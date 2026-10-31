//! Bounded supplied-design linear regression and conditional inference.
//! Untrusted floating-point computation, not an Isabelle theorem or a claim
//! that the caller's statistical assumptions hold. No threads are created.
#![forbid(unsafe_code)]

pub mod calibration;
pub mod glm;
pub mod sequential;
pub use calibration::{calibrate, CalibrationInput, CalibrationResult};

use faer::diag::Diag;
use faer::dyn_stack::{MemBuffer, MemStack};
use faer::linalg::svd::{svd, svd_scratch, ComputeSvdVectors};
use faer::{Mat, Par};
use oracle_execution::{ExecutionError, WorkControl};
use serde::{Deserialize, Serialize};
use statrs::distribution::{ContinuousCDF, Normal, StudentsT};

pub const SCHEMA: &str = "oracle-statistics-experimental-v1";
pub const MAX_REQUEST_BYTES: usize = 1024 * 1024;
pub const MAX_ROWS: usize = 512;
/// Includes an intercept when requested.
pub const MAX_PARAMETERS: usize = 64;
pub const MAX_PREDICTIONS: usize = 128;
pub const MAX_WORK: usize = 2_097_152;
pub const MAX_SCRATCH_BYTES: usize = 32 * 1024 * 1024;
pub const MAX_INFERENCE_CONDITION: f64 = 1e8;
const LEVERAGE_GAP: f64 = 1e-10;
const STATIONARITY_LIMIT: f64 = 1e-10;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid input: {0}")]
    Invalid(String),
    #[error("resource limit: {0}")]
    Limit(&'static str),
    #[error("cancelled (SVD and distribution quantiles are not interruptible)")]
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

#[derive(Clone, Debug)]
pub struct Limits {
    pub request_bytes: usize,
    pub rows: usize,
    pub parameters: usize,
    pub predictions: usize,
    /// Admission estimate n*p*p, not an executed instruction count.
    pub work: usize,
    pub scratch_bytes: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            request_bytes: MAX_REQUEST_BYTES,
            rows: MAX_ROWS,
            parameters: MAX_PARAMETERS,
            predictions: MAX_PREDICTIONS,
            work: MAX_WORK,
            scratch_bytes: MAX_SCRATCH_BYTES,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Covariance {
    /// Independent Gaussian errors, correct conditional linear mean, fixed
    /// design/weights, Var(error_i | X) = sigma^2 / relative_precision_i.
    ClassicalNormalErrors,
    /// Independent, mean-zero errors with arbitrary heteroskedasticity;
    /// fixed design/weights and usual asymptotic regularity are caller claims.
    /// This applies HC3 to the transformed WLS design, with normal Wald tails.
    Hc3Asymptotic,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Model {
    pub description: String,
    pub predictor_names: Vec<String>,
    pub predictor_units: Vec<String>,
    pub response_unit: String,
    /// Caller assertions retained verbatim, not checked properties.
    pub assumptions: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PredictionInput {
    pub features: Vec<f64>,
    /// Required to request an individual-observation interval. Uses the SAME
    /// precision scale as training inputs; never inferred from a training row.
    /// Unsupported for HC3 because its covariance does not model new noise.
    #[serde(default)]
    pub observation_relative_precision: Option<f64>,
}

fn confidence_default() -> f64 {
    0.95
}
fn rank_default() -> f64 {
    1e-12
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RegressionInput {
    /// One supplied feature row per observation; never include an automatic
    /// constant here when intercept=true. Empty rows allow an intercept-only fit.
    pub features: Vec<Vec<f64>>,
    pub response: Vec<f64>,
    pub intercept: bool,
    /// Positive fixed loss weights; classical inference additionally asserts
    /// these are proportional to inverse conditional error variances.
    #[serde(default)]
    pub relative_precisions: Option<Vec<f64>>,
    pub covariance: Covariance,
    pub model: Model,
    #[serde(default = "confidence_default")]
    pub confidence_level: f64,
    #[serde(default = "rank_default")]
    pub rank_relative: f64,
    #[serde(default)]
    pub predictions: Vec<PredictionInput>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CoefficientInference {
    pub estimate: f64,
    pub standard_error: f64,
    /// Tests the supplied-design coefficient against zero; no causal claim.
    pub statistic_against_zero: f64,
    pub two_sided_p_against_zero: f64,
    /// Pointwise interval; no multiple-comparison or model-selection correction.
    pub confidence_interval: [f64; 2],
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Inference {
    pub covariance_method: Covariance,
    pub reference_distribution: String,
    pub confidence_level: f64,
    pub critical_value: f64,
    pub coefficient_covariance: Vec<Vec<f64>>,
    pub coefficients: Vec<CoefficientInference>,
    /// sqrt(sum(w_normalized*e^2)/(n-p)). It estimates a common noise
    /// scale only for ClassicalNormalErrors; under HC3 it is descriptive.
    pub residual_std_at_unit_normalized_precision: f64,
    pub required_assumptions: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ObservationDiagnostics {
    pub fitted: f64,
    /// response - fitted, in response units, recomputed from returned beta.
    pub residual: f64,
    /// Diagonal of the transformed-design projection, from retained U columns.
    pub leverage: f64,
    /// Classical-scale diagnostic, even when HC3 inference is requested.
    /// Missing for deficient rank, zero df, zero residual scale or leverage ~1.
    pub internally_standardized_residual: Option<f64>,
    /// Classical WLS influence diagnostic, not a probability or outlier test.
    pub cooks_distance: Option<f64>,
    /// e_i/(1-h_i), in response units. Present only for full rank and h_i<1.
    pub leave_one_out_residual: Option<f64>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Prediction {
    pub features: Vec<f64>,
    /// Absent for rank deficiency: this provider does not test estimability.
    pub fitted_mean: Option<f64>,
    pub mean_standard_error: Option<f64>,
    pub pointwise_mean_interval: Option<[f64; 2]>,
    pub observation_relative_precision: Option<f64>,
    pub pointwise_observation_interval: Option<[f64; 2]>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Diagnostics {
    pub observations: usize,
    pub parameters: usize,
    pub numerical_rank: usize,
    pub residual_degrees_of_freedom: usize,
    pub singular_values_scaled: Vec<f64>,
    pub rank_cutoff_scaled: f64,
    pub condition_number_2: Option<f64>,
    pub weighted_design_scale: f64,
    pub weighted_response_scale: f64,
    /// Input weights divided by this maximum before computation. Global
    /// reweighting preserves beta, HC3 and all reported intervals.
    pub input_precision_scale: f64,
    pub weighted_residual_norm: f64,
    /// max_j |A_scaled[:,j]^T*r_scaled| / ||b_scaled||; absolute when b=0.
    /// Checks the fitted rows independently of the decomposition.
    pub stationarity_scaled: f64,
    pub svd_scratch_bytes: usize,
    pub work_estimate: usize,
    pub threads: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RegressionResult {
    pub schema: String,
    pub assurance: String,
    pub operation: String,
    pub outcome: String,
    /// Intercept first, followed by supplied feature order.
    pub parameter_names: Vec<String>,
    pub parameter_units: Vec<String>,
    /// Rank deficiency gives the minimum-norm representative of the truncated
    /// weighted design in supplied coordinates, not identifiable coefficients.
    pub coefficient_candidate: Vec<f64>,
    pub candidate_interpretation: String,
    pub diagnostics: Diagnostics,
    pub observations: Vec<ObservationDiagnostics>,
    pub inference: Option<Inference>,
    pub inference_unavailable_reasons: Vec<String>,
    pub predictions: Vec<Prediction>,
    pub model: Model,
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
fn finite(x: f64, why: &'static str) -> Result<f64> {
    if x.is_finite() {
        Ok(x)
    } else {
        Err(Error::Numerical(why))
    }
}
fn product(a: f64, b: f64) -> Result<f64> {
    let v = finite(a * b, "product overflow")?;
    if a != 0.0 && b != 0.0 && v == 0.0 {
        return Err(Error::Numerical("product underflow"));
    }
    Ok(v)
}
fn sum(xs: impl Iterator<Item = f64>) -> Result<f64> {
    let mut s = 0.0_f64;
    let mut c = 0.0_f64;
    for x in xs {
        finite(x, "nonfinite summand")?;
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
fn dot(a: &[f64], b: &[f64]) -> Result<f64> {
    let terms: Result<Vec<_>> = a.iter().zip(b).map(|(&x, &y)| product(x, y)).collect();
    sum(terms?.into_iter())
}
fn norm(xs: impl Iterator<Item = f64>) -> Result<f64> {
    finite(xs.fold(0.0_f64, |s, x| s.hypot(x)), "norm overflow")
}
fn restore(x: f64, numerator: f64, denominator: f64) -> Result<f64> {
    let ratio = numerator / denominator;
    let v = if ratio.is_finite() && ratio != 0.0 {
        x * ratio
    } else {
        (x / denominator) * numerator
    };
    finite(v, "restoring units overflows")?;
    if x != 0.0 && v == 0.0 {
        return Err(Error::Numerical("restoring units underflows"));
    }
    Ok(v)
}
fn label(s: &str) -> bool {
    !s.trim().is_empty() && s.len() <= 1024
}
fn positive(x: f64) -> bool {
    x.is_finite() && x > 0.0
}

fn validate(input: &RegressionInput, limits: &Limits) -> Result<(usize, usize, usize, usize)> {
    let n = input.features.len();
    let q = input.features.first().map_or(0, Vec::len);
    let p = q
        .checked_add(usize::from(input.intercept))
        .ok_or(Error::Limit("parameters"))?;
    if n == 0 || p == 0 {
        return Err(Error::Invalid(
            "need observations and at least one parameter".into(),
        ));
    }
    if n > limits.rows.min(MAX_ROWS)
        || p > limits.parameters.min(MAX_PARAMETERS)
        || input.predictions.len() > limits.predictions.min(MAX_PREDICTIONS)
    {
        return Err(Error::Limit("regression dimensions"));
    }
    let work = n
        .checked_mul(p)
        .and_then(|v| v.checked_mul(p))
        .ok_or(Error::Limit("regression work"))?;
    if work > limits.work.min(MAX_WORK) {
        return Err(Error::Limit("regression work"));
    }
    if input.response.len() != n
        || input.features.iter().any(|r| r.len() != q)
        || input
            .features
            .iter()
            .flatten()
            .chain(&input.response)
            .any(|x| !x.is_finite())
    {
        return Err(Error::Invalid(
            "ragged design, response mismatch, or nonfinite observation".into(),
        ));
    }
    if input
        .relative_precisions
        .as_ref()
        .is_some_and(|w| w.len() != n || w.iter().any(|x| !positive(*x)))
    {
        return Err(Error::Invalid(
            "relative precisions must be positive finite, one per observation".into(),
        ));
    }
    if input.predictions.iter().any(|v| {
        v.features.len() != q
            || v.features.iter().any(|x| !x.is_finite())
            || v.observation_relative_precision
                .is_some_and(|w| !positive(w))
    }) {
        return Err(Error::Invalid(
            "prediction shape, value or observation precision".into(),
        ));
    }
    if input.covariance == Covariance::Hc3Asymptotic
        && input
            .predictions
            .iter()
            .any(|v| v.observation_relative_precision.is_some())
    {
        return Err(Error::Invalid(
            "HC3 estimates mean uncertainty, not new-observation noise; omit observation precision"
                .into(),
        ));
    }
    if !input.confidence_level.is_finite()
        || !(0.5..=0.999).contains(&input.confidence_level)
        || !input.rank_relative.is_finite()
        || !(f64::EPSILON..=0.01).contains(&input.rank_relative)
    {
        return Err(Error::Invalid(
            "confidence must be in [0.5,0.999]; rank_relative in [EPSILON,0.01]".into(),
        ));
    }
    let m = &input.model;
    if m.predictor_names.len() != q
        || m.predictor_units.len() != q
        || !label(&m.description)
        || !label(&m.response_unit)
        || m.assumptions.is_empty()
        || m.assumptions.len() > 16
        || m.assumptions.iter().any(|s| !label(s))
        || m.predictor_names.iter().any(|s| !label(s))
        || m.predictor_units.iter().any(|s| !label(s))
    {
        return Err(Error::Invalid("declare description, predictor names/units, response unit and assumptions (labels <=1024 bytes, <=16 assumptions)".into()));
    }
    let mut names = std::collections::BTreeSet::new();
    if input.intercept {
        names.insert("(intercept)");
    }
    if m.predictor_names.iter().any(|s| !names.insert(s.as_str())) {
        return Err(Error::Invalid(
            "parameter names must be unique, including (intercept)".into(),
        ));
    }
    Ok((n, q, p, work))
}

fn design_row(features: &[f64], intercept: bool) -> Vec<f64> {
    std::iter::once(1.0)
        .take(usize::from(intercept))
        .chain(features.iter().copied())
        .collect()
}

fn interval(estimate: f64, se: f64, critical: f64) -> Result<[f64; 2]> {
    let width = product(se, critical)?;
    Ok([
        finite(estimate - width, "interval lower bound overflow")?,
        finite(estimate + width, "interval upper bound overflow")?,
    ])
}

/// No statistical independence, distribution, completeness or causal premise
/// is verified. Inference is explicitly conditional on the requested model.
pub fn regress(
    input: &RegressionInput,
    limits: &Limits,
    cancel: &dyn WorkControl,
) -> Result<RegressionResult> {
    checkpoint(cancel)?;
    let (n, _q, p, work) = validate(input, limits)?;
    // Charge the bounded foreign-kernel estimate before allocating/running it.
    cancel.checkpoint(work as u64).map_err(|e| match e {
        ExecutionError::Cancelled => Error::Cancelled,
        ExecutionError::Deadline => Error::Limit("shared deadline"),
        ExecutionError::FuelExhausted => Error::Limit("shared work"),
        _ => Error::Limit("shared execution budget"),
    })?;
    let k = n.min(p);
    let req = svd_scratch::<f64>(
        n,
        p,
        ComputeSvdVectors::Thin,
        ComputeSvdVectors::Thin,
        Par::Seq,
        Default::default(),
    );
    let scratch_bytes = req.size_bytes();
    if scratch_bytes > limits.scratch_bytes.min(MAX_SCRATCH_BYTES) {
        return Err(Error::Limit("SVD scratch bytes"));
    }
    let rows: Vec<_> = input
        .features
        .iter()
        .map(|r| design_row(r, input.intercept))
        .collect();
    let wscale = input
        .relative_precisions
        .as_ref()
        .map_or(1.0, |w| w.iter().copied().fold(0.0_f64, f64::max));
    let weights: Vec<f64> = (0..n)
        .map(|i| {
            input
                .relative_precisions
                .as_ref()
                .map_or(1.0, |w| w[i] / wscale)
        })
        .collect();
    if weights.contains(&0.0) {
        return Err(Error::Numerical("precision normalization underflows"));
    }
    let roots: Vec<_> = weights.iter().map(|w| w.sqrt()).collect();
    let mut weighted_rows = Vec::with_capacity(n);
    let mut weighted_y = Vec::with_capacity(n);
    for i in 0..n {
        checkpoint(cancel)?;
        weighted_rows.push(
            rows[i]
                .iter()
                .map(|x| product(*x, roots[i]))
                .collect::<Result<Vec<_>>>()?,
        );
        weighted_y.push(product(input.response[i], roots[i])?);
    }
    let max_x = weighted_rows
        .iter()
        .flatten()
        .fold(0.0_f64, |a, b| a.max(b.abs()));
    let xscale = if max_x == 0.0 { 1.0 } else { max_x };
    let max_y = weighted_y.iter().fold(0.0_f64, |a, b| a.max(b.abs()));
    let yscale = if max_y == 0.0 { 1.0 } else { max_y };
    if weighted_rows
        .iter()
        .flatten()
        .any(|x| *x != 0.0 && x / xscale == 0.0)
        || weighted_y.iter().any(|x| *x != 0.0 && x / yscale == 0.0)
    {
        return Err(Error::Numerical(
            "global design or response normalization underflows",
        ));
    }
    let a = Mat::<f64>::from_fn(n, p, |i, j| weighted_rows[i][j] / xscale);
    let b: Vec<_> = weighted_y.iter().map(|y| y / yscale).collect();
    let mut u = Mat::<f64>::zeros(n, k);
    let mut v = Mat::<f64>::zeros(p, k);
    let mut s = Diag::<f64>::zeros(k);
    checkpoint(cancel)?;
    if max_x > 0.0 {
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
    let spectrum: Vec<_> = (0..k).map(|j| s[j]).collect();
    if spectrum.iter().any(|x| !x.is_finite() || *x < 0.0)
        || spectrum.windows(2).any(|v| v[0] < v[1])
    {
        return Err(Error::Numerical("invalid SVD spectrum"));
    }
    let cutoff = spectrum[0] * input.rank_relative;
    let rank = spectrum.iter().filter(|x| **x > cutoff).count();
    let full = rank == p;
    let df = n - rank;
    let condition = if full {
        Some(finite(s[0] / s[p - 1], "condition overflow")?)
    } else {
        None
    };
    let mut projection = Vec::with_capacity(rank);
    for j in 0..rank {
        checkpoint(cancel)?;
        projection.push(finite(
            sum((0..n).map(|i| u[(i, j)] * b[i]))? / s[j],
            "projection overflow",
        )?);
    }
    let mut beta = Vec::with_capacity(p);
    for j in 0..p {
        beta.push(restore(
            sum((0..rank).map(|t| v[(j, t)] * projection[t]))?,
            yscale,
            xscale,
        )?);
    }
    // Residuals use the returned coefficients and original supplied rows, not
    // U*S*V. This also catches range loss while restoring the coefficients.
    let mut residuals = Vec::with_capacity(n);
    let mut fitted = Vec::with_capacity(n);
    let mut rw = Vec::with_capacity(n);
    let mut leverage = Vec::with_capacity(n);
    for i in 0..n {
        checkpoint(cancel)?;
        let yhat = dot(&rows[i], &beta)?;
        let e = finite(input.response[i] - yhat, "residual overflow")?;
        let scaled = finite(product(e, roots[i])? / yscale, "residual scaling overflow")?;
        if e != 0.0 && scaled == 0.0 {
            return Err(Error::Numerical("residual scaling underflows"));
        }
        let h = sum((0..rank).map(|t| u[(i, t)] * u[(i, t)]))?;
        if !(0.0..=1.0 + 1e-10).contains(&h) {
            return Err(Error::Numerical("invalid projection leverage"));
        }
        leverage.push(h.min(1.0));
        fitted.push(yhat);
        residuals.push(e);
        rw.push(scaled);
    }
    let rnorm = norm(rw.iter().copied())?;
    let bnorm = norm(b.iter().copied())?;
    let mut stationarity = 0.0_f64;
    for j in 0..p {
        checkpoint(cancel)?;
        let g = sum((0..n).map(|i| a[(i, j)] * rw[i]))?.abs() / bnorm.max(1.0);
        stationarity = stationarity.max(g);
    }
    let sigma_scaled = if df > 0 {
        rnorm / (df as f64).sqrt()
    } else {
        0.0
    };
    let sigma = product(sigma_scaled, yscale)?;
    // Very small residuals may be only decomposition rounding. Do not turn
    // exact or nearly exact fits into spurious vanishing uncertainty.
    let residual_at_roundoff = rnorm <= 64.0 * f64::EPSILON * bnorm.max(1.0) * (n as f64).sqrt();
    let mut reasons = Vec::new();
    if !full {
        reasons.push("parameters_not_identifiable_under_rank_policy".into());
    }
    if df == 0 {
        reasons.push("no_residual_degrees_of_freedom".into());
    }
    if residual_at_roundoff {
        reasons.push("residual_scale_at_numerical_roundoff".into());
    }
    if condition.is_some_and(|c| c > MAX_INFERENCE_CONDITION) {
        reasons.push("design_too_ill_conditioned_for_inference_policy".into());
    }
    if stationarity > STATIONARITY_LIMIT {
        reasons.push("candidate_fails_stationarity_policy".into());
    }
    if input.covariance == Covariance::Hc3Asymptotic
        && leverage.iter().any(|h| 1.0 - h <= LEVERAGE_GAP)
    {
        reasons.push("hc3_undefined_at_unit_leverage".into());
    }
    let mut observations = Vec::with_capacity(n);
    for i in 0..n {
        let gap = 1.0 - leverage[i];
        let good = full && df > 0 && !residual_at_roundoff && gap > LEVERAGE_GAP;
        let standardized = if good {
            Some(finite(
                rw[i] / sigma_scaled / gap.sqrt(),
                "standardized residual overflow",
            )?)
        } else {
            None
        };
        let cooks = standardized
            .map(|t| {
                finite(
                    t * t * leverage[i] / ((p as f64) * gap),
                    "Cook distance overflow",
                )
            })
            .transpose()?;
        let loo = if full && gap > LEVERAGE_GAP {
            Some(finite(residuals[i] / gap, "LOO residual overflow")?)
        } else {
            None
        };
        observations.push(ObservationDiagnostics {
            fitted: fitted[i],
            residual: residuals[i],
            leverage: leverage[i],
            internally_standardized_residual: standardized,
            cooks_distance: cooks,
            leave_one_out_residual: loo,
        });
    }
    let mut factors: Vec<Vec<f64>> = Vec::new();
    if reasons.is_empty() {
        // A_scaled^+ = V*S^-1*U^T. Build a covariance square-root factor
        // directly rather than inverting X'WX or squaring condition numbers.
        let columns = if input.covariance == Covariance::ClassicalNormalErrors {
            p
        } else {
            n
        };
        factors = vec![vec![0.0; columns]; p];
        for j in 0..p {
            checkpoint(cancel)?;
            for t in 0..columns {
                let f = match input.covariance {
                    Covariance::ClassicalNormalErrors => product(v[(j, t)] / s[t], sigma_scaled)?,
                    Covariance::Hc3Asymptotic => {
                        let pinv = sum((0..p).map(|l| (v[(j, l)] / s[l]) * u[(t, l)]))?;
                        product(pinv, rw[t] / (1.0 - leverage[t]))?
                    }
                };
                factors[j][t] = restore(f, yscale, xscale)?;
            }
        }
        if factors.iter().any(|r| r.iter().all(|v| *v == 0.0)) {
            reasons.push("zero_estimated_coefficient_variance".into());
            factors.clear();
        }
    }
    let inference = if reasons.is_empty() {
        let student = StudentsT::new(0.0, 1.0, df as f64)
            .map_err(|_| Error::Numerical("Student-t parameters"))?;
        let gaussian = Normal::new(0.0, 1.0).map_err(|_| Error::Numerical("normal parameters"))?;
        let prob = 0.5 + input.confidence_level / 2.0;
        checkpoint(cancel)?;
        let critical = finite(
            match input.covariance {
                Covariance::ClassicalNormalErrors => student.inverse_cdf(prob),
                Covariance::Hc3Asymptotic => gaussian.inverse_cdf(prob),
            },
            "distribution quantile failure",
        )?;
        if critical <= 0.0 {
            return Err(Error::Numerical("nonpositive critical value"));
        }
        checkpoint(cancel)?;
        let mut covariance = vec![vec![0.0; p]; p];
        let mut coefficients = Vec::with_capacity(p);
        for j in 0..p {
            checkpoint(cancel)?;
            for l in 0..=j {
                let c = dot(&factors[j], &factors[l])?;
                covariance[j][l] = c;
                covariance[l][j] = c;
            }
            let se = norm(factors[j].iter().copied())?;
            let statistic = finite(beta[j] / se, "coefficient statistic overflow")?;
            let tail = match input.covariance {
                Covariance::ClassicalNormalErrors => student.sf(statistic.abs()),
                Covariance::Hc3Asymptotic => gaussian.sf(statistic.abs()),
            };
            let pvalue = finite(2.0 * tail, "distribution tail failure")?;
            if !(0.0..=1.0).contains(&pvalue) {
                return Err(Error::Numerical("invalid tail probability"));
            }
            coefficients.push(CoefficientInference {
                estimate: beta[j],
                standard_error: se,
                statistic_against_zero: statistic,
                two_sided_p_against_zero: pvalue,
                confidence_interval: interval(beta[j], se, critical)?,
            });
        }
        let required = match input.covariance {
            Covariance::ClassicalNormalErrors => vec!["Correct conditional linear mean; supplied predictors and positive weights fixed independently of response noise.", "Independent Gaussian errors with Var(error_i | X) = sigma^2 / supplied_relative_precision_i.", "Pointwise inference for this prespecified model; no selection, multiplicity or causal adjustment."],
            Covariance::Hc3Asymptotic => vec!["Correct conditional linear mean and independent mean-zero errors; supplied predictors and positive loss weights fixed independently of noise.", "HC3 sandwich on transformed weighted rows; arbitrary conditional variances, finite moments and usual large-sample regularity. No cluster or time-series dependence.", "Normal Wald tails and pointwise intervals are asymptotic approximations, with no finite-sample coverage guarantee or causal interpretation."],
        };
        Some(Inference {
            covariance_method: input.covariance,
            reference_distribution: if input.covariance == Covariance::ClassicalNormalErrors {
                format!("Student-t with {df} residual degrees of freedom")
            } else {
                "standard normal (asymptotic HC3 Wald)".into()
            },
            confidence_level: input.confidence_level,
            critical_value: critical,
            coefficient_covariance: covariance,
            coefficients,
            residual_std_at_unit_normalized_precision: sigma,
            required_assumptions: required.into_iter().map(str::to_string).collect(),
        })
    } else {
        None
    };
    let mut predictions = Vec::with_capacity(input.predictions.len());
    for prediction in &input.predictions {
        checkpoint(cancel)?;
        let row = design_row(&prediction.features, input.intercept);
        let mean = if full { Some(dot(&row, &beta)?) } else { None };
        let mut se = None;
        let mut mean_interval = None;
        let mut observation_interval = None;
        if let Some(inference) = &inference {
            let mut projected = Vec::with_capacity(factors[0].len());
            for t in 0..factors[0].len() {
                let column: Vec<_> = factors.iter().map(|r| r[t]).collect();
                projected.push(dot(&row, &column)?);
            }
            let mean_se = norm(projected.into_iter())?;
            se = Some(mean_se);
            mean_interval = Some(interval(mean.unwrap(), mean_se, inference.critical_value)?);
            if let Some(w) = prediction.observation_relative_precision {
                let wn = w / wscale;
                if !positive(wn) {
                    return Err(Error::Numerical(
                        "new observation precision normalization out of range",
                    ));
                }
                let new_noise = finite(sigma / wn.sqrt(), "new observation noise overflow")?;
                if sigma != 0.0 && new_noise == 0.0 {
                    return Err(Error::Numerical("new observation noise underflow"));
                }
                observation_interval = Some(interval(
                    mean.unwrap(),
                    mean_se.hypot(new_noise),
                    inference.critical_value,
                )?);
            }
        }
        predictions.push(Prediction {
            features: prediction.features.clone(),
            fitted_mean: mean,
            mean_standard_error: se,
            pointwise_mean_interval: mean_interval,
            observation_relative_precision: prediction.observation_relative_precision,
            pointwise_observation_interval: observation_interval,
        });
    }
    let mut names = input.model.predictor_names.clone();
    let mut units: Vec<_> = input
        .model
        .predictor_units
        .iter()
        .map(|u| format!("{}/({u})", input.model.response_unit))
        .collect();
    if input.intercept {
        names.insert(0, "(intercept)".into());
        units.insert(0, input.model.response_unit.clone());
    }
    let mut warnings = vec!["Model, units, independence and error assumptions are caller assertions; this provider does not establish them or causation.".into(), "Numerical rank depends on supplied coordinates and tolerance; intervals are pointwise for a prespecified model.".into()];
    if input.covariance == Covariance::Hc3Asymptotic {
        warnings.push("HC3 normal inference is asymptotic; small samples and influential observations can make it unreliable.".into());
    }
    if leverage.iter().any(|h| *h > 0.5) {
        warnings.push("Some observations have leverage above 0.5; inspect influence diagnostics and model stability.".into());
    }
    if spectrum
        .iter()
        .any(|s| *s > 0.0 && *s >= cutoff / 10.0 && *s <= cutoff * 10.0)
    {
        warnings.push("A singular value is near the rank cutoff; rank and inference availability can change with tolerance.".into());
    }
    if !input.predictions.is_empty() {
        warnings.push("Prediction inputs are supplied by the caller; extrapolation and covariate shift are not assessed.".into());
    }
    checkpoint(cancel)?;
    Ok(RegressionResult { schema: SCHEMA.into(), assurance: "experimental floating-point fit; statistical inference conditional on unverified assumptions; no Isabelle theorem".into(), operation: "statistics.linear_regression".into(), outcome: if !full { "rank_deficient_fit" } else if inference.is_none() { "fit_without_inference" } else { "fit_with_conditional_inference" }.into(), parameter_names: names, parameter_units: units, coefficient_candidate: beta, candidate_interpretation: if full { "weighted least-squares coefficients unique within numerical rank policy" } else { "minimum-norm representative of rank-truncated weighted design in supplied variable coordinates; coefficients not uniquely identifiable" }.into(), diagnostics: Diagnostics { observations: n, parameters: p, numerical_rank: rank, residual_degrees_of_freedom: df, singular_values_scaled: spectrum, rank_cutoff_scaled: cutoff, condition_number_2: condition, weighted_design_scale: xscale, weighted_response_scale: yscale, input_precision_scale: wscale, weighted_residual_norm: product(rnorm, yscale)?, stationarity_scaled: stationarity, svd_scratch_bytes: scratch_bytes, work_estimate: work, threads: 1 }, observations, inference, inference_unavailable_reasons: reasons, predictions, model: input.model.clone(), warnings })
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    operation: String,
    // Preserve numeric lexemes: workspace arbitrary_precision conflicts with
    // Serde's intermediate adjacently tagged Content when decoding f64.
    arguments: Box<serde_json::value::RawValue>,
}

pub fn call(request: &str, limits: &Limits, cancel: &dyn WorkControl) -> Result<String> {
    checkpoint(cancel)?;
    if request.len() > limits.request_bytes.min(MAX_REQUEST_BYTES) {
        return Err(Error::Limit("request bytes"));
    }
    let request: Request = serde_json::from_str(request)?;
    if request.operation == glm::OPERATION {
        let input = serde_json::from_str(request.arguments.get())?;
        return Ok(serde_json::to_string(&glm::fit(&input, limits, cancel)?)?);
    }
    if request.operation == "statistics.sequential_monitor" {
        let input = serde_json::from_str(request.arguments.get())?;
        return Ok(serde_json::to_string(&sequential::replay(&input, limits, cancel)?)?);
    }
    if request.operation == "statistics.calibration" {
        let input = serde_json::from_str(request.arguments.get())?;
        return Ok(serde_json::to_string(&calibrate(&input, limits, cancel)?)?);
    }
    if request.operation != "statistics.linear_regression" {
        return Err(Error::Invalid("unknown statistical operation".into()));
    }
    let input = serde_json::from_str(request.arguments.get())?;
    Ok(serde_json::to_string(&regress(&input, limits, cancel)?)?)
}

pub fn catalog() -> serde_json::Value {
    serde_json::json!({
        "schema": SCHEMA,
        "assurance": "experimental floating-point; conditional statistical inference, no formal verification or causal claim",
        "operations": ["statistics.linear_regression", "statistics.calibration", "statistics.events_exposure", "statistics.sequential_monitor"],
        "events_exposure": glm::catalog_entry(),
        "sequential_monitor": {"method":sequential::METHOD,"operation":"statistics.sequential_monitor",
            "arguments":"config{method,bounds,alpha,metric,unit,sampling_assumptions,multiplicity,hypothesis?},observations",
            "assurance":"handwritten outward arithmetic, no extracted proof; time-uniform common conditional mean under fixed bounds and caller assumptions; null interval means all common means excluded, not failure"},
        "calibration": "one supplied predictor with intercept; forward_mean, forward_observation or inverse_point (algebraic inversion of y-on-x, never reverse regression); point_only or pointwise_interval; units are caller labels, not conversions; inverse uncertainty is refused",
        "arguments": "features, response, intercept, covariance (classical_normal_errors|hc3_asymptotic), model{description,predictor_names,predictor_units,response_unit,assumptions}; optional relative_precisions,confidence_level,rank_relative,predictions[{features,observation_relative_precision?}]",
        "inference": "full numerical column rank, positive residual df/scale, condition <=1e8, stationarity policy; HC3 additionally requires all leverage <1-1e-10; absent inference has explicit reasons",
        "precision_semantics": "fixed positive loss weights; classical errors require true inverse-variance ratios. HC3 transforms WLS rows and uses sandwich covariance with asymptotic normal tails. Global weight scaling leaves all intervals invariant.",
        "prediction": "pointwise conditional mean intervals; classical individual-observation intervals only with caller-supplied precision on the same scale; no HC3 observation intervals",
        "limits": {"request_bytes":MAX_REQUEST_BYTES,"observations":MAX_ROWS,"parameters_including_intercept":MAX_PARAMETERS,"predictions":MAX_PREDICTIONS,"work_estimate_n_p_p":MAX_WORK,"svd_scratch_bytes":MAX_SCRATCH_BYTES,"threads":1},
        "cancellation": "cooperative before/after SVD and quantile; those calls are not interruptible",
        "hosting": "pure library and one-request CLI; host supplies global admission and hard containment; no specialist or Mini registration"
    })
}
