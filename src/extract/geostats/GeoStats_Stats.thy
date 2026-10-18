theory GeoStats_Stats
  imports GeoStats_Num
begin

text \<open>
  The statistics family (specialists statistics, statistics-v2, statistics-v3;
  organs upstream/root/specialists/statistics*/organ_stats_v{1,2,3}.py) as one
  HOL kernel: descriptive statistics over a finite list of exact rationals
  (mean, median, mode, range, sample and population variance and standard
  deviation), z-scores, combinations, permutations and the binomial
  probability of exactly k successes. Everything is exact rational arithmetic
  except the standard deviation, a square root, which is enclosed in a verified
  interval and rounded to four decimals.
\<close>

section \<open>Requests and outcomes\<close>

datatype skind = SK_mean | SK_median | SK_mode | SK_range | SK_stdev | SK_variance
  | SK_combinations | SK_permutations | SK_binomial | SK_z

text \<open>The @{typ bool} of mean and median asks for the exact fraction beside a
non-integer value (statistics-v2 and v3); the one of the counting requests and
the binomial selects the v2 wording of the reply over v1's. A variance or
standard deviation request carries @{text pop}: population (divide by n) or
sample (divide by n - 1). @{text "S_choose n k"} is the number of ways to choose
@{text k} of @{text n}; @{text "S_arrange n k"} the ordered arrangements of
@{text k} of @{text n} (all of them when @{text k} is absent);
@{text "S_binom k n p"} is P(X = k) for @{text n} trials with success
probability @{text p}.\<close>
datatype srequest =
    S_mean "rat list" bool
  | S_median "rat list" bool
  | S_mode "rat list"
  | S_range "rat list"
  | S_variance bool "rat list"
  | S_stdev bool "rat list"
  | S_choose nat nat bool
  | S_arrange nat "nat option" bool
  | S_binom nat nat rat bool
  | S_z rat rat rat

datatype sreason = SR_choose_k_gt_n | SR_arrange_k_gt_n | SR_binomial_setup | SR_nonpositive_sd | SR_too_large

datatype sdecline = SNoData | STooFew | SImpossible sreason | SImprecise

datatype soutcome = SRat skind rat | SApprox skind int | SCount skind nat
  | SModes "rat list" | SNoMode | SDecline sdecline

fun skind_of :: "srequest \<Rightarrow> skind" where
  "skind_of (S_mean _ _) = SK_mean"
| "skind_of (S_median _ _) = SK_median"
| "skind_of (S_mode _) = SK_mode"
| "skind_of (S_range _) = SK_range"
| "skind_of (S_variance _ _) = SK_variance"
| "skind_of (S_stdev _ _) = SK_stdev"
| "skind_of (S_choose _ _ _) = SK_combinations"
| "skind_of (S_arrange _ _ _) = SK_permutations"
| "skind_of (S_binom _ _ _ _) = SK_binomial"
| "skind_of (S_z _ _ _) = SK_z"


section \<open>The measures\<close>

definition smean :: "rat list \<Rightarrow> rat" where
  "smean xs = sum_list xs / of_nat (length xs)"

definition svar :: "bool \<Rightarrow> rat list \<Rightarrow> rat" where
  "svar pop xs = sum_list (map (\<lambda>x. (x - smean xs)\<^sup>2) xs) / of_nat (length xs - (if pop then 0 else 1))"

definition smed_sorted :: "rat list \<Rightarrow> rat" where
  "smed_sorted s = (if length s mod 2 = 1 then s ! (length s div 2)
     else (s ! (length s div 2 - 1) + s ! (length s div 2)) / 2)"

definition smedian :: "rat list \<Rightarrow> rat" where
  "smedian xs = smed_sorted (sort xs)"

fun lmax :: "rat list \<Rightarrow> rat" where
  "lmax [] = 0" | "lmax (x # xs) = fold max xs x"

fun lmin :: "rat list \<Rightarrow> rat" where
  "lmin [] = 0" | "lmin (x # xs) = fold min xs x"

definition srange :: "rat list \<Rightarrow> rat" where
  "srange xs = lmax xs - lmin xs"

text \<open>The modes: the values that occur most often, in order of first
occurrence (Python's @{text multimode}).\<close>
definition sdistinct :: "rat list \<Rightarrow> rat list" where
  "sdistinct xs = rev (remdups (rev xs))"

definition smaxcount :: "rat list \<Rightarrow> nat" where
  "smaxcount xs = foldr max (map (count_list xs) (sdistinct xs)) 0"

definition smodes :: "rat list \<Rightarrow> rat list" where
  "smodes xs = filter (\<lambda>x. count_list xs x = smaxcount xs) (sdistinct xs)"

definition scomb :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "scomb n k = fact n div (fact k * fact (n - k))"

definition sperm :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "sperm n k = fact n div fact (n - k)"

definition sbinom :: "nat \<Rightarrow> nat \<Rightarrow> rat \<Rightarrow> rat" where
  "sbinom k n p = of_nat (scomb n k) * p ^ k * (1 - p) ^ (n - k)"

text \<open>Resource guard: counting questions above this size are declined (the
binary would spend its time multiplying huge integers; Python's math module
would answer them).\<close>
definition slimit :: nat where "slimit = 10000"


section \<open>Declines\<close>

fun sdecline_of :: "srequest \<Rightarrow> sdecline option" where
  "sdecline_of (S_mean xs _) = (if xs = [] then Some SNoData else None)"
| "sdecline_of (S_median xs _) = (if xs = [] then Some SNoData else None)"
| "sdecline_of (S_mode xs) = (if xs = [] then Some SNoData else None)"
| "sdecline_of (S_range xs) = (if xs = [] then Some SNoData else None)"
| "sdecline_of (S_variance pop xs) =
     (if xs = [] then Some SNoData else if \<not> pop \<and> length xs < 2 then Some STooFew else None)"
| "sdecline_of (S_stdev pop xs) =
     (if xs = [] then Some SNoData else if \<not> pop \<and> length xs < 2 then Some STooFew else None)"
| "sdecline_of (S_choose n k _) =
     (if slimit < n then Some (SImpossible SR_too_large)
      else if n < k then Some (SImpossible SR_choose_k_gt_n) else None)"
| "sdecline_of (S_arrange n k _) =
     (if slimit < n then Some (SImpossible SR_too_large)
      else case k of Some k \<Rightarrow> (if n < k then Some (SImpossible SR_arrange_k_gt_n) else None) | None \<Rightarrow> None)"
| "sdecline_of (S_binom k n p _) =
     (if slimit < n then Some (SImpossible SR_too_large)
      else if p < 0 \<or> 1 < p \<or> n < k then Some (SImpossible SR_binomial_setup) else None)"
| "sdecline_of (S_z x mu sd) = (if sd \<le> 0 then Some (SImpossible SR_nonpositive_sd) else None)"


section \<open>Values\<close>

datatype sform = SF_rat rat | SF_root rat | SF_count nat | SF_modes "rat list" | SF_nomode

fun sval :: "srequest \<Rightarrow> sform" where
  "sval (S_mean xs _) = SF_rat (smean xs)"
| "sval (S_median xs _) = SF_rat (smedian xs)"
| "sval (S_mode xs) = (if length (smodes xs) = length xs then SF_nomode else SF_modes (smodes xs))"
| "sval (S_range xs) = SF_rat (srange xs)"
| "sval (S_variance pop xs) = SF_rat (svar pop xs)"
| "sval (S_stdev pop xs) = SF_root (svar pop xs)"
| "sval (S_choose n k _) = SF_count (scomb n k)"
| "sval (S_arrange n k _) = SF_count (case k of None \<Rightarrow> fact n | Some k \<Rightarrow> sperm n k)"
| "sval (S_binom k n p _) = SF_rat (sbinom k n p)"
| "sval (S_z x mu sd) = SF_rat ((x - mu) / sd)"

definition s_answer :: "srequest \<Rightarrow> soutcome" where
  "s_answer r = (case sval r of
       SF_rat q \<Rightarrow> SRat (skind_of r) q
     | SF_root d \<Rightarrow> (case enc4 (floatarith.Sqrt (Q d)) of None \<Rightarrow> SDecline SImprecise
                       | Some m \<Rightarrow> SApprox (skind_of r) m)
     | SF_count n \<Rightarrow> SCount (skind_of r) n
     | SF_modes ms \<Rightarrow> SModes ms
     | SF_nomode \<Rightarrow> SNoMode)"

definition s_kernel :: "srequest \<Rightarrow> soutcome" where
  "s_kernel r = (case sdecline_of r of Some w \<Rightarrow> SDecline w | None \<Rightarrow> s_answer r)"

lemma s_answer_decline: "s_answer r = SDecline w \<Longrightarrow> w = SImprecise"
  by (cases "sval r") (auto simp: s_answer_def split: option.splits)

lemma s_answer_rat: "s_answer r = SRat k q \<Longrightarrow> k = skind_of r \<and> sval r = SF_rat q"
  by (cases "sval r") (auto simp: s_answer_def split: option.splits)

lemma s_answer_count: "s_answer r = SCount k n \<Longrightarrow> k = skind_of r \<and> sval r = SF_count n"
  by (cases "sval r") (auto simp: s_answer_def split: option.splits)

lemma s_answer_approx:
  assumes "s_answer r = SApprox k m"
  shows "k = skind_of r \<and> (\<exists>d. sval r = SF_root d \<and>
           \<bar>real_of_int m - sqrt (rl d) * 10000\<bar> \<le> 51 / 100)"
proof (cases "sval r")
  case (SF_root d)
  then obtain m' where m': "enc4 (floatarith.Sqrt (Q d)) = Some m'" and e: "SApprox (skind_of r) m' = SApprox k m"
    using assms by (auto simp: s_answer_def split: option.splits)
  from e have mm: "m' = m" and kk: "k = skind_of r" by simp_all
  have "\<bar>real_of_int m' - interpret_floatarith (floatarith.Sqrt (Q d)) [] * 10000\<bar> \<le> 51 / 100"
    by (rule enc4_sound[OF m'])
  then show ?thesis using SF_root mm kk by auto
next
  case (SF_rat x)
  then show ?thesis using assms by (simp add: s_answer_def)
next
  case (SF_count x)
  then show ?thesis using assms by (simp add: s_answer_def)
next
  case (SF_modes x)
  then show ?thesis using assms by (simp add: s_answer_def)
next
  case SF_nomode
  then show ?thesis using assms by (simp add: s_answer_def)
qed

theorem s_rat_sound:
  assumes "s_kernel r = SRat k q"
  shows "sdecline_of r = None \<and> k = skind_of r \<and> sval r = SF_rat q"
proof -
  have nd: "sdecline_of r = None" and a: "s_answer r = SRat k q"
    using assms by (auto simp: s_kernel_def split: option.splits)
  show ?thesis using nd s_answer_rat[OF a] by simp
qed

theorem s_count_sound:
  assumes "s_kernel r = SCount k n"
  shows "sdecline_of r = None \<and> k = skind_of r \<and> sval r = SF_count n"
proof -
  have nd: "sdecline_of r = None" and a: "s_answer r = SCount k n"
    using assms by (auto simp: s_kernel_def split: option.splits)
  show ?thesis using nd s_answer_count[OF a] by simp
qed

theorem s_approx_sound:
  assumes "s_kernel r = SApprox k m"
  shows "sdecline_of r = None \<and> k = skind_of r \<and> (\<exists>d. sval r = SF_root d \<and>
           \<bar>real_of_int m - sqrt (rl d) * 10000\<bar> \<le> 51 / 100)"
proof -
  have nd: "sdecline_of r = None" and a: "s_answer r = SApprox k m"
    using assms by (auto simp: s_kernel_def split: option.splits)
  show ?thesis using nd s_answer_approx[OF a] by simp
qed

theorem s_no_data: "s_kernel r = SDecline SNoData \<longleftrightarrow> sdecline_of r = Some SNoData"
  by (auto simp: s_kernel_def dest: s_answer_decline split: option.splits)

theorem s_too_few: "s_kernel r = SDecline STooFew \<longleftrightarrow> sdecline_of r = Some STooFew"
  by (auto simp: s_kernel_def dest: s_answer_decline split: option.splits)

theorem s_impossible:
  "s_kernel r = SDecline (SImpossible why) \<longleftrightarrow> sdecline_of r = Some (SImpossible why)"
  by (auto simp: s_kernel_def dest: s_answer_decline split: option.splits)

lemma sdecline_not_imprecise: "sdecline_of r = Some w \<Longrightarrow> w \<noteq> SImprecise"
  by (cases r) (auto split: if_splits option.splits)

theorem s_imprecise:
  assumes "s_kernel r = SDecline SImprecise"
  shows "sdecline_of r = None"
proof (cases "sdecline_of r")
  case None then show ?thesis .
next
  case (Some w)
  then have "s_kernel r = SDecline w" by (simp add: s_kernel_def)
  then have "w = SImprecise" using assms by simp
  then show ?thesis using sdecline_not_imprecise[OF Some] by simp
qed

text \<open>The organs' decline predicates, spelled out.\<close>
theorem too_few_iff:
  "xs \<noteq> [] \<Longrightarrow> s_kernel (S_stdev pop xs) = SDecline STooFew \<longleftrightarrow> \<not> pop \<and> length xs < 2"
  by (auto simp: s_kernel_def dest: s_answer_decline)

theorem choose_impossible_iff:
  "\<not> slimit < n \<Longrightarrow> s_kernel (S_choose n k v) = SDecline (SImpossible SR_choose_k_gt_n) \<longleftrightarrow> n < k"
  by (auto simp: s_kernel_def dest: s_answer_decline)

theorem binomial_impossible_iff:
  "\<not> slimit < n \<Longrightarrow> s_kernel (S_binom k n p v) = SDecline (SImpossible SR_binomial_setup) \<longleftrightarrow>
     p < 0 \<or> 1 < p \<or> n < k"
  by (auto simp: s_kernel_def dest: s_answer_decline)

theorem z_impossible_iff:
  "s_kernel (S_z x mu sd) = SDecline (SImpossible SR_nonpositive_sd) \<longleftrightarrow> sd \<le> 0"
  by (auto simp: s_kernel_def dest: s_answer_decline)


section \<open>What each kind means\<close>

subsection \<open>Mean, variance, standard deviation\<close>

theorem mean_value:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_mean xs v) = SRat SK_mean (smean xs) \<and> smean xs * of_nat (length xs) = sum_list xs"
proof (intro conjI)
  show "s_kernel (S_mean xs v) = SRat SK_mean (smean xs)"
    using assms by (simp add: s_kernel_def s_answer_def)
  have nz: "(of_nat (length xs) :: rat) \<noteq> 0" using assms by simp
  show "smean xs * of_nat (length xs) = sum_list xs" using nz unfolding smean_def by (simp add: divide_simps)
qed

lemma svar_nonneg: "0 \<le> svar pop xs"
  unfolding svar_def by (intro divide_nonneg_nonneg sum_list_nonneg) auto

theorem variance_population:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_variance True xs) = SRat SK_variance (svar True xs) \<and>
         svar True xs * of_nat (length xs) = sum_list (map (\<lambda>x. (x - smean xs)\<^sup>2) xs) \<and> 0 \<le> svar True xs"
proof (intro conjI)
  show "s_kernel (S_variance True xs) = SRat SK_variance (svar True xs)"
    using assms by (simp add: s_kernel_def s_answer_def)
  have nz: "(of_nat (length xs) :: rat) \<noteq> 0" using assms by simp
  show "svar True xs * of_nat (length xs) = sum_list (map (\<lambda>x. (x - smean xs)\<^sup>2) xs)"
    using nz unfolding svar_def by (simp add: divide_simps)
  show "0 \<le> svar True xs" by (rule svar_nonneg)
qed

theorem variance_sample:
  assumes "2 \<le> length xs"
  shows "s_kernel (S_variance False xs) = SRat SK_variance (svar False xs) \<and>
         svar False xs * of_nat (length xs - 1) = sum_list (map (\<lambda>x. (x - smean xs)\<^sup>2) xs) \<and> 0 \<le> svar False xs"
proof (intro conjI)
  have ne: "xs \<noteq> []" using assms by auto
  have nl: "\<not> length xs < 2" using assms by simp
  show "s_kernel (S_variance False xs) = SRat SK_variance (svar False xs)"
    using ne nl by (simp add: s_kernel_def s_answer_def)
  have nz: "(of_nat (length xs - 1) :: rat) \<noteq> 0" using assms by simp
  show "svar False xs * of_nat (length xs - 1) = sum_list (map (\<lambda>x. (x - smean xs)\<^sup>2) xs)"
    using nz unfolding svar_def by (simp add: divide_simps)
  show "0 \<le> svar False xs" by (rule svar_nonneg)
qed

text \<open>The standard deviation is the non-negative square root of the
variance (sample or population as asked), enclosed and rounded to four
decimals: the stated integer @{text m} stands for @{text "m / 10000"}.\<close>
theorem stdev_value:
  assumes "s_kernel (S_stdev pop xs) = SApprox k m"
  shows "k = SK_stdev \<and> (\<exists>s. 0 \<le> s \<and> s\<^sup>2 = rl (svar pop xs) \<and> \<bar>real_of_int m - s * 10000\<bar> \<le> 51 / 100)"
proof -
  from s_approx_sound[OF assms] obtain d where kk: "k = SK_stdev"
    and d: "sval (S_stdev pop xs) = SF_root d"
    and b: "\<bar>real_of_int m - sqrt (rl d) * 10000\<bar> \<le> 51 / 100" by auto
  have dd: "d = svar pop xs" using d by simp
  have X: "0 \<le> rl (svar pop xs)" using svar_nonneg[of pop xs] by (simp add: zero_le_of_rat_iff)
  show ?thesis
  proof (intro conjI exI[where x = "sqrt (rl d)"])
    show "k = SK_stdev" by (rule kk)
    show "0 \<le> sqrt (rl d)" by (rule real_sqrt_ge_zero) (use X dd in simp)
    show "(sqrt (rl d))\<^sup>2 = rl (svar pop xs)" unfolding dd by (rule real_sqrt_pow2[OF X])
    show "\<bar>real_of_int m - sqrt (rl d) * 10000\<bar> \<le> 51 / 100" by (rule b)
  qed
qed

subsection \<open>Median\<close>

lemma length_filter_mono: "(\<forall>x. P x \<longrightarrow> Q x) \<Longrightarrow> length (filter P s) \<le> length (filter Q s)"
  by (induct s) auto

lemma length_filter_perm: "length (filter P xs) = length (filter P (sort xs))"
proof -
  have "mset (filter P (sort xs)) = mset (filter P xs)" by (simp add: mset_filter)
  then show ?thesis by (metis size_mset)
qed

lemma sorted_count_le:
  assumes s: "sorted s" and i: "i < length s"
  shows "i + 1 \<le> length (filter (\<lambda>x. x \<le> s ! i) s)"
proof -
  have all: "\<forall>x\<in>set (take (i + 1) s). x \<le> s ! i"
  proof
    fix x assume "x \<in> set (take (i + 1) s)"
    then obtain j where j: "j < length (take (i + 1) s)" "take (i + 1) s ! j = x"
      by (auto simp: in_set_conv_nth)
    have ji: "j \<le> i" using j(1) i by simp
    have "s ! j \<le> s ! i" by (rule sorted_nth_mono[OF s ji i])
    moreover have "x = s ! j" using j by simp
    ultimately show "x \<le> s ! i" by simp
  qed
  have f1: "filter (\<lambda>x. x \<le> s ! i) (take (i + 1) s) = take (i + 1) s"
    using all by (simp add: filter_id_conv)
  have e: "filter (\<lambda>x. x \<le> s ! i) s =
      filter (\<lambda>x. x \<le> s ! i) (take (i + 1) s) @ filter (\<lambda>x. x \<le> s ! i) (drop (i + 1) s)"
    by (simp flip: filter_append)
  have lt: "length (take (i + 1) s) = i + 1" using i by simp
  have "length (filter (\<lambda>x. x \<le> s ! i) s) = length (take (i + 1) s) + length (filter (\<lambda>x. x \<le> s ! i) (drop (i + 1) s))"
    by (simp only: e f1 length_append)
  then show ?thesis using lt by arith
qed

lemma sorted_count_ge:
  assumes s: "sorted s" and i: "i < length s"
  shows "length s - i \<le> length (filter (\<lambda>x. s ! i \<le> x) s)"
proof -
  have le: "i \<le> length s" using i by simp
  have all: "\<forall>x\<in>set (drop i s). s ! i \<le> x"
  proof
    fix x assume "x \<in> set (drop i s)"
    then obtain j where j: "j < length (drop i s)" "drop i s ! j = x"
      by (auto simp: in_set_conv_nth)
    have j2: "j < length s - i" using j(1) by simp
    have ij: "i + j < length s" using j2 by arith
    have "s ! i \<le> s ! (i + j)" by (rule sorted_nth_mono[OF s _ ij]) simp
    moreover have "x = s ! (i + j)" using j le by (simp add: nth_drop)
    ultimately show "s ! i \<le> x" by simp
  qed
  have f1: "filter (\<lambda>x. s ! i \<le> x) (drop i s) = drop i s"
    using all by (simp add: filter_id_conv)
  have e: "filter (\<lambda>x. s ! i \<le> x) s =
      filter (\<lambda>x. s ! i \<le> x) (take i s) @ filter (\<lambda>x. s ! i \<le> x) (drop i s)"
    by (simp flip: filter_append)
  show ?thesis by (simp add: e f1)
qed

lemma avg_ge: "(a::rat) \<le> b \<Longrightarrow> a \<le> (a + b) / 2"
  by (simp add: field_simps)

lemma avg_le: "(a::rat) \<le> b \<Longrightarrow> (a + b) / 2 \<le> b"
  by (simp add: field_simps)

lemma avg_between: "(a::rat) \<le> p \<Longrightarrow> p \<le> b \<Longrightarrow> a \<le> q \<Longrightarrow> q \<le> b \<Longrightarrow> a \<le> (p + q) / 2 \<and> (p + q) / 2 \<le> b"
  by (simp add: field_simps)

lemma median_core:
  assumes s: "sorted s" and ne: "s \<noteq> []"
  shows "length s \<le> 2 * length (filter (\<lambda>x. x \<le> smed_sorted s) s)"
    and "length s \<le> 2 * length (filter (\<lambda>x. smed_sorted s \<le> x) s)"
proof -
  have n0: "0 < length s" using ne by simp
  show "length s \<le> 2 * length (filter (\<lambda>x. x \<le> smed_sorted s) s)"
  proof (cases "length s mod 2 = 1")
    case True
    then have m: "smed_sorted s = s ! (length s div 2)" by (simp add: smed_sorted_def)
    have i: "length s div 2 < length s" using n0 by arith
    from sorted_count_le[OF s i]
    have "length s div 2 + 1 \<le> length (filter (\<lambda>x. x \<le> s ! (length s div 2)) s)" .
    then show ?thesis unfolding m using True by arith
  next
    case False
    then have ev: "length s mod 2 = 0" by arith
    have m: "smed_sorted s = (s ! (length s div 2 - 1) + s ! (length s div 2)) / 2"
      using False by (simp add: smed_sorted_def)
    have h1: "length s div 2 - 1 < length s" using n0 by arith
    have h2: "length s div 2 < length s" using n0 by arith
    have mono: "s ! (length s div 2 - 1) \<le> s ! (length s div 2)"
      by (rule sorted_nth_mono[OF s _ h2]) simp
    have low: "s ! (length s div 2 - 1) \<le> smed_sorted s" unfolding m by (rule avg_ge[OF mono])
    have c: "length s div 2 - 1 + 1 \<le> length (filter (\<lambda>x. x \<le> s ! (length s div 2 - 1)) s)"
      by (rule sorted_count_le[OF s h1])
    have "length (filter (\<lambda>x. x \<le> s ! (length s div 2 - 1)) s) \<le> length (filter (\<lambda>x. x \<le> smed_sorted s) s)"
      by (rule length_filter_mono) (use low in \<open>auto intro: order_trans\<close>)
    then show ?thesis using c ev n0 by arith
  qed
  show "length s \<le> 2 * length (filter (\<lambda>x. smed_sorted s \<le> x) s)"
  proof (cases "length s mod 2 = 1")
    case True
    then have m: "smed_sorted s = s ! (length s div 2)" by (simp add: smed_sorted_def)
    have i: "length s div 2 < length s" using n0 by arith
    from sorted_count_ge[OF s i]
    have "length s - length s div 2 \<le> length (filter (\<lambda>x. s ! (length s div 2) \<le> x) s)" .
    then show ?thesis unfolding m using True by arith
  next
    case False
    then have ev: "length s mod 2 = 0" by arith
    have m: "smed_sorted s = (s ! (length s div 2 - 1) + s ! (length s div 2)) / 2"
      using False by (simp add: smed_sorted_def)
    have h1: "length s div 2 - 1 < length s" using n0 by arith
    have h2: "length s div 2 < length s" using n0 by arith
    have mono: "s ! (length s div 2 - 1) \<le> s ! (length s div 2)"
      by (rule sorted_nth_mono[OF s _ h2]) simp
    have up: "smed_sorted s \<le> s ! (length s div 2)" unfolding m by (rule avg_le[OF mono])
    have c: "length s - length s div 2 \<le> length (filter (\<lambda>x. s ! (length s div 2) \<le> x) s)"
      by (rule sorted_count_ge[OF s h2])
    have "length (filter (\<lambda>x. s ! (length s div 2) \<le> x) s) \<le> length (filter (\<lambda>x. smed_sorted s \<le> x) s)"
      by (rule length_filter_mono) (use up in \<open>auto intro: order_trans\<close>)
    then show ?thesis using c ev n0 by arith
  qed
qed

text \<open>The median has at least half of the data at or below it and at least half
at or above it.\<close>
theorem median_halves:
  assumes "xs \<noteq> []"
  shows "length xs \<le> 2 * length (filter (\<lambda>x. x \<le> smedian xs) xs)"
    and "length xs \<le> 2 * length (filter (\<lambda>x. smedian xs \<le> x) xs)"
proof -
  have s: "sorted (sort xs)" by simp
  have ne: "sort xs \<noteq> []" by (metis assms length_0_conv length_sort)
  have e1: "length (filter (\<lambda>x. x \<le> smedian xs) xs) = length (filter (\<lambda>x. x \<le> smedian xs) (sort xs))"
    by (rule length_filter_perm)
  have e2: "length (filter (\<lambda>x. smedian xs \<le> x) xs) = length (filter (\<lambda>x. smedian xs \<le> x) (sort xs))"
    by (rule length_filter_perm)
  have h1: "length xs \<le> 2 * length (filter (\<lambda>x. x \<le> smedian xs) (sort xs))"
    using median_core(1)[OF s ne] by (simp add: smedian_def)
  have h2: "length xs \<le> 2 * length (filter (\<lambda>x. smedian xs \<le> x) (sort xs))"
    using median_core(2)[OF s ne] by (simp add: smedian_def)
  show "length xs \<le> 2 * length (filter (\<lambda>x. x \<le> smedian xs) xs)" using h1 e1 by simp
  show "length xs \<le> 2 * length (filter (\<lambda>x. smedian xs \<le> x) xs)" using h2 e2 by simp
qed

lemma sort_perm:
  assumes "mset xs = mset ys"
  shows "sort xs = sort ys"
proof (rule properties_for_sort)
  show "mset (sort ys) = mset xs" using assms by simp
  show "sorted (sort ys)" by simp
qed

text \<open>The median does not depend on the order of the data.\<close>
theorem median_order_free:
  assumes "mset xs = mset ys"
  shows "smedian xs = smedian ys"
  unfolding smedian_def using sort_perm[OF assms] by simp

lemma smed_sorted_in_range:
  assumes "set s \<subseteq> {a..b}" "s \<noteq> []"
  shows "a \<le> smed_sorted s \<and> smed_sorted s \<le> b"
proof -
  have n0: "0 < length s" using assms(2) by simp
  show ?thesis
  proof (cases "length s mod 2 = 1")
    case True
    have "length s div 2 < length s" using n0 by arith
    then have "s ! (length s div 2) \<in> set s" by simp
    then have "s ! (length s div 2) \<in> {a..b}" using assms(1) by blast
    then show ?thesis using True by (simp add: smed_sorted_def)
  next
    case False
    have h1: "length s div 2 - 1 < length s" and h2: "length s div 2 < length s" using n0 by arith+
    then have "s ! (length s div 2 - 1) \<in> set s" "s ! (length s div 2) \<in> set s" by simp_all
    then have b: "a \<le> s ! (length s div 2 - 1)" "s ! (length s div 2 - 1) \<le> b"
      "a \<le> s ! (length s div 2)" "s ! (length s div 2) \<le> b" using assms(1) by auto
    have m: "smed_sorted s = (s ! (length s div 2 - 1) + s ! (length s div 2)) / 2"
      using False by (simp add: smed_sorted_def)
    show ?thesis unfolding m by (rule avg_between[OF b(1) b(2) b(3) b(4)])
  qed
qed

subsection \<open>Range\<close>

lemma fold_max_ge: "x \<le> fold max (xs::rat list) x"
proof (induct xs arbitrary: x)
  case Nil show ?case by simp
next
  case (Cons y ys)
  have "x \<le> max y x" by simp
  also have "max y x \<le> fold max ys (max y x)" by (rule Cons.hyps)
  finally show ?case by simp
qed

lemma fold_max_ge_elem: "y \<in> set (xs::rat list) \<Longrightarrow> y \<le> fold max xs x"
proof (induct xs arbitrary: x)
  case Nil then show ?case by simp
next
  case (Cons z zs)
  show ?case
  proof (cases "y = z")
    case True
    have "z \<le> max z x" by simp
    also have "max z x \<le> fold max zs (max z x)" by (rule fold_max_ge)
    finally show ?thesis using True by simp
  next
    case False
    then have "y \<in> set zs" using Cons.prems by simp
    then show ?thesis using Cons.hyps by simp
  qed
qed

lemma fold_max_mem: "fold max (xs::rat list) x \<in> insert x (set xs)"
proof (induct xs arbitrary: x)
  case Nil show ?case by simp
next
  case (Cons y ys)
  have "fold max ys (max y x) \<in> insert (max y x) (set ys)" by (rule Cons.hyps)
  moreover have "max y x = x \<or> max y x = y" by (simp add: max_def)
  ultimately show ?case by auto
qed

lemma fold_min_le: "fold min (xs::rat list) x \<le> x"
proof (induct xs arbitrary: x)
  case Nil show ?case by simp
next
  case (Cons y ys)
  have "fold min ys (min y x) \<le> min y x" by (rule Cons.hyps)
  also have "min y x \<le> x" by simp
  finally show ?case by simp
qed

lemma fold_min_le_elem: "y \<in> set (xs::rat list) \<Longrightarrow> fold min xs x \<le> y"
proof (induct xs arbitrary: x)
  case Nil then show ?case by simp
next
  case (Cons z zs)
  show ?case
  proof (cases "y = z")
    case True
    have "fold min zs (min z x) \<le> min z x" by (rule fold_min_le)
    also have "min z x \<le> z" by simp
    finally show ?thesis using True by simp
  next
    case False
    then have "y \<in> set zs" using Cons.prems by simp
    then show ?thesis using Cons.hyps by simp
  qed
qed

lemma fold_min_mem: "fold min (xs::rat list) x \<in> insert x (set xs)"
proof (induct xs arbitrary: x)
  case Nil show ?case by simp
next
  case (Cons y ys)
  have "fold min ys (min y x) \<in> insert (min y x) (set ys)" by (rule Cons.hyps)
  moreover have "min y x = x \<or> min y x = y" by (simp add: min_def)
  ultimately show ?case by auto
qed

lemma lmax_ge: "x \<in> set xs \<Longrightarrow> x \<le> lmax xs"
  by (cases xs) (auto simp: fold_max_ge fold_max_ge_elem)

lemma lmin_le: "x \<in> set xs \<Longrightarrow> lmin xs \<le> x"
  by (cases xs) (auto simp: fold_min_le fold_min_le_elem)

lemma lmax_mem: "xs \<noteq> [] \<Longrightarrow> lmax xs \<in> set xs"
  by (cases xs) (use fold_max_mem in auto)

lemma lmin_mem: "xs \<noteq> [] \<Longrightarrow> lmin xs \<in> set xs"
  by (cases xs) (use fold_min_mem in auto)

theorem range_value:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_range xs) = SRat SK_range (srange xs) \<and> srange xs = lmax xs - lmin xs \<and>
         lmax xs \<in> set xs \<and> lmin xs \<in> set xs \<and> (\<forall>x\<in>set xs. lmin xs \<le> x \<and> x \<le> lmax xs)"
  using assms lmax_ge lmin_le lmax_mem lmin_mem by (auto simp: s_kernel_def s_answer_def srange_def)

theorem median_between_extremes:
  assumes "xs \<noteq> []"
  shows "lmin xs \<le> smedian xs \<and> smedian xs \<le> lmax xs"
proof -
  have sub: "set (sort xs) \<subseteq> {lmin xs..lmax xs}" using lmax_ge lmin_le by auto
  have "sort xs \<noteq> []" by (metis assms length_0_conv length_sort)
  from smed_sorted_in_range[OF sub this] show ?thesis by (simp add: smedian_def)
qed

theorem median_value:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_median xs v) = SRat SK_median (smedian xs)"
  using assms by (simp add: s_kernel_def s_answer_def)

subsection \<open>Mode\<close>

lemma foldr_max_ge: "y \<in> set l \<Longrightarrow> y \<le> foldr max l (0::nat)"
  by (induct l) auto

text \<open>Every mode is a data value that occurs at least as often as any
value.\<close>
theorem modes_value:
  assumes "x \<in> set (smodes xs)"
  shows "x \<in> set xs \<and> (\<forall>y. count_list xs y \<le> count_list xs x)"
proof -
  have sd: "set (sdistinct xs) = set xs" by (simp add: sdistinct_def)
  have mem: "x \<in> set (sdistinct xs)" and cx: "count_list xs x = smaxcount xs"
    using assms by (simp_all add: smodes_def)
  have xin: "x \<in> set xs" using mem sd by simp
  show ?thesis
  proof (intro conjI allI)
    show "x \<in> set xs" by (rule xin)
    fix y
    show "count_list xs y \<le> count_list xs x"
    proof (cases "y \<in> set xs")
      case True
      then have "y \<in> set (sdistinct xs)" using sd by simp
      then have "count_list xs y \<in> set (map (count_list xs) (sdistinct xs))" by simp
      from foldr_max_ge[OF this] show ?thesis using cx by (simp add: smaxcount_def)
    next
      case False
      then have "count_list xs y = 0" by (simp add: count_list_0_iff)
      then show ?thesis by simp
    qed
  qed
qed

theorem mode_value:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_mode xs) = (if length (smodes xs) = length xs then SNoMode else SModes (smodes xs))"
  using assms by (simp add: s_kernel_def s_answer_def)

subsection \<open>Counting, the binomial and the z-score\<close>

lemma scomb_eq:
  assumes k: "k \<le> n"
  shows "scomb n k = n choose k"
proof -
  have D: "fact k * fact (n - k) \<noteq> (0::nat)" by simp
  have e: "(fact n :: nat) = fact k * fact (n - k) * (n choose k)" by (rule binomial_fact_lemma[OF k, symmetric])
  show ?thesis unfolding scomb_def by (subst e) (use D in simp)
qed

theorem choose_value:
  assumes "k \<le> n" "n \<le> slimit"
  shows "s_kernel (S_choose n k v) = SCount SK_combinations (scomb n k) \<and>
         scomb n k = n choose k \<and> fact k * fact (n - k) * scomb n k = fact n"
proof -
  have c: "scomb n k = n choose k" by (rule scomb_eq[OF assms(1)])
  have f: "fact k * fact (n - k) * scomb n k = fact n" using c binomial_fact_lemma[OF assms(1)] by simp
  have "\<not> slimit < n" "\<not> n < k" using assms by simp_all
  then show ?thesis using c f by (simp add: s_kernel_def s_answer_def)
qed

theorem arrange_value:
  assumes "k \<le> n" "n \<le> slimit"
  shows "s_kernel (S_arrange n (Some k) v) = SCount SK_permutations (sperm n k) \<and>
         sperm n k * fact (n - k) = fact n"
proof -
  have e: "(fact n :: nat) = fact k * fact (n - k) * (n choose k)" by (rule binomial_fact_lemma[OF assms(1), symmetric])
  have "(fact n :: nat) = fact (n - k) * (fact k * (n choose k))" using e by (simp add: ac_simps)
  then have d: "(fact (n - k) :: nat) dvd fact n" by (rule dvdI)
  have "sperm n k * fact (n - k) = fact n" unfolding sperm_def by (rule dvd_div_mult_self[OF d])
  moreover have "\<not> slimit < n" "\<not> n < k" using assms by simp_all
  ultimately show ?thesis by (simp add: s_kernel_def s_answer_def)
qed

theorem arrange_all_value:
  assumes "n \<le> slimit"
  shows "s_kernel (S_arrange n None v) = SCount SK_permutations (fact n)"
  using assms by (simp add: s_kernel_def s_answer_def)

theorem binomial_value:
  assumes "k \<le> n" "n \<le> slimit" "0 \<le> p" "p \<le> 1"
  shows "s_kernel (S_binom k n p v) = SRat SK_binomial (of_nat (n choose k) * p ^ k * (1 - p) ^ (n - k))"
proof -
  have "\<not> slimit < n" "\<not> p < 0" "\<not> 1 < p" "\<not> n < k" using assms by simp_all
  then show ?thesis using scomb_eq[OF assms(1)] by (simp add: s_kernel_def s_answer_def sbinom_def)
qed

theorem z_value:
  assumes "0 < sd"
  shows "s_kernel (S_z x mu sd) = SRat SK_z ((x - mu) / sd) \<and> (x - mu) / sd * sd = x - mu"
proof (intro conjI)
  have nz: "sd \<noteq> 0" using assms by simp
  show "s_kernel (S_z x mu sd) = SRat SK_z ((x - mu) / sd)"
    using assms by (simp add: s_kernel_def s_answer_def)
  show "(x - mu) / sd * sd = x - mu" using nz by (simp add: divide_simps)
qed


section \<open>Response text (ASCII)\<close>

fun join_f4 :: "rat list \<Rightarrow> String.literal" where
  "join_f4 [] = STR ''''"
| "join_f4 [x] = f4 x"
| "join_f4 (x # y # zs) = f4 x + STR '', '' + join_f4 (y # zs)"

fun join_and :: "rat list \<Rightarrow> String.literal" where
  "join_and [] = STR ''''"
| "join_and [x] = f4 x"
| "join_and (x # y # zs) = f4 x + STR '' and '' + join_and (y # zs)"

definition exact_note :: "bool \<Rightarrow> rat \<Rightarrow> String.literal" where
  "exact_note b q = (case quotient_of q of (a, d) \<Rightarrow>
     if b \<and> d \<noteq> 1 then STR '' (exactly '' + show_int a + STR ''/'' + show_int d + STR '')'' else STR '''')"

definition pop_name :: "bool \<Rightarrow> String.literal" where
  "pop_name pop = (if pop then STR ''population'' else STR ''sample'')"

definition pop_rule :: "bool \<Rightarrow> String.literal" where
  "pop_rule pop = (if pop then STR ''divides by n''
     else STR ''divides by n-1; say '' + apos + STR ''population'' + apos + STR '' for n'')"

definition ni :: "nat \<Rightarrow> String.literal" where "ni n = show_int (int n)"

fun stext :: "srequest \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "stext (S_mean xs b) V = STR ''The mean of '' + join_f4 xs + STR '' is '' + V + STR '' (sum '' + f4 (sum_list xs)
     + STR '' / '' + ni (length xs) + STR '')'' + exact_note b (smean xs) + STR ''.''"
| "stext (S_median xs b) V = STR ''The median of '' + join_f4 xs + STR '' is '' + V
     + exact_note b (smedian xs) + STR ''.''"
| "stext (S_mode xs) V = STR ''The mode of '' + join_f4 xs + STR '' is '' + V + STR ''.''"
| "stext (S_range xs) V = STR ''The range of '' + join_f4 xs + STR '' is '' + V + STR '' ('' + f4 (lmax xs)
     + STR '' - '' + f4 (lmin xs) + STR '').''"
| "stext (S_variance pop xs) V = STR ''The '' + pop_name pop + STR '' variance of '' + join_f4 xs + STR '' is '' + V
     + STR '' ('' + pop_rule pop + STR '').''"
| "stext (S_stdev pop xs) V = STR ''The '' + pop_name pop + STR '' standard deviation of '' + join_f4 xs + STR '' is '' + V
     + STR '' ('' + pop_rule pop + STR '').''"
| "stext (S_choose n k nw) V = (if nw
     then STR ''There are '' + V + STR '' combinations. That is C('' + ni n + STR '', '' + ni k + STR '') = '' + ni n
       + STR ''!/('' + ni k + STR ''!*'' + ni (n - k) + STR ''!), the ways to choose '' + ni k + STR '' from '' + ni n + STR ''.''
     else STR ''There are '' + V + STR '' ways to choose '' + ni k + STR '' from '' + ni n + STR '' (C('' + ni n + STR '', ''
       + ni k + STR '') = '' + ni n + STR ''!/('' + ni k + STR ''!*'' + ni (n - k) + STR ''!)).'')"
| "stext (S_arrange n k nw) V = (if nw
     then STR ''There are '' + V + STR '' arrangements. That is ''
       + (case k of None \<Rightarrow> ni n + STR ''!''
          | Some k \<Rightarrow> STR ''P('' + ni n + STR '', '' + ni k + STR '') = '' + ni n + STR ''!/'' + ni (n - k) + STR ''!'')
       + STR '', ordered.''
     else STR ''There are '' + V + STR '' ordered arrangements (''
       + (case k of None \<Rightarrow> ni n + STR ''!'' | Some k \<Rightarrow> STR ''P('' + ni n + STR '', '' + ni k + STR '')'') + STR '').'')"
| "stext (S_binom k n p nw) V = (if nw
     then STR ''P(X = '' + ni k + STR '') = '' + V + STR '' for n = '' + ni n + STR '' trials with p = '' + show6 p
       + STR '' (C('' + ni n + STR '', '' + ni k + STR '') p^'' + ni k + STR '' (1 - p)^'' + ni (n - k) + STR '').''
     else STR ''P(X = '' + ni k + STR '') = '' + V + STR '' for '' + ni n + STR '' trials with p = '' + show6 p
       + STR '' (C('' + ni n + STR '','' + ni k + STR '') * p^'' + ni k + STR '' * (1-p)^'' + ni (n - k) + STR '').'')"
| "stext (S_z x mu sd) V = STR ''The z-score is '' + V + STR '' ((x - mu)/sigma = ('' + f4 x + STR '' - '' + f4 mu
     + STR '')/'' + f4 sd + STR '').''"

definition skind_name :: "skind \<Rightarrow> String.literal" where
  "skind_name k = (case k of SK_mean \<Rightarrow> STR ''mean'' | SK_median \<Rightarrow> STR ''median'' | SK_mode \<Rightarrow> STR ''mode''
     | SK_range \<Rightarrow> STR ''range'' | SK_stdev \<Rightarrow> STR ''stdev'' | SK_variance \<Rightarrow> STR ''variance''
     | SK_combinations \<Rightarrow> STR ''combinations'' | SK_permutations \<Rightarrow> STR ''permutations''
     | SK_binomial \<Rightarrow> STR ''binomial'' | SK_z \<Rightarrow> STR ''z'')"

definition sdecline_name :: "sdecline \<Rightarrow> String.literal" where
  "sdecline_name w = (case w of SNoData \<Rightarrow> STR ''underspecified'' | STooFew \<Rightarrow> STR ''too_few''
     | SImpossible _ \<Rightarrow> STR ''impossible'' | SImprecise \<Rightarrow> STR ''imprecise'')"

definition sdecline_text :: "srequest \<Rightarrow> sdecline \<Rightarrow> String.literal" where
  "sdecline_text r w = (case w of
       SNoData \<Rightarrow> STR ''I need some numbers to compute that; I won'' + apos + STR ''t assume any.''
     | STooFew \<Rightarrow> STR ''A sample '' + (case r of S_stdev _ _ \<Rightarrow> STR ''standard deviation'' | _ \<Rightarrow> STR ''variance'')
         + STR '' needs at least two values.''
     | SImpossible why \<Rightarrow> (case why of
           SR_choose_k_gt_n \<Rightarrow> (case r of
               S_choose n k _ \<Rightarrow> STR ''You can'' + apos + STR ''t choose '' + ni k + STR '' from only '' + ni n
                 + STR ''; there are no such selections.''
             | _ \<Rightarrow> STR ''You can'' + apos + STR ''t choose more than there are.'')
         | SR_arrange_k_gt_n \<Rightarrow> (case r of
               S_arrange n (Some k) _ \<Rightarrow> STR ''You can'' + apos + STR ''t arrange '' + ni k + STR '' from only '' + ni n
                 + STR ''; there are no such arrangements.''
             | _ \<Rightarrow> STR ''You can'' + apos + STR ''t arrange more than there are.'')
         | SR_binomial_setup \<Rightarrow> STR ''That isn'' + apos + STR ''t a valid binomial setup (need 0 <= p <= 1 and k <= n).''
         | SR_nonpositive_sd \<Rightarrow> STR ''A standard deviation must be positive, so there'' + apos + STR ''s no z-score.''
         | SR_too_large \<Rightarrow> STR ''That count is too large for this binary; I won'' + apos + STR ''t guess.'')
     | SImprecise \<Rightarrow> STR ''The interval arithmetic could not pin four decimals; I won'' + apos + STR ''t guess.'')"

definition s_rat_lit :: "skind \<Rightarrow> rat \<Rightarrow> String.literal option" where
  "s_rat_lit k q = (if k = SK_binomial then map_option (render_dec 6) (round_sig 6 (rl q)) else Some (f4 q))"

definition no_mode_text :: "srequest \<Rightarrow> String.literal" where
  "no_mode_text r = (case r of S_mode xs \<Rightarrow> STR ''Every value in '' + join_f4 xs
       + STR '' appears once, so there is no single mode.''
     | _ \<Rightarrow> STR ''There is no single mode.'')"

definition s_reply :: "srequest \<Rightarrow> reply" where
  "s_reply r = (case s_kernel r of
       SRat k q \<Rightarrow> (case s_rat_lit k q of
           None \<Rightarrow> Reply False (STR ''imprecise'') (sdecline_text r SImprecise) None
         | Some v \<Rightarrow> Reply True (skind_name k) (stext r v) (Some v))
     | SApprox k m \<Rightarrow> Reply True (skind_name k) (stext r (f4_dec m)) (Some (f4_dec m))
     | SCount k n \<Rightarrow> Reply True (skind_name k) (stext r (ni n)) (Some (ni n))
     | SModes ms \<Rightarrow> Reply True (STR ''mode'') (stext r (join_and ms)) (Some (f4 (hd ms)))
     | SNoMode \<Rightarrow> Reply True (STR ''mode'') (no_mode_text r) None
     | SDecline w \<Rightarrow> Reply False (sdecline_name w) (sdecline_text r w) None)"

theorem s_reply_answered_iff:
  "answered (s_reply r) \<longleftrightarrow>
     (\<exists>k q v. s_kernel r = SRat k q \<and> s_rat_lit k q = Some v) \<or> (\<exists>k m. s_kernel r = SApprox k m) \<or>
     (\<exists>k n. s_kernel r = SCount k n) \<or> (\<exists>ms. s_kernel r = SModes ms) \<or> s_kernel r = SNoMode"
  by (auto simp: s_reply_def split: soutcome.splits option.splits)

theorem s_reply_withheld_names_decline:
  "s_kernel r = SDecline w \<Longrightarrow> \<not> answered (s_reply r) \<and> reply_kind (s_reply r) = sdecline_name w"
  by (simp add: s_reply_def)

theorem s_reply_states_approx:
  "s_kernel r = SApprox k m \<Longrightarrow> stated (s_reply r) = Some (f4_dec m)"
  by (simp add: s_reply_def)

theorem s_reply_states_rat:
  "s_kernel r = SRat k q \<Longrightarrow> s_rat_lit k q = Some v \<Longrightarrow> stated (s_reply r) = Some v"
  by (simp add: s_reply_def)

end
