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
fun effect_issue event=
  let val token=issue_gate_token(Effect event)NONE
    val _=case event of EffectResident.Start(e as EffectResident.Entry{acknowledged,prestate,...})=>
      Synchronized.change acknowledged(K(SOME(token,EffectCore.expected(EffectResident.native e)
        prestate(Owner.current_epoch()))))|_=>()
  in token end;
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
         (uid,observation)::all))
    in Synchronized.change EffectResident.pending_observations(AList.delete(op =)uid)end;
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

(* Inert projection only. The parent source-open handler must additionally match
   the latest generated model association and bind Owner version/sequence. *)
fun effect_source_projection uid=
  case EffectResident.source_lookup uid of NONE=>NONE|SOME observation=>
    if EffectResident.observation_live observation then
      SOME(EffectResident.source_projection observation,EffectResident.source_incarnation observation)
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
    fun release()=(List.app EffectResident.release entries;
      List.app(fn(uid,(observation,_))=>(EffectResident.release_observation observation;
        Synchronized.change EffectResident.pending_observations(AList.delete(op =)uid)))pending;
      List.app(fn(uid,observation)=>(EffectResident.release_observation observation;
        Synchronized.change EffectResident.source_entries(AList.delete(op =)uid)))sources)
  in if null entries andalso null pending andalso null sources then()else launch_cleanup target release end;
