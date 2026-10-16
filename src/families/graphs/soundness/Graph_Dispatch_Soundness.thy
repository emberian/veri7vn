theory Graph_Dispatch_Soundness
 imports Veri7vn_Graph_Core.Graph_Dispatch Graph_MST_Optimality
begin

lemma disconnected_certificate_sound:
 "disconnected_certificate_check g cut \<Longrightarrow> \<not> spanning_tree g tree"
 using spanning_tree_crosses_proper_cut by (auto simp: disconnected_certificate_check_def)

lemma dispatch_default_mst_sound:
  "graph_dispatch nv ne nd g MinimumSpanningTree = MinimumTree tree cost \<Longrightarrow>
    \<not> directed g \<and> minimum_tree g tree \<and> cost=path_cost tree"
  using partition_dual_check_sound
  by (auto simp: graph_dispatch_def Let_def split: if_splits)

lemma dispatch_default_disconnected_sound:
 "graph_dispatch nv ne nd g MinimumSpanningTree = DisconnectedGraph cut \<Longrightarrow>
  \<not> spanning_tree g tree"
 using disconnected_certificate_sound
 by (auto simp: graph_dispatch_def Let_def split: if_splits)

lemma spanning_tree_in_candidates:
 assumes "spanning_tree g tree"
 shows "tree\<in>set (spanning_candidates g)"
proof -
 have "tree\<in>set (subsets (edges g))"
   using assms unfolding spanning_tree_def by blast
 then show ?thesis using assms by (simp add: spanning_candidates_def)
qed

lemma no_cheapest_no_tree:
 assumes "cheapest (spanning_candidates g)=None"
 shows "\<not>(\<exists>tree. spanning_tree g tree)"
proof -
 have "spanning_candidates g=[]" using assms cheapest_none by blast
 then show ?thesis using spanning_tree_in_candidates by fastforce
qed

lemma graph_dispatch_refinement:
 "graph_reply_meaning nv ne nd g call (graph_dispatch nv ne nd g call)"
proof (cases call)
 case (CheckPath s t es)
 show ?thesis by (rule graph_path_dispatch_refinement) (simp add: CheckPath)
next
 case (CheckShortest s t es ds)
 show ?thesis by (rule graph_path_dispatch_refinement) (simp add: CheckShortest)
next
 case (CheckUnreachable s t cut)
 show ?thesis by (rule graph_path_dispatch_refinement) (simp add: CheckUnreachable)
next
 case (EnumeratePaths s t depth)
 show ?thesis by (rule graph_path_dispatch_refinement) (simp add: EnumeratePaths)
next
 case (ShortestPathQuery s t)
 show ?thesis by (rule graph_path_dispatch_refinement) (simp add: ShortestPathQuery)
next
 case (SearchPath s t depth fuel frontier)
 show ?thesis by (rule graph_path_dispatch_refinement) (simp add: SearchPath)
next
 case MinimumSpanningTree
 then show ?thesis using feasible_tree_check_sound partition_dual_check_sound
   by (auto simp: graph_reply_meaning_def graph_dispatch_def Let_def)
next
 case ReferenceMinimumSpanningTree
 then show ?thesis using minimum_tree_sound no_cheapest_no_tree
   by (auto simp: graph_reply_meaning_def graph_dispatch_def split: option.splits)
qed

end
