theory Veri7vn_Execution_Bundle
  imports "Veri7vn_Source_Admission.Veri7vn_Source_Admission"
    "Veri7vn_Source_Plans.Veri7vn_Source_Plans"
    "Veri7vn_Projection.Veri7vn_Bounded_Projection"
    "Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets"
begin

type_synonym source_environment = "(nat \<times> (int source_value \<times> nat list)) list"
type_synonym source_trace = "(nat \<times> (int source_value, unit) node_result) list"

definition source_request_guard :: "nat \<Rightarrow> source_plan_context \<Rightarrow> nat \<Rightarrow>
    source_environment \<Rightarrow> source_operation plan_node list \<Rightarrow> bool" where
  "source_request_guard bound context fuel env plan \<longleftrightarrow>
    0 < bound \<and> fuel \<le> bound \<and> length env \<le> bound \<and> length plan \<le> bound \<and> length (pinned_dependencies context) \<le> bound \<and>
    list_all (\<lambda>n. size (node_operation n) \<le> bound) plan \<and>
    materialization_limit context \<le> bound \<and>
    list_all (\<lambda>(_,(v,ps)). source_value_extent v \<le> bound \<and> length ps \<le> bound) env \<and>
    list_all (\<lambda>n. length (node_inputs n) \<le> bound \<and> length (retained_premises n) \<le> bound) plan"

definition guarded_source_run :: "nat \<Rightarrow> source_plan_context \<Rightarrow> nat \<Rightarrow>
    source_environment \<Rightarrow> source_operation plan_node list \<Rightarrow> bool \<times> source_trace option" where
  "guarded_source_run bound context fuel env plan =
    (if source_request_guard bound context fuel env plan
      then (True, run_source_plan context fuel env plan) else (False,None))"

definition guarded_source_meaning :: "nat \<Rightarrow> source_plan_context \<Rightarrow> nat \<Rightarrow>
    source_environment \<Rightarrow> source_operation plan_node list \<Rightarrow> bool \<times> source_trace option" where
  "guarded_source_meaning bound context fuel env plan =
    (if source_request_guard bound context fuel env plan
      then (True, source_spec_plans.run_checked context fuel env plan) else (False,None))"

lemma guarded_source_run_refinement:
  "guarded_source_run bound context fuel env plan =
    guarded_source_meaning bound context fuel env plan"
  by (simp add: guarded_source_run_def guarded_source_meaning_def run_source_plan_refinement)
lemma request_guard_before_run:
  "\<not> source_request_guard bound context fuel env plan \<Longrightarrow>
   guarded_source_run bound context fuel env plan = (False,None)"
  by (simp add: guarded_source_run_def)
lemma successful_guarded_run:
  "guarded_source_run bound context fuel env plan = (True,Some trace) \<Longrightarrow>
   source_request_guard bound context fuel env plan \<and>
   run_source_plan context fuel env plan = Some trace"
  by (auto simp: guarded_source_run_def split: if_splits)

ML_file "row_execution.ML"
ML_file "relation_execution.ML"
end
