//! The Python Engine as contained child processes.
//!
//! Each worker runs `tools/parity/answerers/oracle7.py` (JSON lines in and out,
//! `docs/contracts/answerer.md`) in its own process group, with a cleared
//! environment, `PYTHONDONTWRITEBYTECODE=1`, a private `--state` directory and
//! `PARITY_UPSTREAM` naming the operator's checkout. One question per line.
//! A turn that misses its deadline kills the worker's whole process group by
//! the PID the host recorded at spawn, reaps it, and starts a replacement.
//! There is no queue: a request that finds every worker busy is told so.

use crate::config::{self, err, ConfigError, EngineConfig};
use crate::front::{Candidate, Offer};
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Read, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError};
use std::sync::{Mutex, TryLockError};
use std::time::{Duration, Instant};

const READY_MARKER: &str = "[oracle7 answerer] head ";
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
    generation: u64,
    worker: Option<Worker>,
    starts: u64,
    deaths: u64,
}

struct Worker {
    child: Child,
    pid: i32,
    stdin: ChildStdin,
    lines: Receiver<String>,
    ready: Receiver<()>,
    is_ready: bool,
    pid_file: PathBuf,
}

/// A reply with the (worker, generation) that produced it, or why there is none
/// and which worker was involved.
pub type Turn = Result<(Value, usize, u64), (EngineError, Option<(usize, u64)>)>;

/// Why an Engine turn produced no reply.
#[derive(Debug, PartialEq, Eq)]
pub enum EngineError {
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
        let head = config::git_head(&settings.checkout)?;
        if head != settings.revision {
            return Err(err(format!(
                "engine.checkout HEAD is {head}, configured revision is {}",
                settings.revision
            )));
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
            "answerer_sha256": settings.answerer.sha256, "checkout_revision": head,
            "release": release_receipt(&settings.checkout),
            "workers": settings.workers, "specialist": settings.specialist.as_ref().map(|p| p.file_name()
                .map(|n| n.to_string_lossy().into_owned())), "compose": settings.compose, "tip": settings.tip,
            "containment": {"process_group": true, "environment": "cleared", "bytecode_writes": false,
                            "memory_limit": false, "filesystem_sandbox": false}});
        Ok(Self {
            slots: (0..settings.workers)
                .map(|index| {
                    Mutex::new(Slot {
                        index,
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

    /// Start every worker and wait for each Engine to finish construction.
    pub fn start_all(&self) -> Result<(), String> {
        for slot in &self.slots {
            let mut slot = slot.lock().unwrap_or_else(|e| e.into_inner());
            self.spawn(&mut slot)?;
            let deadline = Instant::now() + Duration::from_millis(self.config.startup_ms);
            wait_ready(&mut slot, deadline)
                .map_err(|e| format!("engine worker {}: {e:?}", slot.index))?;
        }
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
        let mut command = Command::new(&self.config.python.path);
        command
            .args(&self.argv)
            .arg("--state")
            .arg(&state)
            .env_clear()
            .env("PATH", "/usr/bin:/bin")
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
        let pid = child.id() as i32;
        let pid_file = self.config.state.join(format!("worker-{}.pid", slot.index));
        let _ = std::fs::write(&pid_file, format!("{pid}\n"));
        let stdin = child.stdin.take().expect("piped");
        let stdout = child.stdout.take().expect("piped");
        let stderr = child.stderr.take().expect("piped");
        let (line_tx, lines) = mpsc::channel();
        std::thread::spawn(move || {
            for line in BufReader::new(stdout).lines() {
                let Ok(line) = line else { break };
                if line_tx.send(line).is_err() {
                    break;
                }
            }
        });
        let (ready_tx, ready) = mpsc::channel();
        std::thread::spawn(move || {
            let mut log = log;
            let mut written = 0u64;
            let mut reader = BufReader::new(stderr);
            let mut line = Vec::new();
            let mut signalled = false;
            loop {
                line.clear();
                match reader.by_ref().take(1 << 20).read_until(b'\n', &mut line) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if !signalled && line.starts_with(READY_MARKER.as_bytes()) {
                            signalled = true;
                            let _ = ready_tx.send(());
                        }
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
            pid,
            stdin,
            lines,
            ready,
            is_ready: false,
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

    /// Ask one question. `prefer` keeps a conversation on its worker.
    pub fn ask(&self, question: &str, session: &str, prefer: Option<(usize, u64)>) -> Turn {
        if self.stopping.load(Ordering::Acquire) {
            return Err((EngineError::Stopping, None));
        }
        let mut chosen = None;
        let candidates: Vec<usize> = match prefer {
            Some((index, _)) if index < self.slots.len() => vec![index],
            _ => (0..self.slots.len()).collect(),
        };
        for index in candidates {
            match self.slots[index].try_lock() {
                Ok(guard) => {
                    chosen = Some(guard);
                    break;
                }
                Err(TryLockError::Poisoned(p)) => {
                    chosen = Some(p.into_inner());
                    break;
                }
                Err(TryLockError::WouldBlock) => continue,
            }
        }
        let Some(mut slot) = chosen else {
            return Err((EngineError::Busy, None));
        };
        if let Some((_, generation)) = prefer {
            if generation != slot.generation || slot.worker.is_none() {
                return Err((
                    EngineError::Lost("conversation_reset_required"),
                    Some((slot.index, slot.generation)),
                ));
            }
        }
        if slot.worker.is_none() {
            self.spawn(&mut slot)
                .map_err(|_| (EngineError::Lost("engine_start_failed"), None))?;
        }
        let deadline = Instant::now() + Duration::from_millis(self.config.startup_ms);
        if let Err(e) = wait_ready(&mut slot, deadline) {
            Self::retire(&mut slot);
            return Err((e, None));
        }
        let place = (slot.index, slot.generation);
        let id = self.sequence.fetch_add(1, Ordering::Relaxed);
        let request = json!({"id": id, "q": question, "session": session});
        let worker = slot.worker.as_mut().expect("started");
        let mut line = crate::wire::encode(&request);
        line.push(b'\n');
        if worker
            .stdin
            .write_all(&line)
            .and_then(|_| worker.stdin.flush())
            .is_err()
        {
            Self::retire(&mut slot);
            let _ = self.spawn(&mut slot);
            return Err((EngineError::Lost("worker_lost"), Some(place)));
        }
        let deadline = Instant::now() + Duration::from_millis(self.config.turn_ms);
        loop {
            let left = deadline.saturating_duration_since(Instant::now());
            let worker = slot.worker.as_mut().expect("started");
            match worker.lines.recv_timeout(left) {
                Ok(text) => {
                    if text.len() > self.config.reply_bytes {
                        Self::retire(&mut slot);
                        let _ = self.spawn(&mut slot);
                        return Err((EngineError::Lost("reply_too_large"), Some(place)));
                    }
                    let Ok(reply) = crate::wire::parse(text.as_bytes()) else {
                        continue;
                    };
                    if reply.get("id") != Some(&json!(id)) {
                        continue;
                    }
                    return Ok((reply, place.0, place.1));
                }
                Err(RecvTimeoutError::Timeout) => {
                    Self::retire(&mut slot);
                    let _ = self.spawn(&mut slot);
                    return Err((EngineError::Timeout, Some(place)));
                }
                Err(RecvTimeoutError::Disconnected) => {
                    Self::retire(&mut slot);
                    let _ = self.spawn(&mut slot);
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
        for slot in &self.slots {
            match slot.try_lock() {
                Ok(mut slot) => {
                    if let Some(worker) = slot.worker.as_mut() {
                        if !worker.is_ready && worker.ready.try_recv().is_ok() {
                            worker.is_ready = true;
                        }
                        if worker.is_ready {
                            ready += 1;
                        }
                    }
                    starts += slot.starts;
                    deaths += slot.deaths;
                }
                Err(_) => busy += 1,
            }
        }
        json!({"workers": self.slots.len(), "busy": busy, "ready_idle": ready, "starts": starts, "retired": deaths})
    }

    pub fn close(&self) {
        self.stopping.store(true, Ordering::Release);
        for slot in &self.slots {
            let mut slot = slot.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(worker) = slot.worker.as_mut() {
                // EOF asks the answerer to exit cleanly; then the group is reaped.
                let _ = worker.stdin.flush();
            }
            if let Some(mut worker) = slot.worker.take() {
                drop(worker.stdin);
                let deadline = Instant::now() + Duration::from_secs(5);
                while Instant::now() < deadline {
                    if let Ok(Some(_)) = worker.child.try_wait() {
                        break;
                    }
                    std::thread::sleep(Duration::from_millis(50));
                }
                let _ = nix::sys::signal::killpg(
                    nix::unistd::Pid::from_raw(worker.pid),
                    nix::sys::signal::Signal::SIGKILL,
                );
                let _ = worker.child.wait();
                let _ = std::fs::remove_file(&worker.pid_file);
            }
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

fn wait_ready(slot: &mut Slot, deadline: Instant) -> Result<(), EngineError> {
    let worker = slot.worker.as_mut().ok_or(EngineError::Starting)?;
    if worker.is_ready {
        return Ok(());
    }
    let left = deadline.saturating_duration_since(Instant::now());
    match worker.ready.recv_timeout(left) {
        Ok(()) => {
            worker.is_ready = true;
            Ok(())
        }
        Err(RecvTimeoutError::Timeout) => Err(EngineError::Starting),
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
