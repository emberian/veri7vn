theory Humanities_Export
  imports "Veri7vn_Humanities_Music.Music" "Veri7vn_Humanities_Facts.Facts"
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from the
numerals and words it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition all_self_test :: bool where
  "all_self_test \<longleftrightarrow> music_self_test \<and> grammar_self_test \<and> myth_self_test \<and> us_self_test
                    \<and> library_self_test \<and> gov_self_test"

export_code mreply greply yreply hreply vreply lreply answered reply_kind response stated mk_rat
  integer_of_int int_of_integer nat_of_integer integer_of_nat
  ivl_order g2r_rows r2g_rows greek_domain norse_domain roles presidents events topic_nums fact_rows
  subject_order
  MCents MDur MKey MRel MScale MSemis MBetween MMidiNote MMidiNum MFreq
  N_C N_D N_E N_F N_G N_A N_B D_whole D_half D_quarter D_eighth D_sixteenth D_thirty_second
  GReq YG2R YR2G YDomain YRole P_greek P_roman P_norse HNth HNum HEvent
  VTopic VAmend VArticle VFact LIsbn LCode LSubject
  in SML module_name Humanities file_prefix humanities

ML \<open>
  val theorems = [@{thm fixed3_err}, @{thm to_fixed3_sound}, @{thm enclose3_sound},
    @{thm pick_some}, @{thm pick_none},
    @{thm keysig_formula_is_table}, @{thm keysig_circle_of_fifths},
    @{thm rel_key_pitch}, @{thm rel_key_letter}, @{thm rel_key_signature},
    @{thm scale_steps_close}, @{thm scale_note_letter}, @{thm scale_note_pitch}, @{thm scale_first},
    @{thm scale_adjacent}, @{thm scale_adjacent_distance}, @{thm scale_matches_signature},
    @{thm qual_rows_rule}, @{thm qual_rows_distinct}, @{thm qual_lookup_sound},
    @{thm midi_pitch}, @{thm between_sound}, @{thm midi_name_roundtrip},
    @{thm dur_defining}, @{thm dur_quarter_60}, @{thm beats_halving}, @{thm dotted_adds_half},
    @{thm freq_a4}, @{thm freq_octave}, @{thm freq_semitone}, @{thm cents_model},
    @{thm key_value}, @{thm key_theoretical}, @{thm key_matches_organ_table},
    @{thm relative_value}, @{thm scale_value}, @{thm scale_double_accidental},
    @{thm semitones_named}, @{thm semitones_named_none}, @{thm between_semitones},
    @{thm between_interval}, @{thm midi_note_value}, @{thm midi_note_impossible},
    @{thm midi_kernel_roundtrip}, @{thm midi_number_value}, @{thm midi_number_underspecified}, @{thm freq_underspecified},
    @{thm freq_value}, @{thm cents_value}, @{thm duration_value},
    @{thm mreply_answered_iff}, @{thm mreply_silent}, @{thm mreply_withheld_names_decline},
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
  val _ = if null oracles then () else error ("humanities theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code all_self_test} then () else error "humanities self test failed";
  val _ = writeln ("VERI7VN_HUMANITIES PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
