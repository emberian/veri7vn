theory Veri7vn_Authority_Proofs
  imports Veri7vn_Authority.Veri7vn_Authority
begin

lemma refined_execution_pin:
  "execution_fits g required actual RefinedExecution \<Longrightarrow>
    executable_generation actual = ExecutableGeneration (goal_code_generation g)"
  by (simp add: execution_fits_def)
lemma oracle_execution_pin:
  "execution_fits g required actual EvaluationOracle \<Longrightarrow>
    executable_generation actual = ExecutableGeneration (goal_code_generation g)"
  by (simp add: execution_fits_def)
lemma noexec_cannot_satisfy_required_execution:
  "executable_generation actual = NoExecution \<Longrightarrow>
    executable_generation required = ExecutableGeneration g \<Longrightarrow>
    \<not> execution_fits goal required actual route"
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

lemma live_goals_current:
  assumes "d \<in> set (live_goals s r available gs)" "d \<notin> set available"
  shows "\<exists>g\<in>set gs. unblocked r g \<and> current_goal s r g=Some d"
  using assms
proof (induction gs arbitrary: available)
  case Nil
  then show ?case by (auto simp only: live_goals.simps)
next
  case (Cons g gs)
  let ?next = "if list_all (\<lambda>d. d\<in>set available) (goal_dependencies g) \<and> unblocked r g
    then (case current_goal s r g of None \<Rightarrow> available | Some ready \<Rightarrow> ready # available)
    else available"
  have tail_member: "d\<in>set (live_goals s r ?next gs)"
    using Cons.prems(1) by (simp only: live_goals.simps)
  show ?case
  proof (cases "d\<in>set ?next")
    case True
    have head: "unblocked r g \<and> current_goal s r g=Some d"
      using True Cons.prems(2)
      by (auto simp only: list.set(2) option.case split: if_splits option.splits)
    then show ?thesis by (auto simp only: list.set(2))
  next
    case False
    obtain h where "h\<in>set gs" "unblocked r h" "current_goal s r h=Some d"
      using Cons.IH[OF tail_member False] by blast
    then show ?thesis by (auto simp only: list.set(2))
  qed
qed
lemma live_goals_licensed:
  assumes "LogicalDependency n \<in> set (live_goals s r available gs)"
    "LogicalDependency n \<notin> set available"
  shows "\<exists>g\<in>set gs. goal_id g=n \<and> unblocked r g \<and>
    (\<exists>c e. goal_outcome g=Accepted c e \<and> licensed s r g c e)"
proof -
  obtain g where g: "g\<in>set gs" "unblocked r g"
    "current_goal s r g=Some (LogicalDependency n)"
    using live_goals_current[OF assms] by blast
  have result: "goal_id g=n \<and>
    (\<exists>c e. goal_outcome g=Accepted c e \<and> licensed s r g c e)"
    using g(3)
    by (cases "goal_required g"; cases "goal_outcome g")
      (auto simp only: current_goal.simps prod.case goal_requirement.case outcome.case
        option.inject option.distinct goal_dependency.inject goal_dependency.distinct
        split: if_splits)
  show ?thesis using g(1,2) result by blast
qed
lemma ready_live_predecessors:
  assumes "goal_ready_live s r g" "d\<in>set (goal_dependencies g)"
  shows "\<exists>h\<in>set (request_goals r). unblocked r h \<and> current_goal s r h=Some d"
  using assms live_goals_current[of d s r "[]" "request_goals r"]
  by (auto simp: goal_ready_live_def list_all_iff)
lemma ready_live_logical_predecessors:
  assumes "goal_ready_live s r g" "LogicalDependency n\<in>set (goal_dependencies g)"
  shows "\<exists>h\<in>set (request_goals r). goal_id h=n \<and> unblocked r h \<and>
    (\<exists>c e. goal_outcome h=Accepted c e \<and> licensed s r h c e)"
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
  assumes "d\<in>set (goal_dependencies g)"
    "\<forall>h\<in>set (request_goals r). goal_satisfied h \<noteq> Some d"
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
  by (simp add: remdups_remdups)
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

lemma forget_roots_new_denials_exact:
  assumes "roots \<noteq> []" "forget_closure (retained_values s) (remdups roots) = Some removed"
  shows "set (new_revoked_objects s (fst (step s (ForgetRoots roots)))) =
      set removed - set (revoked_objects s)"
    "set (new_forgotten_objects s (fst (step s (ForgetRoots roots)))) =
      set removed - set (forgotten_objects s)"
  using assms
  by (auto simp: new_revoked_objects_def new_forgotten_objects_def
      lifecycle_def forget_state_def revoke_state_def)

lemma forget_roots_already_revoked_still_erases:
  assumes "roots \<noteq> []" "forget_closure (retained_values s) (remdups roots) = Some removed"
    "objid \<in> set removed" "objid \<in> set (revoked_objects s)"
    "objid \<notin> set (forgotten_objects s)"
  shows "objid \<notin> set (new_revoked_objects s (fst (step s (ForgetRoots roots))))"
    "objid \<in> set (new_forgotten_objects s (fst (step s (ForgetRoots roots))))"
  using forget_roots_new_denials_exact[OF assms(1,2)] assms by auto

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
  "claim_output_permitted s a publication \<Longrightarrow>
   binding_licensed (output_preview s a) (assigned_binding a)"
  by (simp add: claim_output_permitted_def)
lemma output_slot_one_shot:
  "old \<in> set (output_assignments s) \<Longrightarrow> assignment_slot old = assignment_slot a \<Longrightarrow>
    \<not> output_permitted s a publication"
proof -
  assume old: "old \<in> set (output_assignments s)"
    and same: "assignment_slot old = assignment_slot a"
  show "\<not> output_permitted s a publication"
  proof
    assume permitted: "output_permitted s a publication"
    have fresh: "\<forall>prior\<in>set (output_assignments s). assignment_slot prior \<noteq> assignment_slot a"
    proof (cases a)
      case (ClaimOutput claim)
      have "claim_output_permitted s claim publication" using permitted by (simp only: ClaimOutput output_permitted.simps)
      then have "\<forall>prior\<in>set (output_assignments s). assignment_slot prior \<noteq> assigned_slot claim"
        unfolding claim_output_permitted_def by (rule conjunct1)
      then show ?thesis by (simp only: ClaimOutput assignment_slot.simps)
    next
      case (ArtifactOutput artifact)
      have "publication=None \<and> artifact_output_permitted s artifact"
        using permitted by (simp only: ArtifactOutput output_permitted.simps)
      then have "artifact_output_permitted s artifact" by (rule conjunct2)
      then have "\<forall>prior\<in>set (output_assignments s). assignment_slot prior \<noteq> artifact_assigned_slot artifact"
        unfolding artifact_output_permitted_def by (rule conjunct1)
      then show ?thesis by (simp only: ArtifactOutput assignment_slot.simps)
    qed
    show False using fresh old same by blast
  qed
qed
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
proof -
  have claims: "claim_assignments s=claim_assignments t"
    by (simp only: claim_assignments_def assms(2))
  show ?thesis unfolding required_for_def
    by (subst assms(1); subst claims; rule refl)
qed
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
    by (cases "required_for s r g"; simp add: licensed_def fresh required[symmetric] evidence accessible_def parent_accessible_def child_accessible_def)
qed

lemma licensed_bookkeeping [simp]:
  "licensed (s\<lparr>visible_bindings := bs\<rparr>) r g c e = licensed s r g c e"
  "licensed (s\<lparr>source_publications := ps\<rparr>) r g c e = licensed s r g c e"
  "licensed (s\<lparr>revision := n\<rparr>) r g c e = licensed s r g c e"
  "licensed (s\<lparr>pending_batch := pending\<rparr>) r g c e = licensed s r g c e"
  by (rule licensed_view_cong; simp)+
lemma resolved_inputs_cong:
  assumes "output_assignments s=output_assignments t"
  shows "resolved_inputs s inputs=resolved_inputs t inputs"
  by (induction inputs) (simp_all add: assms split: slot_input.splits option.splits)
lemma resolved_artifact_requirement_cong:
  assumes same: "output_assignments s=output_assignments t"
  shows "resolved_artifact_requirement s a=resolved_artifact_requirement t a"
proof -
  have resolved: "resolved_inputs s (artifact_parents a)=resolved_inputs t (artifact_parents a)"
    using resolved_inputs_cong[OF same] .
  show ?thesis by (simp only: resolved_artifact_requirement_def resolved)
qed
lemma resolved_artifact_requirement_bookkeeping [simp]:
  "resolved_artifact_requirement (s\<lparr>visible_bindings:=bs\<rparr>) a=resolved_artifact_requirement s a"
  "resolved_artifact_requirement (s\<lparr>source_publications:=ps\<rparr>) a=resolved_artifact_requirement s a"
  "resolved_artifact_requirement (s\<lparr>revision:=n\<rparr>) a=resolved_artifact_requirement s a"
  "resolved_artifact_requirement (s\<lparr>pending_batch:=pending\<rparr>) a=resolved_artifact_requirement s a"
  by (rule resolved_artifact_requirement_cong; simp)+
lemma artifact_owner_references_cong:
  assumes "requests s=requests t" "output_slots s=output_slots t"
  shows "artifact_owner_references s a=artifact_owner_references t a"
proof -
  have requests: "filter (\<lambda>r. request_id r=artifact_assigned_request a) (requests s)=
    filter (\<lambda>r. request_id r=artifact_assigned_request a) (requests t)"
    by (simp only: assms(1))
  have slots: "filter (\<lambda>x. output_slot_id x=artifact_assigned_slot a) (output_slots s)=
    filter (\<lambda>x. output_slot_id x=artifact_assigned_slot a) (output_slots t)"
    by (simp only: assms(2))
  show ?thesis unfolding artifact_owner_references_def
    by (subst requests; subst slots; rule refl)
qed
lemma artifact_expected_retained_cong:
  assumes "requests s=requests t" "output_slots s=output_slots t"
  shows "artifact_expected_retained s a=artifact_expected_retained t a"
  unfolding artifact_expected_retained_def
  by (simp only: artifact_owner_references_cong[OF assms])
lemma artifact_expected_retained_bookkeeping [simp]:
  "artifact_expected_retained (s\<lparr>visible_bindings:=bs\<rparr>) a=artifact_expected_retained s a"
  "artifact_expected_retained (s\<lparr>source_publications:=ps\<rparr>) a=artifact_expected_retained s a"
  "artifact_expected_retained (s\<lparr>revision:=n\<rparr>) a=artifact_expected_retained s a"
  "artifact_expected_retained (s\<lparr>pending_batch:=pending\<rparr>) a=artifact_expected_retained s a"
  by (rule artifact_expected_retained_cong; simp)+
lemma artifact_licensed_bookkeeping [simp]:
  "artifact_licensed (s\<lparr>visible_bindings:=bs\<rparr>) r g objid=artifact_licensed s r g objid"
  "artifact_licensed (s\<lparr>source_publications:=ps\<rparr>) r g objid=artifact_licensed s r g objid"
  "artifact_licensed (s\<lparr>revision:=n\<rparr>) r g objid=artifact_licensed s r g objid"
  "artifact_licensed (s\<lparr>pending_batch:=pending\<rparr>) r g objid=artifact_licensed s r g objid"
  by (simp_all add: artifact_licensed_def artifact_accessible_def artifact_assignments_def
      accessible_def parent_accessible_def child_accessible_def request_fresh_def observation_fresh_def)
lemma current_goal_bookkeeping [simp]:
  "current_goal (s\<lparr>visible_bindings:=bs\<rparr>) r g=current_goal s r g"
  "current_goal (s\<lparr>source_publications:=ps\<rparr>) r g=current_goal s r g"
  "current_goal (s\<lparr>revision:=n\<rparr>) r g=current_goal s r g"
  "current_goal (s\<lparr>pending_batch:=pending\<rparr>) r g=current_goal s r g"
  by (cases "goal_required g"; cases "goal_outcome g"; simp_all)
lemma live_goals_cong:
  assumes "\<And>g. current_goal s r g=current_goal t r g"
  shows "live_goals s r available gs=live_goals t r available gs"
  by (induction gs arbitrary: available) (simp_all add: assms)
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
lemma effect_observation_preview_nonassertional [simp]:
  "visible_bindings (effect_observation_preview s observation)=visible_bindings s"
  "evidence_table (effect_observation_preview s observation)=evidence_table s"
  "output_assignments (effect_observation_preview s observation)=output_assignments s"
  by (simp_all add: effect_observation_preview_def split: if_splits option.splits)

lemma authorized_delta_new_binding:
  assumes "delta_permitted s d"
    "b \<in> set (visible_bindings (apply_delta d s))"
    "b \<notin> set (visible_bindings s)"
  shows "binding_licensed (apply_delta d s) b"
  using assms
  by (cases d; auto simp: Let_def artifact_preview_def split: slot_assignment.splits if_splits dest: output_authorized_in_preview)
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
  assumes "ClaimOutput a \<in> set (output_assignments s)"
    "private \<in> set (binding_managed_dependencies s (assigned_binding a))"
    "private \<in> set removed"
  shows "ClaimOutput a \<notin> set (output_assignments (forget_state removed s))"
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
        split: option.splits outcome.splits list.splits if_splits)
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
  assumes "claim_output_permitted s a publication"
  obtains slot r g original where "slot \<in> set (output_slots s)"
    "r \<in> set (requests s)" "g \<in> set (request_goals r)"
    "output_slot_id slot = assigned_slot a"
    "output_owner slot = request_id r" "output_goal slot = goal_id g"
    "goal_output_slot g = Some (assigned_slot a)"
    "goal_required g=ClaimRequirement original"
    "scope_preserved original (assigned_requirement a)
      (assigned_premise_correspondence a)"
  using assms by (auto simp only: claim_output_permitted_def)

lemma output_premise_occurrences:
  assumes "scope_preserved original specialized correspondence"
  shows "map fst correspondence = premises original"
    "set (map snd correspondence) = set (premises specialized)"
  using assms by (simp_all add: scope_preserved_def)

lemma acknowledged_output_contract:
  assumes "pending_batch s = Some batch" "batch_delta batch = RecordOutput (ClaimOutput a) publication"
    "snd (step s (DurableAck n ack_rev epoch)) = [Visible n]"
  shows "claim_output_permitted s a publication"
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

lemma close_retained_dependencies_set:
  "set (retained_dependencies (close_retained_dependencies refs value)) =
    set (retained_dependencies value) \<union> set refs"
  by (auto simp: close_retained_dependencies_def)
lemma close_retained_dependencies_idempotent:
  "close_retained_dependencies refs (close_retained_dependencies refs value) =
    close_retained_dependencies refs value"
proof -
  have missing: "filter (\<lambda>d. d\<notin>set (retained_dependencies (close_retained_dependencies refs value)))
      (remdups refs)=[]"
    by (simp add: close_retained_dependencies_set filter_empty_conv)
  have "close_retained_dependencies refs (close_retained_dependencies refs value) =
      (close_retained_dependencies refs value)\<lparr>retained_dependencies:=
        retained_dependencies (close_retained_dependencies refs value)\<rparr>"
    unfolding close_retained_dependencies_def[of refs "close_retained_dependencies refs value"]
    by (simp only: missing append_Nil)
  then show ?thesis by simp
qed
lemma artifact_owner_references_rows_independent:
  "artifact_owner_references s (a\<lparr>artifact_assigned_retained:=values\<rparr>)=artifact_owner_references s a"
  by (simp add: artifact_owner_references_def)
lemma artifact_expected_retained_idempotent:
  "artifact_expected_retained s a=Some values \<Longrightarrow>
    artifact_expected_retained s (a\<lparr>artifact_assigned_retained:=values\<rparr>)=Some values"
  by (auto simp: artifact_expected_retained_def artifact_owner_references_rows_independent
    map_map comp_def close_retained_dependencies_idempotent split: option.splits)
lemma artifact_owner_references_intrinsic:
  "artifact_owner_references s a=Some refs \<Longrightarrow>
    set [artifact_assigned_request a,artifact_assigned_goal a,artifact_assigned_slot a,
      artifact_assigned_generation a] \<subseteq> set refs"
  by (auto simp: artifact_owner_references_def split: list.splits goal_requirement.splits if_splits)
lemma artifact_expected_retained_intrinsic:
  assumes "artifact_expected_retained s a=Some values" "value\<in>set values"
  shows "set [artifact_assigned_request a,artifact_assigned_goal a,artifact_assigned_slot a,
      artifact_assigned_generation a] \<subseteq> set (retained_dependencies value)"
proof -
  obtain refs where refs: "artifact_owner_references s a=Some refs"
    "values=map (close_retained_dependencies refs) (artifact_assigned_retained a)"
    using assms(1) by (cases "artifact_owner_references s a"; auto simp: artifact_expected_retained_def)
  obtain original where "value=close_retained_dependencies refs original"
    using assms(2) refs(2) by auto
  then show ?thesis using artifact_owner_references_intrinsic[OF refs(1)]
    by (auto simp: close_retained_dependencies_set)
qed

lemma artifact_requirement_never_licenses_claim:
  "goal_required g=ArtifactRequirement a \<Longrightarrow> \<not> licensed s r g c evidence"
  by (simp add: licensed_def)
lemma artifact_requirement_has_no_claim_requirement:
  "goal_required g=ArtifactRequirement a \<Longrightarrow> required_for s r g=None"
  by (simp add: required_for_def)
lemma artifact_dependency_is_not_logical:
  "goal_required g=ArtifactRequirement a \<Longrightarrow>
    current_goal s r g \<noteq> Some (LogicalDependency n)"
  by (auto split: outcome.splits)
lemma logical_dependency_is_not_artifact:
  "goal_required g=ClaimRequirement c \<Longrightarrow>
    current_goal s r g \<noteq> Some (ArtifactDependency n)"
  by (auto split: outcome.splits)
lemma licensing_uses_child_not_parent_pins:
  "licensed s (r\<lparr>request_generation:=generation,request_code_generation:=code\<rparr>) g c e =
    licensed s r g c e"
  by (simp add: licensed_def request_fresh_def parent_accessible_def required_for_def)
lemma charging_uses_child_not_parent_pin:
  "goal_chargeable (r\<lparr>request_code_generation:=code\<rparr>) g cost=goal_chargeable r g cost"
  by (simp add: goal_chargeable_def)
lemma artifact_ready_not_accepted:
  "\<not> accepted (ArtifactReady candidate)"
  by simp
lemma artifact_output_not_claim_publication:
  "visible_bindings (apply_delta (RecordOutput (ArtifactOutput a) publication) s)=visible_bindings s"
  by (auto simp: artifact_preview_def split: if_splits)
lemma artifact_output_retains_exact_candidate:
  assumes "artifact_output_permitted s a"
  shows "ArtifactOutput a\<in>set (output_assignments (artifact_preview s a))"
    "set (artifact_assigned_retained a) \<subseteq> set (retained_values (artifact_preview s a))"
proof -
  have canonical: "artifact_expected_retained s a=Some (artifact_assigned_retained a)"
    using assms by (auto simp: artifact_output_permitted_def)
  show "ArtifactOutput a\<in>set (output_assignments (artifact_preview s a))"
    "set (artifact_assigned_retained a) \<subseteq> set (retained_values (artifact_preview s a))"
    using canonical by (simp_all add: artifact_preview_def)
qed
lemma malformed_artifact_not_installed:
  "artifact_expected_retained s a\<noteq>Some (artifact_assigned_retained a) \<Longrightarrow> artifact_preview s a=s"
  by (simp add: artifact_preview_def)
lemma composite_rejects_legacy_effect:
  "length (request_goals r) \<noteq> 1 \<Longrightarrow> \<not> legacy_single_goal r"
  by (auto simp: legacy_single_goal_def split: list.splits)
lemma permitted_intent_uses_single_goal_request:
  "intent_permitted s intent \<Longrightarrow> \<exists>r\<in>set (requests s).
    request_id r=attempt_request intent \<and> length (request_goals r)=1"
  by (auto simp: intent_permitted_def legacy_single_goal_def split: list.splits)
lemma parent_denial_prevents_dispatch:
  "execution_request run\<in>set (revoked_objects s) \<Longrightarrow> \<not> pure_permitted s run"
  by (auto simp: pure_permitted_def parent_accessible_def accessible_def list_all_iff)
lemma parent_retirement_cancels_request:
  "cancel_dependent s (request_id r) r = r\<lparr>request_cancelled:=True\<rparr>"
  by (simp add: cancel_dependent_def)
lemma child_denial_preserves_parent_cancellation_flag:
  "n \<noteq> request_id r \<Longrightarrow> n\<notin>set (request_dependencies r) \<Longrightarrow>
    request_cancelled (cancel_dependent s n r)=request_cancelled r"
  by (simp add: cancel_dependent_def)
lemma child_identity_is_guarded:
  "goal_id g\<in>set (revoked_objects s) \<Longrightarrow> \<not> child_accessible s g"
  by (simp add: child_accessible_def goal_references_def accessible_def)
lemma artifact_result_generation_retained:
  "artifact_output_permitted s a \<Longrightarrow> artifact_assigned_generation a>0"
  "artifact_output_permitted s a \<Longrightarrow>
    artifact_assigned_generation a\<in>set (artifact_assigned_dependencies a)"
  by (auto simp: artifact_output_permitted_def)
lemma qualification_charge_uses_owned_child:
  assumes "qualification_startable s q"
  obtains r g where "r\<in>set (requests s)" "g\<in>set (request_goals r)"
    "request_id r=reservation_owner q" "goal_id g=reservation_goal q"
    "cost_code_generation (reservation_cost q)=goal_code_generation g"
    "goal_ready_live s r g" "unblocked r g"
  using assms by (auto simp: qualification_startable_def goal_chargeable_def)

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


lemma terminal_attempt_rejects_effect_observation:
  assumes unique: "filter (\<lambda>a. attempt_id (attempt_intent a)=effect_observation_attempt observation) (attempts s)=[a]"
    and terminal: "attempt_state a=Confirmed \<or> attempt_state a=EffectFailed"
  shows "\<not> effect_observation_permitted s observation"
  using terminal by (simp only: effect_observation_permitted_def unique list.case; auto)

lemma retained_terminal_attempt_rejects_effect_observation:
  assumes member: "a\<in>set (attempts s)"
    and identity: "attempt_id (attempt_intent a)=effect_observation_attempt observation"
    and terminal: "attempt_state a=Confirmed \<or> attempt_state a=EffectFailed"
  shows "\<not> effect_observation_permitted s observation"
proof -
  have filtered: "a\<in>set (filter (\<lambda>x. attempt_id (attempt_intent x)=effect_observation_attempt observation) (attempts s))"
    using member identity by simp
  show ?thesis using filtered terminal
    by (auto simp: effect_observation_permitted_def split: list.splits)
qed

lemma forget_preserves_attempt_history [simp]:
  "attempts (forget_state removed s)=attempts s"
  by (simp add: forget_state_def revoke_state_def)
lemma retained_terminal_rejects_staging_response:
  assumes "a\<in>set (attempts s)"
    "attempt_id (attempt_intent a)=effect_observation_attempt observation"
    "attempt_state a=Confirmed \<or> attempt_state a=EffectFailed"
  shows "step s (StageEffectObservation batch observation)=(s,[Rejected 44])"
  using retained_terminal_attempt_rejects_effect_observation[OF assms] by simp
lemma forgotten_terminal_rejects_new_response:
  assumes "a\<in>set (attempts s)"
    "attempt_id (attempt_intent a)=effect_observation_attempt observation"
    "attempt_state a=Confirmed \<or> attempt_state a=EffectFailed"
  shows "step (forget_state removed s) (StageEffectObservation fresh_batch observation)=
    (forget_state removed s,[Rejected 44])"
  by (rule retained_terminal_rejects_staging_response) (simp_all add: assms)
lemma reconcile_preserves_retained_terminal:
  assumes "a\<in>set (attempts s)"
    "attempt_state a=Confirmed \<or> attempt_state a=EffectFailed"
  shows "a\<in>set (attempts (fst (step s (Reconcile attempt status))))"
  using assms by (auto intro: image_eqI split: if_splits)

lemma required_native_child_has_output_slot:
  assumes "(r,g)\<in>set (required_native_children s)"
  shows "goal_output_slot g\<noteq>None"
  using assms by (auto simp: required_native_children_def)

lemma required_native_effect_request_is_slotless:
  assumes "r\<in>set (required_native_effect_requests s)"
  shows "\<exists>g. request_goals r=[g] \<and> goal_output_slot g=None"
  using assms by (auto simp: required_native_effect_requests_def effect_request_material_required_def split: list.splits)

end
