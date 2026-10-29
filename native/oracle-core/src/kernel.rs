//! Bounded transport for operator-admitted, stateless extracted specialists.
//!
//! This is untrusted process/framing code, not a Rust reimplementation or a new
//! proof. Acoustics/quantity use JSONL. The MST certificate uses its fixed
//! bounded ASCII line protocol. All are resident and stateless across requests;
//! specialist session fields are ignored. Stateful families are not admitted.
//! A digest binds the bytes copied at admission; it does not attest a build,
//! theorem, parser, manifest acceptance rule, or answer's correctness.
//!
//! Unix children have their own process group and nonblocking pipes. Only that
//! owned group is killed. Every I/O thread is joined before releasing a slot.
//! Process creation/reaping and filesystem I/O remain OS operations, not hard
//! real-time deadlines. Host process/memory limits are still necessary.

use crate::{Budget, Cancellation, Error, Limits, Result};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, HashSet};
use std::fs::File;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};
use tempfile::TempPath;

const POLL: Duration = Duration::from_millis(2);

/// The variants fix argv and explicitly delimit the stateless protocol audit.
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case", deny_unknown_fields)]
pub enum KernelFamily {
    Acoustics,
    /// Bounded ASCII occurrence-ID certificate protocol, not a question answerer.
    MstCertificate,
    Quantity {
        specialist: Option<QuantitySpecialist>,
    },
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum QuantitySpecialist {
    Densities,
    Units,
    UnitsV3,
    Springs,
    Fluids,
    Fuels,
}
impl QuantitySpecialist {
    fn argument(&self) -> &'static str {
        match self {
            Self::Densities => "densities",
            Self::Units => "units",
            Self::UnitsV3 => "units-v3",
            Self::Springs => "springs",
            Self::Fluids => "fluids",
            Self::Fuels => "fuels",
        }
    }
}

/// Only authenticated hosting code constructs these. Never deserialize caller
/// input into deployment configuration. No arbitrary argv, cwd or env exists.
#[derive(Clone, Debug)]
pub struct KernelDescriptor {
    id: String,
    executable: PathBuf,
    sha256: String,
    family: KernelFamily,
    compiled_receipt: Option<(PathBuf, String)>,
}
impl KernelDescriptor {
    pub fn new(
        id: impl Into<String>,
        executable: impl Into<PathBuf>,
        trusted_sha256: impl Into<String>,
        family: KernelFamily,
    ) -> Self {
        Self {
            id: id.into(),
            executable: executable.into(),
            sha256: trusted_sha256.into(),
            family,
            compiled_receipt: None,
        }
    }

    /// Operator-approved compiler receipt and its trusted digest, never tenant
    /// input. Admission checks the receipt's binary/proof/export bindings.
    pub fn with_compiled_receipt(
        mut self,
        path: impl Into<PathBuf>,
        sha256: impl Into<String>,
    ) -> Self {
        self.compiled_receipt = Some((path.into(), sha256.into()));
        self
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct KernelLimits {
    pub workers: usize,
    pub registry_entries: usize,
    pub executable_bytes: u64,
    pub request_bytes: usize,
    pub reply_bytes: usize,
    /// Per resident process lifetime; content is drained, never retained.
    pub stderr_bytes: usize,
    pub timeout_ms: u64,
}
impl Default for KernelLimits {
    fn default() -> Self {
        Self {
            workers: 2,
            registry_entries: 32,
            executable_bytes: 32 * 1024 * 1024,
            request_bytes: 65536,
            reply_bytes: 2 * 1024 * 1024,
            stderr_bytes: 65536,
            timeout_ms: 5000,
        }
    }
}

/// Observed admission of bytes, not a manifest's declaration of availability.
#[derive(Clone, Debug, Serialize)]
pub struct KernelAdmission {
    pub id: String,
    pub family: KernelFamily,
    pub executable_sha256: String,
    pub executable_bytes: u64,
    /// Present only after checking an operator-admitted compiled proof receipt.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub compiled_receipt_sha256: Option<String>,
}
struct Admitted {
    receipt: KernelAdmission,
    // Private copy avoids a check/exec race when the source path is replaced.
    executable: TempPath,
}

#[derive(Clone, Debug, Serialize)]
pub struct KernelReply {
    /// The complete reply, including the producer's unmodified evidence fields.
    pub reply: Value,
    pub admission: KernelAdmission,
    /// Owned resident PID, for host reuse/retirement diagnostics.
    pub worker_pid: u32,
}

/// Complete supplied graph. Edge IDs index this exact, ordered multigraph.
/// Signed weights deserialize as i64; fractions, booleans and overflow fail.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct MstGraph {
    pub vertices: usize,
    pub edges: Vec<(usize, usize, i64)>,
}
impl MstGraph {
    pub fn validate_candidate(&self, ids: &[usize]) -> Result<usize> {
        if self.vertices > 64
            || self.edges.len() > 256
            || ids.len() > self.vertices.saturating_sub(1)
        {
            return Err(Error::Limit("MST certificate graph/candidate size"));
        }
        let mut parent: Vec<_> = (0..self.vertices).collect();
        fn root(parent: &[usize], mut i: usize) -> usize {
            while parent[i] != i {
                i = parent[i];
            }
            i
        }
        for &(a, b, _) in &self.edges {
            if a >= self.vertices || b >= self.vertices {
                return Err(Error::Invalid(
                    "edge endpoint outside declared vertices".into(),
                ));
            }
            let x = root(&parent, a);
            let y = root(&parent, b);
            parent[x] = y;
        }
        let mut seen = HashSet::new();
        if ids
            .iter()
            .any(|&i| i >= self.edges.len() || !seen.insert(i))
        {
            return Err(Error::Invalid("unknown/repeated candidate edge ID".into()));
        }
        Ok((0..self.vertices)
            .map(|v| root(&parent, v))
            .collect::<HashSet<_>>()
            .len())
    }
}

struct Slot {
    worker: Option<Worker>,
    poisoned: bool,
}

/// One fixed process pool shared by all logical tenants. Admission is immediate:
/// busy callers do not queue or start threads. Idle slots retain a resident;
/// changing its registered kernel retires it before starting the replacement.
pub struct KernelExecutor {
    registry: BTreeMap<String, Admitted>,
    slots: Vec<Mutex<Slot>>,
    tenants: Mutex<HashSet<String>>,
    active: AtomicUsize,
    sequence: AtomicU64,
    limits: KernelLimits,
}
impl KernelExecutor {
    pub fn new(descriptors: Vec<KernelDescriptor>, limits: KernelLimits) -> Result<Self> {
        if limits.workers == 0
            || limits.registry_entries == 0
            || limits.executable_bytes == 0
            || limits.request_bytes == 0
            || limits.reply_bytes == 0
            || limits.stderr_bytes == 0
            || limits.timeout_ms == 0
            || descriptors.len() > limits.registry_entries
        {
            return Err(Error::Invalid("invalid kernel limits/registry size".into()));
        }
        if !cfg!(unix) {
            return Err(Error::Invalid(
                "kernel process containment requires Unix".into(),
            ));
        }
        let mut registry = BTreeMap::new();
        for descriptor in descriptors {
            if !valid_id(&descriptor.id) || registry.contains_key(&descriptor.id) {
                return Err(Error::Invalid("invalid/duplicate kernel identity".into()));
            }
            let admitted = admit(descriptor, &limits)?;
            registry.insert(admitted.receipt.id.clone(), admitted);
        }
        Ok(Self {
            registry,
            slots: (0..limits.workers)
                .map(|_| {
                    Mutex::new(Slot {
                        worker: None,
                        poisoned: false,
                    })
                })
                .collect(),
            tenants: Mutex::new(HashSet::new()),
            active: AtomicUsize::new(0),
            sequence: AtomicU64::new(0),
            limits,
        })
    }

    pub fn admissions(&self) -> Vec<KernelAdmission> {
        self.registry.values().map(|k| k.receipt.clone()).collect()
    }
    pub fn active_workers(&self) -> usize {
        self.active.load(Ordering::Acquire)
    }

    pub fn execute(
        &self,
        tenant: &str,
        kernel_id: &str,
        question: &str,
        cancellation: Cancellation,
    ) -> Result<KernelReply> {
        let budget = Budget::new(
            &Limits {
                timeout_ms: self.limits.timeout_ms,
                ..Limits::default()
            },
            cancellation,
        )?;
        self.execute_with_budget(tenant, kernel_id, question, &budget)
    }

    /// Lets a composed request retain its original deadline/cancellation.
    pub fn execute_with_budget(
        &self,
        tenant: &str,
        kernel_id: &str,
        question: &str,
        budget: &Budget,
    ) -> Result<KernelReply> {
        budget.check()?;
        let deadline = Instant::now()
            .checked_add(Duration::from_millis(self.limits.timeout_ms))
            .ok_or_else(|| Error::Invalid("kernel deadline overflow".into()))?;
        if !valid_id(tenant) {
            return Err(Error::Invalid("invalid kernel tenant identity".into()));
        }
        let admitted = self
            .registry
            .get(kernel_id)
            .ok_or_else(|| Error::Invalid("unregistered kernel identity".into()))?;
        // Check before encoding: JSON escaping can enlarge this by at most 6x;
        // the exact complete envelope is bounded by the capped writer below.
        if question.len() > self.limits.request_bytes {
            return Err(Error::Limit("kernel request bytes"));
        }
        let id = self
            .sequence
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| n.checked_add(1))
            .map_err(|_| Error::Limit("kernel request ids"))?;
        if admitted.receipt.family == KernelFamily::MstCertificate {
            return Err(Error::Invalid(
                "use check_mst for certificate kernels".into(),
            ));
        }
        let request = json!({"id": id, "q": question, "session": "native-stateless"});
        let mut encoded = CappedWriter {
            bytes: Vec::new(),
            cap: self.limits.request_bytes,
        };
        serde_json::to_writer(&mut encoded, &request)
            .map_err(|_| Error::Limit("kernel request bytes"))?;
        encoded
            .write_all(b"\n")
            .map_err(|_| Error::Limit("kernel request bytes"))?;
        self.execute_wire(
            tenant,
            kernel_id,
            admitted,
            encoded.bytes,
            id,
            budget,
            deadline,
            None,
        )
    }

    /// Start one deadline before composing a native producer and checker.
    pub fn request_budget(&self, cancellation: Cancellation) -> Result<Budget> {
        Budget::new(
            &Limits {
                timeout_ms: self.limits.timeout_ms,
                ..Limits::default()
            },
            cancellation,
        )
    }

    pub fn check_mst(
        &self,
        tenant: &str,
        kernel_id: &str,
        graph: &MstGraph,
        ids: &[usize],
        cancellation: Cancellation,
    ) -> Result<KernelReply> {
        let budget = Budget::new(
            &Limits {
                timeout_ms: self.limits.timeout_ms,
                ..Limits::default()
            },
            cancellation,
        )?;
        self.check_mst_with_budget(tenant, kernel_id, graph, ids, &budget)
    }

    /// Uses the same bounded leases, snapshot, I/O, and cleanup as specialists.
    /// Candidate production may pass its original budget through this method.
    pub fn check_mst_with_budget(
        &self,
        tenant: &str,
        kernel_id: &str,
        graph: &MstGraph,
        ids: &[usize],
        budget: &Budget,
    ) -> Result<KernelReply> {
        budget.check()?;
        let components = graph.validate_candidate(ids)?;
        let admitted = self
            .registry
            .get(kernel_id)
            .ok_or_else(|| Error::Invalid("unregistered kernel identity".into()))?;
        if admitted.receipt.family != KernelFamily::MstCertificate || !valid_id(tenant) {
            return Err(Error::Invalid(
                "MST certificate family/tenant mismatch".into(),
            ));
        }
        let deadline = Instant::now()
            .checked_add(Duration::from_millis(self.limits.timeout_ms))
            .ok_or_else(|| Error::Invalid("kernel deadline overflow".into()))?;
        let id = self
            .sequence
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| n.checked_add(1))
            .map_err(|_| Error::Limit("kernel request ids"))?;
        let mut text = format!(
            "mst-cert-v2 {id} {} {} {}",
            graph.vertices,
            graph.edges.len(),
            ids.len()
        );
        use std::fmt::Write as _;
        for &(a, b, w) in &graph.edges {
            write!(&mut text, " {a} {b} {w}").expect("String writer");
        }
        for i in ids {
            write!(&mut text, " {i}").expect("String writer");
        }
        text.push('\n');
        if text.len() > self.limits.request_bytes.min(65536) {
            return Err(Error::Limit("kernel request bytes"));
        }
        let mut result = self.execute_wire(
            tenant,
            kernel_id,
            admitted,
            text.into_bytes(),
            id,
            budget,
            deadline,
            Some(graph.vertices >= 2 && components == 1),
        )?;
        // Bind outcomes to the complete supplied universe, independently of the
        // producer. Never allow an unsupported graph to inherit the tree scope.
        let supported = graph.vertices >= 2 && components == 1;
        let status = result.reply["status"]
            .as_str()
            .expect("validated status")
            .to_owned();
        if (status == "unsupported") == supported {
            // Defense in depth: exchange checks this before releasing its lease.
            return Err(Error::Format("certificate scope mismatch".into()));
        }
        result.reply["vertices"] = json!(graph.vertices);
        result.reply["edges"] = json!(graph.edges.len());
        result.reply["components"] = json!(components);
        result.reply["edge_ids"] = json!(ids);
        result.reply["total_weight"] = json!(ids
            .iter()
            .map(|&i| i128::from(graph.edges[i].2))
            .sum::<i128>()
            .to_string());
        result.reply["input_sha256"] = json!(crate::digest(&serde_json::to_vec(
            &json!({"graph":graph,"edge_ids":ids})
        )?));
        result.reply["evidence"] = if status == "accepted"
            && admitted.receipt.compiled_receipt_sha256.is_some()
        {
            json!({"kind":"extracted_hol_connected_mst", "scope":"connected_mst_only",
                "predicate":"Mst_Certificate_Export.external_mst_cert",
                "session":"Veri7vn_Discrete_Certificate",
                "theorems":["Mst_Certificate_Export.external_mst_cert_spans", "Mst_Certificate_Export.external_mst_cert_minimal"],
                "compiled_receipt_sha256":admitted.receipt.compiled_receipt_sha256,
                "checker_sha256":admitted.receipt.executable_sha256,
                "trust":"operator-admitted compiler receipt; JSON/framing/compiler remain untrusted"})
        } else {
            json!({"kind":"none", "predicate_outcome":status,
                "reason":"HOL scope requires acceptance and an operator-admitted compiled receipt"})
        };
        Ok(result)
    }

    #[allow(clippy::too_many_arguments)]
    fn execute_wire(
        &self,
        tenant: &str,
        kernel_id: &str,
        admitted: &Admitted,
        request: Vec<u8>,
        id: u64,
        budget: &Budget,
        deadline: Instant,
        expected_mst_supported: Option<bool>,
    ) -> Result<KernelReply> {
        {
            let mut tenants = crate::lock(&self.tenants)?;
            if tenants.len() >= self.limits.workers || !tenants.insert(tenant.to_owned()) {
                return Err(Error::Busy);
            }
        }
        let _tenant = TenantLease {
            executor: self,
            tenant,
        };
        let mut any_poisoned = false;
        for slot in &self.slots {
            let mut slot = match slot.try_lock() {
                Ok(slot) => slot,
                Err(std::sync::TryLockError::WouldBlock) => continue,
                Err(std::sync::TryLockError::Poisoned(_)) => {
                    any_poisoned = true;
                    continue;
                }
            };
            if slot.poisoned {
                any_poisoned = true;
                continue;
            }
            self.active.fetch_add(1, Ordering::AcqRel);
            let _active = ActiveLease(&self.active);
            let result = (|| {
                budget.check()?;
                if slot
                    .worker
                    .as_ref()
                    .is_some_and(|w| w.kernel_id != kernel_id)
                {
                    retire(&mut slot)?;
                }
                if slot.worker.is_none() {
                    slot.worker = Some(Worker::start(admitted, &self.limits, budget, deadline)?);
                }
                let worker = slot.worker.as_mut().expect("worker just started");
                let reply = worker.exchange(
                    request,
                    id,
                    budget,
                    deadline,
                    &admitted.receipt.family,
                    expected_mst_supported,
                )?;
                Ok(KernelReply {
                    reply,
                    admission: admitted.receipt.clone(),
                    worker_pid: worker.child.as_ref().expect("owned live child").id(),
                })
            })();
            if result.is_err() {
                // A failed/cancelled exchange must never leave a stale reply for
                // the next tenant. Cleanup stays within this exclusive lease.
                retire(&mut slot)?;
            }
            return result;
        }
        if any_poisoned {
            Err(Error::Poisoned)
        } else {
            Err(Error::Busy)
        }
    }
}

fn parse_mst_reply(bytes: &[u8], id: u64) -> Result<Value> {
    for (wire, status) in [
        ("accept", "accepted"),
        ("reject", "rejected"),
        ("unsupported", "unsupported"),
    ] {
        if bytes == format!("mst-cert-v2 {id} {wire}\n").as_bytes() {
            return Ok(
                json!({"id":id,"status":status,"response":wire,"path":"certificate:external_mst_cert"}),
            );
        }
    }
    Err(Error::Format(
        "invalid/cross-request MST certificate reply".into(),
    ))
}

fn valid_id(id: &str) -> bool {
    !id.is_empty()
        && id.len() <= 160
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
}
struct TenantLease<'a> {
    executor: &'a KernelExecutor,
    tenant: &'a str,
}
impl Drop for TenantLease<'_> {
    fn drop(&mut self) {
        if let Ok(mut tenants) = self.executor.tenants.lock() {
            tenants.remove(self.tenant);
        }
    }
}
struct ActiveLease<'a>(&'a AtomicUsize);
impl Drop for ActiveLease<'_> {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::AcqRel);
    }
}
struct CappedWriter {
    bytes: Vec<u8>,
    cap: usize,
}
impl Write for CappedWriter {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        if bytes.len() > self.cap.saturating_sub(self.bytes.len()) {
            return Err(std::io::Error::other("kernel request exceeds byte bound"));
        }
        self.bytes.extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

fn admit(descriptor: KernelDescriptor, limits: &KernelLimits) -> Result<Admitted> {
    if !descriptor.executable.is_absolute()
        || descriptor.sha256.len() != 64
        || !descriptor
            .sha256
            .bytes()
            .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
    {
        return Err(Error::Invalid(
            "kernel requires absolute path and lowercase SHA-256".into(),
        ));
    }
    let mut source = File::open(&descriptor.executable)?;
    if !source.metadata()?.is_file() {
        return Err(Error::Invalid(
            "kernel executable is not a regular file".into(),
        ));
    }
    let mut snapshot = tempfile::Builder::new()
        .prefix("oracle-kernel-")
        .tempfile()?;
    let mut sha = Sha256::new();
    let mut total = 0u64;
    let mut buffer = [0u8; 16384];
    loop {
        let count = source.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        total = total
            .checked_add(count as u64)
            .ok_or(Error::Limit("kernel executable bytes"))?;
        if total > limits.executable_bytes {
            return Err(Error::Limit("kernel executable bytes"));
        }
        sha.update(&buffer[..count]);
        snapshot.write_all(&buffer[..count])?;
    }
    if total == 0 || format!("{:x}", sha.finalize()) != descriptor.sha256 {
        return Err(Error::Format(
            "kernel executable hash mismatch/empty file".into(),
        ));
    }
    snapshot.flush()?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        snapshot
            .as_file()
            .set_permissions(std::fs::Permissions::from_mode(0o500))?;
    }
    // Close the writable descriptor before exec (Linux otherwise rejects it).
    let (writable, executable) = snapshot.into_parts();
    drop(writable);
    drop(source);
    let compiled_receipt_sha256 = admit_compiled_receipt(&descriptor, total)?;
    Ok(Admitted {
        receipt: KernelAdmission {
            id: descriptor.id,
            family: descriptor.family,
            executable_sha256: descriptor.sha256,
            executable_bytes: total,
            compiled_receipt_sha256,
        },
        executable,
    })
}

// This checks deployment evidence, not a proof of compiler/framing correctness.
// The digest comes from an authenticated operator. A tenant cannot register its
// own executable/receipt or confer proof scope by returning JSON declarations.
fn admit_compiled_receipt(
    descriptor: &KernelDescriptor,
    binary_bytes: u64,
) -> Result<Option<String>> {
    let Some((path, expected)) = &descriptor.compiled_receipt else {
        return Ok(None);
    };
    if descriptor.family != KernelFamily::MstCertificate
        || !path.is_absolute()
        || !valid_sha256(expected)
    {
        return Err(Error::Invalid("invalid compiled receipt admission".into()));
    }
    let bytes = bounded_receipt(path)?;
    if crate::digest(&bytes) != *expected {
        return Err(Error::Format("compiled receipt hash mismatch".into()));
    }
    let record: Value = serde_json::from_slice(&bytes)?;
    let proof = &record["session_receipt"]["record"];
    let remote = &proof["remote"];
    let export = "Veri7vn_Discrete_Certificate.Mst_Certificate_Export/code/mst_certificate.ML";
    let generated = record["generated_sha256"].as_str().unwrap_or("");
    let driver = "src/extract/discrete-certificate/main.sml";
    let driver_sha = crate::digest(include_bytes!(
        "../../../src/extract/discrete-certificate/main.sml"
    ));
    if record["schema_version"] != 1
        || record["compile_ok"] != true
        || record["compiler_exit"] != 0
        || record["family"] != "discrete-certificate"
        || record["session"] != "Veri7vn_Discrete_Certificate"
        || record["binary_sha256"] != descriptor.sha256
        || record["binary_bytes"] != binary_bytes
        || record["generated_export"] != export
        || !valid_sha256(generated)
        || proof["export_sha256"][export] != generated
        || record["source_sha256"][driver] != driver_sha
        || !record["proof_dependency_sha256"]
            .as_object()
            .is_some_and(|m| !m.is_empty())
        || proof["status"] != "passed"
        || proof["exit_code"] != 0
        || proof["session"] != "Veri7vn_Discrete_Certificate"
        || proof["expect"] != "VERI7VN_DISCRETE_CERTIFICATE PASS theorems=4 oracles=0"
        || remote["exit_code"] != 0
        || remote.get("cancelled").is_some_and(|v| v != false)
        || proof["source_digest"]
            .as_str()
            .is_none_or(|v| !valid_sha256(v))
        || proof["source_digest"] != remote["source_digest"]
        || (remote.get("build_completed").is_some()
            && (remote["build_completed"] != true || remote["build_exit"] != 0))
    {
        return Err(Error::Format(
            "compiled MST receipt does not bind admitted binary, driver and passed proof export"
                .into(),
        ));
    }
    let proof_path = record["session_receipt"]["path"]
        .as_str()
        .ok_or_else(|| Error::Format("missing proof receipt path".into()))?;
    let proof_bytes = bounded_receipt(Path::new(proof_path))?;
    let proof_sha = record["session_receipt"]["sha256"].as_str().unwrap_or("");
    if !Path::new(proof_path).is_absolute()
        || !valid_sha256(proof_sha)
        || crate::digest(&proof_bytes) != proof_sha
        || serde_json::from_slice::<Value>(&proof_bytes)? != *proof
    {
        return Err(Error::Format(
            "compiled/proof receipt binding mismatch".into(),
        ));
    }
    Ok(Some(expected.clone()))
}
fn valid_sha256(text: &str) -> bool {
    text.len() == 64
        && text
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
fn bounded_receipt(path: &Path) -> Result<Vec<u8>> {
    let source = File::open(path)?;
    if !source.metadata()?.is_file() {
        return Err(Error::Invalid("receipt must be a regular file".into()));
    }
    let mut bytes = Vec::new();
    source.take(1024 * 1024 + 1).read_to_end(&mut bytes)?;
    if bytes.len() > 1024 * 1024 {
        return Err(Error::Limit("compiled receipt bytes"));
    }
    Ok(bytes)
}

fn retire(slot: &mut Slot) -> Result<()> {
    if let Some(mut worker) = slot.worker.take() {
        if let Err(error) = worker.shutdown() {
            slot.poisoned = true;
            return Err(error);
        }
    }
    Ok(())
}

enum Output {
    Line(Vec<u8>),
    Limit,
    Eof,
    Io(std::io::Error),
}
struct Worker {
    kernel_id: String,
    child: Option<Child>,
    stop: Arc<AtomicBool>,
    stderr_overflow: Arc<AtomicBool>,
    input: Option<mpsc::SyncSender<Vec<u8>>>,
    written: mpsc::Receiver<std::io::Result<()>>,
    output: mpsc::Receiver<Output>,
    threads: Vec<JoinHandle<()>>,
}
impl Worker {
    #[cfg(unix)]
    fn start(
        admitted: &Admitted,
        limits: &KernelLimits,
        budget: &Budget,
        deadline: Instant,
    ) -> Result<Self> {
        use std::os::unix::process::CommandExt;
        let mut command = Command::new(Path::new(&admitted.executable));
        command
            .env_clear()
            .current_dir("/")
            .process_group(0)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        if let KernelFamily::Quantity {
            specialist: Some(specialist),
        } = &admitted.receipt.family
        {
            command.args(["--specialist", specialist.argument()]);
        }
        // The writable snapshot handle was closed at admission. A concurrent
        // fork can nevertheless briefly inherit that CLOEXEC handle before its
        // own exec closes it. Linux reports ETXTBSY during that interval. Retry
        // only this transient condition, under the original request bounds.
        let child = loop {
            budget.check()?;
            if Instant::now() >= deadline {
                return Err(Error::Deadline);
            }
            match command.spawn() {
                Ok(child) => break child,
                Err(error) if error.raw_os_error() == Some(nix::errno::Errno::ETXTBSY as i32) => {
                    thread::sleep(POLL)
                }
                Err(error) => return Err(error.into()),
            }
        };
        let (send_input, receive_input) = mpsc::sync_channel::<Vec<u8>>(1);
        let (send_written, written) = mpsc::sync_channel(1);
        let (send_output, output) = mpsc::sync_channel(1);
        let mut worker = Self {
            kernel_id: admitted.receipt.id.clone(),
            child: Some(child),
            stop: Arc::new(AtomicBool::new(false)),
            stderr_overflow: Arc::new(AtomicBool::new(false)),
            input: Some(send_input),
            written,
            output,
            threads: Vec::new(),
        };
        let child = worker.child.as_mut().expect("owned child");
        let mut stdin = child.stdin.take().expect("piped stdin");
        let stdout = child.stdout.take().expect("piped stdout");
        let stderr = child.stderr.take().expect("piped stderr");
        nonblocking(&stdin)?;
        nonblocking(&stdout)?;
        nonblocking(&stderr)?;
        let stop = worker.stop.clone();
        worker
            .threads
            .push(
                thread::Builder::new()
                    .name("kernel-input".into())
                    .spawn(move || {
                        while let Ok(request) = receive_input.recv() {
                            let result = write_request(&mut stdin, &request, &stop);
                            let failed = result.is_err();
                            if !send_bounded(&send_written, result, &stop) || failed {
                                break;
                            }
                        }
                    })?,
            );
        let stop = worker.stop.clone();
        let cap = limits.reply_bytes;
        worker
            .threads
            .push(
                thread::Builder::new()
                    .name("kernel-output".into())
                    .spawn(move || {
                        read_output(stdout, cap, send_output, stop);
                    })?,
            );
        let stop = worker.stop.clone();
        let overflow = worker.stderr_overflow.clone();
        let cap = limits.stderr_bytes;
        worker
            .threads
            .push(
                thread::Builder::new()
                    .name("kernel-stderr".into())
                    .spawn(move || {
                        drain_stderr(stderr, cap, stop, overflow);
                    })?,
            );
        Ok(worker)
    }
    #[cfg(not(unix))]
    fn start(_: &Admitted, _: &KernelLimits, _: &Budget, _: Instant) -> Result<Self> {
        Err(Error::Invalid(
            "kernel process containment requires Unix".into(),
        ))
    }

    fn exchange(
        &mut self,
        request: Vec<u8>,
        id: u64,
        budget: &Budget,
        deadline: Instant,
        family: &KernelFamily,
        expected_mst_supported: Option<bool>,
    ) -> Result<Value> {
        self.input
            .as_ref()
            .expect("live worker input")
            .try_send(request)
            .map_err(|_| Error::Format("kernel input worker unavailable".into()))?;
        let mut write_done = false;
        let mut reply = None;
        loop {
            budget.check()?;
            if Instant::now() >= deadline {
                return Err(Error::Deadline);
            }
            if self.stderr_overflow.load(Ordering::Acquire) {
                return Err(Error::Limit("kernel stderr bytes"));
            }
            if !write_done {
                match self.written.try_recv() {
                    Ok(result) => {
                        result?;
                        write_done = true;
                    }
                    Err(mpsc::TryRecvError::Empty) => (),
                    Err(_) => return Err(Error::Format("kernel input worker exited".into())),
                }
            }
            if reply.is_none() {
                match self.output.try_recv() {
                    Ok(Output::Line(bytes)) => {
                        let value: Value = if *family == KernelFamily::MstCertificate {
                            let value = parse_mst_reply(&bytes, id)?;
                            if expected_mst_supported.is_some_and(|supported| {
                                (value["status"] == "unsupported") == supported
                            }) {
                                return Err(Error::Format("certificate scope mismatch".into()));
                            }
                            value
                        } else {
                            serde_json::from_slice(&bytes)?
                        };
                        if value.get("id").and_then(Value::as_u64) != Some(id)
                            || !value.get("status").is_some_and(Value::is_string)
                            || !value.get("response").is_some_and(Value::is_string)
                            || !value.get("path").is_some_and(Value::is_string)
                            || value.get("error").is_some()
                        {
                            return Err(Error::Format("invalid/cross-request kernel reply".into()));
                        }
                        reply = Some(value);
                    }
                    Ok(Output::Limit) => return Err(Error::Limit("kernel reply bytes")),
                    Ok(Output::Io(error)) => return Err(Error::Io(error)),
                    Ok(Output::Eof) | Err(mpsc::TryRecvError::Disconnected) => {
                        return Err(Error::Format("kernel closed stdout before reply".into()));
                    }
                    Err(mpsc::TryRecvError::Empty) => (),
                }
            }
            if write_done {
                if let Some(value) = reply {
                    return Ok(value);
                }
            }
            thread::sleep(POLL);
        }
    }

    fn shutdown(&mut self) -> Result<()> {
        let Some(mut child) = self.child.take() else {
            return Ok(());
        };
        // Kill while the leader is still unreaped: its PID cannot be reused for
        // another group. Never signal a name, tenant process, or caller PID.
        #[cfg(unix)]
        let group_result = {
            use nix::{
                sys::signal::{killpg, Signal},
                unistd::Pid,
            };
            match killpg(Pid::from_raw(child.id() as i32), Signal::SIGKILL) {
                Ok(()) | Err(nix::errno::Errno::ESRCH) => Ok(()),
                Err(error) => Err(std::io::Error::from_raw_os_error(error as i32)),
            }
        };
        #[cfg(not(unix))]
        let group_result: std::io::Result<()> = Ok(());
        if group_result.is_err() {
            let _ = child.kill();
        }
        let waited = child.wait();
        self.stop.store(true, Ordering::Release);
        self.input.take();
        let mut panicked = false;
        for handle in self.threads.drain(..) {
            panicked |= handle.join().is_err();
        }
        group_result?;
        waited?;
        if panicked {
            return Err(Error::Poisoned);
        }
        Ok(())
    }
}
impl Drop for Worker {
    fn drop(&mut self) {
        let _ = self.shutdown();
    }
}

#[cfg(unix)]
fn nonblocking(pipe: &impl std::os::fd::AsFd) -> Result<()> {
    use nix::fcntl::{fcntl, FcntlArg, OFlag};
    let flags =
        fcntl(pipe, FcntlArg::F_GETFL).map_err(|e| std::io::Error::from_raw_os_error(e as i32))?;
    fcntl(
        pipe,
        FcntlArg::F_SETFL(OFlag::from_bits_truncate(flags) | OFlag::O_NONBLOCK),
    )
    .map_err(|e| std::io::Error::from_raw_os_error(e as i32))?;
    Ok(())
}
fn send_bounded<T>(sender: &mpsc::SyncSender<T>, mut value: T, stop: &AtomicBool) -> bool {
    loop {
        if stop.load(Ordering::Acquire) {
            return false;
        }
        match sender.try_send(value) {
            Ok(()) => return true,
            Err(mpsc::TrySendError::Full(returned)) => value = returned,
            Err(_) => return false,
        }
        thread::sleep(POLL);
    }
}
fn write_request(
    pipe: &mut impl Write,
    mut request: &[u8],
    stop: &AtomicBool,
) -> std::io::Result<()> {
    while !request.is_empty() {
        if stop.load(Ordering::Acquire) {
            return Err(std::io::Error::other("kernel stopped"));
        }
        match pipe.write(request) {
            Ok(0) => return Err(std::io::ErrorKind::WriteZero.into()),
            Ok(count) => request = &request[count..],
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => thread::sleep(POLL),
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => (),
            Err(error) => return Err(error),
        }
    }
    Ok(())
}
fn read_output(
    mut pipe: impl Read,
    cap: usize,
    sender: mpsc::SyncSender<Output>,
    stop: Arc<AtomicBool>,
) {
    let mut line = Vec::new();
    let mut buffer = [0u8; 4096];
    loop {
        match pipe.read(&mut buffer) {
            Ok(0) => {
                send_bounded(&sender, Output::Eof, &stop);
                return;
            }
            Ok(count) => {
                for &byte in &buffer[..count] {
                    // The newline is included in the wire byte bound.
                    if line.len() >= cap {
                        send_bounded(&sender, Output::Limit, &stop);
                        return;
                    }
                    line.push(byte);
                    if byte == b'\n'
                        && !send_bounded(&sender, Output::Line(std::mem::take(&mut line)), &stop)
                    {
                        return;
                    }
                }
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                if stop.load(Ordering::Acquire) {
                    return;
                }
                thread::sleep(POLL);
            }
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => (),
            Err(error) => {
                send_bounded(&sender, Output::Io(error), &stop);
                return;
            }
        }
        if stop.load(Ordering::Acquire) {
            return;
        }
    }
}
fn drain_stderr(mut pipe: impl Read, cap: usize, stop: Arc<AtomicBool>, overflow: Arc<AtomicBool>) {
    let mut count = 0usize;
    let mut buffer = [0u8; 4096];
    loop {
        match pipe.read(&mut buffer) {
            Ok(0) => return,
            Ok(n) => {
                count = count.saturating_add(n);
                if count > cap {
                    overflow.store(true, Ordering::Release);
                }
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                if stop.load(Ordering::Acquire) {
                    return;
                }
                thread::sleep(POLL);
            }
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => (),
            Err(_) => {
                overflow.store(true, Ordering::Release);
                return;
            }
        }
        if stop.load(Ordering::Acquire) {
            return;
        }
    }
}
