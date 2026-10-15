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

The checked task graph contains 43 tasks. On foundation acceptance, six foundation
tasks are complete and eight initial implementation lanes become dispatchable.
The board is generated from the ledger. Relative local Markdown references and
current evidence paths are checked during the final checkpoint review.

## Limits

These checks do not establish production performance, a complete admission
policy/metatheory, clean target deployment, or completed upstream migration.
The native inspector is diagnostic, not an admission implementation. The fixture
consumer is not a general package loader. Schema checking does not prove a
package's claims. The full coverage, authoring, assurance and deployment gates
remain open in the task graph. Earlier arithmetic/C experiments retain their
separate research status; this foundation check does not revalidate them.

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
