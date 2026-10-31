use crate::{Error, Limits, Result};
use petgraph::{algo::min_spanning_tree, data::Element, graph::UnGraph};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::time::Instant;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct GraphInput {
    pub vertices: usize,
    pub edges: Vec<(usize, usize, i64)>,
}

#[derive(Debug, Serialize)]
pub struct Forest {
    pub schema: &'static str,
    pub edge_ids: Vec<usize>,
    /// Decimal string: sums can exceed the JSON/JavaScript exact-integer range.
    pub total_weight: String,
    pub components: usize,
    pub connected: bool,
    pub check: &'static str,
    pub build_us: u128,
    pub search_us: u128,
    pub check_us: u128,
}

fn validate(input: &GraphInput, limits: &Limits) -> Result<()> {
    if input.vertices > limits.vertices || input.edges.len() > limits.edges {
        return Err(Error::Limit("graph size"));
    }
    // Also establishes that all possible i64 edge sums fit i128.
    if input.vertices >= u32::MAX as usize || input.edges.len() >= u32::MAX as usize {
        return Err(Error::Limit("graph index range"));
    }
    if input
        .edges
        .iter()
        .any(|(a, b, _)| *a >= input.vertices || *b >= input.vertices)
    {
        return Err(Error::Invalid(
            "edge endpoint outside declared vertices".into(),
        ));
    }
    Ok(())
}

pub fn minimum_spanning_forest(input: &GraphInput, limits: &Limits) -> Result<Forest> {
    minimum_spanning_forest_controlled(input, limits, &std::sync::atomic::AtomicBool::new(false))
}
pub fn minimum_spanning_forest_controlled(
    input: &GraphInput,
    limits: &Limits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<Forest> {
    let started = Instant::now();
    validate(input, limits)?;
    let mut graph = UnGraph::<(), (i64, usize)>::with_capacity(input.vertices, input.edges.len());
    for _ in 0..input.vertices {
        crate::checkpoint(control, 1)?;
        graph.add_node(());
    }
    for (id, &(a, b, weight)) in input.edges.iter().enumerate() {
        crate::checkpoint(control, 1)?;
        graph.add_edge((a as u32).into(), (b as u32).into(), (weight, id));
    }
    let build_us = started.elapsed().as_micros();
    let search_started = Instant::now();
    // The second key makes tie choices deterministic and preserves parallel-edge IDs.
    let mut selected: Vec<_> = min_spanning_tree(&graph)
        .filter_map(|element| match element {
            Element::Edge {
                weight: (_, id), ..
            } => Some(id),
            Element::Node { .. } => None,
        })
        .collect();
    crate::checkpoint(control, input.edges.len() as u64)?;
    selected.sort_unstable();
    let search_us = search_started.elapsed().as_micros();
    let check_started = Instant::now();
    let components = check_forest_controlled(input, &selected, limits, control)?;
    let total: i128 = selected.iter().map(|&i| i128::from(input.edges[i].2)).sum();
    Ok(Forest {
        schema: "oracle-minimum-spanning-forest-v1",
        edge_ids: selected,
        total_weight: total.to_string(),
        components,
        connected: input.vertices > 0 && components == 1,
        check: "independent Rust forest coverage and cycle-optimality check; not an Isabelle certificate",
        build_us,
        search_us,
        check_us: check_started.elapsed().as_micros(),
    })
}

/// Independent of petgraph/Kruskal: verify a forest, its component coverage, and
/// that no graph edge can replace a heavier edge on its forest path.
/// Binary lifting makes the check O((V+E) log V), including disconnected graphs.
pub fn check_forest(input: &GraphInput, selected: &[usize], limits: &Limits) -> Result<usize> {
    check_forest_controlled(
        input,
        selected,
        limits,
        &std::sync::atomic::AtomicBool::new(false),
    )
}
pub fn check_forest_controlled(
    input: &GraphInput,
    selected: &[usize],
    limits: &Limits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<usize> {
    validate(input, limits)?;
    let n = input.vertices;
    if selected.len() > n.saturating_sub(1) && n > 0 {
        return Err(Error::Check("too many forest edges"));
    }
    let mut adjacency = vec![Vec::new(); n];
    let mut seen = BTreeSet::new();
    for &id in selected {
        crate::checkpoint(control, 1)?;
        let &(a, b, w) = input.edges.get(id).ok_or(Error::Check("unknown edge ID"))?;
        if a == b || !seen.insert(id) {
            return Err(Error::Check("self-loop or repeated edge"));
        }
        adjacency[a].push((b, w, id));
        adjacency[b].push((a, w, id));
    }
    let levels = (usize::BITS - n.max(1).leading_zeros()) as usize;
    let mut parent = vec![vec![0; n]; levels];
    let mut maximum = vec![vec![i64::MIN; n]; levels];
    let mut component = vec![usize::MAX; n];
    let mut depth = vec![0; n];
    let mut components = 0;
    for root in 0..n {
        crate::checkpoint(control, 1)?;
        if component[root] != usize::MAX {
            continue;
        }
        component[root] = components;
        components += 1;
        parent[0][root] = root;
        let mut stack = vec![(root, usize::MAX)];
        while let Some((a, incoming)) = stack.pop() {
            crate::checkpoint(control, 1)?;
            for &(b, w, id) in &adjacency[a] {
                crate::checkpoint(control, 1)?;
                if id == incoming {
                    continue;
                }
                if component[b] != usize::MAX {
                    return Err(Error::Check("cycle"));
                }
                component[b] = component[a];
                depth[b] = depth[a] + 1;
                parent[0][b] = a;
                maximum[0][b] = w;
                stack.push((b, id));
            }
        }
    }
    for level in 1..levels {
        crate::checkpoint(control, 1)?;
        for node in 0..n {
            crate::checkpoint(control, 1)?;
            let p = parent[level - 1][node];
            parent[level][node] = parent[level - 1][p];
            maximum[level][node] = maximum[level - 1][node].max(maximum[level - 1][p]);
        }
    }
    for &(mut a, mut b, weight) in &input.edges {
        crate::checkpoint(control, 1)?;
        if component[a] != component[b] {
            return Err(Error::Check("missing component connection"));
        }
        if a == b {
            continue;
        }
        let mut path_max = i64::MIN;
        if depth[a] < depth[b] {
            std::mem::swap(&mut a, &mut b);
        }
        let diff = depth[a] - depth[b];
        for level in 0..levels {
            crate::checkpoint(control, 1)?;
            if (diff >> level) & 1 != 0 {
                path_max = path_max.max(maximum[level][a]);
                a = parent[level][a];
            }
        }
        if a != b {
            for level in (0..levels).rev() {
                crate::checkpoint(control, 1)?;
                if parent[level][a] != parent[level][b] {
                    path_max = path_max.max(maximum[level][a]).max(maximum[level][b]);
                    a = parent[level][a];
                    b = parent[level][b];
                }
            }
            path_max = path_max.max(maximum[0][a]).max(maximum[0][b]);
        }
        if weight < path_max {
            return Err(Error::Check("cheaper cycle replacement exists"));
        }
    }
    Ok(components)
}
