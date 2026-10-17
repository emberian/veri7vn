theory Trades_Num
  imports "Veri7vn_Trades_Base.Trades_Base"
begin

text \<open>Numbers for the trades family: exact rationals read as reals, verified
interval enclosures (lane D and lane G's pattern, copied), decimal rounding with
a proved error bound, and the layout of numbers as text. Everything from
@{text pow10} to @{text enclose_sound} and the digit helpers is copied from
src/extract/quantity/Quantity.thy (lane G); @{text Dv}, @{text Sb}, the
logarithm and its lemmas from src/extract/acoustics/Acoustics.thy (lane D).\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

section \<open>Interval expressions\<close>

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


definition Dv :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where "Dv a b = floatarith.Mult a (floatarith.Inverse b)"
definition Sb :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where "Sb a b = floatarith.Add a (floatarith.Minus b)"
text \<open>Base-10 logarithm. The library's bounds for @{text ln} converge slowly when
the binary mantissa of the argument is near 2 (about four digits at any
precision), so the argument is first brought near 1 by eight square roots:
@{text "ln y = 256 ln (sqrt\<^sup>8 y)"} for @{text "y \<ge> 0"}.\<close>
definition sq8 :: "floatarith \<Rightarrow> floatarith" where
  "sq8 a = floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt
     (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt a)))))))"

definition r8 :: "real \<Rightarrow> real" where
  "r8 y = sqrt (sqrt (sqrt (sqrt (sqrt (sqrt (sqrt (sqrt y)))))))"

definition Lg :: "floatarith \<Rightarrow> floatarith" where
  "Lg a = floatarith.Mult (floatarith.Mult (I 256) (floatarith.Ln (sq8 a)))
     (floatarith.Inverse (floatarith.Ln (I 10)))"

lemma interp_Dv [simp]: "interpret_floatarith (Dv a b) xs = interpret_floatarith a xs / interpret_floatarith b xs"
  by (simp add: Dv_def divide_inverse)
lemma interp_Sb [simp]: "interpret_floatarith (Sb a b) xs = interpret_floatarith a xs - interpret_floatarith b xs"
  by (simp add: Sb_def)
lemma interp_sq8: "interpret_floatarith (sq8 a) xs = r8 (interpret_floatarith a xs)"
  by (simp add: sq8_def r8_def)

lemma ln_sqrt_half: "0 \<le> z \<Longrightarrow> ln (sqrt z) = ln z / 2"
  by (rule ln_sqrt)

lemma ln_r8: "0 \<le> y \<Longrightarrow> ln (r8 y) = ln y / 256"
proof -
  assume y: "0 \<le> y"
  let ?s = sqrt
  have n1: "0 \<le> ?s y" and n2: "0 \<le> ?s (?s y)" and n3: "0 \<le> ?s (?s (?s y))"
    and n4: "0 \<le> ?s (?s (?s (?s y)))" and n5: "0 \<le> ?s (?s (?s (?s (?s y))))"
    and n6: "0 \<le> ?s (?s (?s (?s (?s (?s y)))))" and n7: "0 \<le> ?s (?s (?s (?s (?s (?s (?s y))))))"
    using y by (simp_all only: real_sqrt_ge_zero)
  show ?thesis unfolding r8_def
    by (simp only: ln_sqrt_half[OF n7] ln_sqrt_half[OF n6] ln_sqrt_half[OF n5] ln_sqrt_half[OF n4]
        ln_sqrt_half[OF n3] ln_sqrt_half[OF n2] ln_sqrt_half[OF n1] ln_sqrt_half[OF y])
qed

lemma interp_Lg [simp]:
  "0 \<le> interpret_floatarith a xs \<Longrightarrow> interpret_floatarith (Lg a) xs = log 10 (interpret_floatarith a xs)"
proof -
  assume y: "0 \<le> interpret_floatarith a xs"
  have "interpret_floatarith (Lg a) xs = of_int 256 * ln (r8 (interpret_floatarith a xs)) * inverse (ln (of_int 10))"
    by (simp only: Lg_def interpret_floatarith.simps interp_sq8 interp_I)
  also have "\<dots> = of_int 256 * (ln (interpret_floatarith a xs) / 256) * inverse (ln (of_int 10))"
    by (simp only: ln_r8[OF y])
  also have "\<dots> = ln (interpret_floatarith a xs) * inverse (ln 10)"
    by simp
  also have "\<dots> = log 10 (interpret_floatarith a xs)"
    by (simp only: log_def divide_inverse)
  finally show ?thesis .
qed

lemma interp_P10 [simp]: "interpret_floatarith (floatarith.Powr (I 10) a) xs = 10 powr interpret_floatarith a xs"
  by simp

section \<open>Decimal rounding with a proved error bound\<close>

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

definition prec :: nat where "prec = 64"

definition enclose :: "nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose p e = (case approx p e [] of None \<Rightarrow> None | Some X \<Rightarrow> to_dec X)"

lemma enclose_sound:
  assumes "enclose p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
proof -
  obtain X where X: "approx p e [] = Some X" and d: "to_dec X = Some d"
    using assms by (auto simp: enclose_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using to_dec_sound d by blast
qed

section \<open>Digits as text\<close>

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

definition show_nat :: "nat \<Rightarrow> String.literal" where
  "show_nat n = lit (digits n)"

text \<open>Python's @{text "format(n, ',')"} for a non-negative whole number.\<close>
fun commas_aux :: "nat \<Rightarrow> nat list \<Rightarrow> String.literal" where
  "commas_aux k [] = STR ''''"
| "commas_aux k (d # ds) = digit_lit d
     + (if ds \<noteq> [] \<and> (k - 1) mod 3 = 0 then STR '','' else STR '''') + commas_aux (k - 1) ds"

definition show_commas :: "int \<Rightarrow> String.literal" where
  "show_commas i = (if i < 0 then STR ''-'' else STR '''')
     + commas_aux (length (digits (nat \<bar>i\<bar>))) (digits (nat \<bar>i\<bar>))"

text \<open>Python's @{text "%.2f"} of a decimal @{text "m * 10^-2"}.\<close>
definition render_cents :: "int \<times> int \<Rightarrow> String.literal" where
  "render_cents d = (case d of (m, e) \<Rightarrow>
     (if m < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>m\<bar> div 100)) + STR ''.''
       + lit (pad2 (digits (nat \<bar>m\<bar> mod 100))))"

section \<open>Fixed decimals and the three enclosure modes\<close>

text \<open>Enclosure to a fixed decimal place (the organs' @{text "%.3f"}): the
interval must be narrower than a thousandth of the place.\<close>
definition to_fixed :: "int \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed e X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if hi - lo \<le> pow10 e / 1000 then Some (round_at mid e) else None)"

theorem to_fixed_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed e X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> pow10 e * (1001 / 2000)"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> pow10 e / 1000" and dd: "d = round_at mid e"
    using d by (simp_all add: to_fixed_def Let_def lo_def hi_def mid_def split: if_splits)
  have r: "\<bar>dec_val d - mid\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have mc: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2" unfolding mid_def using xin by (rule midpoint_close)
  have h2: "(hi - lo) / 2 \<le> pow10 e / 2000" using chk by (simp add: field_simps)
  have m: "\<bar>mid - x\<bar> \<le> pow10 e / 2000" by (rule order_trans[OF mc h2])
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
  show ?thesis using r m tri by linarith
qed

datatype amode = Sig4 | Sig4C | Fix3

text \<open>Sig4: four significant digits (@{text "%.4g"}). Sig4C: the same below
10000, a comma-grouped whole number from there up (printing's @{text g}).
Fix3: three decimals.\<close>
definition enclose_m :: "amode \<Rightarrow> nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose_m md p e = (case approx p e [] of None \<Rightarrow> None | Some X \<Rightarrow>
     (case md of Sig4 \<Rightarrow> to_dec X
      | Sig4C \<Rightarrow> if 10000 \<le> real_of_float (lower X) then to_fixed 0 X else to_dec X
      | Fix3 \<Rightarrow> to_fixed (- 3) X))"

theorem enclose_m_sound:
  assumes "enclose_m md p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000"
proof -
  obtain X where X: "approx p e [] = Some X" and d: "(case md of Sig4 \<Rightarrow> to_dec X
      | Sig4C \<Rightarrow> if 10000 \<le> real_of_float (lower X) then to_fixed 0 X else to_dec X
      | Fix3 \<Rightarrow> to_fixed (- 3) X) = Some d"
    using assms by (auto simp: enclose_m_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have xin: "interpret_floatarith e [] \<in>\<^sub>r X" .
  define x where "x = interpret_floatarith e []"
  have xin': "x \<in>\<^sub>r X" using xin by (simp add: x_def)
  have ax: "0 \<le> \<bar>x\<bar>" by simp
  have claim: "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000"
  proof (cases md)
    case Sig4
    then have td: "to_dec X = Some d" using d by simp
    have "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000" by (rule to_dec_sound[OF xin' td])
    then show ?thesis by linarith
  next
    case Fix3
    then have "to_fixed (- 3) X = Some d" using d by simp
    then have "\<bar>dec_val d - x\<bar> \<le> pow10 (- 3) * (1001 / 2000)" by (rule to_fixed_sound[OF xin'])
    moreover have "pow10 (- 3) = 1 / 1000" by (simp add: pow10_def inverse_eq_divide)
    ultimately show ?thesis using ax by linarith
  next
    case Sig4C
    show ?thesis
    proof (cases "10000 \<le> real_of_float (lower X)")
      case True
      then have f: "to_fixed 0 X = Some d" using d Sig4C by simp
      have b: "\<bar>dec_val d - x\<bar> \<le> pow10 0 * (1001 / 2000)" by (rule to_fixed_sound[OF xin' f])
      have p0: "pow10 0 = 1" by (simp add: pow10_def)
      have lo: "real_of_float (lower X) \<le> x" using xin' by (auto simp: set_of_eq)
      then have "10000 \<le> x" using True by linarith
      then have "\<bar>x\<bar> / 1000 \<ge> 10" by simp
      then show ?thesis using b p0 by linarith
    next
      case False
      then have td: "to_dec X = Some d" using d Sig4C by simp
      have "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000" by (rule to_dec_sound[OF xin' td])
      then show ?thesis by linarith
    qed
  qed
  then show ?thesis by (simp add: x_def)
qed

end
