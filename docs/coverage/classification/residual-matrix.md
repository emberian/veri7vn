# Source-family disposition and residual ownership

The pinned denominator is completely partitioned in `source-roles.json`: 1,757
Python paths and 3,608 Git entries, each in exactly one role. This is source
accounting, not native migration completion. Reproduce with
`python3 tools/audit/reachability/source_roles.py`. It imports no upstream code.
Source roles derive from exact manifest targets, imported C3 classes, reviewed
local helper closure, textual import candidates and explicitly identified tooling
paths. Evaluation filename rules classify retained development artifacts, never
prove unreachability. No entry is excluded as dead; the following residuals name
concrete operations and consumers rather than blanket “all files unknown”.

| Source role / Python paths | Reviewed route or purpose | Residual disposition / owner |
|---|---|---|
| Front door / 1 | oracle7.py HEAD resolver, actual class selection, serialized one-thread engine, CLI/HTTP/workbench entry | Native service/CLI lifecycle and clean deployment; runtime-service/deployment-builder |
| Core class dispatch /360 | 361-class C3, virtual/super/explicit-base method resolution; inner dialogue updates and outer guards | Potential dispatch, not activation; imported free-function/store semantics require family consumers; routing-dialogue/runtime-service |
| Manifest capabilities /305 | All declared kinds, acceptance/decline context, resource claims and operation roles; 119 domain profiles, relation/fact/site families retained | Each manifest is not_lifted; matching implementation classes never establish store/domain parity; family-integration and named family tasks |
| Domain local helpers /174 | Local inherited imports and policy helpers, included in 293-file text closure; byte-identical source reuse distinguished from data/config composition | Native law/refinement and composition; domain-families/interpretation-model |
| Dynamic fact stores /23 | FactsOrgan imports manifest init.store; compiles GATE/BLOCK/ASK and ordered FACTS; first matching fact wins | Versioned quoted table plus owned reader/ranking/absence guards; facts-document-family/source-import |
| Textual runtime support /309 | Import-candidate graph from current front doors/C3/manifest modules; exact targets and nonlocal names retained | Shadowing/optional imports/dynamic callbacks require target-specific consumer check, not automatic activation; routing-dialogue plus source, math, graph, synthesis owners |
| Gate composition/qualification /5 | Specialist loader/environment isolation; network typed pool/search; standing lists and empirical scoring tools | Native linking/plan semantics and empirical qualification distinct; plan-composition/package-lifecycle |
| Evaluation/development support /456 | Panels/scorers/exams/train/dev/probe tools not reached by modeled imports; scripts remain replay/exposure/qualification evidence | Retain empirical fixtures and provenance; no blanket translation or dead-code exclusion; workbench-audit/performance-hardening/synthesis-growth |
| Source build/growth development /7 | Nutrition/Python snapshot builders, dictionary catalog compiler and tool-successor development source | Import/extraction policy and actual outputs remain source-dependent, no adapter-as-lift claim; source-import/synthesis-growth |
| Nonselected optics variants /6 | V5 importsV3; retains V4/numbers-rule files without selecting them in that local parent path | Explicit historical implementation evidence, no proof of universal deadness or migration equivalence; domain-families |
| State model fixtures /2 | Warehouse site_sim_v1 scripts generate finite local warehouse snapshot | Fixture/model generation, not live warehouse integration; stateful-connectors |
| Vendored parser /58 | ANTLR distribution dependency source | Deployment/license/parser trust boundary, no owned theorem credit; deployment-builder/interpretation-model |
| Standalone relational tooling /24 | oracle_relational_v3 CLI explicitly says research runtime, relative-import successor/tool registry/corpus pipeline | Retained research/compatibility source; not the oracle7.py runtime or a silently completed native lift. Consumer/scope qualification remains source-import/relation-family |
| Workbench lifecycle surfaces /8 | server/cli/exam/sources/sensors/mcp/registry/verify; authoring audit and lifecycle matrix below | Candidate workflows, acquisition, actions, learning and package qualification; workspace-interaction/package-lifecycle/stateful-connectors |
| Author templates/examples /4 | Local author code and test inputs | Candidate development workflow, privileged execution/effect boundary; authoring-assistance |
| Research evidence /15 | sealed_history, path_memory and coverage_reader source tools | Attributable research/exposure fixtures; separate from active source helpers with same concepts; strategy-engine/synthesis-growth |

The other tracked entries are 305 capability descriptors, 973 empirical/exposure
artifacts, 274 documentation/policy/standing files, 28 data/pack paths, 16 UI/media
assets, 5 learning/policy/state snapshots, 189 reader lexicon/domain policies,
5 release/build configurations, 13 source-provenance descriptors, 6 source-table
or family configurations, 33 standalone source snapshots and 4 retained build
resources. The last four are one older astronomy descriptor and ANTLR packaging
metadata. These exact subpartitions avoid burying learned code, reader policy or
typed source records under an undifferentiated asset category. Policy/code/source
snapshots are inputs requiring qualified interpretation and lifecycle, never
serialized native theorem authority. Canonical package, source-import, strategy
and deployment owners retain those obligations. No personal data or retrieved
text was copied into this ledger.

## Materialized resources

All 14 PACK_MANIFEST payloads currently exist and match published sizes. This
tranche read SQLite schema metadata only, in read-only immutable mode. It did
**not** rehash multi-gigabyte payloads: the hashes are attributed to
`audit/results/stores.json` and PACK_MANIFEST. `tracked_data` separately records
current existence, size, container/pointer status and Git blob identity for all 28
tracked pack/tabular/database paths. Git/LFS-pointer identity is not substituted
for payload content identity. A missing compressed wrapper after unpacking is
not a missing materialized database.

The original `relations_v2.sqlite3`, `names_v1.sqlite3`, `linking_src/labels.tsv`
and `aliases.tsv` remain unavailable. Materialized relations_v1 has entity/fact
schema; it does not reconstruct the missing snapshot. Registry-domain gaps remain
per manifest. D17/source-import owns replacement source/version/filter/license and
loss accounting. This does not block model/reader development on declared test
snapshots and does not license claiming original corpus parity.

## Lifecycle and dynamic-loading matrix

| Actual source path / operation | State, failure and lifetime evidence | Preservation/repair and migration owner |
|---|---|---|
| sensors.start_all→start_poller→poll_once | Config read each iteration; sensor read then append JSONL and STATUS; missing config ends loop; errors recorded and retry after interval. Cleanup trims history only above 4 MB | Preserve source acquisition/error history, add binding epoch check before publish. Local original-body fixture demonstrates removed config/history recreated by an in-flight read; stateful-connectors/operational-model |
| sensors.MqttLast.run/read_source | Subscriber caches (receipt time,payload), reconnects on error; _MQTT keyed only by address. remove endpoint deletes config/history/specialist but does not set subscriber.stop or remove _MQTT | Explicit connection/config/auth generation and subscription cancellation; distinguish event/receipt/poll time. WB08 covers repoll stamp; no real network connection exercised |
| SensorOrgan.answer/history | Valid-reading selection and min/max/mean over retained observations; stale flag after 3 intervals; invalid latest can accompany earlier valid reading | Scoped aggregate/population coverage and freshness premises, not timeless world truth; source-semantics/stateful-connectors |
| MachineOrgan.readings | Local/SSH scan cache 20 s; configured target/credentials; failures become unreadable | Snapshot identity, receipt time and bounded external acquisition; sources are observations, scanner/parser remains owned; stateful-connectors |
| server /api/feedback→mcp.learn→exam.start_source | credit.json updates right/wrong and learned keywords, then async source requalification; files_sha excludes credit/probes/registry. route suppresses tool after>=3 wrong and wrong>right | Publish policy generation and requalification separately; empirical marks cannot admit logical meaning. WB03 plus source inspection; package-lifecycle/strategy-engine |
| mcp.Client/connect/client | Stdio subprocess+reader thread or HTTP JSON-RPC; timeout; cached schema/client by server name. reconnect closes old process, saves new config, discovers tools | Version/config association and pending call lifecycle; timeout may leave remote action unknown. No external tool/server invoked in audit; state-effects/runtime-service |
| McpOrgan.answer / qualification | schema acquisition before route; fills required arguments; tools/call can have effects. Source probes may invoke answer; lane check uses takes when present, which can still discover schema | Qualification/acquisition needs authority; discovery is not pure metadata. Pin schema and effect policy before invocation; native admission distinct from empirical ADMIT |
| exam.Loaded and _scorer | spec_from_file_location executes author module/scorer; class/init and accepted kinds from manifest; Loaded adds folder to sys.path without combo's private module snapshot | Candidate code workflow/privileged plugin boundary; native declarative admission must not inherit arbitrary code execution as proof. Track actual imports/shadowing; package-lifecycle/native-admission |
| exam.start/start_source | Daemon thread, progress map, verdict file then on_done reload. start has running guard; start_source has no equivalent guard or captured policy epoch. run_source reads actual sources | Serialize/version publication against current identity/retirement; no stale completion may reactivate authority. Source ordering reviewed; no concurrent network qualification executed |
| Workbench.reload/chat | status checks expiry/hash when loading; ordinary live filter later; cached pronoun follow-up occurs before expiry filter. Reconnect replays last 2 core questions | Preserve conversation recall as state restoration, repair execution replay and expired handle use. Existing WB06/WB07; runtime-service/package-lifecycle |
| SiteOrgan._reorder/_confirm | SQLite is opened read-only; now/freshness derive from snapshot meta; sessions and orders are in-memory. Confirmation appends requested-order artifact, not external dispatch or durable stock mutation | Source snapshot+owned query/state+candidate workflow. Do not relabel requested artifact as fulfilled external action; stateful-connectors/state-effects |
| registry fingerprint/memo/relay | Files/verdict/heldout/release fingerprints; read-only allowlisted RPC/simulation; browser wallet signs submission; registry.json records evidence | Local package/integrity artifacts retained; optional public chain remains D16. No transaction/network executed; package-lifecycle/deployment-builder |
| Local Film/code surfaces | Authoring audit maps Film plan/layers/render/export and fixed code experimentation, remote media API optional | Preserve candidate/artifact workflow; produced bytes need their own evidence, not placement metadata theorem. External publication/provider scope remains explicit |

## Three synthesis mechanisms and learning stores

1. **w32 catalogue/toolchain.** `_pick_task` chooses longest matching catalogue key;
   `_pick_language` is virtual and later overridden by w36. `_verify` writes fixed
   catalogue source, runs actual language toolchain (C compiles first, SQL uses an
   in-memory SQLite process), compares normalized-newline stdout exactly, and
   distinguishes missing toolchain, compilation, nonzero exit and timeout.
   Witness/history records are empirical. Preserve task/language selection,
   emitted artifact and exact test observation; do not replace it with one new
   enumerator. Native owner synthesis-growth, execution effect state-effects.
2. **w37 ordered pipeline.** Keyword hits sorted by position select operations;
   explicit descending removes ascending, earliest aggregate wins, domain hints
   select strings/numbers and incompatible operators block. Three fixed sample
   inputs including empty list are evaluated by internal functions; emitted
   Python/JS is run in a subprocess and compared. Preserve ordering, sample and
   language behavior. Native pipeline laws/refinement or bounded candidate/test
   scope are separate from empirical equality. No original subprocess was run in
   this tranche.
3. **w482/w486 CodeChat→code_organ_v3.** Parse literal examples; V2 removes expected
   outputs from description constants. Size-bounded typed enumeration deduplicates
   output vectors on visible cases, ranks request-word coverage and looks at most
   one size beyond first hit. Resource caps yield exhausted/no-fit, never
   impossibility. `_emit` executes rendered library-template source on every
   supplied case; keyword confidence controls learning, not theorem admission.
   `learn` appends primitive and replaces library_src[name]. `_save` writes temp
   JSON then replace, but skips existing names; `_load` compiles stored source and
   silently abandons failures. Recall recompiles/rechecks supplied examples.
   Stores therefore need source/version/dependency/exposure identity and startup
   admission, with distinct program generations rather than bare names.

w486 sets persist=False for loop-* sessions, yet CodeChat.answer still calls
in-memory learn. The new fixed local add-example fixture actually synthesizes
through the original bounded templates: disk remains absent while prims and
library_src grow. Independence requires isolation of both stores; this does not
claim a universal synthesis guarantee or execute arbitrary user code.

**Path-memory correction:** w535's research route is not in HEAD, but active w536
conditionally imports PathMemory and can consult the JSON credit store, with
min_n=4 and a Beta-style prior, to suppress low-credit routes or prefer a relation
family. NumPy/store/reader imports and conditions control activation; this audit
has not run that full path. The score is empirical policy, not source truth or
native proof. `PathMemory.build` accumulates right/wrong grades from head/family
records, so exposure lineage and replay qualification belong to strategy-engine.

No autonomous always-on growth daemon was found among the pinned public front doors and 14 background constructors. Six additional executor sites belong to
retained stage5 research/development helpers; the exact source/line/call catalog
keeps them visible for strategy-engine qualification. A separately published
worker mentioned by prior inventory/report is not supplied as executable worker
source in these roots: synthesis-growth retains a specifically unresolved
external-source/interface investigation, not an implemented daemon claim.

The six sibling products remain D18 contract-stress investigations, with their
own evidence limits in sibling-gaps.md. None of these source roles expands or
silently reduces public core scope. Native implementation/refinement/runtime
consumer checks now belong to the family/integration owners above; source
classification itself can be reviewed independently of those future repairs.
