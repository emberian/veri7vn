//! The Python Engine as contained child processes.
//!
//! Each worker runs `tools/appliance/engine_worker.py` (JSON lines in and out,
//! `docs/contracts/answerer.md`) in its own process group, with a cleared
//! environment, `PYTHONDONTWRITEBYTECODE=1`, a private `--state` directory and
//! `PARITY_UPSTREAM` naming the operator's checkout. One question per line.
//! A slot belongs to one tenant for its entire generation. Eviction destroys
//! all process memory; old state files remain but are never imported.
//! A turn that misses its deadline kills the worker's whole process group by
//! the PID the host recorded at spawn and reaps it. A fresh conversation starts
//! its replacement lazily.
//! There is no queue: a request that finds every worker busy is told so.

use crate::config::{self, err, ConfigError, EngineConfig};
use crate::front::{Candidate, Offer};
use oracle_execution::{Cancellation, ExecutionContext, ExecutionError};
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::fd::AsRawFd;
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::sync::{Mutex, TryLockError};
use std::time::{Duration, Instant};

const STDERR_LOG_BYTES: u64 = 16 * 1024 * 1024;

pub struct EnginePool {
    config: EngineConfig,
    argv: Vec<String>,
    slots: Vec<Mutex<Slot>>,
    boot: String,
    sequence: AtomicU64,
    stopping: AtomicBool,
    pub admission: Value,
}

struct Slot {
    index: usize,
    tenant: Option<String>,
    generation: u64,
    worker: Option<Worker>,
    starts: u64,
    deaths: u64,
}

struct Worker {
    child: Child,
    _liveness: UnixStream,
    pid: i32,
    stdin: ChildStdin,
    lines: Receiver<String>,
    is_ready: bool,
    runtime_readiness: Value,
    pid_file: PathBuf,
}

/// A reply with the (worker, generation) that produced it, or why there is none
/// and which worker was involved.
pub type Turn = Result<(Value, usize, u64), (EngineError, Option<(usize, u64)>)>;

/// Why an Engine turn produced no reply.
#[derive(Debug, PartialEq, Eq)]
pub enum EngineError {
    /// Shared-budget failure; Turn location is None before request dispatch.
    Budget(ExecutionError),
    Busy,
    Timeout,
    Lost(&'static str),
    Starting,
    Stopping,
}

impl EnginePool {
    pub fn open(settings: &EngineConfig, boot: &str) -> Result<Self, ConfigError> {
        config::admit("engine.python", &settings.python)?;
        config::admit("engine.answerer", &settings.answerer)?;
        config::absolute("engine.checkout", &settings.checkout)?;
        config::absolute("engine.state", &settings.state)?;
        if settings.workers == 0 || settings.workers > 16 {
            return Err(err("engine.workers must be between 1 and 16"));
        }
        let checkout_identity = config::admit_engine_checkout(settings)?;
        let checkout = std::fs::canonicalize(&settings.checkout)
            .map_err(|e| err(format!("engine.checkout: {e}")))?;
        let state =
            resolve_location(&settings.state).map_err(|e| err(format!("engine.state: {e}")))?;
        if state.starts_with(&checkout) {
            return Err(err("engine.state must be outside engine.checkout"));
        }
        let mut argv = vec![
            "-B".to_owned(),
            settings.answerer.path.display().to_string(),
        ];
        if let Some(specialist) = &settings.specialist {
            config::absolute("engine.specialist", specialist)?;
            argv.extend(["--specialist".into(), specialist.display().to_string()]);
        }
        if let Some(compose) = &settings.compose {
            if !["exam", "front", "combo"].contains(&compose.as_str()) {
                return Err(err("engine.compose must be exam, front or combo"));
            }
            argv.extend(["--compose".into(), compose.clone()]);
        }
        if let Some(tip) = &settings.tip {
            if !tip.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_') || tip.is_empty() {
                return Err(err("engine.tip must be a module name"));
            }
            argv.extend(["--tip".into(), tip.clone()]);
        }
        std::fs::create_dir_all(&settings.state).map_err(|e| err(format!("engine.state: {e}")))?;
        let admission = json!({"python_sha256": settings.python.sha256,
            "answerer_sha256": settings.answerer.sha256, "checkout_revision": settings.revision, "checkout": checkout_identity,
            "release": release_receipt(&settings.checkout),
            "workers": settings.workers, "specialist": settings.specialist.as_ref().map(|p| p.file_name()
                .map(|n| n.to_string_lossy().into_owned())), "compose": settings.compose, "tip": settings.tip,
            "containment": {"process_group": true, "environment": "cleared", "bytecode_writes": false,
                            "memory_limit": false, "filesystem_sandbox": false, "tenant_ownership": "whole_process_generation", "state_export": false, "lazy_start": true, "host_death_guardian": "one_process_per_active_worker"}});
        Ok(Self {
            slots: (0..settings.workers)
                .map(|index| {
                    Mutex::new(Slot {
                        index,
                        tenant: None,
                        generation: 0,
                        worker: None,
                        starts: 0,
                        deaths: 0,
                    })
                })
                .collect(),
            config: settings.clone(),
            argv,
            boot: boot.to_owned(),
            sequence: AtomicU64::new(0),
            stopping: AtomicBool::new(false),
            admission,
        })
    }

    pub fn workers(&self) -> usize {
        self.slots.len()
    }

    /// Reserve bounded capacity without constructing tenantless full Engines.
    /// Readiness of a specific generation is established on its first turn.
    pub fn start_all(&self) -> Result<(), String> {
        Ok(())
    }

    fn spawn(&self, slot: &mut Slot) -> Result<(), String> {
        use std::os::unix::process::CommandExt;
        slot.generation += 1;
        slot.starts += 1;
        let tag = format!("worker-{}-{}-{}", slot.index, self.boot, slot.generation);
        let state = self.config.state.join(&tag);
        let log = std::fs::File::create(self.config.state.join(format!("{tag}.stderr.log")))
            .map_err(|e| format!("engine stderr log: {e}"))?;
        // The host endpoint stays CLOEXEC. Only the guardian's read endpoint
        // crosses exec; EOF therefore means this host is gone, even on SIGKILL.
        let (liveness, guardian_endpoint) =
            UnixStream::pair().map_err(|e| format!("engine liveness: {e}"))?;
        use nix::fcntl::{fcntl, FcntlArg, FdFlag};
        let flags = fcntl(&guardian_endpoint, FcntlArg::F_GETFD).map_err(|e| e.to_string())?;
        fcntl(
            &guardian_endpoint,
            FcntlArg::F_SETFD(FdFlag::from_bits_truncate(flags) & !FdFlag::FD_CLOEXEC),
        )
        .map_err(|e| e.to_string())?;
        let mut command = Command::new(&self.config.python.path);
        command
            .args(&self.argv)
            .arg("--checkout")
            .arg(&self.config.checkout)
            .arg("--state")
            .arg(&state)
            .env_clear()
            .env("PATH", "/usr/bin:/bin")
            .env(
                "ORACLE_HOST_LIVENESS_FD",
                guardian_endpoint.as_raw_fd().to_string(),
            )
            .env("HOME", &self.config.state)
            .env("LANG", "C.UTF-8")
            .env("PARITY_UPSTREAM", &self.config.checkout)
            .env("PYTHONDONTWRITEBYTECODE", "1")
            .env("PYTHONHASHSEED", "0")
            .env("PYTHONIOENCODING", "utf-8")
            .current_dir(&self.config.state)
            .process_group(0)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let mut child = command.spawn().map_err(|e| format!("engine spawn: {e}"))?;
        drop(guardian_endpoint);
        let pid = child.id() as i32;
        let pid_file = self.config.state.join(format!("worker-{}.pid", slot.index));
        let _ = std::fs::write(&pid_file, format!("{pid}\n"));
        let stdin = child.stdin.take().expect("piped");
        // Pipe writes must obey the same wall deadline as the reply.
        use nix::fcntl::OFlag;
        let nonblocking = fcntl(&stdin, FcntlArg::F_GETFL).and_then(|flags| {
            fcntl(
                &stdin,
                FcntlArg::F_SETFL(OFlag::from_bits_truncate(flags) | OFlag::O_NONBLOCK),
            )
        });
        if nonblocking.is_err() {
            let _ = nix::sys::signal::killpg(
                nix::unistd::Pid::from_raw(pid),
                nix::sys::signal::Signal::SIGKILL,
            );
            let _ = child.wait();
            return Err("cannot bound engine pipe writes".into());
        }
        let stdout = child.stdout.take().expect("piped");
        let stderr = child.stderr.take().expect("piped");
        let (line_tx, lines) = mpsc::sync_channel(2);
        let frame_limit = self.config.reply_bytes;
        std::thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            loop {
                let mut bytes = Vec::new();
                match reader
                    .by_ref()
                    .take(frame_limit as u64 + 1)
                    .read_until(b'\n', &mut bytes)
                {
                    Ok(0) | Err(_) => break,
                    Ok(_) if bytes.len() > frame_limit || !bytes.ends_with(b"\n") => break,
                    Ok(_) => {
                        let Ok(line) = String::from_utf8(bytes) else {
                            break;
                        };
                        // A full channel is a protocol violation: do not allow
                        // unbounded output or leave a producer blocked forever.
                        if line_tx.try_send(line).is_err() {
                            break;
                        }
                    }
                }
            }
        });
        std::thread::spawn(move || {
            let mut log = log;
            let mut written = 0u64;
            let mut reader = BufReader::new(stderr);
            let mut line = Vec::new();
            loop {
                line.clear();
                match reader.by_ref().take(1 << 20).read_until(b'\n', &mut line) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if written < STDERR_LOG_BYTES {
                            let _ = log.write_all(&line);
                            written += n as u64;
                        }
                    }
                }
            }
        });
        slot.worker = Some(Worker {
            child,
            _liveness: liveness,
            pid,
            stdin,
            lines,
            is_ready: false,
            runtime_readiness: Value::Null,
            pid_file,
        });
        Ok(())
    }

    fn retire(slot: &mut Slot) {
        if let Some(mut worker) = slot.worker.take() {
            // Only the process group this host created, by the PID it recorded.
            let _ = nix::sys::signal::killpg(
                nix::unistd::Pid::from_raw(worker.pid),
                nix::sys::signal::Signal::SIGKILL,
            );
            let _ = worker.child.wait();
            let _ = std::fs::remove_file(&worker.pid_file);
            slot.deaths += 1;
        }
    }

    /// Check a conversation generation without dispatching or starting work.
    /// The caller must repeat immediately before returning an early answer.
    pub fn validate_binding(
        &self,
        tenant: &str,
        index: usize,
        generation: u64,
    ) -> Result<(), EngineError> {
        if self.stopping.load(Ordering::Acquire) {
            return Err(EngineError::Stopping);
        }
        let mutex = self
            .slots
            .get(index)
            .ok_or(EngineError::Lost("conversation_reset_required"))?;
        let slot = match mutex.try_lock() {
            Ok(slot) => slot,
            Err(TryLockError::Poisoned(p)) => p.into_inner(),
            Err(TryLockError::WouldBlock) => return Err(EngineError::Busy),
        };
        if slot.tenant.as_deref() != Some(tenant)
            || slot.generation != generation
            || slot.worker.is_none()
        {
            return Err(EngineError::Lost("conversation_reset_required"));
        }
        Ok(())
    }

    /// Ask one question. `prefer` keeps a conversation on its worker.
    pub fn ask(
        &self,
        tenant: &str,
        question: &str,
        session: &str,
        prefer: Option<(usize, u64)>,
    ) -> Turn {
        // Standalone callers receive one budget covering startup and the turn.
        let timeout = Duration::from_millis(self.config.startup_ms)
            .saturating_add(Duration::from_millis(self.config.turn_ms));
        let context = ExecutionContext::new(u64::MAX, timeout, Cancellation::default())
            .map_err(|_| (EngineError::Timeout, None))?;
        self.ask_with_context(tenant, question, session, prefer, &context)
    }

    /// The host's absolute deadline includes routing, startup and reply I/O.
    /// Cancellation retires the owned process before releasing this slot.
    pub fn ask_with_context(
        &self,
        tenant: &str,
        question: &str,
        session: &str,
        prefer: Option<(usize, u64)>,
        context: &ExecutionContext,
    ) -> Turn {
        context
            .spend(1)
            .map_err(|error| (EngineError::Budget(error), None))?;
        if self.stopping.load(Ordering::Acquire) {
            return Err((EngineError::Stopping, None));
        }
        if prefer.is_some_and(|(index, _)| index >= self.slots.len()) {
            return Err((EngineError::Lost("conversation_reset_required"), None));
        }
        let mut chosen = None;
        let candidates: Vec<usize> = match prefer {
            Some((index, _)) if index < self.slots.len() => vec![index],
            _ => (0..self.slots.len()).collect(),
        };
        // Prefer an existing owner, then unused capacity, then evict an idle
        // owner. Never reuse a live Engine for a different tenant.
        for pass in 0..3 {
            for &index in &candidates {
                let guard = match self.slots[index].try_lock() {
                    Ok(g) => g,
                    Err(TryLockError::Poisoned(p)) => p.into_inner(),
                    Err(TryLockError::WouldBlock) => continue,
                };
                if prefer.is_some()
                    || (pass == 0 && guard.tenant.as_deref() == Some(tenant))
                    || (pass == 1 && guard.worker.is_none())
                    || pass == 2
                {
                    chosen = Some(guard);
                    break;
                }
            }
            if chosen.is_some() {
                break;
            }
        }
        let Some(mut slot) = chosen else {
            return Err((EngineError::Busy, None));
        };
        if let Some((_, generation)) = prefer {
            if generation != slot.generation
                || slot.worker.is_none()
                || slot.tenant.as_deref() != Some(tenant)
            {
                return Err((
                    EngineError::Lost("conversation_reset_required"),
                    Some((slot.index, slot.generation)),
                ));
            }
        }
        if slot.tenant.as_deref() != Some(tenant) {
            Self::retire(&mut slot);
            slot.tenant = Some(tenant.to_owned());
        }
        if slot.worker.is_none() {
            self.spawn(&mut slot)
                .map_err(|_| (EngineError::Lost("engine_start_failed"), None))?;
        }
        let deadline = stage_deadline(context, self.config.startup_ms);
        if let Err(e) = wait_ready(&mut slot, deadline, context) {
            Self::retire(&mut slot);
            return Err((e, None));
        }
        let place = (slot.index, slot.generation);
        let id = self.sequence.fetch_add(1, Ordering::Relaxed);
        let request = json!({"id": id, "q": question, "session": session});
        let worker = slot.worker.as_mut().expect("started");
        let mut line = crate::wire::encode(&request);
        line.push(b'\n');
        let deadline = stage_deadline(context, self.config.turn_ms);
        if let Err(timed_out) = write_deadline(&mut worker.stdin, &line, deadline, context) {
            Self::retire(&mut slot);
            return Err((
                if timed_out {
                    context
                        .check()
                        .err()
                        .map_or(EngineError::Timeout, EngineError::Budget)
                } else {
                    EngineError::Lost("worker_lost")
                },
                Some(place),
            ));
        }
        loop {
            let worker = slot.worker.as_mut().expect("started");
            match receive_until(&worker.lines, deadline, context) {
                Ok(text) => {
                    if text.len() > self.config.reply_bytes {
                        Self::retire(&mut slot);
                        return Err((EngineError::Lost("reply_too_large"), Some(place)));
                    }
                    let Ok(reply) = crate::wire::parse(text.as_bytes()) else {
                        Self::retire(&mut slot);
                        return Err((EngineError::Lost("worker_protocol"), Some(place)));
                    };
                    if reply.get("id") != Some(&json!(id)) {
                        Self::retire(&mut slot);
                        return Err((EngineError::Lost("worker_protocol"), Some(place)));
                    }
                    if reply.get("error").is_some() {
                        Self::retire(&mut slot);
                        return Err((EngineError::Lost("worker_error"), Some(place)));
                    }
                    worker.runtime_readiness = reply
                        .get("runtime_readiness")
                        .cloned()
                        .unwrap_or(Value::Null);
                    return Ok((reply, place.0, place.1));
                }
                Err(RecvTimeoutError::Timeout) => {
                    Self::retire(&mut slot);
                    let error = context
                        .check()
                        .err()
                        .map_or(EngineError::Timeout, EngineError::Budget);
                    return Err((error, Some(place)));
                }
                Err(RecvTimeoutError::Disconnected) => {
                    Self::retire(&mut slot);
                    return Err((EngineError::Lost("worker_lost"), Some(place)));
                }
            }
        }
    }

    pub fn health(&self) -> Value {
        let mut busy = 0;
        let mut ready = 0;
        let mut starts = 0;
        let mut deaths = 0;
        let mut readiness = Vec::new();
        for slot in &self.slots {
            match slot.try_lock() {
                Ok(mut slot) => {
                    if let Some(worker) = slot.worker.as_mut() {
                        if worker.is_ready {
                            ready += 1;
                            readiness.push(worker.runtime_readiness.clone());
                        }
                    }
                    starts += slot.starts;
                    deaths += slot.deaths;
                }
                Err(_) => busy += 1,
            }
        }
        json!({"workers": self.slots.len(), "busy": busy, "ready_idle": ready, "ready_idle_scope": "constructor_handshake_not_liveness_probe", "runtime_readiness": readiness, "starts": starts, "retired": deaths, "lazy_start": true, "tenant_isolation": "whole_process_generation", "state_export": false, "conversation_survives_eviction": false})
    }

    pub fn close(&self) {
        self.stopping.store(true, Ordering::Release);
        for slot in &self.slots {
            let mut slot = slot.lock().unwrap_or_else(|e| e.into_inner());
            // Signal the owned group before reaping its leader. Reaping first
            // permits PID reuse and would make a later killpg unsafe.
            Self::retire(&mut slot);
        }
    }

    /// The Engine route's report for the front door.
    pub fn candidate(&self, result: &Value, ms: f64) -> Candidate {
        if let Some(error) = result.get("error").and_then(Value::as_str) {
            return Candidate::unavailable("engine".into(), 1, error, ms);
        }
        let offer = if result.get("status").and_then(Value::as_str) == Some("answered") {
            Offer::Answer
        } else {
            Offer::Refusal
        };
        let mut candidate = Candidate::from_reply("engine".into(), 1, offer, result, ms);
        // Engine replies are prose: the whole response is the comparison text.
        candidate.key = Some(candidate.response.clone()).filter(|r| !r.trim().is_empty());
        candidate.number = None;
        candidate
    }
}

fn wait_ready(
    slot: &mut Slot,
    deadline: Instant,
    context: &ExecutionContext,
) -> Result<(), EngineError> {
    let worker = slot.worker.as_mut().ok_or(EngineError::Starting)?;
    context.check().map_err(EngineError::Budget)?;
    if worker.is_ready {
        return Ok(());
    }
    match receive_until(&worker.lines, deadline, context) {
        Ok(text) => {
            let value = crate::wire::parse(text.as_bytes())
                .map_err(|_| EngineError::Lost("engine_start_failed"))?;
            if value.get("ready") != Some(&json!(true))
                || value.get("protocol") != Some(&json!("oracle-engine-v1"))
            {
                return Err(EngineError::Lost("engine_start_failed"));
            }
            worker.runtime_readiness = value
                .get("runtime_readiness")
                .cloned()
                .unwrap_or(Value::Null);
            worker.is_ready = true;
            Ok(())
        }
        Err(RecvTimeoutError::Timeout) => Err(context
            .check()
            .err()
            .map_or(EngineError::Starting, EngineError::Budget)),
        Err(RecvTimeoutError::Disconnected) => Err(EngineError::Lost("engine_start_failed")),
    }
}

/// The checkout's own release receipt, read so reports name what was served.
fn release_receipt(checkout: &std::path::Path) -> Value {
    let mut receipt = json!({});
    for name in ["BUILD_REPORT.json", "RELEASE_HASHES.json"] {
        let path = checkout.join(name);
        if let Ok(bytes) = std::fs::read(&path) {
            receipt[name] = json!(config::sha256_bytes(&bytes));
            if let Ok(value) = crate::wire::parse(&bytes) {
                for key in [
                    "format",
                    "release",
                    "variant",
                    "head",
                    "merkle_root",
                    "version",
                    "revision",
                    "source_revision",
                ] {
                    if let Some(v) = value.get(key).filter(|v| !v.is_object() && !v.is_array()) {
                        receipt[format!("{name}:{key}")] = v.clone();
                    }
                }
            }
        }
    }
    receipt
}

impl Drop for EnginePool {
    fn drop(&mut self) {
        self.close();
    }
}

fn write_deadline(
    pipe: &mut ChildStdin,
    bytes: &[u8],
    deadline: Instant,
    context: &ExecutionContext,
) -> Result<(), bool> {
    let mut sent = 0;
    while sent < bytes.len() {
        if context.check().is_err() || Instant::now() >= deadline {
            return Err(true);
        }
        match pipe.write(&bytes[sent..]) {
            Ok(0) => return Err(false),
            Ok(n) => sent += n,
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(Duration::from_millis(2))
            }
            Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {}
            Err(_) => return Err(false),
        }
    }
    Ok(())
}

// Resolve symlinks in existing ancestors before creating any state or log.
fn resolve_location(path: &std::path::Path) -> std::io::Result<PathBuf> {
    if path.exists() {
        return std::fs::canonicalize(path);
    }
    let parent = path
        .parent()
        .ok_or_else(|| std::io::Error::other("no state parent"))?;
    let base = resolve_location(parent)?;
    let name = path
        .file_name()
        .ok_or_else(|| std::io::Error::other("invalid state name"))?;
    Ok(base.join(name))
}

// Child pipe readers use bounded channels. Polling permits cancellation without
// introducing another scheduler or allowing an abandoned child to keep a slot.
fn receive_until(
    lines: &Receiver<String>,
    deadline: Instant,
    context: &ExecutionContext,
) -> Result<String, RecvTimeoutError> {
    loop {
        if context.check().is_err() || Instant::now() >= deadline {
            return Err(RecvTimeoutError::Timeout);
        }
        let left = deadline.saturating_duration_since(Instant::now());
        match lines.recv_timeout(left.min(Duration::from_millis(10))) {
            Err(RecvTimeoutError::Timeout) => continue,
            result => return result,
        }
    }
}
fn stage_deadline(context: &ExecutionContext, stage_ms: u64) -> Instant {
    Instant::now()
        .checked_add(Duration::from_millis(stage_ms))
        .map_or(context.deadline(), |deadline| {
            deadline.min(context.deadline())
        })
}

#[cfg(test)]
mod execution_inheritance_tests {
    use super::*;
    #[test]
    fn stage_limits_cannot_restart_an_expired_enclosing_deadline() {
        let deadline = Instant::now();
        let context = ExecutionContext::with_deadline(10, deadline, Cancellation::default());
        assert_eq!(stage_deadline(&context, 60_000), deadline);
        let (send, receive) = mpsc::channel();
        send.send("already queued".to_owned()).unwrap();
        assert_eq!(
            receive_until(&receive, deadline, &context),
            Err(RecvTimeoutError::Timeout)
        );
    }
    #[test]
    fn cancellation_interrupts_an_idle_reply_channel() {
        let context =
            ExecutionContext::new(10, Duration::from_secs(60), Cancellation::default()).unwrap();
        let cancellation = context.cancellation().clone();
        let (_send, receive) = mpsc::channel();
        let (started, start) = mpsc::channel();
        let (done, completed) = mpsc::channel();
        let thread = std::thread::spawn(move || {
            started.send(()).unwrap();
            done.send(receive_until(&receive, context.deadline(), &context))
                .unwrap();
        });
        start.recv_timeout(Duration::from_secs(2)).unwrap();
        cancellation.cancel();
        assert_eq!(
            completed.recv_timeout(Duration::from_secs(2)).unwrap(),
            Err(RecvTimeoutError::Timeout)
        );
        thread.join().unwrap();
    }
}
