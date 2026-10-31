//! A closed, typed front end for complete KQA programs.
//!
//! This is an executable contract, not a proof of the upstream interpreter.
//! Programs describe data access only: operation names never select host methods.
//! Scalar producers become final projections over a shared entity DAG. No entity
//! IDs or intermediate rows cross the language boundary during compilation.

use crate::query::{Node, Projection, QualifierCondition, SelectionOrder, ValuePredicate};
use crate::value::{ComparisonOp, TypedValue, ValueKind, ValueLimits};
use crate::{Error, Limits, Plan, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Deserialize, Serialize)]
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
#[derive(Debug, Clone, PartialEq, Eq, Hash, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ProgramStep {
    pub function: Operation,
    pub dependencies: Vec<usize>,
    pub inputs: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Deserialize, Serialize)]
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
        crate::query::encoded_size(self, limits.request_bytes)?;
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
        self.compile_validated(limits)
    }

    /// This path is private: callers must first validate the complete program,
    /// including branches that are not dependencies of the final projection.
    fn compile_validated(&self, limits: &Limits) -> Result<Plan> {
        let mut nodes = Vec::new();
        let mut lowered = Vec::<Lowered>::with_capacity(self.0.len());
        for step in &self.0 {
            use Operation::*;
            let inputs = &step.inputs;
            let entity = |n: usize| lowered[step.dependencies[n]].entity();
            let predicate = |kind, literal: &str, comparison: &str| -> Result<ValuePredicate> {
                Ok(ValuePredicate {
                    kind,
                    literal: literal.to_owned(),
                    comparison: operator(comparison)?,
                })
            };
            let (node, scalar) = match step.function {
                FindAll => (Some(Node::All), None),
                Find => (
                    Some(Node::Find {
                        name: inputs[0].clone(),
                    }),
                    None,
                ),
                FilterConcept => (
                    Some(Node::FilterConcept {
                        input: entity(0),
                        name: inputs[0].clone(),
                    }),
                    None,
                ),
                Relate => (
                    Some(Node::Relate {
                        input: entity(0),
                        predicate: inputs[0].clone(),
                        direction: inputs[1].clone(),
                    }),
                    None,
                ),
                And => (
                    Some(Node::And {
                        left: entity(0),
                        right: entity(1),
                    }),
                    None,
                ),
                Or => (
                    Some(Node::Or {
                        left: entity(0),
                        right: entity(1),
                    }),
                    None,
                ),
                FilterStr | FilterNum | FilterYear | FilterDate | QFilterStr | QFilterNum
                | QFilterYear | QFilterDate => {
                    let comparison = if inputs.len() == 2 { "=" } else { &inputs[2] };
                    let predicate =
                        predicate(step.function.literal_kind(), &inputs[1], comparison)?;
                    let input = entity(0);
                    let key = inputs[0].clone();
                    let node = if matches!(
                        step.function,
                        QFilterStr | QFilterNum | QFilterYear | QFilterDate
                    ) {
                        Node::FilterQualifier {
                            input,
                            key,
                            predicate,
                        }
                    } else {
                        Node::FilterAttribute {
                            input,
                            key,
                            predicate,
                        }
                    };
                    (Some(node), None)
                }
                What => (None, Some((entity(0), Projection::UniqueName))),
                Count => (None, Some((entity(0), Projection::Count))),
                QueryAttr => (
                    None,
                    Some((
                        entity(0),
                        Projection::UniqueAttribute {
                            key: inputs[0].clone(),
                            condition: None,
                        },
                    )),
                ),
                QueryAttrUnderCondition => (
                    None,
                    Some((
                        entity(0),
                        Projection::UniqueAttribute {
                            key: inputs[0].clone(),
                            condition: Some(QualifierCondition {
                                key: inputs[1].clone(),
                                predicate: predicate(None, &inputs[2], "=")?,
                            }),
                        },
                    )),
                ),
                QueryAttrQualifier => (
                    None,
                    Some((
                        entity(0),
                        Projection::AttributeQualifier {
                            key: inputs[0].clone(),
                            predicate: predicate(None, &inputs[1], "=")?,
                            qualifier: inputs[2].clone(),
                        },
                    )),
                ),
                QueryRelation => (
                    None,
                    Some((
                        entity(0),
                        Projection::Relation {
                            target: entity(1),
                            direction: None,
                        },
                    )),
                ),
                QueryRelationQualifier => (
                    None,
                    Some((
                        entity(0),
                        Projection::RelationQualifier {
                            target: entity(1),
                            predicate: inputs[0].clone(),
                            direction: None,
                            qualifier: inputs[1].clone(),
                        },
                    )),
                ),
                SelectAmong => (
                    None,
                    Some((
                        entity(0),
                        Projection::Select {
                            key: inputs[0].clone(),
                            order: if inputs[1] == "largest" {
                                SelectionOrder::Largest
                            } else {
                                SelectionOrder::Smallest
                            },
                        },
                    )),
                ),
                SelectBetween => (
                    None,
                    Some((
                        entity(0),
                        Projection::SelectBetween {
                            target: entity(1),
                            key: inputs[0].clone(),
                            order: if inputs[1] == "greater" {
                                SelectionOrder::Largest
                            } else {
                                SelectionOrder::Smallest
                            },
                        },
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
                            Projection::Verify {
                                source: Box::new(projection.clone()),
                                predicate: predicate(
                                    step.function.literal_kind(),
                                    &inputs[0],
                                    comparison,
                                )?,
                            },
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
            Lowered::Entities(output) => (*output, Projection::Entities),
            Lowered::Scalar { output, projection } => (*output, projection.clone()),
        };
        let plan = Plan {
            nodes,
            output,
            projection,
        };
        // The former lowering omitted these optional null fields. Preserve its
        // exact internal byte boundary while constructing the same typed plan.
        fn omitted_bytes(projection: &Projection) -> usize {
            match projection {
                Projection::UniqueAttribute {
                    condition: None, ..
                } => ",\"condition\":null".len(),
                Projection::Relation {
                    direction: None, ..
                }
                | Projection::RelationQualifier {
                    direction: None, ..
                } => ",\"direction\":null".len(),
                Projection::Verify { source, .. } => omitted_bytes(source),
                _ => 0,
            }
        }
        let omitted = omitted_bytes(&plan.projection);
        crate::query::encoded_size(&plan, limits.materialized_bytes.saturating_add(omitted))?;
        plan.validate(limits)?;
        Ok(plan)
    }

    /// Convert learned syntax without a JSON round trip. This is still untrusted
    /// input: the complete operation contract is checked before compilation.
    pub(crate) fn from_reader(steps: &crate::grammar::Program, limits: &Limits) -> Result<Self> {
        // Preserve the original reader byte admission even for invalid syntax.
        crate::query::encoded_size(steps, limits.request_bytes)?;
        let steps = steps
            .iter()
            .map(|step| {
                let function = Operation::deserialize(serde::de::value::StrDeserializer::<
                    serde::de::value::Error,
                >::new(&step.function))
                .map_err(|e| Error::Invalid(e.to_string()))?;
                let inputs = step
                    .inputs
                    .iter()
                    .map(|v| {
                        v.as_str().map(str::to_owned).ok_or_else(|| {
                            Error::Invalid("program literal must be a string".into())
                        })
                    })
                    .collect::<Result<Vec<_>>>()?;
                Ok(ProgramStep {
                    function,
                    dependencies: step.dependencies.clone(),
                    inputs,
                })
            })
            .collect::<Result<Vec<_>>>()?;
        let program = Self(steps);
        program.validate(limits)?;
        Ok(program)
    }
}

enum Lowered {
    Entities(usize),
    Scalar {
        output: usize,
        projection: Projection,
    },
}

impl Lowered {
    fn entity(&self) -> usize {
        match self {
            Self::Entities(index) => *index,
            Self::Scalar { .. } => unreachable!("validated entity dependency"),
        }
    }
}

#[cfg(test)]
mod typed_reader_tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn reader_conversion_agrees_with_wire_admission() {
        let cases = [
            json!([]),
            json!([{"function":"Find","dependencies":[],"inputs":["α\n\"x"]}]),
            json!([{"function":"Find","inputs":[42]}]),
            json!([{"function":"Find","inputs":[null]}]),
            json!([{"function":"Missing","inputs":[]}]),
            json!([{"function":"What","dependencies":[0],"inputs":[]}]),
            json!([{"function":"FindAll","inputs":[]},{"function":"FilterNum","dependencies":[0],"inputs":["mass","9007199254740993 kilogram","="]}]),
            json!([{"function":"FindAll","inputs":[]},{"function":"FilterDate","dependencies":[0],"inputs":["born","1900-02-29","="]},{"function":"FindAll","inputs":[]}]),
        ];
        for value in cases {
            let syntax: crate::grammar::Program = serde_json::from_value(value).unwrap();
            let wire = serde_json::to_string(&syntax).unwrap();
            for bound in [wire.len().saturating_sub(1), wire.len(), wire.len() + 1] {
                let limits = Limits {
                    request_bytes: bound,
                    ..Limits::default()
                };
                let direct = Program::from_reader(&syntax, &limits);
                let parsed = Program::parse(&wire, &limits);
                assert_eq!(direct.is_ok(), parsed.is_ok(), "{wire}, bound {bound}");
                if let (Ok(direct), Ok(parsed)) = (direct, parsed) {
                    assert_eq!(direct, parsed);
                }
            }
        }
    }

    #[test]
    fn typed_lowering_preserves_original_internal_byte_boundary() {
        for (function, inputs, projection) in [
            (
                "QueryAttr",
                json!(["mass"]),
                json!({"kind":"unique_attribute","key":"mass"}),
            ),
            (
                "QueryAttrUnderCondition",
                json!(["mass", "since", "2000"]),
                json!({"kind":"unique_attribute","key":"mass","condition":{"key":"since","predicate":{"kind":null,"literal":"2000","comparison":"="}}}),
            ),
        ] {
            let wire = json!([
                {"function":"FindAll","dependencies":[],"inputs":[]},
                {"function":function,"dependencies":[0],"inputs":inputs}
            ])
            .to_string();
            let old_lowered =
                json!({"nodes":[{"op":"all"}],"output":0,"projection":projection}).to_string();
            let program = Program::parse(&wire, &Limits::default()).unwrap();
            for (bound, accepted) in [(old_lowered.len() - 1, false), (old_lowered.len(), true)] {
                let limits = Limits {
                    materialized_bytes: bound,
                    ..Limits::default()
                };
                assert_eq!(program.compile(&limits).is_ok(), accepted);
            }
        }
    }

    #[test]
    fn counting_writer_matches_json_byte_length() {
        for value in [json!("α\n\"\\"), json!([1, 2, 3]), json!({"a":null})] {
            let length = serde_json::to_vec(&value).unwrap().len();
            assert_eq!(crate::query::encoded_size(&value, length).unwrap(), length);
            assert!(crate::query::encoded_size(&value, length - 1).is_err());
        }
    }

    #[test]
    fn typed_lowering_retains_dead_nodes_exact_literals_and_qualifier_scope() {
        let program = Program::parse(r#"[
            {"function":"Find","dependencies":[],"inputs":["Unused"]},
            {"function":"Find","dependencies":[],"inputs":["Alice"]},
            {"function":"QueryAttrUnderCondition","dependencies":[1],"inputs":["mass","since","2000"]},
            {"function":"VerifyNum","dependencies":[2],"inputs":["9007199254740993 kilogram","="]}
        ]"#, &Limits::default()).unwrap();
        let plan = program.compile(&Limits::default()).unwrap();
        let expected = json!({
            "nodes":[{"op":"find","name":"Unused"},{"op":"find","name":"Alice"}],
            "output":1,
            "projection":{"kind":"verify", "source":{"kind":"unique_attribute","key":"mass",
                "condition":{"key":"since","predicate":{"kind":null,"literal":"2000","comparison":"="}}},
                "predicate":{"kind":"quantity","literal":"9007199254740993 kilogram","comparison":"="}}
        });
        assert_eq!(serde_json::to_value(&plan).unwrap(), expected);
        let wire = serde_json::to_string(&plan).unwrap();
        let parsed = Plan::parse(&wire, &Limits::default()).unwrap();
        assert_eq!(serde_json::to_value(parsed).unwrap(), expected);
    }
}
