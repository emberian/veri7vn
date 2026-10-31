//! Bounded release declarations and host admission, independent of file paths.
//!
//! A SHA256 identity is a content binding, not authentication or a proof that
//! code is correct. The authenticated host supplies the expected identity,
//! measurements of its protected artifacts, and actual operation registrations.
//! Neither JSON schemas nor operation IDs select code, imports or executables.

use crate::{digest, Error, Limits, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};

pub const RELEASE_SCHEMA: &str = "oracle-native-release-v1";
pub const MAX_MANIFEST_BYTES: usize = 4 * 1024 * 1024;
pub const MAX_OPERATIONS: usize = 4096;
pub const MAX_RESOURCES: usize = 256;
pub const MAX_SCHEMAS: usize = 256;
pub const MAX_DESCRIPTOR_BYTES: usize = 24 * 1024;
const IDENTITY_DOMAIN: &[u8] = b"oracle-native-release-v1\0";
const PROFILE_DOMAIN: &[u8] = b"oracle-native-query-profile-v1\0";

/// Serving classification, not an assurance level. `Implemented` means the
/// host registered a native entrypoint; `LegacyContained` requires a separately
/// contained adapter. Neither claims a theorem or qualification result.
#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Availability {
    Implemented,
    LegacyContained,
    OfflineOnly,
    Unavailable,
}

impl Availability {
    pub fn is_serving(self) -> bool {
        matches!(self, Self::Implemented | Self::LegacyContained)
    }
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct SchemaVersion {
    pub id: String,
    pub version: u32,
}

/// Host-selected protected resource. IDs are names, never filesystem locators.
/// Schema versions are resolved against this manifest's `schemas` list.
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct ResourceDescriptor {
    pub id: String,
    pub sha256: String,
    pub schema_id: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct OperationDescriptor {
    pub id: String,
    pub version: u32,
    pub summary: String,
    pub availability: Availability,
    /// Bounded metadata only; this module does not evaluate JSON Schema or refs.
    pub input_schema: Value,
    pub output_schema: Value,
    /// Dependencies by resource ID. No client paths, URLs or executable names.
    pub resources: Vec<String>,
    pub limitations: Vec<String>,
}

/// Whole-release identity. The runtime artifact may be a host-measured binary,
/// wheel, or immutable deployment aggregate; it must cover executable semantics.
/// `resource_profile_sha256` binds the host's canonical execution limits/profile.
/// Every schema affecting execution, state or reply interpretation belongs here.
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct ReleaseManifest {
    pub schema: String,
    pub runtime_artifact_sha256: String,
    pub data_image_sha256: String,
    pub resource_profile_sha256: String,
    /// Optional hash of existing APPLIANCE.json bytes, preserving receipt linkage
    /// without treating those self-reported bytes as an authenticated signature.
    pub appliance_receipt_sha256: Option<String>,
    pub schemas: Vec<SchemaVersion>,
    pub resources: Vec<ResourceDescriptor>,
    pub operations: Vec<OperationDescriptor>,
}

/// Measurements supplied by trusted hosting code after protecting its artifacts.
/// The library cannot attest the caller or defeat later artifact mutation.
#[derive(Clone, Debug)]
pub struct ReleaseBindings {
    pub runtime_artifact_sha256: String,
    pub data_image_sha256: String,
    pub resource_profile_sha256: String,
    pub resources: Vec<ResourceBinding>,
}

#[derive(Clone, Debug)]
pub struct ResourceBinding {
    pub id: String,
    pub sha256: String,
}

/// A registration is host evidence that an entrypoint is present. It is not a
/// callback and cannot cause this module to load anything. The host must enforce
/// containment before registering a LegacyContained operation.
#[derive(Clone, Debug)]
pub struct OperationRegistration {
    pub id: String,
    pub availability: Availability,
}

#[derive(Clone, Copy, Debug, Default, Serialize, PartialEq, Eq)]
pub struct CapabilityCounts {
    pub implemented: usize,
    pub legacy_contained: usize,
    pub offline_only: usize,
    pub unavailable: usize,
}

/// Immutable after admission. Persist `identity()` in both conversation state
/// and request journals, and reject a mismatch before replay or evaluation.
#[derive(Clone, Debug)]
pub struct AdmittedRelease {
    manifest: ReleaseManifest,
    identity: String,
}

fn invalid(message: &str) -> Error {
    Error::Invalid(format!("release: {message}"))
}

fn valid_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 160
        && id.as_bytes()[0].is_ascii_alphanumeric()
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
}

fn check_hash(hash: &str) -> Result<()> {
    if hash.len() != 64
        || !hash
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(invalid(
            "SHA256 must contain 64 lowercase hexadecimal characters",
        ));
    }
    Ok(())
}

fn insert_id<'a>(seen: &mut BTreeSet<&'a str>, id: &'a str) -> Result<()> {
    if !valid_id(id) || !seen.insert(id) {
        return Err(invalid("invalid or duplicate ID"));
    }
    Ok(())
}

fn check_metadata(value: &Value, depth: usize, remaining: &mut usize) -> Result<()> {
    if depth > 32 || *remaining == 0 {
        return Err(Error::Limit("release schema metadata structure"));
    }
    *remaining -= 1;
    match value {
        Value::Object(fields) => {
            for (key, item) in fields {
                if key.len() > 256 {
                    return Err(Error::Limit("release schema key bytes"));
                }
                check_metadata(item, depth + 1, remaining)?;
            }
        }
        Value::Array(items) => {
            for item in items {
                check_metadata(item, depth + 1, remaining)?;
            }
        }
        Value::String(text) if text.len() > MAX_DESCRIPTOR_BYTES => {
            return Err(Error::Limit("release schema string bytes"));
        }
        _ => {}
    }
    Ok(())
}

/// Explicit object-key ordering avoids dependence on serde_json map features.
/// Arrays are ordered; only declaration sets are sorted before calling this.
fn canonical_json(value: &Value, out: &mut Vec<u8>, depth: usize) -> Result<()> {
    if depth > 64 {
        return Err(Error::Limit("release metadata depth"));
    }
    match value {
        Value::Object(fields) => {
            out.push(b'{');
            let ordered: BTreeMap<_, _> = fields.iter().collect();
            for (i, (key, value)) in ordered.into_iter().enumerate() {
                if i != 0 {
                    out.push(b',');
                }
                serde_json::to_writer(&mut *out, key)?;
                out.push(b':');
                canonical_json(value, out, depth + 1)?;
            }
            out.push(b'}');
        }
        Value::Array(items) => {
            out.push(b'[');
            for (i, value) in items.iter().enumerate() {
                if i != 0 {
                    out.push(b',');
                }
                canonical_json(value, out, depth + 1)?;
            }
            out.push(b']');
        }
        scalar => serde_json::to_writer(out, scalar)?,
    }
    Ok(())
}

/// Canonical identity of the actual pure query runtime's operator Limits.
/// Every serialized field participates, including worker/storage budgets.
/// A larger mixed runtime needs its own versioned composite profile covering
/// session, grammar, kernel and effect settings as well; do not reuse this
/// identity while omitting additional semantically relevant configuration.
pub fn runtime_profile_sha256(limits: &Limits) -> Result<String> {
    limits.validate()?;
    let mut bytes = PROFILE_DOMAIN.to_vec();
    canonical_json(&serde_json::to_value(limits)?, &mut bytes, 0)?;
    Ok(digest(&bytes))
}

impl ReleaseManifest {
    /// Parse only a bounded, strict declaration. Unknown typed fields and
    /// duplicate typed JSON keys are rejected by serde; schema contents remain
    /// opaque metadata. Call `admit` before attaching to a serving runtime.
    pub fn from_json(bytes: &[u8]) -> Result<Self> {
        if bytes.len() > MAX_MANIFEST_BYTES {
            return Err(Error::Limit("release manifest bytes"));
        }
        let manifest: Self = serde_json::from_slice(bytes)?;
        manifest.validate()?;
        Ok(manifest)
    }

    pub fn validate(&self) -> Result<()> {
        if self.schema != RELEASE_SCHEMA {
            return Err(invalid("unsupported manifest schema"));
        }
        for hash in [
            &self.runtime_artifact_sha256,
            &self.data_image_sha256,
            &self.resource_profile_sha256,
        ] {
            check_hash(hash)?;
        }
        if let Some(hash) = &self.appliance_receipt_sha256 {
            check_hash(hash)?;
        }
        if self.schemas.is_empty() || self.schemas.len() > MAX_SCHEMAS {
            return Err(Error::Limit("release schema declarations"));
        }
        if self.resources.len() > MAX_RESOURCES {
            return Err(Error::Limit("release resources"));
        }
        if self.operations.len() > MAX_OPERATIONS {
            return Err(Error::Limit("release operations"));
        }
        let mut schema_ids = BTreeSet::new();
        for schema in &self.schemas {
            insert_id(&mut schema_ids, &schema.id)?;
            if schema.version == 0 {
                return Err(invalid("zero schema version"));
            }
        }
        let mut resource_ids = BTreeSet::new();
        for resource in &self.resources {
            insert_id(&mut resource_ids, &resource.id)?;
            check_hash(&resource.sha256)?;
            if !schema_ids.contains(resource.schema_id.as_str()) {
                return Err(invalid("unknown resource schema"));
            }
        }
        let mut operation_ids = BTreeSet::new();
        for operation in &self.operations {
            insert_id(&mut operation_ids, &operation.id)?;
            if operation.version == 0
                || operation.summary.is_empty()
                || operation.summary.len() > 512
            {
                return Err(invalid("invalid operation version or summary"));
            }
            if !operation.input_schema.is_object() || !operation.output_schema.is_object() {
                return Err(invalid("operation schemas must be objects"));
            }
            let mut remaining = 8192;
            check_metadata(&operation.input_schema, 0, &mut remaining)?;
            check_metadata(&operation.output_schema, 0, &mut remaining)?;
            if operation.resources.len() > MAX_RESOURCES || operation.limitations.len() > 16 {
                return Err(Error::Limit("release operation metadata"));
            }
            if operation
                .limitations
                .iter()
                .any(|v| v.is_empty() || v.len() > 1024)
            {
                return Err(invalid("invalid operation limitation"));
            }
            let mut dependencies = BTreeSet::new();
            for resource in &operation.resources {
                insert_id(&mut dependencies, resource)?;
                if !resource_ids.contains(resource.as_str()) {
                    return Err(invalid("unknown operation resource"));
                }
            }
            if serde_json::to_vec(operation)?.len() > MAX_DESCRIPTOR_BYTES {
                return Err(Error::Limit("release operation descriptor bytes"));
            }
        }
        // Bounds also apply to directly constructed Rust values, not only JSON.
        if serde_json::to_vec(self)?.len() > MAX_MANIFEST_BYTES {
            return Err(Error::Limit("release manifest bytes"));
        }
        Ok(())
    }

    /// SHA256(domain || canonical JSON). Declaration order and object key order
    /// do not matter. Schema arrays and limitations retain their stated order.
    /// Numeric schema constants retain their JSON representation (1 != 1.0).
    pub fn identity(&self) -> Result<String> {
        self.validate()?;
        let mut normalized = self.clone();
        normalized.schemas.sort_by(|a, b| a.id.cmp(&b.id));
        normalized.resources.sort_by(|a, b| a.id.cmp(&b.id));
        normalized.operations.sort_by(|a, b| a.id.cmp(&b.id));
        for operation in &mut normalized.operations {
            operation.resources.sort();
        }
        let mut bytes = IDENTITY_DOMAIN.to_vec();
        canonical_json(&serde_json::to_value(normalized)?, &mut bytes, 0)?;
        Ok(digest(&bytes))
    }

    /// Compare against separately authenticated deployment metadata and actual
    /// host measurements. Every serving declaration must have an exactly matching
    /// registration; unavailable/offline declarations cannot acquire callability.
    pub fn admit(
        self,
        expected_identity: &str,
        bindings: &ReleaseBindings,
        registrations: &[OperationRegistration],
    ) -> Result<AdmittedRelease> {
        check_hash(expected_identity)?;
        let identity = self.identity()?;
        if identity != expected_identity {
            return Err(Error::Conflict("release identity mismatch"));
        }
        for (declared, measured) in [
            (
                &self.runtime_artifact_sha256,
                &bindings.runtime_artifact_sha256,
            ),
            (&self.data_image_sha256, &bindings.data_image_sha256),
            (
                &self.resource_profile_sha256,
                &bindings.resource_profile_sha256,
            ),
        ] {
            check_hash(measured)?;
            if declared != measured {
                return Err(Error::Conflict("release artifact/profile mismatch"));
            }
        }
        if bindings.resources.len() > MAX_RESOURCES || registrations.len() > MAX_OPERATIONS {
            return Err(Error::Limit("release admission declarations"));
        }
        let mut resources = BTreeMap::new();
        for resource in &bindings.resources {
            check_hash(&resource.sha256)?;
            if !valid_id(&resource.id)
                || resources
                    .insert(resource.id.as_str(), resource.sha256.as_str())
                    .is_some()
            {
                return Err(invalid("invalid or duplicate resource binding"));
            }
        }
        if resources.len() != self.resources.len()
            || self
                .resources
                .iter()
                .any(|r| resources.get(r.id.as_str()).copied() != Some(r.sha256.as_str()))
        {
            return Err(Error::Conflict("release resource mismatch"));
        }
        let mut registry = BTreeMap::new();
        for operation in registrations {
            if !valid_id(&operation.id)
                || !operation.availability.is_serving()
                || registry
                    .insert(operation.id.as_str(), operation.availability)
                    .is_some()
            {
                return Err(invalid("invalid or duplicate serving registration"));
            }
        }
        let mut serving = 0;
        for operation in &self.operations {
            if operation.availability.is_serving() {
                serving += 1;
                if registry.get(operation.id.as_str()).copied() != Some(operation.availability) {
                    return Err(Error::Conflict(
                        "release availability does not match registry",
                    ));
                }
            }
        }
        if serving != registry.len() {
            return Err(Error::Conflict("undeclared serving operation"));
        }
        Ok(AdmittedRelease {
            manifest: self,
            identity,
        })
    }
}

impl AdmittedRelease {
    /// Compiled native owner schemas must be admitted independently of session
    /// envelope format. Snapshot bytes cannot register their own decoders.
    pub fn require_schema(&self, id: &str, version: u32) -> Result<()> {
        if self
            .manifest
            .schemas
            .iter()
            .any(|schema| schema.id == id && schema.version == version)
        {
            Ok(())
        } else {
            Err(Error::Format(format!(
                "unadmitted native owner schema: {id}/{version}"
            )))
        }
    }
    pub fn identity(&self) -> &str {
        &self.identity
    }
    pub fn manifest(&self) -> &ReleaseManifest {
        &self.manifest
    }
    /// Runtime-constructor guard using the already opened Image's actual digest
    /// and Limits, plus the runtime's hardcoded supported schema requirements.
    /// Call before opening state, replaying a result or evaluating a request.
    /// Admission has separately checked the host-measured executable/resources;
    /// this guard does not pretend to measure its own currently executing code.
    pub fn check_runtime(
        &self,
        data_image_sha256: &str,
        limits: &Limits,
        required_schemas: &[SchemaVersion],
    ) -> Result<()> {
        self.check_runtime_profile(
            data_image_sha256,
            &runtime_profile_sha256(limits)?,
            required_schemas,
        )
    }

    /// Variant for a host-measured versioned composite execution profile. The
    /// caller must calculate it from actual admitted runtime settings, never
    /// copy the claimed digest out of the manifest to satisfy this check.
    pub fn check_runtime_profile(
        &self,
        data_image_sha256: &str,
        measured_profile_sha256: &str,
        required_schemas: &[SchemaVersion],
    ) -> Result<()> {
        check_hash(data_image_sha256)?;
        check_hash(measured_profile_sha256)?;
        if self.manifest.data_image_sha256 != data_image_sha256
            || self.manifest.resource_profile_sha256 != measured_profile_sha256
        {
            return Err(Error::Conflict("opened runtime does not match release"));
        }
        if required_schemas.is_empty() || required_schemas.len() > MAX_SCHEMAS {
            return Err(invalid("invalid runtime schema requirements"));
        }
        let mut seen = BTreeSet::new();
        for required in required_schemas {
            insert_id(&mut seen, &required.id)?;
            if required.version == 0 {
                return Err(invalid("zero required schema version"));
            }
            if !self
                .manifest
                .schemas
                .iter()
                .any(|declared| declared == required)
            {
                return Err(Error::Conflict("runtime schema does not match release"));
            }
        }
        Ok(())
    }
    pub fn operation(&self, id: &str) -> Option<&OperationDescriptor> {
        self.manifest
            .operations
            .iter()
            .find(|operation| operation.id == id)
    }
    /// Native serving code must refuse legacy/offline/unavailable entries.
    /// Separate containment and effect protocols are required for legacy work.
    pub fn require_implemented(&self, id: &str) -> Result<&OperationDescriptor> {
        self.operation(id)
            .filter(|operation| operation.availability == Availability::Implemented)
            .ok_or_else(|| invalid("operation is not implemented in native runtime"))
    }
    pub fn counts(&self) -> CapabilityCounts {
        let mut counts = CapabilityCounts::default();
        for operation in &self.manifest.operations {
            match operation.availability {
                Availability::Implemented => counts.implemented += 1,
                Availability::LegacyContained => counts.legacy_contained += 1,
                Availability::OfflineOnly => counts.offline_only += 1,
                Availability::Unavailable => counts.unavailable += 1,
            }
        }
        counts
    }
    pub fn check_identity(&self, retained_identity: &str) -> Result<()> {
        if self.identity == retained_identity {
            Ok(())
        } else {
            Err(Error::Conflict(
                "release changed; explicit migration required",
            ))
        }
    }
}
