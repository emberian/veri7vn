//! Bounded supplied passive thermal scenarios. Untrusted floating-point model
//! evaluation; no transient, advection, inverse-design or uncertainty claim.
//! One serial dense SVD is retained for all right-hand sides. At <=128 nodes
//! this preserves the established rank policy without a sparse dependency/cache.
use super::thermal::{
    build_rhs, compile_thermal, evaluate_candidate, linear_model, CompiledThermal, ThermalInput,
    ThermalOutcome, ThermalResult,
};
use super::{checkpoint, finite, sum, Error, Limits, LinearInput, Result, SCHEMA};
use faer::diag::Diag;
use faer::dyn_stack::{MemBuffer, MemStack};
use faer::linalg::svd::{svd, svd_scratch, ComputeSvdVectors};
use faer::{Mat, Par};
use oracle_execution::{ExecutionContext, MemoryBudget, MemoryReservation, WorkControl};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeSet, VecDeque};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

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
    pub template_identity: String,
    pub operator_identity: String,
    pub identity_encoding: String,
    pub factorization_count: usize,
    #[serde(skip_serializing)]
    pub factor_cache_hit: bool,
    pub scenario_rhs_solves: usize,
    pub sensitivity_rhs_solves: usize,
    pub node_order: Vec<String>,
    pub scenarios: Vec<ScenarioResult>,
    pub sensitivities: Vec<SensitivityResult>,
    pub warnings: Vec<String>,
    #[serde(skip_serializing)]
    _result_reservation: Option<MemoryReservation>,
}
fn bounded_text(value: &str, cap: usize) -> bool {
    value.len() <= cap && !value.trim().is_empty()
}
fn preflight_network(network: &ThermalInput) -> Result<()> {
    if network.nodes.is_empty() {
        return Err(Error::Invalid("thermal network needs nodes".into()));
    }
    if network.nodes.len() > super::thermal::MAX_NODES
        || network.links.len() > super::thermal::MAX_LINKS
    {
        return Err(Error::Limit("thermal typed topology bounds"));
    }
    if !bounded_text(&network.description, 1024)
        || network.assumptions.is_empty()
        || network.assumptions.len() > 32
        || network
            .assumptions
            .iter()
            .any(|text| !bounded_text(text, 1024))
        || network
            .nodes
            .iter()
            .any(|node| !bounded_text(&node.id, 128))
        || network
            .links
            .iter()
            .any(|link| !bounded_text(&link.from, 128) || !bounded_text(&link.to, 128))
    {
        return Err(Error::Invalid("thermal typed text bounds".into()));
    }
    Ok(())
}
fn preflight(input: &ThermalScenariosInput) -> Result<()> {
    preflight_network(&input.network)?;
    if input.scenarios.is_empty()
        || input.scenarios.len() > MAX_SCENARIOS
        || input.sensitivities.len() > MAX_SENSITIVITIES
    {
        return Err(Error::Limit("thermal scenarios or sensitivities"));
    }
    let n = input.network.nodes.len();
    if input.scenarios.iter().any(|scenario| !bounded_text(&scenario.id, 128)
        || scenario.applied_heat_w.len() != n || scenario.fixed_temperature_k.len() != n)
        || input.sensitivities.iter().any(|request| !bounded_text(&request.scenario_id, 128)
            || matches!(&request.parameter, Parameter::Load { node_id } if !bounded_text(node_id, 128))) {
        return Err(Error::Invalid("thermal typed scenario vectors or text bounds".into()));
    }
    Ok(())
}
fn bounded_json_len<T: Serialize>(value: &T, limit: usize) -> Result<usize> {
    struct Counter {
        count: usize,
        limit: usize,
    }
    impl std::io::Write for Counter {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            if bytes.len() > self.limit.saturating_sub(self.count) {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    "thermal request byte limit",
                ));
            }
            self.count += bytes.len();
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut counter = Counter { count: 0, limit };
    serde_json::to_writer(&mut counter, value)
        .map_err(|_| Error::Limit("thermal bounded serialization bytes"))?;
    Ok(counter.count)
}
fn bounded_json<T: Serialize>(value: &T, limit: usize) -> Result<Vec<u8>> {
    struct Writer {
        bytes: Vec<u8>,
        limit: usize,
    }
    impl std::io::Write for Writer {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            if bytes.len() > self.limit.saturating_sub(self.bytes.len()) {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    "thermal request byte limit",
                ));
            }
            self.bytes.extend_from_slice(bytes);
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut writer = Writer {
        bytes: Vec::new(),
        limit,
    };
    serde_json::to_writer(&mut writer, value)
        .map_err(|_| Error::Limit("thermal bounded serialization bytes"))?;
    Ok(writer.bytes)
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

/// Context-owned single-solve result. Payload stays private so moving public
/// fields cannot detach evidence buffers from their reservation. Serialization
/// borrows this owner; any resulting host JSON allocation needs its own custody.
#[derive(Serialize)]
pub struct PreparedThermalSolve {
    operator_identity: String,
    template_identity: String,
    request_identity: String,
    result: ThermalResult,
    #[serde(skip_serializing)]
    _reservation: MemoryReservation,
}
impl PreparedThermalSolve {
    pub fn result(&self) -> &ThermalResult {
        &self.result
    }
    pub fn operator_identity(&self) -> &str {
        &self.operator_identity
    }
    pub fn template_identity(&self) -> &str {
        &self.template_identity
    }
    pub fn request_identity(&self) -> &str {
        &self.request_identity
    }
}
fn evidence_allowance(network: &ThermalInput) -> usize {
    let declarations = network.description.len()
        + network
            .assumptions
            .iter()
            .map(|text| text.len() + std::mem::size_of::<String>())
            .sum::<usize>()
        + 1024;
    let links = network
        .links
        .iter()
        .map(|link| {
            link.from.len() + link.to.len() + std::mem::size_of::<super::thermal::LinkEvidence>()
        })
        .sum::<usize>();
    network.nodes.len() * 2048 + declarations + links
}
/// Immutable structure/value/policy owner; callers may Arc-share it. Changing
/// links, boundary membership or numerical policy requires preparing a new one.
/// Optional ledger reservation covers an explicit conservative buffer allowance,
/// not allocator/RSS tracking or foreign allocations.
pub struct PreparedThermalNetwork {
    network: ThermalInput,
    factors: Option<Factors>,
    compiled: CompiledThermal,
    identity: String,
    operator_identity: String,
    template_identity: String,
    evidence_allowance: usize,
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
        preflight_network(network)?;
        let byte_limit = limits.request_bytes.min(super::MAX_REQUEST_BYTES);
        let encoded_length = bounded_json_len(network, byte_limit)?;
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
        // Count through a capped nonallocating writer, then reserve actual
        // serialization growth before any encoded copy or retained factors.
        let matrix_allowance = scratch_bytes + 8 * n * n * 8 + 128 * (n + network.links.len());
        let reservation = memory
            .map(|budget| {
                budget
                    .reserve(matrix_allowance + 6 * encoded_length)
                    .map_err(|_| Error::Limit("shared thermal memory"))
            })
            .transpose()?;
        let bytes = bounded_json(network, byte_limit)?;
        let compiled = compile_thermal(network, limits, control)?;
        if compiled.topology.floating_count != 0 {
            return Err(Error::Invalid(
                "thermal scenarios require a fixed-temperature boundary in every component".into(),
            ));
        }
        let factors = if free == 0 {
            None
        } else {
            let input = LinearInput {
                matrix: compiled.matrix.clone(),
                rhs: vec![0.0; free],
                model: linear_model(network, free),
                tolerances: network.tolerances.clone(),
            };
            Some(Factors::prepare(&input, limits, control)?)
        };
        let identity = format!("sha256:{:x}", Sha256::digest(&bytes));
        // Operator identity excludes RHS values and caller prose; numerical rank
        // policy remains part of the key. Mask/order/coefficients cannot mutate.
        #[derive(Serialize)]
        struct OperatorNode<'a> {
            id: &'a str,
            fixed: bool,
        }
        #[derive(Serialize)]
        struct OperatorKey<'a> {
            schema: &'static str,
            nodes: Vec<OperatorNode<'a>>,
            links: &'a [super::thermal::Link],
            tolerances: &'a super::Tolerances,
        }
        let operator = OperatorKey {
            schema: "thermal-operator-v1",
            nodes: network
                .nodes
                .iter()
                .map(|node| OperatorNode {
                    id: &node.id,
                    fixed: node.fixed_temperature_k.is_some(),
                })
                .collect(),
            links: &network.links,
            tolerances: &network.tolerances,
        };
        let operator_identity = format!(
            "sha256:{:x}",
            Sha256::digest(bounded_json(&operator, super::MAX_REQUEST_BYTES)?)
        );
        let mut template = network.clone();
        for node in &mut template.nodes {
            node.applied_heat_w = 0.0;
            node.fixed_temperature_k = node.fixed_temperature_k.map(|_| 0.0);
        }
        let mut hash = Sha256::new();
        hash.update(b"thermal-template-v1\0");
        hash.update(bounded_json(&template, super::MAX_REQUEST_BYTES)?);
        let template_identity = format!("sha256:{:x}", hash.finalize());
        let evidence_allowance = evidence_allowance(network);
        Ok(Self {
            network: network.clone(),
            compiled,
            factors,
            identity,
            operator_identity,
            template_identity,
            evidence_allowance,
            _reservation: reservation,
        })
    }
    /// Historical full preparation-input identity, retained for wire compatibility.
    pub fn identity(&self) -> &str {
        &self.identity
    }
    /// Topology/order, conductances, fixed membership and numerical policy only.
    pub fn operator_identity(&self) -> &str {
        &self.operator_identity
    }
    /// Immutable declarations/reference/policies plus operator, excluding RHS values.
    pub fn template_identity(&self) -> &str {
        &self.template_identity
    }
    fn admit_scenario(
        &self,
        scenario: &Scenario,
        limits: &Limits,
        control: &dyn WorkControl,
    ) -> Result<usize> {
        checkpoint(control)?;
        let n = self.network.nodes.len();
        let free = self.compiled.topology.unknown.len();
        if !bounded_text(&scenario.id, 128)
            || scenario.applied_heat_w.len() != n
            || scenario.fixed_temperature_k.len() != n
        {
            return Err(Error::Invalid(
                "scenario id or complete value-vector bounds".into(),
            ));
        }
        if free > limits.rows.min(super::MAX_ROWS) || free > limits.columns.min(super::MAX_COLUMNS)
        {
            return Err(Error::Limit("prepared solve dimensions"));
        }
        // Actual retained solve estimate is quadratic, not the fresh SVD's cubic
        // work. Semantic dimension and original-node checks are still enforced.
        let work = 2 * free * free + free + 4 * (n + self.network.links.len());
        if work > limits.work.min(super::MAX_WORK) {
            return Err(Error::Limit("prepared solve work"));
        }
        for (i, node) in self.network.nodes.iter().enumerate() {
            if !scenario.applied_heat_w[i].is_finite()
                || scenario.fixed_temperature_k[i].is_some() != node.fixed_temperature_k.is_some()
                || scenario.fixed_temperature_k[i]
                    .is_some_and(|value| !value.is_finite() || value < 0.0)
            {
                return Err(Error::Invalid("scenario values must be finite, fixed temperatures nonnegative, boundary membership unchanged".into()));
            }
        }
        bounded_json_len(scenario, limits.request_bytes.min(super::MAX_REQUEST_BYTES))
    }
    fn solve_admitted(
        &self,
        scenario: &Scenario,
        control: &dyn WorkControl,
    ) -> Result<ThermalResult> {
        let topology = &self.compiled.topology;
        let (mut offsets, rhs) = build_rhs(
            &self.network,
            topology,
            &scenario.applied_heat_w,
            &scenario.fixed_temperature_k,
            control,
        )?;
        if let Some(factors) = &self.factors {
            let candidate = factors.solve(&rhs, control)?;
            for (row, &i) in topology.unknown.iter().enumerate() {
                offsets[i] = candidate[row];
            }
        }
        evaluate_candidate(
            &self.network,
            topology,
            &scenario.applied_heat_w,
            &scenario.fixed_temperature_k,
            offsets,
            topology.unknown.len(),
            None,
            control,
        )
    }
    /// Compatibility API: locally bounded raw result with caller-owned custody.
    /// No topology, matrix, declarations or factors are rebuilt here. Use the
    /// context-aware owner below when a returned result must retain byte custody.
    pub fn solve(
        &self,
        scenario: &Scenario,
        limits: &Limits,
        control: &dyn WorkControl,
    ) -> Result<ThermalResult> {
        self.admit_scenario(scenario, limits, control)?;
        self.solve_admitted(scenario, control)
    }
    pub fn solve_with_context(
        &self,
        scenario: &Scenario,
        limits: &Limits,
        context: &ExecutionContext,
    ) -> Result<PreparedThermalSolve> {
        let encoded_length = self.admit_scenario(scenario, limits, context)?;
        let reservation = context
            .memory()
            .reserve(self.evidence_allowance + encoded_length * 4 + 2048)
            .map_err(|_| Error::Limit("prepared thermal result memory"))?;
        let result = self.solve_admitted(scenario, context)?;
        let mut hash = Sha256::new();
        hash.update(b"thermal-prepared-solve-v1\0");
        hash.update(self.template_identity.as_bytes());
        hash.update(b"\0");
        hash.update(bounded_json(
            scenario,
            limits.request_bytes.min(super::MAX_REQUEST_BYTES),
        )?);
        Ok(PreparedThermalSolve {
            operator_identity: self.operator_identity.clone(),
            template_identity: self.template_identity.clone(),
            request_identity: format!("sha256:{:x}", hash.finalize()),
            result,
            _reservation: reservation,
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
                    .position(|node| &node.id == node_id)
                    .ok_or_else(|| Error::Invalid("unknown load node".into()))?;
                forcing[i] = 1.0;
                "W"
            }
            Parameter::Conductance { link_index } => {
                let &(i, j) = self
                    .compiled
                    .topology
                    .endpoints
                    .get(*link_index)
                    .ok_or_else(|| Error::Invalid("unknown conductance link index".into()))?;
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
        let rhs: Vec<f64> = self
            .compiled
            .topology
            .unknown
            .iter()
            .map(|i| forcing[*i])
            .collect();
        let mut derivative = vec![0.0; n];
        if let Some(f) = &self.factors {
            for (i, x) in self
                .compiled
                .topology
                .unknown
                .iter()
                .zip(f.solve(&rhs, control)?)
            {
                derivative[*i] = x;
            }
        }
        let mut outgoing = vec![Vec::new(); n];
        for (k, ((i, j), link)) in self
            .compiled
            .topology
            .endpoints
            .iter()
            .copied()
            .zip(&self.network.links)
            .enumerate()
        {
            checkpoint(control)?;
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
        for &i in &self.compiled.topology.unknown {
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
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
pub struct PreparedThermalCacheStats {
    pub entries: usize,
    pub max_entries: usize,
    pub live_bytes: usize,
    pub max_bytes: usize,
    pub hits: u64,
    pub misses: u64,
    pub evictions: u64,
}

/// Bounded cross-request cache of immutable prepared thermal networks, keyed by
/// `template_identity` (topology, conductances, boundary mask, declarations and
/// numerical policy, excluding base RHS values). Retained factor reservations
/// live in the cache's own `MemoryBudget`, separate from per-request output
/// reservations.
pub struct PreparedThermalCache {
    max_entries: usize,
    max_bytes: usize,
    memory: MemoryBudget,
    entries: Mutex<VecDeque<(String, Arc<PreparedThermalNetwork>)>>,
    hits: AtomicU64,
    misses: AtomicU64,
    evictions: AtomicU64,
}

impl Default for PreparedThermalCache {
    fn default() -> Self {
        Self::new(64, 32 * 1024 * 1024)
    }
}

impl PreparedThermalCache {
    pub fn new(max_entries: usize, max_bytes: usize) -> Self {
        Self {
            max_entries: max_entries.max(1),
            max_bytes: max_bytes.max(1),
            memory: MemoryBudget::new(max_bytes.max(1)),
            entries: Mutex::new(VecDeque::new()),
            hits: AtomicU64::new(0),
            misses: AtomicU64::new(0),
            evictions: AtomicU64::new(0),
        }
    }

    pub fn stats(&self) -> PreparedThermalCacheStats {
        let entries = self.entries.lock().unwrap_or_else(|e| e.into_inner()).len();
        PreparedThermalCacheStats {
            entries,
            max_entries: self.max_entries,
            live_bytes: self.memory.snapshot().live,
            max_bytes: self.max_bytes,
            hits: self.hits.load(Ordering::Acquire),
            misses: self.misses.load(Ordering::Acquire),
            evictions: self.evictions.load(Ordering::Acquire),
        }
    }

    pub fn get_or_prepare(
        &self,
        network: &ThermalInput,
        limits: &Limits,
        control: &dyn WorkControl,
        request_memory: Option<&MemoryBudget>,
    ) -> Result<(Arc<PreparedThermalNetwork>, String, bool)> {
        checkpoint(control)?;
        preflight_network(network)?;
        for node in &network.nodes {
            if !node.applied_heat_w.is_finite()
                || node
                    .fixed_temperature_k
                    .is_some_and(|t| !t.is_finite() || t < 0.0)
            {
                return Err(Error::Invalid(
                    "node heat must be finite watts; fixed temperatures must be nonnegative finite kelvin".into(),
                ));
            }
        }
        let byte_limit = limits.request_bytes.min(super::MAX_REQUEST_BYTES);
        let encoded_length = bounded_json_len(network, byte_limit)?;
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
        let matrix_allowance = scratch_bytes + 8 * n * n * 8 + 128 * (n + network.links.len());
        let _request_prep_guard = request_memory
            .map(|budget| {
                budget
                    .reserve(matrix_allowance + 6 * encoded_length)
                    .map_err(|_| Error::Limit("shared thermal memory"))
            })
            .transpose()?;
        let bytes = bounded_json(network, byte_limit)?;
        let identity = format!("sha256:{:x}", Sha256::digest(&bytes));
        let mut template = network.clone();
        for node in &mut template.nodes {
            node.applied_heat_w = 0.0;
            node.fixed_temperature_k = node.fixed_temperature_k.map(|_| 0.0);
        }
        let mut hash = Sha256::new();
        hash.update(b"thermal-template-v1\0");
        hash.update(bounded_json(&template, super::MAX_REQUEST_BYTES)?);
        let template_identity = format!("sha256:{:x}", hash.finalize());
        {
            let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(pos) = entries
                .iter()
                .position(|(key, _)| key == &template_identity)
            {
                let (key, prepared) = entries.remove(pos).expect("entry index");
                entries.push_back((key, prepared.clone()));
                if free > limits.rows.min(super::MAX_ROWS)
                    || free > limits.columns.min(super::MAX_COLUMNS)
                {
                    return Err(Error::Limit("matrix dimensions"));
                }
                let prep_work = free
                    .checked_mul(free)
                    .and_then(|v| v.checked_mul(free))
                    .ok_or(Error::Limit("matrix work"))?;
                if prep_work > limits.work.min(super::MAX_WORK) {
                    return Err(Error::Limit("matrix work"));
                }
                self.hits.fetch_add(1, Ordering::Relaxed);
                return Ok((prepared, identity, true));
            }
        }
        self.misses.fetch_add(1, Ordering::Relaxed);
        let prepared = loop {
            match PreparedThermalNetwork::prepare(network, limits, control, Some(&self.memory)) {
                Ok(prepared) => break Arc::new(prepared),
                Err(Error::Limit("shared thermal memory")) => {
                    let evicted = {
                        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
                        entries.pop_front()
                    };
                    if evicted.is_some() {
                        self.evictions.fetch_add(1, Ordering::Relaxed);
                        continue;
                    }
                    // Entry exceeds cache budget: prepare under request memory without caching.
                    let uncached =
                        PreparedThermalNetwork::prepare(network, limits, control, None)?;
                    return Ok((Arc::new(uncached), identity, false));
                }
                Err(other) => return Err(other),
            }
        };
        let mut entries = self.entries.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(pos) = entries
            .iter()
            .position(|(key, _)| key == &template_identity)
        {
            entries.remove(pos);
        }
        while entries.len() >= self.max_entries {
            entries.pop_front();
            self.evictions.fetch_add(1, Ordering::Relaxed);
        }
        entries.push_back((template_identity, prepared.clone()));
        Ok((prepared, identity, false))
    }
}

fn run(
    input: &ThermalScenariosInput,
    limits: &Limits,
    control: &dyn WorkControl,
    memory: Option<&MemoryBudget>,
    cache: Option<&PreparedThermalCache>,
) -> Result<ThermalScenariosResult> {
    checkpoint(control)?;
    preflight(input)?;
    let n = input.network.nodes.len();
    let byte_limit = limits.request_bytes.min(super::MAX_REQUEST_BYTES);
    let work =
        n * n * n + (input.scenarios.len() + input.sensitivities.len() + 1) * (2 * n * n + n);
    if work > limits.work.min(super::MAX_WORK) {
        return Err(Error::Limit("aggregate thermal work estimate"));
    }
    let encoded_length = bounded_json_len(input, byte_limit)?;
    // Each accepted scenario owns its declarations and link evidence; counting
    // only node vectors misses repeated long assumptions even in a one-node graph.
    let output_allowance = encoded_length * 4
        + input.scenarios.len() * evidence_allowance(&input.network)
        + input.sensitivities.len() * (n * 128 + 1024);
    let result_reservation = memory
        .map(|budget| {
            budget
                .reserve(output_allowance)
                .map_err(|_| Error::Limit("shared thermal result memory"))
        })
        .transpose()?;
    let _encoded = bounded_json(input, byte_limit)?;
    let mut ids = BTreeSet::new();
    if input.scenarios.iter().any(|s| !ids.insert(s.id.as_str())) {
        return Err(Error::Invalid("duplicate scenario id".into()));
    }
    let (prepared, network_identity, factor_cache_hit) = if let Some(cache) = cache {
        cache.get_or_prepare(&input.network, limits, control, memory)?
    } else {
        let prepared = PreparedThermalNetwork::prepare(&input.network, limits, control, memory)?;
        let identity = prepared.identity.clone();
        (Arc::new(prepared), identity, false)
    };
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
    Ok(ThermalScenariosResult {
        _result_reservation: result_reservation,
        schema: SCHEMA.into(),
        operation: "science.thermal_scenarios".into(),
        assurance: "untrusted floating-point passive-network scenarios; not formally verified"
            .into(),
        network_identity,
        template_identity: prepared.template_identity.clone(),
        operator_identity: prepared.operator_identity.clone(),
        identity_encoding: "SHA-256 of serde_json serialized complete ThermalInput, including ordered nodes/links, base loads, boundaries, declarations and numerical policy; not topology-only".into(),
        factorization_count: usize::from(prepared.factors.is_some()),
        factor_cache_hit,
        scenario_rhs_solves: input.scenarios.len() * usize::from(prepared.factors.is_some()),
        sensitivity_rhs_solves: input.sensitivities.len() * usize::from(prepared.factors.is_some()),
        node_order: input.network.nodes.iter().map(|n| n.id.clone()).collect(),
        scenarios,
        sensitivities,
        warnings: vec![
            "Sampled supplied load/boundary scenarios, not uncertainty bounds, worst-case optimization or inferred physical truth.".into(),
            "Local analytic derivatives hold boundary temperatures and every other parameter fixed. They do not solve inverse design; positive conductances and grounded rank policy must remain valid.".into(),
            "Dense serial SVD factors are reused across scenarios and across requests matching the same immutable template identity. Reused results omit per-scenario SVD diagnostics; original-node power evidence remains authoritative.".into(),
        ],
    })
}
pub fn thermal_scenarios(
    input: &ThermalScenariosInput,
    limits: &Limits,
    control: &dyn WorkControl,
) -> Result<ThermalScenariosResult> {
    run(input, limits, control, None, None)
}
/// Explicit shared ledger entry point; same cooperative budget is passed through
/// preparation, every scenario, every derivative and every acceptance check.
pub fn thermal_scenarios_with_context(
    input: &ThermalScenariosInput,
    limits: &Limits,
    context: &ExecutionContext,
) -> Result<ThermalScenariosResult> {
    run(input, limits, context, Some(context.memory()), None)
}
/// Execute supplied thermal scenarios using a bounded cross-request prepared-factor cache.
pub fn thermal_scenarios_with_cache(
    input: &ThermalScenariosInput,
    limits: &Limits,
    context: &ExecutionContext,
    cache: &PreparedThermalCache,
) -> Result<ThermalScenariosResult> {
    run(input, limits, context, Some(context.memory()), Some(cache))
}
