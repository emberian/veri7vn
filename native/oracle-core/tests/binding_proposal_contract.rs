use oracle_runtime_core::{
    batch,
    binding_proposal::{resolve, ProposalInput},
    build_image_with_reader, Budget, Cancellation, Image, Limits, ReaderBuildOptions,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::sync::Arc;

fn fixture() -> (tempfile::TempDir, Arc<Image>) {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("kb.json");
    let output = dir.path().join("image.sqlite");
    let kb = json!({"concepts":{},"entities":{
        "real-A":{"name":"Alice","instanceOf":[],"attributes":[
            {"key":"score","value":{"type":"quantity","value":10,"unit":"point"},"qualifiers":{}}
        ],"relations":[{"predicate":"shared","direction":"forward","object":"real-B","qualifiers":{}}]},
        "real-B":{"name":"Bob","instanceOf":[],"attributes":[{"key":"shared","value":{"type":"string","value":"ambiguous"},"qualifiers":{}}],"relations":[]}}});
    std::fs::write(&source, kb.to_string()).unwrap();
    let receipt = build_image_with_reader(
        &source,
        &output,
        1000000,
        100000,
        ReaderBuildOptions::default(),
    )
    .unwrap();
    let image = Image::open(&output, &receipt.image_sha256, Limits::default()).unwrap();
    (dir, image)
}
fn proposal(source: &str, entity: &str, role: &str, value: &str) -> ProposalInput {
    let span = |text: &str| -> Value {
        let byte = source.find(text).unwrap();
        let start = source[..byte].chars().count();
        json!({"start":start,"end":start+text.chars().count(),"text":text})
    };
    serde_json::from_value(json!({"schema":"oracle.binding-candidates.v1","source_id":"supplied",
        "source_sha256":format!("{:x}",Sha256::digest(source.as_bytes())),"offset_unit":"unicode_codepoint",
        "bindings":[{"entity":span(entity),"role":span(role),"value":span(value),"score":0.8,"status":"untrusted_proposal"}],
        "coverage":"unknown","graph_resolution":"required","empirical_status":"experimental"})).unwrap()
}

#[test]
fn conditional_proposal_uses_image_dictionary_and_existing_batch_validator() {
    let (_dir, image) = fixture();
    let source = "🪶 Alice has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let report = resolve(
        &image,
        "tenant",
        source,
        proposal(source, "Alice", "score", "10"),
        &budget,
    )
    .unwrap();
    assert_eq!(report.candidate_coverage(), "unknown");
    assert_eq!(report.proposals().len(), 1);
    assert_eq!(report.proposals()[0].binding.entity.start, 2); // codepoints, not UTF-8 bytes
    assert_eq!(report.proposals()[0].program.0[0].inputs, vec!["Alice"]);
    assert_eq!(report.proposals()[0].binding.score, 0.8);
    let prepared = batch::prepare_program(
        image.clone(),
        report.proposals()[0].program.clone(),
        &budget,
    )
    .unwrap();
    let result = batch::execute(
        &image,
        "tenant",
        &[(&prepared, batch::BatchDemand::Full)],
        &budget,
    )
    .unwrap();
    match &result.items()[0] {
        batch::ItemOutcome::Answer(batch::BatchValue::Full(value)) => {
            assert_eq!(value.value["status"], "unique");
            assert_eq!(
                value.value["candidate"],
                json!({"type":"quantity","value":10,"unit":"point"})
            );
        }
        _ => panic!("expected conditional image result"),
    }
    assert_eq!(image.active_workers(), 0);
}
#[test]
fn unresolved_names_are_not_invented_ids() {
    let (_dir, image) = fixture();
    let source = "Zelda has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let report = resolve(
        &image,
        "tenant",
        source,
        proposal(source, "Zelda", "score", "10"),
        &budget,
    )
    .unwrap();
    assert!(report.proposals().is_empty());
    assert_eq!(report.unresolved().len(), 1);
    assert_eq!(image.active_workers(), 0);
}
#[test]
fn tampered_span_or_source_digest_fails_closed() {
    let (_dir, image) = fixture();
    let source = "Alice has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let mut input = proposal(source, "Alice", "score", "10");
    input.bindings[0].entity.start = 1;
    assert!(resolve(&image, "tenant", source, input, &budget).is_err());
    let mut input = proposal(source, "Alice", "score", "10");
    input.source_sha256 = "forged".into();
    assert!(resolve(&image, "tenant", source, input, &budget).is_err());
    assert_eq!(image.active_workers(), 0);
}
#[test]
fn model_may_not_upgrade_coverage() {
    let (_dir, image) = fixture();
    let source = "Alice has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let mut input = proposal(source, "Alice", "score", "10");
    input.coverage = "complete".into();
    assert!(resolve(&image, "tenant", source, input, &budget).is_err());
}

#[test]
fn role_kind_ambiguity_retains_both_programs() {
    let (_dir, image) = fixture();
    let source = "Alice shared Bob.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let report = resolve(
        &image,
        "tenant",
        source,
        proposal(source, "Alice", "shared", "Bob"),
        &budget,
    )
    .unwrap();
    assert_eq!(report.proposals().len(), 2);
    let operations: Vec<_> = report
        .proposals()
        .iter()
        .map(|p| p.program.0[1].function)
        .collect();
    assert!(operations.contains(&oracle_runtime_core::Operation::QueryAttr));
    assert!(operations.contains(&oracle_runtime_core::Operation::Relate));
    assert_eq!(report.candidate_coverage(), "unknown");
}

#[test]
fn report_owns_retention_and_prepared_copy_has_its_own_guard() {
    let (_dir, image) = fixture();
    let source = "Alice has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    assert_eq!(budget.memory().snapshot().live, 0);
    let report = resolve(
        &image,
        "tenant",
        source,
        proposal(source, "Alice", "score", "10"),
        &budget,
    )
    .unwrap();
    assert_eq!(budget.memory().snapshot().live, 2 * 1024 * 1024);
    let prepared = batch::prepare_program(
        image.clone(),
        report.proposals()[0].program.clone(),
        &budget,
    )
    .unwrap();
    drop(report);
    assert!(budget.memory().snapshot().live > 0);
    assert!(budget.memory().snapshot().live < 2 * 1024 * 1024);
    drop(prepared);
    assert_eq!(budget.memory().snapshot().live, 0);
}

#[test]
fn oversized_unicode_indices_fail_without_traversal_or_leak() {
    let (_dir, image) = fixture();
    let source = "🪶 Alice has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let mut input = proposal(source, "Alice", "score", "10");
    input.bindings[0].entity.start = usize::MAX - 1;
    input.bindings[0].entity.end = usize::MAX;
    assert!(resolve(&image, "tenant", source, input, &budget).is_err());
    assert_eq!(budget.memory().snapshot().live, 0);
    assert_eq!(image.active_workers(), 0);
}

#[test]
fn typed_spare_capacity_is_charged_even_when_json_is_tiny() {
    let (_dir, image) = fixture();
    let source = "Alice has score 10.";
    let limits = Limits {
        request_memory_bytes: 3 * 1024 * 1024,
        ..image.limits.clone()
    };
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut input = proposal(source, "Alice", "score", "10");
    input.bindings[0].entity.text.reserve_exact(4 * 1024 * 1024);
    assert!(serde_json::to_vec(&input).unwrap().len() < 2048);
    assert!(matches!(
        resolve(&image, "tenant", source, input, &budget),
        Err(oracle_runtime_core::Error::Limit("retained request memory"))
    ));
    assert_eq!(budget.memory().snapshot().live, 0);
    assert_eq!(image.active_workers(), 0);
}

#[test]
fn full_report_obeys_image_result_bytes_and_releases_guards() {
    let (_dir, mut image) = fixture();
    Arc::get_mut(&mut image).unwrap().limits.result_bytes = 32;
    let source = "Alice has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    assert!(resolve(
        &image,
        "tenant",
        source,
        proposal(source, "Alice", "score", "10"),
        &budget
    )
    .is_err());
    assert_eq!(budget.memory().snapshot().live, 0);
    assert_eq!(image.active_workers(), 0);
}

#[test]
fn unresolved_output_does_not_inherit_typed_spare_capacity() {
    let (_dir, image) = fixture();
    let source = "Zelda has score 10.";
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let mut input = proposal(source, "Zelda", "score", "10");
    input.bindings[0].entity.text.reserve_exact(4 * 1024 * 1024);
    let report = resolve(&image, "tenant", source, input, &budget).unwrap();
    assert_eq!(report.unresolved().len(), 1);
    assert!(report.unresolved()[0].binding.entity.text.capacity() < 4096);
    assert_eq!(budget.memory().snapshot().live, 2 * 1024 * 1024);
    drop(report);
    assert_eq!(budget.memory().snapshot().live, 0);
}
