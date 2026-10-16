theory Mathematics_Exact
  imports "Veri7vn_Codegen.Veri7vn_Codegen" "HOL.Rat"
begin

text \<open>Finite family syntax; names denote parameters, never executable host text.
Undefined arithmetic is represented by None, including zero division.\<close>
datatype math_expr = Rational rat | Parameter nat
  | Negate math_expr | Plus math_expr math_expr | Times math_expr math_expr
  | Divide math_expr math_expr | Power math_expr nat | Absolute math_expr

fun math_eval :: "(nat \<Rightarrow> rat option) \<Rightarrow> math_expr \<Rightarrow> rat option" where
  "math_eval env (Rational q) = Some q"
| "math_eval env (Parameter n) = env n"
| "math_eval env (Negate a) = map_option uminus (math_eval env a)"
| "math_eval env (Plus a b) = (case math_eval env a of None \<Rightarrow> None | Some x \<Rightarrow> map_option ((+) x) (math_eval env b))"
| "math_eval env (Times a b) = (case math_eval env a of None \<Rightarrow> None | Some x \<Rightarrow> map_option ((*) x) (math_eval env b))"
| "math_eval env (Divide a b) = (case math_eval env a of None \<Rightarrow> None | Some x \<Rightarrow> (case math_eval env b of None \<Rightarrow> None | Some y \<Rightarrow> if y = 0 then None else Some (x / y)))"
| "math_eval env (Power a n) = map_option (\<lambda>x. x ^ n) (math_eval env a)"
| "math_eval env (Absolute a) = map_option abs (math_eval env a)"

fun math_parameters :: "math_expr \<Rightarrow> nat list" where
  "math_parameters (Rational q) = []"
| "math_parameters (Parameter n) = [n]"
| "math_parameters (Negate a) = math_parameters a"
| "math_parameters (Plus a b) = math_parameters a @ math_parameters b"
| "math_parameters (Times a b) = math_parameters a @ math_parameters b"
| "math_parameters (Divide a b) = math_parameters a @ math_parameters b"
| "math_parameters (Power a n) = math_parameters a"
| "math_parameters (Absolute a) = math_parameters a"

definition missing_math_parameters where
  "missing_math_parameters env expression = remdups (filter (\<lambda>n. env n=None) (math_parameters expression))"

text \<open>Independent relational meaning, used by certificates and refinement.\<close>
inductive math_value :: "(nat \<Rightarrow> rat option) \<Rightarrow> math_expr \<Rightarrow> rat \<Rightarrow> bool" where
  literal: "math_value env (Rational q) q"
| parameter: "env n = Some q \<Longrightarrow> math_value env (Parameter n) q"
| negate: "math_value env a x \<Longrightarrow> math_value env (Negate a) (-x)"
| plus: "math_value env a x \<Longrightarrow> math_value env b y \<Longrightarrow> math_value env (Plus a b) (x+y)"
| times: "math_value env a x \<Longrightarrow> math_value env b y \<Longrightarrow> math_value env (Times a b) (x*y)"
| divide: "math_value env a x \<Longrightarrow> math_value env b y \<Longrightarrow> y \<noteq> 0 \<Longrightarrow> math_value env (Divide a b) (x/y)"
| power: "math_value env a x \<Longrightarrow> math_value env (Power a n) (x^n)"
| absolute: "math_value env a x \<Longrightarrow> math_value env (Absolute a) (abs x)"

lemma math_value_eval: "math_value env e q \<Longrightarrow> math_eval env e = Some q"
  by (induction rule: math_value.induct) auto

lemma math_eval_value: "math_eval env e = Some q \<Longrightarrow> math_value env e q"
  by (induction e arbitrary: q)
     (auto split: option.splits if_splits intro: math_value.intros)

theorem math_eval_refinement: "math_eval env e = Some q \<longleftrightarrow> math_value env e q"
  using math_value_eval math_eval_value by blast

lemma math_eval_no_value:
  "math_eval env expression = None \<longleftrightarrow> \<not> (\<exists>q. math_value env expression q)"
  using math_eval_refinement[of env expression] by (cases "math_eval env expression") auto

text \<open>Finite executable environments use map_of's first-binding semantics.
This typed entry point does not require passing an arbitrary host function.\<close>
definition math_eval_bindings where
  "math_eval_bindings bindings expression = math_eval (map_of bindings) expression"

theorem math_bindings_refinement:
  "math_eval_bindings bindings expression = Some q \<longleftrightarrow>
   math_value (map_of bindings) expression q"
  by (simp add: math_eval_bindings_def math_eval_refinement)

lemma division_zero_undefined [simp]:
  "math_eval env (Divide e (Rational 0)) = None"
  by (simp split: option.splits)

text \<open>No equality result is issued when either operand is undefined.\<close>
definition math_equal where
  "math_equal env a b = (case math_eval env a of None \<Rightarrow> None | Some x \<Rightarrow> map_option ((=) x) (math_eval env b))"

lemma equality_sound:
  "math_equal env a b = Some True \<Longrightarrow> \<exists>x. math_value env a x \<and> math_value env b x"
  by (auto simp: math_equal_def math_eval_refinement split: option.splits)

definition within_tolerance :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> bool" where
  "within_tolerance tolerance a b \<longleftrightarrow> 0 \<le> tolerance \<and> abs (a-b) \<le> tolerance"

text \<open>A certificate for a principal square root is checked rather than guessed.
Only rational roots are represented by this kernel; nonrational roots require a
separate symbolic representation.\<close>
definition principal_root_witness :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "principal_root_witness x y \<longleftrightarrow> 0 \<le> y \<and> y*y = x"

lemma square_root_branch:
  "principal_root_witness (x*x) (abs x)"
  by (simp add: principal_root_witness_def abs_mult[symmetric])

lemma square_root_identity_condition:
  "principal_root_witness (x*x) x \<longleftrightarrow> 0 \<le> x"
  by (simp add: principal_root_witness_def)

lemma principal_root_unique:
  "principal_root_witness x a \<Longrightarrow> principal_root_witness x b \<Longrightarrow> a=b"
  unfolding principal_root_witness_def
  by (metis power2_eq_imp_eq power2_eq_square)

text \<open>Complete open-interval characterization, not sampled membership.\<close>
definition square_interval :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "square_interval radius x \<longleftrightarrow> 0 < radius \<and> -radius < x \<and> x < radius"

lemma square_interval_complete:
  assumes "0 < r"
  shows "square_interval r x \<longleftrightarrow> x*x < r*r"
proof -
  have square: "x*x < r*r \<longleftrightarrow> abs x < r"
    by (metis abs_le_square_iff abs_of_pos assms not_le power2_eq_square)
  show ?thesis using assms by (auto simp: square_interval_def square abs_less_iff; linarith)
qed

text \<open>A cancellation rewrite needs an execution guard, not a retained
unproved source premise. In particular, x/x is not replaced at zero.\<close>
lemma cancel_self_guarded:
  assumes "math_eval env e = Some x" "x \<noteq> 0"
  shows "math_eval env (Divide e e) = math_eval env (Rational 1)"
  using assms by simp

lemma zero_cancel_refuted:
  "math_eval env (Divide (Rational 0) (Rational 0)) \<noteq> math_eval env (Rational 1)"
  by simp

text \<open>Candidate validation deliberately provides existence only.\<close>
definition equation_witness where
  "equation_witness env lhs rhs candidate = math_equal (env(0 := Some candidate)) lhs rhs"

lemma equation_witness_sound:
  "equation_witness env lhs rhs c = Some True \<Longrightarrow>
   \<exists>q. math_value (env(0 := Some c)) lhs q \<and> math_value (env(0 := Some c)) rhs q"
  using equality_sound unfolding equation_witness_def by blast

export_code math_eval math_eval_bindings math_equal within_tolerance principal_root_witness
  square_interval equation_witness in SML module_name Mathematics_Exact

end
