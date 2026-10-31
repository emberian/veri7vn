//! Durable scalar owner, shared selection and exact-retry composition.
use oracle_runtime_core::context_delta::ScalarOwner;
use oracle_runtime_core::session::{NativeSessionOwner, SessionBinding};
use oracle_runtime_core::{build_image, Budget, Cancellation, Error, Image, Limits, Runtime};
use serde_json::{json, Value};
use std::sync::{Arc, Barrier};
use tempfile::TempDir;

struct Fixture {
    _dir: TempDir,
    image: Arc<Image>,
    store: std::path::PathBuf,
}
impl Fixture {
    fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        let source = dir.path().join("source.json");
        let target = dir.path().join("image.sqlite");
        std::fs::write(
            &source,
            json!({"concepts":{},"entities":{
            "A":{"name":"Alice","instanceOf":[],"attributes":[],"relations":[]}}})
            .to_string(),
        )
        .unwrap();
        let receipt = build_image(&source, &target, 1_000_000, 100_000).unwrap();
        let image = Image::open(&target, &receipt.image_sha256, Limits::default()).unwrap();
        Self {
            store: dir.path().join("state.sqlite"),
            _dir: dir,
            image,
        }
    }
    fn runtime(&self) -> Runtime {
        Runtime::open(self.image.clone(), &self.store).unwrap()
    }
}
fn command(runtime: &Runtime, request: &str, revision: i64, command: Value) -> String {
    runtime
        .execute_context(
            "alice",
            "s",
            request,
            revision,
            &command.to_string(),
            Cancellation::default(),
        )
        .unwrap()
}
fn observe(number: &str) -> Value {
    json!({"op":"observe","value":{"number":number,"origin":"exact_decimal"}})
}
fn find() -> String {
    json!({"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"entities"}})
        .to_string()
}
fn previous() -> String {
    json!({"nodes":[{"op":"previous"}],"output":0,"projection":{"kind":"entities"}}).to_string()
}

#[test]
fn scalar_graph_restart_exact_retry_and_changed_input() {
    let f = Fixture::new();
    let runtime = f.runtime();
    runtime
        .execute("alice", "s", "reader", 0, &find(), Cancellation::default())
        .unwrap();
    let first = command(&runtime, "import", 1, observe("2.5"));
    let second = command(&runtime, "scale", 2, json!({"op":"scale","factor":"3"}));
    let parsed: Value = serde_json::from_str(&second).unwrap();
    assert_eq!(parsed["result"]["scalar"]["value"]["number"], "15/2");
    let graph: Value = serde_json::from_str(
        &runtime
            .execute(
                "alice",
                "s",
                "previous",
                3,
                &previous(),
                Cancellation::default(),
            )
            .unwrap(),
    )
    .unwrap();
    assert_eq!(graph["result"]["entities"], json!(["A"]));
    assert_eq!(command(&runtime, "import", 1, observe("2.5")), first);
    let cancelled = Cancellation::default();
    cancelled.cancel();
    assert_eq!(
        runtime
            .execute_context(
                "alice",
                "s",
                "import",
                1,
                &observe("2.5").to_string(),
                cancelled
            )
            .unwrap(),
        first
    );
    let tiny = Limits {
        request_memory_bytes: 1,
        ..Limits::default()
    };
    let tiny_budget = Budget::new(&tiny, Cancellation::default()).unwrap();
    assert_eq!(
        runtime
            .execute_native_owner_typed_with_budget::<ScalarOwner>(
                "alice",
                "s",
                "import",
                1,
                serde_json::from_value(observe("2.5")).unwrap(),
                &tiny_budget
            )
            .unwrap(),
        first
    );
    assert!(matches!(
        runtime.execute_context(
            "alice",
            "s",
            "import",
            1,
            &observe("999").to_string(),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
    drop(runtime);
    let runtime = f.runtime();
    assert_eq!(
        command(&runtime, "scale", 2, json!({"op":"scale","factor":"3"})),
        second
    );
    let budget = Budget::new(&f.image.limits, Cancellation::default()).unwrap();
    let snapshot = runtime
        .read_native_owner_with_budget::<ScalarOwner>("alice", "s", 4, &budget)
        .unwrap();
    assert_eq!(
        snapshot
            .state()
            .unwrap()
            .scalar
            .as_ref()
            .unwrap()
            .value
            .number,
        "15/2"
    );
    assert_eq!(snapshot.revision(), 4);
    assert!(runtime
        .read_native_owner_with_budget::<ScalarOwner>("bob", "s", 4, &budget)
        .is_err());
}

struct Counter;
impl NativeSessionOwner for Counter {
    const OWNER: &'static str = "test_counter";
    const VERSION: u32 = 1;
    const OPERATION: &'static str = "counter.add";
    type State = u32;
    type Command = u32;
    type Reply = u32;
    fn validate(_: &u32, _: &SessionBinding, _: i64) -> oracle_runtime_core::Result<()> {
        Ok(())
    }
    fn transition(
        _: &SessionBinding,
        _: i64,
        _: &str,
        state: Option<u32>,
        command: u32,
        budget: &Budget,
    ) -> oracle_runtime_core::Result<(u32, u32)> {
        budget.spend(1)?;
        let value = state
            .unwrap_or_default()
            .checked_add(command)
            .ok_or(Error::Limit("counter"))?;
        Ok((value, value))
    }
}

#[test]
fn independent_native_owners_survive_interleaved_turns() {
    let f = Fixture::new();
    let runtime = f.runtime().register_native_owner::<Counter>().unwrap();
    let budget = Budget::new(&f.image.limits, Cancellation::default()).unwrap();
    runtime
        .execute_native_owner_typed_with_budget::<Counter>("alice", "s", "counter", 0, 7, &budget)
        .unwrap();
    command(&runtime, "scalar", 1, observe("5"));
    let counter = runtime
        .read_native_owner_with_budget::<Counter>("alice", "s", 2, &budget)
        .unwrap();
    assert_eq!(counter.state(), Some(&7));
    // Restart without declaring the counter decoder refuses to reinterpret it.
    drop(counter);
    drop(runtime);
    let runtime = f.runtime();
    assert!(runtime
        .execute_context(
            "alice",
            "s",
            "unknown",
            2,
            r#"{"op":"inspect"}"#,
            Cancellation::default()
        )
        .is_err());
}

#[test]
fn concurrent_owner_and_selection_turn_cannot_overwrite_each_other() {
    let f = Fixture::new();
    let runtime = Arc::new(f.runtime());
    command(&runtime, "initial", 0, observe("11"));
    let barrier = Arc::new(Barrier::new(3));
    let a = {
        let runtime = runtime.clone();
        let barrier = barrier.clone();
        std::thread::spawn(move || {
            barrier.wait();
            runtime.execute_context(
                "alice",
                "s",
                "owner",
                1,
                r#"{"op":"scale","factor":"2"}"#,
                Cancellation::default(),
            )
        })
    };
    let b = {
        let runtime = runtime.clone();
        let barrier = barrier.clone();
        std::thread::spawn(move || {
            barrier.wait();
            runtime.execute("alice", "s", "reader", 1, &find(), Cancellation::default())
        })
    };
    barrier.wait();
    let a = a.join().unwrap();
    let b = b.join().unwrap();
    assert!(a.is_ok() ^ b.is_ok());
    for result in [&a, &b] {
        if let Err(error) = result {
            assert!(matches!(error, Error::Busy | Error::Conflict(_)));
        }
    }
    if a.is_ok() {
        runtime
            .execute(
                "alice",
                "s",
                "reader_after",
                2,
                &find(),
                Cancellation::default(),
            )
            .unwrap();
    } else {
        command(
            &runtime,
            "owner_after",
            2,
            json!({"op":"scale","factor":"2"}),
        );
    }
    let budget = Budget::new(&f.image.limits, Cancellation::default()).unwrap();
    let state = runtime
        .read_native_owner_with_budget::<ScalarOwner>("alice", "s", 3, &budget)
        .unwrap();
    assert_eq!(
        state.state().unwrap().scalar.as_ref().unwrap().value.number,
        "22/1"
    );
    let graph: Value = serde_json::from_str(
        &runtime
            .execute(
                "alice",
                "s",
                "read_previous",
                3,
                &previous(),
                Cancellation::default(),
            )
            .unwrap(),
    )
    .unwrap();
    assert_eq!(graph["result"]["entities"], json!(["A"]));
}

#[test]
fn schema_two_migration_is_explicit_and_keeps_oracle_unknown() {
    let f = Fixture::new();
    let runtime = f.runtime();
    runtime
        .execute("alice", "s", "reader", 0, &find(), Cancellation::default())
        .unwrap();
    let db = rusqlite::Connection::open(&f.store).unwrap();
    let text: String = db
        .query_row("SELECT state FROM sessions", [], |row| row.get(0))
        .unwrap();
    let mut old: Value = serde_json::from_str(&text).unwrap();
    old["schema"] = json!(2);
    old.as_object_mut().unwrap().remove("native_extensions");
    db.execute("UPDATE sessions SET state=?1", [old.to_string()])
        .unwrap();
    command(&runtime, "migrate", 1, observe("3"));
    let new: String = db
        .query_row("SELECT state FROM sessions", [], |row| row.get(0))
        .unwrap();
    let new: Value = serde_json::from_str(&new).unwrap();
    assert_eq!(new["schema"], 3);
    assert!(new["oracle"].is_null());
    assert_eq!(new["selection"]["ids"], json!(["A"]));
}
