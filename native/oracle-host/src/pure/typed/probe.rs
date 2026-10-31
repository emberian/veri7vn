//! Unit-test-only structural evidence. No production counters or timing hook.
use serde::Serialize;
use std::cell::RefCell;
#[derive(Default, Serialize)]
pub(super) struct Probe {
    pub input_decodes: u64,
    pub provider_envelope_counts: u64,
    pub provider_envelope_bytes: u64,
    pub payload_to_value: u64,
    pub result_redecodes: u64,
    pub checked_reply_serializations: u64,
}
thread_local! {static CURRENT:RefCell<Probe>=RefCell::new(Probe::default());}
pub(super) fn decoded() {
    CURRENT.with(|p| p.borrow_mut().input_decodes += 1);
}
pub(super) fn envelope(bytes: usize) {
    CURRENT.with(|p| {
        let mut p = p.borrow_mut();
        p.provider_envelope_counts += 1;
        p.provider_envelope_bytes += bytes as u64;
    });
}
pub(super) fn serialized() {
    CURRENT.with(|p| p.borrow_mut().checked_reply_serializations += 1);
}
pub(super) fn take() -> Probe {
    CURRENT.with(|p| std::mem::take(&mut *p.borrow_mut()))
}

pub(super) fn redecoded() {
    CURRENT.with(|p| p.borrow_mut().result_redecodes += 1);
}
pub(super) fn materialized() {
    CURRENT.with(|p| p.borrow_mut().payload_to_value += 1);
}
