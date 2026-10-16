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
  fun rejects f=case Exn.capture f()of Exn.Exn _=>()|Exn.Res _=>error "Expected expert recovery refusal";
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
  val padding=String.concat(map(fn i=>"definition recovery_pad_"^Int.toString i^
    " :: nat where \"recovery_pad_"^Int.toString i^" = "^Int.toString i^"\"\n")(1 upto 50));
  val child_source="theory Recovery_Expert_Child imports Provenance_Specialist begin\n"^padding^
    "lemma inherited_selection: \"(identifier, None) ~: set (classified_observations observations)\" "^
    "by (simp add: Provenance_Specialist.classified_observations_def)\nend";
  val child_input=L.input{bytes=child_source,encoding="UTF-8"};
  val child_owner=P.install_host_source ids child_input;
  val child_span=L.slice child_input{start=0,stop=size child_source,expected=child_source};
  val child=P.replay_source[("Provenance_Specialist",development)]child_owner child_span;
  val inherited=P.named_theorem child("Recovery_Expert_Child.inherited_selection",0);
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun protect fact=
    let val native=N.register_produced ids fact val projection=N.project native
      val th=A.theorem(N.accepted native)val evidence=I.allocate ids
      val(assumptions,sorts)=chop(length(Thm.hyps_of th@Thm.prems_of th))(#premises projection)
      val artifact=V.qualify ids image fact{workspace=workspace,evidence_id=evidence,projection=projection,
        assumption_ids=assumptions,sort_ids=sorts}
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
  val(n1,p1,t1,c1,a1)=protect first;
  val(n2,p2,t2,c2,_)=protect second;
  val(n3,p3,t3,c3,_)=protect inherited;
  val _=assert(X.is_recipe(#reconstruction a1)) "Expert source exported under another reconstruction profile";
  val recipe=X.decode(#reconstruction a1);
  val _=assert(length(X.source_ids(#graph recipe))=1) "Expert source owner omitted or duplicated";
  val _=P.release root;
  val _=List.app(fn input=>(L.forget_input input;I.release_disposed_input input))[input,child_input];
  fun modified_recipe recipe=
    let val m=C.materials c1
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
  val wrong_name=modified_recipe{graph= #graph recipe,name=("Provenance_Specialist.selection_preserves_batches",0)};
  val _=rejects(fn()=>V.recheck ids image wrong_name);
  val _=C.release wrong_name;
  val wrong_alias=modified_recipe{graph= #graph recipe,name=("selected_origin_is_classified",0)};
  val _=rejects(fn()=>V.recheck ids image wrong_alias);
  val _=C.release wrong_alias;
  val graph= #graph recipe;
  val bad_imports=map(fn(n:Veri7vn_Native_Recovery_Graph.construction_node)=>
    {context_id= #context_id n,parents= #parents n,construction=case #construction n of
      Veri7vn_Native_Recovery_Graph.Replay{source_id,start,stop,...}=>
        Veri7vn_Native_Recovery_Graph.Replay{source_id=source_id,start=start,stop=stop,imports=["Foreign_Context"]}
    | construction=>construction})(#nodes graph);
  val wrong_import=modified_recipe{graph={head= #head graph,nodes=bad_imports},name= #name recipe};
  val _=rejects(fn()=>V.recheck ids image wrong_import);
  val _=C.release wrong_import;
  val cancel_batch=V.restore_batch();
  val cancel_parent=V.recheck_in cancel_batch ids image c1;
  fun restored_source verified=P.source_input(#source(the(P.replay_recipe(the(P.alias_parent
    (P.consequence_development(V.consequence verified)))))));
  val cancel_input=restored_source cancel_parent;
  val _=assert(V.active_replays cancel_batch=0) "Isolated replay counter was not initially zero";
  val replay_future=Future.fork(fn()=>V.recheck_in cancel_batch ids image c3);
  fun await_replay()=if V.active_replays cancel_batch>0 then true
    else if Future.is_finished replay_future then false
    else (Time.sleep(Time.fromMilliseconds 1);await_replay());
  val entered=Timeout.apply(Time.fromSeconds 5)await_replay();
  val _=assert entered "Expert replay finished before cancellation; no interruption coverage";
  val _=Future.cancel replay_future;
  val cancelled=Timeout.apply(Time.fromSeconds 5)Future.join_result replay_future;
  val _=assert(Exn.is_interrupt_exn cancelled) "Replay cancellation did not interrupt the actual owned construction";
  val _=assert(V.active_replays cancel_batch=0) "Cancelled replay left an active construction counter";
  val _=rejects(fn()=>V.consequence cancel_parent);
  val _=V.abort_batch cancel_batch;
  val _=assert(L.disposed cancel_input andalso is_none(I.lookup_input_identity ids cancel_input))
    "Cancelled replay retained source ownership or published its source identity";
  val _=writeln "RECOVERY expert_owned_replay_cancellation PASS";
  val race_batch=V.restore_batch();
  val race_parent=V.recheck_in race_batch ids image c1;
  val race_input=restored_source race_parent;
  val race_future=Future.fork(fn()=>V.recheck_in race_batch ids image c3);
  fun await_race()=if V.active_replays race_batch>0 then true
    else if Future.is_finished race_future then false
    else(Time.sleep(Time.fromMilliseconds 1);await_race());
  val _=assert(Timeout.apply(Time.fromSeconds 5)await_race())
    "Expert replay finished before concurrent release; no race coverage";
  val _=V.release race_parent;
  val raced=Timeout.apply(Time.fromSeconds 5)Future.join_result race_future;
  val _=assert(case raced of Exn.Exn _=>true|Exn.Res _=>false)
    "Expert replay committed before concurrent release; no lost-race coverage";
  val _=assert(V.active_replays race_batch=0) "Concurrent release left replay marked active";
  val _=V.abort_batch race_batch;
  val _=assert(L.disposed race_input andalso is_none(I.lookup_input_identity ids race_input))
    "Concurrent replay release retained source ownership or published its source identity";
  val _=writeln "RECOVERY expert_concurrent_context_release PASS";
  val batch=V.restore_batch();
  val v1=V.recheck_in batch ids image c1;
  val v2=V.recheck_in batch ids image c2;
  val v3=V.recheck_in batch ids image c3;
  val _=rejects(fn()=>N.restore ids v1);
  val _=I.install_fragments ids[V.fragment(V.seal_batch batch)];
  val r1=N.restore ids v1 val r2=N.restore ids v2 val r3=N.restore ids v3;
  val _=assert(N.project r1=p1 andalso N.project r2=p2 andalso N.project r3=p3)
    "Expert replay changed durable native identities";
  val _=assert(R.same_generation(A.generation(N.accepted r1),A.generation(N.accepted r2)))
    "Two named expert facts reconstructed separate native contexts";
  val _=List.app(fn(native,expected)=>assert(Thm.prop_of(A.theorem(N.accepted native)) aconv expected)
    "Expert replay changed the complete named theorem proposition")[(r1,t1),(r2,t2),(r3,t3)];
  val child_thy=Thm.theory_of_thm(A.theorem(N.accepted r3));
  val transferred=Thm.transfer child_thy(A.theorem(N.accepted r1));
  val _=assert(Thm.prop_of transferred aconv t1) "Expert logical import parent was not a genuine ancestor";
  val restored_input=P.source_input(#source(the(P.replay_recipe(the(P.alias_parent
    (P.consequence_development(V.consequence v1)))))));
  val _=assert(L.bytes restored_input=prefix^source^"\nretained suffix") "Expert original source bytes/slice lost";
  val _=N.release r1;
  val _=assert(N.is_live r2 andalso N.is_live r3 andalso L.retained restored_input)
    "Expert association release invalidated another retained fact/import child";
  val _=N.release r2;
  val _=assert(N.is_live r3 andalso L.retained restored_input) "Expert import ancestor retired too early";
  val _=N.release r3;
  val _=assert(L.disposed restored_input) "Final expert context release retained source bytes";
  val _=V.abort_batch batch;
  val _=List.app C.release[c1,c2,c3];
  val _=List.app N.release[n1,n2,n3];
in
  val _=writeln "RECOVERY managed_expert_replay_named_theorems PASS";
end;
\<close>
end
