//! Independent supplied-network contracts for persistent immutable preparation.
use oracle_execution::{Cancellation, ExecutionContext, MemoryBudget};
use oracle_science::{
    thermal::{thermal_network, Link, Node, ThermalInput, ThermalOutcome},
    thermal_scenarios::{PreparedThermalNetwork, Scenario},
    Limits, Tolerances,
};
use std::{
    sync::{atomic::AtomicBool, Arc},
    time::Duration,
};
fn chain(free: usize) -> ThermalInput {
    let mut nodes: Vec<_> = (0..free)
        .map(|i| Node {
            id: format!("n{i}"),
            applied_heat_w: 0.0,
            fixed_temperature_k: None,
        })
        .collect();
    nodes.push(Node {
        id: "sink".into(),
        applied_heat_w: 0.0,
        fixed_temperature_k: Some(300.0),
    });
    let mut links = Vec::new();
    for i in 0..free {
        links.push(Link {
            from: format!("n{i}"),
            to: if i + 1 == free {
                "sink".into()
            } else {
                format!("n{}", i + 1)
            },
            conductance_w_per_k: 2.0,
        });
    }
    ThermalInput {
        description: "Supplied grounded chain".into(),
        assumptions: vec!["constant positive passive conductances".into()],
        reference_temperature_k: 300.0,
        nodes,
        links,
        power_tolerance_w: 1e-8,
        tolerances: Tolerances::default(),
    }
}
fn scenario(free: usize, q: f64, sink: f64) -> Scenario {
    let mut heats = vec![0.0; free + 1];
    heats[0] = q;
    let mut fixed = vec![None; free + 1];
    fixed[free] = Some(sink);
    Scenario {
        id: "current".into(),
        applied_heat_w: heats,
        fixed_temperature_k: fixed,
    }
}
fn context(bytes: usize) -> ExecutionContext {
    ExecutionContext::new(5_000_000, Duration::from_secs(60), Cancellation::default())
        .unwrap()
        .restricted_memory(bytes)
}
fn near(a: f64, b: f64) {
    assert!((a - b).abs() < 1e-7, "{a} != {b}");
}
#[test]
fn repeated_rhs_and_boundary_changes_match_fresh_and_chain_truth() {
    let n = chain(2);
    let control = AtomicBool::new(false);
    let prepared = PreparedThermalNetwork::prepare(&n, &Limits::default(), &control, None).unwrap();
    for (q, t) in [(8.0, 300.0), (16.0, 310.0), (-2.0, 290.0)] {
        let s = scenario(2, q, t);
        let got = prepared.solve(&s, &Limits::default(), &control).unwrap();
        let mut fresh = n.clone();
        for (i, node) in fresh.nodes.iter_mut().enumerate() {
            node.applied_heat_w = s.applied_heat_w[i];
            node.fixed_temperature_k = s.fixed_temperature_k[i];
        }
        let reference = thermal_network(&fresh, &Limits::default(), &control).unwrap();
        assert_eq!(got.outcome, ThermalOutcome::SolvedWithinTolerance);
        near(got.nodes[0].temperature_k.unwrap(), t + q);
        near(got.nodes[1].temperature_k.unwrap(), t + q / 2.0);
        for (a, b) in got.nodes.iter().zip(&reference.nodes) {
            near(a.temperature_k.unwrap(), b.temperature_k.unwrap());
            near(a.outgoing_link_heat_w, b.outgoing_link_heat_w);
            near(a.power_balance_residual_w, b.power_balance_residual_w);
            near(
                a.boundary_exchange_w.unwrap_or(0.0),
                b.boundary_exchange_w.unwrap_or(0.0),
            );
            assert!(a.power_balance_within_tolerance);
        }
        near(got.nodes[2].boundary_exchange_w.unwrap(), -q);
        near(got.conservation.net_external_heat_w, 0.0);
    }
}
#[test]
fn operator_template_and_full_input_identities_have_explicit_dependencies() {
    let n = chain(1);
    let c = AtomicBool::new(false);
    let make = |n: &ThermalInput| {
        PreparedThermalNetwork::prepare(n, &Limits::default(), &c, None).unwrap()
    };
    let base = make(&n);
    let mut values = n.clone();
    values.nodes[0].applied_heat_w = 99.0;
    values.nodes[1].fixed_temperature_k = Some(310.0);
    let rhs = make(&values);
    assert_eq!(base.operator_identity(), rhs.operator_identity());
    assert_eq!(base.template_identity(), rhs.template_identity());
    assert_ne!(base.identity(), rhs.identity());
    let mut prose = n.clone();
    prose.assumptions.push("additional supplied premise".into());
    let prose = make(&prose);
    assert_eq!(base.operator_identity(), prose.operator_identity());
    assert_ne!(base.template_identity(), prose.template_identity());
    let mut conductance = n.clone();
    conductance.links[0].conductance_w_per_k = 4.0;
    assert_ne!(
        base.operator_identity(),
        make(&conductance).operator_identity()
    );
    let mut policy = n.clone();
    policy.tolerances.rank_relative = 1e-11;
    assert_ne!(base.operator_identity(), make(&policy).operator_identity());
    let mut order = n.clone();
    order.nodes.swap(0, 1);
    assert_ne!(base.operator_identity(), make(&order).operator_identity());
}
#[test]
fn request_identity_binds_current_values_and_correlation_without_base_loads() {
    let n = chain(1);
    let c = AtomicBool::new(false);
    let a = PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).unwrap();
    let ctx = context(1024 * 1024);
    let s = scenario(1, 8.0, 300.0);
    let first = a.solve_with_context(&s, &Limits::default(), &ctx).unwrap();
    let mut changed = s.clone();
    changed.applied_heat_w[0] = 16.0;
    let second = a
        .solve_with_context(&changed, &Limits::default(), &ctx)
        .unwrap();
    assert_eq!(first.operator_identity(), second.operator_identity());
    assert_ne!(first.request_identity(), second.request_identity());
    let mut changed = s.clone();
    changed.fixed_temperature_k[1] = Some(310.0);
    assert_ne!(
        first.request_identity(),
        a.solve_with_context(&changed, &Limits::default(), &ctx)
            .unwrap()
            .request_identity()
    );
    let mut changed = s.clone();
    changed.id = "revision-2".into();
    assert_ne!(
        first.request_identity(),
        a.solve_with_context(&changed, &Limits::default(), &ctx)
            .unwrap()
            .request_identity()
    );
    let mut baseline = n;
    baseline.nodes[0].applied_heat_w = 999.0;
    let b = PreparedThermalNetwork::prepare(&baseline, &Limits::default(), &c, None).unwrap();
    assert_eq!(
        first.request_identity(),
        b.solve_with_context(&s, &Limits::default(), &ctx)
            .unwrap()
            .request_identity()
    );
}
#[test]
fn retained_solve_uses_quadratic_local_policy_and_stricter_limits() {
    let n = chain(16);
    let c = AtomicBool::new(false);
    let p = PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).unwrap();
    let s = scenario(16, 1.0, 300.0);
    let mut limits = Limits::default();
    limits.work = 1024;
    limits.scratch_bytes = 0;
    assert!(p.solve(&s, &limits, &c).is_ok());
    let mut fresh = n;
    fresh.nodes[0].applied_heat_w = 1.0;
    assert!(thermal_network(&fresh, &limits, &c).is_err());
    limits.work = 1;
    assert!(p.solve(&s, &limits, &c).is_err());
    limits = Limits::default();
    limits.columns = 0;
    assert!(p.solve(&s, &limits, &c).is_err());
    limits = Limits::default();
    limits.request_bytes = 1;
    assert!(p.solve(&s, &limits, &c).is_err());
}
#[test]
fn model_arc_and_context_owned_outputs_have_separate_live_custody() {
    let ledger = MemoryBudget::new(32 * 1024 * 1024);
    let c = AtomicBool::new(false);
    let model = Arc::new(
        PreparedThermalNetwork::prepare(&chain(1), &Limits::default(), &c, Some(&ledger)).unwrap(),
    );
    let retained = ledger.snapshot().live;
    assert!(retained > 0);
    let other = model.clone();
    assert_eq!(ledger.snapshot().live, retained);
    let ctx = context(1024 * 1024);
    let output = other
        .solve_with_context(&scenario(1, 8.0, 300.0), &Limits::default(), &ctx)
        .unwrap();
    assert!(ctx.memory().snapshot().live > 0);
    drop(model);
    assert_eq!(ledger.snapshot().live, retained);
    drop(other);
    assert_eq!(ledger.snapshot().live, 0);
    near(output.result().nodes[0].temperature_k.unwrap(), 304.0);
    drop(output);
    assert_eq!(ctx.memory().snapshot().live, 0);
}
#[test]
fn failure_budget_and_cancellation_never_promote_negative_temperature() {
    let c = AtomicBool::new(false);
    let p = PreparedThermalNetwork::prepare(&chain(1), &Limits::default(), &c, None).unwrap();
    let ctx = context(1024 * 1024);
    let bad = p
        .solve_with_context(&scenario(1, -1000.0, 300.0), &Limits::default(), &ctx)
        .unwrap();
    assert_eq!(
        bad.result().outcome,
        ThermalOutcome::BelowAbsoluteZeroCandidate
    );
    assert!(bad.result().nodes[0].temperature_k.is_none());
    near(
        bad.result().nodes[0].candidate_temperature_k.unwrap(),
        -200.0,
    );
    assert!(bad
        .result()
        .nodes
        .iter()
        .all(|node| node.power_balance_within_tolerance));
    drop(bad);
    let tiny = context(1);
    assert!(p
        .solve_with_context(&scenario(1, 8.0, 300.0), &Limits::default(), &tiny)
        .is_err());
    assert_eq!(tiny.memory().snapshot().live, 0);
    ctx.cancellation().cancel();
    assert_eq!(
        p.solve_with_context(&scenario(1, 8.0, 300.0), &Limits::default(), &ctx)
            .err()
            .unwrap()
            .code(),
        "cancelled"
    );
    let fresh_context = context(1024 * 1024);
    assert!(p
        .solve_with_context(&scenario(1, 8.0, 300.0), &Limits::default(), &fresh_context)
        .is_ok());
}
#[test]
fn preparation_validates_base_quantities_but_defers_unrequested_base_solution() {
    let c = AtomicBool::new(false);
    let mut n = chain(1);
    n.nodes[0].applied_heat_w = f64::MAX;
    n.nodes[1].applied_heat_w = f64::MAX;
    let p = PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).unwrap();
    near(
        p.solve(&scenario(1, 8.0, 300.0), &Limits::default(), &c)
            .unwrap()
            .nodes[0]
            .temperature_k
            .unwrap(),
        304.0,
    );
    n.nodes[0].applied_heat_w = f64::NAN;
    assert!(PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).is_err());
    n.nodes[0].applied_heat_w = 0.0;
    n.nodes[1].fixed_temperature_k = Some(-1.0);
    assert!(PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).is_err());
}
#[test]
fn immutable_operator_survives_caller_edit_and_masks_cannot_change() {
    let c = AtomicBool::new(false);
    let mut n = chain(1);
    let p = PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).unwrap();
    n.links[0].conductance_w_per_k = 4.0;
    near(
        p.solve(&scenario(1, 8.0, 300.0), &Limits::default(), &c)
            .unwrap()
            .nodes[0]
            .temperature_k
            .unwrap(),
        304.0,
    );
    let mut changed = scenario(1, 8.0, 300.0);
    changed.fixed_temperature_k[0] = Some(300.0);
    assert!(p.solve(&changed, &Limits::default(), &c).is_err());
    changed.fixed_temperature_k = vec![None, None];
    assert!(p.solve(&changed, &Limits::default(), &c).is_err());
}
