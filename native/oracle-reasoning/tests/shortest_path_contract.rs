use oracle_reasoning::shortest_path::{
    check_certificate, shortest_path, Certificate, PathLimits, ShortestPathInput,
};
use std::sync::atomic::AtomicBool;
fn limits() -> PathLimits {
    PathLimits {
        milliseconds: 10_000,
        ..PathLimits::default()
    }
}
fn solve(g: &ShortestPathInput) -> Certificate {
    shortest_path(g, &limits(), &AtomicBool::new(false)).unwrap()
}
fn valid(g: &ShortestPathInput, c: &Certificate) -> bool {
    check_certificate(g, c, &limits(), &AtomicBool::new(false)).is_ok()
}
#[test]
fn exhaustive_three_vertex_signed_graphs_against_floyd_warshall() {
    // All 3^6 loop-free directed graphs: absent, -1, +1. Every endpoint pair.
    let pairs = [(0, 1), (0, 2), (1, 0), (1, 2), (2, 0), (2, 1)];
    for mut code in 0..729 {
        let mut edges = vec![];
        for &(a, z) in &pairs {
            let digit = code % 3;
            code /= 3;
            if digit != 0 {
                edges.push((a, z, if digit == 1 { -1 } else { 1 }));
            }
        }
        let mut d = [[None; 3]; 3];
        for (v, row) in d.iter_mut().enumerate() {
            row[v] = Some(0i128);
        }
        for &(a, z, w) in &edges {
            d[a][z] = Some(i128::from(w));
        }
        for k in 0..3 {
            for a in 0..3 {
                for z in 0..3 {
                    if let (Some(x), Some(y)) = (d[a][k], d[k][z]) {
                        let n = x + y;
                        if d[a][z].is_none_or(|old| n < old) {
                            d[a][z] = Some(n);
                        }
                    }
                }
            }
        }
        for source in 0..3 {
            for target in 0..3 {
                let g = ShortestPathInput {
                    vertices: 3,
                    edges: edges.clone(),
                    source,
                    target,
                };
                let c = solve(&g);
                assert!(valid(&g, &c));
                let negative = (0..3).any(|k| {
                    d[source][k].is_some() && d[k][target].is_some() && d[k][k].unwrap() < 0
                });
                match c {
                    Certificate::Unbounded { .. } => assert!(negative),
                    Certificate::Unreachable { .. } => assert!(d[source][target].is_none()),
                    Certificate::Finite { distance, .. } => {
                        assert!(!negative);
                        assert_eq!(Some(distance.parse::<i128>().unwrap()), d[source][target]);
                    }
                }
            }
        }
    }
}
#[test]
fn loops_parallel_edges_and_irrelevant_negative_cycles() {
    let g = ShortestPathInput {
        vertices: 4,
        source: 0,
        target: 1,
        edges: vec![(0, 1, 7), (0, 1, 2), (0, 2, 0), (2, 2, -1), (3, 1, -5)],
    };
    match solve(&g) {
        Certificate::Finite { distance, path, .. } => {
            assert_eq!(distance, "2");
            assert_eq!(path, vec![1]);
        }
        _ => panic!(),
    }
    let mut g = g;
    g.edges.push((2, 1, 0));
    assert!(matches!(solve(&g), Certificate::Unbounded { .. }));
    g.source = 2;
    g.target = 2;
    assert!(matches!(solve(&g), Certificate::Unbounded { .. }));
}
#[test]
fn exact_extreme_weights_and_zero_ties() {
    let g = ShortestPathInput {
        vertices: 3,
        source: 0,
        target: 2,
        edges: vec![(0, 1, i64::MAX), (1, 2, i64::MAX), (1, 1, 0)],
    };
    match solve(&g) {
        Certificate::Finite { distance, .. } => {
            assert_eq!(distance, (2 * i128::from(i64::MAX)).to_string())
        }
        _ => panic!(),
    }
    let g = ShortestPathInput {
        vertices: 3,
        source: 0,
        target: 2,
        edges: vec![(0, 1, i64::MIN), (1, 2, i64::MIN)],
    };
    match solve(&g) {
        Certificate::Finite { distance, .. } => {
            assert_eq!(distance, (2 * i128::from(i64::MIN)).to_string())
        }
        _ => panic!(),
    }
}
#[test]
fn rejects_tampering_each_witness_kind() {
    let g = ShortestPathInput {
        vertices: 3,
        source: 0,
        target: 2,
        edges: vec![(0, 1, 1), (1, 2, 2), (0, 2, 9)],
    };
    let original = solve(&g);
    if let Certificate::Finite {
        distance,
        path,
        labels,
    } = original
    {
        assert!(!valid(
            &g,
            &Certificate::Finite {
                distance: "9".into(),
                path: vec![2],
                labels: labels.clone()
            }
        ));
        let mut bad = labels.clone();
        bad[1] = Some("8".into());
        assert!(!valid(
            &g,
            &Certificate::Finite {
                distance: distance.clone(),
                path: path.clone(),
                labels: bad
            }
        ));
        let mut bad = labels;
        bad[1] = None;
        assert!(!valid(
            &g,
            &Certificate::Finite {
                distance,
                path,
                labels: bad
            }
        ));
    } else {
        panic!()
    }
    let g = ShortestPathInput {
        vertices: 3,
        source: 0,
        target: 2,
        edges: vec![(0, 1, 0)],
    };
    assert!(!valid(
        &g,
        &Certificate::Unreachable {
            reachable: vec![true, false, false]
        }
    ));
    assert!(!valid(
        &g,
        &Certificate::Unreachable {
            reachable: vec![true, true, true]
        }
    ));
    let g = ShortestPathInput {
        vertices: 3,
        source: 0,
        target: 2,
        edges: vec![(0, 1, 0), (1, 1, -1), (1, 2, 0)],
    };
    assert!(valid(
        &g,
        &Certificate::Unbounded {
            prefix: vec![0],
            cycle: vec![1],
            suffix: vec![2]
        }
    ));
    for c in [
        Certificate::Unbounded {
            prefix: vec![],
            cycle: vec![1],
            suffix: vec![2],
        },
        Certificate::Unbounded {
            prefix: vec![0],
            cycle: vec![],
            suffix: vec![2],
        },
        Certificate::Unbounded {
            prefix: vec![0],
            cycle: vec![1],
            suffix: vec![],
        },
    ] {
        assert!(!valid(&g, &c));
    }
}
#[test]
fn cancellation_limits_invalid_graph_and_hostile_encoding() {
    let g = ShortestPathInput {
        vertices: 1,
        source: 0,
        target: 0,
        edges: vec![],
    };
    assert!(shortest_path(&g, &limits(), &AtomicBool::new(true)).is_err());
    let mut l = limits();
    l.work = 0;
    assert!(shortest_path(&g, &l, &AtomicBool::new(false)).is_err());
    l = limits();
    l.milliseconds = 0;
    assert!(shortest_path(&g, &l, &AtomicBool::new(false)).is_err());
    l = limits();
    l.vertices = 0;
    assert!(shortest_path(&g, &l, &AtomicBool::new(false)).is_err());
    assert!(!valid(
        &g,
        &Certificate::Finite {
            distance: "00".into(),
            path: vec![],
            labels: vec![Some("0".into())]
        }
    ));
    assert!(!valid(
        &g,
        &Certificate::Finite {
            distance: "0".into(),
            path: vec![usize::MAX],
            labels: vec![Some("0".into())]
        }
    ));
    let g = ShortestPathInput {
        vertices: 1,
        source: 0,
        target: 1,
        edges: vec![],
    };
    assert!(shortest_path(&g, &limits(), &AtomicBool::new(false)).is_err());
}
#[test]
fn budgets_include_validation_and_vertex_initialization() {
    let cancel = AtomicBool::new(false);
    let mut l = limits();
    l.work = 8;
    // Endpoints remain valid; eight ticks cannot validate the edge list.
    let edges = vec![(0, 0, 0); 100];
    let g = ShortestPathInput {
        vertices: 1,
        source: 0,
        target: 0,
        edges,
    };
    assert!(shortest_path(&g, &l, &cancel).is_err());
    assert!(check_certificate(
        &g,
        &Certificate::Finite {
            distance: "0".into(),
            path: vec![],
            labels: vec![Some("0".into())]
        },
        &l,
        &cancel
    )
    .is_err());
    // With no edges, vertex initialization still consumes work.
    let g = ShortestPathInput {
        vertices: 100,
        source: 0,
        target: 99,
        edges: vec![],
    };
    assert!(shortest_path(&g, &l, &cancel).is_err());
    assert!(check_certificate(
        &g,
        &Certificate::Finite {
            distance: "0".into(),
            path: vec![],
            labels: vec![None; 100]
        },
        &l,
        &cancel
    )
    .is_err());
}
#[test]
fn dispatcher_honors_caller_limits_and_caps_encoding() {
    use oracle_reasoning::{call, Limits};
    let request = r#"{"operation":"graph.shortest_path","arguments":{"vertices":2,"edges":[[0,1,7]],"source":0,"target":1}}"#;
    let generous = Limits {
        search_ms: 10_000,
        ..Limits::default()
    };
    let result: serde_json::Value =
        serde_json::from_str(&call(request, &generous).unwrap()).unwrap();
    assert_eq!(result["distance"], "7");
    for l in [
        Limits {
            vertices: 1,
            ..generous.clone()
        },
        Limits {
            edges: 0,
            ..generous.clone()
        },
        Limits {
            request_bytes: 1,
            ..generous.clone()
        },
        Limits {
            graph_work: 0,
            ..generous.clone()
        },
        Limits {
            search_ms: 0,
            ..generous.clone()
        },
        Limits {
            graph_reply_bytes: 1,
            ..generous.clone()
        },
    ] {
        assert!(call(request, &l).is_err());
    }
    let exact = call(request, &generous).unwrap();
    assert_eq!(
        call(
            request,
            &Limits {
                graph_reply_bytes: exact.len(),
                ..generous.clone()
            }
        )
        .unwrap(),
        exact
    );
    assert!(call(
        request,
        &Limits {
            graph_reply_bytes: exact.len() - 1,
            ..generous
        }
    )
    .is_err());
}
