# Resident host feasibility

The bounded RC1 fixtures in `experiments/runtime-host/` test Headless protocol,
local durability and handoff races. They do not implement generated authority,
native admission or production recovery.

## Mechanisms and evidence

`Host_Protocol.thy`/`probe.scala` starts an existing custom HOL heap through Headless,
registers a PIDE handler and sends five commands without theory edits. Version
rejection and future cancellation pass; cleanup stops the worker. Headless loads
existing heaps; the development driver builds the fixture first. Scala startup
compilation is separate from warm ML command latency.

`durable.scala` uses SQLite WAL/FULL, a cooperating writer lock and one monitor for
revision/epoch, command identity, blobs, commit/ack and dispatch. Blobs are verified,
forced and atomically installed before journal references. The same monitor encloses
current-authority checks, durable attempt insertion and immediate executor handoff;
retirement cannot pass a paused callback. Exceptions near handoff preserve unknown
outcome and prohibit blind replay.

Passing checks cover stale/duplicate denial, database reopen, before-commit rollback,
after-commit acknowledgement loss and child JVM abrupt termination:
`halt(73)` before commit restores revision 0; `halt(74)` after commit restores revision
1/exact payload; `halt(75)` during handoff restores unknown and denies reuse. These
are local process-death fixtures, not power-loss or exactly-once qualification.

Protocol startup measured 3372 ms excluding Scala/JVM startup. Local protocol evidence:
`var/runtime-host/protocol-20261015T133500Z/receipt.json` and sibling archived logs.
Durability details remain with the fixture's source-pinned driver receipt; tests are
host conformance, never native theorem evidence.

## Run and production obligations

```sh
python3 tools/dev/check-native --session Veri7vn_Runtime_Host \
  --session-root experiments/runtime-host \
  --scala-script experiments/runtime-host/probe.scala --timeout 240
python3 tools/dev/check-native --session Veri7vn_Runtime_Host \
  --session-root experiments/runtime-host \
  --scala-script experiments/runtime-host/durable.scala --timeout 420
```

Use the shared build lock. Production must bind exact native-authorized batch,
expected revision, epoch, command, target/permit and delta, then validate journal
sequence/artifacts/reconstructed associations before enabling restore. Add quotas,
revocation/Forget, migration, missing-heap/platform checks and connector reconciliation.
SQLite/JDBC/OS remain explicit trusted boundaries.

Crucially, AddBlocker/SetOutcome may invalidate a staged claim without advancing
epoch. Commit followed by rejected DurableAck must not resurrect it on restart.
Serialize all relevant native transitions through precommit/DB/ack or use a token
covering them; workspace revision plus epoch alone is insufficient. OpenRequest
permissions come from authenticated policy and AttachEvidence from native admission,
never public protocol constructors. The fixture does not test this correspondence.
