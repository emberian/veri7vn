theory Literal_Grammar_Tests
  imports Veri7vn_Interpretation_Core.Veri7vn_Grammar
begin

lemma two_spaces_survive:
  "literal_argument [0::nat, 65,32,32,66,0] (1,5) = [65,32,32,66]"
  by (simp add: literal_argument_def slice_def)
lemma collapse_changes_payload:
  "literal_argument [65::nat,32,32,66] (0,4) \<noteq> [65,32,66]"
  by (simp add: literal_argument_def slice_def)
lemma normalized_cues_literal_payload:
  "normalized_view [72::nat,65,32,32,66]
    [Language (0,1) [104], Literal (1,5)] = [104,65,32,32,66]"
  by (simp add: normalized_view_def slice_def)
lemma multiline_json_position:
  "literal_argument [0::nat,123,10,32,125,0] (1,5) ! 1 = 10"
  by (simp add: literal_argument_def slice_def)
lemma case_sensitive_token:
  "literal_argument [65::nat,97] (0,2) \<noteq> literal_argument [97,97] (0,2)"
  by (simp add: literal_argument_def slice_def)
lemma title_not_pronoun:
  "literal_argument [89::nat,111,117] (0,3) \<noteq> [121,111,117]"
  by (simp add: literal_argument_def slice_def)
lemma source_map_with_deleted_segment:
  "well_mapped [1::nat,2,3]
    [Language (0,1) [], Literal (1,3)]"
  by (simp add: well_mapped_def valid_span_def)
lemma two_readings_remain_ambiguous:
  "recognize [0::nat,1] = Ambiguous [0,1]"
  by simp

lemma hash_request_uses_original_payload:
  "specialist_request [104::nat,97,115,104,32] 34 4 Some
    [104,97,115,104,32,34,65,32,32,66,34] 0 =
    [(((6,10),[65,32,32,66]),11)]"
  by (simp add: specialist_request_def quoted_capture_def project_def sequence_def
    token_def capture_def slice_def)
lemma missing_quote_has_no_derivation:
  "specialist_request [104::nat,97,115,104,32] 34 4 Some
    [104,97,115,104,32,34,65,32,32,66] 0 = []"
  by (simp add: specialist_request_def quoted_capture_def project_def sequence_def
    token_def capture_def slice_def)
datatype entity_reading = SeriesTitle nat | Addressee
lemma ambiguous_entity_roles:
  "choice (project (\<lambda>_. SeriesTitle 42) (token [89::nat,111,117]))
          (project (\<lambda>_. Addressee) (token [89,111,117])) [89,111,117] 0 =
    [(SeriesTitle 42,3),(Addressee,3)]"
  by (simp add: choice_def project_def token_def slice_def)

end
