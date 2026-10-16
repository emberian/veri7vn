theory Authority_Events
  imports Veri7vn_Authority_Metadata.Authority_Metadata
begin

ML \<open>Veri7vn_Authority_Compile.reset "events_started"\<close>

datatype (plugins del: size) event =
  OpenRequest request |
  ReserveRequest request "output_slot list" |
  UpdateObservation observation_context |
  RecordUtterance nat nat |
  StageAdoption nat nat "binding adopted_delta" |
  StageRetention nat nat nat retention_scope |
  ExecutePure pure_execution |
  StageOutput nat output_assignment "source_publication option" |
  RegisterManaged retained_value |
  InstallRetentionGrant retention_grant |
  InstallJob acquisition_job |
  StartJob nat operation_cost |
  StopJob nat bool |
  InstallQualificationPolicy qualification_policy_spec |
  InstallExposure exposure_state |
  InstallEligibility eligibility_record |
  ReserveQualification nat qualification_reservation |
  ClaimQualificationStart nat |
  StageQualification nat qualification_record |
  StageQualifiedPublication nat package_publication |
  AttachEvidence evidence |
  SetOutcome nat nat outcome |
  AddBlocker nat blocker |
  StageClaim nat nat nat nat |
  StageIntent nat effect_intent |
  StageObservation nat source_publication |
  StageMigration nat nat nat "binding list" |
  DurableAck nat nat nat |
  DurableConflict nat |
  CancelRequest nat |
  RetireCapability nat |
  RetireSource nat |
  Revoke nat |
  Forget nat |
  ForgetRoots "nat list" |
  ClaimAndStart nat |
  Reconcile nat attempt_status

datatype (plugins del: size) command = Persist batch | Visible nat | Rejected nat |
  ClaimStart effect_intent nat | StopRequest nat | RemoveManaged nat |
  AuthorityChanged nat | RunPure pure_execution | RunJob acquisition_job |
  ExposeQualification qualification_reservation nat

ML \<open>Veri7vn_Authority_Compile.phase "event_types_ready"\<close>

end
