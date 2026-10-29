use oracle_runtime_core::{
    build_image_with_reader,
    grammar::{
        AliasRow, FormRow, ReaderExport, ReaderPolicy, TemplateRow, READER_FORMAT, READER_VERSION,
    },
    reader::{ReaderLimits, ReaderReason, ReaderResult, ReaderStatus},
    Cancellation, Error, Image, Limits, Program, ReaderBuildOptions,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::sync::Arc;
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
    fn read(&self, question: &str) -> ReaderResult {
        serde_json::from_str(
            &self
                .image
                .read_whole("tenant", question, Cancellation::default())
                .unwrap(),
        )
        .unwrap()
    }
}

#[test]
fn release_tables_are_consumed_through_one_worker_with_alias_spelling() {
    let mut e = tables(vec![entity()]);
    e.aliases.push(AliasRow {
        phrase: "the bard".into(),
        kind: 'E',
        canonical: "alice".into(),
    });
    let fixture = Fixture::new(e);
    let answer = fixture.read("Who is the bard?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("Alice"));
    assert_eq!(answer.coverage, oracle_runtime_core::reader::COVERAGE);
    assert_eq!(answer.readings[0].result.entities, vec!["A"]);
    assert_eq!(fixture.image.active_workers(), 0);
    // Tenant handles share immutable grammar; no first tenant may teach it.
    let next: ReaderResult = serde_json::from_str(
        &fixture
            .image
            .read_whole("other", "Who is Alice?", Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(next.answer, answer.answer);
}

#[test]
fn unknown_and_raw_non_ascii_refusal_are_explicit() {
    let fixture = Fixture::new(tables(vec![entity()]));
    let unknown = fixture.read("Tell me Alice's whole life story");
    assert_eq!(unknown.status, ReaderStatus::Unknown);
    assert_eq!(unknown.reason, Some(ReaderReason::NoTemplate));
    let writing = fixture.read("Who is 東京 Alice?");
    assert_eq!(writing.status, ReaderStatus::Refused);
    assert_eq!(writing.reason, Some(ReaderReason::UnreadableScript));
    assert!(writing.answer.is_none());
}

#[test]
fn all_executed_answers_must_agree_and_counts_never_elect_a_winner() {
    let mut e = tables(vec![entity(), count()]);
    e.templates[0].support = 100;
    let fixture = Fixture::new(e);
    let answer = fixture.read("Who is Alice?");
    assert_eq!(answer.status, ReaderStatus::Ambiguous);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerDisagreement));
    assert_eq!(answer.distinct_answers, vec!["1", "Alice"]);
    assert!(answer.answer.is_none());
    assert_eq!(answer.readings.len(), 2);
}

#[test]
fn wrong_answer_form_vetoes_the_complete_successful_set() {
    let mut e = tables(vec![entity(), count()]);
    e.forms.push(FormRow {
        opening: "who".into(),
        kinds: vec!["entity".into()],
    });
    let fixture = Fixture::new(e);
    let answer = fixture.read("Who is Alice?");
    assert_eq!(answer.status, ReaderStatus::Refused);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerForm));
    assert_eq!(answer.readings.len(), 2); // Wrong-form alternative was not erased.
    assert!(answer.answer.is_none());
}

#[test]
fn unimplemented_learned_operation_cannot_disappear_beside_a_supported_answer() {
    let unknown = json!([step("FutureOperation", &[], json!([]))]);
    let fixture = Fixture::new(tables(vec![entity(), unknown]));
    let result = fixture.read("Who is Alice?");
    assert_eq!(result.status, ReaderStatus::Refused);
    assert_eq!(result.reason, Some(ReaderReason::UnsupportedProgram));
    assert_eq!(result.unsupported_programs, 1);
    assert_eq!(result.readings.len(), 1);
}

#[test]
fn unsuccessful_reading_does_not_veto_success_but_ambiguous_values_do() {
    let absent = json!([
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("Relate", &[0], json!(["missing relation", "forward"])),
        step("What", &[1], json!([]))
    ]);
    let fixture = Fixture::new(tables(vec![entity(), absent]));
    let answer = fixture.read("Who is Alice?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("Alice"));
    let ambiguous = fixture.read("Who is Bob?");
    assert_eq!(ambiguous.status, ReaderStatus::Ambiguous);
    assert_eq!(ambiguous.reason, Some(ReaderReason::AmbiguousExecution));
}

#[test]
fn source_empty_intermediate_rule_applies_only_to_language_and_except_count() {
    let make = |terminal| {
        json!([
            step("Find", &[], json!([["@", "E", 1, ""]])),
            step("Find", &[], json!(["Missing"])),
            step("Or", &[0, 1], json!([])),
            step(terminal, &[2], json!([]))
        ])
    };
    let fixture = Fixture::new(tables(vec![make("What")]));
    let answer = fixture.read("Who is Alice?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert_eq!(answer.reason, Some(ReaderReason::NoViableReading));
    // Ordinary native Program/Plan execution preserves ordinary union semantics.
    let program: Program = serde_json::from_value(json!([
        step("Find", &[], json!(["Alice"])),
        step("Find", &[], json!(["Missing"])),
        step("Or", &[0, 1], json!([])),
        step("What", &[2], json!([]))
    ]))
    .unwrap();
    let plan = program.compile(&fixture.image.limits).unwrap();
    let direct: Value = serde_json::from_str(
        &fixture
            .image
            .query(
                "tenant",
                &serde_json::to_string(&plan).unwrap(),
                Cancellation::default(),
            )
            .unwrap(),
    )
    .unwrap();
    assert_eq!(direct["value"]["candidate"]["name"], "Alice");
    let counted = Fixture::new(tables(vec![make("Count")])).read("Who is Alice?");
    assert_eq!(counted.status, ReaderStatus::Answered);
    assert_eq!(counted.answer.as_deref(), Some("1"));
}

#[test]
fn limits_and_cancellation_remain_errors_and_release_the_worker() {
    let mut e = tables(vec![entity()]);
    // Two genuinely learned complete bindings, rather than counting impossible
    // powerset leaves which no longer consume the combination bound.
    e.templates.push(TemplateRow {
        family: "whole".into(),
        level: 0,
        template: "who is alice".into(),
        skeleton: json!([
            step("Find", &[], json!(["Alice"])),
            step("What", &[0], json!([]))
        ]),
        support: 3,
    });
    let fixture = Fixture::new(e);
    let bounds = ReaderLimits {
        combinations_per_level: 1,
        ..ReaderLimits::default()
    };
    assert!(matches!(
        fixture.image.read_whole_with_limits(
            "tenant",
            "Who is Alice?",
            &bounds,
            Cancellation::default()
        ),
        Err(Error::Limit(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
    let cancel = Cancellation::default();
    cancel.cancel();
    assert!(matches!(
        fixture.image.read_whole("tenant", "Who is Alice?", cancel),
        Err(Error::Cancelled)
    ));
    assert_eq!(fixture.read("Who is Alice?").status, ReaderStatus::Answered);
}

#[test]
fn typed_value_projection_uses_common_program_execution() {
    let skeleton = json!([
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("QueryAttr", &[0], json!(["score"]))
    ]);
    let mut e = tables(vec![skeleton]);
    e.templates[0].template = "what score has E1".into();
    let fixture = Fixture::new(e);
    let answer = fixture.read("What score has Alice?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("10 point"));
    assert_eq!(
        answer.readings[0].result.value["candidate"]["unit"],
        "point"
    );
}

#[test]
fn possessive_names_are_normalized_once_and_both_levels_contribute() {
    let mut e = tables(vec![entity()]);
    let mut second = e.templates[0].clone();
    second.level = 1;
    e.templates.push(second);
    let fixture = Fixture::new(e);
    let answer = fixture.read("Who is King's?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("King's"));
    assert_eq!(answer.readings.len(), 2);
    assert_eq!(
        answer.readings.iter().map(|r| r.level).collect::<Vec<_>>(),
        vec![0, 1]
    );
}
