theory Versioned_Policies
  imports "Veri7vn_Codegen.Veri7vn_Codegen" "Veri7vn_Plans.Veri7vn_Plans"
begin

text \<open>These are computations under a named policy transcription. Neither a
source citation nor a reported premise is an assertion about the world. Exact
nonnegative fractions avoid floating epsilon repairs at normative boundaries.\<close>
datatype policy_fraction = PolicyFraction nat nat
fun fraction_valid where "fraction_valid (PolicyFraction n d) = (d > 0)"
fun scaled_floor where "scaled_floor scale (PolicyFraction n d) = n * scale div d"
fun at_most where "at_most (PolicyFraction n d) bound = (n \<le> bound * d)"
fun fraction_le where
  "fraction_le (PolicyFraction a b) (PolicyFraction c d) = (a*d \<le> c*b)"

datatype aqi_pollutant = PM25 | PM10 | Ozone | CarbonMonoxide | SulfurDioxide | NitrogenDioxide
datatype aqi_period = Hours24 | Hours8 | Hour1
datatype area_basis = NetArea | GrossArea
datatype occupancy_use = Business | Mercantile | Residential | Classroom |
  AssemblyStanding | AssemblyChairs | AssemblyTables | Exercise | LibraryReading |
  LibraryStacks | CommercialKitchen | Warehouse
record aqi_breakpoint =
  concentration_low :: nat
  concentration_high :: nat
  index_low :: nat
  index_high :: nat

definition bp where "bp lo hi ilo ihi = \<lparr>concentration_low=lo, concentration_high=hi,
  index_low=ilo,index_high=ihi\<rparr>"
fun aqi_rows where
  "aqi_rows PM25 = [bp 0 90 0 50,bp 91 354 51 100,bp 355 554 101 150,
    bp 555 1254 151 200,bp 1255 2254 201 300,bp 2255 3254 301 500]" |
  "aqi_rows PM10 = [bp 0 54 0 50,bp 55 154 51 100,bp 155 254 101 150,
    bp 255 354 151 200,bp 355 424 201 300,bp 425 604 301 500]" |
  "aqi_rows Ozone = [bp 0 54 0 50,bp 55 70 51 100,bp 71 85 101 150,
    bp 86 105 151 200,bp 106 200 201 300]" |
  "aqi_rows CarbonMonoxide = [bp 0 44 0 50,bp 45 94 51 100,bp 95 124 101 150,
    bp 125 154 151 200,bp 155 304 201 300,bp 305 504 301 500]" |
  "aqi_rows SulfurDioxide = [bp 0 35 0 50,bp 36 75 51 100,bp 76 185 101 150,bp 186 304 151 200]" |
  "aqi_rows NitrogenDioxide = [bp 0 53 0 50,bp 54 100 51 100,bp 101 360 101 150,
    bp 361 649 151 200,bp 650 1249 201 300,bp 1250 2049 301 500]"
fun aqi_scale where "aqi_scale PM25=10" | "aqi_scale CarbonMonoxide=10" |
  "aqi_scale Ozone=1000" | "aqi_scale _=1"
fun aqi_averaging where "aqi_averaging PM25=Hours24" | "aqi_averaging PM10=Hours24" |
  "aqi_averaging Ozone=Hours8" | "aqi_averaging CarbonMonoxide=Hours8" |
  "aqi_averaging _=Hour1"
fun occupancy_factor where
  "occupancy_factor Business=(150,GrossArea)" | "occupancy_factor Mercantile=(60,GrossArea)" |
  "occupancy_factor Residential=(200,GrossArea)" | "occupancy_factor Classroom=(20,NetArea)" |
  "occupancy_factor AssemblyStanding=(5,NetArea)" | "occupancy_factor AssemblyChairs=(7,NetArea)" |
  "occupancy_factor AssemblyTables=(15,NetArea)" | "occupancy_factor Exercise=(50,GrossArea)" |
  "occupancy_factor LibraryReading=(50,NetArea)" | "occupancy_factor LibraryStacks=(100,GrossArea)" |
  "occupancy_factor CommercialKitchen=(200,GrossArea)" | "occupancy_factor Warehouse=(500,GrossArea)"

datatype policy_rule = AQIRule aqi_pollutant | OccupancyRule occupancy_use | CoolingRule
record policy_recipe =
  rule_version :: string
  rule_source :: string
  recipe_rule :: policy_rule
  recipe_conditions :: "nat list"

definition epa_2024_recipe where
  "epa_2024_recipe pollutant premises = \<lparr>rule_version=''EPA-AQS-2024-PM-revision'',
    rule_source=''upstream/root/specialists/airquality/organ_airquality_v1.py:BP'',
    recipe_rule=AQIRule pollutant,recipe_conditions=premises\<rparr>"
definition ibc_2021_recipe where
  "ibc_2021_recipe use premises = \<lparr>rule_version=''IBC-2021-Table-1004.5'',
    rule_source=''upstream/root/specialists/architecture/organ_architecture_v1.py:LOAD'',
    recipe_rule=OccupancyRule use,recipe_conditions=premises\<rparr>"
definition fda_2022_recipe where
  "fda_2022_recipe premises = \<lparr>rule_version=''FDA-Food-Code-2022-3-501.14(A)'',
    rule_source=''upstream/root/specialists/coldchain/organ_coldchain_v1.py:cooling'',
    recipe_rule=CoolingRule,recipe_conditions=premises\<rparr>"

fun canonical_recipe where
  "canonical_recipe (AQIRule pollutant) premises = epa_2024_recipe pollutant premises" |
  "canonical_recipe (OccupancyRule use) premises = ibc_2021_recipe use premises" |
  "canonical_recipe CoolingRule premises = fda_2022_recipe premises"
definition supported_recipe where
  "supported_recipe recipe \<longleftrightarrow>
    recipe=canonical_recipe (recipe_rule recipe) (recipe_conditions recipe)"

text \<open>All AQI concentrations use the unit printed by the source: PM in
micrograms per cubic metre, ozone/CO in ppm, SO2/NO2 in ppb. Occupancy areas
are square feet of the declared basis. Cooling times are elapsed hours from
135 F to 70 F and from 135 F to 41 F respectively. Those endpoint/measurement
claims, applicability and local adoption are retained premises, never inferred.\<close>
datatype policy_input = AQIInput aqi_period policy_fraction |
  OccupancyInput area_basis policy_fraction |
  CoolingInput "policy_fraction option" "policy_fraction option"
datatype policy_value = AQIValue nat nat | Occupants nat | CoolingAssessment

datatype policy_condition = InitialStage | TotalCooling | Chronology
datatype condition_verdict = ConditionMet | ConditionFailed | ConditionMissing
datatype policy_status = PolicyComputed | PolicyConditionsMet | PolicyConditionsFailed | PolicyConditionsMissing
datatype policy_failure = MissingRuleVersion | WrongRuleVersion | MissingRuleSource |
  UnsupportedRecipe | WrongPolicyInput | InvalidFraction | WrongAveragingPeriod | WrongAreaBasis | BeyondTable
datatype policy_reply = PolicyReport policy_recipe policy_value policy_status
  "(policy_condition \<times> condition_verdict) list" "nat list" | PolicyRefused policy_failure
datatype policy_call = PolicyCall policy_recipe "string option" policy_input "nat list"

fun in_breakpoint where
  "in_breakpoint c row = (concentration_low row \<le> c \<and> c \<le> concentration_high row)"
definition interpolate_half_up where
  "interpolate_half_up c row =
    (let width=concentration_high row-concentration_low row;
      numerator=(index_high row-index_low row)*(c-concentration_low row)+index_low row*width
    in (2*numerator+width) div (2*width))"
fun exact_ceiling where
  "exact_ceiling (PolicyFraction n d) factor = (n + d*factor - 1) div (d*factor)"
lemma exact_ceiling_least_upper_bound:
  assumes "d>0" "factor>0"
  shows "exact_ceiling (PolicyFraction n d) factor \<le> k \<longleftrightarrow> n \<le> k*(d*factor)"
proof -
  have positive: "d*factor>0" using assms by simp
  have "(n+d*factor-1) div (d*factor) \<le> k \<longleftrightarrow> n+d*factor-1 < Suc k*(d*factor)"
    using div_less_iff_less_mult[OF positive, of "n+d*factor-1" "Suc k"]
    by (simp only: less_Suc_eq_le)
  also have "... \<longleftrightarrow> n \<le> k*(d*factor)"
    using positive by (simp only: Suc_mult; omega)
  finally show ?thesis by simp
qed

fun time_verdict where
  "time_verdict None limit = ConditionMissing" |
  "time_verdict (Some x) limit = (if at_most x limit then ConditionMet else ConditionFailed)"
fun chronology_verdict where
  "chronology_verdict (Some a) (Some b) = (if fraction_le a b then ConditionMet else ConditionFailed)" |
  "chronology_verdict _ _ = ConditionMissing"
definition cooling_checks where
  "cooling_checks first elapsed_total = [(InitialStage,time_verdict first 2),
    (TotalCooling,time_verdict elapsed_total 6),(Chronology,chronology_verdict first elapsed_total)]"
definition checks_status where
  "checks_status checks = (if ConditionFailed \<in> set (map snd checks) then PolicyConditionsFailed
    else if ConditionMissing \<in> set (map snd checks) then PolicyConditionsMissing else PolicyConditionsMet)"

datatype policy_evaluation = PolicyEvaluation policy_value policy_status
  "(policy_condition \<times> condition_verdict) list" | PolicyEvaluationRefused policy_failure

fun evaluate_rule where
  "evaluate_rule (AQIRule pollutant) (AQIInput period concentration) =
    (if \<not> fraction_valid concentration then PolicyEvaluationRefused InvalidFraction
     else if period \<noteq> aqi_averaging pollutant then PolicyEvaluationRefused WrongAveragingPeriod
     else let c=scaled_floor (aqi_scale pollutant) concentration in
       case List.find (in_breakpoint c) (aqi_rows pollutant) of None \<Rightarrow> PolicyEvaluationRefused BeyondTable
       | Some row \<Rightarrow> PolicyEvaluation (AQIValue (interpolate_half_up c row) c) PolicyComputed [])" |
  "evaluate_rule (OccupancyRule use) (OccupancyInput basis area) =
    (if \<not> fraction_valid area then PolicyEvaluationRefused InvalidFraction
     else if basis \<noteq> snd (occupancy_factor use) then PolicyEvaluationRefused WrongAreaBasis
     else PolicyEvaluation (Occupants (exact_ceiling area (fst (occupancy_factor use)))) PolicyComputed [])" |
  "evaluate_rule CoolingRule (CoolingInput first elapsed_total) =
    (if \<not> list_all fraction_valid (map_filter id [first,elapsed_total]) then PolicyEvaluationRefused InvalidFraction
     else PolicyEvaluation CoolingAssessment (checks_status (cooling_checks first elapsed_total)) (cooling_checks first elapsed_total))" |
  "evaluate_rule _ _ = PolicyEvaluationRefused WrongPolicyInput"

fun stamp_report where
  "stamp_report recipe premises (PolicyEvaluation value status checks) =
    PolicyReport recipe value status checks (merge_conditions (recipe_conditions recipe @ premises))" |
  "stamp_report recipe premises (PolicyEvaluationRefused reason) = PolicyRefused reason"
fun registered_policy_dispatch where
  "registered_policy_dispatch (PolicyCall recipe requested input premises) =
    (case requested of None \<Rightarrow> PolicyRefused MissingRuleVersion | Some version \<Rightarrow>
      if version \<noteq> rule_version recipe \<or> version=[] then PolicyRefused WrongRuleVersion
      else if rule_source recipe=[] then PolicyRefused MissingRuleSource
      else if \<not> supported_recipe recipe then PolicyRefused UnsupportedRecipe
      else stamp_report recipe premises (evaluate_rule (recipe_rule recipe) input))"

definition policy_call_meaning where
  "policy_call_meaning call reply \<longleftrightarrow> (case call of PolicyCall recipe requested input premises \<Rightarrow>
    (case requested of None \<Rightarrow> reply=PolicyRefused MissingRuleVersion | Some version \<Rightarrow>
      if version \<noteq> rule_version recipe \<or> version=[] then reply=PolicyRefused WrongRuleVersion
      else if rule_source recipe=[] then reply=PolicyRefused MissingRuleSource
      else if \<not> supported_recipe recipe then reply=PolicyRefused UnsupportedRecipe
      else reply=stamp_report recipe premises (evaluate_rule (recipe_rule recipe) input)))"
lemma policy_execution_refinement:
  "policy_call_meaning call (registered_policy_dispatch call)"
  by (cases call) (simp add: policy_call_meaning_def split: option.splits)
lemma absent_version_never_defaults:
  "registered_policy_dispatch (PolicyCall recipe None input premises)=PolicyRefused MissingRuleVersion"
  by simp
lemma stamped_report_retains_recipe:
  "stamp_report recipe premises evaluation=PolicyReport actual value status checks conditions
    \<Longrightarrow> actual=recipe \<and> set conditions=set (recipe_conditions recipe @ premises)"
  by (cases evaluation) auto
lemma policy_report_retains_recipe:
  "registered_policy_dispatch (PolicyCall recipe version input premises)=PolicyReport actual value status checks conditions
    \<Longrightarrow> actual=recipe \<and> set conditions=set (recipe_conditions recipe @ premises)"
  by (auto dest: stamped_report_retains_recipe split: option.splits if_splits)
lemma missing_initial_stage_not_complete:
  "checks_status (cooling_checks None elapsed_total) \<noteq> PolicyConditionsMet"
  by (simp add: checks_status_def cooling_checks_def split: if_splits)
lemma failed_initial_stage_not_complete:
  "\<not> at_most first 2 \<Longrightarrow>
    checks_status (cooling_checks (Some first) elapsed_total)=PolicyConditionsFailed"
  by (simp add: checks_status_def cooling_checks_def)
lemma cooling_complete_requires_both_stages:
  "checks_status (cooling_checks first elapsed_total)=PolicyConditionsMet \<Longrightarrow>
    \<exists>a b. first=Some a \<and> elapsed_total=Some b \<and> at_most a 2 \<and> at_most b 6 \<and> fraction_le a b"
  by (cases first; cases elapsed_total)
    (auto simp: checks_status_def cooling_checks_def split: if_splits)

end
