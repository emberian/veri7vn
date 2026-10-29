use oracle_runtime_core::admission::*;
use oracle_runtime_core::value::{ExactNumber, ValueLimits};
use oracle_runtime_core::{Budget, Cancellation, Error, Limits};
use std::cell::Cell;

fn budget() -> Budget {
    Budget::new(&Limits::default(), Cancellation::default()).unwrap()
}

fn policy(ids: &[&str]) -> AdmissionPolicy {
    AdmissionPolicy {
        routes: ids
            .iter()
            .map(|id| RouteSpec {
                id: (*id).into(),
                participation: Participation::Optional,
            })
            .collect(),
        agreement: AgreementMode::Exact,
        limits: AdmissionLimits::default(),
    }
}

fn answer(key: AgreementKey, text: &str) -> AnswerCandidate {
    AnswerCandidate {
        key,
        response: text.into(),
        path: "organ:test>answer".into(),
        dimension: None,
        evidence: Vec::new(),
    }
}

fn text(id: &str, key: &str, response: &str) -> RouteReport {
    RouteReport {
        route: id.into(),
        outcome: RouteOutcome::Answer(answer(AgreementKey::Text(key.into()), response)),
    }
}

fn report(id: &str, outcome: RouteOutcome) -> RouteReport {
    RouteReport {
        route: id.into(),
        outcome,
    }
}

fn exact(text: &str) -> ExactNumber {
    ExactNumber::parse(text, &ValueLimits::default()).unwrap()
}

fn number(id: &str, value: &str, unit: &str) -> RouteReport {
    RouteReport {
        route: id.into(),
        outcome: RouteOutcome::Answer(answer(
            AgreementKey::Number {
                value: exact(value),
                unit: unit.into(),
            },
            value,
        )),
    }
}

#[test]
fn w574_agreement_preserves_route_order_and_first_display() {
    let reports = vec![
        text("air", "  CO2 ", "air display and citation"),
        text("physics", "co2", "physics display"),
        text("facts", "Co2", "facts display"),
    ];
    let decision = arbitrate(&policy(&["air", "physics", "facts"]), reports, &budget()).unwrap();
    assert_eq!(
        decision.outcome(),
        &AdmissionOutcome::Answered {
            selected: 0,
            agreeing: vec![0, 1, 2]
        }
    );
    assert_eq!(
        decision.answer().unwrap().response,
        "air display and citation"
    );
    assert_eq!(decision.reports()[2].route, "facts");
    assert!(!decision.allows_fallback());
}

#[test]
fn disagreement_keeps_both_answers_and_evidence_classes_do_not_rank() {
    let mut a = text("facts", "Ada", "Ada");
    if let RouteOutcome::Answer(candidate) = &mut a.outcome {
        candidate.evidence = vec![
            EvidenceClaim {
                class: EvidenceClass::Direct,
                reference: "source:row1".into(),
                detail: "producer claims a direct record".into(),
            };
            12
        ];
    }
    let decision = arbitrate(
        &policy(&["facts", "physics"]),
        [a, text("physics", "Grace", "Grace")],
        &budget(),
    )
    .unwrap();
    assert_eq!(
        decision.outcome(),
        &AdmissionOutcome::Disagreement { routes: vec![0, 1] }
    );
    assert_eq!(decision.reports().len(), 2);
    assert_eq!(decision.duplicate_evidence_claims(), 11);
    assert!(decision.answer().is_none());
    assert!(!decision.allows_fallback());
}

#[test]
fn accepted_refusal_and_ambiguity_are_terminal_even_with_an_answer() {
    for kind in [
        RefusalKind::InvalidPremise,
        RefusalKind::AmbiguousReading,
        RefusalKind::OutsideDomain,
        RefusalKind::Deliberate,
    ] {
        let refusal = SemanticRefusal {
            kind,
            response: "recognized request cannot be answered".into(),
            path: "premise>unconnected".into(),
        };
        let decision = arbitrate(
            &policy(&["premise", "facts"]),
            [
                report("premise", RouteOutcome::Refusal(refusal.clone())),
                text("facts", "42", "unchecked fallback"),
            ],
            &budget(),
        )
        .unwrap();
        assert_eq!(
            decision.outcome(),
            &AdmissionOutcome::Refused { routes: vec![0] }
        );
        assert_eq!(
            decision.reports()[0].outcome,
            RouteOutcome::Refusal(refusal)
        );
        assert!(decision.answer().is_none());
        assert!(!decision.allows_fallback());
    }
}

#[test]
fn only_unread_groups_allow_fallback() {
    let decision = arbitrate(
        &policy(&["facts"]),
        [report("facts", RouteOutcome::NoReading)],
        &budget(),
    )
    .unwrap();
    assert_eq!(decision.outcome(), &AdmissionOutcome::NoReading);
    assert!(decision.allows_fallback());
}

#[test]
fn optional_background_failure_differs_from_required_failure() {
    for unavailable in [
        Unavailability::NotLoaded,
        Unavailability::BudgetExceeded,
        Unavailability::Cancelled,
        Unavailability::Failed("organ failed".into()),
    ] {
        let reports = vec![
            report("air", RouteOutcome::Unavailable(unavailable)),
            text("facts", "Ada", "Ada"),
        ];
        let mut rules = policy(&["air", "facts"]);
        let optional = arbitrate(&rules, reports.clone(), &budget()).unwrap();
        assert_eq!(optional.answer().unwrap().response, "Ada");
        assert!(matches!(
            optional.reports()[0].outcome,
            RouteOutcome::Unavailable(_)
        ));
        rules.routes[0].participation = Participation::Required;
        let required = arbitrate(&rules, reports, &budget()).unwrap();
        assert_eq!(
            required.outcome(),
            &AdmissionOutcome::Unavailable { routes: vec![0] }
        );
        assert!(!required.allows_fallback());
    }
}

#[test]
fn unavailable_without_answers_is_not_a_semantic_refusal() {
    let decision = arbitrate(
        &policy(&["facts"]),
        [report(
            "facts",
            RouteOutcome::Unavailable(Unavailability::BudgetExceeded),
        )],
        &budget(),
    )
    .unwrap();
    assert_eq!(
        decision.outcome(),
        &AdmissionOutcome::Unavailable { routes: vec![0] }
    );
    assert!(!decision.allows_fallback());
}

struct TestGuard<'a> {
    id: &'a str,
    calls: &'a Cell<usize>,
    verdict: GuardVerdict,
}

impl NarrowingGuard for TestGuard<'_> {
    fn id(&self) -> &str {
        self.id
    }
    fn check(
        &self,
        _candidate: &AnswerCandidate,
        budget: &Budget,
    ) -> oracle_runtime_core::Result<GuardVerdict> {
        budget.spend(1)?;
        self.calls.set(self.calls.get() + 1);
        Ok(self.verdict.clone())
    }
}

#[test]
fn guard_veto_is_terminal_and_never_promotes_another_candidate() {
    let calls = Cell::new(0);
    let keep = TestGuard {
        id: "keep",
        calls: &calls,
        verdict: GuardVerdict::Keep,
    };
    let veto = TestGuard {
        id: "premise",
        calls: &calls,
        verdict: GuardVerdict::Veto {
            reason: "unconnected premise".into(),
        },
    };
    let later = TestGuard {
        id: "later",
        calls: &calls,
        verdict: GuardVerdict::Keep,
    };
    let decision = arbitrate(
        &policy(&["air", "facts"]),
        [
            text("air", "same", "first reply"),
            text("facts", "same", "second reply"),
        ],
        &budget(),
    )
    .unwrap();
    let decision = apply_guards(decision, &[&keep, &veto, &later], &budget()).unwrap();
    assert_eq!(calls.get(), 2);
    assert_eq!(
        decision.outcome(),
        &AdmissionOutcome::GuardVeto {
            guard: "premise".into(),
            reason: "unconnected premise".into(),
        }
    );
    assert_eq!(decision.guard_records().len(), 2);
    assert_eq!(decision.reports().len(), 2);
    assert!(decision.answer().is_none());
    assert!(!decision.allows_fallback());
}

#[test]
fn guards_cannot_repair_disagreement_or_refusal() {
    let calls = Cell::new(0);
    let guard = TestGuard {
        id: "irrelevant",
        calls: &calls,
        verdict: GuardVerdict::Keep,
    };
    let decision = arbitrate(
        &policy(&["a", "b"]),
        [text("a", "one", "one"), text("b", "two", "two")],
        &budget(),
    )
    .unwrap();
    let decision = apply_guards(decision, &[&guard], &budget()).unwrap();
    assert!(matches!(
        decision.outcome(),
        AdmissionOutcome::Disagreement { .. }
    ));
    assert_eq!(calls.get(), 0);
    assert!(decision.guard_records().is_empty());
}

#[test]
fn unavailable_guard_is_distinct_and_preserves_candidate_receipt() {
    let calls = Cell::new(0);
    let guard = TestGuard {
        id: "replay",
        calls: &calls,
        verdict: GuardVerdict::Unavailable {
            reason: "checker unavailable".into(),
        },
    };
    let original = text("facts", "ada", "Ada from the supplied row");
    let decision = arbitrate(&policy(&["facts"]), [original.clone()], &budget()).unwrap();
    let decision = apply_guards(decision, &[&guard], &budget()).unwrap();
    assert!(matches!(
        decision.outcome(),
        AdmissionOutcome::GuardUnavailable { .. }
    ));
    assert_eq!(decision.reports()[0], original);
    assert!(!decision.allows_fallback());
}

#[test]
fn dimension_guard_handles_mismatch_and_unread_power_without_guessing() {
    let length = Dimension([1, 0, 0, 0, 0, 0]);
    let volume = Dimension([3, 0, 0, 0, 0, 0]);
    let guard = DimensionGuard {
        id: "dimension".into(),
        expected: volume,
        unknown: UnknownDimension::Pass,
    };
    let mut candidate = answer(AgreementKey::Text("1440 ft3".into()), "1440 ft³");
    candidate.dimension = Some(length);
    assert!(matches!(
        guard.check(&candidate, &budget()).unwrap(),
        GuardVerdict::Veto { .. }
    ));
    candidate.dimension = None;
    assert_eq!(
        guard.check(&candidate, &budget()).unwrap(),
        GuardVerdict::Keep
    );
    let strict = DimensionGuard {
        unknown: UnknownDimension::Veto,
        ..guard
    };
    assert!(matches!(
        strict.check(&candidate, &budget()).unwrap(),
        GuardVerdict::Veto { .. }
    ));
    candidate.dimension = Some(volume);
    assert_eq!(
        strict.check(&candidate, &budget()).unwrap(),
        GuardVerdict::Keep
    );
}

#[test]
fn typed_numeric_agreement_does_not_round_through_binary_float() {
    let decision = arbitrate(
        &policy(&["a", "b"]),
        [number("a", "0.1", "m"), number("b", "1/10", "m")],
        &budget(),
    )
    .unwrap();
    assert!(decision.answer().is_some());
    for second in [
        number("b", "9007199254740993", "count"),
        number("b", "9007199254740992", "m"),
    ] {
        let decision = arbitrate(
            &policy(&["a", "b"]),
            [number("a", "9007199254740992", "count"), second],
            &budget(),
        )
        .unwrap();
        assert!(matches!(
            decision.outcome(),
            AdmissionOutcome::Disagreement { .. }
        ));
    }
}

#[test]
fn pairwise_relative_agreement_rejects_anchor_order_trap() {
    let mut rules = policy(&["a", "b", "c"]);
    rules.agreement = AgreementMode::Relative(Box::new(RelativeAgreement {
        tolerance: exact("1/200"),
        floor: exact("1e-12"),
        value_limits: ValueLimits::default(),
    }));
    for values in [
        ["100.4", "100", "100.8"],
        ["100", "100.8", "100.4"],
        ["100.8", "100.4", "100"],
    ] {
        let decision = arbitrate(
            &rules,
            [
                number("a", values[0], "m"),
                number("b", values[1], "m"),
                number("c", values[2], "m"),
            ],
            &budget(),
        )
        .unwrap();
        assert!(matches!(
            decision.outcome(),
            AdmissionOutcome::Disagreement { .. }
        ));
    }
    let decision = arbitrate(
        &rules,
        [
            number("a", "100", "m"),
            number("b", "100.4", "m"),
            number("c", "100.5", "m"),
        ],
        &budget(),
    )
    .unwrap();
    assert!(decision.answer().is_some());
}

#[test]
fn extrema_rule_matches_pairwise_across_signs_and_floor() {
    let mut rules = policy(&["a", "b", "c"]);
    let tolerance = exact("1/2");
    let floor = exact("10");
    let values = ["-100", "-1", "0", "1", "100"];
    let limits = ValueLimits::default();
    rules.agreement = AgreementMode::Relative(Box::new(RelativeAgreement {
        tolerance: tolerance.clone(),
        floor: floor.clone(),
        value_limits: limits.clone(),
    }));
    for a in values {
        for b in values {
            for c in values {
                let numbers = [exact(a), exact(b), exact(c)];
                let pairwise = numbers.iter().all(|x| {
                    numbers
                        .iter()
                        .all(|y| x.within_relative(y, &tolerance, &floor, &limits).unwrap())
                });
                let decision = arbitrate(
                    &rules,
                    [
                        number("a", a, "m"),
                        number("b", b, "m"),
                        number("c", c, "m"),
                    ],
                    &budget(),
                )
                .unwrap();
                assert_eq!(decision.answer().is_some(), pairwise, "{a}, {b}, {c}");
            }
        }
    }
}

#[test]
fn incomplete_extra_and_reordered_inputs_never_yield_a_prefix_answer() {
    let rules = policy(&["a", "b"]);
    for reports in [
        vec![text("a", "x", "x")],
        vec![text("b", "x", "x"), text("a", "x", "x")],
        vec![
            text("a", "x", "x"),
            text("b", "x", "x"),
            text("b", "x", "x"),
        ],
    ] {
        assert!(matches!(
            arbitrate(&rules, reports, &budget()),
            Err(Error::Invalid(_))
        ));
    }
    let mut duplicate = policy(&["a", "a"]);
    assert!(arbitrate(&duplicate, Vec::new(), &budget()).is_err());
    duplicate.routes.clear();
    assert!(arbitrate(&duplicate, Vec::new(), &budget())
        .unwrap()
        .allows_fallback());
}

#[test]
fn byte_claim_guard_and_execution_bounds_fail_without_a_partial_answer() {
    let mut rules = policy(&["a"]);
    rules.limits.input_bytes = 12;
    assert!(matches!(
        arbitrate(&rules, [text("a", "x", "long answer")], &budget()),
        Err(Error::Limit("admission input bytes"))
    ));
    let mut claim_rules = policy(&["a"]);
    claim_rules.limits.evidence_claims = 1;
    let mut claimed = text("a", "x", "x");
    if let RouteOutcome::Answer(candidate) = &mut claimed.outcome {
        candidate.evidence = vec![
            EvidenceClaim {
                class: EvidenceClass::Direct,
                reference: "same".into(),
                detail: "same".into(),
            };
            2
        ];
    }
    // Duplicate claims consume input bounds before deduplication.
    assert!(matches!(
        arbitrate(&claim_rules, [claimed], &budget()),
        Err(Error::Limit("admission evidence claims"))
    ));
    let cancellation = Cancellation::default();
    cancellation.cancel();
    let cancelled = Budget::new(&Limits::default(), cancellation).unwrap();
    assert!(matches!(
        arbitrate(&policy(&["a"]), [text("a", "x", "x")], &cancelled),
        Err(Error::Cancelled)
    ));
    let calls = Cell::new(0);
    let guard = TestGuard {
        id: "same",
        calls: &calls,
        verdict: GuardVerdict::Keep,
    };
    let decision = arbitrate(&policy(&["a"]), [text("a", "x", "x")], &budget()).unwrap();
    assert!(matches!(
        apply_guards(decision, &[&guard, &guard], &budget()),
        Err(Error::Invalid(_))
    ));
    assert_eq!(calls.get(), 0);
    let mut guard_rules = policy(&["a"]);
    guard_rules.limits.guards = 0;
    let decision = arbitrate(&guard_rules, [text("a", "x", "x")], &budget()).unwrap();
    assert!(matches!(
        apply_guards(decision, &[&guard], &budget()),
        Err(Error::Limit("admission guards"))
    ));
}
