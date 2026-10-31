//! Independent tiny relational truth cases through the public language consumer.
use oracle_runtime_core::{
    build_image_with_reader,
    grammar::{FormRow, ReaderExport, ReaderPolicy, TemplateRow, READER_FORMAT, READER_VERSION},
    reader::{CountScope, ReaderLimits, ReaderOptions, ReaderReason, ReaderResult, ReaderStatus},
    Budget, Cancellation, Image, Limits, ReaderBuildOptions,
};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::sync::Arc;
use tempfile::TempDir;

fn step(function: &str, dependencies: &[usize], inputs: Value) -> Value {
    json!({"function":function,"dependencies":dependencies,"inputs":inputs})
}
fn fragment(relation: &str) -> Value {
    json!([
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("Relate", &[0], json!([relation, "backward"])),
        step("FilterConcept", &[1], json!([["@", "C", 1, ""]]))
    ])
}
fn outer(terminal: &str) -> Value {
    json!([step("@X", &[], json!([1])), step(terminal, &[0], json!([]))])
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
struct Fixture {
    _directory: TempDir,
    image: Arc<Image>,
}
impl Fixture {
    fn new(templates: Vec<TemplateRow>, forms: Vec<FormRow>) -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let output = directory.path().join("reader.sqlite");
        // York has Alice and Bob as residents; Alice alone was born there.
        // Paris is named but has no resident. These are data claims, not gold
        // strings imported from the reference interpreter.
        let kb = json!({"concepts":{"P":{"name":"person","instanceOf":[]}},"entities":{
            "Y":{"name":"York","instanceOf":[],"attributes":[],"relations":[]},
            "Z":{"name":"Paris","instanceOf":[],"attributes":[],"relations":[]},
            "A":{"name":"Alice","instanceOf":["P"],"attributes":[],"relations":[
                {"predicate":"resident of","object":"Y","direction":"forward","qualifiers":{}},
                {"predicate":"born in","object":"Y","direction":"forward","qualifiers":{}}
            ]},
            "B":{"name":"Bob","instanceOf":["P"],"attributes":[],"relations":[
                {"predicate":"resident of","object":"Y","direction":"forward","qualifiers":{}}
            ]}
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
            forms,
            shapes: vec![],
            aliases: vec![],
            words: vec![],
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
    fn read(&self, question: &str, snapshot: bool) -> ReaderResult {
        let budget = Budget::new(&self.image.limits, Cancellation::default()).unwrap();
        let options = ReaderOptions {
            count_scope: snapshot.then_some(CountScope::SuppliedSnapshot),
        };
        let bytes = self
            .image
            .read_whole_with_options_and_budget(
                "tenant",
                question,
                &ReaderLimits::default(),
                &options,
                &budget,
            )
            .unwrap();
        assert_eq!(self.image.active_workers(), 0);
        serde_json::from_str(&bytes).unwrap()
    }
}

#[test]
fn snapshot_count_admits_composed_zero_with_explicit_premise_only() {
    let fixture = Fixture::new(
        vec![
            row("fragment", "C1 in E1", fragment("resident of")),
            row("outer", "how many X1", outer("Count")),
        ],
        vec![],
    );
    assert_eq!(
        fixture.read("How many persons in Paris?", false).status,
        ReaderStatus::Unknown
    );
    let answer = fixture.read("How many persons in Paris?", true);
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("0"));
    assert_eq!(answer.count_scope, Some(CountScope::SuppliedSnapshot));
}

#[test]
fn snapshot_count_keeps_live_empty_union_but_refuses_dead_empty_stage() {
    let union = json!([
        step("Find", &[], json!(["Missing"])),
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("Or", &[0, 1], json!([])),
        step("Count", &[2], json!([]))
    ]);
    let fixture = Fixture::new(vec![row("whole", "how many E1", union)], vec![]);
    assert_eq!(
        fixture.read("How many Alice?", true).answer.as_deref(),
        Some("1")
    );
    let dead = json!([
        step("Find", &[], json!(["Missing"])),
        step("Find", &[], json!([["@", "E", 1, ""]])),
        step("Count", &[1], json!([]))
    ]);
    let fixture = Fixture::new(vec![row("whole", "how many E1", dead)], vec![]);
    assert_eq!(
        fixture.read("How many Alice?", false).answer.as_deref(),
        Some("1")
    );
    assert_eq!(
        fixture.read("How many Alice?", true).status,
        ReaderStatus::Unknown
    );
}

#[test]
fn snapshot_composed_union_and_noncount_sibling_keep_distinct_obligations() {
    let mut union: Vec<Value> = serde_json::from_value(fragment("resident of")).unwrap();
    union.push(step("Find", &[], json!(["Alice"])));
    union.push(step("Or", &[2, 3], json!([])));
    let fixture = Fixture::new(
        vec![
            row("fragment", "C1 in E1", json!(union)),
            row("outer", "how many X1", outer("Count")),
            row("outer", "who are X1", outer("What")),
        ],
        vec![],
    );
    assert_eq!(
        fixture
            .read("How many persons in Paris?", true)
            .answer
            .as_deref(),
        Some("1")
    );
    assert_eq!(
        fixture.read("Who are persons in Paris?", true).status,
        ReaderStatus::Unknown
    );
}

#[test]
fn snapshot_omitted_child_stays_strict_even_beside_live_same_child() {
    let ignored = json!([
        step("Find", &[], json!(["Alice"])),
        step("Count", &[0], json!([]))
    ]);
    let fixture = Fixture::new(
        vec![
            row("fragment", "C1 in E1", fragment("resident of")),
            row("outer", "how many X1", ignored),
            row("outer", "how many X1", outer("Count")),
        ],
        vec![],
    );
    let answer = fixture.read("How many persons in Paris?", true);
    assert_eq!(answer.answer.as_deref(), Some("0"));
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.readings.len(), 1);
}

#[test]
fn snapshot_missing_attributes_mean_zero_stored_matches_never_source_coverage() {
    let program = json!([
        step("FindAll", &[], json!([])),
        step("FilterYear", &[0], json!(["birth year", "1900", "<"])),
        step("Count", &[1], json!([]))
    ]);
    let fixture = Fixture::new(
        vec![row("whole", "how many recorded births", program)],
        vec![],
    );
    let answer = fixture.read("How many recorded births?", true);
    assert_eq!(answer.answer.as_deref(), Some("0"));
    assert_eq!(answer.count_scope, Some(CountScope::SuppliedSnapshot));
    assert!(!answer.coverage.contains("complete"));
    assert!(
        serde_json::from_value::<ReaderOptions>(json!({"count_scope":"complete_source"})).is_err()
    );
}

#[test]
fn snapshot_nested_omitted_child_keeps_its_own_strict_obligation() {
    let fixture = Fixture::new(
        vec![
            row("fragment", "C1 in E1", fragment("resident of")),
            row(
                "fragment",
                "C1 employing X1",
                json!([
                    step("FindAll", &[], json!([])),
                    step("FilterConcept", &[0], json!([["@", "C", 1, ""]]))
                ]),
            ),
            row("outer", "how many X1", outer("Count")),
        ],
        vec![],
    );
    let answer = fixture.read("How many persons employing persons in Paris?", true);
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.readings.is_empty());
    assert_eq!(
        fixture
            .read("How many persons employing persons in York?", true)
            .answer
            .as_deref(),
        Some("2")
    );
}

#[test]
fn snapshot_unsupported_fragment_alternative_cannot_hide_behind_empty_sibling() {
    let fixture = Fixture::new(
        vec![
            row("fragment", "C1 in E1", fragment("resident of")),
            row(
                "fragment",
                "C1 in E1",
                json!([step(
                    "UnsupportedOperation",
                    &[],
                    json!([["@", "E", 1, ""]])
                )]),
            ),
            row("outer", "how many X1", outer("Count")),
        ],
        vec![],
    );
    let answer = fixture.read("How many persons in Paris?", true);
    assert_eq!(answer.status, ReaderStatus::Refused);
    assert_eq!(answer.reason, Some(ReaderReason::UnsupportedProgram));
    assert!(answer.answer.is_none());
}
