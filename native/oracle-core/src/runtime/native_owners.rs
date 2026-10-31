//! Typed owners over the existing durable session/reply transaction.
use super::*;
use crate::session::{ExtensionState, NativeOwnerSnapshot, NativeSessionOwner};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub(super) struct OwnerPolicy {
    version: u32,
    validate: fn(&serde_json::Value, &SessionBinding, i64) -> Result<()>,
}
type EvaluateOwner<'a> = dyn Fn(&SessionEnvelope, &Budget) -> Result<(ExtensionState, String)> + 'a;
pub(super) struct OwnerEvaluation<'a> {
    pub operation: &'static str,
    pub owner: &'static str,
    pub version: u32,
    pub evaluate: &'a EvaluateOwner<'a>,
}

#[derive(Serialize)]
struct OwnerReply<R: Serialize> {
    version: i64,
    result: R,
}

fn validate<T: NativeSessionOwner>(
    payload: &serde_json::Value,
    binding: &SessionBinding,
    revision: i64,
) -> Result<()> {
    let state = T::State::deserialize(payload)?;
    T::validate(&state, binding, revision)
}

impl Runtime {
    /// Only compiled hosting code can register a type; retained JSON cannot.
    /// Call before sharing Runtime through Arc. Registration does not admit an
    /// operation: a serving release must also declare its owner schema and route.
    pub fn register_native_owner<T: NativeSessionOwner>(mut self) -> Result<Self> {
        crate::session::owner_identifier(T::OWNER)?;
        crate::session::owner_identifier(T::OPERATION)?;
        if T::VERSION == 0 || self.native_owners.contains_key(T::OWNER) {
            return Err(Error::Format(
                "duplicate native owner or zero version".into(),
            ));
        }
        if self.native_owners.len() >= 64 {
            return Err(Error::Limit("native owner registrations"));
        }
        self.native_owners.insert(
            T::OWNER.into(),
            OwnerPolicy {
                version: T::VERSION,
                validate: validate::<T>,
            },
        );
        Ok(self)
    }

    pub(super) fn native_owner_versions(&self) -> BTreeMap<String, u32> {
        self.native_owners
            .iter()
            .map(|(name, policy)| (name.clone(), policy.version))
            .collect()
    }

    fn require_native_owner<T: NativeSessionOwner>(&self) -> Result<()> {
        if self
            .native_owners
            .get(T::OWNER)
            .map(|policy| policy.version)
            != Some(T::VERSION)
        {
            return Err(Error::Format("unregistered native owner".into()));
        }
        if let Some(release) = &self.release {
            release.require_schema(T::OWNER, T::VERSION)?;
        }
        Ok(())
    }

    pub(super) fn validate_native_owners(
        &self,
        envelope: &SessionEnvelope,
        budget: &Budget,
    ) -> Result<()> {
        for (owner, state) in &envelope.native_extensions {
            budget.spend(1 + state.payload_bytes as u64)?;
            let _memory = budget.reserve_memory(state.payload_bytes.saturating_mul(8))?;
            let policy = self
                .native_owners
                .get(owner)
                .ok_or_else(|| Error::Format("unregistered retained native owner".into()))?;
            if policy.version != state.version {
                return Err(Error::Format("native owner version".into()));
            }
            if let Some(release) = &self.release {
                release.require_schema(owner, state.version)?;
            }
            (policy.validate)(&state.payload, &envelope.binding, envelope.revision)?;
        }
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    pub fn execute_native_owner_with_budget<T: NativeSessionOwner>(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        input_json: &str,
        budget: &Budget,
    ) -> Result<String> {
        if input_json.len() > self.image.limits.request_bytes {
            return Err(Error::Limit("request bytes"));
        }
        let command = serde_json::from_str(input_json)?;
        self.execute_native_owner_typed_with_budget::<T>(
            tenant,
            session,
            request,
            expected_version,
            command,
            budget,
        )
    }

    /// Host parses structured input once. Core derives canonical journal identity
    /// from this exact typed command, without parsing it back into domain data.
    #[allow(clippy::too_many_arguments)]
    pub fn execute_native_owner_typed_with_budget<T: NativeSessionOwner>(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        command: T::Command,
        budget: &Budget,
    ) -> Result<String> {
        self.require_native_owner::<T>()?;
        let budget = budget.restricted_to(&self.image.limits)?;
        let request_identity = encode(&command, self.image.limits.request_bytes)?;
        // Initialized only after completed replay has been checked. It outlives
        // closure output, envelope insertion, encoding and the atomic commit.
        let owner_memory = std::cell::RefCell::new(None);
        let command = std::cell::RefCell::new(Some(command));
        let evaluate = |envelope: &SessionEnvelope, budget: &Budget| {
            *owner_memory.borrow_mut() =
                Some(budget.reserve_memory(self.image.limits.state_bytes.saturating_mul(8))?);
            // JSON admission is confined to the durable owner/input boundary.
            let state = envelope
                .native_extensions
                .get(T::OWNER)
                .map(|extension| T::State::deserialize(&extension.payload))
                .transpose()?;
            let command = command
                .borrow_mut()
                .take()
                .ok_or_else(|| Error::Invalid("native owner evaluated twice".into()))?;
            let (state, reply) = T::transition(
                &envelope.binding,
                expected_version,
                request,
                state,
                command,
                budget,
            )?;
            budget.check()?;
            T::validate(&state, &envelope.binding, expected_version + 1)?;
            let payload = serde_json::to_value(state)?;
            let extension = ExtensionState::new(T::OWNER.into(), T::VERSION, payload)?;
            if extension.payload_bytes > SessionLimits::default().max_extension_bytes {
                return Err(Error::Limit("native owner bytes"));
            }
            let reply = encode(
                &OwnerReply {
                    version: expected_version + 1,
                    result: reply,
                },
                self.image.limits.result_bytes,
            )?;
            Ok((extension, reply))
        };
        self.execute_dialect_budget_owner(
            tenant,
            session,
            request,
            expected_version,
            &request_identity,
            budget.execution_context().cancellation().clone(),
            RequestDialect::NativeOwner,
            None,
            Some(&budget),
            Some(OwnerEvaluation {
                operation: T::OPERATION,
                owner: T::OWNER,
                version: T::VERSION,
                evaluate: &evaluate,
            }),
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn execute_context_typed_with_budget(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        command: crate::context_delta::ContextCommand,
        budget: &Budget,
    ) -> Result<String> {
        self.execute_native_owner_typed_with_budget::<crate::context_delta::ScalarOwner>(
            tenant,
            session,
            request,
            expected_version,
            command,
            budget,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn execute_context_with_budget(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        command_json: &str,
        budget: &Budget,
    ) -> Result<String> {
        self.execute_native_owner_with_budget::<crate::context_delta::ScalarOwner>(
            tenant,
            session,
            request,
            expected_version,
            command_json,
            budget,
        )
    }

    pub fn execute_context(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        command_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        let budget = Budget::new(&self.image.limits, cancellation)?;
        self.execute_context_with_budget(
            tenant,
            session,
            request,
            expected_version,
            command_json,
            &budget,
        )
    }

    /// Checked immutable snapshot. A subsequent revision cannot change this
    /// result; solving may return a receipt for this version, never for 'latest'.
    pub fn read_native_owner_with_budget<T: NativeSessionOwner>(
        &self,
        tenant: &str,
        session: &str,
        expected_version: i64,
        budget: &Budget,
    ) -> Result<NativeOwnerSnapshot<T>> {
        self.require_native_owner::<T>()?;
        identifier(tenant)?;
        identifier(session)?;
        if expected_version < 0 {
            return Err(Error::Invalid("state version".into()));
        }
        let budget = budget.restricted_to(&self.image.limits)?;
        budget.check()?;
        let memory = budget.reserve_memory(self.image.limits.state_bytes.saturating_mul(8))?;
        let binding = SessionBinding {
            tenant: tenant.into(),
            session: session.into(),
            image: self.identity().into(),
        };
        let policy = SessionLimits {
            max_bytes: self.image.limits.state_bytes,
            native_extension_versions: self.native_owner_versions(),
            ..SessionLimits::default()
        };
        let envelope = {
            let db = self.state.acquire(&budget)?;
            Self::require_active_namespace(&db, tenant)?;
            let stored: Option<(String, i64, Option<String>)> = db.query_row(
                "SELECT image,version,CASE WHEN length(CAST(state AS BLOB))<=?3 THEN state ELSE NULL END FROM sessions WHERE tenant=?1 AND id=?2",
                params![tenant, session, self.image.limits.state_bytes], |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?))).optional()?;
            match stored {
                None if expected_version == 0 => SessionEnvelope::new(binding.clone())?,
                None => return Err(Error::Conflict("session absent")),
                Some((image, revision, Some(text)))
                    if image == self.identity() && revision == expected_version =>
                {
                    match serde_json::from_str::<serde_json::Value>(&text)?
                        .get("schema")
                        .and_then(|value| value.as_u64())
                    {
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
                    }
                }
                Some((_, _, None)) => return Err(Error::Limit("retained state bytes")),
                _ => return Err(Error::Conflict("snapshot identity or revision changed")),
            }
        };
        self.validate_native_owners(&envelope, &budget)?;
        let state = envelope
            .native_extensions
            .get(T::OWNER)
            .map(|value| T::State::deserialize(&value.payload))
            .transpose()?;
        budget.check()?;
        Ok(NativeOwnerSnapshot {
            binding,
            revision: envelope.revision,
            state,
            _memory: memory,
        })
    }

    pub fn relation_coverage(
        &self,
        tenant: &str,
        request: crate::coverage::CoverageRequest,
        cancellation: Cancellation,
    ) -> Result<crate::coverage::CoveredRelations> {
        self.require_operation("graph.coverage")?;
        self.image.relation_coverage(tenant, request, cancellation)
    }

    pub fn relation_coverage_with_budget(
        &self,
        tenant: &str,
        request: crate::coverage::CoverageRequest,
        budget: &Budget,
    ) -> Result<crate::coverage::CoveredRelations> {
        self.require_operation("graph.coverage")?;
        self.image
            .relation_coverage_with_budget(tenant, request, budget)
    }
}
