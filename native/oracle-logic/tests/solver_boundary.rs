#![cfg(unix)]
use oracle_logic::{process, Limits};
use std::os::unix::fs::PermissionsExt;
use std::{fs, path::PathBuf, sync::atomic::AtomicBool};

struct Fixture(PathBuf);
impl Fixture {
    fn new(script: &str) -> Self {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "oracle-logic-fixture-{}-{nonce}",
            std::process::id()
        ));
        fs::write(&path, script).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o700)).unwrap();
        Self(path)
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.0);
    }
}
const INPUT: &str = r#"{"scope":{"tenant":"test","snapshot":"v1","complete_program":true},"atoms":["a"],"rules":[{"head":0,"positive":[],"negative":[]}],"queries":[0]}"#;

#[test]
fn conflicting_process_exit_cannot_establish_inconsistency() {
    let fixture=Fixture::new("#!/bin/sh\nwhile IFS= read -r line; do :; done\nprintf '%s' '{\"Result\":\"UNSATISFIABLE\",\"Models\":{\"Number\":0,\"More\":\"no\"},\"Call\":[{}]}'\nexit 10\n");
    let l = Limits {
        milliseconds: 3000,
        ..Limits::default()
    };
    let reply = process::call(INPUT, &fixture.0, &l, &AtomicBool::new(false)).unwrap();
    let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(v["status"], "inconclusive");
    assert!(v["answers"][0]["skeptical"].is_null());
}

#[test]
fn interrupted_opposite_process_retains_checked_base_witness() {
    let fixture=Fixture::new("#!/bin/sh\nopposite=no\nwhile IFS= read -r line; do case \"$line\" in ':-a0.') opposite=yes;; esac; done\nif [ \"$opposite\" = yes ]; then\nprintf '%s' '{\"Result\":\"UNSATISFIABLE\",\"Models\":{\"Number\":0,\"More\":\"no\"},\"Call\":[{}]}'\nexit 21\nfi\nprintf '%s' '{\"Result\":\"SATISFIABLE\",\"Models\":{\"Number\":1,\"More\":\"yes\"},\"Call\":[{\"Witnesses\":[{\"Value\":[\"a0\"]}]}]}'\nexit 10\n");
    let l = Limits {
        milliseconds: 3000,
        ..Limits::default()
    };
    let reply = process::call(INPUT, &fixture.0, &l, &AtomicBool::new(false)).unwrap();
    let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(v["status"], "inconclusive");
    assert_eq!(v["answers"][0]["credulous"], true);
    assert!(v["answers"][0]["skeptical"].is_null());
    assert_eq!(v["models"], serde_json::json!([[0]]));
}

#[test]
fn third_query_counterexample_revokes_unrelated_earlier_absence() {
    // Backend falsely reports opposite-q0/q1 UNSAT, then returns a valid
    // opposite-q2 model also refuting q0. q1 UNSAT must be revoked as well.
    let fixture = Fixture::new(
        r#"#!/bin/sh
probe=base
while IFS= read -r line; do
case "$line" in ':-a0.') probe=first;; ':-a1.') probe=second;; ':-a2.') probe=third;; esac
done
case "$probe" in
first|second)
printf '%s' '{"Result":"UNSATISFIABLE","Models":{"Number":0,"More":"no"},"Call":[{}]}'
exit 20;;
third)
printf '%s' '{"Result":"SATISFIABLE","Models":{"Number":1,"More":"yes"},"Call":[{"Witnesses":[{"Value":["a1","a3","a5"]}]}]}'
exit 10;;
*)
printf '%s' '{"Result":"SATISFIABLE","Models":{"Number":1,"More":"yes"},"Call":[{"Witnesses":[{"Value":["a0","a1","a2"]}]}]}'
exit 10;;
esac
"#,
    );
    let input =
        serde_json::json!({"scope":{"tenant":"test","snapshot":"v1","complete_program":true},
        "atoms":["a","b","c","not-a-choice","not-b-choice","not-c-choice"],
        "rules":[
            {"head":0,"positive":[],"negative":[3]},{"head":3,"positive":[],"negative":[0]},
            {"head":1,"positive":[],"negative":[4]},{"head":4,"positive":[],"negative":[1]},
            {"head":2,"positive":[],"negative":[5]},{"head":5,"positive":[],"negative":[2]}],
        "queries":[0,1,2]})
        .to_string();
    let l = Limits {
        milliseconds: 3000,
        ..Limits::default()
    };
    let reply = process::call(&input, &fixture.0, &l, &AtomicBool::new(false)).unwrap();
    let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(v["status"], "inconclusive");
    assert_eq!(
        v["completeness_trust"],
        "witnesses_only_backend_inconsistent"
    );
    assert_eq!(v["answers"][0]["skeptical"], false);
    assert!(v["answers"][1]["skeptical"].is_null());
    assert_eq!(v["answers"][1]["credulous"], true);
    assert_eq!(v["answers"][2]["skeptical"], false);
}

struct ChildReceipt(PathBuf);
impl ChildReceipt {
    fn new() -> Self {
        let nonce = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        Self(std::env::temp_dir().join(format!(
            "oracle-logic-child-{}-{nonce}.pid",
            std::process::id()
        )))
    }
    fn pid(&self) -> u32 {
        fs::read_to_string(&self.0)
            .expect("fixture wrote owned child PID")
            .parse()
            .unwrap()
    }
    fn assert_reaped(&self) {
        let alive = std::process::Command::new("/bin/kill")
            .args(["-0", &self.pid().to_string()])
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .unwrap();
        assert!(
            !alive.success(),
            "owned fixture child still exists after call returned"
        );
    }
}
impl Drop for ChildReceipt {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.0);
    }
}

#[test]
fn blocked_stdin_child_times_out_and_is_reaped() {
    let receipt = ChildReceipt::new();
    // Pure shell builtins, no descendants; does not consume the provider stdin.
    let script = format!(
        "#!/bin/sh\nprintf '%s' \"$$\" > '{}'\nwhile :; do :; done\n",
        receipt.0.display()
    );
    let fixture = Fixture::new(&script);
    let input =
        serde_json::json!({"scope":{"tenant":"test","snapshot":"v1","complete_program":true},
        "atoms":["a"],"queries":[0],"rules":[{"head":0,"positive":vec![0;32768],"negative":[]}]})
        .to_string();
    let l = Limits {
        milliseconds: 300,
        ..Limits::default()
    };
    let started = std::time::Instant::now();
    let reply = process::call(&input, &fixture.0, &l, &AtomicBool::new(false)).unwrap();
    assert!(started.elapsed() < std::time::Duration::from_secs(3));
    let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(v["status"], "inconclusive");
    assert!(v["reason"].as_str().unwrap().contains("deadline"));
    receipt.assert_reaped();
}

#[test]
fn overflowing_stdout_child_is_stopped_and_reaped() {
    let receipt = ChildReceipt::new();
    let script=format!("#!/bin/sh\nprintf '%s' \"$$\" > '{}'\nwhile :; do printf '%s' 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; done\n",receipt.0.display());
    let fixture = Fixture::new(&script);
    let l = Limits {
        milliseconds: 3000,
        output_bytes: 4096,
        ..Limits::default()
    };
    let reply = process::call(INPUT, &fixture.0, &l, &AtomicBool::new(false)).unwrap();
    let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(v["status"], "inconclusive");
    assert!(v["reason"].as_str().unwrap().contains("pipe bytes"));
    receipt.assert_reaped();
}

#[test]
fn inflight_cancellation_stops_and_reaps_owned_child() {
    let receipt = ChildReceipt::new();
    let script = format!(
        "#!/bin/sh\nprintf '%s' \"$$\" > '{}'\nwhile :; do :; done\n",
        receipt.0.display()
    );
    let fixture = Fixture::new(&script);
    let cancel = std::sync::Arc::new(AtomicBool::new(false));
    let token = cancel.clone();
    let marker = receipt.0.clone();
    let trigger = std::thread::spawn(move || {
        let start = std::time::Instant::now();
        while fs::read_to_string(&marker)
            .ok()
            .is_none_or(|s| s.is_empty())
        {
            assert!(
                start.elapsed() < std::time::Duration::from_secs(2),
                "child did not start"
            );
            std::thread::sleep(std::time::Duration::from_millis(2));
        }
        token.store(true, std::sync::atomic::Ordering::Relaxed);
    });
    let l = Limits {
        milliseconds: 3000,
        ..Limits::default()
    };
    let reply = process::call(INPUT, &fixture.0, &l, &cancel).unwrap();
    trigger.join().unwrap();
    let v: serde_json::Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(v["status"], "inconclusive");
    assert!(v["reason"].as_str().unwrap().contains("Cancelled"));
    receipt.assert_reaped();
}
