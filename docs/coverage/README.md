# Capability coverage and migration

This ledger prevents an attractive arithmetic or relation-reader implementation
from being mistaken for completion of Oracle7. The current platform has **no
completed specialist lifts** under the proposed full package contract. Existing
IRs and Isabelle probes are partial feasibility evidence.

The [preimplementation audit](../review/PREIMPLEMENTATION.md) adds source-backed
G01–G08 interface/lifecycle requirements and a provisional partition of all 119
unclassified entries. It does not replace the reviewed migration decisions.
Coverage follows actual entry surfaces, inherited/virtual dispatch, state reads
and writes, failure/expiry/cancellation and restart behavior—not just manifests.

## Reproduce the denominator

Run `python audit/coverage/generate.py`, then
`python audit/coverage/generate.py --check`. The standard-library script reads
manifests and hashes Python files without importing upstream code. It records
the checkout revision and hashes its audit inputs. Generated output is
[inventory.json](../../audit/coverage/inventory.json); reviewed migration decisions
belong in [decisions.json](../../audit/coverage/decisions.json), which regeneration
does not overwrite.

At revision `c5d6a29d5bc5e2525078e5a53afa1abf659e4d69`:

| Source grouping | Manifests | Classification meaning |
|---|---:|---|
| RelationOrganV2 / V2G | 161 | Shared class family; individual reader/domain semantics still matter |
| FactsOrgan / FactsOrganBoundary | 22 | Ordered pattern/fact rules; boundary variant needs separate review |
| SiteOrgan / SiteOrganV3 | 2 | Stateful site queries, freshness, sessions and proposed/confirmed actions |
| SpringsOrgan | 1 | Six quantity computations; existing prototype covers only selected layers |
| Other organ classes | 119 | **Needs semantic classification**, not assumed to be arithmetic |
| Total | 305 | 124 distinct class names; neither count measures distinct capabilities |

The release hash ledger's 307 specialist folders and the 305 manifests are
different denominators: `_gate` and `_cards` have no manifest. The generated
ledger also retains all 1,757 Python file paths/hashes. Those include old folds,
training scripts, exam generators and utilities: it is **not** a claim that all
are reachable or must be translated verbatim. The 317-fold inherited runtime
needs an explicit call/override/reachability disposition beyond manifest coverage.
All 3,608 Git-index entries are also listed with their blob identity and mode,
assigned to the `coverage-disposition` work package. These include documentation,
data, tests, templates and assets. Git blob identities for LFS pointers are not
hashes of materialized payloads. Unpacked/generated data is covered by the separate
pack/store audit, not falsely described as tracked source. The current lists retain
unclassified items explicitly; the future reachability audit must update the
reviewed decisions rather than delete inconvenient entries from the denominator.

## Coverage families and completion boundaries

These are work queues, not assertions that a common implementation already
handles each family. One manifest can ultimately span several families.

| ID | Source / present evidence | Required disposition and architectural pressure |
|---|---|---|
| COV-REL | `root/specialists/rel-*`, `wander-train/general_reader_v1.py`, entity linkers, relation readers | Ordered recognition, domain/role conditions, linking ambiguity, unique/absent/multiple answers, joins; query semantics and candidate-region dependencies. Missing relation/name snapshot is explicit. |
| COV-FACT | 22 FactsOrgan-family manifests and their store modules | Ordered rule behavior, structured values versus rendered sentence, source report semantics, guards and declines; per-store provenance is not established by a common class. |
| COV-DOMAIN | 119 currently unclassified manifests, plus springs | Classify actual operations before shared abstraction selection: quantities, tables, algorithms, symbolic mathematics, interpretation/formatting, or new families. No bulk closure from matching method signatures. |
| COV-MATH | `wander-train/math_organ_v3.py`, `math_solver_v3.py`, `math_general_v1.py` and reachable predecessors | Exact/approximate distinctions, domain/branch conditions, partiality, symbolic parsing, equivalence and solver witnesses. Preserve valid behavior while explicitly repairing reproduced errors. |
| COV-COMPOSE | `specialists/_gate/network_v3.py` and gates/registries | Typed composition, consumption/history, meaningful Boolean values, search-state equivalence, conflicts, failure and budgets; replace English round trips with connected typed interfaces. |
| COV-SYNTH | `root/wander-train/code_organ_v3.py`, code chat adapters; admitted w32/w37/w482/w486 paths | Separately disposition catalogue/toolchain execution, ordered pipeline/differential samples, and bounded typed enumeration with retained programs. Preserve ordinary-user tentative artifacts, language choice and emitted-code behavior; example agreement does not establish universal equivalence. See runtime audit R4–R6. |
| COV-GRAPH | `wander-train/oracle_release_conceptnet.py`, graph stores | Relation chains and witnesses, depth/frontier bounds, provenance and uncertain source interpretation. |
| COV-ROUTE | Admitted chain from `HEAD_MANIFEST.json`, runtime superclass dependencies, `oracle7.py` | Actual reachable priority/fallback/ambiguity/context semantics, text normalization and licensed rendering. Every remaining reachable route gets a disposition; old dead code receives evidence-based exclusion. |
| COV-DOC | Runtime document/definition retrieval and installed corpus stores | Retrieval versus entailment, quotation/synthesis distinction, source spans and unknown authorship, refusal/decline behavior. Exact source selection/retrieval reachability still needs mapping. |
| COV-STATE | Warehouse specialists, runtime sessions and workbench conversations | Follow-ups, time/freshness, persisted versus ephemeral state, proposed/confirmed actions, interruption and atomic publication. Source inspection confirms these semantics are already relevant in core. |
| COV-WORKBENCH | `workbench/{cli,server,sources,sensors,mcp,exam,registry,verify}.py`, templates, static UI | Existing authoring/import/exam/inspection UX; computer/SSH/file/MCP/sensor readers, feedback adaptation, conversation specialists and package transfer are documented. Code-level coverage and enabled routes remain to audit. |
| COV-GROWTH | Empirical template/admission machinery and separate published worker; retained synthesis; disabled path-memory research | Distinguish shipped/enabled, research-only and separately published behavior. Preserve useful empirical authoring tools while adding proof-producing generalization/search. General Isabelle orchestration is a new platform requirement, not an existing Oracle7 claim. |

Paths in the table are relative to `upstream/` unless stated otherwise. Existing
audits are in `audit/results/`; this table does not upgrade a component probe into
full-runtime evidence.

## Missing data and permitted replacement

The audit records missing `relations_v2.sqlite3`, `names_v1.sqlite3`,
`linking_src/labels.tsv`, `linking_src/aliases.tsv`, and 52 manifest domain names
absent from the central registry. The v1 relation store is present but has a
different schema. The origin snapshot and extraction policy are incompletely
known. A replacement importer should record source, query/filter policy, version,
licenses, qualifiers and loss decisions. It can restore useful capability without
claiming bit-identical reconstruction of the missing release.

Unavailable source dependencies are separately reportable. They do not block
building the platform against versioned test/imported sources, and they do not
license claiming Oracle7 data parity. Never satisfy a missing source by silently
promoting example answers to ground truth.

## Closure rule

Every manifest and reachable core/workbench surface must end with an explicit
scope, migration decision and linked evidence. `preserved` and `repaired` require
an executable semantic bridge, behavioral checks, applicable assurance evidence,
and deployed execution. `opaque_adapter`, `partially_lifted`, `unavailable_source`
and `excluded_with_rationale` remain visible and never count as fully lifted.

For a repair, retain the old behavior, counterexample and intended replacement
contract. For an exclusion, explain why the code is unreachable, redundant or
outside the adopted product scope; a class being inconvenient is insufficient.
Do not use a mandatory sequence of two examples as a substitute for checking the
architecture against all these families.

## Related distributions

[distribution-recheck.json](../../audit/results/distribution-recheck.json) pins
the nine repositories searched. `oracle7-slim` is a compatibility/deployment
variant, and `oracle7-specialists` is currently an empty exchange with a README
and placeholder. Neither recovers the missing databases.

The six siblings are **compatibility investigations and future family candidates**,
not a tacit commitment to reimplement six additional products:

| Sibling | Architectural stress / potential reuse | Current evidence limit |
|---|---|---|
| infrastructure | Monitoring, forecasts, admission and effect checks | Distribution/docs inspection; no full algorithm audit |
| trafficcop | Preconditions, obligations, evidence ranking and lookahead | Same |
| deepspace | Fault diagnosis, simulation-based response choice and rule admission | Same |
| chameleon | Repository/site reconstruction and repair | Same |
| vision | Exemplar recognition and OCR | Same |
| artist | Compositional image construction | Same |

Investigate whether the capability/effect/search interfaces can express these
families. Any decision to migrate a sibling should add its own pinned inventory,
scope, obligations, performance envelope and work packages. Core sensor/site
effects already justify a real effect model without importing sibling scope.
