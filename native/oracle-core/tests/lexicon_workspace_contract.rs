//! Cached indexed rows must preserve the uncached recognizer's complete output.
use oracle_runtime_core::lexicon::{
    self, CandidateOptions, LexicalWorkspace, LexiconLimits, Normalization,
};
use oracle_runtime_core::{Budget, Cancellation, Error, Limits};
use rusqlite::{params, Connection};
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
fn budget() -> Budget {
    Budget::new(&Limits::default(), Cancellation::default()).unwrap()
}
fn fixture() -> Connection {
    let db = Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE oracle_lexicon(profile TEXT,surface TEXT,kind TEXT,canonical TEXT,alias INTEGER,PRIMARY KEY(profile,surface,kind,alias,canonical)) WITHOUT ROWID;
        CREATE TABLE oracle_lexicon_concepts(profile TEXT,surface TEXT,canonical TEXT,PRIMARY KEY(profile,surface,canonical)) WITHOUT ROWID;").unwrap();
    for profile in [Normalization::Reader4, Normalization::Reader7] {
        let name = if profile == Normalization::Reader4 {
            "reader4"
        } else {
            "reader7"
        };
        for (surface, kind, canonical, alias) in [
            ("the", "E", "The", 0),
            ("the", "C", "The", 0),
            ("the", "V", "The", 0),
            ("the", "C", "The Alias", 1),
            ("King's College", "E", "King's College", 0),
            ("city", "E", "City", 0),
            ("city", "C", "City", 0),
            ("cities", "C", "Cities Alias", 1),
            ("64.0", "N", "0", 1),
            ("foo", "E", "Foo", 0),
            ("foo", "C", "Foo", 0),
            ("foo", "A", "Foo attribute", 0),
            ("foo", "R", "Foo relation", 0),
            ("blue", "V", "Blue", 0),
            ("blue", "V", "Azure", 1),
            ("in", "R", "located in", 1),
            ("new york", "E", "New York", 0),
            ("new york", "C", "New York", 0),
            ("new york", "E", "York Alias A", 1),
            ("new york", "E", "York Alias B", 1),
            ("york", "E", "York", 0),
            ("ambiguous", "E", "Choice A", 1),
            ("ambiguous", "E", "Choice B", 1),
            ("i stanbul", "E", "İstanbul", 0),
            ("k", "E", "Kelvin", 0),
        ] {
            db.execute(
                "INSERT INTO oracle_lexicon VALUES (?1,?2,?3,?4,?5)",
                params![
                    name,
                    lexicon::normalize(surface, profile),
                    kind,
                    canonical,
                    alias
                ],
            )
            .unwrap();
        }
        db.execute(
            "INSERT INTO oracle_lexicon_concepts VALUES (?1,'city','City')",
            [name],
        )
        .unwrap();
    }
    db
}
fn modes() -> Vec<CandidateOptions> {
    let mut result = Vec::new();
    for normalization in [Normalization::Reader4, Normalization::Reader7] {
        for compositional in [false, true] {
            for level2 in [false, true] {
                for outer in [false, true] {
                    for plural in [false, true] {
                        for max_words in [1, 2, 8] {
                            result.push(CandidateOptions {
                                normalization,
                                compositional,
                                level2,
                                outer,
                                plural,
                                max_words,
                            });
                        }
                    }
                }
            }
        }
    }
    result
}
fn vm_counter(db: &Connection) -> Arc<AtomicUsize> {
    let count = Arc::new(AtomicUsize::new(0));
    let progress = Arc::clone(&count);
    db.progress_handler(
        1,
        Some(move || {
            progress.fetch_add(1, Ordering::Relaxed);
            false
        }),
    );
    count
}
#[test]
fn every_option_mode_matches_uncached_rows_aliases_plural_and_unicode() {
    let db = fixture();
    let limits = LexiconLimits::default();
    for raw in [
        "The King's College has cities and 64.0 foo in Blue new york missing",
        "İSTANBUL K Café Straße A..B O’Neil -64 1.2.3",
        "ambiguous cities cities city foo foo absent absent",
    ] {
        let mut shared = LexicalWorkspace::new(&db, raw);
        for options in modes() {
            let expected = lexicon::candidates(&db, raw, &options, &limits, &budget()).unwrap();
            let actual = shared.candidates(&options, &limits, &budget()).unwrap();
            assert_eq!(actual, expected, "{raw}: {options:?}");
            assert!(shared.retained_bytes() <= limits.materialized_bytes);
        }
    }
}
#[test]
fn warmed_modes_make_no_sql_probes_including_negative_results() {
    let db = fixture();
    let vm = vm_counter(&db);
    let limits = LexiconLimits::default();
    let raw = "new york absent absent cities foo 64.0";
    let mut shared = LexicalWorkspace::new(&db, raw);
    let options = modes();
    let mut expected = Vec::new();
    for mode in &options {
        expected.push(shared.candidates(mode, &limits, &budget()).unwrap());
    }
    assert!(vm.load(Ordering::Relaxed) > 0);
    vm.store(0, Ordering::Relaxed);
    for (mode, expected) in options.iter().zip(expected) {
        assert_eq!(
            shared.candidates(mode, &limits, &budget()).unwrap(),
            expected
        );
    }
    assert_eq!(vm.load(Ordering::Relaxed), 0);
    drop(shared);
    let mut next = LexicalWorkspace::new(&db, raw);
    next.candidates(&CandidateOptions::default(), &limits, &budget())
        .unwrap();
    assert!(vm.load(Ordering::Relaxed) > 0); // No cross-request retained probes.
}
#[test]
fn cache_saturation_streams_complete_results_instead_of_refusing() {
    let db = fixture();
    let vm = vm_counter(&db);
    let limits = LexiconLimits {
        materialized_bytes: 256,
        ..LexiconLimits::default()
    };
    let options = CandidateOptions::default();
    let raw = "city";
    let expected = lexicon::candidates(&db, raw, &options, &limits, &budget()).unwrap();
    let mut shared = LexicalWorkspace::new(&db, raw);
    assert_eq!(
        shared.candidates(&options, &limits, &budget()).unwrap(),
        expected
    );
    vm.store(0, Ordering::Relaxed);
    assert_eq!(
        shared.candidates(&options, &limits, &budget()).unwrap(),
        expected
    );
    assert!(vm.load(Ordering::Relaxed) > 0); // Raw rows do not fit beside normalization.
    assert!(shared.retained_bytes() <= limits.materialized_bytes);
}
#[test]
fn cached_projection_keeps_exact_limit_failures_and_cancellation() {
    let db = fixture();
    let raw = "ambiguous cities foo";
    let options = CandidateOptions::default();
    let mut shared = LexicalWorkspace::new(&db, raw);
    shared
        .candidates(&options, &LexiconLimits::default(), &budget())
        .unwrap();
    for limits in [
        LexiconLimits {
            question_bytes: 2,
            ..LexiconLimits::default()
        },
        LexiconLimits {
            question_tokens: 1,
            ..LexiconLimits::default()
        },
        LexiconLimits {
            max_name_words: 1,
            ..LexiconLimits::default()
        },
        LexiconLimits {
            spans: 0,
            ..LexiconLimits::default()
        },
        LexiconLimits {
            readings: 1,
            ..LexiconLimits::default()
        },
        LexiconLimits {
            materialized_bytes: 20,
            ..LexiconLimits::default()
        },
    ] {
        let expected = lexicon::candidates(&db, raw, &options, &limits, &budget()).unwrap_err();
        let actual = shared.candidates(&options, &limits, &budget()).unwrap_err();
        assert_eq!(actual.to_string(), expected.to_string());
    }
    shared
        .candidates(&options, &LexiconLimits::default(), &budget())
        .unwrap();
    let cancelled = Cancellation::default();
    cancelled.cancel();
    let cancelled = Budget::new(&Limits::default(), cancelled).unwrap();
    assert!(matches!(
        shared.candidates(&options, &LexiconLimits::default(), &cancelled),
        Err(Error::Cancelled)
    ));
}
#[test]
fn a_failed_lookup_never_commits_partial_cached_rows() {
    let db = fixture();
    let vm = vm_counter(&db);
    let raw = "ambiguous";
    let options = CandidateOptions::default();
    let mut shared = LexicalWorkspace::new(&db, raw);
    assert!(matches!(
        shared.candidates(
            &options,
            &LexiconLimits {
                readings: 1,
                ..LexiconLimits::default()
            },
            &budget()
        ),
        Err(Error::Limit("lexical readings"))
    ));
    vm.store(0, Ordering::Relaxed);
    let actual = shared
        .candidates(&options, &LexiconLimits::default(), &budget())
        .unwrap();
    assert!(vm.load(Ordering::Relaxed) > 0);
    assert_eq!(actual.spans[0].readings.len(), 2);
    assert_eq!(
        actual,
        lexicon::candidates(&db, raw, &options, &LexiconLimits::default(), &budget()).unwrap()
    );
}
