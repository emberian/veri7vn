theory Native_Request_Scope
  imports Veri7vn_Admission.Veri7vn_Admission
    Veri7vn_Authority_Codec.Authority_Codec
begin
definition scope_checkpoint_plan_matches :: "authority_state \<Rightarrow> nat \<Rightarrow>
    (nat \<times> nat \<times> nat \<times> nat list) list \<Rightarrow> (nat \<times> nat) list \<Rightarrow> bool" where
  "scope_checkpoint_plan_matches s rid original required =
    (\<exists>r\<in>set (requests s). request_id r=rid \<and>
      request_observation r=StateTimeUnused \<and> request_session r=None \<and>
      list_all (\<lambda>g. goal_output_slot g\<noteq>None) (request_goals r) \<and>
      map (\<lambda>g. (goal_id g,the (goal_output_slot g),goal_interpretation g,
        map dependency_goal (goal_dependencies g))) (request_goals r)=original \<and>
      map (\<lambda>rg. (goal_id (snd rg),the (goal_output_slot (snd rg))))
        (filter (\<lambda>rg. request_id (fst rg)=rid) (required_native_children s))=required)"
definition scope_checkpoint_parent_active :: "authority_state \<Rightarrow> nat \<Rightarrow> bool" where
  "scope_checkpoint_parent_active s rid = (\<exists>r\<in>set (requests s).
    request_id r=rid \<and> \<not>request_cancelled r \<and> parent_accessible s r)"
ML_file \<open>recovery/native_checked_scope.ML\<close>
ML_file \<open>native_scope_checkpoint.ML\<close>
ML_file \<open>recovery/native_scope_recovery.ML\<close>
ML_file \<open>native_request_scope.ML\<close>
ML_file \<open>native_entry_control.ML\<close>
end
