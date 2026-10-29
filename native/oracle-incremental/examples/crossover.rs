//! Synthetic crossover matrix. Explicit host limits/policy, cold and warm times.
//! This is not a load test or a specialist-panel score.
use oracle_incremental::rooted::RootedOperation;
use oracle_incremental::{
    evaluate_rooted, Epoch, Limits, Mutation, Query, Request, RootedRequest, RootedResponse, Roots,
    Strategy,
};
use serde_json::json;
use std::time::Instant;

fn edge(id: usize, a: u32, b: u32) -> Mutation {
    Mutation::Insert {
        fact_id: format!("e{id}"),
        from: a,
        to: b,
    }
}

fn workload(kind: &str, n: u32, roots: usize, epochs: u64) -> RootedRequest {
    let mut initial = Vec::new();
    let mut id = 0;
    let (a, b) = if kind == "chain_tail" {
        for i in 0..n - 1 {
            initial.push(edge(id, i, i + 1));
            id += 1;
        }
        (n - 2, n - 1)
    } else {
        // A shallow two-hop graph reaches almost all nodes. Multiple roots
        // duplicate traversal demand without lengthening the fixed-point loop.
        let middle = roots as u32;
        for r in 0..roots as u32 {
            initial.push(edge(id, r, middle));
            id += 1;
        }
        for v in middle + 1..n - 2 {
            initial.push(edge(id, middle, v));
            id += 1;
        }
        if kind == "unrelated_toggle" {
            (n - 2, n - 1)
        } else {
            (middle, n - 3)
        }
    };
    // A distinct support ID is toggled; for duplicate_support the base support
    // remains, so input revisions should produce no view changes.
    let toggle: String = if kind == "duplicate_support" {
        "duplicate".into()
    } else {
        "toggle".into()
    };
    initial.push(Mutation::Insert {
        fact_id: toggle.clone(),
        from: a,
        to: b,
    });
    // For unrelated/affected edge toggles avoid a base duplicate, except where
    // the duplicate-support workload intentionally keeps it.
    if kind == "chain_tail" || kind == "affected_toggle" {
        initial.retain(|m| !matches!(m,Mutation::Insert {fact_id,from,to} if fact_id != &toggle && *from==a && *to==b));
    }
    let query = Query::Reachable {
        from: 0,
        to: if kind == "chain_tail" { n - 1 } else { n - 3 },
    };
    let mut history = vec![Epoch {
        version: 0,
        mutations: initial,
        queries: vec![query.clone()],
    }];
    for version in 1..epochs {
        let mutation = if version % 2 == 1 {
            Mutation::Retract {
                fact_id: toggle.clone(),
            }
        } else {
            Mutation::Insert {
                fact_id: toggle.clone(),
                from: a,
                to: b,
            }
        };
        history.push(Epoch {
            version,
            mutations: vec![mutation],
            queries: vec![query.clone()],
        });
    }
    RootedRequest {
        operation: RootedOperation::RootedV2,
        roots: Roots {
            downstream: (0..roots as u32).collect(),
            upstream: vec![],
        },
        graph: Request {
            scope: format!("crossover/{kind}/{n}/{roots}"),
            nodes: (0..n).collect(),
            epochs: history,
        },
    }
}

fn summary(response: &RootedResponse, total: u128) -> serde_json::Value {
    let epochs = &response.result.epochs;
    let mut warm: Vec<_> = epochs.iter().skip(1).map(|e| e.elapsed_us).collect();
    warm.sort_unstable();
    json!({"total_us":total,"first_epoch_us":epochs.first().map(|e|e.elapsed_us),
        "warm_median_us":warm.get(warm.len()/2),"warm_p95_us":warm.get(warm.len().saturating_sub(1)*95/100),
        "sum_epoch_us":epochs.iter().map(|e|e.elapsed_us).sum::<u64>(),
        "max_live_view_pairs":epochs.iter().map(|e|e.reachable_pairs).max(),
        "reported_delta_rows":epochs.iter().map(|e|e.delta.len()).sum::<usize>(),
        "observed_output_events":epochs.iter().map(|e|e.observed_output_events).sum::<u64>(),
        "fresh_work":response.fresh_work.iter().sum::<u64>(),
        "per_epoch_us":epochs.iter().map(|e|e.elapsed_us).collect::<Vec<_>>()})
}

fn main() {
    let mut rows = Vec::new();
    for (kind, n, roots, epochs) in [
        ("chain_tail", 48, 1, 80),
        ("unrelated_toggle", 1024, 1, 128),
        ("unrelated_toggle", 1024, 16, 128),
        ("duplicate_support", 1024, 16, 128),
        ("affected_toggle", 1024, 16, 128),
        ("unrelated_toggle", 4096, 32, 128),
        ("affected_toggle", 4096, 32, 128),
    ] {
        let request = workload(kind, n, roots, epochs);
        let limits = Limits {
            max_nodes: n as usize,
            max_live_facts: 16384,
            max_relation_pairs: roots * n as usize,
            max_response_items: 2_000_000,
            max_elapsed_ms: 30_000,
            ..Limits::default()
        };
        let mut outcomes = Vec::new();
        // Alternate order across rows; no assertion of rigorous statistical
        // isolation. Each invocation includes a newly initialized provider.
        let strategies = if roots == 1 {
            [Strategy::Fresh, Strategy::Differential]
        } else {
            [Strategy::Differential, Strategy::Fresh]
        };
        let mut fresh = None;
        let mut maintained = None;
        for strategy in strategies {
            let start = Instant::now();
            match evaluate_rooted(request.clone(), limits.clone(), strategy) {
                Err(error) => outcomes.push(json!({"strategy":strategy,"error":error})),
                Ok(response) => {
                    let elapsed = start.elapsed().as_micros();
                    outcomes.push(
                        json!({"strategy":strategy,"measurements":summary(&response,elapsed)}),
                    );
                    match strategy {
                        Strategy::Fresh => fresh = Some(response),
                        Strategy::Differential => maintained = Some(response),
                    }
                }
            }
        }
        let semantic_match = match (&fresh, &maintained) {
            (Some(a), Some(b)) => Some(
                a.result.epochs.len() == b.result.epochs.len()
                    && a.result.epochs.iter().zip(&b.result.epochs).all(|(a, b)| {
                        a.version == b.version
                            && a.delta == b.delta
                            && a.answers == b.answers
                            && a.reachable_pairs == b.reachable_pairs
                    }),
            ),
            _ => None,
        };
        rows.push(
            json!({"workload":kind,"nodes":n,"fixed_downstream_roots":roots,"epochs":epochs,
            "semantic_match":semantic_match,"host_limits":limits,"outcomes":outcomes}),
        );
    }
    println!(
        "{}",
        json!({"schema":1,"default_policy":"fresh; explicit host override only",
        "measurement":"cold total includes request cloning, preflight, provider setup, output and provider destruction; warm epoch excludes preflight/setup/destruction; RSS not measured; one trial per row; no automatic crossover inferred",
        "rows":rows})
    );
}
