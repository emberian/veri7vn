theory Mathematics_Polynomial
  imports Mathematics_Exact "HOL.Deriv"
begin

text \<open>Sparse monomial lists retain duplicates: their semantics is addition.
Coefficients remain rational and exact; the real interpretation is separate.\<close>
type_synonym exact_polynomial = "(nat \<times> rat) list"

fun polynomial_at :: "exact_polynomial \<Rightarrow> rat \<Rightarrow> rat" where
  "polynomial_at [] x = 0"
| "polynomial_at ((n,c)#p) x = c*x^n + polynomial_at p x"

fun polynomial_real :: "exact_polynomial \<Rightarrow> real \<Rightarrow> real" where
  "polynomial_real [] x = 0"
| "polynomial_real ((n,c)#p) x = of_rat c*x^n + polynomial_real p x"

definition polynomial_derivative :: "exact_polynomial \<Rightarrow> exact_polynomial" where
  "polynomial_derivative p = map (\<lambda>(n,c). (n-1, c * of_nat n)) p"

definition polynomial_primitive :: "exact_polynomial \<Rightarrow> exact_polynomial" where
  "polynomial_primitive p = map (\<lambda>(n,c). (Suc n, c / of_nat (Suc n))) p"

datatype antiderivative_family = Antiderivative exact_polynomial

fun primitive_instance :: "antiderivative_family \<Rightarrow> rat \<Rightarrow> exact_polynomial" where
  "primitive_instance (Antiderivative p) constant = (0,constant)#polynomial_primitive p"

lemma polynomial_at_real:
  "polynomial_real p (of_rat x) = of_rat (polynomial_at p x)"
  by (induction p) (auto simp: of_rat_add of_rat_mult of_rat_power split: prod.splits)

lemma polynomial_derivative_Cons [simp]:
  "polynomial_derivative ((n,c)#p) = (n-1,c*of_nat n)#polynomial_derivative p"
  by (simp add: polynomial_derivative_def)

lemma polynomial_primitive_derivative:
  "polynomial_real (polynomial_derivative (polynomial_primitive p)) x = polynomial_real p x"
  by (induction p) (auto simp: polynomial_primitive_def polynomial_derivative_def of_rat_mult of_rat_divide of_rat_add field_simps split: prod.splits)

lemma polynomial_derivative_correct:
  "DERIV (polynomial_real p) x :> polynomial_real (polynomial_derivative p) x"
proof (induction p)
  case Nil
  then show ?case by (simp add: polynomial_derivative_def)
next
  case (Cons a p)
  obtain n c where a: "a=(n,c)" by (cases a) auto
  have monomial_derivative: "DERIV (\<lambda>x::real. of_rat c*x^n) x :> (of_rat c * (of_nat n*x^(n-1)))"
    by (auto intro!: derivative_eq_intros)
  have equation: "polynomial_real (a#p) = (\<lambda>x. of_rat c*x^n + polynomial_real p x)"
    by (simp add: a fun_eq_iff)
  show ?case unfolding equation using DERIV_add[OF monomial_derivative Cons.IH]
    by (simp add: a of_rat_mult algebra_simps)
qed

lemma antiderivative_instance_correct:
  "DERIV (polynomial_real (primitive_instance (Antiderivative p) c)) x :> polynomial_real p x"
  using polynomial_derivative_correct[of "primitive_instance (Antiderivative p) c" x]
  by (simp add: polynomial_primitive_derivative)

text \<open>The executable rational instances belong to a logical family with
an arbitrary real integration constant, rather than restricting the mathematical
answer to rational constants. This is a logical carrier, not a real-value codec.\<close>
fun antiderivative_member :: "antiderivative_family \<Rightarrow> (real \<Rightarrow> real) \<Rightarrow> bool" where
  "antiderivative_member (Antiderivative p) f =
    (\<exists>constant::real. \<forall>x. f x = polynomial_real (polynomial_primitive p) x + constant)"

lemma primitive_real_correct:
  "DERIV (polynomial_real (polynomial_primitive p)) x :> polynomial_real p x"
  using polynomial_derivative_correct[of "polynomial_primitive p" x]
  by (simp add: polynomial_primitive_derivative)

theorem antiderivative_family_complete:
  "antiderivative_member (Antiderivative p) f \<longleftrightarrow>
    (\<forall>x. DERIV f x :> polynomial_real p x)"
proof
  assume "antiderivative_member (Antiderivative p) f"
  then obtain c where representation: "f = (\<lambda>x. polynomial_real (polynomial_primitive p) x+c)"
    by (auto simp: fun_eq_iff)
  show "\<forall>x. DERIV f x :> polynomial_real p x"
    unfolding representation using primitive_real_correct
    by (auto intro!: derivative_eq_intros)
next
  assume derivatives: "\<forall>x. DERIV f x :> polynomial_real p x"
  have difference: "\<forall>x. DERIV (\<lambda>x. f x - polynomial_real (polynomial_primitive p) x) x :> 0"
  proof
    fix x
    have first: "DERIV f x :> polynomial_real p x" using derivatives by blast
    show "DERIV (\<lambda>x. f x - polynomial_real (polynomial_primitive p) x) x :> 0"
      using DERIV_diff[OF first primitive_real_correct[of p x]] by simp
  qed
  have integration_constant: "\<And>x. f x - polynomial_real (polynomial_primitive p) x =
    f 0 - polynomial_real (polynomial_primitive p) 0"
    using DERIV_isconst_all[OF difference] by blast
  show "antiderivative_member (Antiderivative p) f"
  proof (simp only: antiderivative_member.simps, rule exI[of _ "f 0 - polynomial_real (polynomial_primitive p) 0"], rule allI)
    fix x
    show "f x = polynomial_real (polynomial_primitive p) x +
      (f 0 - polynomial_real (polynomial_primitive p) 0)"
      using integration_constant[of x] by linarith
  qed
qed

fun repeated_derivative :: "nat \<Rightarrow> exact_polynomial \<Rightarrow> exact_polynomial" where
  "repeated_derivative 0 p = p"
| "repeated_derivative (Suc n) p = polynomial_derivative (repeated_derivative n p)"

inductive derivative_chain :: "nat \<Rightarrow> (real \<Rightarrow> real) \<Rightarrow> (real \<Rightarrow> real) \<Rightarrow> bool" where
  identity: "derivative_chain 0 f f"
| step: "derivative_chain n f g \<Longrightarrow> (\<And>x. DERIV g x :> h x) \<Longrightarrow> derivative_chain (Suc n) f h"

lemma repeated_derivative_correct:
  "derivative_chain n (polynomial_real p) (polynomial_real (repeated_derivative n p))"
  by (induction n) (auto intro: derivative_chain.intros polynomial_derivative_correct)

text \<open>Exact endpoint difference is computed separately. Its identification
with an analytic definite integral still requires the corresponding integral theorem.\<close>
definition primitive_endpoint_difference where
  "primitive_endpoint_difference p a b = polynomial_at (polynomial_primitive p) b - polynomial_at (polynomial_primitive p) a"

export_code polynomial_at polynomial_derivative repeated_derivative polynomial_primitive primitive_instance
  primitive_endpoint_difference in SML module_name Mathematics_Polynomial

end
