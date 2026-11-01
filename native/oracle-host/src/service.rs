//! The host's request semantics, independent of the socket layer: envelope
//! checks, bounded global/tenant admission, discovery, `/invoke` and `/query`.

use crate::admission::{Admission, Permit};
use crate::config::{self, Config, ConfigError, HostLimits};
use crate::engine::{EngineError, EnginePool};
use crate::front::{self, Candidate, Decision};
use crate::journal::{EncodedLookup, Journal};
use crate::kernels::Kernels;
use crate::native::NativeRuntime;
use crate::operations::{valid_operation_id, Registry, Route};
use crate::pure::{CheckedPureReply, Pure};
use crate::wire;
use crate::workers::InvocationWorkers;
use crate::{failure, Failure};
use core::conversation::{
    ConversationBegin, ConversationCandidate, ConversationHttpReply, ConversationInput,
    ConversationRequest,
};
use oracle_execution::{Cancellation, ExecutionContext};
use oracle_runtime_core as core;
use serde::Serialize;
use serde_json::{json, Value};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};
use std::time::{Duration, Instant};

#[derive(Serialize)]
#[serde(untagged)]
enum InvocationReply {
    Runtime(Value),
    Pure(CheckedPureReply),
}

#[derive(Serialize)]
struct CompletedInvocation {
    outcome: &'static str,
    operation_id: String,
    reply: InvocationReply,
    native_execution: [Value; 1],
    durable_replay: bool,
}

pub struct Service {
    pub limits: HostLimits,
    pub native: Option<Arc<NativeRuntime>>,
    pub pure: Option<Arc<Pure>>,
    pub kernels: Option<Kernels>,
    pub engine: Option<EnginePool>,
    pub registry: Registry,
    journal: Journal,
    admission: Arc<Admission>,
    invocations: InvocationWorkers,
    pub stopping: AtomicBool,
    pub host_sha256: String,
    boot: String,
    providers: Vec<Value>,
    conversation_profile: bool,
    native_conversation_profile: bool,
    conversation_wikidata: bool,
}

pub fn identifier(text: &str) -> bool {
    (1..=80).contains(&text.len())
        && text
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
}

pub fn tenant_key(text: &str) -> bool {
    config::is_hash(text)
}

fn invalid_request() -> Failure {
    Failure::plain(400, "invalid_request")
}

/// The reference envelope: exact field set, bounded identifiers, strict JSON.
pub fn envelope(raw: &[u8], path: &str, request_bytes: usize) -> Result<Value, Failure> {
    if raw.len() > request_bytes {
        return Err(Failure::plain(413, "request_too_large"));
    }
    let request = wire::parse(raw).map_err(|_| invalid_request())?;
    let object = request.as_object().ok_or_else(invalid_request)?;
    let fields: &[&str] = if path == "/query" {
        &["conversation_id", "request_id", "text"]
    } else {
        &["arguments", "conversation_id", "operation_id", "request_id"]
    };
    if object.len() != fields.len() || !fields.iter().all(|f| object.contains_key(*f)) {
        return Err(invalid_request());
    }
    for name in ["request_id", "conversation_id"] {
        if !object[name].as_str().is_some_and(identifier) {
            return Err(invalid_request());
        }
    }
    if path == "/query" {
        if !object["text"]
            .as_str()
            .is_some_and(|t| !t.trim().is_empty())
        {
            return Err(invalid_request());
        }
    } else if !object["operation_id"]
        .as_str()
        .is_some_and(valid_operation_id)
        || !object["arguments"].is_object()
    {
        return Err(invalid_request());
    }
    Ok(request)
}

impl Service {
    pub fn open(config: &Config) -> Result<Arc<Self>, ConfigError> {
        if config.limits.reply_bytes < 1024 {
            return Err(config::err("config: reply_bytes must be at least 1024"));
        }
        if config.conversation_profile.as_deref() == Some("native-v1") && config.engine.is_some() {
            return Err(config::err(
                "native-v1 excludes Engine configuration; use a separate readonly-v1 configuration",
            ));
        }
        let host_sha256 =
            crate::host_binary_sha256().map_err(|e| config::err(format!("host binary: {e}")))?;
        let boot = format!(
            "{:x}{:x}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_or(0, |d| d.as_nanos())
        );
        let conversation_profile = match config.conversation_profile.as_deref() {
            None => false,
            Some("readonly-v1" | "native-v1") if config.native.is_some() => true,
            Some("readonly-v1" | "native-v1") => {
                return Err(config::err("conversation_profile requires native state"))
            }
            Some(_) => return Err(config::err("unsupported conversation_profile")),
        };
        let native_conversation_profile =
            config.conversation_profile.as_deref() == Some("native-v1");
        if conversation_profile
            && !native_conversation_profile
            && config
                .engine
                .as_ref()
                .is_some_and(|engine| engine.conversation_adapter.is_none())
        {
            return Err(config::err(
                "readonly-v1 Engine requires an admitted conversation_adapter",
            ));
        }
        let conversation_wikidata = match config.conversation_entity_namespace.as_deref() {
            None => false,
            Some("wikidata") if conversation_profile && !native_conversation_profile => true,
            _ => {
                return Err(config::err(
                    "conversation_entity_namespace requires readonly-v1 and must be wikidata",
                ))
            }
        };
        let limits = config.limits.clone();
        let journal = Journal::open(
            &config.journal,
            limits.retained_requests,
            limits.conversations,
            &config::deployment_identity(config, &host_sha256)?,
        )
        .map_err(|e| config::err(format!("journal: {e}")))?;
        let mut registry = Registry::new(limits.request_bytes, limits.reply_bytes);
        let mut providers = Vec::new();
        let host_identity = format!("{host_sha256}:host");
        let native = match &config.native {
            Some(settings) => {
                let runtime = NativeRuntime::open_with_solver(
                    settings,
                    &host_sha256,
                    config.pure.as_ref().is_some_and(|p| p.solver.is_some()),
                )?;
                let runtime = if native_conversation_profile {
                    runtime.enable_native_conversation()?
                } else if conversation_profile {
                    runtime.enable_conversation(conversation_wikidata)?
                } else {
                    runtime
                };
                for declaration in runtime.declarations(&host_identity) {
                    registry
                        .add(&declaration, Route::Runtime)
                        .map_err(config::err)?;
                }
                providers.push(json!({"provider_id": "native", "admission": {
                    "release_identity": runtime.identity(), "release_admitted": runtime.release_admitted,
                    "image_sha256": runtime.image_sha256, "resource_identity": runtime.resource_identity,
                    "host_sha256": host_sha256, "reader_route": runtime.reader_route},
                    "containment": {"process": "in_host", "cancellation": "cooperative_budget"}}));
                Some(Arc::new(runtime))
            }
            None => None,
        };
        let pure = match &config.pure {
            Some(settings) => {
                let pure = Pure::open(&settings.profiles, &host_sha256, settings.solver.as_ref())?;
                for (profile, declaration) in pure.declarations() {
                    registry
                        .add(&declaration, Route::Pure(profile))
                        .map_err(config::err)?;
                }
                providers.push(json!({"provider_id": "pure", "admission": {"profiles": pure.profiles,
                    "host_sha256": host_sha256, "solver_sha256": pure.solver_sha256()},
                    "containment": {"process": "in_host", "cancellation": "cooperative_flag_and_native_limits"}}));
                Some(Arc::new(pure))
            }
            None => None,
        };
        let kernels = match &config.kernels {
            Some(settings) => {
                let kernels = Kernels::open(settings)?;
                providers.push(json!({"provider_id": "kernels", "admission": kernels.admissions(),
                    "containment": {"process": "resident_process_group_per_slot", "cancellation": "kill_and_reap"}}));
                Some(kernels)
            }
            None => None,
        };
        let engine = match &config.engine {
            Some(settings) => {
                let pool = EnginePool::open(settings, &boot)?;
                providers.push(json!({"provider_id": "engine", "admission": pool.admission,
                    "containment": {"process": "child_process_group", "cancellation": "kill_and_reap"}}));
                Some(pool)
            }
            None => None,
        };
        let admission = Admission::new(
            limits.capacity,
            limits.tenant_capacity.unwrap_or(limits.capacity),
        );
        let invocations = InvocationWorkers::new(limits.capacity)
            .map_err(|e| config::err(format!("invocation workers: {e}")))?;
        Ok(Arc::new(Self {
            limits,
            native,
            pure,
            kernels,
            engine,
            registry,
            journal,
            admission,
            invocations,
            stopping: AtomicBool::new(false),
            host_sha256,
            boot,
            providers,
            conversation_profile,
            native_conversation_profile,
            conversation_wikidata,
        }))
    }

    pub fn acquire(&self, tenant: &str) -> Option<Permit> {
        self.admission.acquire(tenant)
    }

    fn context(&self, timeout_ms: u64) -> Result<ExecutionContext, Failure> {
        ExecutionContext::new(
            self.limits.execution_fuel,
            Duration::from_millis(timeout_ms),
            Cancellation::default(),
        )
        .map(|context| context.restricted_memory(self.limits.request_memory_bytes))
        .map_err(|_| Failure::plain(503, "invalid_execution_deadline"))
    }

    fn stateful_operations(&self) -> Vec<&'static str> {
        self.native.as_ref().map_or(vec![], |n| {
            n.operations()
                .iter()
                .copied()
                .filter(|op| n.is_stateful(op))
                .collect()
        })
    }

    pub fn routes(&self) -> Vec<String> {
        let mut routes = vec!["native:modeling".to_owned()];
        if self.native.as_ref().is_some_and(|n| n.reader_route) {
            routes.push("native:reader".to_owned());
        }
        if let Some(kernels) = &self.kernels {
            routes.extend(kernels.organs.iter().map(|o| format!("organ:{}", o.id)));
        }
        if self.native_conversation_profile {
            routes.push("native:context".to_owned());
        } else if self.engine.is_some() {
            routes.push("engine".to_owned());
        }
        routes
    }

    pub fn health(&self) -> (u16, Value) {
        let ready = !self.stopping.load(Ordering::Acquire);
        let body = json!({"ready": ready, "backend": "oracle_host", "capacity": self.limits.capacity,
            "busy": self.admission.active(), "tenant_capacity": self.limits.tenant_capacity.unwrap_or(self.limits.capacity),
            "query_queue": 0,
            "durable_replay": true, "query_journal": if self.conversation_profile { "core-authoritative exact HTTP replay and admitted read-only owner snapshots" } else { "exact retained request replay; Engine context is not persisted" },
            "engine": self.engine.as_ref().map(EnginePool::health)});
        (if ready { 200 } else { 503 }, body)
    }

    pub fn capabilities(&self) -> Value {
        let stateful = self.stateful_operations();
        json!({"protocol": "oracle-appliance-v1", "backend": "oracle_host",
            "host": {"schema": config::SCHEMA, "binary_sha256": self.host_sha256},
            "operation_discovery": {"protocol": "oracle-operations-v1", "list": "/operations",
                "detail": "/operations/{operation_id}", "invoke": "/invoke", "state": "ready",
                "counts": {"live_direct": self.registry.items.len(), "text_only": 0, "unavailable": 0}},
            "query": {"routes": self.routes(), "groups": if self.native_conversation_profile {json!([["native:modeling"],["native:reader","organ:*"],["native:context"]])}else{json!([["native:modeling"],["native:reader", "organ:*"], ["engine"]])},
                "rule": "exact supplied-modeling prefix owns before depth groups; otherwise first depth group whose routes take the question decides; agreement or refusal, never a pick",
                "supplied_modeling": {"prefix":crate::modeling::PREFIX,"profile":"statistics","owner":"native:modeling","operations":["statistics.calibration","statistics.events_exposure"],"available":self.registry.routes.get("statistics.calibration")==Some(&Route::Pure("statistics")),"readonly_v1":"explicit unsupported transition refusal; no Engine projection","ordinary":"answers only without prior Engine binding; modeling results do not carry into later Engine context"},
                "agreement": {"text": "trimmed lowercase equality", "number": "within 0.5 percent with an identical explicit unit"}},
            "scope": "operator-admitted native operations, resident organs and a contained Engine; host-assigned tenant admission",
            "durable_conversations": !stateful.is_empty(), "durable_replay": true,
            "conversation_profile": if self.native_conversation_profile {json!({"id":"native-v1","state_authority":"core session and exact HTTP reply transaction","coverage":"finite native Empty/Entity/Quantity owner; admitted image selection and explicit supplied/provider quantities","engine":"no initialization, dispatch or fallback; Python state is not covered","entity_scope":"the admitted native image snapshot, without U8 or world-completeness claims","unsupported_transition":"unread requests and semantic refusals preserve; delivered answers without an admitted typed anchor clear native anchor and selection","initialization":"only a genuinely absent session; retained history requires this checked native owner"})} else if self.conversation_profile {json!({"id":"readonly-v1","state_authority":"core session and exact HTTP reply transaction","entity_namespace":if self.conversation_wikidata {"operator-declared Wikidata: KQA Q identifiers map to wd:Q identifiers"}else{"cross-provider entity projection unsupported; no namespace admitted"},"coverage":"adapter-declared read-only entity, quantity, pending conversion and dialogue owners only","native_invocation_owners":"native selection/scalar/evidence; no implicit Python context consumption","refusal_transition":"delivered query refusals advance session revision while retaining native selection","opaque_failure":"uncertain dispatch requires reset; exact retained requests replay"})}else{Value::Null},
            "query_journal": {"durable_replay": true, "engine_context_persisted": self.conversation_profile && !self.native_conversation_profile,
                "engine_conversation_recovery": if self.native_conversation_profile {"not used; native-v1 never dispatches the Engine"} else if self.conversation_profile { "restore only admitted covered snapshots; uncovered legacy Engine conversations require reset" } else { "fresh conversation required after worker loss, eviction, uncertainty or host restart; exact retained requests replay" }},
            "durable_operations": stateful,
            "request_id_semantics": if self.conversation_profile { "/query and stateful /invoke share endpoint-tagged request IDs and core revisions; exact completed HTTP bytes replay; legacy host replies retained, cross-journal collisions conflict; pure calls correlation only" } else { "/query: exact retry from the host journal; stateful native turns: exact core reply replay; pure calls: correlation only" },
            "tenant_header_authentication": false, "mini_qualified": false, "query_queue": 0,
            "limits": {"request_bytes": self.limits.request_bytes, "reply_bytes": self.limits.reply_bytes,
                       "capacity": self.limits.capacity, "tenant_capacity": self.limits.tenant_capacity.unwrap_or(self.limits.capacity),
                       "invoke_ms": self.limits.invoke_ms, "query_ms": self.limits.query_ms,
                       "execution_fuel": self.limits.execution_fuel,
                       "request_memory_bytes": self.limits.request_memory_bytes,
                       "memory_scope": "explicitly tracked retained request data; excludes untracked foreign allocations"},
            "invocation_workers": {"threads": self.limits.capacity, "waiting_queue": 0,
                "policy": "immediate refusal when no idle worker; no fairness guarantee"},
            "providers": self.providers})
    }

    pub fn discover(&self, parameters: &Discovery) -> (u16, Value) {
        if self.stopping.load(Ordering::Acquire) {
            return (503, failure("service_stopping", json!({})));
        }
        let result = match parameters {
            Discovery::Detail(id) => self.registry.detail(id),
            Discovery::List {
                offset,
                limit,
                q,
                availability,
            } => self
                .registry
                .list(*offset, *limit, q, availability.as_deref()),
        };
        match result {
            Ok(body) => (200, body),
            Err(f) => (f.status, f.body),
        }
    }

    /// Value compatibility for direct library callers. HTTP retains the encoded buffer.
    pub fn invoke(self: &Arc<Self>, tenant: &str, raw: &[u8]) -> (u16, Value) {
        self.invoke_encoded(tenant, raw).into_value()
    }

    pub fn invoke_encoded(self: &Arc<Self>, tenant: &str, raw: &[u8]) -> wire::EncodedReply {
        if self.conversation_profile {
            if let Ok(request) = envelope(raw, "/invoke", self.limits.request_bytes) {
                if self
                    .native
                    .as_ref()
                    .is_some_and(|n| n.is_stateful(request["operation_id"].as_str().unwrap_or("")))
                {
                    return match self.covered_invoke(tenant, raw, &request) {
                        Ok(reply) => reply,
                        Err(f) => self.encode_response(f.status, &f.body),
                    };
                }
            }
        }
        match self.invoke_body(tenant, raw) {
            Ok(body) => {
                let stateful = body.durable_replay;
                match wire::EncodedReply::encode(200, &body, self.limits.reply_bytes) {
                    Ok(encoded) => encoded,
                    Err(_) => self.encode_response(
                        502,
                        &failure(
                            "reply_too_large",
                            json!({
                                "execution_completed": true, "state_may_have_changed": stateful,
                                "retryable": stateful, "exact_retry_required": stateful
                            }),
                        ),
                    ),
                }
            }
            Err(f) => self.encode_response(f.status, &f.body),
        }
    }

    fn invoke_body(
        self: &Arc<Self>,
        tenant: &str,
        raw: &[u8],
    ) -> Result<CompletedInvocation, Failure> {
        let request = envelope(raw, "/invoke", self.limits.request_bytes)?;
        if self.stopping.load(Ordering::Acquire) {
            return Err(Failure::plain(503, "service_stopping"));
        }
        let id = request["operation_id"].as_str().unwrap_or("").to_owned();
        let route = self.registry.check_arguments(&id, &request["arguments"])?;
        let stateful = matches!(route, Route::Runtime)
            && self.native.as_ref().is_some_and(|n| n.is_stateful(&id));
        let conversation_lease = if stateful {
            Some(
                self.journal
                    .lease(tenant, request["conversation_id"].as_str().unwrap_or(""))?,
            )
        } else {
            None
        };
        let permit = self.acquire(tenant).ok_or_else(|| Failure::new(429, "pool_busy",
            json!({"retryable": true, "state_may_have_changed": false, "exact_retry_required": false})))?;
        let (sender, receiver) = mpsc::channel();
        let context = self.context(self.limits.invoke_ms)?;
        let started = Instant::now();
        {
            let native = self.native.clone();
            let pure = self.pure.clone();
            let tenant = tenant.to_owned();
            let context = context.clone();
            let id = id.clone();
            if !self.invocations.try_submit(move || {
                let _permit = permit;
                let _conversation_lease = conversation_lease;
                let arguments = &request["arguments"];
                let result = match route {
                    Route::Runtime => native
                        .as_ref()
                        .expect("runtime route")
                        .invoke(
                            &id,
                            arguments,
                            &tenant,
                            request["request_id"].as_str().unwrap_or(""),
                            request["conversation_id"].as_str().unwrap_or(""),
                            context,
                            pure.as_ref().and_then(|p| p.solver_path()),
                            pure.as_ref().and_then(|p| p.solver_sha256()),
                        )
                        .map(InvocationReply::Runtime),
                    Route::Pure(profile) => pure
                        .as_ref()
                        .expect("pure route")
                        .invoke_checked(profile, &id, arguments, &tenant, &context)
                        .map(InvocationReply::Pure),
                };
                let _ = sender.send(result);
            }) {
                return Err(Failure::new(
                    429,
                    "pool_busy",
                    json!({"retryable": true,
                    "state_may_have_changed": false, "exact_retry_required": false}),
                ));
            }
        }
        let reply = match receiver
            .recv_timeout(context.deadline().saturating_duration_since(Instant::now()))
        {
            Ok(result) => result?,
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                return Err(Failure::new(
                    502,
                    "runtime_error",
                    json!({"retryable": stateful, "state_may_have_changed": stateful, "exact_retry_required": stateful}),
                ))
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                // Work owns its permit even after this receiver and context return.
                context.cancellation().cancel();
                return Err(Failure::new(
                    503,
                    "deadline_exceeded",
                    json!({"retryable": stateful,
                    "state_may_have_changed": stateful, "exact_retry_required": stateful}),
                ));
            }
        };
        Ok(CompletedInvocation {
            outcome: "completed",
            operation_id: id,
            reply,
            durable_replay: stateful,
            native_execution: [
                json!({"admission": {"host_sha256": self.host_sha256, "route": match route {
                Route::Runtime => "runtime".to_owned(), Route::Pure(p) => p.to_owned() }},
                "containment": {"process": "in_host", "elapsed_ms": started.elapsed().as_millis() as u64}}),
            ],
        })
    }

    /// All Value-based routes share the same bounded transport encoder. The
    /// configured 1024-byte minimum leaves room for this fixed-size refusal.
    pub(crate) fn encode_response(&self, status: u16, body: &Value) -> wire::EncodedReply {
        wire::EncodedReply::encode(status, body, self.limits.reply_bytes).unwrap_or_else(|_| {
            let mut replacement = failure("reply_too_large", json!({
                "execution_completed": body["outcome"] == "completed" || body["execution_completed"] == true
            }));
            for field in ["state_may_have_changed", "exact_retry_required", "retryable"] {
                if let Some(value) = body.get(field) { replacement[field] = value.clone(); }
            }
            if body.get("http_status").is_some() { replacement["http_status"] = json!(502); }
            wire::EncodedReply::encode(502, &replacement, self.limits.reply_bytes)
                .expect("reply_bytes admits the fixed-size refusal")
        })
    }

    pub fn query(&self, tenant: &str, raw: &[u8]) -> (u16, Value) {
        self.query_encoded(tenant, raw).into_value()
    }

    pub fn query_encoded(&self, tenant: &str, raw: &[u8]) -> wire::EncodedReply {
        if self.conversation_profile {
            return match self.covered_query(tenant, raw) {
                Ok(reply) => reply,
                Err(f) => self.encode_response(f.status, &f.body),
            };
        }
        let request = match envelope(raw, "/query", self.limits.request_bytes) {
            Ok(r) => r,
            Err(f) => return self.encode_response(f.status, &f.body),
        };
        let request_id = request["request_id"].as_str().unwrap_or("");
        match self
            .journal
            .begin_encoded(tenant, request_id, raw, self.limits.reply_bytes)
        {
            Ok(EncodedLookup::Replay(reply)) => return reply,
            Ok(EncodedLookup::Fresh) => {}
            Err(f) => return self.encode_response(f.status, &f.body),
        }
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        let context = match self.context(self.limits.query_ms) {
            Ok(context) => context,
            Err(f) => {
                if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                    return self.encode_response(e.status, &e.body);
                }
                return self.encode_response(f.status, &f.body);
            }
        };
        let _lease = match self.journal.lease(tenant, conversation) {
            Ok(lease) => lease,
            Err(f) => {
                if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                    return self.encode_response(e.status, &e.body);
                }
                return self.encode_response(f.status, &f.body);
            }
        };
        let Some(_permit) = self.acquire(tenant) else {
            if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                return self.encode_response(e.status, &e.body);
            }
            return self.encode_response(429, &failure("busy", json!({"retryable": true})));
        };
        if self.stopping.load(Ordering::Acquire) {
            if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                return self.encode_response(e.status, &e.body);
            }
            return self.encode_response(
                503,
                &failure("backend_unavailable", json!({"retryable": false})),
            );
        }
        // Retain possible opaque effects even if execution unwinds.
        let mut modeling_owner = None;
        let turn = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            self.turn(tenant, &request, &context, &mut modeling_owner)
        }))
        .unwrap_or_else(|_| {
            Err(Failure::new(
                502,
                "runtime_error",
                json!({"state_may_have_changed": true, "exact_retry_required": true}),
            ))
        });
        match turn {
            Ok(result) => self.finish_query(tenant, request_id, conversation, result),
            Err(mut f) => {
                if f.body["state_may_have_changed"] == true {
                    f.body["http_status"] = json!(f.status);
                    let encoded = self.encode_response(f.status, &f.body);
                    // The uncertainty body cannot clear the conversation poison.
                    // A failed journal latches and retains the pending record.
                    let _ = self.journal.finish_bytes(
                        tenant,
                        request_id,
                        conversation,
                        encoded.body(),
                        false,
                    );
                    encoded
                } else {
                    if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                        return self.encode_response(e.status, &e.body);
                    }
                    self.encode_response(f.status, &f.body)
                }
            }
        }
    }

    fn finish_query(
        &self,
        tenant: &str,
        request_id: &str,
        conversation: &str,
        result: Value,
    ) -> wire::EncodedReply {
        // Compute this predicate from the same Value we encode. A replacement
        // refusal must NEVER inherit a completed=true flag from its oversized turn.
        let (encoded, completed) = match wire::EncodedReply::encode(
            crate::journal::status_of(&result),
            &result,
            self.limits.reply_bytes,
        ) {
            Ok(encoded) => (encoded, result["outcome"] == "completed"),
            Err(_) => (
                self.encode_response(
                    502,
                    &failure(
                        "reply_too_large",
                        json!({"execution_completed": true, "state_may_have_changed": true}),
                    ),
                ),
                false,
            ),
        };
        if let Err(f) =
            self.journal
                .finish_bytes(tenant, request_id, conversation, encoded.body(), completed)
        {
            return self.encode_response(f.status, &f.body);
        }
        encoded
    }

    /// One front-door turn. Failures explicitly carry opaque-effect uncertainty.
    fn turn(
        &self,
        tenant: &str,
        request: &Value,
        context: &ExecutionContext,
        modeling_owner: &mut Option<CheckedPureReply>,
    ) -> Result<Value, Failure> {
        check_context(context)?;
        let text = request["text"].as_str().unwrap_or("");
        let modeling_transition_supported = !text.starts_with(crate::modeling::PREFIX)
            || self
                .journal
                .conversation(tenant, request["conversation_id"].as_str().unwrap_or(""))?
                .is_none();
        if let Some(answer) = crate::modeling::answer(
            text,
            self.pure.as_deref(),
            tenant,
            context,
            modeling_owner,
            modeling_transition_supported,
        ) {
            return answer;
        }
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        let prefer = match self.journal.conversation(tenant, conversation)? {
            Some((worker, generation)) => {
                let parsed = generation
                    .split_once(':')
                    .filter(|(boot, _)| *boot == self.boot)
                    .and_then(|(_, n)| n.parse::<u64>().ok());
                match parsed {
                    Some(n) => Some((worker, n)),
                    None => return Err(reset_required()),
                }
            }
            None => None,
        };
        self.validate_conversation_binding(tenant, prefer)?;
        let mut first: Vec<Candidate> = Vec::new();
        std::thread::scope(|scope| {
            let reader = self
                .native
                .as_ref()
                .filter(|n| n.reader_route)
                .map(|native| {
                    let context = context.clone();
                    scope.spawn(move || native.ask_reader(tenant, text, context))
                });
            // KernelExecutor admits one call per tenant at a time, so the
            // organs (milliseconds each) are asked in order, beside the reader.
            let organs = self.kernels.as_ref().map(|kernels| {
                let context = context.clone();
                scope.spawn(move || {
                    kernels
                        .organs
                        .iter()
                        .map(|o| kernels.ask(o, tenant, text, context.clone()))
                        .collect::<Vec<_>>()
                })
            });
            if let Some(handle) = reader {
                first.push(handle.join().unwrap_or_else(|_| {
                    Candidate::unavailable("native:reader".into(), 0, "panic", 0.0)
                }));
            }
            if let Some(handle) = organs {
                match handle.join() {
                    Ok(candidates) => first.extend(candidates),
                    Err(_) => first.push(Candidate::unavailable("organ".into(), 0, "panic", 0.0)),
                }
            }
        });
        check_context(context)?;
        let group0: Vec<&Candidate> = first.iter().collect();
        let decision = front::decide(&group0).map_err(|e| {
            Failure::new(
                502,
                "arbitration_error",
                json!({"detail": e, "state_may_have_changed": false}),
            )
        })?;
        if !matches!(decision, Decision::NoReading) || self.engine.is_none() {
            // Group zero reads no Engine context. Revalidate at its reply
            // linearization point: eviction observed during pure evaluation
            // refuses this turn. This is not atomic mixed native/Engine state
            // projection; full context projection is not implemented.
            self.validate_conversation_binding(tenant, prefer)?;
            let decided = (!matches!(decision, Decision::NoReading)).then_some(0);
            return Ok(
                json!({"outcome": "completed", "reply": front::reply(&decision, &group0, &first, decided)}),
            );
        }
        check_context(context)?;
        let engine = self.engine.as_ref().expect("engine");
        let session = format!(
            "h{}",
            &config::sha256_bytes(
                format!("oracle-host-v1\0session\0{tenant}\0{conversation}").as_bytes()
            )[..40]
        );
        let started = Instant::now();
        self.journal.dispatch(
            tenant,
            request["request_id"].as_str().unwrap_or(""),
            conversation,
        )?;
        match engine.ask_with_context(tenant, text, &session, prefer, context) {
            Ok((reply, worker, generation)) => {
                self.journal.bind(
                    tenant,
                    conversation,
                    worker,
                    &format!("{}:{generation}", self.boot),
                )?;
                first.push(engine.candidate(&reply, started.elapsed().as_secs_f64() * 1000.0));
                let all = first;
                let group1: Vec<&Candidate> = all.iter().filter(|c| c.group == 1).collect();
                let decision = front::decide(&group1).map_err(|e| {
                    Failure::new(
                        502,
                        "arbitration_error",
                        json!({"detail": e, "state_may_have_changed": true}),
                    )
                })?;
                Ok(
                    json!({"outcome": "completed", "reply": front::reply(&decision, &group1, &all, Some(1))}),
                )
            }
            Err((EngineError::Busy, _)) => {
                Err(Failure::new(429, "busy", json!({"retryable": true})))
            }
            Err((EngineError::Stopping, _)) => Err(Failure::new(
                503,
                "backend_unavailable",
                json!({"retryable": false}),
            )),
            Err((EngineError::Starting, _)) => Err(Failure::new(
                503,
                "backend_unavailable",
                json!({"retryable": true}),
            )),
            Err((EngineError::Lost("conversation_reset_required"), _)) => Err(reset_required()),
            Err((EngineError::Lost("engine_start_failed"), _)) => Err(Failure::new(
                503,
                "backend_unavailable",
                json!({"retryable": true, "detail": "engine_start_failed"}),
            )),
            Err((EngineError::Budget(error), place)) => {
                Err(query_context_failure(error, place.is_some()))
            }
            Err((EngineError::Timeout, _)) => Ok(failure(
                "query_timeout",
                json!({"state_may_have_changed": true}),
            )),
            Err((EngineError::Lost(code), _)) => {
                Ok(failure(code, json!({"state_may_have_changed": true})))
            }
        }
    }

    fn validate_conversation_binding(
        &self,
        tenant: &str,
        prefer: Option<(usize, u64)>,
    ) -> Result<(), Failure> {
        if let (Some(engine), Some((worker, generation))) = (&self.engine, prefer) {
            match engine.validate_binding(tenant, worker, generation) {
                Ok(()) => {}
                Err(EngineError::Busy) => {
                    return Err(Failure::new(429, "busy", json!({"retryable":true})))
                }
                Err(_) => return Err(reset_required()),
            }
        }
        Ok(())
    }

    pub fn close(&self) {
        self.stopping.store(true, Ordering::Release);
        self.invocations.shutdown();
        if let Some(engine) = &self.engine {
            engine.close();
        }
    }
}

fn retained_core(reply: ConversationHttpReply) -> wire::EncodedReply {
    wire::EncodedReply::retained(reply.status, reply.body)
}

impl Service {
    fn conversation_identity(
        &self,
        request: &Value,
        endpoint: &str,
        raw: &[u8],
    ) -> (String, String, ConversationRequest) {
        let operation = if endpoint == "/query" {
            "query"
        } else {
            request["operation_id"].as_str().unwrap_or("")
        };
        let input = if endpoint == "/query" {
            ConversationInput::ExactBytes(raw.to_vec())
        } else if request["arguments"].get("count_scope").is_some() {
            ConversationInput::Typed(request["arguments"].clone())
        } else if request["arguments"].get("command").is_some() {
            ConversationInput::Typed(request["arguments"]["command"].clone())
        } else {
            let field = if operation == "graph.execute" {
                "plan_json"
            } else if operation == "kqa.execute" {
                "program_json"
            } else {
                "question"
            };
            ConversationInput::ExactBytes(
                request["arguments"][field]
                    .as_str()
                    .unwrap_or("")
                    .as_bytes()
                    .to_vec(),
            )
        };
        (
            crate::native::core_id("session", request["conversation_id"].as_str().unwrap_or(""))
                .expect("validated conversation"),
            crate::native::core_id("request", request["request_id"].as_str().unwrap_or(""))
                .expect("validated request"),
            ConversationRequest {
                endpoint: endpoint.into(),
                operation: if self.native_conversation_profile {
                    format!("native-v1.{operation}")
                } else {
                    operation.into()
                },
                expected_version: if endpoint == "/query" {
                    None
                } else {
                    request["arguments"]["expected_version"].as_i64()
                },
                input,
            },
        )
    }

    /// HTTP serialization is admitted before the only successful durable write.
    /// On an unknown commit outcome, completion takes precedence over uncertainty.
    fn commit_covered(
        &self,
        tenant: &str,
        session: &str,
        id: &str,
        identity: &ConversationRequest,
        candidate: ConversationCandidate,
        encoded: wire::EncodedReply,
        budget: &core::Budget,
    ) -> Result<wire::EncodedReply, Failure> {
        let native = self.native.as_ref().expect("covered native");
        match native.runtime.conversation_commit(
            candidate,
            encoded.status(),
            encoded.body(),
            budget,
        ) {
            Ok(reply) => Ok(retained_core(reply)),
            Err(error) => match native
                .runtime
                .conversation_completion(tenant, session, id, identity)
            {
                Ok(Some(reply)) => Ok(retained_core(reply)),
                Ok(None) => Err(crate::native::conversation_failure(error)),
                Err(_) => Err(Failure::new(
                    507,
                    "conversation_commit_unknown",
                    json!({"state_may_have_changed":true,"exact_retry_required":true}),
                )),
            },
        }
    }

    fn covered_invoke(
        &self,
        tenant: &str,
        raw: &[u8],
        request: &Value,
    ) -> Result<wire::EncodedReply, Failure> {
        let native = self.native.as_ref().expect("covered native");
        let id = request["operation_id"].as_str().unwrap_or("");
        self.registry.check_arguments(id, &request["arguments"])?;
        let (session, request_id, identity) = self.conversation_identity(request, "/invoke", raw);
        let outer_id = request["request_id"].as_str().unwrap_or("");
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        // Typed invocation retries retain their admitted command identity even
        // when object-key order differs on the wire.
        let ledger_body = wire::encode(request);
        if let Some(reply) = native
            .runtime
            .conversation_completion(tenant, &session, &request_id, &identity)
            .map_err(crate::native::conversation_failure)?
        {
            let _ = self
                .journal
                .acknowledge_core(tenant, outer_id, conversation);
            return Ok(retained_core(reply));
        }
        if let Some(reply) = self.covered_ledger_replay(tenant, outer_id, &ledger_body)? {
            return Ok(reply);
        }
        let _lease = self
            .journal
            .lease(tenant, request["conversation_id"].as_str().unwrap_or(""))?;
        let _permit = self
            .acquire(tenant)
            .ok_or_else(|| Failure::plain(429, "pool_busy"))?;
        if self.stopping.load(Ordering::Acquire) {
            return Err(Failure::plain(503, "service_stopping"));
        }
        let context = self.context(self.limits.invoke_ms)?;
        let budget = core::Budget::from_execution_context(context.clone())
            .restricted_to(&native.runtime.image.limits)
            .map_err(crate::native::conversation_failure)?;
        let mut candidate = match native
            .runtime
            .conversation_begin(tenant, &session, &request_id, &identity, &budget)
            .map_err(crate::native::conversation_failure)?
        {
            ConversationBegin::Replay(reply) => return Ok(retained_core(reply)),
            ConversationBegin::Fresh(candidate) => candidate,
        };
        if self.native_conversation_profile {
            self.prepare_native_profile(tenant, conversation, &mut candidate, &budget)?;
        }
        if self.engine.is_some() && !self.native_conversation_profile {
            if let Some((_, generation)) = self.journal.conversation(tenant, conversation)? {
                if candidate.envelope.oracle.is_none() || generation == "poisoned" {
                    return Err(reset_required());
                }
            }
            if candidate.envelope.oracle.is_none() && !candidate.starts_new_session() {
                return Err(reset_required());
            }
        }
        match self
            .journal
            .begin_encoded(tenant, outer_id, &ledger_body, self.limits.reply_bytes)?
        {
            EncodedLookup::Replay(reply) => return Ok(reply),
            EncodedLookup::Fresh => {}
        }
        let mut dispatched = false;
        let mut binding = None;
        let turn=std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let started = Instant::now();
        let reply =
            native.propose_invocation(&mut candidate, id, &request["arguments"], &budget)?;
        if self.native_conversation_profile {
            native.runtime.conversation_native_reconcile_selection(&mut candidate,&budget)
                .map_err(crate::native::conversation_failure)?;
        }
        let body = CompletedInvocation {
            outcome: "completed",
            operation_id: id.into(),
            reply: InvocationReply::Runtime(reply),
            durable_replay: true,
            native_execution: [
                json!({"admission":{"host_sha256":self.host_sha256,"route":"runtime"},"containment":{"process":"in_host","elapsed_ms":started.elapsed().as_millis() as u64}}),
            ],
        };
        let encoded = wire::EncodedReply::encode(
            200,
            &body,
            self.limits
                .reply_bytes
                .min(native.runtime.image.limits.result_bytes),
        )
        .map_err(|_| {
            Failure::new(
                502,
                "reply_too_large",
                json!({"execution_completed":false,"state_may_have_changed":false}),
            )
        })?;
        // Reject malformed native inputs and oversized final replies before
        // starting any adapter work. Capture changes only Python-owned fields.
        if !self.native_conversation_profile && self.engine.is_some() && candidate.envelope.oracle.is_none() {
            self.initialize_invoke_snapshot(tenant,request,&mut candidate,&context,&mut dispatched,&mut binding)?;
        }
        self.commit_covered(
            tenant,
            &session,
            &request_id,
            &identity,
            candidate,
            encoded,
            &budget,
        )
        })).unwrap_or_else(|_|Err(Failure::plain(502,"runtime_error")));
        self.finish_covered_request(
            tenant,
            outer_id,
            conversation,
            &session,
            &request_id,
            &identity,
            turn,
            dispatched,
            binding,
        )
    }
}

// This boundary is used only before dispatching opaque Engine effects.
fn check_context(context: &ExecutionContext) -> Result<(), Failure> {
    context
        .check()
        .map_err(|error| query_context_failure(error, false))
}

fn query_context_failure(error: oracle_execution::ExecutionError, dispatched: bool) -> Failure {
    use oracle_execution::ExecutionError;
    let (status, code) = match error {
        ExecutionError::Cancelled => (503, "query_cancelled"),
        ExecutionError::Deadline => (504, "query_timeout"),
        ExecutionError::FuelExhausted => (503, "query_budget"),
        _ => (503, "execution_unavailable"),
    };
    Failure::new(
        status,
        code,
        json!({"retryable": true,
        "state_may_have_changed": dispatched, "exact_retry_required": dispatched}),
    )
}

fn reset_required() -> Failure {
    Failure::new(
        409,
        "conversation_reset_required",
        json!({"executed": false,
        "fresh_conversation_required": true, "retryable": false}),
    )
}

pub enum Discovery {
    Detail(String),
    List {
        offset: usize,
        limit: usize,
        q: String,
        availability: Option<String>,
    },
}

#[cfg(test)]
#[path = "encoded_reply_tests.rs"]
mod encoded_reply_tests;

impl Service {
    fn prepare_native_profile(
        &self,
        tenant: &str,
        conversation: &str,
        candidate: &mut ConversationCandidate,
        budget: &core::Budget,
    ) -> Result<(), Failure> {
        // A previous opaque binding is never adopted, even if its core row was
        // lost or absent. Native ownership does not imply Python coverage.
        if self.journal.conversation(tenant, conversation)?.is_some() {
            return Err(reset_required());
        }
        let runtime = &self.native.as_ref().expect("native profile").runtime;
        if candidate.starts_new_session() {
            runtime
                .conversation_native_initialize(candidate, budget)
                .map_err(crate::native::conversation_failure)?;
        }
        runtime
            .conversation_native_validate(candidate, budget)
            .map_err(|_| reset_required())?;
        Ok(())
    }

    fn covered_ledger_replay(
        &self,
        tenant: &str,
        id: &str,
        body: &[u8],
    ) -> Result<Option<wire::EncodedReply>, Failure> {
        if let Some((previous, result, phase)) = self.journal.retained_request(tenant, id)? {
            if previous != body {
                return Err(Failure::plain(409, "request_id_conflict"));
            }
            if result.is_some() || phase.starts_with("recovered_") {
                return match self.journal.begin_encoded(
                    tenant,
                    id,
                    body,
                    self.limits.reply_bytes,
                )? {
                    EncodedLookup::Replay(reply) => Ok(Some(reply)),
                    EncodedLookup::Fresh => Err(Failure::plain(503, "journal_inconsistent")),
                };
            }
            return Err(Failure::new(429, "busy", json!({"retryable":true})));
        }
        Ok(None)
    }

    /// Initialize only a genuinely absent conversation by asking the admitted
    /// adapter to capture its real empty owner state. No native result is
    /// projected into Python; native invocation owners remain independent.
    fn initialize_invoke_snapshot(
        &self,
        tenant: &str,
        request: &Value,
        candidate: &mut ConversationCandidate,
        context: &ExecutionContext,
        dispatched: &mut bool,
        binding: &mut Option<(usize, u64)>,
    ) -> Result<(), Failure> {
        if !candidate.starts_new_session() || candidate.envelope.oracle.is_some() {
            return Err(reset_required());
        }
        let engine = self.engine.as_ref().expect("initialization Engine");
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        let committed = serde_json::to_value(&candidate.envelope)
            .map_err(|_| Failure::plain(502, "state_encoding"))?;
        let engine_session = format!(
            "h{}",
            &config::sha256_bytes(
                format!("oracle-host-v1\0session\0{tenant}\0{conversation}").as_bytes()
            )[..40]
        );
        self.journal.dispatch(
            tenant,
            request["request_id"].as_str().unwrap_or(""),
            conversation,
        )?;
        *dispatched = true;
        let delivered = json!({"conversation_projection":{"preserve":true}});
        let (capture, worker, generation) = engine
            .project_conversation_with_context(
                tenant,
                &engine_session,
                None,
                &committed,
                &delivered,
                context,
            )
            .map_err(|(_, place)| {
                if place.is_none() {
                    *dispatched = false;
                }
                *binding = place;
                Failure::plain(503, "conversation_initialization_unavailable")
            })?;
        *binding = Some((worker, generation));
        Self::install_capture(candidate, &capture)
    }

    fn covered_query(&self, tenant: &str, raw: &[u8]) -> Result<wire::EncodedReply, Failure> {
        let request = envelope(raw, "/query", self.limits.request_bytes)?;
        let native = self.native.as_ref().expect("covered native");
        let outer_id = request["request_id"].as_str().unwrap_or("");
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        let (session, request_id, identity) = self.conversation_identity(&request, "/query", raw);
        // Completion precedes host crash classification, admission and cancellation.
        if let Some(reply) = native
            .runtime
            .conversation_completion(tenant, &session, &request_id, &identity)
            .map_err(crate::native::conversation_failure)?
        {
            let _ = self
                .journal
                .acknowledge_core(tenant, outer_id, conversation);
            return Ok(retained_core(reply));
        }
        if let Some(reply) = self.covered_ledger_replay(tenant, outer_id, raw)? {
            return Ok(reply);
        }
        let _lease = self.journal.lease(tenant, conversation)?;
        let _permit = self
            .acquire(tenant)
            .ok_or_else(|| Failure::plain(429, "pool_busy"))?;
        if self.stopping.load(Ordering::Acquire) {
            return Err(Failure::plain(503, "service_stopping"));
        }
        let context = self.context(self.limits.query_ms)?;
        let budget = core::Budget::from_execution_context(context.clone())
            .restricted_to(&native.runtime.image.limits)
            .map_err(crate::native::conversation_failure)?;
        let mut candidate = match native
            .runtime
            .conversation_begin(tenant, &session, &request_id, &identity, &budget)
            .map_err(crate::native::conversation_failure)?
        {
            ConversationBegin::Replay(reply) => return Ok(retained_core(reply)),
            ConversationBegin::Fresh(candidate) => candidate,
        };
        if self.native_conversation_profile {
            self.prepare_native_profile(tenant, conversation, &mut candidate, &budget)?;
        }
        // An uncovered retained Engine binding has no recoverable snapshot.
        if let Some((_, generation)) = self.journal.conversation(tenant, conversation)? {
            if candidate.envelope.oracle.is_none() || generation == "poisoned" {
                return Err(reset_required());
            }
        }
        match self
            .journal
            .begin_encoded(tenant, outer_id, raw, self.limits.reply_bytes)?
        {
            EncodedLookup::Replay(reply) => return Ok(reply),
            EncodedLookup::Fresh => {}
        }
        let mut dispatched = false;
        let mut binding = None;
        let mut modeling_owner = None;
        let turn = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            self.covered_turn(
                tenant,
                &request,
                &mut candidate,
                &budget,
                &context,
                &mut dispatched,
                &mut binding,
                &mut modeling_owner,
            )
        }))
        .unwrap_or_else(|_| Err(Failure::plain(502, "runtime_error")));
        let final_reply = turn.and_then(|mut body| {
            if self.native_conversation_profile {
                let version = candidate
                    .revision()
                    .checked_add(1)
                    .ok_or_else(|| Failure::plain(503, "conversation_version_unavailable"))?;
                body["conversation_version"] = json!(version);
            }
            let encoded = wire::EncodedReply::encode(
                200,
                &body,
                self.limits
                    .reply_bytes
                    .min(native.runtime.image.limits.result_bytes),
            )
            .map_err(|_| Failure::plain(502, "reply_too_large"))?;
            self.commit_covered(
                tenant,
                &session,
                &request_id,
                &identity,
                candidate,
                encoded,
                &budget,
            )
        });
        self.finish_covered_request(
            tenant,
            outer_id,
            conversation,
            &session,
            &request_id,
            &identity,
            final_reply,
            dispatched,
            binding,
        )
    }

    fn finish_covered_request(
        &self,
        tenant: &str,
        outer_id: &str,
        conversation: &str,
        session: &str,
        request_id: &str,
        identity: &ConversationRequest,
        final_reply: Result<wire::EncodedReply, Failure>,
        dispatched: bool,
        binding: Option<(usize, u64)>,
    ) -> Result<wire::EncodedReply, Failure> {
        let native = self.native.as_ref().expect("covered native");
        match final_reply {
            Ok(reply) => {
                // Lost host acknowledgement cannot replace authoritative success.
                let _ = self
                    .journal
                    .acknowledge_core(tenant, outer_id, conversation);
                Ok(reply)
            }
            Err(mut f) => {
                // Includes panic and failure during response encoding/capture.
                // A commit acknowledgement may have been lost on any error path.
                if let Ok(Some(reply)) =
                    native
                        .runtime
                        .conversation_completion(tenant, &session, &request_id, &identity)
                {
                    let _ = self
                        .journal
                        .acknowledge_core(tenant, outer_id, conversation);
                    return Ok(retained_core(reply));
                }
                if dispatched {
                    if let (Some(engine), Some(binding)) = (&self.engine, binding) {
                        let _ = engine.retire_binding(tenant, binding);
                    }
                    f.body["state_may_have_changed"] = json!(true);
                    f.body["exact_retry_required"] = json!(true);
                    f.body["retryable"] = json!(false);
                    f.body["http_status"] = json!(f.status);
                    let reply = self.encode_response(f.status, &f.body);
                    let _ = self.journal.finish_bytes(
                        tenant,
                        outer_id,
                        conversation,
                        reply.body(),
                        false,
                    );
                    Ok(reply)
                } else {
                    self.journal.forget(tenant, outer_id, conversation)?;
                    Err(f)
                }
            }
        }
    }

    fn install_capture(
        candidate: &mut ConversationCandidate,
        reply: &Value,
    ) -> Result<(), Failure> {
        let capture = reply
            .get("conversation")
            .ok_or_else(|| Failure::plain(502, "conversation_capture_missing"))?;
        if capture["protocol"] != "oracle-conversation-v1"
            || capture["coverage"]["complete"] != true
            || capture["coverage"]["scope"] != "supported_adapter_routes"
            || capture["adapter_schema"] != 1
        {
            return Err(Failure::plain(409, "conversation_unsupported"));
        }
        let source = capture["source"]
            .as_str()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| Failure::plain(502, "conversation_capture_source"))?;
        let state = serde_json::from_value(capture["state"].clone())
            .map_err(|_| Failure::plain(502, "conversation_capture_invalid"))?;
        candidate.envelope.oracle = Some(state);
        candidate.envelope.coverage = core::session::StateCoverage::OracleAdapter {
            adapter_schema: 1,
            source: source.into(),
        };
        Ok(())
    }

    fn covered_turn(
        &self,
        tenant: &str,
        request: &Value,
        candidate: &mut ConversationCandidate,
        budget: &core::Budget,
        context: &ExecutionContext,
        dispatched: &mut bool,
        binding: &mut Option<(usize, u64)>,
        modeling_owner: &mut Option<CheckedPureReply>,
    ) -> Result<Value, Failure> {
        let native = self.native.as_ref().expect("covered native");
        let text = request["text"].as_str().unwrap_or("");
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        check_context(context)?;
        if let Some(answer) = crate::modeling::answer(
            text,
            self.pure.as_deref(),
            tenant,
            context,
            modeling_owner,
            self.native_conversation_profile,
        ) {
            let mut body = answer?;
            if self.native_conversation_profile && body["reply"]["status"] == "answered" {
                let command = match crate::modeling::retained_model(&body["reply"]) {
                    Some(model) => {
                        core::native_conversation::NativeContextCommand::InstallModel { model }
                    }
                    None => core::native_conversation::NativeContextCommand::ResetTopic,
                };
                native
                    .runtime
                    .conversation_native_command(candidate, command, budget)
                    .map_err(crate::native::conversation_failure)?;
                native
                    .runtime
                    .conversation_native_reconcile_selection(candidate, budget)
                    .map_err(crate::native::conversation_failure)?;
                body["reply"]["native_context_transition"] =
                    json!("cleared_unrepresentable_answer");
            } else {
                body["reply"]["native_context_transition"] = json!("preserved_refusal");
            }
            return Ok(body);
        }
        let mut first = Vec::new();
        let mut proposal = None;
        if native.reader_route {
            match native
                .runtime
                .conversation_reader_proposal(candidate, text, budget)
            {
                Ok(reader) => {
                    let raw = serde_json::to_string(&reader.language)
                        .map_err(|_| Failure::plain(502, "reader_encoding"))?;
                    first.push(native.reader_candidate(&raw, 0.0));
                    proposal = Some(reader);
                }
                Err(error) => first.push(Candidate::unavailable(
                    "native:reader".into(),
                    0,
                    &error.to_string(),
                    0.0,
                )),
            }
        }
        if let Some(kernels) = &self.kernels {
            first.extend(
                kernels
                    .organs
                    .iter()
                    .map(|organ| kernels.ask(organ, tenant, text, context.clone())),
            );
        }
        check_context(context)?;
        let group: Vec<_> = first.iter().collect();
        let decision =
            front::decide(&group).map_err(|_| Failure::plain(502, "arbitration_error"))?;
        if self.native_conversation_profile {
            return self
                .native_delivery(tenant, text, candidate, budget, first, proposal, decision);
        }
        if !matches!(decision, Decision::NoReading) || self.engine.is_none() {
            let mut projection = json!({"question":text,"acknowledgement":false,"preserve":true});
            let mut projection_supported = false;
            if let Decision::Answered { selected, agreeing } = &decision {
                let selected = group[*selected];
                if let (Some(number), Some(unit)) = (&selected.number, &selected.unit) {
                    let number: Value = wire::parse(number.as_bytes())
                        .map_err(|_| Failure::plain(502, "quantity_projection"))?;
                    let origin = selected
                        .reply
                        .get("numeric_origin")
                        .and_then(Value::as_str)
                        .filter(|origin| {
                            matches!(
                                *origin,
                                "exact_decimal" | "python_float" | "displayed_decimal"
                            )
                        })
                        .or_else(|| {
                            selected
                                .route
                                .starts_with("organ:")
                                .then_some("displayed_decimal")
                        });
                    if let Some(origin) = origin {
                        let value = json!({"number":number,"unit":unit,"origin":origin});
                        projection = json!({"question":text,"result":value,
                            "scalar":if unit.is_empty(){value}else{Value::Null},"subject":null,"answer":null,"topic":null,"acknowledgement":false});
                        projection_supported = true;
                    }
                }
                if agreeing
                    .iter()
                    .any(|index| group[*index].route == "native:reader")
                {
                    if let Some(reader) = proposal.take() {
                        // Only a typed unique-name value establishes an entity.
                        // The operator must separately declare the Wikidata namespace.
                        let mut referent = None;
                        let mut entities = std::collections::BTreeSet::new();
                        let mut numbers = std::collections::BTreeSet::new();
                        for reading in &reader.language.readings {
                            let value = &reading.result.value;
                            if value.is_number() {
                                numbers.insert(value.to_string());
                            }
                            if value["status"] == "unique" {
                                let id = value["candidate"]["id"].as_str().unwrap_or("");
                                let label = value["candidate"]["name"].as_str().unwrap_or("");
                                if self.conversation_wikidata
                                    && id.starts_with('Q')
                                    && id.len() > 1
                                    && id[1..].bytes().all(|b| b.is_ascii_digit())
                                    && !label.is_empty()
                                {
                                    entities.insert((id.to_owned(), label.to_owned()));
                                }
                            }
                        }
                        if numbers.len() == 1
                            && reader
                                .language
                                .readings
                                .iter()
                                .all(|r| r.result.value.is_number())
                        {
                            let number =
                                wire::parse(numbers.iter().next().expect("one number").as_bytes())
                                    .map_err(|_| {
                                        Failure::plain(502, "reader_numeric_projection")
                                    })?;
                            let value = json!({"number":number,"unit":"","origin":"exact_decimal"});
                            projection = json!({"question":text,"subject":null,"answer":null,"topic":null,
                                "result":value,"scalar":value,"acknowledgement":false});
                            projection_supported = true;
                        }
                        if entities.len() == 1 {
                            let (id, label) = entities.into_iter().next().expect("one entity");
                            referent =
                                Some(json!({"id":format!("wd:{id}"),"label":label,"surface":null}));
                        }
                        if let Some(entity) = referent {
                            projection_supported = true;
                            projection = json!({"question":text,"subject":entity,"answer":entity,"topic":entity,
                                "result":null,"scalar":null,"acknowledgement":false});
                        }
                        candidate
                            .apply_reader(reader)
                            .map_err(crate::native::conversation_failure)?;
                    }
                }
            }
            let mut result = json!({"outcome":"completed","reply":front::reply(&decision,&group,&first,
                if matches!(decision,Decision::NoReading){None}else{Some(0)})});
            if let Some(origin) = projection.pointer("/result/origin") {
                result["reply"]["numeric_origin"] = origin.clone();
            }
            if let Some(engine) = &self.engine {
                if matches!(decision, Decision::Answered { .. }) && !projection_supported {
                    return Err(Failure::plain(409, "conversation_projection_unsupported"));
                }
                if !candidate.starts_new_session() && candidate.envelope.oracle.is_none() {
                    return Err(reset_required());
                }
                let committed = serde_json::to_value(&candidate.envelope)
                    .map_err(|_| Failure::plain(502, "state_encoding"))?;
                let delivered =
                    json!({"reply":result["reply"],"conversation_projection":projection});
                let engine_session = format!(
                    "h{}",
                    &config::sha256_bytes(
                        format!("oracle-host-v1\0session\0{tenant}\0{conversation}").as_bytes()
                    )[..40]
                );
                self.journal.dispatch(
                    tenant,
                    request["request_id"].as_str().unwrap_or(""),
                    conversation,
                )?;
                *dispatched = true;
                let (capture, worker, generation) = engine
                    .project_conversation_with_context(
                        tenant,
                        &engine_session,
                        None,
                        &committed,
                        &delivered,
                        context,
                    )
                    .map_err(|(_, place)| {
                        if place.is_none() {
                            *dispatched = false;
                        }
                        *binding = place;
                        Failure::plain(503, "conversation_projection_unavailable")
                    })?;
                *binding = Some((worker, generation));
                Self::install_capture(candidate, &capture)?;
            }
            return Ok(result);
        }
        let engine = self.engine.as_ref().expect("engine");
        // A native-only retained envelope is explicitly uncovered for Python.
        // First-turn initialization is admitted; continuation needs a snapshot.
        if !candidate.starts_new_session() && candidate.envelope.oracle.is_none() {
            return Err(reset_required());
        }
        let committed = serde_json::to_value(&candidate.envelope)
            .map_err(|_| Failure::plain(502, "state_encoding"))?;
        let engine_session = format!(
            "h{}",
            &config::sha256_bytes(
                format!("oracle-host-v1\0session\0{tenant}\0{conversation}").as_bytes()
            )[..40]
        );
        self.journal.dispatch(
            tenant,
            request["request_id"].as_str().unwrap_or(""),
            conversation,
        )?;
        *dispatched = true;
        let started = Instant::now();
        let (reply, worker, generation) = engine
            .ask_conversation_with_context(tenant, text, &engine_session, None, &committed, context)
            .map_err(|(error, place)| {
                if place.is_none() {
                    *dispatched = false;
                }
                if let Some(place) = place {
                    *binding = Some(place);
                }
                let (status, code) = match error {
                    EngineError::Busy => (429, "busy"),
                    EngineError::Timeout => (504, "query_timeout"),
                    _ => (503, "engine_conversation_unavailable"),
                };
                Failure::plain(status, code)
            })?;
        *binding = Some((worker, generation));
        first.push(engine.candidate(&reply, started.elapsed().as_secs_f64() * 1000.0));
        let group: Vec<_> = first.iter().filter(|c| c.group == 1).collect();
        let decision =
            front::decide(&group).map_err(|_| Failure::plain(502, "arbitration_error"))?;
        // Capture is the adapter's finalized delivered transition, including
        // semantic refusals; speculative group zero never consumed Python state.
        Self::install_capture(candidate, &reply)?;
        Ok(json!({"outcome":"completed","reply":front::reply(&decision,&group,&first,Some(1))}))
    }
}

#[cfg(test)]
#[path = "conversation_host_tests.rs"]
mod conversation_host_tests;

impl Service {
    fn native_delivery(
        &self,
        tenant: &str,
        text: &str,
        candidate: &mut ConversationCandidate,
        budget: &core::Budget,
        first: Vec<Candidate>,
        mut proposal: Option<core::conversation::ConversationReaderProposal>,
        decision: Decision,
    ) -> Result<Value, Failure> {
        use core::native_conversation::{NativeQuantity, ProviderIdentity, ProviderQuantityAnchor};
        let native = self.native.as_ref().expect("native profile");
        if matches!(decision, Decision::NoReading) {
            return self.native_fallback(tenant, text, candidate, budget);
        }
        let group: Vec<_> = first.iter().collect();
        let mut delivered = false;
        if let Decision::Answered { selected, agreeing } = &decision {
            if agreeing
                .iter()
                .any(|index| group[*index].route == "native:reader")
            {
                if let Some(reader) = proposal.take() {
                    let entity = reader.agreed_entity_id().map(str::to_owned);
                    let count = reader.agreed_count();
                    let identity =
                        ProviderIdentity::from_host_delivery("native_reader", &native.image_sha256)
                            .map_err(crate::native::conversation_failure)?;
                    if let Some(id) = entity {
                        candidate
                            .apply_reader(reader)
                            .map_err(crate::native::conversation_failure)?;
                        native
                            .runtime
                            .conversation_deliver_entity(candidate, &id, identity, budget)
                            .map_err(crate::native::conversation_failure)?;
                        delivered = true;
                    } else if let Some(count) = count {
                        let quantity = NativeQuantity {
                            number: count.to_string(),
                            unit: "1".into(),
                            origin: core::session::NumericOrigin::ExactDecimal,
                            role: core::native_conversation::QuantityRole::Scalar,
                        };
                        let anchor = ProviderQuantityAnchor::from_host_delivery(identity, quantity)
                            .map_err(crate::native::conversation_failure)?;
                        native
                            .runtime
                            .conversation_deliver_quantity(candidate, anchor, budget)
                            .map_err(crate::native::conversation_failure)?;
                        delivered = true;
                    }
                }
            } else {
                let selected = group[*selected];
                // Structured numeric/unit fields from the admitted extracted
                // protocol, never a number inferred from displayed answer text.
                if let (Some(number), Some(unit), Some(id)) = (
                    &selected.number,
                    &selected.unit,
                    selected.route.strip_prefix("organ:"),
                ) {
                    let admission = self
                        .kernels
                        .as_ref()
                        .and_then(|kernels| {
                            kernels
                                .executor
                                .admissions()
                                .into_iter()
                                .find(|row| row.id == id)
                        })
                        .ok_or_else(|| Failure::plain(503, "native_provider_identity_missing"))?;
                    let identity = ProviderIdentity::from_host_delivery(
                        &format!("organ.{id}"),
                        &admission.executable_sha256,
                    )
                    .map_err(crate::native::conversation_failure)?;
                    let quantity = NativeQuantity {
                        number: number.clone(),
                        unit: unit.clone(),
                        origin: core::session::NumericOrigin::DisplayedDecimal,
                        role: core::native_conversation::QuantityRole::Scalar,
                    };
                    let anchor = ProviderQuantityAnchor::from_host_delivery(identity, quantity)
                        .map_err(crate::native::conversation_failure)?;
                    native
                        .runtime
                        .conversation_deliver_quantity(candidate, anchor, budget)
                        .map_err(crate::native::conversation_failure)?;
                    delivered = true;
                }
            }
            if !delivered {
                // A new delivered answer replaces what “that” denotes. If its
                // typed result has no admitted anchor representation, clear the
                // old anchor and selection rather than reusing a stale answer.
                native
                    .runtime
                    .conversation_native_command(
                        candidate,
                        core::native_conversation::NativeContextCommand::ResetTopic,
                        budget,
                    )
                    .map_err(crate::native::conversation_failure)?;
            }
            native
                .runtime
                .conversation_native_reconcile_selection(candidate, budget)
                .map_err(crate::native::conversation_failure)?;
        }
        let mut reply = front::reply(&decision, &group, &first, Some(0));
        reply["native_context_transition"] = json!(if delivered {
            "delivered_typed_anchor"
        } else if matches!(decision, Decision::Answered { .. }) {
            "cleared_unrepresentable_answer"
        } else {
            "preserved_refusal"
        });
        Ok(json!({"outcome":"completed","reply":reply}))
    }

    fn native_command_reply(
        &self,
        candidate: &mut ConversationCandidate,
        command: core::native_conversation::NativeContextCommand,
        budget: &core::Budget,
    ) -> Result<Value, Failure> {
        use core::native_conversation::{NativeAnchor, NativeContextStatus};
        let reply = self
            .native
            .as_ref()
            .expect("native profile")
            .runtime
            .conversation_native_command(candidate, command, budget)
            .map_err(crate::native::conversation_failure)?;
        let answered = matches!(reply.status, NativeContextStatus::Answered);
        let response = if !answered {
            "This request needs a compatible retained native quantity.".into()
        } else {
            match &reply.anchor {
                NativeAnchor::Quantity { value } => format!(
                    "{}{}{}",
                    value.number,
                    if value.unit.is_empty() { "" } else { " " },
                    value.unit
                ),
                NativeAnchor::Entity { id } => format!("Retained native entity {id}."),
                NativeAnchor::Empty => "No native entity or quantity is retained.".into(),
            }
        };
        Ok(
            json!({"outcome":"completed","reply":{"status":if answered{"answered"}else{"withheld"},"response":response,
            "path":"native:context","provenance":{"scope":"finite native conversation owner","native_context":reply}}}),
        )
    }

    fn native_fallback(
        &self,
        tenant: &str,
        text: &str,
        candidate: &mut ConversationCandidate,
        budget: &core::Budget,
    ) -> Result<Value, Failure> {
        use core::native_conversation::NativeContextCommand as Command;
        let normalized = text
            .trim()
            .trim_end_matches(['.', '?', '!'])
            .to_ascii_lowercase();
        let command = match normalized.as_str() {
            "thanks" | "thank you" | "ok" | "okay" | "got it" => Some(Command::Acknowledge),
            "new topic" | "reset topic" | "forget that" => Some(Command::ResetTopic),
            "what was that" | "what is the current quantity" => Some(Command::Inspect),
            _ => None,
        };
        if let Some(command) = command {
            return self.native_command_reply(candidate, command, budget);
        }
        const NUMBER_PATTERN: &str = r"([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)";
        static NUMBER: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
        static COST: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
        for (prefix, divide) in [
            ("that times ", false),
            ("multiply that by ", false),
            ("that divided by ", true),
            ("divide that by ", true),
        ] {
            if let Some(value) = normalized.strip_prefix(prefix) {
                if NUMBER
                    .get_or_init(|| {
                        regex::Regex::new(&format!("^{NUMBER_PATTERN}$"))
                            .expect("constant native number grammar")
                    })
                    .is_match(value)
                {
                    return self.native_command_reply(
                        candidate,
                        if divide {
                            Command::Divide {
                                divisor: value.into(),
                            }
                        } else {
                            Command::Scale {
                                factor: value.into(),
                            }
                        },
                        budget,
                    );
                }
            }
        }
        for prefix in ["evaluate that model at ", "predict with that model at "] {
            if let Some(value) = normalized.strip_prefix(prefix) {
                if NUMBER
                    .get_or_init(|| {
                        regex::Regex::new(&format!("^{NUMBER_PATTERN}$"))
                            .expect("constant native number grammar")
                    })
                    .is_match(value)
                {
                    return self.native_command_reply(
                        candidate,
                        Command::EvaluateModel {
                            value: value.into(),
                        },
                        budget,
                    );
                }
            }
        }
        let trimmed = text.trim().trim_end_matches(['.', '?', '!']);
        if trimmed
            .to_ascii_lowercase()
            .starts_with("convert that temperature to ")
        {
            let target_unit = trimmed["convert that temperature to ".len()..].trim();
            if matches!(target_unit, "K" | "degC" | "C" | "degF" | "F") {
                return self.native_command_reply(
                    candidate,
                    Command::ConvertTemperature {
                        target_unit: target_unit.into(),
                    },
                    budget,
                );
            }
        }
        static SHIFT_TEMP: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
        static DIFF_TEMP: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
        if let Some(capture) = SHIFT_TEMP
            .get_or_init(|| {
                regex::Regex::new(&format!(
                    r"^(?i:shift that temperature by) {NUMBER_PATTERN} (K|degC|C|degF|F)$"
                ))
                .expect("constant shift temp grammar")
            })
            .captures(trimmed)
        {
            return self.native_command_reply(
                candidate,
                Command::ShiftTemperature {
                    delta: capture[1].into(),
                    delta_unit: capture[2].into(),
                },
                budget,
            );
        }
        if let Some(capture) = DIFF_TEMP
            .get_or_init(|| {
                regex::Regex::new(&format!(
                    r"^(?i:temperature difference from) {NUMBER_PATTERN} (K|degC|C|degF|F)$"
                ))
                .expect("constant diff temp grammar")
            })
            .captures(trimmed)
        {
            return self.native_command_reply(
                candidate,
                Command::TemperatureDifferenceFrom {
                    baseline: capture[1].into(),
                    baseline_unit: capture[2].into(),
                },
                budget,
            );
        }
        let cost = COST.get_or_init(|| {
            regex::Regex::new(&format!(
                r"^(?i:what does that cost at) \$?{NUMBER_PATTERN} (?i:per) (J|kWh)$"
            ))
            .expect("constant native cost grammar")
        });
        if let Some(capture) = cost.captures(trimmed) {
            let unit = &capture[2];
            return self.native_command_reply(
                candidate,
                Command::Cost {
                    rate: capture[1].into(),
                    per_unit: unit.into(),
                },
                budget,
            );
        }
        let entity_query = if normalized == "what is the birthplace of that entity" {
            Some(core::NativeEntityQuery::Relation {
                predicate: "place of birth".into(),
            })
        } else {
            let lower = trimmed.to_ascii_lowercase();
            if lower.starts_with("select entity id ") || lower.starts_with("find entity id ") {
                let prefix_len = if lower.starts_with("select entity id ") {
                    "select entity id ".len()
                } else {
                    "find entity id ".len()
                };
                let id = trimmed[prefix_len..].trim();
                (!id.is_empty() && id.len() <= 256)
                    .then(|| core::NativeEntityQuery::ById { id: id.into() })
            } else if lower.starts_with("find entity ") {
                let name = trimmed["find entity ".len()..].trim();
                (!name.is_empty() && name.len() <= 512)
                    .then(|| core::NativeEntityQuery::Find { name: name.into() })
            } else {
                None
            }
        };
        if let Some(query) = entity_query {
            let native = self.native.as_ref().expect("native profile");
            let reply = native
                .runtime
                .conversation_native_entity_query(candidate, query, budget)
                .map_err(crate::native::conversation_failure)?;
            let answered = matches!(
                reply.status,
                core::native_conversation::NativeContextStatus::Answered
            );
            let response = reply
                .entity
                .as_ref()
                .map(|entity| entity.label.clone())
                .unwrap_or_else(|| {
                    "The admitted native snapshot has no unique entity answer for this request."
                        .into()
                });
            return Ok(
                json!({"outcome":"completed","reply":{"status":if answered{"answered"}else{"withheld"},"response":response,
                "path":"native:context>source_entity","provenance":{"scope":"admitted native image snapshot","image_sha256":native.image_sha256,
                    "source_entity":reply.entity,"native_context":reply.context,"evidence":reply.evidence}}}),
            );
        }
        let _ = tenant;
        Ok(
            json!({"outcome":"completed","reply":{"status":"withheld","response":"No admitted native route reads this request; the prior native context is preserved.","path":"native:context>unsupported","provenance":{"scope":"native image and finite native commands"}}}),
        )
    }
}

#[cfg(test)]
#[path = "modeling_tests.rs"]
mod modeling_tests;
