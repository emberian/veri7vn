use oracle_science::{
    thermal::{Link, Node, ThermalInput},
    thermal_transient::*,
    Limits, Tolerances,
};
use std::sync::atomic::AtomicBool;
fn model() -> TransientInput {
    TransientInput {
        network: ThermalInput {
            description: "Supplied one-node thermal storage".into(),
            assumptions: vec![
                "constant capacity and positive conduction to an ideal reservoir".into(),
            ],
            reference_temperature_k: 300.0,
            nodes: vec![
                Node {
                    id: "body".into(),
                    applied_heat_w: 0.0,
                    fixed_temperature_k: None,
                },
                Node {
                    id: "sink".into(),
                    applied_heat_w: 0.0,
                    fixed_temperature_k: Some(300.0),
                },
            ],
            links: vec![Link {
                from: "body".into(),
                to: "sink".into(),
                conductance_w_per_k: 2.0,
            }],
            power_tolerance_w: 1e-8,
            tolerances: Tolerances::default(),
        },
        capacities_j_per_k: vec![10.0, 1.0],
        initial_temperature_k: vec![310.0, 300.0],
        duration_s: 10.0,
        loads: vec![LoadSegment {
            start_time_s: 0.0,
            applied_heat_w: vec![0.0, 0.0],
        }],
        sample_times_s: vec![5.0],
        events: vec![],
        integration: Integration {
            initial_step_s: 0.1,
            min_step_s: 1e-6,
            max_step_s: 0.1,
            absolute_tolerance_k: 1e-5,
            relative_tolerance: 0.0,
            max_steps: 8192,
        },
    }
}
fn run(input: &TransientInput) -> TransientResult {
    thermal_transient(input, &Limits::default(), &AtomicBool::new(false)).unwrap()
}
fn final_t(result: &TransientResult) -> f64 {
    result.samples.last().unwrap().temperature_k[0]
}
fn close(a: f64, b: f64, tolerance: f64) {
    assert!(
        (a - b).abs() <= tolerance,
        "{a} vs {b} tolerance {tolerance}"
    );
}
#[test]
fn exponential_cooling_and_original_global_energy() {
    let input = model();
    let result = run(&input);
    close(final_t(&result), 300.0 + 10.0 * (-2.0_f64).exp(), 0.01);
    assert_eq!(
        result.samples.iter().map(|s| s.time_s).collect::<Vec<_>>(),
        vec![0.0, 5.0, 10.0]
    );
    close(result.energy.global_balance_residual_j, 0.0, 1e-7);
    close(result.energy.internal_link_cancellation_j, 0.0, 1e-9);
    close(
        result.energy.storage_change_j,
        result.energy.reservoir_heat_j,
        1e-7,
    );
    assert!(result.diagnostics.maximum_accepted_local_error_ratio <= 1.0);
    assert!(result.diagnostics.factor_cache_hits > result.diagnostics.factorizations);
}
#[test]
fn fixed_step_refinement_converges_to_exponential() {
    let mut coarse = model();
    coarse.sample_times_s.clear();
    coarse.integration.absolute_tolerance_k = 1e6;
    coarse.integration.initial_step_s = 1.0;
    coarse.integration.max_step_s = 1.0;
    let mut fine = coarse.clone();
    fine.integration.initial_step_s = 0.5;
    fine.integration.max_step_s = 0.5;
    let c = run(&coarse);
    let f = run(&fine);
    let exact = 300.0 + 10.0 * (-2.0_f64).exp();
    assert!((final_t(&f) - exact).abs() < (final_t(&c) - exact).abs() * 0.6);
    let discrete = 300.0 + 10.0 * (1.0 + 0.5 / 5.0_f64).powi(-20);
    close(final_t(&c), discrete, 1e-9);
}
#[test]
fn isolated_positive_capacity_has_determined_initial_value_solution() {
    let mut input = model();
    input.network.links.clear();
    input.network.nodes[1].fixed_temperature_k = None;
    input.initial_temperature_k[1] = 280.0;
    input.loads[0].applied_heat_w = vec![2.0, -0.5];
    let result = run(&input);
    close(final_t(&result), 312.0, 1e-8);
    close(result.samples.last().unwrap().temperature_k[1], 275.0, 1e-8);
    close(result.energy.storage_change_j, 15.0, 1e-7);
    close(result.energy.applied_heat_j, 15.0, 1e-8);
    close(result.energy.global_balance_residual_j, 0.0, 1e-7);
}
#[test]
fn load_change_is_an_exact_time_boundary() {
    let mut input = model();
    input.network.links.clear();
    input.initial_temperature_k[0] = 300.0;
    input.duration_s = 4.0;
    input.sample_times_s = vec![1.25, 2.0];
    input.loads = vec![
        LoadSegment {
            start_time_s: 0.0,
            applied_heat_w: vec![10.0, 0.0],
        },
        LoadSegment {
            start_time_s: 1.25,
            applied_heat_w: vec![0.0, 0.0],
        },
    ];
    let result = run(&input);
    close(result.samples[1].time_s, 1.25, 0.0);
    for sample in result.samples.iter().skip(1) {
        close(sample.temperature_k[0], 301.25, 1e-8);
    }
    close(result.energy.applied_heat_j, 12.5, 1e-8);
}
#[test]
fn threshold_crossing_has_numerical_bracket_and_interpolant() {
    let mut input = model();
    input.initial_temperature_k[0] = 300.0;
    input.loads[0].applied_heat_w[0] = 20.0;
    input.events = vec![ThresholdEvent {
        id: "warm".into(),
        node_id: "body".into(),
        temperature_k: 305.0,
        direction: Direction::Rising,
    }];
    let result = run(&input);
    assert_eq!(result.events.len(), 1);
    let hit = &result.events[0];
    assert!(hit.bracket_s[0] <= hit.linear_estimate_s && hit.linear_estimate_s <= hit.bracket_s[1]);
    close(hit.linear_estimate_s, 5.0 * 2.0_f64.ln(), 0.02);
    assert!(hit.endpoint_temperature_k[0] < 305.0 && hit.endpoint_temperature_k[1] >= 305.0);
}
#[test]
fn fixed_reservoir_load_has_heat_but_no_storage_change() {
    let mut input = model();
    input.network.nodes[0].fixed_temperature_k = Some(310.0);
    input.loads[0].applied_heat_w = vec![3.0, 4.0];
    let result = run(&input);
    assert_eq!(
        result.samples.last().unwrap().temperature_k,
        vec![310.0, 300.0]
    );
    assert_eq!(result.diagnostics.factorizations, 0);
    close(result.energy.storage_change_j, 0.0, 0.0);
    close(result.energy.applied_heat_j, 70.0, 1e-8);
    close(result.energy.reservoir_heat_j, -70.0, 1e-8);
    close(
        result.energy.nodes[0].reservoir_heat_j.unwrap(),
        170.0,
        1e-8,
    );
    close(
        result.energy.nodes[1].reservoir_heat_j.unwrap(),
        -240.0,
        1e-8,
    );
}
#[test]
fn capacities_must_be_positive_even_at_fixed_nodes() {
    for capacity in [0.0, -1.0, f64::INFINITY] {
        let mut input = model();
        input.capacities_j_per_k[1] = capacity;
        assert!(thermal_transient(&input, &Limits::default(), &AtomicBool::new(false)).is_err());
    }
}
#[test]
fn invalid_boundary_initial_and_load_order_refused() {
    let mut input = model();
    input.initial_temperature_k[1] = 301.0;
    assert!(thermal_transient(&input, &Limits::default(), &AtomicBool::new(false)).is_err());
    let mut input = model();
    input.loads.push(input.loads[0].clone());
    assert!(thermal_transient(&input, &Limits::default(), &AtomicBool::new(false)).is_err());
}
#[test]
fn exhaustion_is_not_a_complete_trajectory() {
    let mut input = model();
    input.integration.max_steps = 1;
    assert!(thermal_transient(&input, &Limits::default(), &AtomicBool::new(false)).is_err());
    let mut limits = Limits::default();
    limits.work = 1;
    assert!(thermal_transient(&model(), &limits, &AtomicBool::new(false)).is_err());
}
#[test]
fn positive_capacity_two_node_closed_system_conserves_energy() {
    let mut input = model();
    input.network.nodes[1].fixed_temperature_k = None;
    input.capacities_j_per_k = vec![10.0, 10.0];
    input.initial_temperature_k = vec![310.0, 290.0];
    let result = run(&input);
    let end = &result.samples.last().unwrap().temperature_k;
    close(end[0] + end[1], 600.0, 1e-7);
    close(end[0], 300.0 + 10.0 * (-4.0_f64).exp(), 0.01);
    close(result.energy.global_balance_residual_j, 0.0, 1e-7);
}
#[test]
fn shared_context_ledger_and_cancellation() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let context =
        ExecutionContext::new(5_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(32 * 1024 * 1024);
    let result = thermal_transient_with_context(&model(), &Limits::default(), &context).unwrap();
    assert!(context.memory().snapshot().live > 0);
    drop(result);
    assert_eq!(context.memory().snapshot().live, 0);
    context.cancellation().cancel();
    let error = thermal_transient_with_context(&model(), &Limits::default(), &context)
        .err()
        .unwrap();
    assert_eq!(error.code(), "cancelled");
}

#[test]
fn typed_and_wire_transient_dispatch_agree() {
    let input = model();
    let cancel = AtomicBool::new(false);
    let typed = oracle_science::execute(
        &oracle_science::ScientificRequest::ThermalTransient(input.clone()),
        &Limits::default(),
        &cancel,
    )
    .unwrap();
    let request = serde_json::json!({"operation":"science.thermal_transient","arguments":input});
    let wire = oracle_science::call(&request.to_string(), &Limits::default(), &cancel).unwrap();
    let wire: serde_json::Value = serde_json::from_str(&wire).unwrap();
    assert_eq!(serde_json::to_value(typed).unwrap(), wire);
    assert!(oracle_science::catalog()["operations"]
        .as_array()
        .unwrap()
        .iter()
        .any(|op| op == "science.thermal_transient"));
}

#[test]
fn typed_preflight_refuses_before_serialization_or_memory_reservation() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let context =
        ExecutionContext::new(1_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(1);
    let mut oversized = model();
    oversized.network.nodes = vec![oversized.network.nodes[0].clone(); MAX_NODES + 1];
    let error = thermal_transient_with_context(&oversized, &Limits::default(), &context)
        .err()
        .unwrap();
    assert!(error.to_string().contains("typed shape bounds"));
    assert_eq!(context.memory().snapshot().peak, 0);
    let mut oversized = model();
    oversized.network.description = "x".repeat(2048);
    let error = thermal_transient_with_context(&oversized, &Limits::default(), &context)
        .err()
        .unwrap();
    assert!(error.to_string().contains("typed text bounds"));
    assert_eq!(context.memory().snapshot().peak, 0);
    let error = thermal_transient_with_context(&model(), &Limits::default(), &context)
        .err()
        .unwrap();
    assert!(error.to_string().contains("shared transient memory"));
    assert_eq!(context.memory().snapshot().peak, 0);
}
#[test]
fn bounded_typed_serialization_and_content_identity() {
    let mut limits = Limits::default();
    limits.request_bytes = 64;
    assert!(
        thermal_transient(&model(), &limits, &AtomicBool::new(false))
            .err()
            .unwrap()
            .to_string()
            .contains("serialization bytes")
    );
    let original = run(&model());
    let mut changed = model();
    changed.network.links[0].conductance_w_per_k = 3.0;
    assert_ne!(original.model_identity, run(&changed).model_identity);
    assert_eq!(original.identity_encoding, "thermal-canonical-binary64-v1");
}
