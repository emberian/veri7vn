theory Exact_Mathematics_Example
  imports "Veri7vn_Mathematics.Mathematics_Syntax" "Veri7vn_Mathematics.Mathematics_Solutions" "Veri7vn_Mathematics.Mathematics_Polynomial"
begin

text \<open>A specialist author can use the exact family directly. The expression
1/3 + 1/6 stays rational throughout; undefined and syntax errors stay separate.\<close>
definition fraction_request where
  "fraction_request = [FractionToken 1 3, FractionToken 1 6, PlusToken]"

lemma fraction_answer:
  "evaluate_tokens (\<lambda>_. None) fraction_request = Some (Some (1/2))"
  by (simp add: fraction_request_def evaluate_tokens_def parse_math_def)

text \<open>For the polynomial x squared, instantiate the whole primitive family
with any rational constant; the constant remains part of the typed value.\<close>
definition square_primitive where
  "square_primitive = Antiderivative [(2,1)]"

lemma square_primitive_derivative:
  "DERIV (polynomial_real (primitive_instance square_primitive c)) x :> x^2"
  using antiderivative_instance_correct[of "[(2,1)]" c x]
  by (simp add: square_primitive_def)

text \<open>The complete linear answer licenses all solutions; checking one
candidate alone would license only that witness.\<close>
lemma all_linear_answers:
  "linear_contains (solve_linear 2 (-1)) x \<longleftrightarrow> 2*x-1=0"
  using solve_linear_complete[of 2 "-1" x] by simp

end
