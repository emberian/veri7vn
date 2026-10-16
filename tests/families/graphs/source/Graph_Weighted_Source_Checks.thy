theory Graph_Weighted_Source_Checks
 imports Veri7vn_Graph_Source_Soundness.Graph_Source_Soundness
begin
fun vertex_row where
 "vertex_row v = [Cell_Integer False [0],Cell_Integer False [v],Cell_Null,Cell_Null,Cell_Null,Cell_Null]"
fun edge_row where
 "edge_row key s t neg cost mode = [Cell_Integer False [1],Cell_Integer False [key],
  Cell_Integer False [s],Cell_Integer False [t],Cell_Integer neg [cost],Cell_Integer False [if mode then 1 else 0]]"
definition weighted_fixture where
 "weighted_fixture mode isolated = Source_Batch 6
  ([vertex_row 0,vertex_row 1,vertex_row 2] @ (if isolated then [vertex_row 3] else []) @
   [edge_row 10 0 1 False 2 mode,edge_row 11 1 2 False 3 mode,edge_row 12 0 2 False 8 mode]) True"
lemma signed_weight_from_original_cell:
 "decode_graph_weight (Cell_Integer True [3])=Some (-3)"
 by (simp add: run_structured_graph_query_def graph_request_output_permitted_def graph_request_output_nodes_def graph_max_cell_work_def graph_request_budget_permitted_def graph_request_budget_def
   graph_source_shape_work_def graph_decode_work_def byte_string_def)
lemma excessive_weight_bits_rejected:
 "decode_graph_weight (Cell_Integer False (replicate 65 0))=None"
 by simp
lemma float_cell_not_silently_rounded:
 "decode_graph_weight (Cell_RealBits [0,0,0,0,0,0,240,63])=None"
 by simp
lemma undirected_weighted_traversal_supported:
 "weighted_operation_supported False (SearchPath 2 0 4 10 8)"
 by (simp add: weighted_operation_supported_def)
definition weighted_mst_request where
 "weighted_mst_request = SnapshotWeightedGraphQuery False 8 8 4 MinimumSpanningTree"
definition run_weighted_fixture where
 "run_weighted_fixture isolated = run_structured_graph_query weighted_mst_request (weighted_fixture False isolated)"
definition run_weighted_reverse_path where
 "run_weighted_reverse_path ignored = run_structured_graph_query
   (SnapshotWeightedGraphQuery False 8 8 4 (ShortestPathQuery 2 0)) (weighted_fixture False False)"
ML \<open>
 val _ = (case @{code run_weighted_reverse_path} () of
     @{code GraphWeightedSnapshotAnswer} (lineage, @{code ShortestPath} (rows,_)) =>
       if length lineage=3 andalso length rows=2 then () else error "weighted reverse path lost original rows"
   | _ => error "weighted source reverse shortest failed");
 val _ = (case @{code run_weighted_fixture} false of
     @{code GraphWeightedSnapshotAnswer} (lineage, @{code MinimumTree} (rows,_)) =>
       if length lineage=3 andalso length rows=2 then () else error "weighted source witness/lineage lost"
   | _ => error "weighted source MST consumer failed");
 val _ = (case @{code run_weighted_fixture} true of
     @{code GraphWeightedSnapshotAnswer} (_, @{code DisconnectedGraph} _) => ()
   | _ => error "weighted source isolated vertex disappeared");
\<close>
end
