//! Explicit retained native byte accounting, not allocator, RSS or SQLite tracking.
//! Callers reserve before retaining buffers and attach the guard to their owner.
use std::sync::{Arc, Mutex};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MemoryError {
    Limit,
    Overflow,
}
impl std::fmt::Display for MemoryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Limit => "retained memory limit",
            Self::Overflow => "retained memory accounting overflow",
        })
    }
}
impl std::error::Error for MemoryError {}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct MemorySnapshot {
    pub limit: usize,
    pub live: usize,
    pub peak: usize,
}
struct Scope {
    parent: Option<Arc<Scope>>,
    stats: Mutex<MemorySnapshot>,
}
/// Clones share one scope; restricted scopes also charge every ancestor.
/// Each scope owns only its parent, so completed child scopes are reclaimed as
/// soon as their last budget/reservation owner disappears. The shared gate makes
/// validation, updates and snapshots one transaction across the ancestry.
#[derive(Clone)]
pub struct MemoryBudget {
    gate: Arc<Mutex<()>>,
    scope: Arc<Scope>,
}
impl MemoryBudget {
    pub fn new(limit: usize) -> Self {
        Self {
            gate: Arc::new(Mutex::new(())),
            scope: Arc::new(Scope {
                parent: None,
                stats: Mutex::new(MemorySnapshot {
                    limit,
                    live: 0,
                    peak: 0,
                }),
            }),
        }
    }
    pub fn restricted(&self, limit: usize) -> Self {
        Self {
            gate: self.gate.clone(),
            scope: Arc::new(Scope {
                parent: Some(self.scope.clone()),
                stats: Mutex::new(MemorySnapshot {
                    limit,
                    live: 0,
                    peak: 0,
                }),
            }),
        }
    }
    pub fn snapshot(&self) -> MemorySnapshot {
        let _transaction = self.gate.lock().unwrap_or_else(|e| e.into_inner());
        *self.scope.stats.lock().unwrap_or_else(|e| e.into_inner())
    }
    pub fn reserve(&self, bytes: usize) -> Result<MemoryReservation, MemoryError> {
        self.change(0, bytes)?;
        Ok(MemoryReservation {
            budget: self.clone(),
            bytes,
        })
    }
    fn change(&self, old: usize, new: usize) -> Result<(), MemoryError> {
        let _transaction = self.gate.lock().unwrap_or_else(|e| e.into_inner());
        // Individual stats locks never escape the transaction. No user code is
        // called under either lock. Validate every ancestor before any update.
        let mut cursor = Some(self.scope.as_ref());
        while let Some(scope) = cursor {
            let stats = scope.stats.lock().unwrap_or_else(|e| e.into_inner());
            let live = (stats.live - old)
                .checked_add(new)
                .ok_or(MemoryError::Overflow)?;
            if live > stats.limit {
                return Err(MemoryError::Limit);
            }
            cursor = scope.parent.as_deref();
        }
        let mut cursor = Some(self.scope.as_ref());
        while let Some(scope) = cursor {
            let mut stats = scope.stats.lock().unwrap_or_else(|e| e.into_inner());
            stats.live = stats.live - old + new;
            stats.peak = stats.peak.max(stats.live);
            cursor = scope.parent.as_deref();
        }
        Ok(())
    }
}
/// One retained allocation/accounting owner. Share this guard with `Arc` alongside
/// the data; cloning the Arc does not charge again. Resize before growing data.
/// Cancellation never refunds live buffers early: drop does, including unwind.
#[must_use = "retain the reservation for the entire retained data lifetime"]
pub struct MemoryReservation {
    budget: MemoryBudget,
    bytes: usize,
}
impl MemoryReservation {
    pub fn bytes(&self) -> usize {
        self.bytes
    }
    /// Failed growth leaves the previous reservation intact. Shrinking is always
    /// possible even after cancellation/deadline/fuel exhaustion.
    pub fn resize(&mut self, bytes: usize) -> Result<(), MemoryError> {
        self.budget.change(self.bytes, bytes)?;
        self.bytes = bytes;
        Ok(())
    }
}
impl Drop for MemoryReservation {
    fn drop(&mut self) {
        let _ = self.budget.change(self.bytes, 0);
    }
}
impl std::fmt::Debug for MemoryReservation {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("MemoryReservation")
            .field("bytes", &self.bytes)
            .finish()
    }
}

#[cfg(test)]
mod memory_tests {
    use super::*;
    #[test]
    fn dropped_scope_churn_reclaims_metadata_and_reservations_keep_ancestors() {
        let root = MemoryBudget::new(10);
        for _ in 0..10_000 {
            let child = root.restricted(5);
            let grandchild = child.restricted(5);
            let child_weak = Arc::downgrade(&child.scope);
            let grandchild_weak = Arc::downgrade(&grandchild.scope);
            let retained = grandchild.reserve(1).unwrap();
            drop(child);
            drop(grandchild);
            assert!(child_weak.upgrade().is_some());
            assert!(grandchild_weak.upgrade().is_some());
            assert_eq!(root.snapshot().live, 1);
            drop(retained);
            assert!(child_weak.upgrade().is_none());
            assert!(grandchild_weak.upgrade().is_none());
            assert_eq!(Arc::strong_count(&root.scope), 1);
            assert_eq!(Arc::strong_count(&root.gate), 1);
        }
        assert_eq!(root.snapshot().live, 0);
        assert_eq!(root.snapshot().peak, 1);
    }

    #[test]
    fn shared_lifetime_resize_failure_and_unwind() {
        let memory = MemoryBudget::new(10);
        let mut reservation = memory.reserve(6).unwrap();
        assert_eq!(reservation.resize(11), Err(MemoryError::Limit));
        assert_eq!(reservation.bytes(), 6);
        reservation.resize(8).unwrap();
        reservation.resize(4).unwrap();
        let shared = Arc::new(reservation);
        let other = shared.clone();
        drop(shared);
        assert_eq!(
            memory.snapshot(),
            MemorySnapshot {
                limit: 10,
                live: 4,
                peak: 8
            }
        );
        let _ = std::panic::catch_unwind(|| {
            let _guard = other;
            panic!("owned work failed");
        });
        assert_eq!(memory.snapshot().live, 0);
    }
    #[test]
    fn children_are_atomic_and_cannot_replenish_parent() {
        let parent = MemoryBudget::new(10);
        let a = parent.restricted(3);
        let b = parent.restricted(100);
        assert!(matches!(a.reserve(4), Err(MemoryError::Limit)));
        assert_eq!(parent.snapshot().peak, 0);
        let _a = a.reserve(3).unwrap();
        let _b = b.reserve(7).unwrap();
        assert!(matches!(b.clone().reserve(1), Err(MemoryError::Limit)));
        assert_eq!(parent.snapshot().live, 10);
    }
    #[test]
    fn ancestor_resize_failure_preserves_every_balance_and_peak() {
        let parent = MemoryBudget::new(10);
        let child = parent.restricted(20);
        let sibling = parent.restricted(20);
        let mut retained = child.reserve(2).unwrap();
        let other = sibling.reserve(7).unwrap();
        let before_parent = parent.snapshot();
        let before_child = child.snapshot();
        assert_eq!(retained.resize(4), Err(MemoryError::Limit));
        assert_eq!(retained.bytes(), 2);
        assert_eq!(parent.snapshot(), before_parent);
        assert_eq!(child.snapshot(), before_child);
        drop(other);
        retained.resize(10).unwrap();
        assert_eq!(parent.snapshot().live, 10);
        drop(retained);
        assert_eq!(parent.snapshot().live, 0);
        assert_eq!(child.snapshot().live, 0);
        assert_eq!(sibling.snapshot().live, 0);
    }

    #[test]
    fn arithmetic_overflow_cannot_wrap_allowance() {
        let memory = MemoryBudget::new(usize::MAX);
        let mut reservation = memory.reserve(usize::MAX).unwrap();
        assert!(matches!(memory.reserve(1), Err(MemoryError::Overflow)));
        reservation.resize(0).unwrap();
        assert_eq!(memory.snapshot().live, 0);
        assert_eq!(memory.snapshot().peak, usize::MAX);
    }
    #[test]
    fn concurrent_scopes_share_one_live_ceiling() {
        let memory = MemoryBudget::new(7);
        let start = Arc::new(std::sync::Barrier::new(17));
        let held = Arc::new(std::sync::Barrier::new(17));
        let workers: Vec<_> = (0..16)
            .map(|_| {
                let child = memory.restricted(7);
                let start = start.clone();
                let held = held.clone();
                std::thread::spawn(move || {
                    start.wait();
                    let reservation = child.reserve(1).ok();
                    held.wait();
                    reservation
                })
            })
            .collect();
        start.wait();
        held.wait();
        let guards: Vec<_> = workers
            .into_iter()
            .filter_map(|w| w.join().unwrap())
            .collect();
        assert_eq!(guards.len(), 7);
        assert_eq!(memory.snapshot().live, 7);
        drop(guards);
        assert_eq!(memory.snapshot().live, 0);
    }
}
