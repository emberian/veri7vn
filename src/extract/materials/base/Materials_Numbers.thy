theory Materials_Numbers
  imports Materials_Base
begin

text \<open>Number machinery shared by the materials family. The rounding, the
decimal layout and the interval enclosure are lane G's
(src/extract/quantity/Quantity.thy, copied here with the same proofs), with two
additions: a three-digit enclosure (@{text to_dec3}, the water organ prints the
hydrogen-ion concentration with %.3g) and a fixed-point enclosure
(@{text to_fixed}, the additive organ prints volumes with three decimals).\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

section \<open>Interval arithmetic helpers (lane G)\<close>

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

section \<open>Decimals and rounding (lane G)\<close>
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

section \<open>Enclosures\<close>

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

text \<open>Three significant digits from a float interval enclosing a value, or a
refusal when the interval is too wide (lane D's @{text to_dec3}).\<close>
definition to_dec3 :: "float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec3 X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000 then Some (0, 0)
     else let e = sig_exp 3 mid in
       if hi - lo \<le> \<bar>mid\<bar> / 1000000 \<and> 100 * pow10 e \<le> \<bar>mid\<bar> then Some (round_at mid e) else None)"

theorem to_dec3_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec3 X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 100 + 1 / 1000000000"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  show ?thesis
  proof (cases "lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000")
    case True
    then have "d = (0, 0)" using d by (simp add: to_dec3_def Let_def lo_def hi_def)
    then have "dec_val d = 0" by (simp add: dec_val_def)
    then have eq: "\<bar>dec_val d - x\<bar> = \<bar>x\<bar>" by simp
    have "\<bar>x\<bar> \<le> 1 / 1000000000" using True xin by arith
    then show ?thesis using eq by linarith
  next
    case False
    define e where "e = sig_exp 3 mid"
    have chk: "hi - lo \<le> \<bar>mid\<bar> / 1000000" "100 * pow10 e \<le> \<bar>mid\<bar>" and dd: "d = round_at mid e"
      using d False by (simp_all add: to_dec3_def Let_def lo_def hi_def mid_def e_def split: if_splits)
    have r: "\<bar>dec_val d - mid\<bar> \<le> \<bar>mid\<bar> / 200"
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

section \<open>Fixed-point enclosure\<close>

text \<open>An interval around a value, rounded to a fixed number of decimals
@{text "10^e"} when the interval is narrow enough that the midpoint's
rounding is within one unit of the value.\<close>
definition to_fixed :: "int \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed e X = (let lo = real_of_float (lower X); hi = real_of_float (upper X) in
     if hi - lo \<le> pow10 e / 1000 then Some (round_at ((lo + hi) / 2) e) else None)"

lemma snd_round_at [simp]: "snd (round_at x e) = e"
  by (simp add: round_at_def)

theorem to_fixed_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed e X = Some d"
  shows "snd d = e \<and> \<bar>dec_val d - x\<bar> \<le> pow10 e"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> pow10 e / 1000" and dd: "d = round_at ((lo + hi) / 2) e"
    using d by (simp_all add: to_fixed_def Let_def lo_def hi_def split: if_splits)
  have r: "\<bar>dec_val d - (lo + hi) / 2\<bar> \<le> pow10 e / 2"
    unfolding dd by (rule round_at_error)
  have m: "\<bar>(lo + hi) / 2 - x\<bar> \<le> (hi - lo) / 2" by (rule midpoint_close[OF xin])
  have p: "0 < pow10 e" by (rule pow10_pos)
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - (lo + hi) / 2\<bar> + \<bar>(lo + hi) / 2 - x\<bar>"
    by arith
  have s: "snd d = e" by (simp add: dd)
  have sum: "\<bar>dec_val d - x\<bar> \<le> pow10 e / 2 + (hi - lo) / 2"
    by (rule order_trans[OF tri add_mono[OF r m]])
  have half: "pow10 e / 2 + (hi - lo) / 2 \<le> pow10 e"
    using chk p by (simp add: field_simps)
  have "\<bar>dec_val d - x\<bar> \<le> pow10 e" by (rule order_trans[OF sum half])
  with s show ?thesis by simp
qed

section \<open>Layouts and the enclosure of one value\<close>

text \<open>How a decimal is laid out: fixed decimals with trailing zeros stripped,
a whole number with thousands separators, or Python's @{text "%.pg"}.\<close>
datatype layout = Fixed | Commas | Sig nat

fun tol_exact :: "layout \<Rightarrow> int \<times> int \<Rightarrow> real \<Rightarrow> real" where
  "tol_exact Fixed d x = pow10 (snd d) / 2"
| "tol_exact Commas d x = pow10 (snd d) / 2"
| "tol_exact (Sig p) d x = \<bar>x\<bar> / (2 * 10 ^ (p - 1))"

fun tol_approx :: "layout \<Rightarrow> int \<times> int \<Rightarrow> real \<Rightarrow> real" where
  "tol_approx Fixed d x = pow10 (snd d)"
| "tol_approx Commas d x = pow10 (snd d)"
| "tol_approx (Sig p) d x = \<bar>x\<bar> / 10 ^ (p - 1) + 1 / 1000000000"

datatype amode = M_sig3 | M_sig4 | M_add

definition prec :: nat where "prec = 120"

definition enclose :: "amode \<Rightarrow> floatarith \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "enclose m fa = (case approx prec fa [] of None \<Rightarrow> None | Some X \<Rightarrow>
     (case m of
        M_sig3 \<Rightarrow> map_option (\<lambda>d. (d, Sig 3)) (to_dec3 X)
      | M_sig4 \<Rightarrow> map_option (\<lambda>d. (d, Sig 4)) (to_dec X)
      | M_add \<Rightarrow>
          if 1000000 \<le> real_of_float (lower X) then map_option (\<lambda>d. (d, Commas)) (to_fixed 0 X)
          else if real_of_float (upper X) < 1000000 then map_option (\<lambda>d. (d, Fixed)) (to_fixed (-3) X)
          else None))"

theorem enclose_sound:
  assumes "enclose m fa = Some (d, lay)"
  shows "\<bar>dec_val d - interpret_floatarith fa []\<bar> \<le> tol_approx lay d (interpret_floatarith fa [])"
proof -
  obtain X where X: "approx prec fa [] = Some X"
    using assms by (auto simp: enclose_def split: option.splits)
  have mem: "interpret_floatarith fa [] \<in>\<^sub>r X"
  proof -
    have "bounded_by [] []" by (simp add: bounded_by_def)
    from approx[OF this X] show ?thesis .
  qed
  have e3: "(10::real) ^ (3 - 1) = 100" and e4: "(10::real) ^ (4 - 1) = 1000" by simp_all
  show ?thesis
  proof (cases m)
    case M_sig3
    then have h: "map_option (\<lambda>d. (d, Sig 3)) (to_dec3 X) = Some (d, lay)"
      using assms X by (simp add: enclose_def)
    then obtain d3 where d3: "to_dec3 X = Some d3" and dl: "d = d3" "lay = Sig 3"
      by (cases "to_dec3 X") auto
    from to_dec3_sound[OF mem d3] show ?thesis using dl e3 by simp
  next
    case M_sig4
    then have h: "map_option (\<lambda>d. (d, Sig 4)) (to_dec X) = Some (d, lay)"
      using assms X by (simp add: enclose_def)
    then obtain d4 where d4: "to_dec X = Some d4" and dl: "d = d4" "lay = Sig 4"
      by (cases "to_dec X") auto
    from to_dec_sound[OF mem d4] show ?thesis using dl e4 by simp
  next
    case M_add
    show ?thesis
    proof (cases "1000000 \<le> real_of_float (lower X)")
      case True
      then have h: "map_option (\<lambda>d. (d, Commas)) (to_fixed 0 X) = Some (d, lay)"
        using assms X M_add by (simp add: enclose_def)
      then obtain d0 where d0: "to_fixed 0 X = Some d0" and dl: "d = d0" "lay = Commas"
        by (cases "to_fixed 0 X") auto
      from to_fixed_sound[OF mem d0] show ?thesis using dl by simp
    next
      case False
      then have u: "real_of_float (upper X) < 1000000"
        and h: "map_option (\<lambda>d. (d, Fixed)) (to_fixed (-3) X) = Some (d, lay)"
        using assms X M_add by (auto simp: enclose_def split: if_splits)
      then obtain d0 where d0: "to_fixed (-3) X = Some d0" and dl: "d = d0" "lay = Fixed"
        by (cases "to_fixed (-3) X") auto
      from to_fixed_sound[OF mem d0] show ?thesis using dl by simp
    qed
  qed
qed

section \<open>Digits and layouts as text (ASCII)\<close>

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

definition render_fixed :: "int \<times> int \<Rightarrow> String.literal" where
  "render_fixed d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>); p = nat (- e);
         ip = (if p < length ds then take (length ds - p) ds else [0]);
         fr = strip_zeros (if p < length ds then drop (length ds - p) ds
                           else replicate (p - length ds) 0 @ ds)
     in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr))"

fun commas_go :: "nat \<Rightarrow> nat list \<Rightarrow> String.literal" where
  "commas_go n [] = STR ''''"
| "commas_go n (d # ds) = digit_lit d
     + (if 1 < n \<and> (n - 1) mod 3 = 0 then STR '','' else STR '''') + commas_go (n - 1) ds"

definition render_commas :: "int \<Rightarrow> String.literal" where
  "render_commas m = (if m < 0 then STR ''-'' else STR '''')
     + commas_go (length (digits (nat \<bar>m\<bar>))) (digits (nat \<bar>m\<bar>))"

definition render_layout :: "layout \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_layout lay d = (case lay of
       Fixed \<Rightarrow> render_fixed d
     | Commas \<Rightarrow> render_commas (fst d)
     | Sig p \<Rightarrow> render_dec p d)"

text \<open>The same decimal as a JSON number token (no thousands separators).\<close>
definition render_json :: "layout \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_json lay d = (case lay of
       Fixed \<Rightarrow> render_fixed d
     | Commas \<Rightarrow> show_int (fst d)
     | Sig p \<Rightarrow> render_dec p d)"

section \<open>Stated values of exact results\<close>

text \<open>The four organs print their numbers differently. The additive organ
prints three decimals (a whole number with separators from 10^6 up), the soil
organ three decimals, the materials organ four decimals from 1 up to 10^6 and
four significant digits otherwise, the water organ four significant digits
(a whole number from 1000 up with separators).\<close>
datatype family = Fam_add | Fam_mat | Fam_soil | Fam_water

definition is_int :: "rat \<Rightarrow> bool" where
  "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

definition st_fixed :: "int \<Rightarrow> rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_fixed e q = Some (round_at (rl q) e, Fixed)"

definition st_commas :: "rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_commas q = Some (round_at (rl q) 0, Commas)"

definition st_int :: "rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_int q = (if is_int q then Some ((fst (quotient_of q), 0), Commas) else None)"

definition st_sig :: "rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_sig q = (case round_sig 4 (rl q) of Some d \<Rightarrow> Some (d, Sig 4) | None \<Rightarrow> None)"

definition stated_of :: "family \<Rightarrow> rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "stated_of f q = (case f of
      Fam_add \<Rightarrow> if \<bar>q\<bar> < 1000000 then st_fixed (-3) q else st_commas q
    | Fam_soil \<Rightarrow> st_fixed (-3) q
    | Fam_mat \<Rightarrow> if 1 \<le> \<bar>q\<bar> \<and> \<bar>q\<bar> < 1000000 then st_fixed (-4) q else st_sig q
    | Fam_water \<Rightarrow> if 1000 \<le> \<bar>q\<bar> \<and> is_int q then st_int q
                   else if \<bar>q\<bar> < 1000000 then st_sig q else st_commas q)"

definition ok_st :: "((int \<times> int) \<times> layout) option \<Rightarrow> rat \<Rightarrow> bool" where
  "ok_st r q \<longleftrightarrow> (\<forall>d lay. r = Some (d, lay) \<longrightarrow> \<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q))"

lemma ok_fixed: "ok_st (st_fixed e q) q"
proof (unfold ok_st_def st_fixed_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume "Some (round_at (rl q) e, Fixed) = Some (d, lay)"
  then have d: "d = round_at (rl q) e" and lay: "lay = Fixed" by simp_all
  have h: "\<bar>dec_val (round_at (rl q) e) - rl q\<bar> \<le> pow10 e / 2" by (rule round_at_error)
  show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)"
    unfolding d lay tol_exact.simps snd_round_at by (rule h)
qed

lemma ok_commas: "ok_st (st_commas q) q"
proof (unfold ok_st_def st_commas_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume "Some (round_at (rl q) 0, Commas) = Some (d, lay)"
  then have d: "d = round_at (rl q) 0" and lay: "lay = Commas" by simp_all
  have h: "\<bar>dec_val (round_at (rl q) 0) - rl q\<bar> \<le> pow10 0 / 2" by (rule round_at_error)
  show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)"
    unfolding d lay tol_exact.simps snd_round_at by (rule h)
qed

lemma ok_int: "ok_st (st_int q) q"
proof (unfold ok_st_def st_int_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume h: "(if is_int q then Some ((fst (quotient_of q), 0), Commas) else None) = Some (d, lay)"
  then have isi: "is_int q" and d: "d = (fst (quotient_of q), (0::int))" and lay: "lay = Commas"
    by (auto split: if_splits)
  obtain a b where ab: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have b: "b = 1" using isi by (simp add: is_int_def)
  have "q = of_int a / of_int b" using ab by (rule quotient_of_div)
  then have qa: "rl q = of_int a" using b by simp
  have "dec_val d = rl q" using d ab qa by (simp add: dec_val_def pow10_def)
  then show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)" by (simp add: lay less_imp_le[OF pow10_pos])
qed

lemma ok_sig: "ok_st (st_sig q) q"
proof (unfold ok_st_def st_sig_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume h: "(case round_sig 4 (rl q) of None \<Rightarrow> None | Some d \<Rightarrow> Some (d, Sig 4)) = Some (d, lay)"
  then obtain d0 where r: "round_sig 4 (rl q) = Some d0" and d: "d = d0" and lay: "lay = Sig 4"
    by (cases "round_sig 4 (rl q)") auto
  from round_sig_sound[OF r] have "\<bar>dec_val d0 - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" .
  then show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)" by (simp add: d lay)
qed

theorem stated_of_sound: "ok_st (stated_of f q) q"
  by (cases f) (simp_all add: stated_of_def ok_fixed ok_commas ok_int ok_sig split: if_splits)

definition shw :: "family \<Rightarrow> rat \<Rightarrow> String.literal" where
  "shw f q = (case stated_of f q of Some (d, lay) \<Rightarrow> render_layout lay d | None \<Rightarrow> STR ''?'')"

end
