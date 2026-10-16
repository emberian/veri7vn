theory Graph_Shortest_Proposal
 imports Graph_Search
begin

text \<open>Fixed Bellman-Ford proposal, never an authority. Signed weights are
retained exactly. Every label retains original edge records and its actual root;
virtual high-cost roots cannot create a source-to-target witness. The independent
path/potential checker must accept the result. Negative-cycle diagnostics and
completeness of the global-potential proposal are separate obligations.\<close>
datatype distance_label = DistanceLabel nat int "graph_edge list" nat
fun lookup_distance where
 "lookup_distance [] v = None"
| "lookup_distance (DistanceLabel key cost path origin#rest) v =
   (if key=v then Some (cost,path,origin) else lookup_distance rest v)"
fun oriented_arcs where
 "oriented_arcs mode [] = []"
| "oriented_arcs mode (e#es) = (e,tail e,head e)#
   (if mode \<or> tail e=head e then oriented_arcs mode es
    else (e,head e,tail e)#oriented_arcs mode es)"
fun relax_arc where
 "relax_arc (e,s,t) labels =
  (case (lookup_distance labels s,lookup_distance labels t) of
    (Some (cost,path,origin),Some (previous,old_path,old_origin)) \<Rightarrow>
      if cost+weight e<previous then
        map (\<lambda>label. case label of DistanceLabel key d p root \<Rightarrow>
          if key=t then DistanceLabel key (cost+weight e) (e#path) origin else label) labels
      else labels
   | _ \<Rightarrow> labels)"
fun relax_rounds where
 "relax_rounds 0 arcs labels = labels"
| "relax_rounds (Suc n) arcs labels = relax_rounds n arcs (fold relax_arc arcs labels)"
definition proposal_magnitude where
 "proposal_magnitude g = fold max (map (\<lambda>e. abs (weight e)) (edges g)) 0"
definition shortest_labels where
 "shortest_labels g s =
  (let high=2*int (length (vertices g)+1)*proposal_magnitude g+1;
    initial=map (\<lambda>v. DistanceLabel v (if v=s then 0 else high) [] v) (vertices g)
   in relax_rounds (length (vertices g)) (oriented_arcs (directed g) (edges g)) initial)"
fun label_potentials where
 "label_potentials [] = []"
| "label_potentials (DistanceLabel v cost path origin#rest) = (v,cost)#label_potentials rest"
datatype shortest_proposal = ProposedShortest "graph_edge list" "(nat*int) list"
 | ShortestProposalUnavailable
definition propose_shortest where
 "propose_shortest g s t = (let labels=shortest_labels g s in
   case lookup_distance labels t of None \<Rightarrow> ShortestProposalUnavailable
    | Some (cost,path,origin) \<Rightarrow> if origin=s then
        ProposedShortest (rev path) (label_potentials labels) else ShortestProposalUnavailable)"
end
