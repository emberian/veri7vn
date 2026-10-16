# Defect evidence and repair obligations

Run `.venv/bin/python -m unittest discover -s tests/regressions -v`.
On 2026-10-15 the original **25 tests passed** with SymPy 1.14.0.
These are upstream characterizations and independent counterexamples, not passing
native repair acceptance tests. Standard `python3` lacks SymPy and explicitly
skips five math checks; use the project environment for complete evidence.
No full upstream app, external service, or untrusted arbitrary program runs.
The parser probe evaluates only a fixed harmless print; timeout work is controlled
by local Events. Safe module imports, extracted original AST bodies and mocks are
identified below. Native repair evidence and remaining consumer boundaries are recorded below; the
upstream characterization suite alone does not establish a native repair.

| Case / test | Exercised old behavior and independent counterexample | Required native replacement / owner |
|---|---|---|
| Negative sqrt / `test_sqrt_negative_domain` | Actual MathOrgan.equiv accepts sqrt(x²)=x; answer ignores negative-x wording. Independent substitution x=-2 gives 2 versus -2 | Retain real-domain/branch conditions and original interpretation; mathematics-family/interpretation-model |
| NaN/0÷0 / `test_nan_and_zero_over_zero` | Actual equiv accepts NaN as equal to 1; evaluation returns SymPy NaN | Explicit undefinedness, no real equality claim; mathematics-family |
| Precision / `test_precision_losing_equivalence` | Actual solver.agree accepts 1 versus 1+10^-20 against nominal 10^-40 tolerance; exact rational difference proves discrepancy | Exact or justified error-bounded equivalence; mathematics-family |
| Interval / `test_small_interval_is_rejected_despite_valid_solution` | Actual MathOrgan rejects x²<1/100 but accepts x²<4; independent exact inequality solver yields (-1/10,1/10), membership excludes endpoints and includes 0 | Complete interval/boundary verification, not one sample; mathematics-family |
| Parser / `test_parser_executes_fixed_print` | Actual f_evaluate executes fixed print(731942) while parsing | Inert syntax and admitted semantics before effects; interpretation-model/mathematics-family |
| Boolean search / `test_conflicting_boolean_plans_collapse` | Original Network.solve receives synthetic True and False completed plans; dedup leaves answered True | Equivalence retains Boolean value and arbitrates disagreeing complete plans; plan-composition |
| Rounded cache / `test_original_rounded_cache_key_collision` | Original operation-key AST applied to 1 and 1+10^-13 collides while >1 distinguishes inputs | Cache equality implies operation/guard equivalence for profile; plan-composition. **Key collision only**, no routed bad cache answer established |
| Negative edge / `test_negative_edge_is_silently_omitted` | Original AlgorithmsOrgan omits B-C -2 then returns shortest A-C cost4; supplied graph has A-B-C cost -1 | Reject negative/malformed parsed edge model before Dijkstra; graph-family/interpretation-model |
| Directed MST / `test_directed_edges_accepted_as_mst` | Original Kruskal branch returns3 for A→B2,C→B1; independent reachability shows no directed root reaches all | Require declared undirected model or explicit adoption, retain tree witness/optimum; graph-family |
| Die face / `test_impossible_die_face_receives_positive_probability` | Actual GamesOrganV3 returns positive P(at least one7 in two d6 rolls); exhaustive36-outcome sample space contains no7 | Validate event membership in finite sample space; domain-families |
| Internal TypeError / `test_wrapper_internal_typeerror_retries_effectful_answer` | Actual _Organ.reply retries answer after internal TypeError; mock effect counter increments twice, result None | Qualify signature before invocation; failure/unknown effect cannot trigger redispatch; state-effects/operational-model |
| Wrapper data / `test_real_wrapper_preserves_decline_but_drops_typed_value` | Real manifest/_Organ/Algorithms path preserves unsorted decline; successful sort loses structured list while direct value is [1,2,3] | Preserve domain refusal; carry typed result across dispatch, not only rendering; plan-composition |
| Literal / `test_literal_spaces` | Actual FormatsOrgan returns same hash for quoted `a b`/`a  b`; hashlib of original bytes distinguishes them | Preserve original payload bytes through cue normalization; interpretation-model/domain-families (G02) |
| SQL prefix / `test_sql_row_prefix_loses_completion` | Actual bounded SqlOrgan returns 20 rows of a 21-row local recursive SELECT, prose alone says at least; independent SQLite query returns 21 | Typed order/schema/NULL/blob/prefix/completeness and backend config; source-semantics/domain-families |
| Late sensor removal / `test_removed_sensor_can_receive_late_history` | Original poll loop captures config; local mock acquisition removes temporary config/history before return; original poll_once recreates history and STATUS reports ok | Recheck binding epoch before publish; stop/release source handles separately; stateful-connectors/operational-model |
| In-memory learning / `test_disk_persistence_off_still_learns_in_memory` | Actual CodeChat composes fixed add examples with persist=False; disk absent but prims/library_src grow | Isolate in-memory learning/exposure as well as persistent store during independent evaluation; synthesis-growth/package-lifecycle |
| Timeout / `test_timed_out_worker_still_finishes` | Original w480 _run returns None before controlled worker finishes; release Event lets it complete | Cancellation and current authority checked before state/effect publication; runtime-service/operational-model |
| Narrowed fallback error / `test_narrowing_error_restores_old_answer` | Original w525.chat with mock parent and narrowed-silent condition restores suppressed answer when family loading raises; corresponding no-error test withholds | Dependency failure cannot resurrect suppressed authority; routing-dialogue/operational-model (G04) |
| Context before guard / `test_context_adopts_numeric_result_before_outer_rejection` | Actual w529.chat, chat_context_v2.update/state and w540 guard execute with mock numeric parent and inert entity readers. Final result withheld by N2 but session result=(0,'') and question already adopted | Final arbitration before adopted result/referent state; transcript may record attempted turn separately; operational-model/routing-dialogue (G04/G07) |
| Multipart / `test_multipart_reports_answered_for_incomplete_whole` | Actual w533.chat with one answered and one withheld mocked part produces status answered, path 1-of-2; second part loses original dependency path/status | Preserve partial display, each typed outcome and blocker, license only completed-part scope; interpretation-model/routing-dialogue |

Existing statistics repair: `test_statistics_v2_preserves_order_repair` exercises
V1 returning 792 for choosing 12 from 5 and V2 correctly withholding as impossible.
Preserve V2 argument-role/domain checking during native migration.

Other preservation checks in `test_runtime_dispatch.py`: deliberate validity
blocker prevents family/network fallback; ordinary unscoped withholding permits a
different family answer; family disagreement permits network; parent executes
before fallback; narrowing without error withholds. These preserve useful scoped
behavior while repairs above close specific leaks.

`test_math_components.py` imports only individual math/network components and
supplies synthetic planner expansions; it is not an end-to-end routing benchmark.
`test_source_components.py` imports dataformats/SQL components and evaluates one
original AST key. `test_runtime_dispatch.py` extracts the named definitions and
uses explicit local dependency doubles; all reported guard/update bodies really
execute. It does not prove the full 361-class runtime activates the supplied
mock responses or mocked store failures on a natural-language request.
Historical `audit/results/components.json` remains unchanged and now has fresh
independent regression checks for its mathematical, timeout and Boolean cases.

Eleven separately owned workbench checks in `audit/workbench/check.py` and
`results.json` cover WB06 reconnect reexecution, WB07 expired follow-up, WB08
repolled event stamped with poll time, and additional author workflows. WB04
**rejects imported exam_log.jsonl at the filename allowlist**, before extraction
and re-exam. The earlier repeated-holdout narrative is not reached on that actual
route. The desired native intake/exposure policy is retained separately in
`audit/workbench/transfer-regression.json`, with its missing native consumer.

Remaining distinctions: numeric adopted state has been reproduced in the scoped
composition above; arbitrary entity referent adoption through the entire live
chain has not. No full routed cache-error example, persistence/learning isolation
qualification or fresh recipient evaluation is claimed. Native mathematics
component evidence is scoped in the review below; it does not close the broad
known-regressions task. Corpus replacement and external-publication scope remain D17/D16.


## Native mathematics consumer review (2026-10-15)

This review follows `Mathematics_Exact`, `Mathematics_ASCII`,
`Mathematics_Real_Guards`, `Mathematics_Solutions`, the exact tests, and the
`mathematics_bundle.ML` decoder/dispatcher. It does not count a theorem name or an
export declaration as execution. The sole registered bundle operation is
`QualifiedExactArithmetic`; its accepted requests are closed rational expression
or bounded postfix ASCII evaluation. The expression datatype has no square root,
inequality, tolerance, or equation-solver constructor.

| Reproduced defect | Existing native statement and executed-path boundary | Remaining acceptance consumer |
|---|---|---|
| Negative `sqrt(x²)` | `real_square_branch` returns `Some (abs x)` for every real x; identity requires nonnegative x. Rational witness tests separately reject -2 and accept 2. These are branch proofs, not an executed root request. | Interpretation must retain the negative-domain premise, select an admitted root operation, and return 2 for x=-2; reject the unrestricted identity. No such registered operation exists yet. |
| 0/0 and NaN equivalence | `math_eval_refinement` and `math_eval_no_value` connect explicit `None` to absence of a relational value. `math_equal` returns `None` for undefined operands. Exact tests invoke generated `evaluate_ascii` on `0 0 /`; bundle tests exercise prepare/execute/project and `Undefined_Arithmetic` view, pending bundle qualification. | Run the checked bundle path, including nested undefined operands and typed output. Natural-language `evaluate 0/0` is not provided by the current integer binary phrase grammar. There is no NaN rational constructor and no blanket repair claim for external engine NaN. |
| Precision-losing agreement | `within_tolerance` compares exact rational differences; exact tests invoke its generated code at 10^-40 versus difference 10^-20. Bundle rational views retain signed numerator and positive denominator. | Bundle exact-pair regressions can establish preserved distinction. Agreement/tolerance is not a registered operation, so dispatch-level agreement repair remains open. |
| Small interval | `square_interval_complete` and `real_square_interval_complete` cover every point under a positive radius; endpoint and zero lemmas cover radius 1/10. | Add actual inequality request/complete-set result and retain strict endpoints -1/10 and 1/10, zero interior, and outside point 1/5. Candidate membership alone is insufficient. |
| Parser effects | Generated `evaluate_ascii` tests reject the fixed print bytes and distinguish missing parameters, syntax, undefined arithmetic and power bound. Its grammar is inert integer postfix arithmetic. Bundle source routes bytes through that same generated dispatch. | Qualify bundle execution and byte-to-output tests, including signs and malformed powers. This is a scoped grammar replacement; it does not implement general upstream symbolic syntax or establish full interpretation/routing repair. |

The current bundle tests also cover release/ownership and bounded projection,
which matter when an exact result reaches a runtime consumer. Root and interval
proofs cannot be smuggled into this path by testing an unrelated arithmetic
expression. Similarly, a generated tolerance helper is not evidence that planner
agreement calls it.

Historical verification receipt `var/native-scaffold/sessions/f6f61c21e18caa0d/receipt.json`
is **overall failed** in `Veri7vn_Natural_Mathematics`; it is not a green combined
qualification. The mathematics owner reports the mathematics test session passed
in an earlier attempt under that directory, whose build log was overwritten by a
retry. Independent cached marker extraction is requested before treating that
reported execution as durable regression evidence. Bundle tests have not yet
been independently built in this review; frozen native inputs remain unchanged.


## Integration-pass lifecycle regressions

`tests/regressions/test_workbench_lifecycle.py` now executes three additional
original-body characterizations without importing/launching the server or MQTT
client. `selected` compiles the original named AST bodies; dependencies are local
clock/store/client fixtures, explicitly not native repaired implementations.

| Test | Executed evidence | Required actual repair consumer |
|---|---|---|
| `test_same_cached_mqtt_event_gets_new_poll_timestamp` | Actual `read_source` MQTT branch consumes one cached `(event_time=50,payload)` twice; actual `poll_once` stores `t=100` then `t=200` with identical source description/value. No socket/client is instantiated. | Source acquisition must retain event time50 while receipt times advance. `Source_Semantics.repoll` already states this pure property; it does not install an MQTT connector. Actual acquired metadata, freshness query and returned result must consume the separated clocks. |
| `test_expired_reader_pronoun_bypasses_live_filter` | Actual `Workbench.chat` invokes expired reader after pronoun substitution before constructing the live-reader filter; result is `answered` with a followup path. Local reader returns a fixed answer; full server routing is not claimed. | Check current source binding/lease/expiry before dispatch and before final answer adoption, including restored referents. Dialogue/workbench owner retains this requirement; no source resident followup constructor yet. |
| `test_mqtt_configuration_change_reuses_old_cached_connection` | Actual `read_source` returns identical cached data for changed user/password because `_MQTT` is keyed only by address. There is no new network connection. | Source/stateful-connectors owner: versioned configuration/binding epoch and adapter requalification; old cached observations retain their original config. Raw secret credentials must not appear in public IDs/receipts. |

Verification: `.venv/bin/python -m unittest discover -s tests/regressions -v`
passed all **28 tests** in 2.323s after the final configuration case. These
executions are counterexamples to upstream, not repair qualification. No native/Scala/runtime build was launched by this
lane. Native composition and scoped partial/refusal acceptance are queued separately
in [integration.md](integration.md), with their real consumer boundaries.


The older failed mathematics receipt above is not the current whole-runtime
status. A later [frozen resident baseline](../../tests/runtime/service/native/evidence/resident-baseline-20261016/README.md)
records native attempt `6c1269b0971d4e5cb7f5074b6d0bd883` and host attempt
`e8efa7e5fae14a66a647e8c7be3becf6` passing the actual mathematical execution,
publication, recovery and ownership path. This establishes that such a resident
path runs; it does not establish every negative regression in this document.
The new zero-denominator dialogue scenario is in
`tests/language/runtime/DialogueClientChecks.scala` and still needs its own
post-change runtime receipt. Square-root, interval and dispatch-level tolerance
operations remain absent, as identified in the consumer review.
