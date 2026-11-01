//! Host-owned revisable evidence. No persistence, authority, or retained solver.
//! Hosts authenticate ScopeKey, bound serialized size, and atomically persist the
//! returned workspace with their existing session/journal transaction.
use crate::{hosted, Error, Limits, Operation, Request, Rule, Scope};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

pub const OWNER: &str = "oracle.logic.revisions";
pub const VERSION: u32 = 1;
pub const DEFAULT_MAX_RECORDS: usize = 128;
pub const DEFAULT_MAX_BYTES: usize = 256 * 1024;

/// Explicit retention dimensions for revisable evidence workspaces.
/// Separates active records, historical IDs (including withdrawn records),
/// revision history length, retained retry payloads, and serialized byte size.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RetentionPolicy {
    pub max_active_records: usize,
    pub max_historical_ids: usize,
    pub max_revisions: usize,
    pub max_retained_retries: usize,
    pub max_bytes: usize,
}

impl Default for RetentionPolicy {
    fn default() -> Self {
        Self::uniform(DEFAULT_MAX_RECORDS)
    }
}

impl RetentionPolicy {
    pub const fn uniform(max_records: usize) -> Self {
        Self {
            max_active_records: max_records,
            max_historical_ids: max_records,
            max_revisions: max_records,
            max_retained_retries: max_records,
            max_bytes: DEFAULT_MAX_BYTES,
        }
    }

    /// Compatibility with the original count-only API and its durable v1 events.
    /// Callers opt into a serialized-byte bound with `uniform` or explicit fields.
    pub const fn legacy(max_records: usize) -> Self {
        Self {
            max_bytes: usize::MAX,
            ..Self::uniform(max_records)
        }
    }

    pub fn validate(&self) -> Result<(), Error> {
        if self.max_historical_ids < self.max_active_records || self.max_bytes == 0 {
            return Err(Error::Invalid("invalid workspace retention policy"));
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
pub struct RetentionMetrics {
    pub active_records: usize,
    pub historical_ids: usize,
    pub revisions: usize,
    pub retained_retries: usize,
    pub retired_tokens: usize,
    /// Exact serialized StoredWorkspace bytes, including JSON escaping and framing.
    /// This is not an estimate of the derived maps or process memory.
    pub estimated_bytes: usize,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScopeKey {
    pub tenant: String,
    pub workspace: String,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Observation {
    pub id: String,
    /// Source identity is local to the authenticated tenant and workspace.
    pub source: String,
    pub source_revision: String,
    /// Signed observations use different stable atom names; contradictions are
    /// retained rather than silently resolved by source precedence.
    pub atom: String,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
/// Caller-declared closure of a supplied source domain. This is NOT a checked
/// source EOF/traversal handle and establishes no external-world completeness.
pub struct Coverage {
    pub id: String,
    pub source: String,
    pub source_revision: String,
    pub domain: String,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PolicyRule {
    pub id: String,
    pub head: Option<String>,
    pub positive: Vec<String>,
    pub negative: Vec<String>,
    /// Explicit source-domain coverage required to activate an absence rule.
    /// These IDs remain part of its justification, not positive atom edges.
    pub coverage: Vec<String>,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Insert {
    Observation(Observation),
    Coverage(Coverage),
    Rule(PolicyRule),
}
impl Insert {
    fn id(&self) -> &str {
        match self {
            Self::Observation(x) => &x.id,
            Self::Coverage(x) => &x.id,
            Self::Rule(x) => &x.id,
        }
    }
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Revision {
    pub token: String,
    pub expected_revision: u64,
    pub insert: Vec<Insert>,
    pub withdraw: Vec<String>,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Commit {
    pub revision: u64,
    pub snapshot_identity: String,
}
/// Receipt for the requested current state, not stored historical snapshots,
/// compaction, or authority to import client-supplied derived state.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Checkpoint {
    pub scope: ScopeKey,
    pub revision: u64,
    pub snapshot_identity: String,
    pub active_record_ids: Vec<String>,
    pub coverage_ids: Vec<String>,
}
#[derive(Clone, Debug, Serialize)]
pub struct Snapshot {
    scope: ScopeKey,
    revision: u64,
    records: BTreeMap<String, Insert>,
    active: BTreeSet<String>,
}
fn hash<T: Serialize>(x: &T) -> String {
    Sha256::digest(serde_json::to_vec(x).expect("typed JSON serialization"))
        .iter()
        .map(|x| format!("{x:02x}"))
        .collect()
}
impl Snapshot {
    pub fn checkpoint(&self) -> Checkpoint {
        Checkpoint {
            scope: self.scope.clone(),
            revision: self.revision,
            snapshot_identity: self.identity(),
            active_record_ids: self.active.iter().cloned().collect(),
            coverage_ids: self
                .active()
                .filter_map(|record| match record {
                    Insert::Coverage(coverage) => Some(coverage.id.clone()),
                    _ => None,
                })
                .collect(),
        }
    }
    pub fn revision(&self) -> u64 {
        self.revision
    }
    pub fn identity(&self) -> String {
        hash(self)
    }
    pub fn scope(&self) -> &ScopeKey {
        &self.scope
    }
    pub fn active(&self) -> impl Iterator<Item = &Insert> {
        self.active.iter().map(|id| &self.records[id])
    }
    /// Compile a complete supplied local program. Missing coverage disables a
    /// guarded rule; it does not establish that the external world is empty.
    pub fn prepare(&self, queries: Vec<String>, limits: &Limits) -> Result<Prepared, Error> {
        let mut atoms: BTreeSet<String> = queries.iter().cloned().collect();
        let mut covered = BTreeSet::new();
        for x in self.active() {
            if let Insert::Coverage(c) = x {
                covered.insert(c.id.clone());
            }
        }
        let enabled: Vec<_> = self
            .active()
            .filter(|x| match x {
                Insert::Rule(r) => r.coverage.iter().all(|id| covered.contains(id)),
                _ => true,
            })
            .collect();
        for x in &enabled {
            match x {
                Insert::Observation(o) => {
                    atoms.insert(o.atom.clone());
                }
                Insert::Rule(r) => {
                    atoms.extend(r.head.iter().chain(&r.positive).chain(&r.negative).cloned());
                }
                _ => {}
            }
        }
        let atoms: Vec<_> = atoms.into_iter().collect();
        let index: BTreeMap<_, _> = atoms
            .iter()
            .enumerate()
            .map(|(i, a)| (a.clone(), i))
            .collect();
        let mut rules = Vec::new();
        let mut supports = Vec::new();
        for x in enabled {
            match x {
                Insert::Observation(o) => {
                    rules.push(Rule {
                        head: Some(index[&o.atom]),
                        positive: vec![],
                        negative: vec![],
                    });
                    supports.push(Justification {
                        record: o.id.clone(),
                        head: Some(o.atom.clone()),
                        conjunction: vec![],
                        absent: vec![],
                        coverage: vec![],
                    });
                }
                Insert::Rule(r) => {
                    rules.push(Rule {
                        head: r.head.as_ref().map(|a| index[a]),
                        positive: r.positive.iter().map(|a| index[a]).collect(),
                        negative: r.negative.iter().map(|a| index[a]).collect(),
                    });
                    supports.push(Justification {
                        record: r.id.clone(),
                        head: r.head.clone(),
                        conjunction: r.positive.clone(),
                        absent: r.negative.clone(),
                        coverage: r.coverage.clone(),
                    });
                }
                _ => {}
            }
        }
        let request = Request {
            operation: Operation::Query,
            scope: Scope {
                tenant: self.scope.tenant.clone(),
                snapshot: self.identity(),
                complete_program: true,
            },
            queries: queries.iter().map(|a| index[a]).collect(),
            atoms,
            rules,
        };
        crate::validate(&request, limits)?;
        let receipt = Receipt {
            scope: self.scope.clone(),
            revision: self.revision,
            snapshot_identity: self.identity(),
            program_identity: hosted::program_identity(&request),
            request_identity: hosted::request_identity(&request)?,
            compiler: "oracle.logic.revisions/1".into(),
        };
        Ok(Prepared {
            request,
            receipt,
            supports,
        })
    }
}
/// Each entry is an AND body; entries with equal heads are OR alternatives.
/// These are local rule explanations, never causal proofs or reachability.
#[derive(Clone, Debug, Serialize)]
pub struct Justification {
    pub record: String,
    pub head: Option<String>,
    pub conjunction: Vec<String>,
    pub absent: Vec<String>,
    pub coverage: Vec<String>,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Receipt {
    pub scope: ScopeKey,
    pub revision: u64,
    pub snapshot_identity: String,
    pub program_identity: String,
    pub request_identity: String,
    pub compiler: String,
}
pub struct Prepared {
    request: Request,
    receipt: Receipt,
    supports: Vec<Justification>,
}
pub struct Evaluated {
    pub receipt: Receipt,
    pub reply: crate::Reply,
}
impl Prepared {
    pub fn supports(&self) -> &[Justification] {
        &self.supports
    }
    pub fn request(&self) -> &Request {
        &self.request
    }
    pub fn receipt(&self) -> &Receipt {
        &self.receipt
    }
    /// Solve only after the host has durably committed evidence. A failed solve
    /// changes no ledger state. Return receipt alongside the solver result.
    pub fn evaluate(
        &self,
        solver: &std::path::Path,
        limits: &Limits,
        control: &dyn oracle_execution::WorkControl,
    ) -> Result<Evaluated, Error> {
        Ok(Evaluated {
            receipt: self.receipt.clone(),
            reply: crate::process::execute(&self.request, solver, limits, control)?,
        })
    }
}
#[derive(Clone, Debug)]
pub struct Workspace {
    initial: ScopeKey,
    history: Vec<Revision>,
    current: Snapshot,
    retries: BTreeMap<String, (Revision, Commit)>,
    retry_order: VecDeque<String>,
    retired_tokens: BTreeMap<String, Commit>,
    estimated_bytes: usize,
}
/// Owner-extension payload. Derived state is reconstructed and validated.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StoredWorkspace {
    pub version: u32,
    pub scope: ScopeKey,
    pub history: Vec<Revision>,
}
impl Workspace {
    pub fn export(&self) -> StoredWorkspace {
        StoredWorkspace {
            version: VERSION,
            scope: self.initial.clone(),
            history: self.history.clone(),
        }
    }
    pub fn retention_metrics(&self) -> RetentionMetrics {
        RetentionMetrics {
            active_records: self.current.active.len(),
            historical_ids: self.current.records.len(),
            revisions: self.history.len(),
            retained_retries: self.retries.len(),
            retired_tokens: self.retired_tokens.len(),
            estimated_bytes: self.estimated_bytes,
        }
    }
    pub fn import(
        stored: StoredWorkspace,
        authenticated_scope: &ScopeKey,
        max_records: usize,
    ) -> Result<Self, Error> {
        Self::import_with_policy(
            stored,
            authenticated_scope,
            &RetentionPolicy::legacy(max_records),
        )
    }
    pub fn import_with_policy(
        stored: StoredWorkspace,
        authenticated_scope: &ScopeKey,
        policy: &RetentionPolicy,
    ) -> Result<Self, Error> {
        policy.validate()?;
        if stored.version != VERSION || &stored.scope != authenticated_scope {
            return Err(Error::Invalid(
                "workspace owner version or authenticated scope",
            ));
        }
        Self::restore_with_policy(stored.scope, stored.history, policy)
    }
    /// Checked replay with inherited work/deadline/cancellation. The resulting
    /// Workspace is the checked typed handle; callers may project and prepare
    /// multiple queries from it without serializing/importing it again.
    pub fn import_with_control(
        stored: StoredWorkspace,
        authenticated_scope: &ScopeKey,
        max_records: usize,
        control: &dyn oracle_execution::WorkControl,
    ) -> Result<Self, Error> {
        Self::import_with_policy_and_control(
            stored,
            authenticated_scope,
            &RetentionPolicy::legacy(max_records),
            control,
        )
    }
    pub fn import_with_policy_and_control(
        stored: StoredWorkspace,
        authenticated_scope: &ScopeKey,
        policy: &RetentionPolicy,
        control: &dyn oracle_execution::WorkControl,
    ) -> Result<Self, Error> {
        policy.validate()?;
        if stored.version != VERSION || &stored.scope != authenticated_scope {
            return Err(Error::Invalid(
                "workspace owner version or authenticated scope",
            ));
        }
        if stored.history.len() > policy.max_revisions {
            return Err(Error::Limit("workspace history"));
        }
        let mut workspace = Self::new(stored.scope)?;
        if workspace.estimated_bytes > policy.max_bytes {
            return Err(Error::Limit("workspace bytes"));
        }
        for revision in stored.history {
            restore_checkpoint(
                control,
                1 + revision.insert.len() as u64 + revision.withdraw.len() as u64,
            )?;
            workspace.apply_with_policy(revision, policy)?;
            restore_checkpoint(control, 0)?;
        }
        restore_checkpoint(control, 0)?;
        Ok(workspace)
    }
    pub fn checkpoint(&self) -> Checkpoint {
        self.current.checkpoint()
    }
    pub fn new(scope: ScopeKey) -> Result<Self, Error> {
        if scope.tenant.is_empty() || scope.workspace.is_empty() {
            return Err(Error::Invalid("workspace scope"));
        }
        #[derive(Serialize)]
        struct EmptyWorkspace<'a> {
            version: u32,
            scope: &'a ScopeKey,
            history: &'a [Revision],
        }
        let estimated_bytes = bounded_serialized_len(
            &EmptyWorkspace {
                version: VERSION,
                scope: &scope,
                history: &[],
            },
            usize::MAX,
        )?;
        Ok(Self {
            initial: scope.clone(),
            history: vec![],
            current: Snapshot {
                scope,
                revision: 0,
                records: BTreeMap::new(),
                active: BTreeSet::new(),
            },
            retries: BTreeMap::new(),
            retry_order: VecDeque::new(),
            retired_tokens: BTreeMap::new(),
            estimated_bytes,
        })
    }
    /// Restore via checked events, never by trusting deserialized derived maps.
    pub fn restore(
        scope: ScopeKey,
        history: Vec<Revision>,
        max_records: usize,
    ) -> Result<Self, Error> {
        Self::restore_with_policy(scope, history, &RetentionPolicy::legacy(max_records))
    }
    pub fn restore_with_policy(
        scope: ScopeKey,
        history: Vec<Revision>,
        policy: &RetentionPolicy,
    ) -> Result<Self, Error> {
        policy.validate()?;
        if history.len() > policy.max_revisions {
            return Err(Error::Limit("workspace history"));
        }
        let mut w = Self::new(scope)?;
        if w.estimated_bytes > policy.max_bytes {
            return Err(Error::Limit("workspace bytes"));
        }
        for r in history {
            w.apply_with_policy(r, policy)?;
        }
        Ok(w)
    }
    /// Authenticated scope retained by checked restoration.
    pub fn scope(&self) -> &ScopeKey {
        &self.initial
    }
    pub fn history(&self) -> &[Revision] {
        &self.history
    }
    pub fn snapshot(&self) -> Snapshot {
        self.current.clone()
    }
    pub fn apply(&mut self, r: Revision, max_records: usize) -> Result<Commit, Error> {
        self.apply_with_policy(r, &RetentionPolicy::legacy(max_records))
    }
    pub fn apply_with_policy(
        &mut self,
        r: Revision,
        policy: &RetentionPolicy,
    ) -> Result<Commit, Error> {
        policy.validate()?;
        if let Some((old, result)) = self.retries.get(&r.token) {
            return if old == &r {
                Ok(result.clone())
            } else {
                Err(Error::Invalid(
                    "revision token reused with different content",
                ))
            };
        }
        if let Some(result) = self.retired_tokens.get(&r.token) {
            // Only the duplicate retry payload is evicted. The authoritative
            // committed event remains in history, so exact retry never expires.
            let old = usize::try_from(result.revision - 1)
                .ok()
                .and_then(|index| self.history.get(index));
            return if old == Some(&r) {
                Ok(result.clone())
            } else {
                Err(Error::Invalid(
                    "revision token reused with different content",
                ))
            };
        }
        if r.token.is_empty() {
            return Err(Error::Invalid("empty revision token"));
        }
        if r.expected_revision != self.current.revision {
            return Err(Error::Invalid("stale workspace revision"));
        }
        if self.history.len() >= policy.max_revisions
            || self
                .current
                .records
                .len()
                .checked_add(r.insert.len())
                .is_none_or(|n| n > policy.max_historical_ids)
        {
            return Err(Error::Limit("workspace history"));
        }
        let framing_bytes = usize::from(!self.history.is_empty());
        let available = policy
            .max_bytes
            .checked_sub(self.estimated_bytes)
            .and_then(|bytes| bytes.checked_sub(framing_bytes))
            .ok_or(Error::Limit("workspace bytes"))?;
        // A capped writer counts before cloning the event or derived snapshot;
        // oversized strings cannot force a temporary encoded allocation.
        let revision_bytes = bounded_serialized_len(&r, available)?;
        let next_bytes = self.estimated_bytes + framing_bytes + revision_bytes;
        if next_bytes > policy.max_bytes {
            return Err(Error::Limit("workspace bytes"));
        }
        let mut next = self.current.clone();
        let mut withdrawn = BTreeSet::new();
        for id in &r.withdraw {
            if !withdrawn.insert(id) || !next.active.remove(id) {
                return Err(Error::Invalid("unknown, inactive or duplicate withdrawal"));
            }
        }
        if next
            .active
            .len()
            .checked_add(r.insert.len())
            .is_none_or(|n| n > policy.max_active_records)
        {
            return Err(Error::Limit("workspace active records"));
        }
        for x in &r.insert {
            if x.id().is_empty() || next.records.contains_key(x.id()) {
                return Err(Error::Invalid("record identity reused"));
            }
            match x {
                Insert::Observation(o)
                    if o.source.is_empty() || o.source_revision.is_empty() || o.atom.is_empty() =>
                {
                    return Err(Error::Invalid("observation identity"))
                }
                Insert::Coverage(c)
                    if c.source.is_empty()
                        || c.source_revision.is_empty()
                        || c.domain.is_empty() =>
                {
                    return Err(Error::Invalid("coverage identity"))
                }
                Insert::Rule(p)
                    if p.head
                        .iter()
                        .chain(&p.positive)
                        .chain(&p.negative)
                        .any(|a| a.is_empty())
                        || (!p.negative.is_empty() && p.coverage.is_empty()) =>
                {
                    return Err(Error::Invalid("negative rules require coverage"))
                }
                _ => {}
            }
            next.active.insert(x.id().into());
            next.records.insert(x.id().into(), x.clone());
        }
        // Coverage references are typed, including withdrawn records; never bind
        // a rule's coverage guard to an observation with the same string ID.
        for x in next.records.values() {
            if let Insert::Rule(p) = x {
                for id in &p.coverage {
                    if !matches!(next.records.get(id), Some(Insert::Coverage(_))) {
                        return Err(Error::Invalid("unknown coverage reference"));
                    }
                }
            }
        }
        next.revision = next
            .revision
            .checked_add(1)
            .ok_or(Error::Limit("revision overflow"))?;
        let result = Commit {
            revision: next.revision,
            snapshot_identity: next.identity(),
        };
        self.current = next;
        self.estimated_bytes = next_bytes;
        self.history.push(r.clone());
        while self.retry_order.len() >= policy.max_retained_retries && !self.retry_order.is_empty()
        {
            if let Some(evicted) = self.retry_order.pop_front() {
                if let Some((_, commit)) = self.retries.remove(&evicted) {
                    self.retired_tokens.insert(evicted, commit);
                }
            }
        }
        let token = r.token.clone();
        if policy.max_retained_retries == 0 {
            self.retired_tokens.insert(token, result.clone());
        } else {
            self.retry_order.push_back(token.clone());
            self.retries.insert(token, (r, result.clone()));
        }
        Ok(result)
    }
}

/// Count serialized wire custody without allocating an encoded copy.
fn bounded_serialized_len(value: &impl Serialize, limit: usize) -> Result<usize, Error> {
    struct Counter {
        bytes: usize,
        limit: usize,
    }
    impl std::io::Write for Counter {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            if bytes.len() > self.limit.saturating_sub(self.bytes) {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    "workspace byte limit",
                ));
            }
            self.bytes += bytes.len();
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut counter = Counter { bytes: 0, limit };
    serde_json::to_writer(&mut counter, value).map_err(|_| Error::Limit("workspace bytes"))?;
    Ok(counter.bytes)
}

pub(crate) fn restore_checkpoint(
    control: &dyn oracle_execution::WorkControl,
    work: u64,
) -> Result<(), Error> {
    control.checkpoint(work).map_err(|error| match error {
        oracle_execution::ExecutionError::Cancelled => Error::Cancelled,
        oracle_execution::ExecutionError::Deadline => Error::Limit("shared deadline"),
        oracle_execution::ExecutionError::FuelExhausted => Error::Limit("shared work"),
        _ => Error::Limit("shared execution budget"),
    })
}
