theory Veri7vn_Strategies
  imports "Veri7vn_Plans.Veri7vn_Plan_Search"
begin

datatype strategy_action = Retrieve nat | Apply nat | Simplify "nat list" |
  Split | Introduce | SeekWitness nat | Counterexample nat | Conjecture nat |
  SynthesizeCatalogue nat | SynthesizePipeline nat | EnumerateTyped nat | Refine nat

datatype proposal_scope = FeasibleWitness | ConditionalCandidate "nat list" |
  FiniteComplete "nat list" | EmpiricalAgreement "nat list"

datatype 'a strategy_reply = Candidate 'a proposal_scope | RouteFailure nat |
  ScopedBlocker nat | RefutationProposal 'a | NoProposal

record ('goal,'artifact) strategy_event =
  event_goal :: 'goal
  event_action :: strategy_action
  event_reply :: "'artifact strategy_reply"

record ('goal,'artifact) strategy_state =
  pending_steps :: "('goal \<times> strategy_action) list"
  strategy_trace :: "('goal,'artifact) strategy_event list"
  charged_steps :: nat
  retained_candidates :: "('goal \<times> 'artifact \<times> proposal_scope) list"
  retained_refutations :: "('goal \<times> 'artifact) list"
  route_failures :: "('goal \<times> nat) list"
  goal_blockers :: "('goal \<times> nat) list"

datatype stop_reason = WorklistFinished | BudgetStopped | Cancelled

definition record_reply where
  "record_reply goal action reply s =
    (let t = s\<lparr>strategy_trace := strategy_trace s @
      [\<lparr>event_goal=goal,event_action=action,event_reply=reply\<rparr>],
      charged_steps := Suc (charged_steps s)\<rparr>
     in case reply of Candidate value scope \<Rightarrow>
       t\<lparr>retained_candidates := retained_candidates t @ [(goal,value,scope)]\<rparr>
     | RefutationProposal value \<Rightarrow>
       t\<lparr>retained_refutations := retained_refutations t @ [(goal,value)]\<rparr>
     | RouteFailure reason \<Rightarrow>
       t\<lparr>route_failures := route_failures t @ [(goal,reason)]\<rparr>
     | ScopedBlocker reason \<Rightarrow>
       t\<lparr>goal_blockers := goal_blockers t @ [(goal,reason)]\<rparr>
     | NoProposal \<Rightarrow> t)"

fun schedule where
  "schedule run cancelled 0 s =
    (s, if cancelled then Cancelled else if pending_steps s = []
      then WorklistFinished else BudgetStopped)" |
  "schedule run cancelled (Suc fuel) s =
    (if cancelled then (s,Cancelled) else case pending_steps s of
      [] \<Rightarrow> (s,WorklistFinished) | (goal,action)#rest \<Rightarrow>
        schedule run cancelled fuel
          (record_reply goal action (run goal action)
            (s\<lparr>pending_steps := rest\<rparr>)))"

lemma record_reply_positive_charge:
  "charged_steps (record_reply goal action reply s) = Suc (charged_steps s)"
  by (simp add: record_reply_def Let_def split: strategy_reply.splits)
lemma record_reply_preserves_pending:
  "pending_steps (record_reply goal action reply s) = pending_steps s"
  by (simp add: record_reply_def Let_def split: strategy_reply.splits)
lemma route_failure_is_not_refutation:
  "retained_refutations (record_reply goal action (RouteFailure reason) s) =
    retained_refutations s"
  by (simp add: record_reply_def Let_def)
lemma candidate_is_not_refutation:
  "retained_refutations (record_reply goal action (Candidate value scope) s) =
    retained_refutations s"
  by (simp add: record_reply_def Let_def)
lemma cancelled_does_no_work:
  "schedule run True fuel s = (s,Cancelled)"
  by (cases fuel) simp_all
lemma schedule_charge_bound:
  "charged_steps (fst (schedule run cancelled fuel s)) \<le> charged_steps s + fuel"
proof (induction fuel arbitrary: s)
  case 0 then show ?case by simp
next
  case (Suc fuel)
  show ?case
  proof (cases cancelled)
    case True then show ?thesis by simp
  next
    case False
    show ?thesis
    proof (cases "pending_steps s")
      case Nil then show ?thesis using False by simp
    next
      case (Cons step rest)
      obtain goal action where step: "step=(goal,action)" by (cases step) auto
      let ?next = "record_reply goal action (run goal action)
        (s\<lparr>pending_steps := rest\<rparr>)"
      have bound: "charged_steps (fst (schedule run cancelled fuel ?next))
        \<le> charged_steps ?next + fuel" by (rule Suc.IH)
      have charge: "charged_steps ?next = Suc (charged_steps s)"
        by (simp add: record_reply_positive_charge)
      show ?thesis using bound False Cons step charge by simp
    qed
  qed
qed

text \<open>The scheduler records proposals. It has no accepted theorem/state field.
Its run parameter specifies family behavior for this model, not a runtime callback
or an authority premise. Runtime proof search below is a fixed native producer;
receiver reconstruction and generated authority remain separate consumers.\<close>
end
