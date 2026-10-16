(* Protected qualification-role checkers. The static Checkpoint implementation is
   the shared generated Frame namespace, never a runtime supplied callback. *)
signature VERI7VN_QUALIFICATION_CHECKPOINT =
sig
  val initial:string -> Veri7vn_Qualification_Codec.initial -> bool
  val update:string -> Veri7vn_Qualification_Codec.update -> bool
end;

functor Veri7vn_Checked_Qualification_Root
  (type payload val live:payload -> bool val dispose:payload -> unit) :>
sig
  type checked
  val create:payload -> checked
  val read:checked -> payload
  val is_live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end =
struct
  datatype checked=Checked of {root:(payload*int)option Synchronized.var,active:bool Synchronized.var};
  fun require true _=() | require false message=error message;
  fun create payload=(require(live payload) "Checked qualification root unavailable";
    Checked{root=Synchronized.var "checked_qualification_root"(SOME(payload,1)),
      active=Synchronized.var "checked_qualification_handle" true});
  fun read(Checked{root,active})=(require(Synchronized.value active) "Checked qualification handle released";
    case Synchronized.value root of SOME(payload,_)=>
      (require(live payload) "Checked qualification inputs invalidated";payload)
    | NONE=>error "Checked qualification root released");
  fun is_live checked=(ignore(read checked);true) handle ERROR _=>false;
  fun retain(Checked{root,active})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change_result active(fn current=>
    let val _=require current "Checked qualification handle released"
      val _=Synchronized.change root(fn stored=>case stored of SOME(payload,refs)=>
        (require(live payload andalso refs<8192) "Checked qualification lease unavailable/bounds";
          SOME(payload,refs+1)) | NONE=>error "Checked qualification root released")
    in (Checked{root=root,active=Synchronized.var "retained_qualification_handle" true},current) end));
  fun release(Checked{root,active})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change active(fn current=>if not current then false else
      (Synchronized.change root(fn stored=>case stored of NONE=>NONE | SOME(payload,refs)=>
        if refs>1 then SOME(payload,refs-1) else (dispose payload;NONE));false)));
end;

structure Veri7vn_Qualification_Material_Check =
struct
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  fun require true _=() | require false message=error message;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun closure image executable=
    let fun encoded raw=Bytes.content(Base64.encode(Bytes.string raw))
    in YXML.string_of_body[XML.Elem(("qualification-code-closure",[("version","1")]),
      XML.Encode.pair XML.Encode.string XML.Encode.string
        (encoded(V.context_closure image),encoded(Pin.material executable)))] end;
  fun check image executable expected_role marker committed=
    let
      val _=require(C.is_live committed) "Qualification committed material released";
      val m=C.materials committed;
      val envelope=M.decode{max_bytes=8192}(#manifest m);
      val _=M.require_profile expected_role envelope;
      val _=require(#workspace envelope= #workspace m andalso #association envelope= #association m andalso
        #semantic_generation envelope= #semantic_generation m andalso
        #reconstruction envelope=M.Controlled_Recipe andalso C.reconstruction committed=M.Controlled_Recipe)
        "Qualification material identity/recipe mismatch";
      val _=require(#sequent m="" andalso #reconstruction m=marker andalso
        #context_closure m=closure image executable) "Qualification profile/image/empty-sequent mismatch";
      val _=require(#projection envelope=digest(#projection m) andalso
        #sequent envelope=digest(#sequent m) andalso #context_closure envelope=digest(#context_closure m) andalso
        #payload envelope=digest(#reconstruction m) andalso #executable envelope=SOME(Pin.digest executable))
        "Qualification protected payload/code integrity mismatch";
    in m end;
end;

functor Veri7vn_Check_Initial_Qualification
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Owner:VERI7VN_BUILD_CANDIDATE_LEASE
   structure Admission:VERI7VN_INITIAL_PACKAGE_ADMISSION
   structure Checkpoint:VERI7VN_QUALIFICATION_CHECKPOINT
   sharing type Intent.intent=Builder.export_intent=Admission.intent
   sharing type Builder.candidate=Owner.candidate=Admission.candidate) :>
sig
  include VERI7VN_CHECKED_INITIAL_QUALIFICATION
    where type candidate=Builder.candidate and type intent=Intent.intent
  val check:Veri7vn_Native_Identity_Allocator.allocator -> Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Committed_Native_Recovery.committed -> Owner.lease -> checked
end =
struct
  structure Wire=Veri7vn_Qualification_Codec;
  structure C=Veri7vn_Qualification_Material_Check;
  structure T=Veri7vn_Qualification_Recovery_Types;
  structure P=Veri7vn_Managed_Provenance;
  structure Q=Admission;
  structure N=Veri7vn_Native_Descriptor;
  structure V=Veri7vn_Qualification_Restore_Check;
  type candidate=Builder.candidate;
  type intent=Intent.intent;
  type binding={candidate:candidate,intent:intent,context:T.initial_context,names:T.names,
    candidate_pin:T.candidate_pin,profile:string,count:int,dependencies:IntInf.int list,exports:T.sequents};
  type payload={binding:binding,owner:Owner.lease,observation:Q.observation};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({owner,observation,...}:payload)=>Owner.is_live owner andalso Q.is_live observation
    val dispose=fn({owner,observation,...}:payload)=>(Q.release observation;Owner.release owner));
  type checked=Root.checked;
  structure Bind=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=checked
    fun bindings checked=let val b= #binding(Root.read checked)
      in [{workspace=Veri7vn_Managed_Provenance.development_workspace(Builder.development(#candidate b)),
        generation=Q.observer_generation,semantic_generation= #semantic_generation(#names b)}] end
  end);
  val fragment=Bind.fragment;

  fun check allocator image committed owner=
    let
      val m=C.check image Q.executable Veri7vn_Recovery_Manifest.InitialQualification "initial-qualification/2" committed;
      val wire=Wire.decode_initial(#projection m);
      val _=C.require(Owner.is_live owner) "Initial qualification candidate lease unavailable";
      val candidate=Owner.candidate owner;
      val intent=Builder.original_intent candidate;
      val projection=Builder.projection candidate;
      val original=Intent.binding intent;
      val context= #context wire;
      val names= #names wire;
      val _=C.require(#association m= #evidence names andalso #semantic_generation m= #semantic_generation names andalso
        #workspace m=Veri7vn_Native_Identity_Allocator.workspace allocator andalso
        #workspace m=Intent.workspace intent andalso #candidate wire=projection andalso #profile wire=Q.profile)
        "Initial qualification native identity/profile mismatch";
      val _=C.require(case N.lookup_semantic_generation_id allocator Q.observer_generation of
        NONE=>true | SOME id=>id= #semantic_generation names) "Initial qualification observer generation mismatch";
      val candidate_generation=case N.lookup_semantic_generation_id allocator(Builder.native_generation candidate) of
        SOME id=>id | NONE=>error "Initial qualification candidate generation unregistered";
      val _=C.require(#semantic_generation names<>candidate_generation) "Observer pin aliases candidate subject meaning";
      val expected=distinct(op =)([#request_slot context,#candidate projection,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,
        #executable_generation context,#interpretation context,#semantic_generation names,candidate_generation,
        P.source_identity(#source original),#source_revision original,#manifest original,#export_intent original] @
        #dependencies projection @ #dependencies original);
      val _=C.require(#dependencies wire=expected andalso Checkpoint.initial(#checkpoint m)wire)
        "Initial qualification checkpoint membership/closure mismatch";
      val retained=Owner.retain owner;
      fun produce()=
        let val observation=Q.measure intent candidate
          fun finish()=(C.require(Q.count observation= #count wire) "Initial qualification saved count differs";
            V.exports(#exports wire)(Q.checked_exports observation);
            Root.create{binding={candidate=candidate,intent=intent,context=context,names=names,
              candidate_pin=projection,profile=Q.profile,count= #count wire,
              dependencies=expected,exports= #exports wire},owner=retained,observation=observation})
        in case Exn.capture finish() of Exn.Res result=>result
          | Exn.Exn exn=>(Q.release observation;Exn.reraise exn) end;
    in case Exn.capture produce() of Exn.Res result=>result
      | Exn.Exn exn=>(Owner.release retained;Exn.reraise exn) end;
  fun binding checked= #binding(Root.read checked);
  fun executable checked=(ignore(Root.read checked);Q.executable);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;

functor Veri7vn_Check_Update_Qualification
  (structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Owner:VERI7VN_BUILD_CANDIDATE_LEASE
   structure Qualification:VERI7VN_PACKAGE_QUALIFICATION
   structure Checkpoint:VERI7VN_QUALIFICATION_CHECKPOINT
   sharing type Builder.candidate=Owner.candidate=Qualification.candidate) :>
sig
  include VERI7VN_CHECKED_UPDATE_QUALIFICATION where type candidate=Builder.candidate
  val check:Veri7vn_Native_Identity_Allocator.allocator -> Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Committed_Native_Recovery.committed -> {candidate:Owner.lease,baseline:Owner.lease} -> checked
end =
struct
  structure Wire=Veri7vn_Qualification_Codec;
  structure C=Veri7vn_Qualification_Material_Check;
  structure T=Veri7vn_Qualification_Recovery_Types;
  structure Q=Qualification;
  structure N=Veri7vn_Native_Descriptor;
  structure V=Veri7vn_Qualification_Restore_Check;
  type candidate=Builder.candidate;
  type binding={candidate:candidate,baseline:candidate,context:T.update_context,names:T.names,
    candidate_pin:T.candidate_pin,baseline_pin:T.candidate_pin,profile:string,count:int,
    dependencies:IntInf.int list,expected_exports:T.sequents,exports:T.sequents};
  type payload={binding:binding,candidate:Owner.lease,baseline:Owner.lease,
    contract:Q.contract,observation:Q.observation};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({candidate,baseline,contract,observation,...}:payload)=>
      Owner.is_live candidate andalso Owner.is_live baseline andalso Q.contract_live contract andalso Q.is_live observation
    val dispose=fn({candidate,baseline,contract,observation,...}:payload)=>
      (Q.release observation;Q.release_contract contract;Owner.release baseline;Owner.release candidate));
  type checked=Root.checked;
  structure Bind=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=checked
    fun bindings checked=let val b= #binding(Root.read checked)
      in [{workspace=Veri7vn_Managed_Provenance.development_workspace(Builder.development(#candidate b)),
        generation=Q.observer_generation,semantic_generation= #semantic_generation(#names b)}] end
  end);
  val fragment=Bind.fragment;

  fun check allocator image committed {candidate=owner,baseline=prior_owner}=
    let
      val m=C.check image Q.executable Veri7vn_Recovery_Manifest.UpdateQualification "update-qualification/2" committed;
      val wire=Wire.decode_update(#projection m);
      val _=C.require(Owner.is_live owner andalso Owner.is_live prior_owner) "Update qualification candidate leases unavailable";
      val candidate=Owner.candidate owner;
      val baseline=Owner.candidate prior_owner;
      val projection=Builder.projection candidate;
      val previous=Builder.projection baseline;
      val context= #context wire;
      val names= #names wire;
      val _=C.require(#association m= #evidence names andalso #semantic_generation m= #semantic_generation names andalso
        #workspace m=Veri7vn_Native_Identity_Allocator.workspace allocator andalso
        #workspace m=Veri7vn_Managed_Provenance.development_workspace(Builder.development candidate) andalso
        #candidate wire=projection andalso #baseline wire=previous andalso #profile wire=Q.profile andalso
        #candidate projection<> #candidate previous andalso #previous context=SOME(#candidate previous))
        "Update qualification native baseline/identity/profile mismatch";
      val _=C.require(case N.lookup_semantic_generation_id allocator Q.observer_generation of
        NONE=>true | SOME id=>id= #semantic_generation names) "Update qualification observer generation mismatch";
      fun subject_generation subject=case N.lookup_semantic_generation_id allocator(Builder.native_generation subject) of
        SOME id=>id | NONE=>error "Update qualification subject generation unregistered";
      val candidate_generation=subject_generation candidate;
      val baseline_generation=subject_generation baseline;
      val _=C.require(#semantic_generation names<>candidate_generation andalso
        #semantic_generation names<>baseline_generation) "Observer pin aliases subject meaning";
      val expected=distinct(op =)([#request_slot context,#candidate projection,#candidate previous,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,#executable_generation context,
        #interpretation context,#semantic_generation names,candidate_generation,baseline_generation] @ #dependencies projection @ #dependencies previous);
      val _=C.require(#dependencies wire=expected andalso Checkpoint.update(#checkpoint m)wire)
        "Update qualification checkpoint membership/closure mismatch";
      val _=V.exports(#expected_exports wire)(Builder.exports baseline);
      val retained=Owner.retain owner;
      val prior=(case Exn.capture Owner.retain prior_owner of Exn.Res prior=>prior |
        Exn.Exn exn=>(Owner.release retained;Exn.reraise exn));
      val contract=(case Exn.capture Q.retain_baseline_contract baseline of Exn.Res contract=>contract |
        Exn.Exn exn=>(Owner.release prior;Owner.release retained;Exn.reraise exn));
      fun produce()=
        let val observation=Q.measure contract candidate
          fun finish()=(C.require(Q.count observation= #count wire) "Update qualification saved count differs";
            V.exports(#exports wire)(Q.checked_exports observation);
            Root.create{binding={candidate=candidate,baseline=baseline,context=context,names=names,
              candidate_pin=projection,baseline_pin=previous,profile=Q.profile,count= #count wire,
              dependencies=expected,expected_exports= #expected_exports wire,exports= #exports wire},
              candidate=retained,baseline=prior,contract=contract,observation=observation})
        in case Exn.capture finish() of Exn.Res result=>result
          | Exn.Exn exn=>(Q.release observation;Exn.reraise exn) end;
    in case Exn.capture produce() of Exn.Res result=>result
      | Exn.Exn exn=>(Q.release_contract contract;Owner.release prior;Owner.release retained;Exn.reraise exn) end;
  fun binding checked= #binding(Root.read checked);
  fun executable checked=(ignore(Root.read checked);Q.executable);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;
