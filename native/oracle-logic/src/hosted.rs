//! Hosted envelope for the shared native service.
//!
//! The operation ID chooses query or enumeration. The solver executable comes
//! only from operator-owned host JSON, never from the request. Replies carry
//! SHA-256 content identities computed from the validated request, so a later
//! cache or audit replay can key on content rather than the caller's
//! `scope.snapshot` label. `scope.complete_program` stays a caller assertion.
use crate::*;
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::path::PathBuf;

pub const SCHEMA: &str = "oracle-logic-experimental-v1";
pub const QUERY: &str = "logic.query";
pub const ENUMERATE: &str = "logic.enumerate";

/// Operator configuration passed by the host process, not by a tenant.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Host {
    /// Absolute path of an executable whose bytes the host already admitted.
    pub solver: PathBuf,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Envelope {
    operation: String,
    arguments: Map<String, Value>,
}

pub fn operation(id: &str) -> Option<Operation> {
    match id {
        QUERY => Some(Operation::Query),
        ENUMERATE => Some(Operation::Enumerate),
        _ => None,
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

/// SHA-256 of the exact `encode(request)` ASP text. That text is the numeric
/// rule list, so the set of stable models over atom IDs is a function of it.
/// It omits labels, queries, scope and operation.
pub fn program_identity(p: &Request) -> String {
    sha256_hex(encode(p).as_bytes())
}

/// SHA-256 of the compact serde serialization of the validated request in
/// declared field order: operation, scope, labels, rules and queries.
pub fn request_identity(p: &Request) -> Result<String, Error> {
    let text = serde_json::to_string(p).map_err(|_| Error::Backend("request JSON"))?;
    Ok(sha256_hex(text.as_bytes()))
}

/// `{"operation": "logic.query"|"logic.enumerate", "arguments": <program>}`.
/// The program must not name `operation`; any other unknown key, including a
/// solver path or flag, is rejected by the request's strict field list.
pub fn call(
    envelope: &str,
    host: &str,
    limits: &Limits,
    cancel: &dyn WorkControl,
) -> Result<String, Error> {
    let host: Host =
        serde_json::from_str(host).map_err(|_| Error::Backend("host solver configuration"))?;
    if !host.solver.is_absolute() {
        return Err(Error::Backend("host solver path must be absolute"));
    }
    if envelope.len() > limits.request_bytes {
        return Err(Error::Limit("request bytes"));
    }
    let Envelope {
        operation: id,
        mut arguments,
    } = serde_json::from_str(envelope).map_err(|_| Error::Invalid("request JSON"))?;
    let op = operation(&id).ok_or(Error::Invalid("unknown logic operation"))?;
    if arguments.contains_key("operation") {
        return Err(Error::Invalid("operation is chosen by the operation ID"));
    }
    arguments.insert(
        "operation".into(),
        serde_json::to_value(op).map_err(|_| Error::Backend("operation JSON"))?,
    );
    if serde_json::to_vec(&arguments)
        .map_err(|_| Error::Invalid("request JSON"))?
        .len()
        > limits.request_bytes
    {
        return Err(Error::Limit("request bytes"));
    }
    let request: Request = serde_json::from_value(Value::Object(arguments))
        .map_err(|_| Error::Invalid("request JSON"))?;
    // Historical inner-request byte admission remains in addition to envelope admission.
    let reply = execute(&request, &host.solver, limits, cancel)?;
    let value = serde_json::to_value(reply).map_err(|_| Error::Backend("reply JSON"))?;
    serde_json::to_string(&value).map_err(|_| Error::Backend("reply JSON"))
}

#[derive(Serialize)]
pub struct IdentityEncoding {
    program_identity: &'static str,
    request_identity: &'static str,
    complete_program: &'static str,
}
#[derive(Serialize)]
pub struct HostedReply {
    #[serde(flatten)]
    pub result: Reply,
    pub schema: &'static str,
    pub operation_id: &'static str,
    pub program_identity: String,
    pub request_identity: String,
    pub identity_encoding: IdentityEncoding,
}

pub fn execute(
    request: &Request,
    solver: &std::path::Path,
    limits: &Limits,
    control: &dyn WorkControl,
) -> Result<HostedReply, Error> {
    if !solver.is_absolute() {
        return Err(Error::Backend("host solver path must be absolute"));
    }
    // Wire adapters enforce their raw envelope/inner byte ceilings before
    // decoding; typed callers retain the same structural/kernel limits.
    let result = process::execute(request, solver, limits, control)?;
    let reply = HostedReply {
        result,
        schema: SCHEMA,
        operation_id: match request.operation { Operation::Query => QUERY, Operation::Enumerate => ENUMERATE },
        program_identity: program_identity(request),
        request_identity: request_identity(request)?,
        identity_encoding: IdentityEncoding {
            program_identity: "sha256 of encode(request) ASP text over numeric atom IDs; determines the stable-model set",
            request_identity: "sha256 of compact serde JSON of the validated request, including labels, scope and queries",
            complete_program: "caller coverage assertion, not verified",
        },
    };
    if serde_json::to_vec(&reply)
        .map_err(|_| Error::Backend("reply JSON"))?
        .len()
        > limits.output_bytes
    {
        return Err(Error::Limit("reply bytes"));
    }
    Ok(reply)
}

pub fn catalog() -> Value {
    let l = Limits::default();
    json!({
        "schema": SCHEMA,
        "operations": [
            {"id": QUERY, "semantics": "skeptical and credulous answers per query atom; at most 1 + queries solver probes"},
            {"id": ENUMERATE, "semantics": "bounded full enumeration of stable models"}
        ],
        "limits": {
            "request_bytes": l.request_bytes, "atoms": l.atoms, "rules": l.rules,
            "literals": l.literals, "models": l.models, "output_bytes": l.output_bytes,
            "milliseconds": l.milliseconds, "checker_work": l.checker_work
        },
        "solver": "operator-admitted executable; never a request field",
        "witness_check": "handwritten_gl_reduct",
        "absence_claims": "solver_trusted_no_certificate"
    })
}
