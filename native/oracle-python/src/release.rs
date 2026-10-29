//! Host-only admission of the measured pure-query runtime through PyO3.
//!
//! This is not authentication or self-attestation. The embedding host supplies
//! a trusted expected release identity and independently measured protected code
//! artifact digest. Neither value belongs in tenant request JSON. Image bytes
//! have already been checked by Image::open; all reader resources are in that
//! image. External resources, effects and kernel execution require other host
//! measurement/capability APIs and cannot be enabled by this factory.

use super::core;
use core::release::{Availability, OperationRegistration, ReleaseBindings, ReleaseManifest};
use pyo3::prelude::*;
use std::path::PathBuf;
use std::sync::Arc;

pub(super) fn profile_sha256(image: &super::Image) -> PyResult<String> {
    core::release::runtime_profile_sha256(&image.0.limits).map_err(super::error)
}

/// The caller is authenticated host code, not a tenant-facing descriptor loader.
/// Only fixed entrypoints supported by the actual opened image can register.
pub(super) fn open(
    py: Python<'_>,
    image: &super::Image,
    state_path: PathBuf,
    manifest_json: &str,
    expected_identity: &str,
    runtime_artifact_sha256: &str,
) -> PyResult<super::Runtime> {
    let image = image.0.clone();
    py.detach(move || {
        // from_json checks the 4 MiB bound before parsing and rejects unknown
        // typed fields, invalid hashes, duplicate IDs and dangling dependencies.
        let manifest = ReleaseManifest::from_json(manifest_json.as_bytes())?;
        if !manifest.resources.is_empty() {
            return Err(core::Error::Invalid(
                "host release factory does not admit external resources".into(),
            ));
        }
        let registrations = manifest
            .operations
            .iter()
            .filter(|operation| {
                operation.availability.is_serving()
                    && operation.version == 1
                    && (matches!(
                        operation.id.as_str(),
                        "graph.query"
                            | "graph.execute"
                            | "kqa.query"
                            | "kqa.execute"
                            | "host.retention.retire"
                            | "host.retention.inspect"
                    ) || (matches!(operation.id.as_str(), "reader.whole" | "reader.execute")
                        && image.capabilities.reader.is_some()))
            })
            .map(|operation| OperationRegistration {
                id: operation.id.clone(),
                // A manifest cannot make a Python callback or a separately
                // contained implementation native merely by declaring it so.
                availability: Availability::Implemented,
            })
            .collect::<Vec<_>>();
        let bindings = ReleaseBindings {
            runtime_artifact_sha256: runtime_artifact_sha256.into(),
            data_image_sha256: image.identity.clone(),
            resource_profile_sha256: core::release::runtime_profile_sha256(&image.limits)?,
            resources: vec![],
        };
        let admitted = manifest.admit(expected_identity, &bindings, &registrations)?;
        core::Runtime::open_release(image, &state_path, admitted)
    })
    .map(|runtime| super::Runtime(Arc::new(runtime)))
    .map_err(super::error)
}
