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

    /// Check supplied occurrence IDs against this exact bounded graph. Producer
    /// declarations never confer HOL scope; admission metadata controls that.
    fn check_mst(
        &self,
        py: Python<'_>,
        kernel_id: &str,
        graph_json: &str,
        edge_ids_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        if graph_json.len() > 65536 || edge_ids_json.len() > 1024 {
            return Err(PyValueError::new_err("MST request exceeds byte bound"));
        }
        let cancel = cancellation.0.clone();
        py.detach(|| {
            let graph: native::MstGraph = serde_json::from_str(graph_json)?;
            let ids: Vec<usize> = serde_json::from_str(edge_ids_json)?;
            let result =
                self.executor
                    .check_mst(&self.identity, kernel_id, &graph, &ids, cancel)?;
            Ok(serde_json::to_string(&result)?)
        })
        .map_err(error)
    }

    /// Actual Rust candidate production + independent Rust forest check +
    /// resident extracted connected-tree check under the original deadline.
    /// The returned forest remains useful when the HOL scope is unsupported.
    #[cfg(feature = "reasoning")]
    fn minimum_spanning_forest(
        &self,
        py: Python<'_>,
        kernel_id: &str,
        graph_json: &str,
        cancellation: &Cancellation,
    ) -> PyResult<String> {
        if graph_json.len() > 65536 {
            return Err(PyValueError::new_err("MST request exceeds byte bound"));
        }
        let cancel = cancellation.0.clone();
        py.detach(|| {
            let budget = self.executor.request_budget(cancel)?;
            let graph: native::MstGraph = serde_json::from_str(graph_json)?;
            graph.validate_candidate(&[])?;
            budget.check()?;
            let input = oracle_reasoning::graph::GraphInput {
                vertices: graph.vertices, edges: graph.edges.clone(),
            };
            let limits = oracle_reasoning::Limits { vertices:64, edges:256,
                ..oracle_reasoning::Limits::default() };
            let forest = oracle_reasoning::graph::minimum_spanning_forest(&input, &limits)
                .map_err(|e| core::Error::Invalid(e.to_string()))?;
            budget.check()?;
            let certificate = self.executor.check_mst_with_budget(
                &self.identity, kernel_id, &graph, &forest.edge_ids, &budget)?;
            Ok(serde_json::to_string(&serde_json::json!({
                "rust_forest":forest, "certificate":certificate,
                "scope":"supplied graph; HOL scope only for receipt-admitted accepted connected trees"
            }))?)
        }).map_err(error)
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
            if !["id", "executable", "sha256", "family"].iter().all(|k| fields.contains_key(*k))
                || !fields.keys().all(|key| ["id", "executable", "sha256", "family", "compiled_receipt"].contains(&key.as_str()))
            {
                return Err(core::Error::Invalid(
                    "kernel descriptor requires id, executable, sha256, family and optional compiled_receipt".into(),
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
            let descriptor = native::KernelDescriptor::new(
                string("id")?, PathBuf::from(string("executable")?), string("sha256")?, family,
            );
            if let Some(receipt) = fields.get("compiled_receipt") {
                let object = receipt.as_object().ok_or_else(|| core::Error::Invalid("compiled_receipt must be an object".into()))?;
                if object.len() != 2 || !object.contains_key("path") || !object.contains_key("sha256") {
                    return Err(core::Error::Invalid("compiled_receipt requires path and sha256".into()));
                }
                let path = object["path"].as_str().ok_or_else(|| core::Error::Invalid("compiled_receipt path must be a string".into()))?;
                let sha = object["sha256"].as_str().ok_or_else(|| core::Error::Invalid("compiled_receipt sha256 must be a string".into()))?;
                Ok(descriptor.with_compiled_receipt(path, sha))
            } else { Ok(descriptor) }
        })
        .collect()
}

pub(super) fn register(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_class::<KernelExecutor>()?;
    module.add_class::<KernelTenant>()?;
    Ok(())
}
