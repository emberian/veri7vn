//! Independent source-set truth cases; central validation owns execution.
use oracle_runtime_core::{
    batch::{self, BatchDemand, BatchValue, ItemOutcome},
    build_image, Budget, Cancellation, Image, Limits,
};
use serde_json::json;
use std::sync::Arc;

fn fixture() -> (tempfile::TempDir, Arc<Image>) {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source.json");
    let dest = dir.path().join("image.sqlite");
    std::fs::write(&source, json!({"concepts":{},"entities":{
        "Q1":{"name":"Alice","instanceOf":[],"attributes":[{"key":"color","value":{"type":"string","value":"red"},"qualifiers":{}}],"relations":[{"predicate":"knows","direction":"forward","object":"Q2","qualifiers":{"since":[{"type":"year","value":2000}]}}]},
        "Q2":{"name":"Bob","instanceOf":[],"attributes":[{"key":"color","value":{"type":"string","value":"blue"},"qualifiers":{}}],"relations":[]}
    }}).to_string()).unwrap();
    let receipt = build_image(&source, &dest, 1_000_000, 100_000).unwrap();
    let image = Image::open(&dest, &receipt.image_sha256, Limits::default()).unwrap();
    (dir, image)
}
fn find(name: &str) -> String {
    json!([{"function":"Find","dependencies":[],"inputs":[name]}]).to_string()
}
#[test]
fn batch_matches_singles_and_source_truth_without_previous_chaining() {
    let (_dir, image) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let alice = batch::prepare(image.clone(), &find("Alice"), &budget).unwrap();
    let bob = batch::prepare(image.clone(), &find("Bob"), &budget).unwrap();
    let requests = [
        (&alice, BatchDemand::Full),
        (&bob, BatchDemand::Full),
        (&alice, BatchDemand::Full),
    ];
    let result = batch::execute(&image, "test", &requests, &budget).unwrap();
    for (i, (prepared, demand)) in requests.iter().enumerate() {
        let single = batch::execute(&image, "test", &[(*prepared, *demand)], &budget).unwrap();
        assert_eq!(
            serde_json::to_value(&result.items()[i]).unwrap(),
            serde_json::to_value(&single.items()[0]).unwrap()
        );
    }
    let public: serde_json::Value = serde_json::from_str(
        &image
            .query_program("test", &find("Alice"), Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    let ItemOutcome::Answer(BatchValue::Full(full)) = &result.items()[0] else {
        panic!("full")
    };
    assert_eq!(serde_json::to_value(full).unwrap(), public);
    for (item, expected) in result.items().iter().zip(["Q1", "Q2", "Q1"]) {
        let ItemOutcome::Answer(BatchValue::Full(q)) = item else {
            panic!("expected full answer")
        };
        assert_eq!(q.entities, [expected]);
    }
    assert_eq!(result.costs().worker_leases, 1);
    assert_eq!(image.active_workers(), 0);
}
#[test]
fn demand_keeps_original_dead_branch_semantics_and_source_count() {
    let (_dir, image) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let dead = json!([
        {"function":"Find","dependencies":[],"inputs":["Missing"]},
        {"function":"Find","dependencies":[],"inputs":["Alice"]}
    ])
    .to_string();
    let prepared = batch::prepare(image.clone(), &dead, &budget).unwrap();
    let found = batch::prepare(image.clone(), &find("Alice"), &budget).unwrap();
    let report = batch::execute(
        &image,
        "test",
        &[
            (&prepared, BatchDemand::Exists),
            (&found, BatchDemand::Count),
        ],
        &budget,
    )
    .unwrap();
    assert!(matches!(
        report.items()[0],
        ItemOutcome::Answer(BatchValue::Exists(true))
    ));
    assert!(matches!(
        report.items()[1],
        ItemOutcome::Answer(BatchValue::Count(1))
    ));
}
#[test]
fn ownership_cancellation_and_literal_admission_fail_closed() {
    let (_dir, image) = fixture();
    let (_other_dir, other) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let prepared = batch::prepare(image.clone(), &find("Alice"), &budget).unwrap();
    assert!(batch::execute(&other, "test", &[(&prepared, BatchDemand::Full)], &budget).is_err());
    let bad = json!([{"function":"FilterNum","dependencies":[],"inputs":["mass","banana","="]}])
        .to_string();
    assert!(batch::prepare(image.clone(), &bad, &budget).is_err());
    let cancellation = Cancellation::default();
    let cancelled = Budget::new(&image.limits, cancellation.clone()).unwrap();
    cancellation.cancel();
    assert!(batch::execute(
        &image,
        "test",
        &[(&prepared, BatchDemand::Full)],
        &cancelled
    )
    .is_err());
    assert_eq!(image.active_workers(), 0);
}
#[test]
fn returned_values_hold_memory_until_owner_drops() {
    let (_dir, image) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let prepared = batch::prepare(image.clone(), &find("Alice"), &budget).unwrap();
    let before = budget.memory().snapshot().live;
    let report =
        batch::execute(&image, "test", &[(&prepared, BatchDemand::Full)], &budget).unwrap();
    assert!(budget.memory().snapshot().live > before);
    drop(report);
    assert_eq!(budget.memory().snapshot().live, before);
    drop(prepared);
    assert_eq!(budget.memory().snapshot().live, 0);
}
#[test]
fn exhausted_shared_fuel_names_failure_and_every_unattempted_item() {
    let (_dir, image) = fixture();
    let preparation = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let prepared = batch::prepare(image.clone(), &find("Alice"), &preparation).unwrap();
    let limits = Limits {
        fuel: 1,
        ..image.limits.clone()
    };
    let execution = Budget::new(&limits, Cancellation::default()).unwrap();
    let report = batch::execute(
        &image,
        "test",
        &[
            (&prepared, BatchDemand::Full),
            (&prepared, BatchDemand::Full),
        ],
        &execution,
    )
    .unwrap();
    assert!(matches!(report.items()[0], ItemOutcome::Failed(_)));
    assert!(matches!(report.items()[1], ItemOutcome::NotRun));
    assert_eq!(report.costs().items_attempted, 1);
    assert_eq!(image.active_workers(), 0);
}

#[test]
fn shared_column_predicates_keep_truth_and_measure_actual_reuse() {
    let (_dir, image) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let query = |color: &str| {
        json!([
            {"function":"FindAll","dependencies":[],"inputs":[]},
            {"function":"FilterStr","dependencies":[0],"inputs":["color",color]}
        ])
        .to_string()
    };
    let red = batch::prepare(image.clone(), &query("red"), &budget).unwrap();
    let blue = batch::prepare(image.clone(), &query("blue"), &budget).unwrap();
    let report = batch::execute(
        &image,
        "test",
        &[
            (&red, BatchDemand::Full),
            (&blue, BatchDemand::Full),
            (&red, BatchDemand::Count),
        ],
        &budget,
    )
    .unwrap();
    assert_eq!(report.costs().distinct_columns, 1);
    assert_eq!(report.costs().column_rows_decoded, 2);
    assert_eq!(report.costs().column_cache_hits, 1);
    assert!(report.costs().stage_cache_hits >= 3);
    for (i, id) in [(0, "Q1"), (1, "Q2")] {
        let ItemOutcome::Answer(BatchValue::Full(full)) = &report.items()[i] else {
            panic!("full")
        };
        assert_eq!(full.entities, [id]);
        assert_eq!(full.attributes.len(), 1);
        let public: serde_json::Value = serde_json::from_str(
            &image
                .query_program(
                    "test",
                    &query(if i == 0 { "red" } else { "blue" }),
                    Cancellation::default(),
                )
                .unwrap(),
        )
        .unwrap();
        assert_eq!(serde_json::to_value(full).unwrap(), public);
    }
    assert!(matches!(
        report.items()[2],
        ItemOutcome::Answer(BatchValue::Count(1))
    ));
}
#[test]
fn graph_previous_is_empty_per_item_and_mode_does_not_leak() {
    let (_dir, image) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let alice = batch::prepare(image.clone(), &find("Alice"), &budget).unwrap();
    let graph = oracle_runtime_core::Plan {
        nodes: vec![oracle_runtime_core::Node::Previous],
        output: 0,
        projection: oracle_runtime_core::Projection::Entities,
    };
    let previous = batch::prepare_graph(
        image.clone(),
        &serde_json::to_string(&graph).unwrap(),
        &budget,
    )
    .unwrap();
    let report = batch::execute(
        &image,
        "test",
        &[(&alice, BatchDemand::Full), (&previous, BatchDemand::Count)],
        &budget,
    )
    .unwrap();
    assert!(matches!(
        report.items()[1],
        ItemOutcome::Answer(BatchValue::Count(0))
    ));
    let guarded =
        batch::execute_guarded(&image, "test", &[(&previous, BatchDemand::Exists)], &budget)
            .unwrap();
    assert!(matches!(guarded.items()[0], ItemOutcome::Refused));
}
#[test]
fn aggregate_output_overflow_refuses_instead_of_truncating() {
    let (dir, image) = fixture();
    let limited = Image::open(
        &dir.path().join("image.sqlite"),
        image.verified_identity(),
        Limits {
            result_bytes: 128,
            ..Limits::default()
        },
    )
    .unwrap();
    let budget = Budget::new(&limited.limits, Cancellation::default()).unwrap();
    let prepared = batch::prepare(limited.clone(), &find("Alice"), &budget).unwrap();
    assert!(batch::execute(&limited, "test", &[(&prepared, BatchDemand::Full)], &budget).is_err());
    assert_eq!(limited.active_workers(), 0);
}
#[test]
fn typed_plan_spare_capacity_is_charged_instead_of_wire_length() {
    let (_dir, image) = fixture();
    let budget = Budget::new(
        &Limits {
            request_memory_bytes: 1024,
            ..image.limits.clone()
        },
        Cancellation::default(),
    )
    .unwrap();
    let mut nodes = Vec::with_capacity(128);
    nodes.push(oracle_runtime_core::Node::All);
    let plan = oracle_runtime_core::Plan {
        nodes,
        output: 0,
        projection: oracle_runtime_core::Projection::Entities,
    };
    assert!(batch::prepare_plan(image, plan, &budget).is_err());
    assert_eq!(budget.memory().snapshot().live, 0);
}

#[test]
fn relation_qualifiers_survive_reused_stages_with_exact_single_equivalence() {
    let (_dir, image) = fixture();
    let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
    let make = |year: &str| {
        json!([
            {"function":"Find","dependencies":[],"inputs":["Alice"]},
            {"function":"Relate","dependencies":[0],"inputs":["knows","forward"]},
            {"function":"QFilterYear","dependencies":[1],"inputs":["since",year,"="]}
        ])
        .to_string()
    };
    let positive = batch::prepare(image.clone(), &make("2000"), &budget).unwrap();
    let negative = batch::prepare(image.clone(), &make("2001"), &budget).unwrap();
    let report = batch::execute(
        &image,
        "test",
        &[
            (&positive, BatchDemand::Full),
            (&negative, BatchDemand::Full),
        ],
        &budget,
    )
    .unwrap();
    for (index, year) in [(0, "2000"), (1, "2001")] {
        let ItemOutcome::Answer(BatchValue::Full(full)) = &report.items()[index] else {
            panic!("full")
        };
        let public: serde_json::Value = serde_json::from_str(
            &image
                .query_program("test", &make(year), Cancellation::default())
                .unwrap(),
        )
        .unwrap();
        assert_eq!(serde_json::to_value(full).unwrap(), public);
        assert_eq!(full.entities.len(), if index == 0 { 1 } else { 0 });
        if index == 0 {
            assert_eq!(full.entities, ["Q2"]);
            assert_eq!(full.facts.len(), 1);
            let qualifiers: serde_json::Value =
                serde_json::from_str(&full.facts[0].qualifiers_json).unwrap();
            assert_eq!(qualifiers["since"][0]["value"], 2000);
        }
    }
}
