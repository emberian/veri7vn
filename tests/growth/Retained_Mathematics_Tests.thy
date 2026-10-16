theory Retained_Mathematics_Tests
  imports "Veri7vn_Retained_Mathematics.Retained_Mathematics"
begin

definition zero_samples where
  "zero_samples = [\<lparr>sample_bindings=[(0,0)],sample_expected=Some 0\<rparr>]"
definition one_samples where
  "one_samples = [\<lparr>sample_bindings=[(0,1)],sample_expected=Some 1\<rparr>]"
definition retained_fixture where
  "retained_fixture = (let
      old = \<lparr>retained_context=(7::nat),retained_expression=Rational 0,
        retained_samples=zero_samples\<rparr>;
      good = \<lparr>retained_context=(7::nat),retained_expression=Parameter 0,
        retained_samples=zero_samples\<rparr>;
      square = \<lparr>retained_context=(7::nat),
        retained_expression=Times (Parameter 0) (Parameter 0),
        retained_samples=zero_samples\<rparr>;
      library=[old,good];
      baseline=isolated_evaluation 7 library 8 0 [] one_samples;
      evaluation=isolated_evaluation 7 library 8 1 [Rational 1] one_samples
    in remdups (guided_expressions 7 library 8 0 [] one_samples) = [Parameter 0] \<and>
      guided_expressions 8 library 8 0 [] one_samples = [] \<and>
      remdups (guided_expressions 7 library 8 0 [] zero_samples) = [Rational 0,Parameter 0] \<and>
      retain_expression 7 (Rational 0) one_samples library = None \<and>
      retain_expression 7 (Parameter 0) [] library = None \<and>
      Negate (Times (Parameter 0) (Parameter 0)) \<in>
        set (guided_expressions 7 [square] 100 1 []
          [\<lparr>sample_bindings=[(0,2)],sample_expected=Some (-4)\<rparr>]) \<and>
      length baseline = 2 \<and> length evaluation > 1 \<and>
      isolated_evaluation 7 library 8 0 [] one_samples = baseline \<and>
      map observed_value (observe_samples zero_samples
        (Divide (Rational 1) (Rational 0))) = [None])"

ML \<open>
  if @{code retained_fixture} then
    writeln "GROWTH retained_recheck_context_isolation_partiality PASS"
  else error "retained candidate scope, revalidation or evaluation isolation changed"
\<close>
end
