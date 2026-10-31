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

#[test]
fn checked_evidence_read_keeps_old_snapshot_and_rejects_stale_current_read() {
    let f = Fixture::new();
    let runtime = f.runtime();
    runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "r1",
            0,
            &mutation("one", 0),
            &budget(),
        )
        .unwrap();
    let read_budget = budget();
    let old = runtime
        .read_checked_native_owner_with_budget::<EvidenceOwner>("t", "s", 1, &read_budget)
        .unwrap();
    let identity = old.state().unwrap().checkpoint().snapshot_identity;
    runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "r2",
            1,
            &mutation("two", 1),
            &budget(),
        )
        .unwrap();
    assert!(runtime
        .read_checked_native_owner_with_budget::<EvidenceOwner>("t", "s", 1, &budget())
        .is_err());
    let prepared = oracle_host::revisions_owner::prepare_solve_checked(
        old.state().unwrap(),
        1,
        vec!["ready".into()],
        &oracle_logic::Limits::default(),
    )
    .unwrap();
    assert_eq!(prepared.receipt().snapshot_identity, identity);
    assert_eq!(prepared.receipt().revision, 1);
    let checkpoint = oracle_host::revisions_owner::checkpoint_checked(
        old.binding(),
        old.state(),
        old.revision(),
        1,
        Some(&identity),
        &read_budget,
    )
    .unwrap();
    assert_eq!(checkpoint.session_version, 1);
    assert_eq!(checkpoint.checkpoint.snapshot_identity, identity);
    assert!(oracle_host::revisions_owner::prepare_solve_checked(
        old.state().unwrap(),
        2,
        vec![],
        &oracle_logic::Limits::default()
    )
    .is_err());
    let current = runtime
        .read_checked_native_owner_with_budget::<EvidenceOwner>("t", "s", 2, &budget())
        .unwrap();
    assert_ne!(
        current.state().unwrap().checkpoint().snapshot_identity,
        identity
    );
}

#[test]
fn checked_read_refuses_cancelled_budget_and_transplanted_scope() {
    let f = Fixture::new();
    let runtime = f.runtime();
    runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "r1",
            0,
            &mutation("one", 0),
            &budget(),
        )
        .unwrap();
    let cancellation = Cancellation::default();
    let cancelled = Budget::new(&Limits::default(), cancellation.clone()).unwrap();
    cancellation.cancel();
    assert!(matches!(
        runtime.read_checked_native_owner_with_budget::<EvidenceOwner>("t", "s", 1, &cancelled),
        Err(oracle_runtime_core::Error::Cancelled)
    ));
    let (_, mut envelope) = f.stored("t");
    let mut state: StoredWorkspace =
        serde_json::from_value(envelope["native_extensions"][OWNER]["payload"].clone()).unwrap();
    state.scope.tenant = "another-tenant".into();
    envelope["native_extensions"][OWNER] = serde_json::to_value(
        oracle_runtime_core::session::ExtensionState::new(
            OWNER.into(),
            VERSION,
            serde_json::to_value(state).unwrap(),
        )
        .unwrap(),
    )
    .unwrap();
    Connection::open(f.dir.path().join("state.sqlite"))
        .unwrap()
        .execute(
            "UPDATE sessions SET state=?1 WHERE tenant='t' AND id='s'",
            [envelope.to_string()],
        )
        .unwrap();
    assert!(runtime
        .read_checked_native_owner_with_budget::<EvidenceOwner>("t", "s", 1, &budget())
        .is_err());
}

struct CheckedProbe;
static CHECKED_RESTORES: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
impl oracle_runtime_core::session::NativeSessionOwner for CheckedProbe {
    const OWNER: &'static str = "checked_probe";
    const VERSION: u32 = 1;
    const OPERATION: &'static str = "checked.probe";
    type State = bool;
    type Command = bool;
    type Reply = bool;
    fn validate(
        _: &bool,
        _: &oracle_runtime_core::session::SessionBinding,
        _: i64,
    ) -> oracle_runtime_core::Result<()> {
        Err(oracle_runtime_core::Error::Invalid(
            "unchecked probe validation must not run".into(),
        ))
    }
    fn transition(
        _: &oracle_runtime_core::session::SessionBinding,
        _: i64,
        _: &str,
        _: Option<bool>,
        _: bool,
        _: &Budget,
    ) -> oracle_runtime_core::Result<(bool, bool)> {
        unreachable!("read-only probe")
    }
}
impl oracle_runtime_core::session::CheckedNativeSessionOwner for CheckedProbe {
    type Checked = bool;
    fn restore_checked(
        state: bool,
        _: &oracle_runtime_core::session::SessionBinding,
        _: i64,
        budget: &Budget,
    ) -> oracle_runtime_core::Result<bool> {
        budget.spend(1)?;
        CHECKED_RESTORES.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        Ok(state)
    }
}

#[test]
fn selected_owner_restored_once_and_other_owner_still_validated() {
    let f = Fixture::new();
    let runtime = f.runtime().register_native_owner::<CheckedProbe>().unwrap();
    runtime
        .execute_native_owner_with_budget::<EvidenceOwner>(
            "t",
            "s",
            "r1",
            0,
            &mutation("one", 0),
            &budget(),
        )
        .unwrap();
    let (_, mut envelope) = f.stored("t");
    envelope["native_extensions"]["checked_probe"] = serde_json::to_value(
        oracle_runtime_core::session::ExtensionState::new("checked_probe".into(), 1, json!(true))
            .unwrap(),
    )
    .unwrap();
    let db = Connection::open(f.dir.path().join("state.sqlite")).unwrap();
    db.execute(
        "UPDATE sessions SET state=?1 WHERE tenant='t' AND id='s'",
        [envelope.to_string()],
    )
    .unwrap();
    CHECKED_RESTORES.store(0, std::sync::atomic::Ordering::SeqCst);
    let checked = runtime
        .read_checked_native_owner_with_budget::<CheckedProbe>("t", "s", 1, &budget())
        .unwrap();
    assert_eq!(checked.state(), Some(&true));
    assert_eq!(
        CHECKED_RESTORES.load(std::sync::atomic::Ordering::SeqCst),
        1
    );
    // Selected restoration cannot exempt another owner from semantic validation.
    let mut state: StoredWorkspace =
        serde_json::from_value(envelope["native_extensions"][OWNER]["payload"].clone()).unwrap();
    state.history[0].expected_revision = 9;
    envelope["native_extensions"][OWNER] = serde_json::to_value(
        oracle_runtime_core::session::ExtensionState::new(
            OWNER.into(),
            VERSION,
            serde_json::to_value(state).unwrap(),
        )
        .unwrap(),
    )
    .unwrap();
    db.execute(
        "UPDATE sessions SET state=?1 WHERE tenant='t' AND id='s'",
        [envelope.to_string()],
    )
    .unwrap();
    assert!(runtime
        .read_checked_native_owner_with_budget::<CheckedProbe>("t", "s", 1, &budget())
        .is_err());
    assert_eq!(
        CHECKED_RESTORES.load(std::sync::atomic::Ordering::SeqCst),
        1
    );
}
