//! Authored scenarios with hand-traced assertions; they run clean (see also tests/transitions.rs).
use maintained_views_experiment::*;
fn main() -> Result<(), Error> {
    let public = Public::new(
        "host-bound-release".into(),
        vec![("public-ab".into(), (1, 2))],
    )?;
    let limits = Limits {
        views: 4,
        nodes_per_view: 32,
        private_supports: 16,
    };
    let mut a = Tenant::new(public.clone(), "a".into(), limits)?;
    let mut b = Tenant::new(public, "b".into(), limits)?;
    let live = || false;
    let mut budget = Budget {
        remaining: 10000,
        cancelled: &live,
    };
    let root = Demand {
        root: 1,
        direction: Direction::Downstream,
    };
    let before = a.demand(root, 0, &mut budget)?;
    assert_eq!(&*before.nodes, &std::collections::BTreeSet::from([2]));
    let insert = |id: &str, edge| Mutation::Insert {
        id: id.into(),
        edge,
    };
    let retract = |id: &str| Mutation::Retract { id: id.into() };
    a.apply(
        &Delta {
            expected: 0,
            version: 1,
            changes: vec![
                insert("bc1", (2, 3)),
                insert("bc2", (2, 3)),
                insert("cb", (3, 2)),
            ],
        },
        &mut budget,
    )?;
    let cycle = a.demand(root, 1, &mut budget)?;
    assert_eq!(&*cycle.nodes, &std::collections::BTreeSet::from([2, 3]));
    let duplicate = a.apply(
        &Delta {
            expected: 1,
            version: 2,
            changes: vec![retract("bc1")],
        },
        &mut budget,
    )?;
    assert_eq!(duplicate.removed_edges, 0);
    let last = a.apply(
        &Delta {
            expected: 2,
            version: 3,
            changes: vec![retract("bc2")],
        },
        &mut budget,
    )?;
    assert_eq!(last.rederived_views, 1);
    assert_eq!(
        &*a.demand(root, 3, &mut budget)?.nodes,
        &std::collections::BTreeSet::from([2])
    );
    assert_eq!(
        &*b.demand(root, 3, &mut budget)?.nodes,
        &std::collections::BTreeSet::from([2])
    );
    assert_ne!(cycle.key.scope, b.demand(root, 3, &mut budget)?.key.scope);
    // Existing output remains an old settled result after actor updates.
    assert_eq!(cycle.version, 1);
    assert_eq!(cycle.nodes.len(), 2);
    // Budget refusal occurs after staging one mutation, before publication.
    let mut short = Budget {
        remaining: 1,
        cancelled: &live,
    };
    let pending = Delta {
        expected: 3,
        version: 4,
        changes: vec![insert("pending", (2, 9)), insert("more", (9, 10))],
    };
    assert_eq!(a.apply(&pending, &mut short).unwrap_err(), Error::Budget);
    assert_eq!(a.version(), 3);
    a.apply(&pending, &mut budget)?; // replay same expected version succeeds
                                     // Simulate asynchronous cancellation after entering staged work.
    let calls = std::cell::Cell::new(0);
    let cancel = || {
        calls.set(calls.get() + 1);
        calls.get() > 1
    };
    let mut cancelled = Budget {
        remaining: 100,
        cancelled: &cancel,
    };
    assert_eq!(
        a.apply(
            &Delta {
                expected: 4,
                version: 5,
                changes: vec![retract("pending")]
            },
            &mut cancelled
        )
        .unwrap_err(),
        Error::Cancelled
    );
    assert_eq!(a.version(), 4);
    assert_eq!(a.evict_idle(100, 5), 1);
    // A disconnected cycle cannot retain its own reachability evidence.
    a.apply(
        &Delta {
            expected: 4,
            version: 6,
            changes: vec![
                insert("entry", (2, 20)),
                insert("loop1", (20, 21)),
                insert("loop2", (21, 20)),
            ],
        },
        &mut budget,
    )?;
    assert!(a.demand(root, 101, &mut budget)?.nodes.contains(&21));
    a.apply(
        &Delta {
            expected: 6,
            version: 7,
            changes: vec![retract("entry")],
        },
        &mut budget,
    )?;
    let disconnected = a.demand(root, 102, &mut budget)?;
    assert!(!disconnected.nodes.contains(&20));
    assert!(!disconnected.nodes.contains(&21));
    Ok(())
}
