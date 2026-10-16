# Graph specialist consumer

The original shipped `upstream/root/specialists/algorithms/organ_algorithms_v1.py`
uses Dijkstra and Kruskal, accepts unsigned decimal edge text into binary floats,
and ignores input direction in its MST loop. The native profile deliberately uses
exact signed integers and rejects directed MST input. This is a repair/profile
change, not a preservation claim for the Python parser or floating-point results.

`tests/families/graphs/Graph_Checks.thy` is the concrete native dispatcher caller:
it distinguishes a valid cost-8 path from a certified shortest cost-5 path,
checks a cut certificate, and retains depth-bounded absence as bounded absence.
The HOL `graph_dispatch` definition is the sole algorithm implementation.

A shortest certificate consists of the original edge list and vertex potentials;
its theorem bounds **every walk**, including cycles, and therefore rejects graphs
with a reachable negative cycle whenever no global potential exists. A refusal is
not a theorem that no shortest path exists. Negative edges themselves are allowed.

The default one-path search uses a two-list FIFO, node deduplication, expansion
fuel, frontier cap, and depth cap. Every returned witness/cut passes the independent
checker. A depth-limited unclosed cut stays `SearchExhausted DepthBound`. This
operation promises a feasible path, not shortest weighted cost or all alternatives.
The separate all-walk enumeration preserves all edge alternatives and requires a
conservative capped-count check before output allocation.

Default MST proposes a tree with Kruskal (signed exact weights, row-ID tie order)
and builds threshold-component partition prices in the same sorted-edge order.
The independent partition-dual checker bounds **every** feasible tree and licenses
`MinimumTree` only when the selected cost matches that lower bound. A failed
certificate retains a separate `TreeCandidate`, never an optimum. Component labels
currently give O(EV) proposal work; the checked certificate remains polynomial.
`ReferenceMinimumSpanningTree` explicitly enumerates at most 16 supplied edges and
is a developer reference, not the production default. Empty graphs have no tree
in this profile. Conventional acyclic-tree equivalence and efficient verified
Kruskal completeness remain open proof obligations.

Every dispatch first checks actual graph dimensions, requested materialization,
and a conservative variant-specific work profile. Source charging includes raw
cell decoding plus actual projected graph work. These are algorithmic work models,
not wall-clock or process-memory guarantees. Native proofs and performance
measurements remain pending the build steward.

No source row key grants adoption. Source graph execution must consume the same
opaque `Veri7vn_Source_Admission.association` held by the fixed service gate, its
actual acquired snapshot and source owner. `src/families/graphs/source/Graph_Source.thy` provides the fixed typed
`SnapshotGraphQuery` projection from the same source batch, rejecting incomplete
snapshots and literal rows for this entity-only profile. Its lineage theorem binds
every projected edge to the original decoded row ordinal. The source owner is
coordinating the closed operation in that gate. Service source-backed claims, charged generated execution,
registered codecs, restart/Forget, and ordinary-user output remain **unintegrated**;
these fixtures do not satisfy the graph-family task's production acceptance.

Native source/generated caller fixtures are awaiting the coordinated build steward;
no native test pass or deployed qualification is claimed by this draft.

## Weighted acquired source profile

`SnapshotWeightedGraphQuery mode nv ne nd call` consumes the same protected
six-column source batch. Vertex rows are `[0,id,NULL,NULL,NULL,NULL]`; edge rows
are `[1,edgeID,tail,head,signedIntegerWeight,direction]`. Direction is 0 for
undirected or 1 for directed and must match the declared mode for every edge.
IDs have at most 256 magnitude bits, weights at most 512. Duplicate vertex IDs or
edge keys, undeclared endpoints, mixed modes and malformed cells reject the entire
profile. Distinct-key contradictory or parallel edges survive. The result retains
edge-key to original raw-row-ordinal lineage, in addition to the source assertion
observation. Native fixtures exercise acquired weighted MST and isolated vertices.

The orientation-aware kernel now uses the original edge record plus the starting
vertex to determine forward or reverse traversal. This preserves row identity for
undirected paths rather than manufacturing reversed provenance. Directed and
undirected fixtures are queued for native checking; no deployed qualification is
claimed. Mixed-direction input still needs an explicit profile and is rejected.

## Exact decimal bridge plan

Upstream parses unsigned decimal weight text to binary floats. Integer support
does not cover that domain. The next separate profile will parse the entire inert
decimal cell (optional sign, decimal point, no executable expression), retain its
original bytes, and bound mantissa to 512 bits and fractional digits to 18. Let
`d` be the maximum fractional length and `scale = 10^d`; each original decimal
`m / 10^k` becomes integer weight `m * 10^(d-k)`, rejecting scaled magnitudes over
1024 bits. The profile must retain `scale` and display exact rational cost
`integer_cost / scale`, not label scaled integers as original units. Certificate
potentials use that same scale. Positive common scaling preserves path/tree cost
ordering; native sum/scaling and result projection theorems must connect this
codec to the existing integer checker before service activation.

This repairs numerical semantics to exact decimal rational values; it does not
preserve binary floating-point rounding or claim full original parser parity.
Mixed directions need separate original-edge/traversal orientation lineage,
including reversal of undirected edges without duplicating provenance identity.

Automatic shortest paths now have a bounded Bellman-Ford proposal, checked by
the same path/potential contract. A global potential cannot certify a graph with
an unrelated negative cycle; that failure stays a certificate diagnostic rather
than a claim that no requested shortest path exists. Source execution first checks
a cheap raw-row/cell work budget before projection or quadratic validation; the
projected-work function is a diagnostic, not a substitute for precharge.

The optional source leaf now provides `Graph_Acquisition.run_associated_graph_query`
over one retained acquisition association. Its refinement retains the exact
manifest, original-byte representation and attached observation while reusing
`run_structured_graph_query` on that association's batch. `Graph_Source_Resources`
provides scalar cached work and output guards: row-width validity comes from the
acquisition meaning, and cell-size bounds use the shared source-row/2 encoding
accounting. These are modeled work/allocation bounds, not heap or serialized-frame
size theorems. These new leaf compositions await native checking and do not yet
constitute an installed protected graph operation or UI result.

Path consumers select `Veri7vn_Graph_Core.Graph_Dispatch` and prove the
`graph_path_call` profile before using `graph_path_dispatch_refinement`.
`MinimumSpanningTree` and its reference variant are excluded. The evaluator and
call/reply datatypes remain shared with the full graph service.
`Veri7vn_Graphs.Graph_Dispatch_Soundness` retains the aggregate theorem and MST
optimality obligation. The source and associated-source leaves make the same
split: conditional path refinement in `Veri7vn_Graph_Source`, unconditional
refinement in `Veri7vn_Graph_Source_Soundness`. A light build does not qualify a
general graph admission profile.
