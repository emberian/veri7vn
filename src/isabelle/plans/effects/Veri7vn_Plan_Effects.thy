theory Veri7vn_Plan_Effects
  imports "Veri7vn_Plans.Veri7vn_Plans"
    "Veri7vn_Authority.Veri7vn_Authority"
begin

text \<open>A suspension can propose only the authority machine's StageIntent
operation. No arbitrary privileged event is accepted from an effect node.
Unresolved premises block submission; this translation cannot discharge them or
license execution. The actual effect-family primitive still needs its native bridge.\<close>
fun authority_proposal :: "('v, nat \<times> effect_intent) node_result \<Rightarrow>
    (event \<times> nat list) option" where
  "authority_proposal (NodeSuspended (batch,intent) conditions) =
    (if conditions = [] then Some (StageIntent batch intent, []) else None)" |
  "authority_proposal _ = None"

lemma suspension_keeps_exact_intent:
  "authority_proposal (NodeSuspended (batch,intent) []) =
    Some (StageIntent batch intent, [])"
  by simp

lemma unresolved_effect_conditions_block:
  "conditions \<noteq> [] \<Longrightarrow>
   authority_proposal (NodeSuspended (batch,intent) conditions) = None"
  by simp

lemma proposed_intent_still_checked:
  assumes "authority_proposal result = Some (StageIntent batch intent, conditions)"
    "\<not> can_stage s \<or> \<not> intent_permitted s intent \<or>
      (\<exists>a\<in>set (attempts s). attempt_id (attempt_intent a) = attempt_id intent)"
  shows "step s (StageIntent batch intent) = (s,[Rejected 4])"
  using assms by simp

lemma permitted_intent_only_stages:
  assumes "can_stage s" "intent_permitted s intent"
    "\<forall>a\<in>set (attempts s). attempt_id (attempt_intent a) \<noteq> attempt_id intent"
    "batch \<notin> set (issued_batches s)"
  shows "step s (StageIntent batch intent) =
    (s\<lparr>pending_batch := Some \<lparr>batch_id = batch, expected_revision = revision s,
       batch_epoch = authority_epoch s, batch_delta = RecordIntent intent\<rparr>,
       issued_batches := batch # issued_batches s\<rparr>,
     [Persist \<lparr>batch_id = batch, expected_revision = revision s,
       batch_epoch = authority_epoch s, batch_delta = RecordIntent intent\<rparr>])"
  using assms by (simp add: stage_def Let_def)

lemma staging_never_dispatches:
  "ClaimStart intent epoch \<notin> set (snd (step s (StageIntent batch proposed)))"
  by (simp add: stage_def Let_def split: if_splits)

text \<open>Even the successful case emits Persist, not ClaimStart. DurableAck and
ClaimAndStart remain separate generated transitions under the host trace contract.
A repeated or cancelled/retired request can still be rejected by current authority.\<close>
end
