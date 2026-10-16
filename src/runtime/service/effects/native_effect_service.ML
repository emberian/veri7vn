(* Closed native metadata/permit producer. Permission and resource charge remain
   in the generated Owner; the host owns the fixed external worker and its join.
   No event reducer, native issuer, callback registry or restoration of permits. *)
functor Veri7vn_Native_Effect_Service
  (structure Scope:VERI7VN_NATIVE_REQUEST_SCOPE) :>
sig
  datatype operation=Discover|QualifyCounter|InvokeCounter
  type owner type entry
  type names={request:IntInf.int,goal:IntInf.int,interpretation:IntInf.int,
    target:IntInf.int,capability:IntInf.int,profile:IntInf.int,operation:IntInf.int,
    step:IntInf.int,generation:IntInf.int,attempt:IntInf.int,batch:IntInf.int}
  type command={attempt:IntInf.int,request:IntInf.int,target:IntInf.int,
    capability:IntInf.int,sources:IntInf.int list,dependencies:IntInf.int list,
    prestate:IntInf.int,epoch:IntInf.int,cost:{profile:IntInf.int,code_generation:IntInf.int,
      operation:IntInf.int,step:IntInf.int,units:IntInf.int}}
  type receipt={gate:string,incarnation:serial,permit:serial,command:command}
  val create:Veri7vn_Native_Identity_Allocator.allocator->Veri7vn_Native_Admission.policy->owner
  val prepare:owner->operation->Veri7vn_Native_Effect_Inputs.prepared->entry
  val names:entry->names val live:entry->bool val incarnation:entry->serial
  val context:entry->Veri7vn_Managed_Provenance.development
  val generation:entry->Veri7vn_Native_Registry.generation
  val operation:entry->operation
  val input_binding:entry->Veri7vn_Native_Effect_Inputs.binding
  val dependencies:entry->IntInf.int list val sources:entry->IntInf.int list
  val managed_dependencies:entry->IntInf.int list
  val expected:entry->IntInf.int->IntInf.int->command
  val acknowledged_start:entry->string->command->unit
  val consume_start:entry->string->serial->receipt
  val begin_response:entry->Veri7vn_Native_Effect_Responses.pool->string->serial->serial->string->
    Veri7vn_Native_Effect_Responses.metadata->Veri7vn_Native_Effect_Responses.transfer
  val observation_binding:entry->Veri7vn_Native_Effect_Responses.response->
    {command:command,source:Veri7vn_Managed_Provenance.source_owner,
      originals:Veri7vn_Native_Effect_Inputs.binding}
  val cancel:entry->unit val release:entry->unit val close:owner->unit
end =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure N=Veri7vn_Native_Registry;
  structure P=Veri7vn_Managed_Provenance;
  structure Control=Veri7vn_Native_Entry_Control;
  datatype operation=Discover|QualifyCounter|InvokeCounter;
  type names={request:IntInf.int,goal:IntInf.int,interpretation:IntInf.int,
    target:IntInf.int,capability:IntInf.int,profile:IntInf.int,operation:IntInf.int,
    step:IntInf.int,generation:IntInf.int,attempt:IntInf.int,batch:IntInf.int};
  type command={attempt:IntInf.int,request:IntInf.int,target:IntInf.int,
    capability:IntInf.int,sources:IntInf.int list,dependencies:IntInf.int list,
    prestate:IntInf.int,epoch:IntInf.int,cost:{profile:IntInf.int,code_generation:IntInf.int,
      operation:IntInf.int,step:IntInf.int,units:IntInf.int}};
  type receipt={gate:string,incarnation:serial,permit:serial,command:command};
  datatype phase=Prepared|Acknowledged of string*command|Consumed of receipt|Denied;
  datatype owner=Owner of {allocator:I.allocator,policy:Veri7vn_Native_Admission.policy,
    generation:IntInf.int,native_generation:N.generation,context:P.development,active:bool Synchronized.var,entries:entry list Synchronized.var}
  and entry=Entry of {owner:owner,child:Scope.child,parent:Scope.parent,names:names,
    operation:operation,
    binding:Veri7vn_Native_Effect_Inputs.binding,
    sources:IntInf.int list,dependencies:IntInf.int list,configuration:L.input,
    packet:L.input,config_lease:L.lease,control:Control.cell,phase:phase Synchronized.var};
  fun require true _=()|require false text=error text;
  fun create allocator policy=
    let val context=P.public_image allocator policy
      val generation=P.generation context
      val result=Exn.capture(fn()=>Owner{allocator=allocator,policy=policy,
        generation=I.generation_id allocator generation,native_generation=generation,context=context,
        active=Synchronized.var "native_effect_owner" true,
        entries=Synchronized.var "native_effect_entries" []})()
    in case result of Exn.Res owner=>owner|Exn.Exn failure=>(P.release context;Exn.reraise failure)end;
  fun incarnation(Entry{control,...})=Control.incarnation control;
  fun names(Entry{names,...})=names;
  fun operation(Entry{operation,...})=operation;
  fun context(Entry{owner=Owner{context,...},...})=context;
  fun generation entry=P.generation(context entry);
  fun dependencies(Entry{dependencies,...})=dependencies;
  fun sources(Entry{sources,...})=sources;
  fun managed_dependencies(entry as Entry{names=n,dependencies,...})=distinct(op =)
    ([#request n,#goal n,#interpretation n,#target n,#capability n,#profile n,
      #operation n,#step n,#generation n,#attempt n,#batch n]@dependencies);
  fun live(Entry{owner=Owner{active,...},child,configuration,packet,control,binding,...})=
    Synchronized.value active andalso Control.active control andalso Scope.child_live child
    andalso Veri7vn_Native_Effect_Inputs.configuration_live(#configuration_owner binding)
    andalso L.retained configuration andalso L.retained packet;
  fun input_binding(entry as Entry{binding,...})=
    (require(live entry) "Native effect input binding unavailable";binding);
  fun expected(entry as Entry{names=n,sources,dependencies,...}) prestate epoch=
    (require(live entry) "Native effect entry denied";
     {attempt= #attempt n,request= #request n,target= #target n,capability= #capability n,
       sources=sources,dependencies=dependencies,prestate=prestate,epoch=epoch,
       cost={profile= #profile n,code_generation= #generation n,operation= #operation n,
         step= #step n,units=1}}:command);
  fun prepare(owner as Owner{allocator,policy,generation,active,entries,...}) operation prepared =
    Thread_Attributes.uninterruptible_body(fn _=>
    let val binding=Veri7vn_Native_Effect_Inputs.binding prepared
      val configuration=Veri7vn_Managed_Provenance.source_input(#configuration binding)
      val packet=Veri7vn_Managed_Provenance.source_input(#packet binding)
      val original=L.slice packet{start=0,stop=size(L.bytes packet),expected=L.bytes packet}
      val _=require(Veri7vn_Managed_Provenance.source_workspace(#configuration binding)=I.workspace allocator
          andalso Veri7vn_Managed_Provenance.source_workspace(#packet binding)=I.workspace allocator
          andalso Synchronized.value active andalso L.same_input(L.owner original,packet)
          andalso L.original original=L.bytes packet andalso size(L.bytes packet)<=16384
          andalso size(L.bytes configuration)<=16384) "Native effect original/configuration association";
      val parent=Scope.new_parent{allocator=allocator,policy=policy,
        observation=Scope.StateTimeUnused,inputs=[packet,configuration]};
      val child_slot=Unsynchronized.ref(NONE:Scope.child option);
      val config_slot=Unsynchronized.ref(NONE:L.lease option);
      val result=Exn.capture(fn()=>
        let val child=Scope.new_child parent{source=original,predecessors=[]};
          val _=child_slot:=SOME child;
          val config_lease=L.retain configuration;
          val _=config_slot:=SOME config_lease;
          val identity=Scope.identity child;
          val _=Scope.claim child;
          val _=Scope.seal parent[child];
          val n={request= #request identity,goal= #goal identity,interpretation= #interpretation identity,
            target=I.allocate allocator,capability=I.allocate allocator,profile=I.allocate allocator,
            operation=I.allocate allocator,step=I.allocate allocator,generation=generation,
            attempt=I.allocate allocator,batch=I.allocate allocator}:names;
          val config=I.input_identity allocator configuration;
          val packet_id=I.input_identity allocator packet;
          val entry=Entry{owner=owner,child=child,parent=parent,names=n,operation=operation,binding=binding,sources=[config],
            dependencies=[packet_id,config],configuration=configuration,packet=packet,
            config_lease=config_lease,control=Control.create true,
            phase=Synchronized.var "native_effect_start" Prepared};
          val _=Synchronized.change entries(fn previous=>
            (require(Synchronized.value active andalso length previous<256)
              "Native effect owner denied or full";entry::previous));
        in entry end)();
    in case result of Exn.Res entry=>entry|Exn.Exn failure=>
      (Option.app(fn lease=>Option.app I.release_disposed_input(L.release lease))(!config_slot);
       Option.app Scope.release_child(!child_slot);Scope.release_parent parent;Exn.reraise failure)end);
  fun acknowledged_start(entry as Entry{phase,...}) gate (command:command)=
    Synchronized.change phase(fn previous=>
      (require(live entry andalso size gate>0 andalso size gate<=256)
        "Native effect acknowledgement association unavailable";
       require(command=expected entry (#prestate command)(#epoch command))
         "Acknowledged ClaimStart differs from native original";
       case previous of Prepared=>Acknowledged(gate,command)
       | _=>error "Native effect start already acknowledged/consumed/denied"));
  fun consume_start(entry as Entry{phase,...}) gate serial_id=
    Synchronized.change_result phase(fn previous=>
      (require(live entry andalso serial_id=incarnation entry) "Native effect entry incarnation unavailable";
       case previous of Acknowledged(saved,command)=>
         (require(gate=saved) "Native effect gate token mismatch";
          let val receipt={gate=saved,incarnation=serial_id,permit=serial(),command=command}:receipt
          in(receipt,Consumed receipt)end)
       | _=>error "Native effect start permit unavailable"));
  (* A consumed native origin authorizes only this inert upload association.
     Generated current-context admission and durable ack remain the parent gate. *)
  fun begin_response(entry as Entry{phase,binding,...}) pool gate incarnation_id permit_id nonce data=
    Synchronized.change_result phase(fn previous=>
      (require(live entry) "Native effect response origin denied";
       case previous of Consumed receipt=>
         (require(#gate receipt=gate andalso #incarnation receipt=incarnation_id andalso
            #permit receipt=permit_id) "Native effect response consumed origin mismatch";
          (Veri7vn_Native_Effect_Responses.begin_response pool binding
            {gate=gate,incarnation=incarnation_id,permit=permit_id} nonce data,previous))
       | _=>error "Native effect response requires actual consumed start"));
  fun observation_binding(entry as Entry{phase,binding,...}) response=
    let val _=require(live entry) "Native effect observation context denied"
      val receipt=case Synchronized.value phase of Consumed receipt=>receipt
        |_=>error "Native effect observation without consumed start"
      val origin=Veri7vn_Native_Effect_Responses.origin response
      val originals=Veri7vn_Native_Effect_Responses.originals response
      val _=require(origin={gate= #gate receipt,incarnation= #incarnation receipt,permit= #permit receipt}
        andalso L.same_input(Veri7vn_Managed_Provenance.source_input(#configuration binding),
          Veri7vn_Managed_Provenance.source_input(#configuration originals))
        andalso L.same_input(Veri7vn_Managed_Provenance.source_input(#packet binding),
          Veri7vn_Managed_Provenance.source_input(#packet originals)))
        "Native effect observation differs from actual consumed original"
    in{command= #command receipt,source=Veri7vn_Native_Effect_Responses.source response,
      originals=originals}end;
  fun cancel(Entry{control,phase,...})=
    (Control.deny control;Synchronized.change phase(K Denied));
  fun release(entry as Entry{control,child,parent,config_lease,...})=
    if Control.released control then () else
      (cancel entry;Scope.release_child child;Scope.release_parent parent;
       Option.app I.release_disposed_input(L.release config_lease);Control.mark_released control);
  fun close(Owner{context,active,entries,...})=
    (Synchronized.change active(K false);List.app release(Synchronized.value entries);
     Synchronized.change entries(K []);P.release context);
end;
