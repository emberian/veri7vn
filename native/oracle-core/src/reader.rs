//! Bounded whole-template language reader over one leased native image worker.
//!
//! This is an untrusted recognizer, not a proof of natural-language meaning.
//! Coverage is explicitly whole templates: fragment composition, segments,
//! analogy and clause patches are not silently treated as implemented. Direct
//! graph/program execution does not inherit this reader's admission rules.
use crate::grammar::{self, GrammarSpan, MatchLimits, MatchedProgram};
use crate::lexicon::{self, CandidateOptions, LexiconLimits};
use crate::program::{Operation, Program};
use crate::query::{encode, evaluate_language, Selection};
use crate::{Budget, Cancellation, Error, Image, Limits, QueryResult, Result};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;
use std::sync::Arc;

pub const COVERAGE: &str = "whole_templates_only";

/// Host bounds, not learned language settings. Exhaustion fails the request.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct ReaderLimits {
    pub lexicon: LexiconLimits,
    pub max_name_words: usize,
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
#[derive(Debug, Deserialize, Serialize)]
pub struct ReaderReading {
    pub template: String,
    pub level: u8,
    pub support: u64,
    pub program: grammar::Program,
    pub answer: String,
    pub result: QueryResult,
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
) -> Result<(ReaderResult, Option<Selection>)> {
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
) -> Result<(ReaderResult, Option<Selection>)> {
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
    let mut total_bytes = 0usize;
    let mut selection = None::<Selection>;
    let mut same_selection = true;
    let mut checked_form_kinds = BTreeSet::new();
    let mut forms_ok = true;
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
        let candidates = lexicon::candidates(db, raw_question, &options, &lexical_limits, budget)?;
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
        let normalized = candidates.normalized;
        for candidate in matched {
            budget.spend(1)?;
            result.matched_programs += 1;
            if result.matched_programs > reader_limits.matched_programs {
                return Err(Error::Limit("reader matched programs"));
            }
            let compiled = compile_candidate(&candidate, limits)?;
            let Some((program, plan)) = compiled else {
                result.unsupported_programs += 1;
                continue;
            };
            // The language mode examines every entity-producing intermediate,
            // including dead branches; terminal Count alone permits empties.
            // The common evaluator owns DAG execution, typed values and budgets.
            let evaluation = evaluate_language(db, identity, &plan, previous, limits, budget);
            budget.check()?;
            let Some((query, selected)) = evaluation? else {
                continue;
            };
            match execution_answer(
                &query,
                program.0.last().expect("validated program").function,
            )? {
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
                    if checked_form_kinds.insert(grammar::answer_kind(&candidate.program)) {
                        forms_ok &= grammar::forms_allow(
                            db,
                            &normalized,
                            std::slice::from_ref(&candidate.program),
                            &policy,
                            budget,
                        )?;
                    }
                    let reading = ReaderReading {
                        template: candidate.template,
                        level: candidate.level,
                        support: candidate.support,
                        program: candidate.program,
                        answer,
                        result: query,
                    };
                    let bytes = encode(&reading, bytes_limit)?.len();
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
    encode(&result, limits.result_bytes.min(bytes_limit))?;
    Ok((result, selected))
}

fn compile_candidate(
    candidate: &MatchedProgram,
    limits: &Limits,
) -> Result<Option<(Program, crate::Plan)>> {
    if candidate.program.len() > limits.plan_nodes {
        return Err(Error::Limit("reader program steps"));
    }
    let encoded = encode(&candidate.program, limits.request_bytes)?;
    let result = Program::parse(&encoded, limits).and_then(|program| {
        let plan = program.compile(limits)?;
        Ok((program, plan))
    });
    match result {
        Ok(compiled) => Ok(Some(compiled)),
        // A native-uncovered/malformed learned candidate cannot erase ambiguity
        // by disappearing. The caller vetoes the complete reader answer.
        Err(Error::Invalid(_) | Error::Json(_)) => Ok(None),
        Err(error) => Err(error),
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
