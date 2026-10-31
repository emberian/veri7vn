//! Typed domain reply checks in addition to descriptor field refinements.
use super::*;
use oracle_reasoning::{Request as Q, Response as R};
pub(super) fn semantic(q: &Q, r: &R, context: &ExecutionContext) -> bool {
    match (q, r) {
        (Q::ShortestPath(input), R::ShortestPath(reply)) => {
            oracle_reasoning::shortest_path::check_certificate(
                input,
                reply,
                &oracle_reasoning::shortest_path_limits(&Default::default()),
                context,
            )
            .is_ok()
        }
        (Q::Reaction(input), R::Reaction(reply)) => {
            use oracle_reasoning::stoichiometry::BalanceStatus as S;
            let n = input.species.len();
            let nullity = reply.nullity;
            if reply.rank.checked_add(nullity) != Some(n)
                || reply.nullspace_basis.len() != nullity
                || reply.nullspace_basis.iter().any(|v| v.len() != n)
                || reply.free_species_indices.len() != nullity
                || reply
                    .free_species_indices
                    .iter()
                    .collect::<BTreeSet<_>>()
                    .len()
                    != nullity
                || reply.free_species_indices.iter().any(|i| *i >= n)
            {
                return false;
            }
            if matches!(reply.status, S::NoNonzeroBalance) && nullity != 0
                || matches!(reply.status, S::UniquePositive) && nullity != 1
                || matches!(reply.status, S::NoStrictlyPositiveBalance) && nullity < 1
                || matches!(
                    reply.status,
                    S::MultipleWithPositiveCandidate | S::MultipleSearchInconclusive
                ) && nullity < 2
            {
                return false;
            }
            if matches!(
                reply.status,
                S::UniquePositive | S::MultipleWithPositiveCandidate
            ) {
                let mut expected = BTreeSet::from(["charge"]);
                for s in &input.species {
                    expected.extend(s.composition.keys().map(String::as_str));
                }
                let actual: BTreeSet<_> = reply
                    .conservation
                    .iter()
                    .map(|r| r.inventory.as_str())
                    .collect();
                reply.coefficients.as_ref().is_some_and(|c| c.len() == n)
                    && reply.conservation.len() == expected.len()
                    && actual == expected
                    && reply.conservation.iter().all(|r| r.reactant == r.product)
            } else {
                reply.coefficients.is_none() && reply.conservation.is_empty()
            }
        }
        (Q::Rational(input), R::Rational(reply)) => {
            if input
                .output_dimension
                .is_some_and(|d| d != reply.output_dimension)
                || input.point.is_none() != reply.evaluation.is_none()
            {
                return false;
            }
            if let Some(e) = &reply.evaluation {
                if (e.status == "value") != e.value.is_some() {
                    return false;
                }
            }
            reply.selection_fallback.is_none() || reply.selected_cost == reply.original_cost
        }
        (Q::Forest(_), R::Forest(_))
        | (Q::Polynomial(_), R::Polynomial(_))
        | (Q::Dimensional(_), R::Dimensional(_)) => true,
        _ => false,
    }
}
