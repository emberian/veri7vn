//! Operator configuration. Every artifact is named by an absolute path and the
//! SHA-256 of its bytes; nothing here can come from a request. Unknown fields
//! fail startup rather than being ignored.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::io::Read;
use std::path::{Path, PathBuf};

pub const SCHEMA: &str = "oracle-host-v1";
const MAX_CONFIG_BYTES: u64 = 8 * 1024 * 1024;

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub schema: String,
    /// Opt-in core-authoritative readonly-v1 or native-v1 conversation profile.
    #[serde(default)]
    pub conversation_profile: Option<String>,
    /// Explicit source ID contract for cross-provider entity transfer. Included
    /// in deployment identity; Q-prefixed labels alone never establish this.
    #[serde(default)]
    pub conversation_entity_namespace: Option<String>,
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(default)]
    pub limits: HostLimits,
    /// Durable `/query` request journal (exact retry, conversation registry).
    pub journal: PathBuf,
    pub native: Option<NativeConfig>,
    pub kernels: Option<KernelsConfig>,
    pub engine: Option<EngineConfig>,
    pub pure: Option<PureConfig>,
}

/// Pure supplied-argument profiles linked into the host, each a cargo feature.
#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PureConfig {
    pub profiles: Vec<String>,
    /// Operator-admitted clingo for the `logic` profile, and only for it.
    pub solver: Option<Artifact>,
}

fn default_port() -> u16 {
    7071
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(default, deny_unknown_fields)]
pub struct HostLimits {
    /// One global cap on requests doing work, across every route and tenant.
    pub capacity: usize,
    /// Optional per-tenant live-work cap; absent preserves the global-only policy.
    pub tenant_capacity: Option<usize>,
    /// Open connections, including ones still sending headers or body.
    pub connections: usize,
    pub request_bytes: usize,
    pub reply_bytes: usize,
    /// Absolute deadline for headers plus body, as the reference server.
    pub ingress_ms: u64,
    /// Wall deadline for one `/invoke` call; the slot stays occupied until the
    /// work actually stops.
    pub invoke_ms: u64,
    /// Shared cooperative deadline for the complete query cascade.
    pub query_ms: u64,
    /// Work units shared by all native/provider branches of one request.
    pub execution_fuel: u64,
    /// Explicitly tracked retained request data; not process RSS or untracked
    /// foreign allocations. Components may impose a tighter shared ceiling.
    pub request_memory_bytes: usize,
    /// Retained `/query` request records before the journal refuses (507).
    pub retained_requests: u64,
    /// Remembered (tenant, conversation) Engine bindings before refusing (507).
    pub conversations: u64,
}

impl Default for HostLimits {
    fn default() -> Self {
        Self {
            capacity: 2,
            tenant_capacity: None,
            connections: 16,
            request_bytes: 1024 * 1024,
            reply_bytes: 2 * 1024 * 1024,
            ingress_ms: 5000,
            invoke_ms: 30_000,
            query_ms: 120_000,
            execution_fuel: 10_000_000,
            request_memory_bytes: 32 * 1024 * 1024,
            retained_requests: 100_000,
            conversations: 100_000,
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Artifact {
    pub path: PathBuf,
    pub sha256: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NativeConfig {
    pub image: PathBuf,
    pub image_sha256: String,
    pub state: PathBuf,
    #[serde(default)]
    pub core_limits: Value,
    /// Complete release declaration binding this host binary, the image and the
    /// core resource profile. Absent: development mode, reported as such.
    pub release: Option<ReleaseConfig>,
    /// Route the front door's questions through the learned reader.
    #[serde(default = "yes")]
    pub reader_route: bool,
}

fn yes() -> bool {
    true
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReleaseConfig {
    /// Exact JSON text; numbers are never re-rendered.
    pub manifest_json: String,
    pub identity: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct KernelsConfig {
    #[serde(default)]
    pub limits: Value,
    pub organs: Vec<OrganConfig>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct OrganConfig {
    pub id: String,
    pub executable: PathBuf,
    pub sha256: String,
    /// `oracle_runtime_core::KernelFamily` JSON, e.g. `"acoustics"`.
    pub family: Value,
    /// The specialist's acceptance rule (shipped manifest plus the family's
    /// capability extension), exactly as `tools/runtime_contract.acceptance`.
    pub accept: Acceptance,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Acceptance {
    pub kinds: Vec<String>,
    #[serde(default)]
    pub declines_in_domain: Vec<String>,
    pub context_regex: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct EngineConfig {
    pub python: Artifact,
    /// Production JSON-lines Engine worker, admitted independently of its checkout.
    pub answerer: Artifact,
    /// Source-bound helper imported beside the admitted worker. Required for
    /// the covered conversation profile, independently hashed at admission.
    #[serde(default)]
    pub conversation_adapter: Option<Artifact>,
    /// A pinned provisioner receipt admits the materialized tree without Git.
    #[serde(default)]
    pub materialization: Option<Artifact>,
    /// Independently admitted public tables; source and artifacts remain protected
    /// against writes for the complete host lifetime. No private state is shared.
    #[serde(default)]
    pub prepared: Option<PreparedEngineConfig>,
    /// The upstream checkout and source revision (Git alone is development mode).
    pub checkout: PathBuf,
    pub revision: String,
    /// Parent of each worker's private `--state` directory.
    pub state: PathBuf,
    #[serde(default = "one")]
    pub workers: usize,
    #[serde(default = "startup_ms")]
    pub startup_ms: u64,
    #[serde(default = "turn_ms")]
    pub turn_ms: u64,
    /// Optional answerer composition flags, passed as fixed argv.
    pub specialist: Option<PathBuf>,
    pub compose: Option<String>,
    pub tip: Option<String>,
    #[serde(default = "reply_bytes")]
    pub reply_bytes: usize,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct PreparedEngineConfig {
    /// Exact external artifact-root/MANIFEST.json, never an inherited environment.
    pub artifact: Artifact,
    #[serde(default = "replacement_attempts")]
    pub replacement_attempts: usize,
    #[serde(default = "replacement_backoff_ms")]
    pub replacement_backoff_ms: u64,
}
fn replacement_attempts() -> usize {
    2
}
fn replacement_backoff_ms() -> u64 {
    1000
}

fn one() -> usize {
    1
}
fn startup_ms() -> u64 {
    600_000
}
fn turn_ms() -> u64 {
    300_000
}
fn reply_bytes() -> usize {
    1024 * 1024
}

#[derive(Debug)]
pub struct ConfigError(pub String);

impl std::fmt::Display for ConfigError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

pub fn err(message: impl Into<String>) -> ConfigError {
    ConfigError(message.into())
}

pub fn is_hash(text: &str) -> bool {
    text.len() == 64 && text.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f'))
}

pub fn sha256_file(path: &Path) -> std::io::Result<String> {
    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = vec![0u8; 1 << 16];
    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

pub fn sha256_bytes(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

/// Check an operator artifact's bytes against its declared digest.
pub fn admit(what: &str, artifact: &Artifact) -> Result<(), ConfigError> {
    absolute(what, &artifact.path)?;
    if !is_hash(&artifact.sha256) {
        return Err(err(format!("{what}: sha256 must be 64 lowercase hex")));
    }
    let actual = sha256_file(&artifact.path).map_err(|e| {
        err(format!(
            "{what}: cannot read {}: {e}",
            artifact.path.display()
        ))
    })?;
    if actual != artifact.sha256 {
        return Err(err(format!(
            "{what}: sha256 mismatch for {} (declared {}, actual {actual})",
            artifact.path.display(),
            artifact.sha256
        )));
    }
    Ok(())
}

pub fn absolute(what: &str, path: &Path) -> Result<(), ConfigError> {
    if !path.is_absolute() {
        return Err(err(format!("{what}: path must be absolute")));
    }
    Ok(())
}

/// Resolve a checkout's HEAD revision from `.git` files, without running git.
/// This names a commit; it does not hash the working tree.
pub fn git_head(checkout: &Path) -> Result<String, ConfigError> {
    let git = checkout.join(".git");
    let read = |p: &Path| {
        std::fs::read_to_string(p)
            .map_err(|e| err(format!("engine checkout: {}: {e}", p.display())))
    };
    let head = read(&git.join("HEAD"))?;
    let head = head.trim();
    let Some(reference) = head.strip_prefix("ref: ") else {
        return Ok(head.to_owned());
    };
    let loose = git.join(reference);
    if loose.is_file() {
        return Ok(read(&loose)?.trim().to_owned());
    }
    let packed = read(&git.join("packed-refs"))?;
    packed
        .lines()
        .filter(|line| !line.starts_with('#') && !line.starts_with('^'))
        .find_map(|line| {
            let (hash, name) = line.split_once(' ')?;
            (name == reference).then(|| hash.to_owned())
        })
        .ok_or_else(|| err("engine checkout: HEAD reference not found"))
}

/// Bind serving semantics, not filesystem locators. Moving a complete deployment
/// and its state does not change its identity. Changing code, data, routing,
/// budgets or a worker policy does. Protected artifact custody remains required.
pub fn deployment_identity(config: &Config, host_sha256: &str) -> Result<String, ConfigError> {
    let mut value = serde_json::to_value(config).map_err(|e| err(e.to_string()))?;
    let object = value.as_object_mut().expect("configuration object");
    object.remove("port");
    object.remove("journal");
    if let Some(native) = object.get_mut("native").and_then(Value::as_object_mut) {
        native.remove("image");
        native.remove("state");
        let supplied = native.get("core_limits").cloned().unwrap_or(Value::Null);
        let limits: oracle_runtime_core::Limits = if supplied.is_null() {
            Default::default()
        } else {
            serde_json::from_value(supplied).map_err(|e| err(format!("native.core_limits: {e}")))?
        };
        native.insert(
            "core_limits".into(),
            serde_json::to_value(limits).map_err(|e| err(e.to_string()))?,
        );
    }
    if let Some(kernels) = object.get_mut("kernels").and_then(Value::as_object_mut) {
        let supplied = kernels.get("limits").cloned().unwrap_or(Value::Null);
        let limits: oracle_runtime_core::KernelLimits = if supplied.is_null() {
            Default::default()
        } else {
            serde_json::from_value(supplied).map_err(|e| err(format!("kernels.limits: {e}")))?
        };
        kernels.insert(
            "limits".into(),
            serde_json::to_value(limits).map_err(|e| err(e.to_string()))?,
        );
        if let Some(organs) = kernels.get_mut("organs").and_then(Value::as_array_mut) {
            for organ in organs {
                organ
                    .as_object_mut()
                    .expect("organ object")
                    .remove("executable");
            }
        }
    }
    if let Some(engine) = object.get_mut("engine").and_then(Value::as_object_mut) {
        engine.remove("state");
        // A specialist's relative path is part of the routing contract.
        if let Some(settings) = &config.engine {
            if let Some(specialist) = &settings.specialist {
                let name = specialist
                    .strip_prefix(&settings.checkout)
                    .unwrap_or(specialist);
                engine.insert("specialist".into(), json!(name));
            }
        }
        engine.remove("checkout");
        if let Some(artifact) = engine
            .get_mut("prepared")
            .and_then(|p| p.get_mut("artifact"))
            .and_then(Value::as_object_mut)
        {
            artifact.remove("path");
        }

        for field in [
            "python",
            "answerer",
            "materialization",
            "conversation_adapter",
        ] {
            if let Some(artifact) = engine.get_mut(field).and_then(Value::as_object_mut) {
                artifact.remove("path");
            }
        }
    }
    if let Some(solver) = object
        .get_mut("pure")
        .and_then(|p| p.get_mut("solver"))
        .and_then(Value::as_object_mut)
    {
        solver.remove("path");
    }
    Ok(sha256_bytes(&crate::wire::encode(&json!({
        "schema": "oracle-host-deployment-v1", "host_sha256": host_sha256,
        "config": value
    }))))
}

/// Admit a provisioner's complete file inventory once, before any worker starts.
/// Receipt hashes pin patched contents; a Git commit alone cannot do that.
pub fn admit_engine_checkout(settings: &EngineConfig) -> Result<Value, ConfigError> {
    use std::collections::BTreeSet;
    use std::os::unix::fs::PermissionsExt;
    absolute("engine.checkout", &settings.checkout)?;
    let Some(artifact) = &settings.materialization else {
        let head = git_head(&settings.checkout)?;
        if head != settings.revision {
            return Err(err("engine.checkout revision mismatch"));
        }
        return Ok(
            json!({"mode": "development_git", "revision": head, "contents_verified": false}),
        );
    };
    if artifact.path != settings.checkout.join("APPLIANCE.json") {
        return Err(err(
            "engine.materialization must name checkout/APPLIANCE.json",
        ));
    }
    admit("engine.materialization", artifact)?;
    let mut bytes = Vec::new();
    std::fs::File::open(&artifact.path)
        .map_err(|e| err(e.to_string()))?
        .take(64 * 1024 * 1024 + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| err(e.to_string()))?;
    if bytes.len() > 64 * 1024 * 1024 {
        return Err(err("materialization receipt exceeds 64 MiB"));
    }
    let receipt = crate::wire::parse(&bytes).map_err(|e| err(e.0))?;
    if receipt["schema"] != json!(1) || receipt["source_revision"] != settings.revision {
        return Err(err("materialization schema or source revision mismatch"));
    }
    let files = receipt["files"]
        .as_object()
        .ok_or_else(|| err("materialization files missing"))?;
    if files.is_empty() || files.len() > 200_000 || !files.contains_key("oracle7.py") {
        return Err(err("materialization file inventory invalid"));
    }
    let stores: BTreeSet<&str> = receipt["stores"]
        .as_array()
        .ok_or_else(|| err("materialization stores missing"))?
        .iter()
        .filter_map(|s| s["path"].as_str())
        .collect();
    let mut seen = BTreeSet::new();
    let mut dirs = vec![settings.checkout.clone()];
    let mut entries = 0usize;
    while let Some(dir) = dirs.pop() {
        for entry in
            std::fs::read_dir(&dir).map_err(|e| err(format!("materialization directory: {e}")))?
        {
            let entry = entry.map_err(|e| err(e.to_string()))?;
            entries += 1;
            if entries > 400_000 {
                return Err(err("materialization directory entry limit"));
            }
            let path = entry.path();
            let relative = path
                .strip_prefix(&settings.checkout)
                .map_err(|e| err(e.to_string()))?
                .to_str()
                .ok_or_else(|| err("materialization non-UTF8 path"))?
                .to_owned();
            let kind = entry.file_type().map_err(|e| err(e.to_string()))?;
            if kind.is_dir() {
                dirs.push(path);
                continue;
            }
            if relative == "APPLIANCE.json" && kind.is_file() {
                continue;
            }
            let record = files
                .get(&relative)
                .ok_or_else(|| err(format!("materialization unlisted file: {relative}")))?;
            if !kind.is_file() && !(kind.is_symlink() && stores.contains(relative.as_str())) {
                return Err(err(format!(
                    "materialization unsupported file type: {relative}"
                )));
            }
            let metadata = std::fs::metadata(&path).map_err(|e| err(e.to_string()))?;
            let hash = record["sha256"]
                .as_str()
                .filter(|s| is_hash(s))
                .ok_or_else(|| err("invalid materialization file hash"))?;
            if !metadata.is_file()
                || record["size"].as_u64() != Some(metadata.len())
                || record["executable"].as_bool()
                    != Some(metadata.permissions().mode() & 0o111 != 0)
                || sha256_file(&path).map_err(|e| err(e.to_string()))? != hash
            {
                return Err(err(format!("materialization file mismatch: {relative}")));
            }
            seen.insert(relative);
        }
    }
    if seen.len() != files.len() || !files.keys().all(|name| seen.contains(name)) {
        return Err(err(
            "materialization inventory has missing or invalid paths",
        ));
    }
    if let Some(specialist) = &settings.specialist {
        let relative = specialist
            .strip_prefix(&settings.checkout)
            .map_err(|_| err("materialized specialist must be inside checkout"))?;
        if relative
            .components()
            .any(|c| !matches!(c, std::path::Component::Normal(_)))
        {
            return Err(err("invalid materialized specialist path"));
        }
    }
    Ok(
        json!({"mode": "materialized", "revision": settings.revision,
        "receipt_sha256": artifact.sha256, "contents_verified": true, "files": files.len()}),
    )
}

/// After admit_engine_checkout, admit exact public artifact bytes before workers.
/// The Python worker independently checks Python/options and source identity before decoding pickle.
/// Admission is not a write lock: operator-protected immutable custody is required.
pub fn admit_engine_prepared(settings: &EngineConfig) -> Result<Option<Value>, ConfigError> {
    let Some(prepared) = &settings.prepared else {
        return Ok(None);
    };
    if !(1..=8).contains(&prepared.replacement_attempts)
        || !(1..=60_000).contains(&prepared.replacement_backoff_ms)
    {
        return Err(err("engine.prepared: invalid bounded replacement policy"));
    }
    let source = settings
        .materialization
        .as_ref()
        .ok_or_else(|| err("engine.prepared requires admitted materialization"))?;
    if settings.revision != "c473d28914e480425adb29b4f7f42485b8cfb4e3"
        || settings
            .tip
            .as_deref()
            .is_some_and(|t| t != "oracle_release_runtime_w574")
    {
        return Err(err("engine.prepared requires exact U8 w574 source"));
    }
    // Caller must first admit_engine_checkout, including actual shared store bytes.
    admit("engine.materialization", source)?;
    let receipt = crate::wire::parse(&std::fs::read(&source.path).map_err(|e| err(e.to_string()))?)
        .map_err(|e| err(e.0))?;
    if receipt["prepared_source"]["mode"] != "isolated_prepared_u8_w574"
        || receipt["prepared_source"]["baseline_appliance_sha256"]
            != "97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5"
        || !receipt["patches"].as_array().is_some_and(|rows| {
            rows.iter().any(|r| {
                r["sha256"] == "c3f4de2ea8d1a6ff039786668cba8c730943a5649db784364b1745d03d0ef2d8"
            })
        })
    {
        return Err(err("engine.prepared: unsupported patched materialization"));
    }
    let artifact = &prepared.artifact;
    absolute("engine.prepared.artifact", &artifact.path)?;
    if artifact.path.file_name().and_then(|s| s.to_str()) != Some("MANIFEST.json") {
        return Err(err("engine.prepared.artifact must name MANIFEST.json"));
    }
    let root = artifact
        .path
        .parent()
        .ok_or_else(|| err("prepared artifact root missing"))?;
    fn resolve_location(path: &Path) -> std::io::Result<PathBuf> {
        if path.exists() {
            return std::fs::canonicalize(path);
        }
        let parent = path
            .parent()
            .ok_or_else(|| std::io::Error::other("no path parent"))?;
        let name = path
            .file_name()
            .ok_or_else(|| std::io::Error::other("invalid path name"))?;
        Ok(resolve_location(parent)?.join(name))
    }
    let public_location = resolve_location(root).map_err(|e| err(e.to_string()))?;
    let checkout_location = resolve_location(&settings.checkout).map_err(|e| err(e.to_string()))?;
    let state_location = resolve_location(&settings.state).map_err(|e| err(e.to_string()))?;
    if public_location.starts_with(&checkout_location)
        || checkout_location.starts_with(&public_location)
        || public_location.starts_with(&state_location)
        || state_location.starts_with(&public_location)
    {
        return Err(err(
            "prepared artifact, checkout and private state must be disjoint",
        ));
    }
    fn regular(path: &Path) -> Result<std::fs::Metadata, ConfigError> {
        for part in path.ancestors() {
            if part
                .components()
                .any(|c| matches!(c, std::path::Component::ParentDir))
                || std::fs::symlink_metadata(part)
                    .map_err(|e| err(e.to_string()))?
                    .file_type()
                    .is_symlink()
            {
                return Err(err("prepared artifact symlink/traversal refused"));
            }
        }
        let m = std::fs::metadata(path).map_err(|e| err(e.to_string()))?;
        if !m.is_file() {
            return Err(err("prepared artifact must be regular"));
        }
        Ok(m)
    }
    if regular(&artifact.path)?.len() > 2 * 1024 * 1024 {
        return Err(err("prepared manifest exceeds 2 MiB"));
    }
    let mut raw = Vec::new();
    std::fs::File::open(&artifact.path)
        .map_err(|e| err(e.to_string()))?
        .take(2 * 1024 * 1024 + 1)
        .read_to_end(&mut raw)
        .map_err(|e| err(e.to_string()))?;
    if raw.len() > 2 * 1024 * 1024
        || !is_hash(&artifact.sha256)
        || sha256_bytes(&raw) != artifact.sha256
    {
        return Err(err("prepared manifest digest/size mismatch"));
    }
    let manifest = crate::wire::parse(&raw).map_err(|e| err(e.0))?;
    if manifest.as_object().map(|o| o.len()) != Some(4)
        || manifest["schema"] != "oracle-public-reader-preparation-v1"
        || manifest["identity"]["materialization_sha256"] != source.sha256
        || manifest["identity"]["hash_seed"] != "0"
    {
        return Err(err("prepared manifest source/schema mismatch"));
    }
    let expected_sources: serde_json::Map<String, Value> = receipt["files"]
        .as_object()
        .ok_or_else(|| err("source inventory missing"))?
        .iter()
        .filter(|(name, _)| name.starts_with("workbench/swarm/") && name.ends_with(".py"))
        .map(|(name, row)| (name.clone(), row["sha256"].clone()))
        .collect();
    if expected_sources.is_empty()
        || !expected_sources.contains_key("workbench/swarm/runtime_preparation.py")
        || manifest["identity"]["source_sha256"] != Value::Object(expected_sources)
    {
        return Err(err("prepared reader source closure mismatch"));
    }
    for name in ["train.json", "kb.json"] {
        let expected = &receipt["files"][format!("root/organs10/kqa/{name}")]["sha256"];
        if !expected.as_str().is_some_and(is_hash)
            || manifest["identity"]["data_sha256"][name] != *expected
        {
            return Err(err("prepared public data identity mismatch"));
        }
    }
    let files = manifest["files"]
        .as_object()
        .ok_or_else(|| err("prepared files missing"))?;
    if files.len() != 2 {
        return Err(err("prepared requires exact reader/clause pair"));
    }
    let mut reader = 0;
    let mut clause = 0;
    for (name, row) in files {
        let valid = |prefix: &str, digits: usize| {
            name.strip_prefix(prefix)
                .and_then(|n| n.strip_suffix(".pickle"))
                .is_some_and(|n| {
                    n.len() == digits
                        && n.bytes()
                            .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
                })
        };
        if valid("reader90_", 24) {
            reader += 1;
        } else if valid("clause101_", 20) {
            clause += 1;
        } else {
            return Err(err("invalid prepared filename"));
        }
        let size = row["bytes"]
            .as_u64()
            .filter(|n| *n > 0 && *n <= 512 * 1024 * 1024)
            .ok_or_else(|| err("invalid prepared payload size"))?;
        let hash = row["sha256"]
            .as_str()
            .filter(|s| is_hash(s))
            .ok_or_else(|| err("invalid prepared hash"))?;
        let path = root.join(name);
        if row.as_object().map(|o| o.len()) != Some(2)
            || regular(&path)?.len() != size
            || sha256_file(&path).map_err(|e| err(e.to_string()))? != hash
        {
            return Err(err("prepared payload size/hash mismatch"));
        }
    }
    if reader != 1 || clause != 1 {
        return Err(err("prepared pair mismatch"));
    }
    let names: std::collections::BTreeSet<_> = std::fs::read_dir(root)
        .map_err(|e| err(e.to_string()))?
        .map(|r| r.map(|e| e.file_name().to_string_lossy().into_owned()))
        .collect::<Result<_, _>>()
        .map_err(|e| err(e.to_string()))?;
    let mut expected: std::collections::BTreeSet<_> = files.keys().cloned().collect();
    expected.insert("MANIFEST.json".into());
    if names != expected {
        return Err(err("unexpected prepared artifact entry"));
    }
    Ok(Some(
        json!({"mode":"prepared_u8_w574", "manifest_sha256":artifact.sha256,
        "materialization_sha256":source.sha256,"custody":"operator_protected_immutable"}),
    ))
}

pub fn read(path: &Path) -> Result<Config, ConfigError> {
    absolute("config", path)?;
    let file = std::fs::File::open(path).map_err(|e| err(format!("config: {e}")))?;
    let mut raw = Vec::new();
    file.take(MAX_CONFIG_BYTES + 1)
        .read_to_end(&mut raw)
        .map_err(|e| err(format!("config: {e}")))?;
    if raw.len() as u64 > MAX_CONFIG_BYTES {
        return Err(err("config exceeds 8 MiB"));
    }
    // Strict decoding first (duplicate keys refused), then typed fields.
    let value = crate::wire::parse(&raw).map_err(|e| err(format!("config: {}", e.0)))?;
    let config: Config = serde_json::from_value(value).map_err(|e| err(format!("config: {e}")))?;
    if config.schema != SCHEMA {
        return Err(err(format!("config: schema must be {SCHEMA}")));
    }
    let limits = &config.limits;
    if limits.capacity == 0
        || limits.capacity > 256
        || limits.connections < limits.capacity
        || limits.connections > 1024
        || limits.request_bytes == 0
        || limits.reply_bytes < 1024
        || limits.ingress_ms == 0
        || limits.invoke_ms == 0
        || limits.query_ms == 0
        || limits.execution_fuel == 0
        || limits.request_memory_bytes == 0
        || limits
            .tenant_capacity
            .is_some_and(|n| n == 0 || n > limits.capacity)
        || limits.retained_requests == 0
        || limits.conversations == 0
    {
        return Err(err("config: invalid limits"));
    }
    absolute("journal", &config.journal)?;
    if config.native.is_none()
        && config.kernels.is_none()
        && config.engine.is_none()
        && config.pure.is_none()
    {
        return Err(err("config: at least one provider is required"));
    }
    Ok(config)
}
