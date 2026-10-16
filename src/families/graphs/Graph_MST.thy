theory Graph_MST
 imports Graph_Search
begin

text \<open>Polynomial Kruskal proposer. Component labels use a bounded association
list, so union costs O(V), sorting O(E log E), and the proposal O(EV).
The output is reordered to original source edge order before certificate checking.
No proposal is a minimum-tree claim. A union-find refinement can replace this
representation without changing either certificate or source identity.\<close>
fun component where
 "component [] v = v"
| "component ((x,r)#xs) v = (if x=v then r else component xs v)"
fun kruskal_step where
 "kruskal_step e (labels,chosen) =
  (let a=component labels (tail e); b=component labels (head e)
   in if a=b then (labels,chosen)
      else (map (\<lambda>(v,r). (v,if r=b then a else r)) labels, row_key e#chosen))"
definition kruskal_proposal where
 "kruskal_proposal g =
  (let chosen=snd (fold kruskal_step (sort_key weight (sort_key row_key (edges g)))
      (map (\<lambda>v. (v,v)) (vertices g),[]))
   in filter (\<lambda>e. row_key e \<in> set chosen) (edges g))"

definition canonical_tree where
 "canonical_tree g tree \<longleftrightarrow>
   filter (\<lambda>e. row_key e \<in> set (map row_key tree)) (edges g)=tree"
lemma filter_in_subsets: "filter p xs \<in> set (subsets xs)"
 by (induction xs) auto
lemma canonical_tree_original_order:
 "canonical_tree g tree \<Longrightarrow> tree \<in> set (subsets (edges g))"
 using filter_in_subsets by (auto simp: canonical_tree_def)
definition feasible_tree_check where
 "feasible_tree_check g tree \<longleftrightarrow> canonical_tree g tree \<and>
  length tree+1=length (vertices g) \<and>
  (case vertices g of [] \<Rightarrow> False | v#vs \<Rightarrow>
    set (vertices g) \<subseteq> set (reachable (length (vertices g)) tree [v]))"
lemma feasible_tree_check_sound:
 "feasible_tree_check g tree \<Longrightarrow> spanning_tree g tree"
 using canonical_tree_original_order by (auto simp: feasible_tree_check_def spanning_tree_def)
fun reverse_edge where
 "reverse_edge e = e\<lparr>tail:=head e, head:=tail e\<rparr>"
definition tree_graph where
 "tree_graph g tree = g\<lparr>edges:=tree @ map reverse_edge tree,directed:=True\<rparr>"
fun fundamental_edge_check where
 "fundamental_edge_check g tree e =
   (case propose_path (Suc (length (vertices g))) (length (vertices g)) (length (vertices g))
      (tree_graph g tree) (tail e) (head e) of
     ProposedPath path \<Rightarrow> feasible_path (tree_graph g tree) (tail e) (head e) path \<and>
       (\<forall>step\<in>set path. weight step \<le> weight e)
    | _ \<Rightarrow> False)"
definition cycle_certificate_check where
 "cycle_certificate_check g tree \<longleftrightarrow> \<not> directed g \<and>
   feasible_tree_check g tree \<and> (\<forall>e\<in>set (edges g). fundamental_edge_check g tree e)"
lemma cycle_certificate_feasible:
 "cycle_certificate_check g tree \<Longrightarrow> \<not> directed g \<and> spanning_tree g tree"
 using feasible_tree_check_sound by (auto simp: cycle_certificate_check_def)

text \<open>The missing exchange theorem is deliberately not asserted here:
wellformed_graph g and cycle_certificate_check g tree must imply minimum_tree g tree.
Until that native theorem and execution bridge are admitted, this checker output
is a feasible tree with an inspected cycle certificate, not licensed optimality.
Negative signed weights are compared exactly and require no Dijkstra restriction.\<close>
end
