use oracle_execution::{Cancellation, ExecutionContext, ExecutionError, WorkControl};
use oracle_logic::{revisions::*, revisions_owner, Error, Limits};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Duration;

fn scope() -> ScopeKey {
    ScopeKey {
        tenant: "tenant".into(),
        workspace: "incident".into(),
    }
}
fn observation(id: &str) -> Insert {
    Insert::Observation(Observation {
        id: id.into(),
        source: id.into(),
        source_revision: "v1".into(),
        atom: "ready".into(),
    })
}
fn revision(token: &str, n: u64, insert: Vec<Insert>, withdraw: Vec<&str>) -> Revision {
    Revision {
        token: token.into(),
        expected_revision: n,
        insert,
        withdraw: withdraw.into_iter().map(str::to_string).collect(),
    }
}
fn control() -> ExecutionContext {
    ExecutionContext::new(10000, Duration::from_secs(5), Cancellation::default()).unwrap()
}

#[test]
fn immutable_checkpoint_tracks_support_and_coverage_withdrawal() {
    let mut workspace = Workspace::new(scope()).unwrap();
    workspace
        .apply(
            revision(
                "first",
                0,
                vec![
                    observation("a"),
                    observation("b"),
                    Insert::Coverage(Coverage {
                        id: "closure".into(),
                        source: "log".into(),
                        source_revision: "v1".into(),
                        domain: "supplied".into(),
                    }),
                    Insert::Rule(PolicyRule {
                        id: "policy".into(),
                        head: Some("safe".into()),
                        positive: vec!["ready".into()],
                        negative: vec!["risk".into()],
                        coverage: vec!["closure".into()],
                    }),
                ],
                vec![],
            ),
            16,
        )
        .unwrap();
    let first = workspace.checkpoint();
    assert_eq!(first.coverage_ids, vec!["closure"]);
    workspace
        .apply(revision("withdraw_a", 1, vec![], vec!["a"]), 16)
        .unwrap();
    let second = workspace.checkpoint();
    assert!(second.active_record_ids.contains(&"b".into()));
    let prepared = workspace
        .snapshot()
        .prepare(vec!["safe".into()], &Limits::default())
        .unwrap();
    assert!(prepared
        .supports()
        .iter()
        .any(|support| support.record == "b"));
    assert!(!prepared
        .supports()
        .iter()
        .any(|support| support.record == "a"));
    workspace
        .apply(revision("withdraw_closure", 2, vec![], vec!["closure"]), 16)
        .unwrap();
    assert!(workspace.checkpoint().coverage_ids.is_empty());
    assert!(!workspace
        .snapshot()
        .prepare(vec!["safe".into()], &Limits::default())
        .unwrap()
        .supports()
        .iter()
        .any(|support| support.record == "policy"));
    assert_eq!(first.revision, 1);
    assert_ne!(first.snapshot_identity, second.snapshot_identity);
    assert_eq!(
        Workspace::import_with_control(workspace.export(), &scope(), 16, &control())
            .unwrap()
            .checkpoint(),
        workspace.checkpoint()
    );
}

#[test]
fn checkpoint_checks_authenticated_scope_revision_identity_and_owner_version() {
    let mut workspace = Workspace::new(scope()).unwrap();
    workspace
        .apply(revision("first", 0, vec![observation("a")], vec![]), 16)
        .unwrap();
    let expected = workspace.checkpoint();
    assert!(revisions_owner::checkpoint(
        "tenant",
        Some(workspace.export()),
        "incident".into(),
        0,
        None,
        16,
        &control()
    )
    .is_err());
    assert!(revisions_owner::checkpoint(
        "tenant",
        Some(workspace.export()),
        "incident".into(),
        1,
        Some("wrong"),
        16,
        &control()
    )
    .is_err());
    assert!(revisions_owner::checkpoint(
        "other",
        Some(workspace.export()),
        "incident".into(),
        1,
        None,
        16,
        &control()
    )
    .is_err());
    let mut bad = workspace.export();
    bad.version = 999;
    assert!(Workspace::import_with_control(bad, &scope(), 16, &control()).is_err());
    let actual = revisions_owner::checkpoint(
        "tenant",
        Some(workspace.export()),
        "incident".into(),
        1,
        Some(&expected.snapshot_identity),
        16,
        &control(),
    )
    .unwrap();
    assert_eq!(actual, expected);
}

struct CancelDuringRestore(AtomicUsize);
impl WorkControl for CancelDuringRestore {
    fn checkpoint(&self, _: u64) -> Result<(), ExecutionError> {
        if self.0.fetch_add(1, Ordering::SeqCst) >= 1 {
            Err(ExecutionError::Cancelled)
        } else {
            Ok(())
        }
    }
}
#[test]
fn restoration_checks_each_event_and_does_not_mutate_source_on_failure() {
    let mut workspace = Workspace::new(scope()).unwrap();
    workspace
        .apply(revision("first", 0, vec![observation("a")], vec![]), 16)
        .unwrap();
    workspace
        .apply(revision("second", 1, vec![observation("b")], vec![]), 16)
        .unwrap();
    let before = serde_json::to_string(&workspace.export()).unwrap();
    let interrupted = CancelDuringRestore(AtomicUsize::new(0));
    assert!(matches!(
        Workspace::import_with_control(workspace.export(), &scope(), 16, &interrupted),
        Err(Error::Cancelled)
    ));
    assert_eq!(serde_json::to_string(&workspace.export()).unwrap(), before);
    let insufficient =
        ExecutionContext::new(1, Duration::from_secs(5), Cancellation::default()).unwrap();
    assert!(matches!(
        Workspace::import_with_control(workspace.export(), &scope(), 16, &insufficient),
        Err(Error::Limit("shared work"))
    ));
    assert_eq!(
        Workspace::import_with_control(workspace.export(), &scope(), 16, &control())
            .unwrap()
            .checkpoint(),
        workspace.checkpoint()
    );
}
