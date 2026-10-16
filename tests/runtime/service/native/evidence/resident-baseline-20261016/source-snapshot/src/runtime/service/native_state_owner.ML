(* Family-independent owner. Instantiate once inside the final sealed resident
   assembly, with a statically closed gate. Neither generated state nor candidate
   constructors escape; install closures are built only from actual reducer output. *)
signature VERI7VN_REGISTERED_NATIVE_GATE =
sig
  type event
  val is_live: event -> bool
  val event_frame: event -> IntInf.int -> string
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
  val registration_present: event -> bool
  val revoked_ids: unit -> IntInf.int list
  val prepare: event -> candidate
  val event_frame: candidate -> string
  val checkpoint: candidate -> string
  val revision: candidate -> IntInf.int
  val epoch: candidate -> IntInf.int
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
  datatype candidate=Candidate of {gate:event,version:IntInf.int,event_frame:string,
    checkpoint:string,revision:IntInf.int,epoch:IntInf.int,commands:F.command_view list,install:unit->unit};
  fun initial_frame ()=F.encode_state F.initial_state;
  fun current_version ()= #1 (Synchronized.value state);
  fun current_revision ()=F.revision (#2 (Synchronized.value state));
  fun current_epoch ()=F.epoch (#2 (Synchronized.value state));
  fun binding_live request evidence=F.binding_live (#2 (Synchronized.value state)) request evidence;
  fun registration_present gate=Gate.is_live gate andalso
    F.registration_present(#2(Synchronized.value state))(Gate.event_frame gate(current_revision()));
  fun revoked_ids()=F.revoked_ids(#2(Synchronized.value state));
  fun prepare gate =
    let
      (* Every observed event supersedes a staged candidate, including rejected
         events and metadata-only events which preserve revision and epoch. *)
      val _=Synchronized.change state (fn (version,current)=>(version+1,current));
      val _=F.guard (Gate.is_live gate) "Native gate association unavailable";
      val (version,current)=Synchronized.value state;
      val event_frame=Gate.event_frame gate (F.revision current);
      val event=(case F.decode_event event_frame of SOME value=>value
        | NONE=>error "Native gate event schema mismatch");
      val (_,next,commands,_)=F.prepare current event;
      val _=F.guard (not (F.rejected commands)) "Generated transition rejected";
      val commands=F.command_views commands;
      val _=F.guard (Gate.supports gate commands) "Native command consumer unavailable";
      val checkpoint=F.encode_state next;
      fun install ()=Synchronized.change state (fn (actual,_)=>
        if actual=version andalso Gate.is_live gate then (version+1,next)
        else error "Native state or association changed before acknowledgement");
    in Candidate {gate=gate,version=version,event_frame=event_frame,checkpoint=checkpoint,
      revision=F.revision next,epoch=F.epoch next,commands=commands,install=install} end;
  fun event_frame (Candidate {event_frame,...})=event_frame;
  fun checkpoint (Candidate {checkpoint,...})=checkpoint;
  fun revision (Candidate {revision,...})=revision;
  fun epoch (Candidate {epoch,...})=epoch;
  fun valid (Candidate {gate,version,...})=
    #1 (Synchronized.value state)=version andalso Gate.is_live gate;
  fun acknowledge (candidate as Candidate {install,commands,...})=
    (F.guard (valid candidate) "Native precommit changed";install ();commands);
  fun invalidate ()=Synchronized.change state (fn (version,current)=>(version+1,current));
  fun restore_initial bytes =
    if bytes=initial_frame () andalso F.encode_state (#2 (Synchronized.value state))=initial_frame ()
    then (Synchronized.change state (fn (version,_)=>(version+1,F.initial_state));true)
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
        val _=F.guard (forall Gate.is_live gates) "Released native recovery association";
        val frames=map (fn gate=>Gate.event_frame gate (F.revision recovered)) gates;
        val _=F.guard (forall (F.evidence_matches recovered) frames)
          "Native recovered evidence differs from latest checkpoint";
        (* Exact frame equality distinguishes duplicate descriptors without any
           caller-supplied saved-ID or acceptance predicate. *)
        val ids=map (fn frame=>the (F.event_evidence_id frame)) frames;
        val _=F.guard (sort IntInf.compare ids=required andalso
          length (distinct (op =) ids)=length ids) "Duplicate or missing native recovery association";
        val _=Synchronized.change state (fn (version,current)=>
          (F.guard (F.encode_state current=initial_frame () andalso forall Gate.is_live gates)
            "Native restore requires fresh current owner and live associations";
           (version+1,recovered)));
      in true end);
  fun restore_complete bytes gates =
    (case F.decode_state bytes of NONE=>false | SOME recovered=>
      let val _=F.guard(forall Gate.is_live gates) "Released native recovery association";
        val _=F.restore_matches recovered (map Gate.recovery_view gates);
        val _=Synchronized.change state(fn (version,current)=>
          (F.guard(F.encode_state current=initial_frame() andalso forall Gate.is_live gates)
            "Complete native restore requires fresh owner and live checked objects";
           (version+1,recovered)))
      in true end);
end;
