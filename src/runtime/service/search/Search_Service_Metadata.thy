theory Search_Service_Metadata
  imports Veri7vn_Search_Service.Search_Service Veri7vn_Authority.Veri7vn_Authority
    Veri7vn_Native_Lifetime.Native_Lifetime
begin
text \<open>Closed metadata for the first native literal-proposition profile.
Mathematical denotes a kernel-checked HOL proposition, with no numerical-result
interpretation. Only the protected source and proof gates supply these identities;
the definitions neither parse a proposition nor establish its truth. The original
receiver, source, interpretation and whole target remain immutable.\<close>

record search_service_control =
  ssc_request :: nat
  ssc_goal :: nat
  ssc_slot :: nat
  ssc_interpretation :: nat
  ssc_decision :: nat
  ssc_semantic :: nat
  ssc_input :: nat
  ssc_capability :: nat
  ssc_operation :: nat
  ssc_profile :: nat
  ssc_step :: nat
  ssc_template :: nat
  ssc_claim :: nat
  ssc_parameter :: nat
  ssc_execution :: nat
  ssc_code :: nat
  ssc_evidence :: nat
  ssc_output :: nat
  ssc_batch :: nat
  ssc_exhausted :: nat
  ssc_budget :: nat
  ssc_deadline :: nat
  ssc_cancelled :: nat
  ssc_failed :: nat

definition search_service_control :: "nat list \<Rightarrow> search_service_control" where
  "search_service_control ns =
    \<lparr>ssc_request=ns!0,ssc_goal=ns!1,ssc_slot=ns!2,ssc_interpretation=ns!3,
      ssc_decision=ns!4,ssc_semantic=ns!5,ssc_input=ns!6,ssc_capability=ns!7,
      ssc_operation=ns!8,ssc_profile=ns!9,ssc_step=ns!10,ssc_template=ns!11,
      ssc_claim=ns!12,ssc_parameter=ns!13,ssc_execution=ns!14,ssc_code=ns!15,
      ssc_evidence=ns!16,ssc_output=ns!17,ssc_batch=ns!18,ssc_exhausted=ns!19,
      ssc_budget=ns!20,ssc_deadline=ns!21,ssc_cancelled=ns!22,ssc_failed=ns!23\<rparr>"

definition search_service_requirement :: "search_service_control \<Rightarrow> nat list \<Rightarrow> claim" where
  "search_service_requirement n deps =
    \<lparr>claim_id=ssc_claim n,target_id=ssc_template n,interpretation_id=ssc_interpretation n,
      claim_kind=Mathematical,claim_modality=Asserted,collection_scope=Scalar,
      claim_optimality=Unspecified,premises=[],dependencies=deps,
      semantic_generation=ssc_semantic n,executable_generation=ExecutableGeneration (ssc_code n)\<rparr>"

definition search_service_intrinsic :: "nat \<Rightarrow> event" where
  "search_service_intrinsic identity = RegisterManaged
    \<lparr>retained_id=identity,retained_owner=WorkspaceShared,retained_dependencies=[],
      retained_read_dependencies=[],retained_access_requirements=[],retained_payload=identity\<rparr>"

definition search_service_parameter :: "search_service_control \<Rightarrow> nat list \<Rightarrow> event" where
  "search_service_parameter n owned = RegisterManaged
    \<lparr>retained_id=ssc_parameter n,retained_owner=RequestLocal (ssc_request n),
      retained_dependencies=remdups (filter (\<lambda>d. d\<noteq>ssc_parameter n)
        ([ssc_request n,ssc_goal n,ssc_slot n,ssc_interpretation n,ssc_decision n,ssc_input n] @ owned)),
      retained_read_dependencies=[ssc_input n],retained_access_requirements=[],retained_payload=ssc_parameter n\<rparr>"

definition search_service_child :: "search_service_control \<Rightarrow> nat list \<Rightarrow> subgoal" where
  "search_service_child n deps =
    \<lparr>goal_id=ssc_goal n,goal_interpretation=ssc_interpretation n,goal_capability=ssc_capability n,
      goal_dependencies=[],goal_required=ClaimRequirement (search_service_requirement n deps),
      goal_generation=ssc_semantic n,goal_code_generation=ssc_code n,goal_output_slot=Some (ssc_slot n),
      goal_outcome=AwaitingOutput (ssc_slot n)\<rparr>"

definition search_service_slot :: "search_service_control \<Rightarrow> nat list \<Rightarrow> output_slot" where
  "search_service_slot n deps =
    \<lparr>output_slot_id=ssc_slot n,output_owner=ssc_request n,output_goal=ssc_goal n,
      output_template=ssc_template n,output_profile=ssc_profile n,output_inputs=[KnownInput (ssc_parameter n)],
      output_input_identity=ssc_parameter n,output_reserved_dependencies=deps,output_origin=PureOrigin\<rparr>"

definition search_service_reserve :: "search_service_control \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> event" where
  "search_service_reserve n prestate cost deps = ReserveRequest
    \<lparr>request_id=ssc_request n,request_generation=ssc_semantic n,request_code_generation=ssc_code n,
      request_prestate=prestate,request_dependencies=deps,allowed_routes=[KernelConsequence],permitted_effects=[],
      request_goals=[search_service_child n deps],request_blockers=[],request_cancelled=False,
      request_fuel=cost,request_session=None,request_observation=StateTimeUnused,
      request_retention_scopes=[RequestLocal (ssc_request n)]\<rparr> [search_service_slot n deps]"

definition search_service_execute :: "search_service_control \<Rightarrow> nat \<Rightarrow> event" where
  "search_service_execute n cost = ExecutePure
    \<lparr>execution_id=ssc_execution n,execution_request=ssc_request n,execution_slot=ssc_slot n,
      execution_cost=\<lparr>cost_profile=ssc_profile n,cost_code_generation=ssc_code n,
        cost_operation=ssc_operation n,cost_step=ssc_step n,cost_units=cost\<rparr>,
      execution_inputs=[ssc_parameter n]\<rparr>"

definition search_service_output_dependencies :: "search_service_control \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "search_service_output_dependencies n deps native = remdups
    ([ssc_output n,ssc_execution n,ssc_parameter n] @ deps @ native)"

definition search_service_evidence :: "search_service_control \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> event" where
  "search_service_evidence n deps native = AttachEvidence
    \<lparr>evidence_id=ssc_evidence n,evidence_claim=search_service_requirement n (search_service_output_dependencies n deps native),
      evidence_route=KernelConsequence,evidence_managed_dependencies=remdups
        ([ssc_evidence n,ssc_claim n,ssc_template n,ssc_interpretation n,ssc_request n,ssc_goal n,ssc_slot n] @
          search_service_output_dependencies n deps native)\<rparr>"

definition search_service_publish :: "search_service_control \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> event" where
  "search_service_publish n deps native = StageOutput (ssc_batch n)
    (ClaimOutput \<lparr>assigned_slot=ssc_slot n,
      assigned_requirement=search_service_requirement n (search_service_output_dependencies n deps native),
      assigned_premise_correspondence=[],assigned_output=ssc_output n,assigned_lineage=ssc_execution n,
      assigned_binding=\<lparr>binding_request=ssc_request n,binding_goal=ssc_goal n,
        binding_claim=search_service_requirement n (search_service_output_dependencies n deps native),binding_evidence=ssc_evidence n\<rparr>,
      assigned_dependencies=search_service_output_dependencies n deps native,
      assigned_retained=[\<lparr>retained_id=ssc_output n,retained_owner=RequestLocal (ssc_request n),
        retained_dependencies=remdups
          ([ssc_evidence n,ssc_claim n,ssc_template n,ssc_interpretation n,ssc_request n,ssc_goal n,ssc_slot n] @
            search_service_output_dependencies n deps native),
        retained_read_dependencies=[ssc_parameter n],retained_access_requirements=[],retained_payload=ssc_output n\<rparr>]\<rparr>) None"

datatype search_service_stop = SearchExhausted | SearchBudget | SearchDeadline | SearchCancelled | SearchFailed
definition search_service_stopped :: "search_service_control \<Rightarrow> search_service_stop \<Rightarrow> event" where
  "search_service_stopped n stopped = SetOutcome (ssc_request n) (ssc_goal n)
    (case stopped of SearchExhausted \<Rightarrow> Inconclusive (ssc_exhausted n)
      | SearchBudget \<Rightarrow> Inconclusive (ssc_budget n)
      | SearchDeadline \<Rightarrow> Inconclusive (ssc_deadline n)
      | SearchCancelled \<Rightarrow> Declined (ssc_cancelled n)
      | SearchFailed \<Rightarrow> Failed (ssc_failed n))"

definition search_service_request_matches :: "authority_state \<Rightarrow> search_service_control \<Rightarrow>
    nat list \<Rightarrow> nat \<Rightarrow> bool" where
  "search_service_request_matches s n deps cost =
    (\<exists>r\<in>set (requests s). request_id r=ssc_request n \<and>
      request_generation r=ssc_semantic n \<and> request_code_generation r=ssc_code n \<and>
      request_dependencies r=deps \<and> request_prestate r\<le>revision s \<and> request_fuel r\<le>cost \<and>
      allowed_routes r=[KernelConsequence] \<and> permitted_effects r=[] \<and> request_blockers r=[] \<and>
      request_session r=None \<and> request_observation r=StateTimeUnused \<and>
      request_retention_scopes r=[RequestLocal (ssc_request n)] \<and>
      map (\<lambda>g. g\<lparr>goal_outcome:=AwaitingOutput (ssc_slot n)\<rparr>) (request_goals r)=[search_service_child n deps] \<and>
      filter (\<lambda>x. output_owner x=ssc_request n) (output_slots s)=[search_service_slot n deps])"

definition search_service_execution_matches :: "authority_state \<Rightarrow> search_service_control \<Rightarrow>
    nat \<Rightarrow> bool \<Rightarrow> bool" where
  "search_service_execution_matches s n cost consumed =
    (case search_service_execute n cost of ExecutePure expected \<Rightarrow>
      filter (\<lambda>run. execution_request run=ssc_request n \<and> execution_slot run=ssc_slot n)
        (pure_executions s)=(if consumed then [expected] else []) \<and>
      (\<exists>r\<in>set (requests s). request_id r=ssc_request n \<and>
        request_fuel r=(if consumed then 0 else cost))
    | _ \<Rightarrow> False)"

definition search_service_stopped_matches :: "authority_state \<Rightarrow> search_service_control \<Rightarrow>
    search_service_stop \<Rightarrow> bool" where
  "search_service_stopped_matches s n stopped =
    (\<exists>r\<in>set (requests s). request_id r=ssc_request n \<and>
      (\<exists>g\<in>set (request_goals r). goal_id g=ssc_goal n \<and>
        (if request_cancelled r then stopped=SearchCancelled \<and> goal_outcome g=Cancelled
         else case search_service_stopped n stopped of SetOutcome rid gid out \<Rightarrow> goal_outcome g=out
           | _ \<Rightarrow> False)))"

definition search_service_output_matches :: "authority_state \<Rightarrow> search_service_control \<Rightarrow>
    nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "search_service_output_matches s n deps native =
    (case search_service_publish n deps native of StageOutput batch (ClaimOutput a) None \<Rightarrow>
      a\<in>set (claim_assignments s) \<and> assigned_binding a\<in>set (visible_bindings s) \<and>
      (case search_service_evidence n deps native of AttachEvidence e \<Rightarrow>
        e\<in>set (required_native_evidence s) | _ \<Rightarrow> False)
    | _ \<Rightarrow> False)"

lemma search_service_proposition_assurance:
  "claim_kind (search_service_requirement n deps) = Mathematical"
  "premises (search_service_requirement n deps) = []"
  "semantic_generation (search_service_requirement n deps) = ssc_semantic n"
  "interpretation_id (search_service_requirement n deps) = ssc_interpretation n"
  by (simp_all add: search_service_requirement_def)
lemma search_service_output_preserves_scope:
  "scope_preserved (search_service_requirement n deps)
    (search_service_requirement n (search_service_output_dependencies n deps native)) []"
  by (auto simp: scope_preserved_def same_target_def search_service_requirement_def
      search_service_output_dependencies_def list_all_iff)
ML_file "native_search_request_checkpoint.ML"
end
