# Dependency changes, without rebuilding every answer

This provider maintains directed reachability while supplied facts are inserted
and retracted. An edge points from a prerequisite to its dependent. It answers
“can A affect B?”, “what depends on these changed facts?” and “what prerequisites
can reach this answer?” for every settled version in a finite request.

It runs actual differential-dataflow operators: distinct supported edges,
recursive join and union, and distinct reachable pairs. Cycles are allowed.
Two separately identified facts can support the same edge; withdrawing one
leaves the other intact. Removing the last support retracts paths that no longer
exist, including paths through cycles. Changes and answers are sorted.

The provider is handwritten Rust with authored comparison checks. It has no
Isabelle theorem and is not a proof checker. It does not infer missing source
facts, parse questions, evaluate arbitrary Datalog, or implement default logic.
A negative answer means no path in the complete **supplied** graph at that
version. It cannot establish that no dependency exists in an external corpus.

## Operations and versions

The JSON request has an opaque `scope`, a complete `nodes` universe, and ordered
`epochs`. Each epoch contains a strictly increasing `version`, `mutations` and
optional `queries`. Versions need not be contiguous. `u64::MAX` is refused.
Unknown JSON fields are refused. See [the complete demo](examples/supports-cycle.json).

- `insert {fact_id, from, to}` adds an identified support. A live fact ID cannot
  be overwritten. Different IDs can support identical edges.
- `retract {fact_id}` withdraws exactly that live support. An unknown ID is an
  error. Retract then reinsert can replace a support atomically within one epoch.
- `reachable {from, to}` asks for a nonempty directed path. A node reaches itself
  only if there is a cycle/self-loop, rather than by an implicit identity edge.
- `impact {roots, direction, include_roots}` returns a sorted union.
  `downstream` follows dependency edges; `upstream` follows their reverse.
  `include_roots` adds roots without requiring paths. When false, roots still
  occur if reached through cycles; it is not a filter that removes roots.

The complete mutation history is validated before any dataflow starts. Within an
epoch, support IDs are validated in mutation order, but only the final settled
graph is observable. Insert/retract cancellation in one epoch produces no delta.

The provider advances input time to `version + 1`, flushes it, and steps the
worker until the output probe frontier is strictly beyond `version`. Flush alone
is insufficient: recursive retractions must settle too. Each result includes the
actual frontier, `settled: true`, live support and edge counts, reachable-pair
count, consolidated `delta` rows with `diff` equal to +1/-1, query answers, and
microsecond/worker-step/output-event counters. Empty deltas are meaningful.

No partial snapshot escapes on an error: a refused batch returns an error with a
code and, where relevant, the failing version. Earlier settled epochs in that
batch are discarded. The input graph and all dataflows are dropped on both
success and refusal. Later requests never see prior facts, even with identical
node/fact IDs. `scope` is echoed for identity binding; the host must authenticate
it and choose the permitted data. A label is not access control.

## Costs and containment

`evaluate(Request, Limits)` runs on the calling thread; it creates no worker
thread or process. One batch owns one graph. There is no per-tenant resident
worker, hosted scheduler, cross-request cache, durable overlay or restart
recovery claim. A host should invoke it through its globally admitted provider
pool. Persistent serving should first consider demand-driven closures for a
bounded set of roots rather than maintaining every reachable pair for every
tenant.

Default host limits admit 128 nodes, 2,048 live identified supports, 256 epochs,
16,384 mutations, 4,096 queries and 128 bytes per scope/fact ID. The admitted
node universe squared must fit 16,384 possible relation pairs. The CLI accepts
at most 1 MiB of UTF-8 JSON. Callers of the typed API are responsible for bounding
JSON decoding before constructing a request. Limits are host arguments, never
request fields.

`call_json(&str) -> String` applies the same fixed 1 MiB cap before decoding,
uses immutable default limits, and returns a `status: ok` result envelope or
`status: refused` error envelope. `catalog()` (CLI `--catalog`) reports operations,
default limits, semantics, evidence type and containment boundaries. Bindings
should use this boundary rather than exposing caller-controlled `Limits`.

All-pairs closure is O(V²) live output even for sparse input. Each version can
change O(V²) output pairs. Up to 262,144 delta/answer rows and answer nodes may be
retained across a response; the check occurs after the current epoch's bounded
answers are constructed. Preflight stores the admitted finite history. The
node, support, history and possible output cardinalities are admission bounds,
not byte-accurate memory measurements. Internal arrangements, intermediate joins
and iterative timestamp histories consume additional memory, and a join can
perform O(V³) candidate work in a round. No hard RSS limit is implemented here.

The 10-second elapsed budget is checked between worker steps, with at most
1,000,000 steps and 2,000,000 observed output events per epoch. Output events
include updates that later cancel. A single `worker.step()` is not preempted;
these are **cooperative** limits, not hard CPU or wall-clock limits. Parsing,
preflight, answer construction and graph destruction are outside the step
checks. A production hard deadline/RSS limit requires a contained process owned
by the host, with global admission and termination by that process's recorded
PID. The provider explicitly removes its dataflow before returning so timely's
automatic drain cannot bypass a refusal by continuing the recursive graph.

## Checks and a measurement surface

Root registers `oracle-incremental` in the workspace and refreshes the lockfile.
Dependencies are pinned differential-dataflow 0.25.1 and timely 0.31.0 (Rust 1.86
or newer), with Serde/serde_json from the workspace. They are MIT licensed; this
wrapper's `forbid(unsafe_code)` does not make a claim about dependency internals.

Run centrally on the designated build host, with two Cargo jobs:

```sh
CARGO_BUILD_JOBS=2 cargo test -p oracle-incremental --test semantics
cargo run -p oracle-incremental -- --demo
cargo run -p oracle-incremental -- --catalog
cargo run --release -p oracle-incremental -- --benchmark
cargo run -p oracle-incremental < oracle-incremental/examples/supports-cycle.json
```

The ten focused tests compare every version's full consolidated delta and answers
against independent fresh BFS, not against the differential implementation's
own intermediate state. Explicit cases cover alternate paths, duplicate
supports, removal of one/last support, cycle removal, full teardown, isolated
nodes, self-loops, ID reuse, skipped versions, scope isolation, malformed
history and cooperative refusal cleanup. A deterministic 96-version mixed
history adds cycles, duplicates and self-loops without a random dependency.

`--benchmark` emits JSON for the same 48-node chain across 80 versions, toggling
the tail edge. It compares complete semantics before reporting total and per
version times for maintained differential closure and fresh BFS. Total times
include validation and result construction; differential total also includes
graph construction/destruction. Per-epoch incremental times include update,
settlement, delta and query construction; fresh times include rebuilding
adjacency, BFS, delta and query construction. This is a deliberately bounded
measurement workload, not a claim that differential beats BFS. Both approaches
produce the full view delta, so output costs are charged to both.

No specialist-panel numbers are available for this new capability. Focused
checks and synthetic timings do not count as shipped panel completion.

## Useful consumers, and what still needs an adapter

These are concrete extensions enabled by the supplied-graph operation, not
claims of deployed specialist behavior:

- Revision-aware lessons and answer lineage: withdraw a lesson's dependency
  facts and find affected conclusions. `native/oracle-core/src/session.rs`
  already represents `AnswerLineage` and `EffectLineage`, but it does not yet
  store the dependency edges this provider needs. The adapter must retain
  source/support IDs and version/authority binding, and decide whether an
  affected answer should be rechecked or withdrawn. Reachability identifies
  possible impact; it does not recompute the answer or prove it false.
- Build, package, workflow and prerequisite specialists: supplied dependency
  graphs can answer “which jobs need rechecking after this component changes?”
  and “what does this task transitively require?” under edge revisions. This
  adds a reusable dependency capability rather than another fixed formula.
- Networking extension: shipped `networking/organ_networking_v1.py` handles
  IPv4/CIDR arithmetic. A new supplied-topology operation could answer changing
  connectivity questions, including link withdrawal. Model an undirected link
  as two directed supports. Reachability alone does not model ACLs, capacities,
  routing policy, latency, or actual packet delivery.
- Ecology extension: shipped `ecology/organ_ecology_v1.py` handles population
  and diversity arithmetic. A supplied directed interaction graph could answer
  potential downstream exposure after a species/interaction withdrawal. A
  path is not a quantitative population prediction, causal proof, or substitute
  for the current formulas.

A specialist route, parser, source-coverage checks, evidence links and authored
panel/scorer are still needed before any of these is a shipped specialist. The
provider does not automatically invalidate external caches or write session
state. The native host must bind overlay revision/authority to its actual
transaction rather than accepting a request's scope label as a guarantee.

## Why differential, and what the papers establish

McSherry, Murray, Isaacs and Isard's [CIDR 2013 paper](https://www.cidrdb.org/cidr2013/Papers/CIDR13_Paper111.pdf)
introduces partially ordered versions to reuse work across input epochs and
loop iterations. Its nested iterative graph examples motivate maintaining
closure under a history of changes. Here, outer time is the input version and
inner time is the fixed-point iteration; a final `distinct` consolidates feedback
so canceling changes do not circulate forever.

Budiu, McSherry, Ryzhyk and Tannen's [DBSP paper](https://arxiv.org/abs/2203.16684),
sections 5–6, describes nested incremental fixed-point evaluation and preserving
changes to recursive relations. The local corpus file is named 2023 but contains
the arXiv v1 header dated 30 March 2022; this implementation relies on the
sections in that supplied text rather than asserting a publication identity.
Its integer-weight/set distinction motivates tracking supports before
set-thresholding edges. Neither paper verifies this wrapper or guarantees
speedups for small graphs.

Implementation APIs were inspected in the exact published crates
[differential-dataflow 0.25.1](https://docs.rs/differential-dataflow/0.25.1/differential_dataflow/)
and [timely 0.31.0](https://docs.rs/timely/0.31.0/timely/), particularly recursive
`iterate`, `distinct`, input-session flushing, frontier probes and explicit graph
destruction. Runtime resource containment and Oracle integration remain host
contracts.
