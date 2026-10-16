# Project board

Ledger updated: 2026-10-15.

Generated from the task ledger. Edit the ledger, then regenerate this view.

Readiness is derived from completed dependencies for planned/ready tasks. Evidence references require review; path overlap warnings are advisory.

| ID | Task | Area | Status | Owner | Outstanding dependencies |
| --- | --- | --- | --- | --- | --- |
| f-project | Record project scope, decisions and integration discipline | coordination | done | root | — |
| f-contracts | Establish shared package and authority contracts with fixtures | contracts | done | contracts_scaffold | — |
| f-native | Provide isolated warm native build and boundary probes | native bootstrap | done | native_bootstrap | — |
| f-coverage | Inventory coverage and define product acceptance | coverage | done | coverage_readiness | — |
| f-tools | Provide minimal task validation and derived coordination views | coordination tooling | done | project_tools | — |
| foundation-integration | Review and integrate the parallel scaffolds | integration | done | root | — |
| design-convergence | Converge and agree the concrete implementation architecture | design integration | done | root | — |
| native-build-support | Extend serialized native checks for scoped implementation sessions | native build tooling | done | build_support61 | — |
| native-linkage-feasibility | Resolve finite native linkage and bounded proof transport feasibility | native feasibility | active | linkage61 | — |
| runtime-host-bootstrap | Probe the resident Scala/PIDE host and durable protocol seam | host feasibility | review | host61 | — |
| coverage-disposition | Classify reachable core behavior and sibling interface pressures | coverage | done | coverage61 | — |
| native-registry | Implement native capabilities and immutable environment registry | registry | active | registry61 | native-linkage-feasibility |
| operational-model | Implement and prove the executable HOL authority machine | metatheory | active | authority61 | — |
| source-semantics | Specify source observations, adoption and query dependencies | sources | active | sources61 | — |
| interpretation-model | Specify typed interpretation and licensed rendering | language | active | language61 | — |
| workbench-audit | Audit upstream authoring, local integrations and transfer workflows | authoring discovery | done | authoring61 | — |
| performance-envelope | Establish representative workloads and deployment budgets | performance | active | performance61 | — |
| known-regressions | Turn reproduced Oracle7 defects into independent regression obligations | behavioral correctness | active | coverage61 | — |
| workspace-interaction | Design the specialist authoring and diagnosis workflows | authoring design | done | authoring61 | — |
| native-admission | Implement the authoritative native admission boundary | admission | active | admission61 | native-registry, operational-model |
| plan-composition | Implement typed composition and justified finite-search quotients | composition | planned | — | operational-model, interpretation-model, native-registry |
| state-effects | Implement generated state/effect transitions and linearized execution authority | state and effects | planned | — | operational-model, native-registry |
| source-import | Build reproducible snapshot import and missing-store replacement | sources | planned | — | source-semantics, native-registry |
| dependency-updates | Implement dependency-aware generation publication and reuse | updates | planned | — | source-import, state-effects, native-registry |
| strategy-engine | Implement budgeted native search strategies and replayable proposals | search | planned | — | plan-composition, native-admission, state-effects |
| runtime-service | Implement the Scala/PIDE host, durable writer and native protocol | runtime | active | host61 | native-registry, native-admission, state-effects, runtime-host-bootstrap |
| package-intake | Implement inert original/native package intake and source revision storage | packages | active | authoring61 | — |
| package-lifecycle | Implement editable packages, imports, builds and versions | packages | planned | — | native-admission, native-registry, package-intake |
| workspace-client | Build the browser workbench and coherent CLI authoring surface | authoring client | planned | — | package-lifecycle, runtime-service |
| diagnostics-repair | Provide precise counterexamples and reviewable repair proposals | diagnostics | planned | — | native-admission, interpretation-model, package-lifecycle |
| staged-execution | Compile stable operations once with explicit assurance boundaries | execution | planned | — | native-registry, native-admission, performance-envelope |
| relation-family | Migrate relation readers, linking and guarded query behavior | relation specialists | planned | — | source-import, interpretation-model, plan-composition, native-admission, staged-execution |
| facts-document-family | Migrate fact rules and source-grounded document retrieval | facts and documents | planned | — | source-import, interpretation-model, native-admission, staged-execution |
| domain-families | Implement classified domain families with genuine semantic bridges | domain specialists | planned | — | plan-composition, native-admission, staged-execution |
| mathematics-family | Implement mathematical capabilities with branch and precision contracts | mathematical specialists | planned | — | known-regressions, plan-composition, native-admission, staged-execution |
| graph-family | Implement source-dependent graph reasoning with explicit bounds | graph specialists | planned | — | source-import, plan-composition, strategy-engine |
| stateful-connectors | Migrate site/session specialists and controlled local connectors | stateful specialists | planned | — | state-effects, source-import, runtime-service |
| routing-dialogue | Implement contextual routing, ambiguity resolution and answer rendering | dialogue | planned | — | interpretation-model, plan-composition, runtime-service, diagnostics-repair |
| synthesis-growth | Implement retained synthesis, abstractions and admitted growth | growth | planned | — | strategy-engine, package-lifecycle, dependency-updates |
| authoring-assistance | Integrate assisted obligations, search and repair into authoring | authoring assistance | planned | — | workspace-client, diagnostics-repair, strategy-engine, synthesis-growth |
| refinement-backends | Deliver the justified efficient backend portfolio | refinement | planned | — | staged-execution, plan-composition, performance-envelope |
| deployment-builder | Build pinned native deployments with clean install and recovery | deployment | planned | — | package-lifecycle, runtime-service, staged-execution, dependency-updates, performance-envelope |
| family-integration | Close behavioral coverage and cross-family execution | integration | planned | — | relation-family, facts-document-family, domain-families, mathematics-family, graph-family, stateful-connectors, routing-dialogue, synthesis-growth, dependency-updates, known-regressions |
| workspace-integration | Integrate complete authoring, change and deployment workflows | integration | planned | — | workspace-client, authoring-assistance, diagnostics-repair, dependency-updates, deployment-builder, stateful-connectors |
| proof-implementation-closure | Establish mandatory metatheory obligations and their runtime connections | assurance integration | planned | — | family-integration, workspace-integration, refinement-backends |
| performance-hardening | Meet measured whole-system performance and resource budgets | performance integration | planned | — | family-integration, workspace-integration, refinement-backends, performance-envelope |
| release-integration | Validate the complete deployable product and release contents | release integration | planned | — | proof-implementation-closure, performance-hardening, deployment-builder, family-integration, workspace-integration |
| recipient-handoff | Prepare maintainable documentation and rehearse independent authorship | handoff | planned | — | release-integration |

## Ready to dispatch

None.

## Coordination warnings

- native-registry: status active with unresolved dependencies: native-linkage-feasibility
- native-admission: status active with unresolved dependencies: native-registry, operational-model
- runtime-service: status active with unresolved dependencies: native-registry, native-admission, state-effects, runtime-host-bootstrap
