//! Untrusted conversational admission for caller-supplied statistical models.
//! The existing typed Pure provider owns all numerical work and checked evidence.
use crate::{
    pure::{CheckedPureReply, Pure},
    wire, Failure,
};
use oracle_execution::ExecutionContext;
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
        let pure = pure.ok_or_else(|| Failure::plain(503, "modeling_profile_unavailable"))?;
        let Some(declaration) = pure.operation_declaration("statistics", operation) else {
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
                "Supplied arguments do not meet the declared statistics input contract.",
            ));
        }
        if !transition_supported {
            return Ok(refusal("conversation_transition_unsupported","This conversation cannot replace its prior answer context without Engine projection. Use native-v1, or an ordinary conversation with no prior Engine binding."));
        }
        let checked = pure.invoke_checked(
            "statistics",
            operation,
            &request["arguments"],
            tenant,
            context,
        )?;
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
            if operation == "statistics.calibration" {
                "Computed the requested calibration estimates on the supplied rows and declared assumptions."
            } else {
                "Fitted the declared events/exposure model to the supplied rows; predictions, diagnostics and conditional evidence are included."
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

pub fn retained_model(
    reply: &Value,
) -> Option<oracle_runtime_core::native_conversation::RetainedFittedModel> {
    if reply["status"] != "answered" || reply["supplied"]["operation"] != "statistics.calibration" {
        return None;
    }
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
        },
    )
}
