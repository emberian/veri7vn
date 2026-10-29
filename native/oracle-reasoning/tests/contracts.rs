use oracle_reasoning::{
    algebra::{equivalent, optimize, PolynomialInput},
    call,
    graph::{check_forest, minimum_spanning_forest, GraphInput},
    Limits,
};

fn closure(input: &GraphInput, ids: &[usize]) -> Vec<Vec<bool>> {
    let n = input.vertices;
    let mut reachable = vec![vec![false; n]; n];
    for (i, row) in reachable.iter_mut().enumerate() {
        row[i] = true;
    }
    for &id in ids {
        let (a, b, _) = input.edges[id];
        reachable[a][b] = true;
        reachable[b][a] = true;
    }
    for k in 0..n {
        for a in 0..n {
            for b in 0..n {
                reachable[a][b] |= reachable[a][k] && reachable[k][b];
            }
        }
    }
    reachable
}

#[test]
fn forests_and_checker_agree_with_exhaustive_subsets() {
    let limits = Limits::default();
    let mut seed = 129_u64;
    for _ in 0..128 {
        let mut input = GraphInput {
            vertices: 4,
            edges: vec![],
        };
        for _ in 0..7 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            input.edges.push((
                (seed >> 32) as usize % 4,
                (seed >> 40) as usize % 4,
                ((seed >> 48) % 9) as i64 - 4,
            ));
        }
        let all = closure(&input, &(0..input.edges.len()).collect::<Vec<_>>());
        let components = (0..4).filter(|&a| !(0..a).any(|b| all[a][b])).count();
        let mut candidates = Vec::new();
        for mask in 0usize..(1 << input.edges.len()) {
            let ids: Vec<_> = (0..input.edges.len())
                .filter(|&i| (mask >> i) & 1 != 0)
                .collect();
            // Matching component coverage and V-C edges characterize a forest.
            if ids.len() == 4 - components && closure(&input, &ids) == all {
                let weight: i128 = ids.iter().map(|&i| i128::from(input.edges[i].2)).sum();
                candidates.push((weight, ids));
            }
        }
        let best = candidates.iter().map(|x| x.0).min().unwrap();
        let result = minimum_spanning_forest(&input, &limits).unwrap();
        assert_eq!(result.total_weight, best.to_string());
        assert_eq!(result.components, components);
        for mask in 0usize..(1 << input.edges.len()) {
            let ids: Vec<_> = (0..input.edges.len())
                .filter(|&i| (mask >> i) & 1 != 0)
                .collect();
            let expected = candidates
                .iter()
                .any(|(w, candidate)| *w == best && *candidate == ids);
            assert_eq!(
                check_forest(&input, &ids, &limits).is_ok(),
                expected,
                "{input:?}: {ids:?}"
            );
        }
    }
}

#[test]
fn disconnected_isolated_parallel_negative_and_exact_large_weights() {
    let limits = Limits::default();
    let input = GraphInput {
        vertices: 5,
        edges: vec![
            (0, 1, i64::MAX),
            (0, 1, i64::MAX - 1),
            (1, 2, i64::MAX),
            (0, 0, i64::MIN),
            (3, 3, -10),
        ],
    };
    let result = minimum_spanning_forest(&input, &limits).unwrap();
    assert_eq!(result.edge_ids, vec![1, 2]);
    assert_eq!(
        result.total_weight,
        (2 * i128::from(i64::MAX) - 1).to_string()
    );
    assert_eq!(result.components, 3);
    assert!(!result.connected);
    let negative = GraphInput {
        vertices: 3,
        edges: vec![(0, 1, i64::MIN), (1, 2, -3), (0, 2, -2)],
    };
    assert_eq!(
        minimum_spanning_forest(&negative, &limits)
            .unwrap()
            .edge_ids,
        vec![0, 1]
    );
}

#[test]
fn forest_rejects_invalid_and_tampered_candidates() {
    let limits = Limits::default();
    let input = GraphInput {
        vertices: 3,
        edges: vec![(0, 1, 1), (1, 2, 2), (0, 2, 5)],
    };
    for ids in [
        vec![],
        vec![0],
        vec![0, 0],
        vec![1, 2],
        vec![0, 1, 2],
        vec![8],
    ] {
        assert!(check_forest(&input, &ids, &limits).is_err());
    }
    assert!(minimum_spanning_forest(
        &GraphInput {
            vertices: 2,
            edges: vec![(0, 2, 1)]
        },
        &limits
    )
    .is_err());
    assert!(minimum_spanning_forest(
        &input,
        &Limits {
            vertices: 2,
            ..limits
        }
    )
    .is_err());
}

#[test]
fn empty_singleton_and_deep_tree_are_explicit() {
    let limits = Limits::default();
    let empty = minimum_spanning_forest(
        &GraphInput {
            vertices: 0,
            edges: vec![],
        },
        &limits,
    )
    .unwrap();
    assert_eq!(empty.components, 0);
    assert!(!empty.connected);
    assert!(
        minimum_spanning_forest(
            &GraphInput {
                vertices: 1,
                edges: vec![]
            },
            &limits
        )
        .unwrap()
        .connected
    );
    let input = GraphInput {
        vertices: 10_000,
        edges: (1..10_000).map(|i| (i - 1, i, -1)).collect(),
    };
    assert_eq!(
        minimum_spanning_forest(&input, &limits)
            .unwrap()
            .total_weight,
        "-9999"
    );
}

#[test]
fn factor_and_check_without_sampling_or_global_optimality_claim() {
    let limits = Limits::default();
    let input = PolynomialInput {
        expression: "(+ (* x y) (* x z))".into(),
    };
    let result = optimize(&input, &limits).unwrap();
    assert!(result.selected_cost < result.original_cost);
    assert!(equivalent(&input.expression, &result.expression, &limits).unwrap());
    assert_eq!(result.polynomial_terms, 2);
    assert!(!equivalent("(* x x)", "x", &limits).unwrap()); // agrees at 0 and 1, still false
    assert!(!equivalent("(+ x 1)", "(+ x 2)", &limits).unwrap());
}

#[test]
fn exact_identities_and_generated_distributivity() {
    let limits = Limits::default();
    for (a, b) in [
        ("(- (* x x) (* x x))", "0"),
        ("(* (+ x 1) (- x 1))", "(- (* x x) 1)"),
        (
            "(* 9223372036854775807 2)",
            "(+ 9223372036854775807 9223372036854775807)",
        ),
    ] {
        assert!(equivalent(a, b, &limits).unwrap());
    }
    for k in -8..=8 {
        let source = format!("(+ (* {k} x) (* {k} y))");
        let target = format!("(* {k} (+ x y))");
        assert!(equivalent(&source, &target, &limits).unwrap());
        let result = optimize(
            &PolynomialInput {
                expression: source.clone(),
            },
            &limits,
        )
        .unwrap();
        assert!(equivalent(&result.expression, &target, &limits).unwrap());
        assert!(result.selected_cost <= result.original_cost);
    }
}

#[test]
fn reject_partial_or_float_semantics_and_expansion_budgets() {
    let limits = Limits::default();
    for source in [
        "",
        "(/ x x)",
        "1.5",
        "NaN!",
        "9223372036854775808",
        "(+ x)",
        "(+ x y))",
    ] {
        assert!(equivalent(source, "1", &limits).is_err(), "{source}");
    }
    assert!(equivalent(
        "(* (+ a b) (+ c d))",
        "1",
        &Limits {
            polynomial_terms: 2,
            ..limits.clone()
        }
    )
    .is_err());
    assert!(equivalent(
        "(* 100 100)",
        "1",
        &Limits {
            coefficient_bits: 8,
            ..limits.clone()
        }
    )
    .is_err());
    assert!(equivalent(
        "(* a b)",
        "1",
        &Limits {
            polynomial_work: 1,
            ..limits.clone()
        }
    )
    .is_err());
    let deep = format!("{}x{}", "(+ 0 ".repeat(40), ")".repeat(40));
    assert!(equivalent(&deep, "x", &limits).is_err());
}

#[test]
fn json_dispatch_is_strict_and_resource_limited() {
    let limits = Limits::default();
    let reply = call(r#"{"operation":"graph.minimum_spanning_forest","arguments":{"vertices":2,"edges":[[0,1,4]]}}"#,&limits).unwrap();
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(&reply).unwrap()["total_weight"],
        "4"
    );
    for input in [
        r#"{"operation":"unknown","arguments":{}}"#,
        r#"{"operation":"algebra.optimize_polynomial","arguments":{"expression":"x","extra":1}}"#,
        r#"{"operation":"algebra.optimize_polynomial","arguments":{"expression":"x"},"extra":1}"#,
    ] {
        assert!(call(input, &limits).is_err());
    }
    assert!(call(
        "{}",
        &Limits {
            request_bytes: 1,
            ..limits
        }
    )
    .is_err());
}
