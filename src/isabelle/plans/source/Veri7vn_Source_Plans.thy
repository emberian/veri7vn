theory Veri7vn_Source_Plans
  imports "Veri7vn_Plans.Veri7vn_Plans"
    "Veri7vn_Execution_Core.Veri7vn_Source_Execution"
begin

datatype source_input_pin = RetainedSourceSnapshot nat | ReservedSourceOutput nat

record source_plan_context =
  plan_executable_generation :: nat
  installed_executable_generation :: nat
  pinned_source_snapshot :: source_input_pin
  pinned_session_state :: nat
  pinned_evaluation_clock :: clock_reading
  pinned_source_policy :: nat
  pinned_dependencies :: "nat list"
  materialization_limit :: nat

text \<open>The finite source operations are total on their typed inputs. Their
runtime applicability guard enforces generation compatibility and an explicit
finite input materialization bound. This guard establishes neither freshness of
external sources nor source-world truth; those remain pinned claim conditions.
Native identity binding is the sealed staging wrapper's additional obligation.\<close>
definition source_plan_guard where
  "source_plan_guard context op inputs =
    (if plan_executable_generation context \<noteq> installed_executable_generation context
     then GuardRefuted 100 else
     if source_materialization_guard (materialization_limit context) op inputs
     then GuardEstablished else GuardRefuted 101)"

definition source_plan_primitive :: "source_plan_context \<Rightarrow> source_operation \<Rightarrow>
    int source_value list \<Rightarrow> (int source_value, unit) primitive_result" where
  "source_plan_primitive context op inputs =
    (case source_dispatch op inputs of None \<Rightarrow> PrimitiveFailure 102 |
       Some v \<Rightarrow> Computed v)"

global_interpretation source_plans: typed_plan_bundle source_type_of source_arg_types
  source_result_type source_plan_guard source_plan_primitive 103
  defines source_elaborate = source_plans.elaborate_plan
    and source_check_primitive = source_plans.check_primitive
    and source_execute_node = source_plans.execute_node
    and source_execute_plan = source_plans.execute_plan
    and source_run_checked = source_plans.run_checked .

definition run_source_plan where
  "run_source_plan context fuel env plan = source_plans.run_checked context fuel env plan"

definition source_plan_spec_primitive :: "source_plan_context \<Rightarrow> source_operation \<Rightarrow>
    int source_value list \<Rightarrow> (int source_value, unit) primitive_result" where
  "source_plan_spec_primitive context op inputs =
    (case source_meaning op inputs of None \<Rightarrow> PrimitiveFailure 102 |
       Some v \<Rightarrow> Computed v)"

interpretation source_spec_plans: typed_plan_bundle source_type_of source_arg_types
  source_result_type source_plan_guard source_plan_spec_primitive 103 .

lemma source_plan_primitive_refinement:
  "source_plan_primitive = source_plan_spec_primitive"
  by (intro ext) (simp add: source_plan_primitive_def source_plan_spec_primitive_def
    source_dispatch_refinement)

lemma run_source_plan_refinement:
  "run_source_plan context fuel env plan =
    source_spec_plans.run_checked context fuel env plan"
  unfolding run_source_plan_def source_run_checked_def source_plan_primitive_refinement by (rule refl)

lemma source_node_semantics:
  assumes "fetch_inputs env (node_inputs n) = Some inputs"
    "source_plans.execute_node context env n = NodeValue v ps"
  shows "source_meaning (node_operation n) (map fst inputs) = Some v \<and>
    ps = merge_conditions (retained_premises n @ concat (map snd inputs))"
  using assms unfolding source_plans.execute_node_def source_plan_primitive_def Let_def
  by (auto simp: source_dispatch_refinement
    split: if_splits guard_verdict.splits option.splits)

lemma source_guard_materialization:
  "source_plan_guard context op inputs = GuardEstablished \<Longrightarrow>
    plan_executable_generation context = installed_executable_generation context \<and>
    (\<forall>v\<in>set inputs. source_value_extent v \<le> materialization_limit context)"
  by (auto simp: source_plan_guard_def source_materialization_guard_def list_all_iff split: if_splits)

text \<open>This exported constant reuses the actual source_dispatch equations.
A new graph needs no per-plan code generation. Native callable registration and
admission must additionally bind this generated entry to the exact executable
pin and approved code context; this pure definition cannot mint either.\<close>

end
