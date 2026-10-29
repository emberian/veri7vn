//! The four hand-simulated traces from the README, one test each. The expected
//! node sets were written by hand; nothing here compares against an
//! independent traversal.
use maintained_views_experiment::*;
use std::collections::BTreeSet;

fn live() -> bool {
    false
}
fn budget(remaining: usize) -> Budget<'static> {
    Budget {
        remaining,
        cancelled: &live,
    }
}
fn tenant(name: &str) -> Tenant {
    let public = Public::new(
        "host-bound-release".into(),
        vec![("public-ab".into(), (1, 2))],
    )
    .unwrap();
    let limits = Limits {
        views: 4,
        nodes_per_view: 32,
        private_supports: 16,
    };
    Tenant::new(public, name.into(), limits).unwrap()
}
const ROOT: Demand = Demand {
    root: 1,
    direction: Direction::Downstream,
};
fn insert(id: &str, edge: Edge) -> Mutation {
    Mutation::Insert {
        id: id.into(),
        edge,
    }
}
fn retract(id: &str) -> Mutation {
    Mutation::Retract { id: id.into() }
}
fn delta(expected: u64, version: u64, changes: Vec<Mutation>) -> Delta {
    Delta {
        expected,
        version,
        changes,
    }
}
fn set(items: &[u32]) -> BTreeSet<u32> {
    items.iter().copied().collect()
}

#[test]
fn trace_one_duplicate_supports_and_tenant_isolation() {
    let mut a = tenant("a");
    let mut b = tenant("b");
    let mut bud = budget(10_000);
    assert_eq!(*a.demand(ROOT, 0, &mut bud).unwrap().nodes, set(&[2]));
    a.apply(
        &delta(
            0,
            1,
            vec![
                insert("bc1", (2, 3)),
                insert("bc2", (2, 3)),
                insert("cb", (3, 2)),
            ],
        ),
        &mut bud,
    )
    .unwrap();
    let cycle = a.demand(ROOT, 1, &mut bud).unwrap();
    assert_eq!(*cycle.nodes, set(&[2, 3]));
    assert_eq!(*b.demand(ROOT, 1, &mut bud).unwrap().nodes, set(&[2]));
    let first = a
        .apply(&delta(1, 2, vec![retract("bc1")]), &mut bud)
        .unwrap();
    assert_eq!(first.removed_edges, 0);
    let last = a
        .apply(&delta(2, 3, vec![retract("bc2")]), &mut bud)
        .unwrap();
    assert_eq!(last.rederived_views, 1);
    assert_eq!(*a.demand(ROOT, 3, &mut bud).unwrap().nodes, set(&[2]));
    // The version-1 snapshot stays {2,3} after the retraction.
    assert_eq!(cycle.version, 1);
    assert_eq!(*cycle.nodes, set(&[2, 3]));
    assert_ne!(
        cycle.key.scope,
        b.demand(ROOT, 3, &mut bud).unwrap().key.scope
    );
}

#[test]
fn trace_two_disconnected_cycle_does_not_keep_itself_alive() {
    let mut a = tenant("a");
    let mut bud = budget(10_000);
    a.apply(
        &delta(
            0,
            1,
            vec![
                insert("entry", (2, 20)),
                insert("loop1", (20, 21)),
                insert("loop2", (21, 20)),
            ],
        ),
        &mut bud,
    )
    .unwrap();
    assert_eq!(
        *a.demand(ROOT, 1, &mut bud).unwrap().nodes,
        set(&[2, 20, 21])
    );
    a.apply(&delta(1, 2, vec![retract("entry")]), &mut bud)
        .unwrap();
    assert_eq!(*a.demand(ROOT, 2, &mut bud).unwrap().nodes, set(&[2]));
}

#[test]
fn trace_three_budget_refusal_then_replay_then_cancellation() {
    let mut a = tenant("a");
    let mut bud = budget(10_000);
    a.apply(&delta(0, 1, vec![insert("x", (2, 5))]), &mut bud)
        .unwrap();
    a.apply(&delta(1, 2, vec![insert("y", (5, 6))]), &mut bud)
        .unwrap();
    a.apply(&delta(2, 3, vec![insert("z", (6, 7))]), &mut bud)
        .unwrap();
    assert_eq!(a.version(), 3);
    let pending = delta(
        3,
        4,
        vec![insert("pending", (2, 9)), insert("more", (9, 10))],
    );
    let mut short = budget(1);
    assert_eq!(a.apply(&pending, &mut short).unwrap_err(), Error::Budget);
    assert_eq!(a.version(), 3);
    a.apply(&pending, &mut bud).unwrap();
    assert_eq!(a.version(), 4);
    let calls = std::cell::Cell::new(0);
    let cancel = || {
        calls.set(calls.get() + 1);
        calls.get() > 1
    };
    let mut cancelled = Budget {
        remaining: 100,
        cancelled: &cancel,
    };
    let err = a
        .apply(&delta(4, 5, vec![retract("pending")]), &mut cancelled)
        .unwrap_err();
    assert_eq!(err, Error::Cancelled);
    assert_eq!(a.version(), 4);
}

#[test]
fn trace_four_old_snapshot_survives_and_idle_eviction_drops_memo() {
    let mut a = tenant("a");
    let mut bud = budget(10_000);
    a.apply(&delta(0, 1, vec![insert("bc", (2, 3))]), &mut bud)
        .unwrap();
    let old = a.demand(ROOT, 1, &mut bud).unwrap();
    assert_eq!(*old.nodes, set(&[2, 3]));
    a.apply(&delta(1, 2, vec![retract("bc")]), &mut bud)
        .unwrap();
    assert_eq!(*old.nodes, set(&[2, 3]));
    assert_eq!(old.version, 1);
    assert_eq!(*a.demand(ROOT, 2, &mut bud).unwrap().nodes, set(&[2]));
    assert_eq!(a.evict_idle(100, 5), 1);
    assert_eq!(*a.demand(ROOT, 101, &mut bud).unwrap().nodes, set(&[2]));
}
