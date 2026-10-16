(* Lexical include after Owner/issue_gate_token/launch_cleanup in the SAME sealed
   parent. No alternate authority store or reducer lives in this include. *)
type effect_workspace={inputs:EffectInputs.pool,responses:EffectResponses.pool,owner:EffectCore.owner};
val effect_workspace=Synchronized.var "native_effect_workspace" (NONE:effect_workspace option);
fun local_effect_workspace()=Synchronized.change_result effect_workspace(fn previous=>
  case previous of SOME workspace=>(workspace,previous)
  |NONE=>let val ids=identity_allocator()
      val workspace={inputs=EffectInputs.create ids,responses=EffectResponses.create ids,
        owner=EffectCore.create ids boot_policy}
    in(workspace,SOME workspace)end);
fun effect_serial text=let val value=decimal text
  in F.guard(value>0) "Effect serial bound";
    IntInf.toInt value end;
fun effect_attributes tag version fields chunks=
  let val raw=case chunks of [bytes]=>Bytes.content bytes|_=>error "Effect metadata artifact count"
    val _=F.guard(size raw>0 andalso size raw<=16384) "Effect metadata bound"
    val attributes=case YXML.parse_body raw of [XML.Elem((name,attributes),[])]=>
      (F.guard(name=tag) "Effect metadata tag";attributes)
      |_=>error "Effect metadata shape"
    val _=F.guard(sort_strings(map fst attributes)=sort_strings fields andalso
      length(distinct(op =)(map fst attributes))=length fields) "Effect metadata fields"
    fun field key=the(AList.lookup(op =)attributes key)
    val _=F.guard(field "version"=version) "Effect metadata version"
  in field end;
fun effect_source_metadata chunks=
  let val field=effect_attributes "effect-source" "1"
      ["version","nonce","draft","head","member","sha256","size"]chunks
    val count=decimal(field "size")
    val _=F.guard(count>0 andalso count<=65536) "Effect source size"
  in(field "nonce",{draft=field "draft",head=field "head",member=field "member",
    sha256=field "sha256",size=IntInf.toInt count}:EffectInputs.source_data)end;
fun effect_configuration_metadata chunks=
  let val field=effect_attributes "effect-source" "2"
      ["version","nonce","draft","head","member","sha256","size","configurationEpoch"]chunks
    val count=decimal(field "size")
    val epoch=decimal(field "configurationEpoch")
    val _=F.guard(count>0 andalso count<=65536) "Effect configuration size"
  in(field "nonce",{draft=field "draft",head=field "head",member=field "member",
    sha256=field "sha256",size=IntInf.toInt count}:EffectInputs.source_data,epoch)end;
fun effect_response_metadata chunks=
  let val field=effect_attributes "effect-response-source" "1" ["version","nonce","sha256","size"]chunks
    val count=decimal(field "size")
    val _=F.guard(count>0 andalso count<=65536) "Effect response size"
  in(field "nonce",{sha256=field "sha256",size=IntInf.toInt count}:EffectResponses.metadata)end;
fun effect_transfer_key(EffectResident.InputTransfer(_,t))=EffectInputs.transfer_key t
  |effect_transfer_key(EffectResident.ResponseTransfer(_,t))=EffectResponses.transfer_key t;
fun effect_transfer_nonce(EffectResident.InputTransfer(nonce,_))=nonce
  |effect_transfer_nonce(EffectResident.ResponseTransfer(nonce,_))=nonce;
fun effect_save_transfer transfer=
  let val key=effect_transfer_key transfer
    val _=Synchronized.change EffectResident.transfers(fn all=>
      (F.guard(length all<4 orelse is_some(AList.lookup(op =)all key)) "Effect transfer table capacity";
       AList.update(op =)(key,transfer)all))
  in key end;
fun effect_transfer_lookup key=case AList.lookup(op =)(Synchronized.value EffectResident.transfers)key of
  SOME transfer=>transfer|NONE=>error "Unknown native effect transfer";
fun effect_begin id operation payload chunks=
  let val {inputs,responses,...}=local_effect_workspace()
    val transfer=case operation of
      "effect_config_begin"=>let val _=F.guard(payload="") "Configuration begin payload"
        val(nonce,data,epoch)=effect_configuration_metadata chunks
      in EffectResident.InputTransfer(nonce,EffectInputs.begin_configuration inputs nonce data epoch)end
    |"effect_packet_begin"=>let val config=EffectResident.configuration(effect_serial payload)
        val(nonce,data)=effect_source_metadata chunks
      in EffectResident.InputTransfer(nonce,EffectInputs.begin_packet inputs config nonce data)end
    |"effect_response_begin"=>let
        val(gate,incarnation,permit)=case space_explode "," payload of [gate,incarnation,permit]=>
          (gate,effect_serial incarnation,effect_serial permit)|_=>error "Response consumed origin shape"
        val matches=filter(fn(_,EffectResident.Entry{acknowledged,...})=>
          case Synchronized.value acknowledged of SOME(saved,_)=>saved=gate|NONE=>false)
          (Synchronized.value EffectResident.entries)
        val entry=case matches of [(_,entry)]=>entry|_=>error "Response consumed origin unavailable"
        val(nonce,data)=effect_response_metadata chunks
      in EffectResident.ResponseTransfer(nonce,EffectCore.begin_response(EffectResident.native entry)
        responses gate incarnation permit nonce data)end
    |_=>error "Unknown effect begin operation"
    val key=effect_save_transfer transfer
  in emit id "effect_transfer"(commas[effect_transfer_nonce transfer,Int.toString key])[]end;
fun effect_write id payload chunks=
  let val(key,offset)=case space_explode "," payload of [key,offset]=>(effect_serial key,decimal offset)
        |_=>error "Effect write shape"
    val _=F.guard(offset>=0 andalso offset<=65536) "Effect write offset"
    val bytes=case chunks of [bytes]=>bytes|_=>error "Effect write artifact count"
    val transfer=effect_transfer_lookup key
    val _=case transfer of EffectResident.InputTransfer(_,t)=>EffectInputs.write t(IntInf.toInt offset)bytes
      |EffectResident.ResponseTransfer(_,t)=>EffectResponses.write t(IntInf.toInt offset)bytes
  in emit id "effect_written"(commas[Int.toString key,IntInf.toString(offset+IntInf.fromInt(Bytes.size bytes))])[]end;
fun effect_finish id payload=
  let val transfer=effect_transfer_lookup(effect_serial payload)
    val publication=case transfer of EffectResident.InputTransfer(_,t)=>
      (case EffectInputs.finish t of EffectInputs.InstalledConfiguration c=>EffectResident.Configuration c
       |EffectInputs.PreparedPacket p=>EffectResident.Packet p)
      |EffectResident.ResponseTransfer(_,t)=>EffectResident.Response(EffectResponses.finish t)
    val nonce=effect_transfer_nonce transfer
    val _=Synchronized.change EffectResident.publications(AList.update(op =)(nonce,publication))
  in emit id "effect_finished" nonce []end;
fun effect_accept id nonce=
  let val {inputs,responses,...}=local_effect_workspace()
    val publication=case AList.lookup(op =)(Synchronized.value EffectResident.publications)nonce of
      SOME publication=>publication|NONE=>error "Effect publication not finished"
    val(tag,fields)=case publication of EffectResident.Configuration _=>
      (case EffectInputs.accept_nonce inputs nonce of EffectInputs.InstalledConfiguration c=>
        let val key=EffectInputs.configuration_key c
          val _=Synchronized.change EffectResident.configurations(AList.update(op =)(key,c))
        in("effect_configuration",[nonce,Int.toString key,
          IntInf.toString(P.source_identity(EffectInputs.configuration_source c))])end
      |_=>error "Effect configuration acceptance changed kind")
    |EffectResident.Packet _=>
      (case EffectInputs.accept_nonce inputs nonce of EffectInputs.PreparedPacket p=>
        let val key=EffectInputs.prepared_key p
          val _=Synchronized.change EffectResident.packets(AList.update(op =)(key,p))
        in("effect_packet",[nonce,Int.toString key])end
      |_=>error "Effect packet acceptance changed kind")
    |EffectResident.Response _=>let val response=EffectResponses.accept_nonce responses nonce
        val key=EffectResponses.key response
        val _=Synchronized.change EffectResident.responses(AList.update(op =)(key,response))
      in("effect_response",[nonce,Int.toString key,IntInf.toString(P.source_identity(EffectResponses.source response))])end
  in emit id tag(commas fields)[]end;
fun effect_discard id nonce=
  let val {inputs,responses,...}=local_effect_workspace()
    (* Unknown/lost-begin replies must also leave an abandonment marker. Both
       bounded inert pools may see the nonce; neither operation grants access. *)
    val _=EffectInputs.discard_nonce inputs nonce
    val _=EffectResponses.discard_nonce responses nonce
    val _=Synchronized.change EffectResident.publications(AList.delete(op =)nonce)
  in emit id "effect_discarded" nonce []end;
fun effect_settle id nonce=
  let val {inputs,responses,...}=local_effect_workspace()
    val _=EffectInputs.settle_nonce inputs nonce
    val _=EffectResponses.settle_nonce responses nonce
    val _=Synchronized.change EffectResident.transfers(filter_out(fn(_,t)=>effect_transfer_nonce t=nonce))
    val _=Synchronized.change EffectResident.publications(AList.delete(op =)nonce)
  in emit id "effect_settled" nonce []end;
fun effect_release id operation payload=
  let val key=effect_serial payload
    val tag=case operation of "effect_config_release"=>
      (EffectInputs.release_configuration(EffectResident.configuration key);
       Synchronized.change EffectResident.configurations(AList.delete(op =)key);"effect_config_released")
    |"effect_packet_release"=>
      (EffectInputs.release(EffectResident.packet key);
       Synchronized.change EffectResident.packets(AList.delete(op =)key);"effect_packet_released")
    |"effect_response_release"=>
      (EffectResponses.release(EffectResident.response key);
       Synchronized.change EffectResident.responses(AList.delete(op =)key);"effect_response_released")
    |_=>error "Unknown effect release operation"
  in emit id tag(Int.toString key)[]end;
fun effect_transfer id operation payload chunks=case operation of
    "effect_config_begin"=>effect_begin id operation payload chunks
  |"effect_packet_begin"=>effect_begin id operation payload chunks
  |"effect_response_begin"=>effect_begin id operation payload chunks
  |"effect_input_write"=>effect_write id payload chunks
  |"effect_input_finish"=>(F.guard(null chunks) "Effect finish artifacts";effect_finish id payload)
  |"effect_input_accept"=>(F.guard(null chunks) "Effect accept artifacts";effect_accept id payload)
  |"effect_input_discard"=>(F.guard(null chunks) "Effect discard artifacts";effect_discard id payload)
  |"effect_input_settle"=>(F.guard(null chunks) "Effect settle artifacts";effect_settle id payload)
  |_=>(F.guard(null chunks) "Effect release artifacts";effect_release id operation payload);
(* Reserve is the first durable prefix: it owns the exact original request
   recipe before any support rows or attempt can exist. Subsequent gates retain
   that same inert recipe; it never reconstructs permission to invoke. *)
fun effect_material profile association semantic dependencies
    (artifact:EffectExport.artifacts):recovery_material=
  let fun digest bytes=Message_Digest.rep(SHA256.digest bytes)
    val manifest=Veri7vn_Recovery_Manifest.encode{profile=profile,
      workspace=I.workspace(identity_allocator()),association=association,
      semantic_generation=semantic,projection=digest(#projection artifact),
      sequent=digest(#sequent artifact),context_closure=digest(#context_closure artifact),
      payload=digest(#reconstruction artifact),
      reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,
      executable=SOME(Veri7vn_Native_Recovery_Pin.digest Veri7vn_Native_Effect_Image.executable)}
  in {association=association,semantic_generation=semantic,manifest=manifest,
    projection= #projection artifact,sequent= #sequent artifact,
    context_closure= #context_closure artifact,reconstruction= #reconstruction artifact,
    executable=SOME(#executable artifact),dependencies=distinct(op =)(association::dependencies)} end;
fun effect_request_material(entry as EffectResident.Entry{prestate,...})=
  let val native=EffectResident.native entry
    val original=EffectCore.original_metadata native prestate
    val artifact=EffectExport.request(identity_allocator())(boot_image())native prestate
  in effect_material Veri7vn_Recovery_Manifest.EffectRequest
    (#request(#names original))(#generation(#names original))
    (F.effect_request_dependencies original)artifact end;
fun effect_issue event=
  let val material=case event of EffectResident.Observe(EffectResident.Observation{material,...})=>material
        |EffectResident.RestoredRequest _=>error "Historical effect cannot issue a gate"
        |EffectResident.RestoredSource _=>error "Historical effect cannot issue a gate"
        |_=>effect_request_material(EffectResident.entry event)
  in issue_gate_token(Effect event)(SOME material)end;
(* Caller passes commands from the SAME Owner.valid pending candidate. Retain
   that actual command before journaling, never a guessed current epoch. *)
fun effect_command_info token event commands=case event of EffectResident.Start(entry as EffectResident.Entry{acknowledged,...})=>
    (case commands of [F.EffectStart actual]=>
      let val _=F.guard(EffectResident.exact_start entry actual) "Effect candidate command differs from original"
        val _=Synchronized.change acknowledged(K(SOME(token,actual)))
      in SOME(F.effect_command_descriptor actual)end
      |_=>error "Effect pending command shape")
  |_=>NONE;
fun effect_supports entry remaining=case remaining of []=>ignore(effect_issue(EffectResident.Stage entry))
  |(key,frame)::rest=>let val event=EffectResident.Register(entry,key,frame,rest)
    in if Owner.registration_present(Effect event)then effect_supports entry rest
       else ignore(effect_issue event)end;
fun effect_after_ack_support(EffectResident.Register(entry,_,_,remaining))=effect_supports entry remaining
  |effect_after_ack_support _=error "Native effect support gate required";
fun effect_after_ack event commands _=
  case event of EffectResident.Register(entry,_,_,remaining)=>effect_supports entry remaining
  |EffectResident.Reserve(entry as EffectResident.Entry{registrations,...})=>effect_supports entry registrations
  |EffectResident.Stage entry=>ignore(effect_issue(EffectResident.Start entry))
  |EffectResident.Start(entry as EffectResident.Entry{acknowledged,...})=>
    let val actual=case commands of [F.EffectStart command]=>command
          |_=>error "Acknowledged native effect command shape"
      val(token,expected)=the(Synchronized.value acknowledged)
      val _=F.guard(actual=expected andalso EffectResident.exact_start entry actual andalso
        Owner.effect_current_context(#attempt actual)) "Acknowledged native effect context changed"
    in EffectCore.acknowledged_start(EffectResident.native entry)token actual end
  |EffectResident.Observe(observation as EffectResident.Observation{projection,...})=>
    let val uid= #source projection
      val _=F.guard(EffectResident.observation_live observation andalso null commands)
        "Acknowledged effect observation lost owned source"
      val _=Synchronized.change EffectResident.source_entries(fn all=>
        (F.guard(is_none(AList.lookup(op =)all uid)) "Effect observation already installed";
         (uid,EffectResident.FreshSource observation)::all))
    in Synchronized.change EffectResident.pending_observations(AList.delete(op =)uid)end
  |EffectResident.RestoredRequest _=>error "Historical effect request cannot acknowledge an event"
  |EffectResident.RestoredSource _=>error "Historical effect source cannot acknowledge an event";
fun effect_propose id payload=
  let val(prepared,operation)=case space_explode "," payload of [prepared,operation]=>
      (effect_serial prepared,case operation of "Discover"=>EffectCore.Discover
       |"QualifyCounter"=>EffectCore.QualifyCounter|"InvokeCounter"=>EffectCore.InvokeCounter
       |_=>error "Unsupported fixed native effect operation")|_=>error "Effect proposal shape"
    val {owner,...}=local_effect_workspace()
    val native=EffectCore.prepare owner operation(EffectResident.packet prepared)
    val entry_slot=Unsynchronized.ref(NONE:EffectResident.entry option)
    val result=Exn.capture(fn()=>let val names=EffectCore.names native
        val registrations=F.effect_registration_frames names(EffectCore.dependencies native)
        val entry=EffectResident.Entry{native=native,prepared=prepared,prestate=Owner.current_revision(),
          registrations=registrations,acknowledged=Synchronized.var "effect_acknowledged_origin" NONE}
        val _=EffectResident.publish entry
        val _=entry_slot:=SOME entry
        val _=ignore(effect_issue(EffectResident.Reserve entry))
      in emit id "effect_proposed"(IntInf.toString(#attempt names))[]end)()
  in case result of Exn.Res()=>()|Exn.Exn failure=>((case !entry_slot of SOME entry=>EffectResident.release entry
    |NONE=>EffectCore.release native);Exn.reraise failure)end;
fun effect_consume id payload=
  let val(token,incarnation)=case space_explode "," payload of [token,incarnation]=>
      (token,effect_serial incarnation)|_=>error "Effect consume shape"
    val matches=filter(fn(_,EffectResident.Entry{acknowledged,...})=>
      case Synchronized.value acknowledged of SOME(saved,_)=>saved=token|NONE=>false)
      (Synchronized.value EffectResident.entries)
    val entry=case matches of [(_,entry)]=>entry|_=>error "Effect acknowledged origin unavailable"
    val _=F.guard(Owner.effect_current_context(EffectResident.key entry)) "Effect handoff context unavailable"
    val receipt=EffectCore.consume_start(EffectResident.native entry)token incarnation
  in emit id "effect_permit"(commas[token,Int.toString(#incarnation receipt),
      Int.toString(#permit receipt)]) [Bytes.string(F.effect_command_descriptor(#command receipt))]end;

(* A response upload is not admission. Only this closed gate checks the
   actual consumed origin, exact generated encoding witness and current paid
   attempt before deriving the response's retained row. *)
fun effect_observation_prepare id payload chunks=
  let val response_handle=effect_serial payload
    val witness=case chunks of [bytes]=>Bytes.content bytes|_=>error "Effect observation witness count"
    val _=F.guard(size witness<=524288) "Effect observation witness bound"
    val response=EffectResident.response response_handle
    val origin=EffectResponses.origin response
    val entries=filter(fn(_,entry)=>EffectCore.incarnation(EffectResident.native entry)= #incarnation origin)
      (Synchronized.value EffectResident.entries)
    val entry=case entries of [(_,entry)]=>entry|_=>error "Original effect response entry unavailable"
    val native=EffectResident.native entry
    val actual=EffectCore.response_state native response
    val original=EffectCore.original_metadata native(#prestate actual)
    val names= #names original
    val expected={workspace= #workspace original,attempt= #attempt names,request= #request names,
      capability= #capability names,operation= #operation original,configuration= #configuration original,
      configuration_epoch= #configuration_epoch original,configuration_source= #configuration_source original,
      packet_source= #packet_source original}:EffectObservation.expected
    val checked=EffectObservation.check expected response witness
    val rejected=case EffectObservation.status checked of EffectObservation.RejectedResponse=>true|_=>false
    val uid=P.source_identity(EffectResponses.source response)
    val query={attempt= #attempt names,source=uid,rejected=rejected}
    val _=F.guard(Owner.effect_observation_permitted query) "Effect response current context denied"
    val dependencies=case Owner.effect_observation_dependencies query of SOME values=>values
      |NONE=>error "Effect response derived retained row unavailable"
    val previous=AList.lookup(op =)(Synchronized.value EffectResident.pending_observations)uid
    val token=case previous of SOME(_,token)=>token|NONE=>
      let val artifact=EffectExport.observation(identity_allocator())(boot_image())native checked witness
        val material=effect_material Veri7vn_Recovery_Manifest.EffectSourceObservation uid
          (#generation names)dependencies artifact
        val projection={source=uid,attempt= #attempt names,request= #request names,
          configuration= #configuration original,packet= #packet original,semantic= #generation names,
          status=if rejected then "failed"else "confirmed",
          projection=Veri7vn_Native_Effect_Codec.digest(#projection artifact),
          payload=Veri7vn_Native_Effect_Codec.digest(#reconstruction artifact),
          bytes=size(#reconstruction artifact)}:EffectResident.source_projection
        val retained=EffectResponses.retain response
        val observation=EffectResident.Observation{entry=entry,checked=checked,owner=retained,
          batch=I.allocate(identity_allocator()),material=material,projection=projection}
        val result=Exn.capture(fn()=>effect_issue(EffectResident.Observe observation))()
      in case result of Exn.Res token=>(Synchronized.change EffectResident.pending_observations
          (cons(uid,(observation,token)));token)
        |Exn.Exn failure=>(EffectResponses.release retained;Exn.reraise failure)end
  in emit id "effect_observation_prepared"
    (commas[token,IntInf.toString uid,IntInf.toString(#attempt names),IntInf.toString(#request names)])[]end;

(* Inert projection only. The parent source-open handler must additionally match
   the latest generated model association and bind Owner version/sequence. *)
fun effect_source_projection uid=
  case EffectResident.source_lookup uid of NONE=>NONE|SOME observation=>
    if EffectResident.history_live observation then
      SOME(EffectResident.history_projection observation,EffectResident.history_incarnation observation)
    else NONE;
fun effect_cleanup action invalidations=
  let val(target,removed)=case action of F.Cancel rid=>(rid,[rid])
      |F.Revoke id=>(id,F.invalidation_ids invalidations)
      |F.Forget id=>(id,F.invalidation_ids invalidations)
      |F.RetireCapability id=>(id,[id])|F.RetireSource id=>(id,[id])
    val entries=map snd(filter(fn(_,entry)=>exists(fn id=>EffectResident.depends id entry)removed)
      (Synchronized.value EffectResident.entries))
    val _=List.app(EffectCore.cancel o EffectResident.native)entries
    val pending=filter(fn(_, (EffectResident.Observation{entry,...},_))=>
      exists(fn id=>EffectResident.depends id entry)removed)(Synchronized.value EffectResident.pending_observations)
    (* Cancellation stops active work/admission; committed retained response
       ownership is not the executable Scope and survives cancellation. *)
    val sources=case action of F.Cancel _=>[]|_=>filter(fn(uid,_)=>member(op =)removed uid)
      (Synchronized.value EffectResident.source_entries)
    val historical_requests=case action of F.Cancel _=>[]|_=>
      filter(fn(rid,_)=>member(op =)removed rid)(Synchronized.value EffectResident.request_history)
    fun release()=(List.app EffectResident.release entries;
      List.app(fn(rid,view)=>(EffectRecovery.View.release view;
        Synchronized.change EffectResident.request_history(AList.delete(op =)rid)))historical_requests;
      List.app(fn(uid,(observation,_))=>(EffectResident.release_observation observation;
        Synchronized.change EffectResident.pending_observations(AList.delete(op =)uid)))pending;
      List.app(fn(uid,observation)=>(EffectResident.history_release observation;
        Synchronized.change EffectResident.source_entries(AList.delete(op =)uid)))sources)
  in if null entries andalso null pending andalso null sources andalso null historical_requests then()else launch_cleanup target release end;

fun effect_current_binding id token=
  case Synchronized.value pending of SOME(current,Effect event,candidate)=>
    if current<>token orelse not(Owner.valid candidate)then emit id "effect_binding_none" token [] else
      let val entry=EffectResident.entry event
        val EffectResident.Entry{prepared,...}=entry
        val _=F.guard(EffectResident.live event) "Effect original source binding unavailable"
        val binding=EffectCore.input_binding(EffectResident.native entry)
        val n=EffectResident.names entry
        val phase=case event of EffectResident.Register _=>"support"|EffectResident.Reserve _=>"reserve"
          |EffectResident.Stage _=>"stage"|EffectResident.Start _=>"start"|EffectResident.Observe _=>"observation"|_=>error "Historical effect has no current source binding"
        val operation=case EffectCore.operation(EffectResident.native entry) of EffectCore.Discover=>"Discover"
          |EffectCore.QualifyCounter=>"QualifyCounter"|EffectCore.InvokeCounter=>"InvokeCounter"
        val response=case event of EffectResident.Observe observation=> #source(EffectResident.source_projection observation)|_=>0
        val raw=YXML.string_of_body[XML.Elem(("effect-binding",[("version","1"),("token",token),("phase",phase),
          ("prepared",Int.toString prepared),
          ("configuration",Int.toString(EffectInputs.configuration_key(#configuration_owner binding))),
          ("incarnation",Int.toString(EffectCore.incarnation(EffectResident.native entry))),
          ("attempt",IntInf.toString(#attempt n)),("request",IntInf.toString(#request n)),
          ("response",IntInf.toString response),("operation",operation),("protocol","local-mcp/1"),
          ("artifact",Veri7vn_Native_Recovery_Pin.digest Veri7vn_Native_Effect_Image.executable)]),[])]
        val _=F.guard(size raw<=4096) "Effect original binding frame bound"
      in emit id "effect_binding" token[Bytes.string raw]end
  |_=>emit id "effect_binding_none" token [];
