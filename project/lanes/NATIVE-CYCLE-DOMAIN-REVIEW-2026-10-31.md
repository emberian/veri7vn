# Native cycle domain review — 31 October 2026

Independent Astra review of the graph representation and packed reader work
under `NATIVE-NEXT-CYCLES-2026-10-31.md`. Report-only ownership: no implementation
edits, builds, tests or commits by this lane. **No new specialist-panel numbers.**

## Graph: frozen source approved

Reviewed `native/oracle-reasoning/src/graph.rs` and
`native/oracle-reasoning/tests/graph_layout.rs`. Author-provided freeze identities:
graph `e3dd9cb2e07b6aeb78814adc17ea0322656fb2437ac0494431efec1de5681ceb`;
tests `7471c69ed98f4e7a0505dcc58f8d1fdde2e29e5ea9c4473ace7a12f2c2703c5e`.
These are source review identifiers, not independently regenerated test receipts.

No blocking semantic finding. Kruskal sorts original edge IDs by `(weight,id)`,
matching the previous heap's full tuple ordering; equal weights therefore retain
deterministic occurrence selection, including parallel/reversed edges. Returned
IDs are sorted as before. The private borrowed admission handle only removes
duplicate validation within one call; the public checker still validates its own
input. Solver union/find state is dropped before independent checking.

The checker stores original edge IDs in CSR adjacency. This preserves distinct
parallel occurrences and rejects duplicate IDs and self-loops in certificates.
Its traversal rejects cycles and its original-edge pass rejects missing
connections. The flattened level-major parent/maximum tables retain the original
binary-lifting recurrence and final LCA edge check. `i64::MIN` is a valid maximum
identity even when it is also an actual edge weight; comparison remains strict
`weight < path_max`, so tied optimum certificates remain admissible. Negative
self-loops are correctly irrelevant to a spanning forest. Isolated vertices and
the empty graph retain their component/connected behavior. Bounded i64 edge sums
remain exactly representable in i128 under the admitted index bound.

The new finite oracle is independent of both union/find and binary lifting:
Floyd reachability plus edge count V−C characterizes spanning forests, then
enumeration selects minimum exact weight. It tests all ordered edge sequences
of length <=3 on <=3 vertices and every certificate subset, including loops,
parallel edges, disconnection, ties and negative weights. Separate tests compare
legacy selected IDs and cross a lifting boundary with actual i64::MIN edges.
Malformed/duplicate/nonminimal certificates are refuted. These are meaningful
authored checks; this review did not execute them or claim a measured speedup.

The subsequent root-approved block-fuel extension also received source review.
Known prefix/fill/lifting/path loops precharge their exact executed extent, with
check-only calls retained per iteration; the conditional LCA loop pays only when
entered. The producer prepays its edge scan and brackets standard-library sorts
with checks. Sorting remains an explicitly bounded uninterruptible interval;
one unit per edge is not a claim of charging every sort comparison. Cancellation
keeps prepaid fuel spent. Hand-counting the new two-vertex fixture gives 16
checker units and 20 producer-plus-checker units, agreeing with authored tests;
the insufficient-block and mid-prefix cancellation tests distinguish attempted
work from conservative retained charge. No semantic/block-accounting blocker.

## Reader: early interface review, final source pending

Read the existing program validation/lowering, reader compilation/execution and
evidence caches, composition pre-nested checks and query language evaluator.
The three owners are coordinating an existing-chart ProgramId/root representation
with private checked-operation handles, ordered occurrence recipes and a borrowed
query plan view. They have not yet supplied frozen code for final review.

Sent these concrete preservation obligations to the owners before implementation:

- Unique operations are an execution-sharing key, not an admission count. Each
  original syntax occurrence, repeated splice, encoded-byte obligation and dead
  branch must survive per-candidate limits and structural checks, including cache
  hits. A query view must retain ordered occurrence mapping rather than traversing
  only nodes reachable from its final unique root.
- Demanded children must undergo complete structural admission and entity-output
  nonempty viability before parent products, even when a learned parent omits its
  `@X` splice. Unsupported omitted children still veto certainty. Resource errors
  and cancellation must propagate, not become ordinary unavailable alternatives.
- Preserve the existing language-mode all-entity-stage guard and terminal Count
  exception. Pure program/graph evaluation has different dead-empty semantics;
  sharing the representation must not erase that mode boundary.
- Keep derivation/form/provenance checks separate from shared execution. Equal
  answer text or equal operation roots do not imply equal entity IDs, relation
  facts or qualifier/attribute positions. Existing selection comparison and
  complete evidence equality remain the answer-agreement boundary.
- The query stage cache stays request/lease/image/Previous scoped and retains
  literal, predicate, direction and qualifier identity. A checked private handle
  must not become a public unchecked constructor or deserializable receipt.
- Establish removed flattening through counters at the actual construction and
  expansion boundaries, including fragment viability. Counting calls to a new
  wrapper cannot prove that the old flat program reconstruction disappeared.

Final review will inspect implementation and adversarial fixtures for omitted
unsupported children, unused empty branches, equal text with differing witnesses,
repeated occurrence caps and 49-by-49 alternatives. Current early interface review
is not approval of an implementation that has not yet been delivered.

### Query view seam: source reviewed

The delivered `CheckedPlanView` exposes original entity-stage occurrence count,
borrowed/rebased individual nodes, output and projection. Existing Plan implements
the same interface. The private evaluator/compiler/projector now consume this
view; no semantics-changing branch was added to language traversal, Count's empty
exception, stage keys or result/evidence hydration. No blocker found in this
layer. Its checked producer remains responsible for byte/step/type/topology
admission before calling it.

`query_packed_tests.rs` uses a small packed stand-in, compares to the flat plan,
and adds independent expected entity IDs, a dead-empty refusal/Count exception,
and a relation witness with `since=2000` plus changed Previous in a fresh scope.
These tests exercise the query seam but cannot establish that the actual chart
and compiler producer satisfies its checked-view contract; that final review is
still pending. No tests executed here.

### Packed producer/chart: intermediate source review

The delivered producer checks expanded step count and original serialized syntax
bytes before consulting its exact occurrence-root cache. Literal specs and
semantic operation IDs are separate from local ordered entity occurrences;
rebasing preserves repeated/dead stages and scalar projection targets. Verify
accepts only Value dependencies, whose lowering produces the three allowed typed
value projections, so the missing direct call to Plan.validate does not by itself
permit nested Boolean verification. No concrete projection-admission mismatch
found in the shared operation contracts.

The chart visitor walks persistent child recipes with a base offset, preserving
each repeated child's internal indices and the parent's final child index.
Fingerprint buckets retain full occurrence equality checks. bind_recipe preserves
the old singleton placeholder expansion's NOP removal, missing-binding refusal,
and dependency mapping. The demanded base union remains checked before products,
and unsupported omitted children retain their certainty veto. Answer agreement
still compares entity IDs, facts and attribute positions; form and unsupported
guards still apply across readings.

Ownership remains under repair at this intermediate review: successful production
evaluation keeps source guards across levels and drops checked roots before those
guards, but raw source Arcs do not themselves own reservations. A retained callback
root on a composition error can outlive the chart ledger. Requested that the
shared owner cover sources from creation through error paths, including whole-flat
sources. Also requested counters at actual chart diagnostic flattening boundaries;
the compiler's own syntax counter alone cannot establish absence of other flat
construction. Final approval awaits those source changes and actual producer
adversarial fixtures. No tests executed here.

The subsequent custody repair closes the identified gap in source. Each chart
Recipe now coowns SharedChartMemory from creation; the ledger resizes that same
guard, so failure before batch transfer does not release retained recipe charges.
Whole-flat production sources similarly own the shared matched-batch reservation.
The new actual Chart.check callback-error test retains a source, drops chart and
ledger, requires live charged memory, then requires zero after dropping the source.
It checks a counter at DiagnosticStore.program itself, not merely a compiler
wrapper. Repeated-child step-cap and bind_recipe versus old singleton expansion
fixtures add relevant representation checks. These tests are authored evidence,
not execution receipts. Final producer regression/freeze review remains pending.

Explicit old Plan.validate parity audit found no missing invariant across the 27
operations. A nonempty valid program must begin with Find/FindAll; only these have
zero dependencies. Entity occurrence count is therefore positive and at most the
bounded original step count, and final output always inherits a valid entity
index. Backward typed dependencies ensure every rebased entity dependency precedes
its consumer. Relate directions and typed/inferred predicate admission use the
same shared checks as before (including the inferred text bound already present
in HEAD). Projection targets use local entity indices; optional directions remain
None. Verify consumes only Value, hence one of the three allowed source projections
and at most one nesting level. There is no additional name/key bound in the old
Plan validator. Packed Plan byte counting includes the exact envelope, output,
nodes, separators and projection with the same omitted-null allowance.

Read the actual packed_program_tests producer fixtures: six representative
lowering comparisons include duplicates/dead stages, Verify, relation qualifier
targets, typed filters and reversed relation targets. Additional fixtures check
original step/byte limits despite two shared FindAll occurrences, rejected dead
literal/topology/type caches, 2,401 distinct derivations with the expected shared
prefix lowering count, and source/diagnostic reservation lifetimes. The flat
comparison shares operation lowering code, so it establishes representation
parity rather than independently proving operation semantics. Independent query
expectations and the explicit invariant audit supply complementary evidence.

## Final cycle source disposition

**Source approved; no remaining blocking finding.** The preceding pending notes
describe intermediate review states, superseded by the final producer freeze.
The first byte-stream pass now checks cancellation and spends bytes per original
occurrence. Whole/composed/fragment counters are distinct; materialize() itself
records construction, and a fragment scope records any such event even on error.
Chart diagnostic construction has its own actual-boundary counter. These counters
do not themselves prove a performance result; central execution must supply the
new panels, parity results and measurements. This lane executed no builds/tests
and has no new panel numbers.

Final source identities read directly from files:

- packed_program.rs: `c136e36d050783314bb58854eb2c2e3579684d72a8ebde7b5a3956a6158713be`
- packed_program_tests.rs: `729bde4c1389a44cb8fcc4fa6351ccc8bbc66c9b45ece5f3e571a89cc5593aaf`
- reader.rs: `b1b6e69cd58576e44224be7679dfc1eb986e7a57a2f9eeb07cb18316db5a0b98`
- program.rs: `fa9830c28840ff389470cfa3caf91fc4fe324ac71b3216440dd5afbf9be7673f`
- segments.rs: `9045e57d7bc7849180a8fb08c73fe106b7b25de5f3531dd55351176d836c02ee`
- composition.rs: `15100091588b82dd1f9cdbd6f34bd3d5eb2c4382b9ec6527c80ed0b79fc05b91`
- grammar.rs: `efe097febee0701e862036eabe96f3348857210f260e565549992680506a307f`
- packed_recipe_tests.rs: `ac9fbe084683860874b60616ad791d9cda99440d2528f5daae6a9cd8b38e1379`
- query.rs: `8d5efe835a1e98720095dde8518fe841d8b89cce0d0a176b33d2d7bd03853439`
- query_packed_tests.rs: `397d0e35eebc33706ce90acdd70be131700beb6be445ae6fa4b9f782aebaaddf`
