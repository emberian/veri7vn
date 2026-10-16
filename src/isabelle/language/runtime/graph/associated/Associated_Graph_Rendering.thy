theory Associated_Graph_Rendering
  imports Veri7vn_Graph_Rendering.Graph_Rendering
    Veri7vn_Graph_Source.Graph_Acquisition
begin

text \<open>This optional composition consumes the same source association used by
acquisition. It does not decode again, allocate another source carrier, or license
a caller's header. The native observer must supply the actual request and the
licensed claim from its same retained result before emission. The full manifest
here remains private native data, not a public exposure policy.\<close>

lemma associated_graph_path_execution_display_meaning:
  assumes association: "source_association_meaning a"
    and path: "source_graph_path_request request"
    and rendered: "checked_source_graph_display c (association_manifest a)
      (run_associated_graph_query request a) = Some display"
  shows "associated_graph_snapshot_meaning request a (source_graph_display_reply display)"
    and "graph_display_meaning request (association_batch a) display"
    and "source_graph_context display = association_manifest a"
    and "manifest_matches (association_requirement a) (association_manifest a)"
    and "versioned_source_represents (association_requirement a)
      (association_original_bytes a) (association_batch a)"
    and "association_observation a = attach_batch
      (source_assertion_metadata (association_manifest a))
      (source_observation_metadata (association_manifest a)) (association_batch a)"
proof -
  show "associated_graph_snapshot_meaning request a (source_graph_display_reply display)"
    using rendered associated_graph_path_query_refinement[OF association path]
    by (auto simp: checked_source_graph_display_def source_graph_display_correspondence
      split: if_splits)
  show "graph_display_meaning request (association_batch a) display"
    using rendered unfolding run_associated_graph_query_def
    by (rule checked_graph_path_execution_preserves_meaning[OF path])
  show "source_graph_context display = association_manifest a"
    using rendered by (auto simp: checked_source_graph_display_def
      source_context_preserved split: if_splits)
  have representation: "manifest_matches (association_requirement a) (association_manifest a) \<and>
      versioned_source_represents (association_requirement a)
        (association_original_bytes a) (association_batch a) \<and>
      snapshot_data_valid (batch_snapshot (association_batch a)) \<and>
      association_observation a = attach_batch
        (source_assertion_metadata (association_manifest a))
        (source_observation_metadata (association_manifest a)) (association_batch a)"
    using association by (rule source_association_representation)
  show "manifest_matches (association_requirement a) (association_manifest a)"
    using representation by blast
  show "versioned_source_represents (association_requirement a)
      (association_original_bytes a) (association_batch a)"
    using representation by blast
  show "association_observation a = attach_batch
      (source_assertion_metadata (association_manifest a))
      (source_observation_metadata (association_manifest a)) (association_batch a)"
    using representation by blast
qed

end
