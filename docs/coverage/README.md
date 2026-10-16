# Capability coverage

The migration ledger is [decisions.json](../../audit/coverage/decisions.json): **305 manifests remain `not_lifted`**. Native component proofs and a working mathematics installation do not close specialist migration. Completion requires actual source behavior, semantic/runtime correspondence, qualification and deployed lifecycle evidence; see [integration](integration.md).

## Inventory and reproduction

Run `python audit/coverage/generate.py` and `python audit/coverage/generate.py --check`. The import-free generator records source hashes/revision in [inventory.json](../../audit/coverage/inventory.json); reviewed decisions survive regeneration.

Pinned revision: `c5d6a29d5bc5e2525078e5a53afa1abf659e4d69`.

| Manifest family | Count | Required semantics |
|---|---:|---|
| RelationOrganV2/V2G | 161 | Ordered readers, domain/role guards, linking ambiguity, joins, absence/unique/multiple results |
| FactsOrgan/Boundary | 22 | Ordered rules, guards/declines, structured values, original sentences, store provenance |
| SiteOrgan/V3 | 2 | Snapshot freshness, sessions, proposed/confirmed actions |
| SpringsOrgan | 1 | Six quantity operations and physical-model conditions |
| Other classes | 119 | Source-reviewed semantic profiles; classification is not implementation |
| Total | 305 | 124 class names; neither denominator counts capabilities |

There are 307 specialist folders (`_gate`/`_cards` lack manifests), 1,757 Python entries and 3,608 Git entries. The latter retain modes/blob identities; LFS pointers do not identify materialized payload bytes. The 317-fold HEAD chain needs actual C3 dispatch/helper review, separately from manifest accounting. Packs/stores have their own audit.

## Work families

Paths below are relative to `upstream/`.

| ID | Entry surface | Consumer obligations |
|---|---|---|
| COV-REL | `root/specialists/rel-*`, `wander-train/general_reader_v1.py`, linkers | Reader precedence, source/query scope, candidate-region dependencies |
| COV-FACT | FactsOrgan stores | Guarded source observations, per-store coverage |
| COV-DOMAIN | 119 profiles plus springs | Quantity/table/algorithm/model meanings and failure conventions |
| COV-MATH | `math_organ_v3.py`, `math_solver_v3.py`, `math_general_v1.py` | Branch/domain/partiality, exact versus approximate equality, complete solution witnesses |
| COV-COMPOSE | `_gate/network_v3.py` | Typed edges, meaningful Booleans, disagreement, budgets/history; no English round trips |
| COV-SYNTH | `code_organ_v3.py`, w32/w37/w482/w486 | Catalogue/toolchain, ordered sample pipeline and bounded enumeration remain distinct; tentative artifacts retain test scope |
| COV-GRAPH | `oracle_release_conceptnet.py`, stores | Path witnesses, work/frontier bounds, source provenance/model conditions |
| COV-ROUTE | HEAD, superclasses, `oracle7.py` | Actual priority/fallback/context, literal preservation, licensed rendering |
| COV-DOC | Document/definition readers, corpora | Retrieval, quotation, synthesis and entailment distinguished; original spans/authorship |
| COV-STATE | Warehouse, sessions, conversations | Freshness, persisted/ephemeral state, interruption, atomic publication |
| COV-WORKBENCH | `workbench/{cli,server,sources,sensors,mcp,exam,registry,verify}.py` | Author/import/exam/feedback/transfer workflows and enabled routes |
| COV-GROWTH | Admission, retained synthesis, research/worker paths | Separate shipped behavior, research and external worker; native engineering is a new requirement |

## Unavailable data and closure

Missing originals: `relations_v2.sqlite3`, `names_v1.sqlite3`, `linking_src/labels.tsv`, `linking_src/aliases.tsv`; 52 manifest domains also lack central registry entries. Available v1 relations have a different schema. Replacement imports need explicit source/version/query/license/qualifier/loss records, without claiming original parity.

Each manifest and reachable surface receives a scope, disposition and evidence. `preserved`/`repaired` need executable bridges and deployed evidence; `opaque_adapter`, `partially_lifted`, `unavailable_source`, `excluded_with_rationale` stay visible. Exclusions require reachability/redundancy/scope evidence. Repairs retain the reproduced counterexample and replacement contract. [G01–G08](../review/PREIMPLEMENTATION.md) govern interface/lifecycle coverage.

[Distribution audit](../../audit/results/distribution-recheck.json) covers nine repositories. `oracle7-slim` is a deployment variant; the placeholder `oracle7-specialists` exchange restores no databases. D18 siblings— infrastructure, trafficcop, deepspace, chameleon, vision, artist—are contract-stress investigations, not six additional promised migrations. Adding one requires its own inventory, scope, obligations and performance envelope.
