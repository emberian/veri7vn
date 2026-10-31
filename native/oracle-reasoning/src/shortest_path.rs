//! Exact directed walks in the complete supplied graph, not claims about absent
//! real-world edges. Candidate search and certificate checking are handwritten
//! Rust, independently structured; neither is Isabelle-verified.
use crate::{Error, Result};
use oracle_execution::WorkControl;
use serde::{Deserialize, Serialize};
use std::cmp::Reverse;
use std::collections::{BinaryHeap, VecDeque};
use std::time::Instant;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ShortestPathInput {
    pub vertices: usize,
    /// Stable edge IDs are positions, including parallel edges and loops.
    pub edges: Vec<(usize, usize, i64)>,
    pub source: usize,
    pub target: usize,
}
#[derive(Clone, Debug, Serialize)]
pub struct PathLimits {
    pub vertices: usize,
    pub edges: usize,
    pub work: usize,
    pub milliseconds: u64,
    /// Maximum encoded certificate bytes, enforced while serializing.
    pub reply_bytes: usize,
}
impl Default for PathLimits {
    fn default() -> Self {
        Self {
            vertices: 10_000,
            edges: 100_000,
            work: 5_000_000,
            milliseconds: 100,
            reply_bytes: 256 * 1024,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "outcome", rename_all = "snake_case", deny_unknown_fields)]
pub enum Certificate {
    Finite {
        distance: String,
        path: Vec<usize>,
        /// Decimal distances on the source/target corridor; None elsewhere.
        labels: Vec<Option<String>>,
    },
    Unreachable {
        reachable: Vec<bool>,
    },
    Unbounded {
        prefix: Vec<usize>,
        cycle: Vec<usize>,
        suffix: Vec<usize>,
    },
}
struct Budget<'a> {
    remaining: usize,
    start: Instant,
    limits: &'a PathLimits,
    cancel: &'a dyn WorkControl,
}
impl<'a> Budget<'a> {
    fn new(limits: &'a PathLimits, cancel: &'a dyn WorkControl) -> Self {
        Self {
            remaining: limits.work,
            start: Instant::now(),
            limits,
            cancel,
        }
    }
    fn tick(&mut self) -> Result<()> {
        crate::checkpoint(self.cancel, 1)?;
        if self.remaining == 0 {
            return Err(Error::Limit("shortest path work"));
        }
        self.remaining -= 1;
        if self.start.elapsed().as_millis() >= u128::from(self.limits.milliseconds) {
            return Err(Error::Limit("shortest path time"));
        }
        Ok(())
    }
}
fn add(a: i128, b: i64) -> Result<i128> {
    a.checked_add(i128::from(b))
        .ok_or(Error::Limit("shortest path arithmetic"))
}
fn filled<T: Clone>(n: usize, value: T, b: &mut Budget<'_>) -> Result<Vec<T>> {
    // Each initialized slot is charged. Allocator calls remain cooperative,
    // like heap insertion; they cannot be preempted inside the allocator.
    let mut result = Vec::new();
    for _ in 0..n {
        b.tick()?;
        result.push(value.clone());
    }
    Ok(result)
}
fn reverse<T>(xs: &mut [T], b: &mut Budget<'_>) -> Result<()> {
    for i in 0..xs.len() / 2 {
        b.tick()?;
        xs.swap(i, xs.len() - 1 - i);
    }
    Ok(())
}
fn validate(g: &ShortestPathInput, l: &PathLimits, b: &mut Budget<'_>) -> Result<()> {
    b.tick()?;
    if g.vertices > l.vertices || g.edges.len() > l.edges {
        return Err(Error::Limit("shortest path graph size"));
    }
    if g.source >= g.vertices || g.target >= g.vertices {
        return Err(Error::Invalid(
            "shortest path endpoint outside graph".into(),
        ));
    }
    for &(a, z, _) in &g.edges {
        b.tick()?;
        if a >= g.vertices || z >= g.vertices {
            return Err(Error::Invalid(
                "shortest path endpoint outside graph".into(),
            ));
        }
    }
    Ok(())
}
type Adjacency = Vec<Vec<usize>>;
fn adjacency(g: &ShortestPathInput, b: &mut Budget<'_>) -> Result<(Adjacency, Adjacency)> {
    let mut out = filled(g.vertices, Vec::new(), b)?;
    let mut rev = filled(g.vertices, Vec::new(), b)?;
    for (id, &(a, z, _)) in g.edges.iter().enumerate() {
        b.tick()?;
        out[a].push(id);
        rev[z].push(id);
    }
    Ok((out, rev))
}
fn reach(
    g: &ShortestPathInput,
    adj: &[Vec<usize>],
    start: usize,
    reverse: bool,
    b: &mut Budget<'_>,
) -> Result<Vec<bool>> {
    let mut seen = filled(g.vertices, false, b)?;
    seen[start] = true;
    let mut q = VecDeque::from([start]);
    while let Some(v) = q.pop_front() {
        b.tick()?;
        for &id in &adj[v] {
            b.tick()?;
            let (a, z, _) = g.edges[id];
            let w = if reverse { a } else { z };
            if !seen[w] {
                seen[w] = true;
                q.push_back(w);
            }
        }
    }
    Ok(seen)
}
fn route(
    g: &ShortestPathInput,
    adj: &[Vec<usize>],
    start: usize,
    end: usize,
    b: &mut Budget<'_>,
) -> Result<Vec<usize>> {
    let mut pred = filled(g.vertices, None, b)?;
    let mut seen = filled(g.vertices, false, b)?;
    seen[start] = true;
    let mut q = VecDeque::from([start]);
    while let Some(v) = q.pop_front() {
        b.tick()?;
        if v == end {
            break;
        }
        for &id in &adj[v] {
            b.tick()?;
            let w = g.edges[id].1;
            if !seen[w] {
                seen[w] = true;
                pred[w] = Some(id);
                q.push_back(w);
            }
        }
    }
    if !seen[end] {
        return Err(Error::Check("missing witness route"));
    }
    let mut p = vec![];
    let mut v = end;
    while v != start {
        b.tick()?;
        let id = pred[v].ok_or(Error::Check("missing route predecessor"))?;
        p.push(id);
        v = g.edges[id].0;
    }
    reverse(&mut p, b)?;
    Ok(p)
}
/// Nonnegative corridors use an exact integer heap; signed corridors use bounded
/// Bellman-Ford. Every successful candidate is checked before being returned.
pub fn shortest_path(
    g: &ShortestPathInput,
    limits: &PathLimits,
    cancel: &dyn WorkControl,
) -> Result<Certificate> {
    let mut b = Budget::new(limits, cancel);
    solve(g, &mut b)
}
fn solve(g: &ShortestPathInput, b: &mut Budget<'_>) -> Result<Certificate> {
    validate(g, b.limits, b)?;
    let (out, rev) = adjacency(g, b)?;
    let from = reach(g, &out, g.source, false, b)?;
    let cert = if !from[g.target] {
        Certificate::Unreachable { reachable: from }
    } else {
        let to = reach(g, &rev, g.target, true, b)?;
        let mut corridor = Vec::new();
        let mut count = 0;
        for (&a, &z) in from.iter().zip(&to) {
            b.tick()?;
            corridor.push(a && z);
            if a && z {
                count += 1;
            }
        }
        let mut ids = Vec::new();
        let mut nonnegative = true;
        for (id, &(a, z, w)) in g.edges.iter().enumerate() {
            b.tick()?;
            if corridor[a] && corridor[z] {
                ids.push(id);
                nonnegative &= w >= 0;
            }
        }
        let mut d: Vec<Option<i128>> = filled(g.vertices, None, b)?;
        d[g.source] = Some(0);
        let mut pred = filled(g.vertices, None, b)?;
        let mut changed = None;
        if nonnegative {
            let mut heap = BinaryHeap::from([Reverse((0i128, g.source))]);
            while let Some(Reverse((cost, v))) = heap.pop() {
                b.tick()?;
                if d[v] != Some(cost) {
                    continue;
                }
                for &id in &out[v] {
                    b.tick()?;
                    let (_, w, weight) = g.edges[id];
                    if !corridor[w] {
                        continue;
                    }
                    let next = add(cost, weight)?;
                    if d[w].is_none_or(|old| next < old) {
                        d[w] = Some(next);
                        pred[w] = Some(id);
                        heap.push(Reverse((next, w)));
                    }
                }
            }
        } else {
            for _ in 0..count {
                changed = None;
                for &id in &ids {
                    b.tick()?;
                    let (a, z, w) = g.edges[id];
                    if let Some(da) = d[a] {
                        let next = add(da, w)?;
                        if d[z].is_none_or(|old| next < old) {
                            d[z] = Some(next);
                            pred[z] = Some(id);
                            changed = Some(z);
                        }
                    }
                }
                if changed.is_none() {
                    break;
                }
            }
        }
        if let Some(mut v) = changed {
            for _ in 0..g.vertices {
                b.tick()?;
                v = g.edges[pred[v].ok_or(Error::Check("negative-cycle predecessor"))?].0;
            }
            let anchor = v;
            let mut cycle = vec![];
            loop {
                b.tick()?;
                let id = pred[v].ok_or(Error::Check("negative-cycle predecessor"))?;
                cycle.push(id);
                v = g.edges[id].0;
                if v == anchor {
                    break;
                }
                if cycle.len() > g.vertices {
                    return Err(Error::Check("cycle extraction"));
                }
            }
            reverse(&mut cycle, b)?;
            Certificate::Unbounded {
                prefix: route(g, &out, g.source, anchor, b)?,
                cycle,
                suffix: route(g, &out, anchor, g.target, b)?,
            }
        } else {
            // Tight-edge BFS avoids predecessor cycles among zero-weight ties.
            let mut tight = filled(g.vertices, Vec::new(), b)?;
            for (id, &(a, z, w)) in g.edges.iter().enumerate() {
                b.tick()?;
                if let (Some(x), Some(y)) = (d[a], d[z]) {
                    if x.checked_add(i128::from(w)) == Some(y) {
                        tight[a].push(id);
                    }
                }
            }
            let mut labels = Vec::new();
            for (v, x) in d.iter().enumerate() {
                b.tick()?;
                labels.push(if corridor[v] {
                    x.map(|x| x.to_string())
                } else {
                    None
                });
            }
            Certificate::Finite {
                distance: d[g.target]
                    .ok_or(Error::Check("missing target distance"))?
                    .to_string(),
                path: route(g, &tight, g.source, g.target, b)?,
                labels,
            }
        }
    };
    // Search and check share one overall work/time allowance.
    check_inner(g, &cert, b)?;
    b.tick()?;
    Ok(cert)
}
fn walk(
    g: &ShortestPathInput,
    path: &[usize],
    start: usize,
    b: &mut Budget<'_>,
) -> Result<(usize, i128)> {
    if path.len() > g.vertices {
        return Err(Error::Check("witness walk too long"));
    }
    let mut v = start;
    let mut sum = 0;
    for &id in path {
        b.tick()?;
        let &(a, z, w) = g.edges.get(id).ok_or(Error::Check("unknown path edge"))?;
        if a != v {
            return Err(Error::Check("disconnected path"));
        }
        v = z;
        sum = add(sum, w)?;
    }
    Ok((v, sum))
}
fn number(s: &str) -> Result<i128> {
    if s.len() > 40 {
        return Err(Error::Check("distance encoding"));
    }
    let n = s
        .parse::<i128>()
        .map_err(|_| Error::Check("distance encoding"))?;
    if n.to_string() != s {
        return Err(Error::Check("noncanonical distance"));
    }
    Ok(n)
}
/// Checks graph-local witnesses without rerunning shortest-path optimization.
/// Finite labels bound every corridor walk below; the supplied path attains it.
pub fn check_certificate(
    g: &ShortestPathInput,
    cert: &Certificate,
    limits: &PathLimits,
    cancel: &dyn WorkControl,
) -> Result<()> {
    let mut b = Budget::new(limits, cancel);
    validate(g, limits, &mut b)?;
    check_inner(g, cert, &mut b)?;
    b.tick()
}
fn check_inner(g: &ShortestPathInput, cert: &Certificate, b: &mut Budget<'_>) -> Result<()> {
    match cert {
        Certificate::Unreachable { reachable } => {
            if reachable.len() != g.vertices || !reachable[g.source] || reachable[g.target] {
                return Err(Error::Check("invalid unreachable set"));
            }
            for &(a, z, _) in &g.edges {
                b.tick()?;
                if reachable[a] && !reachable[z] {
                    return Err(Error::Check("reachable set not closed"));
                }
            }
        }
        Certificate::Unbounded {
            prefix,
            cycle,
            suffix,
        } => {
            let (anchor, _) = walk(g, prefix, g.source, b)?;
            let (end, weight) = walk(g, cycle, anchor, b)?;
            if cycle.is_empty()
                || end != anchor
                || weight >= 0
                || walk(g, suffix, anchor, b)?.0 != g.target
            {
                return Err(Error::Check("invalid negative-cycle witness"));
            }
        }
        Certificate::Finite {
            distance,
            path,
            labels,
        } => {
            if labels.len() != g.vertices {
                return Err(Error::Check("label count"));
            }
            let distance = number(distance)?;
            let mut ds = Vec::new();
            for x in labels {
                b.tick()?;
                ds.push(x.as_deref().map(number).transpose()?);
            }
            let (out, rev) = adjacency(g, b)?;
            let from = reach(g, &out, g.source, false, b)?;
            let to = reach(g, &rev, g.target, true, b)?;
            for v in 0..g.vertices {
                b.tick()?;
                if ds[v].is_some() != (from[v] && to[v]) {
                    return Err(Error::Check("label corridor coverage"));
                }
            }
            if ds[g.source] != Some(0) || ds[g.target] != Some(distance) {
                return Err(Error::Check("endpoint labels"));
            }
            for &(a, z, w) in &g.edges {
                b.tick()?;
                if let (Some(x), Some(y)) = (ds[a], ds[z]) {
                    if y > add(x, w)? {
                        return Err(Error::Check("infeasible distance labels"));
                    }
                }
            }
            if walk(g, path, g.source, b)? != (g.target, distance) {
                return Err(Error::Check("path does not attain distance"));
            }
        }
    }
    Ok(())
}

/// Search, independent check and bounded JSON encoding share one allowance.
/// Certificate fields are ASCII; no complete intermediate JSON value is built.
pub fn shortest_path_bounded(
    g: &ShortestPathInput,
    limits: &PathLimits,
    cancel: &dyn WorkControl,
) -> Result<Certificate> {
    let mut b = Budget::new(limits, cancel);
    let cert = solve(g, &mut b)?;
    let mut writer = CertificateWriter {
        output: String::new(),
        budget: &mut b,
        failure: None,
    };
    let encoded = serde_json::to_writer(&mut writer, &cert);
    if let Some(error) = writer.failure.take() {
        return Err(error);
    }
    encoded?;
    writer.budget.tick()?;
    Ok(cert)
}
pub fn shortest_path_json(
    g: &ShortestPathInput,
    limits: &PathLimits,
    cancel: &dyn WorkControl,
) -> Result<String> {
    Ok(serde_json::to_string(&shortest_path_bounded(
        g, limits, cancel,
    )?)?)
}

struct CertificateWriter<'a, 'b> {
    output: String,
    budget: &'a mut Budget<'b>,
    failure: Option<Error>,
}
impl std::io::Write for CertificateWriter<'_, '_> {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        let result = (|| -> Result<()> {
            if bytes.len()
                > self
                    .budget
                    .limits
                    .reply_bytes
                    .saturating_sub(self.output.len())
            {
                return Err(Error::Limit("shortest path reply bytes"));
            }
            // Every write is bounded even if a future serializer emits a large chunk.
            for chunk in bytes.chunks(128) {
                self.budget.tick()?;
                let text = std::str::from_utf8(chunk)
                    .map_err(|_| Error::Check("certificate encoding must be ASCII"))?;
                self.output.push_str(text);
            }
            Ok(())
        })();
        if let Err(error) = result {
            self.failure = Some(error);
            return Err(std::io::Error::other("certificate encoding refused"));
        }
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
