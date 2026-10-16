theory Graph_Indexed
  imports Veri7vn_Graph_Core.Graph_Search Veri7vn_Ordered_Index.Ordered_Index
begin

record graph_index =
  vertex_index :: "(nat, unit) RBT.rbt"
  outgoing_index :: "(nat, graph_edge list) RBT.rbt"

definition index_graph :: "graph_snapshot \<Rightarrow> graph_index" where
  "index_graph g = \<lparr>vertex_index = membership_index (vertices g),
    outgoing_index = multi_bucket_index
      (\<lambda>e. if directed g then [tail e] else [tail e, head e]) (edges g)\<rparr>"

definition indexed_outgoing where
  "indexed_outgoing index s = bucket_lookup (outgoing_index index) s"

lemma indexed_outgoing_exact:
  "indexed_outgoing (index_graph g) s = filter (edge_enabled g s) (edges g)"
  by (auto simp: indexed_outgoing_def index_graph_def multi_bucket_index_exact
      edge_enabled_def intro!: filter_cong)

fun indexed_path_check :: "graph_snapshot \<Rightarrow> graph_index \<Rightarrow> nat \<Rightarrow> graph_edge list \<Rightarrow> bool" where
  "indexed_path_check g index s [] = (RBT.lookup (vertex_index index) s \<noteq> None)"
| "indexed_path_check g index s (e#es) =
    (e \<in> set (indexed_outgoing index s) \<and> indexed_path_check g index (edge_target g s e) es)"

lemma indexed_path_check_exact:
  "indexed_path_check g (index_graph g) s es = path_check g s es"
  by (induction es arbitrary: s)
    (auto simp: indexed_outgoing_exact index_graph_def membership_index_exact)

fun indexed_paths_upto :: "nat \<Rightarrow> graph_snapshot \<Rightarrow> graph_index \<Rightarrow> nat \<Rightarrow> graph_edge list list" where
  "indexed_paths_upto 0 g index s =
    (if RBT.lookup (vertex_index index) s \<noteq> None then [[]] else [])"
| "indexed_paths_upto (Suc n) g index s =
    (if RBT.lookup (vertex_index index) s \<noteq> None then [[]] else []) @
    concat (map (\<lambda>e. map ((#) e) (indexed_paths_upto n g index (edge_target g s e)))
      (indexed_outgoing index s))"

lemma indexed_paths_upto_exact:
  "indexed_paths_upto n g (index_graph g) s = paths_upto n g s"
  by (induction n arbitrary: s)
    (simp_all add: indexed_outgoing_exact index_graph_def membership_index_exact)

text \<open>The executable distinct check threads a single set, rather than
rebuilding a suffix index for every element.\<close>
fun distinct_from :: "('a::linorder, unit) RBT.rbt \<Rightarrow> 'a list \<Rightarrow> bool" where
  "distinct_from seen [] = True"
| "distinct_from seen (x#xs) =
    (RBT.lookup seen x = None \<and> distinct_from (RBT.insert x () seen) xs)"

lemma distinct_from_exact:
  "distinct_from seen xs \<longleftrightarrow>
    distinct xs \<and> (\<forall>x\<in>set xs. RBT.lookup seen x = None)"
  by (induction xs arbitrary: seen) auto

definition indexed_wellformed_graph where
  "indexed_wellformed_graph g =
    (let members = membership_index (vertices g) in
      distinct_from RBT.empty (vertices g) \<and>
      distinct_from RBT.empty (map row_key (edges g)) \<and>
      list_all (\<lambda>e. RBT.lookup members (tail e) \<noteq> None \<and>
        RBT.lookup members (head e) \<noteq> None) (edges g))"

lemma indexed_wellformed_graph_exact:
  "indexed_wellformed_graph g = wellformed_graph g"
  by (simp add: indexed_wellformed_graph_def wellformed_graph_def
    distinct_from_exact membership_index_exact list_all_iff Let_def)

lemma enqueue_disabled:
  "\<not> edge_enabled g s e \<Longrightarrow> enqueue_edge g s path depth e state = state"
  by (cases state) simp

lemma enqueue_filter:
  "fold (enqueue_edge g s path depth) (filter (edge_enabled g s) es) state =
    fold (enqueue_edge g s path depth) es state"
  by (induction es arbitrary: state) (auto simp: enqueue_disabled)

fun indexed_frontier_search where
 "indexed_frontier_search 0 maxfront maxdepth g index target front back seen = SearchStopped ExpansionBound"
| "indexed_frontier_search (Suc fuel) maxfront maxdepth g index target front back seen =
  (case queue_take front back of None \<Rightarrow> ProposedCut seen
   | Some (SearchNode s path depth,rest,pending) \<Rightarrow>
     if s=target then ProposedPath (rev path)
     else if depth \<ge> maxdepth then
       indexed_frontier_search fuel maxfront maxdepth g index target rest pending seen
     else let expanded=fold (enqueue_edge g s path depth) (indexed_outgoing index s) (pending,seen)
       in if length rest + length (fst expanded) > maxfront then SearchStopped FrontierBound
       else indexed_frontier_search fuel maxfront maxdepth g index target rest (fst expanded) (snd expanded))"

lemma indexed_frontier_search_exact:
  "indexed_frontier_search fuel maxfront maxdepth g (index_graph g) target front back seen =
    frontier_search fuel maxfront maxdepth g target front back seen"
  by (induction fuel arbitrary: front back seen)
    (auto simp: indexed_outgoing_exact enqueue_filter Let_def
      split: option.splits prod.splits search_node.splits)

definition indexed_propose_path where
 "indexed_propose_path fuel maxfront maxdepth g s t =
   (if maxfront=0 then SearchStopped FrontierBound
    else indexed_frontier_search fuel maxfront maxdepth g (index_graph g) t
      [SearchNode s [] 0] [] [s])"

lemma indexed_propose_path_exact:
  "indexed_propose_path fuel maxfront maxdepth g s t = propose_path fuel maxfront maxdepth g s t"
  by (simp add: indexed_propose_path_def propose_path_def indexed_frontier_search_exact)

end
