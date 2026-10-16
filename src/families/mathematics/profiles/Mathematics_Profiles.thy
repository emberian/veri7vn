theory Mathematics_Profiles
  imports "Veri7vn_Mathematics.Mathematics_Representation" "Veri7vn_Mathematics.Mathematics_Display" "Veri7vn_Mathematics.Mathematics_Polynomial"
    "Veri7vn_Registry.Veri7vn_Registry"
begin

definition rational_representation :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "rational_representation encoded meaning \<longleftrightarrow> encoded=meaning"

definition symbolic_representation :: "math_expr \<Rightarrow> ((nat \<Rightarrow> rat option) \<Rightarrow> rat option) \<Rightarrow> bool" where
  "symbolic_representation expression meaning \<longleftrightarrow>
   (\<forall>env q. meaning env = Some q \<longleftrightarrow> math_value env expression q)"

lemma rational_representation_identity:
  "rational_representation q q"
  by (simp add: rational_representation_def)

lemma symbolic_evaluator_representation:
  "symbolic_representation expression (\<lambda>env. math_eval env expression)"
  by (simp add: symbolic_representation_def math_eval_refinement)

ML_file "mathematics_profiles.ML"
end
