theory Chem_Util
  imports "HOL-Decision_Procs.Approximation" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Shared numerics for the chemistry family (lane S07): decimal rounding
with a proved error bound, interval enclosures of floatarith expressions
(HOL-Decision_Procs.Approximation, no HOL-Analysis), and Python-compatible
number layout (@{text "%.4g"}, @{text "%.2f"}, @{text "%.3f"}).

The rounding, enclosure and layout definitions and their proofs live once in
the shared session Veri7vn_Commons (src/extract/commons/Commons_Num.thy, lifted
from lane G); the fixed-point layout and nval are this family's own.\<close>

definition prec :: nat where "prec = 53"

section \<open>Fixed-point layout (Python's %.nf)\<close>

definition round_int :: "rat \<Rightarrow> int" where
  "round_int q = \<lfloor>q + 1 / 2\<rfloor>"

lemma round_int_error: "\<bar>rat_of_int (round_int q) - q\<bar> \<le> 1 / 2"
proof -
  have fc: "rat_of_int \<lfloor>q + 1 / 2\<rfloor> \<le> q + 1 / 2 \<and> q + 1 / 2 < rat_of_int \<lfloor>q + 1 / 2\<rfloor> + 1"
    using floor_correct[of "q + 1 / 2"] by simp
  show ?thesis unfolding round_int_def using fc by (intro abs_leI) linarith+
qed

definition fixed_val :: "nat \<Rightarrow> rat \<Rightarrow> rat" where
  "fixed_val n q = rat_of_int (round_int (q * 10 ^ n)) / 10 ^ n"

text \<open>The value a fixed-point layout shows is within half a unit of the last
place of the number.\<close>
theorem fixed_val_error: "\<bar>fixed_val n q - q\<bar> \<le> 1 / (2 * 10 ^ n)"
proof -
  have p: "(0::rat) < 10 ^ n" by simp
  have e: "\<bar>rat_of_int (round_int (q * 10 ^ n)) - q * 10 ^ n\<bar> \<le> 1 / 2" by (rule round_int_error)
  have eq: "fixed_val n q - q = (rat_of_int (round_int (q * 10 ^ n)) - q * 10 ^ n) / 10 ^ n"
    using p by (simp add: fixed_val_def divide_simps)
  have "\<bar>fixed_val n q - q\<bar> = \<bar>rat_of_int (round_int (q * 10 ^ n)) - q * 10 ^ n\<bar> / 10 ^ n"
    using p eq by simp
  also have "\<dots> \<le> (1 / 2) / 10 ^ n" using e p by (intro divide_right_mono) simp_all
  also have "\<dots> = 1 / (2 * 10 ^ n)" by simp
  finally show ?thesis .
qed

definition pad_to :: "nat \<Rightarrow> nat list \<Rightarrow> nat list" where
  "pad_to n ds = replicate (n - length ds) 0 @ ds"

text \<open>The digits of the rounded value, with a decimal point @{text n} places
from the right. A negative number gets a minus sign, as Python prints it.\<close>
definition fixed :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "fixed n q = (let r = round_int (\<bar>q\<bar> * 10 ^ n); s = (nat r) ;
       ip = s div 10 ^ n; fp = s mod 10 ^ n in
     (if q < 0 then STR ''-'' else STR '''') + lit (digits ip)
       + (if n = 0 then STR '''' else STR ''.'' + lit (pad_to n (digits fp))))"

text \<open>@{text "%.pg"} of an exact rational, four to fifteen digits.\<close>
definition gfmt :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "gfmt p q = (case round_sig p (rl q) of Some d \<Rightarrow> render_dec p d | None \<Rightarrow> STR ''?'')"

section \<open>Numeric values: an exact rational or an enclosed real\<close>

text \<open>A quantity the kernel states is either an exact rational or a real
given by a floatarith expression (exp, ln); the real is stated only through a
verified enclosure.\<close>
datatype nval = NR rat | NA floatarith

fun nreal :: "nval \<Rightarrow> real" where
  "nreal (NR q) = rl q"
| "nreal (NA e) = interpret_floatarith e []"

fun ndec :: "nval \<Rightarrow> (int \<times> int) option" where
  "ndec (NR q) = round_sig 4 (rl q)"
| "ndec (NA e) = enclose 53 e"

theorem ndec_sound:
  assumes "ndec v = Some d"
  shows "\<bar>dec_val d - nreal v\<bar> \<le> \<bar>nreal v\<bar> / 1000 + 1 / 1000000000"
proof (cases v)
  case (NR q)
  have r: "round_sig 4 (rl q) = Some d" using assms NR by simp
  have a: "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" by (rule round_sig_sound[OF r])
  have k: "(2::real) * 10 ^ (4 - 1) = 2000" by simp
  have b: "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / 2000" using a k by simp
  have c: "0 \<le> \<bar>rl q\<bar>" by simp
  have n: "nreal v = rl q" using NR by simp
  show ?thesis unfolding n using b c by linarith
next
  case (NA e)
  have "enclose 53 e = Some d" using assms NA by simp
  from enclose_sound[OF this] show ?thesis using NA by simp
qed

definition nshow :: "nval \<Rightarrow> String.literal" where
  "nshow v = (case ndec v of Some d \<Rightarrow> render_dec 4 d | None \<Rightarrow> STR ''?'')"

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

end
