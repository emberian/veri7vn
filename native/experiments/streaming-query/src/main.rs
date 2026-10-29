//! Authored executable fixture with hand-traced assertions; runs clean (see also tests/fixture.rs).
use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, Instant},
};
use streaming_query_spike::*;
fn context() -> Context {
    Context::new(
        100_000,
        1_000_000,
        Instant::now() + Duration::from_secs(10),
        Arc::new(AtomicBool::new(false)),
    )
}
fn main() -> Result<()> {
    let e = Entity;
    let image = Arc::new(Image::authored(
        42,
        vec![
            (0, vec![e(1), e(2), e(4), e(9)]),
            (1, vec![e(2), e(3), e(4)]),
            (2, vec![]),
        ],
        vec![
            Edge {
                subject: e(2),
                predicate: Predicate(7),
                object: e(9),
                evidence: Statement(0),
            },
            Edge {
                subject: e(2),
                predicate: Predicate(7),
                object: e(9),
                evidence: Statement(1),
            },
            Edge {
                subject: e(4),
                predicate: Predicate(7),
                object: e(3),
                evidence: Statement(2),
            },
        ],
    )?);
    let mut cx = context();
    let shared = Materialized::fill(
        Merge::intersection(image.scan(0)?, image.scan(1)?)?,
        &mut cx,
    )?;
    assert_eq!(count(shared.scan(), &mut cx)?.relative_to_image, 2);
    let result =
        Relate::new(image.clone(), shared.scan(), Predicate(7))?.materialize_objects(&mut cx)?;
    assert_eq!(result.witnesses.len(), 3); // parallel rows survive
    assert_eq!(count(result.entities.scan(), &mut cx)?.relative_to_image, 2); // {3,9}
    let union = Merge::union(image.scan(0)?, image.scan(1)?)?;
    assert_eq!(count(union, &mut cx)?.relative_to_image, 5); // {1,2,3,4,9}
    assert_eq!(unique(image.scan(2)?, &mut cx)?.value, Uniqueness::Empty);
    let parts = partition(&image.scan(0)?, &[e(2), e(4), e(8)], &mut cx)?;
    assert_eq!(
        count(Concat::ordered_disjoint(parts)?, &mut cx)?.relative_to_image,
        4
    );
    // Same label, independently constructed image: IDs must not mix.
    let other = Arc::new(Image::authored(42, vec![(0, vec![e(2)])], vec![])?);
    assert!(matches!(
        Merge::intersection(image.scan(0)?, other.scan(0)?),
        Err(Error::Snapshot)
    ));
    assert!(matches!(
        Merge::union(shared.scan(), other.scan(0)?),
        Err(Error::Snapshot)
    ));
    assert!(matches!(
        Relate::new(other.clone(), shared.scan(), Predicate(7)),
        Err(Error::Snapshot)
    ));
    assert!(matches!(
        Concat::ordered_disjoint(vec![image.scan(2)?, other.scan(0)?]),
        Err(Error::Snapshot)
    ));
    let answer = count(shared.scan(), &mut cx)?;
    assert_eq!(answer.scope.release_label(), 42); // descriptive label, not an admission proof
    let cancel = Arc::new(AtomicBool::new(false));
    let mut cancelled = Context::new(
        100,
        1000,
        Instant::now() + Duration::from_secs(10),
        cancel.clone(),
    );
    cancel.store(true, Ordering::Relaxed);
    assert_eq!(count(image.scan(2)?, &mut cancelled), Err(Error::Cancelled)); // empty still checks
    let mut no_fuel = Context::new(
        0,
        1000,
        Instant::now() + Duration::from_secs(10),
        Arc::new(AtomicBool::new(false)),
    );
    assert_eq!(count(image.scan(0)?, &mut no_fuel), Err(Error::Fuel));
    let mut no_memory = Context::new(
        100,
        0,
        Instant::now() + Duration::from_secs(10),
        Arc::new(AtomicBool::new(false)),
    );
    assert!(matches!(
        Materialized::fill(image.scan(0)?, &mut no_memory),
        Err(Error::Scratch)
    ));
    println!(
        "authored fixture: intersections, reuse, edge bags, partition fan-in, empty and limits"
    );
    Ok(())
}
