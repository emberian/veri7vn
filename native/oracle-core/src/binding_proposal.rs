//! Untrusted learned-binding proposals resolved against one admitted image.
//! Original source coordinates are Unicode codepoints. Lexicon coordinates are
//! bytes in separately normalized labels and never replace source coordinates.
//! Programs query the image conditionally; they do not establish source entailment.
use crate::lexicon::{self, CandidateOptions, LexicalKind, LexicalReading, LexiconLimits};
use crate::{Budget, Error, Image, Operation, Program, ProgramStep, Result};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SourceSpan {
    pub start: usize,
    pub end: usize,
    pub text: String,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Binding {
    pub entity: SourceSpan,
    pub role: SourceSpan,
    pub value: SourceSpan,
    pub score: f64,
    pub status: String,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ProposalInput {
    pub schema: String,
    pub source_id: String,
    pub source_sha256: String,
    pub offset_unit: String,
    pub bindings: Vec<Binding>,
    pub coverage: String,
    pub graph_resolution: String,
    pub empirical_status: String,
}
#[derive(Debug, Serialize)]
pub struct ResolvedProposal {
    pub binding: Binding,
    pub entity_reading: LexicalReading,
    pub role_reading: LexicalReading,
    pub program: Program,
}
#[derive(Debug, Serialize)]
pub struct UnresolvedBinding {
    pub binding: Binding,
    pub reason: &'static str,
}
#[derive(Serialize)]
pub struct ProposalReport {
    image: String,
    source_id: String,
    source_sha256: String,
    candidate_coverage: &'static str,
    interpretation: &'static str,
    proposals: Vec<ResolvedProposal>,
    unresolved: Vec<UnresolvedBinding>,
    #[serde(skip)]
    _memory: crate::budget::MemoryReservation,
}
impl ProposalReport {
    pub fn image(&self) -> &str {
        &self.image
    }
    pub fn source_id(&self) -> &str {
        &self.source_id
    }
    pub fn candidate_coverage(&self) -> &str {
        self.candidate_coverage
    }
    /// Immutable borrow keeps the report's reservation alive. No mutable or
    /// consuming payload accessor can detach these allocations from the guard.
    /// ```compile_fail
    /// use oracle_runtime_core::binding_proposal::ProposalReport;
    /// fn detach(report: &mut ProposalReport) {
    ///     let _payload = std::mem::take(report.proposals());
    /// }
    /// ```
    pub fn proposals(&self) -> &[ResolvedProposal] {
        &self.proposals
    }
    pub fn unresolved(&self) -> &[UnresolvedBinding] {
        &self.unresolved
    }
}

fn binding_heap(binding: &Binding) -> usize {
    binding
        .entity
        .text
        .capacity()
        .saturating_add(binding.role.text.capacity())
        .saturating_add(binding.value.text.capacity())
        .saturating_add(binding.status.capacity())
}
fn input_bytes(input: &ProposalInput) -> usize {
    let strings = [
        &input.schema,
        &input.source_id,
        &input.source_sha256,
        &input.offset_unit,
        &input.coverage,
        &input.graph_resolution,
        &input.empirical_status,
    ];
    strings
        .iter()
        .fold(std::mem::size_of::<ProposalInput>(), |n, s| {
            n.saturating_add(s.capacity())
        })
        .saturating_add(
            input
                .bindings
                .capacity()
                .saturating_mul(std::mem::size_of::<Binding>()),
        )
        .saturating_add(
            input
                .bindings
                .iter()
                .fold(0usize, |n, b| n.saturating_add(binding_heap(b))),
        )
}
fn proposal_bytes(proposal: &ResolvedProposal) -> usize {
    let program = proposal.program.0.iter().fold(
        proposal
            .program
            .0
            .capacity()
            .saturating_mul(std::mem::size_of::<ProgramStep>()),
        |n, s| {
            n.saturating_add(
                s.dependencies
                    .capacity()
                    .saturating_mul(std::mem::size_of::<usize>()),
            )
            .saturating_add(
                s.inputs
                    .capacity()
                    .saturating_mul(std::mem::size_of::<String>()),
            )
            .saturating_add(
                s.inputs
                    .iter()
                    .fold(0usize, |n, s| n.saturating_add(s.capacity())),
            )
        },
    );
    std::mem::size_of::<ResolvedProposal>()
        .saturating_add(binding_heap(&proposal.binding))
        .saturating_add(proposal.entity_reading.canonical.capacity())
        .saturating_add(proposal.role_reading.canonical.capacity())
        .saturating_add(program)
}
fn check_span(source: &str, offsets: &[usize], span: &SourceSpan, budget: &Budget) -> Result<()> {
    budget.spend(span.text.len() as u64 + 1)?;
    if span.end <= span.start {
        return Err(Error::Invalid("binding source span".into()));
    }
    let start = offsets
        .get(span.start)
        .ok_or_else(|| Error::Invalid("binding source span index".into()))?;
    let end = offsets
        .get(span.end)
        .ok_or_else(|| Error::Invalid("binding source span index".into()))?;
    if source.get(*start..*end) != Some(span.text.as_str()) {
        return Err(Error::Invalid("binding source span text".into()));
    }
    Ok(())
}

fn full_readings(
    db: &rusqlite::Connection,
    text: &str,
    budget: &Budget,
) -> Result<Vec<LexicalReading>> {
    let limits = LexiconLimits {
        question_bytes: 4096,
        question_tokens: 64,
        max_name_words: 32,
        spans: 256,
        readings: 512,
        materialized_bytes: 65536,
    };
    let found = lexicon::candidates(
        db,
        text,
        &CandidateOptions {
            max_words: 32,
            // Predicate labels are level-2 lexical kinds. The ordinary
            // entity-only reader mode deliberately suppresses A/R readings.
            level2: true,
            plural: false,
            ..CandidateOptions::default()
        },
        &limits,
        budget,
    )?;
    Ok(found
        .spans
        .into_iter()
        .filter(|s| s.start == 0 && s.end == found.normalized.len())
        .flat_map(|s| s.readings)
        .collect())
}

/// Resolve alternatives without selecting by confidence. Host supplies tenant,
/// immutable image, source text and shared request budget. No mutation or session
/// selection occurs. Caller may prepare each program with batch::prepare_program.
/// Any output cap overflow fails the request; it never silently drops alternatives.
pub fn resolve(
    image: &Image,
    tenant: &str,
    source: &str,
    input: ProposalInput,
    inherited: &Budget,
) -> Result<ProposalReport> {
    crate::runtime::identifier(tenant)?;
    let budget = inherited.restricted_to(&image.limits)?;
    budget.check()?;
    if source.len() > 65536 || input.bindings.len() > 128 {
        return Err(Error::Limit("binding proposal input"));
    }
    if input.source_id.len() > 4096 {
        return Err(Error::Limit("binding source identity"));
    }
    // Typed callers may supply huge spare capacity behind a tiny JSON value.
    // Charge actual incoming ownership for the entire call, before processing.
    let input_size = input_bytes(&input);
    let _input_memory = budget.reserve_memory(input_size)?;
    budget.spend(
        (input_size as u64)
            .saturating_add(source.len() as u64)
            .saturating_add(1),
    )?;
    crate::query::encoded_size(&input, image.limits.request_bytes)?;
    let _index_memory = budget.reserve_memory((source.len() + 1) * std::mem::size_of::<usize>())?;
    let mut offsets = Vec::with_capacity(source.len() + 1);
    for (byte, _) in source.char_indices() {
        budget.spend(1)?;
        offsets.push(byte);
    }
    offsets.push(source.len());
    if input.schema != "oracle.binding-candidates.v1"
        || input.offset_unit != "unicode_codepoint"
        || input.coverage != "unknown"
        || input.graph_resolution != "required"
        || input.empirical_status != "experimental"
        || input.source_sha256 != crate::digest(source.as_bytes())
    {
        return Err(Error::Invalid("binding proposal provenance".into()));
    }
    for binding in &input.bindings {
        if !binding.score.is_finite()
            || !(0.0..=1.0).contains(&binding.score)
            || binding.status != "untrusted_proposal"
        {
            return Err(Error::Invalid("binding confidence or status".into()));
        }
        for span in [&binding.entity, &binding.role, &binding.value] {
            check_span(source, &offsets, span, &budget)?;
        }
    }
    // Reserve bounded output retention before cloning any input rows. Lexicon
    // scratch has its own 64 KiB bound. This excludes allocator/SQLite overhead.
    let memory = budget.reserve_memory(2 * 1024 * 1024)?;
    if image.capabilities.lexicon.is_none() {
        return Err(Error::Invalid(
            "binding resolver requires image lexicon".into(),
        ));
    }
    let worker = image.acquire(tenant, &budget)?;
    let mut retained_bytes = 0usize;
    let mut proposals = Vec::with_capacity(64);
    let mut unresolved = Vec::with_capacity(128);
    for binding in input.bindings {
        budget.spend(1)?;
        let entities = full_readings(&worker, &binding.entity.text, &budget)?;
        let roles = full_readings(&worker, &binding.role.text, &budget)?;
        let mut produced = false;
        for entity in entities.iter().filter(|r| r.kind == LexicalKind::E) {
            for role in roles
                .iter()
                .filter(|r| matches!(r.kind, LexicalKind::A | LexicalKind::R))
            {
                if proposals.len() >= 64 {
                    return Err(Error::Limit("binding proposal alternatives"));
                }
                let mut steps = vec![ProgramStep {
                    function: Operation::Find,
                    dependencies: vec![],
                    inputs: vec![entity.canonical.clone()],
                }];
                if role.kind == LexicalKind::A {
                    steps.push(ProgramStep {
                        function: Operation::QueryAttr,
                        dependencies: vec![0],
                        inputs: vec![role.canonical.clone()],
                    });
                } else {
                    steps.push(ProgramStep {
                        function: Operation::Relate,
                        dependencies: vec![0],
                        inputs: vec![role.canonical.clone(), "forward".into()],
                    });
                    steps.push(ProgramStep {
                        function: Operation::What,
                        dependencies: vec![1],
                        inputs: vec![],
                    });
                }
                let program = Program(steps);
                program.validate(&image.limits)?;
                let proposal = ResolvedProposal {
                    binding: binding.clone(),
                    entity_reading: entity.clone(),
                    role_reading: role.clone(),
                    program,
                };
                retained_bytes = retained_bytes
                    .checked_add(
                        crate::query::encoded_size(&proposal, 524288)?
                            .max(proposal_bytes(&proposal)),
                    )
                    .ok_or(Error::Limit("binding proposal bytes"))?;
                if retained_bytes > 524288 {
                    return Err(Error::Limit("binding proposal bytes"));
                }
                proposals.push(proposal);
                produced = true;
            }
        }
        if !produced {
            let row = UnresolvedBinding {
                binding: binding.clone(),
                reason: "no_full_entity_and_role_reading",
            };
            retained_bytes = retained_bytes
                .checked_add(
                    crate::query::encoded_size(&row, 524288)?.max(
                        std::mem::size_of::<UnresolvedBinding>()
                            .saturating_add(binding_heap(&row.binding)),
                    ),
                )
                .ok_or(Error::Limit("binding proposal bytes"))?;
            if retained_bytes > 524288 {
                return Err(Error::Limit("binding proposal bytes"));
            }
            unresolved.push(row);
        }
    }
    let report = ProposalReport {
        image: image.verified_identity().into(),
        source_id: input.source_id.clone(),
        source_sha256: input.source_sha256.clone(),
        candidate_coverage: "unknown",
        interpretation: "conditional_image_queries_not_source_entailment",
        proposals,
        unresolved,
        _memory: memory,
    };
    let encoded = crate::query::encoded_size(&report, image.limits.result_bytes)?;
    budget.spend(encoded as u64 + 1)?;
    Ok(report)
}
