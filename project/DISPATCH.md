# Active implementation wave — 2026-10-15

The user agreed to proceed with architecture revision 2, asked for gpt-6.1-sol as
much as practical, and explicitly requested an active goal for the full project.
Root owns synthesis, task statuses, shared contracts, integration and commits.
Implementation belongs to scoped agents. The complete product remains the target;
small deliverables are interfaces/integration points, not a lowered destination.

Read AGENTS.md, docs/ARCHITECTURE_PROPOSAL.md, your entries in project/tasks.json,
relevant C01–C05 contracts and design/review reports. Existing source reports are
leads, not execution evidence. Inspect actual source when a behavior matters.
Each lane owns only its listed paths. Do not edit shared ROOT files, other lanes,
the tracker, LICENSE.md or shared contracts without an ownership agreement.

| Agent | Task and owned area |
|---|---|
| build_support61 | native-build-support; tools/dev/** and tests/dev/** |
| admission61 | native-admission; src/isabelle/admission/**, tests/admission/**, docs/formal/admission.md |
| registry61 | native-registry; src/isabelle/registry/** and tests/registry/**; co-review shared codec/native objects with model/language/sources/linkage |
| linkage61 | native-linkage-feasibility; experiments/native-linkage/** and its design report |
| host61 | runtime-host-bootstrap review; runtime-service active in src/runtime/{service,host}/**, tests/runtime/{service,host}/**, docs/runtime/{protocol,persistence}.md |
| authority61 | operational-model; src/isabelle/model/**, tests/model/**, docs/formal/operational.md |
| sources61 | source-semantics; src/isabelle/sources/semantics/**, tests/sources/semantics/**, docs/formal/sources.md |
| language61 | interpretation-model; src/isabelle/language/model/**, tests/language/model/**, docs/formal/interpretation.md |
| coverage61 | coverage-disposition complete; known-regressions retains repaired-native-consumer gate |
| authoring61 | workbench-audit/workspace-interaction complete; package-intake active in src/packages/intake/**, tests/packages/intake/**, docs/packages/intake.md |
| performance61 | performance-envelope; benchmarks/envelope/**, tools/performance/envelope/**, docs/performance/envelope.md |

Build support extends the existing serialized driver for independent lane sessions.
Use lane-local ROOT/session files. Coordinate checks through the driver and its
shared lock; do not launch manual concurrent Isabelle builds. No HOL-Analysis
builds, global environment edits or cache deletion. Preserve warm artifacts.
Native authorities/model/linkage/source/language owners send proposed common
signatures early for cross-review, before downstream consumption. No universal
HOL value universe, arbitrary callback-as-proof bridge or metadata truth token.

Report concrete working code, exact theorem statements and assumptions, real
consumers, refuting checks, timings and outstanding obligations. No sorry,
skip_proof, hidden oracle/axiom or false completion. Tests cannot replace required
refinement; explicit TB assumptions cannot absorb owned algorithms. Runtime guards
precede execution; conditional source premises are separate. Search proposals do
not publish acceptance. Roots retain unsupported behavior as tracked work.

Do not spawn further agents or commit shared work in this wave without root
coordination. Seek a true useful replacement when an initial theorem/design fails.
Send recoverable obstructions promptly; continue independent work rather than
waiting on a signature that is not yet needed. Root replenishes downstream work
as real interfaces become usable.

Build queue: build_support61 is sole steward. Native lanes request a slot and
await a grant; no retry racing. Its tooling task is complete but stewardship
continues. Scoped/default inputs exclude independent session edits while retaining
actual declared dependencies. Root reviewed the passed default/scoped receipts.

Package intake is an independent early production component. It stages inert
original/native contents and draft source revisions; native admission/activation
remain package-lifecycle consumers. Shared host/authority integration is mandatory.

Checkpoint signing: two attempts to commit the staged reviewed work failed in
the configured 1Password SSH signer (failed to fill whole buffer). Signing policy
was not bypassed. Staged/working files remain intact; this does not block code work.

Production host work starts against reviewed feasibility while native dependencies
remain open. The tracker warning is intentional, not dependency completion. Its
first shared consumer is inert package/source storage; full runtime-service still
requires generated reducer/gate/lifecycle integration. Serialize all state events
with native staging through durable ack, including blockers/outcome changes that
do not advance workspace revision or authority epoch.

Registry early implementation is likewise active before final linkage feasibility
review. It owns native object tables and common profile/codec signatures; no
downstream signature freezes until co-review. Authority owns finite metadata wire
codecs/roundtrips after core compilation, distinct from family bulk-value codecs.
Decoding privileged event data never grants event-construction authority.
