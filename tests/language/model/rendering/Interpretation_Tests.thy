theory Interpretation_Tests
  imports Veri7vn_Interpretation.Veri7vn_Rendering
    Veri7vn_Interpretation_Core_Tests.Literal_Grammar_Tests
begin

definition scoped_claim :: claim where
  "scoped_claim = \<lparr>claim_id=1, target_id=2, interpretation_id=3,
    claim_kind=ModelPrediction, claim_modality=Conditional,
    collection_scope=Prefix 20, claim_optimality=Feasible,
    premises=[7], dependencies=[8], semantic_generation=9,
    executable_generation=ExecutableGeneration 10\<rparr>"
lemma model_scope_cannot_become_world_assertion:
  "\<not> rendering_licensed scoped_claim (render_claim
    (scoped_claim\<lparr>claim_kind:=Mathematical, claim_modality:=Asserted\<rparr>))"
  by (simp add: rendering_licensed_def claim_rendering_correspondence scoped_claim_def)
lemma prefix_cannot_become_complete:
  "\<not> rendering_licensed scoped_claim
    (render_claim (scoped_claim\<lparr>collection_scope:=Complete\<rparr>))"
  by (simp add: rendering_licensed_def claim_rendering_correspondence scoped_claim_def)
lemma conditional_premise_cannot_disappear:
  "\<not> rendering_licensed scoped_claim (render_claim (scoped_claim\<lparr>premises:=[]\<rparr>))"
  by (simp add: rendering_licensed_def claim_rendering_correspondence scoped_claim_def)
lemma source_scope_cannot_become_math:
  "\<not> rendering_licensed (scoped_claim\<lparr>claim_kind:=SourceObservation\<rparr>)
    (render_claim (scoped_claim\<lparr>claim_kind:=Mathematical\<rparr>))"
  by (simp add: rendering_licensed_def claim_rendering_correspondence scoped_claim_def)
lemma partial_turn_not_completed:
  "\<not> all_parts_accepted [g\<lparr>goal_outcome:=Accepted scoped_claim 11\<rparr>,
    h\<lparr>goal_outcome:=Failed 12\<rparr>]"
  by (simp add: all_parts_accepted_def)
lemma helpful_act_has_no_claim_requirement:
  "assertions_licensed [] (assertions
    \<lparr>act_kind=Help, proposed_commentary=[], assertions=[]\<rparr>)"
  by (simp add: assertions_licensed_def)
definition false_premise_blocker :: blocker where
  "false_premise_blocker = \<lparr>blocked_scope=InterpretationScope 3,
    reason_id=13, discharge_conditions=[7]\<rparr>"
lemma fallback_same_reading_blocked:
  "goal_interpretation g = 3 \<Longrightarrow>
    \<not> unblocked (r\<lparr>request_blockers:=[false_premise_blocker]\<rparr>) g"
  by (simp add: unblocked_def false_premise_blocker_def)
lemma different_reading_can_proceed:
  "goal_interpretation g = 4 \<Longrightarrow>
    unblocked (r\<lparr>request_blockers:=[false_premise_blocker]\<rparr>) g"
  by (simp add: unblocked_def false_premise_blocker_def)
lemma helpful_act_can_render_without_claim_evidence:
  "authoritative_render s rid
    \<lparr>act_kind=Help, proposed_commentary=[], assertions=[]\<rparr> =
    Some (ShownAct Help [])"
  by (simp add: authoritative_render_def assertions_licensed_def
    render_act_def render_assertions_def)
lemma actual_execution_dependency_cannot_disappear:
  "\<not> rendering_licensed scoped_claim
    (render_claim (scoped_claim\<lparr>executable_generation:=NoExecution\<rparr>))"
  by (simp add: rendering_licensed_def claim_rendering_correspondence scoped_claim_def)
lemma pending_computation_is_not_user_question:
  "render_outcome (AwaitingOutput sid) = ShownAwaitingOutput sid \<and>
    render_outcome (AwaitingOutput sid) \<noteq> ShownNeedsInput []"
  by simp
lemma candidate_ready_is_not_a_claim:
  "render_outcome (ArtifactReady candidate)=ShownArtifactReady candidate \<and>
    render_outcome (ArtifactReady candidate) \<noteq> ShownAccepted clauses evidence \<and>
    \<not> accepted (ArtifactReady candidate)"
  by simp
lemma artifact_requirement_roundtrip_is_nonassertional:
  "read_requirement (render_requirement (ArtifactRequirement a))=Some (ArtifactRequirement a)"
  "render_requirement (ArtifactRequirement a) \<noteq> ShownClaimRequirement cs"
  by (simp_all add: requirement_rendering_correspondence)

end
