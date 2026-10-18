theory Converse_Export
  imports Converse
begin

export_code resolve choose_query may_rewrite select retain_ground
  Entity Person Thing Unknown Person_ref Thing_ref Answer_thing_ref Subject_ref Number_ref Variable_ref
  Query_slot Answer_slot Number_slot Variable_slot Missing Ambiguous
  Raw_question Context_question Clarify_reference
  Unrecognized Answered Refused Failed Original Rewritten
  in SML module_name Converse file_prefix converse

ML \<open>
  val roots = [@{thm person_requires_human(1)}, @{thm person_requires_human(2)},
    @{thm distinct_people_ambiguous}, @{thm unknown_answer_competes_with_person},
    @{thm unknown_query_competes_with_person}, @{thm unknown_cannot_be_person},
    @{thm query_thing_preferred}, @{thm unknown_query_competes_with_thing}, @{thm answer_thing_requires_answer},
    @{thm incomplete_keeps_raw}, @{thm context_requires_resolved_slot}, @{thm unresolved_never_evaluates_context},
    @{thm absent_numeric_refused(1)}, @{thm absent_numeric_refused(2)},
    @{thm terminal_preserved}, @{thm rewritten_has_candidate},
    @{thm failed_candidate_is_terminal}, @{thm chosen_preserves_payload},
    @{thm one_final_append}, @{thm other_session_unchanged},
    @{thm final_length}, @{thm recall_is_recorded}, @{thm substantive_refusal_clears_ground}];
  val oracles = Thm_Deps.all_oracles roots;
  val _ = if null oracles then () else error "converse theorem uses an oracle";
  val marker = "VERI7VN_CONVERSE PASS theorems=23 oracles=0";
  val _ = writeln marker;
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/converse")) [XML.Text marker];
\<close>
end
