//! Authored fixture driver. NOT RUN; its assertions are intended expectations.
use conditional_symbolics_experiment::*;
use num_rational::BigRational as Q;
use std::collections::BTreeMap;
fn q(n: i64) -> Q {
    Q::from_integer(n.into())
}
fn main() -> Result<()> {
    let mut dag = Dag::default();
    let x = dag.put(Node::Variable("x".into(), SCALAR))?;
    let xx = dag.put(Node::Div(x, x))?;
    let unknown = Snapshot {
        revision: "unknown".into(),
        bounds: vec![],
    };
    let positive = Snapshot {
        revision: "positive-v1".into(),
        bounds: vec![Bound {
            variable: x,
            low: q(1),
            high: q(10),
            source: "supplied-range".into(),
        }],
    };
    let one = dag.one()?;
    let forged = Certificate {
        snapshot: unknown.clone(),
        steps: vec![Step {
            left: xx,
            right: one,
            rule: Rule::SelfDivide,
        }],
    };
    assert!(replay(&dag, xx, one, &forged, &unknown).is_err());
    let (selected, cert) = propose(&mut dag, xx, &positive)?;
    let checked = replay(&dag, xx, selected, &cert, &positive)?;
    assert_eq!(
        checked.evaluate(&positive, &BTreeMap::from([("x".into(), q(2))]))?,
        q(1)
    );
    assert!(checked
        .evaluate(&positive, &BTreeMap::from([("x".into(), q(0))]))
        .is_err());
    assert!(replay(&dag, xx, selected, &cert, &unknown).is_err());
    let (unchanged, _) = propose(&mut dag, xx, &unknown)?;
    assert_eq!(unchanged, xx);

    // Mechanics consumer: kinetic energy + spring energy per unit mass.
    let mass = [0, 1, 0, 0, 0, 0, 0];
    let energy = [2, 1, -2, 0, 0, 0, 0];
    let m = dag.put(Node::Variable("m".into(), mass))?;
    let kinetic = dag.put(Node::Variable("kinetic".into(), energy))?;
    let spring = dag.put(Node::Variable("spring".into(), energy))?;
    let km = dag.put(Node::Div(kinetic, m))?;
    let sm = dag.put(Node::Div(spring, m))?;
    let input = dag.put(Node::Add(km, sm))?;
    assert!(dag.put(Node::Add(kinetic, m)).is_err());
    let (fused, receipt) = propose(&mut dag, input, &unknown)?;
    assert_ne!(input, fused);
    let execution = replay(&dag, input, fused, &receipt, &unknown)?;
    let mut values = BTreeMap::from([
        ("m".into(), q(2)),
        ("kinetic".into(), q(12)),
        ("spring".into(), q(6)),
    ]);
    assert_eq!(execution.evaluate(&unknown, &values)?, q(9));
    values.insert("m".into(), q(0));
    assert!(execution.evaluate(&unknown, &values).is_err());
    println!("authored conditional-symbolics fixtures reached end");
    Ok(())
}
