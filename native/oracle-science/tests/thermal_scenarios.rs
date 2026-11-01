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

#[test]
fn typed_batch_preflight_precedes_serialization_and_reservation() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let context =
        ExecutionContext::new(1_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(1);
    let mut oversized = input();
    oversized.network.description = " ".repeat(2048);
    let error = thermal_scenarios_with_context(&oversized, &Limits::default(), &context)
        .err()
        .unwrap();
    assert!(error.to_string().contains("typed text bounds"));
    assert_eq!(context.memory().snapshot().peak, 0);
    let mut oversized = input();
    oversized.scenarios[0].applied_heat_w = vec![0.0; 1024];
    let error = thermal_scenarios_with_context(&oversized, &Limits::default(), &context)
        .err()
        .unwrap();
    assert!(error.to_string().contains("typed scenario vectors"));
    assert_eq!(context.memory().snapshot().peak, 0);
    let mut oversized = input();
    oversized.network.nodes =
        vec![oversized.network.nodes[0].clone(); oracle_science::thermal::MAX_NODES + 1];
    let error = thermal_scenarios_with_context(&oversized, &Limits::default(), &context)
        .err()
        .unwrap();
    assert!(error.to_string().contains("typed topology bounds"));
    assert_eq!(context.memory().snapshot().peak, 0);
}

#[test]
fn prepared_typed_preflight_and_serialization_have_live_guards() {
    use oracle_execution::MemoryBudget;
    let control = AtomicBool::new(false);
    let tiny = MemoryBudget::new(1);
    let mut oversized = network();
    oversized.description = " ".repeat(2048);
    let error =
        PreparedThermalNetwork::prepare(&oversized, &Limits::default(), &control, Some(&tiny))
            .err()
            .unwrap();
    assert!(error.to_string().contains("typed text bounds"));
    assert_eq!(tiny.snapshot().peak, 0);
    let error =
        PreparedThermalNetwork::prepare(&network(), &Limits::default(), &control, Some(&tiny))
            .err()
            .unwrap();
    assert!(error.to_string().contains("shared thermal memory"));
    assert_eq!(tiny.snapshot().peak, 0);
    let budget = MemoryBudget::new(8 * 1024 * 1024);
    let mut limits = Limits::default();
    limits.request_bytes = 64;
    let error = PreparedThermalNetwork::prepare(&network(), &limits, &control, Some(&budget))
        .err()
        .unwrap();
    assert!(error.to_string().contains("bounded serialization bytes"));
    // Capped counting can refuse an oversized encoding without allocating it.
    assert_eq!(budget.snapshot().peak, 0);
    assert_eq!(budget.snapshot().live, 0);
}

#[test]
fn escaped_text_obeys_original_byte_cap_without_new_cutoff() {
    let control = AtomicBool::new(false);
    let mut n = network();
    n.description = "\u{0001}".repeat(1024);
    assert!(PreparedThermalNetwork::prepare(&n, &Limits::default(), &control, None).is_ok());
    let mut limits = Limits::default();
    limits.request_bytes = 1024;
    let error = PreparedThermalNetwork::prepare(&n, &limits, &control, None)
        .err()
        .unwrap();
    assert!(error.to_string().contains("bounded serialization bytes"));
    let mut batch = input();
    batch.network = n;
    let error = thermal_scenarios(&batch, &limits, &control).err().unwrap();
    assert!(error.to_string().contains("bounded serialization bytes"));
}

#[test]
fn repeated_scenario_declarations_stay_charged_after_preparation_drops() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let mut batch = input();
    batch.network.description = "d".repeat(1024);
    batch.network.assumptions = vec!["a".repeat(1024); 32];
    batch.sensitivities.clear();
    batch.scenarios = (0..64)
        .map(|i| scenario(&format!("scenario-{i}"), 10.0, 300.0))
        .collect();
    let context =
        ExecutionContext::new(1_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(32 * 1024 * 1024);
    let result = thermal_scenarios_with_context(&batch, &Limits::default(), &context).unwrap();
    let declaration_payload = (1024 + 32 * 1024) * 64;
    assert!(context.memory().snapshot().live >= declaration_payload);
    drop(result);
    assert_eq!(context.memory().snapshot().live, 0);
}
#[test]
fn actual_small_encoding_does_not_require_a_full_request_cap_reservation() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let context =
        ExecutionContext::new(1_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(1024 * 1024);
    let result = thermal_scenarios_with_context(&input(), &Limits::default(), &context).unwrap();
    assert!(context.memory().snapshot().live < 1024 * 1024);
    drop(result);
    assert_eq!(context.memory().snapshot().live, 0);
}

#[test]
fn cross_request_prepared_cache_reuses_factors_and_bounds_entries() {
    use oracle_execution::{Cancellation, ExecutionContext};
    use std::time::Duration;
    let cache = PreparedThermalCache::new(2, 8 * 1024 * 1024);
    let context =
        ExecutionContext::new(1_000_000, Duration::from_secs(60), Cancellation::default())
            .unwrap()
            .restricted_memory(4 * 1024 * 1024);
    let first =
        thermal_scenarios_with_cache(&input(), &Limits::default(), &context, &cache).unwrap();
    assert!(!first.factor_cache_hit);
    assert_eq!(cache.stats().misses, 1);
    assert_eq!(cache.stats().hits, 0);
    assert_eq!(cache.stats().entries, 1);
    let first_network_id = first.network_identity.clone();
    let first_template_id = first.template_identity.clone();
    drop(first);
    assert_eq!(context.memory().snapshot().live, 0);
    assert!(cache.stats().live_bytes > 0);

    // Changing only base loads preserves template_identity and hits the prepared factor cache.
    let mut second_input = input();
    second_input.network.nodes[0].applied_heat_w = 500.0;
    let second =
        thermal_scenarios_with_cache(&second_input, &Limits::default(), &context, &cache).unwrap();
    assert!(second.factor_cache_hit);
    assert_eq!(second.template_identity, first_template_id);
    assert_ne!(second.network_identity, first_network_id);
    assert_eq!(cache.stats().hits, 1);
    assert_eq!(cache.stats().misses, 1);
    near(
        second.scenarios[0].result.nodes[0].temperature_k.unwrap(),
        305.0,
    );
    drop(second);

    // Changing conductances alters the operator/template and bounded capacity evicts LRU entries.
    let mut third_input = input();
    third_input.network.links[0].conductance_w_per_k = 4.0;
    let third =
        thermal_scenarios_with_cache(&third_input, &Limits::default(), &context, &cache).unwrap();
    assert!(!third.factor_cache_hit);
    assert_eq!(cache.stats().entries, 2);

    let mut fourth_input = input();
    fourth_input.network.links[0].conductance_w_per_k = 8.0;
    let fourth =
        thermal_scenarios_with_cache(&fourth_input, &Limits::default(), &context, &cache).unwrap();
    assert!(!fourth.factor_cache_hit);
    assert_eq!(cache.stats().entries, 2);
    assert_eq!(cache.stats().evictions, 1);
    drop((third, fourth));
}

#[test]
fn oversized_cache_entry_keeps_request_custody_until_last_reader_drops() {
    use oracle_execution::MemoryBudget;
    let cache = PreparedThermalCache::new(1, 1);
    let memory = MemoryBudget::new(4 * 1024 * 1024);
    let control = AtomicBool::new(false);
    let (prepared, _, hit) = cache
        .get_or_prepare(&network(), &Limits::default(), &control, Some(&memory))
        .unwrap();
    assert!(!hit);
    assert_eq!(cache.stats().entries, 0);
    assert_eq!(cache.stats().live_bytes, 0);
    assert!(memory.snapshot().live > 0);
    let reader = prepared.clone();
    drop(prepared);
    near(
        reader
            .solve(
                &scenario("retained", 10.0, 300.0),
                &Limits::default(),
                &control,
            )
            .unwrap()
            .nodes[0]
            .temperature_k
            .unwrap(),
        305.0,
    );
    assert!(memory.snapshot().live > 0);
    drop(reader);
    assert_eq!(memory.snapshot().live, 0);
}

#[test]
fn cached_owner_does_not_reveal_a_previous_callers_base_rhs_identity() {
    let cache = PreparedThermalCache::new(1, 4 * 1024 * 1024);
    let control = AtomicBool::new(false);
    let first_input = network();
    let mut second_input = first_input.clone();
    second_input.nodes[0].applied_heat_w = 12345.0;
    second_input.nodes[1].fixed_temperature_k = Some(456.0);
    let (first, first_id, _) = cache
        .get_or_prepare(&first_input, &Limits::default(), &control, None)
        .unwrap();
    let (second, second_id, hit) = cache
        .get_or_prepare(&second_input, &Limits::default(), &control, None)
        .unwrap();
    assert!(hit);
    assert!(std::sync::Arc::ptr_eq(&first, &second));
    assert_ne!(first_id, second_id);
    let mut normalized = second_input;
    for node in &mut normalized.nodes {
        node.applied_heat_w = 0.0;
        node.fixed_temperature_k = node.fixed_temperature_k.map(|_| 0.0);
    }
    let canonical =
        PreparedThermalNetwork::prepare(&normalized, &Limits::default(), &control, None).unwrap();
    assert_eq!(second.identity(), canonical.identity());
    assert_ne!(second.identity(), first_id);
}

#[test]
fn warm_cache_obeys_topology_limits_and_cold_result_evidence() {
    let control = AtomicBool::new(false);
    let cache = PreparedThermalCache::new(2, 4 * 1024 * 1024);
    let (prepared, _, _) = cache
        .get_or_prepare(&network(), &Limits::default(), &control, None)
        .unwrap();
    let direct =
        PreparedThermalNetwork::prepare(&network(), &Limits::default(), &control, None).unwrap();
    assert_eq!(
        serde_json::to_value(
            prepared
                .solve(&scenario("x", 10.0, 300.0), &Limits::default(), &control)
                .unwrap()
        )
        .unwrap(),
        serde_json::to_value(
            direct
                .solve(&scenario("x", 10.0, 300.0), &Limits::default(), &control)
                .unwrap()
        )
        .unwrap()
    );
    let mut strict = Limits::default();
    strict.work = 1; // Cubic factor work is one, but two nodes plus one link is three.
    assert!(cache
        .get_or_prepare(&network(), &strict, &control, None)
        .is_err());
    assert!(PreparedThermalNetwork::prepare(&network(), &strict, &control, None).is_err());
    strict = Limits::default();
    strict.rows = 0;
    assert!(cache
        .get_or_prepare(&network(), &strict, &control, None)
        .is_err());
    strict = Limits::default();
    strict.scratch_bytes = 0;
    assert_eq!(
        cache
            .get_or_prepare(&network(), &strict, &control, None)
            .is_err(),
        PreparedThermalNetwork::prepare(&network(), &strict, &control, None).is_err()
    );
}
