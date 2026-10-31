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

The first hosted owner admits at most 128 revisions and 128 historical record
IDs, additionally bounded by the existing 256 KiB owner payload cap. This keeps
checked restore work bounded. At capacity it refuses further mutations; it does
not silently forget prior retry tokens or withdrawn IDs. A future compaction
contract needs explicit retry/identity retention rules and measurement.
