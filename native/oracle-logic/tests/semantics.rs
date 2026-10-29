use oracle_logic::*;
use std::sync::atomic::AtomicBool;

fn request(n: usize, rules: Vec<Rule>) -> Request {
    Request {
        operation: Operation::Query,
        scope: Scope {
            tenant: "test".into(),
            snapshot: "v1".into(),
            complete_program: true,
        },
        atoms: (0..n).map(|a| format!("atom-{a}")).collect(),
        rules,
        queries: (0..n).collect(),
    }
}
fn model(mask: usize, n: usize) -> Vec<usize> {
    (0..n).filter(|a| mask & (1 << a) != 0).collect()
}
// Independent test oracle: minimal models of the reduct by exhaustive subsets,
// not the production checker's least-fixpoint algorithm. Exponential ONLY here.
fn reference(p: &Request, m: usize) -> bool {
    let satisfies = |s: usize| {
        p.rules.iter().all(|r| {
            if r.negative.iter().any(|a| m & (1 << a) != 0) {
                return true;
            }
            !r.positive.iter().all(|a| s & (1 << a) != 0)
                || r.head.is_some_and(|a| s & (1 << a) != 0)
        })
    };
    satisfies(m)
        && (0..(1 << p.atoms.len()))
            .filter(|&s| s != m && s & m == s)
            .all(|s| !satisfies(s))
}

#[test]
fn exhaustive_two_atoms_up_to_two_rules() {
    let mut universe = vec![];
    for head in [None, Some(0), Some(1)] {
        for pos in 0..4 {
            for neg in 0..4 {
                universe.push(Rule {
                    head,
                    positive: model(pos, 2),
                    negative: model(neg, 2),
                });
            }
        }
    }
    let cancel = AtomicBool::new(false);
    let limits = Limits {
        milliseconds: 10000,
        ..Limits::default()
    };
    let mut programs = vec![vec![]];
    for i in 0..universe.len() {
        programs.push(vec![universe[i].clone()]);
        for j in i..universe.len() {
            programs.push(vec![universe[i].clone(), universe[j].clone()]);
        }
    }
    assert_eq!(programs.len(), 1225); // empty + 48 singles + 1176 pairs (with repetition)
    for rules in programs {
        let p = request(2, rules);
        for m in 0..4 {
            let actual = check_model(&p, &model(m, 2), &mut Budget::new(&limits, &cancel));
            assert_eq!(
                actual.is_ok(),
                reference(&p, m),
                "rules={:?}, model={m}, actual={actual:?}",
                p.rules
            );
        }
    }
}

fn output(models: &[Vec<usize>], complete: bool) -> Vec<u8> {
    serde_json::to_vec(&serde_json::json!({"Result":if models.is_empty(){"UNSATISFIABLE"}else{"SATISFIABLE"},
        "Models":{"Number":models.len(),"More":if complete{"no"}else{"yes"}},
        "Call":[{"Witnesses":models.iter().map(|m|serde_json::json!({"Value":m.iter().map(|a|format!("a{a}")).collect::<Vec<_>>()})).collect::<Vec<_>>()}]})).unwrap()
}
#[test]
fn skeptical_credulous_inconsistent_and_incomplete() {
    let p = request(
        2,
        vec![
            Rule {
                head: Some(0),
                positive: vec![],
                negative: vec![1],
            },
            Rule {
                head: Some(1),
                positive: vec![],
                negative: vec![0],
            },
        ],
    );
    let l = Limits::default();
    let c = AtomicBool::new(false);
    let r = decode(
        &p,
        &output(&[vec![0], vec![1]], true),
        &l,
        &mut Budget::new(&l, &c),
    )
    .unwrap();
    assert_eq!(r.status, Status::Consistent);
    for a in r.answers {
        assert_eq!(a.skeptical, Some(false));
        assert_eq!(a.credulous, Some(true));
        assert!(a.true_witness.is_some());
        assert!(a.false_witness.is_some());
    }
    let r = decode(&p, &output(&[vec![0]], false), &l, &mut Budget::new(&l, &c)).unwrap();
    assert_eq!(r.status, Status::Inconclusive);
    assert!(r
        .answers
        .iter()
        .all(|a| a.skeptical.is_none() && a.credulous.is_none()));
    let odd = request(
        1,
        vec![Rule {
            head: Some(0),
            positive: vec![],
            negative: vec![0],
        }],
    );
    let r = decode(&odd, &output(&[], true), &l, &mut Budget::new(&l, &c)).unwrap();
    assert_eq!(r.status, Status::Inconsistent);
    assert!(r.answers[0].skeptical.is_none());
    assert!(r.answers[0].credulous.is_none());
}

#[test]
fn rejects_unsupported_cycles_bad_symbols_and_limits() {
    let p = request(
        2,
        vec![
            Rule {
                head: Some(0),
                positive: vec![1],
                negative: vec![],
            },
            Rule {
                head: Some(1),
                positive: vec![0],
                negative: vec![],
            },
        ],
    );
    let l = Limits::default();
    let c = AtomicBool::new(false);
    assert!(decode(
        &p,
        &output(&[vec![0, 1]], true),
        &l,
        &mut Budget::new(&l, &c)
    )
    .is_err());
    assert!(check_model(&p, &[0, 0], &mut Budget::new(&l, &c)).is_err());
    assert!(check_model(&p, &[99], &mut Budget::new(&l, &c)).is_err());
    let cancelled = AtomicBool::new(true);
    assert_eq!(
        check_model(&p, &[], &mut Budget::new(&l, &cancelled)),
        Err(Error::Cancelled)
    );
    let mut tiny = l.clone();
    tiny.checker_work = 0;
    assert_eq!(
        check_model(&p, &[], &mut Budget::new(&tiny, &c)),
        Err(Error::Limit("checker work"))
    );
    tiny = l.clone();
    tiny.models = 0;
    assert_eq!(
        decode(
            &p,
            &output(&[vec![]], true),
            &tiny,
            &mut Budget::new(&tiny, &c)
        )
        .unwrap()
        .status,
        Status::Inconclusive
    );
    let bad=br#"{"Result":"SATISFIABLE","Models":{"More":"no","Number":1},"Call":[{"Witnesses":[{"Value":["__include"]}]}]}"#;
    assert!(decode(&p, bad, &l, &mut Budget::new(&l, &c)).is_err());
    let mut missing = p.clone();
    missing.scope.complete_program = false;
    assert!(validate(&missing, &l).is_err());
    missing = p.clone();
    missing.queries = vec![2];
    assert!(validate(&missing, &l).is_err());
}

#[test]
fn labels_are_never_executable_source_and_empty_model_is_consistent() {
    let mut p = request(1, vec![]);
    p.atoms[0] = "#include \"secret\".\n#script(python)".into();
    assert_eq!(encode(&p), "");
    let l = Limits::default();
    let c = AtomicBool::new(false);
    let r = decode(&p, &output(&[vec![]], true), &l, &mut Budget::new(&l, &c)).unwrap();
    assert_eq!(r.status, Status::Consistent);
    assert_eq!(r.answers[0].skeptical, Some(false));
    assert_eq!(r.answers[0].credulous, Some(false));
}

#[test]
fn motivating_programs_and_snapshot_retraction() {
    let cases = [
        (
            include_str!("../examples/default-flight.json"),
            vec![vec![0, 3]],
        ),
        (
            include_str!("../examples/exception-flight.json"),
            vec![vec![0, 1, 2]],
        ),
        (
            include_str!("../examples/recursive-policy.json"),
            vec![vec![0, 1, 2, 3, 4, 5, 7]],
        ),
        (
            include_str!("../examples/alternative-plans.json"),
            vec![vec![0, 2], vec![1, 2]],
        ),
        (include_str!("../examples/inconsistent.json"), vec![]),
    ];
    let l = Limits::default();
    let c = AtomicBool::new(false);
    for (input, expected) in cases {
        let p = parse(input, &l).unwrap();
        let found: Vec<_> = (0..(1 << p.atoms.len()))
            .filter(|&m| reference(&p, m))
            .map(|m| model(m, p.atoms.len()))
            .collect();
        assert_eq!(found, expected);
        for witness in found {
            check_model(&p, &witness, &mut Budget::new(&l, &c)).unwrap();
        }
    }
    let mut policy = parse(include_str!("../examples/recursive-policy.json"), &l).unwrap();
    policy.scope.snapshot = "revoked-v2".into();
    policy.rules.push(Rule {
        head: Some(6),
        positive: vec![],
        negative: vec![],
    });
    assert!(reference(&policy, 0b0111_1111)); // reachable, revoked, no can-read
    assert!(!reference(&policy, 0b1111_1111));
}

#[test]
fn unavailable_backend_and_pre_cancel_are_inconclusive() {
    let input = include_str!("../examples/default-flight.json");
    let l = Limits::default();
    for cancel in [false, true] {
        let reply = process::call(
            input,
            std::path::Path::new("/nonexistent/oracle-test-clingo"),
            &l,
            &AtomicBool::new(cancel),
        )
        .unwrap();
        let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
        assert_eq!(v["status"], "inconclusive");
        assert!(v["answers"]
            .as_array()
            .unwrap()
            .iter()
            .all(|a| a["skeptical"].is_null() && a["credulous"].is_null()));
    }
}

#[test]
fn satisfiability_probe_does_not_require_enumeration() {
    let p = request(
        2,
        vec![
            Rule {
                head: Some(0),
                positive: vec![],
                negative: vec![1],
            },
            Rule {
                head: Some(1),
                positive: vec![],
                negative: vec![0],
            },
        ],
    );
    let l = Limits::default();
    let c = AtomicBool::new(false);
    assert_eq!(
        decode_probe(&p, &output(&[vec![0]], false), &l, &mut Budget::new(&l, &c)).unwrap(),
        Some(vec![0])
    );
    assert!(decode_probe(&p, &output(&[], false), &l, &mut Budget::new(&l, &c)).is_err());
}

#[test]
fn conflicting_exit_summary_and_interrupted_states_fail_closed() {
    let sat_partial = output(&[vec![0]], false);
    let sat_complete = output(&[vec![0]], true);
    let unsat = output(&[], true);
    for code in [0, 1, 10, 11, 20, 21, 30, 31, 33, 65, 128] {
        assert_eq!(validate_solver_exit(&sat_partial, code).is_ok(), code == 10);
        assert_eq!(
            validate_solver_exit(&sat_complete, code).is_ok(),
            code == 30
        );
        assert_eq!(validate_solver_exit(&unsat, code).is_ok(), code == 20);
    }
    assert!(validate_solver_exit(&output(&[], false), 20).is_err());
    let unknown = br#"{"Result":"UNKNOWN","Models":{"Number":0,"More":"yes"}}"#;
    for code in [0, 1, 10, 20, 30] {
        assert!(validate_solver_exit(unknown, code).is_err());
    }
    let interrupted = br#"{"Result":"UNSATISFIABLE","Models":{"Number":0,"More":"no"}}"#;
    assert!(validate_solver_exit(interrupted, 21).is_err());
}

#[test]
fn interrupted_probe_keeps_only_supported_one_sided_facts() {
    let p = request(
        2,
        vec![Rule {
            head: Some(0),
            positive: vec![],
            negative: vec![],
        }],
    );
    let r = partial_query(&p, "cancelled opposite probe", vec![vec![0]], vec![]);
    assert_eq!(r.status, Status::Inconclusive);
    assert_eq!(r.answers[0].credulous, Some(true));
    assert_eq!(r.answers[0].skeptical, None);
    assert_eq!(r.answers[1].skeptical, Some(false));
    assert_eq!(r.answers[1].credulous, None);
    assert_eq!(r.models, vec![vec![0]]);
}

#[test]
fn contradiction_before_later_failure_revokes_all_absence_claims() {
    let mut rules = Vec::new();
    for atom in 0..3 {
        rules.push(Rule {
            head: Some(atom),
            positive: vec![],
            negative: vec![atom + 3],
        });
        rules.push(Rule {
            head: Some(atom + 3),
            positive: vec![],
            negative: vec![atom],
        });
    }
    let p = request(6, rules);
    let completed = vec![
        Answer {
            atom: 0,
            skeptical: Some(true),
            credulous: Some(true),
            true_witness: Some(0),
            false_witness: None,
        },
        Answer {
            atom: 1,
            skeptical: Some(true),
            credulous: Some(true),
            true_witness: Some(0),
            false_witness: None,
        },
    ];
    let r = partial_query(
        &p,
        "later probe interrupted",
        vec![vec![0, 1, 2], vec![1, 3, 5]],
        completed,
    );
    assert_eq!(r.completeness_trust, "witnesses_only_backend_inconsistent");
    assert_eq!(r.answers[0].skeptical, Some(false));
    assert_eq!(r.answers[1].skeptical, None);
    assert_eq!(r.answers[1].credulous, Some(true));
}

#[test]
#[ignore = "central runner only: requires operator-pinned CLINGO_EXECUTABLE"]
fn sixty_irrelevant_default_choices_do_not_force_enumeration() {
    let path = std::env::var("CLINGO_EXECUTABLE").expect("pin native clingo executable");
    let mut rules = Vec::new();
    for i in 0..60 {
        rules.push(Rule {
            head: Some(2 * i),
            positive: vec![],
            negative: vec![2 * i + 1],
        });
        rules.push(Rule {
            head: Some(2 * i + 1),
            positive: vec![],
            negative: vec![2 * i],
        });
    }
    rules.push(Rule {
        head: Some(120),
        positive: vec![],
        negative: vec![],
    });
    let mut p = request(121, rules);
    p.queries = vec![120];
    let l = Limits {
        models: 2,
        milliseconds: 5000,
        ..Limits::default()
    };
    let c = AtomicBool::new(false);
    let call = |p: &Request| {
        let reply = process::call(
            &serde_json::to_string(p).unwrap(),
            std::path::Path::new(&path),
            &l,
            &c,
        )
        .unwrap();
        serde_json::from_str::<serde_json::Value>(&reply).unwrap()
    };
    // 2^60 stable models. Query needs one full witness and one UNSAT probe.
    let v = call(&p);
    assert_eq!(v["status"], "consistent");
    assert_eq!(v["enumeration_complete"], false);
    assert_eq!(v["answers"][0]["skeptical"], true);
    assert_eq!(v["answers"][0]["credulous"], true);
    assert_eq!(v["models"].as_array().unwrap().len(), 1);
    p.operation = Operation::Enumerate;
    let v = call(&p);
    assert_eq!(v["status"], "inconclusive");
    assert!(v["answers"][0]["skeptical"].is_null());
}

#[test]
#[ignore = "central runner only: requires operator-pinned CLINGO_EXECUTABLE"]
fn clingo_matches_independent_oracle() {
    let path = std::env::var("CLINGO_EXECUTABLE").expect("pin native clingo executable");
    let l = Limits {
        milliseconds: 3000,
        ..Limits::default()
    };
    let c = AtomicBool::new(false);
    // All unordered pairs with repetition over the one-atom rule universe (8).
    let mut rules = vec![];
    for head in [None, Some(0)] {
        for pos in 0..2 {
            for neg in 0..2 {
                rules.push(Rule {
                    head,
                    positive: model(pos, 1),
                    negative: model(neg, 1),
                });
            }
        }
    }
    for i in 0..rules.len() {
        for j in i..rules.len() {
            let p = request(1, vec![rules[i].clone(), rules[j].clone()]);
            let expected: Vec<_> = (0..2)
                .filter(|&m| reference(&p, m))
                .map(|m| model(m, 1))
                .collect();
            let text = process::call(
                &serde_json::to_string(&p).unwrap(),
                std::path::Path::new(&path),
                &l,
                &c,
            )
            .unwrap();
            let v: serde_json::Value = serde_json::from_str(&text).unwrap();
            assert_eq!(
                v["status"],
                if expected.is_empty() {
                    "inconsistent"
                } else {
                    "consistent"
                },
                "{text}"
            );
            let mut actual: Vec<Vec<usize>> = serde_json::from_value(v["models"].clone()).unwrap();
            actual.sort();
            assert_eq!(actual, expected);
        }
    }
}
