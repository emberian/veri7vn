use oracle_runtime_core::{grammar::*, Budget, Cancellation, Error, Limits};
use rusqlite::Connection;
use serde_json::json;
use std::collections::BTreeMap;

fn budget() -> Budget {
    Budget::new(&Limits::default(), Cancellation::default()).unwrap()
}
fn export() -> ReaderExport {
    ReaderExport {
        format: READER_FORMAT.into(),
        version: READER_VERSION,
        metadata: BTreeMap::new(),
        policy: ReaderPolicy::default(),
        templates: vec![],
        shapes: vec![],
        aliases: vec![],
        words: vec![],
        forms: vec![],
    }
}
fn row(family: &str, template: &str, skeleton: serde_json::Value, support: u64) -> TemplateRow {
    TemplateRow {
        family: family.into(),
        level: 0,
        template: template.into(),
        skeleton,
        support,
    }
}
fn named_program() -> serde_json::Value {
    json!([{"function":"Find","dependencies":[],"inputs":[["@","E",1,""]]},
           {"function":"What","dependencies":[0],"inputs":[]}])
}
fn install(export: &ReaderExport) -> Connection {
    let db = Connection::open_in_memory().unwrap();
    install_tables(&db, export, 1000, 1024 * 1024).unwrap();
    db
}

#[test]
fn alternatives_keep_counts_and_do_not_choose_a_winner() {
    let mut e = export();
    let second = json!([{"function":"Find","dependencies":[],"inputs":[["@","E",1,""]]},
                       {"function":"Count","dependencies":[0],"inputs":[]}]);
    e.templates = vec![
        row("whole", "who is E1", named_program(), 3),
        row("whole", "who is E1", second, 8),
    ];
    let db = install(&e);
    let hit = lookup(
        &db,
        "whole",
        0,
        "who is E1",
        Fallback::None,
        &e.policy,
        20,
        &budget(),
    )
    .unwrap()
    .unwrap();
    assert!(hit.exact);
    assert_eq!(hit.total_support, 11);
    assert_eq!(hit.candidates.len(), 2);
    assert!(hit.candidates.iter().all(|c| c.rejection.is_none()));
    let spans = [GrammarSpan {
        start: 7,
        end: 13,
        kind: 'E',
        canonical: "Hamlet".into(),
    }];
    let programs = match_whole(
        &db,
        "who is hamlet",
        &spans,
        0,
        &e.policy,
        MatchLimits::default(),
        &budget(),
    )
    .unwrap();
    assert_eq!(programs.len(), 2);
    assert!(programs
        .iter()
        .all(|p| p.program[0].inputs == vec![json!("Hamlet")]));
}

#[test]
fn exact_presence_prevents_fallback_even_when_it_is_rejected() {
    let mut e = export();
    let hidden = json!([{"function":"Find","dependencies":[],"inputs":["unwritten name"]}]);
    e.templates = vec![
        row("fragment", "the E1", hidden, 1),
        row("fragment", "~E1", named_program(), 7),
    ];
    e.words.push(WordRow {
        category: "glue".into(),
        word: "the".into(),
    });
    let db = install(&e);
    let hit = lookup(
        &db,
        "fragment",
        0,
        "the E1",
        Fallback::Content,
        &e.policy,
        20,
        &budget(),
    )
    .unwrap()
    .unwrap();
    assert!(hit.exact);
    assert_eq!(hit.matched_key, "the E1");
    assert_eq!(hit.candidates.len(), 1);
    assert!(hit.candidates[0].rejection.is_some());
    let fallback = lookup(
        &db,
        "fragment",
        0,
        "the the E1",
        Fallback::Content,
        &e.policy,
        20,
        &budget(),
    )
    .unwrap()
    .unwrap();
    assert!(!fallback.exact);
    assert_eq!(fallback.matched_key, "~E1");
}

#[test]
fn hidden_words_require_replication_and_dominance_for_composition() {
    let mut e = export();
    let hidden = json!([{"function":"Find","dependencies":[],"inputs":["hidden"]}]);
    e.templates = vec![
        row("fragment", "E1", hidden, 2),
        row("fragment", "E1", named_program(), 8),
        row(
            "whole",
            "E1",
            json!([{"function":"Find","dependencies":[],"inputs":["hidden"]}]),
            2,
        ),
        row(
            "outer",
            "X1",
            json!([{"function":"@X","dependencies":[],"inputs":[1]}]),
            1,
        ),
    ];
    let db = install(&e);
    let fragment = lookup(
        &db,
        "fragment",
        0,
        "E1",
        Fallback::None,
        &e.policy,
        20,
        &budget(),
    )
    .unwrap()
    .unwrap();
    assert_eq!(
        fragment
            .candidates
            .iter()
            .filter(|c| c.rejection.is_some())
            .count(),
        1
    );
    let whole = lookup(
        &db,
        "whole",
        0,
        "E1",
        Fallback::None,
        &e.policy,
        20,
        &budget(),
    )
    .unwrap()
    .unwrap();
    assert!(whole.candidates[0].rejection.is_none()); // Reader6 has no dominance guard.
    let outer = lookup(
        &db,
        "outer",
        0,
        "X1",
        Fallback::None,
        &e.policy,
        20,
        &budget(),
    )
    .unwrap()
    .unwrap();
    assert_eq!(
        outer.candidates[0].rejection.as_deref(),
        Some("replication")
    );
}

#[test]
fn fallback_keeps_asked_words_and_strip_only_drops_leading_glue() {
    let mut e = export();
    for (category, word) in [("glue", "the"), ("glue", "many"), ("keep", "many")] {
        e.words.push(WordRow {
            category: category.into(),
            word: word.into(),
        });
    }
    let db = install(&e);
    assert_eq!(
        fallback_key(&db, "the many the E1", Fallback::Content, &budget()).unwrap(),
        "~many E1"
    );
    assert_eq!(
        fallback_key(&db, "the E1 the", Fallback::Strip, &budget()).unwrap(),
        "~E1 the"
    );
    assert_eq!(
        fallback_key(&db, "the", Fallback::Strip, &budget()).unwrap(),
        "~the"
    );
}

#[test]
fn expansion_rebases_shared_dependencies_preserves_units_and_refuses_missing_slots() {
    let sk: Program = serde_json::from_value(json!([
        {"function":"@NOP","dependencies":[],"inputs":[]},
        {"function":"@X","dependencies":[],"inputs":[1]},
        {"function":"FilterNum","dependencies":[1],"inputs":["height",["@","N",1,"metre"],">"]},
        {"function":"Count","dependencies":[2],"inputs":[]}]))
    .unwrap();
    let mut xp: Program = serde_json::from_value(named_program()).unwrap();
    xp[0].inputs = vec![json!("Paris")];
    let mut texts = Bindings::new();
    texts.insert(('N', 1), "1.25".into());
    let xs = BTreeMap::from([(1, xp)]);
    let result = expand(&sk, &texts, &xs, 20).unwrap().unwrap();
    assert_eq!(result.len(), 4);
    assert_eq!(result[2].dependencies, vec![1]);
    assert_eq!(result[3].dependencies, vec![2]);
    assert_eq!(result[2].inputs[1], json!("1.25 metre"));
    assert!(expand(&sk, &Bindings::new(), &xs, 20).unwrap().is_none());
    assert!(matches!(expand(&sk, &texts, &xs, 3), Err(Error::Limit(_))));
}

#[test]
fn ordinal_binding_uses_text_order_and_rejects_overlap() {
    let spans = vec![
        GrammarSpan {
            start: 8,
            end: 12,
            kind: 'E',
            canonical: "Rome".into(),
        },
        GrammarSpan {
            start: 0,
            end: 5,
            kind: 'E',
            canonical: "Paris".into(),
        },
    ];
    let (tm, texts) = delex("paris v rome", &spans).unwrap();
    assert_eq!(tm, "E1 v E2");
    assert_eq!(texts[&('E', 1)], "Paris");
    let mut overlap = spans;
    overlap.push(GrammarSpan {
        start: 0,
        end: 12,
        kind: 'E',
        canonical: "all".into(),
    });
    assert!(delex("paris v rome", &overlap).is_err());
}

#[test]
fn form_veto_applies_to_all_successful_readings() {
    let mut e = export();
    e.forms = vec![
        FormRow {
            opening: "how many".into(),
            kinds: vec!["count".into()],
        },
        FormRow {
            opening: "how".into(),
            kinds: vec!["entity".into()],
        },
        FormRow {
            opening: "has:which".into(),
            kinds: vec!["entity".into()],
        },
    ];
    let db = install(&e);
    let count: Program =
        serde_json::from_value(json!([{"function":"Count","dependencies":[],"inputs":[]}]))
            .unwrap();
    let entity: Program = serde_json::from_value(named_program()).unwrap();
    assert!(forms_allow(
        &db,
        "how many names",
        std::slice::from_ref(&count),
        &e.policy,
        &budget()
    )
    .unwrap());
    assert!(!forms_allow(
        &db,
        "how many names",
        &[count.clone(), entity],
        &e.policy,
        &budget()
    )
    .unwrap());
    assert!(!forms_allow(&db, "how many which names", &[count], &e.policy, &budget()).unwrap());
}

#[test]
fn bounds_do_not_return_truncated_ambiguity_and_cancel_is_observed() {
    let mut e = export();
    e.templates.push(row("whole", "E1", named_program(), 3));
    let db = install(&e);
    let spans = [
        GrammarSpan {
            start: 0,
            end: 6,
            kind: 'E',
            canonical: "Hamlet".into(),
        },
        GrammarSpan {
            start: 0,
            end: 6,
            kind: 'E',
            canonical: "Another Hamlet".into(),
        },
    ];
    let limits = MatchLimits {
        combinations: 1,
        ..MatchLimits::default()
    };
    assert!(matches!(
        match_whole(&db, "hamlet", &spans, 0, &e.policy, limits, &budget()),
        Err(Error::Limit(_))
    ));
    let cancel = Cancellation::default();
    cancel.cancel();
    let b = Budget::new(&Limits::default(), cancel).unwrap();
    assert!(matches!(
        lookup(&db, "whole", 0, "E1", Fallback::None, &e.policy, 10, &b),
        Err(Error::Cancelled)
    ));
}

#[test]
fn malformed_import_rolls_back_its_schema_and_rows() {
    let db = Connection::open_in_memory().unwrap();
    let mut e = export();
    e.templates.push(row("whole", "E1", named_program(), 3));
    e.templates.push(row(
        "whole",
        "bad",
        json!([{"function":"What","dependencies":[0],"inputs":[]}]),
        1,
    ));
    assert!(install_tables(&db, &e, 100, 1024 * 1024).is_err());
    let count: i64 = db
        .query_row(
            "SELECT count(*) FROM sqlite_master WHERE name LIKE 'reader_%'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!(count, 0);
    e.templates.pop();
    install_tables(&db, &e, 100, 1024 * 1024).unwrap();
    assert!(install_tables(&db, &e, 100, 1024 * 1024).is_err());
    assert_eq!(
        db.query_row("SELECT count(*) FROM reader_template", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        1
    );
}

/// Deliberately independent powerset traversal for small cases. This is an
/// executable equivalence oracle for path enumeration, not the production
/// prefix walk. Lookup/expansion guards are separately contracted above.
fn brute_force_whole(
    db: &Connection,
    question: &str,
    spans: &[GrammarSpan],
    policy: &ReaderPolicy,
) -> Vec<String> {
    assert!(spans.len() < 16);
    let mut answers = Vec::new();
    for mask in 0usize..(1usize << spans.len()) {
        let selected: Vec<_> = spans
            .iter()
            .enumerate()
            .filter(|(i, _)| mask & (1usize << i) != 0)
            .map(|(_, s)| s.clone())
            .collect();
        let Ok((template, texts)) = delex(question, &selected) else {
            continue;
        };
        if let Some(hit) = lookup(
            db,
            "whole",
            0,
            &template,
            Fallback::None,
            policy,
            1000,
            &budget(),
        )
        .unwrap()
        {
            for candidate in hit.candidates.into_iter().filter(|c| c.rejection.is_none()) {
                let skeleton: Program = serde_json::from_value(candidate.skeleton).unwrap();
                if let Some(program) = expand(&skeleton, &texts, &BTreeMap::new(), 128).unwrap() {
                    answers.push(
                        serde_json::to_string(&MatchedProgram {
                            template: template.clone(),
                            level: 0,
                            support: candidate.support,
                            program,
                        })
                        .unwrap(),
                    );
                }
            }
        }
    }
    answers.sort();
    answers
}

#[test]
fn prefix_walk_equals_independent_small_brute_force_with_overlap_and_ambiguity() {
    let question = "alpha beta gamma";
    let spans = vec![
        GrammarSpan {
            start: 0,
            end: 5,
            kind: 'E',
            canonical: "Alpha".into(),
        },
        GrammarSpan {
            start: 0,
            end: 5,
            kind: 'E',
            canonical: "Other Alpha".into(),
        },
        GrammarSpan {
            start: 0,
            end: 10,
            kind: 'E',
            canonical: "Alpha Beta".into(),
        },
        GrammarSpan {
            start: 6,
            end: 10,
            kind: 'C',
            canonical: "Beta".into(),
        },
        GrammarSpan {
            start: 6,
            end: 16,
            kind: 'V',
            canonical: "Beta Gamma".into(),
        },
        GrammarSpan {
            start: 11,
            end: 16,
            kind: 'N',
            canonical: "3".into(),
        },
        GrammarSpan {
            start: 11,
            end: 16,
            kind: 'E',
            canonical: "Gamma".into(),
        },
    ];
    // Build a mix of reachable learned and unlearned templates. Slot-bearing
    // inputs make lost canonical bindings and wrong ordinals visible in output.
    let mut by_template = BTreeMap::new();
    for mask in 0usize..(1usize << spans.len()) {
        let selected: Vec<_> = spans
            .iter()
            .enumerate()
            .filter(|(i, _)| mask & (1usize << i) != 0)
            .map(|(_, s)| s.clone())
            .collect();
        let Ok((template, texts)) = delex(question, &selected) else {
            continue;
        };
        let mut skeleton = vec![json!({"function":"Find","dependencies":[],"inputs":["fixed"]})];
        for ((kind, ordinal), _) in texts {
            let dependency = skeleton.len() - 1;
            skeleton.push(json!({"function":"FilterStr","dependencies":[dependency],
                "inputs":["field",["@",kind.to_string(),ordinal,if kind=='N' {"unit"} else {""}]]}));
        }
        by_template.insert(template, json!(skeleton));
    }
    let mut e = export();
    for (i, (template, skeleton)) in by_template.into_iter().enumerate() {
        if i % 2 == 0 {
            e.templates.push(row("whole", &template, skeleton, 3));
        }
    }
    // Near prefixes and the wrong template level/family must not manufacture a
    // path; exact lookup still decides at the final word.
    e.templates
        .push(row("whole", "E10 gamma", named_program(), 3));
    e.templates
        .push(row("fragment", "E1 beta gamma", named_program(), 3));
    let db = install(&e);
    let expected = brute_force_whole(&db, question, &spans, &e.policy);
    assert!(!expected.is_empty());
    let mut actual: Vec<_> = match_whole(
        &db,
        question,
        &spans,
        0,
        &e.policy,
        MatchLimits::default(),
        &budget(),
    )
    .unwrap()
    .iter()
    .map(|m| serde_json::to_string(m).unwrap())
    .collect();
    actual.sort();
    assert_eq!(actual, expected);
}

#[test]
fn many_irrelevant_spans_do_not_consume_reachable_binding_bound() {
    let words: Vec<_> = (0..24).map(|i| format!("word{i}")).collect();
    let question = words.join(" ");
    let mut spans = Vec::new();
    let mut offset = 0;
    for word in &words {
        spans.push(GrammarSpan {
            start: offset,
            end: offset + word.len(),
            kind: 'E',
            canonical: word.clone(),
        });
        offset += word.len() + 1;
    }
    let template = format!("{} E1", words[..23].join(" "));
    let mut e = export();
    e.templates
        .push(row("whole", &template, named_program(), 3));
    let db = install(&e);
    let limits = MatchLimits {
        combinations: 1,
        ..MatchLimits::default()
    };
    // There are 2^24 valid disjoint subsets, but precisely one learned complete
    // template/binding. A powerset cap of 400 would incorrectly refuse this.
    let matches = match_whole(&db, &question, &spans, 0, &e.policy, limits, &budget()).unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].program[0].inputs, vec![json!("word23")]);
}

#[test]
fn genuine_more_than_four_hundred_complete_bindings_still_fail_closed() {
    let mut e = export();
    e.templates.push(row("whole", "E1", named_program(), 3));
    let db = install(&e);
    let spans: Vec<_> = (0..401)
        .map(|i| GrammarSpan {
            start: 0,
            end: 4,
            kind: 'E',
            canonical: format!("name{i}"),
        })
        .collect();
    assert!(matches!(
        match_whole(
            &db,
            "name",
            &spans,
            0,
            &e.policy,
            MatchLimits::default(),
            &budget()
        ),
        Err(Error::Limit("reader combinations"))
    ));
}
