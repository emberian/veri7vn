//! Host-owned revisable evidence. No persistence, authority, or retained solver.
//! Hosts authenticate ScopeKey, bound serialized size, and atomically persist the
//! returned workspace with their existing session/journal transaction.
use crate::{hosted, Error, Limits, Operation, Request, Rule, Scope};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet};

pub const OWNER: &str = "oracle.logic.revisions";
pub const VERSION: u32 = 1;
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
    pub fn import(
        stored: StoredWorkspace,
        authenticated_scope: &ScopeKey,
        max_records: usize,
    ) -> Result<Self, Error> {
        if stored.version != VERSION || &stored.scope != authenticated_scope {
            return Err(Error::Invalid(
                "workspace owner version or authenticated scope",
            ));
        }
        Self::restore(stored.scope, stored.history, max_records)
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
        if stored.version != VERSION || &stored.scope != authenticated_scope {
            return Err(Error::Invalid(
                "workspace owner version or authenticated scope",
            ));
        }
        if stored.history.len() > max_records {
            return Err(Error::Limit("workspace history"));
        }
        let mut workspace = Self::new(stored.scope)?;
        for revision in stored.history {
            restore_checkpoint(
                control,
                1 + revision.insert.len() as u64 + revision.withdraw.len() as u64,
            )?;
            workspace.apply(revision, max_records)?;
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
        })
    }
    /// Restore via checked events, never by trusting deserialized derived maps.
    pub fn restore(
        scope: ScopeKey,
        history: Vec<Revision>,
        max_records: usize,
    ) -> Result<Self, Error> {
        let mut w = Self::new(scope)?;
        for r in history {
            w.apply(r, max_records)?;
        }
        Ok(w)
    }
    pub fn history(&self) -> &[Revision] {
        &self.history
    }
    pub fn snapshot(&self) -> Snapshot {
        self.current.clone()
    }
    pub fn apply(&mut self, r: Revision, max_records: usize) -> Result<Commit, Error> {
        if let Some((old, result)) = self.retries.get(&r.token) {
            return if old == &r {
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
        if self.history.len() >= max_records
            || self
                .current
                .records
                .len()
                .checked_add(r.insert.len())
                .is_none_or(|n| n > max_records)
        {
            return Err(Error::Limit("workspace history"));
        }
        let mut next = self.current.clone();
        let mut withdrawn = BTreeSet::new();
        for id in &r.withdraw {
            if !withdrawn.insert(id) || !next.active.remove(id) {
                return Err(Error::Invalid("unknown, inactive or duplicate withdrawal"));
            }
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
        self.history.push(r.clone());
        self.retries.insert(r.token.clone(), (r, result.clone()));
        Ok(result)
    }
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
