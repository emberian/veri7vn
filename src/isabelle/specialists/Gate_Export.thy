theory Gate_Export
  imports Specialist_Contract Arbitration Exam_Gate
begin

text \<open>The decision functions as Standard ML.  The checker \<^verbatim>\<open>tools/gate/check_verdicts.py\<close> extracts
  this export from the session database, compiles it with Isabelle's bundled MLton, and feeds it the
  counts from the shipped verdict files.\<close>

export_code accept spec_reply fillable compose exam_turn Answered Withheld
  Cand arbitrate combo_chat Fallthrough Pick Disagree
  Exam Tally need wrong_cap lane_cap reasons admit decide Dev Heldout
  DOMAIN FALSE_YES WRONG LANE SELF BUDGET ADMIT NEGATIVE WOULD_PASS WOULD_FAIL
  nat_of_integer integer_of_nat
  in SML module_name Veri7vn_Gate file_prefix "veri7vn_gate"

end
