theory Relation_Reader
  imports Main
begin

text \<open>Oracle7's exact relation router (upstream/root/wander-train/exact_router_v1.py) as a decision over
fetched evidence. The fetch, the entity linker and the question regexes stay outside HOL: their results
arrive as @{typ bool}s, word lists and candidate rows. The decision proves what an answer means about that
evidence, and only that. A candidate's @{text complete} flag is the fetch's own claim that its rows hold every
stored fact for that entity and every property of the admitted table; the theorems below use it as a
premise and never establish it.\<close>

datatype rel_value = Entity natural | Literal String.literal | Blank

record candidate =
  qid :: natural
  links :: natural
  rows :: "(natural \<times> rel_value) list"
  complete :: bool

datatype reason = Polar | NoCandidate | HiddenHop | NotSubject | NoPattern | ConflictingPatterns
  | PastQualifier | IncompleteEvidence | NoValue | BlankNode | MultiValued | Disagreement | RestatesQuestion

datatype outcome = Answer rel_value | Refuse reason

record question_features =
  polar :: bool
  hidden_hop :: bool
  subject_ok :: bool
  past :: bool
  head_key :: String.literal
  content_words :: "String.literal list"
  question_words :: "String.literal list"
  value_words :: "(rel_value \<times> String.literal list) list"

type_synonym pattern = "(String.literal \<times> String.literal) \<times> natural"

section \<open>Routing: the admitted patterns that fire must name one property\<close>

definition matched_props :: "question_features \<Rightarrow> pattern list \<Rightarrow> natural list" where
  "matched_props f ps = remdups (map snd (filter (\<lambda>((k, w), p). k = head_key f \<and>
      (w = STR ''*'' \<or> w \<in> set (content_words f))) ps))"

definition route :: "question_features \<Rightarrow> pattern list \<Rightarrow> natural option" where
  "route f ps = (case matched_props f ps of [p] \<Rightarrow> Some p | _ \<Rightarrow> None)"

section \<open>Candidate selection: at most three, or one when it dominates\<close>

definition dominated :: "candidate list \<Rightarrow> bool" where
  "dominated cs = (case cs of c # rest \<Rightarrow> rest \<noteq> [] \<and>
      10 * max 1 (fold max (map links rest) 0) \<le> links c | [] \<Rightarrow> False)"

definition select :: "candidate list \<Rightarrow> candidate list" where
  "select cs = (if dominated (take 3 cs) then take 1 cs else take 3 cs)"

section \<open>Evidence and the decision\<close>

definition vals :: "natural \<Rightarrow> candidate \<Rightarrow> rel_value list" where
  "vals P c = remdups (map snd (filter (\<lambda>(p, _). p = P) (rows c)))"

text \<open>Properties whose stored value is the current one; a past-time qualifier on them is refused
(TIME_VARIANT in exact_router_v1).\<close>
definition time_variant :: "natural list" where
  "time_variant = [36, 35, 6, 54, 159, 27, 17, 131, 286, 488, 1037, 108, 39, 463, 102, 26]"

definition restates :: "question_features \<Rightarrow> rel_value \<Rightarrow> bool" where
  "restates f v = (case map_of (value_words f) v of
      Some ws \<Rightarrow> ws \<noteq> [] \<and> set ws \<subseteq> set (question_words f) | None \<Rightarrow> False)"

definition judge :: "question_features \<Rightarrow> natural \<Rightarrow> candidate list \<Rightarrow> candidate \<Rightarrow> outcome" where
  "judge f P cs c0 =
    (if \<exists>c\<in>set cs. Blank \<in> set (vals P c) then Refuse BlankNode
     else if \<exists>c\<in>set cs. 1 < length (vals P c) then Refuse MultiValued
     else if \<exists>c\<in>set cs. vals P c \<noteq> [] \<and> vals P c \<noteq> vals P c0 then Refuse Disagreement
     else if restates f (hd (vals P c0)) then Refuse RestatesQuestion
     else Answer (hd (vals P c0)))"

definition carried :: "question_features \<Rightarrow> natural \<Rightarrow> candidate list \<Rightarrow> outcome" where
  "carried f P cs = (case filter (\<lambda>c. vals P c \<noteq> []) cs of
       [] \<Rightarrow> Refuse NoValue
     | c0 # _ \<Rightarrow> judge f P cs c0)"

definition evidence :: "question_features \<Rightarrow> natural \<Rightarrow> candidate list \<Rightarrow> outcome" where
  "evidence f P cs =
    (if P \<in> set time_variant \<and> past f then Refuse PastQualifier
     else if \<not> (\<forall>c\<in>set cs. complete c) then Refuse IncompleteEvidence
     else carried f P cs)"

text \<open>@{text decide_on} judges exactly the candidates it is given; @{text decide} first applies the
shipped selection (at most three; one when its link count dominates the rest tenfold).\<close>
definition decide_on :: "question_features \<Rightarrow> pattern list \<Rightarrow> candidate list \<Rightarrow> outcome" where
  "decide_on f ps cs =
    (if polar f then Refuse Polar
     else if cs = [] then Refuse NoCandidate
     else if hidden_hop f then Refuse HiddenHop
     else if \<not> subject_ok f then Refuse NotSubject
     else case matched_props f ps of
       [] \<Rightarrow> Refuse NoPattern
     | [P] \<Rightarrow> evidence f P cs
     | _ \<Rightarrow> Refuse ConflictingPatterns)"

definition decide :: "question_features \<Rightarrow> pattern list \<Rightarrow> candidate list \<Rightarrow> outcome" where
  "decide f ps cs = decide_on f ps (select cs)"

section \<open>What an answer means\<close>

lemma set_vals: "set (vals P c) = {ob. (P, ob) \<in> set (rows c)}"
  by (force simp: vals_def)

lemma route_some_iff: "route f ps = Some P \<longleftrightarrow> matched_props f ps = [P]"
  by (auto simp: route_def split: list.splits)

lemma vals_single:
  assumes "\<not> 1 < length (vals P c)" "vals P c \<noteq> []"
  shows "\<exists>x. vals P c = [x]"
  using assms by (cases "vals P c") auto

lemma filter_Cons_mem:
  assumes "filter Q xs = y # ys"
  shows "y \<in> set xs \<and> Q y"
proof -
  have "y \<in> set (filter Q xs)" using assms by simp
  then show ?thesis by simp
qed

lemma judge_answer:
  assumes "judge f P cs c0 = Answer v"
  shows "\<not> (\<exists>c\<in>set cs. Blank \<in> set (vals P c)) \<and> \<not> (\<exists>c\<in>set cs. 1 < length (vals P c))
    \<and> \<not> (\<exists>c\<in>set cs. vals P c \<noteq> [] \<and> vals P c \<noteq> vals P c0)
    \<and> \<not> restates f (hd (vals P c0)) \<and> v = hd (vals P c0)"
  using assms unfolding judge_def by (simp split: if_splits)

lemma judge_reasons:
  "judge f P cs c0 = Refuse r \<Longrightarrow> r \<in> {BlankNode, MultiValued, Disagreement, RestatesQuestion}"
  unfolding judge_def by (simp split: if_splits)

lemma carried_reasons:
  "carried f P cs = Refuse r \<Longrightarrow> r \<in> {NoValue, BlankNode, MultiValued, Disagreement, RestatesQuestion}"
  unfolding carried_def by (auto split: list.splits dest: judge_reasons)

lemma evidence_reasons:
  "evidence f P cs = Refuse r \<Longrightarrow>
    r \<in> {PastQualifier, IncompleteEvidence, NoValue, BlankNode, MultiValued, Disagreement, RestatesQuestion}"
  unfolding evidence_def by (auto split: if_splits dest: carried_reasons)

lemma evidence_answer:
  assumes "evidence f P cs = Answer v"
  shows "(\<forall>c\<in>set cs. complete c) \<and> (\<forall>c\<in>set cs. vals P c = [] \<or> vals P c = [v])
         \<and> v \<noteq> Blank \<and> (\<exists>c\<in>set cs. vals P c = [v]) \<and> \<not> restates f v
         \<and> \<not> (P \<in> set time_variant \<and> past f)"
proof -
  have tv: "\<not> (P \<in> set time_variant \<and> past f)" and cov: "\<forall>c\<in>set cs. complete c"
   and ca: "carried f P cs = Answer v"
    using assms unfolding evidence_def by (simp_all split: if_splits)
  obtain c0 rest where fl: "filter (\<lambda>c. vals P c \<noteq> []) cs = c0 # rest"
    using ca unfolding carried_def by (auto split: list.splits)
  then have ja: "judge f P cs c0 = Answer v" using ca unfolding carried_def by simp
  have c0: "c0 \<in> set cs" "vals P c0 \<noteq> []"
    using filter_Cons_mem[OF fl] by simp_all
  note J = judge_answer[OF ja]
  obtain x where x: "vals P c0 = [x]" using vals_single J c0 by blast
  have v: "v = x" using J x by simp
  have all: "\<forall>c\<in>set cs. vals P c = [] \<or> vals P c = [v]" using J x v by auto
  have nb: "v \<noteq> Blank" using J x v c0(1) by force
  show ?thesis using cov tv all nb c0(1) x v J by auto
qed

lemma evidence_answer_intro:
  assumes "\<not> (P \<in> set time_variant \<and> past f)" "\<forall>c\<in>set cs. complete c"
    "\<forall>c\<in>set cs. vals P c = [] \<or> vals P c = [v]" "\<exists>c\<in>set cs. vals P c = [v]"
    "v \<noteq> Blank" "\<not> restates f v"
  shows "evidence f P cs = Answer v"
proof -
  obtain c0 rest where fl: "filter (\<lambda>c. vals P c \<noteq> []) cs = c0 # rest"
    using assms(4) by (cases "filter (\<lambda>c. vals P c \<noteq> []) cs") (auto simp: filter_empty_conv)
  have "c0 \<in> set cs" "vals P c0 \<noteq> []"
    using filter_Cons_mem[OF fl] by simp_all
  then have v0: "vals P c0 = [v]" using assms(3) by blast
  have "\<not> (\<exists>c\<in>set cs. Blank \<in> set (vals P c))" using assms(3,5) by fastforce
  moreover have "\<not> (\<exists>c\<in>set cs. 1 < length (vals P c))" using assms(3) by fastforce
  moreover have "\<not> (\<exists>c\<in>set cs. vals P c \<noteq> [] \<and> vals P c \<noteq> vals P c0)" using assms(3) v0 by auto
  ultimately have "judge f P cs c0 = Answer v" using v0 assms(6) unfolding judge_def by simp
  then show ?thesis using assms(1,2) fl unfolding evidence_def carried_def by simp
qed

lemma decide_on_answer:
  "decide_on f ps cs = Answer v \<Longrightarrow> \<exists>P. matched_props f ps = [P] \<and> evidence f P cs = Answer v"
  by (auto simp: decide_on_def split: if_splits list.splits)

theorem answer_unique_agreement:
  assumes "decide_on f ps cs = Answer v" and "route f ps = Some P"
  shows "\<forall>c\<in>set cs. \<forall>(p', ob)\<in>set (rows c). p' = P \<longrightarrow> ob = v"
proof -
  have "evidence f P cs = Answer v"
    using decide_on_answer[OF assms(1)] assms(2) by (auto simp: route_some_iff)
  then have all: "\<forall>c\<in>set cs. vals P c = [] \<or> vals P c = [v]" using evidence_answer by blast
  show ?thesis
  proof (rule ballI)
    fix c assume c: "c \<in> set cs"
    have "ob = v" if m: "(p', ob) \<in> set (rows c)" "p' = P" for p' ob
    proof -
      have "ob \<in> set (vals P c)" using m by (simp add: set_vals)
      then show "ob = v" using all c by auto
    qed
    then show "\<forall>(p', ob)\<in>set (rows c). p' = P \<longrightarrow> ob = v" by auto
  qed
qed

theorem answer_requires_coverage:
  "decide_on f ps cs = Answer v \<Longrightarrow> \<forall>c\<in>set cs. complete c"
  using decide_on_answer evidence_answer by blast

theorem answer_not_blank: "decide_on f ps cs \<noteq> Answer Blank"
  using decide_on_answer evidence_answer by blast

theorem answer_witnessed:
  "decide_on f ps cs = Answer v \<Longrightarrow>
    \<exists>P. route f ps = Some P \<and> (\<exists>c\<in>set cs. (P, v) \<in> set (rows c))"
proof -
  assume a: "decide_on f ps cs = Answer v"
  then obtain P where "matched_props f ps = [P]" "evidence f P cs = Answer v"
    using decide_on_answer by blast
  moreover then obtain c where "c \<in> set cs" "vals P c = [v]" using evidence_answer by blast
  ultimately show ?thesis using set_vals[of P c] by (auto simp: route_some_iff)
qed

theorem answer_not_restating:
  "decide_on f ps cs = Answer v \<Longrightarrow> \<not> restates f v"
  using decide_on_answer evidence_answer by blast

section \<open>The named refusals are exactly their conditions\<close>

theorem polar_refused: "decide_on f ps cs = Refuse Polar \<longleftrightarrow> polar f"
  by (auto simp: decide_on_def split: if_splits list.splits dest: evidence_reasons)

theorem no_candidate_refused:
  "decide_on f ps cs = Refuse NoCandidate \<longleftrightarrow> \<not> polar f \<and> cs = []"
  by (auto simp: decide_on_def split: if_splits list.splits dest: evidence_reasons)

theorem hop_refused:
  "decide_on f ps cs = Refuse HiddenHop \<longleftrightarrow> \<not> polar f \<and> cs \<noteq> [] \<and> hidden_hop f"
  by (auto simp: decide_on_def split: if_splits list.splits dest: evidence_reasons)

theorem no_pattern_refused:
  "decide_on f ps cs = Refuse NoPattern \<longleftrightarrow>
    \<not> polar f \<and> cs \<noteq> [] \<and> \<not> hidden_hop f \<and> subject_ok f \<and> matched_props f ps = []"
  by (auto simp: decide_on_def split: if_splits list.splits dest: evidence_reasons)

theorem conflicting_patterns_refused:
  "decide_on f ps cs = Refuse ConflictingPatterns \<longleftrightarrow>
    \<not> polar f \<and> cs \<noteq> [] \<and> \<not> hidden_hop f \<and> subject_ok f \<and> 2 \<le> length (matched_props f ps)"
proof -
  have len: "2 \<le> length xs \<longleftrightarrow> (\<exists>a b r. xs = a # b # r)" for xs :: "natural list"
    by (cases xs; cases "tl xs") auto
  show ?thesis
    by (auto simp: decide_on_def len split: if_splits list.splits dest: evidence_reasons)
qed

lemma evidence_incomplete:
  "evidence f P cs = Refuse IncompleteEvidence \<Longrightarrow> \<exists>c\<in>set cs. \<not> complete c"
  unfolding evidence_def by (auto split: if_splits dest: carried_reasons)

theorem incomplete_refusal_names_a_gap:
  "decide_on f ps cs = Refuse IncompleteEvidence \<Longrightarrow> \<exists>c\<in>set cs. \<not> complete c"
  by (auto simp: decide_on_def split: if_splits list.splits dest: evidence_incomplete)

section \<open>More candidates: agreement keeps the answer, disagreement refuses\<close>

lemma distinct_subset_single:
  assumes "set xs \<subseteq> {v}" "distinct xs"
  shows "xs = [] \<or> xs = [v]"
proof (cases xs)
  case (Cons a r)
  then have "a = v" using assms by auto
  moreover have sub: "set r \<subseteq> {v}" "v \<notin> set r" using Cons assms \<open>a = v\<close> by auto
  have "r = []"
  proof (cases r)
    case (Cons b t)
    then have "b \<in> set r" by simp
    then show ?thesis using sub by auto
  qed simp
  ultimately show ?thesis using Cons by simp
qed simp

theorem agreeing_candidates_keep_answer:
  assumes ans: "decide_on f ps cs = Answer v" and r: "route f ps = Some P"
    and sub: "set cs \<subseteq> set cs'"
    and cov: "\<forall>c\<in>set cs'. complete c"
    and agree: "\<forall>c\<in>set cs'. \<forall>(p', ob)\<in>set (rows c). p' = P \<longrightarrow> ob = v"
  shows "decide_on f ps cs' = Answer v"
proof -
  have mp: "matched_props f ps = [P]" using r by (simp add: route_some_iff)
  have ev: "evidence f P cs = Answer v"
    using decide_on_answer[OF ans] mp by auto
  note E = evidence_answer[OF ev]
  have pre: "\<not> polar f" "cs \<noteq> []" "\<not> hidden_hop f" "subject_ok f"
    using ans unfolding decide_on_def by (simp_all split: if_splits)
  have vs: "\<forall>c\<in>set cs'. vals P c = [] \<or> vals P c = [v]"
  proof
    fix c assume c: "c \<in> set cs'"
    have "set (vals P c) \<subseteq> {v}" using agree c set_vals[of P c] by fastforce
    moreover have "distinct (vals P c)" by (simp add: vals_def)
    ultimately show "vals P c = [] \<or> vals P c = [v]" by (rule distinct_subset_single)
  qed
  have w: "\<exists>c\<in>set cs'. vals P c = [v]" using E sub by blast
  have "evidence f P cs' = Answer v"
    using evidence_answer_intro[OF _ cov vs w] E by blast
  moreover have "cs' \<noteq> []" using sub pre(2) by auto
  ultimately show ?thesis using pre mp by (simp add: decide_on_def)
qed

corollary more_candidates_never_flip_answer:
  assumes "decide_on f ps cs = Answer v" "route f ps = Some P" "complete c"
    "\<forall>(p', ob)\<in>set (rows c). p' = P \<longrightarrow> ob = v"
  shows "decide_on f ps (cs @ [c]) = Answer v"
proof -
  have "\<forall>c\<in>set cs. complete c" using answer_requires_coverage assms(1) by blast
  moreover have "\<forall>c\<in>set cs. \<forall>(p', ob)\<in>set (rows c). p' = P \<longrightarrow> ob = v"
    using answer_unique_agreement assms(1,2) by blast
  ultimately show ?thesis
    using agreeing_candidates_keep_answer[OF assms(1,2), of "cs @ [c]"] assms(3,4) by auto
qed

theorem disagreeing_candidate_refuses:
  assumes ans: "decide_on f ps cs = Answer v" and r: "route f ps = Some P"
    and sub: "set cs \<subseteq> set cs'" and c: "c \<in> set cs'" and row: "(P, ob) \<in> set (rows c)" and ne: "ob \<noteq> v"
  shows "\<exists>reason. decide_on f ps cs' = Refuse reason"
proof (cases "decide_on f ps cs'")
  case (Answer v')
  obtain P' cw where "route f ps = Some P'" "cw \<in> set cs" "(P', v) \<in> set (rows cw)"
    using answer_witnessed[OF ans] by blast
  then have "P' = P" "cw \<in> set cs'" using r sub by auto
  then have "v = v'" "ob = v'"
    using answer_unique_agreement[OF Answer r] \<open>(P', v) \<in> set (rows cw)\<close> c row by fastforce+
  then show ?thesis using ne by simp
qed simp

text \<open>Refusals on the evidence (not on the question) survive any enlargement of the candidate set.\<close>
theorem evidence_refusal_monotone:
  assumes ref: "decide_on f ps cs = Refuse r"
    and rs: "r \<in> {IncompleteEvidence, BlankNode, MultiValued, Disagreement}"
    and sub: "set cs \<subseteq> set cs'"
  shows "\<exists>r'. decide_on f ps cs' = Refuse r'"
proof (cases "decide_on f ps cs'")
  case (Answer v)
  obtain P where mp: "matched_props f ps = [P]" and ev': "evidence f P cs' = Answer v"
    using decide_on_answer[OF Answer] by blast
  note E = evidence_answer[OF ev']
  have pre: "\<not> polar f" "cs \<noteq> []" "\<not> hidden_hop f" "subject_ok f"
    using ref rs unfolding decide_on_def by (auto split: if_splits)
  have ev: "evidence f P cs = Refuse r"
    using ref pre mp by (simp add: decide_on_def)
  have cov: "\<forall>c\<in>set cs. complete c" and vs: "\<forall>c\<in>set cs. vals P c = [] \<or> vals P c = [v]"
    using E sub by blast+
  show ?thesis
  proof (cases "\<exists>c\<in>set cs. vals P c = [v]")
    case True
    then have "evidence f P cs = Answer v" using evidence_answer_intro[OF _ cov vs] E by blast
    then show ?thesis using ev by simp
  next
    case False
    then have "filter (\<lambda>c. vals P c \<noteq> []) cs = []" using vs by (auto simp: filter_empty_conv)
    then have "evidence f P cs = Refuse NoValue"
      using E cov unfolding evidence_def carried_def by simp
    then show ?thesis using ev rs by simp
  qed
qed simp

section \<open>Selection keeps at most three of the linker's candidates, in order\<close>

lemma select_cases:
  "select cs = take 3 cs \<or> (select cs = take 1 cs \<and> dominated (take 3 cs))"
  by (simp add: select_def)

lemma select_subset: "set (select cs) \<subseteq> set cs"
  by (auto simp: select_def dest: in_set_takeD)

lemma select_length: "length (select cs) \<le> 3"
  by (simp add: select_def min_def)

corollary decide_answer_unique_agreement:
  "decide f ps cs = Answer v \<Longrightarrow> route f ps = Some P \<Longrightarrow>
    \<forall>c\<in>set (select cs). \<forall>(p', ob)\<in>set (rows c). p' = P \<longrightarrow> ob = v"
  unfolding decide_def by (rule answer_unique_agreement)

corollary decide_answer_requires_coverage:
  "decide f ps cs = Answer v \<Longrightarrow> \<forall>c\<in>set (select cs). complete c"
  unfolding decide_def by (rule answer_requires_coverage)

corollary decide_answer_not_blank: "decide f ps cs \<noteq> Answer Blank"
  unfolding decide_def by (rule answer_not_blank)

section \<open>The admitted table (router_patterns_v4.json, 35 patterns over 17 properties)\<close>

definition admitted_patterns_v4 :: "pattern list" where
  "admitted_patterns_v4 = [
    ((STR ''who'', STR ''directed''), 57),
    ((STR ''horse'', STR ''won''), 1346),
    ((STR ''which'', STR ''home''), 466),
    ((STR ''which'', STR ''games''), 466),
    ((STR ''who'', STR ''novel''), 50),
    ((STR ''author'', STR ''created''), 170),
    ((STR ''instrument'', STR ''*''), 1303),
    ((STR ''instrument'', STR ''instrument''), 1303),
    ((STR ''capital'', STR ''capital''), 36),
    ((STR ''capital'', STR ''*''), 36),
    ((STR ''novelist'', STR ''*''), 50),
    ((STR ''novelist'', STR ''novelist''), 50),
    ((STR ''which'', STR ''instrument''), 1303),
    ((STR ''country'', STR ''president''), 27),
    ((STR ''year'', STR ''die''), 570),
    ((STR ''which'', STR ''metal''), 527),
    ((STR ''who'', STR ''composed''), 86),
    ((STR ''who'', STR ''published''), 50),
    ((STR ''author'', STR ''books''), 50),
    ((STR ''whose'', STR ''novel''), 50),
    ((STR ''author'', STR ''american''), 50),
    ((STR ''novelist'', STR ''wrote''), 50),
    ((STR ''who'', STR ''booker''), 50),
    ((STR ''who'', STR ''prize''), 50),
    ((STR ''city'', STR ''headquarters''), 159),
    ((STR ''capital'', STR ''province''), 36),
    ((STR ''country'', STR ''take''), 17),
    ((STR ''who'', STR ''oratorio''), 86),
    ((STR ''which'', STR ''albums''), 361),
    ((STR ''instrument'', STR ''musician''), 1303),
    ((STR ''which'', STR ''designed''), 84),
    ((STR ''constellation'', STR ''constellation''), 59),
    ((STR ''constellation'', STR ''*''), 59),
    ((STR ''constellation'', STR ''star''), 59),
    ((STR ''what'', STR ''join''), 208)]"

definition admitted_properties :: "natural list" where
  "admitted_properties = remdups (map snd admitted_patterns_v4)"

lemma admitted_table_size:
  "length admitted_patterns_v4 = 35 \<and> length admitted_properties = 17"
  by (simp add: admitted_patterns_v4_def admitted_properties_def)

lemma route_admitted_in_table:
  "route f admitted_patterns_v4 = Some P \<Longrightarrow> P \<in> set admitted_properties"
proof -
  assume "route f admitted_patterns_v4 = Some P"
  then have "P \<in> set (matched_props f admitted_patterns_v4)" by (simp add: route_some_iff)
  then show ?thesis by (auto simp: matched_props_def admitted_properties_def)
qed

definition decide_admitted :: "question_features \<Rightarrow> candidate list \<Rightarrow> outcome" where
  "decide_admitted f cs = decide f admitted_patterns_v4 cs"

definition reason_name :: "reason \<Rightarrow> String.literal" where
  "reason_name r = (case r of Polar \<Rightarrow> STR ''Polar'' | NoCandidate \<Rightarrow> STR ''NoCandidate''
    | HiddenHop \<Rightarrow> STR ''HiddenHop'' | NotSubject \<Rightarrow> STR ''NotSubject'' | NoPattern \<Rightarrow> STR ''NoPattern''
    | ConflictingPatterns \<Rightarrow> STR ''ConflictingPatterns'' | PastQualifier \<Rightarrow> STR ''PastQualifier''
    | IncompleteEvidence \<Rightarrow> STR ''IncompleteEvidence'' | NoValue \<Rightarrow> STR ''NoValue''
    | BlankNode \<Rightarrow> STR ''BlankNode'' | MultiValued \<Rightarrow> STR ''MultiValued''
    | Disagreement \<Rightarrow> STR ''Disagreement'' | RestatesQuestion \<Rightarrow> STR ''RestatesQuestion'')"

end
