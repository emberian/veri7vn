theory Computing_Num
  imports "Veri7vn_Computing_Base.Computing_Base"
begin

text \<open>Numbers shared by the computing family: verified decimal rounding and
rendering, interval enclosures through Isabelle's Approximation, Python's
half-even round, thousands separators. The blocks from @{text I} to
@{text enclose_sound} and from @{text digits} to @{text show4} are copied
from lane G (src/extract/quantity/Quantity.thy) unchanged; the rest is new in
this lane.\<close>

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



definition apos :: String.literal where "apos = String.implode [CHR 0x27]"
definition dquote :: String.literal where "dquote = String.implode [CHR 0x22]"
definition bquote :: String.literal where "bquote = String.implode [CHR 0x60]"

subsection \<open>Fixed-decimal enclosure (new)\<close>

definition to_fixed :: "nat \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed k X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if hi - lo \<le> pow10 (- int k) / 100 then Some (round_at mid (- int k)) else None)"

theorem to_fixed_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed k X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> pow10 (- int k) * (101 / 200)"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  define p where "p = pow10 (- int k)"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> p / 100" and dd: "d = round_at mid (- int k)"
    using d by (simp_all add: to_fixed_def Let_def lo_def hi_def mid_def p_def split: if_splits)
  have r: "\<bar>dec_val d - mid\<bar> \<le> p / 2" unfolding dd p_def by (rule round_at_error)
  have "\<bar>mid - x\<bar> \<le> (hi - lo) / 2" unfolding mid_def using xin by (rule midpoint_close)
  then have h1: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2" .
  have h2: "(hi - lo) / 2 \<le> p / 200"
  proof -
    have "(hi - lo) / 2 \<le> (p / 100) / 2" by (rule divide_right_mono[OF chk]) simp
    then show ?thesis by simp
  qed
  have m: "\<bar>mid - x\<bar> \<le> p / 200" using h1 h2 by (rule order_trans)
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
  show ?thesis using r m tri unfolding p_def[symmetric] by linarith
qed

definition enclose_fixed :: "nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose_fixed k e = (case approx prec e [] of None \<Rightarrow> None | Some X \<Rightarrow> to_fixed k X)"

theorem enclose_fixed_sound:
  assumes "enclose_fixed k e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> pow10 (- int k) * (101 / 200)"
proof -
  obtain X where X: "approx prec e [] = Some X" and d: "to_fixed k X = Some d"
    using assms by (auto simp: enclose_fixed_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using to_fixed_sound d by blast
qed

lemma findSomeD: "find P xs = Some x \<Longrightarrow> x \<in> set xs \<and> P x"
  by (induction xs) (auto split: if_splits)

subsection \<open>Exact rational rounding (new)\<close>

text \<open>Python's @{text round}: to the nearest integer, ties to even.\<close>
definition round_he :: "rat \<Rightarrow> int" where
  "round_he q = (let f = \<lfloor>q\<rfloor>; r = q - of_int f in
     if r < 1 / 2 then f else if 1 / 2 < r then f + 1 else if even f then f else f + 1)"

lemma round_he_aux:
  fixes q :: rat and f :: int
  assumes "of_int f \<le> q" "q < of_int f + 1"
  shows "\<bar>of_int (if q - of_int f < 1 / 2 then f else if 1 / 2 < q - of_int f then f + 1
           else if even f then f else f + 1) - q\<bar> \<le> 1 / 2"
proof -
  consider "q - of_int f < 1 / 2" | "1 / 2 < q - of_int f" | "q - of_int f = 1 / 2" by linarith
  then show ?thesis
  proof cases
    case 1
    then show ?thesis using assms by (auto simp: abs_le_iff; linarith)
  next
    case 2
    then show ?thesis using assms by (auto simp: abs_le_iff; linarith)
  next
    case 3
    have c1: "\<not> q - of_int f < 1 / 2" and c2: "\<not> 1 / 2 < q - of_int f" using 3 by simp_all
    have q: "q = of_int f + 1 / 2" using 3 by simp
    show ?thesis by (cases "even f") (simp_all add: c1 c2 q abs_le_iff)
  qed
qed

theorem round_he_close: "\<bar>of_int (round_he q) - q\<bar> \<le> 1 / 2"
proof -
  have lo: "of_int \<lfloor>q\<rfloor> \<le> q" by (rule of_int_floor_le)
  have hi: "q < of_int \<lfloor>q\<rfloor> + 1" using floor_correct[of q] by simp
  show ?thesis unfolding round_he_def Let_def by (rule round_he_aux[OF lo hi])
qed

theorem round_he_tie_even:
  assumes "q = of_int n + 1 / 2"
  shows "even (round_he q)"
proof -
  have f: "\<lfloor>q\<rfloor> = n"
  proof (rule floor_unique)
    show "of_int n \<le> q" using assms by linarith
    show "q < of_int n + 1" using assms by linarith
  qed
  have r: "q - of_int n = 1 / 2" using assms by simp
  have c1: "\<not> q - of_int n < 1 / 2" and c2: "\<not> 1 / 2 < q - of_int n" using r by simp_all
  have r2: "q * 2 - of_int n * 2 = 1" using r by linarith
  show ?thesis by (cases "even n") (simp_all add: round_he_def Let_def f c1 c2 r2)
qed

subsection \<open>Text helpers (new)\<close>

definition commas :: "int \<Rightarrow> String.literal" where
  "commas i = (let ds = digits (nat \<bar>i\<bar>); n = length ds in
     (if i < 0 then STR ''-'' else STR '''') +
     foldl (\<lambda>s kd. s + (if 0 < fst kd \<and> (n - fst kd) mod 3 = 0 then STR '','' else STR '''')
        + digit_lit (snd kd)) (STR '''') (zip [0..<n] ds))"

definition oct3 :: "nat \<Rightarrow> String.literal" where
  "oct3 n = lit [n div 64 mod 8, n div 8 mod 8, n mod 8]"

text \<open>Python's @{text "%.4f"} with trailing zeros stripped, of a rational.\<close>
definition fixed_str :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "fixed_str k q = render_dec 40 (round_at (rl q) (- int k))"

theorem fixed_str_sound:
  "\<bar>dec_val (round_at (rl q) (- int k)) - rl q\<bar> \<le> pow10 (- int k) / 2"
  by (rule round_at_error)

text \<open>Python's @{text "%.4g"} of a rational (or refusal).\<close>
definition sig4_str :: "rat \<Rightarrow> String.literal" where
  "sig4_str q = (case round_sig 4 (rl q) of Some d \<Rightarrow> render_dec 4 d | None \<Rightarrow> STR ''?'')"

text \<open>The shared reply record.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

end
