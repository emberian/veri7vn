theory ConceptNet_Acquisition
 imports Veri7vn_Source_Acquisition.Source_Acquisition_Association
   Veri7vn_ConceptNet_Source.ConceptNet_Source
begin

text \<open>This observer consumes the whole same source association. Its HOL
constructor is data; only the fixed managed native producer can supply runtime
ownership. No new acquisition, source decoding, adoption or authority is created.
The source leaf must bound actual result serialization before public emission.\<close>
lemma concept_cell_shared_dimension:
 "concept_cell_size cell=source_cell_payload_bytes cell"
 by (cases cell) simp_all
lemma concept_batch_shared_dimension:
 "concept_payload_size batch=source_batch_payload_bytes batch"
proof -
 have cells: "concept_cell_size=source_cell_payload_bytes"
   by (rule ext) (rule concept_cell_shared_dimension)
 show ?thesis by (simp add: concept_payload_size_def source_batch_payload_bytes_def cells)
qed

definition associated_concept_budget where
 "associated_concept_budget request association = concept_budget_from_dimensions
    (association_rows association) (association_payload_bytes association) request"
definition observe_associated_concept where
 "observe_associated_concept request association =
    run_structured_concept_query request (association_batch association)"

lemma associated_concept_budget_exact:
 "source_association_meaning association \<Longrightarrow>
  associated_concept_budget request association =
    concept_request_budget request (association_batch association)"
 by (simp add: associated_concept_budget_def concept_request_budget_def
    source_association_meaning_def concept_batch_shared_dimension)
lemma associated_concept_precharge_recheck:
 "source_association_meaning association \<Longrightarrow>
  (associated_concept_budget request association\<le>10000000) =
    concept_request_work_permitted request (association_batch association)"
 using associated_concept_budget_exact
 by (simp add: concept_request_work_permitted_def)

definition associated_concept_meaning where
 "associated_concept_meaning request association result \<longleftrightarrow>
  manifest_matches (association_requirement association) (association_manifest association) \<and>
  versioned_source_represents (association_requirement association)
    (association_original_bytes association) (association_batch association) \<and>
  association_observation association = attach_batch
    (source_assertion_metadata (association_manifest association))
    (source_observation_metadata (association_manifest association)) (association_batch association) \<and>
  structured_concept_snapshot_meaning request (association_batch association) result"
lemma associated_concept_refinement:
 "source_association_meaning association \<Longrightarrow>
  associated_concept_meaning request association (observe_associated_concept request association)"
 using source_association_representation concept_query_refinement
 by (auto simp: associated_concept_meaning_def observe_associated_concept_def)

lemma associated_concept_framed_original:
 "source_association_meaning association \<Longrightarrow>
  required_recipe (association_requirement association)=''source-row-codec/2'' \<Longrightarrow>
  source_stream_represents (acquisition_stream_limits (association_requirement association)) True
    (association_original_bytes association) (association_batch association) \<and>
  associated_concept_meaning request association (observe_associated_concept request association)"
 using source_association_framed_representation associated_concept_refinement by blast

export_code associated_concept_budget observe_associated_concept
 in SML module_name ConceptNet_Association_Observer_Code
end
