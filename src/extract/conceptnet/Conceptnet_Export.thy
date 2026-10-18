theory Conceptnet_Export
  imports Conceptnet
begin

text \<open>Every relation the adapter's RELATION_TEMPLATES table names, in table
order; used by the round-trip check below and by the answerer's startup check.\<close>
definition all_rels :: "relation list" where
  "all_rels = [IsA, PartOf, HasA, UsedFor, CapableOf, AtLocation, Causes,
    HasSubevent, HasPrerequisite, MotivatedByGoal, Desires, MadeOf,
    ReceivesAction, HasProperty, Synonym, Antonym, DistinctFrom,
    SimilarTo, RelatedTo]"

lemma all_rels_complete: "r \<in> set all_rels" by (cases r) (simp_all add: all_rels_def)

lemma parse_rel_name_roundtrip:
  "r \<in> set all_rels \<Longrightarrow> parse_relation (rel_name r) = Some r"
  by (cases r) (auto simp: parse_relation_def rel_name_def all_rels_def)

subsection \<open>Monomorphic constructors for the generated code\<close>

text \<open>The record extension constructors are polymorphic in their tail and
cannot be exported directly; these fix the tail to unit.\<close>

definition mk_cedge :: "relation \<Rightarrow> int list \<Rightarrow> int list \<Rightarrow> int \<Rightarrow> int list \<Rightarrow> int list \<Rightarrow> cedge" where
  "mk_cedge r s t w sf ds = \<lparr>c_rel = r, c_start = s, c_end = t, c_weight = w, c_surface = sf, c_dataset = ds\<rparr>"

definition mk_crequest :: "int list \<Rightarrow> (relation \<times> direction) list \<Rightarrow> crequest" where
  "mk_crequest c specs = \<lparr>c_concept = c, c_specs = specs\<rparr>"

lemma mk_cedge_rel [simp]: "c_rel (mk_cedge r s t w sf ds) = r"
  and mk_cedge_start [simp]: "c_start (mk_cedge r s t w sf ds) = s"
  and mk_cedge_end [simp]: "c_end (mk_cedge r s t w sf ds) = t"
  and mk_cedge_weight [simp]: "c_weight (mk_cedge r s t w sf ds) = w"
  and mk_cedge_surface [simp]: "c_surface (mk_cedge r s t w sf ds) = sf"
  and mk_cedge_dataset [simp]: "c_dataset (mk_cedge r s t w sf ds) = ds"
  and mk_crequest_concept [simp]: "c_concept (mk_crequest c specs) = c"
  and mk_crequest_specs [simp]: "c_specs (mk_crequest c specs) = specs"
  by (simp_all add: mk_cedge_def mk_crequest_def)

subsection \<open>Fixtures: real rows of the sealed build (m13e5_conceptnet_build_a_v1)\<close>

definition e_dog_comp :: cedge where
  "e_dog_comp = \<lparr>c_rel = UsedFor, c_start = cp ''dog'', c_end = cp ''companionship'',
    c_weight = 6325000, c_surface = cp ''[[a dog]] is for [[companionship]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition e_dog_guard :: cedge where
  "e_dog_guard = \<lparr>c_rel = UsedFor, c_start = cp ''dog'', c_end = cp ''guarding property'',
    c_weight = 2828000, c_surface = cp ''[[a dog]] is used for [[guarding property]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition e_dog_pet :: cedge where
  "e_dog_pet = \<lparr>c_rel = UsedFor, c_start = cp ''dog'', c_end = cp ''pet'',
    c_weight = 2828000, c_surface = cp ''[[a dog]] is for [[a pet]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition e_dog_antonym :: cedge where
  "e_dog_antonym = \<lparr>c_rel = Antonym, c_start = cp ''dog'', c_end = cp ''again'',
    c_weight = 183000, c_surface = cp ''[[dog]] is the opposite of [[again]]'',
    c_dataset = cp ''/d/verbosity''\<rparr>"

definition dog_edges :: "cedge list" where
  "dog_edges = [e_dog_comp, e_dog_guard, e_dog_pet, e_dog_antonym]"

definition req_dog :: crequest where
  "req_dog = \<lparr>c_concept = cp ''dog'', c_specs = [(UsedFor, Fwd)]\<rparr>"

definition e_kitten_isa_cat :: cedge where
  "e_kitten_isa_cat = \<lparr>c_rel = IsA, c_start = cp ''kitten'', c_end = cp ''cat'',
    c_weight = 4472000, c_surface = cp ''[[a kitten]] is [[a cat]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition e_kitten_isa_frag :: cedge where
  "e_kitten_isa_frag = \<lparr>c_rel = IsA, c_start = cp ''kitten'', c_end = cp ''fragile animal'',
    c_weight = 2000000, c_surface = cp ''[[a kitten]] is [[a fragile animal]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition e_cat_catch :: cedge where
  "e_cat_catch = \<lparr>c_rel = UsedFor, c_start = cp ''cat'', c_end = cp ''catch mice'',
    c_weight = 4000000, c_surface = cp ''You can use [[a cat]] to [[catch mice]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition e_cat_comp :: cedge where
  "e_cat_comp = \<lparr>c_rel = UsedFor, c_start = cp ''cat'', c_end = cp ''companionship'',
    c_weight = 4000000, c_surface = cp ''[[a cat]] is for [[companionship]]'',
    c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

definition kitten_edges :: "cedge list" where
  "kitten_edges = [e_kitten_isa_cat, e_kitten_isa_frag, e_cat_catch, e_cat_comp]"

definition req_kitten :: crequest where
  "req_kitten = \<lparr>c_concept = cp ''kitten'', c_specs = [(UsedFor, Fwd)]\<rparr>"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     (\<forall>r \<in> set all_rels. parse_relation (rel_name r) = Some r) \<and>
     (case decide [IsA, PartOf] req_dog dog_edges of
        C_answer out \<Rightarrow> map fst out = [cp ''A dog is for companionship.'',
          cp ''A dog is used for guarding property.'', cp ''A dog is for a pet.'']
      | _ \<Rightarrow> False) \<and>
     (case decide [IsA, PartOf] req_kitten kitten_edges of
        C_derived ds \<Rightarrow> map d_line ds =
          [cp ''(via cat) You can use a cat to catch mice.'',
           cp ''(via cat) A cat is for companionship.'']
      | _ \<Rightarrow> False) \<and>
     decide [IsA, PartOf] \<lparr>c_concept = cp ''unicorn'', c_specs = [(UsedFor, Fwd)]\<rparr> kitten_edges
       = C_abstain"

export_code decide decide_direct decide_derived parse_relation rel_name all_rels
  template_chars render_edge claim_of mk_cedge mk_crequest
  c_rel c_start c_end c_weight c_surface c_dataset c_concept c_specs
  d_via d_line d_hop1 d_hop2
  Fwd Rev IsA PartOf HasA UsedFor CapableOf AtLocation
  Causes HasSubevent HasPrerequisite MotivatedByGoal Desires MadeOf ReceivesAction
  HasProperty Synonym Antonym DistinctFrom SimilarTo RelatedTo
  C_answer C_derived C_abstain self_test
  in SML module_name Conceptnet_Code file_prefix conceptnet

text \<open>The same program, written where the MLton build (tools/conceptnet/build.sh)
reads it. Its SHA-1 is printed as a build marker, so the binary can be tied to
this session's receipt.\<close>
ML \<open>
local
  val consts = [@{const_name decide}, @{const_name decide_direct}, @{const_name decide_derived},
    @{const_name parse_relation}, @{const_name rel_name}, @{const_name all_rels},
    @{const_name template_chars}, @{const_name render_edge}, @{const_name claim_of},
    @{const_name mk_cedge}, @{const_name mk_crequest},
    @{const_name c_rel}, @{const_name c_start}, @{const_name c_end}, @{const_name c_weight},
    @{const_name c_surface}, @{const_name c_dataset}, @{const_name c_concept}, @{const_name c_specs},
    @{const_name d_via}, @{const_name d_line}, @{const_name d_hop1}, @{const_name d_hop2},
    @{const_name Fwd}, @{const_name Rev},
    @{const_name C_answer}, @{const_name C_derived}, @{const_name C_abstain}, @{const_name self_test}]
  val (files, _) = Code_Target.produce_code @{context} false consts "SML" "Conceptnet_Code" NONE []
  val text = implode (map (Bytes.content o snd) files)
  val dir = Path.append (Resources.master_directory @{theory}) (Path.explode "../../../var/conceptnet/gen")
  val _ = Isabelle_System.make_directory dir
  val _ = File.write (Path.append dir (Path.basic "Conceptnet_Code.ML")) text
in
  val _ = writeln ("VERI7VN_CONCEPTNET code sha1=" ^ Message_Digest.rep (SHA1.digest text))
end
\<close>

end
