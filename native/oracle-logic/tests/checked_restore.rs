//! Checked restoration preserves event semantics and inherited cancellation.
use oracle_execution::{ExecutionError, WorkControl};
use oracle_logic::{revisions::*, revisions_owner, Error, Limits};
use std::sync::atomic::{AtomicUsize, Ordering};

struct CancelAt {
    calls: AtomicUsize,
    at: usize,
}
impl WorkControl for CancelAt {
    fn checkpoint(&self, _: u64) -> Result<(), ExecutionError> {
        if self.calls.fetch_add(1, Ordering::SeqCst) >= self.at {
            Err(ExecutionError::Cancelled)
        } else {
            Ok(())
        }
    }
}
fn initial() -> Workspace {
    Workspace::new(ScopeKey {
        tenant: "tenant".into(),
        workspace: "workspace".into(),
    })
    .unwrap()
}
fn revision(token: &str, expected_revision: u64) -> Revision {
    Revision {
        token: token.into(),
        expected_revision,
        insert: vec![],
        withdraw: vec![],
    }
}
#[test]
fn restoration_can_be_cancelled_inside_history_and_retry_is_still_exact() {
    let mut workspace = initial();
    let first = revision("first", 0);
    let first_commit = workspace.apply(first.clone(), 128).unwrap();
    for n in 1..12 {
        workspace.apply(revision(&format!("r{n}"), n), 128).unwrap();
    }
    let scope = workspace.snapshot().scope().clone();
    let stored = workspace.export();
    let control = CancelAt {
        calls: AtomicUsize::new(0),
        at: 4,
    };
    assert!(matches!(
        Workspace::import_with_control(stored.clone(), &scope, 128, &control),
        Err(Error::Cancelled)
    ));
    assert_eq!(control.calls.load(Ordering::SeqCst), 5);
    // Cancellation did not mutate the durable event representation.
    assert_eq!(stored.history.len(), 12);
    let control = CancelAt {
        calls: AtomicUsize::new(0),
        at: usize::MAX,
    };
    let mut restored = Workspace::import_with_control(stored, &scope, 128, &control).unwrap();
    assert_eq!(restored.apply(first.clone(), 128).unwrap(), first_commit);
    let mut different = first;
    different.expected_revision = 12;
    assert!(restored.apply(different, 128).is_err());
    assert_eq!(restored.checkpoint().revision, 12);
}
#[test]
fn history_limit_is_enforced_without_erasing_old_retry_contract() {
    let mut workspace = initial();
    let first = revision("first", 0);
    let first_commit = workspace.apply(first.clone(), 3).unwrap();
    workspace.apply(revision("second", 1), 3).unwrap();
    workspace.apply(revision("third", 2), 3).unwrap();
    assert!(workspace.apply(revision("fourth", 3), 3).is_err());
    assert_eq!(workspace.apply(first, 3).unwrap(), first_commit);
    let scope = workspace.snapshot().scope().clone();
    let control = CancelAt {
        calls: AtomicUsize::new(0),
        at: usize::MAX,
    };
    assert!(matches!(
        Workspace::import_with_control(workspace.export(), &scope, 2, &control),
        Err(Error::Limit("workspace history"))
    ));
    assert_eq!(control.calls.load(Ordering::SeqCst), 0);
}
#[test]
fn checked_handle_reuses_restoration_for_multiple_query_receipts() {
    let mut workspace = initial();
    workspace.apply(revision("one", 0), 128).unwrap();
    let scope = workspace.snapshot().scope().clone();
    let control = CancelAt {
        calls: AtomicUsize::new(0),
        at: usize::MAX,
    };
    let checked =
        Workspace::import_with_control(workspace.export(), &scope, 128, &control).unwrap();
    let calls = control.calls.load(Ordering::SeqCst);
    let a =
        revisions_owner::prepare_solve_checked(&checked, 1, vec!["a".into()], &Limits::default())
            .unwrap();
    let b =
        revisions_owner::prepare_solve_checked(&checked, 1, vec!["b".into()], &Limits::default())
            .unwrap();
    assert_eq!(a.receipt().snapshot_identity, b.receipt().snapshot_identity);
    assert_ne!(a.receipt().request_identity, b.receipt().request_identity);
    assert_eq!(control.calls.load(Ordering::SeqCst), calls);
    assert!(
        revisions_owner::prepare_solve_checked(&checked, 0, vec![], &Limits::default()).is_err()
    );
}
