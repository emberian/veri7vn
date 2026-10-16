theory Session_Source
  imports Veri7vn_Admission.Veri7vn_Admission
    Veri7vn_Observation_Pin.Observation_Pin
begin
ML_file \<open>../native_session_input_codec.ML\<close>
ML_file \<open>../../../isabelle/admission/recovery/native_checked_session_input.ML\<close>
ML_file \<open>../../../isabelle/admission/recovery/native_session_input_recovery.ML\<close>
ML_file \<open>../native_session_context.ML\<close>
ML_file \<open>../native_session_entry.ML\<close>
ML_file \<open>../../../isabelle/admission/recovery/native_session_input_export.ML\<close>
end
