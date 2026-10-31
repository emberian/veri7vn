use oracle_logic::{revisions::*, Limits, Request};
fn workspace() -> Workspace {
    Workspace::new(ScopeKey {
        tenant: "t".into(),
        workspace: "incident".into(),
    })
    .unwrap()
}
fn obs(id: &str, atom: &str) -> Insert {
    Insert::Observation(Observation {
        id: id.into(),
        source: "operator".into(),
        source_revision: "supplied-1".into(),
        atom: atom.into(),
    })
}
fn rev(token: &str, n: u64, insert: Vec<Insert>, withdraw: Vec<&str>) -> Revision {
    Revision {
        token: token.into(),
        expected_revision: n,
        insert,
        withdraw: withdraw.into_iter().map(String::from).collect(),
    }
}
// Independent brute-force semantics for tiny gold cases, no external solver.
fn models(p: &Request) -> Vec<Vec<String>> {
    (0..(1usize << p.atoms.len()))
        .filter_map(|bits| {
            let candidate: Vec<bool> = (0..p.atoms.len()).map(|i| bits & (1 << i) != 0).collect();
            let reduct: Vec<_> = p
                .rules
                .iter()
                .filter(|r| r.negative.iter().all(|i| !candidate[*i]))
                .collect();
            let mut closure = vec![false; p.atoms.len()];
            loop {
                let before = closure.clone();
                for r in &reduct {
                    if r.positive.iter().all(|i| closure[*i]) {
                        if let Some(h) = r.head {
                            closure[h] = true;
                        }
                    }
                }
                if before == closure {
                    break;
                }
            }
            if candidate != closure
                || reduct
                    .iter()
                    .any(|r| r.head.is_none() && r.positive.iter().all(|i| closure[*i]))
            {
                None
            } else {
                Some(
                    p.atoms
                        .iter()
                        .enumerate()
                        .filter(|(i, _)| closure[*i])
                        .map(|(_, a)| a.clone())
                        .collect(),
                )
            }
        })
        .collect()
}
fn rule(id: &str, h: &str, pos: Vec<&str>, neg: Vec<&str>, cov: Vec<&str>) -> Insert {
    Insert::Rule(PolicyRule {
        id: id.into(),
        head: Some(h.into()),
        positive: pos.into_iter().map(String::from).collect(),
        negative: neg.into_iter().map(String::from).collect(),
        coverage: cov.into_iter().map(String::from).collect(),
    })
}
fn answer(w: &Workspace) -> Vec<Vec<String>> {
    models(
        w.snapshot()
            .prepare(vec!["safe".into()], &Limits::default())
            .unwrap()
            .request(),
    )
}
#[test]
fn atomic_retry_conflict_and_restore() {
    let mut w = workspace();
    let r = rev("one", 0, vec![obs("a", "ready")], vec![]);
    let c = w.apply(r.clone(), 100).unwrap();
    assert_eq!(w.apply(r.clone(), 100).unwrap(), c);
    assert!(w.apply(rev("one", 0, vec![], vec![]), 100).is_err());
    assert!(w.apply(rev("stale", 0, vec![], vec![]), 100).is_err());
    assert!(w
        .apply(rev("bad", 1, vec![obs("b", "risk")], vec!["unknown"]), 100)
        .is_err());
    assert_eq!(w.snapshot().identity(), c.snapshot_identity);
    let restored =
        Workspace::restore(w.snapshot().scope().clone(), w.history().to_vec(), 100).unwrap();
    assert_eq!(restored.snapshot().identity(), w.snapshot().identity());
}
#[test]
fn duplicate_support_last_withdrawal_and_frozen_snapshot() {
    let mut w = workspace();
    w.apply(
        rev(
            "1",
            0,
            vec![
                obs("a", "ready"),
                obs("b", "ready"),
                rule("policy", "safe", vec!["ready"], vec![], vec![]),
            ],
            vec![],
        ),
        100,
    )
    .unwrap();
    let old = w.snapshot();
    assert_eq!(
        answer(&w),
        vec![vec!["ready".to_string(), "safe".to_string()]]
    );
    w.apply(rev("2", 1, vec![], vec!["a"]), 100).unwrap();
    assert_eq!(answer(&w).len(), 1);
    assert!(answer(&w)[0].contains(&"safe".into()));
    w.apply(rev("3", 2, vec![], vec!["b"]), 100).unwrap();
    assert_eq!(answer(&w), vec![Vec::<String>::new()]);
    assert_eq!(old.revision(), 1);
    assert_ne!(old.identity(), w.snapshot().identity());
    assert!(w
        .apply(rev("4", 3, vec![obs("a", "risk")], vec![]), 100)
        .is_err());
}
#[test]
fn new_exception_coverage_withdrawal_and_conflicting_sources() {
    let mut w = workspace();
    let coverage = Insert::Coverage(Coverage {
        id: "cover".into(),
        source: "incident log".into(),
        source_revision: "1".into(),
        domain: "all supplied risks".into(),
    });
    w.apply(
        rev(
            "1",
            0,
            vec![
                coverage,
                obs("ok", "ready"),
                rule(
                    "safe-policy",
                    "safe",
                    vec!["ready"],
                    vec!["risk"],
                    vec!["cover"],
                ),
            ],
            vec![],
        ),
        100,
    )
    .unwrap();
    assert!(answer(&w)[0].contains(&"safe".into()));
    w.apply(
        rev(
            "2",
            1,
            vec![obs("risk-row", "risk"), obs("dispute", "no-risk")],
            vec![],
        ),
        100,
    )
    .unwrap();
    assert!(!answer(&w)[0].contains(&"safe".into()));
    assert!(answer(&w)[0].contains(&"no-risk".into()));
    w.apply(rev("3", 2, vec![], vec!["risk-row"]), 100).unwrap();
    assert!(answer(&w)[0].contains(&"safe".into()));
    w.apply(rev("4", 3, vec![], vec!["cover"]), 100).unwrap();
    assert!(!answer(&w)[0].contains(&"safe".into()));
}
#[test]
fn cycle_loses_last_external_support_and_and_is_not_or() {
    let mut w = workspace();
    w.apply(
        rev(
            "1",
            0,
            vec![
                obs("a", "a"),
                rule("ab", "b", vec!["a"], vec![], vec![]),
                rule("ba", "a", vec!["b"], vec![], vec![]),
                rule("both", "safe", vec!["a", "missing"], vec![], vec![]),
            ],
            vec![],
        ),
        100,
    )
    .unwrap();
    assert!(!answer(&w)[0].contains(&"safe".into()));
    w.apply(rev("2", 1, vec![], vec!["a"]), 100).unwrap();
    assert_eq!(answer(&w), vec![Vec::<String>::new()]);
}
#[test]
fn negative_cycles_have_distinct_gold_models() {
    let cover = || {
        Insert::Coverage(Coverage {
            id: "c".into(),
            source: "fixture".into(),
            source_revision: "1".into(),
            domain: "supplied finite program".into(),
        })
    };
    let mut odd = workspace();
    odd.apply(
        rev(
            "1",
            0,
            vec![cover(), rule("odd", "a", vec![], vec!["a"], vec!["c"])],
            vec![],
        ),
        100,
    )
    .unwrap();
    assert!(answer(&odd).is_empty());
    let mut even = workspace();
    even.apply(
        rev(
            "1",
            0,
            vec![
                cover(),
                rule("left", "a", vec![], vec!["b"], vec!["c"]),
                rule("right", "b", vec![], vec!["a"], vec!["c"]),
            ],
            vec![],
        ),
        100,
    )
    .unwrap();
    assert_eq!(
        answer(&even),
        vec![vec!["a".to_string()], vec!["b".to_string()]]
    );
}
#[test]
fn atomic_replacement_changes_receipt_even_with_same_semantics() {
    let mut w = workspace();
    w.apply(rev("1", 0, vec![obs("old", "ready")], vec![]), 100)
        .unwrap();
    let p = w
        .snapshot()
        .prepare(vec!["ready".into()], &Limits::default())
        .unwrap();
    w.apply(rev("2", 1, vec![obs("new", "ready")], vec!["old"]), 100)
        .unwrap();
    let q = w
        .snapshot()
        .prepare(vec!["ready".into()], &Limits::default())
        .unwrap();
    assert_eq!(p.receipt().program_identity, q.receipt().program_identity);
    assert_ne!(p.receipt().snapshot_identity, q.receipt().snapshot_identity);
    assert_ne!(p.receipt().request_identity, q.receipt().request_identity);
    let other = Workspace::new(ScopeKey {
        tenant: "other".into(),
        workspace: "incident".into(),
    })
    .unwrap();
    assert_ne!(
        other.snapshot().identity(),
        workspace().snapshot().identity()
    );
}
#[test]
fn owner_restore_rejects_cross_tenant_and_unknown_version() {
    let w = workspace();
    let other = ScopeKey {
        tenant: "other".into(),
        workspace: "incident".into(),
    };
    assert!(Workspace::import(w.export(), &other, 100).is_err());
    let mut exported = w.export();
    exported.version += 1;
    assert!(Workspace::import(exported, w.snapshot().scope(), 100).is_err());
}
#[test]
fn capacity_refusal_preserves_snapshot_and_retained_retry() {
    let mut w = workspace();
    let first = rev("one", 0, vec![obs("a", "ready")], vec![]);
    let committed = w.apply(first.clone(), 1).unwrap();
    assert!(w.apply(rev("two", 1, vec![], vec!["a"]), 1).is_err());
    assert_eq!(w.snapshot().identity(), committed.snapshot_identity);
    assert_eq!(w.apply(first, 1).unwrap(), committed);
}
