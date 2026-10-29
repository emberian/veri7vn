//! Hand-traced cases from the README table, one test each. They check the
//! prototype against hand calculation, not against any other system.
use conditional_symbolics_experiment::*;
use num_rational::BigRational as Q;
use std::collections::BTreeMap;

fn q(n: i64) -> Q {
    Q::from_integer(n.into())
}
fn unknown() -> Snapshot {
    Snapshot {
        revision: "unknown".into(),
        bounds: vec![],
    }
}
fn positive(x: Id) -> Snapshot {
    Snapshot {
        revision: "positive-v1".into(),
        bounds: vec![Bound {
            variable: x,
            low: q(1),
            high: q(10),
            source: "supplied-range".into(),
        }],
    }
}
fn x_over_x(dag: &mut Dag) -> (Id, Id) {
    let x = dag.put(Node::Variable("x".into(), SCALAR)).unwrap();
    (x, dag.put(Node::Div(x, x)).unwrap())
}
fn x_is(n: i64) -> BTreeMap<String, Q> {
    BTreeMap::from([("x".into(), q(n))])
}

#[test]
fn x_over_x_without_range_keeps_original_and_forged_replay_fails() {
    let mut dag = Dag::default();
    let (_, xx) = x_over_x(&mut dag);
    let one = dag.one().unwrap();
    let forged = Certificate {
        snapshot: unknown(),
        steps: vec![Step {
            left: xx,
            right: one,
            rule: Rule::SelfDivide,
        }],
    };
    assert!(replay(&dag, xx, one, &forged, &unknown()).is_err());
    let (unchanged, _) = propose(&mut dag, xx, &unknown()).unwrap();
    assert_eq!(unchanged, xx);
}

#[test]
fn x_over_x_with_supplied_range_becomes_one() {
    let mut dag = Dag::default();
    let (x, xx) = x_over_x(&mut dag);
    let snap = positive(x);
    let (selected, cert) = propose(&mut dag, xx, &snap).unwrap();
    assert_eq!(selected, dag.one().unwrap());
    let checked = replay(&dag, xx, selected, &cert, &snap).unwrap();
    assert_eq!(checked.evaluate(&snap, &x_is(2)).unwrap(), q(1));
}

#[test]
fn receipt_is_rejected_after_range_withdrawal() {
    let mut dag = Dag::default();
    let (x, xx) = x_over_x(&mut dag);
    let snap = positive(x);
    let (selected, cert) = propose(&mut dag, xx, &snap).unwrap();
    assert!(replay(&dag, xx, selected, &cert, &unknown()).is_err());
    let checked = replay(&dag, xx, selected, &cert, &snap).unwrap();
    assert!(checked.evaluate(&unknown(), &x_is(2)).is_err());
}

#[test]
fn input_outside_supplied_range_is_rejected_before_evaluation() {
    let mut dag = Dag::default();
    let (x, xx) = x_over_x(&mut dag);
    let snap = positive(x);
    let (selected, cert) = propose(&mut dag, xx, &snap).unwrap();
    let checked = replay(&dag, xx, selected, &cert, &snap).unwrap();
    assert!(checked.evaluate(&snap, &x_is(0)).is_err());
}

const MASS: Dim = [0, 1, 0, 0, 0, 0, 0];
const ENERGY: Dim = [2, 1, -2, 0, 0, 0, 0];

#[test]
fn energy_plus_mass_is_rejected_by_the_dag() {
    let mut dag = Dag::default();
    let m = dag.put(Node::Variable("m".into(), MASS)).unwrap();
    let k = dag.put(Node::Variable("kinetic".into(), ENERGY)).unwrap();
    assert!(dag.put(Node::Add(k, m)).is_err());
}

#[test]
fn specific_energy_fusion_gives_nine_and_rejects_zero_mass() {
    let mut dag = Dag::default();
    let m = dag.put(Node::Variable("m".into(), MASS)).unwrap();
    let k = dag.put(Node::Variable("kinetic".into(), ENERGY)).unwrap();
    let s = dag.put(Node::Variable("spring".into(), ENERGY)).unwrap();
    let km = dag.put(Node::Div(k, m)).unwrap();
    let sm = dag.put(Node::Div(s, m)).unwrap();
    let input = dag.put(Node::Add(km, sm)).unwrap();
    let (fused, receipt) = propose(&mut dag, input, &unknown()).unwrap();
    assert_ne!(input, fused);
    let run = replay(&dag, input, fused, &receipt, &unknown()).unwrap();
    let mut values = BTreeMap::from([
        ("m".to_string(), q(2)),
        ("kinetic".to_string(), q(12)),
        ("spring".to_string(), q(6)),
    ]);
    assert_eq!(run.evaluate(&unknown(), &values).unwrap(), q(9));
    values.insert("m".into(), q(0));
    assert!(run.evaluate(&unknown(), &values).is_err());
}

#[test]
fn product_over_factor_with_singular_division_still_rejects_the_singular_input() {
    // README row: (a*b)/b where b contains a singular division. The original
    // expression is evaluated first, so the singular point is refused.
    let mut dag = Dag::default();
    let a = dag.put(Node::Variable("a".into(), SCALAR)).unwrap();
    let y = dag.put(Node::Variable("y".into(), SCALAR)).unwrap();
    let one = dag.one().unwrap();
    let b = dag.put(Node::Div(one, y)).unwrap();
    let ab = dag.put(Node::Mul(a, b)).unwrap();
    let top = dag.put(Node::Div(ab, b)).unwrap();
    let snap = Snapshot {
        revision: "y-positive".into(),
        bounds: vec![Bound {
            variable: y,
            low: q(1),
            high: q(10),
            source: "supplied-range".into(),
        }],
    };
    let (selected, cert) = propose(&mut dag, top, &snap).unwrap();
    let run = replay(&dag, top, selected, &cert, &snap).unwrap();
    let ok = BTreeMap::from([("a".to_string(), q(3)), ("y".to_string(), q(2))]);
    assert_eq!(run.evaluate(&snap, &ok).unwrap(), q(3));
    let bad = BTreeMap::from([("a".to_string(), q(3)), ("y".to_string(), q(0))]);
    assert!(run.evaluate(&snap, &bad).is_err());
}
