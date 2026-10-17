theory Converse
  imports "HOL-Library.Code_Target_Numeral"
begin

section \<open>Oracle7's conversation conversion layer\<close>

text \<open>
  Source: \<open>upstream/root/wander-train/oracle_release_runtime_ao.py\<close> (runtime
  AO, produced by the M53 meta-fold), over runtime AN (the LiminalTransition
  instrument) and AM (final-result dialogue state), both descending from
  runtime E (the ACTS layer that introduced the per-session dialogue slot).
  The released head carries the same layer shape as w529 over
  \<open>chat_context_v2.py\<close>: rewrite the turn, then re-dispatch through the
  unchanged chain. The AO docstring states the two properties this theory is
  about: ``Nothing here answers; the warrant is whatever the re-dispatched
  route provides'' and ``the probe must not write state''.

  Division of trust, as in lane F (verified decision over an untrusted fetch):
  the untrusted recognizer reads the raw surface with the organ's regexes and
  produces a \<^bold>\<open>reading\<close> (one constructor per guard). Everything past that
  point - the referent resolution, the four constructions, the probe gating,
  the fallback, the note that is recorded on the transition - is the verified
  kernel below, and the theorems hold for \<^emph>\<open>every\<close> reading the recognizer
  can produce. The chains themselves (probe entry = AM/E without AN, dispatch
  entry = AN/AM/E) stay abstract: two locale-fixed functions.
\<close>

datatype status = Answered | Withheld | Clarify

datatype reply = Reply (r_status: status) (r_path: String.literal) (r_text: String.literal)

text \<open>The four constructions of the M53 meta-fold (AO docstring, clusters in
  descending support): referent substitution (deictics), ellipsis completion,
  opener alias, repair accept.\<close>

datatype construction =
  Referent_substitution
| Ellipsis_completion
| Opener_alias
| Repair_accept

text \<open>One typed reading of a turn's surface. The recognizer decides which
  constructor applies (it owns the regexes); the flag on Repair / Opener /
  Ellipsis says the captured topic is \<^emph>\<open>itself\<close> referential (matches the
  deictic pattern, or one of the three referential noun phrases), which is
  what AO's \<open>_topic_or_referent\<close> re-checks in Python. \<open>Pred\<close> carries the
  lowercased predicate row of the PREDICATE_OF table; \<open>Free_deictic\<close> carries
  the surface split around its \<^emph>\<open>first\<close> deictic occurrence (Python:
  \<open>DEICTIC.sub(topic, s, count=1)\<close>).\<close>

datatype reading =
  Plain
| Repair String.literal bool
| Opener String.literal bool
| Ellipsis String.literal bool
| Bare String.literal
| Pred String.literal
| Free_deictic String.literal String.literal
| Continuation

text \<open>Dialogue state. The slot's \<open>last_topic\<close> is written only by ACTS
  routes (rarely); the log is AN's transition list, most recent last. A turn
  records its outcome and, if its surface \<^emph>\<open>opened\<close> a topic (opener form,
  or a conversion that resolved one), the topic it grounded - AO's
  \<open>_live_topic\<close> walks exactly this in reverse, skipping turns that were not
  answered and grounding none.\<close>

datatype turn = Turn (t_status: status) (t_opened: "String.literal option")

datatype dstate = DState (slot_topic: "String.literal option") (log: "turn list")

section \<open>The organ's tables, transcribed\<close>

text \<open>PREDICATE_OF of \<open>oracle_release_runtime_ao.py\<close> lines 33-41, as
  (key, prefix, suffix) triples with the topic as the hole;
  \<open>tables_check.py\<close> asserts equality against the Python dict.\<close>

definition predicate_of :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "predicate_of =
     [(STR ''what lives there'', STR ''What lives in '', STR ''?''),
      (STR ''is it big'', STR ''How big is '', STR ''?''),
      (STR ''where is it'', STR ''Where is '', STR ''?''),
      (STR ''how old is it'', STR ''How old is '', STR ''?''),
      (STR ''who discovered it'', STR ''Who discovered '', STR ''?''),
      (STR ''what is it made of'', STR ''What is '', STR '' made of?''),
      (STR ''is that true'', STR ''Summarize '', STR ''.'')]"

text \<open>The three noun phrases AO's \<open>_topic_or_referent\<close> treats as references
  even though they contain no deictic word.\<close>

definition referential_nps :: "String.literal list" where
  "referential_nps = [STR ''the big one'', STR ''the small one'', STR ''the other one'']"

definition summarize :: "String.literal \<Rightarrow> String.literal" where
  "summarize t = STR ''Summarize '' + t + STR ''.''"

definition lookup_pred :: "String.literal \<Rightarrow> (String.literal \<times> String.literal) option" where
  "lookup_pred k =
     (case find (\<lambda>row. fst row = k) predicate_of of
        Some row \<Rightarrow> Some (fst (snd row), snd (snd row))
      | None \<Rightarrow> None)"

section \<open>Referent resolution and the rewrite\<close>

primrec last_opened :: "turn list \<Rightarrow> String.literal option" where
  "last_opened [] = None"
| "last_opened (tr # trs) =
     (if t_status tr = Answered \<and> t_opened tr \<noteq> None then t_opened tr else last_opened trs)"

text \<open>AO \<open>_live_topic\<close>: the slot's \<open>last_topic\<close> if an ACTS route set one,
  else the most recent \<^emph>\<open>grounded\<close> turn on the path - one that was answered
  and opened a topic.\<close>

definition live_topic :: "dstate \<Rightarrow> String.literal option" where
  "live_topic \<sigma> =
     (case slot_topic \<sigma> of
        Some t \<Rightarrow> Some t
      | None \<Rightarrow> last_opened (rev (log \<sigma>)))"

text \<open>AO \<open>_topic_or_referent\<close>: a captured topic that is itself referential
  resolves against the live topic, or the conversion declines.\<close>

fun resolved :: "dstate \<Rightarrow> String.literal \<Rightarrow> bool \<Rightarrow> String.literal option" where
  "resolved \<sigma> t referential =
     (if referential \<or> t \<in> set referential_nps then live_topic \<sigma> else Some t)"

text \<open>AO \<open>_convert\<close>, over typed readings. Repair is tried first, then
  opener, then ellipsis, then bare phrase, then the deictic branch - the
  recognizer's job is only to say \<^emph>\<open>which\<close> shape the surface has; the order
  below therefore does not encode regex precedence but the one dispatch the
  reading stands for.\<close>

fun rewrite :: "dstate \<Rightarrow> reading \<Rightarrow> (String.literal \<times> construction) option" where
  "rewrite \<sigma> (Repair t referential) =
     map_option (\<lambda>e. (summarize e, Repair_accept)) (resolved \<sigma> t referential)"
| "rewrite \<sigma> (Opener t referential) =
     map_option (\<lambda>e. (summarize e, Opener_alias)) (resolved \<sigma> t referential)"
| "rewrite \<sigma> (Ellipsis t referential) =
     map_option (\<lambda>e. (summarize e, Ellipsis_completion)) (resolved \<sigma> t referential)"
| "rewrite \<sigma> (Bare t) = Some (summarize t, Ellipsis_completion)"
| "rewrite \<sigma> (Pred k) =
     (case lookup_pred k of
        Some (pre, suf) \<Rightarrow>
          map_option (\<lambda>e. (pre + e + suf, Referent_substitution)) (live_topic \<sigma>)
      | None \<Rightarrow> None)"
| "rewrite \<sigma> (Free_deictic pre suf) =
     map_option (\<lambda>e. (pre + e + suf, Referent_substitution)) (live_topic \<sigma>)"
| "rewrite \<sigma> Plain = None"
| "rewrite \<sigma> Continuation = None"

section \<open>The turn: probe, rewrite, re-dispatch\<close>

text \<open>
  AO \<open>chat\<close>, as one function. \<open>probe\<close> is the unchanged chain entered
  below the instrument (AM: writes the dialogue slot, never the log); \<open>full\<close>
  is the chain through the instrument (AN: records the transition and writes
  the slot). Both are parameters - the theorems hold for any pair satisfying
  AN's own shipped claim that it ``returns exactly what AM.chat returns''.

  The three AO decision points, in order:
    \<^enum> the probe on the raw turn answered: dispatch the raw turn (a conversion
      is applied ONLY when the unchanged chain would not answer);
    \<^enum> no conversion, or a conversion that does not change the surface (a
      rewrite equal to the raw text is not a rewrite): dispatch the raw turn;
    \<^enum> a conversion that changes the surface: probe the \<^emph>\<open>specific\<close> rewritten
      form; if that is unserved and the construction was a referent
      substitution with a live topic, fall back to the grounded summary of the
      SAME topic. Either way the answer - if any - comes from the chain.
\<close>

definition form :: "(dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate) \<Rightarrow> dstate \<Rightarrow> reading
                   \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "form probe \<sigma> rd t =
     (if r_status (fst (probe \<sigma> t)) = Answered then t
      else case rewrite \<sigma> rd of
             None \<Rightarrow> t
           | Some (r, c) \<Rightarrow>
               if r = t then t
               else if c = Referent_substitution \<and> r_status (fst (probe \<sigma> r)) \<noteq> Answered
                 then (case live_topic \<sigma> of Some e \<Rightarrow> summarize e | None \<Rightarrow> r)
               else r)"

text \<open>The conversion note AO records on the transition: construction,
  from-surface, dispatched form, and whether the specific predicate was
  unserved (the fallback fired).\<close>

definition note_of :: "(dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate) \<Rightarrow> dstate \<Rightarrow> reading
                      \<Rightarrow> String.literal \<Rightarrow> (construction \<times> String.literal \<times> String.literal \<times> bool) option" where
  "note_of probe \<sigma> rd t =
     (if r_status (fst (probe \<sigma> t)) = Answered then None
      else case rewrite \<sigma> rd of
             None \<Rightarrow> None
           | Some (r, c) \<Rightarrow>
               if r = t then None
               else Some (c, t, form probe \<sigma> rd t,
                          c = Referent_substitution \<and> r_status (fst (probe \<sigma> r)) \<noteq> Answered
                            \<and> live_topic \<sigma> \<noteq> None))"

text \<open>One turn of the conversation layer: exactly one dispatch through the
  instrumented chain, on the form chosen above. The probes appear only in the
  choice of \<open>form\<close>; their state writes are discarded by construction, which
  is AO's snapshot-then-restore.\<close>

definition conv_step :: "(dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate)
                         \<Rightarrow> (dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate)
                         \<Rightarrow> dstate \<Rightarrow> reading \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate" where
  "conv_step probe full \<sigma> rd t = full \<sigma> (form probe \<sigma> rd t)"

section \<open>Theorems\<close>

text \<open>Premise names quote the shipped claims they formalize:
  \<^item> \<open>an_agree\<close>: ``AN.chat returns exactly what AM.chat returns''
    (oracle_release_runtime_an.py, docstring line 23);
  \<^item> \<open>am_no_log\<close>: AM writes the dialogue slot only - the transition log is
    AN's, and the probe enters below AN (AO calls \<open>_Plain.chat\<close>, i.e. AM,
    directly);
  \<^item> \<open>an_one_transition\<close>: AN records exactly one transition per chat call
    (one append to the path; oracle_release_runtime_an.py line 168).
\<close>

theorem conv_step_is_one_dispatch:
  "conv_step probe full \<sigma> rd t = full \<sigma> (form probe \<sigma> rd t)"
  by (rule conv_step_def)

text \<open>T1. A rewrite never answers by itself: an answered reply of the layer
  IS the chain's reply to the dispatched form - the same reply the unchanged
  chain gives, so the warrant shown is the re-dispatched route's.\<close>

theorem warrant_stays_with_route:
  assumes an_agree: "\<And>\<sigma> t. fst (probe \<sigma> t) = fst (full \<sigma> t)"
  assumes step: "conv_step probe full \<sigma> rd t = (rep, \<sigma>')"
  assumes answered: "r_status rep = Answered"
  shows "rep = fst (full \<sigma> (form probe \<sigma> rd t))"
    and "rep = fst (probe \<sigma> (form probe \<sigma> rd t))"
  using step answered an_agree by (auto simp: conv_step_def)

text \<open>The gate: the layer dispatches something other than the raw turn only
  when the probe on the raw turn declined, and the dispatched form is always
  either a conversion's output or the grounded fallback summary. This is
  ``conversions are applied ONLY when the unchanged chain would not answer''
  plus the complete case analysis of what can be dispatched.\<close>

theorem form_cases:
  "form probe \<sigma> rd t = t
   \<or> (\<exists>r c. rewrite \<sigma> rd = Some (r, c) \<and> r \<noteq> t \<and> form probe \<sigma> rd t = r
          \<and> r_status (fst (probe \<sigma> t)) \<noteq> Answered)
   \<or> (\<exists>r e. rewrite \<sigma> rd = Some (r, Referent_substitution) \<and> r \<noteq> t
          \<and> r_status (fst (probe \<sigma> t)) \<noteq> Answered
          \<and> r_status (fst (probe \<sigma> r)) \<noteq> Answered
          \<and> live_topic \<sigma> = Some e \<and> form probe \<sigma> rd t = summarize e)"
  by (auto simp: form_def split: option.splits status.splits if_splits)

corollary gate_no_new_answer:
  assumes other: "form probe \<sigma> rd t \<noteq> t"
  shows "r_status (fst (probe \<sigma> t)) \<noteq> Answered"
  using other by (auto simp: form_def split: option.splits if_splits)

text \<open>T2, part one. The probe leaves state unchanged: the state after the
  turn is exactly the state after the single dispatch - the probe's state
  write (AM does write the slot on the way through) never survives, which is
  the snapshot-then-restore.\<close>

theorem probe_state_discarded:
  "snd (conv_step probe full \<sigma> rd t) = snd (full \<sigma> (form probe \<sigma> rd t))"
  by (simp add: conv_step_def)

text \<open>T2, part two, sharp. However many probes ran (none, one or two), the
  turn adds exactly ONE transition to the log. AO's first version re-dispatched
  through the instrumented parent after a failed probe, so every conversion
  recorded two transitions and ``the held-out turn count inflated 248 \<rightarrow> 294'';
  the gate rejected it for exactly that.\<close>

theorem probe_leaves_log_unchanged:
  assumes am_no_log: "\<And>\<sigma> t. log (snd (probe \<sigma> t)) = log \<sigma>"
  assumes an_one_transition: "\<And>\<sigma> t. length (log (snd (full \<sigma> t))) = Suc (length (log \<sigma>))"
  shows "length (log (snd (conv_step probe full \<sigma> rd t))) = Suc (length (log \<sigma>))"
  using an_one_transition by (simp add: conv_step_def)

text \<open>The note is honest: a note exists only when a conversion actually
  changed the dispatched form, it names the construction and the form really
  dispatched (the fallback summary, when the specific predicate was unserved),
  and the unserved flag is set only for referent substitutions whose specific
  form the chain declined.\<close>

theorem note_iff_conversion:
  "note_of probe \<sigma> rd t = Some (c, f, f', u) \<longleftrightarrow>
     (\<exists>r. rewrite \<sigma> rd = Some (r, c) \<and> r \<noteq> t \<and> r_status (fst (probe \<sigma> t)) \<noteq> Answered
          \<and> f = t \<and> f' = form probe \<sigma> rd t
          \<and> u = (c = Referent_substitution \<and> r_status (fst (probe \<sigma> r)) \<noteq> Answered
                    \<and> live_topic \<sigma> \<noteq> None))"
  by (auto simp: note_of_def form_def split: option.splits if_splits prod.splits)

text \<open>No echo: a dispatched form that differs from the raw turn always comes
  from the rewrite (or its documented fallback); the layer never silently
  substitutes a form of its own devising.\<close>

corollary no_silent_substitution:
  assumes other: "form probe \<sigma> rd t \<noteq> t"
  shows "\<exists>r c e. rewrite \<sigma> rd = Some (r, c)
                 \<and> (form probe \<sigma> rd t = r \<or> (c = Referent_substitution \<and> live_topic \<sigma> = Some e
                        \<and> form probe \<sigma> rd t = summarize e))"
  using other by (auto simp: form_def split: option.splits if_splits)

text \<open>Table sanity: seven predicate rows, distinct keys - the transcription
  cannot drift into a silent shadow (tables_check.py additionally asserts the
  text against the organ's Python dict).\<close>

lemma predicate_of_shape:
  "length predicate_of = 7" and "distinct (map fst predicate_of)"
  by (simp_all add: predicate_of_def)

text \<open>Determinism transfers: a deterministic pair of chain entry points gives
  a deterministic conversation layer.\<close>

theorem conv_step_deterministic:
  assumes det: "\<And>\<sigma> t a b. full \<sigma> t = a \<Longrightarrow> full \<sigma> t = b \<Longrightarrow> a = b"
  shows "conv_step probe full \<sigma> rd t = a \<Longrightarrow> conv_step probe full \<sigma> rd t = b \<Longrightarrow> a = b"
  by (metis conv_step_def det)

end
