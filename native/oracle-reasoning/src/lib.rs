//! Experimental pure providers, with independently checked results.
//! No Isabelle proof claim, host authority, durable state or production admission.
#![forbid(unsafe_code)]

pub mod algebra;
pub mod dimensions;
pub mod graph;
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

/// Operator configuration. Search limits are cooperative, not hard containment.
#[derive(Clone, Debug, Serialize)]
pub struct Limits {
    pub request_bytes: usize,
    pub vertices: usize,
    pub edges: usize,
    pub expression_nodes: usize,
    pub expression_depth: usize,
    pub polynomial_terms: usize,
    pub coefficient_bits: u64,
    pub polynomial_work: usize,
    pub egraph_nodes: usize,
    pub iterations: usize,
    pub search_ms: u64,
}
impl Default for Limits {
    fn default() -> Self {
        Self {
            request_bytes: 4 * 1024 * 1024,
            vertices: 10_000,
            edges: 100_000,
            expression_nodes: 128,
            expression_depth: 32,
            polynomial_terms: 512,
            coefficient_bits: 4096,
            polynomial_work: 1_000_000,
            egraph_nodes: 10_000,
            iterations: 12,
            search_ms: 50,
        }
    }
}

#[derive(Deserialize)]
#[serde(tag = "operation", content = "arguments", deny_unknown_fields)]
enum Request {
    #[serde(rename = "graph.minimum_spanning_forest")]
    Forest(graph::GraphInput),
    #[serde(rename = "algebra.optimize_polynomial")]
    Polynomial(algebra::PolynomialInput),
    #[serde(rename = "algebra.optimize_dimensional_polynomial")]
    Dimensional(dimensions::DimensionalInput),
    #[serde(rename = "chemistry.balance_reaction")]
    Reaction(stoichiometry::ReactionInput),
}

pub fn call(request: &str, limits: &Limits) -> Result<String> {
    if request.len() > limits.request_bytes {
        return Err(Error::Limit("request bytes"));
    }
    let reply = match serde_json::from_str(request)? {
        Request::Reaction(input) => serde_json::to_value(stoichiometry::balance_reaction(
            &input,
            &stoichiometry::ChemistryLimits::default(),
        )?)?,
        Request::Dimensional(input) => serde_json::to_value(dimensions::optimize(&input, limits)?)?,
        Request::Forest(input) => {
            serde_json::to_value(graph::minimum_spanning_forest(&input, limits)?)?
        }
        Request::Polynomial(input) => serde_json::to_value(algebra::optimize(&input, limits)?)?,
    };
    Ok(serde_json::to_string(&reply)?)
}

pub fn catalog() -> serde_json::Value {
    serde_json::json!({
        "schema": "oracle-reasoning-experimental-v1",
        "assurance": "independent Rust checks; not Isabelle-verified",
        "hosting": "pure library/CLI; no Mini registration or hard containment",
        "limits": Limits::default(),
        "operations": [
            {"id": "chemistry.balance_reaction", "domain": "exact element/isotope and charge conservation for supplied species; not reaction feasibility", "chemistry_limits": stoichiometry::ChemistryLimits::default(), "arguments": {"species": "list of {name, side: reactant|product, composition: {element_or_isotope: positive_u64}, charge: i64}; empty composition with charge -1 represents an explicit electron"}},
            {"id": "graph.minimum_spanning_forest", "domain": "supplied undirected multigraph, exact i64 edge weights", "arguments": {"vertices": "nonnegative integer; vertex IDs are 0..vertices-1", "edges": "list of [source, target, weight]; edge ID is list position"}},
            {"id": "algebra.optimize_polynomial", "domain": "dimensionless commutative polynomials with integer coefficients", "arguments": {"expression": "prefix expression: i64 literals, ASCII variables, binary + - *; no division or floating-point semantics"}},
            {"id": "algebra.optimize_dimensional_polynomial", "domain": "exact polynomials over normalized linear SI quantities; dimensions checked, physical law not established", "dimension_order": dimensions::DIMENSION_ORDER, "max_exponent": dimensions::MAX_EXPONENT, "arguments": {"expression": "prefix expression", "variables": "list of {name, dimension: seven SI integer exponents, kind?: linear|affine}; affine refused", "output_dimension": "optional seven SI integer exponents"}}
        ]
    })
}
