theory Veri7vn_Source_Admission
  imports "Veri7vn_Row_Kernel.Veri7vn_Row_Kernel"
    "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets"
begin

text \<open>This family judgment is separate from generic theorem admission.
The source requirement, metadata, original wire, query and context are retained
as exact arguments. It does not assert external-world truth or authenticate a
host acquisition attempt. The native association constructor must additionally
consume that actual host boundary and the immutable owned output reservation.\<close>
definition source_output_judgment where
  "source_output_judgment acquisition manifest bytes context query batch observation trace \<longleftrightarrow>
    manifest_matches acquisition manifest \<and>
    snapshot_wellformed (batch_snapshot batch) \<and>
    encode_wire batch = bytes \<and>
    observation = attach_batch (source_assertion_metadata manifest)
      (source_observation_metadata manifest) batch \<and>
    trace = requested_acquired_meaning context query [observation]"

lemma fixed_pipeline_output_judgment:
  "acquire_and_query acquisition manifest bytes context query = Some (batch, observation, trace)
    \<Longrightarrow> source_output_judgment acquisition manifest bytes context query batch observation trace"
  by (auto simp: source_output_judgment_def dest: acquire_and_query_refinement)

definition source_relation_snapshot_judgment where
  "source_relation_snapshot_judgment acquisition manifest bytes request observation result \<longleftrightarrow>
    (\<exists>batch. manifest_matches acquisition manifest \<and>
      snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bytes \<and>
      observation = attach_batch (source_assertion_metadata manifest)
        (source_observation_metadata manifest) batch \<and>
      structured_relation_snapshot_meaning request batch result)"
lemma fixed_relation_snapshot_judgment:
  "acquire_and_query_structured_relation acquisition manifest bytes request = Some (observation,result)
    \<Longrightarrow> source_relation_snapshot_judgment acquisition manifest bytes request observation result"
  by (auto simp: source_relation_snapshot_judgment_def dest: acquired_structured_relation_refinement)

text \<open>This judgment is exact decoded-snapshot observation. Neither the
source-declared materialization flag nor a Unique constructor licenses an NL
reading, complete external population, or external-world fact. The managed
consumer retains its original encoded inputs and ownership dependencies.\<close>

ML_file "../../execution/instance/row_instance.ML"
ML_file "source_admission.ML"

end
