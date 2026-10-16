(* Initial activation owner. Only fixed service assembly may turn this native
   owner into the corresponding generated initial-admission gates/events. *)
functor Veri7vn_Native_Initial_Package
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Admission:VERI7VN_INITIAL_PACKAGE_ADMISSION
   structure Recovery:VERI7VN_CHECKED_INITIAL_QUALIFICATION_REQUEST
   sharing type Recovery.candidate=Builder.candidate
   sharing type Recovery.intent=Intent.intent
   sharing type Builder.export_intent=Intent.intent
   sharing type Admission.intent=Intent.intent
   sharing type Admission.candidate=Builder.candidate) :>
sig
  type pending
  type qualified
  type job
  type context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,interpretation:IntInf.int,
    run_spec:IntInf.int,policy:IntInf.int,policy_resource:IntInf.int,exposure:IntInf.int,
    acceptance_metric:IntInf.int,count_metric:IntInf.int,unit_id:IntInf.int,
    executable_generation:IntInf.int,slot:IntInf.int}
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,contract:IntInf.int,
    attempt:IntInf.int,qualification:IntInf.int,observation:IntInf.int,semantic_generation:IntInf.int}
  type intent_projection={source_owner:IntInf.int,source_revision:IntInf.int,
    manifest:IntInf.int,export_intent:IntInf.int,dependencies:IntInf.int list}
  type projection={context:context,names:names,candidate:Builder.projection,
    intent:intent_projection,dependencies:IntInf.int list,profile:string}
  val prepare:Veri7vn_Managed_Provenance.construction_scope ->
    Veri7vn_Native_Identity_Allocator.allocator -> context ->
    {candidate:Builder.candidate,intent:Intent.intent} -> pending
  val restore:Veri7vn_Managed_Provenance.construction_scope -> Recovery.checked -> pending
  val pending_snapshot:pending -> Veri7vn_Pending_Qualification_Types.initial
  val reservation:pending -> projection
  val is_live:pending -> bool
  val failed:pending -> bool
  val measure_started:pending -> qualified
  val start_after_ack:pending -> job
  val cancel:job -> unit
  val join:job -> qualified Exn.result
  val finished:job -> bool
  val result:qualified -> projection * int
  val exports:qualified -> Veri7vn_Managed_Provenance.consequence list
  val release:pending -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure N=Veri7vn_Native_Descriptor;
  structure Q=Admission;
  type context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,interpretation:IntInf.int,
    run_spec:IntInf.int,policy:IntInf.int,policy_resource:IntInf.int,exposure:IntInf.int,
    acceptance_metric:IntInf.int,count_metric:IntInf.int,unit_id:IntInf.int,
    executable_generation:IntInf.int,slot:IntInf.int};
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,contract:IntInf.int,
    attempt:IntInf.int,qualification:IntInf.int,observation:IntInf.int,semantic_generation:IntInf.int};
  type intent_projection={source_owner:IntInf.int,source_revision:IntInf.int,
    manifest:IntInf.int,export_intent:IntInf.int,dependencies:IntInf.int list};
  type projection={context:context,names:names,candidate:Builder.projection,
    intent:intent_projection,dependencies:IntInf.int list,profile:string};
  type payload={candidate:Builder.candidate,intent:Intent.intent,projection:projection,recovered:Recovery.checked option};
  structure Worker=Veri7vn_Qualification_Worker(
    type input=payload type observation=Q.observation
    val input_live=fn({candidate,intent,...}:payload)=>Builder.is_live candidate andalso Intent.is_live intent
    val observation_live=Q.is_live
    val measure=fn({candidate,intent,...}:payload)=>Q.measure intent candidate
    val release_input=fn({intent,recovered,...}:payload)=>(Intent.release intent;Option.app Recovery.release recovered)
    val release_observation=Q.release);
  type pending=Worker.pending;
  type qualified=Worker.qualified;
  type job=Worker.job;
  fun require true _=() | require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun prepare scope allocator (context:context) {candidate,intent}=
    let
      val _=require(Builder.is_live candidate andalso Intent.is_live intent andalso
        Intent.same(intent,Builder.original_intent candidate)) "Initial package requires original pre-build intent";
      val _=require(Intent.workspace intent=I.workspace allocator andalso
        P.development_workspace(Builder.development candidate)=I.workspace allocator)
        "Initial package workspace mismatch";
      val _=require(forall positive [#request context,#goal context,#request_slot context,#interpretation context,
        #run_spec context,#policy context,#policy_resource context,#exposure context,
        #acceptance_metric context,#count_metric context,#unit_id context,
        #executable_generation context,#slot context] andalso
        #acceptance_metric context<> #count_metric context) "Initial package identity bounds";
      val _=require(not(null(Intent.theorem_names intent)) andalso null(Intent.executable_locators intent))
        "Unsupported initial package profile: requires nonempty logical exports only";
      val original=Intent.binding intent;
      val _=require(#request_slot context<> #slot context) "Qualification request/publication slot collision";
      val candidate_projection=Builder.projection candidate;
      val _=require(#source_revision original= #source_revision candidate_projection andalso
        #manifest original= #manifest candidate_projection andalso
        #export_intent original= #export_intent candidate_projection) "Initial package source association mismatch";
      val intent_projection={source_owner=P.source_identity(#source original),
        source_revision= #source_revision original,manifest= #manifest original,
        export_intent= #export_intent original,dependencies= #dependencies original};
      val names={claim=I.allocate allocator,target=I.allocate allocator,evidence=I.allocate allocator,
        contract=I.allocate allocator,attempt=I.allocate allocator,qualification=I.allocate allocator,
        observation=I.allocate allocator,semantic_generation=N.semantic_generation_id allocator
          (Q.observer_generation)};
      val candidate_generation=N.semantic_generation_id allocator(Builder.native_generation candidate);
      val dependencies=distinct(op =)([#request_slot context,#candidate candidate_projection,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,
        #executable_generation context,#interpretation context,#semantic_generation names,candidate_generation,
        #source_owner intent_projection,#source_revision intent_projection,#manifest intent_projection,
        #export_intent intent_projection] @ #dependencies candidate_projection @ #dependencies intent_projection);
      val _=require(length dependencies<=8192) "Initial package dependency bounds";
      val retained=Intent.retain_owned scope intent;
      val projection={context=context,names=names,candidate=candidate_projection,intent=intent_projection,
        dependencies=dependencies,profile=Q.profile};
      val created=Exn.capture Worker.create {candidate=candidate,intent=retained,projection=projection,recovered=NONE};
    in case created of Exn.Res pending=>pending | Exn.Exn exn=>(Intent.release retained;Exn.reraise exn) end;
  fun restore scope checked=
    let
      val _=require(Recovery.is_live checked andalso
        Veri7vn_Executable_Identity.same(Recovery.executable checked,Q.executable))
        "Initial pending recovery code/owner mismatch";
      val {candidate,intent,snapshot,phase}=Recovery.binding checked;
      val original=Intent.binding intent;
      val projection:projection={context= #context snapshot,names= #names snapshot,candidate= #candidate snapshot,
        intent={source_owner=P.source_identity(#source original),source_revision= #source_revision original,
          manifest= #manifest original,export_intent= #export_intent original,dependencies= #dependencies original},
        dependencies= #dependencies snapshot,profile= #profile snapshot};
      val retained=Recovery.retain checked;
      val intent_owner=(case Exn.capture(Intent.retain_owned scope)intent of Exn.Res value=>value
        | Exn.Exn exn=>(Recovery.release retained;Exn.reraise exn));
      val input={candidate=candidate,intent=intent_owner,projection=projection,recovered=SOME retained};
      val create=case phase of Veri7vn_Pending_Qualification_Types.QualificationStarted=>Worker.create_interrupted
        | _=>Worker.create;
    in case Exn.capture create input of Exn.Res pending=>pending
      | Exn.Exn exn=>(Intent.release intent_owner;Recovery.release retained;Exn.reraise exn) end;
  fun pending_snapshot pending=
    let val {projection,...}=Worker.input pending
    in {request_slot= #request_slot(#context projection),context= #context projection,names= #names projection,
      candidate= #candidate projection,profile= #profile projection,
      dependencies= #dependencies projection}:Veri7vn_Pending_Qualification_Types.initial end;
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
  fun exports qualified=Q.checked_exports(#2(Worker.result qualified));
  val release=Worker.release;
end;
