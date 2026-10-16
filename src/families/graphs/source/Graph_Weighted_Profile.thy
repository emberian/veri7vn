theory Graph_Weighted_Profile
 imports Veri7vn_Relation_Import.Relation_Source_Import Veri7vn_Graph_Core.Graph_Dispatch
begin

text \<open>Weighted graph source profile, revision 1: exact six-column tagged rows.
Vertex rows are [0,id,NULL,NULL,NULL,NULL]. Edge rows are
[1,edge_id,tail,head,signed_integer_weight,direction], direction 0 undirected or
1 directed. All vertices must be declared, including isolated vertices. IDs are
unsigned at most 256 bits; signed weight magnitudes are at most 512 bits. Original
SQL cells remain in the acquired source; numeric spelling is not row identity.
Decimals, floats and mixed-direction input are explicitly outside this profile.\<close>
fun decode_graph_id where
 "decode_graph_id (Cell_Integer False bs) =
    (if byte_string bs \<and> length bs\<le>32 then Some (magnitude_nat bs) else None)"
| "decode_graph_id _ = None"
fun decode_graph_weight where
 "decode_graph_weight (Cell_Integer neg bs) =
    (if byte_string bs \<and> length bs\<le>64
     then Some (if neg then - int (magnitude_nat bs) else int (magnitude_nat bs)) else None)"
| "decode_graph_weight _ = None"
datatype weighted_graph_row = DeclaredVertex nat | DeclaredEdge graph_edge bool
fun decode_weighted_graph_row where
 "decode_weighted_graph_row [tag,id,Cell_Null,Cell_Null,Cell_Null,Cell_Null] =
   (if decode_graph_id tag=Some 0 then map_option DeclaredVertex (decode_graph_id id) else None)"
| "decode_weighted_graph_row [tag,id,s,t,w,mode] =
   (if decode_graph_id tag=Some 1 then
     case (decode_graph_id id,decode_graph_id s,decode_graph_id t,decode_graph_weight w,decode_graph_id mode) of
       (Some key,Some a,Some b,Some cost,Some direction) \<Rightarrow>
         if direction\<le>1 then Some (DeclaredEdge
           \<lparr>row_key=key,relation_key=0,tail=a,head=b,weight=cost\<rparr> (direction=1)) else None
     | _ \<Rightarrow> None
    else None)"
| "decode_weighted_graph_row _ = None"

fun project_weighted_rows where
 "project_weighted_rows n mode [] = Some ([],[],[])"
| "project_weighted_rows n mode (row#rows) =
   (case (decode_weighted_graph_row row,project_weighted_rows (Suc n) mode rows) of
      (Some (DeclaredVertex v),Some (vs,es,lineage)) \<Rightarrow> Some (v#vs,es,lineage)
    | (Some (DeclaredEdge e edge_mode),Some (vs,es,lineage)) \<Rightarrow>
        if edge_mode=mode then Some (vs,e#es,(row_key e,n)#lineage) else None
    | _ \<Rightarrow> None)"
definition project_weighted_graph where
 "project_weighted_graph mode rows =
  (case project_weighted_rows 0 mode rows of None \<Rightarrow> None
   | Some (vs,es,lineage) \<Rightarrow>
      let g=\<lparr>vertices=vs,edges=es,directed=mode\<rparr>
      in if wellformed_graph g then Some (g,lineage) else None)"
lemma weighted_projection_wellformed:
 "project_weighted_graph mode rows=Some (g,lineage) \<Longrightarrow>
  wellformed_graph g \<and> directed g=mode"
 by (auto simp: project_weighted_graph_def Let_def split: option.splits prod.splits if_splits)
lemma weighted_rows_lineage:
 "project_weighted_rows n mode rows=Some (vs,es,lineage) \<Longrightarrow>
  (key,k)\<in>set lineage \<Longrightarrow>
  \<exists>e\<in>set es. \<exists>row. row_key e=key \<and>
    (k,row)\<in>set (zip [n..<n+length rows] rows) \<and>
    decode_weighted_graph_row row=Some (DeclaredEdge e mode)"
 by (induction rows arbitrary: n vs es lineage)
   (auto simp: upt_conv_Cons split: option.splits weighted_graph_row.splits prod.splits if_splits)
lemma weighted_edges_have_lineage:
 "project_weighted_rows n mode rows=Some (vs,es,lineage) \<Longrightarrow>
  e\<in>set es \<Longrightarrow> \<exists>k. (row_key e,k)\<in>set lineage"
 by (induction rows arbitrary: n vs es lineage)
   (auto split: option.splits weighted_graph_row.splits prod.splits if_splits)
lemma weighted_rows_original_edge:
 "project_weighted_rows n mode rows=Some (vs,es,lineage) \<Longrightarrow> e\<in>set es \<Longrightarrow>
  \<exists>row\<in>set rows. decode_weighted_graph_row row=Some (DeclaredEdge e mode)"
 by (induction rows arbitrary: n vs es lineage)
   (auto split: option.splits weighted_graph_row.splits prod.splits if_splits)
lemma weighted_projection_edge_source:
 "project_weighted_graph mode rows=Some (g,lineage) \<Longrightarrow> e\<in>set (edges g) \<Longrightarrow>
  \<exists>k<length rows. decode_weighted_graph_row (rows!k)=Some (DeclaredEdge e mode)"
 using weighted_rows_original_edge
 by (auto simp: project_weighted_graph_def Let_def in_set_conv_nth split: option.splits prod.splits if_splits)
lemma weighted_projection_lineage:
 "project_weighted_graph mode rows=Some (g,lineage) \<Longrightarrow> (key,k)\<in>set lineage \<Longrightarrow>
  k<length rows \<and> (\<exists>e\<in>set (edges g). row_key e=key \<and>
    decode_weighted_graph_row (rows!k)=Some (DeclaredEdge e mode))"
 using weighted_rows_lineage[where n=0]
 by (auto simp: project_weighted_graph_def Let_def set_zip split: option.splits prod.splits if_splits)
lemma weighted_projection_edge_has_lineage:
 "project_weighted_graph mode rows=Some (g,lineage) \<Longrightarrow> e\<in>set (edges g) \<Longrightarrow>
  \<exists>k<length rows. (row_key e,k)\<in>set lineage"
 using weighted_edges_have_lineage weighted_projection_lineage
 by (auto simp: project_weighted_graph_def Let_def split: option.splits prod.splits if_splits)

lemma weighted_integer_exact:
 "byte_string bs \<Longrightarrow> length bs\<le>64 \<Longrightarrow>
  decode_graph_weight (Cell_Integer neg bs)=
    Some (if neg then - int (magnitude_nat bs) else int (magnitude_nat bs))"
 by simp
end
