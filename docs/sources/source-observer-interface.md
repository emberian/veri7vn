# Common acquisition and qualified source observers

Proposed interface after the current D48 source-base check. It is not an existing
RPC or a claim of native qualification. The common acquisition session must not
import count plans, graph search/MST, facts/documents or ConceptNet observers.

## Common native declaration

The native authored declaration carries source key, schema/encoding, version
policy, origin, configuration, calibration, quality, acquisition codec, selection,
retention and ordered condition references. It carries no request, attempt,
source binding, slot, target, semantic-generation or condition-occurrence IDs.
The gate allocates those from the current generated owner context. Equal-valued
condition references in different declared positions remain distinct occurrences.
Acquisition limits are validated and clamped by the installed acquisition profile.
Observer leaves separately pin work, output-node and output-byte limits.

`CountSettings`, `RelationSettings`, graph settings and ConceptNet settings belong
to their observer leaves. A relation declaration has no count predicate or count
plan context. Observation/session/clock context remains explicit common source
context, constructed from the pinned owner state rather than supplied numeric IDs.

The proposed internal common signatures are:

```sml
signature VERI7VN_COMMON_SOURCE =
sig
  type instance
  type declaration
  type reservation
  type snapshot
  type condition_reference
  type owner_context
  type limits = {input_bytes:int,materialized_rows:int,metadata_nodes:int,
    metadata_depth:int,metadata_bytes:int,seconds:int}
  type dimensions = {wire_bytes:IntInf.int,rows:IntInf.int,columns:IntInf.int,
    cell_payload_bytes:IntInf.int,max_cell_payload_bytes:IntInf.int}
  val qualify: limits -> instance
  val elaborate: instance ->
    {declaration_owner:Veri7vn_Managed_Provenance.source_owner,
     declaration_slice:Veri7vn_Native_Literals.slice,
     conditions:condition_reference list} -> declaration
  val prepare: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    context:owner_context,declaration:declaration} -> reservation
  val dimensions: snapshot -> dimensions
  val is_live: snapshot -> bool
  val dependencies: snapshot -> IntInf.int list
  val release_reservation: reservation -> unit
  val release_snapshot: snapshot -> unit
end
```

The private common source owner additionally consumes the actual acquisition
`Tickets.acquisition_ticket` with the existing protected body/manifest inputs and
P owners, and returns `snapshot`. It verifies source/manifest/declaration/condition
ownership, the exact reserved generated identities, versioned original-byte
representation and attached observation. This constructor is lexical-private in
the installed assembly, like the current private ticket issuer.

`condition_reference` and `owner_context` are sealed products of the actual
native declaration/generated owner; no constructor accepts unchecked IDs or a
Boolean describing authority. The authored declaration slice is interpreted by
one fixed decoder for this native settings version; a caller-supplied cterm or
pretty-printed equivalence cannot replace the original binding.

## Observer leaves and the installed aggregate

Each leaf contains its own fixed generated evaluator, request decoder, meaning,
serializer/representation bridges, admitted C02 semantic entrypoints and
executable pin. Relation consumes `structured_relation_request`; graph consumes
its closed `source_graph_request`; ConceptNet consumes `concept_source_request`.
A source-cell observer selects the exact integer cell and actual reported-unit
metadata for quantity/domain composition; it does not accept a caller literal or
unit string as a source value. Count alone imports row-plan specialization. Their pure results are separate
types, not a universal HOL value or JSON proof token.

A leaf binds a common live snapshot, its exact decoded request and its
observer-specific declaration/condition occurrence guards to an opaque job.
The final installed aggregate has a closed sum of these already-qualified leaf
jobs/results and the same private generated operation tickets. It exposes fixed
typed methods, not callback registration or a raw-batch accessor.

The transfer between common owner and the fixed leaf is a private typed input
witness retaining the actual source carrier/observation and independent leases.
Only the compiled native leaf adapter can inspect this owner view. It is not a
recipient API or a substitute for the leaf's semantic/runtime correspondence:
the adapter must apply its fixed generated function to that exact transferred
carrier and retain source/observer guards at reserve, transfer, execution and
result access. No arbitrary function or caller proof callback crosses this seam.
Proposed exact private owner view (visible only to fixed leaf adapters):

```sml
signature VERI7VN_SOURCE_OBSERVER_INPUT =
sig
  type snapshot
  type input_witness
  val transfer: snapshot -> input_witness
  type acquisition_association = Veri7vn_Source_Acquisition_Code.source_association
  type association_binding
  val native_binding: input_witness -> association_binding
  val association: input_witness -> acquisition_association
  val dimensions: input_witness ->
    {wire_bytes:IntInf.int,rows:IntInf.int,columns:IntInf.int,cell_payload_bytes:IntInf.int,max_cell_payload_bytes:IntInf.int}
  val dependencies: input_witness -> IntInf.int list
  val is_live: input_witness -> bool
  val same_input: input_witness * input_witness -> bool
  val release: input_witness -> unit
end
```

`acquisition_association` is a shared reflected native datatype for one exact
acquisition, not an accepted-theorem list or a batch value with provenance labels.
Its HOL model binds the source requirement, manifest, original versioned bytes,
actual decoded `source_batch` and attached observation:

```isabelle
source_association_meaning a \<longleftrightarrow>
  acquire_native_versioned (association_requirement a) (association_manifest a)
    (association_original_bytes a) =
      Some (association_batch a, association_observation a)
```

Only the fixed `construct_source_association` entry creates an association inside
the opaque owner. Its refinement states `source_association_meaning` and the
exact original-input/manifest binding. The native owner stores the result of that
same fixed generated entry, with the actual protected input owners/leases and
qualified acquisition executable. It does not accept a caller association,
cterm, theorem name, Boolean certificate or callback. The common reflected
association reuses the existing native `source_batch` carrier; it does not copy
or reinterpret source rows in a leaf.

Every leaf's semantic and executable entry takes this **association**, not a free
ML batch. For example, `run_associated_relation request a` observes
`association_batch a`, while its refinement consumes `source_association_meaning a`
and concludes the source observation/representation plus the relation's meaning
for that exact batch. The runtime leaf obtains `a` only from its retained common
`input_witness`; the native generated operation ticket is checked against that
same witness, source support, request, observer executable and owner generation.
Thus a cloned ML batch and unrelated admitted theorem cannot satisfy the leaf's
input or output association. Bare accepted lists are not the composition seam.

`transfer` retains a separate tracked input witness; it does not issue execution
or publication permission. The common owner exposes a fixed typed association
view plus its qualified native entrypoint/association certificate specialization
to the compiled leaf. That specialization is built by the owner from its actual
record; no caller cterm is accepted. Each leaf hardwires the exact input form and
checks native specialization against its composed semantic requirement before
receiving an accepted result. Static module privacy alone is not the refinement.
The precise association serializer/receiver correspondence remains a required
C02 bridge and must be qualified together with the owner and first real leaf.

The installed aggregate statically wires this exact common owner to fixed leaves.
There is no evaluator/theorem parameter or recipient-visible raw batch accessor.
Associated original-byte storage and any native representation optimization must
remain within the acquisition resource budget; rebuilding a huge HOL term or
reparsing the source on every query is not the intended deployed path.

## Charging and lifetime

Acquisition computes and retains authenticated scalar dimensions while already
charged for parsing. Observer precharge uses a fixed cheap conservative function
of those scalars and its request, covering decode/projection/validation/search.
It must not project or sort a graph merely to calculate the charge. Output bounds
include repeated witness nodes times retained payload size before allocation;
final frame rejection alone is too late. A fixed bounded typed serializer checks
the exact same result, and refusal cannot silently truncate a Complete collection. The worker
rechecks actual decoded dimensions/work under the charged budget. These are
explicit algorithmic work models, not wallclock or memory theorems.

A source declaration occurrence owns an existing managed native unit token.
Retiring it denies its bound jobs even while a second occurrence sharing the same
physical input remains valid. Physical input invalidation additionally denies all
uses of that input. Each result release retires only its own handle; parent
retirement invalidates all children. Dead child entries must be unlinked from
long-lived parents rather than retained until parent shutdown.

## Migration checks

Preserve the actual D48 base receipt and its source bytes before moving the count
observer out. Then check common acquisition alone, each leaf alone, and the closed
aggregate's actual private-ticket consumers. Keep compact `/1` roundtrip and
framed `/2` original-byte representation separate. The actual retained v1 relation
fixture, NL ambiguity/occurrence retirement, graph row lineage/work guards,
ConceptNet text/confidence/selection and exact document-byte spans remain separate
consumer obligations. No observer pass closes the others.

## SourceCell consumer contract

The draft isolated `Veri7vn_Source_Cell_Selection` session contains
`Source_Cell_Selection.thy` and the source-owned `VERI7VN_QUALIFIED_SOURCE_CELL`
signature. It does not yet contain a charged producer or installed service branch.
`project_source_cell` selects an integer and the observation's original reported
unit, with distinct unavailable-observation, missing-row, missing-column,
missing-unit, malformed-cell and noninteger refusals. Its refinement relates
success to the independently stated `source_cell_selection_meaning` predicate.

An opaque cell's native input is exactly `(observation,row,column)`; its native
requirement is the closed `source_cell_selection_meaning observation row column
value unit` proposition. The native observation, coordinates, integer and reported
unit exposed to the fixed quantity bridge must agree with those terms. The source
producer specializes this judgment from the same qualified acquisition
association. A true selection theorem about a separately supplied observation is
insufficient. Retained cell leases preserve storage; current source occurrence,
managed dependencies and execution authority must still be checked at use.

D54's fixed SourceDomain wrapper retains this cell and the exact domain request
through execution, publication, display and recovery. Unwrapping the domain call
must not authorize a source-derived answer independently. The pure selection and
quantity bridge drafts are not evidence that this protected producer and service
consumer already exist.
