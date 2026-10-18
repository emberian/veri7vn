theory Relation_Identity
  imports "Veri7vn_Relation_Request.Relation_Request"
begin

text \<open>Inverse questions retain entity identifiers and collect subjects for
all supplied linked target senses. Requested-kind uniqueness is checked before
specialist ownership, so an otherwise unclassified human remains an alternative.
The fetch's complete finite candidate/subject sets and ontology remain premises.\<close>

definition identity_matches :: "subject_constraint \<Rightarrow> natural list \<Rightarrow> candidate \<Rightarrow> bool" where
  "identity_matches r excluded c = (subject_matches r c \<and>
    (\<forall>row \<in> set (rows c). fst row \<notin> set excluded))"

definition identity_pool :: "subject_constraint \<Rightarrow> natural list \<Rightarrow> attempt \<Rightarrow> candidate list" where
  "identity_pool r excluded a = filter (identity_matches r excluded) (subjects a)"

definition identity_evidence :: "natural \<Rightarrow> attempt \<Rightarrow> bool" where
  "identity_evidence p a = (\<not> capped a \<and> distinct (map qid (subjects a)) \<and>
    (\<forall>c \<in> set (subjects a). complete c \<and> dom_complete c \<and>
      (\<exists>t \<in> set (candidates a). (p,Entity (qid t)) \<in> set (rows c))))"

definition inverse_identity_choice ::
  "spec \<Rightarrow> subject_constraint \<Rightarrow> natural list \<Rightarrow> attempt \<Rightarrow> candidate option" where
  "inverse_identity_choice sp r excluded a =
    (if identity_evidence (prop_of sp (key a)) a then
      (case identity_pool r excluded a of [c] \<Rightarrow>
        (if domain_member sp c \<and> label c \<noteq> Blank then Some c else None)
       | _ \<Rightarrow> None)
     else None)"

lemma inverse_identity_choice_sound:
  assumes "inverse_identity_choice sp r excluded a = Some c"
  shows "identity_pool r excluded a = [c] \<and> domain_member sp c \<and> label c \<noteq> Blank \<and>
    identity_evidence (prop_of sp (key a)) a"
  using assms by (auto simp: inverse_identity_choice_def split: if_splits list.splits)

lemma inverse_identity_choice_member:
  assumes "inverse_identity_choice sp r excluded a = Some c"
  shows "c \<in> set (subjects a) \<and> identity_matches r excluded c \<and>
    (\<exists>t \<in> set (candidates a). (prop_of sp (key a),Entity (qid t)) \<in> set (rows c))"
proof -
  from inverse_identity_choice_sound[OF assms] have pool: "identity_pool r excluded a = [c]"
    and evidence: "identity_evidence (prop_of sp (key a)) a" by blast+
  have inside: "c \<in> set (identity_pool r excluded a)" using pool by simp
  from inside have member: "c \<in> set (subjects a) \<and> identity_matches r excluded c"
    by (simp add: identity_pool_def)
  show ?thesis using member evidence by (auto simp: identity_evidence_def)
qed

definition identity_step ::
  "spec \<Rightarrow> question_features \<Rightarrow> subject_constraint \<Rightarrow> natural list \<Rightarrow> attempt \<Rightarrow> step" where
  "identity_step sp f r excluded a = (if dir a = Fwd then step sp f a else
    if \<not> live sp a \<or> dropped sp (key a) Inv (idx a) then Cont None else
    case inverse_identity_choice sp r excluded a of None \<Rightarrow> Cont None
      | Some c \<Rightarrow> finish sp f a c (label c))"

fun identity_walk ::
  "spec \<Rightarrow> question_features \<Rightarrow> subject_constraint \<Rightarrow> natural list \<Rightarrow> attempt list \<Rightarrow>
    (natural \<times> natural \<times> bool) option \<Rightarrow> outcome" where
  "identity_walk sp f r excluded [] acc = walk sp f [] acc"
| "identity_walk sp f r excluded (a # ats) acc =
    (case identity_step sp f r excluded a of Halt out \<Rightarrow> out
     | Cont m \<Rightarrow> identity_walk sp f r excluded ats (case acc of None \<Rightarrow> m | Some d \<Rightarrow> Some d))"

definition ambiguous_identity_attempt ::
  "spec \<Rightarrow> question_features \<Rightarrow> subject_constraint \<Rightarrow> natural list \<Rightarrow> attempt \<Rightarrow> bool" where
  "ambiguous_identity_attempt sp f r excluded a = (dir a = Inv \<and> live sp a \<and>
    \<not> dropped sp (key a) Inv (idx a) \<and> \<not> (past f \<and> prop_of sp (key a) \<in> set time_variant) \<and>
    identity_evidence (prop_of sp (key a)) a \<and> length (identity_pool r excluded a) > 1)"

definition identity_ambiguity ::
  "spec \<Rightarrow> question_features \<Rightarrow> attempt list \<Rightarrow> subject_constraint \<Rightarrow> natural list \<Rightarrow>
    (natural \<times> (natural \<times> rel_value) list) option" where
  "identity_ambiguity sp f ats r excluded = (if kind_conflict f then None else
    case find (ambiguous_identity_attempt sp f r excluded) ats of None \<Rightarrow> None
    | Some a \<Rightarrow> Some (prop_of sp (key a), map (\<lambda>c. (qid c,label c)) (identity_pool r excluded a)))"

lemma identity_ambiguity_meaning:
  assumes "identity_ambiguity sp f ats r excluded = Some (p, alternatives)"
  shows "\<exists>a \<in> set ats. dir a = Inv \<and> p = prop_of sp (key a) \<and>
    identity_evidence p a \<and> length (identity_pool r excluded a) > 1 \<and>
    alternatives = map (\<lambda>c. (qid c,label c)) (identity_pool r excluded a)"
proof -
  from assms obtain a where found: "find (ambiguous_identity_attempt sp f r excluded) ats = Some a"
    and pair: "(p,alternatives) = (prop_of sp (key a),map (\<lambda>c. (qid c,label c)) (identity_pool r excluded a))"
    by (auto simp: identity_ambiguity_def split: if_splits option.splits)
  from find_Some_mem[OF found] have "a \<in> set ats" "ambiguous_identity_attempt sp f r excluded a" by blast+
  with pair show ?thesis by (auto simp: ambiguous_identity_attempt_def)
qed

definition decide_identity ::
  "spec \<Rightarrow> question_features \<Rightarrow> attempt list \<Rightarrow> subject_constraint \<Rightarrow> natural list \<Rightarrow> outcome" where
  "decide_identity sp f ats r excluded =
    (if kind_conflict f then Silent else
     case identity_ambiguity sp f ats r excluded of Some _ \<Rightarrow> Silent
       | None \<Rightarrow> identity_walk sp f r excluded ats None)"

lemma identity_walk_answer:
  "identity_walk sp f r excluded ats acc = Answer x \<Longrightarrow>
    \<exists>a \<in> set ats. identity_step sp f r excluded a = Halt (Answer x)"
proof (induct ats arbitrary: acc)
  case Nil
  then show ?case by (cases acc) (auto split: if_splits)
next
  case (Cons a ats)
  then show ?case by (cases "identity_step sp f r excluded a") auto
qed

lemma identity_answer_witness:
  assumes ans: "decide_identity sp f ats r excluded = Answer (s,p,v)"
    and inv: "\<forall>a \<in> set ats. dir a = Inv"
  shows "\<exists>a \<in> set ats. \<exists>c. inverse_identity_choice sp r excluded a = Some c \<and>
    qid c = s \<and> prop_of sp (key a) = p \<and> label c = v"
proof -
  from ans have run: "identity_walk sp f r excluded ats None = Answer (s,p,v)"
    by (auto simp: decide_identity_def split: if_splits option.splits)
  from identity_walk_answer[OF run] obtain a where a: "a \<in> set ats"
    "identity_step sp f r excluded a = Halt (Answer (s,p,v))" by blast
  have direction: "dir a = Inv" using inv a(1) by blast
  from a(2) direction obtain c where choice: "inverse_identity_choice sp r excluded a = Some c"
    and finish: "finish sp f a c (label c) = Halt (Answer (s,p,v))"
    by (auto simp: identity_step_def split: if_splits option.splits)
  show ?thesis using a(1) choice finish_answer[OF finish] by blast
qed

text \<open>The external snapshot is an identity edge relation (subject, property,
object). Coverage refers to all supplied linked targets, not only the first.
Eligibility agrees with the interpreted requested-kind predicate on every fetched
subject; it includes any explicit exclusions such as dissolved-state records.\<close>

definition inverse_snapshot_complete ::
  "(natural \<times> natural \<times> natural) set \<Rightarrow> natural \<Rightarrow> attempt \<Rightarrow> bool" where
  "inverse_snapshot_complete S p a =
    (qid ` set (subjects a) = {s. \<exists>t \<in> set (candidates a). (s,p,qid t) \<in> S})"

lemma choice_snapshot_singleton:
  assumes chosen: "inverse_identity_choice sp r excluded a = Some c"
    and coverage: "inverse_snapshot_complete S (prop_of sp (key a)) a"
    and eligibility: "\<forall>d \<in> set (subjects a). E (qid d) = identity_matches r excluded d"
  shows "{s. E s \<and> (\<exists>t \<in> set (candidates a). (s,prop_of sp (key a),qid t) \<in> S)} = {qid c}"
proof -
  have pool: "identity_pool r excluded a = [c]"
    using inverse_identity_choice_sound[OF chosen] by blast
  have eligible: "qid ` set (identity_pool r excluded a) = {s \<in> qid ` set (subjects a). E s}"
    using eligibility by (auto simp: identity_pool_def)
  show ?thesis using pool eligible coverage
    by (auto simp: inverse_snapshot_complete_def)
qed

theorem inverse_answer_snapshot_identity:
  assumes answer: "decide_identity sp f ats r excluded = Answer (s,p,v)"
    and inv: "\<forall>a \<in> set ats. dir a = Inv"
    and coverage: "\<forall>a \<in> set ats. inverse_snapshot_complete S (prop_of sp (key a)) a"
    and eligibility: "\<forall>a \<in> set ats. \<forall>d \<in> set (subjects a). E (qid d) = identity_matches r excluded d"
  shows "\<exists>a \<in> set ats.
    {u. E u \<and> (\<exists>t \<in> set (candidates a). (u,p,qid t) \<in> S)} = {s}"
proof -
  from identity_answer_witness[OF answer inv] obtain a c where a: "a \<in> set ats"
    and c: "inverse_identity_choice sp r excluded a = Some c" "qid c = s" "prop_of sp (key a) = p" by blast
  have cover: "inverse_snapshot_complete S (prop_of sp (key a)) a" using coverage a by blast
  have elig: "\<forall>d \<in> set (subjects a). E (qid d) = identity_matches r excluded d" using eligibility a by blast
  show ?thesis using a c choice_snapshot_singleton[OF c(1) cover elig] by blast
qed

lemma identity_forward_unchanged:
  "(\<forall>a \<in> set ats. dir a = Fwd) \<Longrightarrow>
    identity_walk sp f r excluded ats acc = walk sp f ats acc"
  by (induct ats arbitrary: acc) (auto simp: identity_step_def split: step.splits option.splits)

end
