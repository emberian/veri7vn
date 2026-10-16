(* Lexical include in the ONE native service after Owner, issue_gate_token,
   implementation_artifact and launch_cleanup. Search is the parent gate case.
   Every caller already holds serialized; monitor completions enter it once. *)
val search_context_owner=Synchronized.var "veri7vn_search_public_context"
  (NONE:(P.development*SearchSource.owner)option);
fun local_search_context()=case Synchronized.value search_context_owner of
    SOME(_,owner)=>(F.guard(SearchSource.owner_live owner andalso
      not(Owner.managed_denied(SearchSource.context owner))) "Search installed context retired/denied";owner)
  |NONE=>Thread_Attributes.uninterruptible_body(fn _=>
    let val development=public_development();
      val result=Exn.capture(fn()=>SearchSource.bind_public(identity_allocator())boot_policy development)();
    in case result of Exn.Res owner=>
        (Synchronized.change search_context_owner(K(SOME(development,owner)));owner)
      |Exn.Exn failure=>(P.release development;Exn.reraise failure)end);
fun search_material deps(m:SearchCodec.artifacts):recovery_material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
   projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
   reconstruction= #reconstruction m,executable=SOME(#executable m),
   dependencies=distinct(op =)(#association m::deps)};
fun search_request_material e phase=
  search_material(SearchResident.dependencies e)(SearchCodec.export(boot_image())
    (#context(SearchResident.projection e))(SearchResident.request e)(SearchResident.names e)phase);
fun search_issue_request event phase=
  issue_gate(Search event)(SOME(search_request_material(SearchResident.event_entry event)phase));
fun search_supports e ids=
  case ids of []=>issue_gate(Search(SearchResident.Parameter e))NONE
  |id::rest=>let val event=SearchResident.Support(e,id,rest,false)
    in if Owner.registration_present(Search event)then search_supports e rest
      else issue_gate(Search event)NONE end;
(* Evidence's private certificate is attached to this exact gate, so proof
   support continuation carries that already checked material in one root. *)
val search_output_materials=Synchronized.var "veri7vn_search_output_material_roots"
  ([]:(SearchResident.key*recovery_material)list);
fun search_issue_evidence e=
  let val material=case AList.lookup(op =)(Synchronized.value search_output_materials)(SearchResident.key e)of
        SOME m=>m|NONE=>error "Search source certificate material missing";
    val SearchResident.Entry{witness,...}=e;
    val w=case Synchronized.value witness of SOME w=>w|NONE=>error "Search native proof root missing"
  in issue_gate(Search(SearchResident.Evidence(e,w)))(SOME material)end;
fun search_proof_support e ids=case ids of []=>
    (case e of SearchResident.Entry{witness,...}=>case Synchronized.value witness of
      SOME w=>issue_gate(Search(SearchResident.Publish(e,w)))NONE|
      NONE=>error "Search publication witness missing")|
  id::rest=>let val event=SearchResident.Support(e,id,rest,true)
    in if id= #receiver(SearchResident.projection e) orelse Owner.registration_present(Search event)then search_proof_support e rest
      else issue_gate(Search event)NONE end;
fun search_stopped_packet e phase=case phase of SearchCodec.Pending _=>SearchWire.pending(SearchResident.wire_identity e)|
  SearchCodec.Stopped{stop,diagnostic,progress,...}=>
    (SearchWire.validate_progress progress;
     SearchWire.root(SearchResident.wire_identity e)(SearchCodec.stop_name stop)
       [SearchWire.node "diagnostic"[][XML.Text diagnostic],progress]);
fun search_after_ack_support event=case event of SearchResident.Support(e,_,rest,true)=>search_proof_support e rest|
    SearchResident.Support(e,_,rest,false)=>search_supports e rest|
    _=>error "Search registration continuation requires support event";
fun search_history_frames e h=
  let val p=SearchResident.projection e;val n=SearchResident.names e;
    val hp=SearchOutput.history_projection h;
    val _=F.guard(#identity hp= #identity p andalso #receiver hp= #receiver p andalso #names hp=n)
      "Retained Search original control association differs";
    val native= #native hp;val deps=SearchResident.dependencies e
  in {evidence=F.search_evidence_frame p n deps native,publication=F.search_publish_frame p n deps native}end;
fun search_history_access e h=SearchOutput.history_live h andalso
  Owner.historical_output_access(search_history_frames e h);
fun search_history_packet e h status=
  let val _=F.guard(member(op =)["proved","historical_proved"]status) "Search proof display status";
    val hp=SearchOutput.history_projection h;val saved=SearchOutput.history_saved h;
    val progress=SearchOutput.history_progress h;
    val deps=distinct(op =)(SearchResident.dependencies e@ #native hp);
    val _=F.guard(length deps<=1024 andalso member(op =)deps(#receiver hp)andalso member(op =)deps(#proof hp))
      "Retained Search native provenance display bound";
    val original=String.substring(#bytes saved,#start saved,#stop saved- #start saved)
  in SearchWire.root(SearchResident.identity e)status
    [SearchWire.node "proof"[("evidence",IntInf.toString(#evidence(#names hp))),("semantic",IntInf.toString(#receiver hp)),
      ("proof_semantic",IntInf.toString(#proof hp)),("route","kernel_consequence")]
      [SearchWire.node "proposition"[][XML.Text original],SearchWire.node "dependencies"[]
        (map(fn id=>SearchWire.node "dependency"[("id",IntInf.toString id)][])deps)],progress]end;
fun start_search e sequence=
  let val SearchResident.Entry{projection=p,names=n,job,monitor,proof_scope,witness,packet,observed,history,...}=e;
    val request=SearchResident.request e;
    val i= #identity p;val instance=SearchRequest.instance request;
    val version=Owner.current_version();val epoch=Owner.current_epoch();
    val identity={execution= #execution n,slot= #slot i,operation={workspace=I.workspace(identity_allocator()),
      request= #request i,profile= #profile n,code_generation= #code n,operation= #operation n,
      step= #step n,cost= #cost p,inputs=[#parameter n],owner_version=version,epoch=epoch,
      journal_sequence=sequence,semantic_generation= #receiver p,implementation_artifact=implementation_artifact()}};
    val scope=Tickets.begin_scope issuer{owner_version=version,epoch=epoch};
    val started=Exn.capture(fn()=>SearchWorker.start(Tickets.issue_pure scope identity
      {instance=instance,request=SearchRequest.prepared request,operation=SearchCore.operation instance,
       executable=SearchRequest.executable request,generation=P.generation(SearchRequest.worker request),
       receiver=P.generation(SearchRequest.receiver request)}))();
    val _=Tickets.close_scope scope;
    fun fail message=
      let val owned=Synchronized.change_result witness(fn previous=>(previous,NONE));
        val _=Option.app SearchGate.release owned;
        val _=P.abort_scope proof_scope;
        val _=Synchronized.change packet(K NONE);
        val _=Synchronized.change search_output_materials(AList.delete(op =)(SearchResident.key e))
      in if SearchResident.entry_live e andalso not(Owner.child_unavailable(SearchResident.key e))then
        let val phase=SearchCodec.failed{execution= #execution n,reason= #failed n,diagnostic=message}
        in search_issue_request(SearchResident.Stopped(e,phase))phase end else ()end;
  in case started of Exn.Exn _=>fail "search.worker_handoff_failed"|Exn.Res running=>
    (Synchronized.change job(K(SOME running));
     let val task=Future.fork(fn()=>
       Thread_Attributes.uninterruptible(fn restore=>fn()=>
       let val output_root=Unsynchronized.ref NONE;
         val gate_root=Unsynchronized.ref NONE;
         val history_root=Unsynchronized.ref NONE;
         fun current()=SearchResident.entry_live e andalso SearchWorker.identity running=identity andalso
           not(Owner.child_unavailable(SearchResident.key e));
         fun complete()=
           let val output=restore(fn()=>SearchWorker.join running)();
             val _=output_root:=SOME output;
             val report=SearchWorker.report output;
             val _=F.guard(SearchWorker.identity running=identity) "Search charged worker association changed";
           in case #outcome report of SearchCore.ProofProposal wire=>
             let val w=restore(fn()=>SearchGate.reconstruct_into gate_root proof_scope request wire)();
               val native= #dependencies(SearchGate.project w);
               val retained=restore(fn()=>SearchOutput.retain_into history_root(boot_image())n w report)();
               val exported=SearchOutput.history_material retained;
               val material=search_material(SearchResident.dependencies e@native)exported;
               val rendered=SearchWire.proved(SearchResident.wire_identity e)
                 (Veri7vn_Native_Registry.context(P.generation(SearchRequest.receiver request)))
                 {proposition= #bytes(SearchRequest.snapshot request),evidence= #evidence n,
                  semantic= #receiver p,proof_semantic= #proof_semantic(SearchGate.project w),
                  dependencies=distinct(op =)(SearchResident.dependencies e@native)}report
             in serialized(fn()=>if current() andalso SearchGate.live w then
               (Synchronized.change witness(K(SOME w));gate_root:=NONE;
                Synchronized.change history(K(SOME retained));history_root:=NONE;
                P.commit_scope proof_scope;
                Synchronized.change observed(K native);
                Synchronized.change packet(K(SOME rendered));
                Synchronized.change search_output_materials(AList.update(op =)(SearchResident.key e,material));
                (* Evidence+certificate precedes fresh proof support rows, so
                   every durable prefix can reconstruct the actual proof. *)
                search_issue_evidence e)
               else ())end
           |_=>let val reason=case #outcome report of SearchCore.Exhausted=> #exhausted n|
                 SearchCore.BudgetStop=> #budget n|SearchCore.Deadline=> #deadline n|
                 SearchCore.Cancelled=> #cancelled n|_=>error "Search nonproof outcome";
               val phase=SearchCodec.stopped request{execution= #execution n,reason=reason,
                 diagnostic="search.no_proof_found",report=report}
             in serialized(fn()=>if current()then search_issue_request(SearchResident.Stopped(e,phase))phase else ())end end;
         val outcome=Exn.capture complete();
         val _=Option.app SearchGate.release(!gate_root);
         val _=Option.app SearchOutput.history_release(!history_root);
         val _=Option.app SearchWorker.release_output(!output_root);
         val _=if is_none(Synchronized.value witness)then P.abort_scope proof_scope else ();
         val _=serialized(fn()=>
           (Synchronized.change job(K NONE);
            case outcome of Exn.Res()=>()|Exn.Exn _=>fail "search.native_attempt_failed"))
       in ()end)());
     in Synchronized.change monitor(K(SOME task))end)end;
fun search_after_ack event commands sequence=
  let val e=SearchResident.event_entry event;val SearchResident.Entry{phase,packet,...}=e
  in case event of SearchResident.Support _=>search_after_ack_support event|
    SearchResident.Parameter _=>search_issue_request(SearchResident.Execute e)
      (SearchCodec.Pending(SOME(#execution(SearchResident.names e))))|
    SearchResident.Reserve _=>
      let val p=SearchResident.projection e;val n=SearchResident.names e;
        val support=filter(fn id=>id<> #receiver p)(distinct(op =)
          (filter(fn id=>id<> #parameter n andalso id<> #output n)
          (F.search_control_values p n)@SearchRequest.dependencies(SearchResident.request e)))
      in search_supports e support end|
    SearchResident.Execute _=>
      (F.guard(case commands of [F.PureRun run]=>SearchResident.pure_matches e run|_=>false)
        "Search acknowledged command differs from protected worker";
       Synchronized.change phase(K(SearchCodec.Pending(SOME(#execution(SearchResident.names e)))));
       start_search e sequence)|
    SearchResident.Evidence(_,w)=>search_proof_support e(#dependencies(SearchGate.project w))|
    SearchResident.Publish _=>Synchronized.change search_output_materials(AList.delete(op =)(SearchResident.key e))|
    SearchResident.Stopped(_,stopped)=>
      (Synchronized.change phase(K stopped);Synchronized.change packet(K(SOME(search_stopped_packet e stopped))))|
    _=>error "Restored search association cannot acknowledge event"end;
fun search_contexts id payload=
  let val _=F.guard(payload="") "Search context query payload";
    val owner=case Synchronized.value search_context_owner of SOME(_,owner)=>owner|NONE=>local_search_context();
    val context=SearchSource.context owner;
    val contexts=if SearchSource.owner_live owner andalso not(Owner.managed_denied context)then
      [{id=context,semantic=context,label="Installed native HOL context"}]else []
  in emit id "search_contexts" "1"[Bytes.string(SearchWire.context_list contexts)]end;
fun propose_search id payload bytes=
  let val _=F.guard(payload="") "Search proposal control payload";
    val root=Unsynchronized.ref NONE;val owned=Unsynchronized.ref NONE;
    fun cleanup()=(case !owned of NONE=>Option.app SearchSource.release(!root)|SOME e=>
      (SearchResident.deny e;SearchResident.release e;
       Synchronized.change SearchResident.entries(AList.delete(op =)(SearchResident.key e))));
    val result=Exn.capture(fn()=>
      let val source=SearchSource.prepare_into root(local_search_context())bytes;
        val p=SearchSource.project source;val n=SearchSource.names source;val q=SearchSource.request source;
        val deps=F.search_prerequisites p n(SearchRequest.dependencies q);
        val e=SearchResident.Entry{roots=SearchResident.Fresh source,request=SOME q,projection=p,names=n,dependencies=deps,
          control=Control.create true,phase=Synchronized.var "search_durable_phase"(SearchCodec.Pending NONE),
          observed=Synchronized.var "search_observed_native_dependencies" [],
          job=Synchronized.var "search_job" NONE,monitor=Synchronized.var "search_monitor" NONE,
          witness=Synchronized.var "search_proof_root" NONE,proof_scope=P.construction_scope(),
          history=Synchronized.var "search_independent_output" NONE,
          packet=Synchronized.var "search_bounded_result" NONE};
        val _=owned:=SOME e;
        (* Reserve is FIRST, as in the existing mathematics path. Every durable
           prefix therefore retains the actual typed source recipe; there is
           no support-only checkpoint with no reconstructible native child. *)
        val material=search_request_material e(SearchCodec.Pending NONE);
        val _=SearchResident.insert e;
        val _=issue_gate(Search(SearchResident.Reserve e))(SOME material);
        val(rid,gid,slot)=SearchResident.key e
      in emit id "search_proposed"(space_implode ","(map IntInf.toString[rid,gid,slot]))[]end)()
  in case result of Exn.Res()=>()|Exn.Exn failure=>(cleanup();Exn.reraise failure)end;
fun search_key payload=case space_explode "," payload of [rid,gid,slot]=>
    (SearchWire.identity rid,SearchWire.identity gid,SearchWire.identity slot)|_=>error "Search exact child key required";
fun poll_search id payload=
  let val key as(rid,gid,slot)=search_key payload;
    (* Missing/retired keys need only an inert wire reply, never a fabricated
       Scope.identity with invented interpretation or decision associations. *)
    fun absent status diagnostic=SearchWire.document(SearchWire.node "search-result"
      [("version","1"),("request",IntInf.toString rid),("goal",IntInf.toString gid),
       ("slot",IntInf.toString slot),("status",status)]
      [SearchWire.node "diagnostic"[][XML.Text diagnostic],
       SearchWire.node "progress"[("expansions","0"),("trace_total","0"),("remaining_total","0"),
         ("details_truncated","false")][SearchWire.node "trace"[][],SearchWire.node "remaining"[][]]]);
    val result=case SearchResident.lookup key of NONE=>
        if Owner.child_unavailable key then absent "cancelled" "search.child_unavailable"
        else absent "unavailable" "search.native_owner_unavailable"|
        SOME(e as SearchResident.Entry{phase,packet,witness,history,...})=>
          let val ids=SearchResident.identity e
            val retained=Synchronized.value history;
            val historical=case retained of SOME h=>search_history_access e h|NONE=>false
          in if historical then
            let val h=the retained;
              val active=SearchResident.entry_live e andalso Owner.binding_live rid(#evidence(SearchResident.names e))
            in search_history_packet e h(if active then "proved"else "historical_proved")end
          else if Owner.child_unavailable key then SearchWire.failure ids "cancelled" "search.child_unavailable"
          else if not(SearchResident.entry_live e)then SearchWire.failure ids "unavailable" "search.native_owner_unavailable"
          else case Synchronized.value witness of SOME w=>
            if SearchGate.live w andalso Owner.binding_live rid(#evidence(SearchResident.names e))
            then the(Synchronized.value packet)else
              (case e of SearchResident.Entry{roots=SearchResident.Recovered _,...}=>
                SearchWire.failure ids "unavailable" "search.interrupted_before_publication"|_=>SearchWire.pending ids)|
          NONE=>(case Synchronized.value phase of SearchCodec.Pending _=>
            (case e of SearchResident.Entry{roots=SearchResident.Recovered _,...}=>
              SearchWire.failure ids "unavailable" "search.interrupted_request_not_replayed"|_=>SearchWire.pending ids)|
            stopped=>search_stopped_packet e stopped)end
  in emit id "search_result" payload[Bytes.string result]end;
fun search_requests id payload=
  let val _=F.guard(payload="") "Search retained child query payload";
    val entries=filter(fn(key,e as SearchResident.Entry{history,...})=>
      (SearchResident.entry_live e andalso Owner.search_child_required key)orelse
      (case Synchronized.value history of SOME h=>search_history_access e h|NONE=>false))
      (Synchronized.value SearchResident.entries);
    val values=map(fn(_,e)=>let val p=SearchResident.projection e
      in {identity= #identity p,context= #context p,semantic= #receiver p}end)entries
  in emit id "search_requests" "1"[Bytes.string(SearchWire.requests values)]end;
fun search_command_info event=case event of SearchResident.Execute e=>
    let val n=SearchResident.names e;val p=SearchResident.projection e;val i= #identity p
    in SOME(space_implode ","("pure"::map IntInf.toString
      [#execution n,#request i,#slot i,#profile n,#code n,#operation n,#step n,#cost p]))end|_=>NONE;
fun search_known_request rid=exists(fn((actual,_,_),_)=>actual=rid)(Synchronized.value SearchResident.entries);
fun search_known_managed target=exists(fn(_,e)=>SearchResident.depends target e)(Synchronized.value SearchResident.entries);
fun search_cleanup action invalidations=
  let val(target,removed)=case action of F.Cancel rid=>(rid,[rid])|
      F.Revoke id=>(id,F.invalidation_ids invalidations)|F.Forget id=>(id,F.invalidation_ids invalidations)|
      F.RetireCapability id=>(id,[id])|F.RetireSource id=>(id,[id]);
    val entries=map snd(filter(fn(_,e)=>exists(fn id=>SearchResident.depends id e)removed)
      (Synchronized.value SearchResident.entries));
    val _=List.app SearchResident.deny entries;
    val _=Synchronized.change search_output_materials(filter(fn(key,_)=>not(exists(fn e=>SearchResident.key e=key)entries)));
    val cancel=case action of F.Cancel _=>true|_=>false;
    fun release()=(List.app(if cancel then SearchResident.release_execution else SearchResident.release)entries;
      serialized SearchResident.remove_released)
  in if null entries then ()else launch_cleanup target release end;

(* Fixed aggregate recovery handoff. The parent first authenticates the shared
   checkpoint, checks SearchReceiver/Scope material in the SAME V/G batch, seals
   it, and installs ALL identity/source fragments. No worker/ticket/start occurs
   here, including for a saved Pending NONE. target is parent-owned before call;
   only the parent installs the checked RestoredRequest/RestoredOutput in Owner.
   The child must be the actual required child supplied by shared Scope.restore. *)
fun search_restore_request_into target receiver child=
  Thread_Attributes.uninterruptible(fn restore=>fn()=>
  let val _=F.guard(is_none(!target)) "Search restored entry target occupied";
    val retained=Unsynchronized.ref NONE;
    val qscope=SearchRequest.construction_scope();val pscope=P.construction_scope();
    val proof_scope=P.construction_scope();val instance_root=Unsynchronized.ref NONE;
    val entry_root=Unsynchronized.ref NONE;
    fun cleanup()=case !entry_root of SOME e=>SearchResident.release e|NONE=>
      (SearchRequest.abort_scope qscope;P.abort_scope pscope;P.abort_scope proof_scope;
       Option.app SearchCore.release_instance(!instance_root);Option.app SearchReceiver.release(!retained));
    val result=Exn.capture(fn()=>
      let val actual=SearchReceiver.retain_into retained receiver;
        val material=SearchReceiver.inspect actual;
        val {links,names,saved,phase}=SearchCodec.inspect material;
        val _=F.guard(#scope_identity saved=SOME(RequestScope.identity child))
          "Search restored child differs from authenticated original requirement";
        val instance=SearchCore.qualify(#limits saved);val _=instance_root:=SOME instance;
        val facts=restore(fn()=>SearchReceiver.catalogue pscope actual)();
        val development=SearchReceiver.development actual;
        val original=Literals.owner(RequestScope.source child);
        val _=F.guard(I.lookup_input_identity(identity_allocator())original=SOME(#source links))
          "Search original source identity fragments are missing or differ";
        val source=P.install_host_source(identity_allocator())original;
        val request=restore(fn()=>SearchRequest.restore_child_owned qscope instance child saved
          {receiver=development,worker=development,source=source,facts=facts})();
        val p={identity=RequestScope.identity child,context= #context links,receiver= #receiver links,
          worker= #worker links,input= #source links,cost=SearchRequest.cost request}:F.search_projection;
        val _=F.guard(#cost p= #cost links andalso #receiver p= #worker p)
          "Search restored fixed profile/cost differs from checked original";
        val deps=F.search_prerequisites p names(SearchRequest.dependencies request);
        (* Reconstruction validates the exact recipe, then retires its prepared
           executable input. Old consumed and unstarted lineages never start
           merely because their source and context can be reconstructed. *)
        val _=SearchCore.release(SearchRequest.prepared request);
        val e=SearchResident.Entry{roots=SearchResident.Recovered{receiver=actual,pscope=pscope,
            qscope=qscope,instance=instance},request=SOME request,projection=p,names=names,dependencies=deps,
          control=Control.create true,phase=Synchronized.var "search_restored_phase" phase,
          observed=Synchronized.var "search_restored_native_dependencies" [],
          job=Synchronized.var "search_restored_job" NONE,monitor=Synchronized.var "search_restored_monitor" NONE,
          witness=Synchronized.var "search_restored_proof" NONE,proof_scope=proof_scope,
          history=Synchronized.var "search_restored_independent_output" NONE,
          packet=Synchronized.var "search_restored_packet" NONE};
        val _=entry_root:=SOME e;
        val _=target:=SOME e
      in e end)()
  in case result of Exn.Res e=>e|Exn.Exn failure=>(cleanup();Exn.reraise failure)end)();
fun search_restored_packet e w progress=
  let val _=SearchWire.validate_progress progress;val native= #dependencies(SearchGate.project w);
    val deps=distinct(op =)(SearchResident.dependencies e@native);val p=SearchResident.projection e;
    val n=SearchResident.names e;
    val proof= #proof_semantic(SearchGate.project w);
    val _=F.guard(length deps<=1024 andalso member(op =)deps(#receiver p)andalso member(op =)deps proof)
      "Search restored licensed proof provenance projection bound"
  in SearchWire.root(SearchResident.identity e)"proved"
    [SearchWire.node "proof"[("evidence",IntInf.toString(#evidence n)),("semantic",IntInf.toString(#receiver p)),
      ("proof_semantic",IntInf.toString proof),("route","kernel_consequence")]
      [SearchWire.node "proposition"[][XML.Text(#bytes(SearchRequest.snapshot(SearchResident.request e)))],
       SearchWire.node "dependencies"[](map(fn id=>SearchWire.node "dependency"[("id",IntInf.toString id)][])deps)],
     progress]end;
fun search_restore_output_into target (e as SearchResident.Entry{names,witness,packet,observed,...}) verified=
  Thread_Attributes.uninterruptible_body(fn _=>
  let val _=F.guard(is_none(!target)andalso is_none(Synchronized.value witness)) "Search restored proof target occupied";
    val progress= #progress(SearchOutput.inspect verified);
    val owned=Unsynchronized.ref NONE;
    val result=Exn.capture(fn()=>
      let val w=SearchOutput.restore_into owned(SearchResident.request e)names verified;
        val rendered=search_restored_packet e w progress;
        val _=Synchronized.change witness(K(SOME w));
        val _=Synchronized.change observed(K(#dependencies(SearchGate.project w)));
        val _=Synchronized.change packet(K(SOME rendered));
        val _=target:=SOME w;val _=owned:=NONE
      in w end)()
  in case result of Exn.Res w=>w|Exn.Exn failure=>
    (Synchronized.change witness(K NONE);Synchronized.change packet(K NONE);
     Synchronized.change observed(K []);target:=NONE;
     Option.app SearchGate.release(!owned);Exn.reraise failure)end);
fun search_install_restored e=
  (F.guard(SearchResident.native_live e orelse
    (case e of SearchResident.Entry{history,...}=>
      case Synchronized.value history of SOME h=>SearchOutput.history_live h|NONE=>false))
    "Restored search native roots unavailable";SearchResident.insert e);
(* A retained proof can exist without an execution request or active Scope.
   The exact original control projection comes only from this native capsule. *)
fun search_restore_history_into target existing verified=
  Thread_Attributes.uninterruptible(fn _=>fn()=>
  let val _=F.guard(is_none(!target)) "Restored Search history entry target occupied";
    val owned=Unsynchronized.ref NONE;
    val result=Exn.capture(fn()=>
      let val h=SearchOutput.restore_historical_into owned(identity_allocator())(boot_image())verified;
        val hp=SearchOutput.history_projection h;
        val p={identity= #identity hp,context= #context hp,receiver= #receiver hp,worker= #receiver hp,
          input= #input hp,cost= #cost hp}:F.search_projection;
        val n= #names hp;
        val deps=F.search_prerequisites p n[#input p,#receiver p];
        val e=case existing of SOME(e as SearchResident.Entry{history,...})=>
            (F.guard(SearchResident.projection e=p andalso SearchResident.names e=n andalso
              SearchResident.dependencies e=deps andalso is_none(Synchronized.value history))
              "Restored Search history conflicts with actual original child";e)
          |NONE=>let val control=Control.create false;val _=Control.mark_released control
            in SearchResident.Entry{roots=SearchResident.HistoricalOnly,request=NONE,projection=p,names=n,
              dependencies=deps,control=control,phase=Synchronized.var "historical_search_consumed_execution"
                (SearchCodec.Pending(SOME(#execution n))),observed=Synchronized.var "historical_search_native_dependencies"(#native hp),
              job=Synchronized.var "historical_search_no_job" NONE,monitor=Synchronized.var "historical_search_no_monitor" NONE,
              witness=Synchronized.var "historical_search_no_active_witness" NONE,proof_scope=P.construction_scope(),
              history=Synchronized.var "historical_search_output_owner" NONE,packet=Synchronized.var "historical_search_no_active_packet" NONE}end;
        val SearchResident.Entry{history,observed,...}=e;
        val _=Synchronized.change observed(K(#native hp));
        val _=Synchronized.change history(K(SOME h));
        val _=target:=SOME e;val _=owned:=NONE
      in e end)()
  in case result of Exn.Res e=>e|Exn.Exn failure=>
    (Option.app SearchOutput.history_release(!owned);Exn.reraise failure)end)();
val search_retirement_registrations=SearchResident.retirement_registrations;
