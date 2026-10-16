theory Policy_Bundle
  imports "Veri7vn_Policies.Policy_Plans" "Veri7vn_Domain_Bundle.Domain_Bundle"
begin

definition policy_modeled_cost :: "nat \<Rightarrow> nat" where
  "policy_modeled_cost nodes=(1+nodes)*(1+nodes)"
definition policy_reply_term :: "policy_reply \<Rightarrow> Code_Evaluation.term" where
  "policy_reply_term=Code_Evaluation.term_of"
ML_file "policy_bundle.ML"
end
