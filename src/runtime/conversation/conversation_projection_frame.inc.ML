(* Paste after conversation_metadata_frame.inc.ML INSIDE the SAME F block.
   These records are inert. Native historical HTML must additionally come from
   the SAME live Exact witness whose actual publication is checked below. *)
structure ConversationDisplay=Veri7vn_Conversation_Display;
fun conversation_update_frame original=encode_event(@{code UpdateObservation}(conversation_native_observation original));
fun conversation_display_observation(original:ConversationPin.snapshot):ConversationDisplay.observation=
  {session= #session original,version= #version original,reads= #reads original,
   clock=Option.map(fn{basis,ticks}=>
     let val(kind,origin)=case basis of ConversationPin.Wall text=>("wall",text)
       | ConversationPin.Monotonic text=>("monotonic",text)|ConversationPin.SourceEvent text=>("source_event",text)
     in{kind=kind,origin=origin,ticks=ticks}end)(#evaluation_time original)};
fun conversation_view_status state view=
  if not(@{code accessible}state[@{code session_id}view])then ConversationDisplay.Expired
  else if is_some(@{code conversation_context}state(@{code session_id}view)(@{code session_version}view))
    then ConversationDisplay.Active else ConversationDisplay.Unavailable;
fun conversation_summaries state=
  let val views= @{code session_views}state;
    val selected=take(Int.min(128,length views))views;
    val summaries=map(fn view=>{id=integer(@{code session_id}view),version=integer(@{code session_version}view),
      status=conversation_view_status state view,utterances=length(@{code recorded_utterances}view),
      adopted=length(@{code adopted_bindings}view)}:ConversationDisplay.summary)selected
  in(summaries,length views<=128)end;
fun conversation_summary state sid=
  case find_first(fn view=>integer(@{code session_id}view)=sid)(@{code session_views}state)of NONE=>NONE
  |SOME view=>SOME({id=sid,version=integer(@{code session_version}view),status=conversation_view_status state view,
      utterances=length(@{code recorded_utterances}view),adopted=length(@{code adopted_bindings}view)}:ConversationDisplay.summary);
fun conversation_claim state binding:ConversationDisplay.claim option=
  let val c= @{code binding_claim}binding;
    val evidence= @{code binding_evidence}binding;
    val found=find_first(fn e=> @{code evidence_id}e=evidence andalso
      write(@{code encode_claim}(@{code evidence_claim}e))=write(@{code encode_claim}c))(@{code evidence_table}state);
    fun route @{code KernelConsequence}="kernel_consequence" | route @{code RefinedExecution}="refined_execution"
      | route @{code EvaluationOracle}="oracle_consequence";
    fun kind @{code Mathematical}="mathematical" |kind @{code SourceObservation}="source_observation"
      |kind @{code EngineObservation}="engine_observation" |kind @{code ModelPrediction}="model_prediction"
      |kind @{code TestObservation}="test_observation" |kind @{code Optimization}="optimization";
    fun modality @{code Asserted}="asserted" |modality @{code Conditional}="conditional"
      |modality @{code Quoted}="quoted" |modality @{code Hypothetical}="hypothetical"|modality @{code Fictional}="fictional";
    fun collection @{code Scalar}="scalar"|collection @{code Complete}="complete"
      |collection(@{code Prefix} n)="prefix:"^IntInf.toString(integer n);
    fun optimality @{code Unspecified}="unspecified"|optimality @{code Feasible}="feasible"
      |optimality @{code Optimal}="optimal"|optimality @{code Impossible}="impossible";
    val executable=case @{code executable_generation}c of @{code NoExecution}=>NONE
      | @{code ExecutableGeneration}n=>SOME(integer n)
  in Option.map(fn e=>{claim=integer(@{code claim_id}c),target=integer(@{code target_id}c),
    interpretation=integer(@{code interpretation_id}c),evidence=integer evidence,
    semantic_generation=integer(@{code semantic_generation}c),executable_generation=executable,
    route=route(@{code evidence_route}e),kind=kind(@{code claim_kind}c),modality=modality(@{code claim_modality}c),
    collection=collection(@{code collection_scope}c),optimality=optimality(@{code claim_optimality}c),
    premises=map integer(@{code premises}c),dependencies=map integer(@{code dependencies}c)}:ConversationDisplay.claim)found end;
type conversation_part_projection={goal:IntInf.int,slot:IntInf.int,status:string,
  predecessors:ConversationDisplay.predecessor list,claim:ConversationDisplay.claim option};
type conversation_turn_projection={request:IntInf.int,utterance:IntInf.int,
  observation:ConversationPin.snapshot,parts:conversation_part_projection list};
(* The sealed parent derives these ONLY from actual R.project input_identity and
   the same request's issuer-checked Scope observation. A managed dependency is
   not an original-input association: it may merely be an older observed read. *)
type conversation_native_turn={request:IntInf.int,utterance:IntInf.int,
  observation:ConversationPin.snapshot};
fun conversation_turn_projections state workspace sid(native_originals:conversation_native_turn list)=
  let val originals_bound=length native_originals<=8192 andalso forall(fn {request,utterance,observation}=>
      request>0 andalso utterance>0 andalso #workspace observation=workspace andalso
      #session observation=sid)native_originals;
    val _=guard originals_bound "Conversation native original association/bound";
    val native_originals=distinct(op =)native_originals;
    val view=find_first(fn view=>integer(@{code session_id}view)=sid)(@{code session_views}state);
    val originals=case view of NONE=>[]|SOME view=> @{code recorded_utterances}view;
    val chosen=take(Int.min(128,length originals))originals;
    val budget=Unsynchronized.ref 1024;
    val complete=Unsynchronized.ref(length originals<=128);
    fun predecessor(@{code LogicalDependency}goal)={kind="logical",goal=integer goal}:ConversationDisplay.predecessor
      |predecessor(@{code ArtifactDependency}goal)={kind="artifact",goal=integer goal}:ConversationDisplay.predecessor;
    fun part request goal=
      case @{code goal_output_slot}goal of NONE=>(complete:=false;NONE)
      |SOME slot=>
        let val rid= @{code request_id}request;val gid= @{code goal_id}goal;
          val unavailable=not(@{code parent_accessible}state request) orelse
            not(@{code child_accessible}state goal);
          val adopted=case view of NONE=>[]|SOME view=>filter(fn binding=>
            @{code binding_request}binding=rid andalso @{code binding_goal}binding=gid andalso
            @{code conversation_quotable}state(nat sid)binding)(@{code adopted_bindings}view);
          val claim=case adopted of [binding]=>conversation_claim state binding|_=>NONE;
          val current_original= @{code request_fresh}state request andalso
            (case @{code request_observation}request of @{code RequireObservation}(original,_)=>
              @{code service_exact_observation_current}state original | _=>false);
          val status=if unavailable then "unavailable"else if @{code request_cancelled}request then "cancelled"else case @{code goal_outcome}goal of
              @{code Accepted} _=>if is_some claim then "historical"else if current_original then "pending"else "unavailable"
            | @{code ArtifactReady} _=>"artifact" | @{code AwaitingOutput} _=>"pending"
            | @{code NeedsInput} _=>"inconclusive" | @{code Declined} _=>"declined"
            | @{code Inconclusive} _=>"inconclusive" | @{code Failed} _=>"failed" | @{code Cancelled}=>"cancelled";
        in SOME{goal=integer gid,slot=integer slot,status=status,
          predecessors=map predecessor(@{code goal_dependencies}goal),claim=if unavailable then NONE else claim}:conversation_part_projection option end;
    fun turn uid=
      if !budget=0 orelse not(conversation_source_visible state(sid,integer uid))then(complete:=false;NONE)else
      (case filter(fn actual=> #utterance actual=integer uid)native_originals of
        [actual]=>(case filter(fn request=>integer(@{code request_id}request)= #request actual andalso
            @{code request_session}request=SOME(nat sid) andalso
            member(op =)(@{code request_dependencies}request)uid)(@{code requests}state)of
          [request]=>(case @{code request_observation}request of @{code RequireObservation}(original,NONE)=>
          let val goals= @{code request_goals}request;
            val count=Int.min(64,Int.min(!budget,length goals));
            val selected=take count goals;
            val _=budget:= !budget-count;
            val parts=map_filter(part request)selected;
            val _=if count=length goals andalso length parts=count then()else complete:=false;
            (* A source without its full initial identity prefix cannot fabricate
               slots or dangling dependent parts. Such unqualified input is absent. *)
            val sound=length parts=count andalso not(null parts) andalso
              conversation_snapshot workspace original= #observation actual;
          in if sound then SOME{request=integer(@{code request_id}request),utterance=integer uid,
              observation=conversation_snapshot workspace original,parts=parts}:conversation_turn_projection option
            else(complete:=false;NONE)end
          |_=>(complete:=false;NONE))
        |_=>(complete:=false;NONE))
      |_=>(complete:=false;NONE));
    val turns=map_filter turn chosen
  in(turns,!complete)end;
(* Caller passes a publication obtained from the SAME currently live native
   Exact token used for HTML. Numeric identity equality alone is insufficient. *)
fun conversation_quote_projection state sid
    ({request,goal,slot,evidence}:{request:IntInf.int,goal:IntInf.int,slot:IntInf.int,evidence:IntInf.int})publication=
  case decode_event publication of SOME(@{code StageOutput}(_,@{code ClaimOutput}assignment,NONE))=>
    let val binding= @{code assigned_binding}assignment;
      val exact=integer(@{code binding_request}binding)=request andalso integer(@{code binding_goal}binding)=goal
        andalso integer(@{code binding_evidence}binding)=evidence andalso integer(@{code assigned_slot}assignment)=slot
    in if exact andalso @{code conversation_quotable}state(nat sid)binding then conversation_claim state binding else NONE end
  | _=>NONE;
