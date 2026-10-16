(* Paste in the EXISTING Veri7vn_Metadata_Frame generated unit after encode_event.
   Never ML_file separately: these terms must share the reducer carrier universe.
   Only actual private Build/Scope handles or C-checked witnesses supply snapshots. *)
type build_control_names={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
  interpretation:IntInf.int,decision:IntInf.int,parameter:IntInf.int,candidate:IntInf.int,
  execution:IntInf.int,capability:IntInf.int,step:IntInf.int,operation:IntInf.int,
  code_generation:IntInf.int,semantic_generation:IntInf.int};
type build_native_projection={template:IntInf.int,source_owner:IntInf.int,source_revision:IntInf.int,
  manifest:IntInf.int,parents:IntInf.int list,profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,
  candidate:IntInf.int,lineage:IntInf.int,dependencies:IntInf.int list};
fun build_control(n:build_control_names)=
  (guard(forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)
    [#request n,#goal n,#slot n,#interpretation n,#decision n,#parameter n,#candidate n,
     #execution n,#capability n,#step n,#operation n,#code_generation n,#semantic_generation n])
     "Build control identity";
   @{code build_service_control}(nat(#request n))(nat(#goal n))(nat(#slot n))(nat(#parameter n))
     (nat(#semantic_generation n))(nat(#code_generation n))(nat(#candidate n))(nat(#execution n)));
fun build_plan(n:build_control_names)=
  @{code build_service_plan}(build_control n)(nat(#interpretation n))(nat(#capability n))
    (nat(#operation n))(nat(#step n));
fun build_requirement(p:build_native_projection)=
  @{code build_service_requirement}(nat(#template p))(nat(#source_owner p))(nat(#source_revision p))
    (nat(#manifest p))(map(fn id=> @{code KnownInput}(nat id)) (#parents p))
    (nat(#profile p))(nat(#setup p))(nat(#export_intent p));
fun build_deferred_requirement(p:Veri7vn_Native_Deferred_Build_Types.plan)=
  let val source= #source p
    fun parent(Veri7vn_Native_Deferred_Build_Types.Installed _)=NONE
      |parent(Veri7vn_Native_Deferred_Build_Types.KnownCandidate{candidate,...})=
        SOME(@{code KnownInput}(nat candidate))
      |parent(Veri7vn_Native_Deferred_Build_Types.ReservedOutput{slot,...})=
        SOME(@{code ReservedOutput}(nat slot))
  in @{code build_service_requirement}(nat(#template p))(nat(#source_owner source))
    (nat(#source_revision source))(nat(#manifest source))(map_filter parent(#parents p))
    (nat(#profile p))(nat(#setup p))(nat(#export_intent source))end;
fun build_intrinsic_frame id=(guard(id>0) "Build intrinsic identity";
  encode_event(@{code build_service_intrinsic}(nat id)));
fun build_parent_identity (n:build_control_names) parent original=
  guard(integer(@{code request_id}parent)= #request n andalso
    member(op =)(@{code request_goals}parent)original andalso
    integer(@{code goal_id}original)= #goal n andalso
    integer(@{code goal_interpretation}original)= #interpretation n andalso
    integer(@{code goal_capability}original)= #capability n andalso
    integer(@{code goal_generation}original)= #semantic_generation n andalso
    integer(@{code goal_code_generation}original)= #code_generation n andalso
    @{code goal_output_slot}original=SOME(nat(#slot n))) "Build original parent/child differs";
fun build_parameter_frame n parent original closure reads accesses=
  (build_parent_identity n parent original;encode_event(@{code build_service_parameter}(build_control n)parent original(map nat closure)(map nat reads)accesses));
fun build_child n required predecessor_goals=
  @{code build_service_child}(build_plan n)required
    (map(fn id=> @{code ArtifactDependency}(nat id))predecessor_goals);
fun build_slot n required reserved=
  @{code build_service_slot}(build_plan n)required(map nat reserved);
fun build_execute_frame n required inputs=
  encode_event(@{code build_service_execute}(build_plan n)required(map nat inputs));
fun build_artifact_frame n parent original required native_generation closure inputs scope accesses=
  (build_parent_identity n parent original;
   encode_event(@{code build_service_artifact}(build_control n)parent original required(nat native_generation)
     (map nat closure)(map nat inputs)scope accesses));
fun build_request_matches state n required inputs=
  @{code build_service_request_matches}state(build_plan n)required(map nat inputs);
fun build_retained_request_matches state n required inputs=
  @{code build_service_retained_request_matches}state(build_plan n)required(map nat inputs);
fun build_paid_matches state n required inputs=
  @{code build_service_paid_matches}state(build_plan n)required(map nat inputs);
fun build_candidate_matches state n required inputs native_generation parents=
  @{code build_service_candidate_matches}state(build_plan n)required(map nat inputs)(nat native_generation)
    (map(fn(candidate,generation)=>(nat candidate,nat generation))parents);
fun build_failure_matches state n required inputs reason=
  @{code build_service_failure_matches}state(build_plan n)required(map nat inputs)(nat reason);
(* Candidate-role metadata lacks decision/operation names by design. Query the
   SINGLE actual original child/slot/paid run; never fabricate a decision ID. *)
fun build_native_plan state (m:Veri7vn_Native_Development_Codec.metadata)=
  @{code build_service_native_plan}state(nat(#request m))(nat(#goal m))(nat(#slot m))
    (nat(#lineage m))(nat(#candidate m));
fun build_native_candidate_matches state (m:Veri7vn_Native_Development_Codec.metadata) parents=
  case build_native_plan state m of NONE=>false|SOME plan=>
    let val required= @{code build_service_requirement}(nat(#template m))(nat(#source_owner m))
      (nat(#source_revision m))(nat(#manifest m))(map(fn id=> @{code KnownInput}(nat id)) (#parents m))
      (nat(#profile m))(nat(#setup m))(nat(#export_intent m))
    in integer(@{code bsc_generation}(@{code bsp_control}plan))= #charged_generation m andalso
      @{code build_service_candidate_matches}state plan required(map nat(#input_bindings m))
      (nat(#semantic_generation m))(map(fn(id,context)=>(nat id,nat context))parents)end;
fun build_native_control_values state m=
  Option.map(fn plan=>let val n= @{code bsp_control}plan
    in map integer [@{code bsp_interpretation}plan,@{code bsp_capability}plan,
      @{code bsp_operation}plan,@{code bsp_step}plan,@{code bsc_code}n,
      @{code bsc_generation}n,@{code bsc_parameter}n]end)(build_native_plan state m);
