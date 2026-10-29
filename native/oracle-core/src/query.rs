use crate::{Budget, Error, Limits, Result};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::BTreeSet;
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
    And {
        left: usize,
        right: usize,
    },
    Or {
        left: usize,
        right: usize,
    },
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Projection {
    Entities,
    Names,
    UniqueName,
    Count,
    Attributes { key: String },
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Plan {
    pub nodes: Vec<Node>,
    pub output: usize,
    pub projection: Projection,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Selection {
    pub ids: BTreeSet<String>,
    pub facts: BTreeSet<Fact>,
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

#[derive(Debug, Serialize, Deserialize)]
pub struct QueryResult {
    pub image: String,
    pub coverage: String,
    pub entities: Vec<String>,
    pub facts: Vec<Fact>,
    pub value: Value,
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

impl Plan {
    pub fn parse(text: &str, limits: &Limits) -> Result<Self> {
        if text.len() > limits.request_bytes {
            return Err(Error::Limit("request bytes"));
        }
        let plan: Self = serde_json::from_str(text)?;
        if plan.nodes.is_empty()
            || plan.nodes.len() > limits.plan_nodes
            || plan.output >= plan.nodes.len()
        {
            return Err(Error::Invalid("plan dimensions".into()));
        }
        for (i, node) in plan.nodes.iter().enumerate() {
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
                Node::And { left, right } | Node::Or { left, right } => vec![*left, *right],
                _ => vec![],
            };
            if deps.iter().any(|&d| d >= i) {
                return Err(Error::Invalid("dependency must precede consumer".into()));
            }
        }
        Ok(plan)
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

pub(crate) fn evaluate(
    db: &Connection,
    identity: &str,
    plan: &Plan,
    previous: &Selection,
    limits: &Limits,
    budget: &Budget,
) -> Result<(QueryResult, Selection)> {
    let mut meter = Meter {
        rows: 0,
        bytes: 0,
        limits,
        budget,
    };
    // Compile the complete pure DAG. SQLite can push predicates through the plan;
    // Rust materializes results and shared subplans, not every single-use node.
    let compiled = compile(db, plan, previous, &mut meter)?;
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
    let value = match &plan.projection {
        Projection::Entities => Value::Null,
        Projection::Count => json!(selected.ids.len()),
        Projection::UniqueName if selected.ids.len() != 1 => {
            json!({"status":if selected.ids.is_empty() {"absent"} else {"ambiguous"},"candidates":selected.ids.len()})
        }
        Projection::Names | Projection::UniqueName => {
            let mut names = Vec::new();
            let mut stmt = db.prepare_cached("SELECT name FROM nodes WHERE id=?1")?;
            for id in &selected.ids {
                budget.spend(1)?;
                let name: String = stmt.query_row([id], |r| r.get(0))?;
                meter.charge(id.len() + name.len())?;
                names.push(json!({"id":id,"name":name}));
            }
            if matches!(plan.projection, Projection::UniqueName) {
                json!({"status":"unique","candidate":names[0]})
            } else {
                json!(names)
            }
        }
        Projection::Attributes { key } => {
            let mut attributes = Vec::new();
            let mut stmt = db.prepare_cached("SELECT value,qualifiers FROM attributes WHERE subject=?1 AND key=?2 ORDER BY position")?;
            for id in &selected.ids {
                budget.spend(1)?;
                let mut rows = stmt.query(params![id, key])?;
                while let Some(row) = rows.next()? {
                    let value: String = row.get(0)?;
                    let qualifiers: String = row.get(1)?;
                    meter.charge(id.len() + key.len() + value.len() + qualifiers.len())?;
                    attributes.push(json!({"subject":id,"key":key,"value":serde_json::from_str::<Value>(&value)?,"qualifiers":serde_json::from_str::<Value>(&qualifiers)?}));
                }
            }
            json!(attributes)
        }
    };
    budget.check()?;
    let result = QueryResult {
        image: identity.into(),
        coverage: "complete_relative_to_image".into(),
        entities: selected.ids.iter().cloned().collect(),
        facts: selected.facts.iter().cloned().collect(),
        value,
    };
    Ok((result, selected))
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
) -> Result<Compiled> {
    let mut ctes = Vec::new();
    let mut parameters = Vec::new();
    let mut live = vec![false; plan.nodes.len()];
    let mut pending = vec![plan.output];
    while let Some(index) = pending.pop() {
        if live[index] {
            continue;
        }
        live[index] = true;
        match &plan.nodes[index] {
            Node::Relate { input, .. } | Node::FilterConcept { input, .. } => pending.push(*input),
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
            Node::Relate { input, .. } | Node::FilterConcept { input, .. } => uses[*input] += 1,
            Node::And { left, right } | Node::Or { left, right } => {
                uses[*left] += 1;
                uses[*right] += 1;
            }
            _ => {}
        }
    }
    for (i, node) in plan.nodes.iter().enumerate() {
        if !live[i] {
            continue;
        }
        meter.budget.spend(1)?;
        let mut bind = |text: String| {
            parameters.push(text);
            format!("?{}", parameters.len())
        };
        let mut facts = "SELECT '', '', '', '', '' WHERE 0".to_string();
        let ids = match node {
            Node::Find { name } => {
                format!("SELECT id FROM nodes WHERE name={}", bind(name.clone()))
            }
            Node::All => "SELECT id FROM nodes WHERE kind='entity'".into(),
            Node::Previous => {
                let ids = bind(serde_json::to_string(&previous.ids)?);
                let fs = bind(serde_json::to_string(&previous.facts)?);
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
            Node::And { left, right } | Node::Or { left, right } => {
                let op = if matches!(node, Node::And { .. }) {
                    "INTERSECT"
                } else {
                    "UNION"
                };
                facts=format!("SELECT * FROM (SELECT * FROM f{left} UNION SELECT * FROM f{right}) WHERE object IN (SELECT id FROM n{i})");
                format!("SELECT id FROM n{left} {op} SELECT id FROM n{right}")
            }
        };
        ctes.push(format!("n{i}(id) AS ({ids})"));
        ctes.push(format!(
            "f{i}(subject,predicate,direction,object,qualifiers) AS ({facts})"
        ));
        if uses[i] > 1 {
            materialize(db, &ctes, &parameters, i, meter)?;
            let n = ctes.len();
            ctes[n - 2] = format!("n{i}(id) AS (SELECT id FROM temp.oracle_sets WHERE node={i})");
            ctes[n-1]=format!("f{i}(subject,predicate,direction,object,qualifiers) AS (SELECT subject,predicate,direction,object,qualifiers FROM temp.oracle_facts WHERE node={i})");
        }
    }
    Ok(Compiled {
        prefix: format!("WITH RECURSIVE {}", ctes.join(",")),
        parameters,
    })
}

fn materialize(
    db: &Connection,
    ctes: &[String],
    parameters: &[String],
    node: usize,
    meter: &mut Meter<'_>,
) -> Result<()> {
    let prefix = format!("WITH RECURSIVE {}", ctes.join(","));
    {
        let mut query = db.prepare(&format!("{prefix} SELECT id FROM n{node}"))?;
        let count = query.parameter_count();
        let mut rows = query.query(rusqlite::params_from_iter(parameters.iter().take(count)))?;
        let mut insert = db.prepare_cached("INSERT INTO temp.oracle_sets VALUES (?1,?2)")?;
        while let Some(row) = rows.next()? {
            let id: String = row.get(0)?;
            meter.charge(id.len())?;
            insert.execute(params![node as i64, id])?;
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
                node as i64,
                fields[0],
                fields[1],
                fields[2],
                fields[3],
                fields[4]
            ])?;
        }
    }
    Ok(())
}
