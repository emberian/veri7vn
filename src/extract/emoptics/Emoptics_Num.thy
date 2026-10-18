theory Emoptics_Num
  imports "Veri7vn_Emoptics_Base.Emoptics_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Numerics shared by the whole family. The enclosure, decimal rounding and
the layout of decimals as text come from Veri7vn_Commons
(src/extract/commons/Commons_Num.thy, lifted from lane G); this theory adds: the sign of an enclosed real, a
square root of an exact rational, sine in degrees, arc sine, and the powers the
AWG gauge law needs. Nothing here depends on a request or a kind.\<close>

definition prec :: nat where "prec = 53"

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
