theory Dialogue_Tests
  imports Veri7vn_Dialogue.Veri7vn_Dialogue
begin

definition test_claim :: claim where
  "test_claim = \<lparr>claim_id=1,target_id=2,interpretation_id=3,
    claim_kind=Mathematical,claim_modality=Asserted,collection_scope=Scalar,
    claim_optimality=Unspecified,premises=[],dependencies=[],
    semantic_generation=1,executable_generation=NoExecution\<rparr>"
definition test_goal :: "subgoal" where
  "test_goal = \<lparr>goal_id=1,goal_interpretation=3,goal_capability=10,
    goal_dependencies=[],goal_required=ClaimRequirement test_claim,
    goal_generation=1,goal_code_generation=1,goal_output_slot=None,
    goal_outcome=NeedsInput []\<rparr>"
definition test_policy :: dialogue_policy where
  "test_policy = \<lparr>dialogue_policy_version=7,positive_precedence=[20,10],
    addressed_capabilities=None,reading_decline_codes=[71]\<rparr>"
definition test_request :: request where
  "test_request = \<lparr>request_id=9,request_generation=1,request_code_generation=1,
    request_prestate=0,request_dependencies=[],allowed_routes=[KernelConsequence],
    permitted_effects=[],request_goals=[test_goal,test_goal\<lparr>goal_id:=2,goal_capability:=20\<rparr>],
    request_blockers=[],request_cancelled=False,request_fuel=100,
    request_session=None,request_observation=StateTimeUnused,request_retention_scopes=[]\<rparr>"
definition test_receipt :: "nat selection" where
  "test_receipt = \<lparr>alternatives=[3],chosen=3,decision_id=4\<rparr>"

lemma positive_precedence_selects_specialist:
  "map goal_capability (dialogue_select test_policy initial_state test_request
    7 test_receipt (ClaimRequirement test_claim)) = [20]"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def
    test_receipt_def selection_valid_def goal_ready_live_def
    unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def Let_def same_target_def)

lemma private_address_prevents_general_fallback:
  "dialogue_select (test_policy\<lparr>addressed_capabilities:=Some [99]\<rparr>)
    initial_state test_request 7 test_receipt (ClaimRequirement test_claim) = []"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def
    test_receipt_def selection_valid_def goal_ready_live_def
    unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def Let_def)

lemma explicitly_unavailable_private_source_has_no_fallback:
  "dialogue_select (test_policy\<lparr>addressed_capabilities:=Some []\<rparr>)
    initial_state test_request 7 test_receipt (ClaimRequirement test_claim) = []"
  by (rule unavailable_address_no_route) simp

lemma unaddressed_question_still_routes:
  "addressed_capabilities test_policy = None \<and>
    map goal_capability (dialogue_select test_policy initial_state test_request
      7 test_receipt (ClaimRequirement test_claim)) = [20]"
  using positive_precedence_selects_specialist by (simp add: list_all_iff test_policy_def)

lemma scoped_veto_blocks_every_capability:
  "dialogue_select test_policy initial_state
    (test_request\<lparr>request_blockers:=[\<lparr>blocked_scope=InterpretationScope 3,
      reason_id=42,discharge_conditions=[]\<rparr>]\<rparr>) 7 test_receipt (ClaimRequirement test_claim) = []"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def
    test_receipt_def selection_valid_def goal_ready_live_def
    unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def Let_def)

lemma stale_selection_rejected:
  "dialogue_select test_policy initial_state test_request 6 test_receipt (ClaimRequirement test_claim) = []"
  by (simp add: list_all_iff dialogue_select_def test_policy_def)

lemma changed_question_rejected:
  "dialogue_select test_policy initial_state test_request 7 test_receipt
    (ClaimRequirement (test_claim\<lparr>target_id:=999\<rparr>)) = []"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def test_claim_def
    test_receipt_def selection_valid_def goal_ready_live_def
    unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def Let_def same_target_def)

lemma ambiguity_is_not_resolved_by_capability_priority:
  "dialogue_clarification test_policy initial_state
    (test_request\<lparr>request_goals:=[test_goal,
      test_goal\<lparr>goal_id:=2,goal_interpretation:=4,goal_capability:=20\<rparr>]\<rparr>)
    = Ambiguous [3,4]"
  by (simp add: list_all_iff dialogue_clarification_def dialogue_readings_def dialogue_eligible_def
    test_policy_def test_request_def test_goal_def goal_ready_live_def unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def)

lemma no_implicit_choice_after_alternatives_change:
  "dialogue_select test_policy initial_state
    (test_request\<lparr>request_goals:=[test_goal,
      test_goal\<lparr>goal_id:=2,goal_interpretation:=4\<rparr>]\<rparr>)
    7 test_receipt (ClaimRequirement test_claim) = []"
  by (simp add: list_all_iff dialogue_select_def dialogue_readings_def dialogue_eligible_def
    test_policy_def test_request_def test_goal_def test_receipt_def
    goal_ready_live_def unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def)

lemma dependent_part_requires_live_predecessor:
  "test_goal\<lparr>goal_id:=3,goal_dependencies:=[LogicalDependency 1]\<rparr> \<notin> set
    (dialogue_eligible test_policy initial_state
      (test_request\<lparr>request_goals:=[test_goal,
        test_goal\<lparr>goal_id:=3,goal_dependencies:=[LogicalDependency 1]\<rparr>]\<rparr>))"
  by (simp add: list_all_iff dialogue_eligible_def test_policy_def test_request_def test_goal_def
    goal_ready_live_def unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def)

lemma outer_veto_cannot_seed_followup:
  assumes "b \<in> set (adoption_bindings d)"
    "\<not> binding_licensed guarded_state b"
  shows "dialogue_adoption guarded_state request nonce d = None"
  by (rule withheld_binding_not_adopted[OF assms])

definition test_artifact :: artifact_requirement where
  "test_artifact = \<lparr>artifact_template=10,artifact_source=11,artifact_revision=12,
    artifact_manifest=13,artifact_parents=[],artifact_profile=14,artifact_setup=15,
    artifact_exports=16\<rparr>"

lemma logical_answer_cannot_fill_artifact_requirement:
  "dialogue_select test_policy initial_state test_request 7 test_receipt
    (ArtifactRequirement test_artifact) = []"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def
    test_receipt_def selection_valid_def goal_ready_live_def unblocked_def child_accessible_def parent_accessible_def accessible_def initial_state_def Let_def)

lemma candidate_outcome_is_not_an_accepted_claim:
  "\<not> accepted (ArtifactReady 17)"
  by simp

lemma revoked_child_does_not_hide_unrelated_route:
  "map goal_capability (dialogue_select test_policy
    (initial_state\<lparr>revoked_objects:=[20]\<rparr>) test_request
    7 test_receipt (ClaimRequirement test_claim)) = [10]"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def test_claim_def
    test_receipt_def selection_valid_def goal_ready_live_def unblocked_def
    child_accessible_def parent_accessible_def accessible_def goal_references_def claim_references_def
    initial_state_def Let_def same_target_def)

lemma current_parent_routes_only_accessible_children:
  "map goal_capability (dialogue_current_select test_policy
    (initial_state\<lparr>requests:=[test_request],revoked_objects:=[20]\<rparr>)
    9 7 test_receipt (ClaimRequirement test_claim)) = [10]"
  by (simp add: list_all_iff dialogue_current_select_def dialogue_select_def dialogue_routes_def
    dialogue_readings_def dialogue_eligible_def test_policy_def test_request_def
    test_goal_def test_claim_def test_receipt_def selection_valid_def goal_ready_live_def
    request_fresh_def observation_fresh_def unblocked_def child_accessible_def parent_accessible_def
    accessible_def goal_references_def claim_references_def initial_state_def
    Let_def same_target_def)

lemma cancelled_preferred_child_does_not_hide_unrelated_route:
  "map goal_capability (dialogue_select test_policy initial_state
    (test_request\<lparr>request_goals:=[test_goal,
      test_goal\<lparr>goal_id:=2,goal_capability:=20,goal_outcome:=Cancelled\<rparr>]\<rparr>)
    7 test_receipt (ClaimRequirement test_claim)) = [10]"
  by (simp add: list_all_iff dialogue_select_def dialogue_routes_def dialogue_readings_def
    dialogue_eligible_def test_policy_def test_request_def test_goal_def
    test_receipt_def selection_valid_def goal_ready_live_def unblocked_def
    child_accessible_def parent_accessible_def accessible_def initial_state_def Let_def same_target_def)

definition independently_named_children where
  "independently_named_children = test_request\<lparr>request_goals:=[
    test_goal\<lparr>goal_id:=31,goal_output_slot:=Some 41\<rparr>,
    test_goal\<lparr>goal_id:=32,goal_capability:=20,goal_output_slot:=Some 42\<rparr>]\<rparr>"

definition independently_named_state where
  "independently_named_state = initial_state\<lparr>requests:=[independently_named_children]\<rparr>"
definition independently_named_receipt :: "nat selection" where
  "independently_named_receipt = \<lparr>
    alternatives=dialogue_readings test_policy independently_named_state independently_named_children,
    chosen=3,decision_id=45\<rparr>"
definition independently_named_after_forget where
  "independently_named_after_forget n = fst (step independently_named_state (Forget n))"

lemma forgotten_goal_preserves_unrelated_route:
  "map goal_capability (dialogue_current_select test_policy
    (independently_named_after_forget 32) 9
    7 independently_named_receipt (ClaimRequirement test_claim)) = [10]"
  by (simp add: list_all_iff dialogue_current_select_def dialogue_select_def dialogue_routes_def
    dialogue_readings_def dialogue_eligible_def independently_named_children_def
    independently_named_state_def independently_named_receipt_def independently_named_after_forget_def
    test_policy_def test_request_def test_goal_def test_claim_def selection_valid_def
    goal_ready_live_def request_fresh_def observation_fresh_def unblocked_def child_accessible_def parent_accessible_def
    accessible_def goal_references_def claim_references_def initial_state_def Let_def same_target_def
    forget_closure_def lifecycle_def forget_state_def revoke_state_def cancel_dependent_def required_for_def)

lemma forgotten_slot_preserves_unrelated_route:
  "map goal_capability (dialogue_current_select test_policy
    (independently_named_after_forget 42) 9
    7 independently_named_receipt (ClaimRequirement test_claim)) = [10]"
  by (simp add: list_all_iff dialogue_current_select_def dialogue_select_def dialogue_routes_def
    dialogue_readings_def dialogue_eligible_def independently_named_children_def
    independently_named_state_def independently_named_receipt_def independently_named_after_forget_def
    test_policy_def test_request_def test_goal_def test_claim_def selection_valid_def
    goal_ready_live_def request_fresh_def observation_fresh_def unblocked_def child_accessible_def parent_accessible_def
    accessible_def goal_references_def claim_references_def initial_state_def Let_def same_target_def
    forget_closure_def lifecycle_def forget_state_def revoke_state_def cancel_dependent_def required_for_def)

lemma forgotten_parent_rejects_current_and_stale_child_routes:
  "dialogue_current_select test_policy (independently_named_after_forget 9) 9
      7 independently_named_receipt (ClaimRequirement test_claim) = [] \<and>
    dialogue_select test_policy (independently_named_after_forget 9) independently_named_children
      7 independently_named_receipt (ClaimRequirement test_claim) = []"
  by (simp add: list_all_iff dialogue_current_select_def dialogue_select_def dialogue_routes_def
    dialogue_readings_def dialogue_eligible_def independently_named_children_def
    independently_named_state_def independently_named_receipt_def independently_named_after_forget_def
    test_policy_def test_request_def test_goal_def test_claim_def selection_valid_def
    goal_ready_live_def request_fresh_def observation_fresh_def unblocked_def child_accessible_def
    parent_accessible_def accessible_def goal_references_def claim_references_def initial_state_def
    Let_def same_target_def forget_closure_def lifecycle_def forget_state_def revoke_state_def
    cancel_dependent_def required_for_def)

lemma reading_decline_is_distinct_from_guard_failure:
  "dialogue_fillable test_policy (Declined 71) \<and>
    \<not> dialogue_fillable test_policy (Declined 72) \<and>
    \<not> dialogue_fillable test_policy (NeedsInput [71]) \<and>
    \<not> dialogue_fillable test_policy (Inconclusive 71) \<and>
    \<not> dialogue_fillable test_policy (Failed 71) \<and>
    \<not> dialogue_fillable test_policy Cancelled"
  by (simp add: test_policy_def)

lemma core_answer_cannot_be_intercepted:
  assumes "goal_outcome previous = Accepted c evidence \<or>
    goal_outcome previous = ArtifactReady artifact \<or>
    goal_outcome previous = AwaitingOutput slot"
  shows "dialogue_fallback p s r v receipt required previous = []"
  using assms by (auto simp: dialogue_fallback_def)

lemma fabricated_prior_decline_cannot_open_route:
  "previous \<notin> set (request_goals r) \<Longrightarrow>
    dialogue_fallback p s r v receipt required previous = []"
  by (simp add: dialogue_fallback_def)

lemma fallback_cannot_evade_interpretation_guard:
  assumes "b \<in> set (request_blockers r)"
    "blocked_scope b = InterpretationScope (goal_interpretation g)"
  shows "g \<notin> set (dialogue_fallback p s r v receipt required previous)"
  using assms fallback_preserves_selection scoped_veto_no_fallback by blast

lemma unavailable_personal_reader_stays_unavailable_after_decline:
  "dialogue_fallback (test_policy\<lparr>addressed_capabilities:=Some []\<rparr>)
    initial_state test_request 7 test_receipt (ClaimRequirement test_claim) previous = []"
  by (simp add: dialogue_fallback_def unavailable_address_no_route)

end
