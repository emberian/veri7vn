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
