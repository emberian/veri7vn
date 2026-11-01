//! Untrusted conversational admission for caller-supplied statistical models.
//! The existing typed Pure provider owns all numerical work and checked evidence.
use crate::{
    pure::{CheckedPureReply, Pure},
    wire, Failure,
};
use oracle_execution::ExecutionContext;
use oracle_runtime_core::native_conversation::{AnchorSource, ProviderIdentity};
use oracle_runtime_core::session::NumericOrigin;
use serde_json::{json, Value};

pub const PREFIX: &str = "Model supplied data: ";
const MAX_BYTES: usize = 65_536;

fn fields(v: &Value, required: &[&str], optional: &[&str]) -> bool {
    v.as_object().is_some_and(|m| {
        required.iter().all(|k| m.contains_key(*k))
            && m.keys()
                .all(|k| required.contains(&k.as_str()) || optional.contains(&k.as_str()))
    })
}
fn label(v: &Value) -> bool {
    v.as_str()
        .is_some_and(|s| !s.trim().is_empty() && s.chars().count() <= 512 && s.len() <= 1024)
}
fn finite(v: &Value) -> bool {
    v.as_f64().is_some_and(f64::is_finite)
}
fn numbers(v: &Value, maximum: usize) -> bool {
    v.as_array()
        .is_some_and(|a| !a.is_empty() && a.len() <= maximum && a.iter().all(finite))
}
fn assumptions(v: &Value) -> bool {
    v.as_array()
        .is_some_and(|a| !a.is_empty() && a.len() <= 16 && a.iter().all(label))
}
fn positive(v: &Value) -> bool {
    v.as_f64().is_some_and(|n| n.is_finite() && n > 0.0)
}
fn exposure(v: &Value) -> bool {
    v.as_f64()
        .is_some_and(|n| n.is_finite() && n > 0.0 && n.ln().abs() <= 500.0)
}
fn counts(v: &Value, n: usize, minimum: u64) -> bool {
    v.as_array().is_some_and(|a| {
        a.len() == n
            && a.iter().all(|x| {
                x.as_u64()
                    .is_some_and(|x| (minimum..=1_000_000_000).contains(&x))
            })
    })
}
fn thermal_network(n: &Value, max_nodes: usize, max_links: usize) -> bool {
    fields(
        n,
        &[
            "description",
            "assumptions",
            "reference_temperature_k",
            "nodes",
            "links",
        ],
        &["power_tolerance_w", "tolerances"],
    ) && label(&n["description"])
        && assumptions(&n["assumptions"])
        && positive(&n["reference_temperature_k"])
        && n["nodes"]
            .as_array()
            .is_some_and(|nodes| !nodes.is_empty() && nodes.len() <= max_nodes)
        && n["links"]
            .as_array()
            .is_some_and(|links| links.len() <= max_links)
}

/// Additional conversational contract, stricter than optional native defaults.
/// Provider admission still owns covariance, solver, precision and fit semantics.
fn validate(request: &Value) -> bool {
    if !fields(request, &["operation", "arguments"], &[]) {
        return false;
    }
    let a = &request["arguments"];
    match request["operation"].as_str() {
        Some("statistics.calibration") => {
            fields(
                a,
                &[
                    "x",
                    "response",
                    "x_name",
                    "x_unit",
                    "response_unit",
                    "assumptions",
                    "covariance",
                    "direction",
                    "uncertainty",
                    "values",
                ],
                &[
                    "relative_precisions",
                    "observation_relative_precision",
                    "confidence_level",
                    "rank_relative",
                ],
            ) && numbers(&a["x"], 256)
                && numbers(&a["response"], 256)
                && a["x"].as_array().map(Vec::len) == a["response"].as_array().map(Vec::len)
                && ["x_name", "x_unit", "response_unit"]
                    .iter()
                    .all(|k| label(&a[k]))
                && assumptions(&a["assumptions"])
                && numbers(&a["values"], 32)
                && matches!(
                    a["direction"].as_str(),
                    Some("forward_mean" | "forward_observation" | "inverse_point")
                )
                && matches!(
                    a["uncertainty"].as_str(),
                    Some("point_only" | "pointwise_interval")
                )
                && matches!(
                    a["covariance"].as_str(),
                    Some("classical_normal_errors" | "hc3_asymptotic")
                )
                && (a["direction"] != "forward_observation"
                    || positive(&a["observation_relative_precision"]))
        }
        Some("statistics.events_exposure") => {
            if !fields(
                a,
                &[
                    "family",
                    "method",
                    "features",
                    "intercept",
                    "uncertainty",
                    "model",
                    "predictions",
                ],
                &[
                    "successes",
                    "trials",
                    "counts",
                    "exposures",
                    "exposure_unit",
                    "confidence_level",
                    "rank_relative",
                    "solver",
                ],
            ) || a["method"] != "maximum_likelihood"
                || !a["intercept"].is_boolean()
                || !matches!(a["uncertainty"].as_str(), Some("none" | "model_based_wald"))
            {
                return false;
            }
            let Some(rows) = a["features"]
                .as_array()
                .filter(|r| !r.is_empty() && r.len() <= 256)
            else {
                return false;
            };
            let Some(first) = rows[0].as_array() else {
                return false;
            };
            let q = first.len();
            let p = q + usize::from(a["intercept"] == true);
            if !(1..=16).contains(&p)
                || rows.iter().any(|r| {
                    !r.as_array()
                        .is_some_and(|r| r.len() == q && r.iter().all(finite))
                })
            {
                return false;
            }
            let m = &a["model"];
            if !fields(
                m,
                &[
                    "description",
                    "predictor_names",
                    "predictor_units",
                    "independent_unit",
                    "grouping",
                    "assumptions",
                ],
                &[],
            ) || !["description", "independent_unit", "grouping"]
                .iter()
                .all(|k| label(&m[k]))
                || !assumptions(&m["assumptions"])
                || !["predictor_names", "predictor_units"].iter().all(|k| {
                    m[k].as_array()
                        .is_some_and(|v| v.len() == q && v.iter().all(label))
                })
            {
                return false;
            }
            let Some(predictions) = a["predictions"]
                .as_array()
                .filter(|v| !v.is_empty() && v.len() <= 32)
            else {
                return false;
            };
            let poisson = a["family"] == "poisson_log";
            if predictions.iter().any(|r| {
                !fields(
                    r,
                    &["features", if poisson { "exposure" } else { "trials" }],
                    &[],
                ) || !r["features"]
                    .as_array()
                    .is_some_and(|v| v.len() == q && v.iter().all(finite))
                    || if poisson {
                        !exposure(&r["exposure"])
                    } else {
                        !r["trials"]
                            .as_u64()
                            .is_some_and(|n| (1..=1_000_000_000).contains(&n))
                    }
            }) {
                return false;
            }
            if poisson {
                counts(&a["counts"], rows.len(), 0)
                    && label(&a["exposure_unit"])
                    && a["exposures"]
                        .as_array()
                        .is_some_and(|v| v.len() == rows.len() && v.iter().all(exposure))
                    && a["successes"].is_null()
                    && a["trials"].is_null()
            } else {
                a["family"] == "grouped_binomial_logit"
                    && counts(&a["successes"], rows.len(), 0)
                    && counts(&a["trials"], rows.len(), 1)
                    && a["successes"]
                        .as_array()
                        .unwrap()
                        .iter()
                        .zip(a["trials"].as_array().unwrap())
                        .all(|(s, t)| s.as_u64() <= t.as_u64())
                    && ["counts", "exposures", "exposure_unit"]
                        .iter()
                        .all(|k| a[k].is_null())
            }
        }
        Some("science.thermal_network") => thermal_network(a, 128, 1024),
        Some("science.thermal_scenarios") => {
            fields(a, &["network", "scenarios"], &["sensitivities"])
                && thermal_network(&a["network"], 128, 1024)
                && a["scenarios"]
                    .as_array()
                    .is_some_and(|s| !s.is_empty() && s.len() <= 64)
        }
        Some("science.thermal_transient") => {
            if !fields(
                a,
                &[
                    "network",
                    "capacities_j_per_k",
                    "initial_temperature_k",
                    "duration_s",
                    "loads",
                    "integration",
                ],
                &["sample_times_s", "events"],
            ) || !thermal_network(&a["network"], 64, 512)
                || !positive(&a["duration_s"])
            {
                return false;
            }
            let node_count = a["network"]["nodes"].as_array().map_or(0, Vec::len);
            a["capacities_j_per_k"]
                .as_array()
                .is_some_and(|c| c.len() == node_count && c.iter().all(positive))
                && a["initial_temperature_k"].as_array().is_some_and(|t| {
                    t.len() == node_count
                        && t.iter()
                            .all(|x| x.as_f64().is_some_and(|v| v.is_finite() && v >= 0.0))
                })
                && a["loads"]
                    .as_array()
                    .is_some_and(|l| !l.is_empty() && l.len() <= 64)
                && fields(
                    &a["integration"],
                    &[
                        "initial_step_s",
                        "min_step_s",
                        "max_step_s",
                        "absolute_tolerance_k",
                        "relative_tolerance",
                        "max_steps",
                    ],
                    &[],
                )
        }
        Some("science.solve_linear" | "science.least_squares") => {
            if !fields(a, &["matrix", "rhs", "model"], &["tolerances"]) {
                return false;
            }
            let Some(rows) = a["matrix"]
                .as_array()
                .filter(|r| !r.is_empty() && r.len() <= 512)
            else {
                return false;
            };
            let Some(first) = rows[0]
                .as_array()
                .filter(|c| !c.is_empty() && c.len() <= 128)
            else {
                return false;
            };
            let m = rows.len();
            let n = first.len();
            let model = &a["model"];
            rows.iter().all(|r| {
                r.as_array()
                    .is_some_and(|r| r.len() == n && r.iter().all(finite))
            }) && a["rhs"]
                .as_array()
                .is_some_and(|rhs| rhs.len() == m && rhs.iter().all(finite))
                && fields(
                    model,
                    &[
                        "description",
                        "variable_units",
                        "row_units",
                        "normalization",
                        "assumptions",
                    ],
                    &[],
                )
                && label(&model["description"])
                && label(&model["normalization"])
                && assumptions(&model["assumptions"])
                && model["variable_units"]
                    .as_array()
                    .is_some_and(|u| u.len() == n && u.iter().all(label))
                && model["row_units"]
                    .as_array()
                    .is_some_and(|u| u.len() == m && u.iter().all(label))
        }
        Some("bio.align_pairwise") => {
            fields(
                a,
                &["query", "reference", "mode", "scoring"],
                &["ambiguity"],
            ) && a["query"]
                .as_str()
                .is_some_and(|s| !s.is_empty() && s.len() <= 4096)
                && a["reference"]
                    .as_str()
                    .is_some_and(|s| !s.is_empty() && s.len() <= 4096)
                && matches!(
                    a["mode"].as_str(),
                    Some("global" | "local" | "query_global")
                )
                && fields(
                    &a["scoring"],
                    &["match_score", "mismatch_score", "gap_open", "gap_extend"],
                    &[],
                )
        }
        Some("reasoning.optimize_linear") => {
            fields(a, &["variables", "rows", "objective"], &[])
                && a["variables"]
                    .as_array()
                    .is_some_and(|v| !v.is_empty() && v.len() <= 32 && v.iter().all(label))
                && a["rows"]
                    .as_array()
                    .is_some_and(|r| !r.is_empty() && r.len() <= 256)
                && a["objective"]
                    .as_array()
                    .is_some_and(|o| !o.is_empty() && o.len() <= 32 && o.iter().all(label))
        }
        Some("reasoning.exact_linear_feasibility") => {
            fields(a, &["variables", "rows"], &["objective"])
                && a["variables"]
                    .as_array()
                    .is_some_and(|v| !v.is_empty() && v.len() <= 32 && v.iter().all(label))
                && a["rows"]
                    .as_array()
                    .is_some_and(|r| !r.is_empty() && r.len() <= 256)
        }
        Some("graph.shortest_path") => {
            fields(a, &["vertices", "edges", "source", "target"], &[])
                && a["vertices"]
                    .as_u64()
                    .is_some_and(|v| (1..=10_000).contains(&v))
                && a["edges"].as_array().is_some_and(|e| e.len() <= 100_000)
                && a["source"].as_u64().is_some()
                && a["target"].as_u64().is_some()
        }
        Some("graph.minimum_spanning_forest") => {
            fields(a, &["vertices", "edges"], &[])
                && a["vertices"].as_u64().is_some_and(|v| v <= 10_000)
                && a["edges"].as_array().is_some_and(|e| e.len() <= 100_000)
        }
        Some("chemistry.balance_reaction") => {
            fields(a, &["species"], &[])
                && a["species"]
                    .as_array()
                    .is_some_and(|s| (2..=32).contains(&s.len()))
        }
        _ => false,
    }
}

fn refusal(reason: &str, detail: &str) -> Value {
    json!({"outcome":"completed","reply":{"status":"withheld","kind":"modeling_input","reason":reason,
        "detail":detail,"path":"native:modeling","response":detail,"authority":"computation_only"}})
}

/// None is exclusively an outside-prefix request. Every owned outcome is final.
/// The caller retains `retained` until final bounded wire encoding/commit ends.
pub fn answer(
    text: &str,
    pure: Option<&Pure>,
    tenant: &str,
    context: &ExecutionContext,
    retained: &mut Option<CheckedPureReply>,
    transition_supported: bool,
) -> Option<Result<Value, Failure>> {
    let raw = text.strip_prefix(PREFIX)?;
    Some((|| {
        if text.len() > MAX_BYTES {
            return Ok(refusal(
                "invalid_input",
                "Supplied request exceeds byte cap.",
            ));
        }
        let request=match wire::parse(raw.as_bytes()) {
            Ok(r) if validate(&r) => r,
            _ => return Ok(refusal("invalid_input","Complete bounded supplied rows, units, sampling declarations and assumptions are required; unsupported or unknown fields are refused.")),
        };
        let operation = request["operation"].as_str().expect("validated operation");
        let profile = if operation.starts_with("science.") {
            "science"
        } else if operation.starts_with("bio.") {
            "bio"
        } else if operation.starts_with("reasoning.")
            || operation.starts_with("graph.")
            || operation.starts_with("chemistry.")
        {
            "reasoning"
        } else {
            "statistics"
        };
        let pure = pure.ok_or_else(|| Failure::plain(503, "modeling_profile_unavailable"))?;
        let Some(declaration) = pure.operation_declaration(profile, operation) else {
            return Err(Failure::plain(503, "modeling_profile_unavailable"));
        };
        if crate::schema::validate(
            &request["arguments"],
            &declaration["input_schema"],
            "arguments",
        )
        .is_err()
        {
            return Ok(refusal(
                "invalid_input",
                "Supplied arguments do not meet the declared modeling input contract.",
            ));
        }
        if !transition_supported {
            return Ok(refusal("conversation_transition_unsupported","This conversation cannot replace its prior answer context without Engine projection. Use native-v1, or an ordinary conversation with no prior Engine binding."));
        }
        let checked =
            match pure.invoke_checked(profile, operation, &request["arguments"], tenant, context) {
                Ok(checked) => checked,
                Err(failure) if failure.status == 400 => {
                    return Ok(refusal(
                        "invalid_input",
                        "Supplied arguments do not meet the declared modeling input contract.",
                    ));
                }
                Err(failure) => return Err(failure),
            };
        // Delivery projection only: never decode this result back into a provider.
        let mut reply = serde_json::to_value(&checked)
            .map_err(|_| Failure::plain(502, "modeling_reply_invalid"))?;
        *retained = Some(checked);
        context.check().map_err(|error| {
            use oracle_execution::ExecutionError;
            let (status, code) = match error {
                ExecutionError::Deadline => (504, "query_timeout"),
                ExecutionError::Cancelled => (503, "query_cancelled"),
                ExecutionError::FuelExhausted => (503, "query_budget"),
                _ => (503, "execution_unavailable"),
            };
            Failure::plain(status, code)
        })?;
        let detail = reply["detail"].as_str().unwrap_or("");
        if reply["reason"] == "native_reply_invalid"
            || (reply.get("result").is_none()
                && !detail.starts_with("invalid input:")
                && !detail.starts_with("invalid type:")
                && !detail.starts_with("invalid value:")
                && !detail.starts_with("missing field")
                && !detail.starts_with("unknown field")
                && !detail.starts_with("unknown variant"))
        {
            return Err(Failure::new(
                502,
                "modeling_execution_failure",
                json!({"provider_reply":reply}),
            ));
        }
        if operation == "statistics.calibration" {
            if let Some(result) = reply.get("result") {
                let a = &request["arguments"];
                let forward = a["direction"] != "inverse_point";
                let values_bound = result["estimates"]
                    .as_array()
                    .zip(a["values"].as_array())
                    .is_some_and(|(estimates, values)| {
                        estimates.len() == values.len()
                            && estimates
                                .iter()
                                .zip(values)
                                .all(|(e, v)| e["supplied_value"].as_f64() == v.as_f64())
                    });
                if result["operation"] != operation
                    || result["direction"] != a["direction"]
                    || result["uncertainty"] != a["uncertainty"]
                    || result["fit"]["model"]["assumptions"] != a["assumptions"]
                    || !values_bound
                    || result["input_unit"] != a[if forward { "x_unit" } else { "response_unit" }]
                    || result["output_unit"] != a[if forward { "response_unit" } else { "x_unit" }]
                {
                    return Err(Failure::plain(502, "modeling_reply_binding"));
                }
            }
        }
        let answered = match reply["status"].as_str() {
            Some("answered") => true,
            Some("withheld") => false,
            _ => return Err(Failure::plain(502, "modeling_reply_invalid")),
        };
        // Extend the checked delivery in place. Provider metadata, reasons and
        // evidence stay intact, and the numerical result occurs exactly once.
        reply["kind"] = json!("supplied_modeling");
        reply["path"] = json!("native:modeling");
        reply["modeling_reason"] = json!(if answered {
            "model_result"
        } else {
            "model_refused"
        });
        reply["response"] = json!(if answered {
            match operation {
                "statistics.calibration" => {
                    "Computed the requested calibration estimates on the supplied rows and declared assumptions."
                }
                "science.thermal_scenarios" => {
                    "Evaluated the supplied steady-state thermal scenarios on the declared network and assumptions."
                }
                "science.thermal_network" => {
                    "Solved the supplied steady-state thermal network on the declared nodes, links and assumptions."
                }
                "science.thermal_transient" => {
                    "Integrated the supplied transient thermal model on the declared network, capacities and assumptions."
                }
                "science.solve_linear" | "science.least_squares" => {
                    "Computed the requested linear model solution and diagnostics on the supplied matrix, units and assumptions."
                }
                "bio.align_pairwise" => {
                    "Aligned the supplied sequences under the declared scoring model and verified optimal score replay."
                }
                "reasoning.optimize_linear" => {
                    "Solved the supplied exact linear optimization problem and verified the certificate against the original rows."
                }
                "reasoning.exact_linear_feasibility" => {
                    "Checked exact rational feasibility on the supplied linear rows and verified the certificate."
                }
                "graph.shortest_path" => {
                    "Computed the exact directed shortest-path certificate on the supplied graph."
                }
                "graph.minimum_spanning_forest" => {
                    "Computed the exact minimum spanning forest on the supplied undirected graph."
                }
                "chemistry.balance_reaction" => {
                    "Checked exact element, isotope and charge conservation on the supplied reaction species."
                }
                _ => {
                    "Fitted the declared events/exposure model to the supplied rows; predictions, diagnostics and conditional evidence are included."
                }
            }
        } else {
            "The supplied model did not establish the requested result. The provider reason and diagnostics are included."
        });
        reply["interpretation"] = json!("Conditional computation on supplied rows and declared assumptions; no model-truth or causal claim.");
        reply["supplied"] = request;
        let mut body = json!({"outcome":"completed"});
        body["reply"] = reply;
        Ok(body)
    })())
}

pub fn retained_thermal_quantity(
    reply: &Value,
) -> Option<oracle_runtime_core::native_conversation::NativeQuantity> {
    if reply["status"] != "answered" {
        return None;
    }
    let temp_k = match reply["supplied"]["operation"].as_str()? {
        "science.thermal_scenarios" => {
            let scenarios = reply["result"]["scenarios"].as_array()?;
            if scenarios.len() != 1 {
                return None;
            }
            let nodes = scenarios[0]["result"]["nodes"].as_array()?;
            let free_temps: Vec<f64> = nodes
                .iter()
                .filter(|n| n["fixed_temperature_k"].is_null())
                .filter_map(|n| n["temperature_k"].as_f64().filter(|x| x.is_finite()))
                .collect();
            if free_temps.len() == 1 {
                free_temps[0]
            } else if nodes.len() == 1 {
                nodes[0]["temperature_k"]
                    .as_f64()
                    .filter(|x| x.is_finite())?
            } else {
                return None;
            }
        }
        "science.thermal_network" => {
            let nodes = reply["result"]["nodes"].as_array()?;
            let free_temps: Vec<f64> = nodes
                .iter()
                .filter(|n| n["fixed_temperature_k"].is_null())
                .filter_map(|n| n["temperature_k"].as_f64().filter(|x| x.is_finite()))
                .collect();
            if free_temps.len() == 1 {
                free_temps[0]
            } else if nodes.len() == 1 {
                nodes[0]["temperature_k"]
                    .as_f64()
                    .filter(|x| x.is_finite())?
            } else {
                return None;
            }
        }
        "science.thermal_transient" => {
            let samples = reply["result"]["samples"].as_array()?;
            let last_temps = samples.last()?["temperature_k"].as_array()?;
            let supplied_nodes = reply["supplied"]["arguments"]["network"]["nodes"].as_array()?;
            if last_temps.len() != supplied_nodes.len() {
                return None;
            }
            let free_temps: Vec<f64> = supplied_nodes
                .iter()
                .zip(last_temps.iter())
                .filter(|(n, _)| n["fixed_temperature_k"].is_null())
                .filter_map(|(_, t)| t.as_f64().filter(|x| x.is_finite()))
                .collect();
            if free_temps.len() == 1 {
                free_temps[0]
            } else if last_temps.len() == 1 {
                last_temps[0].as_f64().filter(|x| x.is_finite())?
            } else {
                return None;
            }
        }
        _ => return None,
    };
    let quantity = oracle_runtime_core::native_conversation::NativeQuantity {
        number: temp_k.to_string(),
        unit: "K".into(),
        origin: NumericOrigin::DisplayedDecimal,
        role: oracle_runtime_core::native_conversation::QuantityRole::TemperaturePoint,
    };
    quantity.validate().ok()?;
    Some(quantity)
}

pub fn retained_reasoning_quantity(
    reply: &Value,
) -> Option<oracle_runtime_core::native_conversation::NativeQuantity> {
    if reply["status"] != "answered" {
        return None;
    }
    let number = match reply["supplied"]["operation"].as_str()? {
        "graph.shortest_path" => {
            if reply["result"]["outcome"] != "finite" {
                return None;
            }
            reply["result"]["distance"].as_str()?.to_owned()
        }
        "graph.minimum_spanning_forest" => reply["result"]["total_weight"].as_str()?.to_owned(),
        _ => return None,
    };
    let quantity = oracle_runtime_core::native_conversation::NativeQuantity {
        number,
        unit: "1".into(),
        origin: oracle_runtime_core::session::NumericOrigin::ExactDecimal,
        role: oracle_runtime_core::native_conversation::QuantityRole::Scalar,
    };
    quantity.validate().ok()?;
    Some(quantity)
}

pub fn retained_model(
    reply: &Value,
) -> Option<oracle_runtime_core::native_conversation::RetainedFittedModel> {
    if reply["status"] != "answered" {
        return None;
    }
    let model = match reply["supplied"]["operation"].as_str()? {
        "statistics.calibration" => {
            let coeffs = reply["result"]["fit"]["coefficient_candidate"].as_array()?;
            if coeffs.len() != 2 {
                return None;
            }
            let intercept = coeffs[0].as_f64().filter(|x| x.is_finite())?;
            let slope = coeffs[1].as_f64().filter(|x| x.is_finite())?;
            let args = &reply["supplied"]["arguments"];
            Some(
                oracle_runtime_core::native_conversation::RetainedFittedModel::Calibration {
                    request: "pending".into(),
                    revision: 1,
                    intercept: intercept.to_string(),
                    slope: slope.to_string(),
                    x_unit: args["x_unit"].as_str()?.to_owned(),
                    response_unit: args["response_unit"].as_str()?.to_owned(),
                    direction: args["direction"].as_str()?.to_owned(),
                    source: AnchorSource::Supplied,
                    origin: NumericOrigin::DisplayedDecimal,
                },
            )
        }
        "science.solve_linear" | "science.least_squares" => {
            if !matches!(
                reply["result"]["outcome"].as_str(),
                Some(
                    "consistent_unique_within_tolerance"
                        | "least_squares_unique_within_rank_policy"
                )
            ) {
                return None;
            }
            let candidates: Vec<String> = reply["result"]["candidate"]
                .as_array()?
                .iter()
                .map(|v| v.as_f64().filter(|x| x.is_finite()).map(|x| x.to_string()))
                .collect::<Option<Vec<String>>>()?;
            let variable_units: Vec<String> = reply["supplied"]["arguments"]["model"]
                ["variable_units"]
                .as_array()?
                .iter()
                .map(|v| v.as_str().map(str::to_owned))
                .collect::<Option<Vec<String>>>()?;
            if candidates.is_empty() || candidates.len() != variable_units.len() {
                return None;
            }
            Some(
                oracle_runtime_core::native_conversation::RetainedFittedModel::LinearSystem {
                    request: "pending".into(),
                    revision: 1,
                    candidates,
                    variable_units,
                    source: AnchorSource::Supplied,
                    origin: NumericOrigin::DisplayedDecimal,
                },
            )
        }
        "reasoning.optimize_linear" | "reasoning.exact_linear_feasibility" => {
            let status = reply["result"]["status"].as_str()?;
            if (reply["supplied"]["operation"] == "reasoning.optimize_linear"
                && status != "optimal")
                || !matches!(status, "feasible" | "optimal")
            {
                return None;
            }
            let point = reply["result"]["certificate"]["point"].as_array()?;
            let candidates: Vec<String> = point
                .iter()
                .map(|v| v.as_str().map(str::to_owned))
                .collect::<Option<Vec<String>>>()?;
            if candidates.is_empty() {
                return None;
            }
            let variable_units = vec!["1".to_owned(); candidates.len()];
            Some(
                oracle_runtime_core::native_conversation::RetainedFittedModel::LinearSystem {
                    request: "pending".into(),
                    revision: 1,
                    candidates,
                    variable_units,
                    source: AnchorSource::Supplied,
                    origin: NumericOrigin::ExactDecimal,
                },
            )
        }
        _ => None,
    }?;
    model.validate(1).ok()?;
    if ambiguous_temperature_model(reply) {
        return None;
    }
    // Leave space for the host's provider identity, final request ID and revision.
    let encoded = serde_json::to_vec(&model).ok()?;
    if encoded.len() > oracle_runtime_core::native_conversation::MAX_MODEL_BYTES - 1024 {
        return None;
    }
    Some(model)
}

fn ambiguous_temperature_model(reply: &Value) -> bool {
    let temperature_unit =
        |unit: &Value| matches!(unit.as_str(), Some("K" | "degC" | "C" | "degF" | "F"));
    let args = &reply["supplied"]["arguments"];
    match reply["supplied"]["operation"].as_str() {
        Some("statistics.calibration") => {
            temperature_unit(&args["x_unit"]) || temperature_unit(&args["response_unit"])
        }
        Some("science.solve_linear" | "science.least_squares") => args["model"]["variable_units"]
            .as_array()
            .is_some_and(|units| units.iter().any(temperature_unit)),
        _ => false,
    }
}

pub fn retention_reason(reply: &Value) -> &'static str {
    if ambiguous_temperature_model(reply) {
        "temperature_role_unspecified"
    } else if matches!(
        reply["result"]["outcome"].as_str(),
        Some(
            "consistent_underdetermined_within_tolerance"
                | "least_squares_underdetermined_within_rank_policy"
        )
    ) {
        "model_not_unique"
    } else {
        "no_bounded_unambiguous_anchor"
    }
}

/// Complete supplied-model identity, including provider build and all options.
/// This binds later arithmetic to the delivered computation, not to the graph image.
pub fn delivery_identity(reply: &Value) -> Result<ProviderIdentity, Failure> {
    let operation = reply["supplied"]["operation"]
        .as_str()
        .ok_or_else(|| Failure::plain(502, "modeling_reply_binding"))?;
    let runtime = reply["runtime_identity"]
        .as_str()
        .ok_or_else(|| Failure::plain(502, "modeling_reply_binding"))?;
    let bytes = wire::encode(&json!({"schema":"native-model-delivery-v1",
        "runtime_identity":runtime,"supplied":reply["supplied"]}));
    ProviderIdentity::from_host_delivery(operation, &crate::config::sha256_bytes(&bytes))
        .map_err(crate::native::conversation_failure)
}
