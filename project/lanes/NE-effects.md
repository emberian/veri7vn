# Native effect intents, 2026-10-28

The native core can retain a request to do something after a conversation reply
commits. It records who claimed the work, a deadline, the result, and whether a
crash left the outcome unknown. It does not run a lesson builder, change an
Oracle workspace, send a message, or execute caller code.

Changed files: `native/oracle-core/src/effects.rs`,
`native/oracle-core/tests/effects_contract.rs`, and this report. Root owns module
exports, runtime integration, schema migration and the host executors.

Specialist-panel numbers: none. Theorem statements: none. These are Rust/SQLite
execution contracts, not Isabelle proofs or a full Oracle capability migration.

## What the source consumers need

Read-only source examined in
`var/runtime-architecture-20261028/source/workbench/swarm/`:

- `organs10.py` directs lessons, places, ledger, growth workspaces and scratch to
  mutable state separate from the release. It also changes process globals when
  imported. The new outbox does neither; the embedding host must select scoped
  resources and capabilities explicitly.
- `voice10.Mind.ask` and `ledger95.ask` inspect the entire existing JSONL ledger
  to find its predecessor, then append the answer. The latter binds a knowledge
  snapshot and plan. A native ledger consumer should retain those bindings and
  use an atomic indexed predecessor check, rather than copy that append recipe.
  An existing JSONL append is not receiver-deduplicated.
- `ledger95.snapshot/materialize` bind admitted parts and exam records by
  content. A growth or teaching intent must retain the relevant immutable
  knowledge state, source hash and admitted-part references in its payload.
  The outbox's body hash cannot substitute for those semantic checks.
- `teach75.lesson` only teaches an answered question. It checks each equation,
  independently solves worked/practice examples, reads picture labels back and
  checks film values. It writes several artifacts. An executor needs a bounded
  staged artifact set and a receipt naming the checked outputs; marking the
  intent completed alone establishes none of those teaching checks.
- `grow60.build/main` construct a source target, launch a build subprocess with
  scoped environment overrides, admit parts through exams, and record before
  and after scores. A native growth executor needs the checked target,
  admission evidence and publication boundary. A subprocess exit code alone
  does not establish useful or correct growth. Workspace mutation is
  AtMostOnce until the actual receiver implements durable deduplication.
- `slowfire71` checks greeting, sensor admission, signatures and current
  consent/revocation before reads or tells. A queued operation must recheck
  current authority when it runs. A stored payload is not continuing consent.

## Durable behavior

An identity is `(tenant, effect_id)`, with host-chosen bounded identifiers. Its
SHA256 binds a versioned domain tag, tenant and every intent field: session,
request, capability, replay policy and exact payload bytes. An exact enqueue
retry returns the current row, including a completed result. Changed content
with that identity fails. Tenant identity must come from the authenticated host.

The states and transitions are:

| From | Operation | To |
|---|---|---|
| absent | enqueue, in the reply/state transaction | pending |
| pending | claim and commit | leased, with a new generation |
| leased before its deadline | complete | completed |
| leased before its deadline | mark outcome unknown | uncertain |
| expired leased, AtMostOnce | bounded recovery | uncertain |
| expired leased, ReceiverDeduplicated | bounded recovery | pending |
| uncertain | authoritative evidence of completion | completed |
| uncertain | authoritative evidence that it did not and cannot still run | pending |

Only a host-approved receiver that durably deduplicates the stable tuple
`(tenant, id, body_digest)`, including simultaneous and late calls, may use
ReceiverDeduplicated. Retrying a timed-out non-idempotent action automatically
is forbidden by the state transitions. Explicit unknown outcomes remain held
for reconciliation even for deduplicated receivers.

A fence binds tenant, identity, body hash, generation, claimant and exact lease
deadline. Expiry is strict: a result arriving at the deadline is late. Renewing
replaces the fence; the older copy is invalid. Recovery and reconciliation
invalidate old claims. Exact completion retries with the original successful
fence/result are accepted after a lost commit acknowledgement. Changed results
are rejected. Fences control journal writes; they cannot stop a process or
undo an action at an outside service.

Rows are never silently deleted. Entry count and aggregate payload/result/
reconciliation-evidence bytes use transactionally updated counters, with per
value limits checked before copying retained blobs into Rust. Only the latest
reconciliation evidence is retained; this is not a growing attempt log. Pending
selection, expiry and inspection have dedicated indexes. Recovery and keyset
inspection have configured page bounds. The host owns tenant scheduling and
fairness; no background thread or implicit queue starts here.

## Exact integration recipe

1. Export `pub mod effects;` from the crate. No dependency changes are needed.
2. In the root-owned state-schema migration, call
   `effects::initialize(&tx)?` exactly once, for fresh databases and for an
   explicit upgrade of existing stores. It creates only its tables, indexes and
   counter triggers. It does not change SQLite pragmas or application/schema
   identity. Keep the host's WAL/FULL settings and state-file ownership checks.
3. Construct one `EffectOutbox::new(EffectLimits { ... })?` with operator bounds.
   Keep it in the trusted runtime/host. Serialize writers and use IMMEDIATE
   transactions. Roll back the whole caller transaction on any outbox error.
4. A pure evaluator or trusted adapter may propose a bounded set of intents.
   The host registry validates the capability-specific payload, source/image/
   admission bindings, tenant authority and replay policy. Include those exact
   intents in the originating request digest so reusing a request ID with a
   changed effect proposal conflicts. Require each intent's session/request to
   match that originating turn. Cap the number of intents in one turn.
5. After rechecking request replay and session version, write the reply, next
   session state/lineage and all intents through `outbox.enqueue(&tx, tenant,
   &intent)?` in the SAME transaction, then commit. Session lineage holds IDs and
   request/revision only; the outbox is the authority for effect outcomes. The
   reply should say work was queued, never imply it already succeeded.
6. The host scheduler selects an authorized tenant and capability. In a short
   IMMEDIATE transaction, call `claim_next` or exact-key `claim`, then commit.
   Do not execute the returned work until its lease commit succeeds. Run the
   host capability outside SQLite's writer transaction. Pass the stable tuple
   and exact payload to the receiver; renew if needed and commit the replacement
   fence before using it. Clocks must be trustworthy across restarts.
7. Validate a bounded outcome receipt, then call `complete` in a fresh
   transaction. A handled refusal/failure may be a structured result; completed
   means a durable outcome, not mathematical correctness or admission. If the
   outside action may have happened but no reliable result exists, call
   `mark_uncertain` while the lease is valid, or leave expiry recovery to hold it.
8. Run `recover_expired` in bounded committed pages. Inspect uncertain work with
   `list(..., EffectState::Uncertain, after_id, page_size)` and `get`. Only fresh
   authoritative host evidence may call `reconcile`; `NotApplied` must also
   exclude an old worker still running. Receiver confirmation may instead use
   `Applied(receipt)` without repeating the action. No real external operation
   or public message was run in this lane.

The interface deliberately leaves executors, their sandbox/resources, consent
checks, target publication, real specialist admission, tenant fairness, retry
backoff and immutable artifact retention to the host. The aggregate byte quota
does not reserve future result space: an action can finish when its receipt
cannot fit. The host must provision headroom/short receipts and treat failed
settlement as unknown, never infer that the action failed. SQLite/WAL overhead
also needs a physical disk quota. No deletion or ID-reuse protocol is supplied.

## Checks and remaining validation

No builds or tests were run, per root's instruction to use hbox for execution.
`rustfmt --edition 2021` succeeded on both Rust files. Source review and
`git diff --check -- <owned Rust files>` found no whitespace issue (new files
are untracked until root stages them). These are not compiler/test results.

The 15 contract tests include a helper and two real subprocess-crash scenarios.
The child test process exits while a SQLite transaction is still live, so Rust
cannot supply a tidy destructor rollback. One crashes before reply/state/intent
commit; another commits a lease, writes a fixture-local marker standing in for
an external action, writes but does not commit completion, then exits. Restart
must retain the claim, lose the uncommitted result, hold it uncertain at expiry
and refuse automatic retry. No outside service is contacted.

Other cases exercise atomic rollback, every changed intent field, tenant
isolation, competing independent SQLite connections, uncommitted claims,
strict expiry, receiver-deduplicated generation changes, late/changed results,
renewal invalidating an old fence, explicit reconciliation, bounded recovery and
inspection, capacity preserving identity, per-value/aggregate limits, retained
values under tighter bounds, invalid clocks/IDs and generation overflow.

Root's narrow execution command after exporting the module:

```sh
CARGO_BUILD_JOBS=2 cargo test --locked -p oracle-runtime-core --test effects_contract
```

Run that on the designated hbox with its normal target/resource controls. Then
exercise the root-owned runtime integration with its own request/state tests;
these standalone contracts do not prove that the runtime actually enqueues an
intent together with a conversation reply.

## Follow-on: an actual Rust Runtime consumer

Root subsequently authorized two more owned files:
`native/oracle-core/src/runtime/host_effects.rs` and
`native/oracle-core/tests/runtime_effects_contract.rs`. The outbox also now exposes
`limits_digest()`, which hashes all six actual immutable broker bounds under a
versioned domain. It cannot be replaced by an arbitrary caller-supplied label.

`Runtime::execute_with_effects` and `execute_program_with_effects` take a
`HostEffects { outbox, intents }` batch. They use the existing pure evaluation
path. Root's `execute_dialect` changes bind the canonical intent batch and actual
broker-limit digest to request identity, check batch/encoded-byte limits, reject
mismatched origin and duplicate IDs, and enqueue in the final reply/state
transaction. Root also connects the effect schema to fresh state stores and the
explicit store-v1 to store-v2 migration. These source integrations were read;
no execution result is claimed here.

The trusted host can now inspect, claim, renew, settle, recover and reconcile
through `Runtime::effect_*` methods without receiving a SQLite connection or a
callback slot. Each call opens and commits its own short transaction; a returned
lease is therefore durable before a host executor can use it. Writer locks are
released before returning. Every wrapper checks the admitted release's operation
before touching the state store:

| Host operation | Release operation |
|---|---|
| execute a turn carrying intents | host.effects.enqueue, plus graph.execute or kqa.execute |
| get or list rows | host.effects.inspect |
| claim, claim next or renew | host.effects.claim |
| complete or mark uncertain | host.effects.settle |
| recover expired leases | host.effects.recover |
| reconcile authoritative evidence | host.effects.reconcile |

The development compatibility constructor has no admitted release, as before.
These methods belong to authenticated Rust hosting code; no Python tenant
binding exposes them. Registering a broker operation does not admit a concrete
lesson, growth or network executor. Concrete capability validation, consent,
containment and external authority still belong to that host.

The twelve additional runtime contract tests cover graph/program enqueue and
exact replay after settlement/restart; changed intent/actual-profile conflicts;
every broker limit affecting profile identity; rollback of an earlier enqueue
when a later enqueue conflicts; quota rollback preserving request/state retry;
origin/count/encoded-byte checks; cancellation; closed program opcodes; restart
recovery, renewal and reconciliation; and an admitted query-only release refusing
every host-effect wrapper before store access. They use only temporary local
fixtures and run no real capability.

Validation performed for this follow-on: rustfmt succeeded on the three Rust
files; no compilation or tests, as instructed. Root's additional scoped hbox
command is:

```sh
CARGO_BUILD_JOBS=2 cargo test --locked -p oracle-runtime-core --test runtime_effects_contract
```

Remaining release work: the broker policy digest binds each originating request,
but the release resource-profile identity currently covers query limits. A whole
host release policy should admit the effect profile too. Native selection-only
sessions do not fabricate an Oracle adapter snapshot just to populate
`oracle.last_effect`; linkage is currently the committed request/session origin
in the outbox. Full Oracle adapter lineage still needs its actual adapter.
