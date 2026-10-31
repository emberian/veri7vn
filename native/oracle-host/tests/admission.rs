//! Host admission/journal composition without provider fixtures. These tests
//! claim no specialist score and no physical provider cancellation guarantee.
use oracle_host::{
    config::{self, Config, HostLimits},
    service::Service,
};
use serde_json::json;

fn raw(id: &str) -> Vec<u8> {
    serde_json::to_vec(&json!({"request_id": id, "conversation_id": id, "text": "hello"})).unwrap()
}

#[test]
fn completed_query_replays_through_tenant_and_global_saturation() {
    let dir = tempfile::tempdir().unwrap();
    // Service accepts this route-free test composition; operator config::read
    // correctly requires a real provider for production startup.
    let config: Config = serde_json::from_value(json!({
        "schema": "oracle-host-v1", "journal": dir.path().join("journal.sqlite3"),
        "limits": {"capacity": 2, "tenant_capacity": 1}
    }))
    .unwrap();
    let service = Service::open(&config).unwrap();
    let a = "a".repeat(64);
    let b = "b".repeat(64);
    let completed = service.query(&a, &raw("saved"));
    assert_eq!(completed.0, 200);
    let permit_a = service.acquire(&a).unwrap();
    assert_eq!(service.query(&a, &raw("new")).0, 429);
    // Another tenant still gets the remaining slot.
    assert_eq!(service.query(&b, &raw("other")).0, 200);
    let permit_b = service.acquire(&b).unwrap();
    assert_eq!(service.health().1["busy"], 2);
    assert_eq!(service.query(&a, &raw("saved")), completed);
    assert_eq!(service.query(&b, &raw("busy")).0, 429);
    drop((permit_a, permit_b));
    // Busy responses must not consume the durable request ID.
    assert_eq!(service.query(&a, &raw("new")).0, 200);
    assert_eq!(service.query(&b, &raw("busy")).0, 200);
    assert_eq!(service.health().1["busy"], 0);
}

#[test]
fn default_policy_and_serialized_limits_are_deployment_bound() {
    let defaults = HostLimits::default();
    assert_eq!(defaults.tenant_capacity, None);
    let base = json!({"schema":"oracle-host-v1","journal":"/state/journal"});
    let identity = |value| {
        config::deployment_identity(
            &serde_json::from_value::<Config>(value).unwrap(),
            &"c".repeat(64),
        )
        .unwrap()
    };
    let original = identity(base.clone());
    for (field, value) in [
        ("tenant_capacity", json!(1)),
        ("query_ms", json!(1234)),
        ("execution_fuel", json!(1234)),
    ] {
        let mut changed = base.clone();
        changed["limits"] = json!({});
        changed["limits"][field] = value;
        assert_ne!(identity(changed), original, "{field}");
    }
}

#[test]
fn invalid_tenant_limits_are_rejected_before_provider_admission() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("host.json");
    for cap in [0, 3] {
        std::fs::write(
            &path,
            serde_json::to_vec(&json!({
                "schema": "oracle-host-v1", "journal": dir.path().join("journal.sqlite3"),
                "limits": {"capacity": 2, "tenant_capacity": cap}
            }))
            .unwrap(),
        )
        .unwrap();
        assert!(config::read(&path)
            .unwrap_err()
            .to_string()
            .contains("invalid limits"));
    }
}
