# Native source semantics

`src/isabelle/sources/semantics/Source_Semantics.thy` defines a parametric native
source model under C03/C04, D02 and PO-09. It imports only Main. It introduces no
registry, universal value carrier, oracle, axiomatization or truth authority.

Observations retain typed valid/missing/rejected readings, measured/simulated
origin, configuration/schema, sequence identity, raw reference, qualifiers and
separate event/receipt clocks. Clock bases include wall zone, monotonic origin
and source convention. `repoll_preserves_event`, `repoll_preserves_payload`,
`repoll_preserves_configuration` and `repoll_window` prove that updating receipt
time cannot refresh event-time membership or relabel historical payload/config.
`window_population` selects before `valid_values`: rejection and missingness stay
in the population even though the valid-value projection excludes them. No mean
or estimator convention is implicitly selected.

Queries use `candidates P xs`; `covers U P xs` means its set equals exactly the
specified candidate population in U. `witness_sound` needs only membership.
`covered_absence`, `covered_uniqueness`, `covered_count`, `covered_extremum` and
`covered_ranking` require coverage. Count is distinct-entity count; list order
and multiplicity remain available separately. Ranking proves completeness and
nonincreasing scores, without promising a unique tie breaker. Coverage is a
mathematical premise, not a boolean assertion issued by an external backend.

`adopted_premise meaning a` applies a domain-specific meaning to the adoption
scope, full qualifier list and valid payload. `adoption_elimination` preserves
those parameters and requires the actual premise. Missing/rejected readings
cannot supply this premise. Contradictory reports are consistent data, as
`conflicting_reports_are_consistent` demonstrates; adoption may itself impose
incompatible conditional assumptions, which no theorem here discharges.

`source_pin` includes the whole snapshot, state reads, evaluation clock and
selection/adoption policy. `whole_pin_recomputation` proves pure recomputation
agrees for equal pins; snapshot or evaluation-clock changes invalidate reuse.
The snapshot parameter must identify exact contents, schema, recipe and source
closure in the consumer. This baseline deliberately supplies no selective cache
optimization and makes no current-authority or retirement claim.

Consumer obligations remain open: importer/chunk decoding must preserve these
fields and establish collection/coverage correspondence; SQL execution is only
an external observation until its actual query implementation is linked to the
native semantics. An SQLite adapter cannot claim refinement of its query engine.
The runtime must instantiate pins with every relevant observation and enforce
current authority separately. Adoption must bind actual native premises, never
metadata IDs as evidence. These definitions/proofs do not close PO-09 or establish
a completed importer, production query path, cache instrumentation or estimator.

The scoped regression theory is `tests/sources/semantics/Source_Semantics_Tests.thy`.
Build through the shared driver with both session roots and the tests session.

`engine_observation` pins engine/version/configuration/input and keeps syntax
rejection, runtime rejection, missing input, budget exhaustion and platform
failure separate. `nullable` keeps SQL NULL distinct from those failures.
`engine_success_requires_bridge` extracts exact native row agreement only from
`native_query_agreement`, an explicit correspondence premise; an observed success
alone cannot establish it. `prefix_not_complete` rejects incomplete prefixes.

Finite policy evaluations retain supplied observations, applicable rules, checked
rules and unresolved rules. `licensed_policy_all_applicable` derives each applicable
rule only when the exact applicable population is covered, all checks hold, and no
conditions remain unresolved. Domain assumptions belong in the instantiated
`holds` judgment; this is not proof that an arbitrary external policy engine works.
Streaming regressions also exercise old-event repoll and a three-sample window
with one valid, one missing and one rejected reading.

The source-backed SQL regression at `tests/regressions/test_source_components.py`
is a future bridge consumer: its 21-row query returns a 20-row prefix in the
original implementation. The native observer must label that prefix incomplete;
prose saying “at least” cannot repair a structured completeness claim. This file
is cross-lane evidence, not an importer integration test established here.

Validation (2026-10-15, Isabelle2026-RC1, shared lock, one job/two ML threads):

```
python3 tools/dev/check-native --timeout 30 \
  --session Veri7vn_Source_Semantics_Tests \
  --session-root src/isabelle/sources/semantics \
  --session-root tests/sources/semantics
```

Passed with stable inputs. The semantic parent built in 15 seconds; the final
regression rebuild took 7 seconds (0.617 seconds cumulative theory command time),
and the subsequent cached receipt check took 5 seconds. Receipt:
`var/native-scaffold/sessions/33cc86ca692f0c81/receipt.json` (transient, uncommitted).
The initial broad `auto` proof of the first counterexample was slow; replacing it
with explicit coverage equality and transport of witness 2 preserves the statement
and makes the entire regression theory fast. Individual remaining diagnostic
simp/auto tactics have five-second native timeouts. No proof skipping is involved.
Diagnostic `writeln` output was absent from `build_log`; final success relies on
the kernel-checked theory/session build, rather than an asserted log marker.

## Concrete provenance and lifecycle consumers

`Source_Provenance.thy` supplies the concrete `source_assertion` payload: reported
value, optional rank and units, references, explicit import loss and applicability.
`qualified_source_meaning` passes all these fields to the domain interpretation;
`qualified_adoption_preserves_fields` preserves them in the exact adopted premise.
`replacement_retains_qualifiers` proves that changing the value alone cannot change
its provenance/conditions. Observation-level `qualifiers`, source/schema/config,
clock/origin and raw reference remain outside that typed payload and are retained
by the encompassing observation. A physical quantity consumer must interpret units
and applicability explicitly; a citation renderer must use retained references;
ranking must consume reported rank plus its complete candidate population. Dropping
an unavailable unit/rank to a default is not licensed by this declaration.

The local importer Manifest maps `rank`, `units`, `references`, `knownLoss` and
qualifiers/applicability into this assertion/observation split. Its Scala metadata
remains untrusted input until the native importer gate binds those exact fields
and decoded bytes to an admitted observation. The declaration above fills the
missing native semantic carrier; it does not prove that ingestion binding.

Lifecycle has a single owner, `Veri7vn_Authority`, rather than a second source
machine. Source-semantic consumption of that contract is:

| Source operation | Existing native authority consumer | Retained meaning |
|---|---|---|
| Acquire/start | `intent_permitted`, `ClaimAndStart` | Current source/target authority and request-owned attempt are required before handoff. |
| Publish new snapshot | `observation_permitted`, `StageObservation`, `RecordObservation` | Live source binding distinct from snapshot ID, exact dependent SourceObservation binding, matching confirmed request-owned attempt; retirement blocks late publication. |
| Historical source-relative computation | ordinary licensed `StageClaim` | Retiring acquisition does not rewrite retained snapshot meaning or forbid historical source claims by itself. |
| Revoke | `step s (Revoke n)`, `cancel_dependent` | Cancels dependent requests and denies current use; immutable identity grants no access. |
| Forget | `step s (Forget n)`, `RemoveManaged n` | Revokes, cancels dependent work, filters dependent source publications/bindings, and asks the managed host to remove payloads/derivatives. |
| Restore | host reconstruction of pinned metadata/native associations | Reconstructs retained state only; it does not dispatch another poll or infer forgotten content from a locator. |

The authority proof `retired_source_no_publication` directly states that a retired
source binding cannot satisfy `observation_permitted`. Retention class and policy
are explicit host inputs; no universal expiry is chosen here. The native metadata
Forget transition is not proof of physical disk erasure: the host must remove the
managed raw/decoded chunks, manifests, indices, private-derived caches/examples and
other derivatives named by the retained dependency graph. Permitted non-content
attempt/tombstone information may remain. Once required payloads are forgotten,
historical logical identity can remain but replay, byte reconstruction and fresh
execution may be unavailable; neither old pins nor raw locators authorize recovery.
The local candidate adapter propagates private retention and supplies no forgotten
locator lookup or publication bypass. Full importer/gate/host correspondence and
managed deletion qualification remain PO-09/TB-03/04 obligations.

D33 appends `Unknown_Origin` to the native origin carrier. Existing Measured and
Simulated retain their meanings. `repoll_preserves_origin`, unknown-origin import
and ingestion cases, and `unknown_qualified_adoption_fields` retain unknown origin;
`unknown_origin_cannot_be_known` forbids implicit promotion. The concrete
`qualified_observation_premise` passes the full native observation into its domain
meaning alongside every structured assertion field, so source/schema/configuration,
origin, clocks and raw reference remain available in the actual adoption judgment.
`source_rank` distinguishes named and ordinal ranks rather than coercing source
rank labels into numbers. Import acquisition requirements can demand an exact
origin; an Unknown manifest fails a Measured requirement.

`Source_Window_Coverage` makes missing or incompatible event clocks explicit:
`classify_window` returns Inside, Outside or Unclassified. The existing
`window_population` remains the exact known matching-clock selection; failure of
that predicate does not establish Outside. `window_classified` is required by
`closed_window_population` over the original, pre-filter population.
`closed_window_has_no_unclassified` licenses only that classification closure.
Full-window totals/absence require this guard plus appropriate candidate/source
coverage. Observed-window projections may retain unknown samples separately with
`unclassified_population`, their original input context and scope limitations.
This prevents an empty known selection with a vacuous materialization flag from
being strengthened into complete coverage of unknown-time source observations.
