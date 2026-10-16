theory Stateful_Observation_Tests
  imports Veri7vn_Stateful_Observations.Stateful_Observations
begin
ML \<open>
  val _ = List.app (fn name => ignore (Proof_Context.get_thm @{context} name))
    ["retired_ingest", "old_worker_rejected", "ingestion_bounded",
     "repoll_no_freshening", "follow_up_current_access"];
\<close>
lemma stale_old_event:
  "\<not> fresh_event \<lparr>basis = Source_Event ''sensor'', ticks = 100\<rparr> 10
    (\<lparr>source_id = ''s'', sequence_id = 1, configuration = ''c'', schema_version = ''v1'',
      origin = Measured, event_clock = Some \<lparr>basis = Source_Event ''sensor'', ticks = 1\<rparr>,
      receipt_clock = \<lparr>basis = Source_Event ''sensor'', ticks = 100\<rparr>,
      payload = Valid \<lparr>quantity_key = ''temperature'', unit_key = ''C'', exact_value = 20\<rparr>,
      qualifiers = [], raw_reference = None\<rparr>)"
  by (simp add: fresh_event_def)
definition measured_event :: sensor_event where
  "measured_event = \<lparr>source_id = ''sensor'', sequence_id = 1,
    configuration = ''C-measured-v1'', schema_version = ''temperature/1'', origin = Measured,
    event_clock = Some \<lparr>basis = Source_Event ''sensor'', ticks = 10\<rparr>,
    receipt_clock = \<lparr>basis = Source_Event ''sensor'', ticks = 12\<rparr>,
    payload = Valid \<lparr>quantity_key = ''temperature'', unit_key = ''C'', exact_value = 20\<rparr>,
    qualifiers = [], raw_reference = Some ''fixture:1''\<rparr>"
definition initial_acquisition :: acquisition_state where
  "initial_acquisition = \<lparr>acquisition_epoch = 1, acquisition_live = True,
    acquisition_events = [measured_event], acquisition_limit = 8\<rparr>"
lemma exact_duplicate_no_refresh:
  "ingest 1 measured_event initial_acquisition = (Duplicate,initial_acquisition)"
  by (simp add: ingest_def initial_acquisition_def same_event_def same_event_content_def repoll_def measured_event_def)
lemma changed_receipt_duplicate_keeps_original:
  "ingest 1 (repoll \<lparr>basis = Source_Event ''sensor'', ticks = 100\<rparr> measured_event)
    initial_acquisition = (Duplicate,initial_acquisition)"
  by (simp add: ingest_def initial_acquisition_def same_event_def same_event_content_def repoll_def measured_event_def)
lemma changed_payload_conflicts:
  "ingest 1 (measured_event\<lparr>payload := Rejected ''bad''\<rparr>) initial_acquisition =
    (Identity_Conflict,initial_acquisition)"
  by (simp add: ingest_def initial_acquisition_def same_event_def same_event_content_def
    repoll_def measured_event_def)
lemma late_invalid_retained:
  "fst (ingest 1 (measured_event\<lparr>sequence_id := 2,
    event_clock := Some \<lparr>basis = Source_Event ''sensor'', ticks = 5\<rparr>,
    payload := Rejected ''invalid''\<rparr>) initial_acquisition) = Stored"
  by (simp add: ingest_def initial_acquisition_def same_event_def measured_event_def)
lemma units_and_origin_partition:
  "sample_summary (sensor_partition ''sensor'' ''C-measured-v1'' ''temperature/1''
    Measured ''temperature'' ''C'') (Source_Event ''sensor'') 0 100
    [measured_event, measured_event\<lparr>origin := Simulated\<rparr>,
      measured_event\<lparr>payload := Valid \<lparr>quantity_key = ''temperature'',
        unit_key = ''F'', exact_value = 68\<rparr>\<rparr>] = (20,1)"
  by (simp add: sample_summary_def sensor_partition_def window_population_def
    event_in_window_def valid_values_def measured_event_def)
lemma rejected_latest_does_not_refresh_last_valid:
  "observe_sensor \<lparr>basis = Source_Event ''sensor'', ticks = 100\<rparr>
    [measured_event, measured_event\<lparr>sequence_id := 2,
      event_clock := Some \<lparr>basis = Source_Event ''sensor'', ticks = 99\<rparr>,
      payload := Rejected ''invalid''\<rparr>] =
    \<lparr>newest_observation = Some (measured_event\<lparr>sequence_id := 2,
      event_clock := Some \<lparr>basis = Source_Event ''sensor'', ticks = 99\<rparr>,
      payload := Rejected ''invalid''\<rparr>), last_valid_observation = Some measured_event,
      unclassified_observations = []\<rparr>"
  by (simp add: observe_sensor_def event_eligible_def valid_sensor_event_def measured_event_def)
definition remembered_session :: sensor_session where
  "remembered_session = \<lparr>session_key = ''alice'', session_revision = 3,
    session_reference = Some (''sensor'',''C-measured-v1'',''temperature'')\<rparr>"
lemma actual_session_population:
  "session_population ''alice'' 3 [(''sensor'',''C-measured-v1'',''temperature'')]
    remembered_session initial_acquisition = Some \<lparr>session_samples = [measured_event], session_unclassified = []\<rparr>"
  by (simp add: session_population_def follow_up_def remembered_session_def
    initial_acquisition_def measured_event_def valid_sensor_event_def)
lemma invalid_multi_quantity_is_unclassified:
  "session_population ''alice'' 3 [(''sensor'',''C-measured-v1'',''temperature'')]
    remembered_session (initial_acquisition\<lparr>acquisition_events :=
      [measured_event, measured_event\<lparr>sequence_id := 2, payload := Rejected ''humidity failure''\<rparr>]\<rparr>) =
    Some \<lparr>session_samples = [measured_event], session_unclassified =
      [measured_event\<lparr>sequence_id := 2, payload := Rejected ''humidity failure''\<rparr>]\<rparr>"
  by (simp add: session_population_def follow_up_def remembered_session_def
    initial_acquisition_def measured_event_def valid_sensor_event_def)
lemma session_consumer_reports_original_event:
  "session_observation \<lparr>basis = Source_Event ''sensor'', ticks = 100\<rparr>
    ''alice'' 3 [(''sensor'',''C-measured-v1'',''temperature'')]
    remembered_session initial_acquisition = Some
      (\<lparr>newest_observation = Some measured_event, last_valid_observation = Some measured_event,
        unclassified_observations = []\<rparr>, [])"
  by (simp add: session_observation_def actual_session_population observe_sensor_def
    event_eligible_def valid_sensor_event_def measured_event_def)
lemma other_session_unavailable:
  "session_population ''bob'' 3 [(''sensor'',''C-measured-v1'',''temperature'')]
    remembered_session initial_acquisition = None"
  by (simp add: session_population_def follow_up_def remembered_session_def initial_acquisition_def)
ML \<open>writeln "STATEFUL_OBSERVATION_TESTS_PASS"\<close>
end
