# Serve the durable native data runtime

The [Rust appliance host](HOST.md) opens one admitted native image and durable
session store, shared by tenant handles. It serves graph/KQA plans, bounded
learned language reads, typed batches, source coverage and native state owners.
See [data and state](DATA-AND-STATE.md) for complete structured examples and the
boundaries of source completeness and conversation import.

The service binds loopback. An outer host supplies the
`X-Mini-Oracle-Tenant` routing key and must authenticate users and protect this
private boundary. A tenant cannot choose the image, state path, release, solver
or executable through operation arguments.

## Operator admission

Configure `native.image`, its `image_sha256`, a stable `native.state` path and
`native.core_limits` in the host configuration. An optional admitted release
binds the actual host artifact, image, resource profile, schemas and operations;
without it discovery declares development mode. Learned reader routes require
reader tables in the image. Evidence solving also requires the logic feature
and the operator's admitted solver. Discovery exposes only available admitted
operations.

Protect image and release files from replacement, retain the state directory
across restarts, and plan backup and retention. Native limits bound workers,
request/result/state bytes, retained sessions and journal entries. Shared request
reservations bound explicitly retained native data; SQLite cache/mmap settings
and foreign allocations remain separate. This is not a directory quota or an
RSS ceiling. [Namespace retirement](RETENTION.md) is host-only administration,
not a tenant operation.

## Operations

All operations use the normal `POST /invoke` envelope with `request_id`,
`conversation_id`, `operation_id` and `arguments`.

| Operation | Arguments | Durable session effect |
| --- | --- | --- |
| `graph.query` | `plan_json` string | None |
| `graph.batch` | Structured `batch` object | None; empty `Previous` context |
| `graph.coverage` | Structured `coverage` object | None; declared snapshot scan |
| `graph.execute` | `plan_json`, `expected_version` | Selection and exact reply |
| `kqa.query` | `program_json` string | None |
| `kqa.execute` | `program_json`, `expected_version` | Selection and exact reply |
| `reader.whole` | `question` | None |
| `reader.execute` | `question`, `expected_version` | Language reply and agreed selection |
| `context.execute` | Structured `command`, `expected_version` | Delivered scalar owner and exact reply |
| `logic.workspace` | Structured revision `command`, `expected_version` | Evidence owner and exact acknowledgement |
| `logic.workspace.solve` | Structured solve `command`, `expected_version` | None; solve a version-checked snapshot |

New batch, coverage and owner operations take JSON objects directly. Only the
legacy graph/KQA single-operation fields are JSON strings. Their exact string
bytes, including whitespace and key order, remain part of retry identity.
Language keeps exact question bytes. Outer IDs map to core identifiers through
stable, domain-separated hashes.

Replies carry authoritative `core_reply_json`; arbitrary-precision numeric tokens
remain in that exact string. The wrapper exposes bounded metadata and, for
stateful operations, the committed `version`. A semantic refusal can still
advance the version. Use the returned version for the next turn.

## Exact retry and cancellation

Native session updates and exact replies use the existing core transaction and
journal. Native `/invoke` calls do not add a second replay record to the host's
separate `/query` journal. Retry a stateful call with the same tenant, outer IDs,
operation, command and expected version. A matching completed call returns the
stored `core_reply_json` across restart; changed content conflicts. Pure reads
and solves retain no durable retry reply. Wrapper and containment metadata need
not be byte-identical.

All branches inherit the request's cancellation, deadline, fuel and retained-byte
ledger. A client timeout does not release live-work capacity before execution
actually stops. Cancellation may race a completed commit: an uncertainty reply
requires an exact retry, not a new request ID. It does not promise rollback.
The HTTP API has no individual cancellation endpoint.

Session schema 3 retains native owners independently of explicitly imported
Oracle state. Schema-2 migration preserves an unchanged binding; a changed
release/image requires explicit migration. Native scalar import does not restore
a whole Engine or enable tenant switching between live Python Engines.

## Python reference service

`tools/appliance/native_service.py` remains the earlier extension-backed host.
Its `runtime` provider configuration names the extension/hash, image/hash,
persistent state path, admitted manifest/release identity, core limits and
`state_file_bytes`. It runs one request at a time per pool child and retains the
persistent journal outside temporary extension snapshots. Its per-file
`RLIMIT_FSIZE` is not a total state-directory quota. Exact decimal metadata can
use `manifest_json` to avoid Python float conversion. The new Rust operation
catalog above does not imply that this older service exposes those new routes.

## Validation status

The [central expansion receipt](../evidence/2026-10-31-native-expansion-validation.json)
records 171 Rust and 142 Python checks, the real HTTP state/restart journey,
evidence-owner contracts and all new supplied-data workflow panels. A separate
256-request journey checks 64 tenants sharing one process. These bounded results
do not qualify full Engine recovery, a public gateway or the shipped specialist
fleet. The [performance report](PERFORMANCE.md) retains both gains and regressions.
