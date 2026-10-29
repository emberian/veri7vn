use oracle_science::{
    call, linear, Error, Limits, LinearInput, Model, Operation, Outcome, Tolerances,
};
use std::sync::atomic::AtomicBool;

fn input(a: &[&[f64]], b: &[f64]) -> LinearInput {
    let m = a.len();
    let n = a.first().map_or(0, |r| r.len());
    LinearInput {
        matrix: a.iter().map(|r| r.to_vec()).collect(),
        rhs: b.to_vec(),
        model: Model {
            description: "authored supplied-matrix numerical test".into(),
            variable_units: vec!["1".into(); n],
            row_units: vec!["1".into(); m],
            normalization: "all rows equally weighted in these dimensionless coordinates".into(),
            assumptions: vec!["linear model with supplied fixed coefficients".into()],
        },
        tolerances: Tolerances::default(),
    }
}
fn run(p: &LinearInput, op: Operation) -> oracle_science::LinearResult {
    linear(p, op, &Limits::default(), &AtomicBool::new(false)).unwrap()
}
fn close(a: f64, b: f64, atol: f64) {
    assert!((a - b).abs() <= atol, "{a} vs {b}");
}

#[test]
fn coupled_heat_balance_with_declared_watts_and_kelvin() {
    // Two steady-state nodes: 3*T1-T2=20, -T1+2*T2=10.
    // Conductances in W/K, prescribed heat inputs in W; temperatures are
    // offsets from one declared reference, not absolute Celsius arithmetic.
    let mut p = input(&[&[3.0, -1.0], &[-1.0, 2.0]], &[20.0, 10.0]);
    p.model.variable_units = vec!["K interval".into(); 2];
    p.model.row_units = vec!["W".into(); 2];
    p.model.assumptions = vec![
        "steady state; linear fixed conductance; temperatures relative to fixed reference".into(),
    ];
    let r = run(&p, Operation::SolveLinear);
    assert_eq!(r.outcome, Outcome::ConsistentUniqueWithinTolerance);
    close(r.candidate[0], 10.0, 1e-12);
    close(r.candidate[1], 10.0, 1e-12);
    assert!(r.diagnostics.componentwise_backward_error < 1e-14);
    assert_eq!(r.model.row_units, p.model.row_units);
    assert_eq!(r.diagnostics.threads, 1);
}

#[test]
fn measured_spring_stiffness_and_offset_fit_is_not_exact_solution() {
    // Force = offset + stiffness * displacement. Values give analytic
    // OLS offset 5/6, stiffness 3/2; residual [-1/6, 1/3, -1/6].
    let mut p = input(&[&[1.0, 0.0], &[1.0, 1.0], &[1.0, 2.0]], &[1.0, 2.0, 4.0]);
    p.model.variable_units = vec!["N".into(), "N/m".into()];
    p.model.row_units = vec!["N".into(); 3];
    p.model.assumptions = vec![
        "linear response; equally weighted force observations; displacement treated as fixed"
            .into(),
    ];
    let r = run(&p, Operation::LeastSquares);
    assert_eq!(r.outcome, Outcome::LeastSquaresUniqueWithinRankPolicy);
    assert!(!r.diagnostics.equations_consistent_within_tolerance);
    close(r.candidate[0], 5.0 / 6.0, 1e-12);
    close(r.candidate[1], 1.5, 1e-12);
    for (got, expected) in r
        .diagnostics
        .residuals
        .iter()
        .zip([-1.0 / 6.0, 1.0 / 3.0, -1.0 / 6.0])
    {
        close(*got, expected, 1e-12);
    }
    assert!(r
        .diagnostics
        .normal_equation_gradient_scaled
        .iter()
        .all(|v| v.abs() < 1e-14));
    assert!(r.candidate_interpretation.contains("not an exact solution"));
    let strict = run(&p, Operation::SolveLinear);
    assert_eq!(strict.outcome, Outcome::InconsistentWithinTolerance);
    assert!(strict.candidate_interpretation.contains("least-squares"));
}

#[test]
fn rank_deficient_consistent_does_not_report_unique_coefficients() {
    let p = input(&[&[1.0, 1.0], &[2.0, 2.0]], &[2.0, 4.0]);
    let r = run(&p, Operation::SolveLinear);
    assert_eq!(r.outcome, Outcome::ConsistentUnderdeterminedWithinTolerance);
    assert_eq!(r.diagnostics.numerical_rank, 1);
    assert_eq!(r.diagnostics.nullity, 1);
    assert_eq!(r.diagnostics.condition_number_2, None);
    close(r.candidate[0], 1.0, 1e-12);
    close(r.candidate[1], 1.0, 1e-12);
}

#[test]
fn wide_system_includes_implicit_null_directions() {
    let p = input(&[&[1.0, 0.0, 1.0], &[0.0, 1.0, 0.0]], &[2.0, 3.0]);
    let r = run(&p, Operation::SolveLinear);
    assert_eq!(r.outcome, Outcome::ConsistentUnderdeterminedWithinTolerance);
    assert_eq!(r.diagnostics.nullity, 1);
    for (got, want) in r.candidate.iter().zip([1.0, 3.0, 1.0]) {
        close(*got, want, 1e-12);
    }
}

#[test]
fn inconsistent_duplicate_equations_remain_a_refused_solve() {
    let p = input(&[&[1.0, 1.0], &[1.0, 1.0]], &[2.0, 4.0]);
    let r = run(&p, Operation::SolveLinear);
    assert_eq!(r.outcome, Outcome::InconsistentWithinTolerance);
    assert_eq!(r.diagnostics.numerical_rank, 1);
    close(r.candidate[0], 1.5, 1e-12);
    close(r.candidate[1], 1.5, 1e-12);
    let fit = run(&p, Operation::LeastSquares);
    assert_eq!(
        fit.outcome,
        Outcome::LeastSquaresUnderdeterminedWithinRankPolicy
    );
}

#[test]
fn zero_matrix_distinguishes_free_variables_and_inconsistent_data() {
    let p = input(&[&[0.0, 0.0], &[0.0, 0.0]], &[0.0, 0.0]);
    let r = run(&p, Operation::SolveLinear);
    assert_eq!(r.outcome, Outcome::ConsistentUnderdeterminedWithinTolerance);
    assert_eq!(r.diagnostics.numerical_rank, 0);
    assert_eq!(r.candidate, vec![0.0, 0.0]);
    let mut q = p;
    q.rhs[0] = 1.0;
    let r = run(&q, Operation::SolveLinear);
    assert_eq!(r.outcome, Outcome::InconsistentWithinTolerance);
    close(r.diagnostics.componentwise_backward_error, 1.0, 0.0);
}

#[test]
fn bad_column_scaling_changes_numerical_identifiability_explicitly() {
    let mut p = input(&[&[1.0, 0.0], &[0.0, 1e-10]], &[1.0, 1e-10]);
    let full = run(&p, Operation::SolveLinear);
    assert_eq!(full.diagnostics.numerical_rank, 2);
    assert!(full.diagnostics.condition_number_2.unwrap() > 1e9);
    assert!(full
        .warnings
        .iter()
        .any(|w| w.contains("poorly conditioned")));
    p.tolerances.rank_relative = 1e-8;
    let truncated = run(&p, Operation::SolveLinear);
    assert_eq!(truncated.diagnostics.numerical_rank, 1);
    assert_eq!(truncated.outcome, Outcome::InconsistentWithinTolerance);
    close(truncated.diagnostics.componentwise_backward_error, 1.0, 0.0);
}

#[test]
fn global_scaling_preserves_fit_and_original_units() {
    for scale in [1e-150, 1.0, 1e150] {
        let p = input(
            &[&[2.0 * scale, scale], &[scale, -scale]],
            &[5.0 * scale, scale],
        );
        let r = run(&p, Operation::SolveLinear);
        close(r.candidate[0], 2.0, 1e-12);
        close(r.candidate[1], 1.0, 1e-12);
        assert_eq!(r.outcome, Outcome::ConsistentUniqueWithinTolerance);
        assert!(r.diagnostics.residuals.iter().all(|x| x.is_finite()));
    }
}

#[test]
fn singleton_and_zero_rhs_are_supported() {
    let r = run(&input(&[&[4.0]], &[12.0]), Operation::SolveLinear);
    close(r.candidate[0], 3.0, 1e-14);
    let r = run(
        &input(&[&[3.0, -1.0], &[2.0, 4.0]], &[0.0, 0.0]),
        Operation::SolveLinear,
    );
    assert_eq!(r.candidate, vec![0.0, 0.0]);
    assert_eq!(r.outcome, Outcome::ConsistentUniqueWithinTolerance);
}

#[test]
fn tall_exact_constraints_and_permutations_agree() {
    // Three independent observations of x=2, y=-3.
    let a = input(&[&[1.0, 0.0], &[0.0, 1.0], &[1.0, 1.0]], &[2.0, -3.0, -1.0]);
    let b = input(&[&[1.0, 1.0], &[1.0, 0.0], &[0.0, 1.0]], &[-1.0, 2.0, -3.0]);
    for p in [a, b] {
        let r = run(&p, Operation::SolveLinear);
        assert_eq!(r.outcome, Outcome::ConsistentUniqueWithinTolerance);
        close(r.candidate[0], 2.0, 1e-12);
        close(r.candidate[1], -3.0, 1e-12);
    }
}

#[test]
fn row_weighting_is_not_silently_equilibrated() {
    // min (x-1)^2 + (10*x-30)^2 gives x=301/101, not 2.
    let r = run(
        &input(&[&[1.0], &[10.0]], &[1.0, 30.0]),
        Operation::LeastSquares,
    );
    close(r.candidate[0], 301.0 / 101.0, 1e-12);
}

#[test]
fn nonfinite_ragged_empty_and_missing_units_are_rejected() {
    let original = input(&[&[1.0]], &[1.0]);
    for value in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
        let mut p = original.clone();
        p.matrix[0][0] = value;
        assert!(matches!(
            linear(
                &p,
                Operation::SolveLinear,
                &Limits::default(),
                &AtomicBool::new(false)
            ),
            Err(Error::Invalid(_))
        ));
        let mut p = original.clone();
        p.rhs[0] = value;
        assert!(matches!(
            linear(
                &p,
                Operation::SolveLinear,
                &Limits::default(),
                &AtomicBool::new(false)
            ),
            Err(Error::Invalid(_))
        ));
    }
    for p in [
        input(&[], &[]),
        input(&[&[]], &[1.0]),
        input(&[&[1.0], &[1.0, 2.0]], &[1.0, 2.0]),
        input(&[&[1.0]], &[]),
    ] {
        assert!(matches!(
            linear(
                &p,
                Operation::SolveLinear,
                &Limits::default(),
                &AtomicBool::new(false)
            ),
            Err(Error::Invalid(_))
        ));
    }
    let mut p = original;
    p.model.variable_units.clear();
    assert!(matches!(
        linear(
            &p,
            Operation::SolveLinear,
            &Limits::default(),
            &AtomicBool::new(false)
        ),
        Err(Error::Invalid(_))
    ));
}

#[test]
fn invalid_tolerances_cannot_hide_arbitrary_disagreements() {
    for value in [0.0, -1.0, 0.5, f64::NAN, f64::INFINITY] {
        let mut p = input(&[&[1.0]], &[1.0]);
        p.tolerances.consistency_relative = value;
        assert!(matches!(
            linear(
                &p,
                Operation::SolveLinear,
                &Limits::default(),
                &AtomicBool::new(false)
            ),
            Err(Error::Invalid(_))
        ));
    }
}

#[test]
fn cancellation_and_lower_operator_limits_take_effect() {
    let p = input(&[&[1.0, 0.0], &[0.0, 1.0]], &[1.0, 2.0]);
    assert!(matches!(
        linear(
            &p,
            Operation::SolveLinear,
            &Limits::default(),
            &AtomicBool::new(true)
        ),
        Err(Error::Cancelled)
    ));
    for limits in [
        Limits {
            rows: 1,
            ..Default::default()
        },
        Limits {
            columns: 1,
            ..Default::default()
        },
        Limits {
            work: 1,
            ..Default::default()
        },
        Limits {
            scratch_bytes: 0,
            ..Default::default()
        },
    ] {
        assert!(matches!(
            linear(&p, Operation::SolveLinear, &limits, &AtomicBool::new(false)),
            Err(Error::Limit(_))
        ));
    }
}

#[test]
fn raising_operator_limit_cannot_bypass_dimension_cap() {
    let p = input(&[&[1.0; oracle_science::MAX_COLUMNS + 1]], &[1.0]);
    let limits = Limits {
        columns: usize::MAX,
        ..Default::default()
    };
    assert!(matches!(
        linear(&p, Operation::SolveLinear, &limits, &AtomicBool::new(false)),
        Err(Error::Limit(_))
    ));
}

#[test]
fn unsupported_dynamic_range_and_unrepresentable_solution_are_refused() {
    for p in [
        input(&[&[1e308, 1e-308]], &[1.0]),
        input(&[&[1e-300]], &[1e300]),
    ] {
        assert!(matches!(
            linear(
                &p,
                Operation::SolveLinear,
                &Limits::default(),
                &AtomicBool::new(false)
            ),
            Err(Error::Numerical(_))
        ));
    }
}

#[test]
fn strict_json_interface_retains_scientific_contract() {
    let p = input(&[&[2.0]], &[8.0]);
    let json = serde_json::json!({"operation": "science.solve_linear", "arguments": p}).to_string();
    let reply = call(&json, &Limits::default(), &AtomicBool::new(false)).unwrap();
    let result: oracle_science::LinearResult = serde_json::from_str(&reply).unwrap();
    close(result.candidate[0], 4.0, 1e-12);
    assert_eq!(result.schema, oracle_science::SCHEMA);
    assert!(matches!(
        call(
            &json,
            &Limits {
                request_bytes: 1,
                ..Default::default()
            },
            &AtomicBool::new(false)
        ),
        Err(Error::Limit(_))
    ));
    for text in [
        "{\"operation\":\"science.mystery\",\"arguments\":{}}",
        "{\"operation\":\"science.solve_linear\",\"arguments\":{},\"extra\":true}",
        "NaN",
    ] {
        assert!(call(text, &Limits::default(), &AtomicBool::new(false)).is_err());
    }
}
