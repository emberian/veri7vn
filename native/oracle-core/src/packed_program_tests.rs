use super::*;
use crate::program::Program;
use crate::Cancellation;
use serde_json::json;

fn source(value: Value) -> OwnedPackedProgram {
    from_flat(serde_json::from_value(value).unwrap())
}
fn explicit_plan(source: &OwnedPackedProgram, limits: &Limits) -> crate::Plan {
    // The old flat compiler is intentionally retained as the independent
    // representation oracle in tests, never as a production packed fallback.
    let mut flat = Vec::new();
    source
        .visit_steps(&mut |step| {
            flat.push(grammar::Step {
                function: step.function.into(),
                inputs: step.inputs.into(),
                dependencies: step.dependencies.into(),
            });
            Ok(())
        })
        .unwrap();
    Program::from_reader(&flat, limits)
        .unwrap()
        .compile(limits)
        .unwrap()
}
fn view_plan(checked: &CheckedProgram) -> crate::Plan {
    crate::Plan {
        nodes: (0..checked.node_count())
            .map(|i| checked.node(i).into_owned())
            .collect(),
        output: checked.output(),
        projection: checked.projection().clone(),
    }
}

#[test]
fn checked_operations_preserve_exact_local_occurrences_and_scalar_lowerings() {
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let workspace = ProgramWorkspace::new(&limits, &budget);
    let cases = [
        json!([
            {"function":"Find","inputs":["unused"],"dependencies":[]},
            {"function":"Find","inputs":["A"],"dependencies":[]},
            {"function":"Find","inputs":["A"],"dependencies":[]},
            {"function":"Relate","inputs":["knows","forward"],"dependencies":[1]},
            {"function":"And","inputs":[],"dependencies":[2,3]},
            {"function":"What","inputs":[],"dependencies":[4]}
        ]),
        json!([
            {"function":"Find","inputs":["A"],"dependencies":[]},
            {"function":"QueryAttr","inputs":["height"],"dependencies":[0]},
            {"function":"VerifyNum","inputs":["10 metre",">"],"dependencies":[1]}
        ]),
        json!([
            {"function":"Find","inputs":["unused"],"dependencies":[]},
            {"function":"Find","inputs":["A"],"dependencies":[]},
            {"function":"Find","inputs":["B"],"dependencies":[]},
            {"function":"QueryRelationQualifier","inputs":["knows","since"],"dependencies":[1,2]},
            {"function":"VerifyYear","inputs":["2000","="],"dependencies":[3]}
        ]),
        json!([
            {"function":"FindAll","inputs":[],"dependencies":[]},
            {"function":"FilterNum","inputs":["height","10 metre",">"],"dependencies":[0]},
            {"function":"QFilterYear","inputs":["since","2001","="],"dependencies":[1]},
            {"function":"SelectBetween","inputs":["height","greater"],"dependencies":[0,2]}
        ]),
        json!([
            {"function":"Find","inputs":["A"],"dependencies":[]},
            {"function":"QueryAttrUnderCondition","inputs":["height","since","2000"],"dependencies":[0]}
        ]),
        json!([
            {"function":"Find","inputs":["A"],"dependencies":[]},
            {"function":"Find","inputs":["B"],"dependencies":[]},
            {"function":"QueryRelation","inputs":[],"dependencies":[1,0]}
        ]),
    ];
    for case in cases {
        let source = source(case);
        let checked = workspace
            .compile(PackedProgramRef::new(&source), CompileOrigin::Fragment)
            .unwrap()
            .unwrap();
        let old = explicit_plan(&source, &limits);
        let new = view_plan(&checked);
        assert_eq!(
            serde_json::to_value(&old).unwrap(),
            serde_json::to_value(&new).unwrap()
        );
        new.validate(&limits).unwrap();
    }
    assert_eq!(
        workspace.stats().materializations,
        0,
        "checking never constructs a flat diagnostic program"
    );
}

#[test]
fn duplicate_semantic_nodes_do_not_reduce_original_step_or_byte_admission() {
    let program = json!([
        {"function":"FindAll","inputs":[],"dependencies":[]},
        {"function":"FindAll","inputs":[],"dependencies":[]},
        {"function":"Count","inputs":[],"dependencies":[0]}
    ]);
    let source = source(program.clone());
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let workspace = ProgramWorkspace::new(&limits, &budget);
    let checked = workspace
        .compile(PackedProgramRef::new(&source), CompileOrigin::Fragment)
        .unwrap()
        .unwrap();
    assert_eq!(workspace.stats().lowered_operations, 2);
    assert_eq!(checked.node_count(), 2); // two original FindAll occurrences
    assert_eq!(checked.output(), 0); // Count refers to first, not most recent alias
    assert_eq!(
        source_bytes(PackedProgramRef::new(&source), usize::MAX).unwrap(),
        serde_json::to_string(&program).unwrap().len()
    );
    let small = Limits {
        plan_nodes: 2,
        ..limits.clone()
    };
    assert!(matches!(
        ProgramWorkspace::new(&small, &budget)
            .compile(PackedProgramRef::new(&source), CompileOrigin::Complete),
        Err(Error::Limit("reader program steps"))
    ));
    let small = Limits {
        request_bytes: serde_json::to_string(&program).unwrap().len() - 1,
        ..limits
    };
    assert!(matches!(
        ProgramWorkspace::new(&small, &budget)
            .compile(PackedProgramRef::new(&source), CompileOrigin::Complete),
        Err(Error::Limit(_))
    ));
    let again = workspace
        .compile(PackedProgramRef::new(&source), CompileOrigin::Complete)
        .unwrap()
        .unwrap();
    assert!(Arc::ptr_eq(&checked, &again));
    assert_eq!(workspace.stats().root_cache_hits, 1);
    assert_eq!(workspace.stats().materializations, 0);
}

#[test]
fn invalid_literal_and_dead_dependency_failures_are_cached_without_becoming_admitted() {
    let limits = Limits::default();
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let workspace = ProgramWorkspace::new(&limits, &budget);
    for program in [
        json!([
            {"function":"FindAll","inputs":[],"dependencies":[]},
            {"function":"FilterDate","inputs":["inflation","49.3 percentage","="],"dependencies":[0]},
            {"function":"Count","inputs":[],"dependencies":[0]}
        ]),
        json!([
            {"function":"FindAll","inputs":[],"dependencies":[]},
            {"function":"Count","inputs":[],"dependencies":[1]}
        ]),
        json!([
            {"function":"FindAll","inputs":[],"dependencies":[]},
            {"function":"Count","inputs":[],"dependencies":[0]},
            {"function":"FilterConcept","inputs":["person"],"dependencies":[1]}
        ]),
    ] {
        let source = source(program);
        assert!(workspace
            .compile(PackedProgramRef::new(&source), CompileOrigin::Fragment)
            .unwrap()
            .is_none());
        let validations = workspace.stats().syntax_specs;
        assert!(workspace
            .compile(PackedProgramRef::new(&source), CompileOrigin::Fragment)
            .unwrap()
            .is_none());
        assert_eq!(workspace.stats().syntax_specs, validations);
    }
    assert_eq!(workspace.stats().rejected_cache_hits, 3);
    assert_eq!(workspace.stats().materializations, 0);
}

#[test]
fn forty_nine_by_forty_nine_derivations_share_prefix_lowerings_not_occurrences() {
    let limits = Limits {
        fuel: 100_000_000,
        ..Limits::default()
    };
    let budget = Budget::new(&limits, Cancellation::default()).unwrap();
    let workspace = ProgramWorkspace::new(&limits, &budget);
    for left in 0..49 {
        for right in 0..49 {
            let source = source(json!([
                {"function":"FindAll","inputs":[],"dependencies":[]},
                {"function":"FilterConcept","inputs":[format!("left-{left}")],"dependencies":[0]},
                {"function":"FindAll","inputs":[],"dependencies":[]},
                {"function":"FilterConcept","inputs":[format!("right-{right}")],"dependencies":[2]},
                {"function":"And","inputs":[],"dependencies":[1,3]},
                {"function":"Count","inputs":[],"dependencies":[4]}
            ]));
            let root = workspace
                .compile(PackedProgramRef::new(&source), CompileOrigin::Fragment)
                .unwrap()
                .unwrap();
            assert_eq!(root.node_count(), 5);
        }
    }
    let stats = workspace.stats();
    assert_eq!(stats.fragment_checks, 2401);
    assert_eq!(stats.checked_roots, 2401);
    assert_eq!(stats.lowered_operations, 1 + 49 + 49 + 2401 + 2401);
    assert_eq!(stats.materializations, 0);
    assert_eq!(stats.fragment_materializations, 0);
    assert_eq!(stats.resident_roots, 2401);
    // An actually distinct 2,401-way conjunction is not pruned to the prefixes.
    assert!(stats.lowered_operations > 2401);
}

#[test]
fn root_recipe_reservation_outlives_workspace_and_diagnostics_expand_once() {
    let budget = Budget::new(&Limits::default(), Cancellation::default()).unwrap();
    let program: grammar::Program = serde_json::from_value(json!([
        {"function":"Find","inputs":["same"],"dependencies":[]},
        {"function":"Find","inputs":["same"],"dependencies":[]},
        {"function":"What","inputs":[],"dependencies":[0]}
    ]))
    .unwrap();
    let reservation = Arc::new(budget.reserve_memory(4096).unwrap());
    let source = from_flat_retained(program, reservation.clone());
    drop(reservation);
    let workspace = ProgramWorkspace::new(&Limits::default(), &budget);
    let root = workspace
        .compile(PackedProgramRef::new(&source), CompileOrigin::Fragment)
        .unwrap()
        .unwrap();
    let original = workspace.syntax(&root).unwrap();
    let repeated = workspace.syntax(&root).unwrap();
    assert!(original.ptr_eq(&repeated));
    assert_eq!(workspace.stats().materializations, 1);
    assert_eq!(original.len(), 3);
    assert_eq!(original[2].dependencies, vec![0]);
    drop(workspace);
    drop(source);
    assert!(budget.memory().snapshot().live >= 4096);
    drop(root);
    assert!(budget.memory().snapshot().live > 0); // expanded diagnostics own their guard
    drop(original);
    drop(repeated);
    assert_eq!(budget.memory().snapshot().live, 0);
}
