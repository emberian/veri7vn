theory Novel_Reader_Export
  imports "HOL-Library.Code_Target_Numeral" Novel_Reader
begin

export_code decide_spec attempt_values attempt_decline transparent
  Entity Literal Blank Answer Decline Incomplete Silent
  candidate_ext attempt_ext question_features_ext
  readers in_table dropped prop_of time_variant
  natural_of_integer integer_of_natural
  in SML module_name Novel_Reader_Code file_prefix novel_reader

text \<open>The same program, written where the MLton build (tools/reader-novels/build_decide.sh) reads
it. Its SHA-1 is printed as a build marker, so the binary can be tied to this session's receipt.\<close>
ML \<open>
local
  val consts = [@{const_name decide_spec}, @{const_name attempt_values}, @{const_name attempt_decline},
    @{const_name transparent},
    @{const_name Entity}, @{const_name Literal}, @{const_name Blank}, @{const_name Answer},
    @{const_name Decline}, @{const_name Incomplete}, @{const_name Silent},
    @{const_name candidate_ext}, @{const_name attempt_ext}, @{const_name question_features_ext},
    @{const_name readers}, @{const_name in_table}, @{const_name dropped}, @{const_name prop_of},
    @{const_name time_variant},
    @{const_name natural_of_integer}, @{const_name integer_of_natural}]
  val (files, _) = Code_Target.produce_code @{context} false consts "SML" "Novel_Reader_Code" NONE []
  val text = implode (map (Bytes.content o snd) files)
  val dir = Path.append (Resources.master_directory @{theory}) (Path.explode "../../../var/rel-novels/gen")
  val _ = Isabelle_System.make_directory dir
  val _ = File.write (Path.append dir (Path.basic "Novel_Reader_Code.ML")) text
in
  val _ = writeln ("VERI7VN_NOVEL code sha1=" ^ Message_Digest.rep (SHA1.digest text))
end
\<close>

end
