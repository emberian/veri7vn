//! Bounded alignment of supplied DNA, with independent path and score checks.
//! This is untrusted Rust computation, not an Isabelle theorem, reference
//! genome lookup, biological interpretation, diagnostic or design system.
#![forbid(unsafe_code)]

use bio::alignment::{pairwise::Aligner, AlignmentOperation};
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, Ordering};

pub const SCHEMA: &str = "oracle-bio-experimental-v1";
pub const MAX_REQUEST_BYTES: usize = 256 * 1024;
pub const MAX_SEQUENCE_BASES: usize = 4096;
pub const MAX_DP_CELLS: usize = 1_048_576;
pub const MAX_WORKING_BYTES_ESTIMATE: usize = 16 * 1024 * 1024;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid input: {0}")]
    Invalid(&'static str),
    #[error("resource limit: {0}")]
    Limit(&'static str),
    #[error("alignment failed independent check: {0}")]
    Check(&'static str),
    #[error("cancelled (Rust-Bio alignment itself is not interruptible)")]
    Cancelled,
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}
impl Error {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Invalid(_) => "invalid_input",
            Self::Limit(_) => "resource_limit",
            Self::Check(_) => "candidate_check_failed",
            Self::Cancelled => "cancelled",
            Self::Json(_) => "invalid_json",
        }
    }
}
pub type Result<T> = std::result::Result<T, Error>;

/// Operator policy can lower, but cannot raise, the fixed library caps.
#[derive(Clone, Debug, Serialize)]
pub struct Limits {
    pub request_bytes: usize,
    pub sequence_bases: usize,
    pub dp_cells: usize,
    pub working_bytes_estimate: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            request_bytes: MAX_REQUEST_BYTES,
            sequence_bases: MAX_SEQUENCE_BASES,
            dp_cells: MAX_DP_CELLS,
            working_bytes_estimate: MAX_WORKING_BYTES_ESTIMATE,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Mode {
    Global,
    Local,
    /// Consume all query bases; reference prefix and suffix are free clips.
    QueryGlobal,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Ambiguity {
    #[default]
    Reject,
    /// Accept IUPAC DNA letters, but any non-ACGT base scores as mismatch,
    /// even N versus N. No probabilistic or set-overlap interpretation.
    AlwaysMismatch,
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Scoring {
    pub match_score: i32,
    pub mismatch_score: i32,
    /// A run of k >= 1 gaps scores gap_open + (k - 1)*gap_extend.
    pub gap_open: i32,
    pub gap_extend: i32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AlignmentInput {
    /// DNA letters only, case insensitive. No whitespace, U, gaps or FASTA.
    pub query: String,
    pub reference: String,
    pub mode: Mode,
    pub scoring: Scoring,
    #[serde(default)]
    pub ambiguity: Ambiguity,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Edit {
    Match,
    Substitution,
    /// Consume one query base and no reference base.
    Insertion,
    /// Consume one reference base and no query base.
    Deletion,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Candidate {
    pub score: i64,
    /// All four coordinates are zero-based, half-open, in supplied orientation.
    pub query_start: usize,
    pub query_end: usize,
    pub reference_start: usize,
    pub reference_end: usize,
    /// One edit per alignment column; clipped prefixes/suffixes are omitted.
    pub operations: Vec<Edit>,
}
#[derive(Clone, Debug, Serialize)]
pub struct Checks {
    pub replayed_score: i64,
    pub independently_computed_optimal_score: i64,
    pub matches: usize,
    pub substitutions: usize,
    pub insertions: usize,
    pub deletions: usize,
    pub gap_runs: usize,
}
#[derive(Clone, Debug, Serialize)]
pub struct AlignmentResult {
    pub schema: &'static str,
    pub assurance: &'static str,
    pub backend: &'static str,
    pub mode: Mode,
    pub scoring: Scoring,
    pub ambiguity: Ambiguity,
    pub query_length: usize,
    pub reference_length: usize,
    pub candidate: Candidate,
    pub checks: Checks,
    pub dp_cells_per_pass: usize,
    pub working_bytes_estimate: usize,
    pub coordinate_convention: &'static str,
    pub interpretation: &'static str,
}

fn checkpoint(cancel: &AtomicBool) -> Result<()> {
    if cancel.load(Ordering::Relaxed) {
        Err(Error::Cancelled)
    } else {
        Ok(())
    }
}
fn canonical(b: u8) -> bool {
    matches!(b, b'A' | b'C' | b'G' | b'T')
}
fn equal_base(x: u8, y: u8) -> bool {
    canonical(x) && x == y
}
fn substitution(x: u8, y: u8, s: Scoring) -> i64 {
    i64::from(if equal_base(x, y) {
        s.match_score
    } else {
        s.mismatch_score
    })
}

/// Check bounds before normalization, Rust-Bio matrices, checker rows or output
/// allocation. JSON parsing has its own prior byte cap. This conservative
/// estimate covers algorithm buffers, not allocator metadata or process RSS.
fn admission(input: &AlignmentInput, limits: &Limits) -> Result<(usize, usize)> {
    let m = input.query.len();
    let n = input.reference.len();
    if m == 0 || n == 0 {
        return Err(Error::Invalid("both DNA sequences must be nonempty"));
    }
    if m.max(n) > limits.sequence_bases.min(MAX_SEQUENCE_BASES) {
        return Err(Error::Limit("sequence bases"));
    }
    let cells = (m + 1).checked_mul(n + 1).ok_or(Error::Limit("DP cells"))?;
    if cells > limits.dp_cells.min(MAX_DP_CELLS) {
        return Err(Error::Limit("DP cells"));
    }
    // Pinned Rust-Bio uses two-byte traceback cells plus linear score/clip
    // rows. Allow 8 bytes/cell and 256 bytes/base for rows, path and encoding.
    let bytes = cells
        .checked_mul(8)
        .and_then(|b| b.checked_add((m + n + 2) * 256))
        .and_then(|b| b.checked_add(65_536))
        .ok_or(Error::Limit("working bytes estimate"))?;
    if bytes
        > limits
            .working_bytes_estimate
            .min(MAX_WORKING_BYTES_ESTIMATE)
    {
        return Err(Error::Limit("working bytes estimate"));
    }
    let s = input.scoring;
    // This also keeps all finite paths far from Rust-Bio's i32 sentinel and
    // prevents reopening contiguous gaps from beating extension of that run.
    if !(1..=1000).contains(&s.match_score)
        || !(-1000..=0).contains(&s.mismatch_score)
        || !(-1000..=-1).contains(&s.gap_open)
        || !(-1000..=-1).contains(&s.gap_extend)
        || s.gap_open > s.gap_extend
    {
        return Err(Error::Invalid("require match_score 1..1000, mismatch_score -1000..0, and -1000 <= gap_open <= gap_extend <= -1"));
    }
    for b in input.query.bytes().chain(input.reference.bytes()) {
        let b = b.to_ascii_uppercase();
        let admitted = canonical(b)
            || (input.ambiguity == Ambiguity::AlwaysMismatch
                && matches!(
                    b,
                    b'R' | b'Y' | b'S' | b'W' | b'K' | b'M' | b'B' | b'D' | b'H' | b'V' | b'N'
                ));
        if !admitted {
            return Err(Error::Invalid("expected DNA letters without whitespace, U or gaps; ambiguity requires always_mismatch"));
        }
    }
    Ok((cells, bytes))
}

/// Independent rolling-row affine DP. It reads only input and scoring, never
/// Rust-Bio's matrices, traceback or reported score. Four i64 rows, O(m*n).
fn optimal_score(x: &[u8], y: &[u8], mode: Mode, s: Scoring, cancel: &AtomicBool) -> Result<i64> {
    const NEG: i64 = i64::MIN / 4;
    let gap = |k: usize| i64::from(s.gap_open) + (k as i64 - 1) * i64::from(s.gap_extend);
    let mut prev = vec![0_i64; y.len() + 1];
    if mode == Mode::Global {
        for (j, v) in prev.iter_mut().enumerate().skip(1) {
            *v = gap(j);
        }
    }
    let mut curr = vec![0_i64; y.len() + 1];
    let mut ins_prev = vec![NEG; y.len() + 1];
    let mut ins_curr = vec![NEG; y.len() + 1];
    let mut best = 0;
    for i in 1..=x.len() {
        checkpoint(cancel)?;
        curr[0] = if mode == Mode::Local { 0 } else { gap(i) };
        ins_curr[0] = if mode == Mode::Local { NEG } else { gap(i) };
        let mut deletion = NEG;
        for j in 1..=y.len() {
            let insertion =
                (ins_prev[j] + i64::from(s.gap_extend)).max(prev[j] + i64::from(s.gap_open));
            deletion =
                (deletion + i64::from(s.gap_extend)).max(curr[j - 1] + i64::from(s.gap_open));
            ins_curr[j] = insertion;
            curr[j] = (prev[j - 1] + substitution(x[i - 1], y[j - 1], s))
                .max(insertion)
                .max(deletion);
            if mode == Mode::Local {
                curr[j] = curr[j].max(0);
                best = best.max(curr[j]);
            }
        }
        std::mem::swap(&mut prev, &mut curr);
        std::mem::swap(&mut ins_prev, &mut ins_curr);
    }
    Ok(match mode {
        Mode::Global => prev[y.len()],
        Mode::QueryGlobal => *prev.iter().max().expect("nonempty row"),
        Mode::Local => best,
    })
}

fn replay(
    input: &AlignmentInput,
    x: &[u8],
    y: &[u8],
    candidate: &Candidate,
    cancel: &AtomicBool,
) -> Result<Checks> {
    let c = candidate;
    if c.query_start > c.query_end
        || c.query_end > x.len()
        || c.reference_start > c.reference_end
        || c.reference_end > y.len()
    {
        return Err(Error::Check("coordinates outside input"));
    }
    if (input.mode == Mode::Global
        && (c.query_start != 0
            || c.query_end != x.len()
            || c.reference_start != 0
            || c.reference_end != y.len()))
        || (input.mode == Mode::QueryGlobal && (c.query_start != 0 || c.query_end != x.len()))
    {
        return Err(Error::Check("coordinates violate alignment mode"));
    }
    if c.operations.len() > x.len() + y.len() {
        return Err(Error::Limit("traceback operations"));
    }
    let (mut i, mut j) = (c.query_start, c.reference_start);
    let mut result = Checks {
        replayed_score: 0,
        independently_computed_optimal_score: 0,
        matches: 0,
        substitutions: 0,
        insertions: 0,
        deletions: 0,
        gap_runs: 0,
    };
    let mut previous = None;
    for &edit in &c.operations {
        checkpoint(cancel)?;
        let score = match edit {
            Edit::Match | Edit::Substitution => {
                if i >= c.query_end || j >= c.reference_end {
                    return Err(Error::Check("diagonal edit exceeds interval"));
                }
                if (edit == Edit::Match) != equal_base(x[i], y[j]) {
                    return Err(Error::Check(
                        "match/substitution label disagrees with bases",
                    ));
                }
                let value = substitution(x[i], y[j], input.scoring);
                i += 1;
                j += 1;
                if edit == Edit::Match {
                    result.matches += 1;
                } else {
                    result.substitutions += 1;
                }
                value
            }
            Edit::Insertion | Edit::Deletion => {
                if edit == Edit::Insertion {
                    if i >= c.query_end {
                        return Err(Error::Check("insertion exceeds query interval"));
                    }
                    i += 1;
                    result.insertions += 1;
                } else {
                    if j >= c.reference_end {
                        return Err(Error::Check("deletion exceeds reference interval"));
                    }
                    j += 1;
                    result.deletions += 1;
                }
                if previous == Some(edit) {
                    i64::from(input.scoring.gap_extend)
                } else {
                    result.gap_runs += 1;
                    i64::from(input.scoring.gap_open)
                }
            }
        };
        result.replayed_score += score;
        previous = Some(edit);
    }
    if i != c.query_end || j != c.reference_end {
        return Err(Error::Check("traceback does not consume intervals"));
    }
    if result.replayed_score != c.score {
        return Err(Error::Check("reported score differs from traceback replay"));
    }
    result.independently_computed_optimal_score =
        optimal_score(x, y, input.mode, input.scoring, cancel)?;
    if result.replayed_score != result.independently_computed_optimal_score {
        return Err(Error::Check("traceback score is not independently optimal"));
    }
    Ok(result)
}

/// Check a supplied candidate, including independent optimal-score recomputation.
/// Equal-scoring alternatives are accepted; no uniqueness claim is made.
pub fn check_alignment(
    input: &AlignmentInput,
    candidate: &Candidate,
    limits: &Limits,
    cancel: &AtomicBool,
) -> Result<Checks> {
    checkpoint(cancel)?;
    admission(input, limits)?;
    // Bound a caller-owned path before making any normalized sequence copies.
    if candidate.operations.len() > input.query.len() + input.reference.len() {
        return Err(Error::Limit("traceback operations"));
    }
    let x = input.query.to_ascii_uppercase();
    let y = input.reference.to_ascii_uppercase();
    replay(input, x.as_bytes(), y.as_bytes(), candidate, cancel)
}

/// Rust-Bio's unbanded affine aligner followed by independent replay and score
/// DP. Cancellation is checked around Rust-Bio and between checker rows; a hard
/// deadline requires the host's owned, killable process worker.
pub fn align_pairwise(
    input: &AlignmentInput,
    limits: &Limits,
    cancel: &AtomicBool,
) -> Result<AlignmentResult> {
    checkpoint(cancel)?;
    let (cells, bytes) = admission(input, limits)?;
    let x = input.query.to_ascii_uppercase();
    let y = input.reference.to_ascii_uppercase();
    let (x, y) = (x.as_bytes(), y.as_bytes());
    let s = input.scoring;
    let mut aligner = Aligner::with_capacity(x.len(), y.len(), s.gap_open, s.gap_extend, |a, b| {
        if canonical(a) && a == b {
            s.match_score
        } else {
            s.mismatch_score
        }
    });
    let alignment = match input.mode {
        Mode::Global => aligner.global(x, y),
        Mode::Local => aligner.local(x, y),
        Mode::QueryGlobal => aligner.semiglobal(x, y),
    };
    checkpoint(cancel)?;
    if alignment.operations.len() > x.len() + y.len() {
        return Err(Error::Check("backend traceback exceeds path bound"));
    }
    let mut candidate = Candidate {
        score: i64::from(alignment.score),
        query_start: alignment.xstart,
        query_end: alignment.xend,
        reference_start: alignment.ystart,
        reference_end: alignment.yend,
        operations: Vec::with_capacity(alignment.operations.len()),
    };
    if input.mode == Mode::Local && candidate.score == 0 {
        // A zero-score local optimum has a canonical empty representative.
        candidate.query_start = 0;
        candidate.query_end = 0;
        candidate.reference_start = 0;
        candidate.reference_end = 0;
    } else {
        let (mut i, mut j) = (candidate.query_start, candidate.reference_start);
        for op in alignment.operations {
            let edit = match op {
                AlignmentOperation::Match | AlignmentOperation::Subst => {
                    let (&a, &b) = x
                        .get(i)
                        .zip(y.get(j))
                        .ok_or(Error::Check("backend diagonal exceeds sequence"))?;
                    i += 1;
                    j += 1;
                    if equal_base(a, b) {
                        Edit::Match
                    } else {
                        Edit::Substitution
                    }
                }
                AlignmentOperation::Ins => {
                    i += 1;
                    Edit::Insertion
                }
                AlignmentOperation::Del => {
                    j += 1;
                    Edit::Deletion
                }
                _ => return Err(Error::Check("unexpected backend clipping operation")),
            };
            candidate.operations.push(edit);
        }
    }
    // Free Rust-Bio's full traceback before the independent score pass.
    drop(aligner);
    let checks = replay(input, x, y, &candidate, cancel)?;
    checkpoint(cancel)?;
    Ok(AlignmentResult { schema: SCHEMA,
        assurance: "integer computation with independent traceback and optimal-score checks; no Isabelle theorem",
        backend: "rust-bio 4.0.1 unbanded pairwise alignment", mode: input.mode, scoring: input.scoring,
        ambiguity: input.ambiguity, query_length: x.len(), reference_length: y.len(), candidate, checks,
        dp_cells_per_pass: cells, working_bytes_estimate: bytes,
        coordinate_convention: "zero-based half-open; original supplied forward orientation; insertion consumes query, deletion consumes reference",
        interpretation: "optimal under supplied scoring and mode; one of possibly many ties; no homology, clinical significance, strand search or biological truth inferred" })
}

#[derive(Deserialize)]
#[serde(tag = "operation", content = "arguments", deny_unknown_fields)]
enum Request {
    #[serde(rename = "bio.align_pairwise")]
    Align(AlignmentInput),
}
pub fn call(request: &str, limits: &Limits, cancel: &AtomicBool) -> Result<String> {
    checkpoint(cancel)?;
    if request.len() > limits.request_bytes.min(MAX_REQUEST_BYTES) {
        return Err(Error::Limit("request bytes"));
    }
    let Request::Align(input) = serde_json::from_str(request)?;
    Ok(serde_json::to_string(&align_pairwise(
        &input, limits, cancel,
    )?)?)
}
pub fn catalog() -> serde_json::Value {
    serde_json::json!({
        "schema": SCHEMA,
        "operations": [{"id": "bio.align_pairwise", "arguments": {
            "query": "nonempty DNA string", "reference": "nonempty DNA string",
            "mode": "global|local|query_global", "scoring": "{match_score,mismatch_score,gap_open,gap_extend}; all explicit",
            "ambiguity": "optional reject (default) or always_mismatch"
        }}],
        "limits": Limits::default(),
        "assurance": "independently replayed integer score and independent affine optimal-score DP; not formally verified",
        "gap_convention": "gap_open + (length-1)*gap_extend",
        "coordinates": "zero-based half-open in supplied orientation",
        "strand": "supplied forward orientation only",
        "hosting": "pure serial provider; cooperative cancellation outside Rust-Bio; host process containment required for hard deadlines"
    })
}
