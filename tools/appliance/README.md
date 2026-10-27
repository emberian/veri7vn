# Oracle computation service

This untrusted Python adapter serves the pinned Oracle7 slim revision
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`. It calls the release's `Engine.chat`
and preserves every field of a successful reply, including unfamiliar evidence.
An Oracle label such as `proved` remains an upstream claim. This service does
not implement Mini admission, resource authority, or proof checking.

The trusted host starts **one process per workspace**. It chooses and protects
that directory and maps its own authorized caller to this process. The service
binds only `127.0.0.1`; it has no tenant selector, passwords, or public ingress.
Loopback does not isolate mutually untrusted local users: use a private network
namespace/container when required. Browser origins and foreign Host headers
are rejected. The host must provide the runtime's CPU/memory/filesystem/network
containment; this adapter is not a Python sandbox.

## Start

Provision and hash-check the release and stores with `deploy/appliance/` first.
The runtime directory contains `oracle7.py` and `PACK_MANIFEST.json`. The data
root is the **complete Oracle7 root view**, including `wander-train`, admitted
source modules, small data, and materialized store mounts. It is not merely a
directory of SQLite files. Mount runtime and data read-only. The resolved workspace path must neither
contain nor sit inside either root; equal paths and overlapping symlink targets
are rejected.

```sh
python tools/appliance/serve.py \
  --runtime /opt/oracle7 \
  --data-root /srv/oracle7/root \
  --workspace /var/lib/oracle-workspaces/workspace-17 \
  --port 7070
```

The host may set `--max-request-bytes` (default 16 KiB), `--max-reply-bytes`
(default 2 MiB), `--max-requests` (default 10,000), `--query-timeout` and
`--startup-timeout` (both default 120 seconds), and `--shutdown-timeout`
(default 5 seconds). These are operator configuration, not hard-coded Mini
user policy. Defaults bound a single request/reply and journal record count;
size retained storage according to the product of those bounds. Oracle's own
conversation state and logs additionally need host storage quotas.

`--source-revision` accepts only the pinned revision. It records the expected
release; it does not independently attest all source bytes. The adapter checks
store existence and declared sizes. Deployment verifies their hashes. The
launcher normally auto-unpacks stores under its code directory, ignoring
`ORACLE7_ROOT`; the adapter deliberately replaces only `setup()` with this
non-mutating preflight before constructing the original `Engine`.

The worker sets `ORACLE7_ROOT` to the data root, and puts `ORACLE7_STATE`,
`ORACLE7_WORKBENCH_LOCAL`, and `SPECBUILD_HOME` in separate subdirectories of the
workspace. Its working directory is that workspace; bytecode writes are off.
The launcher is imported without calling `main()` or importing Workbench CLI.
This query profile neither invokes a builder nor adds an update endpoint.

## Calls

- `GET /health`: readiness and whether a query is running.
- `GET /capabilities`: protocol, upstream tip, bounds, and evidence limitations.
  `source_revision` remains the base upstream revision. When `APPLIANCE.json`
  exists in the runtime directory, `deployment` also reports its SHA256, base
  revision, patch names/hashes, and a compact kernel overlay manifest identity.
  This snapshot is captured once at startup; the full file inventory is omitted.
  Only the receipt bytes are hashed here: the metadata remains unverified unless
  the host independently verifies deployment contents. Missing receipts are
  allowed for source-only runs; malformed receipts or receipts over 4 MiB fail
  startup. The compact identity itself is limited to 16 KiB.
- `POST /query`: `Content-Type: application/json`, with exactly these fields:

```json
{"request_id":"turn-0001","conversation_id":"conversation-7","text":"Who wrote Leaves of Grass?"}
```

IDs contain 1–80 ASCII letters, digits, `_`, or `-`. Both are mandatory. There
is no shared default conversation. The host assigns IDs within its workspace;
the service never interprets an arbitrary header as tenant authority.

HTTP 200 has `{"outcome":"completed","reply":{...}}`, where `reply` is the
complete Oracle result. A deliberate `reply.status="withheld"` is completed
work, distinct from transport/runtime failure. No answer status is converted
into a stronger assurance claim.

There is one engine child process, retaining its normal single SQLite-owning
thread. Queries are admitted immediately or return 429 `busy`; there is no
hidden query queue. At most 16 HTTP connections are handled at once, each with
a 5-second absolute deadline covering all request headers and the complete body;
excess connections close without executing work. Finishing ingress cancels that
deadline before starting the backend query, which has its separate query timeout.
Health remains accessible while the engine computes.

The request journal records the exact input bytes before running a turn, then
stores the complete returned envelope. Retry the **same bytes and request ID**
after disconnects. A changed body under the same ID returns 409, even if the
JSON is semantically equivalent. Completed requests replay without executing;
a concurrent retry gets 429 until the first call finishes. The journal survives
restarts. It never evicts IDs or silently permits their reuse: a full journal
returns 507, and the operator must provision a fresh workspace or explicitly
manage retention with knowledge of callers. Do not remove the journal while
keeping callers' retry expectations.

A crash between execution and recording the result leaves `interrupted` on
restart. Runtime exceptions, timeouts, and lost workers are errors, with
`state_may_have_changed=true`; they are never retried automatically. Inspect
or abandon the affected conversation before issuing a new turn. A timed-out
worker is stopped and the process stays unhealthy until restarted. The journal
is not an exactly-once transaction with Oracle's conversation files.

An oversized reply returns `reply_too_large` with `execution_completed=true`.
It does **not** return a truncated answer or partial evidence, and does not retain
the oversized original. Raise the operator limit before executing a new turn
if such evidence is needed; replaying that ID replays its recorded error.
Lowering the reply limit after recording a larger result also produces this
explicit error, while retaining that original in the journal. Successful
replies always retain all fields.

SIGTERM/SIGINT close owned sockets still receiving request headers/bodies, stop
accepting new turns, and let an admitted turn finish under
its deadline. Shutdown joins the engine thread, then terminates only its owned
worker if the grace period expires. Worst-case drain includes the remaining
query deadline and worker shutdown grace. The host must supervise the whole
container/process tree, including any descendants launched by upstream.

## Discover and call operations

Agents can list `GET /operations?offset=0&limit=10&q=chemistry` and inspect
`GET /operations/specialist.chemistry-v3.molar_mass`. Optional `availability`
filters are `live_direct`, `text_only`, or `unavailable`. Limits are 1–50 entries,
nonnegative offset at most 999999999, and a search string at most 256 UTF-8 bytes.
A page may contain fewer entries to keep its complete JSON below 32 KiB; follow
`next_offset` until null. Descriptors are never silently stripped to fit. The
configured reply limit may be tighter, in which case discovery explicitly fails.

Descriptors give the actual input/output schemas, units, source declarations,
examples, implementation entrypoint, availability and limits. A successful load
establishes that a callable is present, not that all its answers are correct.
Discovery starts from standing lists referenced by modules in the running
Engine's class chain and loads those organs using Oracle's own isolation layer.
It does not make every specialist directory or historical manifest live. Missing
or failed implementations remain unavailable. Development-panel examples are
labeled examples, not fresh validation results.

`POST /invoke` uses the same content type, admission lock, worker deadline,
workspace, and durable journal as `/query`:

```json
{"request_id":"mass-0001","conversation_id":"analysis-7","operation_id":"specialist.chemistry-v3.molar_mass","arguments":{"formula":"H2O"}}
```

Operation IDs use 1–160 ASCII letters/digits/dots/underscores/hyphens, starting
with a letter or digit. Request and conversation IDs retain their original
1–80-character grammar. Journal identity includes HTTP method, route, and exact
body bytes; reusing an ID across `/query` and `/invoke` returns 409. Legacy
journals migrate existing entries as `POST /query` without replaying execution.
Unknown operations return 404; declared but unavailable/text-only operations
return 409; invalid arguments return 400. Successful work and deliberate
refusals both use the completed envelope, with refusal visible in `reply`.

All direct computations run on Engine's dedicated SQLite-owning thread.
`specialist.<id>.answer` calls the existing organ's native `answer(text, session)`
under its own module isolation and acceptance rules. Its schema honestly asks
for text; it does not claim to be a structured formula API. The outer reply says
whether the manifest accepted it and retains every raw result field under
`result`. No head routing, arbitration, or global refusal guard is implied by a
direct call. Core math/relation calls similarly reach their existing organs.
Symbolic math values use tagged SymPy expression/constructor records and tagged
mapping entries when keys are symbols; finite values are not rounded away, and
non-finite numeric outputs fail explicitly.

A small additional set of structured numerical operations calls existing
functions directly: the registered weather implementation's temperature
conversions and heat-index function, and a registered chemistry organ's molar
mass method. No formulas are copied here and no numeric arguments are filled
into a hidden chat template. Learned network templates remain `text_only`.

Optional Workbench, decision, visual, and builder providers are loaded only from
fixed package modules. They accept bounded supplied data or use operator-pinned
component sources. Missing optional providers do not disable unrelated routes.
They cannot accept arbitrary host paths, URLs, imports, code, live sensor polls,
or installation requests through this interface. Separate host file, network,
device and arbitrary execution powers remain explicitly unavailable. Providers'
input checks do not replace Mini's authority checks.

The signed Mini profile may select `--max-request-bytes 65536`; standalone's
backward-compatible default is 16384. Capabilities, discovery pages and operation
descriptors report the configured whole-envelope limit. A provider schema's
larger text/array ceiling never overrides that transport limit. Request IDs,
conversation IDs, arguments and JSON escaping all count toward it. Model-facing
MCP and result-display limits can be tighter still.

## Narrow checks

```sh
.venv/bin/python -m unittest discover -s tests/appliance -v
python tools/appliance/serve.py --runtime /path/to/source \
  --data-root /path/to/source/root --workspace /tmp/import-only --check-import
```

The contract tests use fake engines, including a fake launcher in a real worker
process. They establish transport/state/process behavior, not answer quality.
`--check-import` imports the real release launcher without constructing the
engine or checking/loading stores. It is explicitly an import smoke, not a
successful real query or specialist panel result.
