theory Graph_Source_Resources
 imports Graph_Source Veri7vn_Source_Acquisition.Source_Acquisition_Association
begin

lemma graph_cell_payload_work:
 "graph_cell_work cell \<le> 16+source_cell_payload_bytes cell"
 by (cases cell) simp_all

lemma graph_fold_max_initial:
 "initial \<le> fold max (xs::nat list) initial"
proof (induction xs arbitrary: initial)
 case Nil then show ?case by simp
next
 case (Cons x xs)
 have "max x initial \<le> fold max xs (max x initial)" by (rule Cons.IH)
 then show ?case by simp
qed
lemma graph_fold_max_member:
 assumes "x\<in>set (xs::nat list)"
 shows "x\<le>fold max xs initial"
 using assms
proof (induction xs arbitrary: initial)
 case Nil then show ?case by simp
next
 case (Cons y xs)
 show ?case
 proof (cases "x=y")
  case True
  have "max y initial\<le>fold max xs (max y initial)" by (rule graph_fold_max_initial)
  then show ?thesis using True by simp
 next
  case False
  then have "x\<in>set xs" using Cons.prems by simp
  then show ?thesis using Cons.IH[of "max y initial"] by simp
 qed
qed

lemma graph_row_work_upper:
 assumes "initial\<le>bound" "\<forall>cell\<in>set row. graph_cell_work cell\<le>bound"
 shows "fold (\<lambda>cell current. max (graph_cell_work cell) current) row initial\<le>bound"
 using assms
 by (induction row arbitrary: initial) auto

lemma graph_rows_work_upper:
 assumes "initial\<le>bound" "\<forall>cell\<in>set (concat rows). graph_cell_work cell\<le>bound"
 shows "fold (\<lambda>row total. fold (\<lambda>cell current. max (graph_cell_work cell) current) row total) rows initial\<le>bound"
 using assms
proof (induction rows arbitrary: initial)
 case Nil then show ?case by simp
next
 case (Cons row rows)
 have first: "fold (\<lambda>cell current. max (graph_cell_work cell) current) row initial\<le>bound"
   using Cons.prems by (intro graph_row_work_upper) auto
 have rest: "\<forall>cell\<in>set (concat rows). graph_cell_work cell\<le>bound"
   using Cons.prems by auto
 show ?case using Cons.IH[OF first rest] by simp
qed

lemma graph_max_cell_payload_bound:
 "graph_max_cell_work batch\<le>16+source_batch_max_cell_payload_bytes batch"
proof -
 have each: "\<forall>cell\<in>set (concat (batch_rows batch)).
    graph_cell_work cell\<le>16+source_batch_max_cell_payload_bytes batch"
 proof (intro ballI)
  fix cell assume "cell\<in>set (concat (batch_rows batch))"
  then have "source_cell_payload_bytes cell\<in>set
    (map source_cell_payload_bytes (concat (batch_rows batch)))" by simp
  then have "source_cell_payload_bytes cell\<le>source_batch_max_cell_payload_bytes batch"
    unfolding source_batch_max_cell_payload_bytes_def by (rule graph_fold_max_member)
  then show "graph_cell_work cell\<le>16+source_batch_max_cell_payload_bytes batch"
    using graph_cell_payload_work[of cell] by linarith
 qed
 show ?thesis unfolding graph_max_cell_work_def
   by (rule graph_rows_work_upper[OF _ each]) simp
qed

lemma acquired_graph_output_guard:
 assumes "source_association_meaning a"
   "raw_graph_request_output_permitted (association_rows a)
      (16+association_max_cell_payload_bytes a) request"
 shows "graph_request_output_permitted request (association_batch a)"
proof -
 have dimensions: "association_rows a=length (batch_rows (association_batch a))"
   "association_max_cell_payload_bytes a=source_batch_max_cell_payload_bytes (association_batch a)"
   using assms(1) by (auto simp: source_association_meaning_def)
 show ?thesis
   using assms(2) graph_max_cell_payload_bound[of "association_batch a"] dimensions
   by (intro graph_cached_output_guard[where maxcell="16+association_max_cell_payload_bytes a"]) auto
qed

lemma graph_row_decode_bound:
 "sum_list (map graph_cell_work row) \<le>
   16*length row+sum_list (map source_cell_payload_bytes row)"
proof (induction row)
 case Nil then show ?case by simp
next
 case (Cons cell row)
 show ?case using Cons.IH graph_cell_payload_work[of cell] by (simp; linarith)
qed
lemma graph_rows_decode_bound:
 "sum_list (map (\<lambda>row. 16+sum_list (map graph_cell_work row)) rows) \<le>
   16*length rows+16*sum_list (map length rows)+
   sum_list (map (\<lambda>row. sum_list (map source_cell_payload_bytes row)) rows)"
proof (induction rows)
 case Nil then show ?case by simp
next
 case (Cons row rows)
 show ?case using Cons.IH graph_row_decode_bound[of row]
   by (simp add: algebra_simps; linarith)
qed
lemma graph_valid_rows_cells:
 "rows_data_valid columns rows \<Longrightarrow>
   sum_list (map length rows)=length rows*columns"
 by (induction rows) (auto simp: rows_data_valid_def algebra_simps)
lemma graph_valid_batch_decode_bound:
 assumes "snapshot_data_valid (batch_snapshot batch)"
 shows "graph_decode_work batch\<le>1+16*length (batch_rows batch)+
   16*(length (batch_rows batch)*row_columns (batch_snapshot batch))+
   source_batch_payload_bytes batch"
proof -
 have cells: "sum_list (map length (batch_rows batch))=
   length (batch_rows batch)*row_columns (batch_snapshot batch)"
   using assms graph_valid_rows_cells
   by (cases batch) (auto simp: snapshot_data_valid_def)
 show ?thesis using graph_rows_decode_bound[of "batch_rows batch"] cells
   by (simp add: graph_decode_work_def source_batch_payload_bytes_def)
qed

definition graph_cached_request_budget where
 "graph_cached_request_budget rows columns payload request =
   1+16*rows+16*(rows*columns)+payload+16*(rows+1)^2+
   raw_graph_request_budget rows request"
lemma acquired_graph_request_guard:
 assumes "source_association_meaning a"
   "graph_cached_request_budget (association_rows a) (association_columns a)
      (association_payload_bytes a) request\<le>10000000"
 shows "graph_request_budget_permitted request (association_batch a)"
proof -
 have valid: "snapshot_data_valid (batch_snapshot (association_batch a))"
   using source_association_representation[OF assms(1)] by blast
 have dims: "association_rows a=length (batch_rows (association_batch a))"
   "association_columns a=row_columns (batch_snapshot (association_batch a))"
   "association_payload_bytes a=source_batch_payload_bytes (association_batch a)"
   using assms(1) by (auto simp: source_association_meaning_def)
 have decode: "graph_decode_work (association_batch a)\<le>
   1+16*association_rows a+16*(association_rows a*association_columns a)+association_payload_bytes a"
   using graph_valid_batch_decode_bound[OF valid] dims by simp
 have bounded: "graph_request_budget request (association_batch a)\<le>
   graph_cached_request_budget (association_rows a) (association_columns a)
     (association_payload_bytes a) request"
   using decode dims
   by (auto simp: graph_request_budget_def graph_source_shape_work_def
     graph_cached_request_budget_def; linarith)
 show ?thesis using bounded assms(2)
   by (simp add: graph_request_budget_permitted_def; linarith)
qed

text \<open>The bound uses the retained association's exact cell encoding dimensions.
It asserts neither heap consumption nor an inequality involving raw wire bytes.
The scalar output guard remains a modeled allocation profile, not a serializer theorem.\<close>
end
