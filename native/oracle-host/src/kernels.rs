//! Resident extracted organs behind `KernelExecutor`, with each specialist's
//! own acceptance rule applied before arbitration (as `exam.Loaded.reply`).

use crate::config::{self, err, ConfigError, KernelsConfig, OrganConfig};
use crate::front::{Candidate, Offer};
use oracle_runtime_core::{
    self as core, KernelDescriptor, KernelExecutor, KernelFamily, KernelLimits,
};
use regex::Regex;
use serde_json::{json, Value};
use std::sync::Arc;
use std::time::Instant;

pub struct Organ {
    pub id: String,
    kinds: Vec<String>,
    declines: Vec<String>,
    context: Option<Regex>,
}

pub struct Kernels {
    pub executor: Arc<KernelExecutor>,
    pub organs: Vec<Organ>,
}

impl Kernels {
    pub fn open(settings: &KernelsConfig) -> Result<Self, ConfigError> {
        let limits: KernelLimits = if settings.limits.is_null() {
            KernelLimits::default()
        } else {
            serde_json::from_value(settings.limits.clone())
                .map_err(|e| err(format!("kernels.limits: {e}")))?
        };
        let mut descriptors = Vec::new();
        let mut organs = Vec::new();
        for organ in &settings.organs {
            let OrganConfig {
                id,
                executable,
                sha256,
                family,
                accept,
            } = organ;
            config::absolute("kernels.organs.executable", executable)?;
            if !config::is_hash(sha256) {
                return Err(err(format!(
                    "kernels.organs[{id}]: sha256 must be 64 lowercase hex"
                )));
            }
            let family: KernelFamily = serde_json::from_value(family.clone())
                .map_err(|e| err(format!("kernels.organs[{id}].family: {e}")))?;
            if family == KernelFamily::MstCertificate {
                return Err(err(format!(
                    "kernels.organs[{id}]: a certificate checker is not a question answerer"
                )));
            }
            let context = match &accept.context_regex {
                Some(source) if !source.is_empty() => {
                    Some(Regex::new(&format!("(?i){source}")).map_err(|e| {
                        err(format!("kernels.organs[{id}].accept.context_regex: {e}"))
                    })?)
                }
                _ => None,
            };
            descriptors.push(KernelDescriptor::new(
                id.clone(),
                executable.clone(),
                sha256.clone(),
                family,
            ));
            organs.push(Organ {
                id: id.clone(),
                kinds: accept.kinds.clone(),
                declines: accept.declines_in_domain.clone(),
                context,
            });
        }
        // Admission copies and re-hashes each executable; a mismatch fails startup.
        let executor =
            KernelExecutor::new(descriptors, limits).map_err(|e| err(format!("kernels: {e}")))?;
        Ok(Self {
            executor: Arc::new(executor),
            organs,
        })
    }

    pub fn admissions(&self) -> Value {
        serde_json::to_value(self.executor.admissions()).unwrap_or(Value::Null)
    }

    /// Ask one organ. Not recognized, or recognized with a kind its manifest
    /// does not accept, is `NoReading`: the organ did not take the turn.
    pub fn ask(
        &self,
        organ: &Organ,
        tenant: &str,
        question: &str,
        context: oracle_execution::ExecutionContext,
    ) -> Candidate {
        let route = format!("organ:{}", organ.id);
        let started = Instant::now();
        let budget = core::Budget::from_execution_context(context);
        let result = self
            .executor
            .execute_with_budget(tenant, &organ.id, question, &budget);
        let ms = started.elapsed().as_secs_f64() * 1000.0;
        let reply = match result {
            Ok(reply) => reply.reply,
            Err(error) => return Candidate::unavailable(route, 0, &error.to_string(), ms),
        };
        let taken = reply.pointer("/provenance/taken") != Some(&Value::Bool(false));
        let kind = reply.get("kind").and_then(Value::as_str).unwrap_or("");
        let accepted = taken
            && (organ.kinds.iter().any(|k| k == kind)
                || (organ.declines.iter().any(|k| k == kind)
                    && organ
                        .context
                        .as_ref()
                        .is_some_and(|re| re.is_match(question))));
        let status = reply
            .get("status")
            .and_then(Value::as_str)
            .unwrap_or("answered")
            .to_owned();
        let offer = if !accepted {
            Offer::NoReading
        } else if status == "answered" {
            Offer::Answer
        } else {
            Offer::Refusal
        };
        let mut candidate = Candidate::from_reply(route, 0, offer, &reply, ms);
        candidate.status = status;
        candidate.detail = json!({"taken": taken, "accepted_kind": accepted});
        candidate
    }
}
