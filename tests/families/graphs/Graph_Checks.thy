theory Graph_Checks
 imports Veri7vn_Graphs.Graph_Dispatch_Soundness
begin
definition e01 where "e01 = \<lparr>row_key=10, relation_key=7, tail=0, head=1, weight=2\<rparr>"
definition e12 where "e12 = \<lparr>row_key=11, relation_key=8, tail=1, head=2, weight=3\<rparr>"
definition e02 where "e02 = \<lparr>row_key=12, relation_key=9, tail=0, head=2, weight=8\<rparr>"
definition fixture where "fixture = \<lparr>vertices=[0,1,2], edges=[e01,e12,e02], directed=True\<rparr>"
lemmas fixture_defs = fixture_def e01_def e12_def e02_def
lemma valid_nonoptimal:
 "graph_dispatch 8 8 4 fixture (CheckPath 0 2 [e02]) = FeasiblePath [e02] 8"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def feasible_path_def path_cost_def)
lemma false_optimum_rejected:
 "graph_dispatch 8 8 4 fixture (CheckShortest 0 2 [e02] [(0,0),(1,2),(2,5)]) = RejectedCertificate"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def shortest_certificate_def feasible_path_def potential_check_def path_cost_def)
lemma true_optimum:
 "graph_dispatch 8 8 4 fixture (CheckShortest 0 2 [e01,e12] [(0,0),(1,2),(2,5)]) = ShortestPath [e01,e12] 5"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def shortest_certificate_def feasible_path_def potential_check_def path_cost_def)
lemma directed_mst_rejected:
 "graph_dispatch 8 8 4 fixture MinimumSpanningTree = DirectedMSTRejected"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def)
lemma bounded_absence_is_not_unreachable:
 "graph_dispatch 8 8 4 fixture (EnumeratePaths 2 0 1) = DepthBoundedPaths 1 []"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def bounded_paths_def)
lemma unreachable_cut:
 "graph_dispatch 8 8 4 fixture (CheckUnreachable 2 0 [2]) = Unreachable [2]"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def cut_check_def)
lemma negative_integer_retained: "weight (e01\<lparr>weight := -3\<rparr>) = -3" by simp
lemma mst_triangle:
 "graph_dispatch 8 8 4 (fixture\<lparr>directed:=False\<rparr>) ReferenceMinimumSpanningTree = MinimumTree [e01,e12] 5"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def spanning_candidates_def
   spanning_tree_def path_cost_def reach_step.simps)
lemma isolated_vertex_disconnected:
 "graph_dispatch 8 8 4 (fixture\<lparr>vertices:=[0,1,2,3],directed:=False\<rparr>) ReferenceMinimumSpanningTree = Disconnected"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def spanning_candidates_def
   spanning_tree_def path_cost_def reach_step.simps)
lemma duplicate_row_rejected:
 "graph_dispatch 8 8 4 (fixture\<lparr>edges:=[e01,e01]\<rparr>) MinimumSpanningTree = MalformedGraph"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def)
lemma witness_budget:
 "graph_dispatch 8 8 0 fixture (CheckPath 0 2 [e02]) = MaterializationBound"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def)
lemma negative_edge_shortest_certificate:
 "graph_dispatch 8 8 4 (fixture\<lparr>edges:=[e01\<lparr>weight := -3\<rparr>,e12,e02]\<rparr>)
   (CheckShortest 0 2 [e01\<lparr>weight := -3\<rparr>,e12] [(0,0),(1,-3),(2,0)]) =
   ShortestPath [e01\<lparr>weight := -3\<rparr>,e12] 0"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def shortest_certificate_def
   feasible_path_def potential_check_def path_cost_def)
lemma equal_optimum_retained:
 "graph_dispatch 8 8 4 (fixture\<lparr>edges:=[e01,e12,e02\<lparr>weight:=5\<rparr>]\<rparr>)
   (CheckShortest 0 2 [e02\<lparr>weight:=5\<rparr>] [(0,0),(1,2),(2,5)]) =
   ShortestPath [e02\<lparr>weight:=5\<rparr>] 5"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def shortest_certificate_def
   feasible_path_def potential_check_def path_cost_def)
lemma cycle_survives_depth_search:
 "[e01,e12,\<lparr>row_key=13,relation_key=10,tail=2,head=0,weight=1\<rparr>] \<in>
   set (bounded_paths 3
     (fixture\<lparr>edges:=[e01,e12,\<lparr>row_key=13,relation_key=10,tail=2,head=0,weight=1\<rparr>]\<rparr>) 0 0)"
 by (simp add: bounded_paths_exact feasible_path_def fixture_defs edge_enabled_def edge_target_def)
lemma bfs_returns_feasible_not_weight_optimum:
 "graph_dispatch 8 8 4 fixture (SearchPath 0 2 4 10 8) = FeasiblePath [e02] 8"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def propose_path_def
   feasible_path_def path_cost_def Let_def)
lemma bfs_fuel_exhaustion_is_not_unreachable:
 "graph_dispatch 8 8 4 fixture (SearchPath 0 2 4 0 8) = SearchExhausted ExpansionBound"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def propose_path_def)
lemma bfs_depth_exhaustion_is_not_unreachable:
 "graph_dispatch 8 8 4 fixture (SearchPath 0 2 0 10 8) = SearchExhausted DepthBound"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def propose_path_def cut_check_def Let_def)
lemma enumeration_output_cap:
 "graph_dispatch 8 8 10 fixture (EnumeratePaths 0 2 10) = SearchExhausted OutputBound"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs edge_enabled_def edge_target_def wellformed_graph_def enumeration_fits_def)
lemma kruskal_triangle_proposal:
 "kruskal_proposal (fixture\<lparr>directed:=False\<rparr>) = [e01,e12]"
 by (simp add: kruskal_proposal_def fixture_defs Let_def)
lemma kruskal_triangle_checked_feasible:
 "feasible_tree_check (fixture\<lparr>directed:=False\<rparr>)
   (kruskal_proposal (fixture\<lparr>directed:=False\<rparr>))"
 by (simp add: kruskal_triangle_proposal feasible_tree_check_def canonical_tree_def fixture_defs edge_enabled_def edge_target_def)
lemma undirected_reverse_original_edges:
 "graph_dispatch 8 8 4 (fixture\<lparr>directed:=False\<rparr>) (CheckPath 2 0 [e12,e01]) = FeasiblePath [e12,e01] 5"
 by (simp add: graph_dispatch_def graph_work_guard_def graph_work_def graph_validation_work_def fixture_defs
   edge_enabled_def edge_target_def wellformed_graph_def feasible_path_def path_cost_def)
definition fixture_shortest_call where
 "fixture_shortest_call = CheckShortest 0 2 [e01,e12] [(0,0),(1,2),(2,5)]"
definition fixture_auto_shortest_call where "fixture_auto_shortest_call = ShortestPathQuery 0 2"
definition fixture_reverse_shortest_call where "fixture_reverse_shortest_call = ShortestPathQuery 2 0"
definition fixture_undirected where "fixture_undirected = fixture\<lparr>directed:=False\<rparr>"
definition run_fixture where "run_fixture call = graph_dispatch 8 8 4 fixture call"
definition run_mst_fixture where
 "run_mst_fixture call = graph_dispatch 8 8 4 fixture_undirected call"
definition run_disconnected_fixture where
 "run_disconnected_fixture call = graph_dispatch 8 8 4
   (fixture\<lparr>vertices:=[0,1,2,3],directed:=False\<rparr>) call"
ML \<open>
  val _ = (case @{code run_fixture} @{code fixture_auto_shortest_call} of
      @{code ShortestPath} (rows, _) => if length rows=2 then () else error "automatic shortest witness lost"
    | _ => error "automatic checked shortest failed");
  val _ = (case @{code run_mst_fixture} @{code fixture_reverse_shortest_call} of
      @{code ShortestPath} (rows, _) => if length rows=2 then () else error "undirected reverse witness lost"
    | _ => error "undirected checked shortest failed");
  val _ = (case @{code run_fixture} @{code fixture_shortest_call} of
      @{code ShortestPath} (witness, _) =>
        if length witness = 2 then () else error "graph generated witness lost rows"
    | _ => error "graph generated shortest certificate rejected");
  val _ = (case @{code run_fixture} @{code MinimumSpanningTree} of
      @{code DirectedMSTRejected} => ()
    | _ => error "graph generated MST accepted directed input");
  val _ = (case @{code run_mst_fixture} @{code MinimumSpanningTree} of
      @{code MinimumTree} (rows, _) =>
        if length rows=2 then () else error "graph generated MST lost witness"
    | _ => error "graph generated MST certificate failed");
  val _ = (case @{code run_disconnected_fixture} @{code MinimumSpanningTree} of
      @{code DisconnectedGraph} _ => ()
    | _ => error "graph generated disconnection certificate failed");
\<close>
end
