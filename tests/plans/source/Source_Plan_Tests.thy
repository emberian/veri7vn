theory Source_Plan_Tests
  imports "Veri7vn_Source_Plans.Veri7vn_Source_Slots" "Veri7vn_Plan_Effects.Veri7vn_Plan_Effects"
begin

definition fixture_context :: source_plan_context where
  "fixture_context = \<lparr>plan_executable_generation = 4,
    installed_executable_generation = 4, pinned_source_snapshot = RetainedSourceSnapshot 10,
    pinned_session_state = 20,
    pinned_evaluation_clock = \<lparr>basis = Monotonic ''fixture'', ticks = 30\<rparr>,
    pinned_source_policy = 40, pinned_dependencies = [10,40], materialization_limit = 8\<rparr>"

definition select_node :: "source_operation plan_node" where
  "select_node = \<lparr>node_id = 1, node_operation = Select Population,
    node_inputs = [0], retained_premises = [8]\<rparr>"
definition extract_node :: "source_operation plan_node" where
  "extract_node = \<lparr>node_id = 2, node_operation = Extract (Values Population),
    node_inputs = [1], retained_premises = [9]\<rparr>"
definition count_node :: "source_operation plan_node" where
  "count_node = \<lparr>node_id = 3, node_operation = Count (Values Population),
    node_inputs = [1], retained_premises = []\<rparr>"

definition first_observation :: "int observation" where
  "first_observation = \<lparr>source_id = ''fixture'', sequence_id = 0,
    configuration = ''config'', schema_version = ''1'', origin = Measured,
    event_clock = None,
    receipt_clock = \<lparr>basis = Monotonic ''fixture'', ticks = 30\<rparr>,
    payload = Valid 1, qualifiers = [''reported''], raw_reference = None\<rparr>"
definition second_observation :: "int observation" where
  "second_observation = first_observation\<lparr>sequence_id := 1, payload := Missing\<rparr>"
definition fixture_population where
  "fixture_population = [first_observation, second_observation]"

definition source_plan_fixture :: bool where
  "source_plan_fixture =
    (run_source_plan fixture_context 3 [(0,(Observation_Batch fixture_population,[7]))]
      [select_node, extract_node, count_node] =
     Some [(1,NodeValue (Observation_Batch fixture_population) [8,7]),
       (2,NodeValue (Value_Batch [1]) [9,8,7]),
       (3,NodeValue (Natural_Count 1) [8,7])])"

ML \<open>
  if @{code source_plan_fixture} then
    writeln "PLANS actual_source_dispatch_generated PASS"
  else error "source graph did not preserve structured results and premises"
\<close>

lemma incompatible_source_edge_rejected:
  "run_source_plan fixture_context 3 [(0,(Observation_Batch [],[]))]
    [select_node, extract_node, count_node\<lparr>node_inputs := [2]\<rparr>] = None"
  by (simp add: run_source_plan_def source_plans.run_checked_def
    select_node_def extract_node_def count_node_def)

lemma stale_generation_never_returns_value:
  "source_plans.execute_node
     (fixture_context\<lparr>plan_executable_generation := 3\<rparr>)
     [(0,(Observation_Batch [],[]))] select_node = NodeFailure 100"
  by (simp add: source_plans.execute_node_def source_plan_guard_def
      fixture_context_def select_node_def)

ML \<open>writeln "PLANS source_wrong_edge_stale_generation PASS"\<close>
end
