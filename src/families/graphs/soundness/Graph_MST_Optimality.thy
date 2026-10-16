theory Graph_MST_Optimality
  imports Veri7vn_Graph_Core.Graph_MST_Checker
begin

text \<open>An independent, polynomial weak-duality certificate. The integer
baseline handles negative weights. Nonnegative cut prices give lower bounds on
all spanning trees, not merely on the selected proposal. This cut relaxation is
sound but incomplete; the stronger partition checker below supplies the general
MST lower bound. No exhaustive search occurs in either checker.\<close>


lemma reach_step_preserves_side:
 assumes "\<forall>v\<in>set seen. (v\<in>set cut)=side"
   "\<forall>e\<in>set es. \<not> crosses_cut cut e"
 shows "\<forall>v\<in>set (reach_step es seen). (v\<in>set cut)=side"
 using assms by (auto simp: crosses_cut_def)

lemma reachable_preserves_side:
 assumes "\<forall>v\<in>set seen. (v\<in>set cut)=side"
   "\<forall>e\<in>set es. \<not> crosses_cut cut e"
 shows "\<forall>v\<in>set (reachable n es seen). (v\<in>set cut)=side"
 using assms
 by (induction n arbitrary: seen) (auto intro: reach_step_preserves_side)

lemma spanning_tree_crosses_proper_cut:
 assumes tree: "spanning_tree g tree" and cut: "proper_vertex_cut g cut"
 shows "\<exists>e\<in>set tree. crosses_cut cut e"
proof (rule ccontr)
 assume no: "\<not> (\<exists>e\<in>set tree. crosses_cut cut e)"
 obtain v vs where vertices: "vertices g=v#vs"
   using tree by (cases "vertices g") (auto simp: spanning_tree_def)
 have side: "\<forall>u\<in>set (reachable (length (vertices g)) tree [v]).
     (u\<in>set cut)=(v\<in>set cut)"
   using reachable_preserves_side[of "[v]" cut "v\<in>set cut" tree "length (vertices g)"] no
   by simp
 have connected: "set (vertices g) \<subseteq>
     set (reachable (length (vertices g)) tree [v])"
   using tree by (simp only: spanning_tree_def vertices list.case; blast)
 have all: "\<forall>u\<in>set (vertices g). (u\<in>set cut)=(v\<in>set cut)"
   using side connected by blast
 show False using all cut by (auto simp: proper_vertex_cut_def)
qed


lemma cut_price_lower_bound:
 assumes "spanning_tree g tree" "proper_vertex_cut g (fst p)" "0\<le>snd p"
 shows "snd p \<le> sum_list (map (cut_price p) tree)"
proof -
 obtain e where "e\<in>set tree" "crosses_cut (fst p) e"
   using spanning_tree_crosses_proper_cut assms by blast
 hence member: "snd p\<in>set (map (cut_price p) tree)"
   by (force simp: cut_price_def)
 show ?thesis
   by (rule member_le_sum_list[OF member]) (use assms in \<open>auto simp: cut_price_def\<close>)
qed

lemma sum_list_matrix_swap:
 "sum_list (map (\<lambda>x. sum_list (map (f x) ys)) xs) =
  sum_list (map (\<lambda>y. sum_list (map (\<lambda>x. f x y) xs)) ys)"
 for f :: "'a\<Rightarrow>'b\<Rightarrow>int"
 by (induction xs) (simp_all add: sum_list_addf)

lemma subsets_set_subset:
 "xs\<in>set (subsets ys) \<Longrightarrow> set xs\<subseteq>set ys"
 by (induction ys arbitrary: xs) auto

lemma cut_dual_weak_bound:
 assumes tree: "spanning_tree g tree"
   and prices: "\<forall>p\<in>set prices. 0\<le>snd p \<and> proper_vertex_cut g (fst p)"
   and edge: "\<forall>e\<in>set (edges g). baseline + dual_edge_price prices e \<le> weight e"
 shows "cut_dual_bound g baseline prices \<le> path_cost tree"
proof -
 have original: "set tree\<subseteq>set (edges g)"
   using tree subsets_set_subset by (auto simp: spanning_tree_def)
 have length: "length tree=length (vertices g)-1"
   using tree by (auto simp: spanning_tree_def)
 have lower: "sum_list (map snd prices) \<le>
     sum_list (map (\<lambda>p. sum_list (map (cut_price p) tree)) prices)"
   by (rule sum_list_mono) (use cut_price_lower_bound tree prices in blast)
 have swap: "sum_list (map (\<lambda>p. sum_list (map (cut_price p) tree)) prices) =
     sum_list (map (dual_edge_price prices) tree)"
   unfolding dual_edge_price_def by (rule sum_list_matrix_swap)
 have total: "sum_list (map (\<lambda>e. baseline + dual_edge_price prices e) tree) \<le>
     path_cost tree"
   unfolding path_cost_def by (rule sum_list_mono) (use original edge in blast)
 have constant: "sum_list (map (\<lambda>e. baseline + dual_edge_price prices e) tree) =
     int (length tree)*baseline + sum_list (map (dual_edge_price prices) tree)"
   by (induction tree) (simp_all add: algebra_simps)
 show ?thesis using lower swap total constant length
   by (simp add: cut_dual_bound_def mult.commute; linarith)
qed

lemma cut_dual_check_sound:
 assumes "cut_dual_check g tree baseline prices"
 shows "\<not> directed g \<and> minimum_tree g tree"
 using assms feasible_tree_check_sound cut_dual_weak_bound
 by (auto simp: cut_dual_check_def minimum_tree_def)


text \<open>The following finite component argument strengthens cuts to arbitrary
partitions. It counts actual crossing rows, including parallel rows separately.
Merging component labels is proof infrastructure; it does not trust Kruskal.\<close>
definition merge_edge_labels where
 "merge_edge_labels e f = (\<lambda>v. if f v=f (head e) then f (tail e) else f v)"

lemma merge_edge_labels_eq:
 "f u=f v \<Longrightarrow> merge_edge_labels e f u=merge_edge_labels e f v"
 by (simp add: merge_edge_labels_def)
lemma fold_merge_labels_eq:
 "f u=f v \<Longrightarrow>
   fold merge_edge_labels es f u=fold merge_edge_labels es f v"
 by (induction es arbitrary: f) (auto intro: merge_edge_labels_eq)
lemma fold_merge_labels_edges:
 "e\<in>set es \<Longrightarrow>
  fold merge_edge_labels es f (tail e)=fold merge_edge_labels es f (head e)"
proof (induction es arbitrary: f)
 case Nil then show ?case by simp
next
 case (Cons a es)
 show ?case
 proof (cases "e=a")
  case True
  have "merge_edge_labels a f (tail a)=merge_edge_labels a f (head a)"
   by (simp add: merge_edge_labels_def)
  then show ?thesis using fold_merge_labels_eq[of "merge_edge_labels a f" "tail a" "head a" es]
   True by simp
 next
  case False then show ?thesis using Cons by auto
 qed
qed

lemma reach_step_preserves_label:
 assumes "\<forall>v\<in>set seen. f v=k"
   "\<forall>e\<in>set es. f (tail e)=f (head e)"
 shows "\<forall>v\<in>set (reach_step es seen). f v=k"
 using assms by auto
lemma reachable_preserves_label:
 assumes "\<forall>v\<in>set seen. f v=k"
   "\<forall>e\<in>set es. f (tail e)=f (head e)"
 shows "\<forall>v\<in>set (reachable n es seen). f v=k"
 using assms
 by (induction n arbitrary: seen) (auto intro: reach_step_preserves_label)

lemma spanning_tree_final_label_card:
 assumes "spanning_tree g tree"
 shows "card ((fold merge_edge_labels tree f) ` set (vertices g))=1"
proof -
 obtain v vs where vertices: "vertices g=v#vs"
  using assms by (cases "vertices g") (auto simp: spanning_tree_def)
 let ?F = "fold merge_edge_labels tree f"
 have side: "\<forall>u\<in>set (reachable (length (vertices g)) tree [v]). ?F u=?F v"
  by (rule reachable_preserves_label) (auto intro: fold_merge_labels_edges)
 have connected: "set (vertices g) \<subseteq>
    set (reachable (length (vertices g)) tree [v])"
  using assms by (simp only: spanning_tree_def vertices list.case; blast)
 have root: "v\<in>set (vertices g)" using vertices by simp
 have image: "?F ` set (vertices g)={?F v}"
  using side connected root by blast
 show ?thesis by (simp add: image)
qed

lemma replacing_label_card:
 fixes f :: "nat\<Rightarrow>nat"
 assumes "finite V"
 shows "card (f ` V) \<le> card ((\<lambda>v. if f v=b then a else f v) ` V)+1"
proof -
 let ?A = "(\<lambda>v. if f v=b then a else f v) ` V"
 have sub: "f ` V \<subseteq> insert b ?A" by auto
 have "card (f ` V) \<le> card (insert b ?A)"
  by (rule card_mono) (use assms sub in auto)
 also have "\<dots>\<le>card ?A+1" using assms by (simp add: card_insert_if)
 finally show ?thesis .
qed

lemma merge_labels_card_bound:
 fixes initial f :: "nat\<Rightarrow>nat"
 assumes finite: "finite V"
   and factors: "\<And>u v. initial u=initial v \<Longrightarrow> f u=f v"
 shows "card (f ` V) \<le> card (merge_edge_labels e f ` V) +
   (if initial (tail e)=initial (head e) then 0 else 1)"
proof (cases "initial (tail e)=initial (head e)")
 case True
 have "merge_edge_labels e f=f"
  using factors[OF True] by (auto simp: merge_edge_labels_def fun_eq_iff)
 then show ?thesis using True by simp
next
 case False
 show ?thesis using replacing_label_card[OF finite, of f "f (head e)" "f (tail e)"]
  False by (simp add: merge_edge_labels_def)
qed

lemma fold_merge_labels_card_bound:
 fixes initial f :: "nat\<Rightarrow>nat"
 assumes finite: "finite V"
   and factors: "\<And>u v. initial u=initial v \<Longrightarrow> f u=f v"
 shows "card (f ` V) \<le> card (fold merge_edge_labels es f ` V) +
   length (filter (\<lambda>e. initial (tail e)\<noteq>initial (head e)) es)"
 using factors
proof (induction es arbitrary: f)
 case Nil
 show ?case by (simp only: fold_simps filter.simps list.size add_0 order_refl)
next
 case (Cons e es)
 have step: "card (f ` V) \<le> card (merge_edge_labels e f ` V) +
   (if initial (tail e)=initial (head e) then 0 else 1)"
  by (rule merge_labels_card_bound[OF finite]) (rule Cons.prems)
 have rest: "card (merge_edge_labels e f ` V) \<le>
   card (fold merge_edge_labels es (merge_edge_labels e f) ` V) +
   length (filter (\<lambda>e. initial (tail e)\<noteq>initial (head e)) es)"
 proof (rule Cons.IH)
  fix u v
  assume eq: "initial u=initial v"
  have "f u=f v" by (rule Cons.prems[OF eq])
  then show "merge_edge_labels e f u=merge_edge_labels e f v"
   by (rule merge_edge_labels_eq)
 qed
 show ?case using step rest by (auto split: if_splits; linarith)
qed

lemma spanning_tree_partition_crossing_bound:
 assumes "spanning_tree g tree"
 shows "card (labels ` set (vertices g))-1 \<le>
   length (filter (\<lambda>e. labels (tail e)\<noteq>labels (head e)) tree)"
 using fold_merge_labels_card_bound[where V="set (vertices g)" and initial=labels and f=labels and es=tree]
  spanning_tree_final_label_card[OF assms, of labels]
 by (auto; linarith)



lemma partition_price_sum:
 "sum_list (map (partition_price p) tree) =
   snd p * int (length (filter (partition_crosses (fst p)) tree))"
 by (induction tree) (auto simp: partition_price_def algebra_simps)
lemma partition_price_lower_bound:
 assumes tree: "spanning_tree g tree" and nonneg: "0\<le>snd p"
 shows "snd p * int (partition_blocks g (fst p)-1) \<le>
   sum_list (map (partition_price p) tree)"
proof -
 have count: "partition_blocks g (fst p)-1 \<le>
    length (filter (partition_crosses (fst p)) tree)"
  using spanning_tree_partition_crossing_bound[OF tree, of "component (fst p)"]
  by (simp add: partition_blocks_def partition_crosses_def length_remdups_card_conv)
 have "int (partition_blocks g (fst p)-1) \<le>
    int (length (filter (partition_crosses (fst p)) tree))"
  using count by simp
 then have "snd p * int (partition_blocks g (fst p)-1) \<le>
    snd p * int (length (filter (partition_crosses (fst p)) tree))"
  by (rule mult_left_mono[OF _ nonneg])
 then show ?thesis by (simp add: partition_price_sum)
qed

lemma partition_dual_weak_bound:
 assumes tree: "spanning_tree g tree"
   and prices: "\<forall>p\<in>set prices. 0\<le>snd p"
   and edge: "\<forall>e\<in>set (edges g). baseline + partition_edge_price prices e \<le> weight e"
 shows "partition_dual_bound g baseline prices \<le> path_cost tree"
proof -
 have original: "set tree\<subseteq>set (edges g)"
   using tree subsets_set_subset by (auto simp: spanning_tree_def)
 have length: "length tree=length (vertices g)-1"
   using tree by (auto simp: spanning_tree_def)
 have lower: "sum_list (map (\<lambda>p. snd p * int (partition_blocks g (fst p)-1)) prices) \<le>
     sum_list (map (\<lambda>p. sum_list (map (partition_price p) tree)) prices)"
   by (rule sum_list_mono) (use partition_price_lower_bound tree prices in blast)
 have swap: "sum_list (map (\<lambda>p. sum_list (map (partition_price p) tree)) prices) =
     sum_list (map (partition_edge_price prices) tree)"
   unfolding partition_edge_price_def by (rule sum_list_matrix_swap)
 have total: "sum_list (map (\<lambda>e. baseline + partition_edge_price prices e) tree) \<le>
     path_cost tree"
   unfolding path_cost_def by (rule sum_list_mono) (use original edge in blast)
 have constant: "sum_list (map (\<lambda>e. baseline + partition_edge_price prices e) tree) =
     int (length tree)*baseline + sum_list (map (partition_edge_price prices) tree)"
   by (induction tree) (simp_all add: algebra_simps)
 show ?thesis using lower swap total constant length
   by (simp add: partition_dual_bound_def mult.commute; linarith)
qed

lemma partition_dual_check_sound:
 assumes "partition_dual_check g tree baseline prices"
 shows "\<not> directed g \<and> minimum_tree g tree"
 using assms feasible_tree_check_sound partition_dual_weak_bound
 by (auto simp: partition_dual_check_def minimum_tree_def)

end
