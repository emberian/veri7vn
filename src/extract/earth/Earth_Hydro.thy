theory Earth_Hydro
  imports Earth_Num
begin

text \<open>
  Oracle7 Hydrology & Rivers (upstream/root/specialists/hydrology/organ_hydrology_v1.py):
  the rational method, rainwater harvest, Manning's equation (SI), fill/drain time and
  continuity Q = vA. Runoff coefficients, roughness and collection efficiency are never
  assumed.
\<close>

datatype cunit = CFraction | CPercent
fun runoff_coefficient :: "cunit \<Rightarrow> rat \<Rightarrow> rat" where
  "runoff_coefficient CFraction c = c"
| "runoff_coefficient CPercent c = c / 100"

datatype iunit = IIn | IMm
datatype aunit = AAcre | AHa | AKm2
datatype hsys = HUS | HSI | HMix
datatype vunit = VGal | VL | VM3
datatype tunit = TMin | THour | TSec

datatype hyd_req =
    HyRational "rat option" "rat option" "rat option" iunit aunit
  | HyHarvest "rat option" "rat option" "rat option" hsys
  | HyManning "rat option" "rat option" "rat option" "rat option" bool
  | HyFill "rat option" vunit "rat option" vunit tunit
  | HyCont "rat option" "rat option" bool

fun vol_litres :: "vunit \<Rightarrow> rat" where
  "vol_litres VGal = 3785411784 / 1000000000"
| "vol_litres VL = 1"
| "vol_litres VM3 = 1000"

fun time_secs :: "tunit \<Rightarrow> rat" where
  "time_secs TMin = 60" | "time_secs THour = 3600" | "time_secs TSec = 1"

fun ha_of :: "aunit \<Rightarrow> rat \<Rightarrow> rat" where
  "ha_of AAcre a = a * (40468564224 / 100000000000)"
| "ha_of AHa a = a"
| "ha_of AKm2 a = a * 100"

definition gal_per_inch_sqft :: rat where "gal_per_inch_sqft = 623 / 1000"

section \<open>Declines\<close>

definition w_rational :: String.literal where
  "w_rational = STR ''the runoff coefficient, the rainfall intensity and the drainage area''"
definition w_rational_sys :: String.literal where
  "w_rational_sys = STR ''rainfall and area in matching systems (in/hr with acres, or mm/h with hectares)''"
definition w_harvest :: String.literal where
  "w_harvest = STR ''the rainfall depth and the catchment (roof) area''"
definition w_harvest_sys :: String.literal where
  "w_harvest_sys = STR ''rainfall and roof area in matching systems (inches with square feet, or mm with square metres)''"
definition w_manning :: String.literal where
  "w_manning = STR ''Manning'' + apos + STR ''s n, the flow area, the wetted perimeter and the slope''"
definition w_fill :: String.literal where "w_fill = STR ''the volume and the flow rate''"
definition w_cont :: String.literal where "w_cont = STR ''the velocity and the cross-sectional area''"

fun hy_missing :: "hyd_req \<Rightarrow> String.literal option" where
  "hy_missing (HyRational c i a iu au) =
     (if c = None \<or> i = None \<or> a = None then Some w_rational
      else if iu = IIn \<and> au \<noteq> AAcre then Some w_rational_sys else None)"
| "hy_missing (HyHarvest d a e s) =
     (if d = None \<or> a = None then Some w_harvest else if s = HMix then Some w_harvest_sys else None)"
| "hy_missing (HyManning n a p s q) =
     (if n = None \<or> a = None \<or> p = None \<or> s = None then Some w_manning else None)"
| "hy_missing (HyFill v vu r ru tu) = (if v = None \<or> r = None then Some w_fill else None)"
| "hy_missing (HyCont v a u) = (if v = None \<or> a = None then Some w_cont else None)"

fun hy_impossible :: "hyd_req \<Rightarrow> String.literal option" where
  "hy_impossible (HyManning (Some n) (Some a) (Some p) (Some s) q) =
     (if n \<le> 0 \<or> p \<le> 0 \<or> a < 0 \<or> s < 0 then Some (STR ''Manning'' + apos + STR ''s n and the wetted perimeter must be positive; area and slope cannot be negative.'') else None)"
| "hy_impossible (HyFill (Some v) vu (Some r) ru tu) =
     (if r * vol_litres ru \<le> 0 then Some (STR ''A flow rate must be positive.'') else None)"
| "hy_impossible (HyRational (Some c) (Some i) (Some a) iu au) =
     (if c < 0 \<or> 1 < c \<or> i < 0 \<or> a < 0 then
       Some (STR ''In the simple runoff-fraction model, the coefficient must be from 0 to 1; rainfall intensity and drainage area cannot be negative.'')
      else None)"
| "hy_impossible _ = None"

section \<open>Values\<close>

definition opt :: "rat option \<Rightarrow> rat" where "opt x = (case x of Some v \<Rightarrow> v | None \<Rightarrow> 0)"

definition harv_eff :: "rat option \<Rightarrow> rat" where
  "harv_eff e = (case e of Some p \<Rightarrow> p / 100 | None \<Rightarrow> 1)"

definition manning_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "manning_fa n r s =
     floatarith.Mult (Q (1 / n)) (floatarith.Mult (floatarith.Powr (Q r) (Q (2 / 3))) (floatarith.Sqrt (Q s)))"

definition manning_x :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "manning_x n r s = (if r = 0 \<or> s = 0 then XRat 0 else XFa dprec (manning_fa n r s))"

definition manning_spec :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> real" where
  "manning_spec n r s = (1 / rl n) * (rl r powr (2 / 3)) * sqrt (rl s)"

fun hy_xval :: "hyd_req \<Rightarrow> xexpr" where
  "hy_xval (HyRational (Some c) (Some i) (Some a) iu au) =
     (if iu = IIn then XRat (c * i * a) else XRat (c * i * ha_of au a / 360))"
| "hy_xval (HyHarvest (Some d) (Some a) e s) =
     (if s = HUS then XRat (d * a * gal_per_inch_sqft * harv_eff e) else XRat (d * a * harv_eff e))"
| "hy_xval (HyManning (Some n) (Some a) (Some p) (Some s) q) =
     (if p = 0 then XRat 0
      else if q then scale_x a (manning_x n (a / p) s) else manning_x n (a / p) s)"
| "hy_xval (HyFill (Some v) vu (Some r) ru tu) =
     XRat (v * vol_litres vu / (r * vol_litres ru / time_secs tu) / 60)"
| "hy_xval (HyCont (Some v) (Some a) u) = XRat (v * a)"
| "hy_xval _ = XRat 0"

fun hy_phys :: "hyd_req \<Rightarrow> real" where
  "hy_phys (HyRational (Some c) (Some i) (Some a) iu au) =
     (if iu = IIn then rl c * rl i * rl a else rl c * rl i * rl (ha_of au a) / 360)"
| "hy_phys (HyHarvest (Some d) (Some a) e s) =
     (if s = HUS then rl d * rl a * rl gal_per_inch_sqft * rl (harv_eff e) else rl d * rl a * rl (harv_eff e))"
| "hy_phys (HyManning (Some n) (Some a) (Some p) (Some s) q) =
     (if p = 0 then 0
      else if q then rl a * manning_spec n (a / p) s else manning_spec n (a / p) s)"
| "hy_phys (HyFill (Some v) vu (Some r) ru tu) =
     rl v * rl (vol_litres vu) / (rl r * rl (vol_litres ru) / rl (time_secs tu)) / 60"
| "hy_phys (HyCont (Some v) (Some a) u) = rl v * rl a"
| "hy_phys _ = 0"

definition hy_kernel :: "hyd_req \<Rightarrow> outcome" where
  "hy_kernel r = (case hy_missing r of Some w \<Rightarrow> Decline (Under w)
     | None \<Rightarrow> (case hy_impossible r of Some w \<Rightarrow> Decline (Imposs w) | None \<Rightarrow> Value (hy_xval r)))"

theorem hy_underspecified: "hy_kernel r = Decline (Under w) \<longleftrightarrow> hy_missing r = Some w"
  by (auto simp: hy_kernel_def split: option.splits)

theorem hy_impossible_iff:
  "hy_kernel r = Decline (Imposs w) \<longleftrightarrow> hy_missing r = None \<and> hy_impossible r = Some w"
  by (auto simp: hy_kernel_def split: option.splits)

lemma hy_value_cases:
  "hy_kernel r = Value x \<Longrightarrow> hy_missing r = None \<and> hy_impossible r = None \<and> x = hy_xval r"
  by (auto simp: hy_kernel_def split: option.splits)

lemma hy_not_word: "hy_kernel r \<noteq> Word t" "hy_kernel r \<noteq> Note"
  by (auto simp: hy_kernel_def split: option.splits)

lemma manning_x_sem: "xsem (manning_x n r s) = manning_spec n r s"
proof (cases "r = 0 \<or> s = 0")
  case True
  then show ?thesis by (auto simp: manning_x_def manning_spec_def powr_def)
next
  case False
  then show ?thesis by (simp add: manning_x_def manning_fa_def manning_spec_def of_rat_divide mult.assoc)
qed

theorem hy_value_sound:
  assumes "hy_kernel r = Value x"
  shows "hy_missing r = None \<and> hy_impossible r = None \<and> xsem x = hy_phys r"
proof -
  have cc: "hy_missing r = None" "hy_impossible r = None" "x = hy_xval r"
    using hy_value_cases[OF assms] by auto
  have "xsem (hy_xval r) = hy_phys r"
  proof (cases r)
    case (HyRational c i a iu au)
    then show ?thesis using cc
      by (cases c; cases i; cases a)
         (simp_all add: of_rat_mult of_rat_divide split: if_splits)
  next
    case (HyHarvest d a e s)
    then show ?thesis using cc
      by (cases d; cases a) (simp_all add: of_rat_mult split: if_splits)
  next
    case (HyManning n a p s q)
    then show ?thesis using cc
      by (cases n; cases a; cases p; cases s)
         (simp_all add: manning_x_sem of_rat_divide split: if_splits)
  next
    case (HyFill v vu rt ru tu)
    then show ?thesis using cc
      by (cases v; cases rt) (simp_all add: of_rat_mult of_rat_divide)
  next
    case (HyCont v a u)
    then show ?thesis using cc by (cases v; cases a) (simp_all add: of_rat_mult)
  qed
  then show ?thesis using cc by simp
qed

section \<open>What each kind means\<close>

text \<open>The manning velocity times the roughness is the hydraulic radius to the two-thirds
times the square root of the slope.\<close>
theorem manning_velocity:
  assumes "0 < n"
  shows "manning_spec n r s * rl n = (rl r) powr (2 / 3) * sqrt (rl s)"
proof -
  have "rl n \<noteq> 0" using assms by (simp add: zero_less_of_rat_iff)
  then show ?thesis by (simp add: manning_spec_def)
qed

theorem manning_cubed:
  assumes "0 < r"
  shows "((rl r) powr (2 / 3)) ^ 3 = (rl r) ^ 2"
proof -
  have r: "0 < rl r" using assms by (simp add: zero_less_of_rat_iff)
  have p0: "0 \<le> rl r powr (2 / 3)" by simp
  have "((rl r) powr (2 / 3)) ^ 3 = ((rl r) powr (2 / 3)) powr (3::real)"
    using p0 by (simp add: powr_numeral)
  also have "\<dots> = (rl r) powr ((2 / 3) * 3)" by (simp add: powr_powr)
  also have "(rl r) powr ((2 / 3) * (3::real)) = (rl r) powr (2::real)" by simp
  also have "\<dots> = (rl r) ^ 2" using r by (simp add: powr_numeral)
  finally show ?thesis .
qed

theorem fill_time_times_flow:
  assumes "0 < r * vol_litres ru"
  shows "hy_phys (HyFill (Some v) vu (Some r) ru tu) * 60 * (rl r * rl (vol_litres ru) / rl (time_secs tu))
         = rl v * rl (vol_litres vu)"
proof -
  have a: "(0::real) < rl (r * vol_litres ru)" using assms by (simp add: zero_less_of_rat_iff)
  have a': "(0::real) < rl r * rl (vol_litres ru)" using a by (simp add: of_rat_mult)
  have n1: "rl r * rl (vol_litres ru) \<noteq> 0" by (rule less_imp_neq[THEN not_sym, OF a'])
  have t: "0 < rl (time_secs tu)" by (cases tu) simp_all
  have n2: "rl (time_secs tu) \<noteq> 0" using t by simp
  have rne: "r \<noteq> 0" and vne: "vol_litres ru \<noteq> 0" using n1 by auto
  have tne: "time_secs tu \<noteq> 0" by (cases tu) simp_all
  show ?thesis by (simp add: field_simps n1 n2 rne vne tne)
qed

theorem rational_method_si:
  "hy_phys (HyRational (Some c) (Some i) (Some a) IMm au) * 360 = rl c * rl i * rl (ha_of au a)"
  by (simp add: field_simps)

text \<open>The simple runoff coefficient partitions the model's zero-loss
peak flow. The US CiA approximation and SI conversion remain explicitly distinct.\<close>
definition runoff_capacity :: "iunit \<Rightarrow> aunit \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "runoff_capacity iu au i a = (if iu = IIn then i * a else i * ha_of au a / 360)"

lemma runoff_capacity_nonnegative:
  "0 \<le> i \<Longrightarrow> 0 \<le> a \<Longrightarrow> 0 \<le> runoff_capacity iu au i a"
  by (cases iu; cases au) (auto simp: runoff_capacity_def)

theorem runoff_success_physical:
  assumes "hy_kernel (HyRational (Some c) (Some i) (Some a) iu au) = Value x"
  shows "0 \<le> c \<and> c \<le> 1 \<and> 0 \<le> i \<and> 0 \<le> a \<and> (iu = IIn \<longrightarrow> au = AAcre)"
  using hy_value_cases[OF assms] by (auto split: if_splits)

theorem runoff_success_conservation:
  assumes k: "hy_kernel (HyRational (Some c) (Some i) (Some a) iu au) = Value x"
  shows "0 \<le> xsem x \<and> xsem x \<le> rl (runoff_capacity iu au i a)"
proof -
  have p: "0 \<le> c" "c \<le> 1" "0 \<le> i" "0 \<le> a"
    using runoff_success_physical[OF k] by auto
  have cap: "0 \<le> runoff_capacity iu au i a"
    by (rule runoff_capacity_nonnegative[OF p(3) p(4)])
  have lo: "0 \<le> c * runoff_capacity iu au i a" by (rule mult_nonneg_nonneg[OF p(1) cap])
  have hi: "c * runoff_capacity iu au i a \<le> runoff_capacity iu au i a"
    using mult_right_mono[OF p(2) cap] by simp
  have eq: "xsem x = rl (c * runoff_capacity iu au i a)"
    using hy_value_cases[OF k] by (cases iu) (simp_all add: runoff_capacity_def algebra_simps)
  show ?thesis using lo hi eq by (simp add: of_rat_less_eq)
qed

theorem runoff_percent_equivalent:
  "hy_kernel (HyRational (Some (runoff_coefficient CPercent (100*c))) i a iu au) =
   hy_kernel (HyRational (Some c) i a iu au)"
  by simp

theorem runoff_area_unit_equivalent:
  "hy_kernel (HyRational c i (Some a) IMm AKm2) =
   hy_kernel (HyRational c i (Some (100*a)) IMm AHa)"
  by (cases c; cases i) (auto simp: hy_kernel_def mult_less_0_iff algebra_simps split: if_splits)

theorem harvest_without_efficiency_is_before_losses:
  "harv_eff None = 1"
  by (simp add: harv_eff_def)

section \<open>Text\<close>

fun hy_kind :: "hyd_req \<Rightarrow> String.literal" where
  "hy_kind (HyRational _ _ _ _ _) = STR ''rational''"
| "hy_kind (HyHarvest _ _ _ s) = (if s = HUS then STR ''harvest'' else STR ''harvest_si'')"
| "hy_kind (HyManning _ _ _ _ q) = (if q then STR ''manning_q'' else STR ''manning_v'')"
| "hy_kind (HyFill _ _ _ _ _) = STR ''fill_time''"
| "hy_kind (HyCont _ _ _) = STR ''continuity''"

definition h1 :: "rat option \<Rightarrow> String.literal" where
  "h1 q = showx GHydro (XRat (opt q))"

definition harv_note :: "rat option \<Rightarrow> String.literal" where
  "harv_note e = (case e of Some p \<Rightarrow> STR ''at '' + showx GHydro (XRat p) + STR ''% collection efficiency''
     | None \<Rightarrow> STR ''before losses'')"

fun hy_text :: "hyd_req \<Rightarrow> xexpr \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "hy_text (HyRational c i a iu au) x V =
     (if iu = IIn then STR ''The peak runoff is '' + V + STR '' cfs (Q = CiA = '' + h1 c + STR '' x '' + h1 i
        + STR '' in/hr x '' + h1 a + STR '' acres; rational method).''
      else STR ''The peak runoff is '' + V + STR '' m3/s (Q = C i A / 360 = '' + h1 c + STR '' x '' + h1 i
        + STR '' mm/h x '' + showx GHydro (XRat (ha_of au (opt a))) + STR '' ha / 360; rational method, SI).'')"
| "hy_text (HyHarvest d a e s) x V =
     (if s = HUS then STR ''That is about '' + V + STR '' US gallons ('' + h1 d + STR '' in x '' + h1 a
        + STR '' sq ft x 0.623 gal, '' + harv_note e + STR '').''
      else STR ''That is about '' + V + STR '' litres ('' + h1 d + STR '' mm x '' + h1 a
        + STR '' m2, 1 mm on 1 m2 = 1 L, '' + harv_note e + STR '').'')"
| "hy_text (HyManning n a p s q) x V =
     (if q then STR ''The discharge is '' + V + STR '' m3/s (Q = VA; V = (1/n) R^(2/3) S^(1/2) = ''
        + showx GHydro (manning_x (opt n) (opt a / opt p) (opt s)) + STR '' m/s with R = ''
        + showx GHydro (XRat (opt a / opt p)) + STR '' m; Manning, SI).''
      else STR ''The velocity is '' + V + STR '' m/s (V = (1/n) R^(2/3) S^(1/2), n = '' + h1 n + STR '', R = A/P = ''
        + showx GHydro (XRat (opt a / opt p)) + STR '' m, S = '' + h1 s + STR ''; Manning, SI).'')"
| "hy_text (HyFill v vu r ru tu) x V =
     STR ''It takes '' + V + STR '' minutes ('' + showx GHydro (scale_x (1 / 60) x) + STR '' hours): volume / flow.''"
| "hy_text (HyCont v a u) x V =
     STR ''The flow rate is '' + V + (if u then STR '' m3/s'' else STR '' cfs'') + STR '' (Q = vA = '' + h1 v + STR '' x '' + h1 a + STR '').''"

definition hy_reply :: "hyd_req \<Rightarrow> reply" where
  "hy_reply r = (case hy_kernel r of
      Value x \<Rightarrow> reply_val GHydro (hy_kind r) (hy_text r x) x
    | Decline w \<Rightarrow> decline_reply (hy_kind r) w
    | _ \<Rightarrow> decline_reply (hy_kind r) Imprecise)"

theorem hy_answered_iff:
  "answered (hy_reply r) \<longleftrightarrow> (\<exists>x s. hy_kernel r = Value x \<and> render_x GHydro x = Some s)"
  using hy_not_word[of r] by (cases "hy_kernel r")
    (auto simp: hy_reply_def reply_val_def decline_reply_def split: option.splits decl.splits)


text \<open>The Manning model requires positive roughness and perimeter, and
nonnegative area and slope.\<close>
theorem hy_manning_decline:
  "(\<exists>w. hy_kernel (HyManning (Some n) (Some a) (Some p) (Some s) q) = Decline (Imposs w))
   \<longleftrightarrow> n \<le> 0 \<or> p \<le> 0 \<or> a < 0 \<or> s < 0"
  by (auto simp: hy_kernel_def)

theorem hy_fill_decline:
  "(\<exists>w. hy_kernel (HyFill (Some v) vu (Some r) ru tu) = Decline (Imposs w))
   \<longleftrightarrow> r * vol_litres ru \<le> 0"
  by (auto simp: hy_kernel_def)

end
