theory Fold_Cascade
  imports Main
begin

section \<open>Oracle7's routing cascade as a HOL object\<close>

text \<open>
  Oracle7 answers a turn by calling the \<open>chat\<close> method of its newest runtime class. Each class
  ("fold") either handles the turn itself or calls the next class down with \<open>super().chat(...)\<close>.
  The catalogue \<open>audit/folds/folds.json\<close> lists all 361 classes in that order and gives each a kind.
  This theory gives every kind a meaning and proves what the ordering implies.

  A reply is a status, the path it took, and the text shown. A fold receives the text of the turn and
  the folds below it, as a function from a depth to a dispatcher: depth 0 is the next fold down,
  depth \<open>k\<close> passes over \<open>k\<close> folds, which is what an explicit \<open>X.chat(self, ...)\<close> call does.
\<close>

datatype status = Answered | Withheld | Clarification

record reply =
  status :: status
  path :: string
  response :: string

text \<open>Fold constructors and the catalogue kinds they model (counts are in \<open>audit/folds/README.md\<close>):
  \<^item> \<open>Narrow name guard message\<close>: kind \<open>narrow\<close>. Ask the folds below; if the guard fires on the
    question and their reply, withhold it under a path that names this fold.
  \<^item> \<open>PreRoute handler\<close>: kind \<open>pre_route\<close>. If the handler has its own reply, return it without
    asking below; otherwise ask below.
  \<^item> \<open>Post handler\<close>: kind \<open>post_replace\<close>. Ask below, then the handler may replace the reply.
  \<^item> \<open>Rewrite rewriter\<close>: kind \<open>rewrite\<close>. Ask below about a rewritten question when the rewriter applies.
  \<^item> \<open>Redispatch handler\<close>: kind \<open>post_redispatch\<close>. Ask below, then the handler may ask below again
    about other questions and build a new reply.
  \<^item> \<open>ProbeRewrite k rewriter\<close>: kind \<open>probe_rewrite\<close> (runtime AO). Probe the folds \<open>k\<close> levels down;
    if they answer, ask the next fold down about the same question, else about the rewritten one.
  \<^item> \<open>Replace handler\<close>: kinds \<open>replace\<close> and \<open>base\<close>. Answer without ever asking below.
  \<^item> \<open>Pass\<close>: kinds \<open>hook\<close>, \<open>helper\<close>, \<open>empty\<close>, \<open>join\<close>, \<open>module_patch\<close>, \<open>state_only\<close>, \<open>transparent\<close>. No
    \<open>chat\<close> of its own (or one that only records state): the turn goes straight down.
  \<^item> \<open>Skip k f\<close>: the catalogue field \<open>skips\<close>. Behave as \<open>f\<close>, but every call below passes over
    the next \<open>k\<close> folds.\<close>

datatype fold =
    Narrow string "string \<Rightarrow> reply \<Rightarrow> bool" "reply \<Rightarrow> string"
  | PreRoute "string \<Rightarrow> reply option"
  | Post "string \<Rightarrow> reply \<Rightarrow> reply option"
  | Rewrite "string \<Rightarrow> string option"
  | Redispatch "(string \<Rightarrow> reply) \<Rightarrow> string \<Rightarrow> reply \<Rightarrow> reply option"
  | ProbeRewrite nat "string \<Rightarrow> string option"
  | Replace "string \<Rightarrow> reply"
  | Pass
  | Skip nat fold

definition withhold :: "string \<Rightarrow> string \<Rightarrow> reply \<Rightarrow> reply" where
  "withhold name msg r = r\<lparr>status := Withheld, path := name @ ''>'' @ path r, response := msg\<rparr>"

lemma withhold_status [simp]: "status (withhold name msg r) = Withheld"
  and withhold_path [simp]: "path (withhold name msg r) = name @ ''>'' @ path r"
  and withhold_response [simp]: "response (withhold name msg r) = msg"
  by (simp_all add: withhold_def)

fun step :: "fold \<Rightarrow> (nat \<Rightarrow> string \<Rightarrow> reply) \<Rightarrow> string \<Rightarrow> reply" where
  "step (Narrow name g msg) inner t =
     (let r = inner 0 t in if g t r then withhold name (msg r) r else r)"
| "step (PreRoute h) inner t = (case h t of Some r \<Rightarrow> r | None \<Rightarrow> inner 0 t)"
| "step (Post h) inner t = (let r = inner 0 t in case h t r of Some r' \<Rightarrow> r' | None \<Rightarrow> r)"
| "step (Rewrite rw) inner t = (case rw t of Some t' \<Rightarrow> inner 0 t' | None \<Rightarrow> inner 0 t)"
| "step (Redispatch h) inner t =
     (let r = inner 0 t in case h (inner 0) t r of Some r' \<Rightarrow> r' | None \<Rightarrow> r)"
| "step (ProbeRewrite k cv) inner t =
     (if status (inner k t) = Answered then inner 0 t
      else (case cv t of Some t' \<Rightarrow> inner 0 t' | None \<Rightarrow> inner 0 t))"
| "step (Replace g) inner t = g t"
| "step Pass inner t = inner 0 t"
| "step (Skip k f) inner t = step f (\<lambda>n. inner (n + k)) t"

text \<open>The cascade of a fold list (tip first) over a base dispatcher. It is computed bottom-up as the
  list of dispatchers of every suffix, so a fold can reach any depth below it.\<close>

fun stack :: "fold list \<Rightarrow> (string \<Rightarrow> reply) \<Rightarrow> (string \<Rightarrow> reply) list" where
  "stack [] base = [base]"
| "stack (f # fs) base =
     (let s = stack fs base in step f (\<lambda>n. if n < length s then s ! n else last s) # s)"

definition cascade :: "fold list \<Rightarrow> (string \<Rightarrow> reply) \<Rightarrow> string \<Rightarrow> reply" where
  "cascade fs base = hd (stack fs base)"

lemma length_stack: "length (stack fs base) = Suc (length fs)"
  by (induction fs) (simp_all add: Let_def)

lemma stack_nonempty: "stack fs base \<noteq> []"
  by (cases fs) (simp_all add: Let_def)

lemma last_stack: "last (stack fs base) = base"
  by (induction fs) (simp_all add: Let_def stack_nonempty)

lemma stack_nth: "n \<le> length fs \<Longrightarrow> stack fs base ! n = cascade (drop n fs) base"
proof (induction fs arbitrary: n)
  case Nil
  then show ?case by (simp add: cascade_def)
next
  case (Cons f fs)
  show ?case
  proof (cases n)
    case 0
    then show ?thesis by (simp add: cascade_def Let_def)
  next
    case (Suc m)
    with Cons.prems have "m \<le> length fs" by simp
    with Suc Cons.IH show ?thesis by (simp add: Let_def)
  qed
qed

lemma cascade_Nil [simp]: "cascade [] base = base"
  by (simp add: cascade_def)

lemma cascade_Cons [simp]:
  "cascade (f # fs) base = step f (\<lambda>n. cascade (drop n fs) base)"
proof -
  have inner: "(\<lambda>n. if n < length (stack fs base) then stack fs base ! n else last (stack fs base))
             = (\<lambda>n. cascade (drop n fs) base)"
  proof
    fix n
    show "(if n < length (stack fs base) then stack fs base ! n else last (stack fs base))
          = cascade (drop n fs) base"
      using stack_nth[of n fs base] by (simp add: length_stack last_stack)
  qed
  have "cascade (f # fs) base
        = step f (\<lambda>n. if n < length (stack fs base) then stack fs base ! n else last (stack fs base))"
    by (simp add: cascade_def Let_def)
  also have "\<dots> = step f (\<lambda>n. cascade (drop n fs) base)"
    by (simp only: inner)
  finally show ?thesis .
qed

lemma cascade_Cons_apply:
  "cascade (f # fs) base t = step f (\<lambda>n. cascade (drop n fs) base) t"
  by simp

subsection \<open>Narrowing folds never add an answer\<close>

fun is_narrow :: "fold \<Rightarrow> bool" where
  "is_narrow (Narrow _ _ _) = True"
| "is_narrow _ = False"

lemma narrow_cascade_Cons:
  "cascade (Narrow name g msg # fs) base t =
     (if g t (cascade fs base t) then withhold name (msg (cascade fs base t)) (cascade fs base t)
      else cascade fs base t)"
  by (simp add: Let_def)

theorem narrow_never_adds:
  assumes "\<forall>f \<in> set fs. is_narrow f"
    and "status (cascade fs base t) = Answered"
  shows "status (base t) = Answered"
  using assms
proof (induction fs)
  case Nil
  then show ?case by simp
next
  case (Cons f fs)
  then obtain name g msg where f: "f = Narrow name g msg"
    by (cases f) auto
  from Cons.prems f show ?case
    by (auto simp: narrow_cascade_Cons Let_def split: if_splits intro: Cons.IH)
qed

theorem narrow_preserves_answer_text:
  assumes "\<forall>f \<in> set fs. is_narrow f"
    and "status (cascade fs base t) = Answered"
  shows "cascade fs base t = base t"
  using assms
proof (induction fs)
  case Nil
  then show ?case by simp
next
  case (Cons f fs)
  then obtain name g msg where f: "f = Narrow name g msg"
    by (cases f) auto
  from Cons.prems f show ?case
    by (auto simp: narrow_cascade_Cons Let_def split: if_splits intro: Cons.IH)
qed

theorem narrow_withheld_path:
  assumes "\<forall>f \<in> set fs. is_narrow f"
    and "cascade fs base t \<noteq> base t"
  shows "\<exists>name g msg p. Narrow name g msg \<in> set fs
           \<and> status (cascade fs base t) = Withheld
           \<and> path (cascade fs base t) = name @ ''>'' @ p"
  using assms
proof (induction fs)
  case Nil
  then show ?case by simp
next
  case (Cons f fs)
  then obtain name g msg where f: "f = Narrow name g msg"
    by (cases f) auto
  show ?case
  proof (cases "g t (cascade fs base t)")
    case True
    with f show ?thesis by (auto simp: narrow_cascade_Cons Let_def)
  next
    case False
    with Cons.prems f have "cascade fs base t \<noteq> base t" "\<forall>f\<in>set fs. is_narrow f"
      by (simp_all add: narrow_cascade_Cons del: cascade_Cons)
    from Cons.IH[OF this(2) this(1)] False f show ?thesis
      by (fastforce simp: narrow_cascade_Cons Let_def)
  qed
qed

subsection \<open>The wider class of folds that cannot add an answer\<close>

text \<open>A pre-route whose own replies are never answers, and a post-processor that only answers where
  the folds below already answered, are as safe as a narrowing fold. So are \<open>Pass\<close> and passing over
  folds with \<open>Skip\<close>.\<close>

fun non_adding :: "fold \<Rightarrow> bool" where
  "non_adding (Narrow _ _ _) = True"
| "non_adding Pass = True"
| "non_adding (PreRoute h) = (\<forall>t r. h t = Some r \<longrightarrow> status r \<noteq> Answered)"
| "non_adding (Post h) = (\<forall>t r r'. h t r = Some r' \<longrightarrow> status r' = Answered \<longrightarrow> status r = Answered)"
| "non_adding (Skip k f) = non_adding f"
| "non_adding _ = False"

lemma non_adding_step:
  assumes "non_adding f"
    and "\<And>n t. status (inner n t) = Answered \<Longrightarrow> status (base t) = Answered"
    and "status (step f inner t) = Answered"
  shows "status (base t) = Answered"
  using assms
proof (induction f arbitrary: inner)
  case (Narrow name g msg)
  then show ?case by (auto simp: Let_def split: if_splits)
next
  case (PreRoute h)
  then show ?case by (auto split: option.splits)
next
  case (Post h)
  show ?case
  proof (cases "h t (inner 0 t)")
    case None
    with Post.prems(3) have "status (inner 0 t) = Answered" by (simp add: Let_def)
    then show ?thesis by (rule Post.prems(2))
  next
    case (Some r')
    with Post.prems(3) have r': "status r' = Answered" by (simp add: Let_def)
    from Post.prems(1) have "\<forall>t r r'. h t r = Some r' \<longrightarrow> status r' = Answered \<longrightarrow> status r = Answered"
      by simp
    with Some r' have "status (inner 0 t) = Answered" by blast
    then show ?thesis by (rule Post.prems(2))
  qed
next
  case (Skip k f)
  have "non_adding f" using Skip.prems(1) by simp
  moreover have "\<And>n t. status (inner (n + k) t) = Answered \<Longrightarrow> status (base t) = Answered"
    using Skip.prems(2) by blast
  moreover have "status (step f (\<lambda>n. inner (n + k)) t) = Answered"
    using Skip.prems(3) by simp
  ultimately show ?case by (rule Skip.IH)
qed auto

theorem non_adding_never_adds:
  assumes "\<forall>f \<in> set fs. non_adding f"
    and "status (cascade fs base t) = Answered"
  shows "status (base t) = Answered"
proof -
  have "\<forall>n t. status (cascade (drop n fs) base t) = Answered \<longrightarrow> status (base t) = Answered"
    using assms(1)
  proof (induction fs)
    case Nil
    then show ?case by simp
  next
    case (Cons f fs)
    have nf: "non_adding f" and nfs: "\<forall>f \<in> set fs. non_adding f"
      using Cons.prems by simp_all
    have IH: "\<And>n t. status (cascade (drop n fs) base t) = Answered \<Longrightarrow> status (base t) = Answered"
      using Cons.IH[OF nfs] by blast
    show ?case
    proof (intro allI impI)
      fix n t
      assume a: "status (cascade (drop n (f # fs)) base t) = Answered"
      show "status (base t) = Answered"
      proof (cases n)
        case 0
        with a have st: "status (step f (\<lambda>n. cascade (drop n fs) base) t) = Answered" by simp
        show ?thesis by (rule non_adding_step[OF nf IH st])
      next
        case (Suc m)
        with a have "status (cascade (drop m fs) base t) = Answered" by simp
        then show ?thesis by (rule IH)
      qed
    qed
  qed
  from this[rule_format, of 0 t] assms(2) show ?thesis by simp
qed

lemma narrow_non_adding: "is_narrow f \<Longrightarrow> non_adding f"
  by (cases f) simp_all

corollary narrow_never_adds':
  "\<forall>f \<in> set fs. is_narrow f \<Longrightarrow> status (cascade fs base t) = Answered \<Longrightarrow> status (base t) = Answered"
  by (rule non_adding_never_adds) (auto intro: narrow_non_adding)

subsection \<open>Where an answer can come from\<close>

text \<open>In a cascade built from narrowing folds, pre-routes, rewrites, AO's probe-and-rewrite and
  passes (with or without skipping), every answer is either the base's reply to some question or the
  own reply of one of the pre-routes. Narrowing folds and rewrites never write an answer themselves.\<close>

fun core :: "fold \<Rightarrow> fold" where
  "core (Skip k f) = core f"
| "core f = f"

fun attributing :: "fold \<Rightarrow> bool" where
  "attributing (Narrow _ _ _) = True"
| "attributing (PreRoute _) = True"
| "attributing (Rewrite _) = True"
| "attributing (ProbeRewrite _ _) = True"
| "attributing Pass = True"
| "attributing (Skip _ f) = attributing f"
| "attributing _ = False"

definition attributed :: "fold set \<Rightarrow> (string \<Rightarrow> reply) \<Rightarrow> reply \<Rightarrow> bool" where
  "attributed S base r \<longleftrightarrow> (\<exists>t'. r = base t') \<or> (\<exists>h t'. PreRoute h \<in> core ` S \<and> h t' = Some r)"

lemma attributed_mono: "S \<subseteq> S' \<Longrightarrow> attributed S base r \<Longrightarrow> attributed S' base r"
  unfolding attributed_def by blast

lemma attributed_insert: "attributed S base r \<Longrightarrow> attributed (insert f S) base r"
  by (rule attributed_mono[of S "insert f S"]) auto

lemma attributing_step:
  assumes "attributing f"
    and "\<And>n t. status (inner n t) = Answered \<Longrightarrow> attributed S base (inner n t)"
    and "status (step f inner t) = Answered"
  shows "attributed (insert f S) base (step f inner t)"
  using assms
proof (induction f arbitrary: inner)
  case (Narrow name g msg)
  show ?case
  proof (cases "g t (inner 0 t)")
    case True
    with Narrow.prems(3) show ?thesis by (simp add: Let_def)
  next
    case False
    with Narrow.prems(3) have "status (inner 0 t) = Answered" by (simp add: Let_def)
    then have "attributed S base (inner 0 t)" by (rule Narrow.prems(2))
    with False show ?thesis by (simp add: Let_def attributed_insert)
  qed
next
  case (PreRoute h)
  show ?case
  proof (cases "h t")
    case None
    with PreRoute.prems(3) have "status (inner 0 t) = Answered" by simp
    then have "attributed S base (inner 0 t)" by (rule PreRoute.prems(2))
    with None show ?thesis by (simp add: attributed_insert)
  next
    case (Some r)
    then have "step (PreRoute h) inner t = r" by simp
    moreover have "PreRoute h \<in> core ` insert (PreRoute h) S" by simp
    ultimately show ?thesis using Some unfolding attributed_def by blast
  qed
next
  case (Rewrite rw)
  have "\<exists>t'. step (Rewrite rw) inner t = inner 0 t'"
    by (auto split: option.splits)
  then obtain t' where t': "step (Rewrite rw) inner t = inner 0 t'" by blast
  with Rewrite.prems(3) have "status (inner 0 t') = Answered" by simp
  then have "attributed S base (inner 0 t')" by (rule Rewrite.prems(2))
  with t' show ?case by (simp add: attributed_insert)
next
  case (ProbeRewrite k cv)
  have "\<exists>t'. step (ProbeRewrite k cv) inner t = inner 0 t'"
    by (auto split: option.splits)
  then obtain t' where t': "step (ProbeRewrite k cv) inner t = inner 0 t'" by blast
  with ProbeRewrite.prems(3) have "status (inner 0 t') = Answered" by simp
  then have "attributed S base (inner 0 t')" by (rule ProbeRewrite.prems(2))
  with t' show ?case by (simp add: attributed_insert)
next
  case Pass
  from Pass.prems(3) have "status (inner 0 t) = Answered" by simp
  then have "attributed S base (inner 0 t)" by (rule Pass.prems(2))
  then show ?case by (simp add: attributed_insert)
next
  case (Skip k f)
  have "attributing f" using Skip.prems(1) by simp
  moreover have "\<And>n t. status (inner (n + k) t) = Answered \<Longrightarrow> attributed S base (inner (n + k) t)"
    using Skip.prems(2) by blast
  moreover have "status (step f (\<lambda>n. inner (n + k)) t) = Answered"
    using Skip.prems(3) by simp
  ultimately have "attributed (insert f S) base (step f (\<lambda>n. inner (n + k)) t)"
    by (rule Skip.IH)
  then show ?case by (simp add: attributed_def)
qed auto

theorem answers_are_attributed:
  assumes "\<forall>f \<in> set fs. attributing f"
    and "status (cascade fs base t) = Answered"
  shows "(\<exists>t'. cascade fs base t = base t')
       \<or> (\<exists>h t'. PreRoute h \<in> core ` set fs \<and> h t' = Some (cascade fs base t))"
proof -
  have "\<forall>n t. status (cascade (drop n fs) base t) = Answered
           \<longrightarrow> attributed (set (drop n fs)) base (cascade (drop n fs) base t)"
    using assms(1)
  proof (induction fs)
    case Nil
    then show ?case by (auto simp: attributed_def)
  next
    case (Cons f fs)
    have af: "attributing f" and afs: "\<forall>f \<in> set fs. attributing f"
      using Cons.prems by simp_all
    have IH0: "\<And>n t. status (cascade (drop n fs) base t) = Answered
                 \<Longrightarrow> attributed (set (drop n fs)) base (cascade (drop n fs) base t)"
      using Cons.IH[OF afs] by blast
    have IH: "\<And>n t. status (cascade (drop n fs) base t) = Answered
                     \<Longrightarrow> attributed (set fs) base (cascade (drop n fs) base t)"
      using IH0 attributed_mono[OF set_drop_subset] by blast
    show ?case
    proof (intro allI impI)
      fix n t
      assume a: "status (cascade (drop n (f # fs)) base t) = Answered"
      show "attributed (set (drop n (f # fs))) base (cascade (drop n (f # fs)) base t)"
      proof (cases n)
        case 0
        with a have st: "status (step f (\<lambda>n. cascade (drop n fs) base) t) = Answered" by simp
        have "attributed (insert f (set fs)) base (step f (\<lambda>n. cascade (drop n fs) base) t)"
          by (rule attributing_step[OF af IH st])
        with 0 show ?thesis by simp
      next
        case (Suc m)
        with a have "status (cascade (drop m fs) base t) = Answered" by simp
        then have "attributed (set (drop m fs)) base (cascade (drop m fs) base t)" by (rule IH0)
        with Suc show ?thesis by simp
      qed
    qed
  qed
  from this[rule_format, of 0 t] assms(2) show ?thesis
    by (simp add: attributed_def)
qed

subsection \<open>Pre-routes shadow what lies below them\<close>

theorem preroute_shadowing:
  "h t = Some r \<Longrightarrow> cascade (PreRoute h # fs) base t = r"
  by simp

text \<open>Folds that only ever ask the next fold down about the same question.\<close>

fun same_question :: "fold \<Rightarrow> bool" where
  "same_question (Narrow _ _ _) = True"
| "same_question (PreRoute _) = True"
| "same_question (Post _) = True"
| "same_question Pass = True"
| "same_question _ = False"

lemma same_question_step:
  "same_question f \<Longrightarrow> inner 0 t = inner' 0 t \<Longrightarrow> step f inner t = step f inner' t"
  by (cases f) (simp_all add: Let_def split: option.splits)

text \<open>Below a pre-route that answers, nothing matters: if the folds above it only pass the same
  question down, the reply is the same whatever folds and base lie underneath.\<close>

theorem preroute_shadowing_below:
  assumes "\<forall>f \<in> set xs. same_question f"
    and "h t = Some r"
  shows "cascade (xs @ PreRoute h # ys) base t = cascade (xs @ PreRoute h # ys') base' t"
  using assms(1)
proof (induction xs)
  case Nil
  with assms(2) show ?case by simp
next
  case (Cons x xs)
  have sx: "same_question x" and sxs: "\<forall>f \<in> set xs. same_question f"
    using Cons.prems by simp_all
  have ih: "cascade (xs @ PreRoute h # ys) base t = cascade (xs @ PreRoute h # ys') base' t"
    by (rule Cons.IH[OF sxs])
  have "step x (\<lambda>n. cascade (drop n (xs @ PreRoute h # ys)) base) t
        = step x (\<lambda>n. cascade (drop n (xs @ PreRoute h # ys')) base') t"
    by (rule same_question_step[OF sx]) (simp add: ih)
  then show ?case by (simp only: append_Cons cascade_Cons)
qed

text \<open>A deeper pre-route that can only fire where a shallower one already fires is dead code,
  provided the folds between them pass the same question down.\<close>

lemma preroute_remove_inert:
  assumes "\<forall>f \<in> set ys. same_question f"
    and "h' t = None"
  shows "cascade (ys @ PreRoute h' # zs) base t = cascade (ys @ zs) base t"
  using assms(1)
proof (induction ys)
  case Nil
  with assms(2) show ?case by simp
next
  case (Cons y ys)
  have sy: "same_question y" and sys: "\<forall>f \<in> set ys. same_question f"
    using Cons.prems by simp_all
  have ih: "cascade (ys @ PreRoute h' # zs) base t = cascade (ys @ zs) base t"
    by (rule Cons.IH[OF sys])
  have "step y (\<lambda>n. cascade (drop n (ys @ PreRoute h' # zs)) base) t
        = step y (\<lambda>n. cascade (drop n (ys @ zs)) base) t"
    by (rule same_question_step[OF sy]) (simp add: ih)
  then show ?case by (simp only: append_Cons cascade_Cons)
qed

theorem preroute_dead_copy:
  assumes "\<forall>f \<in> set ys. same_question f"
    and "\<And>t. h' t \<noteq> None \<Longrightarrow> h t \<noteq> None"
  shows "cascade (PreRoute h # ys @ PreRoute h' # zs) base = cascade (PreRoute h # ys @ zs) base"
proof
  fix t
  show "cascade (PreRoute h # ys @ PreRoute h' # zs) base t = cascade (PreRoute h # ys @ zs) base t"
  proof (cases "h t")
    case None
    have "\<not> h' t \<noteq> None" using assms(2)[of t] None by blast
    then have h't: "h' t = None" by simp
    have "cascade (ys @ PreRoute h' # zs) base t = cascade (ys @ zs) base t"
      by (rule preroute_remove_inert[where h'=h' and t=t, OF assms(1) h't])
    with None show ?thesis by simp
  next
    case (Some r)
    then show ?thesis by simp
  qed
qed

subsection \<open>Folds that are never reached\<close>

text \<open>A fold that skips \<open>k\<close> folds makes those \<open>k\<close> folds unreachable from above it.\<close>

theorem skip_hides:
  assumes "length xs = k" and "length xs' = k"
  shows "cascade (Skip k f # xs @ ys) base = cascade (Skip k f # xs' @ ys) base"
proof -
  have "\<And>n. drop (n + k) (xs @ ys) = drop n ys"
    using assms by simp
  moreover have "\<And>n. drop (n + k) (xs' @ ys) = drop n ys"
    using assms by simp
  ultimately show ?thesis by (simp add: fun_eq_iff del: drop_append)
qed

text \<open>Folds that never reach past the next fold down.\<close>

fun local_fold :: "fold \<Rightarrow> bool" where
  "local_fold (Skip _ _) = False"
| "local_fold (ProbeRewrite _ _) = False"
| "local_fold _ = True"

lemma local_step:
  "local_fold f \<Longrightarrow> inner 0 = inner' 0 \<Longrightarrow> step f inner = step f inner'"
  by (rule ext, cases f) (simp_all add: Let_def split: option.splits)

text \<open>A replacing fold cuts the cascade: whatever lies beneath it, including the base, is never
  consulted, as long as no fold above it reaches past it.\<close>

theorem replace_cuts_below:
  assumes "\<forall>f \<in> set xs. local_fold f"
  shows "cascade (xs @ Replace g # ys) base = cascade (xs @ Replace g # ys') base'"
  using assms
proof (induction xs)
  case Nil
  then show ?case by (simp add: fun_eq_iff)
next
  case (Cons x xs)
  have lx: "local_fold x" and lxs: "\<forall>f \<in> set xs. local_fold f"
    using Cons.prems by simp_all
  have ih: "cascade (xs @ Replace g # ys) base = cascade (xs @ Replace g # ys') base'"
    by (rule Cons.IH[OF lxs])
  have "step x (\<lambda>n. cascade (drop n (xs @ Replace g # ys)) base)
        = step x (\<lambda>n. cascade (drop n (xs @ Replace g # ys')) base')"
    by (rule local_step[OF lx]) (simp add: ih)
  then show ?case by (simp only: append_Cons cascade_Cons)
qed

text \<open>The same holds when folds above it pass over others, as long as no jump lands below it.
  \<open>reach f\<close> is how many folds \<open>f\<close> can pass over; fold \<open>i\<close> (counting from the top, from 0)
  can reach position \<open>i + 1 + reach f\<close>. In the shipped chain the replacing fold \<open>b\<close> sits at
  position 359, and every jump above it lands at 359 or higher up (catalogue field
  \<open>inner_calls\<close>), so \<open>OracleReleaseRuntime.chat\<close> is never called from the tip.\<close>

fun reach :: "fold \<Rightarrow> nat" where
  "reach (Skip k f) = k + reach f"
| "reach (ProbeRewrite k _) = k"
| "reach _ = 0"

lemma reach_step:
  "(\<And>m. m \<le> reach f \<Longrightarrow> inner m = inner' m) \<Longrightarrow> step f inner t = step f inner' t"
proof (induction f arbitrary: inner inner' t)
  case (Skip k f)
  have "step f (\<lambda>n. inner (n + k)) t = step f (\<lambda>n. inner' (n + k)) t"
    by (rule Skip.IH) (use Skip.prems in auto)
  then show ?case by simp
qed (simp_all add: Let_def split: option.splits)

theorem replace_cuts_below_reach:
  assumes "\<forall>i < length xs. i + reach (xs ! i) < length xs"
  shows "cascade (xs @ Replace g # ys) base = cascade (xs @ Replace g # ys') base'"
proof -
  let ?L = "xs @ Replace g # ys" and ?L' = "xs @ Replace g # ys'"
  have "d \<le> length xs \<Longrightarrow> cascade (drop (length xs - d) ?L) base = cascade (drop (length xs - d) ?L') base'"
    for d
  proof (induction d rule: less_induct)
    case (less d)
    show ?case
    proof (cases d)
      case 0
      then show ?thesis by (simp add: fun_eq_iff)
    next
      case (Suc e)
      define n where "n = length xs - d"
      from less.prems Suc have n: "n < length xs" by (simp add: n_def)
      have dx: "drop n xs = xs ! n # drop (Suc n) xs"
        using n by (simp add: Cons_nth_drop_Suc)
      have L: "drop n ?L = xs ! n # drop (Suc n) ?L" and L': "drop n ?L' = xs ! n # drop (Suc n) ?L'"
        using n dx by simp_all
      have inner_eq: "\<And>m. m \<le> reach (xs ! n) \<Longrightarrow>
              cascade (drop m (drop (Suc n) ?L)) base = cascade (drop m (drop (Suc n) ?L')) base'"
      proof -
        fix m assume m: "m \<le> reach (xs ! n)"
        from assms n have r: "n + reach (xs ! n) < length xs" by blast
        define d' where "d' = length xs - (m + Suc n)"
        have lt: "d' < d" unfolding d'_def using m r n less.prems Suc n_def by arith
        have le: "d' \<le> length xs" by (simp add: d'_def)
        have len: "length xs - d' = m + Suc n" unfolding d'_def using m r by arith
        have "cascade (drop (length xs - d') ?L) base = cascade (drop (length xs - d') ?L') base'"
          using less.IH[OF lt le] .
        then have "cascade (drop (m + Suc n) ?L) base = cascade (drop (m + Suc n) ?L') base'"
          by (simp only: len)
        then show "cascade (drop m (drop (Suc n) ?L)) base = cascade (drop m (drop (Suc n) ?L')) base'"
          by (simp only: drop_drop)
      qed
      have "step (xs ! n) (\<lambda>m. cascade (drop m (drop (Suc n) ?L)) base)
          = step (xs ! n) (\<lambda>m. cascade (drop m (drop (Suc n) ?L')) base')"
      proof (rule ext)
        fix t
        show "step (xs ! n) (\<lambda>m. cascade (drop m (drop (Suc n) ?L)) base) t
            = step (xs ! n) (\<lambda>m. cascade (drop m (drop (Suc n) ?L')) base') t"
          by (rule reach_step[OF inner_eq])
      qed
      then show ?thesis
        unfolding n_def[symmetric] by (simp only: L L' cascade_Cons)
    qed
  qed
  from this[of "length xs"] show ?thesis by simp
qed

subsection \<open>Why the hypotheses are needed\<close>

text \<open>A post-processor and a rewrite can each produce an answer where the folds below had none, so
  the never-adds theorems must exclude them (catalogue kinds \<open>post_replace\<close>, \<open>post_redispatch\<close>,
  \<open>rewrite\<close>, \<open>probe_rewrite\<close>, and \<open>pre_route\<close> folds with answered own replies).\<close>

definition declined :: reply where
  "declined = \<lparr>status = Withheld, path = ''base'', response = ''''\<rparr>"

definition answer :: reply where
  "answer = \<lparr>status = Answered, path = ''fold'', response = ''42''\<rparr>"

lemma post_can_add:
  "status (cascade [Post (\<lambda>t r. Some answer)] (\<lambda>t. declined) ''q'') = Answered
   \<and> status ((\<lambda>t. declined) ''q'') = Withheld"
  by (simp add: answer_def declined_def)

lemma rewrite_can_add:
  "status (cascade [Rewrite (\<lambda>t. Some ''r'')] (\<lambda>t. if t = ''r'' then answer else declined) ''q'') = Answered
   \<and> status ((\<lambda>t. if t = ''r'' then answer else declined) ''q'') = Withheld"
  by (simp add: answer_def declined_def)

end
