signature VERI7VN_NATIVE_SERVICE =
sig
  (* There is no frame/projection/callback constructor for this ingress. *)
  val boot_image: unit -> Veri7vn_Native_Recovery_Check.image
  val public_development: unit -> Veri7vn_Managed_Provenance.development
  val identity_allocator: unit -> Veri7vn_Native_Identity_Allocator.allocator
  val issue_admitted: Veri7vn_Native_Authority_Descriptor.descriptor -> unit
  val release_admitted: Veri7vn_Native_Authority_Descriptor.descriptor -> unit
  (* Fixed trusted-ML diagnostics only; never a resident protocol operation. *)
  structure Test_Only:
  sig
    datatype fault = BeforeExport | BeforeIssue
    val check_proposal_cleanup: fault -> unit
    val check_rpc_ownership: unit -> unit
    val check_cleanup_ownership: unit -> unit
    val check_pending_alias_cleanup: unit -> unit
  end
end;
structure Veri7vn_Native_Service :> VERI7VN_NATIVE_SERVICE =
struct
structure F = Veri7vn_Metadata_Frame;
structure D = Veri7vn_Native_Authority_Descriptor;
structure I = Veri7vn_Native_Identity_Allocator;
structure V = Veri7vn_Native_Recovery_Check;
structure P = Veri7vn_Managed_Provenance;
structure A = Veri7vn_Native_Admission;
val boot_policy=Veri7vn_Native_Admission.policy @{theory};
val boot = Synchronized.var "veri7vn_native_boot_image" (NONE: (string * V.image) option);
fun boot_image ()=(case Synchronized.value boot of SOME (_,image)=>image
  | NONE=>error "Native deployment image not installed");
fun install_boot bytes =
  (F.guard (size bytes>0 andalso size bytes<=1048576) "Native boot manifest bound";
   Synchronized.change boot (fn previous=>case previous of
     SOME (old,image)=>if bytes=old then SOME (old,image) else error "Native boot image cannot be rebound"
   | NONE=>SOME (bytes,V.install_host_image boot_policy bytes)));

val identity_block = Synchronized.var "veri7vn_service_identity_block" (NONE: I.allocator option);
fun identity_allocator () = (case Synchronized.value identity_block of
  SOME value => value | NONE => error "Durable host identity block not installed");
fun install_ids payload =
  (case space_explode "," payload of
    [workspace, first, past] =>
      let
        fun decimal value = (F.guard (size value > 0 andalso size value <= 128 andalso
          String.sub (value, 0) <> #"0" andalso forall Char.isDigit (String.explode value))
          "invalid durable identity decimal"; the (IntInf.fromString value));
        val _ = (case Synchronized.value identity_block of
          NONE => () | SOME previous => F.guard (I.workspace previous = workspace)
            "resident native workspace mismatch");
        val allocator = I.install_host_block {workspace=workspace,
          first=decimal first, past=decimal past};
      in Synchronized.change identity_block (K (SOME allocator)) end
  | _ => error "invalid durable identity block shape");
val coordinator = Synchronized.var "veri7vn_native_service_coordinator" ();
fun serialized f = Synchronized.change_result coordinator (fn () => (f (), ()));
val native_poisoned=Synchronized.var "veri7vn_native_incarnation_poisoned" false;
structure Request=Veri7vn_Interpreted_Request;
structure Language=Veri7vn_Native_Language_Input;
structure Mathematics=Veri7vn_Mathematics_Execution;
structure MathGate=Veri7vn_Native_Math_Gate;
structure MathRecovery=Veri7vn_Native_Math_Recovery;
structure Display=Veri7vn_Refined_Math_Display;
structure RecoveryInputs=Veri7vn_Native_Recovery_Inputs;
structure Control=Veri7vn_Native_Entry_Control;
structure RequestScope=Veri7vn_Native_Request_Scope;
val math_workspace_owners=Synchronized.var "veri7vn_private_math_workspace_owners"
  ([]:MathRecovery.workspace_owner list);
structure Literals=Veri7vn_Native_Literals;
structure Tickets=Veri7vn_Private_Operation_Tickets ();
structure MathWorker=Veri7vn_Math_Ticket_Execution_Fn
  (structure Mathematics=Mathematics structure Tickets=Tickets);
val issuer=Tickets.new_issuer ();
structure DevelopmentRecovery=Veri7vn_Native_Development_Recovery
  (structure Checkpoint=struct
    fun matches committed metadata payload request=
      let val material=Veri7vn_Committed_Native_Recovery.materials committed;
        val manifest=Veri7vn_Recovery_Manifest.decode{max_bytes=8192}(#manifest material);
      in case #profile manifest of
        Veri7vn_Recovery_Manifest.BuildCandidate=>
          F.build_checkpoint_matches(#checkpoint material)true metadata payload request
      | Veri7vn_Recovery_Manifest.BuildRequest=>
          F.build_checkpoint_matches(#checkpoint material)false metadata payload request
      | _=>false end
  end
   val executable=Veri7vn_Native_Build_Image.executable);
structure NativeBuild=Veri7vn_Native_Build_Service
  (structure Tickets=Tickets structure Recovery=DevelopmentRecovery.Candidate
   structure Request=DevelopmentRecovery.Request structure Scope=RequestScope);
type recovery_material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
  projection:string,sequent:string,context_closure:string,reconstruction:string,
  executable:string option,dependencies:IntInf.int list};
type math_history={witness:MathGate.witness,material:recovery_material,
  request:IntInf.int,goal:IntInf.int,slot:IntInf.int,semantic:IntInf.int,bridge:IntInf.int,
  dependencies:IntInf.int list,names:Request.projection,bridge_names:Display.bridge_projection};
val math_history=Synchronized.var "veri7vn_retained_math_evidence_roots" ([]:(IntInf.int*math_history)list);
val math_output_materials=Synchronized.var "veri7vn_prepared_math_evidence_capsules"
  ([]:(IntInf.int*recovery_material)list);
fun math_history_owns witness=is_some(AList.lookup(op =)(Synchronized.value math_history)(MathGate.evidence witness));
fun captured_math_history witness material:math_history=
  let val p=Request.project(MathGate.request witness);
    val bridge=Display.project_bridge(MathGate.rendering_bridge witness)
  in {witness=witness,material=material,request= #request_id p,goal= #goal_id p,slot= #output_slot_id p,
    semantic= #semantic_generation p,bridge= #bridge_id bridge,dependencies=MathGate.managed_dependencies witness,
    names=p,bridge_names=bridge}end;
datatype math_entry=MathEntry of {request:Request.request,input:Literals.input,bridge:Display.bridge,
  execution:IntInf.int,cost:IntInf.int,dependencies:IntInf.int list,
  observed:IntInf.int list Synchronized.var,control:Control.cell,
  job:MathWorker.job option Synchronized.var,monitor:unit Future.future option Synchronized.var,
  witness:MathGate.witness option Synchronized.var,
  failure:string option Synchronized.var};
val math_requests=Synchronized.var "veri7vn_native_math_requests" ([]:((IntInf.int*IntInf.int*IntInf.int)*math_entry) list);
fun entry_request (MathEntry {request,...})=request;
fun entry_native_live (MathEntry {request,bridge,cost,...})=
  Request.retained_live request andalso Display.bridge_matches bridge(Request.instance request) andalso
  (case Mathematics.modeled_cost(Request.family_request request) of
    Mathematics.Ready actual=>actual=cost andalso
      Veri7vn_Executable_Identity.same(Request.executable request,Mathematics.executable())
  | _=>false) handle ERROR _=>false;
fun entry_bridge(MathEntry {bridge,...})=bridge;
fun entry_prerequisites entry=distinct(op =)(Request.native_prerequisites(entry_request entry) @
  Display.managed_dependencies(entry_bridge entry));
fun request_id entry= #request_id(Request.project(entry_request entry));
fun entry_key entry=let val p=Request.project(entry_request entry)
  in (#request_id p,#goal_id p,#output_slot_id p)end;
fun lookup_child key=AList.lookup(op =)(Synchronized.value math_requests)key;
fun entry_live (entry as MathEntry {control,...})=Control.active control andalso entry_native_live entry andalso
  (case lookup_child(entry_key entry)of SOME(MathEntry{control=current,...})=>
      Control.incarnation current=Control.incarnation control | NONE=>false);
fun lookup_request id=(case map snd(filter(fn((rid,_,_),_)=>rid=id)(Synchronized.value math_requests))of
    []=>NONE | [entry]=>SOME entry | _=>error "Composite request requires exact goal/slot selection");
fun math_entry id=(case lookup_request id of SOME entry=>entry | NONE=>error "Unknown native request");
fun entry_depends id (MathEntry {witness,dependencies,observed,...})=
  member(op =)(dependencies @ Synchronized.value observed) id orelse
  (case Synchronized.value witness of NONE=>false | SOME w=>
    id=MathGate.evidence w orelse member(op =)(MathGate.dependencies w) id);
(* Lexical include inside the ONE sealed native service, before gate/Owner.
   This table owns native resources. Permission remains exclusively in Owner. *)
structure SearchWorker=Veri7vn_Search_Fn(Tickets);
structure SearchCore=SearchWorker.Search;
structure SearchRequest=Veri7vn_Search_Request_Fn(SearchCore);
structure SearchSource=Veri7vn_Search_Source_Fn
  (structure S=SearchCore structure Q=SearchRequest);
structure SearchGate=Veri7vn_Search_Gate_Fn(SearchRequest);
structure SearchReceiver=Veri7vn_Search_Request_Recovery_Fn
  (structure S=SearchCore structure Q=SearchRequest);
structure SearchCodec=SearchReceiver.Codec;
structure SearchOutput=Veri7vn_Search_Output_Codec_Fn
  (structure S=SearchCore structure Q=SearchRequest structure G=SearchGate);
structure SearchWire=Veri7vn_Search_Protocol_Fn(SearchCore);
structure SearchResident=
struct
  type key=IntInf.int*IntInf.int*IntInf.int;
  datatype roots=Fresh of SearchSource.entry | Recovered of
    {receiver:SearchReceiver.receiver,pscope:P.construction_scope,
     qscope:SearchRequest.construction_scope,instance:SearchCore.instance};
  datatype entry=Entry of {roots:roots,request:SearchRequest.request,
    projection:F.search_projection,names:F.search_control_names,dependencies:IntInf.int list,
    control:Control.cell,phase:SearchCodec.phase Synchronized.var,
    observed:IntInf.int list Synchronized.var,
    job:SearchWorker.job option Synchronized.var,monitor:unit Future.future option Synchronized.var,
    witness:SearchGate.witness option Synchronized.var,proof_scope:P.construction_scope,
    packet:string option Synchronized.var};
  datatype event=Support of entry*IntInf.int*IntInf.int list*bool |
    Parameter of entry | Reserve of entry | Execute of entry |
    Evidence of entry*SearchGate.witness | Publish of entry*SearchGate.witness |
    Stopped of entry*SearchCodec.phase | RestoredRequest of entry |
    RestoredOutput of entry*SearchGate.witness;
  val entries=Synchronized.var "veri7vn_search_native_roots" ([]:(key*entry)list);
  fun projection(Entry{projection,...})=projection;
  fun names(Entry{names,...})=names;
  fun request(Entry{request,...})=request;
  fun dependencies(Entry{dependencies,...})=dependencies;
  fun identity e= #identity(projection e);
  val wire_identity=identity;
  fun key e=let val i=identity e in (#request i,#goal i,#slot i)end;
  fun lookup k=AList.lookup(op =)(Synchronized.value entries)k;
  fun native_live(Entry{request,control,...})=Control.active control andalso SearchRequest.live request;
  fun entry_live(e as Entry{control,...})=native_live e andalso
    (case lookup(key e)of SOME(Entry{control=actual,...})=>
      Control.incarnation actual=Control.incarnation control|NONE=>false);
  fun insert e=Synchronized.change entries(fn old=>
    (F.guard(length old<256 andalso is_none(AList.lookup(op =)old(key e)))
      "Search resident ownership capacity/duplicate child";(key e,e)::old));
  fun event_entry(Support(e,_,_,_))=e|event_entry(Parameter e)=e|
    event_entry(Reserve e)=e|event_entry(Execute e)=e|event_entry(Evidence(e,_))=e|
    event_entry(Publish(e,_))=e|event_entry(Stopped(e,_))=e|
    event_entry(RestoredRequest e)=e|event_entry(RestoredOutput(e,_))=e;
  fun live event=(case event of RestoredRequest e=>native_live e|
      RestoredOutput(e,w)=>native_live e andalso SearchGate.live w|
      _=>entry_live(event_entry event) andalso
        (case event of Evidence(_,w)=>SearchGate.live w|Publish(_,w)=>SearchGate.live w|
          Support(Entry{witness,...},_,_,true)=>
            (case Synchronized.value witness of SOME w=>SearchGate.live w|NONE=>false)|_=>true))
    handle ERROR _=>false;
  fun stop_name(SearchCodec.Stopped{stop,...})=SearchCodec.stop_name stop
    |stop_name _=error "Pending search has no terminal outcome";
  fun frame event revision=
    let val e=event_entry event;val p=projection e;val n=names e;val deps=dependencies e
    in case event of Support(_,id,_,_)=>F.search_intrinsic_frame id|
      Parameter _=>F.search_parameter_frame p n deps|
      Reserve _=>F.search_reserve_frame p n revision(#cost p)deps|
      Execute _=>F.search_execute_frame p n(#cost p)|
      Evidence(_,w)=>F.search_evidence_frame p n deps(#dependencies(SearchGate.project w))|
      Publish(_,w)=>F.search_publish_frame p n deps(#dependencies(SearchGate.project w))|
      Stopped(_,phase)=>F.search_stopped_frame p n(stop_name phase)|
      _=>error "Restored search association is not an event"end;
  fun pure_matches e({execution,request,slot,cost,inputs}:F.pure_run)=
    let val p=projection e;val n=names e;val i=identity e
    in execution= #execution n andalso request= #request i andalso slot= #slot i andalso
      #profile cost= #profile n andalso #code_generation cost= #code n andalso
      #operation cost= #operation n andalso #step cost= #step n andalso
      #units cost= #cost p andalso inputs=[#parameter n]end;
  fun supports(Execute e)[F.PureRun run]=pure_matches e run
    |supports _ commands=null commands;
  fun is_support(Support _)=true|is_support _=false;
  fun phase_view phase={execution=SearchCodec.execution phase,reason=SearchCodec.reason phase,
    stopped=(case phase of SearchCodec.Pending _=>NONE|_=>SOME(stop_name phase))};
  fun expected_request event=
    let val e=event_entry event;val Entry{phase,...}=e;
      val actual=case event of Reserve _=>SearchCodec.Pending NONE|
        Execute _=>SearchCodec.Pending(SOME(#execution(names e)))|
        Stopped(_,stopped)=>stopped|_=>Synchronized.value phase
    in {names=projection e,control=names e,dependencies=dependencies e,phase=phase_view actual}end;
  fun expected_output event=
    let val e=event_entry event;val w=case event of Evidence(_,w)=>w|
      Publish(_,w)=>w|RestoredOutput(_,w)=>w|_=>error "No search proof association"
    in {names=projection e,control=names e,dependencies=dependencies e,
      native= #dependencies(SearchGate.project w)}end;
  fun depends id(e as Entry{observed,...})=
    member(op =)(F.search_control_values(projection e)(names e)@dependencies e@Synchronized.value observed)id;
  fun deny(e as Entry{control,request,...})=(Control.deny control;
    (Option.app(RequestScope.deny o RequestScope.parent)(SearchRequest.native_scope request)
      handle ERROR _=>()));
  fun release(e as Entry{roots,job,monitor,witness,proof_scope,control,packet,...})=
    (Option.app SearchWorker.request_cancel(Synchronized.value job);
     (* The monitor owns W.join's one-shot result. Cancel the actual worker and
        let that monitor finish/drain it; interrupting its join loses ownership. *)
     Option.app(fn task=>ignore(Future.join_result task))
       (Synchronized.value monitor);
     Option.app(fn running=>let val output=SearchWorker.join running
       in SearchWorker.release_output output end)(Synchronized.value job);
     Synchronized.change job(K NONE);Synchronized.change monitor(K NONE);
     Option.app SearchGate.release(Synchronized.value witness);Synchronized.change witness(K NONE);
     P.abort_scope proof_scope;
     (case roots of Fresh source=>SearchSource.release source|
       Recovered{receiver,pscope,qscope,instance}=>
         (SearchRequest.abort_scope qscope;P.abort_scope pscope;SearchCore.release_instance instance;
          SearchReceiver.release receiver));
     Synchronized.change packet(K NONE);Control.mark_released control);
  fun remove_released()=Synchronized.change entries(filter(fn(_,Entry{control,...})=>not(Control.released control)));
  fun retirement_registrations()=
    let fun owned(_,e as Entry{observed,...})=
      let val p=projection e;val n=names e;
        (* The installed public receiver belongs to the resident context owner,
           not to one search. Forget must leave that selected context usable.
           Fresh proof generations belong to this entry's witness only. *)
        val original=filter(fn id=>id<> #receiver p andalso id<> #parameter n andalso id<> #output n)
          (F.search_control_values p n);
        val proof=filter(fn id=>not(member(op =)(dependencies e)id))(Synchronized.value observed)
      in map(fn id=>[F.search_intrinsic_frame id])(original@proof)end
    in distinct(op =)(maps owned(Synchronized.value entries))end;
end;

(* Include once before the resident gate datatype. This table owns native
   handles only; the existing Owner remains the sole authority-state owner. *)
structure BuildResident =
struct
  structure B=NativeBuild.Builder;
  structure Requests=Veri7vn_Native_Build_Request_Restore(
    structure Builder=B structure Request=DevelopmentRecovery.Request);
  type request_view={metadata:Veri7vn_Native_Development_Codec.metadata,
    payload:Veri7vn_Native_Development_Codec.payload,
    request:Veri7vn_Native_Build_Request_Envelope.packet};
  type output_view={metadata:Veri7vn_Native_Development_Codec.metadata,
    payload:Veri7vn_Native_Development_Codec.payload};
  datatype restored=Restored of {request:Requests.restored,key:NativeBuild.key,
    request_view:request_view,output:NativeBuild.OutputOwner.lease option Synchronized.var,
    output_view:output_view option Synchronized.var,active:bool Synchronized.var};
  datatype entry=Entry of {native:NativeBuild.entry,prestate:IntInf.int,
    dependencies:IntInf.int list,registrations:IntInf.int list,reason:IntInf.int,
    candidate:NativeBuild.CandidateOwner.lease option Synchronized.var,
    output:NativeBuild.OutputOwner.lease option Synchronized.var,
    failure:Veri7vn_Native_Build_Terminal.failure option Synchronized.var,
    request_view:request_view option Synchronized.var,
    output_view:output_view option Synchronized.var,
    monitor:unit Future.future option Synchronized.var};
  datatype event=Intrinsic of entry*IntInf.int*IntInf.int list |
    Reserve of entry | Parameter of entry | Execute of entry |
    Artifact of entry | Outcome of entry*Veri7vn_Native_Build_Terminal.failure |
    RestoredRequest of restored | RestoredArtifact of restored;
  val entries=Synchronized.var "veri7vn_resident_builds"
    ([]:(NativeBuild.key*entry)list);
  val restored_entries=Synchronized.var "veri7vn_restored_builds"
    ([]:(NativeBuild.key*restored)list);
  fun native(Entry{native,...})=native;
  fun names entry=NativeBuild.names(native entry);
  fun key entry=NativeBuild.key(native entry);
  fun lookup key=AList.lookup(op =)(Synchronized.value entries)key;
  fun event_entry(Intrinsic(e,_,_))=e | event_entry(Reserve e)=e |
    event_entry(Parameter e)=e | event_entry(Execute e)=e |
    event_entry(Artifact e)=e | event_entry(Outcome(e,_))=e |
    event_entry _=error "Restored Build has no executable entry";
  fun restored_key(Restored{key,...})=key;
  fun restored_live(Restored{request,active,...})=Synchronized.value active andalso Requests.is_live request;
  fun request(RestoredRequest r)= #1(restored_key r)
    |request(RestoredArtifact r)= #1(restored_key r)
    |request event= #request(names(event_entry event));
  fun prepared entry=NativeBuild.prepared(native entry);
  fun projection entry=B.prepared_projection(prepared entry);
  fun required entry=F.build_requirement(projection entry);
  fun inputs entry=B.prepared_inputs(prepared entry);
  fun source_reads entry=let val p=projection entry
    in distinct(op =)(#source_owner p:: #parents p)end;
  fun plan entry=NativeBuild.request_plan(native entry);
  fun candidate(Entry{candidate,...})=case Synchronized.value candidate of
    SOME lease=>NativeBuild.CandidateOwner.candidate lease
    | NONE=>error "Native build has no owned completed candidate";
  fun acknowledged(Entry{output,...})=case Synchronized.value output of
    SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false;
  fun live(RestoredRequest r)=restored_live r
    |live(RestoredArtifact(Restored{output,...}))=
      (case Synchronized.value output of SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false)
    |live(Artifact e)=B.is_live(candidate e) andalso
      (acknowledged e orelse NativeBuild.live(native e))
    |live event=NativeBuild.live(native(event_entry event));
  fun frame(Intrinsic(_,id,_)) _=F.build_intrinsic_frame id
    | frame(Reserve(e as Entry{prestate,dependencies,...})) _=
        F.build_reserve_frame(names e)(required e)prestate 1 dependencies
    | frame(Parameter(e as Entry{prestate,dependencies,...})) _=
        F.build_singleton_parameter_frame(names e)(required e)prestate dependencies
          (B.prepared_parent_dependencies(prepared e))(source_reads e)[]
    | frame(Execute e) _=F.build_execute_frame(names e)(required e)(inputs e)
    | frame(Artifact(e as Entry{prestate,dependencies,...})) _=
        let val output=candidate e
          val generation=I.generation_id(identity_allocator())(P.generation(B.development output))
        in F.build_singleton_artifact_frame(names e)(required e)prestate dependencies
          generation(B.retention_dependencies output)(inputs e)[] end
    | frame(Outcome(e,failure)) _=F.build_outcome_frame(names e)(#reason failure)
    | frame _ _=error "Restored Build association is not an event";
  fun pure_matches e ({execution,request,slot,cost,inputs=actual}:F.pure_run)=
    let val n=names e;val p=projection e
    in execution= #execution n andalso request= #request n andalso slot= #slot n andalso
      #profile cost= #profile p andalso #code_generation cost= #code_generation n andalso
      #operation cost= #operation n andalso #step cost= #step n andalso #units cost=1 andalso
      actual=inputs e end;
  fun supports(Execute e)[F.PureRun run]=pure_matches e run
    | supports(Execute _) _=false
    | supports _ commands=null commands;
  fun binding event=
    let val e=event_entry event;val n=names e
      val prepared_id=case NativeBuild.inspect(native e)of
        NativeBuild.Status view=> #prepared_input view | NativeBuild.Unavailable=>0
      val phase=case event of Reserve _=>"reserve" | Execute _=>"execute" |
        Artifact _=>"artifact" | Outcome _=>"outcome" | _=>"reserve"
    in (phase,prepared_id,#request n,#goal n,#slot n)end;
  fun publish entry=Synchronized.change entries(fn all=>
    (F.guard(length all<8192 andalso is_none(AList.lookup(op =)all(key entry)))
       "Native Build request ownership bound or duplicate";
     (key entry,entry)::all));
  fun depends id(e as Entry{dependencies,registrations,output_view,...})=
    let val n=names e
      val completed=case Synchronized.value output_view of NONE=>[]
        |SOME{metadata,...}=> #semantic_generation metadata:: #candidate metadata:: #dependencies metadata
    in member(op =)(completed @ dependencies @ registrations @
      [#request n,#goal n,#slot n,#interpretation n,#decision n,#parameter n,
       #candidate n,#execution n,#capability n,#step n,#operation n,
       #code_generation n,#semantic_generation n])id end;
  fun is_support(Intrinsic _)=true|is_support _=false;
  fun restored_depends id(Restored{request_view={metadata,request,...},output_view,...})=
    let val p= #plan request
      val output_dependencies=case Synchronized.value output_view of
        NONE=>[]|SOME{metadata,...}=> #candidate metadata:: #semantic_generation metadata:: #dependencies metadata
    in member(op =)(output_dependencies @ #dependencies metadata @
      [#request p,#goal p,#slot p,#interpretation p,#decision p,#parameter p,#candidate p,
       #execution p,#template p,#profile p,#setup p,#capability p,#operation p,
       #code_generation p,#operation_generation p,#step p])id end;
  fun deny_restored(Restored{active,...})=Synchronized.change active(K false);
  fun restored_acknowledged(Restored{output,...})=case Synchronized.value output of
    SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false;
  fun expected_request(RestoredRequest(Restored{request_view,...}))=request_view
    |expected_request(RestoredArtifact(Restored{request_view,...}))=request_view
    |expected_request event=
    let val Entry{request_view,...}=event_entry event
    in case Synchronized.value request_view of SOME view=>view
      |NONE=>error "Native Build request material not prepared"end;
  fun expected_output(RestoredArtifact(Restored{output_view,...}))=
      (case Synchronized.value output_view of SOME view=>view
        |NONE=>error "Restored Build output material unavailable")
    |expected_output event=
    let val Entry{output_view,...}=event_entry event
    in case Synchronized.value output_view of SOME view=>view
      |NONE=>error "Native Build artifact material not prepared"end;
  (* Keep the table association until every destructor succeeds, so failed
     cleanup still has a retryable owning root. Joins run outside Owner. *)
  fun release(entry as Entry{native,candidate,output,monitor,...})=
    let val _=NativeBuild.cancel native
      val _=Option.app(fn task=>ignore(Future.join_result task))(Synchronized.value monitor)
      val _=Option.app NativeBuild.OutputOwner.release(Synchronized.value output)
      val _=Synchronized.change output(K NONE)
      val _=Option.app NativeBuild.CandidateOwner.release(Synchronized.value candidate)
      val _=Synchronized.change candidate(K NONE)
      val _=NativeBuild.release_entry native
    in Synchronized.change entries(AList.delete(op =)(key entry))end;
  fun retire_prepared(Entry{native,monitor,...})=
    (NativeBuild.cancel native;
     Option.app(fn task=>ignore(Future.join_result task))(Synchronized.value monitor);
     NativeBuild.release_entry native);
  fun release_restored(r as Restored{request,output,...})=
    let val _=deny_restored r
      val _=Option.app NativeBuild.OutputOwner.release(Synchronized.value output)
      val _=Synchronized.change output(K NONE)
      val _=Requests.release request
    in Synchronized.change restored_entries(AList.delete(op =)(restored_key r))end;
end;

datatype gate=Admitted of D.descriptor | MathInput of math_entry | MathParameter of math_entry | MathReserve of math_entry |
  MathStatement of math_entry | MathBridge of math_entry |
  MathExecute of math_entry | MathEvidence of math_entry* MathGate.witness |
  MathPublish of math_entry* MathGate.witness | RestoredMath of math_entry |
  RestoredOutput of math_entry*MathGate.witness | RestoredMathHistory of MathGate.witness | Build of BuildResident.event | Search of SearchResident.event | Lifecycle of F.lifecycle;
fun gate_live (Admitted d)=D.is_live d
  | gate_live (MathInput e)=entry_live e
  | gate_live (MathParameter e)=entry_live e
  | gate_live (MathReserve e)=entry_live e
  | gate_live (MathStatement e)=entry_live e
  | gate_live (MathBridge e)=entry_live e
  | gate_live (MathExecute e)=entry_live e andalso Request.execution_allowed(entry_request e)
  | gate_live (MathEvidence(e,w))=entry_live e andalso MathGate.live w
  | gate_live (MathPublish(e,w))=entry_live e andalso MathGate.live w
  | gate_live (RestoredMath e)=entry_native_live e
  | gate_live (RestoredOutput(_,w))=MathGate.live w
  | gate_live (RestoredMathHistory w)=MathGate.live w
  | gate_live (Build event)=BuildResident.live event
  | gate_live (Search event)=SearchResident.live event
  | gate_live (Lifecycle _)=true;
fun gate_frame (Admitted d) _=D.event_frame d
  | gate_frame (MathInput e) _=F.math_input_frame (Request.project(entry_request e))
  | gate_frame (MathParameter e) _=F.math_parameter_frame (Request.project(entry_request e))
      (Request.managed_dependencies(entry_request e))
  | gate_frame (MathStatement e) _=F.math_statement_frame(Request.project(entry_request e))
      (Display.project_bridge(entry_bridge e))
  | gate_frame (MathBridge e) _=F.math_bridge_frame(Request.project(entry_request e))
      (Display.project_bridge(entry_bridge e))
  | gate_frame (MathReserve (e as MathEntry {cost,...})) revision=
      F.math_reserve_frame (Request.project(entry_request e)) revision cost
        (entry_prerequisites e)
  | gate_frame (MathExecute (e as MathEntry {execution,cost,...})) _=
      F.math_execute_frame (Request.project(entry_request e)) execution cost
  | gate_frame (MathEvidence(_,w)) _=MathGate.evidence_frame w
  | gate_frame (MathPublish(_,w)) _=MathGate.publication_frame w
  | gate_frame (RestoredMath _) _=error "Restoration association is not an event"
  | gate_frame (RestoredOutput _) _=error "Restoration association is not an event"
  | gate_frame (RestoredMathHistory _) _=error "Historical verification is not an event"
  | gate_frame (Build event) revision=BuildResident.frame event revision
  | gate_frame (Search event) revision=SearchResident.frame event revision
  | gate_frame (Lifecycle action) _=F.lifecycle_frame action;
fun pure_command_matches (MathEntry {request,execution,cost,...})
    ({execution=actual,request=rid,slot,cost=charge,inputs}:F.pure_run) =
  let val p=Request.project request
  in actual=execution andalso rid= #request_id p andalso slot= #output_slot_id p andalso
    #profile charge= #profile_id p andalso #code_generation charge= #executable_generation p andalso
    #operation charge= #operation_id p andalso #step charge= #step_id p andalso
    #units charge=cost andalso inputs=[#parameter_id p] end;
fun supports (MathExecute e) [F.PureRun run]=pure_command_matches e run
  | supports (Lifecycle (F.Cancel rid)) [F.StopRequest actual]=rid=actual
  | supports (Lifecycle _) commands=forall (fn F.RemoveManaged _=>true |
      F.AuthorityChanged _=>true | _=>false) commands
  | supports (Build event) commands=BuildResident.supports event commands
  | supports (Search event) commands=SearchResident.supports event commands
  | supports _ commands=null commands;
fun recovery_view (Admitted descriptor)=F.KernelAssociation(D.event_frame descriptor)
  | recovery_view(MathReserve(entry as MathEntry {request,bridge,cost,...}))=F.MathRequestAssociation
      {names=Request.project request,dependencies=entry_prerequisites entry,
        managed=Request.managed_dependencies request,bridge=Display.project_bridge bridge,cost=cost}
  | recovery_view(MathEvidence(_,witness))=F.MathOutputAssociation
      {evidence=MathGate.evidence_frame witness,publication=MathGate.publication_frame witness}
  | recovery_view(RestoredMath(entry as MathEntry {request,bridge,cost,...}))=F.MathRequestAssociation
      {names=Request.project request,dependencies=entry_prerequisites entry,
        managed=Request.managed_dependencies request,bridge=Display.project_bridge bridge,cost=cost}
  | recovery_view(RestoredOutput(_,witness))=F.MathOutputAssociation
      {evidence=MathGate.evidence_frame witness,publication=MathGate.publication_frame witness}
  | recovery_view(RestoredMathHistory witness)=
      let val request=MathGate.request witness;val bridge=MathGate.rendering_bridge witness;
        val cost=case Mathematics.modeled_cost(Request.family_request request)of Mathematics.Ready cost=>cost
          |_=>error "Historical fixed mathematics cost unavailable"
      in F.MathHistoricalOutputAssociation{request={names=Request.project request,
          dependencies=distinct(op =)(Request.native_prerequisites request @ Display.managed_dependencies bridge),
          managed=Request.managed_dependencies request,bridge=Display.project_bridge bridge,cost=cost},
        evidence=MathGate.evidence_frame witness,publication=MathGate.publication_frame witness}end
  | recovery_view(Build event)=(case event of
      BuildResident.Reserve _=>F.BuildRequestAssociation(BuildResident.expected_request event)
    | BuildResident.Execute _=>F.BuildRequestAssociation(BuildResident.expected_request event)
    | BuildResident.Outcome _=>F.BuildRequestAssociation(BuildResident.expected_request event)
    | BuildResident.RestoredRequest _=>F.BuildRequestAssociation(BuildResident.expected_request event)
    | BuildResident.Artifact _=>F.BuildOutputAssociation(BuildResident.expected_output event)
    | BuildResident.RestoredArtifact _=>F.BuildOutputAssociation(BuildResident.expected_output event)
    | _=>F.NoAssociation)
  | recovery_view(Search event)=(case event of
      SearchResident.Reserve _=>F.SearchRequestAssociation(SearchResident.expected_request event)
    | SearchResident.Execute _=>F.SearchRequestAssociation(SearchResident.expected_request event)
    | SearchResident.Stopped _=>F.SearchRequestAssociation(SearchResident.expected_request event)
    | SearchResident.RestoredRequest _=>F.SearchRequestAssociation(SearchResident.expected_request event)
    | SearchResident.Evidence _=>F.SearchOutputAssociation(SearchResident.expected_output event)
    | SearchResident.RestoredOutput _=>F.SearchOutputAssociation(SearchResident.expected_output event)
    | _=>F.NoAssociation)
  | recovery_view _=F.NoAssociation;
structure SupportGroups=Table(type key=IntInf.int*IntInf.int
  val ord=prod_ord IntInf.compare IntInf.compare);
fun retirement_registrations (Lifecycle (F.Forget _)) =
    let fun add key group (seen,groups)=
          if SupportGroups.defined seen key then (seen,groups) else
            (SupportGroups.update(key,())seen,group::groups);
      fun collect (_,entry) state=
        let val names=Request.project(entry_request entry);
          val bridge=Display.project_bridge(entry_bridge entry)
        in state |> add (#bridge_id bridge,#statement_code_id bridge)
            [F.math_statement_frame names bridge,F.math_bridge_frame names bridge]
          |> add (#input_identity names,0) [F.math_input_frame names] end;
      fun historical(_,history:math_history) state=
        let val names= #names history;val bridge= #bridge_names history
        in state |> add (#bridge_id bridge,#statement_code_id bridge)
          [F.math_statement_frame names bridge,F.math_bridge_frame names bridge]
          |> add (#input_identity names,0)[F.math_input_frame names]end;
      val (_,groups)=fold historical(Synchronized.value math_history)
        (fold collect (Synchronized.value math_requests)(SupportGroups.empty,[]))
    in rev groups @ SearchResident.retirement_registrations() end
  | retirement_registrations _=[];
structure Owner=Veri7vn_Native_State_Owner (struct
  type event=gate
  val is_live=gate_live
  fun current_expectation _=F.NoCurrentExpectation
  val event_frame=gate_frame
  val supports=supports
  val retirement_registrations=retirement_registrations
  val recovery_view=recovery_view
end);
fun boot_bytes()=(case Synchronized.value boot of SOME(bytes,_)=>bytes
  | NONE=>error "Native boot image unavailable");
fun kernel_material descriptor (m:Veri7vn_Native_Recovery_Export.material):recovery_material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
    projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
    reconstruction= #reconstruction m,executable=NONE,
    dependencies=distinct(op =)(D.evidence_id descriptor::
      Veri7vn_Native_Descriptor.native_object_dependencies(D.native descriptor))};
fun math_material dependencies (m:MathRecovery.material):recovery_material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
    projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
    reconstruction= #reconstruction m,executable=SOME(#executable m),dependencies=distinct(op =)(#association m::dependencies)};
val tokens = Synchronized.var "veri7vn_native_gate_tokens"
  ([]: (string * (gate * recovery_material option)) list);
val associations = Synchronized.var "veri7vn_live_native_associations"
  ([]: (IntInf.int * D.descriptor) list);
val cleanup_precommit=Synchronized.var "veri7vn_cleanup_precommit" (fn()=>());
val pending = Synchronized.var "veri7vn_pending_native_transition"
  (NONE: (string * gate * Owner.candidate) option);
val durable_sequence=Synchronized.var "veri7vn_native_durable_sequence" (0:IntInf.int);
fun emit id tag payload chunks = Output.protocol_message
  [Markup.function "veri7vn_service_v1"]
  ([XML.Text ("1|" ^ id ^ "|" ^ tag ^ "|" ^ payload)] :: map Bytes.contents_blob chunks);
fun issue_gate_token gate material =
  let val _=F.guard(not(Synchronized.value native_poisoned)) "Native incarnation requires restart";
    val _=F.guard(gate_live gate) "Native gate association unavailable";
    val token=serial_string ();
    val _=Synchronized.change tokens (fn entries=>
      (F.guard(length entries<256) "Native gate token limit";(token,(gate,material))::entries));
  in Output.protocol_message [Markup.function "veri7vn_service_token_v1"] [[XML.Text token]];token end;
fun issue_gate gate material=ignore(issue_gate_token gate material);
fun public_development ()=(ignore(boot_image());
  Veri7vn_Managed_Provenance.public_image (identity_allocator()) boot_policy);
type build_workspace={owner:NativeBuild.owner,recovery:DevelopmentRecovery.configuration,
  roots:Veri7vn_Native_Installed_Roots.registry,
  developments:Veri7vn_Managed_Provenance.development list,registrations:IntInf.int list};
val build_workspace=Synchronized.var "veri7vn_fixed_build_workspace" (NONE:build_workspace option);
fun local_build_workspace ()=(case Synchronized.value build_workspace of SOME installed=>installed
  | NONE=>Thread_Attributes.uninterruptible_body(fn _=>
    let
      val allocator=identity_allocator();
      val image=boot_image();
      val scope=P.construction_scope();
      val owned=Unsynchronized.ref(NONE:NativeBuild.owner option);
      val result=Exn.capture(fn()=>
        let
          val main_policy=A.policy @{theory Main};
          val admission_policy=A.policy @{theory Veri7vn_Admission};
          val main_name=Context.theory_name{long=true} @{theory Main};
          val admission_name=Context.theory_name{long=true} @{theory Veri7vn_Admission};
          val roots=Veri7vn_Native_Installed_Roots.capture_setup_with_imports
            {roots=[(main_name,main_policy),(admission_name,admission_policy)],
             imports=[("Main",main_name)],context= @{theory}};
          val main=P.public_image_owned scope allocator main_policy;
          val admission=P.public_image_owned scope allocator admission_policy;
          val operation=P.public_image_owned scope allocator boot_policy;
          val code=P.public_image_owned scope allocator
            (A.policy(Veri7vn_Executable_Identity.code_theory Veri7vn_Native_Build_Image.executable));
          val semantic=I.generation_id allocator(P.generation operation);
          val code_id=I.generation_id allocator(P.generation code);
          val template=I.allocate allocator;val profile=I.allocate allocator;
          val setup=I.allocate allocator;val opcode=I.allocate allocator;
          val capability=I.allocate allocator;val step=I.allocate allocator;
          val installed_parents=(if main_name="Main" then [("Main",main)]
            else [("Main",main),(main_name,main)]) @ [(admission_name,admission)];
          val owner=NativeBuild.create{allocator=allocator,template=template,profile=profile,
            setup=setup,operation=opcode,code_generation=code_id,capability=capability,step=step,
            operation_generation=P.generation operation,roots=roots,
            installed_parents=installed_parents};
          val _=owned:=SOME owner;
          val recovery=DevelopmentRecovery.install{image=image,roots=roots};
          val developments=[main,admission,operation,code];
          val registrations=distinct(op =)([template,profile,setup,opcode,capability,step,semantic,code_id] @
            maps P.development_dependencies developments);
        in {owner=owner,recovery=recovery,roots=roots,developments=developments,
          registrations=registrations}:build_workspace end)();
    in case result of Exn.Res installed=>
        (P.commit_scope scope;Synchronized.change build_workspace(K(SOME installed));installed)
      | Exn.Exn failure=>(Option.app NativeBuild.close(!owned);P.abort_scope scope;Exn.reraise failure)
    end));
fun build_transfer id operation payload artifacts=
  let val {owner,...}=local_build_workspace();
    val command=NativeBuild.decode_transfer operation payload artifacts;
    val result=NativeBuild.transfer_operation owner command;
    val (tag,reply)=NativeBuild.transfer_reply result
  in emit id tag reply [] end;
val local_math=Synchronized.var "veri7vn_native_local_math_policy"
  (NONE:(Request.local_policy*Display.bridge*IntInf.int) option);
fun local_math_policy ()=(case Synchronized.value local_math of SOME(p,b,_) =>(p,b) | NONE=>
  let val _=ignore(boot_image());
    val development=public_development();
    val generation=Veri7vn_Managed_Provenance.generation development;
    val semantic=I.generation_id(identity_allocator())generation;
    val owned_instance=Unsynchronized.ref(NONE:Mathematics.instance option);
    val owned_context=Unsynchronized.ref(NONE:MathRecovery.workspace_owner option);
    val owned_bridge=Unsynchronized.ref(NONE:Display.bridge option);
    fun build()=
      let val pin=Mathematics.executable();
        val instance=(case Mathematics.attach {policy=boot_policy,generation=generation,
            code_context=Veri7vn_Executable_Identity.code_theory pin,
            limits={nodes=20000,depth=2048,work=512,seconds=5}} of
          Mathematics.Ready value=>value | Mathematics.Refused _=>error "Shipped mathematics qualification failed");
        val _=owned_instance:=SOME instance;
        val policy=Request.allow_mathematics (identity_allocator()) pin instance;
        val bridge=Display.attach {allocator=identity_allocator(),policy=boot_policy,generation=generation,
          instance=instance,statement_pin=F.statement_executable()};
        val _=owned_bridge:=SOME bridge;
        val owner=MathRecovery.own_public(identity_allocator()) development instance bridge;
        val _=owned_context:=SOME owner;
        val _=Synchronized.change math_workspace_owners(cons owner);
        val _=Synchronized.change local_math (K(SOME(policy,bridge,semantic)));
      in (policy,bridge) end;
    val result=Exn.capture build()
  in case result of Exn.Res binding=>binding | Exn.Exn failure=>
    (Request.release_dependencies(I.workspace(identity_allocator()))[semantic];
     (case !owned_context of SOME owner=>MathRecovery.release_workspace owner
      | NONE=>(Option.app Display.release_bridge(!owned_bridge);
         (case !owned_instance of SOME instance=>Mathematics.release_instance instance | NONE=>());
          Veri7vn_Managed_Provenance.release development));
     Exn.reraise failure) end);
fun valid_id id = size id > 0 andalso size id <= 18 andalso forall Char.isDigit (String.explode id);
fun decimal text=(F.guard(size text>0 andalso size text<=128 andalso
  forall Char.isDigit(String.explode text) andalso (size text=1 orelse String.sub(text,0)<> #"0"))
  "Native identity control bound";the(IntInf.fromString text));
fun validate token=(case Synchronized.value pending of
  SOME(current,_,candidate)=>token=current andalso Owner.valid candidate | NONE=>false);
fun deny_entry (MathEntry {control,...})=Control.deny control;
fun release_entry (MathEntry {job,monitor,request,witness,input,control,...}) =
  ((case Synchronized.value job of NONE=>() | SOME running=>
      (MathWorker.cancel running;Synchronized.change job(K NONE)));
   (case Synchronized.value monitor of NONE=>() | SOME task=>
      (Future.cancel task;ignore(Future.join_result task);Synchronized.change monitor(K NONE)));
   (case Synchronized.value witness of NONE=>() | SOME value=>
      (if math_history_owns value then()else MathGate.release value;Synchronized.change witness(K NONE)));
   Request.release request;Control.mark_released control);
fun drain_unused_math_contexts()=
  List.app(fn owner=>
    (List.app(fn bridge_id=>
      let val entries=map snd(filter(fn(_,entry)=>
          #bridge_id(Display.project_bridge(entry_bridge entry))=bridge_id)(Synchronized.value math_requests));
        val drained=forall(fn MathEntry {control,...}=>Control.released control)entries andalso
          not(exists(fn(_,history:math_history)=> #bridge history=bridge_id)(Synchronized.value math_history))
      in if drained then MathRecovery.release_installation owner bridge_id else () end)
        (MathRecovery.installation_ids owner);
     List.app(fn semantic=>
      let val entries=map snd(filter(fn (_,entry)=>
          #semantic_generation(Request.project(entry_request entry))=semantic)(Synchronized.value math_requests));
        val drained=forall(fn MathEntry {control,...}=>Control.released control)entries andalso
          not(exists(fn(_,history:math_history)=> #semantic history=semantic)(Synchronized.value math_history))
      in if not drained then () else
        (Request.release_dependencies(I.workspace(identity_allocator()))[semantic];
         MathRecovery.release_context owner semantic;
         Synchronized.change local_math(fn current=>case current of SOME(_,_,actual)=>
           if actual=semantic then NONE else current | NONE=>NONE)) end)(MathRecovery.context_ids owner)))
    (Synchronized.value math_workspace_owners);
datatype cleanup=Cleanup of {release:(unit->unit) option Synchronized.var,
  task:unit Future.future option Synchronized.var};
val cleanups=Synchronized.var "veri7vn_retryable_native_cleanup" ([]:(IntInf.int*cleanup)list);
val max_cleanup_jobs=256;
fun cleanup_state(Cleanup {release,task})=if is_none(Synchronized.value release)then 1 else
  (case Synchronized.value task of NONE=>0 | SOME future=>
    (case Future.peek future of NONE=>0 | SOME(Exn.Res())=>1 | SOME(Exn.Exn _)=>2));
fun pending_cleanups entries=filter(fn(_,job)=>cleanup_state job<>1)entries;
fun cleanup_capacity()=F.guard(length(pending_cleanups(Synchronized.value cleanups))<max_cleanup_jobs)
  "Native cleanup intent capacity; retry outstanding cleanup before lifecycle transition";
val _=Synchronized.change cleanup_precommit(K cleanup_capacity);
fun start_cleanup(Cleanup {release,task})=
  (case Synchronized.value release of NONE=>() | SOME work=>
    let val future=Future.fork(fn()=>
      (work();Synchronized.change release(K NONE)))
    in Synchronized.change task(K(SOME future))end);
fun retain_cleanup target cleanup old=(target,cleanup)::pending_cleanups old;
fun launch_cleanup target work =
  let val cleanup=Cleanup {release=Synchronized.var "veri7vn_cleanup_owned_roots" (SOME work),
      task=Synchronized.var "veri7vn_native_cleanup_task" NONE};
    (* Preserve every admitted intent for this target. Revoke->Forget can overlap
       while the first worker still owns descriptors no longer in associations. *)
    val _=Synchronized.change cleanups(retain_cleanup target cleanup);
  in start_cleanup cleanup end;
fun cleanup_status id payload retry =
  let val target=decimal payload;
    val jobs=map snd(filter(fn(actual,_)=>actual=target)(Synchronized.value cleanups));
    val _=if retry then List.app(fn job=>if cleanup_state job=2 then start_cleanup job else ())jobs else ();
    val states=map cleanup_state jobs;
    val status=if null jobs then "unknown" else if member(op =)states 2 then "failed_retryable"
      else if member(op =)states 0 then "pending" else "complete"
  in emit id "cleanup" status [] end;
fun cleanup_barrier id =
  let val states=map(cleanup_state o snd)(Synchronized.value cleanups);
    val status=if Synchronized.value native_poisoned orelse member(op =)states 2
      then "failed_retryable" else if member(op =)states 0 then "pending" else "complete"
  in emit id "cleanup" status [] end;
fun retry_all_cleanups id =
  (List.app(fn (_,job)=>if cleanup_state job=2 then start_cleanup job else ())
    (Synchronized.value cleanups);
   cleanup_barrier id);
fun implementation_artifact ()=(case Synchronized.value boot of
  SOME(bytes,_)=>Message_Digest.rep(SHA256.digest bytes) | NONE=>error "Boot image unavailable");
(* Lexical include in the ONE native service after Owner, issue_gate_token,
   implementation_artifact and launch_cleanup. Search is the parent gate case.
   Every caller already holds serialized; monitor completions enter it once. *)
val search_context_owner=Synchronized.var "veri7vn_search_public_context"
  (NONE:(P.development*SearchSource.owner)option);
fun local_search_context()=case Synchronized.value search_context_owner of
    SOME(_,owner)=>(F.guard(SearchSource.owner_live owner andalso
      not(Owner.managed_denied(SearchSource.context owner))) "Search installed context retired/denied";owner)
  |NONE=>Thread_Attributes.uninterruptible_body(fn _=>
    let val development=public_development();
      val result=Exn.capture(fn()=>SearchSource.bind_public(identity_allocator())boot_policy development)();
    in case result of Exn.Res owner=>
        (Synchronized.change search_context_owner(K(SOME(development,owner)));owner)
      |Exn.Exn failure=>(P.release development;Exn.reraise failure)end);
fun search_material deps(m:SearchCodec.artifacts):recovery_material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
   projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
   reconstruction= #reconstruction m,executable=SOME(#executable m),
   dependencies=distinct(op =)(#association m::deps)};
fun search_request_material e phase=
  search_material(SearchResident.dependencies e)(SearchCodec.export(boot_image())
    (#context(SearchResident.projection e))(SearchResident.request e)(SearchResident.names e)phase);
fun search_issue_request event phase=
  issue_gate(Search event)(SOME(search_request_material(SearchResident.event_entry event)phase));
fun search_supports e ids=
  case ids of []=>issue_gate(Search(SearchResident.Parameter e))NONE
  |id::rest=>let val event=SearchResident.Support(e,id,rest,false)
    in if Owner.registration_present(Search event)then search_supports e rest
      else issue_gate(Search event)NONE end;
(* Evidence's private certificate is attached to this exact gate, so proof
   support continuation carries that already checked material in one root. *)
val search_output_materials=Synchronized.var "veri7vn_search_output_material_roots"
  ([]:(SearchResident.key*recovery_material)list);
fun search_issue_evidence e=
  let val material=case AList.lookup(op =)(Synchronized.value search_output_materials)(SearchResident.key e)of
        SOME m=>m|NONE=>error "Search source certificate material missing";
    val SearchResident.Entry{witness,...}=e;
    val w=case Synchronized.value witness of SOME w=>w|NONE=>error "Search native proof root missing"
  in issue_gate(Search(SearchResident.Evidence(e,w)))(SOME material)end;
fun search_proof_support e ids=case ids of []=>search_issue_evidence e|
  id::rest=>let val event=SearchResident.Support(e,id,rest,true)
    in if Owner.registration_present(Search event)then search_proof_support e rest
      else issue_gate(Search event)NONE end;
fun search_stopped_packet e phase=case phase of SearchCodec.Pending _=>SearchWire.pending(SearchResident.wire_identity e)|
  SearchCodec.Stopped{stop,diagnostic,progress,...}=>
    (SearchWire.validate_progress progress;
     SearchWire.root(SearchResident.wire_identity e)(SearchCodec.stop_name stop)
       [SearchWire.node "diagnostic"[][XML.Text diagnostic],progress]);
fun search_after_ack_support event=case event of SearchResident.Support(e,_,rest,true)=>search_proof_support e rest|
    SearchResident.Support(e,_,rest,false)=>search_supports e rest|
    _=>error "Search registration continuation requires support event";
fun start_search e sequence=
  let val SearchResident.Entry{request,projection=p,names=n,job,monitor,proof_scope,witness,packet,observed,...}=e;
    val i= #identity p;val instance=SearchRequest.instance request;
    val version=Owner.current_version();val epoch=Owner.current_epoch();
    val identity={execution= #execution n,slot= #slot i,operation={workspace=I.workspace(identity_allocator()),
      request= #request i,profile= #profile n,code_generation= #code n,operation= #operation n,
      step= #step n,cost= #cost p,inputs=[#parameter n],owner_version=version,epoch=epoch,
      journal_sequence=sequence,semantic_generation= #receiver p,implementation_artifact=implementation_artifact()}};
    val scope=Tickets.begin_scope issuer{owner_version=version,epoch=epoch};
    val started=Exn.capture(fn()=>SearchWorker.start(Tickets.issue_pure scope identity
      {instance=instance,request=SearchRequest.prepared request,operation=SearchCore.operation instance,
       executable=SearchRequest.executable request,generation=P.generation(SearchRequest.worker request),
       receiver=P.generation(SearchRequest.receiver request)}))();
    val _=Tickets.close_scope scope;
    fun fail message=
      let val owned=Synchronized.change_result witness(fn previous=>(previous,NONE));
        val _=Option.app SearchGate.release owned;
        val _=P.abort_scope proof_scope;
        val _=Synchronized.change packet(K NONE);
        val _=Synchronized.change search_output_materials(AList.delete(op =)(SearchResident.key e))
      in if SearchResident.entry_live e andalso not(Owner.child_unavailable(SearchResident.key e))then
        let val phase=SearchCodec.failed{execution= #execution n,reason= #failed n,diagnostic=message}
        in search_issue_request(SearchResident.Stopped(e,phase))phase end else ()end;
  in case started of Exn.Exn _=>fail "search.worker_handoff_failed"|Exn.Res running=>
    (Synchronized.change job(K(SOME running));
     let val task=Future.fork(fn()=>
       Thread_Attributes.uninterruptible(fn restore=>fn()=>
       let val output_root=Unsynchronized.ref NONE;
         val gate_root=Unsynchronized.ref NONE;
         fun current()=SearchResident.entry_live e andalso SearchWorker.identity running=identity andalso
           not(Owner.child_unavailable(SearchResident.key e));
         fun complete()=
           let val _=restore(fn()=>output_root:=SOME(SearchWorker.join running))();
             val output=the(!output_root);
             val report=SearchWorker.report output;
             val _=F.guard(SearchWorker.identity running=identity) "Search charged worker association changed";
           in case #outcome report of SearchCore.ProofProposal wire=>
             let val _=restore(fn()=>ignore(SearchGate.reconstruct_into gate_root proof_scope request wire))();
               val w=the(!gate_root);
               val native= #dependencies(SearchGate.project w);
               val export_root=Unsynchronized.ref NONE;
               val _=restore(fn()=>export_root:=SOME(SearchOutput.export(boot_image())n w report))();
               val exported=the(!export_root);
               val material=search_material(SearchResident.dependencies e@native)exported;
               val rendered=SearchWire.proved(SearchResident.wire_identity e)
                 (Veri7vn_Native_Registry.context(P.generation(SearchRequest.receiver request)))
                 {proposition= #bytes(SearchRequest.snapshot request),evidence= #evidence n,
                  semantic= #receiver p,proof_semantic= #proof_semantic(SearchGate.project w),
                  dependencies=distinct(op =)(SearchResident.dependencies e@native)}report
             in serialized(fn()=>if current() andalso SearchGate.live w then
               (Synchronized.change witness(K(SOME w));gate_root:=NONE;
                Synchronized.change observed(K native);
                Synchronized.change packet(K(SOME rendered));
                Synchronized.change search_output_materials(AList.update(op =)(SearchResident.key e,material));
                search_proof_support e native)
               else ())end
           |_=>let val reason=case #outcome report of SearchCore.Exhausted=> #exhausted n|
                 SearchCore.BudgetStop=> #budget n|SearchCore.Deadline=> #deadline n|
                 SearchCore.Cancelled=> #cancelled n|_=>error "Search nonproof outcome";
               val phase=SearchCodec.stopped request{execution= #execution n,reason=reason,
                 diagnostic="search.no_proof_found",report=report}
             in serialized(fn()=>if current()then search_issue_request(SearchResident.Stopped(e,phase))phase else ())end end;
         val outcome=Exn.capture complete();
         val _=Option.app SearchGate.release(!gate_root);
         val _=Option.app SearchWorker.release_output(!output_root);
         val _=if is_none(Synchronized.value witness)then P.abort_scope proof_scope else ();
         val _=serialized(fn()=>
           (Synchronized.change job(K NONE);
            case outcome of Exn.Res()=>()|Exn.Exn _=>fail "search.native_attempt_failed"))
       in ()end)());
     in Synchronized.change monitor(K(SOME task))end)end;
fun search_after_ack event commands sequence=
  let val e=SearchResident.event_entry event;val SearchResident.Entry{phase,packet,...}=e
  in case event of SearchResident.Support _=>search_after_ack_support event|
    SearchResident.Parameter _=>search_issue_request(SearchResident.Reserve e)(SearchCodec.Pending NONE)|
    SearchResident.Reserve _=>search_issue_request(SearchResident.Execute e)
      (SearchCodec.Pending(SOME(#execution(SearchResident.names e))))|
    SearchResident.Execute _=>
      (F.guard(case commands of [F.PureRun run]=>SearchResident.pure_matches e run|_=>false)
        "Search acknowledged command differs from protected worker";
       Synchronized.change phase(K(SearchCodec.Pending(SOME(#execution(SearchResident.names e)))));
       start_search e sequence)|
    SearchResident.Evidence(_,w)=>issue_gate(Search(SearchResident.Publish(e,w)))NONE|
    SearchResident.Publish _=>Synchronized.change search_output_materials(AList.delete(op =)(SearchResident.key e))|
    SearchResident.Stopped(_,stopped)=>
      (Synchronized.change phase(K stopped);Synchronized.change packet(K(SOME(search_stopped_packet e stopped))))|
    _=>error "Restored search association cannot acknowledge event"end;
fun search_contexts id payload=
  let val _=F.guard(payload="") "Search context query payload";
    val owner=case Synchronized.value search_context_owner of SOME(_,owner)=>owner|NONE=>local_search_context();
    val context=SearchSource.context owner;
    val contexts=if SearchSource.owner_live owner andalso not(Owner.managed_denied context)then
      [{id=context,semantic=context,label="Installed native HOL context"}]else []
  in emit id "search_contexts" "1"[Bytes.string(SearchWire.context_list contexts)]end;
fun propose_search id payload bytes=
  let val _=F.guard(payload="") "Search proposal control payload";
    val root=Unsynchronized.ref NONE;val owned=Unsynchronized.ref NONE;
    fun cleanup()=(case !owned of NONE=>Option.app SearchSource.release(!root)|SOME e=>
      (SearchResident.deny e;SearchResident.release e;
       Synchronized.change SearchResident.entries(AList.delete(op =)(SearchResident.key e))));
    val result=Exn.capture(fn()=>
      let val source=SearchSource.prepare_into root(local_search_context())bytes;
        val p=SearchSource.project source;val n=SearchSource.names source;val q=SearchSource.request source;
        val deps=F.search_prerequisites p n(SearchRequest.dependencies q);
        val e=SearchResident.Entry{roots=SearchResident.Fresh source,request=q,projection=p,names=n,dependencies=deps,
          control=Control.create true,phase=Synchronized.var "search_durable_phase"(SearchCodec.Pending NONE),
          observed=Synchronized.var "search_observed_native_dependencies" [],
          job=Synchronized.var "search_job" NONE,monitor=Synchronized.var "search_monitor" NONE,
          witness=Synchronized.var "search_proof_root" NONE,proof_scope=P.construction_scope(),
          packet=Synchronized.var "search_bounded_result" NONE};
        val _=owned:=SOME e;
        (* Export once before publishing ownership, so oversized recovery data
           cannot strand a visible chain of support registrations. *)
        val _=ignore(search_request_material e(SearchCodec.Pending NONE));
        val _=SearchResident.insert e;
        val support=distinct(op =)(filter(fn id=>id<> #parameter n andalso id<> #output n)
          (F.search_control_values p n)@SearchRequest.dependencies q);
        val _=search_supports e support;
        val(rid,gid,slot)=SearchResident.key e
      in emit id "search_proposed"(space_implode ","(map IntInf.toString[rid,gid,slot]))[]end)()
  in case result of Exn.Res()=>()|Exn.Exn failure=>(cleanup();Exn.reraise failure)end;
fun search_key payload=case space_explode "," payload of [rid,gid,slot]=>
    (SearchWire.identity rid,SearchWire.identity gid,SearchWire.identity slot)|_=>error "Search exact child key required";
fun poll_search id payload=
  let val key as(rid,gid,slot)=search_key payload;
    (* Missing/retired keys need only an inert wire reply, never a fabricated
       Scope.identity with invented interpretation or decision associations. *)
    fun absent status diagnostic=SearchWire.document(SearchWire.node "search-result"
      [("version","1"),("request",IntInf.toString rid),("goal",IntInf.toString gid),
       ("slot",IntInf.toString slot),("status",status)]
      [SearchWire.node "diagnostic"[][XML.Text diagnostic],
       SearchWire.node "progress"[("expansions","0"),("trace_total","0"),("remaining_total","0"),
         ("details_truncated","false")][SearchWire.node "trace"[][],SearchWire.node "remaining"[][]]]);
    val result=if Owner.child_unavailable key then absent "cancelled" "search.child_unavailable"
      else case SearchResident.lookup key of NONE=>absent "unavailable" "search.native_owner_unavailable"|
        SOME(e as SearchResident.Entry{phase,packet,witness,...})=>
          let val ids=SearchResident.identity e
          in if not(SearchResident.entry_live e)then SearchWire.failure ids "unavailable" "search.native_owner_unavailable"
          else case Synchronized.value witness of SOME w=>
            if SearchGate.live w andalso Owner.binding_live rid(#evidence(SearchResident.names e))
            then the(Synchronized.value packet)else SearchWire.pending ids|
          NONE=>(case Synchronized.value phase of SearchCodec.Pending _=>
            (case e of SearchResident.Entry{roots=SearchResident.Recovered _,...}=>
              SearchWire.failure ids "unavailable" "search.interrupted_request_not_replayed"|_=>SearchWire.pending ids)|
            stopped=>search_stopped_packet e stopped)end
  in emit id "search_result" payload[Bytes.string result]end;
fun search_requests id payload=
  let val _=F.guard(payload="") "Search retained child query payload";
    val entries=filter(fn(key,e)=>SearchResident.entry_live e andalso Owner.search_child_required key)
      (Synchronized.value SearchResident.entries);
    val values=map(fn(_,e)=>let val p=SearchResident.projection e
      in {identity= #identity p,context= #context p,semantic= #receiver p}end)entries
  in emit id "search_requests" "1"[Bytes.string(SearchWire.requests values)]end;
fun search_command_info event=case event of SearchResident.Execute e=>
    let val n=SearchResident.names e;val p=SearchResident.projection e;val i= #identity p
    in SOME(space_implode ","("pure"::map IntInf.toString
      [#execution n,#request i,#slot i,#profile n,#code n,#operation n,#step n,#cost p]))end|_=>NONE;
fun search_known_request rid=exists(fn((actual,_,_),_)=>actual=rid)(Synchronized.value SearchResident.entries);
fun search_known_managed target=exists(fn(_,e)=>SearchResident.depends target e)(Synchronized.value SearchResident.entries);
fun search_cleanup action invalidations=
  let val(target,removed)=case action of F.Cancel rid=>(rid,[rid])|
      F.Revoke id=>(id,F.invalidation_ids invalidations)|F.Forget id=>(id,F.invalidation_ids invalidations)|
      F.RetireCapability id=>(id,[id])|F.RetireSource id=>(id,[id]);
    val entries=map snd(filter(fn(_,e)=>exists(fn id=>SearchResident.depends id e)removed)
      (Synchronized.value SearchResident.entries));
    val _=List.app SearchResident.deny entries;
    val _=Synchronized.change search_output_materials(filter(fn(key,_)=>not(exists(fn e=>SearchResident.key e=key)entries)));
    fun release()=(List.app SearchResident.release entries;serialized SearchResident.remove_released)
  in if null entries then ()else launch_cleanup target release end;

(* Fixed aggregate recovery handoff. The parent first authenticates the shared
   checkpoint, checks SearchReceiver/Scope material in the SAME V/G batch, seals
   it, and installs ALL identity/source fragments. No worker/ticket/start occurs
   here, including for a saved Pending NONE. target is parent-owned before call;
   only the parent installs the checked RestoredRequest/RestoredOutput in Owner.
   The child must be the actual required child supplied by shared Scope.restore. *)
fun search_restore_request_into target receiver child=
  Thread_Attributes.uninterruptible(fn restore=>fn()=>
  let val _=F.guard(is_none(!target)) "Search restored entry target occupied";
    val retained=Unsynchronized.ref NONE;
    val qscope=SearchRequest.construction_scope();val pscope=P.construction_scope();
    val proof_scope=P.construction_scope();val instance_root=Unsynchronized.ref NONE;
    val entry_root=Unsynchronized.ref NONE;
    fun cleanup()=case !entry_root of SOME e=>SearchResident.release e|NONE=>
      (SearchRequest.abort_scope qscope;P.abort_scope pscope;P.abort_scope proof_scope;
       Option.app SearchCore.release_instance(!instance_root);Option.app SearchReceiver.release(!retained));
    val result=Exn.capture(fn()=>
      let val actual=SearchReceiver.retain_into retained receiver;
        val material=SearchReceiver.inspect actual;
        val {links,names,saved,phase}=SearchCodec.inspect material;
        val _=F.guard(#scope_identity saved=SOME(RequestScope.identity child))
          "Search restored child differs from authenticated original requirement";
        val instance=SearchCore.qualify(#limits saved);val _=instance_root:=SOME instance;
        val facts_root=Unsynchronized.ref NONE;
        val _=restore(fn()=>facts_root:=SOME(SearchReceiver.catalogue pscope actual))();
        val facts=the(!facts_root);
        val development=SearchReceiver.development actual;
        val original=Literals.owner(RequestScope.source child);
        val _=F.guard(I.lookup_input_identity(identity_allocator())original=SOME(#source links))
          "Search original source identity fragments are missing or differ";
        val source=P.install_host_source(identity_allocator())original;
        val request_root=Unsynchronized.ref NONE;
        val _=restore(fn()=>request_root:=SOME(SearchRequest.restore_child_owned qscope instance child saved
          {receiver=development,worker=development,source=source,facts=facts}))();
        val request=the(!request_root);
        val p={identity=RequestScope.identity child,context= #context links,receiver= #receiver links,
          worker= #worker links,input= #source links,cost=SearchRequest.cost request}:F.search_projection;
        val _=F.guard(#cost p= #cost links andalso #receiver p= #worker p)
          "Search restored fixed profile/cost differs from checked original";
        val deps=F.search_prerequisites p names(SearchRequest.dependencies request);
        (* Reconstruction validates the exact recipe, then retires its prepared
           executable input. Old consumed and unstarted lineages never start
           merely because their source and context can be reconstructed. *)
        val _=SearchCore.release(SearchRequest.prepared request);
        val e=SearchResident.Entry{roots=SearchResident.Recovered{receiver=actual,pscope=pscope,
            qscope=qscope,instance=instance},request=request,projection=p,names=names,dependencies=deps,
          control=Control.create true,phase=Synchronized.var "search_restored_phase" phase,
          observed=Synchronized.var "search_restored_native_dependencies" [],
          job=Synchronized.var "search_restored_job" NONE,monitor=Synchronized.var "search_restored_monitor" NONE,
          witness=Synchronized.var "search_restored_proof" NONE,proof_scope=proof_scope,
          packet=Synchronized.var "search_restored_packet" NONE};
        val _=entry_root:=SOME e;
        val _=target:=SOME e
      in e end)()
  in case result of Exn.Res e=>e|Exn.Exn failure=>(cleanup();Exn.reraise failure)end)();
fun search_restored_packet e w progress=
  let val _=SearchWire.validate_progress progress;val native= #dependencies(SearchGate.project w);
    val deps=distinct(op =)(SearchResident.dependencies e@native);val p=SearchResident.projection e;
    val n=SearchResident.names e;
    val proof= #proof_semantic(SearchGate.project w);
    val _=F.guard(length deps<=1024 andalso member(op =)deps(#receiver p)andalso member(op =)deps proof)
      "Search restored licensed proof provenance projection bound"
  in SearchWire.root(SearchResident.identity e)"proved"
    [SearchWire.node "proof"[("evidence",IntInf.toString(#evidence n)),("semantic",IntInf.toString(#receiver p)),
      ("proof_semantic",IntInf.toString proof),("route","kernel_consequence")]
      [SearchWire.node "proposition"[][XML.Text(#bytes(SearchRequest.snapshot(SearchResident.request e)))],
       SearchWire.node "dependencies"[](map(fn id=>SearchWire.node "dependency"[("id",IntInf.toString id)][])deps)],
     progress]end;
fun search_restore_output_into target (e as SearchResident.Entry{request,names,witness,packet,observed,...}) verified=
  Thread_Attributes.uninterruptible_body(fn _=>
  let val _=F.guard(is_none(!target)andalso is_none(Synchronized.value witness)) "Search restored proof target occupied";
    val progress= #progress(SearchOutput.inspect verified);
    val owned=Unsynchronized.ref NONE;
    val result=Exn.capture(fn()=>
      let val w=SearchOutput.restore_into owned request names verified;
        val rendered=search_restored_packet e w progress;
        val _=Synchronized.change witness(K(SOME w));
        val _=Synchronized.change observed(K(#dependencies(SearchGate.project w)));
        val _=Synchronized.change packet(K(SOME rendered));
        val _=target:=SOME w;val _=owned:=NONE
      in w end)()
  in case result of Exn.Res w=>w|Exn.Exn failure=>
    (Synchronized.change witness(K NONE);Synchronized.change packet(K NONE);
     Synchronized.change observed(K []);target:=NONE;
     Option.app SearchGate.release(!owned);Exn.reraise failure)end);
fun search_install_restored e=
  (F.guard(SearchResident.native_live e) "Restored search native roots unavailable";SearchResident.insert e);
val search_retirement_registrations=SearchResident.retirement_registrations;

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

fun prepare id token =
  if is_some(Synchronized.value pending) then emit id "rejected" "pending_transition" [] else
  (case AList.lookup(op =)(Synchronized.value tokens) token of
    NONE=>emit id "rejected" "unknown_native_gate_token" []
  | SOME(gate,_)=>if not(gate_live gate) then
      (Owner.invalidate();Synchronized.change tokens(AList.delete(op =)token);
       emit id "rejected" "native_gate_expired" [])
    else if (case gate of MathStatement _=>Owner.registration_present gate
          | MathBridge _=>Owner.registration_present gate
          | Search event=>SearchResident.is_support event andalso Owner.registration_present gate
          | Build event=>BuildResident.is_support event andalso Owner.registration_present gate | _=>false) then
      (Owner.invalidate();Synchronized.change tokens(AList.delete(op =)token);
       (case gate of MathStatement entry=>
           if Owner.registration_present(MathBridge entry) then issue_gate(MathInput entry)NONE
           else issue_gate(MathBridge entry)NONE
         | MathBridge entry=>issue_gate(MathInput entry)NONE
         | Search event=>search_after_ack_support event
         | Build event=>build_after_ack_support event | _=>());
       emit id "rejected" "native_gate_expired" [])
    else let val _=(case gate of Lifecycle _=>(Synchronized.value cleanup_precommit)() | _=>());
      val candidate=Owner.prepare gate;
      val _=Synchronized.change pending(K(SOME(token,gate,candidate)));
    in emit id "prepared" (token ^ "," ^ IntInf.toString(Owner.revision candidate) ^ "," ^
      IntInf.toString(Owner.epoch candidate))
      [Bytes.string(Owner.event_frame candidate),Bytes.string(Owner.checkpoint candidate)] end);

fun cleanup_action action invalidations =
  let
    val _=search_cleanup action invalidations
    val _=build_cleanup action invalidations
    val (target,removed)=(case action of F.Cancel rid=>(rid,[rid])
      | F.Revoke id=>(id,F.invalidation_ids invalidations) | F.Forget id=>(id,F.invalidation_ids invalidations)
      | F.RetireCapability id=>(id,[id]) | F.RetireSource id=>(id,[id]));
    val entries=map snd (filter(fn (_,entry)=>exists(fn id=>entry_depends id entry)removed)
      (Synchronized.value math_requests));
    val _=List.app deny_entry entries;
    val _=List.app(fn entry=>if Owner.request_unavailable(request_id entry) then
      Option.app (RequestScope.deny o RequestScope.parent)
        (Request.scope_child(entry_request entry)) else ())entries;
    val _=(case action of F.Forget _=>List.app(fn MathEntry {request,input,...}=>
      if member(op =)removed(#input_identity(Request.project request)) then Literals.invalidate input else ())entries
      | _=>());
    fun descriptor_removed descriptor=exists(fn id=>
      id=D.evidence_id descriptor orelse
      member(op =)(Veri7vn_Native_Descriptor.native_object_dependencies(D.native descriptor))id)removed;
    val descriptors=case action of F.Cancel _=>[]|_=>distinct (fn (left,right)=>D.evidence_id left=D.evidence_id right)
      (filter descriptor_removed (map snd (Synchronized.value associations) @
        map_filter(fn (_, (Admitted descriptor,_))=>SOME descriptor | _=>NONE)
          (Synchronized.value tokens)));
    (* Invalid pending aliases own original bytes/recovery exports even though
       they never reached durability. Drop their token material at this ack. *)
    val _=Synchronized.change tokens(filter(fn (_, (gate,_))=>case gate of
      Admitted descriptor=>not(descriptor_removed descriptor) | _=>gate_live gate));
    val _=Synchronized.change associations(filter(fn (_,descriptor)=>not(exists(fn other=>
      D.evidence_id other=D.evidence_id descriptor)descriptors)));
    val historical=case action of F.Cancel _=>[]|_=>filter(fn(id,history:math_history)=>
      member(op =)removed id orelse exists(fn dep=>member(op =)removed dep)(#dependencies history))
      (Synchronized.value math_history);
    fun release_history(id,history:math_history)=
      (MathGate.release(#witness history);Synchronized.change math_history(AList.delete(op =)id));
    val _=Synchronized.change math_output_materials(filter(fn(id,_)=>
      not(exists(fn MathEntry{witness,...}=>case Synchronized.value witness of SOME w=>MathGate.evidence w=id
        |NONE=>false)entries)));
    fun release()=(List.app release_entry entries;List.app release_history historical;List.app D.release descriptors;
      (case action of F.Cancel _=>() | _=>Request.release_dependencies(I.workspace(identity_allocator()))removed);
      serialized(fn()=>
        (drain_unused_math_contexts();
         Synchronized.change math_requests(filter(fn(_,MathEntry{control,...})=>not(Control.released control))))));
  in if target=0 orelse null removed then () else launch_cleanup target release end;
fun start_math entry sequence =
  let
    val _=F.guard(Request.execution_allowed(entry_request entry)) "Restored or cancelled request cannot start execution"; val MathEntry {request,bridge,execution,job,monitor,failure,...}=entry;
    val p=Request.project request;
    val cost=(case Mathematics.modeled_cost(Request.family_request request) of
      Mathematics.Ready n=>n | _=>error "Released prepared mathematics input");
    val version=Owner.current_version(); val epoch=Owner.current_epoch();
    val identity={execution=execution,slot= #output_slot_id p,
      operation={workspace=I.workspace(identity_allocator()),request= #request_id p,
        profile= #profile_id p,code_generation= #executable_generation p,
        operation= #operation_id p,step= #step_id p,cost=cost,inputs=[#parameter_id p],
        owner_version=version,epoch=epoch,journal_sequence=sequence,
        semantic_generation= #semantic_generation p,implementation_artifact=implementation_artifact()}};
    val scope=Tickets.begin_scope issuer {owner_version=version,epoch=epoch};
    val started=Exn.capture (fn()=>MathWorker.start(Tickets.issue_pure scope identity
      {executable=Request.executable request,instance=Request.instance request,
        request=Request.family_request request,operation=Request.family_operation request})) ();
    val _=Tickets.close_scope scope;
  in case started of
    Exn.Res(MathWorker.Ready running)=>
      (Synchronized.change job(K(SOME running));
       let val task=Future.fork(fn()=>
         let fun complete()=
         let
           val result=MathWorker.collect running;
           (* Projection and native substitution may allocate or time out. They
              run outside the owner lock; publication rechecks current authority. *)
           val specialized=Exn.capture (fn()=>case result of
             MathWorker.Ready output=>
               (F.guard(MathWorker.output_identity output=identity)
                  "Worker completion differs from the durably charged native handoff";
                case MathWorker.native_output output of
               MathWorker.Ready raw=>let
                 val witness=MathGate.specialize(identity_allocator()) bridge request execution raw;
                 val exported=Exn.capture(fn()=>math_material (MathGate.managed_dependencies witness)
                   (MathRecovery.export_output (boot_image()) (boot_bytes()) witness))();
               in case exported of Exn.Res material=>SOME(witness,material)
                 | Exn.Exn failure=>(MathGate.release witness;Exn.reraise failure) end
             | _=>NONE)
           | _=>NONE) ();
         in serialized(fn()=>case specialized of
             Exn.Res(SOME(witness,material))=>if entry_live entry andalso MathGate.live witness then
               let val MathEntry {witness=root,observed,...}=entry;
                 val _=Synchronized.change root(K(SOME witness));
                 val _=Synchronized.change observed(K(MathGate.managed_dependencies witness));
                 val _=Synchronized.change math_output_materials(AList.update(op =)(MathGate.evidence witness,material));
               in issue_gate (MathEvidence(entry,witness)) (SOME material) end
               else MathGate.release witness
           | _=>(case result of MathWorker.Ready output=>MathWorker.release_output output | _=>();
               Synchronized.change failure(K(SOME "execution.failure")))) end;
           val completed=Exn.capture complete()
         in case completed of Exn.Res()=>() | Exn.Exn _=>serialized(fn()=>
           let val MathEntry {witness=root,...}=entry;
             val owned=Synchronized.change_result root(fn old=>(old,NONE));
             val _=(case owned of NONE=>() | SOME witness=>
               (Synchronized.change tokens(filter(fn (_, (MathEvidence(_,other),_))=>
                   MathGate.evidence other<>MathGate.evidence witness | _=>true));
                MathGate.release witness));
           in Synchronized.change failure(K(SOME "execution.failure")) end) end)
       in Synchronized.change monitor(K(SOME task)) end)
  | _=>Synchronized.change failure(K(SOME "execution.handoff_rejected")) end;
fun after_ack gate commands sequence invalidations =
  (case gate of
    Admitted d=>Synchronized.change associations(AList.update(op =)(D.evidence_id d,d))
  | Search event=>search_after_ack event commands sequence
  | Build event=>build_after_ack event commands sequence
  | MathInput e=>issue_gate (MathParameter e) NONE
  | MathParameter e=>issue_gate (MathExecute e) NONE
  | MathReserve e=>if not(Owner.registration_present(MathStatement e))
      then issue_gate(MathStatement e)NONE else if not(Owner.registration_present(MathBridge e))
      then issue_gate(MathBridge e)NONE else issue_gate(MathInput e)NONE
  | MathStatement e=>if Owner.registration_present(MathBridge e) then issue_gate(MathInput e)NONE
      else issue_gate(MathBridge e)NONE
  | MathBridge e=>issue_gate(MathInput e)NONE
  | MathExecute e=>(F.guard(case commands of [F.PureRun run]=>pure_command_matches e run | _=>false)
      "Acknowledged command differs from fixed worker";start_math e sequence)
  | MathEvidence(e,w)=>
      let val evidence=MathGate.evidence w;
        val material=case AList.lookup(op =)(Synchronized.value math_output_materials)evidence of
          SOME material=>material|NONE=>error "Acknowledged Math evidence lost its original capsule";
        val history=captured_math_history w material;
        val _=Synchronized.change math_history(AList.update(op =)(evidence,history));
        val _=Synchronized.change math_output_materials(AList.delete(op =)evidence)
      in issue_gate (MathPublish(e,w)) NONE end
  | MathPublish _=>()
  | RestoredMath _=>error "Restored association cannot acknowledge an event"
  | RestoredOutput _=>error "Restored association cannot acknowledge an event"
  | RestoredMathHistory _=>error "Historical verification cannot acknowledge an event"
  | Lifecycle action=>cleanup_action action invalidations);
fun acknowledge_internal id payload =
  (case space_explode "," payload of [token,sequence_text]=>
    if not(validate token) then emit id "rejected" "precommit_mismatch" [] else
    let val sequence=decimal sequence_text;
      val _=F.guard(sequence=Synchronized.value durable_sequence+1) "Durable sequence mismatch";
      val SOME(_,gate,candidate)=Synchronized.value pending;
      (* Installation and actual one-shot fixed-worker handoff share this
         uninterrupted coordinator interval. Long work and joins are outside. *)
      val commands=Owner.acknowledge candidate;
      val _=Synchronized.change durable_sequence(K sequence);
      val _=Synchronized.change pending(K NONE);
      val _=Synchronized.change tokens(AList.delete(op =) token);
      val handoff=Exn.capture(fn()=>after_ack gate commands sequence (Owner.invalidations candidate))();
      val _=(case handoff of Exn.Res()=>() | Exn.Exn failure=>
        (Synchronized.change native_poisoned(K true);Exn.reraise failure));
    in emit id "acknowledged" token [] end
  | _=>emit id "rejected" "acknowledgement_shape" []);
fun acknowledge id payload=Thread_Attributes.uninterruptible(fn _=>fn()=>acknowledge_internal id payload)();
fun gate_request_id (MathInput entry)=SOME(request_id entry)
  | gate_request_id(MathParameter entry)=SOME(request_id entry)
  | gate_request_id(MathReserve entry)=SOME(request_id entry)
  | gate_request_id(MathStatement entry)=SOME(request_id entry)
  | gate_request_id(MathBridge entry)=SOME(request_id entry)
  | gate_request_id(MathExecute entry)=SOME(request_id entry)
  | gate_request_id(MathEvidence(entry,_))=SOME(request_id entry)
  | gate_request_id(MathPublish(entry,_))=SOME(request_id entry)
  | gate_request_id(Search event)=SOME(#request(SearchResident.identity(SearchResident.event_entry event)))
  | gate_request_id(Build event)=SOME(BuildResident.request event)
  | gate_request_id _=NONE;
datatype proposal_fault=BeforeExport | BeforeIssue;
val proposal_fault=Synchronized.var "veri7vn_test_proposal_fault" (NONE:proposal_fault option);
val proposal_probe=Synchronized.var "veri7vn_test_proposal_probe"
  (NONE:{entry:math_entry,instance:Mathematics.instance,
    generation:Veri7vn_Native_Registry.generation} option);
fun proposal_fault_at point entry =
  let val armed=Synchronized.change_result proposal_fault(fn current=>
    if current=SOME point then (true,NONE) else (false,current))
  in if not armed then () else
    let val instance=Request.instance(entry_request entry);
      val generation=Veri7vn_Native_Admission.generation(Mathematics.contract instance)
    in Synchronized.change proposal_probe(K(SOME {entry=entry,instance=instance,generation=generation}));
      error "Injected native proposal failure" end end;
fun discard_new_input input=
  (Literals.invalidate input;Option.app I.release_disposed_input(Literals.drop_base input));
fun propose_math id payload bytes =
  let val _=F.guard(size bytes<=256) "Original request byte bound";
    val selection=if payload="" then NONE else SOME(IntInf.toInt(decimal payload));
    val _=F.guard(case selection of NONE=>true | SOME n=>n<=255) "Interpretation selection bound";
    val input=Literals.input {bytes=bytes,encoding="UTF-8"};
    val prepared=Unsynchronized.ref(NONE:Request.request option);
    val scope=Unsynchronized.ref(NONE:(RequestScope.parent*RequestScope.child)option);
    val local_entry=Unsynchronized.ref(NONE:math_entry option);
    fun cleanup()=
      ((case !local_entry of NONE=>(case !prepared of NONE=>() | SOME request=>Request.release request)
        | SOME entry=>
          let val rid=request_id entry;
            val _=Synchronized.change tokens(filter(fn (_, (gate,_))=>gate_request_id gate<>SOME rid));
            val _=Synchronized.change math_requests(AList.delete(op =)(entry_key entry))
          in release_entry entry end);
       Option.app(fn(parent,child)=>(RequestScope.release_child child;RequestScope.release_parent parent))(!scope);
       discard_new_input input;drain_unused_math_contexts());
    fun run()=
      let val (policy,bridge)=local_math_policy();
        val parent=RequestScope.new_parent{allocator=identity_allocator(),policy=boot_policy,
          observation=RequestScope.StateTimeUnused,inputs=[input]};
        val child=(case Exn.capture(fn()=>RequestScope.new_child parent {source=Literals.slice input
          {start=0,stop=size bytes,expected=bytes},predecessors=[]})()of
            Exn.Res child=>child
          | Exn.Exn failure=>(RequestScope.release_parent parent;Exn.reraise failure));
        val _=scope:=SOME(parent,child)
      in case Request.elaborate_math_child policy child selection of Request.Ready request=>
        let val _=prepared:=SOME request;
          val _=RequestScope.seal parent [child];
          val _=RequestScope.release_child child;
          val _=RequestScope.release_parent parent;
          val _=Option.app I.release_disposed_input(Literals.drop_base input);
          val cost=(case Mathematics.modeled_cost(Request.family_request request) of
            Mathematics.Ready n=>n | _=>error "Native modeled cost unavailable");
          val execution=I.allocate(identity_allocator());
          val entry=MathEntry {request=request,input=input,bridge=bridge,execution=execution,
            cost=cost,dependencies=Request.managed_dependencies request @ Display.managed_dependencies bridge,
            observed=Synchronized.var "veri7vn_request_observed_dependencies" [execution],
            control=Control.create true,
            job=Synchronized.var "veri7vn_request_job" NONE,
            monitor=Synchronized.var "veri7vn_request_monitor" NONE,witness=Synchronized.var "veri7vn_request_witness" NONE,
            failure=Synchronized.var "veri7vn_request_failure" NONE};
          val _=local_entry:=SOME entry;
          (* Qualify retained material before publishing the proposal's native
             ownership roots. Nothing has a durable reservation at this point. *)
          val _=proposal_fault_at BeforeExport entry;
          val material=math_material (Request.managed_dependencies request @ Display.managed_dependencies bridge)
            (MathRecovery.export_request (boot_image()) (boot_bytes()) bridge request);
          val rid=request_id entry;
          val _=Synchronized.change math_requests(fn entries=>
            (F.guard(length entries<8192) "Native request ownership bound";AList.update(op =)(entry_key entry,entry)entries));
          val _=proposal_fault_at BeforeIssue entry;
          val _=issue_gate (MathReserve entry) (SOME material);
        in emit id "proposed" (IntInf.toString rid) [] end
      | Request.NeedsSelection _=>(cleanup();emit id "needs_selection" "interpretation.ambiguous" [])
      | Request.NeedsLiteral _=>(cleanup();emit id "needs_literal" "interpretation.literal" [])
      | Request.Refused _=>(cleanup();emit id "rejected" "interpretation.unrecognized" []) end;
    val result=Exn.capture run()
  in case result of Exn.Res()=>() | Exn.Exn failure=>(cleanup();Exn.reraise failure) end;
structure Proposal_Test_Only =
struct
  datatype fault=datatype proposal_fault;
  fun check_proposal_cleanup point = serialized(fn()=>
    let
      val _=F.guard(null(Synchronized.value math_requests) andalso null(Synchronized.value tokens)
        andalso is_none(Synchronized.value pending) andalso not(Synchronized.value native_poisoned))
        "Proposal diagnostic requires an unused resident";
      val _=(case Synchronized.value boot of NONE=>install_boot "native-service-failure-test/1" | SOME _=>());
      val _=(case Synchronized.value identity_block of NONE=>
          install_ids "c0de0000000000000000000000000003,1000000,1065536" | SOME _=>());
      val version=Owner.current_version();
      val sequence=Synchronized.value durable_sequence;
      val _=Synchronized.change proposal_probe(K NONE);
      val _=Synchronized.change proposal_fault(K(SOME point));
      val outcome=Exn.capture(fn()=>propose_math "0" "" "the sum of -2 and 3")();
      val probe=Synchronized.change_result proposal_probe(fn old=>(old,NONE));
      val armed=Synchronized.change_result proposal_fault(fn old=>(old,NONE));
      val _=F.guard(Exn.is_exn outcome andalso is_none armed andalso is_some probe)
        "Proposal diagnostic did not reach its fixed failure boundary";
      val {entry,instance,generation}=the probe;
      val request=entry_request entry;
      val MathEntry {input,control,job,monitor,witness,...}=entry;
      val _=F.guard(not(Request.live request) andalso not(Literals.retained input) andalso
        Control.released control andalso is_none(Synchronized.value job) andalso
        is_none(Synchronized.value monitor) andalso is_none(Synchronized.value witness))
        "Failed proposal retained an actual request, input or worker owner";
      val _=F.guard(Exn.is_exn(Exn.capture Mathematics.contract instance) andalso
        Exn.is_exn(Exn.capture Display.bridge_contract(entry_bridge entry)) andalso
        is_none(I.lookup_generation_id(identity_allocator())generation))
        "Failed proposal retained an instance or canonical generation owner";
      val _=F.guard(null(Synchronized.value math_requests) andalso null(Synchronized.value tokens)
        andalso is_none(Synchronized.value pending) andalso is_none(Synchronized.value local_math))
        "Failed proposal retained a registered entry, token or local instance policy";
      val _=F.guard(Owner.current_version()=version andalso Synchronized.value durable_sequence=sequence)
        "Undurable proposal failure changed committed authority";
    in () end);
end;
fun result_view (entry as MathEntry {witness,failure,...}) =
  if not(entry_live entry) then ("cancelled",[]) else
    case Synchronized.value witness of
      NONE=>(the_default "pending" (Synchronized.value failure),[])
    | SOME w=>if not(Owner.binding_live (request_id entry) (MathGate.evidence w))
      then ("pending",[]) else
      (case MathGate.display w of
        Veri7vn_Refined_Math_Display.Exact {statement_html,...}=>("accepted_exact",[statement_html])
      | Veri7vn_Refined_Math_Display.Undefined=>("undefined",[])
      | Veri7vn_Refined_Math_Display.Missing _=>("missing_parameters",[])
      | Veri7vn_Refined_Math_Display.Syntax=>("invalid_syntax",[])
      | Veri7vn_Refined_Math_Display.Budget=>("budget",[]));
fun poll_result id payload =
  let val request=decimal payload;
    val (status,artifacts)=(case lookup_request request of SOME entry=>result_view entry
      | NONE=>if Owner.request_unavailable request then ("cancelled",[])
          else error "Unknown native request")
  in emit id "result" status (map Bytes.string artifacts) end;
fun poll_math_goal id payload=(case space_explode "," payload of [rid,gid,slot]=>
  let val key=(decimal rid,decimal gid,decimal slot);
    val (status,artifacts)=(case lookup_child key of SOME entry=>result_view entry
      | NONE=>if Owner.child_unavailable key then ("cancelled",[]) else error "Unknown native goal/slot");
  in emit id "goal_result" (payload ^ ",mathematics," ^ status)(map Bytes.string artifacts)end
  | _=>error "Native goal identity shape");
(* Owner inspection reports actual retained readings and numeric provenance. It
   never serializes ticket authority, private native contexts or source bytes. *)
fun inspect_request id payload =
  let val entry as MathEntry {request,input,execution,control,...}=math_entry(decimal payload);
    val p=Request.project request;
    fun n value=IntInf.toString value;
    fun node name attributes body=XML.Elem((name,attributes),body);
    val identity=node "identity"
      [("request",n(#request_id p)),("goal",n(#goal_id p)),
       ("interpretation",n(#interpretation_id p)),("decision",n(#decision_id p)),
       ("capability",n(#capability_id p)),("operation",n(#operation_id p)),
       ("semantic_generation",n(#semantic_generation p)),
       ("executable_generation",n(#executable_generation p)),("execution",n execution)][];
    val reading=if not(entry_live entry) then node "reading-unavailable"
        [("reason",if Control.released control then "released" else "invalidated")][]
      else if not(Literals.retained input) then node "reading-unavailable" [("reason","not_retained")][]
      else let
        val (operation,_,_,slices)=Language.resolve(Request.reading request);
        val operation=(case operation of Language.Sum=>"sum" | Language.Difference=>"difference"
          | Language.Product=>"product" | Language.Quotient=>"quotient" | Language.SubtractFrom=>"subtract_from");
        fun literal slice=let val {start,stop}=Literals.offsets slice
          in node "literal" [("start",Int.toString start),("stop",Int.toString stop)][] end
      in node "reading" [("index",Int.toString(Request.selected_index request)),
        ("operation",operation),("input_bytes",Int.toString(size(Literals.bytes input)))](map literal slices)end;
    val (status,_)=result_view entry;
    val frame=YXML.string_of_body[node "veri7vn-request-inspection"
      [("version","1"),("status",status),("family","mathematics")][identity,reading]];
    val _=F.guard(size frame<=8192) "Native request inspection frame bound"
  in emit id "request_inspection" (n(#request_id p)) [Bytes.string frame] end;
fun inspect_routing id payload bytes =
  let val _=F.guard(payload="math/1" andalso size bytes<=256) "Native routing policy/input bound";
    val (applicable,budget,alternatives,blocked)=F.interpretation_packet_bytes bytes;
    val status=if budget then "budget" else if not applicable then "unrecognized"
      else if null alternatives then if null blocked then "structure_blocked" else "literal" else "readings";
    val artifacts=if status="readings" then
      [Bytes.string(space_implode "," (map_index(fn(index,_)=>Int.toString index)alternatives))] else []
  in emit id "routing" status artifacts end;
fun growth_suggest id payload bytes =
  let val _=F.guard(payload="numeric/1" andalso size bytes<=8192)
      "Growth proposal profile/input bound";
    val {operations,source,unsupported,...}=Veri7vn_Growth_Proposal_Policy.suggest bytes;
    val _=F.guard(size source<=8192) "Growth proposal source bound";
    fun item name text=XML.Elem((name,[]),[XML.Text text]);
    val body=YXML.string_of_body[XML.Elem(("growth-suggestion",
      [("version","1"),("profile","numeric/1"),("status","tentative")]),
      [XML.Elem(("operations",[]),map(item "operation")operations),
       item "source" source,
       XML.Elem(("unsupported",[]),map(item "word")unsupported)])];
    val _=F.guard(size body<=32768) "Growth proposal response bound";
  in emit id "growth_suggestion" "numeric/1" [Bytes.string body] end;
fun service_capabilities id payload =
  let val _=F.guard(payload="") "Native capability query payload";
    val _=ignore(boot_image());val _=ignore(identity_allocator());
    (* This list tracks actual parent dispatch branches. Module availability and
       uninstalled family producers never advertise a service operation. *)
    val body=YXML.string_of_body[XML.Elem(("service-capabilities",[("version","1")]),
      [XML.Elem(("family",[("name","mathematics"),("version","1"),
        ("propose","propose_math"),("poll","poll_result")]),[]),
       XML.Elem(("family",[("name","native-build"),("version","1"),
        ("propose","propose_build"),("poll","poll_build")]),[])])]
  in emit id "service_capabilities" "1" [Bytes.string body]end;
fun lifecycle id operation payload =
  let val target=decimal payload;
    val action=(case operation of "cancel"=>(F.guard((exists(fn(_,entry)=>request_id entry=target)(Synchronized.value math_requests) orelse search_known_request target orelse build_known_request target))
          "Unknown native request";F.Cancel target)
      | "retire_capability"=>(F.guard(exists(fn (_,e)=>
          #capability_id(Request.project(entry_request e))=target)(Synchronized.value math_requests) orelse
          exists(fn(_,e)=> #capability(SearchResident.names e)=target)(Synchronized.value SearchResident.entries) orelse build_known_capability target)
          "Unknown native capability";F.RetireCapability target)
      | _=>(F.guard(member(op =)(Owner.revoked_ids())target orelse
          exists(fn (_,e)=>entry_depends target e)(Synchronized.value math_requests)
          orelse search_known_managed target orelse build_known_managed target
          orelse exists(fn (_,descriptor)=>target=D.evidence_id descriptor orelse
          member(op =)(Veri7vn_Native_Descriptor.native_object_dependencies(D.native descriptor))target)
            (Synchronized.value associations))
          "Unknown managed native association";
          if operation="forget" then F.Forget target else if operation="revoke" then F.Revoke target
          else error "Unknown lifecycle operation"));
    val token=issue_gate_token (Lifecycle action) NONE;
  in emit id "lifecycle_queued" token [] end;
fun command_info id token =
  (case Synchronized.value pending of SOME(current,gate,candidate)=>
    if current<>token orelse not(Owner.valid candidate) then emit id "rejected" "precommit_mismatch" [] else
      (case gate of MathExecute(MathEntry {request,execution,cost,...})=>
        let val p=Request.project request
        in emit id "commands" token [Bytes.string(space_implode "," ("pure"::map IntInf.toString
          [execution,#request_id p,#output_slot_id p,#profile_id p,#executable_generation p,
            #operation_id p,#step_id p,cost]))] end
      | Build event=>(case build_command_info event of SOME bytes=>emit id "commands" token [Bytes.string bytes]
          |NONE=>emit id "commands" "" [])
      | Search event=>(case search_command_info event of SOME bytes=>emit id "commands" token [Bytes.string bytes]
          |NONE=>emit id "commands" "" [])
      | _=>emit id "commands" "" [])
  | NONE=>emit id "rejected" "no_pending_transition" []);
fun recovery_material token=(case AList.lookup(op =)(Synchronized.value tokens) token of
    SOME(gate,SOME material)=>
      (F.guard(gate_live gate) "Native recovery association released";material)
  | _=>error "No kernel recovery material for native token");
fun material_slots (m:recovery_material)=
  [#manifest m,#projection m,#sequent m,#context_closure m,#reconstruction m] @
    the_list(#executable m);
fun recovery_info id token =
  (case AList.lookup(op =)(Synchronized.value tokens) token of
    SOME(_,SOME _)=>let val m=recovery_material token
      in emit id "recovery" (space_implode "," (token::IntInf.toString(#association m)::
        IntInf.toString(#semantic_generation m)::map(Int.toString o size)(material_slots m))) [] end
  | SOME _=>emit id "recovery_none" token []
  | NONE=>emit id "rejected" "unknown_native_gate_token" []);
fun recovery_read id payload=(case space_explode "," payload of [token,slot_text,offset_text]=>
  let val slot=IntInf.toInt(decimal slot_text);
    val offset=IntInf.toInt(decimal offset_text);
    val values=material_slots(recovery_material token);
    val _=F.guard(slot>=0 andalso slot<length values) "Recovery slot bound";
    val bytes=nth values slot;
    val _=F.guard(offset>=0 andalso offset<=size bytes) "Recovery offset bound";
    val chunk=String.substring(bytes,offset,Int.min(65536,size bytes-offset));
  in emit id "recovery_bytes" payload [Bytes.string chunk] end
  | _=>emit id "rejected" "recovery_read_shape" []);
fun recovery_dependencies id token=
  let val material=recovery_material token;
    val bytes=space_implode ","(map IntInf.toString(#dependencies material));
    val _=F.guard(size bytes<=1048576) "Native recovery dependency byte bound";
  in emit id "recovery_dependencies" token [Bytes.string bytes] end;
fun artifact_invalidations id token=
  (case Synchronized.value pending of SOME(current,gate,candidate)=>
    if current<>token orelse not(Owner.valid candidate) then emit id "rejected" "precommit_mismatch" [] else
      let val invalidations=Owner.invalidations candidate;
        val ids=F.invalidation_ids invalidations;
        val mode=if null ids then "none" else (case invalidations of
          F.Revoked _=>"revoke" | F.Forgotten _=>"forget" | F.NoInvalidations=>"none");
      in emit id "artifact_invalidations" (token ^ "," ^ mode)
        (if null ids then [] else [Bytes.string(space_implode ","(map IntInf.toString ids))]) end
  | NONE=>emit id "rejected" "no_pending_transition" []);
datatype restore_upload=Upload of {association:IntInf.int,semantic:IntInf.int,origin:IntInf.int,
  sizes:int list,chunks:string list Array.array,written:int Array.array};
datatype restore_transaction=Restore of {workspace:string,sequence:IntInf.int,checkpoint:string,
  required:F.recovery_identity list,materials:(IntInf.int*(IntInf.int*recovery_material))list Unsynchronized.ref,
  upload:restore_upload option Unsynchronized.ref,total:int Unsynchronized.ref,
  active:bool Synchronized.var,completed:bool Synchronized.var,task:unit Future.future option Synchronized.var};
val restoring=Synchronized.var "veri7vn_native_restore_transaction" (NONE:restore_transaction option);
fun restore_transaction()=(case Synchronized.value restoring of SOME transaction=>transaction
  | NONE=>error "No native restore transaction");
fun staging_transaction()=
  let val transaction as Restore {task,active,...}=restore_transaction();
    val _=F.guard(is_none(Synchronized.value task) andalso Synchronized.value active)
      "Native restore is not staging artifacts"
  in transaction end;
fun role_name F.RequestChildRole="request-child" | role_name F.ArtifactRole="artifact"
  | role_name F.EvidenceRole="evidence";
datatype request_material_family=MathematicsRequest | NativeBuildRequest |
  InitialQualificationRequest | UpdateQualificationRequest;
fun request_material_family (envelope:Veri7vn_Recovery_Manifest.manifest)=(case #profile envelope of
    Veri7vn_Recovery_Manifest.MathRequest=>MathematicsRequest
  | Veri7vn_Recovery_Manifest.BuildRequest=>NativeBuildRequest
  | Veri7vn_Recovery_Manifest.InitialQualificationRequest=>InitialQualificationRequest
  | Veri7vn_Recovery_Manifest.UpdateQualificationRequest=>UpdateQualificationRequest
  | _=>error "Unsupported native request-child material family");
datatype evidence_material_family=KernelEvidence | MathematicsOutput |
  InitialQualificationOutput | UpdateQualificationOutput;
fun evidence_material_family (envelope:Veri7vn_Recovery_Manifest.manifest)=(case #profile envelope of
    Veri7vn_Recovery_Manifest.KernelEvidence=>KernelEvidence
  | Veri7vn_Recovery_Manifest.MathOutput=>MathematicsOutput
  | Veri7vn_Recovery_Manifest.InitialQualification=>InitialQualificationOutput
  | Veri7vn_Recovery_Manifest.UpdateQualification=>UpdateQualificationOutput
  | _=>error "Unsupported closed native evidence material family");
fun require_material_role role (envelope:Veri7vn_Recovery_Manifest.manifest)=(case role of
    F.RequestChildRole=>ignore(request_material_family envelope)
  | F.ArtifactRole=>Veri7vn_Recovery_Manifest.require_profile Veri7vn_Recovery_Manifest.BuildCandidate envelope
  | F.EvidenceRole=>ignore(evidence_material_family envelope));
fun restore_begin id payload checkpoint =
  (case space_explode "," payload of [workspace,sequence_text,revision_text,epoch_text]=>
    let val _=F.guard(is_none(Synchronized.value restoring) andalso
        null(Synchronized.value tokens) andalso is_none(Synchronized.value pending) andalso
        null(Synchronized.value math_requests) andalso null(Synchronized.value associations) andalso
        null(Synchronized.value math_history) andalso null(Synchronized.value math_output_materials) andalso
        null(Synchronized.value SearchResident.entries) andalso null(Synchronized.value BuildResident.entries) andalso
        null(Synchronized.value BuildResident.restored_entries) andalso
        is_none(Synchronized.value search_context_owner) andalso is_none(Synchronized.value build_workspace))
        "Native restore requires fresh unassociated process";
      val sequence=decimal sequence_text;
      val state=the(F.decode_state_checked checkpoint);
      (* A wire-shape upgrade does not implement missing source consumers. This
         generated profile rejects their actual obligations before any restore
         transaction, input pool or committed native material is created. *)
      val _=F.guard(F.restore_supported state) "Unsupported native restoration source profile";
      val _=F.guard(workspace=I.workspace(identity_allocator()) andalso sequence>0 andalso
        F.revision state=decimal revision_text andalso F.epoch state=decimal epoch_text andalso
        F.encode_state state=checkpoint) "Native restore latest checkpoint identity mismatch";
      val required=F.required_associations state;
      val ids=map #association required;
      val _=F.guard(length ids<=8192 andalso length(distinct(op =)ids)=length ids)
        "Native restore association identity bound";
      val transaction=Restore {workspace=workspace,sequence=sequence,checkpoint=checkpoint,required=required,
        materials=Unsynchronized.ref [],upload=Unsynchronized.ref NONE,total=Unsynchronized.ref 0,
        active=Synchronized.var "native_restore_active" true,completed=Synchronized.var "native_restore_complete" false,
        task=Synchronized.var "native_restore_worker" NONE};
      val _=Synchronized.change restoring(K(SOME transaction));
      val bytes=space_implode "\n"(map(fn {association,semantic_generation,role}=>space_implode ","
        [role_name role,IntInf.toString association,IntInf.toString semantic_generation])required);
    in emit id "restore_required" "4" [Bytes.string bytes,Bytes.string ""] end
  | _=>emit id "rejected" "restore_begin_shape" []);
fun restore_material_begin id payload =
  let val Restore {required,materials,upload,total,sequence,...}=staging_transaction();
    val fields=space_explode "," payload;
    val _=F.guard(length fields=8 orelse length fields=9) "Restore material field arity";
    val association=decimal(nth fields 0); val semantic=decimal(nth fields 1);
    val origin=decimal(nth fields 2);val sizes=map(IntInf.toInt o decimal)(drop 3 fields);
    val caps=take(length sizes)[8192,1048576,1048576,16777216,100000,1048576];
    val _=F.guard(is_none(!upload) andalso is_none(AList.lookup(op =)(!materials)association) andalso
      exists(fn {association=actual,semantic_generation,...}=>actual=association andalso
        semantic_generation=semantic)required andalso origin>0 andalso origin<=sequence andalso
      ListPair.allEq (fn (size,cap)=>size>=0 andalso size<=cap)(sizes,caps) andalso
      fold(fn size=>fn used=>size+used)sizes 0<=268435456 - !total) "Restore material membership/resource bound";
    val _=total:= !total+fold(fn size=>fn used=>size+used)sizes 0;
    val _=upload:=SOME(Upload {association=association,semantic=semantic,origin=origin,sizes=sizes,
      chunks=Array.array(length sizes,[]),written=Array.array(length sizes,0)});
  in emit id "restore_material_ready" (IntInf.toString association) [] end;
fun restore_write id payload bytes =
  (case space_explode "," payload of [association_text,slot_text,offset_text]=>
    let val Restore {upload,...}=staging_transaction();
      val Upload {association,sizes,chunks,written,...}=the(!upload);
      val slot=IntInf.toInt(decimal slot_text);val offset=IntInf.toInt(decimal offset_text);
      val _=F.guard(association=decimal association_text andalso slot>=0 andalso slot<length sizes andalso
        offset=Array.sub(written,slot) andalso size bytes>0 andalso size bytes<=65536 andalso
        size bytes<=nth sizes slot-offset) "Restore material append bound";
      val _=Array.update(chunks,slot,bytes::Array.sub(chunks,slot));
      val _=Array.update(written,slot,offset+size bytes);
    in emit id "restore_written" payload [] end
  | _=>emit id "rejected" "restore_write_shape" []);
fun restore_material_end id payload =
  let val Restore {required,materials,upload,...}=staging_transaction();
    val Upload {association,semantic,origin,sizes,chunks,written}=the(!upload);
    val _=F.guard(association=decimal payload andalso
      forall(fn index=>Array.sub(written,index)=nth sizes index)(0 upto(length sizes-1)))
      "Incomplete restore material";
    val values=map(fn index=>String.concat(rev(Array.sub(chunks,index))))(0 upto(length sizes-1));
    val material={association=association,semantic_generation=semantic,manifest=nth values 0,
      projection=nth values 1,sequent=nth values 2,context_closure=nth values 3,reconstruction=nth values 4,
      executable=if length values=6 then SOME(nth values 5)else NONE,dependencies=[]}:recovery_material;
    val envelope=Veri7vn_Recovery_Manifest.decode {max_bytes=8192}(#manifest material);
    val expected= #role(the(find_first(fn {association=actual,...}=>actual=association)required));
    val _=require_material_role expected envelope;
    val _=F.guard(#association envelope=association andalso #semantic_generation envelope=semantic)
      "Restore material differs from latest checkpoint role";
    val _=materials:=AList.update(op =)(association,(origin,material))(!materials);
    val _=upload:=NONE;
  in emit id "restore_material_staged" payload [] end;
fun as_math_material(m:recovery_material):MathRecovery.material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
    projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
    reconstruction= #reconstruction m,executable=the(#executable m)};
fun restore_run (transaction as Restore {workspace,sequence,checkpoint,required,materials,upload,active,completed,...}) =
  let
    val _=F.guard(is_none(!upload) andalso length(!materials)=length required)
      "Incomplete native restore transaction";
    val metadata=the(F.decode_state checkpoint);
    val input_pool=RecoveryInputs.create(identity_allocator());
    (* All native families share the physical input pool and the same graph
       interner. Installed Main/Admission roots are fixed native policies. *)
    val {roots,recovery,...}=local_build_workspace();
    val kernel_batch=V.restore_batch_with_roots input_pool roots;
    val math_batch=MathRecovery.begin_batch_with input_pool;
    val build_batch=DevelopmentRecovery.batch recovery kernel_batch input_pool;
    val build_scope_installation=Veri7vn_Native_Scope_Recovery.install(boot_image())roots
      {math=NONE,build=SOME NativeBuild.Builder.executable,initial=NONE,update=NONE,
       domain=NONE,source_domain=NONE,search=NONE};
    val build_scopes=Veri7vn_Native_Scope_Recovery.batch build_scope_installation
      (identity_allocator())input_pool;
    (* Track the owned target before the helper can allocate and then fail.
       Successful return is not the ownership publication boundary. *)
    val rebuilt_builds=Unsynchronized.ref([]:BuildResident.restored option Unsynchronized.ref list);
    val rebuilt_descriptors=Unsynchronized.ref([]:D.descriptor list);
    val rebuilt_requests=Unsynchronized.ref([]:math_entry list);
    val rebuilt_outputs=Unsynchronized.ref([]:MathGate.witness list);
    val committed=Unsynchronized.ref([]:Veri7vn_Committed_Native_Recovery.committed list);
    val canonical_install_attempted=Unsynchronized.ref false;
    val retained_workspace=Unsynchronized.ref(NONE:MathRecovery.workspace_owner option);
    fun material_for association=the(AList.lookup(op =)(!materials)association);
    fun select role=filter(fn {role=actual,...}=>actual=role)required;
    fun select_evidence family=filter(fn({association,...}:F.recovery_identity)=>
      evidence_material_family(Veri7vn_Recovery_Manifest.decode{max_bytes=8192}
        (#manifest(#2(material_for association))))=family)(select F.EvidenceRole);
    fun run()=
      let
        val _=F.guard(length(select_evidence KernelEvidence)+length(select_evidence MathematicsOutput)=
          length(select F.EvidenceRole)) "Native qualification/search/domain evidence restore adapter not installed";
        val kernel=map(fn {association,...}=>
          let val (origin,m)=material_for association;
            val token=Veri7vn_Committed_Native_Recovery.install_committed_host
              {workspace=workspace,journal_sequence=origin,association=association,
                semantic_generation= #semantic_generation m,checkpoint=checkpoint,manifest= #manifest m,
                projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
                reconstruction= #reconstruction m};
            val _=committed:=token::(!committed)
          in V.recheck_in kernel_batch (identity_allocator()) (boot_image()) token end)(select_evidence KernelEvidence);
        fun family_of ({association,...}:F.recovery_identity)=request_material_family
          (Veri7vn_Recovery_Manifest.decode{max_bytes=8192}(#manifest(#2(material_for association))));
        val child_materials=select F.RequestChildRole;
        val math_children=filter(fn item=>family_of item=MathematicsRequest)child_materials;
        val build_children=filter(fn item=>family_of item=NativeBuildRequest)child_materials;
        val _=F.guard(length math_children+length build_children=length child_materials)
          "Native qualification request restore adapter not installed";
        fun committed_material association=
          let val (origin,m)=material_for association;
            val token=Veri7vn_Committed_Native_Recovery.install_committed_host
              {workspace=workspace,journal_sequence=origin,association=association,
               semantic_generation= #semantic_generation m,checkpoint=checkpoint,manifest= #manifest m,
               projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
               reconstruction= #reconstruction m};
            val _=committed:=token::(!committed)
          in token end;
        val build_requests=map(fn{association,...}=>
          let val token=committed_material association;
            val checked=DevelopmentRecovery.recheck_request_in build_batch(identity_allocator())token;
            val scope=Veri7vn_Native_Scope_Recovery.check build_scopes token
          in(checked,scope,token)end)build_children;
        val build_outputs=map(fn{association,...}=>
          let val token=committed_material association;
            val checked=DevelopmentRecovery.recheck_candidate_in build_batch(identity_allocator())token
          in(checked,token)end)(select F.ArtifactRole);
        val math_ids=distinct(op =)(map #semantic_generation math_children @
          map #semantic_generation(select_evidence MathematicsOutput));
        val _=List.app(fn semantic=>ignore(exists(fn verified=>
          MathRecovery.supply_generation_for math_batch boot_policy verified semantic)kernel))math_ids;
        val active_requests=map(fn {association,...}=>MathRecovery.verify_request math_batch (identity_allocator())
          boot_policy (boot_image()) (boot_bytes()) (as_math_material(#2(material_for association))))
          math_children;
        val historical_requests=map_filter(fn{association,...}=>
          let val material=as_math_material(#2(material_for association))
          in if MathRecovery.has_embedded_request material then SOME(MathRecovery.verify_output_request math_batch
              (identity_allocator())boot_policy(boot_image())(boot_bytes())checkpoint material)
            else NONE end)(select_evidence MathematicsOutput);
        fun merge_request value originals=case find_first(fn old=>
            MathRecovery.verified_identity old=MathRecovery.verified_identity value)originals of
          NONE=>value::originals|SOME old=>
            (F.guard(MathRecovery.same_verified_request old value) "Conflicting original Math capsule source";originals);
        val requests=fold merge_request(active_requests @ historical_requests)[];
        val active_keys=map MathRecovery.verified_identity active_requests;
        val sealed=V.seal_batch kernel_batch;
        val _=Thread_Attributes.uninterruptible(fn _=>fn()=>
          (canonical_install_attempted:=true;
           I.install_fragments(identity_allocator())(V.fragment sealed::map MathRecovery.fragment requests @
             maps(fn(checked,scope,_)=>[DevelopmentRecovery.request_fragment checked,
               Veri7vn_Native_Scope_Recovery.fragment scope])build_requests @
             map(DevelopmentRecovery.candidate_fragment o #1)build_outputs)))();
        val restored_builds=map(fn(checked,_,token)=>
          let val target=Unsynchronized.ref NONE;
            val _=rebuilt_builds:=target::(!rebuilt_builds);
            val restored=build_restore_request_into target checked token
          in(checked,restored)end)build_requests;
        val _=List.app(fn(checked,token)=>
          let val binding=DevelopmentRecovery.Candidate.binding checked;
            val key=(#request binding,#goal binding,#slot binding);
            val paired=filter(fn(_,restored)=>BuildResident.restored_key restored=key)restored_builds;
            val (request,restored)=case paired of [entry]=>entry
              |_=>error "Build artifact has no unique authenticated original request";
          in build_restore_output_into restored request checked token end)build_outputs;
        val descriptors=map(fn verified=>let val descriptor=D.restore(identity_allocator())verified;
          val _=rebuilt_descriptors:=descriptor::(!rebuilt_descriptors) in descriptor end)kernel;
        val entries=map(fn verified=>
          let val {request,bridge}=MathRecovery.restore_request(identity_allocator())verified;
            val rid= #request_id(Request.project request);
            val cost=(case Mathematics.modeled_cost(Request.family_request request) of Mathematics.Ready n=>n
              | _=>error "Restored native cost unavailable");
            val executions=F.execution_ids metadata rid (#output_slot_id(Request.project request));
            val _=F.guard(length executions<=1) "Multiple charged executions for fixed native request";
            val entry=MathEntry {request=request,input=Request.input_owner request,bridge=bridge,
              execution=(case executions of [execution]=>execution | _=>I.allocate(identity_allocator())),
              cost=cost,dependencies=Request.managed_dependencies request @ Display.managed_dependencies bridge,
              observed=Synchronized.var "restored_request_observed_dependencies" executions,
              control=Control.create(not(F.request_cancelled metadata rid)),
              job=Synchronized.var "restored_request_job" NONE,
              monitor=Synchronized.var "restored_request_monitor" NONE,witness=Synchronized.var "restored_request_output" NONE,
              failure=Synchronized.var "restored_request_interrupted" (SOME "execution.interrupted")};
            val _=rebuilt_requests:=entry::(!rebuilt_requests)
          in entry end)requests;
        val outputs=map(fn {association,...}=>
          let val m=as_math_material(#2(material_for association));
            val owner=MathRecovery.output_owner m;
            val candidates=filter(fn entry=>case owner of MathRecovery.LegacyRequest rid=>request_id entry=rid
              | MathRecovery.ScopedChild slot=> #output_slot_id(Request.project(entry_request entry))=slot)entries;
            val _=F.guard(length candidates=1) "Missing/ambiguous native output child association";
            val entry as MathEntry {witness=root,failure,observed,...}=hd candidates;
            val witness=MathRecovery.restore_output(identity_allocator()) (boot_image()) (boot_bytes())
              (entry_bridge entry) (entry_request entry) m;
            val _=rebuilt_outputs:=witness::(!rebuilt_outputs);
            val _=Synchronized.change root(K(SOME witness));
            val _=Synchronized.change observed(K(MathGate.managed_dependencies witness));
            val _=Synchronized.change failure(K NONE)
          in (entry,witness) end)(select_evidence MathematicsOutput);
        val active_entries=filter(fn entry=>member(op =)active_keys(entry_key entry))entries;
        val gates=map Admitted descriptors @ map RestoredMath active_entries @
          map (RestoredMathHistory o #2)outputs @
          maps(fn(_,restored)=>Build(BuildResident.RestoredRequest restored)::
            (if BuildResident.restored_acknowledged restored then
              [Build(BuildResident.RestoredArtifact restored)]else[]))restored_builds;
        (* Native restored owners retained their checked witnesses before the
           construction batches release their temporary roots. *)
        val _=DevelopmentRecovery.close_batch build_batch;
        val _=Veri7vn_Native_Scope_Recovery.close build_scopes;
        val workspace_owner=MathRecovery.close_batch math_batch;
        val _=retained_workspace:=SOME workspace_owner;
        val _=RecoveryInputs.close input_pool;
        val _=serialized(fn()=>Thread_Attributes.uninterruptible(fn _=>fn()=>
          (F.guard(Synchronized.value active) "Native restore was cancelled";
           F.guard(Owner.restore_complete checkpoint gates) "Native complete association restore refused";
           Synchronized.change associations(K(map(fn d=>(D.evidence_id d,d))descriptors));
           Synchronized.change math_requests(K(map(fn e=>(entry_key e,e))active_entries));
           Synchronized.change math_history(K(map(fn(_,witness)=>
             let val id=MathGate.evidence witness;
               val material= #2(material_for id)
             in (id,captured_math_history witness material)end)outputs));
           List.app(fn entry=>if member(op =)active_keys(entry_key entry)then()
             else (Request.release(entry_request entry);Control.mark_released
               (case entry of MathEntry{control,...}=>control)))entries;
           Synchronized.change durable_sequence(K sequence);
           Synchronized.change math_workspace_owners(cons workspace_owner);
           List.app Veri7vn_Committed_Native_Recovery.release (!committed);
           Synchronized.change completed(K true)))());
      in () end;
    val result=Exn.capture run();
  in case result of Exn.Res()=>() | Exn.Exn failure=>
    ((if !canonical_install_attempted then Synchronized.change native_poisoned(K true) else ());
     List.app(fn root=>Option.app BuildResident.release_restored(!root))(!rebuilt_builds);
     DevelopmentRecovery.abort_batch build_batch;
     Veri7vn_Native_Scope_Recovery.close build_scopes;
     List.app MathGate.release(!rebuilt_outputs);List.app release_entry(!rebuilt_requests);
     MathRecovery.abort_batch math_batch;
     (case !retained_workspace of NONE=>() | SOME owner=>MathRecovery.release_workspace owner);
     List.app D.release(!rebuilt_descriptors);V.abort_batch kernel_batch;
     RecoveryInputs.abort input_pool;
     List.app Veri7vn_Committed_Native_Recovery.release(!committed);
     Exn.reraise failure) end;
fun restore_finish id =
  let val transaction as Restore {task,active,...}=restore_transaction();
    val _=F.guard(is_none(Synchronized.value task) andalso Synchronized.value active) "Native restore already verifying";
    val _=Thread_Attributes.uninterruptible(fn _=>fn()=>
      let val future=Future.fork(fn()=>restore_run transaction)
      in Synchronized.change task(K(SOME future)) end)();
  in emit id "restore_verifying" "" [] end;
fun restore_progress id =
  let val Restore {task,completed,...}=restore_transaction()
  in case Synchronized.value task of NONE=>emit id "restore_staging" "" []
  | SOME future=>(case Future.peek future of NONE=>emit id "restore_verifying" "" []
    | SOME _=>if Synchronized.value completed then
        (Synchronized.change restoring(K NONE);emit id "restored" "complete_no_dispatch_replay" [])
      else (Synchronized.change restoring(K NONE);emit id "restore_failed" "native_association_recheck_failed" [])) end;
fun restore_abort id =
  let val Restore {task,active,completed,...}=restore_transaction();
    val _=F.guard(not(Synchronized.value completed)) "Native restore already committed";
    val _=Synchronized.change active(K false)
  in case Synchronized.value task of NONE=>(Synchronized.change restoring(K NONE);emit id "restore_aborted" "" [])
    | SOME future=>(Future.cancel future;emit id "restore_aborting" "" []) end;

fun issue_admitted descriptor =
  let val material=kernel_material descriptor
    (Veri7vn_Native_Recovery_Export.export(identity_allocator()) (boot_image()) descriptor)
  in serialized(fn()=>issue_gate (Admitted descriptor) (SOME material)) end;
fun release_admitted descriptor=serialized(fn()=>
  let val evidence=D.evidence_id descriptor;
    val _=D.release descriptor;
    val _=Synchronized.change tokens(filter(fn (_, (Admitted d,_))=>D.evidence_id d<>evidence | _=>true));
    val _=Synchronized.change associations(AList.delete(op =) evidence);
    val _=Synchronized.change pending(K NONE);
  in Owner.invalidate() end);
fun handle_command args =
  if length args<4 orelse length args>5 orelse fold(fn b=>fn n=>Bytes.size b+n) args 0>2200000
  then emit "0" "rejected" "frame_bound" [] else
  let val controls=map Bytes.content(take 4 args); val body=drop 4 args
  in case controls of ["1",id,operation,payload]=>
    if not(valid_id id) orelse size payload>512 then emit "0" "rejected" "control_bound" [] else
    if Synchronized.value native_poisoned andalso not(member(op =)
      ["status","restore_progress","cleanup_status","cleanup_barrier"]operation)
    then emit id "rejected" "native_incarnation_poisoned_restart_required" [] else
    if is_some(Synchronized.value restoring) andalso not(member(op =)
      ["status","restore_material_begin","restore_write","restore_material_end","restore_finish","restore_progress","restore_abort"]operation)
    then emit id "rejected" "native_recovery_in_progress" [] else
    (case (operation,body) of
      ("install_boot",[manifest])=>(install_boot(Bytes.content manifest);
        emit id "boot_installed" (Value.print_int(PolyML.ml_pid())) [])
    | ("install_ids",[])=>(install_ids payload;emit id "ids_installed" "" [])
    | ("status",[])=>if Synchronized.value native_poisoned
      then emit id "unavailable" "native_incarnation_poisoned_restart_required" []
      else emit id "ready" "resident_fixed_mathematics;typed_staged_recovery" []
    | ("service_capabilities",[])=>service_capabilities id payload
    | ("initial",[])=>emit id "initial" "0,0" [Bytes.string(Owner.initial_frame())]
    | ("propose_math",[bytes])=>propose_math id payload (Bytes.content bytes)
    | ("propose_build",[])=>propose_build id payload
    | ("poll_build",[])=>poll_build id payload
    | ("build_current_binding",[])=>build_current_binding id payload
    | ("search_contexts",[])=>search_contexts id payload
    | ("propose_search",[bytes])=>propose_search id payload (Bytes.content bytes)
    | ("poll_search",[])=>poll_search id payload
    | ("search_requests",[])=>search_requests id payload
    | ("build_input_begin",_)=>build_transfer id operation payload body
    | ("build_input_write",_)=>build_transfer id operation payload body
    | ("build_input_finish",_)=>build_transfer id operation payload body
    | ("build_input_abort",_)=>build_transfer id operation payload body
    | ("build_input_release",_)=>build_transfer id operation payload body
    | ("build_input_discard",_)=>build_transfer id operation payload body
    | ("build_input_accept",_)=>build_transfer id operation payload body
    | ("build_input_settle",_)=>build_transfer id operation payload body
    | ("poll_result",[])=>poll_result id payload
    | ("poll_math_goal",[])=>poll_math_goal id payload
    | ("growth_suggest",[bytes])=>growth_suggest id payload (Bytes.content bytes)
    | ("inspect_request",[])=>inspect_request id payload
    | ("inspect_routing",[bytes])=>inspect_routing id payload (Bytes.content bytes)
    | ("cancel",[])=>lifecycle id operation payload
    | ("forget",[])=>lifecycle id operation payload
    | ("revoke",[])=>lifecycle id operation payload
    | ("retire_capability",[])=>lifecycle id operation payload
    | ("prepare",[])=>prepare id payload
    | ("command_info",[])=>command_info id payload
    | ("recovery_info",[])=>recovery_info id payload
    | ("recovery_read",[])=>recovery_read id payload
    | ("recovery_dependencies",[])=>recovery_dependencies id payload
    | ("artifact_invalidations",[])=>artifact_invalidations id payload
    | ("cleanup_status",[])=>cleanup_status id payload false
    | ("cleanup_barrier",[])=>cleanup_barrier id
    | ("retry_cleanup",[])=>if payload="" then retry_all_cleanups id else cleanup_status id payload true
    | ("restore_begin",[checkpoint])=>restore_begin id payload (Bytes.content checkpoint)
    | ("restore_material_begin",[])=>restore_material_begin id payload
    | ("restore_write",[bytes])=>restore_write id payload (Bytes.content bytes)
    | ("restore_material_end",[])=>restore_material_end id payload
    | ("restore_finish",[])=>restore_finish id
    | ("restore_progress",[])=>restore_progress id
    | ("restore_abort",[])=>restore_abort id
    | ("validate",[])=>emit id (if validate payload then "valid" else "rejected") payload []
    | ("ack",[])=>acknowledge id payload
    | ("restore",[checkpoint])=>if Owner.restore_initial(Bytes.content checkpoint)
      then (Synchronized.change pending(K NONE);Synchronized.change tokens(K []);
        Synchronized.change durable_sequence(K(if payload="" then 1 else decimal payload));
        emit id "restored" "initial" [])
      else emit id "unavailable" "protected_native_association_reconstruction_required" []
    | _=>emit id "rejected" "operation_or_shape" [])
  | _=>emit "0" "rejected" "version_or_shape" [] end;
(* Protocol callbacks run on Isabelle's input reader. Native hashing and other
   Scala functions await Scala.result commands on that same reader, so executing
   a proposal in the callback deadlocks it. The reader only validates/registers
   bounded message ownership. One finite worker drains FIFO messages through the
   existing coordinator; it never introduces another authority state. *)
val rpc_max_items=64;
val rpc_max_bytes=16777216;
type rpc_message={id:string,args:Bytes.T list,bytes:int};
type rpc_state={pending:rpc_message list,active:rpc_message option,bytes:int,
  generation:serial option,worker:unit Future.future option};
val rpc_empty={pending=[],active=NONE,bytes=0,generation=NONE,worker=NONE}:rpc_state;
val rpc_queue=Synchronized.var "veri7vn_owned_native_rpc_queue"
  rpc_empty;
val rpc_operations=["growth_suggest","propose_build","poll_build","build_current_binding","search_contexts","propose_search","poll_search","search_requests","install_boot","install_ids","status","service_capabilities","initial","propose_math","poll_result","poll_math_goal","inspect_request","inspect_routing",
  "build_input_begin","build_input_write","build_input_finish","build_input_abort",
  "build_input_release","build_input_discard","build_input_accept","build_input_settle",
  "cancel","forget","revoke","retire_capability","prepare","command_info","recovery_info",
  "recovery_read","recovery_dependencies","artifact_invalidations","cleanup_status","cleanup_barrier",
  "retry_cleanup","restore_begin","restore_material_begin","restore_write","restore_material_end",
  "restore_finish","restore_progress","restore_abort","validate","ack","restore"];
fun rpc_id args=(case args of version::id::_=>
  if Bytes.size version=1 andalso Bytes.size id<=18 andalso Bytes.content version="1"
    andalso valid_id(Bytes.content id) then Bytes.content id else "0" | _=>"0");
fun rpc_dispatch({id,args,...}:rpc_message)=
  (case Exn.capture(fn()=>serialized(fn()=>handle_command args))() of Exn.Res()=>()
  | Exn.Exn exn=>if Exn.is_interrupt exn then Exn.reraise exn
      else emit id "rejected" "native_transition_failure" []);
fun rpc_pop owner (state as {pending,active,bytes,generation,worker}:rpc_state)=
  if generation<>SOME owner then (NONE,state) else
  (F.guard(is_none active) "Native RPC worker ownership overlap";
   case pending of []=>(NONE,rpc_empty)
   | message::rest=>(SOME message,{pending=rest,active=SOME message,bytes=bytes,
       generation=generation,worker=worker}));
fun rpc_take owner=Synchronized.change_result rpc_queue(rpc_pop owner);
fun rpc_completed owner ({id,bytes=count,...}:rpc_message)
    ({pending,active,bytes,generation,worker}:rpc_state)=
    (F.guard(generation=SOME owner andalso
      (case active of SOME actual=> #id actual=id | NONE=>false))
      "Native RPC message ownership changed";
     {pending=pending,active=NONE,bytes=bytes-count,generation=generation,worker=worker}:rpc_state);
fun rpc_release owner message=Synchronized.change rpc_queue(rpc_completed owner message);
fun rpc_detach owner (state as {pending,active,generation,...}:rpc_state)=
  if generation<>SOME owner then (NONE,state)
  else (SOME(the_list active @ pending),rpc_empty);
fun rpc_fits count ({pending,active,bytes,...}:rpc_state)=
  length pending+(if is_some active then 1 else 0)<rpc_max_items andalso
  count<=rpc_max_bytes-bytes;
fun rpc_abort owner exn = Thread_Attributes.uninterruptible(fn _=>fn()=>
  let
    val abandoned=Synchronized.change_result rpc_queue(fn state=>
      let val (detached,next)=rpc_detach owner state;
        val _=if is_some detached then Synchronized.change native_poisoned(K true) else ();
      in (detached,next) end);
    val _=List.app(fn {id,...}=>ignore(Exn.capture
      (fn()=>emit id "rejected" "native_rpc_worker_failed" [])()))(the_default [] abandoned);
    val _=if is_none abandoned then () else ignore(Exn.capture(fn()=>Output.system_message
      (if Exn.is_interrupt exn then "veri7vn resident RPC worker interrupted; restart required"
       else "veri7vn resident RPC worker failed; restart required"))());
  in () end)();
fun rpc_drain owner () =
  let
    fun advance()=Thread_Attributes.uninterruptible(fn restore=>fn()=>
      (case rpc_take owner of NONE=>false
      | SOME message=>
          let val result=Exn.capture(restore(fn()=>rpc_dispatch message))();
          in case result of Exn.Res()=>(rpc_release owner message;true)
            | Exn.Exn exn=>(rpc_abort owner exn;false) end))();
    fun loop()=if advance() then loop() else ();
  in case Exn.capture loop() of Exn.Res()=>() | Exn.Exn exn=>rpc_abort owner exn end;
fun rpc_enqueue args = Thread_Attributes.uninterruptible(fn _=>fn()=>
  let
    val id=rpc_id args;
    val shape=(case args of [_,_,_,_]=>true | [_,_,_,_,_]=>true | _=>false);
    fun add value NONE=NONE | add value (SOME total)=
      if Bytes.size value>2200000-total then NONE else SOME(total+Bytes.size value);
    val bounded=if shape then fold add args(SOME 0) else NONE;
    val headers=shape andalso (case args of version::request::operation::payload::_=>
      Bytes.size version<=1 andalso Bytes.size request<=18 andalso Bytes.size operation<=64
      andalso Bytes.size payload<=512 | _=>false);
    val controls=if headers then map Bytes.content(take 4 args) else [];
    val bytes=the_default 0 bounded;
    val valid=headers andalso is_some bounded andalso
      (case controls of ["1",actual,operation,payload]=>valid_id actual andalso
        size payload<=512 andalso member(op =)rpc_operations operation | _=>false);
    val attempt=Exn.capture(fn()=>if not valid then false else
      Synchronized.change_result rpc_queue(fn state as {pending,active,bytes=owned,generation,worker}=>
        if not(rpc_fits bytes state) orelse
          exists(fn message=> #id message=id)(the_list active @ pending) then (false,state)
        else
          let
            val message={id=id,args=args,bytes=bytes}:rpc_message;
            (* Fork while the registered queue ownership is locked: the task
               cannot pop its first message before its Future root is installed. *)
            val owner=case generation of SOME current=>current | NONE=>serial();
            val task=case worker of SOME previous=>previous | NONE=>Future.fork(rpc_drain owner);
          in (true,{pending=pending@[message],active=active,bytes=owned+bytes,
            generation=SOME owner,worker=SOME task}) end))();
  in case attempt of Exn.Res true=>() | Exn.Res false=>emit id "rejected"
      (if valid then "native_rpc_queue_limit" else "operation_or_frame_bound") []
    | Exn.Exn _=>emit id "rejected" "native_rpc_worker_unavailable" [] end)();
val _=Protocol_Command.define_bytes "veri7vn_service_v1" rpc_enqueue;
structure Test_Only =
struct
  datatype fault=datatype Proposal_Test_Only.fault;
  val check_proposal_cleanup=Proposal_Test_Only.check_proposal_cleanup;
  fun check_pending_alias_cleanup()=
    let
      val (target,entries)=serialized(fn()=>
        let val _=F.guard(null(Synchronized.value math_requests) andalso null(Synchronized.value tokens)
            andalso is_none(Synchronized.value pending)) "Pending alias diagnostic requires unused resident";
          val version=Owner.current_version();
          val _=propose_math "0" "" "the sum of -2 and 3";
          val _=propose_math "0" "" "the sum of 4 and 5";
          val entries=map snd(Synchronized.value math_requests);
          val _=F.guard(length entries=2) "Pending alias diagnostic did not elaborate both originals";
          val target=request_id(hd entries);
          val bridge=Display.project_bridge(entry_bridge(hd entries));
          val removed=[#bridge_id bridge,#statement_code_id bridge];
          val _=cleanup_action (F.Forget target) (F.Forgotten removed);
          val _=F.guard(forall(fn entry=>not(entry_live entry))entries andalso
            null(Synchronized.value tokens) andalso Owner.current_version()=version)
            "Invalidated undurable alias retained a usable gate or original recovery material"
        in (target,entries)end);
      val jobs=map snd(filter(fn(actual,_)=>actual=target)(Synchronized.value cleanups));
      val _=List.app(fn Cleanup {task,...}=>Option.app(fn future=>
        Exn.release(Future.join_result future))(Synchronized.value task))jobs;
      val _=serialized(fn()=>
        (F.guard(forall(fn MathEntry {request,input,control,...}=>
          Control.released control andalso not(Request.live request) andalso not(Literals.retained input))entries)
          "Undurable alias retained actual request/input roots after draining";
         Synchronized.change math_requests(filter(fn(_,entry)=>not(exists(fn removed=>
           request_id removed=request_id entry)entries)))))
    in writeln "Native undurable alias token/material and input cleanup checks passed" end;
  fun check_cleanup_ownership()=
    let
      val attempts=Synchronized.var "cleanup_fixture_attempts" 0;
      fun job work=Cleanup {release=Synchronized.var "cleanup_fixture_roots" (SOME work),
        task=Synchronized.var "cleanup_fixture_task" NONE};
      fun join(Cleanup {task,...})=Option.app(fn future=>ignore(Future.join_result future))(Synchronized.value task);
      val first=job(fn()=>if Synchronized.change_result attempts(fn n=>(n,n+1))=0
        then error "fixed cleanup retry fixture" else ());
      val second=job(fn()=>());
      val _=start_cleanup first;
      val _=join first;
      val _=F.guard(cleanup_state first=2) "Failed cleanup lost retry ownership";
      val intents=retain_cleanup 1 second (retain_cleanup 1 first []);
      val _=F.guard(length intents=2) "Later same-target cleanup replaced captured roots";
      val _=start_cleanup second;
      val _=join second;
      val _=F.guard(length(pending_cleanups intents)=1 andalso cleanup_state first=2)
        "Completed later cleanup discarded failed earlier roots";
      val _=start_cleanup first;
      val _=join first;
      val _=F.guard(null(pending_cleanups intents) andalso Synchronized.value attempts=2)
        "Cleanup retry did not discharge every retained same-target intent";
      val _=List.app(fn(_,Cleanup {release,...})=>F.guard(is_none(Synchronized.value release))
        "Successful cleanup retained captured work closure")intents
    in writeln "Native same-target cleanup ownership/retry checks passed" end;
  fun check_rpc_ownership()=
    let
      val old=serial(); val fresh=serial();
      fun message id={id=id,args=map Bytes.string["1",id,"status",""],bytes=7+size id}:rpc_message;
      val first=message "11";val second=message "12";
      val root=Future.value();
      val initial={pending=[first,second],active=NONE,bytes= #bytes first+ #bytes second,
        generation=SOME old,worker=SOME root}:rpc_state;
      val (taken,active)=rpc_pop old initial;
      val _=F.guard(map #id(the_list taken)=["11"] andalso map #id(#pending active)=["12"]
        andalso #bytes active= #bytes initial) "RPC FIFO or active byte charge changed";
      val released=rpc_completed old first active;
      val (next,active2)=rpc_pop old released;
      val _=F.guard(map #id(the_list next)=["12"] andalso #bytes released= #bytes second)
        "RPC active ownership was not released before next message";
      val (_,drained)=rpc_pop old(rpc_completed old second active2);
      val _=F.guard(is_none(#generation drained) andalso is_none(#worker drained) andalso #bytes drained=0)
        "RPC drain did not atomically release its generation, worker and bytes";
      val successor={pending=[first],active=NONE,bytes= #bytes first,
        generation=SOME fresh,worker=SOME root}:rpc_state;
      val (stale,kept)=rpc_detach old successor;
      val _=F.guard(is_none stale andalso #generation kept=SOME fresh andalso
        #bytes kept= #bytes first andalso map #id(#pending kept)=["11"] andalso
        (case #worker kept of SOME actual=>Task_Queue.eq_task(Future.task_of actual,Future.task_of root)
        | NONE=>false)) "A finishing RPC burst cleared its successor's roots";
      val (failed,empty)=rpc_detach fresh successor;
      val _=F.guard(map #id(the_default [] failed)=["11"] andalso #bytes empty=0 andalso
        is_none(#worker empty) andalso is_none(#generation empty)) "Failed RPC burst retained private roots";
      val waiting=map(message o Value.print_int)(100 upto(100+rpc_max_items-2));
      val full={pending=waiting,active=SOME second,
        bytes=fold(fn item=>fn n=> #bytes item+n)waiting(#bytes second),
        generation=SOME old,worker=SOME root}:rpc_state;
      val _=F.guard(not(rpc_fits 1 full)) "RPC item bound excluded active ownership";
      val _=F.guard(rpc_fits(rpc_max_bytes- #bytes successor)successor andalso
        not(rpc_fits(rpc_max_bytes- #bytes successor+1)successor)) "RPC aggregate byte boundary changed";
    in () end;
end;
end;
