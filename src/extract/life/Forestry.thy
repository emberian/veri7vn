theory Forestry
  imports Life_Core
begin

text \<open>
  Lane S09-life, forestry (upstream/root/specialists/forestry/organ_forestry_v1.py):
  forest mensuration. Basal area in square feet, trees per acre, Doyle and
  Smalian volumes and per-acre basal area are exact rationals; the metric basal
  area (pi) and the clinometer height (tan) are enclosed with interval
  arithmetic. The constants are checked against the organ by tables_check.py.
\<close>

definition ba_coeff :: rat where "ba_coeff = 5454 / 1000000"
definition acre_sqft :: rat where "acre_sqft = 43560"
definition doyle_floor :: rat where "doyle_floor = 4"

definition ba_ft :: "rat \<Rightarrow> rat" where "ba_ft d = ba_coeff * d * d"

datatype freq =
    F_Doyle rat rat
  | F_Smalian rat rat rat
  | F_Tpa rat rat
  | F_Height rat rat "rat option" bool
  | F_BA rat
  | F_BAPA rat rat
  | F_BAm rat

text \<open>The clinometer height uses the tangent of the angle in degrees;
@{text "tan x = cos (pi/2 - x) / cos x"} is what the interval arithmetic
encloses.\<close>
lemma tan_as_cos: "cos (pi * inverse 2 + - x) * inverse (cos x) = tan x"
proof -
  have s: "sin x = cos (pi / 2 - x)" using sin_cos_eq[of x] by simp
  have a: "pi * inverse 2 + - x = pi / 2 - x" by (auto simp: field_simps)
  have "tan x = sin x * inverse (cos x)" by (simp add: tan_def divide_inverse)
  also have "\<dots> = cos (pi / 2 - x) * inverse (cos x)" by (simp only: s)
  finally show ?thesis by (simp only: a)
qed

definition rad_fa :: "rat \<Rightarrow> floatarith" where
  "rad_fa a = floatarith.Mult (floatarith.Mult (Q a) floatarith.Pi) (floatarith.Inverse (I 180))"

definition tan_fa :: "rat \<Rightarrow> floatarith" where
  "tan_fa a = floatarith.Mult
     (floatarith.Cos (floatarith.Add (floatarith.Mult floatarith.Pi (floatarith.Inverse (I 2))) (floatarith.Minus (rad_fa a))))
     (floatarith.Inverse (floatarith.Cos (rad_fa a)))"

lemma interp_tan_fa [simp]:
  "interpret_floatarith (tan_fa a) xs = tan (rl a * pi / 180)"
proof -
  have r: "interpret_floatarith (rad_fa a) xs = rl a * pi / 180" unfolding rad_fa_def by (simp only: interpret_floatarith.simps interp_Q interp_I of_int_numeral divide_inverse)
  have e: "interpret_floatarith (tan_fa a) xs
      = cos (pi * inverse 2 + - (rl a * pi / 180)) * inverse (cos (rl a * pi / 180))"
    unfolding tan_fa_def by (simp only: interpret_floatarith.simps interp_I of_int_numeral r)
  show ?thesis by (simp only: e tan_as_cos)
qed

fun f_phys :: "freq \<Rightarrow> real" where
  "f_phys (F_Height ds a eye ft) = rl ds * tan (rl a * pi / 180) + (case eye of None \<Rightarrow> 0 | Some e \<Rightarrow> rl e)"
| "f_phys (F_BAm d) = pi * (rl d / 200) ^ 2"
| "f_phys r = 0"

fun f_fa :: "freq \<Rightarrow> floatarith" where
  "f_fa (F_Height ds a eye ft) = (case eye of
       None \<Rightarrow> floatarith.Mult (Q ds) (tan_fa a)
     | Some e \<Rightarrow> floatarith.Add (floatarith.Mult (Q ds) (tan_fa a)) (Q e))"
| "f_fa (F_BAm d) = floatarith.Mult floatarith.Pi (floatarith.Power (Q (d / 200)) 2)"
| "f_fa r = I 0"

lemma interp_f_fa_height:
  "interpret_floatarith (f_fa (F_Height ds a eye ft)) xs = f_phys (F_Height ds a eye ft)"
  by (cases eye) simp_all

lemma interp_f_fa_bam:
  "interpret_floatarith (f_fa (F_BAm d)) xs = f_phys (F_BAm d)"
  by (simp add: of_rat_divide of_rat_numeral_eq)

fun f_bad :: "freq \<Rightarrow> reason option" where
  "f_bad (F_Doyle d l) = (if d \<le> doyle_floor then Some R_doyle else None)"
| "f_bad (F_Tpa a b) = (if a \<le> 0 \<or> b \<le> 0 then Some R_zero else None)"
| "f_bad (F_Height ds a eye ft) = (if 0 < a \<and> a < 90 then None else Some R_angle)"
| "f_bad r = None"

fun f_answer :: "freq \<Rightarrow> outcome" where
  "f_answer (F_Doyle d l) = Exact (STR ''doyle'') ((d - 4) * (d - 4) * l / 16)"
| "f_answer (F_Smalian d1 d2 l) = Exact (STR ''smalian'') (l * (ba_ft d1 + ba_ft d2) / 2)"
| "f_answer (F_Tpa a b) = Exact (STR ''tpa'') (acre_sqft / (a * b))"
| "f_answer (F_Height ds a eye ft) = approx_out (STR ''height'') (f_fa (F_Height ds a eye ft))"
| "f_answer (F_BA d) = Exact (STR ''basal_area'') (ba_ft d)"
| "f_answer (F_BAPA d n) = Exact (STR ''ba_per_acre'') (ba_ft d * n)"
| "f_answer (F_BAm d) = approx_out (STR ''basal_area_m2'') (f_fa (F_BAm d))"

definition f_kernel :: "freq \<Rightarrow> outcome" where
  "f_kernel r = (case f_bad r of Some w \<Rightarrow> Decline (Impossible w) | None \<Rightarrow> f_answer r)"

lemma f_answer_decline: "f_answer r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r) (auto dest: approx_out_decline)

theorem f_impossible:
  "(\<exists>w. f_kernel r = Decline (Impossible w)) \<longleftrightarrow> f_bad r \<noteq> None"
proof (cases "f_bad r")
  case None
  then show ?thesis by (auto simp: f_kernel_def dest: f_answer_decline)
next
  case (Some w)
  then show ?thesis by (auto simp: f_kernel_def)
qed

theorem f_imprecise:
  assumes "f_kernel r = Decline Imprecise"
  shows "f_bad r = None"
  using assms by (cases "f_bad r") (simp_all add: f_kernel_def)

section \<open>What each kind means\<close>

theorem doyle_value:
  assumes "f_kernel (F_Doyle d l) = Exact k q"
  shows "4 < d \<and> q * 16 = (d - 4) * (d - 4) * l"
proof -
  have nd: "f_bad (F_Doyle d l) = None" using assms by (cases "f_bad (F_Doyle d l)") (simp_all add: f_kernel_def)
  then have "4 < d" by (auto simp: doyle_floor_def split: if_splits)
  then show ?thesis using assms nd by (simp add: f_kernel_def)
qed

theorem doyle_declines_small:
  "d \<le> 4 \<Longrightarrow> f_kernel (F_Doyle d l) = Decline (Impossible R_doyle)"
  by (simp add: f_kernel_def doyle_floor_def)

theorem smalian_value:
  "f_kernel (F_Smalian d1 d2 l) = Exact (STR ''smalian'') (l * (ba_ft d1 + ba_ft d2) / 2)"
  by (simp add: f_kernel_def)

text \<open>A log with equal ends is a cylinder: its Smalian volume is its length
times its end area.\<close>
theorem smalian_cylinder:
  "f_kernel (F_Smalian d d l) = Exact (STR ''smalian'') (l * ba_ft d)"
  by (simp add: f_kernel_def field_simps)

theorem tpa_value:
  assumes "f_kernel (F_Tpa a b) = Exact k q"
  shows "0 < a \<and> 0 < b \<and> q * (a * b) = 43560"
proof -
  have nd: "f_bad (F_Tpa a b) = None" using assms by (cases "f_bad (F_Tpa a b)") (simp_all add: f_kernel_def)
  then have ab: "0 < a" "0 < b" by (auto split: if_splits)
  have q: "q = acre_sqft / (a * b)" using assms nd by (simp add: f_kernel_def)
  have "a * b \<noteq> 0" using ab by simp
  then show ?thesis using ab q by (simp add: acre_sqft_def field_simps)
qed

theorem basal_area_value:
  "f_kernel (F_BA d) = Exact (STR ''basal_area'') (5454 / 1000000 * d * d)"
  by (simp add: f_kernel_def ba_ft_def ba_coeff_def)

theorem ba_per_acre_value:
  "f_kernel (F_BAPA d n) = Exact (STR ''ba_per_acre'') (ba_ft d * n)"
  by (simp add: f_kernel_def)

lemma f_fa_phys: "interpret_floatarith (f_fa r) xs = f_phys r"
proof (cases r)
  case (F_Height a b c d) then show ?thesis using interp_f_fa_height by blast
next
  case (F_BAm d) then show ?thesis using interp_f_fa_bam by blast
qed simp_all

theorem forestry_approx:
  assumes "f_kernel r = Approx k d"
  shows "f_bad r = None \<and> \<bar>dec_val d - f_phys r\<bar> \<le> \<bar>f_phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "f_bad r = None" using assms by (cases "f_bad r") (simp_all add: f_kernel_def)
  have a: "f_answer r = Approx k d" using assms nd by (simp add: f_kernel_def)
  have "\<exists>c. approx_out c (f_fa r) = Approx k d" using a by (cases r) auto
  then obtain c where "approx_out c (f_fa r) = Approx k d" by blast
  from approx_out_sound[OF this] show ?thesis using nd f_fa_phys[of r "[]"] by simp
qed

theorem height_angle_range:
  assumes "f_kernel (F_Height ds a eye ft) = Approx k d"
  shows "0 < a \<and> a < 90"
  using assms by (cases "f_bad (F_Height ds a eye ft)") (auto simp: f_kernel_def split: if_splits)

section \<open>Response text\<close>

fun f_text :: "freq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "f_text (F_Doyle d l) o' = STR ''The Doyle volume is '' + vtxt o' + STR '' board feet ((D - 4)^2 x L / 16 = (''
     + plain_lit d + STR '' - 4)^2 x '' + plain_lit l + STR '' / 16).''"
| "f_text (F_Smalian d1 d2 l) o' = STR ''The log volume is '' + vtxt o' + STR '' cubic feet (Smalian: L x (A1 + A2)/2 = ''
     + plain_lit l + STR '' x ('' + plain_lit (ba_ft d1) + STR '' + '' + plain_lit (ba_ft d2) + STR '')/2 sq ft).''"
| "f_text (F_Tpa a b) o' = STR ''That is '' + vtxt o' + STR '' trees per acre (43560 sq ft / ('' + plain_lit a
     + STR '' ft x '' + plain_lit b + STR '' ft)).''"
| "f_text (F_Height ds a eye ft) o' = (case eye of
     None \<Rightarrow> STR ''The tree is '' + vtxt o' + (if ft then STR '' ft'' else STR '' m'')
        + STR '' tall above eye level ('' + plain_lit ds + STR '' x tan '' + plain_lit a + STR '' degrees).''
   | Some e \<Rightarrow> STR ''The tree is '' + vtxt o' + (if ft then STR '' ft'' else STR '' m'')
        + STR '' tall ('' + plain_lit ds + STR '' x tan '' + plain_lit a + STR '' degrees + '' + plain_lit e
        + STR '' eye height).'')"
| "f_text (F_BA d) o' = STR ''The basal area is '' + vtxt o' + STR '' sq ft (0.005454 x '' + plain_lit d + STR ''^2 in).''"
| "f_text (F_BAPA d n) o' = STR ''The basal area is '' + vtxt o' + STR '' sq ft per acre (0.005454 x '' + plain_lit d
     + STR ''^2 x '' + plain_lit n + STR '' trees/acre).''"
| "f_text (F_BAm d) o' = STR ''The basal area is '' + vtxt o' + STR '' m2 (pi x ('' + plain_lit d + STR '' cm / 200)^2).''"

definition f_reply :: "freq \<Rightarrow> reply" where
  "f_reply r = mk_reply (f_kernel r) (f_text r (f_kernel r))"

end
