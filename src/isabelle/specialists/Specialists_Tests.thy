theory Specialists_Tests
  imports Specialist_Contract Arbitration Exam_Gate
begin

section \<open>Concrete checks and the session marker\<close>

subsection \<open>The value tolerance is not transitive, and the agreement shortcut then picks\<close>

text \<open>Python's \<^verbatim>\<open>_same_value\<close> with its default 0.5\% relative tolerance, on integers
  (values in tenths here; Python's \<open>1e-12\<close> floor on the scale only matters at zero).\<close>
definition same_tol :: "int \<Rightarrow> int \<Rightarrow> bool" where
  "same_tol a b \<longleftrightarrow> 200 * \<bar>a - b\<bar> \<le> max \<bar>a\<bar> \<bar>b\<bar>"

lemma tolerance_not_transitive:
  "same_tol 1004 1000 \<and> same_tol 1004 1008 \<and> \<not> same_tol 1000 1008"
  by (simp add: same_tol_def)

text \<open>Three answers: 100.4 (lowest key, first in pick order), 100 and 100.8 (tied at the top on a-d,
  stating numbers 0.8\% apart).  Every answer agrees with the first within 0.5\%, so the shortcut
  takes 100.4; the top-tied disagreement is never shown.  This is why
  \<open>arbitrate_never_picks_disagreement\<close> assumes \<open>same\<close> is an equivalence.\<close>
definition ex_mid :: "(int, string) cand" where
  "ex_mid = Cand False False 0 False (0, 0) False (Some 1004) ''100.4''"
definition ex_low :: "(int, string) cand" where
  "ex_low = Cand False False 2 False (0, 0) False (Some 1000) ''100''"
definition ex_high :: "(int, string) cand" where
  "ex_high = Cand False False 2 False (0, 0) False (Some 1008) ''100.8''"

lemma tolerance_not_transitive_shortcut_picks:
  "agree_shortcut same_tol [ex_mid, ex_low, ex_high] \<and>
   arbitrate same_tol 2 [ex_mid, ex_low, ex_high] = Pick ex_mid"
  by code_simp

lemma tolerance_two_way_disagreement:
  "arbitrate same_tol 2 [ex_low, ex_high] = Disagree ex_low ex_high"
  by code_simp

text \<open>Three answers tied at the top: only the first two in pick order are compared.  The first two
  agree, so the first is picked although the third states another number.\<close>
lemma three_way_tie_third_dissent_unseen:
  "arbitrate (=) 1 [Cand False False 1 False (0,0) False (Some (1::int)) ''a'',
                    Cand False False 1 False (0,0) False (Some 1) ''b'',
                    Cand False False 1 False (0,0) False (Some 2) ''c'']
   = Pick (Cand False False 1 False (0,0) False (Some 1) ''a'')"
  by code_simp

text \<open>The shortcut under the 0.5\% tolerance: the picked answer is within tolerance of every other
  non-decline answer of the turn, though the tolerance is not transitive, so the answers need not be
  within tolerance of each other.  This is the bound that \<open>tolerance_not_transitive_shortcut_picks\<close> lacked.\<close>
lemma same_tol_refl: "same_tol a a"
  by (simp add: same_tol_def)

theorem shortcut_pick_within_tolerance:
  assumes "agree_shortcut same_tol cs" and "arbitrate same_tol g cs = Pick c"
  shows "\<exists>a. val c = Some a \<and>
           (\<forall>d \<in> set cs. \<not> declined d \<longrightarrow> (\<exists>b. val d = Some b \<and> 200 * \<bar>a - b\<bar> \<le> max \<bar>a\<bar> \<bar>b\<bar>))"
proof -
  have main: "val c \<noteq> None" "\<forall>d \<in> set cs. \<not> declined d \<longrightarrow> same_opt same_tol (val c) (val d)"
    using agree_shortcut_pick_agrees[OF same_tol_refl assms] by auto
  then obtain a where a: "val c = Some a" by auto
  show ?thesis
  proof (rule exI[of _ a], rule conjI)
    show "val c = Some a" by (rule a)
  next
    show "\<forall>d \<in> set cs. \<not> declined d \<longrightarrow> (\<exists>b. val d = Some b \<and> 200 * \<bar>a - b\<bar> \<le> max \<bar>a\<bar> \<bar>b\<bar>)"
    proof (intro ballI impI)
      fix d assume d: "d \<in> set cs" "\<not> declined d"
      with main(2) a obtain b where "val d = Some b" "same_tol a b"
        by (cases "val d") auto
      then show "\<exists>b. val d = Some b \<and> 200 * \<bar>a - b\<bar> \<le> max \<bar>a\<bar> \<bar>b\<bar>"
        unfolding same_tol_def by auto
    qed
  qed
qed

subsection \<open>The census example: an organ that assumes a value loses\<close>

text \<open>Soil ignored the given skeletal density and assumed 2.65; the owner used both givens.\<close>
lemma invented_given_loses:
  "arbitrate (=) 2 [Cand False False 2 True (1,3) True (Some (265::int)) ''soil: assuming 2.65'',
                    Cand False False 2 False (1,3) True (Some 180) ''owner'']
   = Pick (Cand False False 2 False (1,3) True (Some 180) ''owner'')"
  by code_simp

lemma checked_decline_beats_foreign_answer:
  "arbitrate (=) 3 [Cand False False 1 False (2,5) True (Some (7::int)) ''foreign'',
                    Cand True True 0 False (0,0) False None ''impossible: out of range'']
   = Pick (Cand True True 0 False (0,0) False None ''impossible: out of range'')"
  by code_simp

lemma pick_order_breaks_full_tie:
  "arbitrate (=) 0 [Cand False False 0 False (0,0) False (None::int option) ''first'',
                    Cand False False 0 False (0,0) False None ''second'']
   = Pick (Cand False False 0 False (0,0) False None ''first'')"
  by code_simp

subsection \<open>Exam gate on shipped numbers\<close>

text \<open>rel-novels held-out (shipped ADMIT under release gate v2): gain 40, no new false yes, no wrong,
  6 of 405 core questions taken.  exam.py's lane cap is max(5, 405 div 100) = 5.\<close>
lemma rel_novels_exam_py:
  "reasons (Exam 60 (Tally 10 0 0) (Tally 50 0 0) 405 6 0 430 100000) = [LANE] \<and>
   decide Heldout (Exam 60 (Tally 10 0 0) (Tally 50 0 0) 405 6 0 430 100000) = NEGATIVE"
  by (simp add: reasons_def decide_def admit_def need_def wrong_cap_def lane_cap_def max_def)

lemma never_fires_example:
  "reasons (Exam 69 (Tally 3 1 0) (Tally 3 1 0) 400 0 0 3 20000) = [DOMAIN]"
  by (simp add: reasons_def decide_def admit_def need_def wrong_cap_def lane_cap_def max_def)

lemma need_examples: "map need [0, 100, 150, 151, 200, 1000] = [3, 3, 3, 4, 4, 20]"
  by (simp add: reasons_def decide_def admit_def need_def wrong_cap_def lane_cap_def max_def)

subsection \<open>Contract examples\<close>

lemma accept_examples:
  "accept [''answer''] [''decline''] (\<lambda>t. t = ''in domain'') ''in domain'' ''decline'' \<and>
   \<not> accept [''answer''] [''decline''] (\<lambda>t. t = ''in domain'') ''elsewhere'' ''decline'' \<and>
   accept [''answer''] [''decline''] (\<lambda>t. False) ''elsewhere'' ''answer''"
  by code_simp

text \<open>Session check: every theorem of the session, and the example lemmas of this theory, depends on no
  oracle (no \<open>sorry\<close>, no code-generator evaluation); the marker is printed after the check.\<close>

ML \<open>
  val theorems = [
    ("checked_context_refusal_wins_tie", @{thms checked_context_refusal_wins_tie}),
    ("arbitrate_fallthrough", @{thms arbitrate_fallthrough}),
    ("arbitrate_never_picks_disagreement", @{thms arbitrate_never_picks_disagreement}),
    ("arbitrate_disagree_sound", @{thms arbitrate_disagree_sound}),
    ("arbitrate_pick_is_first_best", @{thms arbitrate_pick_is_first_best}),
    ("arbitrate_total_deterministic", @{thms arbitrate_total_deterministic}),
    ("arbitrate_order_invariant", @{thms arbitrate_order_invariant}),
    ("agree_shortcut_pick_agrees", @{thms agree_shortcut_pick_agrees}),
    ("agree_shortcut_blocked", @{thms agree_shortcut_blocked}),
    ("admit_iff_reasons_empty", @{thms admit_iff_reasons_empty}),
    ("admit_iff_criteria", @{thms admit_iff_criteria}),
    ("reasons_exact", @{thms reasons_exact}),
    ("never_fires_never_admitted", @{thms never_fires_never_admitted}),
    ("gain_needed", @{thms gain_needed}),
    ("admit_no_new_false_yes", @{thms admit_no_new_false_yes}),
    ("admit_monotone_in_gain", @{thms admit_monotone_in_gain}),
    ("admit_antitone_in_faults", @{thms admit_antitone_in_faults}),
    ("dev_never_admits", @{thms dev_never_admits}),
    ("heldout_admits_iff", @{thms heldout_admits_iff}),
    ("accept_decline_needs_context", @{thms accept_decline_needs_context}),
    ("accept_unknown_kind_rejected", @{thms accept_unknown_kind_rejected}),
    ("spec_reply_needs_accept", @{thms spec_reply_needs_accept}),
    ("fillable_never_a_check", @{thms fillable_never_a_check}),
    ("compose_never_overrides_answer", @{thms compose_never_overrides_answer}),
    ("compose_only_fills_declines", @{thms compose_only_fills_declines}),
    ("compose_consults_only_fillable", @{thms compose_consults_only_fillable}),
    ("exam_turn_respects_checks", @{thms exam_turn_respects_checks}),
    ("exam_turn_changes_only_by_accepted_reply", @{thms exam_turn_changes_only_by_accepted_reply}),
    ("shortcut_pick_within_tolerance", @{thms shortcut_pick_within_tolerance}),
    ("same_tol_refl", @{thms same_tol_refl}),
    ("tolerance_not_transitive", @{thms tolerance_not_transitive}),
    ("tolerance_not_transitive_shortcut_picks", @{thms tolerance_not_transitive_shortcut_picks}),
    ("tolerance_two_way_disagreement", @{thms tolerance_two_way_disagreement}),
    ("three_way_tie_third_dissent_unseen", @{thms three_way_tie_third_dissent_unseen}),
    ("invented_given_loses", @{thms invented_given_loses}),
    ("checked_decline_beats_foreign_answer", @{thms checked_decline_beats_foreign_answer}),
    ("pick_order_breaks_full_tie", @{thms pick_order_breaks_full_tie}),
    ("rel_novels_exam_py", @{thms rel_novels_exam_py}),
    ("never_fires_example", @{thms never_fires_example}),
    ("need_examples", @{thms need_examples}),
    ("accept_examples", @{thms accept_examples})];
  val bad = filter (fn (_, th) => not (null (Thm_Deps.all_oracles th))) theorems;
  val _ = if null bad then () else error ("oracle-dependent: " ^ commas (map fst bad));
  val _ = writeln ("VERI7VN_SPECIALISTS PASS theorems=" ^ string_of_int (length (maps snd theorems)) ^ " oracles=0")
\<close>

end
