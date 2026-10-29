//! Independent tiny relational truth cases through the public language consumer.
use oracle_runtime_core::{
    build_image_with_reader,
    grammar::{FormRow, ReaderExport, ReaderPolicy, TemplateRow, READER_FORMAT, READER_VERSION},
    reader::{ReaderLimits, ReaderReason, ReaderResult, ReaderStatus},
    Cancellation, Error, Image, Limits, ReaderBuildOptions,
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
    fn read(&self, question: &str) -> ReaderResult {
        let result = serde_json::from_str(
            &self
                .image
                .read_whole("tenant", question, Cancellation::default())
                .unwrap(),
        )
        .unwrap();
        assert_eq!(self.image.active_workers(), 0);
        result
    }
}
fn resident_rows() -> Vec<TemplateRow> {
    vec![
        row("fragment", "C1 in E1", fragment("resident of")),
        row("outer", "how many X1", outer("Count")),
    ]
}
#[test]
fn relation_filter_fragment_splices_into_count_without_whole_template() {
    let fixture = Fixture::new(resident_rows(), vec![]);
    let answer = fixture.read("How many persons in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("2"));
    assert!(answer.coverage.contains("exact_fragment_outer_v1"));
    let evidence: Value = serde_json::from_str(&answer.readings[0].template).unwrap();
    assert_eq!(evidence["outer"], "how many X1");
    assert_eq!(evidence["fragments"][0]["template"], "C1 in E1");
    assert_eq!(
        answer.readings[0].program.last().unwrap().dependencies,
        vec![2]
    );
}
#[test]
fn all_fragment_alternatives_survive_until_answer_agreement() {
    let mut rows = resident_rows();
    rows.push(row("fragment", "C1 in E1", fragment("born in")));
    let answer = Fixture::new(rows, vec![]).read("How many persons in York?");
    assert_eq!(answer.status, ReaderStatus::Ambiguous);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerDisagreement));
    assert_eq!(answer.distinct_answers, vec!["1", "2"]);
    assert_eq!(answer.readings.len(), 2);
}
#[test]
fn empty_fragment_cannot_become_a_zero_count_answer() {
    let answer = Fixture::new(resident_rows(), vec![]).read("How many persons in Paris?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
    assert!(answer.readings.is_empty());
}
#[test]
fn composition_cannot_outvote_an_existing_whole_reading() {
    let mut rows = resident_rows();
    rows.push(row(
        "whole",
        "how many C1 in E1",
        json!([
            step("Find", &[], json!([["@", "E", 1, ""]])),
            step("Count", &[0], json!([]))
        ]),
    ));
    let answer = Fixture::new(rows, vec![]).read("How many person in York?");
    assert_eq!(answer.status, ReaderStatus::Ambiguous);
    assert_eq!(answer.distinct_answers, vec!["1", "2"]);
}
#[test]
fn missing_outer_wording_does_not_guess_a_question_operator() {
    let answer = Fixture::new(resident_rows(), vec![]).read("Why persons in York?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
}
#[test]
fn executed_composition_obeys_form_veto() {
    let answer = Fixture::new(
        resident_rows(),
        vec![FormRow {
            opening: "how many".into(),
            kinds: vec!["entity".into()],
        }],
    )
    .read("How many persons in York?");
    assert_eq!(answer.status, ReaderStatus::Refused);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerForm));
    assert_eq!(answer.distinct_answers, vec!["2"]);
    assert!(answer.answer.is_none());
    assert_eq!(answer.readings.len(), 1);
}
#[test]
fn two_fragments_rebase_dependencies_before_intersection() {
    let mut rows = resident_rows();
    rows.push(row("fragment", "C1 born in E1", fragment("born in")));
    rows.push(row(
        "outer",
        "how many X1 and X2",
        json!([
            step("@X", &[], json!([1])),
            step("@X", &[], json!([2])),
            step("And", &[0, 1], json!([])),
            step("Count", &[2], json!([]))
        ]),
    ));
    let answer =
        Fixture::new(rows, vec![]).read("How many persons in York and persons born in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
    let program = &answer.readings[0].program;
    assert_eq!(program[6].dependencies, vec![2, 5]);
    assert_eq!(program[7].dependencies, vec![6]);
}

#[test]
fn exhausted_composition_search_is_an_error_not_a_single_reading() {
    let fixture = Fixture::new(resident_rows(), vec![]);
    let limits = ReaderLimits {
        combinations_per_level: 1,
        ..ReaderLimits::default()
    };
    assert!(matches!(
        fixture.image.read_whole_with_limits(
            "tenant",
            "How many persons in York?",
            &limits,
            Cancellation::default()
        ),
        Err(Error::Limit(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
}

#[test]
fn unused_unsupported_fragment_does_not_poison_a_whole_answer() {
    let rows = vec![
        row(
            "fragment",
            "C1 in E1",
            json!([step(
                "UnsupportedOperation",
                &[],
                json!([["@", "E", 1, ""]])
            )]),
        ),
        row(
            "whole",
            "how many C1 in E1",
            json!([
                step("Find", &[], json!([["@", "E", 1, ""]])),
                step("Count", &[0], json!([]))
            ]),
        ),
    ];
    let answer = Fixture::new(rows, vec![]).read("How many person in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
}

#[test]
fn consumed_unsupported_fragment_remains_an_explicit_error() {
    let fixture = Fixture::new(
        vec![
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
    assert!(matches!(
        fixture.image.read_whole(
            "tenant",
            "How many person in York?",
            Cancellation::default()
        ),
        Err(Error::Invalid(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
}

#[test]
fn only_complete_outer_consumers_demand_fragment_work_and_share_it() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    let source = json!([step("Find", &[], json!([["@", "E", 1, ""]]))]);
    db.execute(
        "INSERT INTO reader_template VALUES ('fragment',0,'E1',?1,3)",
        [source.to_string()],
    )
    .unwrap();
    let spans = vec![
        GrammarSpan {
            start: 0,
            end: 5,
            kind: 'E',
            canonical: "Alice".into(),
        },
        GrammarSpan {
            start: 10,
            end: 15,
            kind: 'E',
            canonical: "Alice".into(),
        },
    ];
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut calls = 0;
    let unused = match_composed(
        &db,
        "alice and alice",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |_| {
            calls += 1;
            Err(Error::Invalid(
                "unconsumed expensive/unsupported provider".into(),
            ))
        },
    )
    .unwrap();
    assert!(unused.is_empty());
    assert_eq!(calls, 0);
    db.execute(
        "INSERT INTO reader_template VALUES ('outer',0,'X1 and X2',?1,3)",
        [json!([
            step("@X", &[], json!([1])),
            step("@X", &[], json!([2])),
            step("And", &[0, 1], json!([])),
            step("Count", &[2], json!([]))
        ])
        .to_string()],
    )
    .unwrap();
    let consumed = match_composed(
        &db,
        "alice and alice",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |_| {
            calls += 1;
            Ok(true)
        },
    )
    .unwrap();
    assert_eq!(consumed.len(), 1);
    assert_eq!(calls, 1); // Same typed program, distinct regions/X ordinals.
}

#[test]
fn irrelevant_local_bindings_never_spend_the_complete_composition_bound() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    let source = json!([step("Find", &[], json!([["@", "E", 1, ""]]))]);
    db.execute(
        "INSERT INTO reader_template VALUES ('fragment',0,'E1',?1,3)",
        [source.to_string()],
    )
    .unwrap();
    let mut spans: Vec<_> = (0..450)
        .map(|i| GrammarSpan {
            start: 5,
            end: 10,
            kind: 'E',
            canonical: format!("irrelevant{i}"),
        })
        .collect();
    spans.push(GrammarSpan {
        start: 11,
        end: 14,
        kind: 'E',
        canonical: "Bob".into(),
    });
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let bounds = MatchLimits {
        combinations: 2,
        ..MatchLimits::default()
    };
    let mut calls = Vec::new();
    let absent = match_composed(
        &db,
        "what alice bob",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        bounds,
        &budget,
        |p| {
            calls.push(p.clone());
            Ok(true)
        },
    )
    .unwrap();
    assert!(absent.is_empty());
    assert!(calls.is_empty());
    db.execute(
        "INSERT INTO reader_template VALUES ('outer',0,'what alice X1',?1,3)",
        [outer("What").to_string()],
    )
    .unwrap();
    let answer = match_composed(
        &db,
        "what alice bob",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        bounds,
        &budget,
        |p| {
            calls.push(p.clone());
            Ok(true)
        },
    )
    .unwrap();
    assert_eq!(answer.len(), 1);
    assert_eq!(calls.len(), 1);
    assert_eq!(
        calls[0][0].inputs,
        json!(["Bob"]).as_array().unwrap().clone()
    );
    assert_eq!(answer[0].program.last().unwrap().function, "What");
}

/// Measurement only, run by hand against the pinned reader image:
/// `O1_IMAGE=<image> O1_COHORT=<cohort json> O1_PROBE_OUT=<json>
/// cargo test --release -p oracle-runtime-core --test composition_contract
/// -- --ignored composition_byte_peaks_on_frozen_cases`.
/// It records the composition ledger's peak and owners for each named case;
/// it asserts only that the probe saw every case.
#[test]
#[ignore]
fn composition_byte_peaks_on_frozen_cases() {
    use oracle_runtime_core::composition::probe;
    let image_path = std::env::var("O1_IMAGE").expect("O1_IMAGE");
    let cohort: Value = serde_json::from_str(
        &std::fs::read_to_string(std::env::var("O1_COHORT").unwrap()).unwrap(),
    )
    .unwrap();
    let out = std::env::var("O1_PROBE_OUT").expect("O1_PROBE_OUT");
    let ids = std::env::var("O1_CASES").unwrap_or_else(|_| {
        "nested_headquarters_city_website_population_bristol,nested_university_count_cardiff,\
         ambiguous_university_selection_cardiff,empty_parent_headquarters_saskatoon"
            .into()
    });
    let mut limits: Limits = serde_json::from_value(cohort["limits"].clone()).unwrap();
    limits.workers = limits.workers.max(1);
    let image = Image::open(
        std::path::Path::new(&image_path),
        cohort["image"]["sha256"].as_str().unwrap(),
        limits,
    )
    .unwrap();
    probe::enable();
    probe::take();
    let mut rows = Vec::new();
    for id in ids.split(',') {
        let case = cohort["cases"]
            .as_array()
            .unwrap()
            .iter()
            .find(|case| case["id"] == id)
            .expect("case id");
        let question = case["question"].as_str().unwrap();
        let result = image.read_whole("probe", question, Cancellation::default());
        let status = match &result {
            Ok(text) => serde_json::from_str::<Value>(text).unwrap()["status"].clone(),
            Err(error) => json!(format!("error {error:?}")),
        };
        let calls: Vec<_> = probe::take()
            .into_iter()
            .map(|r| {
                json!({"peak_bytes": r.peak, "final_bytes": r.final_bytes, "outcome": r.outcome,
                    "peak_owners": r.peak_owners.into_iter().collect::<BTreeMap<_, _>>()})
            })
            .collect();
        assert!(!calls.is_empty(), "probe saw no composition call for {id}");
        rows.push(json!({"id": id, "status": status, "calls": calls}));
    }
    std::fs::write(out, serde_json::to_string_pretty(&rows).unwrap()).unwrap();
}
