theory Graph_Dispatch
  imports Graph_MST_Checker Graph_Shortest_Proposal
begin

datatype graph_call =
    CheckPath nat nat "graph_edge list"
  | CheckShortest nat nat "graph_edge list" "(nat * int) list"
  | CheckUnreachable nat nat "nat list"
  | EnumeratePaths nat nat nat
  | ShortestPathQuery nat nat
  | SearchPath nat nat nat nat nat
  | MinimumSpanningTree
  | ReferenceMinimumSpanningTree

datatype graph_reply =
    FeasiblePath "graph_edge list" int
  | ShortestPath "graph_edge list" int
  | Unreachable "nat list"
  | DepthBoundedPaths nat "graph_edge list list"
  | MinimumTree "graph_edge list" int
  | Disconnected
  | DisconnectedGraph "nat list"
  | TreeCandidate "graph_edge list" int bool
  | RejectedCertificate
  | DirectedMSTRejected
  | MalformedGraph
  | MaterializationBound
  | SearchExhausted graph_stop

fun potential_value where
  "potential_value [] v = (0::int)"
| "potential_value ((k,x)#xs) v = (if k=v then x else potential_value xs v)"

fun call_materialized where
  "call_materialized nv ne nd (CheckPath s t es) = (length es \<le> nd)"
| "call_materialized nv ne nd (CheckShortest s t es ds) = (length es \<le> nd \<and> length ds \<le> nv)"
| "call_materialized nv ne nd (CheckUnreachable s t cut) = (length cut \<le> nv)"
| "call_materialized nv ne nd (EnumeratePaths s t depth) = (depth \<le> nd)"
| "call_materialized nv ne nd (ShortestPathQuery s t) = (nd \<le>256)"
| "call_materialized nv ne nd (SearchPath s t depth fuel frontier) =
    (depth \<le> nd \<and> fuel \<le> (nv+1)*(ne+1) \<and> frontier \<le> nv)"
| "call_materialized nv ne nd MinimumSpanningTree = True"
| "call_materialized nv ne nd ReferenceMinimumSpanningTree = True"

fun requested_depth where
 "requested_depth (CheckPath s t es) = length es"
| "requested_depth (CheckShortest s t es ds) = length es"
| "requested_depth (EnumeratePaths s t depth) = depth"
| "requested_depth (SearchPath s t depth fuel frontier) = depth"
| "requested_depth _ = 0"
fun graph_operation_work where
 "graph_operation_work v e (CheckPath s t es) = 1 + length es*(e+1)"
| "graph_operation_work v e (CheckShortest s t es ds) = 1+(length es+length ds+1)*(e+1)*(v+1)"
| "graph_operation_work v e (CheckUnreachable s t cut) = 1+(length cut+1)*(e+1)"
| "graph_operation_work v e (EnumeratePaths s t depth) =
    1+bounded_walk_count depth e 65536*(depth+1)*(e+1)"
| "graph_operation_work v e (SearchPath s t depth fuel frontier) = 1+fuel*(e+1)*(v+depth+1)"
| "graph_operation_work v e (ShortestPathQuery s t) = 16*(v+1)*(e+1)*(v+e+1)"
| "graph_operation_work v e MinimumSpanningTree = 16*(e+1)*(v+1)^3"
| "graph_operation_work v e ReferenceMinimumSpanningTree =
    (if e>16 then 1 else (2^e)*(v+1)^3*(e+1))"
definition graph_validation_work where
 "graph_validation_work v e = (v+1)^2+(e+1)^2+(v+1)*(e+1)"
definition graph_work where
 "graph_work g call = graph_validation_work (length (vertices g)) (length (edges g))+
   graph_operation_work (length (vertices g)) (length (edges g)) call"
definition graph_work_guard where
 "graph_work_guard g call \<longleftrightarrow> length (vertices g)\<le>4096 \<and>
   length (edges g)\<le>65536 \<and> requested_depth call\<le>256 \<and>
   graph_work g call\<le>10000000"
lemma graph_work_positive: "graph_work g call > 0"
 by (cases call) (auto simp: graph_work_def graph_validation_work_def)

fun minimum_weight where
 "minimum_weight [] = (0::int)"
| "minimum_weight (w#ws) = (case ws of [] \<Rightarrow> w | _ \<Rightarrow> min w (minimum_weight ws))"
definition fundamental_cut where
 "fundamental_cut g tree e = reachable (length (vertices g))
   (filter (\<lambda>step. row_key step \<noteq> row_key e) tree) [tail e]"
definition price_cut where
 "price_cut g baseline cut prices =
  (let residuals=map (\<lambda>e. weight e-baseline-dual_edge_price prices e)
     (filter (crosses_cut cut) (edges g)); price=max 0 (minimum_weight residuals)
   in if price=0 then prices else (cut,price)#prices)"
definition propose_cut_prices where
 "propose_cut_prices g tree baseline = fold
   (\<lambda>e prices. price_cut g baseline (fundamental_cut g tree e) prices)
   tree []"

fun append_partition_price where
 "append_partition_price labels delta [] = [(labels,delta)]"
| "append_partition_price labels delta ((old,price)#rest) =
   (if old=labels then (old,price+delta)#rest else (labels,delta)#(old,price)#rest)"
fun partition_price_step where
 "partition_price_step e (labels,current,prices) =
  (let next_prices=(if current < weight e \<and> length (remdups (map snd labels))>1
     then append_partition_price labels (weight e-current) prices else prices);
       merged=fst (kruskal_step e (labels,[]))
   in (merged,weight e,next_prices))"
definition propose_partition_prices where
 "propose_partition_prices g baseline =
  (let result=fold partition_price_step (sort_key weight (sort_key row_key (edges g)))
     (map (\<lambda>v. (v,v)) (vertices g),baseline,[])
   in case result of (labels,current,prices) \<Rightarrow> prices)"

definition disconnected_certificate_check where
 "disconnected_certificate_check g cut \<longleftrightarrow> \<not> directed g \<and>
   proper_vertex_cut g cut \<and> (\<forall>e\<in>set (edges g). \<not> crosses_cut cut e)"

definition propose_disconnected_cut where
 "propose_disconnected_cut g = (case vertices g of [] \<Rightarrow> []
   | v#vs \<Rightarrow> reachable (length (vertices g)) (edges g) [v])"

definition graph_dispatch where
  "graph_dispatch max_vertices max_edges max_depth g call =
    (if length (vertices g) > max_vertices \<or> length (edges g) > max_edges \<or>
        \<not> call_materialized max_vertices max_edges max_depth call \<or>
        \<not> graph_work_guard g call then MaterializationBound
     else if \<not> wellformed_graph g then MalformedGraph
     else case call of
       CheckPath s t es \<Rightarrow> (if feasible_path g s t es then FeasiblePath es (path_cost es) else RejectedCertificate)
     | CheckShortest s t es ds \<Rightarrow> (if shortest_certificate g s t es (potential_value ds)
         then ShortestPath es (path_cost es) else RejectedCertificate)
     | CheckUnreachable s t cut \<Rightarrow> (if s \<in> set (vertices g) \<and> t \<in> set (vertices g) \<and> cut_check g s t cut
         then Unreachable cut else RejectedCertificate)
     | EnumeratePaths s t depth \<Rightarrow> (if depth > max_depth then MaterializationBound
         else if enumeration_fits depth g 65536 then DepthBoundedPaths depth (bounded_paths depth g s t)
         else SearchExhausted OutputBound)
     | ShortestPathQuery s t \<Rightarrow>
       (case propose_shortest g s t of
          ProposedShortest es ds \<Rightarrow> (if length es>max_depth then SearchExhausted DepthBound
            else if shortest_certificate g s t es (potential_value ds) then ShortestPath es (path_cost es)
            else SearchExhausted CertificateFailure)
        | ShortestProposalUnavailable \<Rightarrow>
          (case propose_path (Suc (length (vertices g))) (length (vertices g)) max_depth g s t of
             ProposedCut cut \<Rightarrow> (if s\<in>set (vertices g) \<and> t\<in>set (vertices g) \<and> cut_check g s t cut
                 then Unreachable cut else SearchExhausted CertificateFailure)
           | _ \<Rightarrow> SearchExhausted CertificateFailure))
     | SearchPath s t depth fuel frontier \<Rightarrow>
       (case propose_path fuel frontier depth g s t of
          ProposedPath es \<Rightarrow> (if feasible_path g s t es then FeasiblePath es (path_cost es) else SearchExhausted CertificateFailure)
        | ProposedCut cut \<Rightarrow> (if s\<in>set (vertices g) \<and> t\<in>set (vertices g) \<and> cut_check g s t cut
            then Unreachable cut else SearchExhausted DepthBound)
        | SearchStopped reason \<Rightarrow> SearchExhausted reason)
     | MinimumSpanningTree \<Rightarrow> (if directed g then DirectedMSTRejected
         else let tree=kruskal_proposal g in
           if feasible_tree_check g tree then
             let baseline=minimum_weight (map weight (edges g)); prices=propose_partition_prices g baseline
             in if partition_dual_check g tree baseline prices then MinimumTree tree (path_cost tree)
                else TreeCandidate tree (path_cost tree) (cycle_certificate_check g tree)
           else let cut=propose_disconnected_cut g in
             if disconnected_certificate_check g cut then DisconnectedGraph cut
             else SearchExhausted CertificateFailure)
     | ReferenceMinimumSpanningTree \<Rightarrow> (if directed g then DirectedMSTRejected
         else if length (edges g)>16 then SearchExhausted OutputBound
         else case cheapest (spanning_candidates g) of None \<Rightarrow> Disconnected
           | Some tree \<Rightarrow> MinimumTree tree (path_cost tree)))"

lemma dispatch_shortest_sound:
  "graph_dispatch nv ne nd g (CheckShortest s t es ds) = ShortestPath es cost \<Longrightarrow>
    feasible_path g s t other \<Longrightarrow> path_cost es \<le> path_cost other"
  using shortest_certificate_sound
  by (auto simp: graph_dispatch_def split: if_splits)
lemma dispatch_unreachable_sound:
  "graph_dispatch nv ne nd g (CheckUnreachable s t cut) = Unreachable cut \<Longrightarrow>
    \<not> feasible_path g s t es"
  using unreachable_certificate_sound by (auto simp: graph_dispatch_def split: if_splits)
lemma dispatch_mst_sound:
  "graph_dispatch nv ne nd g ReferenceMinimumSpanningTree = MinimumTree tree cost \<Longrightarrow>
    \<not> directed g \<and> minimum_tree g tree \<and> cost=path_cost tree"
  using minimum_tree_sound
  by (auto simp: graph_dispatch_def split: if_splits option.splits)



lemma dispatch_disconnected_scope:
  "graph_dispatch nv ne nd g ReferenceMinimumSpanningTree = Disconnected \<Longrightarrow>
    \<not> (\<exists>tree. spanning_tree g tree)"
  by (auto simp: graph_dispatch_def cheapest_none spanning_candidates_def spanning_tree_def
    split: if_splits option.splits)

definition graph_reply_meaning where
 "graph_reply_meaning nv ne nd g call reply \<longleftrightarrow>
  (if length (vertices g)>nv \<or> length (edges g)>ne \<or> \<not> call_materialized nv ne nd call
   \<or> \<not> graph_work_guard g call then reply=MaterializationBound
   else if \<not> wellformed_graph g then reply=MalformedGraph
   else case call of
    CheckPath s t es \<Rightarrow> (if feasible_path g s t es then reply=FeasiblePath es (path_cost es) else reply=RejectedCertificate)
  | CheckShortest s t es ds \<Rightarrow> (if shortest_certificate g s t es (potential_value ds)
      then reply=ShortestPath es (path_cost es) else reply=RejectedCertificate)
  | CheckUnreachable s t cut \<Rightarrow> (if s\<in>set (vertices g) \<and> t\<in>set (vertices g) \<and> cut_check g s t cut
      then reply=Unreachable cut else reply=RejectedCertificate)
  | EnumeratePaths s t depth \<Rightarrow> (if \<not> enumeration_fits depth g 65536 then reply=SearchExhausted OutputBound else (\<exists>ps. reply=DepthBoundedPaths depth ps \<and>
      (\<forall>es. es\<in>set ps \<longleftrightarrow> feasible_path g s t es \<and> length es\<le>depth)))
  | ShortestPathQuery s t \<Rightarrow> (case reply of
      ShortestPath es cost \<Rightarrow> feasible_path g s t es \<and> cost=path_cost es \<and>
        (\<forall>other. feasible_path g s t other \<longrightarrow> cost\<le>path_cost other)
    | Unreachable cut \<Rightarrow> s\<in>set (vertices g) \<and> t\<in>set (vertices g) \<and> cut_check g s t cut
    | SearchExhausted reason \<Rightarrow> True | _ \<Rightarrow> False)
  | SearchPath s t depth fuel frontier \<Rightarrow> (case reply of
      FeasiblePath es cost \<Rightarrow> feasible_path g s t es \<and> cost=path_cost es
    | Unreachable cut \<Rightarrow> s\<in>set (vertices g) \<and> t\<in>set (vertices g) \<and> cut_check g s t cut
    | SearchExhausted reason \<Rightarrow> True | _ \<Rightarrow> False)
  | MinimumSpanningTree \<Rightarrow> (if directed g then reply=DirectedMSTRejected
      else case reply of MinimumTree tree cost \<Rightarrow> minimum_tree g tree \<and> cost=path_cost tree
      | TreeCandidate tree cost checked \<Rightarrow>
        spanning_tree g tree \<and> cost=path_cost tree \<and> checked=cycle_certificate_check g tree
      | DisconnectedGraph cut \<Rightarrow> disconnected_certificate_check g cut
      | SearchExhausted reason \<Rightarrow> True | _ \<Rightarrow> False)
  | ReferenceMinimumSpanningTree \<Rightarrow> (if directed g then reply=DirectedMSTRejected
      else if length (edges g)>16 then reply=SearchExhausted OutputBound
      else case reply of MinimumTree tree cost \<Rightarrow> minimum_tree g tree \<and> cost=path_cost tree
        | Disconnected \<Rightarrow> \<not>(\<exists>tree. spanning_tree g tree) | _ \<Rightarrow> False))"


lemma shortest_certificate_feasible:
 "shortest_certificate g s t es d \<Longrightarrow> feasible_path g s t es"
 by (simp only: shortest_certificate_def; blast)


fun graph_path_call where
 "graph_path_call MinimumSpanningTree = False"
| "graph_path_call ReferenceMinimumSpanningTree = False"
| "graph_path_call _ = True"

lemma graph_path_dispatch_refinement:
 assumes "graph_path_call call"
 shows "graph_reply_meaning nv ne nd g call (graph_dispatch nv ne nd g call)"
proof (cases call)
 case (CheckPath s t es)
 then show ?thesis by (simp add: graph_reply_meaning_def graph_dispatch_def)
next
 case (CheckShortest s t es ds)
 then show ?thesis by (simp add: graph_reply_meaning_def graph_dispatch_def)
next
 case (CheckUnreachable s t cut)
 then show ?thesis by (simp add: graph_reply_meaning_def graph_dispatch_def)
next
 case (EnumeratePaths s t depth)
 then show ?thesis
   by (auto simp: graph_reply_meaning_def graph_dispatch_def bounded_paths_exact)
next
 case (ShortestPathQuery s t)
 then show ?thesis
   using shortest_certificate_sound shortest_certificate_feasible
   by (auto simp: graph_reply_meaning_def graph_dispatch_def
     split: shortest_proposal.splits graph_proposal.splits)
next
 case (SearchPath s t depth fuel frontier)
 then show ?thesis
   by (auto simp: graph_reply_meaning_def graph_dispatch_def split: graph_proposal.splits)
next
 case MinimumSpanningTree
 then show ?thesis using assms by simp
next
 case ReferenceMinimumSpanningTree
 then show ?thesis using assms by simp
qed

text \<open>This dispatcher has no source-adoption, execution-ticket, publication or
proof authority. Those belong to the fixed service gate. Its finite carriers are
not serialized native theorems. The exhaustive MST implementation is deliberately
bounded by the edge profile; its exponential work must be charged before execution.
A Disconnected reply means no candidate under spanning_tree; the empty vertex
universe has no tree under this convention. No incomplete search emits it.\<close>
end
