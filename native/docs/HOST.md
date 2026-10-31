# The native appliance host

`oracle-host` serves Oracle queries and named computations through a private
HTTP boundary. It runs independently of Mini, opens the shared native data image once, keeps the
extracted proof-backed organs resident, and runs the original Python Oracle7
Engine as a contained child process for everything the native side does not
read. Every question goes through one written rule: the routes that take a
question must agree, or the host refuses. It never picks between answers.

The earlier appliance ran the Python Engine with native pieces inside it.
The Rust host reverses that ownership, as [the shared runtime design](../../docs/design/shared-oracle-runtime.md)
and [the 29 October direction](../../project/DIRECTION-2026-10-29.md) ask: the
native runtime hosts, and the Engine is one contained worker.

## What it serves

The routes, headers and basic reply envelopes follow the Python reference services
(`tools/appliance/serve.py` and `native_service.py`), which stay untouched.

| Route | What it does |
| --- | --- |
| `GET /health` | Readiness, the global capacity in use, Engine worker state. No tenant header needed. |
| `GET /capabilities` | Which routes answer questions, which operations exist, the admitted artifact digests. |
| `GET /operations`, `GET /operations/{id}` | Operation discovery, same paging and parameter rules as the reference. |
| `POST /invoke` | `{request_id, conversation_id, operation_id, arguments}`: one named operation. |
| `POST /query` | `{request_id, conversation_id, text}`: the front door. One question, every route, one decision. |

Every request except `/health` must carry exactly one `X-Mini-Oracle-Tenant`
header holding 64 lowercase hex characters. It is a routing key that the
outer host assigns. **It is not authentication.** Requests with an `Origin`
or `Sec-Fetch-Site` header are refused (403), as is any `Host` header other
than the loopback address. The host binds 127.0.0.1 only.

`/invoke` serves the operations admitted by the configured runtime and compiled
providers. Use discovery for the running service's exact list and the
[capability catalog](CAPABILITIES.md) for their meanings:

| Provider | Operations | Where they run |
| --- | --- | --- |
| native runtime | Learned reads, graph/KQA queries and batches, source coverage, scalar context and revisable evidence | In the host, over the admitted image and durable session store; evidence solving additionally needs the logic feature and admitted solver |
| pure computations | Graph and symbolic reasoning, scientific models, statistics, sequence operations, incremental dependencies and logic | In the host, linked from the provider crates under the corresponding cargo features |

The pure operations' descriptions come from the reference Python adapters
themselves: `native/oracle-host/tools/snapshot_descriptors.py` feeds the
compiled catalogs to those adapters and writes `descriptors/pure.json`, which
the host embeds. The host refuses to start if a compiled catalog no longer
matches the snapshot. Typed native replies retain the adapters' domain and
evidence checks. The original 29 October differential qualification covered
65 invocations and the then-available 15 pure operations; it is not a current
operation count or validation of later additions (see Qualification).

## The rule for questions

Routes are grouped by depth, the shallowest first:

| Group | Routes | Why here |
| --- | --- | --- |
| 0 | the native learned reader (`native:reader`) and every admitted organ (`organ:<id>`) | Native code over the admitted image, and proof-backed extracted kernels |
| 1 | the Engine (`engine`) | The whole Python Oracle7, for everything group 0 does not read |

In plain words:

1. Every group 0 route sees the question. An organ "takes" a question only when
   its specialist's own acceptance rule accepts the reply: its kind is one the
   manifest lists, or it is an in-domain decline and the question matches the
   manifest's context pattern (`tools/runtime_contract.py acceptance`, the same
   rule `exam.py` applies). The reader takes a question when it finds a reading.
2. If any group 0 route took the question, group 0 decides and the Engine is
   not asked. The decision uses `oracle_runtime_core::admission::arbitrate`:
   - all answers agree: the host answers, showing the first route's reply;
   - two answers differ: the host refuses (`path: host:disagreement`);
   - any route refused (for example the reader found readings that disagree,
     or an organ declined in its domain): the host refuses with that reply;
   - a route that must take part failed (deadline, crash, busy): the host
     refuses (`path: host:unavailable`).
3. Only when no group 0 route took the question does the Engine answer. Its
   answer or refusal is the reply.

Agreement means: two text answers are the same after trimming and lowercasing;
two numbers agree within 0.5 percent only when both carry the same explicit
unit field; anything else differs. This is the fusion planner's rule (the first
depth at which anything finishes decides, and every finished answer there must
agree within 0.5 percent or there is no answer), applied to routes instead of
plans. No route is ranked above another. Every route is "required": a failed
route blocks an answer rather than being ignored.

The written `RouteSpec`, per group: one entry per route in the order above,
`Participation::Required`, `AgreementMode::Relative { tolerance: 0.005, floor: 0 }`.

Every reply carries `provenance.host`: the decision, the deciding group, the
routes that decided, and every route's outcome, status, path, agreement key
and its own provenance, so a reader can see who answered and who declined.

## Containment

| Property | How |
| --- | --- |
| Hash admission | Every artifact is an absolute path with its SHA-256. The image is hashed whole on open; organ binaries are copied and re-hashed by `KernelExecutor`; the clingo solver is copied to a private directory and re-hashed; the Engine's Python and answerer are hashed; the Engine materialization receipt binds the actual patched file inventory (Git-only admission is development mode). A mismatch stops startup. |
| Release binding | The native runtime opens through `Runtime::open_release` with a release declaration that binds this host binary's own digest, the image and the core resource profile. `oracle-host manifest` prints that declaration for the operator to review. Without one, the runtime runs in development mode and says so in `/capabilities`. |
| Bounded admission | `limits.capacity` requests may do work at once, across all routes and tenants. Optional `limits.tenant_capacity` also caps one tenant; omitted, it equals the global cap. Saturation returns immediate `429` (`busy` on `/query`, `pool_busy` on `/invoke`). There is no queue or starvation-free scheduling promise. A timed-out request keeps its slot until its work stops. Idle tenants occupy no admission records. |
| Bounded ingress | At most `limits.connections` open connections (more are closed at once), and one absolute deadline (`ingress_ms`) for headers plus body, as the reference server. |
| Engine kill-and-reap | Each Engine worker runs in its own process group with a cleared environment, `PYTHONDONTWRITEBYTECODE=1`, a private `--state` directory and a PID file. A turn that misses `turn_ms` kills that process group by the recorded PID and reaps it; a replacement starts lazily for subsequent admitted work. Shutdown closes its input, waits, then kills and reaps the group. |
| Exact retry | `/query` results are journalled by (tenant, request_id). The same bytes replay the stored reply, across restarts; different bytes under the same id get `409 request_id_conflict`. A turn refused before work (busy) leaves no record. |
| Conversations | A conversation that reached the Engine is pinned to that worker generation. If the worker was replaced or the host restarted, the next turn gets `409 conversation_reset_required`, as the Python tenant pool does, instead of silently losing context. |

## Native calls and execution limits

Linked providers receive domain inputs directly. Their string interfaces remain
for external callers and use the same kernels. The host still checks request and
reply byte sizes, output schemas and certificates. Malformed-input diagnostics
may reconstruct the old parser location; valid calls do not encode and reparse
provider messages.

Floating-point inputs use the same correctly rounded decimal conversion through
the typed and wire interfaces. This deliberately corrects older wire decoding
that could choose an adjacent binary float for difficult decimal values. Exact
source decimals and integer representations remain distinct from these numerical
solver inputs.

Each request has one execution context. `invoke_ms` bounds an invocation;
`query_ms` bounds the complete query cascade, including Engine startup and I/O.
`execution_fuel` is shared across native branches and their checks. Components
retain tighter local limits while charging that shared allowance. Fuel counts
explicit work units and conservative estimates, not elapsed CPU time or billing.

Cancellation is cooperative in native libraries. Dense decomposition, alignment,
and other bounded library calls cannot be interrupted at arbitrary instructions.
They retain their admission slot until they return. Engine work runs in owned
processes that are retired and reaped on deadline; cancellation does not transfer
a live worker to another tenant. A completed durable commit remains replayable
even if its deadline passes while committing.

## Recovery and tenant ownership

The host journal has one exclusive owner, held through a persistent sibling
`.owner` file. Canonical parent paths share that lock; database symlink and
hardlink aliases are refused. The sidecar is never removed during normal use.
A request moves from admission to
opaque dispatch to a retained result; dispatch and conversation reservation are
stored before sending a question to Python. An uncertain outcome poisons that
conversation. A successful reply commit clears the poison. Completed exact
retries do not consume an execution slot, including after restart or saturation.
A new request against lost Engine context requires a fresh conversation ID.

Journals bind the host binary, admitted data and worker artifacts, routing rules
and resource settings. Paths and listening port are locators and can change on
relocation. Changing a deployment with retained history is refused; this release
does not silently migrate that history. An empty journal can accept corrected
configuration after a failed first startup. Nonempty older journals without an
identity are preserved and require an explicit migration.

An Engine process belongs to one tenant for its entire generation. Another tenant
can use an idle slot only after its old process group is retired; old state files
are retained. Worker count is bounded independently of registered tenants. Each
active production worker has a small guardian process watching a host-owned
socket. Host death closes that socket; the guardian kills its own worker process
group, even when Engine native code holds Python's interpreter lock.
This is interim isolation for legacy code: switching tenants can still reconstruct an
Engine, and worker eviction does not restore its conversational state. Native
operations continue to share the indexed image and bounded worker resources.

Native front-door reads are currently pure reads. They do not import or update
Engine dialogue context. Full context transfer between providers remains work;
validating an Engine generation does not establish that transfer.

For a materialized Engine, configure `engine.materialization` with the absolute
`APPLIANCE.json` path and its admitted digest. Startup checks every declared file,
its size and executable flag, rejects unlisted files, and checks source revision.
Only declared store files may be symlinked. Keep the admitted tree and its side
mounts under protected, read-only custody throughout serving. Git-only admission
remains a development mode and does not verify working-tree contents.

## Relocatable host package

Build the Rust binary for the receiving OS, then create a directory distribution:

```sh
python3 tools/appliance/package_host.py --host /absolute/oracle-host \
  --sha256 HOST_SHA256 --config /absolute/host.json --output /absolute/new-package
python3 -I -B -S /absolute/new-package/bin/oracle-host \
  --state-root /absolute/private-state --verify
python3 -I -B -S /absolute/new-package/bin/oracle-host \
  --state-root /absolute/private-state
```

The payload contains the host, worker, configured organs and optional solver.
Images, Engine materialization and interpreter remain external; state is always
outside the payload. Verification checks named bytes, not the complete Python
installation or operating-system libraries. The Rust host performs the full
Engine file-inventory admission at startup. The package is independently usable
without Mini; Mini remains responsible for authenticating callers and signing
its installed payload and shared resources.

## Configuration

`oracle-host --config /operator/host.json`. Unknown fields fail startup.

```json
{
  "schema": "oracle-host-v1",
  "port": 0,
  "journal": "/operator/state/host-journal.sqlite3",
  "limits": {"capacity": 2, "tenant_capacity": 1, "connections": 16,
             "request_bytes": 1048576, "reply_bytes": 2097152,
             "ingress_ms": 5000, "invoke_ms": 30000, "query_ms": 120000,
             "execution_fuel": 10000000, "retained_requests": 100000, "conversations": 100000},
  "native": {
    "image": "/operator/data/reader-image-v3.sqlite",
    "image_sha256": "8fcb1db9a08e234179f66ea9e032d2633b38cdcb902f4c95d1ba2c2d49c842f4",
    "state": "/operator/state/sessions.sqlite",
    "core_limits": {"workers": 2, "timeout_ms": 60000},
    "release": {"manifest_json": "OUTPUT OF oracle-host manifest", "identity": "ITS IDENTITY"},
    "reader_route": true
  },
  "pure": {"profiles": ["reasoning", "science", "incremental", "bio", "statistics", "logic"],
           "solver": {"path": "/operator/bin/clingo", "sha256": "ACTUAL_SHA256"}},
  "kernels": {"organs": [{"id": "acoustics", "executable": "/operator/kernels/acoustics", "sha256": "ACTUAL_SHA256",
                          "family": "acoustics", "accept": {"kinds": ["..."], "declines_in_domain": ["..."], "context_regex": "..."}}]},
  "engine": {"python": {"path": "/operator/venv/bin/python", "sha256": "ACTUAL_SHA256"},
             "answerer": {"path": "/operator/engine_worker.py", "sha256": "ACTUAL_SHA256"},
             "checkout": "/operator/oracle7", "revision": "FULL_GIT_COMMIT",
             "materialization": {"path": "/operator/oracle7/APPLIANCE.json", "sha256": "ACTUAL_RECEIPT_SHA256"},
             "state": "/operator/state/engine", "workers": 1,
             "startup_ms": 600000, "turn_ms": 300000}
}
```

`native/oracle-host/tools/make_config.py` writes such a file from measured
artifacts (it hashes them, asks the binary for its release declaration and
reads each organ's acceptance with `tools/runtime_contract.py`). Optional Engine
fields `specialist`, `compose` and `tip` pass the answerer's own flags.

The Engine checkout and revision have no default. The 29 October qualification used the
existing `upstream/` checkout: git commit `c5d6a29d5bc5e2525078e5a53afa1abf659e4d69`,
whose `BUILD_REPORT.json` and `RELEASE_HASHES.json` name head
`oracle_release_runtime_w540`, release merkle root
`04daf3ae439e55b7fea5f73e944b52d75f2535536bcf6a077a23d7a28802476f`. That is not
the 10.1 tip (`c473d28914e480425adb29b4f7f42485b8cfb4e3`). A 10.1
materialization additionally uses its pinned `engine.materialization` receipt;
`/capabilities` reports the checkout's receipt digests and head, so a reader
can see which Engine answered.

The production worker is `tools/appliance/engine_worker.py`. It accepts explicit
checkout and private state paths, uses an explicit readiness record, and keeps
the optional specialist composition used by the parity comparisons. Constructor
completion does not establish that upstream background organs have finished
loading; readiness reports that distinction.

## Build and run

```sh
cd native
cargo build --release -p oracle-host --features reasoning,science,incremental,bio,statistics,logic
target/release/oracle-host manifest --image-sha256 IMAGE_SHA256 --core-limits '{"workers":2,"timeout_ms":60000}'
python3 -B oracle-host/tools/make_config.py --host target/release/oracle-host --out host.json ...
target/release/oracle-host --config "$PWD/host.json"
```

It prints one line, `{"listening": "http://127.0.0.1:PORT", ...}`, once the
image is open, the organs admitted and provider admission has completed. Legacy Engine workers start lazily on
their first admitted question; the health report distinguishes that state. SIGTERM or SIGINT stops it: new connections stop, in-flight turns
finish and journal, then the Engine children are reaped.

Deploy shape: the host binary; the data image (260 MB for the KQA reader
image); a state directory for the session store and journal; the organ
binaries; the clingo binary if `logic` is served; and an Engine checkout with
its stores, a Python with its requirements, and the self-contained
`tools/appliance/engine_worker.py`. No PyO3 extension and no Python adapter
code is needed by the host itself.

## Qualification

The [31 October receipt](../evidence/2026-10-31-host-validation.json) records
focused recovery, ownership, packaging and actual-provider checks. A relocated
Linux package completed 20 logic calls across two launches. On macOS, the real
native reader, extracted acoustics and U8 Engine answered through their expected
routes; separate tenants used separate Engine generations; exact replay survived
restart; a new turn against lost Engine context required reset. These are bounded
integration probes, not new specialist-panel scores or serving benchmarks.

The [Mini staging receipt](../evidence/2026-10-31-mini-rust-stage.json) records a
signed Linux candidate under the existing application identity, independently
verified against its full staged inventory. Its adapter and operator-profile
packer are integrated on Mini main. Mini receiving qualification remains open.

See `native/evidence/2026-10-29-host.json` and
`project/lanes/I2-HOST-2026-10-29.md` for every count, command and
disagreement. Those runs used macOS under heavy load (counts only; timings are
noise):

- 116 reader questions, scored by the S3 control's own rules: the host answers
  everything the native reader answers (36 of 100, and 2 of 16), refuses where
  the reader refuses, and found no disagreement between routes. Where no group
  0 route reads a question the Engine answers; on 3 of the 100 it gave prose
  that does not match gold, exactly as the Engine does alone.
- Shipped specialist panels through the parity harness, scored by each
  specialist's own scorer (right / false yes / wrong):

  | Panel | Host | Board row to compare |
  | --- | --- | --- |
  | acoustics held-out (69), extracted binary as organ, Engine head w540 | 68 / 1 / 0 | veri7vn organ in front of w540: 68 / 1 / 0 |
  | acoustics dev (70) | 70 / 0 / 0 | veri7vn organ in front of w540: 70 / 0 / 0 |
  | networking held-out (71), Python specialist in front of head w503 inside the Engine worker | 67 / 1 / 0 | shipped composition: 67 / 1 / 0 |
  | networking dev (74) | 74 / 0 / 0 | no board row |

  The two false yeses are the Engine's (an optics answer to a supersonic
  Doppler question; a converse reply to an impossible subnet question); the
  board rows carry the same ones. The native reader read none of the 284 panel
  questions.
- The shared contract journey (`tests/journey.rs`, 3 tests) and a differential
  check of `/invoke` against the Python service (65 of 65 replies, 15 of 15
  descriptors identical).

## What it does not do yet

- No Mini signing or qualification, and no authentication: the tenant header
  is routing only, and the outer host must keep untrusted local processes away
  from the loopback port. No public gateway.
- No effect executors (teaching, growth, files, network). The core's effect
  outbox is not exposed.
- The Engine is shared by every tenant that reaches it, separated only by a
  per-(tenant, conversation) session name. Its own learned and global state is
  shared, as in the reference single-workspace service; per-tenant Engine
  processes (the Python tenant pool) are not ported.
- Conversations do not cross providers: a turn the reader answered is not part
  of the Engine's conversation memory, and the `/query` reader route reads
  each question alone (`reader.whole`, not `reader.execute`).
- Pure computations run inside the host process. They are bounded by their own
  native limits and a cooperative cancel flag, not by a killable process or a
  memory limit as in the Python pool. macOS has no memory limit for any child.
- Organ answers are compared as text: the current organ replies carry a value
  but no unit field, so the 0.5 percent numeric rule is used only when a
  producer states a unit.
- The checkout revision is the git HEAD; uncommitted changes in that checkout
  are not hashed.
