theory Finite_Plans
  imports Finite_Probability "Veri7vn_Plans.Veri7vn_Plans"
begin

datatype finite_carrier = RationalCarrier | RationalCollectionCarrier | NaturalCarrier
datatype finite_value = RationalValue rat | RationalCollection "rat list" | NaturalValue nat
datatype finite_operation = Mean | Median | Modes | Range | Centered | ZScore | Variance variance_convention
  | Choose nat nat | Permutations nat nat | Binomial nat nat rat
  | DieAtLeastOne nat nat nat | DiceTotal nat nat nat | DrawAll bool nat nat nat
  | PopulationEvent population_extent "rat list"
  | WeightedEvent population_extent "(rat \<times> rat) list" "rat list"
  | LocusCross "char \<times> char" "char \<times> char" char
  | HardyWeinberg rat
fun finite_type where
  "finite_type (RationalValue x) = RationalCarrier"
| "finite_type (RationalCollection xs) = RationalCollectionCarrier"
| "finite_type (NaturalValue n) = NaturalCarrier"
fun finite_arguments where
  "finite_arguments Mean = [RationalCollectionCarrier]"
| "finite_arguments Centered = [RationalCollectionCarrier]"
| "finite_arguments ZScore = [RationalCarrier,RationalCarrier,RationalCarrier]"
| "finite_arguments Median = [RationalCollectionCarrier]"
| "finite_arguments Modes = [RationalCollectionCarrier]"
| "finite_arguments Range = [RationalCollectionCarrier]"
| "finite_arguments (Variance c) = [RationalCollectionCarrier]"
| "finite_arguments (PopulationEvent e event) = [RationalCollectionCarrier]"
| "finite_arguments _ = []"
fun finite_result where
  "finite_result Modes = RationalCollectionCarrier"
| "finite_result Centered = RationalCollectionCarrier"
| "finite_result (HardyWeinberg q) = RationalCollectionCarrier"
| "finite_result (Choose n k) = NaturalCarrier"
| "finite_result (Permutations n k) = NaturalCarrier"
| "finite_result _ = RationalCarrier"
fun finite_dispatch :: "finite_operation \<Rightarrow> finite_value list \<Rightarrow> finite_value option" where
  "finite_dispatch Mean [RationalCollection xs] = map_option RationalValue (exact_mean xs)"
| "finite_dispatch Centered [RationalCollection xs] = map_option RationalCollection (exact_centered xs)"
| "finite_dispatch ZScore [RationalValue x,RationalValue mean,RationalValue sd] = map_option RationalValue (exact_zscore x mean sd)"
| "finite_dispatch Median [RationalCollection xs] = map_option RationalValue (exact_median xs)"
| "finite_dispatch Modes [RationalCollection xs] = Some (RationalCollection (exact_modes xs))"
| "finite_dispatch Range [RationalCollection xs] = map_option RationalValue (exact_range xs)"
| "finite_dispatch (Variance c) [RationalCollection xs] = map_option RationalValue (exact_variance c xs)"
| "finite_dispatch (Choose n k) [] = map_option NaturalValue (exact_choose n k)"
| "finite_dispatch (Permutations n k) [] = map_option NaturalValue (exact_permutations n k)"
| "finite_dispatch (Binomial n k p) [] = map_option RationalValue (binomial_probability n k p)"
| "finite_dispatch (DieAtLeastOne sides trials face) [] = map_option RationalValue (die_at_least_one sides trials face)"
| "finite_dispatch (DiceTotal sides dice total_count) [] = map_option RationalValue (dice_total_probability sides dice total_count)"
| "finite_dispatch (DrawAll replacement good total_count draws) [] = map_option RationalValue (all_success_draws replacement good total_count draws)"
| "finite_dispatch (PopulationEvent extent event) [RationalCollection xs] =
    map_option RationalValue (finite_probability extent xs (\<lambda>x. x \<in> set event))"
| "finite_dispatch (WeightedEvent extent weights event) [] =
    map_option RationalValue (weighted_probability extent weights (\<lambda>x. x \<in> set event))"
| "finite_dispatch (LocusCross a b recessive) [] =
    map_option RationalValue (cross_probability a b (\<lambda>(x,y). x=recessive \<and> y=recessive))"
| "finite_dispatch (HardyWeinberg q) [] =
    map_option (\<lambda>(a,b,c). RationalCollection [a,b,c]) (hardy_weinberg q)"
| "finite_dispatch _ _ = None"
text \<open>The relation is consumed separately from the executable option
interpreter. Collection results preserve all maximizing observations.\<close>
fun finite_meaning :: "finite_operation \<Rightarrow> finite_value list \<Rightarrow> finite_value \<Rightarrow> bool" where
  "finite_meaning Mean [RationalCollection xs] (RationalValue y) =
    (xs \<noteq> [] \<and> y = sum_list xs / of_nat (length xs))"
| "finite_meaning Centered [RationalCollection xs] (RationalCollection ys) =
    (xs \<noteq> [] \<and> ys = map (\<lambda>x. x - sum_list xs / of_nat (length xs)) xs)"
| "finite_meaning ZScore [RationalValue x,RationalValue mean,RationalValue sd] (RationalValue y) =
    (sd > 0 \<and> y=(x-mean)/sd)"
| "finite_meaning Median [RationalCollection xs] (RationalValue y) = (exact_median xs = Some y)"
| "finite_meaning Modes [RationalCollection xs] (RationalCollection ys) = (ys = exact_modes xs)"
| "finite_meaning Range [RationalCollection xs] (RationalValue y) = (exact_range xs = Some y)"
| "finite_meaning (Variance c) [RationalCollection xs] (RationalValue y) = (variance_denominator c (length xs) > 0 \<and>
      y = sum_list (map (\<lambda>x. (x - sum_list xs / of_nat (length xs))^2) xs) /
        of_nat (variance_denominator c (length xs)))"
| "finite_meaning (Choose n k) [] (NaturalValue y) = (k \<le> n \<and> y = n choose k)"
| "finite_meaning (Permutations n k) [] (NaturalValue y) = (k \<le> n \<and> y = prod_list [n-k+1..<Suc n])"
| "finite_meaning (Binomial n k p) [] (RationalValue y) = (0 \<le> p \<and> p \<le> 1 \<and>
      y = (if k > n then 0 else of_nat (n choose k) * p^k * (1-p)^(n-k)))"
| "finite_meaning (DieAtLeastOne sides trials face) [] (RationalValue y) = (sides > 0 \<and> y = (if face = 0 \<or> face > sides then 0 else
      1 - (1 - 1 / of_nat sides)^trials))"
| "finite_meaning (DiceTotal sides dice total_count) [] (RationalValue y) =
    (sides > 0 \<and> y = of_nat (length (filter (\<lambda>xs. sum_list xs=total_count) (fair_rolls dice sides))) /
       of_nat (sides^dice))"
| "finite_meaning (DrawAll r good total_count draws) [] (RationalValue y) = (total_count > 0 \<and> good \<le> total_count \<and> (r \<or> draws \<le> total_count) \<and>
      y = (if r then (of_nat good / of_nat total_count)^draws else without_replacement good total_count draws))"
| "finite_meaning (PopulationEvent extent event) [RationalCollection xs] (RationalValue y) =
    (extent = CompletePopulation \<and> xs \<noteq> [] \<and>
      y = of_nat (length (filter (\<lambda>x. x \<in> set event) xs)) / of_nat (length xs))"
| "finite_meaning (WeightedEvent extent weights event) [] (RationalValue y) =
    (extent = CompletePopulation \<and> list_all (\<lambda>x. 0 \<le> snd x) weights \<and>
      0 < sum_list (map snd weights) \<and>
      y = sum_list (map (\<lambda>x. if fst x \<in> set event then snd x else 0) weights) /
        sum_list (map snd weights))"
| "finite_meaning (LocusCross a b recessive) [] (RationalValue y) =
    (cross_probability a b (\<lambda>(x,y). x=recessive \<and> y=recessive) = Some y)"
| "finite_meaning (HardyWeinberg q) [] (RationalCollection ys) =
    (\<exists>a b c. hardy_weinberg q = Some (a,b,c) \<and> ys=[a,b,c])"
| "finite_meaning _ _ _ = False"
lemma finite_dispatch_refinement:
  "finite_dispatch op xs = Some y \<longleftrightarrow> finite_meaning op xs y"
  by (induction op xs rule: finite_dispatch.induct)
    (auto simp: exact_mean_def exact_centered_def exact_zscore_def exact_choose_def exact_permutations_def
      finite_probability_def exact_variance_def binomial_probability_def die_at_least_one_def
      all_success_draws_def weighted_probability_def dice_total_probability_def fair_rolls_mass
      dice_total_model_complete Let_def split: finite_value.splits option.splits prod.splits if_splits)

lemma finite_dispatch_output_type:
  "finite_dispatch op xs = Some y \<Longrightarrow> finite_type y = finite_result op"
  by (induction op xs rule: finite_dispatch.induct) (auto split: option.splits prod.splits)
lemma finite_dispatch_input_types:
  "finite_dispatch op xs = Some y \<Longrightarrow> map finite_type xs = finite_arguments op"
  by (induction op xs rule: finite_dispatch.induct) (auto split: option.splits prod.splits)
fun finite_incomplete :: "finite_operation \<Rightarrow> finite_value list \<Rightarrow> bool" where
  "finite_incomplete (PopulationEvent PartialPopulation event) [RationalCollection xs] = True"
| "finite_incomplete (WeightedEvent PartialPopulation weights event) [] = True"
| "finite_incomplete _ _ = False"
lemma incomplete_has_no_probability:
  "finite_incomplete op xs \<Longrightarrow> finite_dispatch op xs = None"
  by (induction op xs rule: finite_incomplete.induct) simp_all
fun finite_guard :: "unit \<Rightarrow> finite_operation \<Rightarrow> finite_value list \<Rightarrow> guard_verdict" where
  "finite_guard _ op xs = (if finite_incomplete op xs then GuardUnresolved 703 else GuardEstablished)"
definition finite_primitive :: "unit \<Rightarrow> finite_operation \<Rightarrow> finite_value list \<Rightarrow> (finite_value,unit) primitive_result" where
  "finite_primitive context op xs = (case finite_dispatch op xs of None \<Rightarrow> PrimitiveFailure 701 | Some v \<Rightarrow> Computed v)"
global_interpretation finite_plans: typed_plan_bundle finite_type finite_arguments finite_result finite_guard finite_primitive 702
  defines finite_elaborate = finite_plans.elaborate_plan
    and finite_check_primitive = finite_plans.check_primitive
    and finite_execute_node = finite_plans.execute_node
    and finite_execute_plan = finite_plans.execute_plan
    and finite_run_checked = finite_plans.run_checked .

datatype finite_call = FiniteCall finite_operation "finite_value list" "nat list"
datatype finite_reply = FiniteAnswer finite_value "nat list" | FiniteRejected | FiniteIncomplete
fun registered_finite_dispatch where
  "registered_finite_dispatch (FiniteCall op inputs conditions) =
    (if finite_incomplete op inputs then FiniteIncomplete else case finite_dispatch op inputs of None \<Rightarrow> FiniteRejected
      | Some v \<Rightarrow> FiniteAnswer v (merge_conditions conditions))"
fun finite_call_meaning where
  "finite_call_meaning (FiniteCall op inputs conditions) (FiniteAnswer value retained) =
    (\<not> finite_incomplete op inputs \<and> finite_meaning op inputs value \<and> retained = merge_conditions conditions)"
| "finite_call_meaning (FiniteCall op inputs conditions) FiniteRejected =
    (\<not> finite_incomplete op inputs \<and> \<not> (\<exists>value. finite_meaning op inputs value))"
| "finite_call_meaning (FiniteCall op inputs conditions) FiniteIncomplete = finite_incomplete op inputs"
lemma finite_execution_refinement:
  "finite_call_meaning call (registered_finite_dispatch call)"
  by (cases call) (auto simp: finite_dispatch_refinement[symmetric] split: option.splits if_splits)
lemma finite_reply_conditions:
  "registered_finite_dispatch (FiniteCall op inputs conditions) = FiniteAnswer value retained
   \<Longrightarrow> set conditions \<subseteq> set retained"
  by (auto split: option.splits prod.splits if_splits)

export_code registered_finite_dispatch finite_run_checked in SML module_name Veri7vn_Finite_Plans
end
