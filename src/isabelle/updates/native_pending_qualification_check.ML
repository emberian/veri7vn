(* Fixed protected request-role reconstruction. This deliberately performs no
   measurement and creates no observation, start, exposure or charged ticket. *)
functor Veri7vn_Check_Initial_Qualification_Request
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Owner:VERI7VN_BUILD_CANDIDATE_LEASE
   structure Admission:VERI7VN_INITIAL_PACKAGE_ADMISSION
   structure Checkpoint:VERI7VN_PENDING_QUALIFICATION_CHECKPOINT
   sharing type Intent.intent=Builder.export_intent=Admission.intent
   sharing type Builder.candidate=Owner.candidate=Admission.candidate) :>
sig
  include VERI7VN_CHECKED_INITIAL_QUALIFICATION_REQUEST
    where type candidate=Builder.candidate and type intent=Intent.intent
  val check:Veri7vn_Native_Identity_Allocator.allocator -> Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Committed_Native_Recovery.committed -> Owner.lease -> checked
end =
struct
  structure T=Veri7vn_Pending_Qualification_Types;
  structure Wire=Veri7vn_Pending_Qualification_Codec;
  structure C=Veri7vn_Qualification_Material_Check;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  type candidate=Builder.candidate;
  type intent=Intent.intent;
  type binding={candidate:candidate,intent:intent,snapshot:T.initial,phase:T.phase};
  type payload={binding:binding,owner:Owner.lease};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({owner,...}:payload)=>Owner.is_live owner
    val dispose=fn({owner,...}:payload)=>Owner.release owner);
  type checked=Root.checked;
  structure Bind=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=checked
    fun bindings checked=let val b= #binding(Root.read checked)
      in [{workspace=Veri7vn_Managed_Provenance.development_workspace(Builder.development(#candidate b)),
        generation=Admission.observer_generation,semantic_generation= #semantic_generation(#names(#snapshot b))}] end
  end);
  val fragment=Bind.fragment;

  fun check allocator image committed owner=
    let
      val m=C.check image Admission.executable Veri7vn_Recovery_Manifest.InitialQualificationRequest
        "initial-qualification-request/2" committed;
      val wire=Wire.decode_initial(#projection m);
      val _=C.require(Owner.is_live owner) "Initial pending candidate lease unavailable";
      val candidate=Owner.candidate owner;
      val intent=Builder.original_intent candidate;
      val original=Intent.binding intent;
      val projection=Builder.projection candidate;
      val context= #context wire;
      val names= #names wire;
      val _=C.require(#association m= #request_slot wire andalso #semantic_generation m= #semantic_generation names andalso
        #workspace m=Veri7vn_Native_Identity_Allocator.workspace allocator andalso
        #workspace m=Intent.workspace intent andalso #candidate wire=projection andalso
        #profile wire=Admission.profile andalso #source_revision original= #source_revision projection andalso
        #manifest original= #manifest projection andalso #export_intent original= #export_intent projection)
        "Initial pending qualification identity/profile/intent mismatch";
      val _=C.require(case N.lookup_semantic_generation_id allocator Admission.observer_generation of
        NONE=>true | SOME id=>id= #semantic_generation names) "Initial pending observer generation mismatch";
      val candidate_generation=case N.lookup_semantic_generation_id allocator(Builder.native_generation candidate) of
        SOME id=>id | NONE=>error "Initial pending subject generation unregistered";
      val _=C.require(#semantic_generation names<>candidate_generation) "Observer pin aliases candidate subject meaning";
      val expected=distinct(op =)([#request_slot context,#candidate projection,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,
        #executable_generation context,#interpretation context,#semantic_generation names,candidate_generation,
        P.source_identity(#source original),#source_revision original,#manifest original,#export_intent original] @
        #dependencies projection @ #dependencies original);
      val _=C.require(#dependencies wire=expected andalso not(null(Intent.theorem_names intent)) andalso
        null(Intent.executable_locators intent)) "Initial pending closure/profile mismatch";
      val phase=case Checkpoint.initial(#checkpoint m)wire of SOME phase=>phase
        | NONE=>error "Initial pending qualification checkpoint mismatch";
      val retained=Owner.retain owner;
      val result=Exn.capture Root.create{binding={candidate=candidate,intent=intent,snapshot=wire,phase=phase},owner=retained};
    in case result of Exn.Res checked=>checked | Exn.Exn exn=>(Owner.release retained;Exn.reraise exn) end;
  fun binding checked= #binding(Root.read checked);
  fun executable checked=(ignore(Root.read checked);Admission.executable);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;

functor Veri7vn_Check_Update_Qualification_Request
  (structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Owner:VERI7VN_BUILD_CANDIDATE_LEASE
   structure Qualification:VERI7VN_PACKAGE_QUALIFICATION
   structure Checkpoint:VERI7VN_PENDING_QUALIFICATION_CHECKPOINT
   sharing type Builder.candidate=Owner.candidate=Qualification.candidate) :>
sig
  include VERI7VN_CHECKED_UPDATE_QUALIFICATION_REQUEST where type candidate=Builder.candidate
  val check:Veri7vn_Native_Identity_Allocator.allocator -> Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Committed_Native_Recovery.committed -> {candidate:Owner.lease,baseline:Owner.lease} -> checked
end =
struct
  structure T=Veri7vn_Pending_Qualification_Types;
  structure Wire=Veri7vn_Pending_Qualification_Codec;
  structure C=Veri7vn_Qualification_Material_Check;
  structure N=Veri7vn_Native_Descriptor;
  structure V=Veri7vn_Qualification_Restore_Check;
  type candidate=Builder.candidate;
  type binding={candidate:candidate,baseline:candidate,snapshot:T.update,phase:T.phase};
  type payload={binding:binding,candidate:Owner.lease,baseline:Owner.lease};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({candidate,baseline,...}:payload)=>Owner.is_live candidate andalso Owner.is_live baseline
    val dispose=fn({candidate,baseline,...}:payload)=>(Owner.release baseline;Owner.release candidate));
  type checked=Root.checked;
  structure Bind=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=checked
    fun bindings checked=let val b= #binding(Root.read checked)
      in [{workspace=Veri7vn_Managed_Provenance.development_workspace(Builder.development(#candidate b)),
        generation=Qualification.observer_generation,semantic_generation= #semantic_generation(#names(#snapshot b))}] end
  end);
  val fragment=Bind.fragment;

  fun check allocator image committed {candidate=owner,baseline=prior_owner}=
    let
      val m=C.check image Qualification.executable Veri7vn_Recovery_Manifest.UpdateQualificationRequest
        "update-qualification-request/1" committed;
      val wire=Wire.decode_update(#projection m);
      val _=C.require(Owner.is_live owner andalso Owner.is_live prior_owner) "Update pending leases unavailable";
      val candidate=Owner.candidate owner;
      val baseline=Owner.candidate prior_owner;
      val projection=Builder.projection candidate;
      val previous=Builder.projection baseline;
      val context= #context wire;
      val names= #names wire;
      val _=C.require(#association m= #request_slot wire andalso #semantic_generation m= #semantic_generation names andalso
        #workspace m=Veri7vn_Native_Identity_Allocator.workspace allocator andalso
        #workspace m=Veri7vn_Managed_Provenance.development_workspace(Builder.development candidate) andalso
        #workspace m=Veri7vn_Managed_Provenance.development_workspace(Builder.development baseline) andalso
        #candidate wire=projection andalso #baseline wire=previous andalso #profile wire=Qualification.profile andalso
        #candidate projection<> #candidate previous andalso #previous context=SOME(#candidate previous))
        "Update pending native baseline/identity/profile mismatch";
      val _=C.require(case N.lookup_semantic_generation_id allocator Qualification.observer_generation of
        NONE=>true | SOME id=>id= #semantic_generation names) "Update pending observer generation mismatch";
      fun subject_generation subject=case N.lookup_semantic_generation_id allocator(Builder.native_generation subject) of
        SOME id=>id | NONE=>error "Update pending subject generation unregistered";
      val candidate_generation=subject_generation candidate;
      val baseline_generation=subject_generation baseline;
      val _=C.require(#semantic_generation names<>candidate_generation andalso
        #semantic_generation names<>baseline_generation) "Observer pin aliases subject meaning";
      val expected=distinct(op =)([#request_slot context,#candidate projection,#candidate previous,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,#executable_generation context,
        #interpretation context,#semantic_generation names,candidate_generation,baseline_generation] @ #dependencies projection @ #dependencies previous);
      val _=C.require(#dependencies wire=expected) "Update pending closure mismatch";
      val _=V.exports(#expected_exports wire)(Builder.exports baseline);
      val phase=case Checkpoint.update(#checkpoint m)wire of SOME phase=>phase
        | NONE=>error "Update pending qualification checkpoint mismatch";
      val retained=Owner.retain owner;
      val prior=case Exn.capture Owner.retain prior_owner of Exn.Res prior=>prior
        | Exn.Exn exn=>(Owner.release retained;Exn.reraise exn);
      val result=Exn.capture Root.create{binding={candidate=candidate,baseline=baseline,snapshot=wire,phase=phase},
        candidate=retained,baseline=prior};
    in case result of Exn.Res checked=>checked
      | Exn.Exn exn=>(Owner.release prior;Owner.release retained;Exn.reraise exn) end;
  fun binding checked= #binding(Root.read checked);
  fun executable checked=(ignore(Root.read checked);Qualification.executable);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;
