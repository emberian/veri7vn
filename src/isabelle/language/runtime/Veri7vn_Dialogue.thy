theory Veri7vn_Dialogue
  imports Veri7vn_Interpretation.Veri7vn_Rendering
begin

text \<open>Routing policy orders capabilities only after interpretation selection.
An addressed source restricts eligible capabilities; a general mathematical or
dictionary route cannot silently answer a personal-source question. Policy versions
are pinned by the caller's installed native policy, not accepted from a proposal.
No new claim, binding, blocker, source registry or adoption carrier is introduced.\<close>
record dialogue_policy =
  dialogue_policy_version :: nat
  positive_precedence :: "nat list"
  addressed_capabilities :: "nat list option"

definition dialogue_eligible where
  "dialogue_eligible p s r = filter (\<lambda>g.
    \<not> request_cancelled r \<and> goal_outcome g \<noteq> Cancelled \<and>
    unblocked r g \<and> goal_ready_live s r g \<and>
    parent_accessible s r \<and> child_accessible s g \<and>
    (case addressed_capabilities p of None \<Rightarrow> True
      | Some allowed \<Rightarrow> goal_capability g \<in> set allowed)) (request_goals r)"

definition dialogue_readings where
  "dialogue_readings p s r = remdups (map goal_interpretation (dialogue_eligible p s r))"

definition dialogue_clarification where
  "dialogue_clarification p s r = recognize (dialogue_readings p s r)"

fun precedence_rank :: "nat list \<Rightarrow> nat \<Rightarrow> nat" where
  "precedence_rank [] c = 0" |
  "precedence_rank (a # rest) c = (if a=c then 0 else Suc (precedence_rank rest c))"

text \<open>The immutable requirement metadata and interpretation are fixed before
fallback. This conservative relation does not establish equivalence of separately
elaborated native predicates; the fixed native proposal adapter must retain that
association before reservation. Equal priority retains all candidates.\<close>
definition dialogue_routes where
  "dialogue_routes p s r i required =
    (let candidates = filter (\<lambda>g. goal_interpretation g = i \<and>
       same_requirement (goal_required g) required) (dialogue_eligible p s r)
     in filter (\<lambda>g. \<forall>h\<in>set candidates.
       precedence_rank (positive_precedence p) (goal_capability g) \<le>
       precedence_rank (positive_precedence p) (goal_capability h)) candidates)"

definition dialogue_select where
  "dialogue_select p s r expected_version receipt required =
    (if dialogue_policy_version p = expected_version \<and>
      alternatives receipt = dialogue_readings p s r \<and> selection_valid receipt
     then dialogue_routes p s r (chosen receipt) required else [])"

definition dialogue_current_select where
  "dialogue_current_select p s rid expected_version receipt required =
    concat (map (\<lambda>r. if request_id r = rid \<and> request_fresh s r
      then dialogue_select p s r expected_version receipt required else []) (requests s))"

lemma current_route_has_native_request:
  "g \<in> set (dialogue_current_select p s rid v receipt required) \<Longrightarrow>
    \<exists>r\<in>set (requests s). request_id r = rid \<and> request_fresh s r \<and>
      g \<in> set (dialogue_select p s r v receipt required)"
  by (auto simp: dialogue_current_select_def split: if_splits)

lemma selected_route_unblocked:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow> unblocked r g"
  by (auto simp: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def split: if_splits)

lemma selected_route_parent_accessible:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow> parent_accessible s r"
  by (auto simp: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def split: if_splits)

lemma selected_route_child_accessible:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow> child_accessible s g"
  by (auto simp: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def split: if_splits)

lemma selected_route_not_cancelled:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow> goal_outcome g \<noteq> Cancelled"
  by (auto simp: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def split: if_splits)

lemma selected_route_same_requirement:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow>
    goal_interpretation g = chosen receipt \<and> same_requirement (goal_required g) required"
  by (auto simp: dialogue_select_def dialogue_routes_def Let_def split: if_splits)

lemma addressed_route_preserved:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow>
    addressed_capabilities p = Some allowed \<Longrightarrow>
    goal_capability g \<in> set allowed"
  by (auto simp: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def split: if_splits)

lemma unavailable_address_no_route:
  "addressed_capabilities p = Some [] \<Longrightarrow>
    dialogue_select p s r v receipt required = []"
  by (simp add: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def)

lemma stale_policy_no_route:
  "dialogue_policy_version p \<noteq> v \<Longrightarrow>
    dialogue_select p s r v receipt required = []"
  by (simp add: dialogue_select_def)

lemma scoped_veto_no_fallback:
  assumes "b \<in> set (request_blockers r)"
    "blocked_scope b = InterpretationScope (goal_interpretation g)"
  shows "g \<notin> set (dialogue_select p s r v receipt required)"
  using assms selected_route_unblocked
  by (fastforce simp: unblocked_def list_all_iff)

lemma all_ambiguous_readings_retained:
  "dialogue_clarification p s r = Ambiguous xs \<Longrightarrow>
    xs = dialogue_readings p s r \<and> length xs \<ge> 2"
  unfolding dialogue_clarification_def
  using ambiguity_retains_all[of "dialogue_readings p s r" xs] by auto

text \<open>Only final current native bindings can seed a follow-up. This function
produces the existing authority event; the durable writer still checks and commits
it. Transcript recording is independent, as in record_utterance. Dependency order
uses goal_ready_live, which rechecks previously accepted parts after revocation.\<close>
definition dialogue_adoption where
  "dialogue_adoption s rid nonce d =
    (if adoption_permitted s rid d then Some (StageAdoption nonce rid d) else None)"

lemma dialogue_adopts_only_live:
  assumes "dialogue_adoption s rid nonce d = Some ev"
    "b \<in> set (adoption_bindings d)"
  shows "b \<in> set (visible_bindings s) \<and> binding_licensed s b \<and> binding_request b = rid"
  using assms by (auto simp: dialogue_adoption_def adoption_permitted_def list_all_iff split: if_splits)

lemma withheld_binding_not_adopted:
  assumes "b \<in> set (adoption_bindings d)" "\<not> binding_licensed s b"
  shows "dialogue_adoption s rid nonce d = None"
  using assms by (auto simp: dialogue_adoption_def adoption_permitted_def list_all_iff)

lemma dependent_route_needs_live_inputs:
  "g \<in> set (dialogue_select p s r v receipt required) \<Longrightarrow> goal_ready_live s r g"
  by (auto simp: dialogue_select_def dialogue_routes_def dialogue_eligible_def Let_def split: if_splits)

export_code dialogue_clarification dialogue_select dialogue_current_select dialogue_adoption render_parts
  authoritative_render in SML module_name Veri7vn_Dialogue

end
