# Revisable incident evidence

This workflow asks whether a supplied incident plan is safe. It keeps two
independent readiness reports. Withdrawing one leaves readiness supported;
withdrawing the last removes it. A risk report blocks the plan even if a
conflicting no-risk report remains. Removing coverage disables absence-based
approval. Every answer names its immutable evidence snapshot.

The native `oracle_logic::revisions` module owns revisions. The Python client
only sends exported complete snapshots to the existing `logic.query` host.
These fixtures authorize no deployment or other external action. Coverage means
coverage of the declared supplied source domain, never all facts in the world.

Host integration must authenticate tenant/workspace, admit maximum serialized
bytes, and persist the typed history and successful mutation acknowledgement in
the existing session journal transaction. Commit evidence before solving: a
solver timeout must leave the evidence committed. On restore, replay checked
history with `Workspace::restore`; do not deserialize internal derived maps.
The native domain module does not supply a second journal or global registry.

No retained multishot cache is implemented. Measure identical revision histories
against fresh solving before adding one: p50/p95, process starts, resident bytes,
output bytes and number of inactive historical records. Explanations distinguish
AND bodies, OR alternatives, default-negative guards and coverage dependencies.
They are rule explanations, not causal proofs.

Authored contract cases are in `native/oracle-logic/tests/revisions_contract.rs`.
They use exhaustive independent tiny-program semantics, not a claim of specialist
panel performance. No shipped specialist-panel numbers are available yet.

`incident-history.json` supplies six exact revisions and independently authored
safe-answer gold values. Coverage expiry is represented by an explicit coverage
withdrawal; the module has no clock or automatic validity scheduler. Source
precedence, external source verification and semantic consistency between signed
atom names remain policy responsibilities. Conflicting observations remain
separate atoms unless the supplied policy adds constraints.

Snapshots retain historical records to reject reused IDs. `max_records` bounds
history and record count; the host must additionally enforce owner payload bytes,
program limits and per-tenant quotas. There is no automatic compaction because
forgetting old IDs or retry tokens changes the mutation contract.

After root registers the module, the coordinated runner can export and evaluate:

```sh
cargo run --manifest-path native/Cargo.toml -p oracle-logic --example revisions_lab > var/revisions-export.json
python3 tools/usage/revisable_evidence.py var/revisions-export.json --tenant incident-demo --url http://HOST:PORT
```

Alternatively pass `--solver /absolute/operator/pinned/clingo` to the native
example to solve every revision freshly and compare all six answers with gold.
The operator chooses the solver, never an untrusted tenant request. The example
emits support templates with conjunctions, alternatives, negative guards and
coverage IDs alongside each request and its receipt. Templates describe rules;
they are not assertions that every body holds in every stable model.

Coverage records here are caller-declared supplied-domain closure. They are
narrower than external-world completeness but do not prove traversal to source
EOF. A separately checked source EOF receipt can justify such a declaration;
this module neither manufactures that receipt nor upgrades a declaration into
one. Replacing its immutable version requires a new ID and atomic withdrawal.

The persisted host path uses the same session store and journal as other native
operations. It keeps evidence in schema 3 `native_extensions` under
`oracle.logic.revisions` version 1, independently of unavailable Python state.
The host derives tenant and workspace from its session binding; command JSON
cannot supply either. `logic.workspace` commits a tagged `revise` command and
returns its exact acknowledgement. `logic.workspace.solve` reads the requested
session version and solves the requested evidence revision without mutating it.
A concurrent new revision leaves the returned older receipt accurate.

```sh
python3 tools/usage/revisable_evidence.py tools/usage/specialist/revisable-evidence/incident-history.json --persisted-history --tenant incident-demo --url http://HOST:PORT
```

This performs six durable revisions, exact acknowledgement retries and six fresh
solves with independent gold answers. The native host must have an image/state
store and the operator-admitted logic solver configured. Unknown/stale revisions
and conflicting retry-token content are refused. Solving after a committed write
can fail while its evidence and acknowledgement remain durable.

## Stop and resume an evidence plan

`logic.workspace.checkpoint` is a pure, version-checked receipt for the current
stored owner. It reports authenticated scope, admitted runtime identity, session
version, evidence revision, snapshot identity, active record IDs and active
coverage IDs. Request both the expected session version and evidence revision;
an optional expected snapshot identity supplies an additional equality check.
A stale request refuses instead of silently selecting newer evidence. At a fresh
session version zero, an absent evidence owner can yield an empty bootstrap
receipt without creating a row. That receipt does not say evidence was previously
persisted, or that any unknown Python conversation owner is empty.

The checkpoint is not historical snapshot storage, a compressed history, or
permission to import client state. Every server read still validates the stored
owner. Native `Workspace::import_with_control` checks inherited work, cancellation
and deadline between replayed events. Its returned typed `Workspace` can produce
several projections without another import. The generic core owner validation
still performs a separate replay before the host checkpoint projection; this
batch does not remove that duplication or introduce a retained solver cache.

Use an explicit local cursor to stop after two additional revisions:

```sh
python3 tools/usage/revisable_evidence.py tools/usage/specialist/revisable-evidence/incident-history.json --persisted-history --cursor var/incident-resume.json --stop-after 2 --tenant incident-demo --url http://HOST:PORT
```

After restarting the same admitted host, run the same command without
`--stop-after`. The consumer resumes that supplied plan and first re-solves the
last committed evidence revision, so a prior solver failure cannot hide a
successful mutation. The cursor binds the tenant, conversation, admitted runtime
and supplied plan. Changing any of those refuses resume.

Before sending a mutation, the consumer atomically replaces and fsyncs its local
record with the complete pending request, including request ID, command and old
expected version. It retains the record under a local exclusive lock. On resume
it retries that exact pending mutation **before** asking for a checkpoint, and
retires pending only after checking the corresponding acknowledgement. A lost
reply after commit therefore recovers from the server's exact journal entry.
The local file is a retry cursor, never another authoritative evidence ledger.
Its combined receipts and pending request must fit 1 MiB of UTF-8 JSON; the same
limit applies before replacing the file and when reopening it. An oversized
pending record refuses before sending. If an acknowledgement-derived replacement
cannot be saved, the earlier durable pending record remains available for retry.
It can contain supplied observations; choose its explicit path accordingly.

If another native turn advances the session, the old cursor refuses even when
the evidence owner itself did not change. It never silently rebases. If a pending
mutation committed before that concurrent advance, exact replay recovers its
acknowledgement first and the following checkpoint still reports the stale
position. A definitive rejection also leaves pending intact for diagnosis; the
client does not guess that a transport failure means the mutation was absent.

The central validator can exercise actual response loss and restart in two
stages, stopping and starting only its own host between them:

```sh
python3 tools/usage/specialist/revisable-evidence/recovery_probe.py --stage lose --url http://HOST:PORT --tenant recovery-demo --cursor var/recovery-demo.json
# Restart the same admitted host and state store, then:
python3 tools/usage/specialist/revisable-evidence/recovery_probe.py --stage resume --url http://HOST:PORT --tenant recovery-demo --cursor var/recovery-demo.json
```

The loss stage deliberately discards a received acknowledgement after the server
completed it; it never restarts a process itself. Use a fresh conversation/state
for this supplied fixture. Focused tests cover interrupted restore, stale scope
and identity, lost replies, invalid acknowledgements, changed pending requests,
concurrent advance, failed solving and independent support/coverage withdrawal.
No execution, performance improvement or new specialist-panel score is claimed
by these authored cases.

The first hosted owner admits at most 128 revisions and 128 historical record
IDs, additionally bounded by the existing 256 KiB owner payload cap. This keeps
checked restore work bounded. At capacity it refuses further mutations; it does
not silently forget prior retry tokens or withdrawn IDs. A future compaction
contract needs explicit retry/identity retention rules and measurement.
