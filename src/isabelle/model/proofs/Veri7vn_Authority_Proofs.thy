theory Veri7vn_Authority_Proofs
  imports Veri7vn_Authority.Veri7vn_Authority
begin

lemma refined_execution_pin:
  "execution_fits r required actual RefinedExecution \<Longrightarrow>
    executable_generation actual = ExecutableGeneration (request_code_generation r)"
  by (simp add: execution_fits_def)
lemma oracle_execution_pin:
  "execution_fits r required actual EvaluationOracle \<Longrightarrow>
    executable_generation actual = ExecutableGeneration (request_code_generation r)"
  by (simp add: execution_fits_def)
lemma noexec_cannot_satisfy_required_execution:
  "executable_generation actual = NoExecution \<Longrightarrow>
    executable_generation required = ExecutableGeneration g \<Longrightarrow>
    \<not> execution_fits r required actual route"
  by (simp add: execution_fits_def)

lemma ordered_goals_distinct:
  "ordered_goals seen gs \<Longrightarrow> distinct (map goal_id gs) \<and>
    (\<forall>g \<in> set gs. goal_id g \<notin> set seen)"
proof (induction gs arbitrary: seen)
  case Nil
  then show ?case by simp
next
  case (Cons a gs)
  have tail: "ordered_goals (goal_id a # seen) gs"
    using Cons.prems by simp
  have ih: "distinct (map goal_id gs) \<and>
    (\<forall>g \<in> set gs. goal_id g \<notin> set (goal_id a # seen))"
    using Cons.IH[OF tail] .
  show ?case using Cons.prems ih by auto
qed

lemma live_goals_licensed:
  assumes "n \<in> set (live_goals s r available gs)" "n \<notin> set available"
  shows "\<exists>g \<in> set gs. goal_id g = n \<and> unblocked r g \<and>
    (\<exists>c e. goal_outcome g = Accepted c e \<and> licensed s r g c e)"
  using assms
proof (induction gs arbitrary: available)
  case Nil
  then show ?case by simp
next
  case (Cons a gs)
  let ?ok = "list_all (\<lambda>d. d \<in> set available) (goal_dependencies a) \<and>
    unblocked r a \<and> (case goal_outcome a of Accepted c e \<Rightarrow>
      licensed s r a c e | _ \<Rightarrow> False)"
  let ?next = "if ?ok then goal_id a # available else available"
  have tail: "n \<in> set (live_goals s r ?next gs)"
    using Cons.prems(1) by simp
  show ?case
  proof (cases "n \<in> set ?next")
    case True
    then have "goal_id a = n" "?ok"
      using Cons.prems(2) by (auto split: if_splits)
    then show ?thesis by (cases "goal_outcome a"; auto)
  next
    case False
    have "\<exists>g \<in> set gs. goal_id g = n \<and> unblocked r g \<and>
      (\<exists>c e. goal_outcome g = Accepted c e \<and> licensed s r g c e)"
      using Cons.IH[OF tail False] .
    then show ?thesis by auto
  qed
qed

lemma ready_live_predecessors:
  assumes "goal_ready_live s r g" "n \<in> set (goal_dependencies g)"
  shows "\<exists>h \<in> set (request_goals r). goal_id h = n \<and> unblocked r h \<and>
    (\<exists>c e. goal_outcome h = Accepted c e \<and> licensed s r h c e)"
  using assms live_goals_licensed[of n s r "[]" "request_goals r"]
  by (auto simp: goal_ready_live_def list_all_iff)

lemma same_target_scope:
  assumes "same_target a b"
  shows "collection_scope a = collection_scope b"
    "claim_optimality a = claim_optimality b"
    "premises a = premises b" "claim_kind a = claim_kind b"
    "claim_modality a = claim_modality b"
  using assms by (cases a; cases b; auto simp: same_target_def)+

lemma stage_not_visible:
  "visible_bindings (fst (stage n d s)) = visible_bindings s"
  by (simp add: stage_def Let_def)

lemma issued_batch_not_rebound:
  "n \<in> set (issued_batches s) \<Longrightarrow> stage n d s = (s, [Rejected 10])"
  by (simp add: stage_def)

lemma cancelled_not_licensed:
  assumes "\<forall>r \<in> set (requests s). request_id r = binding_request b \<longrightarrow> request_cancelled r"
  shows "\<not> binding_licensed s b"
  using assms by (auto simp: binding_licensed_def)

lemma retired_no_intent:
  "attempt_capability i \<in> set (retired_capabilities s) \<Longrightarrow> \<not> intent_permitted s i"
  by (auto simp: intent_permitted_def)

lemma revoked_no_intent:
  "attempt_target i \<in> set (revoked_objects s) \<Longrightarrow> \<not> intent_permitted s i"
  by (auto simp: intent_permitted_def accessible_def list_all_iff)

lemma retired_source_no_publication:
  "source_binding_id p \<in> set (retired_sources s) \<Longrightarrow> \<not> observation_permitted s p"
  by (auto simp: observation_permitted_def)

lemma incomplete_dependency_not_ready:
  assumes "d \<in> set (goal_dependencies g)"
    "\<forall>h \<in> set (request_goals r). goal_id h = d \<longrightarrow> \<not> accepted (goal_outcome h)"
  shows "\<not> goal_ready r g"
  using assms by (auto simp: goal_ready_def list_all_iff)

lemma licensed_retains_dependencies:
  assumes "licensed s r g c e" "d \<in> set (request_dependencies r)"
  shows "d \<in> set (dependencies c)"
  using assms by (auto simp: licensed_def list_all_iff)

lemma lifecycle_invalidates_staging:
  "pending_batch (lifecycle s) = None"
  "authority_epoch (lifecycle s) = Suc (authority_epoch s)"
  by (simp_all add: lifecycle_def)

lemma forget_singleton_compatibility:
  "step s (Forget n) = step s (ForgetRoots [n])"
  by simp
lemma empty_forget_roots_rejected:
  "step s (ForgetRoots []) = (s, [Rejected 41])"
  by simp
lemma duplicate_forget_roots_equivalent:
  "step s (ForgetRoots roots) = step s (ForgetRoots (remdups roots))"
  by simp
lemma forget_roots_exact:
  assumes "roots \<noteq> []" "forget_closure (retained_values s) (remdups roots) = Some removed"
  shows "step s (ForgetRoots roots) =
    (lifecycle (forget_state removed s), map RemoveManaged removed @ [AuthorityChanged (Suc (authority_epoch s))])"
  using assms by simp
lemma forget_roots_one_epoch:
  assumes "roots \<noteq> []" "forget_closure (retained_values s) (remdups roots) = Some removed"
  shows "authority_epoch (fst (step s (ForgetRoots roots))) = Suc (authority_epoch s)"
    "pending_batch (fst (step s (ForgetRoots roots))) = None"
  using assms by (simp_all add: lifecycle_def forget_state_def revoke_state_def)
lemma forget_roots_denies_seeds:
  assumes "roots \<noteq> []" "forget_closure (retained_values s) (remdups roots) = Some removed"
    "root \<in> set roots"
  shows "root \<in> set (revoked_objects (fst (step s (ForgetRoots roots))))"
    "root \<in> set (forgotten_objects (fst (step s (ForgetRoots roots))))"
  using assms forget_closure_closed[OF assms(2)]
  by (auto simp: lifecycle_def forget_state_def revoke_state_def)
lemma forget_roots_checked_closed:
  "forget_closure (retained_values s) (remdups roots) = Some removed \<Longrightarrow>
    managed_closed (retained_values s) (set removed)"
  using forget_closure_closed by blast
lemma forget_roots_checked_minimal:
  "forget_closure (retained_values s) (remdups roots) = Some removed \<Longrightarrow>
    set roots \<subseteq> X \<Longrightarrow> managed_closed (retained_values s) X \<Longrightarrow>
    set removed \<subseteq> X"
  by (metis forget_closure_minimal set_remdups)
lemma forget_roots_unrelated_retained_survives:
  assumes "roots \<noteq> []" "forget_closure (retained_values s) (remdups roots) = Some removed"
    "v \<in> set (retained_values s)" "retained_id v \<notin> set removed"
  shows "v \<in> set (retained_values (fst (step s (ForgetRoots roots))))"
  using assms by (simp add: lifecycle_def forget_state_def)
lemma new_revoked_objects_exact:
  "objid \<in> set (new_revoked_objects previous next) \<longleftrightarrow>
    objid \<in> set (revoked_objects next) \<and> objid \<notin> set (revoked_objects previous)"
  by (simp add: new_revoked_objects_def)
lemma new_forgotten_objects_exact:
  "objid \<in> set (new_forgotten_objects previous next) \<longleftrightarrow>
    objid \<in> set (forgotten_objects next) \<and> objid \<notin> set (forgotten_objects previous)"
  by (simp add: new_forgotten_objects_def)
lemma new_denial_objects_distinct:
  "distinct (new_revoked_objects previous next)"
  "distinct (new_forgotten_objects previous next)"
  by (simp_all add: new_revoked_objects_def new_forgotten_objects_def)

lemma reconciliation_not_publication:
  "visible_bindings (fst (step s (Reconcile n status))) = visible_bindings s"
  "retired_sources (fst (step s (Reconcile n status))) = retired_sources s"
  by simp_all


lemma acknowledgement_exact:
  assumes "snd (step s (DurableAck n ack_rev epoch)) = [Visible n]"
  obtains b where "pending_batch s = Some b" "batch_id b = n"
    "expected_revision b = revision s" "ack_rev = Suc (revision s)"
    "batch_epoch b = authority_epoch s" "epoch = authority_epoch s"
  using assms by (auto split: option.splits if_splits)

lemma unresolved_slot_not_licensed:
  "required_for s r g = None \<Longrightarrow> \<not> licensed s r g c eid"
  by (simp add: licensed_def)
lemma output_authorized_in_preview:
  "output_permitted s a publication \<Longrightarrow>
   binding_licensed (output_preview s a) (assigned_binding a)"
  by (simp add: output_permitted_def)
lemma output_slot_one_shot:
  "old \<in> set (output_assignments s) \<Longrightarrow> assigned_slot old = assigned_slot a \<Longrightarrow>
    \<not> output_permitted s a publication"
  by (auto simp: output_permitted_def)
lemma request_cannot_downgrade_observation:
  "request_observation r = RequireAccess observed window \<Longrightarrow> \<not> request_fresh s r"
  by (simp add: request_fresh_def)
lemma output_scope_unchanged:
  "scope_preserved original specialized correspondence \<Longrightarrow>
    collection_scope original = collection_scope specialized \<and>
    claim_optimality original = claim_optimality specialized \<and>
    claim_kind original = claim_kind specialized \<and>
    claim_modality original = claim_modality specialized \<and>
    interpretation_id original = interpretation_id specialized \<and>
    semantic_generation original = semantic_generation specialized \<and>
    executable_generation original = executable_generation specialized"
  by (cases original; cases specialized; auto simp: scope_preserved_def same_target_def)

lemma observation_fresh_cong:
  assumes "current_observations s = current_observations t" "revoked_objects s = revoked_objects t"
  shows "observation_fresh s required = observation_fresh t required"
  using assms by (cases required; simp add: observation_fresh_def accessible_def)
lemma request_fresh_cong:
  assumes "current_observations s = current_observations t" "revoked_objects s = revoked_objects t"
  shows "request_fresh s r = request_fresh t r"
  using observation_fresh_cong[OF assms] assms
  by (cases "request_observation r"; cases "request_session r";
      simp add: request_fresh_def accessible_def)
lemma required_for_cong:
  assumes "output_slots s = output_slots t" "output_assignments s = output_assignments t"
  shows "required_for s r g = required_for t r g"
  using assms by (auto simp: required_for_def split: option.splits)
lemma evidence_accessible_cong:
  "revoked_objects s = revoked_objects t \<Longrightarrow> evidence_accessible s e = evidence_accessible t e"
  by (simp add: evidence_accessible_def accessible_def)
lemma licensed_view_cong:
  assumes "current_observations s = current_observations t" "revoked_objects s = revoked_objects t"
    "output_slots s = output_slots t" "output_assignments s = output_assignments t"
    "evidence_table s = evidence_table t"
  shows "licensed s r g c e = licensed t r g c e"
proof -
  have fresh: "request_fresh s r = request_fresh t r" using request_fresh_cong[OF assms(1,2)] .
  have required: "required_for s r g = required_for t r g" using required_for_cong[OF assms(3,4)] .
  have evidence: "\<And>entry. evidence_accessible s entry = evidence_accessible t entry"
    using evidence_accessible_cong[OF assms(2)] .
  show ?thesis using assms(2,5)
    by (cases "required_for s r g"; simp add: licensed_def fresh required[symmetric] evidence accessible_def)
qed

lemma licensed_bookkeeping [simp]:
  "licensed (s\<lparr>visible_bindings := bs\<rparr>) r g c e = licensed s r g c e"
  "licensed (s\<lparr>source_publications := ps\<rparr>) r g c e = licensed s r g c e"
  "licensed (s\<lparr>revision := n\<rparr>) r g c e = licensed s r g c e"
  "licensed (s\<lparr>pending_batch := pending\<rparr>) r g c e = licensed s r g c e"
  by (rule licensed_view_cong; simp)+
lemma live_goals_cong:
  assumes "\<And>g c e. licensed s r g c e = licensed t r g c e"
  shows "live_goals s r available gs = live_goals t r available gs"
proof (induction gs arbitrary: available)
  case Nil
  then show ?case by simp
next
  case (Cons g gs)
  have check: "(case goal_outcome g of Accepted c e \<Rightarrow> licensed s r g c e | _ \<Rightarrow> False) =
    (case goal_outcome g of Accepted c e \<Rightarrow> licensed t r g c e | _ \<Rightarrow> False)"
    by (cases "goal_outcome g"; simp add: assms)
  show ?case by (simp only: live_goals.simps check Cons.IH)
qed
lemma live_goals_bookkeeping [simp]:
  "live_goals (s\<lparr>visible_bindings := bs\<rparr>) r available gs = live_goals s r available gs"
  "live_goals (s\<lparr>source_publications := ps\<rparr>) r available gs = live_goals s r available gs"
  "live_goals (s\<lparr>revision := n\<rparr>) r available gs = live_goals s r available gs"
  "live_goals (s\<lparr>pending_batch := pending\<rparr>) r available gs = live_goals s r available gs"
  by (rule live_goals_cong; simp)+
lemma binding_licensed_bookkeeping [simp]:
  "binding_licensed (s\<lparr>visible_bindings := bs\<rparr>) b = binding_licensed s b"
  "binding_licensed (s\<lparr>source_publications := ps\<rparr>) b = binding_licensed s b"
  "binding_licensed (s\<lparr>revision := n\<rparr>) b = binding_licensed s b"
  "binding_licensed (s\<lparr>pending_batch := pending\<rparr>) b = binding_licensed s b"
  by (simp_all add: binding_licensed_def goal_ready_live_def)
lemma output_preview_visible [simp]:
  "visible_bindings (output_preview s a) = visible_bindings s"
  by (simp add: output_preview_def Let_def)
lemma authorized_delta_new_binding:
  assumes "delta_permitted s d"
    "b \<in> set (visible_bindings (apply_delta d s))"
    "b \<notin> set (visible_bindings s)"
  shows "binding_licensed (apply_delta d s) b"
  using assms
  by (cases d; auto simp: Let_def dest: output_authorized_in_preview)
lemma inaccessible_session_refresh_rejected:
  assumes "observed_session context \<in> set (revoked_objects s)"
  shows "step s (UpdateObservation context) = (s, [Rejected 21])"
  using assms by (simp add: accessible_def)
lemma inaccessible_read_refresh_rejected:
  assumes "read_id \<in> set (map fst (observed_reads context))" "read_id \<in> set (revoked_objects s)"
  shows "step s (UpdateObservation context) = (s, [Rejected 21])"
  using assms by (auto simp: accessible_def list_all_iff)
lemma inaccessible_utterance_recording_rejected:
  assumes "utterance \<in> set (revoked_objects s)"
  shows "step s (RecordUtterance sid utterance) = (s, [Rejected 43])"
  using assms by (simp add: accessible_def)
lemma forgotten_session_view_removed:
  assumes "session_id view \<in> set removed"
  shows "view \<notin> set (session_views (forget_state removed s))"
  using assms by (auto simp: forget_state_def)
lemma forgotten_session_observation_removed:
  assumes "observed_session context \<in> set removed"
  shows "context \<notin> set (current_observations (forget_state removed s))"
  using assms by (auto simp: forget_state_def disjoint_ids_def list_all_iff)
lemma forgotten_utterance_reference_removed:
  assumes "view \<in> set (session_views (forget_state removed s))" "utterance \<in> set removed"
  shows "utterance \<notin> set (recorded_utterances view)"
  using assms by (auto simp: forget_state_def)

lemma forgotten_private_edge_removes_assignment:
  assumes "a \<in> set (output_assignments s)"
    "private \<in> set (binding_managed_dependencies s (assigned_binding a))"
    "private \<in> set removed"
  shows "a \<notin> set (output_assignments (forget_state removed s))"
  using assms by (auto simp: forget_state_def disjoint_ids_def list_all_iff)
lemma checked_forget_removes_private_derivative:
  assumes "forget_closure (retained_values s) [private] = Some removed"
    "v \<in> set (retained_values s)" "private \<in> set (retained_dependencies v)"
  shows "retained_id v \<in> set removed"
  using forget_closure_closed[OF assms(1)] assms(2,3)
  by (auto simp: managed_closed_def)


lemma newly_visible_is_licensed:
  assumes "b \<in> set (visible_bindings (fst (step s (DurableAck n ack_rev epoch))))"
    "b \<notin> set (visible_bindings s)"
  shows "binding_licensed (fst (step s (DurableAck n ack_rev epoch))) b"
  using assms authorized_delta_new_binding
  by (auto split: option.splits if_splits)

lemma publication_authorized:
  assumes "b \<in> set (visible_bindings (fst (step s ev)))"
    "b \<notin> set (visible_bindings s)"
  shows "binding_licensed (fst (step s ev)) b"
proof -
  have "\<exists>n ack_rev epoch. ev = DurableAck n ack_rev epoch"
    using assms
    by (cases ev; auto simp: stage_def lifecycle_def forget_state_def
        revoke_state_def charge_request_def charge_intent_def Let_def
        split: option.splits outcome.splits if_splits)
  then obtain n ack_rev epoch where "ev = DurableAck n ack_rev epoch" by blast
  then show ?thesis using assms newly_visible_is_licensed by blast
qed

lemma publication_scope:
  assumes "binding_licensed s b"
  obtains r g required where "r \<in> set (requests s)" "g \<in> set (request_goals r)"
    "required_for s r g = Some required"
    "same_target (binding_claim b) required"
    "goal_ready_live s r g" "unblocked r g" "\<not> request_cancelled r"
  using assms by (auto simp: binding_licensed_def licensed_def split: option.splits)

lemma output_original_requirement:
  assumes "output_permitted s a publication"
  obtains slot r g where "slot \<in> set (output_slots s)"
    "r \<in> set (requests s)" "g \<in> set (request_goals r)"
    "output_slot_id slot = assigned_slot a"
    "output_owner slot = request_id r" "output_goal slot = goal_id g"
    "goal_output_slot g = Some (assigned_slot a)"
    "scope_preserved (goal_required g) (assigned_requirement a)
      (assigned_premise_correspondence a)"
  using assms by (auto simp only: output_permitted_def)

lemma output_premise_occurrences:
  assumes "scope_preserved original specialized correspondence"
  shows "map fst correspondence = premises original"
    "set (map snd correspondence) = set (premises specialized)"
  using assms by (simp_all add: scope_preserved_def)

lemma acknowledged_output_contract:
  assumes "pending_batch s = Some batch" "batch_delta batch = RecordOutput a publication"
    "snd (step s (DurableAck n ack_rev epoch)) = [Visible n]"
  shows "output_permitted s a publication"
    "binding_licensed (fst (step s (DurableAck n ack_rev epoch))) (assigned_binding a)"
  using assms output_authorized_in_preview
  by (auto simp: Let_def split: if_splits)

lemma stage_output_does_not_bind:
  "output_assignments (fst (step s (StageOutput n a publication))) = output_assignments s"
  "visible_bindings (fst (step s (StageOutput n a publication))) = visible_bindings s"
  by (simp_all add: stage_def Let_def)

lemma retained_output_managed_closure:
  assumes "output_retention_permitted s r a"
  obtains v where "v \<in> set (assigned_retained a)" "retained_id v = assigned_output a"
    "set (binding_managed_dependencies s (assigned_binding a)) \<subseteq> set (retained_dependencies v)"
proof -
  obtain v where member: "v \<in> set (assigned_retained a)" and ident: "retained_id v = assigned_output a"
    using assms by (auto simp: output_retention_permitted_def)
  have closure: "set (binding_managed_dependencies s (assigned_binding a)) \<subseteq> set (retained_dependencies v)"
    using assms member ident by (auto simp: output_retention_permitted_def list_all_iff)
  show thesis using that[OF member ident closure] .
qed

lemma unrelated_retained_value_survives:
  "v \<in> set (retained_values s) \<Longrightarrow> retained_id v \<notin> set removed \<Longrightarrow>
    v \<in> set (retained_values (forget_state removed s))"
  by (simp add: forget_state_def)

text \<open>Native association is a relation to the concrete native gate's exported
semantics, not a universal HOL truth predicate. The locale parameter licenses only
this authority metadata claim under the exact recorded native assumptions. Its
assumption is TB-01's faithful attachment, NOT an owned operation refinement.\<close>
locale native_evidence_bridge =
  fixes native_license :: "claim \<Rightarrow> bool"
    and s :: authority_state
  assumes faithful_attachment:
    "e \<in> set (evidence_table s) \<Longrightarrow> native_license (evidence_claim e)"
begin
lemma licensed_native:
  "licensed s r g c eid \<Longrightarrow> native_license c"
  using faithful_attachment by (auto simp: licensed_def split: option.splits)
lemma staged_binding_native:
  "binding_licensed s b \<Longrightarrow> native_license (binding_claim b)"
  using licensed_native by (auto simp: binding_licensed_def)
end


end
