theory Native_Effects_Service
  imports Veri7vn_Native_Request_Scope.Native_Request_Scope Effect_Observation_Encoding
begin

text \<open>Metadata constructors for the fixed native effect producer. These
constructors convey no authority when called with unauthenticated identifiers.
The parent Frame calls them only from that producer's opaque retained entry.\<close>
record service_effect_names =
  se_request :: nat
  se_goal :: nat
  se_interpretation :: nat
  se_target :: nat
  se_capability :: nat
  se_profile :: nat
  se_operation :: nat
  se_step :: nat
  se_generation :: nat
  se_attempt :: nat
  se_batch :: nat

definition service_effect_names ::
  "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow>
   nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> service_effect_names" where
  "service_effect_names request goal interpretation target capability profile operation step_id generation attempt batch =
    \<lparr>se_request=request,se_goal=goal,se_interpretation=interpretation,se_target=target,
      se_capability=capability,se_profile=profile,se_operation=operation,se_step=step_id,
      se_generation=generation,se_attempt=attempt,se_batch=batch\<rparr>"

definition service_effect_cost :: "service_effect_names \<Rightarrow> operation_cost" where
  "service_effect_cost n = \<lparr>cost_profile=se_profile n,
    cost_code_generation=se_generation n,cost_operation=se_operation n,
    cost_step=se_step n,cost_units=1\<rparr>"
definition service_effect_registered_value :: "nat \<Rightarrow> retention_scope \<Rightarrow> nat list \<Rightarrow> event" where
  "service_effect_registered_value key owner deps = RegisterManaged
    \<lparr>retained_id=key,retained_owner=owner,retained_dependencies=deps,
      retained_read_dependencies=[],retained_access_requirements=[],retained_payload=key\<rparr>"
definition service_effect_registration :: "service_effect_names \<Rightarrow> nat list \<Rightarrow> event list" where
  "service_effect_registration n inputs =
    map (\<lambda>key. service_effect_registered_value key WorkspaceShared []) inputs @
    [service_effect_registered_value (se_generation n) WorkspaceShared [],
     service_effect_registered_value (se_profile n) (RequestLocal (se_request n)) [se_generation n],
     service_effect_registered_value (se_operation n) (RequestLocal (se_request n)) [se_profile n,se_generation n],
     service_effect_registered_value (se_step n) (RequestLocal (se_request n)) [se_operation n],
     service_effect_registered_value (se_capability n) (RequestLocal (se_request n)) [se_profile n,se_operation n],
     service_effect_registered_value (se_target n) (RequestLocal (se_request n)) (se_capability n#inputs),
     service_effect_registered_value (se_interpretation n) (RequestLocal (se_request n)) (se_target n#inputs)]"
definition service_effect_reserve ::
  "service_effect_names \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> event" where
  "service_effect_reserve n prestate deps = ReserveRequest
    \<lparr>request_id=se_request n,request_generation=se_generation n,
      request_code_generation=se_generation n,request_prestate=prestate,
      request_dependencies=deps,allowed_routes=[],permitted_effects=[se_target n],
      request_goals=[\<lparr>goal_id=se_goal n,goal_interpretation=se_interpretation n,
        goal_capability=se_capability n,goal_dependencies=[],
        goal_required=ClaimRequirement \<lparr>claim_id=se_goal n,target_id=se_target n,
          interpretation_id=se_interpretation n,claim_kind=SourceObservation,
          claim_modality=Asserted,collection_scope=Scalar,claim_optimality=Unspecified,
          premises=[],dependencies=deps,semantic_generation=se_generation n,
          executable_generation=NoExecution\<rparr>,
        goal_generation=se_generation n,goal_code_generation=se_generation n,
        goal_output_slot=None,goal_outcome=NeedsInput []\<rparr>],
      request_blockers=[],request_cancelled=False,request_fuel=1,request_session=None,
      request_observation=StateTimeUnused,request_retention_scopes=[RequestLocal (se_request n)]\<rparr> []"
definition service_effect_intent ::
  "service_effect_names \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> effect_intent" where
  "service_effect_intent n prestate sources deps =
    \<lparr>attempt_id=se_attempt n,attempt_request=se_request n,
      attempt_target=se_target n,attempt_capability=se_capability n,
      attempt_sources=sources,attempt_dependencies=deps,attempt_prestate=prestate,
      attempt_cost=service_effect_cost n,attempt_job=None\<rparr>"
definition service_effect_stage ::
  "service_effect_names \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> event" where
  "service_effect_stage n prestate sources deps = StageIntent (se_batch n)
    (service_effect_intent n prestate sources deps)"
definition service_effect_start :: "service_effect_names \<Rightarrow> event" where
  "service_effect_start n = ClaimAndStart (se_attempt n)"

definition service_effect_request_origin :: "service_effect_names \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> request option" where
  "service_effect_request_origin n prestate deps=(case service_effect_reserve n prestate deps of
    ReserveRequest r slots \<Rightarrow> Some r | _\<Rightarrow>None)"
definition service_effect_request_immutable :: "request \<Rightarrow> request" where
  "service_effect_request_immutable r=r\<lparr>request_blockers:=[],request_cancelled:=False,request_fuel:=1,
    request_goals:=map (\<lambda>g. g\<lparr>goal_outcome:=NeedsInput []\<rparr>)(request_goals r)\<rparr>"
definition service_effect_request_matches ::
  "authority_state \<Rightarrow> service_effect_names \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "service_effect_request_matches s n prestate sources deps \<longleftrightarrow>
    (case filter (\<lambda>r. request_id r=se_request n) (required_native_effect_requests s) of [r] \<Rightarrow>
      request_fuel r\<le>1 \<and> service_effect_request_origin n prestate deps=Some(service_effect_request_immutable r) \<and>
      (case filter (\<lambda>a. attempt_request(attempt_intent a)=se_request n) (attempts s) of []\<Rightarrow>True
        |[a]\<Rightarrow>attempt_intent a=service_effect_intent n prestate sources deps \<and>
          length(filter (\<lambda>b. attempt_id(attempt_intent b)=se_attempt n)(attempts s))=1
        |_\<Rightarrow>False)
     |_\<Rightarrow>False)"
definition service_effect_handoff_current :: "authority_state \<Rightarrow> nat \<Rightarrow> bool" where
  "service_effect_handoff_current s identity \<longleftrightarrow>
    (case filter (\<lambda>a. attempt_id(attempt_intent a)=identity)(attempts s) of [a]\<Rightarrow>
      attempt_state a=Running \<and> effect_current_context s (attempt_intent a) |_\<Rightarrow>False)"
definition service_effect_observation :: "nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> effect_observation" where
  "service_effect_observation identity source rejected=\<lparr>effect_observation_attempt=identity,
    effect_observation_source=source,effect_observation_status=(if rejected then EffectFailed else Confirmed)\<rparr>"
definition service_effect_observation_stage :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> event" where
  "service_effect_observation_stage batch identity source rejected=
    StageEffectObservation batch (service_effect_observation identity source rejected)"
definition service_effect_observation_matches ::
  "authority_state \<Rightarrow> service_effect_names \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> bool" where
  "service_effect_observation_matches s n prestate sources deps source rejected \<longleftrightarrow>
    service_effect_request_matches s n prestate sources deps \<and>
    filter (\<lambda>observation. effect_observation_source observation=source)
      (required_native_effect_observations s)=[service_effect_observation (se_attempt n) source rejected]"

definition service_effect_source_visible :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> bool" where
  "service_effect_source_visible s source identity owner rejected \<longleftrightarrow>
    filter (\<lambda>observation. effect_observation_source observation=source)
      (required_native_effect_observations s)=[service_effect_observation identity source rejected] \<and>
    (case filter (\<lambda>a. attempt_id(attempt_intent a)=identity)(attempts s) of [a]\<Rightarrow>
      attempt_request(attempt_intent a)=owner |_\<Rightarrow>False)"

lemma service_effect_intent_exact:
  "attempt_cost (service_effect_intent n prestate sources deps)=service_effect_cost n \<and>
    attempt_sources (service_effect_intent n prestate sources deps)=sources \<and>
    attempt_dependencies (service_effect_intent n prestate sources deps)=deps"
  by (simp add: service_effect_intent_def)

ML_file "native_effect_inputs.ML"
ML_file "native_effect_responses.ML"
ML_file "native_effect_codec.ML"
ML_file "native_effect_service.ML"
ML_file "native_effect_observation.ML"
ML_file "native_effect_export.ML"
ML_file "native_effect_recovery.ML"
ML \<open>
structure Veri7vn_Native_Effect_Image =
struct
  val executable=Veri7vn_Executable_Identity.pin @{theory}
    {artifact="veri7vn.fixed-local-mcp-effects/1",compiler="Isabelle code generator / PolyML / Scala",
      target="SML+JVM",serializers=["effect-source configuration/2 packet/1",
        "effect-observation-witness/1","veri7vn-mcp-observed-response/1","JSON.Format/1 ordered receipt"],
      foreign_primitives=["fixed in-process local-mcp/1 counter; no arbitrary endpoint"],
      settings=["signed32 integers; Unicode scalars; ASCII object keys",
        "record64KiB; receipt16KiB; witness512KiB; depth24; shared4096nodes"]};
end;
\<close>
end
