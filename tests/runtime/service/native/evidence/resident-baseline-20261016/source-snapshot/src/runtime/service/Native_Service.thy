theory Native_Service
  imports Veri7vn_Authority_Codec.Authority_Codec
    Veri7vn_Admission_Metadata.Admission_Metadata
    Veri7vn_Interpretation.Veri7vn_Rendering
    Veri7vn_Natural_Mathematics.Natural_Mathematics
    Veri7vn_Controlled_Templates.Checked_Statements
    Veri7vn_Mathematics_Ticket_Execution.Mathematics_Ticket_Execution
    Veri7vn_Refined_Templates.Refined_Template_Bridge
begin
definition service_attach_native_evidence :: "nat \<Rightarrow> claim \<Rightarrow> nat list \<Rightarrow> event" where
  "service_attach_native_evidence eid c deps = AttachEvidence
    \<lparr>evidence_id=eid, evidence_claim=c, evidence_route=KernelConsequence,
      evidence_managed_dependencies=eid#deps\<rparr>"
definition service_evidence_only_checkpoint :: "authority_state \<Rightarrow> bool" where
  "service_evidence_only_checkpoint s =
    (s\<lparr>evidence_table:=[], revision:=0, authority_epoch:=0,
      revoked_objects:=[], forgotten_objects:=[], retired_capabilities:=[],
      retired_sources:=[]\<rparr> = initial_state)"
definition service_evidence_matches :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_evidence_matches s ev = (case ev of AttachEvidence e \<Rightarrow>
    e \<in> set (required_native_evidence s) | _ \<Rightarrow> False)"

text \<open>Fixed resident mathematics bridge. These builders are used only after
native request elaboration and the fixed worker's same-request output association.
They are metadata constructors, not proofs of arbitrary caller-selected claims.\<close>
record service_math_names =
  sm_request :: nat
  sm_goal :: nat
  sm_interpretation :: nat
  sm_capability :: nat
  sm_operation :: nat
  sm_profile :: nat
  sm_step :: nat
  sm_template :: nat
  sm_claim :: nat
  sm_parameter :: nat
  sm_input :: nat
  sm_slot :: nat
  sm_code :: nat
  sm_semantic :: nat

definition service_math_names :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> service_math_names" where
  "service_math_names rid gid iid cap operation profile step_id target cid parameter input slot code semantic =
    \<lparr>sm_request=rid,sm_goal=gid,sm_interpretation=iid,sm_capability=cap,
      sm_operation=operation,sm_profile=profile,sm_step=step_id,sm_template=target,
      sm_claim=cid,sm_parameter=parameter,sm_input=input,sm_slot=slot,
      sm_code=code,sm_semantic=semantic\<rparr>"
definition service_math_requirement :: "service_math_names \<Rightarrow> nat list \<Rightarrow> claim" where
  "service_math_requirement n deps =
    \<lparr>claim_id=sm_claim n,target_id=sm_template n,interpretation_id=sm_interpretation n,
      claim_kind=Mathematical,claim_modality=Asserted,collection_scope=Scalar,
      claim_optimality=Unspecified,premises=[],dependencies=deps,
      semantic_generation=sm_semantic n,executable_generation=ExecutableGeneration (sm_code n)\<rparr>"
definition service_math_input :: "service_math_names \<Rightarrow> nat list \<Rightarrow> event" where
  "service_math_input n deps = RegisterManaged
    \<lparr>retained_id=sm_input n,retained_owner=RequestLocal (sm_request n),
      retained_dependencies=filter (\<lambda>d. d\<noteq>sm_input n) deps,retained_read_dependencies=[],retained_access_requirements=[],
      retained_payload=sm_input n\<rparr>"
definition service_math_parameter :: "service_math_names \<Rightarrow> nat list \<Rightarrow> event" where
  "service_math_parameter n deps = RegisterManaged
    \<lparr>retained_id=sm_parameter n,retained_owner=RequestLocal (sm_request n),
      retained_dependencies=filter (\<lambda>d. d\<noteq>sm_parameter n) deps,
      retained_read_dependencies=[sm_input n],retained_access_requirements=[],
      retained_payload=sm_parameter n\<rparr>"
definition service_math_statement_code :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_statement_code n bridge code = RegisterManaged
    \<lparr>retained_id=code,retained_owner=WorkspaceShared,
      retained_dependencies=[sm_semantic n,bridge],retained_read_dependencies=[],
      retained_access_requirements=[],retained_payload=code\<rparr>"
definition service_math_bridge :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_bridge n bridge code = RegisterManaged
    \<lparr>retained_id=bridge,retained_owner=WorkspaceShared,
      retained_dependencies=[sm_semantic n,sm_code n,code],retained_read_dependencies=[code],
      retained_access_requirements=[],retained_payload=bridge\<rparr>"
definition service_registration_present :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_registration_present s ev = (case ev of RegisterManaged v \<Rightarrow>
    v\<in>set (retained_values s) \<and> accessible s (retained_id v # retained_dependencies v)
    | _ \<Rightarrow> False)"
definition service_math_reserve :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> event" where
  "service_math_reserve n prestate fuel deps = ReserveRequest
    \<lparr>request_id=sm_request n,request_generation=sm_semantic n,
      request_code_generation=sm_code n,request_prestate=prestate,
      request_dependencies=deps,allowed_routes=[RefinedExecution],permitted_effects=[],
      request_goals=[\<lparr>goal_id=sm_goal n,goal_interpretation=sm_interpretation n,
        goal_capability=sm_capability n,goal_dependencies=[],
        goal_required=service_math_requirement n deps,goal_output_slot=Some (sm_slot n),
        goal_outcome=AwaitingOutput (sm_slot n)\<rparr>],request_blockers=[],
      request_cancelled=False,request_fuel=fuel,request_session=None,
      request_observation=StateTimeUnused,request_retention_scopes=[RequestLocal (sm_request n)]\<rparr>
    [\<lparr>output_slot_id=sm_slot n,output_owner=sm_request n,output_goal=sm_goal n,
      output_template=sm_template n,output_profile=sm_profile n,
      output_inputs=[KnownInput (sm_parameter n)],output_input_identity=sm_parameter n,
      output_reserved_dependencies=deps,output_origin=PureOrigin\<rparr>]"
definition service_math_execute :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_execute n eid cost = ExecutePure
    \<lparr>execution_id=eid,execution_request=sm_request n,execution_slot=sm_slot n,
      execution_cost=\<lparr>cost_profile=sm_profile n,cost_code_generation=sm_code n,
        cost_operation=sm_operation n,cost_step=sm_step n,cost_units=cost\<rparr>,
      execution_inputs=[sm_parameter n]\<rparr>"
definition service_math_specialized :: "service_math_names \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> claim" where
  "service_math_specialized n deps cid target = (service_math_requirement n deps)
    \<lparr>claim_id:=cid,target_id:=target\<rparr>"
definition service_math_evidence :: "service_math_names \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_evidence n deps managed cid target eid = AttachEvidence
    \<lparr>evidence_id=eid,evidence_claim=service_math_specialized n deps cid target,
      evidence_route=RefinedExecution,evidence_managed_dependencies=eid#cid#target#sm_interpretation n#(managed@deps)\<rparr>"
definition service_math_publish :: "service_math_names \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_publish n deps managed cid target eid output execution batch = StageOutput batch
    \<lparr>assigned_slot=sm_slot n,assigned_requirement=service_math_specialized n deps cid target,
      assigned_premise_correspondence=[],assigned_output=output,assigned_lineage=execution,
      assigned_binding=\<lparr>binding_request=sm_request n,binding_goal=sm_goal n,
        binding_claim=service_math_specialized n deps cid target,binding_evidence=eid\<rparr>,
      assigned_dependencies=deps,
      assigned_retained=[\<lparr>retained_id=output,retained_owner=RequestLocal (sm_request n),
        retained_dependencies=managed@deps,
        retained_read_dependencies=[sm_parameter n],retained_access_requirements=[],retained_payload=output\<rparr>]\<rparr> None"
definition service_binding_live :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "service_binding_live s rid eid = (\<exists>b\<in>set (visible_bindings s).
    binding_request b=rid \<and> binding_evidence b=eid \<and> binding_licensed s b)"


definition service_required_math_requests :: "authority_state \<Rightarrow> nat list" where
  "service_required_math_requests s = map request_id
    (filter (\<lambda>r. accessible s (request_id r # request_dependencies r)) (requests s))"
definition service_math_request_matches ::
  "authority_state \<Rightarrow> service_math_names \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> bool" where
  "service_math_request_matches s n deps cost =
    (\<exists>r\<in>set (requests s). request_id r=sm_request n \<and>
      request_generation r=sm_semantic n \<and> request_code_generation r=sm_code n \<and>
      request_dependencies r=deps \<and> request_prestate r\<le>revision s \<and>
      allowed_routes r=[RefinedExecution] \<and> permitted_effects r=[] \<and>
      request_blockers r=[] \<and> request_session r=None \<and>
      request_observation r=StateTimeUnused \<and>
      request_retention_scopes r=[RequestLocal (sm_request n)] \<and>
      (request_fuel r=0 \<or> request_fuel r=cost) \<and>
      map (\<lambda>g. g\<lparr>goal_outcome:=AwaitingOutput (sm_slot n)\<rparr>) (request_goals r) =
        [\<lparr>goal_id=sm_goal n,goal_interpretation=sm_interpretation n,
          goal_capability=sm_capability n,goal_dependencies=[],
          goal_required=service_math_requirement n deps,goal_output_slot=Some (sm_slot n),
          goal_outcome=AwaitingOutput (sm_slot n)\<rparr>] \<and>
      \<lparr>output_slot_id=sm_slot n,output_owner=sm_request n,output_goal=sm_goal n,
        output_template=sm_template n,output_profile=sm_profile n,
        output_inputs=[KnownInput (sm_parameter n)],output_input_identity=sm_parameter n,
        output_reserved_dependencies=deps,output_origin=PureOrigin\<rparr>\<in>set (output_slots s))"
definition service_math_output_matches :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_math_output_matches s ev = (case ev of StageOutput batch a None \<Rightarrow>
    (\<forall>old\<in>set (output_assignments s). assigned_slot old=assigned_slot a \<longrightarrow> old=a) \<and>
    (\<forall>b\<in>set (visible_bindings s). binding_evidence b=binding_evidence (assigned_binding a)
      \<longrightarrow> b=assigned_binding a) | _ \<Rightarrow> False)"
definition service_execution_for :: "authority_state \<Rightarrow> nat \<Rightarrow> pure_execution list" where
  "service_execution_for s rid = filter (\<lambda>run. execution_request run=rid) (pure_executions s)"
definition service_restore_supported :: "authority_state \<Rightarrow> bool" where
  "service_restore_supported s = (pending_batch s=None \<and> attempts s=[] \<and>
    source_publications s=[] \<and> acquisition_jobs s=[] \<and> session_views s=[] \<and>
    current_observations s=[] \<and> retention_grants s=[] \<and> consumed_retention_grants s=[] \<and>
    exposure_history s=[] \<and> qualification_eligibility s=[] \<and> spent_domains s=[] \<and>
    qualification_reservations s=[] \<and> qualification_started s=[] \<and>
    qualification_policies s=[] \<and> qualifications s=[] \<and> package_publications s=[] \<and>
    (\<forall>e\<in>set (required_native_evidence s). evidence_route e\<noteq>EvaluationOracle))"

ML_file \<open>metadata_frame.ML\<close>
ML_file \<open>../../isabelle/language/natural/native_language_input.ML\<close>
ML_file \<open>../../isabelle/language/request/native_interpreted_request.ML\<close>
ML_file \<open>../../isabelle/language/emission/refined/native_refined_math_display.ML\<close>
ML_file \<open>../../isabelle/admission/native_authority_descriptor.ML\<close>
ML_file \<open>../../isabelle/admission/recovery/native_recovery_export.ML\<close>
ML_file \<open>native_math_gate.ML\<close>
ML_file \<open>native_math_recovery.ML\<close>
ML_file \<open>native_state_owner.ML\<close>
ML_file \<open>native_service.ML\<close>
end
