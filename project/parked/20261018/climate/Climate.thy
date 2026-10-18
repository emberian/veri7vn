theory Climate
  imports Climate_Num
begin

text \<open>
  Lane S05-climate. Six shipped Oracle7 specialists (carboncapture, airquality,
  climate, carbonmat, coldchain, coldchain-v2: upstream/root/specialists/*/organ_*.py)
  as one verified HOL kernel. A typed request (what the question asks, its numbers
  already read off by the untrusted recognizer) goes to a typed outcome: an exact
  rational value, a decimal enclosure (logarithms, roots, pi, arctan), a yes/no
  verdict, an AQI with its pollutant, a word, or a decline. The tables (emission
  factors, AQI breakpoints, lattice constants, Food Code limits) are HOL constants
  transcribed from the organs; tables_check.py fails on any difference.
\<close>

section \<open>Kinds, declines and outcomes\<close>

datatype kind =
    K_c_to_co2 | K_co2_to_c | K_fuel_co2 | K_co2_per_mile | K_captured | K_capture_energy
  | K_aqi | K_overall | K_category
  | K_forcing | K_warming_ecs | K_warming_lambda | K_ppm_to_gtc | K_ppm_to_gtco2
  | K_mass_to_ppm | K_effective_temp | K_co2e
  | K_cnt_diameter | K_cnt_angle | K_cnt_type | K_cnt_kind | K_graphene_layers | K_graphene_mass
  | K_cooling_check | K_cold_hold | K_hot_hold | K_cook_temp | K_reheat | K_tphc | K_tphc_rule
  | K_date_mark | K_date_rule | K_danger_zone

datatype pol = P_pm25 | P_pm10 | P_o3 | P_co | P_so2 | P_no2
datatype cat = Cat_good | Cat_moderate | Cat_usg | Cat_unhealthy | Cat_very_unhealthy | Cat_hazardous
datatype tube = T_armchair | T_zigzag | T_chiral
datatype weekday = Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday

datatype need = N_gwp | N_conc | N_sens | N_solar_albedo | N_cooling_schedule | N_partial_cooling | N_material_geometry

datatype reason = R_rate_over_100 | R_zero_mpg | R_negative_capture_rate | R_negative_carbon_quantity
  | R_pm_hourly | R_beyond pol | R_o3_above_8h | R_so2_above_1h | R_between pol | R_aqi_out_of_scale
  | R_nonpositive_conc | R_albedo_range | R_negative_solar | R_bad_chirality | R_negative_duration | R_negative_geometry

datatype decline = Underspecified need | Impossible reason | Imprecise | Not_taken

datatype outcome =
    Exact kind rat
  | Approx kind "int \<times> int"
  | Verdict kind bool
  | Index kind int pol
  | Category cat
  | Tube_kind tube
  | Weekday weekday
  | Interval kind rat rat
  | Decline decline

text \<open>The generic finish for a request whose value is either an exact rational
or a real enclosed by a float expression.\<close>
definition approx_out :: "nat \<Rightarrow> kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out dd k e = (case enclose_fixed dd e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out dd c e = Approx k d"
  shows "k = c \<and> (snd d = - int dd \<or> snd d = 0) \<and>
         \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
  using assms by (auto simp: approx_out_def split: option.splits dest: enclose_fixed_sound)

lemma approx_out_not_exact [simp]: "approx_out dd c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_verdict [simp]: "approx_out dd c e \<noteq> Verdict k b"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decline: "approx_out dd c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)

definition spec_out :: "nat \<Rightarrow> kind \<Rightarrow> rat option \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "spec_out dd k ex e = (case ex of Some q \<Rightarrow> Exact k q | None \<Rightarrow> approx_out dd k e)"

lemma spec_out_exact:
  "spec_out dd k ex e = Exact k' q \<Longrightarrow> ex = Some q \<and> k' = k"
  by (auto simp: spec_out_def split: option.splits)

lemma spec_out_approx:
  assumes "spec_out dd k ex e = Approx k' d"
  shows "ex = None \<and> k' = k \<and> (snd d = - int dd \<or> snd d = 0) \<and>
         \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
  using assms by (auto simp: spec_out_def split: option.splits dest: approx_out_sound)

lemma spec_out_decline:
  "spec_out dd k ex e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: spec_out_def dest: approx_out_decline split: option.splits)

lemma spec_out_not_verdict [simp]: "spec_out dd k ex e \<noteq> Verdict k' b"
  by (auto simp: spec_out_def split: option.splits)


section \<open>Carbon capture (carboncapture)\<close>

datatype fuel = F_gasoline | F_diesel
datatype eunit = E_kwh | E_mwh | E_gj
datatype mass_unit = Mass_g | Mass_kg | Mass_tonne | Mass_Mt | Mass_Gt
fun mass_tonnes :: "rat \<Rightarrow> mass_unit \<Rightarrow> rat" where
  "mass_tonnes m Mass_g = m / 1000000"
| "mass_tonnes m Mass_kg = m / 1000"
| "mass_tonnes m Mass_tonne = m"
| "mass_tonnes m Mass_Mt = m * 1000000"
| "mass_tonnes m Mass_Gt = m * 1000000000"

lemma mass_tonnes_nonnegative [simp]:
  "0 \<le> mass_tonnes m u \<longleftrightarrow> 0 \<le> m"
  by (cases u) simp_all


text \<open>EPA tailpipe factors in grams of CO2 per US gallon; the molar masses of
carbon and CO2 (44.01 / 12.011).\<close>
fun ef :: "fuel \<Rightarrow> rat" where
  "ef F_gasoline = 8887" | "ef F_diesel = 10180"

definition c_ratio :: rat where "c_ratio = 44010 / 12011"

lemma c_ratio_mul: "c_ratio * (12011 / 1000) = 4401 / 100"
  by (unfold c_ratio_def) (simp add: field_simps)

lemma c_ratio_nz [simp]: "c_ratio \<noteq> 0"
  by (simp add: c_ratio_def)

fun fuel_name :: "fuel \<Rightarrow> String.literal" where
  "fuel_name F_gasoline = STR ''gasoline''" | "fuel_name F_diesel = STR ''diesel''"

text \<open>The String.literal fields only echo what the question said (the unit as
written, the fuel word); they never enter a value.\<close>
datatype ccreq =
    Cc_c_to_co2 rat String.literal
  | Cc_co2_to_c rat String.literal
  | Cc_fuel_co2 fuel String.literal rat
  | Cc_co2_per_mile fuel String.literal rat
  | Cc_captured rat String.literal rat
  | Cc_capture_energy rat mass_unit rat rat eunit

fun cc_kind :: "ccreq \<Rightarrow> kind" where
  "cc_kind (Cc_c_to_co2 _ _) = K_c_to_co2"
| "cc_kind (Cc_co2_to_c _ _) = K_co2_to_c"
| "cc_kind (Cc_fuel_co2 _ _ _) = K_fuel_co2"
| "cc_kind (Cc_co2_per_mile _ _ _) = K_co2_per_mile"
| "cc_kind (Cc_captured _ _ _) = K_captured"
| "cc_kind (Cc_capture_energy _ _ _ _ _) = K_capture_energy"

fun cc_val :: "ccreq \<Rightarrow> rat" where
  "cc_val (Cc_c_to_co2 m _) = m * c_ratio"
| "cc_val (Cc_co2_to_c m _) = m / c_ratio"
| "cc_val (Cc_fuel_co2 f _ gal) = gal * ef f / 1000"
| "cc_val (Cc_co2_per_mile f _ mpg) = ef f / mpg"
| "cc_val (Cc_captured m _ c) = m * c / 100"
| "cc_val (Cc_capture_energy m u c e _) = mass_tonnes m u * c / 100 * e"

fun cc_impossible :: "ccreq \<Rightarrow> reason option" where
  "cc_impossible (Cc_co2_per_mile _ _ mpg) = (if mpg \<le> 0 then Some R_zero_mpg else None)"
| "cc_impossible (Cc_captured m _ c) =
    (if 100 < c then Some R_rate_over_100 else if c < 0 then Some R_negative_capture_rate
     else if m < 0 then Some R_negative_carbon_quantity else None)"
| "cc_impossible (Cc_capture_energy m _ c e _) =
    (if 100 < c then Some R_rate_over_100 else if c < 0 then Some R_negative_capture_rate
     else if m < 0 \<or> e < 0 then Some R_negative_carbon_quantity else None)"
| "cc_impossible (Cc_c_to_co2 m _) = (if m < 0 then Some R_negative_carbon_quantity else None)"
| "cc_impossible (Cc_co2_to_c m _) = (if m < 0 then Some R_negative_carbon_quantity else None)"
| "cc_impossible (Cc_fuel_co2 _ _ v) = (if v < 0 then Some R_negative_carbon_quantity else None)"

fun cc_feasible :: "ccreq \<Rightarrow> bool" where
  "cc_feasible (Cc_co2_per_mile _ _ mpg) = (0 < mpg)"
| "cc_feasible (Cc_captured m _ c) = (0 \<le> m \<and> 0 \<le> c \<and> c \<le> 100)"
| "cc_feasible (Cc_capture_energy m _ c e _) = (0 \<le> m \<and> 0 \<le> c \<and> c \<le> 100 \<and> 0 \<le> e)"
| "cc_feasible (Cc_c_to_co2 m _) = (0 \<le> m)"
| "cc_feasible (Cc_co2_to_c m _) = (0 \<le> m)"
| "cc_feasible (Cc_fuel_co2 _ _ v) = (0 \<le> v)"

definition cc_kernel :: "ccreq \<Rightarrow> outcome" where
  "cc_kernel r = (case cc_impossible r of Some w \<Rightarrow> Decline (Impossible w)
                  | None \<Rightarrow> Exact (cc_kind r) (cc_val r))"

theorem cc_kernel_sound:
  assumes "cc_kernel r = Exact k q"
  shows "cc_impossible r = None \<and> k = cc_kind r \<and> q = cc_val r"
  using assms by (auto simp: cc_kernel_def split: option.splits)

theorem cc_kernel_declines:
  "cc_kernel r = Decline w \<longleftrightarrow> (\<exists>why. cc_impossible r = Some why \<and> w = Impossible why)"
  by (auto simp: cc_kernel_def split: option.splits)

text \<open>The carbon round trip through the kernel: converting a carbon mass to CO2 and
that CO2 mass back to carbon returns the mass asked about (units only echo).\<close>
theorem carbon_kernel_roundtrip:
  assumes "cc_kernel (Cc_c_to_co2 m u) = Exact k q"
  shows "cc_kernel (Cc_co2_to_c q u') = Exact K_co2_to_c m"
proof -
  have q: "q = m * c_ratio" and m: "0 \<le> m"
    using cc_kernel_sound[OF assms] by (auto split: if_splits)
  have q0: "0 \<le> q" using m q by (simp add: c_ratio_def)
  show ?thesis using q q0 by (simp add: cc_kernel_def)
qed

text \<open>What each kind means. One mole of carbon makes one mole of CO2, so the
masses are in the ratio of the molar masses; the fuel factor is grams per gallon;
the captured mass is the emitted mass times the rate.\<close>
theorem c_to_co2_model:
  assumes "cc_kernel (Cc_c_to_co2 m u) = Exact k q"
  shows "k = K_c_to_co2 \<and> q * (12011 / 1000) = m * (4401 / 100)"
proof -
  have s: "k = K_c_to_co2" "q = m * c_ratio" using cc_kernel_sound[OF assms] by simp_all
  have e: "q * (12011 / 1000) = m * (c_ratio * (12011 / 1000))" by (subst s(2)) (rule mult.assoc)
  have "q * (12011 / 1000) = m * (4401 / 100)" by (simp only: e c_ratio_mul)
  then show ?thesis using s(1) by simp
qed

theorem co2_to_c_model:
  assumes "cc_kernel (Cc_co2_to_c m u) = Exact k q"
  shows "k = K_co2_to_c \<and> q * (4401 / 100) = m * (12011 / 1000)"
proof -
  have s: "k = K_co2_to_c" "q = m / c_ratio" using cc_kernel_sound[OF assms] by simp_all
  have qc: "q * c_ratio = m" using s(2) by (simp add: field_simps)
  have "q * (4401 / 100) = q * (c_ratio * (12011 / 1000))" by (simp only: c_ratio_mul)
  also have "\<dots> = (q * c_ratio) * (12011 / 1000)" by (rule mult.assoc[symmetric])
  finally have "q * (4401 / 100) = (q * c_ratio) * (12011 / 1000)" .
  then show ?thesis using s(1) qc by simp
qed

theorem carbon_co2_roundtrip: "cc_val (Cc_co2_to_c (cc_val (Cc_c_to_co2 m u)) u') = m"
  by (simp add: field_simps)

theorem fuel_co2_model:
  assumes "cc_kernel (Cc_fuel_co2 f n gal) = Exact k q"
  shows "k = K_fuel_co2 \<and> q * 1000 = gal * ef f"
  using cc_kernel_sound[OF assms] by (auto simp: field_simps)

theorem co2_per_mile_model:
  assumes "cc_kernel (Cc_co2_per_mile f n mpg) = Exact k q"
  shows "k = K_co2_per_mile \<and> mpg \<noteq> 0 \<and> q * mpg = ef f"
proof -
  have s: "cc_impossible (Cc_co2_per_mile f n mpg) = None" "k = K_co2_per_mile" "q = ef f / mpg"
    using cc_kernel_sound[OF assms] by simp_all
  then have "mpg \<noteq> 0" by (auto split: if_splits)
  then show ?thesis using s by simp
qed

theorem captured_model:
  assumes "cc_kernel (Cc_captured m u c) = Exact k q"
  shows "k = K_captured \<and> q * 100 = m * c \<and> c \<le> 100 \<and> (0 \<le> m \<and> 0 \<le> c \<longrightarrow> 0 \<le> q \<and> q \<le> m)"
proof -
  have s: "cc_impossible (Cc_captured m u c) = None" "k = K_captured" "q = m * c / 100"
    using cc_kernel_sound[OF assms] by simp_all
  then have c: "c \<le> 100" by (auto split: if_splits)
  have "q * 100 = m * c" using s(3) by (simp add: field_simps)
  moreover have "0 \<le> m \<and> 0 \<le> c \<longrightarrow> 0 \<le> q \<and> q \<le> m"
  proof
    assume h: "0 \<le> m \<and> 0 \<le> c"
    have p: "0 \<le> m * c" using h by simp
    have "m * c \<le> m * 100" using h c by (intro mult_left_mono) simp_all
    then show "0 \<le> q \<and> q \<le> m" using s(3) p by linarith
  qed
  ultimately show ?thesis using s(2) c by simp
qed

theorem capture_energy_model:
  assumes "cc_kernel (Cc_capture_energy m u c e eu) = Exact k q"
  shows "k = K_capture_energy \<and> c \<le> 100 \<and> q = mass_tonnes m u * c / 100 * e"
  using cc_kernel_sound[OF assms] by (auto split: if_splits)

theorem capture_rate_over_100:
  "cc_kernel (Cc_captured m u c) = Decline (Impossible R_rate_over_100) \<longleftrightarrow> 100 < c"
  by (auto simp: cc_kernel_def split: if_splits)

theorem capture_energy_rate_over_100:
  "cc_kernel (Cc_capture_energy m u c e eu) = Decline (Impossible R_rate_over_100) \<longleftrightarrow> 100 < c"
  by (auto simp: cc_kernel_def split: if_splits)

theorem zero_mpg_declined:
  "cc_kernel (Cc_co2_per_mile f n mpg) = Decline w \<longleftrightarrow> mpg \<le> 0 \<and> w = Impossible R_zero_mpg"
  by (auto simp: cc_kernel_def split: if_splits)

theorem carbon_success_feasible:
  "(\<exists>k q. cc_kernel r = Exact k q) \<longleftrightarrow> cc_feasible r"
proof -
  have exact_shape: "(\<exists>k q. cc_kernel r = Exact k q) \<longleftrightarrow> cc_impossible r = None"
    by (cases "cc_impossible r") (auto simp: cc_kernel_def)
  have guard: "cc_impossible r = None \<longleftrightarrow> cc_feasible r"
    by (cases r) (auto split: if_splits)
  show ?thesis using exact_shape guard by simp
qed

theorem captured_success_bounds:
  assumes k: "cc_kernel (Cc_captured m u c) = Exact kind q"
  shows "0 \<le> m \<and> 0 \<le> c \<and> c \<le> 100 \<and> 0 \<le> q \<and> q \<le> m"
  using carbon_success_feasible[of "Cc_captured m u c"] captured_model[OF k] k by auto

theorem capture_energy_success_nonnegative:
  assumes k: "cc_kernel (Cc_capture_energy m u c e eu) = Exact kind q"
  shows "0 \<le> q"
proof -
  have f: "0 \<le> m" "0 \<le> c" "0 \<le> e"
    using carbon_success_feasible[of "Cc_capture_energy m u c e eu"] k by auto
  have m0: "0 \<le> mass_tonnes m u" using f(1) by simp
  have q: "q = mass_tonnes m u * c / 100 * e" using capture_energy_model[OF k] by simp
  have a0: "0 \<le> mass_tonnes m u * c" by (rule mult_nonneg_nonneg[OF m0 f(2)])
  have b0: "0 \<le> mass_tonnes m u * c / 100" using a0 by simp
  show ?thesis unfolding q by (rule mult_nonneg_nonneg[OF b0 f(3)])
qed

theorem capture_energy_unit_answers:
  "cc_kernel (Cc_capture_energy (1000*m) Mass_kg c e eu) = cc_kernel (Cc_capture_energy m Mass_tonne c e eu)"
  "cc_kernel (Cc_capture_energy (1000000*m) Mass_g c e eu) = cc_kernel (Cc_capture_energy m Mass_tonne c e eu)"
  "cc_kernel (Cc_capture_energy m Mass_Mt c e eu) = cc_kernel (Cc_capture_energy (1000000*m) Mass_tonne c e eu)"
  "cc_kernel (Cc_capture_energy m Mass_Gt c e eu) = cc_kernel (Cc_capture_energy (1000000000*m) Mass_tonne c e eu)"
  by (simp_all add: cc_kernel_def mult_less_0_iff)

theorem capture_energy_zero_intensity:
  "0 \<le> m \<Longrightarrow> 0 \<le> c \<Longrightarrow> c \<le> 100 \<Longrightarrow>
    cc_kernel (Cc_capture_energy m u c 0 eu) = Exact K_capture_energy 0"
  by (simp add: cc_kernel_def)


section \<open>Air quality (airquality): the US AQI from EPA's breakpoint table\<close>

text \<open>The index bands, and per pollutant the concentration breakpoints of the
bands that exist for it (the organ's @{text None} rows are always the last ones:
ozone has five rows, SO2 four). Truncation decimals and the pollutant order used
to break a tie for the highest sub-index (the organ's @{text "max"} of tuples
compares the pollutant key strings).\<close>
definition idx_rows :: "(rat \<times> rat) list" where
  "idx_rows = [(0, 50), (51, 100), (101, 150), (151, 200), (201, 300), (301, 500)]"

fun bps :: "pol \<Rightarrow> (rat \<times> rat) list" where
  "bps P_pm25 = [(0, 9), (91/10, 354/10), (355/10, 554/10), (555/10, 1254/10), (1255/10, 2254/10), (2255/10, 3254/10)]"
| "bps P_pm10 = [(0, 54), (55, 154), (155, 254), (255, 354), (355, 424), (425, 604)]"
| "bps P_o3 = [(0, 54/1000), (55/1000, 70/1000), (71/1000, 85/1000), (86/1000, 105/1000), (106/1000, 200/1000)]"
| "bps P_co = [(0, 44/10), (45/10, 94/10), (95/10, 124/10), (125/10, 154/10), (155/10, 304/10), (305/10, 504/10)]"
| "bps P_so2 = [(0, 35), (36, 75), (76, 185), (186, 304)]"
| "bps P_no2 = [(0, 53), (54, 100), (101, 360), (361, 649), (650, 1249), (1250, 2049)]"

fun tdig :: "pol \<Rightarrow> nat" where
  "tdig P_pm25 = 1" | "tdig P_pm10 = 0" | "tdig P_o3 = 3" | "tdig P_co = 1" | "tdig P_so2 = 0" | "tdig P_no2 = 0"

fun rank :: "pol \<Rightarrow> nat" where
  "rank P_co = 0" | "rank P_no2 = 1" | "rank P_o3 = 2" | "rank P_pm10 = 3" | "rank P_pm25 = 4" | "rank P_so2 = 5"

fun is_pm :: "pol \<Rightarrow> bool" where
  "is_pm P_pm25 = True" | "is_pm P_pm10 = True" | "is_pm P_o3 = False" | "is_pm P_co = False"
| "is_pm P_so2 = False" | "is_pm P_no2 = False"

definition rows :: "pol \<Rightarrow> ((rat \<times> rat) \<times> (rat \<times> rat)) list" where
  "rows p = zip idx_rows (bps p)"

definition top_bp :: "pol \<Rightarrow> rat" where
  "top_bp p = snd (last (bps p))"

definition trunc_q :: "rat \<Rightarrow> nat \<Rightarrow> rat" where
  "trunc_q x d = of_int \<lfloor>x * 10 ^ d\<rfloor> / 10 ^ d"

definition in_row :: "rat \<Rightarrow> (rat \<times> rat) \<times> (rat \<times> rat) \<Rightarrow> bool" where
  "in_row c r = (fst (snd r) \<le> c \<and> c \<le> snd (snd r))"

definition interp :: "(rat \<times> rat) \<times> (rat \<times> rat) \<Rightarrow> rat \<Rightarrow> rat" where
  "interp r c = (snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r)) * (c - fst (snd r)) + fst (fst r)"

definition find_row :: "pol \<Rightarrow> rat \<Rightarrow> ((rat \<times> rat) \<times> (rat \<times> rat)) option" where
  "find_row p c = List.find (in_row c) (rows p)"

definition sub_index :: "pol \<Rightarrow> rat \<Rightarrow> int option" where
  "sub_index p c = map_option (\<lambda>r. \<lfloor>interp r c + 1 / 2\<rfloor>) (find_row p c)"

definition sub_reason :: "pol \<Rightarrow> rat \<Rightarrow> reason" where
  "sub_reason p c = (if top_bp p < c then
      (case p of P_o3 \<Rightarrow> R_o3_above_8h | P_so2 \<Rightarrow> R_so2_above_1h | _ \<Rightarrow> R_beyond p)
    else R_between p)"

fun cat_of :: "rat \<Rightarrow> cat" where
  "cat_of a = (if a \<le> 50 then Cat_good else if a \<le> 100 then Cat_moderate else if a \<le> 150 then Cat_usg
     else if a \<le> 200 then Cat_unhealthy else if a \<le> 300 then Cat_very_unhealthy else Cat_hazardous)"

datatype aunit = Au_none | Au_ug | Au_ppm | Au_ppb
datatype reading = Reading pol rat aunit

text \<open>Units are normalised as the organ does: ozone in ppb (or a bare number of
1 or more) is ppm times a thousand; SO2 and NO2 in ppm are ppb; CO in ppb is ppm.\<close>
fun aq_conc :: "pol \<Rightarrow> aunit \<Rightarrow> rat \<Rightarrow> rat" where
  "aq_conc P_o3 u c = (if u = Au_ppb \<or> (u = Au_none \<and> 1 \<le> c) then c / 1000 else c)"
| "aq_conc P_so2 u c = (if u = Au_ppm then c * 1000 else c)"
| "aq_conc P_no2 u c = (if u = Au_ppm then c * 1000 else c)"
| "aq_conc P_co u c = (if u = Au_ppb then c / 1000 else c)"
| "aq_conc P_pm25 u c = c"
| "aq_conc P_pm10 u c = c"

datatype sub = Sub pol rat int

fun sub_aqi :: "sub \<Rightarrow> int" where "sub_aqi (Sub p c a) = a"
fun sub_pol :: "sub \<Rightarrow> pol" where "sub_pol (Sub p c a) = p"

definition aq_one :: "bool \<Rightarrow> reading \<Rightarrow> (decline, sub) sum" where
  "aq_one hourly rd = (case rd of Reading p c u \<Rightarrow>
     if hourly \<and> is_pm p then Inl (Impossible R_pm_hourly)
     else if is_pm p \<and> (u = Au_ppm \<or> u = Au_ppb) then Inl Not_taken
     else (let ct = trunc_q (aq_conc p u c) (tdig p) in
       case sub_index p ct of Some a \<Rightarrow> Inr (Sub p ct a) | None \<Rightarrow> Inl (Impossible (sub_reason p ct))))"

fun aq_subs :: "bool \<Rightarrow> reading list \<Rightarrow> (decline, sub list) sum" where
  "aq_subs h [] = Inr []"
| "aq_subs h (r # rs) = (case aq_one h r of Inl d \<Rightarrow> Inl d
     | Inr s \<Rightarrow> (case aq_subs h rs of Inl d \<Rightarrow> Inl d | Inr ss \<Rightarrow> Inr (s # ss)))"

definition sub_gt :: "sub \<Rightarrow> sub \<Rightarrow> bool" where
  "sub_gt s t = (sub_aqi t < sub_aqi s \<or> (sub_aqi s = sub_aqi t \<and> rank (sub_pol t) < rank (sub_pol s)))"

fun best :: "sub list \<Rightarrow> sub option" where
  "best [] = None"
| "best (s # ss) = (case best ss of None \<Rightarrow> Some s | Some t \<Rightarrow> Some (if sub_gt s t then s else t))"

datatype aqreq = Aq_index bool "reading list" | Aq_category rat String.literal

definition aq_kernel :: "aqreq \<Rightarrow> outcome" where
  "aq_kernel r = (case r of
     Aq_index h rs \<Rightarrow>
       (case aq_subs h rs of Inl d \<Rightarrow> Decline d
        | Inr ss \<Rightarrow> (case ss of [] \<Rightarrow> Decline Not_taken
             | [s] \<Rightarrow> Index K_aqi (sub_aqi s) (sub_pol s)
             | _ \<Rightarrow> (case best ss of None \<Rightarrow> Decline Not_taken
                       | Some s \<Rightarrow> Index K_overall (sub_aqi s) (sub_pol s))))
   | Aq_category a _ \<Rightarrow>
       (if a < 0 \<or> 500 < a then Decline (Impossible R_aqi_out_of_scale) else Category (cat_of a)))"

lemma best_None: "best ss = None \<longleftrightarrow> ss = []"
  by (cases ss) (auto split: option.splits)

lemma best_max: "best ss = Some t \<Longrightarrow> t \<in> set ss \<and> (\<forall>s\<in>set ss. sub_aqi s \<le> sub_aqi t)"
proof (induction ss arbitrary: t)
  case Nil then show ?case by simp
next
  case (Cons s ss)
  show ?case
  proof (cases "best ss")
    case None
    then have "ss = []" by (simp add: best_None)
    then show ?thesis using Cons.prems None by simp
  next
    case (Some t')
    have IH: "t' \<in> set ss \<and> (\<forall>x\<in>set ss. sub_aqi x \<le> sub_aqi t')" using Cons.IH[OF Some] .
    show ?thesis
    proof (cases "sub_gt s t'")
      case True
      then have t: "t = s" using Cons.prems Some by simp
      have "sub_aqi t' \<le> sub_aqi s" using True by (auto simp: sub_gt_def)
      then show ?thesis using t IH by auto
    next
      case False
      then have t: "t = t'" using Cons.prems Some by simp
      have "sub_aqi s \<le> sub_aqi t'" using False by (auto simp: sub_gt_def)
      then show ?thesis using t IH by auto
    qed
  qed
qed

text \<open>The AQI of one concentration: the first band whose breakpoints contain the
truncated concentration, and the interpolation
@{text "(I_hi - I_lo)/(BP_hi - BP_lo) * (C - BP_lo) + I_lo"} rounded to the
nearest integer (half up).\<close>
theorem sub_index_interpolation:
  assumes "sub_index p c = Some a"
  shows "\<exists>r \<in> set (rows p). in_row c r \<and> of_int a \<le> interp r c + 1 / 2 \<and> interp r c + 1 / 2 < of_int a + 1"
proof -
  obtain r where r: "find_row p c = Some r" and a: "a = \<lfloor>interp r c + 1 / 2\<rfloor>"
    using assms by (auto simp: sub_index_def)
  obtain i where i: "i < length (rows p)" "in_row c (rows p ! i)" "r = rows p ! i"
    using r by (auto simp: find_row_def find_Some_iff)
  have mem: "r \<in> set (rows p)" using i by (auto simp: nth_mem)
  have inr: "in_row c r" using i by simp
  have fc: "(of_int \<lfloor>interp r c + 1 / 2\<rfloor> :: rat) \<le> interp r c + 1 / 2 \<and>
            interp r c + 1 / 2 < of_int \<lfloor>interp r c + 1 / 2\<rfloor> + 1"
    by (metis floor_correct of_int_add of_int_1 of_int_floor_le)
  show ?thesis using mem inr fc a by blast
qed

theorem sub_index_none:
  "sub_index p c = None \<longleftrightarrow> (\<forall>r \<in> set (rows p). \<not> in_row c r)"
  by (auto simp: sub_index_def find_row_def find_None_iff)

text \<open>A single reading stated as an AQI is the sub-index of the truncated,
unit-normalised concentration, and was not an hourly particle value or a particle
value in a gas unit.\<close>
theorem aq_single_sound:
  assumes "aq_kernel (Aq_index h [Reading p c u]) = Index k a q"
  shows "k = K_aqi \<and> q = p \<and> \<not> (h \<and> is_pm p) \<and> \<not> (is_pm p \<and> (u = Au_ppm \<or> u = Au_ppb)) \<and>
         sub_index p (trunc_q (aq_conc p u c) (tdig p)) = Some a"
proof (cases "aq_one h (Reading p c u)")
  case (Inl d) then show ?thesis using assms by (simp add: aq_kernel_def)
next
  case (Inr s)
  have kv: "k = K_aqi" "a = sub_aqi s" "q = sub_pol s"
    using assms Inr by (simp_all add: aq_kernel_def)
  have f: "\<not> (h \<and> is_pm p) \<and> \<not> (is_pm p \<and> (u = Au_ppm \<or> u = Au_ppb)) \<and>
           (\<exists>a'. sub_index p (trunc_q (aq_conc p u c) (tdig p)) = Some a' \<and>
                s = Sub p (trunc_q (aq_conc p u c) (tdig p)) a')"
    using Inr by (auto simp: aq_one_def Let_def split: if_splits option.splits)
  then show ?thesis using kv by auto
qed

text \<open>Several readings: the overall AQI is the highest sub-index, and the
pollutant named is one that sets it.\<close>
theorem aq_overall_sound:
  assumes "aq_kernel (Aq_index h rs) = Index K_overall a q"
  shows "\<exists>ss. aq_subs h rs = Inr ss \<and> 2 \<le> length ss \<and>
           (\<exists>s \<in> set ss. sub_pol s = q \<and> sub_aqi s = a) \<and> (\<forall>s \<in> set ss. sub_aqi s \<le> a)"
proof (cases "aq_subs h rs")
  case (Inl d) then show ?thesis using assms by (simp add: aq_kernel_def)
next
  case (Inr ss)
  have key: "(case ss of [] \<Rightarrow> Decline Not_taken
      | [s] \<Rightarrow> Index K_aqi (sub_aqi s) (sub_pol s)
      | _ \<Rightarrow> (case best ss of None \<Rightarrow> Decline Not_taken
                | Some s \<Rightarrow> Index K_overall (sub_aqi s) (sub_pol s))) = Index K_overall a q"
    using assms Inr by (simp add: aq_kernel_def)
  show ?thesis
  proof (cases ss)
    case Nil then show ?thesis using key by simp
  next
    case (Cons s0 ts)
    show ?thesis
    proof (cases ts)
      case Nil then show ?thesis using key Cons by simp
    next
      case (Cons t us)
      have ssd: "ss = s0 # t # us" using \<open>ss = s0 # ts\<close> Cons by simp
      show ?thesis
      proof (cases "best ss")
        case None then show ?thesis using key ssd by simp
      next
        case (Some s)
        have v: "a = sub_aqi s" "q = sub_pol s" using key ssd Some by simp_all
        have m: "s \<in> set ss" "\<forall>x \<in> set ss. sub_aqi x \<le> sub_aqi s" using best_max[OF Some] by simp_all
        show ?thesis using Inr ssd v m by auto
      qed
    qed
  qed
qed

theorem aq_category_sound:
  assumes "aq_kernel (Aq_category a n) = Category c"
  shows "0 \<le> a \<and> a \<le> 500 \<and> c = cat_of a"
  using assms by (auto simp: aq_kernel_def split: if_splits)

theorem aq_category_out_of_scale:
  "aq_kernel (Aq_category a n) = Decline w \<longleftrightarrow> (a < 0 \<or> 500 < a) \<and> w = Impossible R_aqi_out_of_scale"
  by (auto simp: aq_kernel_def split: if_splits)

text \<open>The EPA bands: the category of 50 is Good, of 51 Moderate, of 150 Unhealthy
for Sensitive Groups, of 301 Hazardous.\<close>
theorem cat_of_bands:
  "cat_of 50 = Cat_good \<and> cat_of 51 = Cat_moderate \<and> cat_of 100 = Cat_moderate \<and> cat_of 101 = Cat_usg
   \<and> cat_of 150 = Cat_usg \<and> cat_of 151 = Cat_unhealthy \<and> cat_of 200 = Cat_unhealthy
   \<and> cat_of 201 = Cat_very_unhealthy \<and> cat_of 300 = Cat_very_unhealthy \<and> cat_of 301 = Cat_hazardous"
  by simp

text \<open>The AQI is monotone in concentration, stated against the transcribed
breakpoint table @{const rows}. A table is well ordered when each row has a
positive-width concentration range and a non-decreasing index range, and every
later row starts above where this one ends in both. The index of a concentration
is then non-decreasing in the concentration (a concentration in a gap between rows
has no index and is not compared).\<close>
definition row_valid :: "(rat \<times> rat) \<times> (rat \<times> rat) \<Rightarrow> bool" where
  "row_valid r = (fst (snd r) < snd (snd r) \<and> fst (fst r) \<le> snd (fst r))"

fun rows_ordered :: "((rat \<times> rat) \<times> (rat \<times> rat)) list \<Rightarrow> bool" where
  "rows_ordered [] = True"
| "rows_ordered (r # rs) = (row_valid r \<and> rows_ordered rs \<and>
     (\<forall>r' \<in> set rs. snd (snd r) < fst (snd r') \<and> snd (fst r) \<le> fst (fst r')))"

lemma rows_ordered_valid: "rows_ordered rs \<Longrightarrow> r \<in> set rs \<Longrightarrow> row_valid r"
  by (induction rs) auto

lemma interp_mono:
  assumes "row_valid r" "c1 \<le> c2"
  shows "interp r c1 \<le> interp r c2"
proof -
  have "0 \<le> (snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r))"
    using assms(1) by (auto simp: row_valid_def intro!: divide_nonneg_pos)
  then have "(snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r)) * (c1 - fst (snd r))
      \<le> (snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r)) * (c2 - fst (snd r))"
    using assms(2) by (intro mult_left_mono) simp_all
  then show ?thesis by (simp add: interp_def)
qed

lemma interp_le_hi:
  assumes "row_valid r" "in_row c r"
  shows "interp r c \<le> snd (fst r)"
proof -
  have w: "0 < snd (snd r) - fst (snd r)" using assms(1) by (simp add: row_valid_def)
  have "(snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r)) * (c - fst (snd r))
        \<le> (snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r)) * (snd (snd r) - fst (snd r))"
    using assms by (intro mult_left_mono) (auto simp: row_valid_def in_row_def intro!: divide_nonneg_pos)
  also have "\<dots> = snd (fst r) - fst (fst r)" using w by simp
  finally show ?thesis by (simp add: interp_def)
qed

lemma interp_ge_lo:
  assumes "row_valid r" "in_row c r"
  shows "fst (fst r) \<le> interp r c"
proof -
  have "0 \<le> (snd (fst r) - fst (fst r)) / (snd (snd r) - fst (snd r)) * (c - fst (snd r))"
    using assms by (intro mult_nonneg_nonneg) (auto simp: row_valid_def in_row_def intro!: divide_nonneg_pos)
  then show ?thesis by (simp add: interp_def)
qed

lemma find_in_row: "List.find P xs = Some x \<Longrightarrow> x \<in> set xs \<and> P x"
  by (induction xs) (auto split: if_splits)

lemma find_rows_mono:
  assumes "rows_ordered rs" "List.find (in_row c1) rs = Some r1" "List.find (in_row c2) rs = Some r2"
    "c1 \<le> c2"
  shows "\<lfloor>interp r1 c1 + 1 / 2\<rfloor> \<le> \<lfloor>interp r2 c2 + 1 / 2\<rfloor>"
  using assms
proof (induction rs arbitrary: r1 r2)
  case Nil then show ?case by simp
next
  case (Cons r rs)
  have ord: "row_valid r" "rows_ordered rs"
    and later: "\<forall>r' \<in> set rs. snd (snd r) < fst (snd r') \<and> snd (fst r) \<le> fst (fst r')"
    using Cons.prems(1) by simp_all
  show ?case
  proof (cases "in_row c1 r")
    case t1: True
    show ?thesis
    proof (cases "in_row c2 r")
      case True
      then have "r1 = r" "r2 = r" using t1 Cons.prems by simp_all
      then show ?thesis using interp_mono[OF ord(1) Cons.prems(4)] by (simp add: floor_mono)
    next
      case False
      then have r1: "r1 = r" and f2: "List.find (in_row c2) rs = Some r2" using t1 Cons.prems by simp_all
      have m2: "r2 \<in> set rs" "in_row c2 r2" using find_in_row[OF f2] by simp_all
      have v2: "row_valid r2" using rows_ordered_valid[OF ord(2) m2(1)] .
      have "interp r c1 \<le> snd (fst r)" using interp_le_hi[OF ord(1) t1] .
      also have "snd (fst r) \<le> fst (fst r2)" using later m2(1) by blast
      also have "fst (fst r2) \<le> interp r2 c2" using interp_ge_lo[OF v2 m2(2)] .
      finally show ?thesis using r1 by (simp add: floor_mono)
    qed
  next
    case f1: False
    show ?thesis
    proof (cases "in_row c2 r")
      case True
      then have r2: "r2 = r" and g1: "List.find (in_row c1) rs = Some r1" using f1 Cons.prems by simp_all
      have m1: "r1 \<in> set rs" "in_row c1 r1" using find_in_row[OF g1] by simp_all
      have "snd (snd r) < fst (snd r1)" using later m1(1) by blast
      moreover have "fst (snd r1) \<le> c1" "c2 \<le> snd (snd r)" using m1(2) True by (simp_all add: in_row_def)
      ultimately show ?thesis using Cons.prems(4) by linarith
    next
      case False
      then show ?thesis using f1 Cons.IH[OF ord(2)] Cons.prems by simp
    qed
  qed
qed

lemma all_rows_ordered: "rows_ordered (rows p)"
  by (cases p) (simp_all add: rows_def idx_rows_def row_valid_def)

theorem sub_index_monotone:
  assumes "sub_index p c1 = Some a1" "sub_index p c2 = Some a2" "c1 \<le> c2"
  shows "a1 \<le> a2"
proof -
  obtain r1 where r1: "find_row p c1 = Some r1" "a1 = \<lfloor>interp r1 c1 + 1 / 2\<rfloor>"
    using assms(1) by (auto simp: sub_index_def)
  obtain r2 where r2: "find_row p c2 = Some r2" "a2 = \<lfloor>interp r2 c2 + 1 / 2\<rfloor>"
    using assms(2) by (auto simp: sub_index_def)
  show ?thesis using find_rows_mono[OF all_rows_ordered r1(1)[unfolded find_row_def]
      r2(1)[unfolded find_row_def] assms(3)] r1(2) r2(2) by simp
qed


section \<open>Climate arithmetic (climate)\<close>

text \<open>Constants: the CO2 forcing coefficient 5.35 W/m2 (Myhre et al. 1998), the
Stefan-Boltzmann constant, and the Global Carbon Project conversion 1 ppm = 2.124 GtC
(and times 44.0095 / 12.011 for GtCO2).\<close>
definition forcing_coeff :: rat where "forcing_coeff = 107 / 20"
definition sigma :: rat where "sigma = 5670374419 / 100000000000000000"
definition gtc_per_ppm :: rat where "gtc_per_ppm = 2124 / 1000"
definition gtco2_per_ppm :: rat where
  "gtco2_per_ppm = 2124 / 1000 * (440095 / 10000) / (12011 / 1000)"

datatype sens = Sens_lambda rat | Sens_ecs rat | Sens_none

text \<open>A concentration pair is (initial, final) in ppm; the strings echo the
question's wording.\<close>
datatype clreq =
    Cl_forcing "(rat \<times> rat) option"
  | Cl_warming "(rat \<times> rat) option" sens
  | Cl_ppm_to_gtc rat
  | Cl_ppm_to_gtco2 rat
  | Cl_mass_to_ppm rat bool String.literal
  | Cl_eff_temp "rat option" "rat option"
  | Cl_co2e "rat option" rat String.literal String.literal

text \<open>A request that is complete and possible, with exactly the numbers its
formula reads.\<close>
datatype clspec =
    Sp_forcing rat rat
  | Sp_warming_lambda rat rat rat
  | Sp_warming_ecs rat rat rat
  | Sp_gtc rat
  | Sp_gtco2 rat
  | Sp_ppm rat bool
  | Sp_teff rat rat
  | Sp_co2e rat rat

fun cl_missing :: "clreq \<Rightarrow> need option" where
  "cl_missing (Cl_forcing cc) = (case cc of None \<Rightarrow> Some N_conc | Some _ \<Rightarrow> None)"
| "cl_missing (Cl_warming cc s) = (case cc of None \<Rightarrow> Some N_conc
     | Some _ \<Rightarrow> (case s of Sens_none \<Rightarrow> Some N_sens | _ \<Rightarrow> None))"
| "cl_missing (Cl_ppm_to_gtc _) = None"
| "cl_missing (Cl_ppm_to_gtco2 _) = None"
| "cl_missing (Cl_mass_to_ppm _ _ _) = None"
| "cl_missing (Cl_eff_temp s a) = (if s = None \<or> a = None then Some N_solar_albedo else None)"
| "cl_missing (Cl_co2e g _ _ _) = (case g of None \<Rightarrow> Some N_gwp | Some _ \<Rightarrow> None)"

fun cl_impossible :: "clreq \<Rightarrow> reason option" where
  "cl_impossible (Cl_forcing cc) = (case cc of Some (c0, c) \<Rightarrow>
     (if c0 \<le> 0 \<or> c \<le> 0 then Some R_nonpositive_conc else None) | None \<Rightarrow> None)"
| "cl_impossible (Cl_warming cc s) = (case cc of Some (c0, c) \<Rightarrow>
     (if c0 \<le> 0 \<or> c \<le> 0 then Some R_nonpositive_conc else None) | None \<Rightarrow> None)"
| "cl_impossible (Cl_ppm_to_gtc _) = None"
| "cl_impossible (Cl_ppm_to_gtco2 _) = None"
| "cl_impossible (Cl_mass_to_ppm _ _ _) = None"
| "cl_impossible (Cl_eff_temp s a) = (case s of Some sv \<Rightarrow> (case a of Some av \<Rightarrow>
     (if sv < 0 then Some R_negative_solar else if av < 0 \<or> 1 < av then Some R_albedo_range else None)
     | None \<Rightarrow> None) | None \<Rightarrow> None)"
| "cl_impossible (Cl_co2e _ _ _ _) = None"

text \<open>The spec of a request that passed both checks (a dummy for the others,
never reached by the kernel).\<close>
fun cl_spec :: "clreq \<Rightarrow> clspec" where
  "cl_spec (Cl_forcing cc) = (case cc of Some (c0, c) \<Rightarrow> Sp_forcing c0 c | None \<Rightarrow> Sp_gtc 0)"
| "cl_spec (Cl_warming cc s) = (case cc of Some (c0, c) \<Rightarrow>
     (case s of Sens_lambda l \<Rightarrow> Sp_warming_lambda l c0 c | Sens_ecs e \<Rightarrow> Sp_warming_ecs e c0 c
      | Sens_none \<Rightarrow> Sp_gtc 0) | None \<Rightarrow> Sp_gtc 0)"
| "cl_spec (Cl_ppm_to_gtc p) = Sp_gtc p"
| "cl_spec (Cl_ppm_to_gtco2 p) = Sp_gtco2 p"
| "cl_spec (Cl_mass_to_ppm c co2 _) = Sp_ppm c co2"
| "cl_spec (Cl_eff_temp s a) = (case s of Some sv \<Rightarrow> (case a of Some av \<Rightarrow> Sp_teff sv av
     | None \<Rightarrow> Sp_gtc 0) | None \<Rightarrow> Sp_gtc 0)"
| "cl_spec (Cl_co2e g m _ _) = (case g of Some gv \<Rightarrow> Sp_co2e m gv | None \<Rightarrow> Sp_gtc 0)"

fun sp_kind :: "clspec \<Rightarrow> kind" where
  "sp_kind (Sp_forcing _ _) = K_forcing"
| "sp_kind (Sp_warming_lambda _ _ _) = K_warming_lambda"
| "sp_kind (Sp_warming_ecs _ _ _) = K_warming_ecs"
| "sp_kind (Sp_gtc _) = K_ppm_to_gtc"
| "sp_kind (Sp_gtco2 _) = K_ppm_to_gtco2"
| "sp_kind (Sp_ppm _ _) = K_mass_to_ppm"
| "sp_kind (Sp_teff _ _) = K_effective_temp"
| "sp_kind (Sp_co2e _ _) = K_co2e"

text \<open>Exact kinds carry a rational value; the others a float expression and the
real it encloses.\<close>
fun sp_exact :: "clspec \<Rightarrow> rat option" where
  "sp_exact (Sp_forcing _ _) = None"
| "sp_exact (Sp_warming_lambda _ _ _) = None"
| "sp_exact (Sp_warming_ecs _ _ _) = None"
| "sp_exact (Sp_gtc p) = Some (p * gtc_per_ppm)"
| "sp_exact (Sp_gtco2 p) = Some (p * gtco2_per_ppm)"
| "sp_exact (Sp_ppm c co2) = Some (c / (if co2 then gtco2_per_ppm else gtc_per_ppm))"
| "sp_exact (Sp_teff _ _) = None"
| "sp_exact (Sp_co2e m g) = Some (m * g)"

definition eff_x :: "rat \<Rightarrow> rat \<Rightarrow> rat" where
  "eff_x s a = s * (1 - a) / (4 * sigma)"

fun sp_fa :: "clspec \<Rightarrow> floatarith" where
  "sp_fa (Sp_forcing c0 c) = floatarith.Mult (Q forcing_coeff) (floatarith.Ln (Q (c / c0)))"
| "sp_fa (Sp_warming_lambda l c0 c) =
     floatarith.Mult (Q l) (floatarith.Mult (Q forcing_coeff) (floatarith.Ln (Q (c / c0))))"
| "sp_fa (Sp_warming_ecs e c0 c) =
     floatarith.Mult (Q e) (floatarith.Mult (floatarith.Ln (Q (c / c0))) (floatarith.Inverse (floatarith.Ln (I 2))))"
| "sp_fa (Sp_teff s a) = floatarith.Sqrt (floatarith.Sqrt (Q (eff_x s a)))"
| "sp_fa (Sp_gtc _) = I 0"
| "sp_fa (Sp_gtco2 _) = I 0"
| "sp_fa (Sp_ppm _ _) = I 0"
| "sp_fa (Sp_co2e _ _) = I 0"

text \<open>The real-number model: the logarithm and fourth root are the real ones.\<close>
fun sp_phys :: "clspec \<Rightarrow> real" where
  "sp_phys (Sp_forcing c0 c) = rl forcing_coeff * ln (rl (c / c0))"
| "sp_phys (Sp_warming_lambda l c0 c) = rl l * (rl forcing_coeff * ln (rl (c / c0)))"
| "sp_phys (Sp_warming_ecs e c0 c) = rl e * (ln (rl (c / c0)) / ln 2)"
| "sp_phys (Sp_teff s a) = sqrt (sqrt (rl (eff_x s a)))"
| "sp_phys (Sp_gtc p) = rl (p * gtc_per_ppm)"
| "sp_phys (Sp_gtco2 p) = rl (p * gtco2_per_ppm)"
| "sp_phys (Sp_ppm c co2) = rl (c / (if co2 then gtco2_per_ppm else gtc_per_ppm))"
| "sp_phys (Sp_co2e m g) = rl (m * g)"

lemma sp_fa_interp:
  "sp_exact sp = None \<Longrightarrow> interpret_floatarith (sp_fa sp) [] = sp_phys sp"
  by (cases sp) (simp_all add: divide_inverse)

lemma sp_exact_phys:
  "sp_exact sp = Some q \<Longrightarrow> sp_phys sp = rl q"
  by (cases sp) simp_all

definition cl_kernel :: "clreq \<Rightarrow> outcome" where
  "cl_kernel r = (case cl_missing r of Some n \<Rightarrow> Decline (Underspecified n)
     | None \<Rightarrow> (case cl_impossible r of Some w \<Rightarrow> Decline (Impossible w)
        | None \<Rightarrow> (let sp = cl_spec r in spec_out 3 (sp_kind sp) (sp_exact sp) (sp_fa sp))))"

theorem cl_exact_sound:
  assumes "cl_kernel r = Exact k q"
  shows "cl_missing r = None \<and> cl_impossible r = None \<and> k = sp_kind (cl_spec r) \<and>
         sp_exact (cl_spec r) = Some q \<and> sp_phys (cl_spec r) = rl q"
proof -
  have m: "cl_missing r = None" and i: "cl_impossible r = None"
    using assms by (auto simp: cl_kernel_def split: option.splits)
  have "spec_out 3 (sp_kind (cl_spec r)) (sp_exact (cl_spec r)) (sp_fa (cl_spec r)) = Exact k q"
    using assms m i by (auto simp: cl_kernel_def Let_def)
  from spec_out_exact[OF this] have "sp_exact (cl_spec r) = Some q" "k = sp_kind (cl_spec r)" by simp_all
  then show ?thesis using m i sp_exact_phys by blast
qed

text \<open>A decimal the kernel states for a logarithm or root is within half a unit of
its last printed place (plus a billionth) of the real model value.\<close>
theorem cl_approx_sound:
  assumes "cl_kernel r = Approx k d"
  shows "cl_missing r = None \<and> cl_impossible r = None \<and> k = sp_kind (cl_spec r) \<and>
         sp_exact (cl_spec r) = None \<and> (snd d = -3 \<or> snd d = 0) \<and>
         \<bar>dec_val d - sp_phys (cl_spec r)\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
proof -
  have m: "cl_missing r = None" and i: "cl_impossible r = None"
    using assms by (auto simp: cl_kernel_def split: option.splits)
  have "spec_out 3 (sp_kind (cl_spec r)) (sp_exact (cl_spec r)) (sp_fa (cl_spec r)) = Approx k d"
    using assms m i by (auto simp: cl_kernel_def Let_def)
  from spec_out_approx[OF this] have
    s: "sp_exact (cl_spec r) = None" "k = sp_kind (cl_spec r)" "snd d = - int 3 \<or> snd d = 0"
    and b: "\<bar>dec_val d - interpret_floatarith (sp_fa (cl_spec r)) []\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
    by simp_all
  have "interpret_floatarith (sp_fa (cl_spec r)) [] = sp_phys (cl_spec r)" using sp_fa_interp[OF s(1)] .
  then show ?thesis using m i s b by auto
qed

lemma cl_decline_cases:
  assumes "cl_kernel r = Decline w"
  shows "(\<exists>n. cl_missing r = Some n \<and> w = Underspecified n) \<or>
         (cl_missing r = None \<and> (\<exists>y. cl_impossible r = Some y \<and> w = Impossible y)) \<or>
         (cl_missing r = None \<and> cl_impossible r = None \<and> w = Imprecise)"
  using assms by (auto simp: cl_kernel_def Let_def dest: spec_out_decline split: option.splits)

theorem cl_underspecified:
  "cl_kernel r = Decline (Underspecified n) \<longleftrightarrow> cl_missing r = Some n"
proof
  assume "cl_kernel r = Decline (Underspecified n)"
  from cl_decline_cases[OF this] show "cl_missing r = Some n" by auto
next
  assume "cl_missing r = Some n"
  then show "cl_kernel r = Decline (Underspecified n)" by (simp add: cl_kernel_def)
qed

theorem cl_impossible_iff:
  "(\<exists>why. cl_kernel r = Decline (Impossible why)) \<longleftrightarrow> cl_missing r = None \<and> cl_impossible r \<noteq> None"
proof
  assume "\<exists>why. cl_kernel r = Decline (Impossible why)"
  then obtain why where "cl_kernel r = Decline (Impossible why)" by blast
  from cl_decline_cases[OF this] show "cl_missing r = None \<and> cl_impossible r \<noteq> None" by auto
next
  assume h: "cl_missing r = None \<and> cl_impossible r \<noteq> None"
  then obtain y where "cl_impossible r = Some y" by auto
  then show "\<exists>why. cl_kernel r = Decline (Impossible why)" using h by (auto simp: cl_kernel_def)
qed

text \<open>What each kind means.\<close>
theorem forcing_model:
  assumes "0 < c0" "0 < c"
  shows "exp (sp_phys (Sp_forcing c0 c) / rl forcing_coeff) = rl c / rl c0"
proof -
  have k: "rl forcing_coeff \<noteq> 0" by (simp add: forcing_coeff_def)
  have p: "0 < rl (c / c0)" using assms by (simp add: zero_less_of_rat_iff)
  have "sp_phys (Sp_forcing c0 c) / rl forcing_coeff = ln (rl (c / c0))" using k by (simp add: field_simps)
  then have "exp (sp_phys (Sp_forcing c0 c) / rl forcing_coeff) = rl (c / c0)" using p by simp
  then show ?thesis by (simp add: of_rat_divide)
qed

theorem forcing_doubling:
  assumes "0 < c0"
  shows "sp_phys (Sp_forcing c0 (2 * c0)) = rl forcing_coeff * ln 2"
proof -
  have "c0 \<noteq> 0" using assms by simp
  then have "(2 * c0) / c0 = 2" by simp
  then show ?thesis by simp
qed

theorem warming_ecs_model:
  assumes "0 < c0" "0 < c" "e \<noteq> 0"
  shows "exp (sp_phys (Sp_warming_ecs e c0 c) * ln 2 / rl e) = rl c / rl c0"
proof -
  have e: "rl e \<noteq> 0" using assms(3) by simp
  have p: "0 < rl (c / c0)" using assms by (simp add: zero_less_of_rat_iff)
  have l: "(0::real) < ln 2" by (rule ln_gt_zero) simp
  then have l': "(ln 2::real) \<noteq> 0" by simp
  have "sp_phys (Sp_warming_ecs e c0 c) * ln 2 / rl e = ln (rl (c / c0))" using e l' by (simp add: field_simps)
  then have "exp (sp_phys (Sp_warming_ecs e c0 c) * ln 2 / rl e) = rl (c / c0)" using p by simp
  then show ?thesis by (simp add: of_rat_divide)
qed

theorem warming_ecs_per_doubling:
  assumes "0 < c0"
  shows "sp_phys (Sp_warming_ecs e c0 (2 * c0)) = rl e"
proof -
  have "c0 \<noteq> 0" using assms by simp
  then have "(2 * c0) / c0 = 2" by simp
  then show ?thesis by simp
qed

theorem warming_lambda_model:
  "sp_phys (Sp_warming_lambda l c0 c) = rl l * sp_phys (Sp_forcing c0 c)"
  by simp

theorem effective_temperature_model:
  assumes "0 \<le> s" "0 \<le> a" "a \<le> 1"
  shows "sp_phys (Sp_teff s a) ^ 4 * (4 * rl sigma) = rl s * (1 - rl a)"
proof -
  have sg: "0 < rl sigma" by (simp add: sigma_def zero_less_of_rat_iff)
  have x0: "0 \<le> eff_x s a"
  proof -
    have "0 \<le> s * (1 - a)" using assms by (intro mult_nonneg_nonneg) simp_all
    then show ?thesis by (simp add: eff_x_def sigma_def)
  qed
  then have x1: "0 \<le> rl (eff_x s a)" by (simp add: zero_le_of_rat_iff)
  have "sqrt (sqrt (rl (eff_x s a))) ^ 4 = rl (eff_x s a)"
  proof -
    have h4: "(z::real) ^ 4 = (z ^ 2) ^ 2" for z
    proof -
      have "z ^ 4 = z ^ (2 * 2)" by simp
      also have "\<dots> = (z ^ 2) ^ 2" by (rule power_mult)
      finally show ?thesis .
    qed
    have "sqrt (sqrt (rl (eff_x s a))) ^ 4 = (sqrt (sqrt (rl (eff_x s a))) ^ 2) ^ 2" by (rule h4)
    also have "sqrt (sqrt (rl (eff_x s a))) ^ 2 = sqrt (rl (eff_x s a))" using x1 by simp
    finally show ?thesis using x1 by simp
  qed
  moreover have "rl (eff_x s a) * (4 * rl sigma) = rl s * (1 - rl a)"
    using sg by (simp add: eff_x_def of_rat_mult of_rat_divide of_rat_diff field_simps)
  ultimately show ?thesis by simp
qed

theorem ppm_gtc_model:
  assumes "cl_kernel (Cl_ppm_to_gtc p) = Exact k q"
  shows "k = K_ppm_to_gtc \<and> q * 1000 = p * 2124"
  using cl_exact_sound[OF assms] by (auto simp: gtc_per_ppm_def field_simps)

theorem gtco2_gtc_model:
  "p * gtco2_per_ppm * (12011 / 1000) = p * gtc_per_ppm * (440095 / 10000)"
  by (simp add: gtco2_per_ppm_def gtc_per_ppm_def field_simps)

theorem co2e_model:
  assumes "cl_kernel (Cl_co2e (Some g) m u gs) = Exact k q"
  shows "k = K_co2e \<and> q = m * g"
  using cl_exact_sound[OF assms] by auto

theorem co2e_needs_gwp:
  "cl_kernel (Cl_co2e None m u gs) = Decline (Underspecified N_gwp)"
  by (simp add: cl_kernel_def)

theorem warming_needs_sensitivity:
  "cl_kernel (Cl_warming (Some cc) Sens_none) = Decline (Underspecified N_sens)"
  by (simp add: cl_kernel_def)

theorem albedo_out_of_range:
  assumes "0 \<le> s" "a < 0 \<or> 1 < a"
  shows "cl_kernel (Cl_eff_temp (Some s) (Some a)) = Decline (Impossible R_albedo_range)"
  using assms by (auto simp: cl_kernel_def)

text \<open>The albedo decline is exact: with a non-negative solar constant, the albedo
reason is given precisely when the albedo is outside 0 to 1.\<close>
theorem albedo_decline_iff:
  assumes "0 \<le> s"
  shows "cl_kernel (Cl_eff_temp (Some s) (Some a)) = Decline (Impossible R_albedo_range)
         \<longleftrightarrow> a < 0 \<or> 1 < a"
proof
  assume "a < 0 \<or> 1 < a"
  then show "cl_kernel (Cl_eff_temp (Some s) (Some a)) = Decline (Impossible R_albedo_range)"
    using assms by (auto simp: cl_kernel_def)
next
  assume h: "cl_kernel (Cl_eff_temp (Some s) (Some a)) = Decline (Impossible R_albedo_range)"
  show "a < 0 \<or> 1 < a"
  proof (rule ccontr)
    assume "\<not> (a < 0 \<or> 1 < a)"
    then have "cl_impossible (Cl_eff_temp (Some s) (Some a)) = None" using assms by simp
    then show False using cl_decline_cases[OF h] by simp
  qed
qed


section \<open>Carbon nanomaterials (carbonmat)\<close>

definition lat_a :: rat where "lat_a = 246 / 1000"
definition layer_sp :: rat where "layer_sp = 335 / 1000"

text \<open>Areal mass of single-layer graphene in mg per m2: two carbon atoms of
12.011 g/mol per hexagonal cell of area @{text "(sqrt 3 / 2) a^2"}, a = 0.246 nm,
Avogadro's number 6.02214076e23. It equals @{text "areal_k / sqrt 3"}.\<close>
definition areal_k :: rat where
  "areal_k = (4 * (12011 / 1000) * 1000) / ((602214076 / 1000) * (246 / 1000) ^ 2)"

datatype material_length_unit = Mat_nm | Mat_angstrom | Mat_um
datatype material_area_unit = Mat_m2 | Mat_cm2 | Mat_mm2 | Mat_um2

datatype cmreq =
    Cm_diameter int int
  | Cm_angle int int
  | Cm_type int int
  | Cm_kind int int
  | Cm_layers rat material_length_unit
  | Cm_mass rat material_area_unit
  | Cm_unsupported

fun cm_kind :: "cmreq \<Rightarrow> kind" where
  "cm_kind (Cm_diameter _ _) = K_cnt_diameter"
| "cm_kind (Cm_angle _ _) = K_cnt_angle"
| "cm_kind (Cm_type _ _) = K_cnt_type"
| "cm_kind (Cm_kind _ _) = K_cnt_kind"
| "cm_kind (Cm_layers _ _) = K_graphene_layers"
| "cm_kind (Cm_mass _ _) = K_graphene_mass"
| "cm_kind Cm_unsupported = K_graphene_mass"

text \<open>Chiral indices are (n, m) with n >= m >= 0 and not both zero.\<close>
definition chiral_ok :: "int \<Rightarrow> int \<Rightarrow> bool" where
  "chiral_ok n m \<longleftrightarrow> 0 \<le> m \<and> m \<le> n \<and> \<not> (n = 0 \<and> m = 0)"

fun cm_impossible :: "cmreq \<Rightarrow> reason option" where
  "cm_impossible (Cm_diameter n m) = (if chiral_ok n m then None else Some R_bad_chirality)"
| "cm_impossible (Cm_angle n m) = (if chiral_ok n m then None else Some R_bad_chirality)"
| "cm_impossible (Cm_type n m) = (if chiral_ok n m then None else Some R_bad_chirality)"
| "cm_impossible (Cm_kind n m) = (if chiral_ok n m then None else Some R_bad_chirality)"
| "cm_impossible (Cm_layers t _) = (if t < 0 then Some R_negative_geometry else None)"
| "cm_impossible (Cm_mass a _) = (if a < 0 then Some R_negative_geometry else None)"
| "cm_impossible Cm_unsupported = None"

definition tube_of :: "int \<Rightarrow> int \<Rightarrow> tube" where
  "tube_of n m = (if n = m then T_armchair else if m = 0 then T_zigzag else T_chiral)"

definition circ2 :: "int \<Rightarrow> int \<Rightarrow> int" where "circ2 n m = n * n + n * m + m * m"

text \<open>Input dimensions are finite types. Conversion belongs to the kernel:
length is normalized to nm; physical area is normalized to square metres.\<close>
fun thickness :: "rat \<Rightarrow> material_length_unit \<Rightarrow> rat" where
  "thickness t Mat_nm = t"
| "thickness t Mat_angstrom = t / 10"
| "thickness t Mat_um = t * 1000"
fun area_m2 :: "rat \<Rightarrow> material_area_unit \<Rightarrow> rat" where
  "area_m2 a Mat_m2 = a"
| "area_m2 a Mat_cm2 = a / 10000"
| "area_m2 a Mat_mm2 = a / 1000000"
| "area_m2 a Mat_um2 = a / 1000000000000"
fun side_m :: "material_area_unit \<Rightarrow> rat" where
  "side_m Mat_m2 = 1"
| "side_m Mat_cm2 = 1/100"
| "side_m Mat_mm2 = 1/1000"
| "side_m Mat_um2 = 1/1000000"

fun cm_exact :: "cmreq \<Rightarrow> rat option" where
  "cm_exact (Cm_layers t ang) = Some (thickness t ang / layer_sp)"
| "cm_exact (Cm_diameter _ _) = None"
| "cm_exact (Cm_angle _ _) = None"
| "cm_exact (Cm_type _ _) = None"
| "cm_exact (Cm_kind _ _) = None"
| "cm_exact (Cm_mass _ _) = None"
| "cm_exact Cm_unsupported = None"

fun cm_fa :: "cmreq \<Rightarrow> floatarith" where
  "cm_fa (Cm_diameter n m) = floatarith.Mult (Q lat_a)
      (floatarith.Mult (floatarith.Sqrt (I (circ2 n m))) (floatarith.Inverse floatarith.Pi))"
| "cm_fa (Cm_angle n m) = floatarith.Mult (floatarith.Mult (I 180) (floatarith.Inverse floatarith.Pi))
      (floatarith.Arctan (floatarith.Mult (floatarith.Sqrt (I 3))
         (floatarith.Mult (I m) (floatarith.Inverse (I (2 * n + m))))))"
| "cm_fa (Cm_mass a cm2) = floatarith.Mult (Q (area_m2 a cm2))
      (floatarith.Mult (Q areal_k) (floatarith.Inverse (floatarith.Sqrt (I 3))))"
| "cm_fa (Cm_type _ _) = I 0"
| "cm_fa (Cm_kind _ _) = I 0"
| "cm_fa (Cm_layers _ _) = I 0"
| "cm_fa Cm_unsupported = I 0"

fun cm_phys :: "cmreq \<Rightarrow> real" where
  "cm_phys (Cm_diameter n m) = rl lat_a * (sqrt (of_int (circ2 n m)) * inverse pi)"
| "cm_phys (Cm_angle n m) = of_int 180 * inverse pi *
      arctan (sqrt (of_int 3) * (of_int m * inverse (of_int (2 * n + m))))"
| "cm_phys (Cm_mass a cm2) = rl (area_m2 a cm2) * (rl areal_k * inverse (sqrt (of_int 3)))"
| "cm_phys (Cm_layers t ang) = rl (thickness t ang / layer_sp)"
| "cm_phys (Cm_type _ _) = 0"
| "cm_phys (Cm_kind _ _) = 0"
| "cm_phys Cm_unsupported = 0"

lemma cm_fa_interp:
  "cm_exact r = None \<Longrightarrow> interpret_floatarith (cm_fa r) [] = cm_phys r"
  by (cases r) simp_all

lemma cm_exact_phys: "cm_exact r = Some q \<Longrightarrow> cm_phys r = rl q"
  by (cases r) simp_all


fun cm_small :: "cmreq \<Rightarrow> bool" where
  "cm_small (Cm_mass a u) = (0 < area_m2 a u \<and> area_m2 a u < 1/100)"
| "cm_small _ = False"

definition cm_finish :: "cmreq \<Rightarrow> outcome" where
  "cm_finish r = (if cm_small r then
    (case enclose_small (cm_fa r) of None \<Rightarrow> Decline Imprecise
     | Some d \<Rightarrow> Approx (cm_kind r) d)
   else spec_out 4 (cm_kind r) (cm_exact r) (cm_fa r))"

lemma cm_finish_exact:
  "cm_finish r = Exact k q \<Longrightarrow> cm_exact r = Some q \<and> k=cm_kind r"
  by (auto simp: cm_finish_def split: if_splits option.splits dest: spec_out_exact)

lemma cm_finish_approx:
  assumes "cm_finish r = Approx k d"
  shows "cm_exact r=None \<and> k=cm_kind r \<and>
    \<bar>dec_val d-interpret_floatarith (cm_fa r) []\<bar> \<le> pow10 (snd d)/2+1/1000000000"
  using assms by (cases r) (auto simp: cm_finish_def split: if_splits option.splits
    dest: spec_out_approx enclose_small_sound)

lemma cm_finish_decline:
  "cm_finish r = Decline w \<Longrightarrow> w=Imprecise"
  by (auto simp: cm_finish_def split: if_splits option.splits dest: spec_out_decline)

lemma cm_finish_not_verdict [simp]: "cm_finish r \<noteq> Verdict k b"
  by (auto simp: cm_finish_def split: if_splits option.splits)

definition cm_kernel :: "cmreq \<Rightarrow> outcome" where
  "cm_kernel r = (case cm_impossible r of Some w \<Rightarrow> Decline (Impossible w)
     | None \<Rightarrow> (case r of
          Cm_unsupported \<Rightarrow> Decline (Underspecified N_material_geometry)
        | Cm_type n m \<Rightarrow> Verdict K_cnt_type ((n - m) mod 3 = 0)
        | Cm_kind n m \<Rightarrow> Tube_kind (tube_of n m)
        | _ \<Rightarrow> cm_finish r))"

theorem cm_exact_sound:
  assumes "cm_kernel r = Exact k q"
  shows "cm_impossible r = None \<and> k = cm_kind r \<and> cm_exact r = Some q \<and> cm_phys r = rl q"
proof -
  have i: "cm_impossible r = None" using assms by (auto simp: cm_kernel_def split: option.splits)
  have "cm_finish r = Exact k q"
    using assms i by (cases r) (auto simp: cm_kernel_def)
  from cm_finish_exact[OF this] have e: "cm_exact r = Some q" "k = cm_kind r" by simp_all
  show ?thesis using i e cm_exact_phys by blast
qed

theorem cm_approx_sound:
  assumes "cm_kernel r = Approx k d"
  shows "cm_impossible r = None \<and> k = cm_kind r \<and> cm_exact r = None \<and>
         \<bar>dec_val d - cm_phys r\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
proof -
  have i: "cm_impossible r = None" using assms by (auto simp: cm_kernel_def split: option.splits)
  have "cm_finish r = Approx k d"
    using assms i by (cases r) (auto simp: cm_kernel_def)
  from cm_finish_approx[OF this] have
    s: "cm_exact r = None" "k = cm_kind r"
    and b: "\<bar>dec_val d - interpret_floatarith (cm_fa r) []\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
    by simp_all
  have "interpret_floatarith (cm_fa r) [] = cm_phys r" using cm_fa_interp[OF s(1)] .
  then show ?thesis using i s b by auto
qed

theorem cm_impossible_iff:
  "(\<exists>why. cm_kernel r = Decline (Impossible why)) \<longleftrightarrow> cm_impossible r \<noteq> None"
proof
  assume "\<exists>why. cm_kernel r = Decline (Impossible why)"
  then obtain why where h: "cm_kernel r = Decline (Impossible why)" by blast
  show "cm_impossible r \<noteq> None"
  proof
    assume n: "cm_impossible r = None"
    show False using h n by (cases r) (auto simp: cm_kernel_def dest: cm_finish_decline)
  qed
next
  assume "cm_impossible r \<noteq> None"
  then show "\<exists>why. cm_kernel r = Decline (Impossible why)" by (auto simp: cm_kernel_def)
qed

theorem cnt_chirality_declined:
  "\<not> chiral_ok n m \<Longrightarrow> cm_kernel (Cm_diameter n m) = Decline (Impossible R_bad_chirality)"
  "\<not> chiral_ok n m \<Longrightarrow> cm_kernel (Cm_angle n m) = Decline (Impossible R_bad_chirality)"
  "\<not> chiral_ok n m \<Longrightarrow> cm_kernel (Cm_type n m) = Decline (Impossible R_bad_chirality)"
  "\<not> chiral_ok n m \<Longrightarrow> cm_kernel (Cm_kind n m) = Decline (Impossible R_bad_chirality)"
  by (simp_all add: cm_kernel_def cm_finish_def)

text \<open>What each kind means. The circumference of the rolled sheet is the
chiral vector's length, a sqrt(n^2 + nm + m^2), and equals pi times the
diameter; the chiral angle's tangent is sqrt 3 m / (2n + m); a tube is
metallic exactly when n - m is divisible by 3; armchair is n = m and zigzag
m = 0; layers times the interlayer spacing is the thickness; the mass of the
area times the cell area gives the two carbon atoms' mass.\<close>
theorem cnt_circumference:
  "pi * cm_phys (Cm_diameter n m) = rl lat_a * sqrt (of_int (circ2 n m))"
  using pi_neq_zero by (simp add: field_simps)

theorem cnt_chiral_angle_tangent:
  assumes "2 * n + m \<noteq> 0"
  shows "tan (cm_phys (Cm_angle n m) * pi / 180) = sqrt 3 * (of_int m / of_int (2 * n + m))"
proof -
  have p: "pi \<noteq> 0" by (rule pi_neq_zero)
  define A where "A = arctan (sqrt 3 * (of_int m / of_int (2 * n + m)))"
  have e: "cm_phys (Cm_angle n m) = 180 / pi * A" by (simp add: A_def divide_inverse)
  have "180 / pi * A * pi / 180 = A" using p by (simp add: field_simps)
  then show ?thesis unfolding e A_def by (simp add: tan_arctan)
qed

theorem cnt_type_metallic:
  assumes "cm_kernel (Cm_type n m) = Verdict k v"
  shows "chiral_ok n m \<and> (v \<longleftrightarrow> (\<exists>j. n - m = 3 * j))"
proof -
  have c: "chiral_ok n m" "v = ((n - m) mod 3 = 0)"
    using assms by (auto simp: cm_kernel_def split: if_splits)
  have "((n - m) mod 3 = 0) \<longleftrightarrow> (\<exists>j. n - m = 3 * j)" by (auto simp: dvd_def mod_eq_0_iff_dvd)
  then show ?thesis using c by simp
qed

theorem cnt_kind_classes:
  assumes "cm_kernel (Cm_kind n m) = Tube_kind t"
  shows "chiral_ok n m \<and> (t = T_armchair \<longleftrightarrow> n = m) \<and> (t = T_zigzag \<longleftrightarrow> m = 0 \<and> n \<noteq> m)"
proof -
  have c: "chiral_ok n m" "t = tube_of n m" using assms by (auto simp: cm_kernel_def split: if_splits)
  then show ?thesis by (auto simp: tube_of_def)
qed

theorem graphene_layers_model:
  assumes "cm_kernel (Cm_layers t ang) = Exact k q"
  shows "k = K_graphene_layers \<and> q * layer_sp = thickness t ang"
proof -
  have s: "k = K_graphene_layers" "q = thickness t ang / layer_sp"
    using cm_exact_sound[OF assms] by auto
  have "q * layer_sp = thickness t ang" using s(2) by (simp add: layer_sp_def field_simps)
  then show ?thesis using s(1) by simp
qed

lemma areal_rat: "areal_k * lat_a ^ 2 / 2 / 10 ^ 18 = 2 * (12011 / 1000) * 1000 / (602214076 * 10 ^ 15)"
  by (unfold areal_k_def lat_a_def) (simp add: field_simps)

theorem graphene_areal_mass:
  "(rl areal_k / sqrt 3) * (sqrt 3 / 2 * rl lat_a ^ 2 / 10 ^ 18) =
   rl (2 * (12011 / 1000) * 1000 / (602214076 * 10 ^ 15))"
proof -
  have s3: "sqrt (3::real) \<noteq> 0" by simp
  have "(rl areal_k / sqrt 3) * (sqrt 3 / 2 * rl lat_a ^ 2 / 10 ^ 18) = rl areal_k * rl lat_a ^ 2 / 2 / 10 ^ 18"
    using s3 by (simp add: field_simps)
  also have "\<dots> = rl (areal_k * lat_a ^ 2 / 2 / 10 ^ 18)" by (simp add: of_rat_mult of_rat_divide of_rat_power)
  also have "\<dots> = rl (2 * (12011 / 1000) * 1000 / (602214076 * 10 ^ 15))" by (simp only: areal_rat)
  finally show ?thesis .
qed

theorem graphene_mass_is_area_times_areal:
  "cm_phys (Cm_mass a cm2) = rl (area_m2 a cm2) * (rl areal_k / sqrt 3)"
  by (simp add: divide_inverse)


theorem graphene_unsupported_model:
  "cm_kernel Cm_unsupported = Decline (Underspecified N_material_geometry)"
  by (simp add: cm_kernel_def cm_finish_def)

theorem graphene_layers_decline:
  "(\<exists>w. cm_kernel (Cm_layers t u) = Decline (Impossible w)) \<longleftrightarrow> t < 0"
  by (simp add: cm_impossible_iff)

theorem graphene_mass_decline:
  "(\<exists>w. cm_kernel (Cm_mass a u) = Decline (Impossible w)) \<longleftrightarrow> a < 0"
  by (simp add: cm_impossible_iff)

theorem graphene_layers_feasible_model:
  assumes k: "cm_kernel (Cm_layers t u) = Exact kind q"
  shows "0 \<le> t \<and> 0 \<le> q \<and> q * layer_sp = thickness t u"
proof -
  have t0: "0 \<le> t" using cm_exact_sound[OF k] by (auto split: if_splits)
  have eq: "q * layer_sp = thickness t u" using graphene_layers_model[OF k] by simp
  have th0: "0 \<le> thickness t u" using t0 by (cases u) simp_all
  have q0: "0 \<le> q" using eq th0 by (simp add: layer_sp_def; linarith)
  show ?thesis using t0 q0 eq by simp
qed

theorem graphene_mass_nonnegative:
  assumes k: "cm_kernel (Cm_mass a u) = Approx kind d"
  shows "0 \<le> a \<and> 0 \<le> cm_phys (Cm_mass a u)"
proof -
  have a0: "0 \<le> a" using cm_approx_sound[OF k] by (auto split: if_splits)
  have area0: "0 \<le> rl (area_m2 a u)"
    using a0 by (cases u) (simp_all add: zero_le_of_rat_iff)
  have coefficient0: "0 \<le> rl areal_k * inverse (sqrt (3::real))"
    by (intro mult_nonneg_nonneg) (simp_all add: areal_k_def)
  have physical0: "0 \<le> cm_phys (Cm_mass a u)"
    using mult_nonneg_nonneg[OF area0 coefficient0] by simp
  show ?thesis using a0 physical0 by blast
qed

theorem graphene_squared_area_units:
  "area_m2 a u = a * (side_m u)^2"
  by (cases u) (simp_all add: power2_eq_square field_simps)

theorem graphene_area_unit_answers:
  "cm_kernel (Cm_mass (a*10000) Mat_cm2) = cm_kernel (Cm_mass a Mat_m2)"
  "cm_kernel (Cm_mass (a*1000000) Mat_mm2) = cm_kernel (Cm_mass a Mat_m2)"
  "cm_kernel (Cm_mass (a*1000000000000) Mat_um2) = cm_kernel (Cm_mass a Mat_m2)"
  by (auto simp: cm_kernel_def cm_finish_def mult_less_0_iff split: if_splits option.splits)

theorem graphene_length_unit_answers:
  "cm_kernel (Cm_layers (t*10) Mat_angstrom) = cm_kernel (Cm_layers t Mat_nm)"
  "cm_kernel (Cm_layers t Mat_um) = cm_kernel (Cm_layers (t*1000) Mat_nm)"
  by (auto simp: cm_kernel_def cm_finish_def mult_less_0_iff split: if_splits option.splits)

lemma graphene_mass_additive_model:
  "cm_phys (Cm_mass (a+b) u) = cm_phys (Cm_mass a u) + cm_phys (Cm_mass b u)"
  by (cases u) (simp_all add: of_rat_add of_rat_divide algebra_simps)

theorem graphene_mass_sum_rendered_bound:
  assumes a: "cm_kernel (Cm_mass x u) = Approx kx dx"
    and b: "cm_kernel (Cm_mass y u) = Approx ky dy"
    and c: "cm_kernel (Cm_mass (x+y) u) = Approx kz dz"
  shows "\<bar>dec_val dz - (dec_val dx + dec_val dy)\<bar> \<le>
    pow10 (snd dx)/2 + pow10 (snd dy)/2 + pow10 (snd dz)/2 + 3/1000000000"
  using cm_approx_sound[OF a] cm_approx_sound[OF b] cm_approx_sound[OF c]
    graphene_mass_additive_model[of x y u]
  by (auto simp only: abs_le_iff; linarith)


theorem graphene_small_mass_relative:
  assumes area: "0 < area_m2 a u" "area_m2 a u < 1/100"
    and k: "cm_kernel (Cm_mass a u) = Approx kind d"
  shows "0 < dec_val d \<and> 0 < cm_phys (Cm_mass a u) \<and>
    \<bar>dec_val d-cm_phys (Cm_mass a u)\<bar> \<le> cm_phys (Cm_mass a u)/1000"
proof -
  have "enclose_small (cm_fa (Cm_mass a u)) = Some d"
    using k area by (auto simp: cm_kernel_def cm_finish_def split: if_splits option.splits)
  from enclose_small_sound[OF this] show ?thesis by simp
qed

section \<open>Food-safety temperatures and times (coldchain, coldchain-v2)\<close>

datatype temp = Temp rat bool
datatype dur = Dur rat bool
datatype cookclass = Cook_poultry | Cook_ground | Cook_whole

datatype cooling_observation = First_elapsed | Total_elapsed | Second_elapsed
datatype cooling_scope = Whole_schedule | Checkpoint_only

datatype cdreq =
    Cd_cool temp temp dur
  | Cd_schedule temp temp temp dur dur
  | Cd_schedule_unknown
  | Cd_partial temp temp dur cooling_scope
  | Cd_cold temp
  | Cd_hot temp
  | Cd_cook cookclass
  | Cd_reheat
  | Cd_tphc "rat option"
  | Cd_date "weekday option"
  | Cd_danger

text \<open>A temperature as degrees Fahrenheit (the flag says it was given in Celsius),
a duration in hours (the flag says it was given in minutes).\<close>
fun f_of :: "temp \<Rightarrow> rat" where "f_of (Temp v c) = (if c then v * 9 / 5 + 32 else v)"
fun hours :: "dur \<Rightarrow> rat" where "hours (Dur v mins) = (if mins then v / 60 else v)"

text \<open>FDA Food Code 3-501.14(A): cool from 135 F to 70 F within 2 hours, then to
41 F within 4 more (6 in all). A reading is a stage if its endpoints are within
half a degree of the stage's (the organ's tolerance), and nothing else is judged.\<close>
definition cool_limit :: "rat \<Rightarrow> rat \<Rightarrow> rat option" where
  "cool_limit a b = (if 269 / 2 \<le> a \<and> \<bar>b - 70\<bar> \<le> 1 / 2 then Some 2
     else if \<bar>a - 70\<bar> \<le> 1 / 2 \<and> b \<le> 83 / 2 then Some 4
     else if 269 / 2 \<le> a \<and> b \<le> 83 / 2 then Some 6 else None)"

text \<open>A complete two-stage schedule records incremental durations. The independent
clock model uses the first checkpoint deadline and the total elapsed deadline:
FDA Food Code 2022, 3-501.14(A)(1)-(2), https://www.fda.gov/media/164194/download.
It does not assume that the second stage always consumes exactly four hours.\<close>
definition cooling_deadlines :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "cooling_deadlines t_first t_total \<longleftrightarrow>
    0 \<le> t_first \<and> t_first \<le> 2 \<and> t_first \<le> t_total \<and> t_total \<le> 6"

text \<open>Use the published nominal threshold pairs in the supplied temperature
unit: 57 C / 135 F, 21 C / 70 F, and 5 C / 41 F. The Celsius labels are not
obtained by rounding an exact Fahrenheit conversion. No endpoint tolerance is
allowed in a complete schedule.\<close>
fun schedule_start :: "temp \<Rightarrow> bool" where
  "schedule_start (Temp v celsius) = (if celsius then 57 \<le> v else 135 \<le> v)"
fun schedule_middle :: "temp \<Rightarrow> bool" where
  "schedule_middle (Temp v celsius) = (if celsius then v \<le> 21 else v \<le> 70)"
fun schedule_final :: "temp \<Rightarrow> bool" where
  "schedule_final (Temp v celsius) = (if celsius then v \<le> 5 else v \<le> 41)"

definition schedule_endpoints :: "temp \<Rightarrow> temp \<Rightarrow> temp \<Rightarrow> bool" where
  "schedule_endpoints a b c \<longleftrightarrow>
    schedule_start a \<and> schedule_middle b \<and> schedule_final c"


text \<open>A partial record fixes one elapsed clock. A compatible full record
has a nonnegative first-checkpoint time no later than its final-checkpoint time.
These are times of reaching the nominal checkpoints, not arbitrary later sensor
readings. Quantifying over all compatible clocks avoids inventing the missing
first stage or final stage.\<close>
fun compatible_cooling :: "cooling_observation \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> bool" where
  "compatible_cooling First_elapsed h t_first t_total =
    (0 \<le> t_first \<and> t_first \<le> t_total \<and> t_first = h)"
| "compatible_cooling Total_elapsed h t_first t_total =
    (0 \<le> t_first \<and> t_first \<le> t_total \<and> t_total = h)"
| "compatible_cooling Second_elapsed h t_first t_total =
    (0 \<le> t_first \<and> t_first \<le> t_total \<and> t_total - t_first = h)"

fun partial_pass_possible :: "cooling_observation \<Rightarrow> rat \<Rightarrow> bool" where
  "partial_pass_possible First_elapsed h = (h \<le> 2)"
| "partial_pass_possible Total_elapsed h = (h \<le> 6)"
| "partial_pass_possible Second_elapsed h = (h \<le> 6)"

fun partial_fail_possible :: "cooling_observation \<Rightarrow> rat \<Rightarrow> bool" where
  "partial_fail_possible First_elapsed h = True"
| "partial_fail_possible Total_elapsed h = (2 < h)"
| "partial_fail_possible Second_elapsed h = True"

lemma compatible_cooling_exists:
  assumes "0 \<le> h"
  shows "\<exists>t_first t_total. compatible_cooling obs h t_first t_total"
proof (cases obs)
  case First_elapsed
  show ?thesis unfolding First_elapsed
    by (rule exI[of _ h], rule exI[of _ h]) (simp add: assms)
next
  case Total_elapsed
  show ?thesis unfolding Total_elapsed
    by (rule exI[of _ 0], rule exI[of _ h]) (simp add: assms)
next
  case Second_elapsed
  show ?thesis unfolding Second_elapsed
    by (rule exI[of _ 0], rule exI[of _ h]) (simp add: assms)
qed

lemma compatible_cooling_pass:
  assumes "0 \<le> h"
  shows "(\<exists>t_first t_total. compatible_cooling obs h t_first t_total \<and>
    cooling_deadlines t_first t_total) \<longleftrightarrow> partial_pass_possible obs h"
proof (cases obs)
  case First_elapsed
  show ?thesis unfolding First_elapsed
  proof
    assume "\<exists>t_first t_total. compatible_cooling First_elapsed h t_first t_total \<and> cooling_deadlines t_first t_total"
    then show "partial_pass_possible First_elapsed h" by (auto simp: cooling_deadlines_def)
  next
    assume "partial_pass_possible First_elapsed h"
    then show "\<exists>t_first t_total. compatible_cooling First_elapsed h t_first t_total \<and> cooling_deadlines t_first t_total"
      using assms by (intro exI[of _ h] exI[of _ h]) (simp add: cooling_deadlines_def)
  qed
next
  case Total_elapsed
  show ?thesis unfolding Total_elapsed
  proof
    assume "\<exists>t_first t_total. compatible_cooling Total_elapsed h t_first t_total \<and> cooling_deadlines t_first t_total"
    then show "partial_pass_possible Total_elapsed h" by (auto simp: cooling_deadlines_def)
  next
    assume "partial_pass_possible Total_elapsed h"
    then show "\<exists>t_first t_total. compatible_cooling Total_elapsed h t_first t_total \<and> cooling_deadlines t_first t_total"
      using assms by (intro exI[of _ 0] exI[of _ h]) (simp add: cooling_deadlines_def)
  qed
next
  case Second_elapsed
  show ?thesis unfolding Second_elapsed
  proof
    assume "\<exists>t_first t_total. compatible_cooling Second_elapsed h t_first t_total \<and> cooling_deadlines t_first t_total"
    then show "partial_pass_possible Second_elapsed h" by (auto simp: cooling_deadlines_def; linarith)
  next
    assume "partial_pass_possible Second_elapsed h"
    then show "\<exists>t_first t_total. compatible_cooling Second_elapsed h t_first t_total \<and> cooling_deadlines t_first t_total"
      using assms by (intro exI[of _ 0] exI[of _ h]) (simp add: cooling_deadlines_def)
  qed
qed

lemma compatible_cooling_fail:
  assumes "0 \<le> h"
  shows "(\<exists>t_first t_total. compatible_cooling obs h t_first t_total \<and>
    \<not> cooling_deadlines t_first t_total) \<longleftrightarrow> partial_fail_possible obs h"
proof (cases obs)
  case First_elapsed
  have "compatible_cooling First_elapsed h h (h+7) \<and> \<not> cooling_deadlines h (h+7)"
    using assms by (auto simp: cooling_deadlines_def; linarith)
  then have "\<exists>f t. compatible_cooling First_elapsed h f t \<and> \<not> cooling_deadlines f t"
    by (intro exI[of _ h] exI[of _ "h+7"])
  then show ?thesis unfolding First_elapsed by simp
next
  case Total_elapsed
  show ?thesis unfolding Total_elapsed
  proof
    assume "\<exists>t_first t_total. compatible_cooling Total_elapsed h t_first t_total \<and> \<not> cooling_deadlines t_first t_total"
    then show "partial_fail_possible Total_elapsed h" by (auto simp: cooling_deadlines_def; linarith)
  next
    assume "partial_fail_possible Total_elapsed h"
    then show "\<exists>t_first t_total. compatible_cooling Total_elapsed h t_first t_total \<and> \<not> cooling_deadlines t_first t_total"
      using assms by (intro exI[of _ h] exI[of _ h]) (simp add: cooling_deadlines_def)
  qed
next
  case Second_elapsed
  have "compatible_cooling Second_elapsed h 3 (3+h) \<and> \<not> cooling_deadlines 3 (3+h)"
    using assms by (simp add: cooling_deadlines_def)
  then have "\<exists>f t. compatible_cooling Second_elapsed h f t \<and> \<not> cooling_deadlines f t"
    by (intro exI[of _ 3] exI[of _ "3+h"])
  then show ?thesis unfolding Second_elapsed by simp
qed

fun nominal_start :: "temp \<Rightarrow> bool" where
  "nominal_start (Temp v c) = (v = (if c then 57 else 135))"
fun nominal_middle :: "temp \<Rightarrow> bool" where
  "nominal_middle (Temp v c) = (v = (if c then 21 else 70))"
fun nominal_final :: "temp \<Rightarrow> bool" where
  "nominal_final (Temp v c) = (v = (if c then 5 else 41))"

definition partial_observation :: "temp \<Rightarrow> temp \<Rightarrow> cooling_observation option" where
  "partial_observation a b =
    (if nominal_start a \<and> nominal_middle b then Some First_elapsed
     else if nominal_start a \<and> nominal_final b then Some Total_elapsed
     else if nominal_middle a \<and> nominal_final b then Some Second_elapsed
     else None)"

text \<open>Whole-schedule verdicts quantify over the missing clock. Explicit
checkpoint-only questions test just the named first or total deadline. There is
no independent fixed four-hour second-stage deadline without an earlier clock.\<close>
definition partial_clock_kernel :: "cooling_observation \<Rightarrow> rat \<Rightarrow> cooling_scope \<Rightarrow> outcome" where
  "partial_clock_kernel obs h scope =
    (if h < 0 then Decline (Impossible R_negative_duration)
     else if scope = Checkpoint_only then
       (case obs of First_elapsed \<Rightarrow> Verdict K_cooling_check (h \<le> 2)
        | Total_elapsed \<Rightarrow> Verdict K_cooling_check (h \<le> 6)
        | Second_elapsed \<Rightarrow> Decline (Underspecified N_partial_cooling))
     else if \<not> partial_pass_possible obs h then Verdict K_cooling_check False
     else if \<not> partial_fail_possible obs h then Verdict K_cooling_check True
     else Decline (Underspecified N_partial_cooling))"

theorem partial_clock_true:
  assumes "0 \<le> h"
  shows "partial_clock_kernel obs h Whole_schedule = Verdict K_cooling_check True \<longleftrightarrow>
    (\<forall>t_first t_total. compatible_cooling obs h t_first t_total \<longrightarrow> cooling_deadlines t_first t_total)"
  using assms compatible_cooling_exists[OF assms, of obs]
    compatible_cooling_pass[OF assms, of obs] compatible_cooling_fail[OF assms, of obs]
  by (auto simp: partial_clock_kernel_def; linarith)

theorem partial_clock_false:
  assumes "0 \<le> h"
  shows "partial_clock_kernel obs h Whole_schedule = Verdict K_cooling_check False \<longleftrightarrow>
    (\<forall>t_first t_total. compatible_cooling obs h t_first t_total \<longrightarrow> \<not> cooling_deadlines t_first t_total)"
  using assms compatible_cooling_pass[OF assms, of obs]
  by (auto simp: partial_clock_kernel_def; linarith)

theorem partial_clock_unknown:
  assumes "0 \<le> h"
  shows "partial_clock_kernel obs h Whole_schedule = Decline (Underspecified N_partial_cooling) \<longleftrightarrow>
    (\<exists>f t. compatible_cooling obs h f t \<and> cooling_deadlines f t) \<and>
    (\<exists>f t. compatible_cooling obs h f t \<and> \<not> cooling_deadlines f t)"
  using assms compatible_cooling_pass[OF assms, of obs] compatible_cooling_fail[OF assms, of obs]
  by (auto simp: partial_clock_kernel_def; linarith)

theorem partial_clock_negative:
  "partial_clock_kernel obs h scope = Decline (Impossible R_negative_duration) \<longleftrightarrow> h < 0"
  by (auto simp: partial_clock_kernel_def split: cooling_observation.splits)

theorem partial_checkpoint_scope:
  assumes "0 \<le> h"
  shows "partial_clock_kernel First_elapsed h Checkpoint_only = Verdict K_cooling_check (h \<le> 2)"
    and "partial_clock_kernel Total_elapsed h Checkpoint_only = Verdict K_cooling_check (h \<le> 6)"
  using assms by (simp_all add: partial_clock_kernel_def)

fun cook_f :: "cookclass \<Rightarrow> rat" where
  "cook_f Cook_poultry = 165" | "cook_f Cook_ground = 155" | "cook_f Cook_whole = 145"

fun last_day :: "weekday \<Rightarrow> weekday" where
  "last_day Monday = Sunday" | "last_day Tuesday = Monday" | "last_day Wednesday = Tuesday"
| "last_day Thursday = Wednesday" | "last_day Friday = Thursday" | "last_day Saturday = Friday"
| "last_day Sunday = Saturday"

fun wd_idx :: "weekday \<Rightarrow> nat" where
  "wd_idx Monday = 0" | "wd_idx Tuesday = 1" | "wd_idx Wednesday = 2" | "wd_idx Thursday = 3"
| "wd_idx Friday = 4" | "wd_idx Saturday = 5" | "wd_idx Sunday = 6"

definition cd_kernel :: "cdreq \<Rightarrow> outcome" where
  "cd_kernel r = (case r of
      Cd_cool a b d \<Rightarrow> (if hours d < 0 then Decline (Impossible R_negative_duration)
        else case cool_limit (f_of a) (f_of b) of None \<Rightarrow> Decline Not_taken
                        | Some lm \<Rightarrow> Verdict K_cooling_check (hours d \<le> lm))
    | Cd_schedule a b c d e \<Rightarrow>
        (if hours d < 0 \<or> hours e < 0 then Decline (Impossible R_negative_duration)
         else if \<not> schedule_start a then Decline (Underspecified N_cooling_schedule)
         else Verdict K_cooling_check (schedule_middle b \<and> schedule_final c \<and> hours d \<le> 2 \<and> hours d + hours e \<le> 6))
    | Cd_partial a b d scope \<Rightarrow>
        (if hours d < 0 then Decline (Impossible R_negative_duration)
         else case partial_observation a b of None \<Rightarrow> Decline (Underspecified N_partial_cooling)
           | Some obs \<Rightarrow> partial_clock_kernel obs (hours d) scope)
    | Cd_schedule_unknown \<Rightarrow> Decline (Underspecified N_cooling_schedule)
    | Cd_cold t \<Rightarrow> Verdict K_cold_hold (f_of t \<le> 41)
    | Cd_hot t \<Rightarrow> Verdict K_hot_hold (135 \<le> f_of t)
    | Cd_cook c \<Rightarrow> Exact K_cook_temp (cook_f c)
    | Cd_reheat \<Rightarrow> Exact K_reheat 165
    | Cd_tphc None \<Rightarrow> Exact K_tphc_rule 4
    | Cd_tphc (Some h) \<Rightarrow> (if h < 0 then Decline (Impossible R_negative_duration)
                                    else Verdict K_tphc (h \<le> 4))
    | Cd_date None \<Rightarrow> Exact K_date_rule 7
    | Cd_date (Some d) \<Rightarrow> Weekday (last_day d)
    | Cd_danger \<Rightarrow> Interval K_danger_zone 41 135)"


theorem partial_cooling_whole_binding:
  assumes "partial_observation a b = Some obs" "0 \<le> hours d"
  shows "cd_kernel (Cd_partial a b d Whole_schedule) = partial_clock_kernel obs (hours d) Whole_schedule"
  using assms by (simp add: cd_kernel_def)


theorem partial_cooling_true:
  assumes "partial_observation a b = Some obs" "0 \<le> hours d"
  shows "cd_kernel (Cd_partial a b d Whole_schedule) = Verdict K_cooling_check True \<longleftrightarrow>
    (\<forall>f t. compatible_cooling obs (hours d) f t \<longrightarrow> cooling_deadlines f t)"
  using partial_cooling_whole_binding[OF assms] partial_clock_true[OF assms(2), of obs] by simp

theorem partial_cooling_false:
  assumes "partial_observation a b = Some obs" "0 \<le> hours d"
  shows "cd_kernel (Cd_partial a b d Whole_schedule) = Verdict K_cooling_check False \<longleftrightarrow>
    (\<forall>f t. compatible_cooling obs (hours d) f t \<longrightarrow> \<not> cooling_deadlines f t)"
  using partial_cooling_whole_binding[OF assms] partial_clock_false[OF assms(2), of obs] by simp

theorem partial_cooling_unknown:
  assumes "partial_observation a b = Some obs" "0 \<le> hours d"
  shows "cd_kernel (Cd_partial a b d Whole_schedule) = Decline (Underspecified N_partial_cooling) \<longleftrightarrow>
    (\<exists>f t. compatible_cooling obs (hours d) f t \<and> cooling_deadlines f t) \<and>
    (\<exists>f t. compatible_cooling obs (hours d) f t \<and> \<not> cooling_deadlines f t)"
  using partial_cooling_whole_binding[OF assms] partial_clock_unknown[OF assms(2), of obs] by simp

theorem partial_cooling_negative:
  "cd_kernel (Cd_partial a b d scope) = Decline (Impossible R_negative_duration) \<longleftrightarrow> hours d < 0"
  by (auto simp: cd_kernel_def partial_clock_negative split: option.splits)

theorem cooling_verdict:
  assumes "cd_kernel (Cd_cool a b d) = Verdict k ok"
  shows "k = K_cooling_check \<and> 0 \<le> hours d \<and> (\<exists>lm. cool_limit (f_of a) (f_of b) = Some lm \<and> (ok \<longleftrightarrow> hours d \<le> lm))"
  using assms by (auto simp: cd_kernel_def split: option.splits if_splits)

theorem cooling_not_a_stage:
  "cd_kernel (Cd_cool a b d) = Decline Not_taken \<longleftrightarrow>
    0 \<le> hours d \<and> cool_limit (f_of a) (f_of b) = None"
  by (auto simp: cd_kernel_def split: option.splits if_splits)

theorem cooling_negative_time:
  "cd_kernel (Cd_cool a b d) = Decline (Impossible R_negative_duration) \<longleftrightarrow> hours d < 0"
  by (auto simp: cd_kernel_def split: option.splits if_splits)

theorem cooling_pass_elapsed_bound:
  assumes "cd_kernel (Cd_cool a b d) = Verdict k True"
  shows "0 \<le> hours d \<and> hours d \<le> 6"
  using cooling_verdict[OF assms]
  by (auto simp: cool_limit_def split: if_splits; linarith)

theorem cooling_schedule_clock_law:
  "cd_kernel (Cd_schedule a b c d e) = Verdict K_cooling_check True \<longleftrightarrow>
    schedule_endpoints a b c \<and> cooling_deadlines (hours d) (hours d + hours e)"
  by (auto simp: cd_kernel_def cooling_deadlines_def schedule_endpoints_def; linarith)

theorem cooling_schedule_negative_time:
  "cd_kernel (Cd_schedule a b c d e) = Decline (Impossible R_negative_duration) \<longleftrightarrow>
    hours d < 0 \<or> hours e < 0"
  by (auto simp: cd_kernel_def)

theorem cooling_schedule_shorter:
  assumes "cd_kernel (Cd_schedule a b c d e) = Verdict K_cooling_check True"
    "0 \<le> hours d'" "hours d' \<le> hours d"
    "0 \<le> hours e'" "hours e' \<le> hours e"
  shows "cd_kernel (Cd_schedule a b c d' e') = Verdict K_cooling_check True"
  using assms by (auto simp: cooling_schedule_clock_law cooling_deadlines_def; linarith)

theorem cooling_schedule_temperature_bounds:
  assumes "cd_kernel (Cd_schedule (Temp a ua) (Temp b ub) (Temp c uc) d e) = Verdict K_cooling_check True"
  shows "(if ua then 57 else 135) \<le> a \<and>
    b \<le> (if ub then 21 else 70) \<and> c \<le> (if uc then 5 else 41)"
  using assms by (auto simp: cooling_schedule_clock_law schedule_endpoints_def split: if_splits)

theorem cooling_schedule_above_limit:
  assumes "schedule_start a" "0 \<le> hours d" "0 \<le> hours e"
    "\<not> schedule_middle b \<or> \<not> schedule_final c"
  shows "cd_kernel (Cd_schedule a b c d e) = Verdict K_cooling_check False"
  using assms by (auto simp: cd_kernel_def)

theorem cooling_schedule_nominal_units:
  "schedule_endpoints (Temp 135 False) (Temp 70 False) (Temp 41 False)"
  "schedule_endpoints (Temp 57 True) (Temp 21 True) (Temp 5 True)"
  by (simp_all add: schedule_endpoints_def)

theorem cooling_schedule_missing:
  "cd_kernel Cd_schedule_unknown = Decline (Underspecified N_cooling_schedule)"
  by (simp add: cd_kernel_def)

theorem cool_stage1:
  assumes "269 / 2 \<le> a" "\<bar>b - 70\<bar> \<le> 1 / 2"
  shows "cool_limit a b = Some 2"
  using assms by (simp add: cool_limit_def)

theorem cool_stage2:
  assumes "\<bar>a - 70\<bar> \<le> 1 / 2" "b \<le> 83 / 2"
  shows "cool_limit a b = Some 4"
proof -
  have "a - 70 \<le> 1 / 2" by (rule abs_le_D1[OF assms(1)])
  then have "\<not> 269 / 2 \<le> a" by linarith
  then show ?thesis using assms by (simp add: cool_limit_def)
qed

theorem cool_stage3:
  assumes "269 / 2 \<le> a" "b \<le> 83 / 2"
  shows "cool_limit a b = Some 6"
proof -
  have n1: "\<not> \<bar>b - 70\<bar> \<le> 1 / 2"
  proof
    assume h0: "\<bar>b - 70\<bar> \<le> 1 / 2"
    have "- (b - 70) \<le> 1 / 2" by (rule abs_le_D2[OF h0])
    then show False using assms by linarith
  qed
  have n2: "\<not> \<bar>a - 70\<bar> \<le> 1 / 2"
  proof
    assume h0: "\<bar>a - 70\<bar> \<le> 1 / 2"
    have "a - 70 \<le> 1 / 2" by (rule abs_le_D1[OF h0])
    then show False using assms by linarith
  qed
  show ?thesis using assms n1 n2 by (simp add: cool_limit_def)
qed

theorem cold_hold_verdict:
  "cd_kernel (Cd_cold t) = Verdict K_cold_hold (f_of t \<le> 41)"
  "cd_kernel (Cd_hot t) = Verdict K_hot_hold (135 \<le> f_of t)"
  by (simp_all add: cd_kernel_def)

theorem cooking_minimums:
  "cd_kernel (Cd_cook Cook_poultry) = Exact K_cook_temp 165"
  "cd_kernel (Cd_cook Cook_ground) = Exact K_cook_temp 155"
  "cd_kernel (Cd_cook Cook_whole) = Exact K_cook_temp 145"
  by (simp_all add: cd_kernel_def)

theorem tphc_limit:
  "0 \<le> h \<Longrightarrow> cd_kernel (Cd_tphc (Some h)) = Verdict K_tphc (h \<le> 4)"
  "cd_kernel (Cd_tphc None) = Exact K_tphc_rule 4"
  by (simp_all add: cd_kernel_def)

theorem tphc_negative_time:
  "cd_kernel (Cd_tphc (Some h)) = Decline (Impossible R_negative_duration) \<longleftrightarrow> h < 0"
  by (auto simp: cd_kernel_def)

theorem tphc_pass_elapsed_bound:
  "cd_kernel (Cd_tphc (Some h)) = Verdict k True \<longleftrightarrow>
    k = K_tphc \<and> 0 \<le> h \<and> h \<le> 4"
  by (auto simp: cd_kernel_def)

text \<open>Date marking: the day of preparation is day 1 and the food is discarded at
the end of day 7, which is the day before the weekday of preparation.\<close>
theorem date_marking:
  "wd_idx (last_day d) = (wd_idx d + 6) mod 7"
  by (cases d) simp_all

theorem date_marking_kernel:
  "cd_kernel (Cd_date (Some d)) = Weekday e \<longleftrightarrow> e = last_day d"
  by (auto simp: cd_kernel_def)

theorem celsius_to_fahrenheit:
  "f_of (Temp 100 True) = 212 \<and> f_of (Temp 0 True) = 32 \<and> f_of (Temp 5 True) = 41"
  by simp


section \<open>Requests, the kernel and the reply text (ASCII)\<close>

datatype request = Req_cc ccreq | Req_aq aqreq | Req_cl clreq | Req_cm cmreq | Req_cd cdreq

fun kernel :: "request \<Rightarrow> outcome" where
  "kernel (Req_cc r) = cc_kernel r"
| "kernel (Req_aq r) = aq_kernel r"
| "kernel (Req_cl r) = cl_kernel r"
| "kernel (Req_cm r) = cm_kernel r"
| "kernel (Req_cd r) = cd_kernel r"

fun kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name K_c_to_co2 = STR ''c_to_co2''" | "kind_name K_co2_to_c = STR ''co2_to_c''"
| "kind_name K_fuel_co2 = STR ''fuel_co2''" | "kind_name K_co2_per_mile = STR ''co2_per_mile''"
| "kind_name K_captured = STR ''captured''" | "kind_name K_capture_energy = STR ''capture_energy''"
| "kind_name K_aqi = STR ''aqi''" | "kind_name K_overall = STR ''overall''"
| "kind_name K_category = STR ''category''"
| "kind_name K_forcing = STR ''forcing''" | "kind_name K_warming_ecs = STR ''warming_ecs''"
| "kind_name K_warming_lambda = STR ''warming_lambda''" | "kind_name K_ppm_to_gtc = STR ''ppm_to_gtc''"
| "kind_name K_ppm_to_gtco2 = STR ''ppm_to_gtco2''" | "kind_name K_mass_to_ppm = STR ''mass_to_ppm''"
| "kind_name K_effective_temp = STR ''effective_temp''" | "kind_name K_co2e = STR ''co2e''"
| "kind_name K_cnt_diameter = STR ''cnt_diameter''" | "kind_name K_cnt_angle = STR ''cnt_angle''"
| "kind_name K_cnt_type = STR ''cnt_type''" | "kind_name K_cnt_kind = STR ''cnt_kind''"
| "kind_name K_graphene_layers = STR ''graphene_layers''" | "kind_name K_graphene_mass = STR ''graphene_mass''"
| "kind_name K_cooling_check = STR ''cooling_check''" | "kind_name K_cold_hold = STR ''cold_hold''"
| "kind_name K_hot_hold = STR ''hot_hold''" | "kind_name K_cook_temp = STR ''cook_temp''"
| "kind_name K_reheat = STR ''reheat''" | "kind_name K_tphc = STR ''tphc''"
| "kind_name K_tphc_rule = STR ''tphc_rule''" | "kind_name K_date_mark = STR ''date_mark''"
| "kind_name K_date_rule = STR ''date_rule''" | "kind_name K_danger_zone = STR ''danger_zone''"

fun dd_of :: "kind \<Rightarrow> nat" where
  "dd_of K_forcing = 3" | "dd_of K_warming_ecs = 3" | "dd_of K_warming_lambda = 3"
| "dd_of K_ppm_to_gtc = 3" | "dd_of K_ppm_to_gtco2 = 3" | "dd_of K_mass_to_ppm = 3"
| "dd_of K_effective_temp = 3" | "dd_of K_co2e = 3"
| "dd_of K_c_to_co2 = 4" | "dd_of K_co2_to_c = 4" | "dd_of K_fuel_co2 = 4" | "dd_of K_co2_per_mile = 4"
| "dd_of K_captured = 4" | "dd_of K_capture_energy = 4" | "dd_of K_aqi = 4" | "dd_of K_overall = 4"
| "dd_of K_category = 4" | "dd_of K_cnt_diameter = 4" | "dd_of K_cnt_angle = 4" | "dd_of K_cnt_type = 4"
| "dd_of K_cnt_kind = 4" | "dd_of K_graphene_layers = 4" | "dd_of K_graphene_mass = 4"
| "dd_of K_cooling_check = 4" | "dd_of K_cold_hold = 4" | "dd_of K_hot_hold = 4" | "dd_of K_cook_temp = 4"
| "dd_of K_reheat = 4" | "dd_of K_tphc = 4" | "dd_of K_tphc_rule = 4" | "dd_of K_date_mark = 4"
| "dd_of K_date_rule = 4" | "dd_of K_danger_zone = 4"

fun cat_name :: "cat \<Rightarrow> String.literal" where
  "cat_name Cat_good = STR ''Good''" | "cat_name Cat_moderate = STR ''Moderate''"
| "cat_name Cat_usg = STR ''Unhealthy for Sensitive Groups''" | "cat_name Cat_unhealthy = STR ''Unhealthy''"
| "cat_name Cat_very_unhealthy = STR ''Very Unhealthy''" | "cat_name Cat_hazardous = STR ''Hazardous''"

fun cat_range :: "cat \<Rightarrow> String.literal" where
  "cat_range Cat_good = STR ''0-50''" | "cat_range Cat_moderate = STR ''51-100''"
| "cat_range Cat_usg = STR ''101-150''" | "cat_range Cat_unhealthy = STR ''151-200''"
| "cat_range Cat_very_unhealthy = STR ''201-300''" | "cat_range Cat_hazardous = STR ''301-500''"

fun pol_label :: "pol \<Rightarrow> String.literal" where
  "pol_label P_pm25 = STR ''PM2.5''" | "pol_label P_pm10 = STR ''PM10''" | "pol_label P_o3 = STR ''ozone''"
| "pol_label P_co = STR ''CO''" | "pol_label P_so2 = STR ''SO2''" | "pol_label P_no2 = STR ''NO2''"

fun pol_unit :: "pol \<Rightarrow> String.literal" where
  "pol_unit P_pm25 = STR ''ug/m3''" | "pol_unit P_pm10 = STR ''ug/m3''" | "pol_unit P_o3 = STR ''ppm''"
| "pol_unit P_co = STR ''ppm''" | "pol_unit P_so2 = STR ''ppb''" | "pol_unit P_no2 = STR ''ppb''"

fun pol_period :: "pol \<Rightarrow> String.literal" where
  "pol_period P_pm25 = STR ''24-hour''" | "pol_period P_pm10 = STR ''24-hour''" | "pol_period P_o3 = STR ''8-hour''"
| "pol_period P_co = STR ''8-hour''" | "pol_period P_so2 = STR ''1-hour''" | "pol_period P_no2 = STR ''1-hour''"

fun wd_name :: "weekday \<Rightarrow> String.literal" where
  "wd_name Monday = STR ''Monday''" | "wd_name Tuesday = STR ''Tuesday''" | "wd_name Wednesday = STR ''Wednesday''"
| "wd_name Thursday = STR ''Thursday''" | "wd_name Friday = STR ''Friday''" | "wd_name Saturday = STR ''Saturday''"
| "wd_name Sunday = STR ''Sunday''"

fun tube_name :: "tube \<Rightarrow> String.literal" where
  "tube_name T_armchair = STR ''armchair''" | "tube_name T_zigzag = STR ''zigzag''" | "tube_name T_chiral = STR ''chiral''"

fun eunit_up :: "eunit \<Rightarrow> String.literal" where
  "eunit_up E_kwh = STR ''kWh''" | "eunit_up E_mwh = STR ''MWH''" | "eunit_up E_gj = STR ''GJ''"

fun eunit_low :: "eunit \<Rightarrow> String.literal" where
  "eunit_low E_kwh = STR ''kWh''" | "eunit_low E_mwh = STR ''mwh''" | "eunit_low E_gj = STR ''gj''"

definition g4 :: "rat \<Rightarrow> String.literal" where "g4 q = g_text 4 q"
definition g3 :: "rat \<Rightarrow> String.literal" where "g3 q = g_text 3 q"

definition yes_no :: "bool \<Rightarrow> String.literal" where
  "yes_no b = (if b then STR ''Yes'' else STR ''No'')"

text \<open>The text of each kind. The value literal V is already rounded by the
kernel's rule for the kind (@{text g_text} for exact values, the enclosure's
decimal for approximate ones).\<close>
fun cc_text :: "ccreq \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "cc_text (Cc_c_to_co2 m u) V = STR ''That is '' + V + STR '' '' + u + STR '' of CO2 ('' + g4 m + STR '' x 44.01/12.011).''"
| "cc_text (Cc_co2_to_c m u) V = STR ''That is '' + V + STR '' '' + u + STR '' of carbon ('' + g4 m + STR '' x 12.011/44.01).''"
| "cc_text (Cc_fuel_co2 f n gal) V = STR ''The CO2 emitted is '' + V + STR '' kg ('' + g4 gal + STR '' gal x ''
     + g4 (ef f) + STR '' g CO2/gal; EPA '' + n + STR '' factor).''"
| "cc_text (Cc_co2_per_mile f n mpg) V = STR ''The tailpipe CO2 is '' + V + STR '' g per mile ('' + g4 (ef f)
     + STR '' g CO2/gal / '' + g4 mpg + STR '' mpg; EPA '' + n + STR '' factor).''"
| "cc_text (Cc_captured m u c) V = STR ''The CO2 captured is '' + V + STR '' '' + u + STR '' ('' + g4 m + STR '' x ''
     + g4 c + STR ''% capture rate).''"
| "cc_text (Cc_capture_energy m u c e eu) V = STR ''The energy needed is '' + V + STR '' '' + eunit_up eu + STR '' (''
     + g4 (mass_tonnes m u * c / 100) + STR '' tonnes captured x '' + g4 e + STR '' '' + eunit_low eu + STR '' per tonne).''"

fun join_subs :: "sub list \<Rightarrow> String.literal" where
  "join_subs [] = STR ''''"
| "join_subs [s] = pol_label (sub_pol s) + STR '' '' + show_int (sub_aqi s)"
| "join_subs (s # t # ss) = pol_label (sub_pol s) + STR '' '' + show_int (sub_aqi s) + STR '', '' + join_subs (t # ss)"

definition aq_text :: "aqreq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "aq_text r o' = (case (r, o') of
     (Aq_index h rs, Index K_aqi a p) \<Rightarrow>
        (case aq_subs h rs of
           Inr [Sub _ ct _] \<Rightarrow> STR ''The AQI is '' + show_int a + STR '' - '' + cat_name (cat_of (of_int a))
              + STR '' ('' + pol_label p + STR '' '' + fixed_pad (tdig p) ct + STR '' '' + pol_unit p + STR '' ''
              + pol_period p + STR '' average, truncated; EPA breakpoint interpolation).''
         | _ \<Rightarrow> STR '''')
   | (Aq_index h rs, Index _ a p) \<Rightarrow>
        (case aq_subs h rs of
           Inr ss \<Rightarrow> STR ''The overall AQI is '' + show_int a + STR '' - '' + cat_name (cat_of (of_int a))
              + STR '', set by '' + pol_label p + STR '' (the highest sub-index; '' + join_subs ss + STR '').''
         | Inl _ \<Rightarrow> STR '''')
   | (Aq_category _ echo, Category c) \<Rightarrow>
        STR ''An AQI of '' + echo + STR '' is '' + cat_name c + STR '' (EPA category for '' + cat_range c + STR '').''
   | _ \<Rightarrow> STR '''')"

definition teff_c_txt :: "rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "teff_c_txt s a = (case enclose_fixed 3 (floatarith.Add (sp_fa (Sp_teff s a))
        (floatarith.Mult (I (- 27315)) (floatarith.Inverse (I 100)))) of
      Some d \<Rightarrow> fixed_lit d | None \<Rightarrow> STR ''?'')"

definition forcing_txt :: "rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "forcing_txt c0 c = (case enclose_fixed 3 (sp_fa (Sp_forcing c0 c)) of Some d \<Rightarrow> fixed_lit d | None \<Rightarrow> STR ''?'')"

fun cl_text :: "clreq \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "cl_text (Cl_forcing cc) V = (case cc of Some (c0, c) \<Rightarrow>
      STR ''The radiative forcing is '' + V + STR '' W/m2 (5.35 x ln('' + g3 c + STR ''/'' + g3 c0
        + STR ''); Myhre et al. 1998).'' | None \<Rightarrow> STR '''')"
| "cl_text (Cl_warming cc s) V = (case cc of Some (c0, c) \<Rightarrow>
      (case s of
         Sens_lambda l \<Rightarrow> STR ''The equilibrium warming is '' + V + STR '' C (lambda x dF = '' + g3 l + STR '' x ''
            + forcing_txt c0 c + STR '' W/m2, dF = 5.35 ln('' + g3 c + STR ''/'' + g3 c0 + STR '')).''
       | Sens_ecs e \<Rightarrow> STR ''The equilibrium warming is '' + V + STR '' C (sensitivity '' + g3 e
            + STR '' C per doubling x log2('' + g3 c + STR ''/'' + g3 c0 + STR '')).''
       | Sens_none \<Rightarrow> STR '''') | None \<Rightarrow> STR '''')"
| "cl_text (Cl_ppm_to_gtc p) V = STR ''That is '' + V + STR '' GtC ('' + g3 p + STR '' ppm x 2.124 GtC/ppm; Global Carbon Project).''"
| "cl_text (Cl_ppm_to_gtco2 p) V = STR ''That is '' + V + STR '' GtCO2 ('' + g3 p + STR '' ppm x 7.782 GtCO2/ppm).''"
| "cl_text (Cl_mass_to_ppm c co2 u) V = STR ''That is '' + V + STR '' ppm ('' + g3 c + STR '' '' + u + STR '' / ''
      + g3 (if co2 then gtco2_per_ppm else gtc_per_ppm) + STR '' per ppm).''"
| "cl_text (Cl_eff_temp s a) V = (case s of Some sv \<Rightarrow> (case a of Some av \<Rightarrow>
      STR ''The effective temperature is '' + V + STR '' K ('' + teff_c_txt sv av + STR '' C) ((S (1 - a) / 4 sigma)^(1/4) = (''
        + g3 sv + STR '' x '' + g3 (1 - av) + STR '' / (4 x 5.670e-8))^(1/4)).'' | None \<Rightarrow> STR '''') | None \<Rightarrow> STR '''')"
| "cl_text (Cl_co2e g m u gs) V = STR ''The CO2-equivalent is '' + V + STR '' '' + u + STR '' ('' + g3 m
      + STR '' x GWP '' + gs + STR '').''"

definition material_area_lit :: "rat \<Rightarrow> String.literal" where
  "material_area_lit q = (let (n,d) = quotient_of q in
    if d=1 then show_int n else show_int n + STR ''/'' + show_int d)"

definition cm_text :: "cmreq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "cm_text r o' = (case (r, o') of
     (Cm_diameter n m, Approx _ d) \<Rightarrow> STR ''The diameter is '' + fixed_lit d + STR '' nm (a sqrt(n^2 + nm + m^2) / pi = 0.246 x sqrt''
        + show_int (circ2 n m) + STR '' / pi; '' + tube_name (tube_of n m) + STR '').''
   | (Cm_angle n m, Approx _ d) \<Rightarrow> STR ''The chiral angle is '' + fixed_lit d + STR '' degrees (atan(sqrt3 m / (2n + m)); ''
        + tube_name (tube_of n m) + STR '').''
   | (Cm_type n m, Verdict _ b) \<Rightarrow>
        (if b then STR ''Metallic - a ('' + show_int n + STR '', '' + show_int m + STR '') nanotube is metallic ((n - m) = ''
           + show_int (n - m) + STR '' is divisible by 3; '' + tube_name (tube_of n m) + STR '').''
         else STR ''Semiconducting - a ('' + show_int n + STR '', '' + show_int m + STR '') nanotube is semiconducting ((n - m) = ''
           + show_int (n - m) + STR '' is not divisible by 3; '' + tube_name (tube_of n m) + STR '').'')
   | (Cm_kind n m, Tube_kind t) \<Rightarrow> STR ''A ('' + show_int n + STR '', '' + show_int m + STR '') nanotube is '' + tube_name t
        + STR '' (armchair n = m, zigzag m = 0, otherwise chiral).''
   | (Cm_layers t ang, Exact _ q) \<Rightarrow> STR ''That is about '' + g4 q + STR '' layers ('' + g4 (thickness t ang)
        + STR '' nm / 0.335 nm interlayer spacing).''
   | (Cm_mass a cm2, Approx _ d) \<Rightarrow> STR ''The mass is '' + fixed_lit d + STR '' mg ('' + material_area_lit (area_m2 a cm2) + STR '' m2 x ''
        + (case enclose_fixed 4 (floatarith.Mult (Q areal_k) (floatarith.Inverse (floatarith.Sqrt (I 3)))) of
             Some e \<Rightarrow> fixed_lit e | None \<Rightarrow> STR ''?'')
        + STR '' mg/m2, single-layer graphene).''
   | _ \<Rightarrow> STR '''')"

definition cd_text :: "cdreq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "cd_text r o' = (case (r, o') of
     (Cd_cool a b d, Verdict _ ok) \<Rightarrow>
        (let fa = f_of a; fb = f_of b; h = pct_g (hours d) in
         if 269 / 2 \<le> fa \<and> \<bar>fb - 70\<bar> \<le> 1 / 2 then
           (if ok then STR ''Yes, that meets it'' else STR ''No, that misses it'')
             + STR '': the Food Code requires cooling from 135 F to 70 F within 2 hours; '' + h + STR '' hours ''
             + (if ok then STR ''is within the limit'' else STR ''is too slow'') + STR '' [3-501.14(A)(1)].''
         else if \<bar>fa - 70\<bar> \<le> 1 / 2 \<and> fb \<le> 83 / 2 then
           (if ok then STR ''Yes, that meets it'' else STR ''No, that misses it'')
             + STR '': after reaching 70 F, food must reach 41 F within 4 more hours; '' + h + STR '' hours ''
             + (if ok then STR ''is within the limit'' else STR ''is too slow'') + STR '' [3-501.14(A)(2)].''
         else
           (if ok then STR ''Yes, that meets the limit'' else STR ''No, that misses the limit'')
             + STR '' for the total: 135 F to 41 F must take no more than 6 hours (and the first stage, to 70 F, no more than 2); ''
             + h + STR '' hours '' + (if ok then STR ''is within 6'' else STR ''exceeds 6'') + STR '' [3-501.14(A)].'')
   | (Cd_partial a b d scope, Verdict _ ok) \<Rightarrow>
       (if scope = Checkpoint_only then
          yes_no ok + STR '': this checks only the named checkpoint deadline, not the complete cooling schedule. Elapsed time: ''
          + pct_g (hours d) + STR '' hours.''
        else yes_no ok + STR '': every complete cooling timeline consistent with this elapsed checkpoint time ''
          + (if ok then STR ''meets both deadlines.'' else STR ''fails at least one deadline.'')
          + STR '' The deadlines are 70 F (21 C) within 2 hours and 41 F (5 C) within 6 hours total [Food Code 2022 3-501.14(A)].'')
   | (Cd_schedule a b c d e, Verdict _ ok) \<Rightarrow>
       yes_no ok + STR '': the first cooling stage took '' + pct_g (hours d)
       + STR '' hours and the complete schedule took '' + pct_g (hours d + hours e)
       + STR '' hours. Both checkpoint readings must meet their limits: at most 70 F (21 C) within 2 hours and at most 41 F (5 C) within 6 hours total [Food Code 2022 3-501.14(A)].''
   | (Cd_cold t, Verdict _ ok) \<Rightarrow> yes_no ok + STR '': cold holding must be at or below 41 F (5 C); '' + pct_g (f_of t)
        + STR '' F '' + (if ok then STR ''meets it'' else STR ''is too warm'') + STR '' [3-501.16(A)(2)].''
   | (Cd_hot t, Verdict _ ok) \<Rightarrow> yes_no ok + STR '': hot holding must be at or above 135 F (57 C); '' + pct_g (f_of t)
        + STR '' F '' + (if ok then STR ''meets it'' else STR ''is too cool'') + STR '' [3-501.16(A)(1)].''
   | (Cd_cook c, Exact _ q) \<Rightarrow> STR ''The Food Code minimum is '' + show_int (fst (round_at (rl q) 0)) + STR '' F (''
        + show_int (fst (round_at (rl ((q - 32) * 5 / 9)) 0)) + STR '' C) held for ''
        + (case c of Cook_poultry \<Rightarrow> STR ''<1 second [3-401.11(A)(3)].''
           | Cook_ground \<Rightarrow> STR ''17 seconds [3-401.11(A)(2)].'' | Cook_whole \<Rightarrow> STR ''15 seconds [3-401.11(A)(1)].'')
   | (Cd_reheat, Exact _ _) \<Rightarrow> STR ''Food reheated for hot holding must reach 165 F (74 C) within 2 hours [3-403.11(A),(D)].''
   | (Cd_tphc (Some h), Verdict _ ok) \<Rightarrow> (if ok then STR ''Within the limit'' else STR ''Past the limit'')
        + STR '': under time as a public health control, food must be served or discarded within 4 hours; '' + pct_g h
        + STR '' hours '' + (if ok then STR ''is within it'' else STR ''means it must be discarded'') + STR '' [3-501.19(B)].''
   | (Cd_tphc None, Exact _ _) \<Rightarrow> STR ''Under time as a public health control, food held without temperature control must be served or discarded within 4 hours [3-501.19(B)].''
   | (Cd_date (Some d), Weekday e) \<Rightarrow> STR ''Discard by the end of '' + wd_name e
        + STR '': ready-to-eat TCS food held at 41 F or below may be kept 7 days, counting '' + wd_name d
        + STR '' as day 1 [3-501.17].''
   | (Cd_date None, Exact _ _) \<Rightarrow> STR ''Refrigerated ready-to-eat TCS food held at 41 F (5 C) or below may be kept for 7 days, the day of preparation counting as day 1 [3-501.17].''
   | (Cd_danger, Interval _ _ _) \<Rightarrow> STR ''The temperature danger zone is between 41 F and 135 F (5 C to 57 C): cold food is held at 41 F or below and hot food at 135 F or above [3-501.16].''
   | _ \<Rightarrow> STR '''')"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text n = (case n of
     N_gwp \<Rightarrow> STR ''the global warming potential (GWP) to use - values differ between IPCC reports''
   | N_conc \<Rightarrow> STR ''the starting and final CO2 concentrations (ppm)''
   | N_sens \<Rightarrow> STR ''the climate sensitivity (C per doubling) or the feedback parameter lambda - it is uncertain, so I will not assume one''
   | N_solar_albedo \<Rightarrow> STR ''the solar constant (W/m2) and the albedo''
   | N_material_geometry \<Rightarrow> STR ''one supported geometry: layer count needs a unique thickness; mass needs one area and the single-layer graphene model, not a rate or multilayer sheet''
   | N_partial_cooling \<Rightarrow> STR ''the missing checkpoint time: specify when 70 F (21 C) and 41 F (5 C) were reached relative to 135 F (57 C); a partial record may fit both compliant and noncompliant complete timelines''
   | N_cooling_schedule \<Rightarrow> STR ''a complete supported cooling schedule: from 135 F to 70 F with its elapsed time, then to 41 F with its additional elapsed time'')"

definition reason_text :: "reason \<Rightarrow> String.literal" where
  "reason_text w = (case w of
     R_rate_over_100 \<Rightarrow> STR ''A capture rate above 100% is not possible.''
   | R_negative_capture_rate \<Rightarrow> STR ''A capture rate cannot be negative.''
   | R_negative_carbon_quantity \<Rightarrow> STR ''Mass, fuel quantity and capture energy intensity must be nonnegative.''
   | R_zero_mpg \<Rightarrow> STR ''Fuel economy must be positive.''
   | R_pm_hourly \<Rightarrow> STR ''The AQI for particles uses the 24-hour average (hourly values go through the NowCast, which I do not compute here).''
   | R_beyond p \<Rightarrow> pol_label p + STR '' is beyond the AQI scale (above the 500 breakpoint).''
   | R_o3_above_8h \<Rightarrow> STR ''8-hour ozone above 0.200 ppm is indexed with the 1-hour ozone table, not the 8-hour one.''
   | R_so2_above_1h \<Rightarrow> STR ''1-hour SO2 above 304 ppb is indexed with the 24-hour SO2 table.''
   | R_between p \<Rightarrow> pol_label p + STR '' falls between published breakpoints after truncation.''
   | R_aqi_out_of_scale \<Rightarrow> STR ''That AQI is outside the 0-500 scale.''
   | R_nonpositive_conc \<Rightarrow> STR ''CO2 concentrations must be positive.''
   | R_albedo_range \<Rightarrow> STR ''An albedo must be between 0 and 1.''
   | R_negative_solar \<Rightarrow> STR ''A solar constant cannot be negative.''
   | R_bad_chirality \<Rightarrow> STR ''Chiral indices are written (n, m) with n >= m >= 0 and not both zero.''
   | R_negative_duration \<Rightarrow> STR ''Elapsed time cannot be negative.''
   | R_negative_geometry \<Rightarrow> STR ''Physical area and thickness cannot be negative.'')"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | Impossible _ \<Rightarrow> STR ''impossible''
     | Imprecise \<Rightarrow> STR ''imprecise'' | Not_taken \<Rightarrow> STR ''not_taken'')"

definition decline_text :: "decline \<Rightarrow> String.literal" where
  "decline_text w = (case w of
     Underspecified n \<Rightarrow> STR ''I need '' + need_text n + STR '' to work that out; I will not assume it.''
   | Impossible y \<Rightarrow> reason_text y
   | Imprecise \<Rightarrow> STR ''The value could not be bounded tightly enough to state it.''
   | Not_taken \<Rightarrow> STR '''')"

definition out_kind :: "outcome \<Rightarrow> String.literal" where
  "out_kind o' = (case o' of
     Exact k _ \<Rightarrow> kind_name k | Approx k _ \<Rightarrow> kind_name k | Verdict k _ \<Rightarrow> kind_name k
   | Index k _ _ \<Rightarrow> kind_name k | Category _ \<Rightarrow> kind_name K_category | Tube_kind _ \<Rightarrow> kind_name K_cnt_kind
   | Weekday _ \<Rightarrow> kind_name K_date_mark | Interval k _ _ \<Rightarrow> kind_name k | Decline w \<Rightarrow> decline_name w)"

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

definition stated_of :: "outcome \<Rightarrow> String.literal" where
  "stated_of o' = (case o' of
     Exact k q \<Rightarrow> render_dec 20 (g_dec (dd_of k) q)
   | Approx _ d \<Rightarrow> render_dec 20 d
   | Verdict _ b \<Rightarrow> (if b then STR ''true'' else STR ''false'')
   | Index _ a _ \<Rightarrow> show_int a
   | Category c \<Rightarrow> dq + cat_name c + dq
   | Tube_kind t \<Rightarrow> dq + tube_name t + dq
   | Weekday d \<Rightarrow> dq + wd_name d + dq
   | Interval _ lo hi \<Rightarrow> STR ''['' + render_dec 20 (g_dec 0 lo) + STR '', '' + render_dec 20 (g_dec 0 hi) + STR '']''
   | Decline _ \<Rightarrow> STR '''')"

definition answer_text :: "request \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "answer_text r o' = (case r of
     Req_cc c \<Rightarrow> (case o' of Exact k q \<Rightarrow> cc_text c (g4 q) | _ \<Rightarrow> STR '''')
   | Req_aq a \<Rightarrow> aq_text a o'
   | Req_cl c \<Rightarrow> (case o' of Exact k q \<Rightarrow> cl_text c (g3 q) | Approx k d \<Rightarrow> cl_text c (fixed_lit d) | _ \<Rightarrow> STR '''')
   | Req_cm c \<Rightarrow> cm_text c o'
   | Req_cd c \<Rightarrow> cd_text c o')"

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Decline w \<Rightarrow> Reply False (decline_name w) (decline_text w) None
   | o' \<Rightarrow> Reply True (out_kind o') (answer_text r o') (Some (stated_of o')))"

theorem reply_answered_iff: "answered (reply_of r) \<longleftrightarrow> (\<forall>w. kernel r \<noteq> Decline w)"
  by (cases "kernel r") (auto simp: reply_of_def)

theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated (reply_of r) = Some (render_dec 20 (g_dec (dd_of k) q))"
  by (simp add: reply_of_def stated_of_def)

theorem reply_states_approx:
  "kernel r = Approx k d \<Longrightarrow> stated (reply_of r) = Some (render_dec 20 d)"
  by (simp add: reply_of_def stated_of_def)

theorem exact_stated_sound:
  "\<bar>dec_val (g_dec (dd_of k) q) - rl q\<bar> \<le> pow10 (snd (g_dec (dd_of k) q)) / 2"
  by (rule conjunct2[OF g_dec_sound])

end
