theory Energy_Family
  imports Calorimetry Home Hvac Renewables Iot
begin

text \<open>The family's one request type: a typed request for any of the six
specialists. thermo takes Thermo requests (the kinds carnot, gas_*, radiated_power,
latent_*, sensible_heat), energy-v2 and energy-v3 take home_req, hvac hvac_req,
renewables ren_req, iot iot_req. The dispatcher is a total function; each branch
is the verified reply of its kernel.\<close>
datatype family_request =
    FThermo request
  | FHome home_req
  | FHvac hvac_req
  | FRen ren_req
  | FIot iot_req
  | FCalorLimit calor_limit

fun reply_of :: "family_request \<Rightarrow> reply" where
  "reply_of (FThermo r) = reply_t r"
| "reply_of (FHome r) = reply_h r"
| "reply_of (FHvac r) = reply_v r"
| "reply_of (FRen r) = reply_r r"
| "reply_of (FIot r) = reply_i r"
| "reply_of (FCalorLimit r) = calor_limit_reply r"

fun kernel_of :: "family_request \<Rightarrow> outcome" where
  "kernel_of (FThermo r) = kernel_t r"
| "kernel_of (FHome r) = kernel_h r"
| "kernel_of (FHvac r) = kernel_v r"
| "kernel_of (FRen r) = kernel_r r"
| "kernel_of (FIot r) = kernel_i r"
| "kernel_of (FCalorLimit r) = calor_limit_kernel r"

text \<open>A reply is withheld exactly when its kernel declines (or the digits
cannot be pinned), whichever specialist it came from.\<close>
theorem family_declines_withheld:
  assumes "kernel_of r = Decline d w"
  shows "\<not> answered (reply_of r) \<and> response (reply_of r) = decline_text d w"
  using assms reply_t_withheld reply_h_withheld reply_v_withheld reply_r_withheld reply_i_withheld calor_limit_withheld
  by (cases r) auto

section \<open>Laws across kinds\<close>

text \<open>These relate two different kinds of the same sub-family, so each
reads the kernel twice and neither is a restatement of one formula.\<close>

lemma neg_swap: "neg_temp [a, b] = None \<longleftrightarrow> neg_temp [b, a] = None"
  by (auto simp: neg_temp_none)

lemma pre_t_none: "pre_t (Thermo ts q) = None \<longleftrightarrow> neg_temp ts = None \<and> physical_t q"
  by (cases "neg_temp ts") (auto split: temp.splits if_splits)

text \<open>Heating from the first temperature to the second and the reverse
are opposite: swapping the two temperatures of a sensible-heat question
negates the heat and changes nothing else.\<close>
theorem sensible_heat_swap:
  assumes h: "kernel_t (Thermo [t0, t1] (TSens m cs DT_temps)) = Exact k q"
  shows "kernel_t (Thermo [t1, t0] (TSens m cs DT_temps)) = Exact k (- q)"
proof -
  note p = exact_parts[OF h]
  have pre: "pre_t (Thermo [t1, t0] (TSens m cs DT_temps)) = None"
    using p(1) pre_t_none[of "[t0, t1]"] pre_t_none[of "[t1, t0]"] neg_swap by blast
  have miss: "miss_t (Thermo [t1, t0] (TSens m cs DT_temps)) = None"
    using p(2) by (cases m; cases cs; simp_all add: list.case_eq_if)
  have post: "post_t (Thermo [t1, t0] (TSens m cs DT_temps)) = None" by simp
  have kk: "k = kd_t (Thermo [t1, t0] (TSens m cs DT_temps))" using p(4) by simp
  have qq: "- q = vl_t (Thermo [t1, t0] (TSens m cs DT_temps))"
  proof (cases m)
    case None
    then show ?thesis using p(2) by simp
  next
    case (Some xu)
    then obtain x u where "m = Some (x, u)" by (cases xu) auto
    then show ?thesis using p(5) by (simp add: field_simps)
  qed
  show ?thesis unfolding kernel_t_def mk_exact using pre miss post kk qq by simp
qed

text \<open>Tons and BTU/h are inverse conversions: the tons answered for a
BTU/h load, fed back as a tons question, gives the load again.\<close>
theorem tons_btuh_roundtrip:
  assumes "kernel_v (VTons b) = Exact k q"
  shows "kernel_v (VBtuh q) = Exact (STR ''btuh'') b"
proof -
  have equation: "q * 12000 = b" using tons_law[OF assms] by blast
  have load: "0 \<le> b" using exact_parts_v(1)[OF assms] by (auto split: if_splits)
  have tons: "0 \<le> q" using equation load by linarith
  show ?thesis using equation tons by (simp add: kernel_v_def mk_exact btu_per_ton_def)
qed

theorem btuh_tons_roundtrip:
  assumes "kernel_v (VBtuh t) = Exact k q"
  shows "kernel_v (VTons q) = Exact (STR ''tons'') t"
proof -
  have equation: "q = t * 12000" using btuh_law[OF assms] by blast
  have tons: "0 \<le> t" using exact_parts_v(1)[OF assms] by (auto split: if_splits)
  show ?thesis using equation tons by (simp add: kernel_v_def mk_exact btu_per_ton_def)
qed

text \<open>What a device costs is the energy it uses times the tariff: the
cost question and the energy question for the same watts and hours.\<close>
theorem cost_is_energy_times_tariff:
  assumes c: "kernel_h (HEnergy (Some w) (Some h) (Some rate) True) = Exact k c"
    and e: "kernel_h (HEnergy (Some w) (Some h) r False) = Exact k' e"
  shows "c = e * rate"
proof -
  have c1: "c = w * htot h / 1000 * rate" using cost_law[OF c] by blast
  have e1: "e * 1000 = w * htot h" using energy_law[OF e] by blast
  have "w * htot h / 1000 = e" using e1 by (simp add: field_simps)
  then show ?thesis using c1 by simp
qed

text \<open>Swapping a device for another saves the difference of what the two
use: the swap question against two energy questions at the same hours.\<close>
theorem swap_is_energy_difference:
  assumes s: "kernel_h (HSwap a b (Some h) r) = Exact k sv"
    and ea: "kernel_h (HEnergy (Some a) (Some h) ra False) = Exact k1 ua"
    and eb: "kernel_h (HEnergy (Some b) (Some h) rb False) = Exact k2 ub"
  shows "sv = ua - ub"
proof -
  have s1: "sv * 1000 = (a - b) * htot h" using swap_law[OF s] by blast
  have a1: "ua * 1000 = a * htot h" using energy_law[OF ea] by blast
  have b1: "ub * 1000 = b * htot h" using energy_law[OF eb] by blast
  have d: "(a - b) * htot h = a * htot h - b * htot h" by (simp add: algebra_simps)
  show ?thesis using s1 a1 b1 d by linarith
qed

end
