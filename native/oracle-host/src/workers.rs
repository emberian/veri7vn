//! Fixed invocation threads with direct, nonwaiting handoff. An occupied slot
//! includes its assigned job until that job returns: no job waits behind another
//! job. This is immediate backpressure, with no fairness guarantee.
//!
//! The supervisor owns joins; threads own only shared handoff state. Jobs must
//! own provider resources, never the supervisor or a Service containing it.
//! Panicking jobs unwind and disconnect their reply channel; the same worker
//! then accepts new work. Shutdown drains accepted jobs and joins every thread;
//! cooperative native work may delay it until its bounded foreign call returns.
use std::io;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{Arc, Condvar, Mutex};
use std::thread::JoinHandle;

type Job = Box<dyn FnOnce() + Send + 'static>;

#[derive(Default)]
struct Slot {
    occupied: bool,
    job: Option<Job>,
}

struct State {
    closed: bool,
    slots: Vec<Slot>,
}

struct Shared {
    state: Mutex<State>,
    wake: Condvar,
}

pub(crate) struct InvocationWorkers {
    shared: Arc<Shared>,
    // Serialized shutdown is idempotent, and concurrent callers wait for drain.
    joins: Mutex<Vec<JoinHandle<()>>>,
}

impl InvocationWorkers {
    pub(crate) fn new(capacity: usize) -> io::Result<Self> {
        assert!(capacity > 0);
        let pool = Self {
            shared: Arc::new(Shared {
                state: Mutex::new(State {
                    closed: false,
                    slots: (0..capacity).map(|_| Slot::default()).collect(),
                }),
                wake: Condvar::new(),
            }),
            joins: Mutex::new(Vec::with_capacity(capacity)),
        };
        for index in 0..capacity {
            let shared = pool.shared.clone();
            // On a partial startup failure, Drop closes and joins prior threads.
            let join = std::thread::Builder::new()
                .name(format!("oracle-invoke-{index}"))
                .spawn(move || run(shared, index))?;
            pool.joins
                .lock()
                .unwrap_or_else(|p| p.into_inner())
                .push(join);
        }
        Ok(pool)
    }

    /// Refuses immediately if closed or every worker already owns work. A
    /// refused closure is dropped here, releasing any captured admission permit.
    pub(crate) fn try_submit(&self, job: impl FnOnce() + Send + 'static) -> bool {
        let mut state = self.shared.state.lock().unwrap_or_else(|p| p.into_inner());
        if state.closed {
            return false;
        }
        let Some(slot) = state.slots.iter_mut().find(|slot| !slot.occupied) else {
            return false;
        };
        slot.occupied = true;
        slot.job = Some(Box::new(job));
        self.shared.wake.notify_all();
        true
    }

    pub(crate) fn shutdown(&self) {
        let mut joins = self.joins.lock().unwrap_or_else(|p| p.into_inner());
        {
            let mut state = self.shared.state.lock().unwrap_or_else(|p| p.into_inner());
            state.closed = true;
            self.shared.wake.notify_all();
        }
        for join in joins.drain(..) {
            // Job panics are caught in run; an infrastructure panic retires the
            // thread, with no unbounded replacement loop or new work accepted.
            let _ = join.join();
        }
    }
}

impl Drop for InvocationWorkers {
    fn drop(&mut self) {
        self.shutdown();
    }
}

fn run(shared: Arc<Shared>, index: usize) {
    loop {
        let job = {
            let mut state = shared.state.lock().unwrap_or_else(|p| p.into_inner());
            loop {
                if let Some(job) = state.slots[index].job.take() {
                    break job;
                }
                if state.closed {
                    return;
                }
                state = shared.wake.wait(state).unwrap_or_else(|p| p.into_inner());
            }
        };
        // Includes captured resources' destruction on normal return or unwind.
        let _ = catch_unwind(AssertUnwindSafe(job));
        let mut state = shared.state.lock().unwrap_or_else(|p| p.into_inner());
        state.slots[index].occupied = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::admission::Admission;
    use std::sync::mpsc;
    use std::time::Duration;

    // Wait for the actual handoff state, not merely a job's last notification.
    fn idle(pool: &InvocationWorkers) {
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        while pool
            .shared
            .state
            .lock()
            .unwrap()
            .slots
            .iter()
            .any(|s| s.occupied)
        {
            assert!(
                std::time::Instant::now() < deadline,
                "worker did not become idle"
            );
            std::thread::yield_now();
        }
    }

    #[test]
    fn reuses_fixed_threads_and_refuses_waiting_work() {
        let pool = InvocationWorkers::new(2).unwrap();
        let (entered, seen) = mpsc::channel();
        let (release_a, wait_a) = mpsc::channel();
        let (release_b, wait_b) = mpsc::channel();
        for wait in [wait_a, wait_b] {
            let entered = entered.clone();
            assert!(pool.try_submit(move || {
                entered.send(std::thread::current().id()).unwrap();
                wait.recv_timeout(Duration::from_secs(5)).unwrap();
            }));
        }
        let ids = [
            seen.recv_timeout(Duration::from_secs(5)).unwrap(),
            seen.recv_timeout(Duration::from_secs(5)).unwrap(),
        ];
        assert_ne!(ids[0], ids[1]);
        assert!(!pool.try_submit(|| panic!("saturated job must never run")));
        release_a.send(()).unwrap();
        release_b.send(()).unwrap();
        idle(&pool);
        for _ in 0..8 {
            let entered = entered.clone();
            assert!(pool.try_submit(move || entered.send(std::thread::current().id()).unwrap()));
            assert!(ids.contains(&seen.recv_timeout(Duration::from_secs(5)).unwrap()));
            idle(&pool);
        }
    }

    #[test]
    fn timeout_holds_global_and_tenant_capacity_until_work_stops() {
        let pool = InvocationWorkers::new(2).unwrap();
        let admission = Admission::new(2, 1);
        let permit = admission.acquire("a").unwrap();
        let context = oracle_execution::ExecutionContext::new(
            100,
            Duration::from_secs(10),
            oracle_execution::Cancellation::default(),
        )
        .unwrap();
        let worker_context = context.clone();
        let (observed, cancellation_seen) = mpsc::channel();
        let (release, wait) = mpsc::channel();
        let (reply, client) = mpsc::channel();
        assert!(pool.try_submit(move || {
            let _permit = permit;
            wait.recv_timeout(Duration::from_secs(5)).unwrap();
            observed.send(worker_context.check().is_err()).unwrap();
            let _ = reply.send(());
        }));
        assert!(matches!(
            client.recv_timeout(Duration::from_millis(1)),
            Err(mpsc::RecvTimeoutError::Timeout)
        ));
        drop(client);
        context.cancellation().cancel();
        assert!(admission.acquire("a").is_none());
        let b = admission.acquire("b").unwrap();
        assert!(admission.acquire("c").is_none());
        release.send(()).unwrap();
        assert!(cancellation_seen
            .recv_timeout(Duration::from_secs(5))
            .unwrap());
        idle(&pool);
        assert!(admission.acquire("a").is_some());
        drop(b);
        assert_eq!(admission.active(), 0);
    }

    #[test]
    fn panic_disconnects_result_releases_permit_and_reuses_worker() {
        let pool = InvocationWorkers::new(1).unwrap();
        let admission = Admission::new(1, 1);
        let permit = admission.acquire("a").unwrap();
        let (reply, client) = mpsc::channel::<()>();
        assert!(pool.try_submit(move || {
            let (_permit, _reply) = (permit, reply);
            panic!("provider panic");
        }));
        assert!(matches!(
            client.recv_timeout(Duration::from_secs(5)),
            Err(mpsc::RecvTimeoutError::Disconnected)
        ));
        idle(&pool);
        assert_eq!(admission.active(), 0);
        let (reply, client) = mpsc::channel();
        assert!(pool.try_submit(move || reply.send(42).unwrap()));
        assert_eq!(client.recv_timeout(Duration::from_secs(5)).unwrap(), 42);
    }

    #[test]
    fn shutdown_drains_accepted_work_and_refuses_new_work() {
        let pool = Arc::new(InvocationWorkers::new(1).unwrap());
        let (release, wait) = mpsc::channel();
        let (done, drained) = mpsc::channel();
        assert!(pool.try_submit(move || {
            wait.recv_timeout(Duration::from_secs(5)).unwrap();
            done.send(()).unwrap();
        }));
        let supervisor = pool.clone();
        let (closed, joined) = mpsc::channel();
        let shutdown = std::thread::spawn(move || {
            supervisor.shutdown();
            closed.send(()).unwrap();
        });
        while !pool.shared.state.lock().unwrap().closed {
            std::thread::yield_now();
        }
        assert!(!pool.try_submit(|| panic!("closed job")));
        assert!(matches!(joined.try_recv(), Err(mpsc::TryRecvError::Empty)));
        release.send(()).unwrap();
        drained.recv_timeout(Duration::from_secs(5)).unwrap();
        joined.recv_timeout(Duration::from_secs(5)).unwrap();
        shutdown.join().unwrap();
        pool.shutdown();
    }
}
