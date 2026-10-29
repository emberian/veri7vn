//! Fixed-root closure: retain only demanded source/target rows, O(R*V) output.
//! Strategy is a host decision. Fresh and maintained strategies share admission
//! and answers, while retaining independently implemented traversal algorithms.
use super::*;

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Strategy {
    Fresh,
    Differential,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Roots {
    pub downstream: Vec<Node>,
    pub upstream: Vec<Node>,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RootedOperation {
    RootedV2,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RootedRequest {
    pub operation: RootedOperation,
    pub roots: Roots,
    pub graph: Request,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RootedResponse {
    pub schema: u32,
    pub roots: Roots,
    pub strategy: Strategy,
    /// Fresh uses a logical closed version, not a fabricated timely probe.
    pub settlement: String,
    pub possible_pairs_bound: usize,
    pub fresh_work: Vec<u64>,
    pub result: Response,
}

fn validate(request: &RootedRequest, limits: &Limits) -> Result<(Vec<Prepared>, usize), Error> {
    if request.graph.nodes.len() > limits.max_nodes
        || request.roots.downstream.len() > limits.max_nodes
        || request.roots.upstream.len() > limits.max_nodes
    {
        return Err(error(
            "input_limit",
            "node or root count exceeds host admission",
            None,
        ));
    }
    let universe: BTreeSet<_> = request.graph.nodes.iter().copied().collect();
    let down: BTreeSet<_> = request.roots.downstream.iter().copied().collect();
    let up: BTreeSet<_> = request.roots.upstream.iter().copied().collect();
    if down.len() != request.roots.downstream.len()
        || up.len() != request.roots.upstream.len()
        || !down.is_subset(&universe)
        || !up.is_subset(&universe)
    {
        return Err(error(
            "invalid_roots",
            "roots must be unique declared nodes in each direction",
            None,
        ));
    }
    // The union may overlap; admit its conservative product bound.
    let bound = down
        .len()
        .checked_add(up.len())
        .and_then(|r| r.checked_mul(universe.len()));
    let prepared = prepare_with_pair_bound(&request.graph, limits, bound)?;
    for epoch in &prepared {
        for query in &epoch.queries {
            let permitted = match query {
                Query::Reachable { from, to } => down.contains(from) || up.contains(to),
                Query::Impact {
                    roots,
                    direction: Direction::Downstream,
                    ..
                } => roots.iter().all(|r| down.contains(r)),
                Query::Impact {
                    roots,
                    direction: Direction::Upstream,
                    ..
                } => roots.iter().all(|r| up.contains(r)),
            };
            if !permitted {
                return Err(error(
                    "untracked_query",
                    "query needs a root outside the fixed admitted set",
                    Some(epoch.version),
                ));
            }
        }
    }
    Ok((prepared, bound.unwrap_or(0)))
}

fn check_time(started: Instant, limits: &Limits, version: u64) -> Result<(), Error> {
    if started.elapsed().as_millis() >= u128::from(limits.max_elapsed_ms) {
        return Err(error(
            "cooperative_budget",
            "batch elapsed budget exceeded",
            Some(version),
        ));
    }
    Ok(())
}

fn charge(work: &mut u64, started: Instant, limits: &Limits, version: u64) -> Result<(), Error> {
    *work = work.saturating_add(1);
    if *work > limits.max_fresh_work_per_epoch {
        return Err(error(
            "cooperative_budget",
            "fresh traversal work budget exceeded",
            Some(version),
        ));
    }
    if *work & 255 == 0 {
        check_time(started, limits, version)?;
    }
    Ok(())
}

/// Measurements taken by the selected engine for one settled input epoch.
struct EpochTelemetry {
    frontier: Vec<u64>,
    started: Instant,
    worker_steps: u64,
    output_events: u64,
}

fn append_epoch(
    current: &BTreeSet<Pair>,
    delta: Vec<RelationChange>,
    epoch: &Prepared,
    telemetry: EpochTelemetry,
    retained_items: &mut usize,
    limits: &Limits,
) -> Result<EpochResult, Error> {
    let answers = answers(current, &epoch.queries);
    *retained_items = retained_items
        .saturating_add(delta.len())
        .saturating_add(answers.len());
    for answer in &answers {
        if let Answer::Impact { nodes } = answer {
            *retained_items = retained_items.saturating_add(nodes.len());
        }
    }
    if *retained_items > limits.max_response_items {
        return Err(error(
            "response_limit",
            "retained response exceeds host admission",
            Some(epoch.version),
        ));
    }
    Ok(EpochResult {
        version: epoch.version,
        settled: true,
        frontier: telemetry.frontier,
        live_facts: epoch.live_facts,
        distinct_edges: epoch.distinct_edges,
        reachable_pairs: current.len(),
        delta,
        answers,
        elapsed_us: telemetry
            .started
            .elapsed()
            .as_micros()
            .min(u128::from(u64::MAX)) as u64,
        worker_steps: telemetry.worker_steps,
        observed_output_events: telemetry.output_events,
    })
}

/// Identical root-restricted view semantics for both explicitly chosen engines.
/// No root can be added mid-batch. All requested queries are checked before work.
/// The monotone outer versions define logical completion in fresh mode; the
/// differential engine additionally supplies its actual timely probe frontier.
pub fn evaluate_rooted(
    request: RootedRequest,
    limits: Limits,
    strategy: Strategy,
) -> Result<RootedResponse, Error> {
    let started = Instant::now();
    let (prepared, bound) = validate(&request, &limits)?;
    if let Some(first) = prepared.first() {
        check_time(started, &limits, first.version)?;
    }
    let (epochs, fresh_work) = match strategy {
        Strategy::Fresh => fresh(&request, prepared, &limits, started)?,
        Strategy::Differential => maintained(&request, prepared, limits, started)?,
    };
    Ok(RootedResponse {
        schema: 2,
        roots: request.roots,
        strategy,
        settlement: match strategy {
            Strategy::Fresh => "fresh_recomputation_complete",
            Strategy::Differential => "timely_output_frontier",
        }
        .into(),
        possible_pairs_bound: bound,
        fresh_work,
        result: response(
            request.graph.scope,
            match strategy {
                Strategy::Fresh => "rooted_fresh_bfs_v2",
                Strategy::Differential => "rooted_differential_v2",
            },
            epochs,
        ),
    })
}

fn fresh(
    request: &RootedRequest,
    prepared: Vec<Prepared>,
    limits: &Limits,
    started: Instant,
) -> Result<(Vec<EpochResult>, Vec<u64>), Error> {
    let index: BTreeMap<_, _> = request
        .graph
        .nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (*n, i))
        .collect();
    let n = index.len();
    let mut supports = BTreeMap::<Pair, isize>::new();
    let mut previous = BTreeSet::new();
    let mut results = Vec::new();
    let mut work_log = Vec::new();
    let mut retained = 0;
    for epoch in prepared {
        let tick = Instant::now();
        let mut work = 0;
        check_time(started, limits, epoch.version)?;
        for &(pair, diff) in &epoch.updates {
            charge(&mut work, started, limits, epoch.version)?;
            let count = supports.entry(pair).or_default();
            *count += diff;
            if *count == 0 {
                supports.remove(&pair);
            }
        }
        // Rebuild dense adjacency once per epoch, not once per root. Counts
        // retain O(E) live state, never an unconditional V-squared matrix.
        let mut forward = vec![Vec::<usize>::new(); n];
        let mut reverse = vec![Vec::<usize>::new(); n];
        for &(from, to) in supports.keys() {
            charge(&mut work, started, limits, epoch.version)?;
            let a = index[&from];
            let b = index[&to];
            forward[a].push(b);
            reverse[b].push(a);
        }
        let mut current = BTreeSet::new();
        let mut seen = vec![0usize; n];
        let mut generation = 0usize;
        let mut queue = VecDeque::new();
        for (reversed, roots, adjacency) in [
            (false, &request.roots.downstream, &forward),
            (true, &request.roots.upstream, &reverse),
        ] {
            for &root in roots {
                generation += 1;
                charge(&mut work, started, limits, epoch.version)?;
                // Identity is not seeded: self requires a nonempty cycle.
                queue.extend(adjacency[index[&root]].iter().copied());
                while let Some(node) = queue.pop_front() {
                    charge(&mut work, started, limits, epoch.version)?;
                    if seen[node] != generation {
                        seen[node] = generation;
                        let external = request.graph.nodes[node];
                        current.insert(if reversed {
                            (external, root)
                        } else {
                            (root, external)
                        });
                        // Every enqueued neighbor is later charged, including duplicates.
                        queue.extend(adjacency[node].iter().copied());
                    }
                }
            }
        }
        let mut delta: Vec<_> = current
            .difference(&previous)
            .map(|&(from, to)| RelationChange { from, to, diff: 1 })
            .collect();
        delta.extend(
            previous
                .difference(&current)
                .map(|&(from, to)| RelationChange { from, to, diff: -1 }),
        );
        delta.sort_by_key(|r| (r.from, r.to));
        let result = append_epoch(
            &current,
            delta,
            &epoch,
            EpochTelemetry {
                frontier: vec![epoch.version + 1],
                started: tick,
                worker_steps: 0,
                output_events: 0,
            },
            &mut retained,
            limits,
        )?;
        // Fresh has no internal update stream. Output-event admission charges
        // actual set changes so callers cannot evade output limits by policy.
        if result.delta.len() as u64 > limits.max_output_events_per_epoch {
            return Err(error(
                "output_event_limit",
                "fresh output delta exceeds host admission",
                Some(epoch.version),
            ));
        }
        check_time(started, limits, epoch.version)?;
        previous = current;
        work_log.push(work);
        results.push(result);
    }
    Ok((results, work_log))
}

fn maintained(
    request: &RootedRequest,
    prepared: Vec<Prepared>,
    limits: Limits,
    started: Instant,
) -> Result<(Vec<EpochResult>, Vec<u64>), Error> {
    let roots = request.roots.clone();
    timely::execute_directly(move |worker| {
        let changes = Rc::new(RefCell::new(BTreeMap::<Pair, i64>::new()));
        let events = Rc::new(RefCell::new(0u64));
        let sink = changes.clone();
        let counter = events.clone();
        let event_limit = limits.max_output_events_per_epoch;
        let mut edges_input = InputSession::<u64, Pair, isize>::new();
        let mut roots_input = InputSession::<u64, (bool, Node), isize>::new();
        let id = worker.next_dataflow_index();
        let probe = worker.dataflow::<u64, _, _>(|scope| {
            let edges = edges_input.to_collection(scope).distinct();
            // A direction bit shares one recursive operator graph between the
            // two orientations while retaining only admitted root labels.
            let oriented = edges.flat_map(|(a, b)| [((false, a), b), ((true, b), a)]);
            let seeds = roots_input
                .to_collection(scope)
                .map(|r| (r, ()))
                .join_map(oriented.clone(), |&(rev, root), _, &node| (rev, root, node));
            let closure = seeds.clone().iterate(|inner, paths| {
                let edges = oriented.clone().enter(inner);
                let seeds = seeds.clone().enter(inner);
                paths
                    .map(|(rev, root, node)| ((rev, node), root))
                    .join_map(edges, |&(rev, _), &root, &dest| (rev, root, dest))
                    .concat(seeds)
                    .distinct()
            });
            // Downstream/upstream root sets can expose the same directed pair;
            // union it once before reporting changes and answering queries.
            let (probe, _) = closure
                .map(|(rev, root, node)| if rev { (node, root) } else { (root, node) })
                .distinct()
                .inspect(move |&(pair, _time, diff)| {
                    let mut count = counter.borrow_mut();
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
        for &root in &roots.downstream {
            roots_input.insert((false, root));
        }
        for &root in &roots.upstream {
            roots_input.insert((true, root));
        }
        // Fixed roots never hold back a later input epoch's output frontier.
        roots_input.close();
        let run = (|| {
            let mut current = BTreeSet::new();
            let mut results = Vec::new();
            let mut retained = 0;
            for epoch in prepared {
                let tick = Instant::now();
                *events.borrow_mut() = 0;
                edges_input.advance_to(epoch.version);
                for &(pair, diff) in &epoch.updates {
                    edges_input.update(pair, diff);
                }
                let closed = epoch.version + 1;
                edges_input.advance_to(closed);
                edges_input.flush();
                let mut steps = 0;
                while probe.less_than(&closed) {
                    check_time(started, &limits, epoch.version)?;
                    if steps >= limits.max_steps_per_epoch {
                        return Err(error(
                            "cooperative_budget",
                            "maintained step budget exceeded",
                            Some(epoch.version),
                        ));
                    }
                    if *events.borrow() > event_limit {
                        return Err(error(
                            "output_event_limit",
                            "maintained event budget exceeded",
                            Some(epoch.version),
                        ));
                    }
                    worker.step();
                    steps += 1;
                }
                if *events.borrow() > event_limit {
                    return Err(error(
                        "output_event_limit",
                        "maintained event budget exceeded",
                        Some(epoch.version),
                    ));
                }
                let mut delta = Vec::new();
                for (pair, diff) in std::mem::take(&mut *changes.borrow_mut()) {
                    let valid = match diff {
                        1 => current.insert(pair),
                        -1 => current.remove(&pair),
                        _ => false,
                    };
                    if !valid {
                        return Err(error(
                            "invalid_output_weight",
                            "rooted closure violated set semantics",
                            Some(epoch.version),
                        ));
                    }
                    delta.push(RelationChange {
                        from: pair.0,
                        to: pair.1,
                        diff,
                    });
                }
                let result = append_epoch(
                    &current,
                    delta,
                    &epoch,
                    EpochTelemetry {
                        frontier: probe.with_frontier(|f| f.to_vec()),
                        started: tick,
                        worker_steps: steps,
                        output_events: *events.borrow(),
                    },
                    &mut retained,
                    &limits,
                )?;
                check_time(started, &limits, epoch.version)?;
                results.push(result);
            }
            Ok((results, Vec::new()))
        })();
        worker.drop_dataflow(id);
        run
    })
}
