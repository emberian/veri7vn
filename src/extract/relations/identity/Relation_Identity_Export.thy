theory Relation_Identity_Export
  imports Relation_Identity "Veri7vn_Relations.Relation_Tables"
begin

export_code decide_identity identity_ambiguity prop_of key qid dir domain_member candidates spec_of sid readers roots occs excl guard rkey rprop nfwd ninv dfwd dinv
  AnySubject UnknownSubject InstanceOf OccupationOf HasValue Both subject_matches
  Entity Literal Blank Fwd Inv Answer Decline Incomplete Silent
  candidate_ext attempt_ext question_features_ext
  natural_of_integer integer_of_natural
  in SML module_name Relation_Reader_Code file_prefix relation_reader

ML \<open>
  val theorems = @{thms inverse_identity_choice_sound inverse_identity_choice_member
    identity_answer_witness choice_snapshot_singleton inverse_answer_snapshot_identity
    identity_forward_unchanged identity_ambiguity_meaning};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error "identity theorems use oracles";
  val _ = writeln ("VERI7VN_RELATION_IDENTITY PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
