theory Mech_Num
  imports "Veri7vn_Mechanics_Base.Mechanics_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Numeric infrastructure for the mechanics family: rational to real,
rounding, the decimal enclosure of an interval-arithmetic result and ASCII number
layout all come from Veri7vn_Commons (src/extract/commons/Commons_Num.thy,
lifted from lane G); only the interval precision and a sine identity are local.\<close>

definition prec :: nat where "prec = 53"

lemma sin_as_cos: "sin x = cos (pi / 2 - x)"
  by (simp add: cos_diff)

end
