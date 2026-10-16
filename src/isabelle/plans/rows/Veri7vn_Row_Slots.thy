theory Veri7vn_Row_Slots
  imports Veri7vn_Row_Plans
begin

text \<open>The requested query is immutable and independent of the acquisition's
unknown payload. Its meaning is a function on the exact native source_batch.
An actual BindOutput association can instantiate that argument; it cannot choose
a different predicate merely by returning a theorem about another query.\<close>
record row_query_requirement =
  requested_row_predicate :: row_predicate
  requested_row_conditions :: "nat list"

definition requested_row_graph where
  "requested_row_graph requirement =
    [\<lparr>node_id = 1, node_operation = SelectRows (requested_row_predicate requirement),
      node_inputs = [0], retained_premises = requested_row_conditions requirement\<rparr>,
     \<lparr>node_id = 2, node_operation = CountRows,
      node_inputs = [1], retained_premises = []\<rparr>]"

definition specialize_row_query where
  "specialize_row_query context requirement batch =
    run_row_plan context 2 [(0,(MaterializedRows batch,[]))]
      (requested_row_graph requirement)"

definition requested_row_meaning where
  "requested_row_meaning context requirement batch =
    row_spec_plans.run_checked context 2 [(0,(MaterializedRows batch,[]))]
      (requested_row_graph requirement)"

lemma row_query_native_specialization:
  "specialize_row_query context requirement batch =
    requested_row_meaning context requirement batch"
  by (simp add: specialize_row_query_def requested_row_meaning_def run_row_plan_refinement)

lemma reserved_row_query_typed:
  "row_plans.elaborate_plan [(0,RowsCarrier)] (requested_row_graph requirement) =
    Some [(2,RowCountCarrier),(1,RowsCarrier),(0,RowsCarrier)]"
  by (simp add: requested_row_graph_def)

definition row_query_ready where
  "row_query_ready context requirement batch \<longleftrightarrow>
    plan_executable_generation context = installed_executable_generation context \<and>
    snapshot_data_valid (batch_snapshot batch) \<and>
    length (batch_rows batch) \<le> materialization_limit context \<and>
    row_predicate_typed (row_columns (batch_snapshot batch))
      (requested_row_predicate requirement) \<and>
    row_predicate_applicable (requested_row_predicate requirement) (batch_rows batch)"
lemma row_query_initial_guard:
  "row_query_ready context requirement batch \<Longrightarrow>
   row_safety context (SelectRows (requested_row_predicate requirement))
     [MaterializedRows batch] = GuardEstablished"
  by (simp add: row_query_ready_def)
lemma row_query_selected_guard:
  assumes "row_query_ready context requirement batch"
  shows "row_safety context CountRows
    [MaterializedRows (select_batch (requested_row_predicate requirement) batch)] = GuardEstablished"
proof -
  have bound: "length (batch_rows (select_batch (requested_row_predicate requirement) batch))
      \<le> materialization_limit context"
    using select_batch_length[of "requested_row_predicate requirement" batch] assms
    unfolding row_query_ready_def by (meson order_trans)
  have wf: "snapshot_data_valid
      (batch_snapshot (select_batch (requested_row_predicate requirement) batch))"
    using select_batch_preserves_data_valid[of batch "requested_row_predicate requirement"] assms
    unfolding row_query_ready_def by blast
  show ?thesis using assms bound wf by (simp add: row_query_ready_def)
qed

lemma specialized_row_query_exact_result:
  assumes "row_query_ready context requirement batch"
  defines "selected \<equiv> select_batch (requested_row_predicate requirement) batch"
    and "conditions \<equiv> merge_conditions (requested_row_conditions requirement)"
  shows "specialize_row_query context requirement batch =
    Some [(1,NodeValue (MaterializedRows selected) conditions),
      (2,NodeValue (MaterializedCount (length (batch_rows selected))
        (complete_materialization (batch_snapshot batch))) conditions)]"
proof -
  have initial_guard: "row_safety context
      (SelectRows (requested_row_predicate requirement)) [MaterializedRows batch] = GuardEstablished"
    by (rule row_query_initial_guard[OF assms(1)])
  have selected_guard: "row_safety context CountRows
      [MaterializedRows (select_batch (requested_row_predicate requirement) batch)] = GuardEstablished"
    by (rule row_query_selected_guard[OF assms(1)])
  text \<open>The interpreter recurses on zero/Suc fuel. Its equations do not
  match the opaque numeral two until the constructor form is made explicit.\<close>
  show ?thesis using initial_guard selected_guard
    by (simp add: specialize_row_query_def run_row_plan_def row_plans.run_checked_def
      requested_row_graph_def row_execute_plan_def row_execute_node_def
      row_check_primitive_def typed_plan_bundle.execute_plan.simps
      typed_plan_bundle.execute_node_def typed_plan_bundle.check_primitive.simps row_primitive_def
      selected_def conditions_def Let_def select_batch_scope numeral_2_eq_2)
qed

record acquired_row_requirement =
  requested_population_policy :: population_policy
  requested_population_plan :: observation_plan
  requested_row_schema :: string
  requested_row_columns :: nat
  requested_qualified_predicate :: row_predicate
  requested_acquisition_conditions :: "nat list"

definition requested_acquired_graph where
  "requested_acquired_graph requirement =
    [\<lparr>node_id = 1, node_operation = SelectPopulation (requested_population_policy requirement)
        (requested_population_plan requirement),
      node_inputs = [0], retained_premises = requested_acquisition_conditions requirement\<rparr>,
     \<lparr>node_id = 2, node_operation = ViewRows (requested_row_schema requirement)
        (requested_row_columns requirement), node_inputs = [1], retained_premises = []\<rparr>,
     \<lparr>node_id = 3, node_operation = SelectQualifiedRows (requested_qualified_predicate requirement),
      node_inputs = [2], retained_premises = []\<rparr>,
     \<lparr>node_id = 4, node_operation = CountQualifiedRows,
      node_inputs = [3], retained_premises = []\<rparr>]"

definition specialize_acquired_query where
  "specialize_acquired_query context requirement observations =
    run_row_plan context 4 [(0,(QualifiedObservations observations,[]))]
      (requested_acquired_graph requirement)"
definition requested_acquired_meaning where
  "requested_acquired_meaning context requirement observations =
    row_spec_plans.run_checked context 4 [(0,(QualifiedObservations observations,[]))]
      (requested_acquired_graph requirement)"
lemma acquired_query_native_specialization:
  "specialize_acquired_query context requirement observations =
    requested_acquired_meaning context requirement observations"
  by (simp add: specialize_acquired_query_def requested_acquired_meaning_def run_row_plan_refinement)
lemma acquisition_query_native_link:
  assumes "acquire_native acquisition manifest bytes = Some (batch, observation)"
  shows "manifest_matches acquisition manifest \<and> encode_wire batch = bytes \<and>
    acquisition_request manifest = required_request acquisition \<and>
    acquisition_attempt manifest = required_attempt acquisition \<and>
    acquisition_source_binding manifest = required_source_binding acquisition \<and>
    specialize_acquired_query context requirement [observation] =
      requested_acquired_meaning context requirement
        [attach_batch (source_assertion_metadata manifest)
          (source_observation_metadata manifest) batch]"
  using acquisition_result_sound[OF assms]
    acquisition_keeps_request_attempt_source[OF assms]
  by (auto simp: acquired_query_native_specialization)

lemma reserved_acquired_query_typed:
  "row_plans.elaborate_plan [(0,ObservationRowsCarrier)] (requested_acquired_graph requirement) =
    Some [(4,QualifiedCountCarrier),(3,QualifiedRowsCarrier),(2,QualifiedRowsCarrier),
      (1,PopulationRowsCarrier),(0,ObservationRowsCarrier)]"
  by (simp add: requested_acquired_graph_def)

lemma qualified_selection_preserves_population_scope:
  "row_dispatch (SelectQualifiedRows predicate) [QualifiedRows view] = Some (QualifiedRows selected) \<Longrightarrow>
    view_population selected = view_population view \<and>
    view_original_population selected = view_original_population view \<and>
    view_unclassified_population selected = view_unclassified_population view \<and>
    view_window_diagnostics selected = view_window_diagnostics view \<and>
    view_materialized selected = view_materialized view \<and>
    view_schema selected = view_schema view \<and> view_columns selected = view_columns view \<and>
    view_rows selected = candidates (row_matches predicate) (view_rows view)"
  by (auto simp: candidates_def)
lemma qualified_count_keeps_view:
  "row_dispatch CountQualifiedRows [QualifiedRows view] =
    Some (QualifiedCount (length (view_rows view)) view)"
  by simp

text \<open>The same requirement appears on both sides, including predicate and
retained conditions. The static theorem is universally quantified over batch;
its native specialization must be linked to the exact actual acquisition output
by admission's opaque output association, not by a snapshot number or serialized
proof handle. This does not yet implement that association or BindOutput.\<close>
end
