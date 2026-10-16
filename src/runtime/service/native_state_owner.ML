(* Family-independent owner. Instantiate once inside the final sealed resident
   assembly, with a statically closed gate. Neither generated state nor candidate
   constructors escape; install closures are built only from actual reducer output. *)
signature VERI7VN_REGISTERED_NATIVE_GATE =
sig
  type event
  (* Intrinsic native liveness only: this callback must not query this Owner. *)
  val is_live: event -> bool
  val current_expectation: event -> Veri7vn_Metadata_Frame.current_expectation
  val event_frame: event -> IntInf.int -> string
  val retirement_registrations: event -> string list list
  val supports: event -> Veri7vn_Metadata_Frame.command_view list -> bool
  val recovery_view: event -> Veri7vn_Metadata_Frame.recovery_view
end;
signature VERI7VN_NATIVE_STATE_OWNER =
sig
  type event
  type candidate
  val initial_frame: unit -> string
  val current_version: unit -> IntInf.int
  val current_revision: unit -> IntInf.int
  val current_epoch: unit -> IntInf.int
  val binding_live: IntInf.int -> IntInf.int -> bool
  val historical_output_access: {evidence:string,publication:string} -> bool
  val registration_present: event -> bool
  val request_unavailable: IntInf.int -> bool
  val child_unavailable: IntInf.int * IntInf.int * IntInf.int -> bool
  val search_child_required: IntInf.int * IntInf.int * IntInf.int -> bool
  val managed_denied: IntInf.int -> bool
  val revoked_ids: unit -> IntInf.int list
  val conversation_current_context: string -> IntInf.int * IntInf.int ->
    Veri7vn_Native_Observation_Pin.snapshot option
  val conversation_session_exists: IntInf.int -> bool
  val conversation_source_visible: IntInf.int * IntInf.int -> bool
  val prepare: event -> candidate
  val event_frame: candidate -> string
  val checkpoint: candidate -> string
  val revision: candidate -> IntInf.int
  val epoch: candidate -> IntInf.int
  val invalidations: candidate -> Veri7vn_Metadata_Frame.invalidations
  val valid: candidate -> bool
  val acknowledge: candidate -> Veri7vn_Metadata_Frame.command_view list
  val invalidate: unit -> unit
  val restore_initial: string -> bool
  (* Only the final private assembly calls this after full protected artifact
     re-admission. Commands are never replayed by restoration. *)
  val restore_evidence: string -> event list -> bool
  val restore_complete: string -> event list -> bool
end;
functor Veri7vn_Native_State_Owner (Gate: VERI7VN_REGISTERED_NATIVE_GATE)
  :> VERI7VN_NATIVE_STATE_OWNER where type event = Gate.event =
struct
  structure F=Veri7vn_Metadata_Frame;
  type event=Gate.event;
  val state=Synchronized.var "veri7vn_single_native_authority" ((0: IntInf.int),F.initial_state);
  (* Fail synchronously if a future closed family accidentally recurses into
     the authority monitor from its intrinsic liveness check. This is a callback
     contract check, not a second authority or a cached authorization decision. *)
  val intrinsic_check=Thread_Data.var ():unit Thread_Data.var;
  fun outside_intrinsic ()=F.guard(is_none(Thread_Data.get intrinsic_check))
    "Native gate liveness must not query its authority Owner";
  fun state_value ()=(outside_intrinsic();Synchronized.value state);
  fun state_change f=(outside_intrinsic();Synchronized.change state f);
  fun gate_live gate=Thread_Data.setmp intrinsic_check (SOME ()) Gate.is_live gate;
  datatype candidate=Candidate of {gate:event,version:IntInf.int,event_frame:string,
    checkpoint:string,revision:IntInf.int,epoch:IntInf.int,commands:F.command_view list,invalidations:F.invalidations,install:unit->unit};
  fun initial_frame ()=F.encode_state F.initial_state;
  fun current_version ()= #1 (state_value ());
  fun current_revision ()=F.revision (#2 (state_value ()));
  fun current_epoch ()=F.epoch (#2 (state_value ()));
  fun binding_live request evidence=F.binding_live (#2 (state_value ())) request evidence;
  fun historical_output_access frames=F.historical_output_access(#2(state_value()))frames;
  fun registration_present gate=gate_live gate andalso
    F.registration_present(#2(state_value ()))(Gate.event_frame gate(current_revision()));
  fun request_unavailable id=F.request_unavailable(#2(state_value ()))id;
  fun child_unavailable key=F.child_unavailable(#2(state_value ()))key;
  fun search_child_required key=F.search_child_required(#2(state_value()))key;
  fun managed_denied id=F.managed_denied(#2(state_value()))id;
  fun revoked_ids()=F.revoked_ids(#2(state_value ()));
  fun conversation_current_context workspace key=
    F.conversation_current_context(#2(state_value()))workspace key;
  fun conversation_session_exists sid=F.conversation_session_exists(#2(state_value()))sid;
  fun conversation_source_visible key=F.conversation_source_visible(#2(state_value()))key;
  fun prepare gate =
    let
      (* Every observed event supersedes a staged candidate, including rejected
         events and metadata-only events which preserve revision and epoch. *)
      val _=state_change (fn (version,current)=>(version+1,current));
      val _=F.guard (gate_live gate) "Native gate association unavailable";
      val (version,current)=state_value ();
      val expectation=Gate.current_expectation gate;
      val _=F.guard(F.current_expectation_matches current expectation)
        "Native original observation changed before staging";
      val event_frame=F.current_event_frame current (Gate.event_frame gate (F.revision current))
        (Gate.retirement_registrations gate);
      val _=F.guard(F.current_expectation_event_matches current expectation event_frame)
        "Native conversation record differs from its original request";
      val event=(case F.decode_event event_frame of SOME value=>value
        | NONE=>error "Native gate event schema mismatch");
      val (_,next,commands,_)=F.prepare current event;
      val _=F.guard (not (F.rejected commands)) "Generated transition rejected";
      val commands=F.command_views commands;
      val _=F.guard (Gate.supports gate commands) "Native command consumer unavailable";
      val invalidations=F.invalidation_delta current next event;
      val checkpoint=F.encode_state next;
      fun install ()=state_change (fn (actual,_)=>
        if actual=version andalso gate_live gate then (version+1,next)
        else error "Native state or association changed before acknowledgement");
    in Candidate {gate=gate,version=version,event_frame=event_frame,checkpoint=checkpoint,
      revision=F.revision next,epoch=F.epoch next,commands=commands,invalidations=invalidations,install=install} end;
  fun event_frame (Candidate {event_frame,...})=event_frame;
  fun checkpoint (Candidate {checkpoint,...})=checkpoint;
  fun revision (Candidate {revision,...})=revision;
  fun epoch (Candidate {epoch,...})=epoch;
  fun invalidations(Candidate {invalidations,...})=invalidations;
  fun valid (Candidate {gate,version,...})=
    #1 (state_value ())=version andalso gate_live gate;
  fun acknowledge (candidate as Candidate {install,commands,...})=
    (F.guard (valid candidate) "Native precommit changed";install ();commands);
  fun invalidate ()=state_change (fn (version,current)=>(version+1,current));
  fun restore_initial bytes =
    if bytes=initial_frame () andalso F.encode_state (#2 (state_value ()))=initial_frame ()
    then (state_change (fn (version,_)=>(version+1,F.initial_state));true)
    else false;
  fun restore_evidence bytes gates =
    (case F.decode_state bytes of NONE=>false | SOME recovered=>
      let
        (* First public-kernel recovery profile only. Requests/outputs/jobs need
           their own exact native reconstruction; never silently discard them. *)
        val _=F.guard (F.evidence_only_checkpoint recovered) "Native non-evidence recovery profile unavailable";
        val required=sort IntInf.compare (F.required_evidence_ids recovered);
        val _=F.guard (length required<=8192 andalso length gates=length required)
          "Incomplete native recovery closure";
        val _=F.guard (forall gate_live gates) "Released native recovery association";
        val frames=map (fn gate=>Gate.event_frame gate (F.revision recovered)) gates;
        val _=F.guard (forall (F.evidence_matches recovered) frames)
          "Native recovered evidence differs from latest checkpoint";
        (* Exact frame equality distinguishes duplicate descriptors without any
           caller-supplied saved-ID or acceptance predicate. *)
        val ids=map (fn frame=>the (F.event_evidence_id frame)) frames;
        val _=F.guard (sort IntInf.compare ids=required andalso
          length (distinct (op =) ids)=length ids) "Duplicate or missing native recovery association";
        val _=state_change (fn (version,current)=>
          (F.guard (F.encode_state current=initial_frame () andalso forall gate_live gates)
            "Native restore requires fresh current owner and live associations";
           (version+1,recovered)));
      in true end);
  fun restore_complete bytes gates =
    (case F.decode_state bytes of NONE=>false | SOME recovered=>
      let val _=F.guard(forall gate_live gates) "Released native recovery association";
        val _=F.restore_matches recovered (map Gate.recovery_view gates);
        val _=state_change(fn (version,current)=>
          (F.guard(F.encode_state current=initial_frame() andalso forall gate_live gates)
            "Complete native restore requires fresh owner and live checked objects";
           (version+1,recovered)))
      in true end);
end;
