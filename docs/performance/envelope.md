# Performance envelope — revision 2 foundation

Measure the executed product, with semantic oracles and exact artifact/workload identity. C04/C05, D03/D11, ACC-12 and PO-07/10 govern this envelope. [Installed measurements](installed-runtime-pilot.md) provide finite baselines; generated probes and Scala fixture builds remain separate evidence.

```sh
python3 tools/performance/envelope/report.py validate
python3 tools/performance/envelope/report.py summarize
python3 tools/performance/envelope/check_collector.py
```

These validate/summarize existing records without launching Isabelle. [`workloads.json`](../../benchmarks/envelope/workloads.json) is the machine-readable workload/cost contract. Actual native/runtime measurements use the sole steward and shared lock; never delete shared caches to manufacture cold conditions.

## Baseline evidence and budgets

| Constraint | Status |
|---|---|
| Warm small pure calculation/lookup p95 100 ms; control/codec 10 ms | Provisional design targets; representative repeated native evidence must set budgets |
| Decoded-source cache 256 MiB | Provisional configurable bound; ML/JVM/worker/file-cache peaks measured separately |
| No compilation on poll, ordinary observation or existing-operation plan | Architectural invariant; check compilation counters and executable generation |
| Finite enumeration | Declare exact state count/integer width before running; workload n=8/16/24/32, explicit time/fuel/bytes and 1024-row materialization/pagination/refusal |
| Regression percentage | Unset until repeated baseline/candidate samples, noise estimate, correctness oracle and reviewed threshold |

Historical `audit/results/baseline.jsonl` records legacy load 14.786 s, reported max RSS 467,042,304 B and sixteen heterogeneous requests with general reader disabled. Internal latency differs from external wall. `experiments/native-execution/startup.json` is a feasibility startup, not the same application. Neither supports a cross-system speedup ratio.

## Measurement contract

Record revision/dirty digests; hardware/OS/RAM/cores/power mode; Isabelle/Scala/JVM/PolyML/compiler/settings; heap/bundle/code setup; source/index sizes; state and cache conditions; repetitions, order, concurrency and competing work. Separate startup, first request and warm steady state, cold/attach admission, update and all five growth tiers.

Attribute queue, interpretation, retrieval, search, execution, reconstruction/checking, commit, protocol and rendering. Capture monotonic intervals, CPU, allocation/GC, process live/peak RSS, input/output/certificate bytes, logical/physical I/O, states, integer bits and materialized rows. Missing counters are null with reasons. Parent/nested spans overlap: do not sum them or mix independent clocks. Report median/p95/max with sample count/quantile method.

Cancellation records request, acknowledgment and worker quiescence, uninterruptible intervals, memory afterward and late/unknown attempt state. Measure foreground alone and alongside polling, qualification and candidate compilation. A payload reservation is not a measured heap/RSS cap. Keep raw private traces, source payloads/heaps/credentials local.

## Semantic workload oracles

Preserve interpretation, domain/units, ambiguity/refusal, per-part blockers and typed intermediate values. Absence/uniqueness/ranking/count require candidate-region coverage; prefixes and stale/missing pages remain incomplete. Distinguish fast prefix extraction from complete query work.

Qualification pins baseline/candidate, routing/bindings, learned state, panel/split/scorer/runtime and exposure. Count gain, false assertions, wrong interception/abstention and latency. Regression, fresh holdout, aborted/spent exposure and semantic admission differ. Nonpublishing runs fork memory and disk learning; test sessions, same-name programs, restart and changed primitives.

Growth costs: data/config/example/ranking reuse compiled kernels; reifiable declarations extend native lineage without code mutation; plans use the compiled interpreter; optional specialization retains its interpreter/refinement; new carriers/kernels/bindings/code setup compile and qualify a bundle. Measure checker/compile/amortization, old/new overlap and migration independently.

## Supported local measurements and collection interface

```sh
python3 tools/performance/envelope/local_fixtures.py
python3 tools/performance/envelope/collect.py RECEIPT --log-dir ARCHIVED_LOG_DIRECTORY
```

The local fixture executes inspected offline SQL/formats/mechanics components: thirty samples after one discarded call. SQL 0/1/20/21/100/1000-row cases include an independent complete-query oracle; hash tests expose whitespace loss; mechanics checks 9 J. [Component record](../../benchmarks/envelope/local-components.json): SQL medians 0.061–0.121 ms, literal hash 0.006 ms, kinetic energy 0.037 ms on a shared host. Prefix SQL and semantically wrong hashing are not accepted native performance.

The collector requires passed/stable receipts and exit codes, hashes actual archived logs and separates build/launcher wall from producer markers. Heap-replayed metrics retain their original measurement epoch. Failed attempts have separate diagnostic records; a passing child in a failed aggregate is identified by its own evidence.

## Verified resident host protocol probe

[Host protocol](../../benchmarks/envelope/host-protocol.json), archive `var/runtime-host/protocol-20261015T133500Z`, checks version/shape rejection, pings, interrupted sleeping future and restart. Resource creation→session/handler was 3372 ms; five ping RTTs were 16.473/1.708/1.636/0.983/0.887 ms; cancel→cancel+interrupted events 1000.617 ms. Scala command 13.173 s includes compilation/startups/shutdown; entire receipt 21.640 s. These are protocol measurements, not admitted computation, durable cancellation/quiescence or tail latency.

## Verified durable transaction probe and iteration costs

[Durable probe](../../benchmarks/envelope/host-durable.json) measures one 31.723 ms transaction over structured state: artifact write/fsync, directory fsync, verification and SQLite FULL commit; database initialization excluded. Separate-process halt-before/after/dispatch assertions exercise recovery. Driver 46.671 s includes compilation/children, not commit throughput.

Separate cached-parent checks, changed-base rebuilds, proof-worker rebuilds and requests. A changed driver or cached heap does not refresh old measurements. Other correctness-only records—projection, host failstop/combined, intake—remain under `benchmarks/envelope/`; their build walls are not operation timings.

## Paired generated-service runner design

[`paired-service-plan.json`](../../benchmarks/envelope/paired-service-plan.json) specifies real generated authority/native gate/coordinator comparisons. Prepared `ResidentServiceMeasurement.scala` times native-issued authorized token consumption through durable ack; it cannot mint tokens or substitute a test bridge. Prepared `source_phases.ML` measures actual prepare/execute/project with cleanup. Their existence is not execution evidence; run only with matching built consumers.

<a id="additional-archived-evidence"></a>
<a id="green-integration-records-and-retained-graph-pressure"></a>
<a id="deployment-cost-ranking-after-canonical-29-resource-integration"></a>
<a id="scheduled-generated-closure-pilot-after-checked-totality"></a>
<a id="actual-installed-public-firstwarmrestart-pilot"></a>

## Actual implementation cost review and next runnable seam

| Axis | Question and required consumer |
|---|---|
| Retained requests/evidence/bindings, DAG depth/width | Authority list scans/live-goal checks; vary irrelevant history separately from payload |
| Checkpoint bytes / event count | Full-state serialize/copy/fsync can create O(events×state) work; incremental journal needs an explicit replay contract |
| Source cardinality/selectivity/chunks | Complete versus prefix operations, streaming decoder, Count intermediates; include >255 rows, 64,353-byte TEXT, REAL/blob/UTF-8 and duplicates |
| Plan edges/fan-in/unique premises | `map_of`, membership and dedup costs; preserve value/history multiplicity |
| Projection/output retention | Preflight versus materialization, generated trace memory, release/cancel quiescence |
| Proof contexts/bytes/depth/private expansion | Transport bounds and cold/warm reconstruction, not one tiny theorem |
| Source files/bytes/history/sharing | Parser clones, hash/readback/fsync, resource registration and shared-hash Forget |

Source inspection nominates these axes; it does not measure hotspots. Repeated generated candidates were cached under an all-write version to avoid redundant reducers; quantify invocation/encoding counters before claiming benefit. Resource reservation fixes retain exact bounds/current-authority checks. Mandatory security/reconstruction work stays visible beside avoidable copies/scans.

## Executed generated closure pilot — first measured scaling obstruction

[Closure pilot](../../benchmarks/envelope/closure-pilot.json) pins stable receipt `f4d1f5623f234ab3b424701a5d9e81ce` and actual generated `forget_closure`. Six graph shapes × n16/64/256/1024 produced 21 exact checked results and three five-second censored timeouts. Construction was separate and <17 ms/case.

| Shape | n256 wall ms | n1024 wall ms |
|---|---:|---:|
| Disconnected seed present | 0.581 | 14.841 |
| Chain | 58.580 | timeout 5041.828 |
| Dense lower triangle | 223.807 | timeout 5043.385 |
| Duplicate chain (2n records) | 759.038 | timeout 5014.119 |
| Missing seed linked | 94.561 | 4171.720 |
| Missing seed disconnected | 0.657 | 4.578 |

One fixed-order sample per case on Darwin ARM64/two ML threads is neither p95 nor pure CPU scaling; timeout CPU was ~1.77–2.02 s despite >5 s wall. Timeouts have no eventual result count. Whole driver 47.117 s/build 41.605 s includes unrelated setup/extraction. The pilot justifies proved early-fixed-point and reverse-index/worklist refinement, not lowering the supported retention cap. Compare optimized/reference semantics for duplicates, absent seeds, cycles and declared order before adoption.

## Installed public consumer: bounded first/warm/restart harness

```sh
python3 tools/performance/envelope/public_runtime.py --help
python3 tools/performance/envelope/check_public_runtime.py
```

The actual harness pins an immutable facade, exact licensed HTML, private fresh/nonempty state, process-tree observation and bounded guardian cleanup. The [installed pilot](installed-runtime-pilot.md) records startup-inclusive 22.823/14.792 s and warm 241.649/152.812 ms arithmetic observations; its separate verifier/hash-repair experiments identify launcher costs without inventing cross-run subtraction.

## Open implementation consumers

Remaining acceptance: repeated phase/tail/RSS/I/O/certificate measures for complete sources, domains, serious search, growth, UI and updates; cancellation through quiescence; polling/qualification/build interference; compilation counts by growth tier; macOS/Linux clean closure and evidence-derived enforced budgets. Component proofs and fixtures establish their own properties, not these product performance claims.
