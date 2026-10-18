theory Calorimetry
  imports Thermo
begin

text \<open>Specific heat has energy / (mass * temperature interval) dimensions.
The reader selects units; all scale arithmetic is exported HOL computation.
Absolute temperature offsets do not belong to temperature intervals.\<close>

datatype heatunit = HU_J | HU_kJ | HU_MJ
fun heatfactor :: "heatunit \<Rightarrow> rat" where
  "heatfactor HU_J = 1" | "heatfactor HU_kJ = 1000" | "heatfactor HU_MJ = 1000000"

fun intervalfactor :: "tunit \<Rightarrow> rat" where
  "intervalfactor TU_C = 1" | "intervalfactor TU_K = 1" | "intervalfactor TU_F = 5/9"
definition temperature_interval :: "tunit \<Rightarrow> rat \<Rightarrow> rat" where
  "temperature_interval u d = d * intervalfactor u"

datatype heatcapunit = HeatCapacity heatunit munit tunit
fun heatcapfactor :: "heatcapunit \<Rightarrow> rat" where
  "heatcapfactor (HeatCapacity e m t) = heatfactor e / (mfac m * intervalfactor t)"
definition given_heat_capacity :: "rat \<Rightarrow> heatcapunit \<Rightarrow> csrc" where
  "given_heat_capacity c u = C_given (c * heatcapfactor u)"

lemma interval_is_temperature_difference:
  "temperature_interval u d = kelvin u (a+d) - kelvin u a"
  by (cases u) (simp_all add: temperature_interval_def kelvin_def field_simps algebra_simps)

lemma heatcapfactor_positive: "0 < heatcapfactor u"
proof -
  obtain e m t where u: "u = HeatCapacity e m t" by (cases u) auto
  show ?thesis unfolding u by (cases e; cases m; cases t) simp_all
qed

lemma specific_heat_energy_balance:
  "csv (given_heat_capacity c (HeatCapacity e m t)) * mfac m * intervalfactor t
    = c * heatfactor e"
  by (cases e; cases m; cases t)
     (simp_all add: given_heat_capacity_def field_simps algebra_simps)

theorem sensible_unit_energy_balance:
  assumes "kernel_t (Thermo ts (TSens (Some (mass,mu))
     (given_heat_capacity c (HeatCapacity eu cu tu))
     (DT_by (temperature_interval tu d)))) = Exact k q"
  shows "q * mfac cu = mass * mfac mu * c * heatfactor eu * d"
  using sensible_heat_by[OF assms]
  by (cases eu; cases cu; cases tu)
     (simp_all add: given_heat_capacity_def temperature_interval_def field_simps algebra_simps)

theorem sensible_interval_agrees_with_endpoints:
  "vl_t (Thermo [] (TSens m cs (DT_by (temperature_interval u d)))) =
   vl_t (Thermo [Temp a u, Temp (a+d) u] (TSens m cs DT_temps))"
  using interval_is_temperature_difference[of u d a]
  by (cases m) (auto split: prod.splits)

datatype calor_limit = MissingSpecificHeat | IncompatibleThermalUnits
  | UnsupportedThermalCondition | MissingEmissivity | UnsupportedPhasePath

fun calor_limit_kernel :: "calor_limit \<Rightarrow> outcome" where
  "calor_limit_kernel MissingSpecificHeat = Decline D_under
     (STR ''the supplied specific heat value and complete energy/mass/temperature-interval units'')"
| "calor_limit_kernel MissingEmissivity = Decline D_under (STR ''the supplied emissivity value'')"
| "calor_limit_kernel IncompatibleThermalUnits = Decline D_model
     (STR ''Those supplied units do not match this thermal model. I need complete compatible units.'')"
| "calor_limit_kernel UnsupportedThermalCondition = Decline D_model
     (STR ''This thermal model does not include the supplied conditions, losses or additional inputs.'')"
| "calor_limit_kernel UnsupportedPhasePath = Decline D_model
     (STR ''That process needs sensible heating and phase changes together, with explicit endpoint phases and pressure assumptions.'')"

definition calor_limit_reply :: "calor_limit \<Rightarrow> reply" where
  "calor_limit_reply = mk_reply calor_limit_kernel (\<lambda>_ _. None) (\<lambda>_. True)
     (\<lambda>_ _ _. STR '''') (\<lambda>_ _. None) (\<lambda>_ _. STR '''')"

lemma calor_limit_withheld:
  assumes "calor_limit_kernel r = Decline d w"
  shows "\<not> answered (calor_limit_reply r) \<and>
    response (calor_limit_reply r) = decline_text d w"
  using assms by (simp add: calor_limit_reply_def mk_reply_def)

end
