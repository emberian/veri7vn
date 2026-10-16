theory Authority_Fixtures
  imports Veri7vn_Authority.Veri7vn_Authority
begin

definition fixture_claim :: claim where
  "fixture_claim = \<lparr>claim_id = 1, target_id = 2, interpretation_id = 3,
    claim_kind = Mathematical, claim_modality = Conditional,
    collection_scope = Scalar, claim_optimality = Unspecified,
    premises = [9], dependencies = [7, 10], semantic_generation = 4,
    executable_generation = ExecutableGeneration 5\<rparr>"

definition fixture_goal :: "subgoal" where
  "fixture_goal = \<lparr>goal_id = 6, goal_interpretation = 3,
    goal_capability = 7, goal_dependencies = [], goal_required = ClaimRequirement fixture_claim,
    goal_generation = 4, goal_code_generation = 5,
    goal_output_slot = None, goal_outcome = NeedsInput []\<rparr>"

definition fixture_request :: request where
  "fixture_request = \<lparr>request_id = 8, request_generation = 4,
    request_code_generation = 5, request_prestate = 0, request_dependencies = [10],
    allowed_routes = [KernelConsequence], permitted_effects = [],
    request_goals = [fixture_goal], request_blockers = [], request_cancelled = False,
    request_fuel = 10, request_session = None, request_observation = StateTimeUnused,
    request_retention_scopes = [RequestLocal 8]\<rparr>"

definition fixture_evidence :: evidence where
  "fixture_evidence = \<lparr>evidence_id = 11, evidence_claim = fixture_claim,
    evidence_route = KernelConsequence, evidence_managed_dependencies = [11,1,2,3,4,5,7,9,10]\<rparr>"

definition fixture_internal :: authority_state where
  "fixture_internal = fst (step
    (fst (step (fst (step initial_state (OpenRequest fixture_request)))
      (AttachEvidence fixture_evidence)))
    (SetOutcome 8 6 (Accepted fixture_claim 11)))"

definition fixture_staged :: authority_state where
  "fixture_staged = fst (step fixture_internal (StageClaim 12 8 6 11))"

lemmas fixture_defs = fixture_claim_def fixture_goal_def fixture_request_def
  fixture_evidence_def fixture_internal_def fixture_staged_def initial_state_def
  same_target_def licensed_def execution_fits_def accessible_def goal_ready_def unblocked_def
  request_fresh_def observation_fresh_def required_for_def evidence_accessible_def request_openable_def
  binding_licensed_def goal_ready_live_def parent_accessible_def child_accessible_def goal_references_def claim_references_def can_stage_def stage_def claim_assignments_def artifact_assignments_def Let_def

definition fixture_second_claim :: claim where
  "fixture_second_claim = fixture_claim\<lparr>claim_id := 14, interpretation_id := 4\<rparr>"

definition fixture_second_goal :: "subgoal" where
  "fixture_second_goal = fixture_goal\<lparr>goal_id := 13, goal_interpretation := 4,
    goal_dependencies := [LogicalDependency 6], goal_required := ClaimRequirement fixture_second_claim,
    goal_outcome := Accepted fixture_second_claim 15\<rparr>"

definition fixture_chain :: authority_state where
  "fixture_chain = fixture_internal\<lparr>requests := [fixture_request\<lparr>request_goals :=
    [fixture_goal\<lparr>goal_outcome := Accepted fixture_claim 11\<rparr>, fixture_second_goal]\<rparr>],
    evidence_table := [fixture_evidence, \<lparr>evidence_id = 15,
      evidence_claim = fixture_second_claim, evidence_route = KernelConsequence,
      evidence_managed_dependencies = [15,14,2,4,7,9,10]\<rparr>]\<rparr>"

definition fixture_blocked_chain :: authority_state where
  "fixture_blocked_chain = fst (step fixture_chain (AddBlocker 8
    \<lparr>blocked_scope = InterpretationScope 3, reason_id = 16, discharge_conditions = [17]\<rparr>))"

lemmas chain_defs = fixture_second_claim_def fixture_second_goal_def
  fixture_chain_def fixture_blocked_chain_def fixture_defs

definition fixture_source_claim :: claim where
  "fixture_source_claim = fixture_claim\<lparr>claim_kind := SourceObservation,
    dependencies := [7, 10, 19]\<rparr>"

definition fixture_source_state :: authority_state where
  "fixture_source_state = fixture_internal\<lparr>requests :=
    [fixture_request\<lparr>request_goals := [fixture_goal\<lparr>goal_required := ClaimRequirement fixture_source_claim,
      goal_outcome := Accepted fixture_source_claim 11\<rparr>]\<rparr>],
    evidence_table := [fixture_evidence\<lparr>evidence_claim := fixture_source_claim, evidence_managed_dependencies := [11,1,2,3,4,7,9,10,19]\<rparr>],
    attempts := [\<lparr>attempt_intent = \<lparr>attempt_id = 21, attempt_request = 8,
      attempt_target = 22, attempt_capability = 7, attempt_sources = [10],
      attempt_dependencies = [7, 10], attempt_prestate = 0,
      attempt_cost = \<lparr>cost_profile=30,cost_code_generation=5,cost_operation=31,cost_step=32,cost_units=1\<rparr>, attempt_job=None\<rparr>,
      attempt_state = Confirmed\<rparr>]\<rparr>"

definition fixture_observation :: source_publication where
  "fixture_observation = \<lparr>source_binding_id = 10, snapshot_id = 19, observation_attempt = 21, observation_job = None,
    observed_binding = \<lparr>binding_request = 8, binding_goal = 6,
      binding_claim = fixture_source_claim, binding_evidence = 11\<rparr>\<rparr>"

lemmas source_fixture_defs = fixture_source_claim_def fixture_source_state_def
  fixture_observation_def fixture_defs observation_permitted_def lifecycle_def

definition fixture_proof_only_claim :: claim where
  "fixture_proof_only_claim = fixture_claim\<lparr>executable_generation := NoExecution\<rparr>"

definition fixture_proof_only_state :: authority_state where
  "fixture_proof_only_state = fst (step
    (fst (step (fst (step initial_state (OpenRequest
      (fixture_request\<lparr>request_goals := [fixture_goal\<lparr>goal_required := ClaimRequirement fixture_proof_only_claim\<rparr>]\<rparr>))))
      (AttachEvidence (fixture_evidence\<lparr>evidence_claim := fixture_proof_only_claim, evidence_managed_dependencies :=
        filter (\<lambda>n. n \<noteq> 5) (evidence_managed_dependencies fixture_evidence)\<rparr>))))
    (SetOutcome 8 6 (Accepted fixture_proof_only_claim 11)))"

definition lease_clock_fixture :: clock_reading where
  "lease_clock_fixture = \<lparr>basis=Wall ''lease-clock'', ticks=100\<rparr>"

definition lease_context_fixture :: observation_context where
  "lease_context_fixture = \<lparr>observed_session=42,observed_version=0,
    evaluation_time=Some lease_clock_fixture,observed_reads=[(77,1)]\<rparr>"

definition lease_condition_fixture :: observation_requirement where
  "lease_condition_fixture = RequireAccess lease_context_fixture
    (Some \<lparr>fresh_from=lease_clock_fixture,fresh_through=200\<rparr>)"

definition slot_goal_fixture :: "subgoal" where
  "slot_goal_fixture = fixture_goal\<lparr>goal_required := ClaimRequirement (fixture_claim\<lparr>target_id := 14\<rparr>),
    goal_output_slot := Some 30, goal_outcome := AwaitingOutput 30\<rparr>"

definition slot_request_fixture :: request where
  "slot_request_fixture = fixture_request\<lparr>request_session := Some 42,
    request_retention_scopes := [RequestLocal 8, SessionLocal 42],
    allowed_routes := [RefinedExecution], request_goals := [slot_goal_fixture]\<rparr>"

definition slot_reservation_fixture :: output_slot where
  "slot_reservation_fixture = \<lparr>output_slot_id=30,output_owner=8,output_goal=6,
    output_template=14,output_profile=15,output_inputs=[KnownInput 13],output_input_identity=13,
    output_reserved_dependencies=[7,10,13,14,15],output_origin=PureOrigin\<rparr>"

definition slot_input_fixture :: retained_value where
  "slot_input_fixture = \<lparr>retained_id=13,retained_owner=RequestLocal 8,retained_dependencies=[77,42],
    retained_read_dependencies=[],retained_access_requirements=[lease_condition_fixture],retained_payload=13\<rparr>"

definition public_input_fixture :: retained_value where
  "public_input_fixture = slot_input_fixture\<lparr>retained_id:=300,retained_owner:=WorkspaceShared,
    retained_payload:=300,retained_dependencies:=[],retained_access_requirements:=[]\<rparr>"

definition slot_run_fixture :: pure_execution where
  "slot_run_fixture = \<lparr>execution_id=31,execution_request=8,execution_slot=30,
    execution_cost=\<lparr>cost_profile=15,cost_code_generation=5,cost_operation=16,cost_step=17,cost_units=1\<rparr>,
    execution_inputs=[13]\<rparr>"

definition slot_result_claim :: claim where
  "slot_result_claim = fixture_claim\<lparr>dependencies:=[7,9,10,13,14,15,19]\<rparr>"

definition slot_result_binding :: binding where
  "slot_result_binding = \<lparr>binding_request=8,binding_goal=6,binding_claim=slot_result_claim,binding_evidence=11\<rparr>"

definition slot_result_evidence :: evidence where
  "slot_result_evidence = \<lparr>evidence_id=11,evidence_claim=slot_result_claim,evidence_route=RefinedExecution,
    evidence_managed_dependencies=[11,1,2,3,4,5,7,9,10,13,14,15,19,100,77,42]\<rparr>"

definition slot_retained_result :: retained_value where
  "slot_retained_result = \<lparr>retained_id=19,retained_owner=RequestLocal 8,
    retained_dependencies=[11,1,2,3,4,5,7,9,10,13,14,15,19,100,77,42],retained_read_dependencies=[13],
    retained_access_requirements=[lease_condition_fixture],retained_payload=19\<rparr>"

definition slot_assignment_fixture :: output_assignment where
  "slot_assignment_fixture = \<lparr>assigned_slot=30,assigned_requirement=slot_result_claim,
    assigned_premise_correspondence=[(9,9)],assigned_output=19,assigned_lineage=31,
    assigned_binding=slot_result_binding,assigned_dependencies=[7,9,10,13,14,15,19],
    assigned_retained=[slot_retained_result]\<rparr>"

definition slot_ready_fixture :: authority_state where
  "slot_ready_fixture = fst (step (fst (step (fst (step (fst (step initial_state (UpdateObservation lease_context_fixture)))
    (ReserveRequest slot_request_fixture [slot_reservation_fixture])))
    (RegisterManaged slot_input_fixture))) (RegisterManaged public_input_fixture))"

definition slot_computed_fixture :: authority_state where
  "slot_computed_fixture = fst (step (fst (step slot_ready_fixture (ExecutePure slot_run_fixture)))
    (AttachEvidence slot_result_evidence))"

definition slot_published_fixture :: authority_state where
  "slot_published_fixture = fst (step (fst (step slot_computed_fixture
    (StageOutput 33 (ClaimOutput slot_assignment_fixture) None))) (DurableAck 33 1 0))"

definition missing_private_fixture :: output_assignment where
  "missing_private_fixture = slot_assignment_fixture\<lparr>assigned_retained :=
    [slot_retained_result\<lparr>retained_dependencies := filter (\<lambda>x. x \<noteq> 100)
      (retained_dependencies slot_retained_result)\<rparr>]\<rparr>"

definition slot_retention_grant_fixture :: retention_grant where
  "slot_retention_grant_fixture = \<lparr>retention_grant_id=50,retention_grant_owner=8,
    retention_grant_value=19,retention_grant_destination=SessionLocal 42,retention_policy_association=51,
    retention_grant_provenance=19#retained_dependencies slot_retained_result,
    retention_grant_observation=StateTimeUnused\<rparr>"

definition slot_promoted_fixture :: authority_state where
  "slot_promoted_fixture = fst (step (fst (step (fst (step slot_published_fixture
    (InstallRetentionGrant slot_retention_grant_fixture))) (StageRetention 34 8 19 (SessionLocal 42))))
    (DurableAck 34 2 0))"

definition slot_adopted_fixture :: authority_state where
  "slot_adopted_fixture = fst (step (fst (step slot_promoted_fixture
    (StageAdoption 35 8 \<lparr>adoption_request=8,adoption_session=42,adoption_expected_version=0,
      adoption_bindings=[slot_result_binding]\<rparr>))) (DurableAck 35 3 0))"

definition followup_fixture :: authority_state where
  "followup_fixture = slot_adopted_fixture\<lparr>requests := requests slot_adopted_fixture @
    [fixture_request\<lparr>request_id:=60,request_session:=Some 42\<rparr>,
     fixture_request\<lparr>request_id:=61,request_session:=Some 43\<rparr>]\<rparr>"

definition lease_changed_reads_fixture :: observation_context where
  "lease_changed_reads_fixture = lease_context_fixture\<lparr>observed_version:=1,observed_reads:=[(77,2)]\<rparr>"

definition lease_expired_fixture :: observation_context where
  "lease_expired_fixture = lease_context_fixture\<lparr>observed_version:=1,
    evaluation_time:=Some (lease_clock_fixture\<lparr>ticks:=201\<rparr>)\<rparr>"

definition unaffected_read_fixture :: observation_context where
  "unaffected_read_fixture = lease_context_fixture\<lparr>observed_version:=1,observed_reads:=[(78,1)]\<rparr>"

definition stale_cas_fixture :: observation_context where
  "stale_cas_fixture = unaffected_read_fixture\<lparr>observed_version:=0\<rparr>"

definition surviving_context_fixture :: observation_context where
  "surviving_context_fixture = lease_context_fixture\<lparr>observed_session:=43\<rparr>"

definition artifact_requirement_fixture :: artifact_requirement where
  "artifact_requirement_fixture = \<lparr>artifact_template=501,artifact_source=300,
    artifact_revision=502,artifact_manifest=503,artifact_parents=[],artifact_profile=504,
    artifact_setup=505,artifact_exports=506\<rparr>"

definition artifact_goal_fixture :: "subgoal" where
  "artifact_goal_fixture = fixture_goal\<lparr>goal_required:=ArtifactRequirement artifact_requirement_fixture,
    goal_output_slot:=Some 510,goal_outcome:=AwaitingOutput 510\<rparr>"

definition artifact_request_fixture :: request where
  "artifact_request_fixture = fixture_request\<lparr>request_goals:=[artifact_goal_fixture]\<rparr>"

definition artifact_parameter_fixture :: retained_value where
  "artifact_parameter_fixture = \<lparr>retained_id=530,retained_owner=RequestLocal 8,
    retained_dependencies=[8,300],retained_read_dependencies=[300],
    retained_access_requirements=[],retained_payload=530\<rparr>"

definition artifact_slot_fixture :: output_slot where
  "artifact_slot_fixture = \<lparr>output_slot_id=510,output_owner=8,output_goal=6,
    output_template=501,output_profile=504,output_inputs=[KnownInput 530],output_input_identity=530,
    output_reserved_dependencies=[530,8,300,501,502,503,504,505,506,4,5,7,10],output_origin=PureOrigin\<rparr>"

definition artifact_run_fixture :: pure_execution where
  "artifact_run_fixture = slot_run_fixture\<lparr>execution_slot:=510,
    execution_cost:=(execution_cost slot_run_fixture)\<lparr>cost_profile:=504\<rparr>,execution_inputs:=[530]\<rparr>"

definition artifact_retained_fixture :: retained_value where
  "artifact_retained_fixture = \<lparr>retained_id=520,retained_owner=RequestLocal 8,
    retained_dependencies=[530,8,701,300,501,502,503,504,505,506,4,5,7,10,6,510,3],
    retained_read_dependencies=[530],retained_access_requirements=[],retained_payload=520\<rparr>"

definition artifact_assignment_fixture :: artifact_assignment where
  "artifact_assignment_fixture = \<lparr>artifact_assigned_slot=510,artifact_assigned_request=8,
    artifact_assigned_goal=6,artifact_assigned_requirement=artifact_requirement_fixture,
    artifact_assigned_output=520,artifact_assigned_generation=701,artifact_assigned_lineage=31,
    artifact_assigned_dependencies=[520,530,8,701,300,501,502,503,504,505,506,4,5,7,10],
    artifact_assigned_retained=[artifact_retained_fixture]\<rparr>"

definition artifact_computed_fixture :: authority_state where
  "artifact_computed_fixture = fst (step (fst (step (fst (step (fst (step initial_state
    (RegisterManaged public_input_fixture)))
    (ReserveRequest artifact_request_fixture [artifact_slot_fixture])))
    (RegisterManaged artifact_parameter_fixture))) (ExecutePure artifact_run_fixture))"

definition artifact_missing_identity_fixture :: artifact_assignment where
  "artifact_missing_identity_fixture = artifact_assignment_fixture\<lparr>artifact_assigned_retained:=
    map (\<lambda>v. v\<lparr>retained_dependencies:=filter (\<lambda>d. d\<noteq>6) (retained_dependencies v)\<rparr>)
      (artifact_assigned_retained artifact_assignment_fixture)\<rparr>"

definition artifact_missing_owner_fixture :: authority_state where
  "artifact_missing_owner_fixture = artifact_computed_fixture\<lparr>requests:=[]\<rparr>"

definition artifact_ambiguous_owner_fixture :: authority_state where
  "artifact_ambiguous_owner_fixture = artifact_computed_fixture\<lparr>requests:=
    requests artifact_computed_fixture @ requests artifact_computed_fixture\<rparr>"

definition artifact_ambiguous_child_fixture :: authority_state where
  "artifact_ambiguous_child_fixture = artifact_computed_fixture\<lparr>requests:=map
    (\<lambda>r. r\<lparr>request_goals:=request_goals r @ request_goals r\<rparr>) (requests artifact_computed_fixture)\<rparr>"

definition artifact_ambiguous_slot_fixture :: authority_state where
  "artifact_ambiguous_slot_fixture = artifact_computed_fixture\<lparr>output_slots:=
    output_slots artifact_computed_fixture @ output_slots artifact_computed_fixture\<rparr>"

definition artifact_child_requirement_fixture :: artifact_requirement where
  "artifact_child_requirement_fixture = artifact_requirement_fixture\<lparr>artifact_template:=601,
    artifact_revision:=602,artifact_manifest:=603,artifact_parents:=[ReservedOutput 510],
    artifact_profile:=604,artifact_setup:=605,artifact_exports:=606\<rparr>"

definition artifact_child_goal_fixture :: "subgoal" where
  "artifact_child_goal_fixture = artifact_goal_fixture\<lparr>goal_id:=13,
    goal_generation:=44,goal_code_generation:=55,goal_dependencies:=[ArtifactDependency 6],
    goal_required:=ArtifactRequirement artifact_child_requirement_fixture,
    goal_output_slot:=Some 511,goal_outcome:=AwaitingOutput 511\<rparr>"

definition artifact_composite_request_fixture :: request where
  "artifact_composite_request_fixture = artifact_request_fixture\<lparr>
    request_goals:=[artifact_goal_fixture,artifact_child_goal_fixture]\<rparr>"

definition artifact_child_slot_fixture :: output_slot where
  "artifact_child_slot_fixture = artifact_slot_fixture\<lparr>output_slot_id:=511,output_goal:=13,
    output_template:=601,output_profile:=604,output_inputs:=[KnownInput 530,ReservedOutput 510],
    output_reserved_dependencies:=[530,8,300,601,602,603,604,605,606,44,55,7,10]\<rparr>"

definition artifact_child_run_fixture :: pure_execution where
  "artifact_child_run_fixture = artifact_run_fixture\<lparr>execution_id:=32,execution_slot:=511,
    execution_cost:=(execution_cost artifact_run_fixture)\<lparr>cost_profile:=604,cost_code_generation:=55\<rparr>,
    execution_inputs:=[530,520]\<rparr>"

definition artifact_child_assignment_fixture :: artifact_assignment where
  "artifact_child_assignment_fixture = artifact_assignment_fixture\<lparr>
    artifact_assigned_slot:=511,artifact_assigned_goal:=13,artifact_assigned_output:=525,
    artifact_assigned_lineage:=32,artifact_assigned_generation:=702,artifact_assigned_requirement:=
      artifact_child_requirement_fixture\<lparr>artifact_parents:=[KnownInput 520]\<rparr>,
    artifact_assigned_dependencies:=[525,530,8,702,701,520,300,601,602,603,604,605,606,44,55,7,10,501,502,503,504,505,506,4,5],
    artifact_assigned_retained:=[artifact_retained_fixture\<lparr>retained_id:=525,retained_payload:=525,
      retained_dependencies:=[530,8,702,701,520,300,601,602,603,604,605,606,44,55,7,10,501,502,503,504,505,506,4,5,13,511,3,510],
      retained_read_dependencies:=[530,520]\<rparr>]\<rparr>"

definition artifact_composite_ready_fixture :: authority_state where
  "artifact_composite_ready_fixture = fst (step (fst (step (fst (step initial_state
    (RegisterManaged public_input_fixture))) (ReserveRequest artifact_composite_request_fixture
      [artifact_slot_fixture,artifact_child_slot_fixture]))) (RegisterManaged artifact_parameter_fixture))"

definition effect_request_fixture :: request where
  "effect_request_fixture = fixture_request\<lparr>request_dependencies:=[300],permitted_effects:=[22]\<rparr>"
definition effect_intent_fixture :: effect_intent where
  "effect_intent_fixture = \<lparr>attempt_id=810,attempt_request=8,attempt_target=22,
    attempt_capability=7,attempt_sources=[300],attempt_dependencies=[7,300],attempt_prestate=0,
    attempt_cost=\<lparr>cost_profile=30,cost_code_generation=5,cost_operation=31,cost_step=32,cost_units=1\<rparr>,
    attempt_job=None\<rparr>"
definition effect_prepared_fixture :: authority_state where
  "effect_prepared_fixture = fst (step (fst (step (fst (step (fst (step initial_state
    (RegisterManaged public_input_fixture))) (OpenRequest effect_request_fixture)))
    (StageIntent 800 effect_intent_fixture))) (DurableAck 800 1 0))"
definition effect_running_fixture :: authority_state where
  "effect_running_fixture = fst (step effect_prepared_fixture (ClaimAndStart 810))"
definition effect_blocker_fixture :: blocker where
  "effect_blocker_fixture = \<lparr>blocked_scope=InterpretationScope 3,reason_id=830,discharge_conditions=[]\<rparr>"
definition effect_observation_fixture :: effect_observation where
  "effect_observation_fixture = \<lparr>effect_observation_attempt=810,effect_observation_source=820,
    effect_observation_status=Confirmed\<rparr>"

end
