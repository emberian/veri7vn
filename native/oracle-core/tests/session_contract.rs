use oracle_runtime_core::session::*;
use oracle_runtime_core::Error;
use serde_json::json;

fn binding(tenant: &str) -> SessionBinding {
    SessionBinding { tenant: tenant.into(), session: "conversation_1".into(), image: "release_digest".into() }
}

fn limits() -> SessionLimits {
    let mut limits = SessionLimits::default();
    for owner in ["runtime_an_conversion", "runtime_dialogue", "runtime_v4_disc", "runtime_w572_reply"] {
        limits.extension_versions.insert(owner.into(), 1);
    }
    limits
}

fn extension(owner: &str, payload: serde_json::Value) -> ExtensionState {
    ExtensionState::new(owner.into(), 1, payload).unwrap()
}

fn conversational() -> SessionEnvelope {
    let mut state = SessionEnvelope::new(binding("alice")).unwrap();
    state.import_oracle("oracle10_1_adapter1".into(), OracleSessionState::default(), &limits()).unwrap();
    state
}

#[test]
fn recovery_binds_tenant_session_image_and_revision() {
    let original = conversational();
    let encoded = original.encode(&limits()).unwrap();
    let recovered = SessionEnvelope::recover(Some(&encoded), &binding("alice"), 0, &limits()).unwrap();
    assert_eq!(recovered.encode(&limits()).unwrap(), encoded);
    assert!(matches!(SessionEnvelope::recover(Some(&encoded), &binding("bob"), 0, &limits()), Err(Error::Conflict(_))));
    let mut changed_image = binding("alice");
    changed_image.image = "different_release".into();
    assert!(matches!(SessionEnvelope::recover(Some(&encoded), &changed_image, 0, &limits()), Err(Error::Conflict(_))));
    let mut changed_session = binding("alice");
    changed_session.session = "conversation_2".into();
    assert!(matches!(SessionEnvelope::recover(Some(&encoded), &changed_session, 0, &limits()), Err(Error::Conflict(_))));
    assert!(matches!(SessionEnvelope::recover(Some(&encoded), &binding("alice"), 1, &limits()), Err(Error::Conflict(_))));
    assert!(matches!(SessionEnvelope::recover(None, &binding("alice"), 3, &limits()), Err(Error::Conflict(_))));
}

#[test]
fn legacy_migration_preserves_selection_without_guessing_dialogue() {
    let old = r#"{"schema":1,"selection":{"ids":["Q42"],"facts":[]}}"#;
    assert!(SessionEnvelope::recover(Some(old), &binding("alice"), 7, &limits()).is_err());
    let migrated = SessionEnvelope::migrate_relation_v1(old, binding("alice"), 7, &limits()).unwrap();
    assert_eq!(migrated.revision, 7);
    assert!(migrated.selection.ids.contains("Q42"));
    assert_eq!(migrated.coverage, StateCoverage::NativeSelectionOnly);
    assert!(migrated.oracle.is_none());
    assert!(matches!(migrated.begin_turn(&binding("alice"), 7, true, &limits()), Err(Error::Conflict(_))));
    let turn = migrated.begin_turn(&binding("alice"), 7, false, &limits()).unwrap();
    let next = turn.commit(&migrated, &limits()).unwrap();
    assert_eq!(next.revision, 8);
    assert!(next.oracle.is_none());
    let alien = old.replace("\"schema\":1", "\"schema\":9");
    assert!(SessionEnvelope::migrate_relation_v1(&alien, binding("alice"), 7, &limits()).is_err());
}

#[test]
fn unknown_schema_fields_and_inconsistent_coverage_are_refused() {
    let state = conversational();
    let mut tree = serde_json::to_value(&state).unwrap();
    tree["schema"] = json!(999);
    assert!(SessionEnvelope::recover(Some(&tree.to_string()), &binding("alice"), 0, &limits()).is_err());
    tree = serde_json::to_value(&state).unwrap();
    tree["process_handle"] = json!(77);
    assert!(SessionEnvelope::recover(Some(&tree.to_string()), &binding("alice"), 0, &limits()).is_err());
    let mut state = state;
    state.oracle = None;
    assert!(matches!(state.validate(&limits()), Err(Error::Format(_))));
}

#[test]
fn pending_interpretation_is_consumed_only_by_committed_turn() {
    let mut state = conversational();
    state.oracle.as_mut().unwrap().pending_interpretation = Some(PendingInterpretation {
        from: "Where was he born?".into(),
        to: "Where was Douglas Adams born?".into(),
        conversion: extension("runtime_an_conversion", json!({"from":"Where was he born?", "to":"Where was Douglas Adams born?", "kind":"relation"})),
    });
    let before = state.encode(&limits()).unwrap();
    {
        let draft = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap();
        assert_eq!(draft.consumed_interpretation().unwrap().to, "Where was Douglas Adams born?");
        // Simulated evaluation failure: discard all speculative state.
    }
    assert_eq!(state.encode(&limits()).unwrap(), before);
    let draft = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap();
    let next = draft.commit(&state, &limits()).unwrap();
    assert_eq!(next.revision, 1);
    assert!(next.oracle.as_ref().unwrap().pending_interpretation.is_none());
    let retry_base = SessionEnvelope::recover(Some(&before), &binding("alice"), 0, &limits()).unwrap();
    let retried = retry_base.begin_turn(&binding("alice"), 0, true, &limits()).unwrap().commit(&retry_base, &limits()).unwrap();
    assert_eq!(next.encode(&limits()).unwrap(), retried.encode(&limits()).unwrap());
}

#[test]
fn commit_refuses_stale_or_same_revision_modified_snapshot() {
    let state = conversational();
    let draft = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap();
    let mut intervening = state.clone();
    intervening.selection.ids.insert("Q42".into());
    assert!(matches!(draft.commit(&intervening, &limits()), Err(Error::Conflict(_))));
    let draft = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap();
    let next = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap().commit(&state, &limits()).unwrap();
    assert!(matches!(draft.commit(&next, &limits()), Err(Error::Conflict(_))));
    assert_eq!(state.revision, 0);
}

#[test]
fn owner_versions_and_declared_sizes_are_checked_transactionally() {
    let mut state = SessionEnvelope::new(binding("alice")).unwrap();
    let original = state.encode(&limits()).unwrap();
    let mut snapshot = OracleSessionState::default();
    snapshot.extensions.insert("unknown_owner".into(), extension("unknown_owner", json!({"turns":3})));
    assert!(matches!(state.import_oracle("adapter1".into(), snapshot, &limits()), Err(Error::Format(_))));
    assert_eq!(original, state.encode(&limits()).unwrap());
    let mut snapshot = OracleSessionState::default();
    let mut payload = extension("runtime_dialogue", json!({"last_result":null}));
    payload.payload_bytes += 1;
    snapshot.extensions.insert("runtime_dialogue".into(), payload);
    assert!(state.import_oracle("adapter1".into(), snapshot, &limits()).is_err());
    let mut snapshot = OracleSessionState::default();
    let mut payload = extension("runtime_dialogue", json!({"last_result":null}));
    payload.version = 2;
    snapshot.extensions.insert("runtime_dialogue".into(), payload);
    assert!(state.import_oracle("adapter1".into(), snapshot, &limits()).is_err());
}

#[test]
fn byte_item_and_nested_extension_bounds_fail_without_truncation() {
    let state = conversational();
    let encoded = state.encode(&limits()).unwrap();
    let mut tiny = limits();
    tiny.max_bytes = encoded.len() - 1;
    assert!(matches!(state.encode(&tiny), Err(Error::Limit(_))));
    assert!(matches!(SessionEnvelope::recover(Some(&encoded), &binding("alice"), 0, &tiny), Err(Error::Limit(_))));
    tiny = limits();
    tiny.max_items = 2;
    assert!(matches!(state.validate(&tiny), Err(Error::Limit(_))));
    let mut deep = state.clone();
    deep.oracle.as_mut().unwrap().extensions.insert("runtime_dialogue".into(), extension("runtime_dialogue", json!({"a":{"b":{"c":1}}})));
    tiny = limits();
    tiny.max_json_depth = 5;
    assert!(matches!(deep.validate(&tiny), Err(Error::Limit(_))));
    tiny = limits();
    tiny.max_extension_bytes = 2;
    assert!(matches!(deep.validate(&tiny), Err(Error::Limit(_))));
}

#[test]
fn explicit_source_topic_reset_has_narrow_source_semantics() {
    let mut state = conversational();
    let oracle = state.oracle.as_mut().unwrap();
    oracle.context = Some(DialogueContext { question: Some("What is x?".into()), solved: [("x".into(), "5".into())].into(), ..Default::default() });
    oracle.last_value = Some(PriorValue { number: "12345678901234567890.001".parse().unwrap(), unit: "kg".into(), origin: NumericOrigin::ExactDecimal });
    oracle.last_physics = Some(PhysicsLineage { question: "How far in 5 seconds?".into(), answer: None });
    oracle.extensions.insert("runtime_v4_disc".into(), extension("runtime_v4_disc", json!({"topic":"old"})));
    oracle.extensions.insert("runtime_dialogue".into(), extension("runtime_dialogue", json!({"last_result":{"path":"fact"}})));
    let mut draft = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap();
    draft.runtime_conversation_topic_reset().unwrap();
    let next = draft.commit(&state, &limits()).unwrap();
    let oracle = next.oracle.as_ref().unwrap();
    assert!(oracle.context.as_ref().unwrap().question.is_none());
    assert!(oracle.context.as_ref().unwrap().solved.is_empty());
    assert!(oracle.last_value.is_none());
    assert!(!oracle.extensions.contains_key("runtime_v4_disc"));
    assert!(oracle.extensions.contains_key("runtime_dialogue"));
    assert_eq!(oracle.last_physics.as_ref().unwrap().question, "How far in 5 seconds?");
    assert!(state.oracle.as_ref().unwrap().last_value.is_some());
}

#[test]
fn numeric_spelling_and_effect_lineage_survive_restart_without_outcome_inference() {
    let state = conversational();
    let mut draft = state.begin_turn(&binding("alice"), 0, true, &limits()).unwrap();
    let oracle = draft.oracle_mut().unwrap();
    oracle.last_value = Some(PriorValue { number: "12345678901234567890.001".parse().unwrap(), unit: "J".into(), origin: NumericOrigin::ExactDecimal });
    oracle.last_effect = Some(EffectLineage { revision: 1, request: "turn_1".into(), effect_ids: vec!["intent_1".into()] });
    let state = draft.commit(&state, &limits()).unwrap();
    let encoded = state.encode(&limits()).unwrap();
    let recovered = SessionEnvelope::recover(Some(&encoded), &binding("alice"), 1, &limits()).unwrap();
    let oracle = recovered.oracle.unwrap();
    assert_eq!(oracle.last_value.unwrap().number.to_string(), "12345678901234567890.001");
    assert_eq!(oracle.last_effect.unwrap().effect_ids, ["intent_1"]);
    // No outcome/status is present: consult the effect journal after recovery.
}

#[test]
fn invalid_pending_mapping_and_future_lineage_are_refused() {
    let mut state = conversational();
    let oracle = state.oracle.as_mut().unwrap();
    oracle.pending_interpretation = Some(PendingInterpretation { from: "it".into(), to: "Q42".into(), conversion: extension("runtime_an_conversion", json!({"from":"it","to":"Q43"})) });
    assert!(state.validate(&limits()).is_err());
    let oracle = state.oracle.as_mut().unwrap();
    oracle.pending_interpretation = None;
    oracle.last_answer = Some(AnswerLineage { revision: 1, request: "future".into(), reply: extension("runtime_w572_reply", json!({"status":"answered","response":"hello","path":"social"})) });
    assert!(state.validate(&limits()).is_err());
}
