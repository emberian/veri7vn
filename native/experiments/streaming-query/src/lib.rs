//! Untrusted design experiment (compiled, linted, tests pass on macOS). No inherited Isabelle assurance.
//! Operators return sorted sets unless their type explicitly names a bag.
use std::{
    collections::BTreeMap,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::Instant,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Entity(pub u32);
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Predicate(pub u32);
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Statement(pub u32);
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Error {
    Cancelled,
    Deadline,
    Fuel,
    Scratch,
    InvalidOrder,
    UnknownPosting,
    Snapshot,
    Incomplete,
}
pub type Result<T> = std::result::Result<T, Error>;

/// Identity of one constructed immutable image, not authenticity or provenance.
/// Equal numeric release labels on separately constructed images do not match.
#[derive(Clone, Debug)]
pub struct Scope(Arc<ScopeIdentity>);
#[derive(Debug)]
struct ScopeIdentity {
    release: u64,
}
impl Scope {
    pub fn release_label(&self) -> u64 {
        self.0.release
    }
    fn require_same(&self, other: &Self) -> Result<()> {
        if self == other {
            Ok(())
        } else {
            Err(Error::Snapshot)
        }
    }
}
impl PartialEq for Scope {
    fn eq(&self, other: &Self) -> bool {
        Arc::ptr_eq(&self.0, &other.0)
    }
}
impl Eq for Scope {}
mod sealed {
    pub trait Sealed {}
}

/// One request owns this meter. Scratch is a cumulative allocation allowance,
/// deliberately conservative: dropped vectors do not refund it. Partial outputs
/// must be discarded after any error; failure remains sticky even if caught.
pub struct Context {
    fuel: u64,
    scratch: usize,
    deadline: Instant,
    cancel: Arc<AtomicBool>,
    failed: Option<Error>,
}
impl Context {
    pub fn new(fuel: u64, scratch: usize, deadline: Instant, cancel: Arc<AtomicBool>) -> Self {
        Self {
            fuel,
            scratch,
            deadline,
            cancel,
            failed: None,
        }
    }
    pub fn tick(&mut self) -> Result<()> {
        if let Some(e) = self.failed {
            return Err(e);
        }
        let error = if self.cancel.load(Ordering::Relaxed) {
            Some(Error::Cancelled)
        } else if Instant::now() >= self.deadline {
            Some(Error::Deadline)
        } else if self.fuel == 0 {
            Some(Error::Fuel)
        } else {
            None
        };
        if let Some(e) = error {
            self.failed = Some(e);
            return Err(e);
        }
        self.fuel -= 1;
        Ok(())
    }
    fn allocate(&mut self, bytes: usize) -> Result<()> {
        self.tick()?;
        if bytes > self.scratch {
            self.failed = Some(Error::Scratch);
            return Err(Error::Scratch);
        }
        self.scratch -= bytes;
        Ok(())
    }
}

/// Immutable source rows are bags: two equal edges with distinct Statement IDs
/// are two witnesses. A dictionary, qualifier payloads and rendering live outside
/// this experiment. The image builder must validate ID and evidence references.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Edge {
    pub subject: Entity,
    pub predicate: Predicate,
    pub object: Entity,
    pub evidence: Statement,
}
pub struct Image {
    scope: Scope,
    postings: BTreeMap<u32, Arc<[Entity]>>,
    edges: BTreeMap<(Predicate, Entity), Arc<[Edge]>>,
}
impl Image {
    pub fn authored(
        release: u64,
        postings: Vec<(u32, Vec<Entity>)>,
        edges: Vec<Edge>,
    ) -> Result<Self> {
        let mut sets = BTreeMap::new();
        for (key, rows) in postings {
            if rows.windows(2).any(|p| p[0] >= p[1]) || sets.contains_key(&key) {
                return Err(Error::InvalidOrder);
            }
            sets.insert(key, Arc::from(rows));
        }
        let mut grouped: BTreeMap<(Predicate, Entity), Vec<Edge>> = BTreeMap::new();
        for edge in edges {
            grouped
                .entry((edge.predicate, edge.subject))
                .or_default()
                .push(edge);
        }
        for rows in grouped.values_mut() {
            rows.sort();
        }
        Ok(Self {
            scope: Scope(Arc::new(ScopeIdentity { release })),
            postings: sets,
            edges: grouped
                .into_iter()
                .map(|(k, v)| (k, Arc::from(v)))
                .collect(),
        })
    }
    pub fn scan(&self, key: u32) -> Result<Scan> {
        Ok(Scan {
            scope: self.scope.clone(),
            rows: self
                .postings
                .get(&key)
                .ok_or(Error::UnknownPosting)?
                .clone(),
            at: 0,
            end: None,
        })
    }
}

/// Exhaustion means complete relative to the supplied image/plan only. It is not
/// evidence that a source predicate covers the real world. No timeout is EOF.
pub trait SetPull: sealed::Sealed {
    fn scope(&self) -> &Scope;
    fn next(&mut self, cx: &mut Context) -> Result<Option<Entity>>;
}
pub struct Scan {
    scope: Scope,
    rows: Arc<[Entity]>,
    at: usize,
    end: Option<usize>,
}
impl sealed::Sealed for Scan {}
impl SetPull for Scan {
    fn scope(&self) -> &Scope {
        &self.scope
    }
    fn next(&mut self, cx: &mut Context) -> Result<Option<Entity>> {
        cx.tick()?;
        let end = self.end.unwrap_or(self.rows.len());
        if self.at >= end {
            return Ok(None);
        }
        let id = self.rows[self.at];
        self.at += 1;
        Ok(Some(id))
    }
}
/// Split by disjoint half-open ID ranges; workers clone Arc handles, not images.
/// These are scan descriptors only; the host owns a globally bounded worker pool.
pub fn partition(scan: &Scan, boundaries: &[Entity], cx: &mut Context) -> Result<Vec<Scan>> {
    let slots = boundaries.len().checked_add(2).ok_or(Error::Scratch)?;
    cx.allocate(
        slots
            .checked_mul(std::mem::size_of::<usize>() + std::mem::size_of::<Scan>())
            .ok_or(Error::Scratch)?,
    )?;
    let start = scan.at;
    let end = scan.end.unwrap_or(scan.rows.len());
    // Fix backing capacities up front: geometric Vec growth would exceed the
    // accounting even though the final logical lengths fit the allowance.
    let mut positions = Vec::with_capacity(slots);
    positions.push(start);
    let mut previous = None;
    for b in boundaries {
        cx.tick()?;
        if previous.is_some_and(|p| p >= *b) {
            return Err(Error::InvalidOrder);
        }
        previous = Some(*b);
        positions.push(start + scan.rows[start..end].partition_point(|x| x < b));
    }
    positions.push(end);
    let mut parts = Vec::with_capacity(slots - 1);
    for p in positions.windows(2) {
        cx.tick()?;
        parts.push(Scan {
            scope: scan.scope.clone(),
            rows: scan.rows.clone(),
            at: p[0],
            end: Some(p[1]),
        });
    }
    Ok(parts)
}

pub struct Merge<A, B> {
    a: A,
    b: B,
    left: Option<Entity>,
    right: Option<Entity>,
    init: bool,
    union: bool,
}
impl<A: SetPull, B: SetPull> Merge<A, B> {
    pub fn intersection(a: A, b: B) -> Result<Self> {
        a.scope().require_same(b.scope())?;
        Ok(Self {
            a,
            b,
            left: None,
            right: None,
            init: false,
            union: false,
        })
    }
    pub fn union(a: A, b: B) -> Result<Self> {
        Ok(Self {
            union: true,
            ..Self::intersection(a, b)?
        })
    }
}
impl<A: SetPull, B: SetPull> sealed::Sealed for Merge<A, B> {}
impl<A: SetPull, B: SetPull> SetPull for Merge<A, B> {
    fn scope(&self) -> &Scope {
        self.a.scope()
    }
    fn next(&mut self, cx: &mut Context) -> Result<Option<Entity>> {
        cx.tick()?;
        if !self.init {
            self.left = self.a.next(cx)?;
            self.right = self.b.next(cx)?;
            self.init = true;
        }
        loop {
            cx.tick()?;
            match (self.left, self.right) {
                (Some(a), Some(b)) if a == b => {
                    self.left = self.a.next(cx)?;
                    self.right = self.b.next(cx)?;
                    return Ok(Some(a));
                }
                (Some(a), Some(b)) if a < b => {
                    self.left = self.a.next(cx)?;
                    if self.union {
                        return Ok(Some(a));
                    }
                }
                (Some(_), Some(b)) => {
                    self.right = self.b.next(cx)?;
                    if self.union {
                        return Ok(Some(b));
                    }
                }
                (Some(a), None) if self.union => {
                    self.left = self.a.next(cx)?;
                    return Ok(Some(a));
                }
                (None, Some(b)) if self.union => {
                    self.right = self.b.next(cx)?;
                    return Ok(Some(b));
                }
                _ => return Ok(None),
            }
        }
    }
}

/// Indexed nested-loop join streams witnesses in input-subject order. It does
/// not sort by object or discard parallel source statements.
pub struct Relate<S> {
    image: Arc<Image>,
    input: S,
    predicate: Predicate,
    current: Option<Arc<[Edge]>>,
    at: usize,
}
impl<S: SetPull> Relate<S> {
    pub fn new(image: Arc<Image>, input: S, predicate: Predicate) -> Result<Self> {
        image.scope.require_same(input.scope())?;
        Ok(Self {
            image,
            input,
            predicate,
            current: None,
            at: 0,
        })
    }
    pub fn next_edge(&mut self, cx: &mut Context) -> Result<Option<Edge>> {
        loop {
            cx.tick()?;
            if let Some(rows) = &self.current {
                if self.at < rows.len() {
                    let edge = rows[self.at];
                    self.at += 1;
                    return Ok(Some(edge));
                }
            }
            let Some(subject) = self.input.next(cx)? else {
                return Ok(None);
            };
            self.current = self.image.edges.get(&(self.predicate, subject)).cloned();
            self.at = 0;
        }
    }
    /// Object projection is an explicit pipeline breaker. Retains all witnesses
    /// separately; only entity IDs deduplicate. A bounded quadratic insertion
    /// sort keeps cancellation observable inside sorting (replace before scale).
    pub fn materialize_objects(mut self, cx: &mut Context) -> Result<RelationResult> {
        let mut witnesses = Vec::new();
        let mut objects = Vec::new();
        while let Some(edge) = self.next_edge(cx)? {
            push_bounded(&mut witnesses, edge, cx)?;
            let mut at = objects.len();
            while at > 0 {
                cx.tick()?;
                if objects[at - 1] <= edge.object {
                    break;
                }
                at -= 1;
            }
            if (at > 0 && objects[at - 1] == edge.object) || objects.get(at) == Some(&edge.object) {
                continue;
            }
            push_bounded(&mut objects, edge.object, cx)?;
            let mut n = objects.len() - 1;
            while n > at {
                cx.tick()?;
                objects.swap(n, n - 1);
                n -= 1;
            }
        }
        // Arc conversions can allocate a second backing array before Vec drops.
        cx.allocate(
            witnesses.len() * std::mem::size_of::<Edge>()
                + objects.len() * std::mem::size_of::<Entity>(),
        )?;
        let entities = Materialized {
            scope: self.image.scope.clone(),
            rows: Arc::from(objects),
        };
        Ok(RelationResult {
            entities,
            witnesses: Arc::from(witnesses),
        })
    }
}
fn push_bounded<T>(v: &mut Vec<T>, value: T, cx: &mut Context) -> Result<()> {
    if v.len() == v.capacity() {
        let extra = if v.capacity() == 0 { 4 } else { v.capacity() };
        // Retain the old backing charge and charge the entire replacement:
        // reserve may temporarily hold both allocations during relocation.
        let replacement = v.len().checked_add(extra).ok_or(Error::Scratch)?;
        cx.allocate(
            replacement
                .checked_mul(std::mem::size_of::<T>())
                .ok_or(Error::Scratch)?,
        )?;
        v.reserve_exact(extra);
    }
    v.push(value);
    Ok(())
}

/// Explicit request-local DAG reuse: a stream is consumed once, then every
/// consumer gets an independent immutable cursor. Failed fills are never cached.
pub struct Materialized {
    scope: Scope,
    rows: Arc<[Entity]>,
}
impl Materialized {
    pub fn fill<S: SetPull>(mut source: S, cx: &mut Context) -> Result<Self> {
        let scope = source.scope().clone();
        let mut rows = Vec::new();
        while let Some(row) = source.next(cx)? {
            push_bounded(&mut rows, row, cx)?;
        }
        cx.allocate(rows.len() * std::mem::size_of::<Entity>())?;
        Ok(Self {
            scope,
            rows: Arc::from(rows),
        })
    }
    pub fn scan(&self) -> Scan {
        Scan {
            scope: self.scope.clone(),
            rows: self.rows.clone(),
            at: 0,
            end: None,
        }
    }
}
pub struct RelationResult {
    pub entities: Materialized,
    pub witnesses: Arc<[Edge]>,
}

#[derive(Debug, PartialEq, Eq)]
pub struct CompleteCount {
    pub scope: Scope,
    pub relative_to_image: u64,
}
pub fn count<S: SetPull>(mut source: S, cx: &mut Context) -> Result<CompleteCount> {
    let scope = source.scope().clone();
    let mut n = 0u64;
    while source.next(cx)?.is_some() {
        n = n.checked_add(1).ok_or(Error::Fuel)?;
    }
    cx.tick()?;
    Ok(CompleteCount {
        scope,
        relative_to_image: n,
    })
}
#[derive(Debug, PartialEq, Eq)]
pub enum Uniqueness {
    Empty,
    One(Entity),
    Multiple,
}
#[derive(Debug, PartialEq, Eq)]
pub struct UniqueResult {
    pub scope: Scope,
    pub value: Uniqueness,
}
/// Multiple is a valid early refutation of uniqueness. Empty/One require EOF.
pub fn unique<S: SetPull>(mut source: S, cx: &mut Context) -> Result<UniqueResult> {
    let scope = source.scope().clone();
    let Some(first) = source.next(cx)? else {
        return Ok(UniqueResult {
            scope,
            value: Uniqueness::Empty,
        });
    };
    let value = match source.next(cx)? {
        Some(_) => Uniqueness::Multiple,
        None => Uniqueness::One(first),
    };
    Ok(UniqueResult { scope, value })
}

/// Ordered fan-in of disjoint partitions needs no heap and no output buffer.
/// For overlapping partitions use Merge::union to preserve set semantics.
pub struct Concat {
    scope: Scope,
    parts: std::vec::IntoIter<Scan>,
    current: Option<Scan>,
}
impl Concat {
    pub fn ordered_disjoint(parts: Vec<Scan>) -> Result<Self> {
        // An empty Vec has no image identity. Use an empty image scan instead.
        let scope = parts.first().ok_or(Error::Incomplete)?.scope.clone();
        let mut last = None;
        for p in &parts {
            scope.require_same(&p.scope)?;
            let end = p.end.unwrap_or(p.rows.len());
            if let (Some(before), Some(first)) = (last, p.rows.get(p.at).filter(|_| p.at < end)) {
                if before >= *first {
                    return Err(Error::InvalidOrder);
                }
            }
            if end > p.at {
                last = Some(p.rows[end - 1]);
            }
        }
        Ok(Self {
            scope,
            parts: parts.into_iter(),
            current: None,
        })
    }
}
impl sealed::Sealed for Concat {}
impl SetPull for Concat {
    fn scope(&self) -> &Scope {
        &self.scope
    }
    fn next(&mut self, cx: &mut Context) -> Result<Option<Entity>> {
        loop {
            cx.tick()?;
            if let Some(current) = &mut self.current {
                if let Some(id) = current.next(cx)? {
                    return Ok(Some(id));
                }
            }
            self.current = self.parts.next();
            if self.current.is_none() {
                return Ok(None);
            }
        }
    }
}
