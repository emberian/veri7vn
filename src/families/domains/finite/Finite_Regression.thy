theory Finite_Regression
  imports Finite_Plans
begin
lemma draw_replacement_changes_probability:
  "all_success_draws True 2 4 2 = Some (1/4) \<and>
   all_success_draws False 2 4 2 = Some (1/6)"
  by code_simp
lemma two_dice_seven:
  "dice_total_probability 6 2 7 = Some (1/6)"
  by code_simp
lemma impossible_face_regression:
  "die_at_least_one 6 10 7 = Some 0"
  by (simp add: die_at_least_one_def)
lemma sample_population_differ:
  "exact_variance PopulationVariance [0,2] = Some 1 \<and>
   exact_variance SampleVariance [0,2] = Some 2"
  by code_simp
lemma tied_modes_remain_collection:
  "set (exact_modes [1,1,2,2,3]) = {1,2}"
  by (simp add: exact_modes_def)
lemma singleton_sample_undefined:
  "exact_variance SampleVariance [x] = None"
  by (simp add: exact_variance_def Let_def)
lemma allele_case_retained:
  "cross_probability (CHR ''A'',CHR ''a'') (CHR ''A'',CHR ''a'')
    (\<lambda>(a,b). a = CHR ''a'' \<and> b = CHR ''a'') = Some (1/4)"
  by code_simp
lemma incomplete_plan_refused:
  "registered_finite_dispatch (FiniteCall (PopulationEvent PartialPopulation [1])
     [RationalCollection [1,2]] []) = FiniteIncomplete"
  by simp
lemma named_selection_order_preserved:
  "exact_choose 2 5 = None \<and> exact_permutations 2 5 = None"
  by (simp add: exact_choose_def exact_permutations_def)
lemma centered_variance_plan_retains_conditions:
  "finite_run_checked () 2 [(0,(RationalCollection [0,2],[90]))]
    [\<lparr>node_id=1,node_operation=Centered,node_inputs=[0],retained_premises=[91]\<rparr>,
     \<lparr>node_id=2,node_operation=Variance SampleVariance,node_inputs=[1],retained_premises=[92]\<rparr>] =
   Some [(1,NodeValue (RationalCollection [-1,1]) [91,90]),
         (2,NodeValue (RationalValue 2) [92,91,90])]"
  by code_simp
lemma zscore_refuses_zero_scale:
  "exact_zscore 5 2 0 = None"
  by (simp add: exact_zscore_def)
end
