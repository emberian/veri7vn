theory Earth_Ocean
  imports Earth_Num
begin

text \<open>
  Oracle7 Oceanography (upstream/root/specialists/ocean/organ_ocean_v1.py): shallow-water
  (tsunami) wave speed and travel time, deep-water wave speed and wavelength from the
  period, pressure with depth, and echo-sounding depth. g = 9.81 m/s2, seawater 1025 kg/m3
  and sound 1500 m/s unless given. The organ has no in-domain declines.
\<close>

definition grav :: rat where "grav = 981 / 100"
definition atm_kpa :: rat where "atm_kpa = 101325 / 1000"

datatype ocean_req =
    OSonar rat rat bool
  | OPressure rat rat bool
  | OTsunamiSpeed rat
  | OTsunamiTime rat rat
  | ODeepSpeed rat
  | ODeepGroupSpeed rat
  | ODeepWL rat

section \<open>Declines\<close>

fun oc_feasible :: "ocean_req \<Rightarrow> bool" where
  "oc_feasible (OSonar t v _) = (0 \<le> t \<and> 0 < v)"
| "oc_feasible (OPressure d rho _) = (0 \<le> d \<and> 0 < rho)"
| "oc_feasible (OTsunamiSpeed d) = (0 \<le> d)"
| "oc_feasible (OTsunamiTime d km) = (0 < d \<and> 0 \<le> km)"
| "oc_feasible (ODeepSpeed t) = (0 < t)"
| "oc_feasible (ODeepGroupSpeed t) = (0 < t)"
| "oc_feasible (ODeepWL t) = (0 < t)"

fun oc_bad_input_text :: "ocean_req \<Rightarrow> String.literal" where
  "oc_bad_input_text (OSonar _ _ _) = STR ''Echo time cannot be negative and sound speed must be positive.''"
| "oc_bad_input_text (OPressure _ _ _) = STR ''Water depth cannot be negative and density must be positive.''"
| "oc_bad_input_text (OTsunamiSpeed _) = STR ''Water depth cannot be negative.''"
| "oc_bad_input_text (OTsunamiTime _ _) = STR ''Wave travel needs positive water depth and a nonnegative travel distance.''"
| "oc_bad_input_text (ODeepSpeed _) = STR ''A wave period must be positive.''"
| "oc_bad_input_text (ODeepGroupSpeed _) = STR ''A wave period must be positive.''"
| "oc_bad_input_text (ODeepWL _) = STR ''A wave period must be positive.''"

definition oc_impossible :: "ocean_req \<Rightarrow> String.literal option" where
  "oc_impossible r = (if oc_feasible r then None else Some (oc_bad_input_text r))"

declare oc_impossible_def [simp]

section \<open>Values\<close>

definition sqrt_gd_fa :: "rat \<Rightarrow> floatarith" where
  "sqrt_gd_fa d = floatarith.Sqrt (Q (grav * d))"

definition oc_xval :: "ocean_req \<Rightarrow> xexpr" where
  "oc_xval r = (case r of
      OSonar t v _ \<Rightarrow> XRat (v * t / 2)
    | OPressure d rho ab \<Rightarrow> XRat (rho * grav * d / 1000 + (if ab then atm_kpa else 0))
    | OTsunamiSpeed d \<Rightarrow> XFa dprec (sqrt_gd_fa d)
    | OTsunamiTime d km \<Rightarrow> XFa dprec (floatarith.Mult (Q (km * 1000 / 3600)) (floatarith.Inverse (sqrt_gd_fa d)))
    | ODeepSpeed t \<Rightarrow> XFa dprec (floatarith.Mult (Q (grav * t / 2)) (floatarith.Inverse floatarith.Pi))
    | ODeepGroupSpeed t \<Rightarrow> XFa dprec (floatarith.Mult (Q (grav * t / 4)) (floatarith.Inverse floatarith.Pi))
    | ODeepWL t \<Rightarrow> XFa dprec (floatarith.Mult (Q (grav * t * t / 2)) (floatarith.Inverse floatarith.Pi)))"

definition oc_phys :: "ocean_req \<Rightarrow> real" where
  "oc_phys r = (case r of
      OSonar t v _ \<Rightarrow> rl v * rl t / 2
    | OPressure d rho ab \<Rightarrow> rl rho * rl grav * rl d / 1000 + (if ab then rl atm_kpa else 0)
    | OTsunamiSpeed d \<Rightarrow> sqrt (rl grav * rl d)
    | OTsunamiTime d km \<Rightarrow> rl km * 1000 / sqrt (rl grav * rl d) / 3600
    | ODeepSpeed t \<Rightarrow> rl grav * rl t / (2 * pi)
    | ODeepGroupSpeed t \<Rightarrow> rl grav * rl t / (4 * pi)
    | ODeepWL t \<Rightarrow> rl grav * rl t ^ 2 / (2 * pi))"

definition oc_kernel :: "ocean_req \<Rightarrow> outcome" where
  "oc_kernel r = (case oc_impossible r of Some w \<Rightarrow> Decline (Imposs w) | None \<Rightarrow> Value (oc_xval r))"

theorem oc_impossible_iff:
  "oc_kernel r = Decline (Imposs w) \<longleftrightarrow> oc_impossible r = Some w"
  by (auto simp: oc_kernel_def split: option.splits if_splits)

lemma oc_value_cases: "oc_kernel r = Value x \<Longrightarrow> oc_impossible r = None \<and> x = oc_xval r"
  by (auto simp: oc_kernel_def split: option.splits if_splits)

lemma oc_not_word: "oc_kernel r \<noteq> Word t" "oc_kernel r \<noteq> Note"
  by (auto simp: oc_kernel_def split: option.splits if_splits)

lemma interp_sqrt_gd [simp]: "interpret_floatarith (sqrt_gd_fa d) xs = sqrt (rl grav * rl d)"
  by (simp add: sqrt_gd_fa_def of_rat_mult)

theorem oc_value_sound:
  assumes "oc_kernel r = Value x"
  shows "oc_impossible r = None \<and> xsem x = oc_phys r"
proof -
  have c: "oc_impossible r = None" "x = oc_xval r" using oc_value_cases[OF assms] by auto
  have g0: "rl grav \<noteq> 0" by (simp add: grav_def)
  have "xsem (oc_xval r) = oc_phys r"
  proof (cases r)
    case (OSonar t v st) then show ?thesis by (simp add: oc_xval_def oc_phys_def of_rat_mult of_rat_divide)
  next
    case (OPressure d rho ab)
    then show ?thesis by (cases ab) (simp_all add: oc_xval_def oc_phys_def of_rat_mult of_rat_divide of_rat_add)
  next
    case (OTsunamiSpeed d)
    then show ?thesis by (simp add: oc_xval_def oc_phys_def of_rat_mult)
  next
    case (OTsunamiTime d km)
    then show ?thesis by (simp add: oc_xval_def oc_phys_def of_rat_mult of_rat_divide field_simps)
  next
    case (ODeepSpeed t)
    then show ?thesis by (simp add: oc_xval_def oc_phys_def of_rat_mult of_rat_divide field_simps)
  next
    case (ODeepGroupSpeed t)
    then show ?thesis by (simp add: oc_xval_def oc_phys_def of_rat_mult of_rat_divide field_simps)
  next
    case (ODeepWL t)
    then show ?thesis by (simp add: oc_xval_def oc_phys_def of_rat_mult of_rat_divide power2_eq_square field_simps)
  qed
  then show ?thesis using c by simp
qed

section \<open>What each kind means\<close>

theorem shallow_speed_squared:
  assumes k: "oc_kernel (OTsunamiSpeed d) = Value x" "0 \<le> d"
  shows "(xsem x) ^ 2 = rl grav * rl d \<and> 0 \<le> xsem x"
proof -
  have e: "xsem x = sqrt (rl grav * rl d)" using oc_value_sound[OF k(1)] by (simp add: oc_phys_def)
  have g0: "0 \<le> rl grav" by (simp add: grav_def)
  have d0: "0 \<le> rl d" using k(2) by (simp add: zero_le_of_rat_iff)
  have p: "0 \<le> rl grav * rl d" using g0 d0 by (rule mult_nonneg_nonneg)
  show ?thesis using e p by (simp add: real_sqrt_pow2)
qed

theorem tsunami_time_times_speed:
  assumes "0 < d"
  shows "oc_phys (OTsunamiTime d km) * 3600 * sqrt (rl grav * rl d) = rl km * 1000"
proof -
  have g: "0 < rl grav" by (simp add: grav_def)
  have dd: "0 < rl d" using assms by (simp add: zero_less_of_rat_iff)
  have pos: "0 < sqrt (rl grav * rl d)" by (rule real_sqrt_gt_zero) (rule mult_pos_pos[OF g dd])
  then have ne: "sqrt (rl grav * rl d) \<noteq> 0" by (rule less_imp_neq[THEN not_sym])
  have gne: "grav \<noteq> 0" by (simp add: grav_def)
  have dne: "d \<noteq> 0" using assms by simp
  show ?thesis by (simp add: oc_phys_def field_simps ne gne dne)
qed

theorem deep_wavelength_is_speed_times_period:
  "oc_phys (ODeepWL t) = oc_phys (ODeepSpeed t) * rl t"
  by (simp add: oc_phys_def power2_eq_square algebra_simps)

theorem deep_speed_relation: "oc_phys (ODeepSpeed t) * (2 * pi) = rl grav * rl t"
proof -
  have ne: "2 * pi \<noteq> 0" by simp
  show ?thesis by (simp add: oc_phys_def field_simps ne)
qed

theorem sonar_round_trip: "oc_phys (OSonar t v s) * 2 = rl v * rl t"
  by (simp add: oc_phys_def field_simps)

theorem absolute_pressure_adds_atmosphere:
  "oc_phys (OPressure d rho True) = oc_phys (OPressure d rho False) + rl atm_kpa"
  by (simp add: oc_phys_def)

section \<open>Physical feasibility of successful requests\<close>

theorem ocean_success_feasible:
  "oc_kernel r = Value x \<Longrightarrow> oc_feasible r"
  using oc_value_cases[of r x] by (auto split: if_splits)

theorem ocean_impossible_exact:
  "(\<exists>w. oc_kernel r = Decline (Imposs w)) \<longleftrightarrow> \<not> oc_feasible r"
  by (auto simp: oc_kernel_def)

theorem sonar_value_physical:
  assumes k: "oc_kernel (OSonar t v st) = Value x"
  shows "0 \<le> t \<and> 0 < v \<and> 0 \<le> xsem x \<and> xsem x * 2 = rl v * rl t"
proof -
  have dom: "0 \<le> t" "0 < v" using ocean_success_feasible[OF k] by auto
  have t0: "0 \<le> rl t" using dom(1) by (simp add: zero_le_of_rat_iff)
  have v0: "0 \<le> rl v" using dom(2) by (simp add: zero_le_of_rat_iff less_imp_le)
  have eq: "xsem x = rl v * rl t / 2" using oc_value_sound[OF k] by (simp add: oc_phys_def)
  have product_nonnegative: "0 \<le> rl v * rl t"
    by (rule mult_nonneg_nonneg[OF v0 t0])
  have result_nonnegative: "0 \<le> xsem x" using eq product_nonnegative by linarith
  have round_trip: "xsem x * 2 = rl v * rl t" using eq by linarith
  show ?thesis using dom result_nonnegative round_trip by blast
qed

theorem pressure_value_increment:
  assumes a: "oc_kernel (OPressure d1 rho ab) = Value x"
      and b: "oc_kernel (OPressure d2 rho ab) = Value y"
  shows "(xsem y - xsem x) * 1000 = rl rho * rl grav * (rl d2 - rl d1)"
  using oc_value_sound[OF a] oc_value_sound[OF b]
  by (simp add: oc_phys_def algebra_simps)

theorem wave_travel_value_law:
  assumes k: "oc_kernel (OTsunamiTime d km) = Value x"
  shows "0 < d \<and> 0 \<le> km \<and> xsem x * 3600 * sqrt (rl grav * rl d) = rl km * 1000"
  using ocean_success_feasible[OF k] oc_value_sound[OF k] tsunami_time_times_speed[of d km]
  by auto

section \<open>Group velocity from the dispersion relation\<close>

definition deep_omega :: "real \<Rightarrow> real" where
  "deep_omega k = sqrt (rl grav * k)"

lemma deep_dispersion_derivative:
  assumes "0 < k"
  shows "DERIV deep_omega k :> (rl grav / (2 * deep_omega k))"
proof -
  have p: "0 < rl grav * k" using assms by (simp add: grav_def)
  have sq: "DERIV sqrt (rl grav * k) :> inverse (sqrt (rl grav * k)) / 2"
    by (rule DERIV_real_sqrt[OF p])
  have lin: "DERIV (\<lambda>x. rl grav * x) k :> rl grav" by simp
  have omega_fun: "deep_omega = (\<lambda>x. sqrt (rl grav * x))"
    by (rule ext) (simp add: deep_omega_def)
  have "DERIV (\<lambda>x. sqrt (rl grav * x)) k :> (inverse (sqrt (rl grav * k)) / 2 * rl grav)"
    by (rule DERIV_chain2[OF sq lin])
  then show ?thesis by (simp only: omega_fun divide_inverse inverse_mult_distrib mult.assoc mult.commute mult.left_commute)
qed

theorem group_speed_is_dispersion_derivative:
  assumes answer: "oc_kernel (ODeepGroupSpeed t) = Value x"
      and wave: "0 < k" "deep_omega k * rl t = 2 * pi"
  shows "DERIV deep_omega k :> xsem x"
proof -
  have semantic_eq: "xsem x = rl grav * rl t / (4 * pi)"
    using oc_value_sound[OF answer] by (simp add: oc_phys_def)
  have pos: "0 < deep_omega k" using wave(1)
    by (simp add: deep_omega_def grav_def)
  have period: "rl t = 2 * pi / deep_omega k"
    using wave(2) pos by (simp add: field_simps mult.commute)
  have same: "rl grav * rl t / (4 * pi) = rl grav / (2 * deep_omega k)"
    unfolding period by (simp add: field_simps)
  show ?thesis using deep_dispersion_derivative[OF wave(1)] semantic_eq same by simp
qed

theorem group_speed_half_phase:
  assumes "oc_kernel (ODeepGroupSpeed t) = Value x" "oc_kernel (ODeepSpeed t) = Value y"
  shows "2 * xsem x = xsem y"
proof -
  have group_eq: "xsem x = rl grav * rl t / (4 * pi)"
    using oc_value_sound[OF assms(1)] by (simp add: oc_phys_def)
  have phase_eq: "xsem y = rl grav * rl t / (2 * pi)"
    using oc_value_sound[OF assms(2)] by (simp add: oc_phys_def)
  show ?thesis unfolding group_eq phase_eq by (simp add: field_simps)
qed

section \<open>Text\<close>

fun oc_kind :: "ocean_req \<Rightarrow> String.literal" where
  "oc_kind (OSonar _ _ _) = STR ''sonar_depth''"
| "oc_kind (OPressure _ _ ab) = (if ab then STR ''pressure_abs'' else STR ''pressure'')"
| "oc_kind (OTsunamiSpeed _) = STR ''shallow_speed''"
| "oc_kind (OTsunamiTime _ _) = STR ''tsunami_time''"
| "oc_kind (ODeepSpeed _) = STR ''deep_speed''"
| "oc_kind (ODeepGroupSpeed _) = STR ''deep_group_speed''"
| "oc_kind (ODeepWL _) = STR ''deep_wavelength''"

definition o1 :: "rat \<Rightarrow> String.literal" where "o1 q = showx GOcean (XRat q)"

fun oc_text :: "ocean_req \<Rightarrow> xexpr \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "oc_text (OSonar t v st) x V = STR ''The depth is '' + V + STR '' m ('' + o1 v + STR '' m/s x '' + o1 t
     + STR '' s / 2 for the round trip'' + (if st then STR '''' else STR ''; 1,500 m/s typical seawater'') + STR '').''"
| "oc_text (OPressure d rho ab) x V =
     (if ab then STR ''The absolute pressure is '' + V + STR '' kPa (rho g h + 101.325 kPa = '' + o1 rho
        + STR '' x 9.81 x '' + o1 d + STR '' m + 1 atm).''
      else STR ''The gauge pressure is '' + V + STR '' kPa (rho g h = '' + o1 rho + STR '' kg/m3 x 9.81 x '' + o1 d
        + STR '' m; add 101.325 kPa for absolute).'')"
| "oc_text (OTsunamiSpeed d) x V = STR ''The wave speed is '' + V + STR '' m/s ('' + showx GOcean (scale_x (18 / 5) x)
     + STR '' km/h; c = sqrt(g d) = sqrt(9.81 x '' + o1 d + STR '' m), shallow-water wave).''"
| "oc_text (OTsunamiTime d km) x V = STR ''The travel time is '' + V + STR '' hours ('' + o1 km + STR '' km / ''
     + showx GOcean (XFa dprec (sqrt_gd_fa d)) + STR '' m/s, c = sqrt(g d) = sqrt(9.81 x '' + o1 d + STR '' m)).''"
| "oc_text (ODeepSpeed t) x V = STR ''The wave speed is '' + V + STR '' m/s (c = g T / 2pi = 9.81 x '' + o1 t
     + STR '' / 2pi; deep water).''"
| "oc_text (ODeepGroupSpeed t) x V = STR ''The group velocity is '' + V + STR '' m/s (d omega/d k = g T / 4pi; deep-water gravity-wave dispersion).''"
| "oc_text (ODeepWL t) x V = STR ''The wavelength is '' + V + STR '' m (L = g T^2 / 2pi = 9.81 x '' + o1 t
     + STR ''^2 / 2pi; deep water).''"

definition oc_reply :: "ocean_req \<Rightarrow> reply" where
  "oc_reply r = (case oc_kernel r of
      Value x \<Rightarrow> reply_val GOcean (oc_kind r) (oc_text r x) x
    | Decline w \<Rightarrow> decline_reply (oc_kind r) w
    | _ \<Rightarrow> decline_reply (oc_kind r) Imprecise)"

theorem oc_answered_iff:
  "answered (oc_reply r) \<longleftrightarrow> (\<exists>x s. oc_kernel r = Value x \<and> render_x GOcean x = Some s)"
  using oc_not_word[of r] by (cases "oc_kernel r")
    (auto simp: oc_reply_def reply_val_def decline_reply_def split: option.splits decl.splits)

end
