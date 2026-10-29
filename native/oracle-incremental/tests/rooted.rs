use oracle_incremental::rooted::RootedOperation;
use oracle_incremental::{
    evaluate_rooted, recompute, Limits, Request, RootedRequest, RootedResponse, Roots, Strategy,
};
use serde_json::json;

fn sample() -> RootedRequest {
    RootedRequest {
        operation: RootedOperation::RootedV2,
        roots: Roots {
            downstream: vec![0],
            upstream: vec![3],
        },
        graph: serde_json::from_str(include_str!("../examples/supports-cycle.json")).unwrap(),
    }
}
fn compare(request: RootedRequest) -> (RootedResponse, RootedResponse) {
    let limits = Limits::default();
    let fresh = evaluate_rooted(request.clone(), limits.clone(), Strategy::Fresh).unwrap();
    let maintained =
        evaluate_rooted(request.clone(), limits.clone(), Strategy::Differential).unwrap();
    let all = recompute(&request.graph, &limits).unwrap();
    assert_eq!(fresh.result.epochs.len(), all.epochs.len());
    for ((a, b), full) in fresh
        .result
        .epochs
        .iter()
        .zip(&maintained.result.epochs)
        .zip(all.epochs)
    {
        assert_eq!(a.delta, b.delta, "rooted delta version {}", a.version);
        assert_eq!(a.answers, b.answers);
        assert_eq!(a.reachable_pairs, b.reachable_pairs);
        assert_eq!(
            a.answers, full.answers,
            "query answers independent all-pairs BFS"
        );
        let projection: Vec<_> = full
            .delta
            .into_iter()
            .filter(|r| {
                request.roots.downstream.contains(&r.from) || request.roots.upstream.contains(&r.to)
            })
            .collect();
        assert_eq!(a.delta, projection, "rooted deltas are exact projection");
        assert!(a.settled && b.settled);
        assert!(a.frontier.iter().chain(&b.frontier).all(|t| *t > a.version));
    }
    (fresh, maintained)
}

#[test]
fn fixed_roots_preserve_supports_retractions_cycles_and_union() {
    let mut request = sample();
    // The demo also asks whether 1 reaches itself; admit 1 as a downstream root.
    request.roots.downstream.push(1);
    let (fresh, _) = compare(request);
    assert!(fresh.result.epochs[1].delta.is_empty());
    assert_eq!(fresh.result.epochs[0].reachable_pairs, 7);
    // (0,3) is visible from both directions but is reported once.
    assert_eq!(
        fresh.result.epochs[0]
            .delta
            .iter()
            .filter(|r| r.from == 0 && r.to == 3)
            .count(),
        1
    );
}

#[test]
fn entirely_removed_cycle_and_alternate_support_match_independent_reference() {
    let graph:Request=serde_json::from_value(json!({"scope":"rooted/cycle","nodes":[0,1,2,3,99],"epochs":[
        {"version":0,"mutations":[
            {"op":"insert","fact_id":"a","from":0,"to":1},
            {"op":"insert","fact_id":"b","from":0,"to":1},
            {"op":"insert","fact_id":"c","from":1,"to":2},
            {"op":"insert","fact_id":"d","from":2,"to":0},
            {"op":"insert","fact_id":"e","from":2,"to":3}],
         "queries":[{"op":"reachable","from":0,"to":0},{"op":"impact","roots":[0],"direction":"downstream"}]},
        {"version":3,"mutations":[{"op":"retract","fact_id":"a"}]},
        {"version":8,"mutations":[{"op":"retract","fact_id":"b"}]},
        {"version":10,"mutations":[{"op":"retract","fact_id":"c"},{"op":"retract","fact_id":"d"},{"op":"retract","fact_id":"e"}]}
    ]})).unwrap();
    let (fresh, _) = compare(RootedRequest {
        operation: RootedOperation::RootedV2,
        roots: Roots {
            downstream: vec![0],
            upstream: vec![3],
        },
        graph,
    });
    assert_eq!(fresh.result.epochs.last().unwrap().reachable_pairs, 0);
}

#[test]
fn random_updates_and_both_directions_match_full_bfs_projection() {
    let mut state = 17u64;
    let mut live = std::collections::BTreeSet::new();
    let mut epochs = Vec::new();
    for version in 0..96 {
        state = state.wrapping_mul(6364136223846793005).wrapping_add(1);
        let id = (state >> 16) % 24;
        let change = if live.remove(&id) {
            json!({"op":"retract","fact_id":format!("s{id}")})
        } else {
            live.insert(id);
            json!({"op":"insert","fact_id":format!("s{id}"),"from":(state>>32)%8,"to":(state>>48)%8})
        };
        epochs.push(json!({"version":version,"mutations":[change],"queries":[
            {"op":"reachable","from":0,"to":7},
            {"op":"impact","roots":[0,3],"direction":"downstream","include_roots":true},
            {"op":"impact","roots":[7],"direction":"upstream"}]}));
    }
    let graph = serde_json::from_value(
        json!({"scope":"rooted/mixed","nodes":(0..8).collect::<Vec<_>>(),"epochs":epochs}),
    )
    .unwrap();
    compare(RootedRequest {
        operation: RootedOperation::RootedV2,
        roots: Roots {
            downstream: vec![0, 3],
            upstream: vec![7],
        },
        graph,
    });
}

#[test]
fn query_outside_fixed_roots_and_unknown_roots_are_refused_for_both_strategies() {
    for strategy in [Strategy::Fresh, Strategy::Differential] {
        assert_eq!(
            evaluate_rooted(sample(), Limits::default(), strategy)
                .unwrap_err()
                .code,
            "untracked_query"
        );
        let mut r = sample();
        r.roots.upstream.push(1000);
        assert_eq!(
            evaluate_rooted(r, Limits::default(), strategy)
                .unwrap_err()
                .code,
            "invalid_roots"
        );
    }
}

#[test]
fn rooted_admission_uses_root_times_nodes_not_unconditional_square() {
    let graph:Request=serde_json::from_value(json!({"scope":"large/universe","nodes":(0..512).collect::<Vec<_>>(),"epochs":[{"version":4,"mutations":[{"op":"insert","fact_id":"a","from":0,"to":511}],"queries":[{"op":"reachable","from":0,"to":511}]}]})).unwrap();
    let request = RootedRequest {
        operation: RootedOperation::RootedV2,
        roots: Roots {
            downstream: vec![0],
            upstream: vec![],
        },
        graph,
    };
    let limits = Limits {
        max_nodes: 512,
        max_relation_pairs: 512,
        ..Limits::default()
    };
    for strategy in [Strategy::Fresh, Strategy::Differential] {
        let result = evaluate_rooted(request.clone(), limits.clone(), strategy).unwrap();
        assert_eq!(result.possible_pairs_bound, 512);
        assert_eq!(result.result.epochs[0].reachable_pairs, 1);
    }
}

#[test]
fn both_engines_enforce_response_output_and_deadline_budgets() {
    let graph:Request=serde_json::from_value(json!({"scope":"budget","nodes":[0,1],"epochs":[{"version":0,"mutations":[{"op":"insert","fact_id":"a","from":0,"to":1}]}]})).unwrap();
    let request = RootedRequest {
        operation: RootedOperation::RootedV2,
        roots: Roots {
            downstream: vec![0],
            upstream: vec![],
        },
        graph,
    };
    for strategy in [Strategy::Fresh, Strategy::Differential] {
        for (limits, code) in [
            (
                Limits {
                    max_response_items: 0,
                    ..Limits::default()
                },
                "response_limit",
            ),
            (
                Limits {
                    max_output_events_per_epoch: 0,
                    ..Limits::default()
                },
                "output_event_limit",
            ),
            (
                Limits {
                    max_elapsed_ms: 0,
                    ..Limits::default()
                },
                "cooperative_budget",
            ),
        ] {
            assert_eq!(
                evaluate_rooted(request.clone(), limits, strategy)
                    .unwrap_err()
                    .code,
                code
            );
        }
    }
    assert_eq!(
        evaluate_rooted(
            request.clone(),
            Limits {
                max_fresh_work_per_epoch: 0,
                ..Limits::default()
            },
            Strategy::Fresh
        )
        .unwrap_err()
        .code,
        "cooperative_budget"
    );
    assert_eq!(
        evaluate_rooted(
            request,
            Limits {
                max_steps_per_epoch: 0,
                ..Limits::default()
            },
            Strategy::Differential
        )
        .unwrap_err()
        .code,
        "cooperative_budget"
    );
}

#[test]
fn json_v2_defaults_to_fresh_and_host_can_select_maintained_without_wire_policy() {
    let mut request = sample();
    request.roots.downstream.push(1);
    let text = serde_json::to_string(&request).unwrap();
    let fresh: serde_json::Value =
        serde_json::from_str(&oracle_incremental::call_json(&text)).unwrap();
    assert_eq!(fresh["status"], "ok");
    assert_eq!(fresh["result"]["strategy"], "fresh");
    let maintained: serde_json::Value = serde_json::from_str(
        &oracle_incremental::call_json_with_strategy(&text, Strategy::Differential),
    )
    .unwrap();
    assert_eq!(maintained["result"]["strategy"], "differential");
    let mut injected = serde_json::to_value(request).unwrap();
    injected["strategy"] = json!("differential");
    let refused: serde_json::Value =
        serde_json::from_str(&oracle_incremental::call_json(&injected.to_string())).unwrap();
    assert_eq!(refused["status"], "refused");
    let duplicate = r#"{"scope":"a","scope":"b","nodes":[],"epochs":[]}"#;
    let refused: serde_json::Value =
        serde_json::from_str(&oracle_incremental::call_json(duplicate)).unwrap();
    assert_eq!(
        refused["status"], "refused",
        "legacy duplicate-field rejection preserved"
    );
}

#[test]
fn empty_root_view_and_sparse_identifiers_remain_isolated() {
    let request:RootedRequest=serde_json::from_value(json!({"operation":"rooted_v2","roots":{"downstream":[],"upstream":[]},"graph":{"scope":"empty/roots","nodes":[1,1000,4000000000u32],"epochs":[{"version":7,"mutations":[{"op":"insert","fact_id":"edge","from":1000,"to":4000000000u32}]}]}})).unwrap();
    let (fresh, _) = compare(request);
    assert_eq!(fresh.possible_pairs_bound, 0);
    assert_eq!(fresh.result.epochs[0].reachable_pairs, 0);
}
