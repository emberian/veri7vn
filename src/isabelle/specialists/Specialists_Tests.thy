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
  by eval

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
  by eval

lemma tolerance_two_way_disagreement:
  "arbitrate same_tol 2 [ex_low, ex_high] = Disagree ex_low ex_high"
  by eval

text \<open>Three answers tied at the top: only the first two in pick order are compared.  The first two
  agree, so the first is picked although the third states another number.\<close>
lemma three_way_tie_third_dissent_unseen:
  "arbitrate (=) 1 [Cand False False 1 False (0,0) False (Some (1::int)) ''a'',
                    Cand False False 1 False (0,0) False (Some 1) ''b'',
                    Cand False False 1 False (0,0) False (Some 2) ''c'']
   = Pick (Cand False False 1 False (0,0) False (Some 1) ''a'')"
  by eval

subsection \<open>The census example: an organ that assumes a value loses\<close>

text \<open>Soil ignored the given skeletal density and assumed 2.65; the owner used both givens.\<close>
lemma invented_given_loses:
  "arbitrate (=) 2 [Cand False False 2 True (1,3) True (Some (265::int)) ''soil: assuming 2.65'',
                    Cand False False 2 False (1,3) True (Some 180) ''owner'']
   = Pick (Cand False False 2 False (1,3) True (Some 180) ''owner'')"
  by eval

lemma checked_decline_beats_foreign_answer:
  "arbitrate (=) 3 [Cand False False 1 False (2,5) True (Some (7::int)) ''foreign'',
                    Cand True True 0 False (0,0) False None ''impossible: out of range'']
   = Pick (Cand True True 0 False (0,0) False None ''impossible: out of range'')"
  by eval

lemma pick_order_breaks_full_tie:
  "arbitrate (=) 0 [Cand False False 0 False (0,0) False (None::int option) ''first'',
                    Cand False False 0 False (0,0) False None ''second'']
   = Pick (Cand False False 0 False (0,0) False None ''first'')"
  by eval

subsection \<open>Exam gate on shipped numbers\<close>

text \<open>rel-novels held-out (shipped ADMIT under release gate v2): gain 40, no new false yes, no wrong,
  6 of 405 core questions taken.  exam.py's lane cap is max(5, 405 div 100) = 5.\<close>
lemma rel_novels_exam_py:
  "reasons (Exam 60 (Tally 10 0 0) (Tally 50 0 0) 405 6 0 430 100000) = [LANE] \<and>
   decide Heldout (Exam 60 (Tally 10 0 0) (Tally 50 0 0) 405 6 0 430 100000) = NEGATIVE"
  by eval

lemma never_fires_example:
  "reasons (Exam 69 (Tally 3 1 0) (Tally 3 1 0) 400 0 0 3 20000) = [DOMAIN]"
  by eval

lemma need_examples: "map need [0, 100, 150, 151, 200, 1000] = [3, 3, 3, 4, 4, 20]"
  by eval

subsection \<open>Contract examples\<close>

lemma accept_examples:
  "accept [''answer''] [''decline''] (\<lambda>t. t = ''in domain'') ''in domain'' ''decline'' \<and>
   \<not> accept [''answer''] [''decline''] (\<lambda>t. t = ''in domain'') ''elsewhere'' ''decline'' \<and>
   accept [''answer''] [''decline''] (\<lambda>t. False) ''elsewhere'' ''answer''"
  by eval

ML \<open>writeln "VERI7VN_SPECIALISTS PASS"\<close>

end
