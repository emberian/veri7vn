//! Operator configuration. Every artifact is named by an absolute path and the
//! SHA-256 of its bytes; nothing here can come from a request. Unknown fields
//! fail startup rather than being ignored.

use serde::Deserialize;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::io::Read;
use std::path::{Path, PathBuf};

pub const SCHEMA: &str = "oracle-host-v1";
const MAX_CONFIG_BYTES: u64 = 8 * 1024 * 1024;

#[derive(Debug, Deserialize)]
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
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PureConfig {
    pub profiles: Vec<String>,
    /// Operator-admitted clingo for the `logic` profile, and only for it.
    pub solver: Option<Artifact>,
}

fn default_port() -> u16 {
    7071
}

#[derive(Debug, Deserialize, Clone)]
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

#[derive(Debug, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Artifact {
    pub path: PathBuf,
    pub sha256: String,
}

#[derive(Debug, Deserialize)]
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

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReleaseConfig {
    /// Exact JSON text; numbers are never re-rendered.
    pub manifest_json: String,
    pub identity: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct KernelsConfig {
    #[serde(default)]
    pub limits: Value,
    pub organs: Vec<OrganConfig>,
}

#[derive(Debug, Deserialize, Clone)]
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

#[derive(Debug, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Acceptance {
    pub kinds: Vec<String>,
    #[serde(default)]
    pub declines_in_domain: Vec<String>,
    pub context_regex: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct EngineConfig {
    pub python: Artifact,
    /// `tools/parity/answerers/oracle7.py` (the answerer contract driver).
    pub answerer: Artifact,
    /// The upstream checkout and the git revision its HEAD must name.
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
