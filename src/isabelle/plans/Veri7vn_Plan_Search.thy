theory Veri7vn_Plan_Search
  imports Main
begin

text \<open>The value carrier is the installed bundle's concrete packet carrier.
It is never reconstructed from display text. The context carrier includes the
complete pinned request observation (state, time/clock, policy, dependencies).
History and resource consumption are observable even when returned values agree.\<close>
record ('v,'context,'history,'guard) search_observation =
  observed_values :: "'v list"
  observed_context :: 'context
  observed_history :: "'history list"
  observed_guards :: "'guard list"
  consumed_work :: nat
  remaining_work :: nat
  unresolved_goals :: "nat list"
  scoped_failures :: "(nat \<times> nat) list"

text \<open>Only exact observations may be merged by this first rule. In particular,
Boolean polarity, exact numeric packet payloads, partial collection metadata and
conditional premises remain in the value carrier. No rounded display key occurs.\<close>
definition observation_equivalent where
  "observation_equivalent observe x y \<longleftrightarrow> observe x = observe y"

fun prune_observations where
  "prune_observations observe [] = []" |
  "prune_observations observe (x # xs) =
    x # prune_observations observe (filter (\<lambda>y. observe y \<noteq> observe x) xs)"

lemma prune_observations_subset:
  "set (prune_observations observe xs) \<subseteq> set xs"
  by (induction observe xs rule: prune_observations.induct) auto

lemma prune_observations_coverage:
  "observe ` set (prune_observations observe xs) = observe ` set xs"
  by (induction observe xs rule: prune_observations.induct) auto

lemma prune_observations_distinct:
  "distinct (map observe (prune_observations observe xs))"
  by (induction observe xs rule: prune_observations.induct)
     (auto dest: subsetD[OF prune_observations_subset])

lemma finite_search_exists_preserved:
  "(\<exists>x\<in>set (prune_observations observe xs). P (observe x)) =
   (\<exists>x\<in>set xs. P (observe x))"
  using prune_observations_coverage[of observe xs] by (metis image_iff)

text \<open>Terminal observation equality alone does not justify merging live search
states. This executable sufficient criterion compares the full continuation result
for every member of a named finite continuation list, with the current observation
also retained. Completeness is only relative to this explicit list. The scheduler
must not use it for continuations outside that list.\<close>
definition continuation_key where
  "continuation_key observe run continuations x =
    (observe x, map (\<lambda>p. observe (run p x)) continuations)"

definition finite_continuation_equivalent where
  "finite_continuation_equivalent observe run continuations x y \<longleftrightarrow>
    continuation_key observe run continuations x =
    continuation_key observe run continuations y"

lemma continuation_equivalence_sound:
  assumes "finite_continuation_equivalent observe run continuations x y"
    "p \<in> set continuations"
  shows "observe (run p x) = observe (run p y)"
  using assms unfolding finite_continuation_equivalent_def continuation_key_def
  by (auto simp: map_eq_conv)

lemma finite_continuation_pruning:
  "continuation_key observe run continuations `
      set (prune_observations (continuation_key observe run continuations) xs) =
    continuation_key observe run continuations ` set xs"
  by (rule prune_observations_coverage)

end
