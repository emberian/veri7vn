theory Specialist_Contract
  imports Main
begin

section \<open>The specialist acceptance and composition contract\<close>

text \<open>
  Source: \<^verbatim>\<open>upstream/workbench/exam.py\<close>, \<^verbatim>\<open>fillable\<close> (lines 59-66) and
  \<^verbatim>\<open>Loaded.reply\<close> (lines 69-99), plus the composition in the exam loop (lines 167-174).

  Regex matching is an oracle in this theory.  A manifest's \<^verbatim>\<open>context_regex\<close>, exam.py's
  \<^verbatim>\<open>CHECK\<close> pattern and its substring tests over the reply path are parameters of type
  \<open>_ \<Rightarrow> bool\<close>; no regex engine is modelled and nothing here says what those patterns match.
  What is proved is how their verdicts are combined.
\<close>

subsection \<open>Acceptance\<close>

text \<open>A specialist's reply is kept only if its kind is one the manifest accepts, or it is one of the
  manifest's in-domain declines and the manifest's context pattern matches the question.\<close>
definition accept :: "'k list \<Rightarrow> 'k list \<Rightarrow> ('t \<Rightarrow> bool) \<Rightarrow> 't \<Rightarrow> 'k \<Rightarrow> bool" where
  "accept kinds declines ctx text k \<longleftrightarrow> k \<in> set kinds \<or> (k \<in> set declines \<and> ctx text)"

text \<open>What the organ said, after the acceptance rule: nothing if it crashed or said nothing
  (\<open>None\<close>), nothing if its kind is not accepted, else its reply.\<close>
definition spec_reply ::
  "'k list \<Rightarrow> 'k list \<Rightarrow> ('t \<Rightarrow> bool) \<Rightarrow> 't \<Rightarrow> ('k \<times> 'r) option \<Rightarrow> 'r option" where
  "spec_reply kinds declines ctx text organ_out =
     (case organ_out of
        None \<Rightarrow> None
      | Some (k, r) \<Rightarrow> if accept kinds declines ctx text k then Some r else None)"

theorem accept_decline_needs_context:
  assumes "k \<notin> set kinds"
    and "accept kinds declines ctx text k"
  shows "k \<in> set declines \<and> ctx text"
  using assms unfolding accept_def by blast

theorem accept_unknown_kind_rejected:
  assumes "k \<notin> set kinds" and "k \<notin> set declines"
  shows "\<not> accept kinds declines ctx text k"
  using assms unfolding accept_def by blast

theorem spec_reply_needs_accept:
  "spec_reply kinds declines ctx text organ_out = Some r \<longleftrightarrow>
     (\<exists>k. organ_out = Some (k, r) \<and> accept kinds declines ctx text k)"
  unfolding spec_reply_def by (auto split: option.splits)

subsection \<open>Which head declines a specialist may fill\<close>

text \<open>The path markers of a decline for lack of a reading (exam.py's \<^verbatim>\<open>READING_DECLINES\<close>).\<close>
definition reading_declines :: "string list" where
  "reading_declines = [''act:clarify'', ''unverified:'', ''corpus_query'', ''factoid'', ''deliberation'',
     ''capability:'', ''arb:'', ''compose'', ''family_precedence:low_credit'', ''verified:'', ''cube:'']"

text \<open>A decline the specialist may fill: the core lacked a reading (a reading-decline marker, or a
  precision_guard P-code), and the path carries no check (a G/Q-coded precision guard, a same-name
  clash, a weight question, an unresolved reference).  \<open>infix\<close> is the substring oracle and \<open>check\<close>
  is the oracle for exam.py's \<^verbatim>\<open>CHECK\<close> regex.\<close>
definition fillable :: "(string \<Rightarrow> string \<Rightarrow> bool) \<Rightarrow> (string \<Rightarrow> bool) \<Rightarrow> string \<Rightarrow> bool" where
  "fillable infix check p \<longleftrightarrow>
     \<not> check p \<and> ((\<exists>m \<in> set reading_declines. infix m p) \<or> infix ''precision_guard:P'' p)"

theorem fillable_never_a_check: "check p \<Longrightarrow> \<not> fillable infix check p"
  unfolding fillable_def by blast

subsection \<open>Composition\<close>

text \<open>exam.py's status test is \<^verbatim>\<open>status != "answered"\<close>; every other status is a withheld reply.\<close>
datatype status = Answered | Withheld

text \<open>The composition the exam measures: the core first; the specialist's accepted reply replaces
  the core's only where the core withheld and its path is fillable; otherwise the core's reply stands.\<close>
definition compose :: "('r \<Rightarrow> status) \<Rightarrow> ('r \<Rightarrow> 'p) \<Rightarrow> ('p \<Rightarrow> bool) \<Rightarrow> 'r \<Rightarrow> 'r option \<Rightarrow> 'r" where
  "compose status_of path_of fill head sp =
     (if status_of head \<noteq> Answered \<and> fill (path_of head)
      then (case sp of None \<Rightarrow> head | Some a \<Rightarrow> a)
      else head)"

text \<open>The whole exam turn: core reply, organ output, acceptance, fillability.\<close>
definition exam_turn ::
  "'k list \<Rightarrow> 'k list \<Rightarrow> ('t \<Rightarrow> bool) \<Rightarrow> (string \<Rightarrow> string \<Rightarrow> bool) \<Rightarrow> (string \<Rightarrow> bool) \<Rightarrow>
   ('r \<Rightarrow> status) \<Rightarrow> ('r \<Rightarrow> string) \<Rightarrow> 't \<Rightarrow> 'r \<Rightarrow> ('k \<times> 'r) option \<Rightarrow> 'r" where
  "exam_turn kinds declines ctx infix check status_of path_of text head organ_out =
     compose status_of path_of (fillable infix check) head (spec_reply kinds declines ctx text organ_out)"

theorem compose_never_overrides_answer:
  "status_of head = Answered \<Longrightarrow> compose status_of path_of fill head sp = head"
  unfolding compose_def by simp

theorem compose_only_fills_declines:
  assumes "compose status_of path_of fill head sp \<noteq> head"
  shows "status_of head = Withheld \<and> fill (path_of head) \<and>
         sp = Some (compose status_of path_of fill head sp)"
  using assms unfolding compose_def by (cases "status_of head"; auto split: option.splits if_splits)

text \<open>The specialist is consulted only on a fillable decline: elsewhere the composed reply does not
  depend on what the specialist would have said.\<close>
theorem compose_consults_only_fillable:
  assumes "\<not> (status_of head = Withheld \<and> fill (path_of head))"
  shows "compose status_of path_of fill head sp = compose status_of path_of fill head sp'"
  using assms unfolding compose_def by (cases "status_of head"; auto)

theorem exam_turn_respects_checks:
  "check (path_of head) \<Longrightarrow>
   exam_turn kinds declines ctx infix check status_of path_of text head organ_out = head"
  unfolding exam_turn_def compose_def fillable_def by simp

theorem exam_turn_changes_only_by_accepted_reply:
  assumes "exam_turn kinds declines ctx infix check status_of path_of text head organ_out \<noteq> head"
  shows "status_of head = Withheld \<and> fillable infix check (path_of head) \<and>
         (\<exists>k. organ_out = Some (k, exam_turn kinds declines ctx infix check status_of path_of text head organ_out)
              \<and> accept kinds declines ctx text k)"
  using compose_only_fills_declines[OF assms[unfolded exam_turn_def]]
  unfolding exam_turn_def spec_reply_needs_accept by blast

end
