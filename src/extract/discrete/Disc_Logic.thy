theory Disc_Logic
  imports Disc_Dtext
begin

text \<open>logic-v3: propositional logic decided by the full truth table. A
formula is a classified by every row; an argument is valid iff no row makes
the premises true and the conclusion false, and an invalid one carries that
row. The six named argument forms are decided by the same table.\<close>

datatype fm = FVar nat | FNeg fm | FConj fm fm | FDisj fm fm | FImpl fm fm | FEquiv fm fm

fun eval :: "(nat \<Rightarrow> bool) \<Rightarrow> fm \<Rightarrow> bool" where
  "eval g (FVar x) = g x"
| "eval g (FNeg a) = (\<not> eval g a)"
| "eval g (FConj a b) = (eval g a \<and> eval g b)"
| "eval g (FDisj a b) = (eval g a \<or> eval g b)"
| "eval g (FImpl a b) = (eval g a \<longrightarrow> eval g b)"
| "eval g (FEquiv a b) = (eval g a = eval g b)"

fun rawvars :: "fm \<Rightarrow> nat list" where
  "rawvars (FVar x) = [x]"
| "rawvars (FNeg a) = rawvars a"
| "rawvars (FConj a b) = rawvars a @ rawvars b"
| "rawvars (FDisj a b) = rawvars a @ rawvars b"
| "rawvars (FImpl a b) = rawvars a @ rawvars b"
| "rawvars (FEquiv a b) = rawvars a @ rawvars b"

lemma eval_cong: "(\<forall>x \<in> set (rawvars f). g x = h x) \<Longrightarrow> eval g f = eval h f"
  by (induction f) auto

definition fvars :: "fm \<Rightarrow> nat list" where
  "fvars f = sort (remdups (rawvars f))"

definition avars :: "fm list \<Rightarrow> fm \<Rightarrow> nat list" where
  "avars ps c = sort (remdups (concat (map rawvars ps) @ rawvars c))"

lemma set_fvars [simp]: "set (fvars f) = set (rawvars f)" by (simp add: fvars_def)
lemma set_avars [simp]: "set (avars ps c) = set (concat (map rawvars ps)) \<union> set (rawvars c)"
  by (simp add: avars_def)

text \<open>All assignments to the listed variables, the first variable most
significant and True before False (Python's @{text itertools.product}).\<close>
fun envs :: "nat list \<Rightarrow> (nat \<Rightarrow> bool) list" where
  "envs [] = [\<lambda>_. False]"
| "envs (v # vs) = concat (map (\<lambda>b. map (\<lambda>e. e(v := b)) (envs vs)) [True, False])"

lemma length_envs: "length (envs vs) = 2 ^ length vs"
  by (induction vs) (simp_all add: length_concat)

lemma envs_cover: "\<exists>e \<in> set (envs vs). \<forall>x \<in> set vs. e x = g x"
proof (induction vs)
  case Nil
  show ?case by simp
next
  case (Cons v vs)
  from Cons.IH obtain e where e1: "e \<in> set (envs vs)" and e2: "\<forall>x \<in> set vs. e x = g x" by blast
  have "e(v := g v) \<in> set (envs (v # vs))" using e1 by (cases "g v") auto
  moreover have "\<forall>x \<in> set (v # vs). (e(v := g v)) x = g x" using e2 by auto
  ultimately show ?case by blast
qed

lemma len_filter_all: "length (filter P xs) = length xs \<longleftrightarrow> (\<forall>x \<in> set xs. P x)"
proof (induction xs)
  case Nil
  show ?case by simp
next
  case (Cons y ys)
  show ?case
  proof (cases "P y")
    case True
    then show ?thesis using Cons.IH by simp
  next
    case False
    have h: "length (filter P ys) \<le> length ys" by (rule length_filter_le)
    have "length (filter P ys) \<noteq> Suc (length ys)" using h by arith
    then show ?thesis using False by simp
  qed
qed

lemma len_filter_none: "length (filter P xs) = 0 \<longleftrightarrow> (\<forall>x \<in> set xs. \<not> P x)"
  by (simp add: filter_empty_conv)

section \<open>Classifying a formula\<close>

datatype cls = Taut | Contr | Conting

definition rows_true :: "fm \<Rightarrow> nat" where
  "rows_true f = length (filter (\<lambda>e. eval e f) (envs (fvars f)))"

definition nrows :: "fm \<Rightarrow> nat" where
  "nrows f = length (envs (fvars f))"

definition classify :: "fm \<Rightarrow> cls" where
  "classify f = (if rows_true f = nrows f then Taut else if rows_true f = 0 then Contr else Conting)"

lemma nrows_pos: "0 < nrows f" by (simp add: nrows_def length_envs)

lemma all_rows_iff: "(\<forall>e \<in> set (envs (fvars f)). eval e f) \<longleftrightarrow> (\<forall>g. eval g f)"
proof
  assume a: "\<forall>e \<in> set (envs (fvars f)). eval e f"
  show "\<forall>g. eval g f"
  proof
    fix g
    from envs_cover[of "fvars f" g] obtain e where "e \<in> set (envs (fvars f))"
      and "\<forall>x \<in> set (fvars f). e x = g x" by blast
    then show "eval g f" using a eval_cong[of f e g] by auto
  qed
qed auto

lemma any_rows_iff: "(\<exists>e \<in> set (envs (fvars f)). eval e f) \<longleftrightarrow> (\<exists>g. eval g f)"
proof
  assume "\<exists>e \<in> set (envs (fvars f)). eval e f"
  then show "\<exists>g. eval g f" by blast
next
  assume "\<exists>g. eval g f"
  then obtain g where g: "eval g f" by blast
  from envs_cover[of "fvars f" g] obtain e where "e \<in> set (envs (fvars f))"
    and "\<forall>x \<in> set (fvars f). e x = g x" by blast
  then show "\<exists>e \<in> set (envs (fvars f)). eval e f" using g eval_cong[of f e g] by auto
qed

theorem classify_taut: "classify f = Taut \<longleftrightarrow> (\<forall>g. eval g f)"
  unfolding classify_def rows_true_def nrows_def
  using len_filter_all[of "\<lambda>e. eval e f" "envs (fvars f)"] all_rows_iff[of f] by auto

theorem classify_contr: "classify f = Contr \<longleftrightarrow> (\<forall>g. \<not> eval g f)"
proof -
  have n: "0 < nrows f" by (rule nrows_pos)
  have z: "rows_true f = 0 \<longleftrightarrow> (\<forall>g. \<not> eval g f)"
    unfolding rows_true_def
    using len_filter_none[of "\<lambda>e. eval e f" "envs (fvars f)"] any_rows_iff[of f] by auto
  show ?thesis using n z unfolding classify_def nrows_def rows_true_def by auto
qed

theorem classify_conting: "classify f = Conting \<longleftrightarrow> (\<exists>g. eval g f) \<and> (\<exists>g. \<not> eval g f)"
proof -
  have a: "classify f \<noteq> Taut \<longleftrightarrow> (\<exists>g. \<not> eval g f)" using classify_taut by auto
  have b: "classify f \<noteq> Contr \<longleftrightarrow> (\<exists>g. eval g f)" using classify_contr by auto
  show ?thesis using a b by (cases "classify f") auto
qed

section \<open>Arguments\<close>

definition cex :: "fm list \<Rightarrow> fm \<Rightarrow> (nat \<Rightarrow> bool) option" where
  "cex ps c = List.find (\<lambda>e. (\<forall>p \<in> set ps. eval e p) \<and> \<not> eval e c) (envs (avars ps c))"

lemma cover_args:
  fixes ps c g
  obtains e where "e \<in> set (envs (avars ps c))"
    "\<forall>p \<in> set ps. eval e p = eval g p" "eval e c = eval g c"
proof -
  from envs_cover[of "avars ps c" g] obtain e where e: "e \<in> set (envs (avars ps c))"
    and agree: "\<forall>x \<in> set (avars ps c). e x = g x" by blast
  have "\<forall>p \<in> set ps. eval e p = eval g p"
  proof
    fix p assume p: "p \<in> set ps"
    have "\<forall>x \<in> set (rawvars p). e x = g x" using agree p by auto
    then show "eval e p = eval g p" by (rule eval_cong)
  qed
  moreover have "eval e c = eval g c" using agree by (intro eval_cong) auto
  ultimately show ?thesis using e that by blast
qed

theorem argument_valid:
  "cex ps c = None \<longleftrightarrow> (\<forall>g. (\<forall>p \<in> set ps. eval g p) \<longrightarrow> eval g c)"
proof
  assume n: "cex ps c = None"
  show "\<forall>g. (\<forall>p \<in> set ps. eval g p) \<longrightarrow> eval g c"
  proof (intro allI impI)
    fix g assume pg: "\<forall>p \<in> set ps. eval g p"
    obtain e where e: "e \<in> set (envs (avars ps c))" and ep: "\<forall>p \<in> set ps. eval e p = eval g p"
      and ec: "eval e c = eval g c" by (rule cover_args)
    have "\<not> ((\<forall>p \<in> set ps. eval e p) \<and> \<not> eval e c)" using n e
      by (auto simp: cex_def find_None_iff)
    then show "eval g c" using pg ep ec by auto
  qed
next
  assume v: "\<forall>g. (\<forall>p \<in> set ps. eval g p) \<longrightarrow> eval g c"
  then show "cex ps c = None" by (auto simp: cex_def find_None_iff)
qed

theorem argument_witness:
  assumes "cex ps c = Some e"
  shows "(\<forall>p \<in> set ps. eval e p) \<and> \<not> eval e c"
  using assms unfolding cex_def by (auto simp: find_Some_iff)

section \<open>Named argument forms\<close>

datatype form = F_mp | F_mt | F_ac | F_da | F_hs | F_ds

fun form_prems :: "form \<Rightarrow> fm list" where
  "form_prems F_mp = [FImpl (FVar 0) (FVar 1), FVar 0]"
| "form_prems F_mt = [FImpl (FVar 0) (FVar 1), FNeg (FVar 1)]"
| "form_prems F_ac = [FImpl (FVar 0) (FVar 1), FVar 1]"
| "form_prems F_da = [FImpl (FVar 0) (FVar 1), FNeg (FVar 0)]"
| "form_prems F_hs = [FImpl (FVar 0) (FVar 1), FImpl (FVar 1) (FVar 2)]"
| "form_prems F_ds = [FDisj (FVar 0) (FVar 1), FNeg (FVar 0)]"

fun form_concl :: "form \<Rightarrow> fm" where
  "form_concl F_mp = FVar 1"
| "form_concl F_mt = FNeg (FVar 0)"
| "form_concl F_ac = FVar 0"
| "form_concl F_da = FNeg (FVar 1)"
| "form_concl F_hs = FImpl (FVar 0) (FVar 2)"
| "form_concl F_ds = FVar 1"

definition form_valid :: "form \<Rightarrow> bool" where
  "form_valid f = (cex (form_prems f) (form_concl f) = None)"

text \<open>What the organ declares for each named form, decided by the truth table.\<close>
theorem form_semantics:
  "form_valid f \<longleftrightarrow> (\<forall>g. (\<forall>p \<in> set (form_prems f). eval g p) \<longrightarrow> eval g (form_concl f))"
  unfolding form_valid_def by (rule argument_valid)

text \<open>What the organ declares for each named form, decided by the truth table.\<close>
theorem form_table:
  "form_valid F_mp \<and> form_valid F_mt \<and> form_valid F_hs \<and> form_valid F_ds
   \<and> \<not> form_valid F_ac \<and> \<not> form_valid F_da"
proof -
  have ac: "\<not> form_valid F_ac"
    unfolding form_semantics by (rule notI, drule spec[of _ "\<lambda>x. x = 1"], simp)
  have da: "\<not> form_valid F_da"
    unfolding form_semantics by (rule notI, drule spec[of _ "\<lambda>x. x = 1"], simp)
  show ?thesis using ac da by (auto simp: form_semantics)
qed

section \<open>Requests, kernel and reply\<close>

datatype lreq = L_formula fm | L_argument "fm list" fm | L_form form
  | L_bad_formula | L_bad_argument

datatype lout =
    LClass cls nat nat
  | LValid nat
  | LInvalid "(nat \<times> bool) list"
  | LForm form bool
  | LUnparsed bool

definition row_of :: "nat list \<Rightarrow> (nat \<Rightarrow> bool) \<Rightarrow> (nat \<times> bool) list" where
  "row_of vs e = map (\<lambda>v. (v, e v)) vs"

definition l_kernel :: "lreq \<Rightarrow> lout" where
  "l_kernel r = (case r of
      L_formula f \<Rightarrow> LClass (classify f) (rows_true f) (nrows f)
    | L_argument ps c \<Rightarrow>
        (case cex ps c of None \<Rightarrow> LValid (2 ^ length (avars ps c))
         | Some e \<Rightarrow> LInvalid (row_of (avars ps c) e))
    | L_form f \<Rightarrow> LForm f (form_valid f)
    | L_bad_formula \<Rightarrow> LUnparsed True
    | L_bad_argument \<Rightarrow> LUnparsed False)"

theorem l_formula_sound:
  "l_kernel (L_formula f) = LClass c t n \<Longrightarrow>
     (c = Taut \<longleftrightarrow> (\<forall>g. eval g f)) \<and> (c = Contr \<longleftrightarrow> (\<forall>g. \<not> eval g f))
     \<and> (c = Conting \<longleftrightarrow> (\<exists>g. eval g f) \<and> (\<exists>g. \<not> eval g f))"
  using classify_taut classify_contr classify_conting by (auto simp: l_kernel_def)

theorem l_argument_valid_sound:
  "l_kernel (L_argument ps c) = LValid n \<Longrightarrow>
     (\<forall>g. (\<forall>p \<in> set ps. eval g p) \<longrightarrow> eval g c)"
  using argument_valid by (auto simp: l_kernel_def split: option.splits)

theorem l_argument_invalid_sound:
  "l_kernel (L_argument ps c) = LInvalid row \<Longrightarrow>
     \<exists>e. row = row_of (avars ps c) e \<and> (\<forall>p \<in> set ps. eval e p) \<and> \<not> eval e c"
  using argument_witness by (auto simp: l_kernel_def split: option.splits)

definition letters :: "String.literal list" where
  "letters = [STR ''a'', STR ''b'', STR ''c'', STR ''d'', STR ''e'', STR ''f'', STR ''g'', STR ''h'',
    STR ''i'', STR ''j'', STR ''k'', STR ''l'', STR ''m'', STR ''n'', STR ''o'', STR ''p'', STR ''q'',
    STR ''r'', STR ''s'', STR ''t'', STR ''u'', STR ''v'', STR ''w'', STR ''x'', STR ''y'', STR ''z'']"

definition row_text :: "(nat \<times> bool) list \<Rightarrow> String.literal" where
  "row_text row = (case map (\<lambda>p. letters ! (fst p mod 26) + STR ''='' + (if snd p then STR ''T'' else STR ''F'')) row of
      [] \<Rightarrow> STR '''' | x # r \<Rightarrow> foldl (\<lambda>a b. a + STR '', '' + b) x r)"

fun form_name :: "form \<Rightarrow> String.literal" where
  "form_name F_mp = STR ''modus ponens''" | "form_name F_mt = STR ''modus tollens''"
| "form_name F_ac = STR ''affirming the consequent''" | "form_name F_da = STR ''denying the antecedent''"
| "form_name F_hs = STR ''hypothetical syllogism''" | "form_name F_ds = STR ''disjunctive syllogism''"

definition cls_name :: "cls \<Rightarrow> String.literal" where
  "cls_name c = (case c of Taut \<Rightarrow> STR ''tautology'' | Contr \<Rightarrow> STR ''contradiction'' | Conting \<Rightarrow> STR ''contingent'')"

definition l_reply :: "lreq \<Rightarrow> reply" where
  "l_reply r = (case l_kernel r of
      LClass c t n \<Rightarrow>
        Reply True (STR ''formula'')
          [PS (STR ''It is '' + (if c = Conting then STR '''' else STR ''a '') + cls_name c + STR '' (''
              + show_nat t + STR '' of '' + show_nat n + STR '' truth-table rows true).'')] JNone
    | LValid n \<Rightarrow>
        Reply True (STR ''argument'')
          [PS (STR ''Valid - the argument is valid (no row of the '' + show_nat n
              + STR ''-row truth table makes the premises true and the conclusion false).'')] JNone
    | LInvalid row \<Rightarrow>
        Reply True (STR ''argument'')
          [PS (STR ''Invalid - the argument is invalid (counterexample: '' + row_text row
              + STR '' makes every premise true and the conclusion false).'')] JNone
    | LForm f v \<Rightarrow>
        Reply True (STR ''form'')
          [PS (STR ''This is '' + form_name f + STR '' - ''
              + (if v then STR ''a valid argument form'' else STR ''an invalid argument, a formal fallacy'')
              + STR '' (''
              + (if v then STR ''the conclusion follows in every case''
                 else STR ''a counterexample row makes the premises true and the conclusion false'')
              + STR '').'')] JNone
    | LUnparsed True \<Rightarrow>
        Reply False (STR ''underspecified'')
          [PS (STR ''I could not parse that formula; use single-letter variables with ~ & | -> <->.'')] JNone
    | LUnparsed False \<Rightarrow>
        Reply False (STR ''underspecified'')
          [PS (STR ''I could not parse that argument; write it like p -> q, p |- q using single-letter variables.'')] JNone)"

theorem l_reply_answered:
  "answered (l_reply r) \<longleftrightarrow> (\<forall>b. l_kernel r \<noteq> LUnparsed b)"
  by (auto simp: l_reply_def split: lout.splits bool.splits)

end
