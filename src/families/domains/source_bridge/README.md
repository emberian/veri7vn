# Qualified source quantities

`Source_Quantity_Bridge.thy` composes the actual source integer-cell meaning with
the existing exact quantity/domain interpreter. Its first closed unit profile is
m, cm, mm, N, N/m, kg and g. It checks the original `reported_units`, retains the
whole qualified observation and original cell coordinates, and rejects missing,
malformed, NULL, REAL, wrong-unit or out-of-range input. Invalid inputs retain
all individual projection outcomes; they cannot be dropped to change arity.
The domain result remains the existing typed Answer/Rejected/Blocked outcome.
Spring meaning is conditional on the existing exact ideal-model premise.

`native/source_quantity_consumer.ML` is the fixed **internal** SourceDomain
wrapper approved for the shared ingress. It consumes the source owner's
`VERI7VN_QUALIFIED_SOURCE_CELL`; there is no local source producer, raw batch
accessor, permission machine, ticket issuer or callback registration. The actual
Common/SourceCell producer now exists as an uncompiled source dependency.

For each actual cell the wrapper verifies the exact protected `(obs,row,column)`
input and selected-cell proposition against its integer/unit/coordinate getters.
The source's accepted specialization must match that same proposition and native
receiver generation, with no hidden assumptions or oracles. Kernel inference via
`source_cell_quantity_bridge` derives the exact unit-tagged `LinearValue(of_int n)`
correspondence. The wrapper owns an independently retained cell child, preserving
producer-handle release; source/declaration invalidation still denies every child.

The native operation is parsed from the actual SourceDomain Scope child's exact
owned source slice. The wrapper derives its allocator from that actual parent,
requires each Cell's protected Scope child as a predecessor from the same parent,
claims the operation child once and independently retains its own child view.
Ordinary release of the producer child preserves legitimate descendants; shared
parent denial still blocks every view. No numeric child ID constructs authority.

The complete
DomainCall is a new derivative artifact, not a claim that the original source
wire contained DomainCall syntax. Existing `Domain_Request` owns the calculation
and exact model/input condition associations. Source cell/acquisition bindings,
original operation source, source-derived facts and all native dependencies stay
inside the sealed wrapper. `result_view` includes full source observation,
selection, canonical unit profile and typed value for recipient inspection.

Installed constructors use `prepare_into`/`reconstruct_into` with their caller-owned
cleanup root, preserving ownership when interruption arrives immediately after
publication. `prepare_child_into` is the installed construction name; ordinary `prepare`/`reconstruct` are convenience calls.

Assembly must retain this fixed wrapper through charge, execution, gate,
publication, rendering, durable recovery and Forget. Its internal `family_request`
access does not authorize publication through an extracted Domain request.
`source_bindings` retains the actual opaque acquisition roots; selected-cell
proofs or metadata strings alone are not source qualification. Every output
specialization rechecks the wrapper and same Domain output association.

Snapshots are inert. Recovery reconstructs the actual source cells, original
operation owner and authenticated derivative owner, calls `reconstruct`, then
compares the entire native correspondence. Restored derivative sources are
independently leased and their caller-owned base is not dropped. No saved term,
ID, metadata record or receipt creates a source cell or native authority.

Current verification status: all new native theories/functor/tests are queued,
not yet compiled. `tests/integration/quantities/Source_Quantity_Bridge_Tests.thy`
checks generated pure projection/composition. `Source_Quantity_Kernel_Tests.thy`
separately checks actual bundle `of_int` normalization/execution/projection.
`Source_Quantity_Protected_Tests.thy` now invokes the actual private Common→Cell→
wrapper→charged DomainWorker path, with original source metadata fixtures. It
checks source100cm→exact1m, source3N/m×2m→exact6N, typed unit/NULL/model/dimension
refusals, foreign parents, independent retained views and source invalidation, plus deterministic interruption after a computed output
with cleanup that preserves independent positive consumers.
Its private tickets model already charged commands; it does not execute the
resident generated reducer/journal. Same-owner reconstruction checks actual
native correspondence and rejects output substitution; it is not crash recovery.
Source invalidation checks lower native Forget guards, not an installed lifecycle
RPC. Actual authenticated Scope/Common restart and resident publication remain
open. Body wire/1 and metadata frame/2 are separate existing format versions;
these fixtures preserve both exactly. Wrapper ownership acquisition and root publication use a short mask. Heavy
Domain preparation uses the domain owner's `prepare_into` cleanup root under
restored interruptibility. The domain owner reports actual bundle execution,
exact rational/of_int normalization and prepare_into rollback PASS in receipt
`06c735c6fe8317f8/81feaa2f44f44819aa79a3e1114a5e83`. This is dependency
evidence; the SourceDomain composition and service/source producers still await
their own checks.

Recovery integration proposal (pending root/assembly agreement): the fixed native
payload must carry a distinct `SourceDomain` tag, not reuse a bare `DomainRequest`.
The authenticated outer request/goal/slot/semantic-generation/code-generation
meanings remain the shared envelope meanings. Its native material must retain
`Q.saved`, the original operation owner, the derivative owner, the full original
source settings/body/metadata owners, the actual Scope parent/ordered plan and
required live children, and each original Common acquisition association and Cell
selection. Shared Domain condition-role validation applies inside this material;
it does not replace the source acquisition qualification or correspondence.

Restore first authenticates retained originals and reconstructs the actual Scope
and Common association without issuing acquisition tickets or charging again.
Only then may the source owner reconstruct opaque Cells, the Domain owner restore
condition associations, and `Q.reconstruct_into` compare the entire saved
correspondence. Binary body/metadata originals need an authenticated binary input
owner; the existing UTF-8 native-input pool cannot represent them by relabelling
their encoding. A missing source/condition/Scope reconstruction must refuse the
whole SourceDomain payload. Executing or publishing a recovered naked Domain
request would lose the original source guard and is not an allowed fallback.
No SourceDomain restart codec or source restoration factory is implemented here.

D67 fixes the closed request pair `source-quantities/1` /
`source-domain-request` (empty evidence), and output pair
`source-quantities-runtime-refinement/1` / `source-domain-output` (nonempty
source-qualified RuntimeRefinement). These retain the shared request-slot and
evidence category meanings. They cannot fall back to the plain Domain decoder.

The nested `Q.Gate` is now a concrete uncompiled leaf. Its
`specialize_into bridge actual_request actual_output cleanup_root` constructs
the Domain gate lexically from that wrapper's actual Domain request. The public
API exposes no Domain request or bare Domain gate. Its exact target is the full
`Q.specialize` conjunction; its projection contains both the actual typed Domain
display/conditions and every original source view. All getters check the full
source/wrapper/Domain/output/bridge ancestry. The gate retains an independent Q
view; Q views share the same actual Domain request and release the underlying
Cell/Scope/Domain leases only when the final view is released. The native output
and display bridge remain guarded assembly-owned resources: releasing either
makes the gate unavailable. The protected fixture now checks full-target equality,
source-view projection, producer-release survival and source invalidation through
this actual nested gate. Neither the new gate nor those checks are qualified yet.
