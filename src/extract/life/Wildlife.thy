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

datatype wreq =
    W_Lincoln "nat option" "nat option" "nat option" bool
  | W_Density nat rat String.literal
  | W_Surv nat nat bool

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

fun w_answer :: "wreq \<Rightarrow> outcome" where
  "w_answer (W_Lincoln (Some m) (Some c) (Some r) False) =
     Exact (STR ''lincoln'') (of_nat m * of_nat c / of_nat r)"
| "w_answer (W_Lincoln (Some m) (Some c) (Some r) True) =
     Exact (STR ''chapman'') ((of_nat m + 1) * (of_nat c + 1) / (of_nat r + 1) - 1)"
| "w_answer (W_Lincoln m c r ch) = Decline Imprecise"
| "w_answer (W_Density n a u) = Exact (STR ''density'') (of_nat n / a)"
| "w_answer (W_Surv s n False) = Exact (STR ''survival'') (100 * of_nat s / of_nat n)"
| "w_answer (W_Surv s n True) = Exact (STR ''mortality'') (100 * (1 - of_nat s / of_nat n))"

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
| "w_text r o' = STR ''''"

definition w_reply :: "wreq \<Rightarrow> reply" where
  "w_reply r = mk_reply (w_kernel r) (w_text r (w_kernel r))"

end
