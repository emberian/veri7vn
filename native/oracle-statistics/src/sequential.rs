//! Handwritten, untrusted numerical confidence sequence, not an extracted proof.
//! Hoeffding predictable plug-in construction: Waudby-Smith and Ramdas (2024),
//! §3.1, equations (8)--(12). No repeated fixed-time tests or mutable registry.
use crate::{Error, Limits, Result};
use oracle_execution::{ExecutionError, WorkControl};
use serde::{Deserialize, Serialize};

pub const METHOD: &str = "hoeffding-dyadic-v1";
const MAX_POSITION: usize = 65_536;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SequentialConfig {
    pub method: String,
    pub bounds: [f64; 2],
    /// This stream's allocation, not a family-wide error rate.
    pub alpha: f64,
    pub metric: String,
    pub unit: String,
    pub sampling_assumptions: Vec<String>,
    /// Required explanation of how this allocation fits all monitored metrics.
    pub multiplicity: String,
    /// Optional prespecified candidate for reported log e-capital bounds.
    pub hypothesis: Option<f64>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SequentialInput {
    pub config: SequentialConfig,
    pub observations: Vec<f64>,
}

/// Replayable data, never trusted cached capital. A caller can edit this value;
/// replay then computes a different experiment, not authenticated provenance.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SequentialState {
    pub config: SequentialConfig,
    pub position: usize,
    pub observations: Vec<f64>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SequentialPoint {
    pub position: usize,
    /// Running intersection; None means every common mean has been excluded.
    pub interval: Option<[f64; 2]>,
    /// Conservative lower bounds on positive/negative log e-capital, if asked.
    pub log_capital_lower: Option<[f64; 2]>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SequentialResult {
    pub operation: String,
    pub state: SequentialState,
    pub history: Vec<SequentialPoint>,
    pub interval: Option<[f64; 2]>,
    pub log_rejection_boundary_upper: f64,
    pub contract: String,
    pub numerical_status: String,
}

// Adjacent IEEE binary64 values. Each arithmetic operation is enclosed, including
// subnormals; no transcendental library implementation enters the decision.
fn down(x: f64) -> f64 {
    if x == 0. { return -f64::from_bits(1); }
    f64::from_bits(if x > 0. { x.to_bits() - 1 } else { x.to_bits() + 1 })
}
fn up(x: f64) -> f64 { -down(-x) }
#[derive(Clone, Copy)]
struct I { lo: f64, hi: f64 }
impl I {
    fn exact(x: f64) -> Self { Self { lo: x, hi: x } }
    fn add(self, b: Self) -> Self { Self { lo: down(self.lo+b.lo), hi: up(self.hi+b.hi) } }
    fn sub(self, b: Self) -> Self { Self { lo: down(self.lo-b.hi), hi: up(self.hi-b.lo) } }
    fn mul_positive(self, b: Self) -> Self {
        // Both operands must be nonnegative.
        Self { lo: down(self.lo*b.lo).max(0.), hi: up(self.hi*b.hi) }
    }
    fn div_positive(self, b: Self) -> Self {
        // Numerator may have either sign, denominator is strictly positive.
        let values = [self.lo/b.lo,self.lo/b.hi,self.hi/b.lo,self.hi/b.hi];
        Self { lo: down(values.iter().copied().fold(f64::INFINITY,f64::min)),
            hi: up(values.iter().copied().fold(f64::NEG_INFINITY,f64::max)) }
    }
}
fn invalid(message: &str) -> Error { Error::Invalid(message.into()) }
fn validate(c: &SequentialConfig) -> Result<()> {
    let [a,b] = c.bounds;
    if c.method != METHOD { return Err(invalid("unknown sequential method/version")); }
    if !a.is_finite() || !b.is_finite() || a >= b || !(b-a).is_finite()
        || down(b-a) <= 0. || !up(b-a).is_finite() {
        return Err(invalid("bounds need a finite, positive representable width"));
    }
    if !c.alpha.is_finite() || !(1e-12..1.).contains(&c.alpha) {
        return Err(invalid("alpha must be at least 1e-12 and below one"));
    }
    if c.metric.is_empty() || c.unit.is_empty() || c.multiplicity.is_empty()
        || c.sampling_assumptions.is_empty() || c.sampling_assumptions.len()>16
        || c.sampling_assumptions.iter().any(|x|x.is_empty() || x.len()>1024)
        || [&c.metric,&c.unit,&c.multiplicity].iter().any(|x|x.len()>1024) {
        return Err(invalid("bounded metric/unit, sampling assumptions and multiplicity required"));
    }
    if c.hypothesis.is_some_and(|m| !m.is_finite() || m<a || m>b) {
        return Err(invalid("hypothesis must lie in declared bounds"));
    }
    Ok(())
}
fn normalized(x: f64, bounds: [f64;2]) -> I {
    let width=I::exact(bounds[1]).sub(I::exact(bounds[0]));
    let numerator=I::exact(x).sub(I::exact(bounds[0]));
    let mut z=numerator.div_positive(width);
    z.lo=z.lo.max(0.); z.hi=z.hi.min(1.); z
}
fn physical(z: f64, c: &SequentialConfig, lower: bool) -> f64 {
    let width=I::exact(c.bounds[1]).sub(I::exact(c.bounds[0]));
    let x=I::exact(c.bounds[0]).add(I::exact(z).mul_positive(width));
    if lower { x.lo.max(c.bounds[0]) } else { x.hi.min(c.bounds[1]) }
}

fn charge(control: &dyn WorkControl, work: usize) -> Result<()> {
    control.checkpoint(work as u64).map_err(|error| match error {
        ExecutionError::Cancelled => Error::Cancelled,
        ExecutionError::Deadline => Error::Limit("shared deadline"),
        ExecutionError::FuelExhausted => Error::Limit("shared work"),
        _ => Error::Limit("shared execution budget"),
    })
}
fn admit_size(n: usize, work: usize, limits: &Limits) -> Result<()> {
    if n>limits.rows.min(MAX_POSITION) || work>limits.work {
        return Err(Error::Limit("sequential rows/work"));
    }
    if n.saturating_mul(128).saturating_add(32_768)>limits.scratch_bytes {
        return Err(Error::Limit("sequential scratch estimate"));
    }
    Ok(())
}
fn admit_observation(x: f64, bounds: [f64;2]) -> Result<()> {
    if !x.is_finite() || x<bounds[0] || x>bounds[1] {
        return Err(invalid("observation outside fixed bounds"));
    }
    Ok(())
}

#[derive(Clone, Copy)]
struct Accumulator {
    weights: I,
    weighted: I,
    penalty: I,
    hull: Option<[f64;2]>,
}
impl Accumulator {
    fn new() -> Self { Self { weights:I::exact(0.),weighted:I::exact(0.),
        penalty:I::exact(0.),hull:Some([0.,1.]) } }
    fn next(mut self, position: usize, x: f64, config: &SequentialConfig,
        boundary: f64) -> (Self, SequentialPoint) {
        // Selected using position only, before observing x_t.
        let exponent=((usize::BITS-1-position.leading_zeros())/2) as i32;
        let lambda=f64::from_bits(((1023-exponent) as u64)<<52);
        let l=I::exact(lambda);
        self.weights=self.weights.add(l);
        self.weighted=self.weighted.add(normalized(x,config.bounds).mul_positive(l));
        self.penalty=self.penalty.add(I::exact(lambda*lambda/8.));
        let radius=I::exact(boundary).add(self.penalty);
        let lo=self.weighted.sub(radius).div_positive(self.weights).lo.max(0.);
        let hi=self.weighted.add(radius).div_positive(self.weights).hi.min(1.);
        self.hull=self.hull.and_then(|old| {
            let next=[old[0].max(lo),old[1].min(hi)];
            if next[0]<=next[1] { Some(next) } else { None }
        });
        let logs=config.hypothesis.map(|m| {
            let center=normalized(m,config.bounds).mul_positive(self.weights);
            [self.weighted.sub(center).sub(self.penalty).lo,
                center.sub(self.weighted).sub(self.penalty).lo]
        });
        let point=SequentialPoint { position,
            interval:self.hull.map(|h|[physical(h[0],config,true),physical(h[1],config,false)]),
            log_capital_lower:logs };
        (self,point)
    }
}

/// Invariant-carrying live state. Private fields and no Deserialize prevent an
/// imported cached accumulator from bypassing replay. No mutable registry is
/// owned here. Append costs constant arithmetic plus amortized vector growth;
/// exporting the full observation/history snapshot is explicitly linear work.
pub struct SequentialMonitor {
    config: SequentialConfig,
    observations: Vec<f64>,
    history: Vec<SequentialPoint>,
    accumulator: Accumulator,
    boundary: f64,
}
impl SequentialMonitor {
    /// Start a declared experiment before any observation.
    pub fn new(config: SequentialConfig, limits: &Limits, control: &dyn WorkControl) -> Result<Self> {
        charge(control,1)?;
        validate(&config)?;
        admit_size(0,1,limits)?;
        // k=ceil(log2(2/alpha)) >= ln(2/alpha), using exact doubling.
        let mut scaled=config.alpha;
        let mut boundary=0.;
        while scaled<2. { scaled*=2.; boundary+=1.; }
        Ok(Self {config,observations:Vec::new(),history:Vec::new(),
            accumulator:Accumulator::new(),boundary})
    }
    /// Imported raw data is replayed once; no cached numerical state is accepted.
    /// This validates internal consistency, not authenticated sampling provenance.
    pub fn import(state: &SequentialState, limits: &Limits, control: &dyn WorkControl) -> Result<Self> {
        charge(control,0)?;
        if state.position!=state.observations.len() {
            return Err(invalid("sequential position mismatch"));
        }
        admit_size(state.position,state.position.saturating_mul(64).saturating_add(1),limits)?;
        validate(&state.config)?;
        let mut monitor=Self::new(state.config.clone(),limits,control)?;
        monitor.observations.reserve(state.position);
        monitor.history.reserve(state.position);
        for &x in &state.observations {
            monitor.append(monitor.position(),x,limits,control)?;
        }
        Ok(monitor)
    }
    fn from_input(input: &SequentialInput, limits: &Limits, control: &dyn WorkControl) -> Result<Self> {
        charge(control,0)?;
        // Bound imported storage/work before cloning or reserving anything.
        let n=input.observations.len();
        admit_size(n,n.saturating_mul(64).saturating_add(1),limits)?;
        validate(&input.config)?;
        let mut monitor=Self::new(input.config.clone(),limits,control)?;
        monitor.observations.reserve(n);
        monitor.history.reserve(n);
        for &x in &input.observations {
            monitor.append(monitor.position(),x,limits,control)?;
        }
        Ok(monitor)
    }
    pub fn position(&self) -> usize { self.observations.len() }
    pub fn config(&self) -> &SequentialConfig { &self.config }
    pub fn latest(&self) -> Option<&SequentialPoint> { self.history.last() }
    pub fn history(&self) -> &[SequentialPoint] { &self.history }
    /// An explicit O(n) raw snapshot. Restoring it always uses import/replay.
    pub fn export_state(&self) -> SequentialState {
        SequentialState {config:self.config.clone(),position:self.position(),
            observations:self.observations.clone()}
    }
    /// Rejected calls leave every private field unchanged. The execution budget
    /// can be charged on rejection, as with other pure numerical operations.
    pub fn append(&mut self, expected_position: usize, observation: f64,
        limits: &Limits, control: &dyn WorkControl) -> Result<SequentialPoint> {
        if expected_position!=self.position() {
            return Err(invalid("sequential position mismatch"));
        }
        let next_position=self.position()+1;
        admit_size(next_position,64,limits)?;
        admit_observation(observation,self.config.bounds)?;
        charge(control,64)?;
        let (next,point)=self.accumulator.next(next_position,observation,&self.config,self.boundary);
        // No fallible numerical work or cancellation after this commit point.
        self.observations.push(observation);
        self.history.push(point.clone());
        self.accumulator=next;
        Ok(point)
    }
    pub fn into_result(self) -> SequentialResult {
        let interval=self.history.last().map(|p|p.interval).unwrap_or(Some(self.config.bounds));
        SequentialResult {
            operation:"statistics.sequential_monitor".into(),
            state:SequentialState {config:self.config,position:self.observations.len(),observations:self.observations},
            history:self.history,interval,log_rejection_boundary_upper:self.boundary,
            contract:"Time-uniform common conditional mean under fixed bounds and the supplied sampling assumptions. Each tail receives alpha/2. Stopping on these intervals is allowed; drift, changed bounds, selected outcomes and unallocated additional metrics invalidate coverage. No future-observation interval or causal claim.".into(),
            numerical_status:"Handwritten IEEE-754 binary64 outward arithmetic; analytically conservative integer log threshold; no extracted numerical proof. No source/sampling authority.".into(),
        }
    }
}

pub fn replay(input: &SequentialInput, limits: &Limits, control: &dyn WorkControl) -> Result<SequentialResult> {
    Ok(SequentialMonitor::from_input(input,limits,control)?.into_result())
}

/// Raw-state convenience operation. Import is replayed once; use SequentialMonitor
/// for repeated live appends. Host persistence/retry identity remains external.
pub fn step(state: &SequentialState, expected_position: usize, observation: f64,
    limits: &Limits, control: &dyn WorkControl) -> Result<SequentialResult> {
    charge(control,0)?;
    if state.position!=expected_position || state.position!=state.observations.len() {
        return Err(invalid("sequential position mismatch"));
    }
    admit_size(state.position.saturating_add(1),state.position.saturating_mul(64).saturating_add(65),limits)?;
    validate(&state.config)?;
    admit_observation(observation,state.config.bounds)?;
    let mut monitor=SequentialMonitor::import(state,limits,control)?;
    monitor.append(expected_position,observation,limits,control)?;
    Ok(monitor.into_result())
}
