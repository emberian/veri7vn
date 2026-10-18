theory Genetics
  imports Life_Core
begin

text \<open>
  Lane S09-life, genetics-v2 (upstream/root/specialists/genetics-v2/organ_genetics_v{1,2}.py).
  Mendelian crosses by enumeration of gametes (complete dominance, independent
  loci) and Hardy-Weinberg frequencies. A locus is the dominant and recessive
  letter (for display only) and the parent's zygosity.
\<close>

datatype zyg = Hom_dom | Het | Hom_rec

datatype locus = Locus String.literal String.literal zyg

fun locus_zyg :: "locus \<Rightarrow> zyg" where "locus_zyg (Locus u l z) = z"

fun gam :: "zyg \<Rightarrow> bool list" where
  "gam Hom_dom = [True, True]"
| "gam Het = [True, False]"
| "gam Hom_rec = [False, False]"

fun child :: "bool \<Rightarrow> bool \<Rightarrow> zyg" where
  "child True True = Hom_dom"
| "child False False = Hom_rec"
| "child a b = Het"

text \<open>The four equally likely children of one locus (the Punnett square).\<close>
definition kids1 :: "zyg \<Rightarrow> zyg \<Rightarrow> zyg list" where
  "kids1 z1 z2 = concat (map (\<lambda>a. map (\<lambda>b. child a b) (gam z2)) (gam z1))"

definition cnt1 :: "zyg \<Rightarrow> zyg \<Rightarrow> zyg \<Rightarrow> nat" where
  "cnt1 z1 z2 w = length (filter (\<lambda>x. x = w) (kids1 z1 z2))"

fun dcount :: "zyg \<Rightarrow> nat" where
  "dcount Hom_dom = 2" | "dcount Het = 1" | "dcount Hom_rec = 0"

text \<open>The Punnett square agrees with the gamete frequencies: a child is
homozygous dominant exactly when both gametes carry the dominant allele.\<close>
theorem punnett_closed:
  "cnt1 z1 z2 Hom_dom = dcount z1 * dcount z2
   \<and> cnt1 z1 z2 Hom_rec = (2 - dcount z1) * (2 - dcount z2)
   \<and> cnt1 z1 z2 Het = dcount z1 * (2 - dcount z2) + (2 - dcount z1) * dcount z2"
  by (cases z1; cases z2) (simp_all add: cnt1_def kids1_def)

theorem punnett_total: "cnt1 z1 z2 Hom_dom + cnt1 z1 z2 Het + cnt1 z1 z2 Hom_rec = 4"
  by (cases z1; cases z2) (simp_all add: cnt1_def kids1_def)

section \<open>Several loci\<close>

text \<open>Probability that a cross gives the wanted genotype at every locus
(independent assortment: the product over loci).\<close>
fun gprob :: "(locus \<times> locus \<times> zyg) list \<Rightarrow> rat" where
  "gprob [] = 1"
| "gprob ((a, b, w) # r) = of_nat (cnt1 (locus_zyg a) (locus_zyg b) w) / 4 * gprob r"

theorem gprob_total_one_locus:
  "gprob [(a, b, Hom_dom)] + gprob [(a, b, Het)] + gprob [(a, b, Hom_rec)] = 1"
proof -
  have t: "cnt1 (locus_zyg a) (locus_zyg b) Hom_dom + cnt1 (locus_zyg a) (locus_zyg b) Het
         + cnt1 (locus_zyg a) (locus_zyg b) Hom_rec = 4" by (rule punnett_total)
  have s: "(of_nat (cnt1 (locus_zyg a) (locus_zyg b) Hom_dom) + of_nat (cnt1 (locus_zyg a) (locus_zyg b) Het)
         + of_nat (cnt1 (locus_zyg a) (locus_zyg b) Hom_rec) :: rat) = 4"
    using arg_cong[OF t, of "of_nat :: nat \<Rightarrow> rat"] by (simp only: of_nat_add of_nat_numeral)
  show ?thesis unfolding gprob.simps using s by linarith
qed

fun gcount :: "(locus \<times> locus) list \<Rightarrow> nat" where
  "gcount [] = 1" | "gcount (x # r) = 4 * gcount r"

text \<open>Phenotype counts (out of four) of one locus: dominant and recessive.\<close>
definition pcnt :: "locus \<times> locus \<Rightarrow> nat \<times> nat" where
  "pcnt x = (case x of (a, b) \<Rightarrow>
     (cnt1 (locus_zyg a) (locus_zyg b) Hom_dom + cnt1 (locus_zyg a) (locus_zyg b) Het,
      cnt1 (locus_zyg a) (locus_zyg b) Hom_rec))"

fun pclasses :: "(nat \<times> nat) list \<Rightarrow> nat list" where
  "pclasses [] = [1]"
| "pclasses ((a, b) # r) = map (\<lambda>x. a * x) (pclasses r) @ map (\<lambda>x. b * x) (pclasses r)"

lemma sl_map_mult: "sum_list (map (\<lambda>x. a * x) xs) = (a::nat) * sum_list xs"
  by (induct xs) (simp_all add: algebra_simps)

theorem pclasses_sum:
  "sum_list (pclasses ls) = prod_list (map (\<lambda>x. fst x + snd x) ls)"
proof (induct ls)
  case Nil
  then show ?case by simp
next
  case (Cons x ls)
  obtain a b where x: "x = (a, b)" by (cases x)
  show ?case using Cons by (simp add: x sl_map_mult algebra_simps)
qed

lemma pcnt_sum: "fst (pcnt x) + snd (pcnt x) = 4"
proof -
  obtain a b where x: "x = (a, b)" by (cases x)
  show ?thesis using punnett_total[of "locus_zyg a" "locus_zyg b"] by (simp add: x pcnt_def)
qed

definition ratio_of :: "nat list \<Rightarrow> nat list" where
  "ratio_of cs = (let cs' = filter (\<lambda>x. 0 < x) cs; g = fold gcd cs' 0 in map (\<lambda>x. x div g) cs')"

lemma fold_gcd_dvd: "fold gcd xs (a::nat) dvd a \<and> (\<forall>x\<in>set xs. fold gcd xs a dvd x)"
proof (induct xs arbitrary: a)
  case Nil
  then show ?case by simp
next
  case (Cons y ys)
  have ih: "fold gcd ys (gcd y a) dvd gcd y a \<and> (\<forall>x\<in>set ys. fold gcd ys (gcd y a) dvd x)"
    using Cons by blast
  have da: "fold gcd ys (gcd y a) dvd a" using dvd_trans[OF conjunct1[OF ih] gcd_dvd2] .
  have dy: "fold gcd ys (gcd y a) dvd y" using dvd_trans[OF conjunct1[OF ih] gcd_dvd1] .
  show ?case using da dy conjunct2[OF ih] by simp
qed

text \<open>A ratio is the positive class counts divided by their common divisor.\<close>
theorem ratio_proportional:
  assumes "filter (\<lambda>x. 0 < x) cs \<noteq> []"
  shows "\<exists>g>0. map (\<lambda>x. g * x) (ratio_of cs) = filter (\<lambda>x. 0 < x) cs"
proof -
  define cs' where "cs' = filter (\<lambda>x. 0 < x) cs"
  define g where "g = fold gcd cs' 0"
  have dv: "\<forall>x\<in>set cs'. g dvd x" using fold_gcd_dvd[of cs' 0] by (simp add: g_def)
  have ne: "cs' \<noteq> []" using assms by (simp add: cs'_def)
  define x0 where "x0 = hd cs'"
  have x0: "x0 \<in> set cs'" using ne by (simp add: x0_def)
  have pos: "\<forall>x\<in>set cs'. 0 < x" by (simp add: cs'_def)
  have gpos: "0 < g"
  proof (rule ccontr)
    assume "\<not> 0 < g"
    then have g0: "g = 0" by simp
    have "g dvd x0" using dv x0 by blast
    then have "x0 = 0" using g0 by simp
    then show False using pos x0 by auto
  qed
  have "map (\<lambda>x. g * x) (map (\<lambda>x. x div g) cs') = cs'"
  proof -
    have "map (\<lambda>x. g * x) (map (\<lambda>x. x div g) cs') = map (\<lambda>x. g * (x div g)) cs'"
      by (simp add: comp_def)
    also have "\<dots> = map id cs'"
      by (rule map_cong[OF refl]) (use dv in \<open>auto simp: dvd_mult_div_cancel\<close>)
    finally show ?thesis by simp
  qed
  then show ?thesis using gpos by (auto simp: ratio_of_def Let_def cs'_def g_def)
qed


section \<open>Hardy-Weinberg\<close>

datatype hwk = HK_carrier | HK_p2 | HK_p | HK_q

text \<open>What the question gave: q squared (a share of the population showing the
recessive phenotype), "1 in N", q itself, or p.\<close>
datatype hwsrc = HWq2 rat | HWone nat | HWqs rat | HWps rat

fun hw_q :: "hwsrc \<Rightarrow> real" where
  "hw_q (HWq2 v) = sqrt (rl v)"
| "hw_q (HWone n) = sqrt (inverse (real n))"
| "hw_q (HWqs q) = rl q"
| "hw_q (HWps p) = 1 - rl p"

fun hw_f :: "hwk \<Rightarrow> real \<Rightarrow> real" where
  "hw_f HK_carrier q = 2 * (1 - q) * q"
| "hw_f HK_p2 q = (1 - q) * (1 - q)"
| "hw_f HK_p q = 1 - q"
| "hw_f HK_q q = q"

fun hw_frat :: "hwk \<Rightarrow> rat \<Rightarrow> rat" where
  "hw_frat HK_carrier q = 2 * (1 - q) * q"
| "hw_frat HK_p2 q = (1 - q) * (1 - q)"
| "hw_frat HK_p q = 1 - q"
| "hw_frat HK_q q = q"

lemma hw_frat_rl: "rl (hw_frat k q) = hw_f k (rl q)"
  by (cases k) (simp_all add: of_rat_mult of_rat_diff)

theorem hw_sum_one: "hw_f HK_p2 q + hw_f HK_carrier q + q * q = 1"
  by (simp add: algebra_simps)

fun hw_bad :: "hwsrc \<Rightarrow> reason option" where
  "hw_bad (HWq2 v) = (if 0 \<le> v \<and> v \<le> 1 then None else Some R_freq)"
| "hw_bad (HWone n) = (if n = 0 then Some R_zero else None)"
| "hw_bad (HWqs q) = (if 0 \<le> q \<and> q \<le> 1 then None else Some R_freq)"
| "hw_bad (HWps p) = (if 0 \<le> p \<and> p \<le> 1 then None else Some R_freq)"

fun hwq_fa :: "hwsrc \<Rightarrow> floatarith" where
  "hwq_fa (HWq2 v) = floatarith.Sqrt (Q v)"
| "hwq_fa (HWone n) = floatarith.Sqrt (floatarith.Inverse (I (int n)))"
| "hwq_fa s = I 0"

lemma interp_hwq_fa [simp]:
  "interpret_floatarith (hwq_fa (HWq2 v)) xs = hw_q (HWq2 v)"
  "interpret_floatarith (hwq_fa (HWone n)) xs = hw_q (HWone n)"
  by (simp_all add: divide_inverse)

fun hw_fa :: "hwk \<Rightarrow> floatarith \<Rightarrow> floatarith" where
  "hw_fa HK_carrier e = floatarith.Mult (floatarith.Mult (I 2) (floatarith.Add (I 1) (floatarith.Minus e))) e"
| "hw_fa HK_p2 e = floatarith.Mult (floatarith.Add (I 1) (floatarith.Minus e)) (floatarith.Add (I 1) (floatarith.Minus e))"
| "hw_fa HK_p e = floatarith.Add (I 1) (floatarith.Minus e)"
| "hw_fa HK_q e = e"

lemma interp_hw_fa [simp]:
  "interpret_floatarith (hw_fa k e) xs = hw_f k (interpret_floatarith e xs)"
  by (cases k) simp_all

fun hw_kind :: "hwk \<Rightarrow> kind" where
  "hw_kind HK_carrier = STR ''hw_carrier''"
| "hw_kind HK_p2 = STR ''hw_p2''"
| "hw_kind HK_p = STR ''hw_p''"
| "hw_kind HK_q = STR ''hw_q''"

fun hw_answer :: "hwk \<Rightarrow> hwsrc \<Rightarrow> outcome" where
  "hw_answer k (HWq2 v) = approx_out (hw_kind k) (hw_fa k (hwq_fa (HWq2 v)))"
| "hw_answer k (HWone n) = approx_out (hw_kind k) (hw_fa k (hwq_fa (HWone n)))"
| "hw_answer k (HWqs q) = Exact (hw_kind k) (hw_frat k q)"
| "hw_answer k (HWps p) = Exact (hw_kind k) (hw_frat k (1 - p))"

lemma hw_answer_decline: "hw_answer k s = Decline w \<Longrightarrow> w = Imprecise"
  by (cases s) (auto dest: approx_out_decline)

section \<open>The kernel\<close>

datatype greq =
    G_Geno "(locus \<times> locus \<times> zyg) list"
  | G_Pheno bool locus locus
  | G_PRatio "(locus \<times> locus) list"
  | G_GRatio locus locus
  | G_HW hwk hwsrc
  | G_Need
  | G_Model

definition need_freq :: String.literal where
  "need_freq = STR ''I need a frequency (the recessive phenotype share, q, or p) to work that out; I won'' + apos + STR ''t assume one.''"

fun g_decline :: "greq \<Rightarrow> decline option" where
  "g_decline (G_HW k s) = (case hw_bad s of None \<Rightarrow> None | Some r \<Rightarrow> Some (Impossible r))"
| "g_decline G_Model = Some (Underspecified (STR ''This calculation assumes complete dominance and independent loci; it cannot determine linked, codominant or epistatic inheritance.''))"
| "g_decline G_Need = Some (Underspecified need_freq)"
| "g_decline r = None"

fun g_answer :: "greq \<Rightarrow> outcome" where
  "g_answer (G_Geno xs) = Exact (STR ''genotype_prob'') (gprob xs)"
| "g_answer (G_Pheno True a b) = Exact (STR ''phenotype_prob'') (of_nat (fst (pcnt (a, b))) / 4)"
| "g_answer (G_Pheno False a b) = Exact (STR ''phenotype_prob'') (of_nat (snd (pcnt (a, b))) / 4)"
| "g_answer (G_PRatio ls) = Ratio (STR ''pheno_ratio'') (ratio_of (pclasses (map pcnt ls)))"
| "g_answer (G_GRatio a b) =
     Ratio (STR ''geno_ratio'') (ratio_of (map (cnt1 (locus_zyg a) (locus_zyg b)) [Hom_dom, Het, Hom_rec]))"
| "g_answer (G_HW k s) = hw_answer k s"
| "g_answer G_Model = Decline Imprecise"
| "g_answer G_Need = Decline Imprecise"

definition g_kernel :: "greq \<Rightarrow> outcome" where
  "g_kernel r = (case g_decline r of Some w \<Rightarrow> Decline w | None \<Rightarrow> g_answer r)"

lemma g_kernel_hw:
  "g_kernel (G_HW k s) = (case hw_bad s of Some r \<Rightarrow> Decline (Impossible r) | None \<Rightarrow> hw_answer k s)"
  by (cases "hw_bad s") (simp_all add: g_kernel_def)

section \<open>Hardy-Weinberg declines stated apart from the code\<close>

lemma g_hw_decl: "g_kernel (G_HW k s) = Decline (Impossible w) \<longleftrightarrow> hw_bad s = Some w"
  by (cases "hw_bad s") (auto simp: g_kernel_hw dest: hw_answer_decline)

theorem hw_q2_declines_iff:
  "g_kernel (G_HW k (HWq2 v)) = Decline (Impossible R_freq) \<longleftrightarrow> v < 0 \<or> 1 < v"
  by (auto simp: g_hw_decl)

theorem hw_qs_declines_iff:
  "g_kernel (G_HW k (HWqs q)) = Decline (Impossible R_freq) \<longleftrightarrow> q < 0 \<or> 1 < q"
  by (auto simp: g_hw_decl)

theorem hw_ps_declines_iff:
  "g_kernel (G_HW k (HWps p)) = Decline (Impossible R_freq) \<longleftrightarrow> p < 0 \<or> 1 < p"
  by (auto simp: g_hw_decl)

theorem hw_one_declines_iff:
  "g_kernel (G_HW k (HWone n)) = Decline (Impossible R_zero) \<longleftrightarrow> n = 0"
  by (auto simp: g_hw_decl)

theorem geno_prob_value:
  "g_kernel (G_Geno xs) = Exact (STR ''genotype_prob'') (gprob xs)"
  by (simp add: g_kernel_def)

text \<open>Independent-locus composition is multiplication of the two already
checked probabilities; this is the assumption of the Mendelian model, not a
claim about arbitrary linked genes.\<close>
lemma gprob_append: "gprob (xs @ ys) = gprob xs * gprob ys"
  by (induct xs) (auto simp: algebra_simps split: prod.splits)

theorem genotype_independent_composition:
  assumes "g_kernel (G_Geno xs) = Exact k a"
    "g_kernel (G_Geno ys) = Exact k' b"
  shows "g_kernel (G_Geno (xs @ ys)) = Exact (STR ''genotype_prob'') (a * b)"
  using assms by (simp add: g_kernel_def gprob_append)

theorem pheno_prob_complement:
  "of_nat (fst (pcnt x)) / 4 + of_nat (snd (pcnt x)) / 4 = (1::rat)"
proof -
  have s: "(of_nat (fst (pcnt x)) + of_nat (snd (pcnt x)) :: rat) = 4"
    using arg_cong[OF pcnt_sum[of x], of "of_nat :: nat \<Rightarrow> rat"] by (simp only: of_nat_add of_nat_numeral)
  show ?thesis using s by linarith
qed

theorem pheno_prob_value:
  "g_kernel (G_Pheno True a b) = Exact (STR ''phenotype_prob'') (of_nat (fst (pcnt (a, b))) / 4)"
  "g_kernel (G_Pheno False a b) = Exact (STR ''phenotype_prob'') (of_nat (snd (pcnt (a, b))) / 4)"
  by (simp_all add: g_kernel_def)

theorem pheno_ratio_value:
  "g_kernel (G_PRatio ls) = Ratio (STR ''pheno_ratio'') (ratio_of (pclasses (map pcnt ls)))"
  by (simp add: g_kernel_def)

theorem geno_ratio_value:
  "g_kernel (G_GRatio a b) =
     Ratio (STR ''geno_ratio'') (ratio_of (map (cnt1 (locus_zyg a) (locus_zyg b)) [Hom_dom, Het, Hom_rec]))"
  by (simp add: g_kernel_def)

theorem hw_exact:
  assumes "g_kernel (G_HW k s) = Exact c y"
  shows "c = hw_kind k \<and> hw_bad s = None \<and> rl y = hw_f k (hw_q s)"
proof (cases "hw_bad s")
  case None
  then have a: "hw_answer k s = Exact c y" using assms by (simp add: g_kernel_hw)
  show ?thesis using a None by (cases s) (auto simp: hw_frat_rl of_rat_diff)
next
  case (Some r)
  then show ?thesis using assms by (simp add: g_kernel_hw)
qed

theorem hw_approx:
  assumes "g_kernel (G_HW k s) = Approx c d"
  shows "c = hw_kind k \<and> hw_bad s = None \<and>
         \<bar>dec_val d - hw_f k (hw_q s)\<bar> \<le> \<bar>hw_f k (hw_q s)\<bar> / 1000 + 1 / 1000000000"
proof (cases "hw_bad s")
  case None
  then have a: "hw_answer k s = Approx c d" using assms by (simp add: g_kernel_hw)
  show ?thesis
  proof (cases s)
    case (HWq2 v)
    have "\<forall>xs. interpret_floatarith (hw_fa k (hwq_fa (HWq2 v))) xs = hw_f k (hw_q (HWq2 v))" by simp
    from approx_out_phys[OF _ this] a HWq2 show ?thesis using None by simp
  next
    case (HWone n)
    have "\<forall>xs. interpret_floatarith (hw_fa k (hwq_fa (HWone n))) xs = hw_f k (hw_q (HWone n))" by simp
    from approx_out_phys[OF _ this] a HWone show ?thesis using None by simp
  next
    case (HWqs q) then show ?thesis using a by simp
  next
    case (HWps p) then show ?thesis using a by simp
  qed
next
  case (Some r)
  then show ?thesis using assms by (simp add: g_kernel_hw)
qed

theorem hw_impossible:
  "(\<exists>r. g_kernel (G_HW k s) = Decline (Impossible r)) \<longleftrightarrow> hw_bad s \<noteq> None"
proof (cases "hw_bad s")
  case None
  then show ?thesis by (auto simp: g_kernel_hw dest: hw_answer_decline)
next
  case (Some r)
  then show ?thesis by (auto simp: g_kernel_hw)
qed

theorem hw_imprecise:
  assumes "g_kernel (G_HW k s) = Decline Imprecise"
  shows "hw_bad s = None"
  using assms by (cases "hw_bad s") (simp_all add: g_kernel_hw)

theorem unsupported_model_declines:
  "\<exists>t. g_kernel G_Model = Decline (Underspecified t)"
  by (simp add: g_kernel_def)

theorem need_declines: "g_kernel G_Need = Decline (Underspecified need_freq)"
  by (simp add: g_kernel_def)

section \<open>Response text\<close>

fun zyg_lit :: "locus \<Rightarrow> String.literal" where
  "zyg_lit (Locus u l Hom_dom) = u + u"
| "zyg_lit (Locus u l Het) = u + l"
| "zyg_lit (Locus u l Hom_rec) = l + l"

definition geno_lit :: "locus list \<Rightarrow> String.literal" where
  "geno_lit xs = foldr (\<lambda>x s. zyg_lit x + s) xs (STR '''')"

fun t1 :: "locus \<times> locus \<times> zyg \<Rightarrow> locus" where "t1 (a, b, w) = a"
fun t2 :: "locus \<times> locus \<times> zyg \<Rightarrow> locus" where "t2 (a, b, w) = b"
fun tw :: "locus \<times> locus \<times> zyg \<Rightarrow> locus" where "tw (Locus u l z, b, w) = Locus u l w"

definition ptxt :: "outcome \<Rightarrow> String.literal" where
  "ptxt o' = (case o' of Exact _ q \<Rightarrow> fixed_lit 4 (q * 100)
     | Approx _ d \<Rightarrow> render_plain (fst d, snd d + 2) | _ \<Rightarrow> STR '''')"

fun hw_name :: "hwk \<Rightarrow> String.literal" where
  "hw_name HK_carrier = STR ''The carrier (heterozygote) frequency''"
| "hw_name HK_p2 = STR ''The homozygous dominant frequency''"
| "hw_name HK_p = STR ''The dominant allele frequency p''"
| "hw_name HK_q = STR ''The recessive allele frequency q''"

fun hw_src_lit :: "hwsrc \<Rightarrow> String.literal" where
  "hw_src_lit (HWq2 v) = STR ''q^2 = '' + plain_lit v"
| "hw_src_lit (HWone n) = STR ''q^2 = 1/'' + show_int (int n)"
| "hw_src_lit (HWqs q) = STR ''q = '' + plain_lit q"
| "hw_src_lit (HWps p) = STR ''p = '' + plain_lit p"

fun g_text :: "greq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "g_text (G_Geno xs) (Exact _ f) = STR ''The probability is '' + frac_lit f + STR '' (''
     + fixed_lit 4 (f * 100) + STR ''%) for '' + geno_lit (map tw xs) + STR '' from ''
     + geno_lit (map t1 xs) + STR '' x '' + geno_lit (map t2 xs) + STR '' (Punnett square, ''
     + show_int (int (4 ^ length xs)) + STR '' combinations).''"
| "g_text (G_Pheno isd a b) (Exact _ f) = STR ''The probability is '' + frac_lit f + STR '' (''
     + fixed_lit 4 (f * 100) + STR ''%) of the '' + (if isd then STR ''dominant'' else STR ''recessive'')
     + STR '' phenotype from '' + geno_lit [a] + STR '' x '' + geno_lit [b] + STR '' (complete dominance).''"
| "g_text (G_PRatio ls) (Ratio _ r) = STR ''The phenotypic ratio is '' + ratio_lit r + STR '' (''
     + geno_lit (map fst ls) + STR '' x '' + geno_lit (map snd ls)
     + STR '', complete dominance and independent loci; dominant classes first).''"
| "g_text (G_GRatio a b) (Ratio _ r) = STR ''The genotypic ratio is '' + ratio_lit r + STR '' (''
     + join_lit (STR '' : '') (map (\<lambda>w. (case a of Locus u l _ \<Rightarrow> zyg_lit (Locus u l w)))
         (filter (\<lambda>w. 0 < cnt1 (locus_zyg a) (locus_zyg b) w) [Hom_dom, Het, Hom_rec]))
     + STR ''; '' + geno_lit [a] + STR '' x '' + geno_lit [b] + STR '').''"
| "g_text (G_HW k s) o' = hw_name k + STR '' is '' + vtxt o' + STR '' ('' + ptxt o'
     + STR ''%; Hardy-Weinberg equilibrium, '' + hw_src_lit s + STR '').''"
| "g_text r o' = STR ''''"

definition g_reply :: "greq \<Rightarrow> reply" where
  "g_reply r = (let result = g_kernel r in mk_reply result (g_text r result))"

end
