theory Stateful_Observations
  imports Veri7vn_Source_Semantics.Source_Semantics
begin

record sensor_value =
  quantity_key :: string
  unit_key :: string
  exact_value :: int

type_synonym sensor_event = "sensor_value observation"
record acquisition_state =
  acquisition_epoch :: nat
  acquisition_live :: bool
  acquisition_events :: "sensor_event list"
  acquisition_limit :: nat

datatype ingestion = Stored | Duplicate | Identity_Conflict | Retired | Capacity

definition same_event where
  "same_event x y \<longleftrightarrow> source_id x = source_id y \<and>
    configuration x = configuration y \<and> sequence_id x = sequence_id y"
definition same_event_content where
  "same_event_content original incoming \<longleftrightarrow>
    repoll (receipt_clock original) incoming = original"
text \<open>A sequence identity belongs to the source/configuration, not to polling.
Conflicting reuse is rejected; duplicates never replace original receipt or payload.
Late, rejected and missing events remain in the bounded population.\<close>
definition ingest where
  "ingest epoch event state =
    (if \<not> acquisition_live state \<or> epoch \<noteq> acquisition_epoch state then (Retired,state)
     else if \<exists>x\<in>set (acquisition_events state). same_event x event then
       (if \<exists>x\<in>set (acquisition_events state). same_event x event \<and> same_event_content x event
        then Duplicate else Identity_Conflict,state)
     else if length (acquisition_events state) \<ge> acquisition_limit state then (Capacity,state)
     else (Stored,state\<lparr>acquisition_events := acquisition_events state @ [event]\<rparr>))"
definition retire where
  "retire state = state\<lparr>acquisition_epoch := Suc (acquisition_epoch state),
    acquisition_live := False, acquisition_events := []\<rparr>"
lemma retired_ingest:
  "ingest epoch event (retire state) = (Retired,retire state)"
  by (simp add: ingest_def retire_def)
lemma old_worker_rejected:
  "epoch \<noteq> acquisition_epoch state \<Longrightarrow> ingest epoch event state = (Retired,state)"
  by (simp add: ingest_def)
lemma stored_preserves_event:
  "ingest epoch event state = (Stored,next) \<Longrightarrow>
    acquisition_events next = acquisition_events state @ [event]"
  by (auto simp: ingest_def split: if_splits)
lemma ingestion_bounded:
  "length (acquisition_events state) \<le> acquisition_limit state \<Longrightarrow>
   ingest epoch event state = (status,next) \<Longrightarrow>
   length (acquisition_events next) \<le> acquisition_limit next"
  by (auto simp: ingest_def split: if_splits)

definition fresh_event where
  "fresh_event now max_age event \<longleftrightarrow> (\<exists>clock.
    event_clock event = Some clock \<and> basis clock = basis now \<and>
    ticks clock \<le> ticks now \<and> ticks now - ticks clock \<le> max_age)"
lemma repoll_no_freshening:
  "fresh_event now age (repoll receipt event) = fresh_event now age event"
  by (simp add: fresh_event_def repoll_def)

definition sensor_partition where
  "sensor_partition source config schema sample_origin quantity unit event \<longleftrightarrow>
    source_id event = source \<and> configuration event = config \<and>
    schema_version event = schema \<and> origin event = sample_origin \<and>
    (case payload event of Valid v \<Rightarrow> quantity_key v = quantity \<and> unit_key v = unit
      | _ \<Rightarrow> False)"
text \<open>Aggregates report an exact sum/count, never an implicitly rounded mean.
The population is the retained, selected event-time window, not all world samples.
Invalid/missing events remain inspectable separately, but contribute no numeric value.\<close>
definition sample_summary where
  "sample_summary select cb lo hi events = (let population =
      filter select (window_population cb lo hi events);
      values = map exact_value (valid_values population)
    in (sum_list values,length values))"
lemma summary_partition:
  "sample_summary (sensor_partition s c sc orig q u) cb lo hi events =
    sample_summary (sensor_partition s c sc orig q u) cb lo hi
      (filter (sensor_partition s c sc orig q u) events)"
  by (simp add: sample_summary_def window_population_def filter_filter conj_commute)

definition event_eligible where
  "event_eligible now event \<longleftrightarrow> (\<exists>clock. event_clock event = Some clock \<and>
    basis clock = basis now \<and> ticks clock \<le> ticks now)"
fun latest_observed :: "clock_reading \<Rightarrow> sensor_event list \<Rightarrow> sensor_event option" where
  "latest_observed now [] = None"
| "latest_observed now (event # rest) = (case latest_observed now rest of
    None \<Rightarrow> if event_eligible now event then Some event else None
  | Some previous \<Rightarrow> if event_eligible now event \<and>
      ticks (the (event_clock previous)) \<le> ticks (the (event_clock event))
      then Some event else Some previous)"
lemma latest_observed_member:
  "latest_observed now events = Some event \<Longrightarrow> event \<in> set events"
  by (induction events) (auto split: option.splits if_splits)
lemma latest_observed_eligible:
  "latest_observed now events = Some event \<Longrightarrow> event_eligible now event"
  by (induction events) (auto split: option.splits if_splits)
definition valid_sensor_event where
  "valid_sensor_event event \<longleftrightarrow> (case payload event of Valid value \<Rightarrow> True | _ \<Rightarrow> False)"
record sensor_report =
  newest_observation :: "sensor_event option"
  last_valid_observation :: "sensor_event option"
  unclassified_observations :: "sensor_event list"
definition observe_sensor where
  "observe_sensor now events = \<lparr>newest_observation = latest_observed now events,
    last_valid_observation = latest_observed now (filter valid_sensor_event events),
    unclassified_observations = filter (\<lambda>event. \<not> event_eligible now event) events\<rparr>"
text \<open>The newest rejected/missing observation and the older last-valid sample
remain distinct. The last-valid sample's freshness must still be checked; unknown
or future clocks stay in diagnostics, rather than winning by arrival order.\<close>
lemma reported_last_valid_is_valid:
  "last_valid_observation (observe_sensor now events) = Some event \<Longrightarrow>
    valid_sensor_event event \<and> event \<in> set events"
  by (auto simp: observe_sensor_def dest: latest_observed_member)

record sensor_session =
  session_key :: string
  session_revision :: nat
  session_reference :: "(string \<times> string \<times> string) option"
text \<open>Bindings are typed source/configuration/quantity references. Resolving them
requires the currently accessible population supplied by the managed owner. It never
restores access from a cached historical answer or executes a transcript turn.\<close>
definition follow_up where
  "follow_up expected_session expected_revision currently_accessible session =
    (if session_key session = expected_session \<and> session_revision session = expected_revision
      then (case session_reference session of None \<Rightarrow> None | Some reference \<Rightarrow>
        if reference \<in> set currently_accessible then Some reference else None)
      else None)"
lemma forgotten_follow_up:
  "follow_up sid revision [] session = None"
  by (simp add: follow_up_def split: option.splits)
lemma isolated_follow_up:
  "session_key session \<noteq> sid \<Longrightarrow> follow_up sid revision access session = None"
  by (simp add: follow_up_def)
lemma follow_up_current_access:
  "follow_up sid revision access session = Some reference \<Longrightarrow> reference \<in> set access"
  by (auto simp: follow_up_def split: option.splits if_splits)
text \<open>The session consumer composes the acquisition state, current lifecycle,
expected session version and typed referent. A retired reader yields no population,
even if the caller retained the old session object. The managed runtime must supply
its current state here; this pure result carries no publication authority.\<close>
record session_sensor_view =
  session_samples :: "sensor_event list"
  session_unclassified :: "sensor_event list"
definition session_population where
  "session_population sid revision access session state =
    (if acquisition_live state then
      (case follow_up sid revision access session of None \<Rightarrow> None
       | Some (source,config,quantity) \<Rightarrow> (let scoped =
          filter (\<lambda>event. source_id event = source \<and> configuration event = config)
            (acquisition_events state) in Some
          \<lparr>session_samples = filter (\<lambda>event. case payload event of
             Valid v \<Rightarrow> quantity_key v = quantity | _ \<Rightarrow> False) scoped,
            session_unclassified = filter (\<lambda>event. \<not> valid_sensor_event event) scoped\<rparr>))
      else None)"
definition session_observation where
  "session_observation now sid revision access session state =
    (case session_population sid revision access session state of None \<Rightarrow> None
      | Some view \<Rightarrow> Some (observe_sensor now (session_samples view), session_unclassified view))"
lemma retired_session_observation:
  "session_observation now sid revision access session (retire state) = None"
  by (simp add: session_observation_def session_population_def retire_def)
lemma forgotten_session_observation:
  "session_observation now sid revision [] session state = None"
  by (simp add: session_observation_def session_population_def forgotten_follow_up)
lemma retired_session_population:
  "session_population sid revision access session (retire state) = None"
  by (simp add: session_population_def retire_def)
lemma forgotten_session_population:
  "session_population sid revision [] session state = None"
  by (simp add: session_population_def forgotten_follow_up)
end
