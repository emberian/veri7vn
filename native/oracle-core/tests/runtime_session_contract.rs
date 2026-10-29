//! Runtime/storage composition checks for versioned session state. These are
//! executable contract cases, not specialist-panel scores or proof claims.
use oracle_runtime_core::session::{
    DialogueContext, NumericOrigin, OracleSessionState, PriorValue, SessionBinding,
    SessionEnvelope, SessionLimits, StateCoverage, SESSION_SCHEMA,
};
use oracle_runtime_core::{build_image, Cancellation, Error, Image, Limits, Runtime};
use rusqlite::{params, Connection};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::{Arc, Barrier};
use tempfile::TempDir;

struct Fixture {
    _directory: TempDir,
    image: PathBuf,
    digest: String,
    store: PathBuf,
}

impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("source.json");
        let image = directory.path().join("image.sqlite");
        let store = directory.path().join("state.sqlite");
        let data = json!({"concepts":{},"entities":{
            "A":{"name":"Alice","instanceOf":[],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":64,"unit":"kilogram"},"qualifiers":{"since":[{"type":"year","value":2000}]}},
                {"key":"mass","value":{"type":"quantity","value":64,"unit":"kilogram"},"qualifiers":{"since":[{"type":"year","value":2001}]}}
            ],"relations":[{"predicate":"knows","direction":"forward","object":"B","qualifiers":{"since":[{"type":"year","value":2000}]}}]},
            "B":{"name":"Bob","instanceOf":[],"attributes":[],"relations":[]}
        }});
        std::fs::write(&source, data.to_string()).unwrap();
        let receipt = build_image(&source, &image, 1_000_000, 100_000).unwrap();
        let f = Self { _directory: directory, image, digest: receipt.image_sha256, store };
        // Create the established SQLite store through the production API.
        drop(f.runtime(Limits::default()));
        f
    }

    fn runtime(&self, limits: Limits) -> Runtime {
        let image = Image::open(&self.image, &self.digest, limits).unwrap();
        Runtime::open(image, &self.store).unwrap()
    }

    fn binding(&self, tenant: &str) -> SessionBinding {
        SessionBinding { tenant: tenant.into(), session: "s".into(), image: self.digest.clone() }
    }

    fn seed(&self, tenant: &str, revision: i64, text: &str) {
        let mut db = Connection::open(&self.store).unwrap();
        let tx = db.transaction().unwrap();
        tx.execute("INSERT INTO sessions(tenant,id,image,version,state) VALUES(?1,'s',?2,?3,?4)", params![tenant,self.digest,revision,text]).unwrap();
        tx.execute("UPDATE counts SET sessions=sessions+1 WHERE id=1", []).unwrap();
        tx.commit().unwrap();
    }

    fn stored(&self, tenant: &str) -> (i64, String) {
        let db = Connection::open(&self.store).unwrap();
        db.query_row("SELECT version,state FROM sessions WHERE tenant=?1 AND id='s'", [tenant], |row| Ok((row.get(0)?, row.get(1)?))).unwrap()
    }

    fn envelope(&self, tenant: &str) -> SessionEnvelope {
        let (revision, text) = self.stored(tenant);
        SessionEnvelope::recover(Some(&text), &self.binding(tenant), revision, &SessionLimits::default()).unwrap()
    }

    fn counts(&self) -> (i64, i64) {
        let db = Connection::open(&self.store).unwrap();
        db.query_row("SELECT sessions,requests FROM counts WHERE id=1", [], |r| Ok((r.get(0)?,r.get(1)?))).unwrap()
    }
}

fn plan(nodes: Value, output: usize) -> String {
    json!({"nodes":nodes,"output":output,"projection":{"kind":"entities"}}).to_string()
}

fn previous() -> String {
    plan(json!([{"op":"previous"}]), 0)
}

fn find(name: &str) -> String {
    plan(json!([{"op":"find","name":name}]), 0)
}

fn execute(runtime: &Runtime, tenant: &str, request: &str, revision: i64, plan: &str) -> String {
    runtime.execute(tenant,"s",request,revision,plan,Cancellation::default()).unwrap()
}

fn legacy(ids: &[&str]) -> String {
    json!({"schema":1,"selection":{"ids":ids,"facts":[]}}).to_string()
}

#[test]
fn successful_turn_upgrades_relation_selection_and_keeps_dialogue_unknown() {
    let f = Fixture::new();
    let fact = json!({"subject":"A","predicate":"knows","direction":"forward","object":"B","qualifiers_json":"{\"since\":[{\"type\":\"year\",\"value\":2000}]}"});
    let old = json!({"schema":1,"selection":{"ids":["B"],"facts":[fact.clone()]}}).to_string();
    f.seed("alice",7,&old);
    let runtime = f.runtime(Limits::default());
    let reply = execute(&runtime,"alice","upgrade",7,&previous());
    let decoded: Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(decoded["version"],8);
    assert_eq!(decoded["result"]["entities"],json!(["B"]));
    assert_eq!(decoded["result"]["facts"],json!([fact]));
    let state = f.envelope("alice");
    assert_eq!(state.schema,SESSION_SCHEMA);
    assert_eq!(state.revision,8);
    assert_eq!(state.coverage,StateCoverage::NativeSelectionOnly);
    assert!(state.oracle.is_none());
    assert_eq!(state.selection.facts.len(),1);
    assert!(state.selection.attributes.is_empty());
    assert_eq!(f.counts(),(1,1));
    drop(runtime);
    let runtime = f.runtime(Limits::default());
    assert_eq!(execute(&runtime,"alice","upgrade",7,&previous()),reply);
    assert_eq!(f.envelope("alice").revision,8);
    assert_eq!(f.counts(),(1,1));
}

#[test]
fn completed_retry_precedes_migration_and_preserves_exact_old_state_bytes() {
    let f = Fixture::new();
    let first = {
        let runtime = f.runtime(Limits::default());
        execute(&runtime,"alice","first",0,&find("Alice"))
    };
    // Simulate retained schema-1 bytes from the previous implementation. Keep
    // its genuine journal binding; recomputing the digest in this test would
    // fail to check compatibility with the production replay path.
    let old = legacy(&["A"]);
    let db = Connection::open(&f.store).unwrap();
    db.execute("UPDATE sessions SET state=?1 WHERE tenant='alice' AND id='s'",[&old]).unwrap();
    drop(db);
    let runtime = f.runtime(Limits::default());
    let cancellation = Cancellation::default();
    cancellation.cancel();
    assert_eq!(runtime.execute("alice","s","first",0,&find("Alice"),cancellation).unwrap(),first);
    assert_eq!(f.stored("alice"),(1,old));
    assert_eq!(f.counts(),(1,1));
    let changed = format!("{} ",find("Alice"));
    assert!(matches!(runtime.execute("alice","s","first",0,&changed,Cancellation::default()),Err(Error::Conflict(_))));
    execute(&runtime,"alice","next",1,&previous());
    assert_eq!(f.envelope("alice").revision,2);
    assert!(f.envelope("alice").oracle.is_none());
}

#[test]
fn failed_upgrade_does_not_publish_new_state_or_reply() {
    let f = Fixture::new();
    let old = legacy(&["A"]);
    f.seed("alice",4,&old);
    for limits in [
        Limits { result_bytes: 1, ..Limits::default() },
        // The old selection fits; the full bound envelope cannot fit.
        Limits { state_bytes: old.len()+1, ..Limits::default() },
    ] {
        let runtime = f.runtime(limits);
        assert!(matches!(runtime.execute("alice","s","failed",4,&previous(),Cancellation::default()),Err(Error::Limit(_))));
        assert_eq!(f.stored("alice"),(4,old.clone()));
        assert_eq!(f.counts(),(1,0));
    }
    let runtime = f.runtime(Limits::default());
    let cancellation = Cancellation::default();
    cancellation.cancel();
    assert!(matches!(runtime.execute("alice","s","failed",4,&previous(),cancellation),Err(Error::Cancelled)));
    assert_eq!(f.stored("alice"),(4,old));
    assert_eq!(f.counts(),(1,0));
    execute(&runtime,"alice","failed",4,&previous());
    assert_eq!(f.envelope("alice").revision,5);
}

#[test]
fn envelope_identity_and_schema_refusals_leave_sql_unchanged() {
    let f = Fixture::new();
    let mut state = SessionEnvelope::new(f.binding("other_tenant")).unwrap();
    state.revision = 3;
    state.selection.ids.insert("A".into());
    let wrong_identity = state.encode(&SessionLimits::default()).unwrap();
    f.seed("alice",3,&wrong_identity);
    let runtime = f.runtime(Limits::default());
    assert!(matches!(runtime.execute("alice","s","attempt",3,&previous(),Cancellation::default()),Err(Error::Conflict(_))));
    assert_eq!(f.stored("alice"),(3,wrong_identity));
    assert_eq!(f.counts(),(1,0));
    drop(runtime);
    let mut wrong_schema: Value = serde_json::to_value(&state).unwrap();
    wrong_schema["schema"] = json!(99);
    let wrong_schema = wrong_schema.to_string();
    let db = Connection::open(&f.store).unwrap();
    db.execute("UPDATE sessions SET state=?1 WHERE tenant='alice' AND id='s'",[&wrong_schema]).unwrap();
    drop(db);
    let runtime = f.runtime(Limits::default());
    assert!(matches!(runtime.execute("alice","s","attempt",3,&previous(),Cancellation::default()),Err(Error::Format(_))));
    assert_eq!(f.stored("alice"),(3,wrong_schema));
    assert_eq!(f.counts(),(1,0));
}

#[test]
fn concurrent_legacy_turns_publish_one_upgrade_and_remain_tenant_scoped() {
    let f = Fixture::new();
    f.seed("alice",9,&legacy(&["A"]));
    f.seed("bob",9,&legacy(&["B"]));
    let runtime = Arc::new(f.runtime(Limits { workers:4, ..Limits::default() }));
    let barrier = Arc::new(Barrier::new(6));
    let threads: Vec<_> = (0..6).map(|i| {
        let runtime = runtime.clone();
        let barrier = barrier.clone();
        std::thread::spawn(move || {
            barrier.wait();
            runtime.execute("alice","s",&format!("turn_{i}"),9,&previous(),Cancellation::default())
        })
    }).collect();
    let results: Vec<_> = threads.into_iter().map(|thread|thread.join().unwrap()).collect();
    assert_eq!(results.iter().filter(|r|r.is_ok()).count(),1);
    assert!(results.iter().all(|r|matches!(r,Ok(_) | Err(Error::Busy) | Err(Error::Conflict(_)))));
    assert_eq!(f.envelope("alice").revision,10);
    assert_eq!(f.counts(),(2,1));
    // Bob's old record neither upgraded nor acquired Alice's selection.
    assert_eq!(f.stored("bob"),(9,legacy(&["B"])));
    let bob: Value = serde_json::from_str(&execute(&runtime,"bob","turn_0",9,&previous())).unwrap();
    assert_eq!(bob["result"]["entities"],json!(["B"]));
    assert!(f.envelope("bob").oracle.is_none());
    assert_eq!(f.counts(),(2,2));
}

#[test]
fn attribute_statement_identity_survives_legacy_upgrade_and_restart() {
    let f = Fixture::new();
    let attribute = json!({"subject":"A","key":"mass","position":1,"value_json":"{\"type\":\"quantity\",\"unit\":\"kilogram\",\"value\":64}","qualifiers_json":"{\"since\":[{\"type\":\"year\",\"value\":2001}]}"});
    let old = json!({"schema":1,"selection":{"ids":["A"],"facts":[],"attributes":[attribute.clone()]}}).to_string();
    f.seed("alice",2,&old);
    let filter = plan(json!([
        {"op":"previous"},
        {"op":"filter_qualifier","input":0,"key":"since","predicate":{"kind":"year","literal":"2001","comparison":"="}}
    ]),1);
    let first = {
        let runtime = f.runtime(Limits::default());
        execute(&runtime,"alice","upgrade",2,&filter)
    };
    let result: Value = serde_json::from_str(&first).unwrap();
    assert_eq!(result["result"]["entities"],json!(["A"]));
    assert_eq!(result["result"]["attributes"],json!([attribute.clone()]));
    let state = f.envelope("alice");
    assert!(state.oracle.is_none());
    assert_eq!(state.selection.attributes.len(),1);
    assert_eq!(state.selection.attributes.iter().next().unwrap().position,1);
    let runtime = f.runtime(Limits::default());
    assert_eq!(execute(&runtime,"alice","upgrade",2,&filter),first);
    let next: Value = serde_json::from_str(&execute(&runtime,"alice","next",3,&previous())).unwrap();
    assert_eq!(next["result"]["attributes"],json!([attribute]));
    assert_eq!(f.envelope("alice").revision,4);
}

#[test]
fn pure_native_selection_update_preserves_explicit_imported_dialogue_fields() {
    let f = Fixture::new();
    let mut state = SessionEnvelope::new(f.binding("alice")).unwrap();
    state.revision = 5;
    let mut oracle = OracleSessionState::default();
    oracle.history.push("Alice knows Bob".into());
    oracle.context = Some(DialogueContext {
        question: Some("What is x?".into()),
        solved: [("x".into(),"9007199254740993".into())].into(),
        ..Default::default()
    });
    oracle.last_value = Some(PriorValue {
        number: "9007199254740993.001".parse().unwrap(),
        unit: "J".into(),
        origin: NumericOrigin::ExactDecimal,
    });
    state.import_oracle("explicit_adapter1".into(),oracle,&SessionLimits::default()).unwrap();
    let oracle_before = serde_json::to_value(&state.oracle).unwrap();
    f.seed("alice",5,&state.encode(&SessionLimits::default()).unwrap());
    let runtime = f.runtime(Limits::default());
    execute(&runtime,"alice","native",5,&find("Bob"));
    let after = f.envelope("alice");
    assert_eq!(after.revision,6);
    assert_eq!(after.coverage,state.coverage);
    assert_eq!(serde_json::to_value(&after.oracle).unwrap(),oracle_before);
    assert_eq!(after.selection.ids.into_iter().collect::<Vec<_>>(),["B"]);
}
