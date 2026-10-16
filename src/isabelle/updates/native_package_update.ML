(* Closed native package update owner. Service assembly alone joins this owner to
   generated events, charged qualification start and the durable writer. A client
   cannot create an owner from decoded metadata or supply a successful observation. *)
functor Veri7vn_Native_Package_Update
  (structure Builder: VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Qualification: VERI7VN_PACKAGE_QUALIFICATION
   structure Recovery:VERI7VN_CHECKED_UPDATE_QUALIFICATION_REQUEST
   sharing type Recovery.candidate=Builder.candidate
   sharing type Qualification.candidate=Builder.candidate) :>
sig
  type pending
  type qualified
  type job
  type context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,interpretation:IntInf.int,
    run_spec:IntInf.int,policy:IntInf.int,policy_resource:IntInf.int,
    exposure:IntInf.int,structural_metric:IntInf.int,count_metric:IntInf.int,
    unit_id:IntInf.int,executable_generation:IntInf.int,slot:IntInf.int,
    previous:IntInf.int option}
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,
    contract:IntInf.int,attempt:IntInf.int,qualification:IntInf.int,
    observation:IntInf.int,semantic_generation:IntInf.int}
  type projection={context:context,names:names,candidate:Builder.projection,
    baseline:Builder.projection,dependencies:IntInf.int list,profile:string}
  val prepare: Veri7vn_Native_Identity_Allocator.allocator -> context ->
    {candidate:Builder.candidate,baseline:Builder.candidate} -> pending
  val restore:Recovery.checked -> pending
  val pending_snapshot:pending -> Veri7vn_Pending_Qualification_Types.update
  val reservation: pending -> projection
  (* Called only after the service consumes its exact generated
     ExposeQualification command and durably acknowledges start/exposure. *)
  val measure_started: pending -> qualified
  val start_after_ack: pending -> job
  val cancel: job -> unit
  val join: job -> qualified Exn.result
  val finished: job -> bool
  val result: qualified -> projection * int
  val exports: qualified -> Veri7vn_Managed_Provenance.consequence list
  val expected_exports:qualified -> (Thm_Name.T * Veri7vn_Native_Sequent.snapshot) list
  val is_live: pending -> bool
  val failed: pending -> bool
  val release: pending -> unit
end =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  structure Q=Qualification;
  type context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,interpretation:IntInf.int,
    run_spec:IntInf.int,policy:IntInf.int,policy_resource:IntInf.int,
    exposure:IntInf.int,structural_metric:IntInf.int,count_metric:IntInf.int,
    unit_id:IntInf.int,executable_generation:IntInf.int,slot:IntInf.int,
    previous:IntInf.int option};
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,
    contract:IntInf.int,attempt:IntInf.int,qualification:IntInf.int,
    observation:IntInf.int,semantic_generation:IntInf.int};
  type projection={context:context,names:names,candidate:Builder.projection,
    baseline:Builder.projection,dependencies:IntInf.int list,profile:string};
  type payload={candidate:Builder.candidate,baseline:Builder.candidate,
    contract:Q.contract,projection:projection,recovered:Recovery.checked option};
  fun live_payload({candidate,baseline,contract,...}:payload)=
    Builder.is_live candidate andalso Builder.is_live baseline andalso Q.contract_live contract;
  structure Worker=Veri7vn_Qualification_Worker(
    type input=payload type observation=Q.observation
    val input_live=live_payload val observation_live=Q.is_live
    val measure=fn({candidate,contract,...}:payload)=>Q.measure contract candidate
    val release_input=fn({contract,recovered,...}:payload)=>(Q.release_contract contract;Option.app Recovery.release recovered)
    val release_observation=Q.release);
  type pending=Worker.pending;
  type qualified=Worker.qualified;
  type job=Worker.job;
  fun require true _=() | require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun prepare allocator (context:context) {candidate,baseline}=
    let
      val _=require(Builder.is_live candidate andalso Builder.is_live baseline)
        "Package update candidate/baseline unavailable";
      val _=require(I.workspace allocator=P.development_workspace(Builder.development candidate)
        andalso I.workspace allocator=P.development_workspace(Builder.development baseline))
        "Package update workspace mismatch";
      val _=require(forall positive [#request context,#goal context,#request_slot context,#interpretation context,
        #run_spec context,#policy context,#policy_resource context,#exposure context,
        #structural_metric context,#count_metric context,#unit_id context,
        #executable_generation context,#slot context] andalso
        (case #previous context of NONE=>true | SOME n=>positive n)) "Package update identity bounds";
      val _=require(#structural_metric context<> #count_metric context)
        "Package update metric identities collide";
      val _=require(#request_slot context<> #slot context) "Qualification request/publication slot collision";
      val candidate_projection=Builder.projection candidate;
      val baseline_projection=Builder.projection baseline;
      val _=require(#candidate candidate_projection<> #candidate baseline_projection)
        "Structural update requires an independent retained baseline";
      val _=require(case #previous context of NONE=>false | SOME previous=>
        previous= #candidate baseline_projection) "Package update baseline/current slot mismatch";
      val names={claim=I.allocate allocator,target=I.allocate allocator,evidence=I.allocate allocator,
        contract=I.allocate allocator,attempt=I.allocate allocator,qualification=I.allocate allocator,
        observation=I.allocate allocator,semantic_generation=N.semantic_generation_id allocator
          (Q.observer_generation)};
      val candidate_generation=N.semantic_generation_id allocator(Builder.native_generation candidate);
      val baseline_generation=N.semantic_generation_id allocator(Builder.native_generation baseline);
      val dependencies=distinct(op =)([#request_slot context,#candidate candidate_projection,#candidate baseline_projection,
        #contract names,#observation names,#run_spec context,#policy context,#policy_resource context,
        #exposure context,#executable_generation context,#interpretation context,#semantic_generation names,
        candidate_generation,baseline_generation] @
        #dependencies candidate_projection @ #dependencies baseline_projection);
      val _=require(length dependencies<=8192) "Package update dependency bounds";
      val contract=Q.retain_baseline_contract baseline;
      val projection={context=context,names=names,candidate=candidate_projection,
        baseline=baseline_projection,dependencies=dependencies,profile=Q.profile};
      val result=Exn.capture Worker.create
        {candidate=candidate,baseline=baseline,contract=contract,projection=projection,recovered=NONE}
    in case result of Exn.Res pending=>pending | Exn.Exn exn=>
      (Q.release_contract contract;Exn.reraise exn) end;
  fun restore checked=
    let
      val _=require(Recovery.is_live checked andalso
        Veri7vn_Executable_Identity.same(Recovery.executable checked,Q.executable))
        "Update pending recovery code/owner mismatch";
      val {candidate,baseline,snapshot,phase}=Recovery.binding checked;
      val projection:projection={context= #context snapshot,names= #names snapshot,
        candidate= #candidate snapshot,baseline= #baseline snapshot,
        dependencies= #dependencies snapshot,profile= #profile snapshot};
      val retained=Recovery.retain checked;
      val contract=(case Exn.capture Q.retain_baseline_contract baseline of Exn.Res value=>value
        | Exn.Exn exn=>(Recovery.release retained;Exn.reraise exn));
      val input={candidate=candidate,baseline=baseline,contract=contract,projection=projection,recovered=SOME retained};
      val create=case phase of Veri7vn_Pending_Qualification_Types.QualificationStarted=>Worker.create_interrupted
        | _=>Worker.create;
    in case Exn.capture create input of Exn.Res pending=>pending
      | Exn.Exn exn=>(Q.release_contract contract;Recovery.release retained;Exn.reraise exn) end;
  fun pending_snapshot pending=
    let val {projection,contract,...}=Worker.input pending
    in {request_slot= #request_slot(#context projection),context= #context projection,names= #names projection,
      candidate= #candidate projection,baseline= #baseline projection,profile= #profile projection,
      dependencies= #dependencies projection,expected_exports=Q.expected_exports contract}
      :Veri7vn_Pending_Qualification_Types.update end;
  fun reservation pending= #projection(Worker.input pending);
  val is_live=Worker.is_live;
  val failed=Worker.failed;
  val measure_started=Worker.measure_started;
  val start_after_ack=Worker.start_after_ack;
  val cancel=Worker.cancel;
  val join=Worker.join;
  val finished=Worker.finished;
  fun result qualified=let val (payload,observation)=Worker.result qualified
    in (#projection payload,Q.count observation) end;
  fun expected_exports qualified=let val ({contract,...},_)=Worker.result qualified
    in Q.expected_exports contract end;
  fun exports qualified=Q.checked_exports(#2(Worker.result qualified));
  val release=Worker.release;
end;
