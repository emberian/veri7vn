theory Veri7vn_Row_Kernel
  imports "Veri7vn_Row_Plans.Veri7vn_Row_Slots"
    "Veri7vn_Source_Import.Source_Import_Profile"
    "Veri7vn_Source_Metadata.Source_Metadata_Codec"
    "Veri7vn_Source_Stream.Source_Row_Stream"
    "Veri7vn_Relation_Import.Relation_Source_Import"
    "Veri7vn_Codegen.Veri7vn_Codegen"
begin

type_synonym acquired_row_trace = "(nat \<times> (row_value, unit) node_result) list"

type_synonym source_relation_requirement = structured_relation_request

abbreviation associated_relation_query where
  "associated_relation_query \<equiv> run_structured_relation_query"
lemma associated_relation_incomplete_never_unique:
  "\<not> complete_materialization (batch_snapshot batch) \<Longrightarrow>
    associated_relation_query requirement batch \<noteq>
      Relation_Imported (Relation_Result s (Unique v))"
  by (cases requirement) (simp add: incomplete_batch_never_unique)

definition acquire_and_query where
  "acquire_and_query acquisition manifest bytes context query =
    (case acquire_native_versioned acquisition manifest bytes of None \<Rightarrow> None
    | Some (batch, observation) \<Rightarrow>
      Some (batch, observation, specialize_acquired_query context query [observation]))"

lemma acquire_and_query_refinement:
  "acquire_and_query acquisition manifest bytes context query =
    Some (batch, observation, trace) \<Longrightarrow>
    manifest_matches acquisition manifest \<and>
    versioned_source_represents acquisition bytes batch \<and>
    observation = attach_batch (source_assertion_metadata manifest)
      (source_observation_metadata manifest) batch \<and>
    trace = requested_acquired_meaning context query [observation]"
  by (auto simp: acquire_and_query_def acquired_query_native_specialization
    split: option.splits prod.splits dest: versioned_acquisition_result_sound)

definition acquire_and_query_versioned_relation where
  "acquire_and_query_versioned_relation acquisition manifest bytes request =
    (case acquire_native_versioned acquisition manifest bytes of None \<Rightarrow> None
    | Some (batch, observation) \<Rightarrow>
      Some (observation,run_structured_relation_query request batch))"
lemma acquired_versioned_relation_refinement:
  "acquire_and_query_versioned_relation acquisition manifest bytes request = Some (obs,result)
    \<Longrightarrow> \<exists>batch. manifest_matches acquisition manifest \<and>
      versioned_source_represents acquisition bytes batch \<and>
      obs=attach_batch (source_assertion_metadata manifest) (source_observation_metadata manifest) batch \<and>
      structured_relation_snapshot_meaning request batch result"
  by (auto simp: acquire_and_query_versioned_relation_def structured_relation_query_refinement
    split: option.splits prod.splits dest: versioned_acquisition_result_sound)

lemma row_wire_codecs_refine:
  "(snapshot_wellformed (batch_snapshot compact) \<longrightarrow>
      decode_wire (encode_wire compact)=Some compact) \<and>
    (materialize_source_stream limits eof bytes=Some framed \<longleftrightarrow>
      source_stream_represents limits eof bytes framed)"
  using wire_codec_roundtrip materialize_source_stream_refinement by blast

definition acquisition_source_key_bytes :: "source_acquisition_requirement \<Rightarrow> nat list" where
  "acquisition_source_key_bytes r = map nat_of_char (required_source_key r)"
definition query_schema_bytes :: "acquired_row_requirement \<Rightarrow> nat list" where
  "query_schema_bytes q = map nat_of_char (requested_row_schema q)"

datatype registered_row_operation = QualifiedRowOperation | QualifiedRelationSnapshotQuery
fun registered_row_dispatch where
  "registered_row_dispatch QualifiedRowOperation acquisition manifest bytes context query =
    acquire_and_query acquisition manifest bytes context query"
| "registered_row_dispatch QualifiedRelationSnapshotQuery acquisition manifest bytes context query = None"
definition row_modeled_cost :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "row_modeled_cost input_bytes materialized_rows metadata_nodes =
    Suc (input_bytes + 4 * materialized_rows + metadata_nodes)"
lemma row_modeled_cost_positive: "0 < row_modeled_cost bytes rows nodes"
  by (simp add: row_modeled_cost_def)
lemma registered_row_operation_refinement:
  "registered_row_dispatch QualifiedRowOperation acquisition manifest bytes context query =
    Some (batch, observation, trace) \<Longrightarrow>
    manifest_matches acquisition manifest \<and>
    versioned_source_represents acquisition bytes batch \<and>
    observation = attach_batch (source_assertion_metadata manifest)
      (source_observation_metadata manifest) batch \<and>
    trace = requested_acquired_meaning context query [observation]"
  by (simp only: registered_row_dispatch.simps; erule acquire_and_query_refinement)

lemma registered_row_component_association:
  "registered_row_dispatch QualifiedRowOperation acquisition manifest bytes context query =
    (case acquire_native_versioned acquisition manifest bytes of None \<Rightarrow> None
    | Some (batch, observation) \<Rightarrow>
      Some (batch, observation, specialize_acquired_query context query [observation]))"
  by (simp add: acquire_and_query_def)

datatype row_query_outcome = QueryNoTrace
  | QueryCount nat source_row_view "nat list"
  | QueryStopped "(row_value, unit) node_result option" acquired_row_trace

fun extract_final_count :: "acquired_row_trace option \<Rightarrow> row_query_outcome" where
  "extract_final_count None = QueryNoTrace"
| "extract_final_count (Some trace) =
    (case map_of trace 4 of Some (NodeValue (QualifiedCount n view) conditions)
      \<Rightarrow> QueryCount n view conditions
    | other \<Rightarrow> QueryStopped other trace)"

lemma extract_final_count_sound:
  "extract_final_count trace = QueryCount n view conditions \<Longrightarrow>
    \<exists>nodes. trace = Some nodes \<and>
      (4, NodeValue (QualifiedCount n view) conditions) \<in> set nodes"
  by (cases trace) (auto split: option.splits node_result.splits row_value.splits
    dest: map_of_SomeD)

lemma extracted_query_refinement:
  "extract_final_count (specialize_acquired_query context query observations) =
    extract_final_count (requested_acquired_meaning context query observations)"
  by (simp add: acquired_query_native_specialization)

datatype row_data_scope = SelectedSourceRows
 datatype row_world_coverage = NoWorldCoverage
 datatype row_collection_policy = OrderedBag
record row_window_summary =
  summary_window_clock :: clock_basis
  summary_window_lower :: int
  summary_window_upper :: int
  summary_window_candidates :: nat
  summary_window_missing_clock :: nat
  summary_window_wrong_basis :: nat
record row_count_summary =
  summary_count :: nat
  summary_declared_materialized :: bool
  summary_has_unclassified :: bool
  summary_missing_observations :: nat
  summary_rejected_observations :: nat
  summary_windows :: "row_window_summary list"
  summary_conditions :: "nat list"
  summary_data_scope :: row_data_scope
  summary_world_coverage :: row_world_coverage
  summary_collection_policy :: row_collection_policy
 datatype row_part_summary = PartComputed nat "nat list" | PartFailed nat nat
  | PartConflict nat "nat list" | PartBlocked nat nat | PartPending nat "nat list" | PartBudget nat
 datatype row_summary = SummaryCount row_count_summary | SummaryNoTrace | SummaryStopped "row_part_summary list"

definition summarize_window where
  "summarize_window diagnostic = \<lparr>
    summary_window_clock = diagnostic_clock diagnostic,
    summary_window_lower = diagnostic_lower diagnostic,
    summary_window_upper = diagnostic_upper diagnostic,
    summary_window_candidates = length (diagnostic_population diagnostic),
    summary_window_missing_clock = length (filter (\<lambda>obs. event_clock obs = None)
      (diagnostic_unclassified diagnostic)),
    summary_window_wrong_basis = length (filter (\<lambda>obs. case event_clock obs of None \<Rightarrow> False
      | Some clock \<Rightarrow> basis clock \<noteq> diagnostic_clock diagnostic)
      (diagnostic_unclassified diagnostic))\<rparr>"
definition summarize_count where
  "summarize_count n view conditions = \<lparr>summary_count = n,
    summary_declared_materialized = view_materialized view,
    summary_has_unclassified = (view_unclassified_population view \<noteq> []),
    summary_missing_observations = length (filter (\<lambda>obs. case payload obs of Missing \<Rightarrow> True | _ \<Rightarrow> False)
      (view_original_population view)),
    summary_rejected_observations = length (filter (\<lambda>obs. case payload obs of Rejected _ \<Rightarrow> True | _ \<Rightarrow> False)
      (view_original_population view)),
    summary_windows = map summarize_window (view_window_diagnostics view),
    summary_conditions = conditions, summary_data_scope = SelectedSourceRows,
    summary_world_coverage = NoWorldCoverage, summary_collection_policy = OrderedBag\<rparr>"
fun summarize_part where
  "summarize_part (node_key, NodeValue node_value node_conditions) = PartComputed node_key node_conditions"
| "summarize_part (node_key, NodeFailure node_reason) = PartFailed node_key node_reason"
| "summarize_part (node_key, NodeConflict node_values node_conditions) = PartConflict node_key node_conditions"
| "summarize_part (node_key, NodeBlocked node_reason) = PartBlocked node_key node_reason"
| "summarize_part (node_key, NodeSuspended node_effect node_conditions) = PartPending node_key node_conditions"
| "summarize_part (node_key, NodeBudget) = PartBudget node_key"
fun project_row_summary where
  "project_row_summary (QueryCount result_count result_view result_conditions) =
    SummaryCount (summarize_count result_count result_view result_conditions)"
| "project_row_summary QueryNoTrace = SummaryNoTrace"
| "project_row_summary (QueryStopped terminal_key node_trace) = SummaryStopped (map summarize_part node_trace)"
lemma row_summary_count_sound:
  "project_row_summary outcome = SummaryCount summary \<Longrightarrow>
    \<exists>n view conditions. outcome = QueryCount n view conditions \<and>
      summary = summarize_count n view conditions \<and>
      summary_data_scope summary = SelectedSourceRows \<and>
      summary_world_coverage summary = NoWorldCoverage \<and>
      summary_collection_policy summary = OrderedBag"
  by (cases outcome) (auto simp: summarize_count_def)
lemma row_summary_stopped_transcript:
  "project_row_summary (QueryStopped stopped_terminal stopped_trace) = SummaryStopped (map summarize_part stopped_trace)"
  by simp

definition declared_observed_count_requirement where
  "declared_observed_count_requirement acquisition query \<longleftrightarrow>
    requested_population_plan query = Population \<and>
    requested_population_policy query = ObservedKnownSelection \<and>
    requested_qualified_predicate query = AnyRow \<and>
    requested_row_schema query = required_schema acquisition"

text \<open>This pure generated unit exposes no accepted constructor. The source
admission child retains its exact native inputs and this fixed law. Imported
source_batch constructors retain the existing reflected Eval mapping; no second
row carrier or representation conversion is introduced. Generated functions here
are implementation entry points, not authority to attach an arbitrary callback.\<close>

code_reflect Veri7vn_Row_Code
  datatypes sample_origin = _ and reading = _ and clock_basis = _
    and clock_reading_ext = _ and observation_ext = _ and source_rank = _
    and source_assertion_ext = _ and source_version_requirement = _
    and source_acquisition_requirement_ext = _
    and native_source_manifest_ext = _ and source_row_view_ext = _
    and population_policy = _ and window_diagnostic_ext = _ and source_population_report_ext = _
    and observation_plan = _ and source_input_pin = _ and source_plan_context_ext = _
    and row_predicate = _ and row_operation = _ and row_carrier = _ and row_value = _
    and plan_node_ext = _ and node_result = _ and acquired_row_requirement_ext = _
    and row_query_outcome = _ and registered_row_operation = _
    and source_metadata_record_ext = _
    and row_data_scope = _ and row_world_coverage = _ and row_collection_policy = _
    and row_window_summary_ext = _ and row_count_summary_ext = _ and row_part_summary = _ and row_summary = _
    and structured_relation_request = _ and relation_object = _
    and selection = _ and relation_result = _ and relation_import_result = _
  functions acquire_native acquire_native_versioned specialize_acquired_query acquire_and_query
    manifest_matches requested_acquired_graph extract_final_count
    required_request required_attempt required_source_binding acquisition_byte_limit acquisition_row_limit materialization_limit pinned_source_snapshot
    registered_row_dispatch row_modeled_cost acquisition_source_key_bytes
    query_schema_bytes requested_population_policy requested_row_columns
    decode_source_metadata_wire construct_source_manifest metadata_private
    project_row_summary declared_observed_count_requirement
    run_structured_relation_query

ML \<open>
structure Veri7vn_Row_Kernel =
struct
  type batch = Native_Source_Import.source_batch;
  type acquisition = unit Veri7vn_Row_Code.source_acquisition_requirement_ext;
  type manifest = unit Veri7vn_Row_Code.native_source_manifest_ext;
  type context = unit Veri7vn_Row_Code.source_plan_context_ext;
  type query = unit Veri7vn_Row_Code.acquired_row_requirement_ext;
  type assertion = (batch, unit) Veri7vn_Row_Code.source_assertion_ext;
  type observation = (assertion, unit) Veri7vn_Row_Code.observation_ext;
  type value = Veri7vn_Row_Code.row_value;
  type metadata_record = unit Veri7vn_Row_Code.source_metadata_record_ext;
  val decode_source_metadata_wire = Veri7vn_Row_Code.decode_source_metadata_wire;
  val construct_source_manifest = Veri7vn_Row_Code.construct_source_manifest;
  val metadata_private = Veri7vn_Row_Code.metadata_private;
  type summary = Veri7vn_Row_Code.row_summary;
  val project_summary = Veri7vn_Row_Code.project_row_summary;
  val declared_observed_count_requirement = Veri7vn_Row_Code.declared_observed_count_requirement;
  type operation = Veri7vn_Row_Code.registered_row_operation;
  val operation = Veri7vn_Row_Code.QualifiedRowOperation;
  val dispatch = Veri7vn_Row_Code.registered_row_dispatch;
  val modeled_cost = Veri7vn_Row_Code.row_modeled_cost;
  type query_outcome = Veri7vn_Row_Code.row_query_outcome;
  val extract_final_count = Veri7vn_Row_Code.extract_final_count;
  val acquisition_source_key_bytes = Veri7vn_Row_Code.acquisition_source_key_bytes;
  val query_schema_bytes = Veri7vn_Row_Code.query_schema_bytes;
  val query_policy = Veri7vn_Row_Code.requested_population_policy;
  val query_columns = Veri7vn_Row_Code.requested_row_columns;
  val acquisition_request = Veri7vn_Row_Code.required_request;
  val acquisition_attempt = Veri7vn_Row_Code.required_attempt;
  val acquisition_source_binding = Veri7vn_Row_Code.required_source_binding;
  val acquisition_byte_limit = Veri7vn_Row_Code.acquisition_byte_limit;
  val acquisition_row_limit = Veri7vn_Row_Code.acquisition_row_limit;
  val materialization_limit = Veri7vn_Row_Code.materialization_limit;
  val context_pin = Veri7vn_Row_Code.pinned_source_snapshot;
  val nat_to_integer = Veri7vn_Numerals.integer_of_nat;
  val nat_of_integer = Veri7vn_Numerals.nat_of_integer;
  val acquire = Veri7vn_Row_Code.acquire_native_versioned;
  val query = Veri7vn_Row_Code.specialize_acquired_query;
  val acquire_and_query = Veri7vn_Row_Code.acquire_and_query;
  val matches = Veri7vn_Row_Code.manifest_matches;
  type metadata = acquisition * (query * context);
  type relation_requirement = Veri7vn_Row_Code.structured_relation_request;
  type source_operation = Veri7vn_Row_Code.registered_row_operation;
  val relation_operation = Veri7vn_Row_Code.QualifiedRelationSnapshotQuery;
  val count_operation = Veri7vn_Row_Code.QualifiedRowOperation;
  type relation_result = Veri7vn_Row_Code.relation_import_result;
  val query_relation = Veri7vn_Row_Code.run_structured_relation_query;
  val decode_relation_requirement = @{computation "source_relation_requirement"
    terms: "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
    datatypes: source_relation_requirement "nat list" nat integer num bool unit}
    (fn _ => fn value => (value: relation_requirement option));
  val decode_metadata = @{computation
    "source_acquisition_requirement * acquired_row_requirement * source_plan_context"
    terms: "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
      "0::int" "1::int" "numeral::num\<Rightarrow>int" "uminus::int\<Rightarrow>int"
      "0::integer" "numeral::num\<Rightarrow>integer"
      "uminus::integer\<Rightarrow>integer"
    datatypes: "source_acquisition_requirement * acquired_row_requirement * source_plan_context"
      "acquired_row_requirement * source_plan_context"
      source_acquisition_requirement acquired_row_requirement source_plan_context
      observation_plan population_policy source_input_pin source_version_requirement
      row_predicate source_cell clock_reading clock_basis sample_origin
      "nat list" "string option" string char num nat int integer bool unit}
    (fn _ => fn value => (value: metadata option));
  val decode_manifest = @{computation "native_source_manifest"
    terms: "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
      "0::int" "1::int" "numeral::num\<Rightarrow>int" "uminus::int\<Rightarrow>int"
    datatypes: native_source_manifest "unit observation" "unit source_assertion"
      "unit reading" source_rank clock_reading clock_basis sample_origin
      "clock_reading option" "source_rank option" "string option" "string list"
      string char num nat int integer bool unit}
    (fn _ => fn value => (value: manifest option));
  val code_theory = @{theory};
  val executable = Veri7vn_Executable_Identity.pin code_theory
    {artifact="veri7vn.qualified-row-kernel/2", compiler="Isabelle / PolyML",
     target="Eval", serializers=["native reflected source row carrier", "bounded metadata constructor decoder"],
     foreign_primitives=[], settings=["Code_Target_Numeral", "fixed acquisition and same-query graph"]};
  val acquisition_contract = @{thm versioned_acquisition_result_sound};
  val query_contract = @{thm acquired_query_native_specialization};
  val operation_contract = @{thm registered_row_operation_refinement};
  val projection_contract = @{thm row_summary_count_sound};
  val component_contract = @{thm registered_row_component_association};
  val relation_contract = @{thm structured_relation_query_refinement};
  val relation_acquisition_contract = @{thm acquired_versioned_relation_refinement};
  val relation_incomplete_contract = @{thm associated_relation_incomplete_never_unique};
  val positive_cost_contract = @{thm row_modeled_cost_positive};
  val metadata_contracts = [@{thm construction_preserves_reserved_identity},
    @{thm construction_preserves_source_context},
    @{thm construction_preserves_qualifiers_provenance_loss},
    @{thm metadata_over_budget_rejected}];
  val codec_contract = @{thm row_wire_codecs_refine};
  val final_count_contract = @{thm extract_final_count_sound};
  val extracted_query_contract = @{thm extracted_query_refinement};
  val combined_contract = @{thm acquire_and_query_refinement};
end;
\<close>
end
