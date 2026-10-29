# NRGC — resident extracted graph certificate checker

Author: Codex lane `resident_graph_checker`, 29 October 2026.
Status: implementation authored; central qualification remains. No specialist
panel numbers, build result, test result or performance number is claimed.
Root owns integration, builds and commits. The lane ran no tests, MLton or
Isabelle. It ran `rustfmt --edition 2021` on its three Rust files; exit 0.

## What changed and who consumes it

- `src/extract/discrete-certificate/main.sml`: the former finite v1 reader is a
  bounded, resident v2 line reader. It retains the full declared vertex universe,
  ordered edge rows, exact signed i64 weights and occurrence IDs, and still calls
  the existing extracted `external_mst_cert` for every acceptance. Good rejected
  and unsupported graphs retain the worker. Corrupt or overlong frames end it.
- `native/oracle-core/src/kernel.rs`: new fixed `MstCertificate` family;
  `kernel::MstGraph`; independent full-universe/ID validation; typed
  `check_mst`/`check_mst_with_budget`; original-budget composition support;
  receipt admission; process PID diagnostics. It reuses the original bounded
  pool, tenant cap, byte snapshot, owned process group, deadline/cancellation and
  cleanup machinery. It does not add another pool or process implementation.
- `native/oracle-python/src/kernel.rs`: tenant `check_mst`; optional
  reasoning-feature `minimum_spanning_forest`, which actually calls Rust's graph
  producer plus independent forest checker and then the resident extracted check
  on those exact IDs. Results retain `rust_forest` and `certificate` separately.
  Deployment metadata accepts optional `compiled_receipt: {path, sha256}`.
- `src/extract/discrete-certificate/check.py`: persistent `ResidentChecker`
  facade and JSONL CLI backed by that native host. One host per stream/batch;
  no Python subprocess transport. The extension is installed normally or loaded
  from operator environment `ORACLE_NATIVE_EXTENSION`. Existing standalone
  `check(request, path)` callers must construct `ResidentChecker(path)` once and
  pass it instead. A compiler receipt has to be explicitly hash-admitted before
  a runtime acceptance can carry HOL scope.
- `native/oracle-core/tests/kernel_contract.rs`: focused transport fixtures and
  actual-artifact qualification case, described below.
- `src/extract/discrete-certificate/test_certificate.py`: actual v2/extension
  integration coverage, including real Rust candidate composition when built
  with the reasoning feature.
- `src/extract/discrete-certificate/benchmark_resident.py`: actual Rust candidate
  batches with stable resident PID and exact-result assertions, timing output,
  and a separate documented Linux process-tracing recipe.
- `src/extract/discrete-certificate/README.md`: current contract, consumers,
  receipt trust, bounded failure policy and central qualification recipe.

No `.thy`, `ROOT`, core `lib.rs`, provider, service or pool files were changed by
this lane. Root confirmed ownership of the actual driver, `main.sml` (there is
no `driver.ML` in this consumer).

## Existing theorem statements, unchanged

```isabelle
theorem external_mst_cert_spans:
  assumes "external_mst_cert vs es t"
  shows "spans t es \<and> connects t vs"

theorem external_mst_cert_minimal:
  assumes "external_mst_cert vs es t" and "spans t' es"
  shows "wt t \<le> wt t'"
```

The definition remains:

```isabelle
external_mst_cert vs es t = (distinct vs \<and> 2 \<le> length vs
  \<and> set vs = set (node_list es) \<and> mst_cert es t)
```

This proves spanning/connection and minimal exact rational weight for this
fully supplied connected graph with at least two declared vertices. It does
not prove the Rust producer, the graph's real-world coverage, the adapter,
compiler or a disconnected forest. Empty/singleton/disconnected/isolated cases
are `unsupported`; their independent Rust forest checking is retained.

## Exact resident protocol and failure behavior

The entire request is one ASCII LF-terminated line, at most 65,536 bytes including
LF: `mst-cert-v2 ID V E K`, exactly `3*E` edge tokens and then `K` occurrence IDs.
One space separates tokens. Integers are canonical decimal; signed i64 weights
and unsigned u64 request IDs are checked without floating-point conversion.
Limits remain 64 vertices, 256 edges and at most `max(V-1,0)` candidate IDs.
The SML reader bounds allocation while reading, rather than reading an arbitrary
line before checking size.

The one flushed response is `mst-cert-v2 ID accept|reject|unsupported` plus LF.
Native checks exact framing, request ID and supported/unsupported classification
before releasing its exclusive worker lease. Malformed output, wrong scope, EOF,
overflow, timeout or cancellation retire the owned process, join its I/O threads
and release capacity only afterward. SML malformed/oversized/unterminated input
ends the worker without guessing a new frame boundary. JSON validation errors
occur before I/O and can resynchronize at the next JSON line.

## Build evidence and trust

An admitted binary hash alone gives runtime predicate outcomes and
`evidence.kind: none`. HOL scope is attached only for acceptance with an
operator-selected, trusted-digest `native-compile` compiler receipt.
Admission bounds receipt files to 1 MiB, checks the compiler receipt digest,
compiled binary hash and byte count, successful compiler exit, fixed session and
export name, generated-code hash against the managed proof export, and the
compiled driver's source hash against the v2 driver built into the native host.
It requires the managed proof record to have passed with zero exits and no
cancellation, matching source digests and the exact oracle-free marker. It reads
the separately referenced proof receipt and checks its bytes/hash/record against
the compiler receipt. That proof receipt must remain at its recorded path.

The operator approves actual build provenance; receipt shape and hashes do not
prove an arbitrary binary correct. Compiler, parsing/framing and deployment are
still explicit trust boundaries. No tenant input can register a descriptor,
receipt or executable. Rejected/unsupported/error/cancelled outcomes never gain
the connected theorem.

## Authored checks; exact execution result

Execution result: **not run, per root's instruction that only the central
integrator builds/tests under managed resource controls**. No generated binary
was replaced by this lane. The prior v1 binary cannot serve v2 requests.

Core cases cover accepted/nonminimal/unsupported/accepted on one owned PID;
parallel identical occurrences; i64 extrema and a sum beyond i64; full ordered
input binding; forged/repeated IDs and invalid endpoints/numbers; request size;
malformed, oversized, wrong-scope and timeout replies; cancellation plus tenant
capacity and owned-process retirement; and rejection of incomplete forged
compiler receipt metadata. The mock is explicitly a protocol fixture and never
gets HOL scope. `real_mst_resident_protocol` is ignored until root explicitly
supplies the actual v2 binary/hash, and optionally the actual approved compiler
receipt/hash.

Python's 16 authored integration cases require the actual v2 checker and native
extension. The composition case needs the extension's reasoning feature; a skip
is not composition qualification. It covers actual Rust candidates, including
negative/extreme weights, parallel occurrences and disconnected forests, while
preserving candidate IDs, exact sums, Rust checking and one resident PID.
Direct native framing cases confirm that malformed/oversized/unterminated frames
exit. CLI bad JSON resumes safely at the next JSON line.

Central follow-through:

1. Compile the changed driver with existing managed `build.sh`; use its new
   compiler receipt. The theorem sources are unchanged; a current warm proof
   export can be reused. No new theorem is needed for residence.
2. Build core/extension in root's controlled slot, with `reasoning` for actual
   composition. Run scoped `kernel_contract` and the actual Python cases, then
   the ignored real-artifact core case with explicit artifact metadata. The
   README lists the environment variable names.
3. Run the benchmark with one then 1000 requests using warm artifacts. Stable
   observed checker PID is asserted; use Linux `strace -f -e trace=process` to
   independently verify one checker exec and zero additional process forks/execs
   per request. Distinguish I/O thread clones. Record actual timing/count results
   before making performance claims.

The native service/pool is outside this lane. The concrete consumer is the
PyO3 tenant API plus the resident JSONL CLI and Rust-candidate batch facade.
