theory Domain_Model_Context
  imports "Veri7vn_Domain_Bundle.Domain_Bundle"
begin

text \<open>A model premise names actual native response functions. Adopting this
predicate is an explicit hypothesis about those functions, never a claim that
an arbitrary material has the ideal response. The service must retain the exact
proposition, its condition identity and its owner together.\<close>
definition ideal_spring_model ::
  "(rat \<Rightarrow> rat \<Rightarrow> rat) \<Rightarrow> (rat \<Rightarrow> rat \<Rightarrow> rat) \<Rightarrow> bool" where
  "ideal_spring_model force energy \<longleftrightarrow>
    (\<forall>k x. 0 < k \<longrightarrow> 0 \<le> x \<longrightarrow>
      force k x = k*x \<and> energy k x = k*x*x/2)"

fun spring_model_meaning where
  "spring_model_meaning force energy SpringForce k x f =
    (0 < k \<and> 0 \<le> x \<and> force k x = f)"
| "spring_model_meaning force energy SpringExtension k f x =
    (0 < k \<and> 0 \<le> x \<and> force k x = f)"
| "spring_model_meaning force energy SpringStiffness f x k =
    (0 < k \<and> 0 < x \<and> force k x = f)"
| "spring_model_meaning force energy SpringEnergy k x e =
    (0 < k \<and> 0 \<le> x \<and> energy k x = e)"

lemma adopted_spring_model_consequence:
  assumes "ideal_spring_model force energy" "spring_meaning op a b c"
  shows "spring_model_meaning force energy op a b c"
proof (cases op)
  case SpringForce
  then show ?thesis using assms
    by (auto simp: ideal_spring_model_def)
next
  case SpringExtension
  have guards: "0 < a" "0 \<le> b" "a*c=b"
    using assms(2) SpringExtension by simp_all
  have nonnegative: "0 \<le> c" using guards by (nlinarith)
  show ?thesis using assms(1) guards nonnegative SpringExtension
    by (auto simp: ideal_spring_model_def)
next
  case SpringStiffness
  have guards: "0 < a" "0 < b" "c*b=a"
    using assms(2) SpringStiffness by simp_all
  have positive: "0 < c" using guards by nlinarith
  show ?thesis using assms(1) guards positive SpringStiffness
    by (auto simp: ideal_spring_model_def)
next
  case SpringEnergy
  have guards: "0 < a" "0 \<le> b" "2*c=a*b*b"
    using assms(2) SpringEnergy by simp_all
  have value: "a*b*b/2=c" using guards(3) by linarith
  show ?thesis using assms(1) guards value SpringEnergy
    by (auto simp: ideal_spring_model_def)
qed

lemma adopted_spring_execution_consequence:
  assumes "ideal_spring_model force energy" "spring_kernel op a b = Some c"
  shows "spring_model_meaning force energy op a b c"
  using assms adopted_spring_model_consequence spring_kernel_refinement by blast

fun domain_model_value_meaning where
  "domain_model_value_meaning force energy (Spring op)
    [LinearValue u a,LinearValue v b] (LinearValue w c) =
      spring_model_meaning force energy op a b c"
| "domain_model_value_meaning force energy _ _ _ = True"

lemma domain_model_value_consequence:
  assumes "ideal_spring_model force energy" "domain_meaning op xs value"
  shows "domain_model_value_meaning force energy op xs value"
  using assms
  by (induction op xs value rule: domain_meaning.induct)
    (auto dest: adopted_spring_model_consequence)

definition domain_model_call_meaning where
  "domain_model_call_meaning force energy call reply \<longleftrightarrow>
    domain_call_meaning call reply \<and>
    (case reply of DomainAnswer value conditions \<Rightarrow>
       domain_model_value_meaning force energy (call_operation call) (call_values call) value
     | _ \<Rightarrow> True)"

lemma domain_model_execution_refinement:
  assumes "ideal_spring_model force energy"
  shows "domain_model_call_meaning force energy call (registered_domain_dispatch call)"
  using domain_execution_refinement[of call] assms
  by (cases "registered_domain_dispatch call")
    (auto simp: domain_model_call_meaning_def domain_call_meaning_def
      dest: domain_model_value_consequence)

lemma domain_model_execution_contract:
  "\<forall>force energy call. ideal_spring_model force energy \<longrightarrow>
    domain_model_call_meaning force energy call (registered_domain_dispatch call)"
  using domain_model_execution_refinement by blast

end
