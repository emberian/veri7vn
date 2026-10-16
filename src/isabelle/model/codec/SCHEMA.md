# Finite authority metadata schema 1

Exact parsed-signature fingerprint (SHA-256): fec112b2985d1d48d528047f18138c6e99fcff2e0c98b9d3ad73ea9623c0b226. WireNode 3 [WireNat fingerprint, body] seals transport frames/checkpoints. This locates a schema, never native evidence.
WireNat encodes natural fields; Boolean fields require 0 or 1.
WireNode 0 [] = None; WireNode 1 [x] = Some x; WireNode 2 xs = list.
WireNode 4 [WireNat sign, WireNat magnitude] = exact integer; sign 1 requires positive magnitude.
WireNode 5 [a,b] = pair. Characters require WireNat below 256; strings are byte-character lists.
Generic metadata containers instantiate the actual binding type; no native carrier polymorphism.
All record/constructor nodes require the exact ordered field arity.

| Type | Tag | Constructor / ordered fields |
|---|---:|---|
| clock_basis | 100 | Wall (string) |
| clock_basis | 101 | Monotonic (string) |
| clock_basis | 102 | Source_Event (string) |
| clock_reading | 1000 | basis: clock_basis, ticks: int |
| observation_context | 1001 | observed_session: nat, observed_version: nat, evaluation_time: clock_reading option, observed_reads: (nat \<times> nat) list |
| freshness_window | 1002 | fresh_from: clock_reading, fresh_through: int |
| observation_requirement | 103 | StateTimeUnused |
| observation_requirement | 104 | RequireObservation (observation_context, freshness_window option) |
| observation_requirement | 105 | RequireAccess (observation_context, freshness_window option) |
| operation_cost | 1003 | cost_profile: nat, cost_code_generation: nat, cost_operation: nat, cost_step: nat, cost_units: nat |
| fuel_account | 1004 | fuel_owner: nat, fuel_remaining: nat |
| retention_scope | 106 | RequestLocal (nat) |
| retention_scope | 107 | SessionLocal (nat) |
| retention_scope | 108 | WorkspaceShared |
| retained_value | 1005 | retained_id: nat, retained_owner: retention_scope, retained_dependencies: nat list, retained_read_dependencies: nat list, retained_access_requirements: observation_requirement list, retained_payload: nat |
| adopted_delta | 1006 | adoption_request: nat, adoption_session: nat, adoption_expected_version: nat, adoption_bindings: 'a list |
| session_view | 1007 | session_id: nat, session_version: nat, recorded_utterances: nat list, adopted_bindings: 'a list |
| job_status | 109 | JobStopped |
| job_status | 110 | JobActive |
| job_status | 111 | JobRetired |
| acquisition_job | 1008 | job_id: nat, job_owner: nat, job_source: nat, job_capability: nat, job_budget: fuel_account, job_status: job_status, job_incarnation: nat |
| claim_kind | 112 | Mathematical |
| claim_kind | 113 | SourceObservation |
| claim_kind | 114 | EngineObservation |
| claim_kind | 115 | ModelPrediction |
| claim_kind | 116 | TestObservation |
| claim_kind | 117 | Optimization |
| modality | 118 | Asserted |
| modality | 119 | Conditional |
| modality | 120 | Quoted |
| modality | 121 | Hypothetical |
| modality | 122 | Fictional |
| collection_scope | 123 | Scalar |
| collection_scope | 124 | Prefix (nat) |
| collection_scope | 125 | Complete |
| optimality | 126 | Unspecified |
| optimality | 127 | Feasible |
| optimality | 128 | Optimal |
| optimality | 129 | Impossible |
| assurance_route | 130 | KernelConsequence |
| assurance_route | 131 | RefinedExecution |
| assurance_route | 132 | EvaluationOracle |
| execution_dependency | 133 | NoExecution |
| execution_dependency | 134 | ExecutableGeneration (nat) |
| claim | 1009 | claim_id: nat, target_id: nat, interpretation_id: nat, claim_kind: claim_kind, claim_modality: modality, collection_scope: collection_scope, claim_optimality: optimality, premises: nat list, dependencies: nat list, semantic_generation: nat, executable_generation: execution_dependency |
| slot_input | 135 | KnownInput (nat) |
| slot_input | 136 | ReservedOutput (nat) |
| artifact_requirement | 1010 | artifact_template: nat, artifact_source: nat, artifact_revision: nat, artifact_manifest: nat, artifact_parents: slot_input list, artifact_profile: nat, artifact_setup: nat, artifact_exports: nat |
| goal_requirement | 137 | ClaimRequirement (claim) |
| goal_requirement | 138 | ArtifactRequirement (artifact_requirement) |
| goal_dependency | 139 | LogicalDependency (nat) |
| goal_dependency | 140 | ArtifactDependency (nat) |
| outcome | 141 | Accepted (claim, nat) |
| outcome | 142 | ArtifactReady (nat) |
| outcome | 143 | AwaitingOutput (nat) |
| outcome | 144 | NeedsInput (nat list) |
| outcome | 145 | Declined (nat) |
| outcome | 146 | Inconclusive (nat) |
| outcome | 147 | Failed (nat) |
| outcome | 148 | Cancelled |
| blocker_scope | 149 | RequestScope (nat) |
| blocker_scope | 150 | InterpretationScope (nat) |
| blocker_scope | 151 | PremiseScope (nat) |
| blocker_scope | 152 | CapabilityScope (nat) |
| blocker | 1011 | blocked_scope: blocker_scope, reason_id: nat, discharge_conditions: nat list |
| subgoal | 1012 | goal_id: nat, goal_interpretation: nat, goal_capability: nat, goal_dependencies: goal_dependency list, goal_required: goal_requirement, goal_generation: nat, goal_code_generation: nat, goal_output_slot: nat option, goal_outcome: outcome |
| request | 1013 | request_id: nat, request_generation: nat, request_code_generation: nat, request_prestate: nat, request_dependencies: nat list, allowed_routes: assurance_route list, permitted_effects: nat list, request_goals: subgoal list, request_blockers: blocker list, request_cancelled: bool, request_fuel: nat, request_session: nat option, request_observation: observation_requirement, request_retention_scopes: retention_scope list |
| evidence | 1014 | evidence_id: nat, evidence_claim: claim, evidence_route: assurance_route, evidence_managed_dependencies: nat list |
| binding | 1015 | binding_request: nat, binding_goal: nat, binding_claim: claim, binding_evidence: nat |
| source_publication | 1016 | source_binding_id: nat, snapshot_id: nat, observation_attempt: nat, observation_job: (nat \<times> nat) option, observed_binding: binding |
| effect_intent | 1017 | attempt_id: nat, attempt_request: nat, attempt_target: nat, attempt_capability: nat, attempt_sources: nat list, attempt_dependencies: nat list, attempt_prestate: nat, attempt_cost: operation_cost, attempt_job: (nat \<times> nat) option |
| attempt_status | 153 | Prepared |
| attempt_status | 154 | Running |
| attempt_status | 155 | Confirmed |
| attempt_status | 156 | EffectFailed |
| attempt_status | 157 | Unknown |
| attempt | 1018 | attempt_intent: effect_intent, attempt_state: attempt_status |
| effect_observation | 1019 | effect_observation_attempt: nat, effect_observation_source: nat, effect_observation_status: attempt_status |
| output_origin | 158 | PureOrigin |
| output_origin | 159 | ExternalOrigin (nat, nat option) |
| output_origin | 160 | QualificationOrigin (nat) |
| output_slot | 1020 | output_slot_id: nat, output_owner: nat, output_goal: nat, output_template: nat, output_profile: nat, output_inputs: slot_input list, output_input_identity: nat, output_reserved_dependencies: nat list, output_origin: output_origin |
| output_assignment | 1021 | assigned_slot: nat, assigned_requirement: claim, assigned_premise_correspondence: (nat \<times> nat) list, assigned_output: nat, assigned_lineage: nat, assigned_binding: binding, assigned_dependencies: nat list, assigned_retained: retained_value list |
| artifact_assignment | 1022 | artifact_assigned_slot: nat, artifact_assigned_request: nat, artifact_assigned_goal: nat, artifact_assigned_requirement: artifact_requirement, artifact_assigned_output: nat, artifact_assigned_generation: nat, artifact_assigned_lineage: nat, artifact_assigned_dependencies: nat list, artifact_assigned_retained: retained_value list |
| slot_assignment | 161 | ClaimOutput (output_assignment) |
| slot_assignment | 162 | ArtifactOutput (artifact_assignment) |
| pure_execution | 1023 | execution_id: nat, execution_request: nat, execution_slot: nat, execution_cost: operation_cost, execution_inputs: nat list |
| qualification_mode | 163 | Development |
| qualification_mode | 164 | Regression |
| qualification_mode | 165 | FreshHoldout |
| metric_value | 166 | ExactMetricValue (int, nat) |
| metric_value | 167 | UncertainMetric (nat) |
| metric_comparison | 168 | AtMost (int, nat) |
| metric_comparison | 169 | AtLeast (int, nat) |
| metric_comparison | 170 | Exactly (int, nat) |
| measured_metric | 1024 | metric_id: nat, metric_unit: nat, metric_value: metric_value, metric_observation: nat |
| metric_requirement | 1025 | required_metric: nat, required_unit: nat, required_comparison: metric_comparison |
| qualification_policy_spec | 1026 | policy_spec_id: nat, policy_required_mode: qualification_mode, policy_requires_baseline: bool, policy_metric_bound: nat, policy_requirements: metric_requirement list, policy_resource_association: nat |
| eligibility | 171 | UnknownEligibility |
| eligibility | 172 | Eligible |
| eligibility | 173 | ReservedEligibility (nat) |
| eligibility | 174 | ConsumedEligibility (nat) |
| exposure_state | 1027 | exposure_id: nat, exposure_parent: nat option, exposure_members: nat list |
| qualification_record | 1028 | qualification_id: nat, candidate_artifact: nat, baseline_artifact: nat option, qualification_pins: nat list, qualification_mode: qualification_mode, qualification_attempt: nat, qualification_run_spec: nat, qualification_domain: nat, qualification_policy_ref: nat, qualification_metrics: measured_metric list, exposure_before: nat, exposure_after: nat, spent_observation: nat, measured_binding: binding option, qualification_failure: nat option |
| eligibility_record | 1029 | eligibility_id: nat, eligibility_domain: nat, eligibility_policy: nat, eligibility_exposure: nat, eligibility_state: eligibility |
| qualification_reservation | 1030 | reservation_attempt: nat, reservation_owner: nat, reservation_goal: nat, reservation_candidate: nat, reservation_baseline: nat option, reservation_run_spec: nat, reservation_domain: nat, reservation_policy: nat, reservation_exposure: nat, reservation_eligibility: nat option, reservation_mode: qualification_mode, reservation_dependencies: nat list, reservation_cost: operation_cost |
| retention_grant | 1031 | retention_grant_id: nat, retention_grant_owner: nat, retention_grant_value: nat, retention_grant_destination: retention_scope, retention_policy_association: nat, retention_grant_provenance: nat list, retention_grant_observation: observation_requirement |
| package_kind | 175 | DataPackage |
| package_kind | 176 | SupportPackage |
| package_kind | 177 | TheoryPackage |
| package_kind | 178 | SpecialistPackage |
| package_export | 1032 | declared_export: nat, declared_requirement: claim, declared_profile: nat option |
| package_publication | 1033 | publication_slot: nat, publication_candidate: nat, publication_policy: nat, publication_previous: nat option, publication_qualification: nat, publication_kind: package_kind, publication_exports: package_export list, publication_native_bindings: (nat \<times> binding) list |
| delta | 179 | Publish (binding) |
| delta | 180 | RecordIntent (effect_intent) |
| delta | 181 | RecordObservation (source_publication) |
| delta | 182 | RecordEffectObservation (effect_observation) |
| delta | 183 | RecordOutput (slot_assignment, source_publication option) |
| delta | 184 | AdoptSession (nat, binding adopted_delta) |
| delta | 185 | ChangeRetention (nat, nat, retention_scope) |
| delta | 186 | ConsumeExposure (qualification_reservation) |
| delta | 187 | RecordQualification (qualification_record) |
| delta | 188 | PublishPackage (package_publication) |
| delta | 189 | Migrate (nat, nat, nat, binding list) |
| batch | 1034 | batch_id: nat, expected_revision: nat, batch_epoch: nat, batch_delta: delta |
| authority_state | 1035 | revision: nat, authority_epoch: nat, requests: request list, evidence_table: evidence list, visible_bindings: binding list, attempts: attempt list, effect_observations: effect_observation list, source_publications: source_publication list, pending_batch: batch option, issued_batches: nat list, retired_capabilities: nat list, retired_sources: nat list, revoked_objects: nat list, forgotten_objects: nat list, session_generation: nat, current_observations: observation_context list, session_views: binding session_view list, output_slots: output_slot list, output_assignments: slot_assignment list, pure_executions: pure_execution list, acquisition_jobs: acquisition_job list, retained_values: retained_value list, retention_grants: retention_grant list, consumed_retention_grants: nat list, exposure_history: exposure_state list, qualification_eligibility: eligibility_record list, spent_domains: nat list, qualification_reservations: qualification_reservation list, qualification_started: nat list, qualification_policies: qualification_policy_spec list, qualifications: qualification_record list, package_publications: package_publication list |
| event | 190 | OpenRequest (request) |
| event | 191 | ReserveRequest (request, output_slot list) |
| event | 192 | UpdateObservation (observation_context) |
| event | 193 | RecordUtterance (nat, nat) |
| event | 194 | StageAdoption (nat, nat, binding adopted_delta) |
| event | 195 | StageRetention (nat, nat, nat, retention_scope) |
| event | 196 | ExecutePure (pure_execution) |
| event | 197 | StageOutput (nat, slot_assignment, source_publication option) |
| event | 198 | RegisterManaged (retained_value) |
| event | 199 | InstallRetentionGrant (retention_grant) |
| event | 200 | InstallJob (acquisition_job) |
| event | 201 | StartJob (nat, operation_cost) |
| event | 202 | StopJob (nat, bool) |
| event | 203 | InstallQualificationPolicy (qualification_policy_spec) |
| event | 204 | InstallExposure (exposure_state) |
| event | 205 | InstallEligibility (eligibility_record) |
| event | 206 | ReserveQualification (nat, qualification_reservation) |
| event | 207 | ClaimQualificationStart (nat) |
| event | 208 | StageQualification (nat, qualification_record) |
| event | 209 | StageQualifiedPublication (nat, package_publication) |
| event | 210 | AttachEvidence (evidence) |
| event | 211 | SetOutcome (nat, nat, outcome) |
| event | 212 | AddBlocker (nat, blocker) |
| event | 213 | StageClaim (nat, nat, nat, nat) |
| event | 214 | StageIntent (nat, effect_intent) |
| event | 215 | StageEffectObservation (nat, effect_observation) |
| event | 216 | StageObservation (nat, source_publication) |
| event | 217 | StageMigration (nat, nat, nat, binding list) |
| event | 218 | DurableAck (nat, nat, nat) |
| event | 219 | DurableConflict (nat) |
| event | 220 | CancelRequest (nat) |
| event | 221 | RetireCapability (nat) |
| event | 222 | RetireSource (nat) |
| event | 223 | Revoke (nat) |
| event | 224 | Forget (nat) |
| event | 225 | ForgetRoots (nat list) |
| event | 226 | ClaimAndStart (nat) |
| event | 227 | Reconcile (nat, attempt_status) |
| command | 228 | Persist (batch) |
| command | 229 | Visible (nat) |
| command | 230 | Rejected (nat) |
| command | 231 | ClaimStart (effect_intent, nat) |
| command | 232 | StopRequest (nat) |
| command | 233 | RemoveManaged (nat) |
| command | 234 | AuthorityChanged (nat) |
| command | 235 | RunPure (pure_execution) |
| command | 236 | RunJob (acquisition_job) |
| command | 237 | ExposeQualification (qualification_reservation, nat) |
