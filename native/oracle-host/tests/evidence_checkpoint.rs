#![cfg(feature = "logic")]
//! Checkpoint gateway truth cases over real durable owner state; no panel score.
use oracle_host::{config::NativeConfig, native::NativeRuntime};
use oracle_runtime_core::{Budget, Cancellation, Limits};
use serde_json::{json, Value};

struct Fixture {
    dir: tempfile::TempDir,
    config: NativeConfig,
}
impl Fixture {
    fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        let source = dir.path().join("source.json");
        std::fs::write(&source,json!({"concepts":{},"entities":{"Q1":{"name":"Alice","instanceOf":[],"relations":[]}}}).to_string()).unwrap();
        let image = dir.path().join("image.sqlite");
        let receipt =
            oracle_runtime_core::build_image(&source, &image, 1_000_000, 100_000).unwrap();
        let config = NativeConfig {
            image,
            image_sha256: receipt.image_sha256,
            state: dir.path().join("state.sqlite"),
            core_limits: Value::Null,
            release: None,
            reader_route: false,
        };
        Self { dir, config }
    }
    fn open(&self) -> NativeRuntime {
        NativeRuntime::open(&self.config, &"a".repeat(64)).unwrap()
    }
    fn durable(&self) -> Vec<(String, i64, String)> {
        let db = rusqlite::Connection::open(&self.config.state).unwrap();
        let mut statement = db
            .prepare("SELECT tenant,version,state FROM sessions ORDER BY tenant,id")
            .unwrap();
        statement
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)))
            .unwrap()
            .map(Result::unwrap)
            .collect()
    }
}
fn invoke(
    runtime: &NativeRuntime,
    tenant: &str,
    conversation: &str,
    id: &str,
    request: &str,
    args: Value,
) -> Result<Value, oracle_host::Failure> {
    let budget = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
    runtime.invoke(
        id,
        &args,
        tenant,
        request,
        conversation,
        budget.execution_context().clone(),
        None,
        None,
    )
}
fn revise(runtime: &NativeRuntime, expected: i64, revision: u64, token: &str) -> Value {
    invoke(runtime,"tenant-a","conversation-a","logic.workspace",token,json!({"expected_version":expected,"command":{"command":"revise","revision":{"token":token,"expected_revision":revision,"insert":[{"kind":"observation","id":format!("row-{token}"),"source":"supplied-fixture","source_revision":"v1","atom":"ready"}],"withdraw":[]}}})).unwrap()
}
fn checkpoint(
    runtime: &NativeRuntime,
    expected: i64,
    revision: u64,
    identity: Option<&str>,
) -> Result<Value, oracle_host::Failure> {
    invoke(
        runtime,
        "tenant-a",
        "conversation-a",
        "logic.workspace.checkpoint",
        "checkpoint",
        json!({"expected_version":expected,"command":{"command":"checkpoint","expected_revision":revision,"expected_snapshot_identity":identity}}),
    )
}
fn core(reply: &Value) -> Value {
    serde_json::from_str(reply["core_reply_json"].as_str().unwrap()).unwrap()
}

#[test]
fn checkpoint_discovery_restart_scope_and_compare_receipt() {
    let f = Fixture::new();
    let runtime = f.open();
    assert!(runtime.operations().contains(&"logic.workspace.checkpoint"));
    assert!(
        !runtime.operations().contains(&"logic.workspace.solve"),
        "checkpoint needs no solver"
    );
    let declaration = runtime
        .declarations("host")
        .into_iter()
        .find(|row| row["id"] == "logic.workspace.checkpoint")
        .unwrap();
    assert_eq!(declaration["durable_replay"], false);
    assert!(declaration["input_schema"]["required"]
        .as_array()
        .unwrap()
        .contains(&json!("expected_version")));
    let empty = core(&checkpoint(&runtime, 0, 0, None).unwrap());
    assert_eq!(empty["session_version"], 0);
    assert_eq!(empty["checkpoint"]["active_record_ids"], json!([]));
    assert!(
        f.durable().is_empty(),
        "empty bootstrap receipt must not create durable session"
    );
    revise(&runtime, 0, 0, "first");
    let before = f.durable();
    let first = checkpoint(&runtime, 1, 1, None).unwrap();
    let receipt = core(&first);
    assert_eq!(receipt["schema"], "oracle-evidence-checkpoint-v1");
    assert_eq!(receipt["runtime_identity"], runtime.identity());
    assert_eq!(receipt["session_version"], 1);
    assert_eq!(receipt["checkpoint"]["revision"], 1);
    assert_eq!(
        receipt["checkpoint"]["active_record_ids"],
        json!(["row-first"])
    );
    assert_eq!(first["stateful"], false);
    let identity = receipt["checkpoint"]["snapshot_identity"].as_str().unwrap();
    assert_eq!(
        core(&checkpoint(&runtime, 1, 1, Some(identity)).unwrap()),
        receipt
    );
    assert_eq!(checkpoint(&runtime, 1, 0, None).unwrap_err().status, 409);
    assert_eq!(
        checkpoint(&runtime, 1, 1, Some(&"0".repeat(64)))
            .unwrap_err()
            .status,
        409
    );
    assert_eq!(checkpoint(&runtime, 0, 1, None).unwrap_err().status, 409);
    for (tenant, conversation) in [
        ("tenant-b", "conversation-a"),
        ("tenant-a", "conversation-b"),
    ] {
        assert_eq!(invoke(&runtime,tenant,conversation,"logic.workspace.checkpoint","foreign",json!({"expected_version":1,"command":{"command":"checkpoint","expected_revision":1}})).unwrap_err().status,409);
    }
    assert_eq!(
        f.durable(),
        before,
        "checkpoint and failed comparisons must never mutate durable evidence"
    );
    drop(runtime);
    let runtime = f.open();
    assert_eq!(
        core(&checkpoint(&runtime, 1, 1, Some(identity)).unwrap()),
        receipt
    );
    revise(&runtime, 1, 1, "second");
    assert_eq!(
        checkpoint(&runtime, 1, 1, Some(identity))
            .unwrap_err()
            .status,
        409,
        "concurrent session advancement invalidates old cursor"
    );
    let next = core(&checkpoint(&runtime, 2, 2, None).unwrap());
    assert_ne!(
        next["checkpoint"]["snapshot_identity"],
        receipt["checkpoint"]["snapshot_identity"]
    );
    assert!(f.dir.path().exists());
}

#[test]
fn checkpoint_refuses_unadmitted_route_and_corrupt_owner_without_repairing_it() {
    let mut denied = Fixture::new();
    let template = oracle_host::native::manifest_template(
        &denied.config.image_sha256,
        &Limits::default(),
        &"a".repeat(64),
    )
    .unwrap();
    let mut manifest: Value =
        serde_json::from_str(template["manifest_json"].as_str().unwrap()).unwrap();
    manifest["operations"]
        .as_array_mut()
        .unwrap()
        .retain(|row| row["id"] == "graph.query");
    let manifest_json = manifest.to_string();
    let identity =
        oracle_runtime_core::release::ReleaseManifest::from_json(manifest_json.as_bytes())
            .unwrap()
            .identity()
            .unwrap();
    denied.config.release = Some(oracle_host::config::ReleaseConfig {
        manifest_json,
        identity,
    });
    let runtime = denied.open();
    assert_eq!(checkpoint(&runtime, 0, 0, None).unwrap_err().status, 404);
    let f = Fixture::new();
    let runtime = f.open();
    revise(&runtime, 0, 0, "first");
    let db = rusqlite::Connection::open(&f.config.state).unwrap();
    let (tenant, version, text) = f.durable().pop().unwrap();
    let mut envelope: Value = serde_json::from_str(&text).unwrap();
    envelope["native_extensions"]["oracle.logic.revisions"]["payload"] =
        json!({"untrusted_import":true});
    let corrupted = envelope.to_string();
    db.execute(
        "UPDATE sessions SET state=?1 WHERE tenant=?2 AND version=?3",
        rusqlite::params![corrupted, tenant, version],
    )
    .unwrap();
    let before = f.durable();
    let refused = checkpoint(&runtime, 1, 1, None).unwrap_err();
    assert_eq!(refused.status, 503);
    assert_eq!(
        f.durable(),
        before,
        "read must neither accept nor silently repair corrupt owner state"
    );
}
