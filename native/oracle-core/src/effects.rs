//! Transaction-coupled effect intents, never an executor.
//!
//! Only authenticated host code chooses capabilities, replay policy, clocks and
//! tenants. A query cannot execute code through this module. Commit an intent in
//! the SAME transaction as its originating reply and state. Commit a claim before
//! invoking its host capability; settle it in a fresh transaction afterwards.
//!
//! Fences protect this journal, not the outside world. A receiver-deduplicated
//! capability must durably deduplicate `(tenant, id, body_digest)` itself, including
//! concurrent/late invocations. All other capabilities use AtMostOnce: an expired
//! lease becomes uncertain and is never automatically retried. Reconciliation
//! requires authoritative host evidence, including excluding an in-flight worker
//! before declaring an operation not applied. Lease expiry alone is not evidence.
//!
//! All mutations take the caller's transaction; on ANY error, roll it back.
//! Use an IMMEDIATE transaction for mutations so competing writers fail busy
//! before taking a snapshot; the runtime must also serialize its own writers. There
//! is no retention/deletion operation: exhausting capacity refuses new work and
//! preserves identity tombstones. Limits bound logical values and row count;
//! SQLite/WAL/allocator overhead additionally needs an operator disk/memory quota.
use crate::{digest, Error, Result};
use rusqlite::{params, OptionalExtension, Transaction};
use serde::{Deserialize, Serialize};

/// Install once inside the hosting state-schema migration transaction. Does not
/// change application_id, user_version, pragmas, files, processes or environment.
pub fn initialize(tx: &Transaction<'_>) -> Result<()> {
    tx.execute_batch(
        "CREATE TABLE effect_usage(
            singleton INTEGER PRIMARY KEY CHECK(singleton=1),
            entries INTEGER NOT NULL CHECK(entries>=0),
            value_bytes INTEGER NOT NULL CHECK(value_bytes>=0));
         INSERT INTO effect_usage VALUES(1,0,0);
         CREATE TABLE effect_intents(
            tenant TEXT NOT NULL, id TEXT NOT NULL,
            session TEXT NOT NULL, request TEXT NOT NULL,
            capability TEXT NOT NULL, replay TEXT NOT NULL
                CHECK(replay IN ('at_most_once','receiver_deduplicated')),
            body_digest TEXT NOT NULL CHECK(length(body_digest)=64),
            payload BLOB NOT NULL,
            state TEXT NOT NULL CHECK(state IN ('pending','leased','completed','uncertain')),
            generation INTEGER NOT NULL CHECK(generation>=0),
            claimant TEXT, lease_until_ms INTEGER,
            result BLOB, evidence BLOB NOT NULL,
            PRIMARY KEY(tenant,id),
            CHECK(length(tenant) BETWEEN 1 AND 128),
            CHECK(length(id) BETWEEN 1 AND 128),
            CHECK(length(session) BETWEEN 1 AND 128),
            CHECK(length(request) BETWEEN 1 AND 128),
            CHECK(length(capability) BETWEEN 1 AND 128),
            CHECK(claimant IS NULL OR length(claimant) BETWEEN 1 AND 128),
            CHECK(lease_until_ms IS NULL OR lease_until_ms>=0),
            CHECK((state='pending' AND claimant IS NULL AND lease_until_ms IS NULL AND result IS NULL)
               OR (state='leased' AND claimant IS NOT NULL AND lease_until_ms IS NOT NULL AND result IS NULL)
               OR (state='completed' AND result IS NOT NULL)
               OR state='uncertain')) WITHOUT ROWID;
         CREATE INDEX effect_pending ON effect_intents(tenant,capability,state,id);
         CREATE INDEX effect_expiry ON effect_intents(tenant,state,lease_until_ms,id);
         CREATE INDEX effect_state ON effect_intents(tenant,state,id);
         CREATE TRIGGER effect_insert_usage AFTER INSERT ON effect_intents BEGIN
            UPDATE effect_usage SET entries=entries+1,
                value_bytes=value_bytes+length(NEW.payload)+coalesce(length(NEW.result),0)+length(NEW.evidence)
                WHERE singleton=1;
         END;
         CREATE TRIGGER effect_update_usage AFTER UPDATE OF result,evidence ON effect_intents BEGIN
            UPDATE effect_usage SET value_bytes=value_bytes
                -coalesce(length(OLD.result),0)-length(OLD.evidence)
                +coalesce(length(NEW.result),0)+length(NEW.evidence) WHERE singleton=1;
         END;",
    )?;
    Ok(())
}

#[derive(Debug, Clone, Serialize)]
pub struct EffectLimits {
    pub entries: u64,
    pub payload_bytes: usize,
    pub result_bytes: usize,
    /// Sum of payload, result and reconciliation evidence bytes across all rows.
    pub store_value_bytes: u64,
    pub max_lease_ms: i64,
    pub recovery_batch: usize,
}
impl Default for EffectLimits {
    fn default() -> Self {
        Self {
            entries: 10_000,
            payload_bytes: 65_536,
            result_bytes: 65_536,
            store_value_bytes: 67_108_864,
            max_lease_ms: 300_000,
            recovery_batch: 256,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReplayPolicy {
    AtMostOnce,
    ReceiverDeduplicated,
}
impl ReplayPolicy {
    fn sql(self) -> &'static str {
        match self {
            Self::AtMostOnce => "at_most_once",
            Self::ReceiverDeduplicated => "receiver_deduplicated",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EffectState {
    Pending,
    Leased,
    Completed,
    Uncertain,
}

/// Host-validated typed content belongs in payload, e.g. a checked lesson recipe,
/// growth target with source/admission hashes, or a ledger entry with predecessor
/// and knowledge snapshot. Paths, commands and consent are NOT validated here.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EffectIntent {
    pub id: String,
    pub session: String,
    pub request: String,
    pub capability: String,
    pub replay: ReplayPolicy,
    pub payload: Vec<u8>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EffectRecord {
    pub tenant: String,
    pub intent: EffectIntent,
    pub body_digest: String,
    pub state: EffectState,
    pub generation: i64,
    pub claimant: Option<String>,
    pub lease_until_ms: Option<i64>,
    pub result: Option<Vec<u8>>,
    /// Last explicit reconciliation evidence, never an unbounded attempt log.
    pub evidence: Vec<u8>,
}

/// Opaque journal fence. This is not authentication or an external side-effect
/// cancellation token. Renewal replaces this fence, invalidating the old copy.
#[derive(Debug, Clone)]
pub struct EffectFence {
    tenant: String,
    id: String,
    body_digest: String,
    generation: i64,
    claimant: String,
    lease_until_ms: i64,
}
impl EffectFence {
    pub fn tenant(&self) -> &str {
        &self.tenant
    }
    pub fn id(&self) -> &str {
        &self.id
    }
    pub fn body_digest(&self) -> &str {
        &self.body_digest
    }
    pub fn generation(&self) -> i64 {
        self.generation
    }
    pub fn lease_until_ms(&self) -> i64 {
        self.lease_until_ms
    }
    fn matches(&self, row: &EffectRecord) -> bool {
        row.tenant == self.tenant
            && row.intent.id == self.id
            && row.body_digest == self.body_digest
            && row.generation == self.generation
            && row.claimant.as_deref() == Some(self.claimant.as_str())
            && row.lease_until_ms == Some(self.lease_until_ms)
    }
}

#[derive(Debug)]
pub struct EffectLease {
    pub effect: EffectRecord,
    pub fence: EffectFence,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExpiredEffect {
    pub id: String,
    pub generation: i64,
    pub state: EffectState,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EffectSummary {
    pub id: String,
    pub capability: String,
    pub body_digest: String,
    pub generation: i64,
    pub lease_until_ms: Option<i64>,
}

/// Explicit reconciliation only. NotApplied asserts the action did not happen
/// AND cannot still happen from the old worker. It permits a fresh claim.
pub enum Reconciliation<'a> {
    Applied(&'a [u8]),
    NotApplied,
}

pub struct EffectOutbox {
    limits: EffectLimits,
}

fn identifier(value: &str) -> Result<()> {
    if value.is_empty()
        || value.len() > 128
        || !value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))
    {
        return Err(Error::Invalid("effect identity or capability".into()));
    }
    Ok(())
}
fn time(now_ms: i64) -> Result<()> {
    if now_ms < 0 {
        return Err(Error::Invalid("negative effect clock".into()));
    }
    Ok(())
}

impl EffectOutbox {
    pub fn new(limits: EffectLimits) -> Result<Self> {
        if limits.entries == 0
            || limits.entries > i64::MAX as u64
            || limits.payload_bytes == 0
            || limits.payload_bytes > i32::MAX as usize
            || limits.result_bytes == 0
            || limits.result_bytes > i32::MAX as usize
            || limits.store_value_bytes == 0
            || limits.store_value_bytes > i64::MAX as u64
            || limits.max_lease_ms <= 0
            || limits.recovery_batch == 0
            || limits.recovery_batch > i32::MAX as usize
        {
            return Err(Error::Invalid("effect bounds".into()));
        }
        Ok(Self { limits })
    }

    /// Bind the actual immutable broker policy to a durable host request. This
    /// covers every configured limit, not a caller-supplied label for a profile.
    /// It is not a replacement for admitting the host's release/resource policy.
    pub fn limits_digest(&self) -> Result<String> {
        Ok(digest(&serde_json::to_vec(&(
            "oracle_effect_limits_v1",
            &self.limits,
        ))?))
    }

    fn capacity(
        &self,
        tx: &Transaction<'_>,
        new_entry: bool,
        old_bytes: u64,
        new_bytes: u64,
    ) -> Result<()> {
        let (entries, bytes): (u64, u64) = tx.query_row(
            "SELECT entries,value_bytes FROM effect_usage WHERE singleton=1",
            [],
            |r| Ok((r.get(0)?, r.get(1)?)),
        )?;
        let next_entries = entries
            .checked_add(u64::from(new_entry))
            .ok_or(Error::Limit("effect entries"))?;
        let next_bytes = bytes
            .checked_sub(old_bytes)
            .and_then(|n| n.checked_add(new_bytes))
            .ok_or(Error::Limit("effect store values"))?;
        if next_entries > self.limits.entries {
            return Err(Error::Limit("effect entries"));
        }
        if next_bytes > self.limits.store_value_bytes {
            return Err(Error::Limit("effect store values"));
        }
        Ok(())
    }
    fn result_size(&self, bytes: &[u8]) -> Result<()> {
        if bytes.len() > self.limits.result_bytes {
            return Err(Error::Limit("effect result bytes"));
        }
        Ok(())
    }

    /// Reads one exact key. SQL checks retained value lengths before copying
    /// blobs into Rust, including after reopening with tighter operator limits.
    pub fn get(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        id: &str,
    ) -> Result<Option<EffectRecord>> {
        identifier(tenant)?;
        identifier(id)?;
        let row = tx
            .query_row(
                "SELECT session,request,capability,replay,body_digest,
                CASE WHEN length(payload)<=?3 THEN payload ELSE NULL END,
                state,generation,claimant,lease_until_ms,
                CASE WHEN result IS NULL THEN 0 WHEN length(result)<=?4 THEN 1 ELSE 2 END,
                CASE WHEN length(result)<=?4 THEN result ELSE NULL END,
                CASE WHEN length(evidence)<=?4 THEN evidence ELSE NULL END
             FROM effect_intents WHERE tenant=?1 AND id=?2",
                params![
                    tenant,
                    id,
                    self.limits.payload_bytes,
                    self.limits.result_bytes
                ],
                |r| {
                    Ok((
                        r.get::<_, String>(0)?,
                        r.get::<_, String>(1)?,
                        r.get::<_, String>(2)?,
                        r.get::<_, String>(3)?,
                        r.get::<_, String>(4)?,
                        r.get::<_, Option<Vec<u8>>>(5)?,
                        r.get::<_, String>(6)?,
                        r.get::<_, i64>(7)?,
                        r.get::<_, Option<String>>(8)?,
                        r.get::<_, Option<i64>>(9)?,
                        r.get::<_, i64>(10)?,
                        r.get::<_, Option<Vec<u8>>>(11)?,
                        r.get::<_, Option<Vec<u8>>>(12)?,
                    ))
                },
            )
            .optional()?;
        let Some((
            session,
            request,
            capability,
            replay,
            body_digest,
            payload,
            state,
            generation,
            claimant,
            lease_until_ms,
            result_kind,
            result,
            evidence,
        )) = row
        else {
            return Ok(None);
        };
        let payload = payload.ok_or(Error::Limit("retained effect payload bytes"))?;
        let evidence = evidence.ok_or(Error::Limit("retained effect evidence bytes"))?;
        if result_kind == 2 {
            return Err(Error::Limit("retained effect result bytes"));
        }
        let replay = match replay.as_str() {
            "at_most_once" => ReplayPolicy::AtMostOnce,
            "receiver_deduplicated" => ReplayPolicy::ReceiverDeduplicated,
            _ => return Err(Error::Format("effect replay policy".into())),
        };
        let state = match state.as_str() {
            "pending" => EffectState::Pending,
            "leased" => EffectState::Leased,
            "completed" => EffectState::Completed,
            "uncertain" => EffectState::Uncertain,
            _ => return Err(Error::Format("effect state".into())),
        };
        Ok(Some(EffectRecord {
            tenant: tenant.into(),
            intent: EffectIntent {
                id: id.into(),
                session,
                request,
                capability,
                replay,
                payload,
            },
            body_digest,
            state,
            generation,
            claimant,
            lease_until_ms,
            result,
            evidence,
        }))
    }

    /// Bounded keyset inspection, including uncertain work after restart. The
    /// caller retains the last returned id as its cursor; rows may change state
    /// between pages, so this is operational inspection, not snapshot coverage.
    pub fn list(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        state: EffectState,
        after_id: Option<&str>,
        batch: usize,
    ) -> Result<Vec<EffectSummary>> {
        identifier(tenant)?;
        if let Some(id) = after_id {
            identifier(id)?;
        }
        if batch == 0 || batch > self.limits.recovery_batch {
            return Err(Error::Invalid("effect inspection batch".into()));
        }
        let state = match state {
            EffectState::Pending => "pending",
            EffectState::Leased => "leased",
            EffectState::Completed => "completed",
            EffectState::Uncertain => "uncertain",
        };
        let mut stmt = tx.prepare(
            "SELECT id,capability,body_digest,generation,lease_until_ms FROM effect_intents
            WHERE tenant=?1 AND state=?2 AND id>?3 ORDER BY id LIMIT ?4",
        )?;
        let rows = stmt
            .query_map(params![tenant, state, after_id.unwrap_or(""), batch], |r| {
                Ok(EffectSummary {
                    id: r.get(0)?,
                    capability: r.get(1)?,
                    body_digest: r.get(2)?,
                    generation: r.get(3)?,
                    lease_until_ms: r.get(4)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// Reusing an identity with exact content returns its durable current state.
    /// Every field, including replay policy and origin, binds the SHA256 digest.
    pub fn enqueue(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        intent: &EffectIntent,
    ) -> Result<EffectRecord> {
        for value in [
            tenant,
            &intent.id,
            &intent.session,
            &intent.request,
            &intent.capability,
        ] {
            identifier(value)?;
        }
        if intent.payload.len() > self.limits.payload_bytes {
            return Err(Error::Limit("effect payload bytes"));
        }
        let body_digest = digest(&serde_json::to_vec(&(
            "oracle_effect_intent_v1",
            tenant,
            intent,
        ))?);
        if let Some(row) = self.get(tx, tenant, &intent.id)? {
            if row.body_digest != body_digest {
                return Err(Error::Conflict("effect ID reused with changed intent"));
            }
            return Ok(row);
        }
        self.capacity(tx, true, 0, intent.payload.len() as u64)?;
        tx.execute("INSERT INTO effect_intents VALUES(?1,?2,?3,?4,?5,?6,?7,?8,'pending',0,NULL,NULL,NULL,X'')",
            params![tenant,intent.id,intent.session,intent.request,intent.capability,intent.replay.sql(),body_digest,intent.payload])?;
        self.get(tx, tenant, &intent.id)?
            .ok_or(Error::Conflict("effect disappeared"))
    }

    /// An indexed, single-row dispatch lookup; no full-store scan or queue copy.
    /// Host chooses which tenant/capability to schedule and supplies fairness.
    pub fn claim_next(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        capability: &str,
        claimant: &str,
        now_ms: i64,
        lease_ms: i64,
    ) -> Result<Option<EffectLease>> {
        identifier(tenant)?;
        identifier(capability)?;
        identifier(claimant)?;
        self.deadline(now_ms, lease_ms)?;
        let id: Option<String> = tx.query_row(
            "SELECT id FROM effect_intents WHERE tenant=?1 AND capability=?2 AND state='pending' ORDER BY id LIMIT 1",
            params![tenant,capability], |r| r.get(0)).optional()?;
        match id {
            Some(id) => self.claim(tx, tenant, &id, claimant, now_ms, lease_ms),
            None => Ok(None),
        }
    }
    fn deadline(&self, now_ms: i64, lease_ms: i64) -> Result<i64> {
        time(now_ms)?;
        if lease_ms <= 0 || lease_ms > self.limits.max_lease_ms {
            return Err(Error::Invalid("effect lease duration".into()));
        }
        now_ms
            .checked_add(lease_ms)
            .ok_or(Error::Invalid("effect lease clock overflow".into()))
    }

    /// Commit the returned lease before invoking the external action. The host
    /// clock must be trustworthy across restarts; equality to deadline is expired.
    pub fn claim(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        id: &str,
        claimant: &str,
        now_ms: i64,
        lease_ms: i64,
    ) -> Result<Option<EffectLease>> {
        identifier(claimant)?;
        let deadline = self.deadline(now_ms, lease_ms)?;
        let Some(mut row) = self.get(tx, tenant, id)? else {
            return Ok(None);
        };
        if row.state != EffectState::Pending {
            return Ok(None);
        }
        let generation = row
            .generation
            .checked_add(1)
            .ok_or(Error::Limit("effect generation"))?;
        let changed = tx.execute(
            "UPDATE effect_intents SET state='leased',generation=?3,claimant=?4,lease_until_ms=?5
            WHERE tenant=?1 AND id=?2 AND state='pending' AND generation=?6",
            params![tenant, id, generation, claimant, deadline, row.generation],
        )?;
        if changed != 1 {
            return Err(Error::Conflict("effect claim changed"));
        }
        row.state = EffectState::Leased;
        row.generation = generation;
        row.claimant = Some(claimant.into());
        row.lease_until_ms = Some(deadline);
        let fence = EffectFence {
            tenant: tenant.into(),
            id: id.into(),
            body_digest: row.body_digest.clone(),
            generation,
            claimant: claimant.into(),
            lease_until_ms: deadline,
        };
        Ok(Some(EffectLease { effect: row, fence }))
    }
    fn active(
        &self,
        tx: &Transaction<'_>,
        fence: &EffectFence,
        now_ms: i64,
    ) -> Result<EffectRecord> {
        time(now_ms)?;
        let row = self
            .get(tx, &fence.tenant, &fence.id)?
            .ok_or(Error::Conflict("effect absent"))?;
        if !fence.matches(&row)
            || row.state != EffectState::Leased
            || now_ms >= fence.lease_until_ms
        {
            return Err(Error::Conflict("stale or expired effect fence"));
        }
        Ok(row)
    }

    pub fn renew(
        &self,
        tx: &Transaction<'_>,
        fence: &EffectFence,
        now_ms: i64,
        lease_ms: i64,
    ) -> Result<EffectFence> {
        self.active(tx, fence, now_ms)?;
        let deadline = self.deadline(now_ms, lease_ms)?;
        if deadline <= fence.lease_until_ms {
            return Err(Error::Invalid("renewal must extend effect lease".into()));
        }
        tx.execute(
            "UPDATE effect_intents SET lease_until_ms=?3 WHERE tenant=?1 AND id=?2",
            params![fence.tenant, fence.id, deadline],
        )?;
        let mut next = fence.clone();
        next.lease_until_ms = deadline;
        Ok(next)
    }

    /// A duplicate completion is accepted only for the same fence and exact
    /// result bytes. No re-execution is needed if the commit acknowledgement died.
    pub fn complete(
        &self,
        tx: &Transaction<'_>,
        fence: &EffectFence,
        now_ms: i64,
        result: &[u8],
    ) -> Result<()> {
        time(now_ms)?;
        self.result_size(result)?;
        let row = self
            .get(tx, &fence.tenant, &fence.id)?
            .ok_or(Error::Conflict("effect absent"))?;
        if row.state == EffectState::Completed && fence.matches(&row) {
            return if row.result.as_deref() == Some(result) {
                Ok(())
            } else {
                Err(Error::Conflict("effect completed with a different result"))
            };
        }
        self.active(tx, fence, now_ms)?;
        self.capacity(tx, false, 0, result.len() as u64)?;
        tx.execute(
            "UPDATE effect_intents SET state='completed',result=?3 WHERE tenant=?1 AND id=?2",
            params![fence.tenant, fence.id, result],
        )?;
        Ok(())
    }

    /// Use for timeout/disconnection after a possible external action. Even a
    /// deduplicated receiver is held for explicit reconciliation in this case.
    pub fn mark_uncertain(
        &self,
        tx: &Transaction<'_>,
        fence: &EffectFence,
        now_ms: i64,
        detail: &[u8],
    ) -> Result<()> {
        self.result_size(detail)?;
        self.active(tx, fence, now_ms)?;
        self.capacity(tx, false, 0, detail.len() as u64)?;
        tx.execute(
            "UPDATE effect_intents SET state='uncertain',result=?3 WHERE tenant=?1 AND id=?2",
            params![fence.tenant, fence.id, detail],
        )?;
        Ok(())
    }

    /// Bounded indexed recovery. Never infers success or failure from a crash.
    /// Only receivers with a host-approved durable dedup contract return pending.
    pub fn recover_expired(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        now_ms: i64,
        batch: usize,
    ) -> Result<Vec<ExpiredEffect>> {
        identifier(tenant)?;
        time(now_ms)?;
        if batch == 0 || batch > self.limits.recovery_batch {
            return Err(Error::Invalid("effect recovery batch".into()));
        }
        let mut stmt=tx.prepare("SELECT id,generation,replay FROM effect_intents
            WHERE tenant=?1 AND state='leased' AND lease_until_ms<=?2 ORDER BY lease_until_ms,id LIMIT ?3")?;
        let rows = stmt
            .query_map(params![tenant, now_ms, batch], |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, i64>(1)?,
                    r.get::<_, String>(2)?,
                ))
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        drop(stmt);
        let mut changed = Vec::with_capacity(rows.len());
        for (id, generation, replay) in rows {
            let retry = replay == "receiver_deduplicated";
            tx.execute("UPDATE effect_intents SET state=?3,claimant=CASE WHEN ?4 THEN NULL ELSE claimant END,
                lease_until_ms=CASE WHEN ?4 THEN NULL ELSE lease_until_ms END WHERE tenant=?1 AND id=?2",
                params![tenant,id,if retry { "pending" } else { "uncertain" },retry])?;
            changed.push(ExpiredEffect {
                id,
                generation,
                state: if retry {
                    EffectState::Pending
                } else {
                    EffectState::Uncertain
                },
            });
        }
        Ok(changed)
    }

    /// Caller supplies fresh authoritative evidence, not a lease-expiry guess.
    /// A generation check rejects a reconciliation based on an obsolete reading.
    pub fn reconcile(
        &self,
        tx: &Transaction<'_>,
        tenant: &str,
        id: &str,
        expected_generation: i64,
        resolution: Reconciliation<'_>,
        evidence: &[u8],
    ) -> Result<()> {
        if evidence.is_empty() {
            return Err(Error::Invalid(
                "effect reconciliation needs evidence".into(),
            ));
        }
        self.result_size(evidence)?;
        let row = self
            .get(tx, tenant, id)?
            .ok_or(Error::Conflict("effect absent"))?;
        if row.state != EffectState::Uncertain || row.generation != expected_generation {
            return Err(Error::Conflict("effect reconciliation state changed"));
        }
        let generation = row
            .generation
            .checked_add(1)
            .ok_or(Error::Limit("effect generation"))?;
        let result = match resolution {
            Reconciliation::Applied(value) => {
                self.result_size(value)?;
                Some(value)
            }
            Reconciliation::NotApplied => None,
        };
        let old = row.result.as_ref().map_or(0, Vec::len) + row.evidence.len();
        let new = result.map_or(0, <[u8]>::len) + evidence.len();
        self.capacity(tx, false, old as u64, new as u64)?;
        tx.execute("UPDATE effect_intents SET state=?3,generation=?4,result=?5,evidence=?6,claimant=NULL,lease_until_ms=NULL
            WHERE tenant=?1 AND id=?2", params![tenant,id,if result.is_some() { "completed" } else { "pending" },generation,result,evidence])?;
        Ok(())
    }
}
