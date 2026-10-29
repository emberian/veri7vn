# Exploratory Rust designs: source review, 29 October 2026

These designs have no specialist-panel numbers, executed sprint fixtures or
benchmark results. This review read source and followed small cases by hand;
it did not compile, test, run solvers or integrate anything. The earlier logic
core receipt does not qualify its new examples. No new theorem is claimed.

| Design | Useful result | Decision and next narrow experiment |
| --- | --- | --- |
| [Streaming query](streaming-query/README.md) | Shared integer rows, independent cursors, scalar consumers, and an explicit distinction between entity sets and statement witnesses. | First adoption candidate is a scalar-output contract in the existing executor. Then compare one image adapter against SQLite, keeping evidence and Previous requirements explicit. Do not replace the current SQL pushdown or shared-node materialization. |
| [Maintained views](maintained-views/README.md) | A long-lived owner with dynamic demands, shared public adjacency, private support identities and atomic view versions. This adds something the existing batch differential wrapper lacks. | Next candidate is a disposable, bounded runtime cache tied to durable versions. Keep deletion rederivation until a workload establishes a need for a more complex algorithm. |
| [Conditional symbolics](conditional-symbolics/README.md) | Typed shared formulas and independent replay of rewrites under explicit interval premises. | Retain as a checked formula artifact. Unify it with existing dimensional reasoning before hosting another algebra API. A later domain-obligation plan must preserve original singularities without evaluating the whole original formula. |
| [Logic laboratory](../oracle-logic/DEMOS.md) | Evidence-token withdrawal, complete revised programs and finite conditional explanations. | Retain the revision layer for further planning/repair experiments. The small policies illustrate semantics; they are not a general planner, diagnosis engine or action authority. |

The principal findings are concrete API boundaries, not reasons to discard the
experiments:

- Streaming originally allowed unrelated image cursors to mix and then stamped
  the result with a caller-chosen release. The revised private image identity
  travels through sealed cursors and rejects mixed inputs, including empty
  branches. It establishes compatibility, not source authenticity. Partition
  scratch accounting also now preallocates the charged capacities and checks
  the request budget while constructing descriptors. Vector growth was also
  changed to charge the complete replacement allocation while retaining prior
  charges, since old and new buffers can coexist. This meters logical buffer
  storage, not allocator overhead or a hard process memory limit.
- A maintained view exceeding `nodes_per_view` refuses the whole actor update.
  That is coherent for this isolated atomic actor, but a disposable cache must
  not veto already committed source truth. Its adapter must evict or invalidate
  the oversized demand and coordinate publication with durable versions. The
  host must also bound actor count and retire tenant namespaces. Hand traces of
  duplicate withdrawal, reverse traversal, insertion chains and disconnected
  cycles exposed no reachability error.
- Conditional replay's three identities and congruence preserve dimensions and
  values on admitted inputs. Evaluating the original formula before the selected
  formula preserves its partial domain but currently adds work. There is no
  transitivity rule for chaining successive rewrites at one node; this is a
  deliberate small checker, not yet a general optimizer. Exact-rational work
  and recursion need limits before receiving hosted input.
- Logic's thirteen expected readouts agree with the supplied rules by hand.
  Its topic/revision label is not a stable program identity: builder changes
  can change even one instance's program without advancing the revision counter.
  There is no cache today, so this causes no demonstrated stale answer. Freeze
  construction or identify complete snapshots before using it for caching or
  audit replay. Conditional support traces correctly remain separate from
  stable-model admission and absence-dependent conclusions.

Keep all four as distinct probes. Discard the quadratic relation-object sort
before scaling, and avoid promoting handwritten demo policies into production
contracts. The clearest immediate engineering direction is to separate what a
query consumer needs from how the executor obtains it; after that, persistent
ownership and explicit assumptions offer more than another replacement engine.
