//! A closed, typed front end for complete KQA programs.
//!
//! This is an executable contract, not a proof of the upstream interpreter.
//! Programs describe data access only: operation names never select host methods.
//! Scalar producers become final projections over a shared entity DAG. No entity
//! IDs or intermediate rows cross the language boundary during compilation.

use crate::value::{ComparisonOp, TypedValue, ValueKind, ValueLimits};
use crate::{Error, Limits, Plan, Result};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
pub enum Operation {
    FindAll,
    Find,
    FilterConcept,
    FilterStr,
    FilterNum,
    FilterYear,
    FilterDate,
    QFilterStr,
    QFilterNum,
    QFilterYear,
    QFilterDate,
    Relate,
    And,
    Or,
    What,
    Count,
    QueryAttr,
    QueryAttrUnderCondition,
    QueryAttrQualifier,
    QueryRelation,
    QueryRelationQualifier,
    SelectBetween,
    SelectAmong,
    VerifyStr,
    VerifyNum,
    VerifyYear,
    VerifyDate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ProgramType {
    Entities,
    Value,
    Answer,
}

/// The upstream wire format. Unknown fields, operations and non-string literals
/// are rejected rather than passed through to Python.
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ProgramStep {
    pub function: Operation,
    pub dependencies: Vec<usize>,
    pub inputs: Vec<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(transparent)]
pub struct Program(pub Vec<ProgramStep>);

/// Discoverable admission contract; this list is also useful to future language
/// parsers, which need not generate or execute Python code.
#[derive(Debug, Clone, Serialize)]
pub struct OperationContract {
    pub operation: Operation,
    pub dependencies: Vec<ProgramType>,
    pub inputs: usize,
    pub output: ProgramType,
    pub supported: bool,
}

const OPERATIONS: [Operation; 27] = [
    Operation::FindAll,
    Operation::Find,
    Operation::FilterConcept,
    Operation::FilterStr,
    Operation::FilterNum,
    Operation::FilterYear,
    Operation::FilterDate,
    Operation::QFilterStr,
    Operation::QFilterNum,
    Operation::QFilterYear,
    Operation::QFilterDate,
    Operation::Relate,
    Operation::And,
    Operation::Or,
    Operation::What,
    Operation::Count,
    Operation::QueryAttr,
    Operation::QueryAttrUnderCondition,
    Operation::QueryAttrQualifier,
    Operation::QueryRelation,
    Operation::QueryRelationQualifier,
    Operation::SelectBetween,
    Operation::SelectAmong,
    Operation::VerifyStr,
    Operation::VerifyNum,
    Operation::VerifyYear,
    Operation::VerifyDate,
];

impl Operation {
    pub fn contract(self) -> OperationContract {
        use Operation::*;
        use ProgramType::{Answer, Entities, Value};
        let (dependencies, inputs, output) = match self {
            FindAll => (vec![], 0, Entities),
            Find => (vec![], 1, Entities),
            FilterConcept => (vec![Entities], 1, Entities),
            FilterStr | QFilterStr | Relate => (vec![Entities], 2, Entities),
            FilterNum | FilterYear | FilterDate | QFilterNum | QFilterYear | QFilterDate => {
                (vec![Entities], 3, Entities)
            }
            And | Or => (vec![Entities, Entities], 0, Entities),
            What | Count => (vec![Entities], 0, Answer),
            QueryAttr => (vec![Entities], 1, Value),
            QueryAttrUnderCondition | QueryAttrQualifier => (vec![Entities], 3, Value),
            QueryRelation => (vec![Entities, Entities], 0, Answer),
            // The shipped implementation takes relation and qualifier, without
            // a direction literal (its module-level prose says otherwise).
            QueryRelationQualifier => (vec![Entities, Entities], 2, Value),
            SelectBetween => (vec![Entities, Entities], 2, Answer),
            SelectAmong => (vec![Entities], 2, Answer),
            VerifyStr => (vec![Value], 1, Answer),
            VerifyNum | VerifyYear | VerifyDate => (vec![Value], 2, Answer),
        };
        OperationContract {
            operation: self,
            dependencies,
            inputs,
            output,
            supported: true,
        }
    }

    fn literal_kind(self) -> Option<ValueKind> {
        use Operation::*;
        match self {
            FilterStr | QFilterStr | VerifyStr => Some(ValueKind::String),
            FilterNum | QFilterNum | VerifyNum => Some(ValueKind::Quantity),
            FilterYear | QFilterYear | VerifyYear => Some(ValueKind::Year),
            FilterDate | QFilterDate | VerifyDate => Some(ValueKind::Date),
            _ => None,
        }
    }
}

pub fn operation_catalog() -> Vec<OperationContract> {
    OPERATIONS.iter().map(|op| op.contract()).collect()
}

fn invalid(index: usize, op: Operation, message: &str) -> Error {
    Error::Invalid(format!("program step {index} {op:?}: {message}"))
}

fn operator(text: &str) -> Result<ComparisonOp> {
    // KQA admits only these four operators. The native value layer can expose
    // additional operators without silently extending this upstream language.
    match text {
        "=" => Ok(ComparisonOp::Eq),
        "!=" => Ok(ComparisonOp::Ne),
        "<" => Ok(ComparisonOp::Lt),
        ">" => Ok(ComparisonOp::Gt),
        _ => Err(Error::Invalid(format!(
            "unsupported KQA comparison {text:?}"
        ))),
    }
}

impl Program {
    pub fn parse(text: &str, limits: &Limits) -> Result<Self> {
        if text.len() > limits.request_bytes {
            return Err(Error::Limit("request bytes"));
        }
        let program: Self = serde_json::from_str(text)?;
        program.validate(limits)?;
        Ok(program)
    }

    /// Validate every step, including dead branches. A malformed operation never
    /// becomes acceptable merely because a later step does not use its result.
    pub fn validate(&self, limits: &Limits) -> Result<()> {
        if self.0.is_empty() || self.0.len() > limits.plan_nodes {
            return Err(Error::Invalid("program dimensions".into()));
        }
        // Programmatic callers receive the same byte bound as wire callers.
        crate::query::encode(self, limits.request_bytes)?;
        let mut types = Vec::with_capacity(self.0.len());
        for (index, step) in self.0.iter().enumerate() {
            let contract = step.function.contract();
            if step.dependencies.len() != contract.dependencies.len()
                || step.inputs.len() != contract.inputs
            {
                return Err(invalid(index, step.function, "dependency or literal arity"));
            }
            for (&dependency, expected) in step.dependencies.iter().zip(&contract.dependencies) {
                if dependency >= index {
                    return Err(invalid(
                        index,
                        step.function,
                        "dependency must precede consumer",
                    ));
                }
                if types[dependency] != *expected {
                    return Err(invalid(index, step.function, "dependency type mismatch"));
                }
            }
            use Operation::*;
            match step.function {
                Relate if !matches!(step.inputs[1].as_str(), "forward" | "backward") => {
                    return Err(invalid(index, step.function, "invalid relation direction"));
                }
                SelectBetween if !matches!(step.inputs[1].as_str(), "greater" | "less") => {
                    return Err(invalid(index, step.function, "expected greater or less"));
                }
                SelectAmong if !matches!(step.inputs[1].as_str(), "largest" | "smallest") => {
                    return Err(invalid(
                        index,
                        step.function,
                        "expected largest or smallest",
                    ));
                }
                _ => {}
            }
            let inferred_literal = match step.function {
                QueryAttrQualifier => Some(&step.inputs[1]),
                QueryAttrUnderCondition => Some(&step.inputs[2]),
                _ => None,
            };
            if inferred_literal
                .is_some_and(|literal| literal.len() > ValueLimits::default().max_text_bytes)
            {
                return Err(invalid(index, step.function, "value literal byte limit"));
            }
            if let Some(kind) = step.function.literal_kind() {
                let verification = matches!(
                    step.function,
                    VerifyStr | VerifyNum | VerifyYear | VerifyDate
                );
                let literal = &step.inputs[usize::from(!verification)];
                TypedValue::parse_literal(literal, kind, &ValueLimits::default())
                    .map_err(|err| invalid(index, step.function, &err.to_string()))?;
                if kind != ValueKind::String {
                    operator(step.inputs.last().expect("arity checked"))
                        .map_err(|err| invalid(index, step.function, &err.to_string()))?;
                }
            }
            types.push(contract.output);
        }
        Ok(())
    }

    /// Compile once, then use the ordinary bounded native evaluator. The result
    /// retains DAG sharing; it contains no source-data-dependent expansion.
    pub fn compile(&self, limits: &Limits) -> Result<Plan> {
        self.validate(limits)?;
        let mut nodes = Vec::<Value>::new();
        let mut lowered = Vec::<Lowered>::with_capacity(self.0.len());
        for step in &self.0 {
            use Operation::*;
            let inputs = &step.inputs;
            // Validation proved every dependency's type and position.
            let entity = |n: usize| lowered[step.dependencies[n]].entity();
            let predicate = |kind: Option<ValueKind>, literal: &str, comparison: &str| json!({"kind":kind,"literal":literal,"comparison":comparison});
            let (node, scalar) = match step.function {
                FindAll => (Some(json!({"op":"all"})), None),
                Find => (Some(json!({"op":"find","name":inputs[0]})), None),
                FilterConcept => (
                    Some(json!({"op":"filter_concept","input":entity(0),"name":inputs[0]})),
                    None,
                ),
                Relate => (
                    Some(
                        json!({"op":"relate","input":entity(0),"predicate":inputs[0],"direction":inputs[1]}),
                    ),
                    None,
                ),
                And | Or => (
                    Some(
                        json!({"op":if step.function == And {"and"} else {"or"},"left":entity(0),"right":entity(1)}),
                    ),
                    None,
                ),
                FilterStr | FilterNum | FilterYear | FilterDate | QFilterStr | QFilterNum
                | QFilterYear | QFilterDate => {
                    let comparison = if inputs.len() == 2 { "=" } else { &inputs[2] };
                    let op = if matches!(
                        step.function,
                        QFilterStr | QFilterNum | QFilterYear | QFilterDate
                    ) {
                        "filter_qualifier"
                    } else {
                        "filter_attribute"
                    };
                    (
                        Some(
                            json!({"op":op,"input":entity(0),"key":inputs[0],"predicate":predicate(step.function.literal_kind(), &inputs[1], comparison)}),
                        ),
                        None,
                    )
                }
                What => (None, Some((entity(0), json!({"kind":"unique_name"})))),
                Count => (None, Some((entity(0), json!({"kind":"count"})))),
                QueryAttr => (
                    None,
                    Some((
                        entity(0),
                        json!({"kind":"unique_attribute","key":inputs[0]}),
                    )),
                ),
                QueryAttrUnderCondition => (
                    None,
                    Some((
                        entity(0),
                        json!({"kind":"unique_attribute","key":inputs[0],"condition":{"key":inputs[1],"predicate":predicate(None, &inputs[2], "=")}}),
                    )),
                ),
                QueryAttrQualifier => (
                    None,
                    Some((
                        entity(0),
                        json!({"kind":"attribute_qualifier","key":inputs[0],"predicate":predicate(None, &inputs[1], "="),"qualifier":inputs[2]}),
                    )),
                ),
                QueryRelation => (
                    None,
                    Some((entity(0), json!({"kind":"relation","target":entity(1)}))),
                ),
                QueryRelationQualifier => (
                    None,
                    Some((
                        entity(0),
                        json!({"kind":"relation_qualifier","target":entity(1),"predicate":inputs[0],"qualifier":inputs[1]}),
                    )),
                ),
                SelectAmong => (
                    None,
                    Some((
                        entity(0),
                        json!({"kind":"select","key":inputs[0],"order":inputs[1]}),
                    )),
                ),
                SelectBetween => (
                    None,
                    Some((
                        entity(0),
                        json!({"kind":"select_between","target":entity(1),"key":inputs[0],"order":if inputs[1] == "greater" {"largest"} else {"smallest"}}),
                    )),
                ),
                VerifyStr | VerifyNum | VerifyYear | VerifyDate => {
                    let Lowered::Scalar { output, projection } = &lowered[step.dependencies[0]]
                    else {
                        unreachable!("validated value dependency")
                    };
                    let comparison = if inputs.len() == 1 { "=" } else { &inputs[1] };
                    (
                        None,
                        Some((
                            *output,
                            json!({"kind":"verify","source":projection,"predicate":predicate(step.function.literal_kind(), &inputs[0], comparison)}),
                        )),
                    )
                }
            };
            if let Some(node) = node {
                let index = nodes.len();
                nodes.push(node);
                lowered.push(Lowered::Entities(index));
            } else {
                let (output, projection) = scalar.expect("exhaustive lowering");
                lowered.push(Lowered::Scalar { output, projection });
            }
        }
        let (output, projection) = match lowered.last().expect("nonempty validated program") {
            Lowered::Entities(output) => (*output, json!({"kind":"entities"})),
            Lowered::Scalar { output, projection } => (*output, projection.clone()),
        };
        // Typed Plan admission remains the single authority for executable DAGs.
        // The translated representation can be larger than its wire request.
        // Bound that internal allocation separately; the original program has
        // already passed the request-byte bound, including programmatic callers.
        let wire = crate::query::encode(
            &json!({"nodes":nodes,"output":output,"projection":projection}),
            limits.materialized_bytes,
        )?;
        let mut translated_limits = limits.clone();
        translated_limits.request_bytes = limits.materialized_bytes;
        Plan::parse(&wire, &translated_limits)
    }
}

enum Lowered {
    Entities(usize),
    Scalar { output: usize, projection: Value },
}

impl Lowered {
    fn entity(&self) -> usize {
        match self {
            Self::Entities(index) => *index,
            Self::Scalar { .. } => unreachable!("validated entity dependency"),
        }
    }
}
