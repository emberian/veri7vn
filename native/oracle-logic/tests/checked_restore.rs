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
#[test]
fn retention_policy_separates_active_records_historical_ids_revisions_and_retry_window() {
    let mut workspace = initial();
    let policy = RetentionPolicy {
        max_active_records: 1,
        max_historical_ids: 3,
        max_revisions: 4,
        max_retained_retries: 2,
        max_bytes: 16 * 1024,
    };
    let obs = |id: &str| {
        Insert::Observation(Observation {
            id: id.into(),
            source: "sensor".into(),
            source_revision: "1".into(),
            atom: "ready".into(),
        })
    };
    let r1 = Revision {
        token: "t1".into(),
        expected_revision: 0,
        insert: vec![obs("a")],
        withdraw: vec![],
    };
    let c1 = workspace.apply_with_policy(r1.clone(), &policy).unwrap();
    assert_eq!(
        workspace.apply_with_policy(r1.clone(), &policy).unwrap(),
        c1
    );

    // Replacing active record "a" with "b" keeps active_records == 1 while historical_ids == 2.
    let r2 = Revision {
        token: "t2".into(),
        expected_revision: 1,
        insert: vec![obs("b")],
        withdraw: vec!["a".into()],
    };
    let c2 = workspace.apply_with_policy(r2.clone(), &policy).unwrap();
    assert_eq!(workspace.retention_metrics().active_records, 1);
    assert_eq!(workspace.retention_metrics().historical_ids, 2);
    assert_eq!(workspace.retention_metrics().retained_retries, 2);

    // Forbidden ID reuse of withdrawn record "a" is rejected even when active_records == 0.
    let reuse_a = Revision {
        token: "t3-bad".into(),
        expected_revision: 2,
        insert: vec![obs("a")],
        withdraw: vec!["b".into()],
    };
    assert_eq!(
        workspace.apply_with_policy(reuse_a, &policy),
        Err(Error::Invalid("record identity reused"))
    );

    // Evict the duplicate retry payload, while history preserves exact retry.
    let r3 = Revision {
        token: "t3".into(),
        expected_revision: 2,
        insert: vec![obs("c")],
        withdraw: vec!["b".into()],
    };
    workspace.apply_with_policy(r3, &policy).unwrap();
    assert_eq!(workspace.retention_metrics().retained_retries, 2);
    assert_eq!(workspace.retention_metrics().retired_tokens, 1);
    assert_eq!(workspace.apply_with_policy(r2, &policy).unwrap(), c2);
    assert_eq!(
        workspace.apply_with_policy(r1.clone(), &policy).unwrap(),
        c1
    );
    let mut altered = r1.clone();
    altered.expected_revision = 3;
    assert_eq!(
        workspace.apply_with_policy(altered, &policy),
        Err(Error::Invalid(
            "revision token reused with different content"
        ))
    );
    let scope = workspace.scope().clone();
    let mut restored = Workspace::import_with_policy(workspace.export(), &scope, &policy).unwrap();
    assert_eq!(restored.apply_with_policy(r1.clone(), &policy).unwrap(), c1);
    let smaller_window = RetentionPolicy {
        max_retained_retries: 0,
        ..policy
    };
    let mut restored =
        Workspace::import_with_policy(workspace.export(), &scope, &smaller_window).unwrap();
    assert_eq!(restored.retention_metrics().retained_retries, 0);
    assert_eq!(restored.apply_with_policy(r1, &smaller_window).unwrap(), c1);
}

#[test]
fn count_only_legacy_api_restores_large_committed_v1_events() {
    let mut workspace = initial();
    let mut event = revision("large", 0);
    event.insert.push(Insert::Observation(Observation {
        id: "id".into(),
        source: "s".repeat(DEFAULT_MAX_BYTES + 1),
        source_revision: "1".into(),
        atom: "a".into(),
    }));
    let commit = workspace.apply(event.clone(), 128).unwrap();
    let stored = workspace.export();
    let scope = workspace.scope().clone();
    let mut restored = Workspace::import(stored.clone(), &scope, 128).unwrap();
    assert_eq!(restored.apply(event.clone(), 128).unwrap(), commit);
    let control = CancelAt {
        calls: AtomicUsize::new(0),
        at: usize::MAX,
    };
    let mut checked =
        Workspace::import_with_control(stored.clone(), &scope, 128, &control).unwrap();
    assert_eq!(checked.apply(event, 128).unwrap(), commit);
    assert!(matches!(
        Workspace::import_with_policy(stored, &scope, &RetentionPolicy::default()),
        Err(Error::Limit("workspace bytes"))
    ));
}

#[test]
fn byte_policy_counts_escaped_scope_event_and_exact_stored_framing() {
    let scope = ScopeKey {
        tenant: "\u{0001}".repeat(20),
        workspace: "w\"\\".into(),
    };
    let mut workspace = Workspace::new(scope.clone()).unwrap();
    let initial_bytes = serde_json::to_vec(&workspace.export()).unwrap().len();
    assert_eq!(workspace.retention_metrics().estimated_bytes, initial_bytes);
    let too_small = RetentionPolicy {
        max_bytes: initial_bytes - 1,
        ..RetentionPolicy::default()
    };
    assert!(matches!(
        Workspace::import_with_policy(workspace.export(), &scope, &too_small),
        Err(Error::Limit("workspace bytes"))
    ));
    let control = CancelAt {
        calls: AtomicUsize::new(0),
        at: usize::MAX,
    };
    assert!(matches!(
        Workspace::import_with_policy_and_control(workspace.export(), &scope, &too_small, &control),
        Err(Error::Limit("workspace bytes"))
    ));
    let first = revision("\u{0001}\"\\", 0);
    let expected_bytes = initial_bytes + serde_json::to_vec(&first).unwrap().len();
    let policy = RetentionPolicy {
        max_bytes: expected_bytes,
        ..RetentionPolicy::default()
    };
    assert!(matches!(
        workspace.apply_with_policy(
            first.clone(),
            &RetentionPolicy {
                max_bytes: expected_bytes - 1,
                ..policy
            }
        ),
        Err(Error::Limit("workspace bytes"))
    ));
    assert_eq!(workspace.checkpoint().revision, 0);
    workspace.apply_with_policy(first, &policy).unwrap();
    assert_eq!(
        workspace.retention_metrics().estimated_bytes,
        expected_bytes
    );
    assert_eq!(
        serde_json::to_vec(&workspace.export()).unwrap().len(),
        expected_bytes
    );
    workspace.apply(revision("second", 1), 128).unwrap();
    assert_eq!(
        workspace.retention_metrics().estimated_bytes,
        serde_json::to_vec(&workspace.export()).unwrap().len()
    );
}

#[test]
fn zero_count_legacy_workspace_can_restore_empty_without_admitting_events() {
    let workspace = initial();
    let mut restored = Workspace::import(workspace.export(), workspace.scope(), 0).unwrap();
    assert!(matches!(
        restored.apply(revision("no-space", 0), 0),
        Err(Error::Limit("workspace history"))
    ));
}
