//! Bounded whole-template language reader over one leased native image worker.
//!
//! This is an untrusted recognizer, not a proof of natural-language meaning.
//! Coverage includes whole templates, exact segments and one nested fragment pass.
//! Fallbacks, analogy and clause patches remain unsupported. Direct
//! graph/program execution does not inherit this reader's admission rules.
use crate::grammar::{self, GrammarSpan, MatchLimits};
use crate::lexicon::{self, CandidateOptions, LexiconLimits};
use crate::packed_program::{self, CompileOrigin, PackedProgramRef, ProgramWorkspace};
use crate::program::Operation;
use crate::query::{encode, evaluate_language_packed, LanguageWorkspace, Selection};
use crate::{Budget, Cancellation, Error, Image, Limits, QueryResult, Result};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{BTreeSet, HashMap};
use std::hash::Hasher;
use std::io::Write;
use std::ops::Deref;
use std::sync::Arc;

pub const COVERAGE: &str = "whole_and_exact_fragment_outer_v1+exact_segment_and_single_nested_v1";

/// Host bounds, not learned language settings. Exhaustion fails the request.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct ReaderLimits {
    pub lexicon: LexiconLimits,
    pub max_name_words: usize,
    /// Whole-template bindings; composition counts unique resolved region and
    /// outer nodes, retaining independent child witnesses. Unresolved chart
    /// paths remain bounded by request fuel, match rows and materialized bytes.
    pub combinations_per_level: usize,
    pub matched_programs: usize,
    pub program_steps: usize,
    pub materialized_bytes: usize,
}
impl Default for ReaderLimits {
    fn default() -> Self {
        Self {
            lexicon: LexiconLimits::default(),
            max_name_words: 8,
            combinations_per_level: 400,
            matched_programs: 4000,
            program_steps: 128,
            materialized_bytes: 2 * 1024 * 1024,
        }
    }
}
impl ReaderLimits {
    fn validate(&self) -> Result<()> {
        if self.max_name_words == 0
            || self.combinations_per_level == 0
            || self.matched_programs == 0
            || self.program_steps == 0
            || self.materialized_bytes == 0
        {
            return Err(Error::Invalid("reader bounds".into()));
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ReaderStatus {
    Answered,
    Unknown,
    Ambiguous,
    Refused,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ReaderReason {
    UnreadableScript,
    NoTemplate,
    NoViableReading,
    UnsupportedProgram,
    AmbiguousExecution,
    AnswerForm,
    AnswerDisagreement,
}
/// Immutable request-owned data. Serialization expands the original public
/// value; references share one payload and one aggregate-memory reservation.
/// Deserialization is a wire boundary and does not inherit a request budget.
pub struct ReaderShared<T>(Arc<Retained<T>>);
struct Retained<T> {
    value: T,
    _memory: Option<crate::budget::MemoryReservation>,
}
impl<T> ReaderShared<T> {
    fn new(value: T, bytes: usize, budget: &Budget) -> Result<Self> {
        let bytes = bytes
            .checked_add(std::mem::size_of::<Retained<T>>() + 2 * std::mem::size_of::<usize>())
            .ok_or(Error::Limit("retained memory accounting overflow"))?;
        let memory = budget.reserve_memory(bytes)?;
        Ok(Self(Arc::new(Retained {
            value,
            _memory: Some(memory),
        })))
    }
    pub(crate) fn with_reservation(value: T, memory: crate::budget::MemoryReservation) -> Self {
        Self(Arc::new(Retained {
            value,
            _memory: Some(memory),
        }))
    }
    /// Transfer an owned payload with its reservation. The usual reader return
    /// has one owner; a future shared caller reserves before making a real copy.
    pub(crate) fn into_owned(
        self,
        bytes: usize,
        budget: &Budget,
    ) -> Result<(T, crate::budget::MemoryReservation)>
    where
        T: Clone,
    {
        match Arc::try_unwrap(self.0) {
            Ok(Retained { value, _memory }) => {
                let memory = match _memory {
                    Some(memory) => memory,
                    None => {
                        budget.reserve_memory(bytes.saturating_add(std::mem::size_of::<T>()))?
                    }
                };
                Ok((value, memory))
            }
            Err(shared) => {
                let memory =
                    budget.reserve_memory(bytes.saturating_add(std::mem::size_of::<T>()))?;
                let value = shared.value.clone();
                Ok((value, memory))
            }
        }
    }
    /// Compare ownership, independently of payload equality.
    pub fn ptr_eq(&self, other: &Self) -> bool {
        Arc::ptr_eq(&self.0, &other.0)
    }
}
impl<T> Clone for ReaderShared<T> {
    fn clone(&self) -> Self {
        Self(Arc::clone(&self.0))
    }
}
impl<T> Deref for ReaderShared<T> {
    type Target = T;
    fn deref(&self) -> &T {
        &self.0.value
    }
}
impl<T: std::fmt::Debug> std::fmt::Debug for ReaderShared<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.deref().fmt(f)
    }
}
impl<T: Serialize> Serialize for ReaderShared<T> {
    fn serialize<S: serde::Serializer>(
        &self,
        serializer: S,
    ) -> std::result::Result<S::Ok, S::Error> {
        self.deref().serialize(serializer)
    }
}
impl<'de, T: Deserialize<'de>> Deserialize<'de> for ReaderShared<T> {
    fn deserialize<D: serde::Deserializer<'de>>(
        deserializer: D,
    ) -> std::result::Result<Self, D::Error> {
        Ok(Self(Arc::new(Retained {
            value: T::deserialize(deserializer)?,
            _memory: None,
        })))
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ReaderReading {
    pub template: String,
    pub level: u8,
    pub support: u64,
    pub program: ReaderShared<grammar::Program>,
    pub answer: String,
    pub result: ReaderShared<QueryResult>,
    #[serde(skip)]
    _memory: Option<crate::budget::MemoryReservation>,
}
#[derive(Debug, Deserialize, Serialize)]
pub struct ReaderResult {
    pub image: String,
    pub coverage: String,
    pub status: ReaderStatus,
    pub reason: Option<ReaderReason>,
    pub answer: Option<String>,
    pub distinct_answers: Vec<String>,
    /// Successfully executed alternatives, including those vetoed by form rules.
    pub readings: Vec<ReaderReading>,
    pub matched_programs: usize,
    pub unsupported_programs: usize,
    pub ambiguous_executions: usize,
}
impl ReaderResult {
    fn empty(identity: &str, reason: ReaderReason) -> Self {
        Self {
            image: identity.into(),
            coverage: COVERAGE.into(),
            status: ReaderStatus::Unknown,
            reason: Some(reason),
            answer: None,
            distinct_answers: vec![],
            readings: vec![],
            matched_programs: 0,
            unsupported_programs: 0,
            ambiguous_executions: 0,
        }
    }
}

/// Shared internal consumer for Image/Runtime. It neither acquires another
/// worker nor touches durable state. The caller retains its worker lease until
/// completion and cleanup. Selection is returned only on agreed answer AND
/// identical selection/evidence across all successful readings.
#[allow(clippy::too_many_arguments)]
pub(crate) fn evaluate_whole(
    db: &Connection,
    identity: &str,
    raw_question: &str,
    previous: &Selection,
    limits: &Limits,
    reader_limits: &ReaderLimits,
    budget: &Budget,
) -> Result<(ReaderResult, Option<ReaderShared<Selection>>)> {
    let outcome = evaluate_inner(
        db,
        identity,
        raw_question,
        previous,
        limits,
        reader_limits,
        budget,
    );
    // Preserve cancellation/deadline/fuel when SQLite reports only Interrupted.
    budget.check()?;
    outcome
}

#[allow(clippy::too_many_arguments)]
fn evaluate_inner(
    db: &Connection,
    identity: &str,
    raw_question: &str,
    previous: &Selection,
    limits: &Limits,
    reader_limits: &ReaderLimits,
    budget: &Budget,
) -> Result<(ReaderResult, Option<ReaderShared<Selection>>)> {
    reader_limits.validate()?;
    budget.check()?;
    if raw_question.len() > limits.request_bytes {
        return Err(Error::Limit("request bytes"));
    }
    if grammar::unreadable(raw_question) {
        let mut result = ReaderResult::empty(identity, ReaderReason::UnreadableScript);
        result.status = ReaderStatus::Refused;
        return Ok((result, None));
    }
    let policy = grammar::read_policy(db)?;
    let normalization = lexicon::grammar_normalization(db)?;
    let bytes_limit = reader_limits
        .materialized_bytes
        .min(limits.materialized_bytes);
    let mut lexical_limits = reader_limits.lexicon.clone();
    lexical_limits.question_bytes = lexical_limits.question_bytes.min(limits.request_bytes);
    lexical_limits.materialized_bytes = lexical_limits.materialized_bytes.min(bytes_limit);
    let match_limits = MatchLimits {
        combinations: reader_limits.combinations_per_level,
        matches: reader_limits.matched_programs,
        steps: reader_limits.program_steps.min(limits.plan_nodes),
        materialized_bytes: bytes_limit,
    };
    let mut result = ReaderResult::empty(identity, ReaderReason::NoTemplate);
    let mut shared = LanguageWorkspace::new(db)?;
    let compilation = ProgramWorkspace::new(limits, budget);
    let mut evidence = EvidenceWorkspace::default();

    let mut lexical_workspace = lexicon::LexicalWorkspace::new(db, raw_question);
    let mut total_bytes = 0usize;
    let mut selection = None::<ReaderShared<Selection>>;
    let mut same_selection = true;
    let mut checked_form_kinds = BTreeSet::new();
    let mut forms_ok = true;
    let mut execution_cache_hits = 0usize;
    let mut distinct = BTreeSet::new();
    // R7.read's whole path uses R6.candidates with R7's selected normalizer.
    // Its fragment found() function has different plural/function-word rules.
    for level in 0..=1 {
        let options = CandidateOptions {
            normalization,
            compositional: false,
            level2: level == 1,
            outer: false,
            plural: false,
            max_words: reader_limits.max_name_words,
        };
        let candidates = lexical_workspace.candidates(&options, &lexical_limits, budget)?;
        let spans: Vec<_> = candidates
            .spans
            .into_iter()
            .flat_map(|s| {
                s.readings.into_iter().map(move |r| GrammarSpan {
                    start: s.start,
                    end: s.end,
                    kind: r.kind.code(),
                    canonical: r.canonical,
                })
            })
            .collect();
        // Already normalized exactly once by the lexical entry point.
        let matched = grammar::match_whole(
            db,
            &candidates.normalized,
            &spans,
            level,
            &policy,
            match_limits,
            budget,
        )?;
        // Whole output already coexists with chart execution. Its reservation
        // must be installed before composition starts, not after both return.
        let matched_bytes = crate::query::encoded_size(&matched, usize::MAX)?
            .checked_mul(16)
            .and_then(|n| n.checked_add(matched.capacity().saturating_mul(64)))
            .ok_or(Error::Limit("retained memory accounting overflow"))?;
        let matched_memory = Arc::new(budget.reserve_memory(matched_bytes)?);
        let normalized = candidates.normalized;
        let mut composition_spans = Vec::new();
        for outer in [false, true] {
            let options = CandidateOptions {
                normalization,
                compositional: true,
                level2: level == 1,
                outer,
                plural: true,
                max_words: reader_limits.max_name_words,
            };
            let lexical = lexical_workspace.candidates(&options, &lexical_limits, budget)?;
            let spans: Vec<_> = lexical
                .spans
                .into_iter()
                .flat_map(|s| {
                    s.readings.into_iter().map(move |r| GrammarSpan {
                        start: s.start,
                        end: s.end,
                        kind: r.kind.code(),
                        canonical: r.canonical,
                    })
                })
                .collect();
            composition_spans.push(spans);
        }
        let mut unsupported_fragments = 0usize;
        let composed = crate::composition::match_composed_packed(
            db,
            &normalized,
            &composition_spans[0],
            &composition_spans[1],
            level,
            &policy,
            match_limits,
            budget,
            |fragment| {
                let Some(compiled) = compilation.compile(fragment, CompileOrigin::Fragment)? else {
                    // A demanded unsupported child vetoes certainty, including
                    // when a learned parent omits its X splice. Keep checking
                    // other alternatives; unsupported syntax is a semantic
                    // refusal, while resource/cancellation/source errors still
                    // propagate through `?` above and below.
                    unsupported_fragments += 1;
                    return Ok(false);
                };
                if compiled.terminal.contract().output != crate::ProgramType::Entities {
                    unsupported_fragments += 1;
                    return Ok(false);
                }
                // Viability needs one boolean, so no ids, facts or attributes
                // are fetched. The guard and stage caching are unchanged; with
                // the fragment's Entities projection an admitted plan has a
                // nonempty output, so this equals the former `is_some()`.
                Ok(matches!(
                    crate::query::evaluate_language_packed(
                        db,
                        identity,
                        compiled.as_ref(),
                        previous,
                        limits,
                        budget,
                        &mut shared,
                        crate::query::Demand::Exists,
                    )?,
                    Some(crate::query::Delivered::Exists(true))
                ))
            },
        )?;
        // These programs were demanded by complete outer consumers, even if
        // their unsupported children prevented any flattened outer from running.
        result.unsupported_programs += unsupported_fragments;
        // Keep the transferred composition guard alive across iteration and
        // every early return. No copied batch and no uncharged handoff interval.
        let (composed, _composed_memory) = composed.into_parts();
        let whole = matched.into_iter().map(|candidate| PackedCandidate {
            template: CandidateTemplate::Whole(candidate.template),
            level: candidate.level,
            support: candidate.support,
            program: packed_program::from_flat_retained(
                candidate.program,
                Arc::clone(&matched_memory),
            ),
        });
        let composed = composed.into_iter().map(|candidate| PackedCandidate {
            template: CandidateTemplate::Composed(candidate.template),
            level: candidate.level,
            support: candidate.support,
            program: candidate.program,
        });
        for candidate in whole.chain(composed) {
            budget.spend(1)?;
            result.matched_programs += 1;
            if result.matched_programs > reader_limits.matched_programs {
                return Err(Error::Limit("reader matched programs"));
            }
            let origin = match &candidate.template {
                CandidateTemplate::Whole(_) => CompileOrigin::Whole,
                CandidateTemplate::Composed(_) => CompileOrigin::Composed,
            };
            let compiled =
                compilation.compile(PackedProgramRef::new(&candidate.program), origin)?;
            let Some(compiled) = compiled else {
                result.unsupported_programs += 1;
                continue;
            };
            // The language mode examines every entity-producing intermediate,
            // including dead branches; terminal Count alone permits empties.
            // The common evaluator owns DAG execution, typed values and budgets.
            let execution = if let Some(cached) = compiled.execution.get() {
                execution_cache_hits += 1;
                budget.spend(1)?;
                cached.clone()
            } else {
                let evaluation = evaluate_language_packed(
                    db,
                    identity,
                    compiled.as_ref(),
                    previous,
                    limits,
                    budget,
                    &mut shared,
                    crate::query::Demand::Full,
                );
                budget.check()?;
                let execution = evaluation?
                    .map(|delivered| delivered.into_full())
                    .transpose()?
                    .map(|(query, selected)| evidence.intern(query, selected, budget))
                    .transpose()?;
                // No errors/cancellation are cached. None is the complete
                // all-stage guard refusal for this exact syntax and request.
                let _ = compiled.execution.set(execution.clone());
                execution
            };
            let Some(SharedExecution { query, selected }) = execution else {
                continue;
            };
            match execution_answer(&query, compiled.terminal)? {
                Answer::Absent => continue,
                Answer::Ambiguous => {
                    result.ambiguous_executions += 1;
                    continue;
                }
                Answer::Text(answer) => {
                    distinct.insert(answer.clone());
                    if let Some(previous_selection) = &selection {
                        same_selection &= previous_selection.ids == selected.ids
                            && previous_selection.facts == selected.facts
                            && previous_selection.attributes == selected.attributes;
                    } else {
                        selection = Some(selected);
                    }
                    let syntax = compilation.syntax(&compiled)?;
                    if checked_form_kinds.insert(grammar::answer_kind(&syntax)) {
                        forms_ok &= grammar::forms_allow(
                            db,
                            &normalized,
                            std::slice::from_ref(&*syntax),
                            &policy,
                            budget,
                        )?;
                    }
                    let template_bound = candidate.template.size_bound();
                    let memory = budget.reserve_memory(
                        std::mem::size_of::<ReaderReading>()
                            .saturating_add(template_bound)
                            .saturating_add(answer.capacity())
                            .saturating_add(64),
                    )?;
                    let template = candidate.template.render()?;
                    let reading = ReaderReading {
                        template,
                        level: candidate.level,
                        support: candidate.support,
                        program: syntax,
                        answer,
                        result: query,
                        _memory: Some(memory),
                    };
                    let bytes = crate::query::encoded_size(&reading, bytes_limit)?;
                    budget.spend(bytes as u64)?;
                    total_bytes = total_bytes
                        .checked_add(bytes)
                        .ok_or(Error::Limit("reader result bytes"))?;
                    if total_bytes > bytes_limit {
                        return Err(Error::Limit("reader result bytes"));
                    }
                    result.readings.push(reading);
                }
            }
        }
    }
    result.distinct_answers = distinct.into_iter().collect();
    // Source form guard is a veto over ALL successfully executed readings. It
    // must not discard one alternative then elect another as the only answer.
    let (status, reason) = if !forms_ok {
        (ReaderStatus::Refused, Some(ReaderReason::AnswerForm))
    } else if result.unsupported_programs > 0 {
        (
            ReaderStatus::Refused,
            Some(ReaderReason::UnsupportedProgram),
        )
    } else if result.ambiguous_executions > 0 {
        (
            ReaderStatus::Ambiguous,
            Some(ReaderReason::AmbiguousExecution),
        )
    } else if result.distinct_answers.len() > 1 {
        (
            ReaderStatus::Ambiguous,
            Some(ReaderReason::AnswerDisagreement),
        )
    } else if result.distinct_answers.len() == 1 {
        result.answer = result.distinct_answers.first().cloned();
        (ReaderStatus::Answered, None)
    } else if result.matched_programs == 0 {
        (ReaderStatus::Unknown, Some(ReaderReason::NoTemplate))
    } else {
        (ReaderStatus::Unknown, Some(ReaderReason::NoViableReading))
    };
    result.status = status;
    result.reason = reason;
    let selected = if status == ReaderStatus::Answered && same_selection {
        selection
    } else {
        None
    };
    // Includes result metadata and distinct-answer duplication in the bound.
    let wire_bytes = crate::query::encoded_size(&result, limits.result_bytes.min(bytes_limit))?;
    probe::record(probe::Record {
        matched: result.matched_programs,
        compiled_plans: compilation.stats().checked_roots,
        fragment_checks: compilation.stats().fragment_checks,
        complete_checks: compilation.stats().complete_checks,
        whole_checks: compilation.stats().whole_checks,
        composed_checks: compilation.stats().composed_checks,
        fragment_materializations: compilation.stats().fragment_materializations,
        resident_roots: compilation.stats().resident_roots,
        unique_operations: compilation.stats().lowered_operations,
        syntax_specs: compilation.stats().syntax_specs,
        validation_failures: compilation.stats().validation_failures,
        root_cache_hits: compilation.stats().root_cache_hits,
        rejected_cache_hits: compilation.stats().rejected_cache_hits,
        diagnostic_materializations: compilation.stats().materializations,
        execution_cache_hits,
        projection_hydrations: evidence.hydrations,
        unique_outcomes: evidence.unique,
        wire_bytes,
        retained_live: budget.memory().snapshot().live,
        retained_peak: budget.memory().snapshot().peak,
    });
    Ok((result, selected))
}

enum CandidateTemplate {
    Whole(String),
    Composed(crate::composition::PackedTemplate),
}
impl CandidateTemplate {
    fn size_bound(&self) -> usize {
        match self {
            Self::Whole(template) => template.capacity(),
            Self::Composed(template) => template.size_bound(),
        }
    }
    fn render(self) -> Result<String> {
        match self {
            Self::Whole(template) => Ok(template),
            Self::Composed(template) => template.render(),
        }
    }
}
struct PackedCandidate {
    template: CandidateTemplate,
    level: u8,
    support: u64,
    program: packed_program::OwnedPackedProgram,
}

#[derive(Clone)]
pub(crate) struct SharedExecution {
    pub(crate) query: ReaderShared<QueryResult>,
    pub(crate) selected: ReaderShared<Selection>,
}
/// Hashes only choose a bucket. Complete reply AND selection equality establish
/// sharing, including qualifiers/attribute positions; equal answer text does not.
#[derive(Default)]
struct EvidenceWorkspace {
    outcomes: HashMap<u64, Vec<SharedExecution>>,
    hydrations: usize,
    unique: usize,
}
impl EvidenceWorkspace {
    fn intern(
        &mut self,
        query: QueryResult,
        selected: Selection,
        budget: &Budget,
    ) -> Result<SharedExecution> {
        self.hydrations += 1;
        struct HashWriter(std::collections::hash_map::DefaultHasher);
        impl Write for HashWriter {
            fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
                self.0.write(bytes);
                Ok(bytes.len())
            }
            fn flush(&mut self) -> std::io::Result<()> {
                Ok(())
            }
        }
        let mut writer = HashWriter(std::collections::hash_map::DefaultHasher::new());
        serde_json::to_writer(&mut writer, &query)?;
        // QueryResult currently contains the full Selection too; retaining this
        // explicit comparison protects the invariant if projection evolves.
        let key = writer.0.finish();
        let bucket = self.outcomes.entry(key).or_default();
        for outcome in bucket.iter() {
            budget.spend(1)?;
            if *outcome.query == query && *outcome.selected == selected {
                return Ok(outcome.clone());
            }
        }
        let query_bytes = crate::query::query_retained_bytes(&query);
        let selected_bytes = crate::query::selection_retained_bytes(&selected);
        let outcome = SharedExecution {
            // Bucket/container allowance is charged once with its unique node.
            query: ReaderShared::new(query, query_bytes.saturating_add(128), budget)?,
            selected: ReaderShared::new(selected, selected_bytes, budget)?,
        };
        bucket.push(outcome.clone());
        self.unique += 1;
        Ok(outcome)
    }
}

enum Answer {
    Text(String),
    Absent,
    Ambiguous,
}
fn execution_answer(result: &QueryResult, terminal: Operation) -> Result<Answer> {
    if terminal == Operation::Count {
        return result
            .value
            .as_u64()
            .map(|n| Answer::Text(n.to_string()))
            .ok_or_else(|| Error::Format("reader count result".into()));
    }
    match result.value.get("status").and_then(Value::as_str) {
        Some("absent") => Ok(Answer::Absent),
        Some("verified") => result
            .value
            .get("answer")
            .and_then(Value::as_bool)
            .map(|answer| Answer::Text(if answer { "yes" } else { "no" }.into()))
            .ok_or_else(|| Error::Format("reader verification result".into())),
        Some("unique") => {
            let answer = result
                .value
                .get("display")
                .and_then(Value::as_str)
                .or_else(|| {
                    result
                        .value
                        .get("candidate")
                        .and_then(|c| c.get("name"))
                        .and_then(Value::as_str)
                });
            answer
                .map(|a| Answer::Text(a.into()))
                .ok_or_else(|| Error::Format("reader unique result".into()))
        }
        Some("ambiguous" | "ambiguous_operands" | "incomplete" | "incomparable") => {
            Ok(Answer::Ambiguous)
        }
        // Entity-producing terminal programs are fragment shapes, not answers.
        None if terminal.contract().output == crate::ProgramType::Entities => Ok(Answer::Absent),
        _ => Err(Error::Format("reader execution result status".into())),
    }
}

impl Image {
    /// Pure whole-question language read. It shares one admitted worker and one
    /// budget through lexical lookup, grammar matching and native DAG execution.
    pub fn read_whole(
        self: &Arc<Self>,
        tenant: &str,
        question: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.read_whole_with_limits(tenant, question, &ReaderLimits::default(), cancellation)
    }
    pub fn read_whole_with_limits(
        self: &Arc<Self>,
        tenant: &str,
        question: &str,
        reader_limits: &ReaderLimits,
        cancellation: Cancellation,
    ) -> Result<String> {
        crate::runtime::identifier(tenant)?;
        if self.capabilities.reader.is_none() {
            return Err(Error::Format("image has no learned reader tables".into()));
        }
        let budget = Budget::new(&self.limits, cancellation)?;
        self.read_whole_with_limits_and_budget(tenant, question, reader_limits, &budget)
    }

    /// Reuse the caller's deadline, cancellation and aggregate work allowance.
    pub fn read_whole_with_budget(
        self: &Arc<Self>,
        tenant: &str,
        question: &str,
        budget: &Budget,
    ) -> Result<String> {
        self.read_whole_with_limits_and_budget(tenant, question, &ReaderLimits::default(), budget)
    }

    pub fn read_whole_with_limits_and_budget(
        self: &Arc<Self>,
        tenant: &str,
        question: &str,
        reader_limits: &ReaderLimits,
        budget: &Budget,
    ) -> Result<String> {
        crate::runtime::identifier(tenant)?;
        if self.capabilities.reader.is_none() {
            return Err(Error::Format("image has no learned reader tables".into()));
        }
        let budget = budget.restricted_to(&self.limits)?;
        budget.check()?;
        let worker = self.acquire(tenant, &budget)?;
        let outcome = evaluate_whole(
            &worker,
            &self.identity,
            question,
            &Selection::default(),
            &self.limits,
            reader_limits,
            &budget,
        );
        budget.check()?;
        let (result, _) = outcome?;
        encode(&result, self.limits.result_bytes)
    }
}

/// Optional measurement hooks. Records completed reads only; a refusal is a
/// completed read, while resource/cancellation errors produce no record. Bytes
/// describe explicit reservation units, never process RSS or foreign buffers.
#[doc(hidden)]
pub mod probe {
    use std::sync::{
        atomic::{AtomicBool, Ordering},
        Mutex,
    };
    #[derive(Clone, Debug)]
    pub struct Record {
        pub matched: usize,
        pub compiled_plans: usize,
        pub fragment_checks: usize,
        pub complete_checks: usize,
        pub whole_checks: usize,
        pub composed_checks: usize,
        pub fragment_materializations: usize,
        pub resident_roots: usize,
        pub unique_operations: usize,
        pub syntax_specs: usize,
        pub validation_failures: usize,
        pub root_cache_hits: usize,
        pub rejected_cache_hits: usize,
        pub diagnostic_materializations: usize,
        pub execution_cache_hits: usize,
        pub projection_hydrations: usize,
        pub unique_outcomes: usize,
        pub wire_bytes: usize,
        pub retained_live: usize,
        pub retained_peak: usize,
    }
    static ENABLED: AtomicBool = AtomicBool::new(false);
    static RECORDS: Mutex<Vec<Record>> = Mutex::new(Vec::new());
    pub fn enable() {
        ENABLED.store(true, Ordering::Relaxed);
    }
    pub(super) fn record(record: Record) {
        if ENABLED.load(Ordering::Relaxed) {
            let mut records = RECORDS.lock().expect("reader probe lock");
            if !ENABLED.load(Ordering::Relaxed) {
                return;
            }
            if records.len() == 1024 {
                records.remove(0);
            }
            records.push(record);
        }
    }
    /// Stop recording and release retained measurement records.
    pub fn disable() {
        ENABLED.store(false, Ordering::Relaxed);
        RECORDS.lock().expect("reader probe lock").clear();
    }
    pub fn take() -> Vec<Record> {
        std::mem::take(&mut *RECORDS.lock().expect("reader probe lock"))
    }
}

#[cfg(test)]
mod compilation_tests {
    use super::*;
    use serde_json::json;

    fn syntax(name: &str, qualifier: &str) -> grammar::Program {
        serde_json::from_value(json!([
            {"function":"Find","dependencies":[],"inputs":[name]},
            {"function":"Find","dependencies":[],"inputs":["Alice"]},
            {"function":"Relate","dependencies":[1],"inputs":["meets","forward"]},
            {"function":"QFilterYear","dependencies":[2],"inputs":["since",qualifier,"="]}
        ]))
        .unwrap()
    }

    #[test]
    fn compilation_shares_only_exact_complete_syntax_within_request() {
        let limits = Limits::default();
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        let workspace = ProgramWorkspace::new(&limits, &budget);
        let first = workspace
            .compile(
                PackedProgramRef::new(&packed_program::from_flat(syntax("Unused", "2000"))),
                CompileOrigin::Complete,
            )
            .unwrap()
            .unwrap();
        let repeated = workspace
            .compile(
                PackedProgramRef::new(&packed_program::from_flat(syntax("Unused", "2000"))),
                CompileOrigin::Complete,
            )
            .unwrap()
            .unwrap();
        assert!(Arc::ptr_eq(&first, &repeated));
        for alternative in [
            syntax("Other dead branch", "2000"),
            syntax("Unused", "2001"),
        ] {
            let other = workspace
                .compile(
                    PackedProgramRef::new(&packed_program::from_flat(alternative)),
                    CompileOrigin::Complete,
                )
                .unwrap()
                .unwrap();
            assert!(!Arc::ptr_eq(&first, &other));
        }
        let new_request = ProgramWorkspace::new(&limits, &budget)
            .compile(
                PackedProgramRef::new(&packed_program::from_flat(syntax("Unused", "2000"))),
                CompileOrigin::Complete,
            )
            .unwrap()
            .unwrap();
        assert!(!Arc::ptr_eq(&first, &new_request));
    }

    #[test]
    fn unsupported_dead_branch_still_vetoes_compilation() {
        let mut syntax = syntax("Unused", "2000");
        syntax[0].function = "NotAnOperation".into();
        let limits = Limits::default();
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        assert!(ProgramWorkspace::new(&limits, &budget)
            .compile(
                PackedProgramRef::new(&packed_program::from_flat(syntax)),
                CompileOrigin::Complete
            )
            .unwrap()
            .is_none());
    }
    fn outcome(qualifier: &str) -> (QueryResult, Selection) {
        let attribute = crate::AttributeFact {
            subject: "same-id".into(),
            key: "name".into(),
            position: 1,
            value_json: "\"Same answer\"".into(),
            qualifiers_json: qualifier.into(),
        };
        let selected = Selection {
            ids: BTreeSet::from(["same-id".into()]),
            facts: BTreeSet::new(),
            attributes: BTreeSet::from([attribute.clone()]),
        };
        (
            QueryResult {
                image: "image-one".into(),
                coverage: "complete_relative_to_image".into(),
                entities: vec!["same-id".into()],
                facts: vec![],
                attributes: vec![attribute],
                value: json!({"status":"unique","display":"Same answer"}),
            },
            selected,
        )
    }

    #[test]
    fn shared_evidence_retains_full_source_identity_and_releases_last_owner() {
        let limits = Limits::default();
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        let mut workspace = EvidenceWorkspace::default();
        let (query, selected) = outcome("{\"year\":2000}");
        let first = workspace.intern(query, selected, &budget).unwrap();
        let live = budget.memory().snapshot().live;
        let (query, selected) = outcome("{\"year\":2000}");
        let same = workspace.intern(query, selected, &budget).unwrap();
        assert!(first.query.ptr_eq(&same.query));
        assert!(first.selected.ptr_eq(&same.selected));
        assert_eq!(budget.memory().snapshot().live, live);
        let (query, selected) = outcome("{\"year\":2001}");
        let different = workspace.intern(query, selected, &budget).unwrap();
        assert!(!first.query.ptr_eq(&different.query));
        assert_eq!(first.query.value, different.query.value);
        assert_ne!(first.query.attributes, different.query.attributes);
        assert_eq!(workspace.unique, 2);
        let wire = serde_json::to_value(&first.query).unwrap();
        assert_eq!(wire["attributes"][0]["qualifiers_json"], "{\"year\":2000}");
        assert!(wire.get("_memory").is_none());
        let decoded: ReaderShared<QueryResult> = serde_json::from_value(wire).unwrap();
        assert_eq!(*first.query, *decoded);
        drop(workspace);
        drop(different);
        drop(same);
        assert_eq!(budget.memory().snapshot().live, live);
        let last = first.query.clone();
        drop(first);
        assert!(budget.memory().snapshot().live > 0);
        drop(last);
        assert_eq!(budget.memory().snapshot().live, 0);
    }

    #[test]
    fn shared_evidence_never_merges_different_referents_or_selection_only_evidence() {
        let limits = Limits::default();
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        let mut workspace = EvidenceWorkspace::default();
        let (query, selected) = outcome("{}");
        let first = workspace.intern(query, selected, &budget).unwrap();
        let (query, mut selected) = outcome("{}");
        selected.ids.insert("other-id".into());
        // Even an otherwise identical diagnostic reply cannot mask a distinct
        // Previous selection if future projection rules attach extra evidence.
        let different = workspace.intern(query, selected, &budget).unwrap();
        assert!(!first.query.ptr_eq(&different.query));
        let (mut query, mut selected) = outcome("{}");
        query.entities = vec!["other-id".into()];
        selected.ids = BTreeSet::from(["other-id".into()]);
        let referent = workspace.intern(query, selected, &budget).unwrap();
        assert!(!first.query.ptr_eq(&referent.query));
        assert_eq!(first.query.value, referent.query.value);
    }

    #[test]
    fn aggregate_exhaustion_refuses_without_leaking_partial_shared_nodes() {
        let limits = Limits {
            request_memory_bytes: 1,
            ..Limits::default()
        };
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        let mut workspace = EvidenceWorkspace::default();
        let (query, selected) = outcome("{}");
        assert!(matches!(
            workspace.intern(query, selected, &budget),
            Err(Error::Limit("retained request memory"))
        ));
        assert_eq!(budget.memory().snapshot().live, 0);
        assert_eq!(workspace.unique, 0);
    }
    #[test]
    fn thousands_of_equal_outcomes_share_but_distinct_evidence_exhausts_boundedly() {
        let limits = Limits::default();
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        let mut workspace = EvidenceWorkspace::default();
        let (query, selected) = outcome("{}");
        let first = workspace.intern(query, selected, &budget).unwrap();
        let live = budget.memory().snapshot().live;
        for _ in 0..2401 {
            let (query, selected) = outcome("{}");
            let next = workspace.intern(query, selected, &budget).unwrap();
            assert!(first.query.ptr_eq(&next.query));
            assert_eq!(budget.memory().snapshot().live, live);
        }
        assert_eq!(workspace.unique, 1);
        drop(workspace);
        drop(first);
        assert_eq!(budget.memory().snapshot().live, 0);

        let limits = Limits {
            request_memory_bytes: 4096,
            ..Limits::default()
        };
        let budget = Budget::new(&limits, Cancellation::default()).unwrap();
        let mut workspace = EvidenceWorkspace::default();
        let mut refused = false;
        for year in 0..2401 {
            let (query, selected) = outcome(&format!("{{\"year\":{year}}}"));
            match workspace.intern(query, selected, &budget) {
                Ok(_) => {}
                Err(Error::Limit("retained request memory")) => {
                    refused = true;
                    break;
                }
                Err(error) => panic!("unexpected error: {error:?}"),
            }
        }
        assert!(
            refused,
            "different evidence must remain distinct and bounded"
        );
        assert!(budget.memory().snapshot().live <= 4096);
        drop(workspace);
        assert_eq!(budget.memory().snapshot().live, 0);
    }
    #[test]
    fn returned_selection_transfers_reservation_or_reserves_before_copying() {
        let budget = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
        let (_, selected) = outcome("{}");
        let bytes = crate::query::selection_retained_bytes(&selected);
        let shared = ReaderShared::new(selected, bytes, &budget).unwrap();
        let original = budget.memory().snapshot().live;
        let alias = shared.clone();
        let (copy, copy_memory) = alias.into_owned(bytes, &budget).unwrap();
        assert!(budget.memory().snapshot().live > original);
        assert_eq!(copy.ids, shared.ids);
        drop(copy);
        drop(copy_memory);
        assert_eq!(budget.memory().snapshot().live, original);
        let (owned, memory) = shared.into_owned(bytes, &budget).unwrap();
        assert_eq!(budget.memory().snapshot().live, original);
        assert!(owned.ids.contains("same-id"));
        drop(owned);
        assert_eq!(budget.memory().snapshot().live, original);
        drop(memory);
        assert_eq!(budget.memory().snapshot().live, 0);
    }
}
