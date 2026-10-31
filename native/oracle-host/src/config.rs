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
    /// Open connections, including ones still sending headers or body.
    pub connections: usize,
    pub request_bytes: usize,
    pub reply_bytes: usize,
    /// Absolute deadline for headers plus body, as the reference server.
    pub ingress_ms: u64,
    /// Wall deadline for one `/invoke` call; the slot stays occupied until the
    /// work actually stops.
    pub invoke_ms: u64,
    /// Retained `/query` request records before the journal refuses (507).
    pub retained_requests: u64,
    /// Remembered (tenant, conversation) Engine bindings before refusing (507).
    pub conversations: u64,
}

impl Default for HostLimits {
    fn default() -> Self {
        Self {
            capacity: 2,
            connections: 16,
            request_bytes: 1024 * 1024,
            reply_bytes: 2 * 1024 * 1024,
            ingress_ms: 5000,
            invoke_ms: 30_000,
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
    /// A pinned provisioner receipt admits the materialized tree without Git.
    #[serde(default)]
    pub materialization: Option<Artifact>,
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
        for field in ["python", "answerer", "materialization"] {
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
