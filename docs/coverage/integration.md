# Capability integration and remaining product gaps

This is a consumer map, not a migration completion certificate. The reviewed
upstream ledger still contains **305/305 `not_lifted` entries** in
[`audit/coverage/decisions.json`](../../audit/coverage/decisions.json). Its 161
relation, 22 facts, two site, one springs and 119 other manifests are a source
inventory; neither a shared class nor one native example closes their behaviors.
The denominator, absent v2 stores and available v1 replacement are explained in
[coverage](README.md). Acceptance remains [ACC-01–16](../product/ACCEPTANCE.md).

## What actually reaches a consumer

| Capability | Actual producer and consumer | Evidence level and missing product behavior |
|---|---|---|
| Exact arithmetic / literal interpretation | `Mathematics_ASCII` and mathematics bundle → protected interpreted request → `native_service.ML` → `ResidentAuthorityService.mathematicsResult` → checked HTML | Installed resident mathematics/kernel baseline has [frozen source and receipt](../../tests/runtime/service/native/evidence/resident-baseline-20261016/README.md). Current later edits require a new capture. Integer binary natural-language operations and bounded exact postfix arithmetic do not implement roots, symbolic equations, interval solutions or approximate equivalence. |
| Source acquisition / row codec | `LocalSnapshot.scala` manifest+wire → `Source_Row_Observation.acquire_native` → row kernel/admission → `row_execution.ML` | Concrete protected worker source exists; source/relation language consumer sessions await their actual steward result. No public resident source RPC, qualified result HTML or connector service registration yet. A pure codec test is not installed acquisition. |
| Relations | Retained v1 import / exact four-column rows → `query_relation_batch` and protected `relation_execution.ML` → typed relation outcome | Current source draft is connected to the real row carrier, not a Python wrapper. [Family scope](../families/relations-facts-documents.md) retains missing convergence, inverse-query limit, reader recognition/domain guards and missing original v2/name stores. No deployed relation operation yet. |
| Ordered facts / documents | `Ordered_Facts` / `Document_Quotation` → original first-match typed value or exact span | Source-backed finite instances and native statements exist; shared source/owner admission and resident operation/rendering remain joins. Three literature rules do not migrate 22 stores. Retrieval/ranking/entailment and historical scope are separate requirements. |
| Quantities / springs | `Domain_Quantities` / `Domain_Plans` → `domain_bundle.ML` → `domain_request.ML` typed conditional output | Core exact quantity proofs and plan interpreter exist; current bundle/service child repair is awaiting qualification. No resident Domain registration. [Scope](../families/domains.md): points versus deltas, units, positive stiffness and explicit ideal-model premise; spring period/frequency and wider domains remain missing. |
| Graphs | Shared `source_batch` → `Graph_Source` → `graph_dispatch` with source row ordinals | Actual pure generated-consumer tests exist under `tests/families/graphs/source`; current weighted and protected source-gate additions need their own capture. Numeric entity graph requires a full finite snapshot; weighted profile preserves explicit vertices, signed weights and row lineage. No deployed graph RPC. ConceptNet exact-label retrieval is a distinct profile. |
| Plans / search | `typed_plan_bundle` concrete row/domain interpreters preserve typed edges, guards, blocked/suspended/budget outcomes | Does not currently provide an admitted cross-family source cell→quantity conversion or protected source→graph operation. There is no honest universal value cast. Deployed multi-step discovery, retained synthesis and algorithm improvement still require actual resident consumers. |
| Dialogue / rendering | Authority `unblocked`, `render_parts`, scoped outcomes → `DialogueClient` / workbench exact-math selection | Current dialogue resident harness calls real mathematical routes; partial/multipart/source/domain resident constructors remain absent. An undefined quotient followed by an unrelated accepted sum tests independent requests, not same-request alternate reading or multipart adoption. [Harness](../../tests/language/runtime/DialogueClientChecks.scala) has these distinctions. |
| Stateful connectors | Event/receipt clocks, qualified observations, operation tickets and current authority checks | Local source fixtures and lifecycle model are not MQTT/SSH/MCP/sensor deployments. Actual adapter qualification, connector identity/configuration epochs, re-polling, interruption and forgotten derivatives need end-to-end consumers. |
| Authoring / growth / deployment | Canonical theory forms, candidate workbench and retained native/search objects have dedicated paths | Source-only authoring is runnable but does not complete imported specialist behavior, failed-build recovery, extension/search qualification, all supported-target packaging or independent recipient rehearsal. The working mathematics installation cannot stand in for those gates. |

## Cross-family acceptance harness

[`tests/integration/families/Family_Composition_Tests.thy`](../../tests/integration/families/Family_Composition_Tests.thy)
uses the actual exported definitions, not a mocked API:

1. Encode an ordered source batch, run `decode_wire_bounded`, and pass that same
   decoded object to `query_relation_batch` and `run_structured_graph_query`.
   Relation deduplication retains unique value while graph paths retain duplicate
   edge occurrences and original row keys 0→1 and 0→2. Exact byte decoding precedes
   both consumers.
2. An incomplete batch yields `Incomplete_Snapshot` and `GraphIncompleteSnapshot`;
   one positive witness cannot license uniqueness/absence or a complete graph.
3. A literal object remains a valid relation literal while the entity graph
   rejects the whole profile. It cannot drop the row to manufacture graph claims.
4. Actual `render_parts` retains accepted/needs-input/declined outcomes,
   dependencies, slots and quoted prefix scope. The same authority `unblocked`
   predicate rejects a blocked interpretation while allowing an unrelated reading.

Session `Veri7vn_Family_Composition_Tests` is queued with the sole build steward;
**no execution result is claimed yet**. Expected markers are
`INTEGRATION codec_relation_graph_composition PASS` and
`INTEGRATION language_partial_scope PASS`. These establish only generated pure
composition. They do not run resident admission, journal, RPC, final arbitration
or state adoption. The current numerical graph contract requires full snapshots;
it must not be silently replaced by a different positive-prefix graph profile.

## Concrete missing joins and owners

The shared D46 fixed operation sum remains assembly-owned, after the agreed
D43/D44 common-capture gate. Integration tests cannot fill it by constructing a
second authority or exposing raw protected source batches.

| Missing join | Required consumer and refuting case | Owner seam |
|---|---|---|
| Qualified source → graph | Add fixed graph request to the existing kernel/row instance/admission objects, carry acquisition and source conditions through native gate and resident HTML. Prefix/literal/bounds/directed-MST rejection must reach the real consumer. | source producer + graph owner + assembly |
| Qualified source → quantity | [SourceDomain wrapper](../../src/families/domains/source_bridge/README.md) is now a concrete native draft against the source-owned opaque cell signature: kernel inference for cell/unit conversion, actual Domain request, retained acquisition ancestry, conditional source views and reconstruction. Pure and actual `of_int` bundle checks are queued. Actual Common/Cell producer code and protected composition fixture now exist; native qualification, authenticated source restart and fixed resident registration remain required. NULL/REAL/wrong-unit/source invalidation/missing model cannot be relabeled an unconditional scalar. | source producer + domains + integration + assembly |
| Language → partial/refused/multipart result | Expose the fixed family outcome through the one resident result schema and workbench renderer; accept completed-part scope only, arbitrate before adopted state. | dialogue + assembly + workbench |
| Changed connector configuration | Different authentication/configuration must not silently reuse old MQTT acquisition identity; epoch-check publication and retain old event time separately from receipt/poll time. | source/stateful-connectors + operational owner |

These are actionable product blockers, not just documentary caveats. The source,
domains, graphs, plans and dialogue owners confirmed these exact absent APIs in
this integration pass. Root tracks their completion in `project/tasks.json`.

## Regression evidence

[Known defects](known-defects.md) maps upstream reproductions to actual native
repair boundaries. New local tests exercise the original MQTT branch and
Workbench pronoun dispatch, without sockets/server launch. An address-only MQTT
cache also reuses old connection configuration after username/password changes;
fixing event timestamps alone does not fix this boundary.


## Protected source → quantity implementation pass

The new [SourceDomain consumer](../../src/families/domains/source_bridge/README.md)
uses actual opaque Common/Cell producers and the existing domain interpreter.
Its [protected fixture](../../tests/integration/quantities/Source_Quantity_Protected_Tests.thy)
constructs one real Scope parent with acquisition, cell-query and domain-operation
children. Exact original metadata frames declare centimetres, stiffness and
metres; the fixture executes 100cm→1m and 3N/m×2m→6N through the actual charged
DomainWorker. Foreign parents, reported-unit relabeling, NULL/missing units,
incompatible dimensions, absent ideal model and duplicate child construction
have explicit rejection checks. Original producer/cell/parent handles can be
released while independent child consumers survive; invalidating the actual
centimetre source denies its derived targets while independent spring sources
remain available.

Constructors use the actual Common/Cell cleanup-root APIs, with short masked
publication and interruptible proof work. Independent reflected value checks
expand exact rational representations under a bounded materializer/time cap.
The full SourceDomain restart payload must retain source/cell correspondence;
serializing it as a bare Domain request would discard that authority. D67 now fixes distinct source-quantities/1 request and
source-quantities-runtime-refinement/1 output roles. The
[fixed tagged recovery proposal](../../src/families/domains/source_bridge/README.md)
is awaiting the shared recovery/assembly join.

The domain owner reports the actual bundle `of_int`/rational execution and
prepare_into rollback PASS in `06c735c6fe8317f8/81feaa2f44f44819aa79a3e1114a5e83`.
That qualifies a dependency, not this composition.

This composition is **queued, uncompiled**. It uses the real private ticket library to
model already charged commands; it does not run the resident reducer/journal.
Same-owner reconstruction consumes actual cells, actual Scope child and actual
derivative owner and checks correspondence/output substitution; it is not a
restart claim. SourceCommon currently has no authenticated restored Scope/source
association path. Recovery/source/assembly owners must connect that actual path,
including binary body/metadata originals, without replaying old tickets or
accepting stored IDs as authority. Fixed SourceDomain resident registration,
licensed rendering and installed lifecycle remain assembly joins.

The nested opaque `Q.Gate` now constructs its actual Domain gate lexically from
the same wrapper request/output. It projects the full source-qualified target,
Domain conditional display and original source views, retaining an independent
wrapper view. The protected fixture checks that release of original producer
handles preserves this view and source invalidation denies it. This new gate is
uncompiled; actual assembly-owned output/bridge lifetime and D67 tagged recovery
remain required joins.
