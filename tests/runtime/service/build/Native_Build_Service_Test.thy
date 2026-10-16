theory Native_Build_Service_Test
  imports Veri7vn_Runtime_Build.Native_Build_Service
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure Inputs=Veri7vn_Native_Package_Inputs;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure Recovery=Veri7vn_Native_Development_Recovery(
    structure Checkpoint=struct fun matches _ _ _ _=false end
    val executable=Veri7vn_Native_Build_Image.executable);
  structure Service=Veri7vn_Native_Build_Service(structure Tickets=T
    structure Recovery=Recovery.Candidate structure Request=Recovery.Request structure Scope=Scope);
  structure B=Service.Builder;
  fun assert true _=()|assert false message=error message;
  fun rejects f=case Exn.capture f()of Exn.Exn _=>()|Exn.Res _=>error "Expected private build refusal";
  val allocator=I.install_host_block{workspace="b123456789abcdef0123456789abcdef",first=1000,past=100000};
  val lower=A.policy @{theory Veri7vn_Admission};
  val locator=Context.theory_name{long=true} @{theory Veri7vn_Admission};
  val root=P.public_image allocator lower;
  val roots=Veri7vn_Native_Installed_Roots.capture_setup[(locator,lower)];
  val operation_root=P.public_image allocator(A.policy @{theory});
  val owner=Service.create{allocator=allocator,template=1,profile=2,setup=3,operation=4,
    code_generation=5,capability=6,step=7,operation_generation=P.generation operation_root,roots=roots,installed_parents=[(locator,root)]};
  val source="theory Service_Built imports \""^locator^"\" begin\n"^
    "definition value :: nat where \"value = 42\"\nend";
  val descriptor="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.service\",\"version\":\"1.0.0\",\"title\":\"Service\",\"description\":\"Original expectation\"},\"files\":[{\"path\":\"Service_Built.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Service_Built\",\"theories\":[\"Service_Built\"]},\"capabilities\":[{\"id\":\"value\",\"title\":\"Value\",\"specification\":{\"theory\":\"Service_Built\",\"name\":\"value\"},\"contracts\":[]}]}";
  fun digest raw=Message_Digest.rep(SHA256.digest raw);
  fun nonce index=let val suffix=Int.fmt StringCvt.HEX index
    in String.implode(replicate(32-size suffix)#"0") ^ String.map Char.toLower suffix end;
  fun upload_named index descriptor source path=
    let val key=nonce index
      val header=YXML.string_of_body[XML.Elem(("build-input",[("version","1"),("upload_nonce",key),
        ("revision",digest source),("manifest",digest descriptor),("descriptor_path","package.json"),
        ("theory_path",path),("descriptor_size",Int.toString(size descriptor)),
        ("theory_size",Int.toString(size source)),("descriptor_sha256",digest descriptor),
        ("theory_sha256",digest source)]),[])]
      val transfer=case Service.transfer_operation owner(Service.Begin header)of
        Service.TransferReady id=>id|_=>error "Native transfer did not begin"
      val _=Service.transfer_operation owner(Service.Write(transfer,Inputs.Descriptor,0,Bytes.string descriptor))
      val _=Service.transfer_operation owner(Service.Write(transfer,Inputs.Theory,0,Bytes.string source))
      val prepared=case Service.transfer_operation owner(Service.Finish transfer)of
        Service.InputPrepared id=>id|_=>error "Native transfer did not finish"
      val _=Service.transfer_operation owner(Service.Accept(key,prepared))
      val _=Service.transfer_operation owner(Service.Settle key)
    in prepared end;
  fun upload index=upload_named index descriptor source "Service_Built.thy";
  (* Actual fixed parser on every finish; repeated producer releases must refund
     the native table's 64-count/16MB capacity, not just hide a client handle. *)
  val _=List.app(fn index=>let val id=upload index
    in ignore(Service.transfer_operation owner(Service.Release id))end)(1 upto 65);
  val input_id=upload 66;
  val binding=Service.input_binding owner input_id;
  val child_source="theory Service_Child imports Service_Built begin\n"^
    "definition child_value :: nat where \"child_value = 7\"\nend";
  val child_descriptor="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.child\",\"version\":\"1.0.0\",\"title\":\"Child\",\"description\":\"Deferred expectation\"},\"files\":[{\"path\":\"Service_Child.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Service_Child\",\"theories\":[\"Service_Child\"]},\"capabilities\":[]}";
  val child_input_id=upload_named 67 child_descriptor child_source "Service_Child.thy";
  val child_binding=Service.input_binding owner child_input_id;
  val parent=Scope.new_parent{allocator=allocator,policy=A.policy @{theory},
    observation=Scope.StateTimeUnused,inputs=[L.owner(#theory_slice binding),L.owner(#theory_slice child_binding)]};
  val child=Scope.new_child parent{source= #theory_slice binding,predecessors=[]};
  val target=Unsynchronized.ref NONE;
  val entry=Service.prepare_into target owner child input_id [];
  val deferred_child=Scope.new_child parent{source= #theory_slice child_binding,predecessors=[child]};
  val deferred_target=Unsynchronized.ref NONE;
  val deferred=Service.defer_into deferred_target owner deferred_child child_input_id
    [Service.ReservedSource("Service_Built",child)]Service.DevelopmentOnly;
  val frozen=Service.deferred_plan deferred;
  val _=case #parents frozen of [Veri7vn_Native_Deferred_Build_Types.ReservedOutput{slot,...}]=>
    assert(slot= #slot(Scope.identity child)) "Deferred plan replaced predecessor slot with guessed candidate"
    |_=>error "Deferred plan did not preserve actual unresolved parent";
  val _=assert(Veri7vn_Native_Deferred_Build_Codec.decode
    (Veri7vn_Native_Deferred_Build_Codec.encode frozen)=frozen) "Deferred source plan wire changed";
  val _=Scope.seal parent[child,deferred_child];
  val _=Scope.release_parent parent;
  val prepared_owner=Service.prepared_lease entry;
  val prepared=Service.prepared entry;
  val names=Service.names entry;
  val plan=B.prepared_plan prepared;
  val projection=B.prepared_projection prepared;
  val issuer=T.new_issuer();
  val tickets=T.begin_scope issuer{owner_version=1,epoch=1};
  val ticket=T.issue_pure tickets{execution= #execution names,slot= #slot names,
    operation={workspace=I.workspace allocator,request= #request names,profile= #profile projection,
      code_generation= #code_generation names,operation= #operation names,step= #step names,cost=1,
      inputs=B.prepared_inputs prepared,owner_version=1,epoch=1,journal_sequence=1,
      semantic_generation= #semantic_generation plan,
      implementation_artifact= #artifact(Veri7vn_Executable_Identity.manifest B.executable)}}prepared;
  val job=Service.start entry ticket;
  (* A worker must not defer ticket consumption past the private issuer scope. *)
  val _=T.close_scope tickets;
  val _=Service.join job;
  val _=case Service.inspect entry of Service.Status{phase=Service.CandidateBuilt,...}=>()
    |_=>error "Private source worker did not produce a nonacknowledged candidate";
  val _=Service.transfer_operation owner(Service.Release input_id);
  val _=assert(Service.live entry) "Input producer release invalidated independent prepared root";
  val _=case Service.inspect entry of Service.Status{prepared_input=0,source_revision,manifest,
      phase=Service.CandidateBuilt,...}=>
      assert(source_revision>0 andalso manifest>0) "Retired producer erased independent source identity"
    |_=>error "Retired upload producer remained a current native handle";
  (* Unit fixture exercises only the named post-durable-ack seam. The real state
     owner must prove/persist/ack ArtifactOutput before invoking this operation. *)
  val output=Service.acknowledge_output entry;
  val candidate=Service.OutputOwner.candidate output;
  val _=assert(null(B.exports candidate) andalso #goal(B.execution_plan candidate)= #goal names)
    "Private output candidate changed native goal/zero-export semantics";
  val resolved_target=Unsynchronized.ref NONE;
  val deferred_intent=Service.deferred_intent deferred;
  val resolved=Service.bind_deferred_into resolved_target deferred[(child,output)];
  val resolved_prepared=Service.prepared resolved;
  val resolved_names=Service.names resolved;
  val resolved_plan=B.prepared_plan resolved_prepared;
  val resolved_projection=B.prepared_projection resolved_prepared;
  val _=assert(#candidate resolved_projection= #candidate frozen andalso
    #parents resolved_projection=[#candidate(B.projection candidate)] andalso
    Veri7vn_Native_Export_Intent.same(deferred_intent,B.prepared_original_intent resolved_prepared))
    "Deferred bind changed frozen identity, parent association or original intent";
  val _=rejects(fn()=>Service.bind_deferred_into resolved_target deferred[(child,output)]);
  val _=Service.release_deferred deferred;
  val _=Service.transfer_operation owner(Service.Release child_input_id);
  val _=assert(Service.live resolved) "Deferred producer release dropped resolved independent source ownership";
  val child_tickets=T.begin_scope issuer{owner_version=2,epoch=1};
  val child_ticket=T.issue_pure child_tickets{execution= #execution resolved_names,slot= #slot resolved_names,
    operation={workspace=I.workspace allocator,request= #request resolved_names,profile= #profile resolved_projection,
      code_generation= #code_generation resolved_names,operation= #operation resolved_names,step= #step resolved_names,cost=1,
      inputs=B.prepared_inputs resolved_prepared,owner_version=2,epoch=1,journal_sequence=2,
      semantic_generation= #semantic_generation resolved_plan,
      implementation_artifact= #artifact(Veri7vn_Executable_Identity.manifest B.executable)}}resolved_prepared;
  val child_job=Service.start resolved child_ticket;
  val _=T.close_scope child_tickets;
  val _=Service.join child_job;
  val _=case Service.inspect resolved of Service.Status{phase=Service.CandidateBuilt,...}=>()
    |_=>error "Resolved deferred source did not build with actual predecessor context";
  val child_output=Service.acknowledge_output resolved;
  val _=Service.release_entry resolved;
  val _=Service.release_entry entry;
  val _=assert(Service.PreparedOwner.is_live prepared_owner andalso Service.OutputOwner.is_live output)
    "Producer release dropped independently retained template/output owners";
  val _=Service.PreparedOwner.release prepared_owner;
  val _=assert(Service.OutputOwner.is_live output andalso
    not(null(B.retention_dependencies candidate)) andalso length(B.parent_bindings candidate)=1)
    "Prepared owner drain invalidated candidate retention/recovery accessors";
  val parent_candidate_id= #candidate(B.projection candidate);
  (* Drop EVERY external parent owner. The child's committed owner must retain
     the actual ancestor lease: P.release(parent) recursively drains children. *)
  val _=Service.OutputOwner.release output;
  val _=assert(not(Service.OutputOwner.is_live output) andalso
    Service.OutputOwner.is_live child_output andalso
    length(B.parent_bindings(Service.OutputOwner.candidate child_output))=1)
    "Draining prepared and parent output owners destroyed retained child provenance";
  val _=Service.invalidate owner[parent_candidate_id];
  val _=assert(not(Service.OutputOwner.is_live child_output)) "Forget parent left deferred child artifact live";
  val _=Service.OutputOwner.release child_output;
  val _=assert(not(Service.OutputOwner.is_live output)) "Released parent output lease became live";
  val _=Service.OutputOwner.release output;
  (* A real failed replay supplies the terminal snapshot; decoding alone does
     not authenticate it or commit a Failed outcome. *)
  val false_source="theory Service_Built imports \""^locator^"\" begin\nlemma impossible: False by simp\nend";
  val false_id=upload_named 68 descriptor false_source "Service_Built.thy";
  val false_binding=Service.input_binding owner false_id;
  val false_parent=Scope.new_parent{allocator=allocator,policy=A.policy @{theory},
    observation=Scope.StateTimeUnused,inputs=[L.owner(#theory_slice false_binding)]};
  val false_child=Scope.new_child false_parent{source= #theory_slice false_binding,predecessors=[]};
  val false_entry=Service.prepare_into(Unsynchronized.ref NONE)owner false_child false_id [];
  val _=Scope.seal false_parent[false_child];
  val false_prepared=Service.prepared false_entry;
  val false_names=Service.names false_entry;
  val false_projection=B.prepared_projection false_prepared;
  val false_tickets=T.begin_scope issuer{owner_version=3,epoch=1};
  val false_ticket=T.issue_pure false_tickets{execution= #execution false_names,slot= #slot false_names,
    operation={workspace=I.workspace allocator,request= #request false_names,profile= #profile false_projection,
      code_generation= #code_generation false_names,operation= #operation false_names,step= #step false_names,cost=1,
      inputs=B.prepared_inputs false_prepared,owner_version=3,epoch=1,journal_sequence=3,
      semantic_generation= #semantic_generation false_names,
      implementation_artifact= #artifact(Veri7vn_Executable_Identity.manifest B.executable)}}false_prepared;
  val false_job=Service.start false_entry false_ticket;
  val _=T.close_scope false_tickets;
  val _=Service.join false_job;
  val reason=I.allocate allocator;
  val terminal=case Service.observed_failure false_entry reason of SOME terminal=>terminal
    |NONE=>error "Actual failed native replay lost terminal diagnostic";
  val packet=Veri7vn_Native_Build_Terminal.encode terminal;
  val decoded=Veri7vn_Native_Build_Terminal.decode packet;
  val _=assert(decoded=terminal andalso #execution decoded= #execution false_names andalso
    #reason decoded=reason) "Build terminal codec lost actual paid-attempt identity";
  val envelope={plan=Service.request_plan false_entry,
    phase=Veri7vn_Native_Build_Request_Envelope.ObservedFailure terminal,body="inert-envelope-roundtrip-only"};
  val _=assert(Veri7vn_Native_Build_Request_Envelope.encode
    (Veri7vn_Native_Build_Request_Envelope.decode(Veri7vn_Native_Build_Request_Envelope.encode envelope))=
    Veri7vn_Native_Build_Request_Envelope.encode envelope) "Build terminal/control envelope changed bytes";
  val _=Service.transfer_operation owner(Service.Release false_id);
  val _=case Service.inspect false_entry of Service.Status{prepared_input=0,phase=Service.BuildFailed,
      failure=SOME _,...}=>()|_=>error "Upload release erased actual failed build status";
  val _=Service.release_entry false_entry;
  val _=Scope.release_child false_child;
  val _=Scope.release_parent false_parent;
  val _=Service.close owner;
  val _=Scope.release_child child;
  val _=Scope.release_child deferred_child;
  val _=P.release root;
  val _=P.release operation_root;
  val _=writeln "native_build_service_transfer_worker_leases_ok";
in end;
\<close>
end
