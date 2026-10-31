use oracle_statistics::calibration::{Direction, Uncertainty};
use oracle_statistics::{calibrate, CalibrationInput, Covariance, Limits};
use std::sync::atomic::AtomicBool;

fn input() -> CalibrationInput {
    CalibrationInput {
        x: vec![-1., 0., 1.],
        response: vec![0., -1., 4.],
        x_name: "position".into(),
        x_unit: "m".into(),
        response_unit: "N".into(),
        assumptions: vec![
            "Fixed design, correct prespecified mean, independent Gaussian errors".into(),
        ],
        covariance: Covariance::ClassicalNormalErrors,
        relative_precisions: None,
        direction: Direction::ForwardMean,
        uncertainty: Uncertainty::PointwiseInterval,
        values: vec![0.],
        observation_relative_precision: None,
        confidence_level: 0.95,
        rank_relative: 1e-12,
    }
}
fn close(a: f64, b: f64) {
    assert!((a - b).abs() < 1e-8 * b.abs().max(1.));
}
#[test]
fn forward_mean_and_observation_keep_distinct_uncertainty_and_units() {
    let mut i = input();
    let mean = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    close(mean.estimates[0].value.unwrap(), 1.);
    // Orthogonal residual (1,-2,1): SSE=6, df=1, mean variance=2.
    // t_1(0.975) is the Cauchy tan quantile, independently of statrs.
    let t = (std::f64::consts::PI * 0.475).tan();
    close(
        mean.estimates[0].pointwise_interval.unwrap()[1],
        1. + t * 2f64.sqrt(),
    );
    assert_eq!(mean.output_unit, "N");
    i.direction = Direction::ForwardObservation;
    assert!(calibrate(&i, &Limits::default(), &AtomicBool::new(false)).is_err());
    i.observation_relative_precision = Some(1.);
    let obs = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    close(
        obs.estimates[0].pointwise_interval.unwrap()[1],
        1. + t * 8f64.sqrt(),
    );
}
#[test]
fn inverse_is_inversion_of_y_on_x_never_reverse_regression() {
    let mut i = input();
    i.direction = Direction::InversePoint;
    i.uncertainty = Uncertainty::PointOnly;
    i.values = vec![5.];
    let result = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    close(result.estimates[0].value.unwrap(), 2.); // reverse regression would give 8/7.
    assert_eq!(result.output_unit, "m");
    assert!(result.estimates[0].outside_training_range);
    i.uncertainty = Uncertainty::PointwiseInterval;
    let result = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    assert!(result.estimates[0].value.is_none());
    assert!(result.estimates[0].pointwise_interval.is_none());
    assert!(result.estimates[0].unavailable_reasons[0].contains("inverse_calibration_uncertainty"));
}
#[test]
fn degeneracy_ill_conditioning_and_roundoff_slope_refuse_points() {
    for x in [vec![2., 2., 2.], vec![0., 1e-9, 2e-9]] {
        let mut i = input();
        i.x = x;
        let r = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
        assert!(r.estimates[0].value.is_none());
        assert!(!r.estimates[0].unavailable_reasons.is_empty());
    }
    let mut i = input();
    i.response = vec![3., 3., 3.];
    i.direction = Direction::InversePoint;
    i.uncertainty = Uncertainty::PointOnly;
    let r = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    assert!(r.estimates[0].value.is_none());
}
#[test]
fn perfect_fit_is_a_point_without_invented_interval_and_hc3_is_not_new_noise() {
    let mut i = input();
    i.response = vec![-1., 1., 3.];
    let r = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    close(r.estimates[0].value.unwrap(), 1.);
    assert!(r.estimates[0].pointwise_interval.is_none());
    assert!(!r.estimates[0].unavailable_reasons.is_empty());
    i = input();
    i.direction = Direction::ForwardObservation;
    i.covariance = Covariance::Hc3Asymptotic;
    i.observation_relative_precision = Some(1.);
    let r = calibrate(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    assert!(r.estimates[0].value.is_some());
    assert!(r.estimates[0].pointwise_interval.is_none());
    assert!(!r.estimates[0].unavailable_reasons.is_empty());
}
#[test]
fn typed_and_wire_entrypoints_and_cancellation_agree() {
    let i = input();
    let request = serde_json::json!({"operation":"statistics.calibration","arguments":i});
    let raw = oracle_statistics::call(
        &request.to_string(),
        &Limits::default(),
        &AtomicBool::new(false),
    )
    .unwrap();
    let r: oracle_statistics::CalibrationResult = serde_json::from_str(&raw).unwrap();
    close(r.estimates[0].value.unwrap(), 1.);
    assert!(matches!(
        calibrate(&i, &Limits::default(), &AtomicBool::new(true)),
        Err(oracle_statistics::Error::Cancelled)
    ));
}
