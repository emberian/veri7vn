//! Independent finite truth and public-certificate refutations for graph layout.
use oracle_reasoning::graph::{check_forest, minimum_spanning_forest, GraphInput};
use oracle_reasoning::Limits;

// Floyd closure is deliberately independent of both Kruskal's union/find and
// the certificate checker's tree traversal/binary lifting.
fn closure(input: &GraphInput, selected: &[usize]) -> Vec<Vec<bool>> {
    let n = input.vertices;
    let mut reach = vec![vec![false; n]; n];
    for (i, row) in reach.iter_mut().enumerate() {
        row[i] = true;
    }
    for &id in selected {
        let (a, b, _) = input.edges[id];
        reach[a][b] = true;
        reach[b][a] = true;
    }
    for k in 0..n {
        for a in 0..n {
            for b in 0..n {
                reach[a][b] |= reach[a][k] && reach[k][b];
            }
        }
    }
    reach
}

fn truth(input: &GraphInput) {
    let limits = Limits::default();
    let all = closure(input, &(0..input.edges.len()).collect::<Vec<_>>());
    let components = (0..input.vertices)
        .filter(|&a| !(0..a).any(|b| all[a][b]))
        .count();
    let candidates: Vec<_> = (0..1usize << input.edges.len())
        .map(|mask| {
            let ids: Vec<_> = (0..input.edges.len())
                .filter(|&id| mask & (1 << id) != 0)
                .collect();
            let spanning_forest =
                ids.len() == input.vertices - components && closure(input, &ids) == all;
            let weight: i128 = ids.iter().map(|&id| i128::from(input.edges[id].2)).sum();
            (ids, spanning_forest, weight)
        })
        .collect();
    let optimum = candidates
        .iter()
        .filter(|(_, valid, _)| *valid)
        .map(|(_, _, w)| *w)
        .min()
        .unwrap();
    let result = minimum_spanning_forest(input, &limits).unwrap();
    assert_eq!(result.total_weight, optimum.to_string(), "{input:?}");
    assert_eq!(result.components, components, "{input:?}");
    assert_eq!(result.connected, input.vertices > 0 && components == 1);
    assert!(candidates
        .iter()
        .any(|(ids, valid, w)| *valid && *w == optimum && *ids == result.edge_ids));
    for (ids, valid, weight) in candidates {
        assert_eq!(
            check_forest(input, &ids, &limits).is_ok(),
            valid && weight == optimum,
            "{input:?}; {ids:?}"
        );
    }
}

#[test]
fn exhaustive_small_ordered_multigraphs_and_every_certificate_subset() {
    // Every sequence of up to three edges on <=3 vertices, including parallel
    // edges, loops, disconnected vertices, negative weights and all equal ties.
    for vertices in 0..=3 {
        let mut alphabet = Vec::new();
        for a in 0..vertices {
            for b in a..vertices {
                for weight in -1..=1 {
                    alphabet.push((a, b, weight));
                }
            }
        }
        truth(&GraphInput {
            vertices,
            edges: Vec::new(),
        });
        if alphabet.is_empty() {
            continue;
        }
        for len in 1..=3 {
            for mut encoded in 0..alphabet.len().pow(len) {
                let mut edges = Vec::new();
                for _ in 0..len {
                    edges.push(alphabet[encoded % alphabet.len()]);
                    encoded /= alphabet.len();
                }
                truth(&GraphInput { vertices, edges });
            }
        }
    }
}

fn previous_petgraph_ids(input: &GraphInput) -> Vec<usize> {
    use petgraph::{algo::min_spanning_tree, data::Element, graph::UnGraph};
    let mut graph = UnGraph::<(), (i64, usize)>::with_capacity(input.vertices, input.edges.len());
    for _ in 0..input.vertices {
        graph.add_node(());
    }
    for (id, &(a, b, weight)) in input.edges.iter().enumerate() {
        graph.add_edge((a as u32).into(), (b as u32).into(), (weight, id));
    }
    let mut ids: Vec<_> = min_spanning_tree(&graph)
        .filter_map(|item| match item {
            Element::Edge {
                weight: (_, id), ..
            } => Some(id),
            _ => None,
        })
        .collect();
    ids.sort_unstable();
    ids
}

#[test]
fn deterministic_ids_match_previous_heap_for_ties_parallel_and_reversed_edges() {
    for shift in 0..32 {
        let mut edges = vec![(2, 0, 0), (0, 2, 0), (1, 2, 0), (0, 1, 0), (3, 3, i64::MIN)];
        for i in 0..40 {
            edges.push(((i + shift) % 6, (i * 5 + shift) % 6, (i % 3) as i64 - 1));
        }
        edges.rotate_left(shift);
        let input = GraphInput { vertices: 7, edges };
        assert_eq!(
            minimum_spanning_forest(&input, &Limits::default())
                .unwrap()
                .edge_ids,
            previous_petgraph_ids(&input)
        );
    }
}

#[test]
fn flat_lifting_boundaries_and_public_checker_refutations() {
    let limits = Limits::default();
    // Crosses the 16-vertex lifting boundary; negative sentinel is also a real
    // legal weight. Leave one isolated component and a harmless negative loop.
    let mut edges: Vec<_> = (0..16).map(|i| (i, i + 1, i64::MIN)).collect();
    edges.extend([(0, 16, i64::MIN + 1), (17, 17, i64::MIN)]);
    let input = GraphInput {
        vertices: 18,
        edges,
    };
    let ids: Vec<_> = (0..16).collect();
    assert_eq!(check_forest(&input, &ids, &limits).unwrap(), 2);
    assert_eq!(
        minimum_spanning_forest(&input, &limits).unwrap().edge_ids,
        ids
    );
    let mut nonminimal = ids.clone();
    nonminimal[15] = 16;
    assert!(check_forest(&input, &nonminimal, &limits).is_err());
    for invalid in [
        vec![0, 0],
        vec![17],
        vec![usize::MAX],
        vec![],
        vec![0, 1, 16],
    ] {
        assert!(check_forest(&input, &invalid, &limits).is_err());
    }
    let invalid = GraphInput {
        vertices: 1,
        edges: vec![(0, 1, 0)],
    };
    assert!(check_forest(&invalid, &[], &limits).is_err());
    let too_small = Limits {
        vertices: 1,
        ..limits
    };
    assert!(check_forest(&input, &ids, &too_small).is_err());
}

struct Meter {
    context: oracle_execution::ExecutionContext,
    charged: std::sync::atomic::AtomicU64,
    charges: std::sync::atomic::AtomicUsize,
    checks: std::sync::atomic::AtomicUsize,
    cancel_at: usize,
}
impl Meter {
    fn new(fuel: u64, cancel_at: usize) -> Self {
        Self {
            context: oracle_execution::ExecutionContext::new(
                fuel,
                std::time::Duration::from_secs(60),
                oracle_execution::Cancellation::default(),
            )
            .unwrap(),
            charged: 0.into(),
            charges: 0.into(),
            checks: 0.into(),
            cancel_at,
        }
    }
}
impl oracle_execution::WorkControl for Meter {
    fn checkpoint(&self, work: u64) -> oracle_execution::Result<()> {
        self.context.spend(work)?;
        self.charged
            .fetch_add(work, std::sync::atomic::Ordering::Relaxed);
        self.charges
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        Ok(())
    }
    fn check(&self) -> oracle_execution::Result<()> {
        let checked = self
            .checks
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            + 1;
        if checked == self.cancel_at {
            self.context.cancellation().cancel();
        }
        self.context.check()
    }
}

#[test]
fn known_checker_blocks_keep_exact_total_with_separate_iteration_checks() {
    use std::sync::atomic::Ordering::Relaxed;
    let input = GraphInput {
        vertices: 2,
        edges: vec![(0, 1, 3)],
    };
    // 1 selected +2 prefix +1 fill +2 root visits +2 DFS pops +2
    // adjacency visits +1 level header +2 lifting cells +1 edge +2 lifts.
    let control = Meter::new(16, usize::MAX);
    assert_eq!(
        oracle_reasoning::graph::check_forest_controlled(
            &input,
            &[0],
            &Limits::default(),
            &control
        )
        .unwrap(),
        1
    );
    assert_eq!(control.charged.load(Relaxed), 16);
    assert_eq!(control.charges.load(Relaxed), 13);
    assert_eq!(control.checks.load(Relaxed), 7);
    control.context.check().unwrap();
    assert_eq!(
        control.context.spend(1),
        Err(oracle_execution::ExecutionError::FuelExhausted)
    );
    // Successful producer work was and remains V+2E, before the same checker.
    let solve_control = Meter::new(20, usize::MAX);
    oracle_reasoning::graph::minimum_spanning_forest_controlled(
        &input,
        &Limits::default(),
        &solve_control,
    )
    .unwrap();
    assert_eq!(solve_control.charged.load(Relaxed), 20);
}

#[test]
fn insufficient_checker_block_and_midblock_cancel_stop_before_later_work() {
    use std::sync::atomic::Ordering::Relaxed;
    let input = GraphInput {
        vertices: 4,
        edges: vec![(0, 1, 1), (1, 2, 1), (2, 3, 1)],
    };
    // Selection scan costs 3; the next complete prefix block requires 4.
    let insufficient = Meter::new(6, usize::MAX);
    assert!(oracle_reasoning::graph::check_forest_controlled(
        &input,
        &[0, 1, 2],
        &Limits::default(),
        &insufficient
    )
    .is_err());
    assert_eq!(insufficient.charged.load(Relaxed), 3);
    assert_eq!(insufficient.checks.load(Relaxed), 0);
    assert_eq!(
        insufficient.context.check(),
        Err(oracle_execution::ExecutionError::FuelExhausted)
    );
    let cancelled = Meter::new(30, 2);
    assert!(oracle_reasoning::graph::check_forest_controlled(
        &input,
        &[0, 1, 2],
        &Limits::default(),
        &cancelled
    )
    .is_err());
    assert_eq!(cancelled.charged.load(Relaxed), 7);
    assert_eq!(cancelled.charges.load(Relaxed), 4);
    assert_eq!(cancelled.checks.load(Relaxed), 2);
    assert_eq!(
        cancelled.context.check(),
        Err(oracle_execution::ExecutionError::Cancelled)
    );
}
