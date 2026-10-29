//! Optional experimental pure operations. They are not release-admitted Mini tools.
use pyo3::{exceptions::PyValueError, prelude::*};

#[pyfunction]
fn reasoning_call(py: Python<'_>, request: &str) -> PyResult<String> {
    py.detach(|| oracle_reasoning::call(request, &oracle_reasoning::Limits::default()))
        .map_err(|e| PyValueError::new_err(e.to_string()))
}

#[pyfunction]
fn reasoning_catalog() -> String {
    oracle_reasoning::catalog().to_string()
}

pub(crate) fn register(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_function(wrap_pyfunction!(reasoning_call, module)?)?;
    module.add_function(wrap_pyfunction!(reasoning_catalog, module)?)?;
    Ok(())
}
