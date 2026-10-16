(* Fixed native refinement association. The target is certified syntax, not a
   kernel theorem of the materialized answer. Accepted universal contracts,
   actual generated execution and exact adopted assumptions remain distinct. *)
signature VERI7VN_POLICY_NATIVE_GATE =
sig
  type witness
  type saved={scope:Veri7vn_Scoped_Policy_Request.saved,raw:Veri7vn_Domain_Saved_Types.output_saved}
  val specialize: Veri7vn_Policy_Display.bridge -> Veri7vn_Scoped_Policy_Request.request ->
    Veri7vn_Policy_Execution.output -> witness
  val specialize_into: Veri7vn_Policy_Display.bridge -> Veri7vn_Scoped_Policy_Request.request ->
    Veri7vn_Policy_Execution.output -> witness option Unsynchronized.ref -> witness
  val retain: witness -> witness
  val retain_into: witness -> witness option Unsynchronized.ref -> witness
  val live: witness -> bool
  val request: witness -> Veri7vn_Scoped_Policy_Request.request
  val output: witness -> Veri7vn_Policy_Execution.output
  val target: witness -> cterm
  val implementation: witness -> Veri7vn_Native_Admission.accepted
  val model_contract: witness -> Veri7vn_Native_Admission.accepted option
  val rendering_contract: witness -> Veri7vn_Native_Admission.accepted
  val assumptions: witness -> cterm list
  val conditions: witness -> Veri7vn_Domain_Conditions.condition list
  val managed_dependencies: witness -> IntInf.int list
  val display: witness -> Veri7vn_Policy_Display.projection
  val snapshot: witness -> saved
  val matches_snapshot: witness -> saved -> bool
  val release: witness -> unit
end;
structure Veri7vn_Policy_Native_Gate :> VERI7VN_POLICY_NATIVE_GATE =
struct
  structure D=Veri7vn_Policy_Request;
  structure S=Veri7vn_Scoped_Policy_Request;
  structure M=Veri7vn_Policy_Execution;
  structure V=Veri7vn_Policy_Display;
  structure C=Veri7vn_Domain_Conditions;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  type payload={scope:S.request,request:D.request,output:M.output,target:cterm,implementation:A.accepted,
    model_contract:A.accepted option,bridge:V.bridge,display:V.display,
    conditions:C.condition list,leases:C.lease list};
  datatype witness=Witness of payload option Synchronized.var;
  type saved={scope:Veri7vn_Scoped_Policy_Request.saved,raw:Veri7vn_Domain_Saved_Types.output_saved};
  fun get(Witness root)=(case Synchronized.value root of SOME p=>p
    | NONE=>error "Policy native result association released");
  fun ready(M.Ready value)=value | ready(M.Refused _)=error "Policy native output unavailable";
  fun live witness=(let val{scope,request,output,target,implementation,bridge,leases,...}=get witness
    in S.live scope andalso D.live request andalso V.matches bridge(D.instance request) andalso
      M.belongs_to(D.family_request request)output andalso
      forall(fn held=>(ignore(C.lease_condition held);true))leases andalso
      Thm.term_of(D.specialize request output) aconv Thm.term_of target andalso
      Thm.eq_thm(A.theorem implementation,A.theorem(ready(M.implementation_contract output)))
    end)handle ERROR _=>false;
  fun checked witness=if live witness then get witness else error "Policy native association unavailable";
  fun request w= #scope(checked w);
  fun output w= #output(checked w);
  fun target w= #target(checked w);
  fun implementation w= #implementation(checked w);
  fun model_contract w= #model_contract(checked w);
  fun rendering_contract w=V.contract(#bridge(checked w));
  fun conditions w= #conditions(checked w);
  fun assumptions w=map C.proposition(conditions w);
  fun managed_dependencies w=let val{scope,request,bridge,...}=checked w
    in distinct(op =)(S.managed_dependencies scope @ V.dependencies bridge)end;
  fun display w=V.project(#display(checked w));
  fun snapshot w=let val{scope,request,output,target,implementation,model_contract,bridge,...}=checked w
    in {scope=S.snapshot scope,raw={request=D.snapshot request,output=Thm.term_of(ready(M.project(M.executable())output)),
      target=Thm.term_of target,implementation=Thm.prop_of(A.theorem implementation),
      model_contract=Option.map(Thm.prop_of o A.theorem)model_contract,
      rendering_contract=Thm.prop_of(A.theorem(V.contract bridge)),
      statement_html= #statement_html(display w)}}:saved end;
  (* Data comparison after fixed reconstruction, never restoration authority. *)
  fun matches_snapshot w (saved:saved)=let val actual=snapshot w;
      val a= #raw actual;val b= #raw saved;
      fun same_optional(NONE,NONE)=true
        | same_optional(SOME a,SOME b)=a aconv b | same_optional _=false
    in S.matches_snapshot(request w)(#scope saved) andalso
      D.matches_snapshot(S.native_policy_request(request w))(#request b) andalso
      #output a aconv #output b andalso #target a aconv #target b andalso
      #implementation a aconv #implementation b andalso
      same_optional(#model_contract a,#model_contract b) andalso
      #rendering_contract a aconv #rendering_contract b andalso
      #statement_html a= #statement_html b end;
  fun release(Witness root)=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result root(fn p=>(p,NONE))of NONE=>()
    | SOME{leases,...}=>List.app C.release_lease leases);
  (* Retain the same checked association, not a fresh computation or proof. *)
  fun retain_into original owned=
    let
      val _=if is_none(!owned)then ()else error "Policy evidence ownership root occupied";
      val {scope,request,output,target,implementation,model_contract,bridge,display,conditions,...}=
        checked original;
      fun acquire [] held=rev held
        | acquire(c::rest)held=
          (case Exn.capture C.retain c of Exn.Res lease=>acquire rest(lease::held)
          | Exn.Exn exn=>(List.app C.release_lease held;Exn.reraise exn));
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val leases=acquire conditions [];
        val retained=Witness(Synchronized.var "veri7vn_policy_retained_association"
          (SOME{scope=scope,request=request,output=output,target=target,implementation=implementation,
            model_contract=model_contract,bridge=bridge,display=display,
            conditions=conditions,leases=leases}));
      in owned:=SOME retained;retained end)
    end;
  fun retain original=retain_into original(Unsynchronized.ref NONE);
  fun specialize_into bridge scope output owned=
    let val request=S.native_policy_request scope;
      val _=if is_none(!owned)then ()else error "Policy evidence ownership root occupied";
      val target=S.specialize scope output;
      val implementation=M.contract(D.instance request);
      val actual=ready(M.implementation_contract output);
      val _=if Thm.eq_thm(A.theorem implementation,A.theorem actual) andalso
        R.same_generation(A.generation implementation,ready(M.native_generation output)) andalso
        null(Thm.hyps_of(A.theorem implementation)) andalso
        Thm.nprems_of(A.theorem implementation)=0 andalso null(A.observed_oracles implementation)
        then ()else error "Policy result differs from unconditional admitted implementation";
      val display=V.prepare_exact bridge request output;
      val conditions=D.condition_associations request;
      val model_contract=D.model_contract request;
      val _=if is_none model_contract andalso forall(fn c=>C.role c=C.InputCondition)conditions
        then ()else error "Policy assumptions have unsupported roles or physical-model bridge";
      fun retain [] held=rev held
        | retain(c::rest)held=
          (case Exn.capture C.retain c of Exn.Res lease=>retain rest(lease::held)
          | Exn.Exn exn=>(List.app C.release_lease held;Exn.reraise exn));
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val leases=retain conditions [];
        val witness=Witness(Synchronized.var "veri7vn_policy_native_association"
          (SOME{scope=scope,request=request,output=output,target=target,implementation=implementation,
            model_contract=model_contract,bridge=bridge,display=display,
            conditions=conditions,leases=leases}));
      in if live witness then(owned:=SOME witness;witness)else(release witness;
        error "Policy native association revoked during specialization")end)
    end;
  fun specialize bridge request output=specialize_into bridge request output(Unsynchronized.ref NONE);
end;
