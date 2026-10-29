use oracle_statistics::{
    call, regress, Covariance, Error, Limits, Model, PredictionInput, RegressionInput,
};
use std::sync::atomic::AtomicBool;

fn close(actual: f64, expected: f64) {
    assert!(
        (actual - expected).abs() <= 2e-9 * expected.abs().max(1.0),
        "{actual} != {expected}"
    );
}
fn input() -> RegressionInput {
    // The response is 1 + 2*x + e, with x=(-1,0,1), e=(1,-2,1).
    // sum(e)=sum(x*e)=0 independently establishes beta=(1,2).
    RegressionInput {
        features: vec![vec![-1.0], vec![0.0], vec![1.0]],
        response: vec![0.0, -1.0, 4.0],
        intercept: true,
        relative_precisions: None,
        covariance: Covariance::ClassicalNormalErrors,
        model: Model {
            description: "Analytic prespecified calibration model".into(),
            predictor_names: vec!["position".into()],
            predictor_units: vec!["m".into()],
            response_unit: "N".into(),
            assumptions: vec![
                "Independent Gaussian noise with a common unknown variance; fixed design".into(),
            ],
        },
        confidence_level: 0.95,
        rank_relative: 1e-12,
        predictions: vec![PredictionInput {
            features: vec![0.0],
            observation_relative_precision: Some(1.0),
        }],
    }
}
fn run(input: &RegressionInput) -> oracle_statistics::RegressionResult {
    regress(input, &Limits::default(), &AtomicBool::new(false)).unwrap()
}

#[test]
fn analytic_fit_student_t_covariance_leverage_and_influence() {
    let result = run(&input());
    assert_eq!(result.outcome, "fit_with_conditional_inference");
    close(result.coefficient_candidate[0], 1.0);
    close(result.coefficient_candidate[1], 2.0);
    assert_eq!(result.diagnostics.residual_degrees_of_freedom, 1);
    let inference = result.inference.unwrap();
    // X'X=diag(3,2), SSE=6, df=1; cov(beta)=diag(2,3).
    close(inference.coefficient_covariance[0][0], 2.0);
    close(inference.coefficient_covariance[1][1], 3.0);
    close(inference.coefficient_covariance[0][1], 0.0);
    close(
        inference.residual_std_at_unit_normalized_precision,
        6.0_f64.sqrt(),
    );
    // t with one degree of freedom is exactly Cauchy: use independently
    // derived arctan tails and tan quantile, not another statrs call.
    let critical = (std::f64::consts::PI * (0.975 - 0.5)).tan();
    close(inference.critical_value, critical);
    for (j, (estimate, se)) in [(1.0, 2.0_f64.sqrt()), (2.0, 3.0_f64.sqrt())]
        .into_iter()
        .enumerate()
    {
        let expected_p = 1.0 - 2.0 * (estimate / se).atan() / std::f64::consts::PI;
        close(
            inference.coefficients[j].two_sided_p_against_zero,
            expected_p,
        );
        close(
            inference.coefficients[j].confidence_interval[0],
            estimate - critical * se,
        );
    }
    for (i, (residual, h, standardized, cooks, loo)) in [
        (1.0, 5.0 / 6.0, 1.0, 2.5, 6.0),
        (-2.0, 1.0 / 3.0, -1.0, 0.25, -3.0),
        (1.0, 5.0 / 6.0, 1.0, 2.5, 6.0),
    ]
    .into_iter()
    .enumerate()
    {
        let d = &result.observations[i];
        close(d.residual, residual);
        close(d.leverage, h);
        close(d.internally_standardized_residual.unwrap(), standardized);
        close(d.cooks_distance.unwrap(), cooks);
        close(d.leave_one_out_residual.unwrap(), loo);
    }
    let prediction = &result.predictions[0];
    close(prediction.fitted_mean.unwrap(), 1.0);
    close(prediction.mean_standard_error.unwrap(), 2.0_f64.sqrt());
    close(
        prediction.pointwise_observation_interval.unwrap()[1],
        1.0 + critical * 8.0_f64.sqrt(),
    );
    assert_eq!(result.diagnostics.threads, 1);
}

#[test]
fn hc3_covariance_is_independent_analytic_sandwich() {
    let mut input = input();
    input.covariance = Covariance::Hc3Asymptotic;
    input.predictions[0].observation_relative_precision = None;
    let result = run(&input);
    let inference = result.inference.unwrap();
    // Original-row pseudoinverse has rows (1/3,1/3,1/3),(-1/2,0,1/2).
    // e/(1-h)=(6,-3,6), so HC3 is diag((36+9+36)/9,(36+36)/4).
    close(inference.coefficient_covariance[0][0], 9.0);
    close(inference.coefficient_covariance[1][1], 18.0);
    close(inference.coefficient_covariance[0][1], 0.0);
    close(inference.critical_value, 1.959963984540054);
    assert!(inference.reference_distribution.contains("asymptotic"));
    assert!(result.predictions[0]
        .pointwise_observation_interval
        .is_none());
    close(result.predictions[0].mean_standard_error.unwrap(), 3.0);
}

fn weighted_intercept(covariance: Covariance) -> RegressionInput {
    let mut input = input();
    input.features = vec![vec![], vec![], vec![]];
    input.response = vec![0.0, 2.0, 4.0];
    input.relative_precisions = Some(vec![1.0, 2.0, 1.0]);
    input.covariance = covariance;
    input.model.predictor_names.clear();
    input.model.predictor_units.clear();
    input.predictions = vec![PredictionInput {
        features: vec![],
        observation_relative_precision: if covariance == Covariance::ClassicalNormalErrors {
            Some(1.0)
        } else {
            None
        },
    }];
    input
}

#[test]
fn weighted_classical_and_hc3_agree_with_hand_calculation() {
    for (method, variance) in [
        (Covariance::ClassicalNormalErrors, 1.0),
        (Covariance::Hc3Asymptotic, 8.0 / 9.0),
    ] {
        let result = run(&weighted_intercept(method));
        close(result.coefficient_candidate[0], 2.0);
        close(result.observations[0].leverage, 0.25);
        close(result.observations[1].leverage, 0.5);
        close(
            result.inference.unwrap().coefficient_covariance[0][0],
            variance,
        );
        // For original W=(1,2,1), X'WX=4, e=(-2,0,2).
        // HC3: sum((w*e/(1-h))^2)/(sum(w))^2 = 8/9.
    }
}

#[test]
fn global_precision_scaling_preserves_fit_covariance_and_prediction() {
    for method in [Covariance::ClassicalNormalErrors, Covariance::Hc3Asymptotic] {
        let input = weighted_intercept(method);
        let baseline = run(&input);
        let mut scaled = input.clone();
        for weight in scaled.relative_precisions.as_mut().unwrap() {
            *weight *= 1e100;
        }
        if let Some(w) = &mut scaled.predictions[0].observation_relative_precision {
            *w *= 1e100;
        }
        let result = run(&scaled);
        close(
            result.coefficient_candidate[0],
            baseline.coefficient_candidate[0],
        );
        let ci = result.inference.unwrap();
        let bi = baseline.inference.unwrap();
        close(
            ci.coefficient_covariance[0][0],
            bi.coefficient_covariance[0][0],
        );
        close(
            result.predictions[0].mean_standard_error.unwrap(),
            baseline.predictions[0].mean_standard_error.unwrap(),
        );
        if let Some(interval) = result.predictions[0].pointwise_observation_interval {
            close(
                interval[1],
                baseline.predictions[0]
                    .pointwise_observation_interval
                    .unwrap()[1],
            );
        }
    }
}

#[test]
fn response_and_predictor_units_transform_estimates_and_covariance() {
    for method in [Covariance::ClassicalNormalErrors, Covariance::Hc3Asymptotic] {
        let mut input = input();
        input.covariance = method;
        input.predictions.clear();
        let baseline = run(&input);
        for y in &mut input.response {
            *y *= 7.0;
        }
        for row in &mut input.features {
            row[0] *= 100.0;
        }
        let result = run(&input);
        close(
            result.coefficient_candidate[0],
            baseline.coefficient_candidate[0] * 7.0,
        );
        close(
            result.coefficient_candidate[1],
            baseline.coefficient_candidate[1] * 7.0 / 100.0,
        );
        let ci = result.inference.unwrap();
        let bi = baseline.inference.unwrap();
        close(
            ci.coefficient_covariance[0][0],
            bi.coefficient_covariance[0][0] * 49.0,
        );
        close(
            ci.coefficient_covariance[1][1],
            bi.coefficient_covariance[1][1] * 49.0 / 10000.0,
        );
        for i in 0..3 {
            close(
                result.observations[i].leverage,
                baseline.observations[i].leverage,
            );
        }
    }
}

#[test]
fn row_permutation_preserves_parameters_and_reorders_diagnostics() {
    let mut input = input();
    let baseline = run(&input);
    input.features.reverse();
    input.response.reverse();
    let result = run(&input);
    for j in 0..2 {
        close(
            result.coefficient_candidate[j],
            baseline.coefficient_candidate[j],
        );
    }
    for i in 0..3 {
        close(
            result.observations[i].residual,
            baseline.observations[2 - i].residual,
        );
    }
}

#[test]
fn deficient_design_has_candidate_but_no_parameter_or_prediction_inference() {
    let mut input = input();
    input.features = vec![vec![1.0], vec![1.0], vec![1.0]];
    let result = run(&input);
    assert_eq!(result.diagnostics.numerical_rank, 1);
    assert_eq!(result.outcome, "rank_deficient_fit");
    assert!(result.inference.is_none());
    assert!(result
        .inference_unavailable_reasons
        .iter()
        .any(|r| r.contains("not_identifiable")));
    assert!(result.predictions[0].fitted_mean.is_none());
    // (intercept,slope)=(0.5,0.5) is the minimum-norm representative for
    // response mean=1, not an identified decomposition of that mean.
    close(result.coefficient_candidate[0], 0.5);
    close(result.coefficient_candidate[1], 0.5);
}

#[test]
fn saturated_and_perfect_models_do_not_claim_zero_uncertainty() {
    let mut input = input();
    input.features = vec![vec![-1.0], vec![1.0]];
    input.response = vec![0.0, 4.0];
    let result = run(&input);
    assert!(result.inference.is_none());
    assert!(result
        .inference_unavailable_reasons
        .iter()
        .any(|r| r == "no_residual_degrees_of_freedom"));
    input.features = vec![vec![-1.0], vec![0.0], vec![1.0]];
    input.response = vec![-1.0, 1.0, 3.0];
    let result = run(&input);
    assert!(result.inference.is_none());
    assert!(result
        .inference_unavailable_reasons
        .iter()
        .any(|r| r == "residual_scale_at_numerical_roundoff"));
}

#[test]
fn hc3_unit_leverage_is_explicitly_unavailable() {
    let mut input = input();
    input.features = vec![vec![0.0], vec![0.0], vec![1.0]];
    input.response = vec![0.0, 2.0, 7.0];
    input.covariance = Covariance::Hc3Asymptotic;
    input.predictions.clear();
    let result = run(&input);
    assert!(result.inference.is_none());
    assert!(result
        .inference_unavailable_reasons
        .iter()
        .any(|r| r == "hc3_undefined_at_unit_leverage"));
    close(result.observations[2].leverage, 1.0);
    assert!(result.observations[2].leave_one_out_residual.is_none());
}

#[test]
fn condition_policy_withholds_inference_even_for_numerical_full_rank() {
    let mut input = input();
    for row in &mut input.features {
        row[0] *= 1e-9;
    }
    input.predictions.clear();
    let result = run(&input);
    assert_eq!(result.diagnostics.numerical_rank, 2);
    assert!(result.inference.is_none());
    assert!(result
        .inference_unavailable_reasons
        .iter()
        .any(|r| r.contains("ill_conditioned")));
}

#[test]
fn errors_cover_malformed_inputs_unsupported_noise_and_limits() {
    let cancel = AtomicBool::new(false);
    let mut bad = input();
    bad.features[1].clear();
    assert!(matches!(
        regress(&bad, &Limits::default(), &cancel),
        Err(Error::Invalid(_))
    ));
    let mut bad = input();
    bad.response[0] = f64::NAN;
    assert!(matches!(
        regress(&bad, &Limits::default(), &cancel),
        Err(Error::Invalid(_))
    ));
    let mut bad = input();
    bad.relative_precisions = Some(vec![1.0, 0.0, 1.0]);
    assert!(matches!(
        regress(&bad, &Limits::default(), &cancel),
        Err(Error::Invalid(_))
    ));
    let mut bad = input();
    bad.covariance = Covariance::Hc3Asymptotic;
    assert!(matches!(
        regress(&bad, &Limits::default(), &cancel),
        Err(Error::Invalid(_))
    ));
    let limits = Limits {
        parameters: 1,
        ..Default::default()
    };
    assert!(matches!(
        regress(&input(), &limits, &cancel),
        Err(Error::Limit(_))
    ));
    let limits = Limits {
        scratch_bytes: 0,
        ..Default::default()
    };
    assert!(matches!(
        regress(&input(), &limits, &cancel),
        Err(Error::Limit(_))
    ));
    assert!(matches!(
        regress(&input(), &Limits::default(), &AtomicBool::new(true)),
        Err(Error::Cancelled)
    ));
}

#[test]
fn no_intercept_fit_and_zero_design_have_explicit_meaning() {
    let mut input = input();
    input.intercept = false;
    input.predictions.clear();
    let result = run(&input);
    close(result.coefficient_candidate[0], 2.0);
    // X'X=2; residual=(2,-1,2), SSE=9, df=2 => Var(beta)=9/4.
    close(
        result.inference.unwrap().coefficient_covariance[0][0],
        9.0 / 4.0,
    );
    for row in &mut input.features {
        row[0] = 0.0;
    }
    let result = run(&input);
    assert_eq!(result.diagnostics.numerical_rank, 0);
    close(result.coefficient_candidate[0], 0.0);
    assert!(result.inference.is_none());
}

#[test]
fn json_dispatch_preserves_decimal_numbers_and_rejects_unknown_fields() {
    let args = serde_json::to_string(&input()).unwrap();
    let request =
        format!("{{\"operation\":\"statistics.linear_regression\",\"arguments\":{args}}}");
    let reply = call(&request, &Limits::default(), &AtomicBool::new(false)).unwrap();
    let value: serde_json::Value = serde_json::from_str(&reply).unwrap();
    close(value["coefficient_candidate"][1].as_f64().unwrap(), 2.0);
    let bad = request.replacen("\"arguments\":{", "\"arguments\":{\"unused\":1,", 1);
    assert!(call(&bad, &Limits::default(), &AtomicBool::new(false)).is_err());
    let limits = Limits {
        request_bytes: request.len() - 1,
        ..Default::default()
    };
    assert!(matches!(
        call(&request, &limits, &AtomicBool::new(false)),
        Err(Error::Limit(_))
    ));
}

#[test]
fn extreme_weight_dynamic_range_is_refused_instead_of_dropping_observation() {
    let mut input = input();
    input.relative_precisions = Some(vec![f64::MAX, f64::MIN_POSITIVE, 1.0]);
    assert!(matches!(
        regress(&input, &Limits::default(), &AtomicBool::new(false)),
        Err(Error::Numerical(_))
    ));
}
