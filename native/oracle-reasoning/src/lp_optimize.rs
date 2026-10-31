//! Bounded two-phase exact rational simplex, separate from feasibility-only search.
//!
//! Original variables are unrestricted and original rows mean A*x <= b. Splitting
//! x=x_plus-x_minus and signed slack/artificial rows is proposal machinery only.
//! Every claimed outcome is replayed against the original rows by exact_lp.
//! No Isabelle theorem, model completeness or integer optimization is claimed.
use crate::exact_lp::{self, Certificate, Output, Problem};
use crate::{Error, Result};
use num_rational::BigRational as Q;
use num_traits::{One, Signed, Zero};
use serde::Serialize;
use std::collections::BTreeSet;

#[derive(Clone, Debug, Serialize)]
pub struct Limits {
    pub variables: usize,
    pub rows: usize,
    pub tableau_cells: usize,
    pub bits: u64,
    pub work: usize,
    pub pivots: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self { variables: 32, rows: 256, tableau_cells: 262_144,
            bits: 4096, work: 8_000_000, pivots: 2048 }
    }
}
struct Budget<'a> {
    limits: &'a Limits,
    used: usize,
    pivots: usize,
    control: &'a dyn oracle_execution::WorkControl,
}
impl Budget<'_> {
    fn q(&mut self, q: &Q) -> Result<()> {
        crate::checkpoint(self.control, 1)?;
        self.used = self.used.saturating_add(1);
        if self.used > self.limits.work || q.numer().bits() > self.limits.bits
            || q.denom().bits() > self.limits.bits {
            return Err(Error::Limit("linear optimization arithmetic"));
        }
        Ok(())
    }
    fn parse(&mut self, s: &str) -> Result<Q> {
        if s.len() > (self.limits.bits as usize).saturating_mul(2).saturating_add(3) {
            return Err(Error::Limit("linear optimization rational text"));
        }
        let q = s.parse::<Q>().map_err(|_| Error::Invalid("exact rational required".into()))?;
        self.q(&q)?;
        Ok(q)
    }
    fn mul(&mut self, x: &Q, y: &Q) -> Result<Q> {
        let q = x * y;
        self.q(&q)?;
        Ok(q)
    }
    fn sub(&mut self, x: &Q, y: &Q) -> Result<Q> {
        let q = x - y;
        self.q(&q)?;
        Ok(q)
    }
    fn div(&mut self, x: &Q, y: &Q) -> Result<Q> {
        if y.is_zero() { return Err(Error::Check("zero simplex pivot")); }
        let q = x / y;
        self.q(&q)?;
        Ok(q)
    }
}
struct Data { a: Vec<Vec<Q>>, b: Vec<Q>, c: Vec<Q> }
fn admit(p: &Problem, b: &mut Budget<'_>) -> Result<Data> {
    let n = p.variables.len();
    if n == 0 || n > b.limits.variables || p.rows.len() > b.limits.rows {
        return Err(Error::Invalid("linear optimization dimensions outside limits".into()));
    }
    for ids in [p.variables.iter().map(String::as_str).collect::<Vec<_>>(),
        p.rows.iter().map(|r| r.id.as_str()).collect()] {
        let mut seen = BTreeSet::new();
        for id in ids {
            if id.trim().is_empty() || id.len() > 128 || !seen.insert(id) {
                return Err(Error::Invalid("unique bounded linear IDs required".into()));
            }
        }
    }
    let objective = p.objective.as_ref().ok_or_else(|| Error::Invalid("minimization objective required".into()))?;
    if objective.len() != n || p.rows.iter().any(|r| r.coefficients.len() != n) {
        return Err(Error::Invalid("linear optimization vector length".into()));
    }
    let c = objective.iter().map(|s| b.parse(s)).collect::<Result<Vec<_>>>()?;
    let mut a = Vec::new(); let mut rhs = Vec::new();
    for row in &p.rows {
        a.push(row.coefficients.iter().map(|s| b.parse(s)).collect::<Result<Vec<_>>>()?);
        rhs.push(b.parse(&row.bound)?);
    }
    Ok(Data { a, b: rhs, c })
}
// Full equality tableau T*z=rhs with canonical unit basis columns. The original
// normalized rows are sign_i*(A_i*x+s_i)=sign_i*b_i. `transform` retains their
// coefficients, including after redundant artificial rows are removed.
struct Tableau {
    t: Vec<Vec<Q>>,
    rhs: Vec<Q>,
    basis: Vec<usize>,
    transform: Vec<Vec<Q>>,
    signs: Vec<Q>,
    original_variables: usize,
    non_artificial: usize,
    columns: usize,
}
impl Tableau {
    fn new(d: &Data, budget: &mut Budget<'_>) -> Result<Self> {
        let n = d.c.len(); let m = d.b.len();
        let artificial = d.b.iter().filter(|v| v.is_negative()).count();
        let columns = 2*n + m + artificial;
        if m.saturating_mul(columns.saturating_add(m).saturating_add(1)) > budget.limits.tableau_cells {
            return Err(Error::Limit("linear optimization tableau cells"));
        }
        let mut t = vec![vec![Q::zero(); columns]; m];
        let mut rhs = Vec::new(); let mut basis = Vec::new(); let mut signs = Vec::new();
        let mut transform = vec![vec![Q::zero(); m]; m];
        let mut next_art = 2*n + m;
        for i in 0..m {
            let sign = if d.b[i].is_negative() { -Q::one() } else { Q::one() };
            rhs.push(budget.mul(&sign, &d.b[i])?);
            for j in 0..n {
                t[i][j] = budget.mul(&sign, &d.a[i][j])?;
                t[i][j+n] = -t[i][j].clone();
            }
            t[i][2*n+i] = sign.clone();
            if sign.is_negative() {
                t[i][next_art] = Q::one();
                basis.push(next_art); next_art += 1;
            } else { basis.push(2*n+i); }
            transform[i][i] = Q::one(); signs.push(sign);
        }
        Ok(Self { t, rhs, basis, transform, signs, original_variables:n,
            non_artificial:2*n+m, columns })
    }
    fn pivot(&mut self, row: usize, col: usize, b: &mut Budget<'_>) -> Result<()> {
        if b.pivots >= b.limits.pivots { return Err(Error::Limit("linear optimization pivots")); }
        b.pivots += 1;
        let pivot = self.t[row][col].clone();
        for j in 0..self.columns { self.t[row][j] = b.div(&self.t[row][j], &pivot)?; }
        self.rhs[row] = b.div(&self.rhs[row], &pivot)?;
        for j in 0..self.signs.len() { self.transform[row][j] = b.div(&self.transform[row][j], &pivot)?; }
        let pr = self.t[row].clone(); let pe = self.transform[row].clone(); let pb = self.rhs[row].clone();
        for i in 0..self.t.len() {
            if i == row || self.t[i][col].is_zero() { continue; }
            let factor = self.t[i][col].clone();
            for (j, v) in pr.iter().enumerate() {
                let term = b.mul(&factor, v)?;
                self.t[i][j] = b.sub(&self.t[i][j], &term)?;
            }
            let term = b.mul(&factor, &pb)?;
            self.rhs[i] = b.sub(&self.rhs[i], &term)?;
            for (j, v) in pe.iter().enumerate() {
                let term = b.mul(&factor, v)?;
                self.transform[i][j] = b.sub(&self.transform[i][j], &term)?;
            }
        }
        self.basis[row] = col;
        Ok(())
    }
    fn reduced(&self, costs: &[Q], col: usize, b: &mut Budget<'_>) -> Result<Q> {
        let mut value = costs[col].clone();
        for i in 0..self.t.len() {
            let term = b.mul(&costs[self.basis[i]], &self.t[i][col])?;
            value = b.sub(&value, &term)?;
        }
        Ok(value)
    }
    /// Bland's rule: smallest negative reduced-cost entering column; minimum
    /// ratio leaving row, ties broken by smallest basis variable index.
    fn simplex(&mut self, costs: &[Q], entering_columns: usize, b: &mut Budget<'_>) -> Result<Option<usize>> {
        loop {
            let mut entering = None;
            for j in 0..entering_columns {
                if !self.basis.contains(&j) && self.reduced(costs, j, b)?.is_negative() { entering = Some(j); break; }
            }
            let Some(col) = entering else { return Ok(None); };
            let mut leaving: Option<(usize,Q)> = None;
            for i in 0..self.t.len() {
                if !self.t[i][col].is_positive() { continue; }
                let ratio = b.div(&self.rhs[i], &self.t[i][col])?;
                if leaving.as_ref().is_none_or(|(r, best)| ratio < *best || (ratio == *best && self.basis[i] < self.basis[*r])) {
                    leaving = Some((i,ratio));
                }
            }
            let Some((row,_)) = leaving else { return Ok(Some(col)); };
            self.pivot(row, col, b)?;
        }
    }
    fn multipliers(&self, costs: &[Q], b: &mut Budget<'_>) -> Result<Vec<String>> {
        let mut result = Vec::new();
        for j in 0..self.signs.len() {
            let mut y = Q::zero();
            for i in 0..self.t.len() {
                let term = b.mul(&costs[self.basis[i]], &self.transform[i][j])?;
                y = b.sub(&y, &(-term))?;
            }
            let lambda = b.mul(&(-self.signs[j].clone()), &y)?;
            result.push(lambda.to_string());
        }
        Ok(result)
    }
    fn point(&self) -> Vec<String> {
        let mut z = vec![Q::zero(); self.columns];
        for (i, &col) in self.basis.iter().enumerate() { z[col] = self.rhs[i].clone(); }
        (0..self.original_variables).map(|j| (&z[j]-&z[j+self.original_variables]).to_string()).collect()
    }
    fn direction(&self, entering: usize, b: &mut Budget<'_>) -> Result<Vec<String>> {
        let mut z = vec![Q::zero(); self.columns]; z[entering] = Q::one();
        for (i, &col) in self.basis.iter().enumerate() { z[col] = -self.t[i][entering].clone(); }
        (0..self.original_variables).map(|j| b.sub(&z[j], &z[j+self.original_variables]).map(|v|v.to_string())).collect()
    }
    fn remove_artificials(&mut self, b: &mut Budget<'_>) -> Result<()> {
        let mut i = 0;
        while i < self.t.len() {
            if self.basis[i] < self.non_artificial { i += 1; continue; }
            if !self.rhs[i].is_zero() { return Err(Error::Check("nonzero artificial after phase one")); }
            if let Some(col) = (0..self.non_artificial).find(|j| !self.basis.contains(j) && !self.t[i][*j].is_zero()) {
                self.pivot(i,col,b)?; i += 1;
            } else {
                self.t.remove(i); self.rhs.remove(i); self.basis.remove(i); self.transform.remove(i);
            }
        }
        Ok(())
    }
}
fn propose(p: &Problem, b: &mut Budget<'_>) -> Result<Certificate> {
    let d = admit(p,b)?;
    let mut t = Tableau::new(&d,b)?;
    let phase_one: Vec<Q> = (0..t.columns).map(|j| if j >= t.non_artificial { Q::one() } else { Q::zero() }).collect();
    if t.simplex(&phase_one, t.columns, b)?.is_some() { return Err(Error::Check("phase one unexpectedly unbounded")); }
    let mut artificial_value = Q::zero();
    for i in 0..t.t.len() {
        let term = b.mul(&phase_one[t.basis[i]],&t.rhs[i])?;
        artificial_value = b.sub(&artificial_value,&(-term))?;
    }
    if artificial_value.is_positive() { return Ok(Certificate::Infeasible { multipliers:t.multipliers(&phase_one,b)? }); }
    if artificial_value.is_negative() { return Err(Error::Check("negative artificial objective")); }
    t.remove_artificials(b)?;
    let n = d.c.len();
    let mut costs = vec![Q::zero();t.columns];
    for j in 0..n { costs[j]=d.c[j].clone(); costs[j+n]=-d.c[j].clone(); }
    let unbounded = t.simplex(&costs,t.non_artificial,b)?;
    let point = t.point();
    if let Some(entering) = unbounded { return Ok(Certificate::Unbounded {point,direction:t.direction(entering,b)?}); }
    Ok(Certificate::Optimal {point,multipliers:t.multipliers(&costs,b)?})
}
/// Minimize the supplied objective. Search and independent original-row replay
/// share the local arithmetic cap and the host's cooperative WorkControl.
pub fn optimize_controlled(p: &Problem, limits: &Limits, control: &dyn oracle_execution::WorkControl) -> Result<Output> {
    let mut b = Budget { limits, used:0, pivots:0, control };
    let result = propose(p,&mut b).and_then(|certificate| {
        let checker_limits = exact_lp::Limits {variables:limits.variables, rows:limits.rows,
            generated_rows:0, bits:limits.bits, work:limits.work.saturating_sub(b.used)};
        let status = exact_lp::check_certificate_controlled(p,&certificate,&checker_limits,control)?;
        Ok((status,certificate))
    });
    match result {
        Ok((status, certificate)) => Ok(Output {status, certificate:Some(certificate), reason:None,
            assurance:"exact rational primal/dual or ray replay over original supplied rows; no Isabelle or model completeness claim"}),
        Err(Error::Limit(reason)) => Ok(Output {status:"unknown", certificate:None, reason:Some(reason.into()),
            assurance:"resource exhaustion establishes no optimization conclusion"}),
        Err(e) => Err(e),
    }
}
pub fn optimize(p: &Problem, limits: &Limits) -> Result<Output> {
    optimize_controlled(p,limits,&std::sync::atomic::AtomicBool::new(false))
}
