//! One admitted request remains typed through execution and independent checks.
//! Checked replies cannot be constructed by callers or deserialized from a wire.
use super::*;
use serde::ser::{SerializeMap, Serializer};

#[cfg(feature = "bio")]
mod bio;
#[cfg(feature = "reasoning")]
mod contract;
mod finite;
#[cfg(feature = "logic")]
mod logic;
#[cfg(test)]
mod probe;
#[cfg(feature = "reasoning")]
mod reasoning;
#[cfg(feature = "science")]
mod science;
#[cfg(feature = "statistics")]
mod statistics;
#[cfg(test)]
mod tests;

/// An owned checked reply. Its typed payload (including reservations) remains
/// alive until the final transport serialization has completed.
pub struct CheckedPureReply {
    metadata: serde_json::Map<String, Value>,
    result: Option<Payload>,
}
impl Serialize for CheckedPureReply {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        #[cfg(test)]
        {
            probe::serialized();
            if self.result.is_some()
                && std::any::type_name::<S::Ok>() == std::any::type_name::<Value>()
            {
                probe::materialized();
            }
        }
        let mut map = serializer.serialize_map(Some(
            self.metadata.len() + usize::from(self.result.is_some()),
        ))?;
        for (key, value) in &self.metadata {
            map.serialize_entry(key, value)?;
        }
        if let Some(result) = &self.result {
            map.serialize_entry("result", result)?;
        }
        map.end()
    }
}
#[derive(Serialize)]
#[serde(untagged)]
enum Payload {
    #[serde(skip)]
    Unavailable,
    #[cfg(feature = "reasoning")]
    Reasoning(oracle_reasoning::Response),
    #[cfg(feature = "science")]
    Science(oracle_science::ScientificResponse),
    #[cfg(feature = "bio")]
    Alignment(oracle_bio::AlignmentResult),
    #[cfg(feature = "bio")]
    Search(oracle_bio::collection::SearchResult),
    #[cfg(feature = "bio")]
    Translation(oracle_bio::translation::TranslationResult),
    #[cfg(feature = "statistics")]
    Regression(oracle_statistics::RegressionResult),
    #[cfg(feature = "statistics")]
    Calibration(oracle_statistics::CalibrationResult),
    #[cfg(feature = "statistics")]
    Glm(oracle_statistics::glm::GlmResult),
    #[cfg(feature = "statistics")]
    Sequential(oracle_statistics::sequential::SequentialResult),
    #[cfg(feature = "incremental")]
    Incremental(oracle_incremental::DependencyResponse),
    #[cfg(feature = "incremental")]
    IncrementalWrapped {
        status: &'static str,
        result: oracle_incremental::DependencyResponse,
    },
    #[cfg(feature = "incremental")]
    IncrementalError {
        status: &'static str,
        error: oracle_incremental::Error,
    },
    #[cfg(feature = "logic")]
    Logic {
        #[serde(flatten)]
        reply: oracle_logic::hosted::HostedReply,
        admitted_solver_sha256: String,
    },
}

enum Command {
    Unavailable,
    #[cfg(feature = "reasoning")]
    Reasoning(oracle_reasoning::Request),
    #[cfg(feature = "science")]
    Science(oracle_science::ScientificRequest),
    #[cfg(feature = "bio")]
    Alignment(oracle_bio::AlignmentInput),
    #[cfg(feature = "bio")]
    Search(oracle_bio::collection::SearchInput),
    #[cfg(feature = "bio")]
    Translation(oracle_bio::translation::TranslationInput),
    #[cfg(feature = "statistics")]
    Regression(oracle_statistics::RegressionInput),
    #[cfg(feature = "statistics")]
    Calibration(oracle_statistics::CalibrationInput),
    #[cfg(feature = "statistics")]
    Glm(oracle_statistics::glm::GlmInput),
    #[cfg(feature = "statistics")]
    Sequential(oracle_statistics::sequential::SequentialInput),
    #[cfg(feature = "incremental")]
    Incremental(oracle_incremental::DependencyRequest),
    #[cfg(feature = "incremental")]
    IncrementalError(oracle_incremental::Error),
    #[cfg(feature = "logic")]
    Logic(oracle_logic::Request),
}
struct Admitted<'a> {
    id: &'a str,
    profile: &'a Profile,
    arguments: &'a Value,
    identity: String,
    command: Command,
}
fn metadata(value: Value, result: Option<Payload>) -> CheckedPureReply {
    if result.as_ref().is_some_and(|r| finite::check(r).is_err()) {
        let mut rejected = json!({"status":"withheld","operation_id":value["operation_id"],"reason":"native_reply_invalid"});
        if let Some(authority) = value.get("authority") {
            rejected["authority"] = authority.clone();
        }
        return CheckedPureReply {
            metadata: rejected.as_object().expect("reply metadata").clone(),
            result: None,
        };
    }
    let mut metadata = value.as_object().expect("owned reply metadata").clone();
    metadata.remove("result");
    CheckedPureReply { metadata, result }
}
fn refused_reply(id: &str, detail: &str, authority: bool) -> CheckedPureReply {
    metadata(refused(id, detail, authority), None)
}
fn classification(id: &str, identity: &str, class: &str, payload: Payload) -> CheckedPureReply {
    metadata(
        json!({"status":"answered","operation_id":id,"classification":class,
        "authority":"computation_only","runtime_identity":identity}),
        Some(payload),
    )
}
fn withheld_reply(id: &str, reason: &str, payload: Option<Payload>) -> CheckedPureReply {
    metadata(
        json!({"status":"withheld","operation_id":id,"reason":reason,"authority":"computation_only"}),
        payload,
    )
}

impl Pure {
    /// Registry has already checked the external schema. Admission decodes each
    /// provider request once, retaining it for the kernel and reply checker.
    pub fn invoke_checked(
        &self,
        name: &str,
        id: &str,
        arguments: &Value,
        tenant: &str,
        context: &ExecutionContext,
    ) -> Result<CheckedPureReply, Failure> {
        let profile = self
            .profile(name)
            .ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
        if name == "logic"
            && arguments.pointer("/scope/tenant").and_then(Value::as_str) != Some(tenant)
        {
            return Err(Failure::plain(403, "tenant_scope_mismatch"));
        }
        // Canonical provider-envelope size is distinct from raw HTTP body size.
        // This is the sole common count; rooted/logic inner wire contracts have
        // their own different envelopes and retain their own single count.
        let bytes = envelope_size(id, arguments);
        #[cfg(test)]
        probe::envelope(bytes);
        if name == "reasoning" {
            let declaration = self
                .declaration(profile, id)
                .ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
            reasoning_arguments(id, arguments, declaration, &profile.catalog)
                .map_err(|_| Failure::plain(400, "invalid_arguments"))?;
            if bytes as u64
                > profile
                    .catalog
                    .pointer("/limits/request_bytes")
                    .and_then(Value::as_u64)
                    .unwrap_or(0)
            {
                return Err(Failure::plain(400, "invalid_arguments"));
            }
        }
        let command = match admit(name, id, arguments, bytes) {
            Ok(command) => command,
            Err(detail) => return Ok(refused_reply(id, &detail, name != "reasoning")),
        };
        let admitted = Admitted {
            id,
            profile,
            arguments,
            identity: format!("{}:{name}", self.identity_prefix),
            command,
        };
        self.execute_admitted(admitted, context)
    }

    fn execute_admitted(
        &self,
        admitted: Admitted<'_>,
        context: &ExecutionContext,
    ) -> Result<CheckedPureReply, Failure> {
        let Admitted {
            id,
            profile,
            arguments,
            identity,
            command,
        } = admitted;
        let detail =
            |e: &dyn std::fmt::Display| e.to_string().chars().take(512).collect::<String>();
        let structured = Structured {
            id,
            identity: &identity,
            catalog: &profile.catalog,
        };
        let result: Result<CheckedPureReply, String> = (|| {
            Ok(match command {
                Command::Unavailable => return Err("profile not compiled".into()),
                #[cfg(feature = "reasoning")]
                Command::Reasoning(request) => {
                    let output = oracle_reasoning::execute(&request, &Default::default(), context)
                        .map_err(|e| detail(&e))?;
                    check_reasoning(id, &identity, &request, output, profile, arguments, context)
                }
                #[cfg(feature = "statistics")]
                Command::Glm(input) => {
                    let reply = oracle_statistics::glm::fit(&input, &Default::default(), context)
                        .map_err(|e| detail(&e))?;
                    statistics::glm(&structured, &input, reply, context)
                }
                #[cfg(feature = "statistics")]
                Command::Sequential(input) => {
                    let reply =
                        oracle_statistics::sequential::replay(&input, &Default::default(), context)
                            .map_err(|e| detail(&e))?;
                    statistics::sequential(&structured, &input, reply)
                }
                #[cfg(feature = "statistics")]
                Command::Regression(input) => {
                    let reply = oracle_statistics::regress(&input, &Default::default(), context)
                        .map_err(|e| detail(&e))?;
                    statistics::regression(&structured, reply)
                }
                #[cfg(feature = "statistics")]
                Command::Calibration(input) => {
                    let reply = oracle_statistics::calibrate(&input, &Default::default(), context)
                        .map_err(|e| detail(&e))?;
                    statistics::calibration(&structured, reply)
                }
                #[cfg(feature = "science")]
                Command::Science(request) => {
                    use oracle_science::{ScientificRequest as Q, ScientificResponse as R};
                    let limits = oracle_science::Limits::default();
                    let reply = match &request {
                        Q::ThermalScenarios(input) => R::ThermalScenarios(
                            oracle_science::thermal_scenarios::thermal_scenarios_with_context(
                                input, &limits, context,
                            )
                            .map_err(|e| detail(&e))?,
                        ),
                        Q::ThermalTransient(input) => R::ThermalTransient(
                            oracle_science::thermal_transient::thermal_transient_with_context(
                                input, &limits, context,
                            )
                            .map_err(|e| detail(&e))?,
                        ),
                        _ => oracle_science::execute(&request, &limits, context)
                            .map_err(|e| detail(&e))?,
                    };
                    science::interpret(&structured, reply)
                }
                #[cfg(feature = "bio")]
                Command::Alignment(input) => bio::alignment(
                    &structured,
                    oracle_bio::align_pairwise(&input, &Default::default(), context)
                        .map_err(|e| detail(&e))?,
                ),
                #[cfg(feature = "bio")]
                Command::Search(input) => {
                    let reply = oracle_bio::collection::search_collection(&input, context)
                        .map_err(|e| detail(&e))?;
                    bio::search(&structured, &input, reply, context)
                }
                #[cfg(feature = "bio")]
                Command::Translation(input) => {
                    let reply = oracle_bio::translation::translate_intervals(&input, context)
                        .map_err(|e| detail(&e))?;
                    bio::translation(&structured, &input, reply, context)
                }
                #[cfg(feature = "incremental")]
                Command::Incremental(input) => match oracle_incremental::execute(
                    input,
                    Default::default(),
                    oracle_incremental::Strategy::Fresh,
                    context,
                ) {
                    Ok(reply) => {
                        let epochs = match &reply {
                            oracle_incremental::DependencyResponse::AllPairs(r) => &r.epochs,
                            oracle_incremental::DependencyResponse::Rooted(r) => &r.result.epochs,
                        };
                        if epochs.iter().all(|e| e.settled) {
                            classification(
                                id,
                                &identity,
                                "finite_supplied_graph_computation",
                                Payload::Incremental(reply),
                            )
                        } else {
                            withheld_reply(
                                id,
                                "native_unsettled_or_invalid_reply",
                                Some(Payload::IncrementalWrapped {
                                    status: "ok",
                                    result: reply,
                                }),
                            )
                        }
                    }
                    Err(error) => withheld_reply(
                        id,
                        "native_request_refused",
                        Some(Payload::IncrementalError {
                            status: "refused",
                            error,
                        }),
                    ),
                },
                #[cfg(feature = "incremental")]
                Command::IncrementalError(error) => withheld_reply(
                    id,
                    "native_request_refused",
                    Some(Payload::IncrementalError {
                        status: "refused",
                        error,
                    }),
                ),
                #[cfg(feature = "logic")]
                Command::Logic(input) => {
                    let solver = self
                        .solver
                        .as_ref()
                        .ok_or("Backend(\"host solver configuration\")")?;
                    let reply = oracle_logic::hosted::execute(
                        &input,
                        &solver.1,
                        &Default::default(),
                        context,
                    )
                    .map_err(|e| detail(&e))?;
                    logic::interpret(&structured, &input, reply, &solver.2)
                }
            })
        })();
        Ok(match result {
            Ok(reply) => reply,
            Err(error) => refused_reply(id, &error, profile.name != "reasoning"),
        })
    }
}

#[cfg(test)]
pub(super) fn record_decode<T>() {
    let name = std::any::type_name::<T>();
    if [
        "GlmResult",
        "SequentialResult",
        "CalibrationResult",
        "RegressionResult",
        "Certificate",
    ]
    .iter()
    .any(|end| name.ends_with(end))
    {
        probe::redecoded();
    }
}

fn decode_once<T: serde::de::DeserializeOwned>(value: &Value) -> Result<T, String> {
    #[cfg(test)]
    probe::decoded();
    decode(value)
}

fn admit(name: &str, id: &str, arguments: &Value, bytes: usize) -> Result<Command, String> {
    match name {
        #[cfg(feature = "reasoning")]
        "reasoning" => {
            use oracle_reasoning::Request as Q;
            if bytes > oracle_reasoning::Limits::default().request_bytes {
                return Err("resource limit: request bytes".into());
            }
            let command = (|| {
                Ok(match id {
                    "graph.minimum_spanning_forest" => Q::Forest(decode_once(arguments)?),
                    "graph.shortest_path" => Q::ShortestPath(decode_once(arguments)?),
                    "algebra.optimize_polynomial" => Q::Polynomial(decode_once(arguments)?),
                    "algebra.optimize_dimensional_polynomial" => {
                        Q::Dimensional(decode_once(arguments)?)
                    }
                    "algebra.simplify_rational" => Q::Rational(decode_once(arguments)?),
                    "chemistry.balance_reaction" => Q::Reaction(decode_once(arguments)?),
                    "reasoning.exact_linear_feasibility" => Q::ExactLinear(decode_once(arguments)?),
                    "reasoning.optimize_linear" => Q::OptimizeLinear(decode_once(arguments)?),
                    _ => return Err("invalid input: unknown reasoning operation".into()),
                })
            })()
            .map_err(|error: String| {
                let text = serde_json::to_string(&json!({"operation":id,"arguments":arguments}))
                    .expect("JSON value");
                serde_json::from_str::<Q>(&text)
                    .err()
                    .map_or(error, |e| format!("invalid input: request JSON: {e}"))
            })?;
            Ok(Command::Reasoning(command))
        }
        #[cfg(feature = "science")]
        "science" => {
            use oracle_science::{Operation, ScientificRequest as Q};
            if bytes
                > oracle_science::Limits::default()
                    .request_bytes
                    .min(oracle_science::MAX_REQUEST_BYTES)
            {
                return Err("resource limit: request bytes".into());
            }
            let invalid = |e| format!("invalid input: request arguments: {e}");
            Ok(Command::Science(match id {
                "science.thermal_network" => Q::Thermal(decode_once(arguments).map_err(invalid)?),
                "science.thermal_scenarios" => {
                    Q::ThermalScenarios(decode_once(arguments).map_err(invalid)?)
                }
                "science.thermal_transient" => {
                    Q::ThermalTransient(decode_once(arguments).map_err(invalid)?)
                }
                "science.solve_linear" => Q::Linear {
                    input: decode_once(arguments).map_err(invalid)?,
                    operation: Operation::SolveLinear,
                },
                "science.least_squares" => Q::Linear {
                    input: decode_once(arguments).map_err(invalid)?,
                    operation: Operation::LeastSquares,
                },
                _ => return Err("invalid input: unknown scientific operation".into()),
            }))
        }
        #[cfg(feature = "statistics")]
        "statistics" => {
            if bytes
                > oracle_statistics::Limits::default()
                    .request_bytes
                    .min(oracle_statistics::MAX_REQUEST_BYTES)
            {
                return Err("resource limit: request bytes".into());
            }
            Ok(match id {
                "statistics.linear_regression" => Command::Regression(decode_once(arguments)?),
                "statistics.calibration" => Command::Calibration(decode_once(arguments)?),
                "statistics.events_exposure" => Command::Glm(decode_once(arguments)?),
                "statistics.sequential_monitor" => Command::Sequential(decode_once(arguments)?),
                _ => return Err("invalid input: unknown statistical operation".into()),
            })
        }
        #[cfg(feature = "bio")]
        "bio" => {
            if bytes
                > oracle_bio::Limits::default()
                    .request_bytes
                    .min(oracle_bio::MAX_REQUEST_BYTES)
            {
                return Err("resource limit: request bytes".into());
            }
            Ok(match id {
                "bio.search_collection" => Command::Search(decode_once(arguments)?),
                "bio.translate_coding_intervals" => Command::Translation(decode_once(arguments)?),
                "bio.align_pairwise" => {
                    Command::Alignment(decode_once(arguments).map_err(|error| {
                        let text =
                            serde_json::to_string(&json!({"operation":id,"arguments":arguments}))
                                .expect("JSON value");
                        serde_json::from_str::<oracle_bio::Request>(&text)
                            .err()
                            .map_or(error, |e| e.to_string())
                    })?)
                }
                _ => return Err("invalid input: unknown bio operation".into()),
            })
        }
        #[cfg(feature = "incremental")]
        "incremental" => {
            let rooted;
            let input = if id == "incremental.dependencies" {
                arguments
            } else {
                let mut body = arguments.as_object().cloned().unwrap_or_default();
                body.insert("operation".into(), json!("rooted_v2"));
                rooted = Value::Object(body);
                &rooted
            };
            // These errors are represented inside the incremental result below,
            // preserving its distinct refusal envelope rather than stringifying.
            if encoded_size(input) > oracle_incremental::MAX_REQUEST_BYTES {
                return Ok(Command::IncrementalError(oracle_incremental::Error {
                    code: "request_bytes_limit".into(),
                    detail: "JSON exceeds 1 MiB".into(),
                    version: None,
                }));
            }
            let request = if input.get("operation").is_some_and(|v| !v.is_null()) {
                decode_once(input).map(oracle_incremental::DependencyRequest::Rooted)
            } else {
                decode_once(input).map(oracle_incremental::DependencyRequest::AllPairs)
            };
            Ok(match request {
                Ok(r) => Command::Incremental(r),
                Err(e) => Command::IncrementalError(oracle_incremental::Error {
                    code: "invalid_json".into(),
                    detail: e,
                    version: None,
                }),
            })
        }
        #[cfg(feature = "logic")]
        "logic" => {
            if bytes > oracle_logic::Limits::default().request_bytes {
                return Err("Limit(\"request bytes\")".into());
            }
            if arguments.get("operation").is_some() {
                return Err("Invalid(\"operation is chosen by the operation ID\")".into());
            }
            #[derive(Serialize)]
            struct Inner<'a> {
                #[serde(flatten)]
                arguments: &'a Value,
                operation: oracle_logic::Operation,
            }
            let operation = oracle_logic::hosted::operation(id)
                .ok_or("Invalid(\"unknown logic operation\")")?;
            if encoded_size(&Inner {
                arguments,
                operation,
            }) > oracle_logic::Limits::default().request_bytes
            {
                return Err("Limit(\"request bytes\")".into());
            }
            let mut request: oracle_logic::Request =
                decode_once(arguments).map_err(|_| "Invalid(\"request JSON\")".to_owned())?;
            request.operation = operation;
            Ok(Command::Logic(request))
        }
        _ => Err("profile not compiled".into()),
    }
}

#[cfg(feature = "reasoning")]
fn check_reasoning(
    id: &str,
    identity: &str,
    request: &oracle_reasoning::Request,
    output: oracle_reasoning::Response,
    profile: &Profile,
    _arguments: &Value,
    context: &ExecutionContext,
) -> CheckedPureReply {
    use oracle_reasoning::{Request as Q, Response as R};
    let maximum = match id {
        "graph.shortest_path" => catalog_row(&profile.catalog, id)
            .and_then(|r| r.pointer("/path_limits/reply_bytes"))
            .and_then(Value::as_u64)
            .map_or(MAX_REASONING_REPLY, |v| {
                (v as usize).min(MAX_REASONING_REPLY)
            }),
        "algebra.simplify_rational" => catalog_row(&profile.catalog, id)
            .and_then(|r| r.pointer("/rational_limits/formula_reply_bytes"))
            .and_then(Value::as_u64)
            .map_or(MAX_REASONING_REPLY, |v| {
                (v as usize).min(MAX_REASONING_REPLY)
            }),
        _ => MAX_REASONING_REPLY,
    };
    if encoded_size(&output) > maximum {
        return metadata(
            json!({"status":"withheld","operation_id":id,"reason":"native_reply_invalid"}),
            None,
        );
    }
    if let (
        Q::ExactLinear(input) | Q::OptimizeLinear(input),
        R::ExactLinear(reply) | R::OptimizeLinear(reply),
    ) = (request, &output)
    {
        let terminal = if id == "reasoning.optimize_linear" {
            ["optimal", "infeasible", "unbounded", "unknown"].contains(&reply.status)
        } else {
            ["feasible", "optimal", "infeasible", "unbounded", "unknown"].contains(&reply.status)
        };
        let bounded_text = !reply.assurance.is_empty()
            && reply.assurance.chars().count() <= 1024
            && reply
                .reason
                .as_ref()
                .is_none_or(|r| !r.is_empty() && r.chars().count() <= 512);
        let lexical = reply.certificate.as_ref().is_none_or(|certificate| {
            use oracle_reasoning::exact_lp::Certificate as C;
            static RATIONAL: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
            let rational = RATIONAL.get_or_init(|| {
                regex::Regex::new(r"^-?(0|[1-9][0-9]*)(/[1-9][0-9]*)?$").expect("rational grammar")
            });
            let vector = |v: &Vec<String>| {
                v.len() <= 256 && v.iter().all(|s| s.len() <= 8195 && rational.is_match(s))
            };
            match certificate {
                C::Feasible { point } => vector(point),
                C::Infeasible { multipliers } => vector(multipliers),
                C::Optimal { point, multipliers } => vector(point) && vector(multipliers),
                C::Unbounded { point, direction } => vector(point) && vector(direction),
            }
        });
        let valid = terminal
            && bounded_text
            && lexical
            && if let Some(cert) = &reply.certificate {
                oracle_reasoning::exact_lp::check_certificate_controlled(
                    input,
                    cert,
                    &Default::default(),
                    context,
                )
                .is_ok_and(|s| s == reply.status)
            } else {
                reply.status == "unknown"
            };
        if !valid {
            return metadata(
                json!({"status":"withheld","operation_id":id,"reason":"native_reply_invalid"}),
                None,
            );
        }
        let unknown = reply.status == "unknown";
        let mut header = json!({"status":if unknown{"withheld"}else{"answered"},"operation_id":id,"runtime_identity":identity,"authority":"computation_only"});
        if unknown {
            header["reason"] = json!(if id == "reasoning.optimize_linear" {
                "linear_optimization_inconclusive"
            } else {
                "exact_feasibility_inconclusive"
            });
        }
        return metadata(header, Some(Payload::Reasoning(output)));
    }
    let schema = profile
        .declarations
        .iter()
        .find(|d| d["id"] == id)
        .and_then(|d| d.pointer("/output_schema/anyOf/0/properties/result"))
        .unwrap_or(&Value::Null);
    if !contract::check(&output, schema) || !reasoning::semantic(request, &output, context) {
        return metadata(
            json!({"status":"withheld","operation_id":id,"reason":"native_reply_invalid"}),
            None,
        );
    }
    let mut header = json!({"status":"answered","operation_id":id,"runtime_identity":identity,"authority":"computation_only"});
    if id == "chemistry.balance_reaction" {
        header["scope"]=json!("Exact conservation of caller-supplied species inventories and charge only; no reaction feasibility, chemical identity, kinetics or thermodynamics claim.");
        let R::Reaction(reply) = &output else {
            unreachable!("matched request/response kind")
        };
        if matches!(
            reply.status,
            oracle_reasoning::stoichiometry::BalanceStatus::MultipleSearchInconclusive
        ) {
            header["status"] = json!("withheld");
            header["answer_kind"] = json!("search_inconclusive");
            header["reason"] = json!("positive_balance_search_inconclusive");
        } else {
            header["answer_kind"] = json!(if reply.coefficients.is_none() {
                "mathematical_negative"
            } else {
                "positive_balance"
            });
        }
    }
    metadata(header, Some(Payload::Reasoning(output)))
}
