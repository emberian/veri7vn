# Shared native Oracle foundation

This is the Rust and PyO3 foundation for the next Oracle appliance. It builds a
release's knowledge base once, executes structured query plans over shared
indexes, and persists a conversation's selection and exact replies together.
A tenant handle holds an identity and a shared reference. It starts no process,
loads no corpus, and owns no database connection.

This first implementation covers relation and concept data access. It is not a
replacement for Oracle's full language interpreter, learned readers, specialists
or effectful tools, and is not installed in signed v7. The [migration
tracker](../project/lanes/NATIVE-FOUNDATION-2026-10-28.md) names the remaining work.
There are no new specialist-panel or theorem claims in this component.

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

Queries contain a validated acyclic graph of `find`, `all`, `previous`, `relate`,
`filter_concept`, `and` and `or`. Projections return entities, names, a unique
name, a count or typed attributes. The compiler turns the whole graph into
parameterized SQL. Single-use chains can remain inside the query planner;
shared subplans are explicitly materialized once in bounded worker scratch.
They must not expand into exponential copies during SQL preparation.

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

The [retained Linux receipt](evidence/2026-10-28-linux.json) records its input and
extension hashes. On that run, all 288 comparisons matched. Native post-use PSS
was about 18 MiB versus 545 MiB for the reference KQA; startup was 0.17 versus
2.93 seconds, including image hashing on the native side. Median query time was
77 versus 9 microseconds; p95 was 0.12 versus 4.43 milliseconds. The simple
in-memory lookup remains cheaper in Python, while indexed concept traversal
and the memory footprint improve. These are observed fresh-process timings on
a warm filesystem cache, not guaranteed service latency or full-Engine numbers.

The [installed-wheel validation](evidence/2026-10-28-validation.json) records
14 passing Rust contract tests, six passing Python binding/recovery checks,
Clippy with warnings denied, and the source and wheel digests.
