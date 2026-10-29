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

impl Fixture {
    fn mst() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("mst-checker");
        // Deliberately untrusted protocol fixture, not an extracted predicate.
        // Exhaustive tiny-graph scoring avoids merely echoing chosen edge IDs.
        let script = r##"#!/usr/bin/python3
import itertools, sys, time
for line in sys.stdin:
    fields = line.rstrip('\n').split(' ')
    assert fields[0] == 'mst-cert-v2'
    rid, n, m, k = map(int, fields[1:5])
    numbers = list(map(int, fields[5:]))
    edges = [numbers[i:i+3] for i in range(0, 3*m, 3)]
    ids = numbers[3*m:]
    assert len(ids) == k
    assert all(0 <= a < n and 0 <= b < n for a,b,w in edges)
    assert len(set(ids)) == k and all(0 <= i < m for i in ids)
    if edges and edges[0][2] == 1001:
        while True: time.sleep(1)
    if edges and edges[0][2] == 1002:
        print('x' * 200000, flush=True)
        while True: time.sleep(1)
    if edges and edges[0][2] == 1003:
        print('mst-cert-v2 wrong accept', flush=True); continue
    if edges and edges[0][2] == 1004:
        print('mst-cert-v2 %d unsupported' % rid, flush=True); continue
    def component_count(selected):
        parent = list(range(n))
        def root(i):
            while i != parent[i]: i = parent[i]
            return i
        for i in selected:
            a,b,w = edges[i]
            parent[root(a)] = root(b)
        return len(set(root(i) for i in range(n)))
    if n < 2 or component_count(range(m)) != 1: status = 'unsupported'
    else:
        candidates = [sum(edges[i][2] for i in c)
                      for c in itertools.combinations(range(m), n-1)
                      if component_count(c) == 1]
        status = ('accept' if k == n-1 and component_count(ids) == 1
                  and sum(edges[i][2] for i in ids) == min(candidates) else 'reject')
    print('mst-cert-v2 %d %s' % (rid, status), flush=True)
"##;
        fs::write(&path, script).unwrap();
        let sha = format!("{:x}", Sha256::digest(script.as_bytes()));
        Self {
            _directory: directory,
            path,
            sha,
        }
    }
    fn mst_executor(&self, limits: KernelLimits) -> KernelExecutor {
        KernelExecutor::new(
            vec![KernelDescriptor::new(
                "mst",
                &self.path,
                &self.sha,
                KernelFamily::MstCertificate,
            )],
            limits,
        )
        .unwrap()
    }
}

#[test]
fn mst_resident_exact_ids_weights_and_unsupported_reuse_do_not_confer_proof_scope() {
    use oracle_runtime_core::kernel::MstGraph;
    let f = Fixture::mst();
    let executor = f.mst_executor(KernelLimits {
        workers: 1,
        ..KernelLimits::default()
    });
    let graph = MstGraph {
        vertices: 3,
        edges: vec![(0, 1, i64::MIN), (1, 2, i64::MIN), (0, 2, i64::MAX)],
    };
    let first = executor
        .check_mst("tenant", "mst", &graph, &[0, 1], Cancellation::default())
        .unwrap();
    assert_eq!(first.reply["status"], "accepted");
    assert_eq!(first.reply["total_weight"], "-18446744073709551616");
    assert_eq!(first.reply["evidence"]["kind"], "none");
    assert!(first.admission.compiled_receipt_sha256.is_none());
    let bad = executor
        .check_mst("tenant", "mst", &graph, &[0, 2], Cancellation::default())
        .unwrap();
    assert_eq!(bad.reply["status"], "rejected");
    assert_eq!(bad.worker_pid, first.worker_pid);
    for (vertices, edges, ids) in [
        (4, vec![(0, 1, 1), (2, 3, 2)], vec![0, 1]),
        (3, vec![(0, 1, 1)], vec![0]),
        (1, vec![], vec![]),
        (0, vec![], vec![]),
    ] {
        let reply = executor
            .check_mst(
                "other",
                "mst",
                &MstGraph { vertices, edges },
                &ids,
                Cancellation::default(),
            )
            .unwrap();
        assert_eq!(reply.reply["status"], "unsupported");
        assert_eq!(reply.reply["evidence"]["kind"], "none");
        assert_eq!(reply.worker_pid, first.worker_pid);
    }
    let parallel = MstGraph {
        vertices: 2,
        edges: vec![(0, 1, 4), (0, 1, -2), (0, 1, -2), (0, 0, -100)],
    };
    for id in [1, 2] {
        let reply = executor
            .check_mst("tenant", "mst", &parallel, &[id], Cancellation::default())
            .unwrap();
        assert_eq!(reply.reply["status"], "accepted");
        assert_eq!(reply.reply["edge_ids"], serde_json::json!([id]));
        assert_eq!(reply.worker_pid, first.worker_pid);
    }
    let again = executor
        .check_mst("tenant", "mst", &graph, &[0, 1], Cancellation::default())
        .unwrap();
    assert_eq!(again.worker_pid, first.worker_pid);
    assert_eq!(again.reply["input_sha256"], first.reply["input_sha256"]);
}

#[test]
fn mst_universe_and_candidate_validation_precedes_start_and_hashes_full_edge_order() {
    use oracle_runtime_core::kernel::MstGraph;
    let f = Fixture::mst();
    let executor = f.mst_executor(KernelLimits::default());
    let graph = MstGraph {
        vertices: 3,
        edges: vec![(0, 1, 1), (1, 2, 2), (0, 2, 9)],
    };
    for ids in [vec![0, 0], vec![0, 3], vec![0, 1, 2]] {
        assert!(executor
            .check_mst("tenant", "mst", &graph, &ids, Cancellation::default())
            .is_err());
    }
    assert!(executor
        .check_mst(
            "tenant",
            "mst",
            &MstGraph {
                vertices: 2,
                edges: vec![(0, 2, 1)]
            },
            &[0],
            Cancellation::default()
        )
        .is_err());
    assert!(executor
        .execute(
            "tenant",
            "mst",
            "not a certificate",
            Cancellation::default()
        )
        .is_err());
    let first = executor
        .check_mst("tenant", "mst", &graph, &[0, 1], Cancellation::default())
        .unwrap();
    let reordered = MstGraph {
        vertices: 3,
        edges: vec![(1, 2, 2), (0, 1, 1), (0, 2, 9)],
    };
    let second = executor
        .check_mst(
            "tenant",
            "mst",
            &reordered,
            &[1, 0],
            Cancellation::default(),
        )
        .unwrap();
    assert_ne!(first.reply["input_sha256"], second.reply["input_sha256"]);
    assert_eq!(first.worker_pid, second.worker_pid);
    assert!(serde_json::from_str::<MstGraph>(r#"{"vertices":2,"edges":[[0,1,1.0]]}"#).is_err());
    assert!(serde_json::from_str::<MstGraph>(
        r#"{"vertices":2,"edges":[[0,1,9223372036854775808]]}"#
    )
    .is_err());
}

#[test]
fn mst_timeout_oversized_malformed_and_wrong_scope_replies_retire_owned_worker() {
    use oracle_runtime_core::kernel::MstGraph;
    let f = Fixture::mst();
    let executor = f.mst_executor(KernelLimits {
        workers: 1,
        reply_bytes: 128,
        timeout_ms: 150,
        ..KernelLimits::default()
    });
    let graph = MstGraph {
        vertices: 2,
        edges: vec![(0, 1, 4)],
    };
    let mut pid = executor
        .check_mst("tenant", "mst", &graph, &[0], Cancellation::default())
        .unwrap()
        .worker_pid;
    for weight in [1001, 1002, 1003, 1004] {
        let attack = MstGraph {
            vertices: 2,
            edges: vec![(0, 1, weight)],
        };
        let reply = executor.check_mst("tenant", "mst", &attack, &[0], Cancellation::default());
        match weight {
            1001 => assert!(matches!(reply, Err(Error::Deadline))),
            1002 => assert!(matches!(reply, Err(Error::Limit("kernel reply bytes")))),
            _ => assert!(matches!(reply, Err(Error::Format(_)))),
        }
        assert_eq!(executor.active_workers(), 0);
        assert_eq!(
            nix::sys::signal::kill(nix::unistd::Pid::from_raw(pid as i32), None),
            Err(nix::errno::Errno::ESRCH)
        );
        let recovered = executor
            .check_mst("tenant", "mst", &graph, &[0], Cancellation::default())
            .unwrap();
        assert_ne!(recovered.worker_pid, pid);
        pid = recovered.worker_pid;
    }
}

#[test]
fn mst_request_bytes_and_forged_compiler_receipts_are_rejected() {
    use oracle_runtime_core::kernel::MstGraph;
    let f = Fixture::mst();
    let executor = f.mst_executor(KernelLimits {
        request_bytes: 20,
        ..KernelLimits::default()
    });
    assert!(matches!(
        executor.check_mst(
            "tenant",
            "mst",
            &MstGraph {
                vertices: 2,
                edges: vec![(0, 1, 4)]
            },
            &[0],
            Cancellation::default()
        ),
        Err(Error::Limit("kernel request bytes"))
    ));
    let path = f._directory.path().join("compile-inputs.json");
    let forged = serde_json::json!({"compile_ok":true,"binary_sha256":f.sha,"session":"Veri7vn_Discrete_Certificate"}).to_string();
    fs::write(&path, &forged).unwrap();
    let descriptor = KernelDescriptor::new("mst", &f.path, &f.sha, KernelFamily::MstCertificate)
        .with_compiled_receipt(&path, format!("{:x}", Sha256::digest(forged.as_bytes())));
    assert!(matches!(
        KernelExecutor::new(vec![descriptor], KernelLimits::default()),
        Err(Error::Format(_))
    ));
}

/// Actual extracted artifact; root supplies new v2 compiled bytes and optionally
/// an operator-admitted compiler receipt. No mock gains HOL scope in this test.
#[test]
#[ignore = "requires an explicitly supplied current resident extracted MST artifact"]
fn real_mst_resident_protocol() {
    use oracle_runtime_core::kernel::MstGraph;
    let path = std::env::var("ORACLE_TEST_MST_BIN").expect("absolute MST binary");
    let sha = std::env::var("ORACLE_TEST_MST_SHA256").expect("trusted MST SHA-256");
    let mut descriptor = KernelDescriptor::new("mst", path, sha, KernelFamily::MstCertificate);
    let receipt = std::env::var("ORACLE_TEST_MST_COMPILED_RECEIPT").ok();
    if let Some(path) = &receipt {
        descriptor = descriptor.with_compiled_receipt(
            path,
            std::env::var("ORACLE_TEST_MST_COMPILED_RECEIPT_SHA256")
                .expect("trusted receipt digest"),
        );
    }
    let executor = KernelExecutor::new(
        vec![descriptor],
        KernelLimits {
            workers: 1,
            ..KernelLimits::default()
        },
    )
    .unwrap();
    let graph = MstGraph {
        vertices: 3,
        edges: vec![(0, 1, 4), (1, 2, 1), (0, 2, 7)],
    };
    let accepted = executor
        .check_mst(
            "qualification",
            "mst",
            &graph,
            &[0, 1],
            Cancellation::default(),
        )
        .unwrap();
    assert_eq!(accepted.reply["status"], "accepted");
    assert_eq!(
        accepted.reply["evidence"]["kind"],
        if receipt.is_some() {
            "extracted_hol_connected_mst"
        } else {
            "none"
        }
    );
    let rejected = executor
        .check_mst(
            "qualification",
            "mst",
            &graph,
            &[0, 2],
            Cancellation::default(),
        )
        .unwrap();
    assert_eq!(rejected.reply["status"], "rejected");
    let unsupported = executor
        .check_mst(
            "qualification",
            "mst",
            &MstGraph {
                vertices: 4,
                edges: graph.edges.clone(),
            },
            &[0, 1],
            Cancellation::default(),
        )
        .unwrap();
    assert_eq!(unsupported.reply["status"], "unsupported");
    let final_reply = executor
        .check_mst(
            "qualification",
            "mst",
            &graph,
            &[0, 1],
            Cancellation::default(),
        )
        .unwrap();
    assert_eq!(accepted.worker_pid, rejected.worker_pid);
    assert_eq!(accepted.worker_pid, unsupported.worker_pid);
    assert_eq!(accepted.worker_pid, final_reply.worker_pid);
}

#[test]
fn mst_cancellation_uses_shared_admission_and_reaps_before_recovery() {
    use oracle_runtime_core::kernel::MstGraph;
    let f = Fixture::mst();
    let executor = Arc::new(f.mst_executor(KernelLimits {
        workers: 1,
        timeout_ms: 5000,
        ..KernelLimits::default()
    }));
    let normal = MstGraph {
        vertices: 2,
        edges: vec![(0, 1, 4)],
    };
    let first = executor
        .check_mst("tenant", "mst", &normal, &[0], Cancellation::default())
        .unwrap();
    let token = Cancellation::default();
    let cancel = token.clone();
    let run = executor.clone();
    let thread = thread::spawn(move || {
        run.check_mst(
            "tenant",
            "mst",
            &MstGraph {
                vertices: 2,
                edges: vec![(0, 1, 1001)],
            },
            &[0],
            cancel,
        )
    });
    wait_active(&executor);
    assert!(matches!(
        executor.check_mst("other", "mst", &normal, &[0], Cancellation::default()),
        Err(Error::Busy)
    ));
    token.cancel();
    assert!(matches!(thread.join().unwrap(), Err(Error::Cancelled)));
    assert_eq!(executor.active_workers(), 0);
    assert_eq!(
        nix::sys::signal::kill(nix::unistd::Pid::from_raw(first.worker_pid as i32), None),
        Err(nix::errno::Errno::ESRCH)
    );
    let next = executor
        .check_mst("tenant", "mst", &normal, &[0], Cancellation::default())
        .unwrap();
    assert_ne!(next.worker_pid, first.worker_pid);
}
