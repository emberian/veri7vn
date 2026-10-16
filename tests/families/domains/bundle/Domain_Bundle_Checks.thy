theory Domain_Bundle_Checks
  imports "Veri7vn_Domain_Bundle.Domain_Bundle"
begin

ML \<open>
local
  structure X=Veri7vn_Domain_Execution;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  val pin=X.executable();
  fun evaluate term=Timeout.apply(Time.fromSeconds 5)(fn()=>
    (* dynamic_value_strict certifies the reflected term itself, so the dry
       preflight sentinel is not a legal input to that API. The actual scoped
       materializer still charges every constructor before allocating it. *)
    (Veri7vn_Bounded_Projection.materialize 20000
      (fn()=>Code_Evaluation.dynamic_value_strict @{context} term)))();

  val generation=R.generation @{context} {packages=["quantities"],runtime="closed-domain-check",
    policy="native-test",sources=[],interpretation="typed-exact-point-delta"};
  val phase=Unsynchronized.ref "attach";
  fun failure X.Wrong_Executable="Wrong_Executable"
    | failure X.Wrong_Generation="Wrong_Generation"
    | failure(X.Invalid_Contract reasons)="Invalid_Contract: " ^ commas reasons
    | failure X.Request_Bound="Request_Bound"
    | failure X.Unsupported_Input="Unsupported_Input"
    | failure X.Execution_Budget="Execution_Budget"
    | failure X.Released="Released"
    | failure(X.Runtime_Error message)="Runtime_Error: " ^ message;
  fun ready (X.Ready x)=x | ready (X.Refused reason)=error
    ("Domain bundle " ^ !phase ^ ": " ^ failure reason);
  fun attach ()=ready(X.attach{policy=A.policy @{theory},generation=generation,
    code_context=E.code_theory pin,limits={nodes=5000,depth=100,seconds=2}});
  val instance=attach();
  val mirror=attach();
  val _=if null(A.observed_oracles(X.contract instance)) then () else error "Domain oracle dependency";
  val _=if X.same_instance(instance,instance) andalso not(X.same_instance(instance,mirror))
    then () else error "Domain instance identity confused";
  fun check original expected =
    let val description=Syntax.string_of_term @{context}(Thm.term_of original);
      val _=phase:="prepare " ^ description;
      val request=ready(X.prepare pin instance original);
      val _=phase:="execute " ^ description;
      val output=ready(X.execute pin instance request);
      val _=phase:="project " ^ description;
      val projected=Thm.term_of(ready(X.project pin output));
      val _=if Thm.term_of(ready(X.registered_input request)) aconv Thm.term_of original andalso
        Thm.term_of(ready(X.input output)) aconv Thm.term_of original
        then () else error "Rational conversion detached original native input";
      val equality= @{term "(=) :: domain_reply \<Rightarrow> domain_reply \<Rightarrow> bool"} $ projected $ expected;
      (* term_of rat deliberately reflects the abstract Frct constructor. The
         independent equality evaluator must first expand that representation
         by a kernel conversion, just as any explicit rational input must. *)
      val equality_conversion=Simplifier.rewrite
        (fold Simplifier.add_simp
          [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv}]
          (put_simpset HOL_basic_ss @{context}))
        (Thm.cterm_of @{context} equality);
      val _=phase:="verify projected equality " ^ description;
      val result=(evaluate
        (Thm.term_of(Thm.rhs_of equality_conversion))
        handle ERROR message=>error("Domain bundle " ^ !phase ^ ": " ^ message));
      val _=X.release_request request;
    in if result aconv @{term True} then () else error "Actual domain result differs from exact expected value" end;
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Millimetre Inch) [LinearValue Millimetre 94] [] None)"}
    @{term "DomainAnswer (LinearValue Inch (Fract 470 127)) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Millimetre Inch) [LinearValue Millimetre (of_int (94::int))] [] None)"}
    @{term "DomainAnswer (LinearValue Inch (Fract 470 127)) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertPoint Celsius Fahrenheit) [PointValue Celsius 0] [] None)"}
    @{term "DomainAnswer (PointValue Fahrenheit 32) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertDelta Celsius Fahrenheit) [DeltaValue Celsius 10] [] None)"}
    @{term "DomainAnswer (DeltaValue Fahrenheit 18) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Metre Kilogram) [LinearValue Metre 1] [] None)"}
    @{term "DomainRejected QuantityMismatch"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertPoint Kelvin Celsius) [PointValue Kelvin (-1)] [] None)"}
    @{term "DomainRejected BelowAbsoluteZero"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertPoint Celsius Fahrenheit) [DeltaValue Celsius 10] [] None)"}
    @{term "DomainRejected MalformedCarrier"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (Spring SpringExtension) [LinearValue NewtonPerMetre 0,LinearValue Newton 20] [] (Some 105))"}
    @{term "DomainRejected InvalidSpringParameters"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (Spring SpringEnergy) [LinearValue NewtonPerMetre 200,LinearValue Metre 1] [700] None)"}
    @{term "DomainBlocked MissingIdealModel"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (Spring SpringForce) [LinearValue NewtonPerMetre 1,LinearValue Metre 1] [] (Some 1))"}
    @{term "DomainAnswer (LinearValue Newton 1) [1]"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Millimetre Inch) [LinearValue Millimetre (Rat.Frct (94,1))] [] None)"}
    @{term "DomainAnswer (LinearValue Inch (Fract 470 127)) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre (Rat.Frct (2,4))] [] None)"}
    @{term "DomainAnswer (LinearValue Centimetre 50) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre (Rat.Frct (1,-2))] [] None)"}
    @{term "DomainAnswer (LinearValue Centimetre (-50)) []"};
  val _=check @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre (Rat.Frct (1,0))] [] None)"}
    @{term "DomainAnswer (LinearValue Centimetre 0) []"};
  val _=case X.prepare pin instance @{cterm "registered_domain_dispatch
      (DomainCall (ConvertLinear Metre Centimetre)
        [LinearValue Metre (Rat.Frct (quotient_of (Rat.Frct (1,2))))] [] None)"} of
      X.Refused X.Unsupported_Input=>() | _=>error "Computed abstract representation bypassed literal preflight";
  val reflected_call=evaluate
    @{term "DomainCall (ConvertLinear Millimetre Inch) [LinearValue Millimetre (Fract 94 1)] [] None"};
  val reflected_input=Thm.cterm_of @{context} (@{term registered_domain_dispatch} $ reflected_call);
  val _=check reflected_input @{term "DomainAnswer (LinearValue Inch (Fract 470 127)) []"};
  val original= @{cterm "registered_domain_dispatch
    (DomainCall (Spring SpringEnergy) [LinearValue NewtonPerMetre 200,LinearValue Metre (Fract 1 10)] [700] (Some 105))"};
  val request=ready(X.prepare pin instance original);
  val other=ready(X.prepare pin instance original);
  val _=if ready(X.modeled_cost request)>0 then () else error "Zero domain modeled charge";
  val _=if Thm.term_of(ready(X.registered_input request)) aconv Thm.term_of original
    then () else error "Domain registered input lost exact request";
  val output=ready(X.execute pin instance request);
  val _=if X.belongs_to request output andalso not(X.belongs_to other output)
    then () else error "Equal domain calls confused invocation identity";
  val cancelled_root=Unsynchronized.ref(NONE:X.request option);
  val cancelled_output=Unsynchronized.ref(NONE:X.output option);
  val cancellation=Exn.capture(fn()=>Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=restore(fn()=>ignore(ready(X.prepare_into pin instance original cancelled_root)))();
      val r=the(!cancelled_root);
      val _=restore(fn()=>cancelled_output:=SOME(ready(X.execute pin instance r)))();
    in restore(fn()=>raise Thread.Thread.Interrupt)()end)())();
  val _=case cancellation of Exn.Exn exn=>if Exn.is_interrupt exn then ()else Exn.reraise exn
    | Exn.Res _=>error "Bundle cancellation fixture did not interrupt";
  val _=case !cancelled_root of SOME r=>X.release_request r
    | NONE=>error "Interrupted bundle publication lost cleanup ownership";
  val _=case !cancelled_output of SOME answer=>(case X.project pin answer of
      X.Refused X.Released=>() | _=>error "Cancelled bundle output remained accessible")
    | NONE=>error "Bundle cancellation fixture did not compute";
  val _=ignore(ready(X.project pin output));
  val projected=Thm.term_of(ready(X.project pin output));
  val expected= @{term "DomainAnswer (LinearValue Joule 1) [105,700]"};
  val equality= @{term "(=) :: domain_reply \<Rightarrow> domain_reply \<Rightarrow> bool"} $ projected $ expected;
  val expanded=Thm.rhs_of(Simplifier.rewrite
    (fold Simplifier.add_simp
          [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv}]
          (put_simpset HOL_basic_ss @{context}))
    (Thm.cterm_of @{context} equality));
  val _=if evaluate (Thm.term_of expanded) aconv @{term True}
    then () else error "Projected actual spring result lost exact value or conditional scope";
  val _=case X.execute pin mirror request of X.Refused X.Wrong_Generation=>()
    | _=>error "Domain cross-instance execution escaped";
  val impostor=E.pin(E.code_theory pin)(E.manifest pin);
  val _=case X.prepare impostor instance original of X.Refused X.Wrong_Executable=>()
    | _=>error "Domain equal-manifest executable confused";
  val _=X.release_request request;
  val _=case X.project pin output of X.Refused X.Released=>()
    | _=>error "Domain release retained output";
  val _=case X.registered_input request of X.Refused X.Released=>()
    | _=>error "Domain release retained request";
  val _=X.release_request other;
  val one_packet= @{cterm "registered_domain_dispatch (DomainCall (ConvertLinear Metre Centimetre)
    [LinearValue Metre (Rat.Frct (Code_Numeral.int_of_integer (1::integer),Code_Numeral.int_of_integer (1::integer)))] [] None)"};
  val bound_instance=ready(X.attach{policy=A.policy @{theory},generation=generation,
    code_context=E.code_theory pin,limits={nodes=Term.size_of_term(Thm.term_of one_packet),depth=100,seconds=2}});
  val _=case X.prepare pin bound_instance one_packet of X.Refused X.Request_Bound=>()
    | _=>error "Kernel input conversion bypassed original materialization bound";
  val _=X.release_instance bound_instance;
  val _=X.release_instance mirror;
  val _=X.release_instance instance;
  val _=if not(X.same_instance(instance,instance)) then () else error "Released domain instance live";
in val _=writeln "VERI7VN_DOMAINS admitted_bundle PASS" end;
\<close>
end
