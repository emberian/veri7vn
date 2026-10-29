# NI: supplied dependency revisions, 29 October 2026

Owner: Codex incremental lane. No shipped specialist-panel numbers yet.
No new theorem, axiom or extracted assurance claim. Rust is handwritten and
unverified; comparison checks are empirical evidence.

## What changed

`native/oracle-incremental/Cargo.toml`, `src/lib.rs`, `src/main.rs`,
`tests/semantics.rs`, `examples/supports-cycle.json` and `README.md` implement an
isolated finite JSON/typed provider for dependency revisions. Edges run from
prerequisite to dependent. `insert` and `retract` manipulate identified supports;
`reachable` and `impact` query maintained directed closure after every settled
version. Actual differential-dataflow distinct/recursive join/union operators
retain the closure between epochs. This is not merely a fresh graph algorithm
behind a differential label.

`evaluate(Request, Limits)` owns one batch and uses the caller thread, with no
per-tenant worker. Every output waits for the actual timely probe frontier past
its input version. Duplicate support IDs are refused; separate IDs may support
the same edge. Removing one of two supports preserves the edge; the last support
withdrawal updates all affected paths. Cycles, self-loops, alternate paths and
noncontiguous versions are explicit. Reachability uses nonempty paths; identity
requires a cycle. Results carry scope, actual frontier, consolidated changes,
query answers and timing/work counters. No partial batch result escapes refusal.

Node/support/history/pair/response cardinality admission and cooperative
step/event/elapsed budgets are documented. O(V²) all-pairs state and additional
arrangement/iteration memory are explicit. An individual worker step is not
preempted; hard RSS/CPU containment remains a host job. The dataflow is explicitly
dropped before returning on either success or refusal so timely's drain does
not continue budget-refused work. `scope` is not authentication. Absence applies
only to the supplied graph.

## Checks authored and execution boundary

Ten focused `semantics` tests compare complete per-version delta and query
answers to independent fresh BFS, including duplicate and last support removal,
alternate paths, a broken cycle that cannot self-support, self-loops, full
teardown, empty scope isolation, ID reuse, skipped versions, bad histories,
cardinality limits, step/event/response refusal cleanup, and a deterministic
96-version mixed-update history. The CLI has a 1 MiB request cap. A demo contains
five nodes, duplicate supports, a cycle, an isolated node and four revisions.

`--benchmark` compares a 48-node chain over 80 versions, toggling its tail edge,
using the same histories and checking complete semantic equality. It emits JSON
with cold total times, per-version maintenance/recompute times, worker steps and
observed output events. No performance result or speedup is asserted without
root's central run.

Lane ran no build or test on the shared/local machines. Root's first central
`cargo test -p oracle-incremental --test semantics` passed all original nine tests
on hbox in 0.11 seconds (root's reported result). The subsequently added tenth
test covers byte refusal, fixed JSON policy and discovery; its central result
is pending. Root owns execution on
hbox `/tank/lanes/o7-native-20261028`, with `CARGO_BUILD_JOBS=2`:
`cargo test -p oracle-incremental --test semantics`, followed by demo and release
benchmark. Timing results remain pending central integration.

## Integration and consumers

Root must register the workspace member and refresh Cargo.lock. This crate pins
`differential-dataflow =0.25.1`, `timely =0.31.0`, requires Rust >=1.86, and uses
workspace Serde/serde_json. No lane edits workspace/lockfile or downstream
bindings. `call_json(&str) -> String` provides a 1 MiB fixed-policy result/error
envelope; `catalog()` reports operations and the serialized host defaults.
Optional Python/native provider exposure remains root integration.

The README maps concrete proposed consumers: lesson/answer lineage impact
(existing native `AnswerLineage`/`EffectLineage` needs dependency/source adapters),
new build/workflow/prerequisite specialists, changing supplied network topology
(existing networking specialist handles CIDR arithmetic), and potential food-web
exposure queries (existing ecology specialist handles growth/diversity).
None is claimed to have a live question route or panel/scorer yet. Source
coverage, source/support evidence IDs, authority/revision transaction binding,
and actual affected-answer rechecks remain required adapters.

Grounding: McSherry et al., CIDR 2013, partially ordered input/iteration versions;
Budiu et al., supplied DBSP text sections 5–6, incremental recursive fixed points
and nested streams. The DBSP local filename says 2023 but the supplied text's
header is arXiv v1 dated 30 March 2022. Exact published crate source was consulted
for modern APIs, frontier semantics and graph destruction; papers do not verify
this implementation. See crate README for source links and boundaries.

## Root integration receipt

All ten semantics tests passed on hbox. The actual PyO3 call passed the support/cycle example. The 48-node/80-version benchmark matched every delta and answer but took 74.234 ms versus 7.556 ms for fresh BFS; no incremental speedup is claimed.

See [central validation](../../native/evidence/2026-10-29-validation.json).
