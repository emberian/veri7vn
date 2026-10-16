# Typed plan composition and finite search

Work in progress for C02/C03/C05 and PO-02/03/06. The generic theories are
`src/isabelle/plans/Veri7vn_Plans.thy` and `Veri7vn_Plan_Search.thy`.
The concrete source-family adapter is in `src/isabelle/plans/source/`; no
completed native deployment is claimed by the generic locale.

## Typed graph

A node selects an operation from the installed finite signature, names earlier
node results, and retains source/model premise identifiers. Its arguments are
structured values, never reparsed rendered answers. `elaborate_plan` rejects
forward/dangling references, duplicate node identifiers and mismatched argument
carriers. `typed_plan` is the corresponding independent inductive judgment.
`elaboration_sound` and `elaboration_complete` relate them;
`elaboration_composition` states the exact intermediate type environment for
concatenation. Cross-profile conversion must itself be a linked operation.

The value, type, operation and request-context carriers are parameters of one
finite compiled bundle. This is not a closed universal HOL value language.
Semantic native carriers remain open. The concrete generated adapter must bind
these parameters to actual admitted operations and representation bridges;
merely satisfying the type checker does not establish a domain theorem.

`execute_node` checks argument carriers, then a three-way runtime safety guard,
then invokes the primitive. An unresolved guard yields `NodeBlocked` and a
refuted guard yields `NodeFailure`. `guard_before_primitive` establishes that a
returned value requires an established guard. `computed_node_typed` establishes
its output carrier and preservation of local premises.
`inherited_conditions_retained` states the exact first-occurrence normalization of
local premises and all input conditions, and dependent environments carry those
conditions. `condition_meaning_preserved` preserves `list_all meaning` for any
premise interpretation; `inherited_condition_set_preserved` retains exactly the
union of local and inherited conditions. Those source/model premises
are independent of the execution guard: safe computation can yield a conditional
value without pretending the source premise was discharged. Guard and primitive
functions are installed bundle definitions, not proposal-supplied callbacks.

Conflicts retain all alternative values and their premises. Suspended effects
carry their proposal plus premises and create no effect or persistent binding.
Failures and missing dependencies remain per node; independent later nodes can
continue. `execute_plan_preserves_parts` retains every node identifier including
budget-exhausted parts. The fuel is a modeled per-node work bound, not a wall-time
or process-memory guarantee. `run_checked` is the checked entry point;
`checked_run_has_typed_graph` connects successful entry to the typing judgment.
The native admission gate and generated authority machine remain responsible for
licensed claims, effects and commits.

## Search observations

`prune_observations` retains one representative per **exact** observation.
`prune_observations_coverage` proves equality of the image of the original finite
candidate list and its pruned list; `finite_search_exists_preserved` preserves
any predicate on those observations. No claim extends to candidates absent from
that list, arbitrary search depth or unlisted budgets.

`search_observation` explicitly retains values, pinned request context, guard
observations, history, consumed/remaining work, unresolved subgoals and scoped
failures. The concrete value carrier must retain polarity, exact payloads,
collection order/multiplicity/coverage, domain distinctions and claim conditions.
An incomplete projection that erases any relevant field is not licensed by the
record's existence or the generic theorem.

Live-state pruning needs future behavior as well as current observation.
`continuation_key` adds the result of each continuation in a named finite list;
`continuation_equivalence_sound` proves equality for each listed continuation.
`finite_continuation_pruning` preserves that whole key. This deliberately does
not establish equivalence for unlisted continuations. No more aggressive resource
subsumption, example-based program equivalence, rounded cache key or specialization
rule is enabled here.

## Checks and open connections

`tests/plans/Plan_Tests.thy` contains repaired native fixtures for Boolean polarity,
exact structured payloads, resource history and a continuation that separates
states with equal current observations. Original-source Boolean-collapse and
rounded-cache collisions remain independent counterexamples in
`tests/regressions/`; reproducing a defect is not validation of its replacement.

The generic check passed on 2026-10-15 with stable receipt
`var/native-scaffold/sessions/f9eb157c74f3f5b2/receipt.json` and generated marker
`PLANS polarity_exact_history_continuation PASS`. The final child build took
13 seconds (theory 0.423 seconds), reusing the successfully built generic parent
(16 seconds; search theory 2.025 seconds, graph theory 7.322 seconds). Earlier
failed attempts repaired cross-session qualification, a reserved-word induction
argument, image membership reasoning and an unconstrained numeral fixture; a
30-second attempt timed out before test heap completion. Those attempts are not
passing receipts. The completed generic parent includes condition normalization,
meaning/set/count/idempotence proofs and the guarded graph/pruning theorems.
Concrete
source-family instantiation, generated callable association, native guard
licensing, authority-event suspension, registry pin integration and a real runtime
consumer remain explicit integration gates. Full domain migrations (affine/log,
frames, SQL, symbolic and artifact carriers) remain separate required consumers;
the generic parameters do not claim those migrations exist.

## Concrete source-family consumer

`Veri7vn_Source_Plans` instantiates the graph with `int source_value`,
`source_operation`, `source_carrier` and the actual `source_dispatch` from
`Veri7vn_Execution_Core`. `source_node_semantics` connects each computed graph
node to `source_meaning` and proves exact inherited-premise preservation.
`source_guard_materialization` proves that an established guard retains equal
executable generations and the explicit materialization bound. It consumes the
family's actual `source_materialization_guard`; native executable identity and
admission still belong to the sealed staging wrapper, not numeric pin equality.

The source-plan request context retains executable generations, source snapshot,
session state, evaluation time with `clock_basis`, policy and dependency pins.
Snapshot/state/policy identifiers are retained observations, not native evidence.
Every source result is scoped to the supplied observed population and selected
plan. Count retains multiplicity; it does not claim a complete external population,
world-source truth or an optimum. Valid extraction intentionally omits Missing and
Rejected payloads while selection preserves those observations.

`run_source_plan` is the fixed generated graph entry. The final staged execution
session owns its sealed native callable, compiling it together with the source
family's packet constructors and dispatcher in one unit. This avoids attempting
to transfer datatype values between independently generated ML units. New graphs
over the existing signature are data for that entry; no per-graph compilation is
needed. The graph test's code antiquotation returns only a Boolean test verdict
across its own compilation boundary, never generated packet values.

`tests/plans/source/Source_Plan_Tests.thy` uses a nonempty population containing a
valid integer and a missing observation. Its generated three-node graph selects
both observations, extracts the valid integer and counts one valid payload;
source premises propagate through each edge. Wrong-carrier consumption is rejected
by elaboration and stale generation is rejected before source dispatch.

Executed independent source-characterization checks on 2026-10-15: system Python
`test_source_components.py` passed all three tests (including actual upstream
rounded-key collision); `test_math_components.py` passed the Boolean-collapse
counterexample with five unrelated SymPy tests skipped. These characterize original
defects; native replacement checks await a successful completed serialized Isabelle receipt.

The whole checked-graph relation is `run_source_plan_refinement`: the actual
entry returns the same total transcript as `source_spec_plans.run_checked`,
whose primitive uses `source_meaning`. It follows from the extensional equality
`source_plan_primitive_refinement` and reuses the same elaborator, guard,
failure/budget behavior and premise propagation. Its assumptions are exactly the
native source-family refinement equations and the selected Isabelle code boundary;
it does not convert source reports to world truth.

`plans/effects/Veri7vn_Plan_Effects.thy` connects typed suspension data to the
actual authority model. `authority_proposal` can propose only `StageIntent`,
retaining the exact intent. `unresolved_effect_conditions_block` rejects submission
when unresolved premise identifiers remain; this adapter cannot discharge them.
`proposed_intent_still_checked`
shows current authority rejects unavailable staging, disallowed intent or repeated
attempts. `permitted_intent_only_stages` requires `can_stage`, `intent_permitted`,
fresh attempt and unused batch identifiers, and yields only a pending durable
batch plus `Persist`. Actual execution remains the separate `DurableAck` /
`ClaimAndStart` / host handoff. This adapter is not yet a concrete migrated
effect-family primitive or runtime consumer.

The effect adapter currently supports a conservative closed-condition fragment.
Blocking its nonempty condition list is not an assertion that every source/model
premise is a runtime safety guard or must be proved as external-world truth. A
future native effect policy may explicitly adopt source/model assumptions while
checking its real executor preconditions. That requires an actual effect-family
bridge and an inspectable policy, and is not implemented by this adapter. Pure
source computations continue to retain conditional premises independently of
runtime applicability guards.

## Assumption representation and acquisition boundary

Root approved normalization of conjunctive premise identifiers on 2026-10-15.
`merge_conditions ps = rev (remdups (rev ps))` retains first occurrence order;
plain Isabelle `remdups` retains last occurrence order. `normalized_condition_count`
is the cardinality of the distinct identifier set. This prevents repeated graph
edges from accumulating exponentially many copies of the same assumptions.
It does not normalize observation/value collections, occurrence provenance,
resource use or effect history. The premise interpretation theorem is generic;
actual native meanings are still attached by the registry/admission bridge.

This is not a deployment complexity bound. List-based `remdups` can use quadratic
identifier comparisons in the concatenated local/input list. Native framing and
materialization limits remain necessary; shared condition sets or DAG-backed
assumption references are a future representation refinement with its own bridge
and measurement obligation. Root tracks that requirement rather than treating
normalization as a finished performance result.

The current source graph consumes an already-known retained snapshot. It is not
an acquisition plan whose future output target/snapshot could be preassigned.
Acquisition continuation design is being coordinated with authority: a real
returned observation must be registered and bound with its native typed evidence
before dependent source computation consumes it. The intended continuation retains the original request/goal IDs and graph,
lineage, budget and history. A one-shot native BindOutput association specializes
its immutable requirement and output slot with the actual returned snapshot; it
cannot replay a completed effect, replace the requested query or create a new
request as a workaround.
No acquisition-resume implementation is claimed here.

## Actual imported-row family and requested-query specialization

`plans/rows/Veri7vn_Row_Plans.thy` consumes the actual `source_batch` and
`source_cell` from `Veri7vn_Source_Import.Source_Row_Import`. These are an
additional finite static family, not casts of integer observations. Predicates
are declarative exact encoded-cell equality, NULL recognition, exact signed-
integer lower bounds and conjunction. Invalid columns/literal encodings are
rejected before dispatch. Selection preserves schema, row order, duplicates,
NULL/blob/text payloads and the source-declared complete-materialization flag.
That flag is retained source scope, not independently proved external coverage.
Count is exact over the supplied materialized rows with multiplicity.

`select_batch_refinement` relates actual selection to `row_index`;
`row_dispatch_refinement` and `run_row_plan_refinement` relate the actual family
and total graph to native row meanings. `Veri7vn_Row_Slots` retains an immutable
`row_query_requirement` (predicate and conditions), whose reserved typed graph
selects then counts. `row_query_native_specialization` binds the acquired batch
argument to the **same** requested meaning. `specialized_row_query_exact_result`
names the selected rows, exact count, retained source scope and normalized
conditions under actual schema/generation/materialization guards. It does not
accept an arbitrary returned theorem about another predicate.

The actual acquisition association is owned by admission/authority: exact
attempt, input, output, native profile and approved code context must be bound
before one-shot slot specialization. SourceImport's `code_reflect` mapping is
the typed bulk bridge; per-row cterm serialization and new guessed snapshot IDs
are not implementation paths. The row family and its slot proofs are currently
unbuilt sources pending source-import qualification and a serialized check.
The row test generates an actual imported-type query/count with duplicate rows,
NULL/blob cells and incomplete source scope; out-of-schema predicates reject.

Temporal windows require actual typed event/clock metadata. Sources owns
`source_batch observation` attachment/flattening laws; no timestamp column or
integer-observation conversion is inferred from generic rows. Mixed schemas and
missing/rejected observations require explicit scope/compatibility handling.
That continuation/bundle integration remains open.

The qualified-row signature now composes `SelectPopulation observation_plan`,
`ViewRows schema columns`, `SelectQualifiedRows predicate` and
`CountQualifiedRows`. Its input is the actual
`source_batch source_assertion observation list`. View and count results retain
the entire `source_row_view`, including original selected population, rank/units/
references/import loss, schema and materialization scope. Query changes only the
view's selected row list. Missing/rejected inputs remain in population and cannot
produce a fully materialized view; schema/width incompatibility blocks dispatch.
`acquired_query_native_specialization` binds the actual typed observations to the
same immutable population/window/schema/predicate/condition requirement. The
four-node generated fixture includes a complete returned batch plus a missing
observation, so its false materialization status is caused by missing input,
while duplicate matching rows are retained and counted exactly.

These row/window sources still await source-import/native compilation and the
shared D31 numeric code baseline. The generic passing receipt does not cover
unimported nested source/row/effect sessions or qualify the final callable.

## Window classification and requested scope

Root approved the immutable `population_policy` distinction after finding that
filtering out an unknown clock could otherwise look like known absence.
`ObservedKnownSelection` may compute the exact known selected population;
`RequireClassifiedWindow` blocks with `NodeBlocked 116` when relevant observations
have missing or incomparable event clocks. Classification alone does not prove
complete external-world/source extent, and source materialization scope remains
separate.

`Veri7vn_Row_Population` builds `source_population_report` with the original
population, known selection, aggregate unclassified observations and each nested
window's actual prefilter population/unknown diagnostics. Its known projection
refines `observation_meaning`; `classification_matches_report` connects the
lighter guard computation to the exact unknown report. No `filter False` is
reinterpreted as proved outside-window membership. `ViewRows` consumes that
report and fills the source view's original/unclassified/diagnostic fields;
query and count preserve those fields. The requested population policy is part
of the same immutable `acquired_row_requirement` used in specialization.

The generated regression `unknown_window_fixture` contrasts two requests over
an observation with no event clock: known selection gives zero but retains the
original and unclassified observation, whereas classified-window policy blocks
and dependent nodes remain blocked. The selected empty list's materialization
flag is deliberately true in the first case; it is never used to infer complete
window absence. These concrete tests are frozen pending the coordinated native
RowKernel/SourceAdmission build.

Externally awaited acquisition output and final query result remain distinct
slots. Binding a real acquired batch supplies typed input to the unchanged query
requirement; it does not fill that query's result slot. The actual generated
query/refinement must produce the final result. A valid acquisition followed by
a blocked query can retain source evidence while leaving its final count unbound.
Internal graph nodes require no separate metadata theorem/cterm per row or node.

## Input pins and observed REAL domains

D34's pin addendum replaces an unconditionally numeric snapshot field with
`source_input_pin = RetainedSourceSnapshot nat | ReservedSourceOutput nat`.
The `pinned_source_snapshot` field name is retained for migration, but its type
makes a reserved input explicitly different from a real retained snapshot.
The original context remains immutable. Only the native gate and generated slot
ledger bind a reserved slot to its actual typed output; the slot identifier is
not cast into an output/snapshot identifier. Execution/cache licensing must use
the resolved native association and current dependencies as well as the pinned
executable. The pure fixtures' numeric tags confer no authority.

D37 adds actual observed `Cell_RealBits` binary64 encodings to SourceImport.
The row family preserves those eight bytes and supports explicit encoded-cell
equality, NULL recognition and all-row counting. That is neither SQL numeric
equality nor an admitted real ordering implementation. Integer predicates now
require `row_predicate_applicable` over the actual rows: integer cells and NULL
have the declared integer-filter semantics, whereas REAL/text/blob cells block
the numeric invocation instead of silently becoming false matches.
`real_integer_order_unavailable` states this exclusion. Conjunction checks both
predicates conservatively; authors can explicitly select a supported typed
subpopulation before ordering it. General REAL numeric semantics/refinement
remain required migration work. The generated REAL fixture checks byte equality
and refusal of unsupported integer ordering, pending the shared native build.

## Concrete integration consumers

The staged-execution owner consumes `Veri7vn_Row_Slots` in
`src/isabelle/execution/row_kernel/Veri7vn_Row_Kernel.thy`. That pure generated unit
reuses SourceImport's reflected batch/cell types, compiles actual acquisition plus
same-request query execution, and retains full stopped transcripts rather than
reducing an upstream policy blocker to the last node's missing-dependency code.
Its final-count extraction preserves the full view on success. The source-specific
admission child owns opaque accepted input/output association; the final execution
wrapper owns the managed typed result. These are explicit consumers in progress,
not a claim that the pending integration checks have passed.

The deployed controller must charge actual admitted operation profiles and allocate
real run/job reservations before dispatch (D36). Four graph nodes are only modeled
fuel, not a resource currency supplied by a caller. The row context's materialization
limit bounds selected-list cardinalities, not metadata bytes, AST depth, integer
bit weight, retained provenance/trace weight or OS resource use. Immutable query/
context decoding and source raw/manifest framing require their actual native byte,
node and depth guards before constructing generated values. Search/learning state
is outside this pure row interpreter; future strategy consumers must fork actual
isolated learning state under the effects owner's reservation mechanism.

SourceImport's V2 streaming/index work separates generic data validity from V1
format ceilings. The row consumer now uses `cell_data_valid`, `rows_data_valid`
and `snapshot_data_valid` for exact byte validity, row width and REAL-eight-byte
shape. Literal applicability, filter preservation, row-view preflight and graph
guards migrated together; hardcoded V1 column limits were removed. The added
300-byte text fixture checks duplicate-preserving count and rejects malformed
literal bytes/REAL shape, pending native execution. Actual decoder and admitted
operation resource budgets remain separate requirements; these predicates alone
establish no resource bound. Full streaming snapshots, chunks and indexes
additionally require their own compiled consumer and refinement; this materialized
row graph does not provide those by carrier naming.


The actual domain consumer's `export_code` check exposed that locale abbreviations
alone do not install executable constants for `typed_plan_bundle.run_checked`.
Source and Row now use `global_interpretation ... defines` for their concrete
elaborator, primitive check, node executor, plan executor and checked runner.
Their existing run APIs retain the same semantics; full-transcript refinement
unfolds the concrete alias before the original primitive-refinement equality.
These Source/Row alias changes are pending actual theory/code-generation checks,
not a claim that the unqualified RowKernel already compiles.
