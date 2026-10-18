theory Trades_Num
  imports "Veri7vn_Trades_Base.Trades_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Numbers for the trades family. Exact rationals read as reals, the verified
interval enclosures, decimal rounding with a proved error bound and the layout of
numbers as text come from Veri7vn_Commons (src/extract/commons/Commons_Num.thy,
lifted from lane G and lane D). What is local: the base-10 logarithm and its
lemmas (from src/extract/acoustics/Acoustics.thy, lane D), the precision, the
cents and comma layouts and the family's own @{text to_fixed}.\<close>

section \<open>Interval expressions\<close>

text \<open>Base-10 logarithm. The library's bounds for @{text ln} converge slowly when
the binary mantissa of the argument is near 2 (about four digits at any
precision), so the argument is first brought near 1 by eight square roots:
@{text "ln y = 256 ln (sqrt\<^sup>8 y)"} for @{text "y \<ge> 0"}.\<close>
definition sq8 :: "floatarith \<Rightarrow> floatarith" where
  "sq8 a = floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt
     (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt a)))))))"

definition r8 :: "real \<Rightarrow> real" where
  "r8 y = sqrt (sqrt (sqrt (sqrt (sqrt (sqrt (sqrt (sqrt y)))))))"

definition Lg :: "floatarith \<Rightarrow> floatarith" where
  "Lg a = floatarith.Mult (floatarith.Mult (I 256) (floatarith.Ln (sq8 a)))
     (floatarith.Inverse (floatarith.Ln (I 10)))"

lemma interp_sq8: "interpret_floatarith (sq8 a) xs = r8 (interpret_floatarith a xs)"
  by (simp add: sq8_def r8_def)

lemma ln_sqrt_half: "0 \<le> z \<Longrightarrow> ln (sqrt z) = ln z / 2"
  by (rule ln_sqrt)

lemma ln_r8: "0 \<le> y \<Longrightarrow> ln (r8 y) = ln y / 256"
proof -
  assume y: "0 \<le> y"
  let ?s = sqrt
  have n1: "0 \<le> ?s y" and n2: "0 \<le> ?s (?s y)" and n3: "0 \<le> ?s (?s (?s y))"
    and n4: "0 \<le> ?s (?s (?s (?s y)))" and n5: "0 \<le> ?s (?s (?s (?s (?s y))))"
    and n6: "0 \<le> ?s (?s (?s (?s (?s (?s y)))))" and n7: "0 \<le> ?s (?s (?s (?s (?s (?s (?s y))))))"
    using y by (simp_all only: real_sqrt_ge_zero)
  show ?thesis unfolding r8_def
    by (simp only: ln_sqrt_half[OF n7] ln_sqrt_half[OF n6] ln_sqrt_half[OF n5] ln_sqrt_half[OF n4]
        ln_sqrt_half[OF n3] ln_sqrt_half[OF n2] ln_sqrt_half[OF n1] ln_sqrt_half[OF y])
qed

lemma interp_Lg [simp]:
  "0 \<le> interpret_floatarith a xs \<Longrightarrow> interpret_floatarith (Lg a) xs = log 10 (interpret_floatarith a xs)"
proof -
  assume y: "0 \<le> interpret_floatarith a xs"
  have "interpret_floatarith (Lg a) xs = of_int 256 * ln (r8 (interpret_floatarith a xs)) * inverse (ln (of_int 10))"
    by (simp only: Lg_def interpret_floatarith.simps interp_sq8 interp_I)
  also have "\<dots> = of_int 256 * (ln (interpret_floatarith a xs) / 256) * inverse (ln (of_int 10))"
    by (simp only: ln_r8[OF y])
  also have "\<dots> = ln (interpret_floatarith a xs) * inverse (ln 10)"
    by simp
  also have "\<dots> = log 10 (interpret_floatarith a xs)"
    by (simp only: log_def divide_inverse)
  finally show ?thesis .
qed

lemma interp_P10 [simp]: "interpret_floatarith (floatarith.Powr (I 10) a) xs = 10 powr interpret_floatarith a xs"
  by simp

section \<open>Interval precision\<close>

definition prec :: nat where "prec = 64"

section \<open>Digits as text\<close>

text \<open>Python's @{text "format(n, ',')"} for a non-negative whole number.\<close>
fun commas_aux :: "nat \<Rightarrow> nat list \<Rightarrow> String.literal" where
  "commas_aux k [] = STR ''''"
| "commas_aux k (d # ds) = digit_lit d
     + (if ds \<noteq> [] \<and> (k - 1) mod 3 = 0 then STR '','' else STR '''') + commas_aux (k - 1) ds"

definition show_commas :: "int \<Rightarrow> String.literal" where
  "show_commas i = (if i < 0 then STR ''-'' else STR '''')
     + commas_aux (length (digits (nat \<bar>i\<bar>))) (digits (nat \<bar>i\<bar>))"

text \<open>Python's @{text "%.2f"} of a decimal @{text "m * 10^-2"}.\<close>
definition render_cents :: "int \<times> int \<Rightarrow> String.literal" where
  "render_cents d = (case d of (m, e) \<Rightarrow>
     (if m < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>m\<bar> div 100)) + STR ''.''
       + lit (pad2 (digits (nat \<bar>m\<bar> mod 100))))"

section \<open>Fixed decimals and the three enclosure modes\<close>

text \<open>Enclosure to a fixed decimal place (the organs' @{text "%.3f"}): the
interval must be narrower than a thousandth of the place.\<close>
definition to_fixed :: "int \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed e X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if hi - lo \<le> pow10 e / 1000 then Some (round_at mid e) else None)"

theorem to_fixed_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed e X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> pow10 e * (1001 / 2000)"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> pow10 e / 1000" and dd: "d = round_at mid e"
    using d by (simp_all add: to_fixed_def Let_def lo_def hi_def mid_def split: if_splits)
  have r: "\<bar>dec_val d - mid\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have mc: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2" unfolding mid_def using xin by (rule midpoint_close)
  have h2: "(hi - lo) / 2 \<le> pow10 e / 2000" using chk by (simp add: field_simps)
  have m: "\<bar>mid - x\<bar> \<le> pow10 e / 2000" by (rule order_trans[OF mc h2])
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
  show ?thesis using r m tri by linarith
qed

datatype amode = Sig4 | Sig4C | Fix3

text \<open>Sig4: four significant digits (@{text "%.4g"}). Sig4C: the same below
10000, a comma-grouped whole number from there up (printing's @{text g}).
Fix3: three decimals.\<close>
definition enclose_m :: "amode \<Rightarrow> nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose_m md p e = (case approx p e [] of None \<Rightarrow> None | Some X \<Rightarrow>
     (case md of Sig4 \<Rightarrow> to_dec X
      | Sig4C \<Rightarrow> if 10000 \<le> real_of_float (lower X) then to_fixed 0 X else to_dec X
      | Fix3 \<Rightarrow> to_fixed (- 3) X))"

theorem enclose_m_sound:
  assumes "enclose_m md p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000"
proof -
  obtain X where X: "approx p e [] = Some X" and d: "(case md of Sig4 \<Rightarrow> to_dec X
      | Sig4C \<Rightarrow> if 10000 \<le> real_of_float (lower X) then to_fixed 0 X else to_dec X
      | Fix3 \<Rightarrow> to_fixed (- 3) X) = Some d"
    using assms by (auto simp: enclose_m_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have xin: "interpret_floatarith e [] \<in>\<^sub>r X" .
  define x where "x = interpret_floatarith e []"
  have xin': "x \<in>\<^sub>r X" using xin by (simp add: x_def)
  have ax: "0 \<le> \<bar>x\<bar>" by simp
  have claim: "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000"
  proof (cases md)
    case Sig4
    then have td: "to_dec X = Some d" using d by simp
    have "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000" by (rule to_dec_sound[OF xin' td])
    then show ?thesis by linarith
  next
    case Fix3
    then have "to_fixed (- 3) X = Some d" using d by simp
    then have "\<bar>dec_val d - x\<bar> \<le> pow10 (- 3) * (1001 / 2000)" by (rule to_fixed_sound[OF xin'])
    moreover have "pow10 (- 3) = 1 / 1000" by (simp add: pow10_def inverse_eq_divide)
    ultimately show ?thesis using ax by linarith
  next
    case Sig4C
    show ?thesis
    proof (cases "10000 \<le> real_of_float (lower X)")
      case True
      then have f: "to_fixed 0 X = Some d" using d Sig4C by simp
      have b: "\<bar>dec_val d - x\<bar> \<le> pow10 0 * (1001 / 2000)" by (rule to_fixed_sound[OF xin' f])
      have p0: "pow10 0 = 1" by (simp add: pow10_def)
      have lo: "real_of_float (lower X) \<le> x" using xin' by (auto simp: set_of_eq)
      then have "10000 \<le> x" using True by linarith
      then have "\<bar>x\<bar> / 1000 \<ge> 10" by simp
      then show ?thesis using b p0 by linarith
    next
      case False
      then have td: "to_dec X = Some d" using d Sig4C by simp
      have "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000" by (rule to_dec_sound[OF xin' td])
      then show ?thesis by linarith
    qed
  qed
  then show ?thesis by (simp add: x_def)
qed

end
