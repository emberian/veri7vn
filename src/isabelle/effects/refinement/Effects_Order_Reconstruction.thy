theory Effects_Order_Reconstruction
  imports Veri7vn_Effects_Closure.Effects_Closure_Totality
begin

definition fired_records :: "retained_value list \<Rightarrow> nat list \<Rightarrow> retained_value set" where
  "fired_records values removed = {v \<in> set values. directly_dependent removed v}"

definition ordered_reconstruction :: "retained_value list \<Rightarrow> nat list \<Rightarrow> nat set \<Rightarrow> nat list" where
  "ordered_reconstruction values seeds reached = remdups
    (seeds @ map retained_id (filter (\<lambda>v. retained_id v\<in>reached) values))"

lemma remdups_left_normalize:
  "remdups (remdups xs @ ys) = remdups (xs @ ys)"
  by (induction xs) auto

lemma remdups_repeat_suffix:
  "remdups ((xs @ ys) @ ys) = remdups (xs @ ys)"
proof -
  have suffix: "remdups (ys @ ys) = remdups ys"
    by (rule remdups_append) simp
  show ?thesis
    by (metis append_assoc remdups_append2 suffix)
qed

lemma remdups_prefix_outside:
  "remdups (xs @ ys) = remdups (filter (\<lambda>x. x \<notin> set ys) xs @ ys)"
  by (induction xs) auto

lemma fired_records_mono:
  "set xs \<subseteq> set ys \<Longrightarrow> fired_records values xs \<subseteq> fired_records values ys"
  by (auto simp: fired_records_def directly_dependent_def)

lemma fired_records_step_mono:
  "fired_records values removed \<subseteq> fired_records values (closure_next values removed)"
  by (rule fired_records_mono[OF closure_next_includes])

lemma same_fired_filter:
  "fired_records values xs = fired_records values ys \<Longrightarrow>
   filter (directly_dependent xs) values = filter (directly_dependent ys) values"
  by (rule filter_cong) (auto simp: fired_records_def)

lemma same_fired_step_fixed:
  assumes "fired_records values (closure_next values removed) = fired_records values removed"
  shows "closure_next values (closure_next values removed) = closure_next values removed"
proof -
  have same: "filter (directly_dependent (closure_next values removed)) values =
      filter (directly_dependent removed) values"
    by (rule same_fired_filter[OF assms])
  show ?thesis
    by (simp only: closure_next_def[of "values" "closure_next values removed"] same;
      simp add: closure_next_def remdups_left_normalize remdups_repeat_suffix)
qed

lemma exact_fixed_stays:
  assumes "closure_next values removed = removed"
  shows "dependency_closure n values removed = removed"
  using assms by (induction n) (simp_all add: closure_next_def)

lemma fired_growth:
  assumes "fired_records values (closure_next values removed) \<noteq> fired_records values removed"
  shows "card (set values - fired_records values (closure_next values removed)) <
    card (set values - fired_records values removed)"
proof -
  have "set values - fired_records values (closure_next values removed) \<subset>
      set values - fired_records values removed"
    using fired_records_step_mono[of "values" removed] assms
    by (auto simp: fired_records_def)
  then show ?thesis by (rule psubset_card_mono) simp
qed

lemma closure_exact_bound:
  assumes "card (set values - fired_records values removed) \<le> n"
  shows "closure_next values (dependency_closure (Suc n) values removed) =
    dependency_closure (Suc n) values removed"
  using assms
proof (induction n arbitrary: removed)
  case 0
  have full: "fired_records values removed = set values"
    using 0 by (auto simp: fired_records_def)
  have same: "fired_records values (closure_next values removed) = fired_records values removed"
    using fired_records_step_mono[of "values" removed] full by (auto simp: fired_records_def)
  show ?case using same_fired_step_fixed[OF same] by (simp add: closure_next_def)
next
  case (Suc n)
  show ?case
  proof (cases "fired_records values (closure_next values removed) = fired_records values removed")
    case True
    have fixed: "closure_next values (closure_next values removed) = closure_next values removed"
      by (rule same_fired_step_fixed[OF True])
    show ?thesis using exact_fixed_stays[OF fixed, of "Suc n"] fixed
      by (simp add: closure_next_def)
  next
    case False
    have bound: "card (set values - fired_records values (closure_next values removed)) \<le> n"
      using fired_growth[OF False] Suc.prems by arith
    show ?thesis using Suc.IH[OF bound] by (simp add: closure_next_def)
  qed
qed

lemma closure_reference_fixed:
  assumes "values \<noteq> []"
  shows "closure_next values (dependency_closure (length values) values seeds) =
    dependency_closure (length values) values seeds"
proof (cases "fired_records values seeds = {}")
  case True
  have same: "fired_records values (closure_next values seeds) = fired_records values seeds"
    using True by (auto simp: fired_records_def closure_next_def directly_dependent_def)
  have fixed: "closure_next values (closure_next values seeds) = closure_next values seeds"
    by (rule same_fired_step_fixed[OF same])
  obtain n where len: "length values = Suc n" using assms by (cases "values") auto
  show ?thesis using exact_fixed_stays[OF fixed, of n] fixed
    by (simp add: len closure_next_def)
next
  case False
  have strict: "set values - fired_records values seeds \<subset> set values"
    using False by (auto simp: fired_records_def)
  have smaller: "card (set values - fired_records values seeds) < card (set values)"
    by (rule psubset_card_mono) (use strict in auto)
  have less: "card (set values - fired_records values seeds) < length values"
    using smaller card_length[of "values"] by arith
  have bound: "card (set values - fired_records values seeds) \<le> length values - 1"
    using less by arith
  have len: "Suc (length values - 1) = length values" using assms by simp
  show ?thesis using closure_exact_bound[OF bound] by (simp add: len)
qed


lemma remdups_absorb_subset:
  "set xs \<subseteq> set ys \<Longrightarrow> remdups (xs @ ys) = remdups ys"
  by (induction xs) auto

lemma remdups_middle_absorb:
  "set xs \<subseteq> set ys \<Longrightarrow>
    remdups ((prefix @ xs) @ ys) = remdups (prefix @ ys)"
  by (metis append_assoc remdups_absorb_subset remdups_append2)

lemma closure_normalize_target:
  assumes "set seeds \<subseteq> target" "managed_closed values target"
  defines "suffix \<equiv> map retained_id (filter (\<lambda>v. retained_id v\<in>target) values)"
  shows "remdups (dependency_closure n values seeds @ suffix) = remdups (seeds @ suffix)"
  using assms(1)
proof (induction n arbitrary: seeds)
  case 0 then show ?case by simp
next
  case (Suc n)
  have included: "set (closure_next values seeds) \<subseteq> target"
    using Suc.prems assms(2)
    by (auto simp: closure_next_def directly_dependent_def managed_closed_def)
  have fired: "set (map retained_id (filter (directly_dependent seeds) values)) \<subseteq> set suffix"
    using Suc.prems assms(2) by (auto simp: suffix_def directly_dependent_def managed_closed_def)
  have normalize: "remdups (closure_next values seeds @ suffix) = remdups (seeds @ suffix)"
    unfolding closure_next_def
    by (simp only: remdups_left_normalize remdups_middle_absorb[OF fired])
  from Suc.IH[OF included] normalize show ?case by (simp add: closure_next_def)
qed

lemma reference_order_reconstruction:
  assumes "values \<noteq> []"
  shows "dependency_closure (length values) values seeds =
    ordered_reconstruction values seeds (set (dependency_closure (length values) values seeds))"
proof -
  let ?result = "dependency_closure (length values) values seeds"
  let ?target = "set ?result"
  let ?suffix = "map retained_id (filter (\<lambda>v. retained_id v\<in>?target) values)"
  have bound: "card (set (map retained_id values) - set seeds) \<le> length values"
    using card_mono[of "set (map retained_id values)" "set (map retained_id values) - set seeds"]
      card_length[of "map retained_id values"] by auto
  have closed: "managed_closed values ?target" by (rule closure_bound[OF bound])
  have included: "set seeds \<subseteq> ?target" by (rule dependency_closure_includes)
  have normalize: "remdups (?result @ ?suffix) = remdups (seeds @ ?suffix)"
    by (rule closure_normalize_target[OF included closed])
  have firing: "filter (directly_dependent ?result) values =
      filter (\<lambda>v. retained_id v\<in>?target) values"
    by (rule filter_cong) (use closed in \<open>auto simp: directly_dependent_def managed_closed_def\<close>)
  have fixed: "remdups (?result @ ?suffix) = ?result"
    using closure_reference_fixed[OF assms, of seeds]
    by (simp add: closure_next_def firing)
  from fixed normalize show ?thesis by (simp add: ordered_reconstruction_def)
qed

lemma empty_reference_order:
  "dependency_closure (length []) [] seeds = seeds" by simp

text \<open>The reference directly_dependent predicate includes records whose own
ID is already reached, as well as records with a reached dependency. At closure
these are exactly all reached records. The self-ID disjunct is essential for exact
list order, including seed-only records and their positions among other records.\<close>
end
