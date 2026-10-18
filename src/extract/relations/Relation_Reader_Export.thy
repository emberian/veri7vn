theory Relation_Reader_Export
  imports "HOL-Library.Code_Target_Numeral" Relation_Tables
begin

export_code decide_spec spec_of sid readers roots occs excl guard rkey rprop nfwd ninv dfwd dinv
  Entity Literal Blank Fwd Inv Answer Decline Incomplete Silent
  candidate_ext attempt_ext question_features_ext
  natural_of_integer integer_of_natural
  in SML module_name Relation_Reader_Code file_prefix relation_reader

ML \<open>
  val theorems = @{thms answer_stored decline_stored disagreeing_senses_never_answer answer_senses_agree
    decline_meaning incomplete_meaning silent_meaning step_silent attempt_values_sound attempt_values_sound_inv
    walk_answer_exists no_answer_when_none walk_decline_inv walk_silent_inv walk_incomplete_inv
    forward_attempt_snapshot forward_answer_snapshot omitted_snapshot_value_breaks_coverage
    in_table_reader select_subset select_nonempty select_head mine_in_candidates set_vals agreed_unfold
    finish_answer step_not_decline spec_of_Some};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("relation theorems use oracles: " ^ string_of_int (length oracles));
  val _ = writeln ("VERI7VN_RELATIONS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
