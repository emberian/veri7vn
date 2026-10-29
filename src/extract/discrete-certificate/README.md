# Resident minimum spanning tree certificates

The Rust graph provider can propose a cheap network and pass its exact input-edge
IDs to a resident extracted checker. One checker process handles many requests.
The Rust provider keeps its independent forest coverage and cycle-optimality
check. The extracted predicate supplies a separate connected-tree guarantee.

The HOL guarantee covers a connected graph with at least two declared vertices,
with every declared vertex included in the supplied edges. Empty graphs,
singletons, isolated vertices and disconnected graphs return `unsupported` from
this interface. Their Rust forest result remains useful. There is no extracted
forest theorem here.

Central Linux qualification passed: 13 normal core transport contracts, one
actual Rust resident MST contract, and all 16 actual Python cases with zero
skips. The actual Rust candidate consumer and receipt-admitted acceptance were
exercised. [The retained evidence](../../../native/evidence/2026-10-29-resident-mst.json)
binds the source, checker, receipts and final stable extension. No new specialist
panel numbers are available; this is a checking consumer, not a specialist answerer.

## Build and use

Root owns the build slots. The managed proof build is unchanged:

```sh
python3 tools/dev/remote-build hbox src/extract/discrete-certificate Veri7vn_Discrete_Certificate \
  -d src/extract/discrete -d src/extract/commons \
  --expect 'VERI7VN_DISCRETE_CERTIFICATE PASS theorems=4 oracles=0'
sh src/extract/discrete-certificate/build.sh
```

`build.sh` consumes a published proof export through `native-compile`, which
checks its managed receipt and holds the native compiler lock. It never starts
Isabelle. Recompile after changing `main.sml`: the former finite v1 binary
cannot serve this resident v2 protocol. The theory and its session are unchanged.
A warm matching proof receipt can be reused by `native-compile`.

The JSON command now requires the actual `oracle_native` extension. Install it
normally or set `ORACLE_NATIVE_EXTENSION` to the operator-selected extension
path. Build that extension with its `reasoning` feature to enable the combined
Rust producer/checker method and its composition tests.

```sh
printf '%s\n' '{"schema":"veri7vn-mst-certificate-request-v1","graph":{"vertices":3,"edges":[[0,1,4],[1,2,1],[0,2,7]]},"edge_ids":[0,1]}' |
  python3 -B src/extract/discrete-certificate/check.py
python3 -B src/extract/discrete-certificate/test_certificate.py
```

Construct `ResidentChecker` once for a batch. `check(request, checker)` accepts
that existing host; it does not create a process host for each request. The CLI
keeps one instance for its entire JSONL stream. It uses the native host's copied
executable snapshot, bounded slots and pipes, tenant cap, deadline, cancellation
and owned process-group cleanup. It implements no second process transport.
Python validation errors never enter the checker; the next JSON line can still
use the resident. A broken checker exchange retires its process before another
request is admitted.

## Connected-tree evidence needs an admitted compiler receipt

A hash of arbitrary executable bytes does not establish a theorem. By default,
a successful checker response has `status: accepted` but `evidence.kind: none`.
It reports a runtime predicate outcome and observed byte identity only.

An authenticated operator can additionally supply:

```sh
python3 -B src/extract/discrete-certificate/check.py \
  --checker /absolute/path/to/mst-certificate \
  --checker-sha256 TRUSTED_BINARY_SHA256 \
  --compiled-receipt /absolute/path/to/native-attempt/compile-inputs.json \
  --compiled-receipt-sha256 TRUSTED_COMPILE_RECEIPT_SHA256
```

The operator must select and approve these digests from the actual managed
build. The native host reads bounded receipt files and checks the approved
compiler receipt digest, compiled binary digest and size, successful compilation,
fixed session/export, generated-code digest against the passed proof export,
and the compiled `main.sml` digest against the driver built into the host. It
also checks the nested passed, uncancelled proof record against the separately
hashed proof receipt file. Keep that proof receipt at its recorded absolute path
when deploying this version. The receipt format is the existing
`native-compile` format, not tenant-supplied declarations.

Only `accepted` with this admission gets `extracted_hol_connected_mst`, the two
theorem names and the admitted receipt digest. `rejected`, `unsupported`,
malformed output, timeout and cancellation never acquire HOL scope. This is
operator-admitted build evidence, conditional on the compiler, deployment and
untrusted parsing/framing. It is not a proof of those adapters or of a real-world
graph's completeness.

## Native and Python consumers

Register family `mst_certificate` through an operator-created `KernelExecutor`.
Tenant handles cannot register executables or receipts. Optional descriptor field
`compiled_receipt` contains exactly `path` and the operator-approved `sha256`.
The four original descriptor fields remain `id`, `executable`, `sha256`, `family`.

Core Rust offers `check_mst` and `check_mst_with_budget` on `KernelExecutor`, with
`kernel::MstGraph` and occurrence IDs. It independently checks all input endpoints,
full declared graph components, candidate range/uniqueness, graph limits and
request size before process I/O. It sums weights in i128 and returns decimal text.
A supported graph cannot be reported `unsupported`, or an unsupported graph
reported accepted/rejected: such a reply retires the worker.

PyO3 exposes `KernelTenant.check_mst(kernel_id, graph_json, edge_ids_json,
cancellation)` and, with the `reasoning` feature,
`KernelTenant.minimum_spanning_forest(kernel_id, graph_json, cancellation)`.
The latter calls the actual Rust provider and independent Rust forest checker,
then passes those edge IDs to the resident extracted checker under the original
request budget. It returns `rust_forest` and `certificate` separately. The Python
facade also exposes `ResidentChecker.minimum_spanning_forest(graph)`.

Every native reply includes its `worker_pid` for reuse and retirement diagnostics.
It is process evidence, not mathematical evidence. Requests remain stateless;
neither graph operation changes the native conversation journal.

## JSON contract

One request and one response per JSON line. Blank lines are ignored. Optional
`id` is a string, integer or null. The graph vertices are exactly integer labels
`0 .. vertices-1`. Their canonical decimal strings are injective HOL node labels.
A provider with other names must retain its reversible name-to-index map.

```json
{"schema":"veri7vn-mst-certificate-request-v1","id":"example","graph":{"vertices":3,"edges":[[0,1,-9],[1,2,-3],[0,2,0]]},"edge_ids":[0,1]}
```

An undirected edge's occurrence ID is its zero-based input-list position. Order,
parallel edges, identical rows, candidate-ID order and self-loops are preserved.
Weights must be exact signed i64 integers. Candidate IDs must be distinct and in
range. No search, repair, case folding or edge deduplication occurs in the check.
HOL compares edge-triple lists; identical parallel occurrences have the same
mathematical value, while their occurrence IDs remain distinct externally.

Limits are 64 vertices, 256 edges, at most `max(vertices-1,0)` candidate IDs and
65,536 bytes per JSON line. The small limits bound the extracted closure/counting
checker; no large-graph performance claim follows. Timeout is in `(0,60]` seconds,
default 10. Host memory/CPU containment is still necessary.

Results use schema `veri7vn-mst-certificate-result-v1`: external `id`, `status`,
graph sizes, component count, `edge_ids`, exact decimal-string `total_weight`,
`input_sha256`, `worker_pid`, `admission` and `evidence`. The input digest binds
canonical ASCII JSON of `{"graph":...,"edge_ids":...}` with sorted object keys
and compact separators. Reordered rows or candidate IDs change that binding.
The weight is only the candidate's sum unless acceptance is justified.

- `accepted`: runtime predicate returned true; HOL evidence additionally needs
  the admitted compiler receipt described above.
- `rejected`: this supported graph's supplied candidate failed. It does not say
  that a minimum tree does not exist.
- `unsupported`: fewer than two vertices or disconnected graph. No HOL evidence.
- `error`: malformed JSON/input bound or native transport failure. No HOL evidence.

## Resident wire protocol and failure policy

The private protocol is exactly one ASCII line per request:

```text
mst-cert-v2 REQUEST_ID V E K u0 v0 signed_weight0 ... edge_id0 ...\n
```

After the header come exactly `3*E` edge tokens, then `K` ID tokens. Integers are
canonical decimal: no plus signs, leading zeros, negative zero, ML `~`, exponents
or fractions. Weights span signed i64, request IDs unsigned u64. Tokens have one
ASCII space between them; the final LF counts toward the 65,536-byte bound.
The SML reader bounds allocation while reading, before parsing a line.

The response is `mst-cert-v2 REQUEST_ID accept|reject|unsupported\n`, flushed
immediately. All three outcomes leave the same process available. The SML driver
exits on malformed, overlong or unterminated frames; it does not guess where a
corrupt frame ends. The native host retires on malformed/wrong-ID/wrong-scope
responses, EOF, deadline, cancellation or output/stderr overflow, and joins its
I/O threads before releasing the lease. A new request can start a fresh process.
JSON errors are outside this protocol and can safely resynchronize at their
own line boundary.

## What the predicate proves

The unchanged definition `external_mst_cert vs es t` means that `vs` is distinct,
has at least two vertices, its set equals the edge-derived vertex set, and
`mst_cert es t` passes. The existing theorem statements are:

- `external_mst_cert vs es t ==> spans t es AND connects t vs`.
- `external_mst_cert vs es t ==> spans t' es ==> wt t <= wt t'`.

`spans` means selected triples belong to the supplied graph, the selected list
has one fewer edge than the graph's vertices, and it connects those vertices.
`wt` sums exact rationals. Signed integer weights become denominator-one
rationals. The export's final command scans four theorem dependency trees for
oracles and prints its marker only after generated-code smoke checks.

JSON parsing, the SML adapter, scope classification, occurrence-ID projection,
compiler and deployment remain outside HOL. The complete declared vertex list
still reaches `external_mst_cert`; the theorem's vertex coverage premise has not
been weakened. `.thy` and `ROOT` were not changed for residency.

## Focused qualification and zero-per-request-fork measurement

To reproduce central qualification, run core `kernel_contract` tests and the
actual extension tests with the reasoning feature, then explicitly invoke the ignored
`real_mst_resident_protocol` core test with `ORACLE_TEST_MST_BIN`,
`ORACLE_TEST_MST_SHA256` and optional `ORACLE_TEST_MST_COMPILED_RECEIPT` plus
`ORACLE_TEST_MST_COMPILED_RECEIPT_SHA256`. Python uses `MST_CERTIFICATE_BIN`,
`MST_COMPILED_RECEIPT` and `MST_COMPILED_RECEIPT_SHA256` for the same artifacts.
No mock transport fixture is allowed to claim HOL scope.

```sh
python3 -B src/extract/discrete-certificate/benchmark_resident.py --iterations 1000
```

The benchmark composes actual Rust candidates with one resident checker and
reports elapsed time, p50/p95 and observed checker PIDs. It asserts one PID and
matching exact weights across the batch. It does not turn stable PIDs into a
claim about every process on the host. On Linux, capture actual process creation
for the same narrow workload:

```sh
strace -f -e trace=process -o var/discrete-certificate/resident-process.trace \
  python3 -B src/extract/discrete-certificate/benchmark_resident.py --iterations 1000
```

Inspect the trace for one checker exec and no additional process forks/execs
as the request count increases; distinguish the host's three I/O thread clones
from process creation. Compare one request with 1000 using the same warmed
artifacts.

The central 1000-request batch took 2.171 seconds, p50 2.123 ms and p95 2.279 ms.
A separate 1000-request Linux trace recorded one checker exec/PID and zero
additional process creation per request, distinguishing thread clones. These
benchmarks used the earlier combined extension `bf8cd8e713ce…`; the final stable
extension `f875fc2e217c…` reran all 16 actual Python cases and the real Rust case.
The kernel, producer and driver sources are unchanged between those artifacts.
Full digests and the trace binding are in the retained evidence. Traced timings
are not performance estimates. These small sequential supplied-graph batches do
not establish general latency, throughput or fairness.
