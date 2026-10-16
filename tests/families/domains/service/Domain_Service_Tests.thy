theory Domain_Service_Tests
  imports Veri7vn_Domain_Service_Objects.Domain_Service_Objects
begin
ML \<open>
local
  structure M=Veri7vn_Domain_Execution;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure Private=Veri7vn_Private_Operation_Tickets ();
  structure View:VERI7VN_OPERATION_TICKET_VIEW=Private;
  structure Worker=Veri7vn_Domain_Ticket_Execution_Fn
    (structure Domain=M structure Tickets=View);
  fun domain_failure M.Wrong_Executable="Wrong_Executable"
    | domain_failure M.Wrong_Generation="Wrong_Generation"
    | domain_failure (M.Invalid_Contract reasons)="Invalid_Contract: " ^ commas reasons
    | domain_failure M.Request_Bound="Request_Bound"
    | domain_failure M.Unsupported_Input="Unsupported_Input"
    | domain_failure M.Execution_Budget="Execution_Budget"
    | domain_failure M.Released="Released"
    | domain_failure (M.Runtime_Error message)="Runtime_Error: " ^ message;
  fun worker_failure (Worker.Ticket_Rejected message)="Ticket_Rejected: " ^ message
    | worker_failure Worker.Wrong_Executable="Wrong_Executable"
    | worker_failure Worker.Wrong_Generation="Wrong_Generation"
    | worker_failure Worker.Wrong_Operation="Wrong_Operation"
    | worker_failure Worker.Wrong_Cost="Wrong_Cost"
    | worker_failure Worker.Request_Already_Owned="Request_Already_Owned"
    | worker_failure (Worker.Execution_Failed reason)="Execution_Failed " ^ domain_failure reason
    | worker_failure Worker.Released="Released"
    | worker_failure Worker.Worker_Failed="Worker_Failed (exceptional Future completion)";
  val issuer=Private.new_issuer ();
  val pin=M.executable ();
  val generation=R.generation @{context} {packages=["quantities"],runtime="ticket-test",
    policy="fixed-operation-test",sources=[],interpretation="typed-domain-call"};
  val instance=(case M.attach {policy=A.policy @{theory},generation=generation,
    code_context=E.code_theory pin,limits={nodes=5000,depth=100,seconds=2}} of
    M.Ready value=>value | _=>error "domain instance fixture");
  fun prepared native=(case M.prepare pin instance native of M.Ready value=>value
    | M.Refused reason=>error ("domain prepared fixture: " ^ domain_failure reason));
  fun charge request=(case M.modeled_cost request of M.Ready value=>value
    | _=>error "domain actual charge unavailable");
  fun issued execution request extra =
    let
      val scope=Private.begin_scope issuer {owner_version=0,epoch=0};
      val operation:Private.operation_identity={workspace="fixture",request=2,profile=3,
        code_generation=4,operation=5,step=0,cost=charge request+extra,inputs=[6],
        owner_version=0,epoch=0,journal_sequence=1,semantic_generation=7,
        implementation_artifact="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"};
      val ticket=Private.issue_pure scope {execution=execution,slot=8,operation=operation}
        {executable=pin,instance=instance,request=request,operation=M.operation instance};
      val answer=Worker.start ticket;
      val _=Private.close_scope scope;
    in answer end;
  fun job (Worker.Ready value)=value
    | job (Worker.Refused reason)=error ("charged domain worker did not start: " ^ worker_failure reason);
  fun result task=(case Worker.collect task of Worker.Ready value=>value
    | Worker.Refused reason=>error ("charged domain worker terminal refusal: " ^ worker_failure reason));
  fun evaluate term=Timeout.apply(Time.fromSeconds 5)(fn()=>
    (* dynamic_value_strict certifies the reflected term itself, so the dry
       preflight sentinel is not a legal input to that API. The actual scoped
       materializer still charges every constructor before allocating it. *)
    (Veri7vn_Bounded_Projection.materialize 20000
      (fn()=>Code_Evaluation.dynamic_value_strict @{context} term)))();
  fun exact output expected=(case Worker.native_output output of Worker.Ready native=>
    (case M.project pin native of M.Ready projected=>
      let val equality= @{term "(=) :: domain_reply \<Rightarrow> domain_reply \<Rightarrow> bool"}
        $ Thm.term_of projected $ expected
        val expanded=Thm.rhs_of(Simplifier.rewrite
          (fold Simplifier.add_simp
          [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv}]
          (put_simpset HOL_basic_ss @{context}))
          (Thm.cterm_of @{context} equality))
      in if evaluate (Thm.term_of expanded) aconv @{term True}
        then () else error "wrong domain worker value" end
    | _=>error "domain exact projection unavailable") | _=>error "worker output unavailable");
  val one=prepared @{cterm "registered_domain_dispatch
    (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre 2] [700] None)"};
  val first=job (issued 1 one 0);
  val _=(case issued 2 one 0 of Worker.Refused Worker.Request_Already_Owned=>()
    | _=>error "same native request transferred to two workers");
  val two=prepared @{cterm "registered_domain_dispatch
    (DomainCall (Spring SpringEnergy) [LinearValue NewtonPerMetre 200, LinearValue Metre (Fract 1 10)] [700] (Some 105))"};
  val second=job (issued 3 two 0);
  val first_output=result first;
  val second_output=result second;
  val _=exact first_output @{term "DomainAnswer (LinearValue Centimetre 200) [700]"};
  val _=exact second_output @{term "DomainAnswer (LinearValue Joule 1) [105,700]"};
  val _=Worker.cancel first;
  val _=(case Worker.native_output first_output of Worker.Refused Worker.Released=>()
    | _=>error "cancelled worker output retained");
  val _=exact second_output @{term "DomainAnswer (LinearValue Joule 1) [105,700]"};
  val wrong=prepared @{cterm "registered_domain_dispatch
    (DomainCall (ConvertDelta Celsius Fahrenheit) [DeltaValue Celsius 10] [] None)"};
  val _=(case issued 4 wrong 1 of Worker.Refused Worker.Wrong_Cost=>()
    | _=>error "caller charge accepted instead of actual prepared charge");
  val _=(case M.modeled_cost wrong of M.Refused M.Released=>()
    | _=>error "failed transferred request payload retained");
  val _=Worker.cancel second;
  val _=M.release_instance instance;
in
  val _=writeln "VERI7VN_DOMAINS ticket_workers PASS";
end;
\<close>
ML \<open>
local
  structure C=Veri7vn_Domain_Conditions;
  structure R=Veri7vn_Native_Registry;
  structure L=Veri7vn_Native_Literals;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  val ids=IDs.install_host_block{workspace="dddddddddddddddddddddddddddddddd",first=1,past=1000};
  val development=P.public_image ids (Veri7vn_Native_Admission.policy @{theory});
  val generation=P.generation development;
  val model_text="ideal_spring_model force_response energy_response";
  val condition_text="calibration_is_current";
  val original=L.input{bytes=model_text ^ "\n" ^ condition_text,encoding="UTF-8"};
  val source=P.install_host_source ids original;
  val model_slice=L.slice original{start=0,stop=size model_text,expected=model_text};
  val condition_slice=L.slice original{start=size model_text+1,stop=size model_text+1+size condition_text,expected=condition_text};
  val model_statement= @{cterm "ideal_spring_model force_response energy_response"};
  val model_proposition=Thm.cterm_of @{context}(HOLogic.mk_Trueprop(Thm.term_of model_statement));
  val model=C.prepare{allocator=ids,development=development,source=source,slice=model_slice,
    role=C.IdealSpringModel,proposition=model_proposition};
  val wrong_input=L.input{bytes=L.bytes original,encoding="UTF-8"};
  val wrong_source=P.install_host_source ids wrong_input;
  val _=if can(fn()=>C.prepare{allocator=ids,development=development,source=wrong_source,
    slice=model_slice,role=C.IdealSpringModel,proposition=model_proposition})()
    then error "Equal source bytes replaced actual native proposition owner" else ();
  val _=Option.app IDs.release_disposed_input(L.drop_base wrong_input);
  val condition=C.prepare{allocator=ids,development=development,source=source,slice=condition_slice,
    role=C.InputCondition,proposition= @{cprop "calibration_is_current"}};
  val cancelled_condition=Unsynchronized.ref(NONE:C.condition option);
  val condition_cancel=Exn.capture(fn()=>Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=restore(fn()=>ignore(C.prepare_into{allocator=ids,development=development,
      source=source,slice=condition_slice,role=C.InputCondition,
      proposition= @{cprop "calibration_is_current"}}cancelled_condition))()
    in restore(fn()=>raise Thread.Thread.Interrupt)()end)())();
  val _=case condition_cancel of Exn.Exn exn=>if Exn.is_interrupt exn then ()else Exn.reraise exn
    | Exn.Res _=>error "Condition publication fixture did not interrupt";
  val retired_condition=the(!cancelled_condition);
  val _=C.release retired_condition;
  val _=if not(C.live retired_condition) andalso C.live condition andalso C.live model then ()
    else error "Condition rollback lost independent premise ownership";
  fun number n=HOLogic.mk_number @{typ nat}(IntInf.toInt n);
  val call= @{term "\<lambda>conditions model. registered_domain_dispatch
    (DomainCall (Spring SpringEnergy) [LinearValue NewtonPerMetre 200,LinearValue Metre (Fract 1 10)] conditions model)"};
  fun input model_id=Thm.cterm_of @{context}(Envir.beta_norm(call $
    HOLogic.mk_list @{typ nat}[number(C.identity condition)] $
    (Const(@{const_name Some}, @{typ "nat \<Rightarrow> nat option"}) $ number model_id)));
  val actual=input(C.identity model);
  val statements=C.check_call generation actual [model,condition];
  val _=if length statements=2 andalso exists(fn ct=>Thm.term_of ct aconv Thm.term_of model_proposition)statements
    andalso L.same_input(C.owner model,original) andalso
    C.owner_identity model=the(IDs.lookup_input_identity ids original)
    then () else error "Native model statement/identity/owner association lost";
  structure D=Veri7vn_Domain_Request;
  structure M=Veri7vn_Domain_Execution;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  fun ready(M.Ready x)=x | ready(M.Refused _)=error "Domain native request fixture refused";
  val instance=ready(M.attach{policy=A.policy @{theory},generation=generation,
    code_context=E.code_theory(M.executable()),limits={nodes=5000,depth=100,seconds=2}});
  fun request_text model="registered_domain_dispatch (DomainCall (Spring SpringEnergy) " ^
    "[LinearValue NewtonPerMetre 200,LinearValue Metre (Fract 1 10)] [" ^
    IntInf.toString(C.identity condition) ^ "] " ^ model ^ ")";
  val text=request_text("(Some " ^ IntInf.toString(C.identity model) ^ ")");
  val request_input=L.input{bytes=text,encoding="UTF-8"};
  val request_source=P.install_host_source ids request_input;
  val request_slice=L.slice request_input{start=0,stop=size text,expected=text};
  val request=D.prepare{allocator=ids,instance=instance,development=development,
    source=request_source,slice=request_slice,input=actual,conditions=[model,condition]};
  val _=(case D.model_contract request of SOME accepted=>
    if null(A.observed_oracles accepted) andalso
      Thm.prop_of(A.theorem accepted) aconv Thm.prop_of @{thm domain_model_execution_contract}
      then () else error "Domain model bridge was not admitted exactly"
    | NONE=>error "Domain request lost adopted-model bridge contract");
  val saved=D.snapshot request;
  val forged:D.saved={workspace= #workspace saved,input_identity= #input_identity saved,
    input= #input saved,template= #template saved,bytes= #bytes saved,encoding= #encoding saved,
    owners= #owners saved,input_source_span= #input_source_span saved,context_dependencies= #context_dependencies saved,
    implementation= #implementation saved,model_contract= #model_contract saved,
    conditions=map(fn(c:D.condition_snapshot)=>{identity= #identity c,owner_identity= #owner_identity c,
      role= #role c,proposition= @{prop True},source_span= #source_span c,dependencies= #dependencies c})(#conditions saved)};
  val _=if D.matches_snapshot request saved andalso not(D.matches_snapshot request forged)
    then () else error "Recovery comparison accepted changed native condition statements";
  val frozen=D.original_template request;
  val output=ready(M.execute(M.executable())instance(D.family_request request));
  val _=(case D.result_view request output of D.Answer{value,...}=>
    if fastype_of(Thm.term_of value)= @{typ domain_value}then () else error "Domain answer lost typed unit value"
    | _=>error "Domain numeric output was not distinguished");
  val target=D.specialize request output;
  val expected=HOLogic.mk_Trueprop(Thm.term_of(Thm.apply frozen(ready(M.project(M.executable())output))));
  val _=if Thm.term_of target aconv expected andalso length(D.native_conditions request)=2
    andalso Thm.term_of(D.input request) aconv Thm.term_of actual
    then () else error "Domain specialization replaced original model-aware predicate";
  val other=D.prepare{allocator=ids,instance=instance,development=development,
    source=request_source,slice=request_slice,input=actual,conditions=[model,condition]};
  (* A real interrupt at the ownership-transfer boundary must leave a cleanup
     handle, including its already-computed output, without retiring siblings. *)
  val cancelled_root=Unsynchronized.ref(NONE:D.request option);
  val cancelled_output=Unsynchronized.ref(NONE:M.output option);
  val cancellation=Exn.capture(fn()=>Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=restore(fn()=>ignore(D.prepare_into{allocator=ids,instance=instance,development=development,
        source=request_source,slice=request_slice,input=actual,conditions=[model,condition]}cancelled_root))();
      val r=the(!cancelled_root);
      val _=restore(fn()=>cancelled_output:=SOME(ready(M.execute(M.executable())instance(D.family_request r))))();
    in restore(fn()=>raise Thread.Thread.Interrupt)()end)())();
  val _=case cancellation of Exn.Exn exn=>if Exn.is_interrupt exn then ()else Exn.reraise exn
    | Exn.Res _=>error "Domain cancellation fixture did not interrupt";
  val _=case !cancelled_root of SOME r=>D.release r
    | NONE=>error "Interrupted domain publication lost cleanup ownership";
  val _=case !cancelled_output of SOME answer=>(case M.project(M.executable())answer of
      M.Refused M.Released=>() | _=>error "Cancelled domain output remained physically accessible")
    | NONE=>error "Domain cancellation fixture did not reach computed output";
  val _=if D.live request andalso D.live other andalso C.live model
    then (ignore(D.specialize request output);())
    else error "Cancelled domain publication retired an independent positive owner";
  val _=writeln "VERI7VN_DOMAINS prepare_into_rollback PASS";
  val wrong_text="registered_domain_dispatch (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre 94] [] None)";
  val wrong_owner=L.input{bytes=wrong_text,encoding="UTF-8"};
  val wrong_request_source=P.install_host_source ids wrong_owner;
  val wrong_slice=L.slice wrong_owner{start=0,stop=size wrong_text,expected=wrong_text};
  val _=if can(fn()=>D.prepare{allocator=ids,instance=instance,development=development,
    source=wrong_request_source,slice=wrong_slice,input=actual,conditions=[model,condition]})()
    then error "Unrelated original bytes authorized domain native request" else ();
  val _=Option.app IDs.release_disposed_input(L.drop_base wrong_owner);
  val _=if can(fn()=>D.specialize other output)()
    then error "Equal domain inputs confused native request identity" else ();
  val evidence_lease=C.retain model;
  val _=List.app C.drop_base [model,condition];
  val _=D.release other;
  val _=if D.live request andalso C.live model then ()
    else error "Releasing one request destroyed surviving shared condition leases";
  val wrong_role=C.prepare{allocator=ids,development=development,source=source,slice=model_slice,
    role=C.InputCondition,proposition=model_proposition};
  val _=if can(fn()=>C.check_call generation(input(C.identity wrong_role))[wrong_role,condition])()
    then error "Unclassified premise authorized spring model adoption" else ();
  val _=if can(fn()=>C.prepare{allocator=ids,development=development,source=source,slice=model_slice,
    role=C.IdealSpringModel,proposition= @{cprop True}})()
    then error "Arbitrary proposition accepted as ideal spring response model" else ();
  val missing_input=Thm.cterm_of @{context}(Envir.beta_norm(call $
    HOLogic.mk_list @{typ nat}[number(C.identity condition)] $ @{term "None::nat option"}));
  val missing_text=request_text "None";
  val missing_owner=L.input{bytes=missing_text,encoding="UTF-8"};
  val missing_source=P.install_host_source ids missing_owner;
  val missing_slice=L.slice missing_owner{start=0,stop=size missing_text,expected=missing_text};
  val missing=D.prepare{allocator=ids,instance=instance,development=development,
    source=missing_source,slice=missing_slice,input=missing_input,conditions=[condition]};
  val missing_output=ready(M.execute(M.executable())instance(D.family_request missing));
  val _=(case D.result_view missing missing_output of D.NeedsIdealModel=>()
    | _=>error "Missing model was reinterpreted as numerical answer/rejection");
  val _=D.release missing;
  val _=Option.app IDs.release_disposed_input(L.drop_base missing_owner);
  val _=L.invalidate original;
  val _=if C.live model orelse can(fn()=>C.check_call generation actual[model,condition])()
    then error "Forgotten premise owner retained usable domain association" else ();
  val _=if D.live request then error "Domain native request survived forgotten premise owner" else ();
  val _=D.release request;
  val _=M.release_instance instance;
  val _=Option.app IDs.release_disposed_input(L.drop_base request_input);
  val _=List.app C.release [model,condition,wrong_role];
  val _=ignore(L.drop_base original);
  val _=if L.disposed original then error "Outstanding evidence lease lost original condition owner" else ();
  val _=C.release_lease evidence_lease;
  val _=P.release development;
  val _=if L.disposed original then () else error "Domain condition leases retained original bytes";
in val _=writeln "VERI7VN_DOMAINS native_conditions PASS" end;
\<close>

ML \<open>
local
  structure C=Veri7vn_Domain_Conditions;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  val ids=IDs.install_host_block{workspace="cccccccccccccccccccccccccccccccc",first=1,past=1000};
  val base=P.public_image ids(Veri7vn_Native_Admission.policy @{theory});
  fun definition rhs=
    let val input=L.input{bytes=rhs,encoding="UTF-8"};
      val source=P.install_host_source ids input;
      val slice=L.slice input{start=0,stop=size rhs,expected=rhs};
      val(development,_,fact)=P.define_from_slice base source(Binding.name "domain_receiver_value")slice;
    in(development,fact,input)end;
  val(left,left_fact,left_input)=definition "0::nat";
  val(right,right_fact,right_input)=definition "1::nat";
  val text="domain_receiver_value = (0::nat)";
  val input=L.input{bytes=text,encoding="UTF-8"};
  val source=P.install_host_source ids input;
  val slice=L.slice input{start=0,stop=size text,expected=text};
  fun statement development=let val ctxt=R.context(P.generation development)
    in Thm.cterm_of ctxt(Syntax.read_prop ctxt text)end;
  val original=statement left;
  val different=statement right;
  val first=C.prepare{allocator=ids,development=left,source=source,slice=slice,
    role=C.InputCondition,proposition=original};
  val second=C.prepare{allocator=ids,development=right,source=source,slice=slice,
    role=C.InputCondition,proposition=different};
  val _=if can(fn()=>C.prepare{allocator=ids,development=right,source=source,slice=slice,
    role=C.InputCondition,proposition=original})()
    then error "Same proposition text crossed incompatible native receiver contexts" else ();
  val _=if C.dependencies first=C.dependencies second
    then error "Different native model contexts lost managed ancestry" else ();
  val sibling_lease=C.retain second;
  val _=C.drop_base second;
  val _=P.release left;
  val _=if C.live first orelse not(C.live(C.lease_condition sibling_lease))
    then error "Released receiver context damaged native sibling ownership" else ();
  val _=C.release first;
  val _=C.release_lease sibling_lease;
  val _=P.release right;
  val _=List.app P.release_consequence[left_fact,right_fact];
  val _=P.release base;
  val _=List.app(fn owner=>Option.app IDs.release_disposed_input(L.drop_base owner))[input,left_input,right_input];
  val _=if List.all L.disposed[input,left_input,right_input]then ()
    else error "Native context/condition cleanup retained source payloads";
in val _=writeln "VERI7VN_DOMAINS native_context_ownership PASS" end;
\<close>

end
