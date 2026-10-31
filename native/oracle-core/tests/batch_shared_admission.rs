//! Host-representative composite memory admission: restrict once, not per item.
use oracle_runtime_core::{batch, build_image, Budget, Cancellation, Image, Limits};
use serde_json::json;

#[test]
fn shared_host_scope_bounds_coexisting_preparations_while_sibling_scopes_do_not() {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source.json");
    let destination = dir.path().join("image.sqlite");
    std::fs::write(&source, json!({"concepts":{},"entities":{}}).to_string()).unwrap();
    let receipt = build_image(&source, &destination, 100_000, 1000).unwrap();
    let image = Image::open(&destination, &receipt.image_sha256, Limits::default()).unwrap();
    let program = json!([{"function":"FindAll","dependencies":[],"inputs":[]}]).to_string();
    let measure = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let one = batch::prepare(image.clone(), &program, &measure).unwrap();
    let retained = measure.memory().snapshot().live;
    assert!(retained > 0);
    drop(one);
    let limits = Limits {
        request_memory_bytes: retained * 2 - 1,
        ..Limits::default()
    };
    let image = Image::open(&destination, &receipt.image_sha256, limits.clone()).unwrap();
    let parent = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
    // This is the host contract: one restricted child surrounds the whole loop.
    let shared = parent.restricted_to(&limits).unwrap();
    let first = batch::prepare(image.clone(), &program, &shared).unwrap();
    assert!(batch::prepare(image.clone(), &program, &shared).is_err());
    assert_eq!(shared.memory().snapshot().live, retained);
    drop(first);
    assert_eq!(shared.memory().snapshot().live, 0);
    // Independent local restrictions alone do not enforce the composite cap.
    let sibling_a = parent.restricted_to(&limits).unwrap();
    let sibling_b = parent.restricted_to(&limits).unwrap();
    let a = batch::prepare(image.clone(), &program, &sibling_a).unwrap();
    let b = batch::prepare(image, &program, &sibling_b).unwrap();
    assert!(parent.memory().snapshot().live > limits.request_memory_bytes);
    drop((a, b));
    assert_eq!(parent.memory().snapshot().live, 0);
}
