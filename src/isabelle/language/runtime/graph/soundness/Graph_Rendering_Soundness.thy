theory Graph_Rendering_Soundness
  imports Veri7vn_Graph_Rendering.Graph_Rendering
    Veri7vn_Graph_Source_Soundness.Graph_Source_Soundness
begin

text \<open>General graph correctness, including minimum-tree optimality, remains in
this optional proof child. The light renderer and this theorem use the same sole
dispatch evaluator; no cheaper competing evaluator is introduced.\<close>

lemma actual_graph_execution_display_meaning:
  "graph_display_meaning request batch
    (source_graph_display c context (run_structured_graph_query request batch))"
  by (simp add: graph_display_meaning_def source_graph_display_correspondence
    structured_graph_query_refinement)

lemma acquired_graph_v1_execution_display_meaning:
  "acquire_native acquisition context bytes = Some (batch,observation) \<Longrightarrow>
    acquired_graph_v1_display_meaning acquisition context bytes request batch
      (source_graph_display c context (run_structured_graph_query request batch))"
  by (auto simp: acquired_graph_v1_display_meaning_def source_context_preserved
    actual_graph_execution_display_meaning)

lemma checked_graph_execution_preserves_meaning:
  assumes "checked_source_graph_display c context (run_structured_graph_query request batch) = Some display"
  shows "graph_display_meaning request batch display"
  using assms actual_graph_execution_display_meaning
  by (auto simp: checked_source_graph_display_def split: if_splits)

end
