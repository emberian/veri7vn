# AP1: private Oracle computation adapter — 2026-10-26

Root integration: the bundled adapter now passes the five-query real-Engine candidate smoke, including retry/restart and unchanged runtime files. Earlier lane-only limits below are superseded by the [batch integration record](../APPLIANCE-2026-10-26.md) for those measured cases. Mini authority integration and deployment remain outstanding.

Implemented by the appliance-service lane. Root integrates and commits.

## Changed files and consumer

- `tools/appliance/serve.py`: private loopback HTTP service around the original
  pinned Oracle7 slim `Engine.chat`, with an external runtime and complete
  data-root view, and one host-assigned writable workspace.
- `tools/appliance/README.md`: invocation, transport contract, state and limits.
- `tests/appliance/test_service.py`: fake-engine contract/process tests.
- This lane report.

The consumer is the host's appliance launcher and, later, Mini's authorized
resident-application adapter. This code does not replace Mini's Lean authority.
It carries the complete successful Oracle reply without elevating upstream
`proved` or other labels into a broader claim.

## Behavior and design decisions

`GET /health`, `GET /capabilities`, and `POST /query` are available on loopback.
Both conversation and request IDs are mandatory. Scope is fixed at startup;
there is no default session or tenant header. One admitted query runs at a time;
concurrent work receives 429 instead of entering an unbounded queue. Connection
threads, request bytes, reply bytes, request-journal records, and engine elapsed
time have explicit bounds, configurable by the operator.

The per-workspace journal reserves exact request bytes before execution and
records the entire result. Identical retries replay; changed bytes return 409.
A restart turns unfinished records into explicit `interrupted` errors without
reexecuting them. This is not an atomic transaction with upstream state files.
A deliberate `withheld` response is completed work. Runtime faults, worker loss,
and deadlines are separate errors which acknowledge possible state changes.
Oversized replies explicitly fail; they do not silently lose evidence and
pretend to be successful. The oversized original is not retained. Lowering the
reply cap also cannot expose an oversized cached response.

The worker process preserves Engine's SQLite-owning thread. Graceful shutdown
waits for the admitted query's deadline, then stops/joins its owned worker with
a bounded grace period. The host must supervise upstream descendants and apply
memory, storage, and filesystem/network containment; this is not a sandbox.

Split code/data roots require a deliberate loader adjustment: upstream
`setup()` resolves PACK_MANIFEST under the code path regardless of
`ORACLE7_ROOT`, and auto-expands/deletes packed stores there. This adapter
replaces only that setup hook with presence/size preflight. It retains original
`load`, `Engine`, and `chat`. Deployment separately verifies hashes; capability
metadata explicitly says the adapter has not checked them. No Workbench CLI,
builder, or updater is invoked by the adapter. Source and data should be mounted
read-only. Workspace paths are explicit for Oracle state, Workbench-local state,
and specbuild, and relative upstream writes run from the workspace.

## Exact checks

Command:

```sh
.venv/bin/python -m unittest discover -s tests/appliance -v
```

Result: **17 tests passed**, 0 failures/errors, 1.243 seconds. These use fake
engines; two use a fake launcher in a real spawned worker to check normal
shutdown and timeout termination. They establish transport/process behavior,
not real Oracle accuracy. Cases cover full evidence preservation, deliberate
refusal, runtime failure, output limits, changed-byte replay, missing/unsafe
session IDs, duplicate JSON keys, non-finite values, interrupted requests,
restart replay, queue rejection, workspace lock, bounded journals, HTTP entry
points, browser-origin rejection, and split-root preflight. Real socket tests cover continuously dripping headers
and bodies, immediate shutdown of an accepted slow connection, and an admitted
backend query that outlives the ingress deadline and still returns normally.
Resolved path checks reject both nesting directions and overlapping symlinks.

Real-source smoke: invoked `serve.py --check-import` against
`var/universe-20261026/huggingface/oracle7-slim` with a temporary external
workspace. Git HEAD was exactly
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`. Result:

```json
{"launcher_imported":true,"engine_class_present":true,"engine_constructed":false,"stores_checked":false,"workbench_cli_imported":false}
```

No corpora downloaded. Full Engine construction and a real answer remain
unexercised because the inspected source snapshot lacks the packed store
payloads. The check does not claim otherwise.

Theorem statements: **none**. Specialist panel numbers: **none yet**. No
Isabelle/Lean or broad suites ran. No upstream files changed. No commit created
by this lane.

## Remaining integration

Root owns pinned deployment/source verification, store provisioning, and the
complete data-root view. Run one real Engine query after those stores are
available, inspect its evidence, then connect this private service through the
host's actual Mini application boundary. Configure appropriate operator storage
and compute bounds. Nothing in these transport tests demonstrates that every
upstream fold is safe, mathematically correct, or free from side effects.


## Review fixes

Terra identified that socket inactivity timeouts alone permitted indefinite
slow ingress and could block shutdown. Accepted sockets now have an absolute
5-second deadline spanning headers and body. Deadline expiration atomically
wins against request admission; completed ingress cancels its timer before the
backend call. Server shutdown closes only its tracked ingress sockets and then
drains admitted backend work under its separate query timeout. Tests use a
0.2-second ingress deadline with continuous 0.03-second drips, and a separate
10-second deadline to establish that shutdown closes a slow socket immediately.

Terra also identified reverse nesting: a workspace could contain the code/data
root. The adapter now rejects any resolved workspace/root overlap, including
both ancestry directions and symlink targets, before making state directories.

## Deployment identity follow-up

Capabilities now capture `runtime/APPLIANCE.json` once at service startup and
expose its exact SHA256, the base source revision, patch names/hashes, the kernel
overlay manifest SHA256, and compact kernel revision/count/platform metadata.
The file inventory is omitted. Receipts are read with a 4 MiB cap; the exported
summary has a 16 KiB cap. An absent receipt remains valid for a source-only run;
a malformed/present receipt fails before workspace creation or Engine startup.
The existing `source_revision` field remains the base revision for compatibility.

This hashes the receipt bytes only. Both capability flags and explanatory text
state that deployment contents and metadata have not been independently verified
by the adapter. The trusted host supplies that verification.

Final scoped command `.venv/bin/python -m unittest discover -s tests/appliance -q`:
**19 tests passed**, 0 failures/errors, 1.255 seconds. Added patched-identity,
read-once, no-inventory/no-false-verification, missing-receipt, malformed-receipt,
and oversized-receipt cases. Also read the actual materialized patched receipt:
the summary correctly distinguishes its correctness patch and Earth overlay
from the base source revision. Root owns the corresponding full Engine smoke
and final artifact materialization; this lane did not repeat those queries.
