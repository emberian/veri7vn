# Reproductions and repair consumers

Run `.venv/bin/python -m unittest discover -s tests/regressions -v`. The original25 checks passed on2026-10-15 with SymPy1.14.0; system Python skips five math cases. These execute selected upstream components/AST bodies with local doubles, not a full application or native repair. No external service/arbitrary user program runs.

| Upstream counterexample / test | Required native consumer |
|---|---|
| `test_sqrt_negative_domain`: equiv accepts sqrt(x²)=x despite x=−2 yielding2≠−2 | Preserve real branch/interpretation; registered root operation remains absent. |
| `test_nan_and_zero_over_zero`: NaN agrees with1 | Explicit undefinedness; exact evaluator has no NaN constructor. |
| `test_precision_losing_equivalence`:1 and1+10^-20 agree under nominal10^-40 | Exact difference/error-bound operation, not float tolerance. |
| `test_small_interval_is_rejected_despite_valid_solution`: rejects x²<1/100 | Complete open interval(−1/10,1/10), interior/end/outside checks. |
| `test_parser_executes_fixed_print`: fixed print731942 executes | Inert grammar before execution. |
| `test_conflicting_boolean_plans_collapse`: True/False dedup choosesTrue | Boolean value equivalence and disagreement arbitration. |
| `test_original_rounded_cache_key_collision`:1 versus1+10^-13 collide | Operation/guard-preserving keys; routed bad-answer example remains unestablished. |
| `test_negative_edge_is_silently_omitted`: ignores B–C−2, reports4 instead of−1 | Exact edge model and appropriate algorithm/checker. |
| `test_directed_edges_accepted_as_mst`: returns3 though no directed root spans | Declared undirected model/adoption, tree/optimum witness. |
| `test_impossible_die_face_receives_positive_probability`: face7 in d6 | Validate finite event; impossible valid-model event has zero mass. |
| `test_wrapper_internal_typeerror_retries_effectful_answer`: mock effect twice | Prequalify signature; no redispatch after uncertain started effect. |
| `test_real_wrapper_preserves_decline_but_drops_typed_value` | Keep unsorted-domain decline and successful structured list across wrapper. |
| `test_literal_spaces`: quoted a b/a  b hash identically | Original bytes through cue normalization (G02). |
| `test_sql_row_prefix_loses_completion`: display20 of21 | Typed schema/order/NULL/blob/prefix/completeness/config. |
| `test_removed_sensor_can_receive_late_history`: removed config/history recreated | Binding epoch check before publication. |
| `test_disk_persistence_off_still_learns_in_memory` | Isolate primitives/library and disk during evaluation. |
| `test_timed_out_worker_still_finishes` | Cancellation/current authority before publication. |
| `test_narrowing_error_restores_old_answer` | Dependency failure cannot revive blocked answer (G04). |
| `test_context_adopts_numeric_result_before_outer_rejection` | Final N2 refusal precedes authoritative state adoption. |
| `test_multipart_reports_answered_for_incomplete_whole` | Per-part outcomes/dependency paths; license completed scope only. |

Preserve existing repairs: `test_statistics_v2_preserves_order_repair` withholds choosing12 from5 where V1 returns792. Runtime dispatch tests preserve deliberate blockers, ordinary alternative answers, disagreement/network continuation, parent-first order and successful narrowing.

## Native mathematics boundary

The registered `QualifiedExactArithmetic` accepts closed rational expressions/bounded postfix ASCII; it has no root/inequality/tolerance/equation-solving constructor. Existing proofs therefore have different consumer status:

- `real_square_branch`: sqrt(x*x)=abs x; x needs nonnegative condition. Branch theorem is not an executed root request.
- `math_eval_refinement`/`math_eval_no_value` and partial `math_equal`: undefined has no relational value. Generated `0 0 /` and managed bundle projection need actual execution evidence; current integer NL grammar does not parse this phrase.
- `within_tolerance`: exact10^-40 versus10^-20 regression; tolerance still lacks registered dispatch.
- `square_interval_complete`/`real_square_interval_complete`: all-point interval proofs; complete-set request/result still required.
- `evaluate_ascii`: inert finite grammar rejects print, distinguishes syntax/missing parameters/undefined/power bounds. It does not implement general symbolic syntax.

Current installed math evidence is indexed by [integration](integration.md); test presence, a failed combined receipt or unrelated arithmetic success cannot qualify these missing operations.

## Workbench/lifecycle evidence

`audit/workbench/check.py`/`results.json` records11 checks, including WB06 reconnect reexecution, WB07 expired follow-up and WB08 repoll stamping. WB04 rejects imported exam_log.jsonl at the filename allowlist; repeated-holdout execution is not reached there. Desired native intake policy remains `audit/workbench/transfer-regression.json`.

`test_workbench_lifecycle.py` executes original bodies with local fixtures:

| Test | Observation and repair |
|---|---|
| `test_same_cached_mqtt_event_gets_new_poll_timestamp` | Event50 recorded at polls100/200; preserve event50 and advancing receipt/poll clocks. Pure repoll theorem is not an installed connector. |
| `test_expired_reader_pronoun_bypasses_live_filter` | Cached pronoun invokes expired reader before live filter; current binding checks precede dispatch/adoption, including restored referents. |
| `test_mqtt_configuration_change_reuses_old_cached_connection` | Address-only cache ignores changed user/password; version configuration/auth epochs without exposing secrets. |

Owners: mathematics/interpretation for mathematical/literal repairs; plans for equivalence/typed data; graph/domain for models; operational/routing for arbitration/adoption; source/connectors for epochs/clocks; synthesis/package for isolation. Full live-chain entity adoption, routed cache errors, fresh evaluation and deployed connector repair remain open. D16/D17 retain publication/corpus scope.

References: [frozen resident baseline](../../tests/runtime/service/native/evidence/resident-baseline-20261016/README.md).
