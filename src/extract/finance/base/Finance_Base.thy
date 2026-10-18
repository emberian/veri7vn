theory Finance_Base
  imports "HOL-Decision_Procs.Approximation" "HOL-Library.Code_Target_Numeral"
begin

text \<open>Only an import point: Isabelle's interval arithmetic over binary floats
(@{const approx} and its correctness theorem @{thm approx}) encloses the family
values that are not rational: a logarithm (doubling time, fractional compounding
exponents), an exponential (continuous compounding) and a square root (EOQ).\<close>

end
