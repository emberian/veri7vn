theory Renewables
  imports Energy_Core
begin

text \<open>
  The Oracle7 renewables specialist (upstream/root/specialists/renewables/
  organ_renewables_v1.py): wind power, how power changes with wind speed,
  capacity factor and annual energy, photovoltaic output and hydropower. All
  values are exact rationals except a rotor given by its diameter or blade
  length, whose area is a rational multiple of pi: that outcome is PiMul and its
  digits come from Isabelle's verified interval arithmetic.
\<close>

section \<open>Tables and requests\<close>

definition grav :: rat where "grav = 981 / 100"
definition rho_water :: rat where "rho_water = 1000"
definition air_density :: rat where "air_density = 1225 / 1000"
definition betz :: rat where "betz = 16 / 27"
definition stc_irradiance :: rat where "stc_irradiance = 1000"

datatype geo = G_swept rat | G_diam rat | G_rad rat
datatype irr = Irr_given rat | Irr_stc | Irr_none

text \<open>RHydro: flow (m3/s), head (m), efficiency (a fraction). RPV: area (m2),
irradiance, efficiency. RCapF: rated power (W), energy (Wh), hours. RAnnual: rated
power (W), hours, capacity factor (a fraction). RRatio: the first and second wind
speed. RWind: the swept area, speed (m/s), air density, power coefficient.\<close>
datatype ren_req =
    RHydro rat rat rat
  | RPV rat irr rat
  | RCapF rat rat rat
  | RAnnual rat rat rat
  | RRatio rat rat
  | RWind geo rat rat "rat option"

fun irr_val :: "irr \<Rightarrow> rat" where
  "irr_val (Irr_given i) = i" | "irr_val Irr_stc = stc_irradiance" | "irr_val Irr_none = 0"

fun cpf :: "rat option \<Rightarrow> rat" where "cpf None = 1" | "cpf (Some c) = c"

fun area_coef :: "geo \<Rightarrow> rat" where
  "area_coef (G_swept a) = a" | "area_coef (G_diam d) = d * d / 4" | "area_coef (G_rad r) = r * r"

definition wind_coef :: "geo \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat option \<Rightarrow> rat" where
  "wind_coef g v rho cp = rho * v ^ 3 * cpf cp / 2 * area_coef g"

section \<open>Declines\<close>

abbreviation g3 :: "rat \<Rightarrow> String.literal" where "g3 \<equiv> gf F3C"

fun pre_r :: "ren_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "pre_r (RHydro q h e) = (if 1 < e then Some (D_imposs, STR ''An efficiency above 100% is not possible.'') else None)"
| "pre_r (RPV a i e) = (if 1 < e then Some (D_imposs, STR ''A module efficiency above 100% is not possible.'') else None)"
| "pre_r (RAnnual r h c) = (if 1 < c then Some (D_imposs, STR ''A capacity factor above 100% is not possible.'') else None)"
| "pre_r (RWind g v rho (Some c)) = (if betz < c then Some (D_imposs, STR ''A power coefficient of '' + g3 (c * 100)
     + STR ''% exceeds the Betz limit (16/27 = 59.3%); no turbine can capture that much.'') else None)"
| "pre_r _ = None"

fun miss_r :: "ren_req \<Rightarrow> String.literal option" where
  "miss_r (RPV a Irr_none e) = Some (STR ''the irradiance (W/m2)'')"
| "miss_r _ = None"

text \<open>A rated power or hours of zero, or a first wind speed of zero, would
divide by zero (the organ raises); here they are refused.\<close>
fun post_r :: "ren_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "post_r (RCapF r e h) = (if r * h \<le> 0 then Some (D_imposs, STR ''A plant needs a positive rated power and hours.'')
     else if 100 < e / (r * h) * 100 then Some (D_imposs, STR ''That is more energy than the plant could make running flat out for ''
       + g3 h + STR '' hours (capacity factor above 100%).'')
     else None)"
| "post_r (RRatio v1 v2) = (if v1 \<le> 0 then Some (D_imposs, STR ''A wind speed must be positive.'') else None)"
| "post_r _ = None"

section \<open>Values\<close>

fun vl_r :: "ren_req \<Rightarrow> rat" where
  "vl_r (RHydro q h e) = rho_water * grav * q * h * e"
| "vl_r (RPV a i e) = a * irr_val i * e"
| "vl_r (RCapF r e h) = e / (r * h) * 100"
| "vl_r (RAnnual r h c) = r * h * c"
| "vl_r (RRatio v1 v2) = (v2 / v1) ^ 3"
| "vl_r (RWind g v rho cp) = wind_coef g v rho cp"

fun pf_r :: "ren_req \<Rightarrow> bool" where
  "pf_r (RWind (G_swept _) _ _ _) = False"
| "pf_r (RWind _ _ _ _) = True"
| "pf_r _ = False"

fun kd_r :: "ren_req \<Rightarrow> String.literal" where
  "kd_r (RHydro _ _ _) = STR ''hydro''" | "kd_r (RPV _ _ _) = STR ''pv_power''"
| "kd_r (RCapF _ _ _) = STR ''capacity_factor''" | "kd_r (RAnnual _ _ _) = STR ''annual_energy''"
| "kd_r (RRatio _ _) = STR ''wind_ratio''" | "kd_r (RWind _ _ _ _) = STR ''wind_power''"

definition kernel_r :: "ren_req \<Rightarrow> outcome" where
  "kernel_r = mk_kernel pre_r miss_r post_r (\<lambda>_. None) kd_r vl_r pf_r"

section \<open>Soundness\<close>

theorem ren_exact_sound:
  assumes "kernel_r r = Exact k q"
  shows "pre_r r = None \<and> miss_r r = None \<and> post_r r = None \<and> \<not> pf_r r \<and> k = kd_r r \<and> q = vl_r r"
  using assms by (auto simp: kernel_r_def mk_exact)

theorem ren_pi_sound:
  assumes "kernel_r r = PiMul k q"
  shows "pre_r r = None \<and> miss_r r = None \<and> post_r r = None \<and> pf_r r \<and> k = kd_r r \<and> q = vl_r r"
  using assms by (auto simp: kernel_r_def mk_pi)

lemmas exact_parts_r =
  ren_exact_sound[THEN conjunct1]
  ren_exact_sound[THEN conjunct2, THEN conjunct1]
  ren_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct1]
  ren_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct1]
  ren_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2]

lemmas pi_parts_r =
  ren_pi_sound[THEN conjunct1]
  ren_pi_sound[THEN conjunct2, THEN conjunct2, THEN conjunct1]
  ren_pi_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct1]
  ren_pi_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2]

lemma pre_r_not_under: "pre_r r \<noteq> Some (D_under, w)"
  by (cases r rule: pre_r.cases) (auto split: if_splits)

lemma post_r_not_under: "post_r r \<noteq> Some (D_under, w)"
  by (cases r rule: post_r.cases) (auto split: if_splits)

theorem ren_underspecified:
  "kernel_r r = Decline D_under w \<longleftrightarrow> pre_r r = None \<and> miss_r r = Some w"
  by (auto simp: kernel_r_def mk_decline pre_r_not_under post_r_not_under)

theorem hydro_law:
  assumes "kernel_r (RHydro q h e) = Exact k p"
  shows "k = STR ''hydro'' \<and> e \<le> 1 \<and> p = 1000 * (981 / 100) * q * h * e"
proof -
  note x = exact_parts_r[OF assms]
  have "\<not> 1 < e" using x(1) by (auto split: if_splits)
  then show ?thesis using x(4,5) by (simp add: rho_water_def grav_def)
qed

theorem pv_law:
  assumes "kernel_r (RPV a i e) = Exact k p"
  shows "k = STR ''pv_power'' \<and> e \<le> 1 \<and> p = a * irr_val i * e \<and> i \<noteq> Irr_none"
proof -
  note x = exact_parts_r[OF assms]
  have "\<not> 1 < e" using x(1) by (auto split: if_splits)
  moreover have "i \<noteq> Irr_none" using x(2) by (cases i) auto
  ultimately show ?thesis using x(4,5) by auto
qed

theorem capacity_factor_law:
  assumes "kernel_r (RCapF r e h) = Exact k p"
  shows "k = STR ''capacity_factor'' \<and> 0 < r * h \<and> p \<le> 100 \<and> p * (r * h) = 100 * e"
proof -
  note x = exact_parts_r[OF assms]
  have pos: "0 < r * h" using x(3) by (auto split: if_splits)
  have le: "\<not> 100 < e / (r * h) * 100" using x(3) pos by (auto split: if_splits)
  have nz: "r * h \<noteq> 0" by (rule pos_ne[OF pos])
  have pe: "p = e / (r * h) * 100" using x(5) by simp
  have p_le: "p \<le> 100" using le pe by (simp add: not_less)
  have eq: "p * (r * h) = 100 * e" using pe nz by (simp add: field_simps)
  show ?thesis using x(4) pos p_le eq by simp
qed

theorem annual_energy_law:
  assumes "kernel_r (RAnnual r h c) = Exact k p"
  shows "k = STR ''annual_energy'' \<and> c \<le> 1 \<and> p = r * h * c"
proof -
  note x = exact_parts_r[OF assms]
  have "\<not> 1 < c" using x(1) by (auto split: if_splits)
  then show ?thesis using x(4,5) by simp
qed

text \<open>Power goes as the cube of wind speed: ratio * v1^3 = v2^3.\<close>
theorem wind_ratio_law:
  assumes "kernel_r (RRatio v1 v2) = Exact k p"
  shows "k = STR ''wind_ratio'' \<and> 0 < v1 \<and> p * v1 ^ 3 = v2 ^ 3"
proof -
  note x = exact_parts_r[OF assms]
  have pos: "0 < v1" using x(3) by (auto split: if_splits)
  have nz: "v1 \<noteq> 0" by (rule pos_ne[OF pos])
  have "p = (v2 / v1) ^ 3" using x(5) by simp
  then show ?thesis using x(4) pos nz by (simp add: field_simps power_divide)
qed

text \<open>Wind power P = 1/2 rho A v^3 Cp, Cp at most the Betz limit 16/27; with
no Cp the value is the power in the wind (Cp = 1). For a swept area the value is
exact.\<close>
theorem wind_power_swept_law:
  assumes "kernel_r (RWind (G_swept a) v rho cp) = Exact k p"
  shows "k = STR ''wind_power'' \<and> (\<forall>c. cp = Some c \<longrightarrow> c \<le> betz) \<and>
         p = rho * v ^ 3 * cpf cp / 2 * a"
proof -
  note x = exact_parts_r[OF assms]
  have b: "\<forall>c. cp = Some c \<longrightarrow> c \<le> betz" using x(1) by (cases cp) (auto split: if_splits)
  show ?thesis using b x(4,5) by (simp add: wind_coef_def)
qed

text \<open>With a rotor diameter D or blade length r the value is a rational c with
c * pi = 1/2 rho (pi (D/2)^2) v^3 Cp, in the real numbers.\<close>
theorem wind_power_diameter_law:
  assumes "kernel_r (RWind (G_diam d) v rho cp) = PiMul k c"
  shows "k = STR ''wind_power'' \<and> (\<forall>x. cp = Some x \<longrightarrow> x \<le> betz) \<and>
         rl c * pi = 1 / 2 * rl rho * (pi * (rl d / 2) ^ 2) * rl v ^ 3 * rl (cpf cp)"
proof -
  note x = pi_parts_r[OF assms]
  have b: "\<forall>y. cp = Some y \<longrightarrow> y \<le> betz" using x(1) by (cases cp) (auto split: if_splits)
  have c: "c = rho * v ^ 3 * cpf cp / 2 * (d * d / 4)" using x(4) by (simp add: wind_coef_def)
  have "rl c = rl rho * rl v ^ 3 * rl (cpf cp) / 2 * (rl d * rl d / 4)"
    by (simp add: c of_rat_mult of_rat_divide of_rat_power)
  then show ?thesis using b x(3) by (auto simp: power2_eq_square field_simps)
qed

theorem wind_power_radius_law:
  assumes "kernel_r (RWind (G_rad r) v rho cp) = PiMul k c"
  shows "k = STR ''wind_power'' \<and> rl c * pi = 1 / 2 * rl rho * (pi * rl r ^ 2) * rl v ^ 3 * rl (cpf cp)"
proof -
  note x = pi_parts_r[OF assms]
  have c: "c = rho * v ^ 3 * cpf cp / 2 * (r * r)" using x(4) by (simp add: wind_coef_def)
  have "rl c = rl rho * rl v ^ 3 * rl (cpf cp) / 2 * (rl r * rl r)"
    by (simp add: c of_rat_mult of_rat_divide of_rat_power)
  then show ?thesis using x(3) by (auto simp: power2_eq_square field_simps)
qed

section \<open>Reply text\<close>

definition pwt :: "bool \<Rightarrow> rat \<Rightarrow> String.literal" where
  "pwt en x = (case pw_show en (rl x) (rl x) of Some s \<Rightarrow> s | None \<Rightarrow> STR ''?'')"

fun shw_r :: "ren_req \<Rightarrow> rat \<Rightarrow> String.literal option" where
  "shw_r (RCapF _ _ _) q = show_fmt F3C (rl q)"
| "shw_r (RRatio _ _) q = show_fmt F3C (rl q)"
| "shw_r (RAnnual _ _ _) q = pw_show True (rl q) (rl q)"
| "shw_r _ q = pw_show False (rl q) (rl q)"

fun wind_head :: "rat option \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "wind_head None P = STR ''The power in the wind is '' + P"
| "wind_head (Some _) P = STR ''The power is '' + P"

definition wind_text :: "rat \<Rightarrow> rat \<Rightarrow> rat option \<Rightarrow> String.literal \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "wind_text v rho cp P geotext = wind_head cp P + STR '' (1/2 rho A v^3'' + (case cp of None \<Rightarrow> STR '''' | Some _ \<Rightarrow> STR '' Cp'')
     + STR '' = 1/2 x '' + g3 rho + STR '' x A x '' + g3 v + STR ''^3'' + (case cp of None \<Rightarrow> STR '''' | Some c \<Rightarrow> STR '' x '' + g3 c)
     + STR ''; '' + geotext + STR '').''"

fun exact_text_r :: "ren_req \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text_r (RHydro q h e) p V = STR ''The power is '' + V + STR '' (P = rho g Q h eta = 1000 x 9.81 x ''
     + g3 q + STR '' m3/s x '' + g3 h + STR '' m x '' + g3 e + STR '').''"
| "exact_text_r (RPV a i e) p V = STR ''The output is '' + V + STR '' (area '' + g3 a + STR '' m2 x irradiance ''
     + g3 (irr_val i) + STR '' W/m2'' + (case i of Irr_stc \<Rightarrow> STR '' (1,000 W/m2, standard test conditions)'' | _ \<Rightarrow> STR '''')
     + STR '' x efficiency '' + g3 (e * 100) + STR ''%).''"
| "exact_text_r (RCapF r e h) p V = STR ''The capacity factor is '' + V + STR ''% ('' + pwt True e + STR '' / (''
     + pwt False r + STR '' x '' + g3 h + STR '' h)).''"
| "exact_text_r (RAnnual r h c) p V = STR ''The energy is '' + V + STR '' ('' + pwt False r + STR '' x '' + g3 h
     + STR '' h x '' + g3 (c * 100) + STR ''% capacity factor).''"
| "exact_text_r (RRatio v1 v2) p V = STR ''The power changes by a factor of '' + V + STR '' (('' + g3 v2 + STR '' / ''
     + g3 v1 + STR '')^3 - power goes as wind speed cubed).''"
| "exact_text_r (RWind (G_swept a) v rho cp) p V = wind_text v rho cp V (STR ''swept area '' + g3 a + STR '' m2'')"
| "exact_text_r (RWind _ v rho cp) p V = V"

definition pit_r :: "ren_req \<Rightarrow> rat \<Rightarrow> String.literal option" where
  "pit_r r c = (case r of
       RWind (G_diam d) v rho cp \<Rightarrow>
         (case pi_bounds c of None \<Rightarrow> None | Some (lo, hi) \<Rightarrow>
          (case (pw_show False lo hi, pi_fmt F3C (d * d / 4)) of
             (Some P, Some A) \<Rightarrow> Some (wind_text v rho cp P (STR ''A = pi(D/2)^2 = '' + A + STR '' m2''))
           | _ \<Rightarrow> None))
     | RWind (G_rad rr) v rho cp \<Rightarrow>
         (case pi_bounds c of None \<Rightarrow> None | Some (lo, hi) \<Rightarrow>
          (case (pw_show False lo hi, pi_fmt F3C (rr * rr)) of
             (Some P, Some A) \<Rightarrow> Some (wind_text v rho cp P (STR ''A = pi x '' + g3 rr + STR ''^2 = '' + A + STR '' m2''))
           | _ \<Rightarrow> None))
     | _ \<Rightarrow> None)"

definition reply_r :: "ren_req \<Rightarrow> reply" where
  "reply_r = mk_reply kernel_r shw_r (\<lambda>_. False) exact_text_r pit_r (\<lambda>_ _. STR '''')"

theorem reply_r_withheld:
  assumes "kernel_r r = Decline d w"
  shows "\<not> answered (reply_r r) \<and> response (reply_r r) = decline_text d w"
  using assms by (simp add: reply_r_def mk_reply_def)

theorem reply_r_answered_iff:
  "answered (reply_r r) \<longleftrightarrow>
     (\<exists>k q V. kernel_r r = Exact k q \<and> shw_r r q = Some V) \<or> (\<exists>k c s. kernel_r r = PiMul k c \<and> pit_r r c = Some s)"
  by (simp add: reply_r_def kernel_r_def mk_reply_answered_iff mk_fixed)

text \<open>A stated power is in the unit the value's size picks, and its digits are
within the layout's rounding of the exact value.\<close>
theorem reply_r_power_units:
  assumes "pw_show en x x = Some t"
  shows "\<exists>s i d. pw_scale x x = Some (s, i) \<and> 0 < s \<and> (s = 1 \<or> s \<le> x) \<and> (x < 1000 * s \<or> i = 3) \<and>
         num_dec_r F3C (x / s) = Some d \<and> \<bar>dec_val d - x / s\<bar> \<le> fmt_err_r F3C (x / s)"
proof -
  from pw_show_sound[OF assms] obtain s i d where h: "pw_scale x x = Some (s, i)"
    "num_dec_r F3C ((x + x) / 2 / s) = Some d" "\<bar>dec_val d - (x + x) / 2 / s\<bar> \<le> fmt_err_r F3C ((x + x) / 2 / s)" by blast
  have sc: "0 < s \<and> (s = 1 \<or> s \<le> x) \<and> (x < 1000 * s \<or> i = 3)" using pw_scale_sound[OF h(1)] .
  have m: "(x + x) / 2 / s = x / s" by simp
  have "pw_scale x x = Some (s, i) \<and> 0 < s \<and> (s = 1 \<or> s \<le> x) \<and> (x < 1000 * s \<or> i = 3) \<and>
         num_dec_r F3C (x / s) = Some d \<and> \<bar>dec_val d - x / s\<bar> \<le> fmt_err_r F3C (x / s)"
    using h(1) sc h(2,3) m by simp
  then show ?thesis by blast
qed

end
