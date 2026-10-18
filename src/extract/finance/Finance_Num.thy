theory Finance_Num
  imports "Veri7vn_Finance_Base.Finance_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Numeric machinery specific to the finance family. The real-number
embedding, decimals, rounding with proved error bounds, the verified interval
enclosure of one float interval, and the plain ASCII number layout live in
src/extract/commons (Veri7vn_Commons.Commons_Num) and are shared; what stays
here is the money-and-percent policy: fixed-exponent enclosures, the output
formats with their tolerances, and the fixed-point layout.\<close>
section \<open>Fixed-exponent enclosure\<close>
text \<open>Round the midpoint of a float interval at the decimal exponent @{text e}
when the interval is narrower than a tenth of the last digit. The result is
within 11/20 of the last digit of every real the interval encloses.\<close>
definition to_dec_at :: "int \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec_at e X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if hi - lo \<le> pow10 e / 10 then Some (round_at mid e) else None)"
theorem to_dec_at_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec_at e X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> pow10 e * (11 / 20)"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> pow10 e / 10" and dd: "d = round_at mid e"
    using d by (auto simp: to_dec_at_def Let_def lo_def hi_def mid_def split: if_splits)
  have r: "\<bar>dec_val d - mid\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have m: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2" unfolding mid_def using xin by (rule midpoint_close)
  have h: "(hi - lo) / 2 \<le> pow10 e / 20" using chk by simp
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
  show ?thesis using r m h tri by linarith
qed
text \<open>Four significant digits below 10^4 (as @{text "%.4g"}), two decimals above.\<close>
definition to_dec_g4 :: "float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec_g4 X = (if (real_of_float (lower X) + real_of_float (upper X)) / 2 < 10000
     then to_dec X else to_dec_at (-2) X)"
lemma pow10_m2: "pow10 (-2) = 1 / 100"
  by (simp add: pow10_def)
theorem to_dec_g4_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec_g4 X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 100"
proof (cases "(real_of_float (lower X) + real_of_float (upper X)) / 2 < 10000")
  case True
  then have "to_dec X = Some d" using d by (simp add: to_dec_g4_def)
  from to_dec_sound[OF x this] show ?thesis by linarith
next
  case False
  then have "to_dec_at (-2) X = Some d" using d by (simp add: to_dec_g4_def)
  note h = to_dec_at_sound[OF x this]
  have "0 \<le> \<bar>x\<bar>" by simp
  then show ?thesis using h pow10_m2 by linarith
qed
datatype fmt = Fm_money | Fm_pct4 | Fm_years2 | Fm_g3 | Fm_g4
definition fmt_exp :: "fmt \<Rightarrow> int" where
  "fmt_exp fm = (case fm of Fm_money \<Rightarrow> -2 | Fm_pct4 \<Rightarrow> -4 | Fm_years2 \<Rightarrow> -2 | Fm_g3 \<Rightarrow> -3 | Fm_g4 \<Rightarrow> -2)"
definition tol_approx :: "fmt \<Rightarrow> real \<Rightarrow> real" where
  "tol_approx fm x = (case fm of Fm_g4 \<Rightarrow> \<bar>x\<bar> / 1000 + 1 / 100 | _ \<Rightarrow> pow10 (fmt_exp fm) * (11 / 20))"
definition prec :: nat where "prec = 64"
definition enclose_fmt :: "fmt \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose_fmt fm e = (case approx prec e [] of None \<Rightarrow> None
     | Some X \<Rightarrow> (case fm of Fm_g4 \<Rightarrow> to_dec_g4 X | _ \<Rightarrow> to_dec_at (fmt_exp fm) X))"
theorem enclose_fmt_sound:
  assumes "enclose_fmt fm e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> tol_approx fm (interpret_floatarith e [])"
proof -
  obtain X where X: "approx prec e [] = Some X"
    using assms by (auto simp: enclose_fmt_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have in_: "interpret_floatarith e [] \<in>\<^sub>r X" .
  show ?thesis
  proof (cases "fm = Fm_g4")
    case True
    then have "to_dec_g4 X = Some d" using assms X by (simp add: enclose_fmt_def)
    from to_dec_g4_sound[OF in_ this] show ?thesis using True by (simp add: tol_approx_def)
  next
    case False
    then have "to_dec_at (fmt_exp fm) X = Some d"
      using assms X by (cases fm) (simp_all add: enclose_fmt_def)
    from to_dec_at_sound[OF in_ this] show ?thesis using False by (cases fm) (simp_all add: tol_approx_def)
  qed
qed
section \<open>Rounding an exact value to its stated decimal\<close>
definition quant :: "fmt \<Rightarrow> rat \<Rightarrow> (int \<times> int) option" where
  "quant fm q = (case fm of
       Fm_money \<Rightarrow> Some (round_at (rl q) (-2))
     | Fm_pct4 \<Rightarrow> Some (round_at (rl q) (-4))
     | Fm_years2 \<Rightarrow> Some (round_at (rl q) (-2))
     | Fm_g3 \<Rightarrow> Some (round_at (rl q) (if \<bar>rl q\<bar> < 1000000 then -3 else 0))
     | Fm_g4 \<Rightarrow> if \<bar>rl q\<bar> < 10000 then round_sig 4 (rl q) else Some (round_at (rl q) (-2)))"
definition tol_exact :: "fmt \<Rightarrow> real \<Rightarrow> real" where
  "tol_exact fm x = (case fm of
       Fm_money \<Rightarrow> pow10 (-2) / 2
     | Fm_pct4 \<Rightarrow> pow10 (-4) / 2
     | Fm_years2 \<Rightarrow> pow10 (-2) / 2
     | Fm_g3 \<Rightarrow> pow10 (if \<bar>x\<bar> < 1000000 then -3 else 0) / 2
     | Fm_g4 \<Rightarrow> if \<bar>x\<bar> < 10000 then \<bar>x\<bar> / (2 * 10 ^ (4 - 1)) else pow10 (-2) / 2)"
theorem quant_sound:
  assumes "quant fm q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> tol_exact fm (rl q)"
proof (cases fm)
  case Fm_money
  then have d: "d = round_at (rl q) (-2)" using assms by (simp add: quant_def)
  show ?thesis using round_at_error[of "rl q" "-2"] d Fm_money by (simp add: tol_exact_def)
next
  case Fm_pct4
  then have d: "d = round_at (rl q) (-4)" using assms by (simp add: quant_def)
  show ?thesis using round_at_error[of "rl q" "-4"] d Fm_pct4 by (simp add: tol_exact_def)
next
  case Fm_years2
  then have d: "d = round_at (rl q) (-2)" using assms by (simp add: quant_def)
  show ?thesis using round_at_error[of "rl q" "-2"] d Fm_years2 by (simp add: tol_exact_def)
next
  case Fm_g3
  then have d: "d = round_at (rl q) (if \<bar>rl q\<bar> < 1000000 then -3 else 0)" using assms by (simp add: quant_def)
  show ?thesis using round_at_error[of "rl q" "if \<bar>rl q\<bar> < 1000000 then -3 else 0"] d Fm_g3
    by (simp add: tol_exact_def)
next
  case Fm_g4
  show ?thesis
  proof (cases "\<bar>rl q\<bar> < 10000")
    case True
    then have "round_sig 4 (rl q) = Some d" using assms Fm_g4 by (simp add: quant_def)
    from round_sig_sound[OF this] show ?thesis using True Fm_g4 by (simp add: tol_exact_def)
  next
    case False
    then have d: "d = round_at (rl q) (-2)" using assms Fm_g4 by (simp add: quant_def)
    show ?thesis using False Fm_g4 d round_at_error[of "rl q" "-2"] by (simp add: tol_exact_def)
  qed
qed
text \<open>Digits of @{text "m / 10^k"}: the integer part and the @{text k} fraction digits.\<close>
definition fixed_parts :: "nat \<Rightarrow> int \<Rightarrow> nat list \<times> nat list" where
  "fixed_parts k m = (let ds = digits (nat \<bar>m\<bar>); ds' = replicate (k + 1 - length ds) 0 @ ds
     in (take (length ds' - k) ds', drop (length ds' - k) ds'))"
definition commas :: "nat list \<Rightarrow> String.literal" where
  "commas ds = (let n = length ds in
     foldr (\<lambda>(i, d) s. (if 0 < i \<and> (n - i) mod 3 = 0 then STR '','' else STR '''') + digit_lit d + s)
       (zip [0..<n] ds) (STR ''''))"
definition sign_lit :: "int \<Rightarrow> String.literal" where
  "sign_lit m = (if m < 0 then STR ''-'' else STR '''')"
text \<open>Python's @{text "%.kf"} (with @{text ","} grouping of the integer part when asked).\<close>
definition fixed_lit :: "nat \<Rightarrow> bool \<Rightarrow> int \<Rightarrow> String.literal" where
  "fixed_lit k grp m = (case fixed_parts k m of (ip, fr) \<Rightarrow>
     sign_lit m + (if grp then commas ip else lit ip) + (if k = 0 then STR '''' else STR ''.'' + lit fr))"
text \<open>The same with trailing zeros of the fraction removed (the economics organ's @{text g}).\<close>
definition fixed_strip :: "nat \<Rightarrow> int \<Rightarrow> String.literal" where
  "fixed_strip k m = (case fixed_parts k m of (ip, fr) \<Rightarrow>
     sign_lit m + lit ip + (if strip_zeros fr = [] then STR '''' else STR ''.'' + lit (strip_zeros fr)))"
text \<open>Python's @{text "format(round(x, 2), ',')"}: grouped, shortest fraction but at least one digit.\<close>
definition fixed_repr :: "nat \<Rightarrow> bool \<Rightarrow> int \<Rightarrow> String.literal" where
  "fixed_repr k grp m = (case fixed_parts k m of (ip, fr) \<Rightarrow>
     sign_lit m + (if grp then commas ip else lit ip)
       + (if strip_zeros fr = [] then STR ''.0'' else STR ''.'' + lit (strip_zeros fr)))"
definition show_fmt :: "fmt \<Rightarrow> bool \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "show_fmt fm grp d = (case d of (m, e) \<Rightarrow>
     (case fm of
        Fm_money \<Rightarrow> fixed_lit 2 grp m
      | Fm_pct4 \<Rightarrow> fixed_lit 4 grp m
      | Fm_years2 \<Rightarrow> fixed_lit 2 grp m
      | Fm_g3 \<Rightarrow> if e = 0 then fixed_lit 0 grp m else fixed_strip 3 m
      | Fm_g4 \<Rightarrow> if 10000 \<le> \<bar>m\<bar> then fixed_repr 2 grp m else render_dec 4 d))"
definition show_q :: "fmt \<Rightarrow> rat \<Rightarrow> String.literal" where
  "show_q fm q = (case quant fm q of Some d \<Rightarrow> show_fmt fm True d | None \<Rightarrow> STR ''?'')"
definition money :: "rat \<Rightarrow> String.literal" where
  "money q = STR ''$'' + show_q Fm_money q"
definition g3 :: "rat \<Rightarrow> String.literal" where "g3 q = show_q Fm_g3 q"
definition g4 :: "rat \<Rightarrow> String.literal" where "g4 q = show_q Fm_g4 q"
text \<open>Python's @{text "%g"} (six significant digits), for echoing an input.\<close>
definition g6 :: "rat \<Rightarrow> String.literal" where
  "g6 q = (case round_sig 6 (rl q) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"

end
