theory Veri7vn_Plans
  imports Veri7vn_Plan_Search
begin

datatype guard_verdict = GuardEstablished | GuardRefuted nat | GuardUnresolved nat
datatype ('v,'effect) primitive_result = Computed 'v | PrimitiveFailure nat |
  PrimitiveConflict "'v list" | AwaitAuthority 'effect

record 'op plan_node =
  node_id :: nat
  node_operation :: 'op
  node_inputs :: "nat list"
  retained_premises :: "nat list"

datatype ('v,'effect) node_result = NodeValue 'v "nat list" |
  NodeFailure nat | NodeConflict "'v list" "nat list" | NodeBlocked nat |
  NodeSuspended 'effect "nat list" | NodeBudget

fun fetch_inputs :: "(nat \<times> 'a) list \<Rightarrow> nat list \<Rightarrow> 'a list option" where
  "fetch_inputs env [] = Some []" |
  "fetch_inputs env (n # ns) =
    (case map_of env n of None \<Rightarrow> None | Some x \<Rightarrow>
      map_option ((#) x) (fetch_inputs env ns))"

text \<open>Premise identifiers denote conjunctive conditions, not occurrence
history. Normalize only this list, preserving its first occurrence order. Value
collections and resource/effect/source histories are never normalized here.\<close>
definition merge_conditions where
  "merge_conditions ps = rev (remdups (rev ps))"
lemma set_merge_conditions [simp]: "set (merge_conditions ps) = set ps"
  by (simp add: merge_conditions_def)
lemma distinct_merge_conditions: "distinct (merge_conditions ps)"
  by (simp add: merge_conditions_def)

lemma merge_conditions_idempotent [simp]:
  "merge_conditions (merge_conditions ps) = merge_conditions ps"
  by (simp add: merge_conditions_def)

lemma condition_meaning_preserved:
  "list_all meaning (merge_conditions ps) = list_all meaning ps"
  by (simp add: list_all_iff)
lemma normalized_condition_count:
  "length (merge_conditions ps) = card (set ps)"
  by (simp add: merge_conditions_def length_remdups_card_conv)

locale typed_plan_bundle =
  fixes value_type :: "'v \<Rightarrow> 'ty"
    and argument_types :: "'op \<Rightarrow> 'ty list"
    and result_type :: "'op \<Rightarrow> 'ty"
    and safety_guard :: "'context \<Rightarrow> 'op \<Rightarrow> 'v list \<Rightarrow> guard_verdict"
    and primitive :: "'context \<Rightarrow> 'op \<Rightarrow> 'v list \<Rightarrow> ('v,'effect) primitive_result"
    and type_error :: nat
begin

fun elaborate_plan :: "(nat \<times> 'ty) list \<Rightarrow> 'op plan_node list \<Rightarrow>
    (nat \<times> 'ty) list option" where
  "elaborate_plan env [] = Some env" |
  "elaborate_plan env (n # ns) =
    (if map_of env (node_id n) \<noteq> None \<or>
      fetch_inputs env (node_inputs n) \<noteq> Some (argument_types (node_operation n))
     then None else elaborate_plan
       ((node_id n, result_type (node_operation n)) # env) ns)"

text \<open>The declarative judgment independently states the ordered typed graph.
References must already exist and identifiers cannot be rebound. A conversion
edge is an actual admitted operation in the installed signature, never a cast
introduced merely because two displays or type names happen to match.\<close>
inductive typed_plan where
  empty: "typed_plan env [] env" |
  extend: "map_of env (node_id n) = None \<Longrightarrow>
    fetch_inputs env (node_inputs n) = Some (argument_types (node_operation n)) \<Longrightarrow>
    typed_plan ((node_id n, result_type (node_operation n)) # env) ns out \<Longrightarrow>
    typed_plan env (n # ns) out"

lemma elaboration_sound:
  "elaborate_plan env ns = Some out \<Longrightarrow> typed_plan env ns out"
  by (induction ns arbitrary: env) (auto split: if_splits intro: typed_plan.intros)

lemma elaboration_complete:
  "typed_plan env ns out \<Longrightarrow> elaborate_plan env ns = Some out"
  by (induction rule: typed_plan.induct) simp_all

lemma elaboration_composition:
  "elaborate_plan env (xs @ ys) =
    (case elaborate_plan env xs of None \<Rightarrow> None |
       Some middle \<Rightarrow> elaborate_plan middle ys)"
  by (induction xs arbitrary: env) (auto split: if_splits)

fun check_primitive :: "'op \<Rightarrow> ('v,'effect) primitive_result \<Rightarrow> ('v,'effect) node_result" where
  "check_primitive op (Computed v) =
    (if value_type v = result_type op then NodeValue v [] else NodeFailure type_error)" |
  "check_primitive op (PrimitiveFailure reason) = NodeFailure reason" |
  "check_primitive op (PrimitiveConflict vs) =
    (if list_all (\<lambda>v. value_type v = result_type op) vs
     then NodeConflict vs [] else NodeFailure type_error)" |
  "check_primitive op (AwaitAuthority effect) = NodeSuspended effect []"

lemma checked_value_typed:
  "check_primitive op r = NodeValue v ps \<Longrightarrow>
    value_type v = result_type op \<and> ps = []"
  by (cases r) (auto split: if_splits)

definition execute_node where
  "execute_node context env n =
    (case fetch_inputs env (node_inputs n) of None \<Rightarrow> NodeBlocked type_error |
      Some inputs \<Rightarrow>
      let vs = map fst inputs;
          conditions = merge_conditions (retained_premises n @ concat (map snd inputs))
      in if map value_type vs \<noteq> argument_types (node_operation n) then NodeFailure type_error
      else case safety_guard context (node_operation n) vs of
        GuardRefuted reason \<Rightarrow> NodeFailure reason |
        GuardUnresolved reason \<Rightarrow> NodeBlocked reason |
        GuardEstablished \<Rightarrow>
          (case check_primitive (node_operation n) (primitive context (node_operation n) vs) of
            NodeValue v ignored \<Rightarrow> NodeValue v conditions |
            NodeConflict vs ignored \<Rightarrow> NodeConflict vs conditions |
            NodeSuspended effect ignored \<Rightarrow> NodeSuspended effect conditions |
            other \<Rightarrow> other))"

lemma unresolved_guard_blocks:
  "fetch_inputs env (node_inputs n) = Some inputs \<Longrightarrow>
   map value_type (map fst inputs) = argument_types (node_operation n) \<Longrightarrow>
   safety_guard context (node_operation n) (map fst inputs) = GuardUnresolved reason \<Longrightarrow>
   execute_node context env n = NodeBlocked reason"
  by (simp add: execute_node_def Let_def)

lemma computed_node_typed:
  "execute_node context env n = NodeValue v ps \<Longrightarrow>
    value_type v = result_type (node_operation n) \<and> set (retained_premises n) \<subseteq> set ps"
  unfolding execute_node_def Let_def
  by (auto split: option.splits if_splits guard_verdict.splits node_result.splits
    dest: checked_value_typed)

lemma inherited_conditions_retained:
  assumes "fetch_inputs env (node_inputs n) = Some inputs"
    "execute_node context env n = NodeValue v ps"
  shows "ps = merge_conditions (retained_premises n @ concat (map snd inputs))"
  using assms unfolding execute_node_def Let_def
  by (auto split: if_splits guard_verdict.splits primitive_result.splits node_result.splits)

lemma inherited_condition_set_preserved:
  assumes "fetch_inputs env (node_inputs n) = Some inputs"
    "execute_node context env n = NodeValue v ps"
  shows "set ps = set (retained_premises n) \<union> (\<Union>p\<in>set inputs. set (snd p))"
  using inherited_conditions_retained[OF assms] by auto

lemma guard_before_primitive:
  assumes "fetch_inputs env (node_inputs n) = Some inputs"
    "map value_type (map fst inputs) = argument_types (node_operation n)"
    "execute_node context env n = NodeValue v ps"
  shows "safety_guard context (node_operation n) (map fst inputs) = GuardEstablished"
  using assms unfolding execute_node_def Let_def
  by (auto split: guard_verdict.splits)

fun execute_plan :: "'context \<Rightarrow> nat \<Rightarrow> (nat \<times> ('v \<times> nat list)) list \<Rightarrow>
    'op plan_node list \<Rightarrow> (nat \<times> ('v,'effect) node_result) list" where
  "execute_plan context fuel env [] = []" |
  "execute_plan context 0 env (n # ns) =
    (node_id n, NodeBudget) # execute_plan context 0 env ns" |
  "execute_plan context (Suc fuel) env (n # ns) =
    (let r = execute_node context env n;
         next = (case r of NodeValue v ps \<Rightarrow> (node_id n,(v,ps)) # env | _ \<Rightarrow> env)
     in (node_id n,r) # execute_plan context fuel next ns)"

lemma execute_plan_preserves_parts:
  "map fst (execute_plan context fuel env ns) = map node_id ns"
  by (induction "context" fuel env ns rule: execute_plan.induct) (simp_all add: Let_def)

definition run_checked where
  "run_checked context fuel env ns =
    (case elaborate_plan (map (\<lambda>(n,v). (n,value_type (fst v))) env) ns of
       None \<Rightarrow> None |
       Some types \<Rightarrow> Some (execute_plan context fuel env ns))"

lemma checked_run_has_typed_graph:
  "run_checked context fuel env ns = Some results \<Longrightarrow>
   \<exists>types. typed_plan (map (\<lambda>(n,v). (n,value_type (fst v))) env) ns types"
  unfolding run_checked_def using elaboration_sound by (auto split: option.splits)

text \<open>No result of this interpreter constitutes admission or persistent state.
AwaitAuthority returns data to the generated authority machine. A caller must
validate the graph before execution; closed generated instances supply primitive
and safety_guard, while the native gate owns their semantic bridges.\<close>

end
end
