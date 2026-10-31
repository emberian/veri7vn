use oracle_reasoning::exact_lp::*;
fn problem(rows: &[(&[&str], &str)]) -> Problem {
    Problem {
        variables: vec!["x".into()],
        rows: rows
            .iter()
            .enumerate()
            .map(|(i, (a, b))| Row {
                id: i.to_string(),
                coefficients: a.iter().map(|s| s.to_string()).collect(),
                bound: b.to_string(),
            })
            .collect(),
        objective: Some(vec!["1".into()]),
    }
}
#[test]
fn analytic_intervals_and_mutated_witnesses() {
    let l = Limits::default();
    for low in -3..4 {
        for high in -3..4 {
            let p = problem(&[(&["-1"], &(-low).to_string()), (&["1"], &high.to_string())]);
            let o = solve(&p, &l).unwrap();
            assert_eq!(
                o.status,
                if low <= high {
                    "feasible"
                } else {
                    "infeasible"
                }
            );
            assert_eq!(
                check_certificate(&p, o.certificate.as_ref().unwrap(), &l).unwrap(),
                o.status
            );
        }
    }
    let p = problem(&[(&["-1"], "-1/3"), (&["1"], "1/2")]);
    assert!(check_certificate(
        &p,
        &Certificate::Feasible {
            point: vec!["1/4".into()]
        },
        &l
    )
    .is_err());
    assert!(check_certificate(
        &p,
        &Certificate::Infeasible {
            multipliers: vec!["1".into(), "-1".into()]
        },
        &l
    )
    .is_err());
    assert_eq!(
        check_certificate(
            &p,
            &Certificate::Optimal {
                point: vec!["1/3".into()],
                multipliers: vec!["1".into(), "0".into()]
            },
            &l
        )
        .unwrap(),
        "optimal"
    );
    let mut changed = p.clone();
    changed.rows[0].bound = "-1/2".into();
    assert!(check_certificate(
        &changed,
        &Certificate::Feasible {
            point: vec!["1/3".into()]
        },
        &l
    )
    .is_err());
}
#[test]
fn unbounded_needs_feasible_base_and_unknown_is_not_infeasible() {
    let l = Limits::default();
    let p = problem(&[(&["1"], "0")]);
    assert_eq!(
        check_certificate(
            &p,
            &Certificate::Unbounded {
                point: vec!["0".into()],
                direction: vec!["-1".into()]
            },
            &l
        )
        .unwrap(),
        "unbounded"
    );
    assert!(check_certificate(
        &p,
        &Certificate::Unbounded {
            point: vec!["1".into()],
            direction: vec!["-1".into()]
        },
        &l
    )
    .is_err());
    let tiny = Limits { work: 4, ..l };
    let o = solve(&p, &tiny);
    assert!(o.is_err() || o.unwrap().status == "unknown");
}
#[test]
fn zero_row_and_denominator_mutations() {
    let l = Limits::default();
    let p = problem(&[(&["0"], "-1")]);
    let o = solve(&p, &l).unwrap();
    assert_eq!(o.status, "infeasible");
    assert!(check_certificate(
        &p,
        &Certificate::Infeasible {
            multipliers: vec!["-1/2".into()]
        },
        &l
    )
    .is_err());
    let mut changed = p.clone();
    changed.rows[0].bound = "1".into();
    assert!(check_certificate(&changed, o.certificate.as_ref().unwrap(), &l).is_err());
}
#[test]
fn two_variable_elimination_and_original_row_order() {
    let p = Problem {
        variables: vec!["x".into(), "y".into()],
        objective: None,
        rows: vec![
            Row {
                id: "sum".into(),
                coefficients: vec!["1".into(), "2".into()],
                bound: "1".into(),
            },
            Row {
                id: "x".into(),
                coefficients: vec!["-1".into(), "0".into()],
                bound: "-1".into(),
            },
            Row {
                id: "y".into(),
                coefficients: vec!["0".into(), "-1".into()],
                bound: "-1".into(),
            },
        ],
    };
    let l = Limits::default();
    let out = solve(&p, &l).unwrap();
    assert_eq!(out.status, "infeasible");
    let cert = out.certificate.unwrap();
    let mut changed = p.clone();
    changed.rows[0].bound = "4".into();
    assert!(check_certificate(&changed, &cert, &l).is_err());
    let mut swapped = p.clone();
    swapped.rows.swap(0, 2);
    assert!(check_certificate(&swapped, &cert, &l).is_err());
    let out = solve(&changed, &l).unwrap();
    assert_eq!(out.status, "feasible");
}
