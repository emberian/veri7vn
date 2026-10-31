//! Representation-independent source truth for the checked-view seam.
use super::*;
use std::borrow::Cow;
use std::cell::Cell;
use std::sync::Arc;

/// A tiny stand-in for the producer's unique-operation arena. Its occurrence
/// order is explicit, and only dependency-bearing nodes need local rebasing.
struct Packed {
    unique: Vec<Node>,
    occurrences: Vec<usize>,
    first: Vec<usize>,
    output: usize,
    projection: Projection,
    accesses: Cell<usize>,
}
impl CheckedPlanView for Packed {
    fn node_count(&self) -> usize {
        self.occurrences.len()
    }
    fn node(&self, index: usize) -> Cow<'_, Node> {
        self.accesses.set(self.accesses.get() + 1);
        let node = &self.unique[self.occurrences[index]];
        match node {
            Node::And { left, right } => Cow::Owned(Node::And {
                left: self.first[*left],
                right: self.first[*right],
            }),
            Node::Or { left, right } => Cow::Owned(Node::Or {
                left: self.first[*left],
                right: self.first[*right],
            }),
            Node::Relate {
                input,
                predicate,
                direction,
            } => Cow::Owned(Node::Relate {
                input: self.first[*input],
                predicate: predicate.clone(),
                direction: direction.clone(),
            }),
            _ => Cow::Borrowed(node),
        }
    }
    fn output(&self) -> usize {
        self.output
    }
    fn projection(&self) -> &Projection {
        &self.projection
    }
}
fn fixture() -> (tempfile::TempDir, Arc<crate::Image>) {
    let directory = tempfile::tempdir().unwrap();
    let source = directory.path().join("source.json");
    let destination = directory.path().join("image.sqlite");
    std::fs::write(&source,serde_json::json!({"concepts":{},"entities":{
        "A":{"name":"Alice","instanceOf":[],"attributes":[],"relations":[{"predicate":"knows","direction":"forward","object":"B","qualifiers":{"since":[{"type":"year","value":2000}]}}]},
        "B":{"name":"Bob","instanceOf":[],"attributes":[],"relations":[]}
    }}).to_string()).unwrap();
    let receipt = crate::build_image(&source, &destination, 1_000_000, 100_000).unwrap();
    let image = crate::Image::open(&destination, &receipt.image_sha256, Limits::default()).unwrap();
    (directory, image)
}
fn run(
    image: &crate::Image,
    view: &dyn CheckedPlanView,
    demand: Demand,
    previous: &Selection,
) -> Result<Option<Delivered>> {
    let budget = Budget::new(&image.limits, crate::Cancellation::default())?;
    let worker = image.acquire("packed-test", &budget)?;
    let mut shared = LanguageWorkspace::new(&worker)?;
    evaluate_language_packed(
        &worker,
        image.verified_identity(),
        view,
        previous,
        &image.limits,
        &budget,
        &mut shared,
        demand,
    )
}
#[test]
fn packed_view_rebases_one_node_and_preserves_duplicate_occurrence_truth() {
    let (_directory, image) = fixture();
    let view = Packed {
        unique: vec![
            Node::Find {
                name: "Alice".into(),
            },
            Node::Find { name: "Bob".into() },
            Node::Or { left: 0, right: 1 },
        ],
        occurrences: vec![0, 0, 1, 2],
        first: vec![0, 2, 3],
        output: 3,
        projection: Projection::Entities,
        accesses: Cell::new(0),
    };
    let reference = Plan {
        nodes: vec![
            Node::Find {
                name: "Alice".into(),
            },
            Node::Find {
                name: "Alice".into(),
            },
            Node::Find { name: "Bob".into() },
            Node::Or { left: 0, right: 2 },
        ],
        output: 3,
        projection: Projection::Entities,
    };
    reference.validate(&image.limits).unwrap();
    let Some(Delivered::Full(actual, selected)) =
        run(&image, &view, Demand::Full, &Selection::default()).unwrap()
    else {
        panic!("full")
    };
    let Some(Delivered::Full(expected, expected_selection)) =
        run(&image, &reference, Demand::Full, &Selection::default()).unwrap()
    else {
        panic!("full")
    };
    assert_eq!(
        serde_json::to_value(actual).unwrap(),
        serde_json::to_value(expected).unwrap()
    );
    assert_eq!(selected, expected_selection);
    assert_eq!(selected.ids, BTreeSet::from(["A".into(), "B".into()]));
    assert!(view.accesses.get() >= view.node_count());
    assert!(matches!(
        run(&image, &view, Demand::Count, &Selection::default()).unwrap(),
        Some(Delivered::Count(2))
    ));
    assert_eq!(image.active_workers(), 0);
}
#[test]
fn packed_dead_empty_stage_refuses_scalar_but_count_projection_keeps_exception() {
    let (_directory, image) = fixture();
    let mut view = Packed {
        unique: vec![
            Node::Find {
                name: "Missing".into(),
            },
            Node::Find {
                name: "Alice".into(),
            },
        ],
        occurrences: vec![0, 1],
        first: vec![0, 1],
        output: 1,
        projection: Projection::Entities,
        accesses: Cell::new(0),
    };
    assert!(run(&image, &view, Demand::Exists, &Selection::default())
        .unwrap()
        .is_none());
    view.projection = Projection::Count;
    assert!(matches!(
        run(&image, &view, Demand::Count, &Selection::default()).unwrap(),
        Some(Delivered::Count(1))
    ));
    view.output = 0;
    assert!(matches!(
        run(&image, &view, Demand::Count, &Selection::default()).unwrap(),
        Some(Delivered::Count(0))
    ));
}
#[test]
fn packed_relation_retains_statement_witness_and_previous_scope() {
    let (_directory, image) = fixture();
    let view = Packed {
        unique: vec![
            Node::Previous,
            Node::Relate {
                input: 0,
                predicate: "knows".into(),
                direction: "forward".into(),
            },
        ],
        occurrences: vec![0, 1],
        first: vec![0, 1],
        output: 1,
        projection: Projection::Entities,
        accesses: Cell::new(0),
    };
    let previous = Selection {
        ids: BTreeSet::from(["A".into()]),
        ..Selection::default()
    };
    let Some(Delivered::Full(reply, selected)) =
        run(&image, &view, Demand::Full, &previous).unwrap()
    else {
        panic!("full")
    };
    assert_eq!(reply.entities, ["B"]);
    assert_eq!(selected.facts.len(), 1);
    assert_eq!(
        serde_json::from_str::<Value>(&reply.facts[0].qualifiers_json).unwrap()["since"][0]
            ["value"],
        2000
    );
    // A new Previous snapshot gets a fresh workspace/lease, so no old answer.
    assert!(run(&image, &view, Demand::Full, &Selection::default())
        .unwrap()
        .is_none());
}

fn checked_root(
    workspace: &crate::packed_program::ProgramWorkspace,
    wire: Value,
) -> Arc<crate::packed_program::CheckedProgram> {
    let source = crate::packed_program::from_flat(serde_json::from_value(wire).unwrap());
    workspace
        .compile(
            crate::packed_program::PackedProgramRef::new(&source),
            crate::packed_program::CompileOrigin::Whole,
        )
        .unwrap()
        .unwrap()
}

#[test]
fn checked_stage_reuse_skips_encoding_and_sql_construction_preserving_witnesses() {
    let (_directory, image) = fixture();
    let cancellation = crate::Cancellation::default();
    let budget = Budget::new(&image.limits, cancellation.clone()).unwrap();
    let programs = crate::packed_program::ProgramWorkspace::new(&image.limits, &budget);
    let root = checked_root(
        &programs,
        json!([
            {"function":"Find","inputs":["Alice"],"dependencies":[]},
            {"function":"Find","inputs":["Alice"],"dependencies":[]},
            {"function":"Relate","inputs":["knows","forward"],"dependencies":[1]}
        ]),
    );
    let worker = image.acquire("stable-stage", &budget).unwrap();
    let mut shared = LanguageWorkspace::new(&worker).unwrap();
    let previous = Selection::default();
    let execute = |shared: &mut LanguageWorkspace| {
        evaluate_language_packed(
            &worker,
            image.verified_identity(),
            root.as_ref(),
            &previous,
            &image.limits,
            &budget,
            shared,
            Demand::Full,
        )
    };
    let first = execute(&mut shared).unwrap().unwrap().into_full().unwrap();
    assert_eq!(shared.stage_costs(), (1, 0, 2, 3));
    let retained = (shared.retained_rows, shared.retained_bytes);
    let stage_storage = shared.stage_storage();
    let second = execute(&mut shared).unwrap().unwrap().into_full().unwrap();
    assert_eq!(first, second);
    assert_eq!(second.1.facts.len(), 1);
    assert_eq!(shared.stage_costs(), (4, 0, 2, 3));
    assert_eq!((shared.retained_rows, shared.retained_bytes), retained);
    assert_eq!(shared.stage_storage(), stage_storage);
    cancellation.cancel();
    assert!(matches!(execute(&mut shared), Err(Error::Cancelled)));
    assert_eq!(shared.stage_costs(), (4, 0, 2, 3));
}

#[test]
fn checked_stage_ids_do_not_collide_between_program_workspaces_or_previous() {
    let (_directory, image) = fixture();
    let budget = Budget::new(&image.limits, crate::Cancellation::default()).unwrap();
    let first_workspace = crate::packed_program::ProgramWorkspace::new(&image.limits, &budget);
    let second_workspace = crate::packed_program::ProgramWorkspace::new(&image.limits, &budget);
    let alice = checked_root(
        &first_workspace,
        json!([{"function":"Find","inputs":["Alice"],"dependencies":[]}]),
    );
    let bob = checked_root(
        &second_workspace,
        json!([{"function":"Find","inputs":["Bob"],"dependencies":[]}]),
    );
    let worker = image.acquire("stable-collision", &budget).unwrap();
    let mut shared = LanguageWorkspace::new(&worker).unwrap();
    let previous = Selection::default();
    for (root, expected) in [(&alice, "A"), (&bob, "B"), (&bob, "B"), (&alice, "A")] {
        let selected = evaluate_language_packed(
            &worker,
            image.verified_identity(),
            root.as_ref(),
            &previous,
            &image.limits,
            &budget,
            &mut shared,
            Demand::Full,
        )
        .unwrap()
        .unwrap()
        .into_full()
        .unwrap()
        .1;
        assert_eq!(selected.ids, BTreeSet::from([expected.to_owned()]));
    }
    assert_eq!(shared.stage_costs(), (2, 0, 2, 2));
    let changed = Selection {
        ids: BTreeSet::from(["B".into()]),
        ..Selection::default()
    };
    assert!(matches!(
        evaluate_language_packed(
            &worker,
            image.verified_identity(),
            alice.as_ref(),
            &changed,
            &image.limits,
            &budget,
            &mut shared,
            Demand::Full
        ),
        Err(Error::Invalid(_))
    ));
    assert!(matches!(
        evaluate_language_packed(
            &worker,
            "different-image",
            alice.as_ref(),
            &previous,
            &image.limits,
            &budget,
            &mut shared,
            Demand::Full
        ),
        Err(Error::Invalid(_))
    ));
}

#[test]
fn stage_insert_metadata_counts_successful_duplicates_and_utf8_bytes() {
    let (_directory, image) = fixture();
    let budget = Budget::new(&image.limits, crate::Cancellation::default()).unwrap();
    let worker = image.acquire("insert-metadata", &budget).unwrap();
    let mut shared = LanguageWorkspace::new(&worker).unwrap();
    let mut meter = Meter {
        stage_rows: 0,
        stage_bytes: 0,
        rows: 0,
        bytes: 0,
        limits: &image.limits,
        budget: &budget,
    };
    insert_id(&worker, 0, "é", &mut meter).unwrap();
    insert_id(&worker, 0, "é", &mut meter).unwrap();
    let attribute = AttributeFact {
        subject: "é".into(),
        key: "色".into(),
        position: 7,
        value_json: r#"{"type":"string","value":"青"}"#.into(),
        qualifiers_json: "{}".into(),
    };
    insert_attribute(&worker, 0, &attribute, &mut meter).unwrap();
    insert_attribute(&worker, 0, &attribute, &mut meter).unwrap();
    assert_eq!(
        (meter.stage_rows, meter.stage_bytes),
        (2, "é".len() + attribute_bytes(&attribute))
    );
    shared
        .retain(
            &worker,
            StageKey::Checked(CheckedStageId {
                workspace: 0,
                operation: 0,
            }),
            0,
            true,
            &meter,
        )
        .unwrap();
    assert_eq!(shared.retained_rows, 2);
    assert_eq!(
        shared.retained_bytes,
        "é".len() + attribute_bytes(&attribute) + std::mem::size_of::<CheckedStageId>() + 64
    );
}
