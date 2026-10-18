theory Earth_Seis
  imports Earth_Num
begin

text \<open>
  Oracle7 Seismology & Earthquakes (upstream/root/specialists/seismology/organ_seismology_v1.py):
  energy and amplitude ratios between magnitudes, moment magnitude and seismic moment
  (IASPEI), epicentral distance from the S-P interval with both wave speeds stated, and the
  Gutenberg-Richter count with a and b stated. The ambiguous "how many times stronger" is
  asked back, never picked.
\<close>

datatype seis_req =
    SeEnergy rat rat
  | SeAmp rat rat
  | SeAsk rat rat
  | SeMw rat
  | SeM0 rat
  | SeSP "rat option" "rat option" "rat option"
  | SeGR "rat option" "rat option" "rat option"

definition hi_mag :: "rat \<Rightarrow> rat \<Rightarrow> rat" where "hi_mag a b = max a b"
definition lo_mag :: "rat \<Rightarrow> rat \<Rightarrow> rat" where "lo_mag a b = min a b"
definition dmag :: "rat \<Rightarrow> rat \<Rightarrow> rat" where "dmag a b = hi_mag a b - lo_mag a b"

definition log10_fa :: "floatarith \<Rightarrow> floatarith" where
  "log10_fa a = fdiv (floatarith.Ln a) (floatarith.Ln (I 10))"

lemma interp_log10_fa [simp]: "interpret_floatarith (log10_fa a) xs = log 10 (interpret_floatarith a xs)"
  by (simp add: log10_fa_def log_def)

definition ten_pow :: "rat \<Rightarrow> floatarith" where
  "ten_pow e = floatarith.Powr (I 10) (Q e)"

lemma interp_ten_pow [simp]: "interpret_floatarith (ten_pow e) xs = 10 powr rl e"
  by (simp add: ten_pow_def)

text \<open>Integer powers of ten have exact rational values. The finite exponent
bound limits work in this optional optimization; larger or fractional exponents
retain the existing certified interval algorithm.\<close>
definition ten_rat :: "int \<Rightarrow> rat" where
  "ten_rat n = (if 0 \<le> n then 10 ^ nat n else 1 / 10 ^ nat (-n))"

lemma ten_rat_sound:
  "rl (ten_rat n) = 10 powr (of_int n)"
  by (simp add: ten_rat_def powr_real_of_int of_rat_power of_rat_divide inverse_eq_divide)

definition ten_value :: "rat \<Rightarrow> xexpr" where
  "ten_value e = (let n = \<lfloor>e\<rfloor> in
     if of_int n = e \<and> \<bar>n\<bar> \<le> 256 then XRat (ten_rat n)
     else XFa dprec (ten_pow e))"

lemma ten_value_sound [simp]:
  "xsem (ten_value e) = 10 powr rl e"
proof (cases "of_int \<lfloor>e\<rfloor> = e \<and> \<bar>\<lfloor>e\<rfloor>\<bar> \<le> 256")
  case True
  have er: "rl e = of_int \<lfloor>e\<rfloor>" using True by (metis of_rat_of_int_eq)
  show ?thesis using True er by (simp add: ten_value_def Let_def ten_rat_sound)
next
  case False
  then show ?thesis by (auto simp: ten_value_def Let_def)
qed

theorem ten_value_exact_integer:
  "\<bar>n\<bar> \<le> 256 \<Longrightarrow> ten_value (of_int n) = XRat (ten_rat n)"
  by (simp add: ten_value_def Let_def)

theorem ten_value_fallback:
  "of_int \<lfloor>e\<rfloor> \<noteq> e \<or> 256 < \<bar>\<lfloor>e\<rfloor>\<bar> \<Longrightarrow>
    ten_value e = XFa dprec (ten_pow e)"
  by (auto simp: ten_value_def Let_def)

section \<open>Declines\<close>

definition w_dt :: String.literal where "w_dt = STR ''the S-P arrival-time difference''"
definition w_speeds :: String.literal where
  "w_speeds = STR ''the P- and S-wave speeds (they depend on the crust; I won'' + apos + STR ''t assume a rule of thumb)''"
definition w_ab :: String.literal where "w_ab = STR ''the Gutenberg-Richter a and b values for the region''"
definition w_thr :: String.literal where "w_thr = STR ''the magnitude threshold''"

fun seis_missing :: "seis_req \<Rightarrow> String.literal option" where
  "seis_missing (SeSP dt vp vs) =
     (if dt = None then Some w_dt else if vp = None \<or> vs = None then Some w_speeds else None)"
| "seis_missing (SeGR a b m) =
     (if a = None \<or> b = None then Some w_ab else if m = None then Some w_thr else None)"
| "seis_missing _ = None"

fun seis_impossible :: "seis_req \<Rightarrow> String.literal option" where
  "seis_impossible (SeSP dt (Some p) (Some s)) =
     (if (case dt of Some d \<Rightarrow> d < 0 | None \<Rightarrow> False) then
        Some (STR ''The S-minus-P arrival-time difference cannot be negative in this direct-wave model.'')
      else if p \<le> s \<or> s \<le> 0 then
        Some (STR ''S waves are slower than P waves; an S-wave speed of '' + showx GSeis (XRat s)
              + STR '' km/s at or above a P-wave speed of '' + showx GSeis (XRat p) + STR '' km/s is not physical.'')
      else None)"
| "seis_impossible (SeMw m0) = (if m0 \<le> 0 then Some (STR ''A seismic moment must be positive.'') else None)"
| "seis_impossible _ = None"

section \<open>Values\<close>

definition energy_spec :: "rat \<Rightarrow> real" where "energy_spec d = 10 powr (3 / 2 * rl d)"
definition amp_spec :: "rat \<Rightarrow> real" where "amp_spec d = 10 powr rl d"
definition mw_spec :: "rat \<Rightarrow> real" where "mw_spec m0 = (log 10 (rl m0) - 91 / 10) / (3 / 2)"
definition m0_spec :: "rat \<Rightarrow> real" where "m0_spec mw = 10 powr (3 / 2 * rl mw + 91 / 10)"
definition sp_spec :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> real" where
  "sp_spec dt p s = rl dt / (1 / rl s - 1 / rl p)"
definition gr_spec :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> real" where
  "gr_spec a b m = 10 powr (rl a - rl b * rl m)"

fun seis_xval :: "seis_req \<Rightarrow> xexpr" where
  "seis_xval (SeEnergy a b) = ten_value (3 / 2 * dmag a b)"
| "seis_xval (SeAmp a b) = ten_value (dmag a b)"
| "seis_xval (SeAsk a b) = XRat 0"
| "seis_xval (SeMw m0) = XFa 100 (fdiv (fsub (log10_fa (Q m0)) (Q (91 / 10))) (Q (3 / 2)))"
| "seis_xval (SeM0 mw) = ten_value (3 / 2 * mw + 91 / 10)"
| "seis_xval (SeSP (Some dt) (Some p) (Some s)) = XRat (dt / (1 / s - 1 / p))"
| "seis_xval (SeSP _ _ _) = XRat 0"
| "seis_xval (SeGR (Some a) (Some b) (Some m)) = ten_value (a - b * m)"
| "seis_xval (SeGR _ _ _) = XRat 0"

fun seis_phys :: "seis_req \<Rightarrow> real" where
  "seis_phys (SeEnergy a b) = energy_spec (dmag a b)"
| "seis_phys (SeAmp a b) = amp_spec (dmag a b)"
| "seis_phys (SeAsk a b) = 0"
| "seis_phys (SeMw m0) = mw_spec m0"
| "seis_phys (SeM0 mw) = m0_spec mw"
| "seis_phys (SeSP (Some dt) (Some p) (Some s)) = sp_spec dt p s"
| "seis_phys (SeSP _ _ _) = 0"
| "seis_phys (SeGR (Some a) (Some b) (Some m)) = gr_spec a b m"
| "seis_phys (SeGR _ _ _) = 0"

definition ask_text :: "rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "ask_text a b =
     (let d = dmag a b in
      STR ''Do you mean the energy released or the shaking amplitude? They differ: energy grows 10^(1.5 x ''
      + showx GSeis (XRat d) + STR '') = '' + showx GSeis (ten_value (3 / 2 * d))
      + STR '' times, amplitude 10^'' + showx GSeis (XRat d) + STR '' = '' + showx GSeis (ten_value d)
      + STR '' times, for M'' + showx GSeis (XRat (hi_mag a b)) + STR '' vs M'' + showx GSeis (XRat (lo_mag a b)) + STR ''.'')"

definition seis_kernel :: "seis_req \<Rightarrow> outcome" where
  "seis_kernel r = (case seis_missing r of Some w \<Rightarrow> Decline (Under w)
     | None \<Rightarrow> (case seis_impossible r of Some w \<Rightarrow> Decline (Imposs w)
        | None \<Rightarrow> (case r of SeAsk a b \<Rightarrow> Decline (Ask (ask_text a b)) | _ \<Rightarrow> Value (seis_xval r))))"

theorem seis_underspecified: "seis_kernel r = Decline (Under w) \<longleftrightarrow> seis_missing r = Some w"
  by (cases r) (auto simp: seis_kernel_def split: option.splits)

theorem seis_impossible_iff:
  "seis_kernel r = Decline (Imposs w) \<longleftrightarrow> seis_missing r = None \<and> seis_impossible r = Some w"
  by (cases r) (auto simp: seis_kernel_def split: option.splits)

theorem seis_asks_back:
  "seis_kernel (SeAsk a b) = Decline (Ask (ask_text a b))"
  by (simp add: seis_kernel_def)

lemma seis_value_cases:
  "seis_kernel r = Value x \<Longrightarrow> seis_missing r = None \<and> seis_impossible r = None \<and> x = seis_xval r \<and>
     (\<forall>a b. r \<noteq> SeAsk a b)"
  by (cases r) (auto simp: seis_kernel_def split: option.splits if_splits)

lemma seis_not_word: "seis_kernel r \<noteq> Word t" "seis_kernel r \<noteq> Note"
  by (cases r; auto simp: seis_kernel_def split: option.splits if_splits seis_req.splits)+

theorem seis_value_sound:
  assumes "seis_kernel r = Value x"
  shows "seis_missing r = None \<and> seis_impossible r = None \<and> xsem x = seis_phys r"
proof -
  have c: "seis_missing r = None" "seis_impossible r = None" "x = seis_xval r" "\<forall>a b. r \<noteq> SeAsk a b"
    using seis_value_cases[OF assms] by auto
  have "xsem (seis_xval r) = seis_phys r"
  proof (cases r)
    case (SeSP dt p s)
    then show ?thesis
      by (cases dt; cases p; cases s)
         (simp_all add: sp_spec_def of_rat_divide of_rat_diff)
  next
    case (SeGR a b m)
    then show ?thesis
      by (cases a; cases b; cases m) (simp_all add: gr_spec_def of_rat_diff of_rat_mult)
  qed (simp_all add: energy_spec_def amp_spec_def mw_spec_def m0_spec_def of_rat_divide of_rat_diff
       of_rat_mult of_rat_add)
  then show ?thesis using c by simp
qed

text \<open>Magnitude differences, including negative magnitudes, are invariant
under a shared change of origin. These identities bind the actual ratio outputs.\<close>
lemma dmag_translate:
  "dmag (a+c) (b+c) = dmag a b"
  by (simp add: dmag_def hi_mag_def lo_mag_def max_def min_def)

theorem energy_kernel_translate:
  "seis_kernel (SeEnergy (a+c) (b+c)) = seis_kernel (SeEnergy a b)"
  by (simp add: seis_kernel_def dmag_translate)

theorem amplitude_kernel_translate:
  "seis_kernel (SeAmp (a+c) (b+c)) = seis_kernel (SeAmp a b)"
  by (simp add: seis_kernel_def dmag_translate)

theorem moment_success_positive:
  "(\<exists>x. seis_kernel (SeMw m) = Value x) \<longleftrightarrow> 0 < m"
  by (auto simp: seis_kernel_def split: if_splits)

section \<open>What each kind means\<close>

text \<open>The amplitude ratio grows by a factor of ten per magnitude unit, and the energy ratio
is its three-halves power: about 31.6 times per unit.\<close>
theorem energy_is_amplitude_power: "energy_spec d = (amp_spec d) powr (3 / 2)"
  unfolding energy_spec_def amp_spec_def by (simp add: powr_powr mult.commute)

theorem amp_ratio_adds: "amp_spec (d1 + d2) = amp_spec d1 * amp_spec d2"
  by (simp add: amp_spec_def powr_add of_rat_add)

theorem energy_ratio_adds: "energy_spec (d1 + d2) = energy_spec d1 * energy_spec d2"
  by (simp add: energy_spec_def powr_add of_rat_add distrib_left)

theorem amp_ratio_two_units: "amp_spec 2 = 100"
  by (simp add: amp_spec_def powr_numeral)

theorem energy_ratio_two_units: "energy_spec 2 = 1000"
proof -
  have e: "energy_spec 2 = 10 powr (3::real)" by (simp add: energy_spec_def)
  show ?thesis using e by (simp add: powr_numeral)
qed

lemma log10_ten_powr: "log 10 (10 powr z) = z"
proof -
  have p: "0 < ln (10::real)" by (rule ln_gt_zero) simp
  show ?thesis using p by (simp add: log_def powr_def)
qed

text \<open>The moment magnitude and the seismic moment are inverse to each other.\<close>
definition mw_of :: "real \<Rightarrow> real" where "mw_of m0 = (log 10 m0 - 91 / 10) / (3 / 2)"
definition m0_of :: "real \<Rightarrow> real" where "m0_of mw = 10 powr (3 / 2 * mw + 91 / 10)"

theorem mw_spec_is_mw_of: "mw_spec m0 = mw_of (rl m0)"
  by (simp add: mw_spec_def mw_of_def)

theorem m0_spec_is_m0_of: "m0_spec mw = m0_of (rl mw)"
  by (simp add: m0_spec_def m0_of_def)

theorem mw_of_m0_of: "mw_of (m0_of w) = w"
  by (simp add: mw_of_def m0_of_def log10_ten_powr)

theorem m0_of_mw_of:
  assumes "0 < m0"
  shows "m0_of (mw_of m0) = m0"
proof -
  have "3 / 2 * mw_of m0 + 91 / 10 = log 10 m0" by (simp add: mw_of_def field_simps)
  then show ?thesis using assms by (simp add: m0_of_def powr_log_cancel)
qed

theorem sp_travel_times:
  assumes "0 < s" "s < p"
  shows "sp_spec dt p s / rl s - sp_spec dt p s / rl p = rl dt"
proof -
  have s: "0 < rl s" using assms(1) by (simp add: zero_less_of_rat_iff)
  have sp: "rl s < rl p" using assms(2) by (simp add: of_rat_less)
  have p0: "0 < rl p" using s sp by linarith
  have "inverse (rl p) < inverse (rl s)" using inverse_less_iff_less[OF p0 s] sp by simp
  then have "1 / rl p < 1 / rl s" by (simp add: inverse_eq_divide)
  then have ne: "1 / rl s - 1 / rl p \<noteq> 0" by linarith
  have "sp_spec dt p s / rl s - sp_spec dt p s / rl p = sp_spec dt p s * (1 / rl s - 1 / rl p)"
    by (simp add: algebra_simps divide_inverse)
  also have "\<dots> = rl dt" using ne by (simp add: sp_spec_def field_simps)
  finally show ?thesis .
qed

theorem gr_log_count:
  "log 10 (gr_spec a b m) = rl a - rl b * rl m"
  by (simp add: gr_spec_def log10_ten_powr)

theorem gr_decreases_with_magnitude:
  assumes "0 < b" "m1 \<le> m2"
  shows "gr_spec a b m2 \<le> gr_spec a b m1"
proof -
  have b: "0 \<le> rl b" using assms(1) by (simp add: zero_le_of_rat_iff)
  have m: "rl m1 \<le> rl m2" using assms(2) by (simp add: of_rat_less_eq)
  have "rl b * rl m1 \<le> rl b * rl m2" using m b by (rule mult_left_mono)
  then have h: "rl a - rl b * rl m2 \<le> rl a - rl b * rl m1" by linarith
  show ?thesis unfolding gr_spec_def by (rule powr_mono[OF h]) simp
qed

section \<open>Text\<close>

fun seis_kind :: "seis_req \<Rightarrow> String.literal" where
  "seis_kind (SeEnergy _ _) = STR ''energy_ratio''"
| "seis_kind (SeAmp _ _) = STR ''amplitude_ratio''"
| "seis_kind (SeAsk _ _) = STR ''underspecified''"
| "seis_kind (SeMw _) = STR ''mw''"
| "seis_kind (SeM0 _) = STR ''m0''"
| "seis_kind (SeSP _ _ _) = STR ''sp_distance''"
| "seis_kind (SeGR _ _ _) = STR ''gr_count''"

definition s1 :: "rat \<Rightarrow> String.literal" where "s1 q = showx GSeis (XRat q)"
definition sinp :: "rat option \<Rightarrow> String.literal" where
  "sinp q = (case q of Some v \<Rightarrow> show_input v | None \<Rightarrow> STR ''?'')"

fun seis_text :: "seis_req \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "seis_text (SeEnergy a b) V = STR ''The energy ratio is '' + V + STR '' times (10^(1.5 x '' + s1 (dmag a b)
     + STR '') for M'' + s1 (hi_mag a b) + STR '' vs M'' + s1 (lo_mag a b) + STR '').''"
| "seis_text (SeAmp a b) V = STR ''The amplitude ratio is '' + V + STR '' times (10^'' + s1 (dmag a b)
     + STR '' for M'' + s1 (hi_mag a b) + STR '' vs M'' + s1 (lo_mag a b) + STR ''; ground motion on a seismogram).''"
| "seis_text (SeMw m0) V = STR ''The moment magnitude is '' + V + STR '' (Mw = (log10 M0 - 9.1) / 1.5, M0 = ''
     + s1 m0 + STR '' N m; IASPEI).''"
| "seis_text (SeM0 mw) V = STR ''The seismic moment is '' + V + STR '' N m (M0 = 10^(1.5 Mw + 9.1), Mw ''
     + s1 mw + STR ''; IASPEI).''"
| "seis_text (SeSP dt p s) V = STR ''The distance is '' + V + STR '' km (dt / (1/vs - 1/vp) = '' + sinp dt
     + STR '' s / (1/'' + sinp s + STR '' - 1/'' + sinp p + STR '')).''"
| "seis_text (SeGR a b m) V = STR ''The expected number is '' + V + STR '' per year with magnitude >= '' + sinp m
     + STR '' (log10 N = a - bM = '' + sinp a + STR '' - '' + sinp b + STR '' x '' + sinp m + STR '').''"
| "seis_text r V = V"

definition seis_reply :: "seis_req \<Rightarrow> reply" where
  "seis_reply r = (case seis_kernel r of
      Value x \<Rightarrow> reply_val GSeis (seis_kind r) (seis_text r) x
    | Decline w \<Rightarrow> decline_reply (seis_kind r) w
    | _ \<Rightarrow> decline_reply (seis_kind r) Imprecise)"

theorem seis_answered_iff:
  "answered (seis_reply r) \<longleftrightarrow> (\<exists>x s. seis_kernel r = Value x \<and> render_x GSeis x = Some s)"
  using seis_not_word[of r] by (cases "seis_kernel r")
    (auto simp: seis_reply_def reply_val_def decline_reply_def split: option.splits decl.splits)


theorem seis_travel_decline:
  "(\<exists>w. seis_kernel (SeSP (Some dt) (Some p) (Some s)) = Decline (Imposs w))
   \<longleftrightarrow> dt < 0 \<or> p \<le> s \<or> s \<le> 0"
  by (auto simp: seis_kernel_def)

theorem seis_moment_decline:
  "(\<exists>w. seis_kernel (SeMw m) = Decline (Imposs w)) \<longleftrightarrow> m \<le> 0"
  by (auto simp: seis_kernel_def)


text \<open>A successful direct-wave distance has ordered positive speeds and a
nonnegative S-minus-P delay. The inferred distance reproduces both travel times.\<close>
theorem sp_success_physical:
  assumes k: "seis_kernel (SeSP (Some dt) (Some p) (Some s)) = Value x"
  shows "0 \<le> dt \<and> 0 < s \<and> s < p \<and> 0 \<le> xsem x \<and>
    xsem x / rl s - xsem x / rl p = rl dt"
proof -
  have guards: "0 \<le> dt" "0 < s" "s < p"
    using seis_value_cases[OF k] by (auto split: if_splits)
  have sem: "xsem x = sp_spec dt p s" using seis_value_sound[OF k] by simp
  have s0: "0 < rl s" using guards(2) by (simp add: zero_less_of_rat_iff)
  have sp: "rl s < rl p" using guards(3) by (simp add: of_rat_less)
  have p0: "0 < rl p" using s0 sp by linarith
  have denom: "0 < 1 / rl s - 1 / rl p"
    using inverse_less_iff_less[OF p0 s0] sp by (simp add: inverse_eq_divide)
  have dt0: "0 \<le> rl dt" using guards(1) by (simp add: zero_le_of_rat_iff)
  have nonnegative: "0 \<le> sp_spec dt p s"
    unfolding sp_spec_def by (rule divide_nonneg_pos[OF dt0 denom])
  show ?thesis using guards sem nonnegative sp_travel_times[OF guards(2,3), of dt] by simp
qed

theorem sp_success_zero_iff:
  assumes k: "seis_kernel (SeSP (Some dt) (Some p) (Some s)) = Value x"
  shows "xsem x = 0 \<longleftrightarrow> dt = 0"
proof
  assume "xsem x = 0"
  then have "rl dt = 0" using sp_success_physical[OF k] by simp
  then show "dt = 0" by simp
next
  assume "dt = 0"
  then show "xsem x = 0" using seis_value_sound[OF k] by (simp add: sp_spec_def)
qed

theorem gr_success_log_model:
  assumes k: "seis_kernel (SeGR (Some a) (Some b) (Some m)) = Value x"
  shows "0 < xsem x \<and> log 10 (xsem x) = rl a - rl b * rl m"
  using seis_value_sound[OF k] gr_log_count[of a b m]
  by (simp add: gr_spec_def)

theorem gr_success_threshold_monotone:
  assumes k1: "seis_kernel (SeGR (Some a) (Some b) (Some m1)) = Value x1"
    and k2: "seis_kernel (SeGR (Some a) (Some b) (Some m2)) = Value x2"
    and b: "0 < b" and m: "m1 \<le> m2"
  shows "xsem x2 \<le> xsem x1"
  using seis_value_sound[OF k1] seis_value_sound[OF k2]
    gr_decreases_with_magnitude[OF b m, of a] by simp

end
