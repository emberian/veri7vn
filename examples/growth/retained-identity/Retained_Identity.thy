theory Retained_Identity
  imports "Veri7vn_Retained_Mathematics.Retained_Mathematics"
begin

text \<open>Canonical editable candidate source. This definition declares a program;
it does not prove an intended universal specification or activate a capability.\<close>
definition identity_candidate :: math_expr where
  "identity_candidate = Parameter 0"
definition identity_samples :: "exact_sample list" where
  "identity_samples =
    [\<lparr>sample_bindings=[(0,0)],sample_expected=Some 0\<rparr>,
     \<lparr>sample_bindings=[(0,1)],sample_expected=Some 1\<rparr>]"
end
