theory Novel_Reader_Export
  imports "HOL-Library.Code_Target_Numeral" Novel_Reader
begin

export_code decide_spec attempt_values attempt_decline transparent
  Entity Literal Blank Answer Decline Incomplete Silent
  candidate_ext attempt_ext question_features_ext
  readers in_table dropped prop_of time_variant
  natural_of_integer integer_of_natural
  in SML module_name Novel_Reader_Code file_prefix novel_reader

ML \<open>
  val theorems = @{thms answer_stored decline_stored decline_meaning attempt_values_sound
    incomplete_meaning silent_meaning walk_answer_exists no_answer_when_none select_subset
    select_nonempty select_head table_props in_table_iff dropped_iff set_vals domain_member_roots
    agreed_unfold walk_decline_inv};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("novels theorems use oracles: " ^ string_of_int (length oracles));
  val _ = writeln ("VERI7VN_NOVELS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
