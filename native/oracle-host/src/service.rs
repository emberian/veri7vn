//! The host's request semantics, independent of the socket layer: envelope
//! checks, bounded global/tenant admission, discovery, `/invoke` and `/query`.

use crate::admission::{Admission, Permit};
use crate::config::{self, Config, ConfigError, HostLimits};
use crate::engine::{EngineError, EnginePool};
use crate::front::{self, Candidate, Decision};
use crate::journal::{Journal, Lookup};
use crate::kernels::Kernels;
use crate::native::NativeRuntime;
use crate::operations::{valid_operation_id, Registry, Route};
use crate::pure::Pure;
use crate::wire;
use crate::{failure, Failure};
use oracle_execution::{Cancellation, ExecutionContext};
use serde_json::{json, Value};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc};
use std::time::{Duration, Instant};

pub struct Service {
    pub limits: HostLimits,
    pub native: Option<NativeRuntime>,
    pub pure: Option<Pure>,
    pub kernels: Option<Kernels>,
    pub engine: Option<EnginePool>,
    pub registry: Registry,
    journal: Journal,
    admission: Arc<Admission>,
    pub stopping: AtomicBool,
    pub host_sha256: String,
    boot: String,
    providers: Vec<Value>,
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
        let host_sha256 =
            crate::host_binary_sha256().map_err(|e| config::err(format!("host binary: {e}")))?;
        let boot = format!(
            "{:x}{:x}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_or(0, |d| d.as_nanos())
        );
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
                let runtime = NativeRuntime::open(settings, &host_sha256)?;
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
                Some(runtime)
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
                Some(pure)
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
        Ok(Arc::new(Self {
            limits,
            native,
            pure,
            kernels,
            engine,
            registry,
            journal,
            admission,
            stopping: AtomicBool::new(false),
            host_sha256,
            boot,
            providers,
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
        .map_err(|_| Failure::plain(503, "invalid_execution_deadline"))
    }

    fn stateful_operations(&self) -> Vec<&'static str> {
        self.native.as_ref().map_or(vec![], |n| {
            n.operations
                .iter()
                .copied()
                .filter(|op| n.is_stateful(op))
                .collect()
        })
    }

    pub fn routes(&self) -> Vec<String> {
        let mut routes = Vec::new();
        if self.native.as_ref().is_some_and(|n| n.reader_route) {
            routes.push("native:reader".to_owned());
        }
        if let Some(kernels) = &self.kernels {
            routes.extend(kernels.organs.iter().map(|o| format!("organ:{}", o.id)));
        }
        if self.engine.is_some() {
            routes.push("engine".to_owned());
        }
        routes
    }

    pub fn health(&self) -> (u16, Value) {
        let ready = !self.stopping.load(Ordering::Acquire);
        let body = json!({"ready": ready, "backend": "oracle_host", "capacity": self.limits.capacity,
            "busy": self.admission.active(), "tenant_capacity": self.limits.tenant_capacity.unwrap_or(self.limits.capacity),
            "query_queue": 0,
            "durable_replay": true, "query_journal": "exact retained request replay; Engine context is not persisted",
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
            "query": {"routes": self.routes(), "groups": [["native:reader", "organ:*"], ["engine"]],
                "rule": "first depth group whose routes take the question decides; agreement or refusal, never a pick",
                "agreement": {"text": "trimmed lowercase equality", "number": "within 0.5 percent with an identical explicit unit"}},
            "scope": "operator-admitted native operations, resident organs and a contained Engine; host-assigned tenant admission",
            "durable_conversations": !stateful.is_empty(), "durable_replay": true,
            "query_journal": {"durable_replay": true, "engine_context_persisted": false,
                "engine_conversation_recovery": "fresh conversation required after worker loss, eviction, uncertainty or host restart; exact retained requests replay"},
            "durable_operations": stateful,
            "request_id_semantics": "/query: exact retry from the host journal; stateful native turns: exact core reply replay; pure calls: correlation only",
            "tenant_header_authentication": false, "mini_qualified": false, "query_queue": 0,
            "limits": {"request_bytes": self.limits.request_bytes, "reply_bytes": self.limits.reply_bytes,
                       "capacity": self.limits.capacity, "tenant_capacity": self.limits.tenant_capacity.unwrap_or(self.limits.capacity),
                       "invoke_ms": self.limits.invoke_ms, "query_ms": self.limits.query_ms,
                       "execution_fuel": self.limits.execution_fuel},
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

    pub fn invoke(self: &Arc<Self>, tenant: &str, raw: &[u8]) -> (u16, Value) {
        let request = match envelope(raw, "/invoke", self.limits.request_bytes) {
            Ok(r) => r,
            Err(f) => return (f.status, f.body),
        };
        if self.stopping.load(Ordering::Acquire) {
            return (503, failure("service_stopping", json!({})));
        }
        let id = request["operation_id"].as_str().unwrap_or("").to_owned();
        let route = match self.registry.check_arguments(&id, &request["arguments"]) {
            Ok(route) => route,
            Err(f) => return (f.status, f.body),
        };
        let stateful = matches!(route, Route::Runtime)
            && self.native.as_ref().is_some_and(|n| n.is_stateful(&id));
        let Some(permit) = self.acquire(tenant) else {
            return (
                429,
                failure(
                    "pool_busy",
                    json!({"retryable": true, "state_may_have_changed": false,
                                                     "exact_retry_required": false}),
                ),
            );
        };
        let (sender, receiver) = mpsc::channel();
        let context = match self.context(self.limits.invoke_ms) {
            Ok(context) => context,
            Err(f) => return (f.status, f.body),
        };
        let started = Instant::now();
        {
            let service = self.clone();
            let tenant = tenant.to_owned();
            let context = context.clone();
            let id = id.clone();
            if std::thread::Builder::new()
                .name("oracle-invoke".into())
                .spawn(move || {
                    let _permit = permit;
                    let arguments = &request["arguments"];
                    let result = match route {
                        Route::Runtime => service.native.as_ref().expect("runtime route").invoke(
                            &id,
                            arguments,
                            &tenant,
                            request["request_id"].as_str().unwrap_or(""),
                            request["conversation_id"].as_str().unwrap_or(""),
                            context,
                        ),
                        Route::Pure(profile) => service
                            .pure
                            .as_ref()
                            .expect("pure route")
                            .invoke(profile, &id, arguments, &tenant, &context),
                    };
                    let _ = sender.send(result);
                })
                .is_err()
            {
                return (
                    503,
                    failure(
                        "worker_unavailable",
                        json!({"retryable": true,
                    "state_may_have_changed": false, "exact_retry_required": false}),
                    ),
                );
            }
        }
        let result = match receiver
            .recv_timeout(context.deadline().saturating_duration_since(Instant::now()))
        {
            Ok(result) => result,
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                return (
                    502,
                    failure(
                        "runtime_error",
                        json!({"retryable": stateful,
                    "state_may_have_changed": stateful, "exact_retry_required": stateful}),
                    ),
                );
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                // The slot stays held by the worker thread until it returns.
                context.cancellation().cancel();
                return (
                    503,
                    failure(
                        "deadline_exceeded",
                        json!({"retryable": stateful,
                    "state_may_have_changed": stateful, "exact_retry_required": stateful}),
                    ),
                );
            }
        };
        let reply = match result {
            Ok(reply) => reply,
            Err(f) => return (f.status, f.body),
        };
        let body = json!({"outcome": "completed", "operation_id": id, "reply": reply,
            "native_execution": [{"admission": {"host_sha256": self.host_sha256, "route": match route {
                Route::Runtime => "runtime".to_owned(), Route::Pure(p) => p.to_owned() }},
                "containment": {"process": "in_host", "elapsed_ms": started.elapsed().as_millis() as u64}}],
            "durable_replay": stateful});
        if wire::encode(&body).len() > self.limits.reply_bytes {
            return (
                502,
                failure(
                    "reply_too_large",
                    json!({"execution_completed": true,
                "state_may_have_changed": stateful, "retryable": stateful, "exact_retry_required": stateful}),
                ),
            );
        }
        (200, body)
    }

    pub fn query(&self, tenant: &str, raw: &[u8]) -> (u16, Value) {
        let request = match envelope(raw, "/query", self.limits.request_bytes) {
            Ok(r) => r,
            Err(f) => return (f.status, f.body),
        };
        let request_id = request["request_id"].as_str().unwrap_or("");
        match self
            .journal
            .begin(tenant, request_id, raw, self.limits.reply_bytes)
        {
            Ok(Lookup::Replay(status, body)) => return (status, body),
            Ok(Lookup::Fresh) => {}
            Err(f) => return (f.status, f.body),
        }
        let conversation = request["conversation_id"].as_str().unwrap_or("");
        let context = match self.context(self.limits.query_ms) {
            Ok(context) => context,
            Err(f) => {
                if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                    return (e.status, e.body);
                }
                return (f.status, f.body);
            }
        };
        let _lease = match self.journal.lease(tenant, conversation) {
            Ok(lease) => lease,
            Err(f) => {
                if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                    return (e.status, e.body);
                }
                return (f.status, f.body);
            }
        };
        let Some(_permit) = self.acquire(tenant) else {
            if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                return (e.status, e.body);
            }
            return (429, failure("busy", json!({"retryable": true})));
        };
        if self.stopping.load(Ordering::Acquire) {
            if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                return (e.status, e.body);
            }
            return (
                503,
                failure("backend_unavailable", json!({"retryable": false})),
            );
        }
        // A panic after dispatch must not make the request eligible for another
        // opaque execution. This boundary is separate from native core commits.
        let turn = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            self.turn(tenant, &request, &context)
        }))
        .unwrap_or_else(|_| {
            Err(Failure::new(
                502,
                "runtime_error",
                json!({"state_may_have_changed": true, "exact_retry_required": true}),
            ))
        });
        match turn {
            Ok(result) => {
                let result = if wire::encode(&result).len() > self.limits.reply_bytes {
                    failure(
                        "reply_too_large",
                        json!({"execution_completed": true, "state_may_have_changed": true}),
                    )
                } else {
                    result
                };
                if let Err(f) = self
                    .journal
                    .finish(tenant, request_id, conversation, &result)
                {
                    return (f.status, f.body);
                }
                (crate::journal::status_of(&result), result)
            }
            Err(mut f) => {
                if f.body["state_may_have_changed"] == true {
                    f.body["http_status"] = json!(f.status);
                    // Opaque effects cannot be rolled back. Retain their uncertainty.
                    // A failed journal is latched; its pending record survives restart.
                    let _ = self
                        .journal
                        .finish(tenant, request_id, conversation, &f.body);
                } else if let Err(e) = self.journal.forget(tenant, request_id, conversation) {
                    return (e.status, e.body);
                }
                (f.status, f.body)
            }
        }
    }

    /// One front-door turn. Failures explicitly carry opaque-effect uncertainty.
    fn turn(
        &self,
        tenant: &str,
        request: &Value,
        context: &ExecutionContext,
    ) -> Result<Value, Failure> {
        check_context(context)?;
        let text = request["text"].as_str().unwrap_or("");
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
        if let Some(engine) = &self.engine {
            engine.close();
        }
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
