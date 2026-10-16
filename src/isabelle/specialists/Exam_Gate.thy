theory Exam_Gate
  imports Main
begin

section \<open>The six-criterion specialist exam\<close>

text \<open>
  Source: \<^verbatim>\<open>upstream/workbench/exam.py\<close>, \<^verbatim>\<open>run\<close> (lines 184-224).  The gate is a function of
  counts the exam loop produced; how the counts were measured (the scorer, the 924-question core
  panel, the clock) is outside this theory.  Python's \<^verbatim>\<open>math.ceil(0.02 * n)\<close> and
  \<^verbatim>\<open>math.floor(0.02 * n)\<close> are modelled as exact \<open>\<lceil>n/50\<rceil>\<close> and \<open>\<lfloor>n/50\<rfloor>\<close>; the two agree
  for every \<open>n < 100000\<close> (checked in Python by \<^verbatim>\<open>tools/gate/check_verdicts.py --float-check\<close>).
  Latencies are counted in hundredths of a millisecond: exam.py rounds the median to two decimals.
\<close>

text \<open>Right answers, false yeses (asserted on a must-decline item), and answered-but-wrong on valid items.\<close>
datatype tally = Tally (ok: nat) (fy: nat) (wrong: nat)

text \<open>Everything the decision reads from one exam run.\<close>
datatype exam = Exam
  (n: nat)               \<comment> \<open>items in the split\<close>
  (head: tally)          \<comment> \<open>the core alone\<close>
  (comp: tally)          \<comment> \<open>the core with the specialist filling fillable declines\<close>
  (core_n: nat)          \<comment> \<open>core-panel questions asked (924 in the release)\<close>
  (core_taken: nat)      \<comment> \<open>of those, the ones it took where the core had declined fillably\<close>
  (self_answered: nat)   \<comment> \<open>identity questions it answered\<close>
  (p50_c: nat)           \<comment> \<open>median specialist reply time, hundredths of a ms\<close>
  (budget_c: nat)        \<comment> \<open>manifest budget, hundredths of a ms (default 200 ms)\<close>

datatype reason = DOMAIN | FALSE_YES | WRONG | LANE | SELF | BUDGET

datatype split = Dev | Heldout

datatype decision = ADMIT | NEGATIVE | WOULD_PASS | WOULD_FAIL

text \<open>The gain a specialist must add: at least 3 right answers, and at least 2\% of the items.\<close>
definition need :: "nat \<Rightarrow> nat" where
  "need m = max 3 ((m + 49) div 50)"

text \<open>Wrong answers tolerated: at least 1, and up to 2\% of the items, rounded down.\<close>
definition wrong_cap :: "nat \<Rightarrow> nat" where
  "wrong_cap m = max 1 (m div 50)"

text \<open>General questions it may take: at least 5, and up to 1\% of the core panel, rounded down.\<close>
definition lane_cap :: "nat \<Rightarrow> nat" where
  "lane_cap m = max 5 (m div 100)"

text \<open>Each criterion's failure condition, in exam.py's words.\<close>
fun fails :: "exam \<Rightarrow> reason \<Rightarrow> bool" where
  "fails e DOMAIN \<longleftrightarrow> int (ok (comp e)) - int (ok (head e)) < int (need (n e))"
| "fails e FALSE_YES \<longleftrightarrow> fy (head e) < fy (comp e)"
| "fails e WRONG \<longleftrightarrow> wrong_cap (n e) < wrong (comp e)"
| "fails e LANE \<longleftrightarrow> lane_cap (core_n e) < core_taken e"
| "fails e SELF \<longleftrightarrow> 0 < self_answered e"
| "fails e BUDGET \<longleftrightarrow> budget_c e < p50_c e"

text \<open>The reasons list, in the order exam.py appends them.\<close>
definition reasons :: "exam \<Rightarrow> reason list" where
  "reasons e = filter (fails e) [DOMAIN, FALSE_YES, WRONG, LANE, SELF, BUDGET]"

text \<open>A specialist passes the exam exactly when no reason was recorded.\<close>
definition admit :: "exam \<Rightarrow> bool" where
  "admit e \<longleftrightarrow> reasons e = []"

text \<open>A held-out exam admits or is negative; a dev exam only says how the held-out exam would go.\<close>
definition decide :: "split \<Rightarrow> exam \<Rightarrow> decision" where
  "decide s e = (case s of
       Heldout \<Rightarrow> if admit e then ADMIT else NEGATIVE
     | Dev \<Rightarrow> if admit e then WOULD_PASS else WOULD_FAIL)"

subsection \<open>Theorems\<close>

theorem admit_iff_reasons_empty: "admit e \<longleftrightarrow> reasons e = []"
  by (simp add: admit_def)

theorem admit_iff_criteria:
  "admit e \<longleftrightarrow>
     ok (head e) + need (n e) \<le> ok (comp e) \<and>
     fy (comp e) \<le> fy (head e) \<and>
     wrong (comp e) \<le> wrong_cap (n e) \<and>
     core_taken e \<le> lane_cap (core_n e) \<and>
     self_answered e = 0 \<and>
     p50_c e \<le> budget_c e"
  unfolding admit_def reasons_def by auto

theorem reasons_exact: "set (reasons e) = {r. fails e r} \<and> distinct (reasons e)"
  apply (rule conjI)
   apply (rule set_eqI)
   apply (case_tac x)
        apply (auto simp: reasons_def)
  done

lemma need_ge_3: "3 \<le> need m"
  by (simp add: need_def)

lemma need_is_ceiling:
  fixes m q :: nat
  shows "m \<le> 50 * ((m + 49) div 50)" and "m \<le> 50 * q \<Longrightarrow> (m + 49) div 50 \<le> q"
proof -
  show "m \<le> 50 * ((m + 49) div 50)"
    using div_mult_mod_eq[of "m + 49" 50] mod_less_divisor[of 50 "m + 49"] by linarith
next
  assume "m \<le> 50 * q"
  then have "m + 49 < (q + 1) * 50" by simp
  then have "(m + 49) div 50 < q + 1" by (rule less_mult_imp_div_less)
  then show "(m + 49) div 50 \<le> q" by simp
qed

text \<open>A specialist that never changes the composed tally (it never fires, or never helps) is never admitted.\<close>
theorem never_fires_never_admitted: "comp e = head e \<Longrightarrow> \<not> admit e"
  using need_ge_3[of "n e"] by (simp add: admit_iff_criteria)

theorem gain_needed: "admit e \<Longrightarrow> ok (head e) + 3 \<le> ok (comp e)"
  using need_ge_3[of "n e"] by (simp add: admit_iff_criteria)

theorem admit_no_new_false_yes: "admit e \<Longrightarrow> fy (comp e) \<le> fy (head e)"
  by (simp add: admit_iff_criteria)

text \<open>More right answers, everything else equal, never turns an admission into a rejection.\<close>
theorem admit_monotone_in_gain:
  assumes "admit (Exam m h (Tally c f w) cn ct s p b)" and "c \<le> c'"
  shows "admit (Exam m h (Tally c' f w) cn ct s p b)"
  using assms by (simp add: admit_iff_criteria)

text \<open>Fewer of every bad count, everything else equal, never turns an admission into a rejection.\<close>
theorem admit_antitone_in_faults:
  assumes "admit (Exam m h (Tally c f w) cn ct s p b)"
    and "f' \<le> f" "w' \<le> w" "ct' \<le> ct" "s' \<le> s" "p' \<le> p"
  shows "admit (Exam m h (Tally c f' w') cn ct' s' p' b)"
  using assms by (simp add: admit_iff_criteria)

theorem dev_never_admits: "decide Dev e \<noteq> ADMIT"
  by (simp add: decide_def)

theorem heldout_admits_iff: "decide Heldout e = ADMIT \<longleftrightarrow> admit e"
  by (simp add: decide_def)

end
