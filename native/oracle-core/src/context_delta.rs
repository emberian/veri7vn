//! Delivered dimensionless scalar state, extracted from Oracle w29's `_last_value`.
//!
//! Handwritten transition contract, not a theorem or an Engine snapshot. A proposal
//! has no side effects. Its storage owner must commit it only for the delivered
//! operation, together with the exact reply, in the existing session transaction.
//! Python-float imports retain their rounded origin through arithmetic. No units,
//! solved variables, pending interpretations, files or other Python owners move.
use crate::session::{NativeSessionOwner, SessionBinding};
use crate::value::{ExactNumber, ValueLimits};
use crate::{Error, Result};
use num_rational::BigRational;
use serde::{Deserialize, Serialize};

pub const OWNER: &str = "native_delivered_scalar";
pub const OWNER_VERSION: u32 = 1;
pub const MAX_OWNER_BYTES: usize = 8192;

pub struct ScalarOwner;

impl NativeSessionOwner for ScalarOwner {
    const OWNER: &'static str = crate::context_delta::OWNER;
    const VERSION: u32 = OWNER_VERSION;
    const OPERATION: &'static str = "context.execute";
    type State = ContextState;
    type Command = ContextCommand;
    type Reply = ContextReply;
    fn validate(state: &Self::State, _: &SessionBinding, revision: i64) -> Result<()> {
        state.validate(revision)
    }
    fn transition(
        binding: &SessionBinding,
        revision: i64,
        request: &str,
        state: Option<Self::State>,
        command: Self::Command,
        budget: &crate::Budget,
    ) -> Result<(Self::State, Self::Reply)> {
        budget.spend(1)?;
        let _memory = budget.reserve_memory(MAX_OWNER_BYTES * 8)?;
        let state = state.unwrap_or_default();
        let proposed = propose(binding, revision, request, &state, &command)?;
        budget.check()?;
        let reply = proposed.reply.clone();
        Ok((proposed.commit(binding, revision, &state)?, reply))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ScalarOrigin {
    ExactDecimal,
    PythonFloat,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScalarValue {
    /// Exact decimal or rational spelling; PythonFloat describes its precision.
    pub number: String,
    pub origin: ScalarOrigin,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DeliveredScalar {
    pub value: ScalarValue,
    pub request: String,
    pub revision: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContextState {
    pub owner: String,
    pub version: u32,
    pub scalar: Option<DeliveredScalar>,
}

impl Default for ContextState {
    fn default() -> Self {
        Self {
            owner: OWNER.into(),
            version: OWNER_VERSION,
            scalar: None,
        }
    }
}

fn identifier(text: &str) -> Result<()> {
    if text.is_empty()
        || text.len() > 128
        || !text
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))
    {
        return Err(Error::Invalid("context identity".into()));
    }
    Ok(())
}

fn scalar_limits() -> ValueLimits {
    ValueLimits {
        max_numeric_digits: 128,
        max_exponent: 128,
        max_text_bytes: 512,
        ..ValueLimits::default()
    }
}

impl ContextState {
    pub fn validate(&self, revision: i64) -> Result<()> {
        if self.owner != OWNER || self.version != OWNER_VERSION {
            return Err(Error::Format("unsupported scalar owner/version".into()));
        }
        if revision < 0 {
            return Err(Error::Invalid("negative context revision".into()));
        }
        if let Some(scalar) = &self.scalar {
            identifier(&scalar.request)?;
            if scalar.revision < 1 || scalar.revision > revision {
                return Err(Error::Format("scalar lineage revision".into()));
            }
            ExactNumber::parse(&scalar.value.number, &scalar_limits())?;
        }
        if serde_json::to_vec(self)?.len() > MAX_OWNER_BYTES {
            return Err(Error::Limit("scalar owner bytes"));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
pub enum ContextCommand {
    /// Supplied datum. Only the Python delivery bridge calls this an import of
    /// observed legacy state; client-supplied values have no extra authority.
    Observe {
        value: ScalarValue,
    },
    Scale {
        factor: String,
    },
    Clear,
    Inspect,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContextReply {
    pub status: String,
    pub owner: String,
    pub image: String,
    pub coverage: String,
    pub version: i64,
    pub scalar: Option<DeliveredScalar>,
    pub reason: Option<String>,
}

/// Private draft. It deliberately cannot mutate a session or journal itself.
#[derive(Debug, Clone)]
pub struct ContextDelta {
    binding: SessionBinding,
    revision: i64,
    base: ContextState,
    next: ContextState,
    pub reply: ContextReply,
}

pub fn propose(
    binding: &SessionBinding,
    revision: i64,
    request: &str,
    current: &ContextState,
    command: &ContextCommand,
) -> Result<ContextDelta> {
    identifier(&binding.tenant)?;
    identifier(&binding.session)?;
    identifier(request)?;
    if binding.image.is_empty() || binding.image.len() > 256 {
        return Err(Error::Invalid("context image identity".into()));
    }
    current.validate(revision)?;
    let next_revision = revision
        .checked_add(1)
        .ok_or(Error::Limit("context revision exhausted"))?;
    let mut next = current.clone();
    let mut reason = None;
    let value = match command {
        ContextCommand::Observe { value } => {
            ExactNumber::parse(&value.number, &scalar_limits())?;
            Some(value.clone())
        }
        ContextCommand::Scale { factor } => {
            let factor = ExactNumber::parse(factor, &scalar_limits())?;
            if let Some(prior) = &current.scalar {
                let number = ExactNumber::parse(&prior.value.number, &scalar_limits())?;
                let left =
                    BigRational::new(number.numerator().clone(), number.denominator().clone());
                let right =
                    BigRational::new(factor.numerator().clone(), factor.denominator().clone());
                let product = left * right;
                let text = format!("{}/{}", product.numer(), product.denom());
                let admitted = ExactNumber::parse(&text, &scalar_limits())?;
                // Keep reduced ratio spelling: bounded even for recurring decimals.
                Some(ScalarValue {
                    number: admitted.source_literal().into(),
                    origin: prior.value.origin.clone(),
                })
            } else {
                reason = Some("previous_scalar_unavailable".into());
                None
            }
        }
        ContextCommand::Clear => {
            next.scalar = None;
            None
        }
        ContextCommand::Inspect => None,
    };
    if let Some(value) = value {
        next.scalar = Some(DeliveredScalar {
            value,
            request: request.into(),
            revision: next_revision,
        });
    }
    next.validate(next_revision)?;
    let reply = ContextReply {
        status: if reason.is_some() {
            "withheld"
        } else {
            "answered"
        }
        .into(),
        owner: OWNER.into(),
        image: binding.image.clone(),
        version: next_revision,
        coverage: "delivered_dimensionless_scalar_only".into(),
        scalar: next.scalar.clone(),
        reason,
    };
    Ok(ContextDelta {
        binding: binding.clone(),
        revision,
        base: current.clone(),
        next,
        reply,
    })
}

impl ContextDelta {
    /// Call only after selecting this operation for delivery. Storage must compare
    /// the complete session envelope and commit exact reply bytes atomically too.
    pub fn commit(
        self,
        binding: &SessionBinding,
        revision: i64,
        current: &ContextState,
    ) -> Result<ContextState> {
        if &self.binding != binding || self.revision != revision || &self.base != current {
            return Err(Error::Conflict("context proposal base changed"));
        }
        Ok(self.next)
    }
}
