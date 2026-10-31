use oracle_host::native::{manifest_template, manifest_template_with_conversation};
use oracle_runtime_core::Limits;
use serde_json::Value;

fn schemas(value: &Value) -> Vec<String> {
    let manifest: Value = serde_json::from_str(value["manifest_json"].as_str().unwrap()).unwrap();
    manifest["schemas"]
        .as_array()
        .unwrap()
        .iter()
        .map(|row| row["id"].as_str().unwrap().to_owned())
        .collect()
}

#[test]
fn conversation_and_namespace_admission_have_distinct_release_identities() {
    let image = "a".repeat(64);
    let host = "b".repeat(64);
    let limits = Limits::default();
    let plain = manifest_template(&image, &limits, &host).unwrap();
    let covered =
        manifest_template_with_conversation(&image, &limits, &host, Some("readonly-v1"), None)
            .unwrap();
    let wikidata = manifest_template_with_conversation(
        &image,
        &limits,
        &host,
        Some("readonly-v1"),
        Some("wikidata"),
    )
    .unwrap();
    assert!(!schemas(&plain).contains(&"oracle_readonly_adapter".into()));
    assert!(schemas(&covered).contains(&"oracle_readonly_adapter".into()));
    assert!(!schemas(&covered).contains(&"oracle_wikidata_namespace".into()));
    assert!(schemas(&wikidata).contains(&"oracle_wikidata_namespace".into()));
    assert_ne!(plain["identity"], covered["identity"]);
    assert_ne!(covered["identity"], wikidata["identity"]);
    assert!(
        manifest_template_with_conversation(&image, &limits, &host, None, Some("wikidata"))
            .is_err()
    );
    assert!(
        manifest_template_with_conversation(&image, &limits, &host, Some("unknown"), None).is_err()
    );
}
