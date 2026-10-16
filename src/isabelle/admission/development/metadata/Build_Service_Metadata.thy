theory Build_Service_Metadata
  imports Veri7vn_Native_Build_Candidate.Native_Build_Candidate Veri7vn_Authority.Veri7vn_Authority
begin
text \<open>Fixed metadata constructors for the private native build owner. Native
source and candidate associations are obtained from opaque builder handles before
calling these functions. These functions do not validate decoded ownership labels.
RequestLocal scope is not a Forget edge; control, source, input and parent edges
are explicit retained dependencies.\<close>
record build_service_control =
  bsc_request :: nat
  bsc_goal :: nat
  bsc_slot :: nat
  bsc_parameter :: nat
  bsc_generation :: nat
  bsc_code :: nat
  bsc_output :: nat
  bsc_execution :: nat

definition build_service_control :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> build_service_control" where
  "build_service_control build_rid_arg build_gid_arg build_slot_arg build_parameter_arg build_generation_arg build_code_arg build_output_arg build_execution_arg =
    \<lparr>bsc_request=build_rid_arg,bsc_goal=build_gid_arg,bsc_slot=build_slot_arg,bsc_parameter=build_parameter_arg,
      bsc_generation=build_generation_arg,bsc_code=build_code_arg,bsc_output=build_output_arg,bsc_execution=build_execution_arg\<rparr>"
definition build_service_intrinsic :: "nat \<Rightarrow> event" where
  "build_service_intrinsic build_identity_arg = RegisterManaged
    \<lparr>retained_id=build_identity_arg,retained_owner=WorkspaceShared,retained_dependencies=[],
      retained_read_dependencies=[],retained_access_requirements=[],retained_payload=build_identity_arg\<rparr>"
definition build_service_parameter :: "build_service_control \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow>
    observation_requirement list \<Rightarrow> event" where
  "build_service_parameter n build_parent_arg build_original_arg build_owned_closure_arg build_reads_arg build_access_arg = RegisterManaged
    \<lparr>retained_id=bsc_parameter n,retained_owner=RequestLocal (bsc_request n),
      retained_dependencies=remdups (filter (\<lambda>d. d\<noteq>bsc_parameter n)
        ([bsc_request n,bsc_goal n,bsc_slot n] @ goal_references build_original_arg @ request_dependencies build_parent_arg @ build_owned_closure_arg @ build_reads_arg)),
      retained_read_dependencies=remdups build_reads_arg,retained_access_requirements=build_access_arg,
      retained_payload=bsc_parameter n\<rparr>"
definition build_service_artifact_dependencies :: "build_service_control \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> artifact_requirement \<Rightarrow>
    nat \<Rightarrow> nat list \<Rightarrow> nat list" where
  "build_service_artifact_dependencies n build_parent_arg build_original_arg build_required_arg build_native_generation_arg build_owned_closure_arg =
    remdups ([bsc_output n,build_native_generation_arg,bsc_request n,bsc_goal n,bsc_slot n,
      bsc_generation n,bsc_code n] @ goal_references build_original_arg @ request_dependencies build_parent_arg @ artifact_requirement_references build_required_arg @ build_owned_closure_arg)"
definition build_service_artifact :: "build_service_control \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> artifact_requirement \<Rightarrow>
    nat \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> retention_scope \<Rightarrow>
    observation_requirement list \<Rightarrow> event" where
  "build_service_artifact n build_parent_arg build_original_arg build_required_arg build_native_generation_arg build_owned_closure_arg build_inputs_arg build_scope_arg build_access_arg =
    (let deps=build_service_artifact_dependencies n build_parent_arg build_original_arg build_required_arg build_native_generation_arg (build_owned_closure_arg @ build_inputs_arg);
      value=\<lparr>retained_id=bsc_output n,retained_owner=build_scope_arg,
        retained_dependencies=filter (\<lambda>d. d\<noteq>bsc_output n) deps,
        retained_read_dependencies=remdups build_inputs_arg,retained_access_requirements=build_access_arg,
        retained_payload=bsc_output n\<rparr>
    in StageOutput (bsc_output n) (ArtifactOutput \<lparr>artifact_assigned_slot=bsc_slot n,
      artifact_assigned_request=bsc_request n,artifact_assigned_goal=bsc_goal n,
      artifact_assigned_requirement=build_required_arg,
      artifact_assigned_output=bsc_output n,artifact_assigned_generation=build_native_generation_arg,
      artifact_assigned_lineage=bsc_execution n,
      artifact_assigned_dependencies=deps,artifact_assigned_retained=[value]\<rparr>) None)"
record build_service_plan =
  bsp_control :: build_service_control
  bsp_interpretation :: nat
  bsp_capability :: nat
  bsp_operation :: nat
  bsp_step :: nat

definition build_service_plan :: "build_service_control \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> build_service_plan" where
  "build_service_plan build_control_arg build_interpretation_arg build_capability_arg build_operation_arg build_step_arg =
    \<lparr>bsp_control=build_control_arg,bsp_interpretation=build_interpretation_arg,bsp_capability=build_capability_arg,
      bsp_operation=build_operation_arg,bsp_step=build_step_arg\<rparr>"
definition build_service_requirement :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow>
    slot_input list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> artifact_requirement" where
  "build_service_requirement build_template_arg build_source_arg build_revision_arg build_manifest_arg build_parents_arg build_profile_arg build_setup_arg build_exports_arg =
    \<lparr>artifact_template=build_template_arg,artifact_source=build_source_arg,artifact_revision=build_revision_arg,
      artifact_manifest=build_manifest_arg,artifact_parents=build_parents_arg,artifact_profile=build_profile_arg,
      artifact_setup=build_setup_arg,artifact_exports=build_exports_arg\<rparr>"
definition build_service_child :: "build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow>
    goal_dependency list \<Rightarrow> subgoal" where
  "build_service_child build_plan_arg build_required_arg build_predecessors_arg =
    (let n=bsp_control build_plan_arg in \<lparr>goal_id=bsc_goal n,goal_interpretation=bsp_interpretation build_plan_arg,
      goal_capability=bsp_capability build_plan_arg,goal_dependencies=build_predecessors_arg,
      goal_required=ArtifactRequirement build_required_arg,goal_generation=bsc_generation n,
      goal_code_generation=bsc_code n,goal_output_slot=Some (bsc_slot n),
      goal_outcome=AwaitingOutput (bsc_slot n)\<rparr>)"
definition build_service_slot :: "build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow>
    nat list \<Rightarrow> output_slot" where
  "build_service_slot build_plan_arg build_required_arg build_reserved_arg =
    (let n=bsp_control build_plan_arg in \<lparr>output_slot_id=bsc_slot n,output_owner=bsc_request n,
      output_goal=bsc_goal n,output_template=artifact_template build_required_arg,
      output_profile=artifact_profile build_required_arg,
      output_inputs=KnownInput (bsc_parameter n) # artifact_parents build_required_arg,
      output_input_identity=bsc_parameter n,output_reserved_dependencies=build_reserved_arg,
      output_origin=PureOrigin\<rparr>)"
definition build_service_execute :: "build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow>
    nat list \<Rightarrow> event" where
  "build_service_execute build_plan_arg build_required_arg build_inputs_arg =
    (let n=bsp_control build_plan_arg in ExecutePure \<lparr>execution_id=bsc_execution n,
      execution_request=bsc_request n,execution_slot=bsc_slot n,
      execution_cost=\<lparr>cost_profile=artifact_profile build_required_arg,cost_code_generation=bsc_code n,
        cost_operation=bsp_operation build_plan_arg,cost_step=bsp_step build_plan_arg,cost_units=1\<rparr>,
      execution_inputs=build_inputs_arg\<rparr>)"

definition build_service_parent_heads_match :: "authority_state \<Rightarrow> (nat \<times> nat) list \<Rightarrow> bool" where
  "build_service_parent_heads_match s build_parents_arg = list_all (\<lambda>(build_candidate_arg,build_generation_arg).
    \<exists>a\<in>set (artifact_assignments s). artifact_assigned_output a=build_candidate_arg \<and>
      artifact_assigned_generation a=build_generation_arg \<and> artifact_accessible s a) build_parents_arg"

definition build_service_retained_request_matches :: "authority_state \<Rightarrow> build_service_plan \<Rightarrow>
    artifact_requirement \<Rightarrow> nat list \<Rightarrow> bool" where
  "build_service_retained_request_matches s build_plan_arg build_required_arg build_inputs_arg =
    (let n=bsp_control build_plan_arg in \<exists>r\<in>set (requests s). request_id r=bsc_request n \<and>
      request_observation r=StateTimeUnused \<and> request_session r=None \<and> parent_accessible s r \<and>
      (\<exists>g\<in>set (request_goals r). goal_id g=bsc_goal n \<and>
        goal_interpretation g=bsp_interpretation build_plan_arg \<and> goal_capability g=bsp_capability build_plan_arg \<and>
        goal_generation g=bsc_generation n \<and> goal_code_generation g=bsc_code n \<and> child_accessible s g \<and>
        goal_output_slot g=Some (bsc_slot n) \<and>
        (case goal_required g of ClaimRequirement c \<Rightarrow> False | ArtifactRequirement build_original_arg \<Rightarrow>
          resolved_artifact_requirement s build_original_arg=Some build_required_arg)) \<and>
      (\<exists>x\<in>set (output_slots s). output_slot_id x=bsc_slot n \<and>
        output_owner x=bsc_request n \<and> output_goal x=bsc_goal n \<and>
        output_template x=artifact_template build_required_arg \<and> output_profile x=artifact_profile build_required_arg \<and>
        output_input_identity x=bsc_parameter n \<and> output_origin x=PureOrigin \<and>
        resolved_inputs s (output_inputs x)=Some build_inputs_arg \<and>
        build_inputs_arg\<noteq>[] \<and> hd build_inputs_arg=bsc_parameter n \<and>
        map KnownInput (tl build_inputs_arg)=artifact_parents build_required_arg))"

definition build_service_request_matches :: "authority_state \<Rightarrow> build_service_plan \<Rightarrow>
    artifact_requirement \<Rightarrow> nat list \<Rightarrow> bool" where
  "build_service_request_matches s build_plan_arg build_required_arg build_inputs_arg =
    (build_service_retained_request_matches s build_plan_arg build_required_arg build_inputs_arg \<and>
      (\<exists>r\<in>set (requests s). request_id r=bsc_request (bsp_control build_plan_arg) \<and> \<not>request_cancelled r))"

definition build_service_paid_matches :: "authority_state \<Rightarrow> build_service_plan \<Rightarrow>
    artifact_requirement \<Rightarrow> nat list \<Rightarrow> bool" where
  "build_service_paid_matches s build_plan_arg build_required_arg build_inputs_arg =
    (\<exists>run\<in>set (pure_executions s). ExecutePure run=build_service_execute build_plan_arg build_required_arg build_inputs_arg)"

definition build_service_candidate_matches :: "authority_state \<Rightarrow> build_service_plan \<Rightarrow>
    artifact_requirement \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> (nat \<times> nat) list \<Rightarrow> bool" where
  "build_service_candidate_matches s build_plan_arg build_required_arg build_inputs_arg build_generation_arg build_parents_arg =
    (build_service_retained_request_matches s build_plan_arg build_required_arg build_inputs_arg \<and>
      build_service_paid_matches s build_plan_arg build_required_arg build_inputs_arg \<and> build_service_parent_heads_match s build_parents_arg \<and>
      map (KnownInput \<circ> fst) build_parents_arg=artifact_parents build_required_arg \<and>
      (let n=bsp_control build_plan_arg in \<exists>a\<in>set (artifact_assignments s).
        artifact_assigned_request a=bsc_request n \<and> artifact_assigned_goal a=bsc_goal n \<and>
        artifact_assigned_slot a=bsc_slot n \<and> artifact_assigned_output a=bsc_output n \<and>
        artifact_assigned_lineage a=bsc_execution n \<and> artifact_assigned_generation a=build_generation_arg \<and>
        artifact_assigned_requirement a=build_required_arg \<and> artifact_accessible s a))"

definition build_service_failure_matches :: "authority_state \<Rightarrow> build_service_plan \<Rightarrow>
    artifact_requirement \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> bool" where
  "build_service_failure_matches s build_plan_arg build_required_arg build_inputs_arg build_reason_arg =
    (build_service_retained_request_matches s build_plan_arg build_required_arg build_inputs_arg \<and>
      build_service_paid_matches s build_plan_arg build_required_arg build_inputs_arg \<and>
      (let n=bsp_control build_plan_arg in \<exists>r\<in>set (requests s). request_id r=bsc_request n \<and>
        (\<exists>g\<in>set (request_goals r). goal_id g=bsc_goal n \<and> goal_outcome g=Failed build_reason_arg)))"

definition build_service_native_plan :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow>
    nat \<Rightarrow> nat \<Rightarrow> build_service_plan option" where
  "build_service_native_plan s build_rid_arg build_gid_arg build_slot_arg build_execution_arg build_candidate_arg =
    (case filter (\<lambda>r. request_id r=build_rid_arg) (requests s) of [r] \<Rightarrow>
      (case filter (\<lambda>g. goal_id g=build_gid_arg \<and> goal_output_slot g=Some build_slot_arg) (request_goals r) of [g] \<Rightarrow>
        (case filter (\<lambda>x. output_slot_id x=build_slot_arg \<and> output_owner x=build_rid_arg \<and> output_goal x=build_gid_arg)
            (output_slots s) of [x] \<Rightarrow>
          (case filter (\<lambda>run. execution_id run=build_execution_arg \<and> execution_request run=build_rid_arg \<and>
              execution_slot run=build_slot_arg) (pure_executions s) of [run] \<Rightarrow>
            (if cost_units (execution_cost run)=1 \<and>
                cost_code_generation (execution_cost run)=goal_code_generation g then
              Some (build_service_plan
                (build_service_control build_rid_arg build_gid_arg build_slot_arg (output_input_identity x) (goal_generation g)
                  (goal_code_generation g) build_candidate_arg build_execution_arg)
                (goal_interpretation g) (goal_capability g) (cost_operation (execution_cost run))
                (cost_step (execution_cost run))) else None)
            | _ \<Rightarrow> None)
          | _ \<Rightarrow> None)
        | _ \<Rightarrow> None)
      | _ \<Rightarrow> None)"

end
