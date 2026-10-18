theory Finance_Num
  imports "Veri7vn_Finance_Base.Finance_Base" "HOL-Library.Code_Target_Numeral"
begin

text \<open>Numeric machinery shared by the whole finance family: the real-number
embedding, decimals (m * 10^e), rounding with proved error bounds, verified
interval enclosures, and plain-ASCII number layout. The rounding lemmas from
@{text pow10} to @{text to_dec_sound} are copied from lane G
(src/extract/quantity/Quantity.thy) unchanged; the fixed-point rounding,
the fixed-exponent enclosure and the layout functions are new here.\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

definition I :: "int \<Rightarrow> floatarith" where "I i = floatarith.Num (Float i 0)"

definition Q :: "rat \<Rightarrow> floatarith" where
  "Q q = (case quotient_of q of (a, b) \<Rightarrow> floatarith.Mult (I a) (floatarith.Inverse (I b)))"

lemma interp_I [simp]: "interpret_floatarith (I i) xs = of_int i"
  by (simp add: I_def)

lemma interp_Q [simp]: "interpret_floatarith (Q q) xs = rl q"
proof -
  obtain a b where qa: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have "q = of_int a / of_int b" by (rule quotient_of_div)
  then have "rl q = of_int a / of_int b" by (simp add: of_rat_divide)
  then show ?thesis by (simp add: Q_def qa divide_inverse)
qed

definition pow10 :: "int \<Rightarrow> real" where
  "pow10 k = (if 0 \<le> k then 10 ^ nat k else inverse (10 ^ nat (- k)))"

lemma pow10_pos: "0 < pow10 k"
  by (simp add: pow10_def)

definition dec_val :: "int \<times> int \<Rightarrow> real" where
  "dec_val d = (case d of (m, e) \<Rightarrow> of_int m * pow10 e)"

definition round_at :: "real \<Rightarrow> int \<Rightarrow> int \<times> int" where
  "round_at x e = (\<lfloor>x / pow10 e + 1 / 2\<rfloor>, e)"

lemma round_at_error: "\<bar>dec_val (round_at x e) - x\<bar> \<le> pow10 e / 2"
proof -
  define p where "p = pow10 e"
  have p: "0 < p" by (simp add: p_def pow10_pos)
  define y where "y = x / p"
  have x: "x = y * p" using p by (simp add: y_def)
  have lo: "of_int \<lfloor>y + 1 / 2\<rfloor> \<le> y + 1 / 2" by (rule of_int_floor_le)
  have hi: "y + 1 / 2 < of_int \<lfloor>y + 1 / 2\<rfloor> + 1" by (rule real_of_int_floor_add_one_gt)
  have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> \<le> 1 / 2" using lo hi by linarith
  then have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> * p \<le> 1 / 2 * p" using p by (intro mult_right_mono) auto
  then have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> * p - y * p\<bar> \<le> p / 2"
    using p by (simp add: abs_mult left_diff_distrib[symmetric])
  then show ?thesis by (simp add: dec_val_def round_at_def p_def[symmetric] y_def[symmetric] x[symmetric])
qed

text \<open>Tie behaviour, stated: an exact decimal tie rounds up (away from minus
infinity). Oracle7's organs round a binary float instead, so on an exact decimal
tie whose float lies just below (0.015 * 745 = 11.174999... as a float) they
print the lower neighbour; round-half-even on the exact value would also give
the upper one here (11.175 to 11.18), so no tie rule reproduces the float
artefact.\<close>
theorem round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"
proof -
  have "x / pow10 e + 1 / 2 = of_int (n + 1)" using assms by simp
  then show ?thesis by (simp add: round_at_def)
qed

text \<open>An exponent @{text e} with @{text "10^(p-1) * 10^e \<le> |x| < 10^p * 10^e"}
when one is found within 400 steps; soundness does not rely on the search,
@{text round_sig} checks the condition it needs.\<close>
fun exp_up :: "real \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> int \<Rightarrow> int" where
  "exp_up B x 0 e = e"
| "exp_up B x (Suc n) e = (if B * pow10 e \<le> x then exp_up B x n (e + 1) else e)"

fun exp_down :: "real \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> int \<Rightarrow> int" where
  "exp_down L x 0 e = e"
| "exp_down L x (Suc n) e = (if x < L * pow10 e then exp_down L x n (e - 1) else e)"

definition sig_exp :: "nat \<Rightarrow> real \<Rightarrow> int" where
  "sig_exp p x = exp_down (10 ^ (p - 1)) \<bar>x\<bar> 400 (exp_up (10 ^ p) \<bar>x\<bar> 400 0)"

text \<open>Round to @{text p} significant decimal digits (Python's @{text "%.pg"}
value), or refuse.\<close>
definition round_sig :: "nat \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "round_sig p x = (if x = 0 then Some (0, 0) else
     let e = sig_exp p x in if 10 ^ (p - 1) * pow10 e \<le> \<bar>x\<bar> then Some (round_at x e) else None)"

theorem round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
proof (cases "x = 0")
  case True
  then have "d = (0, 0)" using assms by (simp add: round_sig_def)
  then show ?thesis using True by (simp add: dec_val_def)
next
  case False
  define e where "e = sig_exp p x"
  have chk: "10 ^ (p - 1) * pow10 e \<le> \<bar>x\<bar>" and dd: "d = round_at x e"
    using assms False by (simp_all add: round_sig_def Let_def e_def split: if_splits)
  have r: "\<bar>dec_val d - x\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have L: "(10::real) ^ (p - 1) \<noteq> 0" by simp
  have "(10 ^ (p - 1) * pow10 e) / (2 * 10 ^ (p - 1)) \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
    using chk by (rule divide_right_mono) simp
  moreover have "(10 ^ (p - 1) * pow10 e) / (2 * 10 ^ (p - 1)) = pow10 e / 2"
    using L by (simp add: field_simps)
  ultimately have "pow10 e / 2 \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))" by simp
  then show ?thesis using r by linarith
qed

lemma midpoint_close:
  fixes lo hi x :: real
  assumes "lo \<le> x" "x \<le> hi"
  shows "\<bar>(lo + hi) / 2 - x\<bar> \<le> (hi - lo) / 2"
proof (rule abs_leI)
  show "(lo + hi) / 2 - x \<le> (hi - lo) / 2" using assms(1) by (simp add: field_simps)
  show "- ((lo + hi) / 2 - x) \<le> (hi - lo) / 2" using assms(2) by (simp add: field_simps)
qed

text \<open>Four significant digits from a float interval enclosing a value, or a
refusal when the interval is too wide (lane D's @{text to_dec}).\<close>
definition to_dec :: "float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000 then Some (0, 0)
     else let e = sig_exp 4 mid in
       if hi - lo \<le> \<bar>mid\<bar> / 1000000 \<and> 1000 * pow10 e \<le> \<bar>mid\<bar> then Some (round_at mid e) else None)"

theorem to_dec_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  show ?thesis
  proof (cases "lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000")
    case True
    then have "d = (0, 0)" using d by (simp add: to_dec_def Let_def lo_def hi_def)
    then have "dec_val d = 0" by (simp add: dec_val_def)
    then have eq: "\<bar>dec_val d - x\<bar> = \<bar>x\<bar>" by simp
    have "\<bar>x\<bar> \<le> 1 / 1000000000" using True xin by arith
    then show ?thesis using eq by linarith
  next
    case False
    define e where "e = sig_exp 4 mid"
    have chk: "hi - lo \<le> \<bar>mid\<bar> / 1000000" "1000 * pow10 e \<le> \<bar>mid\<bar>" and dd: "d = round_at mid e"
      using d False by (simp_all add: to_dec_def Let_def lo_def hi_def mid_def e_def split: if_splits)
    have r: "\<bar>dec_val d - mid\<bar> \<le> \<bar>mid\<bar> / 2000"
      unfolding dd using round_at_error[of mid e] chk(2) by linarith
    have "\<bar>mid - x\<bar> \<le> (hi - lo) / 2"
      unfolding mid_def using xin by (rule midpoint_close)
    moreover have "(hi - lo) / 2 \<le> (\<bar>mid\<bar> / 1000000) / 2"
      using chk(1) by (rule divide_right_mono) simp
    then have "(hi - lo) / 2 \<le> \<bar>mid\<bar> / 2000000" by simp
    ultimately have m: "\<bar>mid - x\<bar> \<le> \<bar>mid\<bar> / 2000000" by (rule order_trans)
    have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
    have M: "\<bar>mid\<bar> \<le> \<bar>x\<bar> + \<bar>mid - x\<bar>" by arith
    show ?thesis using r m tri M by linarith
  qed
qed


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

definition prec :: nat where "prec = 120"

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

section \<open>Number layout (plain ASCII, not proved)\<close>

fun digits :: "nat \<Rightarrow> nat list" where
  "digits n = (if n < 10 then [n] else digits (n div 10) @ [n mod 10])"

definition digit_lit :: "nat \<Rightarrow> String.literal" where
  "digit_lit d = (if d = 0 then STR ''0'' else if d = 1 then STR ''1'' else if d = 2 then STR ''2''
    else if d = 3 then STR ''3'' else if d = 4 then STR ''4'' else if d = 5 then STR ''5''
    else if d = 6 then STR ''6'' else if d = 7 then STR ''7'' else if d = 8 then STR ''8''
    else STR ''9'')"

definition lit :: "nat list \<Rightarrow> String.literal" where
  "lit ds = foldr (\<lambda>d s. digit_lit d + s) ds (STR '''')"

definition strip_zeros :: "nat list \<Rightarrow> nat list" where
  "strip_zeros ds = rev (dropWhile (\<lambda>d. d = 0) (rev ds))"

definition pad2 :: "nat list \<Rightarrow> nat list" where
  "pad2 ds = (if length ds < 2 then 0 # ds else ds)"

text \<open>Python's @{text "%.pg"} layout for a decimal @{text "m * 10^e"} (lane D's
@{text render_dec} with the precision as a parameter).\<close>
definition render_dec :: "nat \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_dec p d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>); k = int (length ds); x = e + k - 1 in
     if x < -4 \<or> int p \<le> x then
       (let fr = strip_zeros (tl ds) in
        sg + lit [hd ds] + (if fr = [] then STR '''' else STR ''.'' + lit fr) + STR ''e''
          + (if x < 0 then STR ''-'' else STR ''+'') + lit (pad2 (digits (nat \<bar>x\<bar>))))
     else if 0 \<le> e then sg + lit (ds @ replicate (nat e) 0)
     else
       (let p = nat (- e);
            ip = (if p < length ds then take (length ds - p) ds else [0]);
            fr = strip_zeros (if p < length ds then drop (length ds - p) ds
                              else replicate (p - length ds) 0 @ ds)
        in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr)))"

definition show_int :: "int \<Rightarrow> String.literal" where
  "show_int i = (if i < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>i\<bar>))"

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

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"

end
