# Hosted durable native runtime

Owner: Sol durable runtime host lane. Consumer: the standalone appliance service,
then an authenticated outer host. No specialist-panel numbers or new theorem
statements. The Python boundary is untrusted; the Rust runtime implements the
bounded query, session and exact-reply journal contracts.

Current status: central reports all 25 runtime/service contracts passing
(14 unit/fixture plus 11 actual-extension/process/HTTP), all 20 existing pool
contracts passing, and six domain plus eight package contracts passing with no
skips. The adapter import-identity repair and both fresh path-order cases pass;
no Rust rebuild was needed for that Python-only repair. No remaining hosted or
package issue was reported. No new panel scores or theorem statements.

## Contract before implementation

The operator fixes the extension digest, image path and digest, persistent state
path, release declaration and expected identity, core limits and per-file write
limit. None comes from an invocation. Startup opens the actual `Image` and
`Runtime.from_release` before discovery advertises its supported operations.
A worker retains one image/runtime and creates cheap tenant handles as needed.
The global process pool bounds workers across tenants and profiles. Its affinity
includes all runtime resources, not merely the extension digest. Two workers
may reopen the same journal and read-only image; their SQLite caches are bounded
separately and the OS may share image pages. This is not one Engine/data copy
per tenant, nor a claim that every worker shares one Python/Rust heap.

The six fixed operations are graph.query/execute, kqa.query/execute and
reader.whole/execute, subject to actual release admission. Graph/program input
is an exact JSON string so whitespace and key order retain the core's byte-level
retry identity. Language input is an exact question string. Stateful arguments
require expected_version explicitly. The outer envelope supplies request and
conversation IDs; host routing supplies tenant. Domain-separated hashes map
outer IDs into the core's stricter ASCII identifier space without truncation.
No nested session, request, tenant, resource, module or authority selector exists.

A stateful operation commits selection and reply atomically. A refused language
turn advances the version and preserves prior selection. Its response retains
both the new version and complete semantic reply, as authoritative exact native JSON bytes. The host extracts only bounded
status/image/coverage metadata and the checked version. Arbitrary-precision
numeric tokens never become decoded binary-float answers. The same request, input bytes, version, session and release replay the
same core reply after worker death or host restart. Changed input or a changed
release/data identity conflicts and requires explicit migration. Pure query IDs
remain correlation labels. There are no external effects.

Cancellation/deadline terminates and reaps the owned worker. A completed commit
can race with response loss: report state_may_have_changed and instruct an exact
retry, never invent rollback. Retiring a worker never removes persistent state.
A runtime child permits bounded file writes for its journal; the pure-only
worker retains its zero-write RLIMIT_FSIZE. A per-file cap is not a total journal
or filesystem quota. Core session/journal entry and state limits also apply.

The existing loopback header is host routing metadata, not authentication.
This work does not claim a public gateway, full Oracle Engine, signed Mini
qualification, binary attestation of Python/dependencies, or full language
coverage. Resource identity receipts contain hashes, never operator paths.

## Integration paths

New lane-owned modules: tools/appliance/native_runtime.py,
tools/oracle_components/native_runtime_adapter.py; new tests/appliance/test_native_runtime.py
and test_native_runtime_service.py; native/docs/RUNTIME-HOST.md.

After checkpoint 6cc653b, root transferred the pool/worker/service paths. The
implemented integration adds:
operator-only optional runtime configuration, resource-aware affinity, host
context in the private worker frame, runtime startup factory, journal write
limit and adapter registration. Central tests are still pending; no successful hosted journey is claimed yet.
Python AST parsing of seven changed source files passed; git diff --check passed.
No lane builds or tests were run. Exact manifest_json is supported for numeric
release metadata; float-bearing manifest objects are rejected. Runtime replies
carry only exact core_reply_json plus bounded adapter metadata, and startup
rejects result-byte bounds that cannot fit escaped transport frames.

## Implemented wiring awaiting central execution

Changed paths are the six new files above plus tools/appliance/native_pool.py,
native_worker.py, native_service.py and native/docs/STANDALONE.md (transferred
by root after the initial wiring). Existing typed bio/statistics refusal
contracts are preserved; runtime conflicts/budget/busy failures have their own
exact declared exception routing and remain conservatively retiring failures.

The pool snapshots operator configuration as a private read-only file, carries
host IDs in a separate private frame field and verifies resource identity at
worker readiness. Native release admission remains authoritative, including
exact manifest_json declarations. Runtime result bounds must satisfy
`2 * result_bytes + 16384 <= reply_bytes` before spawning. Supplied-argument providers can reuse a runtime-bound child of the same
artifact. Every runtime-profile call, including pure fixed-image reads,
additionally requires the exact resource identity. Retirement deletes only pool-owned snapshots.

Tests authored: profile/configuration and numeric-token boundaries; all six real
entrypoints; fixed release admission; semantic refusal and selection; exact
retry/restart and changed release; fake-service host-ID/authority contracts;
actual lost-response-after-commit injection; two-worker/many-tenant reuse;
same-artifact/different-journal affinity; cancellation retirement; actual CLI
HTTP discovery/language/previous/refusal/restart. The decimal fixture includes
0.123456789012345678901234567890 and 1e1000 source values. Complete native replies
remain raw text, so neither can become a rounded or infinite decoded answer.

Central validator was notified at source freeze. No build, test or specialist
panel execution was performed by this lane; current exact execution results
remain pending. No new theorem statements.

Retention compatibility: the core-limit allowlist includes retired_namespaces
(default 65536). After native admission, catalog/dispatch select only the six
fixed tenant operations; host.retention.retire/inspect stay private Runtime admin
methods even when the operator's release admits them. A unit regression checks
this exclusion. The runtime tests now contain ten unit contracts plus six
actual-extension contracts; the service tests contain three fixture contracts
plus five actual process/service/CLI contracts. All seven Python sources parse;
whitespace checks pass. Central execution remains pending at this report update.

Root static reviewer reported no actionable issue in host authority, resource
affinity, exact reply preservation or replay routing. That was source review,
not an execution result. Host retirement documentation links from RUNTIME-HOST.

## Central validation in progress

Central integrator reports all 13 new profile/adapter/service unit and fixture
contracts passing locally, and all 20 existing real-process pool tests passing.
The 11 actual-extension runtime/process/HTTP contracts await the newly rebuilt
combined core. These results are separate from checkpoint 6cc653b; this lane did
not execute tests or builds. No specialist-panel numbers or theorem statements.

Cancellation scope: trusted in-process NativePool callers can supply individual
per-call Events. The standalone HTTP service currently passes its shutdown Event
and applies wall deadlines. It has no individual HTTP cancellation endpoint.
This distinction is explicit in RUNTIME-HOST.md; current actual cancellation
coverage targets the trusted pool API, while the CLI test covers the HTTP
language/refusal/previous/restart journey. Root was notified of the optional
remote cancellation extension before any further source change.

Root approved one narrow test delta before actual execution: the actual pool-only
cancellation test is replaced by HTTP shutdown-cancellation composition. A real
loopback HTTP invoke reaches a test-gated worker exchange, host shutdown controls
trigger cancellation, HTTP reports uncertain state/exact retry and the owned PID
is reaped. A fresh service/server then retrieves the earlier exact reply and
selection from the persistent journal. This adds no production cancel endpoint
or caller-controlled fault flag. Source refrozen and central integrator notified;
13 unit/fixture and 11 actual-extension contracts remain the count.


## Import identity repair after central hosted checks

Central reports all 11 actual runtime/process/HTTP contracts passed. A mixed
domain-test process then exposed a real embedding collision: component-first
sys.path selected the component adapter when native_pool requested the flat
native_runtime host helper. Reordering that fixture unblocked execution but did
not remove the ambiguity. The adapter is now native_runtime_adapter.py, imported
through oracle_components.native_runtime_adapter. The appliance helper and its
fixed worker loader retain native_runtime.py. No duplicate basename or fallback
stub remains. Distribution owns the corresponding explicit payload-closure
rename. A fresh-subprocess contract checks both component-first and
appliance-first import orders, including object identity through native_pool and
native_service. This Python-only delta needs scoped central validation; no Rust
rebuild is required.


Final import-repair validation: central ran runtime17 plus service8, all passing
(14 unit/fixture and 11 actual); domain6 and package8 also pass with zero skips
and the original component-first test preamble. The fresh subprocess regression
passes both path orders. Central removed exactly its own stale remote copied
old adapter before final tests; the local renamed source already had no old
file. Consumer: NativePool/NativeService embedded imports and the relocated
standalone distribution. Module/class/operation/config contracts are unchanged;
only the component module basename and its qualified imports/payload entry
changed. No Rust build or test execution by this lane.
