#![forbid(unsafe_code)]
use oracle_runtime_core as core;
mod kernel;
#[cfg(any(
    feature = "science",
    feature = "incremental",
    feature = "bio",
    feature = "statistics"
))]
mod providers;
#[cfg(feature = "reasoning")]
mod reasoning;
mod release;
use pyo3::exceptions::{PyRuntimeError, PyValueError};
use pyo3::prelude::*;
use std::path::PathBuf;
use std::sync::Arc;

pyo3::create_exception!(oracle_native, BusyError, PyRuntimeError);
pyo3::create_exception!(oracle_native, ConflictError, PyRuntimeError);
pyo3::create_exception!(oracle_native, BudgetError, PyRuntimeError);

// Exact request-local errors from reviewed pure providers only. Durable runtime
// errors keep their independent, conservative retirement boundary.
#[cfg(any(
    feature = "reasoning",
    feature = "science",
    feature = "bio",
    feature = "statistics"
))]
pyo3::create_exception!(oracle_native, NativeRequestError, PyValueError);

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
    fn identity(&self) -> &str {
        self.0.identity()
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
    #[staticmethod]
    fn from_release(
        py: Python<'_>,
        image: &Image,
        state_path: PathBuf,
        manifest_json: &str,
        expected_identity: &str,
        runtime_artifact_sha256: &str,
    ) -> PyResult<Self> {
        release::open(
            py,
            image,
            state_path,
            manifest_json,
            expected_identity,
            runtime_artifact_sha256,
        )
    }
    /// Authenticated host maintenance. Permanently closes this namespace and
    /// discards its local replay, conversation and completed-effect payloads.
    /// This method is deliberately absent from the tenant handle.
    fn retire_namespace(
        &self,
        py: Python<'_>,
        tenant: &str,
        cancellation: &Cancellation,
    ) -> PyResult<()> {
        let cancel = cancellation.0.clone();
        py.detach(|| self.0.retire_namespace(tenant, cancel))
            .map_err(error)
    }
    /// Host inspection of the permanent durable retirement fence.
    fn namespace_is_retired(&self, py: Python<'_>, tenant: &str) -> PyResult<bool> {
        py.detach(|| self.0.namespace_is_retired(tenant))
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
    fn resource_profile_sha256(&self) -> PyResult<String> {
        release::profile_sha256(self)
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
    fn read_whole(
        &self,
        py: Python<'_>,
        question: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| self.runtime.read_whole(&self.identity, question, cancel))
            .map_err(error)
    }
    fn query_program(
        &self,
        py: Python<'_>,
        program_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| {
            self.runtime
                .query_program(&self.identity, program_json, cancel)
        })
        .map_err(error)
    }
    fn execute_language(
        &self,
        py: Python<'_>,
        session: &str,
        request: &str,
        expected_version: i64,
        question: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| {
            self.runtime.execute_language(
                &self.identity,
                session,
                request,
                expected_version,
                question,
                cancel,
            )
        })
        .map_err(error)
    }
    fn execute_program(
        &self,
        py: Python<'_>,
        session: &str,
        request: &str,
        expected_version: i64,
        program_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| {
            self.runtime.execute_program(
                &self.identity,
                session,
                request,
                expected_version,
                program_json,
                cancel,
            )
        })
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

/// Offline API. The optional JSON contains inert learned tables, never a pickle.
#[pyfunction]
#[pyo3(signature=(source,output,max_source_bytes,max_record_bytes,reader_json=None))]
fn build_reader_image(
    py: Python<'_>,
    source: PathBuf,
    output: PathBuf,
    max_source_bytes: u64,
    max_record_bytes: usize,
    reader_json: Option<&str>,
) -> PyResult<String> {
    py.detach(|| {
        let reader: Option<core::grammar::ReaderExport> =
            reader_json.map(serde_json::from_str).transpose()?;
        let options = core::ReaderBuildOptions {
            reader: reader.as_ref(),
            ..Default::default()
        };
        let receipt = core::build_image_with_reader(
            &source,
            &output,
            max_source_bytes,
            max_record_bytes,
            options,
        )?;
        Ok(serde_json::to_string(&receipt)?)
    })
    .map_err(error)
}
#[pyfunction]
fn operation_catalog() -> PyResult<String> {
    serde_json::to_string(&core::operation_catalog())
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))
}

#[pymodule]
fn oracle_native(py: Python<'_>, module: &Bound<'_, PyModule>) -> PyResult<()> {
    #[cfg(any(
        feature = "reasoning",
        feature = "science",
        feature = "bio",
        feature = "statistics"
    ))]
    module.add(
        "NativeRequestError",
        module.py().get_type::<NativeRequestError>(),
    )?;
    #[cfg(any(
        feature = "science",
        feature = "incremental",
        feature = "bio",
        feature = "statistics"
    ))]
    providers::register(module)?;
    #[cfg(feature = "reasoning")]
    reasoning::register(module)?;
    kernel::register(module)?;
    module.add_class::<Runtime>()?;
    module.add_class::<Cancellation>()?;
    module.add_class::<Image>()?;
    module.add_class::<Tenant>()?;
    module.add("API_VERSION", "0.2")?;
    module.add_function(wrap_pyfunction!(build_image, module)?)?;
    module.add_function(wrap_pyfunction!(build_reader_image, module)?)?;
    module.add_function(wrap_pyfunction!(operation_catalog, module)?)?;
    module.add("BusyError", py.get_type::<BusyError>())?;
    module.add("ConflictError", py.get_type::<ConflictError>())?;
    module.add("BudgetError", py.get_type::<BudgetError>())?;
    Ok(())
}
