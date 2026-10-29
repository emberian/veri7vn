use oracle_bio::{
    align_pairwise, call, check_alignment, AlignmentInput, Ambiguity, Candidate, Edit, Error,
    Limits, Mode, Scoring, MAX_DP_CELLS, MAX_REQUEST_BYTES, MAX_SEQUENCE_BASES,
};
use std::sync::atomic::AtomicBool;

fn input(query: &str, reference: &str, mode: Mode) -> AlignmentInput {
    AlignmentInput {
        query: query.into(),
        reference: reference.into(),
        mode,
        scoring: Scoring {
            match_score: 2,
            mismatch_score: -3,
            gap_open: -5,
            gap_extend: -1,
        },
        ambiguity: Ambiguity::Reject,
    }
}
fn align(input: &AlignmentInput) -> oracle_bio::AlignmentResult {
    align_pairwise(input, &Limits::default(), &AtomicBool::new(false)).unwrap()
}

#[test]
fn gap_open_applies_to_first_base_and_extension_to_remaining_bases() {
    let a = align(&input("ACGT", "AGT", Mode::Global));
    assert_eq!(a.candidate.score, 1); // Three matches, one length-one gap.
    assert_eq!(
        (a.checks.matches, a.checks.insertions, a.checks.gap_runs),
        (3, 1, 1)
    );
    let mut request = input("AAAACCCC", "AAAA", Mode::Global);
    request.scoring = Scoring {
        match_score: 3,
        mismatch_score: -8,
        gap_open: -4,
        gap_extend: -1,
    };
    let a = align(&request);
    assert_eq!(a.candidate.score, 5); // 4*3 + (-4 + 3*(-1)).
    assert_eq!((a.checks.insertions, a.checks.gap_runs), (4, 1));
    assert_eq!(
        a.checks.replayed_score,
        a.checks.independently_computed_optimal_score
    );
}

#[test]
fn local_and_query_global_report_original_half_open_coordinates() {
    let a = align(&input("acgt", "ttACGTaa", Mode::QueryGlobal));
    assert_eq!(a.candidate.score, 8);
    assert_eq!((a.candidate.query_start, a.candidate.query_end), (0, 4));
    assert_eq!(
        (a.candidate.reference_start, a.candidate.reference_end),
        (2, 6)
    );
    let a = align(&input("TTACGTGG", "CCACGTAA", Mode::Local));
    assert_eq!(a.candidate.score, 8);
    assert_eq!((a.candidate.query_start, a.candidate.query_end), (2, 6));
    assert_eq!(
        (a.candidate.reference_start, a.candidate.reference_end),
        (2, 6)
    );
    let a = align(&input("AAAA", "CCCC", Mode::Local));
    assert_eq!(a.candidate.score, 0);
    assert!(a.candidate.operations.is_empty());
    assert_eq!(
        (
            a.candidate.query_start,
            a.candidate.query_end,
            a.candidate.reference_start,
            a.candidate.reference_end
        ),
        (0, 0, 0, 0)
    );
}

#[test]
fn query_global_does_not_silently_clip_query_or_reverse_complement() {
    let a = align(&input("TTACGTGG", "ACGT", Mode::QueryGlobal));
    assert_eq!((a.candidate.query_start, a.candidate.query_end), (0, 8));
    assert_eq!(
        a.checks.matches + a.checks.substitutions + a.checks.insertions,
        8
    );
    // Forward-only comparison: reverse complement AAAC is GTTT, but this
    // provider does not search that orientation or report its perfect score.
    let a = align(&input("AAAC", "GTTT", Mode::Global));
    assert!(a.candidate.score < 8);
}

#[test]
fn ambiguity_is_an_explicit_mismatch_even_between_identical_letters() {
    let mut request = input("AN", "AN", Mode::Global);
    assert!(matches!(
        align_pairwise(&request, &Limits::default(), &AtomicBool::new(false)),
        Err(Error::Invalid(_))
    ));
    request.ambiguity = Ambiguity::AlwaysMismatch;
    let a = align(&request);
    assert_eq!(a.candidate.score, -1);
    assert_eq!(
        a.candidate.operations,
        vec![Edit::Match, Edit::Substitution]
    );
    assert_eq!((a.checks.matches, a.checks.substitutions), (1, 1));
    for code in "RYSWKMBDHVN".chars() {
        let text = code.to_string();
        let mut q = input(&text, &text, Mode::Global);
        q.ambiguity = Ambiguity::AlwaysMismatch;
        assert_eq!(align(&q).candidate.score, -3);
    }
}

#[test]
fn replay_refuses_tampered_and_suboptimal_candidates() {
    let request = input("AC", "AC", Mode::Global);
    let good = align(&request).candidate;
    let check =
        |c: &Candidate| check_alignment(&request, c, &Limits::default(), &AtomicBool::new(false));
    let mut c = good.clone();
    c.score += 1;
    assert!(matches!(check(&c), Err(Error::Check(_))));
    let mut c = good.clone();
    c.query_end = 3;
    assert!(matches!(check(&c), Err(Error::Check(_))));
    let mut c = good.clone();
    c.operations[0] = Edit::Substitution;
    assert!(matches!(check(&c), Err(Error::Check(_))));
    let mut c = good.clone();
    c.operations.pop();
    assert!(matches!(check(&c), Err(Error::Check(_))));
    let mut c = good;
    c.operations = vec![
        Edit::Insertion,
        Edit::Insertion,
        Edit::Deletion,
        Edit::Deletion,
    ];
    c.score = -12; // Valid path and correctly replayed score, but suboptimal.
    assert!(matches!(
        check(&c),
        Err(Error::Check("traceback score is not independently optimal"))
    ));
}

#[test]
fn equivalent_ties_are_accepted_without_claiming_unique_coordinates() {
    let request = input("A", "AAA", Mode::QueryGlobal);
    for offset in 0..3 {
        let c = Candidate {
            score: 2,
            query_start: 0,
            query_end: 1,
            reference_start: offset,
            reference_end: offset + 1,
            operations: vec![Edit::Match],
        };
        check_alignment(&request, &c, &Limits::default(), &AtomicBool::new(false)).unwrap();
    }
}

#[test]
fn malformed_sequences_and_scoring_are_refused() {
    for text in ["", "A C", "A-C", "AC\n", "ACU", ">x\nAC", "ΑC", "AX"] {
        let q = input(text, "AC", Mode::Global);
        assert!(matches!(
            align_pairwise(&q, &Limits::default(), &AtomicBool::new(false)),
            Err(Error::Invalid(_))
        ));
    }
    for s in [
        Scoring {
            match_score: 0,
            mismatch_score: -1,
            gap_open: -2,
            gap_extend: -1,
        },
        Scoring {
            match_score: 1,
            mismatch_score: 1,
            gap_open: -2,
            gap_extend: -1,
        },
        Scoring {
            match_score: 1,
            mismatch_score: -1,
            gap_open: -1,
            gap_extend: -2,
        },
        Scoring {
            match_score: 1,
            mismatch_score: -1,
            gap_open: -2,
            gap_extend: 0,
        },
        Scoring {
            match_score: i32::MAX,
            mismatch_score: i32::MIN,
            gap_open: -2,
            gap_extend: -1,
        },
    ] {
        let mut q = input("AC", "AC", Mode::Global);
        q.scoring = s;
        assert!(matches!(
            align_pairwise(&q, &Limits::default(), &AtomicBool::new(false)),
            Err(Error::Invalid(_))
        ));
    }
}

#[test]
fn fixed_caps_and_lower_operator_limits_are_admitted_before_matrix_allocation() {
    let mut limits = Limits {
        sequence_bases: usize::MAX,
        dp_cells: usize::MAX,
        working_bytes_estimate: usize::MAX,
        ..Limits::default()
    };
    let long = "A".repeat(MAX_SEQUENCE_BASES + 1);
    assert!(matches!(
        align_pairwise(
            &input(&long, "A", Mode::Global),
            &limits,
            &AtomicBool::new(false)
        ),
        Err(Error::Limit("sequence bases"))
    ));
    let square = "A".repeat(1024);
    assert!((square.len() + 1).pow(2) > MAX_DP_CELLS);
    assert!(matches!(
        align_pairwise(
            &input(&square, &square, Mode::Global),
            &limits,
            &AtomicBool::new(false)
        ),
        Err(Error::Limit("DP cells"))
    ));
    let q = input("AC", "AC", Mode::Global);
    limits.dp_cells = 8;
    assert!(matches!(
        align_pairwise(&q, &limits, &AtomicBool::new(false)),
        Err(Error::Limit("DP cells"))
    ));
    limits.dp_cells = MAX_DP_CELLS;
    limits.working_bytes_estimate = 1;
    assert!(matches!(
        align_pairwise(&q, &limits, &AtomicBool::new(false)),
        Err(Error::Limit("working bytes estimate"))
    ));
    // Invalid JSON exceeds the byte limit: parsing is never reached.
    assert!(matches!(
        call(
            &"{".repeat(MAX_REQUEST_BYTES + 1),
            &Limits::default(),
            &AtomicBool::new(false)
        ),
        Err(Error::Limit("request bytes"))
    ));
}

#[test]
fn cancellation_and_json_contract() {
    let request = input("AC", "AC", Mode::Global);
    assert!(matches!(
        align_pairwise(&request, &Limits::default(), &AtomicBool::new(true)),
        Err(Error::Cancelled)
    ));
    let raw = serde_json::json!({"operation": "bio.align_pairwise", "arguments": request});
    let result = call(
        &raw.to_string(),
        &Limits::default(),
        &AtomicBool::new(false),
    )
    .unwrap();
    let result: serde_json::Value = serde_json::from_str(&result).unwrap();
    assert_eq!(result["candidate"]["score"], 4);
    let mut raw = raw;
    raw["arguments"]["unexpected"] = true.into();
    assert!(matches!(
        call(
            &raw.to_string(),
            &Limits::default(),
            &AtomicBool::new(false)
        ),
        Err(Error::Json(_))
    ));
    raw["operation"] = "bio.design_sequence".into();
    assert!(matches!(
        call(
            &raw.to_string(),
            &Limits::default(),
            &AtomicBool::new(false)
        ),
        Err(Error::Json(_))
    ));
}

// An independent tiny-input oracle enumerates every legal edit path, rather
// than sharing either implementation's dynamic programming recurrence.
fn exhaustive_global(x: &[u8], y: &[u8], s: Scoring, prior: Option<Edit>) -> i64 {
    if x.is_empty() && y.is_empty() {
        return 0;
    }
    let mut best = i64::MIN / 4;
    if !x.is_empty() && !y.is_empty() {
        let value = if x[0] == y[0] && b"ACGT".contains(&x[0]) {
            s.match_score
        } else {
            s.mismatch_score
        };
        best = best.max(i64::from(value) + exhaustive_global(&x[1..], &y[1..], s, None));
    }
    if !x.is_empty() {
        let value = if prior == Some(Edit::Insertion) {
            s.gap_extend
        } else {
            s.gap_open
        };
        best = best.max(i64::from(value) + exhaustive_global(&x[1..], y, s, Some(Edit::Insertion)));
    }
    if !y.is_empty() {
        let value = if prior == Some(Edit::Deletion) {
            s.gap_extend
        } else {
            s.gap_open
        };
        best = best.max(i64::from(value) + exhaustive_global(x, &y[1..], s, Some(Edit::Deletion)));
    }
    best
}
fn exhaustive(request: &AlignmentInput) -> i64 {
    let (x, y) = (request.query.as_bytes(), request.reference.as_bytes());
    if request.mode == Mode::Global {
        return exhaustive_global(x, y, request.scoring, None);
    }
    let mut best = i64::MIN / 4;
    let xranges = if request.mode == Mode::QueryGlobal {
        vec![(0, x.len())]
    } else {
        (0..=x.len())
            .flat_map(|a| (a..=x.len()).map(move |b| (a, b)))
            .collect()
    };
    for (a, b) in xranges {
        for c in 0..=y.len() {
            for d in c..=y.len() {
                best = best.max(exhaustive_global(&x[a..b], &y[c..d], request.scoring, None));
            }
        }
    }
    best
}
fn words() -> Vec<String> {
    let mut words = Vec::new();
    for len in 1..=3 {
        for bits in 0..(1 << len) {
            words.push(
                (0..len)
                    .map(|i| if bits & (1 << i) == 0 { 'A' } else { 'C' })
                    .collect(),
            );
        }
    }
    words
}
#[test]
fn all_short_binary_sequences_agree_with_edit_path_enumeration() {
    let scoring = [
        Scoring {
            match_score: 2,
            mismatch_score: -3,
            gap_open: -5,
            gap_extend: -1,
        },
        Scoring {
            match_score: 1,
            mismatch_score: -9,
            gap_open: -2,
            gap_extend: -1,
        },
        Scoring {
            match_score: 1,
            mismatch_score: 0,
            gap_open: -1,
            gap_extend: -1,
        },
    ];
    let words = words();
    for query in &words {
        for reference in &words {
            for mode in [Mode::Global, Mode::Local, Mode::QueryGlobal] {
                for s in scoring {
                    let mut q = input(query, reference, mode);
                    q.scoring = s;
                    assert_eq!(align(&q).candidate.score, exhaustive(&q), "{q:?}");
                }
            }
        }
    }
}
