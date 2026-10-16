# Whole-project review and horizon

Reviewed 2026-10-16 against the plan, ACC-01–16, PO-01–10/TB-01–05,
source-reviewed Oracle7 coverage, current implementation and scoped evidence.
This is a dated synthesis. [tasks.json](tasks.json) owns current status;
[BOARD.md](BOARD.md) is its generated view. A passing component is not a passing
product workflow. Agent reports of new results are leads until integration review.

## What we are building

A usable specialist engineering environment native to Isabelle: import or author
source, understand its language and meaning, diagnose and repair it, compose it,
obtain justified results, improve execution, and deploy it with continued search
and growth on the recipient's machine. The [architecture](../docs/ARCHITECTURE_PROPOSAL.md)
combines open native HOL developments, generated operational control, typed family
implementations and a durable host/workbench. Those mechanisms must meet in the
actual application. The destination remains the [full acceptance plan](../docs/product/ACCEPTANCE.md).

## The working baseline

The captured standalone macOS ARM64 package has passed outside-checkout source
import/reopen, native exact arithmetic, fresh-process native recovery, and the
bundled browser workshop: import, exact source Open, two new-revision Saves,
normal close and fresh CLI readback. The shipped launcher requires neither system
Python nor a source compiler. Root reviewed the installed and workshop result
records; the [canonical summary](../tests/deployment/evidence/standalone-aae0d7dd.json)
identifies the artifact and finite checks.

Earlier captured resident tests cover result/provenance, cancellation, Forget and
restart. The [validation record](VALIDATION.md) retains their identities and limits.
The current working tree contains newer native/service changes, so these successes
do not automatically qualify the next assembled package. Source editing currently
retains revisions; it does not activate the edited specialist.

Whole standalone invocations observed roughly 10–16 seconds in the four-call
trial. These are a useful baseline, not satisfactory interactive targets or a
speedup claim. A subsequent instrumented source-only comparison measured reopen
at22.005s before and8.027s after invocation-local hash-buffer reuse and standard
hex formatting, retaining every integrity check. The
[comparison](../benchmarks/envelope/standalone-hash-repair-comparison.json) records
the exact artifacts and limits: one observation per version, uncontrolled cache
and load, no native speedup or live-memory claim. There is no representative
whole-system performance envelope yet.

## Capability review

“Checked component” means scoped evidence exists, not that every current source
revision or its deployed consumer has passed. “Draft” means implementation work
exists but the stated connection remains unqualified.

| Front | Present position | Required work still open |
|---|---|---|
| Packages and source editing | Working import/inspection/revision/browser workflow; canonical original/native source retained | Build → diagnose → repair → admit → qualify → activate from that edited revision; complete transfer/export and novice recipe tooling |
| Native authority and recovery | Substantial generated model, gate, transport, ownership and recovery checks; captured finite resident path works | Current shared request scope, closed family roles, deferred builds, source ownership, migration and all-family assembly; no blanket whole-system verification claim |
| Native development | Checked narrow definitions/fixed-simplifier-lemma construction; controlled Build service in progress | Conservative types, datatype/function/package/locale/class support, richer proofs and executable new-carrier qualification |
| Language and routing | Checked interpretation/rendering fragments and installed single-goal mathematics | Source interpretations, real cross-family/multipart routing, useful ambiguity previews, complete Oracle7 priority/guard/context behavior |
| Conversations | New native/client/protocol/facade drafts | Actual adoption, list/open/recall/expiry, browser use and restart/Forget; historical quotation versus current authority |
| Sources, relations, facts and documents | Checked kernels and importer components; original ConceptNet Scala extraction checked; native source execution in progress | Complete readers, linking/inverse/convergence behavior, 22 fact stores, retrieval/ranking/entailment, source-scale operation and resident provenance/recovery |
| Graphs | Path/checker/search/MST source and proof work; lightweight path consumer separated from heavy aggregate proof work | Fresh qualification of split graph sessions, MST optimality, indexed execution, original ConceptNet path consumer and scale measurements |
| Mathematics | Installed exact arithmetic; scoped exact/symbolic polynomial/branch/interval components; linear solver draft | Geometry/extrema/coefficient and integer/counting/modular operations; approximate evaluator; broader symbolic/system/inequality/limit/integration behavior |
| Engineering domains | Checked exact quantity/temperature/spring components; bundle success reported; service/display/source bridge drafts | Most of the 81 reviewed semantic profiles: finite probability/statistics/logic, frames, logarithmic/reference quantities, formats/calendar, versioned policies and wider physical models |
| Stateful specialists and connectors | Sensor model and inert local acquisition fixture work | Actual warehouse query/propose/confirm, computer/SSH/MCP onboarding and HTTP/MQTT/serial acquisition; fixture bytes do not constitute a working sensor |
| Composition and deployed search | Checked generic components and fixed native proof tactics; deployed ingress/recovery draft | Actual installed multi-step search; cross-package retrieval, adaptive worklist, counterexamples, conjectures, synthesis/refinement actions and scheduler/model connection |
| Growth and behavioral exams | Retained mathematical recipe/attachment and paid behavioral observer drafts | Original catalogue/toolchain and ordered-pipeline mechanisms; wider typed enumeration/library reuse; routing/interference exams and durable logical/heuristic/executable growth products |
| Diagnosis, impact and assistance | Source diagnostics and checked declaration-dependency impact through CLI/browser; search assistance draft | Actual native failure → captured source → repair → revalidation; runtime negative/ranking/session dependency impact; opt-in gap journal and example creation |
| Artifacts and author feedback | Audited intended workflows, managed artifact foundations | Editable scratch code/tests, versioned feedback policy, selected-result explanation export and local Film workflow; ordinary theory editing does not replace these |
| Refinement and performance | Real installed baseline and measurement infrastructure; graph RBT refinement draft | Useful Sepref compatibility experiment, hot-plan specialization/fusion, numerical backends, realistic throughput/tail/RSS/interference measurements and regression budgets |
| Deployment and handoff | Local standalone package/source workshop; protected failed-upgrade preservation; recipient docs | Clean complete install/rebuild/upgrade, Linux x86_64 qualification, license closure, generated API reference and independent recipient trial |
| Assurance | Meaningful checked subtheorems and finite boundary tests | Every mandatory PO-01–10 remains globally open; TB-01–05 remain globally unqualified. Current implementation connections and actual deployed consumers must close them |

The detailed denominator is [305 manifest coverage entries](../docs/coverage/README.md).
All remain `not_lifted` under the full migration completion contract. That does not
mean no implementation exists; it means no manifest's entire required migration
has been accepted as complete. The 119 classified domain manifests map to **81
reviewed profiles**. Reusing shared semantic families is essential; one independent
implementation per manifest would recreate the original duplication.

## Untouched scope now made explicit

The earlier ledger had only three `planned` tasks, hiding untouched requirements
inside broad `active` parents. The following child packages expose concrete work
without pretending the remaining parent scope is finished. Their completion
includes existing native/runtime/workbench consumers, not another component handoff.

| Task ID | Capability to carry through | Parent gates |
|---|---|---|
| `finite-probability-statistics` | Exact populations/distributions, counting, genetics cases and descriptive statistics with typed completeness | domain-families, mathematics-family |
| `literal-format-calendar-operations` | Original-byte encoding/hash/JSON/date operations and located diagnostics | domain-families, interpretation-model |
| `bounded-transcendental-models` | Error-bounded exp/log/root computations, reference levels and conditional physical models | mathematics-family, domain-families |
| `versioned-policy-evaluation` | Source-owned tables, piecewise rules, required conditions and normative rounding | domain-families, source-import |
| `sqlite-execution-observer` | Actual governed SQL execution with pinned engine, typed cells, errors, bounds and retained observation | domain-families, state-effects, source-import |
| `warehouse-site-workflow` | Snapshot query, context/freshness, reorder proposal and confirmation artifact | stateful-connectors, routing-dialogue |
| `mcp-connector-workflow` | Configure/discover/select/preview/qualify/invoke/reconcile/retire through the real executor | stateful-connectors, state-effects, workspace-client |
| `catalogue-toolchain-artifacts` | Original catalogue synthesis and editable code/test artifacts through governed workers | synthesis-growth, authoring-assistance, state-effects |
| `ordered-pipeline-synthesis` | Ordered typed pipelines, emitted programs and distinct checked versus observed guarantees | synthesis-growth, plan-composition |
| `retained-typed-program-library` | Broader bounded enumeration and durable reuse beyond the initial mathematical fragment | synthesis-growth, dependency-updates |
| `conservative-type-development` | Controlled typedef with actual witness, reconstruction and subsequent carrier qualification | native-development, native-admission, package-lifecycle |
| `adaptive-cross-capability-search` | Managed retrieval, proof/counterexample routes and retained proposals under one search budget | strategy-engine, plan-composition, synthesis-growth |

Other remaining parent requirements stay explicit: gap journaling, feedback,
explanation/Film export, further connector adapters, the remaining domain profiles,
richer native constructor packages, full routing/context behavior and performance
lowerings. The twelve children are the next useful partition, not an exhaustive
replacement for the parent acceptance lists. Three now have active implementation
owners: finite probability/statistics, versioned policies, and the MCP workflow.
Their native/runtime integration remains unqualified. The other nine children
remain planned; the table does not imply twelve completed implementations.

## How to keep broad progress coherent

1. **Finish shared consumers already being integrated.** Managed draft → native
   Build → diagnostic → retained candidate; source acquisition → typed query/domain
   result; deployed search → native evidence → restart; conversation adoption →
   historical recall. These are reusable application paths for many families.
2. **Fan out by semantic family and actual user capability.** New work can develop
   laws, algorithms and upstream regression cases independently, but must use the
   existing source, admission, execution and result interfaces. It owns the final
   consumer too. Avoid another private registry or bespoke lifecycle per family.
3. **Reduce the cost of integration itself.** Native checking is deliberately
   serialized. Recent failures include numeric representation identity across
   separately generated ML modules and unnecessary reloads of large proof parents.
   Fix the shared generator and factor proof/session dependencies once; more
   simultaneous builds would not solve either problem.
4. **Measure as capabilities arrive.** Startup is now measurable. Source-scale,
   search, evidence, growth and mixed interactive/background workloads need their
   own baselines before selecting optimizations. Keep formal checking and actual
   artifact linkage alongside these changes.
5. **Integrate and preserve usable checkpoints.** Review exact composed evidence,
   commit scoped finished work, and push it. Current draft code must not silently
   replace the last working installed generation. A green leaf never closes its
   parent workflow by itself.

## Horizon, external gaps and decisions

The core commitments above remain in scope. Six siblings—infrastructure,
trafficcop, deepspace, chameleon, vision and artist—have been inspected as
[compatibility/design pressure](../docs/review/sibling-gaps.md). Full migration
of those products is a separate D18 decision, not an unstarted core promise.

The exact missing `relations_v2.sqlite3`, `names_v1.sqlite3`, label/alias material
and unknown extraction provenance constrain original-data parity. We can build
and test readers with explicitly identified fixtures/replacements; we cannot
call such data the original snapshot. D17 governs replacements. These source gaps
must not become excuses to leave the reader platform unimplemented.

D16 governs public registry/chain and optional remote publication/media scope;
D19 governs licensing and redistribution. Local explanation/artifact workflows
remain core. Licensing preparation, platform qualification and usable deployment
are still engineering work to complete; no author contact or publication is implied.

LLVM remains exploratory, with no enabled implementation. Sepref compatibility
still needs its useful experiment. Neither name is evidence of an efficient
backend, and the project does not require every possible backend to exist.

## Evidence and navigation

- [Plan and stage gates](PLAN.md); [complete acceptance criteria](../docs/product/ACCEPTANCE.md).
- [Task ledger](tasks.json); [generated board](BOARD.md); [decisions](DECISIONS.md).
- [Mandatory metatheory and implementation connections](PROOF_OBLIGATIONS.md).
- [Source/runtime residual matrix](../docs/coverage/classification/residual-matrix.md),
  [domain profiles](../docs/coverage/classification/domain-profiles.json),
  [workbench audit](../docs/workbench/audit/README.md).
- [Validation](VALIDATION.md), [standalone checks](../tests/deployment/evidence/standalone-aae0d7dd.json),
  [recipient rehearsal](../docs/handoff/recipient-rehearsal.md).
