theory Row_Plan_Tests
  imports "Veri7vn_Row_Plans.Veri7vn_Row_Slots"
begin

definition row_context :: source_plan_context where
  "row_context = \<lparr>plan_executable_generation = 4, installed_executable_generation = 4,
    pinned_source_snapshot = RetainedSourceSnapshot 10, pinned_session_state = 20,
    pinned_evaluation_clock = \<lparr>basis = Monotonic ''fixture'', ticks = 30\<rparr>,
    pinned_source_policy = 40, pinned_dependencies = [10,40], materialization_limit = 8\<rparr>"
definition acquired_context where
  "acquired_context = row_context\<lparr>pinned_source_snapshot := ReservedSourceOutput 50\<rparr>"

definition duplicate_row where "duplicate_row = [Cell_Integer False [1],Cell_Null]"
definition extra_row where "extra_row = [Cell_Integer False [2],Cell_Blob [0,255]]"
definition row_input where
  "row_input = Source_Batch 2 [duplicate_row, duplicate_row, extra_row] False"
definition row_requirement where
  "row_requirement = \<lparr>requested_row_predicate =
    RowAnd (IntegerAtLeast 0 1) (CellIsNull 1), requested_row_conditions = [7,7,8]\<rparr>"
definition row_plan_fixture where
  "row_plan_fixture =
    (specialize_row_query row_context row_requirement row_input =
      Some [(1,NodeValue (MaterializedRows
          (Source_Batch 2 [duplicate_row, duplicate_row] False)) [7,8]),
        (2,NodeValue (MaterializedCount 2 False) [7,8])])"
ML \<open>
  if @{code row_plan_fixture} then
    writeln "PLANS actual_imported_rows_query_count PASS"
  else error "imported row query/count lost typed values or source scope"
\<close>

definition assertion_metadata :: "unit source_assertion" where
  "assertion_metadata = \<lparr>reported_value = (), reported_rank = Some (Named_Rank ''declared''),
    reported_units = None, reported_references = [''retained-raw''],
    reported_import_loss = [], reported_applicability = [''observed population'']\<rparr>"
definition observation_metadata :: "unit observation" where
  "observation_metadata = \<lparr>source_id = ''fixture'', sequence_id = 0,
    configuration = ''config'', schema_version = ''rows-v1'', origin = Unknown_Origin,
    event_clock = Some \<lparr>basis = Source_Event ''fixture'', ticks = 5\<rparr>,
    receipt_clock = \<lparr>basis = Monotonic ''fixture'', ticks = 30\<rparr>,
    payload = Missing, qualifiers = [''reported''], raw_reference = Some ''retained-raw''\<rparr>"
definition qualified_observation where
  "qualified_observation = attach_batch assertion_metadata observation_metadata
    (Source_Batch 2 [duplicate_row, duplicate_row, extra_row] True)"
definition missing_observation where
  "missing_observation = qualified_observation\<lparr>sequence_id := 1, payload := Missing\<rparr>"
definition acquired_requirement where
  "acquired_requirement = \<lparr>requested_population_policy = ObservedKnownSelection, requested_population_plan =
      Window (Source_Event ''fixture'') 0 10 Population,
    requested_row_schema = ''rows-v1'', requested_row_columns = 2,
    requested_qualified_predicate = RowAnd (IntegerAtLeast 0 1) (CellIsNull 1),
    requested_acquisition_conditions = [7,7,8]\<rparr>"
definition qualified_plan_fixture where
  "qualified_plan_fixture = (let observations = [qualified_observation, missing_observation] in
    let report = select_population_report (requested_population_plan acquired_requirement) observations in
    case report_row_view ''rows-v1'' 2 report of None \<Rightarrow> False | Some view \<Rightarrow>
      let selected = view\<lparr>view_rows := [duplicate_row,duplicate_row]\<rparr> in
      \<not> view_materialized view \<and>
      specialize_acquired_query acquired_context acquired_requirement observations =
      Some [(1,NodeValue (QualifiedPopulation report) [7,8]),
        (2,NodeValue (QualifiedRows view) [7,8]),
        (3,NodeValue (QualifiedRows selected) [7,8]),
        (4,NodeValue (QualifiedCount 2 selected) [7,8])])"
ML \<open>
  if @{code qualified_plan_fixture} then
    writeln "PLANS qualified_window_rows_missing_scope PASS"
  else error "qualified window/query/count lost source population or scope"
\<close>

definition exact_integer_fixture where
  "exact_integer_fixture = (let smaller = [Cell_Integer False [9,24,78,114,160,0]];
       larger = [Cell_Integer False [9,24,78,114,160,1]];
       requirement = \<lparr>requested_row_predicate = IntegerAtLeast 0 10000000000001,
         requested_row_conditions = []\<rparr>
    in specialize_row_query row_context requirement (Source_Batch 1 [smaller,larger] True) =
      Some [(1,NodeValue (MaterializedRows (Source_Batch 1 [larger] True)) []),
        (2,NodeValue (MaterializedCount 1 True) [])])"
ML \<open>
  if @{code exact_integer_fixture} then writeln "PLANS row_exact_large_integer PASS"
  else error "exact integer query conflated distinguishable inputs"
\<close>

definition unknown_window_fixture where
  "unknown_window_fixture = (let observations = [qualified_observation\<lparr>event_clock := None\<rparr>];
      known = specialize_acquired_query acquired_context acquired_requirement observations;
      closed = specialize_acquired_query acquired_context
        (acquired_requirement\<lparr>requested_population_policy := RequireClassifiedWindow\<rparr>) observations
    in closed = Some [(1,NodeBlocked 116),(2,NodeBlocked 114),(3,NodeBlocked 114),(4,NodeBlocked 114)] \<and>
      (case known of Some [one,two,three,(gid,NodeValue (QualifiedCount count view) conditions)] \<Rightarrow>
        gid = 4 \<and> count = 0 \<and> view_population view = [] \<and>
        view_original_population view = observations \<and>
        view_unclassified_population view = observations \<and>
        view_materialized view \<and> conditions = [7,8] | _ \<Rightarrow> False))"
ML \<open>
  if @{code unknown_window_fixture} then writeln "PLANS unknown_window_policy_scope PASS"
  else error "empty known selection was promoted to a classified full window"
\<close>

definition real_domain_fixture where
  "real_domain_fixture = (let real = Cell_RealBits [63,185,153,153,153,153,153,154];
    batch = Source_Batch 1 [[real]] True in
    row_safety row_context (SelectRows (IntegerAtLeast 0 0)) [MaterializedRows batch] =
      GuardRefuted 111 \<and>
    row_safety row_context (SelectRows (CellEquals 0 real)) [MaterializedRows batch] =
      GuardEstablished \<and>
    row_dispatch (SelectRows (CellEquals 0 real)) [MaterializedRows batch] =
      Some (MaterializedRows batch))"
ML \<open>
  if @{code real_domain_fixture} then writeln "PLANS real_bits_domain_guard PASS"
  else error "unsupported REAL integer order became a false match or altered bytes"
\<close>

lemma out_of_schema_query_rejected_before_dispatch:
  "row_safety row_context (SelectRows (CellIsNull 2)) [MaterializedRows row_input] =
    GuardRefuted 111"
  by (simp add: row_context_def row_input_def)

definition long_cell_fixture where
  "long_cell_fixture = (let cell = Cell_Text (replicate 300 65);
      batch = Source_Batch 1 [[cell],[cell]] False;
      requirement = \<lparr>requested_row_predicate = CellEquals 0 cell,
        requested_row_conditions = []\<rparr>
    in \<not> snapshot_wellformed (batch_snapshot batch) \<and>
      snapshot_data_valid (batch_snapshot batch) \<and>
      specialize_row_query row_context requirement batch =
        Some [(1,NodeValue (MaterializedRows batch) []),
          (2,NodeValue (MaterializedCount 2 False) [])] \<and>
      row_safety row_context (SelectRows (CellEquals 0 (Cell_Text [256])))
        [MaterializedRows batch] = GuardRefuted 111 \<and>
      row_safety row_context (SelectRows (CellEquals 0 (Cell_RealBits [0])))
        [MaterializedRows batch] = GuardRefuted 111)"
ML \<open>
  if @{code long_cell_fixture} then writeln "PLANS long_cell_shape_literal_guard PASS"
  else error "row data validity retained V1 limits or accepted malformed query bytes"
\<close>

lemma null_is_a_preserved_value:
  "row_cell duplicate_row 1 = Some Cell_Null"
  by (simp add: duplicate_row_def)
end
