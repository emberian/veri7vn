//! Typed statistical reply checks; no wire/result reconstruction.
use super::*;
use oracle_statistics::{CalibrationResult, RegressionResult};
pub(super) fn sequential(
    s: &Structured<'_>,
    input: &oracle_statistics::sequential::SequentialInput,
    reply: oracle_statistics::sequential::SequentialResult,
) -> CheckedPureReply {
    let checked = (|| -> Option<()> {
        let cap = s.catalog.pointer("/limits/observations")?.as_u64()? as usize;
        let [lo, hi] = reply.state.config.bounds;
        if reply.operation != s.id
            || reply.contract.is_empty()
            || reply.numerical_status.is_empty()
            || reply.state.config != input.config
            || reply.state.observations != input.observations
            || reply.state.position != input.observations.len()
            || reply.state.position > cap
            || reply.history.len() != reply.state.position
            || reply.state.config.method != "hoeffding-dyadic-v1"
            || !lo.is_finite()
            || !hi.is_finite()
            || lo >= hi
            || !(1e-12..1.0).contains(&reply.state.config.alpha)
            || !reply.log_rejection_boundary_upper.is_finite()
            || reply.log_rejection_boundary_upper <= 0.0
            || reply
                .state
                .observations
                .iter()
                .any(|v| !v.is_finite() || *v < lo || *v > hi)
        {
            return None;
        }
        let mut previous = Some([lo, hi]);
        for (i, point) in reply.history.iter().enumerate() {
            if point.position != i + 1 {
                return None;
            }
            if let Some([a, b]) = point.interval {
                let [before, after] = previous?;
                if !a.is_finite() || !b.is_finite() || !(before <= a && a <= b && b <= after) {
                    return None;
                }
            }
            if point
                .log_capital_lower
                .is_some_and(|v| v.iter().any(|x| !x.is_finite()))
            {
                return None;
            }
            previous = point.interval;
        }
        (reply.interval == previous).then_some(())
    })();
    if checked.is_none() {
        return withheld_reply(s.id, "native_reply_invalid", None);
    }
    classification(
        s.id,
        s.identity,
        "conditional_time_uniform_mean_sequence",
        Payload::Sequential(reply),
    )
}
pub(super) fn glm(
    s: &Structured<'_>,
    input: &oracle_statistics::glm::GlmInput,
    reply: oracle_statistics::glm::GlmResult,
    context: &ExecutionContext,
) -> CheckedPureReply {
    use oracle_statistics::glm::{self, Family, Status};
    let checked = (|| -> Option<()> {
        if reply.supplied != *input
            || reply.schema != s.catalog["schema"].as_str()?
            || reply.operation != s.id
        {
            return None;
        }
        let n = input.features.len();
        let width = input.features.first()?.len();
        let p = width + usize::from(input.intercept);
        if !(1..=256).contains(&n)
            || !(1..=16).contains(&p)
            || input
                .features
                .iter()
                .any(|r| r.len() != width || r.iter().any(|x| !x.is_finite()))
            || reply.coefficient_candidate.len() != p
            || reply.coefficient_candidate.iter().any(|x| !x.is_finite())
            || reply.observations.len() != n
            || reply.diagnostics.observations != n
            || reply.diagnostics.parameters != p
            || reply.diagnostics.numerical_design_rank > p.min(n)
            || reply.predictions.len() != input.predictions.len()
            || reply
                .inference_unavailable_reasons
                .iter()
                .any(String::is_empty)
        {
            return None;
        }
        let counts_ok = |v: &Option<Vec<u64>>, positive: bool| {
            v.as_ref().is_some_and(|v| {
                v.len() == n
                    && v.iter()
                        .all(|x| *x <= 1_000_000_000 && (!positive || *x > 0))
            })
        };
        match input.family {
            Family::GroupedBinomialLogit => {
                if !counts_ok(&input.successes, false)
                    || !counts_ok(&input.trials, true)
                    || input
                        .successes
                        .as_ref()?
                        .iter()
                        .zip(input.trials.as_ref()?)
                        .any(|(s, t)| s > t)
                    || input.counts.is_some()
                    || input.exposures.is_some()
                    || input.exposure_unit.is_some()
                {
                    return None;
                }
            }
            Family::PoissonLog => {
                if !counts_ok(&input.counts, false)
                    || !input.exposures.as_ref().is_some_and(|v| {
                        v.len() == n
                            && v.iter()
                                .all(|e| e.is_finite() && *e > 0.0 && e.ln().abs() <= 500.0)
                    })
                    || !input.exposure_unit.as_ref().is_some_and(|u| !u.is_empty())
                    || input.successes.is_some()
                    || input.trials.is_some()
                {
                    return None;
                }
            }
        }
        if reply.finite_mle_certificate.is_some() && reply.separation_certificate.is_some() {
            return None;
        }
        if let Some(cert) = &reply.finite_mle_certificate {
            if !glm::verify_finiteness_certificate(&input, cert, &Default::default(), context)
                .ok()?
            {
                return None;
            }
        }
        if let Some(cert) = &reply.separation_certificate {
            if !glm::verify_separation_certificate(&input, cert, &Default::default(), context)
                .ok()?
            {
                return None;
            }
        }
        let accepted = reply.status == Status::FiniteMleConverged;
        if accepted
            && (reply.finite_mle_certificate.is_none()
                || reply.diagnostics.numerical_design_rank != p
                || !reply
                    .diagnostics
                    .score_scaled_infinity_norm
                    .is_some_and(|x| x.is_finite() && (0.0..=1e-8).contains(&x))
                || !reply
                    .diagnostics
                    .newton_decrement_squared
                    .is_some_and(|x| x.is_finite() && (0.0..=1e-16).contains(&x)))
        {
            return None;
        }
        if (reply.status == Status::SeparationCertified && reply.separation_certificate.is_none())
            || (reply.status == Status::NoFiniteMleEstablished
                && reply.finite_mle_certificate.is_some())
        {
            return None;
        }
        if !accepted
            && (reply.inference.is_some() || reply.inference_unavailable_reasons.is_empty())
        {
            return None;
        }
        if let Some(inference) = &reply.inference {
            if inference.coefficients.len() != p || !reply.inference_unavailable_reasons.is_empty()
            {
                return None;
            }
        } else if accepted && reply.inference_unavailable_reasons.is_empty() {
            return None;
        }
        for (prediction, request) in reply.predictions.iter().zip(&input.predictions) {
            if prediction.features != request.features
                || prediction.exposure != request.exposure
                || prediction.trials != request.trials
            {
                return None;
            }
            for (value, probability) in [
                (prediction.probability, true),
                (prediction.rate_per_exposure_unit, false),
                (prediction.expected_count, false),
            ] {
                if value.is_some_and(|x| {
                    !accepted || !x.is_finite() || x < 0.0 || (probability && x > 1.0)
                }) {
                    return None;
                }
            }
            for (interval, probability) in [
                (prediction.pointwise_probability_interval, true),
                (prediction.pointwise_rate_interval, false),
                (prediction.pointwise_expected_count_interval, false),
            ] {
                if interval.is_some_and(|[a, b]| {
                    !accepted
                        || reply.inference.is_none()
                        || !a.is_finite()
                        || !b.is_finite()
                        || a < 0.0
                        || a > b
                        || (probability && b > 1.0)
                }) {
                    return None;
                }
            }
        }
        Some(())
    })();
    if checked.is_none() {
        if context.check().is_err() {
            return withheld_reply(s.id, "native_reply_check_budget_exhausted", None);
        }
        return withheld_reply(s.id, "native_reply_invalid", None);
    }
    let status = match reply.status {
        Status::FiniteMleConverged => "finite_mle_converged",
        Status::SeparationCertified => "separation_certified",
        Status::RankDeficient => "rank_deficient",
        Status::DesignIllConditioned => "design_ill_conditioned",
        Status::NoFiniteMleEstablished => "no_finite_mle_established",
        Status::NotConverged => "not_converged",
    };
    if reply.status != Status::FiniteMleConverged {
        return withheld_reply(s.id, status, Some(Payload::Glm(reply)));
    }
    classification(
        s.id,
        s.identity,
        "numerical_glm_with_exact_finite_existence_certificate",
        Payload::Glm(reply),
    )
}

fn regression_class(r: &RegressionResult, schema: &str) -> Option<&'static str> {
    let p = r.coefficient_candidate.len();
    let d = &r.diagnostics;
    if r.schema != schema
        || r.operation != "statistics.linear_regression"
        || p == 0
        || r.coefficient_candidate.iter().any(|x| !x.is_finite())
        || d.parameters != p
        || d.observations != r.observations.len()
        || d.numerical_rank > p.min(d.observations)
        || d.residual_degrees_of_freedom != d.observations.checked_sub(d.numerical_rank)?
        || (r.outcome == "rank_deficient_fit") != (d.numerical_rank < p)
        || r.inference_unavailable_reasons.iter().any(String::is_empty)
    {
        return None;
    }
    match r.outcome.as_str() {
        "fit_with_conditional_inference" => {
            let inference = r.inference.as_ref()?;
            if !r.inference_unavailable_reasons.is_empty()
                || d.residual_degrees_of_freedom == 0
                || inference.required_assumptions.is_empty()
                || inference.required_assumptions.iter().any(String::is_empty)
                || inference.coefficients.len() != p
            {
                return None;
            }
            Some("numerical_fit_with_conditional_inference")
        }
        "rank_deficient_fit" | "fit_without_inference" => {
            if r.inference.is_some() || r.inference_unavailable_reasons.is_empty() {
                return None;
            }
            Some(if r.outcome == "rank_deficient_fit" {
                "numerical_unidentifiable_fit"
            } else {
                "numerical_fit_without_inference"
            })
        }
        _ => None,
    }
}
pub(super) fn regression(s: &Structured<'_>, reply: RegressionResult) -> CheckedPureReply {
    match regression_class(&reply, s.catalog["schema"].as_str().unwrap_or("")) {
        Some(class) => classification(s.id, s.identity, class, Payload::Regression(reply)),
        None => withheld_reply(s.id, "native_reply_invalid", None),
    }
}
pub(super) fn calibration(s: &Structured<'_>, reply: CalibrationResult) -> CheckedPureReply {
    use oracle_statistics::calibration::{Direction, Uncertainty};
    let invalid = || withheld_reply(s.id, "native_reply_invalid", None);
    let maximum = s
        .catalog
        .pointer("/limits/predictions")
        .and_then(Value::as_u64)
        .unwrap_or(0) as usize;
    if reply.schema != s.catalog["schema"].as_str().unwrap_or("")
        || reply.operation != s.id
        || reply.estimates.is_empty()
        || reply.estimates.len() > maximum
        || [
            &reply.input_unit,
            &reply.output_unit,
            &reply.interpretation,
            &reply.assurance,
        ]
        .iter()
        .any(|s| s.is_empty())
        || regression_class(&reply.fit, s.catalog["schema"].as_str().unwrap_or("")).is_none()
        || reply.fit.coefficient_candidate.len() != 2
    {
        return invalid();
    }
    let admitted = reply.fit.diagnostics.numerical_rank == 2
        && reply
            .fit
            .diagnostics
            .condition_number_2
            .is_some_and(|c| c.is_finite() && (1.0..=1e8).contains(&c));
    for e in &reply.estimates {
        if !e.supplied_value.is_finite()
            || e.value.is_some_and(|v| !v.is_finite())
            || e.unit != reply.output_unit
            || e.unavailable_reasons.iter().any(String::is_empty)
            || (e.value.is_none() && e.unavailable_reasons.is_empty())
            || (e.value.is_some() && !admitted)
            || e.pointwise_interval.is_some_and(|[a, b]| {
                !a.is_finite()
                    || !b.is_finite()
                    || a > b
                    || e.value.is_none()
                    || reply.fit.inference.is_none()
            })
            || (reply.uncertainty == Uncertainty::PointOnly && e.pointwise_interval.is_some())
            || (reply.uncertainty == Uncertainty::PointwiseInterval
                && e.pointwise_interval.is_none()
                && e.unavailable_reasons.is_empty())
            || (reply.direction == Direction::InversePoint
                && (e.pointwise_interval.is_some()
                    || (reply.uncertainty == Uncertainty::PointwiseInterval && e.value.is_some())))
        {
            return invalid();
        }
    }
    if reply.estimates.iter().all(|e| e.value.is_none()) {
        return withheld_reply(
            s.id,
            "calibration_unavailable",
            Some(Payload::Calibration(reply)),
        );
    }
    classification(
        s.id,
        s.identity,
        "numerical_calibration_conditional_on_supplied_model",
        Payload::Calibration(reply),
    )
}
