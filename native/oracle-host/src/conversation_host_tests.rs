//! Synthetic host crash/encoding boundaries; these are not specialist panels.
use super::*;

fn fixture(label: &str) -> (tempfile::TempDir, Config, Arc<Service>) {
    let directory = tempfile::tempdir().unwrap();
    let source = directory.path().join("source.json");
    std::fs::write(
        &source,
        serde_json::to_vec(
            &json!({"concepts":{},"entities":{"Q1":{"name":label,"instanceOf":[],"relations":[]}}}),
        )
        .unwrap(),
    )
    .unwrap();
    let image = directory.path().join("image.sqlite");
    let receipt = core::build_image(&source, &image, 1_000_000, 100_000).unwrap();
    let config:Config=serde_json::from_value(json!({"schema":"oracle-host-v1","conversation_profile":"readonly-v1",
        "journal":directory.path().join("host.sqlite"),"limits":{"reply_bytes":1024},
        "native":{"image":image,"image_sha256":receipt.image_sha256,"state":directory.path().join("core.sqlite"),"reader_route":false}})).unwrap();
    let service = Service::open(&config).unwrap();
    assert!(!service
        .native
        .as_ref()
        .unwrap()
        .operations()
        .contains(&"context.native"));
    (directory, config, service)
}
fn query(id: &str) -> Vec<u8> {
    wire::encode(&json!({"request_id":id,"conversation_id":"c","text":"a question with no route"}))
}
fn invoke(id: &str, version: i64) -> Vec<u8> {
    wire::encode(
        &json!({"request_id":id,"conversation_id":"c","operation_id":"context.execute","arguments":{"expected_version":version,"command":{"op":"inspect"}}}),
    )
}

#[test]
fn query_refusal_and_invoke_share_revision_and_exact_http_retry_after_restart() {
    let (_directory, config, service) = fixture("Alice");
    let tenant = "a".repeat(64);
    let q = query("query1");
    let first = service.query_encoded(&tenant, &q);
    assert_eq!(first.status(), 200);
    assert_eq!(
        service
            .invoke_encoded(&tenant, &invoke("stale", 0))
            .status(),
        409
    );
    let raw = invoke("inspect", 1);
    let turn = service.invoke_encoded(&tenant, &raw);
    assert_eq!(turn.status(), 200, "{:?}", wire::parse(turn.body()));
    assert_eq!(service.invoke_encoded(&tenant, &raw).body(), turn.body());
    assert_eq!(
        service
            .invoke_encoded(&tenant, &invoke("query1", 2))
            .status(),
        409
    );
    assert_eq!(
        service.query_encoded(&tenant, &query("inspect")).status(),
        409
    );
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    assert_eq!(restarted.query_encoded(&tenant, &q).body(), first.body());
    assert_eq!(restarted.invoke_encoded(&tenant, &raw).body(), turn.body());
    restarted.close();
}

#[test]
fn core_commit_before_host_ack_replays_success_instead_of_interrupted() {
    let (_directory, config, service) = fixture("Alice");
    let tenant = "a".repeat(64);
    let raw = query("crash");
    let request = envelope(&raw, "/query", service.limits.request_bytes).unwrap();
    let (session, id, identity) = service.conversation_identity(&request, "/query", &raw);
    let context = service.context(service.limits.query_ms).unwrap();
    let budget = core::Budget::from_execution_context(context);
    let runtime = &service.native.as_ref().unwrap().runtime;
    let candidate = match runtime
        .conversation_begin(&tenant, &session, &id, &identity, &budget)
        .unwrap()
    {
        ConversationBegin::Fresh(c) => c,
        _ => panic!("fresh"),
    };
    service
        .journal
        .begin_encoded(&tenant, "crash", &raw, 1024)
        .unwrap();
    service.journal.dispatch(&tenant, "crash", "c").unwrap();
    let exact = br#"{ "outcome":"completed", "reply":{"response":"committed"} }"#;
    runtime
        .conversation_commit(candidate, 200, exact, &budget)
        .unwrap();
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    let pending = restarted
        .journal
        .retained_request(&tenant, "crash")
        .unwrap()
        .unwrap();
    assert!(pending.1.is_none());
    assert_eq!(pending.2, "recovered_dispatched");
    let replay = restarted.query_encoded(&tenant, &raw);
    assert_eq!(replay.status(), 200);
    assert_eq!(replay.body(), exact);
    assert_ne!(
        restarted
            .journal
            .conversation(&tenant, "c")
            .unwrap()
            .unwrap()
            .1,
        "poisoned"
    );
    restarted.close();
}

#[test]
fn oversized_native_http_reply_does_not_commit_candidate_state() {
    let label = "x".repeat(6000);
    let (_directory, _config, service) = fixture(&label);
    let tenant = "a".repeat(64);
    let plan=json!({"nodes":[{"op":"find","name":label}],"output":0,"projection":{"kind":"unique_name"}}).to_string();
    let raw = wire::encode(
        &json!({"request_id":"large","conversation_id":"c","operation_id":"graph.execute","arguments":{"expected_version":0,"plan_json":plan}}),
    );
    let reply = service.invoke_encoded(&tenant, &raw);
    assert_eq!(reply.status(), 502, "{:?}", wire::parse(reply.body()));
    assert_eq!(
        wire::parse(reply.body()).unwrap()["state_may_have_changed"],
        false
    );
    // A different admitted turn still starts at revision zero.
    assert_eq!(
        service
            .invoke_encoded(&tenant, &invoke("after", 0))
            .status(),
        200
    );
    service.close();
}

#[test]
fn one_lease_blocks_both_endpoint_turns_before_snapshot() {
    let (_directory, _config, service) = fixture("Alice");
    let tenant = "a".repeat(64);
    let lease = service.journal.lease(&tenant, "c").unwrap();
    assert_eq!(service.query_encoded(&tenant, &query("q")).status(), 429);
    assert_eq!(
        service.invoke_encoded(&tenant, &invoke("i", 0)).status(),
        429
    );
    drop(lease);
    assert_eq!(
        service.invoke_encoded(&tenant, &invoke("i", 0)).status(),
        200
    );
    service.close();
}

#[test]
fn restart_before_dispatch_is_unexecuted_and_after_dispatch_requires_reset() {
    for dispatched in [false, true] {
        let (_directory, config, service) = fixture("Alice");
        let tenant = "a".repeat(64);
        let raw = query("interrupted");
        service
            .journal
            .begin_encoded(&tenant, "interrupted", &raw, 1024)
            .unwrap();
        if dispatched {
            service
                .journal
                .dispatch(&tenant, "interrupted", "c")
                .unwrap();
        }
        service.close();
        drop(service);
        let restarted = Service::open(&config).unwrap();
        let reply = restarted.query_encoded(&tenant, &raw);
        let body = wire::parse(reply.body()).unwrap();
        assert_eq!(body["error"], "interrupted");
        assert_eq!(body["state_may_have_changed"], dispatched);
        if !dispatched {
            assert_eq!(body["executed"], false);
        }
        assert_eq!(restarted.query_encoded(&tenant, &raw).body(), reply.body());
        let next = restarted.query_encoded(&tenant, &query("next"));
        assert_eq!(next.status(), if dispatched { 409 } else { 200 });
        if dispatched {
            assert_eq!(
                wire::parse(next.body()).unwrap()["error"],
                "conversation_reset_required"
            );
        }
        restarted.close();
    }
}

/// Manufactured adapter transport: exercises initialization/recovery custody,
/// not the production Python owner's semantic coverage.
fn fixture_with_engine(mode: &str) -> (tempfile::TempDir, Config, Arc<Service>) {
    let (directory, mut config, service) = fixture(&"x".repeat(6000));
    service.close();
    drop(service);
    let checkout = directory.path().join("checkout");
    std::fs::create_dir_all(checkout.join(".git")).unwrap();
    let revision = "0123456789abcdef0123456789abcdef01234567";
    std::fs::write(checkout.join(".git/HEAD"), revision).unwrap();
    let python = std::env::split_paths(&std::env::var_os("PATH").unwrap())
        .map(|p| p.join("python3"))
        .find(|p| p.is_file())
        .unwrap();
    let helper = directory.path().join("conversation_adapter.py");
    std::fs::write(&helper, "# synthetic admitted transport fixture\n").unwrap();
    let worker = directory.path().join("worker.py");
    let state = serde_json::to_string(&core::session::OracleSessionState::default()).unwrap();
    let script = format!(
        r#"import json,sys,pathlib
mode={mode:?}
log=pathlib.Path({log:?})
initial=json.loads({state:?})
initial['history']=['synthetic-initialized']
print(json.dumps({{'protocol':'oracle-engine-v1','ready':True}}),flush=True)
for line in sys.stdin:
 r=json.loads(line)
 log.write_text(log.read_text()+'dispatch\n' if log.exists() else 'dispatch\n')
 c=r['conversation']
 if c.get('op')=='project':
  assert c['state']['revision']==0 and c['state']['oracle'] is None
  assert c['delivered']['conversation_projection']=={{'preserve':True}}
  if mode=='fail':
   print(json.dumps({{'id':r['id'],'error':'mutated then failed'}}),flush=True);continue
  state=initial
 else:
  assert c['state']['oracle']['history']==['synthetic-initialized']
  state=c['state']['oracle']
 capture={{'protocol':'oracle-conversation-v1','source':'synthetic-source','adapter_schema':1,'coverage':{{'complete':True,'scope':'supported_adapter_routes'}},'state':state}}
 print(json.dumps({{'id':r['id'],'status':'answered','response':'continued','path':'synthetic','conversation':capture}}),flush=True)
"#,
        mode = mode,
        log = directory.path().join("dispatch.log").to_string_lossy(),
        state = state
    );
    std::fs::write(&worker, script).unwrap();
    let artifact = |path: std::path::PathBuf| crate::config::Artifact {
        sha256: crate::config::sha256_file(&path).unwrap(),
        path,
    };
    config.engine = Some(crate::config::EngineConfig {
        python: artifact(python),
        answerer: artifact(worker),
        conversation_adapter: Some(artifact(helper)),
        checkout,
        revision: revision.into(),
        materialization: None,
        state: directory.path().join("engine-state"),
        workers: 1,
        startup_ms: 3000,
        turn_ms: 3000,
        reply_bytes: 8192,
        specialist: None,
        compose: None,
        tip: None,
    });
    let service = Service::open(&config).unwrap();
    (directory, config, service)
}

#[test]
fn initial_invoke_captures_adapter_state_and_query_continues_after_restart() {
    let (directory, config, service) = fixture_with_engine("success");
    let tenant = "a".repeat(64);
    let raw = invoke("initial", 0);
    let reply = service.invoke_encoded(&tenant, &raw);
    assert_eq!(reply.status(), 200, "{:?}", wire::parse(reply.body()));
    assert_eq!(
        std::fs::read_to_string(directory.path().join("dispatch.log"))
            .unwrap()
            .lines()
            .count(),
        1
    );
    assert_eq!(service.invoke_encoded(&tenant, &raw).body(), reply.body());
    let changed_order=br#"{ "arguments": {"command":{"op":"inspect"}, "expected_version":0}, "operation_id":"context.execute", "conversation_id":"c", "request_id":"initial" }"#;
    assert_eq!(
        service.invoke_encoded(&tenant, changed_order).body(),
        reply.body()
    );
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    let q = restarted.query_encoded(&tenant, &query("follow"));
    assert_eq!(q.status(), 200, "{:?}", wire::parse(q.body()));
    assert_eq!(
        wire::parse(q.body()).unwrap()["reply"]["response"],
        "continued"
    );
    assert_eq!(
        std::fs::read_to_string(directory.path().join("dispatch.log"))
            .unwrap()
            .lines()
            .count(),
        2
    );
    restarted.close();
}

#[test]
fn failed_initial_invoke_capture_retains_uncertainty_and_blocks_new_dispatch() {
    let (directory, config, service) = fixture_with_engine("fail");
    let tenant = "a".repeat(64);
    let raw = invoke("initial", 0);
    let reply = service.invoke_encoded(&tenant, &raw);
    assert_eq!(
        wire::parse(reply.body()).unwrap()["state_may_have_changed"],
        true
    );
    assert_eq!(service.invoke_encoded(&tenant, &raw).body(), reply.body());
    assert_eq!(
        service
            .invoke_encoded(&tenant, &invoke("other", 0))
            .status(),
        409
    );
    assert_eq!(
        service
            .query_encoded(&tenant, &query("other-query"))
            .status(),
        409
    );
    assert_eq!(
        std::fs::read_to_string(directory.path().join("dispatch.log"))
            .unwrap()
            .lines()
            .count(),
        1
    );
    let db = rusqlite::Connection::open(&config.native.as_ref().unwrap().state).unwrap();
    assert_eq!(
        db.query_row("SELECT count(*) FROM sessions", [], |row| row
            .get::<_, u64>(0))
            .unwrap(),
        0
    );
    service.close();
}

#[test]
fn oversized_initial_invoke_refuses_before_adapter_dispatch_and_allows_valid_turn() {
    let (directory, config, service) = fixture_with_engine("success");
    let tenant = "a".repeat(64);
    let plan=json!({"nodes":[{"op":"find","name":"x".repeat(6000)}],"output":0,"projection":{"kind":"unique_name"}}).to_string();
    let raw = wire::encode(
        &json!({"request_id":"large-initial","conversation_id":"c","operation_id":"graph.execute","arguments":{"expected_version":0,"plan_json":plan}}),
    );
    let reply = service.invoke_encoded(&tenant, &raw);
    assert_eq!(reply.status(), 502);
    assert_eq!(
        wire::parse(reply.body()).unwrap()["state_may_have_changed"],
        false
    );
    assert!(!directory.path().join("dispatch.log").exists());
    assert!(service
        .journal
        .conversation(&tenant, "c")
        .unwrap()
        .is_none());
    let db = rusqlite::Connection::open(&config.native.as_ref().unwrap().state).unwrap();
    assert_eq!(
        db.query_row("SELECT count(*) FROM sessions", [], |row| row
            .get::<_, u64>(0))
            .unwrap(),
        0
    );
    assert_eq!(
        service
            .invoke_encoded(&tenant, &invoke("after-large", 0))
            .status(),
        200
    );
    assert_eq!(
        std::fs::read_to_string(directory.path().join("dispatch.log"))
            .unwrap()
            .lines()
            .count(),
        1
    );
    service.close();
}

#[test]
fn malformed_initial_native_turn_does_not_dispatch_or_poison() {
    let (directory, _config, service) = fixture_with_engine("success");
    let tenant = "a".repeat(64);
    for (id, operation, arguments) in [
        (
            "bad-plan",
            "graph.execute",
            json!({"expected_version":0,"plan_json":"not a plan"}),
        ),
        (
            "bad-command",
            "context.execute",
            json!({"expected_version":0,"command":{"op":"not-an-operation"}}),
        ),
    ] {
        let raw = wire::encode(
            &json!({"request_id":id,"conversation_id":"c","operation_id":operation,"arguments":arguments}),
        );
        let reply = service.invoke_encoded(&tenant, &raw);
        assert_ne!(reply.status(), 200);
        assert_eq!(
            wire::parse(reply.body()).unwrap()["state_may_have_changed"],
            false
        );
        assert!(!directory.path().join("dispatch.log").exists());
        assert!(service
            .journal
            .conversation(&tenant, "c")
            .unwrap()
            .is_none());
    }
    assert_eq!(
        service
            .invoke_encoded(&tenant, &invoke("valid-after-malformed", 0))
            .status(),
        200
    );
    assert_eq!(
        std::fs::read_to_string(directory.path().join("dispatch.log"))
            .unwrap()
            .lines()
            .count(),
        1
    );
    service.close();
}

#[test]
fn initial_invoke_committed_before_host_ack_replays_before_pending_ledger() {
    let (_directory, config, service) = fixture_with_engine("success");
    let tenant = "a".repeat(64);
    let raw = invoke("initial", 0);
    let request = envelope(&raw, "/invoke", service.limits.request_bytes).unwrap();
    let (session, id, identity) = service.conversation_identity(&request, "/invoke", &raw);
    let context = service.context(service.limits.invoke_ms).unwrap();
    let budget = core::Budget::from_execution_context(context.clone());
    let native = service.native.as_ref().unwrap();
    let mut candidate = match native
        .runtime
        .conversation_begin(&tenant, &session, &id, &identity, &budget)
        .unwrap()
    {
        ConversationBegin::Fresh(c) => c,
        _ => panic!("fresh"),
    };
    service
        .journal
        .begin_encoded(&tenant, "initial", &wire::encode(&request), 1024)
        .unwrap();
    let mut dispatched = false;
    let mut binding = None;
    service
        .initialize_invoke_snapshot(
            &tenant,
            &request,
            &mut candidate,
            &context,
            &mut dispatched,
            &mut binding,
        )
        .unwrap();
    assert!(dispatched);
    native
        .propose_invocation(
            &mut candidate,
            "context.execute",
            &request["arguments"],
            &budget,
        )
        .unwrap();
    let exact = br#"{ "outcome":"completed", "reply":{"response":"initial invoke committed"} }"#;
    native
        .runtime
        .conversation_commit(candidate, 200, exact, &budget)
        .unwrap();
    // Crash window: no host acknowledge_core call.
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    let replay = restarted.invoke_encoded(&tenant, &raw);
    assert_eq!(replay.status(), 200);
    assert_eq!(replay.body(), exact);
    assert_ne!(
        restarted
            .journal
            .conversation(&tenant, "c")
            .unwrap()
            .unwrap()
            .1,
        "poisoned"
    );
    assert_eq!(
        restarted
            .query_encoded(&tenant, &query("after-ack-loss"))
            .status(),
        200
    );
    restarted.close();
}

fn native_fixture() -> (tempfile::TempDir, Config, Arc<Service>) {
    let directory = tempfile::tempdir().unwrap();
    let source = directory.path().join("native-source.json");
    std::fs::write(&source,serde_json::to_vec(&json!({"concepts":{},"entities":{
        "local-alice":{"name":"Alice","instanceOf":[],"relations":[{"predicate":"place of birth","direction":"forward","object":"local-york","qualifiers":{}}]},
        "local-york":{"name":"York","instanceOf":[],"relations":[]},
        "local-robin":{"name":"Robin","instanceOf":[],"relations":[{"predicate":"place of birth","direction":"forward","object":"local-york","qualifiers":{}},{"predicate":"place of birth","direction":"forward","object":"local-other-york","qualifiers":{}}]},
        "local-other-york":{"name":"York","instanceOf":[],"relations":[]}
    }})).unwrap()).unwrap();
    let image = directory.path().join("native-image.sqlite");
    let receipt = core::build_image(&source, &image, 1_000_000, 100_000).unwrap();
    let config:Config=serde_json::from_value(json!({"schema":"oracle-host-v1","conversation_profile":"native-v1",
        "journal":directory.path().join("host.sqlite"),"native":{"image":image,"image_sha256":receipt.image_sha256,"state":directory.path().join("core.sqlite"),"reader_route":false}})).unwrap();
    let service = Service::open(&config).unwrap();
    assert_eq!(
        service
            .native
            .as_ref()
            .unwrap()
            .operations()
            .iter()
            .filter(|id| **id == "context.native")
            .count(),
        1
    );
    assert_eq!(
        service.capabilities()["conversation_profile"]["id"],
        "native-v1"
    );
    (directory, config, service)
}
fn native_query(service: &Service, tenant: &str, id: &str, text: &str) -> wire::EncodedReply {
    service.query_encoded(
        tenant,
        &wire::encode(&json!({"request_id":id,"conversation_id":"c","text":text})),
    )
}
fn native_observe(id: &str, expected: i64, number: &str, unit: &str) -> Vec<u8> {
    wire::encode(
        &json!({"request_id":id,"conversation_id":"c","operation_id":"context.native","arguments":{"expected_version":expected,
        "command":{"op":"observe","quantity":{"number":number,"unit":unit,"origin":"exact_decimal"}}}}),
    )
}
fn native_quantity(reply: &wire::EncodedReply) -> Value {
    let body = wire::parse(reply.body()).unwrap();
    body["reply"]["provenance"]["native_context"]["anchor"]["value"].clone()
}

#[test]
fn native_profile_quantity_cost_ack_topic_exact_replay_and_restart_without_python() {
    let (_directory, config, service) = native_fixture();
    let tenant = "a".repeat(64);
    let raw = native_observe("supplied", 0, "3600000", "J");
    let first = service.invoke_encoded(&tenant, &raw);
    assert_eq!(first.status(), 200, "{:?}", wire::parse(first.body()));
    let scale = native_query(&service, &tenant, "scale", "Multiply that by 2.");
    assert_eq!(native_quantity(&scale)["number"], "7200000/1");
    assert_eq!(native_quantity(&scale)["unit"], "J");
    let wrong_unit = native_query(
        &service,
        &tenant,
        "wrong-unit",
        "What does that cost at $0.20 per kwh?",
    );
    assert_eq!(
        wire::parse(wrong_unit.body()).unwrap()["reply"]["status"],
        "withheld"
    );
    let zero = native_query(&service, &tenant, "zero", "Divide that by 0.");
    assert_eq!(
        wire::parse(zero.body()).unwrap()["reply"]["status"],
        "withheld"
    );
    assert_eq!(native_quantity(&zero), native_quantity(&scale));
    let ack = native_query(&service, &tenant, "ack", "Thanks!");
    assert_eq!(native_quantity(&ack), native_quantity(&scale));
    let unsupported = native_query(&service, &tenant, "unsupported", "Teach me a new theory.");
    assert_eq!(
        wire::parse(unsupported.body()).unwrap()["reply"]["status"],
        "withheld"
    );
    let cost = native_query(
        &service,
        &tenant,
        "cost",
        "What does that cost at $0.20 per kWh?",
    );
    assert_eq!(native_quantity(&cost)["number"], "2/5");
    assert_eq!(native_quantity(&cost)["unit"], "$");
    native_query(&service, &tenant, "topic", "New topic.");
    assert_eq!(service.invoke_encoded(&tenant, &raw).body(), first.body());
    let inspect = native_query(&service, &tenant, "empty", "What was that?");
    assert_eq!(
        wire::parse(inspect.body()).unwrap()["reply"]["provenance"]["native_context"]["anchor"]
            ["kind"],
        "empty"
    );
    assert!(service.engine.is_none());
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    assert_eq!(restarted.invoke_encoded(&tenant, &raw).body(), first.body());
    let inspect = native_query(&restarted, &tenant, "restart-inspect", "What was that?");
    assert_eq!(
        wire::parse(inspect.body()).unwrap()["reply"]["provenance"]["native_context"]["anchor"]
            ["kind"],
        "empty"
    );
    restarted.close();
}

#[test]
fn native_profile_rejects_configured_engine_before_journal_or_worker_effects() {
    let (directory, mut config, service) = fixture_with_engine("fail");
    service.close();
    drop(service);
    config.conversation_profile = Some("native-v1".into());
    config.journal = directory.path().join("native-rejected.sqlite");
    let error = Service::open(&config)
        .err()
        .expect("native profile must reject Engine config");
    assert!(error.to_string().contains("native-v1 excludes Engine"));
    assert!(!config.journal.exists());
    assert!(!directory.path().join("dispatch.log").exists());
}

#[test]
fn native_source_entity_identity_ambiguity_and_topic_switch_are_atomic() {
    let (_directory, config, service) = native_fixture();
    let tenant = "a".repeat(64);
    let first = native_query(&service, &tenant, "alice", "Find entity Alice.");
    let body = wire::parse(first.body()).unwrap();
    assert_eq!(
        body["reply"]["provenance"]["source_entity"]["id"],
        "local-alice"
    );
    assert_eq!(
        body["reply"]["provenance"]["image_sha256"],
        config.native.as_ref().unwrap().image_sha256
    );
    let place = native_query(
        &service,
        &tenant,
        "birth",
        "What is the birthplace of that entity?",
    );
    assert_eq!(
        wire::parse(place.body()).unwrap()["reply"]["provenance"]["source_entity"]["id"],
        "local-york"
    );
    native_query(&service, &tenant, "robin", "Find entity Robin.");
    let ambiguous = native_query(
        &service,
        &tenant,
        "ambiguous",
        "What is the birthplace of that entity?",
    );
    let ambiguous = wire::parse(ambiguous.body()).unwrap();
    assert_eq!(ambiguous["reply"]["status"], "withheld");
    assert_eq!(
        ambiguous["reply"]["provenance"]["native_context"]["anchor"]["id"],
        "local-robin"
    );
    // Both distinct IDs remain ambiguous despite identical displayed labels.
    assert_eq!(
        ambiguous["reply"]["provenance"]["evidence"]["entities"]
            .as_array()
            .unwrap()
            .len(),
        2
    );
    let quantity = service.invoke_encoded(&tenant, &native_observe("quantity", 4, "12", "J"));
    assert_eq!(quantity.status(), 200);
    let old = native_query(&service, &tenant, "alice", "Find entity Alice.");
    assert_eq!(old.body(), first.body());
    let inspect = native_query(&service, &tenant, "inspect-quantity", "What was that?");
    assert_eq!(native_quantity(&inspect)["number"], "12");
    let db = rusqlite::Connection::open(&config.native.as_ref().unwrap().state).unwrap();
    let state: String = db
        .query_row("SELECT state FROM sessions", [], |row| row.get(0))
        .unwrap();
    let state: Value = serde_json::from_str(&state).unwrap();
    assert!(state["selection"]["ids"].as_array().unwrap().is_empty());
    assert!(state["oracle"].is_null());
    service.close();
}

#[test]
fn native_profile_does_not_adopt_retained_scalar_only_or_unknown_oracle_state() {
    for legacy_kind in ["empty", "scalar", "oracle"] {
        let (_directory, _config, service) = native_fixture();
        let tenant = "a".repeat(64);
        let raw = query("legacy-seed");
        let request = envelope(&raw, "/query", service.limits.request_bytes).unwrap();
        let (session, id, identity) = service.conversation_identity(&request, "/query", &raw);
        let budget =
            core::Budget::from_execution_context(service.context(service.limits.query_ms).unwrap());
        let runtime = &service.native.as_ref().unwrap().runtime;
        let mut candidate = match runtime
            .conversation_begin(&tenant, &session, &id, &identity, &budget)
            .unwrap()
        {
            ConversationBegin::Fresh(c) => c,
            _ => panic!("fresh"),
        };
        if legacy_kind == "oracle" {
            candidate.envelope.oracle = Some(core::session::OracleSessionState::default());
            candidate.envelope.coverage = core::session::StateCoverage::OracleAdapter {
                adapter_schema: 1,
                source: "synthetic-legacy".into(),
            };
        } else if legacy_kind == "scalar" {
            runtime
                .conversation_execute_owner::<core::context_delta::ScalarOwner>(
                    &mut candidate,
                    core::context_delta::ContextCommand::Inspect,
                    &budget,
                )
                .unwrap();
        }
        runtime
            .conversation_commit(candidate, 200, br#"{"outcome":"completed"}"#, &budget)
            .unwrap();
        let reply = native_query(&service, &tenant, "new", "What was that?");
        assert_eq!(reply.status(), 409);
        assert_eq!(
            wire::parse(reply.body()).unwrap()["error"],
            "conversation_reset_required"
        );
        service.close();
    }
}

#[test]
fn native_admitted_numeric_provider_anchor_keeps_source_identity_and_rounding() {
    use std::os::unix::fs::PermissionsExt;
    let (directory, mut config, service) = native_fixture();
    service.close();
    drop(service);
    let organ = directory.path().join("synthetic-organ");
    std::fs::write(&organ,r#"#!/bin/sh
while IFS= read -r line; do
 id=$(printf '%s' "$line" | /usr/bin/sed -E 's/.*"id":([0-9]+).*/\1/')
 case "$line" in
 *"release energy"*) printf '{"id":%s,"status":"answered","kind":"energy","response":"3600000 J","path":"synthetic","value":3600000,"unit":"J"}\n' "$id" ;;
 *"release temperature"*) printf '{"id":%s,"status":"answered","kind":"temperature","response":"20 degrees C","path":"synthetic","value":20}\n' "$id" ;;
 *) printf '{"id":%s,"status":"withheld","kind":"outside","response":"","path":"synthetic","provenance":{"taken":false}}\n' "$id" ;;
 esac
done
"#).unwrap();
    std::fs::set_permissions(&organ, std::fs::Permissions::from_mode(0o700)).unwrap();
    let digest = crate::config::sha256_file(&organ).unwrap();
    config.kernels=Some(serde_json::from_value(json!({"organs":[{"id":"synthetic-energy","executable":organ,"sha256":digest,"family":"acoustics","accept":{"kinds":["energy","temperature"],"context_regex":null}}]})).unwrap());
    let service = Service::open(&config).unwrap();
    let tenant = "a".repeat(64);
    let delivered = native_query(&service, &tenant, "energy", "release energy");
    assert_eq!(delivered.status(), 200);
    let scaled = native_query(&service, &tenant, "scaled", "Multiply that by 2.");
    let body = wire::parse(scaled.body()).unwrap();
    assert_eq!(native_quantity(&scaled)["number"], "7200000/1");
    assert_eq!(native_quantity(&scaled)["origin"], "displayed_decimal");
    assert_eq!(
        body["reply"]["provenance"]["native_context"]["delivery"]["source"]["kind"],
        "provider"
    );
    assert_eq!(
        body["reply"]["provenance"]["native_context"]["delivery"]["source"]["identity"]
            ["artifact_identity"],
        digest
    );
    let temperature = native_query(&service, &tenant, "temperature", "release temperature");
    let temperature = wire::parse(temperature.body()).unwrap();
    assert_eq!(temperature["reply"]["status"], "answered");
    assert_eq!(
        temperature["reply"]["native_context_transition"],
        "cleared_unrepresentable_answer"
    );
    let stale = native_query(&service, &tenant, "stale-scale", "Multiply that by 2.");
    let stale = wire::parse(stale.body()).unwrap();
    assert_eq!(stale["reply"]["status"], "withheld");
    assert_eq!(
        stale["reply"]["provenance"]["native_context"]["anchor"]["kind"],
        "empty"
    );
    assert!(service.engine.is_none());
    service.close();
}

#[test]
fn native_answered_reader_value_without_admitted_anchor_clears_prior_quantity() {
    use oracle_runtime_core::grammar::{
        ReaderExport, ReaderPolicy, TemplateRow, READER_FORMAT, READER_VERSION,
    };
    let (directory, mut config, service) = native_fixture();
    service.close();
    drop(service);
    let source = directory.path().join("reader-source.json");
    let bytes=serde_json::to_vec(&json!({"concepts":{},"entities":{"local-alice":{"name":"Alice","instanceOf":[],"relations":[],
        "attributes":[{"key":"temperature","value":{"type":"quantity","value":20,"unit":"degC"},"qualifiers":{}}]}}})).unwrap();
    std::fs::write(&source, &bytes).unwrap();
    let reader = ReaderExport {
        format: READER_FORMAT.into(),
        version: READER_VERSION,
        metadata: std::collections::BTreeMap::from([
            ("normalization".into(), json!("reader7_possessive")),
            (
                "kb_sha256".into(),
                json!(crate::config::sha256_bytes(&bytes)),
            ),
        ]),
        policy: ReaderPolicy::default(),
        templates: vec![TemplateRow {
            family: "whole".into(),
            level: 0,
            template: "what temperature has E1".into(),
            support: 3,
            skeleton: json!([{"function":"Find","dependencies":[],"inputs":[["@","E",1,""]]},{"function":"QueryAttr","dependencies":[0],"inputs":["temperature"]}]),
        }],
        forms: vec![],
        shapes: vec![],
        aliases: vec![],
        words: vec![],
    };
    let image = directory.path().join("reader-image.sqlite");
    let receipt = core::build_image_with_reader(
        &source,
        &image,
        1_000_000,
        100_000,
        core::ReaderBuildOptions {
            reader: Some(&reader),
            ..Default::default()
        },
    )
    .unwrap();
    let native = config.native.as_mut().unwrap();
    native.image = image;
    native.image_sha256 = receipt.image_sha256;
    native.reader_route = true;
    let service = Service::open(&config).unwrap();
    let tenant = "a".repeat(64);
    assert_eq!(
        service
            .invoke_encoded(&tenant, &native_observe("prior-energy", 0, "3600000", "J"))
            .status(),
        200
    );
    let new_answer = native_query(
        &service,
        &tenant,
        "temperature",
        "What temperature has Alice?",
    );
    let body = wire::parse(new_answer.body()).unwrap();
    assert_eq!(body["reply"]["status"], "answered");
    assert_eq!(body["reply"]["response"], "20 degC");
    assert_eq!(
        body["reply"]["native_context_transition"],
        "cleared_unrepresentable_answer"
    );
    let stale = native_query(&service, &tenant, "stale", "Multiply that by 2.");
    let stale = wire::parse(stale.body()).unwrap();
    assert_eq!(stale["reply"]["status"], "withheld");
    assert_eq!(
        stale["reply"]["provenance"]["native_context"]["anchor"]["kind"],
        "empty"
    );
    service.close();
}
