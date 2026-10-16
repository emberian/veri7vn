theory Graph_Certificates
  imports Veri7vn_Codegen.Veri7vn_Codegen
begin

text \<open>Finite directed multigraphs. Each edge retains its original row key;
source/adoption authority is supplied by the source gate, never by this carrier.
Signed weights are literal integers. Parallel and contrary rows remain distinct.\<close>
record graph_edge =
  row_key :: nat
  relation_key :: nat
  tail :: nat
  head :: nat
  weight :: int
record graph_snapshot =
  vertices :: "nat list"
  edges :: "graph_edge list"
  directed :: bool

definition wellformed_graph where
  "wellformed_graph g \<longleftrightarrow> distinct (vertices g) \<and>
    distinct (map row_key (edges g)) \<and>
    (\<forall>e\<in>set (edges g). tail e \<in> set (vertices g) \<and> head e \<in> set (vertices g))"
definition edge_enabled where
 "edge_enabled g s e \<longleftrightarrow> tail e=s \<or> (\<not> directed g \<and> head e=s)"
definition edge_target where
 "edge_target g s e = (if tail e=s then head e else tail e)"
fun path_end :: "graph_snapshot \<Rightarrow> nat \<Rightarrow> graph_edge list \<Rightarrow> nat" where
  "path_end g s [] = s"
| "path_end g s (e#es) = path_end g (edge_target g s e) es"
fun path_check :: "graph_snapshot \<Rightarrow> nat \<Rightarrow> graph_edge list \<Rightarrow> bool" where
  "path_check g s [] = (s \<in> set (vertices g))"
| "path_check g s (e#es) = (e \<in> set (edges g) \<and> edge_enabled g s e \<and>
     path_check g (edge_target g s e) es)"
definition path_cost where "path_cost es = sum_list (map weight es)"
definition feasible_path where
  "feasible_path g s t es \<longleftrightarrow> path_check g s es \<and> path_end g s es=t"


definition relation_chain where
  "relation_chain g s t labels es \<longleftrightarrow>
    feasible_path g s t es \<and> map relation_key es = labels"
lemma path_original_rows:
  "path_check g s es \<Longrightarrow> set es \<subseteq> set (edges g)"
  by (induction es arbitrary: s) auto
lemma relation_chain_provenance:
  "relation_chain g s t labels es \<Longrightarrow>
   set es \<subseteq> set (edges g) \<and> map relation_key es=labels"
  using path_original_rows by (auto simp: relation_chain_def feasible_path_def)

definition potential_check where
  "potential_check g d \<longleftrightarrow> (\<forall>e\<in>set (edges g).
    d (head e) \<le> d (tail e) + weight e \<and>
    (\<not> directed g \<longrightarrow> d (tail e) \<le> d (head e) + weight e))"
lemma potential_path_bound:
  "path_check g s es \<Longrightarrow> potential_check g d \<Longrightarrow>
    d (path_end g s es) \<le> d s + path_cost es"
proof (induction es arbitrary: s)
  case Nil then show ?case by (simp add: path_cost_def)
next
  case (Cons e es)
  have rest: "d (path_end g (edge_target g s e) es) \<le> d (edge_target g s e) + path_cost es"
    using Cons.IH Cons.prems by simp
  have edge: "d (edge_target g s e) \<le> d s + weight e"
    using Cons.prems by (auto simp: potential_check_def edge_enabled_def edge_target_def split: if_splits)
  show ?case using rest edge by (simp add: path_cost_def; linarith)
qed

definition shortest_certificate where
  "shortest_certificate g s t es d \<longleftrightarrow> feasible_path g s t es \<and>
    potential_check g d \<and> path_cost es = d t - d s"
lemma shortest_certificate_sound:
  assumes "shortest_certificate g s t es d" "feasible_path g s t other"
  shows "path_cost es \<le> path_cost other"
  using potential_path_bound[of g s other d] assms
  by (auto simp: shortest_certificate_def feasible_path_def; linarith)

definition cut_check where
  "cut_check g s t cut \<longleftrightarrow> s \<in> set cut \<and> t \<notin> set cut \<and>
    (\<forall>e\<in>set (edges g). (tail e \<in> set cut \<longrightarrow> head e \<in> set cut) \<and>
      (\<not> directed g \<longrightarrow> head e \<in> set cut \<longrightarrow> tail e \<in> set cut))"
lemma closed_cut_path:
  "path_check g s es \<Longrightarrow> s \<in> set cut \<Longrightarrow>
   (\<forall>e\<in>set (edges g). (tail e \<in> set cut \<longrightarrow> head e \<in> set cut) \<and>
     (\<not> directed g \<longrightarrow> head e \<in> set cut \<longrightarrow> tail e \<in> set cut)) \<Longrightarrow>
   path_end g s es \<in> set cut"
  by (induction es arbitrary: s)
    (auto simp: edge_enabled_def edge_target_def split: if_splits)
lemma unreachable_certificate_sound:
  "cut_check g s t cut \<Longrightarrow> \<not> feasible_path g s t es"
  using closed_cut_path by (auto simp: cut_check_def feasible_path_def)

text \<open>Enumeration preserves edge records, hence distinct proofs of the same
endpoint and contradictory relations. Depth exhaustion is never unreachability.\<close>
fun paths_upto :: "nat \<Rightarrow> graph_snapshot \<Rightarrow> nat \<Rightarrow> graph_edge list list" where
  "paths_upto 0 g s = (if s \<in> set (vertices g) then [[]] else [])"
| "paths_upto (Suc n) g s = (if s \<in> set (vertices g) then [[]] else []) @
    concat (map (\<lambda>e. map ((#) e) (paths_upto n g (edge_target g s e)))
      (filter (edge_enabled g s) (edges g)))"
lemma paths_upto_exact:
  "es \<in> set (paths_upto n g s) \<longleftrightarrow> path_check g s es \<and> length es \<le> n"
  by (induction n arbitrary: s es) (case_tac es; auto)+

definition bounded_paths where
  "bounded_paths depth g s t = filter (\<lambda>es. path_end g s es=t) (paths_upto depth g s)"
lemma bounded_paths_exact:
  "es \<in> set (bounded_paths depth g s t) \<longleftrightarrow>
    feasible_path g s t es \<and> length es \<le> depth"
  by (auto simp: bounded_paths_def paths_upto_exact feasible_path_def)

text \<open>Undirected trees use the supplied vertex universe, including isolates.
An oriented input is explicitly rejected by the MST dispatcher. Connectivity is
checked by a closed reachable-set computation; all subsets are considered for
optimality, with source order defining the deterministic tie choice.\<close>
fun subsets :: "'a list \<Rightarrow> 'a list list" where
  "subsets [] = [[]]"
| "subsets (x#xs) = subsets xs @ map ((#) x) (subsets xs)"
fun reach_step where
  "reach_step es seen = remdups (seen @ concat (map (\<lambda>e.
    (if tail e \<in> set seen then [head e] else []) @
    (if head e \<in> set seen then [tail e] else [])) es))"
fun reachable where
  "reachable 0 es seen = seen"
| "reachable (Suc n) es seen = reachable n es (reach_step es seen)"
definition spanning_tree where
  "spanning_tree g tree \<longleftrightarrow> tree \<in> set (subsets (edges g)) \<and>
    length tree + 1 = length (vertices g) \<and>
    (case vertices g of [] \<Rightarrow> False | v#vs \<Rightarrow>
      set (vertices g) \<subseteq> set (reachable (length (vertices g)) tree [v]))"
definition spanning_candidates where
  "spanning_candidates g = filter (spanning_tree g) (subsets (edges g))"
definition minimum_tree where
  "minimum_tree g tree \<longleftrightarrow> spanning_tree g tree \<and>
    (\<forall>other. spanning_tree g other \<longrightarrow> path_cost tree \<le> path_cost other)"
fun cheapest where
  "cheapest [] = None"
| "cheapest (x#xs) = (case cheapest xs of None \<Rightarrow> Some x | Some y \<Rightarrow>
    Some (if path_cost x \<le> path_cost y then x else y))"
lemma cheapest_none:
  "cheapest xs = None \<longleftrightarrow> xs=[]"
  by (cases xs) (auto split: option.splits)
lemma cheapest_member:
  "cheapest xs = Some x \<Longrightarrow> x \<in> set xs"
  by (induction xs) (auto simp: cheapest_none split: option.splits if_splits)
lemma cheapest_lower:
  assumes "cheapest xs = Some x" "y \<in> set xs"
  shows "path_cost x \<le> path_cost y"
  using assms
proof (induction xs arbitrary: x y)
  case Nil then show ?case by simp
next
  case (Cons a xs)
  show ?case
  proof (cases "cheapest xs")
    case None
    then have "xs=[]" by (simp add: cheapest_none)
    then show ?thesis using Cons.prems by simp
  next
    case (Some best)
    have lower: "\<And>z. z\<in>set xs \<Longrightarrow> path_cost best\<le>path_cost z"
      using Cons.IH Some by blast
    show ?thesis using Cons.prems lower[of y]
      by (auto simp: Some split: if_splits; linarith)
  qed
qed
lemma minimum_tree_sound:
  assumes "cheapest (spanning_candidates g) = Some tree"
  shows "minimum_tree g tree"
proof -
  have member: "tree\<in>set (spanning_candidates g)"
    using cheapest_member assms by blast
  have lower: "\<And>other. other\<in>set (spanning_candidates g) \<Longrightarrow> path_cost tree\<le>path_cost other"
    using cheapest_lower assms by blast
  have tree: "spanning_tree g tree"
    using member by (simp add: spanning_candidates_def)
  have bound: "\<And>other. spanning_tree g other \<Longrightarrow> path_cost tree\<le>path_cost other"
  proof -
    fix other assume other: "spanning_tree g other"
    have original: "other\<in>set (subsets (edges g))"
      using other by (simp add: spanning_tree_def)
    have "other\<in>set (spanning_candidates g)"
      using original other by (simp add: spanning_candidates_def)
    then show "path_cost tree\<le>path_cost other" by (rule lower)
  qed
  show ?thesis using tree bound by (simp add: minimum_tree_def)
qed

end
