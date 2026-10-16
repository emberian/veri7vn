theory Graph_Acquisition_Soundness
 imports Veri7vn_Graph_Source.Graph_Acquisition Graph_Source_Soundness
begin

lemma associated_graph_query_refinement:
 assumes "source_association_meaning a"
 shows "associated_graph_snapshot_meaning request a (run_associated_graph_query request a)"
 using assms source_association_representation[OF assms]
   structured_graph_query_refinement[of request "association_batch a"]
 by (simp only: associated_graph_snapshot_meaning_def run_associated_graph_query_def; blast)

end
