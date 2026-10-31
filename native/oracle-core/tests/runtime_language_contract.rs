use oracle_runtime_core::{
    build_image_with_reader,
    grammar::{FormRow, ReaderExport, ReaderPolicy, TemplateRow, READER_FORMAT, READER_VERSION},
    Cancellation, Error, Image, Limits, ReaderBuildOptions, Runtime,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{collections::BTreeMap, sync::Arc};
use tempfile::TempDir;
fn step(function: &str, dependencies: &[usize], inputs: Value) -> Value {
    json!({"function":function,"dependencies":dependencies,"inputs":inputs})
}
fn entity() -> Value {
    json!([
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("What", &[0], json!([]))
    ])
}
#[allow(dead_code)]
fn count() -> Value {
    json!([
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("Count", &[0], json!([]))
    ])
}
fn tables(skeletons: Vec<Value>) -> ReaderExport {
    ReaderExport {
        format: READER_FORMAT.into(),
        version: READER_VERSION,
        metadata: BTreeMap::from([("normalization".into(), json!("reader7_possessive"))]),
        policy: ReaderPolicy::default(),
        templates: skeletons
            .into_iter()
            .map(|skeleton| TemplateRow {
                family: "whole".into(),
                level: 0,
                template: "who is E1".into(),
                skeleton,
                support: 3,
            })
            .collect(),
        shapes: vec![],
        aliases: vec![],
        words: vec![],
        forms: vec![],
    }
}
struct Fixture {
    _directory: TempDir,
    image: Arc<Image>,
}
impl Fixture {
    fn new(mut reader: ReaderExport) -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let output = directory.path().join("reader.sqlite");
        let kb = json!({"concepts":{"P":{"name":"person","instanceOf":[]}},"entities":{
            "A":{"name":"Alice","instanceOf":["P"],"attributes":[
                {"key":"score","value":{"type":"quantity","value":10,"unit":"point"},"qualifiers":{}}
            ],"relations":[]},
            "B":{"name":"Bob","instanceOf":["P"],"attributes":[],"relations":[]},
            "C":{"name":"Bob","instanceOf":["P"],"attributes":[],"relations":[]},
            "D":{"name":"King's","instanceOf":["P"],"attributes":[],"relations":[]}
        }});
        let bytes = kb.to_string();
        std::fs::write(&source, &bytes).unwrap();
        reader.metadata.insert(
            "kb_sha256".into(),
            json!(format!("{:x}", Sha256::digest(bytes.as_bytes()))),
        );
        let receipt = build_image_with_reader(
            &source,
            &output,
            1_000_000,
            100_000,
            ReaderBuildOptions {
                reader: Some(&reader),
                ..ReaderBuildOptions::default()
            },
        )
        .unwrap();
        let limits = Limits {
            workers: 1,
            ..Limits::default()
        };
        let image = Image::open(&output, &receipt.image_sha256, limits).unwrap();
        Self {
            _directory: directory,
            image,
        }
    }
}

fn previous() -> String {
    json!({"nodes":[{"op":"previous"}],"output":0,"projection":{"kind":"names"}}).to_string()
}
#[test]
fn selection_refusal_restart_retry_and_conflicts() {
    let mut reader = tables(vec![entity()]);
    reader.templates.push(TemplateRow {
        family: "whole".into(),
        level: 0,
        template: "who counts E1".into(),
        skeleton: count(),
        support: 3,
    });
    reader.forms.push(FormRow {
        opening: "who".into(),
        kinds: vec!["entity".into()],
    });
    let fixture = Fixture::new(reader);
    let state = fixture._directory.path().join("state.sqlite");
    let runtime = Runtime::open(fixture.image.clone(), &state).unwrap();
    let first = runtime
        .execute_language("t", "s", "r", 0, "who is Alice", Cancellation::default())
        .unwrap();
    let answer: Value = serde_json::from_str(&first).unwrap();
    assert_eq!(answer["language"]["answer"], "Alice");
    assert_eq!(answer["version"], 1);
    for (session, version, question) in [
        ("other", 0, "who is Alice"),
        ("s", 1, "who is Alice"),
        ("s", 0, "who is Alice "),
    ] {
        assert!(matches!(
            runtime.execute_language(
                "t",
                session,
                "r",
                version,
                question,
                Cancellation::default()
            ),
            Err(Error::Conflict(_))
        ));
    }
    assert!(matches!(
        runtime.execute("t", "s", "r", 0, &previous(), Cancellation::default()),
        Err(Error::Conflict(_))
    ));
    let refused = runtime
        .execute_language(
            "t",
            "s",
            "refused",
            1,
            "who counts Alice",
            Cancellation::default(),
        )
        .unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&refused).unwrap()["version"],
        2
    );
    assert_eq!(
        serde_json::from_str::<Value>(&refused).unwrap()["language"]["status"],
        "refused"
    );
    drop(runtime);
    let runtime = Runtime::open(fixture.image.clone(), &state).unwrap();
    let cancelled = Cancellation::default();
    cancelled.cancel();
    assert_eq!(
        runtime
            .execute_language("t", "s", "r", 0, "who is Alice", cancelled.clone())
            .unwrap(),
        first
    );
    assert_eq!(
        runtime
            .execute_language(
                "t",
                "s",
                "refused",
                1,
                "who counts Alice",
                cancelled.clone()
            )
            .unwrap(),
        refused
    );
    assert!(matches!(
        runtime.execute_language("t", "s", "cancel", 2, "who is Alice", cancelled),
        Err(Error::Cancelled)
    ));
    let follow: Value = serde_json::from_str(
        &runtime
            .execute("t", "s", "next", 2, &previous(), Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(follow["result"]["entities"], json!(["A"]));
    let other: Value = serde_json::from_str(
        &runtime
            .execute("other", "s", "r", 0, &previous(), Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(other["result"]["entities"], json!([]));
    let program = json!([{"function":"Find","dependencies":[],"inputs":["Alice"]},{"function":"What","dependencies":[0],"inputs":[]}]).to_string();
    let follow: Value = serde_json::from_str(
        &runtime
            .execute_program("t", "s", "program", 3, &program, Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(follow["result"]["entities"], json!(["A"]));
}

fn release(
    image: &Image,
    operation: &str,
    version: u32,
) -> oracle_runtime_core::release::AdmittedRelease {
    use oracle_runtime_core::release::*;
    let manifest = ReleaseManifest::from_json(&serde_json::to_vec(&json!({
        "schema":"oracle-native-release-v1", "runtime_artifact_sha256":"1".repeat(64),
        "data_image_sha256":image.identity,
        "resource_profile_sha256":runtime_profile_sha256(&image.limits).unwrap(),
        "appliance_receipt_sha256":null,
        "schemas":[{"id":"session","version":2},{"id":"graph","version":1},{"id":"kqa_program","version":1}],
        "resources":[], "operations":[{"id":operation,"version":version,"summary":operation,
            "availability":"implemented","input_schema":{"type":"object"},"output_schema":{"type":"object"},
            "resources":[],"limitations":[]}]
    })).unwrap()).unwrap();
    let measured = ReleaseBindings {
        runtime_artifact_sha256: manifest.runtime_artifact_sha256.clone(),
        data_image_sha256: manifest.data_image_sha256.clone(),
        resource_profile_sha256: manifest.resource_profile_sha256.clone(),
        resources: vec![],
    };
    let identity = manifest.identity().unwrap();
    manifest
        .admit(
            &identity,
            &measured,
            &[OperationRegistration {
                id: operation.into(),
                availability: Availability::Implemented,
            }],
        )
        .unwrap()
}
#[test]
fn admitted_operation_is_explicit_versioned_and_requires_learned_tables() {
    let f = Fixture::new(tables(vec![entity()]));
    for (operation, version) in [("reader.whole", 1), ("reader.execute", 2)] {
        let runtime = Runtime::open_release(
            f.image.clone(),
            &f._directory
                .path()
                .join(format!("{operation}{version}.sqlite")),
            release(&f.image, operation, version),
        )
        .unwrap();
        assert!(runtime
            .execute_language("t", "s", "r", 0, "who is Alice", Cancellation::default())
            .is_err());
    }
    let path = f._directory.path().join("admitted.sqlite");
    let runtime = Runtime::open_release(
        f.image.clone(),
        &path,
        release(&f.image, "reader.execute", 1),
    )
    .unwrap();
    runtime
        .execute_language("t", "s", "r", 0, "who is Alice", Cancellation::default())
        .unwrap();
    drop(runtime);
    // A different executable release cannot reuse the old journal or session.
    let runtime = Runtime::open_release(
        f.image.clone(),
        &path,
        release(&f.image, "graph.execute", 1),
    )
    .unwrap();
    assert!(runtime
        .execute("t", "s", "r", 0, &previous(), Cancellation::default())
        .is_err());
    let source = f._directory.path().join("kb.json");
    let output = f._directory.path().join("plain.sqlite");
    let receipt = oracle_runtime_core::build_image(&source, &output, 1_000_000, 100_000).unwrap();
    let plain = Image::open(&output, &receipt.image_sha256, Limits::default()).unwrap();
    let runtime = Runtime::open_release(
        plain.clone(),
        &f._directory.path().join("plain-state.sqlite"),
        release(&plain, "reader.execute", 1),
    )
    .unwrap();
    assert!(matches!(
        runtime.execute_language("t", "s", "r", 0, "who is Alice", Cancellation::default()),
        Err(Error::Format(_))
    ));
}

#[test]
fn guarded_selection_survives_language_reply_and_durable_state_encoding() {
    use oracle_runtime_core::Budget;
    let fixture = Fixture::new(tables(vec![entity()]));
    let state = fixture._directory.path().join("guarded-state.sqlite");
    let runtime = Runtime::open(fixture.image.clone(), &state).unwrap();
    let budget = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
    let reply = runtime
        .execute_language_with_budget("t", "s", "language", 0, "who is Alice", &budget)
        .unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&reply).unwrap()["language"]["answer"],
        "Alice"
    );
    assert_eq!(budget.memory().snapshot().live, 0);
    assert!(budget.memory().snapshot().peak > 0);
    drop(runtime);
    let runtime = Runtime::open(fixture.image.clone(), &state).unwrap();
    let previous_reply = runtime
        .execute_with_budget("t", "s", "previous", 1, &previous(), &budget)
        .unwrap();
    let previous_reply: Value = serde_json::from_str(&previous_reply).unwrap();
    assert_eq!(previous_reply["result"]["entities"], json!(["A"]));
    assert_eq!(budget.memory().snapshot().live, 0);
    assert_eq!(fixture.image.active_workers(), 0);
}
