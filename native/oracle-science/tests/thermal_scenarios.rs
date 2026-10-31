use oracle_science::{
    thermal::{Link, Node, ThermalInput, ThermalOutcome},
    thermal_scenarios::*,
    Limits, Tolerances,
};
use std::sync::atomic::AtomicBool;
fn network() -> ThermalInput {
    ThermalInput {
        description: "Supplied one-link heater".into(),
        assumptions: vec!["steady positive constant conductance".into()],
        reference_temperature_k: 300.0,
        nodes: vec![
            Node {
                id: "heater".into(),
                applied_heat_w: 10.0,
                fixed_temperature_k: None,
            },
            Node {
                id: "sink".into(),
                applied_heat_w: 0.0,
                fixed_temperature_k: Some(300.0),
            },
        ],
        links: vec![Link {
            from: "heater".into(),
            to: "sink".into(),
            conductance_w_per_k: 2.0,
        }],
        power_tolerance_w: 1e-8,
        tolerances: Tolerances::default(),
    }
}
fn scenario(id: &str, q: f64, t: f64) -> Scenario {
    Scenario {
        id: id.into(),
        applied_heat_w: vec![q, 0.0],
        fixed_temperature_k: vec![None, Some(t)],
    }
}
fn input() -> ThermalScenariosInput {
    ThermalScenariosInput {
        network: network(),
        scenarios: vec![
            scenario("normal", 10.0, 300.0),
            scenario("warm", 24.0, 310.0),
        ],
        sensitivities: vec![
            SensitivityRequest {
                scenario_id: "normal".into(),
                parameter: Parameter::Load {
                    node_id: "heater".into(),
                },
            },
            SensitivityRequest {
                scenario_id: "normal".into(),
                parameter: Parameter::Conductance { link_index: 0 },
            },
        ],
    }
}
fn near(a: f64, b: f64) {
    assert!((a - b).abs() < 1e-8, "{a} != {b}");
}
#[test]
fn one_link_truth_and_original_balances() {
    let out = thermal_scenarios(&input(), &Limits::default(), &AtomicBool::new(false)).unwrap();
    assert_eq!(out.factorization_count, 1);
    assert_eq!(out.scenario_rhs_solves, 2);
    near(
        out.scenarios[0].result.nodes[0].temperature_k.unwrap(),
        305.0,
    );
    near(
        out.scenarios[1].result.nodes[0].temperature_k.unwrap(),
        322.0,
    );
    near(out.sensitivities[0].temperature_derivative[0], 0.5);
    near(out.sensitivities[1].temperature_derivative[0], -2.5);
    for s in out.scenarios {
        assert_eq!(s.result.outcome, ThermalOutcome::SolvedWithinTolerance);
        assert!(s
            .result
            .nodes
            .iter()
            .all(|n| n.power_balance_within_tolerance));
        near(s.result.conservation.net_external_heat_w, 0.0);
    }
}
#[test]
fn analytic_conductance_derivative_matches_central_difference() {
    let base = input();
    let cancel = AtomicBool::new(false);
    let out = thermal_scenarios(&base, &Limits::default(), &cancel).unwrap();
    let h = 1e-4;
    let mut plus = base.clone();
    plus.sensitivities.clear();
    plus.network.links[0].conductance_w_per_k += h;
    let mut minus = plus.clone();
    minus.network.links[0].conductance_w_per_k -= 2.0 * h;
    let p = thermal_scenarios(&plus, &Limits::default(), &cancel).unwrap();
    let m = thermal_scenarios(&minus, &Limits::default(), &cancel).unwrap();
    let fd = (p.scenarios[0].result.nodes[0].temperature_k.unwrap()
        - m.scenarios[0].result.nodes[0].temperature_k.unwrap())
        / (2.0 * h);
    near(out.sensitivities[1].temperature_derivative[0], fd);
}
#[test]
fn reservoir_load_derivative_is_zero() {
    let mut i = input();
    i.sensitivities = vec![SensitivityRequest {
        scenario_id: "normal".into(),
        parameter: Parameter::Load {
            node_id: "sink".into(),
        },
    }];
    let out = thermal_scenarios(&i, &Limits::default(), &AtomicBool::new(false)).unwrap();
    assert_eq!(out.sensitivities[0].temperature_derivative, vec![0.0, 0.0]);
}
#[test]
fn floating_network_is_not_an_absolute_temperature() {
    let mut i = input();
    i.network.nodes[1].fixed_temperature_k = None;
    for s in &mut i.scenarios {
        s.fixed_temperature_k[1] = None;
    }
    assert!(thermal_scenarios(&i, &Limits::default(), &AtomicBool::new(false)).is_err());
}
#[test]
fn changed_boundary_mask_and_incomplete_vectors_refused() {
    let mut i = input();
    i.scenarios[0].fixed_temperature_k[0] = Some(300.0);
    assert!(thermal_scenarios(&i, &Limits::default(), &AtomicBool::new(false)).is_err());
    let mut i = input();
    i.scenarios[0].applied_heat_w.pop();
    assert!(thermal_scenarios(&i, &Limits::default(), &AtomicBool::new(false)).is_err());
}
#[test]
fn immutable_content_identity_changes_with_conductance_and_policy() {
    let c = AtomicBool::new(false);
    let n = network();
    let a = PreparedThermalNetwork::prepare(&n, &Limits::default(), &c, None).unwrap();
    let mut changed = n.clone();
    changed.links[0].conductance_w_per_k = 3.0;
    let b = PreparedThermalNetwork::prepare(&changed, &Limits::default(), &c, None).unwrap();
    assert_ne!(a.identity(), b.identity());
    near(
        a.solve(&scenario("x", 10.0, 300.0), &Limits::default(), &c)
            .unwrap()
            .nodes[0]
            .temperature_k
            .unwrap(),
        305.0,
    );
    changed = n;
    changed.tolerances.rank_relative = 1e-11;
    assert_ne!(
        a.identity(),
        PreparedThermalNetwork::prepare(&changed, &Limits::default(), &c, None)
            .unwrap()
            .identity()
    );
}
#[test]
fn series_two_free_nodes_independent_formula_and_load_difference() {
    let mut i = input();
    i.network.nodes.insert(
        1,
        Node {
            id: "middle".into(),
            applied_heat_w: 0.0,
            fixed_temperature_k: None,
        },
    );
    i.network.links[0].to = "middle".into();
    i.network.links.push(Link {
        from: "middle".into(),
        to: "sink".into(),
        conductance_w_per_k: 4.0,
    });
    i.scenarios = vec![Scenario {
        id: "normal".into(),
        applied_heat_w: vec![8.0, 0.0, 0.0],
        fixed_temperature_k: vec![None, None, Some(300.0)],
    }];
    let c = AtomicBool::new(false);
    let out = thermal_scenarios(&i, &Limits::default(), &c).unwrap();
    near(
        out.scenarios[0].result.nodes[0].temperature_k.unwrap(),
        306.0,
    );
    near(
        out.scenarios[0].result.nodes[1].temperature_k.unwrap(),
        302.0,
    );
    near(out.sensitivities[0].temperature_derivative[0], 0.75);
    near(out.sensitivities[0].temperature_derivative[1], 0.25);
    near(out.sensitivities[1].temperature_derivative[0], -2.0);
    near(out.sensitivities[1].temperature_derivative[1], 0.0);
    let h = 1e-3;
    let mut plus = i.clone();
    plus.sensitivities.clear();
    plus.scenarios[0].applied_heat_w[0] += h;
    let p = thermal_scenarios(&plus, &Limits::default(), &c).unwrap();
    let mut minus = plus;
    minus.scenarios[0].applied_heat_w[0] -= 2.0 * h;
    let m = thermal_scenarios(&minus, &Limits::default(), &c).unwrap();
    for k in 0..3 {
        near(
            out.sensitivities[0].temperature_derivative[k],
            (p.scenarios[0].result.nodes[k].temperature_k.unwrap()
                - m.scenarios[0].result.nodes[k].temperature_k.unwrap())
                / (2.0 * h),
        );
    }
}
#[test]
fn default_host_32m_memory_and_shared_fuel_are_not_refreshed() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let context =
        ExecutionContext::new(1_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(32 * 1024 * 1024);
    let out = thermal_scenarios_with_context(&input(), &Limits::default(), &context).unwrap();
    assert!(context.memory().snapshot().live > 0);
    drop(out);
    assert_eq!(context.memory().snapshot().live, 0);
    let too_small = context.restricted_memory(1);
    assert!(thermal_scenarios_with_context(&input(), &Limits::default(), &too_small).is_err());
    let exhausted = context.restricted(1, Duration::from_secs(60)).unwrap();
    assert!(thermal_scenarios_with_context(&input(), &Limits::default(), &exhausted).is_err());
    assert!(exhausted.check().is_err());
}

#[test]
fn prepared_solve_respects_stricter_local_dimensions() {
    let control = AtomicBool::new(false);
    let prepared =
        PreparedThermalNetwork::prepare(&network(), &Limits::default(), &control, None).unwrap();
    let mut limits = Limits::default();
    limits.columns = 0;
    assert!(prepared
        .solve(&scenario("strict", 10.0, 300.0), &limits, &control)
        .is_err());
}
