theory Source_Semantics_Tests
  imports Veri7vn_Source_Semantics.Source_Semantics
begin
ML \<open>
fun source_test_bounded tac st =
  Seq.make (fn () => Timeout.apply (Time.fromSeconds 5)
    (fn () => Seq.pull (tac st)) ());
\<close>

ML \<open>writeln "SOURCE_TEST begin candidate"\<close>
lemma positive_witness_does_not_establish_absence_or_uniqueness:
  "(1::nat) \<in> set (candidates (\<lambda>_. True) [1]) \<and>
   \<not> covers {1::nat,2} (\<lambda>_. True) [1]"
proof
  show "(1::nat) \<in> set (candidates (\<lambda>_. True) [1])"
    by (tactic \<open>source_test_bounded (asm_full_simp_tac (@{context} |> Simplifier.add_simps @{thms candidates_def}) 1)\<close>)
  show "\<not> covers {1::nat,2} (\<lambda>_. True) [1]"
  proof
    assume h: "covers {1::nat,2} (\<lambda>_. True) [1]"
    from h have eq: "{x \<in> {1::nat,2}. True} = set (candidates (\<lambda>_. True) [1])"
      unfolding covers_def .
    have "(2::nat) \<in> {x \<in> {1::nat,2}. True}" by (tactic \<open>source_test_bounded (asm_full_simp_tac @{context} 1)\<close>)
    then have "(2::nat) \<in> set (candidates (\<lambda>_. True) [1])"
      unfolding eq .
    then show False by (simp add: candidates_def)
  qed
qed

lemma unseen_candidate_changes_count:
  "length (remdups (candidates (\<lambda>_. True) [1::nat])) = 1 \<and>
   card {1::nat,2} = 2"
  by (tactic \<open>source_test_bounded (asm_full_simp_tac (@{context} |> Simplifier.add_simps @{thms candidates_def}) 1)\<close>)
lemma observed_empty_is_not_closed_absence:
  "candidates (\<lambda>_. True) ([]::nat list) = [] \<and>
   \<not> covers {7::nat} (\<lambda>_. True) []"
  by (tactic \<open>source_test_bounded (auto_tac (@{context} |> Simplifier.add_simps @{thms candidates_def covers_def set_eq_iff}))\<close>)
lemma conflicting_valid_readings_retained:
  "length ([Valid True, Valid False, Missing, Rejected ''quality''] :: bool reading list) = 4"
  by (tactic \<open>source_test_bounded (asm_full_simp_tac @{context} 1)\<close>)
lemma ranking_requires_population:
  "sorted_wrt (\<lambda>x y. x \<ge> y) [1::nat] \<and>
   \<not> (\<forall>x\<in>{1::nat,2}. x \<le> 1)"
  by (tactic \<open>source_test_bounded (asm_full_simp_tac @{context} 1)\<close>)
ML \<open>writeln "SOURCE_TEST begin streaming"\<close>
definition old_sample :: "nat observation" where
  "old_sample = \<lparr>source_id = ''sensor'', sequence_id = 4,
    configuration = ''Celsius-v1'', schema_version = ''1'', origin = Measured,
    event_clock = Some \<lparr>basis = Source_Event ''sensor-clock'', ticks = 10\<rparr>,
    receipt_clock = \<lparr>basis = Wall ''UTC'', ticks = 20\<rparr>,
    payload = Valid 7, qualifiers = [''Celsius''], raw_reference = None\<rparr>"
lemma polling_old_sample_does_not_refresh:
  "\<not> event_in_window (Source_Event ''sensor-clock'') 90 110
    (repoll \<lparr>basis = Wall ''UTC'', ticks = 100\<rparr> old_sample)"
  by (tactic \<open>source_test_bounded (asm_full_simp_tac (@{context} |> Simplifier.add_simps @{thms event_in_window_def old_sample_def}) 1)\<close>)
ML \<open>writeln "SOURCE_TEST begin population"\<close>
lemma mixed_quality_window_population:
  "length (window_population (Source_Event ''sensor-clock'') 0 20
      [old_sample, old_sample\<lparr>payload := Missing\<rparr>,
       old_sample\<lparr>payload := Rejected ''range''\<rparr>]) = 3 \<and>
   valid_values [old_sample, old_sample\<lparr>payload := Missing\<rparr>,
       old_sample\<lparr>payload := Rejected ''range''\<rparr>] = [7]"
  by (tactic \<open>source_test_bounded (asm_full_simp_tac (@{context} |> Simplifier.add_simps @{thms window_population_def event_in_window_def valid_values_def old_sample_def}) 1)\<close>)
lemma unknown_event_repoll_stays_unknown:
  "origin (repoll now (old_sample\<lparr>origin := Unknown_Origin\<rparr>)) = Unknown_Origin"
  by simp
ML \<open>writeln "VERI7VN_SOURCE_SEMANTICS regressions PASS"\<close>
end
