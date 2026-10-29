use oracle_runtime_core::{
    build_image, operation_catalog, Cancellation, Image, Limits, Operation, Program,
};
use serde_json::{json, Value};
use std::sync::Arc;
use tempfile::TempDir;

fn step(function: &str, dependencies: &[usize], inputs: &[&str]) -> Value {
    json!({"function":function,"dependencies":dependencies,"inputs":inputs})
}

fn compile(steps: Value) -> oracle_runtime_core::Result<oracle_runtime_core::Plan> {
    Program::parse(&steps.to_string(), &Limits::default())?.compile(&Limits::default())
}

struct Fixture {
    _directory: TempDir,
    image: Arc<Image>,
}

impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("source.json");
        let destination = directory.path().join("image.sqlite");
        let kb = json!({
            "concepts":{"C":{"name":"Person","instanceOf":[]}},
            "entities":{
                "Q1":{"name":"Alice","instanceOf":["C"],"attributes":[
                    {"key":"mass","value":{"type":"quantity","value":64,"unit":"kilogram"},
                        "qualifiers":{"since":[{"type":"year","value":2000}]}},
                    {"key":"score","value":{"type":"quantity","value":10,"unit":"point"},"qualifiers":{}},
                    {"key":"born","value":{"type":"date","value":"2000/02/29"},"qualifiers":{}}
                ],"relations":[
                    {"predicate":"meets","direction":"forward","object":"Q2",
                        "qualifiers":{"since":[{"type":"year","value":2000}]}},
                    {"predicate":"meets","direction":"forward","object":"Q3",
                        "qualifiers":{"since":[{"type":"year","value":2001}]}}
                ]},
                "Q2":{"name":"Bob","instanceOf":["C"],"attributes":[
                    {"key":"score","value":{"type":"quantity","value":20,"unit":"point"},"qualifiers":{}}
                ],"relations":[]},
                "Q3":{"name":"Bob","instanceOf":["C"],"attributes":[
                    {"key":"score","value":{"type":"quantity","value":20,"unit":"point"},"qualifiers":{}}
                ],"relations":[]}
            }
        });
        std::fs::write(&source, kb.to_string()).unwrap();
        let receipt = build_image(&source, &destination, 1_000_000, 100_000).unwrap();
        let image = Image::open(&destination, &receipt.image_sha256, Limits::default()).unwrap();
        Self {
            _directory: directory,
            image,
        }
    }

    fn run(&self, steps: Vec<Value>) -> Value {
        let plan = compile(json!(steps)).unwrap();
        let encoded = serde_json::to_string(&plan).unwrap();
        serde_json::from_str(
            &self
                .image
                .query("test", &encoded, Cancellation::default())
                .unwrap(),
        )
        .unwrap()
    }
}

#[test]
fn closed_catalog_matches_the_shipped_twenty_seven_operations() {
    let catalog = operation_catalog();
    assert_eq!(catalog.len(), 27);
    assert!(catalog.iter().all(|contract| contract.supported));
    assert_eq!(Operation::QueryRelationQualifier.contract().inputs, 2);
    // Unknown Python names are never an execution escape hatch.
    for name in ["__getattribute__", "name", "run", "What ", "FilterBoolean"] {
        assert!(compile(json!([step(name, &[], &[])])).is_err());
    }
}

#[test]
fn every_admitted_operation_has_a_native_lowering() {
    let cases: &[(&str, &[&str], &str)] = &[
        ("FilterConcept", &["Person"], "filter_concept"),
        ("FilterStr", &["label", "Alice"], "filter_attribute"),
        (
            "FilterNum",
            &["mass", "64 kilogram", "="],
            "filter_attribute",
        ),
        ("FilterYear", &["born", "2000", ">"], "filter_attribute"),
        (
            "FilterDate",
            &["born", "2000-02-29", "="],
            "filter_attribute",
        ),
        ("QFilterStr", &["note", "Alpha"], "filter_qualifier"),
        (
            "QFilterNum",
            &["mass", "64 kilogram", "!="],
            "filter_qualifier",
        ),
        ("QFilterYear", &["since", "2000", "<"], "filter_qualifier"),
        (
            "QFilterDate",
            &["since", "2000-02-29", "="],
            "filter_qualifier",
        ),
        ("Relate", &["meets", "forward"], "relate"),
    ];
    for (function, inputs, op) in cases {
        let plan = compile(json!([
            step("FindAll", &[], &[]),
            step(function, &[0], inputs)
        ]))
        .unwrap();
        assert_eq!(serde_json::to_value(plan).unwrap()["nodes"][1]["op"], *op);
    }
    for (function, inputs) in [
        ("VerifyStr", vec!["Alice"]),
        ("VerifyNum", vec!["64 kilogram", "="]),
        ("VerifyYear", vec!["2000", "="]),
        ("VerifyDate", vec!["2000-02-29", "="]),
    ] {
        let plan = compile(json!([
            step("Find", &[], &["Alice"]),
            step("QueryAttr", &[0], &["mass"]),
            step(function, &[1], &inputs)
        ]))
        .unwrap();
        assert_eq!(
            serde_json::to_value(plan).unwrap()["projection"]["kind"],
            "verify"
        );
    }
}

#[test]
fn dependency_order_and_types_are_checked_even_in_dead_branches() {
    for dependency in [0, 1, usize::MAX] {
        assert!(compile(json!([
            step("What", &[dependency], &[]),
            step("Find", &[], &["Alice"])
        ]))
        .is_err());
    }
    assert!(compile(json!([
        step("Find", &[], &["Alice"]),
        step("What", &[0], &[]),
        step("FilterConcept", &[1], &["Person"])
    ]))
    .is_err());
    assert!(compile(json!([
        step("Find", &[], &["Alice"]),
        step("VerifyStr", &[0], &["Alice"])
    ]))
    .is_err());
}

#[test]
fn arity_literals_directions_and_unknown_fields_are_strict() {
    let malformed = [
        json!([]),
        json!([step("Find", &[], &[])]),
        json!([step("FindAll", &[], &["extra"])]),
        json!([
            step("FindAll", &[], &[]),
            step("Relate", &[0], &["meets", "sideways"])
        ]),
        json!([
            step("FindAll", &[], &[]),
            step("FilterNum", &[0], &["mass", "NaN kilogram", "="])
        ]),
        json!([
            step("FindAll", &[], &[]),
            step("FilterNum", &[0], &["mass", "64 kilogram", "<="])
        ]),
        json!([
            step("FindAll", &[], &[]),
            step("FilterDate", &[0], &["born", "1900-02-29", "="])
        ]),
        json!([
            step("FindAll", &[], &[]),
            step("SelectAmong", &[0], &["mass", "whatever"])
        ]),
        json!([{"function":"Find","dependencies":[],"inputs":["Alice"],"callback":"os.system"}]),
        json!([{"function":"Find","dependencies":[],"inputs":[42]}]),
    ];
    for program in malformed {
        assert!(compile(program.clone()).is_err(), "accepted {program}");
    }
}

#[test]
fn bounds_apply_to_wire_and_programmatic_callers() {
    let limits = Limits {
        plan_nodes: 1,
        ..Limits::default()
    };
    assert!(Program::parse(
        &json!([step("FindAll", &[], &[]), step("Count", &[0], &[])]).to_string(),
        &limits
    )
    .is_err());
    let program: Program = serde_json::from_value(json!([step("Find", &[], &["Alice"])])).unwrap();
    let limits = Limits {
        request_bytes: 8,
        ..Limits::default()
    };
    assert!(program.validate(&limits).is_err());
}

#[test]
fn scalar_steps_do_not_corrupt_entity_dependency_indices() {
    let plan = compile(json!([
        step("Find", &[], &["Alice"]),
        step("Count", &[0], &[]), // unused scalar occupies a program index only
        step("Find", &[], &["Bob"]),
        step("Or", &[0, 2], &[]),
        step("Count", &[3], &[])
    ]))
    .unwrap();
    let wire = serde_json::to_value(plan).unwrap();
    assert_eq!(wire["nodes"].as_array().unwrap().len(), 3);
    assert_eq!(wire["nodes"][2], json!({"op":"or","left":0,"right":1}));
    assert_eq!(wire["output"], 2);
}

#[test]
fn what_and_attribute_projection_refuse_arbitrary_first_answers() {
    let f = Fixture::new();
    let names = f.run(vec![step("Find", &[], &["Bob"]), step("What", &[0], &[])]);
    assert_eq!(names["value"]["status"], "ambiguous");
    let attrs = f.run(vec![
        step("FindAll", &[], &[]),
        step("QueryAttr", &[0], &["score"]),
    ]);
    assert_eq!(attrs["value"]["status"], "ambiguous");
    let unique = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("QueryAttr", &[0], &["mass"]),
    ]);
    assert_eq!(unique["value"]["status"], "unique");
    assert_eq!(
        unique["value"]["candidate"],
        json!({"type":"quantity","value":64,"unit":"kilogram"})
    );
}

#[test]
fn relation_and_attribute_qualifiers_survive_the_complete_program() {
    let f = Fixture::new();
    let related = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("Relate", &[0], &["meets", "forward"]),
        step("QFilterYear", &[1], &["since", "2000", "="]),
        step("What", &[2], &[]),
    ]);
    assert_eq!(related["entities"], json!(["Q2"]));
    assert_eq!(related["value"]["candidate"]["name"], "Bob");
    assert_eq!(related["facts"].as_array().unwrap().len(), 1);
    let attributed = f.run(vec![
        step("FindAll", &[], &[]),
        step("FilterNum", &[0], &["mass", "64 kilogram", "="]),
        step("QFilterYear", &[1], &["since", "2000", "="]),
        step("Count", &[2], &[]),
    ]);
    assert_eq!(attributed["entities"], json!(["Q1"]));
    assert_eq!(attributed["value"], 1);
}

#[test]
fn intersection_preserves_the_evidence_of_its_surviving_branch() {
    let f = Fixture::new();
    let result = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("Relate", &[0], &["meets", "forward"]),
        step("FindAll", &[], &[]),
        step("FilterConcept", &[2], &["Person"]),
        step("And", &[1, 3], &[]),
        step("QFilterYear", &[4], &["since", "2000", "="]),
        step("What", &[5], &[]),
    ]);
    assert_eq!(result["entities"], json!(["Q2"]));
    assert_eq!(result["value"]["candidate"]["name"], "Bob");
    assert_eq!(result["facts"].as_array().unwrap().len(), 1);
}

#[test]
fn qualifier_projections_use_the_requested_statement() {
    let f = Fixture::new();
    let condition = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("QueryAttrUnderCondition", &[0], &["mass", "since", "2000"]),
    ]);
    assert_eq!(
        condition["value"]["candidate"],
        json!({"type":"quantity","value":64,"unit":"kilogram"})
    );
    let qualifier = f.run(vec![
        step("Find", &[], &["Alice"]),
        step(
            "QueryAttrQualifier",
            &[0],
            &["mass", "64 kilogram", "since"],
        ),
    ]);
    assert_eq!(
        qualifier["value"]["candidate"],
        json!({"type":"year","value":2000})
    );
    let missing = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("QueryAttrUnderCondition", &[0], &["mass", "since", "1999"]),
    ]);
    assert_eq!(missing["value"]["status"], "absent");
}

#[test]
fn two_selection_projections_keep_their_target_dependency_live() {
    let f = Fixture::new();
    let relation = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("Find", &[], &["Bob"]),
        step("QueryRelation", &[0, 1], &[]),
    ]);
    assert_eq!(
        relation["value"]["candidate"],
        json!({"type":"string","value":"meets"})
    );
    let qualifier = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("Find", &[], &["Bob"]),
        step("QueryRelationQualifier", &[0, 1], &["meets", "since"]),
    ]);
    assert_eq!(qualifier["value"]["status"], "ambiguous");
}

#[test]
fn verification_composes_with_unique_values_without_losing_exact_units() {
    let f = Fixture::new();
    for (literal, expected) in [("64 kilogram", true), ("65 kilogram", false)] {
        let verified = f.run(vec![
            step("Find", &[], &["Alice"]),
            step("QueryAttr", &[0], &["mass"]),
            step("VerifyNum", &[1], &[literal, "="]),
        ]);
        assert_eq!(verified["value"]["answer"], expected);
    }
    let units = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("QueryAttr", &[0], &["mass"]),
        step("VerifyNum", &[1], &["64 second", "="]),
    ]);
    assert_eq!(units["value"]["status"], "incomparable");
}

#[test]
fn selecting_a_tie_or_ambiguous_operand_declines() {
    let f = Fixture::new();
    let tie = f.run(vec![
        step("FindAll", &[], &[]),
        step("SelectAmong", &[0], &["score", "largest"]),
    ]);
    assert_eq!(tie["value"]["status"], "ambiguous");
    let unique = f.run(vec![
        step("FindAll", &[], &[]),
        step("SelectAmong", &[0], &["score", "smallest"]),
    ]);
    assert_eq!(unique["value"]["candidate"]["id"], "Q1");
    let between = f.run(vec![
        step("Find", &[], &["Alice"]),
        step("Find", &[], &["Bob"]),
        step("SelectBetween", &[0, 1], &["score", "greater"]),
    ]);
    assert_eq!(between["value"]["status"], "ambiguous_operands");
}

#[test]
fn empty_sets_compose_as_sets_and_count_as_zero() {
    let f = Fixture::new();
    let empty = f.run(vec![
        step("Find", &[], &["Missing"]),
        step("Count", &[0], &[]),
    ]);
    assert_eq!(empty["value"], 0);
    let union = f.run(vec![
        step("Find", &[], &["Missing"]),
        step("Find", &[], &["Alice"]),
        step("Or", &[0, 1], &[]),
        step("What", &[2], &[]),
    ]);
    assert_eq!(union["value"]["candidate"]["name"], "Alice");
}
