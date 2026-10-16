# Graph consumer profiles

Upstream specialists/algorithms/organ_algorithms_v1.py uses float Dijkstra/Kruskal and ignores MST direction. Native graph_dispatch repairs this with exact signed integers/directed-MST rejection; parser/float parity is not claimed. Graph_Checks distinguishes feasible cost8 from certified shortest5 and bounded from complete absence.

| Operation | Algorithm/checker |
|---|---|
| One feasible path | Two-list FIFO/node dedup/fuel/frontier/depth; independent witness/cut checker. Unclosed depth cut stays SearchExhausted DepthBound. |
| Shortest | Bounded Bellman-Ford proposal plus path/vertex potentials bounding every walk. Unrelated negative cycles may defeat global certificate; diagnostic is not nonexistence. |
| MST | Kruskal signed weight/row-key order plus threshold partition-dual lower bound over every feasible tree. Exact equality licenses MinimumTree; failed certificate stays TreeCandidate. Proposal O(EV). |
| Reference MST/all walks |≤16-edge enumeration/developer reference; capped output-count check before allocation. |

Empty graph has no tree. Conventional acyclic-tree equivalence/efficient verified Kruskal completeness and performance qualification remain open. Variant-specific cheap source/scalar precharge precedes projection/validation; modeled work is not CPU/heap isolation.

SnapshotGraphQuery consumes the same qualified source association/full finite batch, rejecting literal rows; lineage preserves original ordinals. SnapshotWeightedGraphQuery mode nv ne nd call uses6 columns: vertex[0,id,NULL,NULL,NULL,NULL], edge[1,edgeID,tail,head,signedWeight,direction]. Direction0undirected/1directed must match mode. IDs≤256bits, weights≤512; duplicate keys/undeclared endpoints/malformed/mixed modes reject; parallel/contradictory distinct-key edges survive. Traversal uses original edge+start vertex, preserving reversed undirected provenance.

Planned decimal profile parses entire inert signed decimal, mantissa≤512bits/fraction digits≤18, scale10^d and integer weights m×10^(d−k)≤1024bits. Display cost/scale and scale potentials; require native scaling/order/projection proofs before activation. This is exact-decimal repair, not binary-float preservation.

Graph_Acquisition.run_associated_graph_query retains original versioned bytes/manifest/attached observation. Graph_Source_Resources uses cached dimensions for work/output guards. These leaves await native checks and installed protected operation/rendering/recovery/Forget.

Light path clients use Veri7vn_Graph_Core.Graph_Dispatch + graph_path_call/graph_path_dispatch_refinement, excluding MST. Aggregate Veri7vn_Graphs.Graph_Dispatch_Soundness retains MST obligations; source leaves likewise distinguish conditional path and full soundness. A light pass cannot qualify general graph admission.
