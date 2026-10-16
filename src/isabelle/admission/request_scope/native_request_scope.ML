(* Construction/lifetime bookkeeping only. Permission, resource charge and result
   licensing remain in the generated Owner. No raw request/goal identity setter. *)
signature VERI7VN_NATIVE_REQUEST_SCOPE =
sig
  type parent
  type child
  type sealed
  type restore_batch
  val restore_batch: Veri7vn_Native_Identity_Allocator.allocator -> restore_batch
  (* The caller's checked factory batch remains rooted through this call. *)
  val restore: restore_batch -> Veri7vn_Native_Scope_Recovery.View.checked -> parent * child list
  val close_restore_batch: restore_batch -> unit
  val abort_restore_batch: restore_batch -> unit
  datatype observation = StateTimeUnused
  type identity = {request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    interpretation:IntInf.int,decision:IntInf.int}
  val new_parent: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    policy:Veri7vn_Native_Admission.policy,observation:observation,
    inputs:Veri7vn_Native_Literals.input list} -> parent
  val new_child: parent -> {source:Veri7vn_Native_Literals.slice,
    predecessors:child list} -> child
  val unclaimed: child -> bool
  val claim: child -> unit
  val seal: parent -> child list -> sealed
  val parent: child -> parent
  val identity: child -> identity
  val snapshot: parent -> (IntInf.int * IntInf.int) list -> Veri7vn_Native_Scope_Saved.parent
  val observation: parent -> observation
  val request_id: parent -> IntInf.int
  val allocator: parent -> Veri7vn_Native_Identity_Allocator.allocator
  val policy: parent -> Veri7vn_Native_Admission.policy
  val source: child -> Veri7vn_Native_Literals.slice
  val same_parent: parent * parent -> bool
  val same_child: child * child -> bool
  val predecessors: child -> child list
  (* Borrowed construction views. A sealed receipt owns no source lease; a
     consumer retains each live child before the producer releases its view. *)
  val sealed_children: sealed -> child list
  val child_live: child -> bool
  val deny: parent -> unit
  (* Retention preserves an existing physical view, including denied historical
     data; it never changes child_live and cannot retain an erased placeholder. *)
  val retain_child: child -> child
  val release_child: child -> unit
  val release_parent: parent -> unit
end;
structure Veri7vn_Native_Request_Scope :> VERI7VN_NATIVE_REQUEST_SCOPE =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure Recovery=Veri7vn_Native_Scope_Recovery.View;
  structure Saved=Veri7vn_Native_Scope_Saved;
  datatype observation=StateTimeUnused;
  type identity={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    interpretation:IntInf.int,decision:IntInf.int};
  datatype parent=Parent of {key:serial,id:IntInf.int,allocator:I.allocator,
    policy:Veri7vn_Native_Admission.policy,observation:observation,
    active:bool Synchronized.var,inputs:L.lease list option Synchronized.var,
    views:int Synchronized.var,
    plan:Saved.child list option Synchronized.var,
    construction:{sealed:bool,children:child list} Synchronized.var}
  and child=Child of {key:serial,parent:parent,identity:identity,source:L.slice option,
    predecessors:child list,lease:L.lease option Synchronized.var,claimed:bool Synchronized.var};
  datatype sealed=Sealed of parent * child list;
  fun require true _=() | require false text=error text;
  fun same_parent(Parent{key=a,...},Parent{key=b,...})=a=b;
  fun same_child(Child{key=a,...},Child{key=b,...})=a=b;
  fun observation(Parent{observation,...})=observation;
  fun request_id(Parent{id,...})=id;
  fun allocator(Parent{allocator,...})=allocator;
  fun policy(Parent{policy,...})=policy;
  fun parent(Child{parent,...})=parent;
  fun identity(Child{identity,...})=identity;
  fun source(Child{source=SOME source,...})=source
    | source _=error "Inactive restored child has no retained original source";
  fun predecessors(Child{predecessors,...})=predecessors;
  fun release_lease lease=Option.app I.release_disposed_input(L.release lease);
  fun new_parent {allocator,policy,observation,inputs}=Thread_Attributes.uninterruptible_body(fn _=>
    let val _=require(not(null inputs) andalso length inputs<=64 andalso
          length(distinct(op =)(map L.input_locator inputs))=length inputs andalso
          fold(fn input=>fn total=>total+size(L.bytes input))inputs 0<=2000000)
          "Native parent original input bound/uniqueness";
      val leases=Unsynchronized.ref([]:L.lease list);
      val result=Exn.capture(fn()=>
        (List.app(fn input=>leases:=L.retain input :: !leases)inputs;
         Parent{key=serial(),id=I.allocate allocator,allocator=allocator,policy=policy,
           observation=observation,active=Synchronized.var "request_scope_active" true,
           inputs=Synchronized.var "request_scope_inputs" (SOME(rev(!leases))),
           views=Synchronized.var "request_scope_views" 1,
           plan=Synchronized.var "request_scope_original_plan" NONE,
           construction=Synchronized.var "request_scope_construction" {sealed=false,children=[]}}))()
    in case result of Exn.Res p=>p | Exn.Exn failure=>
      (List.app release_lease(!leases);Exn.reraise failure)end);
  fun child_live(Child{parent=Parent{active,...},lease,source,...})=
    Synchronized.value active andalso is_some(Synchronized.value lease) andalso
    (case source of SOME slice=>L.retained(L.owner slice)|NONE=>false);
  fun retain_parent_view(Parent{views,...})=Synchronized.change views(fn count=>
    (require(count>0) "Native parent owner drained";count+1));
  fun release_parent_view(Parent{views,...})=Synchronized.change views(fn count=>
    (require(count>0) "Native parent owner underflow";count-1));
  fun new_child (p as Parent{id,allocator,active,inputs,construction,...}) {source,predecessors}=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result construction(fn {sealed,children}=>
      let val _=require(not sealed andalso Synchronized.value active andalso length children<256) "Native parent sealed/denied or child bound";
        val originals=(case Synchronized.value inputs of SOME leases=>map L.lease_input leases
          | NONE=>error "Native parent producer released");
        val _=require(exists(fn input=>L.same_input(input,L.owner source))originals)
          "Child original span belongs to another parent";
        val _=require(forall(fn child=>same_parent(p,parent child) andalso child_live child andalso
          exists(fn previous=>same_child(child,previous))children)predecessors andalso
          length(distinct(op =)(map(fn Child{key,...}=>key)predecessors))=length predecessors)
          "Native child predecessor association/order";
        val lease=L.retain(L.owner source);
        val result=Exn.capture(fn()=>Child{key=serial(),parent=p,source=SOME source,
          predecessors=predecessors,lease=Synchronized.var "request_child_source" (SOME lease),
          claimed=Synchronized.var "request_child_claimed" false,
          identity={request=id,goal=I.allocate allocator,slot=I.allocate allocator,
            interpretation=I.allocate allocator,decision=I.allocate allocator}})()
      in case result of Exn.Res child=>
          (case Exn.capture(fn()=>
              (retain_parent_view p;(child,{sealed=false,children=children@[child]})))()of
            Exn.Res value=>value
          | Exn.Exn failure=>(release_lease lease;Exn.reraise failure))
        | Exn.Exn failure=>(release_lease lease;Exn.reraise failure) end));
  fun unclaimed(child as Child{claimed,...})=child_live child andalso not(Synchronized.value claimed);
  fun claim(child as Child{claimed,...})=Synchronized.change claimed(fn previous=>
    (require(not previous andalso child_live child) "Native child already constructed or denied";true));
  fun seal(p as Parent{construction,active,...}) ordered=
    Synchronized.change_result construction(fn {sealed,children}=>
      let val _=require(not sealed andalso Synchronized.value active andalso not(null ordered)
          andalso length ordered=length children andalso ListPair.allEq same_child(ordered,children)
          andalso forall child_live ordered andalso
          forall(fn Child{claimed,...}=>Synchronized.value claimed)ordered) "Native parent exact child seal";
        fun ordered_dependencies _ []=true
          | ordered_dependencies seen (child::rest)=
              forall(fn predecessor=>exists(fn previous=>same_child(predecessor,previous))seen)
                (predecessors child) andalso ordered_dependencies(child::seen)rest;
        val _=require(ordered_dependencies [] ordered) "Native parent cyclic/late child dependency"
      in (Sealed(p,ordered),{sealed=true,children=children})end);
  fun sealed_children(Sealed(_,children))=children;
  fun deny(Parent{active,...})=Synchronized.change active(K false);
  fun retain_child(child as Child{key,parent,identity,source,predecessors,claimed,lease=original,...})=
    Thread_Attributes.uninterruptible_body(fn _=>
      let fun retained()=is_some(Synchronized.value original) andalso
            (case source of SOME slice=>L.retained(L.owner slice)|NONE=>false);
        val _=require(retained()) "Native child view/source released";
        val slice=the source;
        val lease=L.retain(L.owner slice);
        val result=Exn.capture(fn()=>
          (require(retained()) "Native child released during retain";
           Child{key=key,parent=parent,identity=identity,source=source,
             predecessors=predecessors,claimed=claimed,
             lease=Synchronized.var "request_child_retained_source" (SOME lease)}))()
      in case result of Exn.Res retained=>
          (case Exn.capture(fn()=>(retain_parent_view parent;retained))()of
            Exn.Res value=>value
          | Exn.Exn failure=>(release_lease lease;Exn.reraise failure))
        | Exn.Exn failure=>(release_lease lease;Exn.reraise failure)end);
  fun release_child(Child{parent,lease,...})=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result lease(fn old=>(old,NONE))of NONE=>()
    |SOME owned=>(release_lease owned;release_parent_view parent));
  fun release_parent(parent as Parent{inputs,...})=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result inputs(fn old=>(old,NONE))of NONE=>()
    |SOME leases=>(List.app release_lease leases;release_parent_view parent));

  fun snapshot(p as Parent{id,allocator,plan,construction,...}) required=
    let val {sealed,children}=Synchronized.value construction;
      val _=require sealed "Native scope snapshot requires sealed original plan";
      fun key child=(#goal(identity child),#slot(identity child));
      val _=require(length(distinct(op =)required)=length required andalso
        forall(fn wanted=>exists(fn child=>key child=wanted)children)required)
        "Native scope snapshot required subset";
      fun original child:Saved.child=
        let val slice=source child;val {start,stop}=L.offsets slice;
          val source_id=the(I.lookup_input_identity allocator(L.owner slice))
        in {identity=identity child,source={source=source_id,start=start,stop=stop},
          predecessors=map key(predecessors child)}end;
      val original=Synchronized.change_result plan(fn previous=>case previous of
        SOME saved=>(saved,previous) |NONE=>let val saved=map original children in(saved,SOME saved)end);
      fun source_record child:Saved.source=
        let val input=L.owner(source child);
          val source_id= #source(#source(the(find_first(fn c=>
            (#goal(#identity(c:Saved.child)),#slot(#identity c))=key child)original)))
          val _=require(I.lookup_input_identity allocator input=SOME source_id andalso L.retained input)
            "Native scope original source no longer retained"
        in {identity=source_id,encoding=L.encoding input,bytes=L.bytes input}end;
      val sources=fold(fn child=>fn seen=>if not(member(op =)required(key child))then seen else
        let val record=source_record child
        in case find_first(fn previous=> #identity previous= #identity record)seen of
          NONE=>seen@[record] |SOME previous=>(require(previous=record) "Conflicting native original source";seen)end)
        children ([]:Saved.source list)
    in {version=1,workspace=I.workspace allocator,request=id,observation=Saved.StateTimeUnused,
      sources=sources,children=original}:Saved.parent end;

  datatype restore_batch=RestoreBatch of {allocator:I.allocator,
    members:(Saved.parent * Saved.required * parent * child list) list Synchronized.var,
    active:bool Synchronized.var};
  fun restore_batch allocator=RestoreBatch{allocator=allocator,
    members=Synchronized.var "scope_restored_parents" [],active=Synchronized.var "scope_restore_active" true};
  fun restore(RestoreBatch{allocator,members,active}) checked=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result members(fn old=>
      let val _=require(Synchronized.value active andalso Recovery.live checked) "Native scope restore batch/guard closed";
        val decoded=Recovery.saved checked;
        val saved={version= #version decoded,workspace= #workspace decoded,request= #request decoded,
          observation= #observation decoded,sources=[],children= #children decoded}:Saved.parent;
        val required=Recovery.required checked;
        val sources=Recovery.sources checked;
        val _=require(#workspace saved=I.workspace allocator) "Restored scope workspace mismatch";
        fun same_sources(parent:parent)=
          let val Parent{inputs,...}=parent;
            val actual=map L.lease_input(the(Synchronized.value inputs))
          in length actual=length sources andalso forall(fn(_,input)=>
            exists(fn present=>L.same_input(input,present))actual)sources end;
      in case find_first(fn(original,_,_,_)=> #request original= #request saved)old of
        SOME(original,needed,p,children)=>
          (require(original=saved andalso needed=required andalso same_sources p)
            "Conflicting authenticated native parent plan/source association";
           ((p,filter(fn child=>member(op =)required
              (#goal(identity child),#slot(identity child)))children),old))
      | NONE=>
        let val owned=Unsynchronized.ref([]:L.lease list);
          val built=Unsynchronized.ref([]:child list);
          val created=Unsynchronized.ref(NONE:parent option);
          val result=Exn.capture(fn()=>
            let val leases=map(fn(_,input)=>let val lease=L.retain input
                  in owned:=lease:: !owned;lease end)sources;
              val p=Parent{key=serial(),id= #request saved,allocator=allocator,
                policy=Recovery.policy checked,observation=StateTimeUnused,
                active=Synchronized.var "restored_scope_active" (Recovery.parent_active checked),
                inputs=Synchronized.var "restored_scope_inputs" (SOME leases),
                views=Synchronized.var "restored_scope_views" 1,
                plan=Synchronized.var "restored_scope_original_plan" (SOME(#children saved)),
                construction=Synchronized.var "restored_scope_construction" {sealed=true,children=[]}};
              val _=created:=SOME p;
              fun make(c:Saved.child)=
                let val names= #identity c;val wanted=member(op =)required(#goal names,#slot names);
                  val span= #source c;
                  val slice=if not wanted then NONE else
                    let val input=the(AList.lookup(op =)sources(#source span));
                      val bytes=L.bytes input;
                    in SOME(L.slice input{start= #start span,stop= #stop span,
                      expected=String.substring(bytes,#start span,#stop span- #start span)})end;
                  val lease=Option.map(fn source=>L.retain(L.owner source))slice;
                  val predecessors=map(fn key=>the(find_first(fn child=>
                    (#goal(identity child),#slot(identity child))=key)(!built)))(#predecessors c);
                  val child=Child{key=serial(),parent=p,identity=names,source=slice,
                    predecessors=predecessors,lease=Synchronized.var "restored_child_source" lease,
                    (* The authenticated family reconstruction binds this child
                       once. This flag grants no durable permission or charge. *)
                    claimed=Synchronized.var "restored_child_claimed" (not wanted)};
                  val _=if is_some lease then retain_parent_view p else();
                  val _=built:= !built@[child]
                in child end;
              val children=map make (#children saved);
              val Parent{construction,...}=p;
              val _=Synchronized.change construction(K{sealed=true,children=children})
            in(p,children)end)();
        in case result of Exn.Res(p,children)=>
            (case Exn.capture(fn()=>
              ((p,filter(fn child=>member(op =)required(#goal(identity child),#slot(identity child)))children),
                (saved,required,p,children)::old))()of
              Exn.Res value=>value
            | Exn.Exn failure=>(List.app release_child children;release_parent p;Exn.reraise failure))
          |Exn.Exn failure=>
            (case !created of NONE=>(List.app release_lease(!owned);Exn.reraise failure)
             |SOME p=>(List.app release_child(!built);release_parent p;Exn.reraise failure))end
      end));
  fun close_restore_batch(RestoreBatch{members,active,...})=Thread_Attributes.uninterruptible_body(fn _=>
    if not(Synchronized.change_result active(fn previous=>(previous,false)))then()else
      let val previous=Synchronized.change_result members(fn old=>(old,[]))
      in List.app(fn(_,_,p,children)=>(List.app release_child children;release_parent p))previous end);
  fun abort_restore_batch(batch as RestoreBatch{members,...})=
    (List.app(fn(_,_,p,_)=>deny p)(Synchronized.value members);close_restore_batch batch);
end;
