# Specialist engineering environment: completion criteria

Status: **acceptance plan, not passing results**. This translates the agreed
product direction into observable completion conditions. Work packages should
link evidence to these IDs. The acceptance matrix must span the coverage families
in [the ledger](../coverage/README.md), including the existing workbench and
stateful site features. A numerical demo and a relation demo do not establish
platform completeness.

The product is a native Isabelle application with a usable authoring client and
deployable packages. Native HOL meanings remain open; operational programs,
queries, strategies and effects have explicit contracts and implementation
connections. Source import, package transfer, local integrations and retained
search are part of the product, not miscellaneous scripts left to the recipient.

| ID | Observable completion condition | Evidence required |
|---|---|---|
| ACC-01 Package ownership | A specialist package is the durable editable unit connecting meaning, language bindings, sources, implementation, examples, obligations, performance and dependencies. Novice-facing rules/formulas and native Isabelle edits operate on coherent objects. | A versioned package schema; round-trip/import/export checks; generated-file ownership rules; no lost custom edits or independently drifting contract copies. |
| ACC-02 Authoring and inspection | An author can create, modify, inspect and run each supported specialist family through documented UI/CLI workflows, with advanced HOL/ML detail available when useful. Existing Oracle7 workbench functions have explicit preserve/repair/defer decisions. | Usable editor/inspector and CLI over shared engine operations; a family-level workflow matrix; a recipient rehearsal using documentation without implementer intervention. Record unknown usability rather than counting automated tests as a person. |
| ACC-03 Diagnosis and repair | Rejection identifies the interpreted request, relevant contract, failed or unresolved condition, source/proof span and useful next actions. Counterexamples distinguish restricting a domain from changing meaning. Failed search is distinguished from refutation. | Structured diagnostics plus UI presentation; regression cases for negative-square-root branch, ambiguous entity, contradictory rows, missing assumptions and budget exhaustion. Repairs yield a new reviewable package version. |
| ACC-04 Language fidelity | Recognized language rules elaborate to typed, scoped goals with interpretation evidence; ambiguity and missing information survive to resolution. Broad-language proposals cannot bypass checks. Rendering preserves licensed structured claims. | Interpretation/renderer contracts and implementation bridge; ambiguity/paraphrase/context regressions; inspectable alternatives and coverage limits. No claim to prove a user's mental intent. |
| ACC-05 Composition | Specialists compose across quantities, queries and search without reparsing answer prose. Meaningful flags, side conditions, units, failures, conflicting answers and effects survive composition. | Composition/refinement results connected to executable APIs; regressions for Boolean-value collapse and rounded cache keys; integration scenarios across every compatible pair of family interfaces, with justified incompatibilities. |
| ACC-06 Sources and observations | Imports record retrieval/extraction policy, snapshot, transformations, license and known loss; source reports stay distinct from adopted premises. Missing/uncertain/conflicting source data remains inspectable. | Reproducible importer and source manifests; missing-v2 disposition; existence/absence/uniqueness/count/extremum cases with candidate-region dependencies. A replacement snapshot must identify itself as replacement. |
| ACC-07 Change impact | Updating a source, binding, contract, implementation or strategy identifies affected consumers and invalidates exactly what the chosen reuse guarantee permits. Running requests retain a pinned generation. | Dependency graph and update semantics; tests that insert a competing row, remove evidence, alter an assumption, change a contract and update while requests run. Whole-generation invalidation is an honest initial guarantee; selective reuse requires further evidence. |
| ACC-08 Admission and assurance | New definitions/theorems/programs are accepted only with their required theory, hypotheses, source and implementation dependencies. The actual acceptance path enforces distinctions between kernel inference, refined computation, evaluation oracle and empirical evidence. | Executable admission checks connected to formal invariants; hidden-hypothesis/oracle/axiom/context probes; invalid candidates cannot become accepted by alternate routing. No global world-fact axioms from inconsistent source rows. |
| ACC-09 Deployed reasoning | The end-user installation can orchestrate serious budgeted search: retrieval, theorem application, simplification, splitting, counterexamples, conjectures, synthesis and refinement as supported by strategy programs. | Goals requiring a multi-step strategy and cross-capability reasoning; success/failure traces; cancellation and resource measurements; end-user execution from shipped artifacts. Attaching Isabelle or replaying one fixed proof is insufficient. |
| ACC-10 Growth and reuse | Successful reasoning can retain separate logical results, search experience and executable improvements. Generalization creates an obligation; heuristic learning can improve proposals without weakening acceptance. | A persisted/reloaded result in each category; evidence of new vocabulary/abstraction or implementation admission; stale and failed candidates handled correctly; explicit relationship to existing Oracle7 learned programs and empirical template tools. |
| ACC-11 State and effects | Sessions, freshness, sensor readings, local connectors and proposed/confirmed actions have explicit authority and commit boundaries. Worker cancellation cannot publish a late effect. | Runtime enforcement and connected state/effect model; temporal/session and interruption tests; connector contract tests without contacting unrequested real services. Arbitrary ML is privileged extension code, not a sandbox for generated strategies. |
| ACC-12 Compilation and performance | Stable operations/checkers stage once; runtime profiles attribute interpretation, retrieval, search, computation, checking and rendering costs. Optimizations have stated semantic guarantees. | Reproducible workload/hardware/runtime manifest; cold/warm/admission/update time, tail latency, memory, evidence size, cancellation; measured baseline and regression budgets set from representative workloads. No unconditional claim of speedup based on toy probes. |
| ACC-13 Deployment | A new end-user environment can install and launch pinned prebuilt runtime/heaps/capabilities/indexes and use documented search and editing workflows without unexpected HOL-Analysis builds. Dependency and license closure is explicit. | Build/install manifests; clean-environment launch and capability admission checks on declared supported targets; update/recovery procedure; optional extracted runtimes declare their reduced feature envelope. Platform/OS support is a deliberate recorded decision. |
| ACC-14 Transfer and recovery | Packages can be shared and imported with inspectable provenance/dependencies; local history and source documents are not accidentally included. Failed import/build/admission preserves the existing working installation. | Transfer/import diagnostics, fault-injection recovery and generation rollback checks; source rebuild recipe and recipient-facing troubleshooting. Public/chain registry compatibility is separately decided, not silently deleted or presumed mandatory. |
| ACC-15 Behavioral migration | All manifests and reachable core/workbench operations have explicit decisions and linked evidence. Known bugs are repaired against intended contracts instead of reproduced for apparent parity. | Completed coverage ledger, upstream comparison where valid, independent property/negative cases, source-unavailable limitations, no opaque adapters counted as completed lifts. |
| ACC-16 Maintainability and handoff | The recipient can add and revise a specialist, diagnose a failure, profile it, package it and obtain useful deployed behavior without the original developers. | Versioned tutorial/reference, working examples across actual families, generated API docs, readable source, build scripts, troubleshooting and a documented recipient rehearsal. Known gaps remain in the tracker. |

The [preimplementation audit](../review/PREIMPLEMENTATION.md), G01–G08, supplies
required concrete cases for these criteria. In particular, ordinary-user candidate
artifacts and speech acts coexist with strict claim admission; imports include
original Oracle7 development material; partial/multipart outcomes retain structure;
qualification, background effects, retention and session restoration have explicit
lifecycles. The task ledger assigns their consumers and refuting checks. Source
review alone does not pass these acceptance criteria.

## Dependency order for parallel work

1. Coverage/reachability and product interaction design can proceed alongside
   package, evidence, source and effect contract work. These investigations inform
   one another; neither should wait for a large interpreter to be completed.
2. Commit shared representation and lifecycle interfaces before independent lanes
   build mutually incompatible registries, renderers, caches or acceptance paths.
3. Family implementations, authoring client, strategy engine and deployment builder
   can then proceed against those interfaces with small contract fixtures. New
   semantic requirements update the interface decision and all affected consumers.
4. Integration acceptance follows the family/feature matrix continuously. Final
   recipient rehearsal and clean-environment packaging require the integrated
   system; they are not substitutes for earlier interface tests.

## Decisions that need early evidence

- Classify the 119 domain-specific manifests and inherited runtime paths before
  choosing which operation languages and backend portfolio suffice.
- Pin the assurance profiles and how compiled execution is connected to them.
- Choose source-adoption, observation-dependency and session/effect semantics.
- Inspect and disposition workbench integrations, including external tool calls,
  local persistence, UI surfaces and optional registry behavior.
- Establish supported deployment machines, realistic memory/storage expectations,
  workload profiles and latency/resource budgets. The 1.3 GB Isabelle installer
  size is not itself a startup or query-performance measurement.

These are engineering work items. Unknown source provenance, a missing original
data snapshot and untested recipient usability must remain candidly unresolved
until evidence changes them; they should not become invented universal blockers
to implementing the rest of the platform.
