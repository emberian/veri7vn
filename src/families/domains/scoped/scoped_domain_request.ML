(* Fixed plain-domain ingress, retaining the actual original scope child. It
   creates no registry, ticket, permission state or publication authority. *)
signature VERI7VN_SCOPED_DOMAIN_REQUEST =
sig
  type request
  type preparation={child:Veri7vn_Native_Request_Scope.child,
    instance:Veri7vn_Domain_Execution.instance,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner,input:cterm,
    conditions:Veri7vn_Domain_Conditions.condition list}
  type saved={domain:Veri7vn_Domain_Request.saved,
    identity:Veri7vn_Native_Request_Scope.identity,
    predecessors:Veri7vn_Native_Request_Scope.identity list,dependencies:IntInf.int list}
  val prepare_child_into:preparation->request option Unsynchronized.ref->request
  val prepare_child:preparation->request
  val child:request->Veri7vn_Native_Request_Scope.child
  val identity:request->Veri7vn_Native_Request_Scope.identity
  val source:request->Veri7vn_Native_Literals.slice
  val live:request->bool
  val managed_dependencies:request->IntInf.int list
  (* Internal fixed worker/gate access. Publication must retain this wrapper. *)
  val native_domain_request:request->Veri7vn_Domain_Request.request
  val instance:request->Veri7vn_Domain_Execution.instance
  val family_request:request->Veri7vn_Domain_Execution.request
  val specialize:request->Veri7vn_Domain_Execution.output->cterm
  val result_view:request->Veri7vn_Domain_Execution.output->Veri7vn_Domain_Request.result_view
  val snapshot:request->saved
  val matches_snapshot:request->saved->bool
  val release:request->unit
end;
structure Veri7vn_Scoped_Domain_Request :> VERI7VN_SCOPED_DOMAIN_REQUEST =
struct
  structure D=Veri7vn_Domain_Request;
  structure M=Veri7vn_Domain_Execution;
  structure P=Veri7vn_Managed_Provenance;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure L=Veri7vn_Native_Literals;
  type preparation={child:Scope.child,instance:M.instance,development:P.development,
    source:P.source_owner,input:cterm,conditions:Veri7vn_Domain_Conditions.condition list};
  type saved={domain:D.saved,identity:Scope.identity,predecessors:Scope.identity list,
    dependencies:IntInf.int list};
  type payload={domain:D.request,child:Scope.child,dependencies:IntInf.int list};
  datatype request=Request of payload option Synchronized.var;
  fun require true _=() | require false message=error message;
  fun get(Request root)=(case Synchronized.value root of SOME p=>p
    | NONE=>error "Scoped domain request released");
  fun live r=(let val{domain,child,...}=get r
    in Scope.child_live child andalso D.live domain andalso
      L.same_input(L.owner(Scope.source child),D.owner domain)end)handle ERROR _=>false;
  fun checked r=(require(live r)"Scoped domain original/source unavailable";get r);
  fun child r= #child(checked r);
  fun identity r=Scope.identity(child r);
  fun source r=Scope.source(child r);
  fun managed_dependencies r= #dependencies(checked r);
  fun native_domain_request r= #domain(checked r);
  fun instance r=D.instance(native_domain_request r);
  fun family_request r=D.family_request(native_domain_request r);
  fun control_ids({request,goal,slot,interpretation,decision}:Scope.identity)=
    [request,goal,slot,interpretation,decision];
  fun prepare_child_into {child,instance,development,source,input,conditions} owned=
    let val _=require(is_none(!owned))"Scoped domain ownership root occupied";
      val _=require(Scope.child_live child andalso Scope.unclaimed child)
        "Scoped domain child denied/already claimed";
      val parent=Scope.parent child;
      val allocator=Scope.allocator parent;
      val slice=Scope.source child;
      val _=require(P.owns_input source(L.owner slice))
        "Scoped domain source belongs to another original physical owner";
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val retained=Scope.retain_child child;
        val domain_root=Unsynchronized.ref(NONE:D.request option);
        val built=Exn.capture(fn()=>
          let val _=restore(fn()=>ignore(D.prepare_into{allocator=allocator,instance=instance,
              development=development,source=source,slice=slice,input=input,conditions=conditions}domain_root))();
            val domain=the(!domain_root);
            val _=Scope.claim retained;
            val dependencies=distinct(op =)(control_ids(Scope.identity retained) @
              maps(control_ids o Scope.identity)(Scope.predecessors retained) @ D.managed_dependencies domain);
            val request=Request(Synchronized.var "veri7vn_scoped_domain"
              (SOME{domain=domain,child=retained,dependencies=dependencies}));
            val _=require(live request)"Scoped domain revoked during publication";
            val _=owned:=SOME request;
          in request end)();
      in case built of Exn.Res request=>request
        | Exn.Exn failure=>(Option.app D.release(!domain_root);Scope.release_child retained;Exn.reraise failure)end)()
    end;
  fun prepare_child arguments=prepare_child_into arguments(Unsynchronized.ref NONE);
  fun specialize r output=let val target=D.specialize(native_domain_request r)output
    in require(live r)"Scoped domain revoked during specialization";target end;
  fun result_view r output=let val result=D.result_view(native_domain_request r)output
    in require(live r)"Scoped domain revoked during result inspection";result end;
  fun snapshot r=let val{domain,child,dependencies}=checked r
    in {domain=D.snapshot domain,identity=Scope.identity child,
      predecessors=map Scope.identity(Scope.predecessors child),dependencies=dependencies}:saved end;
  fun matches_snapshot r(saved:saved)=let val actual=snapshot r
    in D.matches_snapshot(native_domain_request r)(#domain saved) andalso
      #identity actual= #identity saved andalso #predecessors actual= #predecessors saved andalso
      #dependencies actual= #dependencies saved end;
  fun release(Request root)=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result root(fn old=>(old,NONE))of NONE=>()
    | SOME{domain,child,...}=>(D.release domain;Scope.release_child child));
end;
