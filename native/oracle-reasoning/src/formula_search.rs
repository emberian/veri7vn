//! Untrusted e-graph proposer for exact rational formulas, plus the hosted
//! operation `algebra.simplify_rational`.
//!
//! egg searches with explanations on. Its explanation for the chosen formula
//! is translated into a `formula::Certificate` and replayed by `formula`,
//! which shares rule names with this file but not patterns or conditions.
//! If translation or replay fails, the original formula is retained and the
//! reply says why. No e-class merge is trusted.

use crate::algebra::Variable;
use crate::dimensions::{Dimension, VariableAnnotation, DIMENSION_ORDER};
use crate::formula::{
    self, enclose, parse_rational, Budget, Certificate, Dag, Evaluation, Interval, Node, NodeId,
    Op, Premises, Reason, Rule, Step, Q,
};
use crate::{Error, Limits, Result};
use egg::{
    define_language, rewrite, Analysis, CostFunction, DidMerge, EGraph, Extractor, Id, Language,
    RecExpr, Rewrite, Runner, Subst, TreeTerm,
};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap};
use std::rc::Rc;
use std::time::{Duration, Instant};

/// Exact rational literal leaf for egg. Parsing is strict and only used by
/// egg's own pattern syntax; requests are parsed by `formula::Dag::parse`.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Literal(pub Q);
impl std::fmt::Display for Literal {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}
impl std::str::FromStr for Literal {
    type Err = String;
    fn from_str(text: &str) -> std::result::Result<Self, Self::Err> {
        if !text.starts_with(|c: char| c.is_ascii_digit() || c == '-') || text == "-" {
            return Err("not a literal".into());
        }
        parse_rational(text, &Limits::default())
            .map(Literal)
            .map_err(|e| e.to_string())
    }
}

define_language! {
    pub enum Term {
        Num(Literal),
        "+" = Add([Id; 2]),
        "-" = Sub([Id; 2]),
        "*" = Mul([Id; 2]),
        "/" = Div([Id; 2]),
        Var(Variable),
    }
}

/// Per-class proposer facts. Merging intersects enclosures: every rule is an
/// equivalence on the caller's box, so all members share values and domain.
/// These facts only steer search; `formula::replay` recomputes its own.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ClassFacts {
    dimension: Option<Dimension>,
    interval: Option<Interval>,
    total: bool,
}

pub struct Facts {
    variables: BTreeMap<Variable, (Dimension, Option<Interval>)>,
    budget: Budget,
}

impl Analysis<Term> for Facts {
    type Data = ClassFacts;

    fn make(egraph: &mut EGraph<Term, Self>, enode: &Term, _id: Id) -> ClassFacts {
        let child = |id: &Id| egraph[*id].data.clone();
        match enode {
            Term::Num(Literal(q)) => ClassFacts {
                dimension: Some(Dimension::DIMENSIONLESS),
                interval: Some(Interval {
                    low: q.clone(),
                    high: q.clone(),
                }),
                total: true,
            },
            Term::Var(name) => {
                let known = egraph.analysis.variables.get(name).cloned();
                ClassFacts {
                    dimension: known.as_ref().map(|k| k.0),
                    interval: known.and_then(|k| k.1),
                    total: true,
                }
            }
            Term::Add([a, b]) | Term::Sub([a, b]) | Term::Mul([a, b]) | Term::Div([a, b]) => {
                let (fa, fb) = (child(a), child(b));
                let op = op_of(enode).expect("binary node");
                let dimension = match (fa.dimension, fb.dimension) {
                    (Some(x), Some(y)) => match op {
                        Op::Add | Op::Sub => (x == y).then_some(x),
                        Op::Mul => x.product(y).ok(),
                        Op::Div => x.quotient(y).ok(),
                    },
                    _ => None,
                };
                let excludes = fb.interval.as_ref().is_some_and(Interval::excludes_zero);
                // Budget exhaustion only makes the proposer less informed.
                let interval = enclose(
                    op,
                    fa.interval.as_ref(),
                    fb.interval.as_ref(),
                    &mut egraph.analysis.budget,
                )
                .ok()
                .flatten();
                ClassFacts {
                    dimension,
                    interval,
                    total: fa.total && fb.total && (op != Op::Div || excludes),
                }
            }
        }
    }

    fn merge(&mut self, a: &mut ClassFacts, b: ClassFacts) -> DidMerge {
        let before = a.clone();
        if a.dimension.is_none() {
            a.dimension = b.dimension;
        }
        a.total |= b.total;
        a.interval = match (a.interval.take(), b.interval.clone()) {
            (Some(x), Some(y)) => {
                let low = x.low.clone().max(y.low.clone());
                let high = x.high.clone().min(y.high.clone());
                Some(if low <= high {
                    Interval { low, high }
                } else {
                    x
                })
            }
            (x, y) => x.or(y),
        };
        DidMerge(*a != before, *a != b)
    }
}

fn op_of(node: &Term) -> Option<Op> {
    Some(match node {
        Term::Add(_) => Op::Add,
        Term::Sub(_) => Op::Sub,
        Term::Mul(_) => Op::Mul,
        Term::Div(_) => Op::Div,
        _ => return None,
    })
}

type Graph = EGraph<Term, Facts>;

fn class(egraph: &Graph, subst: &Subst, var: &str) -> ClassFacts {
    egraph[subst[var.parse().expect("pattern variable")]]
        .data
        .clone()
}
fn total(var: &'static str) -> impl Fn(&mut Graph, Id, &Subst) -> bool {
    move |egraph, _, subst| class(egraph, subst, var).total
}
fn total_dimensionless(var: &'static str) -> impl Fn(&mut Graph, Id, &Subst) -> bool {
    move |egraph, _, subst| {
        let facts = class(egraph, subst, var);
        facts.total && facts.dimension == Some(Dimension::DIMENSIONLESS)
    }
}
fn total_nonzero(var: &'static str) -> impl Fn(&mut Graph, Id, &Subst) -> bool {
    move |egraph, _, subst| {
        let facts = class(egraph, subst, var);
        facts.total && facts.interval.as_ref().is_some_and(Interval::excludes_zero)
    }
}

/// Proposer rules. Names must be checker rule names (tested); the patterns
/// and gates here are the proposer's own and are not trusted.
pub fn rules() -> Vec<Rewrite<Term, Facts>> {
    vec![
        rewrite!("add-commute"; "(+ ?a ?b)" => "(+ ?b ?a)"),
        rewrite!("mul-commute"; "(* ?a ?b)" => "(* ?b ?a)"),
        rewrite!("add-associate"; "(+ (+ ?a ?b) ?c)" => "(+ ?a (+ ?b ?c))"),
        rewrite!("mul-associate"; "(* (* ?a ?b) ?c)" => "(* ?a (* ?b ?c))"),
        rewrite!("distribute"; "(* ?a (+ ?b ?c))" => "(+ (* ?a ?b) (* ?a ?c))"),
        rewrite!("factor"; "(+ (* ?a ?b) (* ?a ?c))" => "(* ?a (+ ?b ?c))"),
        rewrite!("add-zero"; "(+ ?a 0)" => "?a"),
        rewrite!("add-typed-zero"; "(+ ?a (* 0 ?b))" => "?a" if total("?b")),
        rewrite!("mul-zero"; "(* ?a 0)" => "0" if total_dimensionless("?a")),
        rewrite!("mul-one"; "(* ?a 1)" => "?a"),
        rewrite!("sub-self"; "(- ?a ?a)" => "(* 0 ?a)"),
        rewrite!("sub-zero"; "(- ?a 0)" => "?a"),
        rewrite!("sub-expand"; "(- ?a ?b)" => "(+ ?a (* -1 ?b))"),
        rewrite!("divide-self"; "(/ ?a ?a)" => "1" if total_nonzero("?a")),
        rewrite!("cancel-right"; "(/ (* ?a ?b) ?b)" => "?a" if total_nonzero("?b")),
        rewrite!("fuse-denominator"; "(+ (/ ?a ?d) (/ ?b ?d))" => "(/ (+ ?a ?b) ?d)"),
        rewrite!("divide-divide"; "(/ (/ ?a ?b) ?c)" => "(/ ?a (* ?b ?c))"),
    ]
}

/// Same abstract tree cost as `Dag::tree_cost`; nodes whose dimension the
/// proposer cannot establish are never extracted.
struct FormulaCost<'a> {
    egraph: &'a Graph,
}
impl CostFunction<Term> for FormulaCost<'_> {
    type Cost = u128;
    fn cost<C>(&mut self, node: &Term, mut child: C) -> u128
    where
        C: FnMut(Id) -> u128,
    {
        if let Some(op) = op_of(node) {
            let [a, b] = [node.children()[0], node.children()[1]];
            let (da, db) = (self.egraph[a].data.dimension, self.egraph[b].data.dimension);
            let typed = match (da, db) {
                (Some(x), Some(y)) => match op {
                    Op::Add | Op::Sub => x == y,
                    Op::Mul => x.product(y).is_ok(),
                    Op::Div => x.quotient(y).is_ok(),
                },
                _ => false,
            };
            if !typed {
                return u128::MAX;
            }
        }
        let own: u128 = match node {
            Term::Div(_) => 8,
            Term::Mul(_) => 4,
            _ => 1,
        };
        node.children()
            .iter()
            .fold(own, |total, &id| total.saturating_add(child(id)))
    }
}

fn to_recexpr(dag: &Dag, root: NodeId) -> Result<RecExpr<Term>> {
    let mut expr = RecExpr::default();
    let mut ids: HashMap<NodeId, Id> = HashMap::new();
    for id in dag.reachable(&[root])? {
        let term = match dag.node(id)? {
            Node::Lit(q) => Term::Num(Literal(q.clone())),
            Node::Var(index) => Term::Var(
                dag.variable_name(*index)
                    .ok_or(Error::Check("unknown variable index"))?
                    .clone(),
            ),
            Node::Op(op, a, b) => {
                let children = [ids[a], ids[b]];
                match op {
                    Op::Add => Term::Add(children),
                    Op::Sub => Term::Sub(children),
                    Op::Mul => Term::Mul(children),
                    Op::Div => Term::Div(children),
                }
            }
        };
        ids.insert(id, expr.add(term));
    }
    Ok(expr)
}

fn term_node(dag: &mut Dag, node: &Term, children: &[NodeId]) -> Result<NodeId> {
    match node {
        Term::Num(Literal(q)) => dag.literal(q.clone()),
        Term::Var(name) => dag.variable(&name.to_string()),
        _ => {
            let op = op_of(node).expect("binary node");
            match children {
                [a, b] => dag.op(op, *a, *b),
                _ => Err(Error::Check("explanation node arity")),
            }
        }
    }
}

fn recexpr_node(dag: &mut Dag, expr: &RecExpr<Term>) -> Result<NodeId> {
    let mut ids: Vec<NodeId> = Vec::with_capacity(expr.as_ref().len());
    for node in expr.as_ref() {
        let children: Vec<NodeId> = node
            .children()
            .iter()
            .map(|c| ids[usize::from(*c)])
            .collect();
        ids.push(term_node(dag, node, &children)?);
    }
    ids.last().copied().ok_or(Error::Check("empty extraction"))
}

struct Builder {
    steps: Vec<Step>,
    reflexive: HashMap<NodeId, usize>,
}
impl Builder {
    fn push(
        &mut self,
        left: NodeId,
        right: NodeId,
        reason: Reason,
        limits: &Limits,
    ) -> Result<usize> {
        if self.steps.len() >= limits.proof_steps {
            return Err(Error::Limit("proof steps"));
        }
        self.steps.push(Step {
            left,
            right,
            reason,
        });
        Ok(self.steps.len() - 1)
    }
    fn refl(&mut self, id: NodeId, limits: &Limits) -> Result<usize> {
        if let Some(i) = self.reflexive.get(&id) {
            return Ok(*i);
        }
        let i = self.push(id, id, Reason::Reflexive, limits)?;
        self.reflexive.insert(id, i);
        Ok(i)
    }
    fn trans(&mut self, first: usize, second: usize, limits: &Limits) -> Result<usize> {
        let (left, middle, right) = (
            self.steps[first].left,
            self.steps[first].right,
            self.steps[second].right,
        );
        if middle == left {
            return Ok(second);
        }
        if middle == right {
            return Ok(first);
        }
        self.push(left, right, Reason::Transitive { first, second }, limits)
    }
}

/// Initial term, final term and the step proving them equal.
type Proved = (NodeId, NodeId, usize);

/// One explanation sequence: each later term starts either where the previous
/// one ended or from it by the one root rewrite the later term carries.
fn sequence(
    builder: &mut Builder,
    memo: &HashMap<*const TreeTerm<Term>, Proved>,
    terms: &[Rc<TreeTerm<Term>>],
    limits: &Limits,
) -> Result<Proved> {
    let first = terms
        .first()
        .ok_or(Error::Check("empty explanation sequence"))?;
    let (start, mut current, mut proof) = memo[&Rc::as_ptr(first)];
    for term in &terms[1..] {
        let (initial, last, inner) = memo[&Rc::as_ptr(term)];
        let rule = match (&term.forward_rule, &term.backward_rule) {
            (Some(r), None) => Some((r.to_string(), false)),
            (None, Some(r)) => Some((r.to_string(), true)),
            // No rule: this term starts where the previous one ended.
            (None, None) if initial == current => None,
            _ => return Err(Error::Check("explanation terms do not connect")),
        };
        if let Some((name, reverse)) = rule {
            let rule =
                Rule::from_name(&name).ok_or(Error::Check("explanation names an unknown rule"))?;
            let step = builder.push(current, initial, Reason::Rule { rule, reverse }, limits)?;
            proof = builder.trans(proof, step, limits)?;
        }
        proof = builder.trans(proof, inner, limits)?;
        current = last;
    }
    Ok((start, current, proof))
}

/// Translate egg's shared tree explanation into a checker certificate:
/// each tree term is a congruence over its children's proof sequences, and
/// each sequence joins terms by one named rule at the root. Shared subtrees
/// are translated once. Iterative, so term depth cannot exhaust the stack.
fn certificate(
    dag: &mut Dag,
    explanation: &[Rc<TreeTerm<Term>>],
    limits: &Limits,
) -> Result<(NodeId, NodeId, Certificate)> {
    let mut builder = Builder {
        steps: Vec::new(),
        reflexive: HashMap::new(),
    };
    let mut memo: HashMap<*const TreeTerm<Term>, Proved> = HashMap::new();
    let mut stack: Vec<(&Rc<TreeTerm<Term>>, bool)> =
        explanation.iter().rev().map(|t| (t, false)).collect();
    while let Some((term, expanded)) = stack.pop() {
        let key = Rc::as_ptr(term);
        if memo.contains_key(&key) {
            continue;
        }
        if !expanded {
            stack.push((term, true));
            for child in term.child_proofs.iter().flatten() {
                if !memo.contains_key(&Rc::as_ptr(child)) {
                    stack.push((child, false));
                }
            }
            continue;
        }
        let children = term
            .child_proofs
            .iter()
            .map(|proof| sequence(&mut builder, &memo, proof, limits))
            .collect::<Result<Vec<_>>>()?;
        let initial: Vec<NodeId> = children.iter().map(|c| c.0).collect();
        let last: Vec<NodeId> = children.iter().map(|c| c.1).collect();
        let initial = term_node(dag, &term.node, &initial)?;
        let last = term_node(dag, &term.node, &last)?;
        let proof = match children.as_slice() {
            [] => builder.refl(initial, limits)?,
            [_, _] if initial == last => builder.refl(initial, limits)?,
            [a, b] => builder.push(
                initial,
                last,
                Reason::Congruence {
                    left: a.2,
                    right: b.2,
                },
                limits,
            )?,
            _ => return Err(Error::Check("explanation node arity")),
        };
        memo.insert(key, (initial, last, proof));
    }
    let (start, end, _) = sequence(&mut builder, &memo, explanation, limits)?;
    Ok((
        start,
        end,
        Certificate {
            steps: builder.steps,
        },
    ))
}

/// One point value, as exact rational text in coherent SI units.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PointValue {
    pub name: String,
    pub value: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RationalInput {
    pub expression: String,
    pub variables: Vec<VariableAnnotation>,
    #[serde(default)]
    pub bounds: Vec<formula::BoundInput>,
    #[serde(default)]
    pub output_dimension: Option<Dimension>,
    #[serde(default)]
    pub point: Option<Vec<PointValue>>,
}

#[derive(Debug, Serialize)]
pub struct ObligationReply {
    pub denominator: String,
    pub status: &'static str,
}

#[derive(Debug, Serialize)]
pub struct RuleCount {
    pub rule: Rule,
    pub count: usize,
}

#[derive(Debug, Serialize)]
pub struct EvaluationReply {
    pub status: &'static str,
    pub value: Option<String>,
    pub detail: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct RationalReply {
    pub schema: &'static str,
    pub expression: String,
    pub original_cost: u128,
    pub selected_cost: u128,
    pub cost_model: &'static str,
    pub output_dimension: Dimension,
    pub dimension_order: [&'static str; 7],
    pub domain_obligations: Vec<ObligationReply>,
    pub certificate_steps: usize,
    pub rules_used: Vec<RuleCount>,
    pub selection_fallback: Option<String>,
    pub search_stop: String,
    pub iterations: usize,
    pub egraph_nodes: usize,
    pub evaluation: Option<EvaluationReply>,
    pub check: &'static str,
    pub search_us: u128,
    pub check_us: u128,
}

struct Proposal {
    certificate: Certificate,
    selected: NodeId,
    /// Why the original was retained, when a candidate could not be certified.
    declined: Option<String>,
    stop: String,
    iterations: usize,
    egraph_nodes: usize,
}

/// Run egg and translate its explanation. Never fails: anything the
/// proposer cannot certify retains the original formula with a reason.
fn propose(
    dag: &mut Dag,
    premises: &Premises,
    original: NodeId,
    limits: &Limits,
    context: Option<&oracle_execution::ExecutionContext>,
) -> Proposal {
    let mut proposal = Proposal {
        certificate: Certificate::default(),
        selected: original,
        declined: None,
        stop: String::from("not run"),
        iterations: 0,
        egraph_nodes: 0,
    };
    if let Err(why) = search(dag, premises, original, limits, &mut proposal, context) {
        proposal.certificate = Certificate::default();
        proposal.selected = original;
        proposal.declined = Some(why.to_string());
    }
    proposal
}

fn search(
    dag: &mut Dag,
    premises: &Premises,
    original: NodeId,
    limits: &Limits,
    proposal: &mut Proposal,
    context: Option<&oracle_execution::ExecutionContext>,
) -> Result<()> {
    let mut variables = BTreeMap::new();
    for index in 0..dag.variable_count() {
        let name = dag
            .variable_name(index)
            .ok_or(Error::Check("unknown variable index"))?
            .clone();
        let id = dag.variable(&name.to_string())?;
        variables.insert(name, (dag.dimension(id)?, premises.bound(index).cloned()));
    }
    let expr = to_recexpr(dag, original)?;
    let analysis = Facts {
        variables,
        budget: Budget::controlled(limits, context),
    };
    let hook_context = context.cloned();
    let mut runner = Runner::<Term, Facts>::new(analysis)
        .with_explanations_enabled()
        .with_expr(&expr)
        .with_node_limit(limits.egraph_nodes)
        .with_iter_limit(limits.iterations)
        .with_time_limit(Duration::from_millis(limits.search_ms))
        .with_hook(move |_| {
            hook_context
                .as_ref()
                .map_or(Ok(()), |c| crate::checkpoint(c, 1))
                .map_err(|e| e.to_string())
        })
        .run(&rules());
    proposal.stop = format!("{:?}", runner.stop_reason);
    proposal.iterations = runner.iterations.len();
    proposal.egraph_nodes = runner.egraph.total_size();
    let (_, best) = Extractor::new(
        &runner.egraph,
        FormulaCost {
            egraph: &runner.egraph,
        },
    )
    .find_best(runner.roots[0]);
    let selected = recexpr_node(dag, &best)?;
    if selected == original || dag.tree_cost(selected)? >= dag.tree_cost(original)? {
        return Ok(());
    }
    let explanation = runner.explain_equivalence(&expr, &best);
    if explanation.get_tree_size() > (limits.proof_steps as u64).into() {
        return Err(Error::Limit("proof steps"));
    }
    let (start, end, certificate) = certificate(dag, &explanation.explanation_trees, limits)?;
    if start != original || end != selected {
        return Err(Error::Check(
            "explanation endpoints differ from original and selection",
        ));
    }
    proposal.certificate = certificate;
    proposal.selected = selected;
    Ok(())
}

/// Admit, search, replay, and optionally evaluate at one point.
pub fn simplify(input: &RationalInput, limits: &Limits) -> Result<RationalReply> {
    simplify_controlled(input, limits, None)
}
pub fn simplify_controlled(
    input: &RationalInput,
    limits: &Limits,
    context: Option<&oracle_execution::ExecutionContext>,
) -> Result<RationalReply> {
    if let Some(context) = context {
        crate::checkpoint(context, 1)?;
    }
    let mut dag = Dag::new(&input.variables, limits)?;
    let original = dag.parse(&input.expression, limits)?;
    let used = dag.variables_used(original)?;
    for index in 0..dag.variable_count() {
        if !used.contains(&index) {
            return Err(Error::Invalid(format!(
                "unused dimension annotation for {}",
                dag.variable_name(index).expect("index in range")
            )));
        }
    }
    let output_dimension = dag.dimension(original)?;
    if let Some(expected) = input.output_dimension {
        if expected != output_dimension {
            return Err(Error::Invalid(format!(
                "output dimension {output_dimension} does not match requested {expected}"
            )));
        }
    }
    let premises = Premises::new(&dag, &input.bounds, limits)?;
    let point = match &input.point {
        None => None,
        Some(values) => {
            let mut point = BTreeMap::new();
            for value in values {
                let index = dag.variable_index(&value.name).ok_or_else(|| {
                    Error::Invalid(format!(
                        "point names an unannotated variable {}",
                        value.name
                    ))
                })?;
                if point
                    .insert(index, parse_rational(&value.value, limits)?)
                    .is_some()
                {
                    return Err(Error::Invalid(format!(
                        "duplicate point value for {}",
                        value.name
                    )));
                }
            }
            Some(point)
        }
    };
    // The original alone must replay (reflexivity) before any search; this
    // also refuses a denominator that is zero throughout the bounds.
    formula::replay_controlled(
        &dag,
        &premises,
        original,
        original,
        &Certificate::default(),
        limits,
        context,
    )
    .map_err(|e| match e {
        Error::Check(why) => Error::Invalid(format!("original formula refused: {why}")),
        other => other,
    })?;

    let search_started = Instant::now();
    let proposal = propose(&mut dag, &premises, original, limits, context);
    if let Some(context) = context {
        crate::checkpoint(context, 1)?;
    }
    let mut fallback = proposal
        .declined
        .as_ref()
        .map(|why| format!("retained original: proposal could not be certified: {why}"));
    let search_us = search_started.elapsed().as_micros();
    let check_started = Instant::now();
    let replayed = formula::replay_controlled(
        &dag,
        &premises,
        original,
        proposal.selected,
        &proposal.certificate,
        limits,
        context,
    );
    let checked = match replayed {
        Ok(checked) => checked,
        Err(error) => {
            fallback = Some(format!(
                "retained original: proposed certificate failed replay: {error}"
            ));
            formula::replay_controlled(
                &dag,
                &premises,
                original,
                original,
                &Certificate::default(),
                limits,
                context,
            )?
        }
    };
    let check_us = check_started.elapsed().as_micros();
    let domain_obligations = checked
        .obligations()?
        .into_iter()
        .map(|o| {
            Ok(ObligationReply {
                denominator: dag.render(o.denominator)?,
                status: if o.nonzero_within_bounds {
                    "nonzero_within_bounds"
                } else {
                    "not_established"
                },
            })
        })
        .collect::<Result<Vec<_>>>()?;
    let evaluation = match &point {
        None => None,
        Some(point) => Some(match checked.evaluate_controlled(point, limits, context)? {
            Evaluation::Value(q) => EvaluationReply {
                status: "value",
                value: Some(q.to_string()),
                detail: None,
            },
            Evaluation::OutsideBounds { variable } => EvaluationReply {
                status: "outside_bounds",
                value: None,
                detail: Some(format!(
                    "{} lies outside its supplied bound; nothing is claimed at this point",
                    dag.variable_name(variable).expect("index in range")
                )),
            },
            Evaluation::Undefined { denominator } => EvaluationReply {
                status: "undefined",
                value: None,
                detail: Some(format!(
                    "original denominator {} is zero at this point",
                    dag.render(denominator)?
                )),
            },
        }),
    };
    Ok(RationalReply {
        schema: "oracle-rational-formula-v1",
        expression: dag.render(checked.selected())?,
        original_cost: dag.tree_cost(original)?,
        selected_cost: dag.tree_cost(checked.selected())?,
        cost_model: "tree cost: divide=8, multiply=4, other nodes=1; not measured runtime or global optimality",
        output_dimension,
        dimension_order: DIMENSION_ORDER,
        domain_obligations,
        certificate_steps: checked.steps(),
        rules_used: checked
            .rules()
            .iter()
            .map(|(rule, count)| RuleCount {
                rule: *rule,
                count: *count,
            })
            .collect(),
        selection_fallback: fallback,
        search_stop: proposal.stop,
        iterations: proposal.iterations,
        egraph_nodes: proposal.egraph_nodes,
        evaluation,
        check: "certificate replayed in Rust: on the supplied closed bounds the selected and original formulas have the same domain and agree there; not an Isabelle proof",
        search_us,
        check_us,
    })
}

/// Hosted entry point: the serialized reply is capped by `formula_reply_bytes`.
pub fn simplify_json(input: &RationalInput, limits: &Limits) -> Result<String> {
    let reply = serde_json::to_string(&simplify(input, limits)?)?;
    if reply.len() > limits.formula_reply_bytes {
        return Err(Error::Limit("formula reply bytes"));
    }
    Ok(reply)
}
