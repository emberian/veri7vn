theory Relation_Organ_Export
  imports Relation_Organ
begin

export_code organ_decide pattern_decide walk
  Answered Withheld Silence Fwd Inv Continue Stop
  cand_ext attempt_ext turn_ext
  natural_of_integer integer_of_natural
  in SML module_name Relation_Organ_Code file_prefix relation_organ

text \<open>The same program, written where the MLton build (tools/rel-census/build_decide_organ.sh) reads
it. Its SHA-1 is printed as a build marker, so the binary can be tied to this session's receipt.\<close>
ML \<open>
local
  val consts = [@{const_name organ_decide}, @{const_name pattern_decide}, @{const_name walk},
    @{const_name Answered}, @{const_name Withheld}, @{const_name Silence},
    @{const_name Fwd}, @{const_name Inv}, @{const_name Continue}, @{const_name Stop},
    @{const_name cand_ext}, @{const_name attempt_ext}, @{const_name turn_ext},
    @{const_name natural_of_integer}, @{const_name integer_of_natural}]
  val (files, _) = Code_Target.produce_code @{context} false consts "SML" "Relation_Organ_Code" NONE []
  val text = implode (map (Bytes.content o snd) files)
  val dir = Path.append (Resources.master_directory @{theory}) (Path.explode "../../../var/relorgan/gen")
  val _ = Isabelle_System.make_directory dir
  val _ = File.write (Path.append dir (Path.basic "Relation_Organ_Code.ML")) text
in
  val _ = writeln ("VERI7VN_RELORGAN code sha1=" ^ Message_Digest.rep (SHA1.digest text))
end
\<close>

end
