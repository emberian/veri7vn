theory Veri7vn_Source_Execution
  imports "Veri7vn_Codegen.Veri7vn_Codegen"
    "Veri7vn_Source_Semantics.Source_Semantics"
begin

text \<open>Family-specific finite executable signature. Native payloads and source
meanings remain open; this is not the platform's HOL value universe. Plans are
data, so new windows and compositions reuse the compiled interpreter.\<close>
datatype observation_plan = Population
  | Window clock_basis int int observation_plan
datatype value_plan = Values observation_plan

fun window_member :: "clock_basis \<Rightarrow> int \<Rightarrow> int \<Rightarrow> 'a observation \<Rightarrow> bool" where
  "window_member cb lo hi obs = (case event_clock obs of None \<Rightarrow> False
    | Some c \<Rightarrow> basis c = cb \<and> lo \<le> ticks c \<and> ticks c < hi)"
lemma window_member_refinement:
  "window_member cb lo hi obs = event_in_window cb lo hi obs"
  by (auto simp: event_in_window_def split: option.splits)
lemma window_member_function:
  "window_member cb lo hi = event_in_window cb lo hi"
  by (rule ext) (rule window_member_refinement)

fun select_observations :: "observation_plan \<Rightarrow> 'a observation list \<Rightarrow> 'a observation list" where
  "select_observations Population xs = xs"
| "select_observations (Window cb lo hi p) xs =
    filter (window_member cb lo hi) (select_observations p xs)"
fun observation_meaning :: "observation_plan \<Rightarrow> 'a observation list \<Rightarrow> 'a observation list" where
  "observation_meaning Population xs = xs"
| "observation_meaning (Window cb lo hi p) xs =
    window_population cb lo hi (observation_meaning p xs)"
lemma observation_plan_refinement:
  "select_observations p xs = observation_meaning p xs"
  by (induction p) (simp_all add: window_population_def window_member_function)

fun extract_values :: "value_plan \<Rightarrow> 'a observation list \<Rightarrow> 'a list" where
  "extract_values (Values p) xs = List.map_filter
    (\<lambda>obs. case payload obs of Valid x \<Rightarrow> Some x | _ \<Rightarrow> None)
    (select_observations p xs)"
fun value_meaning :: "value_plan \<Rightarrow> 'a observation list \<Rightarrow> 'a list" where
  "value_meaning (Values p) xs = valid_values (observation_meaning p xs)"
lemma value_plan_refinement:
  "extract_values p xs = value_meaning p xs"
  by (cases p) (simp add: valid_values_def observation_plan_refinement)

definition observed_count :: "value_plan \<Rightarrow> 'a observation list \<Rightarrow> nat" where
  "observed_count p xs = length (extract_values p xs)"
lemma observed_count_refinement:
  "observed_count p xs = length (value_meaning p xs)"
  by (simp add: observed_count_def value_plan_refinement)

text \<open>A typed adapter for the finite compiled family. Its output scope is the
exact observation list and selected plan, retaining multiplicity. No complete
world population, distinct-entity count or adopted source truth is implied.\<close>
datatype source_carrier = Observation_Carrier | Value_Carrier | Natural_Carrier
datatype 'a source_value = Observation_Batch "'a observation list"
  | Value_Batch "'a list" | Natural_Count nat
datatype source_operation = Select observation_plan | Extract value_plan | Count value_plan
fun source_type_of :: "'a source_value \<Rightarrow> source_carrier" where
  "source_type_of (Observation_Batch _) = Observation_Carrier"
| "source_type_of (Value_Batch _) = Value_Carrier"
| "source_type_of (Natural_Count _) = Natural_Carrier"
fun source_arg_types :: "source_operation \<Rightarrow> source_carrier list" where
  "source_arg_types _ = [Observation_Carrier]"
fun source_result_type :: "source_operation \<Rightarrow> source_carrier" where
  "source_result_type (Select _) = Observation_Carrier"
| "source_result_type (Extract _) = Value_Carrier"
| "source_result_type (Count _) = Natural_Carrier"
fun source_dispatch :: "source_operation \<Rightarrow> 'a source_value list \<Rightarrow> 'a source_value option" where
  "source_dispatch (Select p) [Observation_Batch xs] = Some (Observation_Batch (select_observations p xs))"
| "source_dispatch (Extract p) [Observation_Batch xs] = Some (Value_Batch (extract_values p xs))"
| "source_dispatch (Count p) [Observation_Batch xs] = Some (Natural_Count (observed_count p xs))"
| "source_dispatch _ _ = None"
fun source_meaning :: "source_operation \<Rightarrow> 'a source_value list \<Rightarrow> 'a source_value option" where
  "source_meaning (Select p) [Observation_Batch xs] = Some (Observation_Batch (observation_meaning p xs))"
| "source_meaning (Extract p) [Observation_Batch xs] = Some (Value_Batch (value_meaning p xs))"
| "source_meaning (Count p) [Observation_Batch xs] = Some (Natural_Count (length (value_meaning p xs)))"
| "source_meaning _ _ = None"
lemma source_dispatch_refinement:
  "source_dispatch op xs = source_meaning op xs"
  by (induction op xs rule: source_dispatch.induct)
    (simp_all add: observation_plan_refinement value_plan_refinement observed_count_refinement)
lemma source_dispatch_type:
  "source_dispatch op xs = Some y \<Longrightarrow> source_type_of y = source_result_type op"
  by (induction op xs rule: source_dispatch.induct) auto
lemma source_wrong_types:
  "map source_type_of xs \<noteq> source_arg_types op \<Longrightarrow> source_dispatch op xs = None"
  by (induction op xs rule: source_dispatch.induct) auto

fun source_value_extent :: "'a source_value \<Rightarrow> nat" where
  "source_value_extent (Observation_Batch xs) = length xs"
| "source_value_extent (Value_Batch xs) = length xs"
| "source_value_extent (Natural_Count _) = 1"

definition source_materialization_guard :: "nat \<Rightarrow> source_operation \<Rightarrow> 'a source_value list \<Rightarrow> bool" where
  "source_materialization_guard limit op xs \<longleftrightarrow>
    0 < limit \<and> map source_type_of xs = source_arg_types op \<and>
    list_all (\<lambda>x. source_value_extent x \<le> limit) xs"
lemma source_guard_input_types:
  "source_materialization_guard limit op xs \<Longrightarrow>
    map source_type_of xs = source_arg_types op"
  by (simp add: source_materialization_guard_def)

end
