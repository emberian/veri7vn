# Typed composition and search

[Veri7vn_Plans](../../src/isabelle/plans/Veri7vn_Plans.thy) and `Veri7vn_Plan_Search` address C02/C03/C05 and PO-02/03/06. A finite compiled bundle supplies value/type/operation/context carriers. Nodes select installed operations, consume earlier structured results and retain conditions; rendered answers are never arguments. The actual bundle must attach admitted operations and representation bridges.

`execute_node` checks carriers, then a three-way safety guard, then the primitive. Unresolved guards block; refuted guards fail. Conflicts preserve alternative values/conditions. Effect suspension carries a proposal and causes no external effect or persistent binding.

## Equivalence and conditions

`prune_observations_coverage` preserves the exact observation image of a finite list; `finite_search_exists_preserved` preserves predicates on that image. Observations include values, context pins, guards, history, work, unresolved goals and scoped failures. Concrete projections must preserve polarity, payload, order/multiplicity/coverage and conditions. `continuation_equivalence_sound` compares only the explicitly named finite continuation list; it supplies no universal future-state equivalence.

`merge_conditions ps = rev (remdups (rev ps))` retains first occurrence order for conjunctive premise IDs. Its interpretation/count/idempotence laws do not normalize observation occurrences, values, resource consumption or history. List deduplication can be quadratic.

## Concrete source and row bundles

`Veri7vn_Source_Plans` uses actual `int source_value`, `source_operation`, `source_carrier` and `source_dispatch`. `source_node_semantics` connects each node to `source_meaning` with inherited premises; `source_guard_materialization` retains generation equality and the explicit materialization bound. `run_source_plan_refinement` equates the actual checked runner with `source_spec_plans.run_checked`, including guards, budgets, failures and transcript. The sealed generated bundle must install that callable.

Context pins retain snapshot, session, evaluation time/clock basis, policy and dependencies. `source_input_pin = RetainedSourceSnapshot nat | ReservedSourceOutput nat` distinguishes existing data from awaited acquisition. Binding acquisition supplies typed input to an unchanged query requirement; it does not fill the query's result slot.

`Veri7vn_Row_Plans` uses actual `source_batch`/`source_cell`, not integer-observation casts. `select_batch_refinement`, `row_dispatch_refinement` and `run_row_plan_refinement` connect selection, dispatch and graph execution to native meanings. `Veri7vn_Row_Slots` fixes the original predicate/conditions before acquisition. Ordered materialized-row counts preserve duplicates; distinct-row index counts are a different operation. SourceImport's reflected bulk types avoid per-row cterms and guessed snapshot IDs.

Qualified plans compose `SelectPopulation`, `ViewRows`, `SelectQualifiedRows` and `CountQualifiedRows` over actual qualified observations. `ObservedKnownSelection` computes known selected rows; `RequireClassifiedWindow` blocks with `NodeBlocked 116` when relevant event clocks are missing/incomparable. `source_population_report` retains original populations and per-window unknown diagnostics; `classification_matches_report` links the guard to that report. Classification and materialization do not establish external coverage.

D37 observed `Cell_RealBits` preserves eight binary64 bytes for encoded equality, NULL and all-row counting; unsupported integer ordering rejects. `cell_data_valid`, `rows_data_valid` and `snapshot_data_valid` express data validity independently of V1 wire ceilings. D31 supplies the shared numeric code baseline. Concrete aliases use `global_interpretation ... defines` so code generation has executable constants.

## Authority and execution

`Veri7vn_Plan_Effects.authority_proposal` produces only `StageIntent`. `permitted_intent_only_stages` requires staging permission, a permitted intent and fresh attempt/batch IDs; it yields pending persistence, not dispatch. Its closed-condition fragment is conservative and does not require proving source/model assumptions as world facts.

`Veri7vn_Row_Kernel` compiles actual acquisition and same-request query execution with shared reflected types and full stopped transcripts. Request/slot/pin, positive admitted cost and current authority must be validated before dispatch. Graph fuel and materialization cardinality bounds are not CPU, heap, metadata-size or integer-bit bounds.

## Evidence and remaining consumers

[Plan tests](../../tests/plans/Plan_Tests.thy) cover Boolean polarity, exact payloads, history and a continuation separating equal present observations. Receipt `var/native-scaffold/sessions/f9eb157c74f3f5b2/receipt.json` checked the generic graph/pruning parent and `PLANS polarity_exact_history_continuation PASS`.

Source/row fixtures cover missing observations, source-premise propagation, unknown clocks, duplicate rows, REAL bytes and malformed data. Their composed native/code-generation qualification remains separate from the generic pass. Upstream Boolean-collapse and rounded-cache regressions characterize original defects only. Final SourceImport/RowKernel callable, acquisition ownership, D34 specialization, D36 charging and resident publication still require coordinated consumer checks.
