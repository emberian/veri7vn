//! Representation checks: these inspect the production chart source visitor,
//! without compiling/evaluating a question or requesting flat diagnostics.
use super::*;
fn memory() -> SharedChartMemory {
    Arc::new(Mutex::new(
        crate::budget::MemoryBudget::new(1 << 20)
            .reserve(0)
            .unwrap(),
    ))
}

fn operation(identity: u32, function: &str, dependencies: &[usize]) -> RecipeEntry {
    RecipeEntry::Operation(RecipeOperation {
        step: Arc::new((function.into(), vec![])),
        identity,
        dependencies: dependencies.into(),
    })
}
fn source() -> Arc<Recipe> {
    Arc::new(Recipe {
        _memory: memory(),
        entries: vec![
            operation(0, "FindAll", &[]),
            operation(1, "FilterConcept", &[0]),
        ]
        .into(),
        count: 2,
    })
}

#[test]
fn packed_recipe_repeated_child_keeps_occurrences_and_exact_dependencies() {
    let child = source();
    let root = Recipe {
        _memory: memory(),
        entries: vec![
            RecipeEntry::Child {
                start: 0,
                program: child.clone(),
            },
            RecipeEntry::Child {
                start: 2,
                program: child.clone(),
            },
            operation(2, "And", &[1, 3]),
        ]
        .into(),
        count: 5,
    };
    let mut visits = Vec::new();
    root.visit_steps(&mut |step| {
        visits.push((step.function.to_owned(), step.dependencies.to_vec()));
        Ok(())
    })
    .unwrap();
    assert_eq!(root.step_count(), 5); // two shared raw operations, five occurrences
    assert_eq!(
        visits,
        vec![
            ("FindAll".into(), vec![]),
            ("FilterConcept".into(), vec![0]),
            ("FindAll".into(), vec![]),
            ("FilterConcept".into(), vec![2]),
            ("And".into(), vec![1, 3]),
        ]
    );
    let RecipeEntry::Child { program: left, .. } = &root.entries[0] else {
        panic!()
    };
    let RecipeEntry::Child { program: right, .. } = &root.entries[1] else {
        panic!()
    };
    assert!(Arc::ptr_eq(left, right));
}

#[test]
fn packed_recipe_partition_does_not_change_exact_syntax_identity() {
    let child = source();
    let packed = Recipe {
        _memory: memory(),
        entries: vec![
            RecipeEntry::Child {
                start: 0,
                program: child,
            },
            operation(2, "Count", &[1]),
        ]
        .into(),
        count: 3,
    };
    let direct = Recipe {
        _memory: memory(),
        entries: vec![
            operation(0, "FindAll", &[]),
            operation(1, "FilterConcept", &[0]),
            operation(2, "Count", &[1]),
        ]
        .into(),
        count: 3,
    };
    assert!(packed.same_content(&direct));
    assert_eq!(packed.fingerprint(), direct.fingerprint());
}

#[test]
fn packed_recipe_unused_occurrence_is_not_removed_by_root_sharing() {
    let root = Recipe {
        _memory: memory(),
        entries: vec![
            operation(0, "FindAll", &[]),
            operation(3, "Unsupported", &[]),
            operation(2, "Count", &[0]),
        ]
        .into(),
        count: 3,
    };
    let mut functions = Vec::new();
    root.visit_steps(&mut |step| {
        functions.push(step.function.to_owned());
        Ok(())
    })
    .unwrap();
    assert_eq!(functions, ["FindAll", "Unsupported", "Count"]);
    assert_eq!(root.step_count(), 3);
}

#[test]
fn packed_chart_callback_error_keeps_source_memory_without_flat_diagnostics() {
    let limits = crate::Limits::default();
    let budget = Budget::new(&limits, crate::Cancellation::default()).unwrap();
    let db = Connection::open_in_memory().unwrap();
    let policy = ReaderPolicy::default();
    let mut held = None;
    let before = DIAGNOSTIC_PROGRAMS.with(|count| count.get());
    {
        let mut ledger = Ledger::new(1 << 20, &budget).unwrap();
        let mut chart = Chart::new(
            &db,
            "",
            &[],
            0,
            &policy,
            MatchLimits::default(),
            &budget,
            &mut ledger,
            0,
        )
        .unwrap();
        let root = chart
            .intern(&vec![Step {
                function: "FindAll".into(),
                dependencies: vec![],
                inputs: vec![],
            }])
            .unwrap();
        let result = chart.check(
            root,
            &mut BTreeMap::new(),
            &mut |source: PackedProgramRef<'_>| {
                held = Some(source.owned());
                Err(Error::Invalid("injected callback error".into()))
            },
        );
        assert!(matches!(result, Err(Error::Invalid(_))));
    }
    assert!(budget.memory().snapshot().live > 0);
    assert_eq!(DIAGNOSTIC_PROGRAMS.with(|count| count.get()), before);
    drop(held);
    assert_eq!(budget.memory().snapshot().live, 0);
}

#[test]
fn packed_chart_repeated_child_cannot_evade_original_step_limit() {
    let limits = crate::Limits::default();
    let budget = Budget::new(&limits, crate::Cancellation::default()).unwrap();
    let db = Connection::open_in_memory().unwrap();
    let policy = ReaderPolicy::default();
    let mut ledger = Ledger::new(1 << 20, &budget).unwrap();
    let match_limits = MatchLimits {
        steps: 3,
        ..MatchLimits::default()
    };
    let mut chart = Chart::new(
        &db,
        "",
        &[],
        0,
        &policy,
        match_limits,
        &budget,
        &mut ledger,
        0,
    )
    .unwrap();
    let child = chart
        .intern(&vec![
            Step {
                function: "FindAll".into(),
                dependencies: vec![],
                inputs: vec![],
            },
            Step {
                function: "FilterConcept".into(),
                dependencies: vec![0],
                inputs: vec![Value::String("person".into())],
            },
        ])
        .unwrap();
    let skeleton = vec![
        Step {
            function: "@X".into(),
            dependencies: vec![],
            inputs: vec![Value::from(1)],
        },
        Step {
            function: "@X".into(),
            dependencies: vec![],
            inputs: vec![Value::from(1)],
        },
        Step {
            function: "And".into(),
            dependencies: vec![0, 1],
            inputs: vec![],
        },
    ];
    assert!(matches!(
        chart.splice(&skeleton, &BTreeMap::from([(1, child)])),
        Err(Error::Limit("reader program steps"))
    ));
}

#[test]
fn bound_recipe_matches_singleton_x_diagnostics_without_splicing_children() {
    let skeleton = vec![
        Step {
            function: "@NOP".into(),
            dependencies: vec![],
            inputs: vec![],
        },
        Step {
            function: "@X".into(),
            dependencies: vec![],
            inputs: vec![Value::from(1)],
        },
        Step {
            function: "FilterNum".into(),
            dependencies: vec![1],
            inputs: vec![
                Value::String("mass".into()),
                serde_json::json!(["@", "N", 1, "kg"]),
                Value::String("=".into()),
            ],
        },
    ];
    let texts = Bindings::from([(('N', 1), "2".into())]);
    let bound = grammar::bind_recipe(&skeleton, &texts, &BTreeMap::from([(1, 7)]), 3)
        .unwrap()
        .unwrap();
    let singleton = vec![Step {
        function: "@X".into(),
        dependencies: vec![],
        inputs: vec![Value::from(7)],
    }];
    let old = grammar::expand(&skeleton, &texts, &BTreeMap::from([(1, singleton)]), 3)
        .unwrap()
        .unwrap();
    assert_eq!(bound, old);
    assert_eq!(bound[1].inputs[1], Value::String("2 kg".into()));
}

#[test]
fn empty_packed_batch_does_not_pin_chart_or_release_escaped_callback_source() {
    let db = Connection::open_in_memory().unwrap();
    db.execute_batch("CREATE TABLE reader_template(family TEXT,level INTEGER,template TEXT,skeleton TEXT,support INTEGER, PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;").unwrap();
    let fragment =
        serde_json::json!([{"function":"Find","dependencies":[],"inputs":[["@","E",1,""]]}]);
    let outer = serde_json::json!([
        {"function":"@X","dependencies":[],"inputs":[1]},
        {"function":"Count","dependencies":[0],"inputs":[]}
    ]);
    db.execute(
        "INSERT INTO reader_template VALUES ('fragment',0,'E1',?1,3)",
        [fragment.to_string()],
    )
    .unwrap();
    db.execute(
        "INSERT INTO reader_template VALUES ('outer',0,'how many X1',?1,3)",
        [outer.to_string()],
    )
    .unwrap();
    let limits = crate::Limits::default();
    let budget = Budget::new(&limits, crate::Cancellation::default()).unwrap();
    let question = "how many alice";
    let spans = [GrammarSpan {
        start: 9,
        end: 14,
        kind: 'E',
        canonical: "Alice".into(),
    }];
    let mut held = None;
    let batch = crate::composition::match_composed_packed(
        &db,
        question,
        &spans,
        &[],
        0,
        &ReaderPolicy::default(),
        MatchLimits::default(),
        &budget,
        |source| {
            held = Some(source.owned());
            Ok(false)
        },
    )
    .unwrap();
    let (programs, empty_batch_memory) = batch.into_parts();
    assert!(programs.is_empty());
    assert!(held.is_some());
    assert_eq!(empty_batch_memory.lock().unwrap().bytes(), 0);
    assert!(budget.memory().snapshot().live > 0);
    drop(held);
    // The empty returned batch remains alive, but owns no retired chart data.
    assert_eq!(budget.memory().snapshot().live, 0);
    drop(empty_batch_memory);
}
