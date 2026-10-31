# One next-cycle decision comparison

Executed once after central correctness and explicit runner handoff; all seven
matched comparisons and independent checks passed. The runner is released.
Existing baseline receipts remain unchanged. The protocol below records the
executed cohort; do not launch another comparison without a named question.

## Pin work and boundaries

PRE is the accepted expansion source, not `f0dfad7` (which lacks GLM):
`/tank/lanes/o7-expansion-validation-20261031/source`. Bind it to the existing
[expansion receipt](../../../native/evidence/2026-10-31-native-expansion-validation.json):
validated archive SHA256 `1b23eb0de91cc3ac4adf69474968e6794f94b2dca46542269c149a1b67efb822`,
manifest SHA256 `5b9fb20ca89dabfb0bb2ca3029adb257ae2297d49c8d9432fc5a87d9884091dd`.
The named test-only supplement adds one Python test, not runtime code.
The retained PRE host is `artifacts-release/oracle-host` under that root,
SHA256 `b60218021fd65285500ec224d63031428b0e285593beaa22503cf2d170f08db6`.
POST must be a new central sealed source/manifest, never the live shared tree.

`next_cycle.rs` measures one **encoded service boundary**. PRE uses old
`Service::invoke` plus the final caller encoding, matching its HTTP path. POST
uses `invoke_encoded` and its owned bytes directly. It does not time the POST
Value compatibility adapter, whose decoding would create a false production
cost. Neither includes TCP accept/ingress or socket writes. Actual HTTP byte,
oversize and replay correctness belongs to the central transport checks.

Baseline boundary is confirmed by the expansion validator: Value-returning
`Service::invoke`, no `invoke_encoded`; LP/GLM admitted and memory fix included.

The fixed cohort is five service cases: a rational feasible interval, an analytic
binomial GLM, a small graph, the retained 1,000-vertex chain, and a 512-vertex
multigraph. The latter has 128 disconnected blocks with loops, negative weights,
parallel edges and ties: optimum weight −512, 384 edge IDs `[9k,9k+2,9k+4]`,
128 components. The graph owner confirmed this original-ID tie contract.
Each case gets five warmups and 50 measured calls. All must be HTTP-status 200
and semantically answered; independent checks occur before/after timing.
Canonical provider-envelope bytes and raw request bytes remain different counts.

Two actual `Image::read_whole` cases follow: a tiny learned nested composition
and the original supplied-image composed website/population case. The tiny case
uses the admitted `segments_contract.rs` wording, four finite entities and
explicit relation witnesses: Alice/Bob reside in York and work for Library;
“How many organisations employing persons in York?” must answer one with canonical entity `L` (Library) and the six-step nested
program/dependencies. A count of one for York cannot pass. Build its
image ONCE with PRE, then use those exact bytes/hash for both versions. The larger
image remains `/tank/lanes/o7-native-20261028/data/reader-image-v3.sqlite`, SHA256
`8fcb1db9a08e234179f66ea9e032d2633b38cdcb902f4c95d1ba2c2d49c842f4`.
Five warmups and ten measured reads retain the one-second budget and all errors.

## Structural evidence before wall time

Surface owner provides a filtered **cfg(test), thread-local** probe. Its passing
stdout emits `SOL_TYPED_PROBE_JSON` records: input decodes, canonical envelope
count/bytes, intermediate result-payload trees, result re-decodes and checked
reply serializations. LP/GLM should decode input once and avoid intermediate
payload trees/re-decodes. Use the exact filter `pure::typed::tests::typed_lp_glm_probe_has_single_decode_and_no_result_tree -- --nocapture`; preserve its source hashes in the central
receipt. A missing marker blocks the comparison report; no production atomics
or timing counters are added. Baseline counters may be unavailable, never zero.
The records concern unit fixtures unless their request hashes explicitly match
the timed fixture. Do not imply zero Value use or allocation-free admission:
scalar checks, property sets and regex bookkeeping remain. Finite/contract/event
walks are separate intentional traversals, not “one traversal overall.”

Reader owner extends the existing optional diagnostic probe with origins,
`unique_operations`, syntax specs, cache residency/hits, rejected-root hits and
actual materialization events. The harness collects ONE separate untimed real
read after timing. POST asserts zero `fragment_materializations`; final diagnostic
materialization is permitted and counted separately. Keep `packed_program::tests`
passing stdout (five declared tests, including 49×49 alternatives: 4,901 unique
lowerings versus 14,406 occurrence operations). Occurrence limits/admission must
still hold. The new `compiled_plans` means successful checked roots; PRE's count
meant full Program compilation. Never compare those two numbers as one metric.

## One frozen same-CPU release pair, after central go

Use NEW owned directories, the warm target, two build jobs and serial builds.
`next_cycle.py prepare` only writes Cargo/source; it never builds or runs:

```
python3 tools/bench/sol/next_cycle.py prepare --source PRE_SOURCE --source-manifest-sha256 PRE_SHA --out ROOT/pre
python3 tools/bench/sol/next_cycle.py prepare --source POST_SOURCE --source-manifest-sha256 POST_SHA --out ROOT/post --encoded --packed-probe
CARGO_BUILD_JOBS=2 CARGO_TARGET_DIR=/tank/lanes/o7-native-20261028/target cargo build --offline --release --manifest-path ROOT/pre/Cargo.toml
```

Copy `/tank/lanes/o7-native-20261028/target/release/sol-next-cycle` to
`ROOT/pre-bin` before the next build.
Build POST analogously with `--features encoded,packed_probe`, copy `ROOT/post-bin`.
The helper's feature metadata is descriptive; the cargo flags are required.
Create `ROOT/tiny` once using `ROOT/pre-bin fixture ROOT/tiny` and retain its JSON
path/hash. No production affinity setting changes. Run exactly one pair:

```
python3 tools/bench/sol/observe.py --out ROOT/pre.json -- /usr/bin/taskset -c 0 ROOT/pre-bin measure ROOT/pre-run TINY_IMAGE TINY_SHA LARGE_IMAGE LARGE_SHA
python3 tools/bench/sol/observe.py --out ROOT/post.json -- /usr/bin/taskset -c 0 ROOT/post-bin measure ROOT/post-run TINY_IMAGE TINY_SHA LARGE_IMAGE LARGE_SHA
python3 tools/bench/sol/next_cycle.py compare --pre ROOT/pre.json --post ROOT/post.json --pre-source-manifest-sha256 PRE_SHA --post-source-manifest-sha256 POST_SHA --typed-stdout TYPED_PASS_LOG --reader-stdout PACKED_READER_PASS_LOG --out ROOT/comparison.json
```

`observe.py` pins numerical thread environment to one and retains load, tree
RSS/PSS/private samples, elapsed time, output, exit and command. Taskset wrapper
hash/observer affinity are not target binary hash/affinity; hash both copied Rust
binaries separately. Save fixture/source hashes, CPU topology, compiler/profile,
structural stdout and complete observations. The graph sort is a bounded operation
with cancellation checks around it, not interruptible at every instruction.

Decision: require equal input/image hashes, matching semantic/evidence replies,
independent graph/LP/GLM/tiny-reader checks, passing structural assertions, no
reader errors and zero fragment flattening. Only then interpret latency/encoded
bytes. Keep p50/p95 and negative changes. A failure or mixed boundary is a blocked
workload, not a speed result. Repeat only for a named failure/confounder; no CPU,
thread, corpus or profile sweeps.

Sequence is deliberately excluded. A future corrected sequence measurement must
validate both full outputs first, then independently warm each alternative, time
creation with identical drop lifetime, and avoid JSON/naive validation between
paired intervals. The earlier order-confounded records remain intact; none are
rerun by this protocol.

Central structural log filters (reuse these passing logs if already run; do not
repeat correctness builds solely for this harness):

```
cargo test --offline --manifest-path POST_SOURCE/native/Cargo.toml -p oracle-host --all-features --lib pure::typed::tests::typed_lp_glm_probe_has_single_decode_and_no_result_tree -- --nocapture --test-threads=1
cargo test --offline --manifest-path POST_SOURCE/native/Cargo.toml -p oracle-runtime-core --lib packed_program::tests -- --nocapture --test-threads=1
```

Apply the same two-job/warm-target controls as other central commands. Save each
stdout separately as `TYPED_PASS_LOG` and `PACKED_READER_PASS_LOG`; comparison
requires passing summaries and both LP/GLM JSON records. Structural reader
counts in the comparison come from the harness's untimed real reads, not invented
numbers parsed from a zero-test pass.

## Recorded outcome

[The receipt](../../../native/evidence/2026-10-31-native-cycle-performance.json)
binds the final675-file POST source/archive (`5bf5c85a…`, manifest `1b49da53…`),
actual separately linked wrapper hashes, commands, min/median/p95 and all samples.
PRE built once from the already-started owned source copy. POST used the verified
original warm source as a read-only dependency; no production files were edited.
Both wrappers compiled and exited0; no failure, retry or timing sweep occurred.

| Encoded service median | PRE | POST |
|---|---:|---:|
| Rational LP | 96.16 µs | 49.41 µs |
| Binomial GLM | 179.94 µs | 85.34 µs |
| Small graph | 61.14 µs | 26.85 µs |
| Retained 1,000-vertex chain | 2.348 ms | 1.961 ms |
| 512-vertex multigraph | 2.145 ms | 2.016 ms |

Each operation's final encoded byte count stayed equal. These are observed gains
at the stated service boundary, not isolated kernel speedups or HTTP throughput.
The tiny reader slightly regressed (1.713→1.727 ms median), and the retained reader
was nearly unchanged (56.15→55.27 ms). No reader latency gain is established.

The untimed POST probes show zero fragment flattening, six unique operations for
the tiny case, and1,297 unique operations/651 syntax specs for the retained case.
The latter still performs1,292 fragment checks, with ten root-cache hits and two
final diagnostic materializations. Do not describe all compilation work as gone.
Tracked conservative peak units increased on the tiny case (62,595→306,757 bytes)
and decreased on the large case (16,167,853→6,109,824); accounting geometry changed,
so these are not like-for-like heap or RSS reduction ratios. Actual process memory
is separately recorded. Load was about2.11 on24logical CPUs; CPU0 was shared, not
reserved. One ordered pair supplies observations, not confidence intervals.
