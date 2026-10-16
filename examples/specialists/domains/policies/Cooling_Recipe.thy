theory Cooling_Recipe
  imports "Veri7vn_Policies.Policy_Examples"
begin

text \<open>The native source recipe selects one edition explicitly. Observation
and applicability claims must be supplied through source-owned native conditions
by the consuming workspace. This demonstration supplies no such observations and
therefore establishes a calculation under stated inputs, never food safety.\<close>
definition cooling_recipe where "cooling_recipe=fda_2022_recipe []"
definition missing_initial_stage where
  "missing_initial_stage=PolicyCall cooling_recipe
    (Some ''FDA-Food-Code-2022-3-501.14(A)'')
    (CoolingInput None (Some (PolicyFraction 5 1))) []"
lemma total_only_is_incomplete:
  "registered_policy_dispatch missing_initial_stage =
    PolicyReport cooling_recipe CoolingAssessment PolicyConditionsMissing
      [(InitialStage,ConditionMissing),(TotalCooling,ConditionMet),(Chronology,ConditionMissing)] []"
  by (simp only: cooling_recipe_def missing_initial_stage_def; code_simp)
end
