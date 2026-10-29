//! Exact learned segment chains and one pre-nested fragment pass from Reader7.
//!
//! This is an untrusted recognizer. It does not infer language from keywords or
//! treat missing source rows as completeness. Content/strip fallbacks, analogy,
//! clause patches and deeper nesting are outside this coverage. Syntax is built
//! only for outer-demanded regions; the consumer checks every consumed program
//! for supported, nonempty entity stages using its shared execution workspace.
//!
//! Storage is a request-local arena. Steps and programs are interned by their
//! exact JSON content, so a program shared by many chains is stored once. A
//! region alternative is a thin node: its region, an interned program, support
//! and provenance ids (segment units, or a nested recipe and child nodes). The
//! public `Fragment` JSON, including provenance templates, is rebuilt only at
//! the output boundary; programs are flattened only for the viability check,
//! nested expansion and output.
use crate::grammar::{
    self, Bindings, Fallback, GrammarSpan, MatchLimits, Program, ReaderPolicy, Step,
};
use crate::{Budget, Error, Result};
use rusqlite::{params, Connection};
use serde::Serialize;
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::sync::Arc;

pub const COVERAGE: &str = "exact_segment_and_single_nested_v1";
pub(crate) const MAX_FRAGMENT_WORDS: usize = 30;
const MAX_UNIT_WORDS: usize = 12;
const MAX_UNITS: usize = 4;
pub(crate) const MAX_REGION_WORDS: usize = MAX_UNIT_WORDS * MAX_UNITS;
pub(crate) type Region = (usize, usize); // Word offsets, end exclusive.
/// Approximate per-entry container overhead charged beside each owned value.
const ENTRY: usize = 32;

/// Public form of one region alternative. Built only at the output boundary.
#[derive(Clone, Debug, Serialize)]
pub(crate) struct Fragment {
    pub start: usize,
    pub end: usize,
    pub template: String,
    pub support: u64,
    pub program: Program,
    /// Selected pre-nested child programs, including template X slots omitted
    /// from the parent skeleton. Reader7 admits these children before nesting.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub required_children: Vec<ChildWitness>,
}
#[derive(Clone, Debug, Serialize)]
pub(crate) struct ChildWitness {
    pub start: usize,
    pub end: usize,
    pub program: Program,
}

/// Owners of the composition byte envelope. Kept so a measurement can say
/// where retained bytes went; it never changes a decision or error text.
#[derive(Clone, Copy, Debug)]
pub(crate) enum Owner {
    Question,
    Lexical,
    OuterHoles,
    OuterFound,
    Walk,
    Arena,
    Units,
    Nodes,
    Seen,
    Recipes,
    Caches,
    Resolved,
    Viability,
    Scratch,
    Output,
}
pub(crate) const OWNERS: [&str; 15] = [
    "question",
    "lexical_edges",
    "outer_holes",
    "outer_found",
    "walk_scratch",
    "arena_steps_programs",
    "units",
    "region_nodes",
    "active_dedup",
    "nested_recipes",
    "cache_headers",
    "resolved_node_keys",
    "viability_cache",
    "flatten_scratch",
    "output",
];

/// One request's composition byte envelope. Temporary charges are released by
/// their owner; retained charges are never refunded. Fuel is spent for every
/// charge and is never refunded.
pub(crate) struct Ledger {
    pub bytes: usize,
    limit: usize,
    owners: [usize; OWNERS.len()],
    pub peak: usize,
    pub peak_owners: [usize; OWNERS.len()],
}
impl Ledger {
    pub fn new(limit: usize) -> Self {
        Self {
            bytes: 0,
            limit,
            owners: [0; OWNERS.len()],
            peak: 0,
            peak_owners: [0; OWNERS.len()],
        }
    }
    pub fn charge(&mut self, budget: &Budget, bytes: usize, owner: Owner) -> Result<()> {
        budget.spend(bytes as u64 + 1)?;
        self.bytes = self
            .bytes
            .checked_add(bytes)
            .ok_or(Error::Limit("composition bytes"))?;
        let slot = &mut self.owners[owner as usize];
        *slot = slot.saturating_add(bytes);
        if self.bytes > self.peak {
            self.peak = self.bytes;
            self.peak_owners = self.owners;
        }
        if self.bytes > self.limit {
            return Err(Error::Limit("composition bytes"));
        }
        Ok(())
    }
    pub fn release(&mut self, bytes: usize, owner: Owner) {
        // Only owned temporary allocations leave the materialization envelope.
        // Request fuel remains cumulative; ownership transfers never refund work.
        self.bytes = self
            .bytes
            .checked_sub(bytes)
            .expect("balanced composition ownership");
        let slot = &mut self.owners[owner as usize];
        *slot = slot.checked_sub(bytes).expect("balanced composition owner");
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub(crate) struct ProgramId(u32);
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub(crate) struct NodeId(u32);
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct UnitId(u32);

/// Exact content key of a region alternative: its program and its child
/// witnesses. Equal keys are exactly equal `(program, required_children)`
/// JSON, the identity the flat representation used.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub(crate) struct NodeKey {
    pub program: ProgramId,
    pub children: Box<[(Region, ProgramId)]>,
}
impl NodeKey {
    pub fn size(&self) -> usize {
        std::mem::size_of::<Self>()
            + self.children.len() * std::mem::size_of::<(Region, ProgramId)>()
    }
}

/// Content-interned steps and programs. A step's identity is the exact JSON
/// of `(function, inputs)`; dependencies live in the program encoding. A
/// program is encoded as `[step, dependency count, dependencies..]*`, so two
/// programs share an id exactly when their serialized JSON is equal.
#[derive(Default)]
struct Arena {
    step_ids: HashMap<String, u32>,
    steps: Vec<(String, Vec<Value>)>,
    program_ids: HashMap<Arc<[usize]>, ProgramId>,
    programs: Vec<Arc<[usize]>>,
}

#[derive(Clone)]
struct Edge {
    end: usize,
    kind: char,
    canonical: String,
}
struct Unit {
    end: usize,
    source: bool,
    template: Box<str>,
    support: u64,
    steps: ProgramId,
}
impl Unit {
    fn role(&self) -> &'static str {
        if self.source {
            "source"
        } else {
            "filter"
        }
    }
}
enum Origin {
    /// A learned exact fragment; its template is the matched prefix.
    Direct(Box<str>),
    /// A 2–4 unit segment chain, in surface order.
    Chain(Box<[UnitId]>),
    /// One nested learned fragment over already admitted base children.
    Nested {
        recipe: Arc<str>,
        children: Box<[NodeId]>,
    },
}
struct Node {
    region: Region,
    support: u64,
    program: ProgramId,
    origin: Origin,
}
impl Node {
    fn size(&self) -> usize {
        std::mem::size_of::<Self>()
            + match &self.origin {
                Origin::Direct(template) => template.len(),
                Origin::Chain(units) => units.len() * std::mem::size_of::<UnitId>(),
                Origin::Nested { children, .. } => children.len() * std::mem::size_of::<NodeId>(),
            }
    }
}
struct Parsed {
    end: usize,
    template: String,
    support: u64,
    program: Program,
    role: Option<String>,
    children: BTreeMap<usize, Region>,
    retained_bytes: usize,
}

/// A complete region's syntax recipes. Nested children stay shared choices;
/// no parent product is formed before the demanded base programs are admitted.
pub(crate) struct RegionPlan {
    region: Region,
    direct: Arc<Vec<NodeId>>,
    nested: Vec<NestedPlan>,
}
struct NestedPlan {
    template: Arc<str>,
    support: u64,
    program: Program,
    children: Vec<(usize, Arc<Vec<NodeId>>)>,
}
impl RegionPlan {
    pub fn has_syntax(&self) -> bool {
        !self.direct.is_empty() || !self.nested.is_empty()
    }
    /// Direct alternatives, then every nested recipe's child alternatives.
    pub fn base_nodes(&self) -> impl Iterator<Item = NodeId> + '_ {
        self.direct.iter().copied().chain(
            self.nested
                .iter()
                .flat_map(|plan| plan.children.iter().flat_map(|(_, c)| c.iter().copied())),
        )
    }
}

/// Request-local syntax DAG. Base regions contain direct exact fragments and
/// 2–4 segment chains. Nested regions may use those bases once, never themselves.
/// Accounting continues the outer search's ledger, under the same envelopes.
pub(crate) struct Chart<'a> {
    db: &'a Connection,
    words: Vec<&'a str>,
    offsets: Vec<usize>,
    edges: Vec<Vec<Edge>>,
    ends: Vec<usize>,
    level: u8,
    policy: &'a ReaderPolicy,
    limits: MatchLimits,
    budget: &'a Budget,
    ledger: &'a mut Ledger,
    pub complete: usize,
    // Resolved chart nodes, including independent child admission witnesses.
    // Unresolved slot paths/units consume fuel and bytes, not this node cap.
    resolved: BTreeSet<(Region, NodeKey)>,
    bases: BTreeMap<Region, Arc<Vec<NodeId>>>,
    units: BTreeMap<(usize, bool), Arc<Vec<UnitId>>>,
    arena: Arena,
    unit_store: Vec<Unit>,
    nodes: Vec<Node>,
}
impl<'a> Chart<'a> {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        db: &'a Connection,
        normalized: &'a str,
        spans: &[GrammarSpan],
        level: u8,
        policy: &'a ReaderPolicy,
        limits: MatchLimits,
        budget: &'a Budget,
        ledger: &'a mut Ledger,
        complete: usize,
    ) -> Result<Self> {
        let words: Vec<_> = normalized.split_whitespace().collect();
        let mut offsets = Vec::with_capacity(words.len() + 1);
        let mut offset = 0;
        for word in &words {
            offsets.push(offset);
            offset += word.len() + 1;
        }
        offsets.push(normalized.len().saturating_add(1));
        let mut chart = Self {
            db,
            edges: vec![vec![]; words.len()],
            words,
            offsets,
            ends: vec![],
            level,
            policy,
            limits,
            budget,
            ledger,
            complete,
            resolved: BTreeSet::new(),
            bases: BTreeMap::new(),
            units: BTreeMap::new(),
            arena: Arena::default(),
            unit_store: Vec::new(),
            nodes: Vec::new(),
        };
        chart.charge(
            normalized
                .len()
                .saturating_add(chart.words.len().saturating_mul(256)),
            Owner::Question,
        )?;
        let mut unique = BTreeSet::new();
        let mut ends = BTreeSet::new();
        for span in spans {
            grammar::delex(normalized, std::slice::from_ref(span))?;
            if span.kind == 'X' {
                return Err(Error::Invalid("lexical X span".into()));
            }
            if !unique.insert(span) {
                continue;
            }
            let start = chart
                .offsets
                .binary_search(&span.start)
                .map_err(|_| Error::Invalid("segment span start".into()))?;
            let end = chart
                .offsets
                .binary_search(&(span.end + 1))
                .map_err(|_| Error::Invalid("segment span end".into()))?;
            chart.charge(
                span.canonical
                    .len()
                    .saturating_add(std::mem::size_of::<Edge>()),
                Owner::Lexical,
            )?;
            chart.edges[start].push(Edge {
                end,
                kind: span.kind,
                canonical: span.canonical.clone(),
            });
            ends.insert(end);
        }
        chart.ends = ends.into_iter().collect();
        Ok(chart)
    }
    pub fn charge(&mut self, bytes: usize, owner: Owner) -> Result<()> {
        self.ledger.charge(self.budget, bytes, owner)
    }
    pub fn release(&mut self, bytes: usize, owner: Owner) {
        self.ledger.release(bytes, owner);
    }

    // ---- Arena: exact content interning --------------------------------

    fn intern_step(&mut self, function: &str, inputs: &[Value]) -> Result<u32> {
        let key = serde_json::to_string(&(function, inputs))?;
        if let Some(&id) = self.arena.step_ids.get(&key) {
            return Ok(id);
        }
        // The key string and the parsed step are both retained once.
        self.charge(key.len().saturating_mul(2).saturating_add(64), Owner::Arena)?;
        let id =
            u32::try_from(self.arena.steps.len()).map_err(|_| Error::Limit("composition bytes"))?;
        self.arena
            .steps
            .push((function.to_owned(), inputs.to_vec()));
        self.arena.step_ids.insert(key, id);
        Ok(id)
    }
    fn intern_encoded(&mut self, encoded: Vec<usize>) -> Result<ProgramId> {
        if let Some(&id) = self.arena.program_ids.get(encoded.as_slice()) {
            return Ok(id);
        }
        self.charge(
            encoded
                .len()
                .saturating_mul(std::mem::size_of::<usize>())
                .saturating_add(64),
            Owner::Arena,
        )?;
        let id = ProgramId(
            u32::try_from(self.arena.programs.len())
                .map_err(|_| Error::Limit("composition bytes"))?,
        );
        let shared: Arc<[usize]> = encoded.into();
        self.arena.programs.push(shared.clone());
        self.arena.program_ids.insert(shared, id);
        Ok(id)
    }
    /// Intern a program by exact content; equal JSON yields the same id.
    pub fn intern(&mut self, program: &Program) -> Result<ProgramId> {
        let mut encoded = Vec::with_capacity(program.len() * 3);
        for step in program {
            encoded.push(self.intern_step(&step.function, &step.inputs)? as usize);
            encoded.push(step.dependencies.len());
            encoded.extend_from_slice(&step.dependencies);
        }
        self.intern_encoded(encoded)
    }
    /// Steps of an interned program, as (step id, dependencies).
    fn decode(&self, id: ProgramId) -> Vec<(u32, &[usize])> {
        let encoded = &self.arena.programs[id.0 as usize];
        let mut steps = Vec::new();
        let mut i = 0;
        while i < encoded.len() {
            let count = encoded[i + 1];
            steps.push((encoded[i] as u32, &encoded[i + 2..i + 2 + count]));
            i += 2 + count;
        }
        steps
    }
    /// The flat public program. Callers charge it while it is live.
    pub fn program(&self, id: ProgramId) -> Program {
        self.decode(id)
            .into_iter()
            .map(|(step, dependencies)| {
                let (function, inputs) = &self.arena.steps[step as usize];
                Step {
                    function: function.clone(),
                    dependencies: dependencies.to_vec(),
                    inputs: inputs.clone(),
                }
            })
            .collect()
    }
    /// Upper bound on a flattened program's heap bytes, for scratch charges.
    pub fn flat_size(&self, id: ProgramId) -> usize {
        self.decode(id)
            .into_iter()
            .map(|(step, dependencies)| {
                let (function, inputs) = &self.arena.steps[step as usize];
                std::mem::size_of::<Step>()
                    + function.len()
                    + std::mem::size_of_val(dependencies)
                    + serde_json::to_string(inputs).map_or(0, |s| s.len())
            })
            .sum()
    }

    // ---- Nodes -----------------------------------------------------------

    pub fn key(&self, id: NodeId) -> (Region, NodeKey) {
        let node = &self.nodes[id.0 as usize];
        let children = match &node.origin {
            Origin::Nested { children, .. } => children
                .iter()
                .map(|child| {
                    let child = &self.nodes[child.0 as usize];
                    (child.region, child.program)
                })
                .collect(),
            _ => Box::default(),
        };
        (
            node.region,
            NodeKey {
                program: node.program,
                children,
            },
        )
    }
    pub fn node_program(&self, id: NodeId) -> ProgramId {
        self.nodes[id.0 as usize].program
    }
    /// Programs of the child witnesses (empty for a base node).
    pub fn child_programs(&self, id: NodeId) -> Vec<ProgramId> {
        match &self.nodes[id.0 as usize].origin {
            Origin::Nested { children, .. } => {
                children.iter().map(|&c| self.node_program(c)).collect()
            }
            _ => vec![],
        }
    }
    fn template(&self, id: NodeId) -> Result<String> {
        let node = &self.nodes[id.0 as usize];
        Ok(match &node.origin {
            Origin::Direct(template) => template.to_string(),
            Origin::Chain(units) => {
                let provenance: Vec<_> = units
                    .iter()
                    .map(|u| {
                        let unit = &self.unit_store[u.0 as usize];
                        (&*unit.template, unit.role(), unit.support)
                    })
                    .collect();
                serde_json::to_string(
                    &serde_json::json!({"family":COVERAGE,"segments":provenance}),
                )?
            }
            Origin::Nested { recipe, children } => {
                let mut rows = Vec::with_capacity(children.len());
                for &child in children.iter() {
                    let node = &self.nodes[child.0 as usize];
                    rows.push((
                        self.offsets[node.region.0],
                        self.offsets[node.region.1] - 1,
                        self.template(child)?,
                        node.support,
                    ));
                }
                serde_json::to_string(&serde_json::json!({
                    "family":COVERAGE,"nested":&**recipe,"children":rows
                }))?
            }
        })
    }
    /// The public fragment, rebuilt from the arena. Callers charge it while live.
    pub fn fragment(&self, id: NodeId) -> Result<Fragment> {
        let node = &self.nodes[id.0 as usize];
        let required_children = match &node.origin {
            Origin::Nested { children, .. } => children
                .iter()
                .map(|&c| {
                    let child = &self.nodes[c.0 as usize];
                    ChildWitness {
                        start: self.offsets[child.region.0],
                        end: self.offsets[child.region.1] - 1,
                        program: self.program(child.program),
                    }
                })
                .collect(),
            _ => vec![],
        };
        Ok(Fragment {
            start: self.offsets[node.region.0],
            end: self.offsets[node.region.1] - 1,
            template: self.template(id)?,
            support: node.support,
            program: self.program(node.program),
            required_children,
        })
    }

    fn admit(&mut self, region: Region, key: &NodeKey) -> Result<()> {
        let node = (region, key.clone());
        if !self.resolved.contains(&node) {
            self.complete += 1;
            if self.complete > self.limits.combinations {
                return Err(Error::Limit("composition bindings"));
            }
            self.charge(key.size().saturating_add(ENTRY), Owner::Resolved)?;
            self.resolved.insert(node);
        }
        Ok(())
    }
    /// Cached semantic admission of one interned program. The caller's
    /// closure sees the flat program; the cache is keyed by exact content id.
    pub fn check<F>(
        &mut self,
        program: ProgramId,
        cache: &mut BTreeMap<ProgramId, bool>,
        viable: &mut F,
    ) -> Result<bool>
    where
        F: FnMut(&Program) -> Result<bool>,
    {
        if let Some(value) = cache.get(&program) {
            return Ok(*value);
        }
        let scratch = self.flat_size(program);
        self.charge(scratch, Owner::Scratch)?;
        let flat = self.program(program);
        let value = viable(&flat);
        drop(flat);
        self.release(scratch, Owner::Scratch);
        let value = value?;
        self.charge(
            std::mem::size_of::<(ProgramId, bool)>().saturating_add(ENTRY),
            Owner::Viability,
        )?;
        cache.insert(program, value);
        Ok(value)
    }
    fn retain(
        &mut self,
        output: &mut Vec<NodeId>,
        seen: &mut BTreeSet<NodeKey>,
        key: NodeKey,
        node: Node,
    ) -> Result<()> {
        self.budget.spend(1)?;
        // Parent program equality cannot erase an unsupported or empty child
        // witness when a release skeleton omits its template's X reference.
        let key_size = key.size().saturating_add(ENTRY);
        if !seen.insert(key) {
            return Ok(());
        }
        // The active dedup entry is released when its owner finishes.
        self.charge(key_size, Owner::Seen)?;
        if output.len() >= self.limits.matches {
            return Err(Error::Limit("composition matches"));
        }
        self.charge(
            node.size().saturating_add(std::mem::size_of::<NodeId>()),
            Owner::Nodes,
        )?;
        let id = NodeId(
            u32::try_from(self.nodes.len()).map_err(|_| Error::Limit("composition matches"))?,
        );
        self.nodes.push(node);
        output.push(id);
        Ok(())
    }
    fn release_seen(&mut self, seen: &BTreeSet<NodeKey>) {
        self.release(
            seen.iter()
                .map(|key| key.size().saturating_add(ENTRY))
                .sum(),
            Owner::Seen,
        );
    }

    /// Keep complete syntax without forming any nested child products. Outer
    /// syntax reachability is established before check()/resolve() may execute.
    pub fn region(&mut self, start_byte: usize, end_byte: usize) -> Result<RegionPlan> {
        let start = self
            .offsets
            .binary_search(&start_byte)
            .map_err(|_| Error::Invalid("fragment start".into()))?;
        let end = self
            .offsets
            .binary_search(&(end_byte + 1))
            .map_err(|_| Error::Invalid("fragment end".into()))?;
        let region = (start, end);
        let direct = self.base(region)?;
        let mut nested = Vec::new();
        if end - start <= MAX_FRAGMENT_WORDS {
            self.walk("fragment", start, end, true, true, true, |chart, parsed| {
                // The recipe owns this program/prefix while child syntax is
                // demanded. Move that ownership out of the transient walker.
                chart.charge(parsed.retained_bytes, Owner::Recipes)?;
                let mut children = Vec::new();
                for (&ordinal, &child) in &parsed.children {
                    children.push((ordinal, chart.base(child)?));
                }
                if children.iter().any(|(_, choices)| choices.is_empty()) {
                    chart.release(parsed.retained_bytes, Owner::Recipes);
                    return Ok(());
                }
                chart.charge(
                    children.len().saturating_mul(32).saturating_add(64),
                    Owner::Recipes,
                )?;
                nested.push(NestedPlan {
                    template: parsed.template.into(),
                    support: parsed.support,
                    program: parsed.program,
                    children,
                });
                Ok(())
            })?;
        }
        Ok(RegionPlan {
            region,
            direct,
            nested,
        })
    }
    /// Source Reader7 admits runnable/nonempty pre-nested fragments first.
    /// All demanded bases have already been checked independently, including
    /// unsupported alternatives beside empty siblings. Only viable choices now
    /// enter nested products, and independent child-region witnesses survive.
    pub fn resolve<F>(
        &mut self,
        plan: &RegionPlan,
        cache: &mut BTreeMap<ProgramId, bool>,
        viable: &mut F,
    ) -> Result<Vec<NodeId>>
    where
        F: FnMut(&Program) -> Result<bool>,
    {
        let mut output = Vec::new();
        let mut seen = BTreeSet::new();
        for &id in plan.direct.iter() {
            if cache[&self.node_program(id)] {
                let (region, key) = self.key(id);
                self.admit(region, &key)?;
                // The base node is shared, not copied: dedup by key only.
                self.budget.spend(1)?;
                let key_size = key.size().saturating_add(ENTRY);
                if seen.insert(key) {
                    self.charge(key_size, Owner::Seen)?;
                    if output.len() >= self.limits.matches {
                        return Err(Error::Limit("composition matches"));
                    }
                    self.charge(std::mem::size_of::<NodeId>(), Owner::Nodes)?;
                    output.push(id);
                }
            }
        }
        for nested in &plan.nested {
            let choices: Vec<(usize, Vec<NodeId>)> = nested
                .children
                .iter()
                .map(|(ordinal, alternatives)| {
                    (
                        *ordinal,
                        alternatives
                            .iter()
                            .copied()
                            .filter(|&id| cache[&self.node_program(id)])
                            .collect(),
                    )
                })
                .collect();
            if choices
                .iter()
                .any(|(_, alternatives)| alternatives.is_empty())
            {
                continue;
            }
            // These base nodes belong to at least one complete nested syntax
            // whose every child has independently passed semantic admission.
            for (_, alternatives) in &choices {
                for &child in alternatives {
                    let (region, key) = self.key(child);
                    self.admit(region, &key)?;
                }
            }
            let sizes: Vec<_> = choices
                .iter()
                .map(|(_, alternatives)| alternatives.len())
                .collect();
            let mut cursor = vec![0usize; choices.len()];
            loop {
                self.budget.spend(1)?;
                let selected: Vec<NodeId> = choices
                    .iter()
                    .zip(&cursor)
                    .map(|((_, alternatives), i)| alternatives[*i])
                    .collect();
                let scratch: usize = selected
                    .iter()
                    .map(|&id| self.flat_size(self.node_program(id)))
                    .sum();
                self.charge(scratch, Owner::Scratch)?;
                let programs = choices
                    .iter()
                    .zip(&selected)
                    .map(|((ordinal, _), &id)| (*ordinal, self.program(self.node_program(id))))
                    .collect();
                let expanded = grammar::expand(
                    &nested.program,
                    &Bindings::new(),
                    &programs,
                    self.limits.steps,
                );
                drop(programs);
                self.release(scratch, Owner::Scratch);
                if let Some(program) = expanded? {
                    let program = self.intern(&program)?;
                    let key = NodeKey {
                        program,
                        children: selected
                            .iter()
                            .map(|&id| {
                                let child = &self.nodes[id.0 as usize];
                                (child.region, child.program)
                            })
                            .collect(),
                    };
                    self.admit(plan.region, &key)?;
                    if self.check(program, cache, viable)? {
                        let node = Node {
                            region: plan.region,
                            support: nested.support,
                            program,
                            origin: Origin::Nested {
                                recipe: nested.template.clone(),
                                children: selected.into(),
                            },
                        };
                        self.retain(&mut output, &mut seen, key, node)?;
                    }
                }
                if !advance(&mut cursor, &sizes) {
                    break;
                }
            }
        }
        self.release_seen(&seen);
        drop(seen);
        Ok(output)
    }
    fn base(&mut self, region: Region) -> Result<Arc<Vec<NodeId>>> {
        if let Some(found) = self.bases.get(&region) {
            return Ok(found.clone());
        }
        let (start, end) = region;
        let mut output = Vec::new();
        let mut seen = BTreeSet::new();
        if end - start <= MAX_FRAGMENT_WORDS {
            self.walk(
                "fragment",
                start,
                end,
                true,
                true,
                false,
                |chart, parsed| {
                    let program = chart.intern(&parsed.program)?;
                    let node = Node {
                        region,
                        support: parsed.support,
                        program,
                        origin: Origin::Direct(parsed.template.into()),
                    };
                    let key = NodeKey {
                        program,
                        children: Box::default(),
                    };
                    chart.retain(&mut output, &mut seen, key, node)
                },
            )?;
        }
        // A shared mutable path, not copied frontier/powerset states. The source
        // language permits four units; an exhausted host envelope is an error.
        let mut path = Vec::new();
        self.chains(region, start, &mut path, &mut output, &mut seen)?;
        self.release_seen(&seen);
        drop(seen);
        self.charge(64, Owner::Caches)?;
        let output = Arc::new(output);
        self.bases.insert(region, output.clone());
        Ok(output)
    }
    fn units(&mut self, start: usize, first: bool) -> Result<Arc<Vec<UnitId>>> {
        if let Some(found) = self.units.get(&(start, first)) {
            return Ok(found.clone());
        }
        const SEEN: usize = std::mem::size_of::<(usize, bool, ProgramId)>() + ENTRY;
        let mut units = Vec::new();
        let mut seen = BTreeSet::new();
        let end = self.words.len().min(start + MAX_UNIT_WORDS);
        self.walk(
            "segment",
            start,
            end,
            false,
            first,
            false,
            |chart, parsed| {
                let role = parsed
                    .role
                    .ok_or_else(|| Error::Format("segment role".into()))?;
                let steps = chart.intern(&parsed.program)?;
                // Canonical-equivalent paths share one endpoint/role/program node.
                let source = role == "source";
                if seen.insert((parsed.end, source, steps)) {
                    chart.charge(SEEN, Owner::Seen)?;
                    chart.charge(
                        std::mem::size_of::<Unit>()
                            .saturating_add(parsed.template.len())
                            .saturating_add(std::mem::size_of::<UnitId>()),
                        Owner::Units,
                    )?;
                    let id = UnitId(
                        u32::try_from(chart.unit_store.len())
                            .map_err(|_| Error::Limit("composition matches"))?,
                    );
                    chart.unit_store.push(Unit {
                        end: parsed.end,
                        source,
                        template: parsed.template.into(),
                        support: parsed.support,
                        steps,
                    });
                    units.push(id);
                }
                Ok(())
            },
        )?;
        self.release(seen.len() * SEEN, Owner::Seen);
        drop(seen);
        self.charge(64, Owner::Caches)?;
        let units = Arc::new(units);
        self.units.insert((start, first), units.clone());
        Ok(units)
    }
    fn chains(
        &mut self,
        region: Region,
        position: usize,
        path: &mut Vec<UnitId>,
        output: &mut Vec<NodeId>,
        seen: &mut BTreeSet<NodeKey>,
    ) -> Result<()> {
        if path.len() >= MAX_UNITS || position >= region.1 {
            return Ok(());
        }
        let alternatives = self.units(position, path.is_empty())?;
        for &id in alternatives.iter() {
            self.budget.spend(1)?;
            let (end, source) = {
                let unit = &self.unit_store[id.0 as usize];
                (unit.end, unit.source)
            };
            if end > region.1
                || (source && path.iter().any(|u| self.unit_store[u.0 as usize].source))
            {
                continue;
            }
            path.push(id);
            if end == region.1 && path.len() > 1 {
                let program = self.assemble(path)?;
                let support = path
                    .iter()
                    .map(|u| self.unit_store[u.0 as usize].support)
                    .min()
                    .unwrap_or(0);
                let node = Node {
                    region,
                    support,
                    program,
                    origin: Origin::Chain(path.as_slice().into()),
                };
                let key = NodeKey {
                    program,
                    children: Box::default(),
                };
                self.retain(output, seen, key, node)?;
            } else if end < region.1 {
                self.chains(region, end, path, output, seen)?;
            }
            path.pop();
        }
        Ok(())
    }
    /// Reader7's chain assembly over interned unit steps: the source unit (or
    /// `FindAll`), then a stable partition of filter units, concept filters
    /// first, each keeping surface order; every step depends on its predecessor.
    fn assemble(&mut self, units: &[UnitId]) -> Result<ProgramId> {
        let max_steps = self.limits.steps;
        let source = units
            .iter()
            .map(|u| &self.unit_store[u.0 as usize])
            .find(|u| u.source)
            .map(|u| u.steps);
        let mut steps: Vec<u32> = match source {
            Some(program) => self.decode(program).into_iter().map(|(s, _)| s).collect(),
            None => vec![self.intern_step("FindAll", &[])?],
        };
        for concept in [true, false] {
            for u in units {
                let unit = &self.unit_store[u.0 as usize];
                if unit.source {
                    continue;
                }
                let unit_steps: Vec<u32> = self
                    .decode(unit.steps)
                    .into_iter()
                    .map(|(s, _)| s)
                    .collect();
                let first_is_concept = unit_steps
                    .first()
                    .is_some_and(|&s| self.arena.steps[s as usize].0 == "FilterConcept");
                if first_is_concept != concept {
                    continue;
                }
                if unit_steps.len() > max_steps.saturating_sub(steps.len()) {
                    return Err(Error::Limit("reader program steps"));
                }
                steps.extend(unit_steps);
            }
        }
        if steps.len() > max_steps {
            return Err(Error::Limit("reader program steps"));
        }
        let mut encoded = Vec::with_capacity(steps.len() * 3);
        for (i, step) in steps.into_iter().enumerate() {
            encoded.push(step as usize);
            if i == 0 {
                encoded.push(0);
            } else {
                encoded.push(1);
                encoded.push(i - 1);
            }
        }
        self.intern_encoded(encoded)
    }

    /// Indexed prefix DFS. Nested holes carry only region IDs, so no child
    /// parse or semantic execution runs until a whole nested wording matches.
    #[allow(clippy::too_many_arguments)]
    fn walk<F>(
        &mut self,
        family: &str,
        start: usize,
        end: usize,
        fixed_end: bool,
        first_slot: bool,
        nested: bool,
        mut emit: F,
    ) -> Result<()>
    where
        F: FnMut(&mut Self, Parsed) -> Result<()>,
    {
        struct Frame {
            position: usize,
            next: usize,
            length: usize,
            binding: Option<(char, usize)>,
            last_slot: bool,
        }
        let mut stack = vec![Frame {
            position: start,
            next: 0,
            length: 0,
            binding: None,
            last_slot: false,
        }];
        let mut prefix = String::new();
        let mut texts = Bindings::new();
        let mut counters = BTreeMap::<char, usize>::new();
        let mut children = BTreeMap::<usize, Region>::new();
        let mut emitted = 0usize;
        let db = self.db;
        let mut query = db.prepare_cached("SELECT EXISTS(SELECT 1 FROM reader_template WHERE family=?1 AND level=?2 AND template>=?3 AND template<?4)")?;
        while !stack.is_empty() {
            self.budget.spend(1)?;
            let top = stack.len() - 1;
            let position = stack[top].position;
            if stack[top].next == 0
                && position > start
                && stack[top].last_slot
                && (!fixed_end || position == end)
                && (nested != children.is_empty())
            {
                if let Some(hit) = grammar::lookup(
                    self.db,
                    family,
                    self.level,
                    &prefix,
                    Fallback::None,
                    self.policy,
                    self.limits.matches,
                    self.budget,
                )? {
                    // A template hit containing unresolved region holes or one
                    // segment unit is not yet a resolved interpretation node.
                    for candidate in hit.candidates.into_iter().filter(|c| c.rejection.is_none()) {
                        let (skeleton, role): (Program, _) = if family == "segment" {
                            let role = candidate
                                .skeleton
                                .get("role")
                                .and_then(|v| v.as_str())
                                .filter(|r| matches!(*r, "source" | "filter"))
                                .ok_or_else(|| Error::Format("segment role".into()))?
                                .to_owned();
                            (
                                serde_json::from_value(
                                    candidate
                                        .skeleton
                                        .get("steps")
                                        .cloned()
                                        .ok_or_else(|| Error::Format("segment steps".into()))?,
                                )?,
                                Some(role),
                            )
                        } else {
                            (serde_json::from_value(candidate.skeleton)?, None)
                        };
                        let placeholders = children
                            .keys()
                            .map(|&n| {
                                (
                                    n,
                                    vec![Step {
                                        function: "@X".into(),
                                        dependencies: vec![],
                                        inputs: vec![serde_json::json!(n)],
                                    }],
                                )
                            })
                            .collect();
                        if let Some(program) =
                            grammar::expand(&skeleton, &texts, &placeholders, self.limits.steps)?
                        {
                            if emitted >= self.limits.matches {
                                return Err(Error::Limit("composition matches"));
                            }
                            emitted += 1;
                            let retained_bytes = serde_json::to_vec(&program)?
                                .len()
                                .saturating_add(prefix.len())
                                .saturating_add(children.len().saturating_mul(48))
                                .saturating_add(64);
                            // Reserve the one live parsed value, then transfer
                            // it immediately to the consumer's owned storage.
                            // No eager result batch or duplicate lifetime charge.
                            self.charge(retained_bytes, Owner::Walk)?;
                            self.release(retained_bytes, Owner::Walk);
                            emit(
                                self,
                                Parsed {
                                    end: position,
                                    template: prefix.clone(),
                                    support: candidate.support,
                                    program,
                                    role,
                                    children: children.clone(),
                                    retained_bytes,
                                },
                            )?;
                        }
                    }
                }
            }
            let transition = stack[top].next;
            stack[top].next += 1;
            let lexical_len = if position < end {
                self.edges[position].len()
            } else {
                0
            };
            let hole_ends = if nested && position < end && lexical_len > 0 {
                self.ends.partition_point(|&e| e <= end)
            } else {
                0
            };
            if position < end && transition <= lexical_len + hole_ends {
                if position == start && first_slot && transition == 0 {
                    continue;
                }
                let (next, kind, canonical, child) = if transition == 0 {
                    (position + 1, None, String::new(), None)
                } else if transition <= lexical_len {
                    let edge = &self.edges[position][transition - 1];
                    (edge.end, Some(edge.kind), edge.canonical.clone(), None)
                } else {
                    let next = self.ends[transition - lexical_len - 1];
                    if next <= position || next - position > MAX_REGION_WORDS {
                        continue;
                    }
                    (next, Some('X'), String::new(), Some((position, next)))
                };
                if next > end {
                    continue;
                }
                let ordinal = kind.map(|k| counters.get(&k).copied().unwrap_or(0) + 1);
                let token = kind.map_or_else(
                    || self.words[position].to_string(),
                    |k| format!("{k}{}", ordinal.expect("slot")),
                );
                let length = prefix.len();
                if !prefix.is_empty() {
                    prefix.push(' ');
                }
                prefix.push_str(&token);
                self.budget.spend(prefix.len() as u64 + 1)?;
                let exists: bool = query.query_row(
                    params![family, self.level, &prefix, format!("{prefix}! ")],
                    |r| r.get(0),
                )?;
                if exists {
                    let binding = kind.map(|k| {
                        let n = ordinal.expect("slot");
                        counters.insert(k, n);
                        if let Some(region) = child {
                            children.insert(n, region);
                        } else {
                            texts.insert((k, n), canonical);
                        }
                        (k, n)
                    });
                    stack.push(Frame {
                        position: next,
                        next: 0,
                        length,
                        binding,
                        last_slot: kind.is_some(),
                    });
                } else {
                    prefix.truncate(length);
                }
                continue;
            }
            let frame = stack.pop().expect("nonempty path");
            prefix.truncate(frame.length);
            if let Some((kind, n)) = frame.binding {
                counters.insert(kind, n - 1);
                if kind == 'X' {
                    children.remove(&n);
                } else {
                    texts.remove(&(kind, n));
                }
            }
        }
        Ok(())
    }
}
fn advance(cursor: &mut [usize], sizes: &[usize]) -> bool {
    for i in (0..cursor.len()).rev() {
        cursor[i] += 1;
        if cursor[i] < sizes[i] {
            return true;
        }
        cursor[i] = 0;
    }
    false
}
