theory ConceptNet_Source
 imports Veri7vn_Source_Import.Source_Import_Profile Veri7vn_Graph_Core.Graph_Dispatch
begin

text \<open>ConceptNet edge/1 consumes the original eight SQLite columns, not a
numeric graph surrogate. Text identities are exact retained byte strings; no
case folding, plural stripping or word-sense equivalence is asserted. Confidence
uses exact signed integers scaled by 2^1074, including every finite binary64;
it is ranking metadata, never a path cost. All original cells remain attached.\<close>
type_synonym concept_label = "nat list"
record concept_edge =
 concept_ordinal :: nat
 concept_relation :: concept_label
 concept_start :: concept_label
 concept_end :: concept_label
 concept_confidence :: int
 concept_original :: source_row

fun concept_magnitude :: "nat list \<Rightarrow> nat" where
 "concept_magnitude [] = 0"
| "concept_magnitude (b#bs) = b * 256 ^ length bs + concept_magnitude bs"
definition concept_scale :: int where "concept_scale = 2^1074"
fun concept_weight :: "source_cell \<Rightarrow> int option" where
 "concept_weight (Cell_Integer negative bs) = (if byte_string bs \<and> length bs\<le>128
   then Some ((if negative then - int (concept_magnitude bs) else int (concept_magnitude bs))*concept_scale) else None)"
| "concept_weight (Cell_RealBits bs) = (if length bs=8 \<and> byte_string bs then
    (let bits=concept_magnitude bs; exponent=(bits div 2^52) mod 2048;
       fraction=bits mod 2^52; magnitude=(if exponent=0 then fraction else (2^52+fraction)*2^(exponent-1))
     in if exponent=2047 then None else Some (if bits div 2^63=0 then int magnitude else -int magnitude))
    else None)"
| "concept_weight _ = None"
fun concept_decode where
 "concept_decode n [Cell_Text rel,Cell_Text s,pos,Cell_Text t,tpos,w,surface,dataset] =
   (if list_all cell_data_valid [Cell_Text rel,Cell_Text s,pos,Cell_Text t,tpos,w,surface,dataset]
    then map_option (\<lambda>confidence. \<lparr>concept_ordinal=n,concept_relation=rel,
     concept_start=s,concept_end=t,concept_confidence=confidence,
     concept_original=[Cell_Text rel,Cell_Text s,pos,Cell_Text t,tpos,w,surface,dataset]\<rparr>) (concept_weight w)
    else None)"
| "concept_decode _ _ = None"
fun concept_decode_rows where
 "concept_decode_rows n [] = Some []"
| "concept_decode_rows n (row#rows) = (case (concept_decode n row,concept_decode_rows (Suc n) rows) of
    (Some e,Some es) \<Rightarrow> Some (e#es) | _ \<Rightarrow> None)"
lemma concept_decode_original:
 "concept_decode n row=Some e \<Longrightarrow> concept_original e=row \<and> concept_ordinal e=n"
 by (cases "(n,row)" rule: concept_decode.cases) (auto split: option.splits if_splits)
lemma concept_rows_original:
 "concept_decode_rows n rows=Some es \<Longrightarrow> e\<in>set es \<Longrightarrow>
  \<exists>row\<in>set rows. concept_original e=row"
 by (induction rows arbitrary: n es) (auto split: option.splits prod.splits dest: concept_decode_original)
lemma concept_rows_length:
 "concept_decode_rows n rows=Some es \<Longrightarrow> length es=length rows"
 by (induction rows arbitrary: n es) (auto split: option.splits prod.splits)
lemma concept_rows_index:
 "concept_decode_rows n rows=Some es \<Longrightarrow> k<length es \<Longrightarrow>
   concept_original (es!k)=rows!k \<and> concept_ordinal (es!k)=n+k"
 by (induction rows arbitrary: n es k)
   (case_tac k; auto split: option.splits prod.splits dest: concept_decode_original)+

definition concept_dictionary where
 "concept_dictionary es = remdups (map concept_start es @ map concept_end es)"
fun concept_id where
 "concept_id [] label = 0"
| "concept_id (x#xs) label = (if x=label then 0 else Suc (concept_id xs label))"
lemma concept_dictionary_exact:
 "label\<in>set dictionary \<Longrightarrow> dictionary ! concept_id dictionary label=label \<and>
   concept_id dictionary label<length dictionary"
 by (induction dictionary) auto

definition concept_rank_le where
 "concept_rank_le e f \<longleftrightarrow>
   concept_confidence f<concept_confidence e \<or>
   (concept_confidence e=concept_confidence f \<and>
    (lexordp (<) (concept_start e) (concept_start f) \<or>
     (concept_start e=concept_start f \<and>
      (lexordp (<) (concept_end e) (concept_end f) \<or>
       (concept_end e=concept_end f \<and> concept_ordinal e\<le>concept_ordinal f)))))"
fun concept_insert where
 "concept_insert e [] = [e]"
| "concept_insert e (x#xs) = (if concept_rank_le e x then e#x#xs else x#concept_insert e xs)"
fun concept_sort where
 "concept_sort [] = []"
| "concept_sort (e#es) = concept_insert e (concept_sort es)"
lemma concept_insert_set [simp]: "set (concept_insert e es)=insert e (set es)"
 by (induction es) auto
lemma concept_sort_set [simp]: "set (concept_sort es)=set es"
 by (induction es) auto
definition concept_ranked where
 "concept_ranked relation node es = concept_sort
   (filter (\<lambda>e. concept_relation e=relation \<and> concept_start e=node) es)"
definition concept_selected where
 "concept_selected relation cap minimum es = concat (map (\<lambda>node.
   filter (\<lambda>e. minimum\<le>concept_confidence e)
     (take cap (concept_ranked relation node es))) (remdups (map concept_start es)))"
definition concept_project_edge where
 "concept_project_edge dictionary e = \<lparr>row_key=concept_ordinal e,relation_key=0,
   tail=concept_id dictionary (concept_start e),head=concept_id dictionary (concept_end e),weight=1\<rparr>"
lemma concept_project_exact_labels:
 "e\<in>set es \<Longrightarrow>
  concept_dictionary es ! tail (concept_project_edge (concept_dictionary es) e)=concept_start e \<and>
  concept_dictionary es ! head (concept_project_edge (concept_dictionary es) e)=concept_end e \<and>
  weight (concept_project_edge (concept_dictionary es) e)=1"
 using concept_dictionary_exact
 by (auto simp: concept_project_edge_def concept_dictionary_def)
definition concept_graph where
 "concept_graph relation cap minimum es = (let dictionary=concept_dictionary es in
  \<lparr>vertices=[0..<length dictionary],edges=map (concept_project_edge dictionary)
    (concept_selected relation cap minimum es),directed=True\<rparr>)"
lemma concept_selected_original:
 "e\<in>set (concept_selected relation cap minimum es) \<Longrightarrow> e\<in>set es \<and>
   concept_relation e=relation \<and> minimum\<le>concept_confidence e"
 by (auto simp: concept_selected_def concept_ranked_def dest: in_set_takeD)
lemma concept_graph_row_lineage:
 "concept_decode_rows 0 rows=Some es \<Longrightarrow>
  edge\<in>set (edges (concept_graph relation cap minimum es)) \<Longrightarrow>
  \<exists>e\<in>set es. concept_original e\<in>set rows \<and>
   edge=concept_project_edge (concept_dictionary es) e \<and>
   concept_relation e=relation \<and> minimum\<le>concept_confidence e"
 using concept_selected_original concept_rows_original
 by (auto simp: concept_graph_def Let_def)

lemma concept_graph_exact_row:
 assumes decoded: "concept_decode_rows 0 rows=Some es"
     and member: "edge\<in>set (edges (concept_graph relation cap minimum es))"
 shows "\<exists>e\<in>set es. row_key edge<length rows \<and>
   concept_original e=rows ! row_key edge \<and>
   concept_ordinal e=row_key edge \<and>
   concept_relation e=relation \<and> minimum\<le>concept_confidence e \<and>
   edge=concept_project_edge (concept_dictionary es) e"
proof -
 obtain e where e: "e\<in>set es" "edge=concept_project_edge (concept_dictionary es) e"
   "concept_relation e=relation" "minimum\<le>concept_confidence e"
   using concept_graph_row_lineage[OF decoded member] by blast
 obtain k where k: "k<length es" "es!k=e" using e(1) by (auto simp: in_set_conv_nth)
 have idx: "concept_original e=rows!k \<and> concept_ordinal e=k"
   using concept_rows_index[OF decoded k(1)] k(2) by simp
 have len: "length es=length rows"
   using concept_rows_length[OF decoded] .
 show ?thesis using e k idx len by (auto simp: concept_project_edge_def)
qed

datatype concept_reply = ConceptResourceBound | ConceptSchemaRejected | ConceptUnknownLabel | ConceptCategoryGuard
 | ConceptInconclusive graph_reply
 | ConceptPath "concept_label list" "source_row list" graph_reply bool

fun concept_display_cell where
 "concept_display_cell (Cell_Text bytes) = bytes"
| "concept_display_cell Cell_Null = [78,85,76,76]"
| "concept_display_cell _ = [60,116,121,112,101,100,32,118,97,108,117,101,32,114,101,116,97,105,110,101,100,62]"
fun concept_render_row where
 "concept_render_row [Cell_Text relation,Cell_Text source,pos,Cell_Text target,tpos,w,surface,dataset] =
   Some ([83,111,117,114,99,101,32,114,111,119,58,32] @ source @ [32,91] @ concept_display_cell pos @
     [93,32,45,45] @ relation @ [45,45,62,32] @ target @ [32,91] @ concept_display_cell tpos @
     [93,59,32,100,97,116,97,115,101,116,61] @ concept_display_cell dataset @ [59,32,115,117,114,102,97,99,101,61] @ concept_display_cell surface)"
| "concept_render_row _ = None"
fun concept_render_reply where
 "concept_render_reply (ConceptPath dictionary rows answer complete) =
    map (\<lambda>row. (row,concept_render_row row)) rows"
| "concept_render_reply _ = []"
lemma concept_render_preserves_rows:
 "map fst (concept_render_reply (ConceptPath dictionary rows answer complete))=rows"
 by simp

definition concept_isa :: concept_label where "concept_isa = [73,115,65]"
definition concept_query where
 "concept_query nv ne source target batch =
  (if row_columns (batch_snapshot batch)\<noteq>8 then ConceptSchemaRejected else
   case concept_decode_rows 0 (batch_rows batch) of None \<Rightarrow> ConceptSchemaRejected
   | Some es \<Rightarrow> (let dictionary=concept_dictionary es;
      g=concept_graph concept_isa 8 concept_scale es;
      indegree=length (filter (\<lambda>e. concept_relation e=concept_isa \<and> concept_end e=target) es)
    in if source\<notin>set dictionary \<or> target\<notin>set dictionary then ConceptUnknownLabel
    else if indegree<30 then ConceptCategoryGuard
    else let answer=graph_dispatch nv ne 3 g
      (SearchPath (concept_id dictionary source) (concept_id dictionary target) 3 400 nv)
    in case answer of FeasiblePath path cost \<Rightarrow>
      if path=[] then ConceptInconclusive answer else ConceptPath dictionary (map (\<lambda>edge. batch_rows batch ! row_key edge) path) answer
        (complete_materialization (batch_snapshot batch))
    | _ \<Rightarrow> ConceptInconclusive answer))"
text \<open>Only a checked feasible path is a positive source-chain observation.
Even an Unreachable result is inconclusive about the corpus: per-node truncation,
minimum confidence and an incomplete acquisition can omit paths. Category degree
counts duplicate assertions in this observed view and is a heuristic, not a sense
consistency proof. Exact labels remove the upstream plural equivalence; same-label sense crossing remains explicitly unresolved.\<close>
lemma concept_query_no_negative:
 "concept_query nv ne source target batch=ConceptPath dictionary rows answer complete \<Longrightarrow>
   \<exists>path cost. answer=FeasiblePath path cost"
 by (auto simp: concept_query_def Let_def split: option.splits if_splits graph_reply.splits)
lemma concept_search_checked:
 "graph_dispatch nv ne 3 g (SearchPath s t 3 400 nv)=FeasiblePath path cost \<Longrightarrow>
   feasible_path g s t path \<and> cost=path_cost path"
 using graph_path_dispatch_refinement[where nv=nv and ne=ne and nd=3 and g=g
   and call="SearchPath s t 3 400 nv"]
 by (auto simp: graph_reply_meaning_def split: if_splits)

datatype concept_source_request = ConceptNetQuery nat nat concept_label concept_label
fun concept_source_production_request where
 "concept_source_production_request (ConceptNetQuery nv ne source target) = True"
fun concept_cell_size where
 "concept_cell_size Cell_Null = 1"
| "concept_cell_size (Cell_Integer negative bs) = 6+length bs"
| "concept_cell_size (Cell_Text bs) = 5+length bs"
| "concept_cell_size (Cell_Blob bs) = 5+length bs"
| "concept_cell_size (Cell_RealBits bs) = 1+length bs"
definition concept_budget_from_dimensions :: "nat \<Rightarrow> nat \<Rightarrow> concept_source_request \<Rightarrow> nat" where
 "concept_budget_from_dimensions n bytes request =
   1 + 16*(n+1)*(bytes+n) + (n+1)^3 + 4096*n + 400*(n+1)*(2*n+4)"
definition concept_payload_size where
 "concept_payload_size batch = sum_list (map (\<lambda>row. sum_list (map concept_cell_size row)) (batch_rows batch))"
definition concept_request_budget where
 "concept_request_budget request batch =
   concept_budget_from_dimensions (length (batch_rows batch)) (concept_payload_size batch) request"
lemma concept_budget_payload_bound:
 "bytes\<le>declared_bytes \<Longrightarrow>
  concept_budget_from_dimensions n bytes request \<le>
  concept_budget_from_dimensions n declared_bytes request"
 unfolding concept_budget_from_dimensions_def
 by (intro add_le_mono mult_le_mono) auto
lemma concept_precharge_bound:
 "concept_payload_size batch\<le>declared_bytes \<Longrightarrow>
  concept_request_budget request batch \<le>
   concept_budget_from_dimensions (length (batch_rows batch)) declared_bytes request"
 by (simp add: concept_request_budget_def concept_budget_payload_bound)
text \<open>The fixed conservative charge uses only retained row/cell dimensions.
It precedes decoding, dictionary construction, sorting and graph validation.
These are abstract charged work units, not a CPU-time or memory theorem.\<close>
definition concept_request_work where
 "concept_request_work request batch = concept_request_budget request batch"
definition concept_request_work_permitted where
 "concept_request_work_permitted request batch \<longleftrightarrow>
   concept_request_budget request batch\<le>10000000"
fun run_structured_concept_query where
 "run_structured_concept_query (ConceptNetQuery nv ne source target) batch =
   (if concept_request_work_permitted (ConceptNetQuery nv ne source target) batch
    then concept_query nv ne source target batch else ConceptResourceBound)"
definition structured_concept_snapshot_meaning where
 "structured_concept_snapshot_meaning request batch answer \<longleftrightarrow>
  (case request of ConceptNetQuery nv ne source target \<Rightarrow>
   case answer of ConceptPath dictionary original (FeasiblePath path cost) complete \<Rightarrow>
    (\<exists>es. concept_decode_rows 0 (batch_rows batch)=Some es \<and>
     dictionary=concept_dictionary es \<and>
     source\<in>set dictionary \<and> target\<in>set dictionary \<and>
     30\<le>length (filter (\<lambda>e. concept_relation e=concept_isa \<and> concept_end e=target) es) \<and>
     feasible_path (concept_graph concept_isa 8 concept_scale es)
       (concept_id dictionary source) (concept_id dictionary target) path \<and>
     path\<noteq>[] \<and> cost=path_cost path \<and> original=map (\<lambda>edge. batch_rows batch ! row_key edge) path \<and>
     complete=complete_materialization (batch_snapshot batch))
    | ConceptPath _ _ _ _ \<Rightarrow> False
    | _ \<Rightarrow> True)"
lemma concept_query_refinement:
 "structured_concept_snapshot_meaning request batch (run_structured_concept_query request batch)"
 using concept_search_checked
 by (cases request) (auto simp: structured_concept_snapshot_meaning_def concept_query_def Let_def
   split: option.splits if_splits graph_reply.splits)
end
