# NRETENTION — explicit native namespace retirement, 29 October 2026

## Result and consumer

Authored a host maintenance API that permanently closes a namespace and reclaims
its local session, exact-reply and completed-effect payloads. Active namespaces
keep exact retries indefinitely within their admitted capacity. There is no TTL,
silent ID eviction, tenant-facing retirement operation or full automatic
retention claim. The consumer is authenticated Rust/Python host code retaining
the Runtime object. HTTP caller operations exclude these host capabilities.

No specialist-panel numbers. No new theorem statements. Handwritten Rust and SQL
are not Isabelle proofs. No real user store was retired.

## Changed files

- `native/oracle-core/src/runtime.rs`: state schema 3 transactional migration;
  permanent compact tombstones; SQL write fences; host retire/inspect methods;
  tombstone checks before replay, session snapshot and commit; atomic payload
  deletion and global count adjustment; cancellable maintenance SQLite progress.
- `native/oracle-core/src/budget.rs`: operator `retired_namespaces` limit,
  default 65,536; positive signed-SQL-counter validation.
- `native/oracle-core/tests/runtime_retention_contract.rs`: authored scoped
  contracts using manufactured images and stores.
- `native/oracle-python/src/lib.rs`: narrow host Runtime methods only.
- `native/tests/test_python_retention.py`: five authored actual-extension host
  consumer contracts for stale handles/restart, atomic failure/cancellation,
  finite capacity, profile validation and explicit release gates.
- `native/oracle-python/src/release.rs`: fixed registry admits the two host
  version-1 maintenance methods. This does not authenticate the host.
- `native/docs/RETENTION.md`: authority, retirement/audit semantics, stale-writer
  fences, finite history, release/store compatibility and physical-space limits.
- This lane report.

## Safety and compatibility decisions

An IMMEDIATE transaction serializes retirement against committing turns and
external data writers. A permanent tombstone is inserted before deleting payloads.
The runtime consults it before initial replay and at commit. Durable SQL insert
and update triggers on sessions, requests and effects reject closed namespaces
even for an already-open old runtime or a prepared old statement. Tombstones
cannot be updated or deleted through ordinary SQL. A stale WAL read transaction
cannot upgrade into a write behind a committed retirement. Privileged schema
changes and backup rollback remain outside the integrity boundary.

Every pending, leased or uncertain effect refuses retirement. Completed effects
can be removed, including their local outcome and reconciliation evidence: the
operator explicitly authorizes losing that audit when retiring a namespace.
Nothing cancels an outside action or changes receiver-side deduplication duties.
Cancellation before commit, delete failures and counter inconsistency roll back
both tombstone and deletes. A successfully committed retirement may outlive a
lost response. Repeating it is safe and consumes no additional tombstone.

The configured tombstone limit is enforced in the retirement write transaction.
Reaching it refuses further retirement and retains all history. Lowering the
limit preserves existing tombstones. There is no claim of infinite exact IDs
inside finite storage. Operator profiles sharing a store should agree. Freed
logical SQLite capacity can be reused, but this does not promise smaller files,
secure erasure, backup purge or a total disk quota.

Schema-1 and schema-2 stores upgrade transactionally to schema 3 without rewriting
old request digests/replies/sessions/effects. The session envelope stays version2.
The new setting participates in the measured resource profile; a newly measured
binary/profile still needs release admission, and existing release identities
are not silently rebound. No release migration is implemented here.

## Checks and outstanding work

`rustfmt --edition 2021 --config skip_children=true` completed successfully on
the changed Rust files. No build or test ran in this lane, per root's central
validator rule. Authored tests are not an execution receipt. Root must run the
scoped retention contract, affected existing runtime/release/effect contracts
and the actual extension consumer checks against its central artifact.

Host lane coordinated public metadata filtering and its operator core-limit
allowlist. Remaining service lifecycle work includes an authenticated operator
maintenance consumer, namespace minting/epoch policy, audit export if wanted,
and backup/physical-storage policy. These are not supplied by this API.
