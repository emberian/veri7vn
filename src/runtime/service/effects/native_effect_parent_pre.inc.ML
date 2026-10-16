(* Lexical include before the ONE parent gate/Owner. Owns resources and exact
   associations only; all generated authority transitions remain in Owner. *)
structure EffectCore=Veri7vn_Native_Effect_Service(structure Scope=RequestScope);
structure EffectInputs=Veri7vn_Native_Effect_Inputs;
structure EffectResponses=Veri7vn_Native_Effect_Responses;
structure EffectObservation=Veri7vn_Native_Effect_Observation;
structure EffectExport=Veri7vn_Native_Effect_Export
  (structure Core=EffectCore val executable=Veri7vn_Native_Effect_Image.executable);
structure EffectRecovery=Veri7vn_Native_Effect_Recovery
  (structure Checkpoint=struct
     fun matches committed projection=case F.decode_state_checked(#checkpoint(Veri7vn_Committed_Native_Recovery.materials committed))of
       SOME state=>F.effect_recovery_matches state projection|NONE=>false
   end
   val request_profile=Veri7vn_Recovery_Manifest.EffectRequest
   val observation_profile=Veri7vn_Recovery_Manifest.EffectSourceObservation
   val executable=Veri7vn_Native_Effect_Image.executable);
structure EffectResident=
struct
  datatype entry=Entry of {native:EffectCore.entry,prepared:serial,prestate:IntInf.int,
    registrations:(IntInf.int*string)list,
    acknowledged:(string*EffectCore.command)option Synchronized.var};
  type source_projection={source:IntInf.int,attempt:IntInf.int,request:IntInf.int,
    configuration:IntInf.int,packet:IntInf.int,semantic:IntInf.int,status:string,
    projection:string,payload:string,bytes:int};
  datatype observation=Observation of {entry:entry,checked:EffectObservation.checked,
    owner:EffectResponses.response,batch:IntInf.int,material:recovery_material,
    projection:source_projection};
  datatype event=Register of entry*IntInf.int*string*(IntInf.int*string)list |
    Reserve of entry | Stage of entry | Start of entry | Observe of observation |
    RestoredRequest of EffectRecovery.View.checked | RestoredSource of EffectRecovery.View.checked;
  datatype source_history=FreshSource of observation|RecoveredSource of EffectRecovery.View.checked;
  datatype transfer=InputTransfer of string*EffectInputs.transfer|ResponseTransfer of string*EffectResponses.transfer;
  datatype publication=Configuration of EffectInputs.configuration|Packet of EffectInputs.prepared|
    Response of EffectResponses.response;
  val configurations=Synchronized.var "effect_configuration_handles" ([]:(serial*EffectInputs.configuration)list);
  val packets=Synchronized.var "effect_packet_handles" ([]:(serial*EffectInputs.prepared)list);
  val responses=Synchronized.var "effect_response_handles" ([]:(serial*EffectResponses.response)list);
  val transfers=Synchronized.var "effect_transfer_handles" ([]:(serial*transfer)list);
  val publications=Synchronized.var "effect_nonce_publications" ([]:(string*publication)list);
  val pending_observations=Synchronized.var "effect_pending_observations"
    ([]:(IntInf.int*(observation*string))list);
  val source_entries=Synchronized.var "effect_committed_sources"
    ([]:(IntInf.int*source_history)list);
  val request_history=Synchronized.var "effect_request_history"
    ([]:(IntInf.int*EffectRecovery.View.checked)list);
  val entries=Synchronized.var "effect_entries" ([]:(IntInf.int*entry)list);
  fun native(Entry{native,...})=native;
  fun names e=EffectCore.names(native e);
  fun key e= #attempt(names e);
  fun entry(Register(e,_,_,_))=e|entry(Reserve e)=e|entry(Stage e)=e|entry(Start e)=e
    |entry(Observe(Observation{entry,...}))=entry
    |entry _=error "Historical effect has no executable entry";
  fun observation_live(Observation{owner,...})=EffectResponses.live owner;
  fun source_projection(observation as Observation{projection,...})=
    (F.guard(observation_live observation) "Native effect source physical owner unavailable";projection);
  fun source_incarnation(Observation{owner,...})=EffectResponses.key owner;
  fun historical_live view=can EffectRecovery.View.projection view;
  fun live(RestoredRequest view)=historical_live view
    |live(RestoredSource view)=historical_live view andalso is_some(EffectRecovery.View.response view)
    |live event=EffectCore.live(native(entry event)) andalso
      (case event of Observe observation=>observation_live observation|_=>true);
  fun is_support(Register _)=true|is_support _=false;
  fun frame(Register(_,_,frame,_)) _=frame
    |frame(Reserve(e as Entry{prestate,...})) _=
      F.effect_reserve_frame(names e)prestate(EffectCore.dependencies(native e))
    |frame(Stage(e as Entry{prestate,...})) _=
      F.effect_stage_frame(names e)prestate(EffectCore.sources(native e))(EffectCore.dependencies(native e))
    |frame(Start e) _=F.effect_start_frame(names e)
    |frame(Observe(Observation{entry,owner,batch,checked,...})) _=
      F.effect_observation_frame batch (#attempt(names entry))
        (P.source_identity(EffectResponses.source owner))
        (case EffectObservation.status checked of EffectObservation.ConfirmedResponse=>false
          |EffectObservation.RejectedResponse=>true)
    |frame _ _=error "Historical effect association cannot emit an event";
  fun exact_start(e as Entry{prestate,...})(actual:F.claim_start)=
    actual=EffectCore.expected(native e)prestate(#epoch actual);
  fun supports(Start e)[F.EffectStart actual]=exact_start e actual
    |supports(Start _) _=false|supports _ commands=null commands;
  fun publish e=Synchronized.change entries(fn all=>
    (F.guard(length all<256 andalso is_none(AList.lookup(op =)all(key e)))
      "Effect entry capacity/duplicate";(key e,e)::all));
  fun lookup id=case AList.lookup(op =)(Synchronized.value entries)id of
    SOME e=>e|NONE=>error "Unknown native effect entry";
  fun configuration key=case AList.lookup(op =)(Synchronized.value configurations)key of
    SOME c=>c|NONE=>error "Unknown native effect configuration";
  fun packet key=case AList.lookup(op =)(Synchronized.value packets)key of
    SOME p=>p|NONE=>error "Unknown native effect packet";
  fun response key=case AList.lookup(op =)(Synchronized.value responses)key of
    SOME r=>r|NONE=>error "Unknown native effect response";
  fun depends id e=member(op =)(EffectCore.managed_dependencies(native e))id;
  fun release_observation(Observation{owner,...})=EffectResponses.release owner;
  (* Source liveness is independent of executable entry/Scope/configuration
     liveness after commit. Parent still checks the latest model association. *)
  fun source_lookup uid=AList.lookup(op =)(Synchronized.value source_entries)uid;
  fun history_projection(FreshSource observation)=source_projection observation
    |history_projection(RecoveredSource view)=
      (case EffectRecovery.View.projection view of
        projection as Veri7vn_Native_Effect_Codec.Observation{original,response,rejected,...}=>
          let val input=the(EffectRecovery.View.response view)
            val raw=Veri7vn_Native_Literals.bytes input val n= #names original
          in {source=response,attempt= #attempt n,request= #request n,configuration= #configuration original,
            packet= #packet original,semantic= #generation n,status=if rejected then "failed"else "confirmed",
            projection=Veri7vn_Native_Effect_Codec.digest(Veri7vn_Native_Effect_Codec.encode projection),
            payload=Veri7vn_Native_Effect_Codec.digest raw,bytes=size raw}:source_projection end
       |_=>error "Historical request is not a retained response");
  fun history_incarnation(FreshSource observation)=source_incarnation observation
    |history_incarnation(RecoveredSource view)=EffectRecovery.View.incarnation view;
  fun history_live(FreshSource observation)=observation_live observation
    |history_live(RecoveredSource view)=historical_live view andalso is_some(EffectRecovery.View.response view);
  fun history_release(FreshSource observation)=release_observation observation
    |history_release(RecoveredSource view)=EffectRecovery.View.release view;
  (* Aggregate restore calls this only after SAME committed capability and
     shared Pool/G validation, before closing the recovery batch. Publication
     retains independent inert ownership, never executable entry state. *)
  fun publish_restored view=
    let val projection=EffectRecovery.View.projection view
      val retained=EffectRecovery.View.retain view
      val result=Exn.capture(fn()=>case projection of
          Veri7vn_Native_Effect_Codec.Request original=>
            let val rid= #request(#names original)
            in Synchronized.change request_history(fn all=>
              (F.guard(is_none(AList.lookup(op =)all rid)) "Duplicate restored effect request";
               (rid,retained)::all));RestoredRequest retained end
        |Veri7vn_Native_Effect_Codec.Observation{response,...}=>
            (Synchronized.change source_entries(fn all=>
              (F.guard(is_none(AList.lookup(op =)all response)) "Duplicate restored effect source";
               (response,RecoveredSource retained)::all));RestoredSource retained))()
    in case result of Exn.Res event=>event|Exn.Exn failure=>
      (EffectRecovery.View.release retained;Exn.reraise failure)end;
  fun release e=(EffectCore.release(native e);
    Synchronized.change entries(AList.delete(op =)(key e)));
end;
