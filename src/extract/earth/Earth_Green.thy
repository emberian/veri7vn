theory Earth_Green
  imports Earth_Num
begin

text \<open>
  Oracle7 Greenhouse & Controlled Agriculture (upstream/root/specialists/greenhouse/organ_greenhouse_v1.py,
  and greenhouse-r2, which wraps the same organ in a boundary check that lives in the recognizer):
  vapour pressure deficit (Tetens / FAO-56), daily light integral and the PPFD a target needs,
  growing degree days with a stated base, and plants per area. The GDD base temperature is never
  assumed.
\<close>

datatype gunit = GC | GF
datatype lunit = LCm | LM | LIn | LFt
datatype garea = GaM2 | GaFt2

datatype gh_req =
    GhVpd "rat option" gunit "rat option" gunit "rat option" bool
  | GhDli "rat option" "rat option"
  | GhPpfd rat rat
  | GhGdd "rat option" "rat option" "rat option"
  | GhPlants "rat option" garea "rat option" lunit "rat option" lunit

definition g_to_c :: "rat \<Rightarrow> gunit \<Rightarrow> rat" where
  "g_to_c v u = (if u = GF then (v - 32) * 5 / 9 else v)"

fun len_m :: "lunit \<Rightarrow> rat" where
  "len_m LCm = 1 / 100" | "len_m LM = 1" | "len_m LIn = 254 / 10000" | "len_m LFt = 3048 / 10000"

fun area_m2 :: "garea \<Rightarrow> rat" where
  "area_m2 GaM2 = 1" | "area_m2 GaFt2 = 9290304 / 100000000"

definition tetens_a :: rat where "tetens_a = 6108 / 10000"
definition tetens_b :: rat where "tetens_b = 1727 / 100"
definition tetens_c :: rat where "tetens_c = 2373 / 10"

section \<open>Declines\<close>

definition w_gh_temp_rh :: String.literal where "w_gh_temp_rh = STR ''the air temperature and the relative humidity''"

fun gh_missing :: "gh_req \<Rightarrow> String.literal option" where
  "gh_missing (GhVpd air au leaf lu rh anyt) =
     (if \<not> anyt \<or> rh = None then Some w_gh_temp_rh
      else if air = None then Some (STR ''the air temperature as well as the leaf temperature'') else None)"
| "gh_missing (GhDli p h) = (if p = None \<or> h = None then Some (STR ''the PPFD (umol/m2/s) and the hours of light'') else None)"
| "gh_missing (GhPpfd d h) = None"
| "gh_missing (GhGdd hi lo b) =
     (if hi = None \<or> lo = None then Some (STR ''the day'' + apos + STR ''s high and low temperatures'')
      else if b = None then Some (STR ''the base temperature (it depends on the crop)'') else None)"
| "gh_missing (GhPlants a au s1 u1 s2 u2) =
     (if a = None \<or> s1 = None \<or> s2 = None then Some (STR ''the growing area and both the row and in-row spacing'')
      else None)"

definition pole_ok :: "rat \<Rightarrow> gunit \<Rightarrow> bool" where
  "pole_ok v u \<longleftrightarrow> tetens_c + g_to_c v u \<noteq> 0"

fun gh_impossible :: "gh_req \<Rightarrow> String.literal option" where
  "gh_impossible (GhVpd (Some ta) au leaf lu (Some rh) anyt) =
     (if \<not> (0 \<le> rh \<and> rh \<le> 100) then Some (STR ''Relative humidity must be between 0 and 100%.'')
      else if \<not> pole_ok ta au then Some (STR ''That temperature is at the Tetens pole.'')
      else (case leaf of Some lf \<Rightarrow> (if pole_ok lf lu then None else Some (STR ''That temperature is at the Tetens pole.''))
                       | None \<Rightarrow> None))"
| "gh_impossible (GhPpfd d h) = (if h \<le> 0 then Some (STR ''The photoperiod must be longer than zero hours.'') else None)"
| "gh_impossible (GhGdd (Some hi) (Some lo) (Some b)) =
     (if hi < lo then Some (STR ''The low can'' + apos + STR ''t be above the high.'') else None)"
| "gh_impossible (GhPlants (Some a) au (Some s1) u1 (Some s2) u2) =
     (if s1 * len_m u1 \<le> 0 \<or> s2 * len_m u2 \<le> 0 then Some (STR ''Spacings must be positive.'') else None)"
| "gh_impossible _ = None"

section \<open>Values\<close>

definition es_fa :: "rat \<Rightarrow> floatarith" where
  "es_fa t = floatarith.Mult (Q tetens_a) (floatarith.Exp (Q (tetens_b * t / (t + tetens_c))))"

definition es_spec :: "rat \<Rightarrow> real" where
  "es_spec t = rl tetens_a * exp (rl (tetens_b * t / (t + tetens_c)))"

lemma interp_es_fa [simp]: "interpret_floatarith (es_fa t) xs = es_spec t"
  by (simp add: es_fa_def es_spec_def)

lemma rl_max: "rl (max a b) = max (rl a) (rl b)"
  by (cases "a \<le> b") (simp_all add: max_def of_rat_less_eq)

definition opt0 :: "rat option \<Rightarrow> rat" where "opt0 x = (case x of Some v \<Rightarrow> v | None \<Rightarrow> 0)"

definition gh_count :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> int" where
  "gh_count area a b = \<lfloor>area / (a * b) + 1 / 1000000000\<rfloor>"

fun gh_xval :: "gh_req \<Rightarrow> xexpr" where
  "gh_xval (GhVpd (Some ta) au (Some tlf) lu (Some rh) anyt) =
     XFa dprec (fsub (es_fa (g_to_c tlf lu)) (floatarith.Mult (es_fa (g_to_c ta au)) (Q (rh / 100))))"
| "gh_xval (GhVpd (Some ta) au None lu (Some rh) anyt) =
     XFa dprec (floatarith.Mult (es_fa (g_to_c ta au)) (Q (1 - rh / 100)))"
| "gh_xval (GhDli (Some p) (Some h)) = XRat (p * h * 3600 / 1000000)"
| "gh_xval (GhPpfd d h) = XRat (d * 1000000 / (h * 3600))"
| "gh_xval (GhGdd (Some hi) (Some lo) (Some b)) = XRat (max 0 ((hi + lo) / 2 - b))"
| "gh_xval (GhPlants (Some a) au (Some s1) u1 (Some s2) u2) =
     XRat (of_int (gh_count (a * area_m2 au) (s1 * len_m u1) (s2 * len_m u2)))"
| "gh_xval _ = XRat 0"

fun gh_phys :: "gh_req \<Rightarrow> real" where
  "gh_phys (GhVpd (Some ta) au (Some tlf) lu (Some rh) anyt) =
     es_spec (g_to_c tlf lu) - es_spec (g_to_c ta au) * rl (rh / 100)"
| "gh_phys (GhVpd (Some ta) au None lu (Some rh) anyt) = es_spec (g_to_c ta au) * rl (1 - rh / 100)"
| "gh_phys (GhDli (Some p) (Some h)) = rl p * rl h * 3600 / 1000000"
| "gh_phys (GhPpfd d h) = rl d * 1000000 / (rl h * 3600)"
| "gh_phys (GhGdd (Some hi) (Some lo) (Some b)) = max 0 ((rl hi + rl lo) / 2 - rl b)"
| "gh_phys (GhPlants (Some a) au (Some s1) u1 (Some s2) u2) =
     real_of_int (gh_count (a * area_m2 au) (s1 * len_m u1) (s2 * len_m u2))"
| "gh_phys _ = 0"

definition gh_kernel :: "gh_req \<Rightarrow> outcome" where
  "gh_kernel r = (case gh_missing r of Some w \<Rightarrow> Decline (Under w)
     | None \<Rightarrow> (case gh_impossible r of Some w \<Rightarrow> Decline (Imposs w) | None \<Rightarrow> Value (gh_xval r)))"

theorem gh_underspecified: "gh_kernel r = Decline (Under w) \<longleftrightarrow> gh_missing r = Some w"
  by (auto simp: gh_kernel_def split: option.splits)

theorem gh_impossible_iff:
  "gh_kernel r = Decline (Imposs w) \<longleftrightarrow> gh_missing r = None \<and> gh_impossible r = Some w"
  by (auto simp: gh_kernel_def split: option.splits)

lemma gh_value_cases:
  "gh_kernel r = Value x \<Longrightarrow> gh_missing r = None \<and> gh_impossible r = None \<and> x = gh_xval r"
  by (auto simp: gh_kernel_def split: option.splits)

lemma gh_not_word: "gh_kernel r \<noteq> Word t" "gh_kernel r \<noteq> Note"
  by (auto simp: gh_kernel_def split: option.splits)

theorem gh_value_sound:
  assumes "gh_kernel r = Value x"
  shows "gh_missing r = None \<and> gh_impossible r = None \<and> xsem x = gh_phys r"
proof -
  have c: "gh_missing r = None" "gh_impossible r = None" "x = gh_xval r"
    using gh_value_cases[OF assms] by auto
  have "xsem (gh_xval r) = gh_phys r"
  proof (cases r)
    case (GhVpd ta au tlf lu rh anyt)
    then show ?thesis
      by (cases ta; cases tlf; cases rh) (simp_all add: of_rat_mult of_rat_divide of_rat_diff)
  next
    case (GhDli p h)
    then show ?thesis by (cases p; cases h) (simp_all add: of_rat_mult of_rat_divide)
  next
    case (GhPpfd d h)
    then show ?thesis by (simp add: of_rat_mult of_rat_divide)
  next
    case (GhGdd hi lo b)
    then show ?thesis
      by (cases hi; cases lo; cases b)
         (simp_all add: rl_max of_rat_divide of_rat_add of_rat_diff)
  next
    case (GhPlants a au s1 u1 s2 u2)
    then show ?thesis by (cases a; cases s1; cases s2) simp_all
  qed
  then show ?thesis using c by simp
qed

section \<open>What each kind means\<close>

text \<open>The deficit plus the actual vapour pressure is the saturation vapour pressure.\<close>
theorem vpd_air_complements_vapour_pressure:
  "gh_phys (GhVpd (Some ta) au None lu (Some rh) anyt) + es_spec (g_to_c ta au) * (rl rh / 100)
   = es_spec (g_to_c ta au)"
  by (simp add: of_rat_diff of_rat_divide algebra_simps)

theorem vpd_leaf_difference:
  "gh_phys (GhVpd (Some ta) au (Some tlf) lu (Some rh) anyt)
   = es_spec (g_to_c tlf lu) - es_spec (g_to_c ta au) * (rl rh / 100)"
  by (simp add: of_rat_divide)

theorem saturation_pressure_positive: "0 < es_spec t"
  by (simp add: es_spec_def tetens_a_def)

theorem vpd_nonneg_at_leaf_equals_air:
  assumes "0 \<le> rh" "rh \<le> 100"
  shows "0 \<le> gh_phys (GhVpd (Some ta) au None lu (Some rh) anyt)"
proof -
  have a0: "0 \<le> (1::rat) - rh / 100" using assms(2) by linarith
  have a: "0 \<le> rl (1 - rh / 100)" using a0 by (simp add: zero_le_of_rat_iff)
  have "0 < es_spec (g_to_c ta au)" by (rule saturation_pressure_positive)
  then show ?thesis using a by (simp add: mult_nonneg_nonneg)
qed

theorem dli_definition:
  "gh_phys (GhDli (Some p) (Some h)) * 1000000 = rl p * rl h * 3600"
  by (simp add: field_simps)

theorem ppfd_needed_reaches_target:
  assumes "0 < h"
  shows "gh_phys (GhPpfd d h) * (rl h * 3600) = rl d * 1000000"
proof -
  have "rl h \<noteq> 0" using assms by (simp add: zero_less_of_rat_iff)
  then have ne: "rl h * 3600 \<noteq> 0" by simp
  have hne: "h \<noteq> 0" using assms by simp
  show ?thesis by (simp add: field_simps ne hne)
qed

theorem ppfd_inverts_dli:
  assumes "0 < h"
  shows "gh_phys (GhDli (Some (d * 1000000 / (h * 3600))) (Some h)) = rl d"
proof -
  have "rl h \<noteq> 0" using assms by (simp add: zero_less_of_rat_iff)
  then show ?thesis by (simp add: of_rat_mult of_rat_divide field_simps)
qed

theorem gdd_nonneg: "0 \<le> gh_phys (GhGdd (Some hi) (Some lo) (Some b))"
  by simp

theorem plant_count_bounds:
  assumes "0 < a * b"
  shows "of_int (gh_count area a b) \<le> area / (a * b) + 1 / 1000000000 \<and>
         area / (a * b) + 1 / 1000000000 < of_int (gh_count area a b) + 1"
  unfolding gh_count_def using floor_correct[of "area / (a * b) + 1 / 1000000000"] by simp

section \<open>Text\<close>

fun gh_kind :: "gh_req \<Rightarrow> String.literal" where
  "gh_kind (GhVpd _ _ leaf _ _ _) = (if leaf = None then STR ''vpd'' else STR ''vpd_leaf'')"
| "gh_kind (GhDli _ _) = STR ''dli''"
| "gh_kind (GhPpfd _ _) = STR ''ppfd_needed''"
| "gh_kind (GhGdd _ _ _) = STR ''gdd''"
| "gh_kind (GhPlants _ _ _ _ _ _) = STR ''plant_count''"

definition gx :: "rat \<Rightarrow> String.literal" where "gx q = showx (GFix L4) (XRat q)"
definition go :: "rat option \<Rightarrow> String.literal" where "go q = gx (opt0 q)"

fun gh_text :: "gh_req \<Rightarrow> xexpr \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "gh_text (GhVpd ta au None lu rh anyt) x V =
     STR ''The VPD is '' + V + STR '' kPa (es = 0.6108 exp(17.27 T/(T+237.3)) = ''
     + showx (GFix L4) (XFa dprec (es_fa (g_to_c (opt0 ta) au))) + STR '' kPa at '' + gx (g_to_c (opt0 ta) au)
     + STR '' C, x (1 - '' + go rh + STR ''%); Tetens / FAO-56).''"
| "gh_text (GhVpd ta au (Some tlf) lu rh anyt) x V =
     STR ''The leaf VPD is '' + V + STR '' kPa (es at the '' + gx (g_to_c tlf lu) + STR '' C leaf - ea of ''
     + gx (g_to_c (opt0 ta) au) + STR '' C air at '' + go rh + STR ''% RH; Tetens / FAO-56).''"
| "gh_text (GhDli p h) x V =
     STR ''The DLI is '' + V + STR '' mol/m2/d (PPFD '' + go p + STR '' umol/m2/s x '' + go h + STR '' h x 3600 s / 10^6).''"
| "gh_text (GhPpfd d h) x V =
     STR ''The PPFD needed is '' + V + STR '' umol/m2/s (DLI '' + gx d + STR '' mol/m2/d x 10^6 / ('' + gx h
     + STR '' h x 3600 s)).''"
| "gh_text (GhGdd hi lo b) x V =
     STR ''That is '' + V + STR '' growing degree days (('' + go hi + STR '' + '' + go lo + STR '')/2 - '' + go b
     + STR '', floored at 0).''"
| "gh_text (GhPlants a au s1 u1 s2 u2) x V =
     STR ''About '' + V + STR '' plants fit ('' + gx (opt0 a * area_m2 au) + STR '' m2 / ('' + gx (opt0 s1 * len_m u1)
     + STR '' m x '' + gx (opt0 s2 * len_m u2) + STR '' m) per plant, rounded down).''"

fun gh_fmt :: "gh_req \<Rightarrow> gfmt" where
  "gh_fmt (GhPlants _ _ _ _ _ _) = GFix (LP 0)"
| "gh_fmt r = GFix L4"

definition gh_reply :: "gh_req \<Rightarrow> reply" where
  "gh_reply r = (case gh_kernel r of
      Value x \<Rightarrow> reply_val (gh_fmt r) (gh_kind r) (gh_text r x) x
    | Decline w \<Rightarrow> decline_reply (gh_kind r) w
    | _ \<Rightarrow> decline_reply (gh_kind r) Imprecise)"

theorem gh_answered_iff:
  "answered (gh_reply r) \<longleftrightarrow> (\<exists>x s. gh_kernel r = Value x \<and> render_x (gh_fmt r) x = Some s)"
  using gh_not_word[of r] by (cases "gh_kernel r")
    (auto simp: gh_reply_def reply_val_def decline_reply_def split: option.splits decl.splits)


theorem gh_vpd_decline:
  "(\<exists>w. gh_kernel (GhVpd (Some t) u leaf lu (Some r) True) = Decline (Imposs w))
   \<longleftrightarrow> r < 0 \<or> 100 < r \<or> tetens_c + g_to_c t u = 0 \<or>
     (\<exists>l. leaf = Some l \<and> tetens_c + g_to_c l lu = 0)"
  by (auto simp: gh_kernel_def pole_ok_def split: option.splits)

theorem gh_photoperiod_decline:
  "(\<exists>w. gh_kernel (GhPpfd d h) = Decline (Imposs w)) \<longleftrightarrow> h \<le> 0"
  by (auto simp: gh_kernel_def)

theorem gh_temperature_order_decline:
  "(\<exists>w. gh_kernel (GhGdd (Some hi) (Some lo) (Some b)) = Decline (Imposs w)) \<longleftrightarrow> hi < lo"
  by (auto simp: gh_kernel_def)

theorem gh_spacing_decline:
  "(\<exists>w. gh_kernel (GhPlants (Some a) au (Some s1) u1 (Some s2) u2) = Decline (Imposs w))
   \<longleftrightarrow> s1 * len_m u1 \<le> 0 \<or> s2 * len_m u2 \<le> 0"
  by (auto simp: gh_kernel_def)

end
