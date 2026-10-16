theory Authority_Runtime_Tests
  imports Veri7vn_Authority_Fixtures.Authority_Fixtures
begin

text \<open>This ML consumer calls the generated function itself. No handwritten
acceptance transition is substituted. Both valid lifecycle commands and rejected
unbacked acknowledgement execute through that compiled function.\<close>

ML \<open>
  val base = @{code initial_state};
  val key = Veri7vn_Numerals.nat_of_integer 17;
  val (retired, commands) = @{code step} base (@{code RetireCapability} key);
  val _ = if @{code retired_capabilities} retired = [key] then ()
    else error "generated retirement failed";
  val _ = if length commands = 1 then () else error "missing epoch command";
  val (unbacked, rejection) = @{code step} base
    (@{code DurableAck} (key, key, key));
  val _ = if @{code revision} unbacked = @{code revision} base andalso
    length rejection = 1 then () else error "unbacked ack accepted";
  val _ = writeln "VERI7VN_MODEL generated_step PASS";
\<close>

text \<open>Synthetic authority metadata fixtures test the generated guards, not native
admission or mathematical truth. Production events require protected native origins.\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val step = @{code step};
  val computed = @{code slot_computed_fixture};
  val assignment = @{code slot_assignment_fixture};
  fun require true _ = () | require false message = error message;
  val _ = require (@{code request_fuel} (hd (@{code requests} computed)) = n 9)
    "whole pure operation did not charge request fuel";
  val _ = (case @{code required_for} computed @{code slot_request_fixture} @{code slot_goal_fixture} of
    NONE => () | SOME _ => error "unbound output became a live concrete requirement");
  val (staged, _) = step computed (@{code StageOutput} (n 33,@{code ClaimOutput} assignment,NONE));
  val _ = require (null (@{code output_assignments} staged) andalso null (@{code visible_bindings} staged))
    "staging installed output before durable acknowledgement";
  val published = @{code slot_published_fixture};
  val _ = require (length (@{code output_assignments} published) = 1 andalso
      length (@{code visible_bindings} published) = 1 andalso
      @{code binding_licensed} published @{code slot_result_binding})
    "checked output not licensed after exact acknowledgement";
  val (duplicate, _) = step published (@{code StageOutput} (n 35,@{code ClaimOutput} assignment,NONE));
  val _ = require (@{code pending_batch} duplicate = NONE) "one-shot output rebound";
  val (private_rejected, _) = step computed (@{code StageOutput} (n 36,@{code ClaimOutput} @{code missing_private_fixture},NONE));
  val _ = require (@{code pending_batch} private_rejected = NONE)
    "private native provenance omitted from retained derivative";
  val (unauthorized, _) = step published (@{code StageRetention} (n 37,n 8,n 19,@{code SessionLocal} (n 42)));
  val _ = require (@{code pending_batch} unauthorized = NONE) "promotion without policy grant accepted";
  val followup = @{code followup_fixture};
  val _ = require (@{code inputs_accessible_to} followup (n 60) [n 19])
    "same-session retained followup denied";
  val _ = require (not (@{code inputs_accessible_to} followup (n 61) [n 19]))
    "cross-session retained followup admitted";
  val changed_reads = @{code UpdateObservation}
    (@{code lease_changed_reads_fixture});
  val (read_changed, _) = step followup changed_reads;
  val _ = require (not (@{code inputs_accessible_to} read_changed (n 60) [n 19]))
    "state-unused followup laundered changed source access";
  val (expired, _) = step followup (@{code UpdateObservation} @{code lease_expired_fixture});
  val _ = require (not (@{code inputs_accessible_to} expired (n 60) [n 19]))
    "state-unused followup laundered expired access";
  val (session_invalid, _) = step followup (@{code Revoke} (n 42));
  val _ = require (not (@{code inputs_accessible_to} session_invalid (n 60) [n 19]))
    "invalidated session retained access";
  val (forgotten, _) = step followup (@{code Forget} (n 100));
  val _ = require (not (@{code inputs_accessible_to} forgotten (n 60) [n 19]) andalso
      null (@{code output_assignments} forgotten))
    "forgotten private-only provenance left promoted derivative usable";
  val _ = require (exists (fn v => @{code retained_id} v = n 300) (@{code retained_values} forgotten))
    "forget erased unrelated public object";
  val (forgotten_session, _) = step followup (@{code Forget} (n 42));
  val _ = require (not (exists (fn v => @{code session_id} v = n 42)
      (@{code session_views} forgotten_session)) andalso
    not (exists (fn v => @{code observed_session} v = n 42)
      (@{code current_observations} forgotten_session)))
    "forget retained erased session view or clock observation";
  val (stale_forget, forget_reply) = step forgotten_session
    (@{code UpdateObservation} @{code lease_context_fixture});
  val _ = require (stale_forget = forgotten_session andalso length forget_reply = 1)
    "stale observation token resurrected forgotten session";
  val (stale_revoke, revoke_reply) = step session_invalid
    (@{code UpdateObservation} @{code lease_changed_reads_fixture});
  val _ = require (stale_revoke = session_invalid andalso length revoke_reply = 1)
    "stale observation token refreshed revoked session";
  val (surviving, surviving_reply) = step forgotten_session
    (@{code UpdateObservation} @{code surviving_context_fixture});
  val _ = require (null surviving_reply andalso
    exists (fn v => @{code observed_session} v = n 43) (@{code current_observations} surviving))
    "unrelated surviving session observation denied";
  val (utterances, _) = step @{code slot_ready_fixture} (@{code RecordUtterance} (n 42,n 400));
  val (erased_utterance, _) = step utterances (@{code Forget} (n 400));
  val _ = require (forall (fn v => not (member (op =) (@{code recorded_utterances} v) (n 400)))
    (@{code session_views} erased_utterance)) "forget retained erased transcript identifier";
  val (read_revoked, _) = step followup (@{code Revoke} (n 77));
  val _ = require (not (@{code observation_fresh} read_revoked @{code lease_condition_fixture}))
    "revoked read remained a fresh access observation";
  val (stale_read_revoke, revoked_read_reply) = step read_revoked
    (@{code UpdateObservation} @{code lease_changed_reads_fixture});
  val _ = require (stale_read_revoke = read_revoked andalso length revoked_read_reply = 1)
    "stale refresh revived revoked read";
  val (read_forgotten, _) = step followup (@{code Forget} (n 77));
  val (stale_read_forget, forgotten_read_reply) = step read_forgotten
    (@{code UpdateObservation} @{code lease_changed_reads_fixture});
  val _ = require (stale_read_forget = read_forgotten andalso length forgotten_read_reply = 1)
    "stale refresh revived forgotten read";
  val (stale_cas, stale_cas_reply) = step read_forgotten
    (@{code UpdateObservation} @{code stale_cas_fixture});
  val _ = require (stale_cas = read_forgotten andalso length stale_cas_reply = 1)
    "removed observation allowed surviving session CAS rollback";
  val (unaffected_read, unaffected_read_reply) = step read_forgotten
    (@{code UpdateObservation} @{code unaffected_read_fixture});
  val _ = require (null unaffected_read_reply andalso
    exists (fn v => @{code observed_reads} v = [(n 78,n 1)])
      (@{code current_observations} unaffected_read)) "unaffected current-CAS read refresh denied";
  val (reinserted_utterance, utterance_reply) = step erased_utterance
    (@{code RecordUtterance} (n 42,n 400));
  val _ = require (reinserted_utterance = erased_utterance andalso length utterance_reply = 1)
    "forgotten managed utterance reinserted by stale token";
  val _ = writeln "VERI7VN_MODEL slot_retention_private_closure PASS";
\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val before_forget = @{code followup_fixture};
  val (after_forget, removals) = @{code step} before_forget (@{code ForgetRoots} [n 100,n 13]);
  val _ = if not (@{code inputs_accessible_to} after_forget (n 60) [n 19]) andalso
      null (@{code output_assignments} after_forget) andalso
      forall (fn root => member (op =) (@{code forgotten_objects} after_forget) root) [n 100,n 13,n 19]
    then () else error "Atomic root closure retained private derivative";
  val _ = if @{code authority_epoch} after_forget =
      Veri7vn_Numerals.nat_of_integer 1 andalso
      exists (fn v => @{code retained_id} v = n 300) (@{code retained_values} after_forget)
    then () else error "Atomic root forget changed unrelated history or repeated epoch";
  val _ = if @{code step} before_forget (@{code Forget} (n 100)) =
      @{code step} before_forget (@{code ForgetRoots} [n 100]) then ()
    else error "Singleton Forget compatibility changed";
  val _ = writeln "VERI7VN_MODEL forget_roots_closure PASS";
\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val computed = @{code artifact_computed_fixture};
  val assignment = @{code ArtifactOutput} @{code artifact_assignment_fixture};
  val (staged, _) = @{code step} computed (@{code StageOutput} (n 541,assignment,NONE));
  val _ = if is_some (@{code pending_batch} staged) andalso null (@{code output_assignments} staged)
    then () else error "Artifact failed staging or became visible before acknowledgement";
  val (ready,_) = @{code step} staged (@{code DurableAck} (n 541,n 1,n 0));
  val ready_request = hd (@{code requests} ready);
  val ready_goal = hd (@{code request_goals} ready_request);
  val _ = if null (@{code visible_bindings} ready) andalso null (@{code evidence_table} ready)
    then () else error "Artifact licensed a claim or evidence";
  val _ = if length (@{code required_native_artifacts} ready)=1
    then () else error "Acknowledged artifact missing from native recovery query";
  val _ = if @{code current_goal} ready ready_request ready_goal =
        SOME (@{code ArtifactDependency} (n 6))
    then () else error "Current acknowledged child did not expose artifact dependency";
  val (duplicate,_) = @{code step} ready (@{code StageOutput} (n 542,assignment,NONE));
  val _ = if is_none (@{code pending_batch} duplicate) then () else error "Artifact rebound assigned slot";
  val (cancelled,_) = @{code step} computed (@{code CancelRequest} (n 8));
  val (stale,_) = @{code step} cancelled (@{code StageOutput} (n 543,assignment,NONE));
  val _ = if is_none (@{code pending_batch} stale) then () else error "Cancelled build adopted candidate";
  val (forgotten,_) = @{code step} ready (@{code Forget} (n 300));
  val _ = if null (@{code required_native_artifacts} forgotten) andalso
      null (@{code output_assignments} forgotten) andalso
      not (exists (fn v => @{code retained_id} v=n 520) (@{code retained_values} forgotten))
    then () else error "Forgotten build source retained accessible candidate";
  val _ = writeln "VERI7VN_MODEL artifact_owned_nonassertional PASS";
\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val computed = @{code artifact_computed_fixture};
  val assignment = @{code ArtifactOutput} @{code artifact_assignment_fixture};
  fun check_late_artifact target batch =
    let
      val (denied,_) = @{code step} computed (@{code Revoke} target);
      val (late,reply) = @{code step} denied (@{code StageOutput} (batch,assignment,NONE));
      val (late_ack,_) = @{code step} late (@{code DurableAck} (batch,n 1,n 0));
      val _ = if late=denied andalso length reply=1 andalso late_ack=denied andalso
          null (@{code output_assignments} late_ack) then ()
        else error "Late artifact output resurrected a revoked child identity";
      val (pending,_) = @{code step} computed (@{code StageOutput} (batch,assignment,NONE));
      val _ = if is_some (@{code pending_batch} pending) then ()
        else error "Artifact race fixture failed to create its pending output";
      val (revoked_pending,_) = @{code step} pending (@{code Revoke} target);
      val (pending_ack,_) = @{code step} revoked_pending (@{code DurableAck} (batch,n 1,n 0));
      val _ = if is_none (@{code pending_batch} pending_ack) andalso
          null (@{code output_assignments} pending_ack) andalso
          null (@{code required_native_artifacts} pending_ack) then ()
        else error "Acknowledgement published an artifact after child identity revocation";
    in () end;
  val _ = check_late_artifact (n 6) (n 560);
  val _ = check_late_artifact (n 510) (n 561);
  val _ = writeln "VERI7VN_MODEL artifact_child_revocation_races PASS";
\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val computed = @{code artifact_computed_fixture};
  val candidate = @{code artifact_assignment_fixture};
  val expected = @{code artifact_expected_retained} computed candidate;
  val _ = if expected=SOME (@{code artifact_assigned_retained} candidate) then ()
    else error "Valid artifact rows changed under intrinsic closure derivation";
  val malformed = @{code artifact_missing_identity_fixture};
  val _ = if @{code artifact_expected_retained} computed malformed <>
      SOME (@{code artifact_assigned_retained} malformed) then ()
    else error "Malformed artifact proposal omitted owning goal closure";
  val (rejected,_) = @{code step} computed (@{code StageOutput}
    (n 562,@{code ArtifactOutput} malformed,NONE));
  val _ = if rejected=computed andalso is_none (@{code pending_batch} rejected) then ()
    else error "Artifact preflight synthesized missing ownership edges";
  val _ = List.app (fn state =>
      if is_none (@{code artifact_expected_retained} state candidate) then ()
      else error "Artifact expected rows accepted missing or ambiguous ownership")
    [@{code artifact_missing_owner_fixture},@{code artifact_ambiguous_owner_fixture},
     @{code artifact_ambiguous_child_fixture},@{code artifact_ambiguous_slot_fixture}];
  val (staged,_) = @{code step} computed (@{code StageOutput}
    (n 563,@{code ArtifactOutput} candidate,NONE));
  val (ready,_) = @{code step} staged (@{code DurableAck} (n 563,n 1,n 0));
  fun check_identity target =
    let
      val (revoked,_) = @{code step} ready (@{code Revoke} target);
      val (forgotten,_) = @{code step} ready (@{code Forget} target);
      val _ = if null (@{code required_native_artifacts} revoked) andalso
          null (@{code required_native_artifacts} forgotten) andalso
          not (exists (fn row => @{code retained_id} row=n 520) (@{code retained_values} forgotten)) andalso
          null (@{code output_assignments} forgotten) then ()
        else error "Artifact survived owning request, goal or slot erasure";
      val (pending,_) = @{code step} computed (@{code StageOutput}
        (n 564,@{code ArtifactOutput} candidate,NONE));
      val (removed_pending,_) = @{code step} pending (@{code Forget} target);
      val (late_ack,_) = @{code step} removed_pending (@{code DurableAck} (n 564,n 1,n 0));
      val _ = if is_none (@{code pending_batch} late_ack) andalso
          null (@{code output_assignments} late_ack) andalso null (@{code required_native_artifacts} late_ack)
        then () else error "Pending artifact acknowledgement survived owning identity erasure";
    in () end;
  val _ = List.app check_identity [n 8,n 6,n 510];
  val _ = writeln "VERI7VN_MODEL artifact_intrinsic_owner_closure PASS";
\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val initial = @{code artifact_composite_ready_fixture};
  val (first_run,_) = @{code step} initial (@{code ExecutePure} @{code artifact_run_fixture});
  val (first_stage,_) = @{code step} first_run (@{code StageOutput}
    (n 551,@{code ArtifactOutput} @{code artifact_assignment_fixture},NONE));
  val (first,_) = @{code step} first_stage (@{code DurableAck} (n 551,n 1,n 0));
  val r = hd (@{code requests} first);
  val _ = if @{code goal_ready_live} first r @{code artifact_child_goal_fixture} then ()
    else error "Typed artifact parent did not ready dependent goal";
  val (second_run,commands) = @{code step} first (@{code ExecutePure} @{code artifact_child_run_fixture});
  val _ = if length commands=1 andalso @{code request_fuel} (hd (@{code requests} second_run))=n 8
    then () else error "Per-child executable pin fell back to parent pin";
  val (second_stage,_) = @{code step} second_run (@{code StageOutput}
    (n 552,@{code ArtifactOutput} @{code artifact_child_assignment_fixture},NONE));
  val (second,_) = @{code step} second_stage (@{code DurableAck} (n 552,n 2,n 0));
  val _ = if length (@{code required_native_artifacts} second)=2 andalso null (@{code visible_bindings} second)
    then () else error "Composed artifact output failed or licensed assertion";
  val (denied_child,_) = @{code step} second (@{code Revoke} (n 601));
  val _ = if length (@{code required_native_artifacts} denied_child)=1 andalso
      @{code current_goal} denied_child (hd (@{code requests} denied_child))
        (hd (@{code request_goals} (hd (@{code requests} denied_child)))) =
        SOME (@{code ArtifactDependency} (n 6))
    then () else error "One child revocation denied unrelated sibling";
  val (denied_goal,_) = @{code step} second (@{code Revoke} (n 13));
  val _ = if length (@{code required_native_children} denied_goal)=1 andalso
      not (@{code request_cancelled} (hd (@{code requests} denied_goal)))
    then () else error "Child identity denial stopped sibling or survived recovery query";
  val (denied_parent,_) = @{code step} second (@{code Revoke} (n 8));
  val _ = if null (@{code required_native_children} denied_parent) andalso
      null (@{code required_native_artifacts} denied_parent) andalso
      @{code request_cancelled} (hd (@{code requests} denied_parent))
    then () else error "Parent identity denial left an active child";
  val (removed_parent,_) = @{code step} second (@{code Forget} (n 520));
  val _ = if null (@{code required_native_artifacts} removed_parent) then ()
    else error "Artifact-parent erasure retained dependent child";
  val _ = writeln "VERI7VN_MODEL artifact_composite_perchild PASS";
\<close>

ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val (unused,_) = @{code step} @{code initial_state} (@{code AttachEvidence} @{code fixture_evidence});
  val _ = if length (@{code required_native_evidence} unused)=1 then ()
    else error "Unused native evidence was excluded before denial";
  val (denied,_) = @{code step} unused (@{code Revoke} (n 5));
  val _ = if null (@{code required_native_evidence} denied) then ()
    else error "Unused evidence restored denied executable context";
  val _ = writeln "VERI7VN_MODEL unused_evidence_execution_pin PASS";
\<close>

text \<open>These response fixtures exercise generated ownership and lifecycle guards;
they do not assert that an external response is true or reconstruct native bytes.\<close>
ML \<open>
  val n = Veri7vn_Numerals.nat_of_integer;
  val step = @{code step};
  val running = @{code effect_running_fixture};
  val observation = @{code effect_observation_fixture};
  fun require true _ = () | require false message = error message;
  val _ = require (@{code attempt_state} (hd (@{code attempts} running)) = @{code Running} andalso
      @{code request_fuel} (hd (@{code requests} running))=n 9) "Effect did not start with one charge";
  val _ = List.app (fn id =>
      let val aliased = @{code effect_observation_source_update} (K (n id)) observation
      in require (not (@{code effect_observation_permitted} running aliased))
        "Response UID aliased original structural/source/executable identity" end)
    [810,8,6,3,4,5,7,10,22,30,31,32,300];
  val _ = require (null (@{code required_native_children} running) andalso
      null (@{code required_native_build_requests} running) andalso
      @{code goal_output_slot} (hd (@{code request_goals} (hd (@{code requests} running))))=NONE)
    "Slotless legacy effect invented a native request-child association";
  val prefix = @{code effect_request_prefix_fixture};
  val _ = require (length (@{code required_native_effect_requests} prefix)=1 andalso
      null (@{code attempts} prefix) andalso null (@{code retained_values} prefix) andalso
      null (@{code required_native_children} prefix))
    "Original slotless effect recipe missing before intent and supports";
  val (cancelled_prefix,_) = step prefix (@{code CancelRequest} (n 8));
  val _ = require (length (@{code required_native_effect_requests} cancelled_prefix)=1)
    "Cancellation erased inert original effect request material";
  val (forgotten_prefix,_) = step prefix (@{code Forget} (n 8));
  val (denied_source_prefix,_) = step prefix (@{code Revoke} (n 300));
  val (denied_code_prefix,_) = step prefix (@{code Revoke} (n 5));
  val _ = require (null (@{code required_native_effect_requests} forgotten_prefix) andalso
      null (@{code required_native_effect_requests} denied_source_prefix) andalso
      null (@{code required_native_effect_requests} denied_code_prefix))
    "Denied original request/source/code remained in native effect recipe inventory";
  val _ = require (length (@{code required_native_effect_requests} running)=1)
    "Running effect original recipe disappeared";
  val (staged,_) = step running (@{code StageEffectObservation} (n 821,observation));
  val _ = require (is_some (@{code pending_batch} staged) andalso
      null (@{code required_native_effect_observations} staged)) "Response visible before durable ack";
  val (delivered,_) = step staged (@{code DurableAck} (n 821,n 2,n 0));
  val _ = require (length (@{code required_native_effect_observations} delivered)=1 andalso
      @{code attempt_state} (hd (@{code attempts} delivered)) = @{code Confirmed} andalso
      @{code request_fuel} (hd (@{code requests} delivered))=n 9 andalso
      null (@{code visible_bindings} delivered) andalso null (@{code evidence_table} delivered))
    "Response delivery was not atomic, nonassertional and already paid";
  val _ = require (null (@{code required_native_children} delivered) andalso
      length (@{code required_native_effect_observations} delivered)=1)
    "Slotless effect response lost independent source inventory";
  val failed_observation = @{code effect_observation_status_update} (K @{code EffectFailed}) observation;
  val (failed_stage,_) = step running (@{code StageEffectObservation} (n 824,failed_observation));
  val (failed_response,_) = step failed_stage (@{code DurableAck} (n 824,n 2,n 0));
  val _ = require (length (@{code required_native_effect_observations} failed_response)=1 andalso
      @{code attempt_state} (hd (@{code attempts} failed_response)) = @{code EffectFailed})
    "Structured failed response did not retain its nonassertional source";
  val invalid_status = @{code effect_observation_status_update} (K @{code Unknown}) observation;
  val _ = require (not (@{code effect_observation_permitted} running invalid_status))
    "Unknown status invented a response source";
  val (unknown,_) = step running (@{code Reconcile} (n 810,@{code Unknown}));
  val _ = require (@{code effect_observation_permitted} unknown observation) "Unknown blocked actual late response";
  val (terminal,_) = step running (@{code Reconcile} (n 810,@{code Confirmed}));
  val _ = require (not (@{code effect_observation_permitted} terminal observation))
    "Status-only terminal reconciliation allowed later response attachment";
  val _ = require (length (@{code required_native_effect_requests} unknown)=1 andalso
      length (@{code required_native_effect_requests} terminal)=1 andalso
      length (@{code required_native_effect_requests} delivered)=1)
    "Unknown or terminal effect original recipe disappeared";
  val (forgotten,_) = step delivered (@{code Forget} (n 820));
  val _ = require (length (@{code required_native_effect_requests} forgotten)=1)
    "Forgetting response data erased independent original request history";
  val fresh_source = @{code effect_observation_source_update} (K (n 822)) observation;
  val (reattached,_) = step forgotten (@{code StageEffectObservation} (n 823,fresh_source));
  val (replayed,_) = step forgotten (@{code DurableAck} (n 821,n 2,n 0));
  val _ = require (null (@{code effect_observations} forgotten) andalso
      null (@{code required_native_effect_observations} reattached) andalso
      @{code pending_batch} reattached = NONE andalso replayed=forgotten andalso
      @{code attempt_state} (hd (@{code attempts} forgotten)) = @{code Confirmed})
    "Forgotten response resurrected through a new UID/batch or old ack";
  val blocker = @{code effect_blocker_fixture};
  val (blocked,_) = step running (@{code AddBlocker} (n 8,blocker));
  val _ = require (not (@{code effect_observation_permitted} blocked observation))
    "Current child blocker allowed response delivery";
  val (blocked_pending,_) = step staged (@{code AddBlocker} (n 8,blocker));
  val (blocked_ack,_) = step blocked_pending (@{code DurableAck} (n 821,n 2,n 0));
  val _ = require (null (@{code required_native_effect_observations} blocked_ack))
    "Late blocker bypassed durable response recheck";
  val (blocked_prepared,_) = step @{code effect_prepared_fixture} (@{code AddBlocker} (n 8,blocker));
  val (blocked_start,commands) = step blocked_prepared (@{code ClaimAndStart} (n 810));
  val _ = require (blocked_start=blocked_prepared andalso length commands=1)
    "Blocked child launched an already prepared effect";
  val (cancelled,_) = step staged (@{code CancelRequest} (n 8));
  val (cancelled_ack,_) = step cancelled (@{code DurableAck} (n 821,n 2,n 0));
  val _ = require (null (@{code required_native_effect_observations} cancelled_ack))
    "Late cancellation bypassed durable response recheck";
  val (revoked,_) = step staged (@{code Revoke} (n 6));
  val (revoked_ack,_) = step revoked (@{code DurableAck} (n 821,n 2,n 0));
  val _ = require (null (@{code required_native_effect_observations} revoked_ack))
    "Late child identity denial bypassed durable response recheck";
  val _ = writeln "VERI7VN_MODEL effect_observation_atomic_nonassertional PASS";
\<close>

end
