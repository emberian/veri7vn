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

text \<open>The doubling time doubles the population.\<close>
theorem doubling_property:
  assumes "0 < r"
  shows "exp (r * (ln 2 / r)) = (2::real)"
proof -
  have "r * (ln 2 / r) = ln 2" using assms by (simp add: field_simps)
  then show ?thesis by simp
qed

text \<open>Logistic growth starts at the initial population.\<close>
theorem logistic_starts_at_n0:
  assumes "k \<noteq> 0" "n \<noteq> 0"
  shows "(k::real) / (1 + (k - n) / n * exp (- (r * 0))) = n"
proof -
  have e: "1 + (k - n) / n = k / n" using assms by (simp add: field_simps)
  show ?thesis using assms by (simp add: e field_simps)
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
