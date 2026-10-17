theory GeoStats_Num
  imports "Veri7vn_GeoStats_Base.GeoStats_Base" "HOL-Library.Multiset"
begin

text \<open>
  The numeric layer shared by the geometry and statistics kernels: exact
  rational values are rounded with a proved bound; a value that is a multiple
  of pi or a square root is enclosed in a verified interval
  (HOL-Decision_Procs.Approximation) and then rounded; both are laid out as
  text the way Python's @{text "%.6g"} and @{text "%.4f"} lay them out.

  The rounding lemmas from @{text pow10} to @{text midpoint_close} are copied
  from lane G (src/extract/quantity/Quantity.thy), which proved them; the
  six-digit enclosure is the same proof as lane G's four-digit one with the
  constants changed.
\<close>

section \<open>Rounding and enclosure\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

definition fI :: "int \<Rightarrow> floatarith" where "fI i = floatarith.Num (Float i 0)"

definition fQ :: "rat \<Rightarrow> floatarith" where
  "fQ q = (case quotient_of q of (a, b) \<Rightarrow> floatarith.Mult (fI a) (floatarith.Inverse (fI b)))"

lemma interp_fI [simp]: "interpret_floatarith (fI i) xs = of_int i"
  by (simp add: fI_def)

lemma interp_fQ [simp]: "interpret_floatarith (fQ q) xs = rl q"
proof -
  obtain a b where qa: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have "q = of_int a / of_int b" by (rule quotient_of_div)
  then have "rl q = of_int a / of_int b" by (simp add: of_rat_divide)
  then show ?thesis by (simp add: fQ_def qa divide_inverse)
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

text \<open>Six significant digits from a float interval enclosing a value (the
geometry organ's @{text "%.6g"}), or a refusal when the interval is too wide.\<close>
definition to_dec6 :: "float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec6 X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000 then Some (0, 0)
     else let e = sig_exp 6 mid in
       if hi - lo \<le> \<bar>mid\<bar> / 100000000 \<and> 100000 * pow10 e \<le> \<bar>mid\<bar> then Some (round_at mid e) else None)"

theorem to_dec6_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec6 X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 100000 + 1 / 1000000000"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  show ?thesis
  proof (cases "lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000")
    case True
    then have "d = (0, 0)" using d by (simp add: to_dec6_def Let_def lo_def hi_def)
    then have "dec_val d = 0" by (simp add: dec_val_def)
    then have eq: "\<bar>dec_val d - x\<bar> = \<bar>x\<bar>" by simp
    have "\<bar>x\<bar> \<le> 1 / 1000000000" using True xin by arith
    then show ?thesis using eq by linarith
  next
    case False
    define e where "e = sig_exp 6 mid"
    have chk: "hi - lo \<le> \<bar>mid\<bar> / 100000000" "100000 * pow10 e \<le> \<bar>mid\<bar>" and dd: "d = round_at mid e"
      using d False by (simp_all add: to_dec6_def Let_def lo_def hi_def mid_def e_def split: if_splits)
    have r: "\<bar>dec_val d - mid\<bar> \<le> \<bar>mid\<bar> / 200000"
      unfolding dd using round_at_error[of mid e] chk(2) by linarith
    have m1: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2"
      unfolding mid_def using xin by (rule midpoint_close)
    have m2a: "(hi - lo) / 2 \<le> (\<bar>mid\<bar> / 100000000) / 2"
      using chk(1) by (rule divide_right_mono) simp
    have m2: "(hi - lo) / 2 \<le> \<bar>mid\<bar> / 200000000" using m2a by simp
    have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
    have M: "\<bar>mid\<bar> \<le> \<bar>x\<bar> + \<bar>mid - x\<bar>" by arith
    show ?thesis using r m1 m2 tri M abs_ge_zero[of x] by linarith
  qed
qed

definition prec :: nat where "prec = 53"

definition enc6 :: "floatarith \<Rightarrow> (int \<times> int) option" where
  "enc6 e = (case approx prec e [] of None \<Rightarrow> None | Some X \<Rightarrow> to_dec6 X)"

lemma enc6_sound:
  assumes "enc6 e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 100000 + 1 / 1000000000"
proof -
  obtain X where X: "approx prec e [] = Some X" and d: "to_dec6 X = Some d"
    using assms by (auto simp: enc6_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using to_dec6_sound d by blast
qed

text \<open>Four decimals, fixed layout (the statistics organ's @{text "%.4f"}). The
stated number is the integer @{text m} that stands for @{text "m / 10000"}.\<close>
lemma half_round_close:
  fixes y :: "'a::floor_ceiling"
  shows "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> \<le> 1 / 2"
proof (rule abs_leI)
  have lo: "of_int \<lfloor>y + 1 / 2\<rfloor> \<le> y + 1 / 2" by (rule of_int_floor_le)
  have hi: "y + 1 / 2 < of_int \<lfloor>y + 1 / 2\<rfloor> + 1"
    using floor_correct[of "y + 1 / 2"] by (simp add: of_int_add)
  show "of_int \<lfloor>y + 1 / 2\<rfloor> - y \<le> 1 / 2" using lo by linarith
  show "- (of_int \<lfloor>y + 1 / 2\<rfloor> - y) \<le> 1 / 2" using hi by linarith
qed

definition fix4 :: "rat \<Rightarrow> int" where "fix4 q = \<lfloor>q * 10000 + 1 / 2\<rfloor>"

theorem fix4_sound: "\<bar>of_int (fix4 q) - q * 10000\<bar> \<le> 1 / 2"
  unfolding fix4_def by (rule half_round_close)

definition fix4_dec :: "float interval \<Rightarrow> int option" where
  "fix4_dec X = (let lo = real_of_float (lower X); hi = real_of_float (upper X) in
     if hi - lo \<le> 1 / 1000000 then Some \<lfloor>(lo + hi) / 2 * 10000 + 1 / 2\<rfloor> else None)"

theorem fix4_dec_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "fix4_dec X = Some m"
  shows "\<bar>real_of_int m - x * 10000\<bar> \<le> 51 / 100"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> 1 / 1000000" and mm: "m = \<lfloor>(lo + hi) / 2 * 10000 + 1 / 2\<rfloor>"
    using d by (simp_all add: fix4_dec_def Let_def lo_def hi_def split: if_splits)
  have r: "\<bar>real_of_int m - (lo + hi) / 2 * 10000\<bar> \<le> 1 / 2"
    unfolding mm by (rule half_round_close)
  have c: "\<bar>(lo + hi) / 2 - x\<bar> \<le> (hi - lo) / 2" by (rule midpoint_close[OF xin])
  define A where "A = (lo + hi) / 2 - x"
  have d: "(lo + hi) / 2 * 10000 - x * 10000 = A * 10000" by (simp add: A_def algebra_simps)
  have e: "\<bar>(lo + hi) / 2 * 10000 - x * 10000\<bar> = \<bar>A\<bar> * 10000"
  proof -
    have "\<bar>A * 10000\<bar> = \<bar>A\<bar> * \<bar>10000::real\<bar>" by (rule abs_mult)
    then show ?thesis unfolding d by simp
  qed
  have c': "\<bar>A\<bar> \<le> (hi - lo) / 2" using c by (simp add: A_def)
  have k1: "\<bar>A\<bar> * 10000 \<le> (hi - lo) / 2 * 10000" using c' by (rule mult_right_mono) simp
  have k2: "(hi - lo) / 2 * 10000 \<le> (1 / 1000000) / 2 * 10000"
    using chk by (intro mult_right_mono divide_right_mono) simp_all
  have "\<bar>(lo + hi) / 2 * 10000 - x * 10000\<bar> \<le> 1 / 200" using e k1 k2 by simp
  then show ?thesis using r by linarith
qed

definition enc4 :: "floatarith \<Rightarrow> int option" where
  "enc4 e = (case approx prec e [] of None \<Rightarrow> None | Some X \<Rightarrow> fix4_dec X)"

lemma enc4_sound:
  assumes "enc4 e = Some m"
  shows "\<bar>real_of_int m - interpret_floatarith e [] * 10000\<bar> \<le> 51 / 100"
proof -
  obtain X where X: "approx prec e [] = Some X" and d: "fix4_dec X = Some m"
    using assms by (auto simp: enc4_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using fix4_dec_sound d by blast
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

text \<open>A number the question gave or a by-product of the working, six
significant digits (@{text "%.6g"}).\<close>
definition show6 :: "rat \<Rightarrow> String.literal" where
  "show6 q = (case round_sig 6 (rl q) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"

text \<open>@{text "%.4f"} with the trailing zeros and point stripped: the
scaled integer @{text m} (value @{text "m / 10000"}) with the sign the value
had.\<close>
definition fixed_lit :: "bool \<Rightarrow> int \<Rightarrow> String.literal" where
  "fixed_lit neg m = (let ds0 = digits (nat \<bar>m\<bar>); ds = replicate (5 - length ds0) 0 @ ds0;
       k = length ds - 4; ip = take k ds; fp = strip_zeros (drop k ds) in
     (if neg then STR ''-'' else STR '''') + lit ip + (if fp = [] then STR '''' else STR ''.'' + lit fp))"

text \<open>The statistics organ's number format @{text f}: a value within
@{text "10^-9"} of a whole number is that whole number, anything else has four
decimals with the trailing zeros stripped.\<close>
definition f4 :: "rat \<Rightarrow> String.literal" where
  "f4 q = (let n = \<lfloor>q + 1 / 2\<rfloor> in
     if (1::rat) / 1000000000 < \<bar>q - of_int n\<bar> then fixed_lit (q < 0) (fix4 q) else show_int n)"

definition f4_dec :: "int \<Rightarrow> String.literal" where
  "f4_dec m = fixed_lit False m"

text \<open>The whole reply: answered or withheld, the kind, the response text and
the stated value. Withheld replies carry the decline text, as the organs do.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

end
