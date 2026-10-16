theory Finite_Probability
  imports "Veri7vn_Codegen.Veri7vn_Codegen" "HOL.Rat"
begin

text \<open>Lists are multisets of observations, not sets: repeated outcomes carry
mass. Complete means a caller-supplied closed finite model, never a claim that
an observed source enumerates the world. Partial populations cannot license a
normalized probability. All arithmetic uses the shared native rational carrier.\<close>
datatype population_extent = CompletePopulation | PartialPopulation

definition finite_probability :: "population_extent \<Rightarrow> 'a list \<Rightarrow> ('a \<Rightarrow> bool) \<Rightarrow> rat option" where
  "finite_probability extent xs event =
    (if extent = CompletePopulation \<and> xs \<noteq> [] then
      Some (of_nat (length (filter event xs)) / of_nat (length xs)) else None)"
lemma partial_population_refused [simp]:
  "finite_probability PartialPopulation xs event = None"
  by (simp add: finite_probability_def)
lemma finite_probability_characterization:
  "finite_probability extent xs event = Some p \<longleftrightarrow>
    extent = CompletePopulation \<and> xs \<noteq> [] \<and>
    p = of_nat (length (filter event xs)) / of_nat (length xs)"
  by (auto simp: finite_probability_def split: if_splits)
lemma impossible_event_zero:
  assumes "xs \<noteq> []" "\<And>x. x \<in> set xs \<Longrightarrow> \<not> event x"
  shows "finite_probability CompletePopulation xs event = Some 0"
  using assms by (simp add: finite_probability_def filter_empty_conv)

lemma finite_probability_bounds:
  assumes "finite_probability extent xs event = Some p"
  shows "0 \<le> p \<and> p \<le> 1"
proof -
  from assms have nonempty: "xs \<noteq> []" and value:
    "p = of_nat (length (filter event xs)) / of_nat (length xs)"
    by (auto simp: finite_probability_characterization)
  have positive: "(0::rat) < of_nat (length xs)" using nonempty by simp
  have bounded: "(of_nat (length (filter event xs))::rat) \<le> of_nat (length xs)"
    by (simp add: length_filter_le)
  show ?thesis using positive bounded by (simp add: value divide_le_eq)
qed

definition weighted_probability :: "population_extent \<Rightarrow> ('a \<times> rat) list \<Rightarrow> ('a \<Rightarrow> bool) \<Rightarrow> rat option" where
  "weighted_probability extent xs event =
    (let total_count = sum_list (map snd xs) in
      if extent = CompletePopulation \<and> list_all (\<lambda>x. 0 \<le> snd x) xs \<and> 0 < total_count
      then Some (sum_list (map (\<lambda>x. if event (fst x) then snd x else 0) xs) / total_count)
      else None)"
lemma partial_weights_refused [simp]:
  "weighted_probability PartialPopulation xs event = None"
  by (simp add: weighted_probability_def Let_def)

lemma uniform_model_normalized:
  "xs \<noteq> [] \<Longrightarrow> finite_probability CompletePopulation xs (\<lambda>_. True) = Some 1"
  by (simp add: finite_probability_def)
lemma weighted_model_normalized:
  assumes "list_all (\<lambda>x. 0 \<le> snd x) xs" "0 < sum_list (map snd xs)"
  shows "weighted_probability CompletePopulation xs (\<lambda>_. True) = Some 1"
  using assms by (simp add: weighted_probability_def Let_def)

definition exact_mean :: "rat list \<Rightarrow> rat option" where
  "exact_mean xs = (if xs = [] then None else Some (sum_list xs / of_nat (length xs)))"
definition exact_centered :: "rat list \<Rightarrow> rat list option" where
  "exact_centered xs = map_option (\<lambda>mean. map (\<lambda>x. x-mean) xs) (exact_mean xs)"
definition exact_zscore :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat option" where
  "exact_zscore x mean sd = (if sd > 0 then Some ((x-mean)/sd) else None)"
lemma zscore_positive_scale:
  "exact_zscore x mean sd = Some y \<Longrightarrow> sd > 0 \<and> y*sd=x-mean"
  by (auto simp: exact_zscore_def split: if_splits)

datatype variance_convention = PopulationVariance | SampleVariance
fun variance_denominator where
  "variance_denominator PopulationVariance n = n"
| "variance_denominator SampleVariance n = n - 1"
definition exact_variance :: "variance_convention \<Rightarrow> rat list \<Rightarrow> rat option" where
  "exact_variance convention xs =
    (let n = variance_denominator convention (length xs) in
      if n = 0 then None else
      Some (sum_list (map (\<lambda>x. (x - sum_list xs / of_nat (length xs))^2) xs) / of_nat n))"
definition exact_modes :: "rat list \<Rightarrow> rat list" where
  "exact_modes xs = filter (\<lambda>x. list_all (\<lambda>y. count_list xs y \<le> count_list xs x) xs) (remdups xs)"
lemma mode_membership:
  "x \<in> set (exact_modes xs) \<longleftrightarrow>
    x \<in> set xs \<and> (\<forall>y\<in>set xs. count_list xs y \<le> count_list xs x)"
  by (simp add: exact_modes_def list_all_iff)
definition exact_median :: "rat list \<Rightarrow> rat option" where
  "exact_median xs = (if xs = [] then None else
    let ys = sort xs; n = length xs in
    Some (if odd n then ys ! (n div 2)
      else (ys ! (n div 2 - 1) + ys ! (n div 2))/2))"
definition exact_range :: "rat list \<Rightarrow> rat option" where
  "exact_range xs = (if xs = [] then None else Some (last (sort xs) - hd (sort xs)))"

text \<open>Named n/k are never exchanged. Invalid selection models are rejected;
zero mass for k above n is reserved for the valid binomial model.\<close>
definition exact_choose :: "nat \<Rightarrow> nat \<Rightarrow> nat option" where
  "exact_choose n k = (if k \<le> n then Some (n choose k) else None)"
definition exact_permutations :: "nat \<Rightarrow> nat \<Rightarrow> nat option" where
  "exact_permutations n k = (if k \<le> n then Some (prod_list [n-k+1..<Suc n]) else None)"
definition binomial_probability :: "nat \<Rightarrow> nat \<Rightarrow> rat \<Rightarrow> rat option" where
  "binomial_probability n k p = (if 0 \<le> p \<and> p \<le> 1 then
    Some (if k > n then 0 else of_nat (n choose k) * p^k * (1-p)^(n-k)) else None)"
definition die_at_least_one :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> rat option" where
  "die_at_least_one sides trials face = (if sides = 0 then None else
    Some (if face = 0 \<or> face > sides then 0 else 1 - (1 - 1 / of_nat sides)^trials))"
lemma impossible_die_face:
  "0 < sides \<Longrightarrow> face > sides \<Longrightarrow> die_at_least_one sides trials face = Some 0"
  by (simp add: die_at_least_one_def)
fun fair_rolls :: "nat \<Rightarrow> nat \<Rightarrow> nat list list" where
  "fair_rolls 0 sides = [[]]"
| "fair_rolls (Suc n) sides = map (\<lambda>(face,rest). face#rest)
    (List.product [1..<Suc sides] (fair_rolls n sides))"
lemma fair_rolls_mass:
  "length (fair_rolls n sides) = sides^n"
  by (induction n) (simp_all add: power_Suc mult.commute)
definition dice_total_probability :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> rat option" where
  "dice_total_probability sides dice total_count = (if sides=0 then None else
    finite_probability CompletePopulation (fair_rolls dice sides) (\<lambda>xs. sum_list xs=total_count))"
lemma dice_total_model_complete:
  "sides > 0 \<Longrightarrow> fair_rolls dice sides \<noteq> []"
  using fair_rolls_mass[of dice sides] by auto

fun without_replacement :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> rat" where
  "without_replacement good total_count 0 = 1"
| "without_replacement good total_count (Suc n) =
    (if good = 0 \<or> total_count = 0 then 0 else
      of_nat good / of_nat total_count * without_replacement (good-1) (total_count-1) n)"
definition all_success_draws :: "bool \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> rat option" where
  "all_success_draws replacement good total_count draws =
    (if total_count = 0 \<or> good > total_count \<or> (\<not> replacement \<and> draws > total_count) then None
    else Some (if replacement then (of_nat good / of_nat total_count)^draws
      else without_replacement good total_count draws))"

text \<open>A locus carries its case-sensitive source symbol explicitly. The
finite cross preserves both alleles; uppercase normalization is not a genotype
operation. Independent uniform gamete selection is the model assumption.\<close>
definition locus_cross :: "'a \<times> 'a \<Rightarrow> 'a \<times> 'a \<Rightarrow> ('a \<times> 'a) list" where
  "locus_cross a b = [(fst a,fst b),(fst a,snd b),(snd a,fst b),(snd a,snd b)]"
definition cross_probability :: "'a \<times> 'a \<Rightarrow> 'a \<times> 'a \<Rightarrow> (('a \<times> 'a) \<Rightarrow> bool) \<Rightarrow> rat option" where
  "cross_probability a b event = finite_probability CompletePopulation (locus_cross a b) event"
lemma cross_has_four_outcomes: "length (locus_cross a b) = 4"
  by (simp add: locus_cross_def)
definition hardy_weinberg :: "rat \<Rightarrow> (rat \<times> rat \<times> rat) option" where
  "hardy_weinberg q = (if 0 \<le> q \<and> q \<le> 1 then Some ((1-q)^2,2*(1-q)*q,q^2) else None)"
lemma hardy_weinberg_normalized:
  "(1-q)^2 + 2*(1-q)*q + (q::rat)^2 = 1"
  by (simp add: power2_eq_square algebra_simps)

export_code finite_probability weighted_probability exact_mean exact_variance
  exact_modes exact_median exact_range exact_centered exact_zscore exact_choose exact_permutations
  binomial_probability die_at_least_one fair_rolls dice_total_probability all_success_draws cross_probability
  hardy_weinberg in SML module_name Veri7vn_Finite
end
