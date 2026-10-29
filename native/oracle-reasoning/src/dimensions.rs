//! Dimensional admission for exact integer polynomials over linear SI quantities.
//!
//! This checks dimensions and polynomial identities in Rust. It does not prove
//! a physical law, establish units from a variable's name, convert numerical
//! values, or preserve floating-point evaluation. Callers must normalize scales
//! and affine quantities (such as Celsius temperatures) outside this boundary.

use crate::algebra::{self, Expression, Optimization, PolynomialInput, Variable};
use crate::{Error, Limits, Result};
use egg::RecExpr;
use num_bigint::BigInt;
use num_traits::Zero;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

/// Each SI exponent, including each intermediate product, lies in this range.
pub const MAX_EXPONENT: i16 = 64;
pub const DIMENSION_ORDER: [&str; 7] = [
    "length",
    "mass",
    "time",
    "electric_current",
    "temperature",
    "amount",
    "luminous_intensity",
];

/// Exact SI exponents in DIMENSION_ORDER; private storage prevents unchecked
/// construction through the Rust API. Fractional exponents are unsupported.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "[i16; 7]", into = "[i16; 7]")]
pub struct Dimension([i16; 7]);

impl Dimension {
    pub const DIMENSIONLESS: Self = Self([0; 7]);

    pub fn new(exponents: [i16; 7]) -> Result<Self> {
        if exponents
            .iter()
            .any(|e| !(-MAX_EXPONENT..=MAX_EXPONENT).contains(e))
        {
            return Err(Error::Invalid(format!(
                "SI exponents must lie in -{MAX_EXPONENT}..={MAX_EXPONENT}"
            )));
        }
        Ok(Self(exponents))
    }

    pub fn exponents(self) -> [i16; 7] {
        self.0
    }

    fn product(self, rhs: Self) -> Result<Self> {
        let mut result = [0; 7];
        for (i, exponent) in result.iter_mut().enumerate() {
            *exponent = self.0[i]
                .checked_add(rhs.0[i])
                .filter(|e| (-MAX_EXPONENT..=MAX_EXPONENT).contains(e))
                .ok_or(Error::Limit("SI dimension exponent"))?;
        }
        Ok(Self(result))
    }
}

impl TryFrom<[i16; 7]> for Dimension {
    type Error = String;
    fn try_from(value: [i16; 7]) -> std::result::Result<Self, Self::Error> {
        Self::new(value).map_err(|e| e.to_string())
    }
}

impl From<Dimension> for [i16; 7] {
    fn from(value: Dimension) -> Self {
        value.0
    }
}

impl std::fmt::Display for Dimension {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?} in SI order", self.0)
    }
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QuantityKind {
    #[default]
    Linear,
    Affine,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VariableAnnotation {
    pub name: String,
    pub dimension: Dimension,
    #[serde(default)]
    pub kind: QuantityKind,
}

/// Every original variable must occur exactly once in `variables`, with no
/// unused annotations. A list rather than a JSON object exposes duplicate names
/// so they cannot silently overwrite an earlier annotation.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DimensionalInput {
    pub expression: String,
    pub variables: Vec<VariableAnnotation>,
    /// Optional assertion of the requested output dimension. A purely numerical
    /// exact zero can inhabit this dimension; other outputs must already match.
    #[serde(default)]
    pub output_dimension: Option<Dimension>,
}

#[derive(Debug, Serialize)]
pub struct DimensionalOptimization {
    #[serde(flatten)]
    pub optimization: Optimization,
    pub output_dimension: Dimension,
    pub dimension_order: [&'static str; 7],
    pub dimension_check: &'static str,
    pub unit_convention: &'static str,
    /// If an untyped extraction erases a zero's original dimension or exceeds
    /// dimensional admission limits, retain the admitted original expression.
    pub selection_fallback: Option<String>,
}

// This is a computed exact numerical zero, never an absent annotation
// or an unknown dimension. A variable-bearing zero retains its concrete type.
#[derive(Clone, Copy)]
enum InferredDimension {
    NumericalZero,
    Concrete(Dimension),
}

impl InferredDimension {
    fn resolve(self, expected: Option<Dimension>) -> Result<Dimension> {
        match (self, expected) {
            (Self::NumericalZero, dimension) => Ok(dimension.unwrap_or(Dimension::DIMENSIONLESS)),
            (Self::Concrete(actual), None) => Ok(actual),
            (Self::Concrete(actual), Some(expected)) if actual == expected => Ok(actual),
            (Self::Concrete(actual), Some(expected)) => Err(Error::Invalid(format!(
                "output dimension {actual} does not match requested {expected}"
            ))),
        }
    }

    fn sum(self, rhs: Self) -> Result<Self> {
        match (self, rhs) {
            (Self::NumericalZero, other) | (other, Self::NumericalZero) => Ok(other),
            (Self::Concrete(a), Self::Concrete(b)) if a == b => Ok(Self::Concrete(a)),
            (Self::Concrete(a), Self::Concrete(b)) => Err(Error::Invalid(format!(
                "addition/subtraction requires equal dimensions: {a} versus {b}"
            ))),
        }
    }

    fn as_product_factor(self) -> Dimension {
        match self {
            Self::NumericalZero => Dimension::DIMENSIONLESS,
            Self::Concrete(d) => d,
        }
    }
}

struct TypedValue {
    dimension: InferredDimension,
    // Only variable-free expressions have a numeric value here. In particular,
    // x-x is not converted into a dimension-polymorphic zero.
    constant: Option<BigInt>,
}

type Environment = BTreeMap<Variable, Dimension>;

fn infer(
    expression: &RecExpr<Expression>,
    environment: &Environment,
    limits: &Limits,
) -> Result<InferredDimension> {
    let mut values: Vec<TypedValue> = Vec::with_capacity(expression.as_ref().len());
    for node in expression.as_ref() {
        let mut value = match node {
            Expression::Num(n) => TypedValue {
                dimension: InferredDimension::Concrete(Dimension::DIMENSIONLESS),
                constant: Some(BigInt::from(*n)),
            },
            Expression::Var(name) => TypedValue {
                dimension: InferredDimension::Concrete(*environment.get(name).ok_or_else(
                    || Error::Invalid(format!("missing dimension annotation for {name}")),
                )?),
                constant: None,
            },
            Expression::Add([a, b]) | Expression::Sub([a, b]) | Expression::Mul([a, b]) => {
                let left = &values[usize::from(*a)];
                let right = &values[usize::from(*b)];
                // Check both children and the operator before any simplification.
                let dimension = if matches!(node, Expression::Mul(_)) {
                    InferredDimension::Concrete(
                        left.dimension
                            .as_product_factor()
                            .product(right.dimension.as_product_factor())?,
                    )
                } else {
                    left.dimension.sum(right.dimension)?
                };
                let constant = match (&left.constant, &right.constant) {
                    (Some(a), Some(b)) => Some(match node {
                        Expression::Add(_) => a + b,
                        Expression::Sub(_) => a - b,
                        Expression::Mul(_) => a * b,
                        _ => unreachable!(),
                    }),
                    _ => None,
                };
                TypedValue {
                    dimension,
                    constant,
                }
            }
        };
        if let Some(constant) = &value.constant {
            if constant.bits() > limits.coefficient_bits {
                return Err(Error::Limit("coefficient bits"));
            }
            if constant.is_zero() {
                value.dimension = InferredDimension::NumericalZero;
            }
        }
        values.push(value);
    }
    values
        .pop()
        .map(|v| v.dimension)
        .ok_or_else(|| Error::Invalid("empty expression".into()))
}

fn admit(input: &DimensionalInput, limits: &Limits) -> Result<(Environment, Dimension)> {
    let expression = algebra::parse(&input.expression, limits)?;
    if input.variables.len() > limits.expression_nodes {
        return Err(Error::Limit("dimension annotations"));
    }
    let mut environment = Environment::new();
    for annotation in &input.variables {
        let name: Variable = annotation.name.parse().map_err(Error::Invalid)?;
        if matches!(annotation.kind, QuantityKind::Affine) {
            return Err(Error::Invalid(format!(
                "affine quantity {name} must be normalized to a linear SI quantity outside this operation"
            )));
        }
        if environment
            .insert(name.clone(), annotation.dimension)
            .is_some()
        {
            return Err(Error::Invalid(format!(
                "duplicate dimension annotation for {name}"
            )));
        }
    }
    let used: BTreeSet<_> = expression
        .as_ref()
        .iter()
        .filter_map(|node| match node {
            Expression::Var(name) => Some(name),
            _ => None,
        })
        .collect();
    for name in environment.keys() {
        if !used.contains(name) {
            return Err(Error::Invalid(format!(
                "unused dimension annotation for {name}"
            )));
        }
    }
    let dimension = infer(&expression, &environment, limits)?.resolve(input.output_dimension)?;
    Ok((environment, dimension))
}

fn check_admitted_candidate(
    input: &DimensionalInput,
    candidate: &str,
    environment: &Environment,
    expected: Dimension,
    limits: &Limits,
) -> Result<Dimension> {
    let expression = algebra::parse(candidate, limits)?;
    infer(&expression, environment, limits)?.resolve(Some(expected))?;
    if !algebra::equivalent(&input.expression, candidate, limits)? {
        return Err(Error::Check("dimensional polynomial identity"));
    }
    Ok(expected)
}

/// Check the complete original expression, then check a proposed expression's
/// dimensions and exact polynomial identity. The candidate may omit original
/// variables but cannot introduce new variables or erase an invalid input.
pub fn check_candidate(
    input: &DimensionalInput,
    candidate: &str,
    limits: &Limits,
) -> Result<Dimension> {
    let (environment, dimension) = admit(input, limits)?;
    check_admitted_candidate(input, candidate, &environment, dimension, limits)
}

/// Optimize an admitted dimensional polynomial and recheck the actual selected
/// expression against the original dimension and independent exact arithmetic.
pub fn optimize(input: &DimensionalInput, limits: &Limits) -> Result<DimensionalOptimization> {
    let (environment, output_dimension) = admit(input, limits)?;
    let mut optimization = algebra::optimize(
        &PolynomialInput {
            expression: input.expression.clone(),
        },
        limits,
    )?;
    // The algebra provider has already independently checked polynomial
    // identity. Only dimensional rejection triggers this fallback, never a
    // failed identity check. The public checker remains strict for candidates.
    let selected_dimension = algebra::parse(&optimization.expression, limits)
        .and_then(|expression| infer(&expression, &environment, limits))
        .and_then(|dimension| dimension.resolve(Some(output_dimension)));
    let selection_fallback = if let Err(error) = selected_dimension {
        optimization.expression = input.expression.clone();
        optimization.selected_cost = optimization.original_cost;
        Some(format!("retained original expression: selected candidate failed dimensional admission: {error}"))
    } else {
        None
    };
    check_admitted_candidate(
        input,
        &optimization.expression,
        &environment,
        output_dimension,
        limits,
    )?;
    optimization.schema = "oracle-dimensional-polynomial-optimization-v1";
    Ok(DimensionalOptimization {
        optimization,
        output_dimension,
        dimension_order: DIMENSION_ORDER,
        dimension_check: "original and selected expressions checked with exact SI exponents; numerical zero may take the required dimension; variable-bearing zero retains its dimension",
        unit_convention: "variables denote coherent linear SI quantities; scale/affine conversion is external; dimensional consistency does not establish a physical law or floating-point equality",
        selection_fallback,
    })
}
