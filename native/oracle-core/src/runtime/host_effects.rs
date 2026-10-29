//! Trusted Rust host entry points. These methods never execute a capability and
//! are intentionally absent from the Python tenant API. Authentication, concrete
//! capability/payload admission, current consent and external containment remain
//! host responsibilities. No SQL connection or caller callback is exposed.
use super::{RequestDialect, Runtime};
use crate::effects::{
    EffectFence, EffectIntent, EffectLease, EffectOutbox, EffectRecord, EffectState, EffectSummary,
    ExpiredEffect, Reconciliation,
};
use crate::{Cancellation, Error, Result};
use rusqlite::{params, OptionalExtension, Transaction, TransactionBehavior};

/// Already-authorized host proposals, committed atomically with the originating
/// turn. Merely constructing this Rust value does not validate a capability or
/// confer authority. The runtime validates origin and generic resource bounds;
/// the authenticated host must validate each concrete capability and payload.
#[derive(Clone, Copy)]
pub struct HostEffects<'a> {
    pub outbox: &'a EffectOutbox,
    pub intents: &'a [EffectIntent],
}

impl Runtime {
    /// Evaluate a graph purely, then atomically commit reply, state and already
    /// authorized intents. A successful reply means the intents are queued; their
    /// outcomes live in the outbox. No external action runs during evaluation.
    #[allow(clippy::too_many_arguments)]
    pub fn execute_with_effects(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        plan_json: &str,
        cancellation: Cancellation,
        effects: HostEffects<'_>,
    ) -> Result<String> {
        self.execute_dialect(
            tenant,
            session,
            request,
            expected_version,
            plan_json,
            cancellation,
            RequestDialect::Graph,
            Some(effects),
        )
    }

    /// The program remains the closed data-access dialect; effect proposals are
    /// separate authenticated host input and cannot introduce program opcodes.
    #[allow(clippy::too_many_arguments)]
    pub fn execute_program_with_effects(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        program_json: &str,
        cancellation: Cancellation,
        effects: HostEffects<'_>,
    ) -> Result<String> {
        self.execute_dialect(
            tenant,
            session,
            request,
            expected_version,
            program_json,
            cancellation,
            RequestDialect::KqaProgram,
            Some(effects),
        )
    }

    fn effect_transaction<T>(
        &self,
        operation: &str,
        write: bool,
        f: impl FnOnce(&Transaction<'_>) -> Result<T>,
    ) -> Result<T> {
        self.require_operation(operation)?;
        let mut db = self.state.try_acquire()?;
        let tx = db.transaction_with_behavior(if write {
            TransactionBehavior::Immediate
        } else {
            TransactionBehavior::Deferred
        })?;
        let value = f(&tx)?;
        tx.commit()?;
        Ok(value)
    }

    // The session and its originating effect committed together. Reuse the
    // session's durable image/release binding rather than treating a tenant ID
    // or an allowed operation as permission to inherit another release's work.
    fn require_effect_origin(&self, tx: &Transaction<'_>, row: &EffectRecord) -> Result<()> {
        let matches: Option<bool> = tx
            .query_row(
                "SELECT image=?3 FROM sessions WHERE tenant=?1 AND id=?2",
                params![row.tenant, row.intent.session, self.identity()],
                |r| r.get(0),
            )
            .optional()?;
        if matches != Some(true) {
            return Err(Error::Conflict("effect origin requires release migration"));
        }
        Ok(())
    }

    fn effect_origin_row(
        &self,
        tx: &Transaction<'_>,
        outbox: &EffectOutbox,
        tenant: &str,
        id: &str,
    ) -> Result<Option<EffectRecord>> {
        let row = outbox.get(tx, tenant, id)?;
        if let Some(row) = &row {
            self.require_effect_origin(tx, row)?;
        }
        Ok(row)
    }

    fn require_effect_key_origin(
        &self,
        tx: &Transaction<'_>,
        outbox: &EffectOutbox,
        tenant: &str,
        id: &str,
    ) -> Result<()> {
        self.effect_origin_row(tx, outbox, tenant, id)?
            .ok_or(Error::Conflict("effect absent"))?;
        Ok(())
    }

    pub fn effect_get(
        &self,
        outbox: &EffectOutbox,
        tenant: &str,
        id: &str,
    ) -> Result<Option<EffectRecord>> {
        self.effect_transaction("host.effects.inspect", false, |tx| {
            self.effect_origin_row(tx, outbox, tenant, id)
        })
    }

    pub fn effect_list(
        &self,
        outbox: &EffectOutbox,
        tenant: &str,
        state: EffectState,
        after_id: Option<&str>,
        batch: usize,
    ) -> Result<Vec<EffectSummary>> {
        self.effect_transaction("host.effects.inspect", false, |tx| {
            let rows = outbox.list(tx, tenant, state, after_id, batch)?;
            for row in &rows {
                self.require_effect_key_origin(tx, outbox, tenant, &row.id)?;
            }
            Ok(rows)
        })
    }

    /// The lease is durably committed before this method returns. Only now may
    /// the host invoke its admitted capability, outside the state-store lock.
    #[allow(clippy::too_many_arguments)]
    pub fn effect_claim(
        &self,
        outbox: &EffectOutbox,
        tenant: &str,
        id: &str,
        claimant: &str,
        now_ms: i64,
        lease_ms: i64,
    ) -> Result<Option<EffectLease>> {
        self.effect_transaction("host.effects.claim", true, |tx| {
            self.effect_origin_row(tx, outbox, tenant, id)?;
            outbox.claim(tx, tenant, id, claimant, now_ms, lease_ms)
        })
    }

    #[allow(clippy::too_many_arguments)]
    pub fn effect_claim_next(
        &self,
        outbox: &EffectOutbox,
        tenant: &str,
        capability: &str,
        claimant: &str,
        now_ms: i64,
        lease_ms: i64,
    ) -> Result<Option<EffectLease>> {
        self.effect_transaction("host.effects.claim", true, |tx| {
            let lease = outbox.claim_next(tx, tenant, capability, claimant, now_ms, lease_ms)?;
            if let Some(lease) = &lease {
                self.require_effect_origin(tx, &lease.effect)?;
            }
            Ok(lease)
        })
    }

    /// Returns the replacement fence only after renewal commits. The host must
    /// stop using its older fence; renewal does not extend outside authority.
    pub fn effect_renew(
        &self,
        outbox: &EffectOutbox,
        fence: &EffectFence,
        now_ms: i64,
        lease_ms: i64,
    ) -> Result<EffectFence> {
        self.effect_transaction("host.effects.claim", true, |tx| {
            self.require_effect_key_origin(tx, outbox, fence.tenant(), fence.id())?;
            outbox.renew(tx, fence, now_ms, lease_ms)
        })
    }

    pub fn effect_complete(
        &self,
        outbox: &EffectOutbox,
        fence: &EffectFence,
        now_ms: i64,
        result: &[u8],
    ) -> Result<()> {
        self.effect_transaction("host.effects.settle", true, |tx| {
            self.require_effect_key_origin(tx, outbox, fence.tenant(), fence.id())?;
            outbox.complete(tx, fence, now_ms, result)
        })
    }

    pub fn effect_mark_uncertain(
        &self,
        outbox: &EffectOutbox,
        fence: &EffectFence,
        now_ms: i64,
        detail: &[u8],
    ) -> Result<()> {
        self.effect_transaction("host.effects.settle", true, |tx| {
            self.require_effect_key_origin(tx, outbox, fence.tenant(), fence.id())?;
            outbox.mark_uncertain(tx, fence, now_ms, detail)
        })
    }

    pub fn effect_recover_expired(
        &self,
        outbox: &EffectOutbox,
        tenant: &str,
        now_ms: i64,
        batch: usize,
    ) -> Result<Vec<ExpiredEffect>> {
        self.effect_transaction("host.effects.recover", true, |tx| {
            let rows = outbox.recover_expired(tx, tenant, now_ms, batch)?;
            for row in &rows {
                self.require_effect_key_origin(tx, outbox, tenant, &row.id)?;
            }
            Ok(rows)
        })
    }

    /// Evidence must establish the receiver's outcome, not merely that a lease
    /// expired. A NotApplied resolution must also exclude an in-flight worker.
    #[allow(clippy::too_many_arguments)]
    pub fn effect_reconcile(
        &self,
        outbox: &EffectOutbox,
        tenant: &str,
        id: &str,
        expected_generation: i64,
        resolution: Reconciliation<'_>,
        evidence: &[u8],
    ) -> Result<()> {
        self.effect_transaction("host.effects.reconcile", true, |tx| {
            self.require_effect_key_origin(tx, outbox, tenant, id)?;
            outbox.reconcile(tx, tenant, id, expected_generation, resolution, evidence)
        })
    }
}
