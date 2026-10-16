theory Effects_Closure_Totality
  imports Veri7vn_Effects.Veri7vn_Effects
begin

definition closure_next :: "retained_value list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "closure_next values removed = remdups
    (removed @ map retained_id (filter (directly_dependent removed) values))"

lemma closure_next_includes:
  "set removed \<subseteq> set (closure_next values removed)"
  by (auto simp: closure_next_def)
lemma closure_next_closed:
  "managed_closed values (set removed) \<Longrightarrow>
    set (closure_next values removed) = set removed"
  by (auto simp: closure_next_def managed_closed_def directly_dependent_def)
lemma closure_next_progress:
  assumes "\<not> managed_closed values (set removed)"
  shows "set (map retained_id values) - set (closure_next values removed)
    \<subset> set (map retained_id values) - set removed"
  using assms
  by (auto simp: closure_next_def managed_closed_def directly_dependent_def)

lemma closure_closed_stays:
  assumes "managed_closed values (set removed)"
  shows "set (dependency_closure n values removed) = set removed"
  using assms
proof (induction n arbitrary: removed)
  case 0 then show ?case by simp
next
  case (Suc n)
  have same: "set (closure_next values removed) = set removed"
    using closure_next_closed Suc.prems by blast
  have closed: "managed_closed values (set (closure_next values removed))"
    using same Suc.prems by simp
  have "set (dependency_closure n values (closure_next values removed)) = set (closure_next values removed)"
    by (rule Suc.IH[OF closed])
  with same show ?case by (simp add: closure_next_def)
qed

lemma closure_bound:
  assumes "card (set (map retained_id values) - set removed) \<le> n"
  shows "managed_closed values (set (dependency_closure n values removed))"
  using assms
proof (induction n arbitrary: removed)
  case 0
  then have "set (map retained_id values) \<subseteq> set removed" by auto
  then show ?case by (auto simp: managed_closed_def)
next
  case (Suc n)
  show ?case
  proof (cases "managed_closed values (set removed)")
    case True
    then show ?thesis using closure_closed_stays[OF True, of "Suc n"] by simp
  next
    case False
    have strict: "card (set (map retained_id values) - set (closure_next values removed)) <
        card (set (map retained_id values) - set removed)"
      by (rule psubset_card_mono) (use closure_next_progress[OF False] in auto)
    have bound: "card (set (map retained_id values) - set (closure_next values removed)) \<le> n"
      using strict Suc.prems by arith
    from Suc.IH[OF bound] show ?thesis by (simp add: closure_next_def)
  qed
qed

lemma dependency_closure_includes:
  "set removed \<subseteq> set (dependency_closure n values removed)"
proof (induction n arbitrary: removed)
  case 0 then show ?case by simp
next
  case (Suc n)
  have "set removed \<subseteq> set (closure_next values removed)" by (rule closure_next_includes)
  also have "... \<subseteq> set (dependency_closure n values (closure_next values removed))" by (rule Suc.IH)
  finally show ?case by (simp add: closure_next_def)
qed

lemma forget_closure_total:
  "\<exists>result. forget_closure values removed = Some result"
proof -
  have card: "card (set (map retained_id values) - set removed) \<le> length values"
    using card_mono[of "set (map retained_id values)" "set (map retained_id values) - set removed"]
      card_length[of "map retained_id values"] by auto
  have closed: "managed_closed values (set (dependency_closure (length values) values removed))"
    by (rule closure_bound[OF card])
  have seeds: "set removed \<subseteq> set (dependency_closure (length values) values removed)"
    by (rule dependency_closure_includes)
  show ?thesis using closed seeds
    by (auto simp: forget_closure_def Let_def managed_closed_def list_all_iff)
qed
end
