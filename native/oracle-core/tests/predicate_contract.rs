//! Independent semantic cases for native typed predicates and evidence. These
//! are executable contracts, not specialist-panel scores or Isabelle proofs.
use oracle_runtime_core::{build_image, Cancellation, Error, Image, Limits, Plan, Runtime};
use serde_json::{json, Value};
use std::sync::Arc;
use tempfile::TempDir;

struct Fixture {
    directory: TempDir,
    path: std::path::PathBuf,
    digest: String,
}
impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let path = directory.path().join("image.sqlite");
        // Numeric neighbors exceed the exact-integer range of an IEEE double.
        let kb = json!({"concepts":{"C":{"name":"Thing","instanceOf":[]}},"entities":{
            "A":{"name":"Alpha","instanceOf":["C"],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":9007199254740992_u64,"unit":"kilogram"},"qualifiers":{"since":[{"type":"year","value":2000}],"note":[{"type":"string","value":"original"}]}},
                {"key":"mass","value":{"type":"quantity","value":9007199254740992_u64,"unit":"kilogram"},"qualifiers":{"since":[{"type":"year","value":2001}]}},
                {"key":"label","value":{"type":"string","value":"HeLLo"},"qualifiers":{}},
                {"key":"event","value":{"type":"date","value":"2000/01/01"},"qualifiers":{}},
                {"key":"tie","value":{"type":"quantity","value":3,"unit":"metre"},"qualifiers":{}},
                {"key":"choice","value":{"type":"quantity","value":1,"unit":"1"},"qualifiers":{}},
                {"key":"choice","value":{"type":"quantity","value":2,"unit":"1"},"qualifiers":{}}
            ],"relations":[
                {"predicate":"knows","direction":"forward","object":"B","qualifiers":{"since":[{"type":"year","value":2000}],"note":[{"type":"string","value":"retained"}]}},
                {"predicate":"knows","direction":"forward","object":"B","qualifiers":{"since":[{"type":"year","value":2001}]}},
                {"predicate":"likes","direction":"forward","object":"B","qualifiers":{}}
            ]},
            "B":{"name":"Beta","instanceOf":["C"],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":9007199254740993_u64,"unit":"kilogram"},"qualifiers":{"since":[{"type":"year","value":2000}]}},
                {"key":"event","value":{"type":"year","value":2000},"qualifiers":{}},
                {"key":"tie","value":{"type":"quantity","value":3,"unit":"metre"},"qualifiers":{}}
            ],"relations":[]},
            "D":{"name":"Different unit","instanceOf":[],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":9007199254740993_u64,"unit":"gram"},"qualifiers":{}},
                {"key":"event","value":{"type":"year","value":2001},"qualifiers":{}}
            ],"relations":[]},
            "N":{"name":"No value","instanceOf":[],"attributes":[],"relations":[]}
        }});
        std::fs::write(&source, kb.to_string()).unwrap();
        let receipt = build_image(&source, &path, 1_000_000, 100_000).unwrap();
        Self {
            directory,
            path,
            digest: receipt.image_sha256,
        }
    }
    fn image(&self, limits: Limits) -> Arc<Image> {
        Image::open(&self.path, &self.digest, limits).unwrap()
    }
    fn query(&self, nodes: Value, output: usize, projection: Value) -> Value {
        let plan = json!({"nodes":nodes,"output":output,"projection":projection});
        serde_json::from_str(
            &self
                .image(Limits::default())
                .query("tenant", &plan.to_string(), Cancellation::default())
                .unwrap(),
        )
        .unwrap()
    }
}
fn predicate(kind: &str, literal: &str, comparison: &str) -> Value {
    json!({"kind":kind,"literal":literal,"comparison":comparison})
}
fn attr(input: usize, key: &str, kind: &str, literal: &str, comparison: &str) -> Value {
    json!({"op":"filter_attribute","input":input,"key":key,"predicate":predicate(kind,literal,comparison)})
}
fn qfilter(input: usize, key: &str, kind: &str, literal: &str, comparison: &str) -> Value {
    json!({"op":"filter_qualifier","input":input,"key":key,"predicate":predicate(kind,literal,comparison)})
}

#[test]
fn large_numbers_are_exact_and_units_are_required() {
    let f = Fixture::new();
    let result = f.query(
        json!([{"op":"all"},attr(0,"mass","quantity","9007199254740992 kilogram",">")]),
        1,
        json!({"kind":"entities"}),
    );
    assert_eq!(result["entities"], json!(["B"]));
    assert_eq!(result["facts"], json!([]));
    assert_eq!(result["attributes"][0]["subject"], "B");
    let stored: Value =
        serde_json::from_str(result["attributes"][0]["value_json"].as_str().unwrap()).unwrap();
    assert_eq!(
        stored,
        json!({"type":"quantity","unit":"kilogram","value":9007199254740993_u64})
    );
    let absent = f.query(
        json!([{"op":"all"},attr(0,"mass","quantity","9007199254740993 tonne","=")]),
        1,
        json!({"kind":"count"}),
    );
    assert_eq!(absent["value"], 0);
}

#[test]
fn attribute_qualifiers_preserve_source_identity_and_full_qualifiers() {
    let f = Fixture::new();
    let result = f.query(
        json!([
            {"op":"all"},attr(0,"mass","quantity","9007199254740992 kilogram","="),
            qfilter(1,"since","year","2000","=")
        ]),
        2,
        json!({"kind":"entities"}),
    );
    assert_eq!(result["entities"], json!(["A"]));
    assert_eq!(result["facts"], json!([]));
    let evidence = result["attributes"].as_array().unwrap();
    assert_eq!(evidence.len(), 1);
    assert_eq!(evidence[0]["position"], 0);
    let qualifiers: Value =
        serde_json::from_str(evidence[0]["qualifiers_json"].as_str().unwrap()).unwrap();
    assert_eq!(qualifiers["note"][0]["value"], "original");
    // QFilter cannot invent attribute evidence from a plain Find selection.
    let empty = f.query(
        json!([{"op":"find","name":"Alpha"},qfilter(0,"since","year","2000","=")]),
        1,
        json!({"kind":"count"}),
    );
    assert_eq!(empty["value"], 0);
}

#[test]
fn relation_qualifier_filters_keep_only_matching_original_statements() {
    let f = Fixture::new();
    let result = f.query(json!([
        {"op":"find","name":"Alpha"},{"op":"relate","input":0,"predicate":"knows","direction":"forward"},
        qfilter(1,"since","year","2000","=")
    ]),2,json!({"kind":"entities"}));
    assert_eq!(result["entities"], json!(["B"]));
    assert!(result.get("attributes").is_none());
    assert_eq!(result["facts"].as_array().unwrap().len(), 1);
    let qualifiers: Value =
        serde_json::from_str(result["facts"][0]["qualifiers_json"].as_str().unwrap()).unwrap();
    assert_eq!(qualifiers["note"][0]["value"], "retained");
    assert_eq!(result["facts"][0]["object"], "B");
}

#[test]
fn mixed_evidence_union_is_filtered_by_its_own_selected_entity() {
    let f = Fixture::new();
    let result = f.query(
        json!([
            {"op":"find","name":"Alpha"},
            attr(0,"mass","quantity","9007199254740992 kilogram","="),
            {"op":"relate","input":0,"predicate":"knows","direction":"forward"},
            {"op":"or","left":1,"right":2},qfilter(3,"since","year","2000","=")
        ]),
        4,
        json!({"kind":"entities"}),
    );
    assert_eq!(result["entities"], json!(["A", "B"]));
    assert_eq!(result["facts"].as_array().unwrap().len(), 1);
    assert_eq!(result["attributes"].as_array().unwrap().len(), 1);
    assert_eq!(result["attributes"][0]["subject"], "A");
    assert_eq!(result["facts"][0]["object"], "B");
}

#[test]
fn year_projection_is_explicit_and_day_precision_is_preserved() {
    let f = Fixture::new();
    let year = f.query(
        json!([{"op":"all"},attr(0,"event","year","2000","=")]),
        1,
        json!({"kind":"entities"}),
    );
    assert_eq!(year["entities"], json!(["A", "B"]));
    let day = f.query(
        json!([{"op":"all"},attr(0,"event","date","2000-01-01","=")]),
        1,
        json!({"kind":"entities"}),
    );
    assert_eq!(day["entities"], json!(["A"]));
    let year_precision = f.query(
        json!([{"op":"all"},attr(0,"event","date","2000","=")]),
        1,
        json!({"kind":"entities"}),
    );
    assert_eq!(year_precision["entities"], json!(["B"]));
    let precision = f.query(
        json!([{"op":"find","name":"Alpha"}]),
        0,
        json!({
            "kind":"verify","source":{"kind":"unique_attribute","key":"event"},
            "predicate":predicate("date","2000","=")
        }),
    );
    assert_eq!(precision["value"]["status"], "incomparable");
    assert_eq!(precision["value"]["source"]["candidate"]["type"], "date");
}

#[test]
fn repeated_equal_values_agree_and_conflicting_values_refuse() {
    let f = Fixture::new();
    let unique = f.query(
        json!([{"op":"find","name":"Alpha"}]),
        0,
        json!({"kind":"unique_attribute","key":"mass"}),
    );
    assert_eq!(unique["value"]["status"], "unique");
    assert_eq!(unique["value"]["evidence"].as_array().unwrap().len(), 2);
    assert_eq!(unique["value"]["display"], "9007199254740992 kilogram");
    let ambiguous = f.query(
        json!([{"op":"find","name":"Alpha"}]),
        0,
        json!({"kind":"unique_attribute","key":"choice"}),
    );
    assert_eq!(ambiguous["value"]["status"], "ambiguous");
    assert_eq!(ambiguous["value"]["candidates"], 2);
    let verify = f.query(json!([{"op":"find","name":"Alpha"}]),0,json!({"kind":"verify","source":{"kind":"unique_attribute","key":"choice"},"predicate":predicate("quantity","1","=")}));
    assert_eq!(verify["value"]["status"], "ambiguous");
    assert!(verify["value"].get("answer").is_none());
}

#[test]
fn conditional_attributes_and_attribute_qualifier_queries_infer_literal_kind() {
    let f = Fixture::new();
    let conditional = f.query(json!([{"op":"find","name":"Alpha"}]),0,json!({
        "kind":"unique_attribute","key":"mass","condition":{"key":"since","predicate":{"literal":"2001"}}
    }));
    assert_eq!(conditional["value"]["status"], "unique");
    assert_eq!(
        conditional["value"]["evidence"].as_array().unwrap().len(),
        1
    );
    assert_eq!(conditional["value"]["evidence"][0]["position"], 1);
    let qualifier = f.query(json!([{"op":"find","name":"Alpha"}]),0,json!({
        "kind":"attribute_qualifier","key":"mass","predicate":{"literal":"9007199254740992 kilogram"},"qualifier":"since"
    }));
    assert_eq!(qualifier["value"]["status"], "ambiguous");
    assert_eq!(qualifier["value"]["candidates"], 2);
}

#[test]
fn relation_projections_compile_other_branch_and_preserve_ambiguity() {
    let f = Fixture::new();
    let nodes = json!([{"op":"find","name":"Alpha"},{"op":"find","name":"Beta"}]);
    let relation = f.query(
        nodes.clone(),
        0,
        json!({"kind":"relation","target":1,"direction":"forward"}),
    );
    assert_eq!(relation["value"]["status"], "ambiguous");
    assert_eq!(relation["value"]["candidates"], 2);
    let qualifier = f.query(
        nodes,
        0,
        json!({"kind":"relation_qualifier","target":1,"predicate":"knows","qualifier":"since"}),
    );
    assert_eq!(qualifier["value"]["status"], "ambiguous");
    assert_eq!(qualifier["value"]["candidates"], 2);
    assert_eq!(qualifier["entities"], json!(["A"]));
}

#[test]
fn selection_requires_complete_comparable_values_and_refuses_ties() {
    let f = Fixture::new();
    let nodes = json!([{"op":"find","name":"Alpha"},{"op":"find","name":"Beta"}]);
    let larger = f.query(
        nodes.clone(),
        0,
        json!({"kind":"select_between","target":1,"key":"mass","order":"largest"}),
    );
    assert_eq!(larger["value"]["candidate"]["id"], "B");
    let tie = f.query(
        nodes,
        0,
        json!({"kind":"select_between","target":1,"key":"tie","order":"smallest"}),
    );
    assert_eq!(tie["value"]["status"], "ambiguous");
    // The first two values overlap in precision. A later year can still be
    // proved greater than both; input iteration order must not force refusal.
    let later = f.query(
        json!([
            {"op":"find","name":"Alpha"},{"op":"find","name":"Beta"},{"op":"or","left":0,"right":1},
            {"op":"find","name":"Different unit"},{"op":"or","left":2,"right":3}
        ]),
        4,
        json!({"kind":"select","key":"event","order":"largest"}),
    );
    assert_eq!(later["value"]["candidate"]["id"], "D");
    let units = f.query(json!([{"op":"find","name":"Alpha"},{"op":"find","name":"Different unit"},{"op":"or","left":0,"right":1}]),2,json!({"kind":"select","key":"mass","order":"largest"}));
    assert_eq!(units["value"]["status"], "incomparable");
    let missing = f.query(
        json!([{"op":"all"}]),
        0,
        json!({"kind":"select","key":"mass","order":"largest"}),
    );
    assert!(matches!(
        missing["value"]["status"].as_str(),
        Some("incomparable" | "incomplete")
    ));
}

#[test]
fn strings_are_case_insensitive_but_never_sql_or_lexical_ordering() {
    let f = Fixture::new();
    let matching = f.query(
        json!([{"op":"all"},attr(0,"label","string","hello","=")]),
        1,
        json!({"kind":"count"}),
    );
    assert_eq!(matching["value"], 1);
    let injected = f.query(
        json!([{"op":"all"},attr(0,"label' OR 1=1 --","string","hello","=")]),
        1,
        json!({"kind":"count"}),
    );
    assert_eq!(injected["value"], 0);
    let verification = f.query(json!([{"op":"find","name":"Alpha"}]),0,json!({"kind":"verify","source":{"kind":"unique_attribute","key":"label"},"predicate":predicate("string","zzz","<")}));
    assert_eq!(verification["value"]["status"], "incomparable");
}

#[test]
fn state_replay_retains_attribute_evidence_across_reopen() {
    let f = Fixture::new();
    let state = f.directory.path().join("state.sqlite");
    let plan = json!({"nodes":[{"op":"find","name":"Alpha"},attr(0,"mass","quantity","9007199254740992 kilogram","=")],"output":1,"projection":{"kind":"entities"}}).to_string();
    let first = {
        let runtime = Runtime::open(f.image(Limits::default()), &state).unwrap();
        runtime
            .execute("tenant", "s", "first", 0, &plan, Cancellation::default())
            .unwrap()
    };
    let runtime = Runtime::open(f.image(Limits::default()), &state).unwrap();
    assert_eq!(
        runtime
            .execute("tenant", "s", "first", 0, &plan, Cancellation::default())
            .unwrap(),
        first
    );
    let next = json!({"nodes":[{"op":"previous"},qfilter(0,"since","year","2001","=")],"output":1,"projection":{"kind":"entities"}}).to_string();
    let result: Value = serde_json::from_str(
        &runtime
            .execute("tenant", "s", "second", 1, &next, Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(result["result"]["attributes"].as_array().unwrap().len(), 1);
    assert_eq!(result["result"]["attributes"][0]["position"], 1);
}

#[test]
fn bounded_filter_failure_cleans_scratch_for_next_tenant() {
    let f = Fixture::new();
    let image = f.image(Limits {
        workers: 1,
        materialized_rows: 3,
        ..Limits::default()
    });
    let plan = json!({"nodes":[{"op":"all"},attr(0,"mass","quantity","0 kilogram",">")],"output":1,"projection":{"kind":"entities"}}).to_string();
    assert!(matches!(
        image.query("a", &plan, Cancellation::default()),
        Err(Error::Limit(_))
    ));
    assert_eq!(image.active_workers(), 0);
    // The first matching statement was inserted before the next copy exceeded
    // the limit. A later tenant must not observe that private partial result.
    let empty = json!({"nodes":[{"op":"find","name":"absent"},attr(0,"mass","quantity","0 kilogram",">")],"output":1,"projection":{"kind":"count"}}).to_string();
    let result: Value =
        serde_json::from_str(&image.query("b", &empty, Cancellation::default()).unwrap()).unwrap();
    assert_eq!(result["entities"], json!([]));
    assert_eq!(result["value"], 0);
}

#[test]
fn invalid_dependencies_and_verification_sources_fail_before_execution() {
    for plan in [
        json!({"nodes":[{"op":"all"}],"output":0,"projection":{"kind":"relation","target":1}}),
        json!({"nodes":[{"op":"all"}],"output":0,"projection":{"kind":"verify","source":{"kind":"count"},"predicate":{"literal":"1"}}}),
        json!({"nodes":[{"op":"all"},attr(1,"mass","quantity","1 kilogram","=")],"output":1,"projection":{"kind":"entities"}}),
        json!({"nodes":[{"op":"all"},attr(0,"mass","quantity","1e999999 kilogram","=")],"output":1,"projection":{"kind":"entities"}}),
    ] {
        assert!(Plan::parse(&plan.to_string(), &Limits::default()).is_err());
    }
}
