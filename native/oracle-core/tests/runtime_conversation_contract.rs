//! Cross-provider host seam: authoritative exact HTTP replay and state share one
//! transaction. Tests exercise storage boundaries, not a claim of Engine parity.
use oracle_runtime_core::context_delta::ScalarOwner;
use oracle_runtime_core::conversation::{
    ConversationBegin, ConversationCandidate, ConversationInput, ConversationRequest,
};
use oracle_runtime_core::session::{ExtensionState, OracleSessionState, StateCoverage};
use oracle_runtime_core::RequestDialect;
use oracle_runtime_core::{build_image, Budget, Cancellation, Error, Image, Limits, Runtime};
use serde_json::{json, Value};
use std::sync::Arc;
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
                "A":{"name":"Alice","instanceOf":[],"attributes":[],"relations":[]},
                "B":{"name":"Bob","instanceOf":[],"attributes":[],"relations":[]}
            }})
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
    fn budget(&self) -> Budget {
        Budget::new(&self.image.limits, Cancellation::default()).unwrap()
    }
}
fn request(text: &str) -> ConversationRequest {
    ConversationRequest {
        endpoint: "/query".into(),
        operation: "query".into(),
        expected_version: None,
        input: ConversationInput::ExactBytes(text.as_bytes().to_vec()),
    }
}
fn begin(
    runtime: &Runtime,
    rid: &str,
    req: &ConversationRequest,
    budget: &Budget,
) -> ConversationCandidate {
    match runtime
        .conversation_begin("tenant", "conversation", rid, req, budget)
        .unwrap()
    {
        ConversationBegin::Fresh(candidate) => candidate,
        ConversationBegin::Replay(_) => panic!("unexpected replay"),
    }
}
fn graph(name: &str) -> String {
    json!({"nodes":[{"op":"find","name":name}],"output":0,"projection":{"kind":"entities"}})
        .to_string()
}

#[test]
fn delivered_selection_exact_http_retry_restart_and_refusal_revision() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let req = request("Alice?");
    let mut candidate = begin(&rt, "one", &req, &budget);
    let raw = rt
        .conversation_execute(
            &mut candidate,
            RequestDialect::Graph,
            &graph("Alice"),
            &budget,
        )
        .unwrap();
    assert_eq!(serde_json::from_str::<Value>(&raw).unwrap()["version"], 1);
    let body = b"{ \"answer\" : \"Alice\", \"number\":9007199254740993 }\n";
    let committed = rt
        .conversation_commit(candidate, 201, body, &budget)
        .unwrap();
    assert_eq!(committed.body, body);
    drop(rt);
    let rt = f.runtime();
    let cancellation = Cancellation::default();
    cancellation.cancel();
    let cancelled = Budget::new(&f.image.limits, cancellation);
    // Completion needs no execution budget, and begin's replay precedes it.
    let replay = rt
        .conversation_completion("tenant", "conversation", "one", &req)
        .unwrap()
        .unwrap();
    assert_eq!(replay, committed);
    if let Ok(cancelled) = cancelled {
        assert!(matches!(
            rt.conversation_begin("tenant", "conversation", "one", &req, &cancelled)
                .unwrap(),
            ConversationBegin::Replay(_)
        ));
    }
    let candidate = begin(&rt, "refusal", &request("unknown"), &budget);
    assert_eq!(candidate.revision(), 1);
    assert!(candidate.envelope.selection.ids.contains("A"));
    rt.conversation_commit(candidate, 200, b"{\"status\":\"withheld\"}", &budget)
        .unwrap();
    let candidate = begin(&rt, "next", &request("next"), &budget);
    assert_eq!(candidate.revision(), 2);
    assert!(candidate.envelope.selection.ids.contains("A"));
}

#[test]
fn speculative_candidates_do_not_commit_and_same_revision_rewrite_conflicts() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let mut discarded = begin(&rt, "discarded", &request("candidate"), &budget);
    rt.conversation_execute(
        &mut discarded,
        RequestDialect::Graph,
        &graph("Bob"),
        &budget,
    )
    .unwrap();
    drop(discarded);
    let mut winner = begin(&rt, "winner", &request("winner"), &budget);
    assert_eq!(winner.revision(), 0);
    assert!(winner.envelope.selection.ids.is_empty());
    rt.conversation_execute(&mut winner, RequestDialect::Graph, &graph("Alice"), &budget)
        .unwrap();
    rt.conversation_commit(winner, 200, b"{}", &budget).unwrap();
    let pending = begin(&rt, "pending", &request("pending"), &budget);
    // Preserve revision while changing exact captured state bytes, demonstrating
    // why revision-only CAS would be insufficient even for a trusted host.
    let db = rusqlite::Connection::open(&f.store).unwrap();
    db.execute(
        "UPDATE sessions SET state=state || ' ' WHERE tenant='tenant' AND id='conversation'",
        [],
    )
    .unwrap();
    assert!(matches!(
        rt.conversation_commit(pending, 200, b"{}", &budget),
        Err(Error::Conflict(_))
    ));
    assert!(rt
        .conversation_completion("tenant", "conversation", "pending", &request("pending"))
        .unwrap()
        .is_none());
}

#[test]
fn endpoint_operation_conversation_typed_domain_and_legacy_collisions() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let req = request("same");
    rt.conversation_commit(begin(&rt, "id", &req, &budget), 200, b"{}", &budget)
        .unwrap();
    for changed in [
        ConversationRequest {
            endpoint: "/invoke".into(),
            ..req.clone()
        },
        ConversationRequest {
            operation: "reader.execute".into(),
            ..req.clone()
        },
        ConversationRequest {
            input: ConversationInput::Typed(json!("same")),
            ..req.clone()
        },
        ConversationRequest {
            expected_version: Some(0),
            ..req.clone()
        },
    ] {
        assert!(matches!(
            rt.conversation_completion("tenant", "conversation", "id", &changed),
            Err(Error::Conflict(_))
        ));
    }
    assert!(matches!(
        rt.conversation_completion("tenant", "other", "id", &req),
        Err(Error::Conflict(_))
    ));
    rt.execute(
        "tenant",
        "legacy",
        "legacy-id",
        0,
        &graph("Alice"),
        Cancellation::default(),
    )
    .unwrap();
    assert!(matches!(
        rt.conversation_begin("tenant", "legacy", "legacy-id", &req, &budget),
        Err(Error::Conflict(_))
    ));
    // Old entrypoints likewise cannot adopt a tagged HTTP row.
    assert!(matches!(
        rt.execute(
            "tenant",
            "conversation",
            "id",
            0,
            &graph("Alice"),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
}

#[test]
fn candidate_binding_and_unregistered_oracle_owners_cannot_commit() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let mut candidate = begin(&rt, "binding", &request("one"), &budget);
    candidate.envelope.binding.session = "other".into();
    assert!(matches!(
        rt.conversation_commit(candidate, 200, b"{}", &budget),
        Err(Error::Conflict(_))
    ));
    let mut candidate = begin(&rt, "owner", &request("two"), &budget);
    candidate.envelope.coverage = StateCoverage::OracleAdapter {
        adapter_schema: 1,
        source: "reviewed-adapter".into(),
    };
    let mut oracle = OracleSessionState::default();
    oracle.extensions.insert(
        "unknown".into(),
        ExtensionState::new("unknown".into(), 1, json!({})).unwrap(),
    );
    candidate.envelope.oracle = Some(oracle);
    assert!(rt
        .conversation_commit(candidate, 200, b"{}", &budget)
        .is_err());
    assert!(rt
        .conversation_completion("tenant", "conversation", "owner", &request("two"))
        .unwrap()
        .is_none());
}

#[test]
fn typed_owner_and_http_commit_are_atomic_with_other_native_turns() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let req = ConversationRequest {
        endpoint: "/invoke".into(),
        operation: "context.execute".into(),
        expected_version: Some(0),
        input: ConversationInput::Typed(
            json!({"op":"observe","value":{"number":"12.5","origin":"exact_decimal"}}),
        ),
    };
    let mut candidate = begin(&rt, "owner", &req, &budget);
    let command = serde_json::from_value(
        json!({"op":"observe","value":{"number":"12.5","origin":"exact_decimal"}}),
    )
    .unwrap();
    let inner = rt
        .conversation_execute_owner::<ScalarOwner>(&mut candidate, command, &budget)
        .unwrap();
    assert_eq!(serde_json::from_str::<Value>(&inner).unwrap()["version"], 1);
    // A different ordinary native turn consumes the same revision before host
    // delivery. The prepared owner and HTTP result must both lose that race.
    rt.execute(
        "tenant",
        "conversation",
        "race",
        0,
        &graph("Alice"),
        Cancellation::default(),
    )
    .unwrap();
    assert!(matches!(
        rt.conversation_commit(candidate, 200, inner.as_bytes(), &budget),
        Err(Error::Conflict(_))
    ));
    let next = begin(&rt, "next", &request("inspect"), &budget);
    assert!(!next
        .envelope
        .native_extensions
        .contains_key("native_delivered_scalar"));
}

#[test]
fn rejected_response_and_cancelled_commit_leave_no_authoritative_reply() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let invalid = begin(&rt, "status", &request("status"), &budget);
    assert!(matches!(
        rt.conversation_commit(invalid, 999, b"{}", &budget),
        Err(Error::Invalid(_))
    ));
    let invalid = begin(&rt, "encoding", &request("encoding"), &budget);
    assert!(matches!(
        rt.conversation_commit(invalid, 200, &[0xff], &budget),
        Err(Error::Invalid(_))
    ));
    let oversized = begin(&rt, "oversized", &request("oversized"), &budget);
    let bytes = vec![b'x'; f.image.limits.result_bytes + 1];
    assert!(matches!(
        rt.conversation_commit(oversized, 200, &bytes, &budget),
        Err(Error::Limit(_))
    ));
    let cancelled = begin(&rt, "cancelled", &request("cancelled"), &budget);
    let cancellation = Cancellation::default();
    let cancelled_budget = Budget::new(&f.image.limits, cancellation.clone()).unwrap();
    cancellation.cancel();
    assert!(matches!(
        rt.conversation_commit(cancelled, 200, b"{}", &cancelled_budget),
        Err(Error::Cancelled)
    ));
    let next = begin(&rt, "fresh", &request("fresh"), &budget);
    assert_eq!(next.revision(), 0);
    for name in ["status", "encoding", "oversized", "cancelled"] {
        assert!(rt
            .conversation_completion("tenant", "conversation", name, &request(name))
            .unwrap()
            .is_none());
    }
}

#[test]
fn registered_owner_without_release_operation_admission_refuses_preparation() {
    use oracle_runtime_core::release::{
        runtime_profile_sha256, OperationRegistration, ReleaseBindings, ReleaseManifest,
    };
    let f = Fixture::new();
    let manifest = ReleaseManifest::from_json(&serde_json::to_vec(&json!({
        "schema":"oracle-native-release-v1",
        "runtime_artifact_sha256":"1".repeat(64),
        "data_image_sha256":f.image.identity,
        "resource_profile_sha256":runtime_profile_sha256(&f.image.limits).unwrap(),
        "appliance_receipt_sha256":null,
        "schemas":[{"id":"session","version":3},{"id":"graph","version":1},{"id":"kqa_program","version":1},
                   {"id":"native_delivered_scalar","version":1}],
        "resources":[], "operations":[{"id":"graph.execute","version":1,"summary":"fixture","availability":"implemented",
            "input_schema":{"type":"object"},"output_schema":{"type":"object"},"resources":[],"limitations":[]}]
    })).unwrap()).unwrap();
    let expected = manifest.identity().unwrap();
    let bindings = ReleaseBindings {
        runtime_artifact_sha256: manifest.runtime_artifact_sha256.clone(),
        data_image_sha256: manifest.data_image_sha256.clone(),
        resource_profile_sha256: manifest.resource_profile_sha256.clone(),
        resources: vec![],
    };
    let registrations: Vec<_> = manifest
        .operations
        .iter()
        .map(|op| OperationRegistration {
            id: op.id.clone(),
            availability: op.availability,
        })
        .collect();
    let admitted = manifest
        .admit(&expected, &bindings, &registrations)
        .unwrap();
    let rt = Runtime::open_release(f.image.clone(), &f.store, admitted).unwrap();
    let budget = f.budget();
    let mut candidate = begin(&rt, "missing-operation", &request("observe"), &budget);
    let command = serde_json::from_value(
        json!({"op":"observe","value":{"number":"7","origin":"exact_decimal"}}),
    )
    .unwrap();
    assert!(rt
        .conversation_execute_owner::<ScalarOwner>(&mut candidate, command, &budget)
        .is_err());
    assert!(candidate.envelope.native_extensions.is_empty());
    let versions = [("oracle_readonly_adapter".to_string(), 1)]
        .into_iter()
        .collect();
    assert!(rt.with_oracle_extensions(versions).is_err());
}

#[test]
fn covered_entity_quantity_and_absence_survive_core_restart() {
    use oracle_runtime_core::session::{DialogueContext, NumericOrigin, PriorValue, Referent};
    let f = Fixture::new();
    let versions = [("oracle_readonly_adapter".to_string(), 1)]
        .into_iter()
        .collect();
    let rt = f.runtime().with_oracle_extensions(versions).unwrap();
    let budget = f.budget();
    let mut candidate = begin(&rt, "delivered", &request("delivered"), &budget);
    let mut context = DialogueContext::default();
    context.subject = Some(Referent {
        id: "kqa:A".into(),
        label: "Alice".into(),
        is_person: true,
        surface: None,
    });
    context.result = Some(PriorValue {
        number: serde_json::Number::from(6),
        unit: "kWh".into(),
        origin: NumericOrigin::ExactDecimal,
    });
    let mut oracle = OracleSessionState {
        context: Some(context),
        ..Default::default()
    };
    oracle.extensions.insert("oracle_readonly_adapter".into(),ExtensionState::new("oracle_readonly_adapter".into(),1,
        json!({"observed_owners":["context","last_value","pending_conversion"],"adapter":"fixture"})).unwrap());
    candidate.envelope.oracle = Some(oracle);
    candidate.envelope.coverage = StateCoverage::OracleAdapter {
        adapter_schema: 1,
        source: "fixture-reader-adapter-v1".into(),
    };
    rt.conversation_commit(candidate, 200, b"{\"answer\":\"6 kWh\"}", &budget)
        .unwrap();
    drop(rt);
    let versions = [("oracle_readonly_adapter".to_string(), 1)]
        .into_iter()
        .collect();
    let rt = f.runtime().with_oracle_extensions(versions).unwrap();
    let candidate = begin(&rt, "resumed", &request("resumed"), &budget);
    let oracle = candidate.envelope.oracle.as_ref().unwrap();
    assert!(oracle.last_value.is_none());
    assert!(oracle.pending_interpretation.is_none());
    let context = oracle.context.as_ref().unwrap();
    assert_eq!(context.subject.as_ref().unwrap().id, "kqa:A");
    assert_eq!(context.result.as_ref().unwrap().unit, "kWh");
    assert_eq!(context.result.as_ref().unwrap().number.as_i64(), Some(6));
    drop(candidate);
    drop(rt);
    // An unconfigured runtime cannot reinterpret an observed owner as absent.
    let rt = f.runtime();
    assert!(rt
        .conversation_begin(
            "tenant",
            "conversation",
            "unsupported",
            &request("unsupported"),
            &budget
        )
        .is_err());
}

#[test]
fn new_session_accessor_distinguishes_absent_from_retained_revision_zero() {
    let f = Fixture::new();
    let rt = f.runtime();
    let budget = f.budget();
    let absent = begin(&rt, "absent", &request("absent"), &budget);
    assert_eq!(absent.revision(), 0);
    assert!(absent.starts_new_session());
    let retained = absent
        .envelope
        .encode(&oracle_runtime_core::session::SessionLimits::default())
        .unwrap();
    drop(absent);
    // A previously persisted revision-zero envelope still has unknown Oracle
    // coverage. Its version alone cannot authorize empty-state initialization.
    let db = rusqlite::Connection::open(&f.store).unwrap();
    db.execute(
        "INSERT INTO sessions VALUES(?1,?2,?3,0,?4)",
        rusqlite::params!["tenant", "conversation", rt.identity(), retained],
    )
    .unwrap();
    db.execute("UPDATE counts SET sessions=sessions+1 WHERE id=1", [])
        .unwrap();
    let existing = begin(&rt, "existing", &request("existing"), &budget);
    assert_eq!(existing.revision(), 0);
    assert!(!existing.starts_new_session());
    assert!(existing.envelope.oracle.is_none());
}
