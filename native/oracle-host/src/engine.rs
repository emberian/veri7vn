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
//! its replacement lazily, or on bounded supervisor threads in prepared mode.
//! There is no queue: a request that finds every worker busy is told so.

use crate::config::{self, err, ConfigError, EngineConfig};
use crate::front::{Candidate, Offer};
use oracle_execution::{Cancellation, ExecutionContext, ExecutionError};
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Read, Write};
use std::ops::Deref;
use std::os::fd::AsRawFd;
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::sync::{Arc, Condvar, Mutex, TryLockError};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

const STDERR_LOG_BYTES: u64 = 16 * 1024 * 1024;

pub struct EnginePool {
    core: Arc<EngineCore>,
    supervisors: Mutex<Vec<JoinHandle<()>>>,
}

#[doc(hidden)]
pub struct EngineCore {
    config: EngineConfig,
    argv: Vec<String>,
    slots: Vec<Mutex<Slot>>,
    boot: String,
    sequence: AtomicU64,
    stopping: AtomicBool,
    spawn_gate: Mutex<()>,
    preparing: Vec<AtomicBool>,
    initial_preparation_ms: AtomicU64,
    pub admission: Value,
    wake: Arc<Wake>,
    cancellation: Cancellation,
}

struct Wake {
    epoch: Mutex<u64>,
    changed: Condvar,
}
impl Wake {
    fn notify(&self) {
        let mut epoch = self.epoch.lock().unwrap_or_else(|e| e.into_inner());
        *epoch = epoch.wrapping_add(1);
        self.changed.notify_all();
    }
}
impl Deref for EnginePool {
    type Target = EngineCore;
    fn deref(&self) -> &EngineCore {
        &self.core
    }
}

struct Slot {
    wake: Arc<Wake>,
    replenish: bool,
    exhausted: bool,
    index: usize,
    tenant: Option<String>,
    generation: u64,
    worker: Option<Worker>,
    starts: u64,
    deaths: u64,
    last_prepare_ms: u64,
}

struct Worker {
    child: Child,
    _liveness: UnixStream,
    pid: i32,
    stdin: ChildStdin,
    lines: Receiver<String>,
    alive: Arc<AtomicBool>,
    is_ready: bool,
    runtime_readiness: Value,
    pid_file: PathBuf,
    readers: Vec<JoinHandle<()>>,
}

impl Worker {
    fn is_alive(&mut self) -> bool {
        if !self.alive.load(Ordering::Acquire) {
            return false;
        }
        match child_exited(self.pid) {
            Ok(false) => true,
            Ok(true) | Err(_) => {
                self.alive.store(false, Ordering::Release);
                false
            }
        }
    }
}

// Observe exit without reaping: retire must signal the owned process group
// while its leader still reserves the PID, then reap it. Child::try_wait would
// release that reservation before killpg and permit an unrelated reused PID.
#[cfg(any(
    target_os = "android",
    target_os = "freebsd",
    target_os = "haiku",
    all(target_os = "linux", not(target_env = "uclibc"))
))]
fn child_exited(pid: i32) -> std::io::Result<bool> {
    use nix::sys::wait::{waitid, Id, WaitPidFlag, WaitStatus};
    loop {
        match waitid(
            Id::Pid(nix::unistd::Pid::from_raw(pid)),
            WaitPidFlag::WEXITED | WaitPidFlag::WNOHANG | WaitPidFlag::WNOWAIT,
        ) {
            Ok(WaitStatus::StillAlive) => return Ok(false),
            Ok(_) => return Ok(true),
            Err(nix::errno::Errno::EINTR) => continue,
            Err(error) => return Err(std::io::Error::from_raw_os_error(error as i32)),
        }
    }
}

#[cfg(not(any(
    target_os = "android",
    target_os = "freebsd",
    target_os = "haiku",
    all(target_os = "linux", not(target_env = "uclibc"))
)))]
fn child_exited(_pid: i32) -> std::io::Result<bool> {
    // nix does not expose safe waitid on macOS. Stdout EOF still detects normal
    // exit; a descendant keeping stdout open defers detection to a turn timeout.
    // Never use Child::try_wait here: group ownership is more important than
    // observing that exceptional idle exit before the next turn.
    Ok(false)
}

const LIVENESS_PROBE: &str = if cfg!(any(
    target_os = "android",
    target_os = "freebsd",
    target_os = "haiku",
    all(target_os = "linux", not(target_env = "uclibc"))
)) {
    "stdout_eof_and_waitid_wnowait"
} else {
    "stdout_eof_only_descendant_held_pipe_needs_turn_timeout"
};

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
        if let Some(adapter) = &settings.conversation_adapter {
            config::admit("engine.conversation_adapter", adapter)?;
            let helper = std::fs::canonicalize(&adapter.path)
                .map_err(|e| err(format!("engine.conversation_adapter: {e}")))?;
            let answerer = std::fs::canonicalize(&settings.answerer.path)
                .map_err(|e| err(format!("engine.answerer: {e}")))?;
            if helper.file_name().and_then(|n| n.to_str()) != Some("conversation_adapter.py")
                || helper.parent() != answerer.parent()
            {
                return Err(err("engine.conversation_adapter must be conversation_adapter.py beside the admitted answerer"));
            }
        }
        config::absolute("engine.checkout", &settings.checkout)?;
        config::absolute("engine.state", &settings.state)?;
        if settings.workers == 0 || settings.workers > 16 {
            return Err(err("engine.workers must be between 1 and 16"));
        }
        let checkout_identity = config::admit_engine_checkout(settings)?;
        let prepared_identity = config::admit_engine_prepared(settings)?;
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
            "answerer_sha256": settings.answerer.sha256,
            "conversation_adapter_sha256": settings.conversation_adapter.as_ref().map(|a| &a.sha256), "checkout_revision": settings.revision, "checkout": checkout_identity,
            "release": release_receipt(&settings.checkout),
            "workers": settings.workers, "specialist": settings.specialist.as_ref().map(|p| p.file_name()
                .map(|n| n.to_string_lossy().into_owned())), "compose": settings.compose, "tip": settings.tip,
            "containment": {"process_group": true, "environment": "cleared", "bytecode_writes": false,
                            "memory_limit": false, "filesystem_sandbox": false, "tenant_ownership": "whole_process_generation", "state_export": false, "lazy_start": settings.prepared.is_none(), "host_death_guardian": "one_process_per_active_worker"}});
        let wake = Arc::new(Wake {
            epoch: Mutex::new(0),
            changed: Condvar::new(),
        });
        let mut admission = admission;
        admission["prepared"] = prepared_identity.unwrap_or(Value::Null);
        let pool = Self {
            core: Arc::new(EngineCore {
                wake: wake.clone(),
                cancellation: Cancellation::default(),
                slots: (0..settings.workers)
                    .map(|index| {
                        Mutex::new(Slot {
                            wake: wake.clone(),
                            replenish: true,
                            exhausted: false,
                            index,
                            tenant: None,
                            generation: 0,
                            worker: None,
                            starts: 0,
                            deaths: 0,
                            last_prepare_ms: 0,
                        })
                    })
                    .collect(),
                config: settings.clone(),
                argv,
                boot: boot.to_owned(),
                sequence: AtomicU64::new(0),
                stopping: AtomicBool::new(false),
                spawn_gate: Mutex::new(()),
                preparing: (0..settings.workers)
                    .map(|_| AtomicBool::new(settings.prepared.is_some()))
                    .collect(),
                initial_preparation_ms: AtomicU64::new(0),
                admission,
            }),
            supervisors: Mutex::new(Vec::new()),
        };
        if settings.prepared.is_some() {
            for index in 0..settings.workers {
                let core = pool.core.clone();
                let handle = std::thread::Builder::new()
                    .name(format!("engine-prepare-{index}"))
                    .spawn(move || core.supervise(index))
                    .map_err(|e| err(format!("engine supervisor: {e}")))?;
                pool.supervisors.lock().unwrap().push(handle);
            }
        }
        Ok(pool)
    }

    pub fn workers(&self) -> usize {
        self.slots.len()
    }

    /// Prepared mode completes initial public readiness before service admission.
    /// Lazy mode retains its original first-turn startup behavior.
    pub fn start_all(&self) -> Result<(), String> {
        if self.config.prepared.is_none() {
            return Ok(());
        }
        let started = Instant::now();
        loop {
            let epoch = *self.wake.epoch.lock().unwrap_or_else(|e| e.into_inner());
            if self.stopping.load(Ordering::Acquire) {
                return Err("engine stopping".into());
            }
            let mut pending = false;
            for slot in &self.slots {
                match slot.try_lock() {
                    Ok(mut slot) => {
                        Self::check_liveness(&mut slot);
                        if slot.exhausted {
                            return Err("engine preparation attempts exhausted".into());
                        }
                        pending |= !slot.worker.as_ref().is_some_and(|w| w.is_ready);
                    }
                    Err(_) => pending = true,
                }
            }
            if !pending {
                let _ = self.initial_preparation_ms.compare_exchange(
                    0,
                    started.elapsed().as_millis() as u64,
                    Ordering::Release,
                    Ordering::Relaxed,
                );
                return Ok(());
            }
            let guard = self.wake.epoch.lock().unwrap_or_else(|e| e.into_inner());
            let _guard = self
                .wake
                .changed
                .wait_while(guard, |value| {
                    *value == epoch && !self.stopping.load(Ordering::Acquire)
                })
                .unwrap_or_else(|e| e.into_inner());
        }
    }
}

impl EngineCore {
    fn supervise(&self, index: usize) {
        let prepared = self.config.prepared.as_ref().expect("prepared supervisor");
        loop {
            let epoch = *self.wake.epoch.lock().unwrap_or_else(|e| e.into_inner());
            if self.stopping.load(Ordering::Acquire) {
                break;
            }
            let mut slot = self.slots[index].lock().unwrap_or_else(|e| e.into_inner());
            EnginePool::check_liveness(&mut slot);
            if slot.worker.is_none() && slot.replenish {
                self.preparing[index].store(true, Ordering::Release);
                slot.replenish = false;
                slot.tenant = None;
                slot.exhausted = false;
                for attempt in 0..prepared.replacement_attempts {
                    if self.stopping.load(Ordering::Acquire) {
                        break;
                    }
                    let Ok(context) = ExecutionContext::new(
                        u64::MAX,
                        Duration::from_millis(self.config.startup_ms),
                        self.cancellation.clone(),
                    ) else {
                        break;
                    };
                    let attempt_started = Instant::now();
                    let result = self
                        .spawn(&mut slot)
                        .map_err(|_| EngineError::Lost("engine_start_failed"))
                        .and_then(|_| {
                            wait_ready(
                                &mut slot,
                                context.deadline(),
                                &context,
                                Some(&prepared.artifact.sha256),
                            )
                        });
                    if result.is_ok() {
                        slot.last_prepare_ms = attempt_started.elapsed().as_millis() as u64;
                        break;
                    }
                    EnginePool::retire(&mut slot);
                    slot.replenish = false;
                    if attempt + 1 < prepared.replacement_attempts {
                        drop(slot);
                        let guard = self.wake.epoch.lock().unwrap_or_else(|e| e.into_inner());
                        let guard = self
                            .wake
                            .changed
                            .wait_timeout_while(
                                guard,
                                Duration::from_millis(prepared.replacement_backoff_ms),
                                |_| !self.stopping.load(Ordering::Acquire),
                            )
                            .unwrap_or_else(|e| e.into_inner());
                        drop(guard);
                        slot = self.slots[index].lock().unwrap_or_else(|e| e.into_inner());
                    }
                }
                slot.exhausted = slot.worker.is_none();
                self.preparing[index].store(false, Ordering::Release);
                drop(slot);
                self.wake.notify();
                continue;
            }
            drop(slot);
            let guard = self.wake.epoch.lock().unwrap_or_else(|e| e.into_inner());
            let _guard = self
                .wake
                .changed
                .wait_timeout_while(guard, Duration::from_millis(100), |value| {
                    *value == epoch && !self.stopping.load(Ordering::Acquire)
                })
                .unwrap_or_else(|e| e.into_inner());
        }
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
            .env("OMP_NUM_THREADS", "1")
            .env("OPENBLAS_NUM_THREADS", "1")
            .env("MKL_NUM_THREADS", "1")
            .env("VECLIB_MAXIMUM_THREADS", "1")
            .env("NUMEXPR_NUM_THREADS", "1")
            .env("BLIS_NUM_THREADS", "1")
            .env("RAYON_NUM_THREADS", "1")
            .env("TOKENIZERS_PARALLELISM", "false")
            .current_dir(&self.config.state)
            .process_group(0)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        if let Some(prepared) = &self.config.prepared {
            command
                .env("ORACLE7_PREPARED_SERVING", "1")
                .env(
                    "ORACLE7_READER_ARTIFACT",
                    prepared
                        .artifact
                        .path
                        .parent()
                        .expect("admitted manifest parent"),
                )
                .env("ORACLE7_READER_ARTIFACT_SHA256", &prepared.artifact.sha256);
        }
        let spawn_gate = self.spawn_gate.lock().unwrap_or_else(|e| e.into_inner());
        if self.stopping.load(Ordering::Acquire) {
            return Err("engine stopping".into());
        }
        let mut child = command.spawn().map_err(|e| format!("engine spawn: {e}"))?;
        drop(spawn_gate);
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
            let _ = std::fs::remove_file(&pid_file);
            return Err("cannot bound engine pipe writes".into());
        }
        let stdout = child.stdout.take().expect("piped");
        let stderr = child.stderr.take().expect("piped");
        let (line_tx, lines) = mpsc::sync_channel(2);
        let frame_limit = self.config.reply_bytes;
        let alive = Arc::new(AtomicBool::new(true));
        let alive_for_stdout = alive.clone();
        let wake_for_stdout = slot.wake.clone();
        let output_reader = std::thread::Builder::new()
            .name("engine-stdout".into())
            .spawn(move || {
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
                alive_for_stdout.store(false, Ordering::Release);
                wake_for_stdout.notify();
            });
        let output_reader = match output_reader {
            Ok(reader) => reader,
            Err(e) => {
                let _ = nix::sys::signal::killpg(
                    nix::unistd::Pid::from_raw(pid),
                    nix::sys::signal::Signal::SIGKILL,
                );
                let _ = child.wait();
                let _ = std::fs::remove_file(&pid_file);
                return Err(format!("engine stdout reader: {e}"));
            }
        };
        let error_reader = std::thread::Builder::new()
            .name("engine-stderr".into())
            .spawn(move || {
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
        let error_reader = match error_reader {
            Ok(reader) => reader,
            Err(e) => {
                let _ = nix::sys::signal::killpg(
                    nix::unistd::Pid::from_raw(pid),
                    nix::sys::signal::Signal::SIGKILL,
                );
                let _ = child.wait();
                let _ = output_reader.join();
                let _ = std::fs::remove_file(&pid_file);
                return Err(format!("engine stderr reader: {e}"));
            }
        };
        slot.worker = Some(Worker {
            child,
            _liveness: liveness,
            pid,
            stdin,
            lines,
            alive,
            is_ready: false,
            runtime_readiness: Value::Null,
            pid_file,
            readers: vec![output_reader, error_reader],
        });
        Ok(())
    }
}

impl EnginePool {
    fn check_liveness(slot: &mut Slot) -> bool {
        if slot.worker.as_mut().is_some_and(|w| !w.is_alive()) {
            Self::retire(slot);
            false
        } else {
            slot.worker.is_some()
        }
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
            for reader in worker.readers {
                let _ = reader.join();
            }
            slot.deaths += 1;
        }
        slot.replenish = true;
        slot.wake.notify();
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
        let mut slot = match mutex.try_lock() {
            Ok(slot) => slot,
            Err(TryLockError::Poisoned(p)) => p.into_inner(),
            Err(TryLockError::WouldBlock) => return Err(EngineError::Busy),
        };
        Self::check_liveness(&mut slot);
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
        self.ask_inner(tenant, question, session, prefer, None, None, context)
    }

    /// Restore the committed canonical envelope before evaluating covered owners.
    /// This does not make unsupported Engine tools or documents recoverable.
    pub fn ask_conversation_with_context(
        &self,
        tenant: &str,
        question: &str,
        session: &str,
        prefer: Option<(usize, u64)>,
        committed: &Value,
        context: &ExecutionContext,
    ) -> Turn {
        self.ask_inner(
            tenant,
            question,
            session,
            prefer,
            Some(committed),
            None,
            context,
        )
    }

    /// Reconcile a typed native delivery without evaluating an Engine question.
    pub fn project_conversation_with_context(
        &self,
        tenant: &str,
        session: &str,
        prefer: Option<(usize, u64)>,
        committed: &Value,
        delivered: &Value,
        context: &ExecutionContext,
    ) -> Turn {
        self.ask_inner(
            tenant,
            "",
            session,
            prefer,
            Some(committed),
            Some(delivered),
            context,
        )
    }

    /// Retire only the generation whose speculative state the caller owns.
    pub fn retire_binding(&self, tenant: &str, place: (usize, u64)) -> Result<(), EngineError> {
        let Some(mutex) = self.slots.get(place.0) else {
            return Err(EngineError::Lost("conversation_reset_required"));
        };
        let mut slot = match mutex.try_lock() {
            Ok(slot) => slot,
            Err(TryLockError::Poisoned(p)) => p.into_inner(),
            Err(TryLockError::WouldBlock) => return Err(EngineError::Busy),
        };
        if slot.tenant.as_deref() != Some(tenant) || slot.generation != place.1 {
            return Err(EngineError::Lost("conversation_reset_required"));
        }
        Self::retire(&mut slot);
        Ok(())
    }

    fn ask_inner(
        &self,
        tenant: &str,
        question: &str,
        session: &str,
        prefer: Option<(usize, u64)>,
        committed: Option<&Value>,
        delivered: Option<&Value>,
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
        let prepared = self.config.prepared.is_some();
        let mut chosen = None;
        let mut unavailable = false;
        let candidates: Vec<usize> = match prefer {
            Some((index, _)) if index < self.slots.len() => vec![index],
            _ => (0..self.slots.len()).collect(),
        };
        // Prefer an existing owner, then unused capacity, then evict an idle
        // owner. Never reuse a live Engine for a different tenant.
        for pass in 0..3 {
            for &index in &candidates {
                let mut guard = match self.slots[index].try_lock() {
                    Ok(g) => g,
                    Err(TryLockError::Poisoned(p)) => p.into_inner(),
                    Err(TryLockError::WouldBlock) => continue,
                };
                Self::check_liveness(&mut guard);
                unavailable |= prepared && guard.worker.is_none();
                if prefer.is_some()
                    || (pass == 0
                        && guard.tenant.as_deref() == Some(tenant)
                        && (!prepared || guard.worker.is_some()))
                    || (pass == 1
                        && if prepared {
                            guard.tenant.is_none()
                                && guard.worker.as_ref().is_some_and(|w| w.is_ready)
                        } else {
                            guard.worker.is_none()
                        })
                    || (pass == 2 && (!prepared || guard.worker.is_some()))
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
            return Err((
                if prepared
                    && (unavailable || self.preparing.iter().any(|p| p.load(Ordering::Acquire)))
                {
                    EngineError::Starting
                } else {
                    EngineError::Busy
                },
                None,
            ));
        };
        if self.stopping.load(Ordering::Acquire) {
            return Err((EngineError::Stopping, None));
        }
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
            if prepared {
                if slot.worker.is_none() {
                    return Err((EngineError::Starting, None));
                }
                if slot.tenant.is_some() || !slot.worker.as_ref().is_some_and(|w| w.is_ready) {
                    Self::retire(&mut slot);
                    return Err((EngineError::Starting, None));
                }
            } else {
                Self::retire(&mut slot);
            }
            slot.tenant = Some(tenant.to_owned());
        }
        if slot.worker.is_none() {
            if prepared {
                return Err((EngineError::Starting, None));
            }
            self.spawn(&mut slot)
                .map_err(|_| (EngineError::Lost("engine_start_failed"), None))?;
        }
        let deadline = stage_deadline(context, self.config.startup_ms);
        if let Err(e) = wait_ready(&mut slot, deadline, context, None) {
            Self::retire(&mut slot);
            return Err((e, None));
        }
        let place = (slot.index, slot.generation);
        let id = self.sequence.fetch_add(1, Ordering::Relaxed);
        let mut request = json!({"id": id, "q": question, "session": session});
        if let Some(state) = committed {
            request["conversation"] = json!({"protocol": "oracle-conversation-v1", "state": state});
            if let Some(reply) = delivered {
                request["conversation"]["op"] = json!("project");
                request["conversation"]["delivered"] = reply.clone();
            }
        }
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
        let mut unassigned = 0;
        let mut exhausted = 0;
        let mut last_prepare_ms = Vec::new();
        for slot in &self.slots {
            match slot.try_lock() {
                Ok(mut slot) => {
                    Self::check_liveness(&mut slot);
                    exhausted += usize::from(slot.exhausted);
                    unassigned += usize::from(
                        slot.tenant.is_none() && slot.worker.as_ref().is_some_and(|w| w.is_ready),
                    );
                    if let Some(worker) = slot.worker.as_mut() {
                        if worker.is_ready {
                            ready += 1;
                            readiness.push(worker.runtime_readiness.clone());
                        }
                    }
                    starts += slot.starts;
                    deaths += slot.deaths;
                    last_prepare_ms.push(slot.last_prepare_ms);
                }
                Err(_) => busy += 1,
            }
        }
        json!({"workers": self.slots.len(), "unassigned_ready": unassigned, "exhausted": exhausted, "preparing": self.preparing.iter().filter(|p| p.load(Ordering::Acquire)).count(), "initial_preparation_ms": self.initial_preparation_ms.load(Ordering::Acquire), "slot_last_prepare_ms": last_prepare_ms, "replacement_policy": "bounded_attempts_then_unavailable_until_host_restart", "busy": busy, "ready_idle": ready, "ready_idle_scope": "constructor_handshake_not_liveness_probe", "liveness_probe": LIVENESS_PROBE, "runtime_readiness": readiness, "starts": starts, "retired": deaths, "lazy_start": self.config.prepared.is_none(), "tenant_isolation": "whole_process_generation", "state_export": false, "conversation_survives_eviction": false, "supported_conversation_protocol": "oracle-conversation-v1", "supported_conversation_scope": "explicit_source_pinned_adapter_routes_only", "legacy_engine_state_export": false})
    }

    pub fn close(&self) {
        {
            let _gate = self.spawn_gate.lock().unwrap_or_else(|e| e.into_inner());
            self.stopping.store(true, Ordering::Release);
        }
        self.cancellation.cancel();
        self.wake.notify();
        let handles =
            std::mem::take(&mut *self.supervisors.lock().unwrap_or_else(|e| e.into_inner()));
        for handle in handles {
            let _ = handle.join();
        }
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
    prepared_sha256: Option<&str>,
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
            if let Some(digest) = prepared_sha256 {
                let readiness = &value["runtime_readiness"];
                if readiness["scope"] != "prepared_u8_required_dependencies"
                    || readiness["reader_artifact_manifest_sha256"].as_str() != Some(digest)
                    || readiness["background_loading_policy"]
                        != "synchronous_before_constructor_return"
                    || readiness["required_components"]
                        != json!(["standing_family", "air", "physics", "facts"])
                {
                    return Err(EngineError::Lost("engine_prepared_readiness"));
                }
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
    #[cfg(any(
        target_os = "android",
        target_os = "freebsd",
        target_os = "haiku",
        all(target_os = "linux", not(target_env = "uclibc"))
    ))]
    #[test]
    fn liveness_probe_preserves_the_child_wait_status() {
        let mut child = Command::new("sh").args(["-c", "exit 7"]).spawn().unwrap();
        let until = Instant::now() + Duration::from_secs(2);
        while !child_exited(child.id() as i32).unwrap() {
            assert!(Instant::now() < until, "child failed to exit");
            std::thread::sleep(Duration::from_millis(5));
        }
        // Both observations leave the original child available to its owner.
        assert!(child_exited(child.id() as i32).unwrap());
        assert_eq!(child.wait().unwrap().code(), Some(7));
    }

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

#[cfg(test)]
mod prepared_lifecycle_tests {
    use super::*;
    use crate::config::{Artifact, PreparedEngineConfig};

    // Manufactured workers exercise lifecycle ownership only. Public artifact
    // admission is tested separately; this fixture intentionally bypasses it.
    fn fixture(mode: &str) -> (tempfile::TempDir, EnginePool) {
        let dir = tempfile::tempdir().unwrap();
        let python = std::env::split_paths(&std::env::var_os("PATH").unwrap())
            .map(|p| p.join("python3"))
            .find(|p| p.is_file())
            .unwrap();
        let checkout = dir.path().join("checkout");
        std::fs::create_dir_all(checkout.join(".git")).unwrap();
        let revision = "0123456789abcdef0123456789abcdef01234567";
        std::fs::write(checkout.join(".git/HEAD"), revision).unwrap();
        let worker = dir.path().join("worker.py");
        std::fs::write(&worker, r#"import sys,json,os,time,pathlib
state=pathlib.Path(sys.argv[sys.argv.index('--state')+1]); state.mkdir()
mode=(state.parent/'mode').read_text()
if mode=='slow': time.sleep(30)
readiness={'scope':'prepared_u8_required_dependencies','reader_artifact_manifest_sha256':os.environ['ORACLE7_READER_ARTIFACT_SHA256'],'required_components':['standing_family','air','physics','facts'],'background_loading_policy':'synchronous_before_constructor_return'}
if mode=='wrong': readiness['scope']='constructor_complete'
assert os.environ['ORACLE7_PREPARED_SERVING']=='1'
assert os.environ['ORACLE7_READER_ARTIFACT']==str(state.parent.parent)
print(json.dumps({'protocol':'oracle-engine-v1','ready':True,'runtime_readiness':readiness}),flush=True)
private=[]
for line in sys.stdin:
 r=json.loads(line)
 if r['q']=='error': print(json.dumps({'id':r['id'],'error':'failed after dispatch'}),flush=True); continue
 if r['q'].startswith('remember:'): private.append(r['q'])
 print(json.dumps({'id':r['id'],'status':'answered','response':str(private)}),flush=True)
"#).unwrap();
        let artifact = |path: PathBuf| Artifact {
            sha256: config::sha256_file(&path).unwrap(),
            path,
        };
        let settings = EngineConfig {
            python: artifact(python),
            answerer: artifact(worker),
            conversation_adapter: None,
            checkout,
            revision: revision.into(),
            materialization: None,
            prepared: None,
            state: dir.path().join("state"),
            workers: 1,
            startup_ms: 1000,
            turn_ms: 1000,
            reply_bytes: 4096,
            specialist: None,
            compose: None,
            tip: None,
        };
        let mut pool = EnginePool::open(&settings, "prepared-test").unwrap();
        std::fs::write(settings.state.join("mode"), mode).unwrap();
        let core = Arc::get_mut(&mut pool.core).unwrap();
        core.config.prepared = Some(PreparedEngineConfig {
            artifact: Artifact {
                path: dir.path().join("MANIFEST.json"),
                sha256: "a".repeat(64),
            },
            replacement_attempts: 2,
            replacement_backoff_ms: 20,
        });
        core.preparing[0].store(true, Ordering::Release);
        let core = pool.core.clone();
        pool.supervisors
            .lock()
            .unwrap()
            .push(std::thread::spawn(move || core.supervise(0)));
        (dir, pool)
    }

    #[test]
    fn prepared_claim_once_and_replacement_never_share_private_state() {
        let (_dir, pool) = fixture("ready");
        pool.start_all().unwrap();
        assert_eq!(pool.health()["unassigned_ready"], 1);
        let (a, index, generation) = pool.ask("a", "remember:secret", "s", None).unwrap();
        assert!(a["response"].as_str().unwrap().contains("secret"));
        assert_eq!(pool.health()["unassigned_ready"], 0);
        assert_eq!(
            pool.ask("b", "recall", "s", None),
            Err((EngineError::Starting, None))
        );
        pool.start_all().unwrap();
        let (b, _, replacement) = pool.ask("b", "recall", "s", None).unwrap();
        assert_eq!(b["response"], "[]");
        assert!(replacement > generation);
        assert!(matches!(
            pool.ask("a", "recall", "s", Some((index, generation))),
            Err((EngineError::Lost("conversation_reset_required"), _))
        ));
        assert_eq!(
            pool.ask("b", "error", "s", Some((index, replacement))),
            Err((
                EngineError::Lost("worker_error"),
                Some((index, replacement))
            ))
        );
        pool.start_all().unwrap();
        assert_eq!(pool.health()["starts"], 3);
        pool.close();
        assert_eq!(pool.health()["ready_idle"], 0);
        assert_eq!(
            pool.ask("c", "recall", "s", None),
            Err((EngineError::Stopping, None))
        );
    }

    #[test]
    fn wrong_prepared_marker_exhausts_finite_attempts_without_request_rearming() {
        let (_dir, pool) = fixture("wrong");
        assert!(pool.start_all().is_err());
        for _ in 0..20 {
            assert_eq!(
                pool.ask("t", "q", "s", None),
                Err((EngineError::Starting, None))
            );
        }
        assert_eq!(pool.health()["starts"], 2);
        assert_eq!(pool.health()["exhausted"], 1);
        assert_eq!(pool.health()["ready_idle"], 0);
    }

    #[test]
    fn shutdown_cancels_preparation_and_joins_before_returning() {
        let (dir, pool) = fixture("slow");
        let pid_file = dir.path().join("state/worker-0.pid");
        let until = Instant::now() + Duration::from_secs(2);
        while !pid_file.exists() && Instant::now() < until {
            std::thread::sleep(Duration::from_millis(2));
        }
        assert!(
            pid_file.exists(),
            "fixture must be inside startup before cancellation"
        );
        let before = Instant::now();
        pool.close();
        assert!(before.elapsed() < Duration::from_secs(2));
        assert!(!dir.path().join("state/worker-0.pid").exists());
        assert!(pool.supervisors.lock().unwrap().is_empty());
        assert_eq!(pool.start_all(), Err("engine stopping".into()));
    }

    #[test]
    fn idle_worker_death_is_reaped_and_replaced_by_supervisor() {
        let (dir, pool) = fixture("ready");
        pool.start_all().unwrap();
        assert_eq!(pool.health()["starts"], 1);
        assert_eq!(pool.health()["unassigned_ready"], 1);
        let pid_text = std::fs::read_to_string(dir.path().join("state/worker-0.pid")).unwrap();
        let pid: i32 = pid_text.trim().parse().unwrap();
        nix::sys::signal::killpg(
            nix::unistd::Pid::from_raw(pid),
            nix::sys::signal::Signal::SIGKILL,
        )
        .unwrap();
        let until = Instant::now() + Duration::from_secs(2);
        // Observe without health()/start_all(), which themselves check liveness:
        // this specifically requires the supervisor to replace the idle worker.
        loop {
            let ready = pool.slots[0].try_lock().is_ok_and(|slot| {
                slot.starts == 2 && slot.worker.as_ref().is_some_and(|worker| worker.is_ready)
            });
            if ready {
                break;
            }
            assert!(
                Instant::now() < until,
                "supervisor did not replace dead worker"
            );
            std::thread::sleep(Duration::from_millis(5));
        }
        assert_eq!(pool.health()["retired"], 1);
        assert_eq!(pool.health()["starts"], 2);
        assert_eq!(pool.health()["unassigned_ready"], 1);
        let (reply, _, generation) = pool.ask("t", "recall", "s", None).unwrap();
        assert_eq!(reply["response"], "[]");
        assert_eq!(generation, 2);
        pool.close();
    }
}
