//! Actual state/journal consumers of release admission. Synthetic deployment
//! measurements model an authenticated host; these tests do not attest binaries.
use oracle_runtime_core::release::{
    runtime_profile_sha256, AdmittedRelease, Availability, OperationRegistration, ReleaseBindings,
    ReleaseManifest,
};
use oracle_runtime_core::{build_image, Cancellation, Error, Image, Limits, Runtime};
use rusqlite::Connection;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tempfile::TempDir;

const OPERATIONS: [&str; 4] = ["graph.query", "graph.execute", "kqa.query", "kqa.execute"];

struct Fixture {
    directory: TempDir,
    image: Arc<Image>,
    image_path: PathBuf,
    image_sha256: String,
}

impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let image_path = directory.path().join("image.sqlite");
        let image_sha256 = build(&directory.path().join("kb.json"), &image_path, "Alice");
        let image = Image::open(&image_path, &image_sha256, Limits::default()).unwrap();
        Self {
            directory,
            image,
            image_path,
            image_sha256,
        }
    }

    fn state(&self, name: &str) -> PathBuf {
        self.directory.path().join(format!("{name}.sqlite"))
    }
}

fn build(source: &Path, image: &Path, name: &str) -> String {
    std::fs::write(
        source,
        json!({
            "concepts": {},
            "entities": {"Q1": {"name":name,"instanceOf":[],"attributes":[],"relations":[]}}
        })
        .to_string(),
    )
    .unwrap();
    build_image(source, image, 1_000_000, 100_000)
        .unwrap()
        .image_sha256
}

fn manifest(image: &Arc<Image>) -> ReleaseManifest {
    let operations: Vec<Value> = OPERATIONS
        .iter()
        .map(|id| {
            json!({
                "id":id,"version":1,"summary":id,"availability":"implemented",
                "input_schema":{"type":"object"},"output_schema":{"type":"object"},
                "resources":[],"limitations":["Synthetic fixture; no proof or binary attestation"]
            })
        })
        .collect();
    ReleaseManifest::from_json(&serde_json::to_vec(&json!({
        "schema":"oracle-native-release-v1",
        "runtime_artifact_sha256":"1".repeat(64),
        "data_image_sha256":image.identity,
        "resource_profile_sha256":runtime_profile_sha256(&image.limits).unwrap(),
        "appliance_receipt_sha256":null,
        "schemas":[{"id":"session","version":2},{"id":"graph","version":1},{"id":"kqa_program","version":1}],
        "resources":[],"operations":operations
    })).unwrap()).unwrap()
}

fn admit(manifest: ReleaseManifest) -> AdmittedRelease {
    // A real host receives this expected identity from trusted deployment
    // metadata and measures protected artifacts independently. This fixture's
    // publisher constructs both sides so that runtime mismatch checks can run.
    let expected = manifest.identity().unwrap();
    let measured = ReleaseBindings {
        runtime_artifact_sha256: manifest.runtime_artifact_sha256.clone(),
        data_image_sha256: manifest.data_image_sha256.clone(),
        resource_profile_sha256: manifest.resource_profile_sha256.clone(),
        resources: vec![],
    };
    let registrations: Vec<_> = manifest
        .operations
        .iter()
        .filter(|operation| operation.availability.is_serving())
        .map(|operation| OperationRegistration {
            id: operation.id.clone(),
            availability: operation.availability,
        })
        .collect();
    manifest
        .admit(&expected, &measured, &registrations)
        .unwrap()
}

fn graph() -> String {
    json!({"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"unique_name"}})
        .to_string()
}

fn program() -> String {
    json!([
        {"function":"Find","dependencies":[],"inputs":["Alice"]},
        {"function":"What","dependencies":[0],"inputs":[]}
    ])
    .to_string()
}

fn recorded_counts(path: &Path) -> (u64, u64) {
    Connection::open(path)
        .unwrap()
        .query_row("SELECT sessions,requests FROM counts WHERE id=1", [], |r| {
            Ok((r.get(0)?, r.get(1)?))
        })
        .unwrap()
}

#[test]
fn exact_graph_and_program_retries_survive_restart_without_execution() {
    let f = Fixture::new();
    let path = f.state("replay");
    let declaration = manifest(&f.image);
    let expected_identity = declaration.identity().unwrap();
    let runtime =
        Runtime::open_release(f.image.clone(), &path, admit(declaration.clone())).unwrap();
    assert_eq!(runtime.identity(), expected_identity);
    assert_eq!(runtime.release().unwrap().counts().implemented, 4);
    let graph_reply = runtime
        .execute(
            "tenant",
            "graph_session",
            "graph_request",
            0,
            &graph(),
            Cancellation::default(),
        )
        .unwrap();
    let program_reply = runtime
        .execute_program(
            "tenant",
            "program_session",
            "program_request",
            0,
            &program(),
            Cancellation::default(),
        )
        .unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(&graph_reply).unwrap()["version"],
        1
    );
    assert_eq!(
        serde_json::from_str::<Value>(&program_reply).unwrap()["version"],
        1
    );
    drop(runtime);

    let runtime = Runtime::open_release(f.image.clone(), &path, admit(declaration)).unwrap();
    let cancelled = Cancellation::default();
    cancelled.cancel();
    assert_eq!(
        runtime
            .execute(
                "tenant",
                "graph_session",
                "graph_request",
                0,
                &graph(),
                cancelled.clone()
            )
            .unwrap(),
        graph_reply
    );
    assert_eq!(
        runtime
            .execute_program(
                "tenant",
                "program_session",
                "program_request",
                0,
                &program(),
                cancelled
            )
            .unwrap(),
        program_reply
    );
    assert_eq!(runtime.image.active_workers(), 0);
    assert_eq!(recorded_counts(&path), (2, 2));

    // The dialect remains part of the exact journal binding, even with the
    // same release, tenant, conversation, version and request identity.
    assert!(matches!(
        runtime.execute_program(
            "tenant",
            "graph_session",
            "graph_request",
            0,
            &program(),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
    assert!(matches!(
        runtime.execute(
            "tenant",
            "graph_session",
            "graph_request",
            0,
            &(graph() + " "),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
}

#[test]
fn changed_code_profile_data_or_declaration_cannot_replay_or_reuse_sessions() {
    let f = Fixture::new();
    for constituent in ["code", "profile", "data", "declaration"] {
        let path = f.state(constituent);
        let original = manifest(&f.image);
        let runtime =
            Runtime::open_release(f.image.clone(), &path, admit(original.clone())).unwrap();
        let old_identity = runtime.identity().to_owned();
        let graph_reply = runtime
            .execute(
                "tenant",
                "graph_session",
                "graph_request",
                0,
                &graph(),
                Cancellation::default(),
            )
            .unwrap();
        let program_reply = runtime
            .execute_program(
                "tenant",
                "program_session",
                "program_request",
                0,
                &program(),
                Cancellation::default(),
            )
            .unwrap();
        drop(runtime);

        let image = match constituent {
            "profile" => Image::open(
                &f.image_path,
                &f.image_sha256,
                Limits {
                    fuel: f.image.limits.fuel + 1,
                    ..f.image.limits.clone()
                },
            )
            .unwrap(),
            "data" => {
                let new_path = f.directory.path().join("new-image.sqlite");
                let sha = build(&f.directory.path().join("new-kb.json"), &new_path, "Other");
                Image::open(&new_path, &sha, f.image.limits.clone()).unwrap()
            }
            _ => f.image.clone(),
        };
        let mut changed = manifest(&image);
        match constituent {
            "code" => changed.runtime_artifact_sha256 = "9".repeat(64),
            "declaration" => changed.operations[0].summary = "Changed declared contract".into(),
            _ => {}
        }
        let runtime = Runtime::open_release(image, &path, admit(changed)).unwrap();
        assert_ne!(runtime.identity(), old_identity, "{constituent}");
        assert!(
            matches!(
                runtime.execute(
                    "tenant",
                    "graph_session",
                    "graph_request",
                    0,
                    &graph(),
                    Cancellation::default()
                ),
                Err(Error::Conflict(_))
            ),
            "graph replay: {constituent}"
        );
        assert!(
            matches!(
                runtime.execute_program(
                    "tenant",
                    "program_session",
                    "program_request",
                    0,
                    &program(),
                    Cancellation::default()
                ),
                Err(Error::Conflict(_))
            ),
            "program replay: {constituent}"
        );
        assert!(
            matches!(
                runtime.execute(
                    "tenant",
                    "graph_session",
                    "new_graph_request",
                    1,
                    &graph(),
                    Cancellation::default()
                ),
                Err(Error::Conflict(_))
            ),
            "graph state: {constituent}"
        );
        assert!(
            matches!(
                runtime.execute_program(
                    "tenant",
                    "program_session",
                    "new_program_request",
                    1,
                    &program(),
                    Cancellation::default()
                ),
                Err(Error::Conflict(_))
            ),
            "program state: {constituent}"
        );
        assert_eq!(recorded_counts(&path), (2, 2));
        drop(runtime);

        // Refusal does not mutate or migrate the old release's retained bytes.
        let runtime = Runtime::open_release(f.image.clone(), &path, admit(original)).unwrap();
        assert_eq!(
            runtime
                .execute(
                    "tenant",
                    "graph_session",
                    "graph_request",
                    0,
                    &graph(),
                    Cancellation::default()
                )
                .unwrap(),
            graph_reply
        );
        assert_eq!(
            runtime
                .execute_program(
                    "tenant",
                    "program_session",
                    "program_request",
                    0,
                    &program(),
                    Cancellation::default()
                )
                .unwrap(),
            program_reply
        );
    }
}

#[test]
fn incompatible_image_profile_or_schema_is_refused_before_state_file_creation() {
    let f = Fixture::new();
    for mismatch in [
        "image",
        "profile",
        "session",
        "graph",
        "kqa_program",
        "missing_schema",
    ] {
        let path = f.state(&format!("invalid_{mismatch}"));
        let mut declaration = manifest(&f.image);
        match mismatch {
            "image" => declaration.data_image_sha256 = "f".repeat(64),
            "profile" => declaration.resource_profile_sha256 = "f".repeat(64),
            "missing_schema" => {
                declaration.schemas.pop();
            }
            schema => {
                declaration
                    .schemas
                    .iter_mut()
                    .find(|s| s.id == schema)
                    .unwrap()
                    .version += 1
            }
        }
        assert!(
            Runtime::open_release(f.image.clone(), &path, admit(declaration)).is_err(),
            "{mismatch}"
        );
        assert!(!path.exists(), "created state before rejecting {mismatch}");
        assert!(!PathBuf::from(format!("{}-wal", path.display())).exists());
    }
    let path = f.state("actual_limits_mismatch");
    let declaration = manifest(&f.image);
    let changed_image = Image::open(
        &f.image_path,
        &f.image_sha256,
        Limits {
            materialized_rows: f.image.limits.materialized_rows + 1,
            ..f.image.limits.clone()
        },
    )
    .unwrap();
    assert!(Runtime::open_release(changed_image, &path, admit(declaration)).is_err());
    assert!(!path.exists());
}

#[test]
fn advertised_non_native_operations_are_refused_before_evaluation_or_replay() {
    let f = Fixture::new();
    for (index, operation) in OPERATIONS.into_iter().enumerate() {
        for availability in [
            Availability::Unavailable,
            Availability::OfflineOnly,
            Availability::LegacyContained,
        ] {
            let path = f.state(&format!("gate_{index}_{availability:?}"));
            let original = manifest(&f.image);
            let runtime =
                Runtime::open_release(f.image.clone(), &path, admit(original.clone())).unwrap();
            runtime
                .execute(
                    "tenant",
                    "graph_session",
                    "graph_request",
                    0,
                    &graph(),
                    Cancellation::default(),
                )
                .unwrap();
            runtime
                .execute_program(
                    "tenant",
                    "program_session",
                    "program_request",
                    0,
                    &program(),
                    Cancellation::default(),
                )
                .unwrap();
            drop(runtime);
            let mut declaration = original;
            declaration
                .operations
                .iter_mut()
                .find(|item| item.id == operation)
                .unwrap()
                .availability = availability;
            let runtime =
                Runtime::open_release(f.image.clone(), &path, admit(declaration)).unwrap();
            let outcome = match operation {
                "graph.query" => runtime.query("tenant", &graph(), Cancellation::default()),
                "graph.execute" => runtime.execute(
                    "tenant",
                    "graph_session",
                    "graph_request",
                    0,
                    &graph(),
                    Cancellation::default(),
                ),
                "kqa.query" => runtime.query_program("tenant", &program(), Cancellation::default()),
                "kqa.execute" => runtime.execute_program(
                    "tenant",
                    "program_session",
                    "program_request",
                    0,
                    &program(),
                    Cancellation::default(),
                ),
                _ => unreachable!(),
            };
            // Invalid comes from the operation gate. A replay-first path would
            // instead return the old bytes or a changed-release Conflict.
            assert!(
                matches!(outcome, Err(Error::Invalid(_))),
                "{operation}: {availability:?}"
            );
            assert_eq!(runtime.image.active_workers(), 0);
            assert_eq!(recorded_counts(&path), (2, 2));
        }
    }
}

#[test]
fn development_constructor_cannot_reuse_release_bound_replies_or_state() {
    let f = Fixture::new();
    let path = f.state("no_development_downgrade");
    let declaration = manifest(&f.image);
    let runtime =
        Runtime::open_release(f.image.clone(), &path, admit(declaration.clone())).unwrap();
    let reply = runtime
        .execute(
            "tenant",
            "session",
            "request",
            0,
            &graph(),
            Cancellation::default(),
        )
        .unwrap();
    drop(runtime);
    let development = Runtime::open(f.image.clone(), &path).unwrap();
    assert!(matches!(
        development.execute(
            "tenant",
            "session",
            "request",
            0,
            &graph(),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
    assert!(matches!(
        development.execute(
            "tenant",
            "session",
            "new_request",
            1,
            &graph(),
            Cancellation::default()
        ),
        Err(Error::Conflict(_))
    ));
    assert_eq!(recorded_counts(&path), (1, 1));
    drop(development);
    let runtime = Runtime::open_release(f.image.clone(), &path, admit(declaration)).unwrap();
    assert_eq!(
        runtime
            .execute(
                "tenant",
                "session",
                "request",
                0,
                &graph(),
                Cancellation::default()
            )
            .unwrap(),
        reply
    );
}
