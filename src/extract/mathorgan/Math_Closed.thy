theory Math_Closed
  imports Math_Affine
begin

text \<open>A finite closed-expression answer is evaluated on its original typed
tree. No reading of a variable is assumed. Powers are restricted to square
and cube in this exported route; division retains the evaluator's definedness
check even under multiplication by zero.\<close>
fun closed_shape :: "expr \<Rightarrow> bool" where
  "closed_shape (C q) = True"
| "closed_shape (V v) = False"
| "closed_shape (Neg e) = closed_shape e"
| "closed_shape (Add e f) = (closed_shape e \<and> closed_shape f)"
| "closed_shape (Sub e f) = (closed_shape e \<and> closed_shape f)"
| "closed_shape (Mul e f) = (closed_shape e \<and> closed_shape f)"
| "closed_shape (Div e f) = (closed_shape e \<and> closed_shape f)"
| "closed_shape (Pow e n) = (closed_shape e \<and> (n=2 \<or> n=3))"

lemma closed_shape_no_variables:
  "closed_shape e \<Longrightarrow> vars e = {}"
  by (induction e) auto

definition closed_value :: "expr \<Rightarrow> rat option" where
  "closed_value e = (if closed_shape e then ev (\<lambda>_.0) e else None)"

definition check_closed :: "expr \<Rightarrow> rat \<Rightarrow> bool" where
  "check_closed e v \<longleftrightarrow> closed_shape e \<and> ev (\<lambda>_.0) e = Some v"

theorem closed_candidate_checked:
  "closed_value e = Some v \<longleftrightarrow> check_closed e v"
  by (auto simp: closed_value_def check_closed_def split: if_splits)

theorem closed_checked_original_value:
  assumes "check_closed e v"
  shows "ev i e = Some v"
  using assms ev_closed_eq[OF closed_shape_no_variables, of e i "\<lambda>_.0"]
  by (auto simp: check_closed_def)

theorem closed_checked_kernel_value:
  assumes "check_closed e v"
  shows "kernel (EvalExpr e) = Value K_eval v"
  using assms closed_shape_no_variables[of e]
  by (auto simp: check_closed_def)

theorem closed_undefined_refuses:
  assumes "ev (\<lambda>_.0) e = None"
  shows "closed_value e = None"
  using assms by (simp add: closed_value_def)

definition closed_response :: "rat \<Rightarrow> String.literal" where
  "closed_response v = STR ''[ev:derived] '' + affine_exact v + STR ''.''"

definition closed_self_test :: bool where
  "closed_self_test \<longleftrightarrow>
    closed_value (Pow (C 5) 2) = Some 25 \<and>
    closed_value (Pow (Div (Neg (C 3)) (C 2)) 2) = Some (9/4) \<and>
    check_closed (Pow (C (-2)) 3) (-8) \<and>
    \<not> check_closed (Pow (C 5) 2) 24 \<and>
    closed_value (Div (C 1) (Sub (C 2) (C 2))) = None \<and>
    closed_value (Mul (C 0) (Div (C 1) (C 0))) = None \<and>
    closed_value (Pow (V (STR ''x'')) 2) = None \<and>
    closed_value (Pow (C 2) 4) = None"

end
