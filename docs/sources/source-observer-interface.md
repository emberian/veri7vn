# Common acquisition and observer leaves

The D48 follow-on architecture separates common acquisition from count plans, graph/MST, facts/documents and ConceptNet. Interface qualification and installed RPC remain separate gates.

## Common owner

Authored declaration contains source key/schema/encoding/version/origin/config/calibration/quality/codec/selection/retention and ordered condition references. Generated Owner supplies request/attempt/binding/slot/target/semantic-generation/condition-occurrence identities and pinned session/clock context. Equal condition references at distinct positions remain distinct occurrences. Acquisition profile clamps limits; observer leaves pin their work/output limits.

`VERI7VN_COMMON_SOURCE` seals instance/declaration/reservation/snapshot/condition_reference/owner_context. Fixed operations:

- qualify limits(input bytes,rows,metadata nodes/depth/bytes,seconds).
- elaborate actual declaration_owner/declaration_slice/conditions.
- prepare allocator/current owner_context/declaration.
- dimensions(snapshot), is_live, dependencies, release_reservation/release_snapshot.

Private attachment consumes the actual Tickets.acquisition_ticket plus protected body/manifest inputs and provenance owners. It verifies exact generated reservation, all source/declaration/condition ownership and the attached decoded observation. No unchecked numeric IDs, caller cterm or Boolean grants authority.

## Shared representation and transfer

The reflected source_association contains requirement, manifest, original versioned bytes, actual source_batch and attached observation. Its independent meaning is:

```isabelle
source_association_meaning a \<longleftrightarrow>
  acquire_native_versioned (association_requirement a) (association_manifest a)
    (association_original_bytes a) =
      Some (association_batch a, association_observation a)
```

Only fixed construct_source_association creates it inside the opaque owner, retaining original bindings/leases and qualified executable. There is no caller-created association/theorem bag.

`VERI7VN_SOURCE_OBSERVER_INPUT.transfer` creates an independently retained input_witness. Fixed leaf-only view exposes native_binding, association, authenticated dimensions(wire_bytes,rows,columns,total/max cell payload), dependencies, is_live, same_input and release. Recipients get no raw batch accessor; arbitrary functions/proof callbacks cannot cross the seam. Transfer preserves storage, not execution permission.

Each fixed leaf has native request codec, evaluator, independent meaning, representation/serializer bridges, admitted C02 entries and pin: CountSettings alone imports row-plan specialization; relation uses structured_relation_request; graph source_graph_request; ConceptNet concept_source_request; SourceCell exact integer cell/reported units. Leaves execute **the same association**, consume source_association_meaning and specialize their requirement against the actual owner binding. Static privacy alone does not prove runtime correspondence; serializer/receiver/first-consumer checks remain required.

The installed aggregate is a closed sum of qualified typed jobs/results with existing private generated tickets. No universal HOL value, callback registry or externally supplied theorem evaluator is introduced. Reuse captured parsed carriers; rebuilding huge terms or reparsing each query is outside the intended execution path.

## Charge and lifecycle

Acquisition authenticates/cache dimensions while charged. Observer precharge is a cheap conservative function of those scalars/request, before decode/projection/sort/search; worker checks actual dimensions under the charged budget. Bound repeated witness nodes×payload before allocation. Bounded exact serializers reject rather than truncate Complete outputs. Work models are not CPU/memory theorems.

Declaration occurrence owns a managed unit: release denies its jobs while same-input siblings survive; physical invalidation denies all input uses. Independent result release affects only that handle, parent retirement denies children, and dead children unlink promptly.

Migration checks: preserve actual D48 base receipt, check common alone/leaves alone/private-ticket aggregate. Keep compact/1 inverse distinct from framed/2 representation. Real v1 reader, ambiguity/occurrence lifetime, graph lineage/work, ConceptNet labels/confidence/selection and original document bytes each need consumers.

## SourceCell and quantities

Source_Cell_Selection's project_source_cell selects integer+original reported unit, distinguishing unavailable observation, missing row/column/unit, malformed and noninteger cells. Success refines independent source_cell_selection_meaning. Opaque native input is exactly(observation,row,column), and fixed quantity consumers must match its value/unit/coordinates/proposition and receiver generation.

The charged Common/Cell producer specializes from its same acquisition association; a true theorem about another observation cannot substitute. Retention is distinct from current occurrence/authority. D54 SourceDomain must retain cell/conversion/source qualification through execution, display, recovery and Forget; extracting a naked Domain request loses that guard. [SourceDomain implementation/status](../../src/families/domains/source_bridge/README.md) records the newer concrete draft; pure selection/projection does not qualify installed publication.
