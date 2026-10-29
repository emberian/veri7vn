# Shared native Oracle foundation

The [native integration program](docs/INTEGRATIONS.md) adds optional graph,
symbolic/dimensional, scientific and incremental-reasoning providers. They have
Rust libraries, CLIs and feature-gated PyO3 calls; their experimental status and
remaining hosted boundaries are explicit.

The [standalone native service](docs/STANDALONE.md) exposes these computations
through discovery and direct HTTP calls, sharing bounded workers across tenants.
It runs and tests without any minidregg dependency or public Oracle dataset.

This is the Rust and PyO3 foundation for the next Oracle appliance. It builds a
release's knowledge base once, executes structured query plans over shared
indexes, and persists a conversation's selection and exact replies together.
A tenant handle holds an identity and a shared reference. It starts no process,
loads no corpus, and owns no database connection.

The callable library now includes the full pinned KQA program vocabulary,
exact typed predicates and scalar answers, a whole-template language reader,
release-bound restart/retry, and bounded resident transport for the extracted
quantity/acoustics kernels. Rust hosts can commit authorized effect intents
with a query and recover their outcomes through an outbox. Python is not called
inside any of these native execution paths.

This is not the complete Oracle Engine and is not installed in signed v7.
Compositional language readers, the full route cascade and dialogue adapters,
additional specialists and real effect executors remain. The [migration
map](docs/MIGRATION.md) identifies those surfaces and the practical Python
boundaries. The [development roadmap](docs/ROADMAP.md) sets out the shared
runtime design, extracted-code strategy, candidate specialist libraries and
performance evidence needed for an upstream proposal. There are no new
specialist-panel scores. The separate [extracted graph checker](../src/extract/discrete-certificate/README.md)
connects supplied connected-tree candidates to specific Isabelle theorems; it
does not confer formal assurance on the Rust runtime or other computations.

## What runs

`oracle-core` contains the image builder, query compiler, execution budgets and
transactional state store. It has no Python dependency and forbids unsafe Rust
in our code. SQLite and PyO3 remain native dependencies with their own safety
boundaries. `oracle-python` exports the same core through PyO3, releasing the
interpreter while native work runs. Both share the checked-in Cargo lockfile.

The builder accepts a complete KQA-shaped JSON knowledge base. It preserves
source records, typed attribute values and relation qualifiers; creates reverse
relation indexes; deduplicates identical edges; and checks dangling references.
Concept hierarchy and entity membership have separately indexed kinds. Numeric
source digits are preserved rather than converted through a binary float.
Publication uses a temporary file, fsync and a no-overwrite publish. A receipt
binds source bytes, image bytes and schema version. Build-time memory is separate
from serving memory: the current builder parses the whole source offline.

Queries contain validated acyclic graphs, with typed attribute and qualifier
filters, relation/concept operations, exact selection and scalar projections.
The separate `query_program` / `execute_program` APIs accept the upstream
`function/dependencies/inputs` format. They compile the complete program once;
no Python call occurs for each operation. The original bytes and explicit
dialect bind durable retry identity.

Single-use chains can remain inside SQLite's planner. Shared subplans are
materialized once in bounded worker scratch; they must not expand exponentially
during SQL preparation. Language execution checks every entity stage once,
including unused branches, to preserve its empty-intermediate refusal rules.

`build_reader_image` adds shared lexical and trained grammar indexes. Training
runs offline through `tools/export_reader_tables.py`; the export must bind the
exact KB digest. `Tenant.read_whole(question, cancellation)` performs indexed
lexical lookup, whole-template matching, native program execution, answer-form
guards and agreement under one worker lease and budget. Its result explicitly
says `whole_templates_only`; fragments, analogy and clause composition are not
silently treated as supported. Serving never learns or unpickles those tables.

No client SQL is accepted. Ambiguous names remain multiple candidates; a unique
name request reports ambiguity instead of picking the first. Returned coverage
means complete for the admitted image and this plan, not complete knowledge of
the world. Exceeding a bound fails the request; it never returns truncated data
as a complete answer. These are executable contracts, not Isabelle proofs.

## Use from Python

Build an image offline, then hold it read-only under the hosting operator's
control. Its digest must come from trusted deployment metadata. Hash verification
does not protect a file that another actor can rewrite after it is opened.

```sh
cargo run --locked --release -p oracle-runtime-core --bin oracle-image -- \
  /data/kb.json /images/kqa.sqlite 536870912 16777216
```

The two final arguments bound source bytes and one source record. The output is
a JSON receipt; its counts come from the built image, not a hardcoded catalog.

```python
import json
import oracle_native as native

# Once per hosted service, not once per tenant:
image = native.Image(image_path, trusted_image_sha256,
                     json.dumps({"workers": 2, "timeout_ms": 5000}))
runtime = native.Runtime.from_image(image, state_database_path)

# Only authenticated host code mints this handle. Give it to the caller's adapter.
tenant = runtime.tenant(authenticated_tenant_key)
plan = json.dumps({
    "nodes": [{"op": "find", "name": "Douglas Adams"}],
    "output": 0,
    "projection": {"kind": "unique_name"},
})
cancel = native.Cancellation()
reply_json = tenant.execute("conversation_1", "request_1", 0, plan, cancel)
```

`execute` returns JSON containing the next state version and query result. A
later plan may use `previous` to start from the last committed selection.
`tenant.query(plan, cancel)` evaluates without session changes or journaling;
`previous` is empty in that mode. `Image.query` supports pure data access without
opening a state database. Use `json.loads(reply, parse_float=Decimal)` if the
Python consumer needs to retain decimal precision.

An exact retry binds the image, session, expected version and exact plan bytes.
The same request ID with changed input raises `ConflictError`. Completed retries
read the journal without an execution slot, even after restart. Concurrent turns
use version checks: a stale computation cannot overwrite a newer state. Replies,
state versions and capacity counters commit in one SQLite transaction. Image
changes require an explicit session migration; the runtime refuses to guess.

The current evaluator is pure. It does not call Python, send messages, run tools
or mutate external files during evaluation. An uncommitted turn can therefore
be evaluated again after a crash. This guarantee does not extend to arbitrary
Python callbacks or external effects; those need the planned effect broker.

## Resource and isolation contract

Each Image owns a fixed pool of SQLite handles. A lease is exclusive to one
request, and a tenant can occupy at most one slot at a time. Busy work is refused
immediately with `BusyError`; there is no hidden queue or tenant thread. This is
bounded admission, not a promise of starvation-free scheduling. The host still
controls fairness, rates and entitlement. `image.active_workers` reports actual
occupied slots, including scratch cleanup.

`Cancellation.cancel()` is callable from another Python thread while native work
runs. Native loops and SQLite VM progress check cancellation, fuel and deadline.
No timeout abandons a running thread. Cleanup clears private scratch before
returning a connection; failure poisons the pool. The deadline is cooperative:
SQL preparation, OS I/O and a durable commit are not arbitrarily preemptible.
If cancellation arrives during a successful commit, the durable reply wins and
is available for replay. Hard CPU, memory, disk and process limits remain host
responsibilities, including containment for future opaque evaluators.

Pass operator bounds in `limits_json`. Defaults are in
[`Limits`](oracle-core/src/budget.rs): workers, input/output/state bytes, plan
nodes, materialized rows/bytes, work fuel, deadline, SQLite cache and mapping
sizes, persistent session count and journal capacity. Unknown fields fail.
Fuel counts native work units and SQLite VM instructions in batches; it is not
a billing unit. Materialization limits cover copied result and shared-subplan
payloads; SQL optimizer buffers and allocator overhead also consume memory.
The SQLite cache setting is not a hard process-memory ceiling.

The journal never evicts request IDs silently. Persistent storage is bounded by
configured entry counts and value sizes, with SQLite overhead and WAL added;
the host must provision a disk quota. Retention and migration require explicit
protocols before old IDs can be reused. A tenant handle scopes cooperative
callers; an in-process Python extension is not a sandbox for hostile Python.
Do not expose the host Runtime or image paths directly to end users.

## Release admission and effects

`Runtime.from_release(image, state_path, manifest_json, expected_identity,
runtime_artifact_sha256)` is the Python host constructor. The authenticated host
supplies its trusted expected identity and measurement of protected code bytes.
The factory checks the actual opened image, resource profile, required schemas
and fixed native operation registry. It refuses external resources and kernel
or effect claims. Those require their separate host admission paths. The
manifest format and Rust equivalent are in [the migration map](docs/MIGRATION.md).

`Runtime.from_image` remains useful for development; its identity covers data
only. It cannot reuse history created under a full release identity. Session
schema 2 explicitly distinguishes native selections from imported Oracle
conversation state. Upgrading a schema-1 selection does not invent that state.

Rust hosts use `execute_with_effects` / `execute_program_with_effects` and
`HostEffects` for already-authorized intents. Reply, state and intents commit
atomically; no external action runs within that transaction. The host claims
work, executes its capability outside the store lock, and settles with a fenced
receipt. An uncertain non-idempotent action is never automatically retried.
The outbox is not a teaching, filesystem or network executor.

`KernelExecutor` admits operator-supplied executable hashes once and supplies
cheap tenant handles to a fixed resident process pool. The current audited
protocols are acoustics and quantity modes. Cancellation owns the child process
group and joins its I/O threads before releasing capacity. This transport does
not replace the extracted SML implementations, dispatcher acceptance or proofs.

## Build and qualify

From this directory:

```sh
CARGO_BUILD_JOBS=2 cargo test --locked -p oracle-runtime-core --test runtime_contract
CARGO_BUILD_JOBS=2 cargo build --locked --release --workspace
maturin build --locked --release --compatibility linux
```

The extension uses the CPython 3.12+ stable ABI. The `linux` wheel command builds
for the current Linux toolchain; it does not establish manylinux portability or
qualification on Mini's runtime base. Build a pinned compatible wheel in the
appliance build environment before packaging it into an SPK. Keep corpora,
images, targets, wheels and state stores outside tracked source.

`tests/test_python_contract.py` checks the actual extension's scoped handles,
shared query graphs, parallel admission, cancellation, cleanup and process-kill
recovery. `tests/qualify.py` runs the pinned upstream KQA and native reader in
separate fresh processes, comparing relation qualifiers and concept selections
on the real knowledge base. It then creates 256 logical tenant sessions at fixed
worker capacity. Source data preparation is in another process; it cannot inflate
the native process's memory measurement. These are data-access comparisons, not
full Oracle or specialist-panel scores.

The earlier [retained Linux receipt](evidence/2026-10-28-linux.json) records its input and
extension hashes. On that run, all 288 comparisons matched. Native post-use PSS
was about 18 MiB versus 545 MiB for the reference KQA; startup was 0.17 versus
2.93 seconds, including image hashing on the native side. Median query time was
77 versus 9 microseconds; p95 was 0.12 versus 4.43 milliseconds. The simple
in-memory lookup remains cheaper in Python, while indexed concept traversal
and the memory footprint improve. These are observed fresh-process timings on
a warm filesystem cache, not guaranteed service latency or full-Engine numbers.

The earlier [installed-wheel validation](evidence/2026-10-28-validation.json) records
14 passing Rust contract tests, six passing Python binding/recovery checks,
Clippy with warnings denied, and the source and wheel digests.

The [0.2 serving validation](evidence/2026-10-28-serving-validation.json)
records 185 passing Rust checks (including one real resident-kernel protocol
check), 17 Python checks, and Clippy with warnings denied. It binds the exact
source and installed wheel; the retained image and corpora are outside Git.

The [233-program sample](evidence/2026-10-28-programs.json) exercises every
pinned KQA operation: 225 answers match gold, zero are wrong, and eight withhold
on unit/date ambiguity. The [40-question whole-reader sample](evidence/2026-10-28-reader.json)
answers 17 correctly, returns unknown for 23, and has zero wrong answers or
execution errors. Its median is 2.4 ms and p95 23.4 ms; post-query PSS is about
33.2 MiB. Adding 256 scoped handles adds 12 KiB PSS and no threads. This is a
small fresh-process sample on warm filesystem caches, not a throughput or
full-language-coverage claim. The other language readers remain explicit work.

The same 40 questions previously hit a span-combination bound 25 times. Indexed
template-prefix search removed those errors without raising the limit or hiding
alternatives; the [before receipt](evidence/2026-10-28-reader-before-prefix.json)
is retained alongside the final run.
