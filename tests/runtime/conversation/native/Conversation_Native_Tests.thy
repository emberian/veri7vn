theory Conversation_Native_Tests
  imports Veri7vn_Runtime_Service.Native_Service
begin

text \<open>This fixture assembles the real private source owner and authority
locally. The observation-update constructor exists only in this test assembly;
there is no resident opcode or alternative production authority path. The
consumer load requires the actual SessionObservation Scope integration.\<close>

ML_file \<open>../../../../src/runtime/conversation/native_conversation_consumer.ML\<close>

ML \<open>
local
  structure F=Veri7vn_Metadata_Frame;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Pin=Veri7vn_Native_Observation_Pin;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure R=Veri7vn_Interpreted_Request;
  structure Display=Veri7vn_Refined_Math_Display;
  fun ensure true _=() | ensure false message=error message;
  fun rejects message action=ensure(Exn.is_exn(Exn.capture action()))message;
  fun ready(M.Ready value)=value | ready _=error "Actual native mathematics fixture refused";
  val ids=I.install_host_block{workspace="c0de0000000000000000000000000072",first=9300000,past=9365536};
  val workspace=I.workspace ids;
  val policy=A.policy @{theory};
  val executable=M.executable();
  val generation=Veri7vn_Native_Registry.generation @{context}
    {packages=[],runtime="native conversation CAS fixture",policy="kernel",sources=[],
      interpretation="original session source"};
  val instance=ready(M.attach{policy=policy,generation=generation,
    code_context=Veri7vn_Executable_Identity.code_theory executable,
    limits={nodes=20000,depth=2048,work=512,seconds=5}});
  val local_policy=R.allow_mathematics ids executable instance;
  val bridge=Display.attach{allocator=ids,policy=policy,generation=generation,
    instance=instance,statement_pin=F.statement_executable()};
  structure Recovery=Veri7vn_Native_Session_Input_Recovery(
    structure Checkpoint=struct
      fun matches (_:Veri7vn_Committed_Native_Recovery.committed)
        (_:Veri7vn_Session_Input_Codec.metadata)=NONE:{recorded:bool}option
    end
    val executable=executable);
  structure SourceContext=Veri7vn_Private_Session_Context();
  structure Entry=Veri7vn_Private_Session_Entry(
    structure Restored=Recovery.View structure Context=SourceContext);
  structure Frames=
  struct
    val create_frame=F.conversation_create_frame;
    val source_frame=F.conversation_source_frame;
    val record_frame=F.conversation_record_frame;
    val adoption_frame=F.conversation_adoption_frame;
    val expire_frame=F.conversation_expire_frame;
  end;
  structure Roots=Veri7vn_Private_Conversation_Roots(
    structure Frame=Frames structure Context=SourceContext structure Entry=Entry
    fun allocator()=ids val policy=policy);
  structure MathGate=Veri7vn_Native_Math_Gate;
  structure Final=Veri7vn_Conversation_Math_Final;
  datatype math_phase=Reserve | Statement | Bridge | Parameter |
    Execute of {execution:IntInf.int,cost:IntInf.int} |
    Evidence of MathGate.witness | Publish of MathGate.witness;
  datatype gate=Conversation of Roots.event | TestObservationUpdate of Pin.snapshot |
    Math of Roots.prepared * math_phase;
  fun actual_observation prepared=the(Roots.request_observation(Roots.request prepared));
  fun native_math_frame prepared phase revision=
    let val request=Roots.request prepared;
      val names=R.project request;
      val source_dependencies=Entry.dependencies(Roots.source prepared);
      val observed=actual_observation prepared;
      val prerequisites=distinct(op =)(R.native_prerequisites request @ Display.managed_dependencies bridge);
    in case phase of Reserve=>F.conversation_bind_reserve_frame observed source_dependencies
          (F.math_reserve_frame names revision(ready(M.modeled_cost(R.family_request request)))prerequisites)
      |Statement=>F.math_statement_frame names(Display.project_bridge bridge)
      |Bridge=>F.math_bridge_frame names(Display.project_bridge bridge)
      |Parameter=>F.conversation_bind_parameter_frame observed source_dependencies
          {request= #request_id names,input= #input_identity names}
          (F.math_parameter_frame names(R.managed_dependencies request))
      |Execute{execution,cost}=>F.math_execute_frame names execution cost
      |Evidence witness=>MathGate.evidence_frame witness
      |Publish witness=>F.conversation_bind_output_frame observed source_dependencies
          {request= #request_id names,parameter= #parameter_id names}(MathGate.publication_frame witness)end;
  structure Owner=Veri7vn_Native_State_Owner(struct
    type event=gate
    fun is_live(Conversation event)=Roots.live event | is_live(TestObservationUpdate _)=true
      |is_live(Math(prepared,phase))=Roots.intrinsic_request(Roots.request prepared) andalso
        (case phase of Evidence witness=>MathGate.live witness|Publish witness=>MathGate.live witness|_=>true)
    fun current_expectation(Conversation event)=
          (case Roots.original_observation event of NONE=>F.NoCurrentExpectation
          | SOME original=>(case Roots.record_identity event of
              NONE=>F.ExactObservation(F.conversation_observation_bytes original)
            | SOME{request,utterance,...}=>F.ExactConversationRecord
                {observation=F.conversation_observation_bytes original,request=request,input=utterance}))
      | current_expectation(TestObservationUpdate _)=F.NoCurrentExpectation
      | current_expectation(Math(prepared,_))=F.ExactObservation
          (F.conversation_observation_bytes(actual_observation prepared))
    fun event_frame(Conversation event)_=Roots.frame event
      | event_frame(TestObservationUpdate original)_=F.conversation_update_frame original
      | event_frame(Math(prepared,phase))revision=native_math_frame prepared phase revision
    fun retirement_registrations _=[]
    fun supports(Math(prepared,Execute{execution,cost}))[F.PureRun run]=
          let val names=R.project(Roots.request prepared);val charge= #cost run
          in #execution run=execution andalso #request run= #request_id names andalso
            #slot run= #output_slot_id names andalso #inputs run=[#parameter_id names] andalso
            #profile charge= #profile_id names andalso #code_generation charge= #executable_generation names andalso
            #operation charge= #operation_id names andalso #step charge= #step_id names andalso #units charge=cost end
      |supports _ commands=null commands
    fun recovery_view _=F.NoAssociation
  end);
  structure Frontdoor=Veri7vn_Conversation_Frontdoor(
    structure Roots=Roots
    structure Query=struct
      val current_context=Owner.conversation_current_context workspace
      val session_exists=Owner.conversation_session_exists
      val source_visible=Owner.conversation_source_visible
    end
    val authority=Roots.frontdoor_authority);
  val(sid,created)=Frontdoor.create();
  val _=ignore(Owner.acknowledge(Owner.prepare(Conversation created)));
  val _=Roots.release_event created;
  val original=the(Owner.conversation_current_context workspace(sid,0));
  val turn=case Frontdoor.prepare_math{session=sid,version=0,bytes="the sum of 2 and 3",
      selection=NONE,local_policy=local_policy,bridge=bridge}of
      Frontdoor.Ready value=>value | _=>error "Actual original conversation request did not elaborate";
  val source=Frontdoor.source_event turn;
  val _=ensure(Frontdoor.current_event source andalso Roots.live source)
    "Fresh real source descriptor was not current/live";
  val staged=Owner.prepare(Conversation source);
  val old_version=Owner.current_version();
  val old_epoch=Owner.current_epoch();
  val changed={workspace=workspace,session=sid,version= #version original,
    evaluation_time=SOME{basis=Pin.SourceEvent "test-source-clock",ticks=1},
    reads= #reads original}:Pin.snapshot;
  val _=ignore(Owner.acknowledge(Owner.prepare(TestObservationUpdate changed)));
  val _=ensure(Owner.current_version()>old_version andalso Owner.current_epoch()=old_epoch andalso
    Owner.conversation_current_context workspace(sid,0)=SOME changed)
    "Same-version metadata update did not change the actual Owner observation";
  val _=ensure(Roots.live source andalso not(Frontdoor.current_event source))
    "Intrinsic source liveness queried authority or lost the current-observation distinction";
  val _=ensure(not(Owner.valid staged)) "Changed observation retained an old source candidate";
  val checkpoint_before=Owner.current_version();
  val _=rejects "Old real source acknowledgement survived observation supersession"
    (fn()=>Owner.acknowledge staged);
  val _=ensure(Owner.current_version()=checkpoint_before andalso
    Owner.conversation_current_context workspace(sid,0)=SOME changed)
    "Refused old acknowledgement changed the actual authority";
  (* NONE-clock RequireAccess remains fresh under this update. Exact staging
     equality must nevertheless refuse the old descriptor before the reducer. *)
  val _=rejects "Old source observation was accepted again at staging"
    (fn()=>Owner.prepare(Conversation source));
  val _=Roots.release_event source;
  val _=Roots.release_prepared turn;
  val fresh=case Frontdoor.prepare_math{session=sid,version=0,bytes="the product of 6 and 7",
      selection=NONE,local_policy=local_policy,bridge=bridge}of
      Frontdoor.Ready value=>value | _=>error "Updated actual observation did not elaborate";
  val fresh_source=Frontdoor.source_event fresh;
  val _=ignore(Owner.acknowledge(Owner.prepare(Conversation fresh_source)));
  val _=Roots.acknowledged fresh_source;
  val actual_entry=the(Roots.source_entry fresh_source);
  val uid= #utterance(Entry.identity actual_entry);
  val _=ensure(Owner.registration_present(Conversation fresh_source) andalso
    #observation(Entry.snapshot actual_entry)=changed andalso
    not(Owner.conversation_source_visible(sid,uid)))
    "Acknowledged source lost exact observation or became transcript before RecordUtterance";
  fun consume event=let val candidate=Owner.prepare event
      val commands=Owner.acknowledge candidate
    in(candidate,commands)end;
  val _=consume(Math(fresh,Reserve));
  val record=Frontdoor.record_event fresh;
  val _=consume(Conversation record);
  val _=Roots.release_event record;
  val _=ensure(Owner.conversation_source_visible(sid,uid)) "Actual recorded source was not visible";
  val _=List.app(fn phase=>ignore(consume(Math(fresh,phase))))[Statement,Bridge,Parameter];
  val execution=I.allocate ids;
  val actual_request=Frontdoor.request fresh;
  val actual_names=R.project actual_request;
  val cost=ready(M.modeled_cost(R.family_request actual_request));
  val(_,run)=consume(Math(fresh,Execute{execution=execution,cost=cost}));
  val _=ensure(length run=1) "Scoped actual pure command was not consumed exactly once";
  val output=ready(M.execute(R.executable actual_request)(R.instance actual_request)(R.family_request actual_request));
  val witness=MathGate.specialize ids bridge actual_request execution output;
  val _=consume(Math(fresh,Evidence witness));
  val _=consume(Math(fresh,Publish witness));
  val exact=case Final.inspect witness of Final.ExactCandidate value=>value
    |_=>error "Actual product did not produce a native Exact token";
  val _=ensure(R.retained_live(Final.request exact) andalso not(R.live(Final.request exact)))
    "Math witness provenance accidentally granted dispatch or lost retention";
  val adoption=Frontdoor.adopt fresh[exact];
  val(adopted,_)=consume(Conversation adoption);
  val history=the(F.decode_state(Owner.checkpoint adopted));
  val _=ensure(is_some(Owner.conversation_current_context workspace(sid,1)) andalso
    is_none(Owner.conversation_current_context workspace(sid,0)) andalso
    not(Owner.binding_live(#request_id actual_names)(MathGate.evidence witness)) andalso
    is_some(F.conversation_quote_projection history sid(Final.identity exact)(Final.publication_frame exact)) andalso
    String.isSubstring "42"(Final.html exact))
    "Actual adoption failed CAS advancement or confused historical quotation with current licensing";
  val _=Roots.release_event adoption;
  (* The same actual source may be retained by another native construction,
     but a foreign capsule issuer never passes the sealed conversation Roots.
     A failing final source destructor must remain reachable through R/Scope
     after their public liveness has already been denied. *)
  structure Original=Veri7vn_Original_Session_Source;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure L=Veri7vn_Native_Literals;
  val original_request=Frontdoor.request fresh;
  val original_pin=case Scope.observation(Scope.parent(the(R.scope_child original_request)))of
      Scope.SessionObservation pin=>pin | _=>error "Actual session parent lost its pin";
  val cleanup_entry=Entry.retain actual_entry;
  val cleanup_attempts=Unsynchronized.ref 0;
  val foreign=Original.capture(Original.new_issuer())
    {allocator=ids,input=Entry.input cleanup_entry,pin=original_pin,
     source=Veri7vn_Managed_Provenance.install_host_source ids(Entry.input cleanup_entry),
     development=Entry.development cleanup_entry,on_release=fn()=>
       (cleanup_attempts:= !cleanup_attempts+1;
        if !cleanup_attempts=1 then error "Retry original request source cleanup"
        else Entry.release cleanup_entry)};
  val shadow_parent=Scope.new_session_parent{allocator=ids,policy=policy,source=foreign};
  val shadow_input=Original.input foreign;
  val shadow_child=Scope.new_child shadow_parent{source=L.slice shadow_input
    {start=0,stop=size(L.bytes shadow_input),expected=L.bytes shadow_input},predecessors=[]};
  val shadow_request=case R.elaborate_math_child local_policy shadow_child NONE of
      R.Ready value=>value | _=>error "Actual cleanup request did not elaborate";
  val _=Scope.seal shadow_parent[shadow_child];
  val _=ensure(R.live shadow_request andalso not(Roots.intrinsic_request shadow_request))
    "A foreign original-source issuer acquired conversation authority";
  val _=Scope.release_child shadow_child;
  val _=Scope.release_parent shadow_parent;
  val _=Original.release foreign;
  val _=rejects "Original request source destructor did not exercise failure"
    (fn()=>R.release shadow_request);
  val _=ensure(not(R.live shadow_request) andalso !cleanup_attempts=1)
    "Failed request cleanup resurrected liveness or repeated a destructor";
  val _=R.release shadow_request;
  val _=R.release shadow_request;
  val _=ensure(!cleanup_attempts=2 andalso Entry.retained actual_entry)
    "Request/Scope lost retryable cleanup or released another source owner";
  val _=Roots.release_event fresh_source;
  val _=Roots.release_prepared fresh;
  val _=ensure(Final.live exact andalso not(R.live(Final.request exact)) andalso
    String.isSubstring "42"(Final.html exact))
    "Producer release destroyed retained historical native evidence or revived dispatch";
  val _=MathGate.release witness;
  val _=Roots.close();
  val _=R.release_workspace workspace;
  val _=Display.release_bridge bridge;
  val _=M.release_instance instance;
in val _=writeln "CONVERSATION_NATIVE_CAS_PASS actual_source same_version_clock stage_ack_supersession intrinsic_live fresh_pending_registration actual_refined_execution typed_exact_adoption historical_not_current retained_not_dispatch foreign_capsule_issuer request_scope_cleanup_retry" end
\<close>
end
