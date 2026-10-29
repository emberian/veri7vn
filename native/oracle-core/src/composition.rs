//! Bounded, exact learned fragment/outer composition from Reader7.
//!
//! This recognizer is untrusted. It does not implement segment, nested, analogy
//! or content-key fallback reading. Its caller must use compositional lexical
//! candidates and must test each fragment for nonempty, executable entity output.
//! All admitted alternatives participate; support never selects a winner.
use crate::grammar::{
    self, Bindings, Fallback, GrammarSpan, MatchLimits, MatchedProgram, Program, ReaderPolicy,
};
use crate::{Budget, Error, Result};
use rusqlite::{params, Connection};
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};

pub const COVERAGE: &str = "exact_fragment_outer_v1";
const MAX_FRAGMENT_WORDS: usize = 30; // Reader7.MAX_FRAG_W

#[derive(Clone, Debug, Serialize)]
struct Fragment {
    start: usize,
    end: usize,
    template: String,
    support: u64,
    program: Program,
}

#[derive(Clone)]
struct Edge {
    end: usize,
    kind: char,
    canonical: String,
    fragment: Option<usize>,
}

/// Find complete learned outer questions using bounded X-region holes first.
/// Parse only demanded regions, then validate consumed fragments once per program.
/// Prefix probes prune impossible lexical choices; unused fragments never run.
/// The mutable DFS path is shared; parse trees and span powersets are never built.
/// Exhaustion is an error, never a truncated list that could hide disagreement.
///
/// `viable` must reject non-entity and empty fragments, including dead empty
/// branches. It shares the caller's request budget/worker and must not commit.
#[allow(clippy::too_many_arguments)]
pub fn match_composed<F>(
    db: &Connection,
    normalized: &str,
    fragment_spans: &[GrammarSpan],
    outer_spans: &[GrammarSpan],
    level: u8,
    policy: &ReaderPolicy,
    limits: MatchLimits,
    budget: &Budget,
    mut viable: F,
) -> Result<Vec<MatchedProgram>>
where
    F: FnMut(&Program) -> Result<bool>,
{
    if level > 1 || normalized.split_whitespace().collect::<Vec<_>>().join(" ") != normalized {
        return Err(Error::Invalid("composition level or normalization".into()));
    }
    if normalized
        .chars()
        .any(|c| c.is_alphanumeric() && !c.is_ascii())
    {
        return Err(Error::Invalid("unreadable reader script".into()));
    }
    let words: Vec<_> = normalized.split_whitespace().collect();
    let mut offsets = Vec::with_capacity(words.len() + 1);
    let mut offset = 0;
    for word in &words {
        offsets.push(offset);
        offset += word.len() + 1;
    }
    offsets.push(normalized.len().saturating_add(1));
    let mut state = Search {
        db,
        words: &words,
        offsets: &offsets,
        level,
        policy,
        limits,
        budget,
        bytes: 0,
        complete: 0,
    };
    state.charge(
        normalized
            .len()
            .saturating_add(offsets.len().saturating_mul(16)),
    )?;
    let fragment_edges = state.edges(normalized, fragment_spans)?;
    let mut outer_edges = state.edges(normalized, outer_spans)?;
    // Outer-first chart: X edges are bounded lexical-boundary holes. They carry
    // no fragment parse or data execution. Only holes in a complete learned
    // outer question become fragment subproblems.
    let ends: BTreeSet<_> = fragment_edges.iter().flatten().map(|e| e.end).collect();
    let mut holes = Vec::<Fragment>::new();
    for start in 0..words.len() {
        if fragment_edges[start].is_empty() {
            continue;
        }
        for &end in ends.range((start + 1)..=words.len().min(start + MAX_FRAGMENT_WORDS)) {
            let index = holes.len();
            let hole = Fragment {
                start: offsets[start],
                end: offsets[end] - 1,
                template: String::new(),
                support: 0,
                program: vec![grammar::Step {
                    function: "@X".into(),
                    dependencies: vec![],
                    inputs: vec![serde_json::json!(index + 1)],
                }],
            };
            state.charge(
                serde_json::to_vec(&hole)?
                    .len()
                    .saturating_add(std::mem::size_of::<Edge>()),
            )?;
            holes.push(hole);
            outer_edges[start].push(Edge {
                end,
                kind: 'X',
                canonical: String::new(),
                fragment: Some(index),
            });
        }
    }
    if holes.is_empty() {
        return Ok(vec![]);
    }
    let outer = state.walk("outer", 0, &outer_edges, &holes, None)?;
    let demanded: BTreeSet<_> = outer
        .iter()
        .flat_map(|f| f.fragments.iter().copied())
        .collect();
    let mut chart = BTreeMap::<usize, Vec<Fragment>>::new();
    for index in demanded {
        let hole = &holes[index];
        let start = offsets
            .binary_search(&hole.start)
            .map_err(|_| Error::Invalid("fragment start".into()))?;
        let end = offsets
            .binary_search(&(hole.end + 1))
            .map_err(|_| Error::Invalid("fragment end".into()))?;
        let found = state.walk("fragment", start, &fragment_edges, &[], Some(end))?;
        let mut seen = BTreeSet::new();
        let mut alternatives = Vec::new();
        for found in found {
            if !seen.insert(serde_json::to_string(&found.program)?) {
                continue;
            }
            let fragment = Fragment {
                start: hole.start,
                end: hole.end,
                template: found.template,
                support: found.support,
                program: found.program,
            };
            state.charge(serde_json::to_vec(&fragment)?.len().saturating_add(64))?;
            alternatives.push(fragment);
        }
        chart.insert(index, alternatives);
    }
    // A syntactically incomplete hole is not a consumed reading. First require
    // every hole to have a learned fragment, then validate the demanded union.
    // Empty executed siblings cannot hide an unsupported complete alternative.
    let outer: Vec<_> = outer
        .into_iter()
        .filter(|f| f.fragments.iter().all(|index| !chart[index].is_empty()))
        .collect();
    let demanded: BTreeSet<_> = outer
        .iter()
        .flat_map(|f| f.fragments.iter().copied())
        .collect();
    let mut viability = BTreeMap::<String, bool>::new();
    for index in demanded {
        for fragment in &chart[&index] {
            let key = serde_json::to_string(&fragment.program)?;
            if let std::collections::btree_map::Entry::Vacant(entry) = viability.entry(key) {
                let value = viable(&fragment.program)?;
                state.charge(entry.key().len().saturating_add(64))?;
                entry.insert(value);
            }
        }
    }
    let mut output = Vec::new();
    let mut joins = 0usize;
    for found in outer {
        let choices: Vec<Vec<&Fragment>> = found
            .fragments
            .iter()
            .map(|index| {
                chart[index]
                    .iter()
                    .filter(|fragment| {
                        // Serialization already succeeded for every retained fragment.
                        viability[&serde_json::to_string(&fragment.program)
                            .expect("serialized fragment")]
                    })
                    .collect()
            })
            .collect();
        if choices.iter().any(Vec::is_empty) {
            continue;
        }
        let mut cursor = vec![0usize; choices.len()];
        loop {
            budget.spend(1)?;
            joins += 1;
            if joins > limits.combinations {
                return Err(Error::Limit("composition joined bindings"));
            }
            let witnesses: Vec<_> = choices
                .iter()
                .zip(&cursor)
                .map(|(alternatives, index)| alternatives[*index])
                .collect();
            let programs = found
                .fragments
                .iter()
                .zip(&witnesses)
                .map(|(index, fragment)| (index + 1, fragment.program.clone()))
                .collect();
            if let Some(program) =
                grammar::expand(&found.program, &Bindings::new(), &programs, limits.steps)?
            {
                let template = serde_json::to_string(
                    &serde_json::json!({"family":COVERAGE,"outer":found.template,"fragments":witnesses}),
                )?;
                let candidate = MatchedProgram {
                    template,
                    level,
                    support: found.support,
                    program,
                };
                if output.len() >= limits.matches {
                    return Err(Error::Limit("composition matches"));
                }
                state.charge(serde_json::to_vec(&candidate)?.len())?;
                output.push(candidate);
            }
            let mut position = cursor.len();
            while position > 0 {
                position -= 1;
                cursor[position] += 1;
                if cursor[position] < choices[position].len() {
                    break;
                }
                cursor[position] = 0;
            }
            if position == 0 && cursor[0] == 0 {
                break;
            }
        }
    }
    Ok(output)
}

struct Found {
    template: String,
    support: u64,
    program: Program,
    fragments: Vec<usize>,
}
struct Search<'a> {
    db: &'a Connection,
    words: &'a [&'a str],
    offsets: &'a [usize],
    level: u8,
    policy: &'a ReaderPolicy,
    limits: MatchLimits,
    budget: &'a Budget,
    bytes: usize,
    complete: usize,
}
impl Search<'_> {
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
    fn edges(&mut self, question: &str, spans: &[GrammarSpan]) -> Result<Vec<Vec<Edge>>> {
        let mut edges = vec![Vec::new(); self.words.len()];
        let mut unique = BTreeSet::new();
        for span in spans {
            grammar::delex(question, std::slice::from_ref(span))?;
            if span.kind == 'X' {
                return Err(Error::Invalid("lexical X span".into()));
            }
            if !unique.insert(span) {
                continue;
            }
            let start = self
                .offsets
                .binary_search(&span.start)
                .map_err(|_| Error::Invalid("composition span start".into()))?;
            let end = self
                .offsets
                .binary_search(&(span.end + 1))
                .map_err(|_| Error::Invalid("composition span end".into()))?;
            self.charge(
                span.canonical
                    .len()
                    .saturating_add(std::mem::size_of::<Edge>()),
            )?;
            edges[start].push(Edge {
                end,
                kind: span.kind,
                canonical: span.canonical.clone(),
                fragment: None,
            });
        }
        Ok(edges)
    }
    fn walk(
        &mut self,
        family: &str,
        start: usize,
        edges: &[Vec<Edge>],
        fragments: &[Fragment],
        region_end: Option<usize>,
    ) -> Result<Vec<Found>> {
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
        let mut xindices = BTreeMap::<usize, usize>::new();
        let mut out = Vec::new();
        let mut query = self.db.prepare_cached("SELECT EXISTS(SELECT 1 FROM reader_template WHERE family=?1 AND level=?2 AND template>=?3 AND template<?4)")?;
        // Bound the live path independently of emitted output and retained chart.
        self.charge(self.words.len().saturating_mul(256))?;
        while !stack.is_empty() {
            self.budget.spend(1)?;
            let top = stack.len() - 1;
            let position = stack[top].position;
            if stack[top].next == 0
                && position > start
                && ((family == "fragment" && stack[top].last_slot && region_end == Some(position))
                    || (family == "outer" && position == self.words.len() && !xindices.is_empty()))
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
                    self.complete += 1;
                    if self.complete > self.limits.combinations {
                        return Err(Error::Limit("composition bindings"));
                    }
                    for candidate in hit.candidates.into_iter().filter(|c| c.rejection.is_none()) {
                        let skeleton: Program = serde_json::from_value(candidate.skeleton)?;
                        let xprograms = xindices
                            .iter()
                            .map(|(ordinal, index)| (*ordinal, fragments[*index].program.clone()))
                            .collect();
                        if let Some(program) =
                            grammar::expand(&skeleton, &texts, &xprograms, self.limits.steps)?
                        {
                            if out.len() >= self.limits.matches {
                                return Err(Error::Limit("composition matches"));
                            }
                            self.charge(
                                serde_json::to_vec(&program)?
                                    .len()
                                    .saturating_add(prefix.len())
                                    .saturating_add(64),
                            )?;
                            out.push(Found {
                                template: prefix.clone(),
                                support: candidate.support,
                                program,
                                fragments: xindices.values().copied().collect(),
                            });
                        }
                    }
                }
            }
            let transition = stack[top].next;
            stack[top].next += 1;
            let extend = position < region_end.unwrap_or(self.words.len())
                && (family != "fragment" || position - start < MAX_FRAGMENT_WORDS);
            if extend && transition <= edges[position].len() {
                // Source fragments require the first/last item to be lexical;
                // literal glue is permitted only between those endpoints.
                if family == "fragment" && position == start && transition == 0 {
                    continue;
                }
                let edge = if transition == 0 {
                    None
                } else {
                    Some(&edges[position][transition - 1])
                };
                let end = edge.map_or(position + 1, |e| e.end);
                if family == "fragment"
                    && (end - start > MAX_FRAGMENT_WORDS
                        || end > region_end.unwrap_or(self.words.len()))
                {
                    continue;
                }
                let ordinal = edge.map(|e| counters.get(&e.kind).copied().unwrap_or(0) + 1);
                let token = edge.map_or_else(
                    || self.words[position].to_string(),
                    |e| format!("{}{}", e.kind, ordinal.expect("slot ordinal")),
                );
                let length = prefix.len();
                if !prefix.is_empty() {
                    prefix.push(' ');
                }
                prefix.push_str(&token);
                self.budget.spend(prefix.len() as u64 + 1)?;
                let longer: bool = query.query_row(
                    params![family, self.level, &prefix, format!("{prefix}! ")],
                    |r| r.get(0),
                )?;
                // [prefix, prefix+'! ') includes exact key and token-boundary
                // continuations, while excluding E10 as a continuation of E1.
                if longer {
                    let binding = edge.map(|e| {
                        let ordinal = ordinal.expect("slot ordinal");
                        counters.insert(e.kind, ordinal);
                        if let Some(index) = e.fragment {
                            xindices.insert(ordinal, index);
                        } else {
                            texts.insert((e.kind, ordinal), e.canonical.clone());
                        }
                        (e.kind, ordinal)
                    });
                    stack.push(Frame {
                        position: end,
                        next: 0,
                        length,
                        binding,
                        last_slot: edge.is_some(),
                    });
                } else {
                    prefix.truncate(length);
                }
                continue;
            }
            let frame = stack.pop().expect("nonempty composition path");
            prefix.truncate(frame.length);
            if let Some((kind, ordinal)) = frame.binding {
                counters.insert(kind, ordinal - 1);
                if kind == 'X' {
                    xindices.remove(&ordinal);
                } else {
                    texts.remove(&(kind, ordinal));
                }
            }
        }
        Ok(out)
    }
}
