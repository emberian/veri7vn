//! Supplied passive thermal storage dynamics. Untrusted floating-point model.
//! Adaptive backward Euler with step doubling is stable for this linear model;
//! the local difference estimate is NOT a rigorous global error enclosure.
use crate::thermal::ThermalInput;
use crate::{checkpoint, finite, sum, Error, Limits, Result, SCHEMA};
use faer::dyn_stack::{MemBuffer, MemStack};
use faer::linalg::cholesky::llt::factor::{cholesky_in_place, cholesky_in_place_scratch};
use faer::{Mat, Par};
use oracle_execution::{ExecutionContext, MemoryBudget, MemoryReservation, WorkControl};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

pub const MAX_NODES: usize = 64;
pub const MAX_LINKS: usize = 512;
pub const MAX_STEPS: usize = 8192;
pub const MAX_LOAD_CHANGES: usize = 64;
pub const MAX_SAMPLES: usize = 128;
pub const MAX_EVENTS: usize = 32;
pub const MAX_EVENT_HITS: usize = 256;
pub const FACTOR_CACHE_SIZE: usize = 8;
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LoadSegment {
    pub start_time_s: f64,
    pub applied_heat_w: Vec<f64>,
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Direction {
    Rising,
    Falling,
    Either,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ThresholdEvent {
    pub id: String,
    pub node_id: String,
    pub temperature_k: f64,
    pub direction: Direction,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Integration {
    pub initial_step_s: f64,
    pub min_step_s: f64,
    pub max_step_s: f64,
    pub absolute_tolerance_k: f64,
    pub relative_tolerance: f64,
    pub max_steps: usize,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TransientInput {
    pub network: ThermalInput,
    /// Positive lumped heat capacities for ALL nodes. Fixed reservoirs have zero
    /// temperature change, so their supplied finite capacity stores no net heat.
    pub capacities_j_per_k: Vec<f64>,
    pub initial_temperature_k: Vec<f64>,
    pub duration_s: f64,
    pub loads: Vec<LoadSegment>,
    /// Requested output instants. Initial and final instants are always included.
    #[serde(default)]
    pub sample_times_s: Vec<f64>,
    #[serde(default)]
    pub events: Vec<ThresholdEvent>,
    pub integration: Integration,
}
#[derive(Serialize)]
pub struct Sample {
    pub time_s: f64,
    pub temperature_k: Vec<f64>,
}
#[derive(Serialize)]
pub struct EventHit {
    pub id: String,
    pub node_id: String,
    pub direction: String,
    pub bracket_s: [f64; 2],
    pub linear_estimate_s: f64,
    pub endpoint_temperature_k: [f64; 2],
}
#[derive(Serialize)]
pub struct NodeEnergy {
    pub id: String,
    pub storage_change_j: f64,
    pub applied_heat_j: f64,
    /// Positive heat injected by an ideal prescribed-temperature reservoir.
    pub reservoir_heat_j: Option<f64>,
    pub outgoing_link_heat_j: f64,
    /// storage - applied - reservoir + outgoing, recomputed from accepted steps.
    pub integrated_balance_residual_j: f64,
    pub maximum_step_balance_residual_j: f64,
}
#[derive(Serialize)]
pub struct Energy {
    pub nodes: Vec<NodeEnergy>,
    pub storage_change_j: f64,
    pub applied_heat_j: f64,
    pub reservoir_heat_j: f64,
    pub global_balance_residual_j: f64,
    pub internal_link_cancellation_j: f64,
}
#[derive(Serialize)]
pub struct Diagnostics {
    pub attempted_steps: usize,
    pub accepted_steps: usize,
    pub rejected_steps: usize,
    pub implicit_substeps: usize,
    pub factorizations: usize,
    pub factor_cache_hits: usize,
    pub maximum_accepted_local_error_ratio: f64,
    pub maximum_original_node_balance_relative_error: f64,
    pub minimum_accepted_step_s: f64,
    pub maximum_accepted_step_s: f64,
    pub method: String,
    pub threads: usize,
}
#[derive(Serialize)]
pub struct TransientResult {
    pub schema: String,
    pub operation: String,
    pub assurance: String,
    pub outcome: String,
    pub model_identity: String,
    pub identity_encoding: String,
    pub node_order: Vec<String>,
    pub samples: Vec<Sample>,
    pub events: Vec<EventHit>,
    pub energy: Energy,
    pub diagnostics: Diagnostics,
    pub warnings: Vec<String>,
    #[serde(skip_serializing)]
    _reservation: Option<MemoryReservation>,
}
fn charge(control: &dyn WorkControl, work: usize) -> Result<()> {
    control.checkpoint(work as u64).map_err(|e| match e {
        oracle_execution::ExecutionError::Cancelled => Error::Cancelled,
        oracle_execution::ExecutionError::Deadline => Error::Limit("shared deadline"),
        oracle_execution::ExecutionError::FuelExhausted => Error::Limit("shared work"),
        _ => Error::Limit("shared execution budget"),
    })
}
fn positive(x: f64) -> bool {
    x.is_finite() && x > 0.0
}
fn text(s: &str, max: usize) -> bool {
    s.len() <= max && !s.trim().is_empty()
}
fn product(a: f64, b: f64) -> Result<f64> {
    let x = finite(a * b, "transient product overflow")?;
    if x == 0.0 && a != 0.0 && b != 0.0 {
        return Err(Error::Numerical("transient product underflow"));
    }
    Ok(x)
}
/// Immutable spatial graph and heat capacities. Time-step factors depend on h;
/// loads and initial temperatures never change its link coefficients.
struct Spatial {
    free: Vec<usize>,
    free_index: Vec<Option<usize>>,
    endpoints: Vec<(usize, usize)>,
    laplacian: Vec<Vec<f64>>,
    fixed_offsets: Vec<f64>,
}
impl Spatial {
    fn prepare(input: &TransientInput, limits: &Limits, control: &dyn WorkControl) -> Result<Self> {
        checkpoint(control)?;
        let network = &input.network;
        let n = network.nodes.len();
        if n == 0 || n > MAX_NODES || network.links.len() > MAX_LINKS {
            return Err(Error::Limit("transient topology size"));
        }
        if !text(&network.description, 1024)
            || network.assumptions.is_empty()
            || network.assumptions.len() > 32
            || network.assumptions.iter().any(|s| !text(s, 1024))
        {
            return Err(Error::Invalid(
                "declare supplied thermal model assumptions".into(),
            ));
        }
        if !network.reference_temperature_k.is_finite()
            || network.reference_temperature_k < 0.0
            || !network.power_tolerance_w.is_finite()
            || network.power_tolerance_w < 0.0
        {
            return Err(Error::Invalid(
                "invalid thermal reference or power tolerance".into(),
            ));
        }
        for t in [
            network.tolerances.rank_relative,
            network.tolerances.consistency_relative,
        ] {
            if !t.is_finite() || !(f64::EPSILON..=0.01).contains(&t) {
                return Err(Error::Invalid("invalid relative numerical policy".into()));
            }
        }
        if input.capacities_j_per_k.len() != n
            || input.initial_temperature_k.len() != n
            || input.capacities_j_per_k.iter().any(|c| !positive(*c))
            || input
                .initial_temperature_k
                .iter()
                .any(|t| !t.is_finite() || *t < 0.0)
        {
            return Err(Error::Invalid("one strictly positive finite capacity and nonnegative finite initial kelvin temperature per node required".into()));
        }
        let mut ids = BTreeMap::new();
        let mut free = Vec::new();
        let mut free_index = vec![None; n];
        let mut fixed_offsets = vec![0.0; n];
        for (i, node) in network.nodes.iter().enumerate() {
            checkpoint(control)?;
            if !text(&node.id, 128)
                || ids.insert(node.id.as_str(), i).is_some()
                || !node.applied_heat_w.is_finite()
            {
                return Err(Error::Invalid(
                    "invalid/duplicate node id or base load".into(),
                ));
            }
            if let Some(t) = node.fixed_temperature_k {
                if !t.is_finite() || t < 0.0 || t != input.initial_temperature_k[i] {
                    return Err(Error::Invalid("initial boundary temperatures must equal finite nonnegative prescribed kelvin values".into()));
                }
                fixed_offsets[i] = finite(
                    t - network.reference_temperature_k,
                    "fixed reference subtraction",
                )?;
            } else {
                free_index[i] = Some(free.len());
                free.push(i);
            }
        }
        if free.len() > limits.rows.min(crate::MAX_ROWS)
            || free.len() > limits.columns.min(crate::MAX_COLUMNS)
        {
            return Err(Error::Limit("transient free-node dimensions"));
        }
        let mut endpoints = Vec::new();
        let mut pairs = BTreeSet::new();
        let mut laplacian = vec![vec![0.0; free.len()]; free.len()];
        for link in &network.links {
            checkpoint(control)?;
            let (Some(&i), Some(&j)) = (ids.get(link.from.as_str()), ids.get(link.to.as_str()))
            else {
                return Err(Error::Invalid("unknown link endpoint".into()));
            };
            if i == j || !pairs.insert((i.min(j), i.max(j))) || !positive(link.conductance_w_per_k)
            {
                return Err(Error::Invalid(
                    "positive finite conductances and unique unordered non-self links required"
                        .into(),
                ));
            }
            endpoints.push((i, j));
            for (a, b) in [(i, j), (j, i)] {
                if let Some(row) = free_index[a] {
                    laplacian[row][row] = finite(
                        laplacian[row][row] + link.conductance_w_per_k,
                        "Laplacian overflow",
                    )?;
                    if let Some(col) = free_index[b] {
                        laplacian[row][col] = finite(
                            laplacian[row][col] - link.conductance_w_per_k,
                            "Laplacian overflow",
                        )?;
                    }
                }
            }
        }
        Ok(Self {
            free,
            free_index,
            endpoints,
            laplacian,
            fixed_offsets,
        })
    }
}
struct Factor {
    h: f64,
    lower: Mat<f64>,
    scale: f64,
}
impl Factor {
    fn new(
        spatial: &Spatial,
        input: &TransientInput,
        h: f64,
        limits: &Limits,
        control: &dyn WorkControl,
    ) -> Result<Self> {
        let n = spatial.free.len();
        charge(control, n * n * n + n * n)?;
        let mut lower = Mat::from_fn(n, n, |i, j| spatial.laplacian[i][j] * h);
        for (row, &i) in spatial.free.iter().enumerate() {
            lower[(row, row)] = finite(
                lower[(row, row)] + input.capacities_j_per_k[i],
                "capacity plus conduction overflow",
            )?;
        }
        let scale = (0..n)
            .flat_map(|i| (0..n).map(move |j| (i, j)))
            .map(|(i, j)| lower[(i, j)].abs())
            .fold(0.0_f64, f64::max);
        if !positive(scale) {
            return Err(Error::Numerical("invalid transient matrix scale"));
        }
        for i in 0..n {
            for j in 0..n {
                let x = finite(lower[(i, j)], "transient matrix overflow")?;
                lower[(i, j)] = x / scale;
                if x != 0.0 && lower[(i, j)] == 0.0 {
                    return Err(Error::Numerical("transient matrix scaling underflow"));
                }
            }
        }
        let req = cholesky_in_place_scratch::<f64>(n, Par::Seq, Default::default());
        if req.size_bytes() > limits.scratch_bytes.min(crate::MAX_SCRATCH_BYTES) {
            return Err(Error::Limit("transient Cholesky scratch"));
        }
        let mut memory = MemBuffer::new(req);
        checkpoint(control)?;
        cholesky_in_place(
            lower.as_mut(),
            Default::default(),
            Par::Seq,
            MemStack::new(&mut memory),
            Default::default(),
        )
        .map_err(|_| Error::Numerical("transient SPD factorization refused"))?;
        checkpoint(control)?;
        if (0..n).any(|i| !positive(lower[(i, i)])) {
            return Err(Error::Numerical("invalid transient Cholesky diagonal"));
        }
        Ok(Self { h, lower, scale })
    }
    fn solve(&self, rhs: &[f64], control: &dyn WorkControl) -> Result<Vec<f64>> {
        let n = rhs.len();
        charge(control, 2 * n * n + n)?;
        let mut x = Vec::with_capacity(n);
        for i in 0..n {
            let b = finite(rhs[i] / self.scale, "transient rhs scale")?;
            if rhs[i] != 0.0 && b == 0.0 {
                return Err(Error::Numerical("transient rhs scaling underflow"));
            }
            x.push(b);
        }
        for i in 0..n {
            x[i] = finite(
                sum(std::iter::once(x[i]).chain((0..i).map(|j| -self.lower[(i, j)] * x[j])))?
                    / self.lower[(i, i)],
                "forward triangular solve",
            )?;
        }
        for i in (0..n).rev() {
            x[i] = finite(
                sum(std::iter::once(x[i]).chain((i + 1..n).map(|j| -self.lower[(j, i)] * x[j])))?
                    / self.lower[(i, i)],
                "back triangular solve",
            )?;
        }
        Ok(x)
    }
}
#[derive(Clone, Default)]
struct Accumulator {
    value: f64,
    correction: f64,
}
impl Accumulator {
    fn add(&mut self, x: f64) -> Result<()> {
        let next = finite(self.value + x, "integrated heat sum overflow")?;
        self.correction = finite(
            self.correction
                + if self.value.abs() >= x.abs() {
                    (self.value - next) + x
                } else {
                    (x - next) + self.value
                },
            "integrated heat correction overflow",
        )?;
        self.value = next;
        Ok(())
    }
    fn total(&self) -> Result<f64> {
        finite(
            self.value + self.correction,
            "integrated heat total overflow",
        )
    }
}
struct Step {
    temperature: Vec<f64>,
    applied: Vec<f64>,
    reservoir: Vec<f64>,
    outgoing: Vec<f64>,
    residual: Vec<f64>,
    maximum_relative: f64,
}
struct Integrator<'a> {
    input: &'a TransientInput,
    spatial: Spatial,
    cache: VecDeque<Factor>,
    factorizations: usize,
    cache_hits: usize,
    substeps: usize,
}
impl Integrator<'_> {
    fn step(
        &mut self,
        temperature: &[f64],
        loads: &[f64],
        h: f64,
        limits: &Limits,
        control: &dyn WorkControl,
    ) -> Result<Step> {
        checkpoint(control)?;
        let n = temperature.len();
        let network = &self.input.network;
        charge(control, 4 * (n + network.links.len()))?;
        let reference = network.reference_temperature_k;
        let mut next = temperature.to_vec();
        if !self.spatial.free.is_empty() {
            let position = self.cache.iter().position(|f| f.h.to_bits() == h.to_bits());
            let factor = if let Some(i) = position {
                self.cache_hits += 1;
                self.cache.remove(i).unwrap()
            } else {
                self.factorizations += 1;
                Factor::new(&self.spatial, self.input, h, limits, control)?
            };
            let mut rhs = Vec::new();
            for &i in &self.spatial.free {
                rhs.push(sum([
                    product(
                        self.input.capacities_j_per_k[i],
                        finite(
                            temperature[i] - reference,
                            "temperature reference subtraction",
                        )?,
                    )?,
                    product(h, loads[i])?,
                ]
                .into_iter())?);
            }
            for ((i, j), link) in self.spatial.endpoints.iter().copied().zip(&network.links) {
                for (a, b) in [(i, j), (j, i)] {
                    if let Some(row) = self.spatial.free_index[a] {
                        if self.spatial.free_index[b].is_none() {
                            rhs[row] = sum([
                                rhs[row],
                                product(
                                    product(h, link.conductance_w_per_k)?,
                                    self.spatial.fixed_offsets[b],
                                )?,
                            ]
                            .into_iter())?;
                        }
                    }
                }
            }
            let offsets = factor.solve(&rhs, control)?;
            for (&i, offset) in self.spatial.free.iter().zip(offsets) {
                next[i] = finite(reference + offset, "absolute temperature reconstruction")?;
            }
            self.cache.push_front(factor);
            if self.cache.len() > FACTOR_CACHE_SIZE {
                self.cache.pop_back();
            }
        }
        self.substeps += 1;
        if next.iter().any(|t| !t.is_finite() || *t < 0.0) {
            return Err(Error::Numerical(
                "transient candidate below absolute zero or nonfinite",
            ));
        }
        // Independent ORIGINAL-node integrated balance from returned absolute T.
        let mut edge_heat = vec![Vec::new(); n];
        for ((i, j), link) in self.spatial.endpoints.iter().copied().zip(&network.links) {
            let heat = product(
                product(
                    link.conductance_w_per_k,
                    finite(next[i] - next[j], "edge temperature difference")?,
                )?,
                h,
            )?;
            edge_heat[i].push(heat);
            edge_heat[j].push(-heat);
        }
        let mut applied = Vec::new();
        let mut reservoir = Vec::new();
        let mut outgoing = Vec::new();
        let mut residual = Vec::new();
        let mut maximum = 0.0_f64;
        for i in 0..n {
            let q = product(h, loads[i])?;
            let out = sum(edge_heat[i].iter().copied())?;
            let storage = product(
                self.input.capacities_j_per_k[i],
                finite(next[i] - temperature[i], "storage temperature difference")?,
            )?;
            let boundary = if network.nodes[i].fixed_temperature_k.is_some() {
                sum([out, -q].into_iter())?
            } else {
                0.0
            };
            let r = sum([storage, -q, -boundary, out].into_iter())?;
            let magnitude = sum(edge_heat[i].iter().map(|x| x.abs()).chain([
                storage.abs(),
                q.abs(),
                boundary.abs(),
            ]))?;
            let absolute = product(h, network.power_tolerance_w)?;
            // Original-coordinate reconstruction has a capacity*epsilon*T floor.
            // This is a documented numerical acceptance tolerance, not a proof.
            let rounding = finite(
                32.0 * f64::EPSILON
                    * self.input.capacities_j_per_k[i]
                    * next[i].abs().max(temperature[i].abs()),
                "energy rounding allowance",
            )?;
            let permitted = finite(
                absolute + rounding + network.tolerances.consistency_relative * magnitude,
                "energy tolerance",
            )?;
            if r.abs() > permitted {
                return Err(Error::Numerical(
                    "original transient node energy balance failed",
                ));
            }
            maximum = maximum.max(r.abs() / magnitude.max(rounding).max(f64::MIN_POSITIVE));
            applied.push(q);
            reservoir.push(boundary);
            outgoing.push(out);
            residual.push(r);
        }
        Ok(Step {
            temperature: next,
            applied,
            reservoir,
            outgoing,
            residual,
            maximum_relative: maximum,
        })
    }
}
fn validate_schedule(input: &TransientInput) -> Result<Vec<f64>> {
    let n = input.network.nodes.len();
    let policy = &input.integration;
    if !positive(input.duration_s)
        || !positive(policy.initial_step_s)
        || !positive(policy.min_step_s)
        || !positive(policy.max_step_s)
        || policy.min_step_s > policy.initial_step_s
        || policy.initial_step_s > policy.max_step_s
        || !positive(policy.absolute_tolerance_k)
        || !policy.relative_tolerance.is_finite()
        || !(0.0..=0.01).contains(&policy.relative_tolerance)
        || policy.max_steps == 0
        || policy.max_steps > MAX_STEPS
    {
        return Err(Error::Invalid(
            "invalid time horizon, integration steps or tolerances".into(),
        ));
    }
    if input.loads.is_empty()
        || input.loads.len() > MAX_LOAD_CHANGES
        || input.sample_times_s.len() > MAX_SAMPLES
        || input.events.len() > MAX_EVENTS
    {
        return Err(Error::Limit("transient load/sample/event count"));
    }
    for (k, load) in input.loads.iter().enumerate() {
        if !load.start_time_s.is_finite()
            || load.start_time_s < 0.0
            || load.start_time_s >= input.duration_s
            || (k == 0 && load.start_time_s != 0.0)
            || (k > 0 && load.start_time_s <= input.loads[k - 1].start_time_s)
            || load.applied_heat_w.len() != n
            || load.applied_heat_w.iter().any(|x| !x.is_finite())
        {
            return Err(Error::Invalid("loads require increasing finite start times from zero and complete finite node-order vectors".into()));
        }
    }
    let mut ids = BTreeSet::new();
    for event in &input.events {
        if !text(&event.id, 128)
            || !ids.insert(&event.id)
            || !event.temperature_k.is_finite()
            || event.temperature_k < 0.0
            || !input.network.nodes.iter().any(|n| n.id == event.node_id)
        {
            return Err(Error::Invalid("invalid threshold event".into()));
        }
    }
    if input
        .sample_times_s
        .iter()
        .any(|t| !t.is_finite() || *t < 0.0 || *t > input.duration_s)
    {
        return Err(Error::Invalid(
            "sample time outside supplied horizon".into(),
        ));
    }
    let mut samples = input.sample_times_s.clone();
    samples.extend([0.0, input.duration_s]);
    samples.sort_by(f64::total_cmp);
    samples.dedup();
    Ok(samples)
}
fn hits(
    input: &TransientInput,
    old: &[f64],
    new: &[f64],
    start: f64,
    end: f64,
    output: &mut Vec<EventHit>,
) -> Result<()> {
    for event in &input.events {
        let i = input
            .network
            .nodes
            .iter()
            .position(|n| n.id == event.node_id)
            .unwrap();
        let rising = old[i] < event.temperature_k && new[i] >= event.temperature_k;
        let falling = old[i] > event.temperature_k && new[i] <= event.temperature_k;
        let matched = match event.direction {
            Direction::Rising => rising,
            Direction::Falling => falling,
            Direction::Either => rising || falling,
        };
        if matched {
            if output.len() >= MAX_EVENT_HITS {
                return Err(Error::Limit("transient threshold hits"));
            }
            let fraction = (event.temperature_k - old[i]) / (new[i] - old[i]);
            output.push(EventHit {
                id: event.id.clone(),
                node_id: event.node_id.clone(),
                direction: if rising { "rising" } else { "falling" }.into(),
                bracket_s: [start, end],
                linear_estimate_s: finite(start + (end - start) * fraction, "event interpolation")?,
                endpoint_temperature_k: [old[i], new[i]],
            });
        }
    }
    Ok(())
}
// Admit typed calls before serialization, cloning, or matrix allocation.
fn preflight(input: &TransientInput) -> Result<()> {
    let network = &input.network;
    let n = network.nodes.len();
    if n == 0
        || n > MAX_NODES
        || network.links.len() > MAX_LINKS
        || input.capacities_j_per_k.len() != n
        || input.initial_temperature_k.len() != n
        || input.loads.is_empty()
        || input.loads.len() > MAX_LOAD_CHANGES
        || input
            .loads
            .iter()
            .any(|load| load.applied_heat_w.len() != n)
        || input.sample_times_s.len() > MAX_SAMPLES
        || input.events.len() > MAX_EVENTS
    {
        return Err(Error::Limit("transient typed shape bounds"));
    }
    if !text(&network.description, 1024)
        || network.assumptions.is_empty()
        || network.assumptions.len() > 32
        || network.assumptions.iter().any(|value| !text(value, 1024))
        || network.nodes.iter().any(|node| !text(&node.id, 128))
        || network
            .links
            .iter()
            .any(|link| !text(&link.from, 128) || !text(&link.to, 128))
        || input
            .events
            .iter()
            .any(|event| !text(&event.id, 128) || !text(&event.node_id, 128))
    {
        return Err(Error::Invalid("transient typed text bounds".into()));
    }
    Ok(())
}
struct BoundedBytes {
    bytes: Vec<u8>,
    limit: usize,
}
impl std::io::Write for BoundedBytes {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        if bytes.len() > self.limit.saturating_sub(self.bytes.len()) {
            return Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                "transient request byte limit",
            ));
        }
        self.bytes.extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
// Cross-language request binding: all typed numeric fields use binary64, object
// keys are sorted, strings/container lengths use unsigned big-endian u64.
fn canonical_digest(value: &serde_json::Value, digest: &mut Sha256) -> Result<()> {
    use serde_json::Value;
    match value {
        Value::Null => digest.update(b"N"),
        Value::Bool(value) => digest.update(if *value { b"T" } else { b"F" }),
        Value::Number(value) => {
            let number =
                value
                    .as_f64()
                    .filter(|number| number.is_finite())
                    .ok_or(Error::Numerical(
                        "canonical request number outside binary64",
                    ))?;
            digest.update(b"F64");
            digest.update(number.to_bits().to_be_bytes());
        }
        Value::String(value) => {
            digest.update(b"S");
            digest.update((value.len() as u64).to_be_bytes());
            digest.update(value.as_bytes());
        }
        Value::Array(values) => {
            digest.update(b"A");
            digest.update((values.len() as u64).to_be_bytes());
            for value in values {
                canonical_digest(value, digest)?;
            }
        }
        Value::Object(values) => {
            digest.update(b"O");
            digest.update((values.len() as u64).to_be_bytes());
            let mut keys: Vec<_> = values.keys().collect();
            keys.sort();
            for key in keys {
                canonical_digest(&Value::String(key.clone()), digest)?;
                canonical_digest(&values[key], digest)?;
            }
        }
    }
    Ok(())
}
fn run(
    input: &TransientInput,
    limits: &Limits,
    control: &dyn WorkControl,
    memory: Option<&MemoryBudget>,
) -> Result<TransientResult> {
    checkpoint(control)?;
    preflight(input)?;
    let n = input.network.nodes.len();
    let byte_limit = limits.request_bytes.min(crate::MAX_REQUEST_BYTES);
    // Reserve before encoded buffers, canonical Value, spatial matrices or factors.
    // Vec growth can temporarily retain both old/new allocations, hence 4*cap.
    let allowance = byte_limit * 4
        + 8 * n * n * (FACTOR_CACHE_SIZE + 8)
        + 8 * n * (input.sample_times_s.len() + 2 + 64)
        + MAX_EVENT_HITS * 1024
        + cholesky_in_place_scratch::<f64>(n, Par::Seq, Default::default()).size_bytes();
    let reservation = memory
        .map(|budget| {
            budget
                .reserve(allowance)
                .map_err(|_| Error::Limit("shared transient memory"))
        })
        .transpose()?;
    let sample_times = validate_schedule(input)?;
    let spatial = Spatial::prepare(input, limits, control)?;
    let mut encoded = BoundedBytes {
        bytes: Vec::new(),
        limit: byte_limit,
    };
    serde_json::to_writer(&mut encoded, input)
        .map_err(|_| Error::Limit("transient request serialization bytes"))?;
    let mut digest = Sha256::new();
    canonical_digest(&serde_json::to_value(input)?, &mut digest)?;
    let identity = format!("sha256:{:x}", digest.finalize());
    let mut solver = Integrator {
        input,
        spatial,
        cache: VecDeque::new(),
        factorizations: 0,
        cache_hits: 0,
        substeps: 0,
    };
    let mut temperature = input.initial_temperature_k.clone();
    let mut t = 0.0;
    let mut h = input.integration.initial_step_s;
    let mut samples = vec![Sample {
        time_s: 0.0,
        temperature_k: temperature.clone(),
    }];
    let mut sample_index = 1;
    let mut load_index = 0;
    let mut applied = vec![Accumulator::default(); n];
    let mut reservoir = vec![Accumulator::default(); n];
    let mut outgoing = vec![Accumulator::default(); n];
    let mut maximum_node = vec![0.0_f64; n];
    let mut events = Vec::new();
    let mut attempted = 0;
    let mut accepted = 0;
    let mut rejected = 0;
    let mut max_error = 0.0_f64;
    let mut max_balance = 0.0_f64;
    let mut min_h = f64::INFINITY;
    let mut max_h = 0.0_f64;
    let mut local_work = 0usize;
    while t < input.duration_s {
        checkpoint(control)?;
        if attempted >= input.integration.max_steps {
            return Err(Error::Limit(
                "transient attempted step count; no complete trajectory",
            ));
        }
        while load_index + 1 < input.loads.len() && input.loads[load_index + 1].start_time_s <= t {
            load_index += 1;
        }
        let next_load = input
            .loads
            .get(load_index + 1)
            .map_or(input.duration_s, |l| l.start_time_s);
        let stop = sample_times[sample_index]
            .min(next_load)
            .min(input.duration_s);
        let step = h.min(input.integration.max_step_s).min(stop - t);
        if !positive(step) || t + step == t || t + 0.5 * step == t {
            return Err(Error::Numerical("transient time step cannot advance"));
        }
        attempted += 1;
        let size = solver.spatial.free.len();
        let full_cached = solver
            .cache
            .iter()
            .position(|f| f.h.to_bits() == step.to_bits());
        let half_cached = solver
            .cache
            .iter()
            .position(|f| f.h.to_bits() == (step / 2.0).to_bits());
        // A newly inserted full-step factor can evict the oldest half-step factor.
        let half_survives = half_cached.is_some()
            && !(full_cached.is_none()
                && solver.cache.len() == FACTOR_CACHE_SIZE
                && half_cached == Some(FACTOR_CACHE_SIZE - 1));
        let new_factors = if size == 0 {
            0
        } else {
            usize::from(full_cached.is_none()) + usize::from(!half_survives)
        };
        let estimate = new_factors * (size * size * size + size * size)
            + 3 * (2 * size * size + size + 4 * (n + input.network.links.len()))
            + 2 * input.events.len();
        local_work = local_work
            .checked_add(estimate)
            .ok_or(Error::Limit("transient work overflow"))?;
        if local_work > limits.work.min(crate::MAX_WORK) {
            return Err(Error::Limit("transient local work estimate"));
        }
        let loads = &input.loads[load_index].applied_heat_w;
        let full = solver.step(&temperature, loads, step, limits, control)?;
        let half = solver.step(&temperature, loads, step / 2.0, limits, control)?;
        let fine = solver.step(&half.temperature, loads, step / 2.0, limits, control)?;
        let mut error = 0.0_f64;
        for &i in &solver.spatial.free {
            let denominator = finite(
                input.integration.absolute_tolerance_k
                    + input.integration.relative_tolerance
                        * temperature[i].abs().max(fine.temperature[i].abs()),
                "local error scale",
            )?;
            error = error.max((fine.temperature[i] - full.temperature[i]).abs() / denominator);
        }
        if !error.is_finite() {
            return Err(Error::Numerical("nonfinite transient local estimate"));
        }
        if error > 1.0 {
            rejected += 1;
            if step <= input.integration.min_step_s {
                return Err(Error::Numerical("local error target unmet at minimum step"));
            }
            h = (step / 2.0).max(input.integration.min_step_s);
            continue;
        }
        accepted += 1;
        max_error = max_error.max(error);
        min_h = min_h.min(step);
        max_h = max_h.max(step);
        let end = if step == stop - t {
            stop
        } else {
            finite(t + step, "time advance")?
        };
        let middle = t + step / 2.0;
        charge(control, 2 * input.events.len())?;
        hits(
            input,
            &temperature,
            &half.temperature,
            t,
            middle,
            &mut events,
        )?;
        hits(
            input,
            &half.temperature,
            &fine.temperature,
            middle,
            end,
            &mut events,
        )?;
        for part in [&half, &fine] {
            max_balance = max_balance.max(part.maximum_relative);
            for i in 0..n {
                applied[i].add(part.applied[i])?;
                reservoir[i].add(part.reservoir[i])?;
                outgoing[i].add(part.outgoing[i])?;
                maximum_node[i] = maximum_node[i].max(part.residual[i].abs());
            }
        }
        temperature = fine.temperature;
        t = end;
        if t == sample_times[sample_index] {
            samples.push(Sample {
                time_s: t,
                temperature_k: temperature.clone(),
            });
            sample_index += 1;
        }
        if error < 0.2 {
            h = (step * 2.0).min(input.integration.max_step_s);
        } else {
            h = step;
        }
        h = h.max(input.integration.min_step_s);
    }
    let mut nodes = Vec::new();
    for i in 0..n {
        let storage = product(
            input.capacities_j_per_k[i],
            temperature[i] - input.initial_temperature_k[i],
        )?;
        let q = applied[i].total()?;
        let boundary = reservoir[i].total()?;
        let out = outgoing[i].total()?;
        let residual = sum([storage, -q, -boundary, out].into_iter())?;
        nodes.push(NodeEnergy {
            id: input.network.nodes[i].id.clone(),
            storage_change_j: storage,
            applied_heat_j: q,
            reservoir_heat_j: input.network.nodes[i].fixed_temperature_k.map(|_| boundary),
            outgoing_link_heat_j: out,
            integrated_balance_residual_j: residual,
            maximum_step_balance_residual_j: maximum_node[i],
        });
    }
    let storage = sum(nodes.iter().map(|n| n.storage_change_j))?;
    let q = sum(nodes.iter().map(|n| n.applied_heat_j))?;
    let boundary = sum(nodes.iter().map(|n| n.reservoir_heat_j.unwrap_or(0.0)))?;
    let energy = Energy {
        storage_change_j: storage,
        applied_heat_j: q,
        reservoir_heat_j: boundary,
        global_balance_residual_j: sum([storage, -q, -boundary].into_iter())?,
        internal_link_cancellation_j: sum(nodes.iter().map(|n| n.outgoing_link_heat_j))?,
        nodes,
    };
    Ok(TransientResult {
        schema: SCHEMA.into(),
        operation: "science.thermal_transient".into(),
        assurance: "untrusted floating-point supplied physical model; not formally verified".into(),
        outcome: "completed_with_local_error_control".into(),
        model_identity: identity,
        identity_encoding: "thermal-canonical-binary64-v1".into(),
        node_order: input.network.nodes.iter().map(|node| node.id.clone()).collect(),
        samples,
        events,
        energy,
        diagnostics: Diagnostics {
            attempted_steps: attempted,
            accepted_steps: accepted,
            rejected_steps: rejected,
            implicit_substeps: solver.substeps,
            factorizations: solver.factorizations,
            factor_cache_hits: solver.cache_hits,
            maximum_accepted_local_error_ratio: max_error,
            maximum_original_node_balance_relative_error: max_balance,
            minimum_accepted_step_s: min_h,
            maximum_accepted_step_s: max_h,
            method: "backward Euler step doubling; accepted two halfsteps; bounded exact-step-size Cholesky LRU".into(),
            threads: 1,
        },
        warnings: vec![
            "Constant passive conductances, positive lumped capacities and supplied loads are assumptions, not inferred physical truth. No advection, radiation, geometry inference or thermostat control.".into(),
            "Fixed reservoirs maintain constant temperatures throughout; their supplied capacities store no net heat. Reservoir heat is computed to close boundary energy balances, not independently measured cooling capacity.".into(),
            "Step-doubling differences control a numerical local estimate in kelvin, not rigorous global temperature or event-time error. Original-coordinate balance tolerance includes 32*epsilon*capacity*absolute-temperature roundoff allowance.".into(),
            "Threshold events use accepted-halfstep endpoint crossings with linear interpolation. Initial equality and grazing contacts are not crossings; absence means no sampled crossing found, not a certified absence. Rapid recrossings within a halfstep may be missed.".into(),
            "Base network applied_heat_w values are declarations only; the complete piecewise loads schedule supplies every actual transient source. No implicit inheritance or interpolation of load values.".into(),
            "Memory ledger allowance covers explicit native owners, not allocator/RSS or host JSON Values after serialization. Factors are reused only for identical step sizes and immutable spatial coefficients; the transient SPD solve does not use the steady solver's SVD rank cutoff.".into()
        ],
        _reservation: reservation,
    })
}
pub fn thermal_transient(
    input: &TransientInput,
    limits: &Limits,
    control: &dyn WorkControl,
) -> Result<TransientResult> {
    run(input, limits, control, None)
}
pub fn thermal_transient_with_context(
    input: &TransientInput,
    limits: &Limits,
    context: &ExecutionContext,
) -> Result<TransientResult> {
    run(input, limits, context, Some(context.memory()))
}
