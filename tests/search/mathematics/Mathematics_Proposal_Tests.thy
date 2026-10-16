theory Mathematics_Proposal_Tests
  imports "Veri7vn_Mathematics_Proposals.Mathematics_Proposals"
begin
definition proposal_fixture where
  "proposal_fixture = (let samples =
      [\<lparr>sample_bindings=[(0,0)],sample_expected=Some 0\<rparr>,
       \<lparr>sample_bindings=[(0,2)],sample_expected=Some 4\<rparr>];
      candidates=propose_expressions 100 1 [Parameter 0,Rational 2] samples
    in Times (Parameter 0) (Rational 2) \<in> set candidates \<and>
      Rational 0 \<notin> set candidates \<and> length candidates \<le> 100 \<and>
      close_expression [(0,2)] (Times (Parameter 0) (Rational 2)) =
        Some (Times (Rational 2) (Rational 2)) \<and>
      close_expression [] (Parameter 0) = None \<and>
      distinguishes (Parameter 0) (Rational 0)
       \<lparr>counterexample_bindings=[(0,1)],left_value=1,right_value=0\<rparr> \<and>
      math_eval (\<lambda>_. None) (Divide (Rational 1) (Rational 0)) = None)"
ML \<open>
  if @{code proposal_fixture} then writeln "SEARCH actual_math_typed_candidates_scope PASS"
  else error "typed candidate grammar lost witnesses or promoted sample agreement"
\<close>
end
