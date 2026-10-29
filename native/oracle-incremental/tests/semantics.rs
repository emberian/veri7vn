use oracle_incremental::{
    evaluate, recompute, Answer, Direction, Epoch, Limits, Mutation, Query, Request,
};

fn insert(id: &str, from: u32, to: u32) -> Mutation {
    Mutation::Insert {
        fact_id: id.into(),
        from,
        to,
    }
}
fn retract(id: &str) -> Mutation {
    Mutation::Retract { fact_id: id.into() }
}
fn epoch(version: u64, mutations: Vec<Mutation>) -> Epoch {
    Epoch {
        version,
        mutations,
        queries: vec![
            Query::Reachable { from: 0, to: 3 },
            Query::Reachable { from: 1, to: 1 },
            Query::Impact {
                roots: vec![0],
                direction: Direction::Downstream,
                include_roots: true,
            },
            Query::Impact {
                roots: vec![3],
                direction: Direction::Upstream,
                include_roots: false,
            },
        ],
    }
}
fn request(epochs: Vec<Epoch>) -> Request {
    Request {
        scope: "test/private-v1".into(),
        nodes: vec![0, 1, 2, 3, 99],
        epochs,
    }
}
fn compare(request: Request) -> oracle_incremental::Response {
    let actual = evaluate(request.clone(), Limits::default()).unwrap();
    let reference = recompute(&request, &Limits::default()).unwrap();
    assert_eq!(actual.epochs.len(), reference.epochs.len());
    for (a, b) in actual.epochs.iter().zip(reference.epochs) {
        assert_eq!(a.delta, b.delta, "delta at {}", a.version);
        assert_eq!(a.answers, b.answers, "answers at {}", a.version);
        assert_eq!(a.reachable_pairs, b.reachable_pairs);
        assert!(a.settled);
        assert!(
            a.frontier.iter().all(|t| *t > a.version),
            "unsettled frontier"
        );
    }
    actual
}

#[test]
fn duplicate_support_last_support_cycles_and_settled_versions() {
    let response = compare(request(vec![
        epoch(
            0,
            vec![
                insert("a", 0, 1),
                insert("b", 0, 1),
                insert("c", 1, 2),
                insert("d", 2, 1),
                insert("e", 2, 3),
            ],
        ),
        epoch(1, vec![retract("a")]),
        epoch(8, vec![retract("b")]),
        epoch(9, vec![retract("d")]),
        epoch(10, vec![retract("c"), retract("e")]),
    ]));
    assert!(
        response.epochs[1].delta.is_empty(),
        "one of two supports is insufficient to retract"
    );
    assert_eq!(response.epochs[1].live_facts, 4);
    assert_eq!(response.epochs[1].distinct_edges, 4);
    assert!(matches!(
        response.epochs[1].answers[0],
        Answer::Reachable {
            reachable: true,
            ..
        }
    ));
    assert!(matches!(
        response.epochs[2].answers[0],
        Answer::Reachable {
            reachable: false,
            ..
        }
    ));
    assert!(matches!(
        response.epochs[2].answers[1],
        Answer::Reachable {
            reachable: true,
            ..
        }
    ));
    assert!(matches!(
        response.epochs[3].answers[1],
        Answer::Reachable {
            reachable: false,
            ..
        }
    ));
    assert_eq!(response.epochs[4].reachable_pairs, 0);
}

#[test]
fn alternate_path_survives_then_last_path_disappears() {
    let response = compare(request(vec![
        epoch(
            4,
            vec![
                insert("a", 0, 1),
                insert("b", 1, 3),
                insert("c", 0, 2),
                insert("d", 2, 3),
            ],
        ),
        epoch(5, vec![retract("b")]),
        epoch(6, vec![retract("d")]),
    ]));
    assert!(matches!(
        response.epochs[1].answers[0],
        Answer::Reachable {
            reachable: true,
            ..
        }
    ));
    assert!(matches!(
        response.epochs[2].answers[0],
        Answer::Reachable {
            reachable: false,
            ..
        }
    ));
}

#[test]
fn atomic_remove_reinsert_same_fact_id_has_no_observable_delta() {
    let response = compare(request(vec![
        epoch(1, vec![insert("a", 0, 1)]),
        epoch(2, vec![retract("a"), insert("a", 0, 1)]),
    ]));
    assert!(response.epochs[1].delta.is_empty());
}

#[test]
fn scopes_are_isolated_even_with_identical_node_and_fact_ids() {
    let populated = compare(request(vec![epoch(1, vec![insert("a", 0, 3)])]));
    let mut empty = request(vec![epoch(1, vec![])]);
    empty.scope = "another-private-tenant".into();
    let empty = compare(empty);
    assert_ne!(populated.scope, empty.scope);
    assert_eq!(empty.epochs[0].reachable_pairs, 0);
    assert!(matches!(
        empty.epochs[0].answers[0],
        Answer::Reachable {
            reachable: false,
            ..
        }
    ));
}

#[test]
fn cycle_deletion_does_not_leave_self_supported_reachability() {
    let response = compare(request(vec![
        epoch(
            1,
            vec![insert("a", 0, 1), insert("b", 1, 2), insert("c", 2, 0)],
        ),
        epoch(2, vec![retract("a")]),
        epoch(3, vec![retract("b"), retract("c")]),
    ]));
    assert_eq!(response.epochs[0].reachable_pairs, 9);
    assert_eq!(response.epochs[1].reachable_pairs, 3);
    assert_eq!(response.epochs[2].reachable_pairs, 0);
}

#[test]
fn self_loop_is_nonempty_path_but_isolated_identity_is_not() {
    let mut r = request(vec![
        epoch(1, vec![insert("loop", 0, 0)]),
        epoch(2, vec![retract("loop")]),
    ]);
    r.epochs[0].queries = vec![
        Query::Reachable { from: 0, to: 0 },
        Query::Reachable { from: 99, to: 99 },
    ];
    let response = compare(r);
    assert!(matches!(
        response.epochs[0].answers[0],
        Answer::Reachable {
            reachable: true,
            ..
        }
    ));
    assert!(matches!(
        response.epochs[0].answers[1],
        Answer::Reachable {
            reachable: false,
            ..
        }
    ));
}

#[test]
fn deterministic_mixed_updates_match_fresh_recomputation_every_epoch() {
    // Four nodes => cycles, self loops and duplicate supports are common. State
    // is generated without a random dependency and retains all 96 transitions.
    let mut state = 0x3a7d_0041u64;
    let mut live = std::collections::BTreeMap::<usize, (u32, u32)>::new();
    let mut epochs = Vec::new();
    for version in 0..96 {
        state = state.wrapping_mul(6364136223846793005).wrapping_add(1);
        let id = ((state >> 16) % 24) as usize;
        let mutation = if live.remove(&id).is_some() {
            retract(&format!("s{id}"))
        } else {
            let from = ((state >> 32) % 4) as u32;
            let to = ((state >> 48) % 4) as u32;
            live.insert(id, (from, to));
            insert(&format!("s{id}"), from, to)
        };
        epochs.push(epoch(version, vec![mutation]));
    }
    compare(request(epochs));
}

#[test]
fn admission_rejects_invalid_history_before_running_any_epoch() {
    for (r, code) in [
        (
            request(vec![epoch(1, vec![retract("missing")])]),
            "unknown_fact_id",
        ),
        (
            request(vec![epoch(1, vec![insert("a", 0, 1), insert("a", 0, 2)])]),
            "duplicate_fact_id",
        ),
        (
            request(vec![epoch(2, vec![]), epoch(2, vec![])]),
            "invalid_version",
        ),
        (request(vec![epoch(u64::MAX, vec![])]), "invalid_version"),
        (
            request(vec![epoch(1, vec![insert("a", 0, 7)])]),
            "unknown_node",
        ),
    ] {
        assert_eq!(evaluate(r, Limits::default()).unwrap_err().code, code);
    }
    let limits = Limits {
        max_relation_pairs: 24,
        ..Limits::default()
    };
    assert_eq!(
        evaluate(request(vec![]), limits).unwrap_err().code,
        "state_limit"
    );
}

#[test]
fn step_event_and_response_limits_refuse_without_partial_results() {
    let r = request(vec![epoch(0, vec![insert("a", 0, 3)])]);
    let no_steps = Limits {
        max_steps_per_epoch: 0,
        ..Limits::default()
    };
    assert_eq!(
        evaluate(r.clone(), no_steps).unwrap_err().code,
        "cooperative_budget"
    );
    let no_events = Limits {
        max_output_events_per_epoch: 0,
        ..Limits::default()
    };
    assert_eq!(
        evaluate(r.clone(), no_events).unwrap_err().code,
        "output_event_limit"
    );
    let no_response = Limits {
        max_response_items: 0,
        ..Limits::default()
    };
    assert_eq!(evaluate(r, no_response).unwrap_err().code, "response_limit");
    // A refusal must not retain a graph or poison later requests.
    assert_eq!(
        compare(request(vec![epoch(1, vec![])])).epochs[0].reachable_pairs,
        0
    );
}

#[test]
fn json_boundary_has_fixed_limits_and_explicit_discovery() {
    let r = request(vec![epoch(1, vec![insert("a", 0, 3)])]);
    let text = serde_json::to_string(&r).unwrap();
    let result: serde_json::Value =
        serde_json::from_str(&oracle_incremental::call_json(&text)).unwrap();
    assert_eq!(result["status"], "ok");
    assert_eq!(result["result"]["epochs"][0]["reachable_pairs"], 1);
    let oversized = " ".repeat(oracle_incremental::MAX_REQUEST_BYTES + 1);
    let refused: serde_json::Value =
        serde_json::from_str(&oracle_incremental::call_json(&oversized)).unwrap();
    assert_eq!(refused["error"]["code"], "request_bytes_limit");
    let mut with_limits = serde_json::to_value(r).unwrap();
    with_limits["limits"] = serde_json::json!({"max_nodes":u64::MAX});
    let refused: serde_json::Value =
        serde_json::from_str(&oracle_incremental::call_json(&with_limits.to_string())).unwrap();
    assert_eq!(refused["error"]["code"], "invalid_json");
    let catalog = oracle_incremental::catalog();
    assert_eq!(catalog["hard_cpu_or_rss_limit"], false);
    assert_eq!(catalog["threads_created"], 0);
    assert_eq!(catalog["limits"]["max_nodes"], 128);
}
