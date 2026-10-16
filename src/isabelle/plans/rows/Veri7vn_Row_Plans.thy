theory Veri7vn_Row_Plans
  imports Veri7vn_Row_Population
begin

text \<open>This additional finite family consumes the actual imported row carrier.
Cell equality is exact encoded-cell equality. Integer comparisons instead use the
codec's exact signed-integer meaning. NULL is a cell value, not execution failure.
There is no implicit timestamp column or conversion to scalar observations.\<close>
datatype row_predicate = AnyRow | CellEquals nat source_cell | CellIsNull nat |
  IntegerAtLeast nat int | RowAnd row_predicate row_predicate
fun row_cell where
  "row_cell [] column = None" |
  "row_cell (x # xs) 0 = Some x" |
  "row_cell (x # xs) (Suc n) = row_cell xs n"
fun row_matches where
  "row_matches AnyRow row = True" |
  "row_matches (CellEquals column cell) row = (row_cell row column = Some cell)" |
  "row_matches (CellIsNull column) row = (row_cell row column = Some Cell_Null)" |
  "row_matches (IntegerAtLeast column lower) row =
    (case row_cell row column of None \<Rightarrow> False | Some cell \<Rightarrow>
     case integer_meaning cell of None \<Rightarrow> False | Some value \<Rightarrow> lower \<le> value)" |
  "row_matches (RowAnd p q) row = (row_matches p row \<and> row_matches q row)"
fun row_predicate_typed where
  "row_predicate_typed columns AnyRow = True" |
  "row_predicate_typed columns (CellEquals column cell) =
    (column < columns \<and> cell_data_valid cell)" |
  "row_predicate_typed columns (CellIsNull column) = (column < columns)" |
  "row_predicate_typed columns (IntegerAtLeast column lower) = (column < columns)" |
  "row_predicate_typed columns (RowAnd p q) =
    (row_predicate_typed columns p \<and> row_predicate_typed columns q)"

text \<open>NULL is an explicit nonmatching value for integer predicates. Other
numeric/text/blob carriers require their own admitted ordering bridge; an
unsupported REAL comparison cannot silently become a negative integer result.\<close>
fun integer_order_cell where
  "integer_order_cell Cell_Null = True" |
  "integer_order_cell (Cell_Integer negative magnitude_bytes) = True" |
  "integer_order_cell _ = False"
fun row_predicate_applicable where
  "row_predicate_applicable AnyRow rows = True" |
  "row_predicate_applicable (CellEquals column cell) rows = True" |
  "row_predicate_applicable (CellIsNull column) rows = True" |
  "row_predicate_applicable (IntegerAtLeast column lower) rows =
    list_all (\<lambda>row. case row_cell row column of None \<Rightarrow> False |
      Some cell \<Rightarrow> integer_order_cell cell) rows" |
  "row_predicate_applicable (RowAnd p q) rows =
    (row_predicate_applicable p rows \<and> row_predicate_applicable q rows)"

lemma real_integer_order_unavailable:
  "row \<in> set rows \<Longrightarrow> row_cell row column = Some (Cell_RealBits bits) \<Longrightarrow>
    \<not> row_predicate_applicable (IntegerAtLeast column lower) rows"
proof -
  assume member: "row \<in> set rows" and cell:
    "row_cell row column = Some (Cell_RealBits bits)"
  have bad: "\<not> (case row_cell row column of None \<Rightarrow> False |
      Some value \<Rightarrow> integer_order_cell value)" using cell by simp
  show "\<not> row_predicate_applicable (IntegerAtLeast column lower) rows"
  proof
    assume applicable: "row_predicate_applicable (IntegerAtLeast column lower) rows"
    have "case row_cell row column of None \<Rightarrow> False |
      Some value \<Rightarrow> integer_order_cell value"
      using applicable member by (auto simp: list_all_iff)
    with bad show False by contradiction
  qed
qed

fun select_batch where
  "select_batch predicate (Source_Batch columns rows full) =
    Source_Batch columns (filter (row_matches predicate) rows) full"
lemma select_batch_refinement:
  "batch_rows (select_batch predicate batch) =
    row_index (batch_snapshot batch) (row_matches predicate)"
  by (cases batch) (simp add: row_index_def candidates_def)
lemma select_batch_preserves_data_valid:
  "snapshot_data_valid (batch_snapshot batch) \<Longrightarrow>
    snapshot_data_valid (batch_snapshot (select_batch predicate batch))"
  by (cases batch) (auto simp: snapshot_data_valid_def rows_data_valid_def list_all_iff)
lemma select_batch_length:
  "length (batch_rows (select_batch predicate batch)) \<le> length (batch_rows batch)"
  by (cases batch) (simp add: length_filter_le)

lemma select_batch_scope:
  "complete_materialization (batch_snapshot (select_batch predicate batch)) =
    complete_materialization (batch_snapshot batch)"
  by (cases batch) simp

text \<open>The count is over the exact ordered decoded population, with duplicates.
The Boolean is retained source-declared materialization scope, not evidence that
an external service returned every possible matching row.\<close>
datatype row_operation = SelectRows row_predicate | CountRows |
  SelectPopulation population_policy observation_plan | ViewRows string nat |
  SelectQualifiedRows row_predicate | CountQualifiedRows
datatype row_carrier = RowsCarrier | RowCountCarrier | ObservationRowsCarrier | PopulationRowsCarrier | QualifiedRowsCarrier | QualifiedCountCarrier
datatype row_value = MaterializedRows source_batch | MaterializedCount nat bool |
  QualifiedObservations "qualified_batch_observation list" |
  QualifiedPopulation source_population_report |
  QualifiedRows source_row_view | QualifiedCount nat source_row_view
fun row_type where
  "row_type (MaterializedRows batch) = RowsCarrier" |
  "row_type (MaterializedCount count full) = RowCountCarrier" |
  "row_type (QualifiedObservations observations) = ObservationRowsCarrier" |
  "row_type (QualifiedPopulation report) = PopulationRowsCarrier" |
  "row_type (QualifiedRows view) = QualifiedRowsCarrier" |
  "row_type (QualifiedCount count view) = QualifiedCountCarrier"
fun row_arguments where
  "row_arguments (SelectRows predicate) = [RowsCarrier]" |
  "row_arguments CountRows = [RowsCarrier]" |
  "row_arguments (SelectPopulation policy p) = [ObservationRowsCarrier]" |
  "row_arguments (ViewRows schema columns) = [PopulationRowsCarrier]" |
  "row_arguments (SelectQualifiedRows predicate) = [QualifiedRowsCarrier]" |
  "row_arguments CountQualifiedRows = [QualifiedRowsCarrier]"
fun row_result where
  "row_result (SelectRows predicate) = RowsCarrier" |
  "row_result CountRows = RowCountCarrier" |
  "row_result (SelectPopulation policy p) = PopulationRowsCarrier" |
  "row_result (ViewRows schema columns) = QualifiedRowsCarrier" |
  "row_result (SelectQualifiedRows predicate) = QualifiedRowsCarrier" |
  "row_result CountQualifiedRows = QualifiedCountCarrier"
fun row_dispatch :: "row_operation \<Rightarrow> row_value list \<Rightarrow> row_value option" where
  "row_dispatch (SelectRows predicate) [MaterializedRows batch] =
    Some (MaterializedRows (select_batch predicate batch))" |
  "row_dispatch CountRows [MaterializedRows batch] =
    Some (MaterializedCount (length (batch_rows batch))
      (complete_materialization (batch_snapshot batch)))" |
  "row_dispatch (SelectPopulation policy p) [QualifiedObservations observations] =
    Some (QualifiedPopulation (select_population_report p observations))" |
  "row_dispatch (ViewRows schema columns) [QualifiedPopulation report] =
    map_option QualifiedRows (report_row_view schema columns report)" |
  "row_dispatch (SelectQualifiedRows predicate) [QualifiedRows view] =
    Some (QualifiedRows (view\<lparr>view_rows := filter (row_matches predicate) (view_rows view)\<rparr>))" |
  "row_dispatch CountQualifiedRows [QualifiedRows view] =
    Some (QualifiedCount (length (view_rows view)) view)" |
  "row_dispatch _ _ = None"
fun row_meaning :: "row_operation \<Rightarrow> row_value list \<Rightarrow> row_value option" where
  "row_meaning (SelectRows predicate) [MaterializedRows batch] =
    Some (MaterializedRows (Source_Batch (row_columns (batch_snapshot batch))
      (row_index (batch_snapshot batch) (row_matches predicate))
      (complete_materialization (batch_snapshot batch))))" |
  "row_meaning CountRows [MaterializedRows batch] =
    Some (MaterializedCount (length (ordered_rows (batch_snapshot batch)))
      (complete_materialization (batch_snapshot batch)))" |
  "row_meaning (SelectPopulation policy p) [QualifiedObservations observations] =
    Some (QualifiedPopulation (population_report_meaning p observations))" |
  "row_meaning (ViewRows schema columns) [QualifiedPopulation report] =
    map_option QualifiedRows (report_row_view schema columns report)" |
  "row_meaning (SelectQualifiedRows predicate) [QualifiedRows view] =
    Some (QualifiedRows (view\<lparr>view_rows := candidates (row_matches predicate) (view_rows view)\<rparr>))" |
  "row_meaning CountQualifiedRows [QualifiedRows view] =
    Some (QualifiedCount (length (view_rows view)) view)" |
  "row_meaning _ _ = None"
lemma select_batch_as_snapshot:
  "select_batch predicate batch = Source_Batch (row_columns (batch_snapshot batch))
    (row_index (batch_snapshot batch) (row_matches predicate))
    (complete_materialization (batch_snapshot batch))"
  by (cases batch) (simp add: row_index_def candidates_def)
lemma batch_rows_snapshot [simp]:
  "ordered_rows (batch_snapshot batch) = batch_rows batch"
  by (cases batch) simp

lemma row_dispatch_refinement:
  "row_dispatch op vs = row_meaning op vs"
  by (induction op vs rule: row_dispatch.induct)
     (simp_all add: select_batch_as_snapshot observation_plan_refinement population_report_refinement candidates_def)

lemma qualified_view_type:
  "map_option QualifiedRows candidate = Some result \<Longrightarrow>
    row_type result = QualifiedRowsCarrier"
  by (cases candidate) auto

lemma row_dispatch_type:
  "row_dispatch op vs = Some v \<Longrightarrow> row_type v = row_result op"
  by (induction op vs rule: row_dispatch.induct) (auto dest: qualified_view_type)

fun row_operation_applicable where
  "row_operation_applicable (SelectRows predicate) batch =
    (row_predicate_typed (row_columns (batch_snapshot batch)) predicate \<and>
    row_predicate_applicable predicate (batch_rows batch))" |
  "row_operation_applicable CountRows batch = True" |
  "row_operation_applicable _ batch = False"
text \<open>Preflight counts rows without flattening them. Calling row_view in the
safety guard would allocate its population before the bound is established and
then repeat that work in dispatch.\<close>
definition row_view_input_guard where
  "row_view_input_guard context schema columns observations \<longleftrightarrow>
    length observations \<le> materialization_limit context \<and>
    list_all (\<lambda>obs. schema_version obs = schema) observations \<and>
    list_all (\<lambda>segment. row_columns (batch_snapshot (snd segment)) = columns \<and>
      snapshot_data_valid (batch_snapshot (snd segment))) (row_segments observations) \<and>
    sum_list (map (\<lambda>segment. length (batch_rows (snd segment)))
      (row_segments observations)) \<le> materialization_limit context"
lemma row_view_preflight_sound:
  "row_view_input_guard context schema columns observations \<Longrightarrow>
    \<exists>view. row_view schema columns observations = Some view \<and>
      length (view_rows view) \<le> materialization_limit context"
  by (auto simp: row_view_input_guard_def row_view_def row_population_def
    length_concat comp_def)

fun row_safety where
  "row_safety context op [MaterializedRows batch] =
    (if plan_executable_generation context \<noteq> installed_executable_generation context
     then GuardRefuted 110 else
     if \<not> snapshot_data_valid (batch_snapshot batch) \<or>
       length (batch_rows batch) > materialization_limit context \<or>
       \<not> row_operation_applicable op batch
     then GuardRefuted 111 else GuardEstablished)" |
  "row_safety context (SelectPopulation policy p) [QualifiedObservations observations] =
    (if plan_executable_generation context \<noteq> installed_executable_generation context
     then GuardRefuted 110 else if length observations > materialization_limit context
     then GuardRefuted 111 else if population_policy_holds policy p observations
     then GuardEstablished else GuardUnresolved 116)" |
  "row_safety context (ViewRows schema columns) [QualifiedPopulation report] =
    (if plan_executable_generation context \<noteq> installed_executable_generation context
     then GuardRefuted 110 else if row_view_input_guard context schema columns (report_selected_population report)
     then GuardEstablished else GuardRefuted 115)" |
  "row_safety context (SelectQualifiedRows predicate) [QualifiedRows view] =
    (if plan_executable_generation context \<noteq> installed_executable_generation context
     then GuardRefuted 110 else if \<not> rows_data_valid (view_columns view) (view_rows view) \<or>
       length (view_rows view) > materialization_limit context \<or>
       \<not> row_predicate_typed (view_columns view) predicate \<or>
       \<not> row_predicate_applicable predicate (view_rows view)
     then GuardRefuted 111 else GuardEstablished)" |
  "row_safety context CountQualifiedRows [QualifiedRows view] =
    (if plan_executable_generation context \<noteq> installed_executable_generation context
     then GuardRefuted 110 else if \<not> rows_data_valid (view_columns view) (view_rows view) \<or>
       length (view_rows view) > materialization_limit context
     then GuardRefuted 111 else GuardEstablished)" |
  "row_safety context op vs = GuardRefuted 112"
lemma classified_population_guard_sound:
  "row_safety context (SelectPopulation RequireClassifiedWindow p)
      [QualifiedObservations observations] = GuardEstablished \<Longrightarrow>
    report_unclassified_population (select_population_report p observations) = []"
  by (auto simp: classification_matches_report split: if_splits)

definition row_primitive :: "source_plan_context \<Rightarrow> row_operation \<Rightarrow>
    row_value list \<Rightarrow> (row_value,unit) primitive_result" where
  "row_primitive context op vs = (case row_dispatch op vs of
    None \<Rightarrow> PrimitiveFailure 113 | Some v \<Rightarrow> Computed v)"
global_interpretation row_plans: typed_plan_bundle row_type row_arguments row_result
  row_safety row_primitive 114
  defines row_elaborate = row_plans.elaborate_plan
    and row_check_primitive = row_plans.check_primitive
    and row_execute_node = row_plans.execute_node
    and row_execute_plan = row_plans.execute_plan
    and row_run_checked = row_plans.run_checked .
definition run_row_plan where
  "run_row_plan context fuel env plan = row_plans.run_checked context fuel env plan"

definition row_spec_primitive :: "source_plan_context \<Rightarrow> row_operation \<Rightarrow>
    row_value list \<Rightarrow> (row_value,unit) primitive_result" where
  "row_spec_primitive context op vs = (case row_meaning op vs of
    None \<Rightarrow> PrimitiveFailure 113 | Some v \<Rightarrow> Computed v)"
interpretation row_spec_plans: typed_plan_bundle row_type row_arguments row_result
  row_safety row_spec_primitive 114 .
lemma row_primitive_refinement:
  "row_primitive = row_spec_primitive"
  by (intro ext) (simp add: row_primitive_def row_spec_primitive_def row_dispatch_refinement)
lemma run_row_plan_refinement:
  "run_row_plan context fuel env graph = row_spec_plans.run_checked context fuel env graph"
  unfolding run_row_plan_def row_run_checked_def row_primitive_refinement by (rule refl)

text \<open>The generated source codec already reflects source_batch and source_cell.
A production bundle must consume that mapping and actual accepted typed output,
not serialize every row through cterm or cast an int-observation packet. Native
output association, reserved-slot specialization and final bundle qualification
remain required before this family can be an authoritative acquisition consumer.\<close>
end
