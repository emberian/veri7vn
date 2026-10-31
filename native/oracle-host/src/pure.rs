//! Pure supplied-argument operations linked into the host (no extension, no
//! Python). Declarations come from `descriptors/pure.json`, generated from the
//! reference adapters by `tools/snapshot_descriptors.py`; the reply checks
//! below port each adapter's `interpret` (`oracle_components/native_*.py`,
//! `reasoning.py`, `logic.py`). Native refusals become withheld replies, as
//! `native_service.py` reports them. Computations are cooperative: the host
//! raises the cancel flag at the deadline and keeps the capacity slot until
//! the call returns.

use crate::config::{self, err, Artifact, ConfigError};
use crate::schema::strict_valid;
use crate::wire::{self, as_i128, is_integer};
use crate::Failure;
use oracle_execution::ExecutionContext;
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::BTreeSet;

const SNAPSHOT: &str = include_str!("../descriptors/pure.json");
const MAX_REASONING_REPLY: usize = 262144;

/// Compiled catalogs as exact text, keyed by profile.
#[allow(clippy::vec_init_then_push)] // each push is feature-gated
pub fn catalogs() -> Vec<(&'static str, String)> {
    #[allow(unused_mut)]
    let mut rows: Vec<(&'static str, String)> = Vec::new();
    #[cfg(feature = "reasoning")]
    rows.push(("reasoning", oracle_reasoning::catalog().to_string()));
    #[cfg(feature = "science")]
    rows.push(("science", oracle_science::catalog().to_string()));
    #[cfg(feature = "incremental")]
    rows.push(("incremental", oracle_incremental::catalog().to_string()));
    #[cfg(feature = "bio")]
    rows.push(("bio", oracle_bio::catalog().to_string()));
    #[cfg(feature = "statistics")]
    rows.push(("statistics", oracle_statistics::catalog().to_string()));
    #[cfg(feature = "logic")]
    rows.push(("logic", oracle_logic::hosted::catalog().to_string()));
    rows
}

struct Profile {
    name: &'static str,
    catalog: Value,
    declarations: Vec<Value>,
}

pub struct Pure {
    pub profiles: Vec<&'static str>,
    loaded: Vec<Profile>,
    identity_prefix: String,
    solver: Option<(tempfile::TempDir, std::path::PathBuf, String)>,
}

fn replace_strings(value: &mut Value, from: &str, to: &str) {
    match value {
        Value::String(s) if s.contains(from) => *s = s.replace(from, to),
        Value::Array(items) => items.iter_mut().for_each(|v| replace_strings(v, from, to)),
        Value::Object(map) => map.values_mut().for_each(|v| replace_strings(v, from, to)),
        _ => {}
    }
}

/// Copy the admitted solver into a private directory and re-hash the copy, so
/// a later replacement of the operator path cannot change what runs.
fn snapshot_solver(
    solver: &Artifact,
) -> Result<(tempfile::TempDir, std::path::PathBuf, String), ConfigError> {
    use std::os::unix::fs::PermissionsExt;
    config::admit("pure.solver", solver)?;
    let dir = tempfile::tempdir().map_err(|e| err(format!("native.solver snapshot: {e}")))?;
    let copy = dir.path().join("clingo");
    std::fs::copy(&solver.path, &copy).map_err(|e| err(format!("native.solver snapshot: {e}")))?;
    std::fs::set_permissions(&copy, std::fs::Permissions::from_mode(0o500))
        .map_err(|e| err(format!("native.solver snapshot: {e}")))?;
    let digest =
        config::sha256_file(&copy).map_err(|e| err(format!("native.solver snapshot: {e}")))?;
    if digest != solver.sha256 {
        return Err(err(
            "native.solver: snapshot digest differs from the admitted digest",
        ));
    }
    Ok((dir, copy, digest))
}

impl Pure {
    pub fn open(
        requested: &[String],
        host_sha256: &str,
        solver: Option<&Artifact>,
    ) -> Result<Self, ConfigError> {
        let snapshot = wire::parse(SNAPSHOT.as_bytes())
            .map_err(|e| err(format!("descriptor snapshot: {}", e.0)))?;
        let placeholder = snapshot["host_placeholder"]
            .as_str()
            .unwrap_or("@HOST_SHA256@")
            .to_owned();
        let solver_placeholder = snapshot["solver_placeholder"]
            .as_str()
            .unwrap_or("")
            .to_owned();
        let compiled = catalogs();
        let wants_logic = requested.iter().any(|p| p == "logic");
        if wants_logic != solver.is_some() {
            return Err(err(
                "pure.solver is required by, and only by, the logic profile",
            ));
        }
        let solver = solver.map(snapshot_solver).transpose()?;
        let mut loaded = Vec::new();
        let mut profiles = Vec::new();
        let mut seen = BTreeSet::new();
        for name in requested {
            if !seen.insert(name.as_str()) {
                return Err(err(format!("pure.profiles: duplicate profile {name}")));
            }
            let Some((name, text)) = compiled.iter().find(|(p, _)| p == name) else {
                return Err(err(format!(
                    "pure.profiles: profile {name} is not compiled into this host"
                )));
            };
            let entry = &snapshot["profiles"][*name];
            if entry["catalog_sha256"].as_str()
                != Some(config::sha256_bytes(text.as_bytes()).as_str())
            {
                return Err(err(format!(
                    "pure.profiles: {name} catalog differs from descriptors/pure.json; regenerate with tools/snapshot_descriptors.py"
                )));
            }
            let mut declarations = entry["declarations"]
                .as_array()
                .cloned()
                .unwrap_or_default();
            for declaration in &mut declarations {
                replace_strings(declaration, &placeholder, host_sha256);
                if let Some((_, _, digest)) = &solver {
                    replace_strings(declaration, &solver_placeholder, digest);
                }
            }
            let catalog = wire::parse(text.as_bytes())
                .map_err(|e| err(format!("{name} catalog: {}", e.0)))?;
            profiles.push(*name);
            loaded.push(Profile {
                name,
                catalog,
                declarations,
            });
        }
        Ok(Self {
            profiles,
            loaded,
            identity_prefix: host_sha256.to_owned(),
            solver,
        })
    }

    pub fn solver_sha256(&self) -> Option<&str> {
        self.solver.as_ref().map(|s| s.2.as_str())
    }

    pub fn declarations(&self) -> Vec<(&'static str, Value)> {
        self.loaded
            .iter()
            .flat_map(|p| p.declarations.iter().map(move |d| (p.name, d.clone())))
            .collect()
    }

    fn profile(&self, name: &str) -> Option<&Profile> {
        self.loaded.iter().find(|p| p.name == name)
    }

    fn declaration<'a>(&'a self, profile: &'a Profile, id: &str) -> Option<&'a Value> {
        profile.declarations.iter().find(|d| d["id"] == id)
    }

    pub fn invoke(
        &self,
        name: &str,
        id: &str,
        arguments: &Value,
        tenant: &str,
        context: &ExecutionContext,
    ) -> Result<Value, Failure> {
        let profile = self
            .profile(name)
            .ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
        let identity = format!("{}:{name}", self.identity_prefix);
        if name == "reasoning" {
            return self.reasoning(profile, id, arguments, &identity, context);
        }
        if name == "logic"
            && arguments.pointer("/scope/tenant").and_then(Value::as_str) != Some(tenant)
        {
            return Err(Failure::plain(403, "tenant_scope_mismatch"));
        }
        let result = match self.call(name, id, arguments, context) {
            Ok(result) => result,
            Err(detail) => return Ok(refused(id, &detail, true)),
        };
        let structured = Structured {
            id,
            identity: &identity,
            catalog: &profile.catalog,
        };
        Ok(match name {
            "science" => structured.science(&result),
            "incremental" => structured.incremental(&result),
            "bio" => structured.bio(arguments, &result, context),
            "statistics" => structured.statistics(&result),
            "logic" => structured.logic(
                arguments,
                result,
                self.solver.as_ref().map(|s| s.2.as_str()).unwrap_or(""),
            ),
            _ => return Err(Failure::plain(404, "unknown_operation")),
        })
    }

    /// Decode admitted arguments directly into each provider's domain types.
    /// The sole Value result is the public reply representation used by the
    /// independent host admission checks, never input to another provider.
    fn call(
        &self,
        name: &str,
        id: &str,
        arguments: &Value,
        context: &ExecutionContext,
    ) -> Result<Value, String> {
        self.call_typed(name, id, arguments, context)
            .map_err(|e| e.chars().take(512).collect())
    }

    #[allow(unused_variables)]
    fn call_typed(
        &self,
        name: &str,
        id: &str,
        arguments: &Value,
        context: &ExecutionContext,
    ) -> Result<Value, String> {
        let detail =
            |e: &dyn std::fmt::Display| e.to_string().chars().take(512).collect::<String>();
        let bytes = envelope_size(id, arguments);
        match name {
            #[cfg(feature = "reasoning")]
            "reasoning" => {
                use oracle_reasoning::Request;
                let limits = oracle_reasoning::Limits::default();
                if bytes > limits.request_bytes {
                    return Err("resource limit: request bytes".into());
                }
                let request = (|| -> Result<Request, String> {
                    Ok(match id {
                        "graph.minimum_spanning_forest" => Request::Forest(decode(arguments)?),
                        "graph.shortest_path" => Request::ShortestPath(decode(arguments)?),
                        "algebra.optimize_polynomial" => Request::Polynomial(decode(arguments)?),
                        "algebra.optimize_dimensional_polynomial" => {
                            Request::Dimensional(decode(arguments)?)
                        }
                        "algebra.simplify_rational" => Request::Rational(decode(arguments)?),
                        "chemistry.balance_reaction" => Request::Reaction(decode(arguments)?),
                        "reasoning.exact_linear_feasibility" => {
                            Request::ExactLinear(decode(arguments)?)
                        }
                        _ => return Err("invalid input: unknown reasoning operation".into()),
                    })
                })()
                .map_err(|error| {
                    let envelope = json!({"operation": id, "arguments": arguments});
                    let text = serde_json::to_string(&envelope).expect("JSON value");
                    match serde_json::from_str::<Request>(&text) {
                        Err(e) => format!("invalid input: request JSON: {e}"),
                        Ok(_) => error,
                    }
                })?;
                encode_result(
                    oracle_reasoning::execute(&request, &limits, context)
                        .map_err(|e| detail(&e))?,
                )
            }
            #[cfg(feature = "science")]
            "science" => {
                use oracle_science::{Operation, ScientificRequest};
                let limits = oracle_science::Limits::default();
                if bytes > limits.request_bytes.min(oracle_science::MAX_REQUEST_BYTES) {
                    return Err("resource limit: request bytes".into());
                }
                if id == "science.thermal_scenarios" {
                    return encode_result(
                        oracle_science::thermal_scenarios::thermal_scenarios_with_context(
                            &decode(arguments)
                                .map_err(|e| format!("invalid input: request arguments: {e}"))?,
                            &limits,
                            context,
                        )
                        .map_err(|e| detail(&e))?,
                    );
                }
                let request = match id {
                    "science.thermal_network" => ScientificRequest::Thermal(
                        decode(arguments)
                            .map_err(|e| format!("invalid input: request arguments: {e}"))?,
                    ),
                    "science.solve_linear" => ScientificRequest::Linear {
                        input: decode(arguments)
                            .map_err(|e| format!("invalid input: request arguments: {e}"))?,
                        operation: Operation::SolveLinear,
                    },
                    "science.least_squares" => ScientificRequest::Linear {
                        input: decode(arguments)
                            .map_err(|e| format!("invalid input: request arguments: {e}"))?,
                        operation: Operation::LeastSquares,
                    },
                    _ => return Err("invalid input: unknown scientific operation".into()),
                };
                encode_result(
                    oracle_science::execute(&request, &limits, context).map_err(|e| detail(&e))?,
                )
            }
            #[cfg(feature = "incremental")]
            "incremental" => {
                use oracle_incremental::{DependencyRequest, Limits, Strategy};
                // Rooted operation is host selected; preserve the historical
                // replacement and byte admission of that small dispatch field.
                let rooted;
                let input = if id == "incremental.dependencies" {
                    arguments
                } else {
                    let mut body = arguments.as_object().cloned().unwrap_or_default();
                    body.insert("operation".into(), json!("rooted_v2"));
                    rooted = Value::Object(body);
                    &rooted
                };
                let invalid = |code: &str, detail: String| oracle_incremental::Error {
                    code: code.into(),
                    detail,
                    version: None,
                };
                let request = if encoded_size(input) > oracle_incremental::MAX_REQUEST_BYTES {
                    Err(invalid("request_bytes_limit", "JSON exceeds 1 MiB".into()))
                } else if input.get("operation").is_some_and(|v| !v.is_null()) {
                    decode::<oracle_incremental::RootedRequest>(input)
                        .map(DependencyRequest::Rooted)
                        .map_err(|e| invalid("invalid_json", e.to_string()))
                } else {
                    decode::<oracle_incremental::Request>(input)
                        .map(DependencyRequest::AllPairs)
                        .map_err(|e| invalid("invalid_json", e.to_string()))
                };
                Ok(
                    match request.and_then(|r| {
                        oracle_incremental::execute(r, Limits::default(), Strategy::Fresh, context)
                    }) {
                        Ok(result) => json!({"status": "ok", "result": result}),
                        Err(error) => json!({"status": "refused", "error": error}),
                    },
                )
            }
            #[cfg(feature = "bio")]
            "bio" => {
                let limits = oracle_bio::Limits::default();
                if bytes > limits.request_bytes.min(oracle_bio::MAX_REQUEST_BYTES) {
                    return Err("resource limit: request bytes".into());
                }
                if id == "bio.search_collection" {
                    return encode_result(
                        oracle_bio::collection::search_collection(&decode(arguments)?, context)
                            .map_err(|e| detail(&e))?,
                    );
                }
                if id != "bio.align_pairwise" {
                    return Err("invalid input: unknown bio operation".into());
                }
                let input = decode(arguments).map_err(|error| {
                    let text =
                        serde_json::to_string(&json!({"operation": id, "arguments": arguments}))
                            .expect("JSON value");
                    serde_json::from_str::<oracle_bio::Request>(&text)
                        .err()
                        .map_or(error, |e| e.to_string())
                })?;
                encode_result(
                    oracle_bio::align_pairwise(&input, &limits, context).map_err(|e| detail(&e))?,
                )
            }
            #[cfg(feature = "statistics")]
            "statistics" => {
                let limits = oracle_statistics::Limits::default();
                if bytes
                    > limits
                        .request_bytes
                        .min(oracle_statistics::MAX_REQUEST_BYTES)
                {
                    return Err("resource limit: request bytes".into());
                }
                match id {
                    "statistics.linear_regression" => encode_result(
                        oracle_statistics::regress(&decode(arguments)?, &limits, context)
                            .map_err(|e| detail(&e))?,
                    ),
                    "statistics.calibration" => encode_result(
                        oracle_statistics::calibrate(&decode(arguments)?, &limits, context)
                            .map_err(|e| detail(&e))?,
                    ),
                    _ => Err("invalid input: unknown statistical operation".into()),
                }
            }
            #[cfg(feature = "logic")]
            "logic" => {
                let limits = oracle_logic::Limits::default();
                if bytes > limits.request_bytes {
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
                }) > limits.request_bytes
                {
                    return Err("Limit(\"request bytes\")".into());
                }
                let mut request: oracle_logic::Request =
                    decode(arguments).map_err(|_| "Invalid(\"request JSON\")".to_owned())?;
                request.operation = oracle_logic::hosted::operation(id)
                    .ok_or("Invalid(\"unknown logic operation\")")?;
                let solver = self
                    .solver
                    .as_ref()
                    .ok_or("Backend(\"host solver configuration\")")?;
                encode_result(
                    oracle_logic::hosted::execute(&request, &solver.1, &limits, context)
                        .map_err(|e| detail(&e))?,
                )
            }
            _ => Err("profile not compiled".into()),
        }
    }

    fn reasoning(
        &self,
        profile: &Profile,
        id: &str,
        arguments: &Value,
        identity: &str,
        context: &ExecutionContext,
    ) -> Result<Value, Failure> {
        let declaration = self
            .declaration(profile, id)
            .ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
        let invalid = || Failure::plain(400, "invalid_arguments");
        reasoning_arguments(id, arguments, declaration, &profile.catalog).map_err(|_| invalid())?;
        let request_bytes = profile
            .catalog
            .pointer("/limits/request_bytes")
            .and_then(Value::as_u64)
            .unwrap_or(0);
        if envelope_size(id, arguments) as u64 > request_bytes {
            return Err(invalid());
        }
        let result = match self.call("reasoning", id, arguments, context) {
            Ok(result) => result,
            Err(detail) => return Ok(refused(id, &detail, false)),
        };
        let row = |key: &str| {
            catalog_row(&profile.catalog, id)
                .and_then(|r| r.pointer(key))
                .and_then(Value::as_u64)
        };
        let maximum = match id {
            "graph.shortest_path" => row("/path_limits/reply_bytes")
                .map_or(MAX_REASONING_REPLY, |n| {
                    (n as usize).min(MAX_REASONING_REPLY)
                }),
            "algebra.simplify_rational" => row("/rational_limits/formula_reply_bytes")
                .map_or(MAX_REASONING_REPLY, |n| {
                    (n as usize).min(MAX_REASONING_REPLY)
                }),
            _ => MAX_REASONING_REPLY,
        };
        let results = declaration
            .pointer("/output_schema/anyOf/0/properties/result")
            .cloned()
            .unwrap_or(Value::Null);
        let checked = (|| -> Option<Value> {
            if encoded_size(&result) > maximum {
                return None;
            }
            if !strict_valid(&result, &results) {
                return None;
            }
            match id {
                "graph.shortest_path" => check_path(arguments, &result)?,
                "chemistry.balance_reaction" => check_chemistry(arguments, &result)?,
                "reasoning.exact_linear_feasibility" => {
                    let status = result["status"].as_str()?;
                    let certificate = &result["certificate"];
                    if (status == "unknown") != certificate.is_null()
                        || (!certificate.is_null() && certificate["kind"] != status)
                    {
                        return None;
                    }
                    #[cfg(feature = "reasoning")]
                    if !certificate.is_null() {
                        let problem =
                            decode::<oracle_reasoning::exact_lp::Problem>(arguments).ok()?;
                        let certificate =
                            decode::<oracle_reasoning::exact_lp::Certificate>(certificate).ok()?;
                        if oracle_reasoning::exact_lp::check_certificate_controlled(
                            &problem,
                            &certificate,
                            &Default::default(),
                            context,
                        )
                        .ok()?
                            != status
                        {
                            return None;
                        }
                    }
                }
                "algebra.simplify_rational" => check_rational(arguments, &result)?,
                _ => {}
            }
            Some(result)
        })();
        let Some(result) = checked else {
            return Ok(
                json!({"status": "withheld", "operation_id": id, "reason": "native_reply_invalid"}),
            );
        };
        let mut reply = json!({"status": "answered", "operation_id": id, "result": result,
                               "runtime_identity": identity, "authority": "computation_only"});
        if id == "reasoning.exact_linear_feasibility" && reply["result"]["status"] == "unknown" {
            reply["status"] = json!("withheld");
            reply["reason"] = json!("exact_feasibility_inconclusive");
        }
        if id == "chemistry.balance_reaction" {
            reply["scope"] = json!("Exact conservation of caller-supplied species inventories and charge only; no reaction feasibility, chemical identity, kinetics or thermodynamics claim.");
            if reply["result"]["status"] == "multiple_search_inconclusive" {
                reply["status"] = json!("withheld");
                reply["answer_kind"] = json!("search_inconclusive");
                reply["reason"] = json!("positive_balance_search_inconclusive");
            } else {
                reply["answer_kind"] = json!(if reply["result"]["coefficients"].is_null() {
                    "mathematical_negative"
                } else {
                    "positive_balance"
                });
            }
        }
        Ok(reply)
    }
}

fn refused(id: &str, detail: &str, computation_only: bool) -> Value {
    let mut reply =
        json!({"status": "withheld", "operation_id": id, "reason": "native_request_refused"});
    if !detail.is_empty() {
        reply["detail"] = json!(detail);
    }
    if computation_only {
        reply["authority"] = json!("computation_only");
    }
    reply
}

/// Byte admission without materializing and reparsing an internal JSON string.
fn encoded_size<T: Serialize + ?Sized>(value: &T) -> usize {
    struct Counter(usize);
    impl std::io::Write for Counter {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            self.0 = self.0.saturating_add(bytes.len());
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut counter = Counter(0);
    if serde_json::to_writer(&mut counter, value).is_err() {
        return usize::MAX;
    }
    counter.0
}
fn envelope_size(operation: &str, arguments: &Value) -> usize {
    #[derive(Serialize)]
    struct Envelope<'a> {
        operation: &'a str,
        arguments: &'a Value,
    }
    encoded_size(&Envelope {
        operation,
        arguments,
    })
}
fn decode<T: serde::de::DeserializeOwned>(arguments: &Value) -> Result<T, String> {
    T::deserialize(arguments).map_err(|error| {
        // Error-only compatibility: old wire refusals include parser line and
        // column. This decodes rejected data solely to format its diagnostic;
        // no provider execution or second admission attempt occurs here.
        let text = serde_json::to_string(arguments).expect("JSON value");
        let error = serde_json::from_str::<T>(&text).err().unwrap_or(error);
        error.to_string().chars().take(512).collect()
    })
}

fn encode_result<T: Serialize>(result: T) -> Result<Value, String> {
    serde_json::to_value(result).map_err(|e| e.to_string().chars().take(512).collect())
}

fn catalog_row<'a>(catalog: &'a Value, id: &str) -> Option<&'a Value> {
    catalog["operations"]
        .as_array()?
        .iter()
        .find(|r| r["id"] == id)
}

fn int(value: &Value) -> Option<i128> {
    as_i128(value)
}

fn is_finite_number(value: &Value) -> bool {
    value.is_number() // the strict decoder admits only finite numbers
}

/// `NativeStructuredOperations` answered/withheld shapes.
struct Structured<'a> {
    id: &'a str,
    identity: &'a str,
    catalog: &'a Value,
}

impl Structured<'_> {
    fn withheld(&self, reason: &str, result: Option<Value>) -> Value {
        let mut reply = json!({"status": "withheld", "operation_id": self.id, "reason": reason,
                               "authority": "computation_only"});
        if let Some(result) = result {
            reply["result"] = result;
        }
        reply
    }

    fn answered(&self, result: Value, classification: &str) -> Value {
        json!({"status": "answered", "operation_id": self.id, "result": result,
               "classification": classification, "authority": "computation_only",
               "runtime_identity": self.identity})
    }

    fn invalid(&self) -> Value {
        self.withheld("native_reply_invalid", None)
    }

    fn science(&self, result: &Value) -> Value {
        if self.id == "science.thermal_scenarios" {
            return self.thermal_scenarios(result);
        }
        let outcome = result.get("outcome").and_then(Value::as_str).unwrap_or("");
        let thermal = self.id == "science.thermal_network";
        let has = |keys: &[&str]| keys.iter().all(|k| result.get(*k).is_some());
        let valid = if thermal {
            has(&[
                "operation",
                "nodes",
                "links",
                "components",
                "conservation",
                "linear_diagnostics",
                "warnings",
            ]) && result["operation"] == self.id
                && result["nodes"].is_array()
                && result["conservation"].is_object()
        } else {
            has(&[
                "operation",
                "candidate",
                "candidate_interpretation",
                "diagnostics",
                "model",
                "tolerances",
                "warnings",
            ]) && result["operation"].as_str() == self.id.strip_prefix("science.")
                && result["candidate"]
                    .as_array()
                    .is_some_and(|c| !c.is_empty() && c.iter().all(is_finite_number))
                && result["diagnostics"].as_object().is_some_and(|d| {
                    [
                        "numerical_rank",
                        "nullity",
                        "residuals",
                        "equations_consistent_within_tolerance",
                    ]
                    .iter()
                    .all(|k| d.contains_key(*k))
                })
        };
        if !valid {
            return self.invalid();
        }
        let linear = [
            "consistent_unique_within_tolerance",
            "consistent_underdetermined_within_tolerance",
            "inconsistent_within_tolerance",
            "least_squares_unique_within_rank_policy",
            "least_squares_underdetermined_within_rank_policy",
        ];
        let thermals = [
            "solved_within_tolerance",
            "underdetermined_within_tolerance",
            "inconsistent_within_tolerance",
            "numerical_rank_unresolved",
            "below_absolute_zero_candidate",
        ];
        let allowed: &[&str] = if thermal { &thermals } else { &linear };
        if result.get("schema") != self.catalog.get("schema") || !allowed.contains(&outcome) {
            return self.invalid();
        }
        if [
            "inconsistent_within_tolerance",
            "numerical_rank_unresolved",
            "below_absolute_zero_candidate",
        ]
        .contains(&outcome)
        {
            return self.withheld(outcome, Some(result.clone()));
        }
        let classification = if outcome.contains("underdetermined") {
            "numerical_underdetermined"
        } else {
            "numerical"
        };
        self.answered(result.clone(), classification)
    }

    fn thermal_scenarios(&self, result: &Value) -> Value {
        let Some(scenarios) = result["scenarios"].as_array() else {
            return self.invalid();
        };
        let Some(sensitivities) = result["sensitivities"].as_array() else {
            return self.invalid();
        };
        let Some(nodes) = result["node_order"].as_array() else {
            return self.invalid();
        };
        if result.get("schema") != self.catalog.get("schema")
            || result["operation"] != self.id
            || scenarios.is_empty()
            || scenarios.len() > 64
            || sensitivities.len() > 128
            || nodes.is_empty()
            || !result["network_identity"]
                .as_str()
                .is_some_and(|s| s.starts_with("sha256:"))
            || !matches!(result["factorization_count"].as_u64(), Some(0 | 1))
            || ["scenario_rhs_solves", "sensitivity_rhs_solves", "warnings"]
                .iter()
                .any(|k| result.get(*k).is_none())
        {
            return self.invalid();
        }
        let nested = Structured {
            id: "science.thermal_network",
            identity: self.identity,
            catalog: self.catalog,
        };
        let mut accepted = true;
        for scenario in scenarios {
            if !scenario.is_object()
                || !scenario["id"].is_string()
                || !scenario["result"].is_object()
            {
                return self.invalid();
            }
            let checked = nested.science(&scenario["result"]);
            if checked["reason"] == "native_reply_invalid" {
                return self.invalid();
            }
            accepted &= checked["status"] == "answered"
                && scenario["result"]["outcome"] == "solved_within_tolerance";
        }
        for derivative in sensitivities {
            if !derivative.is_object()
                || !derivative["temperature_derivative"]
                    .as_array()
                    .is_some_and(|d| d.len() == nodes.len() && d.iter().all(is_finite_number))
            {
                return self.invalid();
            }
        }
        if !accepted {
            return self.withheld("scenario_not_accepted", Some(result.clone()));
        }
        self.answered(result.clone(), "numerical_scenarios")
    }

    fn incremental(&self, result: &Value) -> Value {
        if result["status"] == "refused" && result["error"].is_object() {
            return self.withheld("native_request_refused", Some(result.clone()));
        }
        if result["status"] != "ok" || !result["result"].is_object() {
            return self.invalid();
        }
        let body = &result["result"];
        let graph = if self.id == "incremental.rooted_dependencies" {
            &body["result"]
        } else {
            body
        };
        let settled = graph["epochs"].as_array().is_some_and(|epochs| {
            epochs
                .iter()
                .all(|e| e.is_object() && e["settled"] == Value::Bool(true))
        });
        if !graph.is_object() || !settled {
            return self.withheld("native_unsettled_or_invalid_reply", Some(result.clone()));
        }
        self.answered(body.clone(), "finite_supplied_graph_computation")
    }

    fn bio(&self, arguments: &Value, result: &Value, context: &ExecutionContext) -> Value {
        if self.id == "bio.search_collection" {
            return match check_collection(arguments, result, context) {
                Ok(Some(())) => self.answered(result.clone(), "exact_supplied_dna_page"),
                Ok(None) => self.invalid(),
                Err(_) => self.withheld("native_reply_check_budget_exhausted", None),
            };
        }
        let candidate = &result["candidate"];
        let checks = &result["checks"];
        let score = candidate.get("score").filter(|v| is_integer(v));
        let valid = result.get("schema") == self.catalog.get("schema")
            && candidate.is_object()
            && checks.is_object()
            && score.is_some()
            && checks.get("replayed_score").is_some_and(is_integer)
            && checks
                .get("independently_computed_optimal_score")
                .is_some_and(is_integer)
            && score.and_then(int) == int(&checks["replayed_score"])
            && score.and_then(int) == int(&checks["independently_computed_optimal_score"])
            && candidate["operations"].as_array().is_some_and(|ops| {
                ops.iter().all(|e| {
                    ["match", "substitution", "insertion", "deletion"]
                        .iter()
                        .any(|k| e == k)
                })
            })
            && ["global", "local", "query_global"]
                .iter()
                .any(|m| result["mode"] == *m)
            && ["reject", "always_mismatch"]
                .iter()
                .any(|m| result["ambiguity"] == *m)
            && ["query_length", "reference_length"]
                .iter()
                .all(|k| int(&result[*k]).is_some_and(|n| n >= 1));
        if !valid {
            return self.invalid();
        }
        for prefix in ["query", "reference"] {
            let (start, end, length) = (
                int(&candidate[format!("{prefix}_start")]),
                int(&candidate[format!("{prefix}_end")]),
                int(&result[format!("{prefix}_length")]),
            );
            match (start, end, length) {
                (Some(s), Some(e), Some(n)) if 0 <= s && s <= e && e <= n => {}
                _ => return self.invalid(),
            }
        }
        self.answered(
            result.clone(),
            "integer_alignment_with_independent_score_checks",
        )
    }

    fn statistics(&self, result: &Value) -> Value {
        if self.id == "statistics.calibration" {
            return self.calibration(result);
        }
        let beta = result["coefficient_candidate"].as_array();
        let diagnostics = &result["diagnostics"];
        let outcome = result["outcome"].as_str().unwrap_or("");
        let inference = &result["inference"];
        let reasons = result["inference_unavailable_reasons"].as_array();
        let valid = result.get("schema") == self.catalog.get("schema")
            && result["operation"] == self.id
            && [
                "rank_deficient_fit",
                "fit_without_inference",
                "fit_with_conditional_inference",
            ]
            .contains(&outcome)
            && beta.is_some_and(|b| !b.is_empty() && b.iter().all(is_finite_number))
            && diagnostics.is_object()
            && int(&diagnostics["parameters"]) == beta.map(|b| b.len() as i128)
            && result["observations"].is_array()
            && int(&diagnostics["observations"])
                == result["observations"].as_array().map(|o| o.len() as i128)
            && result["predictions"].is_array()
            && result["model"].is_object()
            && reasons.is_some_and(|r| r.iter().all(|x| x.as_str().is_some_and(|s| !s.is_empty())));
        if !valid {
            return self.invalid();
        }
        let p = beta.map_or(0, |b| b.len()) as i128;
        let (rank, n, df) = (
            int(&diagnostics["numerical_rank"]),
            int(&diagnostics["observations"]),
            int(&diagnostics["residual_degrees_of_freedom"]),
        );
        let (Some(rank), Some(n), Some(df)) = (rank, n, df) else {
            return self.invalid();
        };
        if !(0 <= rank && rank <= p.min(n))
            || df != n - rank
            || (outcome == "rank_deficient_fit") != (rank < p)
        {
            return self.invalid();
        }
        let reasons = reasons.expect("checked");
        let classification = if outcome == "fit_with_conditional_inference" {
            let assumptions = inference["required_assumptions"].as_array();
            if !inference.is_object()
                || !reasons.is_empty()
                || df <= 0
                || !assumptions.is_some_and(|a| {
                    !a.is_empty() && a.iter().all(|x| x.as_str().is_some_and(|s| !s.is_empty()))
                })
                || inference["coefficients"]
                    .as_array()
                    .map(|c| c.len() as i128)
                    != Some(p)
            {
                return self.invalid();
            }
            "numerical_fit_with_conditional_inference"
        } else {
            if !inference.is_null() || reasons.is_empty() {
                return self.invalid();
            }
            if outcome == "rank_deficient_fit" {
                "numerical_unidentifiable_fit"
            } else {
                "numerical_fit_without_inference"
            }
        };
        self.answered(result.clone(), classification)
    }

    fn calibration(&self, result: &Value) -> Value {
        let direction = result["direction"].as_str().unwrap_or("");
        let uncertainty = result["uncertainty"].as_str().unwrap_or("");
        let fit = &result["fit"];
        let Some(estimates) = result["estimates"].as_array() else {
            return self.invalid();
        };
        let maximum = self
            .catalog
            .pointer("/limits/predictions")
            .and_then(Value::as_u64)
            .unwrap_or(0);
        if result.get("schema") != self.catalog.get("schema")
            || result["operation"] != self.id
            || !["forward_mean", "forward_observation", "inverse_point"].contains(&direction)
            || !["point_only", "pointwise_interval"].contains(&uncertainty)
            || estimates.is_empty()
            || estimates.len() as u64 > maximum
            || ["input_unit", "output_unit", "interpretation", "assurance"]
                .iter()
                .any(|k| !result[*k].as_str().is_some_and(|s| !s.is_empty()))
        {
            return self.invalid();
        }
        let nested = Structured {
            id: "statistics.linear_regression",
            identity: self.identity,
            catalog: self.catalog,
        };
        if nested.statistics(fit)["status"] != "answered"
            || fit["coefficient_candidate"].as_array().map(Vec::len) != Some(2)
        {
            return self.invalid();
        }
        let admitted = int(&fit["diagnostics"]["numerical_rank"]) == Some(2)
            && fit["diagnostics"]["condition_number_2"]
                .as_f64()
                .is_some_and(|c| c.is_finite() && (1.0..=1e8).contains(&c));
        for estimate in estimates {
            let value = &estimate["value"];
            let interval = &estimate["pointwise_interval"];
            let Some(reasons) = estimate["unavailable_reasons"].as_array() else {
                return self.invalid();
            };
            if !estimate.is_object()
                || !is_finite_number(&estimate["supplied_value"])
                || (!value.is_null() && !is_finite_number(value))
                || estimate["unit"] != result["output_unit"]
                || !estimate["outside_training_range"].is_boolean()
                || reasons
                    .iter()
                    .any(|r| !r.as_str().is_some_and(|s| !s.is_empty()))
                || (value.is_null() && reasons.is_empty())
                || (!value.is_null() && !admitted)
                || (!interval.is_null() && fit["inference"].is_null())
                || (!interval.is_null()
                    && !interval.as_array().is_some_and(|a| {
                        a.len() == 2
                            && a.iter().all(is_finite_number)
                            && a[0].as_f64() <= a[1].as_f64()
                            && !value.is_null()
                    }))
                || (uncertainty == "point_only" && !interval.is_null())
                || (uncertainty == "pointwise_interval" && interval.is_null() && reasons.is_empty())
                || (direction == "inverse_point" && !interval.is_null())
                || (direction == "inverse_point"
                    && uncertainty == "pointwise_interval"
                    && !value.is_null())
            {
                return self.invalid();
            }
        }
        if estimates.iter().all(|e| e["value"].is_null()) {
            return self.withheld("calibration_unavailable", Some(result.clone()));
        }
        self.answered(
            result.clone(),
            "numerical_calibration_conditional_on_supplied_model",
        )
    }

    fn logic(&self, arguments: &Value, result: Value, solver: &str) -> Value {
        if !logic_valid(self.id, arguments, &result) {
            return self.invalid();
        }
        let mut result = result;
        result["admitted_solver_sha256"] = json!(solver);
        match result["status"].as_str() {
            Some("inconclusive") => self.withheld("inconclusive", Some(result)),
            Some("inconsistent") => self.answered(
                result,
                "inconsistent_solver_trusted_absence_of_stable_models",
            ),
            _ if self.id == "logic.enumerate" => self.answered(
                result,
                "enumerated_checked_models_solver_trusted_completeness",
            ),
            _ => self.answered(result, "checked_witnesses_solver_trusted_absence"),
        }
    }
}

fn hex64(value: &Value) -> bool {
    value.as_str().is_some_and(config::is_hash)
}

fn logic_valid(id: &str, arguments: &Value, result: &Value) -> bool {
    let (Some(models), Some(answers)) = (result["models"].as_array(), result["answers"].as_array())
    else {
        return false;
    };
    let status = result["status"].as_str().unwrap_or("");
    if result["schema"] != "oracle-logic-experimental-v1"
        || result["operation_id"] != id
        || !["consistent", "inconsistent", "inconclusive"].contains(&status)
        || result.get("scope") != arguments.get("scope")
        || !hex64(&result["program_identity"])
        || !hex64(&result["request_identity"])
        || !result["enumeration_complete"].is_boolean()
        || result["witness_check"] != "handwritten_gl_reduct"
    {
        return false;
    }
    let atoms = arguments["atoms"].as_array().map_or(0, Vec::len) as i128;
    let mut sets = Vec::new();
    for model in models {
        let Some(items) = model.as_array() else {
            return false;
        };
        let mut previous = -1;
        let mut set = BTreeSet::new();
        for atom in items {
            let Some(a) = (is_integer(atom)).then(|| int(atom)).flatten() else {
                return false;
            };
            if !(0..atoms).contains(&a) || a <= previous {
                return false; // must equal sorted(set(model))
            }
            previous = a;
            set.insert(a);
        }
        sets.push(set);
    }
    let queries = arguments["queries"].as_array().cloned().unwrap_or_default();
    if answers.len() != queries.len()
        || answers.iter().zip(&queries).any(|(a, q)| {
            !a.is_object() || !crate::wire::numbers_equal(&a["atom"], q) || !is_integer(&a["atom"])
        })
    {
        return false;
    }
    if status == "inconsistent" && !models.is_empty() {
        return false;
    }
    if id == "logic.query" && result["enumeration_complete"] == Value::Bool(true) {
        return false;
    }
    for answer in answers {
        let (skeptical, credulous) = (&answer["skeptical"], &answer["credulous"]);
        if status == "inconsistent" && (!skeptical.is_null() || !credulous.is_null()) {
            return false;
        }
        if status == "consistent" && (!skeptical.is_boolean() || !credulous.is_boolean()) {
            return false;
        }
        let atom = int(&answer["atom"]).unwrap_or(-1);
        for (key, present) in [("true_witness", true), ("false_witness", false)] {
            let index = &answer[key];
            if index.is_null() || answer.get(key).is_none() {
                continue;
            }
            let Some(i) = is_integer(index).then(|| int(index)).flatten() else {
                return false;
            };
            if i < 0 || i as usize >= sets.len() || sets[i as usize].contains(&atom) != present {
                return false;
            }
        }
        if (skeptical == &Value::Bool(true) && !answer["false_witness"].is_null())
            || (credulous == &Value::Bool(false) && !answer["true_witness"].is_null())
        {
            return false;
        }
    }
    true
}

/// `ReasoningOperations._validate_arguments`, after the schema check.
fn reasoning_arguments(
    id: &str,
    arguments: &Value,
    declaration: &Value,
    catalog: &Value,
) -> Result<(), ()> {
    let schema = &declaration["input_schema"];
    let args = arguments.as_object().ok_or(())?;
    let properties = schema["properties"].as_object().ok_or(())?;
    let required: Vec<&str> = schema["required"]
        .as_array()
        .map_or(vec![], |r| r.iter().filter_map(Value::as_str).collect());
    if !required.iter().all(|k| args.contains_key(*k))
        || !args.keys().all(|k| properties.contains_key(k))
    {
        return Err(());
    }
    let limits = &catalog["limits"];
    let limit = |k: &str| limits[k].as_u64().unwrap_or(0) as i128;
    let label = regex::Regex::new(r"^[A-Z][a-z]?(?:-[1-9][0-9]{0,2})?$").expect("constant");
    let name_re = regex::Regex::new(r"^[A-Za-z_][A-Za-z0-9_]*$").expect("constant");
    if id == "reasoning.exact_linear_feasibility" {
        if !strict_valid(arguments, schema) {
            return Err(());
        }
        let variables = args["variables"].as_array().ok_or(())?;
        let rows = args["rows"].as_array().ok_or(())?;
        let names: BTreeSet<_> = variables.iter().filter_map(Value::as_str).collect();
        let ids: BTreeSet<_> = rows.iter().filter_map(|r| r["id"].as_str()).collect();
        if names.len() != variables.len()
            || ids.len() != rows.len()
            || rows
                .iter()
                .any(|r| r["coefficients"].as_array().map(Vec::len) != Some(variables.len()))
            || args
                .get("objective")
                .filter(|v| !v.is_null())
                .is_some_and(|v| v.as_array().map(Vec::len) != Some(variables.len()))
        {
            return Err(());
        }
        return Ok(());
    }
    if id == "chemistry.balance_reaction" {
        let chemistry = catalog_row(catalog, id)
            .map(|r| &r["chemistry_limits"])
            .ok_or(())?;
        let cap = |k: &str| chemistry[k].as_u64().unwrap_or(0) as usize;
        let species = args["species"].as_array().ok_or(())?;
        if species.len() < 2 || species.len() > cap("species") {
            return Err(());
        }
        let (mut names, mut sides, mut inventories) = (
            BTreeSet::new(),
            BTreeSet::new(),
            BTreeSet::from(["charge".to_owned()]),
        );
        for row in species {
            let row = row.as_object().ok_or(())?;
            let keys: BTreeSet<&str> = row.keys().map(String::as_str).collect();
            if keys != BTreeSet::from(["name", "side", "composition", "charge"]) {
                return Err(());
            }
            let name = row["name"].as_str().ok_or(())?;
            let charge = int(&row["charge"])
                .filter(|_| is_integer(&row["charge"]))
                .ok_or(())?;
            let composition = row["composition"].as_object().ok_or(())?;
            let side = row["side"].as_str().unwrap_or("");
            if name.trim().is_empty()
                || name.len() > 128
                || names.contains(name)
                || !["reactant", "product"].contains(&side)
                || !(i128::from(i64::MIN)..=i128::from(i64::MAX)).contains(&charge)
                || composition.len() >= cap("conserved_rows")
                || (composition.is_empty() && charge != -1)
            {
                return Err(());
            }
            names.insert(name);
            sides.insert(side);
            for (key, count) in composition {
                let n = int(count).filter(|_| is_integer(count)).ok_or(())?;
                if !label.is_match(key) || !(1..=i128::from(u64::MAX)).contains(&n) {
                    return Err(());
                }
                inventories.insert(key.clone());
            }
            if inventories.len() > cap("conserved_rows") {
                return Err(());
            }
        }
        return if sides.len() == 2 { Ok(()) } else { Err(()) };
    }
    if [
        "algebra.optimize_polynomial",
        "algebra.optimize_dimensional_polynomial",
        "algebra.simplify_rational",
    ]
    .contains(&id)
    {
        let expression = args["expression"].as_str().ok_or(())?;
        let n = expression.chars().count() as i128;
        if n < 1 || n > limit("request_bytes") || expression.len() as i128 > limit("request_bytes")
        {
            return Err(());
        }
        if id == "algebra.simplify_rational" {
            for key in ["bounds", "point"] {
                let rows = &args.get(key).cloned().unwrap_or(Value::Null);
                if rows.is_null() && (key == "point" || !args.contains_key(key)) {
                    continue;
                }
                let shape = if key == "bounds" {
                    &properties[key]
                } else {
                    &properties[key]["anyOf"][0]
                };
                let names: Option<BTreeSet<&str>> = rows
                    .as_array()
                    .map(|r| r.iter().filter_map(|x| x["name"].as_str()).collect());
                if !strict_valid(rows, shape)
                    || names.map(|s| s.len()) != rows.as_array().map(Vec::len)
                {
                    return Err(());
                }
            }
        }
        if id != "algebra.optimize_polynomial" {
            let annotations = args["variables"].as_array().ok_or(())?;
            if annotations.len() as i128 > limit("expression_nodes") {
                return Err(());
            }
            let dimension = &properties["variables"]["items"]["properties"]["dimension"];
            let mut seen = BTreeSet::new();
            for row in annotations {
                let row = row.as_object().ok_or(())?;
                let name = row.get("name").and_then(Value::as_str).ok_or(())?;
                let keys_ok = row.contains_key("dimension")
                    && row
                        .keys()
                        .all(|k| ["name", "dimension", "kind"].contains(&k.as_str()));
                let kind_ok = row.get("kind").is_none_or(|k| k == "linear");
                if !keys_ok
                    || name.chars().count() > 64
                    || !name_re.is_match(name)
                    || !kind_ok
                    || seen.contains(name)
                    || !strict_valid(&row["dimension"], dimension)
                {
                    return Err(());
                }
                seen.insert(name);
            }
            if let Some(output) = args.get("output_dimension") {
                if !strict_valid(output, &properties["output_dimension"]) {
                    return Err(());
                }
            }
        }
        return Ok(());
    }
    let vertices = int(&args["vertices"])
        .filter(|_| is_integer(&args["vertices"]))
        .ok_or(())?;
    if !(0..=limit("vertices")).contains(&vertices) {
        return Err(());
    }
    if id == "graph.shortest_path" {
        if vertices < 1 {
            return Err(());
        }
        for key in ["source", "target"] {
            let v = int(&args[key])
                .filter(|_| is_integer(&args[key]))
                .ok_or(())?;
            if !(0..vertices).contains(&v) {
                return Err(());
            }
        }
    }
    let edges = args["edges"].as_array().ok_or(())?;
    if edges.len() as i128 > limit("edges") {
        return Err(());
    }
    for edge in edges {
        let edge = edge
            .as_array()
            .filter(|e| e.len() == 3 && e.iter().all(is_integer))
            .ok_or(())?;
        let (a, b, w) = (
            int(&edge[0]).ok_or(())?,
            int(&edge[1]).ok_or(())?,
            int(&edge[2]).ok_or(())?,
        );
        if !(0..vertices).contains(&a)
            || !(0..vertices).contains(&b)
            || !(i128::from(i64::MIN)..=i128::from(i64::MAX)).contains(&w)
        {
            return Err(());
        }
    }
    Ok(())
}

fn text_int(value: &Value) -> Option<i128> {
    value.as_str()?.parse().ok()
}

/// Walk edge IDs from `start`; (end vertex, total weight).
fn walk(arguments: &Value, path: &Value, start: i128) -> Option<(i128, i128)> {
    let vertices = int(&arguments["vertices"])?;
    let edges = arguments["edges"].as_array()?;
    let path = path.as_array()?;
    if path.len() as i128 > vertices {
        return None;
    }
    let (mut vertex, mut total) = (start, 0i128);
    for id in path {
        let id = int(id)? as usize;
        let edge = edges.get(id)?.as_array()?;
        if int(&edge[0])? != vertex {
            return None;
        }
        vertex = int(&edge[1])?;
        total = total.checked_add(int(&edge[2])?)?;
    }
    Some((vertex, total))
}

/// `_check_path_reply`: transport coverage and edge walks; Rust checked optimality.
fn check_path(arguments: &Value, result: &Value) -> Option<()> {
    let vertices = int(&arguments["vertices"])? as usize;
    let (source, target) = (int(&arguments["source"])?, int(&arguments["target"])?);
    match result["outcome"].as_str()? {
        "finite" => {
            let labels = result["labels"].as_array()?;
            let ok = labels.len() == vertices
                && labels.get(source as usize)? == "0"
                && labels.get(target as usize)? == &result["distance"]
                && walk(arguments, &result["path"], source)?
                    == (target, text_int(&result["distance"])?)
                && labels.iter().all(|v| v.is_null() || text_int(v).is_some());
            ok.then_some(())
        }
        "unreachable" => {
            let reachable = result["reachable"].as_array()?;
            let at = |i: i128| reachable.get(i as usize).and_then(Value::as_bool);
            let edges = arguments["edges"].as_array()?;
            let ok = reachable.len() == vertices
                && at(source)?
                && !at(target)?
                && edges.iter().all(|e| {
                    let (a, z) = (int(&e[0]).unwrap_or(-1), int(&e[1]).unwrap_or(-1));
                    !(at(a).unwrap_or(false) && !at(z).unwrap_or(false))
                });
            ok.then_some(())
        }
        _ => {
            let (anchor, _) = walk(arguments, &result["prefix"], source)?;
            let (end, weight) = walk(arguments, &result["cycle"], anchor)?;
            let (finish, _) = walk(arguments, &result["suffix"], anchor)?;
            (end == anchor && weight < 0 && finish == target).then_some(())
        }
    }
}

/// Validate a DNA page against the exact supplied records and batch identity.
fn check_collection(
    arguments: &Value,
    result: &Value,
    control: &dyn oracle_execution::WorkControl,
) -> Result<Option<()>, oracle_execution::ExecutionError> {
    let mut budget_error = None;
    let checked = (|| -> Option<()> {
        macro_rules! charge {
            ($amount:expr) => {
                if let Err(error) = control.checkpoint($amount as u64) {
                    budget_error = Some(error);
                    return None;
                }
            };
        }
        charge!(1);
        fn field(bytes: &mut Vec<u8>, value: &str) {
            bytes.extend_from_slice(&(value.len() as u64).to_le_bytes());
            bytes.extend_from_slice(value.as_bytes());
        }
        fn records(bytes: &mut Vec<u8>, rows: &[Value]) -> Option<()> {
            bytes.extend_from_slice(&(rows.len() as u64).to_le_bytes());
            for row in rows {
                field(bytes, row["label"].as_str()?);
                field(bytes, row["sequence"].as_str()?);
            }
            Some(())
        }
        let source = arguments["collection"]["records"].as_array()?;
        let patterns = arguments["patterns"].as_array()?;
        // Hash each original record once. Charge before copying/hash work; hits
        // below inspect only their bounded source slice, never the whole record.
        for row in source.iter().chain(patterns.iter()) {
            charge!(row["label"]
                .as_str()?
                .len()
                .saturating_add(row["sequence"].as_str()?.len())
                .saturating_add(16));
        }
        let mut bytes = Vec::new();
        field(&mut bytes, arguments["collection"]["schema"].as_str()?);
        records(&mut bytes, source)?;
        let collection = config::sha256_bytes(&bytes);
        bytes.clear();
        field(&mut bytes, "oracle-sequence-search-v1");
        field(&mut bytes, &collection);
        records(&mut bytes, patterns)?;
        let request = config::sha256_bytes(&bytes);
        let hits = result["hits"].as_array()?;
        let complete = result["complete"].as_bool()?;
        let cursor = &result["next_cursor"];
        if result["schema"] != "oracle-sequence-search-v1"
            || result["collection_sha256"] != collection
            || result["request_sha256"] != request
            || result["coverage_start"] != arguments["cursor"]
            || hits.len() > 1024
            || hits.len() as u64 > arguments["page_size"].as_u64()?
            || (complete && !cursor.is_null())
            || (!complete && (!cursor.is_object() || hits.is_empty()))
        {
            return None;
        }
        let mut previous = None;
        for hit in hits {
            let ri = usize::try_from(hit["record_index"].as_u64()?).ok()?;
            let pi = usize::try_from(hit["pattern_index"].as_u64()?).ok()?;
            let record = source.get(ri)?;
            let pattern = patterns.get(pi)?;
            let raw_pattern = pattern["sequence"].as_str()?;
            charge!(raw_pattern.len().saturating_mul(4).saturating_add(1));
            let forward = raw_pattern.to_ascii_uppercase();
            let reverse: String = forward
                .bytes()
                .rev()
                .map(|b| match b {
                    b'A' => 'T',
                    b'C' => 'G',
                    b'G' => 'C',
                    _ => 'A',
                })
                .collect();
            let strand = hit["strand"].as_str()?;
            let order_strand = match strand {
                "forward" => 0,
                "reverse" => 1,
                "both" => 2,
                _ => return None,
            };
            let expected = if strand == "reverse" {
                &reverse
            } else {
                &forward
            };
            let start = usize::try_from(hit["start"].as_u64()?).ok()?;
            let end = usize::try_from(hit["end"].as_u64()?).ok()?;
            let sequence = record["sequence"].as_str()?;
            let order = (ri, start, pi, order_strand);
            if (strand == "both") != (forward == reverse)
                || hit["record_label"] != record["label"]
                || hit["pattern_label"] != pattern["label"]
                || start >= end
                || end.checked_sub(start)? != expected.len()
                || !sequence
                    .get(start..end)?
                    .eq_ignore_ascii_case(expected.as_str())
                || hit["matched_sequence"] != expected.as_str()
                || previous.is_some_and(|p| p >= order)
            {
                return None;
            }
            previous = Some(order);
        }
        if !cursor.is_null() {
            if cursor["request_sha256"] != request
                || cursor == &arguments["cursor"]
                || ["record", "start", "offset"]
                    .iter()
                    .any(|k| cursor[*k].as_u64().is_none())
            {
                return None;
            }
        }
        Some(())
    })();
    match budget_error {
        Some(error) => Err(error),
        None => Ok(checked),
    }
}

/// `_check_rational_reply`: transport consistency only.
fn check_rational(arguments: &Value, result: &Value) -> Option<()> {
    if let Some(requested) = arguments.get("output_dimension").filter(|v| !v.is_null()) {
        if &result["output_dimension"] != requested {
            return None;
        }
    }
    let point = arguments.get("point").is_none_or(Value::is_null);
    let evaluation = &result["evaluation"];
    if point != evaluation.is_null() {
        return None;
    }
    if !evaluation.is_null() && (evaluation["status"] == "value") != !evaluation["value"].is_null()
    {
        return None;
    }
    if !result["selection_fallback"].is_null() && result["selected_cost"] != result["original_cost"]
    {
        return None;
    }
    Some(())
}

/// `_check_chemistry_reply`: transport shape and coverage, no recomputation.
fn check_chemistry(arguments: &Value, result: &Value) -> Option<()> {
    let species = arguments["species"].as_array()?;
    let size = species.len() as i128;
    let nullity = int(&result["nullity"])?;
    let status = result["status"].as_str()?;
    let basis = result["nullspace_basis"].as_array()?;
    let free = result["free_species_indices"].as_array()?;
    let free_set: BTreeSet<i128> = free.iter().filter_map(int).collect();
    if int(&result["rank"])? + nullity != size
        || basis.len() as i128 != nullity
        || basis
            .iter()
            .any(|v| v.as_array().map(|v| v.len() as i128) != Some(size))
        || free.len() as i128 != nullity
        || free_set.len() as i128 != nullity
        || free_set.iter().any(|&i| i >= size)
    {
        return None;
    }
    let positive = ["unique_positive", "multiple_with_positive_candidate"].contains(&status);
    if (status == "no_nonzero_balance" && nullity != 0)
        || (status == "unique_positive" && nullity != 1)
        || (status == "no_strictly_positive_balance" && nullity < 1)
        || (status.starts_with("multiple_") && nullity < 2)
    {
        return None;
    }
    let rows = result["conservation"].as_array()?;
    if positive {
        let mut labels: BTreeSet<String> = BTreeSet::from(["charge".to_owned()]);
        for row in species {
            labels.extend(row["composition"].as_object()?.keys().cloned());
        }
        let inventories: BTreeSet<String> = rows
            .iter()
            .filter_map(|r| r["inventory"].as_str().map(str::to_owned))
            .collect();
        let ok = result["coefficients"]
            .as_array()
            .is_some_and(|c| c.len() as i128 == size)
            && rows.len() == labels.len()
            && inventories == labels
            && rows.iter().all(|r| r["reactant"] == r["product"]);
        ok.then_some(())
    } else {
        (result["coefficients"].is_null() && rows.is_empty()).then_some(())
    }
}

#[cfg(all(
    test,
    feature = "reasoning",
    feature = "science",
    feature = "statistics",
    feature = "bio",
    feature = "incremental",
    feature = "logic"
))]
mod typed_parity {
    use super::*;
    use std::sync::atomic::AtomicBool;
    use std::time::{Duration, Instant};

    fn context(fuel: u64) -> ExecutionContext {
        ExecutionContext::new(fuel, Duration::from_secs(30), Default::default()).unwrap()
    }
    fn provider() -> Pure {
        let dir = tempfile::tempdir().unwrap();
        let path = std::env::var_os("CLINGO_EXECUTABLE")
            .map(std::path::PathBuf::from)
            .unwrap_or_else(|| dir.path().join("deliberately-absent-solver"));
        Pure {
            profiles: vec![],
            loaded: vec![],
            identity_prefix: "fixture".into(),
            solver: Some((dir, path, "0".repeat(64))),
        }
    }
    fn legacy(pure: &Pure, name: &str, id: &str, args: &Value) -> Result<Value, String> {
        let request = if name == "incremental" {
            let mut args = args.clone();
            if id != "incremental.dependencies" {
                args["operation"] = json!("rooted_v2");
            }
            args
        } else {
            json!({"operation": id, "arguments": args})
        };
        let request = String::from_utf8(wire::encode(&request)).unwrap();
        let flag = AtomicBool::new(false);
        let raw = match name {
            "reasoning" => {
                oracle_reasoning::call(&request, &Default::default()).map_err(|e| e.to_string())
            }
            "science" => oracle_science::call(&request, &Default::default(), &flag)
                .map_err(|e| e.to_string()),
            "statistics" => oracle_statistics::call(&request, &Default::default(), &flag)
                .map_err(|e| e.to_string()),
            "bio" => {
                oracle_bio::call(&request, &Default::default(), &flag).map_err(|e| e.to_string())
            }
            "incremental" => Ok(oracle_incremental::call_json(&request)),
            "logic" => oracle_logic::hosted::call(
                &request,
                &json!({"solver": pure.solver.as_ref().unwrap().1}).to_string(),
                &Default::default(),
                &flag,
            )
            .map_err(|e| e.to_string()),
            _ => unreachable!(),
        }
        .map_err(|e| e.chars().take(512).collect::<String>())?;
        Ok(wire::parse(raw.as_bytes()).unwrap())
    }
    fn without_timings(value: &mut Value) {
        match value {
            Value::Object(map) => {
                map.retain(|k, _| !k.ends_with("_us"));
                for value in map.values_mut() {
                    without_timings(value);
                }
            }
            Value::Array(items) => items.iter_mut().for_each(without_timings),
            _ => (),
        }
    }
    fn parity(name: &str, id: &str, args: &Value) {
        let pure = provider();
        let mut expected = legacy(&pure, name, id, args);
        let mut actual = pure.call(name, id, args, &context(u64::MAX));
        if let Ok(value) = &mut expected {
            without_timings(value);
        }
        if let Ok(value) = &mut actual {
            without_timings(value);
        }
        assert_eq!(actual, expected, "{name}/{id}: {args}");
    }

    #[test]
    fn dna_page_replay_charges_source_once_and_each_short_hit() {
        use std::sync::atomic::{AtomicU64, Ordering};
        struct Count(AtomicU64);
        impl oracle_execution::WorkControl for Count {
            fn checkpoint(&self, work: u64) -> Result<(), oracle_execution::ExecutionError> {
                self.0.fetch_add(work, Ordering::Relaxed);
                Ok(())
            }
        }
        let arguments = json!({
            "collection": {"schema": "oracle-sequence-collection-v1", "records": [{"label": "r", "sequence": "a".repeat(131072)}]},
            "patterns": [{"label": "p", "sequence": "A"}], "page_size": 1024,
        });
        let result = provider()
            .call(
                "bio",
                "bio.search_collection",
                &arguments,
                &context(u64::MAX),
            )
            .unwrap();
        assert_eq!(result["hits"].as_array().unwrap().len(), 1024);
        let count = Count(AtomicU64::new(0));
        assert_eq!(
            check_collection(&arguments, &result, &count).unwrap(),
            Some(())
        );
        // Hashing sees the original record once; checking 1024 one-base hits
        // must not charge/traverse a full 131072-base record for every hit.
        let source_bytes = arguments["collection"]["records"][0]["sequence"]
            .as_str()
            .unwrap()
            .len() as u64;
        let hit_count = result["hits"].as_array().unwrap().len() as u64;
        let pattern_bytes = arguments["patterns"][0]["sequence"].as_str().unwrap().len() as u64;
        let charged = count.0.load(Ordering::Relaxed);
        // Require charged work for input identity and every hit, while leaving
        // room for changes to constant-factor framing/checking costs. This
        // rejects both uncharged replay and record-length work per short hit.
        assert!(charged >= source_bytes + hit_count * pattern_bytes);
        assert!(charged <= 2 * source_bytes + 32 * hit_count * (pattern_bytes + 1));
        assert!(check_collection(&arguments, &result, &context(1)).is_err());
        let catalog = oracle_bio::catalog();
        let structured = Structured {
            id: "bio.search_collection",
            identity: "fixture",
            catalog: &catalog,
        };
        let withheld = structured.bio(&arguments, &result, &context(1));
        assert_eq!(withheld["status"], "withheld");
        assert_eq!(withheld["reason"], "native_reply_check_budget_exhausted");
    }

    #[test]
    fn sol_consumer_discovery_typed_wire_and_semantic_replies() {
        let names = ["reasoning", "science", "bio", "statistics"].map(str::to_owned);
        // This intentionally requires a freshly generated snapshot: a source
        // catalog change cannot silently leave discovery on the previous API.
        let pure = Pure::open(&names, &"a".repeat(64), None).unwrap();
        for (profile, id) in [
            ("reasoning", "reasoning.exact_linear_feasibility"),
            ("science", "science.thermal_scenarios"),
            ("bio", "bio.search_collection"),
            ("statistics", "statistics.calibration"),
        ] {
            let declaration = pure
                .declarations()
                .into_iter()
                .find(|(_, d)| d["id"] == id)
                .unwrap()
                .1;
            let arguments = declaration["examples"][0]["arguments"].clone();
            assert!(
                crate::schema::validate(&arguments, &declaration["input_schema"], "arguments")
                    .is_ok(),
                "{id} example schema"
            );
            parity(profile, id, &arguments);
            let reply = pure
                .invoke(profile, id, &arguments, "tenant", &context(u64::MAX))
                .unwrap();
            assert_eq!(reply["status"], "answered", "{id}: {reply}");
            assert_eq!(reply["authority"], "computation_only");
            let mut unknown = arguments.clone();
            unknown["unknown_field"] = json!(0);
            assert!(
                crate::schema::validate(&unknown, &declaration["input_schema"], "arguments")
                    .is_err(),
                "{id} unknown field"
            );
            assert!(
                pure.call(profile, id, &unknown, &context(u64::MAX))
                    .is_err(),
                "{id} typed unknown field"
            );
            let cancelled = context(u64::MAX);
            cancelled.cancellation().cancel();
            assert!(
                pure.call(profile, id, &arguments, &cancelled).is_err(),
                "{id} cancellation"
            );
            if id == "statistics.calibration" {
                let mut inverse = arguments.clone();
                inverse["direction"] = json!("inverse_point");
                let reply = pure
                    .invoke(profile, id, &inverse, "tenant", &context(u64::MAX))
                    .unwrap();
                assert_eq!(reply["status"], "withheld");
                assert_eq!(reply["reason"], "calibration_unavailable");
            }
            if id == "bio.search_collection" {
                let mut result = pure
                    .call(profile, id, &arguments, &context(u64::MAX))
                    .unwrap();
                result["collection_sha256"] = json!("0".repeat(64));
                assert!(check_collection(&arguments, &result, &context(u64::MAX))
                    .unwrap()
                    .is_none());
            }
        }
    }

    #[test]
    fn all_profiles_typed_wire_success_and_refusal_parity() {
        for id in ["graph.minimum_spanning_forest", "graph.shortest_path"] {
            let mut args = json!({"vertices": 3, "edges": [[0,1,9223372036854775807i64],[1,2,-9223372036854775807i64]]});
            if id.ends_with("shortest_path") {
                args["source"] = json!(0);
                args["target"] = json!(2);
            }
            parity("reasoning", id, &args);
        }
        parity(
            "reasoning",
            "algebra.optimize_polynomial",
            &json!({"expression":"(+ x 0)"}),
        );
        let dimensional =
            json!({"expression":"(+ x 0)","variables":[{"name":"x","dimension":[0,0,0,0,0,0,0]}]});
        parity(
            "reasoning",
            "algebra.optimize_dimensional_polynomial",
            &dimensional,
        );
        parity("reasoning", "algebra.simplify_rational", &dimensional);
        parity(
            "reasoning",
            "chemistry.balance_reaction",
            &json!({"species":[
            {"name":"a","side":"reactant","composition":{"H":18446744073709551615u64},"charge":0},
            {"name":"b","side":"product","composition":{"H":18446744073709551615u64},"charge":0}]}),
        );
        let bio = json!({"query":"ACGT","reference":"AGGT","mode":"global","scoring":{"match_score":2,"mismatch_score":-1,"gap_open":-3,"gap_extend":-1}});
        parity("bio", "bio.align_pairwise", &bio);
        let graph = json!({"scope":"supplied α","nodes":[0,1],"epochs":[{"version":1,"mutations":[{"op":"insert","fact_id":"a","from":0,"to":1}],"queries":[{"op":"reachable","from":0,"to":1}]}]});
        parity("incremental", "incremental.dependencies", &graph);
        parity(
            "incremental",
            "incremental.dependencies_rooted",
            &json!({"graph":graph,"roots":{"downstream":[0],"upstream":[]}}),
        );
        let logic = json!({"scope":{"tenant":"fixture","snapshot":"v1","complete_program":true},"atoms":["a"],"rules":[{"head":0,"positive":[],"negative":[]}],"queries":[0]});
        for id in ["logic.query", "logic.enumerate"] {
            parity("logic", id, &logic);
        }
        for (name, id) in [
            ("reasoning", "graph.shortest_path"),
            ("science", "science.solve_linear"),
            ("bio", "bio.align_pairwise"),
            ("statistics", "statistics.linear_regression"),
            ("logic", "logic.query"),
            ("incremental", "incremental.dependencies"),
        ] {
            parity(name, id, &json!({"unknown":"rejected before computation"}));
        }
    }

    #[test]
    fn floating_numeric_lexemes_survive_direct_typed_admission() {
        for number in [
            "1",
            "1.0",
            "1e0",
            "0.10000000000000001",
            "1.0000000000000003",
            "51.248178375505404",
            "1.00000000000000011102230246251565404236316680908203125",
            "-0.0",
            "1e-100",
            "9007199254740993",
        ] {
            let args = wire::parse(format!(r#"{{"matrix":[[{number}]],"rhs":[1.0],"model":{{"description":"caller model","variable_units":["m"],"row_units":["N"],"normalization":"supplied","assumptions":[]}}}}"#).as_bytes()).unwrap();
            for id in ["science.solve_linear", "science.least_squares"] {
                parity("science", id, &args);
            }
            let stats = wire::parse(format!(r#"{{"features":[[{number}],[2.0],[3.0]],"response":[1.0,2.0,4.0],"intercept":true,"covariance":"classical_normal_errors","model":{{"description":"caller model","predictor_names":["x"],"predictor_units":["m"],"response_unit":"N","assumptions":[]}}}}"#).as_bytes()).unwrap();
            parity("statistics", "statistics.linear_regression", &stats);
            let conductance = wire::parse(number.as_bytes()).unwrap();
            parity(
                "science",
                "science.thermal_network",
                &json!({"description":"supplied network","assumptions":[],"reference_temperature_k":300.0,"nodes":[{"id":"boundary","applied_heat_w":0.0,"fixed_temperature_k":300.0},{"id":"body","applied_heat_w":20.0}],"links":[{"from":"boundary","to":"body","conductance_w_per_k":conductance}]}),
            );
        }
        parity(
            "science",
            "science.thermal_network",
            &json!({"description":"supplied network","assumptions":[],"reference_temperature_k":300.0,"nodes":[{"id":"boundary","applied_heat_w":0.0,"fixed_temperature_k":300.0},{"id":"body","applied_heat_w":20.0}],"links":[{"from":"boundary","to":"body","conductance_w_per_k":2.0}]}),
        );
    }

    #[test]
    fn float_rounding_matches_exact_binary64_neighbors() {
        // In [1,2) binary64 spacing is 2^-52. The first decimal is
        // 1.351079888... spacings above 1, so its nearest value is 1+2^-52.
        // The long decimal is exactly halfway to that neighbor: ties go to 1.
        for (source, expected) in [
            ("1.0000000000000003", 0x3ff0000000000001u64),
            (
                "1.00000000000000011102230246251565404236316680908203125",
                0x3ff0000000000000u64,
            ),
            (
                "1.00000000000000011102230246251565404236316680908203126",
                0x3ff0000000000001u64,
            ),
            ("51.248178375505404", 0x40499fc44f1b2f60u64),
            ("2.2250738585072014e-308", 0x0010000000000000u64),
            ("5e-324", 0x0000000000000001u64),
            ("2.4703282292062327e-324", 0x0000000000000000u64),
            ("2.4703282292062328e-324", 0x0000000000000001u64),
            ("1.7976931348623157e308", 0x7fefffffffffffffu64),
            ("-0.0", 0x8000000000000000u64),
        ] {
            let via_wire: f64 = serde_json::from_str(source).unwrap();
            let value = wire::parse(source.as_bytes()).unwrap();
            let direct: f64 = decode(&value).unwrap();
            assert_eq!(direct.to_bits(), expected, "typed {source}");
            assert_eq!(via_wire.to_bits(), expected, "wire {source}");
        }
    }

    #[test]
    fn byte_count_and_strict_ingress_are_not_widened() {
        let args = json!({"text":"α\n\"\\", "n":18446744073709551615u64});
        assert_eq!(
            envelope_size("operation", &args),
            wire::encode(&json!({"operation":"operation","arguments":args})).len()
        );
        for invalid in [
            r#"{"x":1,"x":2}"#,
            r#"{"x":1e400}"#,
            r#"{"x":"\ud800"}"#,
            "{} trailing",
        ] {
            assert!(wire::parse(invalid.as_bytes()).is_err());
        }
    }

    #[test]
    fn shared_exhaustion_is_not_cancellation_or_success() {
        let pure = provider();
        let args = json!({"vertices":2,"source":0,"target":1,"edges":[[0,1,4]]});
        let fuel = pure
            .call("reasoning", "graph.shortest_path", &args, &context(2))
            .unwrap_err();
        assert!(fuel.contains("shared work"), "{fuel}");
        let deadline =
            ExecutionContext::with_deadline(u64::MAX, Instant::now(), Default::default());
        let time = pure
            .call("reasoning", "graph.shortest_path", &args, &deadline)
            .unwrap_err();
        assert!(time.contains("shared deadline"), "{time}");
        let cancelled = context(u64::MAX);
        cancelled.cancellation().cancel();
        let error = pure
            .call("reasoning", "graph.shortest_path", &args, &cancelled)
            .unwrap_err();
        assert!(error.contains("shared cancellation"), "{error}");
        let rational =
            json!({"expression":"(+ x 0)","variables":[{"name":"x","dimension":[0,0,0,0,0,0,0]}]});
        assert!(pure
            .call(
                "reasoning",
                "algebra.simplify_rational",
                &rational,
                &context(2)
            )
            .unwrap_err()
            .contains("shared work"));
        let graph = json!({"graph":{"scope":"budget","nodes":[0,1],"epochs":[{"version":0,"mutations":[{"op":"insert","fact_id":"a","from":0,"to":1}]}]},"roots":{"downstream":[0],"upstream":[]}});
        let result = pure
            .call(
                "incremental",
                "incremental.dependencies_rooted",
                &graph,
                &context(2),
            )
            .unwrap();
        assert_eq!(result["status"], "refused");
        assert_eq!(result["error"]["code"], "cooperative_budget");
    }
}
