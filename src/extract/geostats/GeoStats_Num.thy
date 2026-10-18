theory GeoStats_Num
  imports "Veri7vn_GeoStats_Base.GeoStats_Base" "HOL-Library.Multiset" "Veri7vn_Commons.Commons_Num"
begin

text \<open>
  The numeric layer shared by the geometry and statistics kernels: exact
  rational values are rounded with a proved bound; a value that is a multiple
  of pi or a square root is enclosed in a verified interval
  (HOL-Decision_Procs.Approximation) and then rounded; both are laid out as
  text the way Python's @{text "%.6g"} and @{text "%.4f"} lay them out.

  The rounding lemmas and the number layout come from Veri7vn_Commons
  (src/extract/commons/Commons_Num.thy, lifted from lane G); the six-digit
  enclosure below is the same proof as the four-digit one with the constants
  changed.
\<close>

section \<open>Rounding and enclosure\<close>

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

text \<open>A number the question gave or a by-product of the working, six
significant digits (@{text "%.6g"}).\<close>
definition show6 :: "rat \<Rightarrow> String.literal" where
  "show6 q = (case round_sig 6 (rl q) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"

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
