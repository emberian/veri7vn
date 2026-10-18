theory Relation_Query
  imports "Veri7vn_Relation_Identity.Relation_Identity"
begin

text \<open>A nominal question may explicitly distinguish a film, novel or
other kind of queried entity. The recognizer's kind and source ontology closure
are supplied premises. A genre row is checked separately from an instance row;
we never turn a genre into an invented instance-of assertion.\<close>

datatype query_constraint = AnyQuery | UnknownQuery
  | QueryInstance "natural list"
  | QueryPropertyClass natural "natural list"
  | EitherQuery query_constraint query_constraint

fun query_matches :: "query_constraint \<Rightarrow> (natural \<times> natural list) list \<Rightarrow> candidate \<Rightarrow> bool" where
  "query_matches AnyQuery cs c = True"
| "query_matches UnknownQuery cs c = False"
| "query_matches (QueryInstance rs) cs c = (dom_complete c \<and> hits (canc c) rs)"
| "query_matches (QueryPropertyClass p rs) cs c =
    (complete c \<and> (\<exists>entry \<in> set cs.
      (p,Entity (fst entry)) \<in> set (rows c) \<and>
      (\<exists>r \<in> set rs. r \<in> set (snd entry))))"
| "query_matches (EitherQuery left right) cs c = (query_matches left cs c \<or> query_matches right cs c)"

fun query_known :: "query_constraint \<Rightarrow> (natural \<times> natural list) list \<Rightarrow> candidate \<Rightarrow> bool" where
  "query_known AnyQuery cs c = True"
| "query_known UnknownQuery cs c = False"
| "query_known (QueryInstance rs) cs c = dom_complete c"
| "query_known (QueryPropertyClass p rs) cs c = (complete c \<and>
    (\<forall>row \<in> set (rows c). fst row = p \<longrightarrow>
      (case snd row of Entity obj \<Rightarrow> obj \<in> fst ` set cs | _ \<Rightarrow> False)))"
| "query_known (EitherQuery a b) cs c = (query_known a cs c \<and> query_known b cs c)"

definition query_scope :: "query_constraint \<Rightarrow> (natural \<times> natural list) list \<Rightarrow> attempt \<Rightarrow> attempt" where
  "query_scope q cs a = (if dir a = Fwd then
     a\<lparr>candidates := (if \<forall>c \<in> set (candidates a). query_known q cs c then
       filter (query_matches q cs) (candidates a) else [])\<rparr> else a)"

definition decide_query :: "spec \<Rightarrow> question_features \<Rightarrow> attempt list \<Rightarrow>
 subject_constraint \<Rightarrow> natural list \<Rightarrow> query_constraint \<Rightarrow>
 (natural \<times> natural list) list \<Rightarrow> outcome" where
  "decide_query sp f ats r excluded q cs = decide_identity sp f (map (query_scope q cs) ats) r excluded"

lemma query_scope_direction [simp]: "dir (query_scope q cs a) = dir a"
  by (simp add: query_scope_def)

lemma query_scope_members:
  "dir a = Fwd \<Longrightarrow> c \<in> set (candidates (query_scope q cs a)) \<Longrightarrow>
    c \<in> set (candidates a) \<and> query_matches q cs c \<and>
    (\<forall>d \<in> set (candidates a). query_known q cs d)"
  by (auto simp: query_scope_def split: if_splits)

lemma identity_forward_decision:
  assumes fw: "\<forall>a \<in> set ats. dir a = Fwd"
  shows "decide_identity sp f ats r excluded = decide_spec sp f ats"
proof -
  have none: "find (ambiguous_identity_attempt sp f r excluded) ats = None"
    using fw by (auto simp: find_None_iff ambiguous_identity_attempt_def)
  have amb: "identity_ambiguity sp f ats r excluded = None"
    by (simp add: identity_ambiguity_def none)
  show ?thesis using identity_forward_unchanged[OF fw] amb
    by (simp add: decide_identity_def decide_spec_def)
qed

theorem queried_forward_answer:
  assumes ans: "decide_query sp f ats r excluded q cs = Answer (s,p,v)"
    and fw: "\<forall>a \<in> set ats. dir a = Fwd"
  shows "\<exists>a \<in> set ats. \<exists>c \<in> set (candidates a).
    query_matches q cs c \<and> qid c = s \<and> domain_member sp c \<and>
    (p,v) \<in> set (rows c) \<and> v \<noteq> Blank \<and>
    (\<forall>d \<in> set (candidates a). query_known q cs d)"
proof -
  have scoped_fw: "\<forall>a \<in> set (map (query_scope q cs) ats). dir a = Fwd"
    using fw by auto
  have base: "decide_spec sp f (map (query_scope q cs) ats) = Answer (s,p,v)"
    using ans identity_forward_decision[OF scoped_fw] by (simp add: decide_query_def)
  from answer_stored[OF base] obtain b where
    b: "b \<in> set (map (query_scope q cs) ats)"
      "attempt_values sp f b = Some (s,p,v)" by blast
  have bf: "dir b = Fwd" using scoped_fw b(1) by blast
  note sound = attempt_values_sound[OF b(2) bf]
  let ?c = "hd (mineof sp b)"
  have c: "?c \<in> set (mineof sp b)" "qid ?c = s"
      "(p,v) \<in> set (rows ?c)" "v \<noteq> Blank"
    using hd_in_set[OF sound(4)] sound(5) sound(10) sound(11) by auto
  from b(1) obtain a where a: "a \<in> set ats" "b = query_scope q cs a" by auto
  from mine_in_candidates[OF c(1)] have member: "?c \<in> set (candidates b)" and dom: "domain_member sp ?c" by blast+
  have dir: "dir a = Fwd" using fw a by blast
  have scoped_member: "?c \<in> set (candidates (query_scope q cs a))" using member a(2) by simp
  from query_scope_members[OF dir scoped_member]
    have original: "?c \<in> set (candidates a) \<and> query_matches q cs ?c \<and>
      (\<forall>d \<in> set (candidates a). query_known q cs d)" .
  show ?thesis using a original dom c by blast
qed

lemma query_genre_witness:
  "query_matches (QueryPropertyClass p rs) cs c \<Longrightarrow>
    \<exists>obj ancestors. (p,Entity obj) \<in> set (rows c) \<and>
      (obj,ancestors) \<in> set cs \<and> (\<exists>root \<in> set rs. root \<in> set ancestors)"
  by (auto; blast)

lemma unqualified_query_unchanged:
  "decide_query sp f ats r excluded AnyQuery cs = decide_identity sp f ats r excluded"
proof -
  have same: "query_scope AnyQuery cs a = a" for a
    by (cases a) (simp add: query_scope_def)
  have "map (query_scope AnyQuery cs) ats = ats"
    by (induct ats) (simp_all add: same)
  then show ?thesis by (simp add: decide_query_def)
qed

lemma inverse_query_unchanged:
  "(\<forall>a \<in> set ats. dir a = Inv) \<Longrightarrow>
    decide_query sp f ats r excluded q cs = decide_identity sp f ats r excluded"
proof -
  assume inv: "\<forall>a \<in> set ats. dir a = Inv"
  have "map (query_scope q cs) ats = ats" using inv
    by (induct ats) (auto simp: query_scope_def)
  then show ?thesis by (simp add: decide_query_def)
qed
end
