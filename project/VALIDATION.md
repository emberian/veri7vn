# Foundation validation

Reviewed by root on 2026-10-15 after contract, native, coverage and coordination
lanes landed and cross-reviewed their consumers. This completes the foundation
stage only. Executed evidence below is distinct from future task checks.

Development host: macOS ARM64; Isabelle2026-RC1 at
`/Applications/Isabelle2026-RC1.app`. Native foundation uses bundled HOL,
workspace-local state, one build and two ML threads.

## Executed checks

| Check | Result and scope |
|---|---|
| `python3 -m unittest discover -s tests/project -v` | Seven tests pass: malformed tasks, cycles/dependencies, completion evidence, ownership, derived readiness, advisory overlap and stable board output. |
| `.venv/bin/python schemas/check.py` | 19/19 structural fixtures pass, including rejected authority claims/unsafe paths and accepted blank, data and theory-library packages. |
| `.venv/bin/python schemas/check.py tests/scaffold/package.json` | Real native fixture descriptor validates. Structural validity alone grants no semantic authority. |
| `python3 audit/coverage/generate.py --check` | Deterministic inventory matches: 305 specialist manifests, 124 class names, 1,757 Python content hashes and 3,608 tracked entries. Git identities do not assert local materialization of LFS payloads; class names do not count distinct semantics. |
| `python3 tools/dev/check-native` | Final driver passes on Isabelle2026-RC1. Receipt starts 2026-10-15T11:35:02Z; all seven assertions present, input snapshots stable, total driver time about 27 seconds. The incremental build can reuse session assertions; this is neither a clean-install test nor an application performance result. |
| Native driver adverse-condition probes | Native lane checked shared-lock exclusion and a stub tool that edits an input mid-build: the latter receives `unstable` status and a nonzero exit. Stub evidence is explicitly not an Isabelle proof/build. |

Native assertions cover transported contracts, retained hidden hypotheses,
exported premises, complete theorem statements, descriptor-derived canonical
export resolution, unresolved-name rejection and wrong-kind rejection. Root and
contracts peer inspected the descriptor, generator and native consumer together.
The generator encodes descriptor strings as data rather than executable ML.

Native command/log/hash receipts are local at `var/native-scaffold/receipt.json`,
`build.log`, `smoke.log` and `stability-probe.json`. They are intentionally ignored
runtime artifacts. The final run includes the source-stability hardening; two
snapshots still do not detect a concurrent edit followed by exact restoration.
Immutable deployment inputs remain a tracked requirement.

## Integration review

- C01 supports packages without exported capabilities. Exported capabilities
  require native locators, and the real fixture tests those locators in Isabelle.
- C03–C05 distinguish immutable environment identity from request session/prestate
  and observation/evaluation time with clock basis. Effect commits recheck their
  applicable preconditions; stale assumptions must not disappear into a cache key.
- Coverage and product review retained workbench authoring, stateful specialists,
  connectors, dialogue, deployed search, retained growth and deployment. No
  inventoried specialist is marked as a completed lift.
- Required family, proof and release gaps block completion. Original unavailable
  data has a separate disposition; exclusions need an agreed scope decision.
  PO-01–10 are mandatory and all open, avoiding a vacuous audit of existing claims.
- Repair version creation now depends on package lifecycle. Initial client work
  can proceed before mature search/profiling, whose actual usability remains a
  mandatory integration gate. Independent recipient rehearsal is a final gate.

At foundation acceptance the checked graph contained 43 tasks: six foundation
tasks were complete and eight initial implementation lanes became dispatchable.
The board is generated from the ledger. Relative local Markdown references and
current evidence paths are checked during the final checkpoint review.

## Limits

These checks do not establish production performance, a complete admission
policy/metatheory, clean target deployment, or completed upstream migration.
The native inspector is diagnostic, not an admission implementation. The fixture
consumer is not a general package loader. Schema checking does not prove a
package's claims. The full coverage, authoring, assurance and deployment gates
remain open in the task graph. This foundation check did not revalidate the
earlier arithmetic/C prototype, which was subsequently removed at user request.

## Preimplementation omissions review

After checkpoint `81e1b31`, four source-review lanes inspected domain specialists,
the inherited runtime, the workbench and pinned sibling implementations. Their
[synthesis](../docs/review/PREIMPLEMENTATION.md) records G01–G08 design requirements
and exact source reports. This produced semantic contract revision 1 and additional
task acceptance cases; descriptor format 0 and executable scaffold are unchanged.

This audit did not execute upstream specialists or sibling applications. Its
source-derived defect candidates and proposed regressions are not new end-to-end
reproductions. The provisional 119-entry domain partition is not completed
behavioral migration. All mandatory metatheory obligations remain open.

Validation after the documentation changes: seven coordination tests and all
19 schema fixtures pass; local Markdown references resolve and changed files pass
`git diff --check`. No native rebuild was needed for documentation/task changes.
The task ledger still distinguishes future checks from completed evidence; source
reports are design inputs, not fabricated implementation completion.

## Architecture convergence and prototype cleanup

After checkpoint `9e4f619`, the user requested reconsideration before implementation
fan-out, then removal of the superseded Python prototype. Four scoped reviews
challenged semantics, runtime, authoring and coverage. Root's
[revision 2 synthesis](../docs/ARCHITECTURE_PROPOSAL.md) now selects generated HOL
control, open native meanings, finite typed execution/linkage, canonical theory
source, resident Scala/PIDE deployment and one durable state/effect protocol.
Cross-review resolved runtime guards, cross-generation session migration, atomic
executor handoff, retirement/revocation policy and formal versus trusted closure.
No remaining architectural blocker was reported. User design agreement is pending.

The [cleanup record](../docs/design/prototype-cleanup.md) identifies 13 removed
tracked files and their Git recovery commit. Audit/development Python tools,
upstream reference, native experiments and shared caches remain. Current docs no
longer offer the deleted runner as an entrypoint. Cleanup checks passed seven
project tests, nineteen schema fixtures and the actual descriptor; native inputs
and generated-data hashes still match the last successful stable receipt. No
native rebuild was needed or performed for documentation and obsolete-file removal.

The updated graph has 46 tasks, including two early linkage/proof-transport and
host/recovery feasibility tasks. All seven project tests pass; root's final graph
check has zero warnings and zero dispatchable tasks. `design-convergence` is in
review, not done. All PO-01–10 remain open, and TB-01–05 remain unqualified.
Design scenarios and new technical probes are explicitly unexecuted.

Local Markdown target checks and `git diff --check` pass. No new production
implementation, performance result, source migration, native proof, deployment
qualification or external publication is claimed by this checkpoint.

## Authorized implementation wave

The user subsequently agreed to proceed, requested gpt-6.1-sol implementation
agents and an active full-project goal. Design-convergence is complete; nine
scoped 6.1-sol lanes were dispatched. Build support and workbench audit have
reviewed evidence; the other implementation tasks remain active. Workbench WB04
corrects the earlier exposure-import inference: JSONL rejection occurs first.
The shared driver now supports scoped sessions while preserving one lock, warm
state and stable input receipts; root inspected passed default seven-assertion
and custom-session receipts. These are tooling/audit completions, not native
platform or metatheory completion. See tasks.json for evolving status.

## Runtime and cross-interface review

Root inspected both stable host archives (protocol 20261015T133500Z, durable
20261015T135235Z), their logs, and the actual Scala persistence/handoff fixture.
Resident prebuilt-heap protocol/restart/cancellation and actual child-JVM crashes
before/after commit and during handoff passed. These demonstrate bounded mechanisms;
the generated authority/native gate and complete lifecycle recovery are still open.
The first durable commit was one 31.722792 ms sample, not a percentile or product
budget. `benchmarks/envelope/host-durable.json` retains exact source/log identities.

Root independently reran all 23 then-present upstream regression fixtures (pass,
1.309 seconds) and the coverage source/policy checker (305 manifests,119 domain
profiles,361-class C3,22 regression source pins and293 local helper identities).
Later audit additions have separate lane evidence until reviewed. These fixtures
characterize upstream behavior and scoped compositions; none proves native repair.

Cross-interface review identified stale Accepted-tag rendering and a durability
race when blockers/outcomes change without changing revision/epoch. Rendering now
uses the shared current binding license (proof check pending); the complete
native staging/commit/ack serialization contract is recorded in DECISIONS and
owned by production runtime/effect integration. Mandatory PO/TB gates remain open.

The native driver now streams output to live logs and exposes actual advisory lock
state plus driver/child handles. Root inspected its implementation and live status;
five controlled tooling checks passed in the owning lane. Verbose theory progress
supports narrowing slow proofs without repeatedly rerunning opaque timeouts.

Workspace interaction design was accepted after desktop/mobile/operation review.
Production inert intake, native registry, and runtime-service work are underway.
The48-task ledger retains two deliberate unresolved-dependency warnings for early
registry/runtime work; these dependencies remain completion gates, not waived work.
