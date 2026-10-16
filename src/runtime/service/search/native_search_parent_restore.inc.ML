(* Lexical include after the Search post block, before restore_run. This is a
   fixed construction transaction, not another journal, interner or authority.
   The parent supplies its SAME RecoveryInputs.pool, V.batch and Scope restore
   DAG. Parent owns the authenticated outer C capabilities and final I/Owner
   installation. No command, ticket, cost or publication is replayed. *)
structure SearchScopeRecovery=Veri7vn_Native_Scope_Recovery;
datatype search_recovery_stage=SearchRecoveryStage of
  {receivers:SearchReceiver.batch,scopes:SearchScopeRecovery.batch,
   requests:(SearchReceiver.receiver*SearchScopeRecovery.View.checked)list Unsynchronized.ref,
   sources:SearchSourceSupport.owner list Unsynchronized.ref,
   proofs:SearchOutput.verified list Unsynchronized.ref,
   entries:SearchResident.entry list Unsynchronized.ref};
fun search_recovery_begin pool shared roots=
  let val instance=SearchCore.qualify{expansions=1,frontier=1,successors=1,milliseconds=1};
    val pin=SearchCore.executable instance;
    val _=SearchCore.release_instance instance;
    val installed_roots=case roots of SOME actual=>actual|
      NONE=>Veri7vn_Native_Installed_Roots.capture_setup [];
    val installation=SearchScopeRecovery.install(boot_image())installed_roots
      {math=NONE,build=NONE,initial=NONE,update=NONE,domain=NONE,source_domain=NONE,search=SOME pin};
    val scopes=SearchScopeRecovery.batch installation(identity_allocator())pool;
    val receivers=SearchReceiver.begin_batch shared(identity_allocator())(boot_image())roots pin
  in SearchRecoveryStage{receivers=receivers,scopes=scopes,requests=Unsynchronized.ref [],
    sources=Unsynchronized.ref [],proofs=Unsynchronized.ref [],entries=Unsynchronized.ref []}end;
fun search_recovery_check_source(SearchRecoveryStage{sources,...}) pool committed=
  Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val instance=SearchCore.qualify{expansions=1,frontier=1,successors=1,milliseconds=1};
      val pin=SearchCore.executable instance;val _=SearchCore.release_instance instance;
      val target=Unsynchronized.ref NONE;
      val result=Exn.capture(restore(fn()=>SearchSourceSupport.restore_into target pool
        (identity_allocator())(boot_image())pin committed))()
    in case result of Exn.Res source=>sources:=source::(!sources)|Exn.Exn failure=>
      (Option.app SearchSourceSupport.release(!target);Exn.reraise failure)end)();
fun search_recovery_check_request(SearchRecoveryStage{receivers,scopes,requests,...}) committed=
  Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val target=Unsynchronized.ref NONE;
      val checked_root=Unsynchronized.ref(NONE:SearchScopeRecovery.View.checked option);
      (* Receiver checks exact actual request/phase/charge BEFORE graph acquire;
         Scope then checks the same authenticated wrapper in the shared pool. *)
      val _=restore(fn()=>ignore(SearchReceiver.prepare_into target receivers committed))();
      val receiver=the(!target);
      val _=restore(fn()=>checked_root:=SOME(SearchScopeRecovery.check scopes committed))();
      val checked=the(!checked_root);
      val _=requests:=(receiver,checked)::(!requests)
    in ()end)();
fun search_recovery_check_output(SearchRecoveryStage{proofs,...}) shared committed=
  Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val instance=SearchCore.qualify{expansions=1,frontier=1,successors=1,milliseconds=1};
      val pin=SearchCore.executable instance;val _=SearchCore.release_instance instance;
      val target=Unsynchronized.ref NONE;
      val output=restore(fn()=>SearchOutput.verify_source_into target shared(identity_allocator())
        (boot_image())pin committed)();
      val _=proofs:=output::(!proofs)
    in ()end)();
(* Parent prepends V.fragment(the ONE sealed shared batch) once. These are ONLY
   original Scope input fragments, never another receiver/context mapping. *)
fun search_recovery_fragments(SearchRecoveryStage{requests,sources,...})=
  map(SearchScopeRecovery.fragment o #2)(rev(!requests)) @
    map SearchSourceSupport.fragment(rev(!sources));
fun search_recovery_reconstruct(stage as SearchRecoveryStage{requests,sources,proofs,entries,...}) shared_scopes=
  let
    fun reconstruct(receiver,checked)=Thread_Attributes.uninterruptible(fn _=>fn()=>
      let val saved= #saved(SearchCodec.inspect(SearchReceiver.inspect receiver));
        val expected=case #scope_identity saved of SOME identity=>identity|
          NONE=>error "Restored Search request lacks original child";
        val(_,children)=RequestScope.restore shared_scopes checked;
        val matching=filter(fn child=>RequestScope.identity child=expected)children;
        val child=case matching of [child]=>child|_=>error "Missing/duplicate actual restored Search child";
        val target=Unsynchronized.ref NONE;
        val entry=search_restore_request_into target receiver child;
        val _=entries:=entry::(!entries)
      in ()end)();
    val _=F.guard(null(!entries)) "Search aggregate reconstructed twice";
    val _=List.app reconstruct(rev(!requests));
    fun original source=Thread_Attributes.uninterruptible_body(fn _=>
      let val target=Unsynchronized.ref NONE;
        val entry=search_restore_source_into target NONE source;
        val _=F.guard(not(exists(fn e=>SearchResident.key e=SearchResident.key entry)(!entries)))
          "Search original source duplicates an executable child";
        val _=entries:=entry::(!entries)
      in ()end);
    val _=List.app original(rev(!sources));
    fun output verified=Thread_Attributes.uninterruptible_body(fn _=>
      let val decoded=SearchOutput.inspect verified;
        val identity= #identity(#projection decoded);
        val candidates=filter(fn e=>SearchResident.identity e=identity)(!entries);
        val existing=case candidates of [entry]=>SOME entry|[]=>NONE|
          _=>error "Search proof has ambiguous original native child";
        val target=Unsynchronized.ref NONE;
        val entry=search_restore_history_into target existing verified;
        val _=case existing of NONE=>entries:=entry::(!entries)|SOME _=>()
      in ()end);
    val _=List.app output(rev(!proofs))
  in ()end;
fun search_recovery_gates(SearchRecoveryStage{entries,...})=
  let val restored=rev(!entries);
    val proof=map_filter(fn(e as SearchResident.Entry{history,...})=>
      Option.map(fn h=>Search(SearchResident.RestoredHistory(e,h)))(Synchronized.value history))restored;
    val active=map_filter(fn(e as SearchResident.Entry{request,...})=>
      Option.map(fn _=>Search(SearchResident.RestoredRequest e))request)restored;
    val originals=map_filter(fn(e as SearchResident.Entry{original_source,...})=>
      Option.map(fn source=>Search(SearchResident.RestoredSource(e,source)))
        (Synchronized.value original_source))restored
  in active@originals@proof end;
fun search_recovery_close(SearchRecoveryStage{receivers,scopes,...})=
  (SearchReceiver.close receivers;SearchScopeRecovery.close scopes);
fun search_recovery_install(SearchRecoveryStage{entries,...})=
  List.app search_install_restored(rev(!entries));
fun search_recovery_abort(SearchRecoveryStage{entries,sources,proofs,receivers,scopes,...})=
  (List.app SearchResident.release(!entries);List.app SearchOutput.release(!proofs);
   List.app SearchSourceSupport.release(!sources);
   SearchReceiver.abort receivers;SearchScopeRecovery.close scopes);
