//! Unverified, uncompiled experiment; no production provider or assurance claim.
//! Nonempty directed reachability over an immutable public release and private
//! identified supports. Shared public adjacency is never cloned per tenant.
#![forbid(unsafe_code)]
use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::sync::Arc;

pub type Node = u32;
pub type Edge = (Node, Node);
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Error {
    Invalid,
    Conflict,
    Budget,
    Cancelled,
    Capacity,
}
type Result<T> = std::result::Result<T, Error>;

/// Supplied by the authenticated embedding host, never by a query parser.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Scope {
    pub release: String,
    pub tenant: String,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Direction {
    Downstream,
    Upstream,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Demand {
    pub root: Node,
    pub direction: Direction,
}
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct CacheKey {
    pub scope: Scope,
    pub demand: Demand,
}

/// One release-wide support/adjacency index, Arc-shared by every tenant.
/// The caller must bind `release` to these actual rows and the implementation.
pub struct Public {
    release: String,
    facts: BTreeMap<String, Edge>,
    counts: BTreeMap<Edge, usize>,
    down: BTreeMap<Node, BTreeSet<Node>>,
    up: BTreeMap<Node, BTreeSet<Node>>,
}
impl Public {
    pub fn new(release: String, rows: Vec<(String, Edge)>) -> Result<Arc<Self>> {
        if release.is_empty() {
            return Err(Error::Invalid);
        }
        let mut p = Self {
            release,
            facts: BTreeMap::new(),
            counts: BTreeMap::new(),
            down: BTreeMap::new(),
            up: BTreeMap::new(),
        };
        for (id, edge) in rows {
            if id.is_empty() || p.facts.insert(id, edge).is_some() {
                return Err(Error::Invalid);
            }
            *p.counts.entry(edge).or_default() += 1;
            p.down.entry(edge.0).or_default().insert(edge.1);
            p.up.entry(edge.1).or_default().insert(edge.0);
        }
        Ok(Arc::new(p))
    }
}
#[derive(Clone, Default)]
struct Overlay {
    facts: BTreeMap<String, Edge>,
    counts: BTreeMap<Edge, usize>,
    down: BTreeMap<Node, BTreeSet<Node>>,
    up: BTreeMap<Node, BTreeSet<Node>>,
}
impl Overlay {
    fn insert(&mut self, id: String, e: Edge) {
        self.facts.insert(id, e);
        *self.counts.entry(e).or_default() += 1;
        self.down.entry(e.0).or_default().insert(e.1);
        self.up.entry(e.1).or_default().insert(e.0);
    }
    fn remove(&mut self, id: &str) -> Result<Edge> {
        let e = self.facts.remove(id).ok_or(Error::Invalid)?;
        let n = self.counts.get_mut(&e).ok_or(Error::Invalid)?;
        *n -= 1;
        if *n == 0 {
            self.counts.remove(&e);
            if let Some(row) = self.down.get_mut(&e.0) {
                row.remove(&e.1);
            }
            if let Some(row) = self.up.get_mut(&e.1) {
                row.remove(&e.0);
            }
            if self.down.get(&e.0).is_some_and(|r| r.is_empty()) {
                self.down.remove(&e.0);
            }
            if self.up.get(&e.1).is_some_and(|r| r.is_empty()) {
                self.up.remove(&e.1);
            }
        }
        Ok(e)
    }
}
/// Replay records use separate public/private ID namespaces. Public support
/// withdrawal needs a new release; private records cannot retract public facts.
#[derive(Clone, Debug)]
pub enum Mutation {
    Insert { id: String, edge: Edge },
    Retract { id: String },
}
#[derive(Clone, Debug)]
pub struct Delta {
    pub expected: u64,
    pub version: u64,
    pub changes: Vec<Mutation>,
}
#[derive(Clone, Debug)]
pub struct Snapshot {
    pub key: CacheKey,
    pub version: u64,
    pub nodes: Arc<BTreeSet<Node>>,
}
#[derive(Clone)]
struct View {
    nodes: Arc<BTreeSet<Node>>,
    touched: u64,
}
#[derive(Clone, Copy)]
pub struct Limits {
    pub views: usize,
    pub nodes_per_view: usize,
    pub private_supports: usize,
}
/// A transaction's cooperative work allowance. Every visited row/edge is charged.
/// Cancellation is observed during traversal and immediately before publication.
pub struct Budget<'a> {
    pub remaining: usize,
    pub cancelled: &'a dyn Fn() -> bool,
}
impl Budget<'_> {
    fn charge(&mut self) -> Result<()> {
        if (self.cancelled)() {
            return Err(Error::Cancelled);
        }
        self.remaining = self.remaining.checked_sub(1).ok_or(Error::Budget)?;
        Ok(())
    }
}
#[derive(Default, Debug)]
pub struct Maintenance {
    pub unchanged_views: usize,
    pub expanded_views: usize,
    pub rederived_views: usize,
    pub inserted_edges: usize,
    pub removed_edges: usize,
}
/// Single-owner actor: &mut operations serialize updates, queries and eviction.
/// Version belongs to the actor state, not the root key. Historical snapshots
/// remain valid through Arc ownership; they do not silently change version.
pub struct Tenant {
    public: Arc<Public>,
    scope: Scope,
    version: u64,
    overlay: Overlay,
    views: BTreeMap<Demand, View>,
    limits: Limits,
}
impl Tenant {
    pub fn new(public: Arc<Public>, tenant: String, limits: Limits) -> Result<Self> {
        if tenant.is_empty() || limits.views == 0 {
            return Err(Error::Invalid);
        }
        let scope = Scope {
            release: public.release.clone(),
            tenant,
        };
        Ok(Self {
            public,
            scope,
            version: 0,
            overlay: Overlay::default(),
            views: BTreeMap::new(),
            limits,
        })
    }
    pub fn version(&self) -> u64 {
        self.version
    }
    pub fn public_support_count(&self) -> usize {
        self.public.facts.len()
    }
    fn present(&self, o: &Overlay, e: &Edge) -> bool {
        self.public.counts.contains_key(e) || o.counts.contains_key(e)
    }
    /// Enumerates only a visited node's two adjacency rows. No union graph copy.
    fn expand(
        &self,
        o: &Overlay,
        d: Demand,
        seed: Vec<Node>,
        mut seen: BTreeSet<Node>,
        budget: &mut Budget<'_>,
    ) -> Result<BTreeSet<Node>> {
        let mut q: VecDeque<_> = seed.into();
        let (public, private) = match d.direction {
            Direction::Downstream => (&self.public.down, &o.down),
            Direction::Upstream => (&self.public.up, &o.up),
        };
        while let Some(n) = q.pop_front() {
            budget.charge()?;
            if !seen.insert(n) {
                continue;
            }
            if seen.len() > self.limits.nodes_per_view {
                return Err(Error::Capacity);
            }
            for index in [public, private] {
                if let Some(row) = index.get(&n) {
                    for &next in row {
                        budget.charge()?;
                        q.push_back(next);
                    }
                }
            }
        }
        Ok(seen)
    }
    fn fresh(&self, o: &Overlay, d: Demand, budget: &mut Budget<'_>) -> Result<BTreeSet<Node>> {
        // Root is not marked reached: self requires an actual nonempty cycle.
        let mut seed = Vec::new();
        let indexes = match d.direction {
            Direction::Downstream => [&self.public.down, &o.down],
            Direction::Upstream => [&self.public.up, &o.up],
        };
        for index in indexes {
            if let Some(row) = index.get(&d.root) {
                for &n in row {
                    budget.charge()?;
                    seed.push(n);
                }
            }
        }
        self.expand(o, d, seed, BTreeSet::new(), budget)
    }
    pub fn demand(&mut self, d: Demand, now: u64, budget: &mut Budget<'_>) -> Result<Snapshot> {
        budget.charge()?;
        if !self.views.contains_key(&d) {
            let nodes = Arc::new(self.fresh(&self.overlay, d, budget)?);
            budget.charge()?;
            if self.views.len() == self.limits.views {
                let oldest = self
                    .views
                    .iter()
                    .min_by_key(|(k, v)| (v.touched, **k))
                    .map(|(k, _)| *k)
                    .unwrap();
                self.views.remove(&oldest);
            }
            self.views.insert(
                d,
                View {
                    nodes,
                    touched: now,
                },
            );
        }
        let v = self.views.get_mut(&d).unwrap();
        v.touched = v.touched.max(now);
        Ok(Snapshot {
            key: CacheKey {
                scope: self.scope.clone(),
                demand: d,
            },
            version: self.version,
            nodes: v.nodes.clone(),
        })
    }
    /// Atomic per-tenant transition: cloned state is private overlay + demanded
    /// views only. Cancel/refusal discards it; even unaffected views get the new
    /// settled actor version only after all required work completes.
    pub fn apply(&mut self, delta: &Delta, budget: &mut Budget<'_>) -> Result<Maintenance> {
        if delta.expected != self.version || delta.version <= self.version {
            return Err(Error::Conflict);
        }
        let mut next = self.overlay.clone();
        let mut touched = BTreeSet::new();
        for change in &delta.changes {
            budget.charge()?;
            match change {
                Mutation::Insert { id, edge } => {
                    if id.is_empty() || next.facts.contains_key(id) {
                        return Err(Error::Invalid);
                    }
                    if next.facts.len() >= self.limits.private_supports {
                        return Err(Error::Capacity);
                    }
                    next.insert(id.clone(), *edge);
                    touched.insert(*edge);
                }
                Mutation::Retract { id } => {
                    touched.insert(next.remove(id)?);
                }
            }
        }
        let mut added = Vec::new();
        let mut removed = Vec::new();
        for edge in touched {
            budget.charge()?;
            match (
                self.present(&self.overlay, &edge),
                self.present(&next, &edge),
            ) {
                (false, true) => added.push(edge),
                (true, false) => removed.push(edge),
                _ => {}
            }
        }
        let mut report = Maintenance {
            inserted_edges: added.len(),
            removed_edges: removed.len(),
            ..Maintenance::default()
        };
        let mut views = self.views.clone();
        for (&d, view) in &mut views {
            budget.charge()?;
            let orient = |e: Edge| match d.direction {
                Direction::Downstream => e,
                Direction::Upstream => (e.1, e.0),
            };
            let affected = |e: &Edge| {
                let (a, _) = orient(*e);
                a == d.root || view.nodes.contains(&a)
            };
            let mut removal_affects = false;
            for edge in &removed {
                budget.charge()?;
                removal_affects |= affected(edge);
            }
            if removal_affects {
                // Do not count recursive derivations as source support. Rebuild
                // this root from extensional edges to break orphan cycles.
                view.nodes = Arc::new(self.fresh(&next, d, budget)?);
                report.rederived_views += 1;
            } else {
                let mut seeds = Vec::new();
                for edge in &added {
                    budget.charge()?;
                    if affected(edge) {
                        seeds.push(orient(*edge).1);
                    }
                }
                if seeds.is_empty() {
                    report.unchanged_views += 1;
                } else {
                    view.nodes =
                        Arc::new(self.expand(&next, d, seeds, (*view.nodes).clone(), budget)?);
                    report.expanded_views += 1;
                }
            }
        }
        budget.charge()?;
        self.overlay = next;
        self.views = views;
        self.version = delta.version;
        Ok(report)
    }
    /// Evicts retained roots, not public graph or authoritative overlay facts.
    /// Caller holds historical result Arcs outside this cache's memory bound.
    pub fn evict_idle(&mut self, now: u64, max_idle: u64) -> usize {
        let before = self.views.len();
        self.views
            .retain(|_, v| now.saturating_sub(v.touched) <= max_idle);
        before - self.views.len()
    }
}
