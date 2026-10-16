# Project board

Ledger updated: 2026-10-16.

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
| native-build-support | Extend serialized native checks for scoped implementation sessions | native build tooling | done | build_reconnected61 | — |
| native-linkage-feasibility | Resolve finite native linkage and bounded proof transport feasibility | native feasibility | done | source_reconnected61 | — |
| runtime-host-bootstrap | Probe the resident Scala/PIDE host and durable protocol seam | host feasibility | done | host_reconnected61 | — |
| coverage-disposition | Classify reachable core behavior and sibling interface pressures | coverage | done | coverage61 | — |
| native-registry | Implement native capabilities and immutable environment registry | registry | active | registry61 | — |
| operational-model | Implement and prove the executable HOL authority machine | metatheory | active | authority_reconnected61 | — |
| source-semantics | Specify source observations, adoption and query dependencies | sources | done | sources61 | — |
| interpretation-model | Specify typed interpretation and licensed rendering | language | active | language61 | — |
| workbench-audit | Audit upstream authoring, local integrations and transfer workflows | authoring discovery | done | authoring61 | — |
| performance-envelope | Establish representative workloads and deployment budgets | performance | active | performance_product61 | — |
| known-regressions | Turn reproduced Oracle7 defects into independent regression obligations | behavioral correctness | active | capability_integration61 | — |
| workspace-interaction | Design the specialist authoring and diagnosis workflows | authoring design | done | authoring61 | — |
| native-admission | Implement the authoritative native admission boundary | admission | active | admission61 | native-registry, operational-model |
| plan-composition | Implement typed composition and justified finite-search quotients | composition | active | plans_reconnected61 | operational-model, interpretation-model, native-registry |
| state-effects | Implement generated state/effect transitions and linearized execution authority | state and effects | active | effects_reconnected61 | operational-model, native-registry |
| source-import | Build reproducible snapshot import and missing-store replacement | sources | active | source_import_product61 | native-registry |
| dependency-updates | Implement dependency-aware generation publication and reuse | updates | active | updates_product61 | source-import, state-effects, native-registry |
| strategy-engine | Implement budgeted native search strategies and replayable proposals | search | active | plans_reconnected61 | plan-composition, native-admission, state-effects |
| runtime-service | Implement the Scala/PIDE host, durable writer and native protocol | runtime | active | host_reconnected61 | native-registry, native-admission, state-effects, native-resident-assembly |
| package-intake | Implement inert original/native package intake and source revision storage | packages | done | authoring61 | — |
| package-lifecycle | Implement editable packages, imports, builds and versions | packages | active | updates_product61 | native-admission, native-registry |
| workspace-client | Build the browser workbench and coherent CLI authoring surface | authoring client | active | workbench_product61 | package-lifecycle, runtime-service |
| diagnostics-repair | Provide precise counterexamples and reviewable repair proposals | diagnostics | active | diagnostics_product61 | native-admission, interpretation-model, package-lifecycle |
| staged-execution | Compile stable operations once with explicit assurance boundaries | execution | active | source_reconnected61 | native-registry, native-admission, performance-envelope |
| relation-family | Migrate relation readers, linking and guarded query behavior | relation specialists | active | facts_relations_product61 | source-import, interpretation-model, plan-composition, native-admission, staged-execution |
| facts-document-family | Migrate fact rules and source-grounded document retrieval | facts and documents | active | facts_relations_product61 | source-import, interpretation-model, native-admission, staged-execution |
| domain-families | Implement classified domain families with genuine semantic bridges | domain specialists | active | domains_reconnected61 | plan-composition, native-admission, staged-execution |
| mathematics-family | Implement mathematical capabilities with branch and precision contracts | mathematical specialists | active | mathematics_product61 | known-regressions, plan-composition, native-admission, staged-execution |
| graph-family | Implement source-dependent graph reasoning with explicit bounds | graph specialists | active | graphs_product61 | source-import, plan-composition, strategy-engine, graph-mst-optimality |
| stateful-connectors | Migrate site/session specialists and controlled local connectors | stateful specialists | active | stateful_product61 | state-effects, source-import, runtime-service |
| routing-dialogue | Implement contextual routing, ambiguity resolution and answer rendering | dialogue | active | dialogue_product61 | interpretation-model, plan-composition, runtime-service, diagnostics-repair |
| synthesis-growth | Implement retained synthesis, abstractions and admitted growth | growth | active | growth_product61 | strategy-engine, package-lifecycle, dependency-updates |
| authoring-assistance | Integrate assisted obligations, search and repair into authoring | authoring assistance | active | assistance_product61 | workspace-client, diagnostics-repair, strategy-engine, synthesis-growth |
| refinement-backends | Deliver the justified efficient backend portfolio | refinement | active | refinement_product61 | staged-execution, plan-composition, performance-envelope |
| deployment-builder | Build pinned native deployments with clean install and recovery | deployment | active | deployment_product61 | package-lifecycle, runtime-service, staged-execution, dependency-updates, performance-envelope |
| family-integration | Close behavioral coverage and cross-family execution | integration | active | capability_integration61 | relation-family, facts-document-family, domain-families, mathematics-family, graph-family, stateful-connectors, routing-dialogue, synthesis-growth, dependency-updates, known-regressions, finite-probability-statistics, literal-format-calendar-operations, bounded-transcendental-models, versioned-policy-evaluation, sqlite-execution-observer, warehouse-site-workflow, mcp-connector-workflow, catalogue-toolchain-artifacts, ordered-pipeline-synthesis, retained-typed-program-library, conservative-type-development, adaptive-cross-capability-search |
| workspace-integration | Integrate complete authoring, change and deployment workflows | integration | active | integration_fairy_astra | workspace-client, authoring-assistance, diagnostics-repair, dependency-updates, deployment-builder, stateful-connectors, deployed-search-consumer, conversation-workspace, behavioral-candidate-evaluation |
| proof-implementation-closure | Establish mandatory metatheory obligations and their runtime connections | assurance integration | active | assurance_consumers61 | family-integration, workspace-integration, refinement-backends |
| performance-hardening | Meet measured whole-system performance and resource budgets | performance integration | planned | — | family-integration, workspace-integration, refinement-backends, performance-envelope |
| release-integration | Validate the complete deployable product and release contents | release integration | planned | — | proof-implementation-closure, performance-hardening, deployment-builder, family-integration, workspace-integration |
| recipient-handoff | Prepare maintainable documentation and rehearse independent authorship | handoff | active | recipient_product61 | release-integration |
| native-recovery | Reconstruct committed native evidence and restore actual resident authority | native recovery | active | recovery_reconnected61 | native-registry, native-admission, operational-model |
| native-development | Build and admit original expert Isabelle developments through controlled native reconstruction | native development | active | native_build_product61 | native-admission, native-registry |
| native-resident-assembly | Connect resident authority, typed operation dispatch and native lifecycle | native runtime integration | active | integration_fairy_astra | operational-model, native-admission, state-effects, staged-execution, native-recovery |
| graph-mst-optimality | Prove an efficient native MST optimality certificate checker | graph specialists | active | mst_proof61 | — |
| conceptnet-source-consumer | Connect shipped ConceptNet labels, retrieval policy and provenance to checked graph queries | source-backed graph specialists | active | conceptnet_product61 | source-import, graph-family |
| installed-recipient-launcher | Ship a checkout-independent verified-inventory launcher | deployment | active | installed_launcher61 | workspace-client, deployment-builder |
| headless-runtime-closure | Qualify a smaller complete headless runtime distribution | deployment performance | active | runtime_distribution61 | performance-envelope |
| deployed-search-consumer | Connect native proof search to the deployed specialist workspace | deployed reasoning | active | search_consumer61 | strategy-engine, runtime-service, native-resident-assembly |
| conversation-workspace | Restore conversations, attributed recall and expiry through native adoption | conversation lifecycle | active | conversation_product61 | routing-dialogue, runtime-service, native-resident-assembly |
| behavioral-candidate-evaluation | Compare actual specialist candidates with the baseline before publication | candidate evaluation | active | behavioral_evaluation61 | dependency-updates, synthesis-growth, routing-dialogue, runtime-service |
| finite-probability-statistics | Implement exact finite probability and descriptive statistics | capability breadth | active | finite_probability61 | native-admission |
| literal-format-calendar-operations | Preserve literal bytes through format and calendar operations | capability breadth | planned | — | interpretation-model |
| bounded-transcendental-models | Provide error-bounded transcendental operations and model consumers | capability breadth | planned | — | native-admission |
| versioned-policy-evaluation | Execute versioned rule tables with complete policy conditions | capability breadth | active | versioned_policy61 | — |
| sqlite-execution-observer | Integrate governed SQL execution and typed bounded observations | capability breadth | planned | — | state-effects |
| warehouse-site-workflow | Deliver warehouse queries, reorder proposals and confirmation | capability breadth | planned | — | conversation-workspace |
| mcp-connector-workflow | Deliver controlled MCP onboarding, qualification and invocation | capability breadth | active | stateful_product61 | state-effects |
| catalogue-toolchain-artifacts | Restore catalogue synthesis and editable code/test artifacts | capability breadth | planned | — | state-effects |
| ordered-pipeline-synthesis | Restore ordered typed pipeline synthesis and emitted programs | capability breadth | planned | — | plan-composition |
| retained-typed-program-library | Complete bounded typed enumeration and durable program reuse | capability breadth | planned | — | dependency-updates |
| conservative-type-development | Admit conservative type developments through native construction | capability breadth | planned | — | native-development |
| adaptive-cross-capability-search | Connect adaptive cross-capability search to the modeled scheduler | capability breadth | planned | — | deployed-search-consumer |
| documentation-house-standard | Rewrite project Markdown as a concise system manual | handoff | done | root | — |

## Ready to dispatch

None.

## Coordination warnings

- possible active edit overlap: operational-model (src/isabelle/language/model/rendering/Veri7vn_Rendering.thy) / interpretation-model (src/isabelle/language/model/**)
- possible active edit overlap: operational-model (tests/language/model/rendering/Interpretation_Tests.thy) / interpretation-model (tests/language/model/**)
- possible active edit overlap: source-import (docs/sources/**) / conceptnet-source-consumer (docs/sources/conceptnet.md)
- possible active edit overlap: dependency-updates (src/isabelle/updates/**) / behavioral-candidate-evaluation (src/isabelle/updates/behavioral/**)
- possible active edit overlap: dependency-updates (tests/updates/**) / behavioral-candidate-evaluation (tests/updates/behavioral/**)
- possible active edit overlap: runtime-service (tests/runtime/service/*.scala) / diagnostics-repair (tests/runtime/service/RequestInspectionTests.scala)
- possible active edit overlap: runtime-service (tests/runtime/service/*.scala) / diagnostics-repair (tests/runtime/service/inspection.scala)
- possible active edit overlap: runtime-service (src/runtime/service/*.scala) / deployed-search-consumer (src/runtime/service/SearchIngress.scala)
- possible active edit overlap: domain-families (src/families/domains/**) / family-integration (src/families/domains/source_bridge/**)
- possible active edit overlap: domain-families (src/families/domains/**) / finite-probability-statistics (src/families/domains/finite/**)
- possible active edit overlap: domain-families (tests/families/domains/**) / finite-probability-statistics (tests/families/domains/finite/**)
- possible active edit overlap: domain-families (examples/specialists/domains/**) / finite-probability-statistics (examples/specialists/domains/finite/**)
- possible active edit overlap: domain-families (src/families/domains/**) / versioned-policy-evaluation (src/families/domains/policies/**)
- possible active edit overlap: domain-families (tests/families/domains/**) / versioned-policy-evaluation (tests/families/domains/policies/**)
- possible active edit overlap: domain-families (examples/specialists/domains/**) / versioned-policy-evaluation (examples/specialists/domains/policies/**)
- possible active edit overlap: graph-family (src/families/graphs/**) / graph-mst-optimality (src/families/graphs/soundness/Graph_MST_Optimality.thy)
- possible active edit overlap: graph-family (tests/families/graphs/**) / graph-mst-optimality (tests/families/graphs/mst/**)
- possible active edit overlap: stateful-connectors (src/connectors/**) / mcp-connector-workflow (src/connectors/mcp/**)
- possible active edit overlap: stateful-connectors (tests/connectors/**) / mcp-connector-workflow (tests/connectors/mcp/**)
- possible active edit overlap: stateful-connectors (examples/specialists/stateful/**) / mcp-connector-workflow (examples/specialists/stateful/mcp/**)
- possible active edit overlap: deployment-builder (tests/deployment/**) / installed-recipient-launcher (tests/deployment/launcher/**)
- possible active edit overlap: deployment-builder (tools/deploy/**) / headless-runtime-closure (tools/deploy/runtime_closure.py)
- possible active edit overlap: deployment-builder (tests/deployment/**) / headless-runtime-closure (tests/deployment/runtime_closure/**)
- possible active edit overlap: deployment-builder (docs/deployment/**) / headless-runtime-closure (docs/deployment/runtime-closure.md)
- native-admission: status active with unresolved dependencies: native-registry, operational-model
- plan-composition: status active with unresolved dependencies: operational-model, interpretation-model, native-registry
- state-effects: status active with unresolved dependencies: operational-model, native-registry
- source-import: status active with unresolved dependencies: native-registry
- dependency-updates: status active with unresolved dependencies: source-import, state-effects, native-registry
- strategy-engine: status active with unresolved dependencies: plan-composition, native-admission, state-effects
- runtime-service: status active with unresolved dependencies: native-registry, native-admission, state-effects, native-resident-assembly
- package-lifecycle: status active with unresolved dependencies: native-admission, native-registry
- workspace-client: status active with unresolved dependencies: package-lifecycle, runtime-service
- diagnostics-repair: status active with unresolved dependencies: native-admission, interpretation-model, package-lifecycle
- staged-execution: status active with unresolved dependencies: native-registry, native-admission, performance-envelope
- relation-family: status active with unresolved dependencies: source-import, interpretation-model, plan-composition, native-admission, staged-execution
- facts-document-family: status active with unresolved dependencies: source-import, interpretation-model, native-admission, staged-execution
- domain-families: status active with unresolved dependencies: plan-composition, native-admission, staged-execution
- mathematics-family: status active with unresolved dependencies: known-regressions, plan-composition, native-admission, staged-execution
- graph-family: status active with unresolved dependencies: source-import, plan-composition, strategy-engine, graph-mst-optimality
- stateful-connectors: status active with unresolved dependencies: state-effects, source-import, runtime-service
- routing-dialogue: status active with unresolved dependencies: interpretation-model, plan-composition, runtime-service, diagnostics-repair
- synthesis-growth: status active with unresolved dependencies: strategy-engine, package-lifecycle, dependency-updates
- authoring-assistance: status active with unresolved dependencies: workspace-client, diagnostics-repair, strategy-engine, synthesis-growth
- refinement-backends: status active with unresolved dependencies: staged-execution, plan-composition, performance-envelope
- deployment-builder: status active with unresolved dependencies: package-lifecycle, runtime-service, staged-execution, dependency-updates, performance-envelope
- family-integration: status active with unresolved dependencies: relation-family, facts-document-family, domain-families, mathematics-family, graph-family, stateful-connectors, routing-dialogue, synthesis-growth, dependency-updates, known-regressions, finite-probability-statistics, literal-format-calendar-operations, bounded-transcendental-models, versioned-policy-evaluation, sqlite-execution-observer, warehouse-site-workflow, mcp-connector-workflow, catalogue-toolchain-artifacts, ordered-pipeline-synthesis, retained-typed-program-library, conservative-type-development, adaptive-cross-capability-search
- workspace-integration: status active with unresolved dependencies: workspace-client, authoring-assistance, diagnostics-repair, dependency-updates, deployment-builder, stateful-connectors, deployed-search-consumer, conversation-workspace, behavioral-candidate-evaluation
- proof-implementation-closure: status active with unresolved dependencies: family-integration, workspace-integration, refinement-backends
- recipient-handoff: status active with unresolved dependencies: release-integration
- native-recovery: status active with unresolved dependencies: native-registry, native-admission, operational-model
- native-development: status active with unresolved dependencies: native-admission, native-registry
- native-resident-assembly: status active with unresolved dependencies: operational-model, native-admission, state-effects, staged-execution, native-recovery
- conceptnet-source-consumer: status active with unresolved dependencies: source-import, graph-family
- installed-recipient-launcher: status active with unresolved dependencies: workspace-client, deployment-builder
- headless-runtime-closure: status active with unresolved dependencies: performance-envelope
- deployed-search-consumer: status active with unresolved dependencies: strategy-engine, runtime-service, native-resident-assembly
- conversation-workspace: status active with unresolved dependencies: routing-dialogue, runtime-service, native-resident-assembly
- behavioral-candidate-evaluation: status active with unresolved dependencies: dependency-updates, synthesis-growth, routing-dialogue, runtime-service
- finite-probability-statistics: status active with unresolved dependencies: native-admission
- mcp-connector-workflow: status active with unresolved dependencies: state-effects
