theory Energy_Core
  imports "Veri7vn_Energy_Base.Energy_Base"
begin

text \<open>
  Shared machinery of the energy family (lane S06-energy): verified rounding to
  significant digits and to fixed decimals, the number layouts the six organs
  print, a generic four-stage kernel with its soundness theorems, and the reply
  record. The rounding and interval pieces are copied from lane G
  (src/extract/quantity/Quantity.thy, sections on executable enclosure and
  response text); the statements are unchanged.
\<close>

section \<open>Interval enclosure and rounding (copied from lane G)\<close>

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

definition prec :: nat where "prec = 53"

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

section \<open>Digits and layout (copied from lane G)\<close>

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

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"

section \<open>Number layouts\<close>

text \<open>The six organs print numbers in five different ways. G4 is Python's
@{text "%.4g"} (thermo). G4W is @{text "%.4g"} below a million and @{text "%.0f"}
above (home energy). G4C is @{text "%.4g"} below ten thousand and a rounded
whole number with thousands commas above (hvac). F3C and F4C are @{text "%.3f"}
and @{text "%.4f"} with trailing zeros stripped below ten thousand (a hundred
thousand), and the commas form above (renewables, iot). G6 is @{text "%g"}
(a tariff). M2 is a money amount: two decimals below 1000, whole with commas
above. An exact decimal tie rounds up (lane G's @{text round_tie_up}); Python's
@{text round} and @{text "%f"} round a binary tie to even.\<close>
datatype nfmt = G4 | G4W | G4C | F3C | F4C | G6 | M2 | FINT

definition num_dec_r :: "nfmt \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "num_dec_r f x = (case f of
      G4 \<Rightarrow> round_sig 4 x
    | G4W \<Rightarrow> if \<bar>x\<bar> < 10 ^ 6 then round_sig 4 x else Some (round_at x 0)
    | G4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then round_sig 4 x else Some (round_at x 0)
    | F3C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then Some (round_at x (-3)) else Some (round_at x 0)
    | F4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 5 then Some (round_at x (-4)) else Some (round_at x 0)
    | G6 \<Rightarrow> round_sig 6 x
    | M2 \<Rightarrow> if x < 1000 then Some (round_at x (-2)) else Some (round_at x 0)
    | FINT \<Rightarrow> Some (round_at x 0))"

definition fmt_err_r :: "nfmt \<Rightarrow> real \<Rightarrow> real" where
  "fmt_err_r f x = (case f of
      G4 \<Rightarrow> \<bar>x\<bar> / (2 * 10 ^ (4 - 1))
    | G4W \<Rightarrow> if \<bar>x\<bar> < 10 ^ 6 then \<bar>x\<bar> / (2 * 10 ^ (4 - 1)) else pow10 0 / 2
    | G4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then \<bar>x\<bar> / (2 * 10 ^ (4 - 1)) else pow10 0 / 2
    | F3C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then pow10 (-3) / 2 else pow10 0 / 2
    | F4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 5 then pow10 (-4) / 2 else pow10 0 / 2
    | G6 \<Rightarrow> \<bar>x\<bar> / (2 * 10 ^ (6 - 1))
    | M2 \<Rightarrow> if x < 1000 then pow10 (-2) / 2 else pow10 0 / 2
    | FINT \<Rightarrow> pow10 0 / 2)"

theorem num_dec_r_sound:
  assumes "num_dec_r f x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> fmt_err_r f x"
proof (cases f)
  case G4
  then have h: "round_sig 4 x = Some d" using assms by (simp add: num_dec_r_def)
  show ?thesis using round_sig_sound[OF h] G4 by (simp add: fmt_err_r_def)
next
  case G4W
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 6")
    case True
    then have h: "round_sig 4 x = Some d" using assms G4W by (simp add: num_dec_r_def)
    show ?thesis using round_sig_sound[OF h] G4W True by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms G4W by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] G4W False h by (simp add: fmt_err_r_def)
  qed
next
  case G4C
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 4")
    case True
    then have h: "round_sig 4 x = Some d" using assms G4C by (simp add: num_dec_r_def)
    show ?thesis using round_sig_sound[OF h] G4C True by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms G4C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] G4C False h by (simp add: fmt_err_r_def)
  qed
next
  case F3C
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 4")
    case True
    then have h: "d = round_at x (-3)" using assms F3C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x "-3"] F3C True h by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms F3C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] F3C False h by (simp add: fmt_err_r_def)
  qed
next
  case F4C
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 5")
    case True
    then have h: "d = round_at x (-4)" using assms F4C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x "-4"] F4C True h by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms F4C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] F4C False h by (simp add: fmt_err_r_def)
  qed
next
  case G6
  then have h: "round_sig 6 x = Some d" using assms by (simp add: num_dec_r_def)
  show ?thesis using round_sig_sound[OF h] G6 by (simp add: fmt_err_r_def)
next
  case M2
  show ?thesis
  proof (cases "x < 1000")
    case True
    then have h: "d = round_at x (-2)" using assms M2 by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x "-2"] M2 True h by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms M2 by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] M2 False h by (simp add: fmt_err_r_def)
  qed
next
  case FINT
  then have h: "d = round_at x 0" using assms by (simp add: num_dec_r_def)
  show ?thesis using round_at_error[of x 0] FINT h by (simp add: fmt_err_r_def)
qed

fun rgroups :: "nat list \<Rightarrow> nat list list" where
  "rgroups [] = []"
| "rgroups [a] = [[a]]"
| "rgroups [a, b] = [[a, b]]"
| "rgroups (a # b # c # ds) = [a, b, c] # rgroups ds"

fun join_commas :: "String.literal list \<Rightarrow> String.literal" where
  "join_commas [] = STR ''''"
| "join_commas [x] = x"
| "join_commas (x # y # zs) = x + STR '','' + join_commas (y # zs)"

definition commas :: "int \<Rightarrow> String.literal" where
  "commas i = (if i < 0 then STR ''-'' else STR '''') +
     join_commas (rev (map (\<lambda>g. lit (rev g)) (rgroups (rev (digits (nat \<bar>i\<bar>))))))"

definition fixed2 :: "int \<Rightarrow> String.literal" where
  "fixed2 n = (if n < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>n\<bar> div 100)) + STR ''.''
     + lit [(nat \<bar>n\<bar> mod 100) div 10, (nat \<bar>n\<bar> mod 100) mod 10]"

definition layout :: "nfmt \<Rightarrow> real \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "layout f x d = (case f of
      G4 \<Rightarrow> render_dec 4 d
    | G4W \<Rightarrow> if \<bar>x\<bar> < 10 ^ 6 then render_dec 4 d else show_int (fst d)
    | G4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then render_dec 4 d else commas (fst d)
    | F3C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then render_dec 100 d else commas (fst d)
    | F4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 5 then render_dec 100 d else commas (fst d)
    | G6 \<Rightarrow> render_dec 6 d
    | M2 \<Rightarrow> if x < 1000 then fixed2 (fst d) else commas (fst d)
    | FINT \<Rightarrow> show_int (fst d))"

definition show_fmt :: "nfmt \<Rightarrow> real \<Rightarrow> String.literal option" where
  "show_fmt f x = (case num_dec_r f x of None \<Rightarrow> None | Some d \<Rightarrow> Some (layout f x d))"

theorem show_fmt_sound:
  assumes "show_fmt f x = Some s"
  shows "\<exists>d. num_dec_r f x = Some d \<and> s = layout f x d \<and> \<bar>dec_val d - x\<bar> \<le> fmt_err_r f x"
  using assms num_dec_r_sound by (auto simp: show_fmt_def split: option.splits)

text \<open>A secondary number in a reply (an input or a by-product).\<close>
definition gf :: "nfmt \<Rightarrow> rat \<Rightarrow> String.literal" where
  "gf f q = (case show_fmt f (rl q) of Some s \<Rightarrow> s | None \<Rightarrow> STR ''?'')"

abbreviation gs :: "rat \<Rightarrow> String.literal" where "gs \<equiv> gf G4"

section \<open>Multiples of pi and power units\<close>

text \<open>The rotor area pi (D/2)^2 and the wind power are rational multiples of pi.
Their decimals come from Isabelle's verified interval arithmetic, never from a
float computed here.\<close>
definition pi_bounds :: "rat \<Rightarrow> (real \<times> real) option" where
  "pi_bounds c = (case approx prec (floatarith.Mult (Q c) floatarith.Pi) [] of
       None \<Rightarrow> None | Some X \<Rightarrow> Some (real_of_float (lower X), real_of_float (upper X)))"

theorem pi_bounds_sound:
  assumes "pi_bounds c = Some (lo, hi)"
  shows "lo \<le> rl c * pi \<and> rl c * pi \<le> hi"
proof -
  from assms obtain X where X: "approx prec (floatarith.Mult (Q c) floatarith.Pi) [] = Some X"
    and lo: "lo = real_of_float (lower X)" and hi: "hi = real_of_float (upper X)"
    by (auto simp: pi_bounds_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith (floatarith.Mult (Q c) floatarith.Pi) [] \<in>\<^sub>r X" .
  then have "rl c * pi \<in>\<^sub>r X" by simp
  then show ?thesis using lo hi by (auto simp: set_of_eq)
qed

definition pi_fmt :: "nfmt \<Rightarrow> rat \<Rightarrow> String.literal option" where
  "pi_fmt f c = (case pi_bounds c of None \<Rightarrow> None | Some (lo, hi) \<Rightarrow> show_fmt f ((lo + hi) / 2))"

text \<open>The unit of a power: GW, MW, kW or W by the size of the value, refused
when the enclosure straddles a unit boundary.\<close>
definition pw_scale :: "real \<Rightarrow> real \<Rightarrow> (real \<times> nat) option" where
  "pw_scale lo hi = (if 10 ^ 9 \<le> lo then Some (10 ^ 9, 3) else if 10 ^ 9 \<le> hi then None
     else if 10 ^ 6 \<le> lo then Some (10 ^ 6, 2) else if 10 ^ 6 \<le> hi then None
     else if 10 ^ 3 \<le> lo then Some (10 ^ 3, 1) else if 10 ^ 3 \<le> hi then None
     else Some (1, 0))"

theorem pw_scale_sound:
  assumes "pw_scale lo hi = Some (s, i)"
  shows "0 < s \<and> (s = 1 \<or> s \<le> lo) \<and> (hi < 1000 * s \<or> i = 3)"
  using assms by (auto simp: pw_scale_def split: if_splits)

definition pw_label :: "bool \<Rightarrow> nat \<Rightarrow> String.literal" where
  "pw_label en i = (if i = 3 then STR ''G'' else if i = 2 then STR ''M'' else if i = 1 then STR ''k'' else STR '''')
     + (if en then STR ''Wh'' else STR ''W'')"

definition pw_show :: "bool \<Rightarrow> real \<Rightarrow> real \<Rightarrow> String.literal option" where
  "pw_show en lo hi = (case pw_scale lo hi of None \<Rightarrow> None | Some (s, i) \<Rightarrow>
     (case show_fmt F3C ((lo + hi) / 2 / s) of None \<Rightarrow> None
      | Some n \<Rightarrow> Some (n + STR '' '' + pw_label en i)))"

theorem pw_show_sound:
  assumes "pw_show en lo hi = Some t"
  shows "\<exists>s i d. pw_scale lo hi = Some (s, i) \<and> num_dec_r F3C ((lo + hi) / 2 / s) = Some d \<and>
         \<bar>dec_val d - (lo + hi) / 2 / s\<bar> \<le> fmt_err_r F3C ((lo + hi) / 2 / s)"
proof -
  from assms obtain s i n where s: "pw_scale lo hi = Some (s, i)" and n: "show_fmt F3C ((lo + hi) / 2 / s) = Some n"
    by (auto simp: pw_show_def split: option.splits)
  from show_fmt_sound[OF n] show ?thesis using s by blast
qed

lemma pos_ne: "0 < (x::rat) \<Longrightarrow> x \<noteq> 0"
  by (metis less_irrefl)

section \<open>Outcomes and the generic kernel\<close>

text \<open>An outcome is an exact rational value of a named kind, a rational multiple
of pi (rotor areas and wind power), an answer with no number, or a decline.
A decline carries its class and the words the reply uses.\<close>
datatype dcl = D_under | D_imposs | D_sizing | D_tariff

datatype outcome =
    Exact String.literal rat
  | PiMul String.literal rat
  | Fixed String.literal
  | Decline dcl String.literal

text \<open>Four stages in the order the organs test: an up-front impossibility
(@{text pre}), a missing quantity (@{text miss}, always underspecified), a late
impossibility or other refusal (@{text post}), an answer without a number
(@{text fx}); otherwise the value.\<close>
definition mk_kernel ::
  "('r \<Rightarrow> (dcl \<times> String.literal) option) \<Rightarrow> ('r \<Rightarrow> String.literal option) \<Rightarrow>
   ('r \<Rightarrow> (dcl \<times> String.literal) option) \<Rightarrow> ('r \<Rightarrow> String.literal option) \<Rightarrow>
   ('r \<Rightarrow> String.literal) \<Rightarrow> ('r \<Rightarrow> rat) \<Rightarrow> ('r \<Rightarrow> bool) \<Rightarrow> 'r \<Rightarrow> outcome" where
  "mk_kernel pre miss post fx kd vl pf r =
     (case pre r of Some (d, w) \<Rightarrow> Decline d w | None \<Rightarrow>
      (case miss r of Some w \<Rightarrow> Decline D_under w | None \<Rightarrow>
       (case post r of Some (d, w) \<Rightarrow> Decline d w | None \<Rightarrow>
        (case fx r of Some k \<Rightarrow> Fixed k | None \<Rightarrow>
         (if pf r then PiMul (kd r) (vl r) else Exact (kd r) (vl r))))))"

theorem mk_exact:
  "mk_kernel pre miss post fx kd vl pf r = Exact k q \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = None \<and> \<not> pf r \<and> k = kd r \<and> q = vl r"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

theorem mk_pi:
  "mk_kernel pre miss post fx kd vl pf r = PiMul k q \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = None \<and> pf r \<and> k = kd r \<and> q = vl r"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

theorem mk_fixed:
  "mk_kernel pre miss post fx kd vl pf r = Fixed k \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = Some k"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

theorem mk_decline:
  "mk_kernel pre miss post fx kd vl pf r = Decline d w \<longleftrightarrow>
     pre r = Some (d, w) \<or> (pre r = None \<and> miss r = Some w \<and> d = D_under) \<or>
     (pre r = None \<and> miss r = None \<and> post r = Some (d, w))"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

section \<open>Replies\<close>

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition dcl_name :: "dcl \<Rightarrow> String.literal" where
  "dcl_name d = (case d of D_under \<Rightarrow> STR ''underspecified'' | D_imposs \<Rightarrow> STR ''impossible''
     | D_sizing \<Rightarrow> STR ''sizing'' | D_tariff \<Rightarrow> STR ''need_tariff'')"

definition decline_text :: "dcl \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "decline_text d w = (case d of
       D_under \<Rightarrow> STR ''I need '' + w + STR '' to work that out; I won'' + apos + STR ''t assume it.''
     | _ \<Rightarrow> w)"

definition imprecise_text :: String.literal where
  "imprecise_text = STR ''The interval arithmetic could not pin the digits; I won'' + apos + STR ''t guess.''"

text \<open>@{text shw} writes the stated number (None when the layout cannot be
decided), @{text ext} puts it in the sentence, @{text pit} writes a whole
sentence for a multiple of pi, @{text fxt} the sentence of an answer without a
number.\<close>
definition mk_reply ::
  "('r \<Rightarrow> outcome) \<Rightarrow> ('r \<Rightarrow> rat \<Rightarrow> String.literal option) \<Rightarrow> ('r \<Rightarrow> bool) \<Rightarrow>
   ('r \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal) \<Rightarrow> ('r \<Rightarrow> rat \<Rightarrow> String.literal option) \<Rightarrow>
   ('r \<Rightarrow> String.literal \<Rightarrow> String.literal) \<Rightarrow> 'r \<Rightarrow> reply" where
  "mk_reply kn shw plain ext pit fxt r = (case kn r of
       Exact k q \<Rightarrow> (case shw r q of
           None \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None
         | Some V \<Rightarrow> Reply True k (ext r q V) (if plain r then Some V else None))
     | PiMul k c \<Rightarrow> (case pit r c of
           None \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None
         | Some s \<Rightarrow> Reply True k s None)
     | Fixed k \<Rightarrow> Reply True k (fxt r k) None
     | Decline d w \<Rightarrow> Reply False (dcl_name d) (decline_text d w) None)"

theorem mk_reply_answered_iff:
  "answered (mk_reply kn shw plain ext pit fxt r) \<longleftrightarrow>
     (\<exists>k q V. kn r = Exact k q \<and> shw r q = Some V) \<or> (\<exists>k c s. kn r = PiMul k c \<and> pit r c = Some s) \<or>
     (\<exists>k. kn r = Fixed k)"
  by (auto simp: mk_reply_def split: outcome.splits option.splits)

theorem mk_reply_exact:
  "kn r = Exact k q \<Longrightarrow> shw r q = Some V \<Longrightarrow>
     response (mk_reply kn shw plain ext pit fxt r) = ext r q V \<and>
     reply_kind (mk_reply kn shw plain ext pit fxt r) = k"
  by (simp add: mk_reply_def)

theorem mk_reply_withheld:
  "kn r = Decline d w \<Longrightarrow>
     \<not> answered (mk_reply kn shw plain ext pit fxt r) \<and>
     response (mk_reply kn shw plain ext pit fxt r) = decline_text d w \<and>
     reply_kind (mk_reply kn shw plain ext pit fxt r) = dcl_name d"
  by (simp add: mk_reply_def)

end
