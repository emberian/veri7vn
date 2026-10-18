theory AnatomyAgri
  imports Main "HOL.Rat" "HOL-Library.Code_Target_Numeral" "Veri7vn_Commons.Commons_Num"
begin

text \<open>
  Lane S10: five shipped Oracle7 specialists as one verified HOL kernel.
    anatomy, anatomy-r2   upstream/root/specialists/anatomy*/organ_anatomy_{v1,r2}.py
    agriculture-v2        upstream/root/specialists/agriculture-v2/organ_agriculture_{v1,v2}.py
    gardening             upstream/root/specialists/gardening/organ_gardening_v1.py
    nutrition-label-v2    upstream/root/specialists/nutrition-label-v2/organ_nutrition_label_{v1,v2}.py
  A typed request (what the question asks, its numbers already read off by the
  untrusted recognizer) goes to an outcome: a rational value, a label, or a decline.
  Every formula is exact rational arithmetic (no square root or logarithm is needed).
  The tables (anatomy counts and facts, grade columns, test weights, daily values,
  unit factors) are HOL constants transcribed from the organs; tables_check.py parses
  the organ files and this file and fails on any difference.
\<close>

section \<open>Number layout\<close>

declare digits.simps [simp del]

lemma digits_small: "n < 10 \<Longrightarrow> digits n = [n]"
  using digits.simps [of n] by simp

lemma digits_big: "\<not> n < 10 \<Longrightarrow> digits n = digits (n div 10) @ [n mod 10]"
  using digits.simps [of n] by simp

definition lval :: "nat list \<Rightarrow> nat" where
  "lval ds = foldl (\<lambda>a d. 10 * a + d) 0 ds"

lemma lval_snoc: "lval (ds @ [d]) = 10 * lval ds + d"
  by (simp add: lval_def)

text \<open>The digit list of a number denotes the number.\<close>
theorem lval_digits: "lval (digits n) = n"
proof (induction n rule: digits.induct)
  case (1 n)
  show ?case
  proof (cases "n < 10")
    case True
    then show ?thesis by (simp add: digits_small lval_def)
  next
    case False
    have ih: "lval (digits (n div 10)) = n div 10" using 1 False by blast
    have e: "10 * (n div 10) + n mod 10 = n" by arith
    show ?thesis using False ih e by (simp add: digits_big lval_snoc)
  qed
qed

definition cat :: "String.literal list \<Rightarrow> String.literal" where
  "cat ss = foldr (+) ss (STR '''')"

definition sn :: "nat \<Rightarrow> String.literal" where
  "sn n = lit (digits n)"

definition frac_digits :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "frac_digits k f = replicate (k - length (digits f)) 0 @ digits f"

text \<open>A non-negative rational rounded to @{text k} decimals, half up: the integer
@{text "n"} with @{text "n / 10^k"} nearest to the value.\<close>
definition rnd :: "nat \<Rightarrow> rat \<Rightarrow> nat" where
  "rnd k x = nat (floor (x * 10 ^ k + 1 / 2))"

theorem rnd_sound:
  assumes "0 \<le> x"
  shows "\<bar>of_nat (rnd k x) - x * 10 ^ k\<bar> \<le> 1 / 2"
proof -
  have x0: "0 \<le> x * 10 ^ k" using assms by (rule mult_nonneg_nonneg) simp
  let ?y = "x * 10 ^ k + 1 / 2"
  have y0: "0 \<le> ?y" using x0 by simp
  have f0: "0 \<le> floor ?y" using y0 by simp
  have n: "(of_nat (rnd k x) :: rat) = of_int (floor ?y)"
  proof -
    have "int (rnd k x) = floor ?y" using f0 by (simp add: rnd_def)
    then have "of_int (int (rnd k x)) = (of_int (floor ?y) :: rat)" by simp
    then show ?thesis by simp
  qed
  have fl: "of_int (floor ?y) \<le> ?y \<and> ?y < of_int (floor ?y) + 1"
    using floor_correct [of ?y] by simp
  show ?thesis unfolding n abs_le_iff using fl by (intro conjI) linarith+
qed

lemma floor_half: "floor (of_nat m + 1 / 2 :: rat) = int m"
  by (auto simp: floor_eq_iff)

text \<open>A whole number is rounded to itself, so counts are stated exactly.\<close>
theorem rnd_nat: "rnd 0 (of_nat m) = m"
  by (simp add: rnd_def floor_half)

definition fixed_lit :: "nat \<Rightarrow> nat \<Rightarrow> String.literal" where
  "fixed_lit k n =
     (let ip = n div 10 ^ k; fr = strip_zeros (frac_digits k (n mod 10 ^ k))
      in lit (digits ip) + (if fr = [] then STR '''' else STR ''.'' + lit fr))"

definition group_lit :: "nat \<Rightarrow> String.literal" where
  "group_lit n =
     (let ds = digits n; m = length ds
      in foldr (\<lambda>(i, d) s. (if 0 < i \<and> (m - i) mod 3 = 0 then STR '','' else STR '''') + digit_lit d + s)
           (zip [0..<m] ds) (STR ''''))"

text \<open>Python's @{text "g"} in the organs: three decimals with trailing zeros dropped, or a
comma-grouped whole number from 100,000 up; @{text g2}: two decimals.\<close>
definition g3 :: "rat \<Rightarrow> String.literal" where
  "g3 x = (if x < 100000 then fixed_lit 3 (rnd 3 x) else group_lit (rnd 0 x))"

definition g2 :: "rat \<Rightarrow> String.literal" where
  "g2 x = fixed_lit 2 (rnd 2 x)"

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

section \<open>Anatomy tables\<close>

datatype count_id = C_bones | C_skull | C_rib_pairs | C_ribs | C_cervical | C_thoracic | C_lumbar
  | C_hand | C_foot | C_carpal | C_tarsal | C_primary | C_permanent | C_chambers | C_valves
  | C_lobes | C_cranial | C_spinal | C_chromosomes

definition count_order :: "count_id list" where
  "count_order = [C_bones, C_skull, C_rib_pairs, C_ribs, C_cervical, C_thoracic, C_lumbar,
    C_hand, C_foot, C_carpal, C_tarsal, C_primary, C_permanent, C_chambers, C_valves,
    C_lobes, C_cranial, C_spinal, C_chromosomes]"

text \<open>organ_anatomy_v1.COUNTS, in the organ's order (the first pattern that matches wins).\<close>
fun count_val :: "count_id \<Rightarrow> nat" where
  "count_val C_bones = 206"
| "count_val C_skull = 22"
| "count_val C_rib_pairs = 12"
| "count_val C_ribs = 24"
| "count_val C_cervical = 7"
| "count_val C_thoracic = 12"
| "count_val C_lumbar = 5"
| "count_val C_hand = 27"
| "count_val C_foot = 26"
| "count_val C_carpal = 8"
| "count_val C_tarsal = 7"
| "count_val C_primary = 20"
| "count_val C_permanent = 32"
| "count_val C_chambers = 4"
| "count_val C_valves = 4"
| "count_val C_lobes = 5"
| "count_val C_cranial = 12"
| "count_val C_spinal = 31"
| "count_val C_chromosomes = 46"

fun count_desc :: "count_id \<Rightarrow> String.literal" where
  "count_desc C_bones = STR ''bones in the adult human skeleton''"
| "count_desc C_skull = STR ''bones in the skull (8 cranial + 14 facial)''"
| "count_desc C_rib_pairs = STR ''pairs of ribs''"
| "count_desc C_ribs = STR ''ribs (12 pairs)''"
| "count_desc C_cervical = STR ''cervical vertebrae''"
| "count_desc C_thoracic = STR ''thoracic vertebrae''"
| "count_desc C_lumbar = STR ''lumbar vertebrae''"
| "count_desc C_hand = STR ''bones in each hand (8 carpals, 5 metacarpals, 14 phalanges)''"
| "count_desc C_foot = STR ''bones in each foot (7 tarsals, 5 metatarsals, 14 phalanges)''"
| "count_desc C_carpal = STR ''carpal bones in each wrist''"
| "count_desc C_tarsal = STR ''tarsal bones in each ankle''"
| "count_desc C_primary = STR ''primary (baby) teeth''"
| "count_desc C_permanent = STR ''permanent teeth, including wisdom teeth''"
| "count_desc C_chambers = STR ''chambers of the heart (2 atria, 2 ventricles)''"
| "count_desc C_valves = STR ''heart valves (tricuspid, pulmonary, mitral, aortic)''"
| "count_desc C_lobes = STR ''lobes in the lungs (3 right, 2 left)''"
| "count_desc C_cranial = STR ''pairs of cranial nerves''"
| "count_desc C_spinal = STR ''pairs of spinal nerves''"
| "count_desc C_chromosomes = STR ''chromosomes in a human body cell (23 pairs)''"

text \<open>The textbook counts agree with each other and with the parts their descriptions name.\<close>
theorem anatomy_counts_consistent:
  "count_val C_skull = 8 + 14 \<and> count_val C_hand = count_val C_carpal + 5 + 14 \<and>
   count_val C_foot = count_val C_tarsal + 5 + 14 \<and> count_val C_ribs = 2 * count_val C_rib_pairs \<and>
   count_val C_rib_pairs = count_val C_thoracic \<and> count_val C_lobes = 3 + 2 \<and>
   count_val C_chambers = 2 + 2 \<and> count_val C_chromosomes = 2 * 23 \<and>
   count_val C_permanent = 4 * 8 \<and> count_val C_primary = 4 * 5"
  by simp

text \<open>These scopes state when the fixed-count table is applicable. They
are a model-selection policy, not a theorem establishing biological facts.\<close>
datatype life_stage = AdultStage | DevelopingStage | NewbornStage

fun age_applicable :: "count_id \<Rightarrow> life_stage \<Rightarrow> bool" where
  "age_applicable C_bones a = (a = AdultStage)"
| "age_applicable C_skull a = (a = AdultStage)"
| "age_applicable C_hand a = (a = AdultStage)"
| "age_applicable C_foot a = (a = AdultStage)"
| "age_applicable C_carpal a = (a = AdultStage)"
| "age_applicable C_tarsal a = (a = AdultStage)"
| "age_applicable C_primary a = (a = DevelopingStage)"
| "age_applicable C_permanent a = (a = AdultStage)"
| "age_applicable c a = True"

datatype super_id = S_bone_largest | S_bone_smallest | S_organ_largest | S_muscle_longest
  | S_internal_largest | S_artery_largest

definition super_order :: "super_id list" where
  "super_order = [S_bone_largest, S_bone_smallest, S_organ_largest, S_muscle_longest,
    S_internal_largest, S_artery_largest]"

text \<open>organ_anatomy_v1.SUPER: the name, and the note in parentheses.\<close>
fun super_name :: "super_id \<Rightarrow> String.literal" where
  "super_name S_bone_largest = STR ''femur''"
| "super_name S_bone_smallest = STR ''stapes''"
| "super_name S_organ_largest = STR ''skin''"
| "super_name S_muscle_longest = STR ''sartorius''"
| "super_name S_internal_largest = STR ''liver''"
| "super_name S_artery_largest = STR ''aorta''"

fun super_note :: "super_id \<Rightarrow> String.literal" where
  "super_note S_bone_largest = STR ''the thigh bone''"
| "super_note S_bone_smallest = STR ''in the middle ear''"
| "super_note S_organ_largest = STR ''by area and weight''"
| "super_note S_muscle_longest = STR ''in the thigh''"
| "super_note S_internal_largest = STR ''the largest internal organ''"
| "super_note S_artery_largest = STR ''leaving the left ventricle''"

datatype made_id = P_insulin | P_bile | P_urine | P_red_cells | P_melatonin | P_thyroxine
  | P_adrenaline | P_surfactant | P_pepsin

definition made_order :: "made_id list" where
  "made_order = [P_insulin, P_bile, P_urine, P_red_cells, P_melatonin, P_thyroxine,
    P_adrenaline, P_surfactant, P_pepsin]"

text \<open>organ_anatomy_v1.MAKES: the organ that makes the substance.\<close>
fun made_organ :: "made_id \<Rightarrow> String.literal" where
  "made_organ P_insulin = STR ''pancreas''"
| "made_organ P_bile = STR ''liver''"
| "made_organ P_urine = STR ''kidneys''"
| "made_organ P_red_cells = STR ''red bone marrow''"
| "made_organ P_melatonin = STR ''pineal gland''"
| "made_organ P_thyroxine = STR ''thyroid gland''"
| "made_organ P_adrenaline = STR ''adrenal glands''"
| "made_organ P_surfactant = STR ''lungs (type II alveolar cells)''"
| "made_organ P_pepsin = STR ''stomach''"

section \<open>Agriculture tables\<close>

datatype nutrient = Nit | Pho | Pot

text \<open>The nutrient's column in an N-P-K grade, and its name on the label.\<close>
fun grade_pct :: "nutrient \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "grade_pct Nit a b c = a"
| "grade_pct Pho a b c = b"
| "grade_pct Pot a b c = c"

fun nut_name :: "nutrient \<Rightarrow> String.literal" where
  "nut_name Nit = STR ''N''"
| "nut_name Pho = STR ''P2O5''"
| "nut_name Pot = STR ''K2O''"

datatype crop = Corn | Maize | Soybeans | Soybean | Wheat | Sorghum | Barley | Oats

definition crop_order :: "crop list" where
  "crop_order = [Corn, Maize, Soybeans, Soybean, Wheat, Sorghum, Barley, Oats]"

text \<open>USDA standard test weights in lb per bushel (organ_agriculture_v1.TW).\<close>
fun test_weight :: "crop \<Rightarrow> nat" where
  "test_weight Corn = 56"
| "test_weight Maize = 56"
| "test_weight Soybeans = 60"
| "test_weight Soybean = 60"
| "test_weight Wheat = 60"
| "test_weight Sorghum = 56"
| "test_weight Barley = 48"
| "test_weight Oats = 32"

fun crop_name :: "crop \<Rightarrow> String.literal" where
  "crop_name Corn = STR ''corn''"
| "crop_name Maize = STR ''maize''"
| "crop_name Soybeans = STR ''soybeans''"
| "crop_name Soybean = STR ''soybean''"
| "crop_name Wheat = STR ''wheat''"
| "crop_name Sorghum = STR ''sorghum''"
| "crop_name Barley = STR ''barley''"
| "crop_name Oats = STR ''oats''"

datatype yunit = KgHa | THa

text \<open>The three agronomic constants the organ uses, tied to the units they come from:
an acre is 43,560 sq ft of 144 sq in; the pound per acre is 0.45359237 kg over 0.40468564224
hectares (0.4046... ha per acre, in the organ's rounded 1.12085); an acre-inch is 3,630 cu ft
of 7.48052 US gallons.\<close>
definition seed_area :: rat where "seed_area = 6272640"
definition lbac_to_kgha :: rat where "lbac_to_kgha = 112085 / 100000"
definition gal_per_acre_inch :: rat where "gal_per_acre_inch = 27154"

theorem agri_constants_grounded:
  "seed_area = 43560 * 144 \<and>
   \<bar>lbac_to_kgha - (45359237 / 100000000) / (40468564224 / 100000000000)\<bar> < 1 / 100000 \<and>
   \<bar>gal_per_acre_inch - 3630 * (748052 / 100000)\<bar> < 1 / 2"
  by (simp add: seed_area_def lbac_to_kgha_def gal_per_acre_inch_def)

section \<open>Gardening table\<close>

definition gal_per_sqft_inch :: rat where "gal_per_sqft_inch = 623 / 1000"

text \<open>One inch of water over one square foot: 7.48052 gallons per cubic foot over 12 (the
organ's 0.623, within 0.1\%).\<close>
theorem water_constant_grounded:
  "\<bar>gal_per_sqft_inch - (748052 / 100000) / 12\<bar> < 1 / 1000"
  by (simp add: gal_per_sqft_inch_def)

section \<open>Nutrition tables\<close>

datatype dunit = U_mg | U_g | U_mcg

fun unit_label :: "dunit \<Rightarrow> String.literal" where
  "unit_label U_mg = STR ''mg''"
| "unit_label U_g = STR ''g''"
| "unit_label U_mcg = STR ''mcg''"

text \<open>organ_nutrition_label_v1's conversion dictionary: from the amount's unit to the label's.\<close>
fun unit_factor :: "dunit \<Rightarrow> dunit \<Rightarrow> rat option" where
  "unit_factor U_g U_mg = Some 1000"
| "unit_factor U_mg U_g = Some (1 / 1000)"
| "unit_factor U_mcg U_mg = Some (1 / 1000)"
| "unit_factor U_mg U_mcg = Some 1000"
| "unit_factor a b = (if a = b then Some 1 else None)"

datatype dvn = Sodium | SatFat | TotFat | Chol | Fiber | AddSug | Carb | Protein | Calcium
  | Iron | Potassium | VitD

definition dv_order :: "dvn list" where
  "dv_order = [Sodium, SatFat, TotFat, Chol, Fiber, AddSug, Carb, Protein, Calcium, Iron,
    Potassium, VitD]"

text \<open>FDA 2020 Daily Values for adults (organ_nutrition_label_v1.DV): amount, unit, name.\<close>
fun dv_amount :: "dvn \<Rightarrow> rat" where
  "dv_amount Sodium = 2300"
| "dv_amount SatFat = 20"
| "dv_amount TotFat = 78"
| "dv_amount Chol = 300"
| "dv_amount Fiber = 28"
| "dv_amount AddSug = 50"
| "dv_amount Carb = 275"
| "dv_amount Protein = 50"
| "dv_amount Calcium = 1300"
| "dv_amount Iron = 18"
| "dv_amount Potassium = 4700"
| "dv_amount VitD = 20"

fun dv_unit :: "dvn \<Rightarrow> dunit" where
  "dv_unit Sodium = U_mg"
| "dv_unit SatFat = U_g"
| "dv_unit TotFat = U_g"
| "dv_unit Chol = U_mg"
| "dv_unit Fiber = U_g"
| "dv_unit AddSug = U_g"
| "dv_unit Carb = U_g"
| "dv_unit Protein = U_g"
| "dv_unit Calcium = U_mg"
| "dv_unit Iron = U_mg"
| "dv_unit Potassium = U_mg"
| "dv_unit VitD = U_mcg"

fun dv_name :: "dvn \<Rightarrow> String.literal" where
  "dv_name Sodium = STR ''sodium''"
| "dv_name SatFat = STR ''saturated fat''"
| "dv_name TotFat = STR ''total fat''"
| "dv_name Chol = STR ''cholesterol''"
| "dv_name Fiber = STR ''dietary fiber''"
| "dv_name AddSug = STR ''added sugars''"
| "dv_name Carb = STR ''total carbohydrate''"
| "dv_name Protein = STR ''protein''"
| "dv_name Calcium = STR ''calcium''"
| "dv_name Iron = STR ''iron''"
| "dv_name Potassium = STR ''potassium''"
| "dv_name VitD = STR ''vitamin D''"

theorem unit_factor_inverse:
  "unit_factor a b = Some f \<Longrightarrow> unit_factor b a = Some g \<Longrightarrow> f * g = 1"
  by (cases a; cases b) auto

datatype bmi_cat = Underweight | Healthy | Overweight | Obesity

text \<open>CDC adult categories: underweight below 18.5, healthy from 18.5 to below 25,
overweight from 25 to below 30, obesity from 30.\<close>
definition bmi_category :: "rat \<Rightarrow> bmi_cat" where
  "bmi_category b = (if b < 37 / 2 then Underweight else if b < 25 then Healthy
     else if b < 30 then Overweight else Obesity)"

theorem bmi_category_exact:
  "(bmi_category b = Underweight \<longleftrightarrow> b < 37 / 2) \<and>
   (bmi_category b = Healthy \<longleftrightarrow> 37 / 2 \<le> b \<and> b < 25) \<and>
   (bmi_category b = Overweight \<longleftrightarrow> 25 \<le> b \<and> b < 30) \<and>
   (bmi_category b = Obesity \<longleftrightarrow> 30 \<le> b)"
  by (auto simp: bmi_category_def)

fun cat_name :: "bmi_cat \<Rightarrow> String.literal" where
  "cat_name Underweight = STR ''underweight''"
| "cat_name Healthy = STR ''healthy weight''"
| "cat_name Overweight = STR ''overweight''"
| "cat_name Obesity = STR ''obesity''"

text \<open>Atwater factors in kcal per gram (protein, carbohydrate, fat, alcohol) and the pound
and inch constant of the imperial BMI formula 703 = 0.45359237 / 0.0254^2 (rounded).\<close>
definition bmi_imperial_const :: rat where "bmi_imperial_const = 703"

theorem bmi_const_grounded:
  "\<bar>bmi_imperial_const - (45359237 / 100000000) / ((254 / 10000) ^ 2)\<bar> < 1 / 10"
  unfolding bmi_imperial_const_def abs_less_iff by (simp add: power2_eq_square)

section \<open>Requests and the kernel\<close>

datatype shape = Dims rat rat | Area rat
datatype depth = Inches rat | Feet rat
datatype mheight = Mm rat | Mcm rat
datatype iheight = Iin rat | Ftin nat rat

datatype seed_scope = TotalSeeds | PerAcreSeeds

datatype fert_context = TotalFertilizer | PerAcreFertilizer | TotalFromRate rat | RateFromTotal rat

fun fert_amount :: "fert_context \<Rightarrow> rat \<Rightarrow> rat" where
  "fert_amount TotalFertilizer q = q"
| "fert_amount PerAcreFertilizer q = q"
| "fert_amount (TotalFromRate acres) q = q * acres"
| "fert_amount (RateFromTotal acres) q = q / acres"

fun fert_context_valid :: "fert_context \<Rightarrow> bool" where
  "fert_context_valid (TotalFromRate acres) = (0 \<le> acres)"
| "fert_context_valid (RateFromTotal acres) = (0 < acres)"
| "fert_context_valid x = True"

definition grade_valid :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "grade_valid a b c \<longleftrightarrow> a \<le> 100 \<and> b \<le> 100 \<and> c \<le> 100"

lemma fert_amount_nonnegative:
  "fert_context_valid ctx \<Longrightarrow> 0 \<le> q \<Longrightarrow> 0 \<le> fert_amount ctx q"
  by (cases ctx) (auto intro: mult_nonneg_nonneg divide_nonneg_nonneg)



datatype portion = GramPortion rat | ServingPortion rat
fun portion_qty :: "portion \<Rightarrow> rat" where
  "portion_qty (GramPortion q) = q"
| "portion_qty (ServingPortion q) = q"
fun portion_same_unit :: "portion \<Rightarrow> portion \<Rightarrow> bool" where
  "portion_same_unit (GramPortion a) (GramPortion b) = True"
| "portion_same_unit (ServingPortion a) (ServingPortion b) = True"
| "portion_same_unit a b = False"
fun portion_weight :: "rat option \<Rightarrow> portion \<Rightarrow> rat" where
  "portion_weight sz (GramPortion q) = q"
| "portion_weight sz (ServingPortion q) = q * (case sz of None \<Rightarrow> 1 | Some s \<Rightarrow> s)"
definition portion_size_valid :: "rat option \<Rightarrow> bool" where
  "portion_size_valid sz \<longleftrightarrow> (case sz of None \<Rightarrow> True | Some s \<Rightarrow> 0 < s)"
definition portion_compatible :: "portion \<Rightarrow> portion \<Rightarrow> rat option \<Rightarrow> bool" where
  "portion_compatible reference target sz \<longleftrightarrow> portion_same_unit reference target \<or> sz \<noteq> None"
lemma portion_weight_positive:
  "0 < portion_qty extent \<Longrightarrow> portion_size_valid sz \<Longrightarrow> 0 < portion_weight sz extent"
  by (cases extent; cases sz) (auto simp: portion_size_valid_def intro: mult_pos_pos)
lemma portion_weight_nonnegative:
  "0 \<le> portion_qty extent \<Longrightarrow> portion_size_valid sz \<Longrightarrow> 0 \<le> portion_weight sz extent"
  by (cases extent; cases sz) (auto simp: portion_size_valid_def intro: mult_nonneg_nonneg)
fun portion_text :: "portion \<Rightarrow> String.literal" where
  "portion_text (GramPortion q) = g3 q + STR '' g''"
| "portion_text (ServingPortion q) = g3 q + STR '' servings''"

datatype request =
    Count count_id
  | CountAt count_id life_stage
  | Superlative super_id
  | Produces made_id
  | FertProduct nutrient nat nat nat rat
  | NutrientLb nutrient nat nat nat rat
  | FertilizerNeed fert_context nutrient nat nat nat rat
  | FertilizerHas fert_context nutrient nat nat nat rat
  | FertUnread
  | SeedsPerAcre rat rat
  | SeedsNeeded rat rat
  | SeedsExpected seed_scope rat rat
  | SeedsMinimum seed_scope rat rat
  | SeedsUnread
  | Yield rat crop yunit
  | AcreInch rat "rat option"
  | AgriUnderspecified
  | GardenWater shape rat
  | GardenFert rat shape
  | GardenGrid rat rat rat
  | GardenRectGrid rat rat rat rat
  | GardenNeedOrientation
  | GardenBags shape depth rat
  | GardenYards shape depth
  | GardenFeet shape depth
  | BmiMetric rat mheight bool
  | BmiImperial rat iheight bool
  | Kcal rat rat rat rat
  | KcalPortion rat rat rat rat portion portion "rat option"
  | PctFatCal rat rat
  | PctDV dvn rat dunit
  | NutUnderspecified
  | NutAdultOnly

text \<open>In @{text FertProduct} the rate is pounds of the nutrient per acre; in @{text NutrientLb}
the amount is pounds of product. @{text SeedsNeeded} takes the germination percentage and the
target stand. @{text AcreInch} takes inches of water and, if the question gave them, acres.
@{text GardenGrid} takes the bed in feet and the spacing in inches. @{text GardenBags} takes the
bag size in cubic feet. @{text BmiMetric} the mass in kg; @{text BmiImperial} the weight in lb.
@{text Kcal} takes grams of protein, carbohydrate, fat and alcohol. @{text PctFatCal} takes the
fat in grams and the energy in kcal. @{text PctDV} takes the amount in the unit it was given.\<close>

definition shape_area :: "shape \<Rightarrow> rat" where
  "shape_area s = (case s of Dims l w \<Rightarrow> l * w | Area a \<Rightarrow> a)"

definition depth_ft :: "depth \<Rightarrow> rat" where
  "depth_ft d = (case d of Inches x \<Rightarrow> x / 12 | Feet x \<Rightarrow> x)"

definition garden_vol :: "shape \<Rightarrow> depth \<Rightarrow> rat" where
  "garden_vol s d = shape_area s * depth_ft d"

definition mheight_m :: "mheight \<Rightarrow> rat" where
  "mheight_m h = (case h of Mm x \<Rightarrow> x | Mcm x \<Rightarrow> x / 100)"

definition iheight_in :: "iheight \<Rightarrow> rat" where
  "iheight_in h = (case h of Iin x \<Rightarrow> x | Ftin f i \<Rightarrow> of_nat f * 12 + i)"

text \<open>Plants on a square grid: the whole number of spacings that fit along a side
(the greatest integer not above side * 12 / spacing); bags: the least integer not below
volume / bag size.\<close>
definition fit :: "rat \<Rightarrow> rat \<Rightarrow> nat" where
  "fit side s = nat (floor (side * 12 / s))"

definition bags_for :: "rat \<Rightarrow> rat \<Rightarrow> nat" where
  "bags_for vol b = nat (- floor (- (vol / b)))"

definition bmi_m :: "rat \<Rightarrow> mheight \<Rightarrow> rat" where
  "bmi_m kg h = kg / (mheight_m h) ^ 2"

definition bmi_i :: "rat \<Rightarrow> iheight \<Rightarrow> rat" where
  "bmi_i lb h = bmi_imperial_const * lb / (iheight_in h) ^ 2"

definition yield_val :: "rat \<Rightarrow> crop \<Rightarrow> yunit \<Rightarrow> rat" where
  "yield_val bu c u = bu * of_nat (test_weight c) * lbac_to_kgha / (case u of KgHa \<Rightarrow> 1 | THa \<Rightarrow> 1000)"

definition acre_val :: "rat \<Rightarrow> rat option \<Rightarrow> rat" where
  "acre_val i ao = i * (case ao of None \<Rightarrow> 1 | Some a \<Rightarrow> a) * gal_per_acre_inch"

definition kcal_total :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "kcal_total p c f a = 4 * p + 4 * c + 9 * f + 7 * a"

datatype reason = R_no_nutrient | R_germination | R_nonpositive | R_nonnegative | R_fertilizer | R_nutrition_domain | R_unit_pair
datatype decline = Underspecified | Impossible reason
datatype outcome = Value rat | Label String.literal | Decline decline

text \<open>Underspecified: a recognised question whose amounts could not be read (agriculture v2 and
nutrition v2 decline in-domain), or no macronutrient given.\<close>
fun underspecified :: "request \<Rightarrow> bool" where
  "underspecified (CountAt c a) = (\<not> age_applicable c a)"
| "underspecified AgriUnderspecified = True"
| "underspecified SeedsUnread = True"
| "underspecified FertUnread = True"
| "underspecified GardenNeedOrientation = True"
| "underspecified NutUnderspecified = True"
| "underspecified NutAdultOnly = True"
| "underspecified (KcalPortion p c f a reference target sz) = (\<not> portion_compatible reference target sz)"
| "underspecified r = False"

text \<open>Impossible: the question cannot have an answer (a nutrient the grade lacks, a germination
rate outside (0, 100], a non-positive spacing, bag size, height or energy, units that do not
convert).\<close>
fun impossible :: "request \<Rightarrow> reason option" where
  "impossible (FertProduct n a b c r) = (if grade_pct n a b c = 0 then Some R_no_nutrient
     else if r < 0 \<or> \<not> grade_valid a b c then Some R_fertilizer else None)"
| "impossible (NutrientLb n a b c q) = (if q < 0 \<or> \<not> grade_valid a b c then Some R_fertilizer else None)"
| "impossible (FertilizerNeed ctx n a b c r) = (if grade_pct n a b c = 0 then Some R_no_nutrient
     else if r < 0 \<or> \<not> grade_valid a b c \<or> \<not> fert_context_valid ctx then Some R_fertilizer else None)"
| "impossible (FertilizerHas ctx n a b c q) = (if q < 0 \<or> \<not> grade_valid a b c \<or> \<not> fert_context_valid ctx then Some R_fertilizer else None)"
| "impossible (SeedsPerAcre r s) = (if r \<le> 0 \<or> s \<le> 0 then Some R_nonpositive else None)"
| "impossible (SeedsNeeded gp t) = (if \<not> (0 < gp \<and> gp \<le> 100) then Some R_germination else if t < 0 then Some R_nonpositive else None)"
| "impossible (SeedsExpected scope gp t) = (if \<not> (0 < gp \<and> gp \<le> 100) then Some R_germination else if t < 0 then Some R_nonpositive else None)"
| "impossible (SeedsMinimum scope gp t) = (if \<not> (0 < gp \<and> gp \<le> 100) then Some R_germination else if t < 0 then Some R_nonpositive else None)"
| "impossible (GardenRectGrid l w rs ps) = (if rs \<le> 0 \<or> ps \<le> 0 \<or> l < 0 \<or> w < 0 then Some R_nonpositive else None)"
| "impossible (GardenGrid l w s) = (if s \<le> 0 then Some R_nonpositive else None)"
| "impossible (GardenBags sh d b) = (if b \<le> 0 then Some R_nonpositive else None)"
| "impossible (BmiMetric kg h c) = (if kg \<le> 0 \<or> mheight_m h \<le> 0 then Some R_nonpositive else None)"
| "impossible (BmiImperial lb h c) = (if lb \<le> 0 \<or> iheight_in h \<le> 0 then Some R_nonpositive else None)"
| "impossible (KcalPortion p c f a reference target sz) =
     (if p < 0 \<or> c < 0 \<or> f < 0 \<or> a < 0 \<or> portion_qty target < 0 then Some R_nonnegative
      else if portion_qty reference \<le> 0 \<or> \<not> portion_size_valid sz then Some R_nonpositive else None)"
| "impossible (Kcal p c f a) = (if p < 0 \<or> c < 0 \<or> f < 0 \<or> a < 0 then Some R_nonnegative else None)"
| "impossible (PctFatCal f k) = (if k \<le> 0 then Some R_nonpositive else if f < 0 \<or> k < 9*f then Some R_nutrition_domain else None)"
| "impossible (PctDV d a u) = (if unit_factor u (dv_unit d) = None then Some R_unit_pair else if a < 0 then Some R_nutrition_domain else None)"
| "impossible r = None"

definition dv_amount_in :: "dvn \<Rightarrow> rat \<Rightarrow> dunit \<Rightarrow> rat" where
  "dv_amount_in d a u = (case unit_factor u (dv_unit d) of Some f \<Rightarrow> a * f | None \<Rightarrow> 0)"

fun compute :: "request \<Rightarrow> outcome" where
  "compute (Count c) = Value (of_nat (count_val c))"
| "compute (CountAt c a) = Value (of_nat (count_val c))"
| "compute (Superlative s) = Label (super_name s)"
| "compute (Produces m) = Label (made_organ m)"
| "compute (FertProduct n a b c r) = Value (r * 100 / of_nat (grade_pct n a b c))"
| "compute (NutrientLb n a b c q) = Value (q * of_nat (grade_pct n a b c) / 100)"
| "compute (FertilizerNeed ctx n a b c r) = Value (fert_amount ctx r * 100 / of_nat (grade_pct n a b c))"
| "compute (FertilizerHas ctx n a b c q) = Value (fert_amount ctx q * of_nat (grade_pct n a b c) / 100)"
| "compute FertUnread = Decline Underspecified"
| "compute (SeedsPerAcre r s) = Value (seed_area / (r * s))"
| "compute (SeedsNeeded gp t) = Value (t / (gp / 100))"
| "compute (SeedsExpected scope gp t) = Value (t / (gp / 100))"
| "compute (SeedsMinimum scope gp t) = Value (of_nat (bags_for t (gp / 100)))"
| "compute (Yield bu c u) = Value (yield_val bu c u)"
| "compute (AcreInch i ao) = Value (acre_val i ao)"
| "compute SeedsUnread = Decline Underspecified"
| "compute GardenNeedOrientation = Decline Underspecified"
| "compute AgriUnderspecified = Decline Underspecified"
| "compute (GardenWater sh i) = Value (shape_area sh * i * gal_per_sqft_inch)"
| "compute (GardenFert rate sh) = Value (rate * shape_area sh / 1000)"
| "compute (GardenRectGrid l w rs ps) = Value (of_nat (fit l ps * fit w rs))"
| "compute (GardenGrid l w s) = Value (of_nat (fit l s * fit w s))"
| "compute (GardenBags sh d b) = Value (of_nat (bags_for (garden_vol sh d) b))"
| "compute (GardenYards sh d) = Value (garden_vol sh d / 27)"
| "compute (GardenFeet sh d) = Value (garden_vol sh d)"
| "compute (BmiMetric kg h c) =
     (if c then Label (cat_name (bmi_category (bmi_m kg h))) else Value (bmi_m kg h))"
| "compute (BmiImperial lb h c) =
     (if c then Label (cat_name (bmi_category (bmi_i lb h))) else Value (bmi_i lb h))"
| "compute (KcalPortion p c f a reference target sz) =
     Value (kcal_total p c f a * portion_weight sz target / portion_weight sz reference)"
| "compute (Kcal p c f a) = Value (kcal_total p c f a)"
| "compute (PctFatCal f k) = Value (9 * f / k * 100)"
| "compute (PctDV d a u) = Value (dv_amount_in d a u / dv_amount d * 100)"
| "compute NutUnderspecified = Decline Underspecified"
| "compute NutAdultOnly = Decline Underspecified"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (if underspecified r then Decline Underspecified
     else case impossible r of Some w \<Rightarrow> Decline (Impossible w) | None \<Rightarrow> compute r)"

lemma compute_decline:
  "compute r = Decline w \<Longrightarrow> underspecified r"
  by (cases r) (auto split: if_splits)

lemma kernel_cases:
  assumes "kernel r = Decline w"
  shows "(underspecified r \<and> w = Underspecified) \<or>
         (\<not> underspecified r \<and> (\<exists>x. impossible r = Some x \<and> w = Impossible x))"
proof (cases "underspecified r")
  case True then show ?thesis using assms by (simp add: kernel_def)
next
  case False
  show ?thesis
  proof (cases "impossible r")
    case None
    then have "compute r = Decline w" using assms False by (simp add: kernel_def)
    then have "underspecified r" by (rule compute_decline)
    then show ?thesis using False by auto
  next
    case (Some x) then show ?thesis using assms False by (simp add: kernel_def)
  qed
qed

theorem kernel_underspecified:
  "kernel r = Decline Underspecified \<longleftrightarrow> underspecified r"
proof
  assume "underspecified r" then show "kernel r = Decline Underspecified" by (simp add: kernel_def)
next
  assume "kernel r = Decline Underspecified"
  then show "underspecified r" using kernel_cases [of r Underspecified] by auto
qed

theorem kernel_impossible:
  "kernel r = Decline (Impossible w) \<longleftrightarrow> \<not> underspecified r \<and> impossible r = Some w"
proof
  assume "kernel r = Decline (Impossible w)"
  then show "\<not> underspecified r \<and> impossible r = Some w"
    using kernel_cases [of r "Impossible w"] by auto
next
  assume "\<not> underspecified r \<and> impossible r = Some w"
  then show "kernel r = Decline (Impossible w)" by (simp add: kernel_def)
qed

text \<open>Nothing else declines: a request that is not underspecified and not impossible always has
a value or a label.\<close>
theorem kernel_total:
  assumes "\<not> underspecified r" and "impossible r = None"
  shows "(\<exists>v. kernel r = Value v) \<or> (\<exists>l. kernel r = Label l)"
proof (cases "kernel r")
  case (Decline w)
  then show ?thesis using kernel_cases [of r w] assms by auto
qed auto

text \<open>A declined request is declined for one reason only, and a value never accompanies it.\<close>
theorem kernel_decline_iff:
  "(\<exists>w. kernel r = Decline w) \<longleftrightarrow> underspecified r \<or> impossible r \<noteq> None"
proof
  assume "\<exists>w. kernel r = Decline w"
  then obtain w where "kernel r = Decline w" by blast
  then show "underspecified r \<or> impossible r \<noteq> None" using kernel_cases [of r w] by auto
next
  assume "underspecified r \<or> impossible r \<noteq> None"
  then show "\<exists>w. kernel r = Decline w" by (auto simp: kernel_def split: option.splits)
qed

text \<open>A value comes only from a request that is neither underspecified nor impossible, and it is
@{const compute}'s.\<close>
lemma kernel_value:
  assumes "kernel r = Value v"
  shows "\<not> underspecified r" and "impossible r = None" and "compute r = Value v"
proof -
  have a: "\<not> underspecified r" using assms by (cases "underspecified r") (simp_all add: kernel_def)
  moreover have b: "impossible r = None" using assms a by (cases "impossible r") (simp_all add: kernel_def)
  ultimately show "\<not> underspecified r" and "impossible r = None" by simp_all
  show "compute r = Value v" using assms a b by (simp add: kernel_def)
qed

section \<open>What the stated values mean\<close>

subsection \<open>Anatomy\<close>

theorem count_value: "kernel (Count c) = Value (of_nat (count_val c))"
  by (simp add: kernel_def)

text \<open>Age applicability only narrows a fixed-table answer; it cannot
invent a different count. This does not prove the source anatomy facts.\<close>
theorem count_stage_narrows:
  "kernel (CountAt c a) = Value v \<Longrightarrow> kernel (Count c) = Value v"
  by (auto simp: kernel_def split: if_splits)

theorem count_stage_declines_iff:
  "kernel (CountAt c a) = Decline Underspecified \<longleftrightarrow> \<not> age_applicable c a"
  by (simp add: kernel_def)

theorem newborn_bones_declines:
  "kernel (CountAt C_bones NewbornStage) = Decline Underspecified"
  by (simp add: kernel_def)

theorem adult_bones_preserved:
  "kernel (CountAt C_bones AdultStage) = kernel (Count C_bones)"
  by (simp add: kernel_def)

theorem superlative_label: "kernel (Superlative s) = Label (super_name s)"
  by (simp add: kernel_def)

theorem produces_label: "kernel (Produces m) = Label (made_organ m)"
  by (simp add: kernel_def)

subsection \<open>Agriculture\<close>

text \<open>Product for a nutrient rate: the nutrient in that much product is the rate.\<close>
theorem fert_product:
  assumes "grade_pct n a b c \<noteq> 0" and "kernel (FertProduct n a b c r) = Value v"
  shows "v * (of_nat (grade_pct n a b c) / 100) = r"
proof -
  have p: "(of_nat (grade_pct n a b c) :: rat) \<noteq> 0" using assms(1) by simp
  have "v = r * 100 / of_nat (grade_pct n a b c)" using kernel_value(3)[OF assms(2)] by simp
  then show ?thesis using p by (simp add: field_simps)
qed

theorem nutrient_lb:
  assumes "kernel (NutrientLb n a b c q) = Value v"
  shows "v * 100 = q * of_nat (grade_pct n a b c)"
  using kernel_value(3)[OF assms] by simp

text \<open>Applying the product the organ prescribes supplies exactly the nutrient asked for.\<close>
theorem fert_roundtrip:
  assumes "kernel (FertProduct n a b c r) = Value v"
  shows "kernel (NutrientLb n a b c v) = Value r"
proof -
  have np: "grade_pct n a b c \<noteq> 0" using assms
    by (cases "grade_pct n a b c = 0") (auto simp: kernel_def)
  have p: "(of_nat (grade_pct n a b c) :: rat) \<noteq> 0" using np by simp
  have dom: "0 \<le> r" "grade_valid a b c" using assms
    by (auto simp: kernel_def split: if_splits)
  have v: "v = r * 100 / of_nat (grade_pct n a b c)" using kernel_value(3)[OF assms] by simp
  have vn: "0 \<le> v" using dom(1) v by (auto intro: divide_nonneg_nonneg mult_nonneg_nonneg)
  show ?thesis using v p dom vn by (simp add: kernel_def field_simps)
qed

theorem fert_no_nutrient:
  "grade_pct n a b c = 0 \<Longrightarrow> kernel (FertProduct n a b c r) = Decline (Impossible R_no_nutrient)"
  by (simp add: kernel_def)

text \<open>The fertilizer grade columns name N, P2O5 and K2O mass
percentages. An elemental P/K question needs a separate conversion model.
Context converts an explicitly supplied total or per-acre rate to the requested
output dimension before the grade relation is solved.\<close>
theorem fertilizer_need_conserves:
  assumes "kernel (FertilizerNeed ctx n a b c r) = Value v"
  shows "0 \<le> r \<and> grade_valid a b c \<and> fert_context_valid ctx \<and>
    0 < grade_pct n a b c \<and> 0 \<le> v \<and>
    v * (of_nat (grade_pct n a b c) / 100) = fert_amount ctx r"
proof -
  have dom: "0 \<le> r" "grade_valid a b c" "fert_context_valid ctx" "0 < grade_pct n a b c"
    using assms by (auto simp: kernel_def split: if_splits)
  have v: "v = fert_amount ctx r * 100 / of_nat (grade_pct n a b c)"
    using kernel_value(3)[OF assms] by simp
  have amount: "0 \<le> fert_amount ctx r" using fert_amount_nonnegative dom by blast
  have vn: "0 \<le> v" using amount v by (auto intro: divide_nonneg_nonneg mult_nonneg_nonneg)
  show ?thesis using dom v vn by (simp add: field_simps)
qed

theorem fertilizer_has_conserves:
  assumes "kernel (FertilizerHas ctx n a b c q) = Value v"
  shows "0 \<le> q \<and> grade_valid a b c \<and> fert_context_valid ctx \<and>
    0 \<le> v \<and> v \<le> fert_amount ctx q \<and>
    v * 100 = fert_amount ctx q * of_nat (grade_pct n a b c)"
proof -
  have dom: "0 \<le> q" "grade_valid a b c" "fert_context_valid ctx"
    using assms by (auto simp: kernel_def split: if_splits)
  have v: "v = fert_amount ctx q * of_nat (grade_pct n a b c) / 100"
    using kernel_value(3)[OF assms] by simp
  have amount: "0 \<le> fert_amount ctx q" using fert_amount_nonnegative dom by blast
  have pct: "(of_nat (grade_pct n a b c)::rat) \<le> 100"
    using dom(2) by (cases n) (auto simp: grade_valid_def)
  have upper: "fert_amount ctx q * of_nat (grade_pct n a b c) \<le> fert_amount ctx q * 100"
    using mult_left_mono[OF pct amount] .
  have product: "0 \<le> fert_amount ctx q * of_nat (grade_pct n a b c)"
    by (rule mult_nonneg_nonneg[OF amount]) simp
  have vn: "0 \<le> v" using v product by linarith
  have bound: "v \<le> fert_amount ctx q" using v upper by linarith
  show ?thesis using dom v vn bound by simp
qed

theorem fertilizer_scope_inverse:
  "0 < acres \<Longrightarrow> fert_amount (RateFromTotal acres) (fert_amount (TotalFromRate acres) q) = q"
  by simp

theorem seeds_per_acre:
  assumes "0 < r" and "0 < s" and "kernel (SeedsPerAcre r s) = Value v"
  shows "v * (r * s) = 43560 * 144"
proof -
  have "r * s \<noteq> 0" using assms(1,2) by simp
  moreover have "v = seed_area / (r * s)" using assms by (simp add: kernel_def)
  ultimately show ?thesis by (simp add: seed_area_def)
qed

text \<open>Under the supplied germination fraction, the expected stand equals the target.\<close>
theorem seeds_needed:
  assumes "0 < gp" and "gp \<le> 100" and "kernel (SeedsNeeded gp t) = Value v"
  shows "v * (gp / 100) = t"
proof -
  have "gp / 100 \<noteq> (0::rat)" using assms(1) by simp
  moreover have "v = t / (gp / 100)" using assms by (auto simp: kernel_def split: if_splits)
  ultimately show ?thesis by simp
qed

theorem seeds_needed_germination:
  "\<not> (0 < gp \<and> gp \<le> 100) \<Longrightarrow> kernel (SeedsNeeded gp t) = Decline (Impossible R_germination)"
  by (simp add: kernel_def)

theorem yield_kgha:
  "kernel (Yield bu c KgHa) = Value v \<Longrightarrow>
     v * 100000 = bu * of_nat (test_weight c) * 112085"
  by (simp add: kernel_def yield_val_def lbac_to_kgha_def)

theorem yield_tha:
  "kernel (Yield bu c THa) = Value v \<Longrightarrow> kernel (Yield bu c KgHa) = Value w \<Longrightarrow> v * 1000 = w"
  by (simp add: kernel_def yield_val_def field_simps)

theorem acre_inch:
  "kernel (AcreInch i None) = Value v \<Longrightarrow> v = i * 27154"
  "kernel (AcreInch i (Some a)) = Value v \<Longrightarrow> v = (i * a) * 27154"
  by (simp_all add: kernel_def acre_val_def gal_per_acre_inch_def)

subsection \<open>Gardening\<close>

theorem garden_water:
  "kernel (GardenWater sh i) = Value v \<Longrightarrow> v * 1000 = shape_area sh * i * 623"
  by (simp add: kernel_def gal_per_sqft_inch_def)

theorem garden_fert:
  "kernel (GardenFert rate sh) = Value v \<Longrightarrow> v * 1000 = rate * shape_area sh"
  by (simp add: kernel_def)

text \<open>A side of the bed holds the greatest whole number of spacings: this many, and not one more.\<close>
theorem fit_floor:
  assumes "0 < s" and "0 \<le> side"
  shows "of_nat (fit side s) \<le> side * 12 / s \<and> side * 12 / s < of_nat (fit side s) + 1"
proof -
  let ?y = "side * 12 / s"
  have y0: "0 \<le> ?y" using assms by simp
  have f0: "0 \<le> floor ?y" using y0 by simp
  have n: "(of_nat (fit side s) :: rat) = of_int (floor ?y)"
  proof -
    have "int (fit side s) = floor ?y" using f0 by (simp add: fit_def)
    then have "of_int (int (fit side s)) = (of_int (floor ?y) :: rat)" by simp
    then show ?thesis by simp
  qed
  show ?thesis unfolding n using floor_correct [of ?y] by simp
qed

theorem garden_grid:
  "kernel (GardenGrid l w s) = Value v \<Longrightarrow> v = of_nat (fit l s) * of_nat (fit w s)"
  by (drule kernel_value(3)) simp


text \<open>The number of rectangular spacing cells fits the physical bed.
The layout reserves one full spacing cell per plant, with no border plants.\<close>
lemma spacing_cells_fit:
  assumes "0 < a" "0 < b" "0 \<le> l" "0 \<le> w"
  shows "of_nat (fit l a) * of_nat (fit w b) * (a * b) \<le> (l * 12) * (w * 12)"
proof -
  have x: "of_nat (fit l a) * a \<le> l * 12"
    using fit_floor[OF assms(1,3)] assms(1) by (simp add: le_divide_eq)
  have y: "of_nat (fit w b) * b \<le> w * 12"
    using fit_floor[OF assms(2,4)] assms(2) by (simp add: le_divide_eq)
  have "(of_nat (fit l a) * a) * (of_nat (fit w b) * b) \<le> (l * 12) * (w * 12)"
    by (rule mult_mono[OF x y]) (use assms in auto)
  then show ?thesis by (simp add: algebra_simps)
qed

theorem garden_grid_fits:
  assumes "kernel (GardenGrid l w s) = Value v" "0 < s" "0 \<le> l" "0 \<le> w"
  shows "v * s ^ 2 \<le> (l * 12) * (w * 12)"
  using garden_grid[OF assms(1)] spacing_cells_fit[OF assms(2,2,3,4)]
  by (simp add: power2_eq_square)

theorem garden_rect_grid_fits:
  assumes "kernel (GardenRectGrid l w rs ps) = Value v"
  shows "0 < rs \<and> 0 < ps \<and> 0 \<le> l \<and> 0 \<le> w \<and>
    v * (ps * rs) \<le> (l * 12) * (w * 12)"
proof -
  have good: "0 < rs" "0 < ps" "0 \<le> l" "0 \<le> w"
    using assms by (auto simp: kernel_def split: if_splits)
  have v: "v = of_nat (fit l ps) * of_nat (fit w rs)"
    using assms by (auto simp: kernel_def split: if_splits)
  show ?thesis using good spacing_cells_fit[OF good(2,1,3,4)] v by simp
qed

theorem seeds_needed_declines_iff:
  "kernel (SeedsNeeded gp t) = Decline (Impossible R_germination)
    \<longleftrightarrow> \<not> (0 < gp \<and> gp \<le> 100)"
  by (auto simp: kernel_def)

theorem acre_inch_derived_error:
  assumes "kernel (AcreInch i (Some a)) = Value v" "0 \<le> i * a"
  shows "\<bar>v - i * a * (3630 * (748052 / 100000))\<bar> \<le> i * a / 2"
proof -
  have v: "v = i * a * 27154" using assms(1) by (simp add: kernel_def acre_val_def gal_per_acre_inch_def)
  have e: "v - i * a * (3630 * (748052 / 100000)) = (i * a) * (-719 / 2500)"
    using v by algebra
  show ?thesis unfolding e using assms(2)
    by (simp only: abs_le_iff; intro conjI; linarith)
qed

text \<open>Bags: the number needed covers the volume, and one fewer would not.\<close>
theorem bags_cover:
  assumes "0 < b" and "0 \<le> vol"
  shows "vol / b \<le> of_nat (bags_for vol b) \<and> of_nat (bags_for vol b) < vol / b + 1"
proof -
  let ?y = "vol / b"
  have y0: "0 \<le> ?y" using assms by simp
  let ?z = "floor (- ?y)"
  have fl: "of_int ?z \<le> - ?y \<and> - ?y < of_int ?z + 1"
    using floor_correct [of "- ?y"] by simp
  have z0: "0 \<le> - ?z"
  proof -
    have "(0::rat) \<le> of_int (- ?z)" using fl y0 by simp
    then show ?thesis by simp
  qed
  have n: "(of_nat (bags_for vol b) :: rat) = of_int (- ?z)"
  proof -
    have "int (bags_for vol b) = - ?z" using z0 by (simp add: bags_for_def)
    then have "of_int (int (bags_for vol b)) = (of_int (- ?z) :: rat)" by simp
    then show ?thesis by simp
  qed
  show ?thesis unfolding n using fl by linarith
qed

text \<open>Expected stand, not a guarantee of realized germination. The returned
whole seed count is sufficient and is the least natural count with that expectation.\<close>
theorem seeds_minimum:
  assumes "kernel (SeedsMinimum scope gp t) = Value v"
  shows "0 < gp \<and> gp \<le> 100 \<and> 0 \<le> t \<and>
    (\<exists>n. v = of_nat n \<and> t \<le> v * (gp / 100) \<and>
       (\<forall>m<n. of_nat m * (gp / 100) < t))"
proof -
  have dom: "0 < gp" "gp \<le> 100" "0 \<le> t"
    using assms by (auto simp: kernel_def split: if_splits)
  have v: "v = of_nat (bags_for t (gp / 100))"
    using kernel_value(3)[OF assms] by simp
  let ?p = "gp / 100"
  let ?n = "bags_for t ?p"
  have pp: "0 < ?p" using dom by simp
  have b: "t / ?p \<le> of_nat ?n" "of_nat ?n < t / ?p + 1"
    using bags_cover[OF pp dom(3)] by blast+
  have enough: "t \<le> v * ?p" using b(1) v pp by (simp add: divide_le_eq)
  have least: "of_nat m * ?p < t" if "m < ?n" for m
  proof -
    have "(of_nat m :: rat) + 1 \<le> of_nat ?n" using that by simp
    then have "(of_nat m :: rat) < t / ?p" using b(2) by linarith
    then show ?thesis using pp by (simp add: less_divide_eq)
  qed
  show ?thesis using dom v enough least by blast
qed

theorem seeds_expected:
  assumes "kernel (SeedsExpected scope gp t) = Value v"
  shows "0 < gp \<and> gp \<le> 100 \<and> 0 \<le> t \<and> v * (gp / 100) = t"
proof -
  have dom: "0 < gp" "gp \<le> 100" "0 \<le> t"
    using assms by (auto simp: kernel_def split: if_splits)
  have v: "v = t / (gp / 100)" using kernel_value(3)[OF assms] by simp
  show ?thesis using dom v by simp
qed

theorem seeds_scope_invariant:
  "kernel (SeedsMinimum a gp t) = kernel (SeedsMinimum b gp t)"
  by (simp add: kernel_def)

theorem seeds_unread_declines: "kernel SeedsUnread = Decline Underspecified"
  by (simp add: kernel_def)

theorem garden_bags:
  "kernel (GardenBags sh d b) = Value v \<Longrightarrow> v = of_nat (bags_for (garden_vol sh d) b)"
  by (drule kernel_value(3)) simp

theorem garden_yards:
  "kernel (GardenYards sh d) = Value v \<Longrightarrow> v * 27 = garden_vol sh d"
  by (simp add: kernel_def)

theorem garden_feet:
  "kernel (GardenFeet sh d) = Value v \<Longrightarrow> v = shape_area sh * depth_ft d"
  by (simp add: kernel_def garden_vol_def)

subsection \<open>Nutrition\<close>

theorem bmi_metric:
  assumes "kernel (BmiMetric kg h False) = Value v"
  shows "v * (mheight_m h) ^ 2 = kg"
proof -
  have c: "compute (BmiMetric kg h False) = Value v" using kernel_value(3) [OF assms] .
  have "impossible (BmiMetric kg h False) = None" using kernel_value(2) [OF assms] .
  then have "\<not> mheight_m h \<le> 0" by (auto split: if_splits)
  then have "mheight_m h \<noteq> 0" by simp
  then have h2: "(mheight_m h) ^ 2 \<noteq> 0" by simp
  have veq: "v = kg / (mheight_m h) ^ 2" using c by (simp add: bmi_m_def)
  show ?thesis using veq h2 by (simp add: divide_simps)
qed

theorem bmi_imperial:
  assumes "kernel (BmiImperial lb h False) = Value v"
  shows "v * (iheight_in h) ^ 2 = 703 * lb"
proof -
  have c: "compute (BmiImperial lb h False) = Value v" using kernel_value(3) [OF assms] .
  have "impossible (BmiImperial lb h False) = None" using kernel_value(2) [OF assms] .
  then have "\<not> iheight_in h \<le> 0" by (auto split: if_splits)
  then have "iheight_in h \<noteq> 0" by simp
  then have h2: "(iheight_in h) ^ 2 \<noteq> 0" by simp
  have veq: "v = 703 * lb / (iheight_in h) ^ 2" using c by (simp add: bmi_i_def bmi_imperial_const_def)
  show ?thesis using veq h2 by (simp add: divide_simps)
qed

text \<open>The category question names the CDC category of the BMI the number question states.\<close>
theorem bmi_category_agrees:
  "kernel (BmiMetric kg h True) = Label l \<Longrightarrow> kernel (BmiMetric kg h False) = Value v \<Longrightarrow>
     l = cat_name (bmi_category v)"
  by (auto simp: kernel_def split: if_splits)

theorem bmi_category_agrees_imperial:
  "kernel (BmiImperial lb h True) = Label l \<Longrightarrow> kernel (BmiImperial lb h False) = Value v \<Longrightarrow>
     l = cat_name (bmi_category v)"
  by (auto simp: kernel_def split: if_splits)

theorem kcal_value:
  "kernel (Kcal p c f a) = Value v \<Longrightarrow> 0 \<le> p \<and> 0 \<le> c \<and> 0 \<le> f \<and> 0 \<le> a \<and> v = 4 * p + 4 * c + 9 * f + 7 * a"
  by (auto simp: kernel_def kcal_total_def split: if_splits)


theorem kcal_portion_domain:
  assumes "kernel (KcalPortion p c f a reference target sz) = Value v"
  shows "0 \<le> p \<and> 0 \<le> c \<and> 0 \<le> f \<and> 0 \<le> a \<and>
    0 < portion_qty reference \<and> 0 \<le> portion_qty target \<and>
    portion_size_valid sz \<and> portion_compatible reference target sz"
  using assms by (auto simp: kernel_def split: if_splits)

theorem kcal_portion_conservation:
  assumes "kernel (KcalPortion p c f a reference target sz) = Value v"
  shows "v * portion_weight sz reference = (4*p + 4*c + 9*f + 7*a) * portion_weight sz target"
proof -
  have d: "0 < portion_qty reference" "portion_size_valid sz"
    using kcal_portion_domain[OF assms] by auto
  have pos: "0 < portion_weight sz reference" by (rule portion_weight_positive[OF d])
  have v: "v = kcal_total p c f a * portion_weight sz target / portion_weight sz reference"
    using assms by (auto simp: kernel_def split: if_splits)
  show ?thesis unfolding v using pos by (simp add: kcal_total_def)
qed

theorem kcal_portion_same_extent:
  assumes "0 \<le> p" "0 \<le> c" "0 \<le> f" "0 \<le> a"
      "0 < portion_qty extent" "portion_size_valid sz"
  shows "kernel (KcalPortion p c f a extent extent sz) = kernel (Kcal p c f a)"
proof -
  have pos: "0 < portion_weight sz extent" using assms by (intro portion_weight_positive) auto
  have same: "portion_same_unit extent extent" by (cases extent) simp_all
  show ?thesis using assms pos same by (simp add: kernel_def portion_compatible_def)
qed

theorem kcal_portion_zero_target:
  assumes "0 \<le> p" "0 \<le> c" "0 \<le> f" "0 \<le> a"
      "0 < portion_qty reference" "portion_qty target = 0"
      "portion_size_valid sz" "portion_compatible reference target sz"
  shows "kernel (KcalPortion p c f a reference target sz) = Value 0"
  using assms by (cases target; cases sz) (auto simp: kernel_def)

theorem kcal_portion_missing_dimension:
  "kernel (KcalPortion p c f a (GramPortion r) (ServingPortion t) None) = Decline Underspecified \<and>
   kernel (KcalPortion p c f a (ServingPortion r) (GramPortion t) None) = Decline Underspecified"
  by (simp add: kernel_def portion_compatible_def)

theorem kcal_atwater_unit:
  "kernel (Kcal 1 0 0 0) = Value 4 \<and> kernel (Kcal 0 1 0 0) = Value 4 \<and>
   kernel (Kcal 0 0 1 0) = Value 9 \<and> kernel (Kcal 0 0 0 1) = Value 7"
  by (simp add: kernel_def kcal_total_def)

text \<open>Explicit zero amounts are data, not missing information. The reader
uses NutUnderspecified for absent or ambiguous roles. Unlisted macronutrients
retain the supplied-amount sum convention, with zeros shown in the response.\<close>
theorem kcal_explicit_zero:
  "kernel (Kcal 0 0 0 0) = Value 0"
  by (simp add: kernel_def kcal_total_def)

theorem kcal_nonnegative_domain:
  "kernel (Kcal p c f a) = Decline (Impossible R_nonnegative) \<longleftrightarrow>
    p < 0 \<or> c < 0 \<or> f < 0 \<or> a < 0"
  by (auto simp: kernel_def)

theorem kcal_supplied_sum:
  assumes "kernel (Kcal p c f a) = Value v" "kernel (Kcal p' c' f' a') = Value v'"
  shows "kernel (Kcal (p+p') (c+c') (f+f') (a+a')) = Value (v+v')"
  using kcal_value[OF assms(1)] kcal_value[OF assms(2)]
  by (auto simp: kernel_def kcal_total_def algebra_simps)

theorem pct_fat_cal:
  assumes "kernel (PctFatCal f k) = Value v"
  shows "v * k = 900 * f"
proof -
  have c: "compute (PctFatCal f k) = Value v" using kernel_value(3) [OF assms] .
  have "impossible (PctFatCal f k) = None" using kernel_value(2) [OF assms] .
  then have "\<not> k \<le> 0" by (auto split: if_splits)
  then have k0: "k \<noteq> 0" by simp
  have veq: "v = 9 * f / k * 100" using c by simp
  show ?thesis using veq k0 by (simp add: divide_simps)
qed

theorem pct_dv:
  assumes "kernel (PctDV d a u) = Value v" and "unit_factor u (dv_unit d) = Some f"
  shows "v * dv_amount d = 100 * (a * f)"
proof -
  have "dv_amount d \<noteq> 0" by (cases d) simp_all
  then show ?thesis using kernel_value(3)[OF assms(1)] assms(2) by (simp add: dv_amount_in_def field_simps)
qed

theorem pct_dv_units:
  "unit_factor u (dv_unit d) = None \<Longrightarrow> kernel (PctDV d a u) = Decline (Impossible R_unit_pair)"
  by (simp add: kernel_def)

section \<open>Response text (ASCII)\<close>

text \<open>Digits after the decimal point in the stated value and the reply: counts and whole
numbers none, label arithmetic two, field arithmetic three.\<close>
text \<open>These domain laws concern unrounded supplied quantities. Percent
Daily Value may exceed 100; it is not the same bounded share as fat calories.\<close>
theorem pct_fat_range:
  assumes "kernel (PctFatCal f k) = Value v"
  shows "0 \<le> f \<and> 0 < k \<and> 9*f \<le> k \<and> 0 \<le> v \<and> v \<le> 100"
proof -
  have dom: "0 \<le> f" "0 < k" "9*f \<le> k" using kernel_value(2)[OF assms]
    by (auto split: if_splits)
  have v: "v = 9*f/k*100" using kernel_value(3)[OF assms] by simp
  have lower: "0 \<le> 9*f/k" using dom by (intro divide_nonneg_nonneg; linarith)
  have upper: "9*f/k \<le> 1" using dom by (simp add: divide_le_eq)
  have lo: "0 \<le> v" using v lower by linarith
  have hi: "v \<le> 100" using v upper by linarith
  show ?thesis using dom lo hi by blast
qed

theorem bmi_positive_inputs:
  "kernel (BmiMetric kg h category) = Value v \<or> kernel (BmiMetric kg h category) = Label label \<Longrightarrow> 0 < kg \<and> 0 < mheight_m h"
  by (auto simp: kernel_def split: if_splits)

theorem bmi_imperial_positive_inputs:
  "kernel (BmiImperial lb h category) = Value v \<or> kernel (BmiImperial lb h category) = Label label \<Longrightarrow> 0 < lb \<and> 0 < iheight_in h"
  by (auto simp: kernel_def split: if_splits)

theorem dv_nonnegative_amount:
  "kernel (PctDV d a u) = Value v \<Longrightarrow> 0 \<le> a"
  by (auto simp: kernel_def split: if_splits)

theorem adult_model_declines:
  "kernel NutAdultOnly = Decline Underspecified"
  by (simp add: kernel_def)

fun dp :: "request \<Rightarrow> nat" where
  "dp (Count c) = 0"
| "dp (CountAt c a) = 0"
| "dp (SeedsMinimum scope gp t) = 0"
| "dp (GardenRectGrid l w rs ps) = 0"
| "dp (GardenGrid l w s) = 0"
| "dp (GardenBags sh d b) = 0"
| "dp (BmiMetric kg h c) = 2"
| "dp (BmiImperial lb h c) = 2"
| "dp (Kcal p c f a) = 2"
| "dp (PctFatCal f k) = 2"
| "dp (PctDV d a u) = 2"
| "dp r = 3"

definition grade_lit :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> String.literal" where
  "grade_lit a b c = cat [sn a, STR ''-'', sn b, STR ''-'', sn c]"

definition bmi_note :: "request \<Rightarrow> String.literal" where
  "bmi_note r = (case r of
       BmiMetric kg h c \<Rightarrow> cat [g2 kg, STR '' kg / ('', g2 (mheight_m h), STR '' m)^2'']
     | BmiImperial lb h c \<Rightarrow> cat [STR ''703 x '', g2 lb, STR '' lb / ('', g2 (iheight_in h), STR '' in)^2'']
     | _ \<Rightarrow> STR '''')"

definition bmi_val :: "request \<Rightarrow> rat" where
  "bmi_val r = (case r of BmiMetric kg h c \<Rightarrow> bmi_m kg h | BmiImperial lb h c \<Rightarrow> bmi_i lb h | _ \<Rightarrow> 0)"

fun seed_unit :: "seed_scope \<Rightarrow> String.literal" where
  "seed_unit TotalSeeds = STR '' seeds''"
| "seed_unit PerAcreSeeds = STR '' seeds per acre''"

fun fert_unit :: "fert_context \<Rightarrow> String.literal" where
  "fert_unit TotalFertilizer = STR '' lb''"
| "fert_unit (TotalFromRate a) = STR '' lb''"
| "fert_unit PerAcreFertilizer = STR '' lb per acre''"
| "fert_unit (RateFromTotal a) = STR '' lb per acre''"

text \<open>The reply text of an answered numeric request (organ wording, ASCII: a slash for the
divide sign, x for the multiply sign).\<close>
fun value_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal" where
  "value_text (Count c) v = cat [STR ''There are '', sn (rnd 0 v), STR '' '', count_desc c, STR ''.'']"
| "value_text (CountAt c a) v = cat [STR ''There are '', sn (rnd 0 v), STR '' '', count_desc c, STR ''.'']"
| "value_text (FertProduct n a b c r) v =
     cat [STR ''Apply '', g3 v, STR '' lb of product per acre ('', g3 r, STR '' lb '', nut_name n,
       STR '' / '', sn (grade_pct n a b c), STR ''% '', nut_name n, STR '' in '', grade_lit a b c, STR '').'']"
| "value_text (NutrientLb n a b c q) v =
     cat [STR ''It contains '', g3 v, STR '' lb of '', nut_name n, STR '' ('', g3 q, STR '' lb x '',
       sn (grade_pct n a b c), STR ''%, grade '', grade_lit a b c, STR '').'']"
| "value_text (FertilizerNeed ctx n a b c r) v =
     cat [STR ''The required product is '', g3 v, fert_unit ctx, STR '' (grade '', grade_lit a b c,
       STR ''; '', g3 (fert_amount ctx r), fert_unit ctx, STR '' of '', nut_name n,
       STR '' divided by '', sn (grade_pct n a b c), STR ''%).'']"
| "value_text (FertilizerHas ctx n a b c q) v =
     cat [STR ''It contains '', g3 v, fert_unit ctx, STR '' of '', nut_name n,
       STR '' (grade '', grade_lit a b c, STR ''; '', g3 (fert_amount ctx q), fert_unit ctx,
       STR '' of product times '', sn (grade_pct n a b c), STR ''%).'']"
| "value_text (SeedsPerAcre r s) v =
     cat [STR ''That is '', g3 v, STR '' seeds per acre (6,272,640 sq in / ('', g3 r, STR '' in rows x '',
       g3 s, STR '' in spacing)).'']"
| "value_text (SeedsExpected scope gp t) v =
     cat [STR ''The expected seed requirement is '', g3 v, seed_unit scope,
       STR '' ('', g3 t, STR '' target / '', g3 gp, STR ''% germination). This is an expectation, not a guaranteed stand.'']"
| "value_text (SeedsMinimum scope gp t) v =
     cat [STR ''Plant at least '', sn (rnd 0 v), seed_unit scope,
       STR '' for an expected stand of '', g3 t, STR '' at '', g3 gp,
       STR ''% germination. No smaller whole seed count meets that expectation; actual germination can vary.'']"
| "value_text (SeedsNeeded gp t) v =
     cat [STR ''Plant '', g3 v, STR '' seeds per acre ('', g3 t, STR '' target / '', g3 gp,
       STR ''% germination).'']"
| "value_text (Yield bu c KgHa) v =
     cat [STR ''That is '', g3 v, STR '' kg/ha ('', g3 bu, STR '' bu/ac x '', sn (test_weight c),
       STR '' lb/bu x 1.12085; USDA test weight for '', crop_name c, STR '').'']"
| "value_text (Yield bu c THa) v =
     cat [STR ''That is '', g3 v, STR '' t/ha ('', g3 bu, STR '' bu/ac x '', sn (test_weight c),
       STR '' lb/bu x 1.12085 / 1000; USDA test weight for '', crop_name c, STR '').'']"
| "value_text (AcreInch i None) v =
     cat [STR ''That is '', g3 v, STR '' gallons ('', g3 i, STR '' acre-inches x 27,154 gal).'']"
| "value_text (AcreInch i (Some a)) v =
     cat [STR ''That is '', g3 v, STR '' gallons ('', g3 (i * a), STR '' acre-inches x 27,154 gal).'']"
| "value_text (GardenWater sh i) v =
     cat [STR ''That is '', g3 v, STR '' gallons ('', g3 (shape_area sh), STR '' sq ft x '', g3 i,
       STR '' in x 0.623 gal per sq ft-inch).'']"
| "value_text (GardenFert rate sh) v =
     cat [STR ''Apply '', g3 v, STR '' lb ('', g3 rate, STR '' lb per 1,000 sq ft x '', g3 (shape_area sh),
       STR '' sq ft / 1,000).'']"
| "value_text (GardenRectGrid l w rs ps) v =
     cat [STR ''That is '', sn (rnd 0 v), STR '' plants ('', sn (fit w rs), STR '' rows across the '',
       g3 w, STR '' ft width, '', sn (fit l ps), STR '' plants along each '', g3 l,
       STR '' ft row; '', g3 rs, STR '' in between rows and '', g3 ps,
       STR '' in between plants, one spacing cell per plant).'']"
| "value_text (GardenGrid l w s) v =
     cat [STR ''That is '', sn (rnd 0 v), STR '' plants (square grid: '', sn (fit l s), STR '' x '',
       sn (fit w s), STR '' at '', g3 s, STR '' in spacing in a '', g3 l, STR '' x '', g3 w, STR '' ft bed).'']"
| "value_text (GardenBags sh d b) v =
     cat [STR ''You need '', sn (rnd 0 v), STR '' bags ('', g3 (garden_vol sh d), STR '' cu ft / '', g3 b,
       STR '' cu ft per bag, rounded up; no settling allowance).'']"
| "value_text (GardenYards sh d) v =
     cat [STR ''That is '', g3 v, STR '' cubic yards ('', g3 (garden_vol sh d),
       STR '' cu ft / 27; no settling allowance).'']"
| "value_text (GardenFeet sh d) v =
     cat [STR ''That is '', g3 v, STR '' cubic feet ('', g3 (garden_vol sh d), STR '' = '',
       (case sh of Dims l w \<Rightarrow> cat [g3 l, STR '' x '', g3 w] | Area a \<Rightarrow> cat [g3 a, STR '' x 1'']),
       STR '' ft x '', g3 (depth_ft d), STR '' ft deep; no settling allowance).'']"
| "value_text (BmiMetric kg h c) v =
     cat [STR ''The BMI is '', g2 v, STR '' ('', bmi_note (BmiMetric kg h c), STR ''; CDC adult category: '',
       cat_name (bmi_category v), STR '' - a screening measure, not a diagnosis).'']"
| "value_text (BmiImperial lb h c) v =
     cat [STR ''The BMI is '', g2 v, STR '' ('', bmi_note (BmiImperial lb h c), STR ''; CDC adult category: '',
       cat_name (bmi_category v), STR '' - a screening measure, not a diagnosis).'']"
| "value_text (KcalPortion p c f a reference target sz) v =
     cat [STR ''The total is '', g2 v, STR '' kcal for '', portion_text target,
       STR '' (Atwater energy '', g2 (kcal_total p c f a), STR '' kcal per '', portion_text reference,
       (case sz of None \<Rightarrow> STR '''' | Some q \<Rightarrow> STR ''; serving size '' + g3 q + STR '' g''), STR '').'']"
| "value_text (Kcal p c f a) v =
     cat [STR ''The total is '', g2 v, STR '' kcal (4 x '', g2 p, STR '' g protein + 4 x '', g2 c,
       STR '' g carbohydrate + 9 x '', g2 f, STR '' g fat'',
       (if a \<noteq> 0 then cat [STR '' + 7 x '', g2 a, STR '' g alcohol''] else STR ''''), STR '').'']"
| "value_text (PctFatCal f k) v =
     cat [STR ''The share of calories from fat is '', g2 v, STR ''% (9 x '', g2 f, STR '' g / '', g2 k,
       STR '' kcal).'']"
| "value_text (PctDV d a u) v =
     cat [STR ''That is '', g2 v, STR ''% of the Daily Value ('', g2 (dv_amount_in d a u), STR '' '',
       unit_label (dv_unit d), STR '' / '', g2 (dv_amount d), STR '' '', unit_label (dv_unit d),
       STR '' DV for '', dv_name d, STR ''; FDA 2020 label, adults).'']"
| "value_text r v = STR ''''"

fun label_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "label_text (Superlative s) l = cat [STR ''It is the '', l, STR '' ('', super_note s, STR '').'']"
| "label_text (Produces m) l = cat [STR ''It is the '', l, STR ''.'']"
| "label_text (BmiMetric kg h c) l =
     cat [STR ''The BMI category is '', l, STR '' (BMI '', g2 (bmi_val (BmiMetric kg h c)), STR '' = '',
       bmi_note (BmiMetric kg h c), STR ''; CDC adult screening categories, not a diagnosis).'']"
| "label_text (BmiImperial lb h c) l =
     cat [STR ''The BMI category is '', l, STR '' (BMI '', g2 (bmi_val (BmiImperial lb h c)), STR '' = '',
       bmi_note (BmiImperial lb h c), STR ''; CDC adult screening categories, not a diagnosis).'']"
| "label_text r l = l"

text \<open>Reason-first presentation avoids expanding every request/reason pair.\<close>
definition decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r d = (case d of
    Impossible w \<Rightarrow>
      (if w = R_fertilizer then
        STR ''Amounts and total area must be nonnegative; dividing by area requires a positive area. Grade percentages must be between zero and 100.''
       else if w = R_nutrition_domain then
        STR ''Nutrient amounts must be nonnegative; under this unrounded calorie model, energy from fat cannot exceed total energy.''
       else if w = R_nonnegative then
        STR ''Macronutrient amounts cannot be negative; explicit zero amounts are allowed.''
       else case r of
         FertProduct n a b c x \<Rightarrow>
           cat [STR ''A '', grade_lit a b c, STR '' fertilizer contains no '', nut_name n,
             STR '', so no amount of it supplies that nutrient.'']
       | FertilizerNeed ctx n a b c x \<Rightarrow> STR ''This grade has none of the requested nutrient column.''
       | SeedsNeeded gp t \<Rightarrow> STR ''The target stand must be nonnegative and germination must be greater than zero and at most 100%.''
       | SeedsMinimum scope gp t \<Rightarrow> STR ''The target stand must be nonnegative and germination must be greater than zero and at most 100%.''
       | SeedsExpected scope gp t \<Rightarrow> STR ''The target stand must be nonnegative and germination must be greater than zero and at most 100%.''
       | PctDV dv x u \<Rightarrow>
           cat [STR ''I cannot convert '', unit_label u, STR '' to '', unit_label (dv_unit dv), STR '' for '', dv_name dv, STR '' here.'']
       | _ \<Rightarrow> STR ''The inputs must be positive.'')
  | Underspecified \<Rightarrow> (case r of
      SeedsUnread \<Rightarrow> STR ''Supply one complete germination percentage and target stand, with a clear total or per-acre scope; I will not guess malformed or conflicting quantities.''
    | CountAt c age \<Rightarrow> STR ''This table has no supported count for that developmental stage; I will not substitute a fully developed skeleton or dentition count.''
    | GardenNeedOrientation \<Rightarrow> STR ''Specify both spacings and which bed side the rows run along; I will not assume a planting orientation.''
    | FertUnread \<Rightarrow> STR ''Supply one complete N-P2O5-K2O grade and one nutrient or product amount, with total/per-acre scope and area when conversion is requested. Elemental phosphorus/potassium requires a separate conversion model.''
    | AgriUnderspecified \<Rightarrow> STR ''I need the amount of product (lb) or the target nutrient rate (lb per acre) to work that out; I will not assume it.''
    | NutAdultOnly \<Rightarrow> STR ''This BMI response includes an adult category for ages 20 and older. Child and teen categories require age-specific data not supplied by this table.''
    | KcalPortion p c f a reference target sz \<Rightarrow> STR ''A conversion between grams and serving counts needs a stated positive serving mass. Supply the label reference portion and requested portion.''
    | NutUnderspecified \<Rightarrow> STR ''I could not read every amount I need from that; give the grams, calories, weight or height with units and I will work it out.''
    | Kcal p c f a \<Rightarrow> STR ''I could not read every amount I need from that; give the grams, calories, weight or height with units and I will work it out.''
    | _ \<Rightarrow> STR ''I need more information to answer that.''))"

fun kind_name :: "request \<Rightarrow> String.literal" where
  "kind_name (Count c) = STR ''count''"
| "kind_name (CountAt c a) = STR ''count''"
| "kind_name (Superlative s) = STR ''superlative''"
| "kind_name (Produces m) = STR ''produces''"
| "kind_name (FertProduct n a b c r) = STR ''fert_product''"
| "kind_name (NutrientLb n a b c q) = STR ''nutrient_lb''"
| "kind_name (FertilizerNeed ctx n a b c r) = STR ''fert_product''"
| "kind_name (FertilizerHas ctx n a b c q) = STR ''nutrient_lb''"
| "kind_name FertUnread = STR ''underspecified''"
| "kind_name (SeedsPerAcre r s) = STR ''seeds_per_acre''"
| "kind_name (SeedsNeeded gp t) = STR ''seeds_needed''"
| "kind_name (SeedsExpected scope gp t) = STR ''seeds_expected''"
| "kind_name (SeedsMinimum scope gp t) = STR ''seeds_minimum''"
| "kind_name (Yield bu c KgHa) = STR ''yield_kgha''"
| "kind_name (Yield bu c THa) = STR ''yield_tha''"
| "kind_name (AcreInch i a) = STR ''acre_inch''"
| "kind_name GardenNeedOrientation = STR ''underspecified''"
| "kind_name AgriUnderspecified = STR ''underspecified''"
| "kind_name (GardenWater sh i) = STR ''water_gal''"
| "kind_name (GardenFert rate sh) = STR ''fert_area''"
| "kind_name (GardenRectGrid l w rs ps) = STR ''plants_grid''"
| "kind_name (GardenGrid l w s) = STR ''plants_grid''"
| "kind_name (GardenBags sh d b) = STR ''bags''"
| "kind_name (GardenYards sh d) = STR ''cubic_yards''"
| "kind_name (GardenFeet sh d) = STR ''cubic_feet''"
| "kind_name (BmiMetric kg h c) = (if c then STR ''bmi_category'' else STR ''bmi'')"
| "kind_name (BmiImperial lb h c) = (if c then STR ''bmi_category'' else STR ''bmi'')"
| "kind_name (KcalPortion p c f a reference target sz) = STR ''kcal_macros''"
| "kind_name (Kcal p c f a) = STR ''kcal_macros''"
| "kind_name (PctFatCal f k) = STR ''pct_fat_cal''"
| "kind_name (PctDV d a u) = STR ''pct_dv''"
| "kind_name SeedsUnread = STR ''underspecified''"
| "kind_name NutUnderspecified = STR ''underspecified''"
| "kind_name NutAdultOnly = STR ''underspecified''"

definition decline_kind :: "decline \<Rightarrow> String.literal" where
  "decline_kind w = (case w of Underspecified \<Rightarrow> STR ''underspecified'' | Impossible x \<Rightarrow> STR ''impossible'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and the stated
value (already JSON: a number, or a quoted name).\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Value v \<Rightarrow>
       (if 0 \<le> v
        then Reply True (kind_name r) (value_text r v) (Some (fixed_lit (dp r) (rnd (dp r) v)))
        else Reply False (STR ''imprecise'') (STR ''The result is negative.'') None)
   | Label l \<Rightarrow> Reply True (kind_name r) (label_text r l) (Some (dq + l + dq))
   | Decline w \<Rightarrow> Reply False (decline_kind w) (decline_text r w) None)"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow> (\<exists>v. kernel r = Value v \<and> 0 \<le> v) \<or> (\<exists>l. kernel r = Label l)"
  by (cases "kernel r") (auto simp: reply_of_def)

text \<open>A stated number is the kernel's value rounded to the reply's decimals, within half a unit
in the last place.\<close>
theorem reply_states_value:
  assumes "kernel r = Value v" and "0 \<le> v"
  shows "\<exists>n. stated (reply_of r) = Some (fixed_lit (dp r) n) \<and>
             \<bar>of_nat n - v * 10 ^ dp r\<bar> \<le> 1 / 2"
  using assms rnd_sound [OF assms(2), of "dp r"] by (auto simp: reply_of_def)

theorem reply_states_label:
  "kernel r = Label l \<Longrightarrow> stated (reply_of r) = Some (dq + l + dq)"
  by (simp add: reply_of_def)

text \<open>Counts are stated exactly.\<close>
theorem count_stated_exact:
  "stated (reply_of (Count c)) = Some (fixed_lit 0 (count_val c))"
  by (simp add: reply_of_def kernel_def rnd_nat)

text \<open>A withheld reply names the kernel's decline.\<close>
theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_kind w"
  by (simp add: reply_of_def)

definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

end
