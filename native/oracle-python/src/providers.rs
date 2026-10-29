//! Explicit optional providers; not enabled in the admitted-runtime registry.
use pyo3::prelude::*;

// Only explicitly classified admission failures use this boundary. An ordinary
// ValueError, numerical failure, cancellation or candidate-check error does not
// promise that a hosting process can safely remain resident.
#[cfg(any(feature = "bio", feature = "statistics"))]
pyo3::create_exception!(
    oracle_native,
    NativeRequestError,
    pyo3::exceptions::PyValueError
);

#[cfg(feature = "bio")]
#[pyfunction]
fn bio_call(py: Python<'_>, request: &str) -> PyResult<String> {
    py.detach(|| {
        oracle_bio::call(
            request,
            &oracle_bio::Limits::default(),
            &std::sync::atomic::AtomicBool::new(false),
        )
    })
    .map_err(|e| match e {
        oracle_bio::Error::Invalid(_) | oracle_bio::Error::Limit(_) => {
            NativeRequestError::new_err((e.code(), e.to_string()))
        }
        _ => pyo3::exceptions::PyValueError::new_err(e.to_string()),
    })
}
#[cfg(feature = "bio")]
#[pyfunction]
fn bio_catalog() -> String {
    oracle_bio::catalog().to_string()
}

#[cfg(feature = "statistics")]
#[pyfunction]
fn statistics_call(py: Python<'_>, request: &str) -> PyResult<String> {
    py.detach(|| {
        oracle_statistics::call(
            request,
            &oracle_statistics::Limits::default(),
            &std::sync::atomic::AtomicBool::new(false),
        )
    })
    .map_err(|e| match e {
        oracle_statistics::Error::Invalid(_) | oracle_statistics::Error::Limit(_) => {
            NativeRequestError::new_err((e.code(), e.to_string()))
        }
        _ => pyo3::exceptions::PyValueError::new_err(e.to_string()),
    })
}
#[cfg(feature = "statistics")]
#[pyfunction]
fn statistics_catalog() -> String {
    oracle_statistics::catalog().to_string()
}

#[cfg(feature = "science")]
#[pyfunction]
fn science_call(py: Python<'_>, request: &str) -> PyResult<String> {
    py.detach(|| {
        oracle_science::call(
            request,
            &oracle_science::Limits::default(),
            &std::sync::atomic::AtomicBool::new(false),
        )
    })
    .map_err(|e| pyo3::exceptions::PyValueError::new_err(e.to_string()))
}
#[cfg(feature = "science")]
#[pyfunction]
fn science_catalog() -> String {
    oracle_science::catalog().to_string()
}

#[cfg(feature = "incremental")]
#[pyfunction]
fn incremental_call(py: Python<'_>, request: &str) -> String {
    py.detach(|| oracle_incremental::call_json(request))
}
#[cfg(feature = "incremental")]
#[pyfunction]
fn incremental_catalog() -> String {
    oracle_incremental::catalog().to_string()
}

pub(crate) fn register(module: &Bound<'_, PyModule>) -> PyResult<()> {
    #[cfg(any(feature = "bio", feature = "statistics"))]
    module.add("NativeRequestError", module.py().get_type::<NativeRequestError>())?;
    #[cfg(feature = "bio")]
    {
        module.add_function(wrap_pyfunction!(bio_call, module)?)?;
        module.add_function(wrap_pyfunction!(bio_catalog, module)?)?;
    }
    #[cfg(feature = "statistics")]
    {
        module.add_function(wrap_pyfunction!(statistics_call, module)?)?;
        module.add_function(wrap_pyfunction!(statistics_catalog, module)?)?;
    }
    #[cfg(feature = "science")]
    {
        module.add_function(wrap_pyfunction!(science_call, module)?)?;
        module.add_function(wrap_pyfunction!(science_catalog, module)?)?;
    }
    #[cfg(feature = "incremental")]
    {
        module.add_function(wrap_pyfunction!(incremental_call, module)?)?;
        module.add_function(wrap_pyfunction!(incremental_catalog, module)?)?;
    }
    Ok(())
}
