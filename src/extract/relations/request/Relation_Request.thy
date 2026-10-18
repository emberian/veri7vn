theory Relation_Request
  imports "Veri7vn_Relations.Relation_Reader"
begin

text \<open>The reader's subject domain and the kind explicitly requested by a
question are separate constraints. An actor question must not be answered by a
physicist reader merely because both readers recognise the same spouse phrase.
The recognizer supplies this finite constraint expression; class closures and
property rows remain fetched evidence, not facts established by this theory.\<close>

datatype subject_constraint = AnySubject | UnknownSubject
  | InstanceOf "natural list" | OccupationOf "natural list"
  | HasValue natural rel_value
  | Both subject_constraint subject_constraint

fun subject_matches :: "subject_constraint \<Rightarrow> candidate \<Rightarrow> bool" where
  "subject_matches AnySubject c = True"
| "subject_matches UnknownSubject c = False"
| "subject_matches (InstanceOf rs) c = (dom_complete c \<and> hits (canc c) rs)"
| "subject_matches (OccupationOf rs) c =
    (dom_complete c \<and> 5 \<in> set (cls c) \<and> hits (oanc c) rs)"
| "subject_matches (HasValue p v) c = (complete c \<and> (p,v) \<in> set (rows c))"
| "subject_matches (Both a b) c = (subject_matches a c \<and> subject_matches b c)"

definition scope_attempt :: "subject_constraint \<Rightarrow> attempt \<Rightarrow> attempt" where
  "scope_attempt r a = (if dir a = Inv
    then a\<lparr>subjects := filter (subject_matches r) (subjects a)\<rparr> else a)"

definition decide_requested ::
  "spec \<Rightarrow> question_features \<Rightarrow> attempt list \<Rightarrow> subject_constraint \<Rightarrow> outcome" where
  "decide_requested sp f ats r = decide_spec sp f (map (scope_attempt r) ats)"

lemma scope_direction [simp]: "dir (scope_attempt r a) = dir a"
  by (simp add: scope_attempt_def)

lemma scope_inverse_subjects:
  "dir a = Inv \<Longrightarrow> set (subjects (scope_attempt r a)) =
    {c \<in> set (subjects a). subject_matches r c}"
  by (simp add: scope_attempt_def)

theorem requested_inverse_answer:
  assumes ans: "decide_requested sp f ats r = Answer (s,p,v)"
    and inverse: "\<forall>a \<in> set ats. dir a = Inv"
  shows "\<exists>a \<in> set ats. \<exists>c \<in> set (subjects a).
    qid c = s \<and> label c = v \<and> domain_member sp c \<and> subject_matches r c \<and>
    (p, label (hd (candidates a))) \<in> set (rows c)"
proof -
  have base: "decide_spec sp f (map (scope_attempt r) ats) = Answer (s,p,v)"
    using ans by (simp add: decide_requested_def)
  from answer_stored[OF base] obtain b where
    b: "b \<in> set (map (scope_attempt r) ats)"
      "attempt_values sp f b = Some (s,p,v)" by blast
  then obtain a where a: "a \<in> set ats" "b = scope_attempt r a" by auto
  have ai: "dir a = Inv" using inverse a(1) by blast
  have bi: "dir b = Inv" using a(2) ai by simp
  from attempt_values_sound_inv(5)[OF b(2) bi] obtain c where
    c: "c \<in> set (subjects b)" "domain_member sp c" "qid c = s" "label c = v"
      "(p, label (hd (candidates b))) \<in> set (rows c)" by blast
  have original: "c \<in> set (subjects a) \<and> subject_matches r c"
    using c(1) a(2) scope_inverse_subjects[OF ai, of r] by auto
  have row: "(p, label (hd (candidates a))) \<in> set (rows c)"
    using c(5) a(2) ai by (simp add: scope_attempt_def)
  show ?thesis using a(1) original c(2-4) row by blast
qed

lemma requested_forward_unchanged:
  "(\<forall>a \<in> set ats. dir a = Fwd) \<Longrightarrow>
    decide_requested sp f ats r = decide_spec sp f ats"
proof -
  assume forward: "\<forall>a \<in> set ats. dir a = Fwd"
  have "map (scope_attempt r) ats = ats"
    using forward by (induct ats) (auto simp: scope_attempt_def)
  then show "decide_requested sp f ats r = decide_spec sp f ats"
    by (simp add: decide_requested_def)
qed

lemma requested_occupation_witness:
  "subject_matches (OccupationOf rs) c \<Longrightarrow>
    dom_complete c \<and> 5 \<in> set (cls c) \<and>
      (\<exists>anc \<in> set (oanc c). \<exists>r \<in> set rs. r \<in> set anc)"
  by (auto simp: hits_def)

lemma requested_property_witness:
  "subject_matches (HasValue p v) c \<Longrightarrow> complete c \<and> (p,v) \<in> set (rows c)"
  by simp

end
