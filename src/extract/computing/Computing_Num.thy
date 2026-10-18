theory Computing_Num
  imports "Veri7vn_Computing_Base.Computing_Base" "HOL-Library.Code_Target_Numeral" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Numbers shared by the computing family: Python's half-even round,
thousands separators and a fixed-decimal enclosure. Verified decimal rounding
and rendering and the interval enclosures come from Veri7vn_Commons
(src/extract/commons/Commons_Num.thy, lifted from lane G).\<close>

definition prec :: nat where "prec = 53"

definition dquote :: String.literal where "dquote = STR 0x22"
definition bquote :: String.literal where "bquote = STR 0x60"

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
