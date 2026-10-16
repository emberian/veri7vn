theory Authority_Metadata
  imports Veri7vn_Effects.Veri7vn_Effects
begin

ML \<open>
structure Veri7vn_Authority_Compile =
struct
  val progress = Path.append (Resources.master_directory @{theory})
    (Path.explode "../../../../var/authority-compile-phases.log")
  val _ = File.write progress ""
  fun phase label =
    let val line = "VERI7VN_AUTHORITY phase=" ^ label ^ " time=" ^ Time.toString (Time.now ())
    in File.append progress (line ^ "\n"); writeln line end
  fun reset label = (File.write progress ""; phase label)
end
val _ = Veri7vn_Authority_Compile.phase "metadata_started"
\<close>

text \<open>Executable authority metadata, not an embedding of native HOL values or truth.
Opaque identifiers acquire native meaning only through the separately stated bridge.\<close>

datatype claim_kind = Mathematical | SourceObservation | EngineObservation |
  ModelPrediction | TestObservation | Optimization
datatype modality = Asserted | Conditional | Quoted | Hypothetical | Fictional
datatype collection_scope = Scalar | Prefix nat | Complete
datatype optimality = Unspecified | Feasible | Optimal | Impossible
datatype assurance_route = KernelConsequence | RefinedExecution | EvaluationOracle

datatype execution_dependency = NoExecution | ExecutableGeneration nat

record claim =
  claim_id :: nat
  target_id :: nat
  interpretation_id :: nat
  claim_kind :: claim_kind
  claim_modality :: modality
  collection_scope :: collection_scope
  claim_optimality :: optimality
  "premises" :: "nat list"
  dependencies :: "nat list"
  semantic_generation :: nat
  executable_generation :: execution_dependency

text \<open>Exact semantic equality is deliberately conservative: no scope-strengthening conversion,
no removal of premises, no inference from feasibility to optimality. Occurrence and
execution-dependency metadata are compared separately. Native conversion
and migration can later establish separately admitted exact targets.\<close>
definition same_target :: "claim \<Rightarrow> claim \<Rightarrow> bool" where
  "same_target a b \<longleftrightarrow> a\<lparr>claim_id := 0, executable_generation := NoExecution\<rparr> =
    b\<lparr>claim_id := 0, executable_generation := NoExecution\<rparr>"

datatype slot_input = KnownInput nat | ReservedOutput nat

record artifact_requirement =
  artifact_template :: nat
  artifact_source :: nat
  artifact_revision :: nat
  artifact_manifest :: nat
  artifact_parents :: "slot_input list"
  artifact_profile :: nat
  artifact_setup :: nat
  artifact_exports :: nat

datatype goal_requirement = ClaimRequirement claim | ArtifactRequirement artifact_requirement
datatype goal_dependency = LogicalDependency nat | ArtifactDependency nat

datatype outcome = Accepted claim nat | ArtifactReady nat | AwaitingOutput nat | NeedsInput "nat list" | Declined nat |
  Inconclusive nat | Failed nat | Cancelled

datatype blocker_scope = RequestScope nat | InterpretationScope nat |
  PremiseScope nat | CapabilityScope nat
record blocker =
  blocked_scope :: blocker_scope
  reason_id :: nat
  discharge_conditions :: "nat list"
record "subgoal" =
  goal_id :: nat
  goal_interpretation :: nat
  goal_capability :: nat
  goal_dependencies :: "goal_dependency list"
  goal_required :: goal_requirement
  goal_generation :: nat
  goal_code_generation :: nat
  goal_output_slot :: "nat option"
  goal_outcome :: outcome
record request =
  request_id :: nat
  request_generation :: nat
  request_code_generation :: nat
  request_prestate :: nat
  request_dependencies :: "nat list"
  allowed_routes :: "assurance_route list"
  permitted_effects :: "nat list"
  request_goals :: "subgoal list"
  request_blockers :: "blocker list"
  request_cancelled :: bool
  request_fuel :: nat
  request_session :: "nat option"
  request_observation :: observation_requirement
  request_retention_scopes :: "retention_scope list"

ML \<open>Veri7vn_Authority_Compile.phase "request_types_ready"\<close>

record evidence =
  evidence_id :: nat
  evidence_claim :: claim
  evidence_route :: assurance_route
  evidence_managed_dependencies :: "nat list"

record binding =
  binding_request :: nat
  binding_goal :: nat
  binding_claim :: claim
  binding_evidence :: nat

record source_publication =
  source_binding_id :: nat
  snapshot_id :: nat
  observation_attempt :: nat
  observation_job :: "(nat \<times> nat) option"
  observed_binding :: binding

record effect_intent =
  attempt_id :: nat
  attempt_request :: nat
  attempt_target :: nat
  attempt_capability :: nat
  attempt_sources :: "nat list"
  attempt_dependencies :: "nat list"
  attempt_prestate :: nat
  attempt_cost :: operation_cost
  attempt_job :: "(nat \<times> nat) option"

datatype attempt_status = Prepared | Running | Confirmed | EffectFailed | Unknown
record attempt =
  attempt_intent :: effect_intent
  attempt_state :: attempt_status


record effect_observation =
  effect_observation_attempt :: nat
  effect_observation_source :: nat
  effect_observation_status :: attempt_status

datatype output_origin = PureOrigin | ExternalOrigin nat "nat option" | QualificationOrigin nat
record output_slot =
  output_slot_id :: nat
  output_owner :: nat
  output_goal :: nat
  output_template :: nat
  output_profile :: nat
  output_inputs :: "slot_input list"
  output_input_identity :: nat
  output_reserved_dependencies :: "nat list"
  output_origin :: output_origin
record output_assignment =
  assigned_slot :: nat
  assigned_requirement :: claim
  assigned_premise_correspondence :: "(nat \<times> nat) list"
  assigned_output :: nat
  assigned_lineage :: nat
  assigned_binding :: binding
  assigned_dependencies :: "nat list"
  assigned_retained :: "retained_value list"

record artifact_assignment =
  artifact_assigned_slot :: nat
  artifact_assigned_request :: nat
  artifact_assigned_goal :: nat
  artifact_assigned_requirement :: artifact_requirement
  artifact_assigned_output :: nat
  artifact_assigned_generation :: nat
  artifact_assigned_lineage :: nat
  artifact_assigned_dependencies :: "nat list"
  artifact_assigned_retained :: "retained_value list"

datatype slot_assignment = ClaimOutput output_assignment | ArtifactOutput artifact_assignment

record pure_execution =
  execution_id :: nat
  execution_request :: nat
  execution_slot :: nat
  execution_cost :: operation_cost
  execution_inputs :: "nat list"

ML \<open>Veri7vn_Authority_Compile.phase "slot_types_ready"\<close>

datatype qualification_mode = Development | Regression | FreshHoldout
datatype metric_value = ExactMetricValue int nat | UncertainMetric nat
datatype metric_comparison = AtMost int nat | AtLeast int nat | Exactly int nat
record measured_metric =
  metric_id :: nat
  metric_unit :: nat
  metric_value :: metric_value
  metric_observation :: nat
record metric_requirement =
  required_metric :: nat
  required_unit :: nat
  required_comparison :: metric_comparison
record qualification_policy_spec =
  policy_spec_id :: nat
  policy_required_mode :: qualification_mode
  policy_requires_baseline :: bool
  policy_metric_bound :: nat
  policy_requirements :: "metric_requirement list"
  policy_resource_association :: nat

datatype eligibility = UnknownEligibility | Eligible | ReservedEligibility nat | ConsumedEligibility nat
record exposure_state =
  exposure_id :: nat
  exposure_parent :: "nat option"
  exposure_members :: "nat list"
record qualification_record =
  qualification_id :: nat
  candidate_artifact :: nat
  baseline_artifact :: "nat option"
  qualification_pins :: "nat list"
  qualification_mode :: qualification_mode
  qualification_attempt :: nat
  qualification_run_spec :: nat
  qualification_domain :: nat
  qualification_policy_ref :: nat
  qualification_metrics :: "measured_metric list"
  exposure_before :: nat
  exposure_after :: nat
  spent_observation :: nat
  measured_binding :: "binding option"
  qualification_failure :: "nat option"
record eligibility_record =
  eligibility_id :: nat
  eligibility_domain :: nat
  eligibility_policy :: nat
  eligibility_exposure :: nat
  eligibility_state :: eligibility
record qualification_reservation =
  reservation_attempt :: nat
  reservation_owner :: nat
  reservation_goal :: nat
  reservation_candidate :: nat
  reservation_baseline :: "nat option"
  reservation_run_spec :: nat
  reservation_domain :: nat
  reservation_policy :: nat
  reservation_exposure :: nat
  reservation_eligibility :: "nat option"
  reservation_mode :: qualification_mode
  reservation_dependencies :: "nat list"
  reservation_cost :: operation_cost
record retention_grant =
  retention_grant_id :: nat
  retention_grant_owner :: nat
  retention_grant_value :: nat
  retention_grant_destination :: retention_scope
  retention_policy_association :: nat
  retention_grant_provenance :: "nat list"
  retention_grant_observation :: observation_requirement
ML \<open>Veri7vn_Authority_Compile.phase "qualification_types_ready"\<close>

datatype package_kind = DataPackage | SupportPackage | TheoryPackage | SpecialistPackage
record package_export =
  declared_export :: nat
  declared_requirement :: claim
  declared_profile :: "nat option"
record package_publication =
  publication_slot :: nat
  publication_candidate :: nat
  publication_policy :: nat
  publication_previous :: "nat option"
  publication_qualification :: nat
  publication_kind :: package_kind
  publication_exports :: "package_export list"
  publication_native_bindings :: "(nat \<times> binding) list"

datatype delta = Publish binding | RecordIntent effect_intent |
  RecordObservation source_publication |
  RecordEffectObservation effect_observation |
  RecordOutput slot_assignment "source_publication option" |
  AdoptSession nat "binding adopted_delta" |
  ChangeRetention nat nat retention_scope |
  ConsumeExposure qualification_reservation |
  RecordQualification qualification_record |
  PublishPackage package_publication |
  Migrate nat nat nat "binding list"
record batch =
  batch_id :: nat
  expected_revision :: nat
  batch_epoch :: nat
  batch_delta :: delta

ML \<open>Veri7vn_Authority_Compile.phase "delta_types_ready"\<close>

record authority_state =
  revision :: nat
  authority_epoch :: nat
  requests :: "request list"
  evidence_table :: "evidence list"
  visible_bindings :: "binding list"
  attempts :: "attempt list"
  effect_observations :: "effect_observation list"
  source_publications :: "source_publication list"
  pending_batch :: "batch option"
  issued_batches :: "nat list"
  retired_capabilities :: "nat list"
  retired_sources :: "nat list"
  revoked_objects :: "nat list"
  forgotten_objects :: "nat list"
  session_generation :: nat
  current_observations :: "observation_context list"
  session_views :: "binding session_view list"
  output_slots :: "output_slot list"
  output_assignments :: "slot_assignment list"
  pure_executions :: "pure_execution list"
  acquisition_jobs :: "acquisition_job list"
  retained_values :: "retained_value list"
  retention_grants :: "retention_grant list"
  consumed_retention_grants :: "nat list"
  exposure_history :: "exposure_state list"
  qualification_eligibility :: "eligibility_record list"
  spent_domains :: "nat list"
  qualification_reservations :: "qualification_reservation list"
  qualification_started :: "nat list"
  qualification_policies :: "qualification_policy_spec list"
  qualifications :: "qualification_record list"
  package_publications :: "package_publication list"

ML \<open>Veri7vn_Authority_Compile.phase "metadata_records_ready"\<close>

end
