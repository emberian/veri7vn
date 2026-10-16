theory Behavioral_Evaluation_Tests
  imports Veri7vn_Behavioral_Evaluation.Behavioral_Evaluation
begin

ML \<open>
local
  structure V=Veri7vn_Behavioral_Metrics;
  fun measured reply:V.measured={reply=reply,elapsed_us=100};
  fun row index expected baseline candidate:V.row={index=index,role=V.Domain,
    expected=expected,baseline=measured baseline,candidate=measured candidate};
  val rows=[row 0 (V.Expected_Rational(4,1)) V.Declined(V.Asserted_Rational(8,2)),
    row 1 V.Must_Decline V.Declined(V.Asserted_Rational(1,1)),
    row 2 V.Unknown V.Not_Taken(V.Asserted_Rational(100,1)),
    row 3 (V.Expected_Rational(2,1))(V.Asserted_Rational(2,1))V.Declined];
  val result=V.summarize rows;
  val _=if #unknown result=1 andalso #scored result=3 andalso
    #correct(#candidate result)=1 andalso #false_assertions(#candidate result)=1 andalso
    #wrong(#candidate result)=0 andalso #unscored(#candidate result)=1 andalso
    #gain result= ~1 then ()else error "Behavioral exact/decline/unknown reduction";
  val policy:V.policy={minimum_gain=0,maximum_wrong=1,maximum_general_taken=0,
    require_general=true,require_identity=true,maximum_p50_us=1000};
  val failures=V.failures policy result;
  val _=if member(op =)failures "False assertions increased" andalso
    member(op =)failures "General interception unmeasured" andalso
    member(op =)failures "Identity interception unmeasured"then ()
    else error "Unmeasured routing silently qualified";
  val failed=V.summarize[row 0 V.Must_Decline V.Declined(V.Measurement_Failed "budget")];
  val _=if #correct(#candidate failed)=0 andalso
    #measurement_failures(#candidate failed)=1 andalso
    member(op =)(V.failures policy failed)"Execution measurement failed"then ()
    else error "Execution failure became a correct refusal";
  val _=if V.median[1,2,3,4]=SOME 3 then ()else error "Behavioral upper median changed";
  val _=case Exn.capture V.summarize[hd rows,hd rows]of Exn.Exn _=>()
    | _=>error "Behavioral duplicate row accepted";
in val _=writeln "BEHAVIORAL exact_decline_unknown_failures_unmeasured PASS"end
\<close>

end
