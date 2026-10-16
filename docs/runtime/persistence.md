# Runtime persistence

`WorkspaceStore` owns one SQLite WAL/FULL writer, forced immutable blobs, source-head CAS, native event/checkpoint journal, protected artifact references, dispatch records, and managed resources. The actual native gate/reducer supplies authority. Stored bytes/hashes and Scala projections cannot substitute for native checking.

Distinct revisions identify workspace source, native journal/CAS, generated model, lifecycle epoch, and native allocation. A single coordinator prepares/validates an opaque candidate, commits its exact predicted post-ack checkpoint, then acknowledges natively. Indeterminate commit/ack poisons readiness; shutdown releases coordinator before storage.

For guarded builds, resolve the registered native input before taking the source monitor. Its opaque current-head/workspace guard covers commit and bounded native validate/ack. Parsing, transfer, replay, and teardown stay outside locks; historical original-byte access is not current-source build authority.

## Recovery and ownership

Before writes, slots record durable intents: stage, slot, exact path, digest/size, dependencies. Adoption removes them atomically; startup collects unadopted paths while preserving shared references. Locators grant no access.

Recovery joins latest checkpoint/access with immutable origin material. Fixed native checkers verify role, pin, source/context closure, saved identities, and actual reconstructed objects. Startup transfers slots under the monitor before enabling the pump. Failure closes the incarnation rather than reusing partial maps. No work or effects replay.

Manifest v2 is closed and <=8192bytes. Named slots are projection, sequent, context closure, reconstruction, and optional executable. Event/checkpoint/projection/sequent/executable caps are1MiB, context16MiB, reconstruction100000bytes, aggregate32MiB. IDs are positive <=128 decimal digits; dependency closure <=8192 includes association. Kernel/math assertions require nonempty sequents. Closed nonassertional Build/qualification/source/request profiles permit empty raw sequents only with their exact role, fixed code pin, and native correspondence; zero-export candidates need no dummy claim. Charged execution identity differs from resulting native context. Current role/version integration is described in [protocol.md](protocol.md).

## Source storage and cleanup

`ManagedSources` records exact request/head/private stage before content writes; CAS and terminal status commit together. Exact retries return historical status. Current reads require recorded selected-manifest membership; revocation/tombstones block stale-locator or reused-operation reacquisition.

Defaults: 40 MiB/object, 256 MiB distinct bytes, 8192 objects, 256 MiB request bytes, 128 operations. Exhaustion preserves replay identity. Roots require owner-only POSIX permissions.

Resources/path intents register before writes. Denial precedes cleanup; signaling uses the source monitor, joins run outside. Confirmed termination permits deletion; failures retain retryable roots. Startup reconciles PID/start identity, not JVM absence.

Head replacement denies current use but preserves owned historical reads; revocation/Forget/release deny both. Build transfer uses a budgeted worker-owned clone; cancel/join precedes clearing, and unresolved begin/finish/accept cleanup retains owner/capacity. See nonce reconciliation in [protocol.md](protocol.md).

Unknown dispatch is journaled with event/checkpoint before acknowledgement, bound to deployment and command. Duplicates cannot append another dispatch; restart never relaunches Unknown work. Forget erases after native cleanup. Queues/tombstones survive partial deletion; shared roots preserve blobs. Erasure excludes hardware copies.

D44 maintenance polls aggregate cleanup, retries owned failures at most eight times with exponential backoff capped30s, then retains roots/intent and polls every30s. Completion resets the episode and permits erasure. Resident attempt `6c02e53b4e2947b6ae54159eb8f6caf2` covers last-owner retirement, commit-before-ack restart, and immediate Forget.

## Closed snapshots and evidence

`WorkspaceSnapshot.acquireClosed` holds the existing Java writer lock without opening the original database, copies a bounded regular-file inventory into a private directory, and validates absence of resident/resource registrations. Orphan-risk records cause refusal, never stripping. The lease spans probes/selection; copies cannot consume original IDs. Failed construction remains incomplete. Live snapshotting/schema migration are separate.

`var/runtime-host/resident-pass-e8efa7e5` covers concurrent math, licensed publication, fresh-process nonempty restore, selective physical Forget, and survivor restart. Host attempt `bf0cb5fe3f7f4e4d8a8ce06f3777d337`/session `95fcfdd61e543422` covers eleven SQLite/source/resource/protocol-loss groups. SQLite/JDBC/filesystem behavior remains the storage trust boundary. Expanded Build/qualification/source recovery, cross-generation deployment, and external connector crash consumers require their actual composed checks; compiler passes alone do not qualify them.
