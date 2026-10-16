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
fun nat n = @{code nat_of_integer} n;
fun integer n = @{code integer_of_nat} n;
fun read bytes =
  let
    val _ = guard (size bytes <= max_bytes) "metadata byte limit";
    val position = Unsynchronized.ref 0;
    val nodes = Unsynchronized.ref 0;
    fun take n =
      let val _ = guard (n >= 0 andalso n <= size bytes - ! position) "truncated metadata";
        val chunk = String.substring (bytes, ! position, n);
        val _ = position := ! position + n;
      in chunk end;
    fun u32 () =
      let val n = fold (fn c => fn v => v * 256 + IntInf.fromInt (Char.ord c))
        (String.explode (take 4)) (0: IntInf.int);
        val _ = guard (n <= 2147483647) "metadata integer bound";
      in IntInf.toInt n end;
    fun loop depth =
      let
        val _ = nodes := ! nodes + 1;
        val _ = guard (depth <= max_depth andalso ! nodes <= max_nodes) "metadata shape limit";
      in
        (case Char.ord (String.sub (take 1, 0)) of
          0 =>
            let
              val length = u32 ();
              val _ = guard (length > 0 andalso length <= max_digits) "metadata digit limit";
              val digits = take length;
              val _ = guard (forall (fn c => #"0" <= c andalso c <= #"9") (String.explode digits)
                andalso (length = 1 orelse String.sub (digits, 0) <> #"0")) "noncanonical metadata natural";
            in @{code WireNat} (nat (the (IntInf.fromString digits))) end
        | 1 =>
            let val tag = u32 (); val count = u32 ();
              val _ = guard (count <= max_nodes - ! nodes andalso count <= size bytes - ! position)
                "metadata arity limit";
            in @{code WireNode} (nat (IntInf.fromInt tag), map (fn _ => loop (depth + 1)) (1 upto count)) end
        | _ => error "unknown metadata frame tag")
      end;
    val value = loop 1;
    val _ = guard (! position = size bytes) "trailing metadata bytes";
  in value end;
fun write value =
  let
    val total = Unsynchronized.ref 0;
    val nodes = Unsynchronized.ref 0;
    val chunks = Unsynchronized.ref ([]: string list);
    fun add s = (guard (size s <= max_bytes - ! total) "metadata byte limit";
      total := ! total + size s; chunks := s :: ! chunks);
    fun u32 n =
      (guard (n >= 0 andalso n <= 2147483647) "metadata integer bound";
       add (String.implode (map (fn divisor => Char.chr ((n div divisor) mod 256)) [16777216, 65536, 256, 1])));
    fun loop depth wire =
      (nodes := ! nodes + 1;
       guard (depth <= max_depth andalso ! nodes <= max_nodes) "metadata shape limit";
       case wire of
         @{code WireNat} n =>
           let val number = integer n;
             val _ = guard (number >= 0 andalso number < IntInf.pow (10, max_digits)) "metadata digit limit";
             val digits = IntInf.toString number;
           in add (String.str (Char.chr 0)); u32 (size digits); add digits end
       | @{code WireNode} (tag, children) =>
           (add (String.str (Char.chr 1)); u32 (IntInf.toInt (integer tag));
            guard (length children <= max_nodes - ! nodes) "metadata node limit";
            u32 (length children); List.app (loop (depth + 1)) children));
    val _ = loop 1 value;
  in String.concat (rev (! chunks)) end;
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
type claim_start = {attempt:IntInf.int,request:IntInf.int,target:IntInf.int,
  capability:IntInf.int,sources:IntInf.int list,dependencies:IntInf.int list,
  prestate:IntInf.int,epoch:IntInf.int};
fun claim_starts commands : claim_start list = map_filter (fn
    @{code ClaimStart} (intent, epoch) => SOME
      {attempt=integer (@{code attempt_id} intent),
       request=integer (@{code attempt_request} intent),
       target=integer (@{code attempt_target} intent),
       capability=integer (@{code attempt_capability} intent),
       sources=map integer (@{code attempt_sources} intent),
       dependencies=map integer (@{code attempt_dependencies} intent),
       prestate=integer (@{code attempt_prestate} intent), epoch=integer epoch}
  | _ => NONE) commands;
type cost_view={profile:IntInf.int,code_generation:IntInf.int,operation:IntInf.int,
  step:IntInf.int,units:IntInf.int};
fun cost_view cost : cost_view =
  {profile=integer (@{code cost_profile} cost),code_generation=integer (@{code cost_code_generation} cost),
   operation=integer (@{code cost_operation} cost),step=integer (@{code cost_step} cost),units=integer (@{code cost_units} cost)};
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
       (@{code int_of_integer} a) (@{code int_of_integer} b)));
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
     (@{code checked_statement} (nat (IntInf.fromInt kind), map @{code int_of_integer} parameters)
       (map (nat o IntInf.fromInt o Char.ord) (String.explode raw))));
fun read_integer_bytes raw =
  Option.map @{code integer_of_int} (@{code read_integer} (byte_naturals raw));
fun binary_checked_statement_bytes number a b numerator denominator raw =
  (guard (number>=0 andalso number<=4 andalso size raw<=16384 andalso
     forall (fn n=>size(IntInf.toString n)<=513) [a,b,numerator,denominator])
     "Binary statement bound";
   Option.map (output_bytes 65536) (@{code binary_checked_statement}
     (nat(IntInf.fromInt number)) (@{code int_of_integer} a) (@{code int_of_integer} b)
     (@{code int_of_integer} numerator) (@{code int_of_integer} denominator)
     (map (nat o IntInf.fromInt o Char.ord) (String.explode raw))));
fun encode_state state = write (@{code encode_checkpoint} state);
fun decode_state bytes = @{code decode_checkpoint} (read bytes);
fun encode_event event = write (@{code encode_event_frame} event);
fun decode_event bytes = @{code decode_event_frame} (read bytes);
val evidence_only_checkpoint = @{code service_evidence_only_checkpoint};
fun evidence_matches state bytes = (case decode_event bytes of
  SOME event => @{code service_evidence_matches} state event | NONE => false);
fun event_evidence_id bytes = (case decode_event bytes of
  SOME (@{code AttachEvidence} evidence)=>SOME (integer (@{code evidence_id} evidence))
  | _=>NONE);
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
fun math_input_frame names deps=encode_event
  (@{code service_math_input} (math_names names) (map nat deps));
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
datatype recovery_view=KernelAssociation of string |
  MathRequestAssociation of {names:math_names,dependencies:IntInf.int list,managed:IntInf.int list,bridge:math_bridge_names,cost:IntInf.int} |
  MathOutputAssociation of {evidence:string,publication:string} | NoAssociation;
fun required_request_ids state=map integer (@{code service_required_math_requests} state);
datatype recovery_role=KernelRole | MathRequestRole | MathOutputRole;
type recovery_identity={association:IntInf.int,semantic_generation:IntInf.int,role:recovery_role};
fun required_associations state:recovery_identity list=
  map_filter(fn request=>if member(op =)(required_request_ids state)(integer(@{code request_id}request))
    then SOME{association=integer(@{code request_id}request),
      semantic_generation=integer(@{code request_generation}request),role=MathRequestRole} else NONE)
    (@{code requests}state) @
  map(fn evidence=>{association=integer(@{code evidence_id}evidence),
    semantic_generation=integer(@{code semantic_generation}(@{code evidence_claim}evidence)),
    role=(case @{code evidence_route}evidence of @{code KernelConsequence}=>KernelRole
      | @{code RefinedExecution}=>MathOutputRole | _=>error "Unsupported recovery assurance route")})
    (@{code required_native_evidence}state);
fun request_cancelled state id=exists(fn request=>integer(@{code request_id}request)=id andalso
  @{code request_cancelled}request)(@{code requests}state);
fun execution_ids state request=map (integer o @{code execution_id})
  (@{code service_execution_for} state (nat request));
fun revoked_ids state=map integer (@{code revoked_objects} state);
fun forgotten_ids state=map integer (@{code forgotten_objects} state);
(* Capture the exact category transition, before host durability or owner install.
   Revoke followed by Forget must still transport its newly forgotten IDs. *)
datatype invalidations=NoInvalidations | Revoked of IntInf.int list | Forgotten of IntInf.int list;
fun invalidation_ids NoInvalidations=[] | invalidation_ids(Revoked ids)=ids
  | invalidation_ids(Forgotten ids)=ids;
fun invalidation_delta previous next event=
  let fun delta before_ids after_ids=map integer(@{code indexed_new_ids} before_ids after_ids);
    val result=(case event of
      @{code Revoke} _=>Revoked(delta (@{code revoked_objects} previous)(@{code revoked_objects} next))
    | @{code Forget} _=>Forgotten(delta (@{code forgotten_objects} previous)(@{code forgotten_objects} next))
    | @{code ForgetRoots} _=>Forgotten(delta (@{code forgotten_objects} previous)(@{code forgotten_objects} next))
    | _=>NoInvalidations);
    val ids=invalidation_ids result;
    val _=guard(length ids<=8192 andalso size(space_implode ","(map IntInf.toString ids))<=1048576)
      "Native artifact invalidation transport bound";
  in result end;

fun restore_matches state views =
  let
    val _=guard (@{code service_restore_supported} state) "Unsupported native checkpoint profile";
    val request_views=map_filter(fn MathRequestAssociation value=>SOME value | _=>NONE)views;
    val evidence_frames=map_filter(fn KernelAssociation frame=>SOME frame
      | MathOutputAssociation {evidence,...}=>SOME evidence | _=>NONE)views;
    val publication_frames=map_filter(fn MathOutputAssociation {publication,...}=>SOME publication | _=>NONE)views;
    val request_ids=map(fn {names,...}=> #request_id names)request_views;
    val required_requests=sort IntInf.compare(required_request_ids state);
    val _=guard(sort IntInf.compare request_ids=required_requests andalso
      length(distinct(op =)request_ids)=length request_ids) "Incomplete native request closure";
    val evidence_ids=map(fn frame=>the(event_evidence_id frame))evidence_frames;
    val _=guard(sort IntInf.compare evidence_ids=sort IntInf.compare(required_evidence_ids state) andalso
      length(distinct(op =)evidence_ids)=length evidence_ids andalso
      forall(evidence_matches state)evidence_frames) "Incomplete or mismatched native evidence closure";
    val _=List.app(fn {names,dependencies,cost,...}=>
      let val _=guard(@{code service_math_request_matches} state (math_names names)
          (map nat dependencies)(nat cost)) "Restored original request differs from checkpoint";
        val runs= @{code service_execution_for} state (nat(#request_id names));
        val _=guard(length runs<=1) "Duplicate fixed native execution";
      in List.app(fn run=>guard(encode_event(@{code ExecutePure} run)=
          math_execute_frame names (integer(@{code execution_id} run)) cost)
          "Restored charge differs from actual native operation")runs end)request_views;
    fun publication frame=(case decode_event frame of SOME(@{code StageOutput}(_,a,NONE))=>a
      | _=>error "Invalid native publication reconstruction");
    val publications=map publication publication_frames;
    val _=guard(forall(fn frame=>case decode_event frame of SOME event=>
        @{code service_math_output_matches} state event | NONE=>false)publication_frames)
      "Restored output differs from checkpoint assignment";
    fun accessible ids= @{code accessible} state ids;
    val _=guard(forall(fn a=>not(accessible(@{code assigned_dependencies} a)) orelse
      exists(fn reconstructed=>reconstructed=a)publications)(@{code output_assignments} state))
      "Native output assignment missing protected witness";
    val inputs=map(fn {names,managed,...}=>case decode_event(math_input_frame names managed) of
      SOME(@{code RegisterManaged} value)=>value | _=>error "Native input profile mismatch")request_views;
    val parameters=map(fn {names,managed,...}=>case decode_event(math_parameter_frame names managed) of
      SOME(@{code RegisterManaged} value)=>value | _=>error "Native parameter profile mismatch")request_views;
    val bridges=maps(fn {names,bridge,...}=>map(fn frame=>case decode_event frame of
      SOME(@{code RegisterManaged} value)=>value | _=>error "Native bridge profile mismatch")
      [math_statement_frame names bridge,math_bridge_frame names bridge])request_views;
    val retained=inputs @ parameters @ bridges @ maps @{code assigned_retained} publications;
    val _=guard(forall(fn value=>not(accessible(@{code retained_id} value::
      @{code retained_dependencies} value)) orelse exists(fn expected=>expected=value)retained)
      (@{code retained_values} state)) "Native retained payload missing protected association";
  in true end;
end;
