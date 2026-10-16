theory Natural_Source_Rows_Tests
  imports Veri7vn_Natural_Source_Rows.Natural_Source_Rows
begin
lemma observed_original_capture:
  "source_key_capture observed_cue [104,111,119,32,109,97,110,121,32,111,98,115,101,114,118,101,100,32,114,111,119,115,32,105,110,32,115,111,117,114,99,101,32,97,32,32,98,63] =
    Some ([97,32,32,98],(33,37))"
  by (simp add: source_key_capture_def observed_cue_def slice_def Let_def)
lemma generic_question_preserves_two_scopes:
  "map row_question_scope (case interpret_source_rows [104,111,119,32,109,97,110,121,32,114,111,119,115,32,105,110,32,115,111,117,114,99,101,32,115,97,109,112,108,101,63] of
      SourceReadings rs \<Rightarrow> rs | _ \<Rightarrow> []) =
    [ObservedSnapshot,FullSourceTotal]"
  by (simp add: interpret_source_rows_def source_key_capture_def observed_cue_def
    total_cue_def source_readings_def slice_def Let_def)
lemma empty_key_is_not_zero:
  "interpret_source_rows [104,111,119,32,109,97,110,121,32,111,98,115,101,114,118,101,100,32,114,111,119,115,32,105,110,32,115,111,117,114,99,101,32,63] = SourceKeyRequired"
  by (simp add: interpret_source_rows_def source_key_capture_def observed_cue_def
    slice_def Let_def)
end
