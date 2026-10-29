use oracle_science::thermal::{
    thermal_network, Link, Node, ThermalInput, ThermalOutcome, ThermalResult,
};
use oracle_science::{call, Error, Limits, Tolerances};
use std::sync::atomic::AtomicBool;

fn node(id: &str, heat: f64, fixed: Option<f64>) -> Node {
    Node {
        id: id.into(),
        applied_heat_w: heat,
        fixed_temperature_k: fixed,
    }
}
fn link(a: &str, b: &str, g: f64) -> Link {
    Link {
        from: a.into(),
        to: b.into(),
        conductance_w_per_k: g,
    }
}
fn network(nodes: Vec<Node>, links: Vec<Link>) -> ThermalInput {
    ThermalInput {
        description: "authored passive steady thermal network".into(),
        assumptions: vec!["steady state; fixed linear conductances; all heat sources and boundary reservoirs supplied".into()],
        reference_temperature_k: 300.0, nodes, links,
        power_tolerance_w: 1e-8, tolerances: Tolerances::default(),
    }
}
fn run(p: &ThermalInput) -> ThermalResult {
    thermal_network(p, &Limits::default(), &AtomicBool::new(false)).unwrap()
}
fn close(a: f64, b: f64, tol: f64) {
    assert!((a - b).abs() < tol, "{a} versus {b}");
}
fn two_free() -> ThermalInput {
    network(
        vec![
            node("ambient", 0.0, Some(300.0)),
            node("a", 20.0, None),
            node("b", 10.0, None),
        ],
        vec![
            link("a", "b", 1.0),
            link("a", "ambient", 2.0),
            link("b", "ambient", 1.0),
        ],
    )
}

#[test]
fn two_coupled_nodes_construct_matrix_and_close_original_power_balances() {
    let p = two_free();
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
    close(r.nodes[1].temperature_k.unwrap(), 310.0, 1e-10);
    close(r.nodes[2].temperature_k.unwrap(), 310.0, 1e-10);
    assert_eq!(r.expected_rank_from_topology, 2);
    assert!(r.nodes.iter().all(|n| n.power_balance_within_tolerance));
    close(r.nodes[0].boundary_exchange_w.unwrap(), -30.0, 1e-10);
    close(r.conservation.net_external_heat_w, 0.0, 1e-10);
    close(r.conservation.internal_link_cancellation_w, 0.0, 1e-10);
    let solver = r.linear_diagnostics.unwrap();
    assert_eq!(solver.model.row_units, vec!["W"; 2]);
    assert_eq!(solver.diagnostics.numerical_rank, 2);
}

#[test]
fn larger_chain_matches_constant_heat_flow_and_signed_source() {
    let p = network(
        vec![
            node("outside", 0.0, Some(300.0)),
            node("one", 0.0, None),
            node("two", 0.0, None),
            node("three", 0.0, None),
            node("four", 20.0, None),
        ],
        vec![
            link("outside", "one", 2.0),
            link("one", "two", 2.0),
            link("two", "three", 2.0),
            link("three", "four", 2.0),
        ],
    );
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
    for (n, t) in r.nodes.iter().zip([300.0, 310.0, 320.0, 330.0, 340.0]) {
        close(n.temperature_k.unwrap(), t, 1e-9);
    }
    for edge in r.links {
        close(edge.candidate_heat_from_to_w, -20.0, 1e-9);
    }
    close(r.conservation.total_boundary_exchange_w, -20.0, 1e-9);
    let cooling = network(
        vec![
            node("reservoir", 0.0, Some(300.0)),
            node("cooled", -20.0, None),
        ],
        vec![link("cooled", "reservoir", 2.0)],
    );
    let r = run(&cooling);
    close(r.nodes[1].temperature_k.unwrap(), 290.0, 1e-10);
    close(r.nodes[0].boundary_exchange_w.unwrap(), 20.0, 1e-10);
}

#[test]
fn a_coordinate_reference_is_not_a_hidden_boundary() {
    let p = network(
        vec![node("a", 10.0, None), node("b", -10.0, None)],
        vec![link("a", "b", 2.0)],
    );
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::UnderdeterminedWithinTolerance);
    assert!(r
        .nodes
        .iter()
        .all(|n| n.temperature_k.is_none() && n.candidate_temperature_k.is_none()));
    close(
        r.nodes[0].candidate_offset_k - r.nodes[1].candidate_offset_k,
        5.0,
        1e-10,
    );
    close(r.links[0].candidate_heat_from_to_w, 10.0, 1e-10);
    assert_eq!(r.expected_rank_from_topology, 1);
    assert_eq!(
        r.components[0].floating_source_balance_within_tolerance,
        Some(true)
    );
    let mut q = p;
    q.reference_temperature_k = 1000.0;
    let s = run(&q);
    close(
        s.links[0].candidate_heat_from_to_w,
        r.links[0].candidate_heat_from_to_w,
        1e-12,
    );
    assert!(s.nodes.iter().all(|n| n.temperature_k.is_none()));
}

#[test]
fn a_floating_component_with_net_heat_has_no_steady_balance() {
    let r = run(&network(
        vec![node("a", 10.0, None), node("b", -5.0, None)],
        vec![link("a", "b", 2.0)],
    ));
    assert_eq!(r.outcome, ThermalOutcome::InconsistentWithinTolerance);
    assert_eq!(
        r.components[0].floating_source_balance_within_tolerance,
        Some(false)
    );
    close(r.components[0].net_applied_heat_w, 5.0, 1e-12);
    assert!(r.nodes.iter().all(|n| n.temperature_k.is_none()));
    assert!(r.nodes.iter().any(|n| !n.power_balance_within_tolerance));
}

#[test]
fn disconnected_island_does_not_receive_an_invented_absolute_temperature() {
    let mut p = two_free();
    p.nodes.push(node("island", 0.0, None));
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::UnderdeterminedWithinTolerance);
    assert_eq!(r.components.len(), 2);
    assert_eq!(r.expected_rank_from_topology, 2);
    close(r.nodes[1].temperature_k.unwrap(), 310.0, 1e-9);
    assert_eq!(r.nodes[3].temperature_k, None);
    let mut q = p;
    q.nodes[3].applied_heat_w = 1.0;
    let r = run(&q);
    assert_eq!(r.outcome, ThermalOutcome::InconsistentWithinTolerance);
    assert_eq!(
        r.components[1].floating_source_balance_within_tolerance,
        Some(false)
    );
}

#[test]
fn isolated_free_node_distinguishes_ambiguous_and_inconsistent() {
    let mut p = network(vec![node("alone", 0.0, None)], vec![]);
    assert_eq!(
        run(&p).outcome,
        ThermalOutcome::UnderdeterminedWithinTolerance
    );
    p.nodes[0].applied_heat_w = -1.0;
    assert_eq!(run(&p).outcome, ThermalOutcome::InconsistentWithinTolerance);
}

#[test]
fn prescribed_boundaries_report_reservoir_exchange_not_conflicting_constraints() {
    let p = network(
        vec![
            node("cold", 5.0, Some(300.0)),
            node("hot", 0.0, Some(310.0)),
        ],
        vec![link("cold", "hot", 2.0)],
    );
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
    assert!(r.linear_diagnostics.is_none());
    close(r.nodes[0].boundary_exchange_w.unwrap(), -25.0, 1e-12);
    close(r.nodes[1].boundary_exchange_w.unwrap(), 20.0, 1e-12);
    close(r.conservation.net_external_heat_w, 0.0, 1e-12);
}

#[test]
fn coordinate_reference_changes_do_not_change_grounded_temperatures() {
    let p = two_free();
    for reference in [0.0, 273.15, 300.0, 320.0] {
        let mut q = p.clone();
        q.reference_temperature_k = reference;
        let r = run(&q);
        assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
        close(r.nodes[1].temperature_k.unwrap(), 310.0, 1e-9);
        close(r.nodes[2].temperature_k.unwrap(), 310.0, 1e-9);
    }
}

#[test]
fn two_different_reservoirs_give_conductance_weighted_temperature() {
    let p = network(
        vec![
            node("cold", 0.0, Some(290.0)),
            node("hot", 0.0, Some(310.0)),
            node("free", 0.0, None),
        ],
        vec![link("free", "cold", 1.0), link("free", "hot", 3.0)],
    );
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
    close(r.nodes[2].temperature_k.unwrap(), 305.0, 1e-10);
    close(r.nodes[0].boundary_exchange_w.unwrap(), -15.0, 1e-10);
    close(r.nodes[1].boundary_exchange_w.unwrap(), 15.0, 1e-10);
}

#[test]
fn original_boundary_evidence_detects_loss_from_a_pathological_reference() {
    let mut p = network(
        vec![node("fixed", 0.0, Some(300.0)), node("free", 0.0, None)],
        vec![link("free", "fixed", 1.0)],
    );
    p.reference_temperature_k = 1e20;
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::InconsistentWithinTolerance);
    assert!(!r.nodes[1].power_balance_within_tolerance);
    assert!(r.nodes.iter().all(|n| n.temperature_k.is_none()));
}

#[test]
fn zero_source_equal_temperature_is_accepted_despite_roundoff() {
    let p = network(
        vec![node("fixed", 0.0, Some(293.15)), node("free", 0.0, None)],
        vec![link("fixed", "free", 3.0)],
    );
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
    close(r.nodes[1].temperature_k.unwrap(), 293.15, 1e-10);
}

#[test]
fn negative_absolute_temperature_candidate_is_never_promoted() {
    let p = network(
        vec![node("fixed", 0.0, Some(1.0)), node("free", -2.0, None)],
        vec![link("free", "fixed", 1.0)],
    );
    let r = run(&p);
    assert_eq!(r.outcome, ThermalOutcome::BelowAbsoluteZeroCandidate);
    close(r.nodes[1].candidate_temperature_k.unwrap(), -1.0, 1e-10);
    assert!(r.nodes.iter().all(|n| n.temperature_k.is_none()));
}

#[test]
fn topology_rank_check_catches_a_dropped_grounded_direction() {
    let p = network(
        vec![
            node("fixed", 0.0, Some(300.0)),
            node("strong", 0.0, None),
            node("weak", 0.0, None),
        ],
        vec![link("fixed", "strong", 1.0), link("fixed", "weak", 1e-14)],
    );
    let r = run(&p);
    assert_eq!(r.expected_rank_from_topology, 2);
    assert_eq!(
        r.linear_diagnostics
            .as_ref()
            .unwrap()
            .diagnostics
            .numerical_rank,
        1
    );
    assert_eq!(r.outcome, ThermalOutcome::NumericalRankUnresolved);
    assert!(r.nodes.iter().all(|n| n.temperature_k.is_none()));
}

#[test]
fn zero_negative_nonfinite_conductances_require_explicit_model_repair() {
    for g in [0.0, -1.0, f64::NAN, f64::INFINITY] {
        let mut p = two_free();
        p.links[0].conductance_w_per_k = g;
        assert!(matches!(
            thermal_network(&p, &Limits::default(), &AtomicBool::new(false)),
            Err(Error::Invalid(_))
        ));
    }
}

#[test]
fn conflicting_definitions_unknown_endpoints_and_duplicate_links_are_rejected() {
    let mut duplicate_node = two_free();
    duplicate_node.nodes.push(node("ambient", 0.0, Some(400.0)));
    let mut duplicate_link = two_free();
    duplicate_link.links.push(link("b", "a", 10.0));
    let mut self_link = two_free();
    self_link.links.push(link("a", "a", 1.0));
    let mut unknown = two_free();
    unknown.links[0].from = "absent".into();
    let mut bad_boundary = two_free();
    bad_boundary.nodes[0].fixed_temperature_k = Some(-1.0);
    let mut nonfinite_source = two_free();
    nonfinite_source.nodes[1].applied_heat_w = f64::INFINITY;
    for p in [
        duplicate_node,
        duplicate_link,
        self_link,
        unknown,
        bad_boundary,
        nonfinite_source,
    ] {
        assert!(matches!(
            thermal_network(&p, &Limits::default(), &AtomicBool::new(false)),
            Err(Error::Invalid(_))
        ));
    }
}

#[test]
fn thermal_json_dispatch_preserves_numeric_literals_and_model_assumptions() {
    let json = serde_json::json!({"operation":"science.thermal_network","arguments":two_free()})
        .to_string();
    let reply = call(&json, &Limits::default(), &AtomicBool::new(false)).unwrap();
    let r: ThermalResult = serde_json::from_str(&reply).unwrap();
    assert_eq!(r.operation, "science.thermal_network");
    assert_eq!(r.assumptions.len(), 1);
    assert_eq!(r.outcome, ThermalOutcome::SolvedWithinTolerance);
}

#[test]
fn thermal_size_and_cancellation_policy_is_bounded() {
    let p = two_free();
    assert!(matches!(
        thermal_network(&p, &Limits::default(), &AtomicBool::new(true)),
        Err(Error::Cancelled)
    ));
    assert!(matches!(
        thermal_network(
            &p,
            &Limits {
                work: 1,
                ..Default::default()
            },
            &AtomicBool::new(false)
        ),
        Err(Error::Limit(_))
    ));
    let p = network(
        (0..129)
            .map(|i| node(&format!("node{i}"), 0.0, None))
            .collect(),
        vec![],
    );
    assert!(matches!(
        thermal_network(&p, &Limits::default(), &AtomicBool::new(false)),
        Err(Error::Limit(_))
    ));
    let p = network(
        vec![node("a", 0.0, None), node("b", 0.0, None)],
        vec![link("a", "b", 1.0); 1025],
    );
    assert!(matches!(
        thermal_network(&p, &Limits::default(), &AtomicBool::new(false)),
        Err(Error::Limit(_))
    ));
}
