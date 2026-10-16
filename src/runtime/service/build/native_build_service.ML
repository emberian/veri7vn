(* Private native family component. No issuer, reducer, event admission or
   scheduler lives here. The parent supplies only already charged pure tickets. *)
functor Veri7vn_Native_Build_Service
  (structure Tickets:VERI7VN_OPERATION_TICKET_VIEW
   structure Recovery:VERI7VN_CHECKED_DEVELOPMENT_VIEW
     where type export_intent=Veri7vn_Native_Export_Intent.intent
   structure Request:VERI7VN_CHECKED_BUILD_REQUEST_VIEW
     where type export_intent=Veri7vn_Native_Export_Intent.intent
       and type control_plan=Veri7vn_Native_Deferred_Build_Types.plan
       and type failure=Veri7vn_Native_Build_Terminal.failure
   structure Scope:VERI7VN_NATIVE_REQUEST_SCOPE) :>
sig
  structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
    where type export_intent=Veri7vn_Native_Export_Intent.intent
      and type checked_request=Request.checked_request
  type owner type entry type job type deferred
  type installation={allocator:Veri7vn_Native_Identity_Allocator.allocator,
    template:IntInf.int,profile:IntInf.int,setup:IntInf.int,operation:IntInf.int,
    code_generation:IntInf.int,capability:IntInf.int,step:IntInf.int,
    operation_generation:Veri7vn_Native_Registry.generation,
    roots:Veri7vn_Native_Installed_Roots.registry,installed_parents:(string*Veri7vn_Managed_Provenance.development)list}
  type key=IntInf.int*IntInf.int*IntInf.int
  type names={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,interpretation:IntInf.int,
    decision:IntInf.int,parameter:IntInf.int,candidate:IntInf.int,execution:IntInf.int,
    capability:IntInf.int,step:IntInf.int,operation:IntInf.int,code_generation:IntInf.int,
    semantic_generation:IntInf.int}
  structure CandidateOwner:sig type candidate=Builder.candidate type lease
    val candidate:lease->candidate val retain:lease->lease val release:lease->unit val is_live:lease->bool end
  structure PreparedOwner:sig type prepared=Builder.prepared type lease
    val prepared:lease->prepared val retain:lease->lease val release:lease->unit val is_live:lease->bool end
  structure OutputOwner:sig type candidate=Builder.candidate type lease
    val candidate:lease->candidate val assigned_slot:lease->IntInf.int
    val retain:lease->lease val release:lease->unit val is_live:lease->bool end
  datatype export_selection=DevelopmentOnly|DeclaredTheorems
  datatype parent_source=InstalledSource of string|KnownSource of string*OutputOwner.lease|
    ReservedSource of string*Scope.child
  val defer_into:deferred option Unsynchronized.ref->owner->Scope.child->IntInf.int->
    parent_source list->export_selection->deferred
  val restore_deferred_into:deferred option Unsynchronized.ref->owner->Scope.child->
    Veri7vn_Native_Package_Inputs.prepared_input->Veri7vn_Native_Registry.generation->OutputOwner.lease list->deferred
  type deferred_material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
    projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string}
  val export_deferred:Veri7vn_Native_Recovery_Check.image->(IntInf.int*IntInf.int)list->deferred->deferred_material
  val deferred_plan:deferred->Veri7vn_Native_Deferred_Build_Types.plan
  val deferred_intent:deferred->Veri7vn_Native_Export_Intent.intent
  val deferred_live:deferred->bool
  val bind_deferred_into:entry option Unsynchronized.ref->deferred->
    (Scope.child*OutputOwner.lease)list->entry
  val release_deferred:deferred->unit
  val create:installation->owner
  val names:entry->names val key:entry->key val live:entry->bool
  val child:entry->Scope.child val deferred_child:deferred->Scope.child
  val lookup:owner->key->entry option
  val input_binding:owner->IntInf.int->Veri7vn_Native_Package_Inputs.binding
  val source_binding:entry->Veri7vn_Native_Package_Inputs.binding
  val request_plan:entry->Veri7vn_Native_Deferred_Build_Types.plan
  val prepared:entry->Builder.prepared
  val prepare_into:entry option Unsynchronized.ref ->owner->Scope.child->IntInf.int->
    (string*CandidateOwner.lease)list->entry
  val prepare_exports_into:entry option Unsynchronized.ref ->owner->Scope.child->IntInf.int->
    (string*CandidateOwner.lease)list->export_selection->entry
  val prepared_lease:entry->PreparedOwner.lease
  val candidate_lease:entry->CandidateOwner.lease
  val acknowledge_output:entry->OutputOwner.lease
  val output_candidate_lease:OutputOwner.lease->CandidateOwner.lease
  val restored_installation:owner->Request.checked_request->Builder.installation
  val restore_output_into:OutputOwner.lease option Unsynchronized.ref->owner->Request.checked_request->Recovery.checked_development->OutputOwner.lease
  val start:entry->Builder.prepared Tickets.pure_ticket->job
  val cancel:entry->unit val join:job->unit val finished:job->bool
  val forget_sources:owner->IntInf.int list->unit
  val release_entry:entry->unit val invalidate:owner->IntInf.int list->entry list
  datatype phase=Prepared|Executing|CandidateBuilt|ArtifactReady|BuildFailed|BuildRefused
  datatype status_view=Unavailable|Status of {key:key,prepared_input:IntInf.int,
    source_revision:IntInf.int,manifest:IntInf.int,candidate:IntInf.int option,
    phase:phase,failure:Builder.diagnostic option}
  val inspect:entry->status_view val failure_packet:Builder.diagnostic->string
  val observed_failure:entry->IntInf.int->Veri7vn_Native_Build_Terminal.failure option
  val terminal_failure_packet:Veri7vn_Native_Build_Terminal.failure->string
  datatype transfer_operation=Begin of string|Write of IntInf.int*Veri7vn_Native_Package_Inputs.part*int*Bytes.T|
    Finish of IntInf.int|Abort of IntInf.int|Discard of string|Accept of string*IntInf.int|
    Settle of string|Release of IntInf.int
  datatype transfer_result=TransferReady of IntInf.int|TransferWritten of IntInf.int|
    InputPrepared of IntInf.int|TransferAborted of IntInf.int|NonceDiscarded of string|
    InputAccepted of string*IntInf.int|NonceSettled of string|InputReleased of IntInf.int
  val decode_transfer:string->string->Bytes.T list->transfer_operation
  val transfer_operation:owner->transfer_operation->transfer_result
  val transfer_reply:transfer_result->string*string
  val close:owner->unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure Inputs=Veri7vn_Native_Package_Inputs;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure T=Veri7vn_Native_Deferred_Build_Types;
  structure B=Veri7vn_Native_Build_Candidate(
    structure Tickets=Tickets structure Intent=Intent structure Recovery=Recovery
    structure Request=Request val executable=Veri7vn_Native_Build_Image.executable
    val cost=1 val max_source_bytes=1000000);
  structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE=B;
  fun require true _=()|require false text=error text;
  type key=IntInf.int*IntInf.int*IntInf.int;
  type installation={allocator:I.allocator,template:IntInf.int,profile:IntInf.int,setup:IntInf.int,
    operation:IntInf.int,code_generation:IntInf.int,capability:IntInf.int,step:IntInf.int,
    operation_generation:Veri7vn_Native_Registry.generation,
    roots:Veri7vn_Native_Installed_Roots.registry,installed_parents:(string*P.development)list};
  type names={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,interpretation:IntInf.int,
    decision:IntInf.int,parameter:IntInf.int,candidate:IntInf.int,execution:IntInf.int,
    capability:IntInf.int,step:IntInf.int,operation:IntInf.int,code_generation:IntInf.int,
    semantic_generation:IntInf.int};
  datatype group=Group of {candidate:B.candidate,key:key,dependencies:IntInf.int list,
    parent_roots:candidate_lease list Synchronized.var,
    state:{active:bool,acknowledged:bool,refs:int} Synchronized.var}
  and candidate_lease=CandidateLease of {group:group,active:bool Synchronized.var};
  fun group_live(Group{candidate,state,...})= #active(Synchronized.value state) andalso B.is_live candidate;
  fun lease_live(CandidateLease{group,active})=Synchronized.value active andalso group_live group;
  fun candidate(lease as CandidateLease{group=Group{candidate,...},...})=
    (require(lease_live lease) "Native candidate lease released or denied";candidate);
  fun retain(lease as CandidateLease{group=group as Group{state,...},...})=
    Thread_Attributes.uninterruptible_body(fn _=>
      (require(lease_live lease) "Native candidate lease released or denied";
       Synchronized.change state(fn {active,acknowledged,refs}=>
         (require active "Native candidate denied";{active=active,acknowledged=acknowledged,refs=refs+1}));
       CandidateLease{group=group,active=Synchronized.var "build_candidate_lease" true}));
  fun release(CandidateLease{group=Group{candidate,state,parent_roots,...},active=lease_active})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change lease_active(fn live=>
      if not live then false else
      let val final=Synchronized.change_result state(fn {active,acknowledged,refs}=>
        (require(refs>0) "Native candidate reference underflow";
         if refs=1 then(true,{active=false,acknowledged=acknowledged,refs=1})
         else(false,{active=active,acknowledged=acknowledged,refs=refs-1})))
        (* A failing final destructor preserves this active cleanup lease and
           refs=1, while denying all new readers/retains. Release can retry. *)
        val _=if final then
          (B.release candidate;release_parent_roots parent_roots;
           Synchronized.change state(fn {acknowledged,...}=>
            {active=false,acknowledged=acknowledged,refs=0}))else()
      in false end))
  and release_parent_roots roots=Synchronized.change roots(fn parents=>
    let fun drain []=[]
          |drain(parent::rest)=(release parent;drain rest)
    in drain parents end);
  structure CandidateOwner =
  struct type candidate=B.candidate type lease=candidate_lease
    val candidate=candidate val retain=retain val release=release val is_live=lease_live
  end;
  datatype output_lease=OutputLease of candidate_lease;
  val lease_candidate=candidate;
  val retain_candidate=retain;
  val release_candidate=release;
  structure OutputOwner =
  struct
    type candidate=B.candidate type lease=output_lease
    fun is_live(OutputLease(lease as CandidateLease{group=Group{state,...},...}))=
      lease_live lease andalso #acknowledged(Synchronized.value state);
    fun candidate(owner as OutputLease lease)=
      (require(is_live owner) "Native build output is not acknowledged";lease_candidate lease);
    fun assigned_slot owner= #slot(B.execution_plan(candidate owner));
    fun retain(owner as OutputLease lease)=
      (require(is_live owner) "Native build output is not acknowledged";OutputLease(retain_candidate lease));
    fun release(OutputLease lease)=release_candidate lease;
  end;
  datatype export_selection=DevelopmentOnly | DeclaredTheorems;
  datatype parent_source=InstalledSource of string|KnownSource of string*output_lease|
    ReservedSource of string*Scope.child;
  datatype outcome=Pending | Running | Built of candidate_lease | Failed of B.diagnostic |
    Refused of string | Cancelled;
  datatype job=Job of {future:unit Future.future option Synchronized.var,
    scope:P.construction_scope option Synchronized.var};
  datatype entry=Entry of {owner:owner,names:names,input_id:IntInf.int,child:Scope.child,input:Inputs.prepared_input,intent:Intent.intent,
    prepared:B.prepared,parents:candidate_lease list,frozen_plan:T.plan option,runnable:bool,active:bool Synchronized.var,
    refs:int Synchronized.var,producer:bool Synchronized.var,cleanup:unit Synchronized.var,
    result:outcome Synchronized.var,candidate_root:candidate_lease option Synchronized.var,job:job option Synchronized.var}
  and owner=Owner of {configuration:installation,builder:B.installation,pool:Inputs.pool,
    entries:entry list Synchronized.var,deferred:deferred list Synchronized.var,groups:group list Synchronized.var,
    transfers:(IntInf.int*Inputs.transfer)list Synchronized.var,
    prepared:(IntInf.int*Inputs.prepared_input)list Synchronized.var,
    finished:(IntInf.int*IntInf.int)list Synchronized.var,
    construction_scopes:(IntInf.int*P.construction_scope)list Synchronized.var,
    pending_constructions:(serial*{scope:P.construction_scope,parents:candidate_lease list Unsynchronized.ref,
      children:Scope.child list Unsynchronized.ref,outputs:output_lease list Unsynchronized.ref})list Synchronized.var,open_owner:bool Synchronized.var}
  and deferred=Deferred of {owner:owner,input_id:IntInf.int,input:Inputs.prepared_input,
    intent:Intent.intent,child:Scope.child,names:names,parents:parent_source list,
    selection:export_selection,snapshot:Veri7vn_Native_Deferred_Build_Types.plan,runnable:bool,
    active:bool Synchronized.var,binding:{started:bool,entry:entry option} Synchronized.var};
  fun create(configuration:installation)=
    let val {allocator,template,profile,setup,operation,code_generation,installed_parents,roots,
          operation_generation,capability,step}=configuration
      val operation_theory=Proof_Context.theory_of(Veri7vn_Native_Registry.context operation_generation)
      val _=require(is_some(I.lookup_generation_id allocator operation_generation) andalso
        Context.subthy(Veri7vn_Executable_Identity.code_theory B.executable,operation_theory) andalso
        capability>0 andalso step>0) "Build operation image/identity is not registered"
      val _=List.app(fn(raw,d)=>
        let val theory=Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation d))
          val canonical=Veri7vn_Native_Installed_Roots.resolve_import roots raw
        in require(Veri7vn_Native_Installed_Roots.matches roots canonical theory andalso
          Context.subthy(theory,operation_theory)) "Build installed map differs from fixed roots/image"end)installed_parents
    in Owner{configuration=configuration,builder=B.install{template=template,profile=profile,
      setup=setup,operation=operation,step=step,code_generation=code_generation,installed_parents=installed_parents},
      pool=Inputs.create allocator,entries=Synchronized.var "build_entries" [],
      deferred=Synchronized.var "deferred_build_plans" [],
      groups=Synchronized.var "build_candidates" [],transfers=Synchronized.var "build_transfers" [],
      prepared=Synchronized.var "build_inputs" [],finished=Synchronized.var "build_finished_transfers" [],
      construction_scopes=Synchronized.var "build_transfer_scopes" [],
      pending_constructions=Synchronized.var "build_pending_constructions" [],
      open_owner=Synchronized.var "build_owner_active" true}end;
  fun owner_live(Owner{open_owner,...})=Synchronized.value open_owner;
  fun names(Entry{names,...})=names;
  fun child(Entry{child,...})=child;
  fun deferred_child(Deferred{child,...})=child;
  fun key entry=let val n=names entry in(#request n,#goal n,#slot n)end;
  fun live(Entry{owner,child,input,prepared,parents,active,...})=
    owner_live owner andalso Synchronized.value active andalso Scope.child_live child andalso
      Inputs.is_live input andalso B.prepared_live prepared andalso forall lease_live parents;
  fun prepared(entry as Entry{prepared,...})=(require(live entry) "Native build entry unavailable";prepared);
  fun source_binding(entry as Entry{input,...})=(require(live entry) "Native build entry unavailable";Inputs.binding input);
  fun lookup(Owner{entries,...}) identity=find_first(fn entry=>key entry=identity)(Synchronized.value entries);
  fun source_handle(Owner{prepared,...}) id=case AList.lookup(op =)(Synchronized.value prepared)id of
    SOME input=>(require(Inputs.is_live input) "Native build input released";input)
    |NONE=>error "Unknown native build input";
  fun input_binding owner id=Inputs.binding(source_handle owner id);
  fun prepare_internal target (owner as Owner{configuration,builder,entries,pending_constructions,...}) child input_id input authored selection frozen intent_override frozen_plan runnable=
    Thread_Attributes.uninterruptible_body(fn restore=>
    let val construction_key=serial()
      val scope=P.construction_scope()
      val kept=Unsynchronized.ref([]:candidate_lease list)
      val kept_child=Unsynchronized.ref([]:Scope.child list)
      val pending_outputs=Unsynchronized.ref([]:output_lease list)
      val header_root=Unsynchronized.ref(NONE:Thy_Header.header option)
      val prepared_root=Unsynchronized.ref(NONE:B.prepared option)
      val _=Synchronized.change pending_constructions(fn old=>
        (require(length old<512) "Build pending construction bound";
         (construction_key,{scope=scope,parents=kept,children=kept_child,outputs=pending_outputs})::old))
      val published=Unsynchronized.ref(NONE:entry option)
      val outcome=Exn.capture(fn()=>
        let val _=require(owner_live owner andalso (Scope.unclaimed child orelse is_some frozen)) "Native build child already claimed"
          val data=Inputs.binding input
          val source=Scope.source child
          val _=require(L.same_input(L.owner source,L.owner(#theory_slice data)) andalso
            L.offsets source=L.offsets(#theory_slice data)) "Build child belongs to another captured original"
          val identity=Scope.identity child
          val {allocator,capability,step,operation,code_generation,operation_generation,...}=configuration
          val _=require(I.workspace allocator=I.workspace(Scope.allocator(Scope.parent child)))
            "Build child workspace differs from runtime installation"
          val _=require(length authored<=64 andalso length(distinct(op =)(map #1 authored))=length authored)
            "Build authored parent bounds"
          val _=List.app(fn(_,lease)=>
            let val p=B.execution_plan(candidate lease)
            in require(#request p= #request identity andalso
              exists(fn predecessor=> #slot(Scope.identity predecessor)= #slot p)(Scope.predecessors child))
              "Build parent is not an owned same-request predecessor"end)authored
          val _=restore(fn()=>header_root:=SOME(Thy_Header.read Position.none(L.original source)))()
          val header=the(!header_root)
          val imports=map #1(#imports header)
          val _=require(forall(fn(raw,_)=>member(op =)imports raw)authored) "Unused authored build parent"
          val parents=map(fn raw=>case AList.lookup(op =)authored raw of
            NONE=>B.Installed raw |SOME lease=>let val c=candidate lease
              in B.Candidate(#candidate(B.projection c),raw,B.development c)end)imports
          val _=if is_none frozen then require(#parents(#metadata data)=
            map_filter(fn B.Installed _=>NONE|B.Candidate(id,_,_)=>SOME id)parents)
            "Build authored parents differ from captured original input association" else()
          val input_root=Inputs.retain_owned scope input
          val intent=case intent_override of NONE=>Inputs.intent_owned scope input_root
            |SOME original=>Intent.retain_owned scope original
          val parameter=case frozen of NONE=>I.allocate allocator|SOME(n:names)=> #parameter n
          val candidate_id=case frozen of NONE=>I.allocate allocator|SOME n=> #candidate n
          val execution=case frozen of NONE=>I.allocate allocator|SOME n=> #execution n
          val semantic_generation=case I.lookup_generation_id allocator operation_generation of
            SOME id=>id|NONE=>error "Builder operation context lacks an owned durable association"
          val _=require(Context.eq_thy(Proof_Context.theory_of(Veri7vn_Native_Registry.context operation_generation),
            Veri7vn_Native_Admission.policy_theory(Scope.policy(Scope.parent child))))
            "Build scope differs from fixed registered operation context"
          val parents_kept=map(fn(_,lease)=>let val root=retain lease
            in kept:=root:: !kept;root end)authored
          val child_root=Scope.retain_child child
          val _=kept_child:=[child_root]
          val input_bindings=parameter::map_filter(fn B.Installed _=>NONE|B.Candidate(id,_,_)=>SOME id)parents
          val _=restore(fn()=>prepared_root:=SOME(B.prepare builder{source= #theory_source data,slice= #theory_slice data,
            original_intent=intent,source_revision= #source_revision data,manifest= #manifest data,
            parents=parents,exports=(case selection of DevelopmentOnly=>[]|DeclaredTheorems=>Intent.theorem_names intent),export_intent= #export_intent data,candidate=candidate_id,
            request= #request identity,goal= #goal identity,execution=execution,slot= #slot identity,
            semantic_generation=semantic_generation,input_bindings=input_bindings}))()
          val p=the(!prepared_root)
          val n={request= #request identity,goal= #goal identity,slot= #slot identity,
            interpretation= #interpretation identity,decision= #decision identity,
            parameter=parameter,candidate=candidate_id,execution=execution,capability=capability,
            step=step,operation=operation,code_generation=code_generation,semantic_generation=semantic_generation}:names
          val _=Option.app(fn expected=>require(expected=n) "Deferred build frozen controls changed")frozen
          val entry=Entry{owner=owner,names=n,input_id=input_id,child=child_root,input=input_root,intent=intent,prepared=p,
            parents=parents_kept,frozen_plan=frozen_plan,runnable=runnable,active=Synchronized.var "build_entry_active" true,
            refs=Synchronized.var "build_entry_refs" 1,producer=Synchronized.var "build_entry_producer" true,
            cleanup=Synchronized.var "build_entry_cleanup" (),
            result=Synchronized.var "build_entry_result" Pending,
            candidate_root=Synchronized.var "build_entry_candidate_cleanup" NONE,job=Synchronized.var "build_entry_job" NONE}
          val _=if is_none frozen then Scope.claim child else()
          val _=published:=SOME entry
          val _=Synchronized.change entries(fn old=>(require(length old<256 andalso
            not(exists(fn previous=>key previous=key entry)old)) "Native build entry bound/duplicate";entry::old))
          val _=target:=SOME entry
          val _=P.commit_scope scope
          val _=Synchronized.change pending_constructions(AList.delete(op =)construction_key)
        in entry end)()
    in case outcome of Exn.Res entry=>entry |Exn.Exn failure=>
      (Option.app(fn entry=>Synchronized.change entries(filter(fn other=>key other<>key entry)))(!published);
       target:=NONE;P.abort_scope scope;
       List.app release(!kept);List.app Scope.release_child(!kept_child);
       Synchronized.change pending_constructions(AList.delete(op =)construction_key);Exn.reraise failure)end);
  fun prepare_exports_into target owner child input_id authored selection=
    prepare_internal target owner child input_id(source_handle owner input_id)authored selection NONE NONE NONE true;
  fun prepare_into target owner child input_id authored=
    prepare_exports_into target owner child input_id authored DevelopmentOnly;
  fun status(entry as Entry{result,...})=
    if live entry then Synchronized.value result else Cancelled;
  datatype phase=Prepared | Executing | CandidateBuilt | ArtifactReady | BuildFailed | BuildRefused;
  datatype status_view=Unavailable | Status of {key:key,prepared_input:IntInf.int,
    source_revision:IntInf.int,manifest:IntInf.int,candidate:IntInf.int option,
    phase:phase,failure:B.diagnostic option};
  fun inspect(entry as Entry{owner=Owner{prepared=producer_inputs,...},input_id,result,input,...})=
    if not(live entry)then Unavailable else
    let val binding=Inputs.binding input
      val (phase,candidate,failure)=case Synchronized.value result of
        Pending=>(Prepared,NONE,NONE)|Running=>(Executing,NONE,NONE)
      |Built(lease as CandidateLease{group=Group{state,...},...})=>
          if lease_live lease then
            (if #acknowledged(Synchronized.value state)then ArtifactReady else CandidateBuilt,
             SOME(#candidate(B.projection(candidate lease))),NONE)
          else(BuildRefused,NONE,NONE)
      |Failed diagnostic=>(BuildFailed,NONE,SOME diagnostic)
      |Refused _=>(BuildRefused,NONE,NONE)|Cancelled=>(BuildRefused,NONE,NONE)
      val producer_id=if exists(fn(id,root)=>id=input_id andalso Inputs.is_live root)
        (Synchronized.value producer_inputs) then input_id else 0
    in Status{key=key entry,prepared_input=producer_id,source_revision= #source_revision binding,
      manifest= #manifest binding,candidate=candidate,phase=phase,failure=failure}end;
  fun failure_packet({phase,source_revision,manifest,span,message}:B.diagnostic)=
    let val visible=XML.content_of(YXML.parse_body message)
      val location=case span of NONE=>XML.Elem(("span-unavailable",[("reason","not_reported")]),[])
        |SOME{start,stop}=>XML.Elem(("span",[("start",Int.toString start),("stop",Int.toString stop)]),[])
      val detail=if size visible<=4096 then XML.Elem(("message",[]),[XML.Text visible])
        else XML.Elem(("message-unavailable",[("reason","exceeds_bound")]),[])
      val packet=YXML.string_of_body[XML.Elem(("veri7vn-build-failure",
        [("version","1"),("phase",case phase of B.NativeReplay=>"replay"|B.NativeExport=>"export"),
         ("source_revision",IntInf.toString source_revision),("manifest",IntInf.toString manifest)]),[location,detail])]
    in require(size packet<=8192) "Native build diagnostic bound";packet end;
  fun request_plan(entry as Entry{owner=Owner{configuration={allocator,roots,...},...},names=n,
      input_id,input,intent,parents,frozen_plan,...})=
    case frozen_plan of SOME snapshot=>snapshot|NONE=>
    let val prepared=prepared entry val projection=B.prepared_projection prepared
      val binding=Inputs.binding input val descriptor=Intent.binding intent
      val source_span=L.offsets(#theory_slice binding) val descriptor_span=L.offsets(#slice descriptor)
      fun parent(NONE,raw,_)=T.Installed{locator=raw,
            root=Veri7vn_Native_Installed_Roots.resolve_import roots raw}
        |parent(SOME id,raw,development)=
            let val lease=case find_first(fn lease=> #candidate(B.projection(candidate lease))=id)parents of
                  SOME lease=>lease|NONE=>error "Build request parent owner missing"
              val CandidateLease{group=Group{key=(_,_,slot),...},...}=lease
              val context=case I.lookup_generation_id allocator(P.generation development)of
                SOME context=>context|NONE=>error "Build request parent context unregistered"
            in T.KnownCandidate{locator=raw,candidate=id,context=context,slot=slot}end
    in {original_input= #metadata binding,prepared_input=input_id,workspace=I.workspace allocator,
      request= #request n,goal= #goal n,slot= #slot n,interpretation= #interpretation n,
      decision= #decision n,parameter= #parameter n,candidate= #candidate n,execution= #execution n,
      template= #template projection,profile= #profile projection,setup= #setup projection,
      capability= #capability n,operation= #operation n,code_generation= #code_generation n,
      operation_generation= #semantic_generation n,step= #step n,
      parents=map parent(B.prepared_parents prepared),exports=B.prepared_exports prepared,
      dependencies=B.prepared_parent_dependencies prepared,
      source={source_owner= #source_owner projection,start= #start source_span,stop= #stop source_span,
        source_revision= #source_revision projection,manifest= #manifest projection,
        export_intent= #export_intent projection,descriptor_source=P.source_identity(#source descriptor),
        descriptor_start= #start descriptor_span,descriptor_stop= #stop descriptor_span}}:T.plan end;
  val terminal_failure_packet=Veri7vn_Native_Build_Terminal.diagnostic_packet;
  fun observed_failure entry reason=
    (require(reason>0) "Native build failure reason identity";
     case inspect entry of Status{phase=BuildFailed,failure=SOME diagnostic,...}=>
       let val control=names entry
         val visible=XML.content_of(YXML.parse_body(#message diagnostic))
         val snapshot={request= #request control,goal= #goal control,slot= #slot control,
           execution= #execution control,reason=reason,source_revision= #source_revision diagnostic,
           manifest= #manifest diagnostic,phase=(case #phase diagnostic of
             B.NativeReplay=>Veri7vn_Native_Build_Terminal.Replay|
             B.NativeExport=>Veri7vn_Native_Build_Terminal.Export),span= #span diagnostic,
           message=if size visible<=4096 then SOME visible else NONE}:Veri7vn_Native_Build_Terminal.failure
         val _=Veri7vn_Native_Build_Terminal.validate snapshot
       in SOME snapshot end
     |_=>NONE);
  fun start(entry as Entry{owner=Owner{groups,...},result,candidate_root,job,runnable,parents,...}) ticket=
    Thread_Attributes.uninterruptible_body(fn _=>
    let val _=require(live entry andalso runnable) "Native build entry requires new current authorization"
      val _=Synchronized.change result(fn Pending=>Running|_=>error "Native build attempt already started")
      val attempt=case Exn.capture(fn()=>B.claim_ticket_for(prepared entry)ticket)()of
          Exn.Res attempt=>attempt
        |Exn.Exn failure=>(Synchronized.change result(K(Refused "native_build.ticket_binding"));Exn.reraise failure)
      val scope_root=Synchronized.var "build_job_construction" NONE
      val future_root=Synchronized.var "build_job_future" NONE
      val running=Job{future=future_root,scope=scope_root}
      val _=Synchronized.change job(K(SOME running))
      fun run()=
        let val scope=Thread_Attributes.uninterruptible_body(fn _=>
            let val scope=P.construction_scope()val _=Synchronized.change scope_root(K(SOME scope))in scope end)
          val produced=Exn.capture(fn()=>B.execute_attempt_owned scope attempt)()
        in Thread_Attributes.uninterruptible_body(fn _=>
          let val completion=Exn.capture(fn()=>case produced of
            Exn.Res candidate=>if live entry then
              let val parent_roots=Synchronized.var "candidate_parent_owners" []
                val group=Group{candidate=candidate,key=key entry,parent_roots=parent_roots,
                dependencies=distinct(op =)(B.retention_dependencies candidate @
                  [#request(names entry),#goal(names entry),#slot(names entry)]),
                state=Synchronized.var "owned_build_candidate"{active=true,acknowledged=false,refs=1}}
                val lease=CandidateLease{group=group,active=Synchronized.var "build_candidate_base" true}
                val _=Synchronized.change candidate_root(K(SOME lease))
                val _=Synchronized.change groups(fn old=>
                  let val retained=filter(fn Group{state,...}=> #refs(Synchronized.value state)>0)old
                  in require(length retained<256) "Native candidate owner bound";group::retained end)
                (* The group is already a fixed cleanup root before retaining
                   any ancestors. Entry teardown may then release all prepared
                   parent leases without destroying a committed descendant. *)
                val _=List.app(fn parent=>
                  let val held=retain parent
                  in Synchronized.change parent_roots(cons held)end)parents
                val _=P.commit_scope scope
              in Synchronized.change result(K(Built lease))end
              else(P.abort_scope scope;Synchronized.change result(K Cancelled))
          |Exn.Exn(B.Build_Failure diagnostic)=>(P.abort_scope scope;Synchronized.change result(K(Failed diagnostic)))
          |Exn.Exn failure=>(P.abort_scope scope;Synchronized.change result(K(if Exn.is_interrupt failure then Cancelled
              else Refused "native_build.execution_failed"))))()
            val _=case completion of Exn.Res()=>()|Exn.Exn failure=>
              (Synchronized.change result(K(Refused "native_build.completion_failed"));
               P.abort_scope scope)
          in Synchronized.change scope_root(K NONE)end)end
      val future=case Exn.capture(fn()=>Future.fork run)()of Exn.Res future=>future
        |Exn.Exn failure=>(Synchronized.change result(K(Refused "native_build.worker_start"));
          Synchronized.change job(K NONE);Exn.reraise failure)
      val _=Synchronized.change future_root(K(SOME future))
    in running end);
  fun cancel(Entry{active,job,...})=
    (Synchronized.change active(K false);Option.app(fn Job{future,...}=>
      Option.app Future.cancel(Synchronized.value future))(Synchronized.value job));
  fun join(Job{future,...})=Option.app(fn task=>ignore(Future.join_result task))(Synchronized.value future);
  fun finished(Job{future,...})=case Synchronized.value future of SOME task=>Future.is_finished task|NONE=>false;
  fun candidate_lease entry=case status entry of Built lease=>retain lease|_=>error "Native candidate not built";
  fun acknowledge_output entry=
    Thread_Attributes.uninterruptible_body(fn _=>
      let val lease=case status entry of Built root=>root|_=>error "Native candidate not built"
        val CandidateLease{group=Group{state,...},...}=lease
        val _=Synchronized.change state(fn {active,refs,...}=>
          (require active "Native candidate denied";{active=active,acknowledged=true,refs=refs}))
      in OutputLease(retain lease) end);
  fun output_candidate_lease(owner as OutputLease lease)=
    (require(OutputOwner.is_live owner) "Native output association is not acknowledged";retain lease);
  fun restored_builder(Owner{configuration={installed_parents,...},...})(plan:T.plan)=
    B.install{template= #template plan,profile= #profile plan,setup= #setup plan,
      operation= #operation plan,step= #step plan,code_generation= #code_generation plan,
      installed_parents=installed_parents};
  fun restored_installation owner request=
    let val _=require(Request.is_live request andalso
          Veri7vn_Executable_Identity.same(Request.executable request,B.executable))
          "Build restored installation requires checked original producer"
      val plan=case Request.control_plan request of SOME plan=>plan
        |NONE=>error "Build restored installation lacks original controls"
      val binding=Request.binding request
      val _=require(#request binding= #request plan andalso #goal binding= #goal plan andalso
        #slot binding= #slot plan andalso #candidate binding= #candidate plan andalso
        #lineage binding= #execution plan andalso #template binding= #template plan andalso
        #profile binding= #profile plan andalso #setup binding= #setup plan)
        "Build restored installation differs from protected request"
    in restored_builder owner plan end;
  fun restore_output_into target (owner as Owner{groups,open_owner,...}) request witness=
    Thread_Attributes.uninterruptible_body(fn _=>
      let val _=require(Synchronized.value open_owner andalso Request.is_live request andalso
          Veri7vn_Executable_Identity.same(Request.executable request,B.executable)) "Native build restore owner unavailable"
        val plan=case Request.control_plan request of SOME plan=>plan
          |NONE=>error "Candidate restoration requires authenticated original Build request controls"
        val candidate_binding=Recovery.binding witness val request_binding=Request.binding request
        val _=require(#request candidate_binding= #request plan andalso #goal candidate_binding= #goal plan andalso
          #slot candidate_binding= #slot plan andalso #candidate candidate_binding= #candidate plan andalso
          #lineage candidate_binding= #execution plan andalso #template candidate_binding= #template plan andalso
          #profile candidate_binding= #profile plan andalso #setup candidate_binding= #setup plan andalso
          #request request_binding= #request plan andalso #goal request_binding= #goal plan andalso
          #slot request_binding= #slot plan andalso
          L.same_input(P.source_input(#source candidate_binding),P.source_input(#source request_binding)) andalso
          L.offsets(#slice candidate_binding)=L.offsets(#slice request_binding))
          "Candidate restoration differs from authenticated original request"
        val builder=restored_builder owner plan
        val kept=filter(fn Group{state,...}=> #refs(Synchronized.value state)>0)(Synchronized.value groups)
        val _=require(length kept<256) "Native candidate owner bound"
        (* This witness was checked against the authenticated latest artifact
           assignment by the fixed recovery factory, not decoded into authority. *)
        val candidate=B.restore builder witness
        val plan=B.execution_plan candidate
        val group=Group{candidate=candidate,key=(#request plan,#goal plan,#slot plan),
          (* The checked recovery witness owns its actual whole G ancestry. *)
          parent_roots=Synchronized.var "restored_candidate_parent_owners" [],
          dependencies=distinct(op =)(B.retention_dependencies candidate @
            [#request plan,#goal plan,#slot plan]),
          state=Synchronized.var "restored_build_candidate"{active=true,acknowledged=true,refs=1}}
        val lease=CandidateLease{group=group,active=Synchronized.var "restored_build_output_lease" true}
        val output=OutputLease lease
        val _=Synchronized.change groups(fn old=>group::filter(fn Group{state,...}=> #refs(Synchronized.value state)>0)old)
        val _=target:=SOME output
      in output end);
  fun dispose_entry(entry as Entry{owner=Owner{entries,...},child,input,intent,parents,result,candidate_root,job,...})=
    let val _=cancel entry
      val _=Option.app join(Synchronized.value job)
      val _=Option.app(fn Job{scope,...}=>Option.app P.abort_scope(Synchronized.value scope))
        (Synchronized.value job)
      val _=Option.app release(Synchronized.value candidate_root)
      val _=Synchronized.change candidate_root(K NONE)
      val _=List.app release parents
      val _=Intent.release intent
      val _=Inputs.release input
      val _=Scope.release_child child
      val _=Synchronized.change result(K Cancelled)
    in Synchronized.change entries(filter(fn other=>key other<>key entry))end;
  fun release_entry_root(entry as Entry{refs,active,...}) root=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change root(fn held=>
      if not held then false else
      let val final=Synchronized.change_result refs(fn n=>
          (require(n>0) "Build prepared owner reference underflow";
           if n=1 then(Synchronized.change active(K false);(true,n))else(false,n-1)))
        val _=if final then(dispose_entry entry;
          Synchronized.change refs(K 0))else()
      in false end));
  fun release_entry(entry as Entry{producer,job,...})=
    (case Synchronized.value job of SOME running=>if finished running then()else cancel entry|NONE=>();
     release_entry_root entry producer);
  datatype prepared_lease=PreparedLease of {entry:entry,active:bool Synchronized.var};
  val entry_prepared=prepared;
  structure PreparedOwner =
  struct
    type prepared=B.prepared type lease=prepared_lease
    fun is_live(PreparedLease{entry,active})=Synchronized.value active andalso live entry;
    fun prepared(lease as PreparedLease{entry,...})=
      (require(is_live lease) "Prepared build lease unavailable";entry_prepared entry);
    fun retain(lease as PreparedLease{entry=entry as Entry{refs,...},...})=
      Thread_Attributes.uninterruptible_body(fn _=>
        (require(is_live lease) "Prepared build lease unavailable";
         Synchronized.change refs(fn n=>(require(n>0 andalso live entry) "Prepared build owner disposed";n+1));
         PreparedLease{entry=entry,active=Synchronized.var "build_prepared_lease" true}));
    fun release(PreparedLease{entry,active})=release_entry_root entry active;
  end;
  fun prepared_lease(entry as Entry{refs,...})=Thread_Attributes.uninterruptible_body(fn _=>
    (require(live entry) "Prepared build entry unavailable";
     Synchronized.change refs(fn n=>(require(n>0 andalso live entry) "Prepared build owner disposed";n+1));
     PreparedLease{entry=entry,active=Synchronized.var "build_prepared_lease" true}));
  fun invalidate(owner as Owner{entries,groups,deferred,prepared=producer_inputs,...}) ids=
    let val _=List.app(fn(_,input)=>ignore(Inputs.invalidate_sources input ids))(Synchronized.value producer_inputs)
      val affected=filter(fn entry=>
          let val n=names entry val deps=B.prepared_parent_dependencies(prepared entry) @
            B.prepared_inputs(prepared entry) @ [#request n,#goal n,#slot n,#candidate n]
          in exists(member(op =)ids)deps end handle ERROR _=>true)(Synchronized.value entries)
      val _=List.app(fn Group{candidate,dependencies,state,...}=>
        if #refs(Synchronized.value state)>0 andalso
          (not(B.is_live candidate) orelse exists(member(op =)ids)(#candidate(B.projection candidate)::dependencies))then
          Synchronized.change state(fn {acknowledged,refs,...}=>{active=false,acknowledged=acknowledged,refs=refs})else())
        (Synchronized.value groups)
      val _=List.app(fn Deferred{snapshot,active,...}=>
        if exists(member(op =)ids)(#request snapshot:: #goal snapshot:: #slot snapshot::
          #candidate snapshot:: #dependencies snapshot)then Synchronized.change active(K false)else())
        (Synchronized.value deferred)
      val _=List.app cancel affected
    in affected end;

  fun deferred_live(Deferred{owner,input,intent,child,parents,active,...})=
    owner_live owner andalso Synchronized.value active andalso Inputs.is_live input andalso
    Intent.is_live intent andalso Scope.child_live child andalso
    forall(fn InstalledSource _=>true|KnownSource(_,lease)=>OutputOwner.is_live lease
      |ReservedSource(_,child)=>Scope.child_live child)parents;
  fun deferred_plan(d as Deferred{snapshot,...})=
    (require(deferred_live d) "Deferred native build unavailable";snapshot);
  fun deferred_intent(d as Deferred{intent,...})=
    (require(deferred_live d) "Deferred native build unavailable";intent);
  type deferred_material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
    projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string};
  fun export_deferred image required(deferred as Deferred{input,intent,child,...}):deferred_material=
    let val plan=deferred_plan deferred
      val _=require(member(op =)required(#goal plan,#slot plan)) "Deferred export omits its actual child"
      val binding=Inputs.binding input val descriptor=Intent.binding intent
      fun source owner={id=P.source_identity owner,encoding=L.encoding(P.source_input owner),
        bytes=L.bytes(P.source_input owner)}
      val image_bytes=Veri7vn_Native_Recovery_Check.context_closure image
      val family=Veri7vn_Native_Recovery_Source.encode{image=image_bytes,
        sources=map source[#theory_source binding,#source descriptor]}
      val executable=Veri7vn_Native_Recovery_Pin.material B.executable
      val context=Veri7vn_Native_Scope_Envelope.encode{
        saved=Scope.snapshot(Scope.parent child)required,required=required,image=image_bytes,
        executable=executable,receiver=Veri7vn_Native_Scope_Envelope.Boot,family=family}
      val projection=Veri7vn_Native_Deferred_Build_Codec.encode plan
      val reconstruction="veri7vn-deferred-build-source/1"
      fun digest bytes=Message_Digest.rep(SHA256.digest bytes)
      val manifest=Veri7vn_Recovery_Manifest.encode{profile=Veri7vn_Recovery_Manifest.BuildRequest,
        workspace= #workspace plan,association= #slot plan,semantic_generation= #operation_generation plan,
        projection=digest projection,sequent=digest "",context_closure=digest context,
        payload=digest reconstruction,reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,
        executable=SOME(Veri7vn_Native_Recovery_Pin.digest B.executable)}
    in {association= #slot plan,semantic_generation= #operation_generation plan,manifest=manifest,
      projection=projection,sequent="",context_closure=context,reconstruction=reconstruction,
      executable=executable}end;
  fun source_locator(InstalledSource raw)=raw|source_locator(KnownSource(raw,_))=raw|
    source_locator(ReservedSource(raw,_))=raw;
  fun defer_internal target (owner as Owner{configuration,deferred=table,pending_constructions,...}) child input_id input parents selection restored runnable=
    Thread_Attributes.uninterruptible_body(fn restore=>
    let val construction_key=serial()
      val scope=P.construction_scope()
      val roots=Unsynchronized.ref([]:parent_source list)
      val child_root=Unsynchronized.ref(NONE:Scope.child option)
      val kept_children=Unsynchronized.ref([]:Scope.child list)
      val kept_outputs=Unsynchronized.ref([]:output_lease list)
      val kept_candidates=Unsynchronized.ref([]:candidate_lease list)
      val _=Synchronized.change pending_constructions(fn old=>
        (require(length old<512) "Build pending construction bound";
         (construction_key,{scope=scope,parents=kept_candidates,children=kept_children,outputs=kept_outputs})::old))
      val published=Unsynchronized.ref(NONE:deferred option)
      val result=Exn.capture(fn()=>
      let val _=require(owner_live owner andalso Scope.unclaimed child) "Deferred child already claimed"
        val data=Inputs.binding input
        val source=Scope.source child
        val _=require(L.same_input(L.owner source,L.owner(#theory_slice data)) andalso
          L.offsets source=L.offsets(#theory_slice data)) "Deferred child captured original mismatch"
        val header=restore(fn()=>Thy_Header.read Position.none(L.original source))()
        val _=require(map #1(#imports header)=map source_locator parents andalso
          not(null parents) andalso length parents<=64 andalso
          length(distinct(op =)(map source_locator parents))=length parents)
          "Deferred exact ordered source import mismatch"
        val identity=Scope.identity child
        val {allocator,template,profile,setup,operation,code_generation,capability,step,
          operation_generation,installed_parents,roots=registry}=configuration
        val semantic=case I.lookup_generation_id allocator operation_generation of SOME id=>id
          |NONE=>error "Deferred operation generation is not registered"
        val n=case restored of NONE=>{request= #request identity,goal= #goal identity,slot= #slot identity,
          interpretation= #interpretation identity,decision= #decision identity,
          parameter=I.allocate allocator,candidate=I.allocate allocator,execution=I.allocate allocator,
          capability=capability,step=step,operation=operation,code_generation=code_generation,
          semantic_generation=semantic}:names
        |SOME(p:T.plan)=>
          (require(#workspace p=I.workspace allocator andalso #request p= #request identity andalso
            #goal p= #goal identity andalso #slot p= #slot identity andalso
            #interpretation p= #interpretation identity andalso #decision p= #decision identity andalso
            #template p=template andalso #profile p=profile andalso #setup p=setup andalso
            #capability p=capability andalso #operation p=operation andalso #code_generation p=code_generation andalso
            #operation_generation p=semantic andalso #step p=step) "Restored deferred control installation mismatch";
           {request= #request p,goal= #goal p,slot= #slot p,interpretation= #interpretation p,
            decision= #decision p,parameter= #parameter p,candidate= #candidate p,execution= #execution p,
            capability= #capability p,step= #step p,operation= #operation p,code_generation= #code_generation p,
            semantic_generation= #operation_generation p})
        fun predecessor previous=require(Scope.same_parent(Scope.parent child,Scope.parent previous) andalso
          exists(fn approved=>Scope.same_child(previous,approved))(Scope.predecessors child))
          "Deferred parent is not a same-request owned predecessor"
        fun keep(InstalledSource raw)=
              (require(is_some(AList.lookup(op =)installed_parents raw)) "Deferred import is not installed";
               InstalledSource raw)
          |keep(KnownSource(raw,lease))=
              let val candidate=OutputOwner.candidate lease val plan=B.execution_plan candidate
                val _=require(#request plan= #request identity andalso exists(fn previous=>
                  #slot(Scope.identity previous)= #slot plan)(Scope.predecessors child))
                  "Deferred known parent is not a same-request predecessor"
              in let val root=OutputOwner.retain lease val _=kept_outputs:=root:: !kept_outputs
              in KnownSource(raw,root)end end
          |keep(ReservedSource(raw,previous))=
              (predecessor previous;let val root=Scope.retain_child previous
                val _=kept_children:=root:: !kept_children in ReservedSource(raw,root)end)
        val kept=map(fn parent=>let val root=keep parent in roots:=root:: !roots;root end)parents
        val owned_input=Inputs.retain_owned scope input
        val intent=Inputs.intent_owned scope owned_input
        val owned_child=Scope.retain_child child val _=child_root:=SOME owned_child
        val _=kept_children:=owned_child:: !kept_children
        val descriptor=Intent.binding intent val descriptor_span=L.offsets(#slice descriptor)
        val span=L.offsets source
        fun view(InstalledSource raw)=T.Installed{locator=raw,
              root=Veri7vn_Native_Installed_Roots.resolve_import registry raw}
          |view(KnownSource(raw,lease))=
              let val candidate=OutputOwner.candidate lease
                val native=case I.lookup_generation_id allocator(B.native_generation candidate)of
                  SOME id=>id|NONE=>error "Deferred known parent context is unregistered"
              in T.KnownCandidate{locator=raw,candidate= #candidate(B.projection candidate),
                context=native,slot=OutputOwner.assigned_slot lease}end
          |view(ReservedSource(raw,previous))=
              let val original=Scope.source previous val offset=L.offsets original
                val source_id=case I.lookup_input_identity allocator(L.owner original)of
                  SOME id=>id|NONE=>error "Deferred predecessor original source is unregistered"
                val p=Scope.identity previous
              in T.ReservedOutput{locator=raw,goal= #goal p,slot= #slot p,
                source_owner=source_id,start= #start offset,stop= #stop offset}end
        val parent_views=map view kept
        val _=require(#parents(#metadata data)=map_filter(fn T.KnownCandidate{candidate,...}=>SOME candidate|_=>NONE)parent_views)
          "Deferred known parents differ from original captured input association"
        val dependencies=distinct(op =)([P.source_identity(#theory_source data),
          P.source_identity(#source descriptor)] @ maps(fn InstalledSource raw=>
            P.development_dependencies(the(AList.lookup(op =)installed_parents raw))
          |KnownSource(_,lease)=>let val candidate=OutputOwner.candidate lease
            in #candidate(B.projection candidate)::B.retention_dependencies candidate end
          |ReservedSource(_,previous)=>let val p=Scope.identity previous
            in[#goal p,#slot p,the(I.lookup_input_identity allocator(L.owner(Scope.source previous)))]end)kept)
        val calculated={original_input= #metadata data,prepared_input=input_id,workspace=I.workspace allocator,request= #request n,goal= #goal n,slot= #slot n,
          interpretation= #interpretation n,decision= #decision n,parameter= #parameter n,
          candidate= #candidate n,execution= #execution n,template=template,profile=profile,
          setup=setup,capability=capability,operation=operation,code_generation=code_generation,
          operation_generation=semantic,step=step,parents=parent_views,
          exports=(case selection of DevelopmentOnly=>[]|DeclaredTheorems=>Intent.theorem_names intent),
          dependencies=dependencies,source={source_owner=P.source_identity(#theory_source data),
            start= #start span,stop= #stop span,source_revision= #source_revision data,manifest= #manifest data,
            export_intent= #export_intent data,descriptor_source=P.source_identity(#source descriptor),
            descriptor_start= #start descriptor_span,descriptor_stop= #stop descriptor_span}}:T.plan
        val snapshot=case restored of NONE=>calculated|SOME original=>
          (require(#source original= #source calculated andalso #parents original= #parents calculated andalso
            #original_input original= #original_input calculated andalso #prepared_input original=input_id andalso
            #exports original= #exports calculated) "Restored deferred source/parent plan differs";original)
        val deferred=Deferred{owner=owner,input_id=input_id,input=owned_input,intent=intent,
          child=owned_child,names=n,parents=kept,selection=selection,snapshot=snapshot,runnable=runnable,
          active=Synchronized.var "deferred_build_active" true,
          binding=Synchronized.var "deferred_build_bound"{started=false,entry=NONE}}
        val _=Scope.claim child
        val _=published:=SOME deferred
        val _=Synchronized.change table(fn old=>(require(length old<256) "Deferred build count bound";deferred::old))
        val _=target:=SOME deferred
        val _=P.commit_scope scope
        val _=Synchronized.change pending_constructions(AList.delete(op =)construction_key)
      in deferred end)()
      fun release_parent(InstalledSource _)=()|release_parent(KnownSource(_,lease))=OutputOwner.release lease
        |release_parent(ReservedSource(_,previous))=Scope.release_child previous
    in case result of Exn.Res deferred=>deferred|Exn.Exn failure=>
      (Option.app(fn Deferred{names,...}=>Synchronized.change table(filter(fn Deferred{names=other,...}=>
        #slot other<> #slot names)))(!published);target:=NONE;P.abort_scope scope;
       List.app release_parent(!roots);Option.app Scope.release_child(!child_root);
       Synchronized.change pending_constructions(AList.delete(op =)construction_key);Exn.reraise failure)end);
  fun defer_into target owner child input_id parents selection=
    defer_internal target owner child input_id(source_handle owner input_id)parents selection NONE true;
  fun historical_owner(owner as Owner data)(plan:T.plan) operation_generation=
    let val original= #configuration data
      val allocator= #allocator original
      val _=require(#workspace plan=I.workspace allocator andalso
        I.lookup_generation_id allocator operation_generation=SOME(#operation_generation plan) andalso
        Context.eq_thy(Proof_Context.theory_of(Veri7vn_Native_Registry.context operation_generation),
          Proof_Context.theory_of(Veri7vn_Native_Registry.context(#operation_generation original))))
        "Historical operation alias is not the checked original fixed context"
      val configuration={allocator=allocator,template= #template plan,profile= #profile plan,setup= #setup plan,
        operation= #operation plan,code_generation= #code_generation plan,capability= #capability plan,
        step= #step plan,operation_generation=operation_generation,roots= #roots original,
        installed_parents= #installed_parents original}:installation
    in Owner{configuration=configuration,builder=restored_builder owner plan,pool= #pool data,
      entries= #entries data,deferred= #deferred data,groups= #groups data,transfers= #transfers data,
      prepared= #prepared data,finished= #finished data,construction_scopes= #construction_scopes data,
      pending_constructions= #pending_constructions data,open_owner= #open_owner data}end;
  fun restore_deferred_into target owner child input operation_generation known=
    let val plan=case Inputs.restored_plan input of SOME plan=>plan
          |NONE=>error "Build historical restoration requires checked original input"
      fun parent(T.Installed{locator,...})=InstalledSource locator
        |parent(T.KnownCandidate{locator,candidate=id,context,slot})=
            let val lease=case find_first(fn lease=> #candidate(B.projection(OutputOwner.candidate lease))=id)known of
                  SOME lease=>lease|NONE=>error "Restored deferred known parent output missing"
              val candidate=OutputOwner.candidate lease
              val ids=Scope.allocator(Scope.parent child)
              val _=require(OutputOwner.assigned_slot lease=slot andalso
                I.lookup_generation_id ids(B.native_generation candidate)=SOME context)
                "Restored deferred known parent identity differs"
            in KnownSource(locator,lease)end
        |parent(T.ReservedOutput{locator,goal,slot,source_owner,start,stop})=
            let val previous=case find_first(fn previous=>let val i=Scope.identity previous
                in #goal i=goal andalso #slot i=slot end)(Scope.predecessors child)of
                  SOME previous=>previous|NONE=>error "Restored deferred predecessor source missing"
              val source=Scope.source previous val span=L.offsets source
              val ids=Scope.allocator(Scope.parent child)
              val _=require(I.lookup_input_identity ids(L.owner source)=SOME source_owner andalso
                #start span=start andalso #stop span=stop) "Restored deferred predecessor source differs"
            in ReservedSource(locator,previous)end
      val _=require(length known=length(filter(fn T.KnownCandidate _=>true|_=>false)(#parents plan)))
        "Restored deferred exact known parent count"
      val selected= #exports plan
      val selection=if null selected then DevelopmentOnly else DeclaredTheorems
      val historical=historical_owner owner plan operation_generation
    in defer_internal target historical child (#prepared_input plan)input(map parent(#parents plan))
      selection(SOME plan)false end;
  fun bind_deferred_into target (deferred as Deferred{owner,input_id,input,intent,child,names,parents,
      selection,snapshot,binding,runnable,...}) resolved=
    Thread_Attributes.uninterruptible_body(fn restore=>
    let val _=require(deferred_live deferred) "Deferred build source unavailable"
      val _=Synchronized.change binding(fn {started,...}=>
        (require(not started) "Deferred build already bound";{started=true,entry=NONE}))
      val acquired=Unsynchronized.ref([]:candidate_lease list)
      val result=Exn.capture(fn()=>
        let fun known(InstalledSource _)=NONE
              |known(KnownSource(raw,output))=
                  let val root=output_candidate_lease output val _=acquired:=root:: !acquired
                  in SOME(raw,root)end
              |known(ReservedSource(raw,previous))=
                  let val output=case find_first(fn(child,_)=>Scope.same_child(child,previous))resolved of
                      SOME(_,lease)=>lease|NONE=>error "Deferred acknowledged predecessor is missing"
                    val candidate=OutputOwner.candidate output val actual=B.execution_plan candidate
                    val expected=Scope.identity previous
                    val original=Scope.source previous val recipe=B.recipe candidate
                    val _=require(OutputOwner.assigned_slot output= #slot expected andalso
                      #request actual= #request expected andalso #goal actual= #goal expected andalso
                      L.same_input(L.owner original,L.owner(#slice recipe)) andalso
                      L.offsets original=L.offsets(#slice recipe)) "Deferred predecessor output/original association differs"
                    val root=output_candidate_lease output val _=acquired:=root:: !acquired
                  in SOME(raw,root)end
          val _=require(length resolved=length(filter(fn ReservedSource _=>true|_=>false)parents) andalso
            length(distinct(op =)(map(fn(child,_)=> #slot(Scope.identity child))resolved))=length resolved)
            "Deferred exact predecessor output count"
          val authored=map_filter known parents
          val entry=restore(fn()=>prepare_internal target owner child input_id input authored selection
            (SOME names)(SOME intent)(SOME snapshot)runnable)()
          val _=require(B.prepared_exports(prepared entry)= #exports snapshot)
            "Deferred selected export declaration changed"
          val _=Synchronized.change binding(K{started=true,entry=SOME entry})
        in entry end)()
      val _=List.app release(!acquired)
    in Exn.release result end);
  fun release_deferred(Deferred{owner=Owner{deferred,...},input,intent,child,names,parents,active,...})=
    Thread_Attributes.uninterruptible_body(fn _=>
      (Synchronized.change active(K false);
       List.app(fn InstalledSource _=>()|KnownSource(_,lease)=>OutputOwner.release lease
         |ReservedSource(_,previous)=>Scope.release_child previous)parents;
       Intent.release intent;Inputs.release input;Scope.release_child child;
       Synchronized.change deferred(filter(fn Deferred{names=other,...}=> #slot other<> #slot names))));

  datatype transfer_operation=Begin of string | Write of IntInf.int*Inputs.part*int*Bytes.T |
    Finish of IntInf.int | Abort of IntInf.int | Discard of string |
    Accept of string*IntInf.int | Settle of string | Release of IntInf.int;
  datatype transfer_result=TransferReady of IntInf.int | TransferWritten of IntInf.int |
    InputPrepared of IntInf.int | TransferAborted of IntInf.int | NonceDiscarded of string |
    InputAccepted of string*IntInf.int | NonceSettled of string | InputReleased of IntInf.int;
  fun transfer(Owner{transfers,...}) id=case AList.lookup(op =)(Synchronized.value transfers)id of
    SOME value=>value|NONE=>error "Unknown native input transfer";
  fun release_input(Owner{prepared,...}) id=
    (case AList.lookup(op =)(Synchronized.value prepared)id of NONE=>()
    |SOME root=>(Inputs.release root;Synchronized.change prepared(AList.delete(op =)id)));
  fun forget_sources(owner as Owner{prepared,...}) ids=
    List.app(fn(id,input)=>if Inputs.forget_sources input ids then release_input owner id else())
      (Synchronized.value prepared);
  fun release_finished owner ids=List.app(release_input owner)ids;
  fun transfer_operation(owner as Owner{configuration={allocator,...},pool,transfers,prepared,finished,construction_scopes,...}) operation=
    (require(owner_live owner) "Native build owner closed";
    case operation of
      Begin raw=>Thread_Attributes.uninterruptible_body(fn _=>
        let val stage=Inputs.begin_input pool raw
          val id=IntInf.fromInt(Inputs.transfer_key stage)
          val _=Synchronized.change transfers(fn old=>AList.update(op =)(id,stage)old)
        in TransferReady id end)
    |Write(id,part,offset,bytes)=>(Inputs.write(transfer owner id)part offset bytes;TransferWritten id)
    |Finish id=>
        (case AList.lookup(op =)(Synchronized.value finished)id of SOME ready=>
          (ignore(source_handle owner ready);InputPrepared ready)
        |NONE=>let val scope=Thread_Attributes.uninterruptible_body(fn _=>
            let val scope=P.construction_scope()
              val _=Synchronized.change construction_scopes(AList.update(op =)(id,scope))
            in scope end)
          val result=Exn.capture(fn()=>
            let val stage=transfer owner id
              (* At most two stages; finished producer table is independently bounded. *)
              val existing=Synchronized.value prepared
              val _=require(length existing<64) "Native prepared input count bound"
              val input=Inputs.finish_owned scope stage
              val metadata= #metadata(Inputs.binding input)
              fun bytes(_,input)=let val m= #metadata(Inputs.binding input)
                in #descriptor_size m + #theory_size m end
              val retained=fold(fn value=>fn total=>bytes value+total)existing 0
              val _=require(retained + #descriptor_size metadata + #theory_size metadata<=16000000)
                "Native prepared original source byte bound"
            in Thread_Attributes.uninterruptible_body(fn _=>
              let val ready=I.allocate allocator
                val _=Synchronized.change prepared(fn old=>(require(length old<64)
                  "Native prepared input count bound";(ready,input)::old))
                val _=Synchronized.change finished(AList.update(op =)(id,ready))
                val _=P.commit_scope scope
                val _=Synchronized.change construction_scopes(AList.delete(op =)id)
              in InputPrepared ready end)end)()
        in case result of Exn.Res value=>value|Exn.Exn failure=>
          (P.abort_scope scope;Synchronized.change construction_scopes(AList.delete(op =)id);
           Inputs.discard(transfer owner id);Exn.reraise failure)end)
    |Abort id=>(Option.app Inputs.abort(AList.lookup(op =)(Synchronized.value transfers)id);TransferAborted id)
    |Discard nonce=>
        let val stage_ids=map #1(filter(fn(_,stage)=> #upload_nonce(Inputs.transfer_metadata stage)=nonce)
            (Synchronized.value transfers))
          val _=List.app(fn id=>case AList.lookup(op =)(Synchronized.value construction_scopes)id of
            NONE=>()|SOME scope=>(P.abort_scope scope;
              Synchronized.change construction_scopes(AList.delete(op =)id)))stage_ids
          val _=Inputs.discard_nonce pool nonce
          val stale=filter(fn(_,input)=>not(Inputs.is_live input))(Synchronized.value prepared)
          val _=List.app(fn(id,_)=>release_input owner id)stale
        in NonceDiscarded nonce end
    |Accept(nonce,id)=>
        let val expected=source_handle owner id
          val _=require(#upload_nonce(#metadata(Inputs.binding expected))=nonce)
            "Native prepared input belongs to another upload nonce"
          val actual=Inputs.accept_nonce pool nonce
          val _=require(Inputs.owner_key actual=Inputs.owner_key expected)
            "Native prepared input acceptance differs from correlated producer"
        in InputAccepted(nonce,id)end
    |Settle nonce=>
        let val retired=map #1(filter(fn(_,stage)=> #upload_nonce(Inputs.transfer_metadata stage)=nonce)
            (Synchronized.value transfers))
          val _=Inputs.settle_nonce pool nonce
          val _=Synchronized.change transfers(filter(fn(id,_)=>not(member(op =)retired id)))
          val _=Synchronized.change finished(filter(fn(id,_)=>not(member(op =)retired id)))
        in NonceSettled nonce end
    |Release id=>(release_input owner id;InputReleased id));
  fun decimal text=case IntInf.fromString text of SOME value=>
      (require(value>0 andalso size text<=128 andalso IntInf.toString value=text)
        "Native build identity decimal";value)
    |NONE=>error "Native build identity decimal";
  fun offset text=case Int.fromString text of SOME value=>
      (require(value>=0 andalso Int.toString value=text) "Native build transfer offset";value)
    |NONE=>error "Native build transfer offset";
  fun decode_transfer command payload artifacts=
    let fun no_artifacts()=require(null artifacts) "Unexpected native build transfer artifact"
      fun one()=case artifacts of[bytes]=>bytes|_=>error "Native build transfer artifact count"
    in case command of
      "build_input_begin"=>(require(payload="") "Native build begin payload";Begin(Bytes.content(one())))
    |"build_input_write"=>(case space_explode "," payload of[id,role,start]=>
        Write(decimal id,(case role of "descriptor"=>Inputs.Descriptor|"theory"=>Inputs.Theory
          |_=>error "Native build transfer part"),offset start,one())
        |_=>error "Native build write payload")
    |"build_input_finish"=>(no_artifacts();Finish(decimal payload))
    |"build_input_abort"=>(no_artifacts();Abort(decimal payload))
    |"build_input_release"=>(no_artifacts();Release(decimal payload))
    |"build_input_discard"=>(no_artifacts();Discard payload)
    |"build_input_settle"=>(no_artifacts();Settle payload)
    |"build_input_accept"=>(no_artifacts();case space_explode "," payload of
        [nonce,id]=>Accept(nonce,decimal id)|_=>error "Native build acceptance payload")
    |_=>error "Unknown native build transfer operation"end;
  fun transfer_reply result=case result of
      TransferReady id=>("build_input_ready",IntInf.toString id)
    |TransferWritten id=>("build_input_written",IntInf.toString id)
    |InputPrepared id=>("build_input_prepared",IntInf.toString id)
    |TransferAborted id=>("build_input_aborted",IntInf.toString id)
    |NonceDiscarded nonce=>("build_input_discarded",nonce)
    |InputAccepted(nonce,id)=>("build_input_accepted",nonce^","^IntInf.toString id)
    |NonceSettled nonce=>("build_input_settled",nonce)
    |InputReleased id=>("build_input_released",IntInf.toString id);
  fun close(owner as Owner{open_owner,entries,groups,deferred,prepared,pool,construction_scopes,pending_constructions,...})=
    let val _=Synchronized.change open_owner(K false)
      val _=List.app(fn Group{state,...}=>Synchronized.change state(fn {acknowledged,refs,...}=>
        {active=false,acknowledged=acknowledged,refs=refs}))(Synchronized.value groups)
      val _=List.app release_deferred(Synchronized.value deferred)
      val current=Synchronized.value entries
      val _=List.app cancel current
      val _=List.app release_entry current
      val roots=Synchronized.value prepared
      val _=List.app(fn(id,_)=>release_input owner id)roots
      val _=List.app(fn(id,scope)=>(P.abort_scope scope;
        Synchronized.change construction_scopes(AList.delete(op =)id)))
        (Synchronized.value construction_scopes)
      val _=List.app(fn(id,{scope,parents,children,outputs})=>(P.abort_scope scope;
        List.app release(!parents);List.app OutputOwner.release(!outputs);
        List.app Scope.release_child(!children);Synchronized.change pending_constructions(AList.delete(op =)id)))
        (Synchronized.value pending_constructions)
    in Inputs.close pool end;
end;
