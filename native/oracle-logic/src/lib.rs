//! Finite grounded normal programs. Handwritten Rust, not Isabelle verified.
//! Clingo proposes models; a separate GL reduct checker validates each witness.
//! Completeness and inconsistency remain solver-trusted claims.
#![forbid(unsafe_code)]
pub mod process;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Scope {
    pub tenant: String,
    pub snapshot: String,
    /// Required assertion: this is the entire program for this local scope.
    pub complete_program: bool,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Rule {
    /// None means an integrity constraint; empty bodies with a head are facts.
    pub head: Option<usize>,
    pub positive: Vec<usize>,
    pub negative: Vec<usize>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    #[serde(default)]
    pub operation: Operation,
    pub scope: Scope,
    /// Opaque atom names, never parsed as ASP syntax. Index in this array is ID.
    pub atoms: Vec<String>,
    pub rules: Vec<Rule>,
    pub queries: Vec<usize>,
}
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Operation {
    #[default]
    Query,
    Enumerate,
}
#[derive(Clone, Debug)]
pub struct Limits {
    pub request_bytes: usize,
    pub atoms: usize,
    pub rules: usize,
    pub literals: usize,
    pub models: usize,
    pub output_bytes: usize,
    pub milliseconds: u64,
    pub checker_work: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            request_bytes: 256 * 1024,
            atoms: 1024,
            rules: 4096,
            literals: 32768,
            models: 256,
            output_bytes: 2 * 1024 * 1024,
            milliseconds: 250,
            checker_work: 5_000_000,
        }
    }
}
#[derive(Debug, PartialEq, Eq)]
pub enum Error {
    Invalid(&'static str),
    Limit(&'static str),
    Cancelled,
    Witness(&'static str),
    Backend(&'static str),
}
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}
impl std::error::Error for Error {}

/// Request-wide budget shared across every witness check (not reset per model).
pub struct Budget<'a> {
    left: usize,
    output_left: usize,
    start: Instant,
    ms: u64,
    cancel: &'a AtomicBool,
    limits: &'a Limits,
}
impl<'a> Budget<'a> {
    pub fn new(l: &'a Limits, cancel: &'a AtomicBool) -> Self {
        Self {
            left: l.checker_work,
            output_left: l.output_bytes,
            start: Instant::now(),
            ms: l.milliseconds,
            cancel,
            limits: l,
        }
    }
    pub fn tick(&mut self) -> Result<(), Error> {
        if self.cancel.load(Ordering::Relaxed) {
            return Err(Error::Cancelled);
        }
        if self.start.elapsed() >= Duration::from_millis(self.ms) {
            return Err(Error::Limit("deadline"));
        }
        self.left = self
            .left
            .checked_sub(1)
            .ok_or(Error::Limit("checker work"))?;
        Ok(())
    }
    pub fn charge_output(&mut self, bytes: usize) -> Result<(), Error> {
        self.output_left = self
            .output_left
            .checked_sub(bytes)
            .ok_or(Error::Limit("aggregate solver output"))?;
        self.tick()
    }
}

pub fn parse(input: &str, limits: &Limits) -> Result<Request, Error> {
    if input.len() > limits.request_bytes {
        return Err(Error::Limit("request bytes"));
    }
    let p: Request = serde_json::from_str(input).map_err(|_| Error::Invalid("request JSON"))?;
    validate(&p, limits)?;
    Ok(p)
}
pub fn validate(p: &Request, l: &Limits) -> Result<(), Error> {
    if !p.scope.complete_program || p.scope.tenant.is_empty() || p.scope.snapshot.is_empty() {
        return Err(Error::Invalid(
            "explicit complete tenant/snapshot scope required",
        ));
    }
    if p.atoms.len() > l.atoms || p.rules.len() > l.rules || p.queries.len() > l.atoms {
        return Err(Error::Limit("program size"));
    }
    if p.atoms.iter().any(|a| a.is_empty())
        || p.atoms.iter().collect::<BTreeSet<_>>().len() != p.atoms.len()
    {
        return Err(Error::Invalid("empty or duplicate atom label"));
    }
    let mut count = 0usize;
    for r in &p.rules {
        count = count
            .checked_add(r.positive.len())
            .and_then(|n| n.checked_add(r.negative.len()))
            .ok_or(Error::Limit("literals"))?;
        if count > l.literals {
            return Err(Error::Limit("literals"));
        }
        if r.head
            .iter()
            .chain(&r.positive)
            .chain(&r.negative)
            .any(|&a| a >= p.atoms.len())
        {
            return Err(Error::Invalid("atom ID outside closed universe"));
        }
    }
    if p.queries.iter().any(|&a| a >= p.atoms.len()) {
        return Err(Error::Invalid("query outside closed universe"));
    }
    Ok(())
}

/// GL reduct: discard rules whose negative body meets M, erase remaining
/// negative literals, derive the least Horn fixpoint, require exactly M and
/// require every surviving integrity constraint to have false positive body.
pub fn check_model(p: &Request, model: &[usize], b: &mut Budget<'_>) -> Result<(), Error> {
    validate(p, b.limits)?;
    for r in &p.rules {
        b.tick()?;
        for &a in r.head.iter().chain(&r.positive).chain(&r.negative) {
            b.tick()?;
            if a >= p.atoms.len() {
                return Err(Error::Invalid("atom ID outside closed universe"));
            }
        }
    }
    let mut m = vec![false; p.atoms.len()];
    for &a in model {
        b.tick()?;
        if a >= m.len() || m[a] {
            return Err(Error::Witness("duplicate or out-of-scope atom"));
        }
        m[a] = true;
    }
    let mut reduct = Vec::new();
    for r in &p.rules {
        b.tick()?;
        let mut removed = false;
        for &a in &r.negative {
            b.tick()?;
            removed |= m[a];
        }
        if !removed {
            reduct.push(r);
        }
    }
    let mut least = vec![false; p.atoms.len()];
    loop {
        let mut changed = false;
        for r in &reduct {
            b.tick()?;
            let mut body = true;
            for &a in &r.positive {
                b.tick()?;
                body &= least[a];
            }
            if body {
                if let Some(h) = r.head {
                    if !least[h] {
                        least[h] = true;
                        changed = true;
                    }
                }
            }
        }
        if !changed {
            break;
        }
    }
    for r in reduct {
        b.tick()?;
        if r.head.is_none() {
            let mut body = true;
            for &a in &r.positive {
                b.tick()?;
                body &= least[a];
            }
            if body {
                return Err(Error::Witness("integrity constraint violated"));
            }
        }
    }
    if least != m {
        return Err(Error::Witness("candidate differs from reduct least model"));
    }
    Ok(())
}

/// Construct ASP solely from numeric IDs; caller-provided labels cannot inject
/// directives, includes, variables, Python/Lua scripts or new atoms.
pub fn encode(p: &Request) -> String {
    let mut s = String::new();
    for r in &p.rules {
        if let Some(h) = r.head {
            s.push_str(&format!("a{h}"));
        }
        if r.head.is_none() || !r.positive.is_empty() || !r.negative.is_empty() {
            s.push_str(":-");
            let terms: Vec<_> = r
                .positive
                .iter()
                .map(|a| format!("a{a}"))
                .chain(r.negative.iter().map(|a| format!("not a{a}")))
                .collect();
            s.push_str(&terms.join(","));
        }
        s.push_str(".\n");
    }
    s
}

#[derive(Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    Consistent,
    Inconsistent,
    Inconclusive,
}
#[derive(Debug, Serialize)]
pub struct Answer {
    pub atom: usize,
    /// None on inconsistency or incomplete search; never vacuous certainty.
    pub skeptical: Option<bool>,
    pub credulous: Option<bool>,
    pub true_witness: Option<usize>,
    pub false_witness: Option<usize>,
}
#[derive(Debug, Serialize)]
pub struct Reply {
    pub scope: Scope,
    pub status: Status,
    pub reason: String,
    pub enumeration_complete: bool,
    pub completeness_trust: &'static str,
    pub witness_check: &'static str,
    pub models: Vec<Vec<usize>>,
    pub answers: Vec<Answer>,
}
pub fn inconclusive(p: &Request, reason: &str) -> Reply {
    Reply {
        scope: p.scope.clone(),
        status: Status::Inconclusive,
        reason: reason.into(),
        enumeration_complete: false,
        completeness_trust: "none",
        witness_check: "handwritten_gl_reduct",
        models: vec![],
        answers: p
            .queries
            .iter()
            .map(|&atom| Answer {
                atom,
                skeptical: None,
                credulous: None,
                true_witness: None,
                false_witness: None,
            })
            .collect(),
    }
}

/// Validate the process status AND JSON summary before trusting any solver
/// result. clasp sets SAT=10, exhausted=20, interrupted=1 as combined flags.
/// This provider never accepts the interruption bit, UNKNOWN, or extra flags.
pub fn validate_solver_exit(bytes: &[u8], exit_code: i32) -> Result<(), Error> {
    let v: serde_json::Value =
        serde_json::from_slice(bytes).map_err(|_| Error::Backend("solver JSON"))?;
    let number = v["Models"]["Number"]
        .as_u64()
        .ok_or(Error::Backend("missing model count"))?;
    let expected = match (v["Result"].as_str(), v["Models"]["More"].as_str(), number) {
        (Some("SATISFIABLE"), Some("yes"), 1..) => 10,
        (Some("SATISFIABLE"), Some("no"), 1..) => 30,
        (Some("UNSATISFIABLE"), Some("no"), 0) => 20,
        _ => return Err(Error::Backend("unknown or conflicting solver summary")),
    };
    if exit_code != expected {
        return Err(Error::Backend(
            "solver exit/JSON conflict or interrupted search",
        ));
    }
    Ok(())
}

/// Retain independently established one-sided facts if a later probe fails.
/// A true witness proves credulous truth; a false witness refutes skepticism.
/// Neither witness alone supports the converse (UNSAT-dependent) direction.
pub fn partial_query(
    p: &Request,
    reason: &str,
    models: Vec<Vec<usize>>,
    mut completed: Vec<Answer>,
) -> Reply {
    let contradicted = completed.iter().any(|a| {
        models.iter().any(|m| {
            let present = m.binary_search(&a.atom).is_ok();
            (a.skeptical == Some(true) && !present) || (a.credulous == Some(false) && present)
        })
    });
    // Any refuted absence claim discredits all backend absence claims. This
    // check applies even on a later timeout after collecting a contradiction.
    if contradicted {
        completed.clear();
    }
    // Direct checked witnesses take precedence over earlier trusted absences
    // if a faulty solver later contradicts its own UNSAT claim.
    for answer in &mut completed {
        if let Some(i) = models
            .iter()
            .position(|m| m.binary_search(&answer.atom).is_ok())
        {
            answer.credulous = Some(true);
            answer.true_witness = Some(i);
        }
        if let Some(i) = models
            .iter()
            .position(|m| m.binary_search(&answer.atom).is_err())
        {
            answer.skeptical = Some(false);
            answer.false_witness = Some(i);
        }
    }
    for &atom in p.queries.iter().skip(completed.len()) {
        let yes = models.iter().position(|m| m.binary_search(&atom).is_ok());
        let no = models.iter().position(|m| m.binary_search(&atom).is_err());
        completed.push(Answer {
            atom,
            skeptical: no.map(|_| false),
            credulous: yes.map(|_| true),
            true_witness: yes,
            false_witness: no,
        });
    }
    Reply {
        scope: p.scope.clone(),
        status: Status::Inconclusive,
        reason: if contradicted {
            format!("backend inconsistency: checked witness refutes prior UNSAT; {reason}")
        } else {
            reason.into()
        },
        enumeration_complete: false,
        completeness_trust: if contradicted {
            "witnesses_only_backend_inconsistent"
        } else {
            "completed_query_unsat_only_otherwise_witnesses"
        },
        witness_check: "handwritten_gl_reduct",
        models,
        answers: completed,
    }
}

/// One satisfiability probe: SAT needs a full independently checked witness;
/// UNSAT needs the solver's completed absence claim. SAT need not enumerate.
pub fn decode_probe(
    p: &Request,
    bytes: &[u8],
    l: &Limits,
    b: &mut Budget<'_>,
) -> Result<Option<Vec<usize>>, Error> {
    validate(p, l)?;
    if bytes.len() > l.output_bytes {
        return Err(Error::Limit("solver output"));
    }
    let v: serde_json::Value =
        serde_json::from_slice(bytes).map_err(|_| Error::Backend("solver JSON"))?;
    let calls = v["Call"]
        .as_array()
        .ok_or(Error::Backend("missing calls"))?;
    if calls.len() != 1 {
        return Err(Error::Backend("expected one solve call"));
    }
    match v["Result"].as_str() {
        Some("UNSATISFIABLE") => {
            if v["Models"]["More"].as_str() != Some("no")
                || v["Models"]["Number"].as_u64() != Some(0)
                || calls[0]
                    .get("Witnesses")
                    .is_some_and(|w| w.as_array().is_none_or(|a| !a.is_empty()))
            {
                return Err(Error::Backend("incomplete or conflicting absence claim"));
            }
            Ok(None)
        }
        Some("SATISFIABLE") => {
            let witnesses = calls[0]["Witnesses"]
                .as_array()
                .ok_or(Error::Backend("missing witness"))?;
            if witnesses.len() != 1 || v["Models"]["Number"].as_u64() != Some(1) {
                return Err(Error::Backend("probe model count"));
            }
            let mut model = Vec::new();
            for a in witnesses[0]["Value"]
                .as_array()
                .ok_or(Error::Backend("model values"))?
            {
                b.tick()?;
                model.push(
                    a.as_str()
                        .and_then(|s| s.strip_prefix('a'))
                        .and_then(|s| s.parse::<usize>().ok())
                        .ok_or(Error::Backend("unexpected symbol"))?,
                );
            }
            model.sort_unstable();
            check_model(p, &model, b)?;
            Ok(Some(model))
        }
        _ => Err(Error::Backend("inconclusive solver probe")),
    }
}

/// Decode only full clingo JSON output, and independently check all candidates.
/// The `More=no` and UNSAT claims are explicitly trusted to the pinned solver.
pub fn decode(p: &Request, bytes: &[u8], l: &Limits, b: &mut Budget<'_>) -> Result<Reply, Error> {
    validate(p, l)?;
    if bytes.len() > l.output_bytes {
        return Err(Error::Limit("solver output"));
    }
    let v: serde_json::Value =
        serde_json::from_slice(bytes).map_err(|_| Error::Backend("solver JSON"))?;
    let result = v["Result"]
        .as_str()
        .ok_or(Error::Backend("missing result"))?;
    let complete = v["Models"]["More"].as_str() == Some("no");
    if !complete || !matches!(result, "SATISFIABLE" | "UNSATISFIABLE") {
        return Ok(inconclusive(p, "solver did not complete enumeration"));
    }
    let calls = v["Call"]
        .as_array()
        .ok_or(Error::Backend("missing calls"))?;
    if calls.len() != 1 {
        return Err(Error::Backend("expected one solve call"));
    }
    let mut models = Vec::new();
    if let Some(witnesses) = calls[0].get("Witnesses") {
        for w in witnesses
            .as_array()
            .ok_or(Error::Backend("witness array"))?
        {
            b.tick()?;
            if models.len() >= l.models {
                return Ok(inconclusive(p, "model bound"));
            }
            let mut m = Vec::new();
            for atom in w["Value"]
                .as_array()
                .ok_or(Error::Backend("model value array"))?
            {
                b.tick()?;
                let a = atom
                    .as_str()
                    .and_then(|s| s.strip_prefix('a'))
                    .and_then(|s| s.parse::<usize>().ok())
                    .ok_or(Error::Backend("unexpected symbol"))?;
                m.push(a);
            }
            m.sort_unstable();
            check_model(p, &m, b)?;
            if models.contains(&m) {
                return Err(Error::Backend("duplicate model"));
            }
            models.push(m);
        }
    }
    if (result == "UNSATISFIABLE") != models.is_empty() {
        return Err(Error::Backend("result/witness mismatch"));
    }
    if v["Models"]["Number"].as_u64() != Some(models.len() as u64) {
        return Err(Error::Backend("model count mismatch"));
    }
    let status = if models.is_empty() {
        Status::Inconsistent
    } else {
        Status::Consistent
    };
    let answers = p
        .queries
        .iter()
        .map(|&atom| {
            let yes = models.iter().position(|m| m.binary_search(&atom).is_ok());
            let no = models.iter().position(|m| m.binary_search(&atom).is_err());
            Answer {
                atom,
                skeptical: if models.is_empty() {
                    None
                } else {
                    Some(no.is_none())
                },
                credulous: if models.is_empty() {
                    None
                } else {
                    Some(yes.is_some())
                },
                true_witness: yes,
                false_witness: no,
            }
        })
        .collect();
    Ok(Reply {
        scope: p.scope.clone(),
        status,
        reason: "complete solver enumeration; all witnesses checked".into(),
        enumeration_complete: true,
        completeness_trust: "solver_trusted_no_certificate",
        witness_check: "handwritten_gl_reduct",
        models,
        answers,
    })
}
