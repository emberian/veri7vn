(* Include once before the resident gate datatype. This table owns native
   handles only; the existing Owner remains the sole authority-state owner. *)
structure BuildResident =
struct
  structure B=NativeBuild.Builder;
  structure Requests=Veri7vn_Native_Build_Request_Restore(
    structure Builder=B structure Request=DevelopmentRecovery.Request);
  type request_view={metadata:Veri7vn_Native_Development_Codec.metadata,
    payload:Veri7vn_Native_Development_Codec.payload,
    request:Veri7vn_Native_Build_Request_Envelope.packet};
  type output_view={metadata:Veri7vn_Native_Development_Codec.metadata,
    payload:Veri7vn_Native_Development_Codec.payload};
  datatype restored=Restored of {request:Requests.restored,key:NativeBuild.key,
    request_view:request_view,output:NativeBuild.OutputOwner.lease option Synchronized.var,
    output_view:output_view option Synchronized.var,active:bool Synchronized.var};
  datatype entry=Entry of {native:NativeBuild.entry,prestate:IntInf.int,
    dependencies:IntInf.int list,registrations:IntInf.int list,reason:IntInf.int,
    candidate:NativeBuild.CandidateOwner.lease option Synchronized.var,
    output:NativeBuild.OutputOwner.lease option Synchronized.var,
    failure:Veri7vn_Native_Build_Terminal.failure option Synchronized.var,
    request_view:request_view option Synchronized.var,
    output_view:output_view option Synchronized.var,
    monitor:unit Future.future option Synchronized.var};
  datatype event=Intrinsic of entry*IntInf.int*IntInf.int list |
    Reserve of entry | Parameter of entry | Execute of entry |
    Artifact of entry | Outcome of entry*Veri7vn_Native_Build_Terminal.failure |
    RestoredRequest of restored | RestoredArtifact of restored;
  val entries=Synchronized.var "veri7vn_resident_builds"
    ([]:(NativeBuild.key*entry)list);
  val restored_entries=Synchronized.var "veri7vn_restored_builds"
    ([]:(NativeBuild.key*restored)list);
  fun native(Entry{native,...})=native;
  fun names entry=NativeBuild.names(native entry);
  fun key entry=NativeBuild.key(native entry);
  fun lookup key=AList.lookup(op =)(Synchronized.value entries)key;
  fun event_entry(Intrinsic(e,_,_))=e | event_entry(Reserve e)=e |
    event_entry(Parameter e)=e | event_entry(Execute e)=e |
    event_entry(Artifact e)=e | event_entry(Outcome(e,_))=e |
    event_entry _=error "Restored Build has no executable entry";
  fun restored_key(Restored{key,...})=key;
  fun restored_live(Restored{request,active,...})=Synchronized.value active andalso Requests.is_live request;
  fun request(RestoredRequest r)= #1(restored_key r)
    |request(RestoredArtifact r)= #1(restored_key r)
    |request event= #request(names(event_entry event));
  fun prepared entry=NativeBuild.prepared(native entry);
  fun projection entry=B.prepared_projection(prepared entry);
  fun required entry=F.build_requirement(projection entry);
  fun inputs entry=B.prepared_inputs(prepared entry);
  fun source_reads entry=let val p=projection entry
    in distinct(op =)(#source_owner p:: #parents p)end;
  fun plan entry=NativeBuild.request_plan(native entry);
  fun candidate(Entry{candidate,...})=case Synchronized.value candidate of
    SOME lease=>NativeBuild.CandidateOwner.candidate lease
    | NONE=>error "Native build has no owned completed candidate";
  fun acknowledged(Entry{output,...})=case Synchronized.value output of
    SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false;
  fun live(RestoredRequest r)=restored_live r
    |live(RestoredArtifact(Restored{output,...}))=
      (case Synchronized.value output of SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false)
    |live(Artifact e)=B.is_live(candidate e) andalso
      (acknowledged e orelse NativeBuild.live(native e))
    |live event=NativeBuild.live(native(event_entry event));
  fun frame(Intrinsic(_,id,_)) _=F.build_intrinsic_frame id
    | frame(Reserve(e as Entry{prestate,dependencies,...})) _=
        F.build_reserve_frame(names e)(required e)prestate 1 dependencies
    | frame(Parameter(e as Entry{prestate,dependencies,...})) _=
        F.build_singleton_parameter_frame(names e)(required e)prestate dependencies
          (B.prepared_parent_dependencies(prepared e))(source_reads e)[]
    | frame(Execute e) _=F.build_execute_frame(names e)(required e)(inputs e)
    | frame(Artifact(e as Entry{prestate,dependencies,...})) _=
        let val output=candidate e
          val generation=I.generation_id(identity_allocator())(P.generation(B.development output))
        in F.build_singleton_artifact_frame(names e)(required e)prestate dependencies
          generation(B.retention_dependencies output)(inputs e)[] end
    | frame(Outcome(e,failure)) _=F.build_outcome_frame(names e)(#reason failure)
    | frame _ _=error "Restored Build association is not an event";
  fun pure_matches e ({execution,request,slot,cost,inputs=actual}:F.pure_run)=
    let val n=names e;val p=projection e
    in execution= #execution n andalso request= #request n andalso slot= #slot n andalso
      #profile cost= #profile p andalso #code_generation cost= #code_generation n andalso
      #operation cost= #operation n andalso #step cost= #step n andalso #units cost=1 andalso
      actual=inputs e end;
  fun supports(Execute e)[F.PureRun run]=pure_matches e run
    | supports(Execute _) _=false
    | supports _ commands=null commands;
  fun binding event=
    let val e=event_entry event;val n=names e
      val prepared_id=case NativeBuild.inspect(native e)of
        NativeBuild.Status view=> #prepared_input view | NativeBuild.Unavailable=>0
      val phase=case event of Reserve _=>"reserve" | Execute _=>"execute" |
        Artifact _=>"artifact" | Outcome _=>"outcome" | _=>"reserve"
    in (phase,prepared_id,#request n,#goal n,#slot n)end;
  fun publish entry=Synchronized.change entries(fn all=>
    (F.guard(length all<8192 andalso is_none(AList.lookup(op =)all(key entry)))
       "Native Build request ownership bound or duplicate";
     (key entry,entry)::all));
  fun depends id(e as Entry{dependencies,registrations,output_view,...})=
    let val n=names e
      val completed=case Synchronized.value output_view of NONE=>[]
        |SOME{metadata,...}=> #semantic_generation metadata:: #candidate metadata:: #dependencies metadata
    in member(op =)(completed @ dependencies @ registrations @
      [#request n,#goal n,#slot n,#interpretation n,#decision n,#parameter n,
       #candidate n,#execution n,#capability n,#step n,#operation n,
       #code_generation n,#semantic_generation n])id end;
  fun is_support(Intrinsic _)=true|is_support _=false;
  fun restored_depends id(Restored{request_view={metadata,request,...},output_view,...})=
    let val p= #plan request
      val output_dependencies=case Synchronized.value output_view of
        NONE=>[]|SOME{metadata,...}=> #candidate metadata:: #semantic_generation metadata:: #dependencies metadata
    in member(op =)(output_dependencies @ #dependencies metadata @
      [#request p,#goal p,#slot p,#interpretation p,#decision p,#parameter p,#candidate p,
       #execution p,#template p,#profile p,#setup p,#capability p,#operation p,
       #code_generation p,#operation_generation p,#step p])id end;
  fun deny_restored(Restored{active,...})=Synchronized.change active(K false);
  fun restored_acknowledged(Restored{output,...})=case Synchronized.value output of
    SOME lease=>NativeBuild.OutputOwner.is_live lease|NONE=>false;
  fun expected_request(RestoredRequest(Restored{request_view,...}))=request_view
    |expected_request(RestoredArtifact(Restored{request_view,...}))=request_view
    |expected_request event=
    let val Entry{request_view,...}=event_entry event
    in case Synchronized.value request_view of SOME view=>view
      |NONE=>error "Native Build request material not prepared"end;
  fun expected_output(RestoredArtifact(Restored{output_view,...}))=
      (case Synchronized.value output_view of SOME view=>view
        |NONE=>error "Restored Build output material unavailable")
    |expected_output event=
    let val Entry{output_view,...}=event_entry event
    in case Synchronized.value output_view of SOME view=>view
      |NONE=>error "Native Build artifact material not prepared"end;
  (* Keep the table association until every destructor succeeds, so failed
     cleanup still has a retryable owning root. Joins run outside Owner. *)
  fun release(entry as Entry{native,candidate,output,monitor,...})=
    let val _=NativeBuild.cancel native
      val _=Option.app(fn task=>ignore(Future.join_result task))(Synchronized.value monitor)
      val _=Option.app NativeBuild.OutputOwner.release(Synchronized.value output)
      val _=Synchronized.change output(K NONE)
      val _=Option.app NativeBuild.CandidateOwner.release(Synchronized.value candidate)
      val _=Synchronized.change candidate(K NONE)
      val _=NativeBuild.release_entry native
    in Synchronized.change entries(AList.delete(op =)(key entry))end;
  fun retire_prepared(Entry{native,monitor,...})=
    (NativeBuild.cancel native;
     Option.app(fn task=>ignore(Future.join_result task))(Synchronized.value monitor);
     NativeBuild.release_entry native);
  fun release_restored(r as Restored{request,output,...})=
    let val _=deny_restored r
      val _=Option.app NativeBuild.OutputOwner.release(Synchronized.value output)
      val _=Synchronized.change output(K NONE)
      val _=Requests.release request
    in Synchronized.change restored_entries(AList.delete(op =)(restored_key r))end;
end;
