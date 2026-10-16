theory Graph_Search
 imports Graph_Certificates
begin

datatype graph_stop = ExpansionBound | FrontierBound | DepthBound | OutputBound
  | CertificateFailure
datatype graph_proposal = ProposedPath "graph_edge list" | ProposedCut "nat list"
  | SearchStopped graph_stop
datatype search_node = SearchNode nat "graph_edge list" nat
fun queue_take where
 "queue_take [] [] = None"
| "queue_take (x#xs) back = Some (x,xs,back)"
| "queue_take [] back = (case rev back of [] \<Rightarrow> None | x#xs \<Rightarrow> Some (x,xs,[]))"
fun enqueue_edge where
 "enqueue_edge g s path depth e (back,seen) =
  (if edge_enabled g s e \<and> edge_target g s e \<notin> set seen
   then (SearchNode (edge_target g s e) (e#path) (Suc depth)#back, edge_target g s e#seen)
   else (back,seen))"
fun frontier_search where
 "frontier_search 0 maxfront maxdepth g target front back seen = SearchStopped ExpansionBound"
| "frontier_search (Suc fuel) maxfront maxdepth g target front back seen =
  (case queue_take front back of None \<Rightarrow> ProposedCut seen
   | Some (SearchNode s path depth,rest,pending) \<Rightarrow>
     if s=target then ProposedPath (rev path)
     else if depth \<ge> maxdepth then
       frontier_search fuel maxfront maxdepth g target rest pending seen
     else let expanded=fold (enqueue_edge g s path depth) (edges g) (pending,seen)
       in if length rest + length (fst expanded) > maxfront then SearchStopped FrontierBound
       else frontier_search fuel maxfront maxdepth g target rest (fst expanded) (snd expanded))"
definition propose_path where
 "propose_path fuel maxfront maxdepth g s t =
   (if maxfront=0 then SearchStopped FrontierBound
    else frontier_search fuel maxfront maxdepth g t [SearchNode s [] 0] [] [s])"

text \<open>One-path reachability uses node deduplication and two-list FIFO queues.
It does not claim complete witness enumeration; that operation remains separate.
Each expansion scans the pinned edge list once. A proposed path or cut must pass
the independent checker before it can become a claim. In particular exhausting
the depth can produce an unclosed cut, which must remain a bound diagnostic.\<close>

fun bounded_walk_count where
 "bounded_walk_count 0 branching cap = 1"
| "bounded_walk_count (Suc depth) branching cap =
   min (Suc cap) (1 + branching * bounded_walk_count depth branching cap)"
definition enumeration_fits where
 "enumeration_fits depth g cap \<longleftrightarrow>
   bounded_walk_count depth (length (edges g)) cap \<le> cap"
end
