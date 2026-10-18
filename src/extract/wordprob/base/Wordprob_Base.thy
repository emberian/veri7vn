theory Wordprob_Base
  imports "HOL.Real" "HOL.Rat" "HOL-Library.Code_Target_Numeral" "HOL-Library.Code_Target_Int"
begin

text \<open>Only an import point: the rational kernel needs nothing beyond main
HOL (Real for the decimal/significant-digit machinery, Rat for the values)
plus the code-target theories that keep numerals binary in the generated SML
(without them @{typ nat} and @{typ int} are unary and the binary balloons).\<close>

end
