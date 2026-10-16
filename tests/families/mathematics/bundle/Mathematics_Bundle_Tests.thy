theory Mathematics_Bundle_Tests
  imports "Veri7vn_Mathematics_Bundle.Mathematics_Bundle"
    "Veri7vn_Mathematics_Tests.Mathematics_Exact_Tests"
begin

ML \<open>
  local
    structure X = Veri7vn_Mathematics_Execution;
    structure R = Veri7vn_Native_Registry;
    structure A = Veri7vn_Native_Admission;
    structure E = Veri7vn_Executable_Identity;
    fun reason X.Wrong_Executable = "Wrong_Executable"
      | reason X.Wrong_Generation = "Wrong_Generation"
      | reason (X.Invalid_Contract messages) = "Invalid_Contract: " ^ commas messages
      | reason X.Request_Bound = "Request_Bound"
      | reason X.Unsupported_Input = "Unsupported_Input"
      | reason X.Execution_Budget = "Execution_Budget"
      | reason X.Released = "Released"
      | reason (X.Runtime_Error message) = "Runtime_Error: " ^ message;
    val pin = X.executable ();
    val generation = R.generation @{context} {packages=["mathematics"],
      runtime="mathematics-static-bundle",policy="curated-native-test",sources=[],interpretation="postfix-ascii"};
    val instance = (case X.attach {policy=A.policy @{theory},generation=generation,
      code_context=E.code_theory pin,limits={nodes=5000,depth=100,work=100,seconds=2}} of
      X.Ready x => x | X.Refused failure => error ("math implementation attachment failed: " ^ reason failure));
    val mirror_instance = (case X.attach {policy=A.policy @{theory},generation=generation,
      code_context=E.code_theory pin,limits={nodes=5000,depth=100,work=100,seconds=2}} of
      X.Ready x => x | X.Refused failure => error ("mirror instance attachment: " ^ reason failure));
    val _ = if X.same_instance (instance,instance) andalso
      not (X.same_instance (instance,mirror_instance)) then ()
      else error "distinct live instances with equal configuration were confused";
    val _ = if null (A.observed_oracles (X.contract instance)) then ()
      else error "math implementation contains oracle dependencies";
    fun run native =
      (case X.prepare pin instance native of X.Ready request =>
        (case X.execute pin instance request of X.Ready output =>
          (case X.project pin output of X.Ready ct => Thm.term_of ct
           | X.Refused failure => error ("math projection failed: " ^ reason failure))
         | X.Refused failure => error ("math generated execution failed: " ^ reason failure))
       | X.Refused failure => error ("math native request failed: " ^ reason failure ^
           "; input=" ^ Syntax.string_of_term @{context} (Thm.term_of native)));

    val _ = if run @{cterm "closed_expression_run 100 (Divide (Rational 1) (Rational 0))"}
      aconv @{term "Computed None"} then () else error "direct expression lost partiality";
    val _ = if run @{cterm "closed_ascii_run 100 [48,32,48,32,47]"}
      aconv @{term "Computed None"} then () else error "bundle lost undefinedness";
    val _ = if run @{cterm "closed_ascii_run 100 [112,114,105,110,116,40,55,51,49,57,52,50,41]"}
      aconv @{term SyntaxRejected} then () else error "bundle accepted print source";
    val _ = if run @{cterm "closed_expression_run 100 (Power (Power (Rational 2) 100) 100)"}
      aconv @{term BoundExceeded} then () else error "nested power bypassed pre-execution magnitude guard";
    val _ = if run @{cterm "closed_expression_run 100 (Power (Power (Rational 0) 100) 100)"}
      aconv @{term "Computed (Some 0)"} then () else error "zero power needlessly refused";
    val _ = if run @{cterm "closed_expression_run 100 (Power (Power (Rational 1) 100) 100)"}
      aconv @{term "Computed (Some 1)"} then () else error "unit power needlessly refused";
    val _ = if run @{cterm "closed_ascii_run 100 [48,32,94,49,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48]"}
      aconv @{term BoundExceeded} then () else error "oversized zero exponent reached resource power";
    val _ = if run @{cterm "closed_ascii_run 100 [49,32,94,49,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48]"}
      aconv @{term BoundExceeded} then () else error "oversized unit exponent reached resource power";
    val _ = if run @{cterm "closed_ascii_run 100 [45,49,32,94,49,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48]"}
      aconv @{term BoundExceeded} then () else error "oversized negative unit exponent reached resource power";
    val impostor = E.pin (E.code_theory pin) (E.manifest pin);
    val _ = (case X.prepare impostor instance @{cterm "closed_ascii_run 100 [49]"} of
      X.Refused X.Wrong_Executable => () | _ => error "math executable identity confused");
    val _ = (case X.prepare pin instance @{cterm "closed_ascii_run 100 bytes"} of
      X.Refused X.Request_Bound => () | _ => error "open native input escaped static decoder");
    val undefined_request = (case X.prepare pin instance
      @{cterm "closed_expression_run 100 (Divide (Rational 1) (Rational 0))"} of
      X.Ready r => r | _ => error "undefined view prepare failed");
    val undefined_output = (case X.execute pin instance undefined_request of X.Ready out => out
      | _ => error "undefined view execution failed");
    val _ = (case X.output_view undefined_output of X.Ready X.Undefined_Arithmetic => ()
      | _ => error "native view confused undefined arithmetic with a rational");
    val _ = X.release_request undefined_request;
    val fraction_request = (case X.prepare pin instance
      @{cterm "closed_expression_run 100 (Divide (Rational 1) (Rational 2))"} of
      X.Ready r => r | _ => error "exact fraction view prepare failed");
    val fraction_output = (case X.execute pin instance fraction_request of X.Ready out => out
      | _ => error "exact fraction execution failed");
    val _ = (case X.output_view fraction_output of X.Ready (X.Exact_Rational (1,2)) => ()
      | _ => error "native view lost exact rational pair");
    val _ = X.release_request fraction_request;
    val request = (case X.prepare pin instance @{cterm "closed_expression_run 100 (Rational 1)"} of
      X.Ready r => r | _ => error "release fixture prepare failed");
    val _ = (case X.registered_input request of X.Ready packet =>
      if Thm.term_of packet aconv @{term "registered_math_dispatch QualifiedExactArithmetic 100 (MathExpression (Rational 1))"}
      then () else error "registered carrier detached from prepared input"
      | _ => error "registered carrier unavailable");
    val _ = if X.same_operation (X.operation instance,X.operation instance) then ()
      else error "fixed mathematics operation identity changed";
    val _ = (case X.modeled_cost request of X.Ready cost =>
        if cost=IntInf.fromInt (1 + (Term.size_of_term @{term "closed_expression_run 100 (Rational 1)"})) then ()
        else error "modeled charge detached from actual prepared input"
      | _ => error "prepared modeled charge unavailable");
    val output = (case X.execute pin instance request of X.Ready out => out
      | _ => error "release fixture execute failed");
    val other_request = (case X.prepare pin instance @{cterm "closed_expression_run 100 (Rational 1)"} of
      X.Ready r => r | _ => error "second equal request prepare failed");
    val _ = if X.same_request (request,request) andalso not (X.same_request (request,other_request))
      then () else error "prepared request ownership identity confused equal operands";
    val _ = if X.belongs_to request output andalso not (X.belongs_to other_request output)
      then () else error "equal operand requests lost opaque invocation association";
    val _ = X.release_request request;
    val _ = (case X.registered_input request of X.Refused X.Released => ()
      | _ => error "released request retained registered carrier");
    val _ = (case X.modeled_cost request of X.Refused X.Released => ()
      | _ => error "released request retained modeled charge");
    val _ = if not (X.belongs_to request output) then ()
      else error "released invocation retained output association";
    val _ = X.release_request other_request;
    val _ = (case X.project pin output of X.Refused X.Released => ()
      | _ => error "forgotten request retained result payload");
    val _ = (case X.execute pin instance request of X.Refused X.Released => ()
      | _ => error "forgotten request executed again");
    val bounded = (case X.attach {policy=A.policy @{theory},generation=generation,
      code_context=E.code_theory pin,limits={nodes=120,depth=100,work=1500,seconds=2}} of
      X.Ready x => x | _ => error "bounded projection instance failed");
    val large_request = (case X.prepare pin bounded
      @{cterm "closed_expression_run 1500 (Power (Rational 2) 200)"} of
      X.Ready r => r | _ => error "large exact expression prepare failed");
    val large_output = (case X.execute pin bounded large_request of X.Ready out => out
      | _ => error "large exact expression failed");
    val allocations = Veri7vn_Bounded_Projection.allocated ();
    val _ = (case X.project pin large_output of X.Refused X.Request_Bound => ()
      | _ => error "oversized exact output bypassed preflight");
    val _ = if Veri7vn_Bounded_Projection.allocated ()=allocations then ()
      else error "oversized projection allocated output term before refusal";
    val _ = X.release_instance bounded;
    val _ = X.release_instance mirror_instance;
    val _ = if not (X.same_instance (mirror_instance,mirror_instance)) andalso
      not (X.same_instance (instance,mirror_instance)) then ()
      else error "released mirror retained instance authority";
    val _ = X.release_instance instance;
    val _ = if not (X.same_instance (instance,instance)) then ()
      else error "released instance retained live identity";
    val _ = (case X.prepare pin instance @{cterm "closed_ascii_run 100 [49]"} of
      X.Refused X.Released => () | _ => error "released native instance retained context");
  in
    val _ = writeln "VERI7VN_MATH admitted_bundle PASS";
  end;
\<close>
end
