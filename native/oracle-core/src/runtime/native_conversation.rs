//! The finite native owner uses the existing candidate/session transaction.
//! These helpers do not send Engine requests or create a second journal.
use super::conversation::{ConversationCandidate, ConversationReaderProposal};
use super::*;
use crate::native_conversation::*;
use crate::session::ExtensionState;

#[derive(Debug, Clone)]
pub enum NativeEntityQuery {
    Find { name: String },
    ById { id: String },
    Relation { predicate: String },
}
#[derive(Debug, Serialize)]
pub struct NativeEntity {
    pub id: String,
    pub label: String,
}
#[derive(Serialize)]
pub struct NativeEntityReply {
    pub status: NativeContextStatus,
    pub entity: Option<NativeEntity>,
    pub context: NativeContextReply,
    pub evidence: Option<QueryResult>,
    #[serde(skip)]
    _memory: Option<crate::budget::MemoryReservation>,
}
fn next_revision(candidate: &ConversationCandidate) -> Result<i64> {
    candidate
        .revision()
        .checked_add(1)
        .ok_or(Error::Limit("native revision exhausted"))
}
impl Runtime {
    fn require_native_context(&self) -> Result<()> {
        self.require_native_owner::<NativeConversationOwner>()?;
        self.require_operation(OPERATION)
    }
    /// Only a genuinely absent session may acquire an empty native owner.
    /// An absent owner in retained state is unknown, never an empty conversation.
    pub fn conversation_native_initialize(
        &self,
        candidate: &mut ConversationCandidate,
        budget: &Budget,
    ) -> Result<()> {
        self.require_native_context()?;
        self.check_conversation_candidate(candidate)?;
        if candidate.envelope.oracle.is_some() {
            return Err(Error::Conflict("native context cannot adopt Oracle owners"));
        }
        if candidate.envelope.native_extensions.contains_key(OWNER) {
            self.conversation_native_validate(candidate, budget)?;
            return Ok(());
        }
        if !candidate.starts_new_session() {
            return Err(Error::Conflict(
                "retained native context missing; reset required",
            ));
        }
        self.store_native_context(candidate, NativeContextState::default(), budget)
    }
    /// Checked native owner only; this never imports or fabricates Oracle state.
    pub fn conversation_native_validate(
        &self,
        candidate: &ConversationCandidate,
        budget: &Budget,
    ) -> Result<NativeContextState> {
        self.require_native_context()?;
        self.check_conversation_candidate(candidate)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        budget.check()?;
        if candidate.envelope.oracle.is_some() {
            return Err(Error::Conflict("native context cannot adopt Oracle owners"));
        }
        let extension = candidate
            .envelope
            .native_extensions
            .get(OWNER)
            .ok_or(Error::Conflict(
                "native context unavailable; reset required",
            ))?;
        if extension.version != OWNER_VERSION
            || extension.owner != OWNER
            || extension.payload_bytes > MAX_OWNER_BYTES
        {
            return Err(Error::Format("native context owner/version".into()));
        }
        let _decode_memory = budget.reserve_memory(extension.payload_bytes.saturating_mul(8))?;
        // ConversationCandidate retains state_bytes*8 while this returned
        // bounded domain copy is used outside the short decode reservation.
        let state: NativeContextState = serde_json::from_value(extension.payload.clone())?;
        state.validate(next_revision(candidate)?)?;
        state.validate_selection(&candidate.envelope.selection)?;
        budget.check()?;
        Ok(state)
    }
    fn store_native_context(
        &self,
        candidate: &mut ConversationCandidate,
        state: NativeContextState,
        budget: &Budget,
    ) -> Result<()> {
        budget.check()?;
        state.validate(next_revision(candidate)?)?;
        state.validate_selection(&candidate.envelope.selection)?;
        let extension =
            ExtensionState::new(OWNER.into(), OWNER_VERSION, serde_json::to_value(state)?)?;
        candidate
            .envelope
            .native_extensions
            .insert(OWNER.into(), extension);
        crate::query::encoded_size(&candidate.envelope, self.image.limits.state_bytes)?;
        budget.check()
    }
    pub fn conversation_native_command(
        &self,
        candidate: &mut ConversationCandidate,
        command: NativeContextCommand,
        budget: &Budget,
    ) -> Result<NativeContextReply> {
        let state = self.conversation_native_validate(candidate, budget)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let reset = matches!(
            &command,
            NativeContextCommand::ResetTopic | NativeContextCommand::InstallModel { .. }
        );
        let quantity_mutation = matches!(
            &command,
            NativeContextCommand::Observe { .. }
                | NativeContextCommand::Scale { .. }
                | NativeContextCommand::Divide { .. }
                | NativeContextCommand::Cost { .. }
                | NativeContextCommand::ConvertTemperature { .. }
                | NativeContextCommand::ShiftTemperature { .. }
                | NativeContextCommand::TemperatureDifferenceFrom { .. }
                | NativeContextCommand::EvaluateModel { .. }
                | NativeContextCommand::InvertModel { .. }
                | NativeContextCommand::ModelSlope
                | NativeContextCommand::ModelVariable { .. }
        );
        let (state, reply) = crate::native_conversation::transition(
            candidate.revision(),
            candidate.request_id(),
            state,
            command,
            &budget,
        )?;
        if reset
            || quantity_mutation
                && reply.status == NativeContextStatus::Answered
                && matches!(state.anchor, NativeAnchor::Quantity { .. })
        {
            candidate.envelope.selection = SessionSelection::default();
        }
        self.store_native_context(candidate, state, &budget)?;
        Ok(reply)
    }
    /// Host-only provenance, separate from deserializable supplied commands.
    pub fn conversation_deliver_model(
        &self,
        candidate: &mut ConversationCandidate,
        model: RetainedFittedModel,
        identity: ProviderIdentity,
        budget: &Budget,
    ) -> Result<NativeContextReply> {
        let state = self.conversation_native_validate(candidate, budget)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let (state, reply) = crate::native_conversation::deliver_model(
            candidate.revision(),
            candidate.request_id(),
            state,
            model,
            AnchorSource::Provider { identity },
            &budget,
        )?;
        candidate.envelope.selection = SessionSelection::default();
        self.store_native_context(candidate, state, &budget)?;
        Ok(reply)
    }
    pub fn conversation_deliver_quantity(
        &self,
        candidate: &mut ConversationCandidate,
        anchor: ProviderQuantityAnchor,
        budget: &Budget,
    ) -> Result<NativeContextReply> {
        let state = self.native_context_without_selection_check(candidate, budget)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let (state, reply) = crate::native_conversation::deliver(
            candidate.revision(),
            candidate.request_id(),
            state,
            NativeAnchor::Quantity {
                value: anchor.quantity,
            },
            AnchorSource::Provider {
                identity: anchor.identity,
            },
            &budget,
        )?;
        candidate.envelope.selection = SessionSelection::default();
        self.store_native_context(candidate, state, &budget)?;
        Ok(reply)
    }
    pub fn conversation_deliver_entity(
        &self,
        candidate: &mut ConversationCandidate,
        id: &str,
        identity: ProviderIdentity,
        budget: &Budget,
    ) -> Result<NativeContextReply> {
        self.require_native_context()?;
        self.check_conversation_candidate(candidate)?;
        if candidate.envelope.selection.ids.len() != 1
            || !candidate.envelope.selection.ids.contains(id)
        {
            return Err(Error::Conflict(
                "delivered entity must reference selected singleton",
            ));
        }
        // A newly chosen selection may replace the former Entity reference. Do
        // not validate that old reference against the new candidate selection.
        let state = self.native_context_without_selection_check(candidate, budget)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let (state, reply) = crate::native_conversation::deliver(
            candidate.revision(),
            candidate.request_id(),
            state,
            NativeAnchor::Entity { id: id.into() },
            AnchorSource::Provider { identity },
            &budget,
        )?;
        self.store_native_context(candidate, state, &budget)?;
        Ok(reply)
    }
    fn native_context_without_selection_check(
        &self,
        candidate: &ConversationCandidate,
        budget: &Budget,
    ) -> Result<NativeContextState> {
        let budget = budget.restricted_to(&self.image.limits)?;
        self.require_native_context()?;
        self.check_conversation_candidate(candidate)?;
        budget.check()?;
        if candidate.envelope.oracle.is_some() {
            return Err(Error::Conflict("native context cannot adopt Oracle owners"));
        }
        let extension = candidate
            .envelope
            .native_extensions
            .get(OWNER)
            .ok_or(Error::Conflict(
                "native context unavailable; reset required",
            ))?;
        if extension.version != OWNER_VERSION
            || extension.owner != OWNER
            || extension.payload_bytes > MAX_OWNER_BYTES
        {
            return Err(Error::Format("native context owner/version".into()));
        }
        let _decode_memory = budget.reserve_memory(extension.payload_bytes.saturating_mul(8))?;
        // ConversationCandidate retains state_bytes*8 while this returned
        // bounded domain copy is used outside the short decode reservation.
        let state: NativeContextState = serde_json::from_value(extension.payload.clone())?;
        state.validate(next_revision(candidate)?)?;
        budget.check()?;
        Ok(state)
    }
    /// An explicitly executed graph/program operation may replace selection.
    /// Clear a now-stale Entity reference, preserving that operation's selected
    /// data. This is not used for a refused /query candidate or an import.
    pub fn conversation_native_reconcile_selection(
        &self,
        candidate: &mut ConversationCandidate,
        budget: &Budget,
    ) -> Result<()> {
        let mut state = self.native_context_without_selection_check(candidate, budget)?;
        if state
            .validate_selection(&candidate.envelope.selection)
            .is_err()
        {
            state.anchor = NativeAnchor::Empty;
            state.delivery = None;
            self.store_native_context(candidate, state, budget)?;
        }
        Ok(())
    }
    /// Native source lookup, with a typed singleton result. A nonunique result
    /// keeps the previous delivered anchor and selection intact.
    pub fn conversation_native_entity_query(
        &self,
        candidate: &mut ConversationCandidate,
        query: NativeEntityQuery,
        budget: &Budget,
    ) -> Result<NativeEntityReply> {
        let state = self.conversation_native_validate(candidate, budget)?;
        self.require_operation("graph.query")?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let memory = budget.reserve_memory(self.image.limits.result_bytes.saturating_mul(4))?;
        let nodes = match query {
            NativeEntityQuery::Find { name } => vec![crate::Node::Find { name }],
            NativeEntityQuery::ById { id } => vec![crate::Node::Id { id }],
            NativeEntityQuery::Relation { predicate } => {
                if !matches!(state.anchor, NativeAnchor::Entity { .. }) {
                    let context = crate::native_conversation::reply(
                        &state,
                        next_revision(candidate)?,
                        Some(NativeContextRefusal::PriorEntityUnavailable),
                    );
                    return Ok(NativeEntityReply {
                        status: context.status,
                        entity: None,
                        context,
                        evidence: None,
                        _memory: Some(memory),
                    });
                }
                vec![
                    crate::Node::Previous,
                    crate::Node::Relate {
                        input: 0,
                        predicate,
                        direction: "forward".into(),
                    },
                ]
            }
        };
        let plan = Plan {
            output: nodes.len() - 1,
            nodes,
            projection: crate::Projection::UniqueName,
        };
        let source_bytes = crate::query::encoded_size(&plan, self.image.limits.request_bytes)?;
        budget.spend(source_bytes as u64)?;
        plan.validate(&self.image.limits)?;
        let worker = self
            .image
            .acquire(&candidate.envelope.binding.tenant, &budget)?;
        let previous = Selection {
            ids: candidate.envelope.selection.ids.clone(),
            facts: candidate.envelope.selection.facts.clone(),
            attributes: candidate.envelope.selection.attributes.clone(),
        };
        let (evidence, selection) = evaluate(
            &worker,
            &self.image.identity,
            &plan,
            &previous,
            &self.image.limits,
            &budget,
        )?;
        budget.check()?;
        if selection.ids.len() != 1 {
            let context = crate::native_conversation::reply(
                &state,
                next_revision(candidate)?,
                Some(NativeContextRefusal::RelationNotUnique),
            );
            return Ok(NativeEntityReply {
                status: context.status,
                entity: None,
                context,
                evidence: Some(evidence),
                _memory: Some(memory),
            });
        }
        let id = selection.ids.iter().next().expect("singleton").clone();
        let label: String =
            worker.query_row("SELECT name FROM nodes WHERE id=?1", [&id], |row| {
                row.get(0)
            })?;
        budget.check()?;
        candidate.envelope.selection = SessionSelection {
            ids: selection.ids,
            facts: selection.facts,
            attributes: selection.attributes,
        };
        let context = self.conversation_deliver_entity(
            candidate,
            &id,
            ProviderIdentity::from_host_delivery("native:graph", &self.image.identity)?,
            &budget,
        )?;
        Ok(NativeEntityReply {
            status: context.status,
            entity: Some(NativeEntity { id, label }),
            context,
            evidence: Some(evidence),
            _memory: Some(memory),
        })
    }
}
impl ConversationReaderProposal {
    /// A checked source-ID projection, never an ID linked from reply text.
    pub fn agreed_entity_id(&self) -> Option<&str> {
        if self.language.status != crate::reader::ReaderStatus::Answered {
            return None;
        }
        let selection = self.selection.as_ref()?;
        if selection.ids.len() != 1 || self.language.readings.is_empty() {
            return None;
        }
        let id = selection.ids.iter().next()?;
        for reading in &self.language.readings {
            if reading.result.entities.len() != 1
                || &reading.result.entities[0] != id
                || reading.result.value.get("status")?.as_str()? != "unique"
                || reading.result.value.get("candidate")?.get("id")?.as_str()? != id
            {
                return None;
            }
        }
        Some(id)
    }
    /// Count projection over each admitted reading's selected source entities.
    pub fn agreed_count(&self) -> Option<u64> {
        if self.language.status != crate::reader::ReaderStatus::Answered
            || self.language.readings.is_empty()
        {
            return None;
        }
        let first = self.language.readings.first()?.result.value.as_u64()?;
        if self.language.readings.iter().all(|r| {
            r.result.value.as_u64() == Some(first) && r.result.entities.len() as u64 == first
        }) {
            Some(first)
        } else {
            None
        }
    }
}
