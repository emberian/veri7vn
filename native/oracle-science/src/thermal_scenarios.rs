//! Bounded supplied passive thermal scenarios. Untrusted floating-point model
//! evaluation; no transient, advection, inverse-design or uncertainty claim.
//! One serial dense SVD is retained for all right-hand sides. At <=128 nodes
//! this preserves the established rank policy without a sparse dependency/cache.
use super::thermal::{thermal_with_solver, ThermalInput, ThermalOutcome, ThermalResult};
use super::{checkpoint, finite, sum, Error, Limits, LinearInput, Result, SCHEMA};
use faer::diag::Diag;
use faer::dyn_stack::{MemBuffer, MemStack};
use faer::linalg::svd::{svd, svd_scratch, ComputeSvdVectors};
use faer::{Mat, Par};
use oracle_execution::{ExecutionContext, MemoryBudget, MemoryReservation, WorkControl};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;

fn charge(control: &dyn WorkControl, work: usize) -> Result<()> {
    control.checkpoint(work as u64).map_err(|e| match e {
        oracle_execution::ExecutionError::Cancelled => Error::Cancelled,
        oracle_execution::ExecutionError::Deadline => Error::Limit("shared deadline"),
        oracle_execution::ExecutionError::FuelExhausted => Error::Limit("shared work"),
        _ => Error::Limit("shared execution budget"),
    })
}
pub const MAX_SCENARIOS: usize = 64;
pub const MAX_SENSITIVITIES: usize = 128;
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Scenario {
    pub id: String,
    /// Complete vectors in supplied node order; omissions cannot inherit loads.
    pub applied_heat_w: Vec<f64>,
    /// Boundary membership must equal the prepared network, values may change.
    pub fixed_temperature_k: Vec<Option<f64>>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Parameter {
    Load {
        node_id: String,
    },
    /// Supplied link order; derivative holds every other conductance fixed.
    Conductance {
        link_index: usize,
    },
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SensitivityRequest {
    pub scenario_id: String,
    pub parameter: Parameter,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ThermalScenariosInput {
    pub network: ThermalInput,
    pub scenarios: Vec<Scenario>,
    #[serde(default)]
    pub sensitivities: Vec<SensitivityRequest>,
}
#[derive(Serialize)]
pub struct ScenarioResult {
    pub id: String,
    pub result: ThermalResult,
}
#[derive(Serialize)]
pub struct SensitivityResult {
    pub scenario_id: String,
    pub parameter: Parameter,
    pub parameter_unit: String,
    pub derivative_unit: String,
    /// All nodes in supplied order; prescribed boundary derivatives are zero.
    pub temperature_derivative: Vec<f64>,
    /// Differentiated ORIGINAL free-node balances; boundary rows are None since
    /// their reservoir exchanges adjust. No independent boundary observation.
    pub free_node_derivative_balance_residual: Vec<Option<f64>>,
    pub maximum_relative_balance_error: f64,
}
#[derive(Serialize)]
pub struct ThermalScenariosResult {
    pub schema: String,
    pub operation: String,
    pub assurance: String,
    pub network_identity: String,
    pub identity_encoding: String,
    pub factorization_count: usize,
    pub scenario_rhs_solves: usize,
    pub sensitivity_rhs_solves: usize,
    pub node_order: Vec<String>,
    pub scenarios: Vec<ScenarioResult>,
    pub sensitivities: Vec<SensitivityResult>,
    pub warnings: Vec<String>,
    #[serde(skip_serializing)]
    _result_reservation: Option<MemoryReservation>,
}
struct Factors {
    u: Mat<f64>,
    v: Mat<f64>,
    s: Vec<f64>,
    scale: f64,
}
impl Factors {
    fn prepare(input: &LinearInput, limits: &Limits, control: &dyn WorkControl) -> Result<Self> {
        let (m, n, work) = super::validate(input, limits)?;
        if m != n {
            return Err(Error::Invalid("thermal block must be square".into()));
        }
        charge(control, work)?;
        let scale = input
            .matrix
            .iter()
            .flatten()
            .fold(0.0_f64, |a, b| a.max(b.abs()));
        if scale == 0.0 {
            return Err(Error::Invalid(
                "floating network cannot determine absolute temperatures".into(),
            ));
        }
        let a = Mat::from_fn(n, n, |i, j| input.matrix[i][j] / scale);
        if input
            .matrix
            .iter()
            .flatten()
            .any(|x| *x != 0.0 && *x / scale == 0.0)
        {
            return Err(Error::Numerical("thermal coefficient scaling underflow"));
        }
        let mut u = Mat::zeros(n, n);
        let mut v = Mat::zeros(n, n);
        let mut s = Diag::zeros(n);
        let req = svd_scratch::<f64>(
            n,
            n,
            ComputeSvdVectors::Thin,
            ComputeSvdVectors::Thin,
            Par::Seq,
            Default::default(),
        );
        if req.size_bytes() > limits.scratch_bytes.min(super::MAX_SCRATCH_BYTES) {
            return Err(Error::Limit("thermal SVD scratch"));
        }
        let mut memory = MemBuffer::new(req);
        checkpoint(control)?;
        svd(
            a.as_ref(),
            s.as_mut(),
            Some(u.as_mut()),
            Some(v.as_mut()),
            Par::Seq,
            MemStack::new(&mut memory),
            Default::default(),
        )
        .map_err(|_| Error::Numerical("thermal SVD failed"))?;
        checkpoint(control)?;
        let singular: Vec<f64> = (0..n).map(|i| s[i]).collect();
        if singular
            .iter()
            .any(|x| !x.is_finite() || *x <= singular[0] * input.tolerances.rank_relative)
        {
            return Err(Error::Numerical(
                "thermal block not full rank under supplied policy",
            ));
        }
        Ok(Self {
            u,
            v,
            s: singular,
            scale,
        })
    }
    fn solve(&self, rhs: &[f64], control: &dyn WorkControl) -> Result<Vec<f64>> {
        let n = self.s.len();
        if rhs.len() != n || rhs.iter().any(|x| !x.is_finite()) {
            return Err(Error::Invalid("thermal rhs dimensions/values".into()));
        }
        charge(control, 2 * n * n + n)?;
        let bscale = rhs
            .iter()
            .fold(0.0_f64, |s, x| s.max(x.abs()))
            .max(f64::MIN_POSITIVE);
        if rhs.iter().any(|x| *x != 0.0 && *x / bscale == 0.0) {
            return Err(Error::Numerical("thermal rhs normalization underflow"));
        }
        let mut c = Vec::with_capacity(n);
        for j in 0..n {
            c.push(finite(
                sum((0..n).map(|i| self.u[(i, j)] * (rhs[i] / bscale)))? / self.s[j],
                "thermal projection overflow",
            )?);
        }
        let mut x = Vec::with_capacity(n);
        for i in 0..n {
            checkpoint(control)?;
            let y = sum((0..n).map(|j| self.v[(i, j)] * c[j]))?;
            let ratio = bscale / self.scale;
            let value = finite(
                if ratio.is_finite() && ratio != 0.0 {
                    y * ratio
                } else {
                    (y / self.scale) * bscale
                },
                "thermal solve overflow",
            )?;
            if y != 0.0 && value == 0.0 {
                return Err(Error::Numerical("thermal solve underflow"));
            }
            x.push(value);
        }
        Ok(x)
    }
}

/// Immutable structure/value/policy owner; callers may Arc-share it. Changing
/// links, boundary membership or numerical policy requires preparing a new one.
/// Optional ledger reservation covers an explicit conservative buffer allowance,
/// not allocator/RSS tracking or foreign allocations.
pub struct PreparedThermalNetwork {
    network: ThermalInput,
    factors: Option<Factors>,
    unknown: Vec<usize>,
    identity: String,
    _reservation: Option<MemoryReservation>,
}
impl PreparedThermalNetwork {
    pub fn prepare(
        network: &ThermalInput,
        limits: &Limits,
        control: &dyn WorkControl,
        memory: Option<&MemoryBudget>,
    ) -> Result<Self> {
        checkpoint(control)?;
        if network.nodes.len() > super::thermal::MAX_NODES
            || network.links.len() > super::thermal::MAX_LINKS
        {
            return Err(Error::Limit("thermal topology"));
        }
        let bytes = serde_json::to_vec(network)?;
        if bytes.len() > limits.request_bytes.min(super::MAX_REQUEST_BYTES) {
            return Err(Error::Limit("prepared network bytes"));
        }
        let n = network.nodes.len();
        let free = network
            .nodes
            .iter()
            .filter(|node| node.fixed_temperature_k.is_none())
            .count();
        let scratch_bytes = if free == 0 {
            0
        } else {
            svd_scratch::<f64>(
                free,
                free,
                ComputeSvdVectors::Thin,
                ComputeSvdVectors::Thin,
                Par::Seq,
                Default::default(),
            )
            .size_bytes()
        };
        if scratch_bytes > limits.scratch_bytes.min(super::MAX_SCRATCH_BYTES) {
            return Err(Error::Limit("thermal SVD scratch"));
        }
        // Actual-dimensional SVD scratch plus retained/construction matrices,
        // cloned declarations and traversal vectors. The global scratch cap is
        // an admission ceiling, not memory allocated by every tiny network.
        let allowance =
            scratch_bytes + 8 * n * n * 8 + bytes.len() * 4 + 64 * (n + network.links.len());
        let reservation = memory
            .map(|m| {
                m.reserve(allowance)
                    .map_err(|_| Error::Limit("shared thermal memory"))
            })
            .transpose()?;
        let mut factors = None;
        // Existing domain admission/topology/evidence path constructs the block.
        let baseline = thermal_with_solver(network, limits, control, &mut |input| {
            let f = Factors::prepare(input, limits, control)?;
            let x = f.solve(&input.rhs, control)?;
            let rank = x.len();
            factors = Some(f);
            Ok((x, rank, None))
        })?;
        if baseline.components.iter().any(|c| !c.grounded) {
            return Err(Error::Invalid(
                "thermal scenarios require a fixed-temperature boundary in every component".into(),
            ));
        }
        let identity = format!("sha256:{:x}", Sha256::digest(&bytes));
        let unknown = network
            .nodes
            .iter()
            .enumerate()
            .filter_map(|(i, n)| n.fixed_temperature_k.is_none().then_some(i))
            .collect();
        Ok(Self {
            network: network.clone(),
            factors,
            unknown,
            identity,
            _reservation: reservation,
        })
    }
    pub fn identity(&self) -> &str {
        &self.identity
    }
    pub fn solve(
        &self,
        scenario: &Scenario,
        limits: &Limits,
        control: &dyn WorkControl,
    ) -> Result<ThermalResult> {
        if scenario.id.trim().is_empty() || scenario.id.len() > 128 {
            return Err(Error::Invalid("scenario id length".into()));
        }
        let n = self.network.nodes.len();
        if scenario.applied_heat_w.len() != n || scenario.fixed_temperature_k.len() != n {
            return Err(Error::Invalid(
                "scenario vectors must cover every node".into(),
            ));
        }
        let mut network = self.network.clone();
        for (i, node) in network.nodes.iter_mut().enumerate() {
            if node.fixed_temperature_k.is_some() != scenario.fixed_temperature_k[i].is_some() {
                return Err(Error::Invalid(
                    "scenario changes prepared boundary membership".into(),
                ));
            }
            node.applied_heat_w = scenario.applied_heat_w[i];
            node.fixed_temperature_k = scenario.fixed_temperature_k[i];
        }
        thermal_with_solver(&network, limits, control, &mut |input| {
            // Reusing factors cannot bypass a caller's stricter local limits.
            super::validate(input, limits)?;
            let f = self
                .factors
                .as_ref()
                .ok_or(Error::Numerical("missing prepared factors"))?;
            let x = f.solve(&input.rhs, control)?;
            let rank = x.len();
            Ok((x, rank, None))
        })
    }
    fn sensitivity(
        &self,
        result: &ScenarioResult,
        parameter: &Parameter,
        control: &dyn WorkControl,
    ) -> Result<SensitivityResult> {
        if result.result.outcome != ThermalOutcome::SolvedWithinTolerance {
            return Err(Error::Invalid(
                "sensitivity requires an accepted scenario".into(),
            ));
        }
        let n = self.network.nodes.len();
        let mut forcing = vec![0.0; n];
        let mut selected_edge = None;
        let unit = match parameter {
            Parameter::Load { node_id } => {
                let i = self
                    .network
                    .nodes
                    .iter()
                    .position(|n| &n.id == node_id)
                    .ok_or_else(|| Error::Invalid("unknown load node".into()))?;
                // A load at an ideal reservoir changes reservoir exchange only.
                forcing[i] = 1.0;
                "W"
            }
            Parameter::Conductance { link_index } => {
                let link = self
                    .network
                    .links
                    .get(*link_index)
                    .ok_or_else(|| Error::Invalid("unknown conductance link index".into()))?;
                let i = self
                    .network
                    .nodes
                    .iter()
                    .position(|n| n.id == link.from)
                    .unwrap();
                let j = self
                    .network
                    .nodes
                    .iter()
                    .position(|n| n.id == link.to)
                    .unwrap();
                let delta = finite(
                    result.result.nodes[i].temperature_k.unwrap()
                        - result.result.nodes[j].temperature_k.unwrap(),
                    "sensitivity temperature difference",
                )?;
                forcing[i] = -delta;
                forcing[j] = delta;
                selected_edge = Some((*link_index, delta));
                "W/K"
            }
        };
        let rhs: Vec<f64> = self.unknown.iter().map(|i| forcing[*i]).collect();
        let mut derivative = vec![0.0; n];
        if let Some(f) = &self.factors {
            for (i, x) in self.unknown.iter().zip(f.solve(&rhs, control)?) {
                derivative[*i] = x;
            }
        }
        let mut outgoing = vec![Vec::new(); n];
        for (k, link) in self.network.links.iter().enumerate() {
            checkpoint(control)?;
            let i = self
                .network
                .nodes
                .iter()
                .position(|n| n.id == link.from)
                .unwrap();
            let j = self
                .network
                .nodes
                .iter()
                .position(|n| n.id == link.to)
                .unwrap();
            let heat = finite(
                link.conductance_w_per_k * (derivative[i] - derivative[j]),
                "derivative flow overflow",
            )?;
            outgoing[i].push(heat);
            outgoing[j].push(-heat);
            if let Some((edge, delta)) = selected_edge {
                if k == edge {
                    outgoing[i].push(delta);
                    outgoing[j].push(-delta);
                }
            }
        }
        let mut residuals = vec![None; n];
        let mut maximum = 0.0_f64;
        for &i in &self.unknown {
            let load = match parameter {
                Parameter::Load { node_id } if self.network.nodes[i].id == *node_id => 1.0,
                _ => 0.0,
            };
            let residual = sum(outgoing[i].iter().copied().chain(std::iter::once(-load)))?;
            let magnitude = sum(outgoing[i]
                .iter()
                .map(|q| q.abs())
                .chain(std::iter::once(load)))?;
            // Absolute floor is in derivative balance units, not a W tolerance.
            let relative = residual.abs() / magnitude.max(1.0);
            maximum = maximum.max(relative);
            residuals[i] = Some(residual);
        }
        if maximum > self.network.tolerances.consistency_relative {
            return Err(Error::Numerical(
                "sensitivity original-node derivative balance failed",
            ));
        }
        Ok(SensitivityResult {
            scenario_id: result.id.clone(),
            parameter: parameter.clone(),
            parameter_unit: unit.into(),
            derivative_unit: format!("K/({unit})"),
            temperature_derivative: derivative,
            free_node_derivative_balance_residual: residuals,
            maximum_relative_balance_error: maximum,
        })
    }
}
fn run(
    input: &ThermalScenariosInput,
    limits: &Limits,
    control: &dyn WorkControl,
    memory: Option<&MemoryBudget>,
) -> Result<ThermalScenariosResult> {
    checkpoint(control)?;
    if input.scenarios.is_empty()
        || input.scenarios.len() > MAX_SCENARIOS
        || input.sensitivities.len() > MAX_SENSITIVITIES
    {
        return Err(Error::Limit("thermal scenarios or sensitivities"));
    }
    let input_bytes = serde_json::to_vec(input)?.len();
    if input_bytes > limits.request_bytes.min(super::MAX_REQUEST_BYTES) {
        return Err(Error::Limit("thermal scenario request bytes"));
    }
    let n = input.network.nodes.len();
    if n > super::thermal::MAX_NODES {
        return Err(Error::Limit("thermal scenario nodes"));
    }
    let work =
        n * n * n + (input.scenarios.len() + input.sensitivities.len() + 1) * (2 * n * n + n);
    if work > limits.work.min(super::MAX_WORK) {
        return Err(Error::Limit("aggregate thermal work estimate"));
    }
    let output_allowance =
        input_bytes * 4 + n * (input.scenarios.len() * 2048 + input.sensitivities.len() * 128);
    let result_reservation = memory
        .map(|m| {
            m.reserve(output_allowance)
                .map_err(|_| Error::Limit("shared thermal result memory"))
        })
        .transpose()?;
    let mut ids = BTreeSet::new();
    if input.scenarios.iter().any(|s| !ids.insert(s.id.as_str())) {
        return Err(Error::Invalid("duplicate scenario id".into()));
    }
    let prepared = PreparedThermalNetwork::prepare(&input.network, limits, control, memory)?;
    let mut scenarios = Vec::new();
    for scenario in &input.scenarios {
        scenarios.push(ScenarioResult {
            id: scenario.id.clone(),
            result: prepared.solve(scenario, limits, control)?,
        });
    }
    let mut sensitivities = Vec::new();
    for request in &input.sensitivities {
        let scenario = scenarios
            .iter()
            .find(|s| s.id == request.scenario_id)
            .ok_or_else(|| Error::Invalid("unknown sensitivity scenario".into()))?;
        sensitivities.push(prepared.sensitivity(scenario, &request.parameter, control)?);
    }
    Ok(ThermalScenariosResult {_result_reservation:result_reservation,schema:SCHEMA.into(),operation:"science.thermal_scenarios".into(),assurance:"untrusted floating-point passive-network scenarios; not formally verified".into(),network_identity:prepared.identity.clone(),identity_encoding:"SHA-256 of serde_json serialized complete ThermalInput, including ordered nodes/links, base loads, boundaries, declarations and numerical policy; not topology-only".into(),factorization_count:usize::from(prepared.factors.is_some()),scenario_rhs_solves:input.scenarios.len()*usize::from(prepared.factors.is_some()),sensitivity_rhs_solves:input.sensitivities.len()*usize::from(prepared.factors.is_some()),node_order:input.network.nodes.iter().map(|n|n.id.clone()).collect(),scenarios,sensitivities,warnings:vec!["Sampled supplied load/boundary scenarios, not uncertainty bounds, worst-case optimization or inferred physical truth.".into(),"Local analytic derivatives hold boundary temperatures and every other parameter fixed. They do not solve inverse design; positive conductances and grounded rank policy must remain valid.".into(),"Dense serial SVD factors are reused; no cross-request cache. Reused results omit per-scenario SVD diagnostics; original-node power evidence remains authoritative.".into()]})
}
pub fn thermal_scenarios(
    input: &ThermalScenariosInput,
    limits: &Limits,
    control: &dyn WorkControl,
) -> Result<ThermalScenariosResult> {
    run(input, limits, control, None)
}
/// Explicit shared ledger entry point; same cooperative budget is passed through
/// preparation, every scenario, every derivative and every acceptance check.
pub fn thermal_scenarios_with_context(
    input: &ThermalScenariosInput,
    limits: &Limits,
    context: &ExecutionContext,
) -> Result<ThermalScenariosResult> {
    run(input, limits, context, Some(context.memory()))
}
