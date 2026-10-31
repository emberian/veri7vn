//! Experimental pure providers, with independently checked results.
//! No Isabelle proof claim, host authority, durable state or production admission.
#![forbid(unsafe_code)]

pub mod algebra;
pub mod dimensions;
pub mod exact_lp;
pub mod formula;
pub mod formula_search;
pub mod graph;
pub mod shortest_path;
pub mod stoichiometry;
use serde::{Deserialize, Serialize};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid input: {0}")]
    Invalid(String),
    #[error("resource limit: {0}")]
    Limit(&'static str),
    #[error("candidate failed independent check: {0}")]
    Check(&'static str),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
}
pub type Result<T> = std::result::Result<T, Error>;

pub(crate) fn checkpoint(control: &dyn oracle_execution::WorkControl, work: u64) -> Result<()> {
    use oracle_execution::ExecutionError;
    control.checkpoint(work).map_err(|error| {
        Error::Limit(match error {
            ExecutionError::Cancelled => "shared cancellation",
            ExecutionError::Deadline => "shared deadline",
            ExecutionError::FuelExhausted => "shared work",
            _ => "shared execution budget",
        })
    })
}

/// Operator configuration. Search limits are cooperative, not hard containment.
#[derive(Clone, Debug, Serialize)]
pub struct Limits {
    pub request_bytes: usize,
    pub vertices: usize,
    pub edges: usize,
    pub graph_work: usize,
    /// Maximum serialized directed shortest-path certificate bytes.
    pub graph_reply_bytes: usize,
    pub expression_nodes: usize,
    pub expression_depth: usize,
    pub polynomial_terms: usize,
    pub coefficient_bits: u64,
    pub polynomial_work: usize,
    pub egraph_nodes: usize,
    pub iterations: usize,
    pub search_ms: u64,
    /// Maximum bits of any exact rational (numerator or denominator) in a
    /// rational-formula request: literals, bounds, intervals, evaluation.
    pub rational_bits: u64,
    /// Exact rational operations per checker or evaluation pass.
    pub rational_work: usize,
    /// Maximum nesting of a rational formula, including intermediate terms.
    pub formula_depth: usize,
    /// Maximum certificate steps (and explanation size) per request.
    pub proof_steps: usize,
    /// Maximum serialized rational-formula reply bytes.
    pub formula_reply_bytes: usize,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            request_bytes: 4 * 1024 * 1024,
            vertices: 10_000,
            edges: 100_000,
            graph_work: 5_000_000,
            graph_reply_bytes: 256 * 1024,
            expression_nodes: 128,
            expression_depth: 32,
            polynomial_terms: 512,
            coefficient_bits: 4096,
            polynomial_work: 1_000_000,
            egraph_nodes: 10_000,
            iterations: 12,
            search_ms: 50,
            rational_bits: 4096,
            rational_work: 1_000_000,
            formula_depth: 64,
            proof_steps: 20_000,
            formula_reply_bytes: 64 * 1024,
        }
    }
}

#[derive(Deserialize)]
#[serde(tag = "operation", content = "arguments", deny_unknown_fields)]
pub enum Request {
    #[serde(rename = "reasoning.exact_linear_feasibility")]
    ExactLinear(exact_lp::Problem),
    #[serde(rename = "graph.minimum_spanning_forest")]
    Forest(graph::GraphInput),
    #[serde(rename = "graph.shortest_path")]
    ShortestPath(shortest_path::ShortestPathInput),
    #[serde(rename = "algebra.optimize_polynomial")]
    Polynomial(algebra::PolynomialInput),
    #[serde(rename = "algebra.optimize_dimensional_polynomial")]
    Dimensional(dimensions::DimensionalInput),
    #[serde(rename = "algebra.simplify_rational")]
    Rational(formula_search::RationalInput),
    #[serde(rename = "chemistry.balance_reaction")]
    Reaction(stoichiometry::ReactionInput),
}

#[derive(Serialize)]
#[serde(untagged)]
pub enum Response {
    ExactLinear(exact_lp::Output),
    Forest(graph::Forest),
    ShortestPath(shortest_path::Certificate),
    Polynomial(algebra::Optimization),
    Dimensional(dimensions::DimensionalOptimization),
    Rational(formula_search::RationalReply),
    Reaction(stoichiometry::BalanceOutput),
}

/// Typed domain dispatch; independent certificate checks remain in the kernels.
pub fn execute(
    request: &Request,
    limits: &Limits,
    context: &oracle_execution::ExecutionContext,
) -> Result<Response> {
    execute_inner(request, limits, Some(context))
}
fn execute_inner(
    request: &Request,
    limits: &Limits,
    context: Option<&oracle_execution::ExecutionContext>,
) -> Result<Response> {
    let legacy = std::sync::atomic::AtomicBool::new(false);
    let control: &dyn oracle_execution::WorkControl =
        context.map_or(&legacy as &dyn oracle_execution::WorkControl, |c| c);
    checkpoint(control, 1)?;
    let reply = match request {
        Request::ExactLinear(input) => Response::ExactLinear(exact_lp::solve_controlled(
            input,
            &exact_lp::Limits::default(),
            control,
        )?),
        Request::ShortestPath(input) => Response::ShortestPath(
            shortest_path::shortest_path_bounded(input, &shortest_path_limits(limits), control)?,
        ),
        Request::Rational(input) => {
            let reply = formula_search::simplify_controlled(input, limits, context)?;
            if serde_json::to_vec(&reply)?.len() > limits.formula_reply_bytes {
                return Err(Error::Limit("formula reply bytes"));
            }
            Response::Rational(reply)
        }
        Request::Reaction(input) => Response::Reaction(stoichiometry::balance_reaction_controlled(
            input,
            &stoichiometry::ChemistryLimits::default(),
            control,
        )?),
        Request::Dimensional(input) => {
            Response::Dimensional(dimensions::optimize_controlled(input, limits, context)?)
        }
        Request::Forest(input) => Response::Forest(graph::minimum_spanning_forest_controlled(
            input, limits, control,
        )?),
        Request::Polynomial(input) => {
            Response::Polynomial(algebra::optimize_controlled(input, limits, context)?)
        }
    };
    checkpoint(control, 1)?;
    Ok(reply)
}

pub fn call(request: &str, limits: &Limits) -> Result<String> {
    if request.len() > limits.request_bytes {
        return Err(Error::Limit("request bytes"));
    }
    let request: Request =
        serde_json::from_str(request).map_err(|e| Error::Invalid(format!("request JSON: {e}")))?;
    let response = execute_inner(&request, limits, None)?;
    match &response {
        Response::ShortestPath(_) | Response::Rational(_) => Ok(serde_json::to_string(&response)?),
        _ => Ok(serde_json::to_string(&serde_json::to_value(&response)?)?),
    }
}

pub fn shortest_path_limits(limits: &Limits) -> shortest_path::PathLimits {
    shortest_path::PathLimits {
        vertices: limits.vertices,
        edges: limits.edges,
        work: limits.graph_work,
        milliseconds: limits.search_ms,
        reply_bytes: limits.graph_reply_bytes,
    }
}

/// Rational-formula budgets, repeated in that operation's catalog row.
pub fn rational_limits(limits: &Limits) -> serde_json::Value {
    serde_json::json!({
        "rational_bits": limits.rational_bits,
        "rational_work": limits.rational_work,
        "formula_depth": limits.formula_depth,
        "proof_steps": limits.proof_steps,
        "formula_reply_bytes": limits.formula_reply_bytes,
    })
}

pub fn catalog() -> serde_json::Value {
    serde_json::json!({
        "schema": "oracle-reasoning-experimental-v1",
        "assurance": "independent Rust checks; not Isabelle-verified",
        "hosting": "pure library/CLI; no Mini registration or hard containment",
        "limits": Limits::default(),
        "operations": [
            {"id": "reasoning.exact_linear_feasibility", "domain": "exact rational feasibility over caller-supplied rows a*x<=b with unrestricted variables; unknown is not infeasible; an optional minimization objective does not turn a feasible witness into an optimality claim", "exact_limits": exact_lp::Limits::default(), "assurance": "separate exact rational certificate replay; not Isabelle-verified", "arguments": {"variables": "unique nonempty variable labels", "rows": "list of {id, coefficients: exact rational strings, bound: exact rational string}", "objective": "optional minimization coefficients as exact rational strings"}},
            {"id": "graph.shortest_path", "domain": "exact directed minimum walk weight in the complete supplied multigraph only; finite, unreachable or unbounded below; missing world edges are not established", "path_limits": shortest_path_limits(&Limits::default()), "assurance": "independent Rust path/feasible-label, closed-set or anchored-negative-cycle check; not Isabelle-verified", "arguments": {"vertices": "positive integer; vertex IDs are 0..vertices-1", "edges": "list of [source, target, exact i64 weight]; stable edge ID is list position", "source": "vertex ID", "target": "vertex ID"}},
            {"id": "chemistry.balance_reaction", "domain": "exact element/isotope and charge conservation for supplied species; not reaction feasibility", "chemistry_limits": stoichiometry::ChemistryLimits::default(), "arguments": {"species": "list of {name, side: reactant|product, composition: {element_or_isotope: positive_u64}, charge: i64}; empty composition with charge -1 represents an explicit electron"}},
            {"id": "graph.minimum_spanning_forest", "domain": "supplied undirected multigraph, exact i64 edge weights", "arguments": {"vertices": "nonnegative integer; vertex IDs are 0..vertices-1", "edges": "list of [source, target, weight]; edge ID is list position"}},
            {"id": "algebra.optimize_polynomial", "domain": "dimensionless commutative polynomials with integer coefficients", "arguments": {"expression": "prefix expression: i64 literals, ASCII variables, binary + - *; no division or floating-point semantics"}},
            {"id": "algebra.optimize_dimensional_polynomial", "domain": "exact polynomials over normalized linear SI quantities; dimensions checked, physical law not established", "dimension_order": dimensions::DIMENSION_ORDER, "max_exponent": dimensions::MAX_EXPONENT, "arguments": {"expression": "prefix expression", "variables": "list of {name, dimension: seven SI integer exponents, kind?: linear|affine}; affine refused", "output_dimension": "optional seven SI integer exponents"}},
            {"id": "algebra.simplify_rational", "domain": "exact rational formulas (+ - * /) over linear SI quantities under supplied closed bounds; rewrites replayed as same-domain equalities on those bounds", "dimension_order": dimensions::DIMENSION_ORDER, "max_exponent": dimensions::MAX_EXPONENT, "rational_limits": rational_limits(&Limits::default()), "assurance": "egg proposer; independent Rust certificate replay; not Isabelle-verified", "arguments": {"expression": "prefix formula: exact rationals -?n or -?n/d, ASCII variables, binary + - * /; literals have no units, so a zero with units is (* 0 x)", "variables": "list of {name, dimension, kind?: linear}", "bounds": "optional list of {name, low, high} exact rational closed bounds", "output_dimension": "optional seven SI integer exponents", "point": "optional list of {name, value} assigning every variable"}}
        ]
    })
}
