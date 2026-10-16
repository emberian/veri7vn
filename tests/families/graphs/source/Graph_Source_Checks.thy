theory Graph_Source_Checks
 imports Veri7vn_Graph_Source_Soundness.Graph_Source_Soundness
begin
definition source_fixture where
 "source_fixture full = Source_Batch 4
   [[Cell_Integer False [0],Cell_Integer False [7],Cell_Integer False [1],Cell_Null],
    [Cell_Integer False [1],Cell_Integer False [8],Cell_Integer False [2],Cell_Null]] full"
lemma incomplete_cannot_claim_unreachable:
 "run_structured_graph_query (SnapshotGraphQuery 8 8 4 (CheckUnreachable 2 0 [2]))
    (source_fixture False) = GraphIncompleteSnapshot"
 by (simp add: run_structured_graph_query_def graph_request_output_permitted_def graph_request_output_nodes_def graph_max_cell_work_def graph_request_budget_permitted_def graph_request_budget_def
   graph_source_shape_work_def graph_decode_work_def source_fixture_def graph_query_batch_def)
lemma source_chain_retains_rows:
 "run_structured_graph_query (SnapshotGraphQuery 8 8 4 (EnumeratePaths 0 2 2))
   (source_fixture True) = GraphSnapshotAnswer (DepthBoundedPaths 2
    [[\<lparr>row_key=0,relation_key=7,tail=0,head=1,weight=1\<rparr>,
      \<lparr>row_key=1,relation_key=8,tail=1,head=2,weight=1\<rparr>]])"
 by (simp add: run_structured_graph_query_def graph_request_output_permitted_def graph_request_output_nodes_def graph_max_cell_work_def graph_request_budget_permitted_def graph_request_budget_def
   graph_source_shape_work_def graph_decode_work_def source_fixture_def graph_query_batch_def relation_graph_def
   graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def wellformed_graph_def bounded_paths_def edge_enabled_def edge_target_def byte_string_def)
lemma source_literal_rejects_whole_profile:
 "run_structured_graph_query (SnapshotGraphQuery 8 8 4 (EnumeratePaths 0 1 2))
   (Source_Batch 4 [[Cell_Integer False [0],Cell_Integer False [7],Cell_Null,Cell_Text [65]]] True)
   = GraphSchemaRejected"
 by (simp add: run_structured_graph_query_def graph_request_output_permitted_def graph_request_output_nodes_def graph_max_cell_work_def graph_request_budget_permitted_def graph_request_budget_def
   graph_source_shape_work_def graph_decode_work_def graph_query_batch_def relation_graph_def byte_string_def)
lemma search_output_budget_covers_cut:
 "v+1 \<le> graph_output_nodes v e depth (SearchPath s t d fuel frontier)"
 by simp
lemma shortest_output_budget_covers_cut:
 "v+1 \<le> graph_output_nodes v e depth (ShortestPathQuery s t)"
 by simp
definition deep_loop_request where
 "deep_loop_request = SnapshotGraphQuery 2 2 256 (EnumeratePaths 0 0 256)"
definition loop_source_row where
 "loop_source_row = [Cell_Integer False [0],Cell_Integer False [7],Cell_Integer False [0],Cell_Null]"
definition run_output_guard_fixture where
 "run_output_guard_fixture ignored = run_structured_graph_query deep_loop_request (Source_Batch 4 [loop_source_row] True)"
definition run_preprojection_guard_fixture where
 "run_preprojection_guard_fixture ignored = run_structured_graph_query
   (SnapshotGraphQuery 2048 2048 4 (CheckPath 0 0 [])) (Source_Batch 4 (replicate 1000 loop_source_row) True)"
ML \<open>
 val _ = (case @{code run_output_guard_fixture} () of
     @{code GraphOutputBound} => () | _ => error "graph aggregate output escaped preguard");
 val _ = (case @{code run_preprojection_guard_fixture} () of
     @{code GraphRequestBound} => () | _ => error "graph raw validation work escaped preguard");
 val _ = (case @{code run_structured_graph_query}
   (@{code SnapshotGraphQuery} (Veri7vn_Numerals.nat_of_integer 8, Veri7vn_Numerals.nat_of_integer 8,
      Veri7vn_Numerals.nat_of_integer 4,
      @{code EnumeratePaths} (Veri7vn_Numerals.nat_of_integer 0, Veri7vn_Numerals.nat_of_integer 2, Veri7vn_Numerals.nat_of_integer 2)))
   (@{code source_fixture} true) of
     @{code GraphSnapshotAnswer} (@{code DepthBoundedPaths} (_, [rows])) =>
       if length rows=2 then () else error "source graph lost exact witness rows"
   | _ => error "source graph generated consumer failed");
\<close>
end
