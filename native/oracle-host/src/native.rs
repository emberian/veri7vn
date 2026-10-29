//! In-process native data runtime: one admitted image and durable session
//! store shared by every tenant handle. A port of `native_runtime.py` plus the
//! reply projection of `oracle_components/native_runtime_adapter.py`, without
//! a Python worker in between.

use crate::config::{self, err, ConfigError, NativeConfig};
use crate::wire::{self, is_integer};
use crate::Failure;
use oracle_runtime_core as core;
use oracle_runtime_core::release::{
    Availability, OperationRegistration, ReleaseBindings, ReleaseManifest,
};
use serde_json::{json, Value};
use std::sync::Arc;

pub const SCHEMA: &str = "oracle-native-runtime-host-v1";

/// (operation, argument field, stateful)
pub const OPERATIONS: [(&str, &str, bool); 6] = [
    ("graph.query", "plan_json", false),
    ("graph.execute", "plan_json", true),
    ("kqa.query", "program_json", false),
    ("kqa.execute", "program_json", true),
    ("reader.whole", "question", false),
    ("reader.execute", "question", true),
];

pub struct NativeRuntime {
    pub runtime: Arc<core::Runtime>,
    pub image_sha256: String,
    pub resource_identity: String,
    pub release_admitted: bool,
    pub operations: Vec<&'static str>,
    pub request_bytes: usize,
    pub reader_route: bool,
}

fn operation(id: &str) -> Option<(&'static str, &'static str, bool)> {
    OPERATIONS.iter().copied().find(|(op, _, _)| *op == id)
}

/// SHA256(domain || kind || outer id): the core's stricter identifier form.
pub fn core_id(kind: &str, outer: &str) -> Option<String> {
    let bytes = outer.as_bytes();
    let valid = !bytes.is_empty()
        && bytes.len() <= 160
        && bytes[0].is_ascii_alphanumeric()
        && bytes
            .iter()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(b));
    valid.then(|| config::sha256_bytes(format!("{SCHEMA}\0{kind}\0{outer}").as_bytes()))
}

impl NativeRuntime {
    pub fn open(settings: &NativeConfig, host_sha256: &str) -> Result<Self, ConfigError> {
        config::absolute("native.image", &settings.image)?;
        config::absolute("native.state", &settings.state)?;
        if !config::is_hash(&settings.image_sha256) {
            return Err(err("native.image_sha256 must be 64 lowercase hex"));
        }
        let limits: core::Limits = if settings.core_limits.is_null() {
            core::Limits::default()
        } else {
            serde_json::from_value(settings.core_limits.clone())
                .map_err(|e| err(format!("native.core_limits: {e}")))?
        };
        let request_bytes = limits.request_bytes;
        // Image::open hashes the whole image and checks its format and limits.
        let image = core::Image::open(&settings.image, &settings.image_sha256, limits)
            .map_err(|e| err(format!("native.image: {e}")))?;
        let has_reader = image.capabilities.reader.is_some();
        let (runtime, operations, release_admitted) = match &settings.release {
            Some(release) => {
                let manifest = ReleaseManifest::from_json(release.manifest_json.as_bytes())
                    .map_err(|e| err(format!("native.release: {e}")))?;
                if !manifest.resources.is_empty() {
                    return Err(err("native.release: external resources are not admitted"));
                }
                let mut operations = Vec::new();
                let mut registrations = Vec::new();
                for row in &manifest.operations {
                    if !row.availability.is_serving() || row.version != 1 {
                        continue;
                    }
                    let host_only = matches!(
                        row.id.as_str(),
                        "host.retention.retire" | "host.retention.inspect"
                    );
                    let tenant = operation(&row.id)
                        .filter(|(id, _, _)| !id.starts_with("reader.") || has_reader);
                    if tenant.is_none() && !host_only {
                        continue;
                    }
                    registrations.push(OperationRegistration {
                        id: row.id.clone(),
                        availability: Availability::Implemented,
                    });
                    // Host retention methods never become tenant operations.
                    if let Some((id, _, _)) = tenant {
                        operations.push(id);
                    }
                }
                let bindings = ReleaseBindings {
                    runtime_artifact_sha256: host_sha256.into(),
                    data_image_sha256: image.identity.clone(),
                    resource_profile_sha256: core::release::runtime_profile_sha256(&image.limits)
                        .map_err(|e| err(format!("native.release: {e}")))?,
                    resources: vec![],
                };
                let admitted = manifest
                    .admit(&release.identity, &bindings, &registrations)
                    .map_err(|e| err(format!("native.release: {e}")))?;
                let runtime = core::Runtime::open_release(image, &settings.state, admitted)
                    .map_err(|e| err(format!("native.state: {e}")))?;
                (runtime, operations, true)
            }
            None => {
                let runtime = core::Runtime::open(image, &settings.state)
                    .map_err(|e| err(format!("native.state: {e}")))?;
                let operations = OPERATIONS
                    .iter()
                    .map(|(id, _, _)| *id)
                    .filter(|id| !id.starts_with("reader.") || has_reader)
                    .collect();
                (runtime, operations, false)
            }
        };
        if operations.is_empty() {
            return Err(err("native: runtime has no implemented tenant operations"));
        }
        let resource_identity = config::sha256_bytes(&wire::encode(&json!({
            "image": settings.image, "image_sha256": settings.image_sha256, "state": settings.state,
            "release_identity": runtime.identity(), "core_limits": settings.core_limits,
            "host_sha256": host_sha256})));
        Ok(Self {
            image_sha256: runtime.image.identity.clone(),
            runtime: Arc::new(runtime),
            resource_identity,
            release_admitted,
            operations,
            request_bytes,
            reader_route: settings.reader_route && has_reader,
        })
    }

    pub fn identity(&self) -> &str {
        self.runtime.identity()
    }

    /// Discovery declarations, as `NativeRuntimeOperations.__init__` builds them.
    pub fn declarations(&self, host_identity: &str) -> Vec<Value> {
        let string = json!({"type": "string", "minLength": 1, "maxLength": self.request_bytes});
        self.operations
            .iter()
            .map(|id| {
                let (id, field, stateful) = operation(id).expect("registered");
                let mut properties = serde_json::Map::new();
                properties.insert(field.into(), string.clone());
                let mut example = match field {
                    "question" => json!({"question": "Who is Alice?"}),
                    "plan_json" => json!({"plan_json": "{\"nodes\":[{\"op\":\"find\",\"name\":\"Alice\"}],\"output\":0,\"projection\":{\"kind\":\"unique_name\"}}"}),
                    _ => json!({"program_json": "[{\"function\":\"Find\",\"dependencies\":[],\"inputs\":[\"Alice\"]},{\"function\":\"What\",\"dependencies\":[0],\"inputs\":[]}]"}),
                };
                if stateful {
                    properties.insert("expected_version".into(),
                        json!({"type": "integer", "minimum": 0, "maximum": (1u64 << 63) - 2}));
                    example["expected_version"] = json!(0);
                }
                let required: Vec<&String> = properties.keys().collect();
                let input = json!({"type": "object", "properties": properties, "required": required,
                                   "additionalProperties": false});
                json!({"id": id, "name": id.replace('.', " "),
                    "description": if stateful { "Commit a bounded native data/language turn and retain its exact reply for retry." }
                                   else { "Read the operator's fixed native data image without changing session state." },
                    "availability": "live_direct", "input_schema": input,
                    "output_schema": {"type": "object", "description":
                        "Authoritative exact core_reply_json and bounded core_metadata, with committed version even when withheld. JSON numeric tokens in core_reply_json are exact; no decoded numerical body is returned."},
                    "examples": [{"arguments": example, "source": "Manufactured usage example; no panel score."}],
                    "sources": [], "implementation": {"backend": "oracle_native_runtime",
                        "runtime_identity": self.identity(), "resource_identity": self.resource_identity,
                        "image_sha256": self.image_sha256, "artifact_profile_identity": host_identity},
                    "durable_replay": stateful,
                    "limitations": ["Untrusted host boundary; no new theorem, specialist-panel score or signed Mini qualification.",
                        "Operator image and admitted release only; no full Oracle Engine, teaching or external effects.",
                        "Host supplies tenant and outer request/conversation IDs; the private tenant header is not authentication.",
                        "Exact native reply bytes replay. HTTP wrapper/containment metadata need not be byte-identical.",
                        if stateful { "Retry stateful calls with the same outer IDs, exact input string and expected_version after response loss." }
                        else { "Pure calls do not retain a retry reply or change the previous selection." }]})
            })
            .collect()
    }

    pub fn is_stateful(&self, id: &str) -> bool {
        operation(id).is_some_and(|(_, _, s)| s)
    }

    /// Execute one runtime operation and project its reply. Arguments have
    /// already passed the declaration's schema.
    pub fn invoke(
        &self,
        id: &str,
        arguments: &Value,
        tenant: &str,
        request_id: &str,
        conversation_id: &str,
        cancellation: core::Cancellation,
    ) -> Result<Value, Failure> {
        let (id, field, stateful) =
            operation(id).ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
        let uncertain = |code: &str, status: u16| {
            Failure::new(
                status,
                code,
                json!({"retryable": stateful, "state_may_have_changed": stateful,
                                               "exact_retry_required": stateful}),
            )
        };
        let input = arguments[field].as_str().unwrap_or("");
        let (Some(session), Some(request)) = (
            core_id("session", conversation_id),
            core_id("request", request_id),
        ) else {
            return Err(uncertain("native_refused", 503));
        };
        let runtime = &self.runtime;
        let expected = arguments
            .get("expected_version")
            .and_then(Value::as_i64)
            .unwrap_or(0);
        let raw = match id {
            "graph.query" => runtime.query(tenant, input, cancellation),
            "kqa.query" => runtime.query_program(tenant, input, cancellation),
            "reader.whole" => runtime.read_whole(tenant, input, cancellation),
            "graph.execute" => {
                runtime.execute(tenant, &session, &request, expected, input, cancellation)
            }
            "kqa.execute" => {
                runtime.execute_program(tenant, &session, &request, expected, input, cancellation)
            }
            _ => {
                runtime.execute_language(tenant, &session, &request, expected, input, cancellation)
            }
        };
        let raw = raw.map_err(|e| match e {
            core::Error::Conflict(_) => Failure::new(
                409,
                "runtime_conflict",
                json!({"retryable": false,
                "state_may_have_changed": false, "exact_retry_required": false}),
            ),
            core::Error::Busy => Failure::new(
                429,
                "runtime_busy",
                json!({"retryable": true,
                "state_may_have_changed": false, "exact_retry_required": false}),
            ),
            core::Error::Cancelled | core::Error::Deadline | core::Error::Limit(_) => {
                uncertain("runtime_budget", 503)
            }
            core::Error::Invalid(_) | core::Error::Json(_) => uncertain("native_refused", 503),
            _ => uncertain("native_execution_failed", 503),
        })?;
        self.project(id, stateful, expected, raw)
            .map_err(|_| uncertain("native_adapter_invalid_reply", 502))
    }

    /// `NativeRuntimeOperations.invoke`'s checks and reply, numbers kept inert.
    fn project(&self, id: &str, stateful: bool, expected: i64, raw: String) -> Result<Value, ()> {
        let core = wire::parse(raw.as_bytes()).map_err(|_| ())?;
        let core = core.as_object().ok_or(())?;
        let version;
        let payload = if stateful {
            let token = core.get("version").ok_or(())?;
            let text = token.to_string();
            let canonical = is_integer(token)
                && (text == "0"
                    || (!text.starts_with('0') && !text.starts_with('-') && text.len() <= 19));
            let number: i64 = text.parse().map_err(|_| ())?;
            if !canonical || Some(number) != expected.checked_add(1) {
                return Err(());
            }
            version = Some(number);
            core.get(if id == "reader.execute" {
                "language"
            } else {
                "result"
            })
            .ok_or(())?
        } else {
            return self.finish(id, stateful, None, &Value::Object(core.clone()), raw);
        };
        let payload = payload.clone();
        self.finish(id, stateful, version, &payload, raw)
    }

    fn finish(
        &self,
        id: &str,
        stateful: bool,
        version: Option<i64>,
        payload: &Value,
        raw: String,
    ) -> Result<Value, ()> {
        let payload = payload.as_object().ok_or(())?;
        if payload.get("image").and_then(Value::as_str) != Some(self.image_sha256.as_str()) {
            return Err(());
        }
        let coverage = payload.get("coverage").and_then(Value::as_str).ok_or(())?;
        if coverage.is_empty() || coverage.len() > 160 {
            return Err(());
        }
        let mut metadata = json!({"image": self.image_sha256, "coverage": coverage});
        let mut reason: Option<String> = None;
        if id.starts_with("reader.") {
            let status = payload.get("status").and_then(Value::as_str).ok_or(())?;
            if !["answered", "unknown", "ambiguous", "refused"].contains(&status) {
                return Err(());
            }
            metadata["semantic_status"] = json!(status);
            if status != "answered" {
                reason = Some(match payload.get("reason") {
                    Some(Value::String(r)) if !r.is_empty() => r.clone(),
                    None | Some(Value::Null) => status.to_owned(),
                    Some(Value::String(_)) => status.to_owned(),
                    _ => return Err(()),
                });
            }
        } else if let Some(Value::Object(value)) = payload.get("value") {
            if let Some(Value::String(status)) = value.get("status") {
                if [
                    "absent",
                    "ambiguous",
                    "incomparable",
                    "ambiguous_operands",
                    "incomplete",
                ]
                .contains(&status.as_str())
                {
                    reason = Some(status.clone());
                }
                if status.len() <= 80 {
                    metadata["semantic_status"] = json!(status);
                }
            }
        }
        if reason.as_ref().is_some_and(|r| r.len() > 80) {
            return Err(());
        }
        let mut reply = json!({"status": if reason.is_some() { "withheld" } else { "answered" },
            "operation_id": id, "authority": "sourced_data", "runtime_identity": self.identity(),
            "resource_identity": self.resource_identity, "stateful": stateful,
            "core_metadata": metadata, "core_reply_json": raw});
        if let Some(version) = version {
            reply["version"] = json!(version);
        }
        if let Some(reason) = reason {
            reply["reason"] = json!(reason);
        }
        Ok(reply)
    }
}

/// A release declaration for this host binary over one image and core
/// limits, for the operator to review and pin. Prints nothing secret.
pub fn manifest_template(
    image_sha256: &str,
    limits: &core::Limits,
    host_sha256: &str,
) -> Result<Value, String> {
    let profile = core::release::runtime_profile_sha256(limits).map_err(|e| e.to_string())?;
    let operations: Vec<Value> = OPERATIONS
        .iter()
        .map(|(id, field, stateful)| {
            json!({"id": id, "version": 1, "summary": format!("{id} over the admitted image"),
                "availability": "implemented",
                "input_schema": {"type": "object", "required": if *stateful { json!([field, "expected_version"]) } else { json!([field]) }},
                "output_schema": {"type": "object"}, "resources": [],
                "limitations": ["Native host operation; no theorem claim, specialist-panel score or Mini qualification."]})
        })
        .collect();
    let manifest = json!({"schema": "oracle-native-release-v1", "runtime_artifact_sha256": host_sha256,
        "data_image_sha256": image_sha256, "resource_profile_sha256": profile,
        "appliance_receipt_sha256": null,
        "schemas": [{"id": "session", "version": 2}, {"id": "graph", "version": 1}, {"id": "kqa_program", "version": 1}],
        "resources": [], "operations": operations});
    let text = String::from_utf8(wire::encode(&manifest)).map_err(|e| e.to_string())?;
    let identity = ReleaseManifest::from_json(text.as_bytes())
        .and_then(|m| m.identity())
        .map_err(|e| e.to_string())?;
    Ok(json!({"manifest_json": text, "identity": identity}))
}

impl NativeRuntime {
    /// The learned reader as a front-door route. `unknown` means it did not
    /// read the question; `ambiguous` and `refused` are refusals that end the
    /// turn; an answer's agreement key is the reader's single agreed answer.
    pub fn ask_reader(
        &self,
        tenant: &str,
        question: &str,
        cancellation: core::Cancellation,
    ) -> crate::front::Candidate {
        use crate::front::{Candidate, Offer};
        let route = "native:reader".to_owned();
        let started = std::time::Instant::now();
        let result = self.runtime.read_whole(tenant, question, cancellation);
        let ms = started.elapsed().as_secs_f64() * 1000.0;
        let raw = match result {
            Ok(raw) => raw,
            Err(error) => return Candidate::unavailable(route, 0, &error.to_string(), ms),
        };
        let Ok(result) = wire::parse(raw.as_bytes()) else {
            return Candidate::unavailable(route, 0, "reader reply is not strict JSON", ms);
        };
        let status = result.get("status").and_then(Value::as_str).unwrap_or("");
        let answer = result.get("answer").and_then(Value::as_str);
        let (offer, response) = match (status, answer) {
            ("answered", Some(answer)) if !answer.trim().is_empty() => {
                (Offer::Answer, answer.to_owned())
            }
            ("unknown", None) => (Offer::NoReading, String::new()),
            ("ambiguous" | "refused", None) => (
                Offer::Refusal,
                "The native reader found readings that disagree, so it gives no answer.".to_owned(),
            ),
            _ => {
                return Candidate::unavailable(
                    route,
                    0,
                    "reader reply has an unexpected status",
                    ms,
                )
            }
        };
        let reason = result.get("reason").cloned().unwrap_or(Value::Null);
        let reply = json!({"status": if offer == Offer::Answer { "answered" } else { "withheld" },
            "response": response, "path": format!("native:reader>{status}"),
            "provenance": {"image": result.get("image"), "coverage": result.get("coverage"),
                "reason": reason, "distinct_answers": result.get("distinct_answers"),
                "readings": result.get("readings").and_then(Value::as_array).map_or(0, Vec::len),
                "matched_programs": result.get("matched_programs")}});
        let mut candidate = Candidate::from_reply(route, 0, offer, &reply, ms);
        candidate.key = answer.map(str::to_owned);
        candidate
    }
}
