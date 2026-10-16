theory Source_Semantics
  imports Main
begin

datatype sample_origin = Measured | Simulated | Unknown_Origin
datatype 'a reading = Valid 'a | Missing | Rejected string
datatype clock_basis = Wall string | Monotonic string | Source_Event string
record clock_reading =
  basis :: clock_basis
  ticks :: int
record 'a observation =
  source_id :: string
  sequence_id :: nat
  configuration :: string
  schema_version :: string
  origin :: sample_origin
  event_clock :: "clock_reading option"
  receipt_clock :: clock_reading
  payload :: "'a reading"
  qualifiers :: "string list"
  raw_reference :: "string option"

text \<open>Receipt updates preserve the source event and its configuration. Missing and
rejected observations remain members of the selected population.\<close>
definition repoll where
  "repoll now obs = obs\<lparr>receipt_clock := now\<rparr>"
lemma repoll_preserves_event [simp]: "event_clock (repoll now obs) = event_clock obs"
  by (simp add: repoll_def)
lemma repoll_preserves_payload [simp]: "payload (repoll now obs) = payload obs"
  by (simp add: repoll_def)
lemma repoll_preserves_origin [simp]: "origin (repoll now obs) = origin obs"
  by (simp add: repoll_def)
lemma repoll_preserves_configuration [simp]:
  "configuration (repoll now obs) = configuration obs"
  by (simp add: repoll_def)

definition event_in_window where
  "event_in_window cb lo hi obs \<longleftrightarrow>
    (\<exists>c. event_clock obs = Some c \<and> basis c = cb \<and> lo \<le> ticks c \<and> ticks c < hi)"
definition window_population where
  "window_population cb lo hi xs = filter (event_in_window cb lo hi) xs"
definition valid_values where
  "valid_values xs = List.map_filter (\<lambda>obs. case payload obs of Valid x \<Rightarrow> Some x | _ \<Rightarrow> None) xs"
lemma repoll_window [simp]:
  "event_in_window cb lo hi (repoll now obs) = event_in_window cb lo hi obs"
  by (simp add: event_in_window_def repoll_def)
lemma missing_in_population:
  "obs \<in> set xs \<Longrightarrow> event_in_window cb lo hi obs \<Longrightarrow>
   payload obs = Missing \<Longrightarrow> obs \<in> set (window_population cb lo hi xs)"
  by (simp add: window_population_def)

text \<open>A partial collection has both an observed list and a specified candidate
universe. Coverage is relative to a predicate; a witness alone needs no closure.\<close>
definition candidates where "candidates P xs = filter P xs"
definition covers where
  "covers U P xs \<longleftrightarrow> {x \<in> U. P x} = set (candidates P xs)"
lemma witness_sound:
  "x \<in> set (candidates P xs) \<Longrightarrow> P x"
  by (simp add: candidates_def)
lemma covered_absence:
  "covers U P xs \<Longrightarrow> candidates P xs = [] \<Longrightarrow> \<not> (\<exists>x\<in>U. P x)"
  by (auto simp: covers_def)
lemma covered_uniqueness:
  "covers U P xs \<Longrightarrow> set (candidates P xs) = {x} \<Longrightarrow>
   {y \<in> U. P y} = {x}"
  by (simp add: covers_def)
lemma covered_count:
  "covers U P xs \<Longrightarrow> card {x \<in> U. P x} = length (remdups (candidates P xs))"
  by (simp add: covers_def length_remdups_card_conv)
lemma covered_extremum:
  "covers U P xs \<Longrightarrow> best \<in> set (candidates P xs) \<Longrightarrow>
   (\<forall>x\<in>set (candidates P xs). score x \<le> score best) \<Longrightarrow>
   best \<in> U \<and> P best \<and> (\<forall>x\<in>U. P x \<longrightarrow> score x \<le> score best)"
  by (auto simp: covers_def)
lemma covered_ranking:
  "covers U P xs \<Longrightarrow> set ranked = set (candidates P xs) \<Longrightarrow>
   sorted_wrt (\<lambda>x y. score x \<ge> score y) ranked \<Longrightarrow>
   set ranked = {x \<in> U. P x} \<and> sorted_wrt (\<lambda>x y. score x \<ge> score y) ranked"
  by (auto simp: covers_def)

text \<open>Adoption carries an explicit scope and all source qualifiers. Its truth
premise is not discharged by the presence of a source report.\<close>
record ('a, 'scope) adoption =
  adopted_report :: "'a observation"
  adoption_scope :: 'scope
  adoption_policy :: string

definition adopted_premise where
  "adopted_premise meaning a = (case payload (adopted_report a) of
      Valid x \<Rightarrow> meaning (adoption_scope a) (qualifiers (adopted_report a)) x
    | _ \<Rightarrow> False)"
lemma adoption_elimination:
  "adopted_premise meaning a \<Longrightarrow> payload (adopted_report a) = Valid x \<Longrightarrow>
   meaning (adoption_scope a) (qualifiers (adopted_report a)) x"
  by (simp add: adopted_premise_def)
lemma conditional_adoption:
  "(adopted_premise meaning a \<Longrightarrow> conclusion) \<Longrightarrow>
   adopted_premise meaning a \<longrightarrow> conclusion"
  by blast
lemma conflicting_reports_are_consistent:
  "\<exists>xs :: bool reading list. Valid True \<in> set xs \<and> Valid False \<in> set xs"
  by (rule exI[of _ "[Valid True, Valid False]"]) simp

record ('snapshot, 'state, 'time, 'policy) source_pin =
  snapshot :: 'snapshot
  state_reads :: 'state
  evaluation_clock :: 'time
  selection_adoption_policy :: 'policy

definition reusable where "reusable old new \<longleftrightarrow> old = new"
lemma whole_pin_recomputation:
  "reusable old new \<Longrightarrow> compute old = compute new"
  by (simp add: reusable_def)
lemma snapshot_change_invalidates:
  "snapshot old \<noteq> snapshot new \<Longrightarrow> \<not> reusable old new"
  by (auto simp: reusable_def)
lemma clock_change_invalidates:
  "evaluation_clock old \<noteq> evaluation_clock new \<Longrightarrow> \<not> reusable old new"
  by (auto simp: reusable_def)


text \<open>External execution observations and native query semantics are distinct.
NULL is a typed cell value, and a successful prefix remains incomplete.\<close>
datatype 'a nullable = SQL_Null | SQL_Value 'a
datatype 'a engine_outcome = Rows "'a list" bool | Syntax_Rejection string
  | Runtime_Rejection string | Missing_Input string | Budget_Exhausted
  | Platform_Failure string
record ('query, 'row) engine_observation =
  engine_name :: string
  engine_version :: string
  engine_configuration :: string
  engine_input_snapshot :: string
  engine_query :: 'query
  engine_result :: "'row engine_outcome"

definition native_query_agreement where
  "native_query_agreement semantics observed \<longleftrightarrow>
    (case engine_result observed of Rows rows complete \<Rightarrow>
      complete \<and> rows = semantics (engine_query observed) | _ \<Rightarrow> False)"
lemma engine_success_requires_bridge:
  "native_query_agreement semantics observed \<Longrightarrow>
   engine_result observed = Rows rows complete \<Longrightarrow>
   complete \<and> rows = semantics (engine_query observed)"
  by (simp add: native_query_agreement_def)
lemma prefix_not_complete:
  "engine_result observed = Rows rows False \<Longrightarrow>
   \<not> native_query_agreement semantics observed"
  by (simp add: native_query_agreement_def)

text \<open>Finite policy evaluation retains applicability, supplied observations,
assumptions and unresolved conditions. A positive subset cannot license the
complete policy. These judgments are domain-parametric, not policy truth tokens.\<close>
record ('rule, 'input) policy_evaluation =
  policy_rules :: "'rule list"
  supplied_observations :: 'input
  applicable_rules :: "'rule list"
  checked_rules :: "'rule list"
  unresolved_rules :: "'rule list"

definition policy_licensed where
  "policy_licensed applicable holds e \<longleftrightarrow>
    set (applicable_rules e) = {r \<in> set (policy_rules e). applicable (supplied_observations e) r} \<and>
    set (checked_rules e) = set (applicable_rules e) \<and>
    unresolved_rules e = [] \<and>
    (\<forall>r\<in>set (checked_rules e). holds (supplied_observations e) r)"
lemma licensed_policy_all_applicable:
  "policy_licensed applicable holds e \<Longrightarrow>
   r \<in> set (policy_rules e) \<Longrightarrow> applicable (supplied_observations e) r \<Longrightarrow>
   holds (supplied_observations e) r"
  by (auto simp: policy_licensed_def)
lemma unresolved_policy_not_licensed:
  "unresolved_rules e \<noteq> [] \<Longrightarrow> \<not> policy_licensed applicable holds e"
  by (simp add: policy_licensed_def)

end
