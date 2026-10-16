(* All code antiquotations share this block's generated carrier types. *)
structure Veri7vn_Metadata_Frame =
struct
(* This exact loaded generated unit implements the closed statement checker and
   original-capture reconstruction. The opaque bridge admits its contract and
   binds this actual pin/context, rather than a profile name. *)
val statement_code_theory = @{theory};
val statement_pin = Veri7vn_Executable_Identity.pin statement_code_theory
  {artifact="veri7vn.fixed-math-statement/1",compiler="Isabelle code generator / PolyML",
   target="Eval (SML)",serializers=["binary captures / native math_expr", "bounded HTML bytes"],
   foreign_primitives=[],settings=["one shared generated metadata/language/checker universe"]};
fun statement_executable () = statement_pin;
val max_bytes = 1048576;
val max_nodes = 65536;
val max_depth = 64;
val max_digits = 128;
fun guard true _ = () | guard false message = error message;
fun nat n = Veri7vn_Numerals.nat_of_integer n;
fun integer n = Veri7vn_Numerals.integer_of_nat n;
structure Wire=Veri7vn_Native_Authority_Wire;
fun read bytes =
  let fun convert (Wire.Atom value)= @{code WireNat}(nat value)
        | convert (Wire.Node(tag,children))=
            @{code WireNode}(nat(IntInf.fromInt tag),map convert children)
  in convert(Wire.read bytes)end;
fun write value = Wire.write_with
  (fn @{code WireNat} number=>Wire.Natural(integer number)
    | @{code WireNode}(tag,children)=>Wire.Branch(integer tag,children)) value;
(* Only an opaque native admission descriptor may supply this internally derived
   projection; decoded wire/client records are never passed to this function. *)
fun make_native_claim {claim_id, target_id, interpretation_id, conditional,
    premises, dependencies, semantic_generation} =
  let
    fun n i = (guard (i >= 0) "negative native identity"; nat i);
  in @{code native_claim_projection} (n claim_id) (n target_id) (n interpretation_id)
      conditional (map n premises) (map n dependencies) (n semantic_generation) end;
fun make_attach_native_evidence (id, claim, dependencies) =
  (guard (id > 0 andalso length dependencies < 8192 andalso forall (fn n=>n>0) dependencies) "native evidence closure bound";
   @{code service_attach_native_evidence} (nat id) claim (map nat dependencies));
val initial_state = @{code initial_state};
fun step state event = @{code step} state event;
(* The actual generated reducer predicts a post-ack image on an immutable copy.
   No state is installed by this function and no native associations are invented. *)
fun prepare state event =
  let
    val (staged, commands) = step state event;
    val (candidate, ack) =
      (case commands of
        [@{code Persist} batch] =>
          let
            val acknowledgement = @{code DurableAck}
              (@{code batch_id} batch, @{code Suc} (@{code expected_revision} batch),
               @{code batch_epoch} batch);
            val (final, responses) = step staged acknowledgement;
            val _ = (case responses of [@{code Visible} _] => ()
              | _ => error "generated precommit acknowledgement rejected");
          in (final, SOME acknowledgement) end
      | _ => (staged, NONE));
  in (staged, candidate, commands, ack) end;
fun revision state = integer (@{code revision} state);
fun epoch state = integer (@{code authority_epoch} state);
(* Inspection of actual generated commands, not a constructor for dispatch authority.
   Service must retain the current native candidate and registered artifact pins. *)
type cost_view={profile:IntInf.int,code_generation:IntInf.int,operation:IntInf.int,
  step:IntInf.int,units:IntInf.int};
fun cost_view cost : cost_view =
  {profile=integer (@{code cost_profile} cost),code_generation=integer (@{code cost_code_generation} cost),
   operation=integer (@{code cost_operation} cost),step=integer (@{code cost_step} cost),units=integer (@{code cost_units} cost)};
type claim_start = {attempt:IntInf.int,request:IntInf.int,target:IntInf.int,
  capability:IntInf.int,sources:IntInf.int list,dependencies:IntInf.int list,
  prestate:IntInf.int,epoch:IntInf.int,cost:cost_view};
fun claim_starts commands : claim_start list = map_filter (fn
    @{code ClaimStart} (intent, epoch) => SOME
      {attempt=integer (@{code attempt_id} intent),
       request=integer (@{code attempt_request} intent),
       target=integer (@{code attempt_target} intent),
       capability=integer (@{code attempt_capability} intent),
       sources=map integer (@{code attempt_sources} intent),
       dependencies=map integer (@{code attempt_dependencies} intent),
       prestate=integer (@{code attempt_prestate} intent), epoch=integer epoch,
       cost=cost_view (@{code attempt_cost} intent)}
  | _ => NONE) commands;
type pure_run = {execution:IntInf.int,request:IntInf.int,slot:IntInf.int,
  cost:cost_view,inputs:IntInf.int list};
datatype command_view = EffectStart of claim_start |
  PureRun of pure_run |
  JobRun of {job:IntInf.int,request:IntInf.int,source:IntInf.int,capability:IntInf.int,
    incarnation:IntInf.int} |
  StopRequest of IntInf.int | RemoveManaged of IntInf.int |
  AuthorityChanged of IntInf.int | UnsupportedCommand;
(* Exhaustive at the bridge: an unknown generated command must never disappear
   before the service decides whether the post-ack handoff is implemented. *)
fun command_views commands = maps (fn
    @{code RunPure} run=>SOME (PureRun
      {execution=integer (@{code execution_id} run),request=integer (@{code execution_request} run),
       slot=integer (@{code execution_slot} run),cost=cost_view (@{code execution_cost} run),
       inputs=map integer (@{code execution_inputs} run)}) |> the_list
  | @{code RunJob} job=>SOME (JobRun
      {job=integer (@{code job_id} job),request=integer (@{code job_owner} job),
       source=integer (@{code job_source} job),capability=integer (@{code job_capability} job),
       incarnation=integer (@{code job_incarnation} job)}) |> the_list
  | @{code StopRequest} n=>[StopRequest (integer n)]
  | @{code RemoveManaged} n=>[RemoveManaged (integer n)]
  | @{code AuthorityChanged} n=>[AuthorityChanged (integer n)]
  | @{code Persist} _=>[]
  | @{code Visible} _=>[]
  | command=>(case claim_starts [command] of [value]=>[EffectStart value]
      | _=>[UnsupportedCommand])) commands;
fun rejected commands = exists (fn @{code Rejected} _ => true | _ => false) commands;
(* Accepted-output entrypoint; raw historical render helpers are not exposed here. *)
val authoritative_render = @{code authoritative_render};
fun byte_naturals raw = (guard (size raw <= 256) "interpretation input byte bound";
  map (nat o IntInf.fromInt o Char.ord) (String.explode raw));
fun bounded_offset n =
  let val value=integer n
  in guard (value >= 0 andalso value <= 256) "interpretation offset bound";
    IntInf.toInt value end;
fun interpretation_packet_bytes raw =
  let
    val (applicable, (budget, (alternatives, blocked))) =
      @{code interpretation_packet} (byte_naturals raw);
    fun span (start, stop) = (bounded_offset start, bounded_offset stop);
    fun alternative (operation, spans) =
      (bounded_offset operation, map span spans);
  in (applicable, budget, map alternative alternatives, map (map span) blocked) end;
fun math_expression_bytes raw index =
  (guard (index >= 0 andalso index <= 255) "interpretation selection bound";
   Option.map @{code "Code_Evaluation.term_of :: math_expr => Code_Evaluation.term"}
     (@{code math_expression_at} (byte_naturals raw) (nat (IntInf.fromInt index))));
fun captured_binary_expression number a b =
  (guard(number>=0 andalso number<=4 andalso
    forall(fn n=>size(IntInf.toString n)<=256)[a,b]) "Captured binary expression bound";
   Option.map @{code "Code_Evaluation.term_of :: math_expr => Code_Evaluation.term"}
     (@{code captured_binary_expression} (nat(IntInf.fromInt number))
       (Veri7vn_Numerals.int_of_integer a) (Veri7vn_Numerals.int_of_integer b)));
fun output_bytes cap values =
  (guard (length values <= cap) "generated byte output bound";
   String.implode (map (fn n => let val value=integer n in
     guard (value >= 0 andalso value <= 255) "generated nonbyte output";
     Char.chr (IntInf.toInt value) end) values));
fun escape_html_bytes raw =
  let val input=byte_naturals raw in
    case @{code bounded_escape} (nat 256) (nat 1536) input of
      SOME values => output_bytes 1536 values | NONE => error "HTML escape bound"
  end;
fun checked_statement_bytes (kind, parameters) raw =
  (guard (kind >= 0 andalso kind <= 3 andalso length parameters <= 4 andalso
      forall (fn n => size (IntInf.toString n) <= 513) parameters) "statement template bound";
   guard (size raw <= 16384) "statement input byte bound";
   Option.map (output_bytes 65536)
     (@{code checked_statement} (nat (IntInf.fromInt kind), map Veri7vn_Numerals.int_of_integer parameters)
       (map (nat o IntInf.fromInt o Char.ord) (String.explode raw))));
fun read_integer_bytes raw =
  Option.map Veri7vn_Numerals.integer_of_int (@{code read_integer} (byte_naturals raw));
fun binary_checked_statement_bytes number a b numerator denominator raw =
  (guard (number>=0 andalso number<=4 andalso size raw<=16384 andalso
     forall (fn n=>size(IntInf.toString n)<=513) [a,b,numerator,denominator])
     "Binary statement bound";
   Option.map (output_bytes 65536) (@{code binary_checked_statement}
     (nat(IntInf.fromInt number)) (Veri7vn_Numerals.int_of_integer a) (Veri7vn_Numerals.int_of_integer b)
     (Veri7vn_Numerals.int_of_integer numerator) (Veri7vn_Numerals.int_of_integer denominator)
     (map (nat o IntInf.fromInt o Char.ord) (String.explode raw))));
fun encode_state state = write (@{code encode_checkpoint} state);
fun decode_state bytes = @{code decode_checkpoint} (read bytes);
(* Diagnose an incompatible sealed format before decoding any state. The exact
   expected tag and schema come from this loaded generated codec. *)
fun decode_state_checked bytes=
  let val wire=read bytes;
    val expected= @{code encode_checkpoint}initial_state;
    val _=(case (wire,expected)of
      (@{code WireNode}(actual,[ @{code WireNat}actual_schema,_]),
       @{code WireNode}(wanted,[ @{code WireNat}wanted_schema,_]))=>
        (guard(actual=wanted)("Native checkpoint codec version mismatch: expected " ^
          IntInf.toString(integer wanted) ^ ", actual " ^ IntInf.toString(integer actual));
         guard(actual_schema=wanted_schema)("Native checkpoint schema mismatch: expected " ^
          IntInf.toString(integer wanted_schema) ^ ", actual " ^ IntInf.toString(integer actual_schema)))
      |_=>error "Native checkpoint has no canonical sealed codec header")
  in @{code decode_checkpoint}wire end;
fun encode_event event = write (@{code encode_event_frame} event);
fun decode_event bytes = @{code decode_event_frame} (read bytes);
(* Closed staging conditions carried by actual native descriptors. The Owner
   evaluates them against the same current state used to prepare the event. *)
datatype current_expectation=NoCurrentExpectation | ExactObservation of string |
  ExactConversationRecord of {observation:string,request:IntInf.int,input:IntInf.int};

(* Paste in the EXISTING Veri7vn_Metadata_Frame generated unit after encode_event.
   Never ML_file separately: these terms must share the reducer carrier universe.
   Only actual private Build/Scope handles or C-checked witnesses supply snapshots. *)
type build_control_names={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
  interpretation:IntInf.int,decision:IntInf.int,parameter:IntInf.int,candidate:IntInf.int,
  execution:IntInf.int,capability:IntInf.int,step:IntInf.int,operation:IntInf.int,
  code_generation:IntInf.int,semantic_generation:IntInf.int};
type build_native_projection={template:IntInf.int,source_owner:IntInf.int,source_revision:IntInf.int,
  manifest:IntInf.int,parents:IntInf.int list,profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,
  candidate:IntInf.int,lineage:IntInf.int,dependencies:IntInf.int list};
fun build_control(n:build_control_names)=
  (guard(forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)
    [#request n,#goal n,#slot n,#interpretation n,#decision n,#parameter n,#candidate n,
     #execution n,#capability n,#step n,#operation n,#code_generation n,#semantic_generation n])
     "Build control identity";
   @{code build_service_control}(nat(#request n))(nat(#goal n))(nat(#slot n))(nat(#parameter n))
     (nat(#semantic_generation n))(nat(#code_generation n))(nat(#candidate n))(nat(#execution n)));
fun build_plan(n:build_control_names)=
  @{code build_service_plan}(build_control n)(nat(#interpretation n))(nat(#capability n))
    (nat(#operation n))(nat(#step n));
fun build_requirement(p:build_native_projection)=
  @{code build_service_requirement}(nat(#template p))(nat(#source_owner p))(nat(#source_revision p))
    (nat(#manifest p))(map(fn id=> @{code KnownInput}(nat id)) (#parents p))
    (nat(#profile p))(nat(#setup p))(nat(#export_intent p));
fun build_deferred_requirement(p:Veri7vn_Native_Deferred_Build_Types.plan)=
  let val source= #source p
    fun parent(Veri7vn_Native_Deferred_Build_Types.Installed _)=NONE
      |parent(Veri7vn_Native_Deferred_Build_Types.KnownCandidate{candidate,...})=
        SOME(@{code KnownInput}(nat candidate))
      |parent(Veri7vn_Native_Deferred_Build_Types.ReservedOutput{slot,...})=
        SOME(@{code ReservedOutput}(nat slot))
  in @{code build_service_requirement}(nat(#template p))(nat(#source_owner source))
    (nat(#source_revision source))(nat(#manifest source))(map_filter parent(#parents p))
    (nat(#profile p))(nat(#setup p))(nat(#export_intent source))end;
fun build_intrinsic_frame id=(guard(id>0) "Build intrinsic identity";
  encode_event(@{code build_service_intrinsic}(nat id)));
fun build_parent_identity (n:build_control_names) parent original=
  guard(integer(@{code request_id}parent)= #request n andalso
    member(op =)(@{code request_goals}parent)original andalso
    integer(@{code goal_id}original)= #goal n andalso
    integer(@{code goal_interpretation}original)= #interpretation n andalso
    integer(@{code goal_capability}original)= #capability n andalso
    integer(@{code goal_generation}original)= #semantic_generation n andalso
    integer(@{code goal_code_generation}original)= #code_generation n andalso
    @{code goal_output_slot}original=SOME(nat(#slot n))) "Build original parent/child differs";
fun build_parameter_frame n parent original closure reads accesses=
  (build_parent_identity n parent original;encode_event(@{code build_service_parameter}(build_control n)parent original(map nat closure)(map nat reads)accesses));
fun build_child n required predecessor_goals=
  @{code build_service_child}(build_plan n)required
    (map(fn id=> @{code ArtifactDependency}(nat id))predecessor_goals);
fun build_slot n required reserved=
  @{code build_service_slot}(build_plan n)required(map nat reserved);
fun build_execute_frame n required inputs=
  encode_event(@{code build_service_execute}(build_plan n)required(map nat inputs));
fun build_artifact_frame n parent original required native_generation closure inputs scope accesses=
  (build_parent_identity n parent original;
   encode_event(@{code build_service_artifact}(build_control n)parent original required(nat native_generation)
     (map nat closure)(map nat inputs)scope accesses));
fun build_request_matches state n required inputs=
  @{code build_service_request_matches}state(build_plan n)required(map nat inputs);
fun build_retained_request_matches state n required inputs=
  @{code build_service_retained_request_matches}state(build_plan n)required(map nat inputs);
fun build_paid_matches state n required inputs=
  @{code build_service_paid_matches}state(build_plan n)required(map nat inputs);
fun build_candidate_matches state n required inputs native_generation parents=
  @{code build_service_candidate_matches}state(build_plan n)required(map nat inputs)(nat native_generation)
    (map(fn(candidate,generation)=>(nat candidate,nat generation))parents);
fun build_failure_matches state n required inputs reason=
  @{code build_service_failure_matches}state(build_plan n)required(map nat inputs)(nat reason);
(* Candidate-role metadata lacks decision/operation names by design. Query the
   SINGLE actual original child/slot/paid run; never fabricate a decision ID. *)
fun build_native_plan state (m:Veri7vn_Native_Development_Codec.metadata)=
  @{code build_service_native_plan}state(nat(#request m))(nat(#goal m))(nat(#slot m))
    (nat(#lineage m))(nat(#candidate m));
fun build_native_candidate_matches state (m:Veri7vn_Native_Development_Codec.metadata) parents=
  case build_native_plan state m of NONE=>false|SOME plan=>
    let val required= @{code build_service_requirement}(nat(#template m))(nat(#source_owner m))
      (nat(#source_revision m))(nat(#manifest m))(map(fn id=> @{code KnownInput}(nat id)) (#parents m))
      (nat(#profile m))(nat(#setup m))(nat(#export_intent m))
    in integer(@{code bsc_generation}(@{code bsp_control}plan))= #charged_generation m andalso
      @{code build_service_candidate_matches}state plan required(map nat(#input_bindings m))
      (nat(#semantic_generation m))(map(fn(id,context)=>(nat id,nat context))parents)end;
fun build_native_control_values state m=
  Option.map(fn plan=>let val n= @{code bsp_control}plan
    in map integer [@{code bsp_interpretation}plan,@{code bsp_capability}plan,
      @{code bsp_operation}plan,@{code bsp_step}plan,@{code bsc_code}n,
      @{code bsc_generation}n,@{code bsc_parameter}n]end)(build_native_plan state m);

fun build_reserve_frame n required prestate fuel deps=
  encode_event(@{code service_build_reserve}(build_plan n)required
    (nat prestate)(nat fuel)(map nat deps));

fun build_singleton_original n required prestate deps =
  (case @{code service_build_reserve}(build_plan n)required(nat prestate)(nat 1)(map nat deps)of
    @{code ReserveRequest}(parent,_) =>
      (case @{code request_goals}parent of [original] => (parent,original)
      | _=>error "Native Build reserve must have one original child")
  | _=>error "Native Build reserve constructor differs");
fun build_singleton_parameter_frame n required prestate deps closure inputs accesses=
  let val(parent,original)=build_singleton_original n required prestate deps
  in build_parameter_frame n parent original closure inputs accesses end;
fun build_singleton_artifact_frame n required prestate deps generation closure inputs accesses=
  let val(parent,original)=build_singleton_original n required prestate deps
  in build_artifact_frame n parent original required generation closure inputs
    (@{code RequestLocal}(nat(#request n)))accesses end;
fun build_outcome_frame(n:build_control_names)reason=encode_event
  (@{code SetOutcome}(nat(#request n),nat(#goal n),@{code Failed}(nat reason)));

fun build_names_from_plan(p:Veri7vn_Native_Deferred_Build_Types.plan):build_control_names=
  {request= #request p,goal= #goal p,slot= #slot p,interpretation= #interpretation p,
   decision= #decision p,parameter= #parameter p,candidate= #candidate p,
   execution= #execution p,capability= #capability p,step= #step p,operation= #operation p,
   code_generation= #code_generation p,semantic_generation= #operation_generation p};
fun build_projection_from_metadata(m:Veri7vn_Native_Development_Codec.metadata):build_native_projection=
  {template= #template m,source_owner= #source_owner m,source_revision= #source_revision m,
   manifest= #manifest m,parents= #parents m,profile= #profile m,setup= #setup m,
   export_intent= #export_intent m,candidate= #candidate m,lineage= #lineage m,
   dependencies= #dependencies m};
(* Native factory checks the full original source/recipe/control correspondence
   independently. This query checks those exact associations in the checkpoint. *)
fun build_checkpoint_matches checkpoint candidate
    (m:Veri7vn_Native_Development_Codec.metadata)
    (payload:Veri7vn_Native_Development_Codec.payload) request=
  (case decode_state checkpoint of NONE=>false | SOME state=>
    if candidate then is_none request andalso
      build_native_candidate_matches state m
        (map_filter(fn(NONE,_,_)=>NONE| (SOME id,head,_)=>SOME(id,head))
          (#parent_bindings payload))
    else case request of NONE=>false | SOME packet=>
      let val control= #plan(packet:Veri7vn_Native_Build_Request_Envelope.packet);
        val names=build_names_from_plan control;
        val required=build_requirement(build_projection_from_metadata m);
        val original=build_deferred_requirement control;
        val original_matches= @{code service_build_original_matches}state
          (nat(#request control))(nat(#goal control))(nat(#slot control))original;
        val current=build_retained_request_matches state names required (#input_bindings m);
      in original_matches andalso current andalso
        (case #phase packet of Veri7vn_Native_Build_Request_Envelope.Prepared=>true
        | Veri7vn_Native_Build_Request_Envelope.ObservedFailure failure=>
            build_failure_matches state names required (#input_bindings m)(#reason failure))end);

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

fun current_expectation_matches _ NoCurrentExpectation=true
  | current_expectation_matches state (ExactObservation bytes)=
      (case @{code decode_observation_context}(read bytes)of NONE=>false
      |SOME context=>write(@{code encode_observation_context}context)=bytes andalso
        @{code service_exact_observation_current}state context)
  | current_expectation_matches state (ExactConversationRecord{observation,...})=
      current_expectation_matches state (ExactObservation observation);
fun current_expectation_event_matches state (ExactConversationRecord original) frame=
      conversation_record_event_matches state original frame
  | current_expectation_event_matches _ _ _=true;

val evidence_only_checkpoint = @{code service_evidence_only_checkpoint};
fun evidence_matches state bytes = (case decode_event bytes of
  SOME event => @{code service_evidence_matches} state event | NONE => false);
fun event_evidence_id bytes = (case decode_event bytes of
  SOME (@{code AttachEvidence} evidence)=>SOME (integer (@{code evidence_id} evidence))
  | _=>NONE);
(* Historical quotation is read permission on the exact retained native
   evidence and exact installed assignment. It does not reopen a request or
   re-establish current binding_licensed after cancellation. *)
fun historical_output_access state {evidence,publication}=
  (case (decode_event evidence,decode_event publication)of
    (SOME(@{code AttachEvidence}e),SOME(@{code StageOutput}(_, @{code ClaimOutput}a,NONE)))=>
      let val binding= @{code assigned_binding}a;
        val refs= @{code evidence_managed_dependencies}e @ @{code assigned_dependencies}a;
        fun guarded row=not(member(op =)refs(@{code retained_id}row)) orelse
          (@{code accessible}state(@{code retained_id}row:: @{code retained_dependencies}row) andalso
           forall(@{code observation_fresh}state)(@{code retained_access_requirements}row))
      in evidence_matches state evidence andalso
        @{code binding_evidence}binding= @{code evidence_id}e andalso
        @{code binding_claim}binding= @{code evidence_claim}e andalso
        member(op =)(@{code claim_assignments}state)a andalso
        member(op =)(@{code visible_bindings}state)binding andalso
        @{code accessible}state(@{code assignment_references}(@{code ClaimOutput}a)) andalso
        forall(fn row=>member(op =)(@{code retained_values}state)row)(@{code assigned_retained}a) andalso
        forall guarded(@{code retained_values}state)
      end
  |_=>false);
fun required_evidence_ids state = map (integer o @{code evidence_id})
  (@{code required_native_evidence} state);
type math_names = {request_id:IntInf.int,goal_id:IntInf.int,
  interpretation_id:IntInf.int,decision_id:IntInf.int,capability_id:IntInf.int,
  operation_id:IntInf.int,profile_id:IntInf.int,step_id:IntInf.int,
  requirement_id:IntInf.int,requirement_claim_id:IntInf.int,parameter_id:IntInf.int,
  input_identity:IntInf.int,output_slot_id:IntInf.int,
  executable_generation:IntInf.int,semantic_generation:IntInf.int};
fun math_names (p:math_names) =
  let fun n v=(guard(v>0) "Unregistered native mathematics identity";nat v)
  in @{code service_math_names} (n (#request_id p)) (n (#goal_id p))
    (n (#interpretation_id p)) (n (#capability_id p)) (n (#operation_id p))
    (n (#profile_id p)) (n (#step_id p)) (n (#requirement_id p))
    (n (#requirement_claim_id p)) (n (#parameter_id p)) (n (#input_identity p))
    (n (#output_slot_id p)) (n (#executable_generation p)) (n (#semantic_generation p)) end;
fun math_input_frame names=encode_event
  (@{code service_math_input} (math_names names));
fun math_parameter_frame names deps=encode_event
  (@{code service_math_parameter} (math_names names) (map nat deps));
fun math_reserve_frame names prestate fuel deps=encode_event
  (@{code service_math_reserve} (math_names names) (nat prestate) (nat fuel) (map nat deps));
fun math_execute_frame names execution cost=encode_event
  (@{code service_math_execute} (math_names names) (nat execution) (nat cost));
type math_bridge_names={bridge_id:IntInf.int,statement_code_id:IntInf.int,semantic_generation:IntInf.int};
fun math_statement_frame names (bridge:math_bridge_names)=encode_event
  (@{code service_math_statement_code}(math_names names)(nat(#bridge_id bridge))(nat(#statement_code_id bridge)));
fun math_bridge_frame names (bridge:math_bridge_names)=encode_event
  (@{code service_math_bridge}(math_names names)(nat(#bridge_id bridge))(nat(#statement_code_id bridge)));
fun registration_present state frame=(case decode_event frame of SOME event=>
  @{code service_registration_present}state event | NONE=>false);
fun math_evidence_frame names deps managed {claim,target,evidence}=encode_event
  (@{code service_math_evidence} (math_names names) (map nat deps) (map nat managed)
    (nat claim) (nat target) (nat evidence));
fun math_publish_frame names deps managed {claim,target,evidence,output,execution,batch}=encode_event
  (@{code service_math_publish} (math_names names) (map nat deps) (map nat managed)
    (nat claim) (nat target) (nat evidence) (nat output) (nat execution) (nat batch));
(* Fixed historical capsule check before reconstruction acquires source/native
   owners. Cancellation does not rewrite the original IDs or charged lineage. *)
fun math_historical_source_matches state names (bridge:math_bridge_names) (output_names:{claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,output:IntInf.int,execution:IntInf.int,batch:IntInf.int})=
  let val base=[#input_identity names,#parameter_id names,#requirement_id names,#capability_id names,
        #operation_id names,#profile_id names,#executable_generation names,#semantic_generation names];
    val bridges=[#bridge_id bridge,#statement_code_id bridge,#semantic_generation bridge];
    val prerequisites=distinct(op =)(base @ bridges);
    val deps=distinct(op =)(#output output_names:: #execution output_names::prerequisites);
    val owned=[#request_id names,#goal_id names,#interpretation_id names,#decision_id names,
      #capability_id names,#operation_id names,#profile_id names,#step_id names,#requirement_id names,
      #requirement_claim_id names,#parameter_id names,#input_identity names,#output_slot_id names,
      #executable_generation names,#semantic_generation names];
    val managed=distinct(op =)([#claim output_names,#target output_names,#evidence output_names,
      #output output_names,#execution output_names,#batch output_names]@owned@bridges);
    val evidence=math_evidence_frame names deps managed
      {claim= #claim output_names,target= #target output_names,evidence= #evidence output_names};
    val publication=math_publish_frame names deps managed output_names;
    val runs=filter(fn run=>integer(@{code execution_id}run)= #execution output_names)
      (@{code service_execution_for}state(nat(#request_id names)));
    fun charged run=let val c= @{code execution_cost}run in
      integer(@{code execution_slot}run)= #output_slot_id names andalso
      map integer(@{code execution_inputs}run)=[#parameter_id names] andalso
      integer(@{code cost_profile}c)= #profile_id names andalso
      integer(@{code cost_code_generation}c)= #executable_generation names andalso
      integer(@{code cost_operation}c)= #operation_id names andalso
      integer(@{code cost_step}c)= #step_id names andalso integer(@{code cost_units}c)>0 end
  in @{code service_math_request_matches}state(math_names names)(map nat prerequisites)(nat 0) andalso
    (case runs of [run]=>charged run|_=>false) andalso evidence_matches state evidence andalso
    (case decode_event publication of SOME event=> @{code service_math_output_matches}state event|_=>false)
  end;
fun binding_live state request evidence =
  @{code service_binding_live} state (nat request) (nat evidence);
datatype lifecycle = Cancel of IntInf.int | RetireCapability of IntInf.int |
  RetireSource of IntInf.int | Revoke of IntInf.int | Forget of IntInf.int;
fun lifecycle_frame action=encode_event (case action of
    Cancel id=> @{code CancelRequest} (nat id)
  | RetireCapability id=> @{code RetireCapability} (nat id)
  | RetireSource id=> @{code RetireSource} (nat id)
  | Revoke id=> @{code Revoke} (nat id)
  | Forget id=> @{code Forget} (nat id));
(* Supplied only by the fixed native gate. Each root is recovered from an
   exact current registered row, never from a caller's root list. *)
fun current_event_frame state frame registration_groups =
  (case decode_event frame of SOME (@{code StageAdoption} _)=>
    (guard(conversation_adoption_event_matches state frame)
      "Native exact adoption differs from current licensed final bindings";frame)
  | SOME (@{code StageOutput}(_, @{code ArtifactOutput} output,_))=>
    (guard(@{code service_artifact_retention_matches}state output)
      "Native artifact retained rows differ from original ownership closure";frame)
  | SOME (@{code Forget} primary)=>
    let fun registration bytes=(case decode_event bytes of
          SOME (event as @{code RegisterManaged} _)=>event
        | _=>error "Native support tuple is not a managed registration");
      val groups=map (map registration) registration_groups;
      val event=(case @{code service_forget_registered_support_event} state primary groups of
        SOME value=>value | NONE=>error "Native support retirement closure unavailable")
    in encode_event event end
  | _=>frame);
(* Owner integration fragment: paste inside Veri7vn_Metadata_Frame's existing
   generated compilation unit, after encode_event. Never ML_file this separately:
   its @{code} terms must share the actual reducer's carrier universe. Numeric
   projections below are obtained ONLY from actual Source/Gate handles or their
   authenticated C/Scope restoration, not resident client packets. *)
type search_projection={identity:Veri7vn_Native_Request_Scope.identity,context:IntInf.int,
  receiver:IntInf.int,worker:IntInf.int,input:IntInf.int,cost:IntInf.int};
type search_control_names={capability:IntInf.int,operation:IntInf.int,profile:IntInf.int,step:IntInf.int,
  template:IntInf.int,claim:IntInf.int,parameter:IntInf.int,execution:IntInf.int,code:IntInf.int,
  evidence:IntInf.int,output:IntInf.int,batch:IntInf.int,exhausted:IntInf.int,budget:IntInf.int,
  deadline:IntInf.int,cancelled:IntInf.int,failed:IntInf.int};
fun search_control_values (p:search_projection) (n:search_control_names)=
  let val i= #identity p in
    [#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
     #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,
     #execution n,#code n,#evidence n,#output n,#batch n,#exhausted n,#budget n,
     #deadline n,#cancelled n,#failed n]end;
fun search_control p n=
  let val values=search_control_values p n;
    val _=guard(length values=24 andalso forall(fn id=>id>0)values andalso
      length(distinct(op =)values)=length values) "Search native control domains overlap"
  in @{code search_service_control}(map nat values)end;
fun search_intrinsic_frame id=(guard(id>0) "Search intrinsic identity";
  encode_event(@{code search_service_intrinsic}(nat id)));
fun search_support_frames p n=map search_intrinsic_frame
  (filter(fn id=>id<> #parameter n andalso id<> #output n)(search_control_values p n));
fun search_prerequisites (p:search_projection) (n:search_control_names) native=
  let val i= #identity p in distinct(op =)
    ([#parameter n,#capability n,#operation n,#profile n,#code n,#template n,#input p,#receiver p,
      #interpretation i,#decision i]@native)end;
fun search_parameter_frame p n owned=encode_event
  (@{code search_service_parameter}(search_control p n)(map nat owned));
fun search_reserve_frame p n prestate cost deps=encode_event
  (@{code search_service_reserve}(search_control p n)(nat prestate)(nat cost)(map nat deps));
fun search_execute_frame p n cost=encode_event
  (@{code search_service_execute}(search_control p n)(nat cost));
fun search_evidence_frame p n deps native=encode_event
  (@{code search_service_evidence}(search_control p n)(map nat deps)(map nat native));
fun search_publish_frame p n deps native=encode_event
  (@{code search_service_publish}(search_control p n)(map nat deps)(map nat native));
fun search_stop stopped=case stopped of "exhausted"=> @{code SearchExhausted} |
    "budget"=> @{code SearchBudget} | "deadline"=> @{code SearchDeadline} |
    "cancelled"=> @{code SearchCancelled} | "failed"=> @{code SearchFailed} |
    _=>error "Unknown fixed native search stop";
fun search_stopped_frame p n stopped=
  encode_event(@{code search_service_stopped}(search_control p n)(search_stop stopped));
fun search_request_matches state p n deps cost=
  @{code search_service_request_matches}state(search_control p n)(map nat deps)(nat cost);
fun search_output_matches state p n deps native=
  @{code search_service_output_matches}state(search_control p n)(map nat deps)(map nat native);
fun search_execution_matches state p n cost consumed=
  @{code search_service_execution_matches}state(search_control p n)(nat cost)consumed;
fun search_stopped_matches state p n stopped=
  @{code search_service_stopped_matches}state(search_control p n)(search_stop stopped);

type math_request_expectation={names:math_names,dependencies:IntInf.int list,managed:IntInf.int list,bridge:math_bridge_names,cost:IntInf.int};
datatype recovery_view=KernelAssociation of string |
  MathRequestAssociation of math_request_expectation |
  MathHistoricalOutputAssociation of {request:math_request_expectation,evidence:string,publication:string} |
  MathOutputAssociation of {evidence:string,publication:string} |
  BuildRequestAssociation of {metadata:Veri7vn_Native_Development_Codec.metadata,
    payload:Veri7vn_Native_Development_Codec.payload,request:Veri7vn_Native_Build_Request_Envelope.packet} |
  BuildOutputAssociation of {metadata:Veri7vn_Native_Development_Codec.metadata,
    payload:Veri7vn_Native_Development_Codec.payload} |
  SearchRequestAssociation of {names:search_projection,control:search_control_names,
    dependencies:IntInf.int list,phase:{execution:IntInf.int option,stopped:string option,reason:IntInf.int option}} |
  SearchOutputAssociation of {names:search_projection,control:search_control_names,
    dependencies:IntInf.int list,native:IntInf.int list} | NoAssociation;
fun required_request_ids state=map integer (@{code service_required_math_requests} state);
datatype recovery_role=RequestChildRole | ArtifactRole | EvidenceRole;
type recovery_identity={association:IntInf.int,semantic_generation:IntInf.int,role:recovery_role};
fun required_associations state:recovery_identity list=
  map_filter(fn(_,goal)=>case @{code goal_output_slot}goal of NONE=>NONE
    |SOME slot=>SOME{association=integer slot,
      semantic_generation=integer(@{code goal_generation}goal),role=RequestChildRole})
    (@{code required_native_children}state) @
  map(fn artifact=>{association=integer(@{code artifact_assigned_output}artifact),
      semantic_generation=integer(@{code artifact_assigned_generation}artifact),role=ArtifactRole})
    (@{code required_native_artifacts}state) @
  map(fn evidence=>{association=integer(@{code evidence_id}evidence),
    semantic_generation=integer(@{code semantic_generation}(@{code evidence_claim}evidence)),
    role=EvidenceRole})
    (@{code required_native_evidence}state);
fun request_cancelled state id=exists(fn request=>integer(@{code request_id}request)=id andalso
  @{code request_cancelled}request)(@{code requests}state);
fun request_unavailable state id=exists(fn request=>integer(@{code request_id}request)=id andalso
  (@{code request_cancelled}request orelse not(@{code accessible}state
    (@{code request_id}request :: @{code request_dependencies}request))))(@{code requests}state);
fun search_child_required state (rid,gid,slot)=exists(fn(request,goal)=>
  integer(@{code request_id}request)=rid andalso integer(@{code goal_id}goal)=gid andalso
  @{code goal_output_slot}goal=SOME(nat slot))(@{code required_native_children}state);
fun managed_denied state id=member(op =)(map integer(@{code revoked_objects}state) @
  map integer(@{code forgotten_objects}state) @ map integer(@{code retired_sources}state) @
  map integer(@{code retired_capabilities}state))id;
fun child_unavailable state (rid,gid,slot)=exists(fn request=>integer(@{code request_id}request)=rid andalso
  exists(fn goal=>integer(@{code goal_id}goal)=gid andalso
    @{code goal_output_slot}goal=SOME(nat slot) andalso
    (@{code request_cancelled}request orelse not(@{code accessible}state
      (@{code request_id}request :: @{code request_dependencies}request)) orelse
      not(@{code child_accessible}state goal)))(@{code request_goals}request))(@{code requests}state);
fun execution_ids state request slot=map (integer o @{code execution_id})
  (filter(fn run=>integer(@{code execution_slot}run)=slot)(@{code service_execution_for} state (nat request)));
fun revoked_ids state=map integer (@{code revoked_objects} state);
fun forgotten_ids state=map integer (@{code forgotten_objects} state);
(* Capture the exact category transition, before host durability or owner install.
   Revoke followed by Forget must still transport its newly forgotten IDs. *)
datatype invalidations=NoInvalidations | Revoked of IntInf.int list | Forgotten of IntInf.int list;
fun invalidation_ids NoInvalidations=[] | invalidation_ids(Revoked ids)=ids
  | invalidation_ids(Forgotten ids)=ids;
fun invalidation_delta previous next event=
  let val result=(case event of
      @{code Revoke} _=>Revoked(map integer(@{code new_revoked_objects} previous next))
    | @{code Forget} _=>Forgotten(map integer(@{code new_forgotten_objects} previous next))
    | @{code ForgetRoots} _=>Forgotten(map integer(@{code new_forgotten_objects} previous next))
    | _=>NoInvalidations);
    val ids=invalidation_ids result;
    val _=guard(length ids<=8192 andalso size(space_implode ","(map IntInf.toString ids))<=1048576)
      "Native artifact invalidation transport bound";
  in result end;

fun reserved_request_matches state frame=(case decode_event frame of
    SOME event=> @{code service_reserved_request_matches} state event
  | NONE=>false);

(* Include in the SAME F generated unit before restore_matches. The first
   resident build profile is a singleton request. Composite restoration needs
   its own captured common plan; this helper does not guess one. *)
type build_request_expectation={metadata:Veri7vn_Native_Development_Codec.metadata,
  payload:Veri7vn_Native_Development_Codec.payload,
  request:Veri7vn_Native_Build_Request_Envelope.packet};
type build_output_expectation={metadata:Veri7vn_Native_Development_Codec.metadata,
  payload:Veri7vn_Native_Development_Codec.payload};
fun build_restore_retained state (requests:build_request_expectation list)
    (outputs:build_output_expectation list)=
  let
    fun original(m:Veri7vn_Native_Development_Codec.metadata)=
      let val parents=filter(fn r=>integer(@{code request_id}r)= #request m)(@{code requests}state)
        val parent=case parents of [r]=>r|_=>error "Build original parent is not unique"
        val children=filter(fn g=>integer(@{code goal_id}g)= #goal m)(@{code request_goals}parent)
        val child=case children of [g]=>g|_=>error "Build original child is not unique"
      in guard(length(@{code request_goals}parent)=1) "Unsupported composite Build restoration";
        (parent,child)end;
    fun registered frame=case decode_event frame of SOME(@{code RegisterManaged}row)=>row
      |_=>error "Build expected registration profile";
    fun request_rows({metadata=m,request=packet,...}:build_request_expectation)=
      let val control= #plan packet;val names=build_names_from_plan control
        val(parent,child)=original m
        val native=distinct(op =)(#dependencies m @ #parents m)
        val dependencies=distinct(op =)([#template control,#profile control,#setup control,
          #operation control,#capability control,#step control,#operation_generation control,
          #code_generation control] @ native)
        val _=guard(@{code request_dependencies}parent=map nat dependencies)
          "Build original shared dependencies differ from native producer"
        val supports=distinct(op =)(#interpretation control:: #capability control::dependencies)
        val parameter=registered(build_parameter_frame names parent child native(#input_bindings m)[])
        val has_parameter=exists(fn row=> @{code retained_id}row=nat(#parameter control))
          (@{code retained_values}state)
      in map(registered o build_intrinsic_frame)supports @
        (if has_parameter then[parameter]else[])end;
    fun output_rows({metadata=m,...}:build_output_expectation)=
      let val paired=filter(fn{metadata=r,...}:build_request_expectation=>
          #request r= #request m andalso #goal r= #goal m andalso #slot r= #slot m)requests
        val packet=case paired of [{request,...}]=>request
          |_=>error "Build candidate lacks exact original request"
        val names=build_names_from_plan(#plan packet)
        val(parent,child)=original m
        val required=build_requirement(build_projection_from_metadata m)
        val closure=distinct(op =)(#dependencies m @ #parents m @ #input_bindings m)
        val frame=build_artifact_frame names parent child required(#semantic_generation m)
          closure(#input_bindings m)(@{code RequestLocal}(nat(#request m)))[]
        val assignment=case decode_event frame of
          SOME(@{code RecordOutput}(@{code ArtifactOutput}a,NONE))=>a
          |_=>error "Build expected artifact profile"
        val matches=filter(fn actual=> @{code artifact_assigned_output}actual=nat(#candidate m))
          (@{code required_native_artifacts}state)
        val _=guard(matches=[assignment]) "Build retained assignment differs from native producer"
        val _=guard(@{code artifact_expected_retained}state assignment=
          SOME(@{code artifact_assigned_retained}assignment))
          "Build artifact retention is not canonical for its original owner"
      in @{code artifact_assigned_retained}assignment end;
    val _=guard(sort IntInf.compare(map(fn{metadata,...}:build_output_expectation=> #candidate metadata)outputs)=
      sort IntInf.compare(map(integer o @{code artifact_assigned_output})(@{code required_native_artifacts}state)))
      "Build native artifact coverage differs"
  in maps request_rows requests @ maps output_rows outputs end;

fun restore_matches state views =
  let
    val _=guard (@{code service_restore_supported} state) "Unsupported native checkpoint profile";
    val active_request_views=map_filter(fn MathRequestAssociation value=>SOME value | _=>NONE)views;
    val historical_request_views=map_filter(fn MathHistoricalOutputAssociation{request,...}=>SOME request|_=>NONE)views;
    fun original_key({names,...}:math_request_expectation)=(#request_id names,#goal_id names,#output_slot_id names);
    fun add_original value originals=case find_first(fn old=>original_key old=original_key value)originals of
      NONE=>value::originals|SOME old=>(guard(old=value) "Conflicting original Math historical recipe";originals);
    val request_views=fold add_original(active_request_views @ historical_request_views)[];
    val build_requests=map_filter(fn BuildRequestAssociation value=>SOME value|_=>NONE)views;
    val build_outputs=map_filter(fn BuildOutputAssociation value=>SOME value|_=>NONE)views;
    val build_retained=build_restore_retained state build_requests build_outputs;
    val checkpoint=encode_state state;
    val _=List.app(fn{metadata,payload,request}=>guard
      (build_checkpoint_matches checkpoint false metadata payload(SOME request))
      "Restored Build request differs from original child")build_requests;
    val _=List.app(fn{metadata,payload}=>guard
      (build_checkpoint_matches checkpoint true metadata payload NONE)
      "Restored Build candidate differs from original artifact")build_outputs;
    val search_requests=map_filter(fn SearchRequestAssociation value=>SOME value|_=>NONE)views;
    val search_outputs=map_filter(fn SearchOutputAssociation value=>SOME value|_=>NONE)views;
    val _=List.app(fn{names,control,dependencies,phase}=>
      (guard(search_request_matches state names control dependencies (#cost names))
        "Restored Search request differs from original child";
       guard(search_execution_matches state names control (#cost names)(is_some(#execution phase)))
        "Restored Search charge differs from actual execution";
       guard(case #execution phase of NONE=>true|SOME id=>id= #execution control)
        "Restored Search execution identity differs";
       guard(case (#stopped phase,#reason phase)of (NONE,NONE)=>true
         |(SOME kind,SOME id)=>id=(case kind of "exhausted"=> #exhausted control
           |"budget"=> #budget control|"deadline"=> #deadline control
           |"cancelled"=> #cancelled control|"failed"=> #failed control|_=>0)
         |_=>false) "Restored Search reason differs from fixed outcome";
       Option.app(fn stopped=>guard(search_stopped_matches state names control stopped)
         "Restored Search outcome differs") (#stopped phase)))search_requests;
    val _=List.app(fn{names,control,dependencies,native}=>
      guard(search_output_matches state names control dependencies native)
        "Restored Search output differs from actual assignment")search_outputs;
    val evidence_frames=map_filter(fn KernelAssociation frame=>SOME frame
      | MathOutputAssociation {evidence,...}=>SOME evidence
      | MathHistoricalOutputAssociation{evidence,...}=>SOME evidence | _=>NONE)views @
      map(fn{names,control,dependencies,native}=>search_evidence_frame names control dependencies native)search_outputs;
    val publication_frames=map_filter(fn MathOutputAssociation {publication,...}=>SOME publication
      |MathHistoricalOutputAssociation{publication,...}=>SOME publication| _=>NONE)views;
    val search_publications=map(fn{names,control,dependencies,native}=>
      search_publish_frame names control dependencies native)search_outputs;
    fun child_key (names:math_names)=(#request_id names,#goal_id names,#output_slot_id names);
    val request_keys=map(fn {names,...}=>child_key names)active_request_views @
      map(fn{metadata,...}=>(#request metadata,#goal metadata,#slot metadata))build_requests @
      map(fn{names,...}=>let val i= #identity names in (#request i,#goal i,#slot i)end)search_requests;
    val required_keys=map(fn(request,goal)=>(integer(@{code request_id}request),
      integer(@{code goal_id}goal),case @{code goal_output_slot}goal of
        SOME slot=>integer slot | NONE=>error "Required native child has no output slot"))
      (@{code required_native_children}state);
    val _=guard(length request_keys=length required_keys andalso
      length(distinct(op =)request_keys)=length request_keys andalso
      forall(fn key=>member(op =)required_keys key)request_keys)
      "Incomplete native request-child closure";
    val evidence_ids=map(fn frame=>the(event_evidence_id frame))evidence_frames;
    val _=guard(sort IntInf.compare evidence_ids=sort IntInf.compare(required_evidence_ids state) andalso
      length(distinct(op =)evidence_ids)=length evidence_ids andalso
      forall(evidence_matches state)evidence_frames) "Incomplete or mismatched native evidence closure";
    val _=List.app(fn {names,dependencies,cost,...}=>
      let val _=guard(@{code service_math_request_matches} state (math_names names)
          (map nat dependencies)(nat cost)) "Restored original request differs from checkpoint";
        val runs=filter(fn run=>integer(@{code execution_slot}run)= #output_slot_id names)
          (@{code service_execution_for} state (nat(#request_id names)));
        val _=guard(length runs<=1) "Duplicate fixed native execution";
      in List.app(fn run=>guard(encode_event(@{code ExecutePure} run)=
          math_execute_frame names (integer(@{code execution_id} run)) cost)
          "Restored charge differs from actual native operation")runs end)request_views;
    fun publication frame=(case decode_event frame of SOME(@{code StageOutput}(_,@{code ClaimOutput} a,NONE))=>a
      | _=>error "Invalid native publication reconstruction");
    val publications=map publication(publication_frames @ search_publications);
    val _=guard(forall(fn frame=>case decode_event frame of SOME event=>
        @{code service_math_output_matches} state event | NONE=>false)publication_frames)
      "Restored output differs from checkpoint assignment";
    fun accessible ids= @{code accessible} state ids;
    val _=guard(forall(fn a=>not(accessible(@{code assigned_dependencies} a)) orelse
      exists(fn reconstructed=>reconstructed=a)publications)(@{code claim_assignments} state))
      "Native output assignment missing protected witness";
    val inputs=map(fn {names,managed,...}=>case decode_event(math_input_frame names) of
      SOME(@{code RegisterManaged} value)=>value | _=>error "Native input profile mismatch")request_views;
    val parameters=map(fn {names,managed,...}=>case decode_event(math_parameter_frame names managed) of
      SOME(@{code RegisterManaged} value)=>value | _=>error "Native parameter profile mismatch")request_views;
    val bridges=maps(fn {names,bridge,...}=>map(fn frame=>case decode_event frame of
      SOME(@{code RegisterManaged} value)=>value | _=>error "Native bridge profile mismatch")
      [math_statement_frame names bridge,math_bridge_frame names bridge])request_views;
    fun registered frame=case decode_event frame of SOME(@{code RegisterManaged} row)=>row
      |_=>error "Native Search support profile differs";
    val search_retained=maps(fn{names,control,dependencies,...}=>
      map registered(search_support_frames names control @ [search_parameter_frame names control dependencies]))search_requests;
    val proof_retained=maps(fn{native,...}=>map(registered o search_intrinsic_frame)native)search_outputs;
    val retained=inputs @ parameters @ bridges @ build_retained @ search_retained @ proof_retained @ maps @{code assigned_retained} publications;
    val _=guard(forall(fn value=>not(accessible(@{code retained_id} value::
      @{code retained_dependencies} value)) orelse exists(fn expected=>expected=value)retained)
      (@{code retained_values} state)) "Native retained payload missing protected association";
  in true end;
end;
