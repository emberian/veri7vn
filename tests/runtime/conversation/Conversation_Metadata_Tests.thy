theory Conversation_Metadata_Tests
  imports Veri7vn_Conversation_Metadata.Conversation_Metadata
begin

lemma absent_session_cannot_pin:
  "session_views s=[] \<Longrightarrow> conversation_context s sid expected=None"
  by (simp add: conversation_context_def)

lemma inaccessible_session_cannot_quote:
  "\<not> accessible s [sid] \<Longrightarrow> conversation_history s sid=[]"
  by (simp add: conversation_history_def conversation_quotable_def)

lemma request_pin_preserves_full_observation:
  "conversation_request_matches context r \<Longrightarrow>
    request_observation r=RequireObservation context None \<and>
    request_session r=Some (observed_session context) \<and>
    set (map fst (observed_reads context)) \<subseteq> set (request_dependencies r)"
  by (auto simp: conversation_request_matches_def list_all_iff)

definition binding_test_observation where
  "binding_test_observation=conversation_observation 10 0 None [(11,3)]"
definition binding_test_parameter where
  "binding_test_parameter deps=RegisterManaged
    \<lparr>retained_id=21,retained_owner=RequestLocal 20,retained_dependencies=deps,
      retained_read_dependencies=[12],retained_access_requirements=[],retained_payload=21\<rparr>"
lemma fresh_parameter_requires_original_source_context:
  "conversation_bind_parameter binding_test_observation [12,13] 20 12
    (binding_test_parameter [10,11,12])=None"
  by eval
lemma fresh_parameter_preserves_dependencies_and_copies_access:
  "conversation_bind_parameter binding_test_observation [12,13] 20 12
    (binding_test_parameter [10,11,12,13])=Some (RegisterManaged
      \<lparr>retained_id=21,retained_owner=RequestLocal 20,retained_dependencies=[10,11,12,13],
        retained_read_dependencies=[12],retained_access_requirements=[RequireAccess binding_test_observation None],
        retained_payload=21\<rparr>)"
  by eval
lemma fresh_parameter_cannot_rebind_another_input:
  "conversation_bind_parameter binding_test_observation [12,13] 20 99
    (binding_test_parameter [10,11,12,13,99])=None"
  by eval
lemma empty_source_closure_cannot_bind_reservation:
  "conversation_bind_reserve original [] (ReserveRequest r slots)=None"
  by (simp add: conversation_bind_reserve_def conversation_has_source_dependencies_def)

lemma adoption_waits_for_all_children:
  assumes "requests s=[r]" "request_id r=rid" "g\<in>set (request_goals r)"
    "goal_outcome g=AwaitingOutput slot"
  shows "conversation_adoption s rid nonce selected=None"
  using assms by (auto simp: conversation_adoption_def Let_def list_all_iff split: option.splits)

lemma observation_cas_advances_past_original:
  "\<not> authority_fresh (context\<lparr>observed_version:=Suc (observed_version context)\<rparr>)
    (RequireObservation context None)"
  by (simp add: authority_fresh_def)

lemma quotation_requires_retained_native_evidence:
  assumes "conversation_quotable s sid b"
  shows "\<exists>e\<in>set (evidence_table s). evidence_id e=binding_evidence b \<and>
    evidence_claim e=binding_claim b \<and> evidence_accessible s e"
  using assms by (auto simp: conversation_quotable_def)

lemma quotation_rechecks_managed_access:
  assumes "conversation_quotable s sid b" "v\<in>set (retained_values s)"
    "retained_id v\<in>set (binding_managed_dependencies s b)"
  shows "list_all (observation_fresh s) (retained_access_requirements v)"
  using assms by (auto simp: conversation_quotable_def list_all_iff)

lemma forgotten_session_has_no_quote:
  assumes "sid\<in>set removed"
  shows "\<not> conversation_quotable (forget_state removed s) sid b"
  using assms by (auto simp: conversation_quotable_def forget_state_def revoke_state_def
    accessible_def)

lemma source_phase_requires_whole_original_row:
  assumes "conversation_source_phase s input original source_deps=Some recorded"
  shows "conversation_retained original input (SessionLocal (observed_session original)) source_deps []
      \<in>set (retained_values s) \<and>
    recorded=conversation_input_recorded s (observed_session original) input"
  using assms by (auto simp: conversation_source_phase_def Let_def split: if_splits)

lemma source_absent_row_cannot_restore:
  assumes "retained_values s=[]"
  shows "conversation_source_phase s input original source_deps=None"
  using assms by (simp add: conversation_source_phase_def Let_def)

lemma another_session_cannot_read_source:
  assumes "\<And>value original. value\<in>set (retained_values s) \<Longrightarrow>
    retained_id value=input \<Longrightarrow> conversation_input_context s value=Some original \<Longrightarrow>
    observed_session original\<noteq>sid"
  shows "\<not> conversation_input_current_access s sid input"
  using assms by (auto simp: conversation_input_current_access_def split: option.splits)

lemma source_inventory_keeps_exact_original:
  assumes "(input,value,original,recorded)\<in>set (conversation_required_inputs s)"
  shows "value\<in>set (retained_values s) \<and> retained_id value=input \<and>
    conversation_input_context s value=Some original \<and>
    recorded=conversation_input_recorded s (observed_session original) input"
  using assms by (auto simp: conversation_required_inputs_def List.map_filter_def split: option.splits)

ML \<open>
local
  structure P=Veri7vn_Native_Observation_Pin;
  val owner=P.new_issuer();
  val foreign=P.new_issuer();
  val original={workspace="c0de0000000000000000000000000003",session=12,version=7,
    evaluation_time=SOME {basis=P.SourceEvent "original-clock",ticks= ~9},reads=[(91,4)]}:P.snapshot;
  val pin=P.mint owner original;
  val sibling=P.retain pin;
  val _=if P.matches owner pin original andalso not(P.matches foreign pin original) andalso
      P.dependencies pin=[12,91] then () else error "Observation pin lost issuer/full dependency identity";
  val _=P.release pin;
  val _=if not(P.live pin) andalso P.live sibling andalso P.snapshot sibling=original
    then () else error "Releasing producer view invalidated retained observation";
  val _=if not(P.matches owner sibling {workspace= #workspace original,session=12,version=8,
      evaluation_time= #evaluation_time original,reads= #reads original})
    then () else error "Observation pin accepted changed session CAS";
  val _=if Exn.is_exn(Exn.capture (P.invalidate foreign) sibling)
    then () else error "Foreign issuer invalidated another issuer's pin";
  val _=P.invalidate owner sibling;
  val _=if not(P.live sibling) andalso Exn.is_exn(Exn.capture P.snapshot sibling)
    then () else error "Invalidated observation pin revived";
  val _=P.release sibling;
  val _=P.release sibling;
in val _=writeln "CONVERSATION_OBSERVATION_PIN_PASS private_issuer exact_snapshot source_clock read_refs_not_versions retained_view monotone_invalidation" end
\<close>

ML \<open>
local
  structure C=Veri7vn_Conversation_Display;
  val original={session=12,version=0,clock=SOME {kind="source_event",origin="sensor",ticks= ~9},reads=[(91,4)]}:C.observation;
  val current={session=12,version=1,clock= #clock original,reads= #reads original}:C.observation;
  val claim={claim=21,target=22,interpretation=23,evidence=24,semantic_generation=25,
    executable_generation=NONE,route="kernel_consequence",kind="source_observation",
    modality="conditional",collection="prefix:5",optimality="feasible",premises=[90],dependencies=[91]}:C.claim;
  val quote={claim=claim,observation=original,html="<p>Historical conditional observation.</p>"}:C.quotation;
  val child={goal=32,slot=33,status="historical",predecessors=[],quotation=SOME quote}:C.part;
  val turn={request=30,utterance=31,input_encoding="UTF-8",input="a  b\n",observation=original,parts=[child]}:C.turn;
  val encoded=C.view{id=12,version=1,status=C.Active,observation=SOME current,turns=[turn],complete=true};
  val _=C.require(String.isSubstring "612020620a" encoded andalso
    String.isSubstring "ticks=-9" encoded)
    "Conversation wire lost original bytes or signed source clock";
  val _=C.require(Exn.is_exn(Exn.capture C.view
    {id=12,version=1,status=C.Expired,observation=NONE,turns=[turn],complete=true}))
    "Expired conversation exposed payload";
  val _=C.require(Exn.is_exn(Exn.capture C.part
    {goal=32,slot=33,status="pending",predecessors=[],quotation=SOME quote}))
    "Pending conversation child exposed historical quotation";
in val _=writeln "CONVERSATION_NATIVE_PROJECTION_PASS original_bytes signed_clock historical_conditions no_pending_quote expired_payload_denied" end
\<close>

end
