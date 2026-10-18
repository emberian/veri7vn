theory Relation_Request_Export
  imports Relation_Request "Veri7vn_Relations.Relation_Tables"
begin

export_code decide_requested spec_of sid readers roots occs excl guard rkey rprop nfwd ninv dfwd dinv
  AnySubject UnknownSubject InstanceOf OccupationOf HasValue Both subject_matches
  Entity Literal Blank Fwd Inv Answer Decline Incomplete Silent
  candidate_ext attempt_ext question_features_ext
  natural_of_integer integer_of_natural
  in SML module_name Relation_Reader_Code file_prefix relation_reader

ML \<open>
  val theorems = @{thms requested_inverse_answer requested_forward_unchanged
    requested_occupation_witness requested_property_witness scope_inverse_subjects};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error "request-scope theorems use oracles";
  val _ = writeln ("VERI7VN_RELATION_REQUEST PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
