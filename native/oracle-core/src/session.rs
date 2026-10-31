//! Durable conversation data, independent of workers and Python module globals.
//!
//! This is an executable serialization/transition contract, not an isolation proof.
//! A schema-1 selection cannot recover Oracle's missing dialogue caches. Adapters
//! must import those explicitly and declare every opaque state owner they support.
use crate::query::{AttributeFact, Fact};
use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use serde_json::{Number, Value};
use std::collections::{BTreeMap, BTreeSet};

pub const SESSION_SCHEMA: u32 = 3;
pub const PYTHON_ADAPTER_SCHEMA: u32 = 1;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SessionBinding {
    pub tenant: String,
    pub session: String,
    pub image: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SessionSelection {
    pub ids: BTreeSet<String>,
    pub facts: BTreeSet<Fact>,
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub attributes: BTreeSet<AttributeFact>,
}

/// Provenance of the available state, never a claim that the whole Engine is isolated.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum StateCoverage {
    NativeSelectionOnly,
    /// Source is an immutable release/adapter identifier, not a filesystem path.
    OracleAdapter {
        adapter_schema: u32,
        source: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Referent {
    /// Preserve the Python qid's namespace; do not infer identity from its label.
    pub id: String,
    pub label: String,
    pub is_person: bool,
    pub surface: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NumericOrigin {
    ExactDecimal,
    /// Decimal spelling of an already rounded Python float, not source precision.
    PythonFloat,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PriorValue {
    pub number: Number,
    pub unit: String,
    pub origin: NumericOrigin,
}

/// Fields of chat_context_v2.Turn. No tuple positions are inferred by recovery.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DialogueContext {
    pub question: Option<String>,
    pub subject: Option<Referent>,
    pub answer: Option<Referent>,
    pub result: Option<PriorValue>,
    /// Python stores solved values as strings; retain their spelling verbatim.
    pub solved: BTreeMap<String, String>,
    pub material: Option<String>,
    pub topic: Option<Referent>,
}

/// Explicit owner/version/byte count for data whose semantics remain in an adapter.
/// JSON is inert here. Adapters must never export paths, handles or executable objects.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExtensionState {
    pub owner: String,
    pub version: u32,
    /// Exact UTF-8 size of serde_json serialization of payload (checked on import).
    pub payload_bytes: usize,
    pub payload: Value,
}

impl ExtensionState {
    pub fn new(owner: String, version: u32, payload: Value) -> Result<Self> {
        let payload_bytes = serde_json::to_vec(&payload)?.len();
        Ok(Self {
            owner,
            version,
            payload_bytes,
            payload,
        })
    }
}

/// runtime_an._pending_conversion[sid], including all adapter-specific keys.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PendingInterpretation {
    pub from: String,
    pub to: String,
    pub conversion: ExtensionState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AnswerLineage {
    pub revision: i64,
    pub request: String,
    /// Full delivered reply; the native contract does not reinterpret its claims.
    pub reply: ExtensionState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PhysicsLineage {
    pub question: String,
    /// Legacy imports can know the question without knowing the producing request.
    pub answer: Option<AnswerLineage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EffectLineage {
    pub revision: i64,
    pub request: String,
    /// References only. The broker's durable journal owns outcomes and replay policy.
    pub effect_ids: Vec<String>,
}

/// One explicit Python session snapshot, not an Engine object pickle.
/// Absence within this struct means the exporter observed an absent entry.
/// Unknown/unexported conversational state is represented by envelope.oracle=None.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OracleSessionState {
    pub history: Vec<String>,
    pub context: Option<DialogueContext>,
    pub last_value: Option<PriorValue>,
    pub pending_interpretation: Option<PendingInterpretation>,
    pub last_answer: Option<AnswerLineage>,
    pub last_physics: Option<PhysicsLineage>,
    pub last_effect: Option<EffectLineage>,
    /// Includes dialogue, AN transition/path history, v4 discourse and ego mood.
    /// Each exported owner must appear in the host's supported-version manifest.
    pub extensions: BTreeMap<String, ExtensionState>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SessionEnvelope {
    pub schema: u32,
    pub binding: SessionBinding,
    pub revision: i64,
    pub coverage: StateCoverage,
    pub selection: SessionSelection,
    pub oracle: Option<OracleSessionState>,
    /// Native owners are independent of unknown/unexported Python owners.
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub native_extensions: BTreeMap<String, ExtensionState>,
}

/// Compiled host-selected state machine. JSON exists only at the durable/input
/// boundary; domain transitions receive typed state. No external effects here.
pub trait NativeSessionOwner {
    const OWNER: &'static str;
    const VERSION: u32;
    const OPERATION: &'static str;
    type State: Serialize + serde::de::DeserializeOwned;
    type Command: Serialize + serde::de::DeserializeOwned;
    type Reply: Serialize;
    fn validate(state: &Self::State, binding: &SessionBinding, revision: i64) -> Result<()>;
    fn transition(
        binding: &SessionBinding,
        revision: i64,
        request: &str,
        state: Option<Self::State>,
        command: Self::Command,
        budget: &crate::Budget,
    ) -> Result<(Self::State, Self::Reply)>;
}

/// Immutable checked read; the reservation lives as long as the typed snapshot.
pub struct NativeOwnerSnapshot<T: NativeSessionOwner> {
    pub(crate) binding: SessionBinding,
    pub(crate) revision: i64,
    pub(crate) state: Option<T::State>,
    pub(crate) _memory: crate::budget::MemoryReservation,
}
impl<T: NativeSessionOwner> NativeOwnerSnapshot<T> {
    pub fn binding(&self) -> &SessionBinding {
        &self.binding
    }
    pub fn revision(&self) -> i64 {
        self.revision
    }
    pub fn state(&self) -> Option<&T::State> {
        self.state.as_ref()
    }
}

/// Host policy. Version manifests come from the adapter release, never the snapshot.
#[derive(Debug, Clone)]
pub struct SessionLimits {
    pub max_bytes: usize,
    pub max_items: usize,
    pub max_text_bytes: usize,
    pub max_extension_bytes: usize,
    pub max_json_depth: usize,
    pub extension_versions: BTreeMap<String, u32>,
    /// Host manifest, never recovered from snapshot bytes.
    pub native_extension_versions: BTreeMap<String, u32>,
}

impl Default for SessionLimits {
    fn default() -> Self {
        Self {
            max_bytes: 1024 * 1024,
            max_items: 4096,
            max_text_bytes: 64 * 1024,
            max_extension_bytes: 256 * 1024,
            max_json_depth: 32,
            extension_versions: BTreeMap::new(),
            native_extension_versions: BTreeMap::new(),
        }
    }
}

/// Drafts are private to one computation. Dropping a draft leaves committed state
/// untouched, including a pending conversion consumed speculatively by that turn.
#[derive(Debug)]
pub struct SessionTurn {
    base: SessionEnvelope,
    candidate: SessionEnvelope,
    consumed: Option<PendingInterpretation>,
}

fn identifier(s: &str) -> Result<()> {
    if s.is_empty()
        || s.len() > 128
        || !s
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))
    {
        return Err(Error::Invalid("invalid session identity".into()));
    }
    Ok(())
}

fn bounded_text(s: &str, limits: &SessionLimits) -> Result<()> {
    if s.len() > limits.max_text_bytes {
        return Err(Error::Limit("session text bytes"));
    }
    Ok(())
}

fn bounded_json(v: &Value, depth: usize, count: &mut usize, limits: &SessionLimits) -> Result<()> {
    if depth > limits.max_json_depth {
        return Err(Error::Limit("session JSON depth"));
    }
    *count = count
        .checked_add(1)
        .ok_or(Error::Limit("session JSON items"))?;
    if *count > limits.max_items {
        return Err(Error::Limit("session JSON items"));
    }
    match v {
        Value::String(s) => bounded_text(s, limits)?,
        Value::Array(xs) => {
            for x in xs {
                bounded_json(x, depth + 1, count, limits)?;
            }
        }
        Value::Object(xs) => {
            for (k, x) in xs {
                bounded_text(k, limits)?;
                bounded_json(x, depth + 1, count, limits)?;
            }
        }
        _ => (),
    }
    Ok(())
}

fn extension(v: &ExtensionState, limits: &SessionLimits) -> Result<()> {
    owner_identifier(&v.owner)?;
    if limits.extension_versions.get(&v.owner) != Some(&v.version) {
        return Err(Error::Format(format!(
            "unsupported session state owner/version: {}/{}",
            v.owner, v.version
        )));
    }
    let encoded = crate::query::encode(&v.payload, limits.max_extension_bytes)?;
    if encoded.len() != v.payload_bytes {
        return Err(Error::Format("session extension byte count".into()));
    }
    bounded_json(&v.payload, 0, &mut 0, limits)
}

pub(crate) fn owner_identifier(s: &str) -> Result<()> {
    if s.is_empty()
        || s.len() > 128
        || !s
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_.-".contains(&b))
    {
        return Err(Error::Invalid("invalid state owner identity".into()));
    }
    Ok(())
}

fn answer(v: &AnswerLineage, revision: i64, limits: &SessionLimits) -> Result<()> {
    identifier(&v.request)?;
    if v.revision < 1 || v.revision > revision {
        return Err(Error::Format("answer lineage revision".into()));
    }
    extension(&v.reply, limits)
}

impl SessionEnvelope {
    /// Fresh native selection state. This does not initialize missing Oracle caches.
    pub fn new(binding: SessionBinding) -> Result<Self> {
        let envelope = Self {
            schema: SESSION_SCHEMA,
            binding,
            revision: 0,
            coverage: StateCoverage::NativeSelectionOnly,
            selection: SessionSelection::default(),
            oracle: None,
            native_extensions: BTreeMap::new(),
        };
        envelope.validate(&SessionLimits::default())?;
        Ok(envelope)
    }

    pub fn validate(&self, limits: &SessionLimits) -> Result<()> {
        if self.schema != SESSION_SCHEMA {
            return Err(Error::Format(
                "session schema requires explicit migration".into(),
            ));
        }
        identifier(&self.binding.tenant)?;
        identifier(&self.binding.session)?;
        if self.binding.image.is_empty() {
            return Err(Error::Invalid("empty session image".into()));
        }
        bounded_text(&self.binding.image, limits)?;
        if self.revision < 0 {
            return Err(Error::Format("negative session revision".into()));
        }
        match (&self.coverage, &self.oracle) {
            (StateCoverage::NativeSelectionOnly, None) => (),
            (
                StateCoverage::OracleAdapter {
                    adapter_schema,
                    source,
                },
                Some(_),
            ) if *adapter_schema == PYTHON_ADAPTER_SCHEMA && !source.is_empty() => {
                bounded_text(source, limits)?
            }
            _ => {
                return Err(Error::Format(
                    "session coverage and payload disagree".into(),
                ))
            }
        }
        // Inspect the full data tree, including source facts, before accepting it.
        let tree = serde_json::to_value(self)?;
        bounded_json(&tree, 0, &mut 0, limits)?;
        if let Some(state) = &self.oracle {
            if let Some(pending) = &state.pending_interpretation {
                extension(&pending.conversion, limits)?;
                if pending.conversion.owner != "runtime_an_conversion"
                    || pending
                        .conversion
                        .payload
                        .get("from")
                        .and_then(Value::as_str)
                        != Some(pending.from.as_str())
                    || pending.conversion.payload.get("to").and_then(Value::as_str)
                        != Some(pending.to.as_str())
                {
                    return Err(Error::Format("pending conversion fields disagree".into()));
                }
            }
            if let Some(v) = &state.last_answer {
                answer(v, self.revision, limits)?;
            }
            if let Some(v) = &state.last_physics {
                if let Some(v) = &v.answer {
                    answer(v, self.revision, limits)?;
                }
            }
            if let Some(v) = &state.last_effect {
                identifier(&v.request)?;
                if v.revision < 1 || v.revision > self.revision {
                    return Err(Error::Format("effect lineage revision".into()));
                }
                let mut unique = BTreeSet::new();
                for id in &v.effect_ids {
                    identifier(id)?;
                    if !unique.insert(id) {
                        return Err(Error::Format("duplicate effect lineage ID".into()));
                    }
                }
            }
            for (owner, value) in &state.extensions {
                if owner != &value.owner {
                    return Err(Error::Format("extension owner key mismatch".into()));
                }
                extension(value, limits)?;
            }
        }
        for (owner, value) in &self.native_extensions {
            if owner != &value.owner {
                return Err(Error::Format("native owner key mismatch".into()));
            }
            let mut native_limits = limits.clone();
            native_limits.extension_versions = limits.native_extension_versions.clone();
            extension(value, &native_limits)?;
        }
        crate::query::encode(self, limits.max_bytes)?;
        Ok(())
    }

    pub fn encode(&self, limits: &SessionLimits) -> Result<String> {
        self.validate(limits)?;
        crate::query::encode(self, limits.max_bytes)
    }

    /// Recovery binds bytes to the authenticated tenant/session/image and SQL revision.
    /// No absent nonzero revision, schema-1 record, or wrong identity is repaired here.
    pub fn recover(
        text: Option<&str>,
        binding: &SessionBinding,
        revision: i64,
        limits: &SessionLimits,
    ) -> Result<Self> {
        let state = match text {
            None if revision == 0 => Self::new(binding.clone())?,
            None => return Err(Error::Conflict("session absent")),
            Some(text) => {
                if text.len() > limits.max_bytes {
                    return Err(Error::Limit("retained session bytes"));
                }
                serde_json::from_str::<Self>(text)?
            }
        };
        state.validate(limits)?;
        if &state.binding != binding {
            return Err(Error::Conflict(
                "session identity or image requires migration",
            ));
        }
        if state.revision != revision {
            return Err(Error::Conflict("session revision changed"));
        }
        Ok(state)
    }

    /// The only supported legacy migration preserves the native selection and marks
    /// all conversational state unavailable. It never manufactures empty dialogue.
    pub fn migrate_relation_v1(
        text: &str,
        binding: SessionBinding,
        revision: i64,
        limits: &SessionLimits,
    ) -> Result<Self> {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct Legacy {
            schema: u32,
            selection: SessionSelection,
        }
        if text.len() > limits.max_bytes {
            return Err(Error::Limit("legacy session bytes"));
        }
        let old: Legacy = serde_json::from_str(text)?;
        if old.schema != 1 {
            return Err(Error::Format("unsupported legacy session schema".into()));
        }
        let mut state = Self::new(binding)?;
        state.revision = revision;
        state.selection = old.selection;
        state.validate(limits)?;
        Ok(state)
    }

    /// Explicit additive migration. A missing Python snapshot stays unknown;
    /// neither native scalar nor any Oracle owner is manufactured from absence.
    pub fn migrate_v2(
        text: &str,
        binding: &SessionBinding,
        revision: i64,
        limits: &SessionLimits,
    ) -> Result<Self> {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct V2 {
            schema: u32,
            binding: SessionBinding,
            revision: i64,
            coverage: StateCoverage,
            selection: SessionSelection,
            oracle: Option<OracleSessionState>,
        }
        if text.len() > limits.max_bytes {
            return Err(Error::Limit("legacy session bytes"));
        }
        let old: V2 = serde_json::from_str(text)?;
        if old.schema != 2 || &old.binding != binding || old.revision != revision {
            return Err(Error::Conflict(
                "legacy session identity or revision changed",
            ));
        }
        let next = Self {
            schema: SESSION_SCHEMA,
            binding: old.binding,
            revision,
            coverage: old.coverage,
            selection: old.selection,
            oracle: old.oracle,
            native_extensions: BTreeMap::new(),
        };
        next.validate(limits)?;
        Ok(next)
    }

    /// Host-authorized adapter installation, after capturing all declared owners.
    /// Importing a partial Engine snapshot is allowed only as partial coverage; the
    /// coverage enum deliberately has no 'complete Engine isolation' variant.
    pub fn import_oracle(
        &mut self,
        source: String,
        state: OracleSessionState,
        limits: &SessionLimits,
    ) -> Result<()> {
        let mut next = self.clone();
        next.coverage = StateCoverage::OracleAdapter {
            adapter_schema: PYTHON_ADAPTER_SCHEMA,
            source,
        };
        next.oracle = Some(state);
        next.validate(limits)?;
        *self = next;
        Ok(())
    }

    pub fn begin_turn(
        &self,
        binding: &SessionBinding,
        revision: i64,
        require_oracle: bool,
        limits: &SessionLimits,
    ) -> Result<SessionTurn> {
        self.validate(limits)?;
        if &self.binding != binding || self.revision != revision {
            return Err(Error::Conflict("turn snapshot changed"));
        }
        if revision == i64::MAX {
            return Err(Error::Limit("session revision exhausted"));
        }
        if require_oracle && self.oracle.is_none() {
            return Err(Error::Conflict(
                "Oracle session state requires explicit import",
            ));
        }
        let mut candidate = self.clone();
        let consumed = candidate
            .oracle
            .as_mut()
            .and_then(|s| s.pending_interpretation.take());
        Ok(SessionTurn {
            base: self.clone(),
            candidate,
            consumed,
        })
    }
}

impl SessionTurn {
    pub fn consumed_interpretation(&self) -> Option<&PendingInterpretation> {
        self.consumed.as_ref()
    }
    pub fn selection_mut(&mut self) -> &mut SessionSelection {
        &mut self.candidate.selection
    }
    pub fn oracle_mut(&mut self) -> Result<&mut OracleSessionState> {
        self.candidate.oracle.as_mut().ok_or(Error::Conflict(
            "Oracle session state requires explicit import",
        ))
    }

    /// runtime_conversation_state.begin's explicit topic-reset event clears only
    /// context, w29's scalar cache and v4 discourse. Other caches remain adapter-owned.
    /// The caller recognizes the source module's _TOPIC syntax; native code does not.
    pub fn runtime_conversation_topic_reset(&mut self) -> Result<()> {
        let state = self.oracle_mut()?;
        state.context = Some(DialogueContext::default());
        state.last_value = None;
        state.extensions.remove("runtime_v4_disc");
        Ok(())
    }

    /// Deterministic commit proposal. The storage owner must compare the persisted
    /// revision and save the returned bytes with its exact reply in one transaction.
    /// Comparing full base bytes also rejects mutation at an unchanged SQL revision.
    pub fn commit(
        mut self,
        current: &SessionEnvelope,
        limits: &SessionLimits,
    ) -> Result<SessionEnvelope> {
        current.validate(limits)?;
        if current.encode(limits)? != self.base.encode(limits)? {
            return Err(Error::Conflict("session changed during turn"));
        }
        self.candidate.revision = self
            .base
            .revision
            .checked_add(1)
            .ok_or(Error::Limit("session revision exhausted"))?;
        self.candidate.validate(limits)?;
        Ok(self.candidate)
    }
}
