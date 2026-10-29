use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc,
};
use std::time::{Duration, Instant};

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
            || self.mmap_bytes > i64::MAX as u64
            || self.sessions > i64::MAX as u64
            || self.journal_entries > i64::MAX as u64
        {
            return Err(Error::Invalid("invalid resource limits".into()));
        }
        Ok(())
    }
}

#[derive(Clone, Default)]
pub struct Cancellation(Arc<AtomicBool>);
impl Cancellation {
    pub fn cancel(&self) {
        self.0.store(true, Ordering::Release);
    }
    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }
}

#[derive(Clone)]
pub struct Budget(Arc<BudgetInner>);
struct BudgetInner {
    cancellation: Cancellation,
    deadline: Instant,
    remaining: AtomicU64,
    exhausted: AtomicBool,
}
impl Budget {
    pub fn new(limits: &Limits, cancellation: Cancellation) -> Result<Self> {
        let deadline = Instant::now()
            .checked_add(Duration::from_millis(limits.timeout_ms))
            .ok_or_else(|| Error::Invalid("deadline overflow".into()))?;
        Ok(Self(Arc::new(BudgetInner {
            cancellation,
            deadline,
            remaining: AtomicU64::new(limits.fuel),
            exhausted: AtomicBool::new(false),
        })))
    }
    pub fn check(&self) -> Result<()> {
        if self.0.cancellation.is_cancelled() {
            return Err(Error::Cancelled);
        }
        if Instant::now() >= self.0.deadline {
            return Err(Error::Deadline);
        }
        if self.0.exhausted.load(Ordering::Relaxed) {
            return Err(Error::Limit("fuel"));
        }
        Ok(())
    }
    pub fn spend(&self, amount: u64) -> Result<()> {
        self.check()?;
        let mut remaining = self.0.remaining.load(Ordering::Relaxed);
        loop {
            let Some(next) = remaining.checked_sub(amount) else {
                self.0.exhausted.store(true, Ordering::Relaxed);
                return Err(Error::Limit("fuel"));
            };
            match self.0.remaining.compare_exchange_weak(
                remaining,
                next,
                Ordering::Relaxed,
                Ordering::Relaxed,
            ) {
                Ok(_) => break,
                Err(current) => remaining = current,
            }
        }
        Ok(())
    }
}
