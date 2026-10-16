(* Lexical include before the ONE parent gate/Owner. Owns resources and exact
   associations only; all generated authority transitions remain in Owner. *)
structure EffectCore=Veri7vn_Native_Effect_Service(structure Scope=RequestScope);
structure EffectInputs=Veri7vn_Native_Effect_Inputs;
structure EffectResponses=Veri7vn_Native_Effect_Responses;
structure EffectObservation=Veri7vn_Native_Effect_Observation;
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
    Reserve of entry | Stage of entry | Start of entry | Observe of observation;
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
    ([]:(IntInf.int*observation)list);
  val entries=Synchronized.var "effect_entries" ([]:(IntInf.int*entry)list);
  fun native(Entry{native,...})=native;
  fun names e=EffectCore.names(native e);
  fun key e= #attempt(names e);
  fun entry(Register(e,_,_,_))=e|entry(Reserve e)=e|entry(Stage e)=e|entry(Start e)=e
    |entry(Observe(Observation{entry,...}))=entry;
  fun observation_live(Observation{owner,...})=EffectResponses.live owner;
  fun source_projection(observation as Observation{projection,...})=
    (F.guard(observation_live observation) "Native effect source physical owner unavailable";projection);
  fun source_incarnation(Observation{owner,...})=EffectResponses.key owner;
  fun live event=EffectCore.live(native(entry event)) andalso
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
          |EffectObservation.RejectedResponse=>true);
  fun exact_start(e as Entry{prestate,...})(actual:F.claim_start)=
    actual=EffectCore.expected(native e)prestate(#epoch actual);
  fun supports(Start e)[F.EffectStart actual]=exact_start e actual
    |supports(Start _) _=false|supports _ commands=null commands;
  fun publish e=Synchronized.change entries(fn all=>
    (F.guard(length all<256 andalso is_none(AList.lookup(op =)all(key e)))
      "Effect entry capacity/duplicate";(key e,e)::all));
  fun lookup id=case AList.lookup(op =)(Synchronized.value entries)id of
    SOME e=>e|NONE=>error "Unknown native effect entry";
  fun configuration handle=case AList.lookup(op =)(Synchronized.value configurations)handle of
    SOME c=>c|NONE=>error "Unknown native effect configuration";
  fun packet handle=case AList.lookup(op =)(Synchronized.value packets)handle of
    SOME p=>p|NONE=>error "Unknown native effect packet";
  fun response handle=case AList.lookup(op =)(Synchronized.value responses)handle of
    SOME r=>r|NONE=>error "Unknown native effect response";
  fun depends id e=member(op =)(EffectCore.managed_dependencies(native e))id;
  fun release_observation(Observation{owner,...})=EffectResponses.release owner;
  (* Source liveness is independent of executable entry/Scope/configuration
     liveness after commit. Parent still checks the latest model association. *)
  fun source_lookup uid=AList.lookup(op =)(Synchronized.value source_entries)uid;
  fun release e=(EffectCore.release(native e);
    Synchronized.change entries(AList.delete(op =)(key e)));
end;
