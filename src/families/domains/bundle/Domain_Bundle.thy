theory Domain_Bundle
  imports "Veri7vn_Domains.Domain_Plans"
    "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Projection.Veri7vn_Bounded_Projection"
begin

datatype domain_call = DomainCall domain_operation "domain_value list" "nat list" "nat option"
fun call_operation where "call_operation (DomainCall op values conditions model) = op"
fun call_values where "call_values (DomainCall op values conditions model) = values"
fun call_conditions where "call_conditions (DomainCall op values conditions model) = conditions"
fun call_model_premise where "call_model_premise (DomainCall op values conditions model) = model"
datatype domain_failure = MalformedCarrier | QuantityMismatch | BelowAbsoluteZero | InvalidSpringParameters | MissingIdealModel
datatype domain_reply = DomainAnswer domain_value "nat list" | DomainRejected domain_failure | DomainBlocked domain_failure

fun call_required_conditions where
  "call_required_conditions call = (case (call_model_premise call,call_operation call) of
    (Some p,Spring _) \<Rightarrow> p # call_conditions call | _ \<Rightarrow> call_conditions call)"
definition domain_rejection_reason where
  "domain_rejection_reason call = (if map domain_type (call_values call) \<noteq> domain_arguments (call_operation call)
    then MalformedCarrier else case call_operation call of
      ConvertLinear a b \<Rightarrow> (if unit_dimension a \<noteq> unit_dimension b then QuantityMismatch else MalformedCarrier)
    | ConvertPoint a b \<Rightarrow> BelowAbsoluteZero
    | ConvertDelta a b \<Rightarrow> MalformedCarrier
    | Spring op \<Rightarrow> InvalidSpringParameters)"
definition registered_domain_dispatch where
  "registered_domain_dispatch call = (case domain_guard (call_model_premise call)
      (call_operation call) (call_values call) of
    GuardEstablished \<Rightarrow> (case domain_dispatch (call_operation call) (call_values call) of
      Some v \<Rightarrow> DomainAnswer v (merge_conditions (call_required_conditions call))
    | None \<Rightarrow> DomainRejected (domain_rejection_reason call))
    | GuardRefuted n \<Rightarrow> DomainRejected MalformedCarrier
    | GuardUnresolved n \<Rightarrow> DomainBlocked MissingIdealModel)"
definition domain_call_meaning where
  "domain_call_meaning call reply \<longleftrightarrow> (case reply of DomainAnswer v conditions \<Rightarrow>
    domain_guard (call_model_premise call) (call_operation call) (call_values call) = GuardEstablished \<and>
    domain_meaning (call_operation call) (call_values call) v \<and>
    conditions=merge_conditions (call_required_conditions call)
  | DomainRejected reason \<Rightarrow>
    (case domain_guard (call_model_premise call) (call_operation call) (call_values call) of
      GuardEstablished \<Rightarrow> reason=domain_rejection_reason call \<and> \<not>(\<exists>v. domain_meaning (call_operation call) (call_values call) v)
    | GuardRefuted n \<Rightarrow> reason=MalformedCarrier | GuardUnresolved n \<Rightarrow> False)
  | DomainBlocked reason \<Rightarrow> reason=MissingIdealModel \<and> (\<exists>n. domain_guard (call_model_premise call) (call_operation call) (call_values call) = GuardUnresolved n))"
lemma domain_execution_refinement:
  "domain_call_meaning call (registered_domain_dispatch call)"
  by (auto simp: domain_call_meaning_def registered_domain_dispatch_def
    domain_dispatch_refinement[symmetric] split: guard_verdict.splits option.splits)
lemma domain_reply_conditions:
  "registered_domain_dispatch call = DomainAnswer value conditions \<Longrightarrow>
    set (call_conditions call) \<subseteq> set conditions"
  by (auto simp: registered_domain_dispatch_def split: guard_verdict.splits option.splits prod.splits
    domain_operation.splits)
lemma domain_reply_model_condition:
  "call_operation call = Spring op \<Longrightarrow>
    registered_domain_dispatch call = DomainAnswer value conditions \<Longrightarrow>
    \<exists>p. call_model_premise call=Some p \<and> p \<in> set conditions"
  by (cases "call_model_premise call")
    (auto simp: registered_domain_dispatch_def split: option.splits)

lemma linear_mismatch_rejected:
  assumes "unit_dimension a \<noteq> unit_dimension b"
  shows "registered_domain_dispatch (DomainCall (ConvertLinear a b) [LinearValue a x] conditions model) = DomainRejected QuantityMismatch"
  using assms by (simp add: registered_domain_dispatch_def domain_rejection_reason_def linear_convert_def)
lemma below_absolute_zero_rejected:
  assumes "kelvin_point a x < 0"
  shows "registered_domain_dispatch (DomainCall (ConvertPoint a b) [PointValue a x] conditions model) = DomainRejected BelowAbsoluteZero"
  using assms by (simp add: registered_domain_dispatch_def domain_rejection_reason_def temperature_convert_def Let_def)
lemma invalid_spring_rejected:
  assumes "domain_dispatch (Spring op) values = None"
    "map domain_type values = domain_arguments (Spring op)"
  shows "registered_domain_dispatch (DomainCall (Spring op) values conditions (Some model)) = DomainRejected InvalidSpringParameters"
  using assms by (simp add: registered_domain_dispatch_def domain_rejection_reason_def)

definition domain_modeled_cost :: "nat \<Rightarrow> nat" where
  "domain_modeled_cost input_nodes = (1+input_nodes)*(1+input_nodes)"
lemma domain_modeled_cost_positive: "0 < domain_modeled_cost input_nodes"
  by (simp add: domain_modeled_cost_def)

lemma domain_integer_one_input:
  "(1::integer) = Code_Numeral.positive Num.One"
  by simp

text \<open>Normalize literal syntax before computation-specific and ordinary
preprocessing. Otherwise rational numerals can introduce integer Pos only after
the computation input-constant set has been fixed to positive.\<close>
lemma domain_nat_one_input:
  "(1::nat) = Code_Numeral.nat_of_integer (Code_Numeral.positive Num.One)"
  by simp
lemma domain_int_zero_input:
  "(0::int) = Code_Numeral.int_of_integer (0::integer)"
  by simp
lemma domain_int_one_input:
  "(1::int) = Code_Numeral.int_of_integer (Code_Numeral.positive Num.One)"
  by simp
lemma domain_int_numeral_input:
  "(numeral n::int) = Code_Numeral.int_of_integer (Code_Numeral.positive n)"
  by simp

definition domain_reply_term :: "domain_reply \<Rightarrow> Code_Evaluation.term" where
  "domain_reply_term = Code_Evaluation.term_of"

ML_file "domain_bundle.ML"
end
