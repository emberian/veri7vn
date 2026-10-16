theory Authority_Tests
  imports Veri7vn_Authority_Proofs.Veri7vn_Authority_Proofs
begin

lemma prefix_is_not_complete:
  "collection_scope a = Prefix n \<Longrightarrow> collection_scope b = Complete \<Longrightarrow>
    \<not> same_target a b"
  using same_target_scope(1) by fastforce

lemma feasible_is_not_optimal:
  "claim_optimality a = Feasible \<Longrightarrow> claim_optimality b = Optimal \<Longrightarrow>
    \<not> same_target a b"
  using same_target_scope(2) by fastforce

lemma cancellation_drops_pending:
  "pending_batch (fst (step s (CancelRequest r))) = None"
  by (simp add: lifecycle_def)

lemma retirement_preserves_history:
  "visible_bindings (fst (step s (RetireCapability c))) = visible_bindings s"
  "visible_bindings (fst (step s (RetireSource c))) = visible_bindings s"
  by (simp_all add: lifecycle_def)

lemma checked_forget_revokes:
  assumes "forget_closure (retained_values s) [n] = Some removed"
  shows "n \<in> set (revoked_objects (fst (step s (Forget n))))"
  using assms forget_closure_closed[OF assms]
  by (auto simp: lifecycle_def forget_state_def revoke_state_def)
lemma incomplete_forget_rejected:
  "forget_closure (retained_values s) [n] = None \<Longrightarrow>
    step s (Forget n) = (s, [Rejected 41])"
  by simp


definition fixture_claim :: claim where
  "fixture_claim = \<lparr>claim_id = 1, target_id = 2, interpretation_id = 3,
    claim_kind = Mathematical, claim_modality = Conditional,
    collection_scope = Scalar, claim_optimality = Unspecified,
    premises = [9], dependencies = [7, 10], semantic_generation = 4,
    executable_generation = ExecutableGeneration 5\<rparr>"
definition fixture_goal :: "subgoal" where
  "fixture_goal = \<lparr>goal_id = 6, goal_interpretation = 3,
    goal_capability = 7, goal_dependencies = [], goal_required = fixture_claim,
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
    evidence_route = KernelConsequence, evidence_managed_dependencies = [11,1,2,3,4,7,9,10]\<rparr>"
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
  binding_licensed_def goal_ready_live_def can_stage_def stage_def Let_def

lemma fixture_internal_not_visible:
  "visible_bindings fixture_internal = []"
  by (simp add: fixture_defs)
lemma fixture_staged_not_visible:
  "visible_bindings fixture_staged = []"
  by (simp add: fixture_defs)
lemma fixture_ack_publishes:
  "length (visible_bindings (fst (step fixture_staged (DurableAck 12 1 0)))) = 1"
  by (simp add: fixture_defs)
lemma fixture_wrong_epoch_rejected:
  "visible_bindings (fst (step fixture_staged (DurableAck 12 1 1))) = []"
  by (simp add: fixture_defs)
lemma fixture_cancelled_late_ack_rejected:
  "visible_bindings (fst (step (fst (step fixture_staged (CancelRequest 8)))
    (DurableAck 12 1 0))) = []"
  by (simp add: fixture_defs lifecycle_def)


definition fixture_second_claim :: claim where
  "fixture_second_claim = fixture_claim\<lparr>claim_id := 14, interpretation_id := 4\<rparr>"
definition fixture_second_goal :: "subgoal" where
  "fixture_second_goal = fixture_goal\<lparr>goal_id := 13, goal_interpretation := 4,
    goal_dependencies := [6], goal_required := fixture_second_claim,
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
lemma fixture_chain_live:
  "goal_ready_live fixture_chain (hd (requests fixture_chain)) fixture_second_goal"
  by (simp add: chain_defs)
lemma fixture_blocked_predecessor_not_live:
  "\<not> goal_ready_live fixture_blocked_chain (hd (requests fixture_blocked_chain))
    fixture_second_goal"
  by (simp add: chain_defs)
lemma fixture_unrelated_still_unblocked:
  "unblocked (hd (requests fixture_blocked_chain)) fixture_second_goal"
  by (simp add: chain_defs)
lemma fixture_blocked_predecessor_no_stage:
  "snd (step fixture_blocked_chain (StageClaim 18 8 13 15)) = [Rejected 3]"
  by (simp add: chain_defs)
lemma fixture_dangling_rejected:
  "\<not> ordered_goals [] [fixture_second_goal]"
  by (simp add: chain_defs)
lemma fixture_cycle_rejected:
  "\<not> ordered_goals [] [fixture_goal\<lparr>goal_dependencies := [13]\<rparr>, fixture_second_goal]"
  by (simp add: chain_defs)

lemma confirmed_not_downgraded:
  assumes "attempts s = [a]" "attempt_state a = Confirmed"
  shows "step s (Reconcile (attempt_id (attempt_intent a)) Unknown) = (s, [Rejected 9])"
  using assms by simp


definition fixture_source_claim :: claim where
  "fixture_source_claim = fixture_claim\<lparr>claim_kind := SourceObservation,
    dependencies := [7, 10, 19]\<rparr>"
definition fixture_source_state :: authority_state where
  "fixture_source_state = fixture_internal\<lparr>requests :=
    [fixture_request\<lparr>request_goals := [fixture_goal\<lparr>goal_required := fixture_source_claim,
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
lemma fixture_live_source_can_publish:
  "observation_permitted fixture_source_state fixture_observation"
  by (simp add: source_fixture_defs)
lemma fixture_retired_source_late_poll_rejected:
  "snd (step (fst (step fixture_source_state (RetireSource 10)))
    (StageObservation 20 fixture_observation)) = [Rejected 12]"
  by (simp add: source_fixture_defs)
lemma fixture_retired_snapshot_claim_usable:
  "length (visible_bindings (fst (step
    (fst (step (fst (step fixture_source_state (RetireSource 10)))
      (StageClaim 20 8 6 11))) (DurableAck 20 1 1)))) = 1"
  by (simp add: source_fixture_defs)


definition fixture_proof_only_claim :: claim where
  "fixture_proof_only_claim = fixture_claim\<lparr>executable_generation := NoExecution\<rparr>"
definition fixture_proof_only_state :: authority_state where
  "fixture_proof_only_state = fst (step
    (fst (step (fst (step initial_state (OpenRequest
      (fixture_request\<lparr>request_goals := [fixture_goal\<lparr>goal_required := fixture_proof_only_claim\<rparr>]\<rparr>))))
      (AttachEvidence (fixture_evidence\<lparr>evidence_claim := fixture_proof_only_claim\<rparr>))))
    (SetOutcome 8 6 (Accepted fixture_proof_only_claim 11)))"
lemma kernel_fact_publishes_in_bundle_pinned_request:
  "length (visible_bindings (fst (step
    (fst (step fixture_proof_only_state (StageClaim 23 8 6 11)))
    (DurableAck 23 1 0)))) = 1"
  by (simp add: fixture_proof_only_state_def fixture_proof_only_claim_def fixture_defs)
lemma kernel_fact_retains_actual_noexec:
  "executable_generation (binding_claim (hd (visible_bindings (fst (step
    (fst (step fixture_proof_only_state (StageClaim 23 8 6 11)))
    (DurableAck 23 1 0)))))) = NoExecution"
  by (simp add: fixture_proof_only_state_def fixture_proof_only_claim_def fixture_defs)

lemma kernel_noexec_in_bundle_pinned_request:
  "execution_fits fixture_request
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>) KernelConsequence"
  by (simp add: execution_fits_def fixture_request_def)
lemma refined_noexec_rejected:
  "\<not> execution_fits fixture_request
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>) RefinedExecution"
  by (simp add: execution_fits_def fixture_request_def)
lemma required_execution_cannot_use_noexec:
  "\<not> execution_fits fixture_request fixture_claim
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>) KernelConsequence"
  by (simp add: execution_fits_def fixture_claim_def)
lemma swapped_execution_rejected:
  "\<not> execution_fits fixture_request
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := ExecutableGeneration 6\<rparr>) RefinedExecution"
  by (simp add: execution_fits_def fixture_request_def)
lemma unknown_actual_execution_rejected:
  "\<not> execution_fits fixture_request
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := ExecutableGeneration 999\<rparr>) KernelConsequence"
  by (simp add: execution_fits_def fixture_request_def)

text \<open>This ML consumer calls the generated function itself. No handwritten
acceptance transition is substituted. Both valid lifecycle commands and rejected
unbacked acknowledgement execute through that compiled function.\<close>
ML \<open>
  val base = @{code initial_state};
  val key = @{code nat_of_integer} 17;
  val (retired, commands) = @{code step} base (@{code RetireCapability} key);
  val _ = if @{code retired_capabilities} retired = [key] then ()
    else error "generated retirement failed";
  val _ = if length commands = 1 then () else error "missing epoch command";
  val (unbacked, rejection) = @{code step} base
    (@{code DurableAck} (key, key, key));
  val _ = if @{code revision} unbacked = @{code revision} base andalso
    length rejection = 1 then () else error "unbacked ack accepted";
  val _ = writeln "VERI7VN_MODEL generated_step PASS";
\<close>


text \<open>Synthetic authority metadata fixtures test the generated guards, not native
admission or mathematical truth. Production events require protected native origins.\<close>
definition lease_clock_fixture :: clock_reading where
  "lease_clock_fixture = \<lparr>basis=Wall ''lease-clock'', ticks=100\<rparr>"
definition lease_context_fixture :: observation_context where
  "lease_context_fixture = \<lparr>observed_session=42,observed_version=0,
    evaluation_time=Some lease_clock_fixture,observed_reads=[(77,1)]\<rparr>"
definition lease_condition_fixture :: observation_requirement where
  "lease_condition_fixture = RequireAccess lease_context_fixture
    (Some \<lparr>fresh_from=lease_clock_fixture,fresh_through=200\<rparr>)"
definition slot_goal_fixture :: "subgoal" where
  "slot_goal_fixture = fixture_goal\<lparr>goal_required := fixture_claim\<lparr>target_id := 14\<rparr>,
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
    (StageOutput 33 slot_assignment_fixture None))) (DurableAck 33 1 0))"
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

ML \<open>
  val n = @{code nat_of_integer};
  val step = @{code step};
  val computed = @{code slot_computed_fixture};
  val assignment = @{code slot_assignment_fixture};
  fun require true _ = () | require false message = error message;
  val _ = require (@{code request_fuel} (hd (@{code requests} computed)) = n 9)
    "whole pure operation did not charge request fuel";
  val _ = (case @{code required_for} computed @{code slot_request_fixture} @{code slot_goal_fixture} of
    NONE => () | SOME _ => error "unbound output became a live concrete requirement");
  val (staged, _) = step computed (@{code StageOutput} (n 33,assignment,NONE));
  val _ = require (null (@{code output_assignments} staged) andalso null (@{code visible_bindings} staged))
    "staging installed output before durable acknowledgement";
  val published = @{code slot_published_fixture};
  val _ = require (length (@{code output_assignments} published) = 1 andalso
      length (@{code visible_bindings} published) = 1 andalso
      @{code binding_licensed} published @{code slot_result_binding})
    "checked output not licensed after exact acknowledgement";
  val (duplicate, _) = step published (@{code StageOutput} (n 35,assignment,NONE));
  val _ = require (@{code pending_batch} duplicate = NONE) "one-shot output rebound";
  val (private_rejected, _) = step computed (@{code StageOutput} (n 36,@{code missing_private_fixture},NONE));
  val _ = require (@{code pending_batch} private_rejected = NONE)
    "private native provenance omitted from retained derivative";
  val (unauthorized, _) = step published (@{code StageRetention} (n 37,n 8,n 19,@{code SessionLocal} (n 42)));
  val _ = require (@{code pending_batch} unauthorized = NONE) "promotion without policy grant accepted";
  val followup = @{code followup_fixture};
  val _ = require (@{code inputs_accessible_to} followup (n 60) [n 19])
    "same-session retained followup denied";
  val _ = require (not (@{code inputs_accessible_to} followup (n 61) [n 19]))
    "cross-session retained followup admitted";
  val changed_reads = @{code UpdateObservation}
    (@{code lease_changed_reads_fixture});
  val (read_changed, _) = step followup changed_reads;
  val _ = require (not (@{code inputs_accessible_to} read_changed (n 60) [n 19]))
    "state-unused followup laundered changed source access";
  val (expired, _) = step followup (@{code UpdateObservation} @{code lease_expired_fixture});
  val _ = require (not (@{code inputs_accessible_to} expired (n 60) [n 19]))
    "state-unused followup laundered expired access";
  val (session_invalid, _) = step followup (@{code Revoke} (n 42));
  val _ = require (not (@{code inputs_accessible_to} session_invalid (n 60) [n 19]))
    "invalidated session retained access";
  val (forgotten, _) = step followup (@{code Forget} (n 100));
  val _ = require (not (@{code inputs_accessible_to} forgotten (n 60) [n 19]) andalso
      null (@{code output_assignments} forgotten))
    "forgotten private-only provenance left promoted derivative usable";
  val _ = require (exists (fn v => @{code retained_id} v = n 300) (@{code retained_values} forgotten))
    "forget erased unrelated public object";
  val (forgotten_session, _) = step followup (@{code Forget} (n 42));
  val _ = require (not (exists (fn v => @{code session_id} v = n 42)
      (@{code session_views} forgotten_session)) andalso
    not (exists (fn v => @{code observed_session} v = n 42)
      (@{code current_observations} forgotten_session)))
    "forget retained erased session view or clock observation";
  val (stale_forget, forget_reply) = step forgotten_session
    (@{code UpdateObservation} @{code lease_context_fixture});
  val _ = require (stale_forget = forgotten_session andalso length forget_reply = 1)
    "stale observation token resurrected forgotten session";
  val (stale_revoke, revoke_reply) = step session_invalid
    (@{code UpdateObservation} @{code lease_changed_reads_fixture});
  val _ = require (stale_revoke = session_invalid andalso length revoke_reply = 1)
    "stale observation token refreshed revoked session";
  val (surviving, surviving_reply) = step forgotten_session
    (@{code UpdateObservation} @{code surviving_context_fixture});
  val _ = require (null surviving_reply andalso
    exists (fn v => @{code observed_session} v = n 43) (@{code current_observations} surviving))
    "unrelated surviving session observation denied";
  val (utterances, _) = step @{code slot_ready_fixture} (@{code RecordUtterance} (n 42,n 400));
  val (erased_utterance, _) = step utterances (@{code Forget} (n 400));
  val _ = require (forall (fn v => not (member (op =) (@{code recorded_utterances} v) (n 400)))
    (@{code session_views} erased_utterance)) "forget retained erased transcript identifier";
  val (read_revoked, _) = step followup (@{code Revoke} (n 77));
  val _ = require (not (@{code observation_fresh} read_revoked @{code lease_condition_fixture}))
    "revoked read remained a fresh access observation";
  val (stale_read_revoke, revoked_read_reply) = step read_revoked
    (@{code UpdateObservation} @{code lease_changed_reads_fixture});
  val _ = require (stale_read_revoke = read_revoked andalso length revoked_read_reply = 1)
    "stale refresh revived revoked read";
  val (read_forgotten, _) = step followup (@{code Forget} (n 77));
  val (stale_read_forget, forgotten_read_reply) = step read_forgotten
    (@{code UpdateObservation} @{code lease_changed_reads_fixture});
  val _ = require (stale_read_forget = read_forgotten andalso length forgotten_read_reply = 1)
    "stale refresh revived forgotten read";
  val (stale_cas, stale_cas_reply) = step read_forgotten
    (@{code UpdateObservation} @{code stale_cas_fixture});
  val _ = require (stale_cas = read_forgotten andalso length stale_cas_reply = 1)
    "removed observation allowed surviving session CAS rollback";
  val (unaffected_read, unaffected_read_reply) = step read_forgotten
    (@{code UpdateObservation} @{code unaffected_read_fixture});
  val _ = require (null unaffected_read_reply andalso
    exists (fn v => @{code observed_reads} v = [(n 78,n 1)])
      (@{code current_observations} unaffected_read)) "unaffected current-CAS read refresh denied";
  val (reinserted_utterance, utterance_reply) = step erased_utterance
    (@{code RecordUtterance} (n 42,n 400));
  val _ = require (reinserted_utterance = erased_utterance andalso length utterance_reply = 1)
    "forgotten managed utterance reinserted by stale token";
  val _ = writeln "VERI7VN_MODEL slot_retention_private_closure PASS";
\<close>

ML \<open>
  val n = @{code nat_of_integer};
  val before_forget = @{code followup_fixture};
  val (after_forget, removals) = @{code step} before_forget (@{code ForgetRoots} [n 100,n 13]);
  val _ = if not (@{code inputs_accessible_to} after_forget (n 60) [n 19]) andalso
      null (@{code output_assignments} after_forget) andalso
      forall (fn root => member (op =) (@{code forgotten_objects} after_forget) root) [n 100,n 13,n 19]
    then () else error "Atomic root closure retained private derivative";
  val _ = if @{code authority_epoch} after_forget =
      @{code nat_of_integer} 1 andalso
      exists (fn v => @{code retained_id} v = n 300) (@{code retained_values} after_forget)
    then () else error "Atomic root forget changed unrelated history or repeated epoch";
  val _ = if @{code step} before_forget (@{code Forget} (n 100)) =
      @{code step} before_forget (@{code ForgetRoots} [n 100]) then ()
    else error "Singleton Forget compatibility changed";
  val _ = writeln "VERI7VN_MODEL forget_roots_closure PASS";
\<close>

end
