//! A supplied steady thermal network, with original-node power evidence.
//! This is an untrusted physical-model adapter to the numerical linear solver.

use super::{
    checkpoint, finite, linear, sum, Error, Limits, LinearInput, LinearResult, Model, Operation,
    Result, Tolerances, SCHEMA,
};
use oracle_execution::WorkControl;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

pub const MAX_NODES: usize = 128;
pub const MAX_LINKS: usize = 1024;
fn default_power_tolerance() -> f64 {
    1e-8
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Node {
    pub id: String,
    /// Positive means an externally supplied heat input, negative heat removal.
    pub applied_heat_w: f64,
    /// Absolute kelvin. The ideal reservoir supplies/removes whatever additional
    /// heat is needed to hold this temperature; its exchange is an output.
    #[serde(default)]
    pub fixed_temperature_k: Option<f64>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Link {
    pub from: String,
    pub to: String,
    pub conductance_w_per_k: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ThermalInput {
    pub description: String,
    pub assumptions: Vec<String>,
    /// Absolute kelvin reference used to construct interval unknowns. For a
    /// floating component it is only a coordinate choice, not a boundary.
    pub reference_temperature_k: f64,
    pub nodes: Vec<Node>,
    pub links: Vec<Link>,
    /// Original-node acceptance: |power residual| <= absolute W tolerance +
    /// consistency_relative*(sum |edge heat| + |applied heat|).
    #[serde(default = "default_power_tolerance")]
    pub power_tolerance_w: f64,
    #[serde(default)]
    pub tolerances: Tolerances,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThermalOutcome {
    SolvedWithinTolerance,
    UnderdeterminedWithinTolerance,
    InconsistentWithinTolerance,
    NumericalRankUnresolved,
    BelowAbsoluteZeroCandidate,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ComponentEvidence {
    pub node_ids: Vec<String>,
    pub fixed_node_ids: Vec<String>,
    pub grounded: bool,
    pub net_applied_heat_w: f64,
    /// Only floating components require zero total supplied power at steady state.
    pub floating_source_balance_within_tolerance: Option<bool>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NodeEvidence {
    pub id: String,
    pub fixed_temperature_k: Option<f64>,
    /// Only accepted, grounded temperatures appear here. Floating components
    /// cannot determine absolute temperature. An inconsistent fit is not promoted.
    pub temperature_k: Option<f64>,
    /// Diagnostic candidate for grounded components, even on a refused result.
    pub candidate_temperature_k: Option<f64>,
    /// Relative to reference for grounded nodes; minimum-norm coordinates for
    /// floating nodes. Floating values may be shifted by any common interval.
    pub candidate_offset_k: f64,
    pub applied_heat_w: f64,
    pub outgoing_link_heat_w: f64,
    /// Positive heat injected into the node by an ideal fixed-temperature reservoir.
    /// Computed to close the boundary balance; not an independent observation.
    pub boundary_exchange_w: Option<f64>,
    /// outgoing_link_heat - applied_heat - boundary_exchange (if fixed).
    pub power_balance_residual_w: f64,
    pub permitted_power_balance_error_w: f64,
    pub power_balance_within_tolerance: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LinkEvidence {
    pub from: String,
    pub to: String,
    pub conductance_w_per_k: f64,
    /// Positive means heat flows from `from` to `to`.
    pub candidate_heat_from_to_w: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ConservationEvidence {
    pub total_applied_heat_w: f64,
    pub total_boundary_exchange_w: f64,
    /// Sum of all prescribed inputs and ideal reservoir exchanges; ideally zero.
    pub net_external_heat_w: f64,
    /// Summing outgoing edge heat over all nodes should cancel internal transfer.
    pub internal_link_cancellation_w: f64,
    pub total_node_power_residual_w: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ThermalResult {
    pub schema: String,
    pub operation: String,
    pub assurance: String,
    pub model: String,
    pub description: String,
    pub assumptions: Vec<String>,
    pub outcome: ThermalOutcome,
    pub reference_temperature_k: f64,
    pub power_tolerance_w: f64,
    pub tolerances: Tolerances,
    pub expected_rank_from_topology: usize,
    /// Order of the constructed matrix rows, columns and solver candidate.
    pub linear_unknown_node_ids: Vec<String>,
    pub components: Vec<ComponentEvidence>,
    pub nodes: Vec<NodeEvidence>,
    pub links: Vec<LinkEvidence>,
    pub conservation: ConservationEvidence,
    /// Absent if every temperature was prescribed. Candidate generation only;
    /// domain acceptance uses original-node power balances and topology.
    pub linear_diagnostics: Option<LinearResult>,
    pub warnings: Vec<String>,
}

fn text_ok(text: &str, max: usize) -> bool {
    !text.trim().is_empty() && text.len() <= max
}
fn product(a: f64, b: f64) -> Result<f64> {
    let result = finite(a * b, "thermal product overflow")?;
    if result == 0.0 && a != 0.0 && b != 0.0 {
        return Err(Error::Numerical("thermal product underflow"));
    }
    Ok(result)
}

/// Positive symmetric conductances define q_ij = G_ij*(T_i-T_j). Every free
/// node has sum_j q_ij = applied_heat_w. Boundary nodes are ideal reservoirs.
/// This excludes heat storage, nonlinear radiation, advection, active pumps,
/// temperature-dependent conductance and inferred geometry/material properties.
pub fn thermal_network(
    input: &ThermalInput,
    limits: &Limits,
    cancel: &dyn WorkControl,
) -> Result<ThermalResult> {
    checkpoint(cancel)?;
    let count = input.nodes.len();
    if count == 0 {
        return Err(Error::Invalid(
            "thermal network needs at least one node".into(),
        ));
    }
    if count > MAX_NODES || input.links.len() > MAX_LINKS {
        return Err(Error::Limit("thermal network nodes or links"));
    }
    if count + input.links.len() > limits.work.min(super::MAX_WORK) {
        return Err(Error::Limit("thermal topology work"));
    }
    if !text_ok(&input.description, 1024)
        || input.assumptions.is_empty()
        || input.assumptions.len() > 32
        || input.assumptions.iter().any(|a| !text_ok(a, 1024))
    {
        return Err(Error::Invalid(
            "supply a description and 1..32 nonempty assumptions, at most 1024 bytes each".into(),
        ));
    }
    if !input.reference_temperature_k.is_finite()
        || input.reference_temperature_k < 0.0
        || !input.power_tolerance_w.is_finite()
        || input.power_tolerance_w < 0.0
    {
        return Err(Error::Invalid("reference temperature must be nonnegative finite kelvin, and power tolerance finite nonnegative watts".into()));
    }
    for t in [
        input.tolerances.rank_relative,
        input.tolerances.consistency_relative,
    ] {
        if !t.is_finite() || !(f64::EPSILON..=0.01).contains(&t) {
            return Err(Error::Invalid(
                "relative tolerances must lie in [f64::EPSILON, 0.01]".into(),
            ));
        }
    }
    let mut ids = BTreeMap::new();
    let mut unknown = Vec::new();
    let mut unknown_index = vec![None; count];
    for (i, node) in input.nodes.iter().enumerate() {
        checkpoint(cancel)?;
        if !text_ok(&node.id, 128) || ids.insert(node.id.as_str(), i).is_some() {
            return Err(Error::Invalid(
                "node IDs must be unique, nonempty, at most 128 bytes".into(),
            ));
        }
        if !node.applied_heat_w.is_finite()
            || node
                .fixed_temperature_k
                .is_some_and(|t| !t.is_finite() || t < 0.0)
        {
            return Err(Error::Invalid("node heat must be finite watts; fixed temperatures must be nonnegative finite kelvin".into()));
        }
        if node.fixed_temperature_k.is_none() {
            unknown_index[i] = Some(unknown.len());
            unknown.push(i);
        }
    }
    let mut endpoints = Vec::with_capacity(input.links.len());
    let mut pairs = BTreeSet::new();
    let mut adjacency = vec![Vec::new(); count];
    for link in &input.links {
        checkpoint(cancel)?;
        let (&a, &b) = match (ids.get(link.from.as_str()), ids.get(link.to.as_str())) {
            (Some(a), Some(b)) => (a, b),
            _ => {
                return Err(Error::Invalid(
                    "thermal link refers to an unknown node".into(),
                ))
            }
        };
        if a == b || !pairs.insert((a.min(b), a.max(b))) {
            return Err(Error::Invalid("self-links and duplicate unordered links are refused; combine intended parallel conductances explicitly".into()));
        }
        if !link.conductance_w_per_k.is_finite() || link.conductance_w_per_k <= 0.0 {
            return Err(Error::Invalid(
                "conductance must be finite and strictly positive W/K; omit an absent link".into(),
            ));
        }
        endpoints.push((a, b));
        adjacency[a].push(b);
        adjacency[b].push(a);
    }
    let mut component_of = vec![usize::MAX; count];
    let mut components = Vec::new();
    let mut floating_count = 0;
    for start in 0..count {
        if component_of[start] != usize::MAX {
            continue;
        }
        checkpoint(cancel)?;
        let ci = components.len();
        let mut members = Vec::new();
        let mut queue = vec![start];
        component_of[start] = ci;
        while let Some(i) = queue.pop() {
            members.push(i);
            for &j in &adjacency[i] {
                if component_of[j] == usize::MAX {
                    component_of[j] = ci;
                    queue.push(j);
                }
            }
        }
        members.sort_unstable();
        let fixed: Vec<usize> = members
            .iter()
            .copied()
            .filter(|i| input.nodes[*i].fixed_temperature_k.is_some())
            .collect();
        let grounded = !fixed.is_empty();
        let net_heat = sum(members.iter().map(|i| input.nodes[*i].applied_heat_w))?;
        let heat_magnitude = sum(members.iter().map(|i| input.nodes[*i].applied_heat_w.abs()))?;
        let permitted = finite(
            input.power_tolerance_w + input.tolerances.consistency_relative * heat_magnitude,
            "thermal tolerance overflow",
        )?;
        if !grounded {
            floating_count += 1;
        }
        components.push(ComponentEvidence {
            node_ids: members.iter().map(|i| input.nodes[*i].id.clone()).collect(),
            fixed_node_ids: fixed.iter().map(|i| input.nodes[*i].id.clone()).collect(),
            grounded,
            net_applied_heat_w: net_heat,
            floating_source_balance_within_tolerance: if grounded {
                None
            } else {
                Some(net_heat.abs() <= permitted)
            },
        });
    }
    let expected_rank = unknown.len() - floating_count;
    let mut linear_result = None;
    let mut offsets = vec![0.0; count];
    for (i, node) in input.nodes.iter().enumerate() {
        if let Some(t) = node.fixed_temperature_k {
            offsets[i] = finite(
                t - input.reference_temperature_k,
                "thermal reference subtraction overflow",
            )?;
        }
    }
    if !unknown.is_empty() {
        let size = unknown.len();
        let mut a = vec![vec![0.0; size]; size];
        let mut b: Vec<f64> = unknown
            .iter()
            .map(|i| input.nodes[*i].applied_heat_w)
            .collect();
        for ((i, j), link) in endpoints.iter().copied().zip(&input.links) {
            checkpoint(cancel)?;
            let g = link.conductance_w_per_k;
            for (node, other) in [(i, j), (j, i)] {
                if let Some(row) = unknown_index[node] {
                    a[row][row] = finite(a[row][row] + g, "thermal diagonal overflow")?;
                    if let Some(column) = unknown_index[other] {
                        a[row][column] =
                            finite(a[row][column] - g, "thermal coefficient overflow")?;
                    } else {
                        b[row] = sum([b[row], product(g, offsets[other])?].into_iter())?;
                    }
                }
            }
        }
        let model = Model {
            description: input.description.clone(),
            variable_units: vec!["K interval from declared reference".into(); size],
            row_units: vec!["W".into(); size],
            normalization: "unweighted original free-node power balances in watts; no gauge equation or hidden reference boundary".into(),
            assumptions: input.assumptions.clone(),
        };
        let result = linear(
            &LinearInput {
                matrix: a,
                rhs: b,
                model,
                tolerances: input.tolerances.clone(),
            },
            Operation::LeastSquares,
            limits,
            cancel,
        )?;
        for (row, i) in unknown.iter().copied().enumerate() {
            offsets[i] = result.candidate[row];
        }
        linear_result = Some(result);
    }
    let rank_resolved = linear_result
        .as_ref()
        .is_none_or(|r| r.diagnostics.numerical_rank == expected_rank);
    let absolute: Vec<Option<f64>> = input
        .nodes
        .iter()
        .enumerate()
        .map(|(i, node)| {
            if components[component_of[i]].grounded {
                match node.fixed_temperature_k {
                    Some(t) => Ok(Some(t)),
                    None => Ok(Some(finite(
                        input.reference_temperature_k + offsets[i],
                        "absolute temperature overflow",
                    )?)),
                }
            } else {
                Ok(None)
            }
        })
        .collect::<Result<_>>()?;
    let mut outgoing = vec![Vec::new(); count];
    let mut link_results = Vec::with_capacity(input.links.len());
    for ((i, j), link) in endpoints.iter().copied().zip(&input.links) {
        checkpoint(cancel)?;
        // Grounded power evidence uses reconstructed absolute candidates and the
        // ORIGINAL fixed temperatures, so reference cancellation cannot hide a
        // failed reconstruction. Floating differences use arbitrary offsets.
        let delta = match (absolute[i], absolute[j]) {
            (Some(ti), Some(tj)) => finite(ti - tj, "thermal temperature difference overflow")?,
            _ => finite(
                offsets[i] - offsets[j],
                "thermal offset difference overflow",
            )?,
        };
        let heat = product(link.conductance_w_per_k, delta)?;
        outgoing[i].push(heat);
        outgoing[j].push(-heat);
        link_results.push(LinkEvidence {
            from: link.from.clone(),
            to: link.to.clone(),
            conductance_w_per_k: link.conductance_w_per_k,
            candidate_heat_from_to_w: heat,
        });
    }
    let mut nodes = Vec::with_capacity(count);
    for (i, node) in input.nodes.iter().enumerate() {
        checkpoint(cancel)?;
        let out = sum(outgoing[i].iter().copied())?;
        let boundary = if node.fixed_temperature_k.is_some() {
            Some(sum([out, -node.applied_heat_w].into_iter())?)
        } else {
            None
        };
        let residual = sum([out, -node.applied_heat_w, -boundary.unwrap_or(0.0)].into_iter())?;
        let magnitude = sum(outgoing[i]
            .iter()
            .map(|q| q.abs())
            .chain(std::iter::once(node.applied_heat_w.abs())))?;
        let permitted = finite(
            input.power_tolerance_w + input.tolerances.consistency_relative * magnitude,
            "thermal tolerance overflow",
        )?;
        nodes.push(NodeEvidence {
            id: node.id.clone(),
            fixed_temperature_k: node.fixed_temperature_k,
            temperature_k: None,
            candidate_temperature_k: absolute[i],
            candidate_offset_k: offsets[i],
            applied_heat_w: node.applied_heat_w,
            outgoing_link_heat_w: out,
            boundary_exchange_w: boundary,
            power_balance_residual_w: residual,
            permitted_power_balance_error_w: permitted,
            power_balance_within_tolerance: residual.abs() <= permitted,
        });
    }
    let consistent = nodes.iter().all(|n| n.power_balance_within_tolerance)
        && components
            .iter()
            .all(|c| c.floating_source_balance_within_tolerance != Some(false));
    let below_zero = absolute.iter().flatten().any(|t| *t < 0.0);
    let outcome = if !consistent {
        ThermalOutcome::InconsistentWithinTolerance
    } else if !rank_resolved {
        ThermalOutcome::NumericalRankUnresolved
    } else if below_zero {
        ThermalOutcome::BelowAbsoluteZeroCandidate
    } else if floating_count != 0 {
        ThermalOutcome::UnderdeterminedWithinTolerance
    } else {
        ThermalOutcome::SolvedWithinTolerance
    };
    // Even in a mixed grounded/floating network, accepted grounded components
    // retain their absolute temperatures. Inconsistent/rank-unresolved candidates
    // are never promoted into this field.
    if consistent && rank_resolved && !below_zero {
        for (i, node) in nodes.iter_mut().enumerate() {
            node.temperature_k = absolute[i];
        }
    }
    let total_applied = sum(nodes.iter().map(|n| n.applied_heat_w))?;
    let total_boundary = sum(nodes.iter().map(|n| n.boundary_exchange_w.unwrap_or(0.0)))?;
    let conservation = ConservationEvidence {
        total_applied_heat_w: total_applied,
        total_boundary_exchange_w: total_boundary,
        net_external_heat_w: sum([total_applied, total_boundary].into_iter())?,
        internal_link_cancellation_w: sum(nodes.iter().map(|n| n.outgoing_link_heat_w))?,
        total_node_power_residual_w: sum(nodes.iter().map(|n| n.power_balance_residual_w))?,
    };
    let mut warnings = vec!["Supplied steady linear conductances and heat sources are model assumptions, not inferred facts; power residuals do not validate them.".into(),
        "Fixed temperatures denote ideal reservoirs. Reported boundary heat is computed to close their balance, not independently measured.".into()];
    if floating_count != 0 {
        warnings.push("Floating components determine only temperature differences; their arbitrary minimum-norm offsets are not absolute temperatures.".into());
    }
    if !rank_resolved {
        warnings.push("Numerical rank differs from passive-network topology; change scale/cutoff or use higher precision before interpreting temperatures.".into());
    }
    checkpoint(cancel)?;
    Ok(ThermalResult {
        schema: SCHEMA.into(),
        operation: "science.thermal_network".into(),
        assurance: "experimental floating-point physical-model adapter; not formally verified"
            .into(),
        model: "steady passive linear conductances: q_ij=G_ij*(T_i-T_j); free-node outgoing heat equals applied heat; fixed nodes are ideal reservoirs; no heat storage, nonlinear radiation or advection".into(),
        description: input.description.clone(),
        assumptions: input.assumptions.clone(),
        outcome,
        reference_temperature_k: input.reference_temperature_k,
        power_tolerance_w: input.power_tolerance_w,
        tolerances: input.tolerances.clone(),
        expected_rank_from_topology: expected_rank,
        linear_unknown_node_ids: unknown.iter().map(|i| input.nodes[*i].id.clone()).collect(),
        components,
        nodes,
        links: link_results,
        conservation,
        linear_diagnostics: linear_result,
        warnings,
    })
}
