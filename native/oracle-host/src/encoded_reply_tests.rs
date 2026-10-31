//! Final-response, retained-byte and compatibility tests. No provider assurance
//! or specialist score follows from these synthetic query completions.
use super::*;

fn fixture() -> (tempfile::TempDir, Config, Arc<Service>) {
    let dir = tempfile::tempdir().unwrap();
    let config: Config = serde_json::from_value(json!({
        "schema": "oracle-host-v1", "journal": dir.path().join("journal.sqlite3"),
        "limits": {"reply_bytes": 1024, "capacity": 1}
    }))
    .unwrap();
    let service = Service::open(&config).unwrap();
    (dir, config, service)
}

fn request(id: &str) -> Vec<u8> {
    wire::encode(&json!({"request_id":id,"conversation_id":"conversation","text":"hello"}))
}

fn dispatch(service: &Service, tenant: &str, id: &str, raw: &[u8]) {
    assert!(matches!(
        service
            .journal
            .begin_encoded(tenant, id, raw, 1024)
            .unwrap(),
        EncodedLookup::Fresh
    ));
    service
        .journal
        .dispatch(tenant, id, "conversation")
        .unwrap();
    service
        .journal
        .bind(tenant, "conversation", 0, "generation")
        .unwrap();
}

#[test]
fn oversized_completed_query_retains_refusal_bytes_and_poison_across_restart() {
    let (_directory, config, service) = fixture();
    let tenant = "a".repeat(64);
    let raw = request("oversized");
    dispatch(&service, &tenant, "oversized", &raw);
    let result = json!({"outcome":"completed","reply":{"response":"x".repeat(4096)}});
    let reply = service.finish_query(&tenant, "oversized", "conversation", result);
    assert_eq!(reply.status(), 502);
    assert!(reply.body().len() <= 1024);
    let value = wire::parse(reply.body()).unwrap();
    assert_eq!(value["error"], "reply_too_large");
    assert_eq!(value["execution_completed"], true);
    assert_eq!(value["state_may_have_changed"], true);
    assert_eq!(
        service
            .journal
            .conversation(&tenant, "conversation")
            .unwrap()
            .unwrap()
            .1,
        "poisoned"
    );
    let permit = service.acquire(&tenant).unwrap();
    let replay = service.query_encoded(&tenant, &raw);
    assert_eq!(replay.body(), reply.body());
    assert_eq!(replay.status(), reply.status());
    assert_eq!(service.query(&tenant, &raw), (reply.status(), value));
    drop(permit);
    service.close();
    drop(service);
    let restarted = Service::open(&config).unwrap();
    let replay = restarted.query_encoded(&tenant, &raw);
    assert_eq!(replay.status(), reply.status());
    assert_eq!(replay.body(), reply.body());
    let changed = wire::encode(
        &json!({"request_id":"oversized","conversation_id":"conversation","text":"changed"}),
    );
    assert_eq!(restarted.query_encoded(&tenant, &changed).status(), 409);
    assert_eq!(
        restarted
            .journal
            .conversation(&tenant, "conversation")
            .unwrap()
            .unwrap()
            .1,
        "poisoned"
    );
    restarted.close();
}

#[test]
fn oversized_uncertainty_replacement_uses_same_status_on_immediate_and_replay_paths() {
    let (_directory, _config, service) = fixture();
    let tenant = "b".repeat(64);
    let raw = request("uncertain");
    dispatch(&service, &tenant, "uncertain", &raw);
    let body = failure(
        "query_timeout",
        json!({"http_status":504,"detail":"x".repeat(4096),
        "state_may_have_changed":true,"exact_retry_required":true,"retryable":false}),
    );
    let reply = service.encode_response(504, &body);
    service
        .journal
        .finish_bytes(&tenant, "uncertain", "conversation", reply.body(), false)
        .unwrap();
    let value = wire::parse(reply.body()).unwrap();
    assert_eq!(reply.status(), 502);
    assert_eq!(value["http_status"], 502);
    assert_eq!(value["state_may_have_changed"], true);
    assert_eq!(value["exact_retry_required"], true);
    let replay = service.query_encoded(&tenant, &raw);
    assert_eq!(replay.status(), reply.status());
    assert_eq!(replay.body(), reply.body());
    assert_eq!(
        service
            .journal
            .conversation(&tenant, "conversation")
            .unwrap()
            .unwrap()
            .1,
        "poisoned"
    );
    service.close();
}

#[test]
fn successful_query_uses_existing_canonical_bytes_and_value_adapter() {
    let (_directory, _config, service) = fixture();
    let tenant = "c".repeat(64);
    let raw = request("saved");
    dispatch(&service, &tenant, "saved", &raw);
    let result = wire::parse(r#"{"outcome":"completed","reply":{"decimal":51.248178375505404,"huge":123456789012345678901234567890,"text":"snowman ☃"}}"#.as_bytes()).unwrap();
    let canonical = wire::encode(&result);
    let reply = service.finish_query(&tenant, "saved", "conversation", result.clone());
    assert_eq!(reply.body(), canonical);
    assert_eq!(
        service
            .journal
            .conversation(&tenant, "conversation")
            .unwrap()
            .unwrap()
            .1,
        "generation"
    );
    assert_eq!(service.query(&tenant, &raw), (200, result));
    assert_eq!(service.query_encoded(&tenant, &raw).body(), canonical);
    let malformed = service.invoke_encoded(&tenant, b"{}");
    assert_eq!(malformed.status(), 400);
    assert_eq!(service.invoke(&tenant, b"{}"), malformed.into_value());
    service.close();
}
