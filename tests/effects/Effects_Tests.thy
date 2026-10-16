theory Effects_Tests
  imports Veri7vn_Effects.Veri7vn_Effects
begin
lemma signed_wall_fresh:
  "fresh_at \<lparr>fresh_from = \<lparr>basis = Wall ''UTC'', ticks = -10\<rparr>,
    fresh_through = -1\<rparr> \<lparr>basis = Wall ''UTC'', ticks = -5\<rparr>"
  by (simp add: fresh_at_def)
lemma different_monotonic_origin_rejected:
  "\<not> fresh_at \<lparr>fresh_from = \<lparr>basis = Monotonic ''boot-a'', ticks = 1\<rparr>,
    fresh_through = 10\<rparr> \<lparr>basis = Monotonic ''boot-b'', ticks = 2\<rparr>"
  by (simp add: fresh_at_def)
definition access_observed :: observation_context where
  "access_observed = \<lparr>observed_session = 7, observed_version = 0,
    evaluation_time = Some \<lparr>basis = Wall ''UTC'', ticks = 10\<rparr>, observed_reads = [(3,4)]\<rparr>"
definition access_window :: freshness_window where
  "access_window = \<lparr>fresh_from = \<lparr>basis = Wall ''UTC'', ticks = 10\<rparr>, fresh_through = 20\<rparr>"
lemma adopted_cas_preserves_access_only:
  "authority_fresh (access_observed\<lparr>observed_version := 1\<rparr>) (RequireAccess access_observed (Some access_window)) \<and>
   \<not> authority_fresh (access_observed\<lparr>observed_version := 1\<rparr>) (RequireObservation access_observed (Some access_window))"
  by (simp add: authority_fresh_def observation_fields_fresh_def access_observed_def access_window_def reads_match_def fresh_at_def)
lemma changed_access_read_rejected:
  "\<not> authority_fresh (access_observed\<lparr>observed_reads := [(3,5)]\<rparr>) (RequireAccess access_observed (Some access_window))"
  by (simp add: authority_fresh_def observation_fields_fresh_def access_observed_def access_window_def reads_match_def)
lemma expired_access_rejected:
  "\<not> authority_fresh (access_observed\<lparr>evaluation_time := Some \<lparr>basis = Wall ''UTC'', ticks = 21\<rparr>\<rparr>) (RequireAccess access_observed (Some access_window))"
  by (simp add: authority_fresh_def observation_fields_fresh_def access_observed_def access_window_def reads_match_def fresh_at_def)
lemma different_access_session_rejected:
  "\<not> authority_fresh (access_observed\<lparr>observed_session := 8\<rparr>) (RequireAccess access_observed (Some access_window))"
  by (simp add: authority_fresh_def observation_fields_fresh_def access_observed_def)

lemma repeated_receipt_not_fresh:
  "\<not> fresh_at \<lparr>fresh_from = \<lparr>basis = Source_Event ''sensor'', ticks = 10\<rparr>,
    fresh_through = 20\<rparr> \<lparr>basis = Source_Event ''sensor'', ticks = 21\<rparr>"
  by (simp add: fresh_at_def)
lemma ambiguous_read_rejected:
  "\<not> reads_match [(1,2)] [(1,2),(1,3)]"
  by (simp add: reads_match_def)
lemma cross_request_fuel_rejected:
  "charge_fuel 8 1 \<lparr>fuel_owner = 7, fuel_remaining = 100\<rparr> = None"
  by (simp add: charge_fuel_def)
lemma exhausted_fuel_rejected:
  "charge_fuel 7 2 \<lparr>fuel_owner = 7, fuel_remaining = 1\<rparr> = None"
  by (simp add: charge_fuel_def)
lemma withheld_answer_not_adopted:
  "adopt_answer 7 [] \<lparr>adoption_request = 7, adoption_session = 1,
    adoption_expected_version = 0, adoption_bindings = [42]\<rparr>
    \<lparr>session_id = 1, session_version = 0, recorded_utterances = [3],
      adopted_bindings = []\<rparr> = None"
  by (simp add: adopt_answer_def)
lemma transitive_private_derivative:
  "forget_closure [\<lparr>retained_id = 2, retained_owner = SessionLocal 7,
    retained_dependencies = [1], retained_read_dependencies = [1], retained_access_requirements = [], retained_payload = 12\<rparr>,
    \<lparr>retained_id = 3, retained_owner = RequestLocal 8,
    retained_dependencies = [2], retained_read_dependencies = [2], retained_access_requirements = [], retained_payload = 13\<rparr>] [1] = Some [1,2,3]"
  by (simp add: forget_closure_def directly_dependent_def)
end
