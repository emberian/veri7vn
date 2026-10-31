//! Recovery tests count actual effects in a tiny, untrusted Python answerer.
//! No upstream code or data, no specialist score, and no native-core transaction claim.
use oracle_host::{
    config::{self, Config},
    journal::{Journal, Lookup},
    service::Service,
};
use serde_json::{json, Value};
use std::{
    path::PathBuf,
    sync::Arc,
    time::{Duration, Instant},
};
const TENANT: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const ENGINE: &str = r#"import json, os, sys, time
print(json.dumps({'protocol':'oracle-engine-v1','ready':True}),flush=True)
for line in sys.stdin:
 r=json.loads(line)
 with open('effects','a') as f:
  f.write(str(os.getpid())+' '+r['session']+' '+r['q']+'\n'); f.flush(); os.fsync(f.fileno())
 if r['q']=='partial-error':
  print(json.dumps({'id':r['id'],'error':'after mutation'}),flush=True); continue
 if r['q']=='wait': time.sleep(0.7)
 out={'id':r['id'],'status':'answered','path':'fake','response':str(os.getpid())}
 print(json.dumps(out),flush=True)
"#;
struct Fixture {
    _dir: tempfile::TempDir,
    config: Config,
    state: PathBuf,
}
impl Fixture {
    fn new(capacity: usize, conversations: u64) -> Option<Self> {
        let python = std::env::split_paths(&std::env::var_os("PATH")?)
            .map(|p| p.join("python3"))
            .find(|p| p.is_file())?
            .canonicalize()
            .ok()?;
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().canonicalize().unwrap();
        let checkout = root.join("checkout");
        std::fs::create_dir_all(checkout.join(".git")).unwrap();
        std::fs::write(
            checkout.join(".git/HEAD"),
            "0123456789abcdef0123456789abcdef01234567\n",
        )
        .unwrap();
        let answerer = root.join("answerer.py");
        std::fs::write(&answerer, ENGINE).unwrap();
        let state = root.join("engine");
        std::fs::create_dir_all(&state).unwrap();
        let value = json!({"schema":"oracle-host-v1","port":0,"journal":root.join("journal.sqlite3"),
   "limits":{"capacity":capacity,"conversations":conversations},"engine":{
   "python":{"path":python,"sha256":config::sha256_file(&python).unwrap()},
   "answerer":{"path":answerer,"sha256":config::sha256_file(&answerer).unwrap()},
   "checkout":checkout,"revision":"0123456789abcdef0123456789abcdef01234567","state":state,
   "workers":2,"startup_ms":10000,"turn_ms":3000}});
        let path = root.join("host.json");
        std::fs::write(&path, serde_json::to_vec(&value).unwrap()).unwrap();
        Some(Self {
            _dir: dir,
            config: config::read(&path).unwrap(),
            state,
        })
    }
    fn open(&self) -> Arc<Service> {
        Service::open(&self.config).unwrap()
    }
    fn effects(&self) -> Vec<String> {
        std::fs::read_to_string(self.state.join("effects"))
            .unwrap_or_default()
            .lines()
            .map(str::to_owned)
            .collect()
    }
    fn wait_effects(&self, n: usize) {
        let until = Instant::now() + Duration::from_secs(10);
        while self.effects().len() < n {
            assert!(Instant::now() < until, "missing Engine effect");
            std::thread::sleep(Duration::from_millis(10));
        }
    }
}
fn raw(id: &str, conversation: &str, text: &str) -> Vec<u8> {
    serde_json::to_vec(&json!({"request_id":id,"conversation_id":conversation,"text":text}))
        .unwrap()
}
fn ask(s: &Service, id: &str, c: &str, q: &str) -> (u16, Value) {
    s.query(TENANT, &raw(id, c, q))
}

#[test]
fn two_workers_serialize_one_conversation_and_replay_under_saturation() {
    let Some(f) = Fixture::new(2, 100) else {
        return;
    };
    let s = f.open();
    let first = ask(&s, "saved", "saved", "hello");
    assert_eq!(first.0, 200, "{:?}", first);
    let a = s.clone();
    let running = std::thread::spawn(move || ask(&a, "running", "same", "wait"));
    f.wait_effects(2);
    // A second worker exists, but cannot race a first turn in the same conversation.
    assert_eq!(ask(&s, "racing", "same", "hello").0, 429);
    assert_eq!(f.effects().len(), 2);
    let b = s.clone();
    let other = std::thread::spawn(move || ask(&b, "other", "other", "wait"));
    f.wait_effects(3);
    assert_eq!(ask(&s, "saved", "saved", "hello"), first);
    assert_eq!(ask(&s, "saved", "saved", "changed").0, 409);
    assert_eq!(ask(&s, "full", "full", "hello").0, 429);
    assert_eq!(running.join().unwrap().0, 200);
    assert_eq!(other.join().unwrap().0, 200);
    // The refused race was not executed or retained; its retry uses the original worker.
    let next = ask(&s, "racing", "same", "hello");
    assert_eq!(next.0, 200, "{:?}", next);
    let rows = f.effects();
    assert_eq!(rows.len(), 4);
    assert_eq!(
        rows[1].split_whitespace().next(),
        rows[3].split_whitespace().next()
    );
    s.close();
    drop(s);
    let s = f.open();
    assert_eq!(ask(&s, "saved", "saved", "hello"), first);
    assert_eq!(ask(&s, "saved", "saved", "changed").0, 409);
    assert_eq!(
        ask(&s, "after", "same", "hello").1["error"],
        "conversation_reset_required"
    );
    assert_eq!(f.effects().len(), 4);
    s.close();
}

#[test]
fn full_registry_refuses_before_counted_engine_effect() {
    let Some(f) = Fixture::new(2, 1) else { return };
    let s = f.open();
    assert_eq!(ask(&s, "one", "one", "hello").0, 200);
    let denied = ask(&s, "two", "two", "hello");
    assert_eq!(denied.1["error"], "conversation_registry_full");
    assert_eq!(denied.1["executed"], false);
    assert_eq!(f.effects().len(), 1);
    s.close();
}

#[test]
fn failed_binding_or_reply_storage_never_reexecutes_effect() {
    for table in ["conversations", "requests"] {
        let Some(f) = Fixture::new(2, 100) else {
            return;
        };
        let s = f.open();
        let db = rusqlite::Connection::open(&f.config.journal).unwrap();
        let trigger = if table == "conversations" {
            "CREATE TRIGGER fail_store BEFORE UPDATE OF worker,generation ON conversations BEGIN SELECT RAISE(ABORT,'injected binding failure'); END"
        } else {
            "CREATE TRIGGER fail_store BEFORE UPDATE OF result ON requests WHEN NEW.result IS NOT NULL BEGIN SELECT RAISE(ABORT,'injected reply failure'); END"
        };
        db.execute_batch(trigger).unwrap();
        let uncertain = ask(&s, "effect", "conv", "hello");
        assert_eq!(uncertain.0, 507, "{uncertain:?}");
        assert_eq!(uncertain.1["state_may_have_changed"], true);
        let retry = ask(&s, "effect", "conv", "hello");
        assert!(
            retry.0 == 507 || retry.1["error"] == "journal_error",
            "{retry:?}"
        );
        assert_eq!(ask(&s, "effect", "conv", "changed").0, 409);
        assert_eq!(f.effects().len(), 1);
        db.execute_batch("DROP TRIGGER fail_store").unwrap();
        drop(db);
        s.close();
        drop(s);
        let s = f.open();
        let retry = ask(&s, "effect", "conv", "hello");
        assert!(
            retry.1["error"] == "interrupted" || retry.1["error"] == "journal_error",
            "{retry:?}"
        );
        assert_eq!(
            ask(&s, "next", "conv", "hello").1["error"],
            "conversation_reset_required"
        );
        assert_eq!(f.effects().len(), 1);
        s.close();
    }
}

#[test]
fn exclusive_owner_lasts_until_service_drop_and_release_change_preserves_history() {
    let Some(mut f) = Fixture::new(2, 100) else {
        return;
    };
    let s = f.open();
    let reply = ask(&s, "keep", "conv", "hello");
    assert_eq!(reply.0, 200);
    s.close();
    assert!(
        Service::open(&f.config).is_err(),
        "close must not unlock a live Service"
    );
    drop(s);
    let answerer = f.config.engine.as_ref().unwrap().answerer.path.clone();
    std::fs::write(&answerer, format!("{ENGINE}\n# changed release\n")).unwrap();
    f.config.engine.as_mut().unwrap().answerer.sha256 = config::sha256_file(&answerer).unwrap();
    assert!(
        Service::open(&f.config).is_err(),
        "changed admitted release must not reuse history"
    );
    assert_eq!(f.effects().len(), 1);
}

#[test]
fn legacy_nonempty_journal_requires_explicit_migration() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("journal");
    let db = rusqlite::Connection::open(&path).unwrap();
    db.execute_batch("CREATE TABLE requests(tenant TEXT,id TEXT,body BLOB,result BLOB); INSERT INTO requests VALUES('t','id',x'01',NULL)").unwrap();
    drop(db);
    assert!(Journal::open(&path, 10, 10, "identity").is_err());
    let db = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        db.query_row("SELECT count(*) FROM requests", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        1
    );
}

#[test]
fn durable_dispatched_crash_retains_exact_bytes() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("journal");
    {
        let journal = Journal::open(&path, 10, 10, "identity").unwrap();
        assert!(matches!(
            journal.begin("t", "id", b"exact", 1024).unwrap(),
            Lookup::Fresh
        ));
        journal.dispatch("t", "id", "c").unwrap();
    }
    let journal = Journal::open(&path, 10, 10, "identity").unwrap();
    match journal.begin("t", "id", b"exact", 1024).unwrap() {
        Lookup::Replay(_, v) => assert_eq!(v["error"], "interrupted"),
        _ => panic!("must replay"),
    };
    assert_eq!(
        journal
            .begin("t", "id", b"changed", 1024)
            .err()
            .unwrap()
            .status,
        409
    );
}

#[test]
fn partial_python_error_poison_replays_and_rejects_context_continuation() {
    let Some(f) = Fixture::new(2, 100) else {
        return;
    };
    let s = f.open();
    let failed = ask(&s, "partial", "conv", "partial-error");
    assert_eq!(failed.1["error"], "worker_error");
    assert_eq!(failed.1["state_may_have_changed"], true);
    assert_eq!(ask(&s, "partial", "conv", "partial-error"), failed);
    assert_eq!(
        ask(&s, "next", "conv", "hello").1["error"],
        "conversation_reset_required"
    );
    assert_eq!(f.effects().len(), 1);
    s.close();
    drop(s);
    let s = f.open();
    assert_eq!(ask(&s, "partial", "conv", "partial-error"), failed);
    assert_eq!(
        ask(&s, "next", "conv", "hello").1["error"],
        "conversation_reset_required"
    );
    assert_eq!(f.effects().len(), 1);
    s.close();
}

#[test]
fn empty_failed_first_admission_can_be_repaired() {
    let Some(mut f) = Fixture::new(2, 100) else {
        return;
    };
    let original = f.config.engine.as_ref().unwrap().answerer.sha256.clone();
    f.config.engine.as_mut().unwrap().answerer.sha256 = "0".repeat(64);
    assert!(Service::open(&f.config).is_err());
    f.config.engine.as_mut().unwrap().answerer.sha256 = original;
    let s = f.open();
    assert_eq!(ask(&s, "first", "conv", "hello").0, 200);
    s.close();
}

#[test]
fn journal_poison_is_cleared_only_by_successful_commit_or_explicit_preexecution_refusal() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("journal");
    let j = Journal::open(&path, 10, 10, "identity").unwrap();
    j.begin("t", "first", b"first", 1024).unwrap();
    j.dispatch("t", "first", "c").unwrap();
    j.bind("t", "c", 0, "boot:1").unwrap();
    j.finish("t", "first", "c", &json!({"outcome":"completed"}))
        .unwrap();
    assert_eq!(
        j.conversation("t", "c").unwrap(),
        Some((0, "boot:1".into()))
    );
    j.begin("t", "refused", b"refused", 1024).unwrap();
    j.dispatch("t", "refused", "c").unwrap();
    j.forget("t", "refused", "c").unwrap();
    assert_eq!(
        j.conversation("t", "c").unwrap(),
        Some((0, "boot:1".into()))
    );
    // Counterexample: opaque execution and bind succeeded, then host arbitration panicked.
    j.begin("t", "panic", b"panic", 1024).unwrap();
    j.dispatch("t", "panic", "c").unwrap();
    j.bind("t", "c", 0, "boot:1").unwrap();
    j.finish(
        "t",
        "panic",
        "c",
        &json!({"outcome":"error","error":"runtime_error","state_may_have_changed":true}),
    )
    .unwrap();
    assert_eq!(
        j.conversation("t", "c").unwrap(),
        Some((0, "poisoned".into()))
    );
    drop(j);
    let j = Journal::open(&path, 10, 10, "identity").unwrap();
    assert_eq!(
        j.conversation("t", "c").unwrap(),
        Some((0, "poisoned".into()))
    );
}

#[test]
fn journal_sibling_ownership_canonicalizes_parent_and_rejects_database_aliases() {
    use std::os::unix::fs::{symlink, MetadataExt};
    let dir = tempfile::tempdir().unwrap();
    let actual = dir.path().join("actual");
    std::fs::create_dir(&actual).unwrap();
    let alias = dir.path().join("alias");
    symlink(&actual, &alias).unwrap();
    let path = actual.join("journal.sqlite3");
    let aliased = alias.join("journal.sqlite3");
    let journal = Journal::open(&path, 10, 10, "identity").unwrap();
    // SQLite WAL access and ownership use distinct inodes on macOS as well as Linux.
    let db = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        db.query_row("SELECT count(*) FROM requests", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        0
    );
    drop(db);
    assert!(Journal::open(&aliased, 10, 10, "identity").is_err());
    let owner = actual.join("journal.sqlite3.owner");
    let inode = std::fs::metadata(&owner).unwrap().ino();
    drop(journal);
    assert_eq!(std::fs::metadata(&owner).unwrap().ino(), inode);
    let journal = Journal::open(&aliased, 10, 10, "identity").unwrap();
    drop(journal);
    assert_eq!(std::fs::metadata(&owner).unwrap().ino(), inode);
    let database_symlink = actual.join("symlink.sqlite3");
    symlink(&path, &database_symlink).unwrap();
    assert!(Journal::open(&database_symlink, 10, 10, "identity").is_err());
    let database_hardlink = actual.join("hardlink.sqlite3");
    std::fs::hard_link(&path, &database_hardlink).unwrap();
    assert!(Journal::open(&database_hardlink, 10, 10, "identity").is_err());
    assert!(Journal::open(&path, 10, 10, "identity").is_err());
}
