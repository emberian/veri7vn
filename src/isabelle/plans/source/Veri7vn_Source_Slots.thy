theory Veri7vn_Source_Slots
  imports Veri7vn_Source_Plans
begin

text \<open>A reserved source graph has a typed input slot before acquisition has
returned its payload. Its graph, interpretation-derived operation choices and
premises remain unchanged when that slot is filled. The slot number addresses a
graph input; it is not a native snapshot/evidence identifier. The native gate must
separately associate the actual attempt/input/output with the registered payload.\<close>
record source_graph_template =
  source_input_slot :: nat
  source_reserved_graph :: "source_operation plan_node list"
  source_reserved_premises :: "nat list"

definition source_template_typed where
  "source_template_typed template \<longleftrightarrow>
    (\<exists>types. source_plans.elaborate_plan
      [(source_input_slot template,Observation_Carrier)]
      (source_reserved_graph template) = Some types)"

definition bind_source_slot where
  "bind_source_slot context fuel observations template =
    run_source_plan context fuel
      [(source_input_slot template,
        (Observation_Batch observations,source_reserved_premises template))]
      (source_reserved_graph template)"

lemma typed_source_slot_elaboration:
  assumes "source_template_typed template"
  shows "\<exists>trace. bind_source_slot context fuel observations template = Some trace"
  using assms unfolding source_template_typed_def bind_source_slot_def
    run_source_plan_def source_plans.run_checked_def by auto

lemma source_slot_specialization_refinement:
  "bind_source_slot context fuel observations template =
    source_spec_plans.run_checked context fuel
      [(source_input_slot template,
        (Observation_Batch observations,source_reserved_premises template))]
      (source_reserved_graph template)"
  by (simp add: bind_source_slot_def run_source_plan_refinement)

text \<open>The refinement is universally quantified over the typed observation
list. Kernel instantiation with an actual registered output supplies the concrete
payload, without a generic natural-number target substitution. This theorem
proves graph computation only. It cannot establish that a payload was actually
returned by an executor, publish a snapshot, mutate a request or replay an effect.
The original reserved requirement and the output association remain native-gate
and authority-ledger obligations. No acquisition-resume runtime is claimed here.\<close>
end
