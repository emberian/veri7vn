//! Coordinate-preserving literal translation of explicitly supplied intervals.
//! Handwritten computation, not gene finding, an ORF caller or an Isabelle proof.
use crate::collection::SequenceRecord;
use crate::{checkpoint, Error, Result};
use oracle_execution::WorkControl;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::sync::Arc;

pub const SOURCE_SCHEMA: &str = "oracle-translation-source-v1";
pub const SCHEMA: &str = "oracle-coding-translation-v1";
pub const CODE_ID: &str = "ncbi-standard-1-2024-09-23";
pub const CODE_SOURCE: &str = "https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#SG1";
pub const MAX_SOURCE_BASES: usize = 131_072;
pub const MAX_RECORDS: usize = 256;
pub const MAX_FEATURES: usize = 256;
pub const MAX_CODONS: usize = 16_384;
// NCBI table 1, ordinary AAs row, TCAG lexicographic codon order.
// Alternative Starts row is deliberately not used: no initiation inference.
const STANDARD: &[u8; 64] = b"FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG";
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TranslationSourceInput {
    pub schema: String,
    pub records: Vec<SequenceRecord>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Strand {
    Forward,
    Reverse,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RemainderPolicy {
    Reject,
    Drop,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StopPolicy {
    Include,
    Terminate,
    Reject,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AmbiguityPolicy {
    Reject,
    Unknown,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InitiationPolicy {
    LiteralCodon,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CodingFeature {
    pub label: String,
    pub record_index: usize,
    pub start: usize,
    pub end: usize,
    pub strand: Strand,
    /// Skip 0, 1 or 2 bases from the interval's oriented 5-prime end.
    pub frame: usize,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TranslationInput {
    pub source: TranslationSourceInput,
    pub features: Vec<CodingFeature>,
    pub genetic_code: String,
    pub initiation: InitiationPolicy,
    pub remainder: RemainderPolicy,
    pub stops: StopPolicy,
    pub ambiguity: AmbiguityPolicy,
}
#[derive(Clone, Debug)]
pub struct PreparedTranslationSource {
    records: Arc<[SequenceRecord]>,
    source_sha256: String,
    has_ambiguity: bool,
}
fn charge(control: &dyn WorkControl, n: usize) -> Result<()> {
    control.checkpoint(n as u64).map_err(|e| match e {
        oracle_execution::ExecutionError::Cancelled => Error::Cancelled,
        _ => Error::Limit("shared translation execution budget"),
    })
}
fn field(hash: &mut Sha256, bytes: &[u8]) {
    hash.update((bytes.len() as u64).to_le_bytes());
    hash.update(bytes);
}
fn is_iupac(b: u8) -> bool {
    b"ACGTRYSWKMBDHVN".contains(&b)
}
fn canonical(b: u8) -> bool {
    b"ACGT".contains(&b)
}
fn complement(b: u8) -> u8 {
    match b {
        b'A' => b'T',
        b'T' => b'A',
        b'C' => b'G',
        b'G' => b'C',
        b'R' => b'Y',
        b'Y' => b'R',
        b'S' => b'S',
        b'W' => b'W',
        b'K' => b'M',
        b'M' => b'K',
        b'B' => b'V',
        b'V' => b'B',
        b'D' => b'H',
        b'H' => b'D',
        _ => b'N',
    }
}
fn code(b: u8) -> usize {
    match b {
        b'T' => 0,
        b'C' => 1,
        b'A' => 2,
        _ => 3,
    }
}
fn amino(codon: [u8; 3]) -> u8 {
    if codon.iter().any(|&b| !canonical(b)) {
        b'X'
    } else {
        STANDARD[code(codon[0]) * 16 + code(codon[1]) * 4 + code(codon[2])]
    }
}
impl PreparedTranslationSource {
    pub fn prepare(source: &TranslationSourceInput, control: &dyn WorkControl) -> Result<Self> {
        checkpoint(control)?;
        if source.schema != SOURCE_SCHEMA {
            return Err(Error::Invalid("translation source schema"));
        }
        if source.records.len() > MAX_RECORDS {
            return Err(Error::Limit("translation source record count"));
        }
        let mut total = 0usize;
        for record in &source.records {
            total = total
                .checked_add(record.sequence.len())
                .ok_or(Error::Limit("translation source bases"))?;
            if total > MAX_SOURCE_BASES || record.label.len() > 256 {
                return Err(Error::Limit("translation source bases or label bytes"));
            }
        }
        let mut hash = Sha256::new();
        field(&mut hash, SOURCE_SCHEMA.as_bytes());
        hash.update((source.records.len() as u64).to_le_bytes());
        let mut records = Vec::with_capacity(source.records.len());
        let mut has_ambiguity = false;
        for record in &source.records {
            charge(control, record.sequence.len() + record.label.len() + 1)?;
            if !record
                .sequence
                .bytes()
                .all(|b| is_iupac(b.to_ascii_uppercase()))
            {
                return Err(Error::Invalid(
                    "translation requires DNA IUPAC letters only; no U, gaps, whitespace or FASTA",
                ));
            }
            let normalized = record.sequence.to_ascii_uppercase();
            has_ambiguity |= normalized.bytes().any(|b| !canonical(b));
            field(&mut hash, record.label.as_bytes());
            field(&mut hash, record.sequence.as_bytes());
            records.push(SequenceRecord {
                label: record.label.clone(),
                sequence: normalized,
            });
        }
        Ok(Self {
            records: records.into(),
            source_sha256: format!("{:x}", hash.finalize()),
            has_ambiguity,
        })
    }
    pub fn source_sha256(&self) -> &str {
        &self.source_sha256
    }
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct SourceInterval {
    pub start: usize,
    pub end: usize,
    pub strand: Strand,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct CodonMapping {
    pub amino_acid_index: usize,
    pub amino_acid: String,
    pub codon: String,
    pub source: SourceInterval,
}
#[derive(Debug, Serialize)]
pub struct FeatureTranslation {
    pub feature_index: usize,
    pub feature: CodingFeature,
    pub record_label: String,
    pub protein: String,
    pub codons: Vec<CodonMapping>,
    pub frame_skipped: Option<SourceInterval>,
    pub trailing_bases: Option<SourceInterval>,
    pub termination_stop: Option<CodonMapping>,
    pub untranslated_after_stop: Option<SourceInterval>,
}
#[derive(Debug, Serialize)]
pub struct TranslationResult {
    pub schema: &'static str,
    pub source_sha256: String,
    pub request_sha256: String,
    pub genetic_code: &'static str,
    pub genetic_code_source: &'static str,
    pub initiation: InitiationPolicy,
    pub remainder: RemainderPolicy,
    pub stops: StopPolicy,
    pub ambiguity: AmbiguityPolicy,
    pub translations: Vec<FeatureTranslation>,
    pub complete: bool,
    pub codons_examined: usize,
    pub coordinate_convention: &'static str,
    pub assurance: &'static str,
}
fn interval(feature: &CodingFeature, lo: usize, hi: usize) -> SourceInterval {
    match feature.strand {
        Strand::Forward => SourceInterval {
            start: feature.start + lo,
            end: feature.start + hi,
            strand: feature.strand,
        },
        Strand::Reverse => SourceInterval {
            start: feature.end - hi,
            end: feature.end - lo,
            strand: feature.strand,
        },
    }
}
fn optional_interval(feature: &CodingFeature, lo: usize, hi: usize) -> Option<SourceInterval> {
    if lo == hi {
        None
    } else {
        Some(interval(feature, lo, hi))
    }
}
/// Prepare once, share immutable source between batches, preserve original-byte
/// identity. All policies and feature order are bound to request_sha256.
pub fn translate_prepared(
    source: &PreparedTranslationSource,
    features: &[CodingFeature],
    genetic_code: &str,
    initiation: InitiationPolicy,
    remainder: RemainderPolicy,
    stops: StopPolicy,
    ambiguity: AmbiguityPolicy,
    control: &dyn WorkControl,
) -> Result<TranslationResult> {
    checkpoint(control)?;
    if genetic_code != CODE_ID {
        return Err(Error::Invalid(
            "only explicitly named NCBI standard table 1 snapshot is supported",
        ));
    }
    if features.is_empty() || features.len() > MAX_FEATURES {
        return Err(Error::Limit("translation feature count 1..256"));
    }
    if ambiguity == AmbiguityPolicy::Reject && source.has_ambiguity {
        return Err(Error::Invalid(
            "ambiguity reject requires all supplied source bases to be ACGT",
        ));
    }
    // Admit worst-case mapped codons even when terminate would stop earlier.
    let mut potential = 0usize;
    for feature in features {
        let record = source
            .records
            .get(feature.record_index)
            .ok_or(Error::Invalid("translation record index"))?;
        if feature.label.len() > 256 {
            return Err(Error::Limit("feature label bytes"));
        }
        if feature.start >= feature.end
            || feature.end > record.sequence.len()
            || feature.frame > 2
            || feature.frame > feature.end - feature.start
        {
            return Err(Error::Invalid("coding interval or frame"));
        }
        let length = feature.end - feature.start - feature.frame;
        if remainder == RemainderPolicy::Reject && length % 3 != 0 {
            return Err(Error::Invalid("incomplete trailing codon"));
        }
        potential = potential
            .checked_add(length / 3)
            .ok_or(Error::Limit("translation codons"))?;
        if potential > MAX_CODONS {
            return Err(Error::Limit("translation potential codons"));
        }
    }
    let mut hash = Sha256::new();
    field(&mut hash, SCHEMA.as_bytes());
    field(&mut hash, source.source_sha256.as_bytes());
    field(&mut hash, genetic_code.as_bytes());
    // Enum spellings and feature fields are serialized from admitted typed values.
    let policy = serde_json::to_vec(&(initiation, remainder, stops, ambiguity))?;
    field(&mut hash, &policy);
    hash.update((features.len() as u64).to_le_bytes());
    let mut translations = Vec::with_capacity(features.len());
    let mut examined = 0;
    for (fi, feature) in features.iter().enumerate() {
        charge(control, feature.label.len() + 1)?;
        field(&mut hash, &serde_json::to_vec(feature)?);
        let text = source.records[feature.record_index].sequence.as_bytes();
        let span = feature.end - feature.start;
        let length = span - feature.frame;
        let full = length / 3;
        let mut protein = String::with_capacity(full);
        let mut codons = Vec::with_capacity(full);
        let mut termination_stop = None;
        let mut untranslated_after_stop = None;
        for ci in 0..full {
            charge(control, 3)?;
            examined += 1;
            let lo = feature.frame + ci * 3;
            let mut triplet = [0u8; 3];
            for (j, b) in triplet.iter_mut().enumerate() {
                *b = match feature.strand {
                    Strand::Forward => text[feature.start + lo + j],
                    Strand::Reverse => complement(text[feature.end - 1 - lo - j]),
                };
            }
            let aa = amino(triplet);
            let mapping = CodonMapping {
                amino_acid_index: ci,
                amino_acid: (aa as char).to_string(),
                codon: triplet.iter().map(|&b| b as char).collect(),
                source: interval(feature, lo, lo + 3),
            };
            if aa == b'*' {
                match stops {
                    StopPolicy::Reject => {
                        return Err(Error::Invalid("stop codon forbidden by supplied policy"))
                    }
                    StopPolicy::Terminate => {
                        termination_stop = Some(mapping);
                        untranslated_after_stop = optional_interval(feature, lo + 3, span);
                        break;
                    }
                    StopPolicy::Include => {}
                }
            }
            protein.push(aa as char);
            codons.push(mapping);
        }
        translations.push(FeatureTranslation {
            feature_index: fi,
            feature: feature.clone(),
            record_label: source.records[feature.record_index].label.clone(),
            protein,
            codons,
            frame_skipped: optional_interval(feature, 0, feature.frame),
            trailing_bases: optional_interval(feature, feature.frame + full * 3, span),
            termination_stop,
            untranslated_after_stop,
        });
    }
    Ok(TranslationResult {schema:SCHEMA,source_sha256:source.source_sha256.clone(),request_sha256:format!("{:x}",hash.finalize()),
        genetic_code:CODE_ID,genetic_code_source:CODE_SOURCE,initiation,remainder,stops,ambiguity,translations,complete:true,codons_examined:examined,
        coordinate_convention:"zero-based half-open original forward source intervals; reverse codons read from end-1 down to start",
        assurance:"untrusted literal table lookup over all supplied features under explicit policies; no gene/ORF inference, protein function or Isabelle theorem"})
}
pub fn translate_intervals(
    input: &TranslationInput,
    control: &dyn WorkControl,
) -> Result<TranslationResult> {
    let source = PreparedTranslationSource::prepare(&input.source, control)?;
    translate_prepared(
        &source,
        &input.features,
        &input.genetic_code,
        input.initiation,
        input.remainder,
        input.stops,
        input.ambiguity,
        control,
    )
}
