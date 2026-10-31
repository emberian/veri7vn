#![cfg(feature = "logic")]
//! Durable owner composition, not a specialist score or source authority claim.
use oracle_host::revisions_owner::{EvidenceOwner, MutationCommand};
use oracle_logic::{revisions::*, revisions_owner as domain};
use oracle_runtime_core::{build_image, Budget, Cancellation, Image, Limits, Runtime};
use rusqlite::Connection;
use serde_json::{json, Value};
struct Fixture {
    dir: tempfile::TempDir,
    digest: String,
}
impl Fixture {
    fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        let source = dir.path().join("source.json");
        std::fs::write(&source,json!({"concepts":{},"entities":{"A":{"name":"A","instanceOf":[],"attributes":[],"relations":[]}}}).to_string()).unwrap();
        let digest = build_image(
            &source,
            &dir.path().join("image.sqlite"),
            1_000_000,
            100_000,
        )
        .unwrap()
        .image_sha256;
        Self { dir, digest }
    }
    fn runtime(&self) -> Runtime {
        Runtime::open(
            Image::open(
                &self.dir.path().join("image.sqlite"),
                &self.digest,
                Limits::default(),
            )
            .unwrap(),
            &self.dir.path().join("state.sqlite"),
        )
        .unwrap()
        .register_native_owner::<EvidenceOwner>()
        .unwrap()
    }
    fn stored(&self, tenant: &str) -> (i64, Value) {
        let db = Connection::open(self.dir.path().join("state.sqlite")).unwrap();
        let (version, text): (i64, String) = db
            .query_row(
                "SELECT version,state FROM sessions WHERE tenant=?1 AND id='s'",
                [tenant],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .unwrap();
        (version, serde_json::from_str(&text).unwrap())
    }
}
fn mutation(token: &str, expected: u64) -> String {
    serde_json::to_string(&MutationCommand {
        revision: Revision {
            token: token.into(),
            expected_revision: expected,
            withdraw: vec![],
            insert: vec![Insert::Observation(Observation {
                id: format!("row-{token}"),
                source: "fixture".into(),
                source_revision: "1".into(),
                atom: "ready".into(),
            })],
        },
    })
    .unwrap()
}
fn budget() -> Budget {
    Budget::new(&Limits::default(), Cancellation::default()).unwrap()
}
#[test]
fn exact_replay_restart_failed_solve_and_native_only_state() {
    let f = Fixture::new();
    let runtime = f.runtime();
    let command = mutation("first", 0);
    let first = runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "request-one",
            0,
            &command,
            &budget(),
        )
        .unwrap();
    assert_eq!(
        first,
        runtime
            .execute_native_owner_with_budget::<EvidenceOwner>(
                "t",
                "s",
                "request-one",
                0,
                &command,
                &budget()
            )
            .unwrap()
    );
    assert!(runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "request-one",
            0,
            &mutation("different", 0),
            &budget()
        )
        .is_err());
    let (version, envelope) = f.stored("t");
    assert_eq!(version, 1);
    assert!(envelope["oracle"].is_null());
    let snapshot = runtime
        .read_native_owner_with_budget::<EvidenceOwner>("t", "s", 1, &budget())
        .unwrap();
    let state = snapshot.state().unwrap().clone();
    let prepared = domain::prepare_solve(
        "t",
        state,
        "s".into(),
        1,
        vec!["ready".into()],
        1024,
        &oracle_logic::Limits::default(),
    )
    .unwrap();
    // The provider deliberately returns an explicit inconclusive reply on a
    // backend launch failure; it does not turn that into a false truth claim.
    let failed = domain::solve(
        &prepared,
        &f.dir.path().join("missing-operator-solver"),
        &oracle_logic::Limits::default(),
        budget().execution_context(),
    )
    .unwrap();
    assert_eq!(failed.result.status, oracle_logic::Status::Inconclusive);
    assert!(failed.result.reason.contains("cannot launch pinned clingo"));
    assert!(!failed.result.enumeration_complete);
    assert_eq!(failed.result.completeness_trust, "none");
    assert!(failed.result.models.is_empty());
    assert_eq!(failed.result.answers.len(), 1);
    let answer = &failed.result.answers[0];
    assert_eq!(answer.skeptical, None);
    assert_eq!(answer.credulous, None);
    assert_eq!(answer.true_witness, None);
    assert_eq!(answer.false_witness, None);
    assert_eq!(&failed.receipt, prepared.receipt());
    let acknowledged: Value = serde_json::from_str(&first).unwrap();
    assert_eq!(
        failed.receipt.snapshot_identity.as_str(),
        acknowledged["result"]["commit"]["snapshot_identity"]
            .as_str()
            .unwrap()
    );
    assert_eq!(failed.receipt.revision, 1);
    assert_eq!(
        failed.result.scope.snapshot,
        failed.receipt.snapshot_identity
    );
    assert_eq!(failed.result.scope.tenant, failed.receipt.scope.tenant);
    assert_eq!(f.stored("t"), (version, envelope));
    drop(snapshot);
    drop(runtime);
    let runtime = f.runtime();
    assert_eq!(
        first,
        runtime
            .execute_native_owner_with_budget::<EvidenceOwner>(
                "t",
                "s",
                "request-one",
                0,
                &command,
                &budget()
            )
            .unwrap()
    );
    assert!(runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "stale",
            0,
            &mutation("second", 1),
            &budget()
        )
        .is_err());
    assert_eq!(f.stored("t").0, 1);
}
#[test]
fn tenant_binding_rejects_transplanted_history_and_isolates_retries() {
    let f = Fixture::new();
    let runtime = f.runtime();
    let command = mutation("same-token", 0);
    runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "a",
            "s",
            "same-request",
            0,
            &command,
            &budget(),
        )
        .unwrap();
    runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "b",
            "s",
            "same-request",
            0,
            &command,
            &budget(),
        )
        .unwrap();
    let (_, a) = f.stored("a");
    let (_, b) = f.stored("b");
    assert_eq!(
        a["native_extensions"][OWNER]["payload"]["scope"]["tenant"],
        "a"
    );
    assert_eq!(
        b["native_extensions"][OWNER]["payload"]["scope"]["tenant"],
        "b"
    );
    assert_ne!(a["native_extensions"][OWNER], b["native_extensions"][OWNER]);
    let state: StoredWorkspace =
        serde_json::from_value(a["native_extensions"][OWNER]["payload"].clone()).unwrap();
    assert!(domain::prepare_solve(
        "b",
        state,
        "s".into(),
        1,
        vec![],
        1024,
        &oracle_logic::Limits::default()
    )
    .is_err());
}
