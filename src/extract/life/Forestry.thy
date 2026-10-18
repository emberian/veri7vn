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
  | F_BAStand bool "(rat \<times> rat) list"

definition stand_squares :: "(rat \<times> rat) list \<Rightarrow> rat" where
  "stand_squares xs = sum_list (map (\<lambda>(d,n). d*d*n) xs)"
definition stand_valid :: "(rat \<times> rat) list \<Rightarrow> bool" where
  "stand_valid xs \<longleftrightarrow> list_all (\<lambda>(d,n). 0 \<le> d \<and> 0 \<le> n) xs"

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
| "f_phys (F_BAStand metric xs) = (if metric then pi / 40000 * rl(stand_squares xs) else rl(ba_coeff * stand_squares xs))"
| "f_phys r = 0"

fun f_fa :: "freq \<Rightarrow> floatarith" where
  "f_fa (F_Height ds a eye ft) = (case eye of
       None \<Rightarrow> floatarith.Mult (Q ds) (tan_fa a)
     | Some e \<Rightarrow> floatarith.Add (floatarith.Mult (Q ds) (tan_fa a)) (Q e))"
| "f_fa (F_BAm d) = floatarith.Mult floatarith.Pi (floatarith.Power (Q (d / 200)) 2)"
| "f_fa (F_BAStand metric xs) = (if metric then floatarith.Mult floatarith.Pi (Q (stand_squares xs / 40000)) else Q (ba_coeff * stand_squares xs))"
| "f_fa r = I 0"

lemma interp_f_fa_height:
  "interpret_floatarith (f_fa (F_Height ds a eye ft)) xs = f_phys (F_Height ds a eye ft)"
  by (cases eye) simp_all

lemma interp_f_fa_bam:
  "interpret_floatarith (f_fa (F_BAm d)) xs = f_phys (F_BAm d)"
  by (simp add: of_rat_divide of_rat_numeral_eq)

fun f_bad :: "freq \<Rightarrow> reason option" where
  "f_bad (F_Doyle d l) = (if d \<le> doyle_floor then Some R_doyle else if l < 0 then Some R_forest_domain else None)"
| "f_bad (F_Tpa a b) = (if a \<le> 0 \<or> b \<le> 0 then Some R_zero else None)"
| "f_bad (F_Height ds a eye ft) = (if \<not>(0 < a \<and> a < 90) then Some R_angle else if ds \<le> 0 \<or> (case eye of None \<Rightarrow> False | Some e \<Rightarrow> e < 0) then Some R_forest_domain else None)"
| "f_bad (F_Smalian d1 d2 l) = (if d1 < 0 \<or> d2 < 0 \<or> l < 0 then Some R_forest_domain else None)"
| "f_bad (F_BA d) = (if d < 0 then Some R_forest_domain else None)"
| "f_bad (F_BAPA d n) = (if d < 0 \<or> n < 0 then Some R_forest_domain else None)"
| "f_bad (F_BAm d) = (if d < 0 then Some R_forest_domain else None)"
| "f_bad (F_BAStand metric xs) = (if stand_valid xs then None else Some R_forest_domain)"

fun f_answer :: "freq \<Rightarrow> outcome" where
  "f_answer (F_Doyle d l) = Exact (STR ''doyle'') ((d - 4) * (d - 4) * l / 16)"
| "f_answer (F_Smalian d1 d2 l) = Exact (STR ''smalian'') (l * (ba_ft d1 + ba_ft d2) / 2)"
| "f_answer (F_Tpa a b) = Exact (STR ''tpa'') (acre_sqft / (a * b))"
| "f_answer (F_Height ds a eye ft) = approx_out (STR ''height'') (f_fa (F_Height ds a eye ft))"
| "f_answer (F_BA d) = Exact (STR ''basal_area'') (ba_ft d)"
| "f_answer (F_BAPA d n) = Exact (STR ''ba_per_acre'') (ba_ft d * n)"
| "f_answer (F_BAm d) = approx_out (STR ''basal_area_m2'') (f_fa (F_BAm d))"
| "f_answer (F_BAStand metric xs) = (if metric then approx_out (STR ''ba_per_acre_m2'') (f_fa (F_BAStand metric xs))
     else Exact (STR ''ba_per_acre'') (ba_coeff * stand_squares xs))"

definition f_kernel :: "freq \<Rightarrow> outcome" where
  "f_kernel r = (case f_bad r of Some w \<Rightarrow> Decline (Impossible w) | None \<Rightarrow> f_answer r)"

lemma f_answer_decline: "f_answer r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r) (auto dest: approx_out_decline split: if_splits)

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
  shows "4 < d \<and> 0 \<le> l \<and> q * 16 = (d - 4) * (d - 4) * l"
proof -
  have nd: "f_bad (F_Doyle d l) = None" using assms by (cases "f_bad (F_Doyle d l)") (simp_all add: f_kernel_def)
  then have "4 < d \<and> 0 \<le> l" by (auto simp: doyle_floor_def split: if_splits)
  then show ?thesis using assms nd by (simp add: f_kernel_def)
qed

theorem doyle_declines_small:
  "d \<le> 4 \<Longrightarrow> f_kernel (F_Doyle d l) = Decline (Impossible R_doyle)"
  by (simp add: f_kernel_def doyle_floor_def)

theorem smalian_value:
  "0 \<le> d1 \<Longrightarrow> 0 \<le> d2 \<Longrightarrow> 0 \<le> l \<Longrightarrow> f_kernel (F_Smalian d1 d2 l) = Exact (STR ''smalian'') (l * (ba_ft d1 + ba_ft d2) / 2)"
  by (simp add: f_kernel_def)

text \<open>A log with equal ends is a cylinder: its Smalian volume is its length
times its end area.\<close>
theorem smalian_cylinder:
  "0 \<le> d \<Longrightarrow> 0 \<le> l \<Longrightarrow> f_kernel (F_Smalian d d l) = Exact (STR ''smalian'') (l * ba_ft d)"
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
  "0 \<le> d \<Longrightarrow> f_kernel (F_BA d) = Exact (STR ''basal_area'') (5454 / 1000000 * d * d)"
  by (simp add: f_kernel_def ba_ft_def ba_coeff_def)

theorem ba_per_acre_value:
  "0 \<le> d \<Longrightarrow> 0 \<le> n \<Longrightarrow> f_kernel (F_BAPA d n) = Exact (STR ''ba_per_acre'') (ba_ft d * n)"
  by (simp add: f_kernel_def)

lemma f_fa_phys: "interpret_floatarith (f_fa r) xs = f_phys r"
proof (cases r)
  case (F_Height a b c d) then show ?thesis using interp_f_fa_height by blast
next
  case (F_BAm d) then show ?thesis using interp_f_fa_bam by blast
qed (simp_all add: of_rat_divide of_rat_mult)

theorem forestry_approx:
  assumes "f_kernel r = Approx k d"
  shows "f_bad r = None \<and> \<bar>dec_val d - f_phys r\<bar> \<le> \<bar>f_phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "f_bad r = None" using assms by (cases "f_bad r") (simp_all add: f_kernel_def)
  have a: "f_answer r = Approx k d" using assms nd by (simp add: f_kernel_def)
  have "\<exists>c. approx_out c (f_fa r) = Approx k d" using a by (cases r) (auto split: if_splits)
  then obtain c where "approx_out c (f_fa r) = Approx k d" by blast
  from approx_out_sound[OF this] show ?thesis using nd f_fa_phys[of r "[]"] by simp
qed

theorem height_angle_range:
  assumes "f_kernel (F_Height ds a eye ft) = Approx k d"
  shows "0 < a \<and> a < 90"
  using assms by (auto simp: f_kernel_def split: if_splits option.splits)

section \<open>Declines stated apart from the code\<close>

lemma f_decl_iff: "f_kernel r = Decline (Impossible w) \<longleftrightarrow> f_bad r = Some w"
proof (cases "f_bad r")
  case None
  then show ?thesis by (auto simp: f_kernel_def dest: f_answer_decline)
next
  case (Some x)
  then show ?thesis by (auto simp: f_kernel_def)
qed

theorem doyle_declines_iff:
  "f_kernel (F_Doyle d l) = Decline (Impossible R_doyle) \<longleftrightarrow> d \<le> 4"
  by (simp add: f_decl_iff doyle_floor_def)

theorem tpa_declines_iff:
  "f_kernel (F_Tpa a b) = Decline (Impossible R_zero) \<longleftrightarrow> a \<le> 0 \<or> b \<le> 0"
  by (simp add: f_decl_iff)

theorem height_declines_iff:
  "f_kernel (F_Height ds a eye ft) = Decline (Impossible R_angle) \<longleftrightarrow> a \<le> 0 \<or> 90 \<le> a"
  by (auto simp: f_decl_iff split: if_splits)

section \<open>Stand aggregation laws\<close>

lemma stand_squares_append:
  "stand_squares (xs @ ys) = stand_squares xs + stand_squares ys"
  by (simp add: stand_squares_def)

lemma stand_squares_nonnegative:
  "stand_valid xs \<Longrightarrow> 0 \<le> stand_squares xs"
  unfolding stand_valid_def stand_squares_def
  by (induction xs) (auto intro: add_nonneg_nonneg mult_nonneg_nonneg)

theorem stand_basal_area_value:
  assumes "f_kernel (F_BAStand False xs) = Exact k q"
  shows "stand_valid xs \<and> q = ba_coeff * sum_list (map (\<lambda>(d,n). d*d*n) xs) \<and> 0 \<le> q"
proof -
  have valid: "stand_valid xs" using assms by (auto simp: f_kernel_def split: if_splits)
  have q: "q = ba_coeff * stand_squares xs" using assms valid by (simp add: f_kernel_def)
  have nonneg: "0 \<le> stand_squares xs" by (rule stand_squares_nonnegative[OF valid])
  have "0 \<le> q" using q nonneg by (simp add: ba_coeff_def)
  then show ?thesis using valid q by (simp add: stand_squares_def)
qed

theorem stand_basal_area_additive:
  "f_phys (F_BAStand metric (xs @ ys)) = f_phys (F_BAStand metric xs) + f_phys (F_BAStand metric ys)"
  by (simp add: stand_squares_append of_rat_add of_rat_mult algebra_simps)

theorem stand_uniform_class:
  "f_kernel (F_BAStand False [(d,n)]) = f_kernel (F_BAPA d n)"
  by (auto simp: f_kernel_def stand_valid_def stand_squares_def ba_ft_def algebra_simps)

theorem stand_qmd_equivalence:
  assumes "q*q*n = stand_squares xs"
  shows "ba_coeff * stand_squares xs = ba_ft q * n"
  using assms by (simp add: ba_ft_def algebra_simps)

theorem height_physical_domain:
  assumes "f_kernel (F_Height ds a eye ft) = Approx k d"
  shows "0 < ds \<and> 0 < a \<and> a < 90 \<and> (case eye of None \<Rightarrow> True | Some e \<Rightarrow> 0 \<le> e)"
  using assms by (cases eye) (auto simp: f_kernel_def split: if_splits)

definition f_unread :: reply where
  "f_unread = mk_reply (Decline (Underspecified (STR ''Supply complete, uniquely assigned diameters/counts or log/height dimensions with units; an arithmetic mean alone does not establish exact stand basal area.''))) (STR '' '')"

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
| "f_text (F_BAStand metric xs) o' = STR ''The basal area is '' + vtxt o' +
    (if metric then STR '' m2 per acre'' else STR '' sq ft per acre'') +
    STR '' (sum of each stated diameter-class area times its trees per acre).''"

definition f_reply :: "freq \<Rightarrow> reply" where
  "f_reply r = (let result = f_kernel r in mk_reply result (f_text r result))"

end
