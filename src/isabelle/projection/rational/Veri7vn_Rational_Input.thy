theory Veri7vn_Rational_Input
  imports "Veri7vn_Codegen.Veri7vn_Codegen" "HOL.Rat"
begin

lemma rational_integer_one_input:
  "(1::integer) = Code_Numeral.positive Num.One"
  by simp

text \<open>Normalize literal syntax before computation-specific and ordinary
preprocessing. Otherwise rational numerals can introduce integer Pos only after
the computation input-constant set has been fixed to positive.\<close>
lemma rational_nat_one_input:
  "(1::nat) = Code_Numeral.nat_of_integer (Code_Numeral.positive Num.One)"
  by simp
lemma rational_int_zero_input:
  "(0::int) = Code_Numeral.int_of_integer (0::integer)"
  by simp
lemma rational_int_one_input:
  "(1::int) = Code_Numeral.int_of_integer (Code_Numeral.positive Num.One)"
  by simp
lemma rational_int_numeral_input:
  "(numeral n::int) = Code_Numeral.int_of_integer (Code_Numeral.positive n)"
  by simp

ML_file "rational_input.ML"
end
