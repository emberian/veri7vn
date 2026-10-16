theory Finite_Bundle_Checks
  imports "Veri7vn_Finite_Runtime.Finite_Bundle"
begin

ML \<open>
local
  structure X=Veri7vn_Finite_Execution;
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

  val generation=R.generation @{context} {packages=["finite-models"],runtime="closed-finite-check",
    policy="native-test",sources=[],interpretation="typed-finite-model"};
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
    ("Finite bundle " ^ !phase ^ ": " ^ failure reason);
  fun attach ()=ready(X.attach{policy=A.policy @{theory},generation=generation,
    code_context=E.code_theory pin,limits={nodes=5000,depth=100,seconds=2}});
  val instance=attach();
  val mirror=attach();
  val _=if null(A.observed_oracles(X.contract instance)) then () else error "Finite oracle dependency";
  val _=if X.same_instance(instance,instance) andalso not(X.same_instance(instance,mirror))
    then () else error "Finite instance identity confused";
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
      val equality= @{term "(=) :: finite_reply \<Rightarrow> finite_reply \<Rightarrow> bool"} $ projected $ expected;
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
        handle ERROR message=>error("Finite bundle " ^ !phase ^ ": " ^ message));
      val _=X.release_request request;
    in if result aconv @{term True} then () else error "Actual finite result differs from exact expected value" end;
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (DrawAll True 2 4 2) [] [17])"}
    @{term "FiniteAnswer (RationalValue (1/4)) [17]"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (DrawAll False 2 4 2) [] [])"}
    @{term "FiniteAnswer (RationalValue (1/6)) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (DieAtLeastOne 6 10 7) [] [])"}
    @{term "FiniteAnswer (RationalValue 0) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (Variance PopulationVariance) [RationalCollection [0,2]] [])"}
    @{term "FiniteAnswer (RationalValue 1) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (Variance SampleVariance) [RationalCollection [0,2]] [])"}
    @{term "FiniteAnswer (RationalValue 2) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall Modes [RationalCollection [1,1,2,2,3]] [])"}
    @{term "FiniteAnswer (RationalCollection [1,2]) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (PopulationEvent PartialPopulation [1]) [RationalCollection [1,2]] [])"}
    @{term FiniteIncomplete};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (LocusCross (CHR ''A'',CHR ''a'') (CHR ''A'',CHR ''a'') (CHR ''a'')) [] [])"}
    @{term "FiniteAnswer (RationalValue (1/4)) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (DiceTotal 6 2 7) [] [])"}
    @{term "FiniteAnswer (RationalValue (1/6)) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (WeightedEvent CompletePopulation [(0,1),(1,3)] [1]) [] [])"}
    @{term "FiniteAnswer (RationalValue (3/4)) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (WeightedEvent CompletePopulation [(0,-1),(1,2)] [1]) [] [])"}
    @{term FiniteRejected};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (Binomial 2 3 (1/2)) [] [])"}
    @{term "FiniteAnswer (RationalValue 0) []"};
  val _=check @{cterm "registered_finite_dispatch
      (FiniteCall (Binomial 0 0 0) [] [])"}
    @{term "FiniteAnswer (RationalValue 1) []"};
  val huge=@{cterm "registered_finite_dispatch (FiniteCall (Choose 1000000 2) [] [])"};
  val _=(case X.prepare pin instance huge of X.Refused X.Unsupported_Input=>()
    | _=>error "Finite operation magnitude guard bypassed");
  val request=ready(X.prepare pin instance @{cterm "registered_finite_dispatch
    (FiniteCall Mean [RationalCollection [1,3]] [])"});
  val _=(case X.execute pin mirror request of X.Refused X.Wrong_Generation=>()
    | _=>error "Finite request crossed instance ownership");
  val output=ready(X.execute pin instance request);
  val _=X.release_request request;
  val _=(case X.project pin output of X.Refused X.Released=>()
    | _=>error "Finite output survived request retirement");
  val _=X.release_instance instance;
  val _=X.release_instance mirror;
  val _=writeln "VERI7VN_FINITE fixed_execution_exact_cases PASS";
in val _=() end
\<close>
end
