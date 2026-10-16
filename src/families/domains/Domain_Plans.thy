theory Domain_Plans
  imports Domain_Springs "Veri7vn_Plans.Veri7vn_Plans"
begin

text \<open>This sum is local to the quantity family. It is not a platform value
universe. Unit coordinates survive plan edges; points never unify with deltas.\<close>
datatype domain_carrier = LinearCarrier linear_unit | PointCarrier temperature_unit | DeltaCarrier temperature_unit
datatype domain_value = LinearValue linear_unit rat | PointValue temperature_unit rat | DeltaValue temperature_unit rat
datatype domain_operation = ConvertLinear linear_unit linear_unit
  | ConvertPoint temperature_unit temperature_unit | ConvertDelta temperature_unit temperature_unit
  | Spring spring_operation
fun domain_type where
  "domain_type (LinearValue u x) = LinearCarrier u"
| "domain_type (PointValue u x) = PointCarrier u"
| "domain_type (DeltaValue u x) = DeltaCarrier u"
fun domain_arguments where
  "domain_arguments (ConvertLinear a b) = [LinearCarrier a]"
| "domain_arguments (ConvertPoint a b) = [PointCarrier a]"
| "domain_arguments (ConvertDelta a b) = [DeltaCarrier a]"
| "domain_arguments (Spring op) = map LinearCarrier (spring_arguments op)"
fun domain_result where
  "domain_result (ConvertLinear a b) = LinearCarrier b"
| "domain_result (ConvertPoint a b) = PointCarrier b"
| "domain_result (ConvertDelta a b) = DeltaCarrier b"
| "domain_result (Spring op) = LinearCarrier (spring_result op)"
fun domain_dispatch :: "domain_operation \<Rightarrow> domain_value list \<Rightarrow> domain_value option" where
  "domain_dispatch (ConvertLinear a b) [LinearValue u x] =
    (if u=a then map_option (LinearValue b) (linear_convert a b x) else None)"
| "domain_dispatch (ConvertPoint a b) [PointValue u x] =
    (if u=a then map_option (PointValue b) (temperature_convert a b x) else None)"
| "domain_dispatch (ConvertDelta a b) [DeltaValue u x] =
    (if u=a then Some (DeltaValue b (temperature_delta_convert a b x)) else None)"
| "domain_dispatch (Spring op) [LinearValue u a,LinearValue v b] =
    (if [u,v] = spring_arguments op then map_option (LinearValue (spring_result op)) (spring_kernel op a b) else None)"
| "domain_dispatch _ _ = None"

fun domain_meaning :: "domain_operation \<Rightarrow> domain_value list \<Rightarrow> domain_value \<Rightarrow> bool" where
  "domain_meaning (ConvertLinear a b) [LinearValue u x] result =
    (u=a \<and> (\<exists>y. result=LinearValue b y \<and> linear_meaning a b x y))"
| "domain_meaning (ConvertPoint a b) [PointValue u x] result =
    (u=a \<and> (\<exists>y. result=PointValue b y \<and> 0 \<le> kelvin_point a x \<and> kelvin_point b y=kelvin_point a x))"
| "domain_meaning (ConvertDelta a b) [DeltaValue u x] result =
    (u=a \<and> (\<exists>y. result=DeltaValue b y \<and> y * temperature_scale b=x * temperature_scale a))"
| "domain_meaning (Spring op) [LinearValue u a,LinearValue v b] result =
    ([u,v]=spring_arguments op \<and> (\<exists>c. result=LinearValue (spring_result op) c \<and> spring_meaning op a b c))"
| "domain_meaning _ _ _ = False"

lemma domain_dispatch_refinement:
  "domain_dispatch op xs = Some result \<longleftrightarrow> domain_meaning op xs result"
  by (induction op xs rule: domain_dispatch.induct)
    (auto simp: linear_conversion_refinement temperature_conversion_refinement
      temperature_delta_characterization[symmetric] spring_kernel_refinement
      split: if_splits option.splits)

lemma domain_dispatch_type:
  "domain_dispatch op xs = Some y \<Longrightarrow> domain_type y = domain_result op"
  by (induction op xs rule: domain_dispatch.induct)
    (auto split: if_splits option.splits)
lemma spring_argument_carriers:
  assumes "[u,v] = spring_arguments op"
  shows "[LinearCarrier u,LinearCarrier v] = map LinearCarrier (spring_arguments op)"
  using arg_cong[OF assms, where f="map LinearCarrier"] by simp

lemma domain_dispatch_input_types:
  "domain_dispatch op xs = Some y \<Longrightarrow> map domain_type xs = domain_arguments op"
  by (induction op xs rule: domain_dispatch.induct)
    (auto intro: spring_argument_carriers split: if_splits option.splits)

text \<open>The context is the explicit adopted ideal-elastic-model premise.
Absent adoption blocks spring calculations; conversions need no such premise.
Its identifier is retained in the composed wrapper below.\<close>
fun domain_guard :: "nat option \<Rightarrow> domain_operation \<Rightarrow> domain_value list \<Rightarrow> guard_verdict" where
  "domain_guard None (Spring _) xs = GuardUnresolved 201"
| "domain_guard _ _ xs = GuardEstablished"
definition domain_primitive :: "nat option \<Rightarrow> domain_operation \<Rightarrow> domain_value list \<Rightarrow> (domain_value,unit) primitive_result" where
  "domain_primitive context op xs = (case domain_dispatch op xs of None \<Rightarrow> PrimitiveFailure 202 | Some v \<Rightarrow> Computed v)"
text \<open>Dedicated interpretation definitions install concrete executable
constants. Locale abbreviations alone do not register a generated interpreter.\<close>
global_interpretation quantity_plans: typed_plan_bundle domain_type domain_arguments domain_result domain_guard domain_primitive 203
  defines quantity_elaborate = quantity_plans.elaborate_plan
    and quantity_check_primitive = quantity_plans.check_primitive
    and quantity_execute_node = quantity_plans.execute_node
    and quantity_execute_plan = quantity_plans.execute_plan
    and quantity_run_checked = quantity_plans.run_checked .

fun retain_model where
  "retain_model context [] = []"
| "retain_model context (n#ns) =
    (case (context,node_operation n) of (Some premise,Spring op) \<Rightarrow>
      n\<lparr>retained_premises := premise # retained_premises n\<rparr> | _ \<Rightarrow> n) # retain_model context ns"
definition run_quantity_plan where
  "run_quantity_plan context fuel env ns = quantity_plans.run_checked context fuel env (retain_model context ns)"
lemma spring_model_premise_retained:
  assumes "node_operation n = Spring op"
    "quantity_plans.execute_node (Some premise) env (hd (retain_model (Some premise) [n])) = NodeValue v ps"
  shows "premise \<in> set ps"
  using assms quantity_plans.computed_node_typed[of "Some premise" env
    "n\<lparr>retained_premises := premise # retained_premises n\<rparr>" v ps]
  by simp
lemma quantity_node_semantics:
  assumes "fetch_inputs env (node_inputs n) = Some inputs"
    "quantity_plans.execute_node context env n = NodeValue v ps"
  shows "domain_dispatch (node_operation n) (map fst inputs) = Some v \<and>
    ps = merge_conditions (retained_premises n @ concat (map snd inputs))"
  using assms unfolding quantity_plans.execute_node_def domain_primitive_def Let_def
  by (auto split: if_splits guard_verdict.splits option.splits)

export_code linear_convert temperature_convert temperature_delta_convert spring_kernel
  domain_dispatch run_quantity_plan in SML module_name Veri7vn_Domains
end
