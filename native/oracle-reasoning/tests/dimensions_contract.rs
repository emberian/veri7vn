use oracle_reasoning::{
    call,
    dimensions::{
        check_candidate, optimize, Dimension, DimensionalInput, QuantityKind, VariableAnnotation,
        MAX_EXPONENT,
    },
    Error, Limits,
};

fn dim(exponents: [i16; 7]) -> Dimension {
    Dimension::new(exponents).unwrap()
}

fn input(expression: &str, variables: &[(&str, [i16; 7])]) -> DimensionalInput {
    DimensionalInput {
        expression: expression.into(),
        variables: variables
            .iter()
            .map(|(name, dimension)| VariableAnnotation {
                name: (*name).into(),
                dimension: dim(*dimension),
                kind: QuantityKind::Linear,
            })
            .collect(),
        output_dimension: None,
    }
}

const LENGTH: [i16; 7] = [1, 0, 0, 0, 0, 0, 0];
const TIME: [i16; 7] = [0, 0, 1, 0, 0, 0, 0];
const MASS: [i16; 7] = [0, 1, 0, 0, 0, 0, 0];

#[test]
fn mechanics_factoring_retains_force_and_checks_the_actual_candidate() {
    let limits = Limits::default();
    let acceleration = [1, 0, -2, 0, 0, 0, 0];
    let source = input(
        "(+ (* m a) (* m b))",
        &[("m", MASS), ("a", acceleration), ("b", acceleration)],
    );
    let result = optimize(&source, &limits).unwrap();
    assert_eq!(result.output_dimension, dim([1, 1, -2, 0, 0, 0, 0]));
    assert!(result.optimization.selected_cost < result.optimization.original_cost);
    assert_eq!(
        check_candidate(&source, &result.optimization.expression, &limits).unwrap(),
        result.output_dimension,
    );
}

#[test]
fn energy_and_chemical_amount_are_derived_from_exact_exponents() {
    let limits = Limits::default();
    let energy = input(
        "(+ (* m (* v v)) (* m (* g h)))",
        &[
            ("m", MASS),
            ("v", [1, 0, -1, 0, 0, 0, 0]),
            ("g", [1, 0, -2, 0, 0, 0, 0]),
            ("h", LENGTH),
        ],
    );
    assert_eq!(
        optimize(&energy, &limits).unwrap().output_dimension,
        dim([2, 1, -2, 0, 0, 0, 0])
    );
    let chemistry = input(
        "(+ (* c v) (* c w))",
        &[
            ("c", [-3, 0, 0, 0, 0, 1, 0]),
            ("v", [3, 0, 0, 0, 0, 0, 0]),
            ("w", [3, 0, 0, 0, 0, 0, 0]),
        ],
    );
    assert_eq!(
        optimize(&chemistry, &limits).unwrap().output_dimension,
        dim([0, 0, 0, 0, 0, 1, 0])
    );
}

#[test]
fn invalid_original_arithmetic_cannot_be_repaired_by_cancellation() {
    let limits = Limits::default();
    for expression in [
        "(+ x t)",
        "(- x t)",
        "(* 0 (+ x t))",
        "(- (+ x t) (+ x t))",
        "(+ (- x x) (- t t))",
    ] {
        let source = input(expression, &[("x", LENGTH), ("t", TIME)]);
        assert!(optimize(&source, &limits).is_err(), "{expression}");
        assert!(
            check_candidate(&source, "0", &limits).is_err(),
            "{expression}"
        );
    }
}

#[test]
fn exact_zero_is_contextual_but_dimensioned_zero_keeps_its_dimension() {
    let limits = Limits::default();
    for expression in ["(+ x 0)", "(+ x (- 1 1))", "(- x 0)"] {
        let source = input(expression, &[("x", LENGTH)]);
        assert_eq!(check_candidate(&source, "x", &limits).unwrap(), dim(LENGTH));
    }
    for expression in ["(- x x)", "(* x 0)"] {
        let source = input(expression, &[("x", LENGTH)]);
        let result = optimize(&source, &limits).unwrap();
        assert_eq!(result.output_dimension, dim(LENGTH));
        assert_eq!(check_candidate(&source, "0", &limits).unwrap(), dim(LENGTH));
    }
    let mut zero = input("(- 9 9)", &[]);
    assert_eq!(
        optimize(&zero, &limits).unwrap().output_dimension,
        Dimension::DIMENSIONLESS
    );
    zero.output_dimension = Some(dim(LENGTH));
    assert_eq!(
        optimize(&zero, &limits).unwrap().output_dimension,
        dim(LENGTH)
    );
    let invalid = input("(+ (* 0 x) t)", &[("x", LENGTH), ("t", TIME)]);
    assert!(optimize(&invalid, &limits).is_err());
}

#[test]
fn candidate_must_preserve_dimensions_and_identity_independently() {
    let limits = Limits::default();
    let source = input("(* (- x x) t)", &[("x", LENGTH), ("t", TIME)]);
    assert_eq!(
        check_candidate(&source, "0", &limits).unwrap(),
        dim([1, 0, 1, 0, 0, 0, 0])
    );
    // Both candidates are exact zero, but this one has the wrong concrete type.
    assert!(check_candidate(&source, "(- t t)", &limits).is_err());
    // The units match, but the polynomial identity is false.
    assert!(matches!(
        check_candidate(&source, "(* x t)", &limits),
        Err(Error::Check(_))
    ));
    // Cancellation inside a proposed candidate cannot conceal invalid units.
    assert!(check_candidate(&source, "(- (+ x t) (+ x t))", &limits).is_err());
}

#[test]
fn partial_zero_simplification_retains_the_original_and_reports_its_cost() {
    // One egg iteration can replace x-x with 0 before a later multiplication
    // rewrite would produce a bare contextual zero. That intermediate candidate
    // has t's dimension, so the dimensional boundary must not return it.
    let limits = Limits {
        iterations: 1,
        ..Limits::default()
    };
    let source = input("(* (- x x) t)", &[("x", LENGTH), ("t", TIME)]);
    let result = optimize(&source, &limits).unwrap();
    assert!(result.selection_fallback.is_some());
    assert_eq!(result.optimization.expression, source.expression);
    assert_eq!(
        result.optimization.selected_cost,
        result.optimization.original_cost
    );
    assert_eq!(
        check_candidate(&source, &result.optimization.expression, &limits).unwrap(),
        result.output_dimension
    );
}

#[test]
fn nonzero_integer_literals_are_dimensionless_coefficients() {
    let limits = Limits::default();
    let source = input("(* 2 x)", &[("x", LENGTH)]);
    assert_eq!(
        check_candidate(&source, "(+ x x)", &limits).unwrap(),
        dim(LENGTH)
    );
    for expression in ["(+ x 1)", "(- 1 x)"] {
        assert!(optimize(&input(expression, &[("x", LENGTH)]), &limits).is_err());
    }
}

#[test]
fn unknown_variables_are_not_treated_as_zero_even_under_zero_multiplication() {
    let limits = Limits::default();
    for expression in ["mystery", "(* 0 mystery)", "(- mystery mystery)"] {
        assert!(optimize(&input(expression, &[]), &limits).is_err());
    }
    let source = input("x", &[("x", LENGTH)]);
    assert!(check_candidate(&source, "(+ x (- mystery mystery))", &limits).is_err());
}

#[test]
fn annotation_coverage_names_duplicates_and_affine_quantities_are_rejected() {
    let limits = Limits::default();
    for source in [
        input("x", &[("x", LENGTH), ("unused", TIME)]),
        input("x", &[("x", LENGTH), ("x", TIME)]),
        input("x", &[("bad-name", LENGTH)]),
    ] {
        assert!(optimize(&source, &limits).is_err());
    }
    let mut affine = input("temperature", &[("temperature", [0, 0, 0, 0, 1, 0, 0])]);
    affine.variables[0].kind = QuantityKind::Affine;
    assert!(optimize(&affine, &limits)
        .unwrap_err()
        .to_string()
        .contains("affine"));
    affine.variables[0].kind = QuantityKind::Linear;
    assert!(optimize(&affine, &limits).is_ok());
}

#[test]
fn output_dimension_is_an_assertion_not_a_cast() {
    let limits = Limits::default();
    let mut source = input("x", &[("x", LENGTH)]);
    source.output_dimension = Some(dim(TIME));
    assert!(optimize(&source, &limits).is_err());
    let mut one = input("1", &[]);
    one.output_dimension = Some(dim(LENGTH));
    assert!(optimize(&one, &limits).is_err());
    let mut typed_zero = input("(- x x)", &[("x", LENGTH)]);
    typed_zero.output_dimension = Some(dim(TIME));
    assert!(optimize(&typed_zero, &limits).is_err());
}

#[test]
fn exponent_bounds_apply_to_annotations_and_every_original_product() {
    let limits = Limits::default();
    assert!(Dimension::new([MAX_EXPONENT + 1, 0, 0, 0, 0, 0, 0]).is_err());
    assert!(Dimension::new([-MAX_EXPONENT - 1, 0, 0, 0, 0, 0, 0]).is_err());
    for exponent in [MAX_EXPONENT, -MAX_EXPONENT] {
        let high = [exponent, 0, 0, 0, 0, 0, 0];
        assert!(optimize(&input("x", &[("x", high)]), &limits).is_ok());
        let source = input("(* x x)", &[("x", high)]);
        assert!(matches!(
            optimize(&source, &limits),
            Err(Error::Limit("SI dimension exponent"))
        ));
        let hidden = input("(* 0 (* x x))", &[("x", high)]);
        assert!(optimize(&hidden, &limits).is_err());
    }
    let inverse = input(
        "(* x y)",
        &[
            ("x", [MAX_EXPONENT, 0, 0, 0, 0, 0, 0]),
            ("y", [-MAX_EXPONENT, 0, 0, 0, 0, 0, 0]),
        ],
    );
    assert_eq!(
        optimize(&inverse, &limits).unwrap().output_dimension,
        Dimension::DIMENSIONLESS
    );
}

#[test]
fn annotations_and_numeric_zero_evaluation_obey_resource_limits() {
    let source = input("(- (* 100 100) (* 100 100))", &[]);
    let limits = Limits {
        coefficient_bits: 8,
        ..Limits::default()
    };
    assert!(optimize(&source, &limits).is_err());
    let limits = Limits {
        expression_nodes: 1,
        ..Limits::default()
    };
    let source = input("x", &[("x", LENGTH), ("y", TIME)]);
    assert!(matches!(
        optimize(&source, &limits),
        Err(Error::Limit("dimension annotations"))
    ));
}

#[test]
fn strict_json_dispatch_returns_actual_expression_and_dimension() {
    let limits = Limits::default();
    let request = serde_json::json!({
        "operation": "algebra.optimize_dimensional_polynomial",
        "arguments": {
            "expression": "(- x x)",
            "variables": [{"name": "x", "dimension": LENGTH}],
        },
    });
    let reply: serde_json::Value =
        serde_json::from_str(&call(&request.to_string(), &limits).unwrap()).unwrap();
    assert_eq!(
        reply["schema"],
        "oracle-dimensional-polynomial-optimization-v1"
    );
    assert_eq!(reply["output_dimension"], serde_json::json!(LENGTH));
    assert!(reply["expression"].is_string());
    assert_eq!(reply["dimension_order"][0], "length");
    let source: DimensionalInput = serde_json::from_value(request["arguments"].clone()).unwrap();
    assert_eq!(
        check_candidate(&source, reply["expression"].as_str().unwrap(), &limits).unwrap(),
        dim(LENGTH)
    );
}

#[test]
fn malformed_dimension_json_is_rejected_instead_of_coerced_or_ignored() {
    for annotation in [
        serde_json::json!({"name":"x", "dimension":[1,0]}),
        serde_json::json!({"name":"x", "dimension":[1,0,0,0,0,0,0,0]}),
        serde_json::json!({"name":"x", "dimension":[1.5,0,0,0,0,0,0]}),
        serde_json::json!({"name":"x", "dimension":[65,0,0,0,0,0,0]}),
        serde_json::json!({"name":"x", "dimension":[0,0,0,0,0,0,0], "unit":"Celsius"}),
        serde_json::json!({"name":"x", "dimension":[0,0,0,0,0,0,0], "kind":"celsius"}),
        serde_json::json!({"name":"x"}),
    ] {
        let value = serde_json::json!({"expression":"x", "variables":[annotation]});
        assert!(serde_json::from_value::<DimensionalInput>(value).is_err());
    }
    for value in [
        serde_json::json!({"expression":"0"}),
        serde_json::json!({"expression":"0", "variables":[], "unrecognized":true}),
        serde_json::json!({"expression":"0", "variables":[], "output_dimension":[0,0]}),
    ] {
        assert!(serde_json::from_value::<DimensionalInput>(value).is_err());
    }
}
