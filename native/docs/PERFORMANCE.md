# Native performance observations

The [31 October receipt](../evidence/2026-10-31-foundation-performance.json)
compares immutable `01b0fbd` and foundation `f0dfad7`, before Sol changes. It has
**no specialist-panel numbers and no new theorem**. Both six-provider hosts
were built in release mode, serially, with two build jobs and warm artifacts.

The same hbox ran both orders, with 80 measured HTTP calls per fixture after
five warmups. Inputs cover small/large science, statistics, alignment and graph
reasoning, incremental computation, actual clingo, one invalid argument case,
and three reader cases over one admitted image. All 28 cross-revision fixture
pairs had identical semantic replies/evidence after the receipt's explicit
identity/timing exclusions. Two reader cases refused ambiguous answer forms;
the retained relation control answered `genre`. These are workloads, not a
reader coverage score.

| Observation | Before foundation | Foundation |
|---|---:|---:|
| Pure HTTP median, matched workload ratios | reference | 0.993–1.006 times reference |
| Reader website refusal median, two orders | 86 / 134 ms | 66 / 90 ms |
| Reader composed refusal median | 109 / 195 ms | 82 / 129 ms |
| Reader answered control median | 45 / 79 ms | 41 / 68 ms |
| Fresh-process startup median, two orders | 1.00 / 1.09 s | 1.33 / 1.58 s |
| Sampled steady host RSS, reader-inclusive runs | 43–45 MiB | 39 MiB |

The old listener sleeps 20 ms when no connection is ready. Pure calls therefore
show no resolved HTTP gain despite internal savings. Reader calls were faster
in these observations; startup was slower. The shared 24-logical/16-physical-CPU
machine's load changed from roughly 14 to 31, so these observations do not isolate
causal speedups or regressions. Startup includes image/solver hashing, opening
state and readiness; OS caches stayed warm. The receipt retains p50, p95,
throughput, outcomes, load and complete artifact references.

With capacity four and four clients, both versions answered about 198 calls/s.
At eight clients they completed about 395 HTTP requests/s, but half were busy
refusals: successful answer throughput stayed near 198/s. Foundation's new
one-live-call-per-tenant cap answered 10/80 requests with one tenant and 40/80
with four tenants; the rest were immediate refusals. This establishes the
observed admission behavior, not queued fairness. A foundation-only fuel-one
probe refused shared work. Neither new policy knob is an old-version speed test.

A separate science microbenchmark starts and ends with JSON `Value`, uses the
same foundation kernel, and asserts equal replies. Over 100 warmed calls:

| Rust allocation calls / requested bytes per call | Wire path | Typed path |
|---|---:|---:|
| Small science | 221 / 17,274 | 158 / 9,636 |
| 48-variable science | 8,939 / 428,145 | 3,148 / 278,224 |

These are global Rust allocation requests, including realloc's new size, **not
HTTP allocations, live memory or C allocations**. The scope excludes the host's
other validation and transport work. No universal boundary saving follows.

A final separate 1,024-fact clingo probe observed host and solver together using
an owned-child walk with a nominal 2 ms sampling wait. Sampled tree RSS peaks
were 25.0 MiB before and 22.3 MiB after; PSS peaks were 22.1 / 20.1 MiB. Short
peaks can still escape sampling; summed RSS counts shared pages twice. The
initial monitor missed short solver children; its AB PSS parser also failed.
Those missing values are null in the receipt, with corrected BA and separate
memory samples retained. No hard aggregate memory ceiling is claimed.

One-millisecond deadline probes returned a deadline error and showed zero live
work at the first later health observation. The health transport itself waits
about 20 ms, so this does not measure sub-millisecond cancellation or interrupt
foreign code. Foundation also repairs old decimal-to-binary rounding; these
integer-valued fixtures avoid difficult numeric tokens and do not establish
universal old/new numeric equivalence.

Reproduction commands and counting scope are in
[the benchmark guide](../../tools/bench/README.md). Immutable archives, binaries,
failed attempts and raw replies remain under
`var/sol-wave-20261031/measurement/` and hbox's
`/tank/lanes/o7-sol-measurement-20261031/`. Sol worker/readiness changes, reader
retained reservations and new consumer reuse need their own frozen comparison.

## Sol first-wave comparison

The [separate Sol receipt](../evidence/2026-10-31-sol-performance.json) uses the
validator's final checked 722-file snapshot, including the narrow reader refusal
repair. It excludes phase-two changes. Builds used the same release settings,
serial two-job warm target and pinned lockfiles. Both HTTP execution orders ran
40 calls per fixture; all 28 semantic reply/evidence pairs agreed.

| Same-image HTTP median, two orders | Foundation | Sol first wave |
|---|---:|---:|
| Small science | 20.12 / 20.24 ms | 0.484 / 0.642 ms |
| 400-base alignment | 19.93 / 20.30 ms | 4.30 / 2.92 ms |
| Eight clients, four tenants: answered throughput | 199 / 196 per second | 942 / 1,112 per second |

The new readiness handling removes the polling floor. At eight clients, 17–19
of Sol's 40 requests still received busy refusals; its larger **request** rate
is not an answer rate. Sampled reader-inclusive host/child RSS was 47–49 MiB
before and 38–39 MiB after. These are observations on a shared machine, not
hard ceilings or isolated attribution to one change.

Direct `Service::invoke` excludes TCP/readiness and final response encoding.
Small graph medians improved from 144 / 194 microseconds to 63.5 / 61.3, while
a 1,000-vertex graph **regressed** from 4.08 / 4.00 ms to 7.54 / 8.15 ms. Both
versions answered every measured call and returned matching graph results.
The machine has eight fast SMT cores and eight slower cores. One bounded pair
using the existing binaries on CPU 0 reduced the large-graph gap to 2.659 versus
3.534 ms, leaving a 33% regression. Scheduling explains part of the observation;
this experiment does not identify the remaining cause. Phase-two repairs must
compare against these retained artifacts rather than rewriting this result.

Prepared thermal chains included preparation and all scenario solves:

| Nodes / scenarios | Prepared batch median | Fresh factorization per scenario |
|---|---:|---:|
| 16 / 8 | 0.236 ms | 0.606 ms |
| 64 / 32 | 2.69 ms | 20.80 ms |
| 128 / 8 | 4.32 ms | 24.35 ms |

Ten trials checked temperatures against an analytic chain solution, original-node
power and boundary exchange, plus fresh/prepared agreement. These are internal
calls with cancellation-only control, excluding production fuel charging, HTTP
and physical-model validation. Solve-only times are separately retained.

Sequence pages and identities matched the stateless API exactly and matched an
independent both-strand scan. Timing did **not** establish a stable API advantage:

| Pages | Prepared first: prepared / stateless | Stateless first: prepared / stateless |
|---|---:|---:|
| 10 | 0.168 / 0.0447 ms | 0.0260 / 0.184 ms |
| 40 | 2.885 / 0.761 ms | 0.310 / 2.983 ms |

The second alternative was faster in either order. Output retention, allocator
and cache state confound this paired harness; the original negative observation
and its counterbalanced followup are both retained. A useful next experiment
must warm and drop each alternative symmetrically before claiming a speedup.

Reader instrumentation now supplies concrete counters: the website case had
20 matched readings, seven compiled plans, 16 execution-cache hits and four
projection hydrations; the composed case had ten final readings but 1,292
intermediate compilations. Tracked retained peaks were approximately 4.37 and
15.42 MiB respectively. Every measured outer reservation returned to zero after
the read. These conservative reservation units exclude SQLite, mmap and returned
wire-string ownership; they are not RSS or a complete heap account.

A selected five-case release diagnostic had no errors in 15 measured one-second
calls; medians were 83–119 ms. The separate five-second diagnostic also completed.
These small release observations do not erase the central validator's debug
one-second errors or establish stable one-second behavior for the retained cohort.
Full code/data reader comparisons and specialist-panel counts belong to the
central validation receipt, not this performance sample.

The [Sol harness guide](../../tools/bench/sol/README.md) records commands and
scope. Raw replies, source bindings, CPU/load observations, binary hashes and
build logs remain beside the earlier measurements. The runner was released
before phase-two execution; no phase-two fix is included above.

## Memory-scope repair in the expansion batch

Memory-only restrictions now share the same execution state instead of adding an
unlimited fuel ancestor. Genuine fuel/deadline restrictions still charge their
parents. Source review and focused tests cover these separate lifetimes.

One fixed-CPU comparison of retained first-wave and expansion release binaries
measured 1,000 calls per workload. Large-graph p50 changed from 3.934 to 3.485 ms
(11.4% lower), while p95 changed from 4.319 to 5.330 ms (23.4% higher). Small-graph
p50 changed from 72.5 to 76.9 microseconds. This does not establish that the
regression is closed; the earlier foundation observation was faster. The
[expansion receipt](../evidence/2026-10-31-native-expansion-validation.json) retains
the actual pair and its limits. No repeated sweep selected a favorable result.

The next target is time close to the underlying computation, with measured costs
for validation, dispatch, allocation and encoding. A timeout is containment, not
a performance objective. Reader interpretation/compilation counts and symmetric
prepared-consumer benchmarks are concrete next targets.
