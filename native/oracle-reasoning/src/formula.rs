//! Exact rational formulas over linear SI quantities: the checking side.
//!
//! This module never imports the e-graph library. It owns the formula
//! representation (a hash-consed DAG whose constructor checks dimensions and
//! depth), the caller's interval premises, the rule table, the replay checker
//! for equality certificates and the evaluator. The untrusted proposer in
//! `formula_search` can only add nodes through `Dag::put` and hand in a
//! `Certificate`; nothing it says is believed without replay.
//!
//! What a replayed certificate establishes: on the box `B` of caller-supplied
//! closed bounds (unbounded variables range over all rationals), the original
//! and selected formulas are defined at exactly the same points, and agree
//! there. Every rule below is such a two-sided equivalence on `B`, so the
//! judgement is symmetric, transitive and a congruence. This is a Rust replay
//! check, not an Isabelle theorem. Literals are exact rationals without units.

use crate::algebra::Variable;
use crate::dimensions::{Dimension, QuantityKind, VariableAnnotation};
use crate::{Error, Limits, Result};
use num_bigint::BigInt;
use num_rational::BigRational;
use num_traits::{One, Signed, Zero};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, HashMap};

pub type Q = BigRational;
pub type NodeId = usize;

/// Size of an exact rational: the larger of numerator and denominator bits.
pub fn rational_bits(q: &Q) -> u64 {
    q.numer().bits().max(q.denom().bits())
}

/// Parse `-?(0|[1-9][0-9]*)(/[1-9][0-9]*)?`. The token length is bounded
/// before any big-integer parse, then the reduced value's bits are checked.
pub fn parse_rational(text: &str, limits: &Limits) -> Result<Q> {
    let digits_cap = (limits.rational_bits / 3) as usize + 4;
    let body = text.strip_prefix('-').unwrap_or(text);
    let (numerator, denominator) = match body.split_once('/') {
        Some((n, d)) => (n, Some(d)),
        None => (body, None),
    };
    let canonical = |part: &str, nonzero: bool| {
        !part.is_empty()
            && part.bytes().all(|c| c.is_ascii_digit())
            && (part == "0" && !nonzero || !part.starts_with('0'))
    };
    if !canonical(numerator, false)
        || denominator.is_some_and(|d| !canonical(d, true))
        || (text.starts_with('-') && numerator == "0")
    {
        return Err(Error::Invalid(format!(
            "exact rational must match -?(0|[1-9][0-9]*)(/[1-9][0-9]*)?: {}",
            text.chars().take(32).collect::<String>()
        )));
    }
    if numerator.len() > digits_cap || denominator.is_some_and(|d| d.len() > digits_cap) {
        return Err(Error::Limit("rational bits"));
    }
    let parse = |part: &str| BigInt::parse_bytes(part.as_bytes(), 10).expect("checked digits");
    let mut value = Q::new(
        parse(numerator),
        denominator.map(parse).unwrap_or_else(BigInt::one),
    );
    if text.starts_with('-') {
        value = -value;
    }
    if rational_bits(&value) > limits.rational_bits {
        return Err(Error::Limit("rational bits"));
    }
    Ok(value)
}

/// Shared budget for exact rational arithmetic in one request.
pub struct Budget {
    bits: u64,
    work: usize,
}
impl Budget {
    pub fn new(limits: &Limits) -> Self {
        Self {
            bits: limits.rational_bits,
            work: limits.rational_work,
        }
    }
    fn charge(&mut self) -> Result<()> {
        self.work = self
            .work
            .checked_sub(1)
            .ok_or(Error::Limit("rational work"))?;
        Ok(())
    }
    fn admit(&mut self, q: Q) -> Result<Q> {
        self.charge()?;
        if rational_bits(&q) > self.bits {
            return Err(Error::Limit("rational bits"));
        }
        Ok(q)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Op {
    Add,
    Sub,
    Mul,
    Div,
}
impl Op {
    pub fn symbol(self) -> &'static str {
        match self {
            Op::Add => "+",
            Op::Sub => "-",
            Op::Mul => "*",
            Op::Div => "/",
        }
    }
    fn from_symbol(token: &str) -> Option<Self> {
        Some(match token {
            "+" => Op::Add,
            "-" => Op::Sub,
            "*" => Op::Mul,
            "/" => Op::Div,
            _ => return None,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum Node {
    /// Exact dimensionless literal.
    Lit(Q),
    /// Index into the DAG's admitted variable table.
    Var(usize),
    Op(Op, NodeId, NodeId),
}

/// Append-only hash-consed formula DAG. Children always precede parents, so
/// every pass below runs in ascending id order without recursion. Private
/// storage means a node can only enter through `put`, which checks dimensions,
/// the node cap and the depth cap.
pub struct Dag {
    variables: Vec<(Variable, Dimension)>,
    index: BTreeMap<Variable, usize>,
    nodes: Vec<Node>,
    dimensions: Vec<Dimension>,
    depths: Vec<usize>,
    intern: HashMap<Node, NodeId>,
    max_nodes: usize,
    max_depth: usize,
}

impl Dag {
    /// Admit linear SI annotations; affine quantities and duplicates are refused.
    pub fn new(annotations: &[VariableAnnotation], limits: &Limits) -> Result<Self> {
        if annotations.len() > limits.expression_nodes {
            return Err(Error::Limit("dimension annotations"));
        }
        let mut dag = Self {
            variables: Vec::new(),
            index: BTreeMap::new(),
            nodes: Vec::new(),
            dimensions: Vec::new(),
            depths: Vec::new(),
            intern: HashMap::new(),
            max_nodes: limits.egraph_nodes,
            max_depth: limits.formula_depth,
        };
        for annotation in annotations {
            let name: Variable = annotation.name.parse().map_err(Error::Invalid)?;
            if matches!(annotation.kind, QuantityKind::Affine) {
                return Err(Error::Invalid(format!(
                    "affine quantity {name} must be normalized to a linear SI quantity outside this operation"
                )));
            }
            if dag.index.contains_key(&name) {
                return Err(Error::Invalid(format!(
                    "duplicate dimension annotation for {name}"
                )));
            }
            dag.index.insert(name.clone(), dag.variables.len());
            dag.variables.push((name, annotation.dimension));
        }
        Ok(dag)
    }

    pub fn len(&self) -> usize {
        self.nodes.len()
    }
    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }
    pub fn node(&self, id: NodeId) -> Result<&Node> {
        self.nodes
            .get(id)
            .ok_or(Error::Check("unknown formula node"))
    }
    pub fn dimension(&self, id: NodeId) -> Result<Dimension> {
        self.dimensions
            .get(id)
            .copied()
            .ok_or(Error::Check("unknown formula node"))
    }
    pub fn variable_count(&self) -> usize {
        self.variables.len()
    }
    pub fn variable_name(&self, index: usize) -> Option<&Variable> {
        self.variables.get(index).map(|(name, _)| name)
    }
    pub fn variable_index(&self, name: &str) -> Option<usize> {
        name.parse::<Variable>()
            .ok()
            .and_then(|name| self.index.get(&name).copied())
    }

    /// Insert (or find) a node. Addition and subtraction need equal dimensions;
    /// products and quotients add or subtract exponents within the SI cap.
    pub fn put(&mut self, node: Node) -> Result<NodeId> {
        if let Some(id) = self.intern.get(&node) {
            return Ok(*id);
        }
        let (dimension, depth) = match &node {
            Node::Lit(_) => (Dimension::DIMENSIONLESS, 1),
            Node::Var(index) => (
                self.variables
                    .get(*index)
                    .ok_or(Error::Check("unknown variable index"))?
                    .1,
                1,
            ),
            Node::Op(op, a, b) => {
                let (da, db) = (self.dimension(*a)?, self.dimension(*b)?);
                let dimension = match op {
                    Op::Add | Op::Sub if da == db => da,
                    Op::Add | Op::Sub => {
                        return Err(Error::Invalid(format!(
                            "addition/subtraction requires equal dimensions: {da} versus {db}"
                        )))
                    }
                    Op::Mul => da.product(db)?,
                    Op::Div => da.quotient(db)?,
                };
                (dimension, 1 + self.depths[*a].max(self.depths[*b]))
            }
        };
        if depth > self.max_depth {
            return Err(Error::Limit("formula depth"));
        }
        if self.nodes.len() >= self.max_nodes {
            return Err(Error::Limit("formula nodes"));
        }
        let id = self.nodes.len();
        self.nodes.push(node.clone());
        self.dimensions.push(dimension);
        self.depths.push(depth);
        self.intern.insert(node, id);
        Ok(id)
    }

    pub fn literal(&mut self, value: Q) -> Result<NodeId> {
        self.put(Node::Lit(value))
    }
    pub fn variable(&mut self, name: &str) -> Result<NodeId> {
        let index = self
            .variable_index(name)
            .ok_or_else(|| Error::Invalid(format!("missing dimension annotation for {name}")))?;
        self.put(Node::Var(index))
    }
    pub fn op(&mut self, op: Op, a: NodeId, b: NodeId) -> Result<NodeId> {
        self.put(Node::Op(op, a, b))
    }

    /// Parse a prefix formula without recursion. Atoms are exact rationals
    /// (see `parse_rational`) or annotated ASCII identifiers; operators are
    /// binary `+ - * /`. Source size, nesting and tokens are bounded first.
    pub fn parse(&mut self, source: &str, limits: &Limits) -> Result<NodeId> {
        crate::algebra::check_source_bounds(source, limits, limits.formula_depth, "formula depth")?;
        let spaced = source.replace('(', " ( ").replace(')', " ) ");
        let mut tokens = spaced.split_whitespace();
        let mut frames: Vec<(Op, Vec<NodeId>)> = Vec::new();
        let mut result = None;
        let invalid = |what: &str| Error::Invalid(format!("formula: {what}"));
        while let Some(token) = tokens.next() {
            let value = match token {
                "(" => {
                    let op = tokens
                        .next()
                        .and_then(Op::from_symbol)
                        .ok_or_else(|| invalid("expected + - * / after '('"))?;
                    frames.push((op, Vec::with_capacity(2)));
                    continue;
                }
                ")" => {
                    let (op, args) = frames.pop().ok_or_else(|| invalid("unbalanced ')'"))?;
                    if args.len() != 2 {
                        return Err(invalid("operators take exactly two arguments"));
                    }
                    self.op(op, args[0], args[1])?
                }
                atom if atom.starts_with(|c: char| c.is_ascii_digit() || c == '-') => {
                    let value = parse_rational(atom, limits)?;
                    self.literal(value)?
                }
                atom => self.variable(atom)?,
            };
            match frames.last_mut() {
                Some((_, args)) if args.len() < 2 => args.push(value),
                Some(_) => return Err(invalid("operators take exactly two arguments")),
                None if result.is_none() => result = Some(value),
                None => return Err(invalid("trailing input after the formula")),
            }
        }
        if !frames.is_empty() {
            return Err(invalid("unbalanced '('"));
        }
        result.ok_or_else(|| invalid("empty formula"))
    }

    /// Ids reachable from `roots`, ascending (children before parents).
    pub fn reachable(&self, roots: &[NodeId]) -> Result<Vec<NodeId>> {
        let mut seen = BTreeSet::new();
        let mut stack: Vec<NodeId> = roots.to_vec();
        while let Some(id) = stack.pop() {
            if seen.insert(id) {
                if let Node::Op(_, a, b) = self.node(id)? {
                    stack.push(*a);
                    stack.push(*b);
                }
            }
        }
        Ok(seen.into_iter().collect())
    }

    /// Distinct denominators of `root`, inner ones first.
    pub fn denominators(&self, root: NodeId) -> Result<Vec<NodeId>> {
        let mut result = BTreeSet::new();
        for id in self.reachable(&[root])? {
            if let Node::Op(Op::Div, _, b) = self.node(id)? {
                result.insert(*b);
            }
        }
        Ok(result.into_iter().collect())
    }

    /// Prefix rendering, built bottom-up without recursion.
    pub fn render(&self, root: NodeId) -> Result<String> {
        let mut text: HashMap<NodeId, String> = HashMap::new();
        for id in self.reachable(&[root])? {
            let rendered = match self.node(id)? {
                Node::Lit(q) => q.to_string(),
                Node::Var(index) => self.variables[*index].0.to_string(),
                Node::Op(op, a, b) => format!("({} {} {})", op.symbol(), text[a], text[b]),
            };
            text.insert(id, rendered);
        }
        Ok(text.remove(&root).expect("root is reachable"))
    }

    /// Tree cost (divide=8, multiply=4, every other node=1): an abstract count.
    pub fn tree_cost(&self, root: NodeId) -> Result<u128> {
        let mut cost: HashMap<NodeId, u128> = HashMap::new();
        for id in self.reachable(&[root])? {
            let own = match self.node(id)? {
                Node::Op(Op::Div, a, b) => 8u128.saturating_add(cost[a]).saturating_add(cost[b]),
                Node::Op(Op::Mul, a, b) => 4u128.saturating_add(cost[a]).saturating_add(cost[b]),
                Node::Op(_, a, b) => 1u128.saturating_add(cost[a]).saturating_add(cost[b]),
                _ => 1,
            };
            cost.insert(id, own);
        }
        Ok(cost[&root])
    }

    pub fn variables_used(&self, root: NodeId) -> Result<BTreeSet<usize>> {
        let mut used = BTreeSet::new();
        for id in self.reachable(&[root])? {
            if let Node::Var(index) = self.node(id)? {
                used.insert(*index);
            }
        }
        Ok(used)
    }
}

/// Closed exact interval `[low, high]`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Interval {
    pub low: Q,
    pub high: Q,
}
impl Interval {
    pub fn excludes_zero(&self) -> bool {
        self.low.is_positive() || self.high.is_negative()
    }
    pub fn contains(&self, q: &Q) -> bool {
        &self.low <= q && q <= &self.high
    }
    fn hull(values: [Q; 4]) -> Self {
        let [a, b, c, d] = values;
        let low = a.clone().min(b.clone()).min(c.clone()).min(d.clone());
        let high = a.max(b).max(c).max(d);
        Self { low, high }
    }
}

/// Caller-supplied closed bound on one variable, as exact rational text.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BoundInput {
    pub name: String,
    pub low: String,
    pub high: String,
}

/// Admitted interval premises: at most one closed bound per annotated
/// variable. They are caller premises, not physical facts.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Premises {
    bounds: BTreeMap<usize, Interval>,
}
impl Premises {
    pub fn new(dag: &Dag, inputs: &[BoundInput], limits: &Limits) -> Result<Self> {
        if inputs.len() > dag.variable_count() {
            return Err(Error::Invalid(
                "more bounds than annotated variables".into(),
            ));
        }
        let mut bounds = BTreeMap::new();
        for input in inputs {
            let index = dag.variable_index(&input.name).ok_or_else(|| {
                Error::Invalid(format!(
                    "bound names an unannotated variable {}",
                    input.name
                ))
            })?;
            let interval = Interval {
                low: parse_rational(&input.low, limits)?,
                high: parse_rational(&input.high, limits)?,
            };
            if interval.low > interval.high {
                return Err(Error::Invalid(format!("empty bound for {}", input.name)));
            }
            if bounds.insert(index, interval).is_some() {
                return Err(Error::Invalid(format!(
                    "duplicate bound for {}",
                    input.name
                )));
            }
        }
        Ok(Self { bounds })
    }
    pub fn none() -> Self {
        Self {
            bounds: BTreeMap::new(),
        }
    }
    pub fn bound(&self, variable: usize) -> Option<&Interval> {
        self.bounds.get(&variable)
    }
}

/// What the checker knows about one node on the box `B`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Fact {
    /// Encloses the node's value at every point of `B` where it is defined;
    /// `None` means no finite enclosure was established.
    pub interval: Option<Interval>,
    /// Every division inside has a denominator whose enclosure excludes zero,
    /// so the node is defined at every point of `B`.
    pub total: bool,
}

/// Interval facts for every DAG node, in one ascending pass.
pub fn facts(dag: &Dag, premises: &Premises, budget: &mut Budget) -> Result<Vec<Fact>> {
    let mut out: Vec<Fact> = Vec::with_capacity(dag.len());
    for id in 0..dag.len() {
        let fact = match dag.node(id)? {
            Node::Lit(q) => Fact {
                interval: Some(Interval {
                    low: q.clone(),
                    high: q.clone(),
                }),
                total: true,
            },
            Node::Var(index) => Fact {
                interval: premises.bound(*index).cloned(),
                total: true,
            },
            Node::Op(op, a, b) => {
                let (fa, fb) = (&out[*a], &out[*b]);
                let total = fa.total
                    && fb.total
                    && (*op != Op::Div
                        || fb.interval.as_ref().is_some_and(Interval::excludes_zero));
                let interval = enclose(*op, fa.interval.as_ref(), fb.interval.as_ref(), budget)?;
                Fact { interval, total }
            }
        };
        out.push(fact);
    }
    Ok(out)
}

/// Enclosure of `x op y` from optional child enclosures. A product with an
/// exact zero factor is zero wherever it is defined, even if the other factor
/// is unbounded.
pub fn enclose(
    op: Op,
    x: Option<&Interval>,
    y: Option<&Interval>,
    budget: &mut Budget,
) -> Result<Option<Interval>> {
    let point_zero = |i: Option<&Interval>| i.is_some_and(|i| i.low.is_zero() && i.high.is_zero());
    match (x, y) {
        _ if op == Op::Mul && (point_zero(x) || point_zero(y)) => Ok(Some(Interval {
            low: Q::zero(),
            high: Q::zero(),
        })),
        (Some(x), Some(y)) => interval_op(op, x, y, budget),
        _ => Ok(None),
    }
}

/// Exact closed-interval arithmetic; division only by an interval excluding zero.
pub fn interval_op(
    op: Op,
    x: &Interval,
    y: &Interval,
    budget: &mut Budget,
) -> Result<Option<Interval>> {
    let product = |x: &Interval, y: &Interval, budget: &mut Budget| -> Result<Interval> {
        Ok(Interval::hull([
            budget.admit(&x.low * &y.low)?,
            budget.admit(&x.low * &y.high)?,
            budget.admit(&x.high * &y.low)?,
            budget.admit(&x.high * &y.high)?,
        ]))
    };
    Ok(Some(match op {
        Op::Add => Interval {
            low: budget.admit(&x.low + &y.low)?,
            high: budget.admit(&x.high + &y.high)?,
        },
        Op::Sub => Interval {
            low: budget.admit(&x.low - &y.high)?,
            high: budget.admit(&x.high - &y.low)?,
        },
        Op::Mul => product(x, y, budget)?,
        Op::Div if y.excludes_zero() => {
            let reciprocal = Interval {
                low: budget.admit(y.high.recip())?,
                high: budget.admit(y.low.recip())?,
            };
            product(x, &reciprocal, budget)?
        }
        Op::Div => return Ok(None),
    }))
}

/// Rewrite rules known to the checker. Each is an identity of rational
/// functions wherever both sides are defined; its side condition makes both
/// sides defined at the same points of `B`, so it may be used in either
/// direction. Names are shared with the proposer; patterns are not.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum Rule {
    AddCommute,
    MulCommute,
    AddAssociate,
    MulAssociate,
    Distribute,
    Factor,
    AddZero,
    AddTypedZero,
    MulZero,
    MulOne,
    SubSelf,
    SubZero,
    SubExpand,
    DivideSelf,
    CancelRight,
    FuseDenominator,
    DivideDivide,
}

/// Pattern over the DAG. `V(i)` binds pattern variable `i`; repeated uses
/// must bind the same hash-consed node.
enum Pat {
    V(usize),
    Lit(i8),
    Op(Op, &'static Pat, &'static Pat),
}
/// Domain side condition on a bound pattern variable.
#[derive(Clone, Copy)]
enum Condition {
    None,
    /// Defined everywhere on `B` (it may be dropped from the formula).
    Total(usize),
    /// Defined everywhere on `B` and its enclosure excludes zero (it may be
    /// cancelled as a denominator).
    TotalNonzero(usize),
}

const A: Pat = Pat::V(0);
const B: Pat = Pat::V(1);
const C: Pat = Pat::V(2);
const ZERO: Pat = Pat::Lit(0);
const ONE: Pat = Pat::Lit(1);
const MINUS_ONE: Pat = Pat::Lit(-1);

impl Rule {
    pub const ALL: [Rule; 17] = [
        Rule::AddCommute,
        Rule::MulCommute,
        Rule::AddAssociate,
        Rule::MulAssociate,
        Rule::Distribute,
        Rule::Factor,
        Rule::AddZero,
        Rule::AddTypedZero,
        Rule::MulZero,
        Rule::MulOne,
        Rule::SubSelf,
        Rule::SubZero,
        Rule::SubExpand,
        Rule::DivideSelf,
        Rule::CancelRight,
        Rule::FuseDenominator,
        Rule::DivideDivide,
    ];

    pub fn name(self) -> &'static str {
        match self {
            Rule::AddCommute => "add-commute",
            Rule::MulCommute => "mul-commute",
            Rule::AddAssociate => "add-associate",
            Rule::MulAssociate => "mul-associate",
            Rule::Distribute => "distribute",
            Rule::Factor => "factor",
            Rule::AddZero => "add-zero",
            Rule::AddTypedZero => "add-typed-zero",
            Rule::MulZero => "mul-zero",
            Rule::MulOne => "mul-one",
            Rule::SubSelf => "sub-self",
            Rule::SubZero => "sub-zero",
            Rule::SubExpand => "sub-expand",
            Rule::DivideSelf => "divide-self",
            Rule::CancelRight => "cancel-right",
            Rule::FuseDenominator => "fuse-denominator",
            Rule::DivideDivide => "divide-divide",
        }
    }

    pub fn from_name(name: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|rule| rule.name() == name)
    }

    // Domain notes use dom(t) for the points where t is defined.
    fn shape(self) -> (&'static Pat, &'static Pat, Condition) {
        use Op::*;
        use Pat::Op as P;
        match self {
            // Same subterms on both sides, no new division: same domain.
            Rule::AddCommute => (&P(Add, &A, &B), &P(Add, &B, &A), Condition::None),
            Rule::MulCommute => (&P(Mul, &A, &B), &P(Mul, &B, &A), Condition::None),
            Rule::AddAssociate => (
                &P(Add, &P(Add, &A, &B), &C),
                &P(Add, &A, &P(Add, &B, &C)),
                Condition::None,
            ),
            Rule::MulAssociate => (
                &P(Mul, &P(Mul, &A, &B), &C),
                &P(Mul, &A, &P(Mul, &B, &C)),
                Condition::None,
            ),
            Rule::Distribute => (
                &P(Mul, &A, &P(Add, &B, &C)),
                &P(Add, &P(Mul, &A, &B), &P(Mul, &A, &C)),
                Condition::None,
            ),
            Rule::Factor => (
                &P(Add, &P(Mul, &A, &B), &P(Mul, &A, &C)),
                &P(Mul, &A, &P(Add, &B, &C)),
                Condition::None,
            ),
            // The literal zero has no units, so `a` is dimensionless here.
            Rule::AddZero => (&P(Add, &A, &ZERO), &A, Condition::None),
            // Drops b: only if b is defined throughout B.
            Rule::AddTypedZero => (&P(Add, &A, &P(Mul, &ZERO, &B)), &A, Condition::Total(1)),
            // Drops a: only if a is defined throughout B. The generic
            // dimension check rejects this step unless a is dimensionless.
            Rule::MulZero => (&P(Mul, &A, &ZERO), &ZERO, Condition::Total(0)),
            Rule::MulOne => (&P(Mul, &A, &ONE), &A, Condition::None),
            // Keeps a, so the zero keeps a's units and a's domain.
            Rule::SubSelf => (&P(Sub, &A, &A), &P(Mul, &ZERO, &A), Condition::None),
            Rule::SubZero => (&P(Sub, &A, &ZERO), &A, Condition::None),
            Rule::SubExpand => (
                &P(Sub, &A, &B),
                &P(Add, &A, &P(Mul, &MINUS_ONE, &B)),
                Condition::None,
            ),
            // Removes a denominator: only if it is defined and nonzero on B.
            Rule::DivideSelf => (&P(Div, &A, &A), &ONE, Condition::TotalNonzero(0)),
            Rule::CancelRight => (&P(Div, &P(Mul, &A, &B), &B), &A, Condition::TotalNonzero(1)),
            // Keeps the denominator d: dom is dom(a)∩dom(b)∩dom(d)∩{d≠0} on both sides.
            Rule::FuseDenominator => (
                &P(Add, &P(Div, &A, &C), &P(Div, &B, &C)),
                &P(Div, &P(Add, &A, &B), &C),
                Condition::None,
            ),
            // {b≠0}∩{c≠0} = {b·c≠0} over the rationals.
            Rule::DivideDivide => (
                &P(Div, &P(Div, &A, &B), &C),
                &P(Div, &A, &P(Mul, &B, &C)),
                Condition::None,
            ),
        }
    }
}

const PATTERN_VARS: usize = 3;
type Subst = [Option<NodeId>; PATTERN_VARS];

fn bind(dag: &Dag, pattern: &Pat, id: NodeId, subst: &mut Subst) -> Result<bool> {
    Ok(match (pattern, dag.node(id)?) {
        (Pat::V(i), _) => match subst[*i] {
            Some(bound) => bound == id,
            None => {
                subst[*i] = Some(id);
                true
            }
        },
        (Pat::Lit(n), Node::Lit(q)) => *q == Q::from_integer(BigInt::from(*n)),
        (Pat::Op(op, pa, pb), Node::Op(nop, a, b)) if op == nop => {
            let (a, b) = (*a, *b);
            bind(dag, pa, a, subst)? && bind(dag, pb, b, subst)?
        }
        _ => false,
    })
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Reason {
    /// `left == right`.
    Reflexive,
    /// One rule instance at the root: `left` matches the rule's left side and
    /// `right` its right side (swapped when `reverse`), with its condition.
    Rule { rule: Rule, reverse: bool },
    /// Same operator at the root; earlier steps relate the two children pairs.
    Congruence { left: usize, right: usize },
    /// Earlier steps `first: left = m` and `second: m = right`.
    Transitive { first: usize, second: usize },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Step {
    pub left: NodeId,
    pub right: NodeId,
    pub reason: Reason,
}

/// A topologically ordered equality derivation. Steps cite only earlier steps.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Certificate {
    pub steps: Vec<Step>,
}

/// A replayed certificate together with the premises it was checked under.
/// It can only be evaluated against those same premises.
pub struct Checked<'a> {
    dag: &'a Dag,
    premises: Premises,
    facts: Vec<Fact>,
    original: NodeId,
    selected: NodeId,
    rules: BTreeMap<Rule, usize>,
    steps: usize,
}

/// Independent replay. Every step's terms must be DAG nodes with equal
/// dimensions; every rule step is re-matched here and its condition is
/// recomputed from the caller's bounds; no term may contain a denominator
/// whose enclosure on `B` is exactly zero; the last step must relate
/// `original` to `selected`.
pub fn replay<'a>(
    dag: &'a Dag,
    premises: &Premises,
    original: NodeId,
    selected: NodeId,
    certificate: &Certificate,
    limits: &Limits,
) -> Result<Checked<'a>> {
    let steps = &certificate.steps;
    if steps.len() > limits.proof_steps {
        return Err(Error::Limit("proof steps"));
    }
    let mut budget = Budget::new(limits);
    let facts = facts(dag, premises, &mut budget)?;
    let mut endpoints = vec![original, selected];
    let mut rules = BTreeMap::new();
    for (index, step) in steps.iter().enumerate() {
        endpoints.push(step.left);
        endpoints.push(step.right);
        if dag.dimension(step.left)? != dag.dimension(step.right)? {
            return Err(Error::Check("step changes dimension"));
        }
        let earlier = |i: usize| -> Result<&Step> {
            if i >= index {
                return Err(Error::Check("step cites a later or same step"));
            }
            Ok(&steps[i])
        };
        let valid = match &step.reason {
            Reason::Reflexive => step.left == step.right,
            Reason::Transitive { first, second } => {
                let (p, q) = (earlier(*first)?, earlier(*second)?);
                p.left == step.left && p.right == q.left && q.right == step.right
            }
            Reason::Congruence { left, right } => {
                let (p, q) = (earlier(*left)?, earlier(*right)?);
                match (dag.node(step.left)?, dag.node(step.right)?) {
                    (Node::Op(o1, a, b), Node::Op(o2, c, d)) => {
                        o1 == o2 && (p.left, p.right, q.left, q.right) == (*a, *c, *b, *d)
                    }
                    _ => false,
                }
            }
            Reason::Rule { rule, reverse } => {
                *rules.entry(*rule).or_insert(0) += 1;
                let (lhs, rhs, condition) = rule.shape();
                let (first, second) = if *reverse { (rhs, lhs) } else { (lhs, rhs) };
                let mut subst: Subst = [None; PATTERN_VARS];
                bind(dag, first, step.left, &mut subst)?
                    && bind(dag, second, step.right, &mut subst)?
                    && match condition {
                        Condition::None => true,
                        Condition::Total(v) => subst[v].is_some_and(|id| facts[id].total),
                        Condition::TotalNonzero(v) => subst[v].is_some_and(|id| {
                            facts[id].total
                                && facts[id]
                                    .interval
                                    .as_ref()
                                    .is_some_and(Interval::excludes_zero)
                        }),
                    }
            }
        };
        if !valid {
            return Err(Error::Check("certificate step does not replay"));
        }
    }
    match steps.last() {
        Some(last) if (last.left, last.right) == (original, selected) => {}
        None if original == selected => {}
        _ => {
            return Err(Error::Check(
                "certificate does not conclude original = selected",
            ))
        }
    }
    for id in dag.reachable(&endpoints)? {
        if let Node::Op(Op::Div, _, b) = dag.node(id)? {
            let zero = Interval {
                low: Q::zero(),
                high: Q::zero(),
            };
            if facts[*b].interval.as_ref() == Some(&zero) {
                return Err(Error::Check("a denominator is zero throughout the bounds"));
            }
        }
    }
    Ok(Checked {
        dag,
        premises: premises.clone(),
        facts,
        original,
        selected,
        rules,
        steps: steps.len(),
    })
}

/// One denominator of the original formula.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Obligation {
    pub denominator: NodeId,
    /// The denominator is defined and nonzero at every point of `B`.
    pub nonzero_within_bounds: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Evaluation {
    Value(Q),
    /// The point violates a caller bound; nothing is claimed there.
    OutsideBounds {
        variable: usize,
    },
    /// An original denominator is zero at the point.
    Undefined {
        denominator: NodeId,
    },
}

impl Checked<'_> {
    pub fn original(&self) -> NodeId {
        self.original
    }
    pub fn selected(&self) -> NodeId {
        self.selected
    }
    pub fn steps(&self) -> usize {
        self.steps
    }
    pub fn rules(&self) -> &BTreeMap<Rule, usize> {
        &self.rules
    }
    pub fn premises(&self) -> &Premises {
        &self.premises
    }

    pub fn obligations(&self) -> Result<Vec<Obligation>> {
        Ok(self
            .dag
            .denominators(self.original)?
            .into_iter()
            .map(|d| Obligation {
                denominator: d,
                nonzero_within_bounds: self.facts[d].total
                    && self.facts[d]
                        .interval
                        .as_ref()
                        .is_some_and(Interval::excludes_zero),
            })
            .collect())
    }

    /// Check the bounds at `point`, then only the original denominators not
    /// established nonzero within the bounds (inner ones first), then
    /// evaluate the selected formula. `point` assigns every annotated variable.
    pub fn evaluate(&self, point: &BTreeMap<usize, Q>, limits: &Limits) -> Result<Evaluation> {
        if point.len() != self.dag.variable_count()
            || point.keys().any(|k| *k >= self.dag.variable_count())
        {
            return Err(Error::Invalid(
                "the point must assign every annotated variable exactly once".into(),
            ));
        }
        for (variable, interval) in &self.premises.bounds {
            if !interval.contains(&point[variable]) {
                return Ok(Evaluation::OutsideBounds {
                    variable: *variable,
                });
            }
        }
        let mut budget = Budget::new(limits);
        let mut memo: HashMap<NodeId, Q> = HashMap::new();
        for obligation in self.obligations()? {
            if obligation.nonzero_within_bounds {
                continue;
            }
            let value = self.value(obligation.denominator, point, &mut memo, &mut budget)?;
            if value.is_zero() {
                return Ok(Evaluation::Undefined {
                    denominator: obligation.denominator,
                });
            }
        }
        Ok(Evaluation::Value(self.value(
            self.selected,
            point,
            &mut memo,
            &mut budget,
        )?))
    }

    fn value(
        &self,
        root: NodeId,
        point: &BTreeMap<usize, Q>,
        memo: &mut HashMap<NodeId, Q>,
        budget: &mut Budget,
    ) -> Result<Q> {
        for id in self.dag.reachable(&[root])? {
            if memo.contains_key(&id) {
                continue;
            }
            let value = match self.dag.node(id)? {
                Node::Lit(q) => q.clone(),
                Node::Var(index) => point[index].clone(),
                Node::Op(op, a, b) => {
                    let (x, y) = (&memo[a], &memo[b]);
                    match op {
                        Op::Add => budget.admit(x + y)?,
                        Op::Sub => budget.admit(x - y)?,
                        Op::Mul => budget.admit(x * y)?,
                        Op::Div if y.is_zero() => {
                            // Every denominator here is either an original
                            // obligation already checked nonzero, enclosed
                            // away from zero on B, or (for the selected
                            // formula) zero only where the original is not
                            // defined. Reaching this is a checker defect.
                            return Err(Error::Check("division by zero inside the checked domain"));
                        }
                        Op::Div => budget.admit(x / y)?,
                    }
                }
            };
            memo.insert(id, value);
        }
        Ok(memo[&root].clone())
    }
}
