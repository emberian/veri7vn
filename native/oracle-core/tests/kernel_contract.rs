//! Subprocess transport contracts; the Python fixture is deliberately untrusted.
//! Passing these tests establishes neither Isabelle provenance nor panel scores.
#![cfg(unix)]
use oracle_runtime_core::{
    Cancellation, Error, KernelDescriptor, KernelExecutor, KernelFamily, KernelLimits,
    QuantitySpecialist,
};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

struct Fixture {
    _directory: tempfile::TempDir,
    path: PathBuf,
    sha: String,
}
impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("answerer");
        // Absolute interpreter, no subprocesses except the explicit inheritance
        // probe. Clearing the executable's environment must not break framing.
        let script = r##"#!/usr/bin/python3
import json, os, sys, time
count = 0
for line in sys.stdin:
    request = json.loads(line)
    q = request['q']
    count += 1
    if q == 'hang':
        while True: time.sleep(1)
    if q == 'flood':
        sys.stdout.write('x' * 200000); sys.stdout.flush()
        while True: time.sleep(1)
    if q == 'stderr':
        sys.stderr.write('x' * 200000); sys.stderr.flush()
        while True: time.sleep(1)
    if q == 'malformed':
        print('{bad', flush=True); continue
    if q == 'eof': sys.exit(0)
    if q == 'inherit':
        descendant = os.fork()
        if descendant == 0:
            while True: time.sleep(1)
        print(json.dumps(dict(id=request['id'], status='answered', response='ready',
                              path='specialist:fixture>ready', descendant=descendant)), flush=True)
        while True: time.sleep(1)
    if q == 'escape':
        if os.fork() == 0:
            os.setsid()
            # Keep the inherited pipes for a short period. Cleanup must not
            # block joining a pipe reader until this unrelated group exits.
            time.sleep(1)
            os._exit(0)
        while True: time.sleep(1)
    response = dict(id=request['id'], status='answered', response=q,
                    path='specialist:fixture>echo', count=count, pid=os.getpid(),
                    argv=sys.argv[1:], env=dict(os.environ),
                    provenance=dict(taken=True, kernel='fixture', theorems=['declaration-only']))
    if q == 'wrong-id': response['id'] = 999999999
    print(json.dumps(response), flush=True)
"##;
        fs::write(&path, script).unwrap();
        let sha = format!("{:x}", Sha256::digest(script.as_bytes()));
        Self {
            _directory: directory,
            path,
            sha,
        }
    }
    fn descriptor(&self, id: &str) -> KernelDescriptor {
        KernelDescriptor::new(id, &self.path, &self.sha, KernelFamily::Acoustics)
    }
    fn executor(&self, limits: KernelLimits) -> KernelExecutor {
        KernelExecutor::new(vec![self.descriptor("test")], limits).unwrap()
    }
}
fn ask(executor: &KernelExecutor, q: &str) -> Value {
    executor
        .execute("tenant", "test", q, Cancellation::default())
        .unwrap()
        .reply
}
fn wait_active(executor: &KernelExecutor) {
    let until = Instant::now() + Duration::from_secs(2);
    while executor.active_workers() == 0 {
        assert!(Instant::now() < until, "worker was never admitted");
        thread::sleep(Duration::from_millis(1));
    }
}

#[test]
fn admission_checks_actual_bytes_and_registry_is_not_a_correctness_attestation() {
    let f = Fixture::new();
    let bad = KernelDescriptor::new("test", &f.path, "0".repeat(64), KernelFamily::Acoustics);
    assert!(matches!(
        KernelExecutor::new(vec![bad], KernelLimits::default()),
        Err(Error::Format(_))
    ));
    let missing = KernelDescriptor::new(
        "test",
        f.path.with_extension("missing"),
        &f.sha,
        KernelFamily::Acoustics,
    );
    assert!(matches!(
        KernelExecutor::new(vec![missing], KernelLimits::default()),
        Err(Error::Io(_))
    ));
    let dup = vec![f.descriptor("same"), f.descriptor("same")];
    assert!(matches!(
        KernelExecutor::new(dup, KernelLimits::default()),
        Err(Error::Invalid(_))
    ));
    let executor = f.executor(KernelLimits::default());
    let admission = &executor.admissions()[0];
    assert_eq!(admission.executable_sha256, f.sha);
    assert_eq!(
        admission.executable_bytes,
        fs::metadata(&f.path).unwrap().len()
    );
    assert!(matches!(
        executor.execute("tenant", "absent", "hello", Cancellation::default()),
        Err(Error::Invalid(_))
    ));
}

#[test]
fn resident_is_reused_across_tenants_snapshot_survives_source_replacement() {
    let f = Fixture::new();
    let executor = f.executor(KernelLimits {
        workers: 1,
        ..KernelLimits::default()
    });
    // Admission owns copied bytes, not a mutable pathname checked earlier.
    fs::write(&f.path, b"this is no longer an executable").unwrap();
    let first = ask(&executor, "hello\nquoted \"text\"");
    let second = executor
        .execute("other", "test", "second", Cancellation::default())
        .unwrap();
    assert_eq!(first["response"], "hello\nquoted \"text\"");
    assert_eq!(second.reply["pid"], first["pid"]);
    assert_eq!(second.reply["count"], 2);
    assert_eq!(
        second.reply["provenance"]["theorems"][0],
        "declaration-only"
    );
    assert_eq!(executor.active_workers(), 0);
    // Python may establish LC_CTYPE internally; no ambient host variables pass.
    assert!(second.reply["env"]
        .as_object()
        .unwrap()
        .keys()
        .all(|k| k == "LC_CTYPE"));
}

#[test]
fn fixed_family_protocol_constructs_quantity_specialist_arguments() {
    let f = Fixture::new();
    let descriptor = KernelDescriptor::new(
        "units",
        &f.path,
        &f.sha,
        KernelFamily::Quantity {
            specialist: Some(QuantitySpecialist::UnitsV3),
        },
    );
    let executor = KernelExecutor::new(vec![descriptor], KernelLimits::default()).unwrap();
    let reply = executor
        .execute("tenant", "units", "echo", Cancellation::default())
        .unwrap();
    assert_eq!(
        reply.reply["argv"],
        serde_json::json!(["--specialist", "units-v3"])
    );
}

#[test]
fn request_bound_includes_json_escaping_and_envelope_before_process_start() {
    let f = Fixture::new();
    let executor = f.executor(KernelLimits {
        request_bytes: 100,
        ..KernelLimits::default()
    });
    assert!(matches!(
        executor.execute(
            "tenant",
            "test",
            &"\u{1}".repeat(30),
            Cancellation::default()
        ),
        Err(Error::Limit("kernel request bytes"))
    ));
    assert_eq!(executor.active_workers(), 0);
    assert_eq!(ask(&executor, "ok")["count"], 1);
}

#[test]
fn floods_malformed_ids_eof_and_deadline_retire_instead_of_reusing_stale_output() {
    let f = Fixture::new();
    let executor = f.executor(KernelLimits {
        workers: 1,
        reply_bytes: 4096,
        stderr_bytes: 1024,
        timeout_ms: 150,
        ..KernelLimits::default()
    });
    let mut pid = ask(&executor, "initial")["pid"].as_u64().unwrap();
    for q in ["flood", "stderr", "malformed", "wrong-id", "eof", "hang"] {
        let result = executor.execute("tenant", "test", q, Cancellation::default());
        match q {
            "flood" => assert!(matches!(result, Err(Error::Limit("kernel reply bytes")))),
            "stderr" => assert!(matches!(result, Err(Error::Limit("kernel stderr bytes")))),
            "hang" => assert!(matches!(result, Err(Error::Deadline))),
            _ => assert!(result.is_err()),
        }
        assert_eq!(executor.active_workers(), 0);
        // Only our process is probed, never a process name or unrelated PID.
        assert_eq!(
            nix::sys::signal::kill(nix::unistd::Pid::from_raw(pid as i32), None),
            Err(nix::errno::Errno::ESRCH)
        );
        let reply = ask(&executor, "recovered");
        assert_eq!(reply["count"], 1);
        pid = reply["pid"].as_u64().unwrap();
    }
}

#[test]
fn cancellation_holds_admission_until_child_and_all_io_have_joined() {
    let f = Fixture::new();
    let executor = Arc::new(f.executor(KernelLimits {
        workers: 1,
        timeout_ms: 5000,
        ..KernelLimits::default()
    }));
    // Wait for the fixture's explicit fork acknowledgement, so cancellation
    // actually exercises an inherited pipe rather than racing process start.
    let descendant = ask(&executor, "inherit")["descendant"].as_u64().unwrap();
    assert!(descendant > 0);
    let cancel = Cancellation::default();
    let run = executor.clone();
    let token = cancel.clone();
    let worker = thread::spawn(move || run.execute("tenant", "test", "hang", token));
    wait_active(&executor);
    assert!(matches!(
        executor.execute("tenant", "test", "other", Cancellation::default()),
        Err(Error::Busy)
    ));
    assert!(matches!(
        executor.execute("other", "test", "other", Cancellation::default()),
        Err(Error::Busy)
    ));
    cancel.cancel();
    assert!(matches!(worker.join().unwrap(), Err(Error::Cancelled)));
    assert_eq!(executor.active_workers(), 0);
    #[cfg(target_os = "linux")]
    {
        let until = Instant::now() + Duration::from_secs(1);
        while let Ok(stat) = fs::read_to_string(format!("/proc/{descendant}/stat")) {
            // Orphans may briefly remain zombies under the host's subreaper;
            // they must not continue holding the inherited pipe descriptors.
            let state = stat.rsplit_once(") ").unwrap().1.as_bytes()[0];
            if state == b'Z' || state == b'X' {
                break;
            }
            assert!(
                Instant::now() < until,
                "descendant survived owned group cleanup"
            );
            thread::sleep(Duration::from_millis(2));
        }
    }
    assert_eq!(ask(&executor, "usable again")["count"], 1);
}

#[test]
fn nonblocking_cleanup_does_not_wait_for_an_escaped_pipe_holder() {
    let f = Fixture::new();
    let executor = f.executor(KernelLimits {
        workers: 1,
        timeout_ms: 200,
        ..KernelLimits::default()
    });
    let started = Instant::now();
    assert!(matches!(
        executor.execute("tenant", "test", "escape", Cancellation::default()),
        Err(Error::Deadline)
    ));
    assert!(
        started.elapsed() < Duration::from_millis(900),
        "cleanup waited for an inherited pipe EOF"
    );
    assert_eq!(executor.active_workers(), 0);
    assert_eq!(ask(&executor, "recovered")["count"], 1);
}

#[test]
fn pre_cancel_and_drop_reap_without_spawning_per_tenant() {
    let f = Fixture::new();
    let executor = f.executor(KernelLimits {
        workers: 1,
        ..KernelLimits::default()
    });
    let token = Cancellation::default();
    token.cancel();
    assert!(matches!(
        executor.execute("tenant", "test", "first", token),
        Err(Error::Cancelled)
    ));
    let pid = ask(&executor, "first")["pid"].as_u64().unwrap();
    for n in 0..64 {
        let reply = executor
            .execute(
                &format!("tenant-{n}"),
                "test",
                "hello",
                Cancellation::default(),
            )
            .unwrap();
        assert_eq!(reply.reply["pid"], pid);
    }
    drop(executor);
    assert_eq!(
        nix::sys::signal::kill(nix::unistd::Pid::from_raw(pid as i32), None),
        Err(nix::errno::Errno::ESRCH)
    );
}

/// Root qualification explicitly supplies a real artifact and its trusted hash.
/// This is protocol/composition evidence; shipped-panel scoring is separate.
#[test]
#[ignore = "requires an explicitly supplied current extracted quantity artifact"]
fn real_quantity_resident_protocol() {
    let path = std::env::var("ORACLE_TEST_QUANTITY_BIN").expect("absolute quantity binary");
    let sha = std::env::var("ORACLE_TEST_QUANTITY_SHA256").expect("trusted quantity SHA-256");
    let executor = KernelExecutor::new(
        vec![KernelDescriptor::new(
            "quantity",
            path,
            sha,
            KernelFamily::Quantity {
                specialist: Some(QuantitySpecialist::Units),
            },
        )],
        KernelLimits::default(),
    )
    .unwrap();
    for (q, expected) in [
        ("Convert 2 metres to centimetres", Some(200.0)),
        ("Who wrote Leaves of Grass?", None),
        ("Convert 3 metres to centimetres", Some(300.0)),
    ] {
        let reply = executor
            .execute("qualification", "quantity", q, Cancellation::default())
            .unwrap();
        if let Some(value) = expected {
            assert_eq!(reply.reply["status"], "answered");
            assert_eq!(reply.reply["value"].as_f64(), Some(value));
            assert_eq!(reply.reply["provenance"]["kernel"], "Quantity.reply_of");
            assert_eq!(reply.reply["provenance"]["taken"], true);
        } else {
            assert_eq!(reply.reply["status"], "withheld");
            assert_eq!(reply.reply["provenance"]["taken"], false);
        }
    }
    assert_eq!(executor.active_workers(), 0);
}
