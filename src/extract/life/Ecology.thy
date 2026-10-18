theory Ecology
  imports Life_Core
begin

text \<open>
  Lane S09-life, ecology (upstream/root/specialists/ecology/organ_ecology_v1.py):
  diversity indices and population growth. Simpson's indices and the logistic
  rate are exact rationals; Shannon, evenness, exponential and logistic
  population size, doubling time and non-integer discrete growth are enclosed
  with Isabelle's interval arithmetic.
\<close>

definition tot :: "nat list \<Rightarrow> nat" where "tot cs = sum_list cs"

definition species :: "nat list \<Rightarrow> nat" where
  "species cs = length (filter (\<lambda>c. 0 < c) cs)"

definition simpD :: "nat list \<Rightarrow> rat" where
  "simpD cs = of_nat (sum_list (map (\<lambda>c. c * (c - 1)) cs)) / of_nat (tot cs * (tot cs - 1))"

fun shan_sum :: "nat \<Rightarrow> nat list \<Rightarrow> real" where
  "shan_sum t [] = 0"
| "shan_sum t (c # r) = (if 0 < c then (real c / real t) * ln (real c / real t) else 0) + shan_sum t r"

fun shan_fa :: "nat \<Rightarrow> nat list \<Rightarrow> floatarith" where
  "shan_fa t [] = I 0"
| "shan_fa t (c # r) = (if 0 < c then
     floatarith.Add (floatarith.Mult (Q (of_nat c / of_nat t)) (floatarith.Ln (Q (of_nat c / of_nat t)))) (shan_fa t r)
     else shan_fa t r)"

lemma interp_shan_fa [simp]: "interpret_floatarith (shan_fa t cs) xs = shan_sum t cs"
  by (induct cs) (simp_all add: of_rat_divide split: if_splits)

section \<open>Requests\<close>

datatype ereq =
    E_Shannon "nat list" | E_Evenness "nat list" | E_SimpD "nat list" | E_SimpDiv "nat list"
  | E_SimpInv "nat list" | E_Richness "nat list"
  | E_LogRate rat rat rat
  | E_LogN rat rat rat rat
  | E_ExpN rat rat rat
  | E_Doubling rat
  | E_Geom rat rat rat

text \<open>The real-number model of every enclosed kind.\<close>
fun e_phys :: "ereq \<Rightarrow> real" where
  "e_phys (E_Shannon cs) = - shan_sum (tot cs) cs"
| "e_phys (E_Evenness cs) = - shan_sum (tot cs) cs / ln (real (species cs))"
| "e_phys (E_LogN r n k t) = rl k / (1 + (rl k - rl n) / rl n * exp (- (rl r * rl t)))"
| "e_phys (E_ExpN r n t) = rl n * exp (rl r * rl t)"
| "e_phys (E_Doubling r) = ln 2 / rl r"
| "e_phys (E_Geom l n t) = rl n * rl l powr rl t"
| "e_phys r = 0"

fun e_fa :: "ereq \<Rightarrow> floatarith" where
  "e_fa (E_Shannon cs) = floatarith.Minus (shan_fa (tot cs) cs)"
| "e_fa (E_Evenness cs) = floatarith.Mult (floatarith.Minus (shan_fa (tot cs) cs))
     (floatarith.Inverse (floatarith.Ln (I (int (species cs)))))"
| "e_fa (E_LogN r n k t) = floatarith.Mult (Q k) (floatarith.Inverse (floatarith.Add (I 1)
     (floatarith.Mult (floatarith.Mult (floatarith.Add (Q k) (floatarith.Minus (Q n))) (floatarith.Inverse (Q n)))
        (floatarith.Exp (floatarith.Minus (floatarith.Mult (Q r) (Q t)))))))"
| "e_fa (E_ExpN r n t) = floatarith.Mult (Q n) (floatarith.Exp (floatarith.Mult (Q r) (Q t)))"
| "e_fa (E_Doubling r) = floatarith.Mult (floatarith.Ln (I 2)) (floatarith.Inverse (Q r))"
| "e_fa (E_Geom l n t) = floatarith.Mult (Q n) (floatarith.Powr (Q l) (Q t))"
| "e_fa r = I 0"

lemma e_fa_phys: "interpret_floatarith (e_fa r) xs = e_phys r"
proof (cases r)
  case (E_Shannon cs) then show ?thesis by simp
next
  case (E_Evenness cs) then show ?thesis by (simp add: divide_inverse)
next
  case (E_LogN r n k t) then show ?thesis by (simp add: divide_inverse of_rat_divide)
next
  case (E_ExpN r n t) then show ?thesis by simp
next
  case (E_Doubling r) then show ?thesis by (simp add: divide_inverse)
next
  case (E_Geom l n t) then show ?thesis by simp
qed simp_all

fun e_bad :: "ereq \<Rightarrow> reason option" where
  "e_bad (E_Shannon cs) = (if tot cs = 0 then Some R_zero else None)"
| "e_bad (E_Evenness cs) = (if tot cs = 0 then Some R_zero else if species cs < 2 then Some R_one_species else None)"
| "e_bad (E_SimpD cs) = (if tot cs < 2 then Some R_zero else None)"
| "e_bad (E_SimpDiv cs) = (if tot cs < 2 then Some R_zero else None)"
| "e_bad (E_SimpInv cs) = (if tot cs < 2 \<or> simpD cs = 0 then Some R_zero else None)"
| "e_bad (E_Richness cs) = None"
| "e_bad (E_LogRate r n k) = (if k = 0 then Some R_zero else None)"
| "e_bad (E_LogN r n k t) = (if n = 0 then Some R_zero else None)"
| "e_bad (E_ExpN r n t) = None"
| "e_bad (E_Doubling r) = (if r \<le> 0 then Some R_rate else None)"
| "e_bad (E_Geom l n t) = (if nat_of_rat t = None \<and> l \<le> 0 then Some R_zero else None)"

fun e_answer :: "ereq \<Rightarrow> outcome" where
  "e_answer (E_Shannon cs) = approx_out (STR ''shannon'') (e_fa (E_Shannon cs))"
| "e_answer (E_Evenness cs) = approx_out (STR ''evenness'') (e_fa (E_Evenness cs))"
| "e_answer (E_SimpD cs) = Exact (STR ''simpson_d'') (simpD cs)"
| "e_answer (E_SimpDiv cs) = Exact (STR ''simpson_div'') (1 - simpD cs)"
| "e_answer (E_SimpInv cs) = Exact (STR ''simpson_inv'') (1 / simpD cs)"
| "e_answer (E_Richness cs) = Exact (STR ''richness'') (of_nat (species cs))"
| "e_answer (E_LogRate r n k) = Exact (STR ''logistic_rate'') (r * n * (1 - n / k))"
| "e_answer (E_LogN r n k t) = approx_out (STR ''logistic_n'') (e_fa (E_LogN r n k t))"
| "e_answer (E_ExpN r n t) = approx_out (STR ''exp_n'') (e_fa (E_ExpN r n t))"
| "e_answer (E_Doubling r) = approx_out (STR ''doubling'') (e_fa (E_Doubling r))"
| "e_answer (E_Geom l n t) = (case nat_of_rat t of
     Some m \<Rightarrow> Exact (STR ''geometric_n'') (n * l ^ m)
   | None \<Rightarrow> approx_out (STR ''geometric_n'') (e_fa (E_Geom l n t)))"

definition e_kernel :: "ereq \<Rightarrow> outcome" where
  "e_kernel r = (case e_bad r of Some w \<Rightarrow> Decline (Impossible w) | None \<Rightarrow> e_answer r)"

lemma e_answer_decline: "e_answer r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r) (auto dest: approx_out_decline split: option.splits)

lemma e_kernel_none: "e_bad r = None \<Longrightarrow> e_kernel r = e_answer r"
  by (simp add: e_kernel_def)

theorem e_impossible:
  "(\<exists>w. e_kernel r = Decline (Impossible w)) \<longleftrightarrow> e_bad r \<noteq> None"
proof (cases "e_bad r")
  case None
  then show ?thesis by (auto simp: e_kernel_def dest: e_answer_decline)
next
  case (Some w)
  then show ?thesis by (auto simp: e_kernel_def)
qed

theorem e_imprecise:
  assumes "e_kernel r = Decline Imprecise"
  shows "e_bad r = None"
  using assms by (cases "e_bad r") (simp_all add: e_kernel_def)

section \<open>What each kind means\<close>

theorem simpson_d_value:
  assumes "e_kernel (E_SimpD cs) = Exact k q"
  shows "2 \<le> tot cs \<and> q * of_nat (tot cs * (tot cs - 1)) = of_nat (sum_list (map (\<lambda>c. c * (c - 1)) cs))"
proof -
  have nd: "e_bad (E_SimpD cs) = None" using assms by (cases "e_bad (E_SimpD cs)") (simp_all add: e_kernel_def)
  then have t: "2 \<le> tot cs" by (auto split: if_splits)
  have q: "q = simpD cs" using assms nd by (simp add: e_kernel_def)
  have "(of_nat (tot cs * (tot cs - 1)) :: rat) \<noteq> 0" using t by simp
  then show ?thesis using q t by (simp add: simpD_def field_simps)
qed

theorem simpson_div_value:
  assumes "e_kernel (E_SimpDiv cs) = Exact k q"
  shows "q = 1 - simpD cs"
proof -
  have nd: "e_bad (E_SimpDiv cs) = None" using assms by (cases "e_bad (E_SimpDiv cs)") (simp_all add: e_kernel_def)
  then show ?thesis using assms by (simp add: e_kernel_def)
qed

theorem simpson_inv_value:
  assumes "e_kernel (E_SimpInv cs) = Exact k q"
  shows "simpD cs \<noteq> 0 \<and> q * simpD cs = 1"
proof -
  have nd: "e_bad (E_SimpInv cs) = None" using assms by (cases "e_bad (E_SimpInv cs)") (simp_all add: e_kernel_def)
  then have d: "simpD cs \<noteq> 0" by (auto split: if_splits)
  have "q = 1 / simpD cs" using assms nd by (simp add: e_kernel_def)
  then show ?thesis using d by simp
qed

theorem richness_value:
  "e_kernel (E_Richness cs) = Exact (STR ''richness'') (of_nat (species cs))"
  by (simp add: e_kernel_def)

theorem logistic_rate_value:
  assumes "e_kernel (E_LogRate r n k) = Exact c q"
  shows "k \<noteq> 0 \<and> q = r * n * (1 - n / k)"
proof -
  have nd: "e_bad (E_LogRate r n k) = None" using assms by (cases "e_bad (E_LogRate r n k)") (simp_all add: e_kernel_def)
  then have "k \<noteq> 0" by (auto split: if_splits)
  then show ?thesis using assms nd by (simp add: e_kernel_def)
qed

text \<open>Growth stops at the carrying capacity.\<close>
theorem logistic_rate_at_capacity:
  "k \<noteq> 0 \<Longrightarrow> e_kernel (E_LogRate r k k) = Exact (STR ''logistic_rate'') 0"
  by (simp add: e_kernel_def)

theorem geometric_exact:
  assumes "e_kernel (E_Geom l n t) = Exact c q"
  shows "\<exists>m. t = of_nat m \<and> q = n * l ^ m"
proof -
  have nd: "e_bad (E_Geom l n t) = None" using assms by (cases "e_bad (E_Geom l n t)") (simp_all add: e_kernel_def)
  show ?thesis
  proof (cases "nat_of_rat t")
    case None
    then show ?thesis using assms nd by (simp add: e_kernel_def)
  next
    case (Some m)
    then show ?thesis using assms nd nat_of_rat_sound by (auto simp: e_kernel_def)
  qed
qed

text \<open>Every enclosed kind is within one part in a thousand of its real model.\<close>
theorem ecology_approx:
  assumes "e_kernel r = Approx k d"
  shows "e_bad r = None \<and> \<bar>dec_val d - e_phys r\<bar> \<le> \<bar>e_phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "e_bad r = None" using assms by (cases "e_bad r") (simp_all add: e_kernel_def)
  have a: "e_answer r = Approx k d" using assms nd by (simp add: e_kernel_def)
  have "\<exists>c. approx_out c (e_fa r) = Approx k d"
    using a by (cases r) (auto split: option.splits)
  then obtain c where "approx_out c (e_fa r) = Approx k d" by blast
  from approx_out_sound[OF this] show ?thesis using nd e_fa_phys[of r "[]"] by simp
qed

section \<open>Declines stated apart from the code\<close>

lemma e_decl_iff: "e_kernel r = Decline (Impossible w) \<longleftrightarrow> e_bad r = Some w"
proof (cases "e_bad r")
  case None
  then show ?thesis by (auto simp: e_kernel_def dest: e_answer_decline)
next
  case (Some x)
  then show ?thesis by (auto simp: e_kernel_def)
qed

theorem doubling_declines_iff:
  "e_kernel (E_Doubling r) = Decline (Impossible R_rate) \<longleftrightarrow> r \<le> 0"
  by (simp add: e_decl_iff)

theorem logistic_n_declines_iff:
  "e_kernel (E_LogN r n k t) = Decline (Impossible R_zero) \<longleftrightarrow> n = 0"
  by (simp add: e_decl_iff)

theorem shannon_declines_iff:
  "e_kernel (E_Shannon cs) = Decline (Impossible R_zero) \<longleftrightarrow> (\<forall>c \<in> set cs. c = 0)"
  by (simp add: e_decl_iff tot_def sum_list_eq_0_iff)

theorem evenness_zero_declines_iff:
  "e_kernel (E_Evenness cs) = Decline (Impossible R_zero) \<longleftrightarrow> (\<forall>c \<in> set cs. c = 0)"
  by (auto simp: e_decl_iff tot_def sum_list_eq_0_iff split: if_splits)

section \<open>Model laws of the real-number model\<close>

text \<open>The doubling time doubles the population in the real model.\<close>
theorem doubling_phys:
  assumes "0 < r"
  shows "exp (rl r * e_phys (E_Doubling r)) = 2"
proof -
  have ne: "rl r \<noteq> 0" using assms by simp
  have "rl r * (ln 2 / rl r) = ln 2" using ne by (simp add: field_simps)
  then show ?thesis by simp
qed

text \<open>Logistic growth starts at the initial population, and a population at carrying capacity stays there.\<close>
theorem logistic_phys_start:
  assumes "n \<noteq> 0" "k \<noteq> 0"
  shows "e_phys (E_LogN r n k 0) = rl n"
proof -
  have n: "rl n \<noteq> 0" and k: "rl k \<noteq> 0" using assms by simp_all
  have e: "1 + (rl k - rl n) / rl n = rl k / rl n" using n by (simp add: field_simps)
  show ?thesis using n k by (simp add: e field_simps)
qed

theorem logistic_phys_capacity:
  assumes "k \<noteq> 0"
  shows "e_phys (E_LogN r k k t) = rl k"
  using assms by simp

theorem exp_phys_start: "e_phys (E_ExpN r n 0) = rl n"
  by simp

lemma tot_ge: "c \<in> set cs \<Longrightarrow> c \<le> tot cs"
  unfolding tot_def by (induct cs) (auto intro: trans_le_add2)

lemma species_cons: "0 < c \<Longrightarrow> species (c # r) = Suc (species r)"
  by (simp add: species_def)

lemma species_cons0: "species (0 # r) = species r"
  by (simp add: species_def)

lemma sum_list_all_zero: "\<forall>c \<in> set cs. c = (0::nat) \<Longrightarrow> sum_list cs = 0"
  by (induct cs) auto

lemma tot_pos_species: "0 < tot cs \<Longrightarrow> 0 < species cs"
proof (rule ccontr)
  assume t: "0 < tot cs" and "\<not> 0 < species cs"
  then have "filter (\<lambda>c. 0 < c) cs = []" by (simp add: species_def)
  then have z: "\<forall>c \<in> set cs. c = 0" by (simp add: filter_empty_conv)
  have "tot cs = 0" unfolding tot_def by (rule sum_list_all_zero[OF z])
  then show False using t by simp
qed

lemma species_tot_pos: "0 < species cs \<Longrightarrow> 0 < tot cs"
proof -
  assume "0 < species cs"
  then have "filter (\<lambda>c. 0 < c) cs \<noteq> []" by (auto simp: species_def)
  then obtain c where c: "c \<in> set cs" "0 < c" by (auto simp: filter_empty_conv)
  then show ?thesis using tot_ge[OF c(1)] by simp
qed

lemma shan_sum_nonpos:
  assumes "\<forall>c \<in> set cs. c \<le> t" "0 < t"
  shows "shan_sum t cs \<le> 0"
using assms
proof (induct cs)
  case Nil then show ?case by simp
next
  case (Cons c r)
  have ih: "shan_sum t r \<le> 0" using Cons by simp
  show ?case
  proof (cases "0 < c")
    case True
    have tp: "(0::real) < real t" using Cons(3) by simp
    have p0: "0 < real c / real t" using True tp by simp
    have p1: "real c / real t \<le> 1" using Cons(2) tp by (simp add: divide_le_eq_1_pos)
    have "ln (real c / real t) \<le> ln 1" using p0 p1 by (subst ln_le_cancel_iff) simp_all
    then have "(real c / real t) * ln (real c / real t) \<le> 0"
      using p0 by (intro mult_nonneg_nonpos) simp_all
    then show ?thesis using ih True by simp
  next
    case False then show ?thesis using ih by simp
  qed
qed

lemma gibbs_term:
  assumes "0 < p" "0 < (S::real)"
  shows "- (p * ln p) \<le> 1 / S + (ln S - 1) * p"
proof -
  have pS: "0 < p * S" using assms by simp
  have ip: "0 < inverse (p * S)" using pS by (rule positive_imp_inverse_positive)
  have h: "ln (inverse (p * S)) \<le> inverse (p * S) - 1" by (rule ln_le_minus_one[OF ip])
  have e: "ln (inverse (p * S)) = - ln p - ln S" using assms pS by (simp add: ln_inverse ln_mult)
  have "p * (- ln p - ln S) \<le> p * (inverse (p * S) - 1)"
    using h e assms(1) by (intro mult_left_mono) simp_all
  moreover have "p * (inverse (p * S) - 1) = 1 / S - p" using assms by (simp add: inverse_eq_divide field_simps)
  ultimately show ?thesis by (simp add: algebra_simps)
qed

lemma gibbs_aux:
  assumes "0 < t" "0 < (S::real)"
  shows "- shan_sum t cs \<le> real (species cs) / S + (ln S - 1) * (real (sum_list cs) / real t)"
proof (induct cs)
  case Nil then show ?case by (simp add: species_def)
next
  case (Cons c r)
  show ?case
  proof (cases "0 < c")
    case True
    have tp: "(0::real) < real t" using assms by simp
    have p0: "0 < real c / real t" using True tp by simp
    have t1: "- ((real c / real t) * ln (real c / real t)) \<le> 1 / S + (ln S - 1) * (real c / real t)"
      using gibbs_term[OF p0 assms(2)] .
    have hs: "shan_sum t (c # r) = (real c / real t) * ln (real c / real t) + shan_sum t r" using True by simp
    have eq: "real (species (c # r)) / S + (ln S - 1) * (real (sum_list (c # r)) / real t)
        = (1 / S + (ln S - 1) * (real c / real t))
          + (real (species r) / S + (ln S - 1) * (real (sum_list r) / real t))"
      using True by (simp add: species_cons add_divide_distrib distrib_left)
    show ?thesis using t1 Cons eq hs by linarith
  next
    case False
    then have c0: "c = 0" by simp
    show ?thesis using Cons c0 by (simp add: species_cons0)
  qed
qed

text \<open>Shannon diversity lies between 0 and ln S (Gibbs): entropy is non-negative and
at most that of the uniform distribution over the S species present.\<close>
theorem shannon_gibbs:
  assumes "0 < tot cs"
  shows "0 \<le> e_phys (E_Shannon cs) \<and> e_phys (E_Shannon cs) \<le> ln (real (species cs))"
proof -
  have sp: "0 < species cs" by (rule tot_pos_species[OF assms])
  have lo: "shan_sum (tot cs) cs \<le> 0"
    using shan_sum_nonpos[of cs "tot cs"] tot_ge assms by blast
  have sp': "(0::real) < real (species cs)" using sp by simp
  have tp: "(0::real) < real (tot cs)" using assms by simp
  have "- shan_sum (tot cs) cs \<le> real (species cs) / real (species cs)
      + (ln (real (species cs)) - 1) * (real (sum_list cs) / real (tot cs))"
    using gibbs_aux[OF assms sp'] .
  moreover have "real (sum_list cs) / real (tot cs) = 1"
  proof -
    have ne: "real (tot cs) \<noteq> 0" using tp by simp
    show ?thesis using ne by (simp add: tot_def[symmetric])
  qed
  moreover have "real (species cs) / real (species cs) = 1" using sp' by simp
  ultimately show ?thesis using lo by simp
qed

text \<open>Pielou evenness lies between 0 and 1.\<close>
theorem evenness_range:
  assumes "2 \<le> species cs"
  shows "0 \<le> e_phys (E_Evenness cs) \<and> e_phys (E_Evenness cs) \<le> 1"
proof -
  have t: "0 < tot cs" using species_tot_pos assms by simp
  have g: "0 \<le> - shan_sum (tot cs) cs" "- shan_sum (tot cs) cs \<le> ln (real (species cs))"
    using shannon_gibbs[OF t] by simp_all
  have s: "(1::real) < real (species cs)" using assms by simp
  then have l: "0 < ln (real (species cs))" by simp
  have ev: "e_phys (E_Evenness cs) = (- shan_sum (tot cs) cs) / ln (real (species cs))" by simp
  have a: "0 \<le> (- shan_sum (tot cs) cs) / ln (real (species cs))" using g(1) l by (rule divide_nonneg_pos)
  have b: "(- shan_sum (tot cs) cs) / ln (real (species cs)) \<le> 1"
    using g(2) l by (simp only: divide_le_eq_1_pos)
  show ?thesis using ev a b by simp
qed

text \<open>The kernel's enclosure of Shannon diversity respects the same range, up to its stated error.\<close>
theorem shannon_kernel_range:
  assumes "e_kernel (E_Shannon cs) = Approx k d"
  shows "- (1 / 1000000000) \<le> dec_val d \<and>
         dec_val d \<le> ln (real (species cs)) + ln (real (species cs)) / 1000 + 1 / 1000000000"
proof -
  have nd: "tot cs \<noteq> 0" using assms by (auto simp: e_kernel_def split: if_splits)
  then have t: "0 < tot cs" by simp
  have a: "\<bar>dec_val d - e_phys (E_Shannon cs)\<bar> \<le> \<bar>e_phys (E_Shannon cs)\<bar> / 1000 + 1 / 1000000000"
    using ecology_approx[OF assms] by simp
  have g: "0 \<le> e_phys (E_Shannon cs)" "e_phys (E_Shannon cs) \<le> ln (real (species cs))"
    using shannon_gibbs[OF t] by simp_all
  then show ?thesis using a by (auto simp: abs_le_iff)
qed

text \<open>The enclosed doubling time is the model value ln 2 / r, and the rate must be positive.\<close>
theorem doubling_kernel_bound:
  assumes "e_kernel (E_Doubling r) = Approx k d"
  shows "0 < r \<and> \<bar>dec_val d - ln 2 / rl r\<bar> \<le> \<bar>ln 2 / rl r\<bar> / 1000 + 1 / 1000000000"
proof -
  have "e_bad (E_Doubling r) = None" using ecology_approx[OF assms] by simp
  then have "0 < r" by (auto split: if_splits)
  moreover have "\<bar>dec_val d - e_phys (E_Doubling r)\<bar> \<le> \<bar>e_phys (E_Doubling r)\<bar> / 1000 + 1 / 1000000000"
    using ecology_approx[OF assms] by blast
  ultimately show ?thesis by simp
qed

section \<open>Response text\<close>

definition dnote :: "ereq \<Rightarrow> String.literal" where
  "dnote r = (case r of
     E_SimpD cs \<Rightarrow> plain_lit (simpD cs) | E_SimpDiv cs \<Rightarrow> plain_lit (simpD cs)
   | E_SimpInv cs \<Rightarrow> plain_lit (simpD cs) | _ \<Rightarrow> STR '''')"

fun e_text :: "ereq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "e_text (E_Shannon cs) o' = STR ''The Shannon diversity index H'' + apos + STR '' is '' + vtxt o'
     + STR '' (-sum p ln p over '' + show_int (int (species cs)) + STR '' species, natural log).''"
| "e_text (E_Evenness cs) o' = STR ''The Shannon evenness J is '' + vtxt o' + STR '' (H'' + apos
     + STR '' / ln S with S = '' + show_int (int (species cs)) + STR '' species).''"
| "e_text (E_SimpD cs) o' = STR ''Simpson'' + apos + STR ''s index D is '' + vtxt o'
     + STR '' (sum n(n-1) / N(N-1), the probability two individuals drawn are the same species; diversity is 1 - D = ''
     + plain_lit (1 - simpD cs) + STR '').''"
| "e_text (E_SimpDiv cs) o' = STR ''Simpson'' + apos + STR ''s diversity index (1 - D) is '' + vtxt o'
     + STR '' (D = sum n(n-1) / N(N-1) = '' + dnote (E_SimpDiv cs) + STR ''; convention named because texts differ).''"
| "e_text (E_SimpInv cs) o' = STR ''The reciprocal Simpson index 1/D is '' + vtxt o'
     + STR '' (D = sum n(n-1) / N(N-1) = '' + dnote (E_SimpInv cs) + STR '').''"
| "e_text (E_Richness cs) o' = STR ''The species richness is '' + vtxt o' + STR '' (species with at least one individual).''"
| "e_text (E_LogRate r n k) o' = STR ''The growth rate is '' + vtxt o'
     + STR '' individuals per unit time (dN/dt = r N (1 - N/K) = '' + plain_lit r + STR '' x '' + plain_lit n
     + STR '' x (1 - '' + plain_lit n + STR ''/'' + plain_lit k + STR ''))''
     + (if n > k then STR ''; negative because N is above K'' else STR '''') + STR ''.''"
| "e_text (E_LogN r n k t) o' = STR ''The population is '' + vtxt o'
     + STR '' (logistic: K / (1 + ((K - N0)/N0) e^(-rt)) with K '' + plain_lit k + STR '', N0 '' + plain_lit n
     + STR '', r '' + plain_lit r + STR '', t '' + plain_lit t + STR '').''"
| "e_text (E_ExpN r n t) o' = STR ''The population is '' + vtxt o' + STR '' (N0 e^(r t) = '' + plain_lit n
     + STR '' x e^('' + plain_lit r + STR '' x '' + plain_lit t + STR ''), continuous exponential growth).''"
| "e_text (E_Doubling r) o' = STR ''The doubling time is '' + vtxt o' + STR '' time units (ln 2 / r = 0.6931 / ''
     + plain_lit r + STR '').''"
| "e_text (E_Geom l n t) o' = STR ''The population is '' + vtxt o' + STR '' (N0 lambda^t = '' + plain_lit n
     + STR '' x '' + plain_lit l + STR ''^'' + plain_lit t + STR '', discrete growth).''"

definition e_reply :: "ereq \<Rightarrow> reply" where
  "e_reply r = mk_reply (e_kernel r) (e_text r (e_kernel r))"

end
