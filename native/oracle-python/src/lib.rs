#![forbid(unsafe_code)]
use oracle_runtime_core as core;
use pyo3::exceptions::{PyRuntimeError, PyValueError};
use pyo3::prelude::*;
use std::path::PathBuf;
use std::sync::Arc;

pyo3::create_exception!(oracle_native, BusyError, PyRuntimeError);
pyo3::create_exception!(oracle_native, ConflictError, PyRuntimeError);
pyo3::create_exception!(oracle_native, BudgetError, PyRuntimeError);

fn error(e: core::Error) -> PyErr {
    let message = e.to_string();
    match e {
        core::Error::Busy => BusyError::new_err(message),
        core::Error::Conflict(_) => ConflictError::new_err(message),
        core::Error::Cancelled | core::Error::Deadline | core::Error::Limit(_) => {
            BudgetError::new_err(message)
        }
        core::Error::Invalid(_) | core::Error::Json(_) => PyValueError::new_err(message),
        _ => PyRuntimeError::new_err(message),
    }
}

#[pyclass(frozen, name = "Cancellation")]
#[derive(Clone, Default)]
struct Cancellation(core::Cancellation);
#[pymethods]
impl Cancellation {
    #[new]
    fn new() -> Self {
        Self::default()
    }
    fn cancel(&self) {
        self.0.cancel();
    }
}

#[pyclass(frozen, name = "Runtime")]
struct Runtime(Arc<core::Runtime>);
#[pymethods]
impl Runtime {
    #[new]
    #[pyo3(signature=(image_path,image_sha256,state_path,limits_json="{}"))]
    fn new(
        py: Python<'_>,
        image_path: PathBuf,
        image_sha256: String,
        state_path: PathBuf,
        limits_json: &str,
    ) -> PyResult<Self> {
        let limits: core::Limits =
            serde_json::from_str(limits_json).map_err(|e| PyValueError::new_err(e.to_string()))?;
        py.detach(move || {
            let image = core::Image::open(&image_path, &image_sha256, limits)?;
            core::Runtime::open(image, &state_path).map(|r| Self(Arc::new(r)))
        })
        .map_err(error)
    }
    #[getter]
    fn image_sha256(&self) -> &str {
        &self.0.image.identity
    }
    #[staticmethod]
    fn from_image(py: Python<'_>, image: &Image, state_path: PathBuf) -> PyResult<Self> {
        let image = image.0.clone();
        py.detach(move || core::Runtime::open(image, &state_path).map(|r| Self(Arc::new(r))))
            .map_err(error)
    }
    /// Only the authenticated host should mint these scoped handles.
    fn tenant(&self, identity: String) -> Tenant {
        Tenant {
            runtime: self.0.clone(),
            identity,
        }
    }
}

#[pyclass(frozen, name = "Image")]
struct Image(Arc<core::Image>);
#[pymethods]
impl Image {
    #[new]
    #[pyo3(signature=(path,sha256,limits_json="{}"))]
    fn new(py: Python<'_>, path: PathBuf, sha256: String, limits_json: &str) -> PyResult<Self> {
        let limits: core::Limits =
            serde_json::from_str(limits_json).map_err(|e| PyValueError::new_err(e.to_string()))?;
        py.detach(move || core::Image::open(&path, &sha256, limits).map(Self))
            .map_err(error)
    }
    fn query(
        &self,
        py: Python<'_>,
        tenant: &str,
        plan_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| self.0.query(tenant, plan_json, cancel))
            .map_err(error)
    }
    #[getter]
    fn sha256(&self) -> &str {
        &self.0.identity
    }
    #[getter]
    fn active_workers(&self) -> usize {
        self.0.active_workers()
    }
}

/// A tenant handle holds a string and an Arc, never an interpreter or data copy.
#[pyclass(frozen, name = "Tenant")]
struct Tenant {
    runtime: Arc<core::Runtime>,
    identity: String,
}
#[pymethods]
impl Tenant {
    fn query(
        &self,
        py: Python<'_>,
        plan_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| self.runtime.query(&self.identity, plan_json, cancel))
            .map_err(error)
    }
    fn execute(
        &self,
        py: Python<'_>,
        session: &str,
        request: &str,
        expected_version: i64,
        plan_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| {
            self.runtime.execute(
                &self.identity,
                session,
                request,
                expected_version,
                plan_json,
                cancel,
            )
        })
        .map_err(error)
    }
}

#[pyfunction]
fn build_image(
    py: Python<'_>,
    source: PathBuf,
    output: PathBuf,
    max_source_bytes: u64,
    max_record_bytes: usize,
) -> PyResult<String> {
    py.detach(move || {
        core::build_image(&source, &output, max_source_bytes, max_record_bytes)
            .and_then(|r| Ok(serde_json::to_string(&r)?))
    })
    .map_err(error)
}

#[pymodule]
fn oracle_native(py: Python<'_>, module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_class::<Runtime>()?;
    module.add_class::<Cancellation>()?;
    module.add_class::<Image>()?;
    module.add_class::<Tenant>()?;
    module.add("API_VERSION", "0.1")?;
    module.add_function(wrap_pyfunction!(build_image, module)?)?;
    module.add("BusyError", py.get_type::<BusyError>())?;
    module.add("ConflictError", py.get_type::<ConflictError>())?;
    module.add("BudgetError", py.get_type::<BudgetError>())?;
    Ok(())
}
