use super::*;
use std::time::Duration;
fn context() -> ExecutionContext {
    ExecutionContext::new(u64::MAX, Duration::from_secs(30), Default::default()).unwrap()
}
fn untimed(value: &mut Value) {
    match value {
        Value::Object(map) => {
            map.retain(|k, _| !k.ends_with("_us"));
            for v in map.values_mut() {
                untimed(v);
            }
        }
        Value::Array(a) => {
            for v in a {
                untimed(v);
            }
        }
        _ => {}
    }
}
#[cfg(all(
    feature = "reasoning",
    feature = "statistics",
    feature = "science",
    feature = "bio",
    feature = "incremental"
))]
#[test]
fn typed_checked_profiles_match_prior_contract_examples() {
    let names = ["reasoning", "statistics", "science", "bio", "incremental"].map(str::to_owned);
    let pure = Pure::open(&names, &"a".repeat(64), None).unwrap();
    for (profile, d) in pure.declarations() {
        let id = d["id"].as_str().unwrap();
        for example in d["examples"].as_array().unwrap() {
            let args = &example["arguments"];
            let mut prior = pure
                .invoke_legacy(profile, id, args, "tenant", &context())
                .unwrap();
            let checked = pure
                .invoke_checked(profile, id, args, "tenant", &context())
                .unwrap();
            let mut actual = serde_json::to_value(checked).unwrap();
            untimed(&mut prior);
            untimed(&mut actual);
            assert_eq!(actual, prior, "{id}: {args}");
        }
    }
}
#[cfg(all(feature = "reasoning", feature = "statistics"))]
#[test]
fn typed_lp_glm_probe_has_single_decode_and_no_result_tree() {
    let pure = Pure::open(
        &["reasoning".into(), "statistics".into()],
        &"a".repeat(64),
        None,
    )
    .unwrap();
    for (profile, id) in [
        ("reasoning", "reasoning.exact_linear_feasibility"),
        ("statistics", "statistics.events_exposure"),
    ] {
        let d = pure
            .declarations()
            .into_iter()
            .find(|(_, d)| d["id"] == id)
            .unwrap()
            .1;
        let args = &d["examples"][0]["arguments"];
        probe::take();
        let checked = pure
            .invoke_checked(profile, id, args, "tenant", &context())
            .unwrap();
        let encoded = wire::EncodedReply::encode(200, &checked, 1_048_576).unwrap();
        let bytes = encoded.body();
        let probe = probe::take();
        assert_eq!(probe.input_decodes, 1);
        assert_eq!(probe.provider_envelope_counts, 1);
        assert_eq!(probe.payload_to_value, 0);
        assert_eq!(probe.result_redecodes, 0);
        assert_eq!(probe.checked_reply_serializations, 1);
        assert_eq!(wire::parse(bytes).unwrap()["status"], "answered");
        println!(
            "SOL_TYPED_PROBE_JSON {}",
            json!({"operation_id":id,"case_id":"catalog_example_0","origin":"live_typed","probe":probe,"reply_bytes":bytes.len(),"baseline_probe":null})
        );
    }
}
#[cfg(feature = "statistics")]
#[test]
fn typed_glm_rejects_nested_nonfinite_and_changed_source() {
    let pure = Pure::open(&["statistics".into()], &"a".repeat(64), None).unwrap();
    let d = pure
        .declarations()
        .into_iter()
        .find(|(_, d)| d["id"] == "statistics.events_exposure")
        .unwrap()
        .1;
    let input: oracle_statistics::glm::GlmInput = decode(&d["examples"][0]["arguments"]).unwrap();
    let catalog = oracle_statistics::catalog();
    let s = Structured {
        id: "statistics.events_exposure",
        identity: "fixture",
        catalog: &catalog,
    };
    for mutation in 0..5 {
        let mut r = oracle_statistics::glm::fit(&input, &Default::default(), &context()).unwrap();
        match mutation {
            0 => r.diagnostics.log_likelihood_kernel = f64::NAN,
            1 => r.observations[0].linear_predictor = f64::INFINITY,
            2 => {
                r.inference
                    .as_mut()
                    .expect("inference fixture")
                    .coefficients[0]
                    .standard_error = f64::NAN
            }
            3 => {
                r.inference
                    .as_mut()
                    .expect("inference fixture")
                    .coefficient_covariance[0][0] = f64::NEG_INFINITY
            }
            _ => r.supplied.features[0].push(7.0),
        }
        let checked = statistics::glm(&s, &input, r, &context());
        let actual = serde_json::to_value(checked).unwrap();
        assert_eq!(actual["status"], "withheld", "mutation {mutation}");
        assert_eq!(actual["reason"], "native_reply_invalid");
    }
}
#[cfg(feature = "reasoning")]
#[test]
fn typed_optimizer_rejects_feasible_status_and_noncanonical_witness() {
    use oracle_reasoning::{
        exact_lp::{Certificate, Output, Problem},
        Request as Q, Response as R,
    };
    let pure = Pure::open(&["reasoning".into()], &"a".repeat(64), None).unwrap();
    let p = pure.profile("reasoning").unwrap();
    let input = Problem {
        variables: vec!["x".into()],
        rows: vec![],
        objective: Some(vec!["1".into()]),
    };
    let q = Q::OptimizeLinear(input);
    for point in ["0", "01"] {
        let output = R::OptimizeLinear(Output {
            status: "feasible",
            certificate: Some(Certificate::Feasible {
                point: vec![point.into()],
            }),
            reason: None,
            assurance: "fixture",
        });
        let checked = check_reasoning(
            "reasoning.optimize_linear",
            "fixture",
            &q,
            output,
            p,
            &Value::Null,
            &context(),
        );
        assert_eq!(serde_json::to_value(checked).unwrap()["status"], "withheld");
    }
    let q = Q::ExactLinear(Problem {
        variables: vec!["x".into()],
        rows: vec![],
        objective: None,
    });
    let output = R::ExactLinear(Output {
        status: "feasible",
        certificate: Some(Certificate::Feasible {
            point: vec!["01".into()],
        }),
        reason: None,
        assurance: "fixture",
    });
    assert_eq!(
        serde_json::to_value(check_reasoning(
            "reasoning.exact_linear_feasibility",
            "fixture",
            &q,
            output,
            p,
            &Value::Null,
            &context()
        ))
        .unwrap()["status"],
        "withheld"
    );
}
#[cfg(feature = "reasoning")]
#[test]
fn descriptor_event_checks_preserve_const_arrays_and_exact_integer_bounds() {
    #[derive(Serialize)]
    struct Row {
        dimension_order: [&'static str; 2],
        size: u128,
    }
    let schema = json!({"type":"object","required":["dimension_order","size"],"properties":{"dimension_order":{"const":["length","mass"]},"size":{"type":"integer","minimum":0,"maximum":340282366920938463463374607431768211455u128}}});
    for r in [
        Row {
            dimension_order: ["length", "mass"],
            size: u128::MAX,
        },
        Row {
            dimension_order: ["mass", "length"],
            size: 1,
        },
    ] {
        assert_eq!(
            contract::check(&r, &schema),
            strict_valid(&serde_json::to_value(&r).unwrap(), &schema)
        );
    }
}

#[cfg(feature = "science")]
#[test]
fn typed_linear_rejects_operation_swap_and_nested_nonfinite() {
    use oracle_science::{Operation, ScientificRequest, ScientificResponse};
    let pure = Pure::open(&["science".into()], &"a".repeat(64), None).unwrap();
    let d = pure
        .declarations()
        .into_iter()
        .find(|(_, d)| d["id"] == "science.solve_linear")
        .unwrap()
        .1;
    let input: oracle_science::LinearInput = decode(&d["examples"][0]["arguments"]).unwrap();
    let catalog = oracle_science::catalog();
    let s = Structured {
        id: "science.solve_linear",
        identity: "fixture",
        catalog: &catalog,
    };
    for swapped in [true, false] {
        let mut r = oracle_science::execute(
            &ScientificRequest::Linear {
                input: input.clone(),
                operation: Operation::SolveLinear,
            },
            &Default::default(),
            &context(),
        )
        .unwrap();
        let ScientificResponse::Linear(linear) = &mut r else {
            unreachable!()
        };
        if swapped {
            linear.operation = Operation::LeastSquares;
        } else {
            linear.diagnostics.normal_equation_gradient_scaled[0] = f64::NAN;
        }
        let checked = science::interpret(&s, r);
        assert_eq!(
            serde_json::to_value(checked).unwrap()["reason"],
            "native_reply_invalid"
        );
    }
}
#[cfg(feature = "statistics")]
#[test]
fn typed_calibration_rejects_nonfinite_nested_fit() {
    let pure = Pure::open(&["statistics".into()], &"a".repeat(64), None).unwrap();
    let d = pure
        .declarations()
        .into_iter()
        .find(|(_, d)| d["id"] == "statistics.calibration")
        .unwrap()
        .1;
    let input: oracle_statistics::CalibrationInput =
        decode(&d["examples"][0]["arguments"]).unwrap();
    let mut reply = oracle_statistics::calibrate(&input, &Default::default(), &context()).unwrap();
    reply.fit.observations[0].residual = f64::NEG_INFINITY;
    let catalog = oracle_statistics::catalog();
    let s = Structured {
        id: "statistics.calibration",
        identity: "fixture",
        catalog: &catalog,
    };
    assert_eq!(
        serde_json::to_value(statistics::calibration(&s, reply)).unwrap()["reason"],
        "native_reply_invalid"
    );
}
