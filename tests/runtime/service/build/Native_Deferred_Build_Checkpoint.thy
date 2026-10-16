theory Native_Deferred_Build_Checkpoint
  imports Veri7vn_Runtime_Build.Native_Build_Service
begin

text \<open>Fixture-only producer of a real generated reservation checkpoint.
The two plans are projections of already owned native deferred children. No
target is replayed, no execution is charged and no output is assigned.\<close>

definition deferred_build_fixture_reserve ::
  "build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow>
    build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow> nat list \<Rightarrow> event" where
  "deferred_build_fixture_reserve first first_required second second_required deps =
    (let a=bsp_control first; b=bsp_control second in ReserveRequest
      \<lparr>request_id=bsc_request a, request_generation=bsc_generation a,
       request_code_generation=bsc_code a,request_prestate=0,
       request_dependencies=deps,allowed_routes=[],permitted_effects=[],
       request_goals=[build_service_child first first_required [],
         build_service_child second second_required [ArtifactDependency (bsc_goal a)]],
       request_blockers=[],request_cancelled=False,request_fuel=2,request_session=None,
       request_observation=StateTimeUnused,
       request_retention_scopes=[RequestLocal (bsc_request a)]\<rparr>
      [build_service_slot first first_required deps,
       build_service_slot second second_required deps])"

definition deferred_build_fixture_checkpoint ::
  "build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow>
    build_service_plan \<Rightarrow> artifact_requirement \<Rightarrow> nat list \<Rightarrow> authority_wire option" where
  "deferred_build_fixture_checkpoint first first_required second second_required deps =
    (let result=step initial_state
       (deferred_build_fixture_reserve first first_required second second_required deps)
     in if snd result=[] \<and> length (required_native_children (fst result))=2
       then Some (encode_checkpoint (fst result)) else None)"

end
