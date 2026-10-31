//! Manufactured process state proves host ownership, not legacy answer quality.
use oracle_host::{
    config::{sha256_file, Artifact, EngineConfig},
    engine::{EngineError, EnginePool},
};
use std::path::PathBuf;
const REV: &str = "0123456789abcdef0123456789abcdef01234567";
fn pool() -> (tempfile::TempDir, EnginePool) {
    let dir = tempfile::tempdir().unwrap();
    let python = std::env::split_paths(&std::env::var_os("PATH").unwrap())
        .map(|p| p.join("python3"))
        .find(|p| p.is_file())
        .unwrap();
    let checkout = dir.path().join("checkout");
    std::fs::create_dir_all(checkout.join(".git")).unwrap();
    std::fs::write(checkout.join(".git/HEAD"), REV).unwrap();
    let worker = dir.path().join("worker.py");
    std::fs::write(
        &worker,
        r#"import sys,json,time,pathlib
state=pathlib.Path(sys.argv[sys.argv.index('--state')+1]); state.mkdir()
(state/'retained').write_text('generation')
print(json.dumps({'protocol':'oracle-engine-v1','ready':True}),flush=True)
private=[]
for line in sys.stdin:
 r=json.loads(line)
 if r['q']=='error': print(json.dumps({'id':r['id'],'error':'mutated then failed'}),flush=True); continue
 if r['q']=='timeout': time.sleep(10)
 if r['q']=='oversize': print('x'*10000,flush=True); continue
 if r['q']=='wrong-id': print(json.dumps({'id':-1}),flush=True); continue
 if r['q'].startswith('remember:'): private.append(r['q'])
 print(json.dumps({'id':r['id'],'status':'answered','response':str(private)}),flush=True)
"#,
    )
    .unwrap();
    let artifact = |path: PathBuf| Artifact {
        sha256: sha256_file(&path).unwrap(),
        path,
    };
    let settings = EngineConfig {
        python: artifact(python),
        answerer: artifact(worker),
        checkout,
        revision: REV.into(),
        materialization: None,
        state: dir.path().join("state"),
        workers: 1,
        startup_ms: 3000,
        turn_ms: 100,
        reply_bytes: 1024,
        specialist: None,
        compose: None,
        tip: None,
    };
    let pool = EnginePool::open(&settings, "ownership-test").unwrap();
    (dir, pool)
}
#[test]
fn eviction_destroys_all_private_state_and_requires_reset() {
    let (dir, pool) = pool();
    pool.start_all().unwrap();
    assert_eq!(pool.health()["starts"], 0);
    let (a, i, generation) = pool
        .ask("tenant-a", "remember:secret", "same", None)
        .unwrap();
    assert!(a["response"].as_str().unwrap().contains("secret"));
    let (b, _, b_generation) = pool.ask("tenant-b", "recall", "same", None).unwrap();
    assert_eq!(b["response"], "[]");
    assert!(b_generation > generation);
    assert_eq!(pool.validate_binding("tenant-b", i, b_generation), Ok(()));
    assert_eq!(
        pool.validate_binding("tenant-a", i, generation),
        Err(EngineError::Lost("conversation_reset_required"))
    );
    assert!(matches!(
        pool.ask("tenant-a", "recall", "same", Some((i, generation))),
        Err((EngineError::Lost("conversation_reset_required"), _))
    ));
    assert!(dir
        .path()
        .join(format!(
            "state/worker-{i}-ownership-test-{generation}/retained"
        ))
        .is_file());
    let (fresh, _, new_generation) = pool.ask("tenant-a", "recall", "new", None).unwrap();
    assert_eq!(fresh["response"], "[]");
    assert!(new_generation > b_generation);
    pool.close();
}
#[test]
fn timeout_protocol_and_oversize_retire_without_resurrecting_private_state() {
    for bad in ["timeout", "oversize", "wrong-id", "error"] {
        let (_dir, pool) = pool();
        let (_, i, g) = pool.ask("a", "remember:secret", "one", None).unwrap();
        assert!(pool.ask("a", bad, "one", Some((i, g))).is_err());
        assert!(matches!(
            pool.ask("a", "recall", "one", Some((i, g))),
            Err((EngineError::Lost("conversation_reset_required"), _))
        ));
        let (r, _, fresh_g) = pool.ask("a", "recall", "fresh", None).unwrap();
        assert_eq!(r["response"], "[]");
        assert!(fresh_g > g);
    }
}
