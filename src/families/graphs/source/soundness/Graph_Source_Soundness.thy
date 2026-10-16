theory Graph_Source_Soundness
 imports Veri7vn_Graph_Source.Graph_Source Veri7vn_Graphs.Graph_Dispatch_Soundness
begin

lemma structured_graph_query_refinement:
 "structured_graph_snapshot_meaning request batch (run_structured_graph_query request batch)"
 by (cases request) (auto simp: structured_graph_snapshot_meaning_def run_structured_graph_query_def graph_query_batch_def weighted_graph_query_batch_def
   graph_dispatch_refinement split: option.splits prod.splits)
end
