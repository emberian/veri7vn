theory Graph_Acquisition
 imports Graph_Source_Resources
begin

definition run_associated_graph_query where
 "run_associated_graph_query request a =
   run_structured_graph_query request (association_batch a)"

definition associated_graph_snapshot_meaning where
 "associated_graph_snapshot_meaning request a result \<longleftrightarrow>
   source_association_meaning a \<and>
   manifest_matches (association_requirement a) (association_manifest a) \<and>
   versioned_source_represents (association_requirement a)
     (association_original_bytes a) (association_batch a) \<and>
   association_observation a = attach_batch (source_assertion_metadata (association_manifest a))
     (source_observation_metadata (association_manifest a)) (association_batch a) \<and>
   structured_graph_snapshot_meaning request (association_batch a) result"

lemma associated_graph_path_query_refinement:
 assumes "source_association_meaning a" "source_graph_path_request request"
 shows "associated_graph_snapshot_meaning request a (run_associated_graph_query request a)"
 using assms source_association_representation[OF assms(1)]
   structured_graph_path_query_refinement[OF assms(2), of "association_batch a"]
 by (simp only: associated_graph_snapshot_meaning_def run_associated_graph_query_def; blast)

text \<open>This pure entry consumes one retained acquisition association. Its manifest,
original bytes, batch and observation remain the same across observers. The HOL
constructor does not grant publication authority; the protected source producer
must supply its opaque association and charge the scalar guards before work.
Graph statuses retain their finite imported-snapshot scope and adoption conditions.\<close>
end
