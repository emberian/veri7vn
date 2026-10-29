//! Hosted envelope: operation IDs, host-owned solver, content identities.
use oracle_logic::{hosted, parse, Error, Limits};
use serde_json::{json, Value};
use std::sync::atomic::AtomicBool;

fn program(snapshot: &str, labels: [&str; 2]) -> Value {
    json!({"scope": {"tenant": "t", "snapshot": snapshot, "complete_program": true},
           "atoms": labels, "rules": [{"head": 0, "positive": [], "negative": [1]}], "queries": [0]})
}

fn envelope(op: &str, arguments: Value) -> String {
    json!({"operation": op, "arguments": arguments}).to_string()
}

const HOST: &str = r#"{"solver":"/nonexistent/admitted/clingo"}"#;

fn call(text: &str, host: &str) -> Result<Value, Error> {
    hosted::call(text, host, &Limits::default(), &AtomicBool::new(false))
        .map(|s| serde_json::from_str(&s).unwrap())
}

#[test]
fn request_cannot_choose_solver_flags_or_operation() {
    for extra in ["solver", "executable", "flags", "operation"] {
        let mut args = program("s", ["a", "b"]);
        args[extra] = json!("/tmp/other-clingo");
        assert_eq!(
            call(&envelope(hosted::QUERY, args), HOST).unwrap_err(),
            if extra == "operation" {
                Error::Invalid("operation is chosen by the operation ID")
            } else {
                Error::Invalid("request JSON")
            },
            "{extra}"
        );
    }
    let outer = json!({"operation": hosted::QUERY, "arguments": program("s", ["a", "b"]),
                       "solver": "/tmp/other-clingo"});
    assert_eq!(
        call(&outer.to_string(), HOST).unwrap_err(),
        Error::Invalid("request JSON")
    );
    assert_eq!(
        call(&envelope("logic.prove", program("s", ["a", "b"])), HOST).unwrap_err(),
        Error::Invalid("unknown logic operation")
    );
    // Host configuration is strict too and never a tenant-safe refusal.
    for host in [
        r#"{"solver":"relative/clingo"}"#,
        r#"{"solver":"/a","flags":"-n0"}"#,
        "{}",
    ] {
        assert!(matches!(
            call(&envelope(hosted::QUERY, program("s", ["a", "b"])), host),
            Err(Error::Backend(_))
        ));
    }
}

#[test]
fn missing_admitted_solver_is_inconclusive_with_content_identity() {
    for (op, name) in [(hosted::QUERY, "query"), (hosted::ENUMERATE, "enumerate")] {
        let reply = call(&envelope(op, program("s", ["a", "b"])), HOST).unwrap();
        assert_eq!(reply["status"], "inconclusive", "{name}");
        assert_eq!(reply["operation_id"], op);
        assert_eq!(reply["answers"][0]["skeptical"], Value::Null);
        assert_eq!(reply["answers"][0]["credulous"], Value::Null);
        assert_eq!(reply["program_identity"].as_str().unwrap().len(), 64);
    }
}

#[test]
fn program_identity_keys_on_rules_not_snapshot_label() {
    let id = |args: Value, op: &str| {
        let r = call(&envelope(op, args), HOST).unwrap();
        (
            r["program_identity"].as_str().unwrap().to_owned(),
            r["request_identity"].as_str().unwrap().to_owned(),
        )
    };
    let base = id(program("v1", ["a", "b"]), hosted::QUERY);
    // Same caller label, different rules: identities must differ.
    let mut changed = program("v1", ["a", "b"]);
    changed["rules"] = json!([{"head": 1, "positive": [], "negative": [0]}]);
    let other = id(changed, hosted::QUERY);
    assert_ne!(base.0, other.0);
    assert_ne!(base.1, other.1);
    // Different caller label, same rules: same program, different request.
    let relabelled = id(program("v2", ["a", "b"]), hosted::QUERY);
    assert_eq!(base.0, relabelled.0);
    assert_ne!(base.1, relabelled.1);
    // Atom labels and the operation are part of the request, not the program.
    let names = id(program("v1", ["x", "y"]), hosted::QUERY);
    assert_eq!(base.0, names.0);
    assert_ne!(base.1, names.1);
    let enumerate = id(program("v1", ["a", "b"]), hosted::ENUMERATE);
    assert_eq!(base.0, enumerate.0);
    assert_ne!(base.1, enumerate.1);
    // The identity is exactly sha256 of encode(request).
    let mut args = program("v1", ["a", "b"]);
    args["operation"] = json!("query");
    let p = parse(&args.to_string(), &Limits::default()).unwrap();
    assert_eq!(oracle_logic::encode(&p), "a0:-not a1.\n");
    assert_eq!(hosted::program_identity(&p), base.0);
}

#[test]
#[ignore = "requires operator-pinned CLINGO_EXECUTABLE"]
fn hosted_examples_with_actual_clingo() {
    let path = std::env::var("CLINGO_EXECUTABLE").expect("pin native clingo executable");
    let host = json!({"solver": path}).to_string();
    let dir = concat!(env!("CARGO_MANIFEST_DIR"), "/examples/");
    let models = |name: &str, op: &str| {
        let text = std::fs::read_to_string(format!("{dir}{name}.json")).unwrap();
        let r = call(&envelope(op, serde_json::from_str(&text).unwrap()), &host).unwrap();
        (
            r["status"].as_str().unwrap().to_owned(),
            r["models"].clone(),
            r,
        )
    };
    let (status, all, _) = models("alternative-plans", hosted::ENUMERATE);
    assert_eq!(status, "consistent");
    let mut all: Vec<Vec<u64>> = serde_json::from_value(all).unwrap();
    all.sort();
    assert_eq!(all, vec![vec![0, 2], vec![1, 2]]);
    assert_eq!(
        models("default-flight", hosted::ENUMERATE).1,
        json!([[0, 3]])
    );
    assert_eq!(
        models("exception-flight", hosted::ENUMERATE).1,
        json!([[0, 1, 2]])
    );
    let (status, _, r) = models("inconsistent", hosted::QUERY);
    assert_eq!(status, "inconsistent");
    assert_eq!(r["answers"][0]["skeptical"], Value::Null);
}
