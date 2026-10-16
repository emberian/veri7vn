theory Native_Deferred_Build_Restart_Test
  imports Native_Deferred_Build_Checkpoint
begin

definition deferred_build_material_matches ::
  "authority_wire \<Rightarrow> build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow>
    nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "deferred_build_material_matches wire_arg plan_arg required_arg shared_arg predecessors_arg =
    (case decode_checkpoint wire_arg of None \<Rightarrow> False | Some s \<Rightarrow>
      (\<exists>r\<in>set (requests s). request_id r=bsc_request (bsp_control plan_arg) \<and>
        request_dependencies r=shared_arg \<and>
        build_service_child plan_arg required_arg (map ArtifactDependency predecessors_arg)\<in>set (request_goals r) \<and>
        build_service_slot plan_arg required_arg shared_arg\<in>set (output_slots s)) \<and>
      pure_executions s=[])"

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
  val allocator=I.install_host_block{workspace="e123456789abcdef0123456789abcdef",first=1000,past=100000};
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
  structure Types=Veri7vn_Native_Deferred_Build_Types;
  structure Codec=Veri7vn_Native_Deferred_Build_Codec;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure V=Veri7vn_Native_Recovery_Check;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure W=Veri7vn_Native_Authority_Wire;
  structure N=Veri7vn_Numerals;
  val nat=N.nat_of_integer;
  val input_id=upload 1;
  val binding=Service.input_binding owner input_id;
  val false_source="theory Service_Child imports Service_Built begin\nlemma impossible: False by simp\nend";
  val false_descriptor="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.pending\",\"version\":\"1.0.0\",\"title\":\"Pending\",\"description\":\"Never replay during restoration\"},\"files\":[{\"path\":\"Service_Child.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Service_Child\",\"theories\":[\"Service_Child\"]},\"capabilities\":[]}";
  val second_input_id=upload_named 2 false_descriptor false_source "Service_Child.thy";
  val second_binding=Service.input_binding owner second_input_id;
  val old_inputs=map P.source_input [#theory_source binding,#descriptor_source binding,
    #theory_source second_binding,#descriptor_source second_binding];
  val parent=Scope.new_parent{allocator=allocator,policy=A.policy @{theory},
    observation=Scope.StateTimeUnused,inputs=map(L.owner o #theory_slice)[binding,second_binding]};
  val first_child=Scope.new_child parent{source= #theory_slice binding,predecessors=[]};
  val first_target=Unsynchronized.ref NONE;
  val first=Service.defer_into first_target owner first_child input_id
    [Service.InstalledSource locator]Service.DevelopmentOnly;
  val second_child=Scope.new_child parent{source= #theory_slice second_binding,predecessors=[first_child]};
  val second_target=Unsynchronized.ref NONE;
  val second=Service.defer_into second_target owner second_child second_input_id
    [Service.ReservedSource("Service_Built",first_child)]Service.DevelopmentOnly;
  val first_plan=Service.deferred_plan first;
  val second_plan=Service.deferred_plan second;
  val _=Scope.seal parent[first_child,second_child];
  fun control(p:Types.plan)= @{code build_service_control}(nat(#request p))(nat(#goal p))
    (nat(#slot p))(nat(#parameter p))(nat(#operation_generation p))(nat(#code_generation p))
    (nat(#candidate p))(nat(#execution p));
  fun model_plan(p:Types.plan)= @{code build_service_plan}(control p)(nat(#interpretation p))
    (nat(#capability p))(nat(#operation p))(nat(#step p));
  fun requirement(p:Types.plan)=
    let val source= #source p
      fun parent(Types.Installed _)=NONE
        |parent(Types.KnownCandidate{candidate,...})=SOME(@{code KnownInput}(nat candidate))
        |parent(Types.ReservedOutput{slot,...})=SOME(@{code ReservedOutput}(nat slot))
    in @{code build_service_requirement}(nat(#template p))(nat(#source_owner source))
      (nat(#source_revision source))(nat(#manifest source))(map_filter parent(#parents p))
      (nat(#profile p))(nat(#setup p))(nat(#export_intent source))end;
  val shared=distinct(op =)(#dependencies first_plan @ #dependencies second_plan @
    [#operation_generation first_plan,#code_generation first_plan]);
  fun shape(@{code WireNat} n)=W.Natural(N.integer_of_nat n)
    |shape(@{code WireNode}(tag,children))=W.Branch(N.integer_of_nat tag,children);
  val checkpoint=case @{code deferred_build_fixture_checkpoint}(model_plan first_plan)(requirement first_plan)
      (model_plan second_plan)(requirement second_plan)(map nat shared)of
    SOME wire=>W.write_with shape wire|NONE=>error "Actual generated two-child reservation refused";
  fun wire raw=
    let fun convert(W.Atom n)= @{code WireNat}(nat n)
          |convert(W.Node(tag,children))= @{code WireNode}(nat(IntInf.fromInt tag),map convert children)
    in convert(W.read raw)end;
  structure Checkpoint =
  struct
    fun matches committed (p:Types.plan)=
      let val material=C.materials committed
        val predecessors=map_filter(fn Types.ReservedOutput{goal,...}=>SOME goal|_=>NONE)(#parents p)
      in #projection material=Codec.encode p andalso
        #operation p= #operation first_plan andalso #step p= #step first_plan andalso
        @{code deferred_build_material_matches}(wire(#checkpoint material))(model_plan p)(requirement p)
          (map nat shared)(map nat predecessors)end;
  end;
  structure NoKnown =
  struct
    datatype lease=Absent;
    fun lookup (_:IntInf.int)=NONE:lease option;
    fun candidate (_:lease):IntInf.int=error "No known parent in this fixture";
    val assigned_slot=candidate;val context=candidate;
    fun development (_:lease):P.development=error "No known parent in this fixture";
    fun is_live (_:lease)=false;
    fun retain (_:lease):lease=error "No known parent in this fixture";
    fun release (_:lease)=();
  end;
  structure Restore=Veri7vn_Native_Deferred_Build_Recovery(structure Checkpoint=Checkpoint
    structure Known=NoKnown val executable=Veri7vn_Native_Build_Image.executable);
  val image=V.install_host_image_with_roots roots(A.policy @{theory})"deferred-build-restart-unit-image";
  val required=map(fn p:Types.plan=>(#goal p,#slot p))[first_plan,second_plan];
  val first_material=Service.export_deferred image required first;
  val second_material=Service.export_deferred image required second;
  fun protect(m:Service.deferred_material)=C.install_committed_host{workspace=I.workspace allocator,
    journal_sequence=1,association= #association m,semantic_generation= #semantic_generation m,
    checkpoint=checkpoint,manifest= #manifest m,projection= #projection m,sequent= #sequent m,
    context_closure= #context_closure m,reconstruction= #reconstruction m};
  val committed_first=protect first_material;
  val committed_second=protect second_material;
  val _=Service.close owner;
  val _=List.app Scope.release_child[first_child,second_child];
  val _=Scope.release_parent parent;
  val _=P.release root;
  val _=P.release operation_root;
  val _=List.app(fn input=>(L.forget_input input;if L.disposed input then I.release_disposed_input input else()))old_inputs;
  val _=assert(forall L.disposed old_inputs) "Old original owner roots survived test restart boundary";
  val restored_root=P.public_image allocator lower;
  val resident_operation=P.public_image allocator(A.policy @{theory});
  val restored_owner=Service.create{allocator=allocator,template=101,profile=102,setup=103,operation=104,
    code_generation=105,capability=106,step=107,operation_generation=P.generation resident_operation,
    roots=roots,installed_parents=[(locator,restored_root)]};
  val configuration=Restore.install{image=image,roots=roots,operation_generation=P.generation resident_operation,
    template=101,profile=102,setup=103,operation=104,code_generation=105,capability=106,step=107};
  val pool=Pool.create allocator;
  val graph=G.create_with_roots pool roots;
  val batch=Restore.batch configuration graph allocator pool;
  val first_checked=Restore.check batch committed_first;
  val second_checked=Restore.check batch committed_second;
  val _=rejects(fn()=>Restore.validate_registered second_checked);
  val _=I.install_fragments allocator[Restore.fragment first_checked,Restore.fragment second_checked,
    V.fragment(V.seal_batch graph)];
  val scopes=Scope.restore_batch allocator;
  val(restored_parent,children)=Scope.restore scopes(Restore.scope first_checked);
  val _=Scope.restore scopes(Restore.scope second_checked);
  fun child(p:Types.plan)=the(find_first(fn actual=> #slot(Scope.identity actual)= #slot p)children);
  val historical_first_target=Unsynchronized.ref NONE;
  val historical_second_target=Unsynchronized.ref NONE;
  val historical_first=Service.restore_deferred_into historical_first_target restored_owner(child first_plan)
    (Restore.input first_checked)(Restore.operation_generation first_checked)[];
  val historical_second=Service.restore_deferred_into historical_second_target restored_owner(child second_plan)
    (Restore.input second_checked)(Restore.operation_generation second_checked)[];
  val _=Restore.scope_adopted first_checked(child first_plan);
  val _=Restore.scope_adopted second_checked(child second_plan);
  val restored_input=L.owner(Scope.source(child second_plan));
  val _=Scope.close_restore_batch scopes;
  val _=Restore.close batch;
  val _=C.release committed_first;
  val _=C.release committed_second;
  val _=assert(Service.deferred_live historical_first andalso Service.deferred_live historical_second andalso
    Service.deferred_plan historical_second=second_plan andalso L.bytes restored_input=false_source)
    "Historical deferred source lost exact original plan, bytes or independently retained owners";
  val _=assert(G.active_replays graph=0) "Deferred restoration left an unexpected replay active";
  (* Missing acknowledged predecessor refuses binding; no execution ticket was
     created anywhere in this test and the False theory remains original data. *)
  val _=rejects(fn()=>Service.bind_deferred_into(Unsynchronized.ref NONE)historical_second []);
  val _=Service.close restored_owner;
  val _=P.release restored_root;
  val _=P.release resident_operation;
  val _=G.abort graph;
  val _=Pool.close pool;
  val _=L.forget_input restored_input;
  val _=assert(L.disposed restored_input) "Deferred historical source survived final root disposal";
  val _=writeln "native_deferred_build_actual_checkpoint_restart_no_replay_ok";
in end;
\<close>
end
