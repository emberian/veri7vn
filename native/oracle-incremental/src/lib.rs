//! Maintained dependency closure for one finite, isolated, versioned supplied graph.
//!
//! Handwritten, unverified Rust. Neither differential-dataflow nor this wrapper
//! inherits an Isabelle theorem. Missing paths mean absence only in this supplied
//! graph; they say nothing about missing public or private source facts.
#![forbid(unsafe_code)]

use differential_dataflow::input::InputSession;
use differential_dataflow::operators::Iterate;
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::rc::Rc;
use std::time::Instant;

pub type Node = u32;
type Pair = (Node, Node);

/// Host-owned admission limits. Request JSON cannot raise these limits.
#[derive(Clone, Debug, Serialize)]
pub struct Limits {
    pub max_nodes: usize,
    pub max_live_facts: usize,
    pub max_epochs: usize,
    pub max_mutations: usize,
    pub max_queries: usize,
    pub max_id_bytes: usize,
    /// Conservative bound on all possible live output pairs, checked before work.
    pub max_relation_pairs: usize,
    /// Includes retained delta rows and query answer nodes across the whole batch.
    pub max_response_items: usize,
    /// Number of calls to worker.step(), not an instruction or recursion bound.
    pub max_steps_per_epoch: u64,
    /// Observed output events, including canceling events, per epoch.
    pub max_output_events_per_epoch: u64,
    /// Checked between worker steps; an individual step is not preempted.
    pub max_elapsed_ms: u64,
}

/// Fixed byte admission used by the JSON and CLI boundaries.
pub const MAX_REQUEST_BYTES: usize = 1_048_576;

impl Default for Limits {
    fn default() -> Self {
        Self {
            max_nodes: 128,
            max_live_facts: 2048,
            max_epochs: 256,
            max_mutations: 16384,
            max_queries: 4096,
            max_id_bytes: 128,
            max_relation_pairs: 16384,
            max_response_items: 262144,
            max_steps_per_epoch: 1_000_000,
            max_output_events_per_epoch: 2_000_000,
            max_elapsed_ms: 10_000,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    /// Opaque authority/snapshot label echoed in every result. Not authentication.
    pub scope: String,
    /// Complete declared node universe for this finite request.
    pub nodes: Vec<Node>,
    pub epochs: Vec<Epoch>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Epoch {
    /// Strictly increasing; MAX is refused because it has no closing frontier.
    pub version: u64,
    pub mutations: Vec<Mutation>,
    #[serde(default)]
    pub queries: Vec<Query>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
pub enum Mutation {
    /// from is a prerequisite/cause, to is its dependent/consequence.
    Insert {
        fact_id: String,
        from: Node,
        to: Node,
    },
    Retract {
        fact_id: String,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
pub enum Query {
    /// Nonempty directed path; self is reachable only on a cycle/self-loop.
    Reachable { from: Node, to: Node },
    /// Union of nodes reached from roots, or of prerequisites reaching roots.
    Impact {
        roots: Vec<Node>,
        direction: Direction,
        #[serde(default)]
        include_roots: bool,
    },
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Direction {
    Downstream,
    Upstream,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct RelationChange {
    pub from: Node,
    pub to: Node,
    pub diff: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Answer {
    Reachable {
        from: Node,
        to: Node,
        reachable: bool,
    },
    Impact {
        nodes: Vec<Node>,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct EpochResult {
    pub version: u64,
    /// No output update at or before version remains possible.
    pub settled: bool,
    /// Actual timely probe frontier after settling; [] means fully completed.
    pub frontier: Vec<u64>,
    pub live_facts: usize,
    pub distinct_edges: usize,
    pub reachable_pairs: usize,
    /// Consolidated set changes relative to the preceding settled version.
    pub delta: Vec<RelationChange>,
    pub answers: Vec<Answer>,
    pub elapsed_us: u64,
    pub worker_steps: u64,
    pub observed_output_events: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Response {
    pub scope: String,
    pub provider: String,
    pub evidence: String,
    pub coverage: String,
    pub epochs: Vec<EpochResult>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Error {
    pub code: String,
    pub detail: String,
    pub version: Option<u64>,
}
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.detail)
    }
}
impl std::error::Error for Error {}
fn error(code: &str, detail: impl Into<String>, version: Option<u64>) -> Error {
    Error {
        code: code.into(),
        detail: detail.into(),
        version,
    }
}

struct Prepared {
    version: u64,
    updates: Vec<(Pair, isize)>,
    queries: Vec<Query>,
    live_facts: usize,
    distinct_edges: usize,
}

/// Preflight the complete history before constructing a dataflow. Mutation order
/// within an epoch is checked, but intermediate states are never published.
fn prepare(request: &Request, limits: &Limits) -> Result<Vec<Prepared>, Error> {
    if request.scope.is_empty() || request.scope.len() > limits.max_id_bytes {
        return Err(error(
            "invalid_scope",
            "scope must be a nonempty bounded label",
            None,
        ));
    }
    if request.nodes.len() > limits.max_nodes || request.epochs.len() > limits.max_epochs {
        return Err(error(
            "input_limit",
            "node or epoch count exceeds host admission",
            None,
        ));
    }
    let nodes: BTreeSet<_> = request.nodes.iter().copied().collect();
    if nodes.len() != request.nodes.len() {
        return Err(error(
            "duplicate_node",
            "declared node IDs must be unique",
            None,
        ));
    }
    if nodes
        .len()
        .checked_mul(nodes.len())
        .is_none_or(|n| n > limits.max_relation_pairs)
    {
        return Err(error(
            "state_limit",
            "node universe squared exceeds admitted pair bound",
            None,
        ));
    }
    let mut live = BTreeMap::<String, Pair>::new();
    let mut prepared = Vec::new();
    let mut previous = None;
    let mut mutations = 0usize;
    let mut queries = 0usize;
    for epoch in &request.epochs {
        let v = Some(epoch.version);
        if epoch.version == u64::MAX || previous.is_some_and(|p| p >= epoch.version) {
            return Err(error(
                "invalid_version",
                "versions must increase strictly and be below MAX",
                v,
            ));
        }
        previous = Some(epoch.version);
        mutations = mutations.saturating_add(epoch.mutations.len());
        queries = queries.saturating_add(epoch.queries.len());
        if mutations > limits.max_mutations || queries > limits.max_queries {
            return Err(error(
                "input_limit",
                "mutation or query count exceeds host admission",
                v,
            ));
        }
        let mut updates = BTreeMap::<Pair, isize>::new();
        for mutation in &epoch.mutations {
            match mutation {
                Mutation::Insert { fact_id, from, to } => {
                    if fact_id.is_empty() || fact_id.len() > limits.max_id_bytes {
                        return Err(error(
                            "invalid_fact_id",
                            "fact IDs must be nonempty bounded labels",
                            v,
                        ));
                    }
                    if !nodes.contains(from) || !nodes.contains(to) {
                        return Err(error(
                            "unknown_node",
                            "edge endpoint not in declared universe",
                            v,
                        ));
                    }
                    if live.contains_key(fact_id) {
                        return Err(error(
                            "duplicate_fact_id",
                            "retract an existing fact ID before reusing it",
                            v,
                        ));
                    }
                    live.insert(fact_id.clone(), (*from, *to));
                    *updates.entry((*from, *to)).or_default() += 1;
                    if live.len() > limits.max_live_facts {
                        return Err(error(
                            "state_limit",
                            "live support count exceeds host admission",
                            v,
                        ));
                    }
                }
                Mutation::Retract { fact_id } => {
                    let pair = live.remove(fact_id).ok_or_else(|| {
                        error("unknown_fact_id", "cannot retract a non-live fact ID", v)
                    })?;
                    *updates.entry(pair).or_default() -= 1;
                }
            }
        }
        for query in &epoch.queries {
            let valid = match query {
                Query::Reachable { from, to } => nodes.contains(from) && nodes.contains(to),
                Query::Impact { roots, .. } => {
                    roots.len() <= limits.max_nodes && roots.iter().all(|n| nodes.contains(n))
                }
            };
            if !valid {
                return Err(error(
                    "invalid_query",
                    "query references undeclared nodes or exceeds root count",
                    v,
                ));
            }
        }
        prepared.push(Prepared {
            version: epoch.version,
            updates: updates.into_iter().filter(|(_, d)| *d != 0).collect(),
            queries: epoch.queries.clone(),
            live_facts: live.len(),
            distinct_edges: live.values().copied().collect::<BTreeSet<_>>().len(),
        });
    }
    Ok(prepared)
}

fn answers(closure: &BTreeSet<Pair>, queries: &[Query]) -> Vec<Answer> {
    queries
        .iter()
        .map(|query| match query {
            Query::Reachable { from, to } => Answer::Reachable {
                from: *from,
                to: *to,
                reachable: closure.contains(&(*from, *to)),
            },
            Query::Impact {
                roots,
                direction,
                include_roots,
            } => {
                let roots: BTreeSet<_> = roots.iter().copied().collect();
                let mut result = BTreeSet::new();
                for &(from, to) in closure {
                    match direction {
                        Direction::Downstream if roots.contains(&from) => {
                            result.insert(to);
                        }
                        Direction::Upstream if roots.contains(&to) => {
                            result.insert(from);
                        }
                        _ => {}
                    }
                }
                if *include_roots {
                    result.extend(roots);
                }
                Answer::Impact {
                    nodes: result.into_iter().collect(),
                }
            }
        })
        .collect()
}

fn response(scope: String, provider: &str, epochs: Vec<EpochResult>) -> Response {
    Response {
        scope,
        provider: provider.into(),
        evidence: "unverified_rust_computation".into(),
        coverage: "only_the_complete_supplied_graph_at_each_version".into(),
        epochs,
    }
}

/// Fixed-policy JSON boundary for native and Python callers. Request fields
/// cannot raise admission limits or select an unbounded reference backend.
pub fn call_json(request_json: &str) -> String {
    let result = if request_json.len() > MAX_REQUEST_BYTES {
        Err(error("request_bytes_limit", "JSON exceeds 1 MiB", None))
    } else {
        serde_json::from_str::<Request>(request_json)
            .map_err(|e| error("invalid_json", e.to_string(), None))
            .and_then(|request| evaluate(request, Limits::default()))
    };
    let envelope = match result {
        Ok(result) => serde_json::json!({"status":"ok", "result":result}),
        Err(error) => serde_json::json!({"status":"refused", "error":error}),
    };
    // The envelope contains only serializable primitives and finite integers.
    serde_json::to_string(&envelope).expect("provider response serialization")
}

/// Discovery describes actual implemented operations and their assurance/cost
/// boundaries; it makes no claim of a live language route or hosted scheduler.
pub fn catalog() -> serde_json::Value {
    serde_json::json!({
        "provider":"oracle-incremental",
        "schema":1,
        "operations":["insert", "retract", "reachable", "impact"],
        "directions":["downstream", "upstream"],
        "input":"one scope, complete node universe, finite strictly ordered epochs",
        "edge_orientation":"prerequisite_to_dependent",
        "semantics":"nonempty directed paths; independently identified duplicate supports",
        "settlement":"actual timely output frontier strictly beyond requested version",
        "coverage":"only_the_complete_supplied_graph_at_each_version",
        "evidence":"unverified_rust_computation",
        "isolation":"all arrangements and capabilities destroyed before return",
        "threads_created":0,
        "worker_model":"one temporary graph on caller thread per admitted batch",
        "hard_cpu_or_rss_limit":false,
        "limits_kind":"input/state cardinality admission plus cooperative step/event/time checks",
        "limits":Limits::default(),
        "max_request_bytes":MAX_REQUEST_BYTES,
        "dependencies":{"differential-dataflow":"0.25.1", "timely":"0.31.0"}
    })
}

/// Evaluate one request on the caller's thread. No thread/process is created and
/// no graph, arrangement, tenant state or capability survives return.
///
/// Results are returned only if every requested epoch settled. A refused batch
/// publishes no partial snapshot. Callers needing hard CPU/RSS deadlines must
/// run this provider behind their globally admitted contained-process boundary.
pub fn evaluate(request: Request, limits: Limits) -> Result<Response, Error> {
    let prepared = prepare(&request, &limits)?;
    timely::execute_directly(move |worker| {
        let started = Instant::now();
        // This is bounded by the declared pair universe, not by output event count.
        let changes = Rc::new(RefCell::new(BTreeMap::<Pair, i64>::new()));
        let event_count = Rc::new(RefCell::new(0u64));
        let sink = changes.clone();
        let events = event_count.clone();
        let event_limit = limits.max_output_events_per_epoch;
        let mut input = InputSession::<u64, Pair, isize>::new();
        let dataflow_id = worker.next_dataflow_index();
        let probe = worker.dataflow::<u64, _, _>(|scope| {
            // Distinct edges preserve duplicate support: retracting one support
            // does not remove an edge while another identified support is live.
            let edges = input.to_collection(scope).distinct();
            let closure = edges.clone().iterate(|inner, paths| {
                let edges = edges.clone().enter(inner);
                // paths(a,b) join edges(b,c), seeded by direct edges each round.
                paths
                    .map(|(a, b)| (b, a))
                    .join_map(edges.clone(), |_b, &a, &c| (a, c))
                    .concat(edges)
                    .distinct()
            });
            let (probe, _) = closure
                .inspect(move |&(pair, _time, diff)| {
                    let mut count = events.borrow_mut();
                    *count = count.saturating_add(1);
                    if *count <= event_limit {
                        let mut pending = sink.borrow_mut();
                        let weight = pending.entry(pair).or_default();
                        *weight += diff as i64;
                        if *weight == 0 {
                            pending.remove(&pair);
                        }
                    }
                })
                .probe();
            probe
        });
        let run = (|| {
            let mut current = BTreeSet::<Pair>::new();
            let mut results = Vec::new();
            let mut response_items = 0usize;
            for epoch in prepared {
                let tick = Instant::now();
                *event_count.borrow_mut() = 0;
                input.advance_to(epoch.version);
                for &(pair, diff) in &epoch.updates {
                    input.update(pair, diff);
                }
                let closed = epoch.version + 1;
                input.advance_to(closed);
                input.flush();
                let mut steps = 0;
                // The frontier check is the semantic barrier. Input flush alone
                // cannot establish that recursive retractions have completed.
                while probe.less_than(&closed) {
                    if steps >= limits.max_steps_per_epoch
                        || started.elapsed().as_millis() >= u128::from(limits.max_elapsed_ms)
                    {
                        return Err(error(
                            "cooperative_budget",
                            "epoch did not settle before its step/time budget",
                            Some(epoch.version),
                        ));
                    }
                    if *event_count.borrow() > event_limit {
                        return Err(error(
                            "output_event_limit",
                            "observed event budget exceeded before settlement",
                            Some(epoch.version),
                        ));
                    }
                    worker.step();
                    steps += 1;
                }
                if *event_count.borrow() > event_limit {
                    return Err(error(
                        "output_event_limit",
                        "observed event budget exceeded",
                        Some(epoch.version),
                    ));
                }
                let mut delta = Vec::new();
                for ((from, to), diff) in std::mem::take(&mut *changes.borrow_mut()) {
                    let valid = match diff {
                        1 => current.insert((from, to)),
                        -1 => current.remove(&(from, to)),
                        _ => false,
                    };
                    if !valid {
                        return Err(error(
                            "invalid_output_weight",
                            "settled closure violated set semantics",
                            Some(epoch.version),
                        ));
                    }
                    delta.push(RelationChange { from, to, diff });
                }
                let answers = answers(&current, &epoch.queries);
                response_items = response_items
                    .saturating_add(delta.len())
                    .saturating_add(answers.len());
                for answer in &answers {
                    if let Answer::Impact { nodes } = answer {
                        response_items = response_items.saturating_add(nodes.len());
                    }
                }
                if response_items > limits.max_response_items {
                    return Err(error(
                        "response_limit",
                        "retained response exceeds host admission",
                        Some(epoch.version),
                    ));
                }
                results.push(EpochResult {
                    version: epoch.version,
                    settled: true,
                    frontier: probe.with_frontier(|f| f.to_vec()),
                    live_facts: epoch.live_facts,
                    distinct_edges: epoch.distinct_edges,
                    reachable_pairs: current.len(),
                    delta,
                    answers,
                    elapsed_us: tick.elapsed().as_micros().min(u128::from(u64::MAX)) as u64,
                    worker_steps: steps,
                    observed_output_events: *event_count.borrow(),
                });
            }
            Ok(response(
                request.scope,
                "differential_dataflow_0.25.1",
                results,
            ))
        })();
        // execute_directly drains surviving graphs after the closure returns.
        // Remove this graph even on refusal so draining cannot evade our budget.
        worker.drop_dataflow(dataflow_id);
        run
    })
}

/// Independent fresh breadth-first recomputation for the comparison harness.
/// No differential operators or old reachability results participate.
/// This reference checks input/state admission, but not cooperative execution
/// or retained-response budgets. It is not exposed by the JSON provider.
pub fn recompute(request: &Request, limits: &Limits) -> Result<Response, Error> {
    let prepared = prepare(request, limits)?;
    let mut weights = BTreeMap::<Pair, isize>::new();
    let mut previous = BTreeSet::new();
    let mut results = Vec::new();
    for epoch in prepared {
        let started = Instant::now();
        for (pair, diff) in epoch.updates {
            *weights.entry(pair).or_default() += diff;
        }
        let mut adjacency = BTreeMap::<Node, Vec<Node>>::new();
        for (&(from, to), &weight) in &weights {
            if weight > 0 {
                adjacency.entry(from).or_default().push(to);
            }
        }
        let mut closure = BTreeSet::new();
        for &root in &request.nodes {
            let mut seen = BTreeSet::new();
            let mut queue: VecDeque<_> = adjacency
                .get(&root)
                .into_iter()
                .flatten()
                .copied()
                .collect();
            while let Some(node) = queue.pop_front() {
                if seen.insert(node) {
                    closure.insert((root, node));
                    queue.extend(adjacency.get(&node).into_iter().flatten().copied());
                }
            }
        }
        let mut delta: Vec<_> = closure
            .difference(&previous)
            .map(|&(from, to)| RelationChange { from, to, diff: 1 })
            .collect();
        delta.extend(
            previous
                .difference(&closure)
                .map(|&(from, to)| RelationChange { from, to, diff: -1 }),
        );
        delta.sort_by_key(|r| (r.from, r.to));
        let result = EpochResult {
            version: epoch.version,
            settled: true,
            frontier: vec![epoch.version + 1],
            live_facts: epoch.live_facts,
            distinct_edges: epoch.distinct_edges,
            reachable_pairs: closure.len(),
            answers: answers(&closure, &epoch.queries),
            delta,
            elapsed_us: started.elapsed().as_micros().min(u128::from(u64::MAX)) as u64,
            worker_steps: 0,
            observed_output_events: 0,
        };
        previous = closure;
        results.push(result);
    }
    Ok(response(
        request.scope.clone(),
        "fresh_breadth_first_reference",
        results,
    ))
}
