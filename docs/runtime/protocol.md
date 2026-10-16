# Resident native service protocol

## Entry points and current scope

`RuntimeService.open` owns one `WorkspaceStore`, one prebuilt
`Veri7vn_Runtime_Service` process, and its coordinator/client. It initializes a new
journal or completes startup-exclusive recovery before starting the event pump.
Ordinary requests neither build a session nor load mutable theory/ML source.
`ResidentSupervisor` launches the immutable heap copies pinned by
`DeploymentImages` and the installed boot manifest.

`RuntimeMain --workspace PATH --images PATH [--session-root PATH ...]` reads one
original-byte mathematics question per input line, bounded to 256 bytes. It emits
native licensed HTML or a finite status. The source also supports
`--workbench COMMAND ...` over the same managed source store and native client.
Broader source/domain/search/build operations remain separate integration work;
the mathematics consumer does not establish full platform coverage.

The finite client implements proposal, result polling, routing/request inspection,
cancel, and Forget. Routing retains exact original bytes for bounded one-use
selection handles. Inspection is metadata, never a theorem or execution permit.
Native inspection and expanded workbench consumers await their composed native
checks. The actual resident baseline already covers concurrent math publication,
nonempty recovery, and selective Forget; see evidence below.

## Transport and authority

Private frames contain version, correlation ID, operation, and payload. Control
replies occupy their own PIDE chunk; binary event/checkpoint material uses separate
raw chunks. Unknown versions, operations, identities, shapes, and exceeded limits
reject. External clients cannot construct events, evidence, execution tickets, or
arbitrary PIDE commands. Native `status` reports readiness, or explicit
unavailability for a poisoned incarnation requiring restart.

The initial profile permits two ML threads, 64 in-flight host exchanges, a
2,200,000-byte frame, 512-byte control payload, and 30-second reply wait. D45 runs
fixed commands on one owned FIFO, bounded to 64 active/queued commands and 16 MiB
retained frame bytes. Its protocol reader remains free for Scala callbacks.
Canceling a host wait does **not** cancel an already queued native command.

Native gates issue opaque event tokens. The sole coordinator serializes prepare,
generated validation, durable CAS commit, and native acknowledgement for every
event, including lifecycle, blockers, and outcomes. It commits the exact predicted
post-ack checkpoint computed by the actual reducer. A client cannot supply a
candidate callback, claim projection, or receipt as authority.

Cancel and Forget wait at most 60 seconds for their exact token's committed and
acknowledged outcome. At most 64 explicit waiters are retained; regular commits
cannot evict their receipts. An already canceled result does not establish a new
Forget commit. Acknowledged denial and physical erasure are distinct.

`MetadataFrame` transports finite metadata, not arbitrary HOL carriers. Tag 0 is a
big-endian uint32 decimal-byte count followed by canonical nonnegative ASCII
decimal. Tag 1 is a big-endian nonnegative signed-32-bit constructor tag and
uint32 child count followed by children. Defaults are 1 MiB, depth 64, 65536 nodes,
and 128 decimal digits. Leading zeros, unknown tags, truncation and trailing bytes
reject; native decoding additionally checks exact constructor arities/types.

`install_ids` accepts only a lease reserved durably by the workspace counter.
Unused IDs burn, including installation failures. IDs and decoded metadata never
grant admission. `claim_starts` inspects generated commands; actual registered
input, executor, request and one-use permit bindings remain required for dispatch.

## Recovery and lifecycle

Recovery derives required associations from the latest checkpoint and obtains
protected immutable material from their actual origin commits. Native role-specific
checking reconstructs real contexts/objects with saved semantic IDs and fresh
process-local handles, then installs state once. Missing material, denied access,
or failed checking closes that incarnation. Recovery issues no workers or tickets
and does not replay historical questions, workflow events, or effects.

Recovery is startup-exclusive. The per-artifact protected transfer holds the store
monitor, and the client/pump starts only after success. This is not a live reload
interface. Event/checkpoint and executable slots are bounded to 1 MiB; additional
slot/resource limits are in [persistence.md](persistence.md).

D44 adds atomic last-owner support retirement and retains every cleanup job for
overlapping lifecycle operations. Current host maintenance polls the aggregate
barrier, including revoke-only work, and retries failed jobs at most eight times
with backoff capped at 30 seconds. Exhaustion retains intent/roots and checks the
barrier every 30 seconds. Physical erasure requires a completed barrier. Actual resident attempt `6c02e53b4e2947b6ae54159eb8f6caf2` passed
last-owner commit-before-ack recovery, strict restart, and immediate Forget, with
stable inputs and clean process cleanup. This does not establish cross-generation
checkpoint compatibility or D43 build recovery.

## D43 protected build ingress — implementation checkpoint

This source is host-tested but not yet connected to a qualified native build,
recovery, or packaged service consumer. It accepts an actual opaque
`NativeBuildInputs.Owned` from the same store. Descriptor and theory originals come
from that single captured revision; it never reopens current paths or accepts a
caller name-list as export authority. Historical inspection requires continued
source access but is distinct from current-source build/adoption permission.

`build_input_begin` carries one UTF-8 YXML artifact, at most 16384 bytes: root
`build-input`, version 1, with managed revision/manifest, original paths, lengths,
SHA256 pins, and a fresh lowercase 32-hex `upload_nonce`. Descriptor path is
`package.json`; theory path is a distinct portable `.thy`. Each original is at
most 1,000,000 bytes; parent candidates are ordered and bounded to 64. There are
two upload permits, retained through unresolved cleanup. Profile/setup are fixed
by the installed builder. Writes are contiguous chunks of at most 65536 bytes.
Finish produces an opaque prepared input; `propose_build` separately creates the
charged workflow.

The worker offers a result; the caller confirms `build_input_accept(nonce,ID)`
before publishing an accepted handle. Nonce discard disposes unaccepted ownership;
accepted ownership requires known-ID release. Lost replies retain the owner and
capacity. After worker join and a native control completion barrier,
`build_input_settle(nonce)` removes bounded terminal correlation state. These
operations stay on the D45 queue; reader arrival alone cannot drain detached work.
A finite join failure reports pending cleanup and retains its registry.

The fixed `veri7vn.package_descriptor_v1` Scala function parses the native-owned
original descriptor through `PackageModel.descriptor` and returns bounded typed
expectation YXML. This declared metadata adapter grants no admission. Production
registration must use the actual jar's Isabelle service manifest and a fresh JVM;
a temporary test classloader does not register global Scala functions.

Before a build commit, a protected native binding must identify its actual
prepared input/request. The host resolves it before acquiring the source monitor.
Lock order is coordinator, source/store, then bounded native validation/ack.
Source transfer, parsing, replay and teardown run outside that monitor; ack may
fork owned work but cannot synchronously call a store callback. The optional host
guard and SQLite race behavior are tested; native binding/wiring remains open.

## Evidence and remaining consumers

D72's current reader draft uses `effect_source_open(sourceUID)` with no input
artifacts. Unavailable ownership returns `effect_source_unavailable`, echoing the
UID without artifacts. `effect_source_owner` echoes the UID with one leaf YXML
frame of at most 4096 bytes. Its closed version-1 fields bind workspace, source,
attempt, request, configuration, packet, actual positive native context, status,
projection/payload hashes, byte count, protocol `local-mcp/1`, representation
`decoded-json/1`, owner incarnation, state version and durable sequence.

The host serializes query and capability opening with lifecycle persistence.
Only the bridge's private issuer for the same resident can mint the one-use
confirmation; opening rejects a changed checkpoint, and resident teardown retires
the issuer. Borrowing the protected reconstruction bytes independently rechecks
continuing source permission. This is historical observation access, with no
execution, dispatch or new result license. The native producer and actual MCP
retrieval consumer remain unqualified; host storage tests use an explicit
controlled native-owner boundary.

The new runtime's restore inventory is version 4 with two artifacts. Ordinary
rows carry `request-child|artifact|evidence|effect-request,id,semantic`; the
semantic is an actual positive protected context identity. Source rows carry
`source-input,uid,pending|recorded` or `acquired-source,uid,confirmed|failed`,
with no inferred generation. The dedicated `effect-request` category uses role
`local-mcp/1` / `effect-request`, an empty nonassertional sequent and an actual
fixed executable pin. It preserves original control/configuration/packet
ownership for inspection, never an executor or handoff permit. This migration
does not make an older native producer compatible with the new host.

- Actual resident baseline: `var/runtime-host/resident-pass-e8efa7e5`, attempt
  `e8efa7e5fae14a66a647e8c7be3becf6`, paired native baseline
  `6c1269b0971d4e5cb7f5074b6d0bd883`. Concurrent original questions reached charged
  execution/licensed HTML; fresh-process nonempty recovery kept journal sequence;
  selective Forget erased its artifacts and preserved a survivor through restart.
- Corrected baseline jar: `var/runtime-host/public-package-final-41e34e70`, attempt
  `41e34e70827e4cba8616a8694e47f1f9`, SHA256
  `8486c19bca61025ac0f15f5ca3aa9dcf68f0652fba33c388405fa4eb379785f0`.
  This historical package checked the actual selected heap/build record.
- Host checkpoint: attempt `bf0cb5fe3f7f4e4d8a8ce06f3777d337`, session
  `95fcfdd61e543422`, stable inputs, clean exit, eleven groups in 50.1695 seconds.
  Actual SQLite/registered source resources and controlled protocol-loss tests
  establish host conformance, not native D43 replay/admission.

Packaging uses the matching Isabelle distribution classpath and `bin/isabelle
java veri7vn.runtime.service.RuntimeMain`. Compile/classload, native heap launch,
staged deployment, expanded workbench, D44 lifecycle, and D43 candidate recovery
are separate consumers. Historical receipts do not qualify later source changes.
