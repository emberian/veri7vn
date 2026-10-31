use crate::{Error, Limits, Result};
use egg::{define_language, rewrite, CostFunction, Extractor, Id, Language, RecExpr, Runner};
use num_bigint::BigInt;
use num_traits::Zero;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::time::{Duration, Instant};

// Request variables must not enter egg's process-global Symbol interner: a long
// lived multitenant worker would otherwise retain every distinct caller name.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Variable(String);
impl std::fmt::Display for Variable {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}
impl std::str::FromStr for Variable {
    type Err = String;
    fn from_str(name: &str) -> std::result::Result<Self, Self::Err> {
        if name.len() > 64
            || !name
                .bytes()
                .next()
                .is_some_and(|c| c.is_ascii_alphabetic() || c == b'_')
            || !name.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_')
        {
            return Err("variables must be ASCII identifiers; constants must fit i64".into());
        }
        Ok(Self(name.to_owned()))
    }
}

define_language! {
    pub enum Expression {
        Num(i64),
        "+" = Add([Id; 2]),
        "-" = Sub([Id; 2]),
        "*" = Mul([Id; 2]),
        Var(Variable),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PolynomialInput {
    pub expression: String,
}

#[derive(Debug, Serialize)]
pub struct Optimization {
    pub schema: &'static str,
    pub expression: String,
    pub original_cost: usize,
    pub selected_cost: usize,
    pub cost_model: &'static str,
    pub polynomial_terms: usize,
    pub search_stop: String,
    pub iterations: usize,
    pub egraph_nodes: usize,
    pub check: &'static str,
    pub normalize_us: u128,
    pub search_us: u128,
    pub check_us: u128,
}

#[derive(Clone)]
struct Cost;
impl CostFunction<Expression> for Cost {
    type Cost = usize;
    fn cost<C>(&mut self, node: &Expression, mut child: C) -> usize
    where
        C: FnMut(Id) -> usize,
    {
        let own: usize = if matches!(node, Expression::Mul(_)) {
            4
        } else {
            1
        };
        node.children()
            .iter()
            .fold(own, |total, &id| total.saturating_add(child(id)))
    }
}

/// Shared bounded pre-parse for prefix expressions: whole-source bytes,
/// parenthesis nesting and token count are checked before any AST is built,
/// so parser work and stack use are bounded by the caller's limits.
pub(crate) fn check_source_bounds(
    source: &str,
    limits: &Limits,
    max_depth: usize,
    depth_name: &'static str,
) -> Result<()> {
    if source.len() > limits.request_bytes {
        return Err(Error::Limit("expression bytes"));
    }
    let mut depth = 0usize;
    for c in source.chars() {
        if c == '(' {
            depth += 1;
            if depth > max_depth {
                return Err(Error::Limit(depth_name));
            }
        } else if c == ')' {
            depth = depth
                .checked_sub(1)
                .ok_or_else(|| Error::Invalid("unbalanced expression".into()))?;
        }
    }
    if depth != 0 {
        return Err(Error::Invalid("unbalanced expression".into()));
    }
    if source
        .split(|c: char| c.is_whitespace() || c == '(' || c == ')')
        .filter(|s| !s.is_empty())
        .count()
        > limits.expression_nodes
    {
        return Err(Error::Limit("expression nodes"));
    }
    Ok(())
}

pub(crate) fn parse(source: &str, limits: &Limits) -> Result<RecExpr<Expression>> {
    check_source_bounds(source, limits, limits.expression_depth, "expression depth")?;
    let expression: RecExpr<Expression> = source
        .parse()
        .map_err(|e| Error::Invalid(format!("expression: {e}")))?;
    validate_expression(&expression, limits)?;
    Ok(expression)
}

fn validate_expression(expression: &RecExpr<Expression>, limits: &Limits) -> Result<()> {
    if expression.as_ref().is_empty() || expression.as_ref().len() > limits.expression_nodes {
        return Err(Error::Limit("expression nodes"));
    }
    Ok(())
}

// This checker uses exact sparse polynomial arithmetic, not e-graph equivalence
// or randomized evaluations. Expanded monomials are sorted multisets of variables.
type Polynomial = BTreeMap<Vec<Variable>, BigInt>;
fn normalize(expression: &RecExpr<Expression>, limits: &Limits) -> Result<Polynomial> {
    normalize_controlled(
        expression,
        limits,
        &std::sync::atomic::AtomicBool::new(false),
    )
}
fn normalize_controlled(
    expression: &RecExpr<Expression>,
    limits: &Limits,
    control: &dyn oracle_execution::WorkControl,
) -> Result<Polynomial> {
    validate_expression(expression, limits)?;
    let mut values: Vec<Polynomial> = Vec::new();
    let mut work = limits.polynomial_work;
    for node in expression.as_ref() {
        let mut result = Polynomial::new();
        let mut insert = |monomial: Vec<Variable>, coefficient: BigInt| -> Result<()> {
            crate::checkpoint(control, 1)?;
            work = work.checked_sub(1).ok_or(Error::Limit("polynomial work"))?;
            if monomial.len() > limits.expression_nodes {
                return Err(Error::Limit("polynomial degree"));
            }
            let value = result.entry(monomial.clone()).or_insert_with(BigInt::zero);
            *value += coefficient;
            if value.bits() > limits.coefficient_bits {
                return Err(Error::Limit("coefficient bits"));
            }
            if value.is_zero() {
                result.remove(&monomial);
            }
            if result.len() > limits.polynomial_terms {
                return Err(Error::Limit("polynomial terms"));
            }
            Ok(())
        };
        match node {
            Expression::Num(n) => insert(vec![], BigInt::from(*n))?,
            Expression::Var(symbol) => insert(vec![symbol.clone()], BigInt::from(1))?,
            Expression::Add([a, b]) | Expression::Sub([a, b]) => {
                for (m, c) in &values[usize::from(*a)] {
                    insert(m.clone(), c.clone())?;
                }
                for (m, c) in &values[usize::from(*b)] {
                    insert(
                        m.clone(),
                        if matches!(node, Expression::Sub(_)) {
                            -c
                        } else {
                            c.clone()
                        },
                    )?;
                }
            }
            Expression::Mul([a, b]) => {
                for (am, ac) in &values[usize::from(*a)] {
                    for (bm, bc) in &values[usize::from(*b)] {
                        let mut m = am.clone();
                        m.extend(bm.iter().cloned());
                        m.sort_unstable();
                        insert(m, ac * bc)?;
                    }
                }
            }
        }
        values.push(result);
    }
    Ok(values.pop().expect("validated nonempty expression"))
}

pub fn equivalent(left: &str, right: &str, limits: &Limits) -> Result<bool> {
    Ok(normalize(&parse(left, limits)?, limits)? == normalize(&parse(right, limits)?, limits)?)
}

pub(crate) fn equivalent_controlled(
    left: &str,
    right: &str,
    limits: &Limits,
    context: Option<&oracle_execution::ExecutionContext>,
) -> Result<bool> {
    let Some(context) = context else {
        return equivalent(left, right, limits);
    };
    Ok(
        normalize_controlled(&parse(left, limits)?, limits, context)?
            == normalize_controlled(&parse(right, limits)?, limits, context)?,
    )
}

pub fn optimize(input: &PolynomialInput, limits: &Limits) -> Result<Optimization> {
    optimize_controlled(input, limits, None)
}
pub fn optimize_controlled(
    input: &PolynomialInput,
    limits: &Limits,
    context: Option<&oracle_execution::ExecutionContext>,
) -> Result<Optimization> {
    let legacy = std::sync::atomic::AtomicBool::new(false);
    let control: &dyn oracle_execution::WorkControl =
        context.map_or(&legacy as &dyn oracle_execution::WorkControl, |c| c);
    let hook_context = context.cloned();
    let started = Instant::now();
    let expression = parse(&input.expression, limits)?;
    let polynomial = normalize_controlled(&expression, limits, control)?;
    let original_cost = Cost.cost_rec(&expression);
    let normalize_us = started.elapsed().as_micros();
    let search_started = Instant::now();
    let rules = vec![
        rewrite!("add-commute"; "(+ ?a ?b)" => "(+ ?b ?a)"),
        rewrite!("mul-commute"; "(* ?a ?b)" => "(* ?b ?a)"),
        rewrite!("add-associate"; "(+ (+ ?a ?b) ?c)" => "(+ ?a (+ ?b ?c))"),
        rewrite!("mul-associate"; "(* (* ?a ?b) ?c)" => "(* ?a (* ?b ?c))"),
        rewrite!("distribute"; "(* ?a (+ ?b ?c))" => "(+ (* ?a ?b) (* ?a ?c))"),
        rewrite!("factor"; "(+ (* ?a ?b) (* ?a ?c))" => "(* ?a (+ ?b ?c))"),
        rewrite!("add-zero"; "(+ ?a 0)" => "?a"),
        rewrite!("mul-zero"; "(* ?a 0)" => "0"),
        rewrite!("mul-one"; "(* ?a 1)" => "?a"),
        rewrite!("sub-self"; "(- ?a ?a)" => "0"),
        rewrite!("sub-zero"; "(- ?a 0)" => "?a"),
        rewrite!("sub-expand"; "(- ?a ?b)" => "(+ ?a (* -1 ?b))"),
    ];
    let runner = Runner::<Expression, ()>::default()
        .with_expr(&expression)
        .with_node_limit(limits.egraph_nodes)
        .with_iter_limit(limits.iterations)
        .with_time_limit(Duration::from_millis(limits.search_ms))
        .with_hook(move |_| {
            hook_context
                .as_ref()
                .map_or(Ok(()), |c| crate::checkpoint(c, 1))
                .map_err(|e| e.to_string())
        })
        .run(&rules);
    crate::checkpoint(control, 1)?;
    let (cost, candidate) = Extractor::new(&runner.egraph, Cost).find_best(runner.roots[0]);
    let search_us = search_started.elapsed().as_micros();
    let check_started = Instant::now();
    if normalize_controlled(&candidate, limits, control)? != polynomial {
        return Err(Error::Check("polynomial identity"));
    }
    Ok(Optimization {
        schema: "oracle-polynomial-optimization-v1",
        expression: candidate.to_string(),
        original_cost,
        selected_cost: cost,
        cost_model:
            "tree cost: multiply=4, other nodes=1; not measured runtime or global optimality",
        polynomial_terms: polynomial.len(),
        search_stop: format!("{:?}", runner.stop_reason),
        iterations: runner.iterations.len(),
        egraph_nodes: runner.egraph.total_size(),
        check: "independent exact integer-polynomial normalization in Rust; not an Isabelle proof",
        normalize_us,
        search_us,
        check_us: check_started.elapsed().as_micros(),
    })
}
