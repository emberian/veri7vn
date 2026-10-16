theory Policy_Plans
  imports Versioned_Policies
begin

datatype policy_carrier = PolicyInputCarrier | PolicyReportCarrier
datatype policy_plan_value = PolicyArguments policy_input | PolicyResult policy_reply
fun policy_value_type where
  "policy_value_type (PolicyArguments _) = PolicyInputCarrier" |
  "policy_value_type (PolicyResult _) = PolicyReportCarrier"
datatype policy_operation = EvaluatePolicy policy_recipe "string option" "nat list"
fun policy_arguments where "policy_arguments (EvaluatePolicy _ _ _)=[PolicyInputCarrier]"
fun policy_result_type where "policy_result_type _=PolicyReportCarrier"
fun policy_guard :: "unit \<Rightarrow> policy_operation \<Rightarrow> policy_plan_value list \<Rightarrow> guard_verdict" where
  "policy_guard _ _ _=GuardEstablished"
fun policy_primitive :: "unit \<Rightarrow> policy_operation \<Rightarrow> policy_plan_value list \<Rightarrow> (policy_plan_value,unit) primitive_result" where
  "policy_primitive _ (EvaluatePolicy recipe version premises) [PolicyArguments input] =
    Computed (PolicyResult (registered_policy_dispatch (PolicyCall recipe version input premises)))" |
  "policy_primitive _ _ _ = PrimitiveFailure 701"
global_interpretation policy_plans: typed_plan_bundle policy_value_type policy_arguments policy_result_type policy_guard policy_primitive 702
  defines policy_elaborate=policy_plans.elaborate_plan
    and policy_execute_node=policy_plans.execute_node
    and policy_execute_plan=policy_plans.execute_plan
    and policy_run_checked=policy_plans.run_checked .

lemma policy_primitive_uses_registered_meaning:
  "policy_primitive () (EvaluatePolicy recipe version premises) [PolicyArguments input] = Computed (PolicyResult reply)
   \<Longrightarrow> policy_call_meaning (PolicyCall recipe version input premises) reply"
  using policy_execution_refinement[of "PolicyCall recipe version input premises"] by simp

end
