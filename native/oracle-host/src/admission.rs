//! Bounded, immediate admission across tenants. There is no waiting queue and
//! no strict fairness guarantee. Only tenants with live work occupy this map.
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

pub struct Admission {
    capacity: usize,
    tenant_capacity: usize,
    state: Mutex<State>,
}

#[derive(Default)]
struct State {
    active: usize,
    tenants: BTreeMap<String, usize>,
}

/// Held by the work, not its waiting HTTP client. Dropping a timed-out receiver
/// cannot release capacity while the worker can still access provider state.
pub struct Permit {
    admission: Arc<Admission>,
    tenant: String,
}

impl Admission {
    pub fn new(capacity: usize, tenant_capacity: usize) -> Arc<Self> {
        assert!(capacity > 0 && tenant_capacity > 0 && tenant_capacity <= capacity);
        Arc::new(Self {
            capacity,
            tenant_capacity,
            state: Mutex::new(State::default()),
        })
    }

    pub fn acquire(self: &Arc<Self>, tenant: &str) -> Option<Permit> {
        // HTTP tenants are SHA-256 keys; also bound allocations for direct users.
        if tenant.is_empty() || tenant.len() > 64 {
            return None;
        }
        let mut state = self.state.lock().unwrap_or_else(|p| p.into_inner());
        if state.active >= self.capacity
            || state.tenants.get(tenant).copied().unwrap_or(0) >= self.tenant_capacity
        {
            return None;
        }
        state.active += 1;
        *state.tenants.entry(tenant.to_owned()).or_default() += 1;
        Some(Permit {
            admission: self.clone(),
            tenant: tenant.to_owned(),
        })
    }

    pub fn active(&self) -> usize {
        self.state.lock().unwrap_or_else(|p| p.into_inner()).active
    }
}

impl Drop for Permit {
    fn drop(&mut self) {
        let mut state = self
            .admission
            .state
            .lock()
            .unwrap_or_else(|p| p.into_inner());
        state.active -= 1;
        let count = state
            .tenants
            .get_mut(&self.tenant)
            .expect("live permit tenant");
        *count -= 1;
        if *count == 0 {
            state.tenants.remove(&self.tenant);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc;
    use std::time::Duration;

    #[test]
    fn tenant_saturation_leaves_room_for_other_tenants_and_reclaims_entries() {
        let admission = Admission::new(3, 2);
        let a = admission.acquire("a").unwrap();
        let a2 = admission.acquire("a").unwrap();
        assert!(admission.acquire("a").is_none());
        let b = admission.acquire("b").unwrap();
        assert!(admission.acquire("c").is_none());
        drop(a);
        let c = admission.acquire("c").unwrap();
        drop((a2, b, c));
        assert_eq!(admission.active(), 0);
        assert!(admission.state.lock().unwrap().tenants.is_empty());
        for n in 0..1000 {
            drop(admission.acquire(&format!("tenant-{n}")).unwrap());
        }
        assert!(admission.state.lock().unwrap().tenants.is_empty());
    }

    #[test]
    fn concurrent_admission_never_oversubscribes_one_tenant() {
        let admission = Admission::new(4, 3);
        let acquired = Arc::new(std::sync::Barrier::new(17));
        let release = Arc::new(std::sync::Barrier::new(17));
        let workers: Vec<_> = (0..16)
            .map(|_| {
                let admission = admission.clone();
                let acquired = acquired.clone();
                let release = release.clone();
                std::thread::spawn(move || {
                    let permit = admission.acquire("a");
                    acquired.wait();
                    release.wait();
                    drop(permit);
                })
            })
            .collect();
        acquired.wait();
        assert_eq!(admission.active(), 3);
        let other = admission.acquire("b").unwrap();
        assert_eq!(admission.active(), 4);
        release.wait();
        for worker in workers {
            worker.join().unwrap();
        }
        drop(other);
        assert_eq!(admission.active(), 0);
    }

    #[test]
    fn timed_out_receiver_does_not_release_running_work() {
        let admission = Admission::new(2, 1);
        let permit = admission.acquire("a").unwrap();
        let context = oracle_execution::ExecutionContext::new(
            100,
            Duration::from_secs(10),
            oracle_execution::Cancellation::default(),
        )
        .unwrap();
        let worker_context = context.clone();
        let (release, wait) = mpsc::channel();
        let (result, receiver) = mpsc::channel();
        let worker = std::thread::spawn(move || {
            let _permit = permit;
            wait.recv().unwrap();
            assert!(worker_context.check().is_err());
            let _ = result.send(());
        });
        assert!(receiver.recv_timeout(Duration::from_millis(1)).is_err());
        drop(receiver);
        context.cancellation().cancel();
        assert!(admission.acquire("a").is_none());
        let b = admission.acquire("b").unwrap();
        release.send(()).unwrap();
        worker.join().unwrap();
        assert!(admission.acquire("a").is_some());
        drop(b);
        assert_eq!(admission.active(), 0);
    }
}
