use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, Weak,
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

/// Internal wake registration. Implementations synchronize with their wait
/// predicate before notifying, so cancellation cannot be lost before a wait.
pub(crate) trait CancellationWake: Send + Sync {
    fn wake(&self);
}
#[derive(Default)]
struct CancellationListeners {
    next: u64,
    entries: BTreeMap<u64, Weak<dyn CancellationWake>>,
}
#[derive(Default)]
struct CancellationInner {
    cancelled: AtomicBool,
    listeners: Mutex<CancellationListeners>,
}
#[derive(Clone, Default)]
pub struct Cancellation(Arc<CancellationInner>);
pub(crate) struct CancellationRegistration {
    token: Cancellation,
    id: u64,
    // The registry retains only weak ownership; this guard owns the listener.
    _wake: Arc<dyn CancellationWake>,
}
impl Drop for CancellationRegistration {
    fn drop(&mut self) {
        let mut listeners = self
            .token
            .0
            .listeners
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        listeners.entries.remove(&self.id);
    }
}
impl Cancellation {
    pub fn cancel(&self) {
        if self.0.cancelled.swap(true, Ordering::AcqRel) {
            return;
        }
        // Never invoke a wake while holding the registry lock. Unregistration
        // and listener-specific predicate locks therefore cannot deadlock.
        let listeners: Vec<_> = self
            .0
            .listeners
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .entries
            .values()
            .cloned()
            .collect();
        for listener in listeners {
            if let Some(listener) = listener.upgrade() {
                listener.wake();
            }
        }
    }
    pub fn is_cancelled(&self) -> bool {
        self.0.cancelled.load(Ordering::Acquire)
    }
    fn register(&self, wake: Arc<dyn CancellationWake>) -> Result<CancellationRegistration> {
        let mut listeners = self.0.listeners.lock().map_err(|_| Error::Poisoned)?;
        let id = listeners.next;
        listeners.next = id
            .checked_add(1)
            .ok_or(Error::Limit("cancellation registrations"))?;
        listeners.entries.insert(id, Arc::downgrade(&wake));
        // Registration can race cancellation's snapshot. The caller must check
        // its budget under the predicate lock after registering, before waiting.
        Ok(CancellationRegistration {
            token: self.clone(),
            id,
            _wake: wake,
        })
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
    pub(crate) fn wake_on_cancel(
        &self,
        wake: Arc<dyn CancellationWake>,
    ) -> Result<CancellationRegistration> {
        self.0.cancellation.register(wake)
    }
    pub(crate) fn remaining_time(&self) -> Result<Duration> {
        self.check()?;
        Ok(self.0.deadline.saturating_duration_since(Instant::now()))
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

#[cfg(test)]
mod cancellation_registration_tests {
    use super::*;
    use std::sync::{atomic::AtomicUsize, mpsc};

    struct Counter(Arc<AtomicUsize>);
    impl CancellationWake for Counter {
        fn wake(&self) {
            self.0.fetch_add(1, Ordering::SeqCst);
        }
    }
    struct BlockingWake {
        entered: mpsc::Sender<()>,
        resume: Mutex<mpsc::Receiver<()>>,
    }
    impl CancellationWake for BlockingWake {
        fn wake(&self) {
            self.entered.send(()).unwrap();
            self.resume.lock().unwrap().recv().unwrap();
        }
    }
    #[test]
    fn unregister_and_late_registration_are_safe_during_cancel_snapshot() {
        let token = Cancellation::default();
        let (entered, received) = mpsc::channel();
        let (resume, resumed) = mpsc::channel();
        let first = token
            .register(Arc::new(BlockingWake {
                entered,
                resume: Mutex::new(resumed),
            }))
            .unwrap();
        let calls = Arc::new(AtomicUsize::new(0));
        let second = token.register(Arc::new(Counter(calls.clone()))).unwrap();
        let cancelling = token.clone();
        let thread = std::thread::spawn(move || cancelling.cancel());
        received.recv_timeout(Duration::from_secs(2)).unwrap();
        // The cancellation snapshot already contains the second weak listener.
        // Dropping its owner must allow it to disappear before invocation.
        drop(second);
        let late = token.register(Arc::new(Counter(calls.clone()))).unwrap();
        let budget = Budget::new(&Limits::default(), token.clone()).unwrap();
        assert!(matches!(budget.check(), Err(Error::Cancelled)));
        resume.send(()).unwrap();
        thread.join().unwrap();
        assert_eq!(calls.load(Ordering::SeqCst), 0);
        drop(first);
        drop(late);
        assert!(token.0.listeners.lock().unwrap().entries.is_empty());
        token.cancel();
    }
}
