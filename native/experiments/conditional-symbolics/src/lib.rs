//! Uncompiled exploratory Rust checker, not an Isabelle theorem or trusted kernel.
//! Exact rational, linear SI quantities only. No floating point or affine units.
use num_rational::BigRational as Q;
use num_traits::{One, Zero};
use std::collections::BTreeMap;

pub type Id = usize;
pub type Dim = [i16; 7];
pub const SCALAR: Dim = [0; 7];
pub type Result<T> = std::result::Result<T, &'static str>;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Node {
    Constant(Q, Dim),
    Variable(String, Dim),
    Add(Id, Id),
    Mul(Id, Id),
    Div(Id, Id),
}

/// Append-only, hash-consed DAG. Private storage prevents forward edges and
/// changing an admitted node. A modest cap bounds this exploratory interface.
#[derive(Default, Debug)]
pub struct Dag {
    nodes: Vec<Node>,
    intern: BTreeMap<Node, Id>,
    dimensions: Vec<Dim>,
}
impl Dag {
    pub fn node(&self, id: Id) -> Result<&Node> {
        self.nodes.get(id).ok_or("unknown node")
    }
    pub fn dimension(&self, id: Id) -> Result<Dim> {
        self.dimensions.get(id).copied().ok_or("unknown node")
    }
    pub fn put(&mut self, node: Node) -> Result<Id> {
        if let Some(id) = self.intern.get(&node) {
            return Ok(*id);
        }
        if self.nodes.len() >= 4096 {
            return Err("DAG cap");
        }
        let dim = match &node {
            Node::Constant(_, d) | Node::Variable(_, d) => {
                if d.iter().any(|e| !(-64..=64).contains(e)) {
                    return Err("dimension cap");
                }
                *d
            }
            Node::Add(a, b) => {
                let d = self.dimension(*a)?;
                if d != self.dimension(*b)? {
                    return Err("addition dimension mismatch");
                }
                d
            }
            Node::Mul(a, b) | Node::Div(a, b) => {
                let a_dim = self.dimension(*a)?;
                let b_dim = self.dimension(*b)?;
                let sign = if matches!(&node, Node::Div(..)) {
                    -1
                } else {
                    1
                };
                let mut d = SCALAR;
                for i in 0..7 {
                    d[i] = a_dim[i]
                        .checked_add(sign * b_dim[i])
                        .ok_or("dimension overflow")?;
                    if !(-64..=64).contains(&d[i]) {
                        return Err("dimension cap");
                    }
                }
                d
            }
        };
        // Same variable name cannot acquire a second type.
        if let Node::Variable(name, d) = &node {
            if self
                .nodes
                .iter()
                .any(|n| matches!(n, Node::Variable(other, od) if name == other && d != od))
            {
                return Err("conflicting variable type");
            }
        }
        let id = self.nodes.len();
        self.dimensions.push(dim);
        self.nodes.push(node.clone());
        self.intern.insert(node, id);
        Ok(id)
    }
    pub fn one(&mut self) -> Result<Id> {
        self.put(Node::Constant(Q::one(), SCALAR))
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Bound {
    pub variable: Id,
    pub low: Q,
    pub high: Q,
    pub source: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    pub revision: String,
    pub bounds: Vec<Bound>,
}
impl Snapshot {
    pub fn admit(&self, dag: &Dag) -> Result<()> {
        if self.bounds.len() > 256 {
            return Err("assumption cap");
        }
        let mut seen = BTreeMap::new();
        for b in &self.bounds {
            if !matches!(dag.node(b.variable)?, Node::Variable(..)) || b.low > b.high {
                return Err("bad interval assumption");
            }
            if b.source.is_empty() || seen.insert(b.variable, ()).is_some() {
                return Err("missing source or duplicate interval");
            }
        }
        Ok(())
    }
}

// Conservative exact interval signs. Products and quotients combine signs;
// addition is deliberately omitted. Unknown never counts as nonzero.
#[derive(Clone, Copy)]
enum Sign {
    Positive,
    Negative,
    Unknown,
}
fn sign(dag: &Dag, id: Id, snapshot: &Snapshot, memo: &mut BTreeMap<Id, Sign>) -> Result<Sign> {
    if let Some(s) = memo.get(&id) {
        return Ok(*s);
    }
    let s = match dag.node(id)? {
        Node::Constant(q, _) => {
            if q > &Q::zero() {
                Sign::Positive
            } else if q < &Q::zero() {
                Sign::Negative
            } else {
                Sign::Unknown
            }
        }
        Node::Variable(..) => snapshot
            .bounds
            .iter()
            .find(|b| b.variable == id)
            .map(|b| {
                if b.low > Q::zero() {
                    Sign::Positive
                } else if b.high < Q::zero() {
                    Sign::Negative
                } else {
                    Sign::Unknown
                }
            })
            .unwrap_or(Sign::Unknown),
        Node::Mul(a, b) | Node::Div(a, b) => match (
            sign(dag, *a, snapshot, memo)?,
            sign(dag, *b, snapshot, memo)?,
        ) {
            (Sign::Positive, Sign::Positive) | (Sign::Negative, Sign::Negative) => Sign::Positive,
            (Sign::Negative, Sign::Positive) | (Sign::Positive, Sign::Negative) => Sign::Negative,
            _ => Sign::Unknown,
        },
        _ => Sign::Unknown,
    };
    memo.insert(id, s);
    Ok(s)
}
fn nonzero(dag: &Dag, id: Id, snapshot: &Snapshot) -> Result<bool> {
    Ok(!matches!(
        sign(dag, id, snapshot, &mut BTreeMap::new())?,
        Sign::Unknown
    ))
}

/// A transcript is a topologically ordered list of equality judgements. Child
/// indices refer only to earlier judgements, never unchecked proposed equalities.
#[derive(Clone, Debug)]
pub enum Rule {
    Same,
    Congruence(usize, usize),
    SelfDivide,
    CancelRight,
    FuseDenominator,
}
#[derive(Clone, Debug)]
pub struct Step {
    pub left: Id,
    pub right: Id,
    pub rule: Rule,
}
#[derive(Clone, Debug)]
pub struct Certificate {
    pub snapshot: Snapshot,
    pub steps: Vec<Step>,
}
#[derive(Clone, Debug)]
pub struct Checked<'a> {
    dag: &'a Dag,
    original: Id,
    selected: Id,
    snapshot: Snapshot,
}

/// Independent replay: does not invoke a search procedure or trust its metadata.
/// Each local identity must preserve the dimension and its original domain.
pub fn replay<'a>(
    dag: &'a Dag,
    original: Id,
    selected: Id,
    cert: &Certificate,
    current: &Snapshot,
) -> Result<Checked<'a>> {
    current.admit(dag)?;
    if &cert.snapshot != current {
        return Err("stale assumption snapshot");
    }
    if cert.steps.is_empty() || cert.steps.len() > 8192 {
        return Err("certificate cap");
    }
    for (index, s) in cert.steps.iter().enumerate() {
        if dag.dimension(s.left)? != dag.dimension(s.right)? {
            return Err("rewrite dimension mismatch");
        }
        let left = dag.node(s.left)?;
        let right = dag.node(s.right)?;
        let valid = match &s.rule {
            Rule::Same => s.left == s.right,
            Rule::Congruence(i, j) => {
                if *i >= index || *j >= index {
                    return Err("forward proof reference");
                }
                let p = &cert.steps[*i];
                let q = &cert.steps[*j];
                match (left, right) {
                    (Node::Add(a, b), Node::Add(c, d))
                    | (Node::Mul(a, b), Node::Mul(c, d))
                    | (Node::Div(a, b), Node::Div(c, d)) => {
                        (*a, *b, *c, *d) == (p.left, q.left, p.right, q.right)
                    }
                    _ => false,
                }
            }
            Rule::SelfDivide => match (left, right) {
                (Node::Div(a, b), Node::Constant(q, d)) => {
                    a == b && q.is_one() && *d == SCALAR && nonzero(dag, *b, current)?
                }
                _ => false,
            },
            Rule::CancelRight => match left {
                Node::Div(product, b) => match dag.node(*product)? {
                    Node::Mul(a, factor) => {
                        factor == b && *a == s.right && nonzero(dag, *b, current)?
                    }
                    _ => false,
                },
                _ => false,
            },
            Rule::FuseDenominator => match (left, right) {
                (Node::Add(x, y), Node::Div(sum, d)) => {
                    match (dag.node(*x)?, dag.node(*y)?, dag.node(*sum)?) {
                        (Node::Div(a, b), Node::Div(c, e), Node::Add(f, g)) => {
                            a == f && c == g && b == e && b == d
                        }
                        _ => false,
                    }
                }
                _ => false,
            },
        };
        if !valid {
            return Err("invalid rewrite step");
        }
    }
    let last = cert.steps.last().ok_or("empty certificate")?;
    if (last.left, last.right) != (original, selected) {
        return Err("wrong certificate conclusion");
    }
    Ok(Checked {
        dag,
        original,
        selected,
        snapshot: current.clone(),
    })
}

/// Evaluate each reachable DAG node once. Original-domain validation is retained
/// even for a selected constant, so no cancellation hides a singular point.
fn evaluate(
    dag: &Dag,
    id: Id,
    inputs: &BTreeMap<String, Q>,
    memo: &mut BTreeMap<Id, Q>,
) -> Result<Q> {
    if let Some(q) = memo.get(&id) {
        return Ok(q.clone());
    }
    let q = match dag.node(id)? {
        Node::Constant(q, _) => q.clone(),
        Node::Variable(name, _) => inputs.get(name).cloned().ok_or("missing input")?,
        Node::Add(a, b) => evaluate(dag, *a, inputs, memo)? + evaluate(dag, *b, inputs, memo)?,
        Node::Mul(a, b) => evaluate(dag, *a, inputs, memo)? * evaluate(dag, *b, inputs, memo)?,
        Node::Div(a, b) => {
            let a = evaluate(dag, *a, inputs, memo)?;
            let b = evaluate(dag, *b, inputs, memo)?;
            if b.is_zero() {
                return Err("original or selected singular point");
            }
            a / b
        }
    };
    memo.insert(id, q.clone());
    Ok(q)
}
impl Checked<'_> {
    pub fn evaluate(&self, current: &Snapshot, inputs: &BTreeMap<String, Q>) -> Result<Q> {
        let dag = self.dag;
        if current != &self.snapshot {
            return Err("stale assumption snapshot");
        }
        let mut memo = BTreeMap::new();
        for b in &current.bounds {
            let q = evaluate(dag, b.variable, inputs, &mut memo)?;
            if q < b.low || q > b.high {
                return Err("input outside assumption interval");
            }
        }
        evaluate(dag, self.original, inputs, &mut memo)?;
        evaluate(dag, self.selected, inputs, &mut memo)
    }
}

/// Deliberately small, untrusted proposer. It chooses a single useful root
/// rewrite; replay must be called before consumers receive an executable handle.
/// Larger planners can author congruence transcripts without enlarging replay.
pub fn propose(dag: &mut Dag, root: Id, snapshot: &Snapshot) -> Result<(Id, Certificate)> {
    snapshot.admit(dag)?;
    let (selected, rule) = match dag.node(root)?.clone() {
        Node::Div(a, b) if a == b && nonzero(dag, b, snapshot)? => (dag.one()?, Rule::SelfDivide),
        Node::Div(a, b) if nonzero(dag, b, snapshot)? => match dag.node(a)?.clone() {
            Node::Mul(x, factor) if factor == b => (x, Rule::CancelRight),
            _ => (root, Rule::Same),
        },
        Node::Add(a, b) => match (dag.node(a)?.clone(), dag.node(b)?.clone()) {
            (Node::Div(x, d), Node::Div(y, e)) if d == e => {
                let sum = dag.put(Node::Add(x, y))?;
                (dag.put(Node::Div(sum, d))?, Rule::FuseDenominator)
            }
            _ => (root, Rule::Same),
        },
        _ => (root, Rule::Same),
    };
    Ok((
        selected,
        Certificate {
            snapshot: snapshot.clone(),
            steps: vec![Step {
                left: root,
                right: selected,
                rule,
            }],
        },
    ))
}
