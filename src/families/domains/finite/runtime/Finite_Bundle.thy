theory Finite_Bundle
  imports "Veri7vn_Finite.Finite_Plans" "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Projection.Veri7vn_Bounded_Projection"
    "Veri7vn_Rational_Input.Veri7vn_Rational_Input"
begin

definition finite_modeled_cost :: "nat \<Rightarrow> nat" where
  "finite_modeled_cost input_nodes = (1+input_nodes)*(1+input_nodes)"
lemma finite_modeled_cost_positive: "0 < finite_modeled_cost input_nodes"
  by (simp add: finite_modeled_cost_def)
definition finite_reply_term :: "finite_reply \<Rightarrow> Code_Evaluation.term" where
  "finite_reply_term = Code_Evaluation.term_of"

text \<open>The fixed native execution adapter imports shared bounded rational
normalization. Its registration is owned by the existing native service.\<close>
ML_file "finite_bundle.ML"
end
