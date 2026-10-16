(* One explicit restore transaction's native construction graph. Its objects are
   staging material, never admission/ID authority. Logical aliases preserve saved
   ancestry; canonical nodes only own shared native contexts and source payloads. *)
signature VERI7VN_NATIVE_RECOVERY_GRAPH =
sig
  type step={context_id:IntInf.int,source_id:IntInf.int,start:int,stop:int,name:string,embedded:bool}
  type description={base_id:IntInf.int,steps:step list}
  datatype construction=Public | Installed_Public of string | Definition of {source_id:IntInf.int,start:int,stop:int,name:string,embedded:bool}
    | Replay of {source_id:IntInf.int,start:int,stop:int,imports:string list}
    | Proof of {source_id:IntInf.int,start:int,stop:int,wire:string,sequent:string}
  type construction_node={context_id:IntInf.int,parents:IntInf.int list,construction:construction}
  type graph_description={head:IntInf.int,nodes:construction_node list}
  type batch
  type lease
  type verified_batch
  val uses_roots:batch->Veri7vn_Native_Installed_Roots.registry->bool
  val is_open:batch->bool
  val active_replays:batch->int
  val create:unit->batch
  val create_roots:Veri7vn_Native_Installed_Roots.registry->batch
  val create_with:Veri7vn_Native_Recovery_Inputs.pool->batch
  val create_with_roots:Veri7vn_Native_Recovery_Inputs.pool->Veri7vn_Native_Installed_Roots.registry->batch
  val input_fragment:verified_batch->Veri7vn_Native_Identity_Allocator.fragment
  val acquire:batch->Veri7vn_Native_Identity_Allocator.allocator->
    Veri7vn_Native_Admission.policy->string->Veri7vn_Committed_Native_Recovery.committed->description->lease
  val acquire_graph:batch->Veri7vn_Native_Identity_Allocator.allocator->
    Veri7vn_Native_Admission.policy->string->Veri7vn_Committed_Native_Recovery.committed->graph_description->lease
  val development:lease->Veri7vn_Managed_Provenance.development
  val canonical_development:lease->Veri7vn_Managed_Provenance.development
  val definition:lease->Veri7vn_Managed_Provenance.consequence option
  val retain:lease->lease
  val retain_for:lease->IntInf.int->lease option
  val checked:lease->unit
  val release:lease->unit
  val seal:batch->verified_batch
  val bindings:verified_batch->{workspace:string,generation:Veri7vn_Native_Registry.generation,
    semantic_generation:IntInf.int} list
  val abort:batch->unit
end;
structure Veri7vn_Native_Recovery_Graph :> VERI7VN_NATIVE_RECOVERY_GRAPH =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  type step={context_id:IntInf.int,source_id:IntInf.int,start:int,stop:int,name:string,embedded:bool};
  type description={base_id:IntInf.int,steps:step list};
  datatype construction=Public | Installed_Public of string | Definition of {source_id:IntInf.int,start:int,stop:int,name:string,embedded:bool}
    | Replay of {source_id:IntInf.int,start:int,stop:int,imports:string list}
    | Proof of {source_id:IntInf.int,start:int,stop:int,wire:string,sequent:string}
  type construction_node={context_id:IntInf.int,parents:IntInf.int list,construction:construction}
  type graph_description={head:IntInf.int,nodes:construction_node list}
  type node={id:int,parents:int list,key:string,development:P.development,
    definition:P.consequence option,internal_id:IntInf.int,source_id:IntInf.int option};
  type logical={id:IntInf.int,node:int,parents:IntInf.int list,development:P.development,refs:int};
  type state={stamp:int,workspace:string option,image:string option,theory:theory option,
    nodes:node list,logical:logical list,pending:int,open_batch:bool};
  datatype batch=Batch of {state:state option Synchronized.var,sources:Q.batch,replays:int Synchronized.var,
    roots:Veri7vn_Native_Installed_Roots.registry option};
  datatype lease=Lease of {batch:batch,id:IntInf.int,status:int Synchronized.var};
  datatype verified_batch=Verified_Batch of batch;
  fun make roots sources=Batch{sources=sources,roots=roots,replays=Synchronized.var "veri7vn_active_restore_replays" 0,state=Synchronized.var "veri7vn_recovery_graph"
    (SOME{stamp=serial(),workspace=NONE,image=NONE,theory=NONE,nodes=[],logical=[],pending=0,open_batch=true})};
  fun active_replays(Batch{replays,...})=Synchronized.value replays;
  fun create()=make NONE(Q.batch());
  fun create_roots roots=make(SOME roots)(Q.batch());
  fun create_with pool=make NONE(Q.batch_with pool);
  fun create_with_roots pool roots=make(SOME roots)(Q.batch_with pool);
  fun uses_roots(Batch{roots,...}) expected=case roots of SOME actual=>
    Veri7vn_Native_Installed_Roots.same(actual,expected)|NONE=>false;
  fun is_open(Batch{state,...})=(case Synchronized.value state of
    SOME{open_batch=true,...}=>true|_=>false);
  fun node nodes id=the(find_first(fn(n:node)=> #id n=id)nodes);
  fun logical entries id=the(find_first(fn(n:logical)=> #id n=id)entries);
  fun set_logical entry entries=entry::filter(fn(n:logical)=> #id n<> #id entry)entries;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun inspect (Lease{batch=Batch{state,...},id,status}) =
    if Synchronized.value status=2 then error "Recovery context lease released"
    else case Synchronized.value state of NONE=>error "Recovery graph aborted"
    | SOME{nodes,logical=entries,...}=>let val g=logical entries id in (g,node nodes(#node g))end;
  fun development lease= #development(#1(inspect lease));
  fun canonical_development lease= #development(#2(inspect lease));
  fun definition lease= #definition(#2(inspect lease));
  fun retain_for (Lease{batch=(batch as Batch{state,...}),id,status}) requested=
    Synchronized.change_result status(fn current=>
      if current<>1 then error "Recovery context can only retain a checked live lease"
      else let val held=Synchronized.change_result state(fn NONE=>error "Recovery graph aborted"
        | SOME(current_state as {stamp=_,workspace,image,theory,nodes,logical=entries,pending,open_batch})=>
          let fun ancestors context seen=if member(op =)seen context then seen
                else fold ancestors (#parents(logical entries context))(context::seen)
          in if not(member(op =)(ancestors id [])requested)then(NONE,SOME current_state)
            else let val g=logical entries requested
              val g'={id= #id g,node= #node g,parents= #parents g,
                development= #development g,refs= #refs g+1}:logical
              val lease=Lease{batch=batch,id=requested,
                status=Synchronized.var "veri7vn_retained_recovery_context" 1}
            in(SOME lease,SOME{stamp=serial(),workspace=workspace,image=image,theory=theory,nodes=nodes,
              logical=set_logical g' entries,pending=pending,open_batch=open_batch})end end)
      in(held,current)end);
  fun retain(lease as Lease{id,...})=the(retain_for lease id);
  fun checked (Lease{batch=Batch{state,...},status,...})=
    Synchronized.change status(fn 0=>(Synchronized.change state(fn NONE=>error "Recovery graph aborted"
      | SOME{stamp=_,workspace,image,theory,nodes,logical,pending,open_batch}=>
          SOME{stamp=serial(),workspace=workspace,image=image,theory=theory,nodes=nodes,logical=logical,
            pending=pending-1,open_batch=open_batch});1)
    | _=>error "Recovery context lease was already checked/released");
  fun prune_many (Batch{state,sources,...}) ids pending_removed =
    let val dropped=Synchronized.change_result state(fn NONE=>(([],[],[]),NONE)
      | SOME{stamp=_,workspace,image,theory,nodes,logical=entries,pending,open_batch}=>
        let val entries0=map(fn(g:logical)=>if member(op =)ids(#id g) then
            {id= #id g,node= #node g,parents= #parents g,development= #development g,refs= #refs g-1}:logical
            else g)entries
          fun keep_alias id seen=if member(op =)seen id then seen else
            fold keep_alias (#parents(logical entries0 id)) (id::seen)
          val kept_alias=fold(fn(g:logical)=>if #refs g>0 then keep_alias(#id g) else I)entries0 []
          val (keep,remove)=List.partition(fn(g:logical)=>member(op =)kept_alias(#id g))entries0
          fun keep_node id seen=if member(op =)seen id then seen else
            fold keep_node (#parents(node nodes id))(id::seen)
          val kept_nodes=fold(fn(g:logical)=>keep_node(#node g))keep []
          val (nodes_keep,nodes_remove)=List.partition(fn(n:node)=>member(op =)kept_nodes(#id n))nodes
          val remove_roots=filter(fn(n:node)=>not(exists(fn p=>exists(fn(m:node)=> #id m=p)nodes_remove)(#parents n)))nodes_remove
          val needed=map(fn n=>(the workspace,the(#source_id n)))
            (filter(fn(n:node)=>is_some(#source_id n))nodes_keep)
        in ((map #development remove,map #development remove_roots,needed),
          SOME{stamp=serial(),workspace=workspace,image=image,theory=theory,nodes=nodes_keep,logical=keep,
            pending=pending-pending_removed,open_batch=open_batch})end)
      val (aliases,roots,needed)=dropped
      val _=List.app P.release aliases
      val _=List.app P.release roots
    in Q.forget_unused sources needed end;
  fun release_many batch leases=Thread_Attributes.uninterruptible_body(fn _=>
    let val selected=map_filter(fn Lease{id,status,...}=>
        let val old=Synchronized.change_result status(fn n=>(n,2))
        in if old=2 then NONE else SOME(id,old=0)end)leases
    in if null selected then()else prune_many batch(map #1 selected)
      (length(filter #2 selected))end);
  fun release(lease as Lease{batch,...})=release_many batch[lease];
  fun construction_key parent_ids construction=
    let fun source_key tag source_id start stop extra=space_implode ":"
          ([tag,IntInf.toString source_id,Int.toString start,Int.toString stop]@extra)
      val suffix=case construction of Public=>"public"
        | Installed_Public locator=>"installed-public:"^Int.toString(size locator)^":"^locator
        | Definition{source_id,start,stop,name,embedded}=>source_key "definition" source_id start stop[name,Bool.toString embedded]
        | Proof{source_id,start,stop,wire,sequent}=>source_key "proof" source_id start stop[
            Int.toString(size wire)^":"^wire,Int.toString(size sequent)^":"^sequent]
        | Replay{source_id,start,stop,imports}=>source_key "replay" source_id start stop(map(fn n=>Int.toString(size n)^":"^n)imports)
    in space_implode ":"(map Int.toString parent_ids)^"/"^suffix end;
  fun acquire_graph (batch as Batch{state,sources,replays,roots}) allocator policy image committed (desc:graph_description)=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
    let val scope=P.construction_scope()
      val workspace=I.workspace allocator
      val _=if #workspace(C.materials committed)=workspace then()else error "Recovery graph workspace mismatch"
      val _=if positive(#head desc) andalso not(null(#nodes desc)) andalso length(#nodes desc)<=128
        then()else error "Recovery construction graph bounds"
      val restored=if forall(fn(n:construction_node)=>case #construction n of Public=>true|Installed_Public _=>true|_=>false)(#nodes desc)
        then[]else Thread_Attributes.with_attributes original(fn _=>Q.recover_all allocator sources committed)
      val input_holds=Unsynchronized.ref([]:L.lease list)
      val graph_holds=Unsynchronized.ref([]:lease list)
      val owners=Unsynchronized.ref([]:(IntInf.int*P.source_owner)list)
      fun owner id=the(AList.lookup(op =)(!owners)id)
      fun source_slice source_id start stop=
        let val source=owner source_id val input=P.source_input source val bytes=L.bytes input
          val _=if start>=0 andalso stop>=start andalso stop<=size bytes then()else error "Recovery source slice bound"
        in(source,L.slice input{start=start,stop=stop,expected=String.substring(bytes,start,stop-start)})end
      fun build(snapshot:state)=let val{stamp=_,workspace=old_workspace,image=old_image,theory=old_theory,nodes,logical=entries,pending,open_batch}=snapshot
        in
        let val _=if open_batch andalso (case old_workspace of NONE=>true|SOME w=>w=workspace) andalso
            (case old_image of NONE=>true|SOME value=>value=image) andalso
            (case old_theory of NONE=>true|SOME thy=>Context.eq_thy(thy,A.policy_theory policy))
            then()else error "Recovery graph installed image/workspace changed or sealed"
          val _=if length entries+length(#nodes desc)<=8192 andalso length nodes+length(#nodes desc)<=65536
            then()else error "Recovery graph object bound"
          fun extend({context_id,parents,construction}:construction_node)(nodes,entries,seen)=
            let val _=if positive context_id andalso not(member(op =)seen context_id) andalso
                forall(fn id=>member(op =)seen id)parents then()else error "Recovery graph is not canonical topological order"
              val logical_parents=map(logical entries)parents
              val parent_nodes=map(fn g=>node nodes(#node g))logical_parents
              val parent_devs=map #development parent_nodes
              val key=construction_key(map #id parent_nodes)construction
              val (actual,nodes')=case find_first(fn(n:node)=> #key n=key)nodes of SOME n=>(n,nodes)
                | NONE=>let val(dev,fact,source)=Thread_Attributes.with_attributes original(fn _=>case construction of
                    Public=>if null parents then(P.staged_public_image_owned scope allocator policy committed,NONE,NONE)
                      else error "Public native construction has private parents"
                  | Installed_Public locator=>if null parents then
                      let val registry=case roots of SOME registry=>registry
                            | NONE=>error "Recovery batch has no fixed installed-root registry"
                        val installed=Veri7vn_Native_Installed_Roots.policy registry locator
                      in(P.staged_public_image_owned scope allocator installed committed,NONE,NONE)end
                    else error "Installed public native construction has private parents"
                  | Definition{source_id,start,stop,name,embedded}=>
                    let val parent=case parent_devs of [d]=>d|_=>error "Definition parent arity"
                      val(source,slice)=source_slice source_id start stop
                      val(d,_,c)=(if embedded then P.define_from_embedded_slice_owned scope else P.define_from_slice_owned scope)
                        parent source(Binding.name name)slice
                    in(d,SOME c,SOME source_id)end
                  | Proof{source_id,start,stop,wire,sequent}=>
                    let val parent=case parent_devs of[d]=>d|_=>error "Proof parent arity"
                      val(source,slice)=source_slice source_id start stop
                      val snapshot=Veri7vn_Native_Sequent.decode{max_bytes=100000,max_depth=256,max_nodes=100000}sequent
                      val(d,c)=P.prove_from_slice_sequent_owned scope parent source slice snapshot wire
                    in(d,SOME c,SOME source_id)end
                  | Replay{source_id,start,stop,imports}=>
                    let val _=if not(null imports) andalso length imports=length parent_devs then()else error "Replay parent arity"
                      val _=List.app(fn(import,parent_id)=>
                        case #construction(the(find_first(fn(n:construction_node)=> #context_id n=parent_id)(#nodes desc)))of
                          Installed_Public locator=>
                            (case roots of SOME registry=>if
                              Veri7vn_Native_Installed_Roots.resolve_import registry import=locator then()
                              else error "Restored source import selects a different installed root"
                            |NONE=>error "Restored import has no installed-root registry")
                        |_=>())(imports~~parents)
                      val(source,slice)=source_slice source_id start stop
                    in Thread_Attributes.uninterruptible(fn restore_replay=>fn()=>
                      let val _=Synchronized.change replays(fn n=>n+1)
                        val result=Exn.capture(restore_replay(fn()=>P.replay_source_owned scope(imports~~parent_devs)source slice))()
                        val _=Synchronized.change replays(fn n=>n-1)
                      in(Exn.release result,NONE,SOME source_id)end)()end)
                  val n={id=serial(),parents=map #id parent_nodes,key=key,development=dev,
                    definition=fact,internal_id=I.allocate allocator,source_id=source}:node
                in(n,n::nodes)end
              val entries'=case find_first(fn(g:logical)=> #id g=context_id)entries of
                SOME g=>if #node g= #id actual andalso #parents g=parents then entries
                  else error "Saved native context ID has inconsistent construction/parents"
              | NONE=>let val dev=P.context_alias_with_parents_owned scope(#development actual)(map #development logical_parents)
                in {id=context_id,node= #id actual,parents=parents,development=dev,refs=0}::entries end
            in(nodes',entries',context_id::seen)end
          val(nodes',entries',_)=fold extend(#nodes desc)(nodes,entries,[])
          val g=logical entries'(#head desc)
          val g'={id= #id g,node= #node g,parents= #parents g,development= #development g,refs= #refs g+1}:logical
        in {stamp=serial(),workspace=SOME workspace,image=SOME image,theory=SOME(A.policy_theory policy),
          nodes=nodes',logical=set_logical g' entries',pending=pending+1,open_batch=true}end end
      fun run()=
        let val _=List.app(fn checked=>
            let val source=P.restore_source checked val input=P.source_input source
              val hold=L.retain input
              val _=input_holds:=hold::(!input_holds)
            in owners:=(P.source_identity source,source)::(!owners)end)restored
          val snapshot=Synchronized.change_result state(fn NONE=>error "Recovery graph aborted"
            | SOME{stamp=_,workspace,image,theory,nodes,logical=entries,pending,open_batch}=>
              let val _=if open_batch then()else error "Recovery graph sealed"
                val indexed_nodes=fold(fn(n:node)=>Symtab.update(#key n,n))nodes Symtab.empty
                val indexed_aliases=fold(fn(g:logical)=>Inttab.update(#node g,#id g))entries Inttab.empty
                val existing_ids=fold(fn(g:logical)=>Symtab.update(IntInf.toString(#id g),()))entries Symtab.empty
                fun needed(n:construction_node)(known,holds)=
                  let val parent_nodes=map(fn id=>AList.lookup(op =)known id)(#parents n)
                    val candidate=if forall is_some parent_nodes then
                      Symtab.lookup indexed_nodes(construction_key(map the parent_nodes)(#construction n))else NONE
                    val holds'=if Symtab.defined existing_ids(IntInf.toString(#context_id n))
                      then insert(op =)(#context_id n)holds else holds
                    val holds''=case candidate of NONE=>holds'|SOME node=>
                      (case Inttab.lookup indexed_aliases(#id node)of NONE=>error "Canonical native node lacks logical owner"
                       | SOME id=>insert(op =)id holds')
                    val known'=case candidate of NONE=>known|SOME node=>(#context_id n,#id node)::known
                  in(known',holds'')end
                val(_,needed_ids)=fold needed(#nodes desc)([],[])
                val holds=map(fn id=>Lease{batch=batch,id=id,
                  status=Synchronized.var "veri7vn_recovery_build_parent" 1})needed_ids
                val entries'=map(fn(g:logical)=>if member(op =)needed_ids(#id g)then
                  {id= #id g,node= #node g,parents= #parents g,
                    development= #development g,refs= #refs g+1}:logical else g)entries
                val snapshot={stamp=serial(),workspace=workspace,image=image,theory=theory,
                  nodes=nodes,logical=entries',pending=pending,open_batch=open_batch}:state
                val _=graph_holds:=holds
              in(snapshot,SOME snapshot)end)
          val next=build snapshot
          val lease=Lease{batch=batch,id= #head desc,status=Synchronized.var "veri7vn_recovery_lease" 0}
          val _=Synchronized.change state(fn SOME current=>if #stamp current= #stamp snapshot
            then (List.app(fn(n:node)=>ignore(P.generation(#development n)))(#nodes next);
              List.app(fn(_,source)=>ignore(L.bytes(P.source_input source)))(!owners);SOME next)
            else error "Recovery construction graph changed during replay"
            | NONE=>error "Recovery graph aborted during replay")
          val _=P.commit_scope scope
        in lease end
      val result=Exn.capture run()
      val _=case result of Exn.Res _=>()|Exn.Exn _=>P.abort_scope scope
      val _=release_many batch(!graph_holds)
      val _=List.app(fn hold=>Option.app I.release_disposed_input(L.release hold))(!input_holds)
    in Exn.release result end);
  fun acquire batch allocator policy image committed({base_id,steps}:description)=
    let fun next(s:step)(parent,nodes)=
        (#context_id s,nodes@[{context_id= #context_id s,parents=[parent],construction=Definition
          {source_id= #source_id s,start= #start s,stop= #stop s,name= #name s,embedded= #embedded s}}])
      val(head,nodes)=fold next steps(base_id,[{context_id=base_id,parents=[],construction=Public}])
    in acquire_graph batch allocator policy image committed{head=head,nodes=nodes}end;
  fun seal (batch as Batch{state,sources,...})=
    (Synchronized.change state(fn NONE=>error "Recovery graph aborted"
    | SOME{stamp=_,workspace,image,theory,nodes,logical,pending,open_batch}=>
      if open_batch andalso pending=0 then SOME{stamp=serial(),workspace=workspace,image=image,theory=theory,
        nodes=nodes,logical=logical,pending=0,open_batch=false}
      else error "Recovery graph has unchecked context leases/already sealed");Q.close sources;Verified_Batch batch);
  fun bindings (Verified_Batch(Batch{state,...}))=
    (case Synchronized.value state of SOME{workspace=SOME workspace,nodes,logical,open_batch=false,pending=0,...}=>
      let val result=map(fn(n:node)=>{workspace=workspace,generation=P.generation(#development n),
          semantic_generation= #internal_id n})nodes @
        map(fn(g:logical)=>{workspace=workspace,generation=P.generation(#development g),semantic_generation= #id g})logical
        val ids=map #semantic_generation result
        val _=if length(distinct(op =)ids)=length ids then () else error "Recovery context identity collision"
      in result end
    | SOME{workspace=NONE,nodes=[],logical=[],open_batch=false,pending=0,...}=>[]
    | _=>error "Recovery graph does not hold a sealed native context correspondence");
  fun input_fragment(Verified_Batch(Batch{sources,...}))=Q.fragment sources;
  fun abort(Batch{state,sources,...})=Thread_Attributes.uninterruptible_body(fn _=>
    (case Synchronized.change_result state(fn old=>(old,NONE))of NONE=>()
    | SOME{nodes,...}=>(List.app(fn(n:node)=>if null(#parents n)then P.release(#development n)else())nodes;
      Q.release sources)));
end;
