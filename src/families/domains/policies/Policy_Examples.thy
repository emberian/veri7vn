theory Policy_Examples
  imports Policy_Plans
begin

lemma pm25_truncation_boundary:
  "registered_policy_dispatch (PolicyCall (epa_2024_recipe PM25 [11])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hours24 (PolicyFraction 90999 10000)) [12]) =
    PolicyReport (epa_2024_recipe PM25 [11]) (AQIValue 50 90) PolicyComputed [] [11,12]"
  by code_simp
lemma pm25_no_epsilon_round_up:
  "registered_policy_dispatch (PolicyCall (epa_2024_recipe PM25 [])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hours24 (PolicyFraction 909999999999 100000000000)) []) =
    PolicyReport (epa_2024_recipe PM25 []) (AQIValue 50 90) PolicyComputed [] []"
  by code_simp
lemma pm25_next_breakpoint:
  "registered_policy_dispatch (PolicyCall (epa_2024_recipe PM25 [])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hours24 (PolicyFraction 91 10)) []) =
    PolicyReport (epa_2024_recipe PM25 []) (AQIValue 51 91) PolicyComputed [] []"
  by code_simp
lemma co_halfway_rounds_up:
  "registered_policy_dispatch (PolicyCall (epa_2024_recipe CarbonMonoxide [])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hours8 (PolicyFraction 11 10)) []) =
    PolicyReport (epa_2024_recipe CarbonMonoxide []) (AQIValue 13 11) PolicyComputed [] []"
  by code_simp
lemma ozone_8_hour_high_range_not_extrapolated:
  "registered_policy_dispatch (PolicyCall (epa_2024_recipe Ozone [])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hours8 (PolicyFraction 201 1000)) []) = PolicyRefused BeyondTable"
  by code_simp
lemma occupancy_no_epsilon_round_down:
  "registered_policy_dispatch (PolicyCall (ibc_2021_recipe Business [21])
    (Some ''IBC-2021-Table-1004.5'') (OccupancyInput GrossArea (PolicyFraction 150000000001 1000000000)) []) =
    PolicyReport (ibc_2021_recipe Business [21]) (Occupants 2) PolicyComputed [] [21]"
  by code_simp
lemma occupancy_wrong_basis:
  "registered_policy_dispatch (PolicyCall (ibc_2021_recipe Classroom [])
    (Some ''IBC-2021-Table-1004.5'') (OccupancyInput GrossArea (PolicyFraction 100 1)) []) = PolicyRefused WrongAreaBasis"
  by code_simp
lemma cooling_total_does_not_cover_missing_initial:
  "registered_policy_dispatch (PolicyCall (fda_2022_recipe [31])
    (Some ''FDA-Food-Code-2022-3-501.14(A)'') (CoolingInput None (Some (PolicyFraction 5 1))) []) =
    PolicyReport (fda_2022_recipe [31]) CoolingAssessment PolicyConditionsMissing
      [(InitialStage,ConditionMissing),(TotalCooling,ConditionMet),(Chronology,ConditionMissing)] [31]"
  by code_simp
lemma cooling_total_does_not_cover_failed_initial:
  "registered_policy_dispatch (PolicyCall (fda_2022_recipe [])
    (Some ''FDA-Food-Code-2022-3-501.14(A)'')
    (CoolingInput (Some (PolicyFraction 3 1)) (Some (PolicyFraction 5 1))) []) =
    PolicyReport (fda_2022_recipe []) CoolingAssessment PolicyConditionsFailed
      [(InitialStage,ConditionFailed),(TotalCooling,ConditionMet),(Chronology,ConditionMet)] []"
  by code_simp
lemma cooling_success_retains_scope:
  "registered_policy_dispatch (PolicyCall (fda_2022_recipe [31])
    (Some ''FDA-Food-Code-2022-3-501.14(A)'')
    (CoolingInput (Some (PolicyFraction 2 1)) (Some (PolicyFraction 6 1))) [32]) =
    PolicyReport (fda_2022_recipe [31]) CoolingAssessment PolicyConditionsMet
      [(InitialStage,ConditionMet),(TotalCooling,ConditionMet),(Chronology,ConditionMet)] [31,32]"
  by code_simp
lemma cooling_time_order_refuted:
  "registered_policy_dispatch (PolicyCall (fda_2022_recipe [])
    (Some ''FDA-Food-Code-2022-3-501.14(A)'')
    (CoolingInput (Some (PolicyFraction 2 1)) (Some (PolicyFraction 1 1))) []) =
    PolicyReport (fda_2022_recipe []) CoolingAssessment PolicyConditionsFailed
      [(InitialStage,ConditionMet),(TotalCooling,ConditionMet),(Chronology,ConditionFailed)] []"
  by code_simp
lemma unknown_period_refused:
  "registered_policy_dispatch (PolicyCall (epa_2024_recipe PM25 [])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hour1 (PolicyFraction 9 1)) []) = PolicyRefused WrongAveragingPeriod"
  by code_simp
lemma zero_denominator_refused:
  "registered_policy_dispatch (PolicyCall (ibc_2021_recipe Business [])
    (Some ''IBC-2021-Table-1004.5'') (OccupancyInput GrossArea (PolicyFraction 150 0)) []) = PolicyRefused InvalidFraction"
  by code_simp
lemma wrong_version_refused:
  "registered_policy_dispatch (PolicyCall (fda_2022_recipe []) (Some ''2025'') (CoolingInput None None) []) = PolicyRefused WrongRuleVersion"
  by code_simp

end
