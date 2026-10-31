//! Bounded grouped-binomial logit and exposure-aware Poisson log likelihoods.
//!
//! This is untrusted numerical estimation plus a separate exact rational replay
//! boundary, not an Isabelle theorem. A small score alone never establishes a
//! finite MLE: accepted estimates also require a checked positive cone-balance
//! witness and exact full rank on the ORIGINAL supplied dyadic design. The
//! witness establishes existence/identifiability, not numerical optimality,
//! model truth, sampling independence, causal effects or interval coverage.
use crate::{Error, Limits, Result, SCHEMA};
use faer::diag::Diag;
use faer::dyn_stack::{MemBuffer, MemStack};
use faer::linalg::svd::{svd, svd_scratch, ComputeSvdVectors};
use faer::{Mat, Par};
use num_rational::BigRational as Q;
use num_traits::{Signed, Zero};
use oracle_execution::{ExecutionError, WorkControl};
use serde::{Deserialize, Serialize};
use statrs::distribution::{ContinuousCDF, Normal};

pub const OPERATION: &str = "statistics.events_exposure";
pub const MAX_GLM_ROWS: usize = 256;
pub const MAX_GLM_PARAMETERS: usize = 16;
pub const MAX_GLM_ITERATIONS: usize = 100;
pub const MAX_GLM_BACKTRACKS: usize = 32;
pub const MAX_EXACT_BITS: u64 = 4096;
pub const MAX_EXACT_WORK: usize = 400_000;
pub const MAX_COUNT_PER_ROW: u64 = 1_000_000_000;
const SCORE_TOLERANCE: f64 = 1e-8;
const MAX_DESIGN_CONDITION: f64 = 1e8;
const MAX_INFORMATION_CONDITION: f64 = 1e8;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Family { GroupedBinomialLogit, PoissonLog }
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Method { MaximumLikelihood }
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Uncertainty { None, ModelBasedWald }
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GlmModel {
    pub description: String,
    pub predictor_names: Vec<String>,
    pub predictor_units: Vec<String>,
    /// Caller assertion: the independent experimental/observational unit.
    pub independent_unit: String,
    /// Caller explanation of why grouped trials or counts form these rows.
    pub grouping: String,
    pub assumptions: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GlmPredictionInput {
    pub features: Vec<f64>,
    /// Required for Poisson predictions; forbidden for binomial predictions.
    #[serde(default)]
    pub exposure: Option<f64>,
    /// Optional binomial expected-success count, never a loss weight.
    #[serde(default)]
    pub trials: Option<u64>,
}
fn iterations_default() -> usize { 80 }
fn backtracks_default() -> usize { 24 }
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SolverOptions {
    #[serde(default = "iterations_default")]
    pub max_iterations: usize,
    #[serde(default = "backtracks_default")]
    pub max_backtracks: usize,
}
impl Default for SolverOptions {
    fn default() -> Self { Self { max_iterations: iterations_default(), max_backtracks: backtracks_default() } }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GlmInput {
    pub family: Family,
    pub method: Method,
    pub features: Vec<Vec<f64>>,
    pub intercept: bool,
    pub model: GlmModel,
    /// Binomial support is integral successes in 0..=trials, trials > 0.
    #[serde(default)] pub successes: Option<Vec<u64>>,
    #[serde(default)] pub trials: Option<Vec<u64>>,
    /// Poisson counts are integral, with strictly positive supplied exposure.
    #[serde(default)] pub counts: Option<Vec<u64>>,
    #[serde(default)] pub exposures: Option<Vec<f64>>,
    #[serde(default)] pub exposure_unit: Option<String>,
    pub uncertainty: Uncertainty,
    #[serde(default = "crate::confidence_default")] pub confidence_level: f64,
    #[serde(default = "crate::rank_default")] pub rank_relative: f64,
    #[serde(default)] pub solver: SolverOptions,
    #[serde(default)] pub predictions: Vec<GlmPredictionInput>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FiniteMleCertificate {
    pub family: Family,
    /// Binomial order: +x_i if successes>0, then -x_i if failures>0, in row order.
    /// Poisson order: original rows. Binomial weights must all be >0; Poisson
    /// weights must be >0 on zero-count rows and may have either sign otherwise.
    pub weights: Vec<String>,
    /// p distinct cone rows forming an exactly nonsingular square design.
    pub basis_rows: Vec<usize>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SeparationCertificate {
    pub family: Family,
    /// Original supplied parameter coordinates, intercept first when selected.
    pub direction: Vec<String>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    FiniteMleConverged,
    SeparationCertified,
    RankDeficient,
    DesignIllConditioned,
    NoFiniteMleEstablished,
    NotConverged,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GlmCoefficientInference {
    pub estimate: f64,
    pub standard_error: f64,
    pub pointwise_link_interval: [f64; 2],
    pub statistic_against_zero: f64,
    pub two_sided_p_against_zero: f64,
    /// Odds ratio for binomial, rate ratio for Poisson; intercept is baseline
    /// odds/rate. Missing when exponentiation is outside floating-point range.
    pub exponentiated_estimate: Option<f64>,
    pub pointwise_exponentiated_interval: Option<[f64; 2]>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GlmInference {
    pub reference_distribution: String,
    pub confidence_level: f64,
    pub critical_value: f64,
    pub coefficient_covariance: Vec<Vec<f64>>,
    pub coefficients: Vec<GlmCoefficientInference>,
    pub required_assumptions: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GlmObservation {
    pub linear_predictor: f64,
    pub fitted_mean_count: f64,
    pub fitted_probability: Option<f64>,
    pub rate_per_exposure_unit: Option<f64>,
    pub response_residual: f64,
    pub pearson_residual: Option<f64>,
    pub deviance_contribution: f64,
    pub leverage: Option<f64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GlmPrediction {
    pub features: Vec<f64>,
    pub exposure: Option<f64>,
    pub trials: Option<u64>,
    /// Binomial log odds, or Poisson log RATE (offset excluded).
    pub linear_predictor_without_offset: Option<f64>,
    pub probability: Option<f64>,
    pub rate_per_exposure_unit: Option<f64>,
    pub expected_count: Option<f64>,
    pub pointwise_probability_interval: Option<[f64; 2]>,
    pub pointwise_rate_interval: Option<[f64; 2]>,
    pub pointwise_expected_count_interval: Option<[f64; 2]>,
    pub unavailable_reasons: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GlmDiagnostics {
    pub observations: usize,
    pub parameters: usize,
    pub numerical_design_rank: usize,
    pub design_condition_2_scaled: Option<f64>,
    pub information_condition_2_scaled: Option<f64>,
    pub column_scales: Vec<f64>,
    pub iterations: usize,
    pub backtracks: usize,
    pub score_scaled_infinity_norm: Option<f64>,
    pub newton_decrement_squared: Option<f64>,
    /// Omits binomial choose(n,y) or Poisson log(y!) constants, includes offsets.
    pub log_likelihood_kernel: f64,
    pub deviance: f64,
    pub pearson_chi_square: Option<f64>,
    pub residual_degrees_of_freedom: usize,
    pub work_units: usize,
    pub exact_work_units: usize,
    pub svd_scratch_peak_bytes: usize,
    pub termination: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GlmResult {
    pub schema: String,
    pub operation: String,
    pub assurance: String,
    pub status: Status,
    /// Complete original supplied request; labels and assumptions stay assertions.
    pub supplied: GlmInput,
    pub parameter_names: Vec<String>,
    /// Last numerical iterate, NOT an estimate unless finite_mle_converged.
    pub coefficient_candidate: Vec<f64>,
    pub candidate_interpretation: String,
    pub finite_mle_certificate: Option<FiniteMleCertificate>,
    pub separation_certificate: Option<SeparationCertificate>,
    pub diagnostics: GlmDiagnostics,
    pub observations: Vec<GlmObservation>,
    pub predictions: Vec<GlmPrediction>,
    pub inference: Option<GlmInference>,
    pub inference_unavailable_reasons: Vec<String>,
    pub warnings: Vec<String>,
}

struct Budget<'a> {
    used: usize, exact: usize, maximum: usize, scratch: usize,
    control: &'a dyn WorkControl,
}
impl<'a> Budget<'a> {
    fn new(limits: &Limits, control: &'a dyn WorkControl) -> Self {
        Self { used: 0, exact: 0, maximum: limits.work.min(crate::MAX_WORK), scratch: 0, control }
    }
    fn pay(&mut self, work: usize) -> Result<()> {
        self.control.checkpoint(work as u64).map_err(|e| match e {
            ExecutionError::Cancelled => Error::Cancelled,
            ExecutionError::Deadline => Error::Limit("shared deadline"),
            _ => Error::Limit("shared execution budget"),
        })?;
        self.used = self.used.checked_add(work).ok_or(Error::Limit("GLM work"))?;
        if self.used > self.maximum { return Err(Error::Limit("GLM work")); }
        Ok(())
    }
    fn q(&mut self, q: &Q) -> Result<()> {
        self.pay(1)?; self.exact += 1;
        if self.exact > MAX_EXACT_WORK || q.numer().bits() > MAX_EXACT_BITS || q.denom().bits() > MAX_EXACT_BITS {
            return Err(Error::Limit("GLM exact witness arithmetic"));
        }
        Ok(())
    }
    fn rational(&mut self, value: f64) -> Result<Q> {
        let q = Q::from_float(value).ok_or(Error::Numerical("nonfinite exact witness proposal"))?;
        self.q(&q)?; Ok(q)
    }
    fn parse(&mut self, text: &str) -> Result<Q> {
        if text.is_empty() || text.len() > 2500 { return Err(Error::Invalid("bounded rational witness required".into())); }
        let q = text.parse::<Q>().map_err(|_| Error::Invalid("invalid rational witness".into()))?;
        self.q(&q)?; Ok(q)
    }
    fn dot(&mut self, a: &[Q], b: &[Q]) -> Result<Q> {
        let mut sum=Q::zero();
        for (x,y) in a.iter().zip(b) { let v=x*y; self.q(&v)?; sum+=v; self.q(&sum)?; }
        Ok(sum)
    }
}
struct Data { x: Vec<Vec<f64>>, scaled: Vec<Vec<f64>>, scales: Vec<f64>, offsets: Vec<f64>, n: usize, p: usize }
fn exposure_ok(x: f64) -> bool { x.is_finite() && x>0.0 && x.ln().abs() <= 500.0 }
fn admit(input: &GlmInput, limits: &Limits) -> Result<Data> {
    let n=input.features.len(); let q=input.features.first().map_or(0,Vec::len);
    let p=q.checked_add(usize::from(input.intercept)).ok_or(Error::Limit("GLM parameters"))?;
    if n==0 || p==0 { return Err(Error::Invalid("GLM needs observations and parameters".into())); }
    if n>limits.rows.min(MAX_GLM_ROWS) || p>limits.parameters.min(MAX_GLM_PARAMETERS)
        || input.predictions.len()>limits.predictions.min(crate::MAX_PREDICTIONS) { return Err(Error::Limit("GLM dimensions")); }
    if input.features.iter().any(|r| r.len()!=q || r.iter().any(|v| !v.is_finite())) {
        return Err(Error::Invalid("ragged or nonfinite GLM design".into()));
    }
    let m=&input.model;
    if !crate::label(&m.description) || !crate::label(&m.independent_unit) || !crate::label(&m.grouping)
        || m.predictor_names.len()!=q || m.predictor_units.len()!=q
        || m.predictor_names.iter().chain(&m.predictor_units).any(|s| !crate::label(s))
        || m.assumptions.is_empty() || m.assumptions.len()>16 || m.assumptions.iter().any(|s| !crate::label(s)) {
        return Err(Error::Invalid("explicit bounded GLM labels, grouping, independent unit and assumptions required".into()));
    }
    let mut names=std::collections::BTreeSet::new();
    if m.predictor_names.iter().any(|s| !names.insert(s)) || (input.intercept && m.predictor_names.iter().any(|s| s=="intercept")) {
        return Err(Error::Invalid("GLM predictor names must be unique and not alias intercept".into()));
    }
    if !input.confidence_level.is_finite() || !(0.5..=0.999).contains(&input.confidence_level)
        || !input.rank_relative.is_finite() || !(f64::EPSILON..=0.01).contains(&input.rank_relative)
        || !(1..=MAX_GLM_ITERATIONS).contains(&input.solver.max_iterations)
        || !(1..=MAX_GLM_BACKTRACKS).contains(&input.solver.max_backtracks) {
        return Err(Error::Invalid("GLM confidence, rank tolerance or iteration/backtracking limits".into()));
    }
    let offsets=match input.family {
        Family::GroupedBinomialLogit => {
            let s=input.successes.as_ref().ok_or_else(|| Error::Invalid("binomial successes required".into()))?;
            let t=input.trials.as_ref().ok_or_else(|| Error::Invalid("binomial trials required".into()))?;
            if s.len()!=n || t.len()!=n || s.iter().zip(t).any(|(s,t)| *t==0 || *t>MAX_COUNT_PER_ROW || s>t)
                || input.counts.is_some() || input.exposures.is_some() || input.exposure_unit.is_some() {
                return Err(Error::Invalid("binomial support or forbidden count/exposure fields".into()));
            }
            vec![0.0;n]
        }
        Family::PoissonLog => {
            let y=input.counts.as_ref().ok_or_else(|| Error::Invalid("Poisson counts required".into()))?;
            let e=input.exposures.as_ref().ok_or_else(|| Error::Invalid("Poisson exposures required".into()))?;
            if y.len()!=n || e.len()!=n || y.iter().any(|y| *y>MAX_COUNT_PER_ROW) || e.iter().any(|e| !exposure_ok(*e))
                || input.exposure_unit.as_ref().is_none_or(|s| !crate::label(s)) || input.successes.is_some() || input.trials.is_some() {
                return Err(Error::Invalid("Poisson support, exposure/unit or forbidden binomial fields".into()));
            }
            e.iter().map(|e| e.ln()).collect()
        }
    };
    for pred in &input.predictions {
        if pred.features.len()!=q || pred.features.iter().any(|v| !v.is_finite()) { return Err(Error::Invalid("GLM prediction features".into())); }
        match input.family {
            Family::GroupedBinomialLogit if pred.exposure.is_some() || pred.trials.is_some_and(|t| t==0 || t>MAX_COUNT_PER_ROW) =>
                return Err(Error::Invalid("binomial prediction has invalid trials or exposure".into())),
            Family::PoissonLog if pred.trials.is_some() || pred.exposure.is_none_or(|e| !exposure_ok(e)) =>
                return Err(Error::Invalid("Poisson prediction requires exposure and forbids trials".into())),
            _=>{}
        }
    }
    let x:Vec<_>=input.features.iter().map(|r| crate::design_row(r,input.intercept)).collect();
    let scales:Vec<_>=(0..p).map(|j| x.iter().map(|r| r[j].abs()).fold(0.0,f64::max).max(f64::MIN_POSITIVE)).collect();
    let scaled:Vec<Vec<f64>>=x.iter().map(|r| r.iter().zip(&scales).map(|(x,s)| x/s).collect()).collect();
    if x.iter().zip(&scaled).any(|(r,z)| r.iter().zip(z).any(|(x,z)| *x!=0.0 && *z==0.0)) {
        return Err(Error::Numerical("GLM column normalization underflow"));
    }
    Ok(Data{x,scaled,scales,offsets,n,p})
}
struct Svd { s: Vec<f64>, v: Vec<Vec<f64>>, rank: usize, condition: Option<f64> }
fn decompose(rows: &[Vec<f64>], rank_relative: f64, limits:&Limits, budget:&mut Budget<'_>) -> Result<Svd> {
    let n=rows.len(); let p=rows[0].len(); let k=n.min(p);
    budget.pay(n.checked_mul(p).and_then(|w| w.checked_mul(p)).ok_or(Error::Limit("GLM SVD work"))?)?;
    let req=svd_scratch::<f64>(n,p,ComputeSvdVectors::Thin,ComputeSvdVectors::Thin,Par::Seq,Default::default());
    if req.size_bytes()>limits.scratch_bytes.min(crate::MAX_SCRATCH_BYTES) { return Err(Error::Limit("GLM SVD scratch")); }
    budget.scratch=budget.scratch.max(req.size_bytes());
    let a=Mat::<f64>::from_fn(n,p,|i,j|rows[i][j]);
    let mut u=Mat::<f64>::zeros(n,k); let mut v=Mat::<f64>::zeros(p,k); let mut s=Diag::<f64>::zeros(k);
    let mut memory=MemBuffer::new(req);
    svd(a.as_ref(),s.as_mut(),Some(u.as_mut()),Some(v.as_mut()),Par::Seq,MemStack::new(&mut memory),Default::default())
        .map_err(|_|Error::Numerical("GLM SVD did not converge"))?;
    budget.pay(1)?;
    let spectrum:Vec<_>=(0..k).map(|j|s[j]).collect();
    if spectrum.iter().any(|s| !s.is_finite() || *s<0.0) || spectrum.windows(2).any(|w| w[0]<w[1]) {
        return Err(Error::Numerical("invalid GLM SVD spectrum"));
    }
    let cutoff=spectrum[0]*rank_relative; let rank=spectrum.iter().filter(|s| **s>cutoff).count();
    let condition=if rank==p { Some(spectrum[0]/spectrum[p-1]) } else { None };
    Ok(Svd{s:spectrum,v:(0..p).map(|j|(0..k).map(|k|v[(j,k)]).collect()).collect(),rank,condition})
}
fn softplus(x:f64)->f64 { if x>0.0 { x+(-x).exp().ln_1p() } else { x.exp().ln_1p() } }
fn logistic_pair(x:f64)->(f64,f64) {
    if x>=0.0 { let e=(-x).exp(); (1.0/(1.0+e),e/(1.0+e)) }
    else { let e=x.exp(); (e/(1.0+e),1.0/(1.0+e)) }
}
fn exp_positive(x:f64)->Option<f64> { let v=x.exp(); if v.is_finite() && v>0.0 { Some(v) } else { None } }
struct Evaluation {
    eta:Vec<f64>,mu:Vec<f64>,probability:Vec<Option<f64>>,failprob:Vec<f64>,
    residual:Vec<f64>,weights:Vec<f64>,deviance:Vec<f64>,ll:f64,
}
fn evaluate(input:&GlmInput,data:&Data,theta:&[f64],budget:&mut Budget<'_>)->Result<Option<Evaluation>> {
    budget.pay(data.n*data.p)?;
    let mut e=Evaluation{eta:vec![],mu:vec![],probability:vec![],failprob:vec![],residual:vec![],weights:vec![],deviance:vec![],ll:0.0};
    let mut likelihood=Vec::with_capacity(data.n);
    for i in 0..data.n {
        let eta=crate::dot(&data.scaled[i],theta)?+data.offsets[i];
        if !eta.is_finite() { return Ok(None); }
        let (mu,prob,q,residual,w,ll,deviance)=match input.family {
            Family::GroupedBinomialLogit=>{
                let s=input.successes.as_ref().unwrap()[i] as f64;
                let t=input.trials.as_ref().unwrap()[i] as f64; let f=t-s;
                let (p,q)=logistic_pair(eta); let logp=-softplus(-eta); let logq=-softplus(eta);
                let ll=s*logp+f*logq;
                let sat=if s>0.0{s*(s/t).ln()}else{0.0}+if f>0.0{f*(f/t).ln()}else{0.0};
                (t*p,Some(p),q,s*q-f*p,t*p*q,ll,(2.0*(sat-ll)).max(0.0))
            }
            Family::PoissonLog=>{
                let y=input.counts.as_ref().unwrap()[i] as f64; let mu=eta.exp();
                if !mu.is_finite() { return Ok(None); }
                let ll=y*eta-mu;
                let d=if y>0.0{2.0*(y*(y.ln()-eta)-y+mu)}else{2.0*mu};
                (mu,None,0.0,y-mu,mu,ll,d.max(0.0))
            }
        };
        if [mu,residual,w,ll,deviance].iter().any(|v| !v.is_finite()) { return Ok(None); }
        e.eta.push(eta);e.mu.push(mu);e.probability.push(prob);e.failprob.push(q);e.residual.push(residual);
        e.weights.push(w);e.deviance.push(deviance);likelihood.push(ll);
    }
    e.ll=crate::sum(likelihood.into_iter())?; Ok(Some(e))
}
struct Newton { decomposition:Svd,weight_scale:f64,score_norm:f64,decrement:f64,step:Vec<f64> }
fn newton(data:&Data,e:&Evaluation,input:&GlmInput,limits:&Limits,budget:&mut Budget<'_>)->Result<Option<Newton>> {
    let scale=e.weights.iter().copied().fold(0.0,f64::max);
    if scale==0.0 { return Ok(None); }
    let rows:Vec<Vec<_>>=data.scaled.iter().zip(&e.weights).map(|(r,w)|r.iter().map(|x|x*(w/scale).sqrt()).collect()).collect();
    let decomposition=decompose(&rows,input.rank_relative,limits,budget)?;
    if decomposition.rank<data.p { return Ok(None); }
    let score:Vec<f64>=(0..data.p).map(|j|crate::sum((0..data.n).map(|i|data.scaled[i][j]*e.residual[i]))).collect::<Result<_>>()?;
    let mut score_norm=0.0f64;
    for j in 0..data.p {
        let diagonal=crate::sum((0..data.n).map(|i|e.weights[i]*data.scaled[i][j]*data.scaled[i][j]))?;
        if diagonal<=0.0 { return Ok(None); }
        score_norm=score_norm.max(score[j].abs()/diagonal.sqrt());
    }
    let projected:Vec<f64>=(0..data.p).map(|k|crate::sum((0..data.p).map(|j|decomposition.v[j][k]*score[j]))).collect::<Result<_>>()?;
    let mut step=vec![0.0;data.p]; let mut decrements=vec![];
    for k in 0..data.p {
        let standardized=projected[k]/(scale.sqrt()*decomposition.s[k]);
        let multiple=(projected[k]/scale)/decomposition.s[k]/decomposition.s[k];
        if !standardized.is_finite() || !multiple.is_finite() { return Ok(None); }
        decrements.push(standardized*standardized);
        for j in 0..data.p {step[j]+=decomposition.v[j][k]*multiple;}
    }
    let decrement=crate::sum(decrements.into_iter())?;
    if step.iter().any(|v| !v.is_finite()) || !score_norm.is_finite() { return Ok(None); }
    Ok(Some(Newton{decomposition,weight_scale:scale,score_norm,decrement,step}))
}

struct Cone { rows:Vec<Vec<Q>>, strict:Vec<bool>, sample:Vec<usize>, sign:Vec<i8> }
fn cone(input:&GlmInput,data:&Data,budget:&mut Budget<'_>)->Result<Cone> {
    let mut c=Cone{rows:vec![],strict:vec![],sample:vec![],sign:vec![]};
    for i in 0..data.n {
        let row:Vec<Q>=data.x[i].iter().map(|x|budget.rational(*x)).collect::<Result<_>>()?;
        match input.family {
            Family::GroupedBinomialLogit=>{
                let s=input.successes.as_ref().unwrap()[i]; let t=input.trials.as_ref().unwrap()[i];
                if s>0 {c.rows.push(row.clone());c.strict.push(true);c.sample.push(i);c.sign.push(1);}
                if s<t {c.rows.push(row.iter().map(|x|-x).collect());c.strict.push(true);c.sample.push(i);c.sign.push(-1);}
            }
            Family::PoissonLog=>{c.rows.push(row);c.strict.push(input.counts.as_ref().unwrap()[i]==0);c.sample.push(i);c.sign.push(1);}
        }
    }
    Ok(c)
}
/// Exact elimination selects original independent row occurrences, not an SVD
/// assertion. All products/divisions are metered and checked for rational growth.
fn basis_rows(rows:&[Vec<Q>],p:usize,budget:&mut Budget<'_>)->Result<Vec<usize>> {
    let mut a=rows.to_vec(); let mut ids:Vec<_>=(0..rows.len()).collect(); let mut rank=0;
    for col in 0..p {
        let Some(pivot)=(rank..a.len()).find(|i|!a[*i][col].is_zero()) else {continue};
        a.swap(rank,pivot);ids.swap(rank,pivot);
        let divisor=a[rank][col].clone();
        for j in col..p {a[rank][j]/=&divisor;budget.q(&a[rank][j])?;}
        for i in rank+1..a.len() {
            if a[i][col].is_zero(){continue;}
            let factor=a[i][col].clone();
            for j in col..p {let v=&factor*&a[rank][j];budget.q(&v)?;a[i][j]-=v;budget.q(&a[i][j])?;}
        }
        rank+=1; if rank==p {break;}
    }
    Ok(ids[..rank].to_vec())
}
fn solve_square(mut a:Vec<Vec<Q>>,mut b:Vec<Q>,budget:&mut Budget<'_>)->Result<Option<Vec<Q>>> {
    let p=b.len();
    for col in 0..p {
        let Some(pivot)=(col..p).find(|i|!a[*i][col].is_zero()) else {return Ok(None)};
        a.swap(col,pivot);b.swap(col,pivot); let divisor=a[col][col].clone();
        for j in col..p {a[col][j]/=&divisor;budget.q(&a[col][j])?;}
        b[col]/=&divisor;budget.q(&b[col])?;
        for i in 0..p {
            if i==col || a[i][col].is_zero(){continue;}
            let factor=a[i][col].clone();
            for j in col..p {let v=&factor*&a[col][j];budget.q(&v)?;a[i][j]-=v;budget.q(&a[i][j])?;}
            let v=&factor*&b[col];budget.q(&v)?;b[i]-=v;budget.q(&b[i])?;
        }
    }
    Ok(Some(b))
}
fn verify_finite(c:&Cone,p:usize,cert:&FiniteMleCertificate,budget:&mut Budget<'_>)->Result<bool> {
    if cert.weights.len()!=c.rows.len() || cert.basis_rows.len()!=p {return Ok(false);}
    let mut seen=std::collections::BTreeSet::new();
    if cert.basis_rows.iter().any(|i|*i>=c.rows.len() || !seen.insert(*i)) {return Ok(false);}
    let weights:Vec<Q>=cert.weights.iter().map(|s|budget.parse(s)).collect::<Result<_>>()?;
    if weights.iter().zip(&c.strict).any(|(w,strict)|*strict && w<=&Q::zero()) {return Ok(false);}
    for j in 0..p {
        let column:Vec<_>=c.rows.iter().map(|r|r[j].clone()).collect();
        if !budget.dot(&column,&weights)?.is_zero(){return Ok(false);}
    }
    let square:Vec<_>=cert.basis_rows.iter().map(|i|c.rows[*i].clone()).collect();
    Ok(solve_square(square,vec![Q::zero();p],budget)?.is_some())
}
/// Independently replay a finite-MLE existence/identifiability witness against
/// the ORIGINAL f64 values interpreted as exact dyadic rationals. No tolerance
/// is used for positivity, balance, or rank. False is not a separation claim.
pub fn verify_finiteness_certificate(input:&GlmInput,cert:&FiniteMleCertificate,limits:&Limits,control:&dyn WorkControl)->Result<bool> {
    let mut budget=Budget::new(limits,control);budget.pay(1)?;
    let data=admit(input,limits)?;
    if cert.family!=input.family{return Ok(false);}
    let c=cone(input,&data,&mut budget)?;verify_finite(&c,data.p,cert,&mut budget)
}
fn finite_witness(input:&GlmInput,data:&Data,e:&Evaluation,c:&Cone,budget:&mut Budget<'_>)->Result<Option<FiniteMleCertificate>> {
    let basis=basis_rows(&c.rows,data.p,budget)?;
    if basis.len()!=data.p{return Ok(None);}
    let mut weights=Vec::with_capacity(c.rows.len());
    for k in 0..c.rows.len() {
        let i=c.sample[k];
        let w=match input.family {
            Family::GroupedBinomialLogit=>if c.sign[k]>0 {input.successes.as_ref().unwrap()[i] as f64*e.failprob[i]}
                else {(input.trials.as_ref().unwrap()[i]-input.successes.as_ref().unwrap()[i]) as f64*e.probability[i].unwrap()},
            Family::PoissonLog=>e.mu[i]-input.counts.as_ref().unwrap()[i] as f64,
        };
        if c.strict[k] && w<=0.0{return Ok(None);}
        weights.push(budget.rational(w)?);
    }
    let mut residual=vec![];
    for j in 0..data.p {
        let column:Vec<_>=c.rows.iter().map(|r|r[j].clone()).collect();
        residual.push(-budget.dot(&column,&weights)?);
    }
    // Repair the proposed almost-balanced weights exactly, on a full-rank
    // subset. Positive repaired weights are a witness; failure is inconclusive.
    let square:Vec<Vec<Q>>=(0..data.p).map(|j|basis.iter().map(|i|c.rows[*i][j].clone()).collect()).collect();
    let Some(correction)=solve_square(square,residual,budget)? else{return Ok(None)};
    for (index,correction) in basis.iter().zip(correction) {weights[*index]+=correction;budget.q(&weights[*index])?;}
    let cert=FiniteMleCertificate{family:input.family,weights:weights.iter().map(ToString::to_string).collect(),basis_rows:basis};
    if verify_finite(c,data.p,&cert,budget)?{Ok(Some(cert))}else{Ok(None)}
}
fn verify_separation(c:&Cone,input:&GlmInput,p:usize,cert:&SeparationCertificate,budget:&mut Budget<'_>)->Result<bool> {
    if cert.family!=input.family || cert.direction.len()!=p{return Ok(false);}
    let d:Vec<Q>=cert.direction.iter().map(|s|budget.parse(s)).collect::<Result<_>>()?;
    let mut strict=false;
    for (i,row) in c.rows.iter().enumerate() {
        let v=budget.dot(row,&d)?;
        match input.family {
            Family::GroupedBinomialLogit=>{if v.is_negative(){return Ok(false);}strict|=v.is_positive();}
            Family::PoissonLog=>{
                if c.strict[i] {if v.is_positive(){return Ok(false);}strict|=v.is_negative();}
                else if !v.is_zero(){return Ok(false);}
            }
        }
    }
    Ok(strict)
}
/// Replay a strict improving recession direction. Binomial signed design dots
/// are >=0 with at least one >0. Poisson positive-count rows have dot=0,
/// zero-count rows dot<=0 with at least one <0. Acceptance rules out a finite
/// maximizer of the specified unpenalized likelihood, not model feasibility.
pub fn verify_separation_certificate(input:&GlmInput,cert:&SeparationCertificate,limits:&Limits,control:&dyn WorkControl)->Result<bool> {
    let mut budget=Budget::new(limits,control);budget.pay(1)?;let data=admit(input,limits)?;
    let c=cone(input,&data,&mut budget)?;verify_separation(&c,input,data.p,cert,&mut budget)
}
/// Project an approximate direction into the exact nullspace of interior
/// binomial rows / positive-count Poisson rows before checking its inequalities.
fn equality_space(input:&GlmInput,data:&Data,budget:&mut Budget<'_>)->Result<(Vec<Vec<Q>>,Vec<usize>)> {
    let mut a=vec![];
    for i in 0..data.n {
        let equality=match input.family {
            Family::GroupedBinomialLogit=>{let s=input.successes.as_ref().unwrap()[i];s>0 && s<input.trials.as_ref().unwrap()[i]},
            Family::PoissonLog=>input.counts.as_ref().unwrap()[i]>0,
        };
        if equality{a.push(data.x[i].iter().map(|x|budget.rational(*x)).collect::<Result<Vec<_>>>()?);}
    }
    let mut rank=0;let mut pivots=vec![];
    for col in 0..data.p {
        let Some(pivot)=(rank..a.len()).find(|i|!a[*i][col].is_zero())else{continue};
        a.swap(rank,pivot);let divisor=a[rank][col].clone();
        for j in col..data.p{a[rank][j]/=&divisor;budget.q(&a[rank][j])?;}
        for i in 0..a.len(){if i==rank || a[i][col].is_zero(){continue;}
            let factor=a[i][col].clone();for j in col..data.p{let v=&factor*&a[rank][j];budget.q(&v)?;a[i][j]-=v;budget.q(&a[i][j])?;}}
        pivots.push(col);rank+=1;if rank==data.p{break;}
    }
    a.truncate(rank);Ok((a,pivots))
}
fn separation_witness(input:&GlmInput,data:&Data,beta:&[f64],c:&Cone,budget:&mut Budget<'_>)->Result<Option<SeparationCertificate>> {
    let norm=beta.iter().map(|v|v.abs()).fold(0.0,f64::max);
    if norm==0.0{return Ok(None);}
    let (equalities,pivots)=equality_space(input,data,budget)?;
    if pivots.len()==data.p{return Ok(None);}
    // These are only candidate generators. Every returned direction is replayed
    // with exact original rows; rounding never decides a mathematical status.
    for denominator in [1.0,16.0,256.0,4096.0,65536.0,1048576.0] {
        for sign in [1.0,-1.0] {
            let mut d:Vec<_>=beta.iter().map(|b|budget.rational((sign*b/norm*denominator).round()/denominator)).collect::<Result<_>>()?;
            for col in &pivots{d[*col]=Q::zero();}
            for (i,col) in pivots.iter().enumerate(){d[*col]=-budget.dot(&equalities[i],&d)?;}
            let cert=SeparationCertificate{family:input.family,direction:d.iter().map(ToString::to_string).collect()};
            if verify_separation(c,input,data.p,&cert,budget)?{return Ok(Some(cert));}
        }
    }
    Ok(None)
}

fn inverse_factors(data:&Data,n:&Newton,budget:&mut Budget<'_>)->Result<Vec<Vec<f64>>> {
    budget.pay(data.p*data.p)?;
    let factors:Vec<Vec<f64>>=(0..data.p).map(|j|(0..data.p).map(|k|
        n.decomposition.v[j][k]/n.decomposition.s[k]/n.weight_scale.sqrt()/data.scales[j]).collect()).collect();
    if factors.iter().flatten().any(|v|!v.is_finite()){return Err(Error::Numerical("GLM information inverse overflows"));}
    Ok(factors)
}
fn inference(input:&GlmInput,data:&Data,beta:&[f64],n:&Newton,budget:&mut Budget<'_>)->Result<Option<GlmInference>> {
    if input.uncertainty==Uncertainty::None{return Ok(None);}
    let condition=n.decomposition.condition.unwrap_or(f64::INFINITY).powi(2);
    if condition>MAX_INFORMATION_CONDITION{return Ok(None);}
    budget.pay(data.p*data.p*data.p)?;
    let f=inverse_factors(data,n,budget)?;
    let covariance:Vec<Vec<f64>>=(0..data.p).map(|i|(0..data.p).map(|j|crate::dot(&f[i],&f[j])).collect()).collect::<Result<_>>()?;
    let normal=Normal::new(0.0,1.0).map_err(|_|Error::Numerical("normal reference"))?;
    let critical=normal.inverse_cdf(0.5+input.confidence_level/2.0);budget.pay(1)?;
    let mut coefficients=vec![];
    for j in 0..data.p {
        let se=covariance[j][j].sqrt();let statistic=beta[j]/se;
        let interval=[beta[j]-critical*se,beta[j]+critical*se];
        if se<=0.0 || !statistic.is_finite() || interval.iter().any(|v|!v.is_finite()){return Ok(None);}
        let exp_interval=match(exp_positive(interval[0]),exp_positive(interval[1])){(Some(a),Some(b))=>Some([a,b]),_=>None};
        coefficients.push(GlmCoefficientInference{estimate:beta[j],standard_error:se,pointwise_link_interval:interval,
            statistic_against_zero:statistic,two_sided_p_against_zero:2.0*normal.sf(statistic.abs()),
            exponentiated_estimate:exp_positive(beta[j]),pointwise_exponentiated_interval:exp_interval});
    }
    Ok(Some(GlmInference{reference_distribution:"asymptotic standard normal; model-based inverse Fisher information; dispersion fixed at 1".into(),
        confidence_level:input.confidence_level,critical_value:critical,coefficient_covariance:covariance,coefficients,
        required_assumptions:match input.family {
            Family::GroupedBinomialLogit=>vec!["Independent binomial rows with the stated positive trial totals and common within-row success probability; correct prespecified logit-linear conditional probabilities.",
                "Grouping does not create independence: within-row trials are independent conditional on supplied predictors, and rows are independent at the caller's declared sampling unit."],
            Family::PoissonLog=>vec!["Independent Poisson counts with means equal to supplied positive exposure times the prespecified log-linear rate; exposure and predictors are fixed or conditioned on.",
                "Variance equals mean; no extra-Poisson dispersion, zero-inflation, clustering or serial dependence is corrected."],
        }.into_iter().chain(["Usual large-sample regularity; no finite-sample coverage, selection, multiplicity, optional-stopping or causal guarantee."]).map(str::to_string).collect()}))
}
fn predict(input:&GlmInput,data:&Data,beta:&[f64],n:Option<&Newton>,inf:Option<&GlmInference>,accepted:bool,budget:&mut Budget<'_>)->Result<Vec<GlmPrediction>> {
    let factors=if accepted && inf.is_some(){Some(inverse_factors(data,n.unwrap(),budget)?)}else{None};
    let mut predictions=vec![];
    for request in &input.predictions {
        budget.pay(data.p*data.p)?;
        let mut p=GlmPrediction{features:request.features.clone(),exposure:request.exposure,trials:request.trials,
            linear_predictor_without_offset:None,probability:None,rate_per_exposure_unit:None,expected_count:None,
            pointwise_probability_interval:None,pointwise_rate_interval:None,pointwise_expected_count_interval:None,unavailable_reasons:vec![]};
        if !accepted{p.unavailable_reasons.push("no_converged_certified_finite_mle".into());predictions.push(p);continue;}
        let row=crate::design_row(&request.features,input.intercept);let link=crate::dot(&row,beta)?;
        if !link.is_finite(){p.unavailable_reasons.push("prediction_link_overflow".into());predictions.push(p);continue;}
        p.linear_predictor_without_offset=Some(link);
        match input.family {
            Family::GroupedBinomialLogit=>{let probability=logistic_pair(link).0;p.probability=Some(probability);p.expected_count=request.trials.map(|t|t as f64*probability);}
            Family::PoissonLog=>{p.rate_per_exposure_unit=exp_positive(link);p.expected_count=exp_positive(link+request.exposure.unwrap().ln());
                if p.rate_per_exposure_unit.is_none() || p.expected_count.is_none(){p.unavailable_reasons.push("prediction_exponent_outside_floating_point_range".into());}}
        }
        if let (Some(f),Some(inf))=(&factors,inf) {
            let mut projected=vec![];
            for k in 0..data.p{projected.push(crate::sum((0..data.p).map(|j|row[j]*f[j][k]))?);}
            let se=crate::norm(projected.into_iter())?;let interval=[link-inf.critical_value*se,link+inf.critical_value*se];
            if interval.iter().all(|v|v.is_finite()) {
                match input.family {
                    Family::GroupedBinomialLogit=>{let ci=[logistic_pair(interval[0]).0,logistic_pair(interval[1]).0];p.pointwise_probability_interval=Some(ci);
                        p.pointwise_expected_count_interval=request.trials.map(|t|[t as f64*ci[0],t as f64*ci[1]]);}
                    Family::PoissonLog=>{
                        p.pointwise_rate_interval=match(exp_positive(interval[0]),exp_positive(interval[1])){(Some(a),Some(b))=>Some([a,b]),_=>None};
                        let offset=request.exposure.unwrap().ln();
                        p.pointwise_expected_count_interval=match(exp_positive(interval[0]+offset),exp_positive(interval[1]+offset)){(Some(a),Some(b))=>Some([a,b]),_=>None};
                        if p.pointwise_rate_interval.is_none() || p.pointwise_expected_count_interval.is_none(){p.unavailable_reasons.push("prediction_interval_exponent_outside_floating_point_range".into());}
                    }
                }
            }else{p.unavailable_reasons.push("prediction_interval_link_overflow".into());}
        }else if input.uncertainty==Uncertainty::ModelBasedWald{p.unavailable_reasons.push("model_based_uncertainty_unavailable".into());}
        predictions.push(p);
    }
    Ok(predictions)
}

/// Fit the requested ordinary GLM. No loss/precision weights, ridge, Firth,
/// fallback family, count transform or hidden pseudocount estimator is used.
pub fn fit(input:&GlmInput,limits:&Limits,control:&dyn WorkControl)->Result<GlmResult> {
    let mut budget=Budget::new(limits,control);budget.pay(1)?;
    let data=admit(input,limits)?;
    let design=decompose(&data.scaled,input.rank_relative,limits,&mut budget)?;
    let mut theta=vec![0.0;data.p];
    if input.intercept {
        theta[0]=match input.family {
            Family::GroupedBinomialLogit=>{
                let s:f64=input.successes.as_ref().unwrap().iter().map(|s|*s as f64).sum();
                let f:f64=input.trials.as_ref().unwrap().iter().zip(input.successes.as_ref().unwrap()).map(|(t,s)|(t-s)as f64).sum();
                // Half counts are only a finite initial iterate; they are never
                // added to the likelihood, its score, or the reported estimator.
                ((s+0.5)/(f+0.5)).ln()
            }
            Family::PoissonLog=>{
                let y:f64=input.counts.as_ref().unwrap().iter().map(|y|*y as f64).sum();
                let max_offset=data.offsets.iter().copied().fold(f64::NEG_INFINITY,f64::max);
                let log_exposure=max_offset+data.offsets.iter().map(|v|(v-max_offset).exp()).sum::<f64>().ln();
                y.max(0.5).ln()-log_exposure
            }
        };
    }
    let mut evaluation=evaluate(input,&data,&theta,&mut budget)?.ok_or(Error::Numerical("initial GLM likelihood outside numerical range"))?;
    let mut final_newton=None;let mut iterations=0;let mut backtracks=0;
    let mut termination=if design.rank<data.p{"design_rank_deficient"}else if design.condition.is_some_and(|c|c>MAX_DESIGN_CONDITION){"design_ill_conditioned"}else{"iteration_limit"}.to_string();
    let design_admitted=design.rank==data.p && design.condition.is_some_and(|c|c<=MAX_DESIGN_CONDITION);
    let mut converged=false;
    if design_admitted {
        for iteration in 0..=input.solver.max_iterations {
            let Some(next)=newton(&data,&evaluation,input,limits,&mut budget)?else{termination="information_rank_or_range_failure".into();break};
            if next.score_norm<=SCORE_TOLERANCE && next.decrement<=SCORE_TOLERANCE*SCORE_TOLERANCE {
                converged=true;termination="score_and_newton_decrement_small".into();final_newton=Some(next);break;
            }
            if iteration==input.solver.max_iterations{final_newton=Some(next);break;}
            let mut accepted=None;
            for halving in 0..=input.solver.max_backtracks {
                let fraction=2f64.powi(-(halving as i32));
                let candidate:Vec<_>=theta.iter().zip(&next.step).map(|(b,d)|b+fraction*d).collect();
                if candidate.iter().any(|v|!v.is_finite()){backtracks+=1;continue;}
                if let Some(e)=evaluate(input,&data,&candidate,&mut budget)? {
                    // Armijo ascent when resolvable; at rounding scale allow no
                    // observed decrease, but never declare convergence from it.
                    let target=evaluation.ll+1e-4*fraction*next.decrement;
                    if e.ll>=target || (target==evaluation.ll && e.ll>=evaluation.ll) {accepted=Some((candidate,e));break;}
                }
                backtracks+=1;
            }
            let Some((candidate,e))=accepted else{termination="line_search_no_ascent".into();final_newton=Some(next);break};
            theta=candidate;evaluation=e;iterations+=1;
        }
    }
    let beta:Vec<_>=theta.iter().zip(&data.scales).map(|(b,s)|b/s).collect();
    if beta.iter().any(|b|!b.is_finite()){return Err(Error::Numerical("GLM coefficient restoration overflow"));}
    let c=cone(input,&data,&mut budget)?;
    let finite=if design_admitted{finite_witness(input,&data,&evaluation,&c,&mut budget)?}else{None};
    let separation=if finite.is_none() && design_admitted{separation_witness(input,&data,&beta,&c,&mut budget)?}else{None};
    let status=if design.rank<data.p{Status::RankDeficient}
        else if !design_admitted{Status::DesignIllConditioned}
        else if separation.is_some(){Status::SeparationCertified}
        else if finite.is_none(){Status::NoFiniteMleEstablished}
        else if !converged{Status::NotConverged}
        else{Status::FiniteMleConverged};
    let accepted=status==Status::FiniteMleConverged;
    let inf=if accepted{inference(input,&data,&beta,final_newton.as_ref().unwrap(),&mut budget)?}else{None};
    let mut inference_reasons=vec![];
    if !accepted{inference_reasons.push("no_converged_certified_finite_mle".into());}
    else if input.uncertainty==Uncertainty::None{inference_reasons.push("uncertainty_not_requested".into());}
    else if inf.is_none(){inference_reasons.push("information_ill_conditioned_or_inference_outside_numerical_range".into());}
    let predictions=predict(input,&data,&beta,final_newton.as_ref(),inf.as_ref(),accepted,&mut budget)?;
    let factors=if accepted{Some(inverse_factors(&data,final_newton.as_ref().unwrap(),&mut budget)?)}else{None};
    let mut observations=vec![];let mut pearson_terms=vec![];let mut all_pearson=true;
    for i in 0..data.n {
        budget.pay(if factors.is_some(){data.p*data.p+data.p}else{data.p})?;
        let pearson=if evaluation.weights[i]>0.0 {let p=evaluation.residual[i]/evaluation.weights[i].sqrt();if p.is_finite(){Some(p)}else{None}}else{None};
        if let Some(p)=pearson{let term=p*p;if term.is_finite(){pearson_terms.push(term);}else{all_pearson=false;}}else{all_pearson=false;}
        let leverage=if let Some(f)=&factors {
            let projected:Vec<_>=(0..data.p).map(|k|crate::sum((0..data.p).map(|j|data.x[i][j]*f[j][k]))).collect::<Result<_>>()?;
            let length=crate::norm(projected.into_iter())?;let h=evaluation.weights[i]*length*length;
            if h.is_finite(){Some(h)}else{None}
        }else{None};
        let rate=if input.family==Family::PoissonLog{exp_positive(evaluation.eta[i]-data.offsets[i])}else{None};
        observations.push(GlmObservation{linear_predictor:evaluation.eta[i],fitted_mean_count:evaluation.mu[i],fitted_probability:evaluation.probability[i],
            rate_per_exposure_unit:rate,response_residual:evaluation.residual[i],pearson_residual:pearson,deviance_contribution:evaluation.deviance[i],leverage});
    }
    let pearson=if all_pearson{Some(crate::sum(pearson_terms.into_iter())?)}else{None};
    let mut warnings=vec!["Ordinary maximum likelihood only; no Firth, ridge, robust dispersion or cluster correction. A finite existence certificate does not certify numerical optimality or sampling assumptions.".into(),
        "Intervals are pointwise asymptotic conditional-mean intervals, not intervals for an individual future count. P-values may underflow; zero is not an exact probability statement.".into(),
        "Predictor columns are scaled by their maximum absolute supplied value for numerical solving; returned coefficients and covariance use original units. Numerical rank remains a coordinate/tolerance policy distinct from exact witness rank.".into()];
    if input.family==Family::PoissonLog{warnings.push("Exposure must be supplied, positive and on one declared scale. Extra-Poisson variation, zero inflation and repeated observations invalidate the simple model unless separately justified.".into());}
    if evaluation.mu.iter().any(|mu|*mu==0.0) || evaluation.probability.iter().flatten().any(|p|*p==0.0 || *p==1.0){
        warnings.push("At least one fitted mean/probability reached a floating-point boundary. Log-likelihood uses stable links; displayed zeros/ones are not mathematical boundary probabilities.".into());
    }
    if !accepted{warnings.push("The candidate and fitted-row diagnostics are the last iterate only; predictions and inferential claims are withheld.".into());}
    let mut names=vec![];if input.intercept{names.push("intercept".into());}names.extend(input.model.predictor_names.clone());
    budget.pay(data.n*data.p+input.predictions.len()*data.p+data.n)?;
    let mut result=GlmResult{schema:SCHEMA.into(),operation:OPERATION.into(),
        assurance:"Untrusted floating-point IRLS and independent bounded exact rational cone replay; no Isabelle theorem. Caller-supplied assumptions, grouping, exposure and units are not established facts.".into(),
        status,supplied:input.clone(),parameter_names:names,coefficient_candidate:beta,
        candidate_interpretation:if accepted{"Approximate ordinary MLE: score/decrement convergence plus exact finite-existence/full-rank witness. Numerical optimality and statistical assumptions are not proved."}
            else{"Last numerical iterate only; not an accepted finite MLE. No prediction or inference authority."}.into(),
        finite_mle_certificate:finite,separation_certificate:separation,
        diagnostics:GlmDiagnostics{observations:data.n,parameters:data.p,numerical_design_rank:design.rank,design_condition_2_scaled:design.condition,
            information_condition_2_scaled:final_newton.as_ref().and_then(|n|n.decomposition.condition.map(|c|c*c)).filter(|v|v.is_finite()),
            column_scales:data.scales.clone(),iterations,backtracks,score_scaled_infinity_norm:final_newton.as_ref().map(|n|n.score_norm),
            newton_decrement_squared:final_newton.as_ref().map(|n|n.decrement),log_likelihood_kernel:evaluation.ll,
            deviance:crate::sum(evaluation.deviance.into_iter())?,pearson_chi_square:pearson,residual_degrees_of_freedom:data.n-design.rank,
            work_units:budget.used,exact_work_units:budget.exact,svd_scratch_peak_bytes:budget.scratch,termination},
        observations,predictions,inference:inf,inference_unavailable_reasons:inference_reasons,warnings};
    budget.pay(1)?;
    result.diagnostics.work_units=budget.used;
    Ok(result)
}

pub fn catalog_entry()->serde_json::Value {
    serde_json::json!({"id":OPERATION,"families":["grouped_binomial_logit","poisson_log"],"method":"maximum_likelihood",
        "limits":{"observations":MAX_GLM_ROWS,"parameters":MAX_GLM_PARAMETERS,"iterations":MAX_GLM_ITERATIONS,
        "backtracks":MAX_GLM_BACKTRACKS,"count_per_row":MAX_COUNT_PER_ROW,"exact_bits":MAX_EXACT_BITS,"exact_work":MAX_EXACT_WORK,
        "total_work":"minimum of parent Limits.work and MAX_WORK; includes all SVDs and exact witness arithmetic","exposure_log_abs":500},
        "assurance":"numerical score/decrement convergence AND exact rational finite-existence/full-rank witness; neither model truth nor numerical optimality theorem",
        "not_supported":["Firth or regularization","precision/loss weights","dependent rows or cluster robust inference","individual count prediction intervals","causal inference"],
        "finite_existence":"exact positive cone balance + independent row basis; lack of witness is inconclusive",
        "separation":"exact strictly improving likelihood recession direction; no finite ordinary MLE",
        "inference":"model-based inverse Fisher information and normal pointwise Wald intervals, conditional on independent binomial/Poisson assumptions and asymptotic regularity"})
}
