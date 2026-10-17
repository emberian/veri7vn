theory Emoptics_Num
  imports "Veri7vn_Emoptics_Base.Emoptics_Base"
begin

text \<open>Numerics shared by the whole family, copied from lane G
(src/extract/quantity/Quantity.thy: enclosure, decimal rounding, the layout of
decimals as text), plus what this family adds: the sign of an enclosed real, a
square root of an exact rational, sine in degrees, arc sine, and the powers the
AWG gauge law needs. Nothing here depends on a request or a kind.\<close>

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

text \<open>A secondary number in a reply (an input or a by-product), four digits.\<close>
definition show4 :: "rat \<Rightarrow> String.literal" where
  "show4 q = (case round_sig 4 (rl q) of Some d \<Rightarrow> render_dec 4 d | None \<Rightarrow> STR ''?'')"

text \<open>A number the question gave, echoed as written (up to 15 digits).\<close>
definition show_input :: "rat \<Rightarrow> String.literal" where
  "show_input q = (if snd (quotient_of q) = 1 then show_int (fst (quotient_of q))
     else case round_sig 15 (rl q) of Some d \<Rightarrow> render_dec 15 d | None \<Rightarrow> STR ''?'')"

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"

section \<open>More enclosure building blocks (this lane)\<close>

text \<open>The sign of an enclosed real: @{text "Some True"} when the float interval
lies strictly above zero, @{text "Some False"} when strictly below.\<close>
definition sign_of :: "floatarith \<Rightarrow> bool option" where
  "sign_of e = (case approx prec e [] of None \<Rightarrow> None
     | Some X \<Rightarrow> if 0 < real_of_float (lower X) then Some True
                 else if real_of_float (upper X) < 0 then Some False else None)"

lemma sign_of_pos:
  assumes "sign_of e = Some True"
  shows "0 < interpret_floatarith e []"
proof -
  obtain X where X: "approx prec e [] = Some X" and l: "0 < real_of_float (lower X)"
    using assms by (auto simp: sign_of_def split: option.splits if_splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have x: "interpret_floatarith e [] \<in>\<^sub>r X" .
  have "real_of_float (lower X) \<le> interpret_floatarith e []" using x by (auto simp: set_of_eq)
  then show ?thesis using l by linarith
qed

lemma sign_of_neg:
  assumes "sign_of e = Some False"
  shows "interpret_floatarith e [] < 0"
proof -
  obtain X where X: "approx prec e [] = Some X" and u: "real_of_float (upper X) < 0"
    using assms by (auto simp: sign_of_def split: option.splits if_splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have x: "interpret_floatarith e [] \<in>\<^sub>r X" .
  have "interpret_floatarith e [] \<le> real_of_float (upper X)" using x by (auto simp: set_of_eq)
  then show ?thesis using u by linarith
qed

text \<open>Building blocks of floatarith terms with their meaning. @{text Sqq} is
the square root of a non-negative rational (the constant zero when the
rational is zero, so the term never asks the enclosure for the square root of
a zero-width interval around zero); @{text Sm} a difference.\<close>
definition Sqq :: "rat \<Rightarrow> floatarith" where
  "Sqq q = (if 0 < q then floatarith.Sqrt (Q q) else I 0)"

lemma interp_Sqq [simp]:
  assumes "0 \<le> q"
  shows "interpret_floatarith (Sqq q) xs = sqrt (rl q)"
proof (cases "0 < q")
  case True
  then show ?thesis by (simp add: Sqq_def)
next
  case False
  then have "q = 0" using assms by linarith
  then show ?thesis by (simp add: Sqq_def)
qed

definition Sm :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where
  "Sm a b = floatarith.Add a (floatarith.Minus b)"

lemma interp_Sm [simp]:
  "interpret_floatarith (Sm a b) xs = interpret_floatarith a xs - interpret_floatarith b xs"
  by (simp add: Sm_def)

text \<open>Sine of an angle given in degrees: @{text "sin (t pi / 180)"}, as
@{text "cos (pi/2 - x)"}.\<close>
definition SinDeg :: "rat \<Rightarrow> floatarith" where
  "SinDeg t = floatarith.Cos (Sm (floatarith.Mult floatarith.Pi (floatarith.Inverse (I 2)))
      (floatarith.Mult (floatarith.Mult floatarith.Pi (floatarith.Inverse (I 180))) (Q t)))"

lemma cos_half_pi_minus: "cos (pi / 2 - x) = sin x"
  by (simp add: cos_diff)

lemma interp_SinDeg [simp]: "interpret_floatarith (SinDeg t) xs = sin (pi * rl t / 180)"
proof -
  have "interpret_floatarith (SinDeg t) xs = cos (pi * inverse 2 - pi * inverse 180 * rl t)"
    by (simp add: SinDeg_def)
  also have "pi * inverse 2 - pi * inverse 180 * rl t = pi / 2 - pi * rl t / 180"
    by (simp add: field_simps)
  also have "cos (pi / 2 - pi * rl t / 180) = sin (pi * rl t / 180)" by (rule cos_half_pi_minus)
  finally show ?thesis .
qed

text \<open>Arc sine, in degrees, of a real in the open interval (-1, 1), as
@{text "arctan (x / sqrt (1 - x^2))"}.\<close>
definition ArcsinDeg :: "floatarith \<Rightarrow> floatarith" where
  "ArcsinDeg x = floatarith.Mult (floatarith.Mult (I 180) (floatarith.Inverse floatarith.Pi))
     (floatarith.Arctan (floatarith.Mult x (floatarith.Inverse (floatarith.Sqrt
        (Sm (I 1) (floatarith.Mult x x))))))"

lemma interp_ArcsinDeg:
  assumes "-1 < interpret_floatarith x xs" "interpret_floatarith x xs < 1"
  shows "interpret_floatarith (ArcsinDeg x) xs = 180 / pi * arcsin (interpret_floatarith x xs)"
proof -
  define y where "y = interpret_floatarith x xs"
  have y1: "-1 < y" and y2: "y < 1" using assms by (simp_all add: y_def)
  have a: "arcsin y = arctan (y / sqrt (1 - y\<^sup>2))" by (rule arcsin_arctan[OF y1 y2])
  show ?thesis
    by (simp add: ArcsinDeg_def y_def[symmetric] a power2_eq_square divide_inverse mult.assoc)
qed

lemma interp_ArcsinDeg_Q:
  assumes "-1 < rl q" "rl q < 1"
  shows "interpret_floatarith (ArcsinDeg (Q q)) xs = 180 / pi * arcsin (rl q)"
proof -
  have h: "interpret_floatarith (ArcsinDeg (Q q)) xs = 180 / pi * arcsin (interpret_floatarith (Q q) xs)"
    by (rule interp_ArcsinDeg) (use assms in simp_all)
  show ?thesis by (rule h[unfolded interp_Q])
qed

end
