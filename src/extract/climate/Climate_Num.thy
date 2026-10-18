theory Climate_Num
  imports "Veri7vn_Climate_Base.Climate_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Lane S05-climate: shared numerics for the climate family. The exact
rational to floating-real glue, decimal rounding with a proved bound and the
digit layout live once in Veri7vn_Commons (src/extract/commons/Commons_Num.thy,
lifted from lane G). What stays here: @{text to_fixed} (a fixed
number of decimals from an enclosure) and the fixed-decimal layout the climate
organs print (Python @{text "%.4f"} / @{text "%.3f"} with trailing zeros removed,
whole numbers with commas from 100000 up).\<close>

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
