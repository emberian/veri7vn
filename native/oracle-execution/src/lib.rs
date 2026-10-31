//! Dependency-free cooperative execution primitives shared by native providers.
//! Explicit retained native bytes have a shared reservation ledger. Allocator,
//! foreign buffers, output and semantic caps remain the caller’s responsibility;
//! fuel only accounts explicitly charged work.
#![forbid(unsafe_code)]

mod memory;
pub use memory::{MemoryBudget, MemoryError, MemoryReservation, MemorySnapshot};

use std::collections::BTreeMap;
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, Weak,
};
use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ExecutionError {
    Cancelled,
    Deadline,
    FuelExhausted,
    DeadlineOverflow,
    Poisoned,
    RegistrationLimit,
}
impl std::fmt::Display for ExecutionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Cancelled => "cancelled",
            Self::Deadline => "deadline exceeded",
            Self::FuelExhausted => "fuel exhausted",
            Self::DeadlineOverflow => "deadline overflow",
            Self::Poisoned => "execution synchronization poisoned",
            Self::RegistrationLimit => "cancellation registrations exhausted",
        })
    }
}
impl std::error::Error for ExecutionError {}
pub type Result<T> = std::result::Result<T, ExecutionError>;

/// Cooperative cancellation wake registration. Implementations synchronize with their wait
/// predicate before notifying, so cancellation cannot be lost before a wait.
pub trait CancellationWake: Send + Sync {
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
/// Owns a wake listener until dropped. Dropping unregisters it, but a wake that
/// has already upgraded its weak reference may still finish afterwards.
#[must_use = "dropping the registration unregisters its wake listener"]
pub struct CancellationRegistration {
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
    /// Register before checking the cancellation predicate under its wait lock.
    /// Registration after cancellation does not itself invoke the wake callback.
    /// The caller must check after registering and before every wait; the wake
    /// implementation must synchronize with that same predicate lock.
    pub fn register(&self, wake: Arc<dyn CancellationWake>) -> Result<CancellationRegistration> {
        let mut listeners = self
            .0
            .listeners
            .lock()
            .map_err(|_| ExecutionError::Poisoned)?;
        let id = listeners.next;
        listeners.next = id.checked_add(1).ok_or(ExecutionError::RegistrationLimit)?;
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

/// Shared cooperative work budget. Clones share fuel, cancellation and the
/// original absolute deadline. Checks do not preempt foreign or uncooperative
/// code: a worker remains occupied until that code actually returns.
#[derive(Clone)]
pub struct ExecutionContext(Arc<ExecutionInner>);
struct ExecutionInner {
    parent: Option<ExecutionContext>,
    memory: MemoryBudget,
    cancellation: Cancellation,
    deadline: Instant,
    remaining: AtomicU64,
    exhausted: AtomicBool,
}
impl ExecutionContext {
    /// Begin one top-level operation. Nested work must borrow or clone this
    /// context so it cannot acquire another timeout or fuel allowance.
    pub fn new(fuel: u64, timeout: Duration, cancellation: Cancellation) -> Result<Self> {
        let deadline = Instant::now()
            .checked_add(timeout)
            .ok_or(ExecutionError::DeadlineOverflow)?;
        Ok(Self::with_deadline(fuel, deadline, cancellation))
    }
    /// Begin an operation with an already established absolute deadline.
    /// This creates a fresh fuel allowance; use `clone` for nested work.
    pub fn with_deadline(fuel: u64, deadline: Instant, cancellation: Cancellation) -> Self {
        Self(Arc::new(ExecutionInner {
            parent: None,
            memory: MemoryBudget::new(usize::MAX),
            cancellation,
            deadline,
            remaining: AtomicU64::new(fuel),
            exhausted: AtomicBool::new(false),
        }))
    }
    /// Add stricter local bounds while retaining the parent's aggregate charge.
    /// Clones share both allowances. A failed local charge can consume parent
    /// fuel conservatively; it never refunds work or creates a fresh allowance.
    pub fn restricted(&self, fuel: u64, timeout: Duration) -> Result<Self> {
        let local_deadline = Instant::now()
            .checked_add(timeout)
            .ok_or(ExecutionError::DeadlineOverflow)?;
        Ok(Self(Arc::new(ExecutionInner {
            parent: Some(self.clone()),
            memory: self.0.memory.clone(),
            cancellation: self.0.cancellation.clone(),
            deadline: self.deadline().min(local_deadline),
            remaining: AtomicU64::new(fuel),
            exhausted: AtomicBool::new(false),
        })))
    }
    /// Shared explicit retained-byte ledger. Legacy constructors start without a
    /// finite memory ceiling; request admission installs one via restriction.
    pub fn memory(&self) -> &MemoryBudget {
        &self.0.memory
    }
    /// Add a local retained-byte ceiling without changing fuel/deadline identity.
    pub fn restricted_memory(&self, limit: usize) -> Self {
        Self(Arc::new(ExecutionInner {
            parent: Some(self.clone()),
            memory: self.0.memory.restricted(limit),
            cancellation: self.0.cancellation.clone(),
            deadline: self.deadline(),
            remaining: AtomicU64::new(u64::MAX),
            exhausted: AtomicBool::new(false),
        }))
    }
    pub fn deadline(&self) -> Instant {
        self.0.deadline
    }
    pub fn cancellation(&self) -> &Cancellation {
        &self.0.cancellation
    }
    pub fn check(&self) -> Result<()> {
        if let Some(parent) = &self.0.parent {
            parent.check()?;
        }
        if self.0.cancellation.is_cancelled() {
            return Err(ExecutionError::Cancelled);
        }
        if Instant::now() >= self.0.deadline {
            return Err(ExecutionError::Deadline);
        }
        if self.0.exhausted.load(Ordering::Relaxed) {
            return Err(ExecutionError::FuelExhausted);
        }
        Ok(())
    }
    /// See [`Cancellation::register`] for the required wait-predicate protocol.
    pub fn wake_on_cancel(
        &self,
        wake: Arc<dyn CancellationWake>,
    ) -> Result<CancellationRegistration> {
        self.0.cancellation.register(wake)
    }
    pub fn remaining_time(&self) -> Result<Duration> {
        self.check()?;
        Ok(self.0.deadline.saturating_duration_since(Instant::now()))
    }
    pub fn spend(&self, amount: u64) -> Result<()> {
        self.check()?;
        if let Some(parent) = &self.0.parent {
            parent.spend(amount)?;
        }
        let mut remaining = self.0.remaining.load(Ordering::Relaxed);
        loop {
            let Some(next) = remaining.checked_sub(amount) else {
                self.0.exhausted.store(true, Ordering::Relaxed);
                return Err(ExecutionError::FuelExhausted);
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

/// A cooperative checkpoint for kernels shared by legacy cancellation-only
/// callers and fully budgeted operations. `work` is explicit charged work,
/// including verification; it does not measure wall time or allocated bytes.
pub trait WorkControl: Send + Sync {
    fn checkpoint(&self, work: u64) -> Result<()>;
}
/// Preserve shared ownership at legacy and budgeted provider boundaries.
/// Delegation observes the original control state without copying or resetting it.
impl<T: WorkControl + ?Sized> WorkControl for Arc<T> {
    fn checkpoint(&self, work: u64) -> Result<()> {
        self.as_ref().checkpoint(work)
    }
}
impl WorkControl for ExecutionContext {
    fn checkpoint(&self, work: u64) -> Result<()> {
        self.spend(work)
    }
}
/// Compatibility for existing provider callers. This checks cancellation only;
/// it has no fuel or deadline allowance and therefore ignores the work count.
impl WorkControl for AtomicBool {
    fn checkpoint(&self, _work: u64) -> Result<()> {
        if self.load(Ordering::Acquire) {
            Err(ExecutionError::Cancelled)
        } else {
            Ok(())
        }
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
    struct WaitWake {
        predicate: Mutex<()>,
        ready: std::sync::Condvar,
    }
    impl CancellationWake for WaitWake {
        fn wake(&self) {
            let _predicate = self.predicate.lock().unwrap();
            self.ready.notify_all();
        }
    }

    #[test]
    fn cancelling_between_predicate_check_and_wait_cannot_lose_wake() {
        let token = Cancellation::default();
        let context = ExecutionContext::new(1, Duration::from_secs(60), token.clone()).unwrap();
        let wake = Arc::new(WaitWake {
            predicate: Mutex::new(()),
            ready: std::sync::Condvar::new(),
        });
        let registration = context.wake_on_cancel(wake.clone()).unwrap();
        let (checked, checked_rx) = mpsc::channel();
        let waiting = std::thread::spawn(move || {
            let predicate = wake.predicate.lock().unwrap();
            context.check().unwrap();
            checked.send(()).unwrap();
            // The cancelling thread may now set the flag, but the wake must
            // acquire the predicate lock released atomically by this wait.
            let (_predicate, timeout) = wake
                .ready
                .wait_timeout_while(predicate, Duration::from_secs(2), |_| {
                    context.check().is_ok()
                })
                .unwrap();
            assert!(!timeout.timed_out());
            assert_eq!(context.check(), Err(ExecutionError::Cancelled));
            drop(registration);
        });
        checked_rx.recv_timeout(Duration::from_secs(2)).unwrap();
        token.cancel();
        waiting.join().unwrap();
        assert!(token.0.listeners.lock().unwrap().entries.is_empty());
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
        let budget = ExecutionContext::new(10, Duration::from_secs(60), token.clone()).unwrap();
        assert!(matches!(budget.check(), Err(ExecutionError::Cancelled)));
        resume.send(()).unwrap();
        thread.join().unwrap();
        assert_eq!(calls.load(Ordering::SeqCst), 0);
        drop(first);
        drop(late);
        assert!(token.0.listeners.lock().unwrap().entries.is_empty());
        token.cancel();
    }
}

#[cfg(test)]
mod execution_contract_tests {
    use super::*;
    use std::sync::Barrier;

    fn context(fuel: u64) -> ExecutionContext {
        ExecutionContext::new(fuel, Duration::from_secs(60), Cancellation::default()).unwrap()
    }

    #[test]
    fn nested_work_and_replay_share_sticky_fuel() {
        let parent = context(10);
        let child = parent.clone();
        parent.spend(4).unwrap();
        child.spend(6).unwrap();
        // Exactly consuming the allowance still permits a final status check.
        parent.check().unwrap();
        assert_eq!(child.spend(1), Err(ExecutionError::FuelExhausted));
        assert_eq!(parent.spend(0), Err(ExecutionError::FuelExhausted));
        assert_eq!(parent.clone().check(), Err(ExecutionError::FuelExhausted));
    }

    #[test]
    fn failed_large_charge_cannot_be_retried_as_small_charge() {
        let parent = context(10);
        assert_eq!(parent.clone().spend(11), Err(ExecutionError::FuelExhausted));
        assert_eq!(parent.spend(1), Err(ExecutionError::FuelExhausted));
    }

    #[test]
    fn concurrent_children_cannot_multiply_allowance() {
        let parent = context(100);
        let start = Arc::new(Barrier::new(5));
        let workers: Vec<_> = (0..4)
            .map(|_| {
                let child = parent.clone();
                let start = start.clone();
                std::thread::spawn(move || {
                    start.wait();
                    let mut successes = 0;
                    while child.spend(1).is_ok() {
                        successes += 1;
                    }
                    successes
                })
            })
            .collect();
        start.wait();
        let total: u64 = workers
            .into_iter()
            .map(|worker| worker.join().unwrap())
            .sum();
        assert_eq!(total, 100);
        assert_eq!(parent.check(), Err(ExecutionError::FuelExhausted));
    }

    #[test]
    fn absolute_deadline_is_inherited_without_extension() {
        let deadline = Instant::now();
        let parent = ExecutionContext::with_deadline(10, deadline, Cancellation::default());
        let child = parent.clone();
        assert_eq!(child.deadline(), deadline);
        assert_eq!(child.check(), Err(ExecutionError::Deadline));
        assert_eq!(child.remaining_time(), Err(ExecutionError::Deadline));
        assert_eq!(child.spend(0), Err(ExecutionError::Deadline));
    }

    #[test]
    fn cancellation_is_shared_and_has_existing_error_precedence() {
        let parent = ExecutionContext::with_deadline(0, Instant::now(), Cancellation::default());
        let child = parent.clone();
        child.cancellation().cancel();
        assert_eq!(parent.check(), Err(ExecutionError::Cancelled));
    }

    #[test]
    fn shared_control_charges_work_and_legacy_control_only_checks_cancellation() {
        let context = context(2);
        let control: &dyn WorkControl = &context;
        control.checkpoint(2).unwrap();
        assert_eq!(control.checkpoint(1), Err(ExecutionError::FuelExhausted));
        let legacy = AtomicBool::new(false);
        let control: &dyn WorkControl = &legacy;
        control.checkpoint(u64::MAX).unwrap();
        legacy.store(true, Ordering::Release);
        assert_eq!(control.checkpoint(0), Err(ExecutionError::Cancelled));
    }
}

#[cfg(test)]
mod restricted_context_tests {
    use super::*;
    #[test]
    fn local_cap_is_sticky_and_failed_charge_does_not_refund_parent() {
        let parent =
            ExecutionContext::new(10, Duration::from_secs(60), Cancellation::default()).unwrap();
        let child = parent.restricted(2, Duration::from_secs(60)).unwrap();
        child.spend(2).unwrap();
        assert_eq!(child.clone().spend(1), Err(ExecutionError::FuelExhausted));
        assert_eq!(child.spend(0), Err(ExecutionError::FuelExhausted));
        parent.spend(7).unwrap();
        assert_eq!(parent.spend(1), Err(ExecutionError::FuelExhausted));
    }
    #[test]
    fn sibling_scopes_cannot_refresh_aggregate_fuel_or_deadline() {
        let parent =
            ExecutionContext::new(3, Duration::from_secs(60), Cancellation::default()).unwrap();
        let a = parent.restricted(100, Duration::from_secs(120)).unwrap();
        let b = parent.restricted(100, Duration::from_secs(120)).unwrap();
        assert_eq!(a.deadline(), parent.deadline());
        assert_eq!(b.deadline(), parent.deadline());
        a.spend(2).unwrap();
        b.spend(1).unwrap();
        assert_eq!(a.spend(1), Err(ExecutionError::FuelExhausted));
        assert_eq!(b.check(), Err(ExecutionError::FuelExhausted));
    }
    #[test]
    fn tighter_local_deadline_does_not_expire_parent_or_extend_on_clone() {
        let parent =
            ExecutionContext::new(3, Duration::from_secs(60), Cancellation::default()).unwrap();
        let child = parent.restricted(3, Duration::ZERO).unwrap();
        assert_eq!(child.clone().check(), Err(ExecutionError::Deadline));
        parent.check().unwrap();
        assert!(child.deadline() < parent.deadline());
    }
}

#[cfg(test)]
mod shared_control_tests {
    use super::*;
    #[test]
    fn arc_atomic_control_observes_original_cancellation() {
        let cancellation = Arc::new(AtomicBool::new(false));
        let shared = cancellation.clone();
        let control: &dyn WorkControl = &shared;
        control.checkpoint(1).unwrap();
        cancellation.store(true, Ordering::Release);
        assert_eq!(control.checkpoint(1), Err(ExecutionError::Cancelled));
    }
    #[test]
    fn arc_context_control_charges_original_allowance() {
        let context =
            ExecutionContext::new(2, Duration::from_secs(60), Cancellation::default()).unwrap();
        let shared = Arc::new(context.clone());
        let control: &dyn WorkControl = &shared;
        control.checkpoint(1).unwrap();
        context.spend(1).unwrap();
        assert_eq!(control.checkpoint(1), Err(ExecutionError::FuelExhausted));
        assert_eq!(context.check(), Err(ExecutionError::FuelExhausted));
    }
    #[test]
    fn arc_dynamic_control_delegates_without_sized_requirement() {
        let cancellation = Arc::new(AtomicBool::new(true));
        let shared: Arc<dyn WorkControl> = cancellation;
        let control: &dyn WorkControl = &shared;
        assert_eq!(control.checkpoint(0), Err(ExecutionError::Cancelled));
    }
}
