theory Space_Log
  imports "Veri7vn_Commons.Commons_Num"
begin

text \<open>Exact rational range reduction exposes a small logarithm argument to
interval arithmetic. The exponent uses the library's terminating bit-length
computation, not a guessed bound or a search with arbitrary fuel.\<close>

definition log_pow2 :: "int \<Rightarrow> rat" where
  "log_pow2 k = (if 0 \<le> k then 2 ^ nat k else inverse (2 ^ nat (-k)))"

lemma log_pow2_pos: "0 < log_pow2 k"
  by (simp add: log_pow2_def)

lemma log_pow2_real: "rl (log_pow2 k) = (2::real) powr of_int k"
  by (simp add: log_pow2_def of_rat_inverse of_rat_divide of_rat_power powr_int inverse_eq_divide)

definition log_exponent :: "rat \<Rightarrow> int" where
  "log_exponent q = (case quotient_of q of (n,d) \<Rightarrow> bitlen n - bitlen d)"

definition log_mantissa :: "rat \<Rightarrow> rat" where
  "log_mantissa q = q / log_pow2 (log_exponent q)"

lemma log_decomposition:
  "q = log_mantissa q * log_pow2 (log_exponent q)"
  using log_pow2_pos[of "log_exponent q"] by (simp add: log_mantissa_def)

lemma log_mantissa_pos:
  "0 < q \<Longrightarrow> 0 < log_mantissa q"
  by (simp add: log_mantissa_def log_pow2_pos)

lemma log_mantissa_range:
  assumes pos: "0 < q"
  shows "1/2 < log_mantissa q \<and> log_mantissa q < 2"
proof -
  obtain n d where nd: "quotient_of q = (n,d)" by (cases "quotient_of q")
  have d: "0 < d" by (rule quotient_of_denom_pos[OF nd])
  have q: "q = of_int n / of_int d" by (rule quotient_of_div[OF nd])
  have n: "0 < n" using pos d by (auto simp: q zero_less_divide_iff)
  have nr: "0 < (of_int n::real)" and dr: "0 < (of_int d::real)" using n d by simp_all
  have mp: "0 < (rl (log_mantissa q)::real)" using log_mantissa_pos[OF pos] by simp
  have mr: "rl (log_mantissa q) = rl q / rl (log_pow2 (log_exponent q))"
    by (simp add: log_mantissa_def of_rat_divide)
  have qr: "rl q = (of_int n::real) / of_int d" using q by (simp add: of_rat_divide)
  have logs: "log 2 (rl (log_mantissa q)) =
      log 2 (of_int n) - log 2 (of_int d) - of_int (log_exponent q)"
    using nr dr
    by (simp only: mr qr log_pow2_real)
       (auto simp: log_divide log_mult; linarith)
  have k: "log_exponent q = \<lfloor>log 2 (of_int n::real)\<rfloor> - \<lfloor>log 2 (of_int d::real)\<rfloor>"
    using n d by (simp add: log_exponent_def nd bitlen_alt_def)
  have lower: "-1 < log 2 (rl (log_mantissa q))"
    using of_int_floor_le[of "log 2 (of_int n::real)"]
      real_of_int_floor_add_one_gt[of "log 2 (of_int d::real)"]
    by (simp only: logs k of_int_diff; linarith)
  have upper: "log 2 (rl (log_mantissa q)) < 1"
    using of_int_floor_le[of "log 2 (of_int d::real)"]
      real_of_int_floor_add_one_gt[of "log 2 (of_int n::real)"]
    by (simp only: logs k of_int_diff; linarith)
  have half: "log 2 (1/2::real) = -1" by (simp add: log_divide)
  have low: "(1/2::real) < rl (log_mantissa q)"
    using lower mp half log_less_cancel_iff[of "2::real" "1/2" "rl (log_mantissa q)"] by auto
  have high: "rl (log_mantissa q) < (2::real)" using upper mp by simp
  have low_rat: "(1/2::rat) < log_mantissa q"
  proof -
    have "(of_rat (1/2::rat)::real) < of_rat (log_mantissa q)"
      using low by (simp add: of_rat_divide)
    then show ?thesis by (simp only: of_rat_less)
  qed
  have high_rat: "log_mantissa q < (2::rat)"
  proof -
    have "(of_rat (log_mantissa q)::real) < of_rat (2::rat)"
      using high by simp
    then show ?thesis by (simp only: of_rat_less)
  qed
  show ?thesis using low_rat high_rat by blast
qed

definition log_expr :: "rat \<Rightarrow> floatarith" where
  "log_expr q = (if 0 < q then
     floatarith.Add (floatarith.Ln (Q (log_mantissa q)))
       (floatarith.Mult (I (log_exponent q)) (floatarith.Ln (I 2)))
     else floatarith.Ln (Q q))"

lemma log_identity:
  assumes "0 < q"
  shows "ln (rl q) = ln (rl (log_mantissa q)) + of_int (log_exponent q) * ln 2"
proof -
  have m: "0 < (rl (log_mantissa q)::real)" using log_mantissa_pos[OF assms] by simp
  have p: "0 < (rl (log_pow2 (log_exponent q))::real)" using log_pow2_pos by simp
  have "ln (rl q) = ln (rl (log_mantissa q) * rl (log_pow2 (log_exponent q)))"
    by (metis log_decomposition of_rat_mult)
  also have "\<dots> = ln (rl (log_mantissa q)) + ln (rl (log_pow2 (log_exponent q)))"
    by (rule ln_mult_pos[OF m p])
  finally show ?thesis by (simp add: log_pow2_real)
qed

lemma interp_log_expr [simp]:
  "interpret_floatarith (log_expr q) xs = ln (rl q)"
  by (auto simp: log_expr_def log_identity)

end
