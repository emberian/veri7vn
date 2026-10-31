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

fn recipe(entries: Vec<RecipeEntry>, count: usize) -> Recipe {
    Recipe {
        _memory: memory(),
        admission: AdmissionSummary::for_entries(&entries, count).unwrap(),
        entries: entries.into(),
        count,
    }
}

fn operation(identity: u32, function: &str, dependencies: &[usize]) -> RecipeEntry {
    RecipeEntry::Operation(RecipeOperation {
        step: Arc::new(
            RawStep::new(
                function,
                &[],
                serde_json::to_string(&(function, Vec::<Value>::new())).unwrap(),
            )
            .unwrap(),
        ),
        identity,
        dependencies: dependencies.into(),
    })
}
fn source() -> Arc<Recipe> {
    Arc::new(recipe(
        vec![
            operation(0, "FindAll", &[]),
            operation(1, "FilterConcept", &[0]),
        ],
        2,
    ))
}

#[test]
fn packed_recipe_repeated_child_keeps_occurrences_and_exact_dependencies() {
    let child = source();
    let root = recipe(
        vec![
            RecipeEntry::Child {
                start: 0,
                program: child.clone(),
            },
            RecipeEntry::Child {
                start: 2,
                program: child.clone(),
            },
            operation(2, "And", &[1, 3]),
        ],
        5,
    );
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
    let packed = recipe(
        vec![
            RecipeEntry::Child {
                start: 0,
                program: child,
            },
            operation(2, "Count", &[1]),
        ],
        3,
    );
    let direct = recipe(
        vec![
            operation(0, "FindAll", &[]),
            operation(1, "FilterConcept", &[0]),
            operation(2, "Count", &[1]),
        ],
        3,
    );
    assert!(packed.same_content(&direct));
    assert_eq!(packed.fingerprint(), direct.fingerprint());
    assert_eq!(
        assert_admission(Arc::new(packed)),
        assert_admission(Arc::new(direct))
    );
}

#[test]
fn packed_recipe_unused_occurrence_is_not_removed_by_root_sharing() {
    let root = recipe(
        vec![
            operation(0, "FindAll", &[]),
            operation(3, "Unsupported", &[]),
            operation(2, "Count", &[0]),
        ],
        3,
    );
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
            false,
            &mut BTreeMap::new(),
            &mut |source: PackedProgramRef<'_>, _allow_empty: bool| {
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
    chart.limits.steps = 5;
    let accepted = chart
        .splice(&skeleton, &BTreeMap::from([(1, child)]))
        .unwrap()
        .unwrap();
    assert_eq!(chart.source(accepted).step_count(), 5);
    chart.limits.steps = 4;
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

// Independent oracle: serialize expanded public Steps, never the summary or its
// histogram. Escapes, commas and decimal index widths are serde's responsibility.
fn assert_admission(root: Arc<Recipe>) -> usize {
    let mut expanded = Vec::new();
    root.visit_steps(&mut |step| {
        expanded.push(Step {
            function: step.function.into(),
            inputs: step.inputs.into(),
            dependencies: step.dependencies.into(),
        });
        Ok(())
    })
    .unwrap();
    let expected = serde_json::to_vec(&expanded).unwrap().len();
    assert_eq!(root.admission.bytes, expected);
    let source: OwnedPackedProgram = root;
    let source = PackedProgramRef::new(&source);
    assert_eq!(
        crate::packed_program::source_bytes(source, expected).unwrap(),
        expected
    );
    assert!(matches!(
        crate::packed_program::source_bytes(source, expected - 1),
        Err(Error::Limit(_))
    ));
    expected
}

#[test]
fn packed_recipe_exact_admission_rebases_decimal_widths_and_unicode() {
    let inputs = vec![
        Value::String("雪\n\"\\\u{0001}é".into()),
        serde_json::json!({"nested": [false, 12]}),
    ];
    let raw = Arc::new(
        RawStep::new(
            "Filter\"Unicode",
            &inputs,
            serde_json::to_string(&("Filter\"Unicode", &inputs)).unwrap(),
        )
        .unwrap(),
    );
    let child = Arc::new(recipe(
        vec![
            operation(0, "FindAll", &[]),
            RecipeEntry::Operation(RecipeOperation {
                step: raw,
                identity: 1,
                dependencies: vec![0, 0].into(),
            }),
        ],
        2,
    ));
    for start in [0, 9, 10, 99, 100] {
        let mut entries = (0..start)
            .map(|_| operation(0, "FindAll", &[]))
            .collect::<Vec<_>>();
        entries.push(RecipeEntry::Child {
            start,
            program: child.clone(),
        });
        entries.push(RecipeEntry::Child {
            start: start + 2,
            program: child.clone(),
        });
        // Dead and repeated occurrences still contribute bytes.
        entries.push(operation(2, "Unsupported", &[]));
        entries.push(operation(3, "Count", &[start + 1]));
        let root = Arc::new(recipe(entries, start + 6));
        assert_admission(root.clone());
        let nested = Arc::new(recipe(
            vec![RecipeEntry::Child {
                start: 0,
                program: root.clone(),
            }],
            root.count,
        ));
        assert_eq!(assert_admission(nested), root.admission.bytes);
    }
    assert_admission(Arc::new(recipe(vec![], 0)));
}

#[test]
fn packed_recipe_cached_rejection_still_checks_exact_admission() {
    let root = Arc::new(recipe(vec![operation(7, "Unsupported", &[])], 1));
    let bytes = assert_admission(root.clone());
    let source: OwnedPackedProgram = root;
    let source = PackedProgramRef::new(&source);
    let mut limits = crate::Limits::default();
    limits.request_bytes = bytes;
    let budget = Budget::new(&limits, crate::Cancellation::default()).unwrap();
    let workspace = crate::packed_program::ProgramWorkspace::new(&limits, &budget);
    for _ in 0..2 {
        assert!(workspace
            .compile(source, crate::packed_program::CompileOrigin::Fragment)
            .unwrap()
            .is_none());
    }
    assert_eq!(workspace.stats().rejected_cache_hits, 1);
    limits.request_bytes = bytes - 1;
    let constrained = crate::packed_program::ProgramWorkspace::new(&limits, &budget);
    assert!(matches!(
        constrained.compile(source, crate::packed_program::CompileOrigin::Fragment),
        Err(Error::Limit(_))
    ));
}

#[test]
fn packed_recipe_admission_uses_summary_without_visiting_occurrences() {
    struct SummaryOnly(Arc<Recipe>);
    impl PackedProgramSource for SummaryOnly {
        fn step_count(&self) -> usize {
            self.0.count
        }
        fn admission_bytes(&self) -> Option<usize> {
            self.0.admission_bytes()
        }
        fn visit_steps(&self, _: &mut dyn FnMut(PackedStep<'_>) -> Result<()>) -> Result<()> {
            panic!("cached admission traversed or serialized occurrences")
        }
    }
    let root = source();
    let expected = assert_admission(root.clone());
    let source: OwnedPackedProgram = Arc::new(SummaryOnly(root));
    let source = PackedProgramRef::new(&source);
    for _ in 0..3 {
        assert_eq!(
            crate::packed_program::source_bytes(source, expected).unwrap(),
            expected
        );
        assert!(matches!(
            crate::packed_program::source_bytes(source, expected - 1),
            Err(Error::Limit(_))
        ));
    }
}

#[test]
fn packed_recipe_dependency_admission_includes_dead_and_nested_steps() {
    let invalid = Arc::new(recipe(
        vec![
            operation(0, "FindAll", &[]),
            operation(1, "Unsupported", &[1]),
        ],
        2,
    ));
    assert!(!invalid.admission.dependencies_valid);
    let nested = recipe(
        vec![RecipeEntry::Child {
            start: 0,
            program: invalid,
        }],
        2,
    );
    assert!(!nested.admission.dependencies_valid);
    let valid = recipe(
        vec![
            operation(0, "FindAll", &[]),
            operation(1, "Unsupported", &[0]),
        ],
        2,
    );
    assert!(valid.admission.dependencies_valid);
}
