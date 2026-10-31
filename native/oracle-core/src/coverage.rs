//! Snapshot-relative relation coverage. Rust checking, not an extracted theorem.
//! Serialized receipts are reports, never admission tokens. Missing source data
//! and completeness about reality remain outside this boundary.
use crate::{Budget, Cancellation, Error, Image, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CoverageRequest {
    /// Canonical source IDs, not aliases or a claim to exhaust an entity class.
    pub subjects: BTreeSet<String>,
    pub predicate: String,
    pub direction: String,
    /// Exact equality of the complete qualifier object; None admits every object.
    pub qualifiers: Option<Value>,
    pub traversal_limit: usize,
}
impl CoverageRequest {
    /// Conservative retained Rust payload, including tree nodes and String
    /// headers even for many one-byte IDs. Saturation cannot wrap admission.
    fn retained_bytes(&self) -> usize {
        let base = 512usize
            .saturating_add(self.predicate.capacity())
            .saturating_add(self.direction.capacity());
        let subjects = self.subjects.iter().fold(base, |bytes, id| {
            bytes.saturating_add(128).saturating_add(id.capacity())
        });
        subjects.saturating_add(self.qualifiers.as_ref()
            .map_or(0, crate::query::json_retained_bytes))
    }
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum IncompleteReason { TraversalLimit, MissingSubject(String) }
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Traversal {
    CompleteDeclaredSnapshotDomain,
    Incomplete { reasons: Vec<IncompleteReason> },
}
/// These scopes cannot be substituted for snapshot traversal. In particular,
/// exhausting a recognizer's admitted candidates does not exhaust aliases.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum OtherCoverage {
    SuppliedRowsVisited { rows: usize },
    AdmittedParseCandidatesExhausted { recognizer: String, candidates: usize },
    WorldClosedAssumption { asserted_by: String, statement: String },
}
#[derive(Debug, Serialize)]
pub struct CoverageReceipt {
    pub source_revision: String,
    pub domain: CoverageRequest,
    pub visited_rows: usize,
    pub matched_statements: usize,
    pub traversal: Traversal,
    pub scope: &'static str,
}
/// Cannot be deserialized or constructed by a caller. No registry is needed:
/// the completed scan owns its matched objects and its exact source binding.
#[derive(Debug)]
pub struct CoveredRelations {
    receipt: CoverageReceipt,
    objects: BTreeSet<String>,
    _memory: Vec<crate::budget::MemoryReservation>,
}
#[derive(Debug, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum UniqueRelation { AbsentInSnapshot, Unique(String), Multiple(usize) }
impl CoveredRelations {
    pub fn receipt(&self) -> &CoverageReceipt { &self.receipt }
    fn require(&self, revision: &str, domain: &CoverageRequest) -> Result<()> {
        if revision != self.receipt.source_revision || domain != &self.receipt.domain {
            return Err(Error::Conflict("coverage revision or domain mismatch"));
        }
        if self.receipt.traversal != Traversal::CompleteDeclaredSnapshotDomain {
            return Err(Error::Conflict("incomplete relation coverage"));
        }
        Ok(())
    }
    /// Counts distinct target IDs, not statements, aliases or real-world objects.
    pub fn count(&self, revision: &str, domain: &CoverageRequest) -> Result<usize> {
        self.require(revision, domain)?; Ok(self.objects.len())
    }
    pub fn absent(&self, revision: &str, domain: &CoverageRequest) -> Result<bool> {
        Ok(self.count(revision, domain)? == 0)
    }
    pub fn unique(&self, revision: &str, domain: &CoverageRequest) -> Result<UniqueRelation> {
        self.require(revision, domain)?;
        Ok(match self.objects.len() {
            0 => UniqueRelation::AbsentInSnapshot,
            1 => UniqueRelation::Unique(self.objects.iter().next().unwrap().clone()),
            n => UniqueRelation::Multiple(n),
        })
    }
    /// Deliberately no union/retraction operation: neither preserves the original
    /// traversal premise. After any source revision, rescan the immutable image.
    pub fn compatible(&self, other: &Self) -> bool {
        self.receipt.source_revision == other.receipt.source_revision
            && self.receipt.domain == other.receipt.domain
    }
}
impl Image {
    /// Traverses actual native `edges` cursors to EOF for every declared ID.
    /// Cancellation/SQLite/budget errors return no coverage token. Immutable
    /// artifact custody is the same host premise as Image::open.
    pub fn relation_coverage(&self, tenant: &str, domain: CoverageRequest,
        cancellation: Cancellation) -> Result<CoveredRelations> {
        let budget = Budget::new(&self.limits, cancellation)?;
        self.relation_coverage_with_budget(tenant, domain, &budget)
    }

    pub fn relation_coverage_with_budget(&self, tenant: &str, domain: CoverageRequest,
        budget: &Budget) -> Result<CoveredRelations> {
        crate::runtime::identifier(tenant)?;
        if domain.subjects.is_empty() || domain.predicate.is_empty()
            || domain.subjects.len() > self.limits.materialized_rows
            || domain.traversal_limit > self.limits.materialized_rows
            || !matches!(domain.direction.as_str(), "forward" | "backward")
            || domain.qualifiers.as_ref().is_some_and(|v| !v.is_object()) {
            return Err(Error::Invalid("coverage requires explicit IDs, predicate, direction and object filter".into()));
        }
        let budget = budget.restricted_to(&self.limits)?;
        // The typed input already exists at this boundary: charge its retained
        // containers before encoding/traversal, rather than approximating them
        // by their compact wire text. No second encoded allocation is needed.
        let domain_memory = budget.reserve_memory(domain.retained_bytes()
            .saturating_add(self.verified_identity().len()))?;
        let domain_bytes = crate::query::encoded_size(&domain, self.limits.request_bytes)?;
        budget.spend(domain_bytes as u64 + 1)?;
        let db = self.acquire(tenant, &budget)?;
        let mut reasons = Vec::new();
        let mut objects = BTreeSet::new();
        let mut visited = 0usize;
        let mut matched = 0usize;
        let mut memory = vec![domain_memory];
        'subjects: for subject in &domain.subjects {
            budget.spend(subject.len() as u64 + 1)?;
            let exists: bool = db.query_row("SELECT EXISTS(SELECT 1 FROM nodes WHERE id=?1)", [subject], |r| r.get(0))?;
            if !exists {
                // Covers the cloned String plus conservative Vec capacity for
                // both the reason and its retained reservation guard.
                memory.push(budget.reserve_memory(subject.len().saturating_add(128))?);
                reasons.push(IncompleteReason::MissingSubject(subject.clone()));
                continue;
            }
            let mut stmt = db.prepare_cached("SELECT object,qualifiers FROM edges WHERE subject=?1 AND predicate=?2 AND direction=?3 ORDER BY object,qualifiers")?;
            let mut rows = stmt.query(rusqlite::params![subject, domain.predicate, domain.direction])?;
            while let Some(row) = rows.next()? {
                // Probe one extra row: exactly-limit EOF remains complete.
                if visited == domain.traversal_limit {
                    memory.push(budget.reserve_memory(128)?);
                    reasons.push(IncompleteReason::TraversalLimit); break 'subjects;
                }
                visited += 1;
                let object: String = row.get(0)?;
                let qualifiers: String = row.get(1)?;
                budget.spend((object.len() + qualifiers.len() + 1) as u64)?;
                let qualifiers: Value = serde_json::from_str(&qualifiers)?;
                if domain.qualifiers.as_ref().is_none_or(|q| &qualifiers == q) {
                    matched += 1;
                    if !objects.contains(&object) {
                        memory.push(budget.reserve_memory(object.capacity().saturating_add(128))?);
                        objects.insert(object);
                    }
                }
            }
        }
        budget.check()?;
        let traversal = if reasons.is_empty() { Traversal::CompleteDeclaredSnapshotDomain }
            else { Traversal::Incomplete { reasons } };
        Ok(CoveredRelations { receipt: CoverageReceipt { source_revision: self.verified_identity().to_owned(), domain,
            visited_rows: visited, matched_statements: matched, traversal,
            scope: "declared canonical IDs and relation filter in immutable native image; no alias or world completeness" }, objects, _memory: memory })
    }
}
