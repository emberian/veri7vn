theory Native_Math_Recovery_Tests
  imports Native_State_Owner_Tests
begin
ML \<open>
local
  structure I=Veri7vn_Native_Identity_Allocator;
  structure N=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure R=Veri7vn_Interpreted_Request;
  structure L=Veri7vn_Native_Literals;
  structure G=Veri7vn_Native_Math_Gate;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Recovery=Veri7vn_Native_Math_Recovery;
  structure Display=Veri7vn_Refined_Math_Display;
  structure F=Veri7vn_Metadata_Frame;
  structure Manifest=Veri7vn_Recovery_Manifest;
  fun require true _=() | require false message=error message;
  fun ready(M.Ready value)=value
    | ready(M.Refused(M.Runtime_Error message))=error("Native execution: " ^ XML.content_of(YXML.parse_body message))
    | ready(M.Refused reason)=error("Native test family refused: " ^ PolyML.makestring reason);
  val ids=I.install_host_block {workspace="c0de0000000000000000000000000001",first=10000,past=75000};
  val policy=A.policy @{theory};
  val generation=N.generation @{context} {packages=[],runtime="native test fixture",
    policy="kernel",sources=[],interpretation="fixed mathematics recovery checks"};
  val pin=M.executable();
  val instance=ready(M.attach {policy=policy,generation=generation,
    code_context=Veri7vn_Executable_Identity.code_theory pin,
    limits={nodes=20000,depth=2048,work=512,seconds=5}});
  val local_policy=R.allow_mathematics ids pin instance;
  val bridge=Display.attach {allocator=ids,policy=policy,generation=generation,
    instance=instance,statement_pin=F.statement_executable()};
  val input=L.input {bytes="the sum of -2 and 3",encoding="UTF-8"};
  val request=(case R.elaborate_math local_policy input NONE of R.Ready value=>value
    | _=>error "Fixed original request did not elaborate");
  val peer_request=(case R.elaborate_math local_policy input NONE of R.Ready value=>value
    | _=>error "Second request for shared bridge did not elaborate");
  val _=ignore(L.drop_base input);
  val execution=I.allocate ids;
  val names=R.project request;
  val bridge_names=Display.project_bridge bridge;
  val model=Unsynchronized.ref F.initial_state;
  fun transition label frame=
    let val event=the(F.decode_event frame);
      val (_,next,commands,_)=F.prepare(!model)event;
      val _=require(not(F.rejected commands))("Generated native workflow rejected " ^ label);
      val _=model:=next
    in commands end;
  val prerequisites=distinct(op =)(R.native_prerequisites request @ Display.managed_dependencies bridge);
  val cost=ready(M.modeled_cost(R.family_request request));
  val _=transition "original reservation" (F.math_reserve_frame names (F.revision(!model))cost prerequisites);
  val (_,immediate_forget,forget_commands,_)=F.prepare(!model)
    (the(F.decode_event(F.lifecycle_frame(F.Forget(#request_id names)))));
  val _=require(not(F.rejected forget_commands) andalso
    not(member(op =)(F.required_request_ids immediate_forget)(#request_id names)))
    "Forgotten reservation still required a denied request artifact before input registration";
  val _=transition "statement code ownership" (F.math_statement_frame names bridge_names);
  val _=transition "admitted display bridge ownership" (F.math_bridge_frame names bridge_names);
  val _=transition "original bytes ownership" (F.math_input_frame names);
  val _=transition "prepared parameter ownership" (F.math_parameter_frame names(R.managed_dependencies request));
  (* D44 selection consumes the exact current checkpoint, not queue-time roots.
     Exercise a last owner and then the same group with a durable survivor. *)
  val registrations=[[F.math_statement_frame names bridge_names,F.math_bridge_frame names bridge_names],
    [F.math_input_frame names]];
  fun forget_with_support current rid =
    let val frame=F.current_event_frame current (F.lifecycle_frame(F.Forget rid)) registrations;
      val event=the(F.decode_event frame);
      val (_,next,commands,_)=F.prepare current event;
      val _=require(not(F.rejected commands)) "Atomic support Forget rejected"
    in (next,F.invalidation_delta current next event) end;
  val (last_forgotten,last_delta)=forget_with_support (!model)(#request_id names);
  val _=require(forall(fn id=>member(op =)(F.forgotten_ids last_forgotten)id)
    [#request_id names,#input_identity names,#bridge_id bridge_names,#statement_code_id bridge_names] andalso
    null(F.required_request_ids last_forgotten))
    "Last-owner Forget left unreconstructible support rows";
  val (_,survivor_state,survivor_commands,_)=F.prepare(!model)
    (the(F.decode_event(F.math_reserve_frame(R.project peer_request)(F.revision(!model))cost
      (distinct(op =)(R.native_prerequisites peer_request @ Display.managed_dependencies bridge)))));
  val _=require(not(F.rejected survivor_commands)) "Durable survivor reservation rejected";
  val (survivor_forgotten,_)=forget_with_support survivor_state (#request_id names);
  val _=require(member(op =)(F.required_request_ids survivor_forgotten)(#request_id(R.project peer_request))
    andalso forall(fn id=>not(member(op =)(F.forgotten_ids survivor_forgotten)id))
      [#bridge_id bridge_names,#statement_code_id bridge_names])
    "Atomic Forget retired a durable survivor's support";
  val (source_forgotten,_)=forget_with_support survivor_state (#input_identity names);
  val _=require(null(F.required_request_ids source_forgotten))
    "Forgetting the shared original input failed to invalidate both dependent requests";
  val revoke_event=the(F.decode_event(F.lifecycle_frame(F.Revoke(#request_id names))));
  val (_,revoked,revoke_commands,_)=F.prepare(!model)revoke_event;
  val _=require(not(F.rejected revoke_commands)) "Revoke fixture rejected";
  val (after_revoke,forget_delta)=forget_with_support revoked (#request_id names);
  val _=require(case forget_delta of F.Forgotten ids=>member(op =)ids(#request_id names) | _=>false)
    "Forget after Revoke lost its separate erasure delta";
  val revoke_bridge=the(F.decode_event(F.lifecycle_frame(F.Revoke(#bridge_id bridge_names))));
  val (_,bridge_revoked,bridge_revoke_commands,_)=F.prepare(!model)revoke_bridge;
  val _=require(not(F.rejected bridge_revoke_commands)) "Bridge Revoke fixture rejected";
  val (revoked_support_forgotten,revoked_support_delta)=forget_with_support bridge_revoked (#request_id names);
  val _=require(forall(fn id=>member(op =)(F.invalidation_ids revoked_support_delta)id)
    [#bridge_id bridge_names,#statement_code_id bridge_names] andalso
    forall(fn id=>member(op =)(F.forgotten_ids revoked_support_forgotten)id)
      [#bridge_id bridge_names,#statement_code_id bridge_names])
    "Already-revoked support lost its new physical Forget erasure intent";
  val (_,repeat_delta)=forget_with_support after_revoke (#request_id names);
  val _=require(null(F.invalidation_ids repeat_delta)) "Repeated Forget created a new erasure delta";
  val _=writeln "Atomic native support retirement/current survivor/category delta checks passed";
  val run=transition "durable pure charge" (F.math_execute_frame names execution cost);
  val _=require(length(F.command_views run)=1) "Actual generated pure execution command was lost";
  val _=writeln("Actual registered request constants: " ^ commas(Term.add_const_names
    (Thm.term_of(ready(M.registered_input(R.family_request request))))[]));
  val output=ready(M.execute pin instance(R.family_request request));
  val _=require(M.belongs_to(R.family_request request)output) "Actual output lost native request";
  (* Frct is an abstract reflected constructor, not a decoder input constant.
     Exercise noncanonical pairs as well: the fixed kernel conversion must
     preserve the original native input while ordinary Fract normalizes it. *)
  fun check_reflected_rational native expected =
    let val prepared=ready(M.prepare pin instance native);
      val produced=ready(M.execute pin instance prepared);
      val _=require(Thm.term_of(ready(M.input produced)) aconv Thm.term_of native)
        "Certified computation conversion replaced the original native request";
      val actual=ready(M.output_view produced);
      val _=require(case actual of M.Exact_Rational pair=>pair=expected | _=>false)
        "Abstract rational constructor bypassed total Fract normalization";
      val _=M.release_output produced;
      val _=M.release_request prepared;
    in () end;
  val _=check_reflected_rational
    @{cterm "closed_expression_run 100 (Rational (Rat.Frct (2,4)))"} (1,2);
  val _=check_reflected_rational
    @{cterm "closed_expression_run 100 (Rational (Rat.Frct (1,-2)))"} (~1,2);
  val _=check_reflected_rational
    @{cterm "closed_expression_run 100 (Rational (Rat.Frct (1,0)))"} (0,1);
  val _=check_reflected_rational
    @{cterm "closed_expression_run 100 (Rational (Rat.Frct (-2,-4)))"} (1,2);
  val _=check_reflected_rational
    @{cterm "closed_expression_run 100 (Rational (Rat.Frct (0,7)))"} (0,1);
  (* This is a declared native boundary fixture, not deployment-heap evidence. *)
  val executable="native-math-recovery-test-image/1";
  val image=V.install_host_image policy executable;
  val other_instance=ready(M.attach {policy=policy,generation=generation,
    code_context=Veri7vn_Executable_Identity.code_theory pin,
    limits={nodes=20000,depth=2048,work=512,seconds=5}});
  val other_bridge=Display.attach {allocator=ids,policy=policy,generation=generation,
    instance=other_instance,statement_pin=F.statement_executable()};
  val _=require(Exn.is_exn(Exn.capture(fn()=>Display.prepare other_bridge request output)()))
    "Equal generation allowed a different native instance to license rendering";
  val _=require(Exn.is_exn(Exn.capture(fn()=>Display.attach {allocator=ids,policy=policy,
    generation=generation,instance=instance,statement_pin=pin})()))
    "Mathematics executable was accepted as statement checker pin";
  val distinct_request=(case R.elaborate_math(R.allow_mathematics ids pin other_instance) input NONE of
    R.Ready value=>value | _=>error "Distinct bridge original did not elaborate");
  val distinct_material=Recovery.export_request image executable other_bridge distinct_request;
  val _=R.release distinct_request;
  val _=Display.release_bridge other_bridge;
  val _=require(Exn.is_exn(Exn.capture(fn()=>Display.prepare other_bridge request output)()))
    "Released rendering bridge remained usable";
  val _=M.release_instance other_instance;
  val unrelated_request=ready(M.prepare pin instance(R.native_input request));
  val unrelated_output=ready(M.execute pin instance unrelated_request);
  val _=require(Exn.is_exn(Exn.capture(fn()=>Display.prepare bridge request unrelated_output)()))
    "Another prepared request's result licensed the original statement";
  val _=M.release_output unrelated_output;
  val _=M.release_request unrelated_request;
  val witness=G.specialize ids bridge request execution output;
  val _=transition "native refined association" (G.evidence_frame witness);
  (* The native result exists before output selection. This Owner branch keeps
     the actual witness accessible but unused: the surviving original request
     and its evidence both retain the shared support; neither is independent of
     that original request. Every checkpoint is serialized by the real Owner. *)
  datatype unused_owner_event = UReserve | UPeer | UStatement | UBridge | UInput |
    UParameter | UExecute | UEvidence | UForgetPeer;
  structure UnusedOwner=Veri7vn_Native_State_Owner(struct
    type event=unused_owner_event
    fun is_live _=R.live request andalso G.live witness
    fun event_frame event revision=(case event of
        UReserve=>F.math_reserve_frame names revision cost prerequisites
      | UPeer=>F.math_reserve_frame(R.project peer_request)revision cost
          (distinct(op =)(R.native_prerequisites peer_request @ Display.managed_dependencies bridge))
      | UStatement=>F.math_statement_frame names bridge_names
      | UBridge=>F.math_bridge_frame names bridge_names
      | UInput=>F.math_input_frame names
      | UParameter=>F.math_parameter_frame names(R.managed_dependencies request)
      | UExecute=>F.math_execute_frame names execution cost
      | UEvidence=>G.evidence_frame witness
      | UForgetPeer=>F.lifecycle_frame(F.Forget(#request_id(R.project peer_request))))
    fun retirement_registrations UForgetPeer=registrations | retirement_registrations _=[]
    fun supports UExecute [F.PureRun run]= #execution run=execution andalso #request run= #request_id names
      | supports UForgetPeer commands=forall(fn F.RemoveManaged _=>true | F.AuthorityChanged _=>true | _=>false)commands
      | supports _ commands=null commands
    fun recovery_view UEvidence=F.MathOutputAssociation{evidence=G.evidence_frame witness,
          publication=G.publication_frame witness}
      | recovery_view _=F.NoAssociation
  end);
  fun unused_owner_step event=let val candidate=UnusedOwner.prepare event
      val checkpoint=the(F.decode_state(UnusedOwner.checkpoint candidate))
      val _=ignore(UnusedOwner.acknowledge candidate)
    in checkpoint end;
  val _=List.app(fn event=>ignore(unused_owner_step event))
    [UReserve,UStatement,UBridge,UInput,UParameter,UExecute,UEvidence,UPeer];
  val unused_checkpoint=unused_owner_step UForgetPeer;
  val _=require(F.evidence_matches unused_checkpoint(G.evidence_frame witness) andalso
      not(F.binding_live unused_checkpoint(#request_id names)(G.evidence witness)) andalso
      forall(fn id=>not(member(op =)(F.forgotten_ids unused_checkpoint)id))
        [#bridge_id bridge_names,#statement_code_id bridge_names])
    "Unused actual native evidence or its surviving request lost serialized shared support";
  val _=writeln "Native unused-before-selection evidence Owner/Frame retention checks passed";
  val _=transition "retained output publication" (G.publication_frame witness);
  val _=require(F.binding_live(!model)(#request_id names)(G.evidence witness))
    "Generated Reserve-to-StageOutput did not license actual native output";
  val _=require(F.restore_matches(!model)
    [F.MathRequestAssociation{names=names,dependencies=prerequisites,managed=R.managed_dependencies request,
      bridge=bridge_names,cost=cost},F.MathOutputAssociation{evidence=G.evidence_frame witness,
        publication=G.publication_frame witness}]) "Published actual native associations did not match recovery closure";
  val request_material=Recovery.export_request image executable bridge request;
  val peer_material=Recovery.export_request image executable bridge peer_request;
  val output_material=Recovery.export_output image executable witness;
  val saved_output=G.snapshot witness;
  val _=G.release witness;
  val _=R.release_workspace(I.workspace ids);
  val _=Display.release_bridge bridge;
  val _=M.release_instance instance;
  val _=I.release_generation ids generation;
  val batch=Recovery.begin_batch();
  val verified=Recovery.verify_request batch ids policy image executable request_material;
  val peer_verified=Recovery.verify_request batch ids policy image executable peer_material;
  val [XML.Elem((projection_name,projection_fields),[])]=YXML.parse_body(#projection peer_material);
  val conflicting_projection=YXML.string_of_body[XML.Elem((projection_name,
    map(fn (name,value)=>if name="statement_code" then (name,IntInf.toString(I.allocate ids))
      else (name,value))projection_fields),[])];
  fun hash bytes=Message_Digest.rep(SHA256.digest bytes);
  val conflicting_manifest=Manifest.encode {profile=Manifest.MathRequest,
    workspace=I.workspace ids,association= #association peer_material,
    semantic_generation= #semantic_generation peer_material,projection=hash conflicting_projection,
    sequent=hash(#sequent peer_material),context_closure=hash(#context_closure peer_material),
    reconstruction=Manifest.Controlled_Recipe,payload=hash(#reconstruction peer_material),executable=SOME(hash executable)};
  val conflicting={association= #association peer_material,semantic_generation= #semantic_generation peer_material,
    manifest=conflicting_manifest,projection=conflicting_projection,sequent= #sequent peer_material,
    context_closure= #context_closure peer_material,reconstruction= #reconstruction peer_material,
    executable=executable}:Recovery.material;
  val _=require(Exn.is_exn(Exn.capture(fn()=>Recovery.verify_request batch ids policy image executable conflicting)()))
    "Same saved bridge ID accepted conflicting statement code identity";
  val distinct_verified=Recovery.verify_request batch ids policy image executable distinct_material;
  val _=I.install_fragments ids [Recovery.fragment verified,Recovery.fragment peer_verified,
    Recovery.fragment distinct_verified];
  val {request=restored,bridge=restored_bridge}=Recovery.restore_request ids verified;
  val {request=restored_peer,bridge=restored_peer_bridge}=Recovery.restore_request ids peer_verified;
  val {request=restored_distinct,bridge=restored_distinct_bridge}=Recovery.restore_request ids distinct_verified;
  val _=require(not(M.same_instance(R.instance restored,R.instance restored_distinct)) andalso
    #bridge_id(Display.project_bridge restored_bridge)<> #bridge_id(Display.project_bridge restored_distinct_bridge))
    "Equal executable pins merged distinct saved bridge/instance owners";
  val _=require(M.same_instance(R.instance restored,R.instance restored_peer) andalso
    Display.project_bridge restored_bridge=Display.project_bridge restored_peer_bridge andalso
    L.same_input(R.input_owner restored,R.input_owner restored_peer))
    "Requests sharing saved bridge/input did not share actual restored native owners";
  val _=require(#request_id(R.project restored)= #association request_material)
    "Original request identity was not restored";
  val bad_sequent=YXML.string_of_body(XML.Encode.list Term_XML.Encode.term_raw
    [#output saved_output,@{prop False},Thm.prop_of(A.theorem(M.contract(R.instance restored))),
      Thm.prop_of(A.theorem(Display.bridge_contract restored_bridge))]);
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  val bad_manifest=Manifest.encode {profile=Manifest.MathOutput,
    workspace=I.workspace ids,association= #association output_material,
    semantic_generation= #semantic_generation output_material,
    projection=digest(#projection output_material),sequent=digest bad_sequent,
    context_closure=digest(#context_closure output_material),reconstruction=Manifest.Controlled_Recipe,
    payload=digest(#reconstruction output_material),executable=SOME(digest executable)};
  val bad_material={association= #association output_material,semantic_generation= #semantic_generation output_material,
    manifest=bad_manifest,projection= #projection output_material,sequent=bad_sequent,
    context_closure= #context_closure output_material,reconstruction= #reconstruction output_material,
    executable=executable}:Recovery.material;
  val refused=Exn.capture(fn()=>Recovery.restore_output ids image executable restored_bridge restored bad_material)();
  val _=require(Exn.is_exn refused) "Matching envelope accepted an unrelated specialized target";
  val recovered=Recovery.restore_output ids image executable restored_bridge restored output_material;
  val _=(case G.display recovered of Veri7vn_Refined_Math_Display.Exact {statement_html,...}=>
      require(statement_html="<p>The exact sum of -2 and 3 is 1.</p>") "Recovered controlled output changed"
    | _=>error "Recovered exact result was not exact");
  val _=G.release recovered;
  val owner=Recovery.close_batch batch;
  val shared_generation=A.generation(M.contract(R.instance restored));
  val distinct_instance=R.instance restored_distinct;
  val distinct_bridge_id= #bridge_id(Display.project_bridge restored_distinct_bridge);
  val main_bridge_id= #bridge_id(Display.project_bridge restored_bridge);
  val _=R.release restored_distinct;
  val _=Recovery.release_installation owner distinct_bridge_id;
  val _=require(Exn.is_exn(Exn.capture M.contract distinct_instance) andalso
    Exn.is_exn(Exn.capture Display.bridge_contract restored_distinct_bridge) andalso
    is_some(I.lookup_generation_id ids shared_generation))
    "Retired installation kept its roots or released a shared surviving native context";
  val survivor_output=ready(M.execute(R.executable restored)(R.instance restored)(R.family_request restored));
  val _=M.release_output survivor_output;
  val _=R.release restored;
  val _=R.release restored_peer;
  val _=Recovery.release_installation owner main_bridge_id;
  val _=Recovery.release_installation owner main_bridge_id;
  val _=require(is_none(I.lookup_generation_id ids shared_generation))
    "Final installation retained its native context association";
  val _=R.release_workspace(I.workspace ids);
  val _=Recovery.release_workspace owner;
  val _=Recovery.abort_batch batch;
  val cleared=Exn.capture Recovery.fragment verified;
  val _=require(Exn.is_exn cleared) "Closed batch retained verified private recovery payload";
  val aborted_batch=Recovery.begin_batch();
  val aborted_verified=Recovery.verify_request aborted_batch ids policy image executable request_material;
  val _=Recovery.abort_batch aborted_batch;
  val _=require(Exn.is_exn(Exn.capture Recovery.fragment aborted_verified))
    "Aborted live verification retained its private recovery payload";
  val _=writeln "Native per-installation retirement and last shared-context release checks passed";
in val _=writeln "Native math original-template, typed recovery and failure lifetime checks passed" end;
\<close>
ML \<open>
local
  structure I=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  structure D=Veri7vn_Native_Authority_Descriptor;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure R=Veri7vn_Interpreted_Request;
  structure L=Veri7vn_Native_Literals;
  structure V=Veri7vn_Native_Recovery_Check;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure Export=Veri7vn_Native_Recovery_Export;
  structure Recovery=Veri7vn_Native_Math_Recovery;
  structure Display=Veri7vn_Refined_Math_Display;
  structure F=Veri7vn_Metadata_Frame;
  fun require true _=() | require false message=error message;
  fun ready(M.Ready value)=value | ready(M.Refused reason)=error("Shared native math family refused: " ^ PolyML.makestring reason);
  val workspace="c0de0000000000000000000000000002";
  val ids=I.install_host_block {workspace=workspace,first=20000,past=80000};
  val policy=A.policy @{theory};
  val executable="shared-kernel-math-context-test/1";
  val image=V.install_host_image policy executable;
  val development=P.public_image ids policy;
  val generation=P.generation development;
  val native=N.register_produced ids(P.public_theorem development ("HOL.refl",0));
  val descriptor=D.register native;
  val kernel=Export.export ids image descriptor;
  val original_unused=D.register(N.register_produced ids(P.public_theorem development ("HOL.sym",0)));
  val unused_kernel=Export.export ids image original_unused;
  val pin=M.executable();
  val instance=ready(M.attach {policy=policy,generation=generation,
    code_context=Veri7vn_Executable_Identity.code_theory pin,
    limits={nodes=20000,depth=2048,work=512,seconds=5}});
  val bridge=Display.attach {allocator=ids,policy=policy,generation=generation,
    instance=instance,statement_pin=F.statement_executable()};
  val input=L.input {bytes="the sum of -2 and 3",encoding="UTF-8"};
  val request=(case R.elaborate_math(R.allow_mathematics ids pin instance)input NONE of
    R.Ready request=>request | _=>error "Shared request did not elaborate");
  val _=ignore(L.drop_base input);
  val request_material=Recovery.export_request image executable bridge request;
  val semantic= #semantic_generation(R.project request);
  val _=require(semantic= #semantic_generation kernel) "Fixture did not share one actual original generation";
  val _=D.release descriptor;
  val _=D.release original_unused;
  val _=R.release_workspace workspace;
  val _=Display.release_bridge bridge;
  val _=M.release_instance instance;
  val _=P.release development;
  val committed=C.install_committed_host {workspace=workspace,journal_sequence=1,
    association= #association kernel,semantic_generation= #semantic_generation kernel,
    checkpoint="shared-native-context-fixture",manifest= #manifest kernel,projection= #projection kernel,
    sequent= #sequent kernel,context_closure= #context_closure kernel,reconstruction= #reconstruction kernel};
  val unused_committed=C.install_committed_host {workspace=workspace,journal_sequence=1,
    association= #association unused_kernel,semantic_generation= #semantic_generation unused_kernel,
    checkpoint="shared-native-context-fixture",manifest= #manifest unused_kernel,projection= #projection unused_kernel,
    sequent= #sequent unused_kernel,context_closure= #context_closure unused_kernel,
    reconstruction= #reconstruction unused_kernel};
  val kernel_batch=V.restore_batch();
  val verified=V.recheck_in kernel_batch ids image committed;
  val unused_verified=V.recheck_in kernel_batch ids image unused_committed;
  val math_batch=Recovery.begin_batch();
  val _=Recovery.supply_generation math_batch policy verified;
  val math_verified=Recovery.verify_request math_batch ids policy image executable request_material;
  val sealed=V.seal_batch kernel_batch;
  val _=I.install_fragments ids[V.fragment sealed,Recovery.fragment math_verified];
  val restored_descriptor=D.restore ids verified;
  val {request=restored,bridge=restored_bridge}=Recovery.restore_request ids math_verified;
  val actual_generation=A.generation(M.contract(R.instance restored));
  val owner=Recovery.close_batch math_batch;
  (* This second checked descriptor owns its own shared-graph lease. Merely
     creating a new consequence from the alias would not retain that graph. *)
  val unused_descriptor=D.restore ids unused_verified;
  structure KernelOwner=Veri7vn_Native_State_Owner(struct
    type event=D.descriptor
    val is_live=D.is_live
    fun event_frame descriptor _=D.event_frame descriptor
    fun retirement_registrations _=[]
    fun supports _ commands=null commands
    fun recovery_view descriptor=F.KernelAssociation(D.event_frame descriptor)
  end);
  val unused_candidate=KernelOwner.prepare unused_descriptor;
  val unused_state=the(F.decode_state(KernelOwner.checkpoint unused_candidate));
  val _=ignore(KernelOwner.acknowledge unused_candidate);
  val _=require(F.evidence_matches unused_state(D.event_frame unused_descriptor) andalso
      null(F.required_request_ids unused_state))
    "Actual unused C02 descriptor did not survive Owner/Frame serialization independently of requests";
  val _=D.release restored_descriptor;
  val _=require(I.lookup_generation_id ids actual_generation=SOME semantic)
    "Last kernel descriptor released the live mathematics context";
  val output=ready(M.execute(R.executable restored)(R.instance restored)(R.family_request restored));
  val _=(case ready(M.output_view output) of M.Exact_Rational(1,1)=>()
    | _=>error "Mathematics stopped executing after kernel descriptor release");
  val _=M.release_output output;
  val _=R.release_workspace workspace;
  val _=Recovery.release_workspace owner;
  val _=require(D.is_live unused_descriptor andalso
      I.lookup_generation_id ids actual_generation=SOME semantic)
    "Mathematics retirement invalidated an independent unused C02 context owner";
  val _=D.release unused_descriptor;
  val _=require(is_none(I.lookup_generation_id ids actual_generation))
    "Final unused C02 owner retained the native context association";
  val _=V.abort_batch kernel_batch;
  val _=C.release committed;
  val _=C.release unused_committed;
in val _=writeln "Native shared kernel/mathematics context ownership checks passed" end;
\<close>

ML \<open>
local
  structure I=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  structure D=Veri7vn_Native_Authority_Descriptor;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure R=Veri7vn_Interpreted_Request;
  structure L=Veri7vn_Native_Literals;
  structure V=Veri7vn_Native_Recovery_Check;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure Export=Veri7vn_Native_Recovery_Export;
  structure Recovery=Veri7vn_Native_Math_Recovery;
  structure Inputs=Veri7vn_Native_Recovery_Inputs;
  structure Display=Veri7vn_Refined_Math_Display;
  structure F=Veri7vn_Metadata_Frame;
  fun require true _=() | require false message=error message;
  fun ready(M.Ready value)=value | ready(M.Refused reason)=error("Shared source family refused: " ^ PolyML.makestring reason);
  val workspace="c0de0000000000000000000000000004";
  val ids=I.install_host_block {workspace=workspace,first=120000,past=180000};
  val policy=A.policy @{theory};
  val executable="shared-kernel-math-input-test/1";
  val image=V.install_host_image policy executable;
  val public=P.public_image ids policy;
  val generation=P.generation public;
  val pin=M.executable();
  val instance=ready(M.attach {policy=policy,generation=generation,
    code_context=Veri7vn_Executable_Identity.code_theory pin,
    limits={nodes=20000,depth=2048,work=512,seconds=5}});
  val bridge=Display.attach {allocator=ids,policy=policy,generation=generation,
    instance=instance,statement_pin=F.statement_executable()};
  val bytes="the sum of -2 and 3";
  val input=L.input {bytes=bytes,encoding="UTF-8"};
  val request=(case R.elaborate_math(R.allow_mathematics ids pin instance)input NONE of
    R.Ready request=>request | _=>error "Shared source original did not elaborate");
  val input_id= #input_identity(R.project request);
  val semantic= #semantic_generation(R.project request);
  val source=P.install_host_source ids input;
  val _=require(P.source_identity source=input_id) "Kernel and mathematics assigned different original-input IDs";
  val slice=L.slice input {start=size bytes-1,stop=size bytes,expected="3"};
  val (_,_,fact)=P.define_from_slice public source (Binding.name "shared_original_three")slice;
  val descriptor=D.register(N.register_produced ids fact);
  val kernel=Export.export ids image descriptor;
  val math=Recovery.export_request image executable bridge request;
  val _=Option.app I.release_disposed_input(L.drop_base input);
  val _=D.release descriptor;
  val _=R.release_workspace workspace;
  val _=Display.release_bridge bridge;
  val _=M.release_instance instance;
  val _=P.release public;
  val _=require(L.disposed input) "Original shared input owners did not drain";
  val committed=C.install_committed_host {workspace=workspace,journal_sequence=1,
    association= #association kernel,semantic_generation= #semantic_generation kernel,
    checkpoint="shared-native-input-fixture",manifest= #manifest kernel,projection= #projection kernel,
    sequent= #sequent kernel,context_closure= #context_closure kernel,reconstruction= #reconstruction kernel};
  val pool=Inputs.create ids;
  val kernel_batch=V.restore_batch_with pool;
  val verified=V.recheck_in kernel_batch ids image committed;
  val math_batch=Recovery.begin_batch_with pool;
  val _=require(Recovery.supply_generation_for math_batch policy verified semantic)
    "Math public parent was absent from verified kernel construction closure";
  val math_verified=Recovery.verify_request math_batch ids policy image executable math;
  val sealed=V.seal_batch kernel_batch;
  val _=I.install_fragments ids[V.fragment sealed,Recovery.fragment math_verified];
  val restored_descriptor=D.restore ids verified;
  val {request=restored,...}=Recovery.restore_request ids math_verified;
  (* Recovery preserves saved logical context identities with managed aliases.
     Inspect the definition in this exact verified alias chain, rather than
     assuming the exposed head itself is the physical defining development. *)
  fun defining_source development = (case P.definition_recipe development of
    SOME recipe=> #source recipe
  | NONE=>(case P.alias_parent development of SOME parent=>defining_source parent
    | NONE=>error "Verified shared-input context has no defining source in its alias closure"));
  val restored_source=defining_source(P.consequence_development(V.consequence verified));
  val recovered_input=R.input_owner restored;
  val _=require(L.same_input(recovered_input,P.source_input restored_source))
    "Kernel and mathematics restored equal bytes into different physical owners";
  val owner=Recovery.close_batch math_batch;
  val _=Inputs.close pool;
  val _=D.release restored_descriptor;
  val _=require(#bytes(R.snapshot restored)=bytes andalso L.retained recovered_input)
    "Kernel source release invalidated surviving mathematics input";
  val output=ready(M.execute(R.executable restored)(R.instance restored)(R.family_request restored));
  val _=(case ready(M.output_view output) of M.Exact_Rational(1,1)=>()
    | _=>error "Shared-source mathematics no longer executed after kernel release");
  val _=M.release_output output;
  val _=R.release_workspace workspace;
  val _=Recovery.release_workspace owner;
  val _=require(L.disposed recovered_input andalso is_none(I.lookup_input_identity ids recovered_input))
    "Final shared-input consumer retained bytes or canonical input identity";
  val _=V.abort_batch kernel_batch;
  val _=Inputs.abort pool;
  val _=C.release committed;
in val _=writeln "Native kernel/mathematics shared original input ownership checks passed" end;
\<close>

ML \<open>
val _=Veri7vn_Native_Service.Test_Only.check_rpc_ownership();
val _=writeln "Native RPC FIFO, burst finalizer and ownership budget checks passed";
(* Use the actual finite host initialization route and its bounded lease. The
   fault probes run after host initialization in the resident service as well. *)
val _=Protocol_Command.run "veri7vn_service_v1"
  (map Bytes.string ["1","0","install_ids",
    "c0de0000000000000000000000000003,1000000,1065536"]);
fun await_native_fixture_ids () =
  (case Exn.capture Veri7vn_Native_Service.identity_allocator () of
    Exn.Res ids=>if Veri7vn_Native_Identity_Allocator.workspace ids="c0de0000000000000000000000000003"
      then () else error "Native proposal fixture host initialization failed"
  | Exn.Exn _=>(Time.sleep(Time.fromMilliseconds 5);await_native_fixture_ids()));
val _=Timeout.apply(Time.fromSeconds 5)await_native_fixture_ids();
val _=Veri7vn_Native_Service.Test_Only.check_proposal_cleanup
  Veri7vn_Native_Service.Test_Only.BeforeExport;
val _=Veri7vn_Native_Service.Test_Only.check_proposal_cleanup
  Veri7vn_Native_Service.Test_Only.BeforeIssue;
val _=writeln "Native proposal export/issue failure owners and tokens cleared";
\<close>
ML \<open>
Veri7vn_Native_Service.Test_Only.check_cleanup_ownership();
Veri7vn_Native_Service.Test_Only.check_pending_alias_cleanup();
\<close>

ML \<open>
val _=Export.export @{theory} (Path.binding0(Path.explode "veri7vn/assertions/math-recovery"))
  [XML.Text (cat_lines [
    "Atomic native support retirement/current survivor/category delta checks passed",
    "Native per-installation retirement and last shared-context release checks passed",
    "Native math original-template, typed recovery and failure lifetime checks passed",
    "Native shared kernel/mathematics context ownership checks passed",
    "Native RPC FIFO, burst finalizer and ownership budget checks passed",
    "Native proposal export/issue failure owners and tokens cleared",
    "Native unused-before-selection evidence Owner/Frame retention checks passed"])];
\<close>

end
