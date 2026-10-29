//! Host-only registration and cheap scoped handles for extracted specialists.
//! This transport is untrusted and establishes no new theorem or panel result.
//! Do not expose KernelExecutor or its constructor to an untrusted Python client.
use super::{error, Cancellation};
use oracle_runtime_core::{self as core, kernel as native};
use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use serde_json::Value;
use std::path::PathBuf;
use std::sync::Arc;

/// Construct once in authenticated hosting code. Descriptors are operator
/// deployment metadata, never a question's input. Admission checks actual bytes.
#[pyclass(frozen, name = "KernelExecutor")]
struct KernelExecutor(Arc<native::KernelExecutor>);
#[pymethods]
impl KernelExecutor {
    #[new]
    #[pyo3(signature=(descriptors_json,limits_json="{}"))]
    fn new(py: Python<'_>, descriptors_json: &str, limits_json: &str) -> PyResult<Self> {
        if descriptors_json.len() > 256 * 1024 || limits_json.len() > 16384 {
            return Err(PyValueError::new_err(
                "kernel deployment metadata exceeds byte bound",
            ));
        }
        let limits: native::KernelLimits =
            serde_json::from_str(limits_json).map_err(|e| PyValueError::new_err(e.to_string()))?;
        let descriptors =
            operator_descriptors(descriptors_json, limits.registry_entries).map_err(error)?;
        py.detach(move || {
            native::KernelExecutor::new(descriptors, limits)
                .map(|executor| Self(Arc::new(executor)))
        })
        .map_err(error)
    }

    /// Only the authenticated host should mint this tenant handle.
    fn tenant(&self, identity: String) -> PyResult<KernelTenant> {
        if identity.is_empty()
            || identity.len() > 160
            || !identity
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
        {
            return Err(PyValueError::new_err("invalid kernel tenant identity"));
        }
        Ok(KernelTenant {
            executor: self.0.clone(),
            identity,
        })
    }

    #[getter]
    fn active_workers(&self) -> usize {
        self.0.active_workers()
    }

    /// Reports copied byte identities, not build provenance or answer soundness.
    fn admissions(&self, py: Python<'_>) -> PyResult<String> {
        py.detach(|| serde_json::to_string(&self.0.admissions()).map_err(core::Error::from))
            .map_err(error)
    }
}

/// One tenant identity and an Arc; no resident process, corpus, queue or thread.
#[pyclass(frozen, name = "KernelTenant")]
struct KernelTenant {
    executor: Arc<native::KernelExecutor>,
    identity: String,
}
#[pymethods]
impl KernelTenant {
    /// Execute an already registered ID. The returned JSON has `reply` (the
    /// complete producer reply) and `admission` (the observed executable hash).
    /// These stateless kernels do not mutate the native conversation journal.
    fn execute(
        &self,
        py: Python<'_>,
        kernel_id: &str,
        question: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        let cancel = cancellation.0.clone();
        py.detach(|| {
            let reply = self
                .executor
                .execute(&self.identity, kernel_id, question, cancel)?;
            Ok(serde_json::to_string(&reply)?)
        })
        .map_err(error)
    }
}

fn operator_descriptors(text: &str, cap: usize) -> core::Result<Vec<native::KernelDescriptor>> {
    let value: Value = serde_json::from_str(text)?;
    let array = value
        .as_array()
        .ok_or_else(|| core::Error::Invalid("kernel descriptors must be an array".into()))?;
    if array.len() > cap {
        return Err(core::Error::Limit("kernel registry entries"));
    }
    array
        .iter()
        .map(|item| {
            let fields = item.as_object().ok_or_else(|| {
                core::Error::Invalid("kernel descriptor must be an object".into())
            })?;
            if fields.len() != 4
                || !fields
                    .keys()
                    .all(|key| ["id", "executable", "sha256", "family"].contains(&key.as_str()))
            {
                return Err(core::Error::Invalid(
                    "kernel descriptor requires exactly id, executable, sha256, family".into(),
                ));
            }
            let string = |key: &str| -> core::Result<String> {
                fields
                    .get(key)
                    .and_then(Value::as_str)
                    .map(str::to_owned)
                    .ok_or_else(|| {
                        core::Error::Invalid(format!("kernel descriptor {key} must be a string"))
                    })
            };
            let family: native::KernelFamily = serde_json::from_value(fields["family"].clone())?;
            Ok(native::KernelDescriptor::new(
                string("id")?,
                PathBuf::from(string("executable")?),
                string("sha256")?,
                family,
            ))
        })
        .collect()
}

pub(super) fn register(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_class::<KernelExecutor>()?;
    module.add_class::<KernelTenant>()?;
    Ok(())
}
