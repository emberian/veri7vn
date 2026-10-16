theory Graph_Source
 imports Graph_Weighted_Profile
begin

text \<open>The entity relation graph profile uses exact source row ordinals and
unit edge costs. Literal objects reject the whole profile rather than disappearing.
This is a directed relation-chain profile, separate from weighted graph input.\<close>
fun project_entity_edges where
 "project_entity_edges n [] = Some []"
| "project_entity_edges n (r#rs) = (case object r of Literal_Object value \<Rightarrow> None
  | Entity_Object target \<Rightarrow> map_option
      ((#) \<lparr>row_key=n, relation_key=property r, tail=subject r, head=target, weight=1\<rparr>)
      (project_entity_edges (Suc n) rs))"
lemma projected_edge_original_relation:
 "project_entity_edges n rows = Some es \<Longrightarrow> e \<in> set es \<Longrightarrow>
  \<exists>r\<in>set rows. subject r=tail e \<and> property r=relation_key e \<and>
    object r=Entity_Object (head e) \<and> weight e=1"
 by (induction rows arbitrary: n es) (auto split: relation_object.splits option.splits)
lemma projected_edge_length:
 "project_entity_edges n rows = Some es \<Longrightarrow> length es=length rows"
 by (induction rows arbitrary: n es) (auto split: relation_object.splits option.splits)
lemma projected_edge_index:
 "project_entity_edges n rows = Some es \<Longrightarrow> k < length es \<Longrightarrow>
  row_key (es!k)=n+k \<and> tail (es!k)=subject (rows!k) \<and>
  relation_key (es!k)=property (rows!k) \<and>
  object (rows!k)=Entity_Object (head (es!k)) \<and> weight (es!k)=1"
 by (induction rows arbitrary: n es k)
   (case_tac k; auto split: relation_object.splits option.splits)+
lemma projected_edge_ordinals:
 "project_entity_edges n rows = Some es \<Longrightarrow> map row_key es=[n..<n+length rows]"
 by (induction rows arbitrary: n es) (auto simp: upt_conv_Cons split: relation_object.splits option.splits)

definition relation_graph where
 "relation_graph rows = map_option (\<lambda>es.
   \<lparr>vertices=remdups (map tail es @ map head es), edges=es, directed=True\<rparr>)
   (project_entity_edges 0 rows)"
datatype source_graph_reply = GraphSchemaRejected | GraphIncompleteSnapshot
  | GraphSnapshotAnswer graph_reply
  | GraphWeightedSnapshotAnswer "(nat * nat) list" graph_reply
  | GraphUnsupportedOperation
  | GraphRequestBound
  | GraphOutputBound

definition graph_query_batch where
 "graph_query_batch nv ne nd call batch =
   (if row_columns (batch_snapshot batch) \<noteq> 4 then GraphSchemaRejected
    else if \<not> complete_materialization (batch_snapshot batch) then GraphIncompleteSnapshot
    else case decode_relation_rows (batch_rows batch) of None \<Rightarrow> GraphSchemaRejected
      | Some rows \<Rightarrow> (case relation_graph rows of None \<Rightarrow> GraphSchemaRejected
        | Some g \<Rightarrow> GraphSnapshotAnswer (graph_dispatch nv ne nd g call)))"

definition weighted_operation_supported where
 "weighted_operation_supported mode call \<longleftrightarrow> True"
definition weighted_graph_query_batch where
 "weighted_graph_query_batch mode nv ne nd call batch =
   (if row_columns (batch_snapshot batch) \<noteq> 6 then GraphSchemaRejected
    else if \<not> complete_materialization (batch_snapshot batch) then GraphIncompleteSnapshot
    else case project_weighted_graph mode (batch_rows batch) of None \<Rightarrow> GraphSchemaRejected
      | Some (g,lineage) \<Rightarrow> (if weighted_operation_supported mode call then
          GraphWeightedSnapshotAnswer lineage (graph_dispatch nv ne nd g call)
          else GraphUnsupportedOperation))"
datatype source_graph_request = SnapshotGraphQuery nat nat nat graph_call
 | SnapshotWeightedGraphQuery bool nat nat nat graph_call
fun source_graph_production_request where
 "source_graph_production_request (SnapshotGraphQuery nv ne nd ReferenceMinimumSpanningTree) = False"
| "source_graph_production_request (SnapshotWeightedGraphQuery mode nv ne nd ReferenceMinimumSpanningTree) = False"
| "source_graph_production_request _ = True"
lemma reference_mst_not_production:
 "\<not> source_graph_production_request (SnapshotGraphQuery nv ne nd ReferenceMinimumSpanningTree)"
 "\<not> source_graph_production_request (SnapshotWeightedGraphQuery mode nv ne nd ReferenceMinimumSpanningTree)"
 by simp_all
fun run_graph_request_unchecked where
 "run_graph_request_unchecked (SnapshotGraphQuery nv ne nd call) batch = graph_query_batch nv ne nd call batch"
| "run_graph_request_unchecked (SnapshotWeightedGraphQuery mode nv ne nd call) batch =
    weighted_graph_query_batch mode nv ne nd call batch"
fun graph_cell_work where
 "graph_cell_work Cell_Null = 1"
| "graph_cell_work (Cell_Integer neg bytes) = 16+length bytes"
| "graph_cell_work (Cell_Text bytes) = 16+length bytes"
| "graph_cell_work (Cell_Blob bytes) = 16+length bytes"
| "graph_cell_work (Cell_RealBits bytes) = 16+length bytes"
definition graph_decode_work where
 "graph_decode_work batch = 1+sum_list
   (map (\<lambda>row. 16+sum_list (map graph_cell_work row)) (batch_rows batch))"
definition graph_source_shape_work where
 "graph_source_shape_work batch = graph_decode_work batch + 16*(length (batch_rows batch)+1)^2"
definition graph_request_work where
 "graph_request_work request batch = (if graph_source_shape_work batch > 10000000
  then graph_source_shape_work batch else graph_source_shape_work batch +
  (case request of SnapshotGraphQuery nv ne nd call \<Rightarrow>
   (if row_columns (batch_snapshot batch) \<noteq> 4 \<or>
      \<not> complete_materialization (batch_snapshot batch) then 1
   else case decode_relation_rows (batch_rows batch) of None \<Rightarrow> 1
    | Some rows \<Rightarrow> (case relation_graph rows of None \<Rightarrow> 1
      | Some g \<Rightarrow> if graph_work_guard g call then graph_work g call else 10000001))
  | SnapshotWeightedGraphQuery mode nv ne nd call \<Rightarrow>
   if row_columns (batch_snapshot batch) \<noteq> 6 \<or>
      \<not> complete_materialization (batch_snapshot batch) then 1
   else case project_weighted_graph mode (batch_rows batch) of None \<Rightarrow> 1
    | Some (g,lineage) \<Rightarrow> if \<not> weighted_operation_supported mode call then 1
      else if graph_work_guard g call then graph_work g call else 10000001))"
definition graph_request_work_permitted where
 "graph_request_work_permitted request batch \<longleftrightarrow> graph_request_work request batch \<le>10000000"
lemma graph_request_work_positive: "graph_request_work request batch > 0"
 by (auto simp: graph_request_work_def graph_source_shape_work_def graph_decode_work_def split: source_graph_request.splits)
lemma graph_request_raw_shape_bounded:
 "graph_request_work_permitted request batch \<Longrightarrow> graph_source_shape_work batch\<le>10000000"
 by (auto simp: graph_request_work_permitted_def graph_request_work_def split: if_splits)

lemma graph_request_work_bounded:
 "graph_request_work_permitted request batch \<Longrightarrow> 0<graph_request_work request batch \<and>
   graph_request_work request batch \<le>10000000"
 using graph_request_work_positive by (simp add: graph_request_work_permitted_def)

fun source_opcode_budget where
 "source_opcode_budget v e ReferenceMinimumSpanningTree = graph_operation_work v (min e 16) ReferenceMinimumSpanningTree"
| "source_opcode_budget v e call = graph_operation_work v e call"
fun raw_graph_request_budget where
 "raw_graph_request_budget rows (SnapshotGraphQuery nv ne nd call) =
  (if nv>4096 \<or> ne>65536 \<or> nd>256 \<or> requested_depth call>256 then 10000001
   else if \<not> call_materialized nv ne nd call then 1
   else source_opcode_budget (min (2*rows) nv) (min rows ne) call)"
| "raw_graph_request_budget rows (SnapshotWeightedGraphQuery mode nv ne nd call) =
  (if nv>4096 \<or> ne>65536 \<or> nd>256 \<or> requested_depth call>256 then 10000001
   else if \<not> call_materialized nv ne nd call then 1
   else source_opcode_budget (min rows nv) (min rows ne) call)"
definition graph_request_budget where
 "graph_request_budget request batch = (if graph_source_shape_work batch>10000000
   then graph_source_shape_work batch else graph_source_shape_work batch+
     raw_graph_request_budget (length (batch_rows batch)) request)"
definition graph_request_budget_permitted where
 "graph_request_budget_permitted request batch \<longleftrightarrow> graph_request_budget request batch\<le>10000000"
lemma graph_request_budget_positive: "0<graph_request_budget request batch"
 by (auto simp: graph_request_budget_def graph_source_shape_work_def graph_decode_work_def)
lemma graph_request_budget_bounded:
 "graph_request_budget_permitted request batch \<Longrightarrow> 0<graph_request_budget request batch \<and>
   graph_request_budget request batch\<le>10000000"
 using graph_request_budget_positive by (simp add: graph_request_budget_permitted_def)
fun graph_output_nodes where
 "graph_output_nodes v e depth (CheckPath s t es) = length es+1"
| "graph_output_nodes v e depth (CheckShortest s t es ds) = length es+1"
| "graph_output_nodes v e depth (CheckUnreachable s t cut) = length cut+1"
| "graph_output_nodes v e depth (SearchPath s t d fuel frontier) = max d v+1"
| "graph_output_nodes v e depth (ShortestPathQuery s t) = max depth v+1"
| "graph_output_nodes v e depth (EnumeratePaths s t d) = bounded_walk_count d e 65536*(d+1)+1"
| "graph_output_nodes v e depth _ = e+v+1"
fun raw_graph_request_output_nodes where
 "raw_graph_request_output_nodes rows (SnapshotGraphQuery nv ne nd call) =
   graph_output_nodes (min (2*rows) nv) (min rows ne) nd call"
| "raw_graph_request_output_nodes rows (SnapshotWeightedGraphQuery mode nv ne nd call) =
   rows+graph_output_nodes (min rows nv) (min rows ne) nd call"
definition graph_request_output_nodes where
 "graph_request_output_nodes request batch =
   raw_graph_request_output_nodes (length (batch_rows batch)) request"
definition graph_max_cell_work where
 "graph_max_cell_work batch = fold (\<lambda>row total.
    fold (\<lambda>cell current. max (graph_cell_work cell) current) row total) (batch_rows batch) 1"
fun raw_graph_request_output_permitted where
 "raw_graph_request_output_permitted rows maxcell request =
   (raw_graph_request_output_nodes rows request\<le>1024 \<and>
    1024+32*maxcell*raw_graph_request_output_nodes rows request\<le>1048576)"
definition graph_request_output_permitted where
 "graph_request_output_permitted request batch \<longleftrightarrow>
   raw_graph_request_output_permitted (length (batch_rows batch)) (graph_max_cell_work batch) request"
lemma graph_cached_output_guard:
 assumes "graph_max_cell_work batch \<le> maxcell"
   "raw_graph_request_output_permitted (length (batch_rows batch)) maxcell request"
 shows "graph_request_output_permitted request batch"
proof -
 have bound: "32*graph_max_cell_work batch*raw_graph_request_output_nodes (length (batch_rows batch)) request
   \<le> 32*maxcell*raw_graph_request_output_nodes (length (batch_rows batch)) request"
   using assms(1) by (intro mult_le_mono) auto
 show ?thesis using assms(2) bound
   by (auto simp: graph_request_output_permitted_def; linarith)
qed
lemma graph_request_output_node_bound:
 "graph_request_output_permitted request batch \<Longrightarrow> graph_request_output_nodes request batch\<le>1024"
 by (simp add: graph_request_output_permitted_def graph_request_output_nodes_def)

definition run_structured_graph_query where
 "run_structured_graph_query request batch = (if \<not> graph_request_budget_permitted request batch then GraphRequestBound
   else if \<not> graph_request_output_permitted request batch then GraphOutputBound
   else run_graph_request_unchecked request batch)"

definition structured_graph_snapshot_meaning where
 "structured_graph_snapshot_meaning request batch result \<longleftrightarrow>
  (if \<not> graph_request_budget_permitted request batch then result=GraphRequestBound
   else if \<not> graph_request_output_permitted request batch then result=GraphOutputBound else case request of SnapshotGraphQuery nv ne nd call \<Rightarrow>
   (if row_columns (batch_snapshot batch) \<noteq> 4 then result=GraphSchemaRejected
   else if \<not> complete_materialization (batch_snapshot batch) then result=GraphIncompleteSnapshot
   else case decode_relation_rows (batch_rows batch) of None \<Rightarrow> result=GraphSchemaRejected
    | Some rows \<Rightarrow> (case relation_graph rows of None \<Rightarrow> result=GraphSchemaRejected
      | Some g \<Rightarrow> (\<exists>answer. result=GraphSnapshotAnswer answer \<and>
          graph_reply_meaning nv ne nd g call answer)))
  | SnapshotWeightedGraphQuery mode nv ne nd call \<Rightarrow>
   if row_columns (batch_snapshot batch) \<noteq> 6 then result=GraphSchemaRejected
   else if \<not> complete_materialization (batch_snapshot batch) then result=GraphIncompleteSnapshot
   else case project_weighted_graph mode (batch_rows batch) of None \<Rightarrow> result=GraphSchemaRejected
    | Some (g,lineage) \<Rightarrow> (if weighted_operation_supported mode call then
      (\<exists>answer. result=GraphWeightedSnapshotAnswer lineage answer \<and>
       graph_reply_meaning nv ne nd g call answer) else result=GraphUnsupportedOperation))"

fun source_graph_path_request where
 "source_graph_path_request (SnapshotGraphQuery nv ne nd call) = graph_path_call call"
| "source_graph_path_request (SnapshotWeightedGraphQuery mode nv ne nd call) = graph_path_call call"
lemma source_graph_path_excludes_mst:
 "\<not>source_graph_path_request (SnapshotGraphQuery nv ne nd MinimumSpanningTree)"
 "\<not>source_graph_path_request (SnapshotWeightedGraphQuery mode nv ne nd ReferenceMinimumSpanningTree)"
 by simp_all

lemma structured_graph_path_query_refinement:
 assumes "source_graph_path_request request"
 shows "structured_graph_snapshot_meaning request batch (run_structured_graph_query request batch)"
 using assms
 by (cases request) (auto simp: structured_graph_snapshot_meaning_def run_structured_graph_query_def graph_query_batch_def weighted_graph_query_batch_def
   graph_path_dispatch_refinement split: option.splits prod.splits)
lemma source_graph_answer_lineage:
 "graph_query_batch nv ne nd call batch=GraphSnapshotAnswer answer \<Longrightarrow>
  \<exists>rows es. decode_relation_rows (batch_rows batch)=Some rows \<and>
   project_entity_edges 0 rows=Some es \<and>
   (\<forall>k<length es. row_key (es!k)=k \<and> tail (es!k)=subject (rows!k) \<and>
    relation_key (es!k)=property (rows!k) \<and> object (rows!k)=Entity_Object (head (es!k)))"
 using projected_edge_index[where n=0]
 by (auto simp: graph_query_batch_def relation_graph_def split: option.splits if_splits)

lemma weighted_source_answer_lineage:
 "weighted_graph_query_batch mode nv ne nd call batch=GraphWeightedSnapshotAnswer lineage answer \<Longrightarrow>
  (key,k)\<in>set lineage \<Longrightarrow> k<length (batch_rows batch) \<and>
   (\<exists>e. row_key e=key \<and> decode_weighted_graph_row (batch_rows batch!k)=Some (DeclaredEdge e mode))"
 using weighted_projection_lineage
 by (auto simp: weighted_graph_query_batch_def split: option.splits prod.splits if_splits)

lemma weighted_mst_witness_original_rows:
 "weighted_graph_query_batch mode nv ne nd call batch=
    GraphWeightedSnapshotAnswer lineage (MinimumTree tree cost) \<Longrightarrow>
  call=MinimumSpanningTree \<Longrightarrow> e\<in>set tree \<Longrightarrow>
  \<exists>k<length (batch_rows batch). decode_weighted_graph_row (batch_rows batch!k)=Some (DeclaredEdge e mode)"
 using dispatch_default_mst_sound subsets_set_subset weighted_projection_edge_source
 by (auto simp: weighted_graph_query_batch_def minimum_tree_def spanning_tree_def
   split: option.splits prod.splits if_splits)

text \<open>Acquisition retains the entire qualified source assertion observation.
The returned graph claim is conditional on adopting that assertion; this pure
projection does not adopt it, assert source truth or issue an authority token.\<close>
text \<open>The following acquisition wrapper is the existing /1 wire law.
It does not reinterpret streaming /2 bytes. The protected source producer owns
D48 versioned acquisition and supplies the same checked source_batch to the
structured graph interpreter, with actual original-wire provenance retained.\<close>
definition acquire_and_query_graph where
 "acquire_and_query_graph acquisition manifest bytes nv ne nd call =
  (case acquire_native acquisition manifest bytes of None \<Rightarrow> None
   | Some (batch, observation) \<Rightarrow>
     Some (observation, graph_query_batch nv ne nd call batch))"
lemma acquired_graph_refinement:
 "acquire_and_query_graph acquisition manifest bytes nv ne nd call = Some (obs,result) \<Longrightarrow>
  \<exists>batch. manifest_matches acquisition manifest \<and>
    snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch=bytes \<and>
    obs=attach_batch (source_assertion_metadata manifest) (source_observation_metadata manifest) batch \<and>
    result=graph_query_batch nv ne nd call batch"
 by (auto simp: acquire_and_query_graph_def split: option.splits prod.splits dest: acquisition_result_sound)
lemma incomplete_source_no_graph_claim:
 "\<not> complete_materialization (batch_snapshot batch) \<Longrightarrow>
  graph_query_batch nv ne nd call batch \<noteq> GraphSnapshotAnswer answer"
 by (auto simp: graph_query_batch_def)
lemma acquired_graph_source_key:
 "acquire_and_query_graph acquisition manifest bytes nv ne nd call = Some (obs,result) \<Longrightarrow>
  source_id obs=required_source_key acquisition"
 by (auto dest: acquired_graph_refinement simp: attach_batch_def manifest_matches_def)
end
