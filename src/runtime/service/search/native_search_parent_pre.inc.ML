(* Lexical include inside the ONE sealed native service, before gate/Owner.
   This table owns native resources. Permission remains exclusively in Owner. *)
structure SearchWorker=Veri7vn_Search_Fn(Tickets);
structure SearchCore=SearchWorker.Search;
structure SearchRequest=Veri7vn_Search_Request_Fn(SearchCore);
structure SearchSource=Veri7vn_Search_Source_Fn
  (structure S=SearchCore structure Q=SearchRequest);
structure SearchGate=Veri7vn_Search_Gate_Fn(SearchRequest);
structure SearchReceiver=Veri7vn_Search_Request_Recovery_Fn
  (structure S=SearchCore structure Q=SearchRequest);
structure SearchCodec=SearchReceiver.Codec;
structure SearchOutput=Veri7vn_Search_Output_Codec_Fn
  (structure S=SearchCore structure Q=SearchRequest structure G=SearchGate);
structure SearchWire=Veri7vn_Search_Protocol_Fn(SearchCore);
structure SearchResident=
struct
  type key=IntInf.int*IntInf.int*IntInf.int;
  datatype roots=Fresh of SearchSource.entry | HistoricalOnly | Recovered of
    {receiver:SearchReceiver.receiver,pscope:P.construction_scope,
     qscope:SearchRequest.construction_scope,instance:SearchCore.instance};
  datatype entry=Entry of {roots:roots,request:SearchRequest.request option,
    projection:F.search_projection,names:F.search_control_names,dependencies:IntInf.int list,
    control:Control.cell,phase:SearchCodec.phase Synchronized.var,
    observed:IntInf.int list Synchronized.var,
    job:SearchWorker.job option Synchronized.var,monitor:unit Future.future option Synchronized.var,
    witness:SearchGate.witness option Synchronized.var,proof_scope:P.construction_scope,
    history:SearchOutput.historical option Synchronized.var,
    packet:string option Synchronized.var};
  datatype event=Support of entry*IntInf.int*IntInf.int list*bool |
    Parameter of entry | Reserve of entry | Execute of entry |
    Evidence of entry*SearchGate.witness | Publish of entry*SearchGate.witness |
    Stopped of entry*SearchCodec.phase | RestoredRequest of entry |
    RestoredOutput of entry*SearchGate.witness | RestoredHistory of entry*SearchOutput.historical;
  val entries=Synchronized.var "veri7vn_search_native_roots" ([]:(key*entry)list);
  fun projection(Entry{projection,...})=projection;
  fun names(Entry{names,...})=names;
  fun request(Entry{request,...})=case request of SOME actual=>actual|
    NONE=>error "Historical Search output has no execution request";
  fun dependencies(Entry{dependencies,...})=dependencies;
  fun identity e= #identity(projection e);
  val wire_identity=identity;
  fun key e=let val i=identity e in (#request i,#goal i,#slot i)end;
  fun lookup k=AList.lookup(op =)(Synchronized.value entries)k;
  fun native_live(Entry{request,control,...})=Control.active control andalso
    (case request of SOME actual=>SearchRequest.live actual|NONE=>false);
  fun entry_live(e as Entry{control,...})=native_live e andalso
    (case lookup(key e)of SOME(Entry{control=actual,...})=>
      Control.incarnation actual=Control.incarnation control|NONE=>false);
  fun insert e=Synchronized.change entries(fn old=>
    (F.guard(length old<256 andalso is_none(AList.lookup(op =)old(key e)))
      "Search resident ownership capacity/duplicate child";(key e,e)::old));
  fun event_entry(Support(e,_,_,_))=e|event_entry(Parameter e)=e|
    event_entry(Reserve e)=e|event_entry(Execute e)=e|event_entry(Evidence(e,_))=e|
    event_entry(Publish(e,_))=e|event_entry(Stopped(e,_))=e|
    event_entry(RestoredRequest e)=e|event_entry(RestoredOutput(e,_))=e|event_entry(RestoredHistory(e,_))=e;
  fun live event=(case event of RestoredRequest e=>native_live e|
      RestoredOutput(e,w)=>native_live e andalso SearchGate.live w|
      RestoredHistory(_,h)=>SearchOutput.history_live h|
      _=>entry_live(event_entry event) andalso
        (case event of Evidence(_,w)=>SearchGate.live w|Publish(_,w)=>SearchGate.live w|
          Support(Entry{witness,...},_,_,true)=>
            (case Synchronized.value witness of SOME w=>SearchGate.live w|NONE=>false)|_=>true))
    handle ERROR _=>false;
  fun stop_name(SearchCodec.Stopped{stop,...})=SearchCodec.stop_name stop
    |stop_name _=error "Pending search has no terminal outcome";
  fun frame event revision=
    let val e=event_entry event;val p=projection e;val n=names e;val deps=dependencies e
    in case event of Support(_,id,_,_)=>F.search_intrinsic_frame id|
      Parameter _=>F.search_parameter_frame p n deps|
      Reserve _=>F.search_reserve_frame p n revision(#cost p)deps|
      Execute _=>F.search_execute_frame p n(#cost p)|
      Evidence(_,w)=>F.search_evidence_frame p n deps(#dependencies(SearchGate.project w))|
      Publish(_,w)=>F.search_publish_frame p n deps(#dependencies(SearchGate.project w))|
      Stopped(_,phase)=>F.search_stopped_frame p n(stop_name phase)|
      _=>error "Restored search association is not an event"end;
  fun pure_matches e({execution,request,slot,cost,inputs}:F.pure_run)=
    let val p=projection e;val n=names e;val i=identity e
    in execution= #execution n andalso request= #request i andalso slot= #slot i andalso
      #profile cost= #profile n andalso #code_generation cost= #code n andalso
      #operation cost= #operation n andalso #step cost= #step n andalso
      #units cost= #cost p andalso inputs=[#parameter n]end;
  fun supports(Execute e)[F.PureRun run]=pure_matches e run
    |supports _ commands=null commands;
  fun is_support(Support _)=true|is_support _=false;
  fun phase_view phase={execution=SearchCodec.execution phase,reason=SearchCodec.reason phase,
    stopped=(case phase of SearchCodec.Pending _=>NONE|_=>SOME(stop_name phase))};
  fun expected_request event=
    let val e=event_entry event;val Entry{phase,...}=e;
      val actual=case event of Reserve _=>SearchCodec.Pending NONE|
        Execute _=>SearchCodec.Pending(SOME(#execution(names e)))|
        Stopped(_,stopped)=>stopped|_=>Synchronized.value phase
    in {names=projection e,control=names e,dependencies=dependencies e,phase=phase_view actual}end;
  fun expected_output event=
    let val e=event_entry event;val native=case event of Evidence(_,w)=> #dependencies(SearchGate.project w)|
      Publish(_,w)=> #dependencies(SearchGate.project w)|RestoredOutput(_,w)=> #dependencies(SearchGate.project w)|
      RestoredHistory(_,h)=> #native(SearchOutput.history_projection h)|_=>error "No search proof association"
    in {names=projection e,control=names e,dependencies=dependencies e,
      native=native}end;
  fun depends id(e as Entry{observed,...})=
    member(op =)(F.search_control_values(projection e)(names e)@dependencies e@Synchronized.value observed)id;
  fun deny(e as Entry{control,request,...})=(Control.deny control;
    (Option.app(fn request=>Option.app(RequestScope.deny o RequestScope.parent)(SearchRequest.native_scope request))request
      handle ERROR _=>()));
  fun release_execution(e as Entry{roots,job,monitor,witness,proof_scope,control,packet,...})=
    (Option.app SearchWorker.request_cancel(Synchronized.value job);
     (* The monitor owns W.join's one-shot result. Cancel the actual worker and
        let that monitor finish/drain it; interrupting its join loses ownership. *)
     Option.app(fn task=>ignore(Future.join_result task))
       (Synchronized.value monitor);
     Option.app(fn running=>let val output=SearchWorker.join running
       in SearchWorker.release_output output end)(Synchronized.value job);
     Synchronized.change job(K NONE);Synchronized.change monitor(K NONE);
     Option.app SearchGate.release(Synchronized.value witness);Synchronized.change witness(K NONE);
     P.abort_scope proof_scope;
     (case roots of Fresh source=>SearchSource.release source|HistoricalOnly=>()|
       Recovered{receiver,pscope,qscope,instance}=>
         (SearchRequest.abort_scope qscope;P.abort_scope pscope;SearchCore.release_instance instance;
          SearchReceiver.release receiver));
     Synchronized.change packet(K NONE);Control.mark_released control);
  fun release(e as Entry{history,...})=
    (release_execution e;Option.app SearchOutput.history_release(Synchronized.value history);
     Synchronized.change history(K NONE));
  fun remove_released()=Synchronized.change entries(filter(fn(_,Entry{control,history,...})=>
    not(Control.released control)orelse is_some(Synchronized.value history)));
  fun retirement_registrations()=
    let fun owned(_,e as Entry{observed,...})=
      let val p=projection e;val n=names e;
        (* The installed public receiver belongs to the resident context owner,
           not to one search. Forget must leave that selected context usable.
           Fresh proof generations belong to this entry's witness only. *)
        val original=filter(fn id=>id<> #receiver p andalso id<> #parameter n andalso id<> #output n)
          (F.search_control_values p n);
        val proof=filter(fn id=>not(member(op =)(dependencies e)id))(Synchronized.value observed)
      in map(fn id=>[F.search_intrinsic_frame id])(original@proof)end
    in distinct(op =)(maps owned(Synchronized.value entries))end;
end;
