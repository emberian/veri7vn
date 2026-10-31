use crate::{Error, Result};
pub use oracle_execution::Cancellation;
pub(crate) use oracle_execution::{CancellationRegistration, CancellationWake};
use oracle_execution::{ExecutionContext, ExecutionError};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;

/// Operator bounds, independent of tenant entitlement. No silent truncation.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct Limits {
    pub workers: usize,
    pub request_bytes: usize,
    pub result_bytes: usize,
    pub state_bytes: usize,
    pub plan_nodes: usize,
    pub materialized_rows: usize,
    pub materialized_bytes: usize,
    pub fuel: u64,
    pub timeout_ms: u64,
    pub sqlite_cache_kib: u32,
    pub mmap_bytes: u64,
    pub sessions: u64,
    pub journal_entries: u64,
    /// Permanent namespace tombstones; exhaustion refuses further retirement.
    pub retired_namespaces: u64,
}

impl Default for Limits {
    fn default() -> Self {
        Self {
            workers: 2,
            request_bytes: 65536,
            result_bytes: 2 * 1024 * 1024,
            state_bytes: 256 * 1024,
            plan_nodes: 128,
            materialized_rows: 100_000,
            materialized_bytes: 16 * 1024 * 1024,
            fuel: 10_000_000,
            timeout_ms: 5000,
            sqlite_cache_kib: 2048,
            mmap_bytes: 256 * 1024 * 1024,
            sessions: 100_000,
            journal_entries: 1_000_000,
            retired_namespaces: 65_536,
        }
    }
}

impl Limits {
    pub fn validate(&self) -> Result<()> {
        if self.workers == 0
            || self.request_bytes == 0
            || self.result_bytes == 0
            || self.state_bytes == 0
            || self.plan_nodes == 0
            || self.materialized_rows == 0
            || self.materialized_bytes == 0
            || self.fuel == 0
            || self.timeout_ms == 0
            || self.sqlite_cache_kib == 0
            || self.sessions == 0
            || self.journal_entries == 0
            || self.retired_namespaces == 0
            || self.mmap_bytes > i64::MAX as u64
            || self.sessions > i64::MAX as u64
            || self.journal_entries > i64::MAX as u64
            || self.retired_namespaces > i64::MAX as u64
        {
            return Err(Error::Invalid("invalid resource limits".into()));
        }
        Ok(())
    }
}

/// Compatibility facade over the shared provider execution context.
#[derive(Clone)]
pub struct Budget(ExecutionContext);
impl Budget {
    pub fn new(limits: &Limits, cancellation: Cancellation) -> Result<Self> {
        ExecutionContext::new(
            limits.fuel,
            Duration::from_millis(limits.timeout_ms),
            cancellation,
        )
        .map(Self)
        .map_err(execution_error)
    }
    /// Adopt the existing operation's deadline and fuel, without resetting either.
    pub fn from_execution_context(context: ExecutionContext) -> Self {
        Self(context)
    }
    /// Preserve the enclosing budget while enforcing this consumer's local caps.
    pub fn restricted_to(&self, limits: &Limits) -> Result<Self> {
        self.0
            .restricted(limits.fuel, Duration::from_millis(limits.timeout_ms))
            .map(Self)
            .map_err(execution_error)
    }
    pub fn execution_context(&self) -> &ExecutionContext {
        &self.0
    }
    pub fn check(&self) -> Result<()> {
        self.0.check().map_err(execution_error)
    }
    pub fn spend(&self, amount: u64) -> Result<()> {
        self.0.spend(amount).map_err(execution_error)
    }
    pub(crate) fn wake_on_cancel(
        &self,
        wake: Arc<dyn CancellationWake>,
    ) -> Result<CancellationRegistration> {
        self.0.wake_on_cancel(wake).map_err(execution_error)
    }
    pub(crate) fn remaining_time(&self) -> Result<Duration> {
        self.0.remaining_time().map_err(execution_error)
    }
}
fn execution_error(error: ExecutionError) -> Error {
    match error {
        ExecutionError::Cancelled => Error::Cancelled,
        ExecutionError::Deadline => Error::Deadline,
        ExecutionError::FuelExhausted => Error::Limit("fuel"),
        ExecutionError::DeadlineOverflow => Error::Invalid("deadline overflow".into()),
        ExecutionError::Poisoned => Error::Poisoned,
        ExecutionError::RegistrationLimit => Error::Limit("cancellation registrations"),
    }
}

#[cfg(test)]
mod budget_facade_tests {
    use super::*;
    use std::time::Instant;

    #[test]
    fn provider_and_core_share_one_allowance() {
        let context =
            ExecutionContext::new(3, Duration::from_secs(60), Cancellation::default()).unwrap();
        let core = Budget::from_execution_context(context.clone());
        core.spend(2).unwrap();
        context.spend(1).unwrap();
        assert!(matches!(core.spend(1), Err(Error::Limit("fuel"))));
        assert_eq!(context.check(), Err(ExecutionError::FuelExhausted));
        assert!(matches!(core.clone().check(), Err(Error::Limit("fuel"))));
    }

    #[test]
    fn adopting_context_preserves_expired_deadline_and_cancellation() {
        let cancellation = Cancellation::default();
        let context = ExecutionContext::with_deadline(10, Instant::now(), cancellation.clone());
        let core = Budget::from_execution_context(context);
        assert!(matches!(core.check(), Err(Error::Deadline)));
        cancellation.cancel();
        assert!(matches!(core.check(), Err(Error::Cancelled)));
    }

    #[test]
    fn old_constructor_exposes_shared_context_without_new_allowance() {
        let limits = Limits {
            fuel: 1,
            ..Limits::default()
        };
        let core = Budget::new(&limits, Cancellation::default()).unwrap();
        core.execution_context().spend(1).unwrap();
        assert!(matches!(core.spend(1), Err(Error::Limit("fuel"))));
    }
}
