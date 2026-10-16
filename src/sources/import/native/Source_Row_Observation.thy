theory Source_Row_Observation
  imports Source_Row_Import
begin

type_synonym qualified_batch_observation = "source_batch source_assertion observation"
definition attach_batch :: "unit source_assertion \<Rightarrow> unit observation \<Rightarrow> source_batch \<Rightarrow> qualified_batch_observation" where
  "attach_batch assertion metadata batch =
    \<lparr>source_id = source_id metadata, sequence_id = sequence_id metadata,
      configuration = configuration metadata, schema_version = schema_version metadata,
      origin = origin metadata, event_clock = event_clock metadata,
      receipt_clock = receipt_clock metadata, payload = Valid (replace_reported_value batch assertion),
      qualifiers = qualifiers metadata, raw_reference = raw_reference metadata\<rparr>"
lemma attach_batch_metadata:
  "source_id (attach_batch a m b) = source_id m \<and>
   sequence_id (attach_batch a m b) = sequence_id m \<and>
   configuration (attach_batch a m b) = configuration m \<and>
   schema_version (attach_batch a m b) = schema_version m \<and>
   event_clock (attach_batch a m b) = event_clock m \<and>
   receipt_clock (attach_batch a m b) = receipt_clock m \<and>
   origin (attach_batch a m b) = origin m \<and>
   qualifiers (attach_batch a m b) = qualifiers m \<and>
   raw_reference (attach_batch a m b) = raw_reference m"
  by (simp add: attach_batch_def)
lemma attach_batch_qualified_payload:
  "payload (attach_batch a m b) = Valid (replace_reported_value b a)"
  by (simp add: attach_batch_def)

datatype source_version_requirement = AnyVersion | ExactKnownVersion string
fun source_version_fits where
  "source_version_fits AnyVersion observed = True"
| "source_version_fits (ExactKnownVersion expected) observed = (observed = Some expected)"

record source_acquisition_requirement =
  required_request :: nat
  required_attempt :: nat
  required_source_binding :: nat
  required_source_key :: string
  required_encoding :: string
  required_schema :: string
  required_version :: source_version_requirement
  required_origin :: sample_origin
  required_configuration :: string
  required_quality_policy :: string
  required_calibration :: "string option"
  required_recipe :: string
  required_selection :: string
  required_retention_policy :: nat
  acquisition_byte_limit :: integer
  acquisition_row_limit :: integer
record native_source_manifest =
  acquisition_request :: nat
  acquisition_attempt :: nat
  acquisition_source_binding :: nat
  source_observation_metadata :: "unit observation"
  source_assertion_metadata :: "unit source_assertion"
  source_encoding :: string
  source_version_known :: "string option"
  source_license_known :: "string option"
  source_provenance_known :: "string option"
  source_import_recipe :: string
  source_selection_policy :: string
  source_retention_policy :: nat
  source_poll_clock :: "clock_reading option"
  source_calibration_known :: "string option"
  source_quality_policy :: string

definition manifest_matches where
  "manifest_matches r m \<longleftrightarrow>
    acquisition_request m = required_request r \<and>
    acquisition_attempt m = required_attempt r \<and>
    acquisition_source_binding m = required_source_binding r \<and>
    source_id (source_observation_metadata m) = required_source_key r \<and>
    source_encoding m = required_encoding r \<and>
    schema_version (source_observation_metadata m) = required_schema r \<and>
    source_version_fits (required_version r) (source_version_known m) \<and>
    origin (source_observation_metadata m) = required_origin r \<and>
    configuration (source_observation_metadata m) = required_configuration r \<and>
    source_quality_policy m = required_quality_policy r \<and>
    source_calibration_known m = required_calibration r \<and>
    source_import_recipe m = required_recipe r \<and>
    source_selection_policy m = required_selection r \<and>
    source_retention_policy m = required_retention_policy r \<and>
    payload (source_observation_metadata m) = Missing"

definition acquire_native where
  "acquire_native r m bytes = (if manifest_matches r m then
    (case decode_wire_bounded (acquisition_byte_limit r) (acquisition_row_limit r) bytes of
      Source_Decoded batch \<Rightarrow> Some (batch, attach_batch (source_assertion_metadata m)
        (source_observation_metadata m) batch) | _ \<Rightarrow> None) else None)"
lemma acquisition_result_sound:
  "acquire_native r m bytes = Some (batch, obs) \<Longrightarrow>
   manifest_matches r m \<and> snapshot_wellformed (batch_snapshot batch) \<and>
   encode_wire batch = bytes \<and>
   obs = attach_batch (source_assertion_metadata m) (source_observation_metadata m) batch"
  by (auto simp: acquire_native_def split: if_splits source_decode_result.splits
    dest: bounded_decoder_sound)
lemma acquisition_keeps_request_attempt_source:
  "acquire_native r m bytes = Some result \<Longrightarrow>
   acquisition_request m = required_request r \<and>
   acquisition_attempt m = required_attempt r \<and>
   acquisition_source_binding m = required_source_binding r"
  by (auto simp: acquire_native_def manifest_matches_def split: if_splits source_decode_result.splits)

lemma expected_known_version_rejects_unknown:
  "required_version r = ExactKnownVersion version \<Longrightarrow>
   source_version_known m = None \<Longrightarrow> acquire_native r m bytes = None"
  by (simp add: acquire_native_def manifest_matches_def)
lemma expected_known_version_rejects_mismatch:
  "required_version r = ExactKnownVersion expected \<Longrightarrow>
   source_version_known m = Some observed \<Longrightarrow> expected \<noteq> observed \<Longrightarrow>
   acquire_native r m bytes = None"
  by (simp add: acquire_native_def manifest_matches_def)
lemma any_version_makes_no_version_assertion:
  "source_version_fits AnyVersion observed"
  by simp

lemma unknown_origin_not_promoted:
  "origin (source_observation_metadata m) = Unknown_Origin \<Longrightarrow>
   required_origin r = Measured \<Longrightarrow> acquire_native r m bytes = None"
  by (simp add: acquire_native_def manifest_matches_def)
lemma attach_unknown_origin:
  "origin m = Unknown_Origin \<Longrightarrow> origin (attach_batch a m batch) = Unknown_Origin"
  by (simp add: attach_batch_def)

lemma unknown_acquisition_retained:
  "acquire_native r m bytes = Some (batch, obs) \<Longrightarrow>
   origin (source_observation_metadata m) = Unknown_Origin \<Longrightarrow> origin obs = Unknown_Origin"
proof -
  assume decoded: "acquire_native r m bytes = Some (batch, obs)"
    and unknown: "origin (source_observation_metadata m) = Unknown_Origin"
  from acquisition_result_sound[OF decoded] have observed:
    "obs = attach_batch (source_assertion_metadata m) (source_observation_metadata m) batch"
    by blast
  show ?thesis using unknown by (simp add: observed attach_batch_def)
qed

fun row_segments :: "qualified_batch_observation list \<Rightarrow> (qualified_batch_observation \<times> source_batch) list" where
  "row_segments [] = []"
| "row_segments (obs # rest) = (case payload obs of Valid assertion \<Rightarrow>
    (obs, reported_value assertion) # row_segments rest | _ \<Rightarrow> row_segments rest)"
definition row_population where
  "row_population observations = concat (map (batch_rows \<circ> snd) (row_segments observations))"
lemma row_segments_retain_context:
  "(obs, batch) \<in> set (row_segments observations) \<Longrightarrow> obs \<in> set observations \<and>
    (\<exists>assertion. payload obs = Valid assertion \<and> reported_value assertion = batch)"
  by (induction observations) (auto split: reading.splits)

record source_row_view =
  view_population :: "qualified_batch_observation list"
  view_original_population :: "qualified_batch_observation list"
  view_unclassified_population :: "qualified_batch_observation list"
  view_window_diagnostics :: "source_batch source_assertion window_diagnostic list"
  view_rows :: "source_row list"
  view_columns :: nat
  view_schema :: string
  view_materialized :: bool

definition row_view where
  "row_view schema columns observations =
    (if list_all (\<lambda>obs. schema_version obs = schema) observations \<and>
      list_all (\<lambda>segment. row_columns (batch_snapshot (snd segment)) = columns \<and>
        snapshot_data_valid (batch_snapshot (snd segment))) (row_segments observations)
    then Some \<lparr>view_population = observations, view_original_population = observations,
      view_unclassified_population = [], view_window_diagnostics = [], view_rows = row_population observations,
      view_columns = columns, view_schema = schema,
      view_materialized = list_all (\<lambda>obs. case payload obs of Valid assertion \<Rightarrow>
        complete_materialization (batch_snapshot (reported_value assertion)) | _ \<Rightarrow> False) observations\<rparr>
    else None)"
lemma row_view_retains_population:
  "row_view schema columns observations = Some view \<Longrightarrow>
   view_population view = observations \<and> view_rows view = row_population observations"
  by (auto simp: row_view_def split: if_splits)
lemma missing_population_not_materialized:
  "row_view schema columns observations = Some view \<Longrightarrow>
   obs \<in> set observations \<Longrightarrow> payload obs = Missing \<Longrightarrow> \<not> view_materialized view"
  by (auto simp: row_view_def list_all_iff split: if_splits reading.splits)

text \<open>These functions bind native data and preserve context. The acquisition
result is still a proposal until the native admission gate associates the exact
confirmed host attempt/input with this immutable requirement.\<close>
end
