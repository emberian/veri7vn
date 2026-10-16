(* Include after Owner, issue_gate_token, launch_cleanup and
   local_build_workspace. Uses the SAME private issuer and native build owner. *)
structure BuildDurable=Veri7vn_Native_Build_Recovery(
  structure Builder=NativeBuild.Builder structure Recovery=DevelopmentRecovery);
structure BuildManifest=Veri7vn_Recovery_Manifest;
structure BuildWire=Veri7vn_Native_Development_Codec;
structure BuildPin=Veri7vn_Native_Recovery_Pin;

fun build_material entry profile (artifact:DevelopmentRecovery.artifacts):recovery_material=
  let
    val metadata=BuildWire.decode_projection(#projection artifact);
    val candidate=profile=BuildManifest.BuildCandidate;
    val BuildResident.Entry{request_view,output_view,...}=entry;
    val _=if candidate then Synchronized.change output_view(K(SOME{
      metadata=metadata,payload=BuildWire.decode_payload(#reconstruction artifact)}))
      else let val packet=Veri7vn_Native_Build_Request_Envelope.decode(#reconstruction artifact)
        in Synchronized.change request_view(K(SOME{metadata=metadata,
          payload=BuildWire.decode_payload(#body packet),request=packet}))end;
    val association=if candidate then #candidate metadata else #slot metadata;
    val context=if candidate then #context_closure artifact else
      let val child=NativeBuild.child(BuildResident.native entry)
      in Veri7vn_Native_Scope_Envelope.encode{
        saved=RequestScope.snapshot(RequestScope.parent child)[(#goal metadata,#slot metadata)],
        required=[(#goal metadata,#slot metadata)],
        image=V.context_closure(boot_image()),executable= #executable artifact,
        receiver=Veri7vn_Native_Scope_Envelope.Boot,family= #context_closure artifact}end;
    fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
    val manifest=BuildManifest.encode{profile=profile,workspace=I.workspace(identity_allocator()),
      association=association,semantic_generation= #semantic_generation metadata,
      projection=digest(#projection artifact),sequent=digest(#sequent artifact),
      context_closure=digest context,payload=digest(#reconstruction artifact),
      reconstruction=BuildManifest.Controlled_Recipe,
      executable=SOME(BuildPin.digest NativeBuild.Builder.executable)};
    val n=BuildResident.names entry;
    val BuildResident.Entry{dependencies,...}=entry;
    val native=if candidate then NativeBuild.Builder.retention_dependencies(BuildResident.candidate entry)
      else NativeBuild.Builder.prepared_parent_dependencies(BuildResident.prepared entry);
    val dependencies=distinct(op =)(association::dependencies @ native @
      [#request n,#goal n,#slot n,#interpretation n,#capability n,#parameter n,
       #semantic_generation n,#code_generation n]);
  in {association=association,semantic_generation= #semantic_generation metadata,
    manifest=manifest,projection= #projection artifact,sequent= #sequent artifact,
    context_closure=context,reconstruction= #reconstruction artifact,
    executable=SOME(#executable artifact),dependencies=dependencies}:recovery_material end;

fun build_request_material entry phase=
  let val {recovery,...}=local_build_workspace()
  in build_material entry Veri7vn_Recovery_Manifest.BuildRequest
    (BuildDurable.request recovery(identity_allocator())
      {control=BuildResident.plan entry,phase=phase}(BuildResident.prepared entry))end;

fun build_command_info event=case event of BuildResident.Execute entry=>
    let val n=BuildResident.names entry;val p=BuildResident.projection entry
    in SOME((space_implode ",")("pure"::map IntInf.toString
      [#execution n,#request n,#slot n,#profile p,#code_generation n,#operation n,#step n,1]))end
  | _=>NONE;
fun build_known_request rid=exists(fn((actual,_,_),_)=>actual=rid)
  (Synchronized.value BuildResident.entries) orelse
  exists(fn((actual,_,_),_)=>actual=rid)(Synchronized.value BuildResident.restored_entries);
fun build_known_managed id=exists(fn(_,entry)=>BuildResident.depends id entry)
  (Synchronized.value BuildResident.entries) orelse
  exists(fn(_,entry)=>BuildResident.restored_depends id entry)(Synchronized.value BuildResident.restored_entries);
fun build_known_capability id=exists(fn(_,entry)=> #capability(BuildResident.names entry)=id)
  (Synchronized.value BuildResident.entries);

fun build_cleanup action invalidations=
  let val(target,removed)=case action of F.Cancel rid=>(rid,[rid])
      |F.Revoke id=>(id,F.invalidation_ids invalidations)
      |F.Forget id=>(id,F.invalidation_ids invalidations)
      |F.RetireCapability id=>(id,[id])|F.RetireSource id=>(id,[id]);
    val owned=map snd(filter(fn(_,entry)=>exists(fn id=>BuildResident.depends id entry)removed)
      (Synchronized.value BuildResident.entries));
    val restored=map snd(filter(fn(_,entry)=>exists(fn id=>BuildResident.restored_depends id entry)removed)
      (Synchronized.value BuildResident.restored_entries));
    (* Monotone native denial precedes joining or destructing workers. Parent
       denial affects siblings only when the actual shared Owner says so. *)
    val _=List.app(fn entry=>
      (NativeBuild.cancel(BuildResident.native entry);
       if Owner.request_unavailable(#request(BuildResident.names entry))then
         RequestScope.deny(RequestScope.parent(NativeBuild.child(BuildResident.native entry)))else()))owned;
    val cancelled=case action of F.Cancel _=>true|_=>false;
    val _=if cancelled then()else(case Synchronized.value build_workspace of NONE=>()
      |SOME{owner,...}=>ignore(NativeBuild.invalidate owner removed));
    val _=List.app BuildResident.deny_restored restored;
    fun release()=
      (List.app(fn entry=>if cancelled andalso BuildResident.acknowledged entry then
          BuildResident.retire_prepared entry else BuildResident.release entry)owned;
       List.app(fn entry=>if cancelled andalso BuildResident.restored_acknowledged entry then()
          else BuildResident.release_restored entry)restored;
       case(action,Synchronized.value build_workspace)of
         (F.Forget _,SOME{owner,...})=>NativeBuild.forget_sources owner removed|_=>());
  in if null owned andalso null restored andalso is_none(Synchronized.value build_workspace)then()
     else launch_cleanup target release end;

fun build_supports entry remaining=
  (case remaining of []=>issue_gate(Build(BuildResident.Parameter entry))NONE
  |id::rest=>let val event=BuildResident.Intrinsic(entry,id,rest)
    in if Owner.registration_present(Build event)then build_supports entry rest
       else issue_gate(Build event)NONE end);
fun build_after_ack_support(BuildResident.Intrinsic(entry,_,remaining))=build_supports entry remaining
  |build_after_ack_support _=error "Native Build support event required";

fun build_current_binding id token=
  (case AList.lookup(op =)(Synchronized.value tokens)token of
    SOME(Build event,_)=>
      (case event of BuildResident.Intrinsic _=>emit id "build_binding_none" token []
      | BuildResident.Parameter _=>emit id "build_binding_none" token []
      | _=>let val _=F.guard(BuildResident.live event) "Native Build gate unavailable"
        val(phase,prepared,rid,gid,slot)=BuildResident.binding event
        val _=F.guard(prepared>0) "Native Build current source producer unavailable"
      in emit id "build_binding"((space_implode ",")[token,phase,IntInf.toString prepared,
          IntInf.toString rid,IntInf.toString gid,IntInf.toString slot])[]end)
  | _=>emit id "build_binding_none" token []);

fun build_start entry sequence=
  let
    val native=BuildResident.native entry;
    val n=BuildResident.names entry;val p=BuildResident.projection entry;
    val version=Owner.current_version();val epoch=Owner.current_epoch();
    val identity={execution= #execution n,slot= #slot n,
      operation={workspace=I.workspace(identity_allocator()),request= #request n,
        profile= #profile p,code_generation= #code_generation n,operation= #operation n,
        step= #step n,cost=1,inputs=BuildResident.inputs entry,owner_version=version,
        epoch=epoch,journal_sequence=sequence,semantic_generation= #semantic_generation n,
        implementation_artifact= #artifact(Veri7vn_Executable_Identity.manifest NativeBuild.Builder.executable)}};
    val ticket_scope=Tickets.begin_scope issuer{owner_version=version,epoch=epoch};
    val started=Exn.capture(fn()=>NativeBuild.start native
      (Tickets.issue_pure ticket_scope identity(BuildResident.prepared entry)))();
    val _=Tickets.close_scope ticket_scope;
    val job=Exn.release started;
    val BuildResident.Entry{candidate,monitor,reason,...}=entry;
    val task=Future.fork(fn()=>
      let val _=NativeBuild.join job
      in case NativeBuild.inspect native of
        NativeBuild.Status{phase=NativeBuild.CandidateBuilt,...}=>
          let val lease=NativeBuild.candidate_lease native
            (* Root the lease before export, including an export failure. *)
            val _=Synchronized.change candidate(K(SOME lease))
            val {recovery,...}=local_build_workspace()
            val material=build_material entry Veri7vn_Recovery_Manifest.BuildCandidate
              (BuildDurable.candidate recovery(identity_allocator())
                (NativeBuild.CandidateOwner.candidate lease))
          in serialized(fn()=>if NativeBuild.live native then
            issue_gate(Build(BuildResident.Artifact entry))(SOME material)else())end
      | NativeBuild.Status{phase=NativeBuild.BuildFailed,...}=>
          (case NativeBuild.observed_failure native reason of NONE=>()
          | SOME failure=>
            let val material=build_request_material entry
              (Veri7vn_Native_Build_Request_Envelope.ObservedFailure failure)
            in serialized(fn()=>if NativeBuild.live native then
              issue_gate(Build(BuildResident.Outcome(entry,failure)))(SOME material)else())end)
      | _=>()end)
  in Synchronized.change monitor(K(SOME task))end;

(* Called only by the parent's durable after_ack branch. No leaf path can
   directly call this hook to create a charge or publish an artifact. *)
fun build_after_ack event commands sequence=
  (case event of
    BuildResident.Intrinsic(e,_,remaining)=>build_supports e remaining
  | BuildResident.Reserve(e as BuildResident.Entry{registrations,...})=>build_supports e registrations
  | BuildResident.Parameter e=>issue_gate(Build(BuildResident.Execute e))NONE
  | BuildResident.Execute e=>
      (F.guard(case commands of [F.PureRun run]=>BuildResident.pure_matches e run|_=>false)
        "Acknowledged Build command differs from charged immutable plan";
       build_start e sequence)
  | BuildResident.Artifact(e as BuildResident.Entry{output,...})=>
      (* The independent output root is installed before publication is visible
         to poll_build or the host can retire its upload producer. *)
      let val lease=NativeBuild.acknowledge_output(BuildResident.native e)
      in Synchronized.change output(K(SOME lease))end
  | BuildResident.Outcome(BuildResident.Entry{failure,...},observed)=>
      Synchronized.change failure(K(SOME observed))
  | BuildResident.RestoredRequest _=>error "Restored Build cannot acknowledge an event"
  | BuildResident.RestoredArtifact _=>error "Restored Build cannot acknowledge an event");

(* The aggregate calls these only after all factories checked the SAME latest
   checkpoint and all I fragments were installed. They retain actual checked
   witnesses before temporary factory roots are drained. Neither starts work. *)
fun build_restore_request_into target checked committed=
  Thread_Attributes.uninterruptible_body(fn _=>
    let
      val _=F.guard(is_none(!target)) "Build restored request target occupied";
      val raw=Veri7vn_Committed_Native_Recovery.materials committed;
      val m=BuildWire.decode_projection(#projection raw);
      val packet=Veri7vn_Native_Build_Request_Envelope.decode(#reconstruction raw);
      val payload=BuildWire.decode_payload(#body packet);
      val binding=DevelopmentRecovery.Request.binding checked;
      val saved=case DevelopmentRecovery.Request.control_plan checked of SOME p=>p
        |NONE=>error "Legacy Build request has no retained original control plan";
      val _=F.guard(Veri7vn_Native_Deferred_Build_Codec.encode saved=
          Veri7vn_Native_Deferred_Build_Codec.encode(#plan packet) andalso
        #request binding= #request m andalso #goal binding= #goal m andalso #slot binding= #slot m andalso
        #source_revision binding= #source_revision m andalso #manifest binding= #manifest m andalso
        P.source_identity(#source binding)= #source_owner m andalso
        F.build_checkpoint_matches(#checkpoint raw)false m payload(SOME packet))
        "Build committed request differs from checked native witness";
      val _=F.guard(case(DevelopmentRecovery.Request.phase checked,#phase packet)of
          (DevelopmentRecovery.Request.Plan,Veri7vn_Native_Build_Request_Envelope.Prepared)=>true
        |(DevelopmentRecovery.Request.ObservedFailure actual,
            Veri7vn_Native_Build_Request_Envelope.ObservedFailure expected)=>
          Veri7vn_Native_Build_Terminal.encode actual=Veri7vn_Native_Build_Terminal.encode expected
        |_=>false) "Build restored terminal phase differs";
      val {owner,...}=local_build_workspace();
      val retained=BuildResident.Requests.restore(NativeBuild.restored_installation owner checked)checked;
      val key=(#request binding,#goal binding,#slot binding);
      val result=BuildResident.Restored{request=retained,key=key,
        request_view={metadata=m,payload=payload,request=packet},
        output=Synchronized.var "restored_build_output" NONE,
        output_view=Synchronized.var "restored_build_output_view" NONE,
        active=Synchronized.var "restored_build_available" true};
      val _=target:=SOME result;
      val _=Synchronized.change BuildResident.restored_entries(fn entries=>
        (F.guard(length entries<8192 andalso is_none(AList.lookup(op =)entries key) andalso
          is_none(BuildResident.lookup key)) "Build duplicate restored child or bound";
         (key,result)::entries));
    in result end);

fun build_restore_output_into restored checked_request checked_candidate committed=
  Thread_Attributes.uninterruptible_body(fn _=>
    let val BuildResident.Restored{request,output,output_view,...}=restored;
      val _=F.guard(is_none(Synchronized.value output)) "Build restored output already owned";
      val current=BuildResident.Requests.binding request;
      val expected=DevelopmentRecovery.Request.binding checked_request;
      val _=F.guard((#request current,#goal current,#slot current)=
        (#request expected,#goal expected,#slot expected) andalso
        Literals.same_input(P.source_input(#source current),P.source_input(#source expected)))
        "Build artifact restoration has a different original request";
      val raw=Veri7vn_Committed_Native_Recovery.materials committed;
      val m=BuildWire.decode_projection(#projection raw);
      val payload=BuildWire.decode_payload(#reconstruction raw);
      val binding=DevelopmentRecovery.Candidate.binding checked_candidate;
      val _=F.guard(#candidate m= #candidate binding andalso
        (#request m,#goal m,#slot m)=BuildResident.restored_key restored andalso
        F.build_checkpoint_matches(#checkpoint raw)true m payload NONE)
        "Build artifact material differs from checked native candidate";
      val {owner,...}=local_build_workspace();
      val root=Unsynchronized.ref NONE;
      val lease=NativeBuild.restore_output_into root owner checked_request checked_candidate;
      (* Publish the independent owning lease before exposing ArtifactReady. *)
      val _=Synchronized.change output(K(SOME lease));
      val _=Synchronized.change output_view(K(SOME{metadata=m,payload=payload}));
    in ()end);

fun propose_build id payload=
  let
    val prepared_id=decimal payload;
    val {owner,...}=local_build_workspace();
    val binding=NativeBuild.input_binding owner prepared_id;
    val parent=RequestScope.new_parent{allocator=identity_allocator(),policy=boot_policy,
      observation=RequestScope.StateTimeUnused,
      inputs=[P.source_input(#theory_source binding),P.source_input(#descriptor_source binding)]};
    val child_root=Unsynchronized.ref(NONE:RequestScope.child option);
    val native_root=Unsynchronized.ref(NONE:NativeBuild.entry option);
    val resident_root=Unsynchronized.ref(NONE:BuildResident.entry option);
    fun construct()=
      let
        val _=F.guard(null(#parents(#metadata binding)))
          "First Build proposal requires no authored candidate parents";
        val child=RequestScope.new_child parent{source= #theory_slice binding,predecessors=[]};
        val _=child_root:=SOME child;
        val native=NativeBuild.prepare_into native_root owner child prepared_id [];
        val _=RequestScope.seal parent[child];
        val prepared=NativeBuild.prepared native;
        val names=NativeBuild.names native;
        val reason=I.allocate(identity_allocator());
        val p=NativeBuild.Builder.prepared_projection prepared;
        val deps=distinct(op =)([#template p,#profile p,#setup p,#operation names,
          #capability names,#step names,#semantic_generation names,#code_generation names] @
          NativeBuild.Builder.prepared_parent_dependencies prepared);
        (* Failure reasons are inert outcome labels, not managed resources.
           Registering this preallocated label would create an unauthenticated
           support row before any terminal observation exists. *)
        val ids=distinct(op =)(#interpretation names:: #capability names::deps);
        val entry=BuildResident.Entry{native=native,prestate=Owner.current_revision(),
          dependencies=deps,registrations=ids,reason=reason,
          candidate=Synchronized.var "build_resident_candidate" NONE,
          output=Synchronized.var "build_resident_output" NONE,
          failure=Synchronized.var "build_resident_committed_failure" NONE,
          request_view=Synchronized.var "build_resident_request_view" NONE,
          output_view=Synchronized.var "build_resident_output_view" NONE,
          monitor=Synchronized.var "build_resident_monitor" NONE};
        val _=resident_root:=SOME entry;
        (* This validates the full bounded recipe, including reserved terminal
           headroom, before any reservation token exists. *)
        val material=build_request_material entry Veri7vn_Native_Build_Request_Envelope.Prepared;
        val _=BuildResident.publish entry;
        val _=issue_gate(Build(BuildResident.Reserve entry))(SOME material);
        val _=RequestScope.release_child child;
        val _=RequestScope.release_parent parent;
      in emit id "build_proposed"((space_implode ",")(map IntInf.toString
        [#request names,#goal names,#slot names]))[]end;
    val result=Exn.capture construct();
  in case result of Exn.Res()=>() | Exn.Exn failure=>
    (case !resident_root of SOME entry=>BuildResident.release entry
      | NONE=>Option.app NativeBuild.release_entry(!native_root);
     Option.app RequestScope.release_child(!child_root);
     RequestScope.release_parent parent;Exn.reraise failure)end;

fun poll_build id payload=
  let val key=case space_explode "," payload of [rid,gid,slot]=>
        (decimal rid,decimal gid,decimal slot)|_=>error "Build poll requires exact child tuple"
    fun fresh entry=
      let val native=BuildResident.native entry
        val BuildResident.Entry{output,failure,...}=entry
      in if BuildResident.acknowledged entry then
        let val {metadata,...}=BuildResident.expected_output(BuildResident.Artifact entry)
          val producer=case NativeBuild.inspect native of NativeBuild.Status view=> #prepared_input view
            |NativeBuild.Unavailable=>0
        in("artifact_ready",producer,#source_revision metadata,#manifest metadata,#candidate metadata,NONE)end
      else case NativeBuild.inspect native of NativeBuild.Unavailable=>("cancelled",0,0,0,0,NONE)
      | NativeBuild.Status view=>
        let val acknowledged=case Synchronized.value output of
            SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false
          val state=case #phase view of NativeBuild.Prepared=>"queued"
            | NativeBuild.Executing=>"running"|NativeBuild.CandidateBuilt=>"pending_publication"
            | NativeBuild.ArtifactReady=>if acknowledged then "artifact_ready"else "pending_publication"
            | NativeBuild.BuildFailed=>if is_some(Synchronized.value failure)
                then "failed"else "pending_publication"
            | NativeBuild.BuildRefused=>"cancelled"
          val diagnostic=if state="failed" then Option.map NativeBuild.terminal_failure_packet
            (Synchronized.value failure)else NONE
          val candidate=if acknowledged then the_default 0(#candidate view)else 0
        in(state,#prepared_input view,#source_revision view,#manifest view,candidate,diagnostic)end
      end;
    fun historical(r as BuildResident.Restored{request,output,...})=
      if not(BuildResident.restored_live r) andalso not(BuildResident.restored_acknowledged r)
      then("cancelled",0,0,0,0,NONE)else
      let val BuildResident.Restored{request_view={metadata,...},...}=r
        val candidate=case Synchronized.value output of SOME lease=>
            if NativeBuild.OutputOwner.is_live lease then
              SOME(#candidate(NativeBuild.Builder.projection(NativeBuild.OutputOwner.candidate lease)))else NONE
          |NONE=>NONE
        val(state,diagnostic)=case candidate of SOME _=>("artifact_ready",NONE)
          |NONE=>(case BuildResident.Requests.phase request of
              DevelopmentRecovery.Request.Plan=>("historical",NONE)
            |DevelopmentRecovery.Request.ObservedFailure failure=>
              ("failed",SOME(NativeBuild.terminal_failure_packet failure)))
      in(state,0,#source_revision metadata,#manifest metadata,the_default 0 candidate,diagnostic)end;
    val(status,prepared,revision,manifest,candidate,diagnostic)=
      case BuildResident.lookup key of SOME entry=>fresh entry
      |NONE=>(case AList.lookup(op =)(Synchronized.value BuildResident.restored_entries)key of
          SOME restored=>historical restored|NONE=>error "Unknown native Build child");
    val(rid,gid,slot)=key
  in emit id "build_result"((space_implode ",")(map IntInf.toString[rid,gid,slot] @ [status] @
    map IntInf.toString[prepared,revision,manifest,candidate]))
    (case diagnostic of NONE=>[]|SOME bytes=>[Bytes.string bytes])end;
