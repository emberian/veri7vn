//! Supplied one-predictor calibration, reusing the bounded SVD regression.
//! Untrusted numerical calculation; unit labels and assumptions are assertions.
use crate::{
    checkpoint, finite, regress, Covariance, Error, Limits, Model, PredictionInput,
    RegressionInput, RegressionResult, Result, MAX_INFERENCE_CONDITION, SCHEMA,
};
use oracle_execution::WorkControl;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Direction {
    ForwardMean,
    ForwardObservation,
    InversePoint,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Uncertainty {
    PointOnly,
    PointwiseInterval,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CalibrationInput {
    pub x: Vec<f64>,
    pub response: Vec<f64>,
    pub x_name: String,
    pub x_unit: String,
    pub response_unit: String,
    pub assumptions: Vec<String>,
    pub covariance: Covariance,
    #[serde(default)]
    pub relative_precisions: Option<Vec<f64>>,
    pub direction: Direction,
    pub uncertainty: Uncertainty,
    /// x values for forward requests, response values for inverse requests.
    pub values: Vec<f64>,
    /// Same precision scale as the training rows; individual observations only.
    #[serde(default)]
    pub observation_relative_precision: Option<f64>,
    #[serde(default = "crate::confidence_default")]
    pub confidence_level: f64,
    #[serde(default = "crate::rank_default")]
    pub rank_relative: f64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CalibrationEstimate {
    pub supplied_value: f64,
    pub value: Option<f64>,
    pub unit: String,
    pub pointwise_interval: Option<[f64; 2]>,
    pub unavailable_reasons: Vec<String>,
    /// A range diagnostic only, not a proof that interpolation is valid.
    pub outside_training_range: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CalibrationResult {
    pub schema: String,
    pub operation: String,
    pub assurance: String,
    pub direction: Direction,
    pub uncertainty: Uncertainty,
    pub input_unit: String,
    pub output_unit: String,
    pub requested_observation_relative_precision: Option<f64>,
    pub estimates: Vec<CalibrationEstimate>,
    pub fit: RegressionResult,
    pub interpretation: String,
}

pub fn calibrate(
    input: &CalibrationInput,
    limits: &Limits,
    cancel: &dyn WorkControl,
) -> Result<CalibrationResult> {
    checkpoint(cancel)?;
    // Bound the wrapper's copies before constructing RegressionInput. The
    // underlying regression repeats all model/numerical admission checks.
    if input.x.len() > limits.rows.min(crate::MAX_ROWS) || limits.parameters < 2 {
        return Err(Error::Limit("calibration dimensions"));
    }
    if input.x.is_empty()
        || input.response.len() != input.x.len()
        || input
            .relative_precisions
            .as_ref()
            .is_some_and(|w| w.len() != input.x.len())
    {
        return Err(Error::Invalid(
            "calibration needs equally long nonempty x,response and optional precision arrays"
                .into(),
        ));
    }
    if !crate::label(&input.x_name)
        || !crate::label(&input.x_unit)
        || !crate::label(&input.response_unit)
        || input.assumptions.is_empty()
        || input.assumptions.len() > 16
        || input.assumptions.iter().any(|a| !crate::label(a))
    {
        return Err(Error::Invalid(
            "bounded calibration labels and explicit assumptions required".into(),
        ));
    }
    if input.values.is_empty()
        || input.values.len() > limits.predictions.min(crate::MAX_PREDICTIONS)
    {
        return Err(Error::Invalid(
            "calibration needs 1..prediction-limit query values".into(),
        ));
    }
    if input.values.iter().any(|v| !v.is_finite()) {
        return Err(Error::Invalid("nonfinite calibration query".into()));
    }
    if input.direction != Direction::ForwardObservation
        && input.observation_relative_precision.is_some()
    {
        return Err(Error::Invalid(
            "new-observation precision applies only to forward_observation".into(),
        ));
    }
    if input.direction == Direction::ForwardObservation
        && input.observation_relative_precision.is_none()
    {
        return Err(Error::Invalid(
            "forward_observation requires explicit relative precision".into(),
        ));
    }
    if input
        .observation_relative_precision
        .is_some_and(|v| !v.is_finite() || v <= 0.0)
    {
        return Err(Error::Invalid(
            "new-observation relative precision must be finite and positive".into(),
        ));
    }
    let forward = input.direction != Direction::InversePoint;
    let fit = regress(
        &RegressionInput {
            features: input.x.iter().map(|x| vec![*x]).collect(),
            response: input.response.clone(),
            intercept: true,
            relative_precisions: input.relative_precisions.clone(),
            covariance: input.covariance,
            model: Model {
                description: "Supplied one-predictor y-on-x calibration".into(),
                predictor_names: vec![input.x_name.clone()],
                predictor_units: vec![input.x_unit.clone()],
                response_unit: input.response_unit.clone(),
                assumptions: input.assumptions.clone(),
            },
            confidence_level: input.confidence_level,
            rank_relative: input.rank_relative,
            predictions: if forward {
                input
                    .values
                    .iter()
                    .map(|v| PredictionInput {
                        features: vec![*v],
                        // HC3 has no new-observation noise model. Fit the mean only and
                        // explicitly refuse the observation interval below, retaining the
                        // requested precision in the outer calibration response.
                        observation_relative_precision: if input.covariance
                            == Covariance::Hc3Asymptotic
                        {
                            None
                        } else {
                            input.observation_relative_precision
                        },
                    })
                    .collect()
            } else {
                vec![]
            },
        },
        limits,
        cancel,
    )?;
    let (input_unit, output_unit) = if forward {
        (&input.x_unit, &input.response_unit)
    } else {
        (&input.response_unit, &input.x_unit)
    };
    let (xmin, xmax) = input
        .x
        .iter()
        .fold((f64::INFINITY, f64::NEG_INFINITY), |(lo, hi), x| {
            (lo.min(*x), hi.max(*x))
        });
    let identified = fit.diagnostics.numerical_rank == 2;
    let conditioned = fit
        .diagnostics
        .condition_number_2
        .is_some_and(|c| c <= MAX_INFERENCE_CONDITION);
    let mut estimates = Vec::with_capacity(input.values.len());
    for (i, supplied) in input.values.iter().enumerate() {
        checkpoint(cancel)?;
        let mut reasons = vec![];
        let mut value = None;
        let mut interval = None;
        if !identified {
            reasons.push("calibration_parameters_not_identifiable".into());
        } else if !conditioned {
            reasons.push("calibration_design_ill_conditioned".into());
        } else if forward {
            let p = &fit.predictions[i];
            value = p.fitted_mean;
            if input.uncertainty == Uncertainty::PointwiseInterval {
                interval = if input.direction == Direction::ForwardObservation {
                    p.pointwise_observation_interval
                } else {
                    p.pointwise_mean_interval
                };
                if interval.is_none() {
                    reasons.extend(fit.inference_unavailable_reasons.clone());
                    if input.direction == Direction::ForwardObservation
                        && input.covariance == Covariance::Hc3Asymptotic
                    {
                        reasons.push("new_observation_noise_not_modelled_by_hc3".into());
                    }
                }
            }
        } else if input.uncertainty == Uncertainty::PointwiseInterval {
            reasons.push(
                "inverse_calibration_uncertainty_not_implemented_no_forward_interval_inversion"
                    .into(),
            );
        } else {
            let a = fit.coefficient_candidate[0];
            let b = fit.coefficient_candidate[1];
            // Reject a slope indistinguishable from numerical cancellation on
            // the observed range. This is a numerical policy, not a t test.
            let yscale = input
                .response
                .iter()
                .fold(a.abs(), |s, y| s.max(y.abs()))
                .max(f64::MIN_POSITIVE);
            if b == 0.0 || (b * (xmax - xmin)).abs() <= 64.0 * f64::EPSILON * yscale {
                reasons.push("inverse_slope_zero_or_roundoff_scale".into());
            } else {
                value = Some(finite((*supplied - a) / b, "inverse calibration overflow")?);
            }
        }
        let query_x = if forward { Some(*supplied) } else { value };
        estimates.push(CalibrationEstimate {
            supplied_value: *supplied,
            value,
            unit: output_unit.clone(),
            pointwise_interval: interval,
            unavailable_reasons: reasons,
            outside_training_range: query_x.is_some_and(|x| x < xmin || x > xmax),
        });
    }
    Ok(CalibrationResult { schema: SCHEMA.into(), operation: "statistics.calibration".into(),
        assurance: "untrusted floating-point SVD; no Isabelle theorem; assumptions and unit labels are caller assertions".into(),
        direction: input.direction, uncertainty: input.uncertainty, input_unit: input_unit.clone(),
        output_unit: output_unit.clone(), estimates, fit,
        requested_observation_relative_precision: input.observation_relative_precision,
        interpretation: if forward { "Conditional y-on-x association; observation intervals require a noise model and supplied precision. No causal or source-coverage claim." }
            else { "Algebraic inversion of the fitted y-on-x line, not x-on-y regression or an errors-in-variables fit. No inverse uncertainty or measurement-error correction." }.into() })
}
