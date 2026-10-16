theory Veri7vn_Rendering
  imports Veri7vn_Interpretation_Core.Veri7vn_Grammar Veri7vn_Authority.Veri7vn_Authority
begin

text \<open>A structured display vocabulary; source/model/modal qualification is a
mandatory semantic clause, not optional decoration or an unchecked text badge.
Target identifiers still require the native gate's exact proposition association.\<close>
datatype clause =
    Identity nat nat nat
  | Qualification claim_kind modality
  | Coverage collection_scope optimality
  | Conditions "nat list"
  | Dependencies "nat list"
  | Generations nat execution_dependency

definition render_claim :: "claim \<Rightarrow> clause list" where
  "render_claim c = [Identity (claim_id c) (target_id c) (interpretation_id c),
    Qualification (claim_kind c) (claim_modality c),
    Coverage (collection_scope c) (claim_optimality c),
    Conditions (premises c), Dependencies (dependencies c),
    Generations (semantic_generation c) (executable_generation c)]"
definition read_claim :: "clause list \<Rightarrow> claim option" where
  "read_claim cs = (case cs of
    [Identity i t r, Qualification k m, Coverage sc opt,
      Conditions ps, Dependencies ds, Generations sg eg] \<Rightarrow> Some
      \<lparr>claim_id = i, target_id = t, interpretation_id = r, claim_kind = k,
       claim_modality = m, collection_scope = sc, claim_optimality = opt,
       premises = ps, dependencies = ds, semantic_generation = sg,
       executable_generation = eg\<rparr>
    | _ \<Rightarrow> None)"
lemma claim_rendering_correspondence:
  "read_claim (render_claim c) = Some c"
  by (cases c) (simp add: render_claim_def read_claim_def)
definition rendering_licensed where
  "rendering_licensed c cs \<longleftrightarrow> read_claim cs = Some c"
lemma rendered_scope_exact:
  "rendering_licensed c cs \<Longrightarrow> read_claim cs = Some d \<Longrightarrow> d = c"
  by (simp add: rendering_licensed_def)
lemma removed_conditions_rejected:
  "read_claim [Identity i t r, Qualification k m, Coverage s out,
    Dependencies ds, Generations sg eg] = None"
  by (simp add: read_claim_def)
lemma changed_premise_rejected:
  assumes "premises c \<noteq> ps"
  shows "\<not> rendering_licensed c (render_claim (c\<lparr>premises := ps\<rparr>))"
proof
  assume L: "rendering_licensed c (render_claim (c\<lparr>premises := ps\<rparr>))"
  have eq: "c\<lparr>premises := ps\<rparr> = c"
    using L by (simp add: rendering_licensed_def claim_rendering_correspondence)
  have "ps = premises c" using arg_cong[OF eq, where f="premises"] by simp
  with assms show False by simp
qed
lemma changed_modality_rejected:
  assumes "claim_modality c \<noteq> m"
  shows "\<not> rendering_licensed c (render_claim (c\<lparr>claim_modality := m\<rparr>))"
proof
  assume L: "rendering_licensed c (render_claim (c\<lparr>claim_modality := m\<rparr>))"
  have eq: "c\<lparr>claim_modality := m\<rparr> = c"
    using L by (simp add: rendering_licensed_def claim_rendering_correspondence)
  have "m = claim_modality c" using arg_cong[OF eq, where f="claim_modality"] by simp
  with assms show False by simp
qed

datatype rendered_outcome =
    ShownAccepted "clause list" nat
  | ShownArtifactReady nat
  | ShownNeedsInput "nat list" | ShownAwaitingOutput nat | ShownDeclined nat | ShownInconclusive nat
  | ShownFailed nat | ShownCancelled
primrec render_outcome where
  "render_outcome (Accepted c e) = ShownAccepted (render_claim c) e" |
  "render_outcome (ArtifactReady objid) = ShownArtifactReady objid" |
  "render_outcome (NeedsInput ns) = ShownNeedsInput ns" |
  "render_outcome (AwaitingOutput slot) = ShownAwaitingOutput slot" |
  "render_outcome (Declined n) = ShownDeclined n" |
  "render_outcome (Inconclusive n) = ShownInconclusive n" |
  "render_outcome (Failed n) = ShownFailed n" |
  "render_outcome Cancelled = ShownCancelled"
primrec read_outcome where
  "read_outcome (ShownAccepted cs e) = map_option (\<lambda>c. Accepted c e) (read_claim cs)" |
  "read_outcome (ShownArtifactReady objid) = Some (ArtifactReady objid)" |
  "read_outcome (ShownNeedsInput ns) = Some (NeedsInput ns)" |
  "read_outcome (ShownAwaitingOutput slot) = Some (AwaitingOutput slot)" |
  "read_outcome (ShownDeclined n) = Some (Declined n)" |
  "read_outcome (ShownInconclusive n) = Some (Inconclusive n)" |
  "read_outcome (ShownFailed n) = Some (Failed n)" |
  "read_outcome ShownCancelled = Some Cancelled"
lemma outcome_rendering_correspondence:
  "read_outcome (render_outcome out) = Some out"
  by (cases out) (simp_all add: claim_rendering_correspondence)

lemma artifact_outcome_nonassertional:
  "render_outcome (ArtifactReady objid)=ShownArtifactReady objid"
  "render_outcome (ArtifactReady objid) \<noteq> ShownAccepted cs evidence"
  "\<not> accepted (ArtifactReady objid)"
  by simp_all

text \<open>Speech acts and candidate/reference artifacts contain separately structured
assertions. Merely delivering code or help neither creates an accepted claim nor
executes it. Free text has no semantic constructor for authoritative assertions.\<close>
datatype act_kind = Help | Question | Acknowledgement | Instruction | Reference | Fiction
record response_act =
  act_kind :: act_kind
  proposed_commentary :: string
  assertions :: "(claim \<times> nat) list"
record artifact_delivery =
  content_id :: nat
  candidate_obligations :: "nat list"
  artifact_assertions :: "(claim \<times> nat) list"
definition render_assertions where
  "render_assertions cs = map (\<lambda>(c,e). (render_claim c,e)) cs"
lemma embedded_assertions_preserved:
  "map (\<lambda>(cs,e). (read_claim cs,e)) (render_assertions xs) =
    map (\<lambda>(c,e). (Some c,e)) xs"
  by (induction xs) (auto simp: render_assertions_def claim_rendering_correspondence split: prod.splits)

datatype rendered_act = ShownAct act_kind "(clause list \<times> nat) list"
definition render_act where
  "render_act a = ShownAct (act_kind a)
    (render_assertions (assertions a))"
primrec act_claims where
  "act_claims (ShownAct k cs) = map (\<lambda>(c,e). (read_claim c,e)) cs"
lemma act_claims_correspondence:
  "act_claims (render_act a) = map (\<lambda>(c,e). (Some c,e)) (assertions a)"
  by (simp add: render_act_def embedded_assertions_preserved)
definition assertions_licensed where
  "assertions_licensed available xs \<longleftrightarrow> set xs \<subseteq> set available"
lemma rendered_act_no_new_claim:
  assumes "assertions_licensed available (assertions a)"
    "(Some c,e) \<in> set (act_claims (render_act a))"
  shows "(c,e) \<in> set available"
  using assms by (auto simp: assertions_licensed_def act_claims_correspondence)

text \<open>Only current live published bindings supply authoritative claims.
Accepted tags in a historical subgoal list are insufficient after authority changes.
Proposed commentary is deliberately absent from the controlled output type.\<close>
definition live_assertions where
  "live_assertions s rid = map (\<lambda>b. (binding_claim b,binding_evidence b))
    (filter (\<lambda>b. binding_request b = rid \<and> binding_licensed s b)
      (visible_bindings s))"
definition authoritative_render where
  "authoritative_render s rid a =
    (if assertions_licensed (live_assertions s rid) (assertions a)
     then Some (render_act a) else None)"
lemma authoritative_render_live:
  assumes "authoritative_render s rid a = Some rendered"
    "(Some c,e) \<in> set (act_claims rendered)"
  shows "\<exists>b\<in>set (visible_bindings s).
    binding_request b = rid \<and> binding_claim b = c \<and>
    binding_evidence b = e \<and> binding_licensed s b"
proof -
  from assms have license: "assertions_licensed (live_assertions s rid) (assertions a)"
    and mem: "(Some c,e) \<in> set (act_claims (render_act a))"
    by (auto simp: authoritative_render_def split: if_splits)
  from rendered_act_no_new_claim[OF license mem] show ?thesis
    by (auto simp: live_assertions_def)
qed
lemma no_live_bindings_no_authoritative_assertions:
  assumes "\<forall>b\<in>set (visible_bindings s). \<not> binding_licensed s b"
    "assertions a \<noteq> []"
  shows "authoritative_render s rid a = None"
  using assms by (auto simp: authoritative_render_def assertions_licensed_def
    live_assertions_def filter_empty_conv)
lemma commentary_not_emitted:
  "render_act (a\<lparr>proposed_commentary := text\<rparr>) = render_act a"
  by (simp add: render_act_def)

datatype rendered_requirement = ShownClaimRequirement "clause list" |
  ShownArtifactRequirement artifact_requirement

primrec render_requirement :: "goal_requirement \<Rightarrow> rendered_requirement" where
  "render_requirement (ClaimRequirement c)=ShownClaimRequirement (render_claim c)" |
  "render_requirement (ArtifactRequirement a)=ShownArtifactRequirement a"
primrec read_requirement :: "rendered_requirement \<Rightarrow> goal_requirement option" where
  "read_requirement (ShownClaimRequirement cs)=map_option ClaimRequirement (read_claim cs)" |
  "read_requirement (ShownArtifactRequirement a)=Some (ArtifactRequirement a)"
lemma requirement_rendering_correspondence:
  "read_requirement (render_requirement required)=Some required"
  by (cases required) (simp_all add: claim_rendering_correspondence)
lemma artifact_requirement_not_rendered_as_claim:
  "render_requirement (ArtifactRequirement a) \<noteq> ShownClaimRequirement cs"
  by simp

definition render_parts where
  "render_parts gs = map (\<lambda>g. (goal_id g, goal_interpretation g,
    goal_dependencies g, goal_output_slot g, render_requirement (goal_required g),
    render_outcome (goal_outcome g))) gs"
lemma per_part_outcome_preserved:
  "(i,r,ds,slot,required,ro) \<in> set (render_parts gs) \<Longrightarrow>
    \<exists>g\<in>set gs. i = goal_id g \<and> r = goal_interpretation g \<and>
      ds = goal_dependencies g \<and> slot = goal_output_slot g \<and>
      read_requirement required = Some (goal_required g) \<and>
      read_outcome ro = Some (goal_outcome g)"
  by (auto simp: render_parts_def outcome_rendering_correspondence requirement_rendering_correspondence)
definition all_parts_accepted where
  "all_parts_accepted gs \<longleftrightarrow> gs \<noteq> [] \<and> list_all (\<lambda>g. accepted (goal_outcome g)) gs"
lemma failed_part_prevents_complete:
  "g \<in> set gs \<Longrightarrow> goal_outcome g = Failed n \<Longrightarrow> \<not> all_parts_accepted gs"
  by (fastforce simp: all_parts_accepted_def list_all_iff)

text \<open>Routing uses the authority machine's unblocked judgment directly.
Discharge metadata is not an independent language-side unblocking mechanism.\<close>
lemma fallback_cannot_evade_interpretation_block:
  assumes "b \<in> set (request_blockers r)"
    "blocked_scope b = InterpretationScope (goal_interpretation g)"
  shows "\<not> unblocked r g"
  using assms by (fastforce simp: unblocked_def list_all_iff)
lemma unrelated_reading_remains_available:
  assumes "request_blockers r = [b]"
    "blocked_scope b = InterpretationScope i" "goal_interpretation g \<noteq> i"
  shows "unblocked r g"
  using assms by (simp add: unblocked_def)

export_code specialist_request render_claim read_claim render_requirement read_requirement render_outcome render_parts
  render_act authoritative_render in SML module_name Veri7vn_Language

end
