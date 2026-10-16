(* Fixed first-profile receiver reconstruction. This borrows the SAME G/V batch
   and source pool used by proof certificates; it creates no second interner,
   admission table, scheduler, raw generation setter or execution ticket. *)
functor Veri7vn_Search_Request_Recovery_Fn (
  structure S:VERI7VN_NATIVE_SEARCH
  structure Q:
  sig
    type request
    type saved={encoding:string,bytes:string,start:int,stop:int,target:term,
      catalogue:Thm_Name.T list,limits:S.limits,actions:S.action list,
      scope_identity:Veri7vn_Native_Request_Scope.identity option}
    val snapshot:request->saved
    val native_scope:request->Veri7vn_Native_Request_Scope.child option
    val receiver:request->Veri7vn_Managed_Provenance.development
    val worker:request->Veri7vn_Managed_Provenance.development
    val source:request->Veri7vn_Managed_Provenance.source_owner
    val cost:request->IntInf.int
    val executable:request->Veri7vn_Executable_Identity.pin
  end) =
struct
  structure Codec=Veri7vn_Search_Request_Codec_Fn(structure S=S structure Q=Q);
  structure P=Veri7vn_Managed_Provenance;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure V=Veri7vn_Native_Recovery_Check;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  structure Roots=Veri7vn_Native_Installed_Roots;
  structure Checkpoint=Veri7vn_Search_Request_Checkpoint;
  val require=Codec.require;
  local
  datatype batch=Batch of {graph:G.batch,ids:I.allocator,image:V.image,pin:E.pin,
    roots:Roots.registry option,owned:{caps:C.committed list,receivers:receiver list} option Synchronized.var}
  and receiver=Receiver of payload option Synchronized.var
  withtype payload={batch:batch,lease:G.lease,material:Codec.material,policy:A.policy};
  in
  type batch=batch type receiver=receiver;
  fun get(Receiver cell)=case Synchronized.value cell of SOME p=>p|NONE=>error "Search restored receiver released";
  fun release(Receiver cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change cell(fn NONE=>NONE|SOME(p as {lease,...})=>(G.release lease;NONE)));
  fun begin_batch graph ids image roots pin=
    let val _=require(Context.subthy(E.code_theory pin,A.policy_theory(V.image_policy image)))
        "Search receiver producer is outside installed image";
      val _=Option.app(fn roots=>require(G.uses_roots graph roots)
        "Search receiver uses another native graph/root registry")roots
    in Batch{graph=graph,ids=ids,image=image,pin=pin,roots=roots,
      owned=Synchronized.var "search_receiver_construction_roots"(SOME{caps=[],receivers=[]})}end;
  fun inspect receiver= #material(get receiver);
  fun policy receiver= #policy(get receiver);
  fun development receiver=
    let val {lease,material,batch=Batch{ids,...},...}=get receiver;
      val dev=G.development lease;
      val expected= #receiver(#links(Codec.inspect material));
      val _=require(P.development_live dev andalso I.lookup_generation_id ids(P.generation dev)=SOME expected)
        "Search restored receiver original identity fragments are not published"
    in dev end;
  fun projection material=
    let val {links={context,receiver,worker,source,cost},saved,...}=Codec.inspect material
    in {identity=the(#scope_identity saved),context=context,receiver=receiver,worker=worker,input=source,cost=cost}:Checkpoint.projection end;
  fun phase material=
    let val {phase,...}=Codec.inspect material
    in {execution=Codec.execution phase,reason=Codec.reason phase,
      stopped=(case phase of Codec.Pending _=>NONE|Codec.Stopped{stop,...}=>SOME(Codec.stop_name stop))}:Checkpoint.phase end;
  fun construction roots image=
    let val theory=A.policy_theory(V.image_policy image)
      val matches=case roots of NONE=>[]|SOME registry=>filter(fn locator=>Roots.matches registry locator theory)(Roots.locators registry)
    in case matches of []=>G.Public |[locator]=>G.Installed_Public locator
      |_=>error "Search boot receiver has ambiguous installed native roots"end;
  fun prepare_into target (batch as Batch{graph,ids,image,pin,roots,owned}) committed=
    let val material=Codec.verify image pin committed;
      val {links,names,...}=Codec.inspect material;
      val _=require(#workspace(C.materials committed)=I.workspace ids andalso
        Checkpoint.matches committed(projection material)names(phase material))
        "Search original requirement/phase/consumed execution differs from committed checkpoint";
      val description={head= #receiver links,nodes=[{context_id= #receiver links,parents=[],
        construction=construction roots image}]}:G.graph_description;
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val _=require(is_none(!target)) "Search receiver cleanup target occupied";
        (* Copy the already checked capability so the parent can retire its own
           C view without killing a canonical staged receiver shared with proof
           graphs. The transaction owns this copy until all fragments publish. *)
        val cap=C.install_committed_host(C.materials committed);
        val installed=Exn.capture(fn()=>Synchronized.change owned(fn NONE=>error "Search receiver construction batch closed"
          |SOME{caps,receivers}=>(require(length caps<256) "Search receiver capsule bound";
             SOME{caps=cap::caps,receivers=receivers})))();
        val _=case installed of Exn.Res()=>()|Exn.Exn failure=>(C.release cap;Exn.reraise failure);
        val lease_root=Unsynchronized.ref(NONE:G.lease option);
        val result=Exn.capture(fn()=>
          let val lease=restore(fn()=>G.acquire_graph graph ids(V.image_policy image)(V.context_closure image)cap description)();
            val _=lease_root:=SOME lease;
            val _=G.checked lease;
            val receiver=Receiver(Synchronized.var "search_restored_receiver"(SOME
              {batch=batch,lease=lease,material=material,policy=V.image_policy image}));
            val _=Synchronized.change owned(fn NONE=>error "Search receiver construction batch closed during handoff"
              |SOME{caps,receivers}=>SOME{caps=caps,receivers=receiver::receivers});
            val _=target:=SOME receiver
          in receiver end)()
      in case result of Exn.Res receiver=>receiver |Exn.Exn failure=>
        (Option.app G.release(!lease_root);Exn.reraise failure)end)()end;
  fun retain_into target receiver=Thread_Attributes.uninterruptible_body(fn _=>
    let val _=require(is_none(!target)) "Search receiver retain cleanup target occupied";
      val {batch=batch as Batch{owned,...},lease,material,policy}=get receiver;
      val retained=G.retain lease;
      val copy=Receiver(Synchronized.var "search_retained_receiver"(SOME
        {batch=batch,lease=retained,material=material,policy=policy}));
      val result=Exn.capture(fn()=>
        (Synchronized.change owned(fn NONE=>NONE|SOME{caps,receivers}=>SOME{caps=caps,receivers=copy::receivers});
         target:=SOME copy;copy))()
    in case result of Exn.Res copy=>copy|Exn.Exn failure=>(release copy;Exn.reraise failure)end);
  (* One shared V seal supplies ALL actual physical/logical context and source
     bindings, including proof outputs. Reuse its exact fragment operation;
     there is no per-family competing binder. close checks that the receivers
     from this same borrowed graph actually became published. *)
  val fragment=V.fragment;
  fun close(Batch{owned,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change owned(fn NONE=>NONE|SOME{caps,receivers}=>
      (List.app(fn receiver=>case Exn.capture get receiver of Exn.Exn _=>()|Exn.Res _=>ignore(development receiver))receivers;
       List.app C.release caps;NONE)));
  fun abort(Batch{owned,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change owned(fn NONE=>NONE|SOME{caps,receivers}=>
      (List.app release receivers;List.app C.release caps;NONE)));
  (* Scope owns the original source independently. Only named public theorem
     CELLS are made here, under the caller's existing P rollback scope. The
     receiver/canonical P developments belong to the shared graph leases. *)
  fun catalogue scope receiver=
    let val {lease,material,...}=get receiver;
      val logical=development receiver;
      val canonical=G.canonical_development lease;
      val _=case P.alias_parent logical of SOME actual=>require(R.same_generation(P.generation actual,P.generation canonical))
        "Search catalogue receiver is not the actual canonical public alias"
        |NONE=>error "Search restored public catalogue lacks native alias association";
      val saved= #saved(Codec.inspect material)
    in map(fn name=>P.restate_owned scope logical(P.public_theorem_owned scope canonical name)) (#catalogue saved)end;
  end;
end;
