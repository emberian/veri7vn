# Resident host feasibility probe

Bounded host feasibility probes implemented and executed, 2026-10-15. This is bounded host fixture evidence for
C03–C05, not the generated authority machine, admission or production service.

`experiments/runtime-host/Host_Protocol.thy` installs an application protocol in a
lane-local HOL descendant heap. `probe.scala` starts Headless resources from the
existing heap, registers a `Session.Protocol_Handler`, and sends five commands
without document edits. It tests explicit protocol version rejection and future
cancellation. The worker is stopped in `finally`.

RC1 source inspection: `src/Pure/PIDE/headless.scala`, Resources.start_session,
obtains `store.session_heaps` and calls `Isabelle_Process.start(...).await_startup`.
It does not invoke a build. The serialized development driver explicitly builds
the lane heap beforehand; a deployed launcher must validate prebuilt artifacts
and fail on missing ones. `isabelle scala` itself invokes scala_build for the
installed Scala component: that tool startup is distinct from warm ML commands.

`durable.scala` uses Isabelle SQLite JDBC, WAL and synchronous FULL. An exclusive
workspace file lock prevents a second cooperating writer. A single
monitor serializes revision/epoch checks, exact command identity insertion,
artifact publication, durable commit and acknowledgement. Blobs have SHA-256
names, verified content, forced temporary file data, atomic installation and a
forced containing directory before journal references. The fixture exposes SQL
constraints to reject reused identities; it supplies no merge policy.

The same monitor encloses cancellation and current epoch/revision checks, unique durable attempt insertion
and the executor callback. Retirement and cancellation take that monitor too. A durable cancellation
identity prevents later handoff for that identity. The callback is
an immediate handoff, not a deferred launch queue. Durable attempt status starts
as unknown. A callback exception leaves it unknown and restart refuses to repeat
it. This neither guarantees exactly once execution nor reconciles a connector.
A latch race checks retirement cannot pass a paused actual handoff. Production
must specify each connector's handoff and reconciliation operation.

The commit fault seam throws immediately before/after JDBC commit, then
closes/reopens the database and checks recovered state. The script also launches
bounded child JVMs and invokes Runtime.halt immediately before/after commit,
then checks recovered revision and structured payload without replay. A third
child halts inside executor handoff; recovery retains unknown and rejects replay. Passing
this checks process death and acknowledgement loss, not OS power failure or
filesystem durability. Execution evidence is recorded below.
SQLite/JDBC/OS and this Scala coordinator are explicit trusted boundary code.
No fixture event is a generated HOL transition or native theorem. Production
still needs exact staged-batch/delta/native association validation, generated
reducer linkage, recovery validation of artifacts, quotas and bounded codecs,
revoked-payload/forget handling, process death/clean-machine qualification,
connector-specific reconciliation and migration integration.

Run through the shared driver, never alongside another native build:

```
python3 tools/dev/check-native --session Veri7vn_Runtime_Host \
  --session-root experiments/runtime-host \
  --scala-script experiments/runtime-host/probe.scala --timeout 240
python3 tools/dev/check-native --session Veri7vn_Runtime_Host \
  --session-root experiments/runtime-host \
  --scala-script experiments/runtime-host/durable.scala --timeout 420
```

Execution results are appended after successful runs; early compilation failures
are not success evidence. Sandbox execution initially failed at restricted
`sysctl`; the approved elevated driver preserves the same lock and local state.

## Executed resident protocol evidence

The command above passed on Isabelle2026-RC1, Darwin arm64, at
2026-10-15T13:35:00Z. Stable source fingerprints and complete logs are archived
locally in `var/runtime-host/protocol-20261015T133500Z/receipt.json` and
`scala.log`. The receipt's original log paths point to the shared session output;
use the archive's sibling logs after subsequent driver invocations.

A prebuilt custom HOL heap started through Headless in **3372 ms** (resource
construction plus ML startup; excludes Scala compiler/JVM startup). Five serial
custom-command round trips were **16.473, 1.708, 1.636, 0.983, 0.887 ms**.
These tiny pings include queue/event delivery and carry no proof/admission work.
The long 30-second future emitted `started`, was cancelled through a second
protocol command, and emitted `interrupted`; cancellation plus both events took
**1000.617 ms** in this run. Wrong protocol version was rejected. The first
worker stopped, a second worker started from the same heap, and a fresh ping
returned successfully. No theory document was edited for any request.

The full serialized driver took 21.640 seconds; its warm build check took 7.435
seconds and the Scala invocation took 13.173 seconds including compilation and
both worker lifecycles. One job and two ML threads were configured. This is one
local feasibility run, not a throughput or production cancellation guarantee.


## Executed durable boundary evidence

The second command passed with stable source fingerprints at
2026-10-15T13:52:35Z. Complete local evidence is archived in
`var/runtime-host/durable-20261015T135235Z/receipt.json` and `scala.log`.
It used the same RC1/Darwin arm64 environment, shared lock and local Isabelle
state. Driver time was 46.671 seconds; Scala time was 35.923 seconds including
three child JVM compilations, abrupt halts and recovery checks. No resident ML
worker was started by the durable script. The first immutable blob publication
plus journal commit took **31.723 ms**, a single sample excluding DB setup.

Checks exercised:

- A second cooperating writer is refused; SQLite uses WAL and FULL synchronous.
- A committed event and its content-addressed payload survive database reopen.
- Stale revision/epoch and repeated command identity do not publish a transition.
- Before-commit exception rolls back; after-commit acknowledgement loss retains
  the committed revision. No request is rerun during recovery.
- Cancelled identities, stale authority/revision and consumed attempt identities
  cannot hand off; retirement preserves already handed-off attempt history.
- A latch blocks inside the executor callback while retirement waits on the
  same monitor. Releasing the callback permits handoff then retirement.
- Child JVM `Runtime.halt(73)` before commit recovers revision 0;
  `Runtime.halt(74)` after commit recovers revision 1 and the exact payload.
- `Runtime.halt(75)` inside the executor callback leaves durable attempt status
  unknown. Recovery refuses the same lease and does not call the executor.

Each abrupt child termination returned its expected exit code; no shutdown hook
or JDBC close performed its recovery work. Local temporary database paths are
retained in the log. These are process-crash probes of a local filesystem,
not a power-cut qualification or an exactly-once external effect guarantee.
The executor is a controlled callback, not a production connector.

## Remaining consumers and integration

No shared contract or production interface was changed. Runtime-service owns
replacing these fixtures with the actual generated reducer, native gate and
client envelopes. The authority lane proposes batch_id/expected_revision/
batch_epoch/batch_delta and an immediate successor-of-intent revision check for
ClaimStart; the adapter must bind all of those to the native association. The
fixture's current-revision check is not that correspondence proof. C03/C04/C05
remain the governing contracts; no proof theorem is asserted here.

Production still needs staged delta/native association checks, replay/recovery
validation of full journal sequence and restored associations, effect target and
permit binding, connector reconciliation, hard message/artifact quotas, package
migration, revoked-payload/managed-erasure handling, missing-heap diagnostics and
clean-machine platform qualification. The host/JDBC/filesystem remain explicit
trusted boundary assumptions. The authoring lane received the file publication
and CAS conventions as a feasibility reference, not a frozen shared API.

Root integration identified an additional correspondence obligation: after
StageClaim/Persist, AddBlocker or SetOutcome may invalidate binding_licensed
without changing authority epoch. A DB commit followed by a rejected native
DurableAck must never resurrect that invalid publication on restart. The
production coordinator must serialize the full generated transition, precommit
validation, DB commit and acknowledgement sequence against every relevant native
event, or use a validated token/revision covering all those events. Workspace
revision plus authority epoch alone does not establish this. The fixture lacks
these native events and does not test that invariant. OpenRequest permissions
must originate in authenticated policy; AttachEvidence must originate in the
native admission gate. Neither is a public protocol authority constructor.
