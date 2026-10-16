theory Graph_Path_Checks
 imports Veri7vn_Graph_Core.Graph_Dispatch
begin

definition path_graph where
 "path_graph = \<lparr>vertices=[0,1,2], edges=
   [\<lparr>row_key=7,relation_key=9,tail=0,head=1,weight= -3\<rparr>,
    \<lparr>row_key=11,relation_key=9,tail=1,head=2,weight=5\<rparr>], directed=True\<rparr>"
lemma path_profile_excludes_minimum_tree:
 "\<not>graph_path_call MinimumSpanningTree"
 "\<not>graph_path_call ReferenceMinimumSpanningTree"
 by simp_all
lemma checked_search_has_path_meaning:
 "graph_reply_meaning 8 8 4 path_graph (SearchPath 0 2 4 8 8)
   (graph_dispatch 8 8 4 path_graph (SearchPath 0 2 4 8 8))"
 by (rule graph_path_dispatch_refinement) simp

definition path_consumer where
 "path_consumer ignored =
   (graph_dispatch 8 8 4 path_graph (SearchPath 0 2 4 8 8),
    graph_dispatch 8 8 4 path_graph (ShortestPathQuery 0 2),
    graph_dispatch 8 8 4 path_graph (SearchPath 2 0 4 8 8),
    graph_dispatch 8 8 4 path_graph (SearchPath 0 2 4 0 8))"
ML \<open>
 val _ = (case @{code path_consumer} () of
   (@{code FeasiblePath} (es,cost), (@{code ShortestPath} (optimal,minimum),
     (@{code Unreachable} _, @{code SearchExhausted} @{code ExpansionBound}))) =>
      if length es=2 andalso length optimal=2 andalso
         Veri7vn_Numerals.integer_of_int cost=2 andalso Veri7vn_Numerals.integer_of_int minimum=2
      then () else error "light path consumer lost witness or signed cost"
   | _ => error "light path consumer status mismatch");
 val _ = writeln "VERI7VN_GRAPH_PATH_CONSUMER_PASS";
\<close>
end
