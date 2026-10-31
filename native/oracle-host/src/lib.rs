//! Loopback appliance host. One Rust process owns the HTTP boundary, the
//! shared native image, resident extracted organs and a contained pool of
//! Python Engine children, and answers questions only by agreement or refusal.
//!
//! This is untrusted transport and orchestration code. It establishes no
//! theorem and no Mini qualification; the tenant header is routing metadata,
//! not authentication. See `native/docs/HOST.md`.
#![forbid(unsafe_code)]

pub mod admission;
pub mod config;
pub mod engine;
pub mod front;
pub mod http;
pub mod journal;
pub mod kernels;
pub mod native;
pub mod operations;
pub mod pure;
pub mod schema;
pub mod service;
pub mod wire;
mod workers;

use serde_json::{json, Map, Value};

/// An HTTP status with the reference service's `{"outcome":"error",...}` body.
#[derive(Debug, Clone)]
pub struct Failure {
    pub status: u16,
    pub body: Value,
}

pub fn failure(code: &str, fields: Value) -> Value {
    let mut body = Map::new();
    body.insert("outcome".into(), json!("error"));
    body.insert("error".into(), json!(code));
    if let Value::Object(extra) = fields {
        body.extend(extra);
    }
    Value::Object(body)
}

impl Failure {
    pub fn new(status: u16, code: &str, fields: Value) -> Self {
        Self {
            status,
            body: failure(code, fields),
        }
    }
    pub fn plain(status: u16, code: &str) -> Self {
        Self::new(status, code, json!({}))
    }
}

/// The measured bytes of this running host binary. Release manifests bind it.
pub fn host_binary_sha256() -> std::io::Result<String> {
    config::sha256_file(&std::env::current_exe()?)
}

/// Compiled-in pure provider profiles, in the order the reference service lists them.
#[allow(clippy::vec_init_then_push)] // each push is feature-gated
pub fn compiled_profiles() -> Vec<&'static str> {
    #[allow(unused_mut)]
    let mut profiles = Vec::new();
    #[cfg(feature = "reasoning")]
    profiles.push("reasoning");
    #[cfg(feature = "science")]
    profiles.push("science");
    #[cfg(feature = "incremental")]
    profiles.push("incremental");
    #[cfg(feature = "bio")]
    profiles.push("bio");
    #[cfg(feature = "statistics")]
    profiles.push("statistics");
    #[cfg(feature = "logic")]
    profiles.push("logic");
    profiles
}
#[cfg(feature = "logic")]
pub mod revisions_owner;
