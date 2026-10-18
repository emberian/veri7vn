theory Guards_Narrow
  imports Guards "Veri7vn_Routing.Fold_Cascade"
begin

text \<open>The precision guards are narrowing folds. In the routing cascade of
\<open>Fold_Cascade\<close> a \<open>Narrow\<close> fold asks the folds below it, and may only turn their
reply into a withheld one. Here the guard decision of this session is that
fold's test: the reply is withheld exactly when \<open>decision_auto\<close> names a firing
guard on the features read off the question and the reply below.

\<open>ext\<close> is the untrusted recognizer, a function from the question and the reply
below to \<open>feats\<close>. Nothing is assumed about it except where a theorem says so.
The fold's name is the one the cascade prefixes to the path; the real folds
write \<open>precision_guard:CODE|route\<close> (see \<open>withheld_path\<close>), which this model does
not reproduce.\<close>

definition guard_fold :: "(string \<Rightarrow> Fold_Cascade.reply \<Rightarrow> feats) \<Rightarrow> Fold_Cascade.fold" where
  "guard_fold ext = Narrow ''precision_guard''
     (\<lambda>t r. decision_auto (ext t r) \<noteq> None)
     (\<lambda>r. ''precision_guard'')"

theorem guard_fold_is_narrow: "is_narrow (guard_fold ext)"
  by (simp add: guard_fold_def)

text \<open>A guard fold withholds when a guard fires, and otherwise hands the reply
below up unchanged.\<close>

theorem guard_withholds:
  assumes "decision_auto (ext t (cascade fs base t)) \<noteq> None"
  shows "status (cascade (guard_fold ext # fs) base t) = Withheld"
  using assms by (simp add: guard_fold_def narrow_cascade_Cons)

theorem guard_passes:
  assumes "decision_auto (ext t (cascade fs base t)) = None"
  shows "cascade (guard_fold ext # fs) base t = cascade fs base t"
  using assms by (simp add: guard_fold_def narrow_cascade_Cons)

text \<open>Whatever the recognizer says, a stack of guard folds only removes
answers: an answer that survives is the base dispatcher's own answer, text
and path included.\<close>

theorem guards_never_add:
  assumes "\<forall>f \<in> set fs. \<exists>ext. f = guard_fold ext"
    and "status (cascade fs base t) = Answered"
  shows "cascade fs base t = base t"
proof (rule narrow_preserves_answer_text [OF _ assms(2)])
  show "\<forall>f \<in> set fs. is_narrow f"
    using assms(1) by (auto simp: guard_fold_def)
qed

text \<open>If the recognizer reports the reply's status faithfully (the kernel's
\<open>answered\<close> flag is true exactly on answered replies), a guard fold never touches
a reply that was already withheld or asked for clarification
(\<open>decision_needs_answer\<close>).\<close>

theorem guard_leaves_unanswered:
  assumes faithful: "\<forall>t r. answered (ext t r) \<longleftrightarrow> status r = Answered"
    and "status (cascade fs base t) \<noteq> Answered"
  shows "cascade (guard_fold ext # fs) base t = cascade fs base t"
proof (rule guard_passes)
  have "\<not> answered (ext t (cascade fs base t))"
    using faithful assms(2) by blast
  then show "decision_auto (ext t (cascade fs base t)) = None"
    by (rule decision_needs_answer)
qed

end
