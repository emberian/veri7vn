# NRETENTION — explicit native namespace retirement, 29 October 2026

## Result and consumer

Implemented a host maintenance API that permanently closes a namespace and reclaims
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
old request digests/replies/sessions/effects. The session envelope stays version 2.
The new setting participates in the measured resource profile; a newly measured
binary/profile still needs release admission, and existing release identities
are not silently rebound. No release migration is implemented here.

## Checks and outstanding work

The central validator qualified code commit `77731632484d0c7129362dca150eb5310cb70233`
against its frozen 140-source closure. The [stable appliance validation receipt](../../native/evidence/2026-10-29-stable-appliance-validation.json)
records extension SHA-256
`f875fc2e217cbe5b7b4de196d546b717a105b28e9767b49905570f1893ae2a37`.

All 10 `runtime_retention_contract` tests passed. All five Python retention
contracts passed against that actual extension with
`python -B native/tests/test_python_retention.py --extension ARTIFACT`.
The affected runtime, session, effect and release contracts also passed in the
115-test scoped Rust run. The broader receipt records one additional actual
resident-kernel test and 54 selected Python checks; those totals cover the
combined appliance, not extra retention cases. Warnings-denied Clippy and the
release build passed. No build or test was run independently in this lane.

These results qualify the manufactured-store/API boundary described above.
They do not qualify real user data, an authenticated maintenance service or the
complete Oracle Engine. State-store schemas 1/2 upgrade to 3 while preserving
old reply bytes, request digests and session envelope 2. The added operator
limit/profile still requires admission; there is no release-history migration.

Host lane coordinated public metadata filtering and its operator core-limit
allowlist. Remaining service lifecycle work includes an authenticated operator
maintenance consumer, namespace minting/epoch policy, audit export if wanted,
and backup/physical-storage policy. These are not supplied by this API.
