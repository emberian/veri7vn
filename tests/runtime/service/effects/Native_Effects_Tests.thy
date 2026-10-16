theory Native_Effects_Tests
  imports Veri7vn_Runtime_Effects.Native_Effects_Service
begin
ML \<open>
local
  structure Responses=Veri7vn_Native_Effect_Responses;
  structure Inputs=Veri7vn_Native_Effect_Inputs;
  structure Effects=Veri7vn_Native_Effect_Service(structure Scope=Veri7vn_Native_Request_Scope);
  val ids=Veri7vn_Native_Identity_Allocator.install_host_block
    {workspace="edfec700000000000000000000000001",first=1,past=4097};
  val pool=Inputs.create ids;
  val responses=Responses.create ids;
  val owner=Effects.create ids (Veri7vn_Native_Admission.policy @{theory});
  fun hash raw=Message_Digest.rep(SHA256.digest raw);
  fun source draft raw:Inputs.source_data={draft=draft,head=hash draft,
    member=hash raw,sha256=hash raw,size=size raw};
  fun denied action=(case Exn.capture action()of Exn.Exn _=>true|_=>false);
  fun check true _=()|check false text=error text;
  val config="fixed local configuration";
  val packet="fixed discovery request";
  val config_nonce="effectFixture0001";
  val config_transfer=Inputs.begin_configuration pool config_nonce(source "config" config)7;
  val _=Inputs.write config_transfer 0(Bytes.string config);
  val _=Inputs.finish config_transfer;
  val configuration=case Inputs.accept_nonce pool config_nonce of
    Inputs.InstalledConfiguration value=>value|_=>error "Configuration installation shape";
  val _=check(Inputs.configuration_epoch configuration=7) "Native configuration epoch changed";
  val _=Inputs.settle_nonce pool config_nonce;
  val packet_nonce="effectFixture0002";
  val transfer=Inputs.begin_packet pool configuration packet_nonce(source "packet" packet);
  val _=check(Inputs.transfer_key(Inputs.begin_packet pool configuration packet_nonce(source "packet" packet))=Inputs.transfer_key transfer)
    "Lost begin reply created duplicate transfer";
  val _=Inputs.write transfer 0 (Bytes.string packet);
  val _=check(denied(fn()=>Inputs.write transfer 0 (Bytes.string packet)))
    "Repeated chunk overwrote source";
  val input=Inputs.finish transfer;
  val _=case Inputs.finish transfer of Inputs.PreparedPacket value=>
    check(Inputs.live value) "Lost finish reply failed reconciliation"|_=>error "Packet installation shape";
  val accepted=case Inputs.accept_nonce pool packet_nonce of Inputs.PreparedPacket value=>value
    |_=>error "Packet acceptance shape";
  val entry=Effects.prepare owner Effects.Discover accepted;
  val natural=Veri7vn_Numerals.nat_of_integer;
  val integer=Veri7vn_Numerals.integer_of_nat;
  val n=Effects.names entry;
  val generated_names= @{code service_effect_names}
    (natural(#request n))(natural(#goal n))(natural(#interpretation n))
    (natural(#target n))(natural(#capability n))(natural(#profile n))
    (natural(#operation n))(natural(#step n))(natural(#generation n))
    (natural(#attempt n))(natural(#batch n));
  val deps=Effects.dependencies entry;
  val sources=Effects.sources entry;
  val step= @{code step};
  val (reserved,reserve_commands)=step @{code initial_state}
    (@{code service_effect_reserve} generated_names(natural 0)(map natural deps));
  val _=check(null reserve_commands) "Generated effect reservation rejected";
  val registered=fold(fn event=>fn state=>
    let val (next,commands)=step state event
    in check(null commands) "Generated source registration rejected";next end)
    (@{code service_effect_registration} generated_names(map natural deps)) reserved;
  val (staged,persist)=step registered
    (@{code service_effect_stage} generated_names(natural 0)(map natural sources)(map natural deps));
  val batch=case persist of [@{code Persist} batch]=>batch|_=>error "Generated intent not persisted";
  val (prepared,visible)=step staged(@{code DurableAck}(@{code batch_id} batch,
    @{code Suc}(@{code expected_revision} batch),@{code batch_epoch} batch));
  val _=case visible of [@{code Visible} _]=>()|_=>error "Generated intent acknowledgement rejected";
  val (_,start)=step prepared(@{code service_effect_start} generated_names);
  val command=case start of [@{code ClaimStart}(intent,epoch)]=>
    {attempt=integer(@{code attempt_id} intent),request=integer(@{code attempt_request} intent),
      target=integer(@{code attempt_target} intent),capability=integer(@{code attempt_capability} intent),
      sources=map integer(@{code attempt_sources} intent),
      dependencies=map integer(@{code attempt_dependencies} intent),
      prestate=integer(@{code attempt_prestate} intent),epoch=integer epoch,
      cost={profile=integer(@{code cost_profile}(@{code attempt_cost} intent)),
        code_generation=integer(@{code cost_code_generation}(@{code attempt_cost} intent)),
        operation=integer(@{code cost_operation}(@{code attempt_cost} intent)),
        step=integer(@{code cost_step}(@{code attempt_cost} intent)),
        units=integer(@{code cost_units}(@{code attempt_cost} intent))}}:Effects.command
    |_=>error "Generated authority did not emit actual ClaimStart";
  fun swapped_cost({attempt,request,target,capability,sources,dependencies,prestate,epoch,cost}:Effects.command)=
    {attempt=attempt,request=request,target=target,capability=capability,sources=sources,
      dependencies=dependencies,prestate=prestate,epoch=epoch,
      cost={profile= #profile cost,code_generation= #code_generation cost,
        operation= #step cost,step= #operation cost,units= #units cost}}:Effects.command;
  val _=check(denied(fn()=>Effects.acknowledged_start entry "swapped-cost-gate" (swapped_cost command)))
    "Native gate armed from swapped actual operation/step";
  val _=Effects.acknowledged_start entry "actual-acknowledged-gate" command;
  val _=check(denied(fn()=>ignore(Effects.consume_start entry "wrong-gate" (Effects.incarnation entry))))
    "Native permit accepted a different gate";
  val receipt=Effects.consume_start entry "actual-acknowledged-gate" (Effects.incarnation entry);
  val _=check(#command receipt=command andalso #permit receipt>0) "Native receipt association differs";
  val _=check(denied(fn()=>ignore(Effects.consume_start entry "actual-acknowledged-gate" (Effects.incarnation entry))))
    "Native permit repeated a handoff";
  val response_raw="bounded observed decoded JSON fixture";
  val response_nonce="effectResponse0001";
  val response_data={sha256=hash response_raw,size=size response_raw};
  val _=check(denied(fn()=>ignore(Effects.begin_response entry responses (#gate receipt)
      (#incarnation receipt)(#permit receipt+1)response_nonce response_data)))
    "Response upload accepted another consumed permit";
  val response_transfer=Effects.begin_response entry responses (#gate receipt)
    (#incarnation receipt)(#permit receipt)response_nonce response_data;
  val _=Responses.write response_transfer 0(Bytes.string response_raw);
  val finished_response=Responses.finish response_transfer;
  val response=Responses.accept_nonce responses response_nonce;
  val _=check(Responses.key response=Responses.key finished_response)
    "Lost response finish/accept reply replaced original source";
  val _=Responses.settle_nonce responses response_nonce;
  val retained_response=Responses.retain response;
  val observed_binding=Effects.observation_binding entry response;
  val _=check(#command observed_binding=command andalso
      Veri7vn_Managed_Provenance.source_identity(#source observed_binding)=
        Veri7vn_Managed_Provenance.source_identity(Responses.source response))
    "Observation binding failed to derive actual consumed command/source";
  val _=Inputs.discard_nonce pool packet_nonce;
  val _=check(Effects.live entry) "Input producer release destroyed retained effect originals";
  val _=Inputs.settle_nonce pool packet_nonce;
  val _=Effects.cancel entry;
  val _=check(not(Effects.live entry)) "Cancelled native effect remained live";
  val _=Effects.release entry;
  fun fresh operation correlation raw=
    let val transfer=Inputs.begin_packet pool configuration correlation(source correlation raw)
      val _=Inputs.write transfer 0(Bytes.string raw)
      val _=Inputs.finish transfer
      val input=case Inputs.accept_nonce pool correlation of Inputs.PreparedPacket input=>input
        |_=>error "Fresh packet installation shape"
      val _=Inputs.settle_nonce pool correlation
    in(input,Effects.prepare owner operation input)end;
  val workflow=[fresh Effects.Discover "effectWorkflow0001" "discovery packet",
    fresh Effects.QualifyCounter "effectWorkflow0002" "qualification packet",
    fresh Effects.InvokeCounter "effectWorkflow0003" "invocation packet"];
  val config_id=Veri7vn_Managed_Provenance.source_identity(Inputs.configuration_source configuration);
  val packet_ids=map(fn(input,entry)=>
    let val binding=Inputs.binding input
      val _=check(Inputs.configuration_key(#configuration_owner binding)=Inputs.configuration_key configuration
        andalso Veri7vn_Managed_Provenance.source_identity(#configuration binding)=config_id)
        "Fresh request packet rebound installed configuration"
      val _=check(Effects.live entry) "Fresh native workflow entry denied"
    in Veri7vn_Managed_Provenance.source_identity(#packet binding)end)workflow;
  val _=check(length(distinct(op =)packet_ids)=3) "Fresh workflow packets reused source identity";
  val _=Inputs.release_configuration configuration;
  val _=check(forall(fn(input,entry)=>not(Inputs.live input) andalso not(Effects.live entry))workflow)
    "Retired configuration left workflow entries live";
  val _=List.app(fn(input,entry)=>(Effects.release entry;Inputs.release input))workflow;
  val _=Responses.release response;
  val _=check(not(Responses.live response) andalso Responses.live retained_response andalso
      Veri7vn_Native_Literals.bytes(Veri7vn_Managed_Provenance.source_input(Responses.source retained_response))=response_raw)
    "Response owner lost retained bytes when original live configuration retired";
  val original_binding=Responses.originals retained_response;
  val _=check(Veri7vn_Native_Literals.bytes(Veri7vn_Managed_Provenance.source_input(#packet original_binding))=packet)
    "Response owner lost exact original packet after entry release";
  val _=Responses.release retained_response;
  val _=check(not(Responses.live retained_response)) "Released response remained readable";
  val _=Responses.close responses;
  val _=Effects.close owner;
  val _=Inputs.close pool;
in val _=writeln "NATIVE_EFFECTS retained_sources_and_single_use PASS" end;
\<close>
end
