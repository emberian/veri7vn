//! Typed scientific interpretation, retaining result reservations through wire.
use super::*;
use oracle_science::thermal::{ThermalOutcome as T, ThermalResult};
use oracle_science::{Outcome, ScientificResponse as R};
fn thermal(r: &ThermalResult, schema: &str) -> Option<Result<&'static str, &'static str>> {
    if r.schema != schema || r.operation != "science.thermal_network" {
        return None;
    }
    Some(match r.outcome {
        T::SolvedWithinTolerance => Ok("numerical"),
        T::UnderdeterminedWithinTolerance => Ok("numerical_underdetermined"),
        T::InconsistentWithinTolerance => Err("inconsistent_within_tolerance"),
        T::NumericalRankUnresolved => Err("numerical_rank_unresolved"),
        T::BelowAbsoluteZeroCandidate => Err("below_absolute_zero_candidate"),
    })
}
pub(super) fn interpret(s: &Structured<'_>, reply: R) -> CheckedPureReply {
    let schema = s.catalog["schema"].as_str().unwrap_or("");
    let checked: Option<Result<&'static str, &'static str>> = match &reply {
        R::Linear(r) => {
            if r.schema != schema
                || r.candidate.is_empty()
                || !matches!(
                    (&r.operation, s.id),
                    (
                        oracle_science::Operation::SolveLinear,
                        "science.solve_linear"
                    ) | (
                        oracle_science::Operation::LeastSquares,
                        "science.least_squares"
                    )
                )
            {
                None
            } else {
                Some(match r.outcome {
                    Outcome::InconsistentWithinTolerance => Err("inconsistent_within_tolerance"),
                    Outcome::ConsistentUnderdeterminedWithinTolerance
                    | Outcome::LeastSquaresUnderdeterminedWithinRankPolicy => {
                        Ok("numerical_underdetermined")
                    }
                    _ => Ok("numerical"),
                })
            }
        }
        R::Thermal(r) => thermal(r, schema),
        R::ThermalScenarios(r) => {
            if r.schema != schema
                || r.operation != s.id
                || r.scenarios.is_empty()
                || r.scenarios.len() > 64
                || r.sensitivities.len() > 128
                || r.node_order.is_empty()
                || !r.network_identity.starts_with("sha256:")
                || r.factorization_count > 1
                || r.sensitivities
                    .iter()
                    .any(|d| d.temperature_derivative.len() != r.node_order.len())
            {
                None
            } else {
                let mut accepted = true;
                let mut valid = true;
                for scenario in &r.scenarios {
                    match thermal(&scenario.result, schema) {
                        None => valid = false,
                        Some(Err(_)) => accepted = false,
                        Some(Ok(_)) => {
                            accepted &= scenario.result.outcome == T::SolvedWithinTolerance
                        }
                    }
                }
                if !valid {
                    None
                } else {
                    Some(if accepted {
                        Ok("numerical_scenarios")
                    } else {
                        Err("scenario_not_accepted")
                    })
                }
            }
        }
        R::ThermalTransient(r) => {
            let check = (|| -> Option<()> {
                let names: BTreeSet<_> = r.node_order.iter().map(String::as_str).collect();
                if r.schema != schema
                    || r.operation != s.id
                    || r.outcome != "completed_with_local_error_control"
                    || r.identity_encoding != "thermal-canonical-binary64-v1"
                    || !r.model_identity.starts_with("sha256:")
                    || !(1..=64).contains(&r.node_order.len())
                    || names.len() != r.node_order.len()
                    || names.contains("")
                    || !(2..=130).contains(&r.samples.len())
                    || r.events.len() > 256
                {
                    return None;
                }
                let mut last = -1.0;
                for sample in &r.samples {
                    if sample.time_s <= last
                        || sample.temperature_k.len() != r.node_order.len()
                        || sample.temperature_k.iter().any(|t| *t < 0.0)
                    {
                        return None;
                    }
                    last = sample.time_s;
                }
                if r.samples[0].time_s != 0.0 {
                    return None;
                }
                let d = &r.diagnostics;
                if d.attempted_steps > 8192
                    || d.accepted_steps == 0
                    || d.accepted_steps > 8192
                    || d.rejected_steps > 8192
                    || d.accepted_steps.checked_add(d.rejected_steps)? != d.attempted_steps
                    || !(0.0..=1.0).contains(&d.maximum_accepted_local_error_ratio)
                    || d.implicit_substeps != 3 * d.attempted_steps
                    || d.factorizations > 3 * 8192
                    || d.factor_cache_hits > 3 * 8192
                {
                    return None;
                }
                if r.energy.nodes.len() != r.node_order.len()
                    || r.energy
                        .nodes
                        .iter()
                        .zip(&r.node_order)
                        .any(|(n, id)| &n.id != id)
                {
                    return None;
                }
                for e in &r.events {
                    let [lo, hi] = e.bracket_s;
                    if !r.node_order.contains(&e.node_id)
                        || !["rising", "falling"].contains(&e.direction.as_str())
                        || !(0.0 <= lo
                            && lo <= e.linear_estimate_s
                            && e.linear_estimate_s <= hi
                            && hi <= last)
                        || e.endpoint_temperature_k.iter().any(|t| *t < 0.0)
                    {
                        return None;
                    }
                }
                Some(())
            })();
            check.map(|_| Ok("numerical_transient_local_error_control"))
        }
    };
    match checked {
        None => withheld_reply(s.id, "native_reply_invalid", None),
        Some(Ok(class)) => classification(s.id, s.identity, class, Payload::Science(reply)),
        Some(Err(reason)) => withheld_reply(s.id, reason, Some(Payload::Science(reply))),
    }
}
