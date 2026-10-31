//! Manufactured stores only. Retirement is explicit operator destruction of a
//! namespace's local payload history, never TTL expiry of individual requests.
use oracle_runtime_core::effects::{
    EffectIntent, EffectLimits, EffectOutbox, Reconciliation, ReplayPolicy,
};
use oracle_runtime_core::release::{
    runtime_profile_sha256, Availability, OperationRegistration, ReleaseBindings, ReleaseManifest,
};
use oracle_runtime_core::{build_image, Cancellation, Error, HostEffects, Image, Limits, Runtime};
use rusqlite::{Connection, TransactionBehavior};
use serde_json::json;
use std::path::PathBuf;
use std::sync::Arc;
use tempfile::TempDir;

struct Fixture {
    _directory: TempDir,
    image: Arc<Image>,
    store: PathBuf,
}
impl Fixture {
    fn new(limits: Limits) -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let path = directory.path().join("image.sqlite");
        std::fs::write(
            &source,
            json!({"concepts":{},"entities":{
                "Q1":{"name":"Alice","instanceOf":[],"attributes":[],"relations":[]}
            }})
            .to_string(),
        )
        .unwrap();
        let built = build_image(&source, &path, 100_000, 10_000).unwrap();
        let image = Image::open(&path, &built.image_sha256, limits).unwrap();
        let store = directory.path().join("state.sqlite");
        Self {
            _directory: directory,
            image,
            store,
        }
    }
    fn runtime(&self) -> Runtime {
        Runtime::open(self.image.clone(), &self.store).unwrap()
    }
    fn db(&self) -> Connection {
        let db = Connection::open(&self.store).unwrap();
        db.busy_timeout(std::time::Duration::ZERO).unwrap();
        db
    }
    fn counts(&self) -> (u64, u64, u64, u64, u64) {
        self.db()
            .query_row(
                "SELECT sessions,requests,entries,value_bytes,
                (SELECT entries FROM retirement_usage WHERE singleton=1)
             FROM counts,effect_usage WHERE id=1 AND singleton=1",
                [],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?)),
            )
            .unwrap()
    }
    // Construct the actual historical store layout; do not fake a downgrade of
    // a v3 store by merely changing its user_version and leaving new triggers.
    fn historical_store(&self, version: i64) {
        let mut db = self.db();
        let tx = db.transaction().unwrap();
        tx.execute_batch(
            "CREATE TABLE sessions(tenant TEXT NOT NULL,id TEXT NOT NULL,image TEXT NOT NULL,version INTEGER NOT NULL,state TEXT NOT NULL,PRIMARY KEY(tenant,id)) WITHOUT ROWID;
             CREATE TABLE requests(tenant TEXT NOT NULL,id TEXT NOT NULL,digest TEXT NOT NULL,reply TEXT NOT NULL,PRIMARY KEY(tenant,id)) WITHOUT ROWID;
             CREATE TABLE counts(id INTEGER PRIMARY KEY CHECK(id=1),sessions INTEGER NOT NULL,requests INTEGER NOT NULL);
             INSERT INTO counts VALUES(1,0,0);"
        ).unwrap();
        if version == 2 {
            oracle_runtime_core::effects::initialize(&tx).unwrap();
        }
        tx.pragma_update(None, "application_id", 0x4f375331i64)
            .unwrap();
        tx.pragma_update(None, "user_version", version).unwrap();
        tx.commit().unwrap();
    }
}
fn graph() -> String {
    json!({"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"unique_name"}})
        .to_string()
}
fn execute(
    r: &Runtime,
    tenant: &str,
    session: &str,
    request: &str,
    version: i64,
) -> oracle_runtime_core::Result<String> {
    r.execute(
        tenant,
        session,
        request,
        version,
        &graph(),
        Cancellation::default(),
    )
}
fn intent() -> EffectIntent {
    EffectIntent {
        id: "effect".into(),
        session: "s".into(),
        request: "r".into(),
        capability: "inert_fixture".into(),
        replay: ReplayPolicy::AtMostOnce,
        payload: b"proposal".to_vec(),
    }
}
fn enqueue(r: &Runtime, outbox: &EffectOutbox, tenant: &str) {
    r.execute_with_effects(
        tenant,
        "s",
        "r",
        0,
        &graph(),
        Cancellation::default(),
        HostEffects {
            outbox,
            intents: &[intent()],
        },
    )
    .unwrap();
}
fn assert_retired(result: oracle_runtime_core::Result<String>) {
    assert!(matches!(result, Err(Error::Conflict("namespace retired"))));
}

#[test]
fn retirement_is_durable_idempotent_and_frees_capacity_without_reexecuting_old_ids() {
    let f = Fixture::new(Limits {
        sessions: 2,
        journal_entries: 3,
        ..Limits::default()
    });
    let r = f.runtime();
    let already_open = f.runtime();
    let first = execute(&r, "old", "s", "one", 0).unwrap();
    execute(&r, "old", "s2", "two", 0).unwrap();
    assert!(matches!(
        execute(&r, "unrelated", "s", "one", 0),
        Err(Error::Limit("session capacity"))
    ));
    r.retire_namespace("old", Cancellation::default()).unwrap();
    assert_eq!(f.counts(), (0, 0, 0, 0, 1));
    r.retire_namespace("old", Cancellation::default()).unwrap();
    assert_eq!(f.counts(), (0, 0, 0, 0, 1));
    for runtime in [&r, &already_open] {
        assert!(runtime.namespace_is_retired("old").unwrap());
        assert_retired(execute(runtime, "old", "s", "one", 0));
        assert_retired(execute(runtime, "old", "new_session", "one", 0));
        assert_retired(execute(runtime, "old", "new_session", "new_request", 0));
        let cancelled = Cancellation::default();
        cancelled.cancel();
        assert_retired(runtime.execute("old", "s", "one", 0, &graph(), cancelled));
    }
    drop(r);
    drop(already_open);
    let reopened = f.runtime();
    assert_retired(execute(&reopened, "old", "s", "one", 0));
    assert!(!reopened
        .namespace_is_retired("fresh_host_namespace")
        .unwrap());
    // A fresh host namespace may independently use the same local request ID.
    assert_eq!(
        execute(&reopened, "fresh_host_namespace", "s", "one", 0).unwrap(),
        first
    );
    assert_eq!(f.counts(), (1, 1, 0, 0, 1));
}

#[test]
fn unresolved_effects_block_retirement_until_authoritative_settlement_then_usage_is_freed() {
    let f = Fixture::new(Limits::default());
    let r = f.runtime();
    let outbox = EffectOutbox::new(EffectLimits {
        entries: 1,
        ..EffectLimits::default()
    })
    .unwrap();
    enqueue(&r, &outbox, "old");
    let before = f.counts();
    assert_eq!(before, (1, 1, 1, 8, 0));
    for phase in 0..3 {
        assert!(matches!(
            r.retire_namespace("old", Cancellation::default()),
            Err(Error::Conflict("namespace has unresolved effects"))
        ));
        assert!(!r.namespace_is_retired("old").unwrap());
        assert_eq!(f.counts().0, 1);
        if phase == 0 {
            r.effect_claim(&outbox, "old", "effect", "worker", 100, 10)
                .unwrap()
                .unwrap();
        } else if phase == 1 {
            r.effect_recover_expired(&outbox, "old", 111, 1).unwrap();
        }
    }
    let uncertain = r.effect_get(&outbox, "old", "effect").unwrap().unwrap();
    r.effect_reconcile(
        &outbox,
        "old",
        "effect",
        uncertain.generation,
        Reconciliation::Applied(b"receiver_receipt"),
        b"authoritative_receiver_evidence",
    )
    .unwrap();
    assert!(f.counts().3 > before.3);
    r.retire_namespace("old", Cancellation::default()).unwrap();
    assert_eq!(f.counts(), (0, 0, 0, 0, 1));
    assert!(r.effect_get(&outbox, "old", "effect").unwrap().is_none());
    enqueue(&r, &outbox, "new");
    assert_eq!(f.counts(), (1, 1, 1, 8, 1));
}

#[test]
fn cancellation_and_mid_delete_failure_leave_the_whole_namespace_intact() {
    let f = Fixture::new(Limits::default());
    let r = f.runtime();
    let outbox = EffectOutbox::new(EffectLimits::default()).unwrap();
    enqueue(&r, &outbox, "old");
    let lease = r
        .effect_claim(&outbox, "old", "effect", "worker", 1, 10)
        .unwrap()
        .unwrap();
    r.effect_complete(&outbox, &lease.fence, 2, b"done")
        .unwrap();
    let before = f.counts();
    let cancelled = Cancellation::default();
    cancelled.cancel();
    assert!(matches!(
        r.retire_namespace("old", cancelled),
        Err(Error::Cancelled)
    ));
    assert_eq!(f.counts(), before);
    // Fail only after completed effect and session deletes have already run.
    f.db().execute_batch("CREATE TRIGGER injected_failure BEFORE DELETE ON requests BEGIN SELECT RAISE(ABORT,'manufactured failure'); END;").unwrap();
    assert!(r.retire_namespace("old", Cancellation::default()).is_err());
    assert_eq!(f.counts(), before);
    assert!(!r.namespace_is_retired("old").unwrap());
    assert!(r.effect_get(&outbox, "old", "effect").unwrap().is_some());
    f.db()
        .execute_batch("DROP TRIGGER injected_failure")
        .unwrap();
    r.retire_namespace("old", Cancellation::default()).unwrap();
    assert_eq!(f.counts(), (0, 0, 0, 0, 1));
}

#[test]
fn retired_fence_runs_before_replay_and_preserves_unchanged_live_replay_digest() {
    let f = Fixture::new(Limits::default());
    let r = f.runtime();
    let reply = execute(&r, "live", "s", "r", 0).unwrap();
    let saved: (String, String) = f
        .db()
        .query_row(
            "SELECT digest,reply FROM requests WHERE tenant='live'",
            [],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .unwrap();
    r.retire_namespace("empty", Cancellation::default())
        .unwrap();
    assert_eq!(execute(&r, "live", "s", "r", 0).unwrap(), reply);
    assert!(matches!(
        r.execute(
            "live",
            "s",
            "r",
            0,
            &format!("{} ", graph()),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
    let after: (String, String) = f
        .db()
        .query_row(
            "SELECT digest,reply FROM requests WHERE tenant='live'",
            [],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .unwrap();
    assert_eq!(after, saved);
    // Manufacture a retained reply already covered by a tombstone, as can exist
    // in a pre-delete snapshot. No schema fence is bypassed: tombstone insertion
    // precedes payload deletion in the supported retirement transaction itself.
    f.db()
        .execute("INSERT INTO retired_namespaces VALUES('live')", [])
        .unwrap();
    assert_retired(execute(&r, "live", "s", "r", 0));
    assert_retired(execute(&r, "live", "other", "r", 0));
}

#[test]
fn migration_preserves_history_and_fences_prepared_historical_writers() {
    for version in [1, 2] {
        let f = Fixture::new(Limits::default());
        f.historical_store(version);
        let stale_writer = f.db();
        let mut old_session_insert = stale_writer
            .prepare("INSERT INTO sessions VALUES(?1,'s','image',1,'state')")
            .unwrap();
        let mut old_request_insert = stale_writer
            .prepare("INSERT INTO requests VALUES(?1,'r','digest','reply')")
            .unwrap();
        stale_writer.execute_batch("INSERT INTO sessions VALUES('kept','s','image',1,'opaque historical state'); INSERT INTO requests VALUES('kept','r','digest','exact historical reply'); UPDATE counts SET sessions=1,requests=1 WHERE id=1;").unwrap();
        let r = f.runtime();
        assert_eq!(
            f.db()
                .pragma_query_value::<i64, _>(None, "user_version", |row| row.get(0))
                .unwrap(),
            3
        );
        let kept: (String,String) = f.db().query_row("SELECT state,reply FROM sessions,requests WHERE sessions.tenant='kept' AND requests.tenant='kept'",[],|row| Ok((row.get(0)?,row.get(1)?))).unwrap();
        assert_eq!(
            kept,
            (
                "opaque historical state".into(),
                "exact historical reply".into()
            )
        );
        r.retire_namespace("closed", Cancellation::default())
            .unwrap();
        assert!(old_session_insert.execute(["closed"]).is_err());
        assert!(old_request_insert.execute(["closed"]).is_err());
        // Both statements were prepared before the new trigger schema existed.
        assert_eq!(old_session_insert.execute(["open"]).unwrap(), 1);
        assert_eq!(old_request_insert.execute(["open"]).unwrap(), 1);
        assert!(stale_writer
            .execute(
                "UPDATE sessions SET tenant='closed' WHERE tenant='open'",
                []
            )
            .is_err());
        assert!(stale_writer
            .execute(
                "UPDATE requests SET tenant='closed' WHERE tenant='open'",
                []
            )
            .is_err());
        assert!(stale_writer
            .execute("DELETE FROM retired_namespaces WHERE tenant='closed'", [])
            .is_err());
        assert!(stale_writer
            .execute(
                "UPDATE retired_namespaces SET tenant='other' WHERE tenant='closed'",
                []
            )
            .is_err());
        // A direct outbox consumer cannot bypass the SQL retirement fence.
        let mut effect_writer = f.db();
        let tx = effect_writer
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .unwrap();
        let outbox = EffectOutbox::new(EffectLimits::default()).unwrap();
        assert!(outbox.enqueue(&tx, "closed", &intent()).is_err());
        drop(tx);
        assert_eq!(f.counts().2, 0);
    }
}

#[test]
fn pre_retirement_sql_snapshot_cannot_commit_a_stale_recreation() {
    let f = Fixture::new(Limits::default());
    let r = f.runtime();
    execute(&r, "old", "s", "r", 0).unwrap();
    let mut stale = f.db();
    let tx = stale
        .transaction_with_behavior(TransactionBehavior::Deferred)
        .unwrap();
    assert_eq!(
        tx.query_row::<i64, _, _>(
            "SELECT count(*) FROM sessions WHERE tenant='old'",
            [],
            |row| row.get(0)
        )
        .unwrap(),
        1
    );
    r.retire_namespace("old", Cancellation::default()).unwrap();
    // SQLite's WAL snapshot upgrade fence rejects this write; an old writer
    // that starts a fresh transaction instead encounters the durable triggers.
    assert!(tx
        .execute(
            "INSERT INTO requests VALUES('old','late','digest','reply')",
            []
        )
        .is_err());
    drop(tx);
    assert_eq!(f.counts(), (0, 0, 0, 0, 1));
}

#[test]
fn migration_failure_is_transactional_and_never_blesses_a_partial_schema() {
    let f = Fixture::new(Limits::default());
    f.historical_store(1);
    // A conflicting name forces failure after the v1 effect migration ran.
    f.db()
        .execute_batch("CREATE TABLE retirement_usage(conflict TEXT)")
        .unwrap();
    assert!(Runtime::open(f.image.clone(), &f.store).is_err());
    let db = f.db();
    assert_eq!(
        db.pragma_query_value::<i64, _>(None, "user_version", |row| row.get(0))
            .unwrap(),
        1
    );
    assert_eq!(db.query_row::<i64,_,_>("SELECT count(*) FROM sqlite_master WHERE name IN ('effect_intents','retired_namespaces')",[],|row|row.get(0)).unwrap(),0);
    assert_eq!(
        db.query_row::<i64, _, _>(
            "SELECT count(*) FROM counts WHERE sessions=0 AND requests=0",
            [],
            |row| row.get(0)
        )
        .unwrap(),
        1
    );
}

#[test]
fn tombstone_capacity_is_explicit_and_never_evicts_an_old_identity() {
    let f = Fixture::new(Limits {
        retired_namespaces: 2,
        ..Limits::default()
    });
    let r = f.runtime();
    r.retire_namespace("closed_1", Cancellation::default())
        .unwrap();
    r.retire_namespace("closed_2", Cancellation::default())
        .unwrap();
    assert_eq!(f.counts().4, 2);
    execute(&r, "still_live", "s", "r", 0).unwrap();
    let before = f.counts();
    assert!(matches!(
        r.retire_namespace("still_live", Cancellation::default()),
        Err(Error::Limit("retired namespace capacity"))
    ));
    assert_eq!(f.counts(), before);
    assert!(!r.namespace_is_retired("still_live").unwrap());
    r.retire_namespace("closed_1", Cancellation::default())
        .unwrap();
    assert_retired(execute(&r, "closed_1", "s", "r", 0));
    assert_eq!(f.counts(), before);
}

#[test]
fn maintenance_requires_its_own_admitted_host_operations() {
    let f = Fixture::new(Limits::default());
    for allow in [false, true] {
        let operation_ids: &[&str] = if allow {
            &[
                "graph.execute",
                "host.retention.retire",
                "host.retention.inspect",
            ]
        } else {
            &["graph.execute"]
        };
        let operations: Vec<_> = operation_ids
            .iter()
            .map(|id| {
                json!({
                    "id":id,"version":1,"summary":id,"availability":"implemented",
                    "input_schema":{},"output_schema":{},"resources":[],"limitations":[]
                })
            })
            .collect();
        let manifest = ReleaseManifest::from_json(&serde_json::to_vec(&json!({
            "schema":"oracle-native-release-v1","runtime_artifact_sha256":"1".repeat(64),
            "data_image_sha256":f.image.identity,
            "resource_profile_sha256":runtime_profile_sha256(&f.image.limits).unwrap(),
            "appliance_receipt_sha256":null,"resources":[],"operations":operations,
            "schemas":[{"id":"session","version":3},{"id":"graph","version":1},{"id":"kqa_program","version":1}]
        })).unwrap()).unwrap();
        let bindings = ReleaseBindings {
            runtime_artifact_sha256: manifest.runtime_artifact_sha256.clone(),
            data_image_sha256: manifest.data_image_sha256.clone(),
            resource_profile_sha256: manifest.resource_profile_sha256.clone(),
            resources: vec![],
        };
        let registrations: Vec<_> = operation_ids
            .iter()
            .map(|id| OperationRegistration {
                id: (*id).into(),
                availability: Availability::Implemented,
            })
            .collect();
        let expected = manifest.identity().unwrap();
        let admitted = manifest
            .admit(&expected, &bindings, &registrations)
            .unwrap();
        let runtime = Runtime::open_release(f.image.clone(), &f.store, admitted).unwrap();
        if allow {
            runtime
                .retire_namespace("retired", Cancellation::default())
                .unwrap();
            assert!(runtime.namespace_is_retired("retired").unwrap());
        } else {
            assert!(matches!(
                runtime.retire_namespace("retired", Cancellation::default()),
                Err(Error::Invalid(_))
            ));
            assert!(matches!(
                runtime.namespace_is_retired("retired"),
                Err(Error::Invalid(_))
            ));
            assert_eq!(f.counts().4, 0);
        }
    }
}

#[test]
fn lowered_tombstone_limit_preserves_history_and_never_reopens_old_namespaces() {
    let f = Fixture::new(Limits {
        retired_namespaces: 2,
        ..Limits::default()
    });
    let r = f.runtime();
    r.retire_namespace("one", Cancellation::default()).unwrap();
    r.retire_namespace("two", Cancellation::default()).unwrap();
    let lower_limits = Limits {
        retired_namespaces: 1,
        ..Limits::default()
    };
    let lower_image = Image::open(
        &f.store.with_file_name("image.sqlite"),
        &f.image.identity,
        lower_limits,
    )
    .unwrap();
    let lower = Runtime::open(lower_image, &f.store).unwrap();
    lower
        .retire_namespace("one", Cancellation::default())
        .unwrap();
    assert_retired(execute(&lower, "two", "s", "r", 0));
    assert!(matches!(
        lower.retire_namespace("three", Cancellation::default()),
        Err(Error::Limit("retired namespace capacity"))
    ));
    assert_eq!(f.counts(), (0, 0, 0, 0, 2));
    for retired_namespaces in [0, i64::MAX as u64 + 1] {
        assert!(Limits {
            retired_namespaces,
            ..Limits::default()
        }
        .validate()
        .is_err());
    }
}
