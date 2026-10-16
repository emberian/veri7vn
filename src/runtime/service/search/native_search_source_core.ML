(* Shared original-source preparation for strict public and genuinely qualified
   receiver owners. This draft is unreferenced until the coordinated consumer
   migration; legacy Source becomes a thin public-context instantiation. *)
functor Veri7vn_Search_Source_In_Context_Fn (
  structure S: VERI7VN_NATIVE_SEARCH
  structure Q:
  sig
    type request type construction_scope
    val construction_scope: unit -> construction_scope
    val abort_scope: construction_scope -> unit
    val prepare_child_owned: construction_scope -> S.instance -> Veri7vn_Native_Request_Scope.child ->
      {receiver:Veri7vn_Managed_Provenance.development,worker:Veri7vn_Managed_Provenance.development,
       source:Veri7vn_Managed_Provenance.source_owner,
       facts:Veri7vn_Managed_Provenance.consequence list,actions:S.action list} -> request
    val cost: request -> IntInf.int
    val live: request -> bool
    val release: request -> unit
  end
  structure Context:VERI7VN_SEARCH_RECEIVER_CONTEXT) :>
sig
  type owner=Context.context type entry type request=Q.request
  type names={capability:IntInf.int,operation:IntInf.int,profile:IntInf.int,step:IntInf.int,
    template:IntInf.int,claim:IntInf.int,parameter:IntInf.int,execution:IntInf.int,code:IntInf.int,
    evidence:IntInf.int,output:IntInf.int,batch:IntInf.int,exhausted:IntInf.int,budget:IntInf.int,
    deadline:IntInf.int,cancelled:IntInf.int,failed:IntInf.int}
  type projection={identity:Veri7vn_Native_Request_Scope.identity,context:IntInf.int,
    receiver:IntInf.int,worker:IntInf.int,input:IntInf.int,cost:IntInf.int}
  val context: owner -> IntInf.int
  val owner_live: owner -> bool
  val prepare_into: entry option Unsynchronized.ref -> owner -> string -> entry
  val receiver_context: entry -> Context.context
  val request: entry -> request
  val instance: entry -> S.instance
  val parent: entry -> Veri7vn_Native_Request_Scope.parent
  val child: entry -> Veri7vn_Native_Request_Scope.child
  val source: entry -> Veri7vn_Managed_Provenance.source_owner
  val project: entry -> projection
  val names: entry -> names
  val live: entry -> bool
  val deny: entry -> unit
  (* Caller first cancels and confirms termination of its actual owned job. *)
  val release: entry -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  val require=Wire.require;
  type request=Q.request;
  type names={capability:IntInf.int,operation:IntInf.int,profile:IntInf.int,step:IntInf.int,
    template:IntInf.int,claim:IntInf.int,parameter:IntInf.int,execution:IntInf.int,code:IntInf.int,
    evidence:IntInf.int,output:IntInf.int,batch:IntInf.int,exhausted:IntInf.int,budget:IntInf.int,
    deadline:IntInf.int,cancelled:IntInf.int,failed:IntInf.int};
  type owner=Context.context;
  type projection={identity:Scope.identity,context:IntInf.int,receiver:IntInf.int,worker:IntInf.int,input:IntInf.int,cost:IntInf.int};
  type payload={owner:owner,request:request,instance:S.instance,parent:Scope.parent,child:Scope.child,
    input:L.input,source:P.source_owner,facts:P.consequence list,
    pscope:P.construction_scope,qscope:Q.construction_scope,projection:projection,names:names};
  datatype entry=Entry of {root:payload option Synchronized.var,lock:unit Synchronized.var};
  val context=Context.semantic_generation;
  val owner_live=Context.is_live;
  fun get(Entry{root,...})=case Synchronized.value root of SOME p=>p | NONE=>error "Search source entry released";
  fun live entry=(let val {owner,request,parent,...}=get entry
    in owner_live owner andalso Q.live request andalso
      Scope.child_live(#child(get entry)) end)handle ERROR _=>false;
  fun checked entry=(require(live entry) "Search source entry unavailable";get entry);
  fun receiver_context entry= #owner(checked entry);
  fun request entry= #request(checked entry);
  fun instance entry= #instance(checked entry);
  fun parent entry= #parent(get entry);
  fun child entry= #child(get entry);
  fun source entry= #source(checked entry);
  fun project entry= #projection(get entry);
  fun names entry= #names(get entry);
  fun deny entry=Scope.deny(parent entry);
  fun drop_base input=Option.app I.release_disposed_input(L.drop_base input);
  fun dispose({owner,request,instance,parent,child,input,facts,pscope,qscope,...}:payload)=
    (Scope.deny parent;Q.release request;P.release_consequences facts;
     Q.abort_scope qscope;P.abort_scope pscope;
     S.release_instance instance;Scope.release_child child;Scope.release_parent parent;drop_base input;Context.release owner);
  fun release(Entry{root,lock})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change lock(fn()=>
      case Synchronized.value root of NONE=>() | SOME payload=>
        (dispose payload;Synchronized.change root(K NONE))));
  fun prepare_into target owner wire=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val ids=Context.allocator owner;val policy=Context.policy owner;
        val development=Context.development owner;val context=Context.semantic_generation owner;
        val _=require(is_none(!target)) "Search source cleanup target already occupied";
        val spec_root=Unsynchronized.ref(NONE:Wire.proposal option);
        val _=restore(fn()=>spec_root:=SOME(Wire.parse wire))();
        val spec=the(!spec_root);
        val _=require(owner_live owner andalso #context spec=context) "Search selected native context is unavailable or differs";
        val qscope=Q.construction_scope();
        val pscope=P.construction_scope();
        val context_root=Unsynchronized.ref(NONE:Context.context option);
        val input_root=Unsynchronized.ref(NONE:L.input option);
        val parent_root=Unsynchronized.ref(NONE:Scope.parent option);
        val child_root=Unsynchronized.ref(NONE:Scope.child option);
        val instance_root=Unsynchronized.ref(NONE:S.instance option);
        val entry_root=Unsynchronized.ref(NONE:entry option);
        val facts_root=Unsynchronized.ref(NONE:P.consequence list option);
        val request_root=Unsynchronized.ref(NONE:Q.request option);
        fun cleanup()=case !entry_root of SOME entry=>release entry | NONE=>
          (Q.abort_scope qscope;P.abort_scope pscope;
           Option.app S.release_instance(!instance_root);Option.app Scope.release_child(!child_root);
           Option.app Scope.release_parent(!parent_root);Option.app drop_base(!input_root);
           Option.app Context.release(!context_root));
        val result=Exn.capture(fn()=>
          let val kept=Context.retain owner;val _=context_root:=SOME kept;
            val input=L.input{bytes= #original spec,encoding="UTF-8"};
            val _=input_root:=SOME input;
            val source=P.install_host_source ids input;
            val instance=S.qualify(#limits spec);
            val _=instance_root:=SOME instance;
            val parent=Scope.new_parent{allocator=ids,policy=policy,observation=Scope.StateTimeUnused,inputs=[input]};
            val _=parent_root:=SOME parent;
            val child=Scope.new_child parent{source=L.slice input
              {start=0,stop=size(#original spec),expected= #original spec},predecessors=[]};
            val _=child_root:=SOME child;
            val selected=map(fn text=>
              let val name=Thm_Name.parse text;
                val _=require(Thm_Name.print name=text) "Search catalogue requires exact native theorem names"
              in name end)(#catalogue spec);
            val _=restore(fn()=>facts_root:=SOME(Context.catalogue_owned pscope kept selected))();
            val facts=the(!facts_root);
            val _=restore(fn()=>request_root:=SOME(Q.prepare_child_owned qscope instance child
              {receiver=development,worker=development,source=source,facts=facts,actions= #actions spec}))();
            val request=the(!request_root);
            val _=Scope.seal parent[child];
            (* These are producer-owned control associations, never caller IDs.
               The serialized owner binds code to this exact S.executable and
               charge to Q.cost before it can issue the single pure ticket. *)
            val names={capability=I.allocate ids,operation=I.allocate ids,profile=I.allocate ids,
              step=I.allocate ids,template=I.allocate ids,claim=I.allocate ids,parameter=I.allocate ids,
              execution=I.allocate ids,code=I.allocate ids,evidence=I.allocate ids,output=I.allocate ids,
              batch=I.allocate ids,exhausted=I.allocate ids,budget=I.allocate ids,deadline=I.allocate ids,
              cancelled=I.allocate ids,failed=I.allocate ids}:names;
            val entry=Entry{root=Synchronized.var "fixed_search_source_entry"(SOME
              {owner=kept,request=request,instance=instance,parent=parent,child=child,input=input,source=source,
               facts=facts,pscope=pscope,qscope=qscope,names=names,projection={identity=Scope.identity child,context=context,
                 receiver=I.generation_id ids(P.generation development),worker=I.generation_id ids(P.generation development),
                 input=P.source_identity source,cost=Q.cost request}}),lock=Synchronized.var "fixed_search_source_release"()};
            val _=entry_root:=SOME entry;
            val _=target:=SOME entry;
            (* Q and Scope already own independent leases. The producer's base
               is never left as an untracked retained original-byte copy. *)
            val _=drop_base input;
            val _=require(live entry) "Search source retired during preparation";
            val _=target:=SOME entry;
          in entry end)();
      in case result of Exn.Res entry=>entry | Exn.Exn failure=>
        (cleanup();Exn.reraise failure)end)();
end;
