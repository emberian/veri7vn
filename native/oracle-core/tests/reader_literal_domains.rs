//! Independent tiny-store questions through the public learned reader.
use oracle_runtime_core::{
    build_image_with_reader,
    grammar::{AliasRow, ReaderExport, ReaderPolicy, TemplateRow, READER_FORMAT, READER_VERSION},
    reader::{ReaderReason, ReaderResult, ReaderStatus},
    Cancellation, Image, Limits, ReaderBuildOptions,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::sync::Arc;
use tempfile::TempDir;

fn step(function: &str, dependencies: &[usize], inputs: Value) -> Value {
    json!({"function":function,"dependencies":dependencies,"inputs":inputs})
}
fn filtered(function: &str, key: &str, unit: &str) -> Vec<Value> {
    vec![
        step("FindAll", &[], json!([])),
        step("FilterConcept", &[0], json!([["@", "C", 1, ""]])),
        step(function, &[1], json!([key, ["@", "N", 1, unit], ">"])),
    ]
}
fn row(family: &str, template: &str, skeleton: Value) -> TemplateRow {
    TemplateRow {
        family: family.into(),
        level: 0,
        template: template.into(),
        skeleton,
        support: 3,
    }
}
fn whole(function: &str, key: &str, unit: &str, template: &str) -> TemplateRow {
    let mut program = filtered(function, key, unit);
    program.push(step("Count", &[2], json!([])));
    row("whole", template, json!(program))
}
struct Fixture {
    _directory: TempDir,
    image: Arc<Image>,
}
impl Fixture {
    fn new(templates: Vec<TemplateRow>) -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let output = directory.path().join("reader.sqlite");
        // A predates 2000, B has a day within 2000, C postdates 2000,
        // and D is known only to year precision. Mass labels are explicit.
        let kb = json!({"concepts":{"I":{"name":"instrument","instanceOf":[]}},"entities":{
            "A":{"name":"Earlier","instanceOf":["I"],"relations":[],"attributes":[
                {"key":"commissioned","value":{"type":"date","value":"1999-12-31"},"qualifiers":{}},
                {"key":"mass","value":{"type":"quantity","value":3,"unit":"kilogram"},"qualifiers":{}}]},
            "B":{"name":"Same year day","instanceOf":["I"],"relations":[],"attributes":[
                {"key":"commissioned","value":{"type":"date","value":"2000-02-29"},"qualifiers":{}},
                {"key":"mass","value":{"type":"quantity","value":4,"unit":"kilogram"},"qualifiers":{}}]},
            "C":{"name":"Later","instanceOf":["I"],"relations":[],"attributes":[
                {"key":"commissioned","value":{"type":"date","value":"2001-01-01"},"qualifiers":{}},
                {"key":"mass","value":{"type":"quantity","value":3000,"unit":"gram"},"qualifiers":{}}]},
            "D":{"name":"Year only","instanceOf":["I"],"relations":[],"attributes":[
                {"key":"commissioned","value":{"type":"year","value":2000},"qualifiers":{}}]}
        }});
        let bytes = kb.to_string();
        std::fs::write(&source, &bytes).unwrap();
        let reader = ReaderExport {
            format: READER_FORMAT.into(),
            version: READER_VERSION,
            metadata: BTreeMap::from([
                ("normalization".into(), json!("reader7_possessive")),
                (
                    "kb_sha256".into(),
                    json!(format!("{:x}", Sha256::digest(bytes.as_bytes()))),
                ),
            ]),
            policy: ReaderPolicy::default(),
            templates,
            shapes: vec![],
            // Whole matching intentionally uses Reader6 candidate rules and
            // does not infer plurals. Supply this ordinary release alias so
            // both whole and composed questions exercise literal binding.
            aliases: vec![AliasRow {
                phrase: "instruments".into(),
                kind: 'C',
                canonical: "instrument".into(),
            }],
            words: vec![],
            forms: vec![],
        };
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
        let image = Image::open(
            &output,
            &receipt.image_sha256,
            Limits {
                workers: 1,
                ..Limits::default()
            },
        )
        .unwrap();
        Self {
            _directory: directory,
            image,
        }
    }
    fn read(&self, question: &str) -> ReaderResult {
        let result = serde_json::from_str(
            &self
                .image
                .read_whole("literal", question, Cancellation::default())
                .unwrap(),
        )
        .unwrap();
        assert_eq!(self.image.active_workers(), 0);
        result
    }
}

#[test]
fn learned_whole_and_composed_calendar_slots_reach_the_public_reader() {
    for function in ["FilterDate", "FilterYear"] {
        for composed in [false, true] {
            let templates = if composed {
                vec![
                    row(
                        "fragment",
                        "C1 were commissioned after N1",
                        json!(filtered(function, "commissioned", "1")),
                    ),
                    row(
                        "outer",
                        "how many X1",
                        json!([step("@X", &[], json!([1])), step("Count", &[0], json!([]))]),
                    ),
                ]
            } else {
                vec![whole(
                    function,
                    "commissioned",
                    "1",
                    "how many C1 were commissioned after N1",
                )]
            };
            let answer =
                Fixture::new(templates).read("How many instruments were commissioned after 2000?");
            assert_eq!(
                answer.status,
                ReaderStatus::Answered,
                "{function}, composed={composed}: {answer:?}"
            );
            assert_eq!(answer.answer.as_deref(), Some("1"));
            assert!(!answer.readings.is_empty());
            if composed {
                assert!(answer.coverage.contains("exact_fragment_outer_v1"));
            }
            for reading in &answer.readings {
                let comparison = reading
                    .program
                    .iter()
                    .find(|step| step.function == function)
                    .unwrap();
                assert_eq!(comparison.inputs[1], "2000");
            }
        }
    }
}

#[test]
fn learned_quantity_units_keep_disagreeing_scalar_readings() {
    let template = "how many C1 weigh more than N1";
    let answer = Fixture::new(vec![
        whole("FilterNum", "mass", "kilogram", template),
        whole("FilterNum", "mass", "gram", template),
    ])
    .read("How many instruments weigh more than 2?");
    assert_eq!(answer.status, ReaderStatus::Ambiguous);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerDisagreement));
    assert_eq!(answer.distinct_answers, vec!["1", "2"]);
    assert_eq!(answer.readings.len(), 2);
}

#[test]
fn learned_physical_unit_date_competitor_vetoes_quantity_answer() {
    let template = "how many C1 weigh more than N1";
    let answer = Fixture::new(vec![
        whole("FilterNum", "mass", "kilogram", template),
        whole("FilterDate", "mass", "kilogram", template),
    ])
    .read("How many instruments weigh more than 2?");
    assert_eq!(answer.status, ReaderStatus::Refused);
    assert_eq!(answer.reason, Some(ReaderReason::UnsupportedProgram));
    assert!(answer.answer.is_none());
    assert!(answer.unsupported_programs > 0);
    assert_eq!(answer.readings.len(), 1);
    assert_eq!(answer.readings[0].answer, "2");
}
