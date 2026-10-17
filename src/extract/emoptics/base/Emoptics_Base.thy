theory Emoptics_Base
  imports "HOL-Decision_Procs.Approximation"
begin

text \<open>Only an import point (as lane G's Quantity_Base): Isabelle's interval
arithmetic over binary floats (@{const approx} and its correctness theorem
@{thm approx}) encloses every value of this family that is not rational:
square roots (three-phase power, power-factor correction), the AWG power law
and pi (wire gauge), sine and arc sine (refraction, critical angle).\<close>

end
