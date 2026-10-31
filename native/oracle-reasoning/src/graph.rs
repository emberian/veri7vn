use crate::{Error, Limits, Result};
use petgraph::unionfind::UnionFind;
use serde::{Deserialize, Serialize};
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

/// Private borrowing admission handle. Public entry points validate independently;
/// the solver can pass its already validated source to the independent checker.
struct ValidatedGraph<'a>(&'a GraphInput);
impl<'a> ValidatedGraph<'a> {
    fn new(input: &'a GraphInput, limits: &Limits) -> Result<Self> {
        validate(input, limits)?;
        Ok(Self(input))
    }
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
    let admitted = ValidatedGraph::new(input, limits)?;
    // Keep only edge IDs: endpoints and exact weights remain in the borrowed
    // source. Petgraph's previous heap key was (weight, original edge ID), so
    // this total ordering preserves every tie and parallel-edge choice.
    let mut ordered = Vec::with_capacity(input.edges.len());
    for id in 0..input.edges.len() {
        crate::checkpoint(control, 1)?;
        ordered.push(id);
    }
    crate::checkpoint(control, input.vertices as u64)?;
    let mut components = UnionFind::<usize>::new(input.vertices);
    let build_us = started.elapsed().as_micros();
    let search_started = Instant::now();
    // Standard-library sorting is a bounded but uninterruptible interval (at
    // most the admitted edge count). Precharge the exact following scan,
    // retaining that conservative charge if cancellation interrupts the block.
    // This is one unit per source edge, not per sort comparison/CPU instruction.
    crate::checkpoint(control, ordered.len() as u64)?;
    crate::check_control(control)?;
    ordered.sort_unstable_by_key(|&id| (input.edges[id].2, id));
    crate::check_control(control)?;
    let mut selected = Vec::with_capacity(input.vertices.saturating_sub(1).min(input.edges.len()));
    for id in ordered {
        crate::check_control(control)?;
        let (a, b, _) = input.edges[id];
        if components.union(a, b) {
            selected.push(id);
        }
    }
    drop(components);
    crate::check_control(control)?;
    selected.sort_unstable();
    crate::check_control(control)?;
    let search_us = search_started.elapsed().as_micros();
    let check_started = Instant::now();
    let components = check_admitted_forest(&admitted, &selected, control)?;
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

/// Independent of Kruskal: verify a forest, its component coverage, and
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
    let admitted = ValidatedGraph::new(input, limits)?;
    check_admitted_forest(&admitted, selected, control)
}

fn check_admitted_forest(
    admitted: &ValidatedGraph<'_>,
    selected: &[usize],
    control: &dyn oracle_execution::WorkControl,
) -> Result<usize> {
    let input = admitted.0;
    let n = input.vertices;
    if selected.len() > n.saturating_sub(1) && n > 0 {
        return Err(Error::Check("too many forest edges"));
    }
    // CSR stores original IDs only: no copied endpoints/weights and no per-node
    // allocations. A dense marker replaces the selected-ID search tree.
    let mut offsets = vec![0usize; n + 1];
    let mut seen = vec![false; input.edges.len()];
    for &id in selected {
        crate::checkpoint(control, 1)?;
        let &(a, b, _) = input.edges.get(id).ok_or(Error::Check("unknown edge ID"))?;
        if a == b || seen[id] {
            return Err(Error::Check("self-loop or repeated edge"));
        }
        seen[id] = true;
        offsets[a + 1] += 1;
        offsets[b + 1] += 1;
    }
    crate::checkpoint(control, n as u64)?;
    for node in 0..n {
        crate::check_control(control)?;
        offsets[node + 1] += offsets[node];
    }
    let entries = selected
        .len()
        .checked_mul(2)
        .ok_or(Error::Limit("forest adjacency size"))?;
    let mut adjacency = vec![0usize; entries];
    let mut cursors = offsets[..n].to_vec();
    crate::checkpoint(control, selected.len() as u64)?;
    for &id in selected {
        crate::check_control(control)?;
        let (a, b, _) = input.edges[id];
        adjacency[cursors[a]] = id;
        cursors[a] += 1;
        adjacency[cursors[b]] = id;
        cursors[b] += 1;
    }
    drop(cursors);
    drop(seen);
    let levels = (usize::BITS - n.max(1).leading_zeros()) as usize;
    let table_len = levels
        .checked_mul(n)
        .ok_or(Error::Limit("forest lifting size"))?;
    let mut parent = vec![0usize; table_len];
    let mut maximum = vec![i64::MIN; table_len];
    let mut component = vec![usize::MAX; n];
    let mut depth = vec![0; n];
    let mut components = 0;
    let mut stack = Vec::with_capacity(n);
    for root in 0..n {
        crate::checkpoint(control, 1)?;
        if component[root] != usize::MAX {
            continue;
        }
        component[root] = components;
        components += 1;
        parent[root] = root;
        stack.push((root, usize::MAX));
        while let Some((a, incoming)) = stack.pop() {
            crate::checkpoint(control, 1)?;
            for &id in &adjacency[offsets[a]..offsets[a + 1]] {
                let (left, right, w) = input.edges[id];
                let b = if left == a { right } else { left };
                crate::checkpoint(control, 1)?;
                if id == incoming {
                    continue;
                }
                if component[b] != usize::MAX {
                    return Err(Error::Check("cycle"));
                }
                component[b] = component[a];
                depth[b] = depth[a] + 1;
                parent[b] = a;
                maximum[b] = w;
                stack.push((b, id));
            }
        }
    }
    for level in 1..levels {
        crate::checkpoint(control, 1)?;
        crate::checkpoint(control, n as u64)?;
        for node in 0..n {
            crate::check_control(control)?;
            let p = parent[(level - 1) * n + node];
            parent[level * n + node] = parent[(level - 1) * n + p];
            maximum[level * n + node] =
                maximum[(level - 1) * n + node].max(maximum[(level - 1) * n + p]);
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
        crate::checkpoint(control, levels as u64)?;
        for level in 0..levels {
            crate::check_control(control)?;
            if (diff >> level) & 1 != 0 {
                path_max = path_max.max(maximum[level * n + a]);
                a = parent[level * n + a];
            }
        }
        if a != b {
            crate::checkpoint(control, levels as u64)?;
            for level in (0..levels).rev() {
                crate::check_control(control)?;
                if parent[level * n + a] != parent[level * n + b] {
                    path_max = path_max
                        .max(maximum[level * n + a])
                        .max(maximum[level * n + b]);
                    a = parent[level * n + a];
                    b = parent[level * n + b];
                }
            }
            path_max = path_max.max(maximum[a]).max(maximum[b]);
        }
        if weight < path_max {
            return Err(Error::Check("cheaper cycle replacement exists"));
        }
    }
    Ok(components)
}
