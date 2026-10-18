theory Earth_Base
  imports "HOL-Decision_Procs.Approximation" "HOL-Library.Code_Target_Numeral"
begin

text \<open>Only an import point: Isabelle's interval arithmetic over binary
floats (@{const approx} and its correctness theorem @{thm approx}) encloses the
family values that are not rational (square roots, exponentials, logarithms,
powers, cosine, arctangent, pi).\<close>

end
