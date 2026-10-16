theory Conversation_Source_Recovery_Tests
  imports Veri7vn_Conversation_Metadata.Conversation_Metadata
    Veri7vn_Session_Source.Session_Source
begin

definition source_recovery_test_context where
  "source_recovery_test_context sid version reads =
    \<lparr>observed_session=sid,observed_version=version,evaluation_time=None,observed_reads=reads\<rparr>"

ML \<open>
local
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  structure Pin=Veri7vn_Native_Observation_Pin;
  structure A=Veri7vn_Native_Admission;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Roots=Veri7vn_Native_Installed_Roots;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure Manifest=Veri7vn_Recovery_Manifest;
  structure Executable=Veri7vn_Executable_Identity;
  structure ExecutablePin=Veri7vn_Native_Recovery_Pin;
  structure Codec=Veri7vn_Session_Input_Codec;
  structure Wire=Veri7vn_Native_Authority_Wire;
  structure SourceContext=Veri7vn_Private_Session_Context();
  fun ensure true _=()|ensure false message=error message;
  fun rejects action=ensure(Exn.is_exn(Exn.capture action())) "Expected fixed source recovery rejection";
  fun nat value=Veri7vn_Numerals.nat_of_integer value;
  fun integer value=Veri7vn_Numerals.integer_of_nat value;
  fun write value=Wire.write_with
    (fn @{code WireNat} n=>Wire.Natural(integer n)
      | @{code WireNode}(tag,children)=>Wire.Branch(integer tag,children))value;
  fun read bytes=
    let fun convert(Wire.Atom n)= @{code WireNat}(nat n)
          | convert(Wire.Node(tag,children))= @{code WireNode}(nat(IntInf.fromInt tag),map convert children)
    in convert(Wire.read bytes)end;
  fun encode_state state=write(@{code encode_checkpoint} state);
  fun decode_state bytes=case @{code decode_checkpoint}(read bytes)of SOME state=>state
    |NONE=>error "Actual source checkpoint did not decode";
  fun context(snapshot:Pin.snapshot)=
    (ensure(is_none(#evaluation_time snapshot)) "Fixture supports original unused clock only";
     @{code source_recovery_test_context}(nat(#session snapshot))(nat(#version snapshot))
       (map(fn(id,version)=>(nat id,nat version))(#reads snapshot)));
  structure Checkpoint=
  struct
    fun matches committed(m:Codec.metadata)=
      let val material=C.materials committed;
        val recovered=decode_state(#checkpoint material)
      in if #association material= #utterance m andalso #workspace material= #workspace m then
        Option.map(fn recorded=>{recorded=recorded})
          (@{code conversation_source_phase} recovered(nat(#utterance m))
            (context(#observation m))(map nat(#source_dependencies m)))
        else NONE end;
  end;
  (* Mechanism fixture: this is a real opaque pin, not a deployed image claim. *)
  val executable=Executable.pin @{theory}
    {artifact="session-source-recovery-fixture",compiler="Isabelle/ML",target="native",
      serializers=["native-session-input/1"],foreign_primitives=[],settings=[]};
  structure Recovery=Veri7vn_Native_Session_Input_Recovery(
    structure Checkpoint=Checkpoint val executable=executable);
  structure Entry=Veri7vn_Private_Session_Entry(
    structure Restored=Recovery.View structure Context=SourceContext);
  structure Export=Veri7vn_Native_Session_Input_Export(structure Entry=Entry val executable=executable);
  val allocator=I.install_host_block{workspace="c0de0000000000000000000000000066",first=9100000,past=9165536};
  val workspace=I.workspace allocator;
  val lower_policy=A.policy @{theory Veri7vn_Admission};
  val roots=Roots.capture_setup[(Context.theory_name{long=true} @{theory Veri7vn_Admission},lower_policy)];
  val image=V.install_host_image_with_roots roots(A.policy @{theory})"session-source-recovery-unit-image";
  val installation=Recovery.install image roots;
  val native_context=SourceContext.create allocator lower_policy;
  val development=SourceContext.development native_context;
  val head=the(I.lookup_generation_id allocator(P.generation development));
  val sid=I.allocate allocator;
  val read_id=I.allocate allocator;
  val observation={workspace=workspace,session=sid,version=0,evaluation_time=NONE,reads=[(read_id,3)]}:Pin.snapshot;
  val issuer=Pin.new_issuer();
  val pin=Pin.mint issuer observation;
  val physical=L.input{bytes="the sum of 2 and 3",encoding="UTF-8"};
  val source_owner=P.install_host_source allocator physical;
  val uid=P.source_identity source_owner;
  val entry=Entry.capture allocator{input=physical,pin=pin,context=native_context,source=source_owner};
  val artifacts=Export.qualify allocator image roots entry;
  val metadata=Codec.decode_projection(#projection artifacts);
  val original_context=context observation;
  fun transition state event=
    let val(next,commands)= @{code step} state event;
      val _=ensure(not(exists(fn @{code Rejected} _=>true|_=>false)commands)) "Generated source transition rejected"
    in next end;
  val created=transition @{code initial_state}(@{code UpdateObservation} original_context);
  val pending=transition created(@{code conversation_input} original_context(nat uid)
    (map nat(#source_dependencies metadata)));
  val _=ensure(@{code conversation_source_phase} pending(nat uid)original_context
      (map nat(#source_dependencies metadata))=SOME false andalso null(@{code requests} pending))
    "Registered source was not pending independently of child requests";
  val recorded=transition pending(@{code RecordUtterance}(nat sid,nat uid));
  val _=ensure(@{code conversation_source_phase} recorded(nat uid)original_context
      (map nat(#source_dependencies metadata))=SOME true andalso
      @{code conversation_input_visible} recorded(nat sid)(nat uid)) "Recorded source phase/access mismatch";
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun protect state=
    let val manifest=Manifest.encode{profile=Manifest.SessionInput,workspace=workspace,association=uid,
      semantic_generation=head,projection=digest(#projection artifacts),sequent=digest(#sequent artifacts),
      context_closure=digest(#context_closure artifacts),payload=digest(#reconstruction artifacts),
      reconstruction=Manifest.Controlled_Recipe,executable=SOME(ExecutablePin.digest executable)}
    in C.install_committed_host{workspace=workspace,journal_sequence=1,association=uid,semantic_generation=head,
      checkpoint=encode_state state,manifest=manifest,projection= #projection artifacts,sequent= #sequent artifacts,
      context_closure= #context_closure artifacts,reconstruction= #reconstruction artifacts}end;
  val pending_material=protect pending;
  val recorded_material=protect recorded;
  val _=ignore(L.drop_base physical);
  val _=Pin.release pin;
  val _=SourceContext.release native_context;
  val _=Entry.release entry;
  val _=ensure(L.disposed physical andalso not(P.development_live development))
    "Original source/context unexpectedly survived fixture crash";
  fun restored material phase= 
    let val pool=Pool.create allocator;
      val graph=G.create_with_roots pool roots;
      val batch=Recovery.batch installation allocator graph pool;
      val witness=Recovery.check batch material;
      val _=ensure(not(Recovery.View.live witness)) "Staged source witness was already registered";
      val _=rejects(fn()=>Entry.restore witness);
      val _=I.install_fragments allocator[Recovery.fragment witness,V.fragment(V.seal_batch graph)];
      val owner=Entry.restore witness;
      val _=ensure(Recovery.View.recorded witness=phase andalso Recovery.View.live witness andalso
        #bytes(Entry.snapshot owner)="the sum of 2 and 3" andalso
        #observation(Entry.snapshot owner)=observation andalso
        #utterance(Entry.identity owner)=uid) "Restored source lost exact original phase/bytes/context/identity";
      val _=Recovery.close batch;
      val _=Pool.close pool;
      val _=ensure(Entry.retained owner) "Closing temporary recovery roots destroyed actual session source";
      val _=Entry.release owner;
      val _=G.abort graph
    in()end;
  val _=restored pending_material false;
  val _=restored recorded_material true;
  val stale_observation= @{code source_recovery_test_context}(nat sid)(nat 0)[(nat read_id,nat 4)];
  val stale=transition recorded(@{code UpdateObservation} stale_observation);
  val _=ensure(not(@{code conversation_input_visible} stale(nat sid)(nat uid)) andalso
    @{code conversation_source_phase} stale(nat uid)original_context(map nat(#source_dependencies metadata))=SOME true)
    "Stale access was confused with inert source reconstruction";
  val stale_material=protect stale;
  val _=restored stale_material true;
  fun forgotten object=
    let val state=transition recorded(@{code Forget}(nat object));
      val material=protect state;
      val pool=Pool.create allocator;
      val graph=G.create_with_roots pool roots;
      val batch=Recovery.batch installation allocator graph pool;
      val _=ensure(@{code conversation_source_phase} state(nat uid)original_context
        (map nat(#source_dependencies metadata))=NONE) "Forget retained a source requirement";
      val _=rejects(fn()=>Recovery.check batch material);
      val _=Recovery.close batch;val _=G.abort graph;val _=Pool.abort pool;val _=C.release material
    in()end;
  val _=List.app forgotten[sid,uid,head];
  val _=List.app C.release[pending_material,recorded_material,stale_material];
in val _=writeln "CONVERSATION_SOURCE_RECOVERY_PASS actual_export generated_exact_checkpoint pending_no_child recorded_no_child atomic_registration retained_pool_graph stale_inert_access_denied forget_session_input_context" end
\<close>
end
