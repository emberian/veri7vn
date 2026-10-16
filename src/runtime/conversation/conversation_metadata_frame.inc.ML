(* Paste INSIDE the one Veri7vn_Metadata_Frame generated block. Do not ML_file
   separately: every code antiquotation must share the actual reducer universe.
   These are inert projection/encoding helpers; only native Roots + Owner stage
   checks can turn them into a committed native association. *)
structure ConversationPin=Veri7vn_Native_Observation_Pin;
structure ConversationEncoding=Veri7vn_Native_Recovery_Encoding;
fun conversation_chars raw=map(Veri7vn_Characters.char_of_integer o IntInf.fromInt o Char.ord)(String.explode raw);
fun conversation_string chars=
  (guard(length chars<=256) "Conversation source clock bound";
   String.implode(map(fn value=>let val n=Veri7vn_Characters.integer_of_char value
     in guard(n>=0 andalso n<=255) "Conversation source clock nonbyte";Char.chr(IntInf.toInt n)end)chars));
fun conversation_snapshot_bound(original:ConversationPin.snapshot)=
  let val _=guard(size(#workspace original)=32 andalso forall(fn c=>Char.isDigit c orelse
      (#"a"<=c andalso c<= #"f"))(String.explode(#workspace original))) "Conversation native workspace";
    fun natural n=n>=0 andalso size(IntInf.toString n)<=128;
    val _=guard(#session original>0 andalso natural(#session original) andalso natural(#version original)
      andalso length(#reads original)<=256 andalso
      length(distinct(op =)(map fst(#reads original)))=length(#reads original) andalso
      forall(fn(id,version)=>id>0 andalso natural id andalso natural version)(#reads original))
      "Conversation original observation bound";
  in case #evaluation_time original of NONE=>()|SOME{basis,ticks}=>
    let val origin=case basis of ConversationPin.Wall name=>name | ConversationPin.Monotonic name=>name
          | ConversationPin.SourceEvent name=>name
    in guard(size origin<=256 andalso ConversationEncoding.utf8 origin andalso
      size(IntInf.toString(IntInf.abs ticks))<=128) "Conversation original clock encoding/bound"end end;
fun conversation_native_observation(original:ConversationPin.snapshot)=
  let val _=conversation_snapshot_bound original;
    fun origin(ConversationPin.Wall name)= @{code Wall}(conversation_chars name)
      | origin(ConversationPin.Monotonic name)= @{code Monotonic}(conversation_chars name)
      | origin(ConversationPin.SourceEvent name)= @{code Source_Event}(conversation_chars name);
    val evaluated=Option.map(fn{basis,ticks}=> @{code conversation_clock}(origin basis)
      (Veri7vn_Numerals.int_of_integer ticks))(#evaluation_time original)
  in @{code conversation_observation}(nat(#session original))(nat(#version original)) evaluated
    (map(fn(id,version)=>(nat id,nat version))(#reads original))end;
fun conversation_snapshot workspace context:ConversationPin.snapshot=
  let fun origin(@{code Wall} chars)=ConversationPin.Wall(conversation_string chars)
        | origin(@{code Monotonic} chars)=ConversationPin.Monotonic(conversation_string chars)
        | origin(@{code Source_Event} chars)=ConversationPin.SourceEvent(conversation_string chars);
    val evaluated=Option.map(fn clock=>{basis=origin(@{code basis} clock),
      ticks=Veri7vn_Numerals.integer_of_int(@{code ticks} clock)})(@{code evaluation_time} context);
    val original={workspace=workspace,session=integer(@{code observed_session} context),
      version=integer(@{code observed_version} context),evaluation_time=evaluated,
      reads=map(fn(id,version)=>(integer id,integer version))(@{code observed_reads} context)}:ConversationPin.snapshot;
    val _=conversation_snapshot_bound original
  in original end;
fun conversation_observation_bytes original=write(@{code encode_observation_context}(conversation_native_observation original));
fun conversation_observation_from_bytes workspace bytes=
  (case @{code decode_observation_context}(read bytes)of NONE=>error "Conversation original observation schema"
  | SOME original=>(guard(write(@{code encode_observation_context}original)=bytes)
      "Noncanonical conversation observation";conversation_snapshot workspace original));
fun conversation_current_context state workspace(sid,version)=
  (guard(sid>0 andalso version>=0 andalso size(IntInf.toString sid)<=128 andalso
    size(IntInf.toString version)<=128) "Conversation context lookup bound";
  Option.map(conversation_snapshot workspace)(@{code conversation_context}state(nat sid)(nat version)));
fun conversation_session_exists state sid=exists(fn view=>integer(@{code session_id}view)=sid)(@{code session_views}state);
fun conversation_source_visible state(sid,uid)=sid>0 andalso uid>0 andalso
  @{code conversation_input_visible}state(nat sid)(nat uid);
fun conversation_create_frame sid=(guard(sid>0) "Conversation create identity";
  encode_event(@{code conversation_create}(nat sid)));
type conversation_source_snapshot={identity:{workspace:string,session:IntInf.int,utterance:IntInf.int},
  observation:ConversationPin.snapshot,encoding:string,bytes:string};
fun conversation_source_frame(original:conversation_source_snapshot)source_dependencies=
  let val identity= #identity original;val observed= #observation original;
    val _=guard(#workspace identity= #workspace observed andalso #session identity= #session observed andalso
      #utterance identity>0 andalso size(#bytes original)<=256 andalso
      ConversationEncoding.valid(#encoding original)(#bytes original) andalso
      not(null source_dependencies) andalso length source_dependencies<=8192 andalso
      forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)source_dependencies andalso
      length(distinct(op =)source_dependencies)=length source_dependencies) "Conversation source association/bound"
  in encode_event(@{code conversation_input}(conversation_native_observation observed)
    (nat(#utterance identity))(map nat source_dependencies))end;
fun conversation_record_frame{session,request,utterance}=
  (guard(forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)[session,request,utterance])
    "Conversation original record identity";
   encode_event(@{code RecordUtterance}(nat session,nat utterance)));
fun conversation_adoption_frame{request,nonce,observation,selected}=
  let val _=guard(request>0 andalso nonce>0 andalso not(null selected) andalso length selected<=64)
      "Conversation native exact adoption bound";
    fun binding({identity,publication}:{identity:{request:IntInf.int,goal:IntInf.int,slot:IntInf.int,evidence:IntInf.int},
        publication:string})=
      let
        val _=guard(#request identity=request) "Conversation exact belongs to another native request";
        val event=decode_event publication
      in case event of SOME(@{code StageOutput}(_,@{code ClaimOutput} assignment,NONE))=>
          let val actual= @{code assigned_binding}assignment
          in guard(integer(@{code binding_request}actual)= #request identity andalso
            integer(@{code binding_goal}actual)= #goal identity andalso
            integer(@{code binding_evidence}actual)= #evidence identity andalso
            integer(@{code assigned_slot}assignment)= #slot identity)
            "Conversation native exact/publication binding mismatch";actual end
        | _=>error "Conversation adoption needs actual native exact claim publication"end;
    val bindings=map binding selected
  in encode_event(@{code conversation_proposed_adoption}(conversation_native_observation observation)
    (nat request)(nat nonce)bindings)end;
fun conversation_adoption_event_matches state frame=(case decode_event frame of
  SOME event=> @{code conversation_adoption_matches}state event|NONE=>false);
fun conversation_record_event_matches state{observation,request,input}proposed=
  (case @{code decode_observation_context}(read observation)of NONE=>false | SOME original=>
    write(@{code encode_observation_context}original)=observation andalso
    @{code service_exact_observation_current}state original andalso
    (case @{code conversation_record}state(@{code observed_session}original)(nat request)(nat input)of
      NONE=>false | SOME expected=>encode_event expected=proposed));
fun conversation_expire_frame sid=(guard(sid>0) "Conversation expiry identity";
  encode_event(@{code Revoke}(nat sid)));
(* The immutable source role is checked against the C-authenticated checkpoint,
   not the mutable current Owner. The fixed factory separately rechecks actual
   native context/head/full dependencies and image before any pool acquisition. *)
fun conversation_source_material_matches checkpoint(metadata:Veri7vn_Session_Input_Codec.metadata)=
  case decode_state checkpoint of NONE=>NONE | SOME state=>
    Option.map(fn recorded=>{recorded=recorded})(@{code conversation_source_phase}state
      (nat(#utterance metadata))(conversation_native_observation(#observation metadata))
      (map nat(#source_dependencies metadata)));
(* Separate D65 inventory: generation is intentionally absent. The whole exact
   row stays inside this generated universe, while the host routes only uid/phase. *)
type conversation_source_requirement={association:IntInf.int,recorded:bool};
fun conversation_required_source_inputs state:conversation_source_requirement list=
  map(fn(uid,(_,(_,recorded)))=>{association=integer uid,recorded=recorded})
    (@{code conversation_required_inputs}state);
fun conversation_source_association_matches state registration recorded=
  (case decode_event registration of SOME(@{code RegisterManaged}value)=>
    exists(fn(uid,(expected,(_,phase)))=>uid= @{code retained_id}value andalso
      encode_event(@{code RegisterManaged}expected)=registration andalso phase=recorded)
      (@{code conversation_required_inputs}state)
  | _=>false);
(* Fresh-event adapters only. The caller derives source_dependencies from the
   SAME retained Entry used at original R construction. The generated binders
   reject missing original dependencies instead of adding them to a claim. *)
fun conversation_bind_frame original source_dependencies bind frame=
  let val _=guard(not(null source_dependencies) andalso length source_dependencies<=8192 andalso
      forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)source_dependencies andalso
      length(distinct(op =)source_dependencies)=length source_dependencies)
      "Conversation original source dependency bound";
    val observed=conversation_native_observation original;
    val deps=map nat source_dependencies;
    val event=case decode_event frame of SOME value=>value|NONE=>error "Conversation native event schema"
  in case bind observed deps event of SOME adapted=>encode_event adapted
    |NONE=>error "Conversation original source closure/event mismatch"end;
fun conversation_bind_reserve_frame original source_dependencies frame=
  conversation_bind_frame original source_dependencies @{code conversation_bind_reserve} frame;
fun conversation_bind_parameter_frame original source_dependencies{request,input}frame=
  (guard(request>0 andalso input>0) "Conversation original parameter identity";
   conversation_bind_frame original source_dependencies
     (fn observed=>fn deps=> @{code conversation_bind_parameter}observed deps(nat request)(nat input))frame);
fun conversation_bind_output_frame original source_dependencies{request,parameter}frame=
  (guard(request>0 andalso parameter>0) "Conversation original output identity";
   conversation_bind_frame original source_dependencies
     (fn observed=>fn deps=> @{code conversation_bind_output}observed deps(nat request)(nat parameter))frame);
