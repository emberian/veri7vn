theory Mythology
  imports Facts_Common
begin

text \<open>
  Oracle7 mythology (upstream/root/specialists/mythology/organ_mythology_v1.py): Greek and
  Roman equivalents, the deity of a domain in the Greek, Roman and Norse pantheons, and
  who a named deity is. The organ scans its tables in order and answers for the first row
  whose name occurs in the question. The untrusted recognizer matches each row's name and
  passes one bit per row; the kernel takes the first row whose bit is set.
\<close>

text \<open>Rows of G2R: lower-case Greek name, Greek name as printed, Roman name as printed,
Roman name lower-case (the key of the derived R2G table).\<close>
definition g2r_rows :: "(String.literal \<times> String.literal \<times> String.literal \<times> String.literal) list" where
  "g2r_rows = [
    (STR ''zeus'', STR ''Zeus'', STR ''Jupiter'', STR ''jupiter''),
    (STR ''hera'', STR ''Hera'', STR ''Juno'', STR ''juno''),
    (STR ''poseidon'', STR ''Poseidon'', STR ''Neptune'', STR ''neptune''),
    (STR ''demeter'', STR ''Demeter'', STR ''Ceres'', STR ''ceres''),
    (STR ''athena'', STR ''Athena'', STR ''Minerva'', STR ''minerva''),
    (STR ''apollo'', STR ''Apollo'', STR ''Apollo'', STR ''apollo''),
    (STR ''artemis'', STR ''Artemis'', STR ''Diana'', STR ''diana''),
    (STR ''ares'', STR ''Ares'', STR ''Mars'', STR ''mars''),
    (STR ''aphrodite'', STR ''Aphrodite'', STR ''Venus'', STR ''venus''),
    (STR ''hephaestus'', STR ''Hephaestus'', STR ''Vulcan'', STR ''vulcan''),
    (STR ''hermes'', STR ''Hermes'', STR ''Mercury'', STR ''mercury''),
    (STR ''hestia'', STR ''Hestia'', STR ''Vesta'', STR ''vesta''),
    (STR ''dionysus'', STR ''Dionysus'', STR ''Bacchus'', STR ''bacchus''),
    (STR ''hades'', STR ''Hades'', STR ''Pluto'', STR ''pluto''),
    (STR ''persephone'', STR ''Persephone'', STR ''Proserpina'', STR ''proserpina''),
    (STR ''eros'', STR ''Eros'', STR ''Cupid'', STR ''cupid''),
    (STR ''cronus'', STR ''Cronus'', STR ''Saturn'', STR ''saturn''),
    (STR ''gaia'', STR ''Gaia'', STR ''Terra'', STR ''terra''),
    (STR ''nike'', STR ''Nike'', STR ''Victoria'', STR ''victoria''),
    (STR ''hypnos'', STR ''Hypnos'', STR ''Somnus'', STR ''somnus''),
    (STR ''pan'', STR ''Pan'', STR ''Faunus'', STR ''faunus''),
    (STR ''asclepius'', STR ''Asclepius'', STR ''Aesculapius'', STR ''aesculapius''),
    (STR ''heracles'', STR ''Heracles'', STR ''Hercules'', STR ''hercules''),
    (STR ''odysseus'', STR ''Odysseus'', STR ''Ulysses'', STR ''ulysses''),
    (STR ''rhea'', STR ''Rhea'', STR ''Ops'', STR ''ops''),
    (STR ''uranus'', STR ''Uranus'', STR ''Caelus'', STR ''caelus''),
    (STR ''eos'', STR ''Eos'', STR ''Aurora'', STR ''aurora''),
    (STR ''selene'', STR ''Selene'', STR ''Luna'', STR ''luna''),
    (STR ''helios'', STR ''Helios'', STR ''Sol'', STR ''sol''),
    (STR ''tyche'', STR ''Tyche'', STR ''Fortuna'', STR ''fortuna'')]"

text \<open>R2G as the organ derives it: Roman keys whose lower-case form differs from the
Greek key, in G2R order, then apollo (same name in both). Rows: Roman key, Roman name
printed, Greek name printed.\<close>
definition r2g_rows :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "r2g_rows = map (\<lambda>r. (snd (snd (snd r)), fst (snd (snd r)), fst (snd r)))
                  (filter (\<lambda>r. snd (snd (snd r)) \<noteq> fst r) g2r_rows)
              @ [(STR ''apollo'', STR ''Apollo'', STR ''Apollo'')]"

definition greek_domain :: "(String.literal \<times> String.literal) list" where
  "greek_domain = [
    (STR ''sky'', STR ''Zeus''),
    (STR ''thunder'', STR ''Zeus''),
    (STR ''sea'', STR ''Poseidon''),
    (STR ''underworld'', STR ''Hades''),
    (STR ''wisdom'', STR ''Athena''),
    (STR ''war'', STR ''Ares''),
    (STR ''love'', STR ''Aphrodite''),
    (STR ''beauty'', STR ''Aphrodite''),
    (STR ''music'', STR ''Apollo''),
    (STR ''prophecy'', STR ''Apollo''),
    (STR ''hunt'', STR ''Artemis''),
    (STR ''hunting'', STR ''Artemis''),
    (STR ''messenger'', STR ''Hermes''),
    (STR ''fire'', STR ''Hephaestus''),
    (STR ''forge'', STR ''Hephaestus''),
    (STR ''blacksmiths'', STR ''Hephaestus''),
    (STR ''harvest'', STR ''Demeter''),
    (STR ''agriculture'', STR ''Demeter''),
    (STR ''wine'', STR ''Dionysus''),
    (STR ''marriage'', STR ''Hera''),
    (STR ''hearth'', STR ''Hestia''),
    (STR ''victory'', STR ''Nike''),
    (STR ''sleep'', STR ''Hypnos''),
    (STR ''medicine'', STR ''Asclepius''),
    (STR ''dawn'', STR ''Eos''),
    (STR ''moon'', STR ''Selene''),
    (STR ''sun'', STR ''Helios'')]"

definition norse_domain :: "(String.literal \<times> String.literal) list" where
  "norse_domain = [
    (STR ''thunder'', STR ''Thor''),
    (STR ''wisdom'', STR ''Odin''),
    (STR ''war'', STR ''Tyr''),
    (STR ''mischief'', STR ''Loki''),
    (STR ''trickery'', STR ''Loki''),
    (STR ''love'', STR ''Freya''),
    (STR ''fertility'', STR ''Freyr''),
    (STR ''underworld'', STR ''Hel''),
    (STR ''death'', STR ''Hel''),
    (STR ''sea'', STR ''Njord''),
    (STR ''light'', STR ''Baldr''),
    (STR ''bifrost'', STR ''Heimdall''),
    (STR ''watchman'', STR ''Heimdall'')]"

text \<open>ROLE: lower-case name, name as printed, description.\<close>
definition roles :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "roles = [
    (STR ''zeus'', STR ''Zeus'', STR ''king of the gods, god of the sky and thunder''),
    (STR ''poseidon'', STR ''Poseidon'', STR ''god of the sea, earthquakes and horses''),
    (STR ''hades'', STR ''Hades'', STR ''god of the underworld''),
    (STR ''athena'', STR ''Athena'', STR ''goddess of wisdom and strategic war''),
    (STR ''ares'', STR ''Ares'', STR ''god of war''),
    (STR ''aphrodite'', STR ''Aphrodite'', STR ''goddess of love and beauty''),
    (STR ''apollo'', STR ''Apollo'', STR ''god of music, prophecy, healing and the sun''),
    (STR ''artemis'', STR ''Artemis'', STR ''goddess of the hunt and the moon''),
    (STR ''hermes'', STR ''Hermes'', STR ''messenger of the gods, god of travel and thieves''),
    (STR ''hephaestus'', STR ''Hephaestus'', STR ''god of fire and the forge''),
    (STR ''demeter'', STR ''Demeter'', STR ''goddess of the harvest''),
    (STR ''dionysus'', STR ''Dionysus'', STR ''god of wine and revelry''),
    (STR ''hera'', STR ''Hera'', STR ''queen of the gods, goddess of marriage''),
    (STR ''hestia'', STR ''Hestia'', STR ''goddess of the hearth''),
    (STR ''thor'', STR ''Thor'', STR ''Norse god of thunder''),
    (STR ''odin'', STR ''Odin'', STR ''chief of the Norse gods, god of wisdom''),
    (STR ''loki'', STR ''Loki'', STR ''Norse trickster god''),
    (STR ''freya'', STR ''Freya'', STR ''Norse goddess of love and fertility''),
    (STR ''tyr'', STR ''Tyr'', STR ''Norse god of war and law''),
    (STR ''heimdall'', STR ''Heimdall'', STR ''watchman of the Norse gods, guardian of the Bifrost''),
    (STR ''hel'', STR ''Hel'', STR ''Norse ruler of the underworld'')]"

datatype pantheon = P_greek | P_roman | P_norse

datatype yreq =
    YG2R "bool list"
  | YR2G "bool list"
  | YDomain pantheon String.literal
  | YRole String.literal

datatype yout =
    YSilent
  | YG2RV String.literal String.literal
  | YR2GV String.literal String.literal
  | YDomV pantheon String.literal String.literal
  | YRoleV String.literal String.literal

definition roman_of :: "String.literal \<Rightarrow> String.literal option" where
  "roman_of god = map_option (\<lambda>r. fst (snd (snd r))) (List.find (\<lambda>r. fst (snd r) = god) g2r_rows)"

definition domain_god :: "pantheon \<Rightarrow> String.literal \<Rightarrow> String.literal option" where
  "domain_god p dmn = (case p of
      P_norse \<Rightarrow> map_of norse_domain dmn
    | P_greek \<Rightarrow> map_of greek_domain dmn
    | P_roman \<Rightarrow> (case map_of greek_domain dmn of Some god \<Rightarrow> roman_of god | None \<Rightarrow> None))"

definition ykernel :: "yreq \<Rightarrow> yout" where
  "ykernel r = (case r of
      YG2R bs \<Rightarrow> (case pick bs g2r_rows of Some row \<Rightarrow> YG2RV (fst (snd row)) (fst (snd (snd row))) | None \<Rightarrow> YSilent)
    | YR2G bs \<Rightarrow> (case pick bs r2g_rows of Some row \<Rightarrow> YR2GV (fst (snd row)) (snd (snd row)) | None \<Rightarrow> YSilent)
    | YDomain p dmn \<Rightarrow> (case domain_god p dmn of Some n \<Rightarrow> YDomV p dmn n | None \<Rightarrow> YSilent)
    | YRole n \<Rightarrow> (case map_of roles n of Some (d, t) \<Rightarrow> YRoleV d t | None \<Rightarrow> YSilent))"

text \<open>The answer to a Greek-to-Roman question is the first row, in table order, whose
bit is set.\<close>
theorem g2r_first_match:
  "ykernel (YG2R bs) = YG2RV g r \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length g2r_rows \<and> bs ! i \<and> (\<forall>j<i. \<not> bs ! j)
         \<and> fst (snd (g2r_rows ! i)) = g \<and> fst (snd (snd (g2r_rows ! i))) = r"
proof -
  assume h: "ykernel (YG2R bs) = YG2RV g r"
  obtain row where p: "pick bs g2r_rows = Some row"
    using h by (cases "pick bs g2r_rows") (auto simp: ykernel_def)
  have e: "fst (snd row) = g \<and> fst (snd (snd row)) = r"
  proof -
    have "ykernel (YG2R bs) = YG2RV (fst (snd row)) (fst (snd (snd row)))" using p by (simp add: ykernel_def)
    then have "YG2RV (fst (snd row)) (fst (snd (snd row))) = YG2RV g r" using h by simp
    then show ?thesis by (rule iffD1[OF yout.inject(1)])
  qed
  from pick_some[OF p] obtain i where i: "i < length bs \<and> i < length g2r_rows \<and> bs ! i \<and> g2r_rows ! i = row \<and> (\<forall>j<i. \<not> bs ! j)"
    by blast
  show ?thesis using e i by metis
qed

theorem r2g_first_match:
  "ykernel (YR2G bs) = YR2GV r g \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length r2g_rows \<and> bs ! i \<and> (\<forall>j<i. \<not> bs ! j)
         \<and> fst (snd (r2g_rows ! i)) = r \<and> snd (snd (r2g_rows ! i)) = g"
proof -
  assume h: "ykernel (YR2G bs) = YR2GV r g"
  obtain row where p: "pick bs r2g_rows = Some row"
    using h by (cases "pick bs r2g_rows") (auto simp: ykernel_def)
  have e: "fst (snd row) = r \<and> snd (snd row) = g"
  proof -
    have "ykernel (YR2G bs) = YR2GV (fst (snd row)) (snd (snd row))" using p by (simp add: ykernel_def)
    then have "YR2GV (fst (snd row)) (snd (snd row)) = YR2GV r g" using h by simp
    then show ?thesis by (rule iffD1[OF yout.inject(2)])
  qed
  from pick_some[OF p] obtain i where i: "i < length bs \<and> i < length r2g_rows \<and> bs ! i \<and> r2g_rows ! i = row \<and> (\<forall>j<i. \<not> bs ! j)"
    by blast
  show ?thesis using e i by metis
qed

theorem g2r_no_bit: "ykernel (YG2R bs) = YSilent \<Longrightarrow> \<forall>i<length bs. i < length g2r_rows \<longrightarrow> \<not> bs ! i"
  by (auto simp: ykernel_def dest: pick_none split: option.splits)

theorem domain_value:
  "ykernel (YDomain p dmn) = YDomV p' dmn' n \<Longrightarrow> p' = p \<and> dmn' = dmn \<and> domain_god p dmn = Some n"
  by (auto simp: ykernel_def split: option.splits)

theorem role_value:
  "ykernel (YRole n) = YRoleV d t \<Longrightarrow> map_of roles n = Some (d, t) \<and> (n, d, t) \<in> set roles"
  by (auto simp: ykernel_def split: option.splits dest: map_of_SomeD)

text \<open>R2G is derived from G2R: every row names a Greek figure and the Roman name the
G2R table gives it (apollo aside, whose two names are equal).\<close>
theorem r2g_from_g2r:
  "\<forall>x\<in>set r2g_rows. x = (STR ''apollo'', STR ''Apollo'', STR ''Apollo'') \<or>
     (\<exists>r\<in>set g2r_rows. x = (snd (snd (snd r)), fst (snd (snd r)), fst (snd r)) \<and> snd (snd (snd r)) \<noteq> fst r)"
proof
  fix x assume x: "x \<in> set r2g_rows"
  have "x = (STR ''apollo'', STR ''Apollo'', STR ''Apollo'') \<or>
         x \<in> (\<lambda>r. (snd (snd (snd r)), fst (snd (snd r)), fst (snd r))) ` {r \<in> set g2r_rows. snd (snd (snd r)) \<noteq> fst r}"
    using x by (simp add: r2g_rows_def set_append)
  then show "x = (STR ''apollo'', STR ''Apollo'', STR ''Apollo'') \<or>
     (\<exists>r\<in>set g2r_rows. x = (snd (snd (snd r)), fst (snd (snd r)), fst (snd r)) \<and> snd (snd (snd r)) \<noteq> fst r)"
    by blast
qed

definition pantheon_name :: "pantheon \<Rightarrow> String.literal" where
  "pantheon_name p = (case p of P_greek \<Rightarrow> STR ''Greek'' | P_roman \<Rightarrow> STR ''Roman'' | P_norse \<Rightarrow> STR ''Norse'')"

definition ytext :: "yout \<Rightarrow> String.literal" where
  "ytext res = (case res of
      YSilent \<Rightarrow> STR ''''
    | YG2RV g r \<Rightarrow> cat [STR ''The Roman equivalent of '', g, STR '' is '', r, STR ''.'']
    | YR2GV r g \<Rightarrow> cat [STR ''The Greek equivalent of '', r, STR '' is '', g, STR ''.'']
    | YDomV p dmn n \<Rightarrow> cat [STR ''The '', pantheon_name p, STR '' deity of '', dmn, STR '' is '', n, STR ''.'']
    | YRoleV d t \<Rightarrow> cat [d, STR '' is the '', t, STR ''.''])"

definition ykind :: "yout \<Rightarrow> String.literal" where
  "ykind res = (case res of YSilent \<Rightarrow> STR ''silent'' | YG2RV g r \<Rightarrow> STR ''g2r'' | YR2GV r g \<Rightarrow> STR ''r2g''
               | YDomV p d n \<Rightarrow> STR ''domain_god'' | YRoleV d t \<Rightarrow> STR ''role'')"

definition ystated :: "yout \<Rightarrow> String.literal" where
  "ystated res = (case res of YSilent \<Rightarrow> STR '''' | YG2RV g r \<Rightarrow> r | YR2GV r g \<Rightarrow> g | YDomV p d n \<Rightarrow> n
                 | YRoleV d t \<Rightarrow> t)"

definition yreply :: "yreq \<Rightarrow> reply" where
  "yreply r = (case ykernel r of YSilent \<Rightarrow> Reply False (STR ''silent'') (STR '''') None
      | v \<Rightarrow> Reply True (ykind v) (ytext v) (Some (ystated v)))"

theorem yreply_answered_iff: "answered (yreply r) \<longleftrightarrow> ykernel r \<noteq> YSilent"
  by (auto simp: yreply_def split: yout.splits)

definition myth_self_test :: bool where
  "myth_self_test \<longleftrightarrow>
     ykernel (YDomain P_roman (STR ''sea'')) = YDomV P_roman (STR ''sea'') (STR ''Neptune'') \<and>
     ykernel (YDomain P_norse (STR ''thunder'')) = YDomV P_norse (STR ''thunder'') (STR ''Thor'') \<and>
     ykernel (YDomain P_greek (STR ''nonsense'')) = YSilent \<and>
     response (yreply (YDomain P_greek (STR ''sea''))) = STR ''The Greek deity of sea is Poseidon.'' \<and>
     ykernel (YRole (STR ''thor'')) = YRoleV (STR ''Thor'') (STR ''Norse god of thunder'') \<and>
     (case r2g_rows of x # _ \<Rightarrow> fst x = STR ''jupiter'' | [] \<Rightarrow> False) \<and>
     length r2g_rows = length g2r_rows"

end
