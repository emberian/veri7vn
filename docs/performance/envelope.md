# Performance envelope — revision 2 foundation

This envelope consumes C04/C05 and D03/D11, the architecture growth tiers and
runtime-review §8. It defines acceptance workloads for the full product. The
installed public arithmetic pilot at the end now supplies a narrowly scoped real
application baseline; earlier probe sections retain their historical limitations.
The Python utilities are development evidence tools, not runtime implementation
or theorems.

`benchmarks/envelope/workloads.json` is the machine-readable workload/cost
manifest. Validate it with `python3 tools/performance/envelope/report.py validate`.
Regenerate historical attribution with
`python3 tools/performance/envelope/report.py summarize` (stdout only). Neither
command starts Isabelle, a service or a benchmark. The committed summary hashes
its input records; hardware there describes the summary machine separately from
the historical run host, whose exact identity is not established by those files.
Do not attribute the historical timings to the summary machine.

## Baseline evidence and budgets

The existing `audit/results/baseline.jsonl` records a 14.786 s legacy load,
467,042,304 byte reported max RSS, and 16 heterogeneous single-query observations.
General reader loading was false. External wall times range from about 0.06 ms
to 4.280 s. Internal reported latency frequently differs substantially from
external wall time; internal timers cannot stand in for request latency.
Questions are source-backed workload seeds, not correct-result or native
performance acceptance. Original corpus/runtime availability and identity must
be established before reproducing these as controlled runs. The profile records
wrapper/dispatch traversal as a historical cost lead, not a current bottleneck.

`experiments/native-execution/startup.json` records a historical warm-filesystem
native feasibility startup, including launcher/JVM/ML and sampled process-tree
RSS. It includes command and memory sampling limitations. Shared pages may be
counted repeatedly. It is neither full product startup nor measured cold launch.
No speedup ratio is valid between this probe and the legacy application.

| Initial constraint | Status and rationale |
|---|---|
| Small warmed pure calculation/indexed lookup: end-to-end p95 100 ms; control/codec 10 ms | Provisional design target copied from runtime review, not established by these samples; revise after native repeated representative runs |
| Decoded-source cache 256 MiB | Provisional configurable design bound; separate ML/JVM/worker/file cache peaks required |
| No compilation on source poll, ordinary observation or existing-operation plan | Architectural acceptance invariant; measure compile counters and generation identity, not just elapsed time |
| Finite enumeration | Record exact 2^n state count and integer bit width before execution; stress n=8/16/24/32 under explicit time/fuel/byte bounds; materialize at most 1024 rows in this workload, then paginate/refuse |
| Regression threshold | Unset until representative repeated baselines and noise estimates exist; the 16 heterogeneous observations cannot supply a regression percentage |

A budget becomes enforced only with a pinned workload, repeated baseline/candidate
samples, noise estimate, semantic oracle and reviewed threshold. Report median,
p95 and maximum separately, with repetition count and quantile method. Cold
launch, first request and warm steady state need separate samples. Use isolated
fresh application state and predeclared filesystem-cache conditions; never delete
shared caches to manufacture cold measurements.

## Measurement contract

Attribute request wall time to queue, interpretation, retrieval/data, search,
execution, proof checking/reconstruction, commit, protocol and rendering. Measure
startup, admission and each growth tier separately. Distinguish spans that overlap
from serial critical-path spans; summing overlapping CPU/wall spans is invalid.
Record monotonic start/end, CPU, allocations, GC, live/peak RSS by ML/JVM/worker,
input/output/certificate bytes, I/O, search states, integer bits and materialized
rows. Unsupported counters are null with a reason, never zero. Record compilation
amortization and number of requests sharing the compiled bundle.

Run identity includes revision plus dirty-file digests; hardware/OS/architecture,
RAM/cores/power mode; Isabelle/Scala/JVM/PolyML/compiler versions and flags; heap,
code setup, bundle, source snapshot, indexes and size; process/heap/filesystem/index
warm state; repetitions/order/concurrency and competing work. Keep corpora, heaps,
credentials and raw private traces outside Git. Publish only non-content metrics.
Current local summary host is macOS ARM64. Linux x86_64 deployment evidence is
unavailable; it remains a required platform gate, not an inferred compatibility.
Clean dependency closure must enumerate shipped heaps/libraries/corpora/UI assets,
installed prerequisites and any unexpected first-launch compilation/download.

Cancellation has three times: request, acknowledgment and worker quiescence.
Record uninterruptible compiler/tactic intervals, memory after quiescence, durable
attempt status and late events. Ack alone does not establish stopped effects.
Measure foreground-only against sensor polling, background qualification and
candidate compilation under root-scheduled resource slots; report slowdown and
queue tails, not merely per-call worker throughput. Do not run noisy experiments
alongside native builds. All native builds use the shared driver lock.

## Semantic workload oracles

Reader/math cases retain interpretations, domain/unit assumptions, ambiguity and
refusal. Source cases require closed coverage for absence/uniqueness/ranking/count;
missing pages, truncation and stale snapshots remain scoped incomplete results.
Routed cases preserve an answering component and another component's timeout or
blocker without promotion to global completion. Large data uses typed batches;
record copies/bytes and buffers separately from logical term or proof transport.

Qualification compares baseline/candidate code, interpretation and routing policy,
learned state, panel/split/scorer/runtime identity and exposure. Count added answers,
wrong interception, negative-space abstention and latency. Repeatable regression,
fresh held-out evaluation, aborted/spent exposure and formal admission are distinct
outcomes. Nonpublishing runs isolate both persistent AND in-memory state. Retained
objects declare request/session/global ownership, exact dependencies and activation
authority. Test normal requests before/after, two sessions, same-name learned
programs, restart/reload and primitive replacement; disabling writes is insufficient.

Each growth tier has independent wall/CPU/memory/code-build/proof-transport costs:
observation/config/example/ranking; reifiable theorem/definition; interpreted typed
plan; optional stable-plan specialization; new carrier/kernel/binding/code setup.
The first three reuse the current executable bundle. Specialization keeps the
interpreter available. New executable generations measure affected-bundle compile,
qualification, publication, old/new overlap, stale-handle rejection and migration.

## Open implementation consumers

Native-linkage feasibility supplies scoped compile/dispatch/proof-transport probe
measurements; runtime-host bootstrap supplies scoped ready/protocol/cancellation
measurements. Host protocol evidence is now collected below; linkage transport
remains pending. These are not runtime-service acceptance. No independent
native benchmark was run by this lane. Root must schedule supported measurements
and review probe limitations before adopting them as new evidence.

Runtime service still owes real startup, durable commit/restart, cancellation,
protocol counters and no-per-request-theory checks. Sources/routing owe complete
negative/partial/pagination fixtures and bulk buffer measurements. Execution/search
owe bounded enumeration and certificate/checker costs. Qualification owes isolation
and exposure tests. Workbench owes authoring/render/impact measurements. Deployment
owes clean macOS/Linux closure. Performance hardening owns repeated whole-path,
concurrent and growth-tier baselines and evidence-derived enforced budgets. This
manifest makes those consumers explicit; it does not close their implementation.

## Supported local measurements and collection interface

`python3 tools/performance/envelope/local_fixtures.py` runs only inspected,
standard-library upstream SQL, formats and mechanics components. Build steward
approved this short offline fixture cost check during the compile queue. It uses
fresh in-memory SQLite connections and bounded queries at 0/1/20/21/100/1000 rows,
an independent full-query SQLite oracle, a literal-space SHA256 counterexample
and a 9 J kinetic-energy case. Thirty measured repetitions follow one discarded
invocation per case. `benchmarks/envelope/local-components.json` retains all
samples, source hashes, Python/SQLite identities and observed semantic outputs.

On this macOS shared host the SQL component median was 0.061–0.121 ms, literal
hash 0.006 ms and kinetic energy 0.037 ms. These are component costs under
uncontrolled background load. SQL reads only 21 rows then displays 20; the flat
100/1000-row costs measure prefix extraction, **not** complete scans. The returned
value lacks typed completeness metadata. The fast literal hash corrupts repeated
spaces and fails its independent oracle. No optimization or semantic acceptance
is inferred from speed. These measurements establish reproducible cost fixtures
and explain why complete-query costs remain open.

`python3 tools/performance/envelope/collect.py RECEIPT` consumes an existing native
driver receipt, requires passed/stable input snapshots and successful command
exit codes, hashes referenced logs and extracts actual host startup/warm/cancel,
linkage aggregate wall/CPU/GC and proof-transport byte/reconstruction markers.
Driver command duration remains a separate launcher/build-inclusive cost.
The collector does not run anything or infer cache warmth. Missing allocations,
live memory, timed durable commits and representative application costs remain
explicitly unavailable. `python3 tools/performance/envelope/check_collector.py`
checks parsing plus rejection of failed/unstable evidence using synthetic input;
those numbers are not benchmark evidence.

Envelope-stage closure is limited to workload coverage, phase/run identity,
repeatable historical/local collection, semantic fixture oracles and explicit
provisional targets. Full acceptance still needs actual native representative
runs: startup/cold closure on both platforms; admission/bundle compilation by
growth tier; warm request phase tails; durable transaction and restart latency;
source complete/negative/aggregate and routed partial results; search/proof
reconstruction curves; UI rendering; allocations/live memory/GC; cancellation to
quiescence; and whole-session polling/qualification/build interference. Learned
state isolation must be exercised in the real runtime, not inferred from these
stateless offline components. The successful early host protocol receipt is collected below; linkage transport
remains pending.

## Verified resident host protocol probe

The stable passed archive `var/runtime-host/protocol-20261015T133500Z/receipt.json`
and its sibling logs are collected in `benchmarks/envelope/host-protocol.json`.
Reproduce without execution:

```
python3 tools/performance/envelope/collect.py var/runtime-host/protocol-20261015T133500Z/receipt.json --log-dir var/runtime-host/protocol-20261015T133500Z
```

The explicit log directory matters: original driver paths are mutable and may be
overwritten by subsequent checks. The collector hashes the actual archived logs
and reports both recorded and current source digests. At collection, theory,
ROOT, protocol Scala and driver match the run; `durable.scala` has changed since
that run. The protocol command invokes only `probe.scala`, so this is not evidence
for the revised durable script. The historical run itself was input-stable.

Toolchain: Isabelle2026-RC1, PolyML 5.9.2, Darwin ARM64, two ML threads and one
build job, existing custom HOL session heap. Cache identity beyond producer-reported
warm heap remains unspecified. The measured protocol is an ML ping command with
Scala event handling, not an admitted domain calculation or theorem checker.

| Measured interval | Value and exact scope |
|---|---|
| Host resource creation → session start and protocol-handler registration | 3372 ms; no startup ping readiness handshake inside this interval |
| Five serial warm ping RTTs | 16.47325, 1.7075, 1.6355, 0.983292, 0.887292 ms; command send through matching Scala event, includes queue/event handling and printing; five observations do not establish tail budget |
| Cancel send → both cancel and interrupted events | 1000.617 ms; interrupting a sleeping ML future; no durable/effectful cancellation or general worker-quiescence claim |
| Scala launcher command | 13172.845 ms; includes script compilation, first session startup, commands, shutdown, second session startup/restart ping and shutdown |
| Driver build command | 7434.793 ms; launcher plus cached build check; not isolated compilation |
| Entire receipt | 21639.851 ms; includes version/settings/build/Scala command and driver overhead |

Archived output proves the protocol-version/shape refusal, successful pings,
interrupted-future events and restart ping assertions executed. It does not
establish kernel computation runtime, admission, proof checking, complete service
startup, durable transaction cost, memory or application latency. Do not subtract
the startup interval from the Scala command to label the remainder compilation:
several uninstrumented phases overlap that difference. Linux evidence and native
linkage all-pass transport evidence remain pending.

## Verified durable transaction probe and iteration costs

`benchmarks/envelope/host-durable.json` collects the passed, stable archive
`var/runtime-host/durable-20261015T135235Z` with the same explicit archived-log
option. The actual `HOST_DURABLE_COMMIT_MS` marker is **31.722792 ms**, one first
transaction over `structured state`: artifact write/fsync, directory fsync,
content verification and JDBC SQLite FULL commit. Database initialization is
outside that interval. This is one sample, not p95, throughput or generated
service commit latency. The log also records real separate-process halt-before,
halt-after and halt-dispatch recovery assertions. Those establish exercised
failure paths, not latency distributions. Driver wall is 46.671 s; Scala command
35.923 s includes child compilation/start/halt/recovery probes.

Current theory/ROOT/protocol/durable sources match this run's recorded hashes;
the driver changed afterward. Recorded run input stability and current source
identity are deliberately separate. The collector retains both digest sets and
the mismatch, rather than retroactively attributing old timings to new code.

Iteration cost must separate a cached parent-session check, edited base rebuild,
proof-worker child rebuild and actual request time. Linkage now separates a
stable/default-recording base from a `record_proofs=2` child. Its base metrics
can be replayed from a cached heap: `LINKAGE BASE_HEAP_REPLAY measured_at_epoch`
is preserved as provenance, never relabeled a fresh benchmark. Authority is
splitting definitions/proofs to reduce opaque long iterations. Their eventual
build receipts need edit-path/session/cache identity and wall/CPU/peak-memory
cost before comparing these engineering changes. No extra native build is
required merely to populate a timing table.

## Paired generated-service runner design

`benchmarks/envelope/paired-service-plan.json` defines the concrete paired-run
inputs and correctness gates. Execution is deliberately disabled until the real
generated authority service, native evidence comparison and phase instrumentation
exist. The collector is usable now; a fake Python service would not discharge
this gate or become a production benchmark interface.

Scale retained requests, evidence, history revisions and visible bindings
independently of payload size, alongside goal-DAG depth/width. The authority
reference uses lists and repeated `live_goals`/evidence scans inside binding
checks, so a tiny request in a long-running session may cost more than a large
request in an empty one. This is a source-derived scaling hypothesis, not yet a
measured hotspot. Indexed representations or dependency snapshots must preserve
epoch/revocation/invalidation semantics through the actual refinement connection.
The authority owner has been notified; paired real-service curves and traversal
counters will determine whether that change is needed.

## Actual implementation cost review and next runnable seam

`tools/performance/envelope/source_phases.ML` is a prepared, **unexecuted**
development harness using `Veri7vn_Source_Execution` directly: an admitted instance
and checked request enter real `prepare`, generated `execute`, and native `project`
spans. It releases output/request handles even after projection failure and
returns counter snapshots plus native projections for consumer comparisons. It
must be loaded into the actual built source-bundle context in a steward-approved
slot; it adds no runtime protocol or handwritten evaluator. Admission belongs in
its own cold/attach span. Repeated native projection equality can detect repeated
run divergence; it does not replace the implementation refinement theorem or
prove a cross-representation optimization correct. Refusal outcomes must be
reported by the fixture consumer; they cannot become fast successful samples.

The production service currently accepts native admission tokens. Arbitrary event
bytes are intentionally unavailable and nonempty association recovery refuses.
Thus the real-service paired harness still needs an admitted token issuer and
stable fixture constructor, rather than an invented benchmark bypass.

| Inspected path | Concrete scaling/materialization question and required paired axes |
|---|---|
| `src/isabelle/model/Veri7vn_Authority.thy` | List append/map scans grow with retained requests/evidence/visible bindings; `goal_ready_live` rebuilds live-goal membership and `licensed` searches evidence. Measure independent R/E/B and DAG depth/width, including revocation and old irrelevant records. |
| `src/runtime/service/native_service.ML` | Earlier draft repeatedly recomputed transitions/checkpoints; current repair caches the actual generated candidate and post bytes under an internal all-write version. Validate/ack compare token/version and install cached native candidate. Measure invocation/encode counts and journal/state size to check the repair; no speedup measured. |
| `src/isabelle/plans/Veri7vn_Plans.thy` | `map_of` input/type environments are linear per reference. Deduplicated conjunctive premise IDs bound duplication but list `remdups` can remain quadratic in unique conditions. Vary edges, fan-in and unique conditions separately; values/history retain multiplicity. |
| `src/isabelle/execution/Veri7vn_Source_Execution.thy` | Input length guard scans lists; Count extracts a value list then takes length. Selection/window/value plans can allocate intermediate lists. Measure source cardinality and selectivity, complete versus prefix semantics. |
| `src/isabelle/execution/bundle/source_bundle.ML` | Generated trace is retained behind projection closure; `project` reifies a full term before node-bound rejection. Existing request node/depth/work/time limits do not alone establish a peak-memory bound for the generated trace/projection. Measure execute/project separately, retained outputs and release/quiescence. |
| `src/isabelle/admission/proof_transport.ML` | 100000-byte/20000-node/128-depth guards and five-second timeout are current defensive limits. Cached native proof checkers retain up to four theory identities. Export expands/reconstructs before final encoded bound. Measure warm/cold checker context, private proof shape/expansion and rejected oversize resource use. These are implementation caps, not demonstrated end-user budgets. |
| `src/packages/intake`, `src/runtime/host/WorkspaceStore.scala` | Archive bounds precede expansion; sorting/canonicalization and defensive copies add memory; blob publication fsyncs and rereads for integrity. Scale file count, compressed/expanded bytes, checkpoint size and history, with disk costs distinct from Scala compilation. |

Root received the authority/service/source materialization findings. Indexed
state/environment representations, streaming Count, cached immutable checkpoints
or bounded projection are candidate refinements requiring actual consumer checks;
none has a measured speedup yet. The approved premise deduplication addresses
exponential repeated conjunction propagation without modifying value/history
collections. Its resulting unique-ID curves remain required measurements.

All five growth tiers use these same axes. Data/observation and interpreted-plan
updates require zero new compilation; theorem lineage admission measures checker
and context costs; optional specialization and new executable bundles measure
compile/qualification, overlap and amortization separately. Provisional time
budgets remain provisional: current evidence supports keeping compilation out of
poll/plan hot paths and explicit bounded materialization, not a numerical full
service p95 promise.

## Additional archived evidence

`benchmarks/envelope/linkage-private.json` hashes the stable private-derivation
receipt and separately archived observation text. Original command logs were not
archived there, so `command_logs_omitted` is explicit; their recorded command
intervals are retained without pretending current mutable logs belong to that
run. The genuine private Pure implication transported **94 bytes in 154.382 ms**
(total expansion/reconstruction, one tiny proof). The seven-byte MinProof attempt
was **rejected**, and is labeled so; it is never successful certificate size or
latency. Base attachment/count timings are heap-replayed observations with
measurement epoch 1792073085.854, not fresh timings from the child run. Neither
probe establishes general HOL transport, admission throughput or app speedup.

`benchmarks/envelope/host-production-failstop.json` collects archive
`var/runtime-host/production-20261015T142804Z`: actual metadata bounds,
WorkspaceStore and coordinator failure-injection assertions ran. Its Scala
command includes compilation and fixtures; it is not per-request time or native
service throughput. `benchmarks/envelope/intake-compiled.json` similarly retains
the stable final intake receipt plus its archived check description: original
command logs are omitted explicitly. Whole Scala compilation/fixture cost cannot
be relabeled intake operation latency. Current source mismatches are retained in
both reports because implementation continued after these runs.

The requested 26-case intake review is additionally collected in
`benchmarks/envelope/intake-review-compiled.json`: receipt whole elapsed
22.848114 s (Scala command about 13.66 s), with archived review-check description,
not retained raw command logs. The subsequent final intake run differs:
29.093685 s whole elapsed and 17.211698 s Scala command. These distinct revisions
and test sets are not merged into a fabricated repeated latency sample.

## Green integration records and retained-graph pressure

The root-reviewed projection receipt is collected in
`benchmarks/envelope/projection-correctness.json`. Its nine N=16/128/512,
P=1/8/32 preflight cases assert no output-term constructor counter advance; a
1000-node budget accepts three and refuses six. Small materialization preserves
the exact native term, and scope escape refuses. The 68.816 s driver / 51.018 s
build includes two authority targets/cache checks. Those are correctness and
whole-build records, not isolated projection timing or live-trace memory proof.
The source generated trace can still retain large values before projection.

Effects record `1d956133573d9775` and actual logs are preserved under
`benchmarks/envelope/evidence/effects-1d956133573d9775`, with normalized
`effects-correctness.json`: generated model checks and actual Scala learning
isolation ran; whole driver 43.796 s, build 34.885 s, Scala 8.243 s. The combined
host archive `var/runtime-host/combined-20261015T145302Z` is normalized in
`host-combined-correctness.json`; its actual host/intake assertions are fixture
execution, not resident request latency. No new native run occurred here.

Effects `forget_closure` currently executes V rounds over retained values even
when a round adds nothing. Each round filters with list membership and deduplicates
a growing removed list. That can incur cubic list-comparison growth, plus dependency
edge scans; it is a source bound hypothesis, not measured runtime complexity for
a corpus. Current conditional Some-result closure/minimality theorems do not yet
supply totality or indexed refinement. The owner agrees to a proved fixed-point
shortcut then worklist/indexed refinement after the core interface stabilizes.

`benchmarks/envelope/native/Effects_Envelope.thy` is an **unexecuted** real generated
API fixture session. It constructs disconnected, chain and dense retained-value
graphs and exposes individually scheduled `Veri7vn_Effects_Envelope.sample shape n`
for n=16/64/256/1024, checks exact expected closure IDs and returns actual Timing.
Fixture construction is separate. Five-second execution timeout and 65536-edge
fixture bound protect development resources: the dense 1024 case is explicitly
refused before construction, never a successful full-graph measurement. Duplicate
IDs, cycles, payload/owner isolation and future optimized/reference equivalence
remain additional cases; this scaffold does not establish general totality.

ManagedSources currently bounds objects/staged bytes and 128 operations per draft,
but aggregate budget queries group all draft hashes before and during each put.
Repeated history/shared-hash joins and per-hash Forget reference queries need
objects1/256/8192 × operations1/16/128 × sharing0/50/100% curves. Hash/clone/readback
costs need 64KiB/1MiB/40MiB object curves. Suggested maintained counts/refcounts or
indexes must preserve cross-draft shared-hash deletion and serialized bound
revalidation; the host owner received these cases. No unchecked hash cache or
write-only bound substitutes for exact association/replay correctness.

The storage audit supplies realistic semantic pressure: >255 rows, 64353-byte TEXT,
REAL fields, duplicate rows, UTF-8 and signed quantities. Native source v1's255
row/cell limits cannot be called full-source performance. The source owner is
building a v2 incremental semantic feed decoder with per-byte state, uint32
lengths, row/footer events, bounded current row and explicit EOF/malformed/trailing
outcomes. Its proposed one-pass behavior is not green evidence yet. The envelope
will use actual v2 APIs with cross-chunk row/cell boundaries and 257/4096 rows,
not infer performance from the old bounded decoder.

`tools/performance/envelope/ResidentServiceMeasurement.scala` prepares the actual
resident-host entrypoint: poll a native-issued token and time the real serialized
`AuthorityCoordinator.submit` through durable commit and native ack. It cannot
construct tokens or accept a stand-in NativeBridge. It is uncompiled/unexecuted
until the D34 native issuer and migrated service session are ready. Complete
startup, admission, initialization, token generation, submit, renderer and phase
counters must then be measured separately in one actual end-to-end run. Existing
ControlledBridge coordinator tests do not exercise that generated resident path.

The host owner repaired the repeated-reducer finding in current source: the
internally built install closure captures the actual generated candidate, validates
an all-write version and installs it once. Restore invalidates pending work.
This removes repeated computation in the inspected path; actual native integration
and paired measurements are still required. No caller-created policy callback
was introduced by the repair.

## Deployment cost ranking after canonical-29 resource integration

This ranking is **derived from current code**, with actual fixture evidence kept
separate. There is still no composed resident application latency/RSS baseline.
The canonical-29 attempt `c0b87f51a8ef41dc9712b22edee4dd38` is overall **failed**:
actual host, worker resources, learning/operation profile,26 intake and6 managed
draft checks printed success, then NativeBuildInputs cleanup failed with
`release managed source resources before workspace store`. The diagnostic artifact
`runtime-c0b87-diagnostic.json` hashes the immutable attempt receipt/log, retains
source hashes and observed subcheck/failure lines. `inspect_failed_attempt.py`
handles this separately; the passed-only collector continues rejecting the run.
None of those fixtures is an executed generated resident request benchmark.

| Priority | Deployment risk, evidence and justified action |
|---|---|
| 1 | Full-state checkpoint serialization/copy/durable write per accepted event remains O(S), even after the cached-candidate repair. At fixed retained state S, repeated events incur O(events×S) checkpoint bytes; growing state can therefore produce quadratic cumulative I/O. Existing 31.7ms first tiny commit does not measure this. First paired resident run must vary metadata1KiB/64KiB/512KiB/up to supported cap independently of event size. Longer-term incremental journal/checkpoint cadence needs an explicit authoritative replay/refinement contract, not an unreviewed checkpoint omission. |
| 2 | NativeBuild default source capacity64MiB has a declared >=192MiB parser clone reservation plus8MiB max-file term, twice manifest bound and separately captured source arrays/metadata. SourceObjects layers read/clone/hash/content materialization and real durable readback. These are source-derived bounds, not measured RSS. Preserve reservations now; a reviewed owned immutable chunk/view parser could reduce full-source copying while maintaining exact bytes/access revocation, but requires actual lifecycle/cleanup tests and producer allocation accounting. |
| 3 | Effects closure V full rounds, list membership/dedup and restore's repeated association scans/reconstruction can dominate retained graph size. Conditional closure proofs and tiny proof transport timings don't establish full-workspace performance. Measure V/edges/history plus cold/warm proof-checker contexts. Totality/indexed refinement remains separate; don't skip recovery rechecks merely to improve restart. |
| 4 | WorkerResources `reserveFile` currently sums all existing file sizes on every reservation: F files imply quadratic cumulative arithmetic even before hashing/I/O. With2048 source entries this is unnecessary work. A synchronized `diskBytes` field, incremented only after durable scratch-file reservation succeeds and cleared on release, preserves the existing cap and inventory and is the recommended small first repair. |

Only two changes are recommended now: the small disk-total accumulator, and a
reviewed owned immutable source-parser representation to remove redundant
whole-source clones once the cleanup path is green. The host and authoring
owners received both exact cases. Full-state journal refinement is consequential
and should follow actual phase/byte measurements; it is not folded into a silent
host optimization. All recommendations retain exact source hashes, original
byte/row multiplicity, native checkpoint identity and lifecycle authority.

WorkerResources explicitly budgets payload reservations rather than claiming an
exact JVM heap cap. Captured bytes, parser roots, file production and live workers
are registered before allocation/handoff; cleanup waits for workers before
clearing arrays/roots and host scratch inventory. Correctness still depends on
fixed producers declaring the complete internal clone envelope. Measure actual
peak live memory/GC and cancellation-to-quiescence on one large file and many
small files; a reservation counter is not an allocation profiler.

Current restore stages bounded chunks, then concatenates/materializes them and
rechecks kernel evidence, restores requests, and reconstructs outputs before
atomic complete association installation. Shared associations are searched in
lists; output→request matching is a scan. Recovery cost needs number and total
bytes of distinct contexts/proofs/requests/outputs, not just checkpoint bytes.
Report required security rechecks separately from avoidable scans/copies. A
cold proof checker and a warmed existing context are distinct restart workloads.

The real `ResidentServiceMeasurement.sampleAuthorized` entrypoint remains ready
for the first composed D34 native pass. It times actual token consumption through
coordinator commit/ack, not ControlledBridge fixtures. The fixture driver must
separately time native proposal/interpretation, wait/poll, computation, result
binding/render, token commit, and restoration, while capturing exact source and
service hashes. Until the service session and issuer compile together, this is
prepared code rather than executed end-to-end evidence.

## Scheduled generated closure pilot after checked totality

Effects totality is now checked in the isolated proof child (the later combined
attempt failed Admission; it does not undo that checked child). The effects owner
confirmed the actual generated API and reviewed all fixture oracles. The pilot
now includes six shapes: disconnected, chain, dense, duplicated chain records,
missing seed linked to a chain, and missing seed disconnected. Each runs n=16,
64,256,1024 once; duplicate shape has2n records and dense1024 has523776 edges.
Missing-linked seed n expects0..n, missing-disconnected expects[n]. Rows/values
are not deduplicated before passing to the actual generated function.

`Effects_Envelope.thy` defines fixtures and phase sampling; the separate
`Effects_Envelope_Run.thy` triggers the24-case pilot only in the scheduled native
session. Construction has a five-second limit separate from each five-second
closure execution limit. The edge bound now524288 explicitly permits the dense
1024 case; no silent reduced-size replacement remains. Timeout is a censored
outcome with no result count, never a fast success. CPU/GC/wall, construction time,
record/edge counts and exact checked outcome are emitted per case. This is one
pilot sample per case, not a repeated p95 or app latency distribution.

The build steward has the exact command and queued the cost question after
connected Recovery/Dev/MathBundle and runtime cleanup fixes:

```
python3 tools/dev/check-native --session Veri7vn_Performance_Effects --session-root benchmarks/envelope/native --session-root src/isabelle/effects --session-root src/isabelle/codegen --session-root src/isabelle/sources/semantics --expect 'EFFECTS_ENVELOPE pilot_complete PASS' --timeout 240
```

No performance lane build was launched. The collector now parses the generated
`EFFECTS_ENVELOPE` records and preserves timeout censoring. Its synthetic parser
check passes. Actual pilot metrics remain pending the steward slot; no optimized
closure was selected in advance of those measurements. Current codegen and
retained-value fields are recorded by the driver source snapshot when it runs,
separately from older proof/export evidence.

## Executed generated closure pilot — first measured scaling obstruction

The steward executed the frozen24-case session successfully with stable inputs:
`f4d1f5623f234ab3b424701a5d9e81ce`. Its immutable receipt and all relevant logs are
copied to `benchmarks/envelope/evidence/closure-f4d1f5623f234ab3b424701a5d9e81ce`;
`closure-pilot.json` records exact source/toolchain/log hashes and parses actual
phase output. The real generated `forget_closure` returned the exact expected
IDs in21 cases;3 exceeded the five-second per-case execution deadline. The test
passes because explicit censored outcomes are part of the pilot protocol; it
does not mean every case met a user-facing performance budget.

| Graph shape | n16 wall ms | n64 wall ms | n256 wall ms | n1024 wall ms |
|---|---:|---:|---:|---:|
| Disconnected, seed present | 0.207 | 0.084 | 0.581 | 14.841 |
| Chain | 0.156 | 1.796 | 58.580 | timeout5041.828 |
| Dense lower-triangular | 0.042 | 1.343 | 223.807 | timeout5043.385 |
| Duplicate chain records (2n records) | 0.187 | 23.007 | 759.038 | timeout5014.119 |
| Missing seed linked to chain | 0.312 | 0.729 | 94.561 | 4171.720 |
| Missing seed disconnected | 0.038 | 1.788 | 0.657 | 4.578 |

Each table cell is **one observation**, fixed order, shared development host,
Isabelle2026-RC1/PolyML5.9.2 Darwin ARM64, two ML threads. No p95, confidence
interval or background-interference correction is established. Construction is
outside the closure interval and under17ms per case. Full per-case CPU/GC metrics
are retained: n1024 chain/dense/duplicate timeouts consumed2022.984/1772.190/
1812.751ms CPU respectively, while wall exceeded5s. Thus elapsed curves include
scheduling/interference; they must not be advertised as pure CPU scaling laws.
Timeout records have no result count and do not establish the eventual result
or uncensored completion time. No corpus payload, host transaction or service
request executes in this pilot.

Exact source pins are the receipt's `sources_sha256`, including benchmark,
Effects, Codegen and Sources inputs. They are separate from earlier checked
closure-totality child evidence and later source changes. Actual receipt whole
elapsed is47.117369s, build command41.604844s and build-log extraction4.122873s;
theory Run output was about20.7s. Those intervals include setup/build/extraction
and must not be relabeled24 isolated request timings. The receipt, rather than
an agent's preliminary duration summary, is authoritative for these numbers.

These measurements now justify an algorithmic repair: a proved early fixed-point
shortcut removes unnecessary saturated rounds, while chain depth still motivates
a reverse-dependency index/worklist refinement. Preserve the reference semantics
for duplicate records, absent seeds, cycles and output ordering/declared relation;
returning less data or lowering admitted graph size is not the repair. The effects
owner received the actual curves before selecting the implementation. Refinement
correctness and totality remain owned there; this harness will compare the actual
optimized generated entry against the same fixtures after that proof is green.

The five-second diagnostic deadline is not a product target. Three timeouts and
a4.17s closure at only1024 nodes block an unsupported claim that current forgetting
is responsive for long-running workspaces. Do not convert1024 into a silent
retention cap to make a green latency report. Meaningful enforced regression
budgets still need repeated paired observations in a controlled slot, plus the
actual authoritative lifecycle integration and cancellation-to-quiescence path.

## Installed public consumer: bounded first/warm/restart harness

The former absence of an integrated application baseline is now historical.
`var/deployment-launch-check-4cc408de-8bd0-432b-8bd9-d5addb5f7e3e/result.json`
records two successful public-main processes over the actual installed generation
`40ac45e74c0be18732a81bff246817cfb2cbe9de91abfc7c8a7ccfc234ec98bd`:
59.052944 seconds for fresh-workspace sum and 21.354130 seconds for nonempty
restart and product. Both include launcher verification, startup/restore,
request, durable workflow, licensed HTML and shutdown. These are **not** query
latencies or a paired speedup; the requests and workspace states differ. The
archive's parent driver finalization was interrupted; its recorded subprocess
exit codes and exact output checks passed. This package predates current D44/D47
integration and cannot qualify their performance.

`tools/performance/envelope/public_runtime.py` now drives the real installed
public launcher with a fresh, retained workspace, two fixed arithmetic cases
repeated sequentially in one resident process, then a second process over the
same nonempty workspace. Every response must equal its expected licensed HTML;
other output is retained but never accepted as a successful response. Each
request has send/observation monotonic timestamps. First response includes startup;
subsequent responses share the process. EOF-to-exit is separately measured.
Manifest and harness/launcher hashes, exact command, selected generation, host,
cache declarations, stdout/stderr logs and logical workspace footprint are
recorded. A changed selected generation fails the run. Timeouts terminate only
the harness-owned process group and retain a failed result. Output paths must be
new; workspace and logs can contain private runtime material and stay outside Git.

Example, **only after the steward grants the named slot**:

```
python3 tools/performance/envelope/public_runtime.py var/deployment-application \
  --output var/performance-public-SLOT --steward-slot SLOT --repeats 4
```

The harness makes no Isabelle build, cache eviction, global setting change or
synthetic service. Its 250ms process-tree RSS sampling is a sum which may double
count shared pages and miss short peaks. Workspace logical bytes are not I/O
bandwidth, physical writes or fsync cost. CPU, allocations, GC and separate
interpretation/admission/execution/evidence/commit/render spans remain explicitly
unavailable. Four repetitions are a pilot, not an enforceable tail budget.
Filesystem cache condition is uncontrolled; fresh process is not cold disk.
Linux and original reader/source/search/domain/growth workloads remain required.

The current `RuntimeMain` waits 25ms between result polls. This is a possible
observation delay of roughly one polling interval under otherwise idle conditions,
not an established dominant execution bottleneck. The much larger measured
startup-inclusive paths motivate attribution first. The runtime owner has received
a proposed opt-in stderr-only timing seam: aggregate service open, ready instant,
proposal, result wait including all polls, output write and close, with monotonic
bounds and request ordinals only. Nested native startup/restore and durable commit
spans must carry parent relationships; overlapping spans cannot be summed.
Instrumentation belongs after the frozen D44 capture, with no licensed stdout
change or payload logging. No improvement is claimed before actual measured runs.

The steward initially held runtime launches while the native queue was under
resource pressure. After that hold, the restricted slot1 launch failed and the
authorized unrestricted slot2 launch passed as recorded below. Synthetic harness
control-flow checks remain separate from those application measurements.

The public harness pins launch through a private `output/installation/current`
symlink to the captured immutable generation. The command uses that facade, so a
switch-and-return of the original installation pointer cannot select a different
runtime unnoticed. The existing staged launcher still verifies the captured
package. A small harness-owned Python session guardian keeps its unreaped group
leader identity reserved until cleanup, including when the public client exits
before its descendants. It reports the actual client exit separately and adds a
small, unisolated Python launch overhead to first-response/process elapsed times.
Cleanup sends TERM then KILL to that owned group, waits at most five seconds,
and drains reader/sampler threads for at most three seconds. A descendant which
escapes the owned group and retains pipes causes explicit bounded-drain failure;
the harness never searches for or kills unrelated processes.

`python3 tools/performance/envelope/check_public_runtime.py` passed synthetic
regressions for pointer switch-and-return while observing the pinned facade,
repeated exact responses, timeout cleanup, and a client which exits leaving a
60-second child holding both output streams open. The last case requires reader
EOF within a bounded run, demonstrating cleanup of the still-owned child. These
are harness checks only. A guardian readiness handshake installs its TERM handler
before requests begin, avoiding a startup race during very short timeout tests.

The first scheduled public harness attempt (`immutable40ac-baseline-slot1`,
`var/performance-public-40ac-20261015-slot1`) failed under the restricted execution
sandbox: client stderr emitted `I/O error: Operation not permitted`, with no
licensed response. The exclusive shared build lock covered the run and bounded
cleanup; wrapper elapsed was 90.653190 seconds. This is failed launch evidence,
not startup latency. Its result/logs are preserved separately from any retry.
The harness now checks the guardian's child status during 100ms output waits so
an early nonzero exit fails promptly. A synthetic exit-7 child with a 30-second
response deadline must fail within five seconds; that regression passed alongside
the existing pointer, descendant and timeout cases. The subsequent steward-granted
slot2 used the authorized unrestricted execution path and passed; no overlapping
run was used.

## Actual installed public first/warm/restart pilot

The authorized `immutable40ac-baseline-slot2` run passed all four exact licensed
HTML checks with both public processes exiting zero and empty stderr. The steward
paused native/Scala work; the harness held the shared build lock for its entire
39.792583-second wrapper run, then completed owned group cleanup and bounded
output drains. `benchmarks/envelope/public-runtime-40ac-pilot.json` retains
non-content observations, log/result hashes, exact old-generation and toolchain
pins, and the source-artifact-set digest. All 235 packaged source artifacts were
independently checked against manifest hashes. Private state/logs remain under
`var/performance-public-40ac-20261015-slot2`.

| Interval | Fresh workspace process | Nonempty restored process |
|---|---:|---:|
| First sum, send to observed licensed HTML, startup inclusive | 22,823.326875 ms | 14,791.519667 ms |
| Second request, product, same resident process | 241.648750 ms | 152.812291 ms |
| EOF to client exit | 477.775709 ms | 588.000125 ms |
| Process elapsed, excluding final guardian cleanup | 23,604.303667 ms | 15,577.679375 ms |
| Sampled process-tree peak RSS | 1,576,206,336 bytes | 1,574,420,480 bytes |
| Logical workspace footprint | 512,382,650 bytes | 512,554,134 bytes |

Every cell is one observation; two warm requests do not establish p95 or a noise
estimate. Warm request walls exceed the provisional 100ms design target, but that
target is not yet a measured regression gate. The RSS samples are tree sums with
shared-page double counting and missed-transient caveats. No CPU/GC/allocations
or internal stage costs were captured. The sampling observer cost is unisolated.
The filesystem was uncontrolled and warm in some metadata/files from prior source
inspection; neither first response is a cold-disk measurement. The 81% memory-free
steward snapshot describes the slot opening, not live memory throughout the run.

Startup deserves attribution before optimization: the public launcher verifies
25,106 package artifacts, then starts JVM/PIDE and acquires the deployment image
before native initialization or restore and the first request. Postshutdown logical
storage is 511,074,906 bytes of public deployment images and 1,479,228 bytes of
authority workspace. The inspected image manager copies and fsyncs heaps on the
first acquisition and reuses them on later starts; its existing
`deploymentCaptureMillis` can distinguish this path in the proposed telemetry.
The two first-response values cannot isolate image capture, cache effects or
restore costs. The host owner received these actual observations and the request
to connect that existing timer to the opt-in startup spans after the D44 capture.
The 25ms polling interval alone cannot account for the full observed warm walls.

This closes the initial runnable public measurement seam for the older arithmetic
consumer. It does not establish source/search/domain/authoring performance,
Linux deployment, current D44/D47 behavior, an enforced latency budget or a
speedup over the earlier 59s/21s launch checks.
