//! Exact supplied-fragment search; untrusted computation, no alignment claim.
//! One immutable collection and one shared query trie per batch. Scanning starts
//! separately prevents cross-record matches. No dense alphabet^k allocation.
use crate::{checkpoint, Error, Result};
use oracle_execution::WorkControl;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::sync::Arc;

pub const COLLECTION_SCHEMA: &str = "oracle-sequence-collection-v1";
pub const SEARCH_SCHEMA: &str = "oracle-sequence-search-v1";
pub const MAX_BASES: usize = 131_072;
pub const MAX_RECORDS: usize = 256;
pub const MAX_PATTERNS: usize = 128;
pub const MAX_PATTERN_BASES: usize = 4096;
pub const MAX_PAGE: usize = 1024;
pub const MAX_WORK: usize = 16_777_216;
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SequenceRecord {
    pub label: String,
    pub sequence: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CollectionInput {
    pub schema: String,
    pub records: Vec<SequenceRecord>,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Cursor {
    pub request_sha256: String,
    pub record: usize,
    pub start: usize,
    pub offset: usize,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SearchInput {
    pub collection: CollectionInput,
    pub patterns: Vec<SequenceRecord>,
    pub page_size: usize,
    #[serde(default)]
    pub cursor: Option<Cursor>,
}
#[derive(Clone, Debug)]
pub struct SequenceCollection {
    records: Arc<[SequenceRecord]>,
    content_sha256: String,
}
fn hash_field(hash: &mut Sha256, bytes: &[u8]) {
    hash.update((bytes.len() as u64).to_le_bytes());
    hash.update(bytes);
}
fn normalize(record: &SequenceRecord, allow_empty: bool) -> Result<SequenceRecord> {
    if record.label.len() > 256 {
        return Err(Error::Limit("sequence label bytes"));
    }
    if (!allow_empty && record.sequence.is_empty())
        || !record
            .sequence
            .bytes()
            .all(|b| matches!(b.to_ascii_uppercase(), b'A' | b'C' | b'G' | b'T'))
    {
        return Err(Error::Invalid(
            "exact search requires unambiguous ACGT DNA; empty patterns forbidden",
        ));
    }
    Ok(SequenceRecord {
        label: record.label.clone(),
        sequence: record.sequence.to_ascii_uppercase(),
    })
}
impl SequenceCollection {
    pub fn prepare(input: &CollectionInput, control: &dyn WorkControl) -> Result<Self> {
        checkpoint(control)?;
        if input.schema != COLLECTION_SCHEMA {
            return Err(Error::Invalid("collection schema"));
        }
        if input.records.len() > MAX_RECORDS {
            return Err(Error::Limit("collection record count"));
        }
        let mut total = 0usize;
        for record in &input.records {
            total = total
                .checked_add(record.sequence.len())
                .ok_or(Error::Limit("collection bases"))?;
            if total > MAX_BASES {
                return Err(Error::Limit("collection bases"));
            }
        }
        let mut hash = Sha256::new();
        hash_field(&mut hash, COLLECTION_SCHEMA.as_bytes());
        hash.update((input.records.len() as u64).to_le_bytes());
        let mut records = Vec::with_capacity(input.records.len());
        for record in &input.records {
            charge(control, record.sequence.len() + record.label.len() + 1)?;
            let normalized = normalize(record, true)?;
            // Identity preserves original case/bytes and ordered labels; the
            // normalized search representation never erases source identity.
            hash_field(&mut hash, record.label.as_bytes());
            hash_field(&mut hash, record.sequence.as_bytes());
            records.push(normalized);
        }
        Ok(Self {
            records: records.into(),
            content_sha256: format!("{:x}", hash.finalize()),
        })
    }
    pub fn content_sha256(&self) -> &str {
        &self.content_sha256
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Strand {
    Forward,
    Reverse,
    Both,
}
#[derive(Clone, Debug, Serialize)]
pub struct Hit {
    pub record_index: usize,
    pub record_label: String,
    pub pattern_index: usize,
    pub pattern_label: String,
    pub strand: Strand,
    pub start: usize,
    pub end: usize,
    /// Normalized forward-record bytes, even for reverse-strand hits.
    pub matched_sequence: String,
}
#[derive(Debug, Serialize)]
pub struct SearchResult {
    pub schema: &'static str,
    pub collection_sha256: String,
    pub request_sha256: String,
    pub hits: Vec<Hit>,
    pub complete: bool,
    pub next_cursor: Option<Cursor>,
    /// None means this page begins at the collection's first position.
    pub coverage_start: Option<Cursor>,
    pub work_units: usize,
    pub coordinate_convention: &'static str,
    pub assurance: &'static str,
}
#[derive(Default)]
struct Node {
    children: [Option<usize>; 4],
    terminals: Vec<(usize, Strand, usize)>,
}
fn code(b: u8) -> usize {
    match b {
        b'A' => 0,
        b'C' => 1,
        b'G' => 2,
        _ => 3,
    }
}
fn reverse_complement(s: &str) -> String {
    s.bytes()
        .rev()
        .map(|b| match b {
            b'A' => 'T',
            b'C' => 'G',
            b'G' => 'C',
            _ => 'A',
        })
        .collect()
}
fn charge(control: &dyn WorkControl, n: usize) -> Result<()> {
    control.checkpoint(n as u64).map_err(|e| match e {
        oracle_execution::ExecutionError::Cancelled => Error::Cancelled,
        _ => Error::Limit("shared execution budget"),
    })
}
fn insert(nodes: &mut Vec<Node>, s: &str, terminal: (usize, Strand, usize)) {
    let mut current = 0;
    for b in s.bytes() {
        let c = code(b);
        let next = if let Some(next) = nodes[current].children[c] {
            next
        } else {
            let next = nodes.len();
            nodes.push(Node::default());
            nodes[current].children[c] = Some(next);
            next
        };
        current = next;
    }
    nodes[current].terminals.push(terminal);
}
/// Searches an already prepared immutable collection, reusable by Arc across
/// batches. This API retains no tenant registry; the caller owns its lifetime.
pub struct PreparedSearch {
    collection: SequenceCollection,
    patterns: Arc<[SequenceRecord]>,
    nodes: Arc<[Node]>,
    request_sha256: String,
}
impl PreparedSearch {
    pub fn prepare(
        collection: &SequenceCollection,
        patterns: &[SequenceRecord],
        control: &dyn WorkControl,
    ) -> Result<Self> {
        checkpoint(control)?;
        if patterns.is_empty() || patterns.len() > MAX_PATTERNS {
            return Err(Error::Limit("pattern count 1..128"));
        }
        let mut total = 0usize;
        for p in patterns {
            total = total
                .checked_add(p.sequence.len())
                .ok_or(Error::Limit("pattern bases"))?;
            if p.sequence.len() > MAX_PATTERN_BASES || total > MAX_PATTERN_BASES {
                return Err(Error::Limit("total pattern bases"));
            }
        }
        let mut hash = Sha256::new();
        hash_field(&mut hash, SEARCH_SCHEMA.as_bytes());
        hash_field(&mut hash, collection.content_sha256.as_bytes());
        hash.update((patterns.len() as u64).to_le_bytes());
        let mut nodes = vec![Node::default()];
        for (i, pattern) in patterns.iter().enumerate() {
            charge(control, pattern.sequence.len() + pattern.label.len() + 1)?;
            let p = normalize(pattern, false)?;
            hash_field(&mut hash, pattern.label.as_bytes());
            hash_field(&mut hash, pattern.sequence.as_bytes());
            let rc = reverse_complement(&p.sequence);
            if rc == p.sequence {
                insert(&mut nodes, &p.sequence, (i, Strand::Both, p.sequence.len()));
            } else {
                insert(
                    &mut nodes,
                    &p.sequence,
                    (i, Strand::Forward, p.sequence.len()),
                );
                insert(&mut nodes, &rc, (i, Strand::Reverse, p.sequence.len()));
            }
        }
        let request_sha256 = format!("{:x}", hash.finalize());
        Ok(Self {
            collection: collection.clone(),
            patterns: patterns.to_vec().into(),
            nodes: nodes.into(),
            request_sha256,
        })
    }
    /// Reuse collection ownership and the same prepared trie across pages;
    /// admission/cancellation charges remain in the caller's WorkControl.
    pub fn page(
        &self,
        page_size: usize,
        cursor: Option<&Cursor>,
        control: &dyn WorkControl,
    ) -> Result<SearchResult> {
        checkpoint(control)?;
        if !(1..=MAX_PAGE).contains(&page_size) {
            return Err(Error::Limit("page size 1..1024"));
        }
        let collection = &self.collection;
        let patterns = &self.patterns;
        let nodes = &self.nodes;
        let request_sha256 = self.request_sha256.clone();
        if let Some(c) = cursor {
            if c.request_sha256 != request_sha256
                || c.record >= collection.records.len()
                || c.start >= collection.records[c.record].sequence.len()
                || c.offset > patterns.len() * 2
            {
                return Err(Error::Invalid(
                    "cursor does not belong to this supplied batch",
                ));
            }
        }
        let mut hits = Vec::with_capacity(page_size);
        let mut work = 0usize;
        for (ri, record) in collection
            .records
            .iter()
            .enumerate()
            .skip(cursor.map_or(0, |c| c.record))
        {
            let first = cursor.filter(|c| c.record == ri).map_or(0, |c| c.start);
            for start in first..record.sequence.len() {
                let mut found = Vec::new();
                let mut node = 0;
                for &b in &record.sequence.as_bytes()[start..] {
                    work += 1;
                    if work > MAX_WORK {
                        return Err(Error::Limit(
                            "exact search work; no absence or completion established",
                        ));
                    }
                    charge(control, 1)?;
                    match nodes[node].children[code(b)] {
                        Some(next) => node = next,
                        None => break,
                    }
                    found.extend_from_slice(&nodes[node].terminals);
                }
                found.sort_by_key(|&(pattern, strand, _)| {
                    (
                        pattern,
                        match strand {
                            Strand::Forward => 0,
                            Strand::Reverse => 1,
                            Strand::Both => 2,
                        },
                    )
                });
                let offset = cursor
                    .filter(|c| c.record == ri && c.start == start)
                    .map_or(0, |c| c.offset);
                if offset > found.len() {
                    return Err(Error::Invalid("cursor hit offset"));
                }
                for (fi, &(pi, strand, len)) in found.iter().enumerate().skip(offset) {
                    if hits.len() == page_size {
                        return Ok(SearchResult {
                            schema: SEARCH_SCHEMA,
                            collection_sha256: collection.content_sha256.clone(),
                            request_sha256: request_sha256.clone(),
                            hits,
                            complete: false,
                            next_cursor: Some(Cursor {
                                request_sha256,
                                record: ri,
                                start,
                                offset: fi,
                            }),
                            coverage_start: cursor.cloned(),
                            work_units: work,
                            coordinate_convention: COORDINATES,
                            assurance: ASSURANCE,
                        });
                    }
                    hits.push(Hit {
                        record_index: ri,
                        record_label: record.label.clone(),
                        pattern_index: pi,
                        pattern_label: patterns[pi].label.clone(),
                        strand,
                        start,
                        end: start + len,
                        matched_sequence: record.sequence[start..start + len].to_owned(),
                    });
                }
            }
        }
        Ok(SearchResult {
            schema: SEARCH_SCHEMA,
            collection_sha256: collection.content_sha256.clone(),
            request_sha256,
            hits,
            complete: true,
            next_cursor: None,
            coverage_start: cursor.cloned(),
            work_units: work,
            coordinate_convention: COORDINATES,
            assurance: ASSURANCE,
        })
    }
}
pub fn search_prepared(
    collection: &SequenceCollection,
    patterns: &[SequenceRecord],
    page_size: usize,
    cursor: Option<&Cursor>,
    control: &dyn WorkControl,
) -> Result<SearchResult> {
    PreparedSearch::prepare(collection, patterns, control)?.page(page_size, cursor, control)
}
const COORDINATES: &str =
    "zero-based half-open in original forward record; reverse hits retain original coordinates";
const ASSURANCE: &str = "untrusted complete exact trie traversal of supplied ACGT records; no alignment, biological or Isabelle claim; complete means remaining suffix exhausted";
pub fn search_collection(input: &SearchInput, control: &dyn WorkControl) -> Result<SearchResult> {
    let collection = SequenceCollection::prepare(&input.collection, control)?;
    search_prepared(
        &collection,
        &input.patterns,
        input.page_size,
        input.cursor.as_ref(),
        control,
    )
}
