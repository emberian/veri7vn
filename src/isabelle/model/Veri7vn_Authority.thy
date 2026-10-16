theory Veri7vn_Authority
  imports Veri7vn_Authority_Events.Authority_Events
begin

ML \<open>Veri7vn_Authority_Compile.reset "core_started"\<close>

definition initial_state :: authority_state where
  "initial_state = \<lparr>revision = 0, authority_epoch = 0, requests = [],
    evidence_table = [], visible_bindings = [], attempts = [], effect_observations = [], source_publications = [], pending_batch = None, issued_batches = [],
    retired_capabilities = [], retired_sources = [], revoked_objects = [],
    forgotten_objects = [], session_generation = 0,
    current_observations = [], session_views = [], output_slots = [], output_assignments = [],
    pure_executions = [], acquisition_jobs = [], retained_values = [], retention_grants = [], consumed_retention_grants = [], exposure_history = [],
    qualification_eligibility = [], spent_domains = [], qualification_reservations = [], qualification_started = [], qualification_policies = [], qualifications = [],
    package_publications = []\<rparr>"

fun accepted :: "outcome \<Rightarrow> bool" where
  "accepted (Accepted c e) = True" | "accepted _ = False"

definition accessible :: "authority_state \<Rightarrow> nat list \<Rightarrow> bool" where
  "accessible s ds \<longleftrightarrow> list_all (\<lambda>d. d \<notin> set (revoked_objects s)) ds"

definition parent_accessible :: "authority_state \<Rightarrow> request \<Rightarrow> bool" where
  "parent_accessible s r \<longleftrightarrow> accessible s (request_id r # request_dependencies r)"

definition new_revoked_objects :: "authority_state \<Rightarrow> authority_state \<Rightarrow> nat list" where
  "new_revoked_objects previous next = filter (\<lambda>objid. objid \<notin> set (revoked_objects previous))
    (remdups (revoked_objects next))"
definition new_forgotten_objects :: "authority_state \<Rightarrow> authority_state \<Rightarrow> nat list" where
  "new_forgotten_objects previous next = filter (\<lambda>objid. objid \<notin> set (forgotten_objects previous))
    (remdups (forgotten_objects next))"

fun same_requirement :: "goal_requirement \<Rightarrow> goal_requirement \<Rightarrow> bool" where
  "same_requirement (ClaimRequirement a) (ClaimRequirement b) = same_target a b" |
  "same_requirement (ArtifactRequirement a) (ArtifactRequirement b) = (a=b)" |
  "same_requirement _ _ = False"
fun requirement_claim :: "goal_requirement \<Rightarrow> claim option" where
  "requirement_claim (ClaimRequirement c) = Some c" |
  "requirement_claim (ArtifactRequirement a) = None"
definition claim_references :: "claim \<Rightarrow> nat list" where
  "claim_references c = claim_id c # target_id c # interpretation_id c # semantic_generation c #
    premises c @ dependencies c @ (case executable_generation c of NoExecution \<Rightarrow> [] | ExecutableGeneration n \<Rightarrow> [n])"
definition artifact_requirement_references :: "artifact_requirement \<Rightarrow> nat list" where
  "artifact_requirement_references a = [artifact_template a,artifact_source a,artifact_revision a,
    artifact_manifest a,artifact_profile a,artifact_setup a,artifact_exports a] @ map (\<lambda>input. case input of KnownInput n \<Rightarrow> n | ReservedOutput n \<Rightarrow> n) (artifact_parents a)"
fun requirement_references :: "goal_requirement \<Rightarrow> nat list" where
  "requirement_references (ClaimRequirement c) = claim_references c" |
  "requirement_references (ArtifactRequirement a) = artifact_requirement_references a"
fun requirement_premises :: "goal_requirement \<Rightarrow> nat list" where
  "requirement_premises (ClaimRequirement c) = premises c" |
  "requirement_premises (ArtifactRequirement a) = []"
definition goal_references :: "subgoal \<Rightarrow> nat list" where
  "goal_references g = goal_id g # goal_generation g # goal_code_generation g # goal_capability g # goal_interpretation g #
    requirement_references (goal_required g) @ (case goal_output_slot g of None \<Rightarrow> [] | Some slot \<Rightarrow> [slot])"
definition child_accessible :: "authority_state \<Rightarrow> subgoal \<Rightarrow> bool" where
  "child_accessible s g \<longleftrightarrow> accessible s (goal_references g)"
fun dependency_goal :: "goal_dependency \<Rightarrow> nat" where
  "dependency_goal (LogicalDependency n) = n" |
  "dependency_goal (ArtifactDependency n) = n"
fun goal_reference :: "subgoal \<Rightarrow> goal_dependency" where
  "goal_reference g = (case goal_required g of ClaimRequirement c \<Rightarrow> LogicalDependency (goal_id g) |
    ArtifactRequirement a \<Rightarrow> ArtifactDependency (goal_id g))"
fun assignment_slot :: "slot_assignment \<Rightarrow> nat" where
  "assignment_slot (ClaimOutput a) = assigned_slot a" |
  "assignment_slot (ArtifactOutput a) = artifact_assigned_slot a"
fun assignment_output :: "slot_assignment \<Rightarrow> nat" where
  "assignment_output (ClaimOutput a) = assigned_output a" |
  "assignment_output (ArtifactOutput a) = artifact_assigned_output a"
fun assignment_dependencies :: "slot_assignment \<Rightarrow> nat list" where
  "assignment_dependencies (ClaimOutput a) = assigned_dependencies a" |
  "assignment_dependencies (ArtifactOutput a) = artifact_assigned_dependencies a"
fun assignment_retained :: "slot_assignment \<Rightarrow> retained_value list" where
  "assignment_retained (ClaimOutput a) = assigned_retained a" |
  "assignment_retained (ArtifactOutput a) = artifact_assigned_retained a"
fun assignment_claim :: "slot_assignment \<Rightarrow> output_assignment option" where
  "assignment_claim (ClaimOutput a) = Some a" |
  "assignment_claim (ArtifactOutput a) = None"
fun assignment_artifact :: "slot_assignment \<Rightarrow> artifact_assignment option" where
  "assignment_artifact (ClaimOutput a) = None" |
  "assignment_artifact (ArtifactOutput a) = Some a"
definition claim_assignments :: "authority_state \<Rightarrow> output_assignment list" where
  "claim_assignments s = List.map_filter assignment_claim (output_assignments s)"
definition artifact_assignments :: "authority_state \<Rightarrow> artifact_assignment list" where
  "artifact_assignments s = List.map_filter assignment_artifact (output_assignments s)"
fun assignment_references :: "slot_assignment \<Rightarrow> nat list" where
  "assignment_references (ClaimOutput a) = binding_request (assigned_binding a) # binding_goal (assigned_binding a) # assigned_slot a # assigned_output a # assigned_dependencies a @
    claim_references (assigned_requirement a) @
    concat (map (\<lambda>v. retained_id v # retained_dependencies v) (assigned_retained a))" |
  "assignment_references (ArtifactOutput a) = artifact_assigned_request a # artifact_assigned_goal a # artifact_assigned_slot a # artifact_assigned_output a # artifact_assigned_generation a # artifact_assigned_dependencies a @
    artifact_requirement_references (artifact_assigned_requirement a) @
    concat (map (\<lambda>v. retained_id v # retained_dependencies v) (artifact_assigned_retained a))"

definition close_retained_dependencies :: "nat list \<Rightarrow> retained_value \<Rightarrow> retained_value" where
  "close_retained_dependencies refs value = value\<lparr>retained_dependencies :=
    retained_dependencies value @ filter (\<lambda>d. d\<notin>set (retained_dependencies value)) (remdups refs)\<rparr>"

definition artifact_owner_references :: "authority_state \<Rightarrow> artifact_assignment \<Rightarrow> nat list option" where
  "artifact_owner_references s a =
    (if artifact_assigned_generation a=0 then None else
      (case filter (\<lambda>r. request_id r=artifact_assigned_request a) (requests s) of [r] \<Rightarrow>
        (case filter (\<lambda>g. goal_id g=artifact_assigned_goal a) (request_goals r) of [g] \<Rightarrow>
          (if goal_output_slot g\<noteq>Some (artifact_assigned_slot a) then None else
            (case goal_required g of ClaimRequirement c \<Rightarrow> None | ArtifactRequirement required \<Rightarrow>
              (case filter (\<lambda>x. output_slot_id x=artifact_assigned_slot a) (output_slots s) of [x] \<Rightarrow>
                (if output_owner x=request_id r \<and> output_goal x=goal_id g then
                  Some ([artifact_assigned_request a,artifact_assigned_goal a,
                    artifact_assigned_slot a,artifact_assigned_generation a] @
                    goal_references g @ request_dependencies r)
                 else None) | _ \<Rightarrow> None)))
         | _ \<Rightarrow> None)
       | _ \<Rightarrow> None))"

definition artifact_expected_retained :: "authority_state \<Rightarrow> artifact_assignment \<Rightarrow> retained_value list option" where
  "artifact_expected_retained s a = map_option
    (\<lambda>refs. map (close_retained_dependencies refs) (artifact_assigned_retained a)) (artifact_owner_references s a)"

fun goal_satisfied :: "subgoal \<Rightarrow> goal_dependency option" where
  "goal_satisfied g = (case (goal_required g,goal_outcome g) of
    (ClaimRequirement c,Accepted actual e) \<Rightarrow> Some (LogicalDependency (goal_id g)) |
    (ArtifactRequirement a,ArtifactReady objid) \<Rightarrow> Some (ArtifactDependency (goal_id g)) | _ \<Rightarrow> None)"
fun resolved_inputs :: "authority_state \<Rightarrow> slot_input list \<Rightarrow> nat list option" where
  "resolved_inputs s [] = Some []" |
  "resolved_inputs s (input # rest) = (case (input, resolved_inputs s rest) of
    (KnownInput n, Some ns) \<Rightarrow> Some (n # ns) |
    (ReservedOutput slot, Some ns) \<Rightarrow>
      map_option (\<lambda>a. assignment_output a # ns) (find (\<lambda>a. assignment_slot a = slot) (output_assignments s)) |
    _ \<Rightarrow> None)"


definition resolved_artifact_requirement :: "authority_state \<Rightarrow> artifact_requirement \<Rightarrow> artifact_requirement option" where
  "resolved_artifact_requirement s a = map_option (\<lambda>parents. a\<lparr>artifact_parents:=map KnownInput parents\<rparr>)
    (resolved_inputs s (artifact_parents a))"

definition goal_ready :: "request \<Rightarrow> subgoal \<Rightarrow> bool" where
  "goal_ready r g \<longleftrightarrow> list_all (\<lambda>d. \<exists>h \<in> set (request_goals r).
    goal_satisfied h = Some d) (goal_dependencies g)"

fun blocks :: "nat \<Rightarrow> subgoal \<Rightarrow> blocker_scope \<Rightarrow> bool" where
  "blocks r g (RequestScope n) = (r = n)" |
  "blocks r g (InterpretationScope n) = (goal_interpretation g = n)" |
  "blocks r g (PremiseScope n) = (n \<in> set (requirement_premises (goal_required g)))" |
  "blocks r g (CapabilityScope n) = (goal_capability g = n)"

definition unblocked :: "request \<Rightarrow> subgoal \<Rightarrow> bool" where
  "unblocked r g \<longleftrightarrow> list_all (\<lambda>b. \<not> blocks (request_id r) g (blocked_scope b))
    (request_blockers r)"

text \<open>Actual NoExecution means no executable dependency; NoExecution in the
requested target means no required executable provenance. It does not assert that
execution did not occur. Exact actual provenance is retained in the accepted claim.
Real request pins are authenticated native-registry inputs, never a fake zero ID.\<close>
definition execution_fits :: "subgoal \<Rightarrow> claim \<Rightarrow> claim \<Rightarrow> assurance_route \<Rightarrow> bool" where
  "execution_fits goal required actual route \<longleftrightarrow>
    (case executable_generation required of NoExecution \<Rightarrow> True |
      ExecutableGeneration g \<Rightarrow> executable_generation actual = ExecutableGeneration g) \<and>
    (case route of KernelConsequence \<Rightarrow>
      (case executable_generation actual of NoExecution \<Rightarrow> True |
        ExecutableGeneration g \<Rightarrow> g = goal_code_generation goal) |
      _ \<Rightarrow> executable_generation actual = ExecutableGeneration (goal_code_generation goal))"

definition observation_fresh :: "authority_state \<Rightarrow> observation_requirement \<Rightarrow> bool" where
  "observation_fresh s required \<longleftrightarrow> (case required of StateTimeUnused \<Rightarrow> True |
    _ \<Rightarrow> (\<exists>current \<in> set (current_observations s).
      accessible s (observed_session current # map fst (observed_reads current)) \<and> authority_fresh current required))"
definition request_fresh :: "authority_state \<Rightarrow> request \<Rightarrow> bool" where
  "request_fresh s r \<longleftrightarrow>
    (case request_session r of None \<Rightarrow> True | Some sid \<Rightarrow> accessible s [sid]) \<and>
    (case request_observation r of RequireAccess observed window \<Rightarrow> False |
      _ \<Rightarrow> observation_fresh s (request_observation r))"

definition required_for :: "authority_state \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> claim option" where
  "required_for s r g = (case goal_required g of ArtifactRequirement a \<Rightarrow> None |
    ClaimRequirement original \<Rightarrow> (case goal_output_slot g of None \<Rightarrow> Some original |
      Some slot \<Rightarrow> (case find (\<lambda>x. output_slot_id x=slot \<and>
        output_owner x=request_id r \<and> output_goal x=goal_id g) (output_slots s) of
        None \<Rightarrow> None | Some reserved \<Rightarrow>
          map_option assigned_requirement (find (\<lambda>a. assigned_slot a=slot) (claim_assignments s)))))"

text \<open>The complete managed closure is supplied by native admission, including
actual target, hypotheses, private inputs and authoritative generation edges.
Neither the recovery query nor a caller can infer that closure from labels.\<close>
definition evidence_accessible :: "authority_state \<Rightarrow> evidence \<Rightarrow> bool" where
  "evidence_accessible s e \<longleftrightarrow>
    list_all (\<lambda>d. d \<in> set (evidence_managed_dependencies e))
      (evidence_id e # claim_references (evidence_claim e)) \<and>
    accessible s (evidence_managed_dependencies e)"

definition required_native_evidence :: "authority_state \<Rightarrow> evidence list" where
  "required_native_evidence s = filter (evidence_accessible s) (evidence_table s)"

definition scope_preserved :: "claim \<Rightarrow> claim \<Rightarrow> (nat \<times> nat) list \<Rightarrow> bool" where
  "scope_preserved original specialized correspondence \<longleftrightarrow>
    same_target (original\<lparr>target_id := target_id specialized,
      dependencies := dependencies specialized, premises := premises specialized\<rparr>) specialized \<and>
    executable_generation original = executable_generation specialized \<and>
    map fst correspondence = premises original \<and>
    set (map snd correspondence) = set (premises specialized) \<and>
    list_all (\<lambda>d. d \<in> set (dependencies specialized)) (dependencies original)"

fun declared_slot_input :: "nat list \<Rightarrow> slot_input \<Rightarrow> bool" where
  "declared_slot_input seen (KnownInput n) = True" |
  "declared_slot_input seen (ReservedOutput n) = (n \<in> set seen)"
fun ordered_slots :: "nat list \<Rightarrow> output_slot list \<Rightarrow> bool" where
  "ordered_slots seen [] = True" |
  "ordered_slots seen (x # xs) = (output_slot_id x \<notin> set seen \<and>
    list_all (declared_slot_input seen) (output_inputs x) \<and>
    ordered_slots (output_slot_id x # seen) xs)"
definition reservations_match :: "request \<Rightarrow> output_slot list \<Rightarrow> bool" where
  "reservations_match r xs \<longleftrightarrow> ordered_slots [] xs \<and>
    list_all (\<lambda>x. output_owner x = request_id r \<and>
      KnownInput (output_input_identity x) \<in> set (output_inputs x) \<and>
      (\<exists>g \<in> set (request_goals r). goal_id g = output_goal x \<and>
        goal_output_slot g = Some (output_slot_id x) \<and>
        (case goal_required g of ClaimRequirement c \<Rightarrow> True | ArtifactRequirement a \<Rightarrow>
          output_origin x=PureOrigin \<and> output_template x=artifact_template a \<and>
          output_profile x=artifact_profile a \<and>
          list_all (\<lambda>parent. parent\<in>set (output_inputs x)) (artifact_parents a)) \<and>
        list_all (\<lambda>input. case input of KnownInput n \<Rightarrow> True | ReservedOutput parent \<Rightarrow>
          (\<exists>p \<in> set xs. output_slot_id p = parent \<and> (\<exists>h\<in>set (request_goals r). goal_id h=output_goal p \<and> goal_reference h \<in> set (goal_dependencies g))))
          (output_inputs x))) xs \<and>
    list_all (\<lambda>g. case goal_output_slot g of None \<Rightarrow> True | Some n \<Rightarrow>
      (\<exists>x \<in> set xs. output_slot_id x = n \<and> output_goal x = goal_id g)) (request_goals r)"

definition operation_chargeable :: "request \<Rightarrow> operation_cost \<Rightarrow> bool" where
  "operation_chargeable r cost \<longleftrightarrow> cost_units cost > 0 \<and>
    cost_units cost \<le> request_fuel r \<and> cost_code_generation cost = request_code_generation r"
definition goal_chargeable :: "request \<Rightarrow> subgoal \<Rightarrow> operation_cost \<Rightarrow> bool" where
  "goal_chargeable r g cost \<longleftrightarrow> cost_units cost > 0 \<and>
    cost_units cost \<le> request_fuel r \<and> cost_code_generation cost = goal_code_generation g"
definition legacy_single_goal :: "request \<Rightarrow> bool" where
  "legacy_single_goal r \<longleftrightarrow> (case request_goals r of [g] \<Rightarrow>
    goal_generation g = request_generation r \<and> goal_code_generation g = request_code_generation r | _ \<Rightarrow> False)"
definition charge_request :: "nat \<Rightarrow> operation_cost \<Rightarrow> authority_state \<Rightarrow> authority_state" where
  "charge_request rid cost s = s\<lparr>requests := map (\<lambda>r. if request_id r = rid then
    r\<lparr>request_fuel := request_fuel r - cost_units cost\<rparr> else r) (requests s)\<rparr>"

definition licensed :: "authority_state \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> claim \<Rightarrow> nat \<Rightarrow> bool" where
  "licensed s r g c eid \<longleftrightarrow>
    (case goal_required g of ClaimRequirement original \<Rightarrow> True | ArtifactRequirement required \<Rightarrow> False) \<and>
    request_fresh s r \<and> parent_accessible s r \<and> interpretation_id c = goal_interpretation g \<and>
    semantic_generation c = goal_generation g \<and>
    goal_capability g \<in> set (dependencies c) \<and>
    list_all (\<lambda>d. d \<in> set (dependencies c)) (request_dependencies r) \<and>
    accessible s (request_dependencies r @ dependencies c) \<and> child_accessible s g \<and>
    (case required_for s r g of None \<Rightarrow> False | Some required \<Rightarrow>
      same_target c required \<and> (\<exists>e \<in> set (evidence_table s). evidence_id e = eid \<and>
        evidence_claim e = c \<and> evidence_route e \<in> set (allowed_routes r) \<and>
        evidence_accessible s e \<and> execution_fits g required c (evidence_route e)))"

text \<open>Request goals are supplied in topological order. The executable check
rejects dangling references and cycles rather than trusting an elaborator flag.\<close>
fun ordered_goals :: "nat list \<Rightarrow> subgoal list \<Rightarrow> bool" where
  "ordered_goals seen [] = True" |
  "ordered_goals seen (g # gs) = (goal_id g \<notin> set seen \<and>
    list_all (\<lambda>d. dependency_goal d \<in> set seen) (goal_dependencies g) \<and>
    ordered_goals (goal_id g # seen) gs)"

definition artifact_accessible :: "authority_state \<Rightarrow> artifact_assignment \<Rightarrow> bool" where
  "artifact_accessible s a \<longleftrightarrow>
    artifact_expected_retained s a=Some (artifact_assigned_retained a) \<and>
    accessible s (assignment_references (ArtifactOutput a)) \<and>
    (\<exists>v\<in>set (retained_values s). retained_id v = artifact_assigned_output a \<and>
      list_all (\<lambda>d. d \<in> set (retained_dependencies v))
        (artifact_assigned_generation a # filter (\<lambda>d. d \<noteq> artifact_assigned_output a) (artifact_assigned_dependencies a)) \<and>
      list_all (observation_fresh s) (retained_access_requirements v))"
definition required_native_artifacts :: "authority_state \<Rightarrow> artifact_assignment list" where
  "required_native_artifacts s = filter (artifact_accessible s) (artifact_assignments s)"
definition required_native_build_requests :: "authority_state \<Rightarrow> request list" where
  "required_native_build_requests s = filter (\<lambda>r. accessible s (request_id r # request_dependencies r) \<and>
    (\<exists>g\<in>set (request_goals r). goal_output_slot g\<noteq>None \<and> child_accessible s g \<and>
      (case goal_required g of ArtifactRequirement a \<Rightarrow> True | ClaimRequirement c \<Rightarrow> False))) (requests s)"
definition required_native_children :: "authority_state \<Rightarrow> (request \<times> subgoal) list" where
  "required_native_children s = concat (map (\<lambda>r. map (Pair r)
      (filter (\<lambda>g. goal_output_slot g\<noteq>None \<and> child_accessible s g) (request_goals r)))
    (filter (\<lambda>r. accessible s (request_id r # request_dependencies r)) (requests s)))"
definition artifact_licensed :: "authority_state \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> nat \<Rightarrow> bool" where
  "artifact_licensed s r g objid \<longleftrightarrow> \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and> child_accessible s g \<and>
    (case goal_required g of ClaimRequirement c \<Rightarrow> False | ArtifactRequirement required \<Rightarrow>
      (\<exists>a\<in>set (artifact_assignments s). artifact_assigned_request a=request_id r \<and>
      artifact_assigned_goal a=goal_id g \<and> goal_output_slot g=Some (artifact_assigned_slot a) \<and>
      artifact_assigned_output a=objid \<and> resolved_artifact_requirement s required=Some (artifact_assigned_requirement a) \<and>
      artifact_accessible s a))"
fun current_goal :: "authority_state \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> goal_dependency option" where
  "current_goal s r g = (case (goal_required g,goal_outcome g) of
    (ClaimRequirement required,Accepted c e) \<Rightarrow>
      (if licensed s r g c e then Some (LogicalDependency (goal_id g)) else None) |
    (ArtifactRequirement required,ArtifactReady objid) \<Rightarrow>
      (if artifact_licensed s r g objid then Some (ArtifactDependency (goal_id g)) else None) | _ \<Rightarrow> None)"
fun live_goals :: "authority_state \<Rightarrow> request \<Rightarrow> goal_dependency list \<Rightarrow>
    subgoal list \<Rightarrow> goal_dependency list" where
  "live_goals s r available [] = available" |
  "live_goals s r available (g # gs) = live_goals s r
    (if list_all (\<lambda>d. d \<in> set available) (goal_dependencies g) \<and> unblocked r g
     then (case current_goal s r g of None \<Rightarrow> available | Some d \<Rightarrow> d # available)
     else available) gs"
definition goal_ready_live :: "authority_state \<Rightarrow> request \<Rightarrow> subgoal \<Rightarrow> bool" where
  "goal_ready_live s r g \<longleftrightarrow> ordered_goals [] (request_goals r) \<and>
    list_all (\<lambda>d. d \<in> set (live_goals s r [] (request_goals r))) (goal_dependencies g)"

definition binding_licensed :: "authority_state \<Rightarrow> binding \<Rightarrow> bool" where
  "binding_licensed s b \<longleftrightarrow> (\<exists>r \<in> set (requests s). \<exists>g \<in> set (request_goals r).
    request_id r = binding_request b \<and> goal_id g = binding_goal b \<and>
    \<not> request_cancelled r \<and> goal_ready_live s r g \<and> unblocked r g \<and>
    goal_outcome g = Accepted (binding_claim b) (binding_evidence b) \<and>
    licensed s r g (binding_claim b) (binding_evidence b))"

definition observation_permitted :: "authority_state \<Rightarrow> source_publication \<Rightarrow> bool" where
  "observation_permitted s p \<longleftrightarrow>
    source_binding_id p \<noteq> snapshot_id p \<and>
    source_binding_id p \<notin> set (retired_sources s) \<and>
    source_binding_id p \<in> set (dependencies (binding_claim (observed_binding p))) \<and>
    snapshot_id p \<in> set (dependencies (binding_claim (observed_binding p))) \<and>
    claim_kind (binding_claim (observed_binding p)) = SourceObservation \<and>
    (\<exists>a \<in> set (attempts s). attempt_id (attempt_intent a) = observation_attempt p \<and>
      attempt_state a = Confirmed \<and>
      source_binding_id p \<in> set (attempt_sources (attempt_intent a)) \<and>
      attempt_request (attempt_intent a) = binding_request (observed_binding p) \<and>
      attempt_job (attempt_intent a) = observation_job p) \<and>
    (case observation_job p of None \<Rightarrow> True | Some (objid, incarnation) \<Rightarrow>
      (\<exists>j \<in> set (acquisition_jobs s). job_id j = objid \<and>
        job_owner j = binding_request (observed_binding p) \<and>
        job_source j = source_binding_id p \<and> job_completion_current incarnation j)) \<and>
    binding_licensed s (observed_binding p)"

text \<open>Retirement prevents NEW invocation/start. It does not revoke retained pins of
already running pure computations. Source retirement additionally blocks acquisition-store updates; source-relative
claims about retained snapshots remain usable.\<close>
definition effect_current_context :: "authority_state \<Rightarrow> effect_intent \<Rightarrow> bool" where
  "effect_current_context s i \<longleftrightarrow>
    (case filter (\<lambda>r. request_id r=attempt_request i) (requests s) of [r] \<Rightarrow>
      \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
      legacy_single_goal r \<and>
      (case request_goals r of [g] \<Rightarrow> goal_outcome g=NeedsInput [] \<and>
        goal_ready_live s r g \<and> unblocked r g \<and> child_accessible s g \<and>
        goal_capability g=attempt_capability i \<and>
        cost_code_generation (attempt_cost i)=goal_code_generation g | _ \<Rightarrow> False) \<and>
      attempt_target i\<in>set (permitted_effects r) \<and>
      attempt_capability i\<notin>set (retired_capabilities s) \<and>
      list_all (\<lambda>d. d\<notin>set (retired_sources s)) (attempt_sources i) \<and>
      accessible s (attempt_dependencies i @ attempt_sources i @
        [attempt_target i,attempt_capability i,cost_profile (attempt_cost i),
         cost_operation (attempt_cost i),cost_code_generation (attempt_cost i),cost_step (attempt_cost i)]) \<and>
      (case attempt_job i of None \<Rightarrow> True | Some (objid,incarnation) \<Rightarrow>
        (case filter (\<lambda>j. job_id j=objid) (acquisition_jobs s) of [j] \<Rightarrow>
          job_owner j=request_id r \<and> job_completion_current incarnation j \<and>
          job_source j\<in>set (attempt_sources i) \<and> job_capability j=attempt_capability i
         | _ \<Rightarrow> False))
     | _ \<Rightarrow> False)"

definition intent_permitted :: "authority_state \<Rightarrow> effect_intent \<Rightarrow> bool" where
  "intent_permitted s i \<longleftrightarrow> effect_current_context s i \<and> (\<exists>r \<in> set (requests s).
    request_id r = attempt_request i \<and> \<not> request_cancelled r \<and>
    request_fresh s r \<and> parent_accessible s r \<and> legacy_single_goal r \<and> operation_chargeable r (attempt_cost i) \<and>
    (case attempt_job i of None \<Rightarrow> True | Some (objid, incarnation) \<Rightarrow>
      (\<exists>j \<in> set (acquisition_jobs s). job_id j = objid \<and> job_owner j = request_id r \<and>
        job_completion_current incarnation j \<and> job_source j \<in> set (attempt_sources i) \<and>
        job_capability j = attempt_capability i \<and>
        cost_units (attempt_cost i) \<le> fuel_remaining (job_budget j))) \<and>
    attempt_target i \<in> set (permitted_effects r) \<and>
    attempt_prestate i = revision s \<and> request_prestate r = attempt_prestate i \<and>
    attempt_capability i \<notin> set (retired_capabilities s) \<and>
    list_all (\<lambda>d. d \<notin> set (retired_sources s)) (attempt_sources i) \<and>
    accessible s (request_dependencies r @ attempt_dependencies i @
      attempt_sources i @ [attempt_capability i, attempt_target i]))"

definition charge_intent :: "effect_intent \<Rightarrow> authority_state \<Rightarrow> authority_state" where
  "charge_intent i s = (charge_request (attempt_request i) (attempt_cost i) s)\<lparr>
    acquisition_jobs := map (\<lambda>j. if attempt_job i = Some (job_id j, job_incarnation j)
      then j\<lparr>job_budget := (job_budget j)\<lparr>fuel_remaining :=
        fuel_remaining (job_budget j) - cost_units (attempt_cost i)\<rparr>\<rparr> else j)
      (acquisition_jobs s)\<rparr>"

definition output_preview :: "authority_state \<Rightarrow> output_assignment \<Rightarrow> authority_state" where
  "output_preview s a = (let b = assigned_binding a in
    s\<lparr>output_assignments := output_assignments s @ [ClaimOutput a],
      retained_values := retained_values s @ assigned_retained a,
      requests := map (\<lambda>r. if request_id r = binding_request b then
        r\<lparr>request_goals := map (\<lambda>g. if goal_id g = binding_goal b then
          g\<lparr>goal_outcome := Accepted (binding_claim b) (binding_evidence b)\<rparr> else g)
          (request_goals r)\<rparr> else r) (requests s)\<rparr>)"

definition artifact_preview :: "authority_state \<Rightarrow> artifact_assignment \<Rightarrow> authority_state" where
  "artifact_preview s a = (if artifact_expected_retained s a=Some (artifact_assigned_retained a) then
    s\<lparr>output_assignments:=output_assignments s @ [ArtifactOutput a],
    retained_values:=retained_values s @ artifact_assigned_retained a,
    requests:=map (\<lambda>r. if request_id r=artifact_assigned_request a then
      r\<lparr>request_goals:=map (\<lambda>g. if goal_id g=artifact_assigned_goal a then
        g\<lparr>goal_outcome:=ArtifactReady (artifact_assigned_output a)\<rparr> else g) (request_goals r)\<rparr> else r) (requests s)\<rparr> else s)"

definition retention_flows :: "authority_state \<Rightarrow> retention_scope \<Rightarrow> retention_scope \<Rightarrow> bool" where
  "retention_flows s source destination \<longleftrightarrow> source = WorkspaceShared \<or> source = destination \<or>
    (case (source, destination) of (SessionLocal sid, RequestLocal rid) \<Rightarrow>
      (\<exists>r \<in> set (requests s). request_id r = rid \<and> request_session r = Some sid) | _ \<Rightarrow> False)"
definition managed_registration :: "authority_state \<Rightarrow> retained_value \<Rightarrow> bool" where
  "managed_registration s v \<longleftrightarrow> accessible s (retained_id v # retained_dependencies v) \<and>
    (\<forall>x \<in> set (retained_values s). retained_id x \<noteq> retained_id v) \<and>
    set (retained_read_dependencies v) \<subseteq> set (retained_dependencies v) \<and>
    list_all (observation_fresh s) (retained_access_requirements v) \<and>
    list_all (\<lambda>d. \<exists>x \<in> set (retained_values s). retained_id x = d \<and>
      retention_flows s (retained_owner x) (retained_owner v) \<and>
      accessible s (retained_id x # retained_dependencies x) \<and>
      list_all (observation_fresh s) (retained_access_requirements x) \<and>
      set (retained_access_requirements x) \<subseteq> set (retained_access_requirements v)) (retained_read_dependencies v)"
fun registrations_permitted :: "authority_state \<Rightarrow> retained_value list \<Rightarrow> bool" where
  "registrations_permitted s [] = True" |
  "registrations_permitted s (v # vs) = (managed_registration s v \<and>
    registrations_permitted (s\<lparr>retained_values := retained_values s @ [v]\<rparr>) vs)"
text \<open>Effect responses are retained source material, not propositions. The fixed
native producer supplies the response identifier after checking the actual receipt,
protocol, source encoding and ownership. This function derives the only permitted
retained row from the original attempt and its unique owning child.\<close>
definition effect_observation_retained :: "authority_state \<Rightarrow> effect_observation \<Rightarrow> retained_value option" where
  "effect_observation_retained s observation =
    (case filter (\<lambda>a. attempt_id (attempt_intent a)=effect_observation_attempt observation) (attempts s) of [a] \<Rightarrow>
      (let i=attempt_intent a in
       case filter (\<lambda>r. request_id r=attempt_request i) (requests s) of [r] \<Rightarrow>
        (case request_goals r of [g] \<Rightarrow>
          (let inputs=remdups (attempt_sources i @ attempt_dependencies i);
               reads=filter (\<lambda>d. \<exists>v\<in>set (retained_values s). retained_id v=d) inputs;
               values=filter (\<lambda>v. retained_id v\<in>set reads) (retained_values s);
               refs=attempt_id i # request_id r # goal_references g @ request_dependencies r @ inputs @
                 [attempt_target i,attempt_capability i,cost_profile (attempt_cost i),
                  cost_operation (attempt_cost i),cost_code_generation (attempt_cost i),cost_step (attempt_cost i)]
           in if effect_observation_source observation\<in>set refs then None else
             Some \<lparr>retained_id=effect_observation_source observation,
             retained_owner=RequestLocal (request_id r),
             retained_dependencies=remdups (effect_observation_source observation # refs),
             retained_read_dependencies=reads,
             retained_access_requirements=remdups (request_observation r # concat (map retained_access_requirements values)),
             retained_payload=effect_observation_source observation\<rparr>)
         | _ \<Rightarrow> None)
        | _ \<Rightarrow> None)
     | _ \<Rightarrow> None)"

definition effect_observation_permitted :: "authority_state \<Rightarrow> effect_observation \<Rightarrow> bool" where
  "effect_observation_permitted s observation \<longleftrightarrow>
    effect_observation_source observation>0 \<and>
    (effect_observation_status observation=Confirmed \<or> effect_observation_status observation=EffectFailed) \<and>
    (\<forall>old\<in>set (effect_observations s).
      effect_observation_attempt old\<noteq>effect_observation_attempt observation \<and>
      effect_observation_source old\<noteq>effect_observation_source observation) \<and>
    (case filter (\<lambda>a. attempt_id (attempt_intent a)=effect_observation_attempt observation) (attempts s) of [a] \<Rightarrow>
      (attempt_state a=Running \<or> attempt_state a=Unknown) \<and>
      effect_current_context s (attempt_intent a) \<and>
      (case effect_observation_retained s observation of None \<Rightarrow> False | Some value \<Rightarrow>
        managed_registration s value)
     | _ \<Rightarrow> False)"

definition effect_observation_preview :: "authority_state \<Rightarrow> effect_observation \<Rightarrow> authority_state" where
  "effect_observation_preview s observation =
    (if effect_observation_permitted s observation then
      (case effect_observation_retained s observation of None \<Rightarrow> s | Some value \<Rightarrow>
        s\<lparr>effect_observations:=effect_observations s @ [observation],
          retained_values:=retained_values s @ [value],
          attempts:=map (\<lambda>a. if attempt_id (attempt_intent a)=effect_observation_attempt observation
            then a\<lparr>attempt_state:=effect_observation_status observation\<rparr> else a) (attempts s)\<rparr>)
     else s)"

definition effect_observation_accessible :: "authority_state \<Rightarrow> effect_observation \<Rightarrow> bool" where
  "effect_observation_accessible s observation \<longleftrightarrow>
    (effect_observation_status observation=Confirmed \<or> effect_observation_status observation=EffectFailed) \<and>
    (case filter (\<lambda>a. attempt_id (attempt_intent a)=effect_observation_attempt observation) (attempts s) of [a] \<Rightarrow>
      attempt_state a=effect_observation_status observation \<and>
      (case effect_observation_retained s observation of None \<Rightarrow> False | Some value \<Rightarrow>
        value\<in>set (retained_values s) \<and> accessible s (retained_id value # retained_dependencies value))
     | _ \<Rightarrow> False)"

definition required_native_effect_observations :: "authority_state \<Rightarrow> effect_observation list" where
  "required_native_effect_observations s = filter (effect_observation_accessible s) (effect_observations s)"

definition binding_managed_dependencies :: "authority_state \<Rightarrow> binding \<Rightarrow> nat list" where
  "binding_managed_dependencies s b = dependencies (binding_claim b) @
    (case find (\<lambda>e. evidence_id e = binding_evidence b \<and> evidence_claim e = binding_claim b)
      (evidence_table s) of None \<Rightarrow> [] | Some e \<Rightarrow> evidence_managed_dependencies e)"

definition output_retention_permitted :: "authority_state \<Rightarrow> request \<Rightarrow> output_assignment \<Rightarrow> bool" where
  "output_retention_permitted s r a \<longleftrightarrow>
    distinct (map retained_id (assigned_retained a)) \<and>
    assigned_output a \<in> set (map retained_id (assigned_retained a)) \<and>
    registrations_permitted s (assigned_retained a) \<and>
    list_all (\<lambda>v. retained_owner v \<in> set (request_retention_scopes r) \<and>
      (retained_id v = assigned_output a \<longrightarrow>
        list_all (\<lambda>d. d \<in> set (retained_dependencies v))
          (binding_managed_dependencies s (assigned_binding a))) \<and>
      list_all (\<lambda>d. d \<in> set (retained_dependencies v)) (filter (\<lambda>d. d \<notin> set (map retained_id (assigned_retained a))) (assigned_dependencies a)))
      (assigned_retained a)"

definition qualification_child_current :: "authority_state \<Rightarrow> qualification_reservation \<Rightarrow> bool" where
  "qualification_child_current s q \<longleftrightarrow>
    accessible s (reservation_candidate q # reservation_run_spec q # reservation_domain q #
      reservation_policy q # reservation_dependencies q @
      (case reservation_baseline q of None \<Rightarrow> [] | Some baseline_id \<Rightarrow> [baseline_id])) \<and>
    (\<exists>r\<in>set (requests s).
    request_id r=reservation_owner q \<and> \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
    (\<exists>g\<in>set (request_goals r). goal_id g=reservation_goal q \<and>
      unblocked r g \<and> goal_ready_live s r g \<and> child_accessible s g \<and>
      goal_capability g \<notin>set (retired_capabilities s) \<and>
      cost_code_generation (reservation_cost q)=goal_code_generation g \<and>
      (case goal_required g of ClaimRequirement c \<Rightarrow> claim_kind c=TestObservation | ArtifactRequirement a \<Rightarrow> False) \<and>
      (\<exists>x\<in>set (output_slots s). output_owner x=request_id r \<and> output_goal x=goal_id g \<and>
        goal_output_slot g=Some (output_slot_id x) \<and>
        output_origin x=QualificationOrigin (reservation_attempt q) \<and>
        output_profile x=cost_profile (reservation_cost q))))"
definition qualification_slot_open :: "authority_state \<Rightarrow> qualification_reservation \<Rightarrow> bool" where
  "qualification_slot_open s q \<longleftrightarrow> (\<exists>x\<in>set (output_slots s).
    output_owner x=reservation_owner q \<and> output_goal x=reservation_goal q \<and>
    output_origin x=QualificationOrigin (reservation_attempt q) \<and>
    (\<forall>a\<in>set (output_assignments s). assignment_slot a \<noteq> output_slot_id x))"

definition claim_output_permitted :: "authority_state \<Rightarrow> output_assignment \<Rightarrow> source_publication option \<Rightarrow> bool" where
  "claim_output_permitted s a publication \<longleftrightarrow>
    (\<forall>old \<in> set (output_assignments s). assignment_slot old \<noteq> assigned_slot a) \<and>
    (\<exists>x \<in> set (output_slots s). output_slot_id x = assigned_slot a \<and>
      binding_request (assigned_binding a) = output_owner x \<and>
      binding_goal (assigned_binding a) = output_goal x \<and>
      accessible s (output_template x # output_profile x # output_input_identity x #
        output_reserved_dependencies x @ assigned_dependencies a) \<and>
      list_all (\<lambda>input. case input of KnownInput n \<Rightarrow> n \<in> set (assigned_dependencies a) \<and>
          (\<exists>v \<in> set (retained_values s). retained_id v = n \<and>
            retention_flows s (retained_owner v) (RequestLocal (output_owner x)) \<and>
            accessible s (retained_dependencies v) \<and>
            list_all (observation_fresh s) (retained_access_requirements v)) |
        ReservedOutput d \<Rightarrow> (\<exists>bound \<in> set (output_assignments s). assignment_slot bound = d \<and>
          list_all (\<lambda>dep. dep \<in> set (assigned_dependencies a)) (assignment_dependencies bound) \<and>
          (\<exists>v \<in> set (retained_values s). retained_id v = assignment_output bound \<and>
            retention_flows s (retained_owner v) (RequestLocal (output_owner x)) \<and>
            accessible s (retained_dependencies v) \<and>
            list_all (observation_fresh s) (retained_access_requirements v)))) (output_inputs x) \<and>
      assigned_output a \<in> set (assigned_dependencies a) \<and>
      list_all (\<lambda>d. d \<in> set (assigned_dependencies a)) (output_reserved_dependencies x) \<and>
      list_all (\<lambda>d. d \<in> set (dependencies (assigned_requirement a))) (assigned_dependencies a) \<and>
      (\<exists>r \<in> set (requests s). request_id r = output_owner x \<and>
        \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
        output_retention_permitted s r a \<and>
        list_all (\<lambda>v. retained_id v = assigned_output a \<longrightarrow>
          list_all (\<lambda>input. case input of KnownInput n \<Rightarrow> n \<in> set (retained_read_dependencies v) |
            ReservedOutput parent \<Rightarrow> (\<exists>bound \<in> set (output_assignments s).
              assignment_slot bound = parent \<and> assignment_output bound \<in> set (retained_read_dependencies v)))
            (output_inputs x)) (assigned_retained a) \<and>
        (\<exists>g \<in> set (request_goals r). goal_id g = output_goal x \<and>
          goal_output_slot g = Some (output_slot_id x) \<and>
          (case goal_required g of ClaimRequirement original \<Rightarrow> scope_preserved original (assigned_requirement a) (assigned_premise_correspondence a) | ArtifactRequirement required \<Rightarrow> False) \<and>
          list_all (\<lambda>d. d \<in> set (assigned_dependencies a)) (requirement_premises (goal_required g)))) \<and>
      (case output_origin x of PureOrigin \<Rightarrow> publication = None \<and>
        (\<exists>run \<in> set (pure_executions s). execution_id run = assigned_lineage a \<and>
          execution_request run = output_owner x \<and> execution_slot run = output_slot_id x \<and>
          cost_profile (execution_cost run) = output_profile x) |
       ExternalOrigin attempt source \<Rightarrow>
        assigned_lineage a = attempt \<and>
        (\<exists>run \<in> set (attempts s). attempt_id (attempt_intent run) = attempt \<and>
          attempt_request (attempt_intent run) = output_owner x \<and>
          attempt_state run = Confirmed \<and>
          cost_profile (attempt_cost (attempt_intent run)) = output_profile x) \<and>
        (case source of None \<Rightarrow> publication = None | Some binding \<Rightarrow>
          (case publication of None \<Rightarrow> False | Some p \<Rightarrow>
            source_binding_id p = binding \<and> snapshot_id p = assigned_output a \<and>
            observation_attempt p = attempt \<and> observed_binding p = assigned_binding a \<and>
            observation_permitted (output_preview s a) p)) |
       QualificationOrigin attempt \<Rightarrow> publication=None \<and> assigned_lineage a=attempt \<and>
        attempt\<in>set (qualification_started s) \<and>
        (\<exists>q\<in>set (qualification_reservations s). reservation_attempt q=attempt \<and>
          reservation_owner q=output_owner x \<and> reservation_goal q=output_goal x \<and>
          qualification_child_current s q \<and> cost_profile (reservation_cost q)=output_profile x))) \<and>
    binding_licensed (output_preview s a) (assigned_binding a)"

ML \<open>Veri7vn_Authority_Compile.phase "output_guards_ready"\<close>

definition inputs_accessible_to :: "authority_state \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> bool" where
  "inputs_accessible_to s rid inputs \<longleftrightarrow> list_all (\<lambda>objid.
    \<exists>v \<in> set (retained_values s). retained_id v = objid \<and>
      accessible s (objid # retained_dependencies v) \<and>
      list_all (observation_fresh s) (retained_access_requirements v) \<and>
      retention_flows s (retained_owner v) (RequestLocal rid)) inputs"
definition inputs_available :: "authority_state \<Rightarrow> nat \<Rightarrow> output_slot \<Rightarrow> bool" where
  "inputs_available s rid x \<longleftrightarrow> (case resolved_inputs s (output_inputs x) of None \<Rightarrow> False | Some inputs \<Rightarrow>
    inputs_accessible_to s rid inputs)"

definition artifact_output_permitted :: "authority_state \<Rightarrow> artifact_assignment \<Rightarrow> bool" where
  "artifact_output_permitted s a \<longleftrightarrow>
    (\<forall>old\<in>set (output_assignments s). assignment_slot old \<noteq> artifact_assigned_slot a) \<and>
    distinct (map retained_id (artifact_assigned_retained a)) \<and>
    artifact_assigned_output a \<in> set (map retained_id (artifact_assigned_retained a)) \<and>
    artifact_assigned_output a \<in> set (artifact_assigned_dependencies a) \<and>
    artifact_assigned_generation a > 0 \<and>
    artifact_expected_retained s a=Some (artifact_assigned_retained a) \<and>
    artifact_assigned_generation a \<in> set (artifact_assigned_dependencies a) \<and>
    registrations_permitted s (artifact_assigned_retained a) \<and>
    accessible s (assignment_references (ArtifactOutput a)) \<and>
    (\<exists>r\<in>set (requests s). request_id r=artifact_assigned_request a \<and>
      \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
      (\<exists>g\<in>set (request_goals r). goal_id g=artifact_assigned_goal a \<and>
        goal_output_slot g=Some (artifact_assigned_slot a) \<and> unblocked r g \<and>
        goal_ready_live s r g \<and> child_accessible s g \<and>
        (case goal_required g of ArtifactRequirement required \<Rightarrow>
          resolved_artifact_requirement s required=Some (artifact_assigned_requirement a) | ClaimRequirement c \<Rightarrow> False) \<and>
        (case resolved_inputs s (artifact_parents (artifact_assigned_requirement a)) of None \<Rightarrow> False | Some parents \<Rightarrow>
          list_all (\<lambda>parent. \<exists>bound\<in>set (artifact_assignments s).
            artifact_assigned_output bound=parent \<and> artifact_accessible s bound) parents) \<and>
        (\<exists>x\<in>set (output_slots s). output_slot_id x=artifact_assigned_slot a \<and>
          output_owner x=request_id r \<and> output_goal x=goal_id g \<and> output_origin x=PureOrigin \<and>
          output_template x=artifact_template (artifact_assigned_requirement a) \<and>
          output_profile x=artifact_profile (artifact_assigned_requirement a) \<and>
          inputs_available s (request_id r) x \<and>
          list_all (\<lambda>d. d\<in>set (artifact_assigned_dependencies a))
            (output_reserved_dependencies x @ artifact_requirement_references (artifact_assigned_requirement a) @
              [goal_generation g,goal_code_generation g]) \<and>
          (\<exists>run\<in>set (pure_executions s). execution_id run=artifact_assigned_lineage a \<and>
            execution_request run=request_id r \<and> execution_slot run=output_slot_id x \<and>
            cost_profile (execution_cost run)=output_profile x \<and>
            cost_code_generation (execution_cost run)=goal_code_generation g \<and>
            resolved_inputs s (output_inputs x)=Some (execution_inputs run) \<and>
            list_all (\<lambda>v. retained_id v=artifact_assigned_output a \<longrightarrow>
              list_all (\<lambda>input. input\<in>set (retained_read_dependencies v)) (execution_inputs run))
              (artifact_assigned_retained a))) \<and>
        list_all (\<lambda>v. retained_owner v\<in>set (request_retention_scopes r) \<and>
          list_all (\<lambda>d. d\<in>set (retained_dependencies v))
            (artifact_assigned_generation a # filter (\<lambda>d. d\<notin>set (map retained_id (artifact_assigned_retained a))) (artifact_assigned_dependencies a)))
          (artifact_assigned_retained a)))"
fun output_permitted :: "authority_state \<Rightarrow> slot_assignment \<Rightarrow> source_publication option \<Rightarrow> bool" where
  "output_permitted s (ClaimOutput a) publication = claim_output_permitted s a publication" |
  "output_permitted s (ArtifactOutput a) publication = (publication=None \<and> artifact_output_permitted s a)"

definition adoption_permitted :: "authority_state \<Rightarrow> nat \<Rightarrow> binding adopted_delta \<Rightarrow> bool" where
  "adoption_permitted s rid d \<longleftrightarrow> (\<exists>r \<in> set (requests s).
    request_id r = rid \<and> \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
    request_session r = Some (adoption_session d) \<and>
    list_all (\<lambda>b. binding_request b = rid \<and> b \<in> set (visible_bindings s) \<and>
      binding_licensed s b) (adoption_bindings d) \<and>
    (\<exists>current \<in> set (current_observations s).
      observed_session current = adoption_session d \<and>
      observed_version current = adoption_expected_version d) \<and>
    (\<exists>view \<in> set (session_views s). adopt_answer rid (filter (binding_licensed s)
       (visible_bindings s)) d view \<noteq> None))"

definition find_retention_grant :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> retention_scope \<Rightarrow> retention_grant option" where
  "find_retention_grant s rid objid destination = find (\<lambda>grant.
    retention_grant_owner grant = rid \<and> retention_grant_value grant = objid \<and>
    retention_grant_destination grant = destination \<and>
    retention_grant_id grant \<notin> set (consumed_retention_grants s) \<and>
    accessible s (retention_policy_association grant # retention_grant_provenance grant) \<and>
    observation_fresh s (retention_grant_observation grant) \<and>
    (\<exists>v \<in> set (retained_values s). retained_id v = objid \<and>
      set (retention_grant_provenance grant) = set (objid # retained_dependencies v) \<and>
      list_all (observation_fresh s) (retained_access_requirements v))) (retention_grants s)"
definition retention_permitted :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> retention_scope \<Rightarrow> bool" where
  "retention_permitted s rid objid destination \<longleftrightarrow> accessible s [objid] \<and>
    find_retention_grant s rid objid destination \<noteq> None \<and>
    (\<exists>r \<in> set (requests s). request_id r = rid \<and> \<not> request_cancelled r \<and>
      request_fresh s r \<and> parent_accessible s r \<and> destination \<in> set (request_retention_scopes r) \<and>
      (\<exists>v \<in> set (retained_values s). retained_id v = objid \<and>
        (retained_owner v = RequestLocal rid \<and>
          (destination = WorkspaceShared \<or> (case request_session r of None \<Rightarrow> False |
            Some sid \<Rightarrow> destination = SessionLocal sid)) \<or>
         (case retained_owner v of SessionLocal sid \<Rightarrow> request_session r = Some sid \<and>
            destination = WorkspaceShared | _ \<Rightarrow> False))))"


definition qualification_reserved :: "authority_state \<Rightarrow> qualification_reservation \<Rightarrow> bool" where
  "qualification_reserved s q \<longleftrightarrow>
    (\<forall>old \<in> set (qualification_reservations s). reservation_attempt old \<noteq> reservation_attempt q) \<and>
    qualification_child_current s q \<and> qualification_slot_open s q \<and>
    accessible s (reservation_candidate q # reservation_run_spec q # reservation_domain q # reservation_policy q # reservation_dependencies q) \<and>
    (\<exists>r \<in> set (requests s). request_id r = reservation_owner q \<and>
      \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
      (\<exists>g\<in>set (request_goals r). goal_id g=reservation_goal q \<and>
        unblocked r g \<and> goal_ready_live s r g \<and>
        goal_capability g \<notin> set (retired_capabilities s) \<and>
        accessible s (requirement_references (goal_required g)) \<and>
        goal_chargeable r g (reservation_cost q))) \<and>
    (\<exists>history \<in> set (exposure_history s). exposure_id history = reservation_exposure q) \<and>
    (reservation_mode q = FreshHoldout \<longrightarrow> reservation_domain q \<notin> set (spent_domains s) \<and>
      (\<exists>e \<in> set (qualification_eligibility s). reservation_eligibility q = Some (eligibility_id e) \<and>
        eligibility_domain e = reservation_domain q \<and>
        eligibility_policy e = reservation_policy q \<and>
        eligibility_exposure e = reservation_exposure q \<and> eligibility_state e = Eligible))"

fun comparison_bounded :: "nat \<Rightarrow> metric_comparison \<Rightarrow> bool" where
  "comparison_bounded metric_bound (AtMost n scale) = (scale > 0 \<and> scale \<le> metric_bound \<and> abs n \<le> int metric_bound)" |
  "comparison_bounded metric_bound (AtLeast n scale) = (scale > 0 \<and> scale \<le> metric_bound \<and> abs n \<le> int metric_bound)" |
  "comparison_bounded metric_bound (Exactly n scale) = (scale > 0 \<and> scale \<le> metric_bound \<and> abs n \<le> int metric_bound)"
definition metric_satisfies :: "nat \<Rightarrow> measured_metric \<Rightarrow> metric_requirement \<Rightarrow> bool" where
  "metric_satisfies metric_bound actual required \<longleftrightarrow>
    metric_id actual = required_metric required \<and> metric_unit actual = required_unit required \<and>
    comparison_bounded metric_bound (required_comparison required) \<and>
    (case metric_value actual of UncertainMetric reason \<Rightarrow> False | ExactMetricValue n scale \<Rightarrow>
      scale > 0 \<and> scale \<le> metric_bound \<and> abs n \<le> int metric_bound \<and>
      (case required_comparison required of
        AtMost threshold_numerator threshold_scale \<Rightarrow> n * int threshold_scale \<le> threshold_numerator * int scale |
        AtLeast threshold_numerator threshold_scale \<Rightarrow> threshold_numerator * int scale \<le> n * int threshold_scale |
        Exactly threshold_numerator threshold_scale \<Rightarrow> n * int threshold_scale = threshold_numerator * int scale))"
definition metric_policy_satisfied :: "qualification_record \<Rightarrow> qualification_policy_spec \<Rightarrow> bool" where
  "metric_policy_satisfied q policy \<longleftrightarrow>
    qualification_policy_ref q = policy_spec_id policy \<and>
    qualification_mode q = policy_required_mode policy \<and>
    policy_metric_bound policy > 0 \<and>
    (policy_requires_baseline policy \<longrightarrow> baseline_artifact q \<noteq> None) \<and>
    distinct (map (\<lambda>metric. (metric_id metric, metric_unit metric)) (qualification_metrics q)) \<and>
    policy_resource_association policy \<in> set (qualification_pins q) \<and>
    list_all (\<lambda>required. \<exists>actual \<in> set (qualification_metrics q).
      metric_satisfies (policy_metric_bound policy) actual required) (policy_requirements policy)"

definition qualification_permitted :: "authority_state \<Rightarrow> qualification_record \<Rightarrow> bool" where
  "qualification_permitted s q \<longleftrightarrow>
    (\<forall>old \<in> set (qualifications s). qualification_id old \<noteq> qualification_id q) \<and>
    qualification_attempt q \<in> set (qualification_started s) \<and>
    accessible s (candidate_artifact q # spent_observation q # qualification_run_spec q #
      qualification_domain q # qualification_policy_ref q # map metric_observation (qualification_metrics q) @ qualification_pins q) \<and>
    (\<exists>reserved \<in> set (qualification_reservations s).
      reservation_attempt reserved = qualification_attempt q \<and> qualification_child_current s reserved \<and>
      reservation_candidate reserved = candidate_artifact q \<and>
      reservation_baseline reserved = baseline_artifact q \<and>
      reservation_run_spec reserved = qualification_run_spec q \<and>
      reservation_domain reserved = qualification_domain q \<and>
      reservation_policy reserved = qualification_policy_ref q \<and>
      reservation_mode reserved = qualification_mode q \<and>
      reservation_exposure reserved = exposure_before q \<and>
      (\<exists>after \<in> set (exposure_history s). exposure_id after = exposure_after q \<and>
        (exposure_id after = exposure_before q \<or> exposure_parent after = Some (exposure_before q))) \<and>
      (case measured_binding q of None \<Rightarrow> qualification_failure q \<noteq> None | Some b \<Rightarrow>
        binding_request b = reservation_owner reserved \<and> binding_goal b = reservation_goal reserved \<and>
        (\<exists>a\<in>set (claim_assignments s). assigned_binding a=b \<and>
          assigned_lineage a=reservation_attempt reserved \<and>
          (\<exists>x\<in>set (output_slots s). output_slot_id x=assigned_slot a \<and>
            output_owner x=reservation_owner reserved \<and> output_goal x=reservation_goal reserved \<and>
            output_origin x=QualificationOrigin (reservation_attempt reserved))) \<and>
        claim_kind (binding_claim b) = TestObservation \<and>
        binding_licensed s b \<and>
        list_all (\<lambda>d. d \<in> set (dependencies (binding_claim b)))
          (candidate_artifact q # spent_observation q # qualification_run_spec q # qualification_domain q #
            qualification_policy_ref q # map metric_observation (qualification_metrics q) @ qualification_pins q)))"

definition package_permitted :: "authority_state \<Rightarrow> package_publication \<Rightarrow> bool" where
  "package_permitted s p \<longleftrightarrow>
    map_option publication_candidate (find (\<lambda>old. publication_slot old = publication_slot p)
      (package_publications s)) = publication_previous p \<and>
    accessible s [publication_candidate p, publication_policy p] \<and>
    publication_candidate p \<notin> set (retired_capabilities s) \<and>
    distinct (map declared_export (publication_exports p)) \<and>
    distinct (map fst (publication_native_bindings p)) \<and>
    set (map fst (publication_native_bindings p)) = set (map declared_export (publication_exports p)) \<and>
    list_all (\<lambda>export. \<exists>entry \<in> set (publication_native_bindings p).
      fst entry = declared_export export \<and> binding_licensed s (snd entry) \<and>
      same_target (binding_claim (snd entry)) (declared_requirement export) \<and>
      (case executable_generation (declared_requirement export) of NoExecution \<Rightarrow> True |
        ExecutableGeneration gen \<Rightarrow> executable_generation (binding_claim (snd entry)) = ExecutableGeneration gen) \<and>
      (case declared_profile export of None \<Rightarrow> True | Some profile \<Rightarrow>
        accessible s [profile] \<and> executable_generation (binding_claim (snd entry)) \<noteq> NoExecution))
      (publication_exports p) \<and>
    (\<exists>q \<in> set (qualifications s). qualification_id q = publication_qualification p \<and>
      candidate_artifact q = publication_candidate p \<and>
      publication_policy p = qualification_policy_ref q \<and>
      (\<exists>policy \<in> set (qualification_policies s). policy_spec_id policy = publication_policy p \<and>
        metric_policy_satisfied q policy \<and> accessible s [policy_resource_association policy]) \<and>
      qualification_failure q = None \<and>
      (case measured_binding q of None \<Rightarrow> False | Some b \<Rightarrow> binding_licensed s b) \<and>
      accessible s (candidate_artifact q # spent_observation q # qualification_pins q))"

definition can_stage :: "authority_state \<Rightarrow> bool" where
  "can_stage s \<longleftrightarrow> pending_batch s = None"

definition stage :: "nat \<Rightarrow> delta \<Rightarrow> authority_state \<Rightarrow> authority_state \<times> command list" where
  "stage n d s = (if n \<in> set (issued_batches s) then (s, [Rejected 10]) else let b = \<lparr>batch_id = n, expected_revision = revision s,
    batch_epoch = authority_epoch s, batch_delta = d\<rparr>
    in (s\<lparr>pending_batch := Some b, issued_batches := n # issued_batches s\<rparr>, [Persist b]))"

fun apply_delta :: "delta \<Rightarrow> authority_state \<Rightarrow> authority_state" where
  "apply_delta (Publish b) s = s\<lparr>visible_bindings := visible_bindings s @ [b]\<rparr>" |
  "apply_delta (RecordIntent i) s = s\<lparr>attempts := attempts s @
    [\<lparr>attempt_intent = i, attempt_state = Prepared\<rparr>]\<rparr>" |
  "apply_delta (RecordEffectObservation observation) s = effect_observation_preview s observation" |
  "apply_delta (RecordObservation p) s =
    s\<lparr>source_publications := source_publications s @ [p]\<rparr>" |
  "apply_delta (RecordOutput (ClaimOutput a) publication) s =
    (let next = output_preview s a in next\<lparr>
      visible_bindings := visible_bindings next @ [assigned_binding a],
      source_publications := source_publications next @ (case publication of None \<Rightarrow> [] | Some p \<Rightarrow> [p])\<rparr>)" |
  "apply_delta (RecordOutput (ArtifactOutput a) publication) s = artifact_preview s a" |
  "apply_delta (AdoptSession rid d) s = s\<lparr>session_views := map (\<lambda>view.
    case adopt_answer rid (filter (binding_licensed s) (visible_bindings s)) d view of
      None \<Rightarrow> view | Some next \<Rightarrow> next) (session_views s),
    current_observations := map (\<lambda>context. if observed_session context = adoption_session d then
      context\<lparr>observed_version := Suc (observed_version context)\<rparr> else context)
      (current_observations s)\<rparr>" |
  "apply_delta (ChangeRetention rid objid destination) s = s\<lparr>retained_values :=
    map (\<lambda>v. if retained_id v = objid then v\<lparr>retained_owner := destination\<rparr> else v) (retained_values s),
    consumed_retention_grants := (case find_retention_grant s rid objid destination of None \<Rightarrow>
      consumed_retention_grants s | Some grant \<Rightarrow> retention_grant_id grant # consumed_retention_grants s)\<rparr>" |
  "apply_delta (ConsumeExposure q) s = s\<lparr>
    qualification_reservations := qualification_reservations s @ [q],
    spent_domains := remdups (reservation_domain q # spent_domains s),
    qualification_eligibility := map (\<lambda>e. if eligibility_domain e = reservation_domain q then
      e\<lparr>eligibility_state := ConsumedEligibility (reservation_attempt q)\<rparr> else e)
      (qualification_eligibility s)\<rparr>" |
  "apply_delta (RecordQualification q) s = s\<lparr>qualifications := qualifications s @ [q]\<rparr>" |
  "apply_delta (PublishPackage p) s = s\<lparr>package_publications :=
    filter (\<lambda>old. publication_slot old \<noteq> publication_slot p) (package_publications s) @ [p]\<rparr>" |
  "apply_delta (Migrate old new proof bs) s =
    s\<lparr>session_generation := new, visible_bindings := bs\<rparr>"

definition request_openable :: "authority_state \<Rightarrow> request \<Rightarrow> bool" where
  "request_openable s r \<longleftrightarrow>
    (\<forall>q \<in> set (requests s). request_id q \<noteq> request_id r) \<and>
    \<not> request_cancelled r \<and> request_prestate r = revision s \<and>
    ordered_goals [] (request_goals r) \<and> request_fresh s r \<and> parent_accessible s r \<and>
    accessible s (request_dependencies r) \<and>
    list_all (\<lambda>g. (case goal_outcome g of Accepted c e \<Rightarrow> False | ArtifactReady objid \<Rightarrow> False | _ \<Rightarrow> True) \<and>
      goal_capability g \<notin> set (retired_capabilities s)) (request_goals r)"



definition pure_permitted :: "authority_state \<Rightarrow> pure_execution \<Rightarrow> bool" where
  "pure_permitted s run \<longleftrightarrow>
    (\<forall>old \<in> set (pure_executions s). execution_id old \<noteq> execution_id run) \<and>
    (\<exists>r \<in> set (requests s). request_id r = execution_request run \<and>
      \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
      (\<exists>x \<in> set (output_slots s). output_slot_id x = execution_slot run \<and>
        output_owner x = request_id r \<and> output_origin x = PureOrigin \<and>
        cost_profile (execution_cost run) = output_profile x \<and>
        resolved_inputs s (output_inputs x) = Some (execution_inputs run) \<and> inputs_available s (request_id r) x \<and>
        accessible s (output_template x # output_profile x # output_input_identity x # output_reserved_dependencies x) \<and>
        (\<forall>a \<in> set (output_assignments s). assignment_slot a \<noteq> output_slot_id x) \<and>
        (\<exists>g \<in> set (request_goals r). goal_id g = output_goal x \<and>
          goal_ready_live s r g \<and> unblocked r g \<and>
          goal_chargeable r g (execution_cost run) \<and>
          goal_output_slot g=Some (output_slot_id x) \<and>
          child_accessible s g \<and>
          goal_capability g \<notin> set (retired_capabilities s))))"

definition qualification_startable :: "authority_state \<Rightarrow> qualification_reservation \<Rightarrow> bool" where
  "qualification_startable s q \<longleftrightarrow> reservation_attempt q \<notin> set (qualification_started s) \<and>
    qualification_child_current s q \<and> qualification_slot_open s q \<and>
    accessible s (reservation_candidate q # reservation_run_spec q # reservation_domain q # reservation_policy q # reservation_dependencies q) \<and>
    (\<exists>r \<in> set (requests s). request_id r = reservation_owner q \<and>
      \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and>
      (\<exists>g\<in>set (request_goals r). goal_id g=reservation_goal q \<and>
        unblocked r g \<and> goal_ready_live s r g \<and>
        goal_capability g \<notin> set (retired_capabilities s) \<and>
        accessible s (requirement_references (goal_required g)) \<and>
        goal_chargeable r g (reservation_cost q)))"

definition job_permitted :: "authority_state \<Rightarrow> acquisition_job \<Rightarrow> operation_cost \<Rightarrow> bool" where
  "job_permitted s j cost \<longleftrightarrow>
    job_source j \<notin> set (retired_sources s) \<and>
    job_capability j \<notin> set (retired_capabilities s) \<and>
    accessible s [job_source j, job_capability j] \<and>
    cost_units cost > 0 \<and> cost_units cost \<le> fuel_remaining (job_budget j) \<and>
    fuel_owner (job_budget j) = job_owner j \<and>
    (\<exists>r \<in> set (requests s). request_id r = job_owner j \<and>
      \<not> request_cancelled r \<and> request_fresh s r \<and> parent_accessible s r \<and> legacy_single_goal r \<and> operation_chargeable r cost \<and>
      job_source j \<in> set (request_dependencies r))"

fun delta_permitted :: "authority_state \<Rightarrow> delta \<Rightarrow> bool" where
  "delta_permitted s (Publish b) = binding_licensed s b" |
  "delta_permitted s (RecordIntent i) = (intent_permitted s i \<and>
    (\<forall>a\<in>set (attempts s). attempt_id (attempt_intent a)\<noteq>attempt_id i))" |
  "delta_permitted s (RecordEffectObservation observation) = effect_observation_permitted s observation" |
  "delta_permitted s (RecordObservation p) = observation_permitted s p" |
  "delta_permitted s (RecordOutput a p) = output_permitted s a p" |
  "delta_permitted s (AdoptSession rid d) = adoption_permitted s rid d" |
  "delta_permitted s (ChangeRetention rid objid destination) = retention_permitted s rid objid destination" |
  "delta_permitted s (ConsumeExposure q) = qualification_reserved s q" |
  "delta_permitted s (RecordQualification q) = qualification_permitted s q" |
  "delta_permitted s (PublishPackage p) = package_permitted s p" |
  "delta_permitted s (Migrate old new proof bs) = False"

fun affected_goals :: "authority_state \<Rightarrow> request \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> subgoal list \<Rightarrow> nat list" where
  "affected_goals s r n affected [] = affected" |
  "affected_goals s r n affected (g # gs) = affected_goals s r n
    (if goal_capability g = n \<or> n \<in> set (goal_references g) \<or>
      (case required_for s r g of None \<Rightarrow> False | Some required \<Rightarrow> n \<in> set (dependencies required)) \<or>
      (\<exists>d \<in> set (goal_dependencies g). dependency_goal d \<in> set affected)
     then goal_id g # affected else affected) gs"

definition cancel_dependent :: "authority_state \<Rightarrow> nat \<Rightarrow> request \<Rightarrow> request" where
  "cancel_dependent s n r = (if n=request_id r \<or> n \<in> set (request_dependencies r)
    then r\<lparr>request_cancelled := True\<rparr> else
    r\<lparr>request_goals := map (\<lambda>g. if goal_id g \<in>
      set (affected_goals s r n [] (request_goals r)) then g\<lparr>goal_outcome := Cancelled\<rparr>
      else g) (request_goals r)\<rparr>)"

definition lifecycle :: "authority_state \<Rightarrow> authority_state" where
  "lifecycle s = s\<lparr>authority_epoch := Suc (authority_epoch s), pending_batch := None\<rparr>"

definition disjoint_ids :: "nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "disjoint_ids removed deps \<longleftrightarrow> list_all (\<lambda>d. d \<notin> set removed) deps"
definition revoke_state :: "nat list \<Rightarrow> authority_state \<Rightarrow> authority_state" where
  "revoke_state removed s = s\<lparr>revoked_objects := remdups (removed @ revoked_objects s),
    requests := map (\<lambda>r. fold (cancel_dependent s) removed r) (requests s),
    acquisition_jobs := map (\<lambda>j. if job_source j \<in> set removed \<or> job_capability j \<in> set removed
      then stop_job True j else j) (acquisition_jobs s)\<rparr>"
definition forget_state :: "nat list \<Rightarrow> authority_state \<Rightarrow> authority_state" where
  "forget_state removed s = (revoke_state removed s)\<lparr>
    forgotten_objects := remdups (removed @ forgotten_objects s),
    retained_values := filter (\<lambda>v. retained_id v \<notin> set removed) (retained_values s),
    visible_bindings := filter (\<lambda>b. disjoint_ids removed (binding_managed_dependencies s b)) (visible_bindings s),
    effect_observations := filter (\<lambda>observation. case effect_observation_retained s observation of
      None \<Rightarrow> False | Some value \<Rightarrow> disjoint_ids removed
        (retained_id value # retained_dependencies value)) (effect_observations s),
    source_publications := filter (\<lambda>p. disjoint_ids removed
      (source_binding_id p # snapshot_id p # binding_managed_dependencies s (observed_binding p))) (source_publications s),
    session_views := map (\<lambda>v. v\<lparr>adopted_bindings := filter (\<lambda>b.
      disjoint_ids removed (binding_managed_dependencies s b)) (adopted_bindings v),
      recorded_utterances := filter (\<lambda>u. u \<notin> set removed) (recorded_utterances v)\<rparr>)
      (filter (\<lambda>v. session_id v \<notin> set removed) (session_views s)),
    current_observations := filter (\<lambda>v. disjoint_ids removed
      (observed_session v # map fst (observed_reads v))) (current_observations s),
    output_slots := filter (\<lambda>x. disjoint_ids removed (output_template x # output_profile x #
      output_input_identity x # output_reserved_dependencies x)) (output_slots s),
    output_assignments := filter (\<lambda>a. disjoint_ids removed
      (assignment_references a @ (case a of ClaimOutput c \<Rightarrow> binding_managed_dependencies s (assigned_binding c) |
        ArtifactOutput c \<Rightarrow> []))) (output_assignments s)\<rparr>"

text \<open>AttachEvidence is privileged native gate input, not a public proposal API.
Its non-rebinding check prevents an old identifier being silently reassociated.
OpenRequest and migration additionally require native typed elaboration association;
the machine does not claim that arbitrary metadata establishes a typed plan.\<close>
ML \<open>Veri7vn_Authority_Compile.phase "lifecycle_guards_ready"\<close>

primrec step :: "authority_state \<Rightarrow> event \<Rightarrow> authority_state \<times> command list" where
  "step s (OpenRequest r) =
    (if request_openable s r \<and> list_all (\<lambda>g. goal_output_slot g = None) (request_goals r)
     then (s\<lparr>requests := requests s @ [r]\<rparr>, []) else (s, [Rejected 1]))" |
  "step s (ReserveRequest r slots) =
    (if request_openable s r \<and> reservations_match r slots \<and>
      list_all (\<lambda>x. (\<forall>old \<in> set (output_slots s). output_slot_id old \<noteq> output_slot_id x) \<and>
        accessible s (output_template x # output_profile x # output_input_identity x # output_reserved_dependencies x)) slots
     then (s\<lparr>requests := requests s @ [r], output_slots := output_slots s @ slots\<rparr>, [])
     else (s, [Rejected 20]))" |
  "step s (UpdateObservation context) =
    (if accessible s (observed_session context # map fst (observed_reads context)) \<and>
      (\<forall>view \<in> set (session_views s). session_id view = observed_session context \<longrightarrow>
        session_version view = observed_version context) \<and>
      (\<forall>old \<in> set (current_observations s). observed_session old = observed_session context \<longrightarrow>
      observed_version old = observed_version context \<and>
      (case (evaluation_time old, evaluation_time context) of (Some earlier, Some later) \<Rightarrow>
        (basis earlier = basis later \<longrightarrow> ticks earlier \<le> ticks later) | _ \<Rightarrow> True))
     then (s\<lparr>current_observations := filter (\<lambda>x. observed_session x \<noteq> observed_session context)
         (current_observations s) @ [context],
       session_views := (if \<exists>v \<in> set (session_views s). session_id v = observed_session context
         then session_views s else session_views s @ [\<lparr>session_id = observed_session context,
           session_version = observed_version context, recorded_utterances = [], adopted_bindings = []\<rparr>])\<rparr>, [])
     else (s, [Rejected 21]))" |
  "step s (RecordUtterance sid utterance) =
    (if accessible s [sid, utterance] then
      (s\<lparr>session_views := map (\<lambda>v. if session_id v = sid then record_utterance utterance v else v)
        (session_views s)\<rparr>, []) else (s, [Rejected 43]))" |
  "step s (StageAdoption n rid d) =
    (if can_stage s \<and> adoption_permitted s rid d then stage n (AdoptSession rid d) s
     else (s, [Rejected 22]))" |
  "step s (StageRetention n rid objid destination) =
    (if can_stage s \<and> retention_permitted s rid objid destination then
      stage n (ChangeRetention rid objid destination) s else (s, [Rejected 26]))" |
  "step s (ExecutePure run) =
    (if pure_permitted s run then
      ((charge_request (execution_request run) (execution_cost run) s)\<lparr>
        pure_executions := pure_executions s @ [run]\<rparr>, [RunPure run])
     else (s, [Rejected 23]))" |
  "step s (StageOutput n assignment publication) =
    (if can_stage s \<and> output_permitted s assignment publication then
      stage n (RecordOutput assignment publication) s else (s, [Rejected 24]))" |
  "step s (RegisterManaged value) =
    (if managed_registration s value then
      (s\<lparr>retained_values := retained_values s @ [value]\<rparr>, []) else (s, [Rejected 25]))" |
  "step s (InstallRetentionGrant grant) =
    (if (\<forall>old \<in> set (retention_grants s). retention_grant_id old \<noteq> retention_grant_id grant) \<and>
      accessible s (retention_policy_association grant # retention_grant_value grant # retention_grant_provenance grant)
     then (s\<lparr>retention_grants := retention_grants s @ [grant]\<rparr>, []) else (s, [Rejected 42]))" |
  "step s (InstallJob j) =
    (if job_status j = JobStopped \<and>
      (\<forall>old \<in> set (acquisition_jobs s). job_id old \<noteq> job_id j) \<and>
      accessible s [job_source j, job_capability j] \<and>
      fuel_owner (job_budget j) = job_owner j \<and>
      (\<exists>r \<in> set (requests s). request_id r = job_owner j \<and> \<not> request_cancelled r \<and>
        job_source j \<in> set (request_dependencies r))
     then (s\<lparr>acquisition_jobs := acquisition_jobs s @ [j]\<rparr>, []) else (s, [Rejected 26]))" |
  "step s (StartJob objid cost) =
    (case find (\<lambda>j. job_id j = objid) (acquisition_jobs s) of None \<Rightarrow> (s, [Rejected 27]) |
      Some j \<Rightarrow> (case start_job (job_owner j) (job_permitted s j cost) j of
        None \<Rightarrow> (s, [Rejected 27]) | Some active \<Rightarrow>
          (let next = active\<lparr>job_budget := (job_budget active)\<lparr>fuel_remaining :=
                fuel_remaining (job_budget active) - cost_units cost\<rparr>\<rparr> in
           ((charge_request (job_owner j) cost s)\<lparr>acquisition_jobs :=
             map (\<lambda>old. if job_id old = objid then next else old) (acquisition_jobs s)\<rparr>, [RunJob next]))))" |
  "step s (StopJob objid retired) =
    (lifecycle (s\<lparr>acquisition_jobs := map (\<lambda>j. if job_id j = objid then stop_job retired j else j)
      (acquisition_jobs s)\<rparr>), [AuthorityChanged (Suc (authority_epoch s))])" |
  "step s (InstallQualificationPolicy policy) =
    (if (\<forall>old \<in> set (qualification_policies s). policy_spec_id old \<noteq> policy_spec_id policy) \<and>
      policy_metric_bound policy > 0 \<and> accessible s [policy_spec_id policy, policy_resource_association policy] \<and>
      distinct (map (\<lambda>required. (required_metric required, required_unit required)) (policy_requirements policy)) \<and>
      list_all (\<lambda>required. comparison_bounded (policy_metric_bound policy) (required_comparison required))
        (policy_requirements policy)
     then (s\<lparr>qualification_policies := qualification_policies s @ [policy]\<rparr>, [])
     else (s, [Rejected 43]))" |
  "step s (InstallExposure history) =
    (if distinct (exposure_members history) \<and>
      (\<forall>old \<in> set (exposure_history s). exposure_id old \<noteq> exposure_id history) \<and>
      (case exposure_parent history of None \<Rightarrow> True | Some parent \<Rightarrow>
        (\<exists>old \<in> set (exposure_history s). exposure_id old = parent \<and>
          set (exposure_members old) \<subseteq> set (exposure_members history)))
     then (s\<lparr>exposure_history := exposure_history s @ [history]\<rparr>, []) else (s, [Rejected 28]))" |
  "step s (InstallEligibility e) =
    (if (eligibility_state e = UnknownEligibility \<or> eligibility_state e = Eligible) \<and>
      (eligibility_state e = Eligible \<longrightarrow> eligibility_domain e \<notin> set (spent_domains s)) \<and>
      (\<exists>history \<in> set (exposure_history s). exposure_id history = eligibility_exposure e) \<and>
      (\<forall>old \<in> set (qualification_eligibility s). eligibility_id old \<noteq> eligibility_id e \<and>
        eligibility_domain old \<noteq> eligibility_domain e)
     then (s\<lparr>qualification_eligibility := qualification_eligibility s @ [e]\<rparr>, [])
     else (s, [Rejected 29]))" |
  "step s (ReserveQualification n q) =
    (if can_stage s \<and> qualification_reserved s q then stage n (ConsumeExposure q) s
     else (s, [Rejected 30]))" |
  "step s (ClaimQualificationStart attempt) =
    (case find (\<lambda>q. reservation_attempt q = attempt) (qualification_reservations s) of
      None \<Rightarrow> (s, [Rejected 31]) | Some q \<Rightarrow>
        if qualification_startable s q then
          ((charge_request (reservation_owner q) (reservation_cost q) s)\<lparr>
            qualification_started := qualification_started s @ [attempt]\<rparr>,
            [ExposeQualification q (authority_epoch s)]) else (s, [Rejected 31]))" |
  "step s (StageQualification n q) =
    (if can_stage s \<and> qualification_permitted s q then stage n (RecordQualification q) s
     else (s, [Rejected 32]))" |
  "step s (StageQualifiedPublication n p) =
    (if can_stage s \<and> package_permitted s p then stage n (PublishPackage p) s
     else (s, [Rejected 33]))" |
  "step s (AttachEvidence e) =
    (if \<exists>a \<in> set (evidence_table s). evidence_id a = evidence_id e
     then (s, [Rejected 2]) else (s\<lparr>evidence_table := evidence_table s @ [e]\<rparr>, []))" |
  "step s (SetOutcome rid gid out) =
    (let rs = map (\<lambda>r. if request_id r = rid \<and> \<not> request_cancelled r then
       r\<lparr>request_goals := map (\<lambda>g. if goal_id g = gid then
         (case out of Accepted c e \<Rightarrow>
            if goal_ready_live s r g \<and> unblocked r g \<and> licensed s r g c e
            then g\<lparr>goal_outcome := out\<rparr> else g
          | _ \<Rightarrow> g\<lparr>goal_outcome := out\<rparr>) else g) (request_goals r)\<rparr> else r)
       (requests s)
     in (s\<lparr>requests := rs\<rparr>, []))" |
  "step s (AddBlocker rid b) =
    (s\<lparr>requests := map (\<lambda>r. if request_id r = rid then
      r\<lparr>request_blockers := b # request_blockers r\<rparr> else r) (requests s)\<rparr>, [] )" |
  "step s (StageClaim n rid gid eid) =
    (case find (\<lambda>r. request_id r = rid) (requests s) of None \<Rightarrow> (s, [Rejected 3]) |
      Some r \<Rightarrow> (case find (\<lambda>g. goal_id g = gid) (request_goals r) of
        None \<Rightarrow> (s, [Rejected 3]) | Some g \<Rightarrow>
        (case goal_outcome g of Accepted c e \<Rightarrow>
          (let b = \<lparr>binding_request = rid, binding_goal = gid,
                    binding_claim = c, binding_evidence = eid\<rparr> in
           if e = eid \<and> can_stage s \<and> binding_licensed s b
           then stage n (Publish b) s else (s, [Rejected 3]))
         | _ \<Rightarrow> (s, [Rejected 3]))))" |
  "step s (StageEffectObservation n observation) =
    (if can_stage s \<and> effect_observation_permitted s observation
     then stage n (RecordEffectObservation observation) s else (s,[Rejected 44]))" |
  "step s (StageIntent n i) =
    (if can_stage s \<and> intent_permitted s i \<and>
      (\<forall>a \<in> set (attempts s). attempt_id (attempt_intent a) \<noteq> attempt_id i)
     then stage n (RecordIntent i) s else (s, [Rejected 4]))" |
  "step s (StageObservation n p) =
    (if can_stage s \<and> observation_permitted s p then stage n (RecordObservation p) s
     else (s, [Rejected 12]))" |
  "step s (StageMigration n old new bs) = (s, [Rejected 5])" |
  "step s (DurableAck n ack_rev epoch) =
    (case pending_batch s of None \<Rightarrow> (s, [Rejected 6]) | Some b \<Rightarrow>
      if batch_id b = n \<and> expected_revision b = revision s \<and>
         ack_rev = Suc (revision s) \<and> batch_epoch b = authority_epoch s \<and>
         epoch = authority_epoch s \<and>
         delta_permitted s (batch_delta b)
      then ((apply_delta (batch_delta b) s)\<lparr>revision := ack_rev, pending_batch := None\<rparr>,
            [Visible n]) else (s, [Rejected 6]))" |
  "step s (DurableConflict n) = (case pending_batch s of None \<Rightarrow> (s, []) |
    Some b \<Rightarrow> if batch_id b = n then (s\<lparr>pending_batch := None\<rparr>, [Rejected 7])
      else (s, [Rejected 7]))" |
  "step s (CancelRequest n) =
    (lifecycle (s\<lparr>requests := map (\<lambda>r. if request_id r = n then
      r\<lparr>request_cancelled := True\<rparr> else r) (requests s),
      acquisition_jobs := map (\<lambda>j. if job_owner j = n then stop_job True j else j)
        (acquisition_jobs s)\<rparr>), [StopRequest n])" |
  "step s (RetireCapability n) =
    (lifecycle (s\<lparr>retired_capabilities := n # retired_capabilities s,
      acquisition_jobs := map (\<lambda>j. if job_capability j = n then stop_job True j else j)
        (acquisition_jobs s)\<rparr>),
      [AuthorityChanged (Suc (authority_epoch s))])" |
  "step s (RetireSource n) =
    (lifecycle (s\<lparr>retired_sources := n # retired_sources s,
      acquisition_jobs := map (\<lambda>j. if job_source j = n then stop_job True j else j)
        (acquisition_jobs s)\<rparr>),
      [AuthorityChanged (Suc (authority_epoch s))])" |
  "step s (Revoke n) =
    (case forget_closure (retained_values s) [n] of None \<Rightarrow> (s, [Rejected 40]) |
      Some removed \<Rightarrow> (lifecycle (revoke_state removed s), [AuthorityChanged (Suc (authority_epoch s))]))" |
  "step s (Forget n) =
    (case forget_closure (retained_values s) [n] of None \<Rightarrow> (s, [Rejected 41]) |
      Some removed \<Rightarrow> (lifecycle (forget_state removed s),
        map RemoveManaged removed @ [AuthorityChanged (Suc (authority_epoch s))]))" |
  "step s (ForgetRoots roots) =
    (if roots = [] then (s, [Rejected 41]) else
      (case forget_closure (retained_values s) (remdups roots) of None \<Rightarrow> (s, [Rejected 41]) |
        Some removed \<Rightarrow> (lifecycle (forget_state removed s),
          map RemoveManaged removed @ [AuthorityChanged (Suc (authority_epoch s))])))" |
  "step s (ClaimAndStart n) =
    (case filter (\<lambda>a. attempt_id (attempt_intent a) = n) (attempts s) of
      [a] \<Rightarrow>
        if attempt_state a = Prepared \<and>
          revision s = Suc (attempt_prestate (attempt_intent a)) \<and>
          intent_permitted (s\<lparr>revision := attempt_prestate (attempt_intent a)\<rparr>)
            (attempt_intent a)
        then ((charge_intent (attempt_intent a) s)\<lparr>attempts := map (\<lambda>x. if attempt_id (attempt_intent x) = n
          then x\<lparr>attempt_state := Running\<rparr> else x) (attempts s)\<rparr>,
          [ClaimStart (attempt_intent a) (authority_epoch s)])
        else (s, [Rejected 8]) | _ \<Rightarrow> (s,[Rejected 8]))" |
  "step s (Reconcile n status) =
    (if status = Prepared \<or> status = Running \<or>
       (\<exists>a \<in> set (attempts s). attempt_id (attempt_intent a) = n \<and>
        (attempt_state a = Confirmed \<or> attempt_state a = EffectFailed) \<and>
        attempt_state a \<noteq> status) then (s, [Rejected 9]) else
     (s\<lparr>attempts := map (\<lambda>a. if attempt_id (attempt_intent a) = n \<and>
       (attempt_state a = Running \<or> attempt_state a = Unknown)
       then a\<lparr>attempt_state := status\<rparr> else a)
       (attempts s)\<rparr>, []))"

ML \<open>Veri7vn_Authority_Compile.phase "step_equations_ready"\<close>

export_code step initial_state new_revoked_objects new_forgotten_objects required_native_evidence required_native_artifacts required_native_build_requests required_native_children required_native_effect_observations effect_observation_retained effect_observation_permitted artifact_expected_retained required_for in SML module_name Veri7vn_Authority file "../../../var/authority-generated.ML"

ML \<open>Veri7vn_Authority_Compile.phase "export_ready"\<close>

end
