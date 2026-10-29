# Serve the durable native data runtime

The standalone appliance can serve the existing native data image, KQA programs
and bounded learned language reader. It uses one global process cap. Each worker
opens one read-only image and release-bound runtime and reuses them for many cheap
tenant handles. It does not construct a Python Oracle Engine for each tenant.
Two workers can open the same image and persistent SQLite journal; their SQLite
caches are bounded separately and the operating system can share image pages.

This is a private loopback boundary for an outer host. The existing
`X-Mini-Oracle-Tenant` header carries a host-assigned routing key. It does not
authenticate a user. The outer host must assign that key and keep untrusted local
clients away from this service. No authenticated public gateway or signed Mini
qualification is implied.

## Operator admission

The operator supplies the extension path and SHA-256, fixed data image path and
SHA-256, persistent state path, complete native release declaration and expected
release identity, core resource bounds and a per-file write limit. The actual
`Image` and `Runtime.from_release` constructors check the image, artifact,
resource profile, schemas and supported operations before the service advertises
them. Learned reader operations require real reader tables inside the image.
The extension digest measures its binary bytes; it does not attest Python or
all linked dependencies.

Add a `runtime` provider to the same operator configuration used by
[native_service.py](../../tools/appliance/native_service.py):

```json
{
  "id": "data",
  "extension": "/operator/oracle_native.so",
  "sha256": "ACTUAL_EXTENSION_SHA256",
  "profile": "runtime",
  "runtime": {
    "image": "/operator/data/image.sqlite",
    "image_sha256": "ACTUAL_IMAGE_SHA256",
    "state": "/operator/state/sessions.sqlite",
    "manifest": {"schema": "oracle-native-release-v1", "...": "COMPLETE_OPERATOR_RELEASE_DECLARATION"},
    "release_identity": "ACTUAL_RELEASE_IDENTITY",
    "core_limits": {"workers": 1, "request_bytes": 65536, "result_bytes": 262144, "timeout_ms": 5000, "sqlite_cache_kib": 2048},
    "state_file_bytes": 268435456
  }
}
```

The abbreviated manifest above is explanatory; supply a complete admitted native
release declaration, including actual code/image/profile hashes, schema versions
and implemented operation descriptors. For exact decimal or exponent constants
in schema metadata, supply `manifest_json` as an exact JSON string instead of the
`manifest` object. Objects containing Python floating-point values are rejected
with that instruction; the service never rounds trusted release metadata. The service never generates a trusted
release from tenant data. Core limits use the native defaults for omitted fields;
`workers` must be one because each pool child processes one request at a time.
The global `limits.workers` remains the cap across all profiles and tenants.
Startup requires `2 * result_bytes + 16384 <= limits.reply_bytes` so every admitted
core reply fits its escaped JSON string and bounded transport metadata. The
image's resource-profile hash must match these exact core limits.

Run the existing service entrypoint:

```sh
python3 tools/appliance/native_service.py --config /operator/native.json
```

Keep the state directory stable across restarts and worker retirement. The pool
never puts persistent state in its temporary extension snapshot directory and
never removes the journal during cleanup. Resource affinity includes state path,
image, release and core limits; workers cannot silently reuse another runtime
merely because its extension digest matches. Public discovery contains resource
identity hashes, with operator paths and configuration withheld.

Runtime workers allow journal writes up to the operator's `RLIMIT_FSIZE` per-file
bound. This is not a total journal/directory quota. Native limits also bound
session count, journal entries and bytes per retained state/reply. Retention,
backup and migration policies remain operator responsibilities. Optional
[host-only namespace retirement](RETENTION.md) can close and delete a completed
namespace's local history; those admin methods are absent from tenant discovery
and dispatch. Keep image,
state directory, release declaration and extension protected from concurrent
replacement by untrusted writers.

## Operations and exact retries

Discovery exposes only the following tenant operations implemented by the
admitted release. Host retention/admin declarations never become HTTP tenant
operations, even when the operator admits those private Runtime methods:

| Operation | Required arguments | Session effect |
| --- | --- | --- |
| `graph.query` | `plan_json` | Pure read |
| `graph.execute` | `plan_json`, `expected_version` | Commit selection and exact reply |
| `kqa.query` | `program_json` | Pure read |
| `kqa.execute` | `program_json`, `expected_version` | Commit selection and exact reply |
| `reader.whole` | `question` | Pure bounded language read |
| `reader.execute` | `question`, `expected_version` | Commit language reply and agreed selection |

Graph and KQA inputs are JSON **strings**. Their exact bytes participate in native
retry identity, including whitespace and key order. Language preserves exact
question bytes. IDs come from the normal outer invocation envelope; arguments
cannot select tenant, session, request, release, resources or code. Stable,
domain-separated hashes map outer conversation/request IDs into the core's
stricter identifier format without truncation.

For example, an initial stateful turn is:

```json
{
  "request_id": "turn-one",
  "conversation_id": "conversation-one",
  "operation_id": "reader.execute",
  "arguments": {"question": "Who is Alice?", "expected_version": 0}
}
```

A completed stateful response includes the committed `version`, bounded
`core_metadata` and authoritative exact `core_reply_json` string. Complete source
values, evidence and language replies live in that string. No decoded numeric
answer body is returned: native arbitrary-precision numbers remain exact JSON
tokens rather than becoming Python floats. The adapter reads numbers as inert
lexical tokens and extracts only bounded status/image/coverage metadata and the
checked integer version. A semantic refusal is reported as
`status: "withheld"` and still carries the committed version and complete native
reply. A refused language turn preserves the previous selection while advancing
the version; use that new version for the next turn. Pure queries neither change
selection nor retain exact-reply journals.

Retry a stateful turn with the same tenant, outer request/conversation IDs,
operation, input string and expected version. The core returns its exact stored
reply across process or service restart. The HTTP wrapper and process containment
metadata may differ; the exact byte guarantee applies to `core_reply_json`.
Changing any part of that retry identity conflicts. Reusing a session or replay
under a changed release/image also conflicts and needs explicit migration.

The trusted in-process pool API accepts per-call cancellation events. The
standalone HTTP service currently applies its shutdown cancellation event and
per-call wall deadlines; it has no individual HTTP cancellation endpoint.
Cancellation and wall deadlines terminate and reap the owned worker. A commit
may finish immediately before a response disappears. The host reports that
state may have changed; an exact retry retrieves the stored reply. It does not
claim that cancellation rolled back a completed commit. There are no external
effects, teaching, full upstream dialogue engine or unrestricted language claims.

## Qualification

The central validator owns builds and scoped tests. These contracts manufacture
a tiny two-entity KB and inert learned reader table, without upstream data or
Mini. They cover discovery, host IDs, structured and language turns, previous
selection, semantic refusal, cancellation, exact retry after a controlled lost
response, restart, tenant separation and multiple tenants sharing bounded workers.

```sh
ORACLE_NATIVE_TEST_EXTENSION=/operator/oracle_native.so \
  python3 -B -m unittest discover -s tests/appliance -p test_native_runtime.py
ORACLE_NATIVE_TEST_EXTENSION=/operator/oracle_native.so \
  python3 -B -m unittest discover -s tests/appliance -p test_native_runtime_service.py
```

No specialist-panel numbers or new theorem statements are claimed by this host
integration. Actual validation results belong in the lane report and checkpoint
receipt after these tests run against the admitted artifact.
