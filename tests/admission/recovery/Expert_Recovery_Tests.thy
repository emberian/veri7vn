theory Expert_Recovery_Tests
  imports Veri7vn_Admission.Veri7vn_Admission
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure V=Veri7vn_Native_Recovery_Check;
  structure X=Veri7vn_Native_Recovery_Replay;
  structure N=Veri7vn_Native_Descriptor;
  structure A=Veri7vn_Native_Admission;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure S=Veri7vn_Native_Sequent;
  structure R=Veri7vn_Native_Registry;
  fun assert b message=if b then()else error message;
  fun phase label f=(f() handle exn as Timeout.TIMEOUT _=>
    error("Expert recovery phase "^label^": "^Runtime.exn_message exn));
  fun rejects f=case Exn.capture f()of
    Exn.Exn(exn as Timeout.TIMEOUT _)=>Exn.reraise exn
  | Exn.Exn exn=>if Exn.is_interrupt exn then Exn.reraise exn else()
  | Exn.Res _=>error "Expected expert recovery refusal";
  val ids=I.install_host_block{workspace="999999999999999999999999999999ab",first=1,past=60000};
  val workspace=I.workspace ids;
  val policy=A.policy @{theory Veri7vn_Admission};
  val image=V.install_host_image policy "unit-test-expert-installed-image";
  val root=P.public_image ids policy;
  val source=File.read(Path.append(Resources.master_directory @{theory})
    (Path.explode "../development/Provenance_Specialist.thy"));
  val prefix="retained expert source prefix\n";
  val input=L.input{bytes=prefix^source^"\nretained suffix",encoding="UTF-8"};
  val owner=P.install_host_source ids input;
  val span=L.slice input{start=size prefix,stop=size prefix+size source,expected=source};
  val development=P.replay_source[(Context.theory_name{long=true}(A.policy_theory policy),root)]owner span;
  val first=P.named_theorem development("Provenance_Specialist.selected_origin_is_classified",0);
  val second=P.named_theorem development("Provenance_Specialist.selection_preserves_batches",0);
  val temporary_scope=P.construction_scope();
  val temporary_source_lease=P.retain_source_owned temporary_scope owner;
  val temporary_first=P.named_theorem_owned temporary_scope development
    ("Provenance_Specialist.selected_origin_is_classified",0);
  val temporary_second=P.named_theorem_owned temporary_scope development
    ("Provenance_Specialist.selection_preserves_batches",0);
  val _=P.abort_scope temporary_scope;
  val _=rejects(fn()=>L.lease_input temporary_source_lease);
  val _=assert(L.retained input) "Scoped source lease rollback invalidated another input owner";
  val _=rejects(fn()=>P.retain_source_owned temporary_scope owner);
  val _=writeln "RECOVERY scoped_source_lease_rollback PASS";
  val _=assert(not(P.is_live temporary_first) andalso not(P.is_live temporary_second) andalso
    P.is_live first andalso P.is_live second andalso P.development_live development)
    "Named-consequence rollback retired another owner or retained temporary theorem cells";
  val _=rejects(fn()=>P.named_theorem_owned temporary_scope development
    ("Provenance_Specialist.selected_origin_is_classified",0));
  val _=assert(P.is_live first) "Closed consequence scope damaged a retained named fact";
  val _=writeln "RECOVERY scoped_named_consequence_rollback PASS";
  val diamond_root=P.public_image ids policy;
  val diamond_inputs=Unsynchronized.ref([]:L.input list);
  fun diamond_node name parents=
    let val imports=space_implode " "(map(fn(name,_)=>"\""^name^"\"")parents)
      val bytes="theory "^name^" imports "^imports^" begin\nlemma diamond_truth: \"True\" by simp\nend"
      val input=L.input{bytes=bytes,encoding="UTF-8"}
      val _=diamond_inputs:=input::(!diamond_inputs)
      val source=P.install_host_source ids input
      val slice=L.slice input{start=0,stop=size bytes,expected=bytes}
    in P.replay_source parents source slice end;
  val shared_name="Recovery_Diamond_Shared";
  val shared_diamond=diamond_node shared_name
    [(Context.theory_name{long=true}(A.policy_theory policy),diamond_root)];
  val shared_diamond_input=hd(!diamond_inputs);
  fun diamond_level depth parents=
    let val left="Recovery_Diamond_Left_"^Int.toString depth
      val right="Recovery_Diamond_Right_"^Int.toString depth
    in [(left,diamond_node left parents),(right,diamond_node right parents)]end;
  val diamond_tops=fold diamond_level(1 upto 22)[(shared_name,shared_diamond)];
  val diamond_alias=P.context_alias(#2(hd diamond_tops));
  val _=assert(phase "shared diamond liveness"(fn()=>
    Timeout.apply(Time.fromSeconds 2)P.development_live diamond_alias))
    "Shared native diamond incorrectly unavailable";
  val _=L.invalidate shared_diamond_input;
  val _=ignore(P.generation diamond_alias);
  val _=assert(not(P.development_live diamond_alias))
    "Revoked shared source left a retained logical diamond alias live";
  val _=P.release diamond_root;
  val _=List.app(fn input=>(L.forget_input input;I.release_disposed_input input))(!diamond_inputs);
  val _=assert(List.all L.disposed(!diamond_inputs)) "Diamond source owners survived complete release";
  val _=writeln "RECOVERY shared_diamond_liveness_and_retired_alias PASS";
  val padding=String.concat(map(fn i=>"definition recovery_pad_"^Int.toString i^
    " :: nat where \"recovery_pad_"^Int.toString i^" = "^Int.toString i^"\"\n")(1 upto 50));
  val aux_source="theory Recovery_Expert_Aux imports \"Veri7vn_Admission.Veri7vn_Admission\" begin\n"^
    "definition auxiliary_origin :: nat where \"auxiliary_origin = 7\"\n"^
    "lemma auxiliary_origin_value: \"auxiliary_origin = 7\" by (simp add: auxiliary_origin_def)\nend";
  val aux_input=L.input{bytes=aux_source,encoding="UTF-8"};
  val aux_owner=P.install_host_source ids aux_input;
  val aux_span=L.slice aux_input{start=0,stop=size aux_source,expected=aux_source};
  val auxiliary=P.replay_source[(Context.theory_name{long=true}(A.policy_theory policy),root)]aux_owner aux_span;
  val auxiliary_fact=P.named_theorem auxiliary("Recovery_Expert_Aux.auxiliary_origin_value",0);
  val child_source="theory Recovery_Expert_Child imports Provenance_Specialist Recovery_Expert_Aux begin\n"^padding^
    "lemma inherited_selection: \"(identifier, None) ~: set (classified_observations observations) & auxiliary_origin = 7\" "^
    "by (simp add: Provenance_Specialist.classified_observations_def Recovery_Expert_Aux.auxiliary_origin_def)\nend";
  val child_input=L.input{bytes=child_source,encoding="UTF-8"};
  val child_owner=P.install_host_source ids child_input;
  val child_span=L.slice child_input{start=0,stop=size child_source,expected=child_source};
  val child=P.replay_source[("Provenance_Specialist",development),("Recovery_Expert_Aux",auxiliary)]child_owner child_span;
  val inherited=P.named_theorem child("Recovery_Expert_Child.inherited_selection",0);
  val proof_bytes="retained proof prefix\nTrue ==> True\nretained proof suffix";
  val proof_input=L.input{bytes=proof_bytes,encoding="UTF-8"};
  val proof_owner=P.install_host_source ids proof_input;
  val proof_span=L.slice proof_input{start=size "retained proof prefix\n",
    stop=size "retained proof prefix\nTrue ==> True",expected="True ==> True"};
  val proof_ctxt=R.context(P.generation root);
  val proof_true=Thm.cterm_of proof_ctxt @{prop True};
  val proof_theorem=Thm.implies_intr proof_true(Thm.assume proof_true);
  val proof_target=Thm.cterm_of proof_ctxt(Syntax.read_prop proof_ctxt(L.original proof_span));
  val proof_snapshot=S.capture proof_target proof_theorem;
  val proof_thy=Proof_Context.theory_of proof_ctxt;
  val proof_wire=Veri7vn_Proof_Transport.export proof_thy proof_thy proof_theorem;
  val refused_scope=P.construction_scope();
  val _=rejects(fn()=>P.prove_from_slice_owned refused_scope root proof_owner proof_span proof_wire);
  val _=P.abort_scope refused_scope;
  val proof_scope=P.construction_scope();
  val(proof_development,proof_fact)=phase "produce full-sequent proof"(fn()=>
    P.prove_from_slice_sequent_owned proof_scope root proof_owner proof_span proof_snapshot proof_wire);
  val _=P.commit_scope proof_scope;
  val _=assert(Thm.nprems_of(A.theorem(P.accepted proof_fact))=1)
    "Managed proof producer lost its explicit full-statement premise";
  val proof_child_source="theory Recovery_Proof_Child imports \"Veri7vn_Admission.Veri7vn_Admission\" begin\n"^
    "lemma proof_child_truth: \"True\" by simp\nend";
  val proof_child_input=L.input{bytes=proof_child_source,encoding="UTF-8"};
  val proof_child_owner=P.install_host_source ids proof_child_input;
  val proof_child_span=L.slice proof_child_input{start=0,stop=size proof_child_source,expected=proof_child_source};
  val proof_child=P.replay_source[(Context.theory_name{long=true}(A.policy_theory policy),proof_development)]
    proof_child_owner proof_child_span;
  val proof_child_fact=P.named_theorem proof_child("Recovery_Proof_Child.proof_child_truth",0);
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun protect label fact=
    let val native=N.register_produced ids fact val projection=N.project native
      val th=A.theorem(N.accepted native)val evidence=I.allocate ids
      val(assumptions,sorts)=chop(length(Thm.hyps_of th@Thm.prems_of th))(#premises projection)
      val artifact=phase("qualify "^label)(fn()=>V.qualify ids image fact{workspace=workspace,evidence_id=evidence,projection=projection,
        assumption_ids=assumptions,sort_ids=sorts})
      val manifest=Veri7vn_Recovery_Manifest.encode{profile=Veri7vn_Recovery_Manifest.KernelEvidence,
        workspace=workspace,association=evidence,semantic_generation= #semantic_generation projection,
        projection=digest(#projection artifact),sequent=digest(#sequent artifact),
        context_closure=digest(#context_closure artifact),payload=digest(#reconstruction artifact),
        reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,executable=NONE}
      val material={workspace=workspace,journal_sequence=17,association=evidence,
        semantic_generation= #semantic_generation projection,checkpoint="unit-current-checkpoint",
        manifest=manifest,projection= #projection artifact,sequent= #sequent artifact,
        context_closure= #context_closure artifact,reconstruction= #reconstruction artifact}
    in(native,projection,Thm.prop_of th,C.install_committed_host material,artifact)end;
  val(n1,p1,t1,c1,a1)=protect "first" first;
  val(n2,p2,t2,c2,_)=protect "second" second;
  val(n3,p3,t3,c3,a3)=protect "inherited" inherited;
  val(n4,p4,t4,c4,_)=protect "auxiliary_fact" auxiliary_fact;
  val(n5,p5,t5,c5,a5)=protect "proof_fact" proof_fact;
  val(n6,p6,t6,c6,a6)=protect "proof_child_fact" proof_child_fact;
  val named_proof_recipe=X.decode(#reconstruction a6);
  val _=assert(case #name named_proof_recipe of X.Named _=>true|_=>false)
    "Named descendant of a produced proof lost its actual theorem selector";
  val _=assert(case YXML.parse_body(#reconstruction a6)of
    [XML.Elem((_,("version","2")::_),_)]=>true|_=>false)
    "Named descendant with Proof ancestry did not select version2";
  val legacy_proof_wire=case YXML.parse_body(#reconstruction a6)of
    [XML.Elem((name,(_,_)::fields),body)]=>YXML.string_of_body[XML.Elem((name,("version","1")::fields),body)]
    | _=>error "Named proof recipe fixture framing";
  val _=rejects(fn()=>X.decode legacy_proof_wire);
  val proof_recipe=X.decode(#reconstruction a5);
  val _=assert(case #name proof_recipe of X.Produced=>true|_=>false)
    "Managed proof consequence acquired a fake named-theorem reconstruction";
  val child_recipe=X.decode(#reconstruction a3);
  val child_graph= #graph child_recipe;
  val _=assert(length(X.source_ids child_graph)=3 andalso length(#nodes child_graph)=4)
    "Multi-parent expert closure duplicated its shared public root or omitted a source";
  val child_node=X.node child_graph(#head child_graph);
  val _=assert(case #construction child_node of
    Veri7vn_Native_Recovery_Graph.Replay{imports,...}=>imports=["Provenance_Specialist","Recovery_Expert_Aux"]
    | _=>false) "Multi-parent expert closure changed ordered source imports";
  val _=assert(X.is_recipe(#reconstruction a1)) "Expert source exported under another reconstruction profile";
  val recipe=X.decode(#reconstruction a1);
  val _=assert(length(X.source_ids(#graph recipe))=1) "Expert source owner omitted or duplicated";
  val _=P.release root;
  val _=List.app(fn input=>(L.forget_input input;I.release_disposed_input input))[input,aux_input,child_input,proof_input,proof_child_input];
  fun modified_committed original recipe=
    let val m=C.materials original
      val wire=X.encode recipe
      val manifest=Veri7vn_Recovery_Manifest.encode{profile=Veri7vn_Recovery_Manifest.KernelEvidence,
        workspace=workspace,association= #association m,semantic_generation= #semantic_generation m,
        projection=digest(#projection m),sequent=digest(#sequent m),
        context_closure=digest(#context_closure m),payload=digest wire,
        reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,executable=NONE}
    in C.install_committed_host{workspace=workspace,journal_sequence= #journal_sequence m,
      association= #association m,semantic_generation= #semantic_generation m,checkpoint= #checkpoint m,
      manifest=manifest,projection= #projection m,sequent= #sequent m,
      context_closure= #context_closure m,reconstruction=wire}end;
  fun modified_recipe recipe=modified_committed c1 recipe;
  val reversed_nodes=map(fn(n:Veri7vn_Native_Recovery_Graph.construction_node)=>
    if #context_id n<> #head child_graph then n else
      {context_id= #context_id n,parents= #parents n,construction=case #construction n of
        Veri7vn_Native_Recovery_Graph.Replay{source_id,start,stop,imports}=>
          Veri7vn_Native_Recovery_Graph.Replay{source_id=source_id,start=start,stop=stop,imports=rev imports}
      | construction=>construction})(#nodes child_graph);
  val reversed_imports=modified_committed c3{graph={head= #head child_graph,nodes=reversed_nodes},name= #name child_recipe};
  val _=phase "negative reversed_imports"(fn()=>rejects(fn()=>V.recheck ids image reversed_imports));
  val _=C.release reversed_imports;
  val wrong_name=modified_recipe{graph= #graph recipe,name=X.Named("Provenance_Specialist.selection_preserves_batches",0)};
  val _=phase "negative wrong_name"(fn()=>rejects(fn()=>V.recheck ids image wrong_name));
  val _=C.release wrong_name;
  val wrong_alias=modified_recipe{graph= #graph recipe,name=X.Named("selected_origin_is_classified",0)};
  val _=phase "negative wrong_alias"(fn()=>rejects(fn()=>V.recheck ids image wrong_alias));
  val _=C.release wrong_alias;
  val graph= #graph recipe;
  val bad_imports=map(fn(n:Veri7vn_Native_Recovery_Graph.construction_node)=>
    {context_id= #context_id n,parents= #parents n,construction=case #construction n of
      Veri7vn_Native_Recovery_Graph.Replay{source_id,start,stop,...}=>
        Veri7vn_Native_Recovery_Graph.Replay{source_id=source_id,start=start,stop=stop,imports=["Foreign_Context"]}
    | construction=>construction})(#nodes graph);
  val wrong_import=modified_recipe{graph={head= #head graph,nodes=bad_imports},name= #name recipe};
  val _=phase "negative wrong_import"(fn()=>rejects(fn()=>V.recheck ids image wrong_import));
  val _=C.release wrong_import;
  val cancel_batch=V.restore_batch();
  val cancel_parent=phase "restore cancel_parent"(fn()=>V.recheck_in cancel_batch ids image c1);
  fun restored_source verified=P.source_input(#source(the(P.replay_recipe(the(P.alias_parent
    (P.consequence_development(V.consequence verified)))))));
  val cancel_input=restored_source cancel_parent;
  val _=assert(V.active_replays cancel_batch=0) "Isolated replay counter was not initially zero";
  val replay_future=Future.fork(fn()=>V.recheck_in cancel_batch ids image c3);
  fun await_replay()=if V.active_replays cancel_batch>0 then true
    else if Future.is_finished replay_future then false
    else (Time.sleep(Time.fromMilliseconds 1);await_replay());
  val entered=phase "await cancellation replay"(fn()=>Timeout.apply(Time.fromSeconds 5)await_replay());
  val _=assert entered "Expert replay finished before cancellation; no interruption coverage";
  val _=Future.cancel replay_future;
  val cancelled=phase "join cancelled replay"(fn()=>Timeout.apply(Time.fromSeconds 5)Future.join_result replay_future);
  val _=assert(Exn.is_interrupt_exn cancelled) "Replay cancellation did not interrupt the actual owned construction";
  val _=assert(V.active_replays cancel_batch=0) "Cancelled replay left an active construction counter";
  val _=rejects(fn()=>V.consequence cancel_parent);
  val _=V.abort_batch cancel_batch;
  val _=assert(L.disposed cancel_input andalso is_none(I.lookup_input_identity ids cancel_input))
    "Cancelled replay retained source ownership or published its source identity";
  val _=writeln "RECOVERY expert_owned_replay_cancellation PASS";
  val race_batch=V.restore_batch();
  val race_parent=phase "restore race_parent"(fn()=>V.recheck_in race_batch ids image c1);
  val race_input=restored_source race_parent;
  val race_future=Future.fork(fn()=>V.recheck_in race_batch ids image c3);
  fun await_race()=if V.active_replays race_batch>0 then true
    else if Future.is_finished race_future then false
    else(Time.sleep(Time.fromMilliseconds 1);await_race());
  val _=assert(phase "await concurrent release replay"(fn()=>Timeout.apply(Time.fromSeconds 5)await_race()))
    "Expert replay finished before concurrent release; no race coverage";
  val _=V.release race_parent;
  val raced=phase "join concurrent release replay"(fn()=>Timeout.apply(Time.fromSeconds 5)Future.join_result race_future);
  val _=assert(case raced of Exn.Exn _=>true|Exn.Res _=>false)
    "Expert replay committed before concurrent release; no lost-race coverage";
  val _=assert(V.active_replays race_batch=0) "Concurrent release left replay marked active";
  val _=V.abort_batch race_batch;
  val _=assert(L.disposed race_input andalso is_none(I.lookup_input_identity ids race_input))
    "Concurrent replay release retained source ownership or published its source identity";
  val _=writeln "RECOVERY expert_concurrent_context_release PASS";
  val batch=V.restore_batch();
  val v1=phase "restore v1"(fn()=>V.recheck_in batch ids image c1);
  val v2=phase "restore v2"(fn()=>V.recheck_in batch ids image c2);
  val v3=phase "restore v3"(fn()=>V.recheck_in batch ids image c3);
  val v4=phase "restore v4"(fn()=>V.recheck_in batch ids image c4);
  val v5=phase "restore v5"(fn()=>V.recheck_in batch ids image c5);
  val v6=phase "restore v6"(fn()=>V.recheck_in batch ids image c6);
  val proof_child_restored_input=restored_source v6;
  val proof_restored_input=P.source_input(#source(the(P.proof_recipe(X.physical
    (P.consequence_development(V.consequence v5))))));
  val auxiliary_restored_input=restored_source v4;
  val child_restored_input=restored_source v3;
  val _=rejects(fn()=>N.restore ids v1);
  val _=I.install_fragments ids[V.fragment(V.seal_batch batch)];
  val r1=N.restore ids v1 val r2=N.restore ids v2 val r3=N.restore ids v3 val r4=N.restore ids v4 val r5=N.restore ids v5 val r6=N.restore ids v6;
  val _=assert(N.project r1=p1 andalso N.project r2=p2 andalso N.project r3=p3 andalso N.project r4=p4 andalso N.project r5=p5 andalso N.project r6=p6)
    "Expert replay changed durable native identities";
  val _=assert(R.same_generation(A.generation(N.accepted r1),A.generation(N.accepted r2)))
    "Two named expert facts reconstructed separate native contexts";
  val _=List.app(fn(native,expected)=>assert(Thm.prop_of(A.theorem(N.accepted native)) aconv expected)
    "Expert replay changed the complete named theorem proposition")[(r1,t1),(r2,t2),(r3,t3),(r4,t4),(r5,t5),(r6,t6)];
  val _=assert(S.matches proof_snapshot(A.target(N.accepted r5))(A.theorem(N.accepted r5)))
    "Recovered proof changed explicit target, hypotheses, premises or sorts";
  val _=assert(L.bytes proof_restored_input=proof_bytes) "Proof recovery lost original source payload";
  val child_thy=Thm.theory_of_thm(A.theorem(N.accepted r3));
  val transferred=Thm.transfer child_thy(A.theorem(N.accepted r1));
  val _=assert(Thm.prop_of transferred aconv t1) "Expert logical import parent was not a genuine ancestor";
  val _=assert(Thm.prop_of(Thm.transfer child_thy(A.theorem(N.accepted r4))) aconv t4)
    "Second expert logical import parent was not a genuine ancestor";
  val restored_input=P.source_input(#source(the(P.replay_recipe(the(P.alias_parent
    (P.consequence_development(V.consequence v1)))))));
  val _=assert(L.bytes restored_input=prefix^source^"\nretained suffix") "Expert original source bytes/slice lost";
  val _=N.release r1;
  val _=assert(N.is_live r2 andalso N.is_live r3 andalso L.retained restored_input)
    "Expert association release invalidated another retained fact/import child";
  val _=N.release r2;
  val _=assert(N.is_live r3 andalso L.retained restored_input) "Expert import ancestor retired too early";
  val _=N.release r4;
  val _=assert(N.is_live r3 andalso L.retained auxiliary_restored_input)
    "Second expert import ancestor retired while child remained live";
  val _=N.release r3;
  val _=assert(List.all L.disposed[restored_input,auxiliary_restored_input,child_restored_input]) "Final expert context release retained source bytes";
  val _=N.release r5;
  val _=assert(N.is_live r6 andalso L.retained proof_restored_input)
    "Named descendant lost its actual produced-proof parent ownership";
  val _=N.release r6;
  val _=assert(L.disposed proof_restored_input andalso L.disposed proof_child_restored_input)
    "Final named descendant retained its proof/source ownership";
  val _=writeln "RECOVERY proof_named_descendant_version2 PASS";
  val _=writeln "RECOVERY managed_proof_source_full_sequent PASS";
  val _=V.abort_batch batch;
  val _=List.app C.release[c1,c2,c3,c4,c5,c6];
  val _=List.app N.release[n1,n2,n3,n4,n5,n6];
in
  val _=writeln "RECOVERY managed_expert_replay_named_theorems PASS";
end;
\<close>
end
