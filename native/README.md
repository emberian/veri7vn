# Native Oracle runtime and appliance

This directory contains a shared-data query runtime and optional computation
providers. The [capability catalog](docs/CAPABILITIES.md) lists exact operation
IDs, current limits and retained results.

The [Rust appliance host](docs/HOST.md) shares the native image and extracted
workers across tenants. Its optional Python Oracle7 Engine handles fallback.
It runs independently of Mini; supplied-model computations need no Oracle dataset.
The [durable runtime](docs/RUNTIME-HOST.md) serves an admitted data image, KQA
programs and learned language turns, with exact reply replay after restart.
The [distribution builder](docs/DISTRIBUTION.md) packages the service into a
relocatable directory; images, journals and private configuration stay external.
The earlier [Python HTTP service](docs/STANDALONE.md) remains a reference.

`oracle-core` builds a KQA-shaped JSON source into immutable indexed SQLite,
executes bounded query graphs and stores versioned session selections/replies.
It preserves typed values and qualifiers, checks dangling references and creates
reverse relation indexes. Source decimal digits are retained exactly. Building
parses the whole source offline; serving shares indexes rather than a Python
object graph per tenant. `oracle-python` exposes the core through PyO3 and
releases the interpreter while native work runs.

The reader uses offline-exported lexical and learned grammar tables bound to the
KB digest. It executes whole templates, exact fragment/outer composition,
2–4-segment chains and one nested fragment pass under one worker budget.
Consumed children must run and be nonempty; successful interpretations must
agree. Serving neither learns nor unpickles. The retained 100 questions have
36 correct answers, 4 refusals and 60 unknowns with no wrong answers/errors;
a separate 16-question expansion failed acceptance, including four byte-limit
errors. Details and evidence are in the catalog.

This does not replace the complete Oracle Engine or install it in signed v7.
The full route cascade, dialogue adapters, remaining language families and real
external effect executors remain. New hosted supplied-data workflow panels pass
16 calibration, nine thermal-scenario, 17 sequence-search and four exact-blend
cases, with no wrong answers or false acceptance. They are manufactured workflow
cases, not results on the shipped specialist exams. Their source and limitations
are linked from the [first Sol checkpoint](../project/lanes/NATIVE-SOL-WAVE-2026-10-31.md).
The [migration map](docs/MIGRATION.md) describes these gaps; the
[roadmap](docs/ROADMAP.md) names the next work. Handwritten Rust contracts do not
inherit Isabelle proofs. [Resident connected-MST checking](../src/extract/discrete-certificate/README.md)
has its own theorem scope and receipt admission.

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

`tenant.execute_language(session, request, expected_version, question, cancel)`
uses the same durable session and returns `version` plus `language`. An agreed
answer can replace the selection for a later graph `previous` query. Unknown,
ambiguous and semantic refusal replies commit their exact result while preserving
the prior selection; operational errors and cancellation before commit do not
advance the version. Retries bind the raw question bytes and language dialect,
and replay after restart without acquiring a worker. A measured release must
explicitly admit `reader.execute` version 1. This does not restore the upstream
Engine's full dialogue state or provide external effect execution.

The current evaluator is pure. It does not call Python, send messages, run tools
or mutate external files during evaluation. An uncommitted turn can therefore
be evaluated again after a crash. This guarantee does not extend to arbitrary
Python callbacks or external effects; those require an authorized host executor and its own recovery contract.

## Resource and isolation contract

`oracle-execution` supplies the native host and providers with shared cancellation,
an absolute deadline and work fuel. A child call can tighten its limits while
charging the enclosing request; it cannot replenish that request's allowance.
The core `Budget` API wraps the same context. Existing cancellation-only provider
callers remain supported, but gain no fuel limit merely by using that interface.

The reader converts admitted grammar programs directly into checked typed plans.
A request can reuse compiled plans and identical result/evidence payloads while
keeping every derivation's checks. Retained results carry shared memory
reservations through selection and durable encoding. This accounting covers
explicitly tracked native allocations; it does not bound process RSS, SQLite,
foreign allocations or all allocator overhead. Representation changes preserve
the language agreement rule. See the [measured comparison](docs/PERFORMANCE.md)
for what the foundation saves and what remains unmeasured.

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
the host must provision a disk quota. [Host namespace retirement](docs/RETENTION.md)
can reclaim retained payloads while permanent, bounded tombstones prevent a
retired namespace from reopening. A tenant handle scopes cooperative
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
protocols include acoustics, quantity and connected-MST checking. The MST path
can admit compiler/proof receipts as described in the checker contract.
Cancellation owns the child process
group and joins its I/O threads before releasing capacity. This transport does
not replace the extracted SML implementations, dispatcher acceptance or proofs.

## Build and evidence

Build on the project's designated host under its resource controls. The workspace
uses the checked-in Cargo lockfile. From this directory:

```sh
CARGO_BUILD_JOBS=2 cargo build --locked --release --workspace
maturin build --locked --release --compatibility linux
```

The extension targets CPython 3.12+ stable ABI. A local Linux wheel does not
establish manylinux portability or compatibility with Mini's base image. Keep
corpora, images, targets, wheels and state stores outside tracked source.

Use the focused checks for the changed surface, centrally coordinated on the
build host. [Runtime hosting](docs/RUNTIME-HOST.md), [distribution](docs/DISTRIBUTION.md)
and domain documents give reproduction commands and exact artifact receipts.
Historical [data-access measurements](evidence/2026-10-28-linux.json) compare
288 KQA queries, not the full Engine: all matched; native post-use PSS was about
18 MiB versus 545 MiB, while median lookup time was slower (77 versus 9 µs).
The [lexical reuse experiment](evidence/2026-10-29-native-performance-reader.json)
preserved results while lowering CPU/wall time on its bounded workload.
These results are separate checkpoints, not a combined score or service-latency
guarantee. Raw evidence and failed runs remain under `evidence/`.
