theory Controlled_Templates_Tests
  imports Veri7vn_Controlled_Templates.Checked_Statements
begin
lemma signed_sum: "decode_statement [84,104,101,32,101,120,97,99,116,32,115,117,109,32,111,102,32,45,50,32,97,110,100,32,51,32,105,115,32,49,46] = Some (ExactSum (-2) 3 1)"
  by code_simp
lemma fraction_quotient: "decode_statement [84,104,101,32,101,120,97,99,116,32,113,117,111,116,105,101,110,116,32,111,102,32,49,32,97,110,100,32,50,32,105,115,32,49,47,50,46] = Some (ExactQuotient 1 2 1 2)"
  by code_simp
lemma changed_result_refused:
  "checked_statement (template_view (ExactSum (-2) 3 1))
    [84,104,101,32,101,120,97,99,116,32,115,117,109,32,111,102,32,45,50,32,97,110,100,32,51,32,105,115,32,50,46] = None"
  by code_simp
lemma markup_refused:
  "decode_statement [84,104,101,32,101,120,97,99,116,32,115,117,109,32,111,102,32,49,32,97,110,100,32,50,32,105,115,32,60,115,99,114,105,112,116,62,46] = None"
  by code_simp
lemma false_sentence_not_certified:
  "\<not> statement_meaning [84,104,101,32,101,120,97,99,116,32,115,117,109,32,111,102,32,49,32,97,110,100,32,50,32,105,115,32,52,46]"
  by code_simp
end
