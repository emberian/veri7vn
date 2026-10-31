use oracle_runtime_core::{build_image, Cancellation, Error, Image, Limits, Runtime};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::Arc;
use tempfile::TempDir;

struct Fixture {
    directory: TempDir,
    path: PathBuf,
    digest: String,
}
impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let path = directory.path().join("image.sqlite");
        let kb = json!({
            "concepts": {
                "C0":{"name":"Thing","instanceOf":["C1"]},
                "C1":{"name":"Person","instanceOf":["C0"]}
            },
            "entities": {
                "Q1":{"name":"Alice","instanceOf":["C1"],"attributes":[
                    {"key":"mass","value":{"type":"quantity","value":64,"unit":"kilogram"},"qualifiers":{}}],
                    "relations":[
                        {"predicate":"knows","direction":"forward","object":"Q2","qualifiers":{"since":[{"type":"year","value":2000}]}},
                        {"predicate":"knows","direction":"forward","object":"Q2","qualifiers":{}}
                    ]},
                "Q2":{"name":"Bob","instanceOf":["C1"],"relations":[
                    {"predicate":"knows","direction":"backward","object":"Q1","qualifiers":{}}
                ]},
                "Q3":{"name":"Bob","instanceOf":[],"relations":[]}
            }
        });
        std::fs::write(&source, kb.to_string()).unwrap();
        let receipt = build_image(&source, &path, 1_000_000, 100_000).unwrap();
        assert_eq!(receipt.nodes, 5);
        assert_eq!(receipt.edges, 4); // Mirrors deduplicated, distinct qualifiers preserved.
        Self {
            directory,
            path,
            digest: receipt.image_sha256,
        }
    }
    fn image(&self, limits: Limits) -> Arc<Image> {
        Image::open(&self.path, &self.digest, limits).unwrap()
    }
    fn runtime(&self, limits: Limits) -> Runtime {
        Runtime::open(
            self.image(limits),
            &self.directory.path().join("state.sqlite"),
        )
        .unwrap()
    }
}
fn find(name: &str) -> String {
    json!({"nodes":[{"op":"find","name":name}],"output":0,"projection":{"kind":"unique_name"}})
        .to_string()
}
fn run(runtime: &Runtime, tenant: &str, request: &str, version: i64, plan: &str) -> Value {
    serde_json::from_str(
        &runtime
            .execute(tenant, "s", request, version, plan, Cancellation::default())
            .unwrap(),
    )
    .unwrap()
}

#[test]
fn indexed_relations_preserve_qualifiers_and_reverse_edges() {
    let f = Fixture::new();
    let r = f.runtime(Limits::default());
    let plan=json!({"nodes":[{"op":"find","name":"Alice"},
        {"op":"relate","input":0,"predicate":"knows","direction":"forward"}],"output":1,"projection":{"kind":"names"}}).to_string();
    let result = run(&r, "tenant", "one", 0, &plan);
    assert_eq!(result["result"]["entities"], json!(["Q2"]));
    assert_eq!(result["result"]["facts"].as_array().unwrap().len(), 2);
    let reverse=json!({"nodes":[{"op":"previous"},
        {"op":"relate","input":0,"predicate":"knows","direction":"backward"}],"output":1,"projection":{"kind":"unique_name"}}).to_string();
    assert_eq!(
        run(&r, "tenant", "two", 1, &reverse)["result"]["value"]["candidate"]["name"],
        "Alice"
    );
}

#[test]
fn ambiguity_is_not_an_arbitrary_first_answer() {
    let f = Fixture::new();
    let r = f.runtime(Limits::default());
    assert_eq!(
        run(&r, "t", "one", 0, &find("Bob"))["result"]["value"]["status"],
        "ambiguous"
    );
    assert_eq!(
        run(&r, "t", "two", 1, &find("missing"))["result"]["value"]["status"],
        "absent"
    );
}

#[test]
fn cyclic_concepts_terminate_and_attributes_keep_types() {
    let f = Fixture::new();
    let r = f.runtime(Limits::default());
    let plan=json!({"nodes":[{"op":"all"},{"op":"filter_concept","input":0,"name":"Thing"}],"output":1,"projection":{"kind":"count"}}).to_string();
    assert_eq!(run(&r, "t", "one", 0, &plan)["result"]["value"], 2);
    let attr=json!({"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"attributes","key":"mass"}}).to_string();
    assert_eq!(
        run(&r, "t", "two", 1, &attr)["result"]["value"][0]["value"],
        json!({"type":"quantity","value":64,"unit":"kilogram"})
    );
}

#[test]
fn tenant_state_survives_restart_and_exact_retry_is_byte_identical() {
    let f = Fixture::new();
    let original = {
        let r = f.runtime(Limits::default());
        r.execute(
            "alice",
            "s",
            "one",
            0,
            &find("Alice"),
            Cancellation::default(),
        )
        .unwrap()
    };
    let r = f.runtime(Limits::default());
    let cancelled = Cancellation::default();
    cancelled.cancel();
    assert_eq!(
        r.execute("alice", "s", "one", 0, &find("Alice"), cancelled)
            .unwrap(),
        original
    );
    let previous = r#"{"nodes":[{"op":"previous"}],"output":0,"projection":{"kind":"names"}}"#;
    assert_eq!(
        run(&r, "bob", "one", 0, previous)["result"]["entities"],
        json!([])
    );
    assert_eq!(
        run(&r, "alice", "two", 1, previous)["result"]["entities"],
        json!(["Q1"])
    );
}

#[test]
fn retry_binds_exact_body_session_and_version() {
    let f = Fixture::new();
    let r = f.runtime(Limits::default());
    let p = find("Alice");
    run(&r, "t", "one", 0, &p);
    for (session, version, body) in [
        ("s", 0, format!("{p} ")),
        ("other", 0, p.clone()),
        ("s", 1, p),
    ] {
        assert!(matches!(
            r.execute("t", session, "one", version, &body, Cancellation::default()),
            Err(Error::Conflict(_))
        ));
    }
}

#[test]
fn budgets_and_cancellation_leave_no_partial_commit() {
    let f = Fixture::new();
    let cancelled = Cancellation::default();
    cancelled.cancel();
    let r = f.runtime(Limits::default());
    assert!(matches!(
        r.execute("t", "s", "one", 0, &find("Alice"), cancelled),
        Err(Error::Cancelled)
    ));
    drop(r);
    let r = f.runtime(Limits {
        fuel: 1,
        ..Limits::default()
    });
    assert!(matches!(
        r.execute("t", "s", "one", 0, &find("Alice"), Cancellation::default()),
        Err(Error::Limit("fuel"))
    ));
    drop(r);
    let r = f.runtime(Limits {
        result_bytes: 10,
        ..Limits::default()
    });
    assert!(matches!(
        r.execute("t", "s", "one", 0, &find("Alice"), Cancellation::default()),
        Err(Error::Limit(_))
    ));
    drop(r);
    let r = f.runtime(Limits::default());
    assert_eq!(run(&r, "t", "one", 0, &find("Alice"))["version"], 1);
}

#[test]
fn journal_and_session_capacity_fail_without_silent_eviction() {
    let f = Fixture::new();
    let r = f.runtime(Limits {
        sessions: 1,
        journal_entries: 2,
        ..Limits::default()
    });
    run(&r, "t", "one", 0, &find("Alice"));
    assert!(matches!(
        r.execute(
            "other",
            "s",
            "one",
            0,
            &find("Bob"),
            Cancellation::default()
        ),
        Err(Error::Limit("session capacity"))
    ));
    run(&r, "t", "two", 1, &find("Bob"));
    assert!(matches!(
        r.execute(
            "t",
            "s",
            "three",
            2,
            &find("Alice"),
            Cancellation::default()
        ),
        Err(Error::Limit("request journal capacity"))
    ));
    assert_eq!(run(&r, "t", "one", 0, &find("Alice"))["version"], 1);
}

#[test]
fn stale_version_and_invalid_plan_cannot_advance_state() {
    let f = Fixture::new();
    let r = f.runtime(Limits::default());
    let invalid = r#"{"nodes":[{"op":"relate","input":0,"predicate":"x","direction":"forward"}],"output":0,"projection":{"kind":"count"}}"#;
    assert!(matches!(
        r.execute("t", "s", "one", 0, invalid, Cancellation::default()),
        Err(Error::Invalid(_))
    ));
    run(&r, "t", "one", 0, &find("Alice"));
    assert!(matches!(
        r.execute("t", "s", "two", 0, &find("Bob"), Cancellation::default()),
        Err(Error::Conflict(_))
    ));
}

#[test]
fn wrong_image_and_foreign_state_are_rejected() {
    let f = Fixture::new();
    assert!(matches!(
        Image::open(&f.path, "bad", Limits::default()),
        Err(Error::Format(_))
    ));
    let state = f.directory.path().join("foreign.sqlite");
    let db = rusqlite::Connection::open(&state).unwrap();
    db.execute_batch("CREATE TABLE private(data TEXT)").unwrap();
    drop(db);
    assert!(matches!(
        Runtime::open(f.image(Limits::default()), &state),
        Err(Error::Format(_))
    ));
}

#[test]
fn builder_never_replaces_destination() {
    let f = Fixture::new();
    let before = std::fs::read(&f.path).unwrap();
    assert!(build_image(
        &f.directory.path().join("kb.json"),
        &f.path,
        1_000_000,
        100_000
    )
    .is_err());
    assert_eq!(std::fs::read(&f.path).unwrap(), before);
}

#[test]
fn concurrent_same_version_commits_once() {
    let f = Fixture::new();
    let r = Arc::new(f.runtime(Limits {
        workers: 4,
        ..Limits::default()
    }));
    let barrier = Arc::new(std::sync::Barrier::new(8));
    let threads: Vec<_> = (0..8)
        .map(|i| {
            let r = r.clone();
            let b = barrier.clone();
            std::thread::spawn(move || {
                b.wait();
                r.execute(
                    "t",
                    "s",
                    &format!("r{i}"),
                    0,
                    &find("Alice"),
                    Cancellation::default(),
                )
            })
        })
        .collect();
    let results: Vec<_> = threads.into_iter().map(|t| t.join().unwrap()).collect();
    assert_eq!(results.iter().filter(|r| r.is_ok()).count(), 1);
    assert!(results
        .iter()
        .all(|r| matches!(r, Ok(_) | Err(Error::Busy) | Err(Error::Conflict(_)))));
    assert_eq!(run(&r, "t", "after", 1, &find("Bob"))["version"], 2);
}

#[test]
fn shared_dag_results_match_set_algebra_across_reused_workers() {
    use std::collections::BTreeSet;
    let f = Fixture::new();
    let r = f.runtime(Limits::default());
    let mut seed = 7u64;
    for _ in 0..64 {
        let mut nodes = vec![
            json!({"op":"find","name":"Alice"}),
            json!({"op":"find","name":"Bob"}),
        ];
        let mut model = vec![BTreeSet::from(["Q1"]), BTreeSet::from(["Q2", "Q3"])];
        for i in 2..16 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let left = (seed as usize) % i;
            let right = ((seed >> 16) as usize) % i;
            let union = seed & (1 << 32) != 0;
            nodes.push(json!({"op":if union {"or"} else {"and"},"left":left,"right":right}));
            let expected = if union {
                model[left].union(&model[right]).copied().collect()
            } else {
                model[left].intersection(&model[right]).copied().collect()
            };
            model.push(expected);
        }
        let plan = json!({"nodes":nodes,"output":15,"projection":{"kind":"entities"}}).to_string();
        let got: Value =
            serde_json::from_str(&r.query("t", &plan, Cancellation::default()).unwrap()).unwrap();
        assert_eq!(got["entities"], json!(model[15]));
        assert_eq!(r.image.active_workers(), 0);
    }
}

#[test]
fn numeric_source_digits_survive_the_image_and_binding_format() {
    let f = Fixture::new();
    let source = f.directory.path().join("kb.json");
    let text = std::fs::read_to_string(&source)
        .unwrap()
        .replace("\"value\":64", "\"value\":0.10000000000000001");
    std::fs::write(&source, text).unwrap();
    let path = f.directory.path().join("precise.sqlite");
    let receipt = build_image(&source, &path, 1_000_000, 100_000).unwrap();
    let image = Image::open(&path, &receipt.image_sha256, Limits::default()).unwrap();
    let result=image.query("t",r#"{"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"attributes","key":"mass"}}"#,Cancellation::default()).unwrap();
    assert!(result.contains("0.10000000000000001"));
}

#[test]
fn lowered_limits_refuse_retained_values_without_rewriting_them() {
    let f = Fixture::new();
    let p = find("Alice");
    let original = {
        let r = f.runtime(Limits::default());
        r.execute("t", "s", "one", 0, &p, Cancellation::default())
            .unwrap()
    };
    {
        let r = f.runtime(Limits {
            result_bytes: 1,
            ..Limits::default()
        });
        assert!(matches!(
            r.execute("t", "s", "one", 0, &p, Cancellation::default()),
            Err(Error::Limit(_))
        ));
    }
    {
        let r = f.runtime(Limits {
            state_bytes: 1,
            ..Limits::default()
        });
        assert!(matches!(
            r.execute("t", "s", "two", 1, &p, Cancellation::default()),
            Err(Error::Limit("retained state bytes"))
        ));
    }
    let r = f.runtime(Limits::default());
    assert_eq!(
        r.execute("t", "s", "one", 0, &p, Cancellation::default())
            .unwrap(),
        original
    );
    assert_eq!(run(&r, "t", "two", 1, &p)["version"], 2);
}

#[test]
fn shared_execution_deadline_preserves_commit_and_replay_boundaries() {
    use oracle_execution::ExecutionContext;
    use oracle_runtime_core::Budget;
    use std::time::Instant;
    let f = Fixture::new();
    let runtime = f.runtime(Limits::default());
    let expired = Budget::from_execution_context(ExecutionContext::with_deadline(
        100_000,
        Instant::now(),
        Cancellation::default(),
    ));
    let plan = find("Alice");
    assert!(matches!(
        runtime.query_with_budget("t", &plan, &expired),
        Err(Error::Deadline)
    ));
    assert!(matches!(
        runtime.execute_with_budget("t", "s", "one", 0, &plan, &expired),
        Err(Error::Deadline)
    ));
    let fresh = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
    let committed = runtime
        .execute_with_budget("t", "s", "one", 0, &plan, &fresh)
        .unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&committed).unwrap()["version"],
        1
    );
    // Durable retry is not another evaluation; its known outcome survives the
    // deadline, just as a commit that finishes after cancellation does.
    assert_eq!(
        runtime
            .execute_with_budget("t", "s", "one", 0, &plan, &expired)
            .unwrap(),
        committed
    );
}

#[test]
fn shared_execution_preserves_parent_and_local_core_fuel_caps() {
    use oracle_runtime_core::Budget;
    let program = r#"[{"function":"Find","dependencies":[],"inputs":["Alice"]},{"function":"What","dependencies":[0],"inputs":[]}]"#;
    let f = Fixture::new();
    let runtime = f.runtime(Limits::default());
    let tiny = Budget::new(
        &Limits {
            fuel: 1,
            ..Limits::default()
        },
        Cancellation::default(),
    )
    .unwrap();
    assert!(matches!(
        runtime.query_program_with_budget("t", program, &tiny),
        Err(Error::Limit("fuel"))
    ));
    assert!(matches!(tiny.check(), Err(Error::Limit("fuel"))));
    drop(runtime);
    let runtime = f.runtime(Limits {
        fuel: 1,
        ..Limits::default()
    });
    let parent = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
    assert!(matches!(
        runtime.query_program_with_budget("t", program, &parent),
        Err(Error::Limit("fuel"))
    ));
    parent.check().unwrap();
    assert!(matches!(
        runtime
            .image
            .query_program_with_budget("t", program, &parent),
        Err(Error::Limit("fuel"))
    ));
    assert!(matches!(
        runtime
            .image
            .query_with_budget("t", &find("Alice"), &parent),
        Err(Error::Limit("fuel"))
    ));
    parent.check().unwrap();
    assert_eq!(runtime.image.active_workers(), 0);
}
