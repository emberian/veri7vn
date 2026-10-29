use num_bigint::BigInt;
use num_rational::BigRational;
use num_traits::{Signed, Zero};
use oracle_reasoning::{
    call,
    dimensions::{Dimension, QuantityKind, VariableAnnotation},
    formula::{
        parse_rational, replay, BoundInput, Certificate, Dag, Evaluation, Premises, Reason, Rule,
        Step,
    },
    formula_search::{rules, simplify, simplify_json, PointValue, RationalInput},
    Error, Limits,
};
use std::collections::BTreeMap;

const MASS: [i16; 7] = [0, 1, 0, 0, 0, 0, 0];
const LENGTH: [i16; 7] = [1, 0, 0, 0, 0, 0, 0];
const VOLUME: [i16; 7] = [3, 0, 0, 0, 0, 0, 0];
const DENSITY: [i16; 7] = [-3, 1, 0, 0, 0, 0, 0];
const ENERGY: [i16; 7] = [2, 1, -2, 0, 0, 0, 0];
const SCALAR: [i16; 7] = [0; 7];

fn q(text: &str) -> BigRational {
    parse_rational(text, &Limits::default()).unwrap()
}

fn annotations(variables: &[(&str, [i16; 7])]) -> Vec<VariableAnnotation> {
    variables
        .iter()
        .map(|(name, d)| VariableAnnotation {
            name: (*name).into(),
            dimension: Dimension::new(*d).unwrap(),
            kind: QuantityKind::Linear,
        })
        .collect()
}

fn bounds(rows: &[(&str, &str, &str)]) -> Vec<BoundInput> {
    rows.iter()
        .map(|(name, low, high)| BoundInput {
            name: (*name).into(),
            low: (*low).into(),
            high: (*high).into(),
        })
        .collect()
}

fn input(
    expression: &str,
    variables: &[(&str, [i16; 7])],
    bound_rows: &[(&str, &str, &str)],
    point: Option<&[(&str, &str)]>,
) -> RationalInput {
    RationalInput {
        expression: expression.into(),
        variables: annotations(variables),
        bounds: bounds(bound_rows),
        output_dimension: None,
        point: point.map(|p| {
            p.iter()
                .map(|(name, value)| PointValue {
                    name: (*name).into(),
                    value: (*value).into(),
                })
                .collect()
        }),
    }
}

/// Densities specialist volume formula, `qval (VolumeOf m (Some M) u) = siq M
/// / density m / scale u` (src/extract/quantity/Quantity.thy). Reference
/// densities and unit scales are that theory's exact table values; expected
/// floats are the shipped panel's (upstream/root/specialists/densities/
/// densities_panel_v1.json). This is a consumer check, not a panel score.
#[test]
fn densities_volume_formula_matches_three_panel_items() {
    let limits = Limits::default();
    let bound_rows = [
        ("M", "0", "1000000"),
        ("rho", "1", "25000"),
        ("u", "1/1000000", "1"),
    ];
    let items = [
        (
            "1",
            "135336/10",
            "1/1000",
            "1250/16917",
            0.07389016965182951_f64,
        ),
        ("1200", "10501", "1", "1200/10501", 0.1142748309684792),
        ("20", "2400", "1/1000", "25/3", 8.333333333333334),
    ];
    // Relative tolerance between the exact value and the shipped float.
    let tolerance = q("1/1000000000000000");
    for (mass, density, unit, exact, shipped) in items {
        let reply = simplify(
            &input(
                "(/ (/ M rho) u)",
                &[("M", MASS), ("rho", DENSITY), ("u", VOLUME)],
                &bound_rows,
                Some(&[("M", mass), ("rho", density), ("u", unit)]),
            ),
            &limits,
        )
        .unwrap();
        assert_eq!(reply.expression, "(/ M (* rho u))");
        assert!(reply.selection_fallback.is_none());
        assert!(reply.selected_cost < reply.original_cost);
        assert_eq!(reply.output_dimension, Dimension::DIMENSIONLESS);
        let statuses: Vec<_> = reply
            .domain_obligations
            .iter()
            .map(|o| (o.denominator.as_str(), o.status))
            .collect();
        assert_eq!(
            statuses,
            [
                ("rho", "nonzero_within_bounds"),
                ("u", "nonzero_within_bounds")
            ]
        );
        let evaluation = reply.evaluation.unwrap();
        assert_eq!(evaluation.status, "value");
        let value = q(evaluation.value.as_deref().unwrap());
        assert_eq!(value, q(exact));
        let shipped = BigRational::from_float(shipped).unwrap();
        assert!(((&value - &shipped) / &value).abs() <= tolerance);
    }
}

#[test]
fn fused_specific_energy_keeps_the_mass_singularity() {
    let limits = Limits::default();
    let variables = [("K", ENERGY), ("S", ENERGY), ("m", MASS)];
    let at = |m: &str| {
        simplify(
            &input(
                "(+ (/ K m) (/ S m))",
                &variables,
                &[],
                Some(&[("K", "12"), ("S", "6"), ("m", m)]),
            ),
            &limits,
        )
        .unwrap()
    };
    let reply = at("2");
    assert!(reply.selection_fallback.is_none());
    assert!(reply
        .rules_used
        .iter()
        .any(|r| r.rule == Rule::FuseDenominator));
    assert!(reply.expression.starts_with("(/ (+ "));
    assert!(reply.expression.ends_with(" m)"));
    assert_eq!(
        reply.output_dimension,
        Dimension::new([2, 0, -2, 0, 0, 0, 0]).unwrap()
    );
    assert_eq!(reply.domain_obligations[0].denominator, "m");
    assert_eq!(reply.domain_obligations[0].status, "not_established");
    assert_eq!(reply.evaluation.unwrap().value.as_deref(), Some("9"));
    let singular = at("0").evaluation.unwrap();
    assert_eq!(singular.status, "undefined");
    assert!(singular.value.is_none());
}

#[test]
fn cancellation_needs_a_bound_and_the_bound_is_checked_at_the_point() {
    let limits = Limits::default();
    let variables = [("a", LENGTH), ("b", SCALAR)];
    let unbounded = simplify(&input("(/ (* a b) b)", &variables, &[], None), &limits).unwrap();
    assert_eq!(unbounded.expression, "(/ (* a b) b)");
    let at = |b: &str| {
        simplify(
            &input(
                "(/ (* a b) b)",
                &variables,
                &[("b", "1", "10")],
                Some(&[("a", "3"), ("b", b)]),
            ),
            &limits,
        )
        .unwrap()
    };
    let reply = at("2");
    assert_eq!(reply.expression, "a");
    assert_eq!(reply.domain_obligations[0].status, "nonzero_within_bounds");
    assert_eq!(reply.evaluation.unwrap().value.as_deref(), Some("3"));
    assert_eq!(at("0").evaluation.unwrap().status, "outside_bounds");

    let ratio = simplify(
        &input("(/ x x)", &[("x", SCALAR)], &[("x", "1", "10")], None),
        &limits,
    )
    .unwrap();
    assert_eq!(ratio.expression, "1");
    let open = simplify(
        &input("(/ x x)", &[("x", SCALAR)], &[("x", "-1", "10")], None),
        &limits,
    )
    .unwrap();
    assert_eq!(open.expression, "(/ x x)");
}

#[test]
fn typed_zero_keeps_units_and_untyped_zero_cannot_join_a_quantity() {
    let limits = Limits::default();
    let variables = [("x", LENGTH), ("y", LENGTH)];
    // Under the tree cost (- x x) is already cheapest; its zero keeps metres.
    let zero = simplify(&input("(- x x)", &[("x", LENGTH)], &[], None), &limits).unwrap();
    assert_eq!(zero.expression, "(- x x)");
    assert_eq!(zero.output_dimension, Dimension::new(LENGTH).unwrap());
    let kept = simplify(&input("(+ y (- x x))", &variables, &[], None), &limits).unwrap();
    assert_eq!(kept.expression, "y");
    assert!(matches!(
        simplify(&input("(+ x 0)", &[("x", LENGTH)], &[], None), &limits),
        Err(Error::Invalid(_))
    ));
    // A dropped subterm must be defined throughout the bounds.
    let partial = simplify(
        &input(
            "(+ y (* 0 (/ x z)))",
            &[("x", LENGTH), ("y", LENGTH), ("z", SCALAR)],
            &[],
            None,
        ),
        &limits,
    )
    .unwrap();
    assert_eq!(partial.expression, "(+ y (* 0 (/ x z)))");
}

#[test]
fn proposer_rule_names_are_exactly_the_checker_rule_names() {
    let mut proposer: Vec<String> = rules().iter().map(|r| r.name.to_string()).collect();
    let mut checker: Vec<String> = Rule::ALL.iter().map(|r| r.name().to_string()).collect();
    proposer.sort();
    checker.sort();
    assert_eq!(proposer, checker);
}

struct Fixture {
    dag: Dag,
    limits: Limits,
}
impl Fixture {
    fn new(variables: &[(&str, [i16; 7])]) -> Self {
        let limits = Limits::default();
        Self {
            dag: Dag::new(&annotations(variables), &limits).unwrap(),
            limits,
        }
    }
    fn term(&mut self, source: &str) -> usize {
        self.dag.parse(source, &self.limits).unwrap()
    }
    fn premises(&self, rows: &[(&str, &str, &str)]) -> Premises {
        Premises::new(&self.dag, &bounds(rows), &self.limits).unwrap()
    }
    fn check(
        &self,
        premises: &Premises,
        left: usize,
        right: usize,
        steps: Vec<Step>,
    ) -> Result<(), Error> {
        replay(
            &self.dag,
            premises,
            left,
            right,
            &Certificate { steps },
            &self.limits,
        )
        .map(|_| ())
    }
}
fn rule(left: usize, right: usize, rule: Rule, reverse: bool) -> Step {
    Step {
        left,
        right,
        reason: Reason::Rule { rule, reverse },
    }
}

#[test]
fn forged_certificates_fail_replay() {
    let mut f = Fixture::new(&[("a", LENGTH), ("b", SCALAR), ("c", SCALAR), ("m", MASS)]);
    let bounded = f.premises(&[("b", "1", "10")]);
    let none = Premises::none();

    // Cancellation without a bound, and with a bound that admits zero.
    let ab_b = f.term("(/ (* a b) b)");
    let a = f.term("a");
    assert!(f
        .check(
            &bounded,
            ab_b,
            a,
            vec![rule(ab_b, a, Rule::CancelRight, false)]
        )
        .is_ok());
    assert!(matches!(
        f.check(
            &none,
            ab_b,
            a,
            vec![rule(ab_b, a, Rule::CancelRight, false)]
        ),
        Err(Error::Check(_))
    ));
    let straddles = f.premises(&[("b", "-1", "10")]);
    assert!(f
        .check(
            &straddles,
            ab_b,
            a,
            vec![rule(ab_b, a, Rule::CancelRight, false)]
        )
        .is_err());
    let bb = f.term("(/ b b)");
    let one = f.term("1");
    assert!(f
        .check(&none, bb, one, vec![rule(bb, one, Rule::DivideSelf, false)])
        .is_err());

    // Wrong factor: the denominator is not the cancelled factor.
    let ab_c = f.term("(/ (* a b) c)");
    let both = f.premises(&[("b", "1", "10"), ("c", "1", "10")]);
    assert!(f
        .check(
            &both,
            ab_c,
            a,
            vec![rule(ab_c, a, Rule::CancelRight, false)]
        )
        .is_err());

    // Broken transitivity chain: b = b and a = a do not compose to b = a.
    let b = f.term("b");
    let broken = vec![
        Step {
            left: b,
            right: b,
            reason: Reason::Reflexive,
        },
        Step {
            left: a,
            right: a,
            reason: Reason::Reflexive,
        },
        Step {
            left: b,
            right: a,
            reason: Reason::Transitive {
                first: 0,
                second: 1,
            },
        },
    ];
    assert!(f.check(&none, b, a, broken).is_err());

    // A step that changes units: mass times zero is not the unitless zero.
    let m0 = f.term("(* m 0)");
    let zero = f.term("0");
    assert!(matches!(
        f.check(&none, m0, zero, vec![rule(m0, zero, Rule::MulZero, false)]),
        Err(Error::Check("step changes dimension"))
    ));
    // Dimensionless but partial: dropping 1/c would hide c = 0.
    let partial = f.term("(* (/ 1 c) 0)");
    assert!(f
        .check(
            &none,
            partial,
            zero,
            vec![rule(partial, zero, Rule::MulZero, false)]
        )
        .is_err());
    let total = f.term("(* (/ 1 c) 0)");
    let positive = f.premises(&[("c", "1", "2")]);
    assert!(f
        .check(
            &positive,
            total,
            zero,
            vec![rule(total, zero, Rule::MulZero, false)]
        )
        .is_ok());

    // Forward citation, wrong conclusion and mismatched congruence.
    let ba = f.term("(+ b c)");
    let ab = f.term("(+ c b)");
    assert!(f
        .check(
            &none,
            ba,
            ab,
            vec![Step {
                left: ba,
                right: ab,
                reason: Reason::Transitive {
                    first: 0,
                    second: 0
                }
            }]
        )
        .is_err());
    assert!(f
        .check(&none, ba, ba, vec![rule(ba, ab, Rule::AddCommute, false)])
        .is_err());
    let left = f.term("(* (+ b c) a)");
    let right = f.term("(* (+ c b) m)");
    let commute = rule(ba, ab, Rule::AddCommute, false);
    let aa = Step {
        left: a,
        right: a,
        reason: Reason::Reflexive,
    };
    let congruence = Step {
        left,
        right,
        reason: Reason::Congruence { left: 0, right: 1 },
    };
    assert!(f
        .check(
            &none,
            left,
            right,
            vec![commute.clone(), aa.clone(), congruence]
        )
        .is_err());
    let good = f.term("(* (+ c b) a)");
    let congruence = Step {
        left,
        right: good,
        reason: Reason::Congruence { left: 0, right: 1 },
    };
    assert!(f
        .check(&none, left, good, vec![commute, aa, congruence])
        .is_ok());

    // Reverse use carries the same condition.
    assert!(f
        .check(
            &bounded,
            a,
            ab_b,
            vec![rule(a, ab_b, Rule::CancelRight, true)]
        )
        .is_ok());
    assert!(f
        .check(&none, a, ab_b, vec![rule(a, ab_b, Rule::CancelRight, true)])
        .is_err());
}

#[test]
fn checked_evaluation_rejects_singular_and_out_of_bounds_points() {
    let mut f = Fixture::new(&[("K", ENERGY), ("S", ENERGY), ("m", MASS)]);
    let original = f.term("(+ (/ K m) (/ S m))");
    let fused = f.term("(/ (+ K S) m)");
    let none = Premises::none();
    let checked = replay(
        &f.dag,
        &none,
        original,
        fused,
        &Certificate {
            steps: vec![rule(original, fused, Rule::FuseDenominator, false)],
        },
        &f.limits,
    )
    .unwrap();
    let point = |m: &str| BTreeMap::from([(0, q("12")), (1, q("6")), (2, q(m))]);
    assert_eq!(
        checked.evaluate(&point("2"), &f.limits).unwrap(),
        Evaluation::Value(q("9"))
    );
    let m = f.dag.variable_index("m").unwrap();
    let m_node = f.dag.denominators(original).unwrap()[0];
    assert!(
        matches!(f.dag.node(m_node).unwrap(), oracle_reasoning::formula::Node::Var(i) if *i == m)
    );
    assert_eq!(
        checked.evaluate(&point("0"), &f.limits).unwrap(),
        Evaluation::Undefined {
            denominator: m_node
        }
    );
}

#[test]
fn identically_zero_denominator_is_refused() {
    let limits = Limits::default();
    let refused = simplify(
        &input("(/ x (* 0 y))", &[("x", SCALAR), ("y", SCALAR)], &[], None),
        &limits,
    );
    assert!(matches!(refused, Err(Error::Invalid(_))));
    let mut f = Fixture::new(&[("x", SCALAR), ("y", SCALAR)]);
    let bad = f.term("(/ (* x y) (* 0 y))");
    assert!(f.check(&Premises::none(), bad, bad, vec![]).is_err());
}

fn nested(depth: usize) -> String {
    let mut s = "y".to_string();
    for _ in 0..depth {
        s = format!("(/ {s} (+ x 1))");
    }
    s
}

#[test]
fn deep_nesting_hits_a_named_limit_without_stack_overflow() {
    let variables = [("x", SCALAR), ("y", SCALAR)];
    let source = nested(200);
    assert!(matches!(
        simplify(&input(&source, &variables, &[], None), &Limits::default()),
        Err(Error::Limit(_))
    ));
    let wide = Limits {
        expression_nodes: 10_000,
        ..Limits::default()
    };
    assert!(matches!(
        simplify(&input(&source, &variables, &[], None), &wide),
        Err(Error::Limit("formula depth"))
    ));
    // Depth admitted: every pass is iterative or bounded by the depth cap.
    let deep = Limits {
        expression_nodes: 10_000,
        formula_depth: 1_000,
        ..Limits::default()
    };
    match simplify(&input(&source, &variables, &[("x", "0", "1")], None), &deep) {
        Ok(reply) => assert!(reply.selected_cost <= reply.original_cost),
        Err(Error::Limit(_)) => {}
        Err(other) => panic!("unexpected {other}"),
    }
}

#[test]
fn rational_budgets_are_named_limits() {
    let variables = [("x", SCALAR)];
    let huge = format!("(* x {})", "9".repeat(5000));
    assert!(matches!(
        simplify(&input(&huge, &variables, &[], None), &Limits::default()),
        Err(Error::Limit("rational bits"))
    ));
    let tight = Limits {
        rational_bits: 8,
        ..Limits::default()
    };
    assert!(matches!(
        simplify(&input("(* x 1000)", &variables, &[], None), &tight),
        Err(Error::Limit("rational bits"))
    ));
    let work = Limits {
        rational_work: 2,
        ..Limits::default()
    };
    assert!(matches!(
        simplify(
            &input("(/ (+ x 1) (+ x 2))", &variables, &[("x", "0", "1")], None),
            &work
        ),
        Err(Error::Limit("rational work"))
    ));
    let reply = Limits {
        formula_reply_bytes: 64,
        ..Limits::default()
    };
    assert!(matches!(
        simplify_json(&input("(+ x x)", &variables, &[], None), &reply),
        Err(Error::Limit("formula reply bytes"))
    ));
    let mut f = Fixture::new(&variables);
    let x = f.term("x");
    let steps = vec![
        Step {
            left: x,
            right: x,
            reason: Reason::Reflexive
        };
        3
    ];
    let few = Limits {
        proof_steps: 2,
        ..Limits::default()
    };
    assert!(matches!(
        replay(
            &f.dag,
            &Premises::none(),
            x,
            x,
            &Certificate { steps },
            &few
        ),
        Err(Error::Limit("proof steps"))
    ));
    assert!(parse_rational("01", &Limits::default()).is_err());
    assert!(parse_rational("-0", &Limits::default()).is_err());
    assert!(parse_rational("1/0", &Limits::default()).is_err());
    assert_eq!(
        parse_rational("-6/4", &Limits::default()).unwrap(),
        q("-3/2")
    );
    assert!(!q("0").is_positive() && q("0").is_zero());
    let _ = BigInt::from(0);
}

#[test]
fn hosted_operation_routes_and_catalog_declares_budgets() {
    let request = serde_json::json!({"operation": "algebra.simplify_rational", "arguments": {
        "expression": "(/ (/ M rho) u)",
        "variables": [{"name": "M", "dimension": MASS}, {"name": "rho", "dimension": DENSITY}, {"name": "u", "dimension": VOLUME}],
        "bounds": [{"name": "rho", "low": "1", "high": "25000"}, {"name": "u", "low": "1/1000000", "high": "1"}],
        "point": [{"name": "M", "value": "20"}, {"name": "rho", "value": "2400"}, {"name": "u", "value": "1/1000"}]}});
    let reply: serde_json::Value =
        serde_json::from_str(&call(&request.to_string(), &Limits::default()).unwrap()).unwrap();
    assert_eq!(reply["schema"], "oracle-rational-formula-v1");
    assert_eq!(reply["evaluation"]["value"], "25/3");
    assert_eq!(reply["rules_used"][0]["rule"], "divide-divide");
    let catalog = oracle_reasoning::catalog();
    let row = catalog["operations"]
        .as_array()
        .unwrap()
        .iter()
        .find(|row| row["id"] == "algebra.simplify_rational")
        .unwrap();
    assert_eq!(row["rational_limits"]["formula_depth"], 64);
    assert!(catalog.to_string().len() < 16384);
}

#[test]
fn multi_step_proposals_replay_through_congruence_and_transitivity() {
    let limits = Limits::default();
    let variables = [("a", SCALAR), ("b", SCALAR), ("c", SCALAR), ("d", SCALAR)];
    let point = [("a", "1"), ("b", "2"), ("c", "3"), ("d", "4")];
    let reply = simplify(
        &input(
            "(+ (/ (/ a b) c) (/ (/ d b) c))",
            &variables,
            &[],
            Some(&point),
        ),
        &limits,
    )
    .unwrap();
    assert!(reply.selection_fallback.is_none());
    assert_eq!(reply.expression, "(/ (+ a d) (* b c))");
    let rule_steps: usize = reply.rules_used.iter().map(|r| r.count).sum();
    assert!(reply.certificate_steps > rule_steps && rule_steps >= 3);
    assert_eq!(reply.evaluation.unwrap().value.as_deref(), Some("5/6"));

    let nested = simplify(
        &input(
            "(* 3 (/ (* (+ x 1) y) (+ x 1)))",
            &[("x", SCALAR), ("y", SCALAR)],
            &[("x", "0", "5")],
            Some(&[("x", "1"), ("y", "7")]),
        ),
        &limits,
    )
    .unwrap();
    assert!(nested.selection_fallback.is_none());
    assert!(nested
        .rules_used
        .iter()
        .any(|r| r.rule == Rule::CancelRight));
    assert!(!nested.expression.contains('/'));
    assert_eq!(nested.evaluation.unwrap().value.as_deref(), Some("21"));
}
