# Finite authority metadata schema 1

Exact parsed-signature fingerprint (SHA-256): 3c8ae1272c21be70c7bcc2821cdd03db89558a7df2d14b7b2cc22cd0c168ca69. WireNode 3 [WireNat fingerprint, body] seals transport frames/checkpoints. This locates a schema, never native evidence.
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
| outcome | 135 | Accepted (claim, nat) |
| outcome | 136 | AwaitingOutput (nat) |
| outcome | 137 | NeedsInput (nat list) |
| outcome | 138 | Declined (nat) |
| outcome | 139 | Inconclusive (nat) |
| outcome | 140 | Failed (nat) |
| outcome | 141 | Cancelled |
| blocker_scope | 142 | RequestScope (nat) |
| blocker_scope | 143 | InterpretationScope (nat) |
| blocker_scope | 144 | PremiseScope (nat) |
| blocker_scope | 145 | CapabilityScope (nat) |
| blocker | 1010 | blocked_scope: blocker_scope, reason_id: nat, discharge_conditions: nat list |
| subgoal | 1011 | goal_id: nat, goal_interpretation: nat, goal_capability: nat, goal_dependencies: nat list, goal_required: claim, goal_output_slot: nat option, goal_outcome: outcome |
| request | 1012 | request_id: nat, request_generation: nat, request_code_generation: nat, request_prestate: nat, request_dependencies: nat list, allowed_routes: assurance_route list, permitted_effects: nat list, request_goals: subgoal list, request_blockers: blocker list, request_cancelled: bool, request_fuel: nat, request_session: nat option, request_observation: observation_requirement, request_retention_scopes: retention_scope list |
| evidence | 1013 | evidence_id: nat, evidence_claim: claim, evidence_route: assurance_route, evidence_managed_dependencies: nat list |
| binding | 1014 | binding_request: nat, binding_goal: nat, binding_claim: claim, binding_evidence: nat |
| source_publication | 1015 | source_binding_id: nat, snapshot_id: nat, observation_attempt: nat, observation_job: (nat \<times> nat) option, observed_binding: binding |
| effect_intent | 1016 | attempt_id: nat, attempt_request: nat, attempt_target: nat, attempt_capability: nat, attempt_sources: nat list, attempt_dependencies: nat list, attempt_prestate: nat, attempt_cost: operation_cost, attempt_job: (nat \<times> nat) option |
| attempt_status | 146 | Prepared |
| attempt_status | 147 | Running |
| attempt_status | 148 | Confirmed |
| attempt_status | 149 | EffectFailed |
| attempt_status | 150 | Unknown |
| attempt | 1017 | attempt_intent: effect_intent, attempt_state: attempt_status |
| slot_input | 151 | KnownInput (nat) |
| slot_input | 152 | ReservedOutput (nat) |
| output_origin | 153 | PureOrigin |
| output_origin | 154 | ExternalOrigin (nat, nat option) |
| output_slot | 1018 | output_slot_id: nat, output_owner: nat, output_goal: nat, output_template: nat, output_profile: nat, output_inputs: slot_input list, output_input_identity: nat, output_reserved_dependencies: nat list, output_origin: output_origin |
| output_assignment | 1019 | assigned_slot: nat, assigned_requirement: claim, assigned_premise_correspondence: (nat \<times> nat) list, assigned_output: nat, assigned_lineage: nat, assigned_binding: binding, assigned_dependencies: nat list, assigned_retained: retained_value list |
| pure_execution | 1020 | execution_id: nat, execution_request: nat, execution_slot: nat, execution_cost: operation_cost, execution_inputs: nat list |
| qualification_mode | 155 | Development |
| qualification_mode | 156 | Regression |
| qualification_mode | 157 | FreshHoldout |
| metric_value | 158 | ExactMetricValue (int, nat) |
| metric_value | 159 | UncertainMetric (nat) |
| metric_comparison | 160 | AtMost (int, nat) |
| metric_comparison | 161 | AtLeast (int, nat) |
| metric_comparison | 162 | Exactly (int, nat) |
| measured_metric | 1021 | metric_id: nat, metric_unit: nat, metric_value: metric_value, metric_observation: nat |
| metric_requirement | 1022 | required_metric: nat, required_unit: nat, required_comparison: metric_comparison |
| qualification_policy_spec | 1023 | policy_spec_id: nat, policy_required_mode: qualification_mode, policy_requires_baseline: bool, policy_metric_bound: nat, policy_requirements: metric_requirement list, policy_resource_association: nat |
| eligibility | 163 | UnknownEligibility |
| eligibility | 164 | Eligible |
| eligibility | 165 | ReservedEligibility (nat) |
| eligibility | 166 | ConsumedEligibility (nat) |
| exposure_state | 1024 | exposure_id: nat, exposure_parent: nat option, exposure_members: nat list |
| qualification_record | 1025 | qualification_id: nat, candidate_artifact: nat, baseline_artifact: nat option, qualification_pins: nat list, qualification_mode: qualification_mode, qualification_attempt: nat, qualification_run_spec: nat, qualification_domain: nat, qualification_policy_ref: nat, qualification_metrics: measured_metric list, exposure_before: nat, exposure_after: nat, spent_observation: nat, measured_binding: binding option, qualification_failure: nat option |
| eligibility_record | 1026 | eligibility_id: nat, eligibility_domain: nat, eligibility_policy: nat, eligibility_exposure: nat, eligibility_state: eligibility |
| qualification_reservation | 1027 | reservation_attempt: nat, reservation_owner: nat, reservation_candidate: nat, reservation_baseline: nat option, reservation_run_spec: nat, reservation_domain: nat, reservation_policy: nat, reservation_exposure: nat, reservation_eligibility: nat option, reservation_mode: qualification_mode, reservation_dependencies: nat list, reservation_cost: operation_cost |
| retention_grant | 1028 | retention_grant_id: nat, retention_grant_owner: nat, retention_grant_value: nat, retention_grant_destination: retention_scope, retention_policy_association: nat, retention_grant_provenance: nat list, retention_grant_observation: observation_requirement |
| package_kind | 167 | DataPackage |
| package_kind | 168 | SupportPackage |
| package_kind | 169 | TheoryPackage |
| package_kind | 170 | SpecialistPackage |
| package_export | 1029 | declared_export: nat, declared_requirement: claim, declared_profile: nat option |
| package_publication | 1030 | publication_slot: nat, publication_candidate: nat, publication_policy: nat, publication_previous: nat option, publication_qualification: nat, publication_kind: package_kind, publication_exports: package_export list, publication_native_bindings: (nat \<times> binding) list |
| delta | 171 | Publish (binding) |
| delta | 172 | RecordIntent (effect_intent) |
| delta | 173 | RecordObservation (source_publication) |
| delta | 174 | RecordOutput (output_assignment, source_publication option) |
| delta | 175 | AdoptSession (nat, binding adopted_delta) |
| delta | 176 | ChangeRetention (nat, nat, retention_scope) |
| delta | 177 | ConsumeExposure (qualification_reservation) |
| delta | 178 | RecordQualification (qualification_record) |
| delta | 179 | PublishPackage (package_publication) |
| delta | 180 | Migrate (nat, nat, nat, binding list) |
| batch | 1031 | batch_id: nat, expected_revision: nat, batch_epoch: nat, batch_delta: delta |
| authority_state | 1032 | revision: nat, authority_epoch: nat, requests: request list, evidence_table: evidence list, visible_bindings: binding list, attempts: attempt list, source_publications: source_publication list, pending_batch: batch option, issued_batches: nat list, retired_capabilities: nat list, retired_sources: nat list, revoked_objects: nat list, forgotten_objects: nat list, session_generation: nat, current_observations: observation_context list, session_views: binding session_view list, output_slots: output_slot list, output_assignments: output_assignment list, pure_executions: pure_execution list, acquisition_jobs: acquisition_job list, retained_values: retained_value list, retention_grants: retention_grant list, consumed_retention_grants: nat list, exposure_history: exposure_state list, qualification_eligibility: eligibility_record list, spent_domains: nat list, qualification_reservations: qualification_reservation list, qualification_started: nat list, qualification_policies: qualification_policy_spec list, qualifications: qualification_record list, package_publications: package_publication list |
| event | 181 | OpenRequest (request) |
| event | 182 | ReserveRequest (request, output_slot list) |
| event | 183 | UpdateObservation (observation_context) |
| event | 184 | RecordUtterance (nat, nat) |
| event | 185 | StageAdoption (nat, nat, binding adopted_delta) |
| event | 186 | StageRetention (nat, nat, nat, retention_scope) |
| event | 187 | ExecutePure (pure_execution) |
| event | 188 | StageOutput (nat, output_assignment, source_publication option) |
| event | 189 | RegisterManaged (retained_value) |
| event | 190 | InstallRetentionGrant (retention_grant) |
| event | 191 | InstallJob (acquisition_job) |
| event | 192 | StartJob (nat, operation_cost) |
| event | 193 | StopJob (nat, bool) |
| event | 194 | InstallQualificationPolicy (qualification_policy_spec) |
| event | 195 | InstallExposure (exposure_state) |
| event | 196 | InstallEligibility (eligibility_record) |
| event | 197 | ReserveQualification (nat, qualification_reservation) |
| event | 198 | ClaimQualificationStart (nat) |
| event | 199 | StageQualification (nat, qualification_record) |
| event | 200 | StageQualifiedPublication (nat, package_publication) |
| event | 201 | AttachEvidence (evidence) |
| event | 202 | SetOutcome (nat, nat, outcome) |
| event | 203 | AddBlocker (nat, blocker) |
| event | 204 | StageClaim (nat, nat, nat, nat) |
| event | 205 | StageIntent (nat, effect_intent) |
| event | 206 | StageObservation (nat, source_publication) |
| event | 207 | StageMigration (nat, nat, nat, binding list) |
| event | 208 | DurableAck (nat, nat, nat) |
| event | 209 | DurableConflict (nat) |
| event | 210 | CancelRequest (nat) |
| event | 211 | RetireCapability (nat) |
| event | 212 | RetireSource (nat) |
| event | 213 | Revoke (nat) |
| event | 214 | Forget (nat) |
| event | 215 | ForgetRoots (nat list) |
| event | 216 | ClaimAndStart (nat) |
| event | 217 | Reconcile (nat, attempt_status) |
| command | 218 | Persist (batch) |
| command | 219 | Visible (nat) |
| command | 220 | Rejected (nat) |
| command | 221 | ClaimStart (effect_intent, nat) |
| command | 222 | StopRequest (nat) |
| command | 223 | RemoveManaged (nat) |
| command | 224 | AuthorityChanged (nat) |
| command | 225 | RunPure (pure_execution) |
| command | 226 | RunJob (acquisition_job) |
| command | 227 | ExposeQualification (qualification_reservation, nat) |
