theory Native_Service
  imports Veri7vn_Runtime_Foundation.Runtime_Foundation
begin
definition service_attach_native_evidence :: "nat \<Rightarrow> claim \<Rightarrow> nat list \<Rightarrow> event" where
  "service_attach_native_evidence eid c deps = AttachEvidence
    \<lparr>evidence_id=eid, evidence_claim=c, evidence_route=KernelConsequence,
      evidence_managed_dependencies=eid#deps\<rparr>"
definition service_evidence_only_checkpoint :: "authority_state \<Rightarrow> bool" where
  "service_evidence_only_checkpoint s =
    (s\<lparr>evidence_table:=[], revision:=0, authority_epoch:=0,
      revoked_objects:=[], forgotten_objects:=[], retired_capabilities:=[],
      retired_sources:=[]\<rparr> = initial_state)"
definition service_evidence_matches :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_evidence_matches s ev = (case ev of AttachEvidence e \<Rightarrow>
    e \<in> set (required_native_evidence s) | _ \<Rightarrow> False)"

text \<open>Fixed resident mathematics bridge. These builders are used only after
native request elaboration and the fixed worker's same-request output association.
They are metadata constructors, not proofs of arbitrary caller-selected claims.\<close>
record service_math_names =
  sm_request :: nat
  sm_goal :: nat
  sm_interpretation :: nat
  sm_capability :: nat
  sm_operation :: nat
  sm_profile :: nat
  sm_step :: nat
  sm_template :: nat
  sm_claim :: nat
  sm_parameter :: nat
  sm_input :: nat
  sm_slot :: nat
  sm_code :: nat
  sm_semantic :: nat

definition service_math_names :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> service_math_names" where
  "service_math_names rid gid iid cap operation profile step_id target cid parameter input slot code semantic =
    \<lparr>sm_request=rid,sm_goal=gid,sm_interpretation=iid,sm_capability=cap,
      sm_operation=operation,sm_profile=profile,sm_step=step_id,sm_template=target,
      sm_claim=cid,sm_parameter=parameter,sm_input=input,sm_slot=slot,
      sm_code=code,sm_semantic=semantic\<rparr>"
definition service_math_requirement :: "service_math_names \<Rightarrow> nat list \<Rightarrow> claim" where
  "service_math_requirement n deps =
    \<lparr>claim_id=sm_claim n,target_id=sm_template n,interpretation_id=sm_interpretation n,
      claim_kind=Mathematical,claim_modality=Asserted,collection_scope=Scalar,
      claim_optimality=Unspecified,premises=[],dependencies=deps,
      semantic_generation=sm_semantic n,executable_generation=ExecutableGeneration (sm_code n)\<rparr>"
definition service_math_input :: "service_math_names \<Rightarrow> event" where
  "service_math_input n = RegisterManaged
    \<lparr>retained_id=sm_input n,retained_owner=WorkspaceShared,
      retained_dependencies=[],retained_read_dependencies=[],retained_access_requirements=[],
      retained_payload=sm_input n\<rparr>"
definition service_math_parameter :: "service_math_names \<Rightarrow> nat list \<Rightarrow> event" where
  "service_math_parameter n deps = RegisterManaged
    \<lparr>retained_id=sm_parameter n,retained_owner=RequestLocal (sm_request n),
      retained_dependencies=filter (\<lambda>d. d\<noteq>sm_parameter n) deps,
      retained_read_dependencies=[sm_input n],retained_access_requirements=[],
      retained_payload=sm_parameter n\<rparr>"
definition service_math_statement_code :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_statement_code n bridge code = RegisterManaged
    \<lparr>retained_id=code,retained_owner=WorkspaceShared,
      retained_dependencies=[sm_semantic n,bridge],retained_read_dependencies=[],
      retained_access_requirements=[],retained_payload=code\<rparr>"
definition service_math_bridge :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_bridge n bridge code = RegisterManaged
    \<lparr>retained_id=bridge,retained_owner=WorkspaceShared,
      retained_dependencies=[sm_semantic n,sm_code n,code],retained_read_dependencies=[code],
      retained_access_requirements=[],retained_payload=bridge\<rparr>"
definition service_registration_present :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_registration_present s ev = (case ev of RegisterManaged v \<Rightarrow>
    v\<in>set (retained_values s) \<and> accessible s (retained_id v # retained_dependencies v)
    | _ \<Rightarrow> False)"
definition service_registration_recorded :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_registration_recorded s ev = (case ev of RegisterManaged v \<Rightarrow>
    v \<in> set (retained_values s) | _ \<Rightarrow> False)"
type_synonym service_record_index = "(nat, retained_value list) rbt"
definition service_record_bucket :: "service_record_index \<Rightarrow> nat \<Rightarrow> retained_value list" where
  "service_record_bucket index key = (case RBT.lookup index key of None \<Rightarrow> [] | Some values \<Rightarrow> values)"
definition service_index_record :: "retained_value \<Rightarrow> service_record_index \<Rightarrow> service_record_index" where
  "service_index_record value index = RBT.insert (retained_id value)
    (value # service_record_bucket index (retained_id value)) index"
lemma service_record_bucket_fold:
  "value \<in> set (service_record_bucket (fold service_index_record values index) key) \<longleftrightarrow>
    value \<in> set (service_record_bucket index key) \<or> (value \<in> set values \<and> retained_id value=key)"
  by (induction "values" arbitrary: index)
    (auto simp: service_index_record_def service_record_bucket_def split: if_splits)
lemma service_record_bucket_empty [simp]:
  "value \<in> set (service_record_bucket (fold service_index_record values RBT.empty) (retained_id value))
    \<longleftrightarrow> value \<in> set values"
  by (simp only: service_record_bucket_fold)
    (simp add: service_record_bucket_def)
definition service_recorded_support_groups :: "authority_state \<Rightarrow> event list list \<Rightarrow> nat list list" where
  "service_recorded_support_groups s groups =
    (let index = fold service_index_record (retained_values s) RBT.empty in
      map (List.map_filter (\<lambda>ev. case ev of RegisterManaged value \<Rightarrow>
        (if value \<in> set (service_record_bucket index (retained_id value))
         then Some (retained_id value) else None) | _ \<Rightarrow> None)) groups)"
lemma service_recorded_support_groups_exact:
  "service_recorded_support_groups s groups =
    map (List.map_filter (\<lambda>ev. case ev of RegisterManaged value \<Rightarrow>
      (if value \<in> set (retained_values s) then Some (retained_id value) else None) | _ \<Rightarrow> None)) groups"
  by (simp add: service_recorded_support_groups_def Let_def)
definition service_math_reserve :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> event" where
  "service_math_reserve n prestate fuel deps = ReserveRequest
    \<lparr>request_id=sm_request n,request_generation=sm_semantic n,
      request_code_generation=sm_code n,request_prestate=prestate,
      request_dependencies=deps,allowed_routes=[RefinedExecution],permitted_effects=[],
      request_goals=[\<lparr>goal_id=sm_goal n,goal_interpretation=sm_interpretation n,
        goal_capability=sm_capability n,goal_dependencies=[],
        goal_required=service_math_requirement n deps,goal_output_slot=Some (sm_slot n),
        goal_outcome=AwaitingOutput (sm_slot n)\<rparr>],request_blockers=[],
      request_cancelled=False,request_fuel=fuel,request_session=None,
      request_observation=StateTimeUnused,request_retention_scopes=[RequestLocal (sm_request n)]\<rparr>
    [\<lparr>output_slot_id=sm_slot n,output_owner=sm_request n,output_goal=sm_goal n,
      output_template=sm_template n,output_profile=sm_profile n,
      output_inputs=[KnownInput (sm_parameter n)],output_input_identity=sm_parameter n,
      output_reserved_dependencies=deps,output_origin=PureOrigin\<rparr>]"
definition service_math_execute :: "service_math_names \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_execute n eid cost = ExecutePure
    \<lparr>execution_id=eid,execution_request=sm_request n,execution_slot=sm_slot n,
      execution_cost=\<lparr>cost_profile=sm_profile n,cost_code_generation=sm_code n,
        cost_operation=sm_operation n,cost_step=sm_step n,cost_units=cost\<rparr>,
      execution_inputs=[sm_parameter n]\<rparr>"
definition service_math_specialized :: "service_math_names \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> claim" where
  "service_math_specialized n deps cid target = (service_math_requirement n deps)
    \<lparr>claim_id:=cid,target_id:=target\<rparr>"
definition service_math_evidence :: "service_math_names \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_evidence n deps managed cid target eid = AttachEvidence
    \<lparr>evidence_id=eid,evidence_claim=service_math_specialized n deps cid target,
      evidence_route=RefinedExecution,evidence_managed_dependencies=eid#cid#target#sm_interpretation n#(managed@deps)\<rparr>"
definition service_math_publish :: "service_math_names \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event" where
  "service_math_publish n deps managed cid target eid output execution batch = StageOutput batch
    \<lparr>assigned_slot=sm_slot n,assigned_requirement=service_math_specialized n deps cid target,
      assigned_premise_correspondence=[],assigned_output=output,assigned_lineage=execution,
      assigned_binding=\<lparr>binding_request=sm_request n,binding_goal=sm_goal n,
        binding_claim=service_math_specialized n deps cid target,binding_evidence=eid\<rparr>,
      assigned_dependencies=deps,
      assigned_retained=[\<lparr>retained_id=output,retained_owner=RequestLocal (sm_request n),
        retained_dependencies=managed@deps,
        retained_read_dependencies=[sm_parameter n],retained_access_requirements=[],retained_payload=output\<rparr>]\<rparr> None"
definition service_binding_live :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "service_binding_live s rid eid = (\<exists>b\<in>set (visible_bindings s).
    binding_request b=rid \<and> binding_evidence b=eid \<and> binding_licensed s b)"


definition service_required_math_requests :: "authority_state \<Rightarrow> nat list" where
  "service_required_math_requests s = map request_id
    (filter (\<lambda>r. accessible s (request_id r # request_dependencies r)) (requests s))"
declare [[code drop: new_revoked_objects new_forgotten_objects]]
lemma service_new_revoked_objects_code [code]:
  "new_revoked_objects previous next = indexed_new_ids (revoked_objects previous) (revoked_objects next)"
  by (simp add: new_revoked_objects_def indexed_new_ids_exact)
lemma service_new_forgotten_objects_code [code]:
  "new_forgotten_objects previous next = indexed_new_ids (forgotten_objects previous) (forgotten_objects next)"
  by (simp add: new_forgotten_objects_def indexed_new_ids_exact)

text \<open>Retirement uses the original current authority, before any extra roots
are selected. The ancestor index includes inaccessible records and unions duplicate
IDs, so an inaccessible intermediate cannot hide a surviving consumer.\<close>
definition service_claim_references :: "claim \<Rightarrow> nat list" where
  "service_claim_references c = claim_id c # target_id c # interpretation_id c # semantic_generation c #
    premises c @ dependencies c @ (case executable_generation c of NoExecution \<Rightarrow> [] | ExecutableGeneration n \<Rightarrow> [n])"
definition service_slot_references :: "output_slot \<Rightarrow> nat list" where
  "service_slot_references slot = output_slot_id slot # output_template slot # output_profile slot #
    output_input_identity slot # output_reserved_dependencies slot @
    map (\<lambda>input. case input of KnownInput n \<Rightarrow> n | ReservedOutput n \<Rightarrow> n) (output_inputs slot)"
definition service_request_references :: "authority_state \<Rightarrow> request \<Rightarrow> nat list" where
  "service_request_references s r = request_id r # request_generation r # request_code_generation r #
    request_dependencies r @ concat (map (\<lambda>g. goal_capability g # goal_interpretation g #
      goal_dependencies g @ service_claim_references (goal_required g) @
      (case required_for s r g of None \<Rightarrow> [] | Some c \<Rightarrow> service_claim_references c)) (request_goals r)) @
    concat (map service_slot_references (filter (\<lambda>slot. output_owner slot=request_id r) (output_slots s))) @
    concat (map (\<lambda>a. assigned_output a # assigned_dependencies a @
      service_claim_references (assigned_requirement a) @
      concat (map (\<lambda>v. retained_id v # retained_dependencies v) (assigned_retained a)))
      (filter (\<lambda>a. binding_request (assigned_binding a)=request_id r) (output_assignments s)))"
definition service_forget_protected :: "authority_state \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "service_forget_protected s removed support =
    concat (map (\<lambda>r. filter (\<lambda>n. n \<notin> set removed) (service_request_references s r))
      (filter (\<lambda>r. accessible s (request_id r # request_dependencies r) \<and>
        list_all (\<lambda>n. n \<notin> set removed) (request_id r # request_dependencies r)) (requests s))) @
    concat (map evidence_managed_dependencies
      (filter (\<lambda>e. evidence_accessible s e \<and>
        list_all (\<lambda>n. n \<notin> set removed) (evidence_managed_dependencies e)) (evidence_table s))) @
    map retained_id (filter (\<lambda>v. accessible s [retained_id v] \<and>
      retained_id v \<notin> set removed \<and> retained_id v \<notin> set support \<and>
      (case retained_owner v of RequestLocal rid \<Rightarrow> rid \<notin> set removed \<and>
        list_all (\<lambda>r. request_id r = rid \<longrightarrow>
          list_all (\<lambda>n. n \<notin> set removed) (request_dependencies r)) (requests s)
      | _ \<Rightarrow> True))
      (retained_values s))"
definition service_membership_index :: "nat list \<Rightarrow> effect_seen" where
  "service_membership_index xs = fold (\<lambda>key. RBT.insert key ()) xs RBT.empty"
lemma service_membership_index_lookup [simp]:
  "RBT.lookup (service_membership_index xs) key = None \<longleftrightarrow> key \<notin> set xs"
  by (simp add: service_membership_index_def fold_seen_lookup)
definition service_index_accessible :: "effect_seen \<Rightarrow> nat list \<Rightarrow> bool" where
  "service_index_accessible denied refs = list_all (\<lambda>key. RBT.lookup denied key = None) refs"
lemma service_index_accessible_exact [simp]:
  "service_index_accessible (service_membership_index (revoked_objects s)) refs = accessible s refs"
  by (simp add: service_index_accessible_def accessible_def list_all_iff)
definition service_index_evidence_accessible :: "effect_seen \<Rightarrow> evidence \<Rightarrow> bool" where
  "service_index_evidence_accessible denied e = (
    list_all (\<lambda>d. d \<in> set (evidence_managed_dependencies e))
      (evidence_id e # claim_id (evidence_claim e) # target_id (evidence_claim e) #
       interpretation_id (evidence_claim e) # semantic_generation (evidence_claim e) #
       premises (evidence_claim e) @ dependencies (evidence_claim e)) \<and>
    service_index_accessible denied (evidence_managed_dependencies e))"
lemma service_index_evidence_accessible_exact [simp]:
  "service_index_evidence_accessible (service_membership_index (revoked_objects s)) e = evidence_accessible s e"
  by (simp add: service_index_evidence_accessible_def evidence_accessible_def)
lemma service_unaffected_request_owner [simp]:
  "rid \<notin> request_id ` {r \<in> set rs. \<not> P r} \<longleftrightarrow>
    list_all (\<lambda>r. request_id r = rid \<longrightarrow> P r) rs"
  by (auto simp: list_all_iff)
lemma service_affected_request_index [simp]:
  "RBT.lookup (service_membership_index (map request_id
    (filter (\<lambda>r. \<not> list_all (\<lambda>n. n \<notin> set removed) (request_dependencies r)) (requests s)))) rid = None
    \<longleftrightarrow> list_all (\<lambda>r. request_id r = rid \<longrightarrow>
      list_all (\<lambda>n. n \<notin> set removed) (request_dependencies r)) (requests s)"
  by (auto simp: list_all_iff)
definition service_forget_protected_indexed :: "authority_state \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "service_forget_protected_indexed s removed support =
    (let removed_index = service_membership_index removed;
         support_index = service_membership_index support;
         denied = service_membership_index (revoked_objects s);
         affected = service_membership_index (map request_id (filter (\<lambda>r.
           \<not> list_all (\<lambda>n. RBT.lookup removed_index n = None) (request_dependencies r)) (requests s)))
     in
    concat (map (\<lambda>r. filter (\<lambda>n. RBT.lookup removed_index n = None) (service_request_references s r))
      (filter (\<lambda>r. service_index_accessible denied (request_id r # request_dependencies r) \<and>
        list_all (\<lambda>n. RBT.lookup removed_index n = None) (request_id r # request_dependencies r)) (requests s))) @
    concat (map evidence_managed_dependencies
      (filter (\<lambda>e. service_index_evidence_accessible denied e \<and>
        list_all (\<lambda>n. RBT.lookup removed_index n = None) (evidence_managed_dependencies e)) (evidence_table s))) @
    map retained_id (filter (\<lambda>v. service_index_accessible denied [retained_id v] \<and>
      RBT.lookup removed_index (retained_id v) = None \<and> RBT.lookup support_index (retained_id v) = None \<and>
      (case retained_owner v of RequestLocal rid \<Rightarrow> RBT.lookup removed_index rid = None \<and>
        RBT.lookup affected rid = None
      | _ \<Rightarrow> True))
      (retained_values s)))"
lemma service_forget_protected_indexed_exact:
  "service_forget_protected_indexed s removed support = service_forget_protected s removed support"
  by (simp add: service_forget_protected_indexed_def service_forget_protected_def Let_def
      cong: retention_scope.case_cong)
declare [[code drop: service_forget_protected]]
lemma service_forget_protected_code [code]:
  "service_forget_protected s removed support = service_forget_protected_indexed s removed support"
  by (simp add: service_forget_protected_indexed_exact)

definition service_forget_support_event :: "authority_state \<Rightarrow> nat \<Rightarrow> nat list list \<Rightarrow> event option" where
  "service_forget_support_event s primary groups =
    (case forget_closure (retained_values s) [primary] of None \<Rightarrow> None | Some removed \<Rightarrow>
      (case protected_ancestor_summary (retained_values s)
        (service_forget_protected s removed (concat groups)) of None \<Rightarrow> None | Some summary \<Rightarrow>
          Some (ForgetRoots (primary # concat (filter (\<lambda>roots.
            \<not> protected_ancestors_hit summary roots) groups)))))"

definition service_forget_registered_support_event :: "authority_state \<Rightarrow> nat \<Rightarrow> event list list \<Rightarrow> event option" where
  "service_forget_registered_support_event s primary groups =
    service_forget_support_event s primary (filter (\<lambda>roots. roots\<noteq>[])
      (service_recorded_support_groups s groups))"

lemma service_forget_selected_group_safe:
  assumes summary: "protected_ancestor_summary (retained_values s)
      (service_forget_protected s removed (concat groups)) = Some summary"
    and eligible: "roots \<in> set (filter (\<lambda>roots. \<not> protected_ancestors_hit summary roots) groups)"
  shows "set (dependency_closure (length (retained_values s)) (retained_values s) roots) \<inter>
    set (service_forget_protected s removed (concat groups)) = {}"
  using protected_ancestors_hit_exact[OF summary, of roots] eligible by auto

lemma service_forget_all_selected_groups_safe:
  assumes summary: "protected_ancestor_summary (retained_values s)
      (service_forget_protected s removed (concat groups)) = Some summary"
  shows "set (dependency_closure (length (retained_values s)) (retained_values s)
      (concat (filter (\<lambda>roots. \<not> protected_ancestors_hit summary roots) groups))) \<inter>
    set (service_forget_protected s removed (concat groups)) = {}"
proof -
  have "\<not> protected_ancestors_hit summary
    (concat (filter (\<lambda>roots. \<not> protected_ancestors_hit summary roots) groups))"
    by (auto simp: protected_ancestors_hit_def list_ex_iff)
  then show ?thesis using protected_ancestors_hit_exact[OF summary] by blast
qed

definition service_math_request_matches ::
  "authority_state \<Rightarrow> service_math_names \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> bool" where
  "service_math_request_matches s n deps cost =
    (\<exists>r\<in>set (requests s). request_id r=sm_request n \<and>
      request_generation r=sm_semantic n \<and> request_code_generation r=sm_code n \<and>
      request_dependencies r=deps \<and> request_prestate r\<le>revision s \<and>
      allowed_routes r=[RefinedExecution] \<and> permitted_effects r=[] \<and>
      request_blockers r=[] \<and> request_session r=None \<and>
      request_observation r=StateTimeUnused \<and>
      request_retention_scopes r=[RequestLocal (sm_request n)] \<and>
      (request_fuel r=0 \<or> request_fuel r=cost) \<and>
      map (\<lambda>g. g\<lparr>goal_outcome:=AwaitingOutput (sm_slot n)\<rparr>) (request_goals r) =
        [\<lparr>goal_id=sm_goal n,goal_interpretation=sm_interpretation n,
          goal_capability=sm_capability n,goal_dependencies=[],
          goal_required=service_math_requirement n deps,goal_output_slot=Some (sm_slot n),
          goal_outcome=AwaitingOutput (sm_slot n)\<rparr>] \<and>
      \<lparr>output_slot_id=sm_slot n,output_owner=sm_request n,output_goal=sm_goal n,
        output_template=sm_template n,output_profile=sm_profile n,
        output_inputs=[KnownInput (sm_parameter n)],output_input_identity=sm_parameter n,
        output_reserved_dependencies=deps,output_origin=PureOrigin\<rparr>\<in>set (output_slots s))"
definition service_math_output_matches :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "service_math_output_matches s ev = (case ev of StageOutput batch a None \<Rightarrow>
    (\<forall>old\<in>set (output_assignments s). assigned_slot old=assigned_slot a \<longrightarrow> old=a) \<and>
    (\<forall>b\<in>set (visible_bindings s). binding_evidence b=binding_evidence (assigned_binding a)
      \<longrightarrow> b=assigned_binding a) | _ \<Rightarrow> False)"
definition service_execution_for :: "authority_state \<Rightarrow> nat \<Rightarrow> pure_execution list" where
  "service_execution_for s rid = filter (\<lambda>run. execution_request run=rid) (pure_executions s)"
definition service_restore_supported :: "authority_state \<Rightarrow> bool" where
  "service_restore_supported s = (pending_batch s=None \<and> attempts s=[] \<and>
    source_publications s=[] \<and> acquisition_jobs s=[] \<and> session_views s=[] \<and>
    current_observations s=[] \<and> retention_grants s=[] \<and> consumed_retention_grants s=[] \<and>
    exposure_history s=[] \<and> qualification_eligibility s=[] \<and> spent_domains s=[] \<and>
    qualification_reservations s=[] \<and> qualification_started s=[] \<and>
    qualification_policies s=[] \<and> qualifications s=[] \<and> package_publications s=[] \<and>
    (\<forall>e\<in>set (required_native_evidence s). evidence_route e\<noteq>EvaluationOracle))"

ML_file \<open>metadata_frame.ML\<close>
ML_file \<open>../../isabelle/language/natural/native_language_input.ML\<close>
ML_file \<open>../../isabelle/language/request/native_interpreted_request.ML\<close>
ML_file \<open>../../isabelle/language/emission/refined/native_refined_math_display.ML\<close>
ML_file \<open>../../isabelle/admission/native_authority_descriptor.ML\<close>
ML_file \<open>../../isabelle/admission/recovery/native_recovery_export.ML\<close>
ML_file \<open>native_math_gate.ML\<close>
ML_file \<open>native_math_recovery.ML\<close>
ML_file \<open>native_state_owner.ML\<close>
ML_file \<open>native_service.ML\<close>
end
