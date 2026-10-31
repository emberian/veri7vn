use crate::value::{string_equality_key, ComparisonOp, TypedValue, ValueKind, ValueLimits};
use crate::{Budget, Error, Limits, Result};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
use std::io::Write;

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
pub enum Node {
    Find {
        name: String,
    },
    All,
    Previous,
    Relate {
        input: usize,
        predicate: String,
        direction: String,
    },
    FilterConcept {
        input: usize,
        name: String,
    },
    FilterAttribute {
        input: usize,
        key: String,
        predicate: ValuePredicate,
    },
    FilterQualifier {
        input: usize,
        key: String,
        predicate: ValuePredicate,
    },
    And {
        left: usize,
        right: usize,
    },
    Or {
        left: usize,
        right: usize,
    },
}

/// A request literal is parsed exactly once per encountered source kind. An omitted
/// kind is useful for KQA operations whose literal is interpreted like its source.
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ValuePredicate {
    #[serde(default)]
    pub kind: Option<ValueKind>,
    pub literal: String,
    #[serde(default)]
    pub comparison: ComparisonOp,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct QualifierCondition {
    pub key: String,
    pub predicate: ValuePredicate,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SelectionOrder {
    Smallest,
    Largest,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Projection {
    Entities,
    Names,
    UniqueName,
    Count,
    Attributes {
        key: String,
    },
    UniqueAttribute {
        key: String,
        #[serde(default)]
        condition: Option<QualifierCondition>,
    },
    AttributeQualifier {
        key: String,
        predicate: ValuePredicate,
        qualifier: String,
    },
    Relation {
        target: usize,
        #[serde(default)]
        direction: Option<String>,
    },
    RelationQualifier {
        target: usize,
        predicate: String,
        #[serde(default)]
        direction: Option<String>,
        qualifier: String,
    },
    Select {
        key: String,
        order: SelectionOrder,
    },
    SelectBetween {
        target: usize,
        key: String,
        order: SelectionOrder,
    },
    Verify {
        source: Box<Projection>,
        predicate: ValuePredicate,
    },
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Plan {
    pub nodes: Vec<Node>,
    pub output: usize,
    pub projection: Projection,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Selection {
    pub ids: BTreeSet<String>,
    pub facts: BTreeSet<Fact>,
    // Omission preserves serialized states and replies produced before attribute
    // evidence existed. Old states deserialize with an empty evidence set.
    #[serde(default, skip_serializing_if = "BTreeSet::is_empty")]
    pub attributes: BTreeSet<AttributeFact>,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Fact {
    pub subject: String,
    pub predicate: String,
    pub direction: String,
    pub object: String,
    /// Canonical JSON kept as bytes/text across native operations; decoded by consumers as needed.
    pub qualifiers_json: String,
}

/// A source attribute statement, separate from relation evidence. Position is
/// source identity: equal values with different qualifier records stay distinct.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct AttributeFact {
    pub subject: String,
    pub key: String,
    pub position: i64,
    pub value_json: String,
    pub qualifiers_json: String,
}

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct QueryResult {
    pub image: String,
    pub coverage: String,
    pub entities: Vec<String>,
    pub facts: Vec<Fact>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub attributes: Vec<AttributeFact>,
    pub value: Value,
}

/// Retained Rust payload accounting. Container allowances intentionally exceed
/// element headers; allocator metadata, SQLite pages and foreign buffers are not
/// measured. Saturation is rejected by the aggregate ledger, never wrapped.
pub(crate) fn json_retained_bytes(value: &Value) -> usize {
    match value {
        Value::String(s) => s.capacity(),
        Value::Array(values) => values.iter().fold(
            values
                .capacity()
                .saturating_mul(std::mem::size_of::<Value>()),
            |n, v| n.saturating_add(json_retained_bytes(v)),
        ),
        Value::Object(values) => values.iter().fold(0usize, |n, (k, v)| {
            n.saturating_add(96)
                .saturating_add(k.capacity())
                .saturating_add(std::mem::size_of::<Value>())
                .saturating_add(json_retained_bytes(v))
        }),
        // arbitrary_precision numbers may own a decimal string internally.
        Value::Number(n) => n.to_string().len(),
        _ => 0,
    }
}
fn fact_retained_bytes(f: &Fact) -> usize {
    [
        &f.subject,
        &f.predicate,
        &f.direction,
        &f.object,
        &f.qualifiers_json,
    ]
    .iter()
    .fold(0usize, |n, s| n.saturating_add(s.capacity()))
}
fn attribute_retained_bytes(f: &AttributeFact) -> usize {
    [&f.subject, &f.key, &f.value_json, &f.qualifiers_json]
        .iter()
        .fold(0usize, |n, s| n.saturating_add(s.capacity()))
}
pub(crate) fn query_retained_bytes(q: &QueryResult) -> usize {
    q.entities
        .iter()
        .fold(
            q.image
                .capacity()
                .saturating_add(q.coverage.capacity())
                .saturating_add(
                    q.entities
                        .capacity()
                        .saturating_mul(std::mem::size_of::<String>()),
                )
                .saturating_add(
                    q.facts
                        .capacity()
                        .saturating_mul(std::mem::size_of::<Fact>()),
                )
                .saturating_add(
                    q.attributes
                        .capacity()
                        .saturating_mul(std::mem::size_of::<AttributeFact>()),
                )
                .saturating_add(json_retained_bytes(&q.value)),
            |n, s| n.saturating_add(s.capacity()),
        )
        .saturating_add(
            q.facts
                .iter()
                .map(fact_retained_bytes)
                .fold(0usize, usize::saturating_add),
        )
        .saturating_add(
            q.attributes
                .iter()
                .map(attribute_retained_bytes)
                .fold(0usize, usize::saturating_add),
        )
}
pub(crate) fn selection_retained_bytes(s: &Selection) -> usize {
    s.ids
        .iter()
        .fold(0usize, |n, id| {
            n.saturating_add(64 + std::mem::size_of::<String>())
                .saturating_add(id.capacity())
        })
        .saturating_add(s.facts.iter().fold(0usize, |n, f| {
            n.saturating_add(64 + std::mem::size_of::<Fact>())
                .saturating_add(fact_retained_bytes(f))
        }))
        .saturating_add(s.attributes.iter().fold(0usize, |n, f| {
            n.saturating_add(64 + std::mem::size_of::<AttributeFact>())
                .saturating_add(attribute_retained_bytes(f))
        }))
}

struct BoundedWriter {
    bytes: Vec<u8>,
    limit: usize,
    exceeded: bool,
}
impl Write for BoundedWriter {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        if bytes.len() > self.limit.saturating_sub(self.bytes.len()) {
            self.exceeded = true;
            return Err(std::io::Error::other("encoded byte limit"));
        }
        self.bytes.extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
pub(crate) fn encode<T: Serialize>(value: &T, limit: usize) -> Result<String> {
    let mut writer = BoundedWriter {
        bytes: Vec::new(),
        limit,
        exceeded: false,
    };
    let result = serde_json::to_writer(&mut writer, value);
    if writer.exceeded {
        return Err(Error::Limit("encoded bytes"));
    }
    result?;
    String::from_utf8(writer.bytes).map_err(|_| Error::Format("invalid encoded UTF-8".into()))
}

/// Count the canonical wire representation without allocating an encoded copy.
/// Uses serde's own escaping/number rules, so byte admission stays exact.
pub(crate) fn encoded_size<T: Serialize>(value: &T, limit: usize) -> Result<usize> {
    struct Counter {
        bytes: usize,
        limit: usize,
        exceeded: bool,
    }
    impl Write for Counter {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            if bytes.len() > self.limit.saturating_sub(self.bytes) {
                self.exceeded = true;
                return Err(std::io::Error::other("encoded byte limit"));
            }
            self.bytes += bytes.len();
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut counter = Counter {
        bytes: 0,
        limit,
        exceeded: false,
    };
    let result = serde_json::to_writer(&mut counter, value);
    if counter.exceeded {
        return Err(Error::Limit("encoded bytes"));
    }
    result?;
    Ok(counter.bytes)
}

impl Plan {
    pub fn parse(text: &str, limits: &Limits) -> Result<Self> {
        if text.len() > limits.request_bytes {
            return Err(Error::Limit("request bytes"));
        }
        let plan: Self = serde_json::from_str(text)?;
        plan.validate(limits)?;
        Ok(plan)
    }

    /// Shared structural admission for wire and checked typed producers.
    pub(crate) fn validate(&self, limits: &Limits) -> Result<()> {
        if self.nodes.is_empty()
            || self.nodes.len() > limits.plan_nodes
            || self.output >= self.nodes.len()
        {
            return Err(Error::Invalid("plan dimensions".into()));
        }
        for (i, node) in self.nodes.iter().enumerate() {
            let deps = match node {
                Node::Relate {
                    input, direction, ..
                } => {
                    if direction != "forward" && direction != "backward" {
                        return Err(Error::Invalid("relation direction".into()));
                    }
                    vec![*input]
                }
                Node::FilterConcept { input, .. } => vec![*input],
                Node::FilterAttribute {
                    input, predicate, ..
                }
                | Node::FilterQualifier {
                    input, predicate, ..
                } => {
                    predicate.validate()?;
                    vec![*input]
                }
                Node::And { left, right } | Node::Or { left, right } => vec![*left, *right],
                _ => vec![],
            };
            if deps.iter().any(|&d| d >= i) {
                return Err(Error::Invalid("dependency must precede consumer".into()));
            }
        }
        self.projection.validate(self.nodes.len(), 0)?;
        Ok(())
    }
}

impl ValuePredicate {
    fn validate(&self) -> Result<()> {
        if let Some(kind) = self.kind {
            TypedValue::parse_literal(&self.literal, kind, &ValueLimits::default())?;
        } else if self.literal.len() > ValueLimits::default().max_text_bytes {
            return Err(Error::Limit("value literal bytes"));
        }
        Ok(())
    }
    fn test(&self, source: &Value, budget: &Budget) -> Result<Option<bool>> {
        PredicateMatcher::new(self).test(source, budget)
    }
}

struct PredicateMatcher<'a> {
    predicate: &'a ValuePredicate,
    literals: Vec<(ValueKind, Option<TypedValue>)>,
}
impl<'a> PredicateMatcher<'a> {
    fn new(predicate: &'a ValuePredicate) -> Self {
        Self {
            predicate,
            literals: Vec::new(),
        }
    }
    fn test(&mut self, source: &Value, budget: &Budget) -> Result<Option<bool>> {
        let predicate = self.predicate;
        // Parsing and exact arithmetic have bounded operands. Charge bytes as
        // well as each row so a large qualifier array cannot hide native work.
        budget.spend(
            serde_json::to_string(source)?.len() as u64 + predicate.literal.len() as u64 + 1,
        )?;
        let limits = ValueLimits::default();
        let source = TypedValue::from_kqa(source, &limits)?;
        self.test_typed(&source)
    }
    fn test_typed(&mut self, source: &TypedValue) -> Result<Option<bool>> {
        let predicate = self.predicate;
        let limits = ValueLimits::default();
        let kind = predicate.kind.unwrap_or_else(|| source.kind());
        let temporal = |kind| matches!(kind, ValueKind::Year | ValueKind::Date);
        if source.kind() != kind && !(temporal(kind) && temporal(source.kind())) {
            return Ok(None);
        }
        if !self.literals.iter().any(|(cached, _)| *cached == kind) {
            let literal = match TypedValue::parse_literal(&predicate.literal, kind, &limits) {
                Ok(value) => Some(value),
                Err(Error::Invalid(_)) if predicate.kind.is_none() => None,
                Err(error) => return Err(error),
            };
            self.literals.push((kind, literal));
        }
        let literal = self
            .literals
            .iter()
            .find(|(cached, _)| *cached == kind)
            .and_then(|(_, literal)| literal.as_ref());
        let Some(literal) = literal else {
            return Ok(None);
        };
        let compared = if matches!(kind, ValueKind::Year) {
            source.compare_at_year(literal)
        } else {
            source.compare(literal)
        };
        Ok(compared.test(predicate.comparison))
    }
}

impl Projection {
    fn dependencies(&self, into: &mut Vec<usize>) {
        match self {
            Self::Relation { target, .. }
            | Self::RelationQualifier { target, .. }
            | Self::SelectBetween { target, .. } => into.push(*target),
            Self::Verify { source, .. } => source.dependencies(into),
            _ => {}
        }
    }
    fn validate(&self, nodes: usize, depth: usize) -> Result<()> {
        if depth > 8 {
            return Err(Error::Invalid("projection nesting".into()));
        }
        match self {
            Self::Relation { target, direction }
            | Self::RelationQualifier {
                target, direction, ..
            } => {
                if *target >= nodes {
                    return Err(Error::Invalid("projection target".into()));
                }
                if direction
                    .as_ref()
                    .is_some_and(|d| d != "forward" && d != "backward")
                {
                    return Err(Error::Invalid("relation direction".into()));
                }
            }
            Self::SelectBetween { target, .. } if *target >= nodes => {
                return Err(Error::Invalid("projection target".into()))
            }
            Self::UniqueAttribute {
                condition: Some(condition),
                ..
            } => condition.predicate.validate()?,
            Self::AttributeQualifier { predicate, .. } => predicate.validate()?,
            Self::Verify { source, predicate } => {
                if !matches!(
                    source.as_ref(),
                    Self::UniqueAttribute { .. }
                        | Self::AttributeQualifier { .. }
                        | Self::RelationQualifier { .. }
                ) {
                    return Err(Error::Invalid(
                        "verification requires a typed value projection".into(),
                    ));
                }
                source.validate(nodes, depth + 1)?;
                predicate.validate()?;
            }
            _ => {}
        }
        Ok(())
    }
}

struct Meter<'a> {
    rows: usize,
    bytes: usize,
    limits: &'a Limits,
    budget: &'a Budget,
}
impl Meter<'_> {
    fn charge(&mut self, bytes: usize) -> Result<()> {
        self.budget.spend(1)?;
        self.rows = self.rows.checked_add(1).ok_or(Error::Limit("rows"))?;
        self.bytes = self
            .bytes
            .checked_add(bytes)
            .ok_or(Error::Limit("materialized bytes"))?;
        if self.rows > self.limits.materialized_rows {
            return Err(Error::Limit("materialized rows"));
        }
        if self.bytes > self.limits.materialized_bytes {
            return Err(Error::Limit("materialized bytes"));
        }
        Ok(())
    }
    fn id(&mut self, set: &mut Selection, id: String) -> Result<()> {
        self.charge(id.len())?;
        set.ids.insert(id);
        Ok(())
    }
    fn attribute(&mut self, set: &mut Selection, attribute: AttributeFact) -> Result<()> {
        self.charge(
            attribute.subject.len()
                + attribute.key.len()
                + attribute.value_json.len()
                + attribute.qualifiers_json.len()
                + 8,
        )?;
        set.attributes.insert(attribute);
        Ok(())
    }
    fn fact(&mut self, set: &mut Selection, fact: Fact) -> Result<()> {
        self.charge(
            fact.subject.len()
                + fact.predicate.len()
                + fact.direction.len()
                + fact.object.len()
                + fact.qualifiers_json.len(),
        )?;
        set.facts.insert(fact);
        Ok(())
    }
}

/// What the consumer of one evaluation needs. Every demand runs the same
/// `compile`: the same stages, the same language guard and the same stage
/// metering. They differ only in what is read from the output stage afterwards.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Demand {
    /// The reply, its entities and statement evidence, and the Selection a
    /// caller may persist as the next turn's Previous.
    Full,
    /// Only whether the output stage holds at least one entity.
    Exists,
    /// Only how many distinct entities the output stage holds.
    #[cfg_attr(
        not(test),
        expect(dead_code, reason = "no production caller asks for a count yet")
    )]
    Count,
}

/// An evaluation shaped by its Demand. Scalar demands fetch no ids, facts or
/// attributes and produce no Selection, so nothing they return can be stored
/// as Previous or shown as evidence.
#[derive(Debug)]
pub(crate) enum Delivered {
    Full(Box<QueryResult>, Selection),
    Exists(bool),
    #[cfg_attr(
        not(test),
        expect(dead_code, reason = "no production caller asks for a count yet")
    )]
    Count(u64),
}
impl Delivered {
    fn into_full(self) -> Result<(QueryResult, Selection)> {
        match self {
            Self::Full(result, selected) => Ok((*result, selected)),
            _ => Err(Error::Format(
                "scalar evaluation where a reply was demanded".into(),
            )),
        }
    }
}

pub(crate) fn evaluate(
    db: &Connection,
    identity: &str,
    plan: &Plan,
    previous: &Selection,
    limits: &Limits,
    budget: &Budget,
) -> Result<(QueryResult, Selection)> {
    evaluate_with_mode(
        db,
        identity,
        plan,
        previous,
        limits,
        budget,
        false,
        None,
        Demand::Full,
    )?
    .ok_or_else(|| Error::Format("unexpected guarded graph evaluation".into()))?
    .into_full()
}

/// R7's language-only admission guard: every entity-producing step is evaluated
/// once, including unused and union branches. Empty intermediates refuse unless
/// the terminal projection is Count. Graph and declared program execution keep
/// their existing final-DAG semantics through `evaluate`.
///
/// A reader may try several candidates on one exclusive lease and budget. Clear
/// its preceding candidate's private node namespace before evaluating another.
/// Cancellation or cleanup errors propagate; the lease still owns unconditional
/// cleanup before the connection can return to the pool.
#[cfg(test)]
pub(crate) fn evaluate_language(
    db: &Connection,
    identity: &str,
    plan: &Plan,
    previous: &Selection,
    limits: &Limits,
    budget: &Budget,
) -> Result<Option<(QueryResult, Selection)>> {
    budget.check()?;
    db.execute_batch("DELETE FROM temp.oracle_sets; DELETE FROM temp.oracle_facts; DELETE FROM temp.oracle_attributes;")?;
    budget.check()?;
    evaluate_with_mode(
        db,
        identity,
        plan,
        previous,
        limits,
        budget,
        true,
        None,
        Demand::Full,
    )?
    .map(Delivered::into_full)
    .transpose()
}

/// One reader request on one exclusive worker, image and previous selection.
/// Keys include complete typed node literals and canonical dependency identities,
/// hence relation/attribute provenance is part of the reusable stage identity.
/// Empty stages are cached too; each candidate still checks all its own stages.
/// The worker lease clears every scratch table on success, refusal or cancellation.
#[derive(Default)]
pub(crate) struct LanguageWorkspace {
    stages: BTreeMap<String, (usize, bool)>,
    retained_rows: usize,
    retained_bytes: usize,
    columns: BTreeMap<(usize, String), AttributeColumn>,
    // Rust stage-key ownership only: SQLite scratch storage is foreign.
    memory: Vec<crate::budget::MemoryReservation>,
}
/// A shared typed source column is indexed independently of any one predicate.
/// Statement positions and qualifiers remain attached to every matching value.
#[derive(Default)]
struct AttributeColumn {
    rows: Vec<(AttributeFact, TypedValue)>,
    strings: BTreeMap<String, Vec<usize>>,
    nonstrings: Vec<usize>,
    memory: Vec<crate::budget::MemoryReservation>,
}
impl LanguageWorkspace {
    pub(crate) fn new(db: &Connection) -> Result<Self> {
        db.execute_batch("DELETE FROM temp.oracle_sets; DELETE FROM temp.oracle_facts; DELETE FROM temp.oracle_attributes;")?;
        Ok(Self::default())
    }
    fn filter_column(
        &mut self,
        db: &Connection,
        input: usize,
        key: &str,
        output: usize,
        predicate: &ValuePredicate,
        meter: &mut Meter<'_>,
    ) -> Result<()> {
        let identity = (input, key.to_string());
        if !self.columns.contains_key(&identity) {
            let mut column = AttributeColumn::default();
            let mut query=db.prepare_cached("SELECT a.subject,a.key,a.position,a.value,a.qualifiers FROM attributes a CROSS JOIN temp.oracle_sets selected ON selected.id=a.subject AND selected.node=?1 WHERE a.key=?2")?;
            let mut rows = query.query(params![input as i64, key])?;
            let mut bytes = key.len().saturating_add(64);
            column
                .memory
                .push(meter.budget.reserve_memory(key.len().saturating_add(256))?);
            while let Some(row) = rows.next()? {
                let attribute = attribute_row(row)?;
                meter.charge(attribute_bytes(&attribute))?;
                meter.budget.spend(attribute.value_json.len() as u64 + 1)?;
                let typed = TypedValue::from_kqa(
                    &serde_json::from_str(&attribute.value_json)?,
                    &ValueLimits::default(),
                )?;
                bytes = bytes
                    .saturating_add(attribute_bytes(&attribute))
                    .saturating_add(attribute.value_json.len())
                    .saturating_add(64);
                if let TypedValue::String(text) = &typed {
                    let equality_key = string_equality_key(text);
                    bytes = bytes.saturating_add(equality_key.len()).saturating_add(32);
                    column
                        .strings
                        .entry(equality_key)
                        .or_default()
                        .push(column.rows.len());
                } else {
                    column.nonstrings.push(column.rows.len());
                }
                if self.retained_bytes.saturating_add(bytes) > meter.limits.materialized_bytes
                    || self.retained_rows.saturating_add(column.rows.len() + 1)
                        > meter.limits.materialized_rows
                {
                    return Err(Error::Limit("language shared attribute column"));
                }
                // Attribute bytes include statement identities and qualifiers.
                // Typed literal/index copies are bounded by a second value copy
                // plus container headers; each row owns exactly one reservation.
                let row_bytes = attribute_retained_bytes(&attribute)
                    .saturating_add(attribute.value_json.len().saturating_mul(2))
                    .saturating_add(256);
                column.memory.push(meter.budget.reserve_memory(row_bytes)?);
                column.rows.push((attribute, typed));
            }
            self.retained_bytes = self.retained_bytes.saturating_add(bytes);
            self.retained_rows = self.retained_rows.saturating_add(column.rows.len());
            self.columns.insert(identity.clone(), column);
        }
        let column = &self.columns[&identity];
        let string_equality = predicate.comparison == ComparisonOp::Eq
            && matches!(predicate.kind, None | Some(ValueKind::String));
        let mut matcher = PredicateMatcher::new(predicate);
        if string_equality {
            // Literal parsing trims whitespace; the shared value-layer key
            // applies the comparator's Unicode lowercasing to both operands.
            // Source whitespace and all statement witnesses remain unchanged.
            meter.budget.spend(predicate.literal.len() as u64 + 1)?;
            if let Some(indices) = column
                .strings
                .get(&string_equality_key(predicate.literal.trim()))
            {
                for index in indices {
                    let attribute = &column.rows[*index].0;
                    insert_id(db, output, &attribute.subject, meter)?;
                    insert_attribute(db, output, attribute)?;
                }
            }
        }
        let mut compare = |index: usize| -> Result<()> {
            let (attribute, typed) = &column.rows[index];
            let wanted = predicate.kind.unwrap_or_else(|| typed.kind());
            let temporal = |kind| matches!(kind, ValueKind::Year | ValueKind::Date);
            if typed.kind() != wanted && !(temporal(wanted) && temporal(typed.kind())) {
                return Ok(());
            }
            meter
                .budget
                .spend(attribute.value_json.len() as u64 + predicate.literal.len() as u64 + 1)?;
            if matcher.test_typed(typed)? == Some(true) {
                insert_id(db, output, &attribute.subject, meter)?;
                insert_attribute(db, output, attribute)?;
            }
            Ok(())
        };
        if string_equality {
            for &index in &column.nonstrings {
                compare(index)?;
            }
        } else {
            for index in 0..column.rows.len() {
                compare(index)?;
            }
        }
        Ok(())
    }
    fn retain(
        &mut self,
        db: &Connection,
        key: String,
        slot: usize,
        nonempty: bool,
        meter: &Meter<'_>,
    ) -> Result<()> {
        let (rows,bytes): (i64,i64) = db.query_row(
            "SELECT sum(n),sum(b) FROM (
             SELECT count(*) n,coalesce(sum(length(CAST(id AS BLOB))),0) b FROM temp.oracle_sets WHERE node=?1
             UNION ALL SELECT count(*),coalesce(sum(length(CAST(subject AS BLOB))+length(CAST(predicate AS BLOB))+length(CAST(direction AS BLOB))+length(CAST(object AS BLOB))+length(CAST(qualifiers AS BLOB))),0) FROM temp.oracle_facts WHERE node=?1
             UNION ALL SELECT count(*),coalesce(sum(length(CAST(subject AS BLOB))+length(CAST(key AS BLOB))+8+length(CAST(value AS BLOB))+length(CAST(qualifiers AS BLOB))),0) FROM temp.oracle_attributes WHERE node=?1)",
            [slot as i64], |row| Ok((row.get(0)?,row.get(1)?)))?;
        let rows = usize::try_from(rows).map_err(|_| Error::Limit("language shared rows"))?;
        let bytes = usize::try_from(bytes).map_err(|_| Error::Limit("language shared bytes"))?;
        self.retained_rows = self.retained_rows.saturating_add(rows);
        self.retained_bytes = self
            .retained_bytes
            .saturating_add(bytes)
            .saturating_add(key.len())
            .saturating_add(64);
        if self.retained_rows > meter.limits.materialized_rows {
            return Err(Error::Limit("language shared rows"));
        }
        if self.retained_bytes > meter.limits.materialized_bytes {
            return Err(Error::Limit("language shared bytes"));
        }
        meter.budget.spend(key.len() as u64 + 1)?;
        self.memory.push(
            meter
                .budget
                .reserve_memory(key.capacity().saturating_add(128))?,
        );
        self.stages.insert(key, (slot, nonempty));
        Ok(())
    }
}
#[allow(clippy::too_many_arguments)]
pub(crate) fn evaluate_language_shared(
    db: &Connection,
    identity: &str,
    plan: &Plan,
    previous: &Selection,
    limits: &Limits,
    budget: &Budget,
    shared: &mut LanguageWorkspace,
) -> Result<Option<(QueryResult, Selection)>> {
    evaluate_language_demand(
        db,
        identity,
        plan,
        previous,
        limits,
        budget,
        shared,
        Demand::Full,
    )?
    .map(Delivered::into_full)
    .transpose()
}

/// `evaluate_language_shared` for a consumer that states what it needs.
/// `None` is the language guard's refusal, exactly as for `Demand::Full`.
#[allow(clippy::too_many_arguments)]
pub(crate) fn evaluate_language_demand(
    db: &Connection,
    identity: &str,
    plan: &Plan,
    previous: &Selection,
    limits: &Limits,
    budget: &Budget,
    shared: &mut LanguageWorkspace,
    demand: Demand,
) -> Result<Option<Delivered>> {
    evaluate_with_mode(
        db,
        identity,
        plan,
        previous,
        limits,
        budget,
        true,
        Some(shared),
        demand,
    )
}

#[allow(clippy::too_many_arguments)]
fn evaluate_with_mode(
    db: &Connection,
    identity: &str,
    plan: &Plan,
    previous: &Selection,
    limits: &Limits,
    budget: &Budget,
    language: bool,
    shared: Option<&mut LanguageWorkspace>,
    demand: Demand,
) -> Result<Option<Delivered>> {
    let mut meter = Meter {
        rows: 0,
        bytes: 0,
        limits,
        budget,
    };
    // Ordinary graph execution preserves SQL pushdown and materializes shared
    // subplans. Language admission materializes every stage exactly once so its
    // intermediate-empty guard cannot be bypassed by dead code or a union.
    let Some(compiled) = compile(db, plan, previous, &mut meter, language, shared)? else {
        return Ok(None);
    };
    // A scalar demand asks SQLite one aggregate over the output stage. In
    // language mode that stage is already a scratch table, so this is an index
    // probe; in graph mode it runs the same pushed-down SQL Full would read.
    let scalar = match demand {
        Demand::Full => None,
        Demand::Exists => Some(format!(
            "{} SELECT EXISTS(SELECT 1 FROM n{})",
            compiled.prefix, plan.output
        )),
        Demand::Count => Some(format!(
            "{} SELECT count(*) FROM (SELECT DISTINCT id FROM n{})",
            compiled.prefix, plan.output
        )),
    };
    if let Some(sql) = scalar {
        budget.spend(1)?;
        let mut stmt = db.prepare_cached(&sql)?;
        let count = stmt.parameter_count();
        let value: i64 = stmt.query_row(
            rusqlite::params_from_iter(compiled.parameters.iter().take(count)),
            |row| row.get(0),
        )?;
        budget.check()?;
        let value = u64::try_from(value).map_err(|_| Error::Format("negative count".into()))?;
        return Ok(Some(if demand == Demand::Exists {
            Delivered::Exists(value != 0)
        } else {
            Delivered::Count(value)
        }));
    }
    let mut selected = Selection::default();
    {
        let sql = format!(
            "{} SELECT id FROM n{} ORDER BY id",
            compiled.prefix, plan.output
        );
        let mut stmt = db.prepare_cached(&sql)?;
        let count = stmt.parameter_count();
        let mut rows = stmt.query(rusqlite::params_from_iter(
            compiled.parameters.iter().take(count),
        ))?;
        while let Some(row) = rows.next()? {
            meter.id(&mut selected, row.get(0)?)?;
        }
    }
    {
        let sql = format!("{} SELECT subject,predicate,direction,object,qualifiers FROM f{} ORDER BY subject,predicate,direction,object,qualifiers",compiled.prefix,plan.output);
        let mut stmt = db.prepare_cached(&sql)?;
        let count = stmt.parameter_count();
        let mut rows = stmt.query(rusqlite::params_from_iter(
            compiled.parameters.iter().take(count),
        ))?;
        while let Some(row) = rows.next()? {
            meter.fact(
                &mut selected,
                Fact {
                    subject: row.get(0)?,
                    predicate: row.get(1)?,
                    direction: row.get(2)?,
                    object: row.get(3)?,
                    qualifiers_json: row.get(4)?,
                },
            )?;
        }
    }
    {
        let sql = format!("{} SELECT subject,key,position,value,qualifiers FROM a{} ORDER BY subject,key,position", compiled.prefix, plan.output);
        let mut stmt = db.prepare_cached(&sql)?;
        let count = stmt.parameter_count();
        let mut rows = stmt.query(rusqlite::params_from_iter(
            compiled.parameters.iter().take(count),
        ))?;
        while let Some(row) = rows.next()? {
            meter.attribute(&mut selected, attribute_row(row)?)?;
        }
    }
    let value = project(db, plan, &compiled, &selected, &plan.projection, &mut meter)?;
    budget.check()?;
    let result = QueryResult {
        image: identity.into(),
        coverage: "complete_relative_to_image".into(),
        entities: selected.ids.iter().cloned().collect(),
        facts: selected.facts.iter().cloned().collect(),
        attributes: selected.attributes.iter().cloned().collect(),
        value,
    };
    Ok(Some(Delivered::Full(Box::new(result), selected)))
}

struct Compiled {
    prefix: String,
    parameters: Vec<String>,
}
fn compile(
    db: &Connection,
    plan: &Plan,
    previous: &Selection,
    meter: &mut Meter<'_>,
    language: bool,
    mut shared: Option<&mut LanguageWorkspace>,
) -> Result<Option<Compiled>> {
    let refuse_empty = language && !matches!(plan.projection, Projection::Count);
    let mut ctes = Vec::new();
    let mut parameters = Vec::new();
    let mut live = vec![language; plan.nodes.len()];
    let mut pending = vec![plan.output];
    plan.projection.dependencies(&mut pending);
    while let Some(index) = pending.pop() {
        if live[index] {
            continue;
        }
        live[index] = true;
        match &plan.nodes[index] {
            Node::Relate { input, .. }
            | Node::FilterConcept { input, .. }
            | Node::FilterAttribute { input, .. }
            | Node::FilterQualifier { input, .. } => pending.push(*input),
            Node::And { left, right } | Node::Or { left, right } => pending.extend([*left, *right]),
            _ => {}
        }
    }
    // Shared subplans must not expand exponentially when the SQL planner inlines
    // CTEs (e.g. repeatedly unioning a result with itself). Keep DAG sharing.
    let mut uses = vec![0usize; plan.nodes.len()];
    for (index, node) in plan.nodes.iter().enumerate() {
        if !live[index] {
            continue;
        }
        match node {
            Node::Relate { input, .. }
            | Node::FilterConcept { input, .. }
            | Node::FilterAttribute { input, .. }
            | Node::FilterQualifier { input, .. } => uses[*input] += 1,
            Node::And { left, right } | Node::Or { left, right } => {
                uses[*left] += 1;
                uses[*right] += 1;
            }
            _ => {}
        }
    }
    let mut slots = vec![0usize; plan.nodes.len()];
    for (i, node) in plan.nodes.iter().enumerate() {
        if !live[i] {
            continue;
        }
        meter.budget.spend(1)?;
        let mut canonical = node.clone();
        match &mut canonical {
            Node::Relate { input, .. }
            | Node::FilterConcept { input, .. }
            | Node::FilterAttribute { input, .. }
            | Node::FilterQualifier { input, .. } => *input = slots[*input],
            Node::And { left, right } | Node::Or { left, right } => {
                *left = slots[*left];
                *right = slots[*right];
            }
            _ => {}
        }
        let key = if shared.is_some() {
            Some(serde_json::to_string(&canonical)?)
        } else {
            None
        };
        if let Some(key) = &key {
            meter.budget.spend(key.len() as u64 + 1)?;
        }

        let slot = if let Some(cache) = shared.as_deref() {
            if let Some(&(slot, nonempty)) = cache.stages.get(key.as_ref().expect("shared key")) {
                slots[i] = slot;
                ctes.push(format!(
                    "n{i}(id) AS (SELECT id FROM temp.oracle_sets WHERE node={slot})"
                ));
                ctes.push(format!(
                    "f{i}(subject,predicate,direction,object,qualifiers) AS ({})",
                    fact_scratch(slot)
                ));
                ctes.push(format!(
                    "a{i}(subject,key,position,value,qualifiers) AS ({})",
                    attribute_scratch(slot)
                ));
                if refuse_empty && !nonempty {
                    return Ok(None);
                }
                continue;
            }
            cache.stages.len()
        } else {
            i
        };
        slots[i] = slot;
        let mut bind = |text: String| {
            parameters.push(text);
            format!("?{}", parameters.len())
        };
        let mut facts = "SELECT '', '', '', '', '' WHERE 0".to_string();
        let mut attributes = "SELECT '', '', 0, '', '' WHERE 0".to_string();
        let mut already_materialized = false;
        let ids = match node {
            Node::Find { name } => {
                format!("SELECT id FROM nodes WHERE name={}", bind(name.clone()))
            }
            Node::All => "SELECT id FROM nodes WHERE kind='entity'".into(),
            Node::Previous => {
                let ids = bind(serde_json::to_string(&previous.ids)?);
                let fs = bind(serde_json::to_string(&previous.facts)?);
                let attrs = bind(serde_json::to_string(&previous.attributes)?);
                attributes = format!("SELECT json_extract(value,'$.subject'),json_extract(value,'$.key'),json_extract(value,'$.position'),json_extract(value,'$.value_json'),json_extract(value,'$.qualifiers_json') FROM json_each({attrs})");
                facts = format!("SELECT json_extract(value,'$.subject'),json_extract(value,'$.predicate'),json_extract(value,'$.direction'),json_extract(value,'$.object'),json_extract(value,'$.qualifiers_json') FROM json_each({fs})");
                format!("SELECT value FROM json_each({ids})")
            }
            Node::Relate {
                input,
                predicate,
                direction,
            } => {
                let pred = bind(predicate.clone());
                let dir = bind(direction.clone());
                let filter=format!("FROM edges WHERE subject IN (SELECT id FROM n{input}) AND predicate={pred} AND direction={dir}");
                facts = format!("SELECT subject,predicate,direction,object,qualifiers {filter}");
                format!("SELECT DISTINCT object {filter}")
            }
            Node::FilterConcept { input, name } => {
                let name = bind(name.clone());
                ctes.push(format!("c{i}(id) AS (SELECT id FROM nodes WHERE kind='concept' AND name={name} UNION SELECT p.child FROM parents p JOIN c{i} ON p.parent=c{i}.id WHERE p.kind='concept')"));
                // Enumerate membership candidates from the typed adjacency index,
                // then test the input set. CROSS JOIN keeps that access order.
                format!("SELECT DISTINCT p.child FROM parents p CROSS JOIN n{input} selected ON selected.id=p.child WHERE p.parent IN (SELECT id FROM c{i}) AND p.kind='entity'")
            }
            Node::FilterAttribute {
                input,
                key,
                predicate,
            } => {
                // Use the attribute key index, then intersect the input set;
                // exact comparisons run in Rust without float coercion in SQL.
                if let Some(cache) = shared.as_deref_mut() {
                    cache.filter_column(db, slots[*input], key, slot, predicate, meter)?;
                } else {
                    let key = bind(key.clone());
                    let sql = format!("{} SELECT a.subject,a.key,a.position,a.value,a.qualifiers FROM attributes a CROSS JOIN n{input} selected ON selected.id=a.subject WHERE a.key={key}", prefix(&ctes));
                    filter_attributes(db, &sql, &parameters, slot, predicate, meter)?;
                }
                attributes = attribute_scratch(slot);
                already_materialized = true;
                format!("SELECT id FROM temp.oracle_sets WHERE node={slot}")
            }
            Node::FilterQualifier {
                input,
                key,
                predicate,
            } => {
                filter_qualifiers(db, &ctes, &parameters, *input, slot, key, predicate, meter)?;
                attributes = attribute_scratch(slot);
                facts = fact_scratch(slot);
                already_materialized = true;
                format!("SELECT id FROM temp.oracle_sets WHERE node={slot}")
            }
            Node::And { left, right } | Node::Or { left, right } => {
                let op = if matches!(node, Node::And { .. }) {
                    "INTERSECT"
                } else {
                    "UNION"
                };
                facts=format!("SELECT * FROM (SELECT * FROM f{left} UNION SELECT * FROM f{right}) WHERE object IN (SELECT id FROM n{i})");
                attributes=format!("SELECT * FROM (SELECT * FROM a{left} UNION SELECT * FROM a{right}) WHERE subject IN (SELECT id FROM n{i})");
                format!("SELECT id FROM n{left} {op} SELECT id FROM n{right}")
            }
        };
        ctes.push(format!("n{i}(id) AS ({ids})"));
        ctes.push(format!(
            "f{i}(subject,predicate,direction,object,qualifiers) AS ({facts})"
        ));
        ctes.push(format!(
            "a{i}(subject,key,position,value,qualifiers) AS ({attributes})"
        ));
        let nonempty = if (uses[i] > 1 || language) && !already_materialized {
            let nonempty = materialize(db, &ctes, &parameters, i, slot, meter)?;
            let n = ctes.len();
            ctes[n - 3] =
                format!("n{i}(id) AS (SELECT id FROM temp.oracle_sets WHERE node={slot})");
            ctes[n - 2] = format!(
                "f{i}(subject,predicate,direction,object,qualifiers) AS ({})",
                fact_scratch(slot)
            );
            ctes[n - 1] = format!(
                "a{i}(subject,key,position,value,qualifiers) AS ({})",
                attribute_scratch(slot)
            );
            Some(nonempty)
        } else if already_materialized && (refuse_empty || shared.is_some()) {
            meter.budget.spend(1)?;
            Some(db.query_row(
                "SELECT EXISTS(SELECT 1 FROM temp.oracle_sets WHERE node=?1)",
                [slot as i64],
                |row| row.get::<_, bool>(0),
            )?)
        } else {
            None
        };
        if let Some(cache) = shared.as_deref_mut() {
            cache.retain(
                db,
                key.expect("shared key"),
                slot,
                nonempty.expect("language materializes each stage"),
                meter,
            )?;
        }
        if refuse_empty && nonempty == Some(false) {
            return Ok(None);
        }
    }
    Ok(Some(Compiled {
        prefix: format!("WITH RECURSIVE {}", ctes.join(",")),
        parameters,
    }))
}

fn materialize(
    db: &Connection,
    ctes: &[String],
    parameters: &[String],
    node: usize,
    slot: usize,
    meter: &mut Meter<'_>,
) -> Result<bool> {
    let prefix = format!("WITH RECURSIVE {}", ctes.join(","));
    let mut nonempty = false;
    {
        let mut query = db.prepare(&format!("{prefix} SELECT id FROM n{node}"))?;
        let count = query.parameter_count();
        let mut rows = query.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
        let mut insert = db.prepare_cached("INSERT INTO temp.oracle_sets VALUES (?1,?2)")?;
        while let Some(row) = rows.next()? {
            let id: String = row.get(0)?;
            meter.charge(id.len())?;
            nonempty = true;
            insert.execute(params![slot as i64, id])?;
        }
    }
    {
        let mut query = db.prepare(&format!(
            "{prefix} SELECT subject,predicate,direction,object,qualifiers FROM f{node}"
        ))?;
        let count = query.parameter_count();
        let mut rows = query.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
        let mut insert =
            db.prepare_cached("INSERT INTO temp.oracle_facts VALUES (?1,?2,?3,?4,?5,?6)")?;
        while let Some(row) = rows.next()? {
            let fields: Vec<String> = (0..5)
                .map(|i| row.get(i))
                .collect::<std::result::Result<_, _>>()?;
            meter.charge(fields.iter().map(String::len).sum())?;
            insert.execute(params![
                slot as i64,
                fields[0],
                fields[1],
                fields[2],
                fields[3],
                fields[4]
            ])?;
        }
    }
    {
        let mut query = db.prepare(&format!(
            "{prefix} SELECT subject,key,position,value,qualifiers FROM a{node}"
        ))?;
        let count = query.parameter_count();
        let mut rows = query.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
        while let Some(row) = rows.next()? {
            let attribute = attribute_row(row)?;
            meter.charge(
                attribute.subject.len()
                    + attribute.key.len()
                    + attribute.value_json.len()
                    + attribute.qualifiers_json.len()
                    + 8,
            )?;
            insert_attribute(db, slot, &attribute)?;
        }
    }
    Ok(nonempty)
}

fn prefix(ctes: &[String]) -> String {
    format!("WITH RECURSIVE {}", ctes.join(","))
}
fn fact_scratch(node: usize) -> String {
    format!("SELECT subject,predicate,direction,object,qualifiers FROM temp.oracle_facts WHERE node={node}")
}
fn attribute_scratch(node: usize) -> String {
    format!("SELECT subject,key,position,value,qualifiers FROM temp.oracle_attributes WHERE node={node}")
}
fn attribute_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<AttributeFact> {
    Ok(AttributeFact {
        subject: row.get(0)?,
        key: row.get(1)?,
        position: row.get(2)?,
        value_json: row.get(3)?,
        qualifiers_json: row.get(4)?,
    })
}
fn attribute_bytes(a: &AttributeFact) -> usize {
    a.subject.len() + a.key.len() + a.value_json.len() + a.qualifiers_json.len() + 8
}
fn attribute_evidence(a: &AttributeFact) -> Result<Value> {
    Ok(
        json!({"subject":a.subject,"key":a.key,"position":a.position,
        "value":serde_json::from_str::<Value>(&a.value_json)?,
        "qualifiers":serde_json::from_str::<Value>(&a.qualifiers_json)?}),
    )
}
fn insert_attribute(db: &Connection, node: usize, a: &AttributeFact) -> Result<()> {
    db.prepare_cached("INSERT OR IGNORE INTO temp.oracle_attributes VALUES (?1,?2,?3,?4,?5,?6)")?
        .execute(params![
            node as i64,
            a.subject,
            a.key,
            a.position,
            a.value_json,
            a.qualifiers_json
        ])?;
    Ok(())
}
fn insert_id(db: &Connection, node: usize, id: &str, meter: &mut Meter<'_>) -> Result<()> {
    meter.charge(id.len())?;
    db.prepare_cached("INSERT OR IGNORE INTO temp.oracle_sets VALUES (?1,?2)")?
        .execute(params![node as i64, id])?;
    Ok(())
}
fn filter_attributes(
    db: &Connection,
    sql: &str,
    parameters: &[String],
    node: usize,
    predicate: &ValuePredicate,
    meter: &mut Meter<'_>,
) -> Result<()> {
    let mut stmt = db.prepare(sql)?;
    let count = stmt.parameter_count();
    let mut rows = stmt.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
    let mut predicate = PredicateMatcher::new(predicate);
    while let Some(row) = rows.next()? {
        let attribute = attribute_row(row)?;
        meter.charge(attribute_bytes(&attribute))?;
        if predicate.test(
            &serde_json::from_str::<Value>(&attribute.value_json)?,
            meter.budget,
        )? == Some(true)
        {
            insert_id(db, node, &attribute.subject, meter)?;
            insert_attribute(db, node, &attribute)?;
        }
    }
    Ok(())
}
fn qualifier_values<'a>(qualifiers: &'a Value, key: &str) -> Result<&'a [Value]> {
    if !qualifiers.is_object() {
        return Err(Error::Invalid("qualifiers must be an object".into()));
    }
    match qualifiers.get(key) {
        None => Ok(&[]),
        Some(Value::Array(values)) => Ok(values),
        _ => Err(Error::Invalid("qualifier values must be an array".into())),
    }
}
fn qualifier_matches(
    text: &str,
    key: &str,
    predicate: &mut PredicateMatcher<'_>,
    budget: &Budget,
) -> Result<bool> {
    budget.spend(text.len() as u64 + 1)?;
    let qualifiers: Value = serde_json::from_str(text)?;
    for value in qualifier_values(&qualifiers, key)? {
        if predicate.test(value, budget)? == Some(true) {
            return Ok(true);
        }
    }
    Ok(false)
}
#[allow(clippy::too_many_arguments)]
fn filter_qualifiers(
    db: &Connection,
    ctes: &[String],
    parameters: &[String],
    input: usize,
    node: usize,
    key: &str,
    predicate: &ValuePredicate,
    meter: &mut Meter<'_>,
) -> Result<()> {
    let prefix = prefix(ctes);
    let mut predicate = PredicateMatcher::new(predicate);
    {
        let mut stmt = db.prepare(&format!(
            "{prefix} SELECT subject,predicate,direction,object,qualifiers FROM f{input}"
        ))?;
        let count = stmt.parameter_count();
        let mut rows = stmt.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
        let mut insert = db
            .prepare_cached("INSERT OR IGNORE INTO temp.oracle_facts VALUES (?1,?2,?3,?4,?5,?6)")?;
        while let Some(row) = rows.next()? {
            let fields: Vec<String> = (0..5)
                .map(|i| row.get(i))
                .collect::<std::result::Result<_, _>>()?;
            meter.charge(fields.iter().map(String::len).sum())?;
            if qualifier_matches(&fields[4], key, &mut predicate, meter.budget)? {
                insert_id(db, node, &fields[3], meter)?;
                insert.execute(params![
                    node as i64,
                    fields[0],
                    fields[1],
                    fields[2],
                    fields[3],
                    fields[4]
                ])?;
            }
        }
    }
    {
        let mut stmt = db.prepare(&format!(
            "{prefix} SELECT subject,key,position,value,qualifiers FROM a{input}"
        ))?;
        let count = stmt.parameter_count();
        let mut rows = stmt.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
        while let Some(row) = rows.next()? {
            let attribute = attribute_row(row)?;
            meter.charge(attribute_bytes(&attribute))?;
            if qualifier_matches(
                &attribute.qualifiers_json,
                key,
                &mut predicate,
                meter.budget,
            )? {
                insert_id(db, node, &attribute.subject, meter)?;
                insert_attribute(db, node, &attribute)?;
            }
        }
    }
    Ok(())
}

/// Uniqueness is over exact typed values, with every supporting statement kept.
/// Equal repeated values are agreement; distinct or incomparable values are an
/// ambiguity, never permission to choose the first source row.
#[derive(Default)]
struct Values {
    distinct: Vec<(TypedValue, Value)>,
    evidence: Vec<Value>,
}
impl Values {
    fn add(&mut self, value: Value, evidence: Value, meter: &mut Meter<'_>) -> Result<()> {
        let typed = TypedValue::from_kqa(&value, &ValueLimits::default())?;
        let mut duplicate = false;
        for (other, _) in &self.distinct {
            meter.budget.spend(1)?;
            if typed.compare(other).test(ComparisonOp::Eq) == Some(true) {
                duplicate = true;
                break;
            }
        }
        meter.charge(serde_json::to_vec(&evidence)?.len() + serde_json::to_vec(&value)?.len())?;
        if !duplicate {
            self.distinct.push((typed, value));
        }
        self.evidence.push(evidence);
        Ok(())
    }
    fn finish(self) -> Value {
        match self.distinct.len() {
            0 => json!({"status":"absent","candidates":0,"evidence":self.evidence}),
            1 => {
                let (typed, value) = self.distinct.into_iter().next().expect("one value");
                json!({"status":"unique","candidate":value,"display":typed.to_string(),"evidence":self.evidence})
            }
            count => json!({"status":"ambiguous","candidates":count,
                "values":self.distinct.into_iter().map(|(_,value)|value).collect::<Vec<_>>(),"evidence":self.evidence}),
        }
    }
}
fn read_attributes(
    db: &Connection,
    ids: &BTreeSet<String>,
    key: &str,
    meter: &mut Meter<'_>,
    mut visit: impl FnMut(AttributeFact, &mut Meter<'_>) -> Result<()>,
) -> Result<()> {
    // One parameterized indexed probe for each selected entity. No full corpus
    // scan, Python callback or source-row rehydration occurs in this path.
    let mut stmt = db.prepare_cached("SELECT subject,key,position,value,qualifiers FROM attributes WHERE subject=?1 AND key=?2 ORDER BY position")?;
    for id in ids {
        meter.budget.spend(1)?;
        let mut rows = stmt.query(params![id, key])?;
        while let Some(row) = rows.next()? {
            let attribute = attribute_row(row)?;
            meter.charge(attribute_bytes(&attribute))?;
            visit(attribute, meter)?;
        }
    }
    Ok(())
}
fn node_ids(
    db: &Connection,
    compiled: &Compiled,
    node: usize,
    meter: &mut Meter<'_>,
) -> Result<BTreeSet<String>> {
    let mut ids = BTreeSet::new();
    let mut stmt = db.prepare(&format!("{} SELECT id FROM n{node}", compiled.prefix))?;
    let count = stmt.parameter_count();
    let mut rows = stmt.query(rusqlite::params_from_iter(
        compiled.parameters.iter().take(count),
    ))?;
    while let Some(row) = rows.next()? {
        let id: String = row.get(0)?;
        meter.charge(id.len())?;
        ids.insert(id);
    }
    Ok(ids)
}
fn project(
    db: &Connection,
    plan: &Plan,
    compiled: &Compiled,
    selected: &Selection,
    projection: &Projection,
    meter: &mut Meter<'_>,
) -> Result<Value> {
    match projection {
        Projection::Entities => Ok(Value::Null),
        Projection::Count => Ok(json!(selected.ids.len())),
        Projection::UniqueName if selected.ids.len() != 1 => Ok(json!({
            "status":if selected.ids.is_empty() {"absent"} else {"ambiguous"},"candidates":selected.ids.len()})),
        Projection::Names | Projection::UniqueName => {
            let mut names = Vec::new();
            let mut stmt = db.prepare_cached("SELECT name FROM nodes WHERE id=?1")?;
            for id in &selected.ids {
                meter.budget.spend(1)?;
                let name: String = stmt.query_row([id], |r| r.get(0))?;
                meter.charge(id.len() + name.len())?;
                names.push(json!({"id":id,"name":name}));
            }
            Ok(if matches!(projection, Projection::UniqueName) {
                json!({"status":"unique","candidate":names[0]})
            } else {
                json!(names)
            })
        }
        Projection::Attributes { key } => {
            let mut attributes = Vec::new();
            read_attributes(db, &selected.ids, key, meter, |a, _| {
                // Preserve this pre-existing projection's exact field contract.
                attributes.push(json!({"subject":a.subject,"key":a.key,
                    "value":serde_json::from_str::<Value>(&a.value_json)?,
                    "qualifiers":serde_json::from_str::<Value>(&a.qualifiers_json)?}));
                Ok(())
            })?;
            Ok(json!(attributes))
        }
        Projection::UniqueAttribute { key, condition } => {
            let mut values = Values::default();
            let mut matcher = condition
                .as_ref()
                .map(|condition| PredicateMatcher::new(&condition.predicate));
            read_attributes(db, &selected.ids, key, meter, |a, meter| {
                if let Some(condition) = condition {
                    if !qualifier_matches(
                        &a.qualifiers_json,
                        &condition.key,
                        matcher.as_mut().expect("condition has a matcher"),
                        meter.budget,
                    )? {
                        return Ok(());
                    }
                }
                values.add(
                    serde_json::from_str(&a.value_json)?,
                    attribute_evidence(&a)?,
                    meter,
                )
            })?;
            Ok(values.finish())
        }
        Projection::AttributeQualifier {
            key,
            predicate,
            qualifier,
        } => {
            let mut values = Values::default();
            let mut predicate = PredicateMatcher::new(predicate);
            read_attributes(db, &selected.ids, key, meter, |a, meter| {
                if predicate.test(&serde_json::from_str::<Value>(&a.value_json)?, meter.budget)?
                    != Some(true)
                {
                    return Ok(());
                }
                let qualifiers: Value = serde_json::from_str(&a.qualifiers_json)?;
                for value in qualifier_values(&qualifiers, qualifier)? {
                    values.add(value.clone(), attribute_evidence(&a)?, meter)?;
                }
                Ok(())
            })?;
            Ok(values.finish())
        }
        Projection::Relation { target, direction }
        | Projection::RelationQualifier {
            target, direction, ..
        } => {
            let mut parameters = compiled.parameters.clone();
            let mut conditions = Vec::new();
            if let Some(direction) = direction {
                parameters.push(direction.clone());
                conditions.push(format!("e.direction=?{}", parameters.len()));
            }
            if let Projection::RelationQualifier { predicate, .. } = projection {
                parameters.push(predicate.clone());
                conditions.push(format!("e.predicate=?{}", parameters.len()));
            }
            let extra = if conditions.is_empty() {
                String::new()
            } else {
                format!(" AND {}", conditions.join(" AND "))
            };
            let sql = format!("{} SELECT e.subject,e.predicate,e.direction,e.object,e.qualifiers FROM edges e WHERE e.subject IN (SELECT id FROM n{}) AND e.object IN (SELECT id FROM n{target}){extra} ORDER BY e.subject,e.predicate,e.direction,e.object,e.qualifiers",compiled.prefix,plan.output);
            let mut stmt = db.prepare(&sql)?;
            let count = stmt.parameter_count();
            let mut rows = stmt.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
            let mut values = Values::default();
            while let Some(row) = rows.next()? {
                let fields: Vec<String> = (0..5)
                    .map(|i| row.get(i))
                    .collect::<std::result::Result<_, _>>()?;
                meter.charge(fields.iter().map(String::len).sum())?;
                let qualifiers: Value = serde_json::from_str(&fields[4])?;
                let evidence = json!({"subject":fields[0],"predicate":fields[1],"direction":fields[2],"object":fields[3],"qualifiers":qualifiers});
                if let Projection::RelationQualifier { qualifier, .. } = projection {
                    for value in qualifier_values(&qualifiers, qualifier)? {
                        values.add(value.clone(), evidence.clone(), meter)?;
                    }
                } else {
                    values.add(json!({"type":"string","value":fields[1]}), evidence, meter)?;
                }
            }
            Ok(values.finish())
        }
        Projection::Verify { source, predicate } => {
            let source = project(db, plan, compiled, selected, source, meter)?;
            if source.get("status").and_then(Value::as_str) != Some("unique") {
                return Ok(source);
            }
            let candidate = source
                .get("candidate")
                .ok_or_else(|| Error::Format("missing value candidate".into()))?;
            Ok(match predicate.test(candidate, meter.budget)? {
                Some(answer) => json!({"status":"verified","answer":answer,"source":source}),
                None => json!({"status":"incomparable","source":source}),
            })
        }
        Projection::Select { key, order } => select(db, &selected.ids, key, *order, meter),
        Projection::SelectBetween { target, key, order } => {
            let target = node_ids(db, compiled, *target, meter)?;
            if selected.ids.len() != 1 || target.len() != 1 {
                return Ok(
                    json!({"status":"ambiguous_operands","left":selected.ids.len(),"right":target.len()}),
                );
            }
            let ids = selected
                .ids
                .union(&target)
                .cloned()
                .collect::<BTreeSet<_>>();
            // Equal entity operands are a tie, not a successful comparison.
            if ids.len() != 2 {
                return Ok(json!({"status":"ambiguous","candidates":ids.len()}));
            }
            select(db, &ids, key, *order, meter)
        }
    }
}

fn select(
    db: &Connection,
    ids: &BTreeSet<String>,
    key: &str,
    order: SelectionOrder,
    meter: &mut Meter<'_>,
) -> Result<Value> {
    if ids.is_empty() {
        return Ok(json!({"status":"absent","candidates":0}));
    }
    let mut candidates = Vec::new();
    for id in ids {
        let one = BTreeSet::from([id.clone()]);
        let mut values = Values::default();
        read_attributes(db, &one, key, meter, |a, meter| {
            values.add(
                serde_json::from_str(&a.value_json)?,
                attribute_evidence(&a)?,
                meter,
            )
        })?;
        if values.distinct.len() != 1 {
            return Ok(json!({"status":"incomplete","subject":id,"value":values.finish()}));
        }
        let (typed, _) = &values.distinct[0];
        if matches!(typed.kind(), ValueKind::String) {
            return Ok(json!({"status":"incomparable","subject":id}));
        }
        candidates.push((id.clone(), typed.clone(), values.finish()));
    }
    let mut best = 0;
    let mut winners = vec![0];
    for index in 1..candidates.len() {
        meter.budget.spend(1)?;
        let comparison = candidates[index].1.compare(&candidates[best].1);
        let strict = match order {
            SelectionOrder::Smallest => ComparisonOp::Lt,
            SelectionOrder::Largest => ComparisonOp::Gt,
        };
        match (comparison.test(strict), comparison.test(ComparisonOp::Eq)) {
            (Some(true), _) => {
                best = index;
                winners = vec![index];
            }
            (Some(false), Some(true)) => winners.push(index),
            (Some(false), Some(false)) => {}
            // Incomparable intermediate values need not prevent a later
            // value from dominating both. The final pass checks every operand.
            _ => {}
        }
    }
    // A partial comparison domain can contain values incomparable with each
    // other even if each compares to the current best. Check the claimed winner
    // against every source before returning it.
    for (index, (_, typed, _)) in candidates.iter().enumerate() {
        if index == best {
            continue;
        }
        meter.budget.spend(1)?;
        let comparison = candidates[best].1.compare(typed);
        let nonstrict = match order {
            SelectionOrder::Smallest => ComparisonOp::Le,
            SelectionOrder::Largest => ComparisonOp::Ge,
        };
        if comparison.test(nonstrict) != Some(true) {
            return Ok(
                json!({"status":"incomparable","left":candidates[best].0,"right":candidates[index].0}),
            );
        }
    }
    if winners.len() != 1 {
        return Ok(
            json!({"status":"ambiguous","candidates":winners.len(),"entities":winners.into_iter().map(|i| &candidates[i].0).collect::<Vec<_>>()}),
        );
    }
    let (id, _, value) = &candidates[best];
    let name: String =
        db.query_row("SELECT name FROM nodes WHERE id=?1", [id], |row| row.get(0))?;
    meter.charge(id.len() + name.len())?;
    Ok(json!({"status":"unique","candidate":{"id":id,"name":name},"attribute":value}))
}

#[cfg(test)]
mod language_guard_contract {
    use super::*;
    use crate::{build_image, Cancellation, Image};
    use std::sync::Arc;
    use tempfile::TempDir;

    fn fixture(limits: Limits) -> (TempDir, Arc<Image>) {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let image = directory.path().join("image.sqlite");
        std::fs::write(&source, json!({"concepts":{},"entities":{
            "A":{"name":"Alpha","instanceOf":[],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":1,"unit":"1"},"qualifiers":{"since":[{"type":"year","value":2000}]}}
            ],"relations":[]},
            "B":{"name":"Beta","instanceOf":[],"attributes":[],"relations":[]}
        }}).to_string()).unwrap();
        let receipt = build_image(&source, &image, 100_000, 10_000).unwrap();
        let image = Image::open(&image, &receipt.image_sha256, limits).unwrap();
        (directory, image)
    }
    fn parse_plan(nodes: Value, output: usize, projection: Value) -> Plan {
        Plan::parse(
            &json!({"nodes":nodes,"output":output,"projection":projection}).to_string(),
            &Limits::default(),
        )
        .unwrap()
    }

    #[test]
    fn language_guard_checks_dead_and_union_branches_without_changing_graphs() {
        let (_directory, image) = fixture(Limits::default());
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let nodes = json!([
            {"op":"find","name":"Absent"},
            {"op":"find","name":"Alpha"},
            {"op":"or","left":0,"right":1}
        ]);
        for output in [1, 2] {
            let plan = parse_plan(nodes.clone(), output, json!({"kind":"unique_name"}));
            let (direct, _) = evaluate(
                &worker,
                &image.identity,
                &plan,
                &Selection::default(),
                &image.limits,
                &budget,
            )
            .unwrap();
            assert_eq!(direct.value["candidate"]["name"], "Alpha");
            let guarded = evaluate_language(
                &worker,
                &image.identity,
                &plan,
                &Selection::default(),
                &image.limits,
                &budget,
            )
            .unwrap();
            assert!(guarded.is_none());
        }
    }

    #[test]
    fn terminal_count_permits_empty_but_still_executes_all_stages() {
        let (_directory, image) = fixture(Limits::default());
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let plan = parse_plan(
            json!([
                {"op":"find","name":"Absent"},
                {"op":"find","name":"Alpha"}
            ]),
            0,
            json!({"kind":"count"}),
        );
        let (result, _) = evaluate_language(
            &worker,
            &image.identity,
            &plan,
            &Selection::default(),
            &image.limits,
            &budget,
        )
        .unwrap()
        .unwrap();
        assert_eq!(result.value, 0);
        drop(worker);

        let (_directory, image) = fixture(Limits {
            materialized_rows: 1,
            ..Limits::default()
        });
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let plan = parse_plan(
            json!([
                {"op":"find","name":"Alpha"},
                {"op":"find","name":"Beta"},
                {"op":"find","name":"Absent"}
            ]),
            2,
            json!({"kind":"count"}),
        );
        let (direct, _) = evaluate(
            &worker,
            &image.identity,
            &plan,
            &Selection::default(),
            &image.limits,
            &budget,
        )
        .unwrap();
        assert_eq!(direct.value, 0);
        assert!(matches!(
            evaluate_language(
                &worker,
                &image.identity,
                &plan,
                &Selection::default(),
                &image.limits,
                &budget,
            ),
            Err(Error::Limit("materialized rows"))
        ));
    }

    #[test]
    fn refused_candidate_cannot_leave_attribute_evidence_in_next_candidate() {
        let (_directory, image) = fixture(Limits::default());
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let filter = json!({"op":"filter_attribute","input":0,"key":"mass",
            "predicate":{"kind":"quantity","literal":"1","comparison":"="}});
        let first = parse_plan(
            json!([
                {"op":"find","name":"Alpha"},filter.clone(),{"op":"find","name":"Absent"}
            ]),
            1,
            json!({"kind":"unique_name"}),
        );
        assert!(evaluate_language(
            &worker,
            &image.identity,
            &first,
            &Selection::default(),
            &image.limits,
            &budget,
        )
        .unwrap()
        .is_none());
        // Reuse the node numbers and the same exclusive worker and Budget.
        // Count permits this empty selection, so stale scratch would be visible.
        let second = parse_plan(
            json!([
                {"op":"find","name":"Absent"},filter
            ]),
            1,
            json!({"kind":"count"}),
        );
        let (result, selected) = evaluate_language(
            &worker,
            &image.identity,
            &second,
            &Selection::default(),
            &image.limits,
            &budget,
        )
        .unwrap()
        .unwrap();
        assert_eq!(result.value, 0);
        assert!(selected.ids.is_empty());
        assert!(selected.facts.is_empty());
        assert!(selected.attributes.is_empty());
    }

    #[test]
    fn language_guard_preserves_shared_dag_materialization() {
        let (_directory, image) = fixture(Limits::default());
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut nodes = vec![json!({"op":"find","name":"Alpha"})];
        for input in 0..24 {
            nodes.push(json!({"op":"or","left":input,"right":input}));
        }
        let plan = parse_plan(json!(nodes), 24, json!({"kind":"unique_name"}));
        let (result, _) = evaluate_language(
            &worker,
            &image.identity,
            &plan,
            &Selection::default(),
            &image.limits,
            &budget,
        )
        .unwrap()
        .unwrap();
        assert_eq!(result.value["candidate"]["name"], "Alpha");
    }
    #[test]
    fn shared_language_stages_rebase_identity_and_preserve_attribute_evidence() {
        let (_directory, image) = fixture(Limits::default());
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        let previous = Selection::default();
        let first = parse_plan(
            json!([
                {"op":"find","name":"Alpha"},
                {"op":"filter_attribute","input":0,"key":"mass","predicate":{"kind":"quantity","literal":"1","comparison":"="}}
            ]),
            1,
            json!({"kind":"entities"}),
        );
        let (_, selected) = evaluate_language_shared(
            &worker,
            &image.identity,
            &first,
            &previous,
            &image.limits,
            &budget,
            &mut shared,
        )
        .unwrap()
        .unwrap();
        assert_eq!(shared.stages.len(), 2);
        assert_eq!(selected.attributes.len(), 1);
        let changes = worker.total_changes();
        let rebased = parse_plan(
            json!([
                {"op":"find","name":"Beta"},
                {"op":"find","name":"Alpha"},
                {"op":"filter_attribute","input":1,"key":"mass","predicate":{"kind":"quantity","literal":"1","comparison":"="}}
            ]),
            2,
            json!({"kind":"entities"}),
        );
        let (_, next) = evaluate_language_shared(
            &worker,
            &image.identity,
            &rebased,
            &previous,
            &image.limits,
            &budget,
            &mut shared,
        )
        .unwrap()
        .unwrap();
        assert_eq!(shared.stages.len(), 3);
        assert_eq!(worker.total_changes() - changes, 1); // Only new Beta stage inserts.
        assert_eq!(selected.ids, next.ids);
        assert_eq!(selected.attributes, next.attributes);
        assert_eq!(selected.facts, next.facts);
    }
    #[test]
    fn shared_empty_stage_still_refuses_dead_branches_but_count_can_reuse_it() {
        let (_directory, image) = fixture(Limits::default());
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        let previous = Selection::default();
        let missing = parse_plan(
            json!([{"op":"find","name":"Missing"}]),
            0,
            json!({"kind":"entities"}),
        );
        assert!(evaluate_language_shared(
            &worker,
            &image.identity,
            &missing,
            &previous,
            &image.limits,
            &budget,
            &mut shared
        )
        .unwrap()
        .is_none());
        let changes = worker.total_changes();
        let count = parse_plan(
            json!([{"op":"find","name":"Missing"}]),
            0,
            json!({"kind":"count"}),
        );
        let (result, _) = evaluate_language_shared(
            &worker,
            &image.identity,
            &count,
            &previous,
            &image.limits,
            &budget,
            &mut shared,
        )
        .unwrap()
        .unwrap();
        assert_eq!(result.value, json!(0));
        assert_eq!(worker.total_changes(), changes);
        let dead = parse_plan(
            json!([{"op":"find","name":"Missing"},{"op":"find","name":"Alpha"}]),
            1,
            json!({"kind":"unique_name"}),
        );
        assert!(evaluate_language_shared(
            &worker,
            &image.identity,
            &dead,
            &previous,
            &image.limits,
            &budget,
            &mut shared
        )
        .unwrap()
        .is_none());
    }
    #[test]
    fn shared_language_cache_has_aggregate_bounds_and_lease_cleanup() {
        let (_directory, image) = fixture(Limits {
            materialized_rows: 1,
            ..Limits::default()
        });
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        let previous = Selection::default();
        // Use compile directly so final reply row metering does not obscure the
        // distinction between each stage's bound and the aggregate cache bound.
        let alpha = parse_plan(
            json!([{"op":"find","name":"Alpha"}]),
            0,
            json!({"kind":"entities"}),
        );
        let beta = parse_plan(
            json!([{"op":"find","name":"Beta"}]),
            0,
            json!({"kind":"entities"}),
        );
        let mut meter = Meter {
            rows: 0,
            bytes: 0,
            limits: &image.limits,
            budget: &budget,
        };
        assert!(compile(
            &worker,
            &alpha,
            &previous,
            &mut meter,
            true,
            Some(&mut shared)
        )
        .unwrap()
        .is_some());
        let mut meter = Meter {
            rows: 0,
            bytes: 0,
            limits: &image.limits,
            budget: &budget,
        };
        assert!(matches!(
            compile(
                &worker,
                &beta,
                &previous,
                &mut meter,
                true,
                Some(&mut shared)
            ),
            Err(Error::Limit("language shared rows"))
        ));
        drop(worker);
        let worker = image.acquire("next", &budget).unwrap();
        let rows: i64 = worker
            .query_row("SELECT count(*) FROM temp.oracle_sets", [], |r| r.get(0))
            .unwrap();
        assert_eq!(rows, 0);
    }
    #[test]
    fn shared_attribute_equality_index_handles_many_predicates_with_all_witnesses() {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("strings.json");
        let output = directory.path().join("strings.sqlite");
        let entities:serde_json::Map<String,Value>=(0..100).map(|i| (format!("E{i}"),json!({
            "name":format!("Entity{i}"),"instanceOf":[],"relations":[],
            "attributes":[{"key":"code","value":{"type":"string","value":"live"},"qualifiers":{}}]
        }))).collect();
        std::fs::write(
            &source,
            json!({"concepts":{},"entities":entities}).to_string(),
        )
        .unwrap();
        let receipt = build_image(&source, &output, 1_000_000, 100_000).unwrap();
        let limits = Limits {
            fuel: 500_000,
            ..Limits::default()
        };
        let image = Image::open(&output, &receipt.image_sha256, limits).unwrap();
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        let previous = Selection::default();
        for i in 0..500 {
            let plan = parse_plan(
                json!([
                    {"op":"all"},
                    {"op":"filter_attribute","input":0,"key":"code","predicate":{"kind":"string","literal":format!("absent{i}"),"comparison":"="}}
                ]),
                1,
                json!({"kind":"entities"}),
            );
            assert!(evaluate_language_shared(
                &worker,
                &image.identity,
                &plan,
                &previous,
                &image.limits,
                &budget,
                &mut shared
            )
            .unwrap()
            .is_none());
        }
        assert_eq!(shared.columns.len(), 1);
        assert_eq!(shared.columns.values().next().unwrap().rows.len(), 100);
        let plan = parse_plan(
            json!([
                {"op":"all"},
                {"op":"filter_attribute","input":0,"key":"code","predicate":{"kind":"string","literal":" live ","comparison":"="}}
            ]),
            1,
            json!({"kind":"entities"}),
        );
        let (_, selected) = evaluate_language_shared(
            &worker,
            &image.identity,
            &plan,
            &previous,
            &image.limits,
            &budget,
            &mut shared,
        )
        .unwrap()
        .unwrap();
        assert_eq!(selected.ids.len(), 100);
        assert_eq!(selected.attributes.len(), 100);
        budget.check().unwrap();
    }
    #[test]
    fn shared_string_index_matches_uncached_unicode_case_and_whitespace_semantics() {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("unicode.json");
        let output = directory.path().join("unicode.sqlite");
        let attributes: Vec<_> = [
            "Live",
            "lIVE",
            " live ",
            "İSTANBUL",
            "ÅNGSTRÖM",
            "βETA",
            " βETA ",
        ]
        .iter()
        .enumerate()
        .map(|(i, text)| {
            json!({
                "key":"code","value":{"type":"string","value":text},
                "qualifiers":{"since":[{"type":"year","value":2000+i}]}
            })
        })
        .collect();
        std::fs::write(
            &source,
            json!({"concepts":{},"entities":{
                "A":{"name":"Alpha","instanceOf":[],"relations":[],"attributes":attributes}
            }})
            .to_string(),
        )
        .unwrap();
        let receipt = build_image(&source, &output, 1_000_000, 100_000).unwrap();
        let image = Image::open(&output, &receipt.image_sha256, Limits::default()).unwrap();
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let previous = Selection::default();
        let mut plans = Vec::new();
        for kind in [None, Some("string")] {
            for literal in [
                " live ",
                "İstanbul",
                "i\u{0307}stanbul",
                "ångström",
                " βeta ",
                "absent",
            ] {
                let mut predicate = json!({"literal":literal,"comparison":"="});
                if let Some(kind) = kind {
                    predicate["kind"] = json!(kind);
                }
                plans.push(parse_plan(json!([
                    {"op":"all"},{"op":"filter_attribute","input":0,"key":"code","predicate":predicate}
                ]),1,json!({"kind":"entities"})));
            }
        }
        let expected: Vec<_> = plans
            .iter()
            .map(|plan| {
                evaluate_language(
                    &worker,
                    &image.identity,
                    plan,
                    &previous,
                    &image.limits,
                    &budget,
                )
                .unwrap()
                .map(|(result, _)| serde_json::to_value(result).unwrap())
            })
            .collect();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        for (plan, expected) in plans.iter().zip(expected) {
            let actual = evaluate_language_shared(
                &worker,
                &image.identity,
                plan,
                &previous,
                &image.limits,
                &budget,
                &mut shared,
            )
            .unwrap()
            .map(|(result, _)| serde_json::to_value(result).unwrap());
            assert_eq!(actual, expected);
        }
        let column = shared.columns.values().next().unwrap();
        assert_eq!(column.strings["live"].len(), 2); // Separate positions/qualifiers.
        assert_eq!(column.strings[" live "].len(), 1); // Source whitespace preserved.
    }
}

#[cfg(test)]
mod output_contract {
    use super::*;
    use crate::{build_image, Cancellation, Image};
    use std::sync::Arc;
    use tempfile::TempDir;

    /// Parallel edges (Alpha knows Gamma twice, with different qualifiers) and
    /// two subjects reaching the same objects give Relate and Or many duplicate
    /// candidate ids and several statement witnesses per id.
    fn fixture(limits: Limits) -> (TempDir, Arc<Image>) {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let image = directory.path().join("image.sqlite");
        let since = |year: i64| json!({"since":[{"type":"year","value":year}]});
        std::fs::write(&source, json!({"concepts":{"P":{"name":"person","instanceOf":[]}},"entities":{
            "A":{"name":"Alpha","instanceOf":["P"],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":1,"unit":"1"},"qualifiers":since(2000)}
            ],"relations":[
                {"predicate":"knows","direction":"forward","object":"C","qualifiers":since(2000)},
                {"predicate":"knows","direction":"forward","object":"C","qualifiers":since(2001)},
                {"predicate":"knows","direction":"forward","object":"D","qualifiers":{}}
            ]},
            "B":{"name":"Beta","instanceOf":["P"],"attributes":[
                {"key":"mass","value":{"type":"quantity","value":2,"unit":"1"},"qualifiers":{}}
            ],"relations":[
                {"predicate":"knows","direction":"forward","object":"C","qualifiers":{}},
                {"predicate":"knows","direction":"forward","object":"D","qualifiers":since(2001)}
            ]},
            "C":{"name":"Gamma","instanceOf":[],"attributes":[],"relations":[]},
            "D":{"name":"Delta","instanceOf":[],"attributes":[],"relations":[]}
        }}).to_string()).unwrap();
        let receipt = build_image(&source, &image, 100_000, 10_000).unwrap();
        let image = Image::open(&image, &receipt.image_sha256, limits).unwrap();
        (directory, image)
    }
    fn plan(nodes: Value, output: usize, projection: &Value) -> Plan {
        Plan::parse(
            &json!({"nodes":nodes,"output":output,"projection":projection}).to_string(),
            &Limits::default(),
        )
        .unwrap()
    }
    fn knows(input: usize) -> Value {
        json!({"op":"relate","input":input,"predicate":"knows","direction":"forward"})
    }
    /// Plans compared across output contracts, each with an Entities, a Count
    /// and a Names projection. The last four have an empty stage: an empty
    /// output, an empty output behind an empty input, a dead branch, and an
    /// empty union side. Language mode refuses those unless the projection is
    /// Count; graph mode answers the last two and returns empty for the others.
    fn plans() -> Vec<(String, Plan)> {
        let alpha = json!({"op":"find","name":"Alpha"});
        let beta = json!({"op":"find","name":"Beta"});
        let absent = json!({"op":"find","name":"Absent"});
        let both = json!({"op":"or","left":0,"right":1});
        let mut out = Vec::new();
        for (kind, projection) in [
            ("entities", json!({"kind":"entities"})),
            ("count", json!({"kind":"count"})),
            ("names", json!({"kind":"names"})),
        ] {
            let p = &projection;
            for (name, plan) in [
                ("parallel_relate", plan(json!([alpha, knows(0)]), 1, p)),
                (
                    "union_of_relates",
                    plan(
                        json!([alpha, beta, both, knows(2), {"op":"or","left":3,"right":2}]),
                        4,
                        p,
                    ),
                ),
                (
                    "shared_union_with_itself",
                    plan(
                        json!([alpha, beta, both, knows(2), {"op":"or","left":3,"right":3},
                            {"op":"and","left":4,"right":3}]),
                        5,
                        p,
                    ),
                ),
                (
                    "qualifier_filter",
                    plan(
                        json!([alpha, beta, both, knows(2),
                            {"op":"filter_qualifier","input":3,"key":"since",
                             "predicate":{"kind":"year","literal":"2001","comparison":"="}}]),
                        4,
                        p,
                    ),
                ),
                (
                    "attribute_filter",
                    plan(
                        json!([{"op":"all"},
                            {"op":"filter_attribute","input":0,"key":"mass",
                             "predicate":{"kind":"quantity","literal":"0","comparison":">"}}]),
                        1,
                        p,
                    ),
                ),
                ("absent_only", plan(json!([absent]), 0, p)),
                ("relate_from_absent", plan(json!([absent, knows(0)]), 1, p)),
                (
                    "dead_empty_branch",
                    plan(json!([absent, alpha, knows(1)]), 2, p),
                ),
                (
                    "empty_union_side",
                    plan(json!([absent, alpha, {"op":"or","left":0,"right":1}]), 2, p),
                ),
            ] {
                out.push((format!("{name}/{kind}"), plan));
            }
        }
        out
    }

    /// Full replies for every plan, in graph mode and in shared language mode,
    /// with the per-build image digest replaced by a placeholder. Graph
    /// queries each take a fresh lease, as `Image::query` does; the language
    /// plans share one lease and workspace in order, as one reader request does.
    fn full_replies(image: &Arc<Image>) -> Value {
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let previous = Selection::default();
        let anonymous = |result: QueryResult| {
            let mut value = serde_json::to_value(result).unwrap();
            value["image"] = json!("<image>");
            value
        };
        let mut replies = serde_json::Map::new();
        for (name, plan) in plans() {
            let worker = image.acquire("tenant", &budget).unwrap();
            let (graph, _) = evaluate(
                &worker,
                &image.identity,
                &plan,
                &previous,
                &image.limits,
                &budget,
            )
            .unwrap();
            replies.insert(name, json!({"graph":anonymous(graph)}));
        }
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        for (name, plan) in plans() {
            let language = evaluate_language_shared(
                &worker,
                &image.identity,
                &plan,
                &previous,
                &image.limits,
                &budget,
                &mut shared,
            )
            .unwrap()
            .map(|(result, _)| anonymous(result));
            replies[&name]["language"] = json!(language);
        }
        Value::Object(replies)
    }

    /// Full replies recorded from the executor before `Demand` existed
    /// (commit ecfeec3), by the same `full_replies` over the same fixture.
    const FROZEN_FULL: &str = include_str!("../tests/fixtures/query_output_full.json");

    #[test]
    fn full_demand_reply_is_unchanged_from_before_the_output_contract() {
        let (_directory, image) = fixture(Limits::default());
        let frozen: Value = serde_json::from_str(FROZEN_FULL).unwrap();
        assert_eq!(frozen.as_object().unwrap().len(), 27);
        assert_eq!(full_replies(&image), frozen);
    }

    /// One graph evaluation on its own fresh lease, as `Image::query` runs.
    fn graph(image: &Arc<Image>, plan: &Plan, demand: Demand) -> Result<Delivered> {
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        evaluate_with_mode(
            &worker,
            &image.identity,
            plan,
            &Selection::default(),
            &image.limits,
            &budget,
            false,
            None,
            demand,
        )
        .map(|delivered| delivered.expect("graph mode never refuses"))
    }

    /// Every plan in order on one lease and one shared workspace under one
    /// demand, as one reader request evaluates its candidates. Returns each
    /// outcome and the workspace's final stage table and retained totals.
    #[allow(clippy::type_complexity)]
    fn language(
        image: &Arc<Image>,
        demand: Demand,
    ) -> (
        Vec<(String, Option<Delivered>)>,
        Vec<(String, usize, bool)>,
        (usize, usize),
    ) {
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        let outcomes = plans()
            .into_iter()
            .map(|(name, plan)| {
                let outcome = evaluate_language_demand(
                    &worker,
                    &image.identity,
                    &plan,
                    &Selection::default(),
                    &image.limits,
                    &budget,
                    &mut shared,
                    demand,
                )
                .unwrap();
                (name, outcome)
            })
            .collect();
        let stages = shared
            .stages
            .iter()
            .map(|(key, &(slot, nonempty))| (key.clone(), slot, nonempty))
            .collect();
        (
            outcomes,
            stages,
            (shared.retained_rows, shared.retained_bytes),
        )
    }

    #[test]
    fn exists_agrees_with_full_on_nonempty_empty_and_refusal() {
        let (_directory, image) = fixture(Limits::default());
        let mut graph_empty = 0;
        for (name, plan) in plans() {
            let (full, _) = graph(&image, &plan, Demand::Full)
                .unwrap()
                .into_full()
                .unwrap();
            let Delivered::Exists(exists) = graph(&image, &plan, Demand::Exists).unwrap() else {
                panic!("{name}: exists demand");
            };
            assert_eq!(exists, !full.entities.is_empty(), "{name}");
            graph_empty += usize::from(!exists);
        }
        // absent_only and relate_from_absent under three projections.
        assert_eq!(graph_empty, 6);

        let (full, full_stages, full_retained) = language(&image, Demand::Full);
        let (exists, exists_stages, exists_retained) = language(&image, Demand::Exists);
        // The same stages were materialized, keyed, sized and judged empty.
        assert_eq!(exists_stages, full_stages);
        assert_eq!(exists_retained, full_retained);
        let (mut refused, mut nonempty, mut empty) = (0, 0, 0);
        for ((name, full), (_, exists)) in full.into_iter().zip(exists) {
            match (full, exists) {
                (None, None) => refused += 1,
                (Some(Delivered::Full(result, _)), Some(Delivered::Exists(exists))) => {
                    assert_eq!(exists, !result.entities.is_empty(), "{name}");
                    if exists {
                        nonempty += 1;
                    } else {
                        empty += 1;
                    }
                }
                (full, exists) => panic!("{name}: {full:?} against {exists:?}"),
            }
        }
        // Four plans with an empty stage refuse under entities and names; only
        // a Count projection admits them, and two of those are empty outputs.
        assert_eq!((refused, nonempty, empty), (8, 17, 2));
    }

    #[test]
    fn count_equals_full_distinct_ids_on_duplicate_heavy_plans() {
        let (_directory, image) = fixture(Limits::default());
        for (name, plan) in plans() {
            let (full, _) = graph(&image, &plan, Demand::Full)
                .unwrap()
                .into_full()
                .unwrap();
            let Delivered::Count(count) = graph(&image, &plan, Demand::Count).unwrap() else {
                panic!("{name}: count demand");
            };
            assert_eq!(count, full.entities.len() as u64, "{name}");
            if name == "union_of_relates/count" {
                // Five statements (two parallel) reach four distinct entities.
                assert_eq!(
                    (count, full.facts.len(), full.value.clone()),
                    (4, 5, json!(4))
                );
            }
            if name == "parallel_relate/entities" {
                assert_eq!((count, full.facts.len()), (2, 3));
            }
        }
        let (full, full_stages, _) = language(&image, Demand::Full);
        let (counts, count_stages, _) = language(&image, Demand::Count);
        assert_eq!(count_stages, full_stages);
        let mut admitted = 0;
        for ((name, full), (_, count)) in full.into_iter().zip(counts) {
            match (full, count) {
                (None, None) => {}
                (Some(Delivered::Full(result, _)), Some(Delivered::Count(count))) => {
                    assert_eq!(count, result.entities.len() as u64, "{name}");
                    admitted += 1;
                }
                (full, count) => panic!("{name}: {full:?} against {count:?}"),
            }
        }
        assert_eq!(admitted, 19);
    }

    #[test]
    fn scalar_demands_keep_stage_limits_and_drop_only_fetch_charges() {
        let plans: BTreeMap<String, Plan> = plans().into_iter().collect();
        let relate = &plans["parallel_relate/entities"];
        // Language stage metering: stage 0 holds one id, stage 1 two ids and
        // three statements. Six rows pass compile; a seventh fetched row fails.
        let (_directory, tight) = fixture(Limits {
            materialized_rows: 5,
            ..Limits::default()
        });
        for demand in [Demand::Full, Demand::Exists, Demand::Count] {
            let budget = Budget::new(&tight.limits, Cancellation::default()).unwrap();
            let worker = tight.acquire("tenant", &budget).unwrap();
            let mut shared = LanguageWorkspace::new(&worker).unwrap();
            let outcome = evaluate_language_demand(
                &worker,
                &tight.identity,
                relate,
                &Selection::default(),
                &tight.limits,
                &budget,
                &mut shared,
                demand,
            );
            assert!(
                matches!(outcome, Err(Error::Limit("materialized rows"))),
                "{demand:?}: {outcome:?}"
            );
        }
        let (_directory, roomy) = fixture(Limits {
            materialized_rows: 6,
            ..Limits::default()
        });
        let budget = Budget::new(&roomy.limits, Cancellation::default()).unwrap();
        let worker = roomy.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        assert!(matches!(
            evaluate_language_demand(
                &worker,
                &roomy.identity,
                relate,
                &Selection::default(),
                &roomy.limits,
                &budget,
                &mut shared,
                Demand::Full,
            ),
            Err(Error::Limit("materialized rows"))
        ));
        drop(shared);
        drop(worker);
        let budget = Budget::new(&roomy.limits, Cancellation::default()).unwrap();
        let worker = roomy.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        assert!(matches!(
            evaluate_language_demand(
                &worker,
                &roomy.identity,
                relate,
                &Selection::default(),
                &roomy.limits,
                &budget,
                &mut shared,
                Demand::Exists,
            ),
            Ok(Some(Delivered::Exists(true)))
        ));
        // The workspace's aggregate bound across candidates is a compile-time
        // stage bound, so it still refuses a scalar demand. With one row
        // allowed, Full already fails on its own reply fetch.
        let find = |name: &str| {
            plan(
                json!([{"op":"find","name":name}]),
                0,
                &json!({"kind":"entities"}),
            )
        };
        let (_directory, image) = fixture(Limits {
            materialized_rows: 1,
            ..Limits::default()
        });
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        let mut run = |plan: &Plan, demand: Demand| {
            evaluate_language_demand(
                &worker,
                &image.identity,
                plan,
                &Selection::default(),
                &image.limits,
                &budget,
                &mut shared,
                demand,
            )
        };
        assert!(matches!(
            run(&find("Alpha"), Demand::Exists),
            Ok(Some(Delivered::Exists(true)))
        ));
        assert!(matches!(
            run(&find("Beta"), Demand::Exists),
            Err(Error::Limit("language shared rows"))
        ));
        let (_directory, image) = fixture(Limits {
            materialized_rows: 1,
            ..Limits::default()
        });
        let budget = Budget::new(&image.limits, Cancellation::default()).unwrap();
        let worker = image.acquire("tenant", &budget).unwrap();
        let mut shared = LanguageWorkspace::new(&worker).unwrap();
        assert!(matches!(
            evaluate_language_demand(
                &worker,
                &image.identity,
                &find("Alpha"),
                &Selection::default(),
                &image.limits,
                &budget,
                &mut shared,
                Demand::Full,
            ),
            Err(Error::Limit("materialized rows"))
        ));
    }
}
