//! Prepared program comparisons over one immutable image and empty Previous snapshot.
//! Source-set results do not establish world completeness or session state.
//! Original typed validation and final-DAG semantics remain in force. The cache
//! lives only inside one leased batch invocation.
use crate::query::{self, Delivered, Demand, LanguageWorkspace, Selection};
use crate::{Budget, Error, Image, Plan, Program, QueryResult, Result};
use serde::Serialize;
use std::sync::Arc;

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum BatchDemand {
    Full,
    Exists,
    Count,
}

/// Checked typed plan; its owning image also pins its schema and source snapshot.
/// No external constructor or mutable plan access can bypass Program admission.
pub struct PreparedQuery {
    image: Arc<Image>,
    plan: Plan,
    _memory: crate::budget::MemoryReservation,
}

#[derive(Debug, Serialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum BatchValue {
    Full(Box<QueryResult>),
    Exists(bool),
    Count(u64),
}
#[derive(Debug, Serialize)]
#[serde(tag = "status", content = "detail", rename_all = "snake_case")]
pub enum ItemOutcome {
    Answer(BatchValue),
    /// Reserved for an explicit evaluator admission refusal.
    Refused,
    Failed(&'static str),
    /// Earlier failure ends this cache lifetime; no later item was attempted.
    NotRun,
}
#[derive(Debug, Default, Serialize)]
pub struct BatchCosts {
    pub items_attempted: usize,
    pub plan_nodes_submitted: usize,
    pub worker_leases: usize,
    pub output_bytes: usize,
    pub distinct_stages: usize,
    pub stage_cache_hits: usize,
    pub distinct_columns: usize,
    pub column_cache_hits: usize,
    pub column_rows_decoded: usize,
}
#[derive(Serialize)]
pub struct BatchReport {
    image: String,
    pub scope: &'static str,
    items: Vec<ItemOutcome>,
    costs: BatchCosts,
    // Result ownership keeps aggregate retained memory charged until drop.
    #[serde(skip)]
    _memory: Vec<crate::budget::MemoryReservation>,
}

impl BatchReport {
    pub fn image(&self) -> &str {
        &self.image
    }
    pub fn items(&self) -> &[ItemOutcome] {
        &self.items
    }
    pub fn costs(&self) -> &BatchCosts {
        &self.costs
    }
}

pub fn prepare(image: Arc<Image>, program_json: &str, budget: &Budget) -> Result<PreparedQuery> {
    let budget = budget.restricted_to(&image.limits)?;
    budget.spend(program_json.len() as u64 + 1)?;
    let program = Program::parse(program_json, &image.limits)?;
    let plan = program.compile(&image.limits)?;
    budget.spend(plan.nodes.len() as u64 + 1)?;
    retain_prepared(image, plan, &budget)
}

/// Prepare the existing public graph dialect with the same structural and
/// literal validation as a single graph request.
pub fn prepare_graph(
    image: Arc<Image>,
    graph_json: &str,
    budget: &Budget,
) -> Result<PreparedQuery> {
    let budget = budget.restricted_to(&image.limits)?;
    budget.spend(graph_json.len() as u64 + 1)?;
    let plan = Plan::parse(graph_json, &image.limits)?;
    budget.spend(plan.nodes.len() as u64 + 1)?;
    retain_prepared(image, plan, &budget)
}

/// Typed host boundary. The host still enforces its original wire byte ceiling;
/// this constructor rechecks the same operation/literal contracts without a
/// JSON round trip. No unvalidated Plan becomes a prepared handle.
pub fn prepare_program(
    image: Arc<Image>,
    program: Program,
    budget: &Budget,
) -> Result<PreparedQuery> {
    let budget = budget.restricted_to(&image.limits)?;
    program.validate(&image.limits)?;
    let size = query::encoded_size(&program, image.limits.request_bytes)?;
    budget.spend(size as u64 + 1)?;
    let plan = program.compile(&image.limits)?;
    budget.spend(plan.nodes.len() as u64 + 1)?;
    retain_prepared(image, plan, &budget)
}

pub fn prepare_plan(image: Arc<Image>, plan: Plan, budget: &Budget) -> Result<PreparedQuery> {
    let budget = budget.restricted_to(&image.limits)?;
    plan.validate(&image.limits)?;
    let size = query::encoded_size(&plan, image.limits.request_bytes)?;
    budget.spend(size as u64 + plan.nodes.len() as u64 + 1)?;
    retain_prepared(image, plan, &budget)
}

fn retain_prepared(image: Arc<Image>, plan: Plan, budget: &Budget) -> Result<PreparedQuery> {
    // Count actual retained capacities, including caller-provided typed plans
    // with spare allocation. SQLite and allocator overhead remain excluded.
    query::encoded_size(&plan, image.limits.request_bytes)?;
    let memory = budget.reserve_memory(plan_retained_bytes(&plan).saturating_add(256))?;
    Ok(PreparedQuery {
        image,
        plan,
        _memory: memory,
    })
}

/// Related source programs share live stages/typed columns, but never Previous or a
/// session. Scalars describe distinct entities in this admitted source image.
/// A terminal error aborts later items explicitly; refusals may safely continue.
/// Envelope/output exhaustion returns Err, never a truncated successful report.
pub fn execute(
    image: &Arc<Image>,
    tenant: &str,
    requests: &[(&PreparedQuery, BatchDemand)],
    budget: &Budget,
) -> Result<BatchReport> {
    execute_mode(image, tenant, requests, budget, false)
}

/// Reader-style all-stage nonempty admission, explicitly separate from public
/// program semantics. Count projection keeps the existing reader exception.
pub fn execute_guarded(
    image: &Arc<Image>,
    tenant: &str,
    requests: &[(&PreparedQuery, BatchDemand)],
    budget: &Budget,
) -> Result<BatchReport> {
    execute_mode(image, tenant, requests, budget, true)
}

fn execute_mode(
    image: &Arc<Image>,
    tenant: &str,
    requests: &[(&PreparedQuery, BatchDemand)],
    budget: &Budget,
    guarded: bool,
) -> Result<BatchReport> {
    crate::runtime::identifier(tenant)?;
    let budget = budget.restricted_to(&image.limits)?;
    budget.check()?;
    if requests.len() > image.limits.plan_nodes {
        return Err(Error::Limit("batch items"));
    }
    if requests.iter().any(|(p, _)| !Arc::ptr_eq(&p.image, image)) {
        return Err(Error::Invalid(
            "prepared query belongs to another image owner".into(),
        ));
    }
    let mut report = BatchReport {
        image: image.verified_identity().to_string(),
        scope: if guarded {
            "guarded_source_empty_previous"
        } else {
            "program_source_empty_previous"
        },
        items: Vec::with_capacity(requests.len()),
        costs: BatchCosts::default(),
        _memory: vec![budget.reserve_memory(
            requests
                .len()
                .saturating_mul(256)
                .saturating_add(image.verified_identity().len()),
        )?],
    };
    if !requests.is_empty() {
        let worker = image.acquire(tenant, &budget)?;
        report.costs.worker_leases = 1;
        let mut shared = LanguageWorkspace::new(&worker)?;
        let previous = Selection::default();
        let mut stopped = false;
        for (prepared, demand) in requests {
            if stopped {
                report.items.push(ItemOutcome::NotRun);
                continue;
            }
            report.costs.items_attempted += 1;
            report.costs.plan_nodes_submitted += prepared.plan.nodes.len();
            let demand = match demand {
                BatchDemand::Full => Demand::Full,
                BatchDemand::Exists => Demand::Exists,
                BatchDemand::Count => Demand::Count,
            };
            let outcome = budget.check().and_then(|()| {
                let evaluate = if guarded {
                    query::evaluate_language_demand
                } else {
                    query::evaluate_program_shared
                };
                evaluate(
                    &worker,
                    image.verified_identity(),
                    &prepared.plan,
                    &previous,
                    &image.limits,
                    &budget,
                    &mut shared,
                    demand,
                )
            });
            let item = match outcome {
                Ok(None) => ItemOutcome::Refused,
                Ok(Some(value)) => {
                    let value = match value {
                        Delivered::Full(result, _) => BatchValue::Full(result),
                        Delivered::Exists(value) => BatchValue::Exists(value),
                        Delivered::Count(value) => BatchValue::Count(value),
                    };
                    let bytes = match &value {
                        BatchValue::Full(q) => query::query_retained_bytes(q),
                        _ => 32,
                    };
                    match budget.reserve_memory(bytes) {
                        Ok(memory) => {
                            report._memory.push(memory);
                            ItemOutcome::Answer(value)
                        }
                        Err(error) => {
                            stopped = true;
                            ItemOutcome::Failed(failure_code(&error))
                        }
                    }
                }
                Err(error) => {
                    stopped = true;
                    ItemOutcome::Failed(failure_code(&error))
                }
            };
            report.items.push(item);
            // Whole-envelope accounting includes status labels and cost fields.
            query::encoded_size(&report, image.limits.result_bytes)?;
        }
        let (stages, stage_hits, columns, column_hits, decoded) = shared.batch_costs();
        report.costs.distinct_stages = stages;
        report.costs.stage_cache_hits = stage_hits;
        report.costs.distinct_columns = columns;
        report.costs.column_cache_hits = column_hits;
        report.costs.column_rows_decoded = decoded;
    }
    report.costs.output_bytes = query::encoded_size(&report, image.limits.result_bytes)?;
    // Updating the counter can widen the envelope. Resolve its fixed point.
    for _ in 0..4 {
        let size = query::encoded_size(&report, image.limits.result_bytes)?;
        if size == report.costs.output_bytes {
            return Ok(report);
        }
        report.costs.output_bytes = size;
    }
    Err(Error::Format(
        "batch output accounting did not converge".into(),
    ))
}

// Stable bounded failure codes keep cancellation/failure reporting independent
// of the exhausted budget and avoid retaining arbitrary database error text.
fn failure_code(error: &Error) -> &'static str {
    match error {
        Error::Cancelled => "cancelled",
        Error::Deadline => "deadline",
        Error::Limit(_) => "resource_limit",
        Error::Busy => "busy",
        Error::Invalid(_) => "invalid",
        Error::Conflict(_) => "conflict",
        Error::Format(_) => "format",
        Error::Poisoned => "poisoned",
        Error::Sql(_) => "database",
        Error::Io(_) => "io",
        Error::Json(_) => "json",
    }
}

fn plan_retained_bytes(plan: &Plan) -> usize {
    use crate::{Node, Projection};
    fn projection(p: &Projection) -> usize {
        match p {
            Projection::Entities
            | Projection::Names
            | Projection::UniqueName
            | Projection::Count => 0,
            Projection::Attributes { key }
            | Projection::Select { key, .. }
            | Projection::SelectBetween { key, .. } => key.capacity(),
            Projection::UniqueAttribute { key, condition } => {
                key.capacity()
                    .saturating_add(condition.as_ref().map_or(0, |c| {
                        c.key
                            .capacity()
                            .saturating_add(c.predicate.literal.capacity())
                    }))
            }
            Projection::AttributeQualifier {
                key,
                predicate,
                qualifier,
            } => key
                .capacity()
                .saturating_add(predicate.literal.capacity())
                .saturating_add(qualifier.capacity()),
            Projection::Relation { direction, .. } => {
                direction.as_ref().map_or(0, String::capacity)
            }
            Projection::RelationQualifier {
                predicate,
                direction,
                qualifier,
                ..
            } => predicate
                .capacity()
                .saturating_add(direction.as_ref().map_or(0, String::capacity))
                .saturating_add(qualifier.capacity()),
            Projection::Verify { source, predicate } => std::mem::size_of::<Projection>()
                .saturating_add(projection(source))
                .saturating_add(predicate.literal.capacity()),
        }
    }
    plan.nodes.iter().fold(
        plan.nodes
            .capacity()
            .saturating_mul(std::mem::size_of::<Node>())
            .saturating_add(projection(&plan.projection)),
        |bytes, node| {
            bytes.saturating_add(match node {
                Node::Find { name } | Node::FilterConcept { name, .. } => name.capacity(),
                Node::Relate {
                    predicate,
                    direction,
                    ..
                } => predicate.capacity().saturating_add(direction.capacity()),
                Node::FilterAttribute { key, predicate, .. }
                | Node::FilterQualifier { key, predicate, .. } => {
                    key.capacity().saturating_add(predicate.literal.capacity())
                }
                Node::All | Node::Previous | Node::And { .. } | Node::Or { .. } => 0,
            })
        },
    )
}
