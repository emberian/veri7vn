# Hosted durable native runtime

Owner: Sol durable runtime host lane. Consumer: the standalone appliance service
and its relocated distribution, then an authenticated outer host. There are no
new specialist-panel scores or theorem statements. The Python boundary is
untrusted; the native runtime implements the bounded query, session and exact
reply journal contracts.

## Final qualified checkpoint

The [stable appliance validation](../../native/evidence/2026-10-29-stable-appliance-validation.json)
records the frozen index tree `1909f489dde610b76dacecae0aecb4a54c2bf2d2`, qualified
code commit `77731632484d0c7129362dca150eb5310cb70233`, and final extension SHA-256
`f875fc2e217cbe5b7b4de196d546b717a105b28e9767b49905570f1893ae2a37`.
Central built and tested that immutable snapshot on hbox. Its hosted tests passed
all 11 actual-extension contracts: six direct runtime contracts and five actual
process/service/HTTP contracts. These are stable-artifact results, separate from
the earlier expanded-reader working-tree tests.

The same Python closure had already passed 14 unit/fixture contracts, including
fresh subprocesses with both component-first and appliance-first import orders.
Earlier central checks also passed 20 existing process-pool contracts and the
six domain/eight package contracts. Those earlier counts do not stand in for the
final artifact run; its exact commands, selected results and log hashes are in
the linked receipt. No tests or builds were executed by this lane.

## Changed files and consumer

- `tools/appliance/native_runtime.py`: operator-fixed RuntimeProfile and the worker-resident Image/Runtime bridge.
- `tools/appliance/native_pool.py`, `native_worker.py`, `native_service.py`: resource-aware worker reuse, private host context, startup admission and HTTP registration.
- `tools/oracle_components/native_runtime_adapter.py`: six fixed operation declarations, bounded metadata and exact native reply transport.
- `tests/appliance/test_native_runtime.py`, `test_native_runtime_service.py`: manufactured data, admission/replay/authority contracts and actual HTTP/process journeys.
- `native/docs/RUNTIME-HOST.md`, `native/docs/STANDALONE.md`: operator launch, retry and qualification contracts.
- This report: ownership, contract and evidence.

The distribution lane updated its explicit Python closure to include the adapter
under its distinct basename. There is no conflicting component `native_runtime.py`
or compatibility stub. NativePool's flat native_runtime import selects the host
helper even when an embedding puts the component directory first. The qualified
adapter import is `oracle_components.native_runtime_adapter`. The regression
checks module and class identity through NativePool and NativeService in fresh
processes. This import repair required no Rust rebuild.

## Serving contract

The operator fixes the extension digest, image path and digest, persistent state
path, release declaration and expected identity, core limits and per-file write
limit. None comes from an invocation. Startup opens the actual `Image` and
`Runtime.from_release` before discovery advertises supported operations. Native
release admission owns canonical identity checks. Exact `manifest_json` text is
supported for arbitrary-precision release metadata; float-bearing manifest
objects are rejected with instructions to use that text form.

Each runtime worker retains one image/runtime and creates cheap tenant handles
as needed. One global process cap covers all profiles and tenants. Runtime
profile calls, including pure fixed-image reads, require worker affinity to the
full operator resource identity: state path, image, release and resource bounds.
The identity never hashes mutable journal contents. Supplied-argument providers
can reuse a runtime-bound child of the same artifact. Two workers may reopen the
same journal and read-only image; SQLite caches are bounded separately, and the
OS may share image pages. No Engine or dataset is constructed per tenant.

The six tenant operations are graph.query/execute, kqa.query/execute and
reader.whole/execute, subject to actual release admission. Graph/program input
is an exact JSON string, preserving the core's byte-level retry identity.
Language input is an exact question string. Stateful arguments require
expected_version explicitly. The outer envelope supplies request/conversation
IDs and host routing supplies tenant. Domain-separated hashes map outer IDs into
the core's stricter identifier space without truncation. Arguments cannot select
tenant, session, request, release, resources, modules or authority.

Private worker frames carry host context separately from operation arguments.
Operator configuration is copied into a private read-only pool snapshot file;
worker readiness verifies its resource identity. Public receipts expose hashes,
not operator paths or release configuration. Runtime result bounds must satisfy
`2 * result_bytes + 16384 <= reply_bytes` before spawning, so every admitted
native reply fits escaped JSON framing and bounded host metadata.

A stateful operation commits selection and reply atomically. A refused language
turn advances its version and preserves prior selection. The adapter retains
that committed version and complete semantic reply as authoritative exact
core_reply_json. It extracts only bounded image/coverage/status/reason metadata
and a checked version; arbitrary-precision native numbers never become decoded
binary-float answers. Tests include source values
0.123456789012345678901234567890 and 1e1000.

The same tenant, request, input bytes, expected version, session and release
replay the same core reply after worker death or host restart. Changed input or
release/data identity conflicts and requires explicit migration. Pure query IDs
remain correlation labels. HTTP wrapper and process metadata need not be
byte-identical. There are no external effects.

## What the actual tests establish

The 11 final-artifact hosted contracts exercise all six entrypoints on a
manufactured two-entity KB and inert learned reader table. They cover release
admission, exact decimal/large-exponent reply transport, versioned selection and
semantic refusal, changed-input/release conflicts, tenant separation, bounded
worker reuse, same-artifact/different-journal affinity, CLI discovery and restart.
They do not qualify a real user store, full Oracle KB or full upstream Engine
through HTTP.

The HTTP cancellation test first commits an initial graph turn. A test-only gate
then holds a second real HTTP invocation **before worker exchange**. Production
shutdown controls produce HTTP 503 cancelled with uncertain-state/exact-retry
metadata and reap the owned child. A fresh service/server retrieves the earlier
committed reply and selection. This does not establish interruption during
native evaluation or SQLite commit, or rollback of a completed commit.

A separate controlled response-loss injection lets a native turn commit
successfully, then drops its response at the parent transport boundary. Worker
retirement and exact retry retrieve that committed core reply. That test covers
successful commit followed by lost response, independently of the pre-exchange
shutdown cancellation case. No production caller-controlled fault flag exists.

## Boundaries

Trusted in-process NativePool callers can supply individual per-call Events.
The standalone HTTP service uses its shutdown Event and wall deadlines; there
is no individual remote cancellation endpoint. Cancellation/deadline failures
retire and reap owned workers, but a completed commit may race with response
loss. The host reports uncertainty and requires exact retry rather than claiming
rollback.

Worker retirement removes only pool-owned snapshots, never the operator's
persistent journal. Runtime children permit bounded per-file writes for that
journal; pure-only children retain zero-write RLIMIT_FSIZE. This is not a total
filesystem quota. Core state, session, journal-entry and retired-namespace bounds
also apply. [Host-only namespace retirement](../../native/docs/RETENTION.md) is a
separate explicit maintenance action. Its admitted admin operations never enter
tenant HTTP discovery or dispatch.

The existing loopback header is routing metadata, not authentication. This work
does not claim an authenticated public gateway, full dialogue/teaching/effect
execution, signed Mini qualification, unrestricted language coverage or binary
attestation of Python and dependencies. The wider routing/dialogue/effect/Mini
work remains outside this qualified hosted surface.
