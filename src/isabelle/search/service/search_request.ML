(* Fixed literal-Isabelle proof requests. Source spans and managed facts are
   actual native owners; numeric projections never reconstruct this object. *)
functor Veri7vn_Search_Request_Fn (Search: VERI7VN_NATIVE_SEARCH) :>
sig
  type request
  type construction_scope
  val construction_scope: unit -> construction_scope
  val abort_scope: construction_scope -> unit
  val commit_scope: construction_scope -> unit
  type saved = {encoding:string,bytes:string,start:int,stop:int,target:term,
    catalogue:Thm_Name.T list,limits:Search.limits,actions:Search.action list,
    scope_identity:Veri7vn_Native_Request_Scope.identity option}
  val prepare_owned: construction_scope -> Search.instance ->
    {receiver:Veri7vn_Managed_Provenance.development,worker:Veri7vn_Managed_Provenance.development,
     source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,
     facts:Veri7vn_Managed_Provenance.consequence list,actions:Search.action list} -> request
  val prepare_child_owned: construction_scope -> Search.instance -> Veri7vn_Native_Request_Scope.child ->
    {receiver:Veri7vn_Managed_Provenance.development,worker:Veri7vn_Managed_Provenance.development,
     source:Veri7vn_Managed_Provenance.source_owner,
     facts:Veri7vn_Managed_Provenance.consequence list,actions:Search.action list} -> request
  val native_scope: request -> Veri7vn_Native_Request_Scope.child option
  val project_scope: request -> Veri7vn_Native_Request_Scope.identity option
  val instance: request -> Search.instance
  val executable: request -> Veri7vn_Executable_Identity.pin
  val cost: request -> IntInf.int
  val restore_owned: construction_scope -> Search.instance -> saved ->
    {receiver:Veri7vn_Managed_Provenance.development,worker:Veri7vn_Managed_Provenance.development,
     source:Veri7vn_Managed_Provenance.source_owner,
     facts:Veri7vn_Managed_Provenance.consequence list} -> request
  val restore_child_owned: construction_scope -> Search.instance -> Veri7vn_Native_Request_Scope.child -> saved ->
    {receiver:Veri7vn_Managed_Provenance.development,worker:Veri7vn_Managed_Provenance.development,
     source:Veri7vn_Managed_Provenance.source_owner,
     facts:Veri7vn_Managed_Provenance.consequence list} -> request
  val prepared: request -> Search.prepared
  val target: request -> cterm
  val receiver: request -> Veri7vn_Managed_Provenance.development
  val worker: request -> Veri7vn_Managed_Provenance.development
  val source: request -> Veri7vn_Managed_Provenance.source_owner
  val slice: request -> Veri7vn_Native_Literals.slice
  val dependencies: request -> IntInf.int list
  val prove_owned: Veri7vn_Managed_Provenance.construction_scope -> request -> string ->
    Veri7vn_Managed_Provenance.development * Veri7vn_Managed_Provenance.consequence
  val snapshot: request -> saved
  val live: request -> bool
  val release: request -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Scope=Veri7vn_Native_Request_Scope;
  type saved={encoding:string,bytes:string,start:int,stop:int,target:term,
    catalogue:Thm_Name.T list,limits:Search.limits,actions:Search.action list,
    scope_identity:Veri7vn_Native_Request_Scope.identity option};
  type payload={receiver:P.development,worker:P.development,source:P.source_owner,
    slice:L.slice,lease:L.lease,facts:P.consequence list,target:cterm,
    prepared:Search.prepared,catalogue:Thm_Name.T list,limits:Search.limits,actions:Search.action list,
    child:Scope.child option,instance:Search.instance,cost:IntInf.int};
  datatype request=Request of payload option Synchronized.var;
  datatype construction_scope=ConstructionScope of request list option Synchronized.var;
  fun construction_scope()=ConstructionScope(Synchronized.var "search_construction_scope"(SOME []));
  fun require true _=() | require false message=error message;
  fun get (Request cell)=case Synchronized.value cell of SOME p=>p
    | NONE=>error "Search request released";
  fun live request=(let val {receiver,worker,source,slice,lease,facts,prepared,child,...}=get request
      val _=L.lease_input lease
      val _=P.generation receiver
      val _=P.generation worker
    in P.development_live receiver andalso P.development_live worker andalso
      can Search.executable (Search.request_instance prepared) andalso
      (case child of NONE=>true|SOME c=>Scope.child_live c) andalso
      P.owns_input source (L.owner slice) andalso forall P.is_live facts end)
    handle ERROR _=>false;
  fun checked request=(require(live request) "Search source or native owner unavailable";get request);
  fun prepared request=let val p= #prepared(checked request)
    in require(Search.is_live p) "Search prepared input already joined/released";p end;
  fun native_scope request= #child(checked request);
  fun project_scope request=Option.map Scope.identity(native_scope request);
  fun instance request= #instance(checked request);
  fun executable request=Search.executable(instance request);
  fun cost request= #cost(checked request);
  fun target request= #target(checked request);
  fun receiver request= #receiver(checked request);
  fun worker request= #worker(checked request);
  fun source request= #source(checked request);
  fun slice request= #slice(checked request);
  fun dependencies request=let val {source,facts,receiver,worker,...}=checked request
    in distinct(op =)(P.source_identity source :: P.development_dependencies receiver @
      P.development_dependencies worker @ maps P.dependencies facts @
      maps P.source_dependencies facts) end;
  fun prove_owned scope request wire=
    let val {receiver,source,slice,...}=checked request
        val (development,consequence)=P.prove_from_slice_owned scope receiver source slice wire
    in if live request then (development,consequence)
      else (P.release development;error "Search request revoked during proof reconstruction") end;
  fun snapshot request=let val {slice,target,catalogue,limits,actions,child,...}=checked request
      val {start,stop}=L.offsets slice
    in {encoding=L.encoding(L.owner slice),bytes=L.bytes(L.owner slice),start=start,stop=stop,
      target=Thm.term_of target,catalogue=catalogue,limits=limits,actions=actions,
      scope_identity=Option.map Scope.identity child} end;
  fun release (Request cell)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    (case Synchronized.change_result cell(fn old=>(old,NONE)) of NONE=>()
    | SOME {prepared,lease,child,...}=>(Search.release prepared;Option.app Scope.release_child child;
        Option.app I.release_disposed_input(L.release lease))))();
  fun abort_scope(ConstructionScope cell)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    List.app release(Synchronized.change_result cell(fn old=>(the_default [] old,NONE))))();
  fun commit_scope(ConstructionScope cell)=Synchronized.change cell(fn NONE=>
      error "Search construction scope closed"|SOME _=>NONE);
  fun register NONE _=()
    | register(SOME(ConstructionScope cell)) request=Synchronized.change cell(fn NONE=>
        error "Search construction scope closed during request publication"
      |SOME roots=>if length roots>=512 then error "Search construction scope bound"
        else SOME(request::roots));
  fun prepare_internal scope child instance {receiver,worker,source,slice,facts,actions} =
    let
      val input=L.owner slice;
      val _=require(P.development_live receiver andalso P.development_live worker)
        "Search receiver or worker development unavailable";
      val _=require(P.owns_input source input) "Search target source owner mismatch";
      val _=require(P.source_workspace source=P.development_workspace receiver andalso
        P.source_workspace source=P.development_workspace worker) "Search source/native workspace mismatch";
      val _=require(L.encoding input="UTF-8") "Search proposition requires UTF-8 source";
      val _=require(size(L.bytes input)<=1048576) "Search original source input byte bound";
      val _=require(Veri7vn_Search_UTF8.valid(L.bytes input) andalso
        Veri7vn_Search_UTF8.valid(L.original slice)) "Search source requires exact scalar UTF-8";
      val _=require(size(L.original slice)>0 andalso size(L.original slice)<=65536)
        "Search literal proposition byte bound";
      val receiver_gen=P.generation receiver;
      val worker_gen=P.generation worker;
      val receiver_ctxt=R.context receiver_gen;
      val worker_ctxt=R.context worker_gen;
      val _=case child of NONE=>() | SOME c=>
        let val parent=Scope.parent c
        in require(Scope.unclaimed c andalso
            I.workspace(Scope.allocator parent)=P.source_workspace source andalso
            L.same_input(L.owner(Scope.source c),input) andalso
            L.offsets(Scope.source c)=L.offsets slice andalso
            Context.eq_thy(A.policy_theory(Scope.policy parent),Proof_Context.theory_of receiver_ctxt))
          "Search native child/source/context mismatch" end;
      val _=require(length facts<=128) "Search managed catalogue bound";
      fun fact_name fact=let
          val _=require(P.is_live fact) "Search catalogue consequence unavailable";
          val _=require(P.workspace fact=P.source_workspace source)
            "Search catalogue outside source workspace";
          val name=case P.public_name fact of SOME name=>name
            | NONE=>error "Search catalogue requires a named managed consequence";
          val resolved=Proof_Context.get_thm worker_ctxt (Thm_Name.print name);
          val actual=Thm.transfer (Proof_Context.theory_of worker_ctxt)
            (A.theorem(P.accepted fact));
          val _=require(Thm.eq_thm(resolved,actual)) "Search catalogue theorem differs from managed owner";
        in name end;
      val catalogue=map fact_name facts;
      val target=Timeout.apply(Time.fromSeconds 5)(fn()=>
        Thm.cterm_of receiver_ctxt (Syntax.read_prop receiver_ctxt (L.original slice)))();
    in Thread_Attributes.uninterruptible(fn _=>fn()=>
      let val lease=L.retain input;
        val owned=Unsynchronized.ref(NONE:Search.prepared option);
        val retained_child=Unsynchronized.ref(NONE:Scope.child option);
        val attempted=Exn.capture(fn()=>
          let val owned_child=Option.map Scope.retain_child child;
            val _=retained_child:=owned_child;
            val _=Option.app Scope.claim owned_child;
            val prepared=Search.prepare instance receiver_gen worker_gen target
                (map Thm_Name.print catalogue) actions;
            val _=owned:=SOME prepared;
            val request=Request(Synchronized.var "managed_search_request"(SOME
              {receiver=receiver,worker=worker,source=source,slice=slice,lease=lease,
               facts=facts,target=target,prepared=prepared,catalogue=catalogue,
               limits=Search.limits instance,actions=actions,child=owned_child,instance=instance,
               cost=Search.cost prepared}));
            val _=register scope request;
          in request end)();
      in case attempted of Exn.Res request=>request
        | Exn.Exn exn=>(Option.app Search.release(!owned);
            Option.app Scope.release_child(!retained_child);
            Option.app I.release_disposed_input(L.release lease);Exn.reraise exn)
      end)()
    end;
  fun prepare_owned scope=prepare_internal(SOME scope) NONE;
  fun prepare_child_owned scope instance child {receiver,worker,source,facts,actions}=
    prepare_internal(SOME scope)(SOME child)instance
      {receiver=receiver,worker=worker,source=source,slice=Scope.source child,facts=facts,actions=actions};
  (* The caller supplies protected reconstructed, published P owners. The inert
     snapshot supplies no identity correspondence or staged-liveness bypass. *)
  fun restore_internal scope child instance (saved:saved) {receiver,worker,source,facts} =
    let val input=P.source_input source;
      val _=require(size(#bytes saved)<=1048576 andalso size(L.bytes input)<=1048576)
        "Restored search source input byte bound";
      val _=require(L.encoding input= #encoding saved andalso L.bytes input= #bytes saved)
        "Restored search original source differs";
      val _=require(Search.limits instance= #limits saved) "Restored search limits differ";
      val {start,stop,...}=saved;
      val _=require(start>=0 andalso stop>=start andalso stop<=size(#bytes saved))
        "Restored search source span outside input";
      val slice=L.slice input{start=start,stop=stop,
        expected=String.substring(#bytes saved,start,stop-start)};
      val _=require(Option.map Scope.identity child= #scope_identity saved)
        "Restored search differs from protected native child";
      val request=prepare_internal scope child instance{receiver=receiver,worker=worker,source=source,slice=slice,
        facts=facts,actions= #actions saved};
      val checked=Exn.capture(fn()=>
        let val actual=snapshot request;
          val _=require(#target actual aconv #target saved andalso #catalogue actual= #catalogue saved)
            "Restored search target or managed catalogue differs"
        in request end)();
    in case checked of Exn.Res request=>request
      | Exn.Exn exn=>(release request;Exn.reraise exn) end;
  fun restore_owned scope=restore_internal(SOME scope) NONE;
  fun restore_child_owned scope instance child=restore_internal(SOME scope)(SOME child)instance;

end;
