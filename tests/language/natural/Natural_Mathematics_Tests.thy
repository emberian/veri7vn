theory Natural_Mathematics_Tests
  imports Veri7vn_Natural_Mathematics.Natural_Mathematics
begin
definition sum_rule :: binary_rule where
  "sum_rule=\<lparr>cue_before=[116,104,101,32,115,117,109,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Sum\<rparr>"
lemma negative_original_literal:
  "attempt_binary [116,104,101,32,115,117,109,32,111,102,32,45,50,32,97,110,100,32,51] sum_rule 13=Some (Reading
    \<lparr>expression=Plus (Rational (-2)) (Rational 3),
      literal_spans=[(11,13),(18,19)],declared_operation=Sum\<rparr>)"
  by (simp add: attempt_binary_def sum_rule_def Let_def slice_def
    integer_literal_def read_integer_def read_unsigned_def)
lemma invalid_literal_is_blocked_not_unrecognized:
  "attempt_binary [116,104,101,32,115,117,109,32,111,102,32,98,97,100,32,97,110,100,32,51] sum_rule 14=Some (LiteralBlocked [(11,14)])"
  by (simp add: attempt_binary_def sum_rule_def Let_def slice_def
    integer_literal_def read_integer_def read_unsigned_def)
lemma valid_left_capture_is_not_a_blocker:
  "attempt_binary [116,104,101,32,115,117,109,32,111,102,32,50,32,97,110,100,32,98,97,100] sum_rule 12=Some (LiteralBlocked [(17,20)])"
  by (simp add: attempt_binary_def sum_rule_def Let_def slice_def
    integer_literal_def read_integer_def read_unsigned_def)
end
