(* Fixed SourceDomain publication association. The Domain gate is a constituent,
   never a substitute for the full source-qualified target. *)
signature VERI7VN_SOURCE_DOMAIN_GATE =
sig
  type request type request_saved type source_view
  type witness
  type saved={request:request_saved,domain:Veri7vn_Domain_Native_Gate.saved,target:term}
  type projection={domain:Veri7vn_Domain_Display.projection,sources:source_view list}
  val specialize_into:Veri7vn_Domain_Display.bridge -> request -> Veri7vn_Domain_Execution.output ->
    witness option Unsynchronized.ref -> witness
  val specialize:Veri7vn_Domain_Display.bridge -> request -> Veri7vn_Domain_Execution.output -> witness
  val live:witness -> bool
  val target:witness -> cterm
  val output:witness -> Veri7vn_Domain_Execution.output
  val implementation:witness -> Veri7vn_Native_Admission.accepted
  val model_contract:witness -> Veri7vn_Native_Admission.accepted option
  val rendering_contract:witness -> Veri7vn_Native_Admission.accepted
  val conditions:witness -> Veri7vn_Domain_Conditions.condition list
  val managed_dependencies:witness -> IntInf.int list
  val display:witness -> projection
  val snapshot:witness -> saved
  val matches_snapshot:witness -> saved -> bool
  val release:witness -> unit
end;
functor Veri7vn_Source_Domain_Gate_Fn
  (Q:sig
    type request type saved type source_view
    val retain:request -> request
    val release:request -> unit
    val live:request -> bool
    val family_request:request -> Veri7vn_Domain_Execution.request
    val managed_dependencies:request -> IntInf.int list
    val source_views:request -> source_view list
    val condition_associations:request -> Veri7vn_Domain_Conditions.condition list
    val specialize:request -> Veri7vn_Domain_Execution.output -> cterm
    val snapshot:request -> saved
    val matches_snapshot:request -> saved -> bool
    val domain_gate_into:Veri7vn_Domain_Display.bridge -> request ->
      Veri7vn_Domain_Execution.output -> Veri7vn_Domain_Native_Gate.witness option Unsynchronized.ref ->
      Veri7vn_Domain_Native_Gate.witness
  end) :> VERI7VN_SOURCE_DOMAIN_GATE
  where type request=Q.request and type request_saved=Q.saved
    and type source_view=Q.source_view =
struct
  structure G=Veri7vn_Domain_Native_Gate;
  structure D=Veri7vn_Domain_Request;
  structure M=Veri7vn_Domain_Execution;
  type request=Q.request;
  type request_saved=Q.saved;
  type source_view=Q.source_view;
  type payload={request:Q.request,domain:G.witness,target:cterm};
  datatype witness=Witness of payload option Synchronized.var;
  type saved={request:Q.saved,domain:G.saved,target:term};
  type projection={domain:Veri7vn_Domain_Display.projection,sources:Q.source_view list};
  fun get(Witness root)=case Synchronized.value root of SOME p=>p
    | NONE=>error "SourceDomain gate released";
  fun live w=(let val{request,domain,target}=get w
    in Q.live request andalso G.live domain andalso
      M.same_request(Q.family_request request,D.family_request(G.request domain)) andalso
      Thm.term_of(Q.specialize request(G.output domain)) aconv Thm.term_of target
    end)handle ERROR _=>false;
  fun checked w=if live w then get w else error "SourceDomain gate ancestry unavailable";
  fun target w= #target(checked w);
  fun output w=G.output(#domain(checked w));
  fun implementation w=G.implementation(#domain(checked w));
  fun model_contract w=G.model_contract(#domain(checked w));
  fun rendering_contract w=G.rendering_contract(#domain(checked w));
  fun conditions w=Q.condition_associations(#request(checked w));
  fun managed_dependencies w=let val{request,domain,...}=checked w
    in distinct(op =)(Q.managed_dependencies request @ G.managed_dependencies domain)end;
  fun display w=let val{request,domain,...}=checked w
    in {domain=G.display domain,sources=Q.source_views request}:projection end;
  fun snapshot w=let val{request,domain,target}=checked w
    in {request=Q.snapshot request,domain=G.snapshot domain,target=Thm.term_of target}:saved end;
  fun matches_snapshot w(saved:saved)=let val{request,domain,target}=checked w
    in Q.matches_snapshot request(#request saved) andalso
      G.matches_snapshot domain(#domain saved) andalso Thm.term_of target aconv #target saved end
    handle ERROR _=>false;
  fun release(Witness root)=Thread_Attributes.uninterruptible_body(fn _=>
    Option.app(fn{request,domain,...}:payload=>(G.release domain;Q.release request))
      (Synchronized.change_result root(fn p=>(p,NONE))));
  fun specialize_into bridge request output owned=
    let val _=if is_none(!owned)then ()else error "SourceDomain gate root occupied";
      val target=Q.specialize request output;
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val held=Q.retain request;
        val domain_root=Unsynchronized.ref NONE;
        val built=Exn.capture(fn()=>let
          val _=restore(fn()=>ignore(Q.domain_gate_into bridge held output domain_root))();
          val retained=the(!domain_root);
          val witness=Witness(Synchronized.var "source_domain_gate"
            (SOME{request=held,domain=retained,target=target}));
        in if live witness then(owned:=SOME witness;witness)
          else(release witness;error "SourceDomain gate revoked during publication")end)();
      in case built of Exn.Res w=>w
        | Exn.Exn exn=>(Option.app G.release(!domain_root);Q.release held;Exn.reraise exn)end)()
    end;
  fun specialize bridge request output=specialize_into bridge request output(Unsynchronized.ref NONE);
end;
