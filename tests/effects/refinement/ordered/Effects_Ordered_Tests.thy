theory Effects_Ordered_Tests
  imports Veri7vn_Effects_Indexed_Refinement.Effects_Indexed_Refinement
begin

definition ordered_fixture_value :: "nat \<Rightarrow> nat list \<Rightarrow> retained_value" where
  "ordered_fixture_value key deps = \<lparr>retained_id=key,retained_owner=WorkspaceShared,
    retained_dependencies=deps,retained_read_dependencies=[],retained_access_requirements=[],retained_payload=key\<rparr>"

lemma ordered_empty_duplicates:
  "indexed_forget_closure_ordered [] [2,2,1] = Some [2,2,1]" by eval
lemma ordered_seed_self_reappend:
  "indexed_forget_closure_ordered [ordered_fixture_value 1 [0],ordered_fixture_value 0 []] [0] =
    Some [1,0]" by eval
lemma ordered_seed_only_reappend:
  "indexed_forget_closure_ordered [ordered_fixture_value 1 [],ordered_fixture_value 0 []] [0,1] =
    Some [1,0]" by eval
lemma dependency_only_candidate_counterexample:
  "indexed_forget_closure [ordered_fixture_value 1 [0],ordered_fixture_value 0 [],ordered_fixture_value 2 [1]]
      [0,2,0] = Some [0,1,2] \<and>
    forget_closure [ordered_fixture_value 1 [0],ordered_fixture_value 0 [],ordered_fixture_value 2 [1]]
      [0,2,0] = Some [1,0,2]" by eval
lemma ordered_exact_counterexample_repair:
  "indexed_forget_closure_ordered [ordered_fixture_value 1 [0],ordered_fixture_value 0 [],ordered_fixture_value 2 [1]]
      [0,2,0] = forget_closure
        [ordered_fixture_value 1 [0],ordered_fixture_value 0 [],ordered_fixture_value 2 [1]] [0,2,0]" by eval
lemma ordered_duplicate_record_self_reappend:
  "indexed_forget_closure_ordered [ordered_fixture_value 2 [0],ordered_fixture_value 1 [2],ordered_fixture_value 2 []]
      [0] = forget_closure [ordered_fixture_value 2 [0],ordered_fixture_value 1 [2],ordered_fixture_value 2 []] [0]" by eval
lemma ordered_cycle_duplicates:
  "indexed_forget_closure_ordered [ordered_fixture_value 2 [1,1],ordered_fixture_value 1 [2],
      ordered_fixture_value 2 [0],ordered_fixture_value 3 [2]] [0,0] =
    forget_closure [ordered_fixture_value 2 [1,1],ordered_fixture_value 1 [2],
      ordered_fixture_value 2 [0],ordered_fixture_value 3 [2]] [0,0]" by eval
lemma ordered_missing_seed:
  "indexed_forget_closure_ordered [ordered_fixture_value 0 [4],ordered_fixture_value 1 [0]] [4,5,4] =
    Some [5,4,0,1]" by eval

ML \<open>val _ = writeln "INDEXED_EFFECTS ordered_counterexample_repair PASS";\<close>
end
