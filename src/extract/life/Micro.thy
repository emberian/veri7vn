theory Micro
  imports Life_Core
begin

text \<open>
  Lane S09-life, microbiology-v2 (upstream/root/specialists/microbiology-v2/organ_micro_v{1,2}.py):
  binary-fission growth, plate counts and serial dilutions. Plate counts,
  serial dilutions and generation counts are exact rationals; a population after
  a whole, small number of generations and a generation time over a power-of-two
  growth are exact; the remaining growth and generation-time questions
  (a real power of two, a real logarithm) are enclosed with interval arithmetic.
\<close>

fun log2_from :: "nat \<Rightarrow> nat \<Rightarrow> rat \<Rightarrow> nat option" where
  "log2_from 0 m r = None"
| "log2_from (Suc f) m r = (if 2 ^ m = r then Some m else log2_from f (Suc m) r)"

lemma log2_from_sound: "log2_from f m r = Some j \<Longrightarrow> 2 ^ j = r \<and> m \<le> j"
proof (induct f arbitrary: m)
  case 0
  then show ?case by simp
next
  case (Suc f)
  show ?case
  proof (cases "2 ^ m = r")
    case True
    then show ?thesis using Suc by simp
  next
    case False
    then have "log2_from f (Suc m) r = Some j" using Suc by simp
    then show ?thesis using Suc.hyps[of "Suc m"] by (auto dest: Suc_leD)
  qed
qed

definition log2_exact :: "rat \<Rightarrow> nat option" where "log2_exact r = log2_from 200 1 r"

lemma log2_exact_sound: "log2_exact r = Some j \<Longrightarrow> (2::rat) ^ j = r \<and> 1 \<le> j"
  by (auto simp: log2_exact_def dest: log2_from_sound)

definition small_nat :: "rat \<Rightarrow> nat option" where
  "small_nat n = (case nat_of_rat n of Some m \<Rightarrow> if m \<le> 60 then Some m else None | None \<Rightarrow> None)"

lemma small_nat_sound: "small_nat n = Some m \<Longrightarrow> n = of_nat m"
  by (auto simp: small_nat_def dest: nat_of_rat_sound split: option.splits if_splits)

datatype mreq =
    M_CFU rat rat rat
  | M_Serial nat nat
  | M_GrowthN rat rat rat
  | M_Gens rat rat
  | M_GenTime rat rat rat
  | M_Unread

definition read_fail :: String.literal where
  "read_fail = STR ''I couldn'' + apos + STR ''t read every quantity I need from that; give the starting count, time and doubling time (or colonies, dilution and volume plated) with units and I'' + apos + STR ''ll work it out.''"

fun m_phys :: "mreq \<Rightarrow> real" where
  "m_phys (M_GrowthN n0 g t) = rl n0 * 2 powr (rl t / rl g)"
| "m_phys (M_GenTime n0 nf t) = rl t / log 2 (rl nf / rl n0)"
| "m_phys r = 0"

fun m_fa :: "mreq \<Rightarrow> floatarith" where
  "m_fa (M_GrowthN n0 g t) = floatarith.Mult (Q n0) (floatarith.Powr (I 2) (Q (t / g)))"
| "m_fa (M_GenTime n0 nf t) = floatarith.Mult (Q t)
     (floatarith.Mult (floatarith.Ln (I 2)) (floatarith.Inverse (floatarith.Ln (Q (nf / n0)))))"
| "m_fa r = I 0"

lemma interp_m_fa_growth [simp]:
  "interpret_floatarith (m_fa (M_GrowthN n0 g t)) xs = m_phys (M_GrowthN n0 g t)"
  by (simp add: of_rat_divide)

lemma interp_m_fa_gentime [simp]:
  "interpret_floatarith (m_fa (M_GenTime n0 nf t)) xs = m_phys (M_GenTime n0 nf t)"
  by (simp add: of_rat_divide of_rat_mult of_rat_inverse log_def divide_inverse)

fun m_bad :: "mreq \<Rightarrow> decline option" where
  "m_bad (M_CFU c d v) = (if d \<le> 0 \<or> v \<le> 0 then Some (Impossible R_zero) else None)"
| "m_bad (M_GrowthN n0 g t) = (if g \<le> 0 then Some (Impossible R_zero) else None)"
| "m_bad (M_Gens t g) = (if g \<le> 0 then Some (Impossible R_zero) else None)"
| "m_bad (M_GenTime n0 nf t) = (if nf \<le> n0 then Some (Impossible R_final_below)
     else if n0 \<le> 0 then Some (Impossible R_zero) else None)"
| "m_bad M_Unread = Some (Underspecified read_fail)"
| "m_bad r = None"

fun m_answer :: "mreq \<Rightarrow> outcome" where
  "m_answer (M_CFU c d v) = Exact (STR ''cfu'') (c / (d * v))"
| "m_answer (M_Serial f k) = Exact (STR ''serial'') (of_nat (f ^ k))"
| "m_answer (M_GrowthN n0 g t) = (case small_nat (t / g) of
     Some m \<Rightarrow> Exact (STR ''growth_n'') (n0 * 2 ^ m)
   | None \<Rightarrow> approx_out (STR ''growth_n'') (m_fa (M_GrowthN n0 g t)))"
| "m_answer (M_Gens t g) = Exact (STR ''generations'') (t / g)"
| "m_answer (M_GenTime n0 nf t) = (case log2_exact (nf / n0) of
     Some m \<Rightarrow> Exact (STR ''gen_time'') (t / of_nat m)
   | None \<Rightarrow> approx_out (STR ''gen_time'') (m_fa (M_GenTime n0 nf t)))"
| "m_answer M_Unread = Decline Imprecise"

definition m_kernel :: "mreq \<Rightarrow> outcome" where
  "m_kernel r = (case m_bad r of Some w \<Rightarrow> Decline w | None \<Rightarrow> m_answer r)"

lemma m_answer_decline: "m_answer r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r) (auto dest: approx_out_decline split: option.splits)

theorem m_imprecise:
  assumes "m_kernel r = Decline Imprecise"
  shows "m_bad r = None"
  using assms by (cases r) (auto simp: m_kernel_def split: if_splits option.splits)

theorem unread_declines: "m_kernel M_Unread = Decline (Underspecified read_fail)"
  by (simp add: m_kernel_def)

section \<open>What each kind means\<close>

theorem cfu_value:
  assumes "m_kernel (M_CFU c d v) = Exact k q"
  shows "0 < d \<and> 0 < v \<and> q * (d * v) = c"
proof -
  have nd: "\<not> (d \<le> 0 \<or> v \<le> 0)" using assms by (cases "d \<le> 0 \<or> v \<le> 0") (simp_all add: m_kernel_def)
  then have h: "0 < d" "0 < v" by auto
  have q: "q = c / (d * v)" using assms nd by (simp add: m_kernel_def)
  have "d * v \<noteq> 0" using h by simp
  then show ?thesis using h q by (simp add: field_simps)
qed

theorem serial_value:
  "m_kernel (M_Serial f k) = Exact (STR ''serial'') (of_nat (f ^ k))"
  by (simp add: m_kernel_def)

text \<open>Dilutions compose: k1 steps then k2 steps is k1 + k2 steps.\<close>
theorem serial_composes:
  assumes "m_kernel (M_Serial f k1) = Exact c a" "m_kernel (M_Serial f k2) = Exact c' b"
  shows "m_kernel (M_Serial f (k1 + k2)) = Exact (STR ''serial'') (a * b)"
  using assms by (simp add: m_kernel_def power_add)

theorem generations_value:
  assumes "m_kernel (M_Gens t g) = Exact k q"
  shows "0 < g \<and> q * g = t"
proof -
  have nd: "\<not> g \<le> 0" using assms by (cases "g \<le> 0") (simp_all add: m_kernel_def)
  then have g: "0 < g" by simp
  have "q = t / g" using assms nd by (simp add: m_kernel_def)
  then show ?thesis using g by simp
qed

theorem growth_exact:
  assumes "m_kernel (M_GrowthN n0 g t) = Exact k q"
  shows "0 < g \<and> rl q = m_phys (M_GrowthN n0 g t)"
proof -
  have nd: "\<not> g \<le> 0" using assms by (cases "g \<le> 0") (simp_all add: m_kernel_def)
  then have gpos: "0 < g" by simp
  have a: "m_answer (M_GrowthN n0 g t) = Exact k q" using assms nd by (simp add: m_kernel_def)
  show ?thesis
  proof (cases "small_nat (t / g)")
    case None
    then show ?thesis using a by simp
  next
    case (Some m)
    have q: "q = n0 * 2 ^ m" using a Some by simp
    have tg: "t / g = of_nat m" by (rule small_nat_sound[OF Some])
    have "rl t / rl g = real m"
    proof -
      have "rl (t / g) = rl (of_nat m)" using tg by simp
      then show ?thesis by (simp add: of_rat_divide)
    qed
    then have "(2::real) powr (rl t / rl g) = 2 ^ m" by (simp add: powr_realpow)
    then show ?thesis using q gpos by (simp add: of_rat_mult of_rat_power)
  qed
qed

theorem growth_approx:
  assumes "m_kernel (M_GrowthN n0 g t) = Approx k d"
  shows "0 < g \<and> \<bar>dec_val d - m_phys (M_GrowthN n0 g t)\<bar> \<le> \<bar>m_phys (M_GrowthN n0 g t)\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "\<not> g \<le> 0" using assms by (cases "g \<le> 0") (simp_all add: m_kernel_def)
  then have gpos: "0 < g" by simp
  have a: "m_answer (M_GrowthN n0 g t) = Approx k d" using assms nd by (simp add: m_kernel_def)
  show ?thesis
  proof (cases "small_nat (t / g)")
    case None
    have a2: "approx_out (STR ''growth_n'') (m_fa (M_GrowthN n0 g t)) = Approx k d" using a None by simp
    have e: "\<forall>xs. interpret_floatarith (m_fa (M_GrowthN n0 g t)) xs = m_phys (M_GrowthN n0 g t)"
      using interp_m_fa_growth by blast
    from approx_out_phys[OF a2 e] show ?thesis using gpos by simp
  next
    case (Some m)
    then show ?thesis using a by simp
  qed
qed

theorem gentime_exact:
  assumes "m_kernel (M_GenTime n0 nf t) = Exact k q"
  shows "n0 < nf \<and> 0 < n0 \<and> (\<exists>m\<ge>1. (2::rat) ^ m = nf / n0 \<and> q * of_nat m = t)"
proof -
  have nd1: "\<not> nf \<le> n0" using assms by (cases "nf \<le> n0") (simp_all add: m_kernel_def)
  have nd2: "\<not> n0 \<le> 0" using assms nd1 by (cases "n0 \<le> 0") (simp_all add: m_kernel_def)
  have nd: "\<not> nf \<le> n0 \<and> \<not> n0 \<le> 0" using nd1 nd2 by simp
  have a: "m_answer (M_GenTime n0 nf t) = Exact k q" using assms nd by (simp add: m_kernel_def)
  show ?thesis
  proof (cases "log2_exact (nf / n0)")
    case None
    then show ?thesis using a by simp
  next
    case (Some m)
    have q: "q = t / of_nat m" using a Some by simp
    have s: "(2::rat) ^ m = nf / n0 \<and> 1 \<le> m" by (rule log2_exact_sound[OF Some])
    then have "(of_nat m :: rat) \<noteq> 0" by simp
    then have "q * of_nat m = t" using q by simp
    then show ?thesis using nd s by (auto intro!: exI[of _ m])
  qed
qed

theorem gentime_approx:
  assumes "m_kernel (M_GenTime n0 nf t) = Approx k d"
  shows "n0 < nf \<and> 0 < n0 \<and> \<bar>dec_val d - m_phys (M_GenTime n0 nf t)\<bar> \<le> \<bar>m_phys (M_GenTime n0 nf t)\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd1: "\<not> nf \<le> n0" using assms by (cases "nf \<le> n0") (simp_all add: m_kernel_def)
  have nd2: "\<not> n0 \<le> 0" using assms nd1 by (cases "n0 \<le> 0") (simp_all add: m_kernel_def)
  have nd: "\<not> nf \<le> n0 \<and> \<not> n0 \<le> 0" using nd1 nd2 by simp
  have a: "m_answer (M_GenTime n0 nf t) = Approx k d" using assms nd by (simp add: m_kernel_def)
  show ?thesis
  proof (cases "log2_exact (nf / n0)")
    case None
    have a2: "approx_out (STR ''gen_time'') (m_fa (M_GenTime n0 nf t)) = Approx k d" using a None by simp
    have e: "\<forall>xs. interpret_floatarith (m_fa (M_GenTime n0 nf t)) xs = m_phys (M_GenTime n0 nf t)"
      using interp_m_fa_gentime by blast
    from approx_out_phys[OF a2 e] show ?thesis using nd by simp
  next
    case (Some m)
    then show ?thesis using a by simp
  qed
qed

theorem gentime_declines_shrinking:
  "nf \<le> n0 \<Longrightarrow> m_kernel (M_GenTime n0 nf t) = Decline (Impossible R_final_below)"
  by (simp add: m_kernel_def)

section \<open>Declines stated apart from the code\<close>

lemma m_decl_iff: "w \<noteq> Imprecise \<Longrightarrow> m_kernel r = Decline w \<longleftrightarrow> m_bad r = Some w"
  by (cases "m_bad r") (auto simp: m_kernel_def dest: m_answer_decline)

theorem cfu_declines_iff:
  "m_kernel (M_CFU c d v) = Decline (Impossible R_zero) \<longleftrightarrow> d \<le> 0 \<or> v \<le> 0"
  by (simp add: m_decl_iff)

theorem gens_declines_iff:
  "m_kernel (M_Gens t g) = Decline (Impossible R_zero) \<longleftrightarrow> g \<le> 0"
  by (simp add: m_decl_iff)

theorem gentime_final_below_iff:
  "m_kernel (M_GenTime n0 nf t) = Decline (Impossible R_final_below) \<longleftrightarrow> nf \<le> n0"
  by (simp add: m_decl_iff)

theorem gentime_zero_iff:
  "m_kernel (M_GenTime n0 nf t) = Decline (Impossible R_zero) \<longleftrightarrow> n0 < nf \<and> n0 \<le> 0"
  by (auto simp: m_decl_iff)

section \<open>Response text\<close>

definition mnum :: "outcome \<Rightarrow> String.literal" where
  "mnum o' = (case o' of Exact _ q \<Rightarrow> plain_lit q | Approx _ d \<Rightarrow> render_dec 4 d | _ \<Rightarrow> STR '''')"

fun m_text :: "mreq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "m_text (M_CFU c d v) o' = STR ''The concentration is '' + mnum o' + STR '' CFU/mL ('' + plain_lit c
     + STR '' colonies / ('' + plain_lit d + STR '' dilution x '' + plain_lit v + STR '' mL plated)''
     + (if 30 \<le> c \<and> c \<le> 300 then STR '''' else STR ''; note '' + plain_lit c
        + STR '' colonies is outside the 30-300 countable range'') + STR '').''"
| "m_text (M_Serial f k) o' = STR ''The total dilution is 1:'' + show_int (int (f ^ k)) + STR '' (''
     + show_int (int f) + STR ''^'' + show_int (int k) + STR ''; each step 1:'' + show_int (int f) + STR '').''"
| "m_text (M_GrowthN n0 g t) o' = STR ''The population is '' + mnum o' + STR '' cells (N0 x 2^(t/g) = '' + plain_lit n0
     + STR '' x 2^'' + plain_lit (t / g) + STR ''; '' + plain_lit (t / g) + STR '' generations).''"
| "m_text (M_Gens t g) o' = STR ''The number of generations is '' + mnum o' + STR '' (t / g = '' + plain_lit t
     + STR '' min / '' + plain_lit g + STR '' min).''"
| "m_text (M_GenTime n0 nf t) o' = STR ''The generation time is '' + mnum o'
     + STR '' minutes (t / log2(N/N0) = '' + plain_lit t + STR '' min / log2('' + plain_lit (nf / n0) + STR '')).''"
| "m_text M_Unread o' = STR ''''"

definition m_reply :: "mreq \<Rightarrow> reply" where
  "m_reply r = mk_reply (m_kernel r) (m_text r (m_kernel r))"

end
