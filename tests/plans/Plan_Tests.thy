theory Plan_Tests
  imports "Veri7vn_Plans.Veri7vn_Plans"
begin

lemma meaningful_booleans_survive:
  "prune_observations id [True, False, True] = [True, False]"
  by simp

lemma exact_payloads_survive:
  "prune_observations id [(1::int, 10::nat),(11,100),(1,10)] = [(1,10),(11,100)]"
  by simp

lemma resource_histories_survive:
  "prune_observations id [(True,0::nat),(True,1)] = [(True,0),(True,1)]"
  by simp

lemma finite_continuations_detect_difference:
  "\<not> finite_continuation_equivalent (\<lambda>n::nat. n > 1)
    (\<lambda>p n. p+n) [1] 0 1"
  by (simp add: finite_continuation_equivalent_def continuation_key_def)

lemma condition_normalization_first_occurrences:
  "merge_conditions [1::nat,2,1,3,2] = [1,2,3]"
  by (simp add: merge_conditions_def)

definition search_repair_fixture where
  "search_repair_fixture =
    (merge_conditions [1::nat,2,1,3,2] = [1,2,3] \<and>
     prune_observations id [True, False, True] = [True, False] \<and>
     prune_observations id [(1::int,10::nat),(11,100),(1,10)] = [(1,10),(11,100)] \<and>
     prune_observations id [(True,0::nat),(True,1)] = [(True,0),(True,1)] \<and>
     \<not> finite_continuation_equivalent (\<lambda>n::nat. n > 1)
       (\<lambda>p n. p+n) [1] 0 1)"
ML \<open>
  if @{code search_repair_fixture} then
    writeln "PLANS polarity_exact_history_continuation PASS"
  else error "generated search repair fixture failed"
\<close>
end
