theory Package_Update_Metadata
  imports "Veri7vn_Authority.Veri7vn_Authority"
begin

text \<open>These are pure metadata constructors. Only the fixed opaque native
producer may supply their projections in the service; decoded records do not
confer native ownership, measurement, or event construction authority. The
criterion is structural export-sequent equality, never semantic preservation.\<close>

record package_qualification_names =
  update_request :: nat
  update_goal :: nat
  update_request_slot :: nat
  update_claim :: nat
  update_target :: nat
  update_interpretation :: nat
  update_evidence :: nat
  update_semantic_generation :: nat
  update_executable_generation :: nat
  update_candidate :: nat
  update_contract :: nat
  update_run_spec :: nat
  update_policy :: nat
  update_policy_resource :: nat
  update_attempt :: nat
  update_qualification :: nat
  update_observation :: nat
  update_acceptance_metric :: nat
  update_count_metric :: nat
  update_unit :: nat
  update_exposure :: nat

record structural_update_names = package_qualification_names +
  update_baseline :: nat

record structural_update_result =
  result_names :: structural_update_names
  result_dependencies :: "nat list"
  result_checked_count :: nat

definition structural_update_dependencies :: "structural_update_result \<Rightarrow> nat list" where
  "structural_update_dependencies x = remdups (
    [update_request_slot (result_names x), update_candidate (result_names x), update_baseline (result_names x),
     update_contract (result_names x), update_run_spec (result_names x),
     update_policy (result_names x), update_policy_resource (result_names x),
     update_observation (result_names x), update_exposure (result_names x),
     update_executable_generation (result_names x)] @ result_dependencies x)"

definition structural_update_claim :: "structural_update_result \<Rightarrow> claim" where
  "structural_update_claim x = (let n = result_names x in
    \<lparr>claim_id = update_claim n, target_id = update_target n,
      interpretation_id = update_interpretation n, claim_kind = TestObservation,
      claim_modality = Asserted, collection_scope = Scalar,
      claim_optimality = Unspecified, premises = [],
      dependencies = structural_update_dependencies x,
      semantic_generation = update_semantic_generation n,
      executable_generation = ExecutableGeneration (update_executable_generation n)\<rparr>)"

definition structural_update_binding :: "structural_update_result \<Rightarrow> binding" where
  "structural_update_binding x = \<lparr>binding_request = update_request (result_names x),
    binding_goal = update_goal (result_names x), binding_claim = structural_update_claim x,
    binding_evidence = update_evidence (result_names x)\<rparr>"

definition structural_update_evidence :: "structural_update_result \<Rightarrow> evidence" where
  "structural_update_evidence x = \<lparr>evidence_id = update_evidence (result_names x),
    evidence_claim = structural_update_claim x, evidence_route = EvaluationOracle,
    evidence_managed_dependencies = remdups (
      [update_evidence (result_names x), update_claim (result_names x),
       update_target (result_names x), update_interpretation (result_names x),
       update_semantic_generation (result_names x)] @ structural_update_dependencies x)\<rparr>"

definition structural_update_reservation ::
  "structural_update_result \<Rightarrow> operation_cost \<Rightarrow> qualification_reservation" where
  "structural_update_reservation x cost = (let n = result_names x in
    \<lparr>reservation_attempt = update_attempt n, reservation_owner = update_request n, reservation_goal = update_goal n,
      reservation_candidate = update_candidate n, reservation_baseline = Some (update_baseline n),
      reservation_run_spec = update_run_spec n, reservation_domain = update_contract n,
      reservation_policy = update_policy n, reservation_exposure = update_exposure n,
      reservation_eligibility = None, reservation_mode = Regression,
      reservation_dependencies = structural_update_dependencies x, reservation_cost = cost\<rparr>)"

definition structural_reservation_matches ::
  "structural_update_result \<Rightarrow> operation_cost \<Rightarrow> qualification_reservation \<Rightarrow> bool" where
  "structural_reservation_matches x cost actual \<longleftrightarrow>
    actual = structural_update_reservation x cost"

definition structural_update_policy :: "structural_update_names \<Rightarrow> qualification_policy_spec" where
  "structural_update_policy n = \<lparr>policy_spec_id = update_policy n,
    policy_required_mode = Regression, policy_requires_baseline = True,
    policy_metric_bound = 256,
    policy_requirements = [\<lparr>required_metric = update_acceptance_metric n,
      required_unit = update_unit n, required_comparison = Exactly 1 1\<rparr>],
    policy_resource_association = update_policy_resource n\<rparr>"

definition structural_update_qualification ::
  "structural_update_result \<Rightarrow> qualification_record" where
  "structural_update_qualification x = (let n = result_names x in
    \<lparr>qualification_id = update_qualification n, candidate_artifact = update_candidate n,
      baseline_artifact = Some (update_baseline n), qualification_pins = structural_update_dependencies x,
      qualification_mode = Regression, qualification_attempt = update_attempt n,
      qualification_run_spec = update_run_spec n, qualification_domain = update_contract n,
      qualification_policy_ref = update_policy n,
      qualification_metrics = [
        \<lparr>metric_id = update_acceptance_metric n, metric_unit = update_unit n,
          metric_value = ExactMetricValue 1 1, metric_observation = update_observation n\<rparr>,
        \<lparr>metric_id = update_count_metric n, metric_unit = update_unit n,
          metric_value = ExactMetricValue (int (result_checked_count x)) 1,
          metric_observation = update_observation n\<rparr>],
      exposure_before = update_exposure n, exposure_after = update_exposure n,
      spent_observation = update_observation n,
      measured_binding = Some (structural_update_binding x), qualification_failure = None\<rparr>)"

definition structural_update_publication ::
  "structural_update_result \<Rightarrow> nat \<Rightarrow> nat option \<Rightarrow> package_kind \<Rightarrow>
    package_export list \<Rightarrow> (nat \<times> binding) list \<Rightarrow> package_publication" where
  "structural_update_publication x slot previous kind exports bindings =
    \<lparr>publication_slot = slot, publication_candidate = update_candidate (result_names x),
      publication_policy = update_policy (result_names x), publication_previous = previous,
      publication_qualification = update_qualification (result_names x), publication_kind = kind,
      publication_exports = exports, publication_native_bindings = bindings\<rparr>"

record initial_admission_names = package_qualification_names +
  admission_export_intent :: nat
  admission_source_owner :: nat
  admission_source_revision :: nat
  admission_manifest :: nat
record initial_admission_result =
  admission_names :: initial_admission_names
  admission_dependencies :: "nat list"
  admission_checked_count :: nat

definition initial_admission_dependencies :: "initial_admission_result \<Rightarrow> nat list" where
  "initial_admission_dependencies x = (let n=admission_names x in remdups (
    [update_request_slot n, update_candidate n, update_contract n, update_run_spec n, update_policy n,
     update_policy_resource n, update_observation n, update_exposure n, update_executable_generation n,
     admission_export_intent n,
     admission_source_owner n, admission_source_revision n, admission_manifest n] @ admission_dependencies x))"

definition initial_admission_claim :: "initial_admission_result \<Rightarrow> claim" where
  "initial_admission_claim x = (let n=admission_names x in
    \<lparr>claim_id=update_claim n, target_id=update_target n, interpretation_id=update_interpretation n,
      claim_kind=TestObservation, claim_modality=Asserted, collection_scope=Scalar,
      claim_optimality=Unspecified, premises=[], dependencies=initial_admission_dependencies x,
      semantic_generation=update_semantic_generation n,
      executable_generation=ExecutableGeneration (update_executable_generation n)\<rparr>)"

definition initial_admission_binding :: "initial_admission_result \<Rightarrow> binding" where
  "initial_admission_binding x = \<lparr>binding_request=update_request (admission_names x),
    binding_goal=update_goal (admission_names x), binding_claim=initial_admission_claim x,
    binding_evidence=update_evidence (admission_names x)\<rparr>"

definition initial_admission_evidence :: "initial_admission_result \<Rightarrow> evidence" where
  "initial_admission_evidence x = (let n=admission_names x in
    \<lparr>evidence_id=update_evidence n, evidence_claim=initial_admission_claim x,
      evidence_route=EvaluationOracle, evidence_managed_dependencies=remdups (
        [update_evidence n,update_claim n,update_target n,update_interpretation n,
         update_semantic_generation n] @ initial_admission_dependencies x)\<rparr>)"

definition initial_admission_reservation ::
  "initial_admission_result \<Rightarrow> operation_cost \<Rightarrow> qualification_reservation" where
  "initial_admission_reservation x cost = (let n=admission_names x in
    \<lparr>reservation_attempt=update_attempt n, reservation_owner=update_request n, reservation_goal=update_goal n,
      reservation_candidate=update_candidate n, reservation_baseline=None,
      reservation_run_spec=update_run_spec n, reservation_domain=update_contract n,
      reservation_policy=update_policy n, reservation_exposure=update_exposure n,
      reservation_eligibility=None, reservation_mode=Development,
      reservation_dependencies=initial_admission_dependencies x, reservation_cost=cost\<rparr>)"

definition initial_admission_policy :: "initial_admission_names \<Rightarrow> qualification_policy_spec" where
  "initial_admission_policy n = \<lparr>policy_spec_id=update_policy n,
    policy_required_mode=Development, policy_requires_baseline=False, policy_metric_bound=256,
    policy_requirements=[\<lparr>required_metric=update_acceptance_metric n,
      required_unit=update_unit n, required_comparison=Exactly 1 1\<rparr>],
    policy_resource_association=update_policy_resource n\<rparr>"

definition initial_admission_qualification :: "initial_admission_result \<Rightarrow> qualification_record" where
  "initial_admission_qualification x = (let n=admission_names x in
    \<lparr>qualification_id=update_qualification n, candidate_artifact=update_candidate n,
      baseline_artifact=None, qualification_pins=initial_admission_dependencies x,
      qualification_mode=Development, qualification_attempt=update_attempt n,
      qualification_run_spec=update_run_spec n, qualification_domain=update_contract n,
      qualification_policy_ref=update_policy n,
      qualification_metrics=[\<lparr>metric_id=update_acceptance_metric n, metric_unit=update_unit n,
        metric_value=ExactMetricValue 1 1, metric_observation=update_observation n\<rparr>,
        \<lparr>metric_id=update_count_metric n, metric_unit=update_unit n,
        metric_value=ExactMetricValue (int (admission_checked_count x)) 1,
        metric_observation=update_observation n\<rparr>],
      exposure_before=update_exposure n, exposure_after=update_exposure n,
      spent_observation=update_observation n, measured_binding=Some (initial_admission_binding x),
      qualification_failure=None\<rparr>)"

definition initial_admission_reservation_matches ::
  "initial_admission_result \<Rightarrow> operation_cost \<Rightarrow> qualification_reservation \<Rightarrow> bool" where
  "initial_admission_reservation_matches x cost actual \<longleftrightarrow>
    actual=initial_admission_reservation x cost"

definition initial_admission_publication ::
  "initial_admission_result \<Rightarrow> nat \<Rightarrow> package_kind \<Rightarrow> package_export list \<Rightarrow>
    (nat \<times> binding) list \<Rightarrow> package_publication" where
  "initial_admission_publication x slot kind exports bindings =
    \<lparr>publication_slot=slot, publication_candidate=update_candidate (admission_names x),
      publication_policy=update_policy (admission_names x), publication_previous=None,
      publication_qualification=update_qualification (admission_names x),
      publication_kind=kind, publication_exports=exports, publication_native_bindings=bindings\<rparr>"

text \<open>A checked observation can be durably attached before its goal is accepted
or its qualification record is staged. Recovery checks that exact historical
observation and its paid reservation; it does not promote a pending/cancelled goal
into a licensed binding or publish a package.\<close>
definition qualification_observation_current ::
  "nat \<Rightarrow> authority_state \<Rightarrow> claim \<Rightarrow> evidence \<Rightarrow> binding \<Rightarrow>
    qualification_policy_spec \<Rightarrow> qualification_record \<Rightarrow> bool" where
  "qualification_observation_current request_slot s c e b policy q \<longleftrightarrow>
    e \<in> set (evidence_table s) \<and> evidence_claim e=c \<and> evidence_accessible s e \<and>
    evidence_route e=EvaluationOracle \<and> claim_kind c=TestObservation \<and>
    binding_claim b=c \<and> binding_evidence b=evidence_id e \<and>
    policy \<in> set (qualification_policies s) \<and>
    (\<forall>a \<in> set (claim_assignments s). assigned_slot a=request_slot \<longrightarrow>
      assigned_binding a=b \<and> assigned_lineage a=qualification_attempt q) \<and>
    qualification_attempt q \<in> set (qualification_started s) \<and>
    (\<forall>old \<in> set (qualifications s). qualification_id old=qualification_id q \<longrightarrow> old=q) \<and>
    (\<exists>reserved \<in> set (qualification_reservations s).
      reservation_attempt reserved=qualification_attempt q \<and>
      reservation_owner reserved=binding_request b \<and>
      (\<exists>slot \<in> set (output_slots s). output_slot_id slot=request_slot \<and>
        output_owner slot=binding_request b \<and> output_goal slot=binding_goal b \<and>
        output_origin slot=QualificationOrigin (qualification_attempt q) \<and>
        output_profile slot=cost_profile (reservation_cost reserved)) \<and>
      reservation_goal reserved=binding_goal b \<and>
      reservation_candidate reserved=candidate_artifact q \<and>
      reservation_baseline reserved=baseline_artifact q \<and>
      reservation_run_spec reserved=qualification_run_spec q \<and>
      reservation_domain reserved=qualification_domain q \<and>
      reservation_policy reserved=qualification_policy_ref q \<and>
      reservation_exposure reserved=exposure_before q \<and>
      reservation_mode reserved=qualification_mode q \<and>
      reservation_dependencies reserved=qualification_pins q \<and>
      reservation_eligibility reserved=None \<and> cost_units (reservation_cost reserved)>0 \<and>
      (case executable_generation c of NoExecution \<Rightarrow> False | ExecutableGeneration code \<Rightarrow>
        cost_code_generation (reservation_cost reserved)=code)) \<and>
    (\<exists>r \<in> set (requests s). request_id r=binding_request b \<and>
      request_session r=None \<and> request_observation r=StateTimeUnused \<and>
      EvaluationOracle \<in> set (allowed_routes r) \<and>
      list_all (\<lambda>d. d \<in> set (dependencies c)) (request_dependencies r) \<and>
      (\<exists>g \<in> set (request_goals r). goal_id g=binding_goal b \<and>
        goal_interpretation g=interpretation_id c \<and>
        (\<exists>original. goal_required g=ClaimRequirement original \<and> scope_preserved original c []) \<and>
        goal_generation g=semantic_generation c \<and>
        executable_generation c=ExecutableGeneration (goal_code_generation g) \<and>
        goal_output_slot g=Some request_slot \<and> goal_capability g \<in> set (dependencies c)))"

definition structural_update_current :: "authority_state \<Rightarrow> structural_update_result \<Rightarrow> bool" where
  "structural_update_current s x = qualification_observation_current (update_request_slot (result_names x)) s
    (structural_update_claim x) (structural_update_evidence x) (structural_update_binding x)
    (structural_update_policy (result_names x)) (structural_update_qualification x)"
definition initial_admission_current :: "authority_state \<Rightarrow> initial_admission_result \<Rightarrow> bool" where
  "initial_admission_current s x = qualification_observation_current (update_request_slot (admission_names x)) s
    (initial_admission_claim x) (initial_admission_evidence x) (initial_admission_binding x)
    (initial_admission_policy (admission_names x)) (initial_admission_qualification x)"

text \<open>Closed native Frame adapters use these constructors rather than
independently depending on generated record-extension layouts. They construct
metadata only; their arguments must still come from opaque native owners.\<close>
fun make_structural_update_result :: "nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> structural_update_result option" where
  "make_structural_update_result [req,goal,request_slot,cid,target,interp,eid,semantic,code,candidate,contract,
      run,policy,resource,attempt,qid,observation,metric,count_metric,unit,exposure,baseline] deps checked =
    Some \<lparr>result_names=\<lparr>update_request=req,update_goal=goal,update_request_slot=request_slot,update_claim=cid,update_target=target,
      update_interpretation=interp,update_evidence=eid,update_semantic_generation=semantic,
      update_executable_generation=code,update_candidate=candidate,update_contract=contract,
      update_run_spec=run,update_policy=policy,update_policy_resource=resource,update_attempt=attempt,
      update_qualification=qid,update_observation=observation,update_acceptance_metric=metric,
      update_count_metric=count_metric,update_unit=unit,update_exposure=exposure,update_baseline=baseline\<rparr>,
      result_dependencies=deps,result_checked_count=checked\<rparr>" |
  "make_structural_update_result _ _ _ = None"
fun make_initial_admission_result :: "nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> initial_admission_result option" where
  "make_initial_admission_result [req,goal,request_slot,cid,target,interp,eid,semantic,code,candidate,contract,
      run,policy,resource,attempt,qid,observation,metric,count_metric,unit,exposure,intent,source,revision,manifest] deps checked =
    Some \<lparr>admission_names=\<lparr>update_request=req,update_goal=goal,update_request_slot=request_slot,update_claim=cid,update_target=target,
      update_interpretation=interp,update_evidence=eid,update_semantic_generation=semantic,
      update_executable_generation=code,update_candidate=candidate,update_contract=contract,
      update_run_spec=run,update_policy=policy,update_policy_resource=resource,update_attempt=attempt,
      update_qualification=qid,update_observation=observation,update_acceptance_metric=metric,
      update_count_metric=count_metric,update_unit=unit,update_exposure=exposure,
      admission_export_intent=intent,admission_source_owner=source,admission_source_revision=revision,
      admission_manifest=manifest\<rparr>,admission_dependencies=deps,admission_checked_count=checked\<rparr>" |
  "make_initial_admission_result _ _ _ = None"
definition qualification_observation_cost :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> operation_cost" where
  "qualification_observation_cost units profile code operation step_id =
    \<lparr>cost_profile=profile,cost_code_generation=code,cost_operation=operation,cost_step=step_id,cost_units=units\<rparr>"
definition qualification_package_export :: "nat \<Rightarrow> claim \<Rightarrow> nat option \<Rightarrow> package_export" where
  "qualification_package_export id required profile = \<lparr>declared_export=id,
    declared_requirement=required,declared_profile=profile\<rparr>"

definition structural_update_output :: "structural_update_result \<Rightarrow> retained_value list \<Rightarrow> output_assignment" where
  "structural_update_output x retained = (let n=result_names x in
    \<lparr>assigned_slot=update_request_slot n, assigned_requirement=structural_update_claim x,
      assigned_premise_correspondence=[], assigned_output=update_observation n,
      assigned_lineage=update_attempt n, assigned_binding=structural_update_binding x,
      assigned_dependencies=structural_update_dependencies x, assigned_retained=retained\<rparr>)"
definition initial_admission_output :: "initial_admission_result \<Rightarrow> retained_value list \<Rightarrow> output_assignment" where
  "initial_admission_output x retained = (let n=admission_names x in
    \<lparr>assigned_slot=update_request_slot n, assigned_requirement=initial_admission_claim x,
      assigned_premise_correspondence=[], assigned_output=update_observation n,
      assigned_lineage=update_attempt n, assigned_binding=initial_admission_binding x,
      assigned_dependencies=initial_admission_dependencies x, assigned_retained=retained\<rparr>)"

end
