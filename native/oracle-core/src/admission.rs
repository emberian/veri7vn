//! Candidate agreement and narrowing guards for an explicitly admitted route group.
//!
//! Handwritten Rust, with no theorem claim. This implements the common agreement
//! operation in w574, not the historical class chain or the specialist ranking
//! rule in `Arbitration.thy`. A producer must first establish that its operation
//! took the turn. An accepted refusal is never represented as `NoReading`.

use crate::value::{ExactNumber, ValueLimits};
use crate::{Budget, Error, Result};
use std::collections::BTreeSet;

#[derive(Clone, Debug)]
pub struct AdmissionLimits {
    pub routes: usize,
    pub input_bytes: usize,
    pub evidence_claims: usize,
    pub guards: usize,
}

impl Default for AdmissionLimits {
    fn default() -> Self {
        Self {
            routes: 256,
            input_bytes: 1024 * 1024,
            evidence_claims: 4096,
            guards: 64,
        }
    }
}

impl AdmissionLimits {
    fn validate(&self) -> Result<()> {
        if self.routes == 0 || self.input_bytes == 0 || self.evidence_claims == 0 {
            return Err(Error::Invalid("invalid admission limits".into()));
        }
        Ok(())
    }
}

/// Optional organs may be absent during background loading (w572). A missing
/// required organ makes the group's answer unavailable, never semantically false.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Participation {
    Optional,
    Required,
}

#[derive(Clone, Debug)]
pub struct RouteSpec {
    pub id: String,
    pub participation: Participation,
}

#[derive(Clone, Debug)]
pub enum AgreementMode {
    Exact,
    /// Pairwise Fusion agreement, using exact rational arithmetic:
    /// |a-b| <= tolerance * max(|a|, |b|, floor).
    /// Tolerance must be in [0,1); floor must be nonnegative. Text and boolean
    /// keys still require equality. This does not emulate the shipped anchor rule.
    Relative(Box<RelativeAgreement>),
}

/// Allocated once when constructing a reusable route policy, not for each
/// report or value. Exact policies do not carry two unused rational payloads.
#[derive(Clone, Debug)]
pub struct RelativeAgreement {
    pub tolerance: ExactNumber,
    pub floor: ExactNumber,
    pub value_limits: ValueLimits,
}

#[derive(Clone, Debug)]
pub struct AdmissionPolicy {
    /// Stable producer order, not strength or confidence. Every listed route
    /// must report once, in this order, including absent and unread routes.
    pub routes: Vec<RouteSpec>,
    pub agreement: AgreementMode,
    pub limits: AdmissionLimits,
}

/// Evidence is a producer's claim. No class, count, or citation upgrades a
/// candidate, establishes coverage, or certifies a theorem or a parsed request.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum EvidenceClass {
    Direct,
    Derived,
    Measured,
    Assumed,
    Unknown,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct EvidenceClaim {
    pub class: EvidenceClass,
    pub reference: String,
    pub detail: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AgreementKey {
    /// w574's key-or-answer, trimmed and lowercased by this consumer. These are
    /// comparison labels, not entity resolution or evidence of factual truth.
    Text(String),
    Boolean(bool),
    /// The caller supplies a canonical unit identity. No unit is guessed from
    /// response prose, and unequal unit identities never agree here.
    Number {
        value: ExactNumber,
        unit: String,
    },
}

/// Fusion's six-dimensional basis: metre, kilogram, second, ampere, kelvin,
/// dollar. A missing dimension is unknown, not a dimensionless scalar.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Dimension(pub [i32; 6]);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AnswerCandidate {
    pub key: AgreementKey,
    pub response: String,
    pub path: String,
    pub dimension: Option<Dimension>,
    pub evidence: Vec<EvidenceClaim>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RefusalKind {
    InvalidPremise,
    OutsideDomain,
    AmbiguousReading,
    Deliberate,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SemanticRefusal {
    pub kind: RefusalKind,
    pub response: String,
    pub path: String,
}

/// These are operational observations, never semantic refusals. An external
/// adapter must stop or cooperatively cancel its work before reporting a bound;
/// this module does not abandon workers like w480's daemon-thread timeout.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Unavailability {
    NotLoaded,
    Failed(String),
    BudgetExceeded,
    Cancelled,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RouteOutcome {
    NoReading,
    Answer(AnswerCandidate),
    Refusal(SemanticRefusal),
    Unavailable(Unavailability),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RouteReport {
    pub route: String,
    pub outcome: RouteOutcome,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AdmissionOutcome {
    Answered {
        selected: usize,
        agreeing: Vec<usize>,
    },
    /// All accepted refusals remain available in `reports`, including ambiguity.
    Refused {
        routes: Vec<usize>,
    },
    Disagreement {
        routes: Vec<usize>,
    },
    /// Required failures block answers. Optional failures remain observations;
    /// if nothing answers, they produce this outcome as well.
    Unavailable {
        routes: Vec<usize>,
    },
    NoReading,
    GuardVeto {
        guard: String,
        reason: String,
    },
    GuardUnavailable {
        guard: String,
        reason: String,
    },
}

/// Only `NoReading` permits another route group to try answering. Consumers
/// must not turn disagreement, a guard veto, or an operational failure into an
/// unread question. Reports retain rejected/conflicting answers for inspection.
#[derive(Clone, Debug)]
pub struct AdmissionDecision {
    outcome: AdmissionOutcome,
    reports: Vec<RouteReport>,
    guard_records: Vec<GuardRecord>,
    duplicate_evidence_claims: usize,
    limits: AdmissionLimits,
    admitted_bytes: usize,
}

impl AdmissionDecision {
    pub fn outcome(&self) -> &AdmissionOutcome {
        &self.outcome
    }

    pub fn reports(&self) -> &[RouteReport] {
        &self.reports
    }

    pub fn guard_records(&self) -> &[GuardRecord] {
        &self.guard_records
    }

    pub fn duplicate_evidence_claims(&self) -> usize {
        self.duplicate_evidence_claims
    }

    pub fn allows_fallback(&self) -> bool {
        matches!(self.outcome, AdmissionOutcome::NoReading)
    }

    pub fn answer(&self) -> Option<&AnswerCandidate> {
        let AdmissionOutcome::Answered { selected, .. } = self.outcome else {
            return None;
        };
        match &self.reports[selected].outcome {
            RouteOutcome::Answer(answer) => Some(answer),
            _ => None,
        }
    }
}

struct Meter<'a> {
    limits: &'a AdmissionLimits,
    budget: &'a Budget,
    bytes: usize,
    claims: usize,
}

impl Meter<'_> {
    fn bytes(&mut self, amount: usize) -> Result<()> {
        self.bytes = self
            .bytes
            .checked_add(amount)
            .ok_or(Error::Limit("admission input bytes"))?;
        if self.bytes > self.limits.input_bytes {
            return Err(Error::Limit("admission input bytes"));
        }
        self.budget.spend(1 + (amount / 64) as u64)
    }

    fn text(&mut self, text: &str) -> Result<()> {
        self.bytes(text.len())
    }

    fn number(&mut self, number: &ExactNumber) -> Result<()> {
        // ExactNumber has private, bounded rational representation. Account for
        // its integer payload without allocating a decimal rendering.
        let bits = number
            .numerator()
            .bits()
            .checked_add(number.denominator().bits())
            .ok_or(Error::Limit("admission input bytes"))?;
        let bytes =
            usize::try_from(bits / 8 + 2).map_err(|_| Error::Limit("admission input bytes"))?;
        self.bytes(bytes)?;
        self.text(number.source_literal())
    }

    fn answer(&mut self, answer: &mut AnswerCandidate) -> Result<usize> {
        self.text(&answer.response)?;
        self.text(&answer.path)?;
        match &mut answer.key {
            AgreementKey::Text(text) => {
                self.text(text)?;
                *text = text.trim().to_lowercase();
                // Case conversion can expand a Unicode label.
                self.text(text)?;
                if text.is_empty() {
                    return Err(Error::Invalid("empty candidate agreement key".into()));
                }
            }
            AgreementKey::Number { value, unit } => {
                self.number(value)?;
                self.text(unit)?;
                if unit.is_empty() {
                    return Err(Error::Invalid("missing numeric unit identity".into()));
                }
            }
            AgreementKey::Boolean(_) => self.bytes(1)?,
        }
        self.claims = self
            .claims
            .checked_add(answer.evidence.len())
            .ok_or(Error::Limit("admission evidence claims"))?;
        if self.claims > self.limits.evidence_claims {
            return Err(Error::Limit("admission evidence claims"));
        }
        let mut seen = BTreeSet::new();
        let mut unique = Vec::new();
        let before = answer.evidence.len();
        for claim in std::mem::take(&mut answer.evidence) {
            self.text(&claim.reference)?;
            self.text(&claim.detail)?;
            if seen.insert(claim.clone()) {
                unique.push(claim);
            }
        }
        answer.evidence = unique;
        Ok(before - answer.evidence.len())
    }
}

/// Consume exactly one bounded group in its admitted order. This is a single
/// pass over reports; equality is never a vote and duplicate evidence is not
/// extra support. All answers must agree, even if a different one claims more
/// evidence. The first agreeing answer supplies the unchanged display reply.
/// A malformed, overlong, incomplete, or cancelled input returns an error and
/// never an answer from a partial prefix.
pub fn arbitrate(
    policy: &AdmissionPolicy,
    reports: impl IntoIterator<Item = RouteReport>,
    budget: &Budget,
) -> Result<AdmissionDecision> {
    policy.limits.validate()?;
    if policy.routes.len() > policy.limits.routes {
        return Err(Error::Limit("admission routes"));
    }
    let mut meter = Meter {
        limits: &policy.limits,
        budget,
        bytes: 0,
        claims: 0,
    };
    let mut route_ids = BTreeSet::new();
    for route in &policy.routes {
        meter.text(&route.id)?;
        if route.id.is_empty() || !route_ids.insert(route.id.as_str()) {
            return Err(Error::Invalid("empty or duplicate admitted route".into()));
        }
    }
    if let AgreementMode::Relative(relative) = &policy.agreement {
        meter.number(&relative.tolerance)?;
        meter.number(&relative.floor)?;
        // Validate even when no numeric answer arrives.
        relative.tolerance.within_relative(
            &relative.tolerance,
            &relative.tolerance,
            &relative.floor,
            &relative.value_limits,
        )?;
    }
    let mut input = reports.into_iter();
    let mut accepted: Vec<RouteReport> = Vec::with_capacity(policy.routes.len());
    let mut answers: Vec<usize> = Vec::new();
    let mut refusals = Vec::new();
    let mut unavailable = Vec::new();
    let mut required_failure = false;
    let mut duplicates = 0;
    let mut unequal = false;
    let mut numeric_extrema: Option<(usize, usize)> = None;
    for (index, route) in policy.routes.iter().enumerate() {
        budget.spend(1)?;
        let mut report = input
            .next()
            .ok_or_else(|| Error::Invalid("missing admitted route report".into()))?;
        meter.text(&report.route)?;
        if report.route != route.id {
            return Err(Error::Invalid(
                "route reports do not follow admitted order".into(),
            ));
        }
        match &mut report.outcome {
            RouteOutcome::Answer(answer) => {
                duplicates += meter.answer(answer)?;
                if let (AgreementKey::Number { value, .. }, AgreementMode::Relative(relative)) =
                    (&answer.key, &policy.agreement)
                {
                    // Check every source literal, including numerically equal
                    // interior values that never become an extremum.
                    ExactNumber::parse(value.source_literal(), &relative.value_limits)?;
                }
                if let Some(&first) = answers.first() {
                    let RouteOutcome::Answer(previous) = &accepted[first].outcome else {
                        unreachable!()
                    };
                    match (&previous.key, &answer.key, &policy.agreement) {
                        (
                            AgreementKey::Number { unit: a, .. },
                            AgreementKey::Number { value, unit: b },
                            AgreementMode::Relative(_),
                        ) if a == b => {
                            let (min, max) = numeric_extrema.expect("first numeric answer");
                            let number_at = |i: usize| match &accepted[i].outcome {
                                RouteOutcome::Answer(AnswerCandidate {
                                    key: AgreementKey::Number { value, .. },
                                    ..
                                }) => value,
                                _ => unreachable!(),
                            };
                            numeric_extrema = Some((
                                if value < number_at(min) { index } else { min },
                                if value > number_at(max) { index } else { max },
                            ));
                        }
                        _ => unequal |= previous.key != answer.key,
                    }
                } else if matches!(answer.key, AgreementKey::Number { .. }) {
                    numeric_extrema = Some((index, index));
                }
                answers.push(index);
            }
            RouteOutcome::Refusal(refusal) => {
                meter.text(&refusal.response)?;
                meter.text(&refusal.path)?;
                refusals.push(index);
            }
            RouteOutcome::Unavailable(reason) => {
                if let Unavailability::Failed(detail) = reason {
                    meter.text(detail)?;
                }
                unavailable.push(index);
                required_failure |= route.participation == Participation::Required;
            }
            RouteOutcome::NoReading => {}
        }
        accepted.push(report);
    }
    if input.next().is_some() {
        return Err(Error::Invalid("unexpected route report".into()));
    }
    if let (Some((min, max)), AgreementMode::Relative(relative)) =
        (numeric_extrema, &policy.agreement)
    {
        let value_at = |i: usize| match &accepted[i].outcome {
            RouteOutcome::Answer(AnswerCandidate {
                key: AgreementKey::Number { value, .. },
                ..
            }) => value,
            _ => unreachable!(),
        };
        // For tolerance < 1, the extrema suffice: if they straddle zero they
        // can agree only through the shared floor; on one side of zero the
        // largest relative gap is between the extrema. No quadratic pair scan.
        unequal |= !value_at(min).within_relative(
            value_at(max),
            &relative.tolerance,
            &relative.floor,
            &relative.value_limits,
        )?;
    }
    budget.check()?;
    let outcome = if !refusals.is_empty() {
        AdmissionOutcome::Refused { routes: refusals }
    } else if unequal {
        AdmissionOutcome::Disagreement { routes: answers }
    } else if required_failure {
        AdmissionOutcome::Unavailable {
            routes: unavailable,
        }
    } else if let Some(&selected) = answers.first() {
        AdmissionOutcome::Answered {
            selected,
            agreeing: answers,
        }
    } else if !unavailable.is_empty() {
        AdmissionOutcome::Unavailable {
            routes: unavailable,
        }
    } else {
        AdmissionOutcome::NoReading
    };
    Ok(AdmissionDecision {
        outcome,
        reports: accepted,
        guard_records: Vec::new(),
        duplicate_evidence_claims: duplicates,
        limits: policy.limits.clone(),
        admitted_bytes: meter.bytes,
    })
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GuardVerdict {
    Keep,
    Veto { reason: String },
    Unavailable { reason: String },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GuardRecord {
    pub guard: String,
    pub verdict: GuardVerdict,
}

/// A guard receives a shared reference and can only keep or withhold the selected
/// answer. Implementations must cooperate with the supplied budget; this trait
/// is for trusted native host code, not untrusted plugins or Python callbacks.
pub trait NarrowingGuard {
    fn id(&self) -> &str;
    fn check(&self, candidate: &AnswerCandidate, budget: &Budget) -> Result<GuardVerdict>;
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UnknownDimension {
    Pass,
    Veto,
}

/// The guard compares typed dimensions, never an incomplete parse of a unit
/// suffix. `Pass` models w574's unread-power exception; it makes no dimensional
/// correctness claim. `Veto` is available when an operation requires a dimension.
pub struct DimensionGuard {
    pub id: String,
    pub expected: Dimension,
    pub unknown: UnknownDimension,
}

impl NarrowingGuard for DimensionGuard {
    fn id(&self) -> &str {
        &self.id
    }

    fn check(&self, candidate: &AnswerCandidate, budget: &Budget) -> Result<GuardVerdict> {
        budget.spend(1)?;
        Ok(match candidate.dimension {
            Some(got) if got != self.expected => GuardVerdict::Veto {
                reason: "answer dimension differs from requested dimension".into(),
            },
            None if self.unknown == UnknownDimension::Veto => GuardVerdict::Veto {
                reason: "answer dimension is unavailable".into(),
            },
            _ => GuardVerdict::Keep,
        })
    }
}

/// Run ordered guards only after arbitration. A veto ends the group; it cannot
/// remove an inconvenient candidate and try arbitration again. Non-answers pass
/// through unchanged, with no guard call. Global budget errors return `Err`.
pub fn apply_guards(
    mut decision: AdmissionDecision,
    guards: &[&dyn NarrowingGuard],
    budget: &Budget,
) -> Result<AdmissionDecision> {
    budget.check()?;
    if decision.answer().is_none() {
        return Ok(decision);
    }
    if guards.len().saturating_add(decision.guard_records.len()) > decision.limits.guards {
        return Err(Error::Limit("admission guards"));
    }
    let mut meter = Meter {
        limits: &decision.limits,
        budget,
        bytes: decision.admitted_bytes,
        claims: 0,
    };
    let mut ids: BTreeSet<String> = decision
        .guard_records
        .iter()
        .map(|r| r.guard.clone())
        .collect();
    for guard in guards {
        meter.text(guard.id())?;
        if guard.id().is_empty() || !ids.insert(guard.id().into()) {
            return Err(Error::Invalid("empty or duplicate guard identity".into()));
        }
    }
    for guard in guards {
        budget.spend(1)?;
        let verdict = guard.check(decision.answer().expect("guards stop on veto"), budget)?;
        budget.check()?;
        match &verdict {
            GuardVerdict::Keep => {}
            GuardVerdict::Veto { reason } => {
                meter.text(reason)?;
                decision.outcome = AdmissionOutcome::GuardVeto {
                    guard: guard.id().into(),
                    reason: reason.clone(),
                };
            }
            GuardVerdict::Unavailable { reason } => {
                meter.text(reason)?;
                decision.outcome = AdmissionOutcome::GuardUnavailable {
                    guard: guard.id().into(),
                    reason: reason.clone(),
                };
            }
        }
        let stop = verdict != GuardVerdict::Keep;
        decision.guard_records.push(GuardRecord {
            guard: guard.id().into(),
            verdict,
        });
        if stop {
            break;
        }
    }
    decision.admitted_bytes = meter.bytes;
    budget.check()?;
    Ok(decision)
}
