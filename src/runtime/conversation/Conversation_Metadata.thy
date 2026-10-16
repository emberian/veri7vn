theory Conversation_Metadata
  imports Veri7vn_Authority_Codec.Authority_Codec
    Veri7vn_Observation_Pin.Observation_Pin
begin

text \<open>Conversation consumers use the existing authority state. These fixed
constructors do not introduce another session registry or an accepted-answer
constructor. A context is read from the current authority before a native parent
is prepared; its complete read and clock fields remain part of that parent.\<close>

definition conversation_clock :: "clock_basis \<Rightarrow> int \<Rightarrow> clock_reading" where
  "conversation_clock origin value = \<lparr>basis=origin,ticks=value\<rparr>"
definition conversation_observation :: "nat \<Rightarrow> nat \<Rightarrow> clock_reading option \<Rightarrow>
    (nat \<times> nat) list \<Rightarrow> observation_context" where
  "conversation_observation sid version evaluated reads =
    \<lparr>observed_session=sid,observed_version=version,evaluation_time=evaluated,observed_reads=reads\<rparr>"

definition conversation_create :: "nat \<Rightarrow> event" where
  "conversation_create sid = UpdateObservation
    \<lparr>observed_session=sid, observed_version=0,
      evaluation_time=None, observed_reads=[]\<rparr>"

definition conversation_retained :: "observation_context \<Rightarrow> nat \<Rightarrow> retention_scope \<Rightarrow>
    nat list \<Rightarrow> nat list \<Rightarrow> retained_value" where
  "conversation_retained context value owner deps reads =
    \<lparr>retained_id=value,retained_owner=owner,
      retained_dependencies=remdups (observed_session context # map fst (observed_reads context) @ deps),
      retained_read_dependencies=reads,
      retained_access_requirements=[RequireAccess context None],retained_payload=value\<rparr>"

definition conversation_input :: "observation_context \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> event" where
  "conversation_input context input source_deps = RegisterManaged (conversation_retained context input
    (SessionLocal (observed_session context)) source_deps [])"

text \<open>D65 uses a distinct nonassertional source inventory. The original
context is carried by the exact retained access row. Source-context generation is
deliberately absent: the fixed native source reconstruction supplies its actual
positive head and must reproduce the whole row, including its complete native
source/context dependencies. Pending source registration is itself durable, even
before the separate RecordUtterance acknowledgement.\<close>
type_synonym conversation_input_requirement = "nat \<times> retained_value \<times> observation_context \<times> bool"

definition conversation_input_context :: "authority_state \<Rightarrow> retained_value \<Rightarrow> observation_context option" where
  "conversation_input_context s value = (case (retained_owner value,retained_access_requirements value) of
    (SessionLocal sid,[RequireAccess original None]) \<Rightarrow>
      (if observed_session original=sid \<and> retained_payload value=retained_id value \<and>
        retained_read_dependencies value=[] \<and>
        list_all (\<lambda>n. n\<in>set (retained_dependencies value))
          (sid # map fst (observed_reads original)) \<and>
        accessible s (retained_id value # retained_dependencies value) \<and>
        (\<exists>view\<in>set (session_views s). session_id view=sid)
       then Some original else None)
    | _ \<Rightarrow> None)"

definition conversation_input_recorded :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "conversation_input_recorded s sid input = (\<exists>view\<in>set (session_views s).
    session_id view=sid \<and> input\<in>set (recorded_utterances view))"

definition conversation_required_inputs :: "authority_state \<Rightarrow> conversation_input_requirement list" where
  "conversation_required_inputs s = List.map_filter (\<lambda>value.
    map_option (\<lambda>original. (retained_id value,value,original,
      conversation_input_recorded s (observed_session original) (retained_id value)))
      (conversation_input_context s value)) (retained_values s)"

text \<open>The fixed native source checker supplies the original full observation
and genuine reconstructed native source dependencies. Equality is against the
whole original retained row; a membership/category route is insufficient. The
phase is derived from the checkpoint, never from the saved material.\<close>
definition conversation_source_phase :: "authority_state \<Rightarrow> nat \<Rightarrow> observation_context \<Rightarrow>
    nat list \<Rightarrow> bool option" where
  "conversation_source_phase s input original source_deps =
    (let expected=conversation_retained original input (SessionLocal (observed_session original)) source_deps []
     in if expected\<in>set (retained_values s) \<and> conversation_input_context s expected=Some original
        then Some (conversation_input_recorded s (observed_session original) input) else None)"

definition conversation_input_current_access :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "conversation_input_current_access s sid input = (\<exists>value\<in>set (retained_values s).
    retained_id value=input \<and> (case conversation_input_context s value of None \<Rightarrow> False
      | Some original \<Rightarrow> observed_session original=sid \<and>
        list_all (observation_fresh s) (retained_access_requirements value)))"

definition conversation_input_visible :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "conversation_input_visible s sid input = (conversation_input_recorded s sid input \<and>
    conversation_input_current_access s sid input \<and> accessible s [sid,input])"

definition conversation_context :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> observation_context option" where
  "conversation_context s sid expected = (case find (\<lambda>v. session_id v=sid)
    (session_views s) of None \<Rightarrow> None | Some view \<Rightarrow>
      (if session_version view\<noteq>expected \<or> \<not> accessible s [sid] then None else
        find (\<lambda>context. observed_session context=sid \<and>
          observed_version context=expected \<and>
          accessible s (sid # map fst (observed_reads context))) (current_observations s)))"

definition conversation_request_matches :: "observation_context \<Rightarrow> request \<Rightarrow> bool" where
  "conversation_request_matches context r = (request_session r=Some (observed_session context) \<and>
    request_observation r=RequireObservation context None \<and> list_all (\<lambda>n.
      n\<in>set (request_dependencies r))
      (observed_session context # map fst (observed_reads context)))"

text \<open>These first-profile adapters operate on fresh actual native mathematics
events before persistence. The original construction must already carry the
whole independently owned source closure. Missing dependencies refuse adaptation;
the adapters never rewrite a native claim's dependencies or create an input row.\<close>
definition conversation_has_source_dependencies :: "observation_context \<Rightarrow> nat list \<Rightarrow>
    nat list \<Rightarrow> bool" where
  "conversation_has_source_dependencies original source_deps actual =
    (source_deps\<noteq>[] \<and> 0\<notin>set source_deps \<and> observed_session original>0 \<and>
      list_all (\<lambda>n. n\<in>set actual)
        (observed_session original # map fst (observed_reads original) @ source_deps))"

definition conversation_bind_reserve :: "observation_context \<Rightarrow> nat list \<Rightarrow> event \<Rightarrow> event option" where
  "conversation_bind_reserve original source_deps proposed = (case proposed of ReserveRequest r slots \<Rightarrow>
    (if request_session r=None \<and> request_observation r=StateTimeUnused \<and>
      length (request_goals r)=1 \<and> length slots=1 \<and>
      conversation_has_source_dependencies original source_deps (request_dependencies r) \<and>
      list_all (\<lambda>g. case goal_required g of ClaimRequirement c \<Rightarrow>
        conversation_has_source_dependencies original source_deps (dependencies c) | _ \<Rightarrow> False)
        (request_goals r) \<and>
      list_all (\<lambda>slot. output_owner slot=request_id r \<and>
        conversation_has_source_dependencies original source_deps (output_reserved_dependencies slot)) slots
     then Some (ReserveRequest (r\<lparr>request_session:=Some (observed_session original),
       request_observation:=RequireObservation original None\<rparr>) slots) else None)
    | _ \<Rightarrow> None)"

definition conversation_bind_parameter :: "observation_context \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow>
    nat \<Rightarrow> event \<Rightarrow> event option" where
  "conversation_bind_parameter original source_deps rid input proposed = (case proposed of RegisterManaged value \<Rightarrow>
    (if rid>0 \<and> input>0 \<and> input\<in>set source_deps \<and> retained_id value\<noteq>input \<and>
      retained_owner value=RequestLocal rid \<and> retained_payload value=retained_id value \<and>
      retained_read_dependencies value=[input] \<and> retained_access_requirements value=[] \<and>
      conversation_has_source_dependencies original source_deps (retained_dependencies value)
     then Some (RegisterManaged (value\<lparr>retained_access_requirements:=[RequireAccess original None]\<rparr>)) else None)
    | _ \<Rightarrow> None)"

definition conversation_bind_output :: "observation_context \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow>
    nat \<Rightarrow> event \<Rightarrow> event option" where
  "conversation_bind_output original source_deps rid parameter proposed = (case proposed of
    StageOutput batch (ClaimOutput assignment) None \<Rightarrow>
      (if rid>0 \<and> parameter>0 \<and> binding_request (assigned_binding assignment)=rid \<and>
        conversation_has_source_dependencies original source_deps (assigned_dependencies assignment) \<and>
        conversation_has_source_dependencies original source_deps (dependencies (assigned_requirement assignment)) \<and>
        conversation_has_source_dependencies original source_deps (dependencies (binding_claim (assigned_binding assignment))) \<and>
        assigned_retained assignment\<noteq>[] \<and>
        list_all (\<lambda>value. retained_owner value=RequestLocal rid \<and>
          retained_payload value=retained_id value \<and> retained_read_dependencies value=[parameter] \<and>
          retained_access_requirements value=[] \<and>
          conversation_has_source_dependencies original source_deps (retained_dependencies value))
          (assigned_retained assignment)
       then Some (StageOutput batch (ClaimOutput (assignment\<lparr>assigned_retained:=map
         (\<lambda>value. value\<lparr>retained_access_requirements:=[RequireAccess original None]\<rparr>)
         (assigned_retained assignment)\<rparr>)) None) else None)
    | _ \<Rightarrow> None)"

definition conversation_context_projection where
  "conversation_context_projection context = (observed_session context,
    observed_version context,evaluation_time context,observed_reads context)"

definition conversation_record :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> event option" where
  "conversation_record s sid rid utterance = (if accessible s [sid,utterance] \<and>
    conversation_input_current_access s sid utterance \<and>
    (\<exists>v\<in>set (session_views s). session_id v=sid \<and>
      utterance\<notin>set (recorded_utterances v)) \<and>
    (\<exists>r\<in>set (requests s). request_id r=rid \<and> request_session r=Some sid \<and>
      utterance\<in>set (request_dependencies r))
    then Some (RecordUtterance sid utterance) else None)"

fun conversation_terminal :: "outcome \<Rightarrow> bool" where
  "conversation_terminal (AwaitingOutput slot) = False" |
  "conversation_terminal outcome = True"

definition conversation_final_bindings :: "authority_state \<Rightarrow> nat \<Rightarrow> binding list" where
  "conversation_final_bindings s rid = filter (\<lambda>b.
    binding_request b=rid \<and> binding_licensed s b) (visible_bindings s)"

text \<open>The selected bindings come from the fixed native finalizer's exhaustive
typed output cases, not a client list. For mathematics only its Exact display may
enter this set. A licensed observation of Undefined is still a user decline. The
state supplies the actual ordered bindings, and rejects a different selection.\<close>
definition conversation_adoption :: "authority_state \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> binding list \<Rightarrow> event option" where
  "conversation_adoption s rid nonce selected = (case find (\<lambda>r. request_id r=rid)
    (requests s) of None \<Rightarrow> None | Some r \<Rightarrow>
    (case request_session r of None \<Rightarrow> None | Some sid \<Rightarrow>
      (case find (\<lambda>v. session_id v=sid) (session_views s) of None \<Rightarrow> None | Some view \<Rightarrow>
        (let bs=filter (\<lambda>b. b\<in>set selected) (conversation_final_bindings s rid);
             d=\<lparr>adoption_request=rid, adoption_session=sid,
               adoption_expected_version=session_version view, adoption_bindings=bs\<rparr>
         in if bs\<noteq>[] \<and> bs=selected \<and> distinct selected \<and>
           list_all (conversation_terminal \<circ> goal_outcome) (request_goals r) \<and>
           \<not> (\<exists>b\<in>set (adopted_bindings view). binding_request b=rid) \<and>
           adoption_permitted s rid d
         then Some (StageAdoption nonce rid d) else None))))"

definition conversation_proposed_adoption :: "observation_context \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow>
    binding list \<Rightarrow> event" where
  "conversation_proposed_adoption original rid nonce selected = StageAdoption nonce rid
    \<lparr>adoption_request=rid,adoption_session=observed_session original,
      adoption_expected_version=observed_version original,adoption_bindings=selected\<rparr>"
definition conversation_adoption_matches :: "authority_state \<Rightarrow> event \<Rightarrow> bool" where
  "conversation_adoption_matches s proposed = (case proposed of StageAdoption nonce rid delta \<Rightarrow>
    conversation_adoption s rid nonce (adoption_bindings delta)=Some proposed | _ \<Rightarrow> False)"

text \<open>After adoption the session CAS advances. Its old answer is therefore
historical, and cannot be rendered through current binding_licensed. Quotation
instead requires the actual retained adoption and accessible evidence. The fixed
native consumer additionally checks the reconstructed witness and preserves the
original request observation and complete claim. This predicate never licenses
execution, a new assertion, or a current follow-up binding.\<close>
definition conversation_quotable :: "authority_state \<Rightarrow> nat \<Rightarrow> binding \<Rightarrow> bool" where
  "conversation_quotable s sid b = (accessible s [sid] \<and>
    (\<exists>view\<in>set (session_views s). session_id view=sid \<and>
      b\<in>set (adopted_bindings view)) \<and>
    b\<in>set (visible_bindings s) \<and>
    accessible s (binding_managed_dependencies s b) \<and>
    list_all (\<lambda>v. retained_id v\<in>set (binding_managed_dependencies s b) \<longrightarrow>
      list_all (observation_fresh s) (retained_access_requirements v)) (retained_values s) \<and>
    (\<exists>r\<in>set (requests s). request_id r=binding_request b \<and>
      request_session r=Some sid \<and> \<not> request_cancelled r \<and>
      parent_accessible s r \<and>
      (\<exists>g\<in>set (request_goals r). goal_id g=binding_goal b \<and>
        child_accessible s g \<and> unblocked r g \<and>
        goal_outcome g=Accepted (binding_claim b) (binding_evidence b))) \<and>
    (\<exists>e\<in>set (evidence_table s). evidence_id e=binding_evidence b \<and>
      evidence_claim e=binding_claim b \<and> evidence_accessible s e))"

definition conversation_history :: "authority_state \<Rightarrow> nat \<Rightarrow> binding list" where
  "conversation_history s sid = concat (map (\<lambda>view.
    filter (conversation_quotable s sid) (adopted_bindings view))
      (filter (\<lambda>view. session_id view=sid) (session_views s)))"

definition conversation_checkpoint_supported :: "authority_state \<Rightarrow> bool" where
  "conversation_checkpoint_supported s = (distinct (map session_id (session_views s)) \<and>
    distinct (map observed_session (current_observations s)) \<and>
    list_all (\<lambda>context. \<exists>view\<in>set (session_views s).
      observed_session context=session_id view \<and>
      observed_version context=session_version view) (current_observations s) \<and>
    list_all (\<lambda>view. distinct (recorded_utterances view) \<and>
      list_all (\<lambda>b. b\<in>set (visible_bindings s) \<and>
        (\<exists>r\<in>set (requests s). request_id r=binding_request b \<and>
          request_session r=Some (session_id view))) (adopted_bindings view)) (session_views s))"

lemma conversation_context_exact:
  "conversation_context s sid expected = Some context \<Longrightarrow>
    context\<in>set (current_observations s) \<and> observed_session context=sid \<and>
    observed_version context=expected \<and>
    accessible s (sid # map fst (observed_reads context))"
  by (auto simp: conversation_context_def find_Some_iff split: option.splits if_splits)

lemma conversation_adoption_only_final_licensed:
  assumes "conversation_adoption s rid nonce selected = Some (StageAdoption n owner d)"
    "b\<in>set (adoption_bindings d)"
  shows "owner=rid \<and> binding_request b=rid \<and> b\<in>set (visible_bindings s) \<and> binding_licensed s b"
  using assms by (auto simp: conversation_adoption_def conversation_final_bindings_def
    Let_def split: option.splits if_splits)

lemma conversation_quote_requires_adoption:
  "conversation_quotable s sid b \<Longrightarrow>
    \<exists>view\<in>set (session_views s). session_id view=sid \<and> b\<in>set (adopted_bindings view)"
  by (auto simp: conversation_quotable_def)

lemma conversation_quote_denied_session:
  "\<not> accessible s [sid] \<Longrightarrow> \<not> conversation_quotable s sid b"
  by (simp add: conversation_quotable_def)

ML_file \<open>native_conversation.ML\<close>

end
