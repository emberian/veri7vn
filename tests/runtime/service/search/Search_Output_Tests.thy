theory Search_Output_Tests
  imports Search_Source_Tests
begin
ML_file "../../../../src/runtime/service/search/native_search_output_codec.ML"
ML_file "../../../../src/runtime/service/search/native_search_request_recovery.ML"
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure V=Veri7vn_Native_Recovery_Check;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure W=Veri7vn_Search_Fn(T);
  structure S=W.Search;
  structure Q=Veri7vn_Search_Request_Fn(S);
  structure Source=Veri7vn_Search_Source_Fn(structure S=S structure Q=Q);
  structure G=Veri7vn_Search_Gate_Fn(Q);
  structure Codec=Veri7vn_Search_Output_Codec_Fn(structure S=S structure Q=Q structure G=G);
  structure Recovery=Veri7vn_Search_Request_Recovery_Fn(structure S=S structure Q=Q);
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  fun assert true _=() | assert false message=error message;
  fun nat n=Veri7vn_Numerals.nat_of_integer n;
  fun integer n=Veri7vn_Numerals.integer_of_nat n;
  val ids=I.install_host_block{workspace="66666666666666666666666666666666",
    first=11000000000000000000000000000000,past=11000000000000000000000000010000};
  val policy=A.policy @{theory};
  val receiver=P.public_image ids policy;
  val owner=Source.bind_public ids policy receiver;
  val original="  P --> (P & P)  \n";
  val header=Wire.document(Wire.node "search-policy"[("version","1"),("context",IntInf.toString(Source.context owner)),
    ("expansions","100"),("frontier","100"),("successors","2"),("milliseconds","5000")]
    [Wire.node "catalogue"[][Wire.node "fact"[][XML.Text "HOL.TrueI"]],Wire.node "actions"[]
      [Wire.action_xml S.Introduce,Wire.action_xml S.Split,Wire.action_xml S.Assume]]);
  val digits=string_of_int(size header);
  val source_root=Unsynchronized.ref NONE;
  val entry=Source.prepare_into source_root owner(replicate_string(8-size digits)"0" ^ digits ^ "\n" ^ header ^ original);
  val p=Source.project entry;
  val n=Source.names entry;
  val i= #identity p;
  val q=Source.request entry;
  val names=[#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
    #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,#execution n,#code n,
    #evidence n,#output n,#batch n,#exhausted n,#budget n,#deadline n,#cancelled n,#failed n];
  val control= @{code search_service_control}(map nat names);
  val deps=distinct(op =)([#parameter n,#capability n,#operation n,#profile n,#code n,#template n,#input p,#receiver p]
    @ [#interpretation i,#decision i] @ Q.dependencies q);
  fun accept state event=
    let val (next,commands)= @{code step}state event
    in case commands of []=>next | [@{code RunPure} _]=>next |
      [@{code Persist} batch]=>
        let val(final,visible)= @{code step}next(@{code DurableAck}
          (@{code batch_id}batch,@{code Suc}(@{code expected_revision}batch),@{code batch_epoch}batch))
        in case visible of [@{code Visible} _]=>final | _=>error "Search model durable acknowledgement refused"end
      | _=>error "Search actual protected metadata transition refused"end;
  val initial=fold(fn id=>fn state=>accept state(@{code search_service_intrinsic}(nat id)))
    (filter(fn id=>id<> #parameter n andalso id<> #output n)names) @{code initial_state};
  val parameter=accept initial(@{code search_service_parameter}control(map nat deps));
  val reserved=accept parameter(@{code search_service_reserve}control(@{code revision}parameter)(nat(Q.cost q))(map nat deps));
  val _=assert(@{code search_service_request_matches}reserved control(map nat deps)(nat(Q.cost q)))
    "Search reservation changed original source/target/receiver pins";
  val charged=accept reserved(@{code search_service_execute}control(nat(Q.cost q)));
  val _=assert(@{code search_service_execution_matches}reserved control(nat(Q.cost q))false andalso
    @{code search_service_execution_matches}charged control(nat(Q.cost q))true)
    "Search checkpoint lost exact charged execution/fuel association";
  val _=assert(not(@{code pure_permitted}charged
    (case @{code search_service_execute}control(nat(Q.cost q)) of @{code ExecutePure}run=>run | _=>error "Search execute shape")))
    "Search same execution could be charged twice";
  val(cancelled,_)= @{code step}charged(@{code CancelRequest}(nat(#request i)));
  val _=assert(@{code search_service_stopped_matches}cancelled control @{code SearchCancelled} andalso
    not(@{code search_service_stopped_matches}cancelled control @{code SearchBudget}))
    "Search parent cancellation became another stored terminal reason";
  val issuer=T.new_issuer();
  val tscope=T.begin_scope issuer{owner_version=1,epoch=1};
  val identity={execution= #execution n,slot= #slot i,operation={workspace=I.workspace ids,
    request= #request i,profile= #profile n,code_generation= #code n,operation= #operation n,step= #step n,
    cost=Q.cost q,inputs=[#parameter n],owner_version=1,epoch=1,journal_sequence=1,
    semantic_generation= #receiver p,implementation_artifact=replicate_string 64 "b"}};
  val job=W.start(T.issue_pure tscope identity
    {instance=Source.instance entry,request=Q.prepared q,operation=S.operation(Source.instance entry),
      executable=Q.executable q,generation=P.generation receiver,receiver=P.generation receiver});
  val output=W.join job;
  val wire=case #outcome(W.report output) of S.ProofProposal wire=>wire | _=>error "Search output fixture no native proof";
  val pscope=P.construction_scope();
  val gate_root=Unsynchronized.ref NONE;
  val gate=G.reconstruct_into gate_root pscope q wire;
  val native= #dependencies(G.project gate);
  val supported=fold(fn id=>fn state=>accept state(@{code search_service_intrinsic}(nat id)))
    (filter(fn id=>not(member(op =)names id))native)charged;
  val evidenced=accept supported(@{code search_service_evidence}control(map nat deps)(map nat native));
  val published=accept evidenced(@{code search_service_publish}control(map nat deps)(map nat native));
  val _=assert(@{code search_service_output_matches}published control(map nat deps)(map nat native))
    "Search native proof output did not become the exact authority binding";
  val image=V.install_host_image policy "fixed-search-output-test-image/1";
  val pin=Q.executable q;
  val executable=Veri7vn_Native_Recovery_Pin.material pin;
  val retained_target=Unsynchronized.ref NONE;
  val retained_output=Codec.retain_into retained_target image n gate(W.report output);
  val material=Codec.history_material retained_output;
  val _=P.commit_scope pscope;
  fun checkpoint state=Veri7vn_Native_Authority_Wire.write_with
    (fn @{code WireNat} number=>Veri7vn_Native_Authority_Wire.Natural(integer number)
      | @{code WireNode}(tag,children)=>Veri7vn_Native_Authority_Wire.Branch(integer tag,children))
      (@{code encode_checkpoint}state);
  val checkpoint_bytes=checkpoint published;
  val committed=C.install_committed_host{workspace=I.workspace ids,journal_sequence=1,
    association= #association material,semantic_generation= #semantic_generation material,
    checkpoint=checkpoint_bytes,manifest= #manifest material,
    projection= #projection material,sequent= #sequent material,context_closure= #context_closure material,
    reconstruction= #reconstruction material};
  val decoded=Codec.decode image pin committed;
  val _=assert(#bytes(#saved decoded)=original andalso #identity(#projection decoded)=i andalso
    #receiver(#projection decoded)<> #proof(#projection decoded) andalso
    #evidence_id(#certificate decoded)<> #evidence n)
    "Search output erased original source or merged private certificate with licensed child";
  val wrong_pin=Veri7vn_Executable_Identity.pin @{theory}
    {artifact="wrong-search-executable",compiler="fixture",target="PolyML",serializers=[],foreign_primitives=[],settings=[]};
  val _=assert(not(can (Codec.decode image wrong_pin)committed)) "Search output accepted a changed executable pin";
  val _=assert(not(can (Codec.unpack 9)(#context_closure material))) "Search output accepted changed packet arity";
  val certificate= #certificate decoded;
  val colliding={workspace= #workspace certificate,evidence_id= #evidence n,projection= #projection certificate,
    assumption_ids= #assumption_ids certificate,sort_ids= #sort_ids certificate}:V.saved;
  val _=assert(not(can (Codec.private_domains(#projection decoded))colliding))
    "Search output treated private source certificate as the licensed user evidence";
  val _=assert(not(can (Codec.export image n gate)
    {outcome=S.Exhausted,trace=[],remaining=[],expansions=0})) "Search output accepted nonproof terminal report";
  val _=assert(not(can (Codec.export image n gate)
    {outcome=S.ProofProposal "wrong wire",trace=[],remaining=[],expansions=0})) "Search output detached report from native proof source";
  val batch=V.restore_batch();
  val verified_root=Unsynchronized.ref NONE;
  val verified=Codec.verify_source_into verified_root batch ids image pin committed;
  val _=assert(is_some(!verified_root) andalso #sequent(#saved(Codec.inspect verified))= #sequent material)
    "Search private native source certificate failed reconstruction";
  val _=Codec.release verified;
  val _=V.abort_batch batch;
  val parts=Codec.unpack 12(#context_closure material);
  val changed=Codec.pack(map_index(fn(index,part)=>if index=4 then
    YXML.string_of_body(Term_XML.Encode.term_raw @{prop True})else part)parts);
  val wrong_manifest=Codec.make_manifest Veri7vn_Recovery_Manifest.SearchOutput(I.workspace ids)
    (#association material)(#semantic_generation material)(#projection material)(#sequent material)changed
    Codec.recipe(SOME(Codec.digest executable));
  val wrong=C.install_committed_host{workspace=I.workspace ids,journal_sequence=1,
    association= #association material,semantic_generation= #semantic_generation material,
    checkpoint="same outer child",manifest=wrong_manifest,projection= #projection material,
    sequent= #sequent material,context_closure=changed,reconstruction= #reconstruction material};
  val wrong_batch=V.restore_batch();
  val wrong_root=Unsynchronized.ref NONE;
  val _=assert(not(can (Codec.verify_source_into wrong_root wrong_batch ids image pin)wrong) andalso
    is_none(!wrong_root)) "Search source certificate accepted a substituted whole target";
  val _=V.abort_batch wrong_batch;
  val _=C.release wrong;
  val request_material=Recovery.Codec.export image(Source.context owner)q n
    (Recovery.Codec.Pending(SOME(#execution n)));
  fun request_cap bytes=C.install_committed_host{workspace=I.workspace ids,journal_sequence=1,
    association= #association request_material,semantic_generation= #semantic_generation request_material,
    checkpoint=bytes,manifest= #manifest request_material,projection= #projection request_material,
    sequent= #sequent request_material,context_closure= #context_closure request_material,
    reconstruction= #reconstruction request_material};
  val request_committed=request_cap checkpoint_bytes;
  val bad_request=request_cap(checkpoint reserved);
  val(cancelled_model,_)= @{code step}published(@{code CancelRequest}(nat(#request i)));
  val _=Scope.deny(Source.parent entry);
  val _=Source.release entry;
  val _=assert(Codec.history_live retained_output andalso
    #bytes(Codec.history_saved retained_output)=original andalso not(G.active_live gate)andalso
    not(can G.request gate)) "Cancelling execution destroyed independently retained native output or left an execution grant";
  val _=G.release gate;
  val _=P.abort_scope pscope;
  val _=assert(Codec.history_live retained_output) "Execution Gate release closed counted historical proof owner";
  val _=Codec.history_release retained_output;
  val _=W.release_output output;
  val _=P.release receiver;
  (* Retire the original native owners first: the saved IDs may now be bound
     only by the actual checked fragment transaction, never a fresh ID alias. *)
  val pool=Veri7vn_Native_Recovery_Inputs.create ids;
  val shared=V.restore_batch_with pool;
  val receiver_batch=Recovery.begin_batch shared ids image NONE pin;
  val bad_receiver_root=Unsynchronized.ref NONE;
  val _=assert(not(can (Recovery.prepare_into bad_receiver_root receiver_batch)bad_request) andalso
    is_none(!bad_receiver_root)) "Search receiver reconstructed before exact consumed charge matched";
  val receiver_root=Unsynchronized.ref NONE;
  val restored_receiver=Recovery.prepare_into receiver_root receiver_batch request_committed;
  val _=assert(not(can Recovery.close receiver_batch))
    "Search receiver closed staging capability before fragments published";
  val roots=Veri7vn_Native_Installed_Roots.capture_setup [];
  val scope_install=Veri7vn_Native_Scope_Recovery.install image roots
    {math=NONE,build=NONE,initial=NONE,update=NONE,domain=NONE,source_domain=NONE,search=SOME pin};
  val scope_checks=Veri7vn_Native_Scope_Recovery.batch scope_install ids pool;
  val checked_scope=Veri7vn_Native_Scope_Recovery.check scope_checks request_committed;
  val restored_output_root=Unsynchronized.ref NONE;
  val restored_output=Codec.verify_source_into restored_output_root shared ids image pin committed;
  val sealed=V.seal_batch shared;
  val _=I.install_fragments ids[Recovery.fragment sealed,Veri7vn_Native_Scope_Recovery.fragment checked_scope];
  val scopes=Scope.restore_batch ids;
  val(restored_parent,restored_children)=Scope.restore scopes checked_scope;
  val restored_child=the_single restored_children;
  val restore_saved= #saved(Recovery.Codec.inspect(Recovery.inspect restored_receiver));
  val restored_instance=S.qualify(#limits restore_saved);
  val restored_pscope=P.construction_scope();
  val restored_facts=Recovery.catalogue restored_pscope restored_receiver;
  val restored_source=P.install_host_source ids(Veri7vn_Native_Literals.owner(Scope.source restored_child));
  val restored_qscope=Q.construction_scope();
  val restored_q=Q.restore_child_owned restored_qscope restored_instance restored_child restore_saved
    {receiver=Recovery.development restored_receiver,worker=Recovery.development restored_receiver,
      source=restored_source,facts=restored_facts};
  val _=S.release(Q.prepared restored_q);
  val restored_gate_root=Unsynchronized.ref NONE;
  val restored_gate=Codec.restore_into restored_gate_root restored_q n restored_output;
  val retained_root=Unsynchronized.ref NONE;
  val retained_receiver=Recovery.retain_into retained_root restored_receiver;
  val _=Recovery.release restored_receiver;
  val _=Recovery.close receiver_batch;
  val _=Scope.close_restore_batch scopes;
  val _=Veri7vn_Native_Scope_Recovery.close scope_checks;
  val _=C.release request_committed;
  val _=C.release committed;
  val _=C.release bad_request;
  val _=assert(Q.live restored_q andalso not(can Q.prepared restored_q) andalso
    #bytes(G.snapshot restored_gate)=original andalso
    #receiver_semantic(G.project restored_gate)= #receiver p andalso
    #proof_semantic(G.project restored_gate)= #proof(#projection decoded) andalso
    Veri7vn_Native_Registry.same_generation(A.generation(G.accepted restored_gate),
      P.generation(Recovery.development retained_receiver)))
    "Search typed restore changed source/receiver/full proof or replayed executable preparation";
  val _=G.release restored_gate;
  val _=assert(Q.live restored_q andalso forall P.is_live restored_facts)
    "Search output release destroyed independently retained original receiver/catalogue";
  val _=Q.abort_scope restored_qscope;
  val _=P.abort_scope restored_pscope;
  val _=S.release_instance restored_instance;
  val _=Recovery.release retained_receiver;
  val _=V.abort_batch shared;
  val _=Veri7vn_Native_Recovery_Inputs.abort pool;
  (* Cancelled proof restart uses ONLY the actual private V graph. There is no
     active Scope, Q, preparation, ticket, worker, charge or publication here. *)
  fun history_cap state=C.install_committed_host{workspace=I.workspace ids,journal_sequence=2,
    association= #association material,semantic_generation= #semantic_generation material,
    checkpoint=checkpoint state,manifest= #manifest material,projection= #projection material,sequent= #sequent material,
    context_closure= #context_closure material,reconstruction= #reconstruction material};
  val historical_cap=history_cap cancelled_model;
  val history_pool=Veri7vn_Native_Recovery_Inputs.create ids;
  val history_shared=V.restore_batch_with history_pool;
  val history_verified_target=Unsynchronized.ref NONE;
  val history_verified=Codec.verify_source_into history_verified_target history_shared ids image pin historical_cap;
  val history_sealed=V.seal_batch history_shared;
  val _=I.install_fragments ids[V.fragment history_sealed];
  val history_target=Unsynchronized.ref NONE;
  val historical=Codec.restore_historical_into history_target ids image history_verified;
  val _=assert(Codec.history_live historical andalso
    #identity(Codec.history_projection historical)=i andalso #bytes(Codec.history_saved historical)=original andalso
    I.lookup_generation_id ids(A.generation(Codec.history_accepted historical))=SOME(#receiver p))
    "Historical native proof changed original target/receiver/provenance or needed active request reconstruction";
  val(forgotten_model,_)= @{code step}cancelled_model(@{code Forget}(nat(#request i)));
  val forgotten_cap=history_cap forgotten_model;
  val denied_history_target=Unsynchronized.ref NONE;
  val _=assert(not(can (Codec.verify_source_into denied_history_target history_shared ids image pin)forgotten_cap))
    "Forgotten original source/evidence was reacquired as a historical proof";
  val _=C.release forgotten_cap;
  val _=Codec.history_release historical;
  val _=assert(not(Codec.history_live historical)) "Historical Forget destructor retained native proof";
  val _=V.abort_batch history_shared;
  val _=Veri7vn_Native_Recovery_Inputs.abort history_pool;
  val _=C.release historical_cap;
  val _=writeln "VERI7VN_SEARCH_RETAINED_OUTPUT_TESTS_PASSED";
  val _=writeln "VERI7VN_SEARCH_OUTPUT_METADATA_CERTIFICATE_TESTS_PASSED";
  val _=writeln "VERI7VN_SEARCH_TYPED_REQUEST_RESTORE_TESTS_PASSED";
in end
\<close>
end
