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
