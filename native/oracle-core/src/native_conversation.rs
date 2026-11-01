//! Finite native delivered-answer context. This is handwritten bookkeeping and
//! exact arithmetic over retained numerical tokens, not an Engine snapshot or
//! a proof of the source's physical precision. Unsupported turns preserve it.
use crate::session::{NativeSessionOwner, NumericOrigin, SessionBinding, SessionSelection};
use crate::value::{ExactNumber, ValueLimits};
use crate::{Budget, Error, Result};
use num_rational::BigRational;
use num_traits::Zero;
use serde::{Deserialize, Serialize};

pub const OWNER: &str = "native_conversation_context";
pub const OWNER_VERSION: u32 = 1;
pub const OPERATION: &str = "context.native";
pub const MAX_OWNER_BYTES: usize = 16384;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NativeQuantity {
    pub number: String,
    /// An explicit unit token. `1` is dimensionless; no unit is inferred.
    pub unit: String,
    pub origin: NumericOrigin,
}
impl NativeQuantity {
    pub fn validate(&self) -> Result<()> {
        ExactNumber::parse(&self.number, &number_limits())?;
        if self.unit.is_empty() || self.unit.len() > 256 || self.unit.chars().any(char::is_control)
        {
            return Err(Error::Invalid("native quantity unit".into()));
        }
        Ok(())
    }
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum NativeAnchor {
    Empty,
    /// A reference to the envelope's current singleton selection, not another
    /// entity set or an inferred Python/Wikidata identity.
    Entity {
        id: String,
    },
    Quantity {
        value: NativeQuantity,
    },
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProviderIdentity {
    pub provider: String,
    pub artifact_identity: String,
}
impl ProviderIdentity {
    /// Compiled host authority binds this to an admitted typed provider result
    /// after arbitration. This constructor does not verify that provider's math.
    pub fn from_host_delivery(provider: &str, artifact_identity: &str) -> Result<Self> {
        let identity = Self {
            provider: provider.into(),
            artifact_identity: artifact_identity.into(),
        };
        identity.validate()?;
        Ok(identity)
    }
    fn validate(&self) -> Result<()> {
        if self.provider.is_empty()
            || self.provider.len() > 128
            || !self
                .provider
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"_.:-".contains(&b))
            || self.artifact_identity.len() != 64
            || !self
                .artifact_identity
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(Error::Invalid("native provider identity".into()));
        }
        Ok(())
    }
}
/// No Deserialize implementation: a public supplied-data command cannot claim
/// this host-delivery provenance merely by including extra JSON fields.
#[derive(Debug)]
pub struct ProviderQuantityAnchor {
    pub(crate) identity: ProviderIdentity,
    pub(crate) quantity: NativeQuantity,
}
impl ProviderQuantityAnchor {
    pub fn from_host_delivery(
        identity: ProviderIdentity,
        quantity: NativeQuantity,
    ) -> Result<Self> {
        identity.validate()?;
        quantity.validate()?;
        Ok(Self { identity, quantity })
    }
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum AnchorSource {
    Supplied,
    Provider { identity: ProviderIdentity },
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Derivation {
    pub previous_request: String,
    pub previous_revision: i64,
    pub operation: String,
    pub operand: String,
    pub conversion_factor: String,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AnchorLineage {
    pub request: String,
    pub revision: i64,
    pub source: AnchorSource,
    /// Immediate parent only; the session reply journal retains prior turns.
    pub derivation: Option<Derivation>,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NativeContextState {
    pub owner: String,
    pub version: u32,
    pub anchor: NativeAnchor,
    pub delivery: Option<AnchorLineage>,
}
impl Default for NativeContextState {
    fn default() -> Self {
        Self {
            owner: OWNER.into(),
            version: OWNER_VERSION,
            anchor: NativeAnchor::Empty,
            delivery: None,
        }
    }
}
impl NativeContextState {
    pub fn validate(&self, revision: i64) -> Result<()> {
        if self.owner != OWNER || self.version != OWNER_VERSION || revision < 0 {
            return Err(Error::Format("native context owner/version".into()));
        }
        match (&self.anchor, &self.delivery) {
            (NativeAnchor::Empty, None) => (),
            (NativeAnchor::Entity { id }, Some(lineage)) => {
                entity_id(id)?;
                validate_lineage(lineage, revision)?;
            }
            (NativeAnchor::Quantity { value }, Some(lineage)) => {
                value.validate()?;
                validate_lineage(lineage, revision)?;
            }
            _ => {
                return Err(Error::Format(
                    "native anchor lineage missing or spurious".into(),
                ))
            }
        }
        crate::query::encoded_size(self, MAX_OWNER_BYTES)?;
        Ok(())
    }
    pub fn validate_selection(&self, selection: &SessionSelection) -> Result<()> {
        if let NativeAnchor::Entity { id } = &self.anchor {
            if selection.ids.len() != 1 || !selection.ids.contains(id) {
                return Err(Error::Conflict("native entity no longer matches selection"));
            }
        }
        Ok(())
    }
    pub fn quantity(&self) -> Option<&NativeQuantity> {
        match &self.anchor {
            NativeAnchor::Quantity { value } => Some(value),
            _ => None,
        }
    }
}
fn entity_id(id: &str) -> Result<()> {
    if id.is_empty() || id.len() > 256 || id.chars().any(char::is_control) {
        return Err(Error::Invalid("native entity reference".into()));
    }
    Ok(())
}
fn request_id(id: &str) -> Result<()> {
    crate::runtime::identifier(id)
}
fn validate_lineage(lineage: &AnchorLineage, revision: i64) -> Result<()> {
    request_id(&lineage.request)?;
    if lineage.revision < 1 || lineage.revision > revision {
        return Err(Error::Format("native delivery revision".into()));
    }
    if let AnchorSource::Provider { identity } = &lineage.source {
        identity.validate()?;
    }
    if let Some(d) = &lineage.derivation {
        request_id(&d.previous_request)?;
        if d.previous_revision < 1
            || d.previous_revision >= lineage.revision
            || !matches!(d.operation.as_str(), "scale" | "divide" | "cost")
        {
            return Err(Error::Format("native derivation lineage".into()));
        }
        ExactNumber::parse(&d.operand, &number_limits())?;
        ExactNumber::parse(&d.conversion_factor, &number_limits())?;
    }
    Ok(())
}
fn number_limits() -> ValueLimits {
    ValueLimits {
        max_numeric_digits: 128,
        max_exponent: 128,
        max_text_bytes: 512,
        ..Default::default()
    }
}
fn rational(text: &str) -> Result<BigRational> {
    let n = ExactNumber::parse(text, &number_limits())?;
    Ok(BigRational::new(
        n.numerator().clone(),
        n.denominator().clone(),
    ))
}
// Numeric syntax already caps digits/exponents. Check bigint growth and charge
// the bounded multiplication before allocating its result, including on paths
// that will later reject an overlong reduced output token.
fn multiply(left: BigRational, right: BigRational, budget: &Budget) -> Result<BigRational> {
    let numerator_bits = left.numer().bits().saturating_add(right.numer().bits());
    let denominator_bits = left.denom().bits().saturating_add(right.denom().bits());
    if numerator_bits > 4096 || denominator_bits > 4096 {
        return Err(Error::Limit("native numerical intermediate bits"));
    }
    let work = numerator_bits.saturating_add(denominator_bits).max(1);
    budget.spend(
        work.saturating_mul(work)
            .saturating_div(64)
            .saturating_add(1),
    )?;
    let _memory = budget.reserve_memory((work as usize).saturating_mul(16))?;
    let result = left * right;
    budget.check()?;
    Ok(result)
}
fn ratio_text(n: &BigRational) -> Result<String> {
    let text = format!("{}/{}", n.numer(), n.denom());
    ExactNumber::parse(&text, &number_limits())?;
    Ok(text)
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
pub enum NativeContextCommand {
    /// Supplied data, with no claim that a provider produced it.
    Observe {
        quantity: NativeQuantity,
    },
    Scale {
        factor: String,
    },
    Divide {
        divisor: String,
    },
    /// Dollar cost at an explicit rate per exactly named unit. Only equal units
    /// and the written J/kWh conversion are admitted in this finite contract.
    Cost {
        rate: String,
        per_unit: String,
    },
    Acknowledge,
    ResetTopic,
    Inspect,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NativeContextStatus {
    Answered,
    Withheld,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NativeContextRefusal {
    PriorQuantityUnavailable,
    UndefinedDivision,
    IncompatibleRateUnit,
    PriorEntityUnavailable,
    RelationNotUnique,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NativeContextReply {
    pub status: NativeContextStatus,
    pub owner: String,
    pub version: i64,
    pub anchor: NativeAnchor,
    pub delivery: Option<AnchorLineage>,
    pub reason: Option<NativeContextRefusal>,
}
impl NativeContextReply {
    pub fn quantity(&self) -> Option<&NativeQuantity> {
        match &self.anchor {
            NativeAnchor::Quantity { value } => Some(value),
            _ => None,
        }
    }
}
pub(crate) fn reply(
    state: &NativeContextState,
    revision: i64,
    reason: Option<NativeContextRefusal>,
) -> NativeContextReply {
    NativeContextReply {
        status: if reason.is_some() {
            NativeContextStatus::Withheld
        } else {
            NativeContextStatus::Answered
        },
        owner: OWNER.into(),
        version: revision,
        anchor: state.anchor.clone(),
        delivery: state.delivery.clone(),
        reason,
    }
}
pub struct NativeConversationOwner;
impl NativeSessionOwner for NativeConversationOwner {
    const OWNER: &'static str = crate::native_conversation::OWNER;
    const VERSION: u32 = crate::native_conversation::OWNER_VERSION;
    const OPERATION: &'static str = crate::native_conversation::OPERATION;
    type State = NativeContextState;
    type Command = NativeContextCommand;
    type Reply = NativeContextReply;
    fn validate(state: &Self::State, _: &SessionBinding, revision: i64) -> Result<()> {
        state.validate(revision)
    }
    fn transition(
        _: &SessionBinding,
        revision: i64,
        request: &str,
        state: Option<Self::State>,
        command: Self::Command,
        budget: &Budget,
    ) -> Result<(Self::State, Self::Reply)> {
        let state = state.ok_or(Error::Conflict(
            "native context requires explicit initialization",
        ))?;
        transition(revision, request, state, command, budget)
    }
}
pub(crate) fn deliver(
    revision: i64,
    request: &str,
    mut state: NativeContextState,
    anchor: NativeAnchor,
    source: AnchorSource,
    budget: &Budget,
) -> Result<(NativeContextState, NativeContextReply)> {
    budget.spend(1)?;
    request_id(request)?;
    state.validate(revision)?;
    let next = revision
        .checked_add(1)
        .ok_or(Error::Limit("native revision"))?;
    let _memory = budget.reserve_memory(MAX_OWNER_BYTES * 4)?;
    state.anchor = anchor;
    state.delivery = Some(AnchorLineage {
        request: request.into(),
        revision: next,
        source,
        derivation: None,
    });
    state.validate(next)?;
    budget.check()?;
    let response = reply(&state, next, None);
    Ok((state, response))
}
pub(crate) fn transition(
    revision: i64,
    request: &str,
    mut state: NativeContextState,
    command: NativeContextCommand,
    budget: &Budget,
) -> Result<(NativeContextState, NativeContextReply)> {
    budget.spend(1)?;
    request_id(request)?;
    state.validate(revision)?;
    let next = revision
        .checked_add(1)
        .ok_or(Error::Limit("native revision"))?;
    let _memory = budget.reserve_memory(MAX_OWNER_BYTES * 8)?;
    let mut reason = None;
    match command {
        NativeContextCommand::Observe { quantity } => {
            return deliver(
                revision,
                request,
                state,
                NativeAnchor::Quantity { value: quantity },
                AnchorSource::Supplied,
                budget,
            )
        }
        NativeContextCommand::Acknowledge | NativeContextCommand::Inspect => (),
        NativeContextCommand::ResetTopic => {
            state.anchor = NativeAnchor::Empty;
            state.delivery = None;
        }
        command => {
            let operation = match &command {
                NativeContextCommand::Scale { .. } => "scale",
                NativeContextCommand::Divide { .. } => "divide",
                NativeContextCommand::Cost { .. } => "cost",
                _ => unreachable!(),
            };
            let (operand, per_unit) = match command {
                NativeContextCommand::Scale { factor } => (factor, None),
                NativeContextCommand::Divide { divisor } => (divisor, None),
                NativeContextCommand::Cost { rate, per_unit } => (rate, Some(per_unit)),
                _ => unreachable!(),
            };
            if let Some(unit) = &per_unit {
                if unit.is_empty()
                    || unit.len() > 256
                    || unit.trim() != unit
                    || unit.chars().any(char::is_control)
                {
                    return Err(Error::Invalid("native rate unit".into()));
                }
            }
            let operand_number = rational(&operand)?;
            if operation == "divide" && operand_number.is_zero() {
                reason = Some(NativeContextRefusal::UndefinedDivision);
            } else if let NativeAnchor::Quantity { value } = &state.anchor {
                let conversion = if let Some(per_unit) = &per_unit {
                    if &value.unit == per_unit {
                        Some(BigRational::from_integer(1.into()))
                    } else {
                        match (value.unit.as_str(), per_unit.as_str()) {
                            ("J", "kWh") => Some(BigRational::new(1.into(), 3_600_000.into())),
                            ("kWh", "J") => Some(BigRational::from_integer(3_600_000.into())),
                            _ => None,
                        }
                    }
                } else {
                    Some(BigRational::from_integer(1.into()))
                };
                if let Some(conversion) = conversion {
                    let prior = state
                        .delivery
                        .as_ref()
                        .ok_or_else(|| Error::Format("native prior lineage".into()))?;
                    let factor = if operation == "divide" {
                        operand_number.recip()
                    } else {
                        operand_number
                    };
                    let scaled = multiply(rational(&value.number)?, factor, budget)?;
                    let result = multiply(scaled, conversion.clone(), budget)?;
                    let number = ratio_text(&result)?;
                    let unit = if operation == "cost" {
                        "$".into()
                    } else {
                        value.unit.clone()
                    };
                    let origin = value.origin.clone();
                    let lineage = AnchorLineage {
                        request: request.into(),
                        revision: next,
                        source: prior.source.clone(),
                        derivation: Some(Derivation {
                            previous_request: prior.request.clone(),
                            previous_revision: prior.revision,
                            operation: operation.into(),
                            operand,
                            conversion_factor: ratio_text(&conversion)?,
                        }),
                    };
                    state.anchor = NativeAnchor::Quantity {
                        value: NativeQuantity {
                            number,
                            unit,
                            origin,
                        },
                    };
                    state.delivery = Some(lineage);
                } else {
                    reason = Some(NativeContextRefusal::IncompatibleRateUnit);
                }
            } else {
                reason = Some(NativeContextRefusal::PriorQuantityUnavailable);
            }
        }
    }
    state.validate(next)?;
    budget.check()?;
    let response = reply(&state, next, reason);
    Ok((state, response))
}
