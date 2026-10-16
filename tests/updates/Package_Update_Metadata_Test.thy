theory Package_Update_Metadata_Test
  imports "Veri7vn_Package_Update_Metadata.Package_Update_Metadata"
begin

definition fixture_names :: structural_update_names where
  "fixture_names = \<lparr>update_request=1, update_goal=2, update_request_slot=31, update_claim=3, update_target=4,
    update_interpretation=5, update_evidence=6, update_semantic_generation=7,
    update_executable_generation=8, update_candidate=9, update_baseline=10,
    update_contract=11, update_run_spec=12, update_policy=13, update_policy_resource=14,
    update_attempt=15, update_qualification=16, update_observation=17,
    update_acceptance_metric=18, update_count_metric=19, update_unit=20, update_exposure=21\<rparr>"
definition fixture_result :: structural_update_result where
  "fixture_result = \<lparr>result_names=fixture_names, result_dependencies=[9,10], result_checked_count=1\<rparr>"
definition fixture_goal :: subgoal where
  "fixture_goal = \<lparr>goal_id=2, goal_interpretation=5, goal_capability=9,
    goal_dependencies=[], goal_required=ClaimRequirement (structural_update_claim fixture_result),
    goal_generation=7, goal_code_generation=8,
    goal_output_slot=Some 31, goal_outcome=Accepted (structural_update_claim fixture_result) 6\<rparr>"
definition fixture_request :: request where
  "fixture_request = \<lparr>request_id=1, request_generation=7, request_code_generation=8,
    request_prestate=0, request_dependencies=structural_update_dependencies fixture_result,
    allowed_routes=[EvaluationOracle], permitted_effects=[], request_goals=[fixture_goal],
    request_blockers=[], request_cancelled=False, request_fuel=10, request_session=None,
    request_observation=StateTimeUnused, request_retention_scopes=[WorkspaceShared]\<rparr>"
definition fixture_cost :: operation_cost where
  "fixture_cost = \<lparr>cost_profile=12, cost_code_generation=8, cost_operation=32, cost_step=33, cost_units=1\<rparr>"
definition fixture_slot :: output_slot where
  "fixture_slot = \<lparr>output_slot_id=31, output_owner=1, output_goal=2, output_template=32,
    output_profile=12, output_inputs=[KnownInput 9], output_input_identity=9,
    output_reserved_dependencies=[], output_origin=QualificationOrigin 15\<rparr>"
definition fixture_candidate :: retained_value where
  "fixture_candidate = \<lparr>retained_id=9, retained_owner=WorkspaceShared,
    retained_dependencies=[9], retained_read_dependencies=[], retained_access_requirements=[], retained_payload=9\<rparr>"
definition fixture_observation :: retained_value where
  "fixture_observation = \<lparr>retained_id=17, retained_owner=WorkspaceShared,
    retained_dependencies=evidence_managed_dependencies (structural_update_evidence fixture_result),
    retained_read_dependencies=[9], retained_access_requirements=[], retained_payload=17\<rparr>"
definition fixture_output :: output_assignment where
  "fixture_output = structural_update_output fixture_result [fixture_observation]"
definition fixture_state :: authority_state where
  "fixture_state = initial_state\<lparr>requests := [fixture_request],
    output_slots := [fixture_slot], output_assignments := [ClaimOutput fixture_output],
    retained_values := [fixture_candidate,fixture_observation],
    evidence_table := [structural_update_evidence fixture_result],
    qualification_started := [15],
    qualification_reservations := [structural_update_reservation fixture_result fixture_cost],
    exposure_history := [\<lparr>exposure_id=21, exposure_parent=None, exposure_members=[]\<rparr>]\<rparr>"
definition fixture_publication :: package_publication where
  "fixture_publication = structural_update_publication fixture_result 30 (Some 10) SupportPackage [] []"
definition fixture_ready_state :: authority_state where
  "fixture_ready_state = fixture_state\<lparr>
    qualification_policies := [structural_update_policy fixture_names],
    qualifications := [structural_update_qualification fixture_result],
    package_publications := [fixture_publication\<lparr>publication_candidate := 10,
      publication_previous := None\<rparr>]\<rparr>"
definition fixture_pending_state :: authority_state where
  "fixture_pending_state = fixture_ready_state\<lparr>qualifications := [],
    output_assignments := [], retained_values := [fixture_candidate],
    requests := [fixture_request\<lparr>request_goals := [fixture_goal\<lparr>goal_outcome := Inconclusive 99\<rparr>]\<rparr>]\<rparr>"
definition fixture_publication_checks :: bool where
  "fixture_publication_checks = (structural_update_current fixture_ready_state fixture_result \<and>
    structural_update_current fixture_pending_state fixture_result \<and>
    \<not> package_permitted fixture_pending_state fixture_publication \<and>
    structural_update_current (fixture_ready_state\<lparr>qualifications := []\<rparr>) fixture_result \<and>
    package_permitted fixture_ready_state fixture_publication \<and>
    \<not> package_permitted fixture_ready_state
      (fixture_publication\<lparr>publication_previous := Some 99\<rparr>) \<and>
    package_publications (fst (step fixture_ready_state
      (StageQualifiedPublication 40 (fixture_publication\<lparr>publication_previous := Some 99\<rparr>)))) =
      package_publications fixture_ready_state \<and>
    package_publications (fst (step (fst (step fixture_ready_state
      (StageQualifiedPublication 40 fixture_publication))) (DurableAck 40 1 0))) =
      [fixture_publication])"
definition fixture_admission_names :: initial_admission_names where
  "fixture_admission_names = \<lparr>update_request=1, update_goal=2, update_request_slot=31, update_claim=3, update_target=4,
    update_interpretation=5, update_evidence=6, update_semantic_generation=7,
    update_executable_generation=8, update_candidate=9,
    update_contract=11, update_run_spec=12, update_policy=13, update_policy_resource=14,
    update_attempt=15, update_qualification=16, update_observation=17,
    update_acceptance_metric=18, update_count_metric=19, update_unit=20, update_exposure=21, admission_export_intent=22, admission_source_owner=23,
    admission_source_revision=24, admission_manifest=25\<rparr>"
definition fixture_admission_result :: initial_admission_result where
  "fixture_admission_result = \<lparr>admission_names=fixture_admission_names,
    admission_dependencies=[9,22,23,24,25], admission_checked_count=1\<rparr>"
definition fixture_admission_observation :: retained_value where
  "fixture_admission_observation = fixture_observation\<lparr>retained_dependencies :=
    evidence_managed_dependencies (initial_admission_evidence fixture_admission_result)\<rparr>"
definition fixture_initial_state :: authority_state where
  "fixture_initial_state = fixture_state\<lparr>requests := [fixture_request\<lparr>
      request_dependencies := initial_admission_dependencies fixture_admission_result,
      request_goals := [fixture_goal\<lparr>goal_required := ClaimRequirement (initial_admission_claim fixture_admission_result),
        goal_outcome := Accepted (initial_admission_claim fixture_admission_result) 6\<rparr>]\<rparr>],
    evidence_table := [initial_admission_evidence fixture_admission_result],
    output_assignments := [ClaimOutput (initial_admission_output fixture_admission_result [fixture_admission_observation])],
    retained_values := [fixture_candidate,fixture_admission_observation],
    qualification_reservations := [initial_admission_reservation fixture_admission_result fixture_cost],
    qualification_policies := [initial_admission_policy fixture_admission_names],
    qualifications := [initial_admission_qualification fixture_admission_result]\<rparr>"
definition fixture_initial_checks :: bool where
  "fixture_initial_checks = (output_permitted
      (fixture_initial_state\<lparr>output_assignments := [], retained_values := [fixture_candidate],
        requests := [fixture_request\<lparr>request_dependencies := initial_admission_dependencies fixture_admission_result,
          request_fuel := 0, request_goals := [fixture_goal\<lparr>goal_required := ClaimRequirement (initial_admission_claim fixture_admission_result),
            goal_outcome := Inconclusive 99\<rparr>]\<rparr>]\<rparr>)
      (ClaimOutput (initial_admission_output fixture_admission_result [fixture_admission_observation])) None \<and>
    initial_admission_current fixture_initial_state fixture_admission_result \<and>
    reservation_baseline
      (initial_admission_reservation fixture_admission_result fixture_cost) = None \<and>
    qualification_permitted (fixture_initial_state\<lparr>qualifications := []\<rparr>)
      (initial_admission_qualification fixture_admission_result) \<and>
    package_permitted fixture_initial_state
      (initial_admission_publication fixture_admission_result 30 SupportPackage [] []) \<and>
    \<not> metric_policy_satisfied (initial_admission_qualification fixture_admission_result)
      (structural_update_policy fixture_names))"
definition fixture_checks :: bool where
  "fixture_checks = (evidence_accessible fixture_state (structural_update_evidence fixture_result) \<and>
    binding_licensed fixture_state (structural_update_binding fixture_result) \<and>
    qualification_permitted fixture_state (structural_update_qualification fixture_result) \<and>
    structural_reservation_matches fixture_result fixture_cost
      (structural_update_reservation fixture_result fixture_cost) \<and>
    \<not> evidence_accessible (fixture_state\<lparr>revoked_objects := [4]\<rparr>)
      (structural_update_evidence fixture_result))"
definition fixture_paid_output_checks :: bool where
  "fixture_paid_output_checks = (let before=fixture_state\<lparr>output_assignments := [],
      retained_values := [fixture_candidate], requests := [fixture_request\<lparr>request_fuel := 0,
        request_goals := [fixture_goal\<lparr>goal_outcome := Inconclusive 99\<rparr>]\<rparr>]\<rparr> in
    output_permitted before (ClaimOutput fixture_output) None \<and>
    \<not> output_permitted (before\<lparr>qualification_started := []\<rparr>) (ClaimOutput fixture_output) None \<and>
    \<not> output_permitted before (ClaimOutput (fixture_output\<lparr>assigned_lineage := 99\<rparr>)) None \<and>
    qualification_permitted (fst (step (fst (step before
      (StageOutput 41 (ClaimOutput fixture_output) None))) (DurableAck 41 1 0)))
      (structural_update_qualification fixture_result) \<and>
    (\<forall>r\<in>set (requests (fst (step (fst (step before
      (StageOutput 41 (ClaimOutput fixture_output) None))) (DurableAck 41 1 0)))). request_fuel r=0))"
text \<open>Acceptance of the paid observation output is not completion of the
qualification/publication protocol. Its native child and measured evidence must
remain recoverable across this exact durable boundary.\<close>
definition fixture_before_accepted_output :: authority_state where
  "fixture_before_accepted_output = fixture_pending_state\<lparr>requests :=
    [fixture_request\<lparr>request_fuel := 0,
      request_goals := [fixture_goal\<lparr>goal_outcome := Inconclusive 99\<rparr>]\<rparr>]\<rparr>"
definition fixture_after_accepted_output :: authority_state where
  "fixture_after_accepted_output = fst (step (fst (step fixture_before_accepted_output
    (StageOutput 41 (ClaimOutput fixture_output) None))) (DurableAck 41 1 0))"
definition fixture_after_qualification :: authority_state where
  "fixture_after_qualification = fst (step (fst (step fixture_after_accepted_output
    (StageQualification 42 (structural_update_qualification fixture_result)))) (DurableAck 42 2 0))"
definition fixture_after_continued_publication :: authority_state where
  "fixture_after_continued_publication = fst (step (fst (step fixture_after_qualification
    (StageQualifiedPublication 43 fixture_publication))) (DurableAck 43 3 0))"
definition fixture_accepted_continuation_checks :: bool where
  "fixture_accepted_continuation_checks = (
    output_permitted fixture_before_accepted_output (ClaimOutput fixture_output) None \<and>
    qualifications fixture_after_accepted_output = [] \<and>
    (\<exists>rg\<in>set (required_native_children fixture_after_accepted_output).
      request_id (fst rg)=1 \<and> \<not> request_cancelled (fst rg) \<and> request_fuel (fst rg)=0 \<and>
      goal_id (snd rg)=2 \<and> goal_output_slot (snd rg)=Some 31 \<and>
      goal_outcome (snd rg)=Accepted (structural_update_claim fixture_result) 6) \<and>
    structural_update_evidence fixture_result \<in> set (required_native_evidence fixture_after_accepted_output) \<and>
    structural_update_reservation fixture_result fixture_cost \<in> set (qualification_reservations fixture_after_accepted_output) \<and>
    15 \<in> set (qualification_started fixture_after_accepted_output) \<and>
    structural_update_current fixture_after_accepted_output fixture_result \<and>
    qualification_permitted fixture_after_accepted_output (structural_update_qualification fixture_result) \<and>
    \<not> package_permitted fixture_after_accepted_output fixture_publication \<and>
    structural_update_qualification fixture_result \<in> set (qualifications fixture_after_qualification) \<and>
    map publication_candidate (package_publications fixture_after_qualification)=[10] \<and>
    package_permitted fixture_after_qualification fixture_publication \<and>
    package_publications fixture_after_continued_publication=[fixture_publication] \<and>
    qualification_reservations fixture_after_continued_publication=qualification_reservations fixture_after_accepted_output \<and>
    qualification_started fixture_after_continued_publication=qualification_started fixture_after_accepted_output \<and>
    (\<forall>r\<in>set (requests fixture_after_continued_publication). request_fuel r=0))"
definition fixture_child_scope_checks :: bool where
  "fixture_child_scope_checks = (
    structural_update_current (fixture_ready_state\<lparr>requests :=
      [fixture_request\<lparr>request_generation := 70, request_code_generation := 80\<rparr>]\<rparr>) fixture_result \<and>
    \<not> structural_update_current (fixture_ready_state\<lparr>requests :=
      [fixture_request\<lparr>request_goals := [fixture_goal\<lparr>goal_code_generation := 80\<rparr>]\<rparr>]\<rparr>) fixture_result \<and>
    \<not> structural_update_current (fixture_ready_state\<lparr>qualification_reservations :=
      [(structural_update_reservation fixture_result fixture_cost)\<lparr>reservation_goal := 99\<rparr>]\<rparr>) fixture_result)"
ML \<open>
val _ = if @{code fixture_checks} andalso @{code fixture_publication_checks} andalso @{code fixture_initial_checks} andalso @{code fixture_child_scope_checks} andalso @{code fixture_paid_output_checks} andalso @{code fixture_accepted_continuation_checks} then
  writeln "Package update metadata: accessible evidence, licensed binding, qualification, accepted continuation and target revocation passed"
  else error "Package update metadata closure failed";
\<close>
end
