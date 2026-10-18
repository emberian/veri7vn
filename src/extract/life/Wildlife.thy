theory Wildlife
  imports Life_Core
begin

text \<open>
  Lane S09-life, wildlife (upstream/root/specialists/wildlife/organ_wildlife_v1.py):
  mark-recapture population estimates (Lincoln-Petersen, Chapman), density,
  survival and mortality, all exact rationals. A recognised mark-recapture
  question with a missing count declines as underspecified, naming exactly
  what is missing.
\<close>

datatype warea = Hectare | Acre | SquareKm | SquareMile
fun w_square_metres :: "warea \<Rightarrow> rat" where
  "w_square_metres Hectare = 10000"
| "w_square_metres Acre = 40468564224 / 10000000"
| "w_square_metres SquareKm = 1000000"
| "w_square_metres SquareMile = 2589988110336 / 1000000"
fun w_area_name :: "warea \<Rightarrow> String.literal" where
  "w_area_name Hectare = STR ''hectare''"
| "w_area_name Acre = STR ''acre''"
| "w_area_name SquareKm = STR ''square kilometer''"
| "w_area_name SquareMile = STR ''square mile''"
lemma w_area_positive [simp]: "0 < w_square_metres u"
  by (cases u) simp_all

lemma w_area_nonzero [simp]: "w_square_metres u \<noteq> 0"
  by (cases u) simp_all

datatype wreq =
    W_Lincoln "nat option" "nat option" "nat option" bool
  | W_Density nat rat String.literal
  | W_Surv nat nat bool
  | W_DensityUnit nat rat warea warea
  | W_Interval nat nat nat bool bool
  | W_Unread
  | W_BadCount

definition w_missing :: "nat option \<Rightarrow> nat option \<Rightarrow> nat option \<Rightarrow> String.literal list" where
  "w_missing m c r =
     (if m = None then [STR ''the number marked in the first sample''] else [])
   @ (if c = None then [STR ''the number caught in the second sample''] else [])
   @ (if r = None then [STR ''how many of those were already marked''] else [])"

definition w_need :: "String.literal list \<Rightarrow> String.literal" where
  "w_need ns = STR ''I need '' + join_lit (STR '' and '') ns + STR '' to work that out; I won'' + apos + STR ''t assume it.''"

fun w_decline :: "wreq \<Rightarrow> decline option" where
  "w_decline (W_Lincoln m c r ch) =
     (if w_missing m c r \<noteq> [] then Some (Underspecified (w_need (w_missing m c r)))
      else case (m, c, r) of
        (Some m', Some c', Some r') \<Rightarrow>
          (if r' = 0 then Some (Impossible R_no_recapture)
           else if c' < r' \<or> m' < r' then Some (Impossible R_recapture_exceeds) else None)
      | _ \<Rightarrow> None)"
| "w_decline (W_Density n a u) = (if a \<le> 0 then Some (Impossible R_zero) else None)"
| "w_decline (W_Surv s n mort) = (if n = 0 \<or> n < s then Some (Impossible R_survivors) else None)"

| "w_decline (W_DensityUnit n a ui uo) = (if a \<le> 0 then Some (Impossible R_zero) else None)"
| "w_decline (W_Interval s1 s2 n conditional mort) =
    (if n = 0 \<or> n < s1 \<or> s1 < s2 \<or> (conditional \<and> s1 = 0)
     then Some (Impossible R_survivors) else None)"
| "w_decline W_Unread = Some (Underspecified (STR ''Supply one complete observation set with unique count roles, area units and the requested observation period. Annualizing a multi-year total requires an additional survival model.''))"
| "w_decline W_BadCount = Some (Impossible R_wild_count)"

fun w_answer :: "wreq \<Rightarrow> outcome" where
  "w_answer (W_Lincoln (Some m) (Some c) (Some r) False) =
     Exact (STR ''lincoln'') (of_nat m * of_nat c / of_nat r)"
| "w_answer (W_Lincoln (Some m) (Some c) (Some r) True) =
     Exact (STR ''chapman'') ((of_nat m + 1) * (of_nat c + 1) / (of_nat r + 1) - 1)"
| "w_answer (W_Lincoln m c r ch) = Decline Imprecise"
| "w_answer (W_Density n a u) = Exact (STR ''density'') (of_nat n / a)"
| "w_answer (W_Surv s n False) = Exact (STR ''survival'') (100 * of_nat s / of_nat n)"
| "w_answer (W_Surv s n True) = Exact (STR ''mortality'') (100 * (1 - of_nat s / of_nat n))"

| "w_answer (W_DensityUnit n a ui uo) = Exact (STR ''density'') (of_nat n * w_square_metres uo / (a * w_square_metres ui))"
| "w_answer (W_Interval s1 s2 n conditional mort) =
    (let fraction = of_nat s2 / of_nat (if conditional then s1 else n)
     in Exact (if mort then STR ''mortality'' else STR ''survival'') (100 * (if mort then 1 - fraction else fraction)))"
| "w_answer W_Unread = Decline Imprecise"
| "w_answer W_BadCount = Decline Imprecise"

definition w_kernel :: "wreq \<Rightarrow> outcome" where
  "w_kernel r = (case w_decline r of Some w \<Rightarrow> Decline w | None \<Rightarrow> w_answer r)"

theorem lincoln_underspecified:
  "w_kernel (W_Lincoln m c r ch) = Decline (Underspecified t) \<longleftrightarrow>
     w_missing m c r \<noteq> [] \<and> t = w_need (w_missing m c r)"
  by (cases m; cases c; cases r; cases ch) (auto simp: w_kernel_def w_missing_def split: option.splits if_splits)

theorem lincoln_estimate:
  assumes "w_kernel (W_Lincoln (Some m) (Some c) (Some r) False) = Exact k q"
  shows "0 < r \<and> r \<le> c \<and> r \<le> m \<and> q * of_nat r = of_nat m * of_nat c"
proof -
  have nd: "w_decline (W_Lincoln (Some m) (Some c) (Some r) False) = None"
    using assms by (cases "w_decline (W_Lincoln (Some m) (Some c) (Some r) False)") (simp_all add: w_kernel_def)
  then have h: "r \<noteq> 0" "r \<le> c" "r \<le> m"
    by (auto simp: w_missing_def split: if_splits)
  have q: "q = of_nat m * of_nat c / of_nat r" using assms nd by (simp add: w_kernel_def)
  have "(of_nat r :: rat) \<noteq> 0" using h(1) by simp
  then show ?thesis using h q by (simp add: field_simps)
qed

theorem chapman_estimate:
  assumes "w_kernel (W_Lincoln (Some m) (Some c) (Some r) True) = Exact k q"
  shows "0 < r \<and> r \<le> c \<and> r \<le> m \<and> (q + 1) * (of_nat r + 1) = (of_nat m + 1) * (of_nat c + 1)"
proof -
  have nd: "w_decline (W_Lincoln (Some m) (Some c) (Some r) True) = None"
    using assms by (cases "w_decline (W_Lincoln (Some m) (Some c) (Some r) True)") (simp_all add: w_kernel_def)
  then have h: "r \<noteq> 0" "r \<le> c" "r \<le> m"
    by (auto simp: w_missing_def split: if_splits)
  have q: "q = (of_nat m + 1) * (of_nat c + 1) / (of_nat r + 1) - 1" using assms nd by (simp add: w_kernel_def)
  have p: "(0::rat) < of_nat r + 1" by (rule add_nonneg_pos) simp_all
  then have ne: "(of_nat r + 1 :: rat) \<noteq> 0" by simp
  show ?thesis using h q ne by (auto simp: field_simps)
qed

theorem lincoln_impossible:
  "(\<exists>w. w_kernel (W_Lincoln (Some m) (Some c) (Some r) ch) = Decline (Impossible w)) \<longleftrightarrow>
     r = 0 \<or> c < r \<or> m < r"
  by (cases ch) (auto simp: w_kernel_def w_missing_def split: if_splits)

theorem density_value:
  assumes "w_kernel (W_Density n a u) = Exact k q"
  shows "0 < a \<and> q * a = of_nat n"
proof -
  have nd: "\<not> a \<le> 0" using assms by (cases "a \<le> 0") (simp_all add: w_kernel_def)
  then have a: "0 < a" by simp
  have "q = of_nat n / a" using assms nd by (simp add: w_kernel_def)
  then show ?thesis using a by simp
qed

theorem survival_value:
  assumes "w_kernel (W_Surv s n False) = Exact k q"
  shows "s \<le> n \<and> 0 < n \<and> q * of_nat n = 100 * of_nat s"
proof -
  have nd: "\<not> (n = 0 \<or> n < s)" using assms by (cases "n = 0 \<or> n < s") (simp_all add: w_kernel_def)
  then have h: "n \<noteq> 0" "s \<le> n" by auto
  have "q = 100 * of_nat s / of_nat n" using assms nd by (simp add: w_kernel_def)
  moreover have "(of_nat n :: rat) \<noteq> 0" using h(1) by simp
  ultimately show ?thesis using h by (auto simp: field_simps)
qed

text \<open>Survival and mortality are the two parts of a hundred percent.\<close>
theorem survival_mortality_sum:
  assumes "w_kernel (W_Surv s n False) = Exact k a" "w_kernel (W_Surv s n True) = Exact k' b"
  shows "a + b = 100"
proof -
  have nd: "\<not> (n = 0 \<or> n < s)" using assms(1) by (cases "n = 0 \<or> n < s") (simp_all add: w_kernel_def)
  have a: "a = 100 * of_nat s / of_nat n" using assms(1) nd by (simp add: w_kernel_def)
  have b: "b = 100 * (1 - of_nat s / of_nat n)" using assms(2) nd by (simp add: w_kernel_def)
  show ?thesis using a b by (simp add: algebra_simps divide_inverse)
qed


section \<open>Observation roles and area conversions\<close>
text \<open>For a closed cohort the second-period denominator is the survivors
at the first endpoint. Cumulative survival instead uses the original cohort.
These are observed proportions, not annualized constant-hazard estimates.\<close>

theorem density_unit_conservation:
  assumes "w_kernel (W_DensityUnit n a ui uo) = Exact k q"
  shows "0 < a \<and> q * (a * w_square_metres ui) = of_nat n * w_square_metres uo"
proof -
  have a: "0 < a" using assms by (auto simp: w_kernel_def split: if_splits)
  have q: "q = of_nat n * w_square_metres uo / (a * w_square_metres ui)"
    using assms a by (simp add: w_kernel_def)
  show ?thesis using a q by simp
qed

theorem density_same_unit:
  "w_kernel (W_DensityUnit n a u u) = w_kernel (W_Density n a (w_area_name u))"
  by (simp add: w_kernel_def field_simps)

theorem interval_observation_domain:
  assumes "w_kernel (W_Interval s1 s2 n conditional mort) = Exact k q"
  shows "s2 \<le> s1 \<and> s1 \<le> n \<and> 0 < n \<and> (conditional \<longrightarrow> 0 < s1)"
  using assms by (auto simp: w_kernel_def Let_def split: if_splits)

theorem interval_survival_value:
  assumes "w_kernel (W_Interval s1 s2 n conditional False) = Exact k q"
  shows "q * of_nat (if conditional then s1 else n) = 100 * of_nat s2"
proof -
  have d: "s2 \<le> s1" "s1 \<le> n" "0 < n" "conditional \<longrightarrow> 0 < s1"
    using interval_observation_domain[OF assms] by auto
  have q: "q = 100 * (of_nat s2 / of_nat (if conditional then s1 else n))"
    using assms d by (auto simp: w_kernel_def Let_def)
  show ?thesis using d q by (auto simp: field_simps)
qed

theorem interval_survival_composes:
  assumes "w_kernel (W_Surv s1 n False) = Exact k a"
      "w_kernel (W_Interval s1 s2 n True False) = Exact k' b"
      "w_kernel (W_Interval s1 s2 n False False) = Exact k'' c"
  shows "a * b = 100 * c"
proof -
  have d: "0 < n" "0 < s1" using interval_observation_domain[OF assms(2)] by auto
  have x: "a * of_nat n = 100 * of_nat s1" using survival_value[OF assms(1)] by simp
  have y: "b * of_nat s1 = 100 * of_nat s2" using interval_survival_value[OF assms(2)] by simp
  have z: "c * of_nat n = 100 * of_nat s2" using interval_survival_value[OF assms(3)] by simp
  have qa: "a = 100 * of_nat s1 / of_nat n" using x d by (simp add: nonzero_eq_divide_eq)
  have qb: "b = 100 * of_nat s2 / of_nat s1" using y d by (simp add: nonzero_eq_divide_eq)
  have qc: "c = 100 * of_nat s2 / of_nat n" using z d by (simp add: nonzero_eq_divide_eq)
  show ?thesis unfolding qa qb qc using d by (simp add: field_simps)
qed

section \<open>Response text\<close>

fun w_text :: "wreq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "w_text (W_Lincoln (Some m) (Some c) (Some r) False) o' = STR ''The estimated population is '' + vtxt o'
     + STR '' (Lincoln-Petersen N = M C / R = '' + show_int (int m) + STR '' x '' + show_int (int c)
     + STR '' / '' + show_int (int r) + STR '').''"
| "w_text (W_Lincoln (Some m) (Some c) (Some r) True) o' = STR ''The estimated population is '' + vtxt o'
     + STR '' (Chapman: (M+1)(C+1)/(R+1) - 1 with M '' + show_int (int m) + STR '', C '' + show_int (int c)
     + STR '', R '' + show_int (int r) + STR '').''"
| "w_text (W_Density n a u) o' = STR ''The density is '' + vtxt o' + STR '' per '' + u + STR '' (''
     + show_int (int n) + STR '' / '' + plain_lit a + STR '').''"
| "w_text (W_Surv s n False) o' = STR ''The survival rate is '' + vtxt o' + STR ''% (''
     + show_int (int s) + STR '' of '' + show_int (int n) + STR '' survived).''"
| "w_text (W_Surv s n True) o' = STR ''The mortality rate is '' + vtxt o' + STR ''% (1 - ''
     + show_int (int s) + STR ''/'' + show_int (int n) + STR '' survived).''"
| "w_text (W_DensityUnit n a ui uo) o' = STR ''The density is '' + vtxt o' + STR '' per '' + w_area_name uo + STR '' ('' + show_int (int n) + STR '' animals across '' + plain_lit a + STR '' '' + w_area_name ui + STR '').''"
| "w_text (W_Interval s1 s2 n conditional mort) o' = STR ''The '' +
    (if mort then STR ''mortality'' else STR ''survival'') + STR '' rate is '' + vtxt o' +
    (if conditional then STR ''% during the second observation period (relative to the survivors at the first endpoint).'' else STR ''% over both observation periods (relative to the original cohort).'')"
| "w_text r o' = STR ''''"

definition w_reply :: "wreq \<Rightarrow> reply" where
  "w_reply r = (let result = w_kernel r in mk_reply result (w_text r result))"

end
