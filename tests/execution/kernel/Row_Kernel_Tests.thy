theory Row_Kernel_Tests
  imports "Veri7vn_Row_Kernel.Veri7vn_Row_Kernel"
begin

definition kernel_clock :: clock_reading where
  "kernel_clock = \<lparr>basis = Wall ''UTC'', ticks = 0\<rparr>"
definition kernel_observation :: "unit observation" where
  "kernel_observation = \<lparr>source_id = ''fixture'', sequence_id = 1,
    configuration = ''cfg'', schema_version = ''one-column'', origin = Unknown_Origin,
    event_clock = None, receipt_clock = kernel_clock, payload = Missing,
    qualifiers = [''declared''], raw_reference = Some ''raw/1''\<rparr>"
definition kernel_assertion :: "unit source_assertion" where
  "kernel_assertion = \<lparr>reported_value = (), reported_rank = Some (Named_Rank ''primary''),
    reported_units = None, reported_references = [''ref/1''], reported_import_loss = [],
    reported_applicability = [''fixture-only'']\<rparr>"
definition kernel_manifest :: native_source_manifest where
  "kernel_manifest = \<lparr>acquisition_request = 1, acquisition_attempt = 2,
    acquisition_source_binding = 3, source_observation_metadata = kernel_observation,
    source_assertion_metadata = kernel_assertion, source_encoding = ''binary'',
    source_version_known = None, source_license_known = None, source_provenance_known = None,
    source_import_recipe = ''source-row-codec/1'', source_selection_policy = ''all'',
    source_retention_policy = 7, source_poll_clock = Some kernel_clock,
    source_calibration_known = None, source_quality_policy = ''declared''\<rparr>"
definition kernel_acquisition :: source_acquisition_requirement where
  "kernel_acquisition = \<lparr>required_request = 1, required_attempt = 2,
    required_source_binding = 3, required_source_key = ''fixture'', required_encoding = ''binary'',
    required_schema = ''one-column'', required_version = AnyVersion,
    required_origin = Unknown_Origin,
    required_configuration = ''cfg'', required_quality_policy = ''declared'',
    required_calibration = None, required_recipe = ''source-row-codec/1'', required_selection = ''all'',
    required_retention_policy = 7, acquisition_byte_limit = 4096, acquisition_row_limit = 256\<rparr>"
definition kernel_context :: source_plan_context where
  "kernel_context = \<lparr>plan_executable_generation = 1, installed_executable_generation = 1,
    pinned_source_snapshot = RetainedSourceSnapshot 4, pinned_session_state = 5, pinned_evaluation_clock = kernel_clock,
    pinned_source_policy = 6, pinned_dependencies = [8], materialization_limit = 256\<rparr>"
definition kernel_query :: acquired_row_requirement where
  "kernel_query = \<lparr>requested_population_policy = ObservedKnownSelection,
    requested_population_plan = Population, requested_row_schema = ''one-column'',
    requested_row_columns = 1, requested_qualified_predicate = AnyRow,
    requested_acquisition_conditions = [9]\<rparr>"
definition kernel_batch where
  "kernel_batch = Source_Batch 1 [[Cell_Null], [Cell_Text [65]]] True"
definition kernel_wire where "kernel_wire = encode_wire kernel_batch"
definition kernel_fixture where
  "kernel_fixture = (case acquire_and_query kernel_acquisition kernel_manifest kernel_wire
      kernel_context kernel_query of
    Some (batch, observation, trace) \<Rightarrow>
      batch = kernel_batch \<and> origin observation = Unknown_Origin \<and>
      (case extract_final_count trace of QueryCount n view conditions \<Rightarrow>
        n = 2 \<and> conditions = [9] \<and> length (view_population view) = 1
      | _ \<Rightarrow> False)
    | _ \<Rightarrow> False)"
definition kernel_foreign_manifest where
  "kernel_foreign_manifest = (acquire_native kernel_acquisition
    (kernel_manifest\<lparr>acquisition_attempt := 999\<rparr>) kernel_wire = None)"
definition kernel_summary_fixture where
  "kernel_summary_fixture = (case acquire_and_query kernel_acquisition kernel_manifest kernel_wire
      kernel_context kernel_query of
    Some (batch, observation, trace) \<Rightarrow>
      (case project_row_summary (extract_final_count trace) of SummaryCount summary \<Rightarrow>
        summary_count summary = 2 \<and> summary_declared_materialized summary \<and>
        \<not> summary_has_unclassified summary \<and> summary_missing_observations summary = 0 \<and>
        summary_rejected_observations summary = 0 \<and> summary_conditions summary = [9] \<and>
        summary_data_scope summary = SelectedSourceRows \<and>
        summary_world_coverage summary = NoWorldCoverage \<and>
        summary_collection_policy summary = OrderedBag
      | _ \<Rightarrow> False)
    | _ \<Rightarrow> False)"
definition kernel_blocked_summary_fixture where
  "kernel_blocked_summary_fixture = (case acquire_and_query kernel_acquisition kernel_manifest kernel_wire
      kernel_context (kernel_query\<lparr>requested_population_policy := RequireClassifiedWindow,
        requested_population_plan := Window (Wall ''UTC'') 0 10 Population\<rparr>) of
    Some (batch, observation, trace) \<Rightarrow>
      project_row_summary (extract_final_count trace) = SummaryStopped
        [PartBlocked 1 116, PartBlocked 2 114, PartBlocked 3 114, PartBlocked 4 114]
    | _ \<Rightarrow> False)"

ML \<open>
val _ = if @{code kernel_fixture} then writeln "EXECUTION native_row_carrier PASS"
  else error "Fixed reflected acquisition/query carrier failed";
val _ = if @{code kernel_foreign_manifest} then writeln "EXECUTION native_attempt_guard PASS"
  else error "Foreign attempt reached native acquisition";
val _ = if @{code kernel_summary_fixture} andalso @{code kernel_blocked_summary_fixture}
  then writeln "EXECUTION scoped_summary PASS"
  else error "Recipient summary lost count scope or upstream blockers";
\<close>
end
