theory Native_Build_Restart_Test
  imports "Veri7vn_Native_Build_Candidate.Native_Build_Candidate"
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure V=Veri7vn_Native_Recovery_Check;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure Wire=Veri7vn_Native_Development_Codec;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  structure T=Veri7vn_Private_Operation_Tickets();
  fun assert true _=()|assert false message=error message;
  val workspace="a123456789abcdef0123456789abcdef";
  val allocator=I.install_host_block{workspace=workspace,first=100,past=60000};
  val lower_policy=A.policy @{theory Veri7vn_Admission};
  val policy=A.policy @{theory};
  val locator=Context.theory_name{long=true} @{theory Veri7vn_Admission};
  val roots=Veri7vn_Native_Installed_Roots.capture_setup[(locator,lower_policy)];
  (* Mechanism fixture only: this label is not a deployed heap/build manifest. *)
  val image=V.install_host_image_with_roots roots policy "native-build-restart-unit-image";
  val pin=Veri7vn_Native_Build_Image.executable;
  val protected=Unsynchronized.ref([]:(IntInf.int*string*string)list);
  structure Checkpoint =
  struct
    fun matches committed metadata payload outer=
      let val material=C.materials committed
      in #checkpoint material="native-build-restart-unit-checkpoint" andalso
        member(op =)(!protected)(#association material,Wire.encode_projection metadata,
          case outer of NONE=>Wire.encode_payload payload|
            SOME packet=>Veri7vn_Native_Build_Request_Envelope.encode packet)end;
  end;
  structure Recovery=Veri7vn_Native_Development_Recovery(
    structure Checkpoint=Checkpoint val executable=pin);
  val recovery_configuration=Recovery.install{image=image,roots=roots};
  structure B=Veri7vn_Native_Build_Candidate(
    structure Tickets=T structure Intent=Intent structure Recovery=Recovery.Candidate
    structure Request=Recovery.Request val executable=pin val cost=1 val max_source_bytes=1000000);
  structure Durable=Veri7vn_Native_Build_Recovery(structure Builder=B structure Recovery=Recovery);
  structure Requests=Veri7vn_Native_Build_Request_Restore(structure Builder=B structure Request=Recovery.Request);
  val parent=P.public_image allocator lower_policy;
  (* The installed source import and charged fixed operation context are
     distinct native owners. Recovery must not relabel the lower import as Boot. *)
  val operation_root=P.public_image allocator policy;
  val charged_generation=I.generation_id allocator(P.generation operation_root);
  val installation=B.install{template=1,profile=2,setup=3,operation=24,step=25,code_generation=23,
    installed_parents=[(locator,parent)]};
  val source="theory Build_Restart imports \""^locator^"\" begin\n"^
    "definition value :: nat where \"value = 42\"\nend";
  val descriptor="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.restart\",\"version\":\"1.0.0\",\"title\":\"Restart\",\"description\":\"Original expectation\"},\"files\":[{\"path\":\"Build_Restart.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Build_Restart\",\"theories\":[\"Build_Restart\"]},\"capabilities\":[{\"id\":\"value\",\"title\":\"Value\",\"specification\":{\"theory\":\"Build_Restart\",\"name\":\"value\"},\"contracts\":[]}]}";
  val input=L.input{bytes=source,encoding="UTF-8"};
  val owner=P.install_host_source allocator input;
  val slice=L.slice input{start=0,stop=size source,expected=source};
  val descriptor_input=L.input{bytes=descriptor,encoding="UTF-8"};
  val descriptor_owner=P.install_host_source allocator descriptor_input;
  val descriptor_slice=L.slice descriptor_input{start=0,stop=size descriptor,expected=descriptor};
  val initial_scope=P.construction_scope();
  (* This is the actual fixed Scala PackageModel bridge, not a parsed-name stub. *)
  val expectation=Veri7vn_Native_Package_Inputs.interpret_descriptor descriptor_owner descriptor_slice;
  val intent=Intent.capture_owned initial_scope{source=descriptor_owner,slice=descriptor_slice,
    source_revision=10,manifest=11,export_intent=13,capabilities= #capabilities expectation};
  val _=P.commit_scope initial_scope;
  val prepared=B.prepare installation{source=owner,slice=slice,original_intent=intent,
    source_revision=10,manifest=11,parents=[B.Installed locator],exports=[],export_intent=13,
    candidate=14,request=22,goal=28,execution=20,slot=21,semantic_generation=charged_generation,input_bindings=[40]};
  (* A false target cannot successfully replay: its pending restoration must
     reconstruct only source/parents, and leave charging/execution to the owner. *)
  val pending_source="theory Build_Restart imports \""^locator^"\" begin\nlemma impossible: False by simp\nend";
  val pending_input=L.input{bytes=pending_source,encoding="UTF-8"};
  val pending_owner=P.install_host_source allocator pending_input;
  val pending_slice=L.slice pending_input{start=0,stop=size pending_source,expected=pending_source};
  val pending_scope=P.construction_scope();
  val pending_intent=Intent.capture_owned pending_scope{source=descriptor_owner,slice=descriptor_slice,
    source_revision=30,manifest=31,export_intent=33,capabilities= #capabilities expectation};
  val _=P.commit_scope pending_scope;
  val pending=B.prepare installation{source=pending_owner,slice=pending_slice,original_intent=pending_intent,
    source_revision=30,manifest=31,parents=[B.Installed locator],exports=[],export_intent=33,
    candidate=34,request=42,goal=48,execution=44,slot=45,semantic_generation=charged_generation,input_bindings=[49]};
  val issuer=T.new_issuer();
  val tickets=T.begin_scope issuer{owner_version=1,epoch=1};
  val ticket=T.issue_pure tickets{execution=20,slot=21,operation={workspace=workspace,
    request=22,profile=2,code_generation=23,operation=24,step=25,cost=1,inputs=[40],
    owner_version=1,epoch=1,journal_sequence=26,semantic_generation=charged_generation,
    implementation_artifact= #artifact(Veri7vn_Executable_Identity.manifest pin)}}prepared;
  val scope=P.construction_scope();
  val candidate=B.execute_owned scope ticket;
  val _=P.commit_scope scope;
  val candidate_art=Durable.candidate recovery_configuration allocator candidate;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  val pending_control={original_input={upload_nonce=String.implode(replicate 32 #"a"),
      revision=digest pending_source,manifest=digest descriptor,descriptor_path="package.json",
      theory_path="Build_Restart.thy",descriptor_size=size descriptor,theory_size=size pending_source,
      descriptor_sha256=digest descriptor,theory_sha256=digest pending_source,parents=[]},
    prepared_input=53,workspace=workspace,request=42,goal=48,slot=45,interpretation=50,decision=51,
    parameter=49,candidate=34,execution=44,template=1,profile=2,setup=3,capability=52,
    operation=24,code_generation=23,operation_generation=charged_generation,step=25,
    source={source_owner=P.source_identity pending_owner,start=0,stop=size pending_source,
      source_revision=30,manifest=31,export_intent=33,descriptor_source=P.source_identity descriptor_owner,
      descriptor_start=0,descriptor_stop=size descriptor},parents=[Veri7vn_Native_Deferred_Build_Types.Installed
        {locator=locator,root=locator}],exports=[],dependencies=B.prepared_parent_dependencies pending}:
    Veri7vn_Native_Deferred_Build_Types.plan;
  val request_art=Durable.request recovery_configuration allocator
    {control=pending_control,phase=Veri7vn_Native_Build_Request_Envelope.Prepared}pending;
  fun protect profile (art:Recovery.artifacts)=
    let val metadata=Wire.decode_projection(#projection art)
      val association=if profile=M.BuildCandidate then #candidate metadata else #slot metadata
      val generation= #semantic_generation metadata
      val manifest=M.encode{profile=profile,workspace=workspace,association=association,
        semantic_generation=generation,projection=digest(#projection art),sequent=digest(#sequent art),
        context_closure=digest(#context_closure art),payload=digest(#reconstruction art),
        reconstruction=M.Controlled_Recipe,executable=SOME(Pin.digest pin)}
      val committed=C.install_committed_host{workspace=workspace,journal_sequence=1,
        association=association,semantic_generation=generation,
        checkpoint="native-build-restart-unit-checkpoint",manifest=manifest,
        projection= #projection art,sequent= #sequent art,context_closure= #context_closure art,
        reconstruction= #reconstruction art}
      val _=protected:=(association,#projection art,#reconstruction art):: !protected
    in committed end;
  val committed_candidate=protect M.BuildCandidate candidate_art;
  val committed_request=protect M.BuildRequest request_art;
  val saved_generation= #semantic_generation(Wire.decode_projection(#projection candidate_art));
  val saved_dependencies= #dependencies(B.projection candidate);
  val _=B.release candidate;
  val _=Intent.release intent;
  val _=Intent.release pending_intent;
  val _=P.release parent;
  val _=P.release operation_root;
  val _=L.forget_input input;
  val _=if L.disposed input then I.release_disposed_input input else();
  val _=L.forget_input pending_input;
  val _=if L.disposed pending_input then I.release_disposed_input pending_input else();
  val _=L.forget_input descriptor_input;
  val _=if L.disposed descriptor_input then I.release_disposed_input descriptor_input else();
  val restored_parent=P.public_image allocator lower_policy;
  val restored_installation=B.install{template=1,profile=2,setup=3,operation=24,step=25,code_generation=23,
    installed_parents=[(locator,restored_parent)]};
  val pool=Pool.create allocator;
  val graph=G.create_with_roots pool roots;
  val batch=Recovery.batch recovery_configuration graph pool;
  val request_witness=Recovery.recheck_request_in batch allocator committed_request;
  val request_source_fragment=Recovery.request_fragment request_witness;
  val candidate_witness=Recovery.recheck_candidate_in batch allocator committed_candidate;
  val candidate_source_fragment=Recovery.candidate_fragment candidate_witness;
  val _=I.install_fragments allocator[request_source_fragment,candidate_source_fragment,V.fragment(V.seal_batch graph)];
  val restored_request=Requests.restore restored_installation request_witness;
  val restored=B.restore restored_installation candidate_witness;
  val held_candidate=Recovery.Candidate.retain candidate_witness;
  val concurrent_candidate=Recovery.Candidate.retain candidate_witness;
  val held_request=Recovery.Request.retain request_witness;
  val _=Recovery.close_batch batch;
  val _=assert(B.is_live restored andalso null(B.exports restored) andalso
    null(B.declared_exports restored) andalso not(null(Intent.theorem_names(B.original_intent restored))))
    "Zero-export restart lost independent original full intent";
  val _=assert(#goal(B.execution_plan restored)=28 andalso
    #dependencies(B.projection restored)=saved_dependencies andalso
    I.lookup_generation_id allocator(B.native_generation restored)=SOME saved_generation)
    "Restart changed protected plan, closure or native generation IDs";
  val _=assert(B.prepared_live(Requests.prepared restored_request) andalso
    #goal(B.prepared_plan(Requests.prepared restored_request))=48 andalso
    L.original(#slice(B.prepared_recipe(Requests.prepared restored_request)))=pending_source)
    "Pending request restore lost original plan";
  (* Hold the opaque released handles themselves across final cleanup. Use
     explicit independent owners to distinguish payload disposal from use denial. *)
  val candidate_input=P.source_input(#source(Recovery.Candidate.binding held_candidate));
  val request_input=P.source_input(#source(Recovery.Request.binding held_request));
  val descriptor_input=P.source_input(#source(Intent.binding(Recovery.Candidate.original_intent held_candidate)));
  val _=B.release restored;
  val _=Requests.release restored_request;
  val release_start=Synchronized.var "same_handle_release_start" false;
  fun release_concurrently()=
    (Synchronized.guarded_access release_start(fn false=>NONE|true=>SOME((),true));
     Recovery.Candidate.release concurrent_candidate);
  val first_release=Future.fork release_concurrently;
  val second_release=Future.fork release_concurrently;
  val _=Synchronized.change release_start(K true);
  val _=Future.join first_release;
  val _=Future.join second_release;
  val _=assert(Recovery.Candidate.is_live held_candidate andalso
    Recovery.retains_candidate_payload held_candidate)
    "Concurrent same-handle release disposed a separately retained sibling";
  val _=List.app L.forget_input[candidate_input,request_input,descriptor_input];
  val _=assert(Recovery.retains_candidate_payload held_candidate andalso
    Recovery.retains_request_payload held_request andalso
    not(L.disposed candidate_input) andalso not(L.disposed request_input))
    "A surviving checked owner lost its cached recipe or source lease";
  val _=Recovery.Candidate.release held_candidate;
  val _=assert(not(Recovery.retains_candidate_payload held_candidate) andalso
    not(Recovery.retains_candidate_payload candidate_witness) andalso
    Recovery.retains_request_payload held_request)
    "Final candidate cleanup retained cached payload or erased a sibling request";
  val _=assert(not(can Recovery.Candidate.retain held_candidate))
    "Released candidate accepted a new owner";
  val _=Recovery.Request.release held_request;
  val _=assert(not(Recovery.retains_request_payload held_request) andalso
    not(Recovery.retains_request_payload request_witness) andalso
    not(can Recovery.Request.retain held_request))
    "Final request cleanup retained original control bytes or accepted a new owner";
  val _=P.release restored_parent;
  val _=G.abort graph;
  val _=Pool.close pool;
  val _=assert(forall L.disposed[candidate_input,request_input,descriptor_input])
    "Forgotten recovery originals survived final graph/source owner disposal";
  val _=writeln "native_build_recovery_held_handle_payload_disposal_ok";
  val _=C.release committed_candidate;
  val _=C.release committed_request;
  val _=writeln "native_build_restart_zero_export_request_ok";
in end;
\<close>
end
