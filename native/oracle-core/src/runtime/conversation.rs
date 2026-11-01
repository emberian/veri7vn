//! Compiled-host conversation boundary. Evaluation runs outside SQLite ownership;
//! only a delivered candidate and its exact HTTP reply commit together. This is
//! bookkeeping for explicitly covered owners, not a snapshot of the whole Engine.
use super::*;
use crate::session::NativeSessionOwner;
use serde_json::Value;
use std::collections::BTreeMap;

/// Exact wire input and typed commands occupy separate retry identity domains.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", content = "input", rename_all = "snake_case")]
pub enum ConversationInput {
    ExactBytes(Vec<u8>),
    Typed(Value),
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ConversationRequest {
    pub endpoint: String,
    pub operation: String,
    /// None means capture the current version. Only the supplied expectation,
    /// never the subsequently observed revision, participates in retry identity.
    pub expected_version: Option<i64>,
    pub input: ConversationInput,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConversationHttpReply {
    pub status: u16,
    pub body: Vec<u8>,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct StoredHttpReply {
    format: String,
    status: u16,
    body: String,
}
#[derive(Serialize)]
struct ConversationOwnerReply<R: Serialize> {
    version: i64,
    result: R,
}

const HTTP_FORMAT: &str = "oracle_conversation_http_v1";

pub enum ConversationBegin {
    Replay(ConversationHttpReply),
    Fresh(ConversationCandidate),
}
/// Host authority may change data fields, but cannot replace the captured base,
/// request identity or binding. Commit validates the entire resulting envelope.
pub struct ConversationCandidate {
    pub envelope: SessionEnvelope,
    binding: SessionBinding,
    revision: i64,
    previous_text: Option<String>,
    request: String,
    digest: String,
    policy: SessionLimits,
    _memory: crate::budget::MemoryReservation,
}
pub struct ConversationReaderProposal {
    pub language: crate::reader::ReaderResult,
    pub(super) selection: Option<SessionSelection>,
    _memory: Option<crate::budget::MemoryReservation>,
}
impl ConversationCandidate {
    /// Install only after this reader proposal wins final route arbitration.
    pub fn apply_reader(&mut self, proposal: ConversationReaderProposal) -> Result<()> {
        if let Some(selection) = proposal.selection {
            self.envelope.selection = selection;
        }
        crate::query::encoded_size(&self.envelope, self.policy.max_bytes)?;
        Ok(())
    }
    /// True only when capture observed no persisted session row. A retained
    /// revision-zero envelope is existing state and must not be initialized as
    /// an empty Oracle conversation merely because its revision is zero.
    pub fn starts_new_session(&self) -> bool {
        self.previous_text.is_none()
    }
    pub fn revision(&self) -> i64 {
        self.revision
    }
    pub fn request_id(&self) -> &str {
        &self.request
    }
}

impl Runtime {
    /// Explicit count-policy language turn. Default policy preserves the exact
    /// legacy reader identity; supplied policy uses a distinct tagged command.
    #[allow(clippy::too_many_arguments)]
    pub fn execute_language_with_options_and_budget(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        question: &str,
        options: &crate::reader::ReaderOptions,
        budget: &Budget,
    ) -> Result<String> {
        if options.count_scope.is_none() {
            return self.execute_language_with_budget(
                tenant,
                session,
                request,
                expected_version,
                question,
                budget,
            );
        }
        self.require_operation("reader.execute")?;
        let identity = ConversationRequest {
            endpoint: "/invoke".into(),
            operation: "reader.execute".into(),
            expected_version: Some(expected_version),
            input: ConversationInput::Typed(
                serde_json::json!({"question":question,"options":options}),
            ),
        };
        let mut candidate = match self.conversation_begin_with_contract(
            tenant,
            session,
            request,
            &identity,
            "oracle_core_language_reply_v1",
            budget,
        )? {
            ConversationBegin::Replay(reply) => {
                return String::from_utf8(reply.body)
                    .map_err(|_| Error::Format("retained language reply UTF-8".into()))
            }
            ConversationBegin::Fresh(candidate) => candidate,
        };
        let reply = self.conversation_execute_with_reader_options(
            &mut candidate,
            RequestDialect::Language,
            question,
            options,
            budget,
        )?;
        let committed = self.conversation_commit(candidate, 200, reply.as_bytes(), budget)?;
        String::from_utf8(committed.body).map_err(|_| Error::Format("language reply UTF-8".into()))
    }
    /// Operator-selected adapter versions, never read from imported state.
    /// Configure before sharing this runtime; unknown retained owners refuse.
    pub fn with_oracle_extensions(mut self, versions: BTreeMap<String, u32>) -> Result<Self> {
        for (owner, version) in &versions {
            crate::session::owner_identifier(owner)?;
            if *version == 0 {
                return Err(Error::Invalid("zero Oracle owner version".into()));
            }
            if let Some(release) = &self.release {
                release.require_schema(owner, *version)?;
            }
        }
        self.oracle_extensions = versions;
        Ok(self)
    }
    fn conversation_policy(&self) -> SessionLimits {
        SessionLimits {
            max_bytes: self.image.limits.state_bytes,
            extension_versions: self.oracle_extensions.clone(),
            native_extension_versions: self.native_owner_versions(),
            ..Default::default()
        }
    }
    fn conversation_digest(
        &self,
        session: &str,
        request: &ConversationRequest,
        reply_contract: &str,
    ) -> Result<String> {
        identifier(session)?;
        if !matches!(request.endpoint.as_str(), "/query" | "/invoke")
            || request.operation.is_empty()
            || request.operation.len() > 128
            || request
                .expected_version
                .is_some_and(|v| v < 0 || v == i64::MAX)
        {
            return Err(Error::Invalid("conversation request identity".into()));
        }
        crate::session::owner_identifier(&request.operation)?;
        let size = match &request.input {
            ConversationInput::ExactBytes(bytes) => bytes.len(),
            ConversationInput::Typed(value) => {
                crate::query::encoded_size(value, self.image.limits.request_bytes)?
            }
        };
        if size > self.image.limits.request_bytes {
            return Err(Error::Limit("request bytes"));
        }
        // Old graph/program/owner identities remain unchanged in their existing
        // entrypoints. A row with any other digest conflicts, including a legacy
        // request ID; it is never overwritten or adopted as a new HTTP result.
        Ok(digest(&serde_json::to_vec(&(
            HTTP_FORMAT,
            reply_contract,
            self.identity(),
            session,
            request,
        ))?))
    }
    fn conversation_replay(
        &self,
        db: &Connection,
        tenant: &str,
        request: &str,
        expected_digest: &str,
    ) -> Result<Option<ConversationHttpReply>> {
        let bound = self
            .image
            .limits
            .result_bytes
            .checked_mul(6)
            .and_then(|n| n.checked_add(256))
            .ok_or(Error::Limit("HTTP reply accounting"))?;
        let Some(raw) = Self::replay(db, tenant, request, expected_digest, bound)? else {
            return Ok(None);
        };
        let reply: StoredHttpReply = serde_json::from_str(&raw)?;
        if reply.format != HTTP_FORMAT || !(100..=599).contains(&reply.status) {
            return Err(Error::Format("conversation HTTP reply format".into()));
        }
        if reply.body.len() > self.image.limits.result_bytes {
            return Err(Error::Limit("HTTP reply bytes"));
        }
        Ok(Some(ConversationHttpReply {
            status: reply.status,
            body: reply.body.into_bytes(),
        }))
    }
    /// Consult after a lost commit acknowledgement before marking dispatch
    /// uncertain. Completed replay precedes budget/candidate acquisition.
    pub fn conversation_completion(
        &self,
        tenant: &str,
        session: &str,
        request_id: &str,
        request: &ConversationRequest,
    ) -> Result<Option<ConversationHttpReply>> {
        identifier(tenant)?;
        identifier(request_id)?;
        let digest = self.conversation_digest(session, request, HTTP_FORMAT)?;
        let db = self.state.try_acquire()?;
        self.conversation_replay(&db, tenant, request_id, &digest)
    }
    pub fn conversation_begin(
        &self,
        tenant: &str,
        session: &str,
        request_id: &str,
        request: &ConversationRequest,
        budget: &Budget,
    ) -> Result<ConversationBegin> {
        self.conversation_begin_with_contract(
            tenant,
            session,
            request_id,
            request,
            HTTP_FORMAT,
            budget,
        )
    }
    #[allow(clippy::too_many_arguments)]
    fn conversation_begin_with_contract(
        &self,
        tenant: &str,
        session: &str,
        request_id: &str,
        request: &ConversationRequest,
        reply_contract: &str,
        budget: &Budget,
    ) -> Result<ConversationBegin> {
        identifier(tenant)?;
        identifier(request_id)?;
        let digest = self.conversation_digest(session, request, reply_contract)?;
        {
            let db = self.state.try_acquire()?;
            if let Some(reply) = self.conversation_replay(&db, tenant, request_id, &digest)? {
                return Ok(ConversationBegin::Replay(reply));
            }
        }
        let budget = budget.restricted_to(&self.image.limits)?;
        budget.check()?;
        let memory = budget.reserve_memory(self.image.limits.state_bytes.saturating_mul(8))?;
        let binding = SessionBinding {
            tenant: tenant.into(),
            session: session.into(),
            image: self.identity().into(),
        };
        let policy = self.conversation_policy();
        let (envelope, previous_text) = {
            let db = self.state.acquire(&budget)?;
            Self::require_active_namespace(&db, tenant)?;
            let stored: Option<(String, i64, Option<String>)> = db.query_row(
                "SELECT image,version,CASE WHEN length(CAST(state AS BLOB))<=?3 THEN state ELSE NULL END FROM sessions WHERE tenant=?1 AND id=?2",
                params![tenant, session, self.image.limits.state_bytes],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            ).optional()?;
            match stored {
                Some((image, _, _)) if image != self.identity() => {
                    return Err(Error::Conflict("session requires image migration"))
                }
                Some((_, version, _)) if request.expected_version.is_some_and(|v| v != version) => {
                    return Err(Error::Conflict("state version changed"))
                }
                Some((_, _, None)) => return Err(Error::Limit("retained state bytes")),
                Some((_, revision, Some(text))) => {
                    if revision < 0 || revision == i64::MAX {
                        return Err(Error::Invalid("state version".into()));
                    }
                    let schema = serde_json::from_str::<Value>(&text)?
                        .get("schema")
                        .and_then(Value::as_u64);
                    let envelope = match schema {
                        Some(1) => SessionEnvelope::migrate_relation_v1(
                            &text,
                            binding.clone(),
                            revision,
                            &policy,
                        )?,
                        Some(2) => SessionEnvelope::migrate_v2(&text, &binding, revision, &policy)?,
                        Some(3) => {
                            SessionEnvelope::recover(Some(&text), &binding, revision, &policy)?
                        }
                        _ => return Err(Error::Format("session state version".into())),
                    };
                    (envelope, Some(text))
                }
                None if request.expected_version.is_some_and(|v| v != 0) => {
                    return Err(Error::Conflict("session absent"))
                }
                None => (SessionEnvelope::new(binding.clone())?, None),
            }
        };
        self.validate_native_owners(&envelope, &budget)?;
        budget.check()?;
        let revision = envelope.revision;
        Ok(ConversationBegin::Fresh(ConversationCandidate {
            envelope,
            binding,
            revision,
            previous_text,
            request: request_id.into(),
            digest,
            policy,
            _memory: memory,
        }))
    }
    pub fn conversation_reader_proposal(
        &self,
        candidate: &ConversationCandidate,
        question: &str,
        budget: &Budget,
    ) -> Result<ConversationReaderProposal> {
        self.conversation_reader_proposal_with_options(
            candidate,
            question,
            &crate::reader::ReaderOptions::default(),
            budget,
        )
    }
    pub fn conversation_reader_proposal_with_options(
        &self,
        candidate: &ConversationCandidate,
        question: &str,
        options: &crate::reader::ReaderOptions,
        budget: &Budget,
    ) -> Result<ConversationReaderProposal> {
        self.require_operation("reader.execute")?;
        if self.image.capabilities.reader.is_none() {
            return Err(Error::Format("image has no learned reader tables".into()));
        }
        self.check_conversation_candidate(candidate)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let worker = self.image.acquire(&candidate.binding.tenant, &budget)?;
        let previous = Selection {
            ids: candidate.envelope.selection.ids.clone(),
            facts: candidate.envelope.selection.facts.clone(),
            attributes: candidate.envelope.selection.attributes.clone(),
        };
        let (language, selection) = crate::reader::evaluate_whole_with_options(
            &worker,
            &self.image.identity,
            question,
            &previous,
            &self.image.limits,
            &crate::reader::ReaderLimits::default(),
            options,
            &budget,
        )?;
        budget.check()?;
        let (selection, memory) = match selection {
            Some(selection) => {
                let bytes = crate::query::selection_retained_bytes(&selection);
                let (selection, memory) = selection.into_owned(bytes, &budget)?;
                (
                    Some(SessionSelection {
                        ids: selection.ids,
                        facts: selection.facts,
                        attributes: selection.attributes,
                    }),
                    Some(memory),
                )
            }
            None => (None, None),
        };
        Ok(ConversationReaderProposal {
            language,
            selection,
            _memory: memory,
        })
    }
    pub(super) fn check_conversation_candidate(
        &self,
        candidate: &ConversationCandidate,
    ) -> Result<()> {
        if candidate.binding.image != self.identity()
            || candidate.envelope.binding != candidate.binding
            || candidate.envelope.revision != candidate.revision
        {
            return Err(Error::Conflict("conversation candidate binding changed"));
        }
        Ok(())
    }
    /// Prepare a native graph/program/language operation without a durable write.
    /// The host must encode its final response before conversation_commit.
    pub fn conversation_execute(
        &self,
        candidate: &mut ConversationCandidate,
        dialect: RequestDialect,
        input: &str,
        budget: &Budget,
    ) -> Result<String> {
        self.conversation_execute_with_reader_options(
            candidate,
            dialect,
            input,
            &crate::reader::ReaderOptions::default(),
            budget,
        )
    }
    pub fn conversation_execute_with_reader_options(
        &self,
        candidate: &mut ConversationCandidate,
        dialect: RequestDialect,
        input: &str,
        options: &crate::reader::ReaderOptions,
        budget: &Budget,
    ) -> Result<String> {
        self.check_conversation_candidate(candidate)?;
        self.require_operation(dialect.operation(true))?;
        let budget = budget.restricted_to(&self.image.limits)?;
        if matches!(dialect, RequestDialect::Language) {
            let proposal =
                self.conversation_reader_proposal_with_options(candidate, input, options, &budget)?;
            let reply = encode(
                &LanguageExecution {
                    version: candidate.revision + 1,
                    language: proposal.language,
                },
                self.image.limits.result_bytes,
            )?;
            if let Some(selection) = proposal.selection {
                candidate.envelope.selection = selection;
            }
            crate::query::encoded_size(&candidate.envelope, candidate.policy.max_bytes)?;
            return Ok(reply);
        }
        if matches!(dialect, RequestDialect::NativeOwner) {
            return Err(Error::Invalid(
                "owner needs typed conversation operation".into(),
            ));
        }
        let plan = dialect.compile(input, &self.image.limits)?;
        let worker = self.image.acquire(&candidate.binding.tenant, &budget)?;
        let previous = Selection {
            ids: candidate.envelope.selection.ids.clone(),
            facts: candidate.envelope.selection.facts.clone(),
            attributes: candidate.envelope.selection.attributes.clone(),
        };
        let (result, selection) = evaluate(
            &worker,
            &self.image.identity,
            &plan,
            &previous,
            &self.image.limits,
            &budget,
        )?;
        budget.check()?;
        let reply = encode(
            &Execution {
                version: candidate.revision + 1,
                result,
            },
            self.image.limits.result_bytes,
        )?;
        candidate.envelope.selection = SessionSelection {
            ids: selection.ids,
            facts: selection.facts,
            attributes: selection.attributes,
        };
        crate::query::encoded_size(&candidate.envelope, candidate.policy.max_bytes)?;
        Ok(reply)
    }
    pub fn conversation_execute_owner<T: NativeSessionOwner>(
        &self,
        candidate: &mut ConversationCandidate,
        command: T::Command,
        budget: &Budget,
    ) -> Result<String> {
        self.check_conversation_candidate(candidate)?;
        self.require_native_owner::<T>()?;
        self.require_operation(T::OPERATION)?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let state = candidate
            .envelope
            .native_extensions
            .get(T::OWNER)
            .map(|extension| T::State::deserialize(&extension.payload))
            .transpose()?;
        let (state, reply) = T::transition(
            &candidate.binding,
            candidate.revision,
            &candidate.request,
            state,
            command,
            &budget,
        )?;
        T::validate_with_budget(&state, &candidate.binding, candidate.revision + 1, &budget)?;
        let payload = serde_json::to_value(state)?;
        let extension = crate::session::ExtensionState::new(T::OWNER.into(), T::VERSION, payload)?;
        let reply = encode(
            &ConversationOwnerReply {
                version: candidate.revision + 1,
                result: reply,
            },
            self.image.limits.result_bytes,
        )?;
        candidate
            .envelope
            .native_extensions
            .insert(T::OWNER.into(), extension);
        crate::query::encoded_size(&candidate.envelope, candidate.policy.max_bytes)?;
        Ok(reply)
    }
    /// Semantic refusal is still a delivered versioned turn. Preserve selection
    /// by leaving it unchanged; explicit owner clearing is the host's policy.
    pub fn conversation_commit(
        &self,
        mut candidate: ConversationCandidate,
        status: u16,
        body: &[u8],
        budget: &Budget,
    ) -> Result<ConversationHttpReply> {
        self.check_conversation_candidate(&candidate)?;
        if !(100..=599).contains(&status) {
            return Err(Error::Invalid("HTTP status".into()));
        }
        if body.len() > self.image.limits.result_bytes {
            return Err(Error::Limit("HTTP reply bytes"));
        }
        let text =
            std::str::from_utf8(body).map_err(|_| Error::Invalid("HTTP reply UTF-8".into()))?;
        let budget = budget.restricted_to(&self.image.limits)?;
        candidate.envelope.revision = candidate.revision + 1;
        let policy = self.conversation_policy();
        crate::query::encoded_size(&candidate.envelope, policy.max_bytes)?;
        candidate.envelope.validate(&policy)?;
        self.validate_native_owners(&candidate.envelope, &budget)?;
        let _encoding = budget.reserve_memory(
            self.image
                .limits
                .state_bytes
                .saturating_mul(2)
                .saturating_add(body.len().saturating_mul(8)),
        )?;
        let state = candidate.envelope.encode(&policy)?;
        let reply = serde_json::to_string(&StoredHttpReply {
            format: HTTP_FORMAT.into(),
            status,
            body: text.into(),
        })?;
        budget.check()?;
        let mut db = self.state.acquire(&budget)?;
        let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
        if let Some(reply) = self.conversation_replay(
            &tx,
            &candidate.binding.tenant,
            &candidate.request,
            &candidate.digest,
        )? {
            return Ok(reply);
        }
        Self::require_active_namespace(&tx, &candidate.binding.tenant)?;
        let current: Option<(String, i64, bool)> = tx
            .query_row(
                "SELECT image,version,state IS ?3 FROM sessions WHERE tenant=?1 AND id=?2",
                params![
                    candidate.binding.tenant,
                    candidate.binding.session,
                    candidate.previous_text
                ],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()?;
        if current
            .as_ref()
            .is_some_and(|(image, revision, unchanged)| {
                image != self.identity() || *revision != candidate.revision || !unchanged
            })
            || (current.is_none() && candidate.previous_text.is_some())
        {
            return Err(Error::Conflict(
                "state changed during conversation evaluation",
            ));
        }
        let (sessions, requests): (u64, u64) =
            tx.query_row("SELECT sessions,requests FROM counts WHERE id=1", [], |r| {
                Ok((r.get(0)?, r.get(1)?))
            })?;
        if requests >= self.image.limits.journal_entries {
            return Err(Error::Limit("request journal capacity"));
        }
        if current.is_none() && sessions >= self.image.limits.sessions {
            return Err(Error::Limit("session capacity"));
        }
        tx.execute("INSERT INTO sessions VALUES (?1,?2,?3,?4,?5) ON CONFLICT(tenant,id) DO UPDATE SET version=excluded.version,state=excluded.state",
            params![candidate.binding.tenant,candidate.binding.session,self.identity(),candidate.revision+1,state])?;
        tx.execute(
            "INSERT INTO requests VALUES (?1,?2,?3,?4)",
            params![
                candidate.binding.tenant,
                candidate.request,
                candidate.digest,
                reply
            ],
        )?;
        tx.execute(
            "UPDATE counts SET sessions=sessions+?1,requests=requests+1 WHERE id=1",
            [i64::from(current.is_none())],
        )?;
        budget.check()?;
        tx.commit()?;
        Ok(ConversationHttpReply {
            status,
            body: body.to_vec(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inner_native_and_outer_http_reply_contracts_cannot_cross_replay() {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("source.json");
        let image_path = directory.path().join("image.sqlite");
        std::fs::write(
            &source,
            serde_json::json!({"concepts":{},"entities":{
                "A":{"name":"Alice","instanceOf":[],"attributes":[],"relations":[]}
            }})
            .to_string(),
        )
        .unwrap();
        let receipt = crate::build_image(&source, &image_path, 1_000_000, 100_000).unwrap();
        let image =
            Image::open(&image_path, &receipt.image_sha256, crate::Limits::default()).unwrap();
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let runtime = Runtime::open(image, &directory.path().join("state.sqlite")).unwrap();
        let request = ConversationRequest {
            endpoint: "/invoke".into(),
            operation: "reader.execute".into(),
            expected_version: Some(0),
            input: ConversationInput::Typed(
                serde_json::json!({"question":"Alice?","options":{"count_scope":"supplied_snapshot"}}),
            ),
        };
        let ConversationBegin::Fresh(candidate) = runtime
            .conversation_begin_with_contract(
                "tenant",
                "session",
                "request",
                &request,
                "oracle_core_language_reply_v1",
                &budget,
            )
            .unwrap()
        else {
            panic!("expected fresh candidate");
        };
        runtime
            .conversation_commit(candidate, 200, b"{\"version\":1,\"language\":{}}", &budget)
            .unwrap();
        assert!(matches!(
            runtime.conversation_completion("tenant", "session", "request", &request),
            Err(Error::Conflict(_))
        ));
        // Retry under the original core-output contract still returns its exact
        // inner reply and never presents it as an outer HTTP response.
        let ConversationBegin::Replay(replayed) = runtime
            .conversation_begin_with_contract(
                "tenant",
                "session",
                "request",
                &request,
                "oracle_core_language_reply_v1",
                &budget,
            )
            .unwrap()
        else {
            panic!("expected replay");
        };
        assert_eq!(replayed.body, b"{\"version\":1,\"language\":{}}");
    }
}
