# Retiring a native runtime namespace

An authenticated operator can permanently close a tenant namespace and reclaim
its local conversation, exact-reply and completed-effect payloads. This is an
explicit host maintenance action. It is not automatic expiry, session eviction,
a tenant request, or a general archive service.

Until that action commits, completed requests retain the existing exact-reply
contract: the same tenant, request ID, session, expected version, release and
input bytes retrieve the stored reply. Changed input conflicts. Reaching a
journal or session limit refuses new work; it never silently forgets an old ID.

Retirement changes that contract for the whole namespace. Every later stateful
turn refuses with `namespace retired`, including an exact retry, a new request
ID, and the same request ID in another session. The namespace never becomes
available again. The outer host must assign a fresh namespace for future work;
a request ID inside that fresh namespace is an independent request. Pure image
queries do not use conversation or replay storage and remain pure queries.

## Host API and authority

Rust host code calls:

```rust,ignore
runtime.retire_namespace(host_assigned_namespace, cancellation)?;
let closed = runtime.namespace_is_retired(host_assigned_namespace)?;
```

Python host code has the corresponding `Runtime.retire_namespace(tenant,
cancellation)` and `Runtime.namespace_is_retired(tenant)` methods. `Tenant` has
neither method. These APIs confer no authentication: the embedding host must
keep its Runtime object and maintenance entrypoint away from tenants. A runtime
opened with an admitted release additionally requires version-1 implemented
operations `host.retention.retire` and `host.retention.inspect`, respectively.
The Python release factory recognizes those fixed host methods. The public
runtime HTTP operation catalog and dispatcher exclude them.

The namespace is the complete host routing key stored in SQLite, not a session
ID or necessarily a human account. Retiring it discards all its sessions and
request history across every image/release using this state store. The operator
must account for those consumers before authorizing destruction. No HTTP admin
endpoint, authorization service, automatic account remapping or retirement
scheduler is provided here.

## What commits together

One SQLite IMMEDIATE transaction:

1. Checks the durable namespace fence and makes a repeated retirement a no-op.
2. Refuses if any effect is pending, leased or uncertain, even if its lease has
   expired. The operator must resolve it through the existing effect protocol.
3. Reserves a permanent namespace tombstone within the configured capacity.
4. Deletes this namespace's completed effect rows, sessions and exact replies.
5. Decrements global session, request, effect-entry and effect-value usage.

A completed effect means the host already recorded an outcome. Retirement
explicitly discards that local outcome, payload and reconciliation evidence.
It does not archive them. An operator needing a lasting audit must export it
through a separately authorized process before retiring the namespace. Nor does
retirement stop an external process, revoke an outside capability or shorten a
receiver's deduplication obligation. Existing effect reconciliation requirements
remain necessary, including excluding an old worker before concluding that an
action did not happen. Pending or uncertain work cannot be discarded to obtain
capacity.

Cancellation or deadline expiry before commit rolls the transaction back. A
SQLite progress handler checks the maintenance budget during longer statements.
Storage errors, an injected delete failure, capacity exhaustion and inconsistent
session/request counters also leave no partial retirement. A successful commit
is the boundary: cancellation during the final fsync may be too late. After a
lost response the host can inspect or repeat the same retirement. A competing
SQLite writer can produce a busy error; the host may retry. Maintenance holds
the state connection and database write lock for this transaction, never an
image worker or a lock spanning another request's computation.

## Durable protection against stale writers

The runtime checks the tombstone before replay, before reading a session and
inside the turn's commit transaction. It does not cache this decision in an
individual Runtime or tenant handle. A turn evaluating during retirement cannot
commit afterward. If its commit wins first, retirement deletes that result;
if retirement wins, the turn refuses. A read already in progress may return its
previously observed reply; retirement does not retract bytes already read.

SQLite insert and update triggers independently fence `sessions`, `requests`
and `effect_intents`. They check both the old and new tenant for updates.
Consequently an already-open older runtime, a statement prepared before the
schema migration, or an ordinary external SQLite data writer cannot recreate
retired payloads. An older WAL read snapshot cannot upgrade into a stale write
after retirement commits. Tombstone update and delete triggers reject reopening
a closed namespace. Inserting a tombstone also refuses unresolved effects at
the SQL layer.

These are persistent integrity fences, not a sandbox against a privileged
operator who drops triggers, rewrites tables or restores an older backup.
Backup restoration must preserve the full state store and its retirement
history. Rolling the database back behind an observed retirement can reopen
namespaces; that operation needs an external policy and is outside this API.

## Bounded history and space

`Limits.retired_namespaces` is an operator setting, defaulting to 65,536. It must
be positive and fit SQLite's signed 64-bit counter. Each tombstone retains only
the bounded namespace identifier, at most 128 ASCII bytes, plus SQLite overhead.
A singleton counter tracks their number. The IMMEDIATE transaction checks the
actual configured limit before inserting another tombstone. Existing tombstones
are preserved when a new operator profile lowers this limit; further retirement
refuses until an explicitly larger limit admits it. Repeated retirement uses no
additional capacity. The setting participates in the measured resource profile.
Hosts sharing a store should deploy the same admitted operator limits.

No finite exact tombstone store supports infinitely many retired namespace IDs.
Capacity exhaustion refuses retirement while preserving the live payloads and
all previous fences. Raising the operator limit raises the bound; it does not
evict history. A longer-lived service needs an explicit namespace/store lifecycle
policy that carries permanent exclusion history forward. No such unbounded
lifecycle or whole-service automatic retention policy is claimed here.

The existing session, request and effect limits continue to bound live payloads.
Retirement returns their logical capacity for reuse by other namespaces. SQLite
can reuse freed pages, but the database and WAL files need not shrink. This API
does not run VACUUM, checkpoint old readers, securely erase disk pages, purge
backups or enforce a total directory quota. Operators retain those duties.

## Store compatibility

Native state-store schema 3 installs the tombstone tables and fences. Opening a
schema-1 or schema-2 store upgrades it inside one transaction; failure rolls back
new tables, triggers and the schema version. Existing sessions, request digests,
reply bytes and effect records are unchanged. Session-envelope schema remains 2;
this is a storage migration, not an interpretation change. A new empty store
starts at schema 3. A fresh open by older code rejects version 3. Its already-open
connections still encounter the persistent SQL fences.

The digest algorithms for ordinary turns do not change. However, the added
operator setting changes the measured resource profile, and a newly measured
runtime artifact changes a release identity. Existing release admission and
release-bound replay rules still apply. This migration does not rebind old
release sessions to a new artifact or authorize reading one release's history
through another. A deployment must retain a compatible identity or use a
separately supported release migration; no release-identity migration is added
by retirement.

## Evidence boundary

`runtime_retention_contract.rs` authors manufactured-store contracts for restart,
already-open runtimes, request IDs across sessions, cancellation and atomic
failure, completed and unresolved effects, global capacity recovery, historical
store migration, prepared old writers, WAL snapshots, immutable tombstones,
operator capacity and release gates. Central validation owns their execution
receipt. These are handwritten Rust/SQL contracts, with no new theorem claim or
specialist-panel score. No retirement was performed on real user data.
