//! Bounded exact rational linear certificates. All original rows mean a*x <= b;
//! variables are unrestricted. This Rust checker has no Isabelle assurance.
use crate::{Error, Result};
use num_rational::BigRational as Q;
use num_traits::{One, Signed, Zero};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Row {
    pub id: String,
    pub coefficients: Vec<String>,
    pub bound: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Problem {
    pub variables: Vec<String>,
    pub rows: Vec<Row>,
    pub objective: Option<Vec<String>>,
}
#[derive(Clone, Debug, Serialize)]
pub struct Limits {
    pub variables: usize,
    pub rows: usize,
    pub generated_rows: usize,
    pub bits: u64,
    pub work: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            variables: 32,
            rows: 256,
            generated_rows: 4096,
            bits: 4096,
            work: 1_000_000,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Certificate {
    Feasible {
        point: Vec<String>,
    },
    Infeasible {
        multipliers: Vec<String>,
    },
    /// For minimization, multipliers >= 0 and A^T multipliers = -c.
    Optimal {
        point: Vec<String>,
        multipliers: Vec<String>,
    },
    Unbounded {
        point: Vec<String>,
        direction: Vec<String>,
    },
}
#[derive(Clone, Debug, Serialize)]
pub struct Output {
    pub status: &'static str,
    pub certificate: Option<Certificate>,
    pub reason: Option<String>,
    pub assurance: &'static str,
}
struct Budget<'a> {
    limits: &'a Limits,
    used: usize,
    control: &'a dyn oracle_execution::WorkControl,
}
impl Budget<'_> {
    fn q(&mut self, q: &Q) -> Result<()> {
        crate::checkpoint(self.control, 1)?;
        self.used += 1;
        if self.used > self.limits.work
            || q.numer().bits() > self.limits.bits
            || q.denom().bits() > self.limits.bits
        {
            Err(Error::Limit("exact linear arithmetic"))
        } else {
            Ok(())
        }
    }
    fn parse(&mut self, s: &str) -> Result<Q> {
        if s.len() > 2 * (self.limits.bits as usize) + 3 {
            return Err(Error::Limit("exact linear text"));
        }
        let q = s
            .parse::<Q>()
            .map_err(|_| Error::Invalid("exact rational required".into()))?;
        self.q(&q)?;
        Ok(q)
    }
    fn vector(&mut self, s: &[String], n: usize) -> Result<Vec<Q>> {
        if s.len() != n {
            return Err(Error::Invalid("linear vector length".into()));
        }
        s.iter().map(|s| self.parse(s)).collect()
    }
    fn dot(&mut self, a: &[Q], x: &[Q]) -> Result<Q> {
        let mut v = Q::zero();
        for (a, x) in a.iter().zip(x) {
            let t = a * x;
            self.q(&t)?;
            v += t;
            self.q(&v)?;
        }
        Ok(v)
    }
}
struct Data {
    a: Vec<Vec<Q>>,
    b: Vec<Q>,
    c: Option<Vec<Q>>,
}
fn admit(p: &Problem, budget: &mut Budget<'_>) -> Result<Data> {
    if p.variables.is_empty()
        || p.variables.len() > budget.limits.variables
        || p.rows.len() > budget.limits.rows
    {
        return Err(Error::Invalid("linear dimensions outside limits".into()));
    }
    for ids in [
        p.variables.iter().map(|s| s.as_str()).collect::<Vec<_>>(),
        p.rows.iter().map(|r| r.id.as_str()).collect(),
    ] {
        let mut seen = std::collections::BTreeSet::new();
        for id in ids {
            if id.trim().is_empty() || id.len() > 128 || !seen.insert(id) {
                return Err(Error::Invalid(
                    "linear IDs must be unique nonempty labels".into(),
                ));
            }
        }
    }
    let mut a = Vec::new();
    let mut b = Vec::new();
    for r in &p.rows {
        a.push(budget.vector(&r.coefficients, p.variables.len())?);
        b.push(budget.parse(&r.bound)?);
    }
    let c = p
        .objective
        .as_ref()
        .map(|v| budget.vector(v, p.variables.len()))
        .transpose()?;
    Ok(Data { a, b, c })
}
fn feasible(d: &Data, x: &[Q], b: &mut Budget<'_>) -> Result<()> {
    for (row, rhs) in d.a.iter().zip(&d.b) {
        if b.dot(row, x)? > *rhs {
            return Err(Error::Check("linear supplied row violated"));
        }
    }
    Ok(())
}
fn replay(p: &Problem, d: &Data, cert: &Certificate, b: &mut Budget<'_>) -> Result<&'static str> {
    let n = p.variables.len();
    let m = p.rows.len();
    match cert {
        Certificate::Feasible { point } => {
            let x = b.vector(point, n)?;
            feasible(d, &x, b)?;
            Ok("feasible")
        }
        Certificate::Infeasible { multipliers } | Certificate::Optimal { multipliers, .. } => {
            let y = b.vector(multipliers, m)?;
            if y.iter().any(Q::is_negative) {
                return Err(Error::Check("negative linear multiplier"));
            }
            let mut sum = vec![Q::zero(); n];
            for (row, y) in d.a.iter().zip(&y) {
                for (v, a) in sum.iter_mut().zip(row) {
                    let t = a * y;
                    b.q(&t)?;
                    *v += t;
                    b.q(v)?;
                }
            }
            let bound = b.dot(&d.b, &y)?;
            if let Certificate::Optimal { point, .. } = cert {
                let c =
                    d.c.as_ref()
                        .ok_or_else(|| Error::Invalid("objective required".into()))?;
                let x = b.vector(point, n)?;
                feasible(d, &x, b)?;
                if sum.iter().zip(c).any(|(a, c)| a != &(-c)) || b.dot(c, &x)? != -bound {
                    return Err(Error::Check("linear optimality witness"));
                }
                Ok("optimal")
            } else {
                if sum.iter().any(|v| !v.is_zero()) || !bound.is_negative() {
                    return Err(Error::Check("linear Farkas witness"));
                }
                Ok("infeasible")
            }
        }
        Certificate::Unbounded { point, direction } => {
            let c =
                d.c.as_ref()
                    .ok_or_else(|| Error::Invalid("objective required".into()))?;
            let x = b.vector(point, n)?;
            let ray = b.vector(direction, n)?;
            feasible(d, &x, b)?;
            for row in &d.a {
                if b.dot(row, &ray)?.is_positive() {
                    return Err(Error::Check("linear recession direction"));
                }
            }
            if !b.dot(c, &ray)?.is_negative() {
                return Err(Error::Check("linear objective direction"));
            }
            Ok("unbounded")
        }
    }
}
pub fn check_certificate_controlled(
    p: &Problem,
    c: &Certificate,
    l: &Limits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<&'static str> {
    let mut b = Budget {
        limits: l,
        used: 0,
        control,
    };
    let d = admit(p, &mut b)?;
    replay(p, &d, c, &mut b)
}
pub fn check_certificate(p: &Problem, c: &Certificate, l: &Limits) -> Result<&'static str> {
    check_certificate_controlled(p, c, l, &std::sync::atomic::AtomicBool::new(false))
}

#[derive(Clone)]
struct Inequality {
    a: Vec<Q>,
    b: Q,
    y: Vec<Q>,
}
fn propose(p: &Problem, d: &Data, b: &mut Budget<'_>) -> Result<Certificate> {
    let n = p.variables.len();
    let m = p.rows.len();
    let mut rows: Vec<_> =
        d.a.iter()
            .zip(&d.b)
            .enumerate()
            .map(|(i, (a, rhs))| {
                let mut y = vec![Q::zero(); m];
                y[i] = Q::one();
                Inequality {
                    a: a.clone(),
                    b: rhs.clone(),
                    y,
                }
            })
            .collect();
    let mut history = Vec::new();
    for col in 0..n {
        for r in &rows {
            if r.a.iter().all(Q::is_zero) && r.b.is_negative() {
                return Ok(Certificate::Infeasible {
                    multipliers: r.y.iter().map(ToString::to_string).collect(),
                });
            }
        }
        for r in &rows {
            for q in r.a.iter().chain(&r.y) {
                b.q(q)?;
            }
        }
        history.push(rows.clone());
        let pos: Vec<_> = rows.iter().filter(|r| r.a[col].is_positive()).collect();
        let neg: Vec<_> = rows.iter().filter(|r| r.a[col].is_negative()).collect();
        let zero = rows.iter().filter(|r| r.a[col].is_zero()).count();
        if pos.len().saturating_mul(neg.len()).saturating_add(zero) > b.limits.generated_rows {
            return Err(Error::Limit("exact linear generated rows"));
        }
        let mut next: Vec<_> = rows
            .iter()
            .filter(|r| r.a[col].is_zero())
            .cloned()
            .collect();
        for u in &pos {
            for v in &neg {
                let alpha = -v.a[col].clone();
                let beta = u.a[col].clone();
                let mut combine = |x: &[Q], y: &[Q]| -> Result<Vec<Q>> {
                    x.iter()
                        .zip(y)
                        .map(|(x, y)| {
                            let t = &alpha * x;
                            b.q(&t)?;
                            let s = &beta * y;
                            b.q(&s)?;
                            let q = t + s;
                            b.q(&q)?;
                            Ok(q)
                        })
                        .collect()
                };
                let a = combine(&u.a, &v.a)?;
                let y = combine(&u.y, &v.y)?;
                let rhs = &alpha * &u.b + &beta * &v.b;
                b.q(&rhs)?;
                next.push(Inequality { a, b: rhs, y });
            }
        }
        rows = next;
    }
    for r in &rows {
        if r.b.is_negative() {
            return Ok(Certificate::Infeasible {
                multipliers: r.y.iter().map(ToString::to_string).collect(),
            });
        }
    }
    let mut x = vec![Q::zero(); n];
    for col in (0..n).rev() {
        let mut lower: Option<Q> = None;
        let mut upper: Option<Q> = None;
        for r in &history[col] {
            if r.a[col].is_zero() {
                continue;
            }
            let residual = &r.b - b.dot(&r.a, &x)?;
            let bound = residual / &r.a[col];
            b.q(&bound)?;
            if r.a[col].is_positive() {
                upper = Some(upper.map_or(bound.clone(), |v| v.min(bound)));
            } else {
                lower = Some(lower.map_or(bound.clone(), |v| v.max(bound)));
            }
        }
        x[col] = match (lower, upper) {
            (Some(l), Some(u)) => {
                if l > u {
                    return Err(Error::Check("linear reconstruction"));
                }
                l
            }
            (Some(l), None) => l,
            (None, Some(u)) => u,
            (None, None) => Q::zero(),
        };
    }
    Ok(Certificate::Feasible {
        point: x.iter().map(ToString::to_string).collect(),
    })
}
pub fn solve_controlled(
    p: &Problem,
    l: &Limits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<Output> {
    let mut b = Budget {
        limits: l,
        used: 0,
        control,
    };
    let d = admit(p, &mut b)?;
    let result = propose(p, &d, &mut b).and_then(|c| {
        let status = replay(p, &d, &c, &mut b)?;
        Ok((status, c))
    });
    match result {
        Ok((status, c)) => Ok(Output {
            status,
            certificate: Some(c),
            reason: None,
            assurance:
                "exact rational replay over supplied rows; no Isabelle or model completeness claim",
        }),
        Err(Error::Limit(reason)) => Ok(Output {
            status: "unknown",
            certificate: None,
            reason: Some(reason.into()),
            assurance: "resource exhaustion establishes no feasibility conclusion",
        }),
        Err(e) => Err(e),
    }
}
pub fn solve(p: &Problem, l: &Limits) -> Result<Output> {
    solve_controlled(p, l, &std::sync::atomic::AtomicBool::new(false))
}
