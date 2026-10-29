use oracle_runtime_core::lexicon::{
    self, Alias, CandidateOptions, LexicalKind, LexiconBuildLimits, LexiconLimits, Normalization,
};
use oracle_runtime_core::{Budget, Cancellation, Error, Limits};
use rusqlite::{params, Connection};
use serde_json::json;

fn budget() -> Budget {
    Budget::new(&Limits::default(), Cancellation::default()).unwrap()
}
fn fixture() -> Connection {
    let db = Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT); CREATE TABLE nodes(id TEXT PRIMARY KEY,kind TEXT,record TEXT);").unwrap();
    for (id, kind, value) in [
        (
            "Q1",
            "entity",
            json!({"name":"New York", "attributes":[{"key":"New York","value":{"type":"string","value":"Blue"},"qualifiers":{"valid at":[]}}], "relations":[{"predicate":"located in","qualifiers":{"since":[]}}]}),
        ),
        ("Q2", "entity", json!({"name":"York"})),
        ("Q3", "entity", json!({"name":"AC/DC"})),
        ("Q4", "entity", json!({"name":"AC-DC"})),
        ("Q5", "entity", json!({"name":"The"})),
        ("C1", "concept", json!({"name":"City"})),
        ("Q6", "entity", json!({"name":"St Edmund Hall"})),
        ("Q7", "entity", json!({"name":"King's College"})),
    ] {
        db.execute(
            "INSERT INTO nodes VALUES (?1,?2,?3)",
            params![id, kind, value.to_string()],
        )
        .unwrap();
    }
    lexicon::build_from_nodes(&db, &budget(), &LexiconBuildLimits::default()).unwrap();
    lexicon::validate(&db).unwrap();
    db
}
fn read(db: &Connection, raw: &str, options: CandidateOptions) -> lexicon::CandidateSet {
    lexicon::candidates(db, raw, &options, &LexiconLimits::default(), &budget()).unwrap()
}

#[test]
fn normalization_is_ascii_after_unicode_lowercase_with_explicit_possessives() {
    assert_eq!(
        lexicon::normalize(
            "İSTANBUL K Café Straße A..B O’Neil -64 1.2.3",
            Normalization::Reader4
        ),
        "i stanbul k caf stra e a b o neil 64 1.2.3"
    );
    assert_eq!(
        lexicon::normalize("St Edmund Hall's ISNI", Normalization::Reader4),
        "st edmund hall's isni"
    );
    assert_eq!(
        lexicon::normalize("St Edmund Hall's ISNI", Normalization::Reader7),
        "st edmund hall 's isni"
    );
    // ASCII apostrophes and dots stay inside tokens only with alphanumerics on both sides.
    assert_eq!(
        lexicon::normalize("'a' X.Y 's 1. .5", Normalization::Reader4),
        "a x.y s 1 5"
    );
}

#[test]
fn overlapping_names_and_kind_ambiguity_survive_with_normalized_offsets() {
    let db = fixture();
    let result = read(&db, "Where is New—York?", CandidateOptions::default());
    assert_eq!(result.normalized, "where is new york");
    assert_eq!(
        result
            .spans
            .iter()
            .map(|s| (s.start, s.end))
            .collect::<Vec<_>>(),
        vec![(9, 17), (13, 17)]
    );
    let kinds: Vec<_> = result.spans[0].readings.iter().map(|r| r.kind).collect();
    assert_eq!(kinds, vec![LexicalKind::E, LexicalKind::C]);
    assert_eq!(result.spans[0].readings[0].canonical, "New York");
    for span in result.spans {
        assert!(!result.normalized[span.start..span.end].is_empty());
    }
}

#[test]
fn typed_spelling_collisions_do_not_pick_the_first_source_record() {
    let db = fixture();
    let result = read(&db, "ac dc", CandidateOptions::default());
    let spellings: Vec<_> = result.spans[0]
        .readings
        .iter()
        .filter(|r| r.kind == LexicalKind::E)
        .map(|r| r.canonical.as_str())
        .collect();
    assert_eq!(spellings, vec!["AC-DC", "AC/DC"]);
}

#[test]
fn aliases_override_only_their_kind_and_retain_multiple_canonical_readings() {
    let db = fixture();
    let aliases = [
        Alias {
            surface: "big apple".into(),
            kind: LexicalKind::E,
            canonical: "new york".into(),
        },
        Alias {
            surface: "big apple".into(),
            kind: LexicalKind::E,
            canonical: "york".into(),
        },
        Alias {
            surface: "york".into(),
            kind: LexicalKind::E,
            canonical: "new york".into(),
        },
        Alias {
            surface: "none".into(),
            kind: LexicalKind::N,
            canonical: "0".into(),
        },
        Alias {
            surface: "64".into(),
            kind: LexicalKind::N,
            canonical: "0".into(),
        },
        Alias {
            surface: "in".into(),
            kind: LexicalKind::R,
            canonical: "located in".into(),
        },
    ];
    lexicon::install_aliases(&db, &aliases, &LexiconBuildLimits::default(), &budget()).unwrap();
    let result = read(&db, "big apple", CandidateOptions::default());
    assert_eq!(
        result.spans[0]
            .readings
            .iter()
            .map(|r| r.canonical.as_str())
            .collect::<Vec<_>>(),
        vec!["New York", "York"]
    );
    assert!(result.spans[0].readings.iter().all(|r| r.via_alias));
    for text in ["none", "64"] {
        let numeric = read(&db, text, CandidateOptions::default());
        assert_eq!(numeric.spans[0].readings.len(), 1);
        assert_eq!(numeric.spans[0].readings[0].kind, LexicalKind::N);
        assert_eq!(numeric.spans[0].readings[0].canonical, "0");
    }
    let york = read(&db, "york", CandidateOptions::default());
    assert_eq!(york.spans[0].readings[0].canonical, "New York");
    assert_eq!(york.spans[0].readings[1].canonical, "York");
    assert!(read(&db, "in", CandidateOptions::default())
        .spans
        .is_empty());
    let options = CandidateOptions {
        level2: true,
        ..CandidateOptions::default()
    };
    assert_eq!(
        read(&db, "in", options).spans[0].readings[0].canonical,
        "located in"
    );
    assert!(read(
        &db,
        "big apple",
        CandidateOptions {
            outer: true,
            compositional: true,
            ..CandidateOptions::default()
        }
    )
    .spans
    .is_empty());
}

#[test]
fn grammar_alias_import_streams_normalized_targets_through_original_spellings() {
    let db = fixture();
    db.execute_batch("CREATE TABLE reader_meta(key TEXT,value TEXT); INSERT INTO reader_meta VALUES ('provenance','{\"normalization\":\"reader7_possessive\"}'); CREATE TABLE reader_alias(phrase TEXT,kind TEXT,canonical TEXT); INSERT INTO reader_alias VALUES ('nyc','E','new york'); INSERT INTO reader_alias VALUES ('royal ''s','E','king ''s college');").unwrap();
    assert_eq!(
        lexicon::install_grammar_aliases(&db, &LexiconBuildLimits::default(), &budget()).unwrap(),
        2
    );
    let result = read(&db, "nyc", CandidateOptions::default());
    assert_eq!(result.spans[0].readings[0].canonical, "New York");
    let possessive = read(&db, "royal's", CandidateOptions::default());
    assert_eq!(possessive.spans[0].readings[0].canonical, "King's College");
    assert!(read(
        &db,
        "nyc",
        CandidateOptions {
            normalization: Normalization::Reader4,
            ..CandidateOptions::default()
        }
    )
    .spans
    .is_empty());
}

#[test]
fn keys_values_qualifiers_and_numeric_tokens_have_the_expected_gates() {
    let db = fixture();
    let raw = "blue valid at since located in -64 1.2.3";
    let basic = read(&db, raw, CandidateOptions::default());
    assert_eq!(basic.spans.len(), 3);
    assert_eq!(basic.spans[0].readings[0].kind, LexicalKind::V);
    assert_eq!(basic.spans[1].readings[0].canonical, "64");
    assert_eq!(basic.spans[2].readings[0].canonical, "1.2.3");
    let keyed = read(
        &db,
        raw,
        CandidateOptions {
            level2: true,
            ..CandidateOptions::default()
        },
    );
    assert_eq!(keyed.spans.len(), 6);
    assert_eq!(keyed.spans[1].readings[0].canonical, "valid at");
    assert_eq!(keyed.spans[2].readings[0].canonical, "since");
    assert_eq!(keyed.spans[3].readings[0].kind, LexicalKind::R);
}

#[test]
fn reader7_plural_and_possessive_support_is_local_and_function_words_are_suppressed() {
    let db = fixture();
    let result = read(
        &db,
        "cities",
        CandidateOptions {
            compositional: true,
            ..CandidateOptions::default()
        },
    );
    assert_eq!(result.spans[0].readings[0].kind, LexicalKind::C);
    assert_eq!(result.spans[0].readings[0].canonical, "City");
    assert!(read(&db, "cities", CandidateOptions::default())
        .spans
        .is_empty());
    assert_eq!(read(&db, "the", CandidateOptions::default()).spans.len(), 1);
    let count: u64 = db
        .query_row(
            "SELECT count(*) FROM oracle_lexicon WHERE surface='cities'",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert_eq!(count, 0);
    assert!(read(
        &db,
        "cities",
        CandidateOptions {
            normalization: Normalization::Reader4,
            ..CandidateOptions::default()
        }
    )
    .spans
    .is_empty());
    assert!(read(
        &db,
        "the",
        CandidateOptions {
            compositional: true,
            ..CandidateOptions::default()
        }
    )
    .spans
    .is_empty());
    assert_eq!(
        read(
            &db,
            "the",
            CandidateOptions {
                normalization: Normalization::Reader4,
                ..CandidateOptions::default()
            }
        )
        .spans
        .len(),
        1
    );
    let poss = read(&db, "St Edmund Hall's ISNI", CandidateOptions::default());
    assert_eq!(
        &poss.normalized[poss.spans[0].start..poss.spans[0].end],
        "st edmund hall"
    );
}

#[test]
fn limits_and_cancellation_fail_the_whole_request() {
    let db = fixture();
    let opts = CandidateOptions::default();
    for (text, limits) in [
        (
            "new york",
            LexiconLimits {
                question_bytes: 3,
                ..LexiconLimits::default()
            },
        ),
        (
            "new york",
            LexiconLimits {
                question_tokens: 1,
                ..LexiconLimits::default()
            },
        ),
        (
            "new york",
            LexiconLimits {
                spans: 1,
                ..LexiconLimits::default()
            },
        ),
        (
            "ac dc",
            LexiconLimits {
                readings: 1,
                ..LexiconLimits::default()
            },
        ),
        (
            "new york",
            LexiconLimits {
                materialized_bytes: 10,
                ..LexiconLimits::default()
            },
        ),
    ] {
        assert!(matches!(
            lexicon::candidates(&db, text, &opts, &limits, &budget()),
            Err(Error::Limit(_))
        ));
    }
    let cancel = Cancellation::default();
    cancel.cancel();
    let cancelled = Budget::new(&Limits::default(), cancel).unwrap();
    assert!(matches!(
        lexicon::candidates(
            &db,
            "new york",
            &opts,
            &LexiconLimits::default(),
            &cancelled
        ),
        Err(Error::Cancelled)
    ));
    let tiny = Budget::new(
        &Limits {
            fuel: 1,
            ..Limits::default()
        },
        Cancellation::default(),
    )
    .unwrap();
    assert!(matches!(
        lexicon::candidates(&db, "new york", &opts, &LexiconLimits::default(), &tiny),
        Err(Error::Limit("fuel"))
    ));
}

#[test]
fn lexical_lookup_uses_its_composite_primary_key() {
    let db = fixture();
    let detail: String = db.query_row("EXPLAIN QUERY PLAN SELECT kind,canonical,alias FROM oracle_lexicon WHERE profile=?1 AND surface=?2 ORDER BY kind,alias DESC,canonical",params!["reader7","new york"],|r|r.get(3)).unwrap();
    assert!(
        detail.contains("SEARCH oracle_lexicon USING PRIMARY KEY"),
        "{detail}"
    );
}

#[test]
fn failed_release_build_is_rolled_back_before_publication() {
    let db = Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT); CREATE TABLE nodes(id TEXT PRIMARY KEY,kind TEXT,record TEXT); INSERT INTO nodes VALUES ('Q1','entity','{\"name\":\"Alice\"}'); BEGIN;").unwrap();
    let bounds = LexiconBuildLimits {
        entries: 1,
        ..LexiconBuildLimits::default()
    };
    assert!(matches!(
        lexicon::build_from_nodes(&db, &budget(), &bounds),
        Err(Error::Limit("lexical entries"))
    ));
    db.execute_batch("ROLLBACK;").unwrap();
    let exists: bool = db
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE name='oracle_lexicon')",
            [],
            |r| r.get(0),
        )
        .unwrap();
    assert!(!exists);
    db.execute_batch("BEGIN;").unwrap();
    let bounds = LexiconBuildLimits {
        record_bytes: 1,
        ..LexiconBuildLimits::default()
    };
    assert!(matches!(
        lexicon::build_from_nodes(&db, &budget(), &bounds),
        Err(Error::Limit("lexical source record bytes"))
    ));
    db.execute_batch("ROLLBACK;").unwrap();
}

#[test]
fn grammar_alias_normalization_is_selected_from_release_provenance() {
    let db = fixture();
    db.execute_batch("CREATE TABLE reader_meta(key TEXT,value TEXT); INSERT INTO reader_meta VALUES ('provenance','{\"normalization\":\"reader4\"}'); CREATE TABLE reader_alias(phrase TEXT,kind TEXT,canonical TEXT); INSERT INTO reader_alias VALUES ('nyc','E','new york');").unwrap();
    assert_eq!(
        lexicon::grammar_normalization(&db).unwrap(),
        Normalization::Reader4
    );
    assert_eq!(
        lexicon::install_grammar_aliases(&db, &LexiconBuildLimits::default(), &budget()).unwrap(),
        1
    );
    assert!(read(&db, "nyc", CandidateOptions::default())
        .spans
        .is_empty());
    assert_eq!(
        read(
            &db,
            "nyc",
            CandidateOptions {
                normalization: Normalization::Reader4,
                ..CandidateOptions::default()
            }
        )
        .spans[0]
            .readings[0]
            .canonical,
        "New York"
    );
    db.execute(
        "UPDATE reader_meta SET value='{}' WHERE key='provenance'",
        [],
    )
    .unwrap();
    assert!(matches!(
        lexicon::grammar_normalization(&db),
        Err(Error::Format(_))
    ));
}

fn image_source(directory: &tempfile::TempDir) -> std::path::PathBuf {
    let source = directory.path().join("source.json");
    std::fs::write(
        &source,
        json!({
            "concepts":{"C":{"name":"Person","instanceOf":[]}},
            "entities":{"Q":{"name":"Alice","instanceOf":["C"],"attributes":[
                {"key":"nickname","value":{"type":"string","value":"Ally"},"qualifiers":{}}
            ],"relations":[]}}
        })
        .to_string(),
    )
    .unwrap();
    source
}
fn reader_export(source: &std::path::Path) -> oracle_runtime_core::grammar::ReaderExport {
    serde_json::from_value(json!({
        "format":"oracle-reader-tables","version":1,
        "metadata":{"fixture":true,"normalization":"reader7_possessive","kb_sha256":image_digest(source)},
        "policy":{
            "min_skeleton":2,"dominance":0.5,"all_replicated":false,
            "outer_replicated":true,"form_check":true,"asking_check":true
        },
        "templates":[],"shapes":[],
        "aliases":[{"phrase":"the person","kind":"E","canonical":"alice"}],
        "words":[],"forms":[]
    }))
    .unwrap()
}
fn image_digest(path: &std::path::Path) -> String {
    use sha2::{Digest, Sha256};
    format!("{:x}", Sha256::digest(std::fs::read(path).unwrap()))
}

#[test]
fn original_v2_image_has_no_lexical_capability_but_runs_pure_programs() {
    use oracle_runtime_core::{build_image, Image};
    let directory = tempfile::tempdir().unwrap();
    let source = image_source(&directory);
    let destination = directory.path().join("v2.sqlite");
    let receipt = build_image(&source, &destination, 100_000, 10_000).unwrap();
    assert_eq!(receipt.schema, "oracle-image-v2");
    assert!(receipt.capabilities.lexicon.is_none());
    assert!(serde_json::to_value(&receipt)
        .unwrap()
        .get("capabilities")
        .is_none());
    let image = Image::open(&destination, &receipt.image_sha256, Limits::default()).unwrap();
    assert!(image.capabilities.lexicon.is_none());
    assert!(image.capabilities.reader.is_none());
    let program = json!([
        {"function":"FindAll","dependencies":[],"inputs":[]},
        {"function":"Count","dependencies":[0],"inputs":[]}
    ])
    .to_string();
    let reply: serde_json::Value = serde_json::from_str(
        &image
            .query_program("tenant", &program, Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(reply["value"], 1);
    let cancelled = Cancellation::default();
    cancelled.cancel();
    assert!(matches!(
        image.query_program("tenant", &program, cancelled),
        Err(Error::Cancelled)
    ));
    assert_eq!(image.active_workers(), 0);
    assert!(image
        .query_program(
            "tenant",
            "[{\"function\":\"__getattribute__\",\"dependencies\":[],\"inputs\":[]}]",
            Cancellation::default()
        )
        .is_err());
}

#[test]
fn lexical_v3_image_declares_only_its_installed_resources() {
    use oracle_runtime_core::{build_image_with_reader, Image, ReaderBuildOptions};
    let directory = tempfile::tempdir().unwrap();
    let source = image_source(&directory);
    let destination = directory.path().join("v3.sqlite");
    let receipt = build_image_with_reader(
        &source,
        &destination,
        100_000,
        10_000,
        ReaderBuildOptions::default(),
    )
    .unwrap();
    assert_eq!(receipt.schema, "oracle-image-v3");
    assert_eq!(
        receipt.capabilities.lexicon.as_deref(),
        Some(lexicon::VERSION)
    );
    assert!(receipt.capabilities.reader.is_none());
    let image = Image::open(&destination, &receipt.image_sha256, Limits::default()).unwrap();
    assert_eq!(image.capabilities, receipt.capabilities);
    let program = json!([
        {"function":"Find","dependencies":[],"inputs":["Alice"]},
        {"function":"What","dependencies":[0],"inputs":[]}
    ])
    .to_string();
    let reply: serde_json::Value = serde_json::from_str(
        &image
            .query_program("tenant", &program, Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(reply["value"]["candidate"]["name"], "Alice");
    let db = Connection::open_with_flags(&destination, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
        .unwrap();
    let version: i64 = db
        .pragma_query_value(None, "user_version", |r| r.get(0))
        .unwrap();
    assert_eq!(version, 3);
    assert_eq!(
        read(&db, "ally", CandidateOptions::default()).spans[0].readings[0].canonical,
        "Ally"
    );
}

#[test]
fn reader_v3_image_installs_aliases_after_shared_grammar() {
    use oracle_runtime_core::{build_image_with_reader, Image, ReaderBuildOptions};
    let directory = tempfile::tempdir().unwrap();
    let source = image_source(&directory);
    let destination = directory.path().join("reader.sqlite");
    let export = reader_export(&source);
    let receipt = build_image_with_reader(
        &source,
        &destination,
        100_000,
        10_000,
        ReaderBuildOptions {
            reader: Some(&export),
            ..ReaderBuildOptions::default()
        },
    )
    .unwrap();
    assert_eq!(
        receipt.capabilities.reader.as_deref(),
        Some("oracle-reader-tables-v1")
    );
    let image = Image::open(&destination, &receipt.image_sha256, Limits::default()).unwrap();
    assert!(image.capabilities.reader.is_some());
    let db = Connection::open_with_flags(&destination, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
        .unwrap();
    let matches = read(&db, "the person", CandidateOptions::default());
    let alias = matches
        .spans
        .iter()
        .find(|s| s.start == 0 && s.end == 10)
        .unwrap();
    assert_eq!(alias.readings[0].canonical, "Alice");
    assert!(alias.readings[0].via_alias);
}

#[test]
fn image_open_rejects_missing_or_mismatched_declared_subformats() {
    use oracle_runtime_core::{build_image_with_reader, Image, ReaderBuildOptions};
    for mutation in [
        "DELETE FROM metadata WHERE key='image_capabilities'",
        "UPDATE metadata SET value='wrong' WHERE key='lexicon_version'",
        "UPDATE metadata SET value='{\"version\":99,\"lexicon\":\"oracle-lexicon-v1\",\"reader\":null}' WHERE key='image_capabilities'",
    ] {
        let directory = tempfile::tempdir().unwrap();
        let source = image_source(&directory);
        let destination = directory.path().join("wrong.sqlite");
        build_image_with_reader(&source,&destination,100_000,10_000,ReaderBuildOptions::default()).unwrap();
        let db = Connection::open(&destination).unwrap();
        db.execute(mutation,[]).unwrap();
        drop(db);
        assert!(matches!(Image::open(&destination,&image_digest(&destination),Limits::default()),Err(Error::Format(_))));
    }
}

#[test]
fn failed_reader_manufacturing_does_not_publish_an_image() {
    use oracle_runtime_core::{build_image_with_reader, ReaderBuildOptions};
    let directory = tempfile::tempdir().unwrap();
    let source = image_source(&directory);
    let destination = directory.path().join("incomplete.sqlite");
    let mut export = reader_export(&source);
    export.metadata.clear();
    assert!(matches!(
        build_image_with_reader(
            &source,
            &destination,
            100_000,
            10_000,
            ReaderBuildOptions {
                reader: Some(&export),
                ..ReaderBuildOptions::default()
            }
        ),
        Err(Error::Format(_))
    ));
    assert!(!destination.exists());
    assert!(matches!(
        build_image_with_reader(
            &source,
            &destination,
            100_000,
            10_000,
            ReaderBuildOptions {
                fuel: 1,
                ..ReaderBuildOptions::default()
            }
        ),
        Err(Error::Limit("fuel"))
    ));
    assert!(!destination.exists());
}

#[test]
fn reader_manufacturing_rejects_wrong_or_missing_source_bindings() {
    use oracle_runtime_core::{build_image_with_reader, ReaderBuildOptions};
    let directory = tempfile::tempdir().unwrap();
    let source = image_source(&directory);
    let destination = directory.path().join("wrong-binding.sqlite");
    let mut export = reader_export(&source);
    export.metadata.insert("kb_sha256".into(), json!("wrong"));
    assert!(matches!(
        build_image_with_reader(
            &source,
            &destination,
            100_000,
            10_000,
            ReaderBuildOptions {
                reader: Some(&export),
                ..ReaderBuildOptions::default()
            }
        ),
        Err(Error::Format(_))
    ));
    assert!(!destination.exists());
    export.metadata.remove("kb_sha256");
    export.metadata.remove("fixture");
    assert!(matches!(
        build_image_with_reader(
            &source,
            &destination,
            100_000,
            10_000,
            ReaderBuildOptions {
                reader: Some(&export),
                ..ReaderBuildOptions::default()
            }
        ),
        Err(Error::Format(_))
    ));
    assert!(!destination.exists());
    export
        .metadata
        .insert("kb_sha256".into(), json!(image_digest(&source)));
    assert!(build_image_with_reader(
        &source,
        &destination,
        100_000,
        10_000,
        ReaderBuildOptions {
            reader: Some(&export),
            ..ReaderBuildOptions::default()
        }
    )
    .is_ok());
}
