theory Facts_Check
  imports Facts
begin

text \<open>Oracle-free check of the lookup families' theorems and self tests.\<close>

definition facts_self_test :: bool where
  "facts_self_test \<longleftrightarrow> grammar_self_test \<and> myth_self_test \<and> us_self_test \<and> library_self_test \<and> gov_self_test"

export_code facts_self_test in SML module_name FactsSelf file_prefix factsself

ML \<open>
  val theorems = [@{thm pick_some}, @{thm pick_none},
    @{thm first_known_some}, @{thm first_known_none}, @{thm ord_suffix_teens}, @{thm ord_suffix_units},
    @{thm gkernel_row}, @{thm gkernel_first_candidate}, @{thm gkernel_silent_no_flag},
    @{thm gkernel_silent_unknown}, @{thm gkernel_silent_past}, @{thm gkernel_silent_plural}, @{thm gkernel_silent_comparison}, @{thm greply_answered_iff},
    @{thm g2r_first_match}, @{thm r2g_first_match}, @{thm g2r_no_bit}, @{thm domain_value},
    @{thm role_value}, @{thm r2g_from_g2r}, @{thm g2r_in_r2g},
    @{thm yreply_answered_iff},
    @{thm nth_value}, @{thm numbers_of_iff}, @{thm num_value}, @{thm event_value},
    @{thm event_silent_ambiguous}, @{thm hreply_answered_iff},
    @{thm chk13_valid}, @{thm chk13_unique}, @{thm chk13_valid_iff}, @{thm chk10_valid},
    @{thm chk10_unique}, @{thm chk10_valid_iff}, @{thm chkissn_valid}, @{thm chkissn_unique},
    @{thm chkissn_valid_iff}, @{thm issn_check_value}, @{thm issn_valid_value},
    @{thm isbn_convert_value}, @{thm isbn13_check_value}, @{thm isbn10_check_value},
    @{thm isbn13_valid_value}, @{thm isbn10_valid_value}, @{thm bad_length}, @{thm bad_issn},
    @{thm lcc_sub_value}, @{thm lcc_class_value}, @{thm lcc_unused_value},
    @{thm lcc_subject_first_match},
    @{thm lreply_answered_iff},
    @{thm amendments_count}, @{thm articles_count}, @{thm topics_are_amendments},
    @{thm electors_sum}, @{thm electoral_majority}, @{thm amendment_count_fact},
    @{thm bill_of_rights_is_first_ten}, @{thm topic_value}, @{thm amend_value},
    @{thm amend_impossible}, @{thm article_value}, @{thm fact_value}, @{thm vreply_answered_iff}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("facts theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code facts_self_test} then () else error "facts self test failed";
  val _ = writeln ("VERI7VN_HUMANITIES_FACTS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
