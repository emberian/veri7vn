# Native source semantics

[Source_Semantics](../../src/isabelle/sources/semantics/Source_Semantics.thy) is the parametric C03/C04, D02, PO-09 model. Observations retain valid/missing/rejected readings, measured/simulated/unknown origin, schema/configuration, sequence/raw references, qualifiers and separate event/receipt clocks. Clock bases include wall zone, monotonic origin and source convention.

`repoll_preserves_event/payload/configuration/origin` and `repoll_window` prevent receipt-time refresh from changing historical meaning or event-window membership. `window_population` selects before `valid_values`, retaining missing/rejected population members. No estimator convention is implied.

## Coverage and adoption

`covers U P xs` equates candidate sets with the specified population. `witness_sound` requires membership; `covered_absence`, `covered_uniqueness`, `covered_count`, `covered_extremum` and `covered_ranking` additionally require coverage. Count is distinct-entity count; ranking retains complete candidates/nonincreasing scores without a unique tie breaker. External flags cannot establish these premises.

`Source_Provenance.source_assertion` retains reported value, named/ordinal rank, units, references, known loss and applicability. Observation metadata retains origin, clocks, schema/configuration and raw reference. `qualified_observation_premise` passes both layers to the domain meaning. Adoption elimination preserves scope and every qualifier, requiring the actual premise; missing/rejected readings supply none. Conflicting reports remain consistent data. D33 unknown origin cannot become Measured implicitly; unavailable units/rank cannot become defaults.

`classify_window` returns Inside, Outside or Unclassified. Known selection is not proof of Outside for unmatched clocks. `closed_window_population` requires classification over the original prefilter population; full totals/absence also require candidate/source coverage. Unknown samples remain explicit diagnostics.

## Execution and lifecycle

Whole source pins include exact snapshot contents/schema/recipe/closure, state reads, evaluation clock and selection/adoption policy. `whole_pin_recomputation` proves equal-pin pure recomputation; selective cache reuse needs another proof.

Engine observations distinguish syntax/runtime rejection, missing input, budget exhaustion and platform failure; SQL NULL is separate. `engine_success_requires_bridge` needs `native_query_agreement` for native row correspondence. `prefix_not_complete` prevents a bounded prefix becoming complete. Policy licensing similarly needs covered applicability, successful checks and no unresolved conditions.

The sole lifecycle owner is `Veri7vn_Authority`: `intent_permitted`/`ClaimAndStart` govern acquisition; `observation_permitted`/`StageObservation` bind confirmed owner/source attempts to snapshot publication. `retired_source_no_publication` blocks late updates while retained historical snapshot computation remains possible. Revoke denies dependent use; Forget removes dependent associations and requests managed cleanup. Restore reconstructs ownership without polling again.

## Evidence and boundaries

[Source semantics tests](../../tests/sources/semantics/Source_Semantics_Tests.thy) passed under receipt `var/native-scaffold/sessions/33cc86ca692f0c81/receipt.json`. Tests include old-event repoll and valid/missing/rejected windows. The upstream 21-row/20-row-prefix SQL regression is [source characterization](../../tests/regressions/test_source_components.py), not query-engine refinement.

Importer bytes/fields/coverage, domain adoption, complete runtime pins and physical deletion require actual consumers under PO-09/TB-03/04. SQL execution remains an external observation absent its implementation bridge. Forget must release raw/decoded chunks, manifests, indexes and derived caches through their dependency owners; a metadata transition or storage receipt alone does not prove erasure. See [composition](composition.md) and [effects](effects.md).
