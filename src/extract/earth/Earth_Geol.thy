theory Earth_Geol
  imports Earth_Num
begin

text \<open>
  Oracle7 Earth Science & Geology (upstream/root/specialists/geology/organ_geology_v1.py):
  radioactive decay (fraction remaining, age from a remaining fraction or from a
  daughter/parent ratio), plate motion, and temperature at depth. Ideal decay with no
  initial daughter. The half-lives of the four named isotopes are HOL constants checked
  against the organ by tables_check.py.
\<close>

datatype iso = C14 | K40 | U238 | U235

fun iso_half :: "iso \<Rightarrow> rat" where
  "iso_half C14 = 5730"
| "iso_half K40 = 1248000000"
| "iso_half U238 = 4468000000"
| "iso_half U235 = 704000000"

fun iso_label :: "iso \<Rightarrow> String.literal" where
  "iso_label C14 = STR ''carbon-14, 5,730 years''"
| "iso_label K40 = STR ''potassium-40, 1.248 billion years''"
| "iso_label U238 = STR ''uranium-238, 4.468 billion years''"
| "iso_label U235 = STR ''uranium-235, 704 million years''"

text \<open>The half-life behind a question: stated (in years), an isotope's, or none.\<close>
datatype hl = HlNone | HlGiven rat | HlIso iso

datatype meas = MRatio rat | MFrac rat

datatype geol_req =
    GlPlateDist rat rat
  | GlPlateRate rat rat
  | GlDepthTemp rat rat rat
  | GlAge hl meas
  | GlLeft hl rat

fun gl_half :: "hl \<Rightarrow> rat option" where
  "gl_half HlNone = None"
| "gl_half (HlGiven y) = Some y"
| "gl_half (HlIso i) = Some (iso_half i)"

definition hv :: "hl \<Rightarrow> rat" where
  "hv h = (case gl_half h of Some y \<Rightarrow> y | None \<Rightarrow> 1)"

section \<open>Declines\<close>

fun gl_missing :: "geol_req \<Rightarrow> String.literal option" where
  "gl_missing (GlAge h _) = (if gl_half h = None then Some (STR ''the half-life (or the isotope)'') else None)"
| "gl_missing (GlLeft h _) = (if gl_half h = None then Some (STR ''the half-life (or the isotope)'') else None)"
| "gl_missing _ = None"

definition bad_half :: "hl \<Rightarrow> bool" where
  "bad_half h \<longleftrightarrow> (case gl_half h of Some y \<Rightarrow> y \<le> 0 | None \<Rightarrow> False)"

fun gl_impossible :: "geol_req \<Rightarrow> String.literal option" where
  "gl_impossible (GlAge h m) =
     (if bad_half h then Some (STR ''A half-life must be positive.'')
      else (case m of
              MFrac f \<Rightarrow> (if 0 < f \<and> f \<le> 1 then None
                          else Some (STR ''The fraction remaining must be between 0 and 100%.''))
            | MRatio r \<Rightarrow> (if r < 0 then Some (STR ''A daughter-to-parent ratio cannot be negative.'') else None)))"
| "gl_impossible (GlLeft h _) = (if bad_half h then Some (STR ''A half-life must be positive.'') else None)"
| "gl_impossible (GlPlateRate _ y) = (if y \<le> 0 then Some (STR ''The time must be positive.'') else None)"
| "gl_impossible _ = None"

section \<open>Values\<close>

definition log2_fa :: "floatarith \<Rightarrow> floatarith" where
  "log2_fa a = fdiv (floatarith.Ln a) (floatarith.Ln (I 2))"

lemma interp_log2_fa [simp]: "interpret_floatarith (log2_fa a) xs = log 2 (interpret_floatarith a xs)"
  by (simp add: log2_fa_def log_def)

fun gl_xval :: "geol_req \<Rightarrow> xexpr" where
  "gl_xval (GlPlateDist rate y) = XRat (rate * y / 1000000)"
| "gl_xval (GlPlateRate km y) = XRat (km * 100000 / y)"
| "gl_xval (GlDepthTemp g d s) = XRat (s + g * d)"
| "gl_xval (GlAge h (MRatio r)) =
     (if r = 0 then XRat 0
      else XFa dprec (floatarith.Mult (Q (hv h)) (log2_fa (floatarith.Add (I 1) (Q r)))))"
| "gl_xval (GlAge h (MFrac f)) =
     (if f = 1 then XRat 0
      else XFa dprec (floatarith.Mult (Q (hv h)) (log2_fa (Q (1 / f)))))"
| "gl_xval (GlLeft h y) =
     (if y = 0 then XRat 1
      else XFa dprec (floatarith.Powr (Q (1 / 2)) (Q (y / hv h))))"

text \<open>The defining formulas, over the reals.\<close>
definition age_ratio_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "age_ratio_spec h r = rl h * log 2 (1 + rl r)"
definition age_frac_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "age_frac_spec h f = rl h * log 2 (1 / rl f)"
definition left_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "left_spec h y = (1 / 2) powr (rl y / rl h)"

fun gl_phys :: "geol_req \<Rightarrow> real" where
  "gl_phys (GlPlateDist rate y) = rl rate * rl y / 1000000"
| "gl_phys (GlPlateRate km y) = rl km * 100000 / rl y"
| "gl_phys (GlDepthTemp g d s) = rl s + rl g * rl d"
| "gl_phys (GlAge h (MRatio r)) = age_ratio_spec (hv h) r"
| "gl_phys (GlAge h (MFrac f)) = age_frac_spec (hv h) f"
| "gl_phys (GlLeft h y) = left_spec (hv h) y"

definition gl_kernel :: "geol_req \<Rightarrow> outcome" where
  "gl_kernel r = (case gl_missing r of Some w \<Rightarrow> Decline (Under w)
     | None \<Rightarrow> (case gl_impossible r of Some w \<Rightarrow> Decline (Imposs w) | None \<Rightarrow> Value (gl_xval r)))"

theorem gl_underspecified: "gl_kernel r = Decline (Under w) \<longleftrightarrow> gl_missing r = Some w"
  by (auto simp: gl_kernel_def split: option.splits)

theorem gl_impossible_iff:
  "gl_kernel r = Decline (Imposs w) \<longleftrightarrow> gl_missing r = None \<and> gl_impossible r = Some w"
  by (auto simp: gl_kernel_def split: option.splits)

lemma gl_value_cases:
  "gl_kernel r = Value x \<Longrightarrow> gl_missing r = None \<and> gl_impossible r = None \<and> x = gl_xval r"
  by (auto simp: gl_kernel_def split: option.splits)

lemma gl_not_word: "gl_kernel r \<noteq> Word t" "gl_kernel r \<noteq> Note"
  by (auto simp: gl_kernel_def split: option.splits)

lemma pos_half: "gl_missing (GlAge h m) = None \<Longrightarrow> gl_impossible (GlAge h m) = None \<Longrightarrow> 0 < hv h"
  by (cases h) (auto simp: bad_half_def hv_def split: if_splits)

lemma pos_half_left: "gl_missing (GlLeft h y) = None \<Longrightarrow> gl_impossible (GlLeft h y) = None \<Longrightarrow> 0 < hv h"
  by (cases h) (auto simp: bad_half_def hv_def split: if_splits)

lemma half_powr_log2:
  assumes "0 < y"
  shows "(1 / 2) powr (log 2 y) = 1 / y"
proof -
  have l2: "ln (2::real) \<noteq> 0" by simp
  have "ln (1 / 2) = - ln (2::real)" by (simp add: ln_div)
  then have "(1 / 2) powr (log 2 y) = exp (log 2 y * (- ln 2))" by (simp add: powr_def)
  also have "log 2 y * (- ln 2) = - ln y" using l2 by (simp add: log_def)
  finally have "(1 / 2) powr (log 2 y) = exp (- ln y)" by simp
  then show ?thesis using assms by (simp add: exp_minus exp_ln inverse_eq_divide)
qed

theorem gl_value_sound:
  assumes "gl_kernel r = Value x"
  shows "gl_missing r = None \<and> gl_impossible r = None \<and> xsem x = gl_phys r"
proof -
  have c: "gl_missing r = None" "gl_impossible r = None" "x = gl_xval r" using gl_value_cases[OF assms] by auto
  have "xsem (gl_xval r) = gl_phys r"
  proof (cases r)
    case (GlAge h m)
    then show ?thesis using c
      by (cases m) (simp_all add: age_ratio_spec_def age_frac_spec_def of_rat_divide of_rat_add split: if_splits)
  next
    case (GlLeft h y)
    then show ?thesis using c by (simp add: left_spec_def of_rat_divide split: if_splits)
  qed (simp_all add: of_rat_mult of_rat_divide of_rat_add)
  then show ?thesis using c by simp
qed

text \<open>An age from a daughter/parent ratio satisfies the decay law: the parent remaining
at that age is the fraction @{text "1/(1 + D/P)"}.\<close>
theorem age_ratio_decay_law:
  assumes "0 < h" "0 \<le> r"
  shows "(1 / 2) powr (age_ratio_spec h r / rl h) * (1 + rl r) = 1"
proof -
  have h: "rl h \<noteq> 0" using assms(1) by (simp add: zero_less_of_rat_iff)
  have r: "0 < 1 + rl r" using assms(2) by (simp add: zero_le_of_rat_iff add_pos_nonneg)
  have "age_ratio_spec h r / rl h = log 2 (1 + rl r)" using h by (simp add: age_ratio_spec_def)
  then show ?thesis using half_powr_log2[OF r] r by simp
qed

text \<open>An age from a remaining fraction satisfies the decay law: after that age the
fraction left is the one given.\<close>
theorem age_fraction_decay_law:
  assumes "0 < h" "0 < f"
  shows "(1 / 2) powr (age_frac_spec h f / rl h) = rl f"
proof -
  have h: "rl h \<noteq> 0" using assms(1) by (simp add: zero_less_of_rat_iff)
  have f: "0 < rl f" using assms(2) by (simp add: zero_less_of_rat_iff)
  have "age_frac_spec h f / rl h = log 2 (1 / rl f)" using h by (simp add: age_frac_spec_def)
  then show ?thesis using half_powr_log2[of "1 / rl f"] f by simp
qed

theorem left_after_one_half_life:
  assumes "0 < h" shows "left_spec h h = 1 / 2"
proof -
  have "rl h \<noteq> 0" using assms by (simp add: zero_less_of_rat_iff)
  then show ?thesis by (simp add: left_spec_def)
qed

theorem left_composes: "left_spec h (y1 + y2) = left_spec h y1 * left_spec h y2"
  by (simp add: left_spec_def add_divide_distrib powr_add of_rat_add)

theorem gl_age_ratio_law:
  assumes k: "gl_kernel (GlAge h (MRatio r)) = Value x"
  shows "(1 / 2) powr (xsem x / rl (hv h)) * (1 + rl r) = 1"
proof -
  have c: "gl_missing (GlAge h (MRatio r)) = None" "gl_impossible (GlAge h (MRatio r)) = None"
    using gl_value_cases[OF k] by auto
  have hp: "0 < hv h" using pos_half[OF c] by simp
  have r0: "0 \<le> r" using c(2) by (auto split: if_splits)
  have "xsem x = age_ratio_spec (hv h) r" using gl_value_sound[OF k] by simp
  then show ?thesis using age_ratio_decay_law[OF hp r0] by simp
qed

theorem gl_age_fraction_law:
  assumes k: "gl_kernel (GlAge h (MFrac f)) = Value x"
  shows "(1 / 2) powr (xsem x / rl (hv h)) = rl f \<and> 0 < f \<and> f \<le> 1"
proof -
  have c: "gl_missing (GlAge h (MFrac f)) = None" "gl_impossible (GlAge h (MFrac f)) = None"
    using gl_value_cases[OF k] by auto
  have hp: "0 < hv h" using pos_half[OF c] by simp
  have f0: "0 < f \<and> f \<le> 1" using c(2) by (auto split: if_splits)
  have "xsem x = age_frac_spec (hv h) f" using gl_value_sound[OF k] by simp
  moreover have fp: "0 < f" using f0 by simp
  ultimately show ?thesis using age_fraction_decay_law[OF hp fp] f0 by simp
qed

section \<open>Text\<close>

definition ystr_opt :: "xexpr \<Rightarrow> String.literal option" where
  "ystr_opt x = (case xint x of None \<Rightarrow> None | Some (lo, hi) \<Rightarrow>
     (let m = (lo + hi) / 2 in
      if 10 ^ 9 \<le> m then map_option (\<lambda>s. s + STR '' billion years'') (render_x GGeo (scale_x (1 / 1000000000) x))
      else if 10 ^ 6 \<le> m then map_option (\<lambda>s. s + STR '' million years'') (render_x GGeo (scale_x (1 / 1000000) x))
      else map_option (\<lambda>s. s + STR '' years'') (render_x GGeo x)))"

definition ystr :: "xexpr \<Rightarrow> String.literal" where
  "ystr x = (case ystr_opt x of Some s \<Rightarrow> s | None \<Rightarrow> STR ''?'')"

theorem ystr_opt_sound:
  assumes "ystr_opt x = Some s"
  shows "(\<exists>s'. render_x GGeo x = Some s' \<and> s = s' + STR '' years'') \<or>
         (\<exists>s'. render_x GGeo (scale_x (1 / 1000000) x) = Some s' \<and> s = s' + STR '' million years'') \<or>
         (\<exists>s'. render_x GGeo (scale_x (1 / 1000000000) x) = Some s' \<and> s = s' + STR '' billion years'')"
  using assms
  by (auto simp: ystr_opt_def Let_def split: option.splits prod.splits if_splits)

definition gl_label :: "hl \<Rightarrow> String.literal" where
  "gl_label h = (case h of HlGiven y \<Rightarrow> STR ''half-life '' + ystr (XRat y)
     | HlIso i \<Rightarrow> iso_label i | HlNone \<Rightarrow> STR '''')"

definition g1 :: "rat \<Rightarrow> String.literal" where
  "g1 q = showx GGeo (XRat q)"

fun gl_kind :: "geol_req \<Rightarrow> String.literal" where
  "gl_kind (GlPlateDist _ _) = STR ''plate_distance''"
| "gl_kind (GlPlateRate _ _) = STR ''plate_rate''"
| "gl_kind (GlDepthTemp _ _ _) = STR ''depth_temp''"
| "gl_kind (GlAge _ (MRatio _)) = STR ''age_ratio''"
| "gl_kind (GlAge _ (MFrac _)) = STR ''age_fraction''"
| "gl_kind (GlLeft _ _) = STR ''fraction_left''"

fun gl_text :: "geol_req \<Rightarrow> xexpr \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "gl_text (GlPlateDist rate y) x V = STR ''The distance is '' + V + STR '' km ('' + g1 rate + STR '' mm/yr x ''
     + ystr (XRat y) + STR ''; 1 mm/yr = 1 km per million years).''"
| "gl_text (GlPlateRate km y) x V = STR ''The rate is '' + V + STR '' cm per year ('' + g1 km + STR '' km / ''
     + ystr (XRat y) + STR '' = '' + g1 (km * 1000000 / y) + STR '' mm/yr).''"
| "gl_text (GlDepthTemp g d s) x V = STR ''The temperature is '' + V + STR '' C ('' + g1 s + STR '' C + '' + g1 g
     + STR '' C/km x '' + g1 d + STR '' km).''"
| "gl_text (GlAge h (MRatio r)) x V = STR ''The age is '' + V + STR '' (t_half log2(1 + D/P) = ''
     + ystr (XRat (hv h)) + STR '' x log2(1 + '' + g1 r + STR ''); '' + gl_label h + STR '').''"
| "gl_text (GlAge h (MFrac f)) x V = STR ''The age is '' + V + STR '' (t_half log2(1/f) = ''
     + ystr (XRat (hv h)) + STR '' x log2(1/'' + g1 f + STR ''); '' + gl_label h + STR '').''"
| "gl_text (GlLeft h y) x V = STR ''The fraction remaining is '' + V + STR '' ('' + showx GGeo (scale_x 100 x)
     + STR ''%; (1/2)^('' + ystr (XRat y) + STR '' / '' + ystr (XRat (hv h)) + STR ''); '' + gl_label h + STR '').''"

fun gl_render :: "geol_req \<Rightarrow> xexpr \<Rightarrow> String.literal option" where
  "gl_render (GlAge _ _) x = ystr_opt x"
| "gl_render r x = render_x GGeo x"

definition gl_reply :: "geol_req \<Rightarrow> reply" where
  "gl_reply r = (case gl_kernel r of
      Value x \<Rightarrow> reply_with (gl_render r) (gl_kind r) (gl_text r x) x
    | Decline w \<Rightarrow> decline_reply (gl_kind r) w
    | _ \<Rightarrow> decline_reply (gl_kind r) Imprecise)"

theorem gl_answered_iff:
  "answered (gl_reply r) \<longleftrightarrow> (\<exists>x s. gl_kernel r = Value x \<and> gl_render r x = Some s)"
  using gl_not_word[of r] by (cases "gl_kernel r")
    (auto simp: gl_reply_def reply_with_def decline_reply_def split: option.splits decl.splits)


text \<open>Explicit input conditions for impossible requests. A missing half-life
is an underspecified request, not an impossible one.\<close>
theorem gl_fraction_decline:
  "(\<exists>w. gl_kernel (GlAge h (MFrac f)) = Decline (Imposs w)) \<longleftrightarrow>
   (\<exists>y. gl_half h = Some y \<and> (y \<le> 0 \<or> f \<le> 0 \<or> 1 < f))"
  by (cases h) (auto simp: gl_kernel_def bad_half_def split: if_splits)

theorem gl_ratio_decline:
  "(\<exists>w. gl_kernel (GlAge h (MRatio r)) = Decline (Imposs w)) \<longleftrightarrow>
   (\<exists>y. gl_half h = Some y \<and> (y \<le> 0 \<or> r < 0))"
  by (cases h) (auto simp: gl_kernel_def bad_half_def split: if_splits)

theorem gl_remaining_decline:
  "(\<exists>w. gl_kernel (GlLeft h t) = Decline (Imposs w)) \<longleftrightarrow>
   (\<exists>y. gl_half h = Some y \<and> y \<le> 0)"
  by (cases h) (auto simp: gl_kernel_def bad_half_def split: if_splits)

theorem gl_plate_rate_decline:
  "(\<exists>w. gl_kernel (GlPlateRate d t) = Decline (Imposs w)) \<longleftrightarrow> t \<le> 0"
  by (auto simp: gl_kernel_def)

end
