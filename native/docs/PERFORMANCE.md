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
