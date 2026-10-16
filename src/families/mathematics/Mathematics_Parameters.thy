theory Mathematics_Parameters
  imports Mathematics_Polynomial
begin

text \<open>Coefficient parameters are independent of the polynomial variable.
A coefficient can be an exact partial expression; its missing parameter or
zero division remains an unresolved specialization, not a fabricated zero.\<close>
type_synonym parameter_polynomial = "(nat \<times> math_expr) list"

fun instantiate_coefficients :: "(nat \<Rightarrow> rat option) \<Rightarrow> parameter_polynomial \<Rightarrow> exact_polynomial option" where
  "instantiate_coefficients env [] = Some []"
| "instantiate_coefficients env ((n,c)#p) =
    (case math_eval env c of None \<Rightarrow> None | Some q \<Rightarrow>
      map_option ((#) (n,q)) (instantiate_coefficients env p))"

inductive coefficient_instance :: "(nat \<Rightarrow> rat option) \<Rightarrow> parameter_polynomial \<Rightarrow> exact_polynomial \<Rightarrow> bool" where
  empty: "coefficient_instance env [] []"
| entry: "math_value env c q \<Longrightarrow> coefficient_instance env p coeffs \<Longrightarrow>
    coefficient_instance env ((n,c)#p) ((n,q)#coeffs)"

lemma coefficient_instance_eval:
  "coefficient_instance env schema coeffs \<Longrightarrow> instantiate_coefficients env schema = Some coeffs"
  by (induction rule: coefficient_instance.induct) (auto dest: math_value_eval)

lemma coefficient_eval_instance:
  "instantiate_coefficients env schema = Some coeffs \<Longrightarrow> coefficient_instance env schema coeffs"
proof (induction schema arbitrary: coeffs)
  case Nil
  then show ?case by (simp add: coefficient_instance.empty)
next
  case (Cons entry schema)
  obtain n c where entry: "entry = (n,c)" by (cases entry) auto
  from Cons.prems obtain q rest where evaluated:
    "math_eval env c = Some q" "instantiate_coefficients env schema = Some rest"
    "coeffs = (n,q)#rest"
    by (auto simp: entry split: option.splits)
  have "math_value env c q" using evaluated(1) math_eval_refinement by blast
  moreover have "coefficient_instance env schema rest" using Cons.IH evaluated(2) by blast
  ultimately show ?case using evaluated(3) entry by (auto intro: coefficient_instance.entry)
qed

theorem coefficient_refinement:
  "instantiate_coefficients env schema = Some coeffs \<longleftrightarrow> coefficient_instance env schema coeffs"
  using coefficient_instance_eval coefficient_eval_instance by blast

definition parameter_derivative :: "parameter_polynomial \<Rightarrow> parameter_polynomial" where
  "parameter_derivative schema = map (\<lambda>(n,c). (n-1,Times c (Rational (of_nat n)))) schema"

lemma map_option_map_cons:
  "map_option (map f) (map_option ((#) x) xs) = map_option ((#) (f x)) (map_option (map f) xs)"
  by (cases xs) simp_all

lemma parameter_derivative_specialization:
  "instantiate_coefficients env (parameter_derivative schema) =
    map_option polynomial_derivative (instantiate_coefficients env schema)"
  by (induction schema)
    (auto simp: parameter_derivative_def polynomial_derivative_def map_option_map_cons split: prod.splits option.splits)

theorem parameter_derivative_real:
  assumes "coefficient_instance env schema p"
  shows "\<exists>dp. coefficient_instance env (parameter_derivative schema) dp \<and>
    (\<forall>x. DERIV (polynomial_real p) x :> polynomial_real dp x)"
proof -
  have specialized: "instantiate_coefficients env (parameter_derivative schema) = Some (polynomial_derivative p)"
    using coefficient_instance_eval[OF assms]
    by (simp add: parameter_derivative_specialization)
  have instantiated_law: "coefficient_instance env (parameter_derivative schema) (polynomial_derivative p)"
    using coefficient_eval_instance[OF specialized] .
  show ?thesis using instantiated_law polynomial_derivative_correct by blast
qed

export_code instantiate_coefficients parameter_derivative
  in SML module_name Mathematics_Parameters
end
