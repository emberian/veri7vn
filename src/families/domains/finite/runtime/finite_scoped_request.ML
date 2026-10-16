(* Fixed original-child association for literal finite-model requests. This
   certifies syntax/lifetime association; generated Owner still licenses work
   and publication. A result target is not a per-answer kernel theorem. *)
signature VERI7VN_FINITE_SCOPED_REQUEST =
sig
  type request type result
  datatype result_view = Answer of cterm | Rejected | Incomplete
  val prepare_child_into: {child:Veri7vn_Native_Request_Scope.child,
    instance:Veri7vn_Finite_Execution.instance,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner} -> request option Unsynchronized.ref -> request
  val prepare_child: {child:Veri7vn_Native_Request_Scope.child,
    instance:Veri7vn_Finite_Execution.instance,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner} -> request
  val live: request -> bool
  val child: request -> Veri7vn_Native_Request_Scope.child
  val identity: request -> Veri7vn_Native_Request_Scope.identity
  val input: request -> cterm
  val original: request -> Veri7vn_Native_Literals.slice
  val convention: request -> string
  val dependencies: request -> IntInf.int list
  val family_request: request -> Veri7vn_Finite_Execution.request
  val instance: request -> Veri7vn_Finite_Execution.instance
  val associate_into: request -> Veri7vn_Finite_Execution.output -> result option Unsynchronized.ref -> result
  val associate: request -> Veri7vn_Finite_Execution.output -> result
  val result_live: result -> bool
  val result_request: result -> request
  val target: result -> cterm
  val output: result -> Veri7vn_Finite_Execution.output
  val view: result -> result_view
  val implementation: result -> Veri7vn_Native_Admission.accepted
  val release_result: result -> unit
  val release: request -> unit
end;
structure Veri7vn_Finite_Scoped_Request :> VERI7VN_FINITE_SCOPED_REQUEST =
struct
  structure X=Veri7vn_Finite_Execution;
  structure P=Veri7vn_Managed_Provenance;
  structure S=Veri7vn_Native_Request_Scope;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  type payload={child:S.child,instance:X.instance,request:X.request,
    source:P.source_owner,development:P.development,input:cterm,convention:string};
  datatype request=Request of payload option Synchronized.var;
  datatype result_view=Answer of cterm | Rejected | Incomplete;
  datatype result=Result of {request:request,output:X.output,target:cterm,view:result_view} option Synchronized.var;
  fun require true _=() | require false reason=error reason;
  fun ready(X.Ready value)=value | ready(X.Refused _)=error "Finite family object unavailable";
  fun get(Request root)=case Synchronized.value root of SOME p=>p | NONE=>error "Finite request released";
  fun live request=(let val{child,instance,request=family,source,development,...}=get request
    in S.child_live child andalso P.development_live development andalso
      P.owns_input source(L.owner(S.source child)) andalso
      X.same_instance(instance,instance) andalso
      R.same_generation(P.generation development,A.generation(X.contract instance)) andalso
      (ignore(ready(X.registered_input family));true)end)handle ERROR _=>false;
  fun checked request=(require(live request)"Finite original child/source unavailable";get request);
  fun child request= #child(checked request);
  fun identity request=S.identity(child request);
  fun input request= #input(checked request);
  fun original request=S.source(child request);
  fun convention request= #convention(checked request);
  fun family_request request= #request(checked request);
  fun instance request= #instance(checked request);
  fun control_ids({request,goal,slot,interpretation,decision}:S.identity)=
    [request,goal,slot,interpretation,decision];
  fun dependencies request=let val{child,source,development,...}=checked request
    in distinct(op =)(control_ids(S.identity child) @
      maps(control_ids o S.identity)(S.predecessors child) @
      P.source_identity source :: P.development_dependencies development)end;
  fun prepare_child_into {child,instance,development,source} owned=
    let val _=require(is_none(!owned))"Finite request ownership root occupied";
      val _=require(S.child_live child andalso S.unclaimed child)"Finite child denied or already claimed";
      val workspace=I.workspace(S.allocator(S.parent child));
      val _=require(P.source_workspace source=workspace andalso
        P.development_workspace development=workspace andalso
        P.development_live development andalso P.owns_input source(L.owner(S.source child)))
        "Finite child source/development owner mismatch";
      val _=require(R.same_generation(P.generation development,A.generation(X.contract instance)))
        "Finite development/executable generation mismatch";
      val ctxt=R.context(P.generation development);
      val(input,convention)=(case Veri7vn_Finite_Interpretation.interpret ctxt(S.source child)of
          Veri7vn_Finite_Interpretation.Proposed{input,convention,...}=>(input,convention)
        | Veri7vn_Finite_Interpretation.Malformed reason=>error reason
        | Veri7vn_Finite_Interpretation.Unrecognized=>error "Finite literal interpretation unavailable");
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val retained=S.retain_child child;
        val family_root=Unsynchronized.ref(NONE:X.request option);
        val made=Exn.capture(fn()=>
          let val family=restore(fn()=>ready(X.prepare_into(X.executable())instance input family_root))();
            val request=Request(Synchronized.var "finite_scoped_request"
              (SOME{child=retained,instance=instance,request=family,source=source,
                development=development,input=input,convention=convention}));
            val _=require(live request)"Finite original revoked during preparation";
            val _=S.claim retained;
            val _=owned:=SOME request;
          in request end)();
      in case made of Exn.Res request=>request | Exn.Exn exn=>
        (Option.app X.release_request(!family_root);S.release_child retained;Exn.reraise exn)end)()end;
  fun prepare_child args=prepare_child_into args(Unsynchronized.ref NONE);
  fun result_payload(Result root)=case Synchronized.value root of SOME p=>p | NONE=>error "Finite result released";
  fun result_live result=(let val{request,output,...}=result_payload result
    in live request andalso X.belongs_to(family_request request)output andalso
      (ignore(ready(X.input output));true)end)handle ERROR _=>false;
  fun result_checked result=(require(result_live result)"Finite result association unavailable";result_payload result);
  fun result_request result= #request(result_checked result);
  fun target result= #target(result_checked result);
  fun output result= #output(result_checked result);
  fun view result= #view(result_checked result);
  fun implementation result=X.contract(instance(result_request result));
  fun associate_into request output owned=
    let val _=require(is_none(!owned))"Finite result ownership root occupied";
      val _=require(live request andalso X.belongs_to(family_request request)output)
        "Finite result belongs to another original request";
      val contract=X.contract(instance request);
      val actual=ready(X.implementation_contract output);
      val _=require(Thm.eq_thm(A.theorem contract,A.theorem actual) andalso
        null(A.observed_oracles actual) andalso null(Thm.hyps_of(A.theorem actual)) andalso
        Thm.nprems_of(A.theorem actual)=0 andalso
        R.same_generation(A.generation actual,ready(X.native_generation output)))
        "Finite fixed implementation association differs";
      val ctxt=R.context(A.generation actual);
      val reply=ready(X.project(X.executable())output);
      val call=(case strip_comb(Thm.term_of(input request))of (_, [call])=>call
        | _=>error "Finite original input shape differs");
      val target=Thm.cterm_of ctxt(HOLogic.mk_Trueprop(@{const finite_call_meaning}$call$Thm.term_of reply));
      val view=(case strip_comb(Thm.term_of reply)of
          (Const(name,_),[value,conditions])=>
            if name= @{const_name FiniteAnswer} andalso conditions aconv HOLogic.mk_list HOLogic.natT []
            then Answer(Thm.cterm_of ctxt value)else error "Finite unexpected answer conditions"
        | (Const(name,_),[])=>if name= @{const_name FiniteRejected} then Rejected
            else if name= @{const_name FiniteIncomplete} then Incomplete
            else error "Finite unexpected reply constructor"
        | _=>error "Finite reply shape differs");
      val result=Result(Synchronized.var "finite_scoped_result"(SOME{request=request,output=output,target=target,view=view}));
      val _=require(result_live result)"Finite original revoked during result association";
      val _=owned:=SOME result;
    in result end;
  fun associate request output=associate_into request output(Unsynchronized.ref NONE);
  fun release_result(Result root)=Synchronized.change root(K NONE);
  fun release(Request root)=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result root(fn old=>(old,NONE))of NONE=>()
    | SOME{request,child,...}=>(X.release_request request;S.release_child child));
end;
