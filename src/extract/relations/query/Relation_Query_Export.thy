theory Relation_Query_Export
  imports Relation_Query "Veri7vn_Relations.Relation_Tables"
begin

export_code decide_query query_scope identity_ambiguity prop_of key qid dir domain_member candidates spec_of sid readers roots occs excl guard rkey rprop nfwd ninv dfwd dinv
  AnyQuery UnknownQuery QueryInstance QueryPropertyClass EitherQuery
  AnySubject UnknownSubject InstanceOf OccupationOf HasValue Both subject_matches
  Entity Literal Blank Fwd Inv Answer Decline Incomplete Silent
  candidate_ext attempt_ext question_features_ext
  natural_of_integer integer_of_natural
  in SML module_name Relation_Reader_Code file_prefix relation_reader

ML \<open>
  val theorems = @{thms query_scope_members identity_forward_decision queried_forward_answer
    query_genre_witness unqualified_query_unchanged inverse_query_unchanged};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error "query constraint theorems use oracles";
  val marker = "VERI7VN_RELATION_QUERY PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0";
  val _ = writeln marker;
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/query")) [XML.Text marker];
\<close>
end
