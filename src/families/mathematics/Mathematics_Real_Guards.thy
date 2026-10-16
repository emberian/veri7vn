theory Mathematics_Real_Guards
  imports Mathematics_Exact "HOL.NthRoot"
begin

text \<open>Isabelle's total real root is not itself our partial user-facing real
square root. The domain guard is explicit even for native logical expressions.\<close>
definition guarded_real_sqrt :: "real \<Rightarrow> real option" where
  "guarded_real_sqrt x = (if x < 0 then None else Some (sqrt x))"

lemma guarded_negative_sqrt:
  "x < 0 \<Longrightarrow> guarded_real_sqrt x = None"
  by (simp add: guarded_real_sqrt_def)

lemma real_square_branch:
  "guarded_real_sqrt (x*x) = Some (abs x)"
  by (simp add: guarded_real_sqrt_def)

lemma real_square_identity_condition:
  "guarded_real_sqrt (x*x) = Some x \<longleftrightarrow> 0 \<le> x"
  by (auto simp: real_square_branch abs_if; linarith)

lemma rational_root_real_bridge:
  assumes "principal_root_witness x y"
  shows "guarded_real_sqrt (of_rat x) = Some (of_rat y)"
proof -
  have nonnegative: "(0::real) \<le> of_rat y"
    using assms by (simp add: principal_root_witness_def)
  have equation: "y*y=x" using assms by (simp add: principal_root_witness_def)
  have square: "(of_rat y::real)^2 = of_rat x"
    using arg_cong[OF equation, of "\<lambda>q. (of_rat q::real)"]
    by (simp add: of_rat_mult power2_eq_square)
  have input_nonnegative: "(0::real) \<le> of_rat x"
    using square zero_le_power2[of "of_rat y::real"] by simp
  show ?thesis
    using real_sqrt_unique[OF square nonnegative] input_nonnegative
    by (simp add: guarded_real_sqrt_def)
qed

definition real_square_interval :: "rat \<Rightarrow> real \<Rightarrow> bool" where
  "real_square_interval radius x \<longleftrightarrow> 0 < radius \<and> -of_rat radius < x \<and> x < of_rat radius"

theorem real_square_interval_complete:
  assumes "0 < r"
  shows "real_square_interval r x \<longleftrightarrow> x*x < (of_rat r)*(of_rat r)"
proof -
  have positive: "(0::real) < of_rat r" using assms by simp
  have square: "x*x < (of_rat r)*(of_rat r) \<longleftrightarrow> abs x < of_rat r"
    by (metis abs_le_square_iff abs_of_pos positive not_le power2_eq_square)
  show ?thesis using assms by (auto simp: real_square_interval_def square abs_less_iff; linarith)
qed

text \<open>These real definitions are logical subjects, not an unqualified
runtime real-number codec or a generated arbitrary-real root algorithm.\<close>
end
