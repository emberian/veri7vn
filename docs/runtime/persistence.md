# Runtime persistence boundary

## Writer and authority

`WorkspaceStore` is one SQLite WAL/FULL writer with forced immutable blobs,
source-head CAS, native event/checkpoint journal, protected artifact references,
dispatch records, and managed resource ownership. Native acceptance comes from
the actual native gate/reducer and reconstructed objects, never stored bytes,
hashes, generated Booleans, or a second Scala authority reducer.

Revision domains remain separate:

- Workspace revision records inert source/storage edits.
- Native journal sequence is the CAS position of each durable native event.
- Model revision is the generated core's revision; some events change state
  without advancing it.
- Authority epoch tracks generated lifecycle authority.
- Native allocation uses its own workspace namespace and decimal counter.

The coordinator owns one all-event monitor and store lease. It prepares and
validates an actual gate candidate, commits the exact predicted post-ack image,
then acknowledges it natively. Another coordinator is rejected. Prepare,
validation, commit or ack exceptions invalidate readiness; no blind retry follows
an indeterminate commit. Shutdown releases the coordinator before closing storage.

For guarded builds, resolve the native input binding before taking the source
monitor. An opaque guard from the actual registered captured owner checks both
workspace identity and current head under the same monitor as commit and bounded
native validate/ack. Parsing, transfer, replay and teardown stay outside it.
An edit before commit rejects; a concurrent edit cannot pass between commit and
ack. Historical access to captured bytes does not establish current-source use.

## Native artifacts and reconstruction

Every recovery slot has a durable publication intent before file writes: stage,
slot, exact temporary path, digest, size and native-derived dependency edges.
Journal adoption removes intents in the same transaction. Startup collects only
recorded unadopted paths and preserves shared live references. Blob locators are
not public read capabilities.

A protected recovery capability requires the exact latest event/checkpoint and
current lifecycle access, while its immutable material may originate in an older
commit. Capabilities are scoped, bounded, released explicitly and invalidated when
the journal advances. Native reconstruction checks pinned profiles, source/context
closure, saved semantic IDs and actual evidence before installation. Fresh native
handles do not substitute for saved identities. Nonempty recovery works in the
resident baseline; it reissues no workers, execution tickets, workflow events, or
external effects.

The current envelope is a closed version-2 manifest, at most 8192 bytes, binding
workspace, association, semantic generation, profile/role and slot hashes. The
checked host baseline accepts `native-kernel/1` kernel evidence and
`exact-arithmetic/1` math request/output material. Named slots are projection,
sequent, context closure, reconstruction, and optional executable. Event,
checkpoint, projection, sequent and executable limits are 1 MiB; context closure
is at most 16 MiB, reconstruction 100000 bytes, and aggregate material 32 MiB.
Association/dependency IDs are positive, at most 128 decimal digits; dependency
closure is bounded to 8192 IDs and includes its association.

D43 adds nonassertional build-request/build-candidate roles and the separately
coordinated qualification roles. Their exact profile/role allowlist, empty raw
sequent, required code pin, native membership/reconstruction and host transport
are pending migration. Empty assertion slots for kernel/math must not become a
compatibility shortcut. A candidate may have zero theorem exports without a dummy
claim. Its charged execution lineage is distinct from its native context identity.

Restoration is startup-exclusive. Protected slot transfer holds the store monitor;
the client/event pump starts only after native checking succeeds. Failure closes
that resident rather than reusing partially bound identity maps. Live reload would
need a separate governed revocable stream lifetime.

## Managed source and worker ownership

`ManagedSources` shares the writer. Operations record exact request bytes,
expected head and private stage before content writes; commit records CAS and
terminal outcome atomically. Exact retries return historical terminal receipts.
Current reads require the selected manifest's recorded member closure, not merely
a known hash. Revocation/Forget deny access; tombstones prevent reacquisition by
reusing operation IDs or supplying no expected head.

Default draft limits are 40 MiB per object, 256 MiB distinct retained bytes,
8192 objects, 256 MiB retained canonical request bytes, and 128 operations.
Exhaustion refuses work rather than dropping replay identity. Compaction and larger
corpus profiles remain separate work. Storage roots require owner-only POSIX
permissions; portability and hardware erasure are separate qualification limits.

Worker resources register before copying bytes or creating scratch paths. Exact
path intents precede writes. Source access is denied before cleanup; signals occur
under the source monitor, joins outside it. Only confirmed stopped owners permit
buffer clearing, deletion of recorded paths and ownership removal. Failure keeps
the resource registered for retry. Startup does not infer process death from a
lost JVM: resident PID/start identity and owner termination govern reconciliation.

Captured roots have distinct current and retained read paths. A changed head
rejects current use while an active registered captured owner can still inspect
its pinned original bytes. Revocation, Forget or release deny both. Build failure
spans belong to that exact original source, not a reopened current draft.

Native build transfer uses a separately budgeted clone attached to its actual
worker. Only bounded capture occurs under source/resource locks; native I/O runs
outside both. Cancel/join precedes clone clearing. Unresolved native begin/finish/
accept cleanup remains tracked with its source owner and capacity; a finite join
attempt is not a claim of termination. See [protocol.md](protocol.md) for nonce
reconciliation and the current D43 implementation boundary.

## Dispatch, denial and erasure

Native dispatch is recorded as Unknown in the same transaction as the event and
checkpoint, before acknowledgement can start work. It pins the deployment and
bounded command identity. Duplicate command occurrences cannot append another
dispatch. Unknown survives restart and never authorizes relaunch.

Generated Forget denials drive native artifact erasure only after the native
worker/root cleanup barrier completes. Erasure queues and association tombstones
survive partial deletion; shared live references preserve their files. Secure
deletion/WAL truncation cover owned journal storage, not hardware-level erasure.
Storage-only source methods are not generated native lifecycle transitions; full
Forget joins authoritative propagation and native/worker release.

D44 host maintenance polls the aggregate barrier, including revoke-only cleanup,
and retries failed owned jobs at most eight times with exponential backoff capped
at 30 seconds. Exhaustion retains roots and erasure intent and checks the barrier
every 30 seconds. A complete barrier resets the retry episode and permits physical
erasure. Actual resident attempt `6c02e53b4e2947b6ae54159eb8f6caf2` passed atomic
last-owner retirement, commit-before-ack strict restart, and immediate Forget
with stable inputs and clean cleanup. Cross-generation compatibility remains a
separate deployment gate.

## Evidence and open coverage

- `var/runtime-host/resident-pass-e8efa7e5` records the actual concurrent math,
  licensed publication, fresh-process nonempty restore, selective physical Forget,
  and surviving-result restart baseline. It does not cover last-owner D44, expert
  build recovery or external-effect crash reconciliation.
- Host attempt `bf0cb5fe3f7f4e4d8a8ce06f3777d337`, session `95fcfdd61e543422`,
  passed eleven groups with stable inputs and clean exit in 50.1695 seconds.
  Tests include real SQLite commit/ack/source races, retained/transfer lifetimes,
  actual captured source owners, and controlled lost-reply/timeout cleanup. These
  check host conformance, not generated HOL or actual native D43 replay.
- Earlier store/intake/resource checkpoints remain historical evidence under
  `var/runtime-host/`; they are superseded as descriptions of current behavior.

SQLite/JDBC/filesystem durability and host extraction/persistence/execution remain
declared boundaries. D43 composition, candidate/qualification recovery,
current-work cancellation, full deployment/erasure, and production connector
reconciliation remain explicit consumers rather than implications of these tests.

## Closed deployment probe snapshots

`WorkspaceSnapshot.acquireClosed` takes the existing Java writer lock without
opening the original database. It copies a bounded, regular-file-only inventory
to a new private directory, preserves denial/tombstone records, and validates the
copied SQLite database has no resident or managed-resource registrations. A crash
can leave an orphan native process even after the JVM lock disappears; such
records cause refusal rather than being stripped from the copy. The original
must first be reconciled by its owning runtime.

The returned lease holds the original writer lock through compatibility probes
and any selection transaction. The command-line helper prints a ready JSON record
and releases the lock on stdin EOF. Probes use separate copies and fresh image
caches; opening a probe may consume allocator IDs only in its copy. Snapshot
construction failure leaves a partial owned destination without a ready record.
This source checkpoint awaits its finite host test and actual cross-generation
probe; it does not supply a live-store snapshot or a schema migration.
