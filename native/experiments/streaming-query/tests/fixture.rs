//! Hand-traced cases from the README, one test each. Expectations were written
//! by hand before the code ran; they check the prototype against itself, not
//! against SQLite or any measurement.
use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, Instant},
};
use streaming_query_spike::*;

fn e(n: u32) -> Entity {
    Entity(n)
}
fn context() -> Context {
    Context::new(
        100_000,
        1_000_000,
        Instant::now() + Duration::from_secs(10),
        Arc::new(AtomicBool::new(false)),
    )
}
fn edge(subject: u32, object: u32, evidence: u32) -> Edge {
    Edge {
        subject: e(subject),
        predicate: Predicate(7),
        object: e(object),
        evidence: Statement(evidence),
    }
}
fn image() -> Arc<Image> {
    Arc::new(
        Image::authored(
            42,
            vec![
                (0, vec![e(1), e(2), e(4), e(9)]),
                (1, vec![e(2), e(3), e(4)]),
                (2, vec![]),
            ],
            vec![edge(2, 9, 0), edge(2, 9, 1), edge(4, 3, 2)],
        )
        .unwrap(),
    )
}
fn drain<S: SetPull>(mut s: S, cx: &mut Context) -> Vec<u32> {
    let mut out = Vec::new();
    while let Some(Entity(n)) = s.next(cx).unwrap() {
        out.push(n);
    }
    out
}

#[test]
fn intersection_is_two_and_four() {
    let (image, mut cx) = (image(), context());
    let m = Merge::intersection(image.scan(0).unwrap(), image.scan(1).unwrap()).unwrap();
    assert_eq!(drain(m, &mut cx), vec![2, 4]);
}

#[test]
fn union_advances_equal_heads_once() {
    let (image, mut cx) = (image(), context());
    let m = Merge::union(image.scan(0).unwrap(), image.scan(1).unwrap()).unwrap();
    assert_eq!(drain(m, &mut cx), vec![1, 2, 3, 4, 9]);
}

#[test]
fn materialized_result_gives_independent_cursors() {
    let (image, mut cx) = (image(), context());
    let shared = Materialized::fill(
        Merge::intersection(image.scan(0).unwrap(), image.scan(1).unwrap()).unwrap(),
        &mut cx,
    )
    .unwrap();
    assert_eq!(drain(shared.scan(), &mut cx), vec![2, 4]);
    assert_eq!(drain(shared.scan(), &mut cx), vec![2, 4]);
    assert_eq!(count(shared.scan(), &mut cx).unwrap().relative_to_image, 2);
}

#[test]
fn parallel_edges_keep_three_witnesses_and_two_objects() {
    let (image, mut cx) = (image(), context());
    let shared = Materialized::fill(
        Merge::intersection(image.scan(0).unwrap(), image.scan(1).unwrap()).unwrap(),
        &mut cx,
    )
    .unwrap();
    let result = Relate::new(image.clone(), shared.scan(), Predicate(7))
        .unwrap()
        .materialize_objects(&mut cx)
        .unwrap();
    assert_eq!(result.witnesses.len(), 3);
    let mut evidence: Vec<u32> = result.witnesses.iter().map(|w| w.evidence.0).collect();
    evidence.sort();
    assert_eq!(evidence, vec![0, 1, 2]);
    assert_eq!(drain(result.entities.scan(), &mut cx), vec![3, 9]);
}

#[test]
fn boundaries_split_first_posting_into_four_singletons() {
    let (image, mut cx) = (image(), context());
    let parts = partition(&image.scan(0).unwrap(), &[e(2), e(4), e(8)], &mut cx).unwrap();
    let got: Vec<Vec<u32>> = parts.into_iter().map(|p| drain(p, &mut cx)).collect();
    assert_eq!(got, vec![vec![1], vec![2], vec![4], vec![9]]);
    let parts = partition(&image.scan(0).unwrap(), &[e(2), e(4), e(8)], &mut cx).unwrap();
    let all = Concat::ordered_disjoint(parts).unwrap();
    assert_eq!(drain(all, &mut cx), vec![1, 2, 4, 9]);
}

#[test]
fn empty_posting_counts_zero_and_is_uniqueness_empty() {
    let (image, mut cx) = (image(), context());
    assert_eq!(
        count(image.scan(2).unwrap(), &mut cx)
            .unwrap()
            .relative_to_image,
        0
    );
    assert_eq!(
        unique(image.scan(2).unwrap(), &mut cx).unwrap().value,
        Uniqueness::Empty
    );
}

#[test]
fn uniqueness_refutes_after_two_ids() {
    let (image, mut cx) = (image(), context());
    assert_eq!(
        unique(image.scan(0).unwrap(), &mut cx).unwrap().value,
        Uniqueness::Multiple
    );
    let one = Image::authored(1, vec![(0, vec![e(5)])], vec![]).unwrap();
    assert_eq!(
        unique(one.scan(0).unwrap(), &mut cx).unwrap().value,
        Uniqueness::One(e(5))
    );
}

#[test]
fn separately_built_images_never_mix() {
    let (image, mut cx) = (image(), context());
    let shared = Materialized::fill(image.scan(0).unwrap(), &mut cx).unwrap();
    let other = Arc::new(Image::authored(42, vec![(0, vec![e(2)])], vec![]).unwrap());
    assert!(matches!(
        Merge::intersection(image.scan(0).unwrap(), other.scan(0).unwrap()),
        Err(Error::Snapshot)
    ));
    assert!(matches!(
        Merge::union(shared.scan(), other.scan(0).unwrap()),
        Err(Error::Snapshot)
    ));
    assert!(matches!(
        Relate::new(other.clone(), shared.scan(), Predicate(7)),
        Err(Error::Snapshot)
    ));
    assert!(matches!(
        Concat::ordered_disjoint(vec![image.scan(2).unwrap(), other.scan(0).unwrap()]),
        Err(Error::Snapshot)
    ));
    assert_eq!(
        count(shared.scan(), &mut cx).unwrap().scope.release_label(),
        42
    );
}

#[test]
fn cancellation_on_empty_scan_is_cancelled() {
    let image = image();
    let cancel = Arc::new(AtomicBool::new(false));
    let mut cx = Context::new(
        100,
        1000,
        Instant::now() + Duration::from_secs(10),
        cancel.clone(),
    );
    cancel.store(true, Ordering::Relaxed);
    assert_eq!(
        count(image.scan(2).unwrap(), &mut cx),
        Err(Error::Cancelled)
    );
}

#[test]
fn exhausted_fuel_and_scratch_refuse_instead_of_counting() {
    let image = image();
    let live = || Arc::new(AtomicBool::new(false));
    let deadline = Instant::now() + Duration::from_secs(10);
    let mut no_fuel = Context::new(0, 1000, deadline, live());
    assert_eq!(
        count(image.scan(0).unwrap(), &mut no_fuel),
        Err(Error::Fuel)
    );
    let mut no_memory = Context::new(100, 0, deadline, live());
    assert!(matches!(
        Materialized::fill(image.scan(0).unwrap(), &mut no_memory),
        Err(Error::Scratch)
    ));
}
