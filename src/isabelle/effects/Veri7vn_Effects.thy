theory Veri7vn_Effects
  imports Veri7vn_Codegen.Veri7vn_Codegen Veri7vn_Source_Semantics.Source_Semantics
begin

text \<open>Pure session primitives for the single authority reducer. These functions
carry no independent acceptance authority and must be called by its guarded events.\<close>

record observation_context =
  observed_session :: nat
  observed_version :: nat
  evaluation_time :: "clock_reading option"
  observed_reads :: "(nat \<times> nat) list"
record freshness_window =
  fresh_from :: clock_reading
  fresh_through :: int

definition fresh_at :: "freshness_window \<Rightarrow> clock_reading \<Rightarrow> bool" where
  "fresh_at w now \<longleftrightarrow> basis (fresh_from w) = basis now \<and>
    ticks (fresh_from w) \<le> ticks now \<and> ticks now \<le> fresh_through w"

definition reads_match :: "(nat \<times> nat) list \<Rightarrow> (nat \<times> nat) list \<Rightarrow> bool" where
  "reads_match required current \<longleftrightarrow> distinct (map fst required) \<and>
    distinct (map fst current) \<and> list_all (\<lambda>p. p \<in> set current) required"

datatype observation_requirement = StateTimeUnused |
  RequireObservation observation_context "freshness_window option" |
  RequireAccess observation_context "freshness_window option"

definition observation_fields_fresh :: "observation_context \<Rightarrow> observation_context \<Rightarrow>
    freshness_window option \<Rightarrow> bool" where
  "observation_fields_fresh current observed window \<longleftrightarrow>
    observed_session observed = observed_session current \<and>
    reads_match (observed_reads observed) (observed_reads current) \<and>
    (case window of None \<Rightarrow> True | Some w \<Rightarrow>
      (case (evaluation_time observed, evaluation_time current) of
        (Some original, Some now) \<Rightarrow>
          fresh_from w = original \<and> basis original = basis now \<and>
          ticks original \<le> ticks now \<and> fresh_at w now |
        _ \<Rightarrow> False))"

text \<open>RequireAccess is reserved for the authenticated retention-policy producer.
It preserves actual session incarnation/read pins/clock origin/expiry, while allowing
conversational CAS to advance. Requests keep RequireObservation's full CAS guard.\<close>
definition authority_fresh :: "observation_context \<Rightarrow> observation_requirement \<Rightarrow> bool" where
  "authority_fresh current required = (case required of StateTimeUnused \<Rightarrow> True |
    RequireObservation observed window \<Rightarrow>
      observed_version observed = observed_version current \<and>
      observation_fields_fresh current observed window |
    RequireAccess observed window \<Rightarrow> observation_fields_fresh current observed window)"

text \<open>Each cost is associated by admission with the actual registered code
profile/operation/step. Metadata equality alone is not that association.\<close>
record operation_cost =
  cost_profile :: nat
  cost_code_generation :: nat
  cost_operation :: nat
  cost_step :: nat
  cost_units :: nat

record fuel_account =
  fuel_owner :: nat
  fuel_remaining :: nat

definition charge_fuel :: "nat \<Rightarrow> nat \<Rightarrow> fuel_account \<Rightarrow> fuel_account option" where
  "charge_fuel owner cost a = (if owner = fuel_owner a \<and> 0 < cost \<and> cost \<le> fuel_remaining a
    then Some (a\<lparr>fuel_remaining := fuel_remaining a - cost\<rparr>) else None)"

datatype retention_scope = RequestLocal nat | SessionLocal nat | WorkspaceShared
record retained_value =
  retained_id :: nat
  retained_owner :: retention_scope
  retained_dependencies :: "nat list"
  retained_read_dependencies :: "nat list"
  retained_access_requirements :: "observation_requirement list"
  retained_payload :: nat
record 'a adopted_delta =
  adoption_request :: nat
  adoption_session :: nat
  adoption_expected_version :: nat
  adoption_bindings :: "'a list"
record 'a session_view =
  session_id :: nat
  session_version :: nat
  recorded_utterances :: "nat list"
  adopted_bindings :: "'a list"

definition record_utterance :: "nat \<Rightarrow> 'a session_view \<Rightarrow> 'a session_view" where
  "record_utterance u s = s\<lparr>recorded_utterances := recorded_utterances s @ [u]\<rparr>"

text \<open>The reducer supplies final arbitration's licensed binding identities.
A caller-provided list is not an implementation of that association.\<close>
definition adopt_answer :: "nat \<Rightarrow> 'a list \<Rightarrow> 'a adopted_delta \<Rightarrow> 'a session_view \<Rightarrow> 'a session_view option" where
  "adopt_answer owner licensed d s = (if adoption_request d = owner \<and> adoption_session d = session_id s \<and>
    adoption_expected_version d = session_version s \<and>
    list_all (\<lambda>b. b \<in> set licensed) (adoption_bindings d)
    then Some (s\<lparr>session_version := Suc (session_version s),
      adopted_bindings := adopted_bindings s @ adoption_bindings d\<rparr>) else None)"

definition directly_dependent :: "nat list \<Rightarrow> retained_value \<Rightarrow> bool" where
  "directly_dependent removed v \<longleftrightarrow> retained_id v \<in> set removed \<or>
    (\<exists>d \<in> set (retained_dependencies v). d \<in> set removed)"

fun dependency_closure :: "nat \<Rightarrow> retained_value list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "dependency_closure 0 values removed = removed" |
  "dependency_closure (Suc n) values removed = dependency_closure n values
    (remdups (removed @ map retained_id (filter (directly_dependent removed) values)))"

definition managed_closed :: "retained_value list \<Rightarrow> nat set \<Rightarrow> bool" where
  "managed_closed values X \<longleftrightarrow> (\<forall>v \<in> set values.
    (\<exists>d \<in> set (retained_dependencies v). d \<in> X) \<longrightarrow> retained_id v \<in> X)"

definition forget_closure :: "retained_value list \<Rightarrow> nat list \<Rightarrow> nat list option" where
  "forget_closure values removed = (let result = dependency_closure (length values) values removed
    in if list_all (\<lambda>d. d \<in> set result) removed \<and>
      list_all (\<lambda>v. list_all (\<lambda>d. d \<notin> set result) (retained_dependencies v) \<or>
        retained_id v \<in> set result) values then Some result else None)"

lemma dependency_closure_minimal:
  assumes "set removed \<subseteq> X" and "managed_closed values X"
  shows "set (dependency_closure n values removed) \<subseteq> X"
  using assms
proof (induction n arbitrary: removed)
  case 0 then show ?case by simp
next
  case (Suc n)
  have "set (remdups (removed @ map retained_id (filter (directly_dependent removed) values))) \<subseteq> X"
    using Suc.prems by (auto simp: directly_dependent_def managed_closed_def)
  then show ?case using Suc.IH Suc.prems(2) by simp
qed

lemma forget_closure_closed:
  "forget_closure values removed = Some result \<Longrightarrow>
    set removed \<subseteq> set result \<and> managed_closed values (set result)"
  by (auto simp: forget_closure_def Let_def list_all_iff managed_closed_def split: if_splits)

lemma forget_closure_minimal:
  "forget_closure values removed = Some result \<Longrightarrow> set removed \<subseteq> X \<Longrightarrow>
    managed_closed values X \<Longrightarrow> set result \<subseteq> X"
proof -
  assume accepted: "forget_closure values removed = Some result"
    and seeds: "set removed \<subseteq> X" and closed: "managed_closed values X"
  have subset: "set (dependency_closure (length values) values removed) \<subseteq> X"
    by (rule dependency_closure_minimal[OF seeds closed])
  from accepted have "result = dependency_closure (length values) values removed"
    by (auto simp: forget_closure_def Let_def split: if_splits)
  with subset show "set result \<subseteq> X" by simp
qed

datatype job_status = JobStopped | JobActive | JobRetired
record acquisition_job =
  job_id :: nat
  job_owner :: nat
  job_source :: nat
  job_capability :: nat
  job_budget :: fuel_account
  job_status :: job_status
  job_incarnation :: nat

text \<open>The authority supplies current source/capability access. Restart advances
an incarnation, so completion from the previous worker cannot update this job.\<close>
definition start_job :: "nat \<Rightarrow> bool \<Rightarrow> acquisition_job \<Rightarrow> acquisition_job option" where
  "start_job owner permitted j = (if owner = job_owner j \<and> permitted \<and>
    job_status j = JobStopped \<and> fuel_owner (job_budget j) = owner \<and>
    fuel_remaining (job_budget j) > 0 then Some (j\<lparr>job_status := JobActive,
      job_incarnation := Suc (job_incarnation j)\<rparr>) else None)"
definition stop_job :: "bool \<Rightarrow> acquisition_job \<Rightarrow> acquisition_job" where
  "stop_job retired j = j\<lparr>job_status := (if retired then JobRetired else JobStopped)\<rparr>"
definition job_completion_current :: "nat \<Rightarrow> acquisition_job \<Rightarrow> bool" where
  "job_completion_current incarnation j \<longleftrightarrow>
    job_status j = JobActive \<and> incarnation = job_incarnation j"

lemma stopped_no_completion:
  "\<not> job_completion_current incarnation (stop_job retired j)"
  by (simp add: job_completion_current_def stop_job_def)
lemma retired_no_restart:
  "job_status j = JobRetired \<Longrightarrow> start_job owner permitted j = None"
  by (simp add: start_job_def)

lemma changed_session_rejected:
  "observed_version observed \<noteq> observed_version current \<Longrightarrow>
    \<not> authority_fresh current (RequireObservation observed window)"
  by (simp add: authority_fresh_def)
lemma changed_read_rejected:
  "p \<in> set (observed_reads observed) \<Longrightarrow> p \<notin> set (observed_reads current) \<Longrightarrow>
    \<not> authority_fresh current (RequireObservation observed window)"
  by (auto simp: authority_fresh_def observation_fields_fresh_def reads_match_def list_all_iff)
lemma freshness_origin_preserved:
  "authority_fresh current (RequireObservation observed (Some w)) \<Longrightarrow>
    evaluation_time observed = Some (fresh_from w)"
  by (auto simp: authority_fresh_def observation_fields_fresh_def split: option.splits prod.splits)

lemma expired_observation_rejected:
  "evaluation_time current = Some now \<Longrightarrow> fresh_through w < ticks now \<Longrightarrow>
    \<not> authority_fresh current (RequireObservation observed (Some w))"
  by (auto simp: authority_fresh_def observation_fields_fresh_def fresh_at_def split: option.splits)
lemma unsupported_clock_rejected:
  "evaluation_time current = Some now \<Longrightarrow> basis (fresh_from w) \<noteq> basis now \<Longrightarrow>
    \<not> authority_fresh current (RequireObservation observed (Some w))"
  by (auto simp: authority_fresh_def observation_fields_fresh_def fresh_at_def split: option.splits)

lemma zero_cost_rejected:
  "charge_fuel owner 0 a = None"
  by (simp add: charge_fuel_def)
lemma charge_strictly_decreases:
  "charge_fuel owner cost a = Some b \<Longrightarrow> fuel_remaining b < fuel_remaining a"
  by (auto simp: charge_fuel_def split: if_splits)
lemma charge_wrong_owner:
  "owner \<noteq> fuel_owner a \<Longrightarrow> charge_fuel owner cost a = None"
  by (simp add: charge_fuel_def)
lemma charge_conserves:
  "charge_fuel owner cost a = Some b \<Longrightarrow>
    fuel_owner b = fuel_owner a \<and> fuel_remaining b + cost = fuel_remaining a"
  by (auto simp: charge_fuel_def split: if_splits)
lemma utterance_not_adoption:
  "adopted_bindings (record_utterance u s) = adopted_bindings s"
  by (simp add: record_utterance_def)
lemma adopt_stale_rejected:
  "adoption_expected_version d \<noteq> session_version s \<Longrightarrow> adopt_answer owner licensed d s = None"
  by (simp add: adopt_answer_def)
lemma adoption_licensed:
  "adopt_answer owner licensed d s = Some t \<Longrightarrow>
    set (adopted_bindings t) - set (adopted_bindings s) \<subseteq> set licensed"
  by (auto simp: adopt_answer_def list_all_iff split: if_splits)
lemma clock_origin_required:
  "basis (fresh_from w) \<noteq> basis now \<Longrightarrow> \<not> fresh_at w now"
  by (simp add: fresh_at_def)

export_code authority_fresh fresh_at reads_match charge_fuel record_utterance adopt_answer forget_closure
  start_job stop_job job_completion_current
  in SML module_name Veri7vn_Effects
end
