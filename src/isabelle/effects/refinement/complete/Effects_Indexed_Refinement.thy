theory Effects_Indexed_Refinement
  imports Veri7vn_Effects_Indexed.Effects_Indexed
    Veri7vn_Effects_Order.Effects_Order_Reconstruction
begin

text \<open>The checked ancestor/history core is intentionally unchanged while
its actual D44 consumer qualifies. Its earlier unselected forward candidate
omitted the reference predicate's self-ID disjunct. This optional corrected
wrapper uses the same indexed traversal and last-occurrence foundation.\<close>

definition indexed_ordered_reconstruction ::
  "retained_value list \<Rightarrow> nat list \<Rightarrow> effect_seen \<Rightarrow> nat list" where
  "indexed_ordered_reconstruction values seeds reached = fst (indexed_last_unique
    (seeds @ map retained_id (filter (\<lambda>v. RBT.lookup reached (retained_id v) \<noteq> None) values)) RBT.empty)"

definition indexed_forget_closure_ordered ::
  "retained_value list \<Rightarrow> nat list \<Rightarrow> nat list option" where
  "indexed_forget_closure_ordered values seeds = (if values=[] then Some seeds else
    map_option (indexed_ordered_reconstruction values seeds)
      (indexed_walk (closure_work values seeds) (reverse_index values) seeds RBT.empty))"

lemma indexed_ordered_reconstruction_order:
  "indexed_ordered_reconstruction values seeds reached =
    ordered_reconstruction values seeds (dom (RBT.lookup reached))"
  by (simp add: indexed_ordered_reconstruction_def indexed_last_unique_empty
    ordered_reconstruction_def domIff)

lemma indexed_forget_closure_ordered_exact:
  "indexed_forget_closure_ordered values seeds = forget_closure values seeds"
proof (cases "values=[]")
  case True
  then show ?thesis by (simp add: indexed_forget_closure_ordered_def forget_closure_def Let_def list_all_iff)
next
  case False
  obtain reached where walk:
    "indexed_walk (closure_work values seeds) (reverse_index values) seeds RBT.empty = Some reached"
    using reverse_walk_total by blast
  have reached: "dom (RBT.lookup reached) = set (dependency_closure (length values) values seeds)"
    using reverse_walk_exact[OF walk] reference_reachable_set by simp
  have order: "indexed_ordered_reconstruction values seeds reached = dependency_closure (length values) values seeds"
  proof -
    have "indexed_ordered_reconstruction values seeds reached =
        ordered_reconstruction values seeds (dom (RBT.lookup reached))"
      by (rule indexed_ordered_reconstruction_order)
    also have "... = ordered_reconstruction values seeds
        (set (dependency_closure (length values) values seeds))"
      by (simp only: reached)
    also have "... = dependency_closure (length values) values seeds"
      by (rule sym) (rule reference_order_reconstruction[OF False])
    finally show ?thesis .
  qed
  have reference: "forget_closure values seeds = Some (dependency_closure (length values) values seeds)"
    using forget_closure_total[of "values" seeds] by (auto simp: forget_closure_def Let_def)
  show ?thesis using False walk order reference
    by (simp add: indexed_forget_closure_ordered_def)
qed

text \<open>Code selection belongs to the actual generated service after this
exact-list theorem and the corresponding native runtime fixtures qualify. The
wrong earlier unselected candidate is not used by this wrapper or production.\<close>
export_code indexed_forget_closure_ordered in SML module_name OrderedIndexedEffects
end
