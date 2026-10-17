theory Climate_Num
  imports "Veri7vn_Climate_Base.Climate_Base"
begin

text \<open>Lane S05-climate: shared numerics for the climate family. Everything in
this theory down to @{text midpoint_close}, and the digit layout at the end, is
copied from lane G (src/extract/quantity/Quantity.thy) unchanged: exact rational
to floating-real glue, decimal rounding with a proved bound, the enclosure of a
real by a verified float interval. The additions are @{text to_fixed} (a fixed
number of decimals from an enclosure) and the fixed-decimal layout the climate
organs print (Python @{text "%.4f"} / @{text "%.3f"} with trailing zeros removed,
whole numbers with commas from 100000 up).\<close>

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

section \<open>Response text (ASCII)\<close>

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



section \<open>Fixed decimals from an enclosure\<close>

text \<open>Round the midpoint of a narrow float interval to @{text dd} decimals, or to a
whole number from 100000 up (the organs print @{text "%.4f"} or @{text "%.3f"},
and a rounded whole number with commas above that). Refuse when the interval is
wider than @{text "10^-9"}. The stated decimal is within half a unit of its last
place of the real value, plus the interval half-width.\<close>
definition to_fixed :: "nat \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed dd X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if hi - lo \<le> 1 / 1000000000 then
       Some (round_at mid (if \<bar>mid\<bar> < 100000 then - int dd else 0))
     else None)"

theorem to_fixed_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed dd X = Some d"
  shows "(snd d = - int dd \<or> snd d = 0) \<and>
         \<bar>dec_val d - x\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  define e where "e = (if \<bar>mid\<bar> < 100000 then - int dd else 0)"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> 1 / 1000000000" and dd: "d = round_at mid e"
    using d by (simp_all add: to_fixed_def Let_def lo_def hi_def mid_def e_def split: if_splits)
  have se: "snd d = e" using dd by (simp add: round_at_def)
  have r: "\<bar>dec_val d - mid\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have m: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2" unfolding mid_def using xin by (rule midpoint_close)
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
  have "(snd d = - int dd \<or> snd d = 0)" using se by (simp add: e_def split: if_splits)
  moreover have "\<bar>dec_val d - x\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
  proof -
    have h1: "\<bar>dec_val d - x\<bar> \<le> pow10 e / 2 + (hi - lo) / 2"
      by (rule order_trans[OF tri add_mono[OF r m]])
    have h2a: "(hi - lo) / 2 \<le> (1 / 1000000000) / 2" using chk by (rule divide_right_mono) simp
    have h2b: "((1::real) / 1000000000) / 2 \<le> 1 / 1000000000" by simp
    have h2: "(hi - lo) / 2 \<le> 1 / 1000000000" by (rule order_trans[OF h2a h2b])
    show ?thesis unfolding se by (rule order_trans[OF h1 add_mono[OF order_refl h2]])
  qed
  ultimately show ?thesis by blast
qed

definition prec :: nat where "prec = 53"

definition enclose_fixed :: "nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose_fixed dd e = (case approx prec e [] of None \<Rightarrow> None | Some X \<Rightarrow> to_fixed dd X)"

lemma enclose_fixed_sound:
  assumes "enclose_fixed dd e = Some d"
  shows "(snd d = - int dd \<or> snd d = 0) \<and>
         \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"
proof -
  obtain X where X: "approx prec e [] = Some X" and d: "to_fixed dd X = Some d"
    using assms by (auto simp: enclose_fixed_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using to_fixed_sound d by blast
qed

text \<open>An exact rational value, rounded the same way (@{text g_dec}); the
fixed-decimal and comma layout of the organs' @{text g}.\<close>
definition g_dec :: "nat \<Rightarrow> rat \<Rightarrow> int \<times> int" where
  "g_dec dd q = round_at (rl q) (if \<bar>q\<bar> < 100000 then - int dd else 0)"

theorem g_dec_sound:
  "(snd (g_dec dd q) = - int dd \<or> snd (g_dec dd q) = 0) \<and>
   \<bar>dec_val (g_dec dd q) - rl q\<bar> \<le> pow10 (snd (g_dec dd q)) / 2"
proof -
  have "snd (g_dec dd q) = (if \<bar>q\<bar> < 100000 then - int dd else 0)" by (simp add: g_dec_def round_at_def)
  then show ?thesis using round_at_error[of "rl q" "if \<bar>q\<bar> < 100000 then - int dd else 0"]
    by (auto simp: g_dec_def split: if_splits)
qed

fun cm :: "nat list \<Rightarrow> nat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "cm [] n acc = acc"
| "cm (d # ds) n acc = cm ds (Suc n) (digit_lit d + (if 0 < n \<and> n mod 3 = 0 then STR '','' else STR '''') + acc)"

definition commas :: "nat \<Rightarrow> String.literal" where
  "commas n = cm (rev (digits n)) 0 (STR '''')"

text \<open>Python's @{text "%.{dd}f"} with trailing zeros stripped (a rounded
decimal @{text "(m, -dd)"}), or a whole number with commas (@{text "(m, 0)"}
from 100000).\<close>
definition fixed_lit :: "int \<times> int \<Rightarrow> String.literal" where
  "fixed_lit d = (case d of (m, e) \<Rightarrow>
     if e = 0 \<and> 100000 \<le> \<bar>m\<bar> then (if m < 0 then STR ''-'' else STR '''') + commas (nat \<bar>m\<bar>)
     else render_dec 20 d)"

definition g_text :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "g_text dd q = fixed_lit (g_dec dd q)"

text \<open>Python's @{text "%g"} (six significant digits).\<close>
definition pct_g :: "rat \<Rightarrow> String.literal" where
  "pct_g q = (case round_sig 6 (rl q) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"

text \<open>@{text "%.{d}f"} of a non-negative multiple of @{text "10^-d"}: all
@{text d} decimals kept.\<close>
definition fixed_pad :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "fixed_pad d q = (let m = nat \<lfloor>q * 10 ^ d\<rfloor>; ds0 = digits m;
       ds = replicate (Suc d - length ds0) 0 @ ds0; k = length ds - d in
     lit (take k ds) + (if d = 0 then STR '''' else STR ''.'' + lit (drop k ds)))"

end
