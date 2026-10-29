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
        let kb = json!({"concepts":{"P":{"name":"person","instanceOf":[]},"O":{"name":"organisation","instanceOf":[]}},"entities":{
            "L":{"name":"Library","instanceOf":["O"],"attributes":[],"relations":[]},
            "Y":{"name":"York","instanceOf":[],"attributes":[],"relations":[]},
            "Z":{"name":"Paris","instanceOf":[],"attributes":[],"relations":[]},
            "A":{"name":"Alice","instanceOf":["P"],"attributes":[],"relations":[
                {"predicate":"employer","object":"L","direction":"forward","qualifiers":{}},
                {"predicate":"resident of","object":"Y","direction":"forward","qualifiers":{"start":[{"type":"year","value":2001}]}},
                {"predicate":"born in","object":"Y","direction":"forward","qualifiers":{}}
            ]},
            "B":{"name":"Bob","instanceOf":["P"],"attributes":[],"relations":[
                {"predicate":"employer","object":"L","direction":"forward","qualifiers":{}},
                {"predicate":"resident of","object":"Y","direction":"forward","qualifiers":{"start":[{"type":"year","value":1999}]}}
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
fn unit(role: &str, steps: Value) -> Value {
    json!({"role":role,"steps":steps})
}
fn concept_unit() -> TemplateRow {
    row(
        "segment",
        "C1",
        unit(
            "filter",
            json!([step("FilterConcept", &[], json!([["@", "C", 1, ""]]))]),
        ),
    )
}
fn source_unit(relation: &str) -> TemplateRow {
    row(
        "segment",
        "in E1",
        unit(
            "source",
            json!([
                step("Find", &[], json!([["@", "E", 1, ""]])),
                step("Relate", &[], json!([relation, "backward"]))
            ]),
        ),
    )
}
fn segment_rows() -> Vec<TemplateRow> {
    vec![
        concept_unit(),
        source_unit("resident of"),
        row("outer", "how many X1", outer("Count")),
    ]
}
fn nested_rows() -> Vec<TemplateRow> {
    let mut rows = segment_rows();
    rows.push(row(
        "fragment",
        "C1 employing X1",
        json!([
            step("@X", &[], json!([1])),
            step("Relate", &[0], json!(["employer", "forward"])),
            step("FilterConcept", &[1], json!([["@", "C", 1, ""]]))
        ]),
    ));
    rows
}
#[test]
fn exact_learned_units_reorder_source_before_surface_first_filter() {
    let answer = Fixture::new(segment_rows(), vec![]).read("How many persons in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("2"));
    let program = &answer.readings[0].program;
    assert_eq!(
        program
            .iter()
            .map(|s| s.function.as_str())
            .collect::<Vec<_>>(),
        vec!["Find", "Relate", "FilterConcept", "Count"]
    );
    assert_eq!(program[2].dependencies, vec![1]);
    assert!(answer
        .coverage
        .contains("exact_segment_and_single_nested_v1"));
}
#[test]
fn exact_segment_unit_alternatives_do_not_vote() {
    let mut rows = segment_rows();
    rows.push(source_unit("born in"));
    let answer = Fixture::new(rows, vec![]).read("How many persons in York?");
    assert_eq!(answer.status, ReaderStatus::Ambiguous);
    assert_eq!(answer.distinct_answers, vec!["1", "2"]);
}
#[test]
fn nested_template_consumes_segment_chain_and_rebases_dependencies() {
    let answer = Fixture::new(nested_rows(), vec![])
        .read("How many organisations employing persons in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
    let program = &answer.readings[0].program;
    assert_eq!(program[3].function, "Relate");
    assert_eq!(program[4].function, "FilterConcept");
    assert_eq!(program[3].dependencies, vec![2]);
    assert_eq!(program[4].dependencies, vec![3]);
    assert_eq!(program[5].dependencies, vec![4]);
}
#[test]
fn exact_fragment_can_be_the_single_pre_nested_child() {
    let mut rows = nested_rows();
    rows.retain(|r| r.family != "segment");
    rows.push(row("fragment", "C1 in E1", fragment("resident of")));
    let answer =
        Fixture::new(rows, vec![]).read("How many organisations employing persons in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
}
#[test]
fn whole_exact_segment_and_nested_all_participate_in_agreement() {
    let mut rows = nested_rows();
    rows.push(row(
        "fragment",
        "C1 employing C2 in E1",
        json!([
            step("Find", &[], json!([["@", "E", 1, ""]])),
            step("Relate", &[0], json!(["resident of", "backward"])),
            step("FilterConcept", &[1], json!([["@", "C", 2, ""]]))
        ]),
    ));
    rows.push(row(
        "whole",
        "how many C1 employing C2 in E1",
        json!([
            step("Find", &[], json!([["@", "E", 1, ""]])),
            step("Count", &[0], json!([]))
        ]),
    ));
    let answer = Fixture::new(rows, vec![]).read("How many organisation employing person in York?");
    assert_eq!(answer.status, ReaderStatus::Ambiguous);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerDisagreement));
    assert_eq!(answer.distinct_answers, vec!["1", "2"]);
    assert!(answer
        .readings
        .iter()
        .any(|r| r.template.starts_with("how many")));
    assert!(answer
        .readings
        .iter()
        .any(|r| r.template.contains("nested")));
}
#[test]
fn only_one_pre_nested_pass_is_admitted() {
    let answer = Fixture::new(nested_rows(), vec![])
        .read("How many organisations employing organisations employing persons in York?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
}
#[test]
fn empty_segment_chain_is_not_a_zero_count_reading() {
    let fixture = Fixture::new(segment_rows(), vec![]);
    let answer = fixture.read("How many persons in Paris?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
    assert!(answer.readings.is_empty());
    assert_eq!(
        fixture.read("How many persons in York?").answer.as_deref(),
        Some("2")
    );
}
#[test]
fn empty_nested_child_cannot_be_resurrected_by_later_nonempty_branch() {
    // Adversarial export row, not a chain learned by Reader7.
    let mut rows = segment_rows();
    rows.push(row(
        "fragment",
        "X1 named E1",
        json!([
            step("@X", &[], json!([1])),
            step("Find", &[], json!([["@", "E", 1, ""]]))
        ]),
    ));
    let answer = Fixture::new(rows, vec![]).read("How many persons in Paris named Alice?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
}
#[test]
fn two_source_units_do_not_form_a_chain() {
    let answer = Fixture::new(segment_rows(), vec![]).read("How many persons in York in Paris?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
}
#[test]
fn source_free_filter_chain_uses_find_all() {
    let rows = vec![
        concept_unit(),
        row(
            "segment",
            "and C1",
            unit(
                "filter",
                json!([step("FilterConcept", &[], json!([["@", "C", 1, ""]]))]),
            ),
        ),
        row("outer", "how many X1", outer("Count")),
    ];
    let answer = Fixture::new(rows, vec![]).read("How many persons and persons?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("2"));
    assert_eq!(answer.readings[0].program[0].function, "FindAll");
}
#[test]
fn unused_unsupported_segment_and_nested_regions_do_not_poison_whole() {
    let rows = vec![
        row(
            "segment",
            "C1",
            unit(
                "filter",
                json!([step(
                    "UnsupportedOperation",
                    &[],
                    json!([["@", "C", 1, ""]])
                )]),
            ),
        ),
        source_unit("resident of"),
        row(
            "fragment",
            "X1 named E1",
            json!([
                step("@X", &[], json!([1])),
                step("UnsupportedOperation", &[0], json!([["@", "E", 1, ""]]))
            ]),
        ),
        row(
            "whole",
            "how many C1 in E1 named E2",
            json!([
                step("Find", &[], json!([["@", "E", 2, ""]])),
                step("Count", &[0], json!([]))
            ]),
        ),
    ];
    let answer = Fixture::new(rows, vec![]).read("How many person in York named Alice?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
}
#[test]
fn consumed_unsupported_segment_cannot_disappear_behind_empty_sibling() {
    let mut rows = segment_rows();
    rows.push(row(
        "segment",
        "in E1",
        unit(
            "source",
            json!([step(
                "UnsupportedOperation",
                &[],
                json!([["@", "E", 1, ""]])
            )]),
        ),
    ));
    let fixture = Fixture::new(rows, vec![]);
    assert!(matches!(
        fixture.image.read_whole(
            "tenant",
            "How many persons in Paris?",
            Cancellation::default()
        ),
        Err(Error::Invalid(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
}
#[test]
fn consumed_unsupported_nested_candidate_cannot_disappear() {
    let mut rows = nested_rows();
    rows.push(row(
        "fragment",
        "C1 employing X1",
        json!([
            step("@X", &[], json!([1])),
            step("UnsupportedOperation", &[0], json!([["@", "C", 1, ""]]))
        ]),
    ));
    let fixture = Fixture::new(rows, vec![]);
    assert!(matches!(
        fixture.image.read_whole(
            "tenant",
            "How many organisations employing persons in York?",
            Cancellation::default()
        ),
        Err(Error::Invalid(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
}
#[test]
fn segment_and_nested_search_exhaustion_and_cancellation_release_worker() {
    let fixture = Fixture::new(nested_rows(), vec![]);
    for limits in [
        ReaderLimits {
            combinations_per_level: 1,
            ..ReaderLimits::default()
        },
        ReaderLimits {
            materialized_bytes: 256,
            ..ReaderLimits::default()
        },
    ] {
        assert!(matches!(
            fixture.image.read_whole_with_limits(
                "tenant",
                "How many organisations employing persons in York?",
                &limits,
                Cancellation::default()
            ),
            Err(Error::Limit(_))
        ));
        assert_eq!(fixture.image.active_workers(), 0);
    }
    let cancellation = Cancellation::default();
    cancellation.cancel();
    assert!(matches!(
        fixture.image.read_whole(
            "tenant",
            "How many organisations employing persons in York?",
            cancellation
        ),
        Err(Error::Cancelled)
    ));
    assert_eq!(fixture.image.active_workers(), 0);
    assert_eq!(
        fixture
            .read("How many organisations employing persons in York?")
            .answer
            .as_deref(),
        Some("1")
    );
}
#[test]
fn consumed_nested_output_obeys_answer_form_veto() {
    let answer = Fixture::new(
        nested_rows(),
        vec![FormRow {
            opening: "how many".into(),
            kinds: vec!["entity".into()],
        }],
    )
    .read("How many organisations employing persons in York?");
    assert_eq!(answer.status, ReaderStatus::Refused);
    assert_eq!(answer.reason, Some(ReaderReason::AnswerForm));
    assert!(answer.answer.is_none());
}
#[test]
fn source_qualifier_stays_attached_before_surface_first_concept_filter() {
    let rows = vec![
        concept_unit(),
        row(
            "segment",
            "in E1 since N1",
            unit(
                "source",
                json!([
                    step("Find", &[], json!([["@", "E", 1, ""]])),
                    step("Relate", &[], json!(["resident of", "backward"])),
                    step("QFilterYear", &[], json!(["start", ["@", "N", 1, ""], "="]))
                ]),
            ),
        ),
        row("outer", "how many X1", outer("Count")),
    ];
    let answer = Fixture::new(rows, vec![]).read("How many persons in York since 2001?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
    let program = &answer.readings[0].program;
    assert_eq!(program[2].function, "QFilterYear");
    assert_eq!(program[3].function, "FilterConcept");
    assert_eq!(program[3].dependencies, vec![2]);
}

#[test]
fn four_source_bounded_units_and_concept_first_order_match_pinned_assembly() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    let rows = vec![
        row("outer", "how many X1", outer("Count")),
        row(
            "segment",
            "E1",
            unit(
                "source",
                json!([step("Find", &[], json!([["@", "E", 1, ""]]))]),
            ),
        ),
        row(
            "segment",
            "with V1",
            unit(
                "filter",
                json!([
                    step("FilterStr", &[], json!(["nickname", ["@", "V", 1, ""]])),
                    step("QFilterStr", &[], json!(["scope", "official"]))
                ]),
            ),
        ),
        row(
            "segment",
            "and C1",
            unit(
                "filter",
                json!([step("FilterConcept", &[], json!([["@", "C", 1, ""]]))]),
            ),
        ),
    ];
    for r in rows {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let limits = Limits::default();
    let question = "how many alice with ally and person and person";
    let spans = vec![
        GrammarSpan {
            start: 9,
            end: 14,
            kind: 'E',
            canonical: "Alice".into(),
        },
        GrammarSpan {
            start: 20,
            end: 24,
            kind: 'V',
            canonical: "Ally".into(),
        },
        GrammarSpan {
            start: 29,
            end: 35,
            kind: 'C',
            canonical: "person".into(),
        },
        GrammarSpan {
            start: 40,
            end: 46,
            kind: 'C',
            canonical: "person".into(),
        },
    ];
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut calls = Vec::new();
    let programs = match_composed(
        &db,
        question,
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |p| {
            calls.push(p.clone());
            Ok(true)
        },
    )
    .unwrap();
    assert_eq!(programs.len(), 1);
    assert_eq!(calls.len(), 1);
    assert_eq!(
        calls[0]
            .iter()
            .map(|s| s.function.as_str())
            .collect::<Vec<_>>(),
        vec![
            "Find",
            "FilterConcept",
            "FilterConcept",
            "FilterStr",
            "QFilterStr"
        ]
    );
    let question5 = "how many alice with ally and person and person and person";
    let mut spans5 = spans.clone();
    spans5.push(GrammarSpan {
        start: 51,
        end: 57,
        kind: 'C',
        canonical: "person".into(),
    });
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let programs = match_composed(
        &db,
        question5,
        &spans5,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |_| Ok(true),
    )
    .unwrap();
    assert!(programs.is_empty());
}
#[test]
fn source_four_by_twelve_word_bound_is_distinct_from_direct_fragment_bound() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    let source_template = format!("E1 {} N1", ["alpha"; 10].join(" "));
    let filter_template = format!("{} C1", ["beta"; 11].join(" "));
    for r in [
        row("outer", "how many X1", outer("Count")),
        row(
            "segment",
            &source_template,
            unit(
                "source",
                json!([
                    step("Find", &[], json!([["@", "E", 1, ""]])),
                    step("Relate", &[], json!(["resident of", "backward"])),
                    step("QFilterYear", &[], json!(["start", ["@", "N", 1, ""], "="]))
                ]),
            ),
        ),
        row(
            "segment",
            &filter_template,
            unit(
                "filter",
                json!([step("FilterConcept", &[], json!([["@", "C", 1, ""]]))]),
            ),
        ),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let source_text = format!("alice {} 2001", ["alpha"; 10].join(" "));
    let filter_text = format!("{} person", ["beta"; 11].join(" "));
    let question = format!("how many {source_text} {filter_text} {filter_text} {filter_text}");
    assert_eq!(question.split_whitespace().count() - 2, 48);
    let mut spans = Vec::new();
    let mut offset = 0;
    for word in question.split_whitespace() {
        let kind = match word {
            "alice" => Some(('E', "Alice")),
            "2001" => Some(('N', "2001")),
            "person" => Some(('C', "person")),
            _ => None,
        };
        if let Some((kind, canonical)) = kind {
            spans.push(GrammarSpan {
                start: offset,
                end: offset + word.len(),
                kind,
                canonical: canonical.into(),
            });
        }
        offset += word.len() + 1;
    }
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let programs = match_composed(
        &db,
        &question,
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |_| Ok(true),
    )
    .unwrap();
    assert_eq!(programs.len(), 1);
    assert_eq!(programs[0].program.len(), 7);
}

fn nested_without_x_splice_rows(child: Value) -> Vec<TemplateRow> {
    // Explicit export rows may contain a template X without a matching @X
    // instruction. Reader7 still requires its selected base fragment to run.
    vec![
        row("fragment", "C1 in E1", child),
        row(
            "fragment",
            "C1 employing X1",
            json!([
                step("FindAll", &[], json!([])),
                step("FilterConcept", &[0], json!([["@", "C", 1, ""]]))
            ]),
        ),
        row("outer", "how many X1", outer("Count")),
    ]
}
#[test]
fn omitted_nested_x_cannot_hide_empty_selected_child() {
    let fixture = Fixture::new(
        nested_without_x_splice_rows(fragment("resident of")),
        vec![],
    );
    let answer = fixture.read("How many organisations employing persons in Paris?");
    assert_eq!(answer.status, ReaderStatus::Unknown);
    assert!(answer.answer.is_none());
    assert!(answer.readings.is_empty());
    assert_eq!(fixture.image.active_workers(), 0);
}
#[test]
fn omitted_nested_x_cannot_hide_unsupported_selected_child() {
    let fixture = Fixture::new(
        nested_without_x_splice_rows(json!([step(
            "UnsupportedOperation",
            &[],
            json!([["@", "E", 1, ""]])
        )])),
        vec![],
    );
    assert!(matches!(
        fixture.image.read_whole(
            "tenant",
            "How many organisations employing persons in York?",
            Cancellation::default()
        ),
        Err(Error::Invalid(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
}
#[test]
fn omitted_nested_x_keeps_valid_child_admission_and_actual_parent_semantics() {
    let fixture = Fixture::new(
        nested_without_x_splice_rows(fragment("resident of")),
        vec![],
    );
    let answer = fixture.read("How many organisations employing persons in York?");
    assert_eq!(answer.status, ReaderStatus::Answered);
    assert_eq!(answer.answer.as_deref(), Some("1"));
    // No synthetic child splice is added: the actual exported parent selects
    // the one organisation. Child admission is a separate source obligation.
    assert_eq!(
        answer.readings[0]
            .program
            .iter()
            .map(|s| s.function.as_str())
            .collect::<Vec<_>>(),
        vec!["FindAll", "FilterConcept", "Count"]
    );
}
#[test]
fn omitted_nested_x_empty_child_alternative_cannot_erase_unsupported_sibling() {
    let mut rows = nested_without_x_splice_rows(fragment("resident of"));
    rows.push(row(
        "fragment",
        "C1 in E1",
        json!([step(
            "UnsupportedOperation",
            &[],
            json!([["@", "E", 1, ""]])
        )]),
    ));
    // Both children expand to the same parent program when @X is absent. They
    // must retain distinct admission witnesses until every child is checked.
    let fixture = Fixture::new(rows, vec![]);
    assert!(matches!(
        fixture.image.read_whole(
            "tenant",
            "How many organisations employing persons in Paris?",
            Cancellation::default()
        ),
        Err(Error::Invalid(_))
    ));
    assert_eq!(fixture.image.active_workers(), 0);
}
#[test]
fn repeated_nested_child_admission_reuses_program_viability_cache() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "fragment",
            "E1",
            json!([step("Find", &[], json!([["@", "E", 1, ""]]))]),
        ),
        row(
            "fragment",
            "X1 beside X2",
            json!([step("FindAll", &[], json!([]))]),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let spans = vec![
        GrammarSpan {
            start: 9,
            end: 14,
            kind: 'E',
            canonical: "Alice".into(),
        },
        GrammarSpan {
            start: 22,
            end: 27,
            kind: 'E',
            canonical: "Alice".into(),
        },
    ];
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut calls = Vec::new();
    let programs = match_composed(
        &db,
        "how many alice beside alice",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |p| {
            calls.push(p.clone());
            Ok(true)
        },
    )
    .unwrap();
    assert_eq!(programs.len(), 1);
    assert_eq!(calls.len(), 2); // One identical child program, then its parent.
    assert_eq!(calls[0][0].function, "Find");
    assert_eq!(calls[1][0].function, "FindAll");
}

#[test]
fn equivalent_segment_slot_paths_share_resolved_nodes_under_unchanged_cap() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "segment",
            "E1",
            unit("source", json!([step("Find", &[], json!(["Alice"]))])),
        ),
        row(
            "segment",
            "and C1",
            unit(
                "filter",
                json!([step("FilterConcept", &[], json!(["person"]))]),
            ),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    // Deliberately many lexical alternatives are unused by these explicit
    // release skeletons. They all have the same actual typed interpretation.
    let mut spans = Vec::new();
    for i in 0..100 {
        spans.push(GrammarSpan {
            start: 9,
            end: 14,
            kind: 'E',
            canonical: format!("alias{i}"),
        });
        spans.push(GrammarSpan {
            start: 19,
            end: 25,
            kind: 'C',
            canonical: format!("concept{i}"),
        });
    }
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut calls = 0;
    let programs = match_composed(
        &db,
        "how many alice and person",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits {
            combinations: 2,
            ..MatchLimits::default()
        },
        &budget,
        |_| {
            calls += 1;
            Ok(true)
        },
    )
    .unwrap();
    assert_eq!(programs.len(), 1);
    assert_eq!(calls, 1);
    assert_eq!(programs[0].program.len(), 3);
}
#[test]
fn unresolved_nested_hole_paths_do_not_spend_resolved_interpretation_cap() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "fragment",
            "E1",
            json!([step("Find", &[], json!([["@", "E", 1, ""]]))]),
        ),
        row(
            "fragment",
            "X1 X2",
            json!([
                step("@X", &[], json!([1])),
                step("@X", &[], json!([2])),
                step("And", &[0, 1], json!([]))
            ]),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let question = format!("how many {}", ["alice"; 20].join(" "));
    let spans = (0..20)
        .map(|i| GrammarSpan {
            start: 9 + 6 * i,
            end: 14 + 6 * i,
            kind: 'E',
            canonical: "Alice".into(),
        })
        .collect::<Vec<_>>();
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut calls = 0;
    let programs = match_composed(
        &db,
        &question,
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits {
            combinations: 2,
            ..MatchLimits::default()
        },
        &budget,
        |_| {
            calls += 1;
            Ok(true)
        },
    )
    .unwrap();
    assert!(programs.is_empty());
    assert_eq!(calls, 0);
}
#[test]
fn genuinely_distinct_resolved_region_programs_still_exhaust_same_cap() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "fragment",
            "E1",
            json!([step("Find", &[], json!([["@", "E", 1, ""]]))]),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let spans = ["Alice", "Bob", "Carol"]
        .into_iter()
        .map(|canonical| GrammarSpan {
            start: 9,
            end: 14,
            kind: 'E',
            canonical: canonical.into(),
        })
        .collect::<Vec<_>>();
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    assert!(matches!(
        match_composed(
            &db,
            "how many alice",
            &spans,
            &[],
            0,
            &ReaderPolicy::default(),
            MatchLimits {
                combinations: 2,
                ..MatchLimits::default()
            },
            &budget,
            |_| Ok(true)
        ),
        Err(Error::Limit("composition bindings"))
    ));
}

#[test]
fn identical_child_programs_at_distinct_boundaries_spend_distinct_witness_nodes() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "fragment",
            "E1",
            json!([step("Find", &[], json!([["@", "E", 1, ""]]))]),
        ),
        row(
            "fragment",
            "X1 X2",
            json!([step("FindAll", &[], json!([]))]),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    // Both cuts produce the identical Find("Alice") child programs and the
    // identical FindAll parent, but the selected child regions differ:
    // [alice] [alice alice] versus [alice alice] [alice].
    let spans = [(9, 14), (15, 26), (9, 20), (21, 26)]
        .into_iter()
        .map(|(start, end)| GrammarSpan {
            start,
            end,
            kind: 'E',
            canonical: "Alice".into(),
        })
        .collect::<Vec<_>>();
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    // Four resolved base regions plus two different nested witness nodes exceed
    // cap 5. Make the parent nonviable so no final outer node could cause this
    // failure if the two child-boundary witnesses were incorrectly collapsed.
    assert!(matches!(
        match_composed(
            &db,
            "how many alice alice alice",
            &spans,
            &[],
            0,
            &ReaderPolicy::default(),
            MatchLimits {
                combinations: 5,
                ..MatchLimits::default()
            },
            &budget,
            |program| Ok(program[0].function != "FindAll")
        ),
        Err(Error::Limit("composition bindings"))
    ));
}

fn dense_nested_syntax() -> (
    rusqlite::Connection,
    Vec<oracle_runtime_core::grammar::GrammarSpan>,
) {
    use oracle_runtime_core::grammar::GrammarSpan;
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "fragment",
            "E1",
            json!([step("Find", &[], json!([["@", "E", 1, ""]]))]),
        ),
        row(
            "fragment",
            "X1 X2",
            json!([
                step("@X", &[], json!([1])),
                step("@X", &[], json!([2])),
                step("And", &[0, 1], json!([]))
            ]),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let mut spans = Vec::new();
    for i in 0..100 {
        spans.push(GrammarSpan {
            start: 9,
            end: 14,
            kind: 'E',
            canonical: format!("entity{i}"),
        });
        spans.push(GrammarSpan {
            start: 15,
            end: 18,
            kind: 'E',
            canonical: format!("entity{i}"),
        });
    }
    (db, spans)
}
#[test]
fn empty_base_candidates_are_pruned_before_nested_products_and_node_admission() {
    use oracle_runtime_core::{composition::match_composed, grammar::MatchLimits, Budget};
    let (db, spans) = dense_nested_syntax();
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut calls = 0;
    let programs = match_composed(
        &db,
        "how many alice bob",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits {
            combinations: 1,
            ..MatchLimits::default()
        },
        &budget,
        |program| {
            assert_eq!(program.len(), 1);
            assert_eq!(program[0].function, "Find");
            calls += 1;
            Ok(false)
        },
    )
    .unwrap();
    assert!(programs.is_empty());
    assert_eq!(calls, 100); // 100 cached base checks, zero of 10,000 parent products.
}
#[test]
fn only_viable_base_choices_enter_nested_product_without_losing_witness_regions() {
    use oracle_runtime_core::{composition::match_composed, grammar::MatchLimits, Budget};
    let (db, spans) = dense_nested_syntax();
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let mut base_calls = 0;
    let mut parent_calls = 0;
    let programs = match_composed(
        &db,
        "how many alice bob",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits {
            combinations: 4,
            ..MatchLimits::default()
        },
        &budget,
        |program| {
            if program.len() == 1 {
                base_calls += 1;
                Ok(program[0].inputs == vec![json!("entity0")])
            } else {
                parent_calls += 1;
                Ok(true)
            }
        },
    )
    .unwrap();
    assert_eq!(base_calls, 100);
    assert_eq!(parent_calls, 1);
    assert_eq!(programs.len(), 1);
    assert_eq!(programs[0].program.len(), 4);
}
#[test]
fn empty_base_union_still_checks_unsupported_sibling_before_product_pruning() {
    use oracle_runtime_core::{composition::match_composed, grammar::MatchLimits, Budget};
    let (db, spans) = dense_nested_syntax();
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    assert!(matches!(
        match_composed(
            &db,
            "how many alice bob",
            &spans,
            &[],
            0,
            &ReaderPolicy::default(),
            MatchLimits {
                combinations: 1,
                ..MatchLimits::default()
            },
            &budget,
            |program| {
                assert_eq!(program.len(), 1);
                if program[0].inputs == vec![json!("entity99")] {
                    Err(Error::Invalid("unsupported demanded child".into()))
                } else {
                    Ok(false)
                }
            }
        ),
        Err(Error::Invalid(_))
    ));
}

#[test]
fn streamed_equivalent_matches_fit_live_storage_without_retaining_raw_batches() {
    use oracle_runtime_core::{
        composition::match_composed,
        grammar::{GrammarSpan, MatchLimits},
        Budget,
    };
    let db = rusqlite::Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    for r in [
        row(
            "segment",
            "E1",
            unit("source", json!([step("Find", &[], json!(["Alice"]))])),
        ),
        row(
            "segment",
            "and C1",
            unit(
                "filter",
                json!([step("FilterConcept", &[], json!(["person"]))]),
            ),
        ),
        row("outer", "how many X1", outer("Count")),
    ] {
        db.execute(
            "INSERT INTO reader_template VALUES (?1,0,?2,?3,3)",
            rusqlite::params![r.family, r.template, r.skeleton.to_string()],
        )
        .unwrap();
    }
    let mut spans = (0..1000)
        .map(|i| GrammarSpan {
            start: 9,
            end: 14,
            kind: 'E',
            canonical: format!("alias{i}"),
        })
        .collect::<Vec<_>>();
    spans.push(GrammarSpan {
        start: 19,
        end: 25,
        kind: 'C',
        canonical: "person".into(),
    });
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let programs = match_composed(
        &db,
        "how many alice and person",
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits {
            combinations: 2,
            materialized_bytes: 200_000,
            ..MatchLimits::default()
        },
        &budget,
        |_| Ok(true),
    )
    .unwrap();
    assert_eq!(programs.len(), 1);
    assert_eq!(programs[0].program.len(), 3);
}
