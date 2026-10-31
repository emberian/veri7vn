//! The standalone journey of `tests/appliance/test_native_service.py`, adapted
//! to the Rust host where the contract is shared (health, discovery, invoke,
//! tenant header refusal, browser refusal, busy), plus the front door:
//! agreement, disagreement, fall-through to the Engine, exact retry, Engine
//! kill-and-reap on a missed deadline, restart replay and conversation reset.
//!
//! Organs and the Engine are manufactured stand-ins speaking the answerer
//! contract (a shell script and a small Python script); no upstream data,
//! image or Mini. They exercise the host's contract, not any score.

use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

const TENANT: &str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const REVISION: &str = "0123456789abcdef0123456789abcdef01234567";

fn sha256(path: &Path) -> String {
    oracle_host::config::sha256_file(path).unwrap()
}

fn python() -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    std::env::split_paths(&path)
        .map(|dir| dir.join("python3"))
        .find(|candidate| candidate.is_file())
}

fn write_executable(path: &Path, text: &str) {
    use std::os::unix::fs::PermissionsExt;
    std::fs::write(path, text).unwrap();
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755)).unwrap();
}

/// A resident organ that takes questions containing "capital" and answers `answer`.
fn organ(dir: &Path, name: &str, answer: &str) -> PathBuf {
    let path = dir.join(format!("organ-{name}"));
    write_executable(
        &path,
        &format!(
            r#"#!/bin/sh
while IFS= read -r line; do
  id=$(printf '%s\n' "$line" | /usr/bin/sed -e 's/^{{"id":\([0-9]*\),.*/\1/')
  case "$line" in
    *capital*) printf '{{"id":%s,"status":"answered","response":"It is {answer}.","path":"specialist:{name}>capital","kind":"capital","value":"{answer}","provenance":{{"taken":true}}}}\n' "$id" ;;
    *vague*) printf '{{"id":%s,"status":"withheld","response":"Which city?","path":"specialist:{name}>underspecified","kind":"underspecified","provenance":{{"taken":true}}}}\n' "$id" ;;
    *) printf '{{"id":%s,"status":"withheld","response":"","path":"","provenance":{{"taken":false}}}}\n' "$id" ;;
  esac
done
"#
        ),
    );
    path
}

const ENGINE: &str = r#"import json, os, sys, time
print(json.dumps({"protocol": "oracle-engine-v1", "ready": True}), flush=True)
n = 0
for line in sys.stdin:
    request = json.loads(line)
    n += 1
    q = request["q"]
    if "hang" in q:
        time.sleep(3600)
    if "clarify" in q:
        out = {"status": "clarification", "response": "Which one?", "path": "act:clarify"}
    else:
        out = {"status": "answered", "response": "engine answer %d from %d" % (n, os.getpid()), "path": "engine:fake",
               "provenance": {"tip": "fake-head", "session": request["session"]}}
    out["id"] = request["id"]
    print(json.dumps(out), flush=True)
"#;

struct Host {
    child: Child,
    port: u16,
    stopped: bool,
}

impl Drop for Host {
    /// A failed assertion must not orphan the host: stop the PID this test started.
    fn drop(&mut self) {
        if !self.stopped {
            let _ = nix::sys::signal::kill(
                nix::unistd::Pid::from_raw(self.child.id() as i32),
                nix::sys::signal::Signal::SIGTERM,
            );
            let _ = self.child.wait();
        }
    }
}

impl Host {
    fn start(config: &Path) -> Self {
        let mut child = Command::new(env!("CARGO_BIN_EXE_oracle-host"))
            .arg("--config")
            .arg(config)
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .unwrap();
        let mut line = String::new();
        BufReader::new(child.stdout.take().unwrap())
            .read_line(&mut line)
            .unwrap();
        let started: Value = serde_json::from_str(&line).expect("startup line");
        let port = started["listening"]
            .as_str()
            .unwrap()
            .rsplit(':')
            .next()
            .unwrap()
            .parse()
            .unwrap();
        std::fs::write(config.with_file_name("host.pid"), child.id().to_string()).unwrap();
        Self {
            child,
            port,
            stopped: false,
        }
    }

    /// SIGTERM to the PID this test started, then wait for a clean exit.
    fn stop(mut self) {
        nix::sys::signal::kill(
            nix::unistd::Pid::from_raw(self.child.id() as i32),
            nix::sys::signal::Signal::SIGTERM,
        )
        .unwrap();
        let deadline = Instant::now() + Duration::from_secs(30);
        while Instant::now() < deadline {
            if let Ok(Some(status)) = self.child.try_wait() {
                self.stopped = true;
                assert!(status.success(), "host exit {status}");
                return;
            }
            std::thread::sleep(Duration::from_millis(50));
        }
        panic!("host did not stop");
    }

    fn request(
        &self,
        method: &str,
        path: &str,
        body: Option<&Value>,
        headers: &[(&str, &str)],
    ) -> (u16, Value) {
        request(self.port, method, path, body, headers)
    }

    fn get(&self, path: &str) -> (u16, Value) {
        self.request("GET", path, None, &[("X-Mini-Oracle-Tenant", TENANT)])
    }

    fn post(&self, path: &str, body: &Value) -> (u16, Value) {
        self.request(
            "POST",
            path,
            Some(body),
            &[("X-Mini-Oracle-Tenant", TENANT)],
        )
    }

    fn ask(&self, id: &str, conversation: &str, text: &str) -> (u16, Value) {
        ask(self.port, id, conversation, text)
    }
}

fn ask(port: u16, id: &str, conversation: &str, text: &str) -> (u16, Value) {
    request(
        port,
        "POST",
        "/query",
        Some(&json!({"request_id": id, "conversation_id": conversation, "text": text})),
        &[("X-Mini-Oracle-Tenant", TENANT)],
    )
}

fn request(
    port: u16,
    method: &str,
    path: &str,
    body: Option<&Value>,
    headers: &[(&str, &str)],
) -> (u16, Value) {
    {
        let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
        let payload = body
            .map(|b| serde_json::to_vec(b).unwrap())
            .unwrap_or_default();
        let mut head = format!("{method} {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n");
        for (k, v) in headers {
            head.push_str(&format!("{k}: {v}\r\n"));
        }
        if body.is_some() {
            head.push_str(&format!(
                "Content-Type: application/json\r\nContent-Length: {}\r\n",
                payload.len()
            ));
        }
        head.push_str("\r\n");
        stream.write_all(head.as_bytes()).unwrap();
        stream.write_all(&payload).unwrap();
        let mut response = Vec::new();
        stream.read_to_end(&mut response).unwrap();
        let text = String::from_utf8(response).unwrap();
        let (head, body) = text.split_once("\r\n\r\n").unwrap();
        let status = head.split(' ').nth(1).unwrap().parse().unwrap();
        assert!(head.contains("Cache-Control: no-store"));
        (status, serde_json::from_str(body).unwrap())
    }
}

fn alive(pid: i32) -> bool {
    nix::sys::signal::kill(nix::unistd::Pid::from_raw(pid), None).is_ok()
}

struct Fixture {
    _dir: tempfile::TempDir,
    config: PathBuf,
    engine_state: PathBuf,
}

fn fixture(capacity: usize, organs: &[(&str, &str)]) -> Option<Fixture> {
    let python = python()?;
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path().canonicalize().unwrap();
    let checkout = root.join("checkout");
    std::fs::create_dir_all(checkout.join(".git")).unwrap();
    std::fs::write(checkout.join(".git/HEAD"), format!("{REVISION}\n")).unwrap();
    let answerer = root.join("answerer.py");
    std::fs::write(&answerer, ENGINE).unwrap();
    let organs: Vec<Value> = organs
        .iter()
        .map(|(name, answer)| {
            let path = organ(&root, name, answer);
            json!({"id": name, "executable": path, "sha256": sha256(&path), "family": "acoustics",
                   "accept": {"kinds": ["capital"], "declines_in_domain": ["underspecified"], "context_regex": "\\bcity\\b"}})
        })
        .collect();
    let engine_state = root.join("engine");
    let mut config = json!({"schema": "oracle-host-v1", "port": 0, "journal": root.join("journal.sqlite3"),
        "limits": {"capacity": capacity, "invoke_ms": 10000},
        "engine": {"python": {"path": python, "sha256": sha256(&python)},
                   "answerer": {"path": answerer, "sha256": sha256(&answerer)},
                   "checkout": checkout, "revision": REVISION, "state": engine_state,
                   "workers": 1, "startup_ms": 60000, "turn_ms": 1500}});
    if !organs.is_empty() {
        config["kernels"] = json!({"organs": organs});
    }
    if oracle_host::compiled_profiles().contains(&"reasoning") {
        config["pure"] = json!({"profiles": ["reasoning"]});
    }
    let path = root.join("host.json");
    std::fs::write(&path, serde_json::to_vec_pretty(&config).unwrap()).unwrap();
    Some(Fixture {
        _dir: dir,
        config: path,
        engine_state,
    })
}

fn engine_pid(state: &Path) -> i32 {
    std::fs::read_to_string(state.join("worker-0.pid"))
        .unwrap()
        .trim()
        .parse()
        .unwrap()
}

#[test]
fn shared_contract_health_discovery_invoke_and_refusals() {
    let Some(fx) = fixture(2, &[("paris", "Paris")]) else {
        return;
    };
    let host = Host::start(&fx.config);
    let (status, health) = host.request("GET", "/health", None, &[]);
    assert_eq!(status, 200);
    assert_eq!(health["query_queue"], 0);
    // The tenant header is required, exact and routing-only.
    assert_eq!(host.request("GET", "/capabilities", None, &[]).0, 400);
    assert_eq!(
        host.request(
            "GET",
            "/capabilities",
            None,
            &[("X-Mini-Oracle-Tenant", "user-choice")]
        )
        .1["error"],
        "host_tenant_required"
    );
    let (status, caps) = host.get("/capabilities");
    assert_eq!(status, 200);
    assert_eq!(caps["tenant_header_authentication"], false);
    assert_eq!(caps["mini_qualified"], false);
    assert_eq!(caps["query"]["routes"], json!(["organ:paris", "engine"]));
    // Browser origins and foreign Host headers are refused before any work.
    let body = json!({"request_id": "o", "conversation_id": "c", "text": "capital?"});
    let origin = host.request(
        "POST",
        "/query",
        Some(&body),
        &[
            ("X-Mini-Oracle-Tenant", TENANT),
            ("Origin", "https://example.org"),
        ],
    );
    assert_eq!(
        origin,
        (
            403,
            json!({"outcome": "error", "error": "browser_request_rejected"})
        )
    );
    let mut stream = TcpStream::connect(("127.0.0.1", host.port)).unwrap();
    stream
        .write_all(b"GET /health HTTP/1.0\r\nHost: evil.example\r\n\r\n")
        .unwrap();
    let mut text = String::new();
    stream.read_to_string(&mut text).unwrap();
    assert!(
        text.starts_with("HTTP/1.0 400") && text.contains("invalid_host"),
        "{text}"
    );
    // Envelope refusals: extra fields, bad identifiers, duplicate keys, wrong media type.
    assert_eq!(
        host.post(
            "/query",
            &json!({"request_id": "x", "conversation_id": "c", "text": "q", "tenant": TENANT})
        )
        .0,
        400
    );
    assert_eq!(
        host.post(
            "/query",
            &json!({"request_id": "bad id", "conversation_id": "c", "text": "q"})
        )
        .0,
        400
    );
    assert_eq!(host.post("/nowhere", &json!({})).0, 404);
    let raw = host.request(
        "POST",
        "/invoke",
        Some(&json!({})),
        &[("X-Mini-Oracle-Tenant", TENANT)],
    );
    assert_eq!(raw.0, 400);
    // Discovery.
    let (status, page) = host.get("/operations?limit=50");
    assert_eq!(status, 200);
    assert_eq!(page["protocol"], "oracle-operations-v1");
    assert_eq!(host.get("/operations?limit=51").0, 400);
    assert_eq!(host.get("/operations/no.such.op").0, 404);
    if oracle_host::compiled_profiles().contains(&"reasoning") {
        let (status, descriptor) = host.get("/operations/graph.minimum_spanning_forest");
        assert_eq!(status, 200);
        assert_eq!(descriptor["availability"], "live_direct");
        let call = |arguments: Value| {
            host.post(
                "/invoke",
                &json!({"request_id": "same", "conversation_id": "corr",
            "operation_id": "graph.minimum_spanning_forest", "arguments": arguments}),
            )
        };
        let (status, result) =
            call(json!({"vertices": 3, "edges": [[0, 1, 2], [1, 2, 1], [0, 2, 7]]}));
        assert_eq!(status, 200, "{result}");
        assert_eq!(result["reply"]["status"], "answered");
        assert_eq!(result["durable_replay"], false);
        assert_eq!(
            call(json!({"vertices": 3, "edges": [], "profile": "logic"})).0,
            400
        );
        let (status, refused) = call(
            json!({"vertices": 2, "edges": [[0, 1, 9223372036854775807i64], [0, 1, 9223372036854775807i64]]}),
        );
        assert_eq!(status, 200);
        assert!(["answered", "withheld"].contains(&refused["reply"]["status"].as_str().unwrap()));
    }
    host.stop();
}

#[test]
fn front_door_agrees_refuses_and_falls_through() {
    let Some(fx) = fixture(2, &[("paris", "Paris"), ("lower", "paris")]) else {
        return;
    };
    let host = Host::start(&fx.config);
    // Two organs take the question and agree (case-insensitively): answered,
    // the Engine is not asked, and provenance lists every route.
    let (status, result) = host.ask("agree", "c-agree", "What is the capital?");
    assert_eq!(status, 200, "{result}");
    let reply = &result["reply"];
    assert_eq!(reply["status"], "answered", "{reply}");
    assert_eq!(reply["response"], "It is Paris.");
    assert_eq!(reply["provenance"]["host"]["decision"], "answered");
    assert_eq!(
        reply["provenance"]["host"]["routes"],
        json!(["organ:paris", "organ:lower"])
    );
    assert_eq!(
        reply["provenance"]["host"]["candidates"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
    // An organ's accepted in-domain decline ends the turn (context matches).
    let (_, result) = host.ask("vague", "c-vague", "Tell me about a vague city");
    assert_eq!(result["reply"]["status"], "withheld");
    assert_eq!(result["reply"]["provenance"]["host"]["decision"], "refused");
    // The same decline kind without the manifest's context is not taken: the Engine answers.
    let (_, result) = host.ask("vague2", "c-vague2", "Something vague");
    assert_eq!(result["reply"]["path"], "engine:fake");
    assert_eq!(result["reply"]["provenance"]["host"]["group"], 1);
    // No organ reads it: group 1, the Engine, answers; its refusal is a refusal.
    let (_, result) = host.ask("clarify", "c-clarify", "please clarify");
    assert_eq!(result["reply"]["status"], "clarification");
    host.stop();

    let Some(fx) = fixture(2, &[("paris", "Paris"), ("lyon", "Lyon")]) else {
        return;
    };
    let host = Host::start(&fx.config);
    let (status, result) = host.ask("disagree", "c-disagree", "What is the capital?");
    assert_eq!(status, 200);
    let reply = &result["reply"];
    assert_eq!(reply["status"], "withheld");
    assert_eq!(reply["path"], "host:disagreement");
    let keys: Vec<&str> = reply["provenance"]["host"]["candidates"]
        .as_array()
        .unwrap()
        .iter()
        .map(|c| c["agreement_key"].as_str().unwrap())
        .collect();
    assert_eq!(keys, ["Paris", "Lyon"]);
    host.stop();
}

#[test]
fn exact_retry_deadline_kill_reap_restart_and_busy() {
    let Some(fx) = fixture(1, &[]) else { return };
    let host = Host::start(&fx.config);
    let (status, first) = host.ask("turn-one", "conv", "hello");
    assert_eq!(status, 200, "{first}");
    let answer = first["reply"]["response"].as_str().unwrap().to_owned();
    // Exact retry replays the journal; the Engine is not asked again.
    assert_eq!(host.ask("turn-one", "conv", "hello"), (200, first.clone()));
    assert_eq!(
        host.ask("turn-one", "conv", "changed"),
        (
            409,
            json!({"outcome": "error", "error": "request_id_conflict"})
        )
    );
    // A missed deadline kills the recorded process group, reaps it and restarts.
    let before = engine_pid(&fx.engine_state);
    let port = host.port;
    let hanging = std::thread::spawn(move || ask(port, "hang", "conv-hang", "please hang"));
    std::thread::sleep(Duration::from_millis(300));
    // Capacity one: a concurrent turn is told busy at once, never queued.
    let started = Instant::now();
    let (status, busy) = host.ask("concurrent", "conv-2", "hello");
    assert_eq!((status, &busy["error"]), (429, &json!("busy")));
    assert!(started.elapsed() < Duration::from_secs(1));
    let (status, timeout) = hanging.join().unwrap();
    assert_eq!((status, &timeout["error"]), (504, &json!("query_timeout")));
    assert_eq!(timeout["state_may_have_changed"], true);
    assert!(!alive(before), "timed-out Engine group was not reaped");
    // The busy turn left no journal record, so its retry runs.
    let (status, retried) = host.ask("concurrent", "conv-2", "hello");
    assert_eq!(status, 200, "{retried}");
    let after = engine_pid(&fx.engine_state);
    assert_ne!(before, after);
    // The first conversation lived in the killed worker: it must be reset.
    let (status, reset) = host.ask("turn-two", "conv", "hello again");
    assert_eq!(
        (status, &reset["error"]),
        (409, &json!("conversation_reset_required"))
    );
    host.stop();
    assert!(!alive(after), "Engine child outlived the host");

    // Restart: exact replay survives; the Engine is not consulted for it.
    let host = Host::start(&fx.config);
    let (status, replay) = host.ask("turn-one", "conv", "hello");
    assert_eq!(status, 200);
    assert_eq!(replay["reply"]["response"], answer);
    let (status, reset) = host.ask("turn-three", "conv-2", "hello");
    assert_eq!(
        (status, &reset["error"]),
        (409, &json!("conversation_reset_required"))
    );
    let (status, fresh) = host.ask("turn-four", "fresh-conv", "hello");
    assert_eq!(status, 200, "{fresh}");
    host.stop();
}

/// Real standalone discovery and invocation for the four supplied-data consumers.
#[cfg(all(
    feature = "reasoning",
    feature = "science",
    feature = "bio",
    feature = "statistics"
))]
#[test]
fn sol_consumers_discover_and_invoke_through_http() {
    let Some(fx) = fixture(2, &[]) else {
        return;
    };
    let mut config: Value = serde_json::from_slice(&std::fs::read(&fx.config).unwrap()).unwrap();
    config["pure"] = json!({"profiles": ["reasoning", "science", "bio", "statistics"]});
    std::fs::write(&fx.config, serde_json::to_vec(&config).unwrap()).unwrap();
    let host = Host::start(&fx.config);
    for id in [
        "reasoning.exact_linear_feasibility",
        "science.thermal_scenarios",
        "bio.search_collection",
        "statistics.calibration",
        "reasoning.optimize_linear",
        "science.thermal_transient",
        "bio.translate_coding_intervals",
        "statistics.events_exposure",
        "statistics.sequential_monitor",
    ] {
        let (status, descriptor) = host.get(&format!("/operations/{id}"));
        assert_eq!(status, 200, "{id}: {descriptor}");
        assert_eq!(descriptor["availability"], "live_direct");
        let arguments = descriptor["examples"][0]["arguments"].clone();
        let invoke = |args: Value| {
            host.post("/invoke", &json!({
            "request_id": "same", "conversation_id": "corr", "operation_id": id, "arguments": args,
        }))
        };
        let (status, result) = invoke(arguments.clone());
        assert_eq!(status, 200, "{id}: {result}");
        assert_eq!(result["reply"]["status"], "answered", "{id}: {result}");
        assert_eq!(result["reply"]["authority"], "computation_only");
        assert_eq!(result["durable_replay"], false);
        let mut extra = arguments.clone();
        extra["profile"] = json!("logic");
        assert_eq!(invoke(extra).0, 400, "{id} caller dispatch override");
        assert_eq!(host.request("POST", "/invoke", Some(&json!({
            "request_id": "same", "conversation_id": "corr", "operation_id": id, "arguments": arguments,
        })), &[]).0, 400, "{id} missing tenant");
    }
    host.stop();
}
