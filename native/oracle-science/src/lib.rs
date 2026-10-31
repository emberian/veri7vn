//! Experimental floating-point scientific provider for supplied linear models.
//! Untrusted numerical computation: no Isabelle theorem, unit checker, physical
//! model validation, statistical uncertainty estimate, or Mini registration.
#![forbid(unsafe_code)]

pub mod thermal;

use faer::diag::Diag;
use faer::dyn_stack::{MemBuffer, MemStack};
use faer::linalg::svd::{svd, svd_scratch, ComputeSvdVectors};
use faer::{Mat, Par};
use oracle_execution::{ExecutionError, WorkControl};
use serde::{Deserialize, Serialize};

pub const SCHEMA: &str = "oracle-science-experimental-v1";
pub const MAX_REQUEST_BYTES: usize = 1024 * 1024;
pub const MAX_ROWS: usize = 512;
pub const MAX_COLUMNS: usize = 128;
pub const MAX_WORK: usize = 8_388_608;
pub const MAX_SCRATCH_BYTES: usize = 32 * 1024 * 1024;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid input: {0}")]
    Invalid(String),
    #[error("resource limit: {0}")]
    Limit(&'static str),
    #[error("cancelled (SVD itself is not interruptible)")]
    Cancelled,
    #[error("numerical computation refused: {0}")]
    Numerical(&'static str),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}

impl Error {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Invalid(_) => "invalid_input",
            Self::Limit(_) => "resource_limit",
            Self::Cancelled => "cancelled",
            Self::Numerical(_) => "numerical_failure",
            Self::Json(_) => "invalid_json",
        }
    }
}
pub type Result<T> = std::result::Result<T, Error>;

/// Operator limits may lower the fixed caps, but cannot raise them. No workers
/// or global thread settings are created/changed by this library.
#[derive(Clone, Debug)]
pub struct Limits {
    pub request_bytes: usize,
    pub rows: usize,
    pub columns: usize,
    /// Admission estimate m*n*min(m,n), not a count of executed instructions.
    pub work: usize,
    pub scratch_bytes: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            request_bytes: MAX_REQUEST_BYTES,
            rows: MAX_ROWS,
            columns: MAX_COLUMNS,
            work: MAX_WORK,
            scratch_bytes: MAX_SCRATCH_BYTES,
        }
    }
}

/// These declarations are retained as caller assertions, not checked facts.
/// Each A[i][j] must have row_units[i]/variable_units[j] dimensions. All rows
/// must already be normalized to the intended least-squares weighting.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Model {
    pub description: String,
    pub variable_units: Vec<String>,
    pub row_units: Vec<String>,
    pub normalization: String,
    pub assumptions: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Tolerances {
    /// Discard singular values <= rank_relative*sigma_max of globally scaled A.
    pub rank_relative: f64,
    /// Largest permitted componentwise backward error of the candidate.
    pub consistency_relative: f64,
}
impl Default for Tolerances {
    fn default() -> Self {
        Self {
            rank_relative: 1e-12,
            consistency_relative: 1e-10,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LinearInput {
    pub matrix: Vec<Vec<f64>>,
    pub rhs: Vec<f64>,
    pub model: Model,
    #[serde(default)]
    pub tolerances: Tolerances,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Operation {
    SolveLinear,
    LeastSquares,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Outcome {
    ConsistentUniqueWithinTolerance,
    ConsistentUnderdeterminedWithinTolerance,
    InconsistentWithinTolerance,
    LeastSquaresUniqueWithinRankPolicy,
    LeastSquaresUnderdeterminedWithinRankPolicy,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Diagnostics {
    pub rows: usize,
    pub columns: usize,
    pub numerical_rank: usize,
    /// n-rank, including null directions omitted by a thin rectangular SVD.
    pub nullity: usize,
    pub rank_cutoff_scaled: f64,
    /// Singular values of A/matrix_scale, in descending order.
    pub singular_values_scaled: Vec<f64>,
    pub matrix_scale: f64,
    pub rhs_scale: f64,
    /// Present only when all variable directions survive the rank policy.
    /// Null means unidentifiable, rather than a finite condition number.
    pub condition_number_2: Option<f64>,
    pub retained_condition_number_2: Option<f64>,
    pub equations_consistent_within_tolerance: bool,
    /// A*x-b in the caller's row units, recomputed from the returned x.
    pub residuals: Vec<f64>,
    /// Relative to the original rhs scale. Comparable only for rows whose
    /// normalization and units make aggregation meaningful.
    pub residual_l2_over_rhs_scale: f64,
    pub componentwise_backward_error: f64,
    pub maximum_row_backward_errors: Vec<f64>,
    /// A_scaled^T * ((A*x-b)/rhs_scale), useful for inspecting LS stationarity.
    /// A nonzero value may also reflect the declared singular-value truncation.
    pub normal_equation_gradient_scaled: Vec<f64>,
    pub candidate_l2: f64,
    pub svd_scratch_bytes: usize,
    pub work_estimate: usize,
    pub threads: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LinearResult {
    pub schema: String,
    pub assurance: String,
    pub operation: Operation,
    pub outcome: Outcome,
    /// x = V*S_truncated^+*U^T*b, then restored to caller variable units.
    /// In an inconsistent solve this is a fit candidate, not a solution.
    /// For numerical rank deficiency it is minimum norm in the supplied
    /// variable coordinates of the truncated model, not a unique inference.
    pub candidate: Vec<f64>,
    pub candidate_interpretation: String,
    pub diagnostics: Diagnostics,
    pub model: Model,
    pub tolerances: Tolerances,
    pub warnings: Vec<String>,
}

fn checkpoint(cancel: &dyn WorkControl) -> Result<()> {
    cancel.checkpoint(1).map_err(|error| match error {
        ExecutionError::Cancelled => Error::Cancelled,
        ExecutionError::Deadline => Error::Limit("shared deadline"),
        ExecutionError::FuelExhausted => Error::Limit("shared work"),
        _ => Error::Limit("shared execution budget"),
    })
}

fn finite(value: f64, context: &'static str) -> Result<f64> {
    if value.is_finite() {
        Ok(value)
    } else {
        Err(Error::Numerical(context))
    }
}

/// Neumaier summation reduces cancellation loss in dot products; it does not
/// turn floating-point residuals into rigorous enclosures.
fn sum(values: impl Iterator<Item = f64>) -> Result<f64> {
    let mut s = 0.0_f64;
    let mut c = 0.0_f64;
    for x in values {
        finite(x, "nonfinite product")?;
        let t = finite(s + x, "sum overflow")?;
        c += if s.abs() >= x.abs() {
            (s - t) + x
        } else {
            (x - t) + s
        };
        s = t;
    }
    finite(s + c, "compensated sum overflow")
}

fn norm(values: impl Iterator<Item = f64>) -> Result<f64> {
    finite(values.fold(0.0_f64, |n, x| n.hypot(x)), "norm overflow")
}

fn validate(input: &LinearInput, limits: &Limits) -> Result<(usize, usize, usize)> {
    let m = input.matrix.len();
    let n = input.matrix.first().map_or(0, Vec::len);
    if m == 0 || n == 0 {
        return Err(Error::Invalid("empty matrix".into()));
    }
    if m > limits.rows.min(MAX_ROWS) || n > limits.columns.min(MAX_COLUMNS) {
        return Err(Error::Limit("matrix dimensions"));
    }
    let work = m
        .checked_mul(n)
        .and_then(|v| v.checked_mul(m.min(n)))
        .ok_or(Error::Limit("matrix work"))?;
    if work > limits.work.min(MAX_WORK) {
        return Err(Error::Limit("matrix work"));
    }
    if input.rhs.len() != m || input.matrix.iter().any(|row| row.len() != n) {
        return Err(Error::Invalid(
            "ragged matrix or rhs length mismatch".into(),
        ));
    }
    if input
        .matrix
        .iter()
        .flatten()
        .chain(&input.rhs)
        .any(|v| !v.is_finite())
    {
        return Err(Error::Invalid("matrix and rhs must be finite".into()));
    }
    for t in [
        input.tolerances.rank_relative,
        input.tolerances.consistency_relative,
    ] {
        if !t.is_finite() || !(f64::EPSILON..=0.01).contains(&t) {
            return Err(Error::Invalid(
                "relative tolerances must lie in [f64::EPSILON, 0.01]".into(),
            ));
        }
    }
    let model = &input.model;
    if model.variable_units.len() != n || model.row_units.len() != m {
        return Err(Error::Invalid(
            "one unit per variable and per equation is required".into(),
        ));
    }
    if model.assumptions.is_empty() {
        return Err(Error::Invalid(
            "declare at least one model assumption".into(),
        ));
    }
    if model.assumptions.len() > 32 {
        return Err(Error::Limit("model assumptions"));
    }
    for text in std::iter::once(&model.description)
        .chain(std::iter::once(&model.normalization))
        .chain(&model.variable_units)
        .chain(&model.row_units)
        .chain(&model.assumptions)
    {
        if text.trim().is_empty() || text.len() > 1024 {
            return Err(Error::Invalid("model declarations must be nonempty and at most 1024 bytes each; use unit 1 for dimensionless values".into()));
        }
    }
    Ok((m, n, work))
}

/// One serial, bounded dense decomposition. Checks cancellation before and
/// after SVD and between outer loops. No hard wall-time/preemption guarantee:
/// a service needing that must put this provider in a killable owned process.
pub fn linear(
    input: &LinearInput,
    operation: Operation,
    limits: &Limits,
    cancel: &dyn WorkControl,
) -> Result<LinearResult> {
    checkpoint(cancel)?;
    let (m, n, work_estimate) = validate(input, limits)?;
    // Charge the bounded foreign-kernel estimate before allocating/running it.
    cancel
        .checkpoint(work_estimate as u64)
        .map_err(|e| match e {
            ExecutionError::Cancelled => Error::Cancelled,
            ExecutionError::Deadline => Error::Limit("shared deadline"),
            ExecutionError::FuelExhausted => Error::Limit("shared work"),
            _ => Error::Limit("shared execution budget"),
        })?;
    let k = m.min(n);
    let max_a = input
        .matrix
        .iter()
        .flatten()
        .fold(0.0_f64, |a, b| a.max(b.abs()));
    let max_b = input.rhs.iter().fold(0.0_f64, |a, b| a.max(b.abs()));
    let matrix_scale = if max_a == 0.0 { 1.0 } else { max_a };
    let rhs_scale = if max_b == 0.0 { 1.0 } else { max_b };
    // Only global scales: row equilibration would silently change the LS objective;
    // column equilibration would change minimum-norm coordinates.
    for value in input.matrix.iter().flatten() {
        if *value != 0.0 && value / matrix_scale == 0.0 {
            return Err(Error::Numerical(
                "matrix dynamic range underflows global normalization",
            ));
        }
    }
    for value in &input.rhs {
        if *value != 0.0 && value / rhs_scale == 0.0 {
            return Err(Error::Numerical(
                "rhs dynamic range underflows global normalization",
            ));
        }
    }
    let a = Mat::<f64>::from_fn(m, n, |i, j| input.matrix[i][j] / matrix_scale);
    let b: Vec<f64> = input.rhs.iter().map(|x| x / rhs_scale).collect();
    let mut u = Mat::<f64>::zeros(m, k);
    let mut v = Mat::<f64>::zeros(n, k);
    let mut s = Diag::<f64>::zeros(k);
    let req = svd_scratch::<f64>(
        m,
        n,
        ComputeSvdVectors::Thin,
        ComputeSvdVectors::Thin,
        Par::Seq,
        Default::default(),
    );
    let scratch_bytes = req.size_bytes();
    if scratch_bytes > limits.scratch_bytes.min(MAX_SCRATCH_BYTES) {
        return Err(Error::Limit("SVD scratch bytes"));
    }
    checkpoint(cancel)?;
    if max_a != 0.0 {
        let mut memory = MemBuffer::new(req);
        svd(
            a.as_ref(),
            s.as_mut(),
            Some(u.as_mut()),
            Some(v.as_mut()),
            Par::Seq,
            MemStack::new(&mut memory),
            Default::default(),
        )
        .map_err(|_| Error::Numerical("SVD did not converge"))?;
    }
    checkpoint(cancel)?;
    let singular_values: Vec<f64> = (0..k).map(|j| s[j]).collect();
    if singular_values.iter().any(|x| !x.is_finite() || *x < 0.0)
        || singular_values.windows(2).any(|p| p[0] < p[1])
    {
        return Err(Error::Numerical("invalid SVD spectrum"));
    }
    let cutoff = singular_values[0] * input.tolerances.rank_relative;
    let rank = singular_values.iter().filter(|s| **s > cutoff).count();
    let mut coefficients = vec![0.0; rank];
    for j in 0..rank {
        checkpoint(cancel)?;
        coefficients[j] = finite(
            sum((0..m).map(|i| u[(i, j)] * b[i]))? / s[j],
            "SVD projection overflow",
        )?;
    }
    let mut candidate = Vec::with_capacity(n);
    for i in 0..n {
        checkpoint(cancel)?;
        let y = sum((0..rank).map(|j| v[(i, j)] * coefficients[j]))?;
        // Try both orders when the scale quotient itself is out of range.
        let ratio = rhs_scale / matrix_scale;
        let x = if ratio.is_finite() && ratio != 0.0 {
            y * ratio
        } else {
            (y / matrix_scale) * rhs_scale
        };
        let x = finite(x, "candidate exceeds representable range")?;
        if y != 0.0 && x == 0.0 {
            return Err(Error::Numerical(
                "candidate underflows variable coordinates",
            ));
        }
        candidate.push(x);
    }
    // Recompute using the returned x in the ORIGINAL supplied rows, independently
    // of the SVD factors. Refuse overflow instead of reporting reassuring zeros.
    let mut residuals = Vec::with_capacity(m);
    let mut row_errors = Vec::with_capacity(m);
    for i in 0..m {
        checkpoint(cancel)?;
        let mut products = Vec::with_capacity(n);
        for j in 0..n {
            let product = finite(
                input.matrix[i][j] * candidate[j],
                "residual product overflow",
            )?;
            if product == 0.0 && input.matrix[i][j] != 0.0 && candidate[j] != 0.0 {
                return Err(Error::Numerical("residual product underflow"));
            }
            products.push(product);
        }
        let residual = sum(products
            .iter()
            .copied()
            .chain(std::iter::once(-input.rhs[i])))?;
        let magnitude = sum(products
            .iter()
            .map(|x| x.abs())
            .chain(std::iter::once(input.rhs[i].abs())))?;
        row_errors.push(if magnitude == 0.0 {
            0.0
        } else {
            residual.abs() / magnitude
        });
        residuals.push(residual);
    }
    let backward_error = row_errors.iter().copied().fold(0.0_f64, f64::max);
    let mut gradient = Vec::with_capacity(n);
    for j in 0..n {
        checkpoint(cancel)?;
        gradient.push(sum((0..m).map(|i| a[(i, j)] * (residuals[i] / rhs_scale)))?);
    }
    let consistent = backward_error <= input.tolerances.consistency_relative;
    let full_column_rank = rank == n;
    let outcome = match (operation, consistent, full_column_rank) {
        (Operation::SolveLinear, false, _) => Outcome::InconsistentWithinTolerance,
        (Operation::SolveLinear, true, true) => Outcome::ConsistentUniqueWithinTolerance,
        (Operation::SolveLinear, true, false) => Outcome::ConsistentUnderdeterminedWithinTolerance,
        (Operation::LeastSquares, _, true) => Outcome::LeastSquaresUniqueWithinRankPolicy,
        (Operation::LeastSquares, _, false) => Outcome::LeastSquaresUnderdeterminedWithinRankPolicy,
    };
    let retained_condition = if rank == 0 {
        None
    } else {
        Some(s[0] / s[rank - 1])
    };
    let mut warnings = vec!["Numerical residuals assess the supplied equations, not whether the physical model or observations are true.".into()];
    if !full_column_rank {
        warnings.push("Unknowns are not uniquely identifiable under the numerical rank policy; minimum norm depends on the supplied variable units.".into());
    }
    if retained_condition.is_some_and(|c| c > 1e8) {
        warnings.push("The retained system is poorly conditioned; small input changes can strongly change coefficients.".into());
    }
    if rank > 0
        && singular_values
            .iter()
            .any(|s| *s >= cutoff / 10.0 && *s <= cutoff * 10.0)
    {
        warnings.push("A singular value is near the rank cutoff; rank and identifiability depend on the chosen tolerance.".into());
    }
    let candidate_interpretation = match (operation, consistent, full_column_rank) {
        (Operation::SolveLinear, true, true) => "numerical solution within declared tolerance",
        (Operation::SolveLinear, true, false) => {
            "minimum-norm representative of the truncated model; not a unique solution"
        }
        _ => "truncated SVD least-squares candidate; not an exact solution claim",
    }
    .into();
    checkpoint(cancel)?;
    Ok(LinearResult {
        schema: SCHEMA.into(),
        assurance: "experimental floating-point computation; not formally verified".into(),
        operation,
        outcome,
        candidate_interpretation,
        diagnostics: Diagnostics {
            rows: m,
            columns: n,
            numerical_rank: rank,
            nullity: n - rank,
            rank_cutoff_scaled: cutoff,
            singular_values_scaled: singular_values,
            matrix_scale,
            rhs_scale,
            condition_number_2: if full_column_rank {
                retained_condition
            } else {
                None
            },
            retained_condition_number_2: retained_condition,
            equations_consistent_within_tolerance: consistent,
            residual_l2_over_rhs_scale: norm(residuals.iter().map(|r| r / rhs_scale))?,
            componentwise_backward_error: backward_error,
            maximum_row_backward_errors: row_errors,
            normal_equation_gradient_scaled: gradient,
            candidate_l2: norm(candidate.iter().copied())?,
            residuals,
            svd_scratch_bytes: scratch_bytes,
            work_estimate,
            threads: 1,
        },
        candidate,
        model: input.model.clone(),
        tolerances: input.tolerances.clone(),
        warnings,
    })
}

// Preserve raw argument bytes until dispatch. Serde's adjacently tagged enum
// buffers numbers through Content, which conflicts with serde_json's workspace
// arbitrary_precision feature when the eventual target is f64.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    operation: String,
    arguments: Box<serde_json::value::RawValue>,
}

/// Domain requests retain matrix/model and thermal semantics after decoding.
pub enum ScientificRequest {
    Linear {
        input: LinearInput,
        operation: Operation,
    },
    Thermal(thermal::ThermalInput),
}
#[derive(Serialize)]
#[serde(untagged)]
pub enum ScientificResponse {
    Linear(LinearResult),
    Thermal(thermal::ThermalResult),
}
pub fn execute(
    request: &ScientificRequest,
    limits: &Limits,
    control: &dyn WorkControl,
) -> Result<ScientificResponse> {
    checkpoint(control)?;
    match request {
        ScientificRequest::Linear { input, operation } => {
            linear(input, *operation, limits, control).map(ScientificResponse::Linear)
        }
        ScientificRequest::Thermal(input) => {
            thermal::thermal_network(input, limits, control).map(ScientificResponse::Thermal)
        }
    }
}

pub fn call(request: &str, limits: &Limits, cancel: &dyn WorkControl) -> Result<String> {
    checkpoint(cancel)?;
    if request.len() > limits.request_bytes.min(MAX_REQUEST_BYTES) {
        return Err(Error::Limit("request bytes"));
    }
    let request: Request =
        serde_json::from_str(request).map_err(|e| Error::Invalid(format!("request JSON: {e}")))?;
    let input = match request.operation.as_str() {
        "science.thermal_network" => ScientificRequest::Thermal(
            serde_json::from_str(request.arguments.get())
                .map_err(|e| Error::Invalid(format!("request arguments: {e}")))?,
        ),
        "science.solve_linear" | "science.least_squares" => ScientificRequest::Linear {
            input: serde_json::from_str(request.arguments.get())
                .map_err(|e| Error::Invalid(format!("request arguments: {e}")))?,
            operation: if request.operation == "science.solve_linear" {
                Operation::SolveLinear
            } else {
                Operation::LeastSquares
            },
        },
        _ => return Err(Error::Invalid("unknown scientific operation".into())),
    };
    Ok(serde_json::to_string(&execute(&input, limits, cancel)?)?)
}

pub fn catalog() -> serde_json::Value {
    serde_json::json!({
        "schema": SCHEMA,
        "assurance": "experimental floating-point; no Isabelle theorem or physical-model validation",
        "operations": ["science.solve_linear", "science.least_squares", "science.thermal_network"],
        "arguments": {"matrix": "row-major finite f64 coefficients", "rhs": "one finite value per row", "model": "description, variable_units, row_units, normalization, assumptions", "tolerances": "optional rank_relative and consistency_relative"},
        "limits": {"request_bytes": MAX_REQUEST_BYTES, "rows": MAX_ROWS, "columns": MAX_COLUMNS, "work_estimate": MAX_WORK, "svd_scratch_bytes": MAX_SCRATCH_BYTES, "threads": 1},
        "cancellation": "cooperative before/after SVD; decomposition is not interruptible",
        "thermal_network": {"arguments": "description, assumptions, reference_temperature_k, nodes[{id, applied_heat_w, fixed_temperature_k?}], links[{from,to,conductance_w_per_k}], power_tolerance_w?, tolerances?", "nodes": thermal::MAX_NODES, "links": thermal::MAX_LINKS, "model": "steady passive linear conductance network; fixed nodes exchange heat with ideal reservoirs; no transient, radiation, inferred geometry or automatic HVAC model"},
        "hosting": "pure library and one-request CLI; no Mini registration or hard containment"
    })
}

#[cfg(test)]
mod numerical_tests {
    use super::*;

    #[test]
    fn compensated_sum_retains_small_term_during_cancellation() {
        assert_eq!(sum([1e16, 1.0, -1e16].into_iter()).unwrap(), 1.0);
        assert_eq!(sum([-1e16, -1.0, 1e16].into_iter()).unwrap(), -1.0);
    }

    #[test]
    fn stable_norm_does_not_square_values_into_overflow_or_underflow() {
        let large = norm([3e150, 4e150].into_iter()).unwrap();
        let small = norm([3e-150, 4e-150].into_iter()).unwrap();
        assert!((large / 5e150 - 1.0).abs() < 1e-15);
        assert!((small / 5e-150 - 1.0).abs() < 1e-15);
    }
}
