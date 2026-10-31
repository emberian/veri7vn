# Sealed Sol measurement preparation

**Preparation only until the central validator explicitly releases the runner.**
No harness here is a theorem, a specialist panel, or proof of an aggregate RSS
bound. Build/run only the sealed snapshot, never the changing shared worktree.

The validator's first-wave source was extracted for measurement as the 722-file tree
at hbox `/tank/lanes/o7-sol-measurement-20261031/sol-sealed`, bound by
`checked-source.tar` SHA256
`1cc9257be31ca0279350d4b8f73e36db923797311fb149323ebbfdcabf55674e`
and `checked-source.json` SHA256
`6935098ca7b9615f07026e34aa441e396edb37ef5db3535bb8ef0e4594a3d69b`.
Root/validator must confirm this binding and transfer the runner before execution.
The comparison source remains immutable foundation `f0dfad7` at
`/tank/lanes/o7-sol-measurement-20261031/foundation`. Its release host is retained
as `foundation-host` in that parent directory. Keep every new binary separately.

## Build and run, after baton

Create each standalone harness under a NEW directory inside owned scratch:

```
python3 tools/bench/sol/prepare.py --snapshot SNAPSHOT --out ROOT/direct-harness --kind direct
python3 tools/bench/sol/prepare.py --snapshot SNAPSHOT --out ROOT/reader-harness --kind reader --candidate
python3 tools/bench/sol/prepare.py --snapshot SNAPSHOT --out ROOT/consumer-harness --kind consumers --candidate
```

For foundation reader omit `--candidate`. Foundation has no new consumer APIs;
consumer comparison is explicitly same-version reuse versus equivalent fresh work.
`prepare.py` only copies source/lockfile and writes Cargo metadata. It never builds.
The candidate feature recorded in PREPARATION.json must also be passed to cargo
for candidate reader instrumentation (`--features candidate`).

Use a single build at a time, `CARGO_BUILD_JOBS=2`, and existing warm
`CARGO_TARGET_DIR=/tank/lanes/o7-native-20261028/target`. For example:

```
CARGO_BUILD_JOBS=2 CARGO_TARGET_DIR=/tank/lanes/o7-native-20261028/target cargo build --offline --release --manifest-path ROOT/direct-harness/Cargo.toml
```

Use `ROOT/reader-harness/Cargo.toml --features candidate` for the candidate
reader and `ROOT/consumer-harness/Cargo.toml` for consumers. Then COPY the
resulting binary before the next build. Binary
names are `sol-measure-direct`, `sol-measure-reader`, `sol-measure-consumers`.
Retain lockfiles, build logs, hashes and every failed attempt. Fix a harness in its
owned paths rather than altering the sealed implementation source.

Build the candidate release oracle-host separately from the sealed native
manifest, using all six features and the same two-job/warm-target controls. Copy
it as `sol-host` beside retained `foundation-host`. HTTP comparison:

```
python3 tools/bench/native_foundation.py --root ROOT --versions foundation,sol --fixtures tools/bench/native_foundation_fixtures.json --image FIXED_IMAGE --repeats 40 --out HTTP-AB.json
python3 tools/bench/native_foundation.py --root ROOT --versions foundation,sol --fixtures tools/bench/native_foundation_fixtures.json --image FIXED_IMAGE --reverse --repeats 40 --out HTTP-BA.json
```

Use the same image SHA and clingo for both; separately record candidate data/image
results rather than silently mixing an image repair into the code comparison.
OMP/OpenBLAS/MKL/Rayon thread counts are fixed to one by the HTTP observer. Set
these same variables to one for direct harnesses. Record CPU affinity/core count,
load before/after, fresh-process startup, sampled tree RSS/PSS/private memory,
refusals and **answered** throughput. Keep both execution orders; no cache drops.

## What the direct programs measure

`sol-measure-direct OWNED_RUN_DIRECTORY` (compiled from `direct.rs`) opens one Service then measures 1,000 serial
small and 1,000 serial large graph invocations after 20 warmups. It includes
request decoding, admission, provider work, worker dispatch, interpretation and
reply Value construction, but excludes TCP/HTTP readiness, ingress and final
encoding. Check all replies answered and compare graph results with volatile
provider timing/deployment identity fields excluded. Compare foundation/candidate
in both orders. This measures the reusable-worker path separately from readiness;
HTTP minus direct is not a controlled causal decomposition.

`sol-measure-reader IMAGE SHA256 FIXTURES_JSON [TIMEOUT_MS=1000] [REPEATS=10]` (compiled from `reader.rs`) opens the same image, takes three warmups,
then the declared number of reads per reader question. It retains all decoded replies/errors
and latency samples. Candidate records include matcher count, actual compilation
count, execution-cache hits, projection hydrations, unique outcomes, wire bytes,
inner retained live/peak and outer budget live-after/peak/limit. Baseline counters
are unavailable, not zero. Explicit reservation units exclude SQLite/mmap and
allocator metadata; observe actual process RSS separately. Include semantic
refusals and errors, not just successful answers. Outer live-after should be
checked even when evaluation errors and therefore emits no successful probe.

`sol-measure-consumers` (compiled from `consumers.rs`) compares three bounded equal-conductance thermal chains
(16 nodes/8 scenarios, 64/32, 128/8), then two exact collection paging workloads.
Ten trials retain every timing; no threshold chooses winners. Thermal reports
prepared-plus-prepare and solve-only times separately, versus fresh network
factorization per scenario. It checks `T_i = T_boundary + load*i/2`, original-node
power, boundary exchange and fresh/prepared numerical agreement outside timing.
Different fresh SVD diagnostics are not required to equal absent prepared solver
diagnostics. This workload does not measure the HTTP batch admission ceiling.

Sequence trials include preparation and every page. They compare all returned
pages (identities, cursor bounds, work counts and hits), then flatten against an
independent naive both-strand original-coordinate scan. Workloads include reverse
and palindromic patterns. The repeated stateless alternative retains one owned
request but rebuilds normalization/trie per page, as that API does. Preparation
cost is included in the main ratio, so small or negative gains remain visible.

The initial preparation ran no checks. The first permitted
execution is a narrow compile, followed by equality assertions; a failed equality
is a failed workload, not a speed result. Root owns final integration/commit.

`reader_deadline_fixtures.json` retains the five cases selected by earlier one-second deadline observations. They are an explicitly selected diagnostic, not a representative coverage cohort. Keep one-second results and five-second diagnostics separate; raising the budget does not repair one-second behavior. Warmup errors are also retained. `observe.py` records process tree memory and load around each direct executable.

The final first-wave run used 40 HTTP calls per fixture, not the earlier foundation
receipt's 80. Direct readers retained the one-second limit. Candidate counters
were measured on the fixed original image, not silently on the plural-data repair.
The five-second diagnostic is separate. First-wave runner execution was released
before phase-two overlays.

The sequence followup supports `SOL_FRESH_FIRST=1` on the same executable.
Its paired timing still keeps the first result alive during the second and does
large JSON/naive validation after both; reversing order flipped the ranking.
Therefore these samples establish identity/completeness agreement but do not
resolve a stable performance advantage. Both original and reversed observations
are preserved. Consumer controls use an uncancelled `AtomicBool`, not production
fuel/deadline accounting.

`summarize.py` creates the concise receipt from fetched raw observations and
hashes them; it never executes a workload. `observe.py` treats a taskset command
as the binary being launched, so its binary hash in CPU0 wrapper records hashes
taskset; the underlying direct executable hash is separately retained. Its
reported affinity is the observer parent's; the explicit taskset command and
successful exit bind the one-CPU experiment.

## Exact executed interfaces and source chain

The first-wave direct executable has **no count argv**. Each invocation records
1,000 small plus 1,000 large measured calls, after 20 warmups per workload. Thus
each paired old/new comparison contains 4,000 measured calls. Later phase-two
100-call variants are different harnesses and do not change this receipt.

The current `direct.rs` and `reader.rs` match the retained executed copies byte
for byte. Current `consumers.rs` matches the counterbalanced executable's source.
The first consumer pass is retained as `recorded/consumers_first.rs`: recovered
from the retained preparation source with the single documented prebuild
`starts_with(pat.as_str())` change. That first input was not separately hashed
at compile time; the original executable is retained and hashed. The receipt
labels this provenance limit instead of calling the preparation hash a compiled
source hash. Hashes for preparation, recovered first pass, followup and binaries
are recorded together. No source or benchmark was rerun during reconciliation.

To reproduce the original fixed-order source, prepare a consumer directory then
copy the recorded source before building:

```
cp tools/bench/sol/recorded/consumers_first.rs ROOT/consumer-harness/src/main.rs
```

Here `ROOT/consumer-harness` must be a new preparation directory. To reproduce the counterbalance, use current `consumers.rs` in a new
directory and run the **same copied executable** in both orders:

```
sol-measure-consumers
SOL_FRESH_FIRST=1 sol-measure-consumers
```

The environment variable applies to sequence timing only; thermal retains its
original prepared-first order. Both consumer sources use ten trials per case,
with no trial-count argv. Executable names above may be replaced by their copied
absolute paths. To reproduce observed metadata, run them through `observe.py`:

```
python3 tools/bench/sol/observe.py --out direct.json -- /absolute/direct-bin /absolute/new-run-directory
python3 tools/bench/sol/observe.py --out sequence-prepared.json -- /absolute/consumer-bin
SOL_FRESH_FIRST=1 python3 tools/bench/sol/observe.py --out sequence-fresh.json -- /absolute/consumer-bin
python3 tools/bench/sol/observe.py --out reader-1s.json -- /absolute/reader-bin IMAGE IMAGE_SHA FIXTURES_JSON 1000 3
python3 tools/bench/sol/observe.py --out reader-5s.json -- /absolute/reader-bin IMAGE IMAGE_SHA FIXTURES_JSON 5000 1
```

Use `native_foundation_fixtures.json` with reader `1000 10` for the three fixed
reader workloads; use `reader_deadline_fixtures.json` for the `1000 3` and `5000 1`
diagnostics above. The CPU0 diagnostic uses `observe.py --out CPU0.json --
/usr/bin/taskset -c 0 /absolute/direct-bin /absolute/new-run-directory`.
