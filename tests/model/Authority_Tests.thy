theory Authority_Tests
  imports Veri7vn_Authority_Proofs.Veri7vn_Authority_Proofs
    Veri7vn_Authority_Fixtures.Authority_Fixtures
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
  "\<not> ordered_goals [] [fixture_goal\<lparr>goal_dependencies := [LogicalDependency 13]\<rparr>, fixture_second_goal]"
  by (simp add: chain_defs)

lemma confirmed_not_downgraded:
  assumes "attempts s = [a]" "attempt_state a = Confirmed"
  shows "step s (Reconcile (attempt_id (attempt_intent a)) Unknown) = (s, [Rejected 9])"
  using assms by simp

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
  "execution_fits fixture_goal
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>) KernelConsequence"
  by (simp add: execution_fits_def fixture_goal_def)

lemma refined_noexec_rejected:
  "\<not> execution_fits fixture_goal
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>) RefinedExecution"
  by (simp add: execution_fits_def fixture_goal_def)

lemma required_execution_cannot_use_noexec:
  "\<not> execution_fits fixture_goal fixture_claim
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>) KernelConsequence"
  by (simp add: execution_fits_def fixture_goal_def fixture_claim_def)

lemma swapped_execution_rejected:
  "\<not> execution_fits fixture_goal
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := ExecutableGeneration 6\<rparr>) RefinedExecution"
  by (simp add: execution_fits_def fixture_goal_def)

lemma unknown_actual_execution_rejected:
  "\<not> execution_fits fixture_goal
    (fixture_claim\<lparr>executable_generation := NoExecution\<rparr>)
    (fixture_claim\<lparr>executable_generation := ExecutableGeneration 999\<rparr>) KernelConsequence"
  by (simp add: execution_fits_def fixture_goal_def)

end
