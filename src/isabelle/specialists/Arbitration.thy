theory Arbitration
  imports Main
begin

section \<open>Combo arbitration\<close>

text \<open>
  Source: \<^verbatim>\<open>upstream/root/specialists/_gate/combo_runtime_v1.py\<close>, \<^verbatim>\<open>Combo._arbitrate\<close>
  (lines 286-314) and the head fall-through in \<^verbatim>\<open>compose\<close> (lines 433-445).

  The original code, not its docstring, supplied the first five ranking fields.
  The current rule adds a final preference for a checked contextual refusal
  when those fields tie. A physical-domain rejection must not lose an otherwise
  equal contest against a generic conversion merely because it registered later.
  The ranking key of a reply starts with the tuple
  \<open>(dependence, not invented, wording, vocabulary)\<close> compared lexicographically, with pick order as the
  last tie-break.  Docstring criterion (c), the checked in-domain decline, is folded into the
  dependence count exactly as the code does it: a checked decline counts as depending on all givens.
  The code also ranks by \<^verbatim>\<open>_wording\<close> (question trigrams the reply repeats) before vocabulary; the
  docstring does not list it.

  Everything that reads text is an oracle: the number of givens (\<^verbatim>\<open>NUM\<close> regex outside code spans,
  at most 6), the counterfactual dependence count (re-asks the organ with each given nudged), the
  \<^verbatim>\<open>ASSUMED\<close> and \<^verbatim>\<open>CHECKED_DECLINE\<close> regexes, the wording trigram counts, the
  \<^verbatim>\<open>context_regex\<close> on the last sentence, and the reply's answer value.  They arrive as fields of a
  candidate.  The value comparison \<^verbatim>\<open>_same_value\<close> (relative tolerance 0.5\%) is the parameter
  \<open>same\<close>.
\<close>

text \<open>One organ's accepted reply with the oracle readings the arbitration uses.\<close>
datatype ('v, 'r) cand = Cand
  (declined: bool)        \<comment> \<open>its kind is one of its manifest's in-domain declines\<close>
  (checked: bool)         \<comment> \<open>\<^verbatim>\<open>CHECKED_DECLINE\<close> matches kind and response\<close>
  (dep_raw: nat)          \<comment> \<open>counterfactual count of givens the answer depends on\<close>
  (assumed: bool)         \<comment> \<open>\<^verbatim>\<open>ASSUMED\<close> matches the response\<close>
  (wording: "nat \<times> nat")  \<comment> \<open>question trigrams repeated: (with a number, all)\<close>
  (ctx_ask: bool)         \<comment> \<open>its \<^verbatim>\<open>context_regex\<close> matches the asking (last) sentence\<close>
  (val: "'v option")      \<comment> \<open>\<^verbatim>\<open>_answer_value\<close>: first number that is not a restated given\<close>
  (reply: 'r)

text \<open>(a) evidence use: how many of the turn's \<open>g\<close> givens the reply depends on; a checked in-domain
  decline counts as using all of them; with no givens nobody scores.\<close>
definition dep :: "nat \<Rightarrow> ('v, 'r) cand \<Rightarrow> nat" where
  "dep g c = (if declined c \<and> checked c then g else if g = 0 then 0 else dep_raw c)"

text \<open>(b) an invented given: the reply assumes a value while the turn supplies numbers (declines never count).\<close>
definition invented :: "nat \<Rightarrow> ('v, 'r) cand \<Rightarrow> bool" where
  "invented g c \<longleftrightarrow> 0 < g \<and> assumed c \<and> \<not> declined c"

text \<open>The ranking key on criteria a-d, compared lexicographically, larger is better.\<close>
definition key :: "nat \<Rightarrow> ('v, 'r) cand \<Rightarrow> nat list" where
  "key g c = [dep g c, of_bool (\<not> invented g c), fst (wording c), snd (wording c), of_bool (ctx_ask c),
    of_bool (declined c \<and> checked c \<and> ctx_ask c)]"

text \<open>Python's \<^verbatim>\<open>_same_value\<close> on optional values: two missing values agree, one missing never does.\<close>
fun same_opt :: "('v \<Rightarrow> 'v \<Rightarrow> bool) \<Rightarrow> 'v option \<Rightarrow> 'v option \<Rightarrow> bool" where
  "same_opt same None None = True"
| "same_opt same (Some a) (Some b) = same a b"
| "same_opt same _ _ = False"

text \<open>Strictly lower key, lexicographically (Python's tuple comparison).\<close>
abbreviation key_less :: "nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "key_less \<equiv> ord_class.lexordp"

subsection \<open>Choosing the best: first in pick order among the highest keys\<close>

text \<open>Scan indices left to right, moving to a later one only when its key is strictly larger.\<close>
fun scan_best :: "(nat \<Rightarrow> nat list) \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat" where
  "scan_best k b [] = b"
| "scan_best k b (x # xs) = scan_best k (if key_less (k b) (k x) then x else b) xs"

definition argmax_ix :: "(nat \<Rightarrow> nat list) \<Rightarrow> nat list \<Rightarrow> nat" where
  "argmax_ix k is = (case is of [] \<Rightarrow> 0 | i # is' \<Rightarrow> scan_best k i is')"

text \<open>The rank-1 reply: highest key, earliest in pick order.\<close>
definition best_ix :: "nat \<Rightarrow> ('v, 'r) cand list \<Rightarrow> nat" where
  "best_ix g cs = argmax_ix (\<lambda>i. key g (cs ! i)) [0..<length cs]"

text \<open>The rank-2 reply: the best of the others.\<close>
definition second_ix :: "nat \<Rightarrow> ('v, 'r) cand list \<Rightarrow> nat \<Rightarrow> nat" where
  "second_ix g cs i = argmax_ix (\<lambda>j. key g (cs ! j)) (filter (\<lambda>j. j \<noteq> i) [0..<length cs])"

subsection \<open>The rule\<close>

datatype ('v, 'r) outcome = Fallthrough | Pick "('v, 'r) cand" | Disagree "('v, 'r) cand" "('v, 'r) cand"

text \<open>The agreement shortcut: two or more non-decline answers whose values all agree with the first
  answer's (which has a value); the first answer is taken.\<close>
definition agree_shortcut :: "('v \<Rightarrow> 'v \<Rightarrow> bool) \<Rightarrow> ('v, 'r) cand list \<Rightarrow> bool" where
  "agree_shortcut same cs \<longleftrightarrow>
     (let ans = filter (\<lambda>c. \<not> declined c) cs in
      2 \<le> length ans \<and> val (hd ans) \<noteq> None \<and> (\<forall>a \<in> set (tl ans). same_opt same (val (hd ans)) (val a)))"

text \<open>Arbitration over the organs that took the turn, in the user's pick order: none means the head
  answers; one is taken; agreeing answers take the first; otherwise rank by a-d then pick order, and
  if the top two tie on a-d, are both answers, and state different numbers, show both and pick neither.\<close>
definition arbitrate :: "('v \<Rightarrow> 'v \<Rightarrow> bool) \<Rightarrow> nat \<Rightarrow> ('v, 'r) cand list \<Rightarrow> ('v, 'r) outcome" where
  "arbitrate same g cs =
     (if cs = [] then Fallthrough
      else if length cs = 1 then Pick (hd cs)
      else if agree_shortcut same cs then Pick (hd (filter (\<lambda>c. \<not> declined c) cs))
      else (let i = best_ix g cs; j = second_ix g cs i; a = cs ! i; b = cs ! j in
            if key g a = key g b \<and> \<not> declined a \<and> \<not> declined b \<and> \<not> same_opt same (val a) (val b)
            then Disagree a b else Pick a))"

text \<open>With equal dependence, assumption, wording and contextual readings,
  a checked refusal wins in either input order. These readings are premises;
  this theorem does not certify the English reader's domain classification.\<close>
theorem checked_context_refusal_wins_tie:
  "arbitrate same g [Cand False False g False (wn,wa) True v a,
      Cand True True 0 False (wn,wa) True None r] =
    Pick (Cand True True 0 False (wn,wa) True None r)"
  "arbitrate same g [Cand True True 0 False (wn,wa) True None r,
      Cand False False g False (wn,wa) True v a] =
    Pick (Cand True True 0 False (wn,wa) True None r)"
  by (simp_all add: arbitrate_def agree_shortcut_def best_ix_def second_ix_def
      argmax_ix_def key_def dep_def invented_def Let_def)

text \<open>The combo in front of the head: the picked reply, both replies labelled on disagreement, and
  the head's own reply, unchanged, when no organ took the turn.\<close>
definition combo_chat ::
  "('v \<Rightarrow> 'v \<Rightarrow> bool) \<Rightarrow> nat \<Rightarrow> ('r \<Rightarrow> 'r \<Rightarrow> 'r) \<Rightarrow> 'r \<Rightarrow> ('v, 'r) cand list \<Rightarrow> 'r" where
  "combo_chat same g show_both head cs =
     (case arbitrate same g cs of
        Fallthrough \<Rightarrow> head
      | Pick c \<Rightarrow> reply c
      | Disagree a b \<Rightarrow> show_both (reply a) (reply b))"

subsection \<open>Properties of the scan\<close>

lemma lex_not_less_trans:
  fixes a b c :: "nat list"
  shows "\<not> key_less a b \<Longrightarrow> \<not> key_less b c \<Longrightarrow> \<not> key_less a c"
  by (metis lexordp_linear lexordp_trans)

lemma scan_best_spec:
  assumes "sorted_wrt (<) (b # xs)"
  shows "scan_best k b xs \<in> set (b # xs) \<and>
         (\<forall>j \<in> set (b # xs). \<not> key_less (k (scan_best k b xs)) (k j)) \<and>
         (\<forall>j \<in> set (b # xs). k j = k (scan_best k b xs) \<longrightarrow> scan_best k b xs \<le> j)"
  using assms
proof (induction xs arbitrary: b)
  case Nil
  then show ?case using lexordp_irreflexive' by auto
next
  case (Cons x xs)
  define b' where "b' = (if key_less (k b) (k x) then x else b)"
  have sorted': "sorted_wrt (<) (b' # xs)"
    using Cons.prems by (auto simp: b'_def)
  have IH: "scan_best k b' xs \<in> set (b' # xs) \<and>
         (\<forall>j \<in> set (b' # xs). \<not> key_less (k (scan_best k b' xs)) (k j)) \<and>
         (\<forall>j \<in> set (b' # xs). k j = k (scan_best k b' xs) \<longrightarrow> scan_best k b' xs \<le> j)"
    using Cons.IH[OF sorted'] .
  have eq: "scan_best k b (x # xs) = scan_best k b' xs" by (simp add: b'_def)
  define r where "r = scan_best k b' xs"
  have bx: "b < x" and xs_gt: "\<forall>j \<in> set xs. b < j \<and> x < j" using Cons.prems by auto
  show ?case
  proof (cases "key_less (k b) (k x)")
    case True
    then have b'x: "b' = x" by (simp add: b'_def)
    have rx: "\<not> key_less (k r) (k x)" using IH b'x r_def by simp
    have rb: "\<not> key_less (k r) (k b)"
      using True rx by (metis lexordp_linear lexordp_trans)
    have "k b \<noteq> k r" using True rx by auto
    then show ?thesis using IH b'x rb bx unfolding eq r_def[symmetric] by auto
  next
    case False
    then have b'b: "b' = b" by (simp add: b'_def)
    have rb: "\<not> key_less (k r) (k b)" using IH b'b r_def by simp
    have rx: "\<not> key_less (k r) (k x)"
      using False rb lex_not_less_trans by blast
    have r_mem: "r \<in> set (b # xs)" using IH b'b r_def by simp
    have r_le_b: "k b = k r \<Longrightarrow> r \<le> b" using IH b'b r_def by simp
    have x_case: "k x = k r \<Longrightarrow> r \<le> x"
    proof -
      assume kx: "k x = k r"
      have "\<not> key_less (k b) (k r)" using False kx by simp
      then have "k b = k r" using rb lexordp_linear by blast
      then have "r \<le> b" using r_le_b by simp
      then show "r \<le> x" using bx by simp
    qed
    show ?thesis using IH b'b rx x_case unfolding eq r_def[symmetric] by auto
  qed
qed

lemma argmax_ix_spec:
  assumes "sorted_wrt (<) is" and "is \<noteq> []"
  shows "argmax_ix k is \<in> set is \<and>
         (\<forall>j \<in> set is. \<not> key_less (k (argmax_ix k is)) (k j)) \<and>
         (\<forall>j \<in> set is. k j = k (argmax_ix k is) \<longrightarrow> argmax_ix k is \<le> j)"
  using assms scan_best_spec[of _ _ k] by (cases "is") (auto simp: argmax_ix_def)

lemma best_ix_spec:
  fixes g :: nat and cs :: "('v, 'r) cand list"
  assumes "cs \<noteq> []"
  defines "i \<equiv> best_ix g cs"
  shows "i < length cs \<and>
         (\<forall>j < length cs. \<not> key_less (key g (cs ! i)) (key g (cs ! j))) \<and>
         (\<forall>j < length cs. key g (cs ! j) = key g (cs ! i) \<longrightarrow> i \<le> j)"
  using argmax_ix_spec[of "[0..<length cs]" "\<lambda>i. key g (cs ! i)"] assms
  unfolding best_ix_def by auto

lemma second_ix_spec:
  fixes g i :: nat and cs :: "('v, 'r) cand list"
  assumes "2 \<le> length cs"
  defines "j \<equiv> second_ix g cs i"
  shows "j < length cs \<and> j \<noteq> i \<and>
         (\<forall>l < length cs. l \<noteq> i \<longrightarrow> \<not> key_less (key g (cs ! j)) (key g (cs ! l))) \<and>
         (\<forall>l < length cs. l \<noteq> i \<longrightarrow> key g (cs ! l) = key g (cs ! j) \<longrightarrow> j \<le> l)"
proof -
  have ne: "filter (\<lambda>j. j \<noteq> i) [0..<length cs] \<noteq> []"
  proof -
    have "(if i = 0 then 1 else 0) \<in> set (filter (\<lambda>j. j \<noteq> i) [0..<length cs])"
      using assms by auto
    then show ?thesis by (metis empty_iff list.set(1))
  qed
  have srt: "sorted_wrt (<) (filter (\<lambda>j. j \<noteq> i) [0..<length cs])"
    by (simp add: sorted_wrt_filter)
  show ?thesis
    using argmax_ix_spec[OF srt ne, of "\<lambda>j. key g (cs ! j)"]
    unfolding j_def second_ix_def by auto
qed

subsection \<open>Theorems\<close>

text \<open>No organ took the turn: the head's reply, as is.  Some organ took it: the head is not asked.\<close>
theorem arbitrate_fallthrough:
  shows "arbitrate same g cs = Fallthrough \<longleftrightarrow> cs = []"
    and "cs = [] \<Longrightarrow> combo_chat same g show_both head cs = head"
  unfolding arbitrate_def combo_chat_def by (auto simp: Let_def)

lemma agree_shortcut_blocked:
  assumes same_sym: "\<And>x y. same x y \<Longrightarrow> same y x"
    and same_trans: "\<And>x y z. same x y \<Longrightarrow> same y z \<Longrightarrow> same x z"
    and a: "a \<in> set cs" "\<not> declined a" and b: "b \<in> set cs" "\<not> declined b"
    and diff: "\<not> same_opt same (val a) (val b)"
  shows "\<not> agree_shortcut same cs"
proof
  assume sc: "agree_shortcut same cs"
  define ans where "ans = filter (\<lambda>c. \<not> declined c) cs"
  have ne: "ans \<noteq> []" and v0: "val (hd ans) \<noteq> None"
    and all: "\<forall>x \<in> set (tl ans). same_opt same (val (hd ans)) (val x)"
    using sc unfolding agree_shortcut_def ans_def Let_def by auto
  have ok: "\<And>x. x \<in> set ans \<Longrightarrow> \<exists>v w. val (hd ans) = Some v \<and> val x = Some w \<and> same v w \<and> same w v"
  proof -
    fix x assume x: "x \<in> set ans"
    obtain v where v: "val (hd ans) = Some v" using v0 by auto
    have "x = hd ans \<or> x \<in> set (tl ans)" using x ne by (cases ans) auto
    then show "\<exists>v w. val (hd ans) = Some v \<and> val x = Some w \<and> same v w \<and> same w v"
    proof
      assume "x = hd ans"
      have "same v v \<or> True" by simp
      have "x \<in> set (tl ans) \<or> x = hd ans" using \<open>x = hd ans\<close> by simp
      show ?thesis
      proof (cases "tl ans")
        case Nil
        have "length ans \<ge> 2" using sc unfolding agree_shortcut_def ans_def Let_def by auto
        then show ?thesis using Nil by (cases ans) auto
      next
        case (Cons y ys)
        have "same_opt same (val (hd ans)) (val y)" using all Cons by auto
        then obtain w where "val y = Some w" "same v w" using v by (cases "val y") auto
        then have "same v v" using same_sym same_trans by blast
        then show ?thesis using v \<open>x = hd ans\<close> by auto
      qed
    next
      assume "x \<in> set (tl ans)"
      then have "same_opt same (val (hd ans)) (val x)" using all by auto
      then obtain w where "val x = Some w" "same v w" using v by (cases "val x") auto
      then show ?thesis using v same_sym by blast
    qed
  qed
  have "a \<in> set ans" "b \<in> set ans" using a b by (auto simp: ans_def)
  from ok[OF this(1)] ok[OF this(2)] obtain v wa wb where
    "val a = Some wa" "val b = Some wb" "same wa v" "same v wb" by force
  then have "same_opt same (val a) (val b)" using same_trans by auto
  then show False using diff by simp
qed

text \<open>If exactly two replies share the highest key on criteria a-d, both are answers (not declines),
  and they state different numbers, the combo shows both and picks neither (\<open>same\<close> must be an
  equivalence; see \<open>tolerance_not_transitive_shortcut_picks\<close> in the test theory for why).\<close>
theorem arbitrate_never_picks_disagreement:
  assumes same_sym: "\<And>x y. same x y \<Longrightarrow> same y x"
    and same_trans: "\<And>x y z. same x y \<Longrightarrow> same y z \<Longrightarrow> same x z"
    and ia: "ia < length cs" and ib: "ib < length cs" and order: "ia < ib"
    and tie: "key g (cs ! ia) = key g (cs ! ib)"
    and top: "\<forall>l < length cs. l \<noteq> ia \<longrightarrow> l \<noteq> ib \<longrightarrow> key_less (key g (cs ! l)) (key g (cs ! ia))"
    and answers: "\<not> declined (cs ! ia)" "\<not> declined (cs ! ib)"
    and differ: "\<not> same_opt same (val (cs ! ia)) (val (cs ! ib))"
  shows "arbitrate same g cs = Disagree (cs ! ia) (cs ! ib)"
proof -
  have len: "2 \<le> length cs" using ia ib order by linarith
  have nsc: "\<not> agree_shortcut same cs"
  proof (rule agree_shortcut_blocked[where a="cs ! ia" and b="cs ! ib"])
    show "same y x" if "same x y" for x y using same_sym that .
    show "same x z" if "same x y" "same y z" for x y z using same_trans that .
    show "cs ! ia \<in> set cs" using ia by simp
    show "cs ! ib \<in> set cs" using ib by simp
  qed (use answers differ in auto)
  define i where "i = best_ix g cs"
  have cs_ne: "cs \<noteq> []" using len by auto
  have bi: "i < length cs" "\<forall>j < length cs. \<not> key_less (key g (cs ! i)) (key g (cs ! j))"
      "\<forall>j < length cs. key g (cs ! j) = key g (cs ! i) \<longrightarrow> i \<le> j"
    using best_ix_spec[OF cs_ne, of g] unfolding i_def by auto
  have i_is: "i = ia"
  proof (rule ccontr)
    assume ne: "i \<noteq> ia"
    show False
    proof (cases "i = ib")
      case True
      then have "ib \<le> ia" using bi(3) ia tie by auto
      then show False using order by simp
    next
      case False
      then have "key_less (key g (cs ! i)) (key g (cs ! ia))" using top bi(1) ne by auto
      then show False using bi(2) ia by auto
    qed
  qed
  define j where "j = second_ix g cs i"
  have sj: "j < length cs" "j \<noteq> i"
      "\<forall>l < length cs. l \<noteq> i \<longrightarrow> \<not> key_less (key g (cs ! j)) (key g (cs ! l))"
      "\<forall>l < length cs. l \<noteq> i \<longrightarrow> key g (cs ! l) = key g (cs ! j) \<longrightarrow> j \<le> l"
    using second_ix_spec[OF len, of g i] unfolding j_def by auto
  have j_is: "j = ib"
  proof (rule ccontr)
    assume "j \<noteq> ib"
    then have "key_less (key g (cs ! j)) (key g (cs ! ia))" using top sj(1,2) i_is by auto
    then have "key_less (key g (cs ! j)) (key g (cs ! ib))" using tie by simp
    then show False using sj(3) ib order i_is by auto
  qed
  have "length cs \<noteq> 1" using len by simp
  then show ?thesis
    using cs_ne nsc tie answers differ i_is j_is
    unfolding arbitrate_def i_def j_def Let_def by auto
qed

text \<open>A Disagree outcome names two different replies of the turn, both answers, tied at the top on a-d,
  stating different numbers.\<close>
theorem arbitrate_disagree_sound:
  assumes "arbitrate same g cs = Disagree a b"
  shows "\<exists>ia ib. ia < length cs \<and> ib < length cs \<and> ia \<noteq> ib \<and> a = cs ! ia \<and> b = cs ! ib \<and>
           key g a = key g b \<and> (\<forall>l < length cs. \<not> key_less (key g a) (key g (cs ! l))) \<and>
           \<not> declined a \<and> \<not> declined b \<and> \<not> same_opt same (val a) (val b)"
proof -
  have len: "2 \<le> length cs" and nsc: "\<not> agree_shortcut same cs"
    using assms unfolding arbitrate_def
    by (auto split: if_splits simp: Let_def) (metis One_nat_def Suc_1 Suc_le_eq length_greater_0_conv less_le)+
  define i where "i = best_ix g cs"
  define j where "j = second_ix g cs i"
  have out: "key g (cs ! i) = key g (cs ! j) \<and> \<not> declined (cs ! i) \<and> \<not> declined (cs ! j) \<and>
             \<not> same_opt same (val (cs ! i)) (val (cs ! j)) \<and> a = cs ! i \<and> b = cs ! j"
    using assms len nsc unfolding arbitrate_def i_def j_def Let_def
    by (auto split: if_splits)
  have cs_ne: "cs \<noteq> []" using len by auto
  show ?thesis
    using best_ix_spec[OF cs_ne, of g] second_ix_spec[OF len, of g i] out
    unfolding i_def[symmetric] j_def[symmetric] by blast
qed

text \<open>The agreement shortcut is a statement about the first answer only: when it fires and a pick
  results, the pick has a value, and every non-decline reply of the turn agrees with it under \<open>same\<close>.
  \<open>same\<close> need not be transitive (it is not for the 0.5\% tolerance); it has to be reflexive, which the
  first answer's agreement with itself uses. Nothing is said about declined replies.\<close>
theorem agree_shortcut_pick_agrees:
  assumes refl: "\<And>x. same x x"
    and sc: "agree_shortcut same cs" and pick: "arbitrate same g cs = Pick c"
  shows "val c \<noteq> None \<and> (\<forall>d \<in> set cs. \<not> declined d \<longrightarrow> same_opt same (val c) (val d))"
proof -
  define ans where "ans = filter (\<lambda>x. \<not> declined x) cs"
  have len: "2 \<le> length ans" and v0: "val (hd ans) \<noteq> None"
    and all: "\<forall>a \<in> set (tl ans). same_opt same (val (hd ans)) (val a)"
    using sc unfolding agree_shortcut_def ans_def Let_def by auto
  have lcs: "length ans \<le> length cs" unfolding ans_def by (rule length_filter_le)
  have cs_ne: "cs \<noteq> []" and cs_len: "length cs \<noteq> 1" using len lcs by auto
  have c_is: "c = hd ans"
    using pick sc cs_ne cs_len unfolding arbitrate_def ans_def by (auto split: if_splits)
  obtain a0 rest where ans_eq: "ans = a0 # rest" using len by (cases ans) auto
  then have c0: "c = a0" and v0': "val a0 \<noteq> None" and all': "\<forall>a \<in> set rest. same_opt same (val a0) (val a)"
    using c_is v0 all by auto
  obtain v where v: "val a0 = Some v" using v0' by auto
  show ?thesis
  proof (intro conjI ballI impI)
    show "val c \<noteq> None" using c0 v by simp
    fix d assume d: "d \<in> set cs" "\<not> declined d"
    then have "d \<in> set ans" unfolding ans_def by simp
    then have "d = a0 \<or> d \<in> set rest" using ans_eq by auto
    then show "same_opt same (val c) (val d)"
    proof
      assume "d = a0"
      then show ?thesis using c0 v refl by simp
    next
      assume "d \<in> set rest"
      then show ?thesis using c0 all' by simp
    qed
  qed
qed

text \<open>Ties are broken only by pick order: outside the agreement shortcut a pick has the highest key
  on a-d, and among replies with that same key it is the first in pick order.\<close>
theorem arbitrate_pick_is_first_best:
  assumes "arbitrate same g cs = Pick c" and "\<not> agree_shortcut same cs"
  shows "\<exists>i < length cs. c = cs ! i \<and>
           (\<forall>l < length cs. \<not> key_less (key g c) (key g (cs ! l))) \<and>
           (\<forall>l < length cs. key g (cs ! l) = key g c \<longrightarrow> i \<le> l)"
proof (cases "length cs = 1")
  case True
  then obtain x where cs: "cs = [x]" by (cases cs) auto
  then show ?thesis using assms lexordp_irreflexive' by (auto simp: arbitrate_def)
next
  case False
  have cs_ne: "cs \<noteq> []" using assms(1) by (auto simp: arbitrate_def)
  have "c = cs ! best_ix g cs"
    using assms False cs_ne unfolding arbitrate_def Let_def by (auto split: if_splits)
  then show ?thesis using best_ix_spec[OF cs_ne, of g] by auto
qed

text \<open>Determinism up to pick order: when the a-d keys of the replies are pairwise different and the
  agreement shortcut does not fire, the outcome is the reply with the highest key, whatever the
  order the user picked the specialists in.\<close>
theorem arbitrate_total_deterministic:
  assumes distinct_keys: "\<forall>l < length cs. \<forall>m < length cs. l \<noteq> m \<longrightarrow> key g (cs ! l) \<noteq> key g (cs ! m)"
    and nsc: "\<not> agree_shortcut same cs" and ne: "cs \<noteq> []"
  shows "arbitrate same g cs = Pick c \<longleftrightarrow> c \<in> set cs \<and> (\<forall>d \<in> set cs. d \<noteq> c \<longrightarrow> key_less (key g d) (key g c))"
proof -
  define i where "i = best_ix g cs"
  have bi: "i < length cs" "\<forall>j < length cs. \<not> key_less (key g (cs ! i)) (key g (cs ! j))"
    using best_ix_spec[OF ne, of g] unfolding i_def by auto
  have top: "\<forall>d \<in> set cs. d \<noteq> cs ! i \<longrightarrow> key_less (key g d) (key g (cs ! i))"
  proof
    fix d assume d: "d \<in> set cs"
    then obtain l where l: "l < length cs" "d = cs ! l" by (auto simp: in_set_conv_nth)
    show "d \<noteq> cs ! i \<longrightarrow> key_less (key g d) (key g (cs ! i))"
    proof
      assume "d \<noteq> cs ! i"
      then have "l \<noteq> i" using l by auto
      then have "key g d \<noteq> key g (cs ! i)" using distinct_keys l bi(1) by auto
      then show "key_less (key g d) (key g (cs ! i))" using bi(2) l lexordp_linear by blast
    qed
  qed
  have pick: "arbitrate same g cs = Pick (cs ! i)"
  proof (cases "length cs = 1")
    case True
    then have "i = 0" using bi(1) by simp
    then show ?thesis using True ne by (cases cs) (auto simp: arbitrate_def)
  next
    case False
    then have len: "2 \<le> length cs" using ne by (cases cs) (auto simp: Suc_le_eq)
    have "second_ix g cs i \<noteq> i" "second_ix g cs i < length cs"
      using second_ix_spec[OF len, of g i] by auto
    then have "key g (cs ! i) \<noteq> key g (cs ! second_ix g cs i)"
      using distinct_keys bi(1) by metis
    then show ?thesis using False ne nsc unfolding arbitrate_def i_def Let_def by auto
  qed
  have uniq: "\<And>c'. c' \<in> set cs \<Longrightarrow> (\<forall>d \<in> set cs. d \<noteq> c' \<longrightarrow> key_less (key g d) (key g c')) \<Longrightarrow> c' = cs ! i"
  proof (rule ccontr)
    fix c' assume c': "c' \<in> set cs" "\<forall>d \<in> set cs. d \<noteq> c' \<longrightarrow> key_less (key g d) (key g c')" "c' \<noteq> cs ! i"
    then have "key_less (key g (cs ! i)) (key g c')" using bi(1) by auto
    moreover have "key_less (key g c') (key g (cs ! i))" using top c' by auto
    ultimately show False using lexordp_trans lexordp_irreflexive' by blast
  qed
  show ?thesis
    using pick top uniq bi(1) by auto
qed

corollary arbitrate_order_invariant:
  assumes "set cs' = set cs" and "length cs' = length cs" and "distinct cs"
    and "\<forall>x \<in> set cs. \<forall>y \<in> set cs. x \<noteq> y \<longrightarrow> key g x \<noteq> key g y"
    and "\<not> agree_shortcut same cs" and "\<not> agree_shortcut same cs'" and "cs \<noteq> []"
  shows "arbitrate same g cs' = arbitrate same g cs"
proof -
  have dist': "distinct cs'" using assms(1-3) by (simp add: card_distinct distinct_card)
  have dk: "\<forall>l < length cs. \<forall>m < length cs. l \<noteq> m \<longrightarrow> key g (cs ! l) \<noteq> key g (cs ! m)"
    using assms(3,4) by (metis nth_eq_iff_index_eq nth_mem)
  have dk': "\<forall>l < length cs'. \<forall>m < length cs'. l \<noteq> m \<longrightarrow> key g (cs' ! l) \<noteq> key g (cs' ! m)"
    using dist' assms(1,4) by (metis nth_eq_iff_index_eq nth_mem)
  have ne': "cs' \<noteq> []" using assms(1,7) by auto
  obtain c where "arbitrate same g cs = Pick c"
  proof -
    have "\<exists>c. arbitrate same g cs = Pick c"
    proof -
      define i where "i = best_ix g cs"
      have bi: "i < length cs" "\<forall>j < length cs. \<not> key_less (key g (cs ! i)) (key g (cs ! j))"
        using best_ix_spec[OF assms(7), of g] unfolding i_def by auto
      have "\<forall>d \<in> set cs. d \<noteq> cs ! i \<longrightarrow> key_less (key g d) (key g (cs ! i))"
        using bi assms(4) lexordp_linear by (metis in_set_conv_nth nth_mem)
      then show ?thesis
        using arbitrate_total_deterministic[OF dk assms(5,7)] bi(1) nth_mem by blast
    qed
    then show ?thesis using that by blast
  qed
  moreover have "arbitrate same g cs' = Pick c"
    using calculation arbitrate_total_deterministic[OF dk assms(5,7)]
          arbitrate_total_deterministic[OF dk' assms(6) ne'] assms(1) by auto
  ultimately show ?thesis by simp
qed

end
