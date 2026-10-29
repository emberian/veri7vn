//! Optional stable-model provider. Not a release-admitted Mini tool.
//!
//! `host_json` is operator configuration supplied by the host worker (the
//! admitted solver path); the request cannot name an executable or flags.
//! The host pool cancels by killing the worker's process group, which also
//! holds any solver child; in-call cancellation is the provider's deadline.
use crate::NativeRequestError;
use pyo3::{exceptions::PyValueError, prelude::*};
use std::sync::atomic::AtomicBool;

#[pyfunction]
fn logic_call(py: Python<'_>, request: &str, host_json: &str) -> PyResult<String> {
    py.detach(|| {
        oracle_logic::hosted::call(
            request,
            host_json,
            &oracle_logic::Limits::default(),
            &AtomicBool::new(false),
        )
    })
    .map_err(|e| match e {
        oracle_logic::Error::Invalid(_) => {
            NativeRequestError::new_err(("invalid_input", e.to_string()))
        }
        oracle_logic::Error::Limit(_) => {
            NativeRequestError::new_err(("resource_limit", e.to_string()))
        }
        _ => PyValueError::new_err(e.to_string()),
    })
}

#[pyfunction]
fn logic_catalog() -> String {
    oracle_logic::hosted::catalog().to_string()
}

pub(crate) fn register(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_function(wrap_pyfunction!(logic_call, module)?)?;
    module.add_function(wrap_pyfunction!(logic_catalog, module)?)?;
    Ok(())
}
