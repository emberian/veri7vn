//! Exact learned segment chains and one pre-nested fragment pass from Reader7.
//!
//! This is an untrusted recognizer. It does not infer language from keywords or
//! treat missing source rows as completeness. Content/strip fallbacks, analogy,
//! clause patches and deeper nesting are outside this coverage. Syntax is built
//! only for outer-demanded regions; the consumer checks every consumed program
//! for supported, nonempty entity stages using its shared execution workspace.
use crate::grammar::{
    self, Bindings, Fallback, GrammarSpan, MatchLimits, Program, ReaderPolicy, Step,
};
use crate::{Budget, Error, Result};
use rusqlite::{params, Connection};
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};
use std::sync::Arc;

pub const COVERAGE: &str = "exact_segment_and_single_nested_v1";
pub(crate) const MAX_FRAGMENT_WORDS: usize = 30;
const MAX_UNIT_WORDS: usize = 12;
const MAX_UNITS: usize = 4;
pub(crate) const MAX_REGION_WORDS: usize = MAX_UNIT_WORDS * MAX_UNITS;
type Region = (usize, usize); // Word offsets, end exclusive.

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
#[derive(Clone)]
struct Edge {
    end: usize,
    kind: char,
    canonical: String,
}
#[derive(Clone, Serialize)]
struct Unit {
    end: usize,
    role: String,
    template: String,
    support: u64,
    steps: Program,
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
    direct: Arc<Vec<Fragment>>,
    nested: Vec<NestedPlan>,
}
struct NestedPlan {
    parsed: Parsed,
    children: Vec<(usize, Arc<Vec<Fragment>>)>,
}
impl RegionPlan {
    pub fn has_syntax(&self) -> bool {
        !self.direct.is_empty() || !self.nested.is_empty()
    }
    pub fn base_programs(&self) -> impl Iterator<Item = &Program> {
        self.direct
            .iter()
            .map(|fragment| &fragment.program)
            .chain(self.nested.iter().flat_map(|plan| {
                plan.children
                    .iter()
                    .flat_map(|(_, choices)| choices.iter().map(|fragment| &fragment.program))
            }))
    }
}

/// Request-local syntax DAG. Base regions contain direct exact fragments and
/// 2–4 segment chains. Nested regions may use those bases once, never themselves.
/// Accounting continues the outer search's counters, under the same envelopes.
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
    pub bytes: usize,
    pub complete: usize,
    // Resolved chart nodes, including independent child admission witnesses.
    // Unresolved slot paths/units consume fuel and bytes, not this node cap.
    resolved: BTreeSet<(usize, usize, String)>,
    bases: BTreeMap<Region, Arc<Vec<Fragment>>>,
    units: BTreeMap<(usize, bool), Arc<Vec<Unit>>>,
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
        bytes: usize,
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
            bytes,
            complete,
            resolved: BTreeSet::new(),
            bases: BTreeMap::new(),
            units: BTreeMap::new(),
        };
        chart.charge(
            normalized
                .len()
                .saturating_add(chart.words.len().saturating_mul(256)),
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
    fn charge(&mut self, bytes: usize) -> Result<()> {
        self.budget.spend(bytes as u64 + 1)?;
        self.bytes = self
            .bytes
            .checked_add(bytes)
            .ok_or(Error::Limit("composition bytes"))?;
        if self.bytes > self.limits.materialized_bytes {
            return Err(Error::Limit("composition bytes"));
        }
        Ok(())
    }
    fn release(&mut self, bytes: usize) {
        // Only owned temporary allocations leave the materialization envelope.
        // Request fuel remains cumulative; ownership transfers never refund work.
        self.bytes = self
            .bytes
            .checked_sub(bytes)
            .expect("balanced composition ownership");
    }
    fn release_seen(&mut self, seen: &BTreeSet<String>) {
        self.release(seen.iter().map(|key| key.len().saturating_add(32)).sum());
    }
    fn admit(&mut self, fragment: &Fragment) -> Result<()> {
        let key = serde_json::to_string(&(&fragment.program, &fragment.required_children))?;
        let node = (fragment.start, fragment.end, key.clone());
        if !self.resolved.contains(&node) {
            self.complete += 1;
            if self.complete > self.limits.combinations {
                return Err(Error::Limit("composition bindings"));
            }
            self.charge(key.len().saturating_add(64))?;
            self.resolved.insert(node);
        }
        Ok(())
    }
    pub fn check<F>(
        &mut self,
        program: &Program,
        cache: &mut BTreeMap<String, bool>,
        viable: &mut F,
    ) -> Result<bool>
    where
        F: FnMut(&Program) -> Result<bool>,
    {
        let key = serde_json::to_string(program)?;
        if let Some(value) = cache.get(&key) {
            return Ok(*value);
        }
        let value = viable(program)?;
        self.charge(key.len().saturating_add(64))?;
        cache.insert(key, value);
        Ok(value)
    }
    fn retain(
        &mut self,
        output: &mut Vec<Fragment>,
        seen: &mut BTreeSet<String>,
        fragment: Fragment,
    ) -> Result<()> {
        self.budget.spend(1)?;
        // Parent program equality cannot erase an unsupported or empty child
        // witness when a release skeleton omits its template's X reference.
        let key = serde_json::to_string(&(&fragment.program, &fragment.required_children))?;
        if !seen.insert(key.clone()) {
            return Ok(());
        }
        if output.len() >= self.limits.matches {
            return Err(Error::Limit("composition matches"));
        }
        self.charge(
            serde_json::to_vec(&fragment)?
                .len()
                .saturating_add(key.len())
                .saturating_add(64),
        )?;
        output.push(fragment);
        Ok(())
    }
    fn fragment(
        &self,
        region: Region,
        template: String,
        support: u64,
        program: Program,
    ) -> Fragment {
        Fragment {
            start: self.offsets[region.0],
            end: self.offsets[region.1] - 1,
            template,
            support,
            program,
            required_children: vec![],
        }
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
                chart.charge(parsed.retained_bytes)?;
                let mut children = Vec::new();
                for (&ordinal, &child) in &parsed.children {
                    children.push((ordinal, chart.base(child)?));
                }
                if children.iter().any(|(_, choices)| choices.is_empty()) {
                    chart.release(parsed.retained_bytes);
                    return Ok(());
                }
                chart.charge(children.len().saturating_mul(32).saturating_add(64))?;
                nested.push(NestedPlan { parsed, children });
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
        cache: &mut BTreeMap<String, bool>,
        viable: &mut F,
    ) -> Result<Vec<Fragment>>
    where
        F: FnMut(&Program) -> Result<bool>,
    {
        let mut output = Vec::new();
        let mut seen = BTreeSet::new();
        for fragment in plan.direct.iter() {
            if cache[&serde_json::to_string(&fragment.program)?] {
                self.admit(fragment)?;
                self.retain(&mut output, &mut seen, fragment.clone())?;
            }
        }
        for nested in &plan.nested {
            let choices: Vec<_> = nested
                .children
                .iter()
                .map(|(ordinal, alternatives)| {
                    (
                        *ordinal,
                        alternatives
                            .iter()
                            .filter(|fragment| {
                                cache[&serde_json::to_string(&fragment.program)
                                    .expect("serialized base")]
                            })
                            .collect::<Vec<_>>(),
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
                for child in alternatives {
                    self.admit(child)?;
                }
            }
            let sizes: Vec<_> = choices
                .iter()
                .map(|(_, alternatives)| alternatives.len())
                .collect();
            let mut cursor = vec![0usize; choices.len()];
            loop {
                self.budget.spend(1)?;
                let programs = choices
                    .iter()
                    .zip(&cursor)
                    .map(|((ordinal, alternatives), i)| {
                        (*ordinal, alternatives[*i].program.clone())
                    })
                    .collect();
                if let Some(program) = grammar::expand(
                    &nested.parsed.program,
                    &Bindings::new(),
                    &programs,
                    self.limits.steps,
                )? {
                    let mut fragment =
                        self.fragment(plan.region, String::new(), nested.parsed.support, program);
                    fragment.required_children = choices
                        .iter()
                        .zip(&cursor)
                        .map(|((_, alternatives), i)| ChildWitness {
                            start: alternatives[*i].start,
                            end: alternatives[*i].end,
                            program: alternatives[*i].program.clone(),
                        })
                        .collect();
                    self.admit(&fragment)?;
                    if self.check(&fragment.program, cache, viable)? {
                        fragment.template = serde_json::to_string(&serde_json::json!({
                            "family":COVERAGE,"nested":nested.parsed.template,
                            "children":choices.iter().zip(&cursor).map(|((_, alternatives), i)| {
                                let child = alternatives[*i];
                                (child.start, child.end, &child.template, child.support)
                            }).collect::<Vec<_>>()
                        }))?;
                        self.retain(&mut output, &mut seen, fragment)?;
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
    fn base(&mut self, region: Region) -> Result<Arc<Vec<Fragment>>> {
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
                    let fragment =
                        chart.fragment(region, parsed.template, parsed.support, parsed.program);
                    chart.retain(&mut output, &mut seen, fragment)
                },
            )?;
        }
        // A shared mutable path, not copied frontier/powerset states. The source
        // language permits four units; an exhausted host envelope is an error.
        let mut path = Vec::new();
        self.chains(region, start, &mut path, &mut output, &mut seen)?;
        self.release_seen(&seen);
        drop(seen);
        self.charge(64)?;
        let output = Arc::new(output);
        self.bases.insert(region, output.clone());
        Ok(output)
    }
    fn units(&mut self, start: usize, first: bool) -> Result<Arc<Vec<Unit>>> {
        if let Some(found) = self.units.get(&(start, first)) {
            return Ok(found.clone());
        }
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
                let unit = Unit {
                    end: parsed.end,
                    role: parsed
                        .role
                        .ok_or_else(|| Error::Format("segment role".into()))?,
                    template: parsed.template,
                    support: parsed.support,
                    steps: parsed.program,
                };
                // Canonical-equivalent paths share one endpoint/role/program node.
                let key = serde_json::to_string(&(unit.end, &unit.role, &unit.steps))?;
                if seen.insert(key.clone()) {
                    chart.charge(
                        serde_json::to_vec(&unit)?
                            .len()
                            .saturating_add(key.len())
                            .saturating_add(64),
                    )?;
                    units.push(unit);
                }
                Ok(())
            },
        )?;
        self.release_seen(&seen);
        drop(seen);
        self.charge(64)?;
        let units = Arc::new(units);
        self.units.insert((start, first), units.clone());
        Ok(units)
    }
    fn chains(
        &mut self,
        region: Region,
        position: usize,
        path: &mut Vec<Unit>,
        output: &mut Vec<Fragment>,
        seen: &mut BTreeSet<String>,
    ) -> Result<()> {
        if path.len() >= MAX_UNITS || position >= region.1 {
            return Ok(());
        }
        let alternatives = self.units(position, path.is_empty())?;
        for unit in alternatives.iter() {
            self.budget.spend(1)?;
            if unit.end > region.1
                || (unit.role == "source" && path.iter().any(|u| u.role == "source"))
            {
                continue;
            }
            path.push(unit.clone());
            if unit.end == region.1 && path.len() > 1 {
                let program = assemble(path, self.limits.steps)?;
                let provenance: Vec<_> = path
                    .iter()
                    .map(|unit| (&unit.template, &unit.role, unit.support))
                    .collect();
                let template = serde_json::to_string(
                    &serde_json::json!({"family":COVERAGE,"segments":provenance}),
                )?;
                let fragment = self.fragment(
                    region,
                    template,
                    path.iter().map(|u| u.support).min().unwrap_or(0),
                    program,
                );
                self.retain(output, seen, fragment)?;
            } else if unit.end < region.1 {
                self.chains(region, unit.end, path, output, seen)?;
            }
            path.pop();
        }
        Ok(())
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
                            self.charge(retained_bytes)?;
                            self.release(retained_bytes);
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
fn assemble(units: &[Unit], max_steps: usize) -> Result<Program> {
    let mut steps = units
        .iter()
        .find(|u| u.role == "source")
        .map(|u| u.steps.clone())
        .unwrap_or_else(|| {
            vec![Step {
                function: "FindAll".into(),
                dependencies: vec![],
                inputs: vec![],
            }]
        });
    // Stable partition matches Reader7's stable sort, retaining surface order
    // within concept filters and within the remaining qualifier-bearing units.
    for concept in [true, false] {
        for unit in units.iter().filter(|u| {
            u.role == "filter"
                && (u
                    .steps
                    .first()
                    .is_some_and(|s| s.function == "FilterConcept")
                    == concept)
        }) {
            if unit.steps.len() > max_steps.saturating_sub(steps.len()) {
                return Err(Error::Limit("reader program steps"));
            }
            steps.extend(unit.steps.iter().cloned());
        }
    }
    if steps.len() > max_steps {
        return Err(Error::Limit("reader program steps"));
    }
    for (i, step) in steps.iter_mut().enumerate() {
        step.dependencies = if i == 0 { vec![] } else { vec![i - 1] };
    }
    Ok(steps)
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
