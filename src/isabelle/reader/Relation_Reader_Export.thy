theory Relation_Reader_Export
  imports Relation_Reader
begin

definition route_admitted :: "question_features \<Rightarrow> natural option" where
  "route_admitted f = route f admitted_patterns_v4"

export_code decide_admitted route_admitted reason_name admitted_patterns_v4 time_variant
  Entity Literal Blank Answer Refuse candidate_ext question_features_ext
  natural_of_integer integer_of_natural
  in SML module_name Relation_Reader_Code file_prefix relation_reader

text \<open>The same program, written where the MLton build (tools/reader/build_decide.sh) reads it. Its SHA-1
is printed as a build marker, so the binary can be tied to this session's receipt.\<close>
ML \<open>
local
  val consts = [@{const_name decide_admitted}, @{const_name route_admitted}, @{const_name reason_name},
    @{const_name admitted_patterns_v4}, @{const_name time_variant},
    @{const_name Entity}, @{const_name Literal}, @{const_name Blank}, @{const_name Answer},
    @{const_name Refuse}, @{const_name candidate_ext}, @{const_name question_features_ext},
    @{const_name natural_of_integer}, @{const_name integer_of_natural}]
  val (files, _) = Code_Target.produce_code @{context} false consts "SML" "Relation_Reader_Code" NONE []
  val text = implode (map (Bytes.content o snd) files)
  val dir = Path.append (Resources.master_directory @{theory}) (Path.explode "../../../var/reader/gen")
  val _ = Isabelle_System.make_directory dir
  val _ = File.write (Path.append dir (Path.basic "Relation_Reader_Code.ML")) text
in
  val _ = writeln ("VERI7VN_READER code sha1=" ^ Message_Digest.rep (SHA1.digest text))
end
\<close>

end
