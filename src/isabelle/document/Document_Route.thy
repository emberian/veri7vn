theory Document_Route
  imports Main
begin

text \<open>Oracle7's document route as one decision over fetched evidence.

Four engine rules are lifted:

- the anchored claim pool of @{text stage5m13d2_anchored_general_document}: a turn with
  neither an exact-title page nor a conjunctive full-text match has NO claims at all --
  lexical-context sentences are discarded without a query anchor;
- the tiered cue pick of @{text oracle_release_runtime_aa} / @{text oracle_release_runtime_y}:
  among the usable (non-fragment) claims of the pool, the answer is the hits of the FIRST
  cue tier that any of them matches; a fragment (a sentence starting mid-parenthetical or
  lower-case) is skipped unless every sentence is one; a when-question only answers
  sentences that carry a year;
- the weak-route admission law of @{text verified_retrieval_v1} / @{text verified_reach_v1}:
  a sentence a weak route retrieved (full-text search, page reading, corpus lookup) is
  ASSERTED only when the independent checker passed it, or it defines the very term that
  was asked about; otherwise it is shown as an unverified passage and the reply is withheld;
- the clarify terminal of @{text oracle_release_runtime_u}: a turn nothing could read ends
  in a typed clarify that asserts nothing.

The fetch (sqlite/FTS), title resolution, the cue regexes, the checker and the WordNet
senses stay outside HOL: their results arrive as flags and claim lists, exactly as lane F's
reader took the linker's rows. The theorems say what an answer means about that evidence,
and only that: an answer always cites claims of the anchored, admitted pool, taken at the
first tier that matched, never a fragment where a whole sentence existed, never without a
year when a year was asked for; an unverified sentence is never asserted; a clarify cites
nothing.\<close>

section \<open>Evidence\<close>

record claim =
  claim_id :: String.literal
  page :: String.literal
  sentence :: String.literal
  fragment :: bool        \<comment> \<open> starts mid-parenthetical or lower-case (aa's FRAGMENT) \<close>
  has_year :: bool        \<comment> \<open> carries a 19xx/20xx year (aa's YEAR) \<close>
  tier :: "natural option"    \<comment> \<open> the first cue tier whose regex matched, if any \<close>

record pool =
  resolved :: bool        \<comment> \<open> the topic resolved to one exact-title page \<close>
  conjunctive :: natural  \<comment> \<open> conjunctive full-text claims the pool admitted \<close>
  claims :: "claim list"  \<comment> \<open> the pool in admission order: exact page, then fts, then context \<close>

record evidence =
  pool_e :: pool
  tiers :: "natural list"           \<comment> \<open> cue tier order; specific forms first, broad last \<close>
  checked :: bool               \<comment> \<open> the independent checker passed the candidate \<close>
  subject_defines :: bool       \<comment> \<open> the candidate's subject is the asked term (DEFINED_TERM) \<close>
  disambiguates :: bool         \<comment> \<open> the candidate's page is a disambiguation ("may refer to") \<close>
  covered :: "bool list"        \<comment> \<open> per content word of the asked term: it occurs in the candidate \<close>
  candidate :: "claim option"   \<comment> \<open> the sentence the route retrieved; None: nothing was found \<close>
  topic :: String.literal       \<comment> \<open> the asked topic, as the organ prints it \<close>
  asked :: String.literal       \<comment> \<open> the question in the organ's own phrasing \<close>
  future :: bool                \<comment> \<open> the statement speaks of tomorrow-ish time (converse ack) \<close>

datatype cue_kind = Cause \<comment> \<open> what causes X / why does X happen \<close>
  | Process \<comment> \<open> how does X work \<close>
  | When \<comment> \<open> when did X start / end / \<dots> \<close>

datatype weak_route = FTS \<comment> \<open> factoid:fts -- full-text search \<close>
  | Page \<comment> \<open> factoid:page -- a page was read \<close>
  | CorpusQuery \<comment> \<open> corpus_query:property_of \<close>
  | ArbDefinitional \<comment> \<open> arb:definitional \<close>

datatype turn =
    Explain cue_kind
  | Weak weak_route
  | Statement \<comment> \<open> organ_converse_v1's statement move: acknowledge + one grounded sentence \<close>
  | Fallback \<comment> \<open> nothing read the turn; runtime U's clarify terminal speaks \<close>

section \<open>The anchored pool (m13d2: no query anchor, no claims)\<close>

definition anchor_present :: "pool \<Rightarrow> bool" where
  "anchor_present p \<longleftrightarrow> resolved p \<or> 0 < conjunctive p"

definition admitted :: "pool \<Rightarrow> claim list" where
  "admitted p = (if anchor_present p then claims p else [])"

lemma admitted_empty: "\<not> anchor_present p \<Longrightarrow> admitted p = []"
  by (simp add: admitted_def)

lemma admitted_refl: "anchor_present p \<Longrightarrow> admitted p = claims p"
  by (simp add: admitted_def)

section \<open>The tiered pick (aa / y: specific cues first, fragments skipped, years for when)\<close>

definition usable :: "claim list \<Rightarrow> claim list" where
  "usable cs = (let u = filter (\<lambda>c. \<not> fragment c) cs in if u \<noteq> [] then u else cs)"

definition tier_hits :: "natural \<Rightarrow> bool \<Rightarrow> claim list \<Rightarrow> claim list" where
  "tier_hits t need_year cs = filter (\<lambda>c. tier c = Some t \<and> (need_year \<longrightarrow> has_year c)) cs"

fun first_tier :: "natural list \<Rightarrow> bool \<Rightarrow> claim list \<Rightarrow> claim list" where
  "first_tier [] _ _ = []"
| "first_tier (t # ts) ny cs =
     (let h = tier_hits t ny cs in if h \<noteq> [] then h else first_tier ts ny cs)"

lemma first_tier_nil_iff:
  "first_tier T ny cs = [] \<longleftrightarrow> (\<forall>t\<in>set T. tier_hits t ny cs = [])"
proof (induct T)
  case Nil show ?case by simp
next
  case (Cons t T) show ?case
  proof (cases "tier_hits t ny cs = []")
    case True thus ?thesis using Cons by simp
  next
    case False thus ?thesis by simp
  qed
qed

text \<open>Which tier the pick came from: a prefix of tiers with no hits, then the tier whose
hits were taken.\<close>
lemma first_tier_split:
  assumes "first_tier T ny cs = h # r"
  shows "\<exists>pre t suf. T = pre @ t # suf \<and> (\<forall>t'\<in>set pre. tier_hits t' ny cs = [])
    \<and> tier_hits t ny cs = h # r"
using assms proof (induct T arbitrary: h r)
  case Nil thus ?case by simp
next
  case (Cons a T)
  show ?case
  proof (cases "tier_hits a ny cs = []")
    case True
    hence "first_tier T ny cs = h # r" using Cons(2) by simp
    then obtain pre t suf where "T = pre @ t # suf" "\<forall>t'\<in>set pre. tier_hits t' ny cs = []"
      "tier_hits t ny cs = h # r" using Cons(1) by blast
    moreover hence "\<forall>t'\<in>set (a # pre). tier_hits t' ny cs = []" using True by simp
    ultimately show ?thesis by (metis Cons_eq_appendI)
  next
    case False
    hence "tier_hits a ny cs = h # r" using Cons(2) by simp
    thus ?thesis by (intro exI[where x="[]"] exI[where x=a] exI[where x=T], simp)
  qed
qed

lemma tier_hits_member:
  "c \<in> set (tier_hits t ny cs) \<Longrightarrow> c \<in> set cs \<and> tier c = Some t \<and> (ny \<longrightarrow> has_year c)"
  by (auto simp: tier_hits_def)

lemma usable_member:
  "c \<in> set (usable cs) \<Longrightarrow> c \<in> set cs \<and> ( (\<exists>d\<in>set cs. \<not> fragment d) \<longrightarrow> \<not> fragment c)"
  by (auto simp: usable_def Let_def filter_empty_conv split: if_splits)

lemma usable_all_fragments:
  "(\<forall>c\<in>set cs. fragment c) \<Longrightarrow> usable cs = cs"
  by (auto simp: usable_def Let_def filter_empty_conv)

section \<open>The decision\<close>

datatype decline = NoAnchor \<comment> \<open> no page and no conjunctive match anchored the query \<close>
  | NoAdmittedStatement \<comment> \<open> the pool holds no statement of the asked form \<close>

datatype outcome =
    Answer claim "claim option"  \<comment> \<open> lead sentence cited, plus at most one more (aa's hits[:2]) \<close>
  | UnverifiedPassage weak_route String.literal  \<comment> \<open> shown, never asserted (verified_retrieval) \<close>
  | Declined decline
  | Clarify \<comment> \<open> the typed clarify terminal; asserts nothing \<close>

definition need_year :: "cue_kind \<Rightarrow> bool" where
  "need_year k \<longleftrightarrow> k = When"

text \<open>Which weak routes withhold with their own text when they find nothing; the factoid
routes pass the turn through to the chain instead (w420 returns the parent's reply).\<close>
definition withholds_empty :: "weak_route \<Rightarrow> bool" where
  "withholds_empty r \<longleftrightarrow> r = CorpusQuery"

definition definitional_release :: "evidence \<Rightarrow> bool" where
  "definitional_release ev \<longleftrightarrow> subject_defines ev \<and> list_all id (covered ev)"

fun decide :: "turn \<Rightarrow> evidence \<Rightarrow> outcome" where
  "decide (Explain k) ev =
     (if \<not> anchor_present (pool_e ev) then Declined NoAnchor
      else case first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) of
             [] \<Rightarrow> Declined NoAdmittedStatement
           | h # r \<Rightarrow> Answer h (if r = [] then None else Some (hd r)))"
| "decide (Weak r) ev =
     (case candidate ev of
        None \<Rightarrow> (if withholds_empty r then Declined NoAdmittedStatement else Clarify)
      | Some c \<Rightarrow> if checked ev then Answer c None
                  else if definitional_release ev then Answer c None
                  else UnverifiedPassage r (sentence c))"
| "decide Statement ev =
     (case candidate ev of
        None \<Rightarrow> Clarify
      | Some c \<Rightarrow> if anchor_present (pool_e ev) \<and> definitional_release ev \<and> \<not> disambiguates ev
                  then Answer c None else Clarify)"
| "decide Fallback ev = Clarify"

section \<open>The reply (status, path, text; rendered so the citation is manifest)\<close>

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"

definition cite :: "claim \<Rightarrow> String.literal" where
  "cite c = STR ''['' + claim_id c + STR '']''"

definition render_lead :: "claim \<Rightarrow> String.literal" where
  "render_lead c = STR ''According to '' + page c + STR '', '' + sentence c + STR '' '' + cite c"

definition render_extra :: "claim \<Rightarrow> String.literal" where
  "render_extra e = page e + STR '' also records: '' + sentence e + STR '' '' + cite e"

fun render_answer :: "claim \<Rightarrow> claim option \<Rightarrow> String.literal" where
  "render_answer c None = render_lead c"
| "render_answer c (Some e) = render_lead c + STR '' '' + render_extra e"

definition no_anchor_text :: "evidence \<Rightarrow> String.literal" where
  "no_anchor_text ev = STR ''I have no admitted entry for '' + topic ev + STR ''.''
     + STR '' The record I hold has no page of its own for it, and no passage that carries every word of the question, so there is nothing to anchor an answer on.''"

definition no_statement_text :: "evidence \<Rightarrow> String.literal" where
  "no_statement_text ev = STR ''The admitted record for '' + topic ev + STR '' contains no statement that answers '' + asked ev + STR ''. I will not infer one.''"

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

definition unverified_text :: "String.literal \<Rightarrow> String.literal" where
  "unverified_text s = STR ''I found a passage that may be related, but I can'' + apos +
    STR ''t verify it answers your question: '' + dq + s + dq"

definition no_corpus_text :: String.literal where
  "no_corpus_text = STR ''No provenance-admitted sentence in the abstracts corpus answers that.''"

definition ack_text :: "evidence \<Rightarrow> String.literal" where
  "ack_text ev = (if future ev then STR ''Good luck with it!'' else STR ''Got it.'')"

definition statement_text :: "evidence \<Rightarrow> claim \<Rightarrow> String.literal" where
  "statement_text ev c = ack_text ev + STR '' Since you mention '' + topic ev + STR '': ''
     + sentence c + STR '' '' + cite c + STR '' Want to know more about it?''"

definition clarify_text :: String.literal where
  "clarify_text = STR ''I didn'' + apos + STR ''t fully parse that, so I won'' + apos + STR ''t guess. I can summarize a topic, compare two things, list facts, give a timeline, explain something simply, define a term, reason about why and what-if, and discuss any document you teach me. A shorter, more direct phrasing usually lands.''"

definition cue_path :: "cue_kind \<Rightarrow> String.literal" where
  "cue_path k = (case k of Cause \<Rightarrow> STR ''capability:what_causes''
    | Process \<Rightarrow> STR ''capability:how_does'' | When \<Rightarrow> STR ''capability:when_did'')"

definition route_name :: "weak_route \<Rightarrow> String.literal" where
  "route_name r = (case r of FTS \<Rightarrow> STR ''factoid:fts'' | Page \<Rightarrow> STR ''factoid:page''
    | CorpusQuery \<Rightarrow> STR ''corpus_query:property_of'' | ArbDefinitional \<Rightarrow> STR ''arb:definitional'')"

fun status_of :: "outcome \<Rightarrow> String.literal" where
  "status_of (Answer _ _) = STR ''answered''"
| "status_of (UnverifiedPassage _ _) = STR ''withheld''"
| "status_of (Declined _) = STR ''withheld''"
| "status_of Clarify = STR ''clarification''"

fun path_of :: "turn \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "path_of (Explain k) (Answer _ _) = cue_path k"
| "path_of (Explain k) (Declined _) = cue_path k"
| "path_of (Weak r) (Answer _ _) = STR ''verified:weak|'' + route_name r"
| "path_of (Weak r) (UnverifiedPassage _ _) = STR ''unverified:'' + route_name r"
| "path_of (Weak r) (Declined _) = route_name r"
| "path_of Statement (Answer _ _) = STR ''organ:converse>statement''"
| "path_of _ Clarify = STR ''act:clarify''"
| "path_of _ _ = STR ''''"

fun response_of :: "turn \<Rightarrow> evidence \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "response_of (Explain k) ev (Answer c e) = render_answer c e"
| "response_of (Explain k) ev (Declined NoAnchor) = no_anchor_text ev"
| "response_of (Explain k) ev (Declined NoAdmittedStatement) = no_statement_text ev"
| "response_of (Weak r) ev (Answer c None) = render_lead c"
| "response_of (Weak r) ev (UnverifiedPassage _ s) = unverified_text s"
| "response_of (Weak r) ev (Declined NoAdmittedStatement) = no_corpus_text"
| "response_of Statement ev (Answer c None) = statement_text ev c"
| "response_of t ev Clarify = clarify_text"
| "response_of t ev _ = STR ''''"

text \<open>The claims a reply puts in brackets: the assertion's witnesses.\<close>
fun cited_claims :: "outcome \<Rightarrow> claim list" where
  "cited_claims (Answer c (Some e)) = [c, e]"
| "cited_claims (Answer c None) = [c]"
| "cited_claims _ = []"

section \<open>What an answer means about the evidence\<close>

text \<open>No answer without an anchor: m13d2's rule as a theorem. The claim-pool routes (Explain,
and the statement move, which asks for the anchor in its own guard) never answer unanchored;
the weak factoid routes read a single fetched sentence, not the pool, and their law is the
check-or-definition rule of weak\_answer\_needs\_check\_or\_definition below.\<close>
theorem no_answer_unanchored:
  "\<not> anchor_present (pool_e ev) \<Longrightarrow> decide (Explain k) ev \<noteq> Answer c e"
  by simp

theorem statement_never_unanchored:
  "\<not> anchor_present (pool_e ev) \<Longrightarrow> decide Statement ev \<noteq> Answer c e"
  by (simp split: option.splits)

theorem explain_answer_witnessed:
  assumes "decide (Explain k) ev = Answer c e"
  shows "anchor_present (pool_e ev)" and "c \<in> set (admitted (pool_e ev))"
    and "e = None \<or> the e \<in> set (admitted (pool_e ev))"
    and "c \<in> set (usable (admitted (pool_e ev)))"
    and "e = None \<or> the e \<in> set (usable (admitted (pool_e ev)))"
proof -
  show "anchor_present (pool_e ev)" using assms by (auto split: if_splits list.splits)
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h" "e = (if r = [] then None else Some (hd r))"
    using assms by (auto split: list.splits if_splits)
  obtain pre t suf where
    th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    using first_tier_split[OF ft] by blast
  have hu: "h \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of h t "need_year k" "usable (admitted (pool_e ev))"] th by simp
  have ru: "r = [] \<or> hd r \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of "hd r" t "need_year k" "usable (admitted (pool_e ev))"] th
    by (cases r) auto
  have u_sub: "set (usable (admitted (pool_e ev))) \<subseteq> set (admitted (pool_e ev))"
    by (auto simp: usable_def Let_def)
  show "c \<in> set (usable (admitted (pool_e ev)))" using hu by (simp add: ce)
  show "e = None \<or> the e \<in> set (usable (admitted (pool_e ev)))" using ru ce by auto
  show "c \<in> set (admitted (pool_e ev))" using hu u_sub ce by auto
  show "e = None \<or> the e \<in> set (admitted (pool_e ev))" using ru u_sub ce by auto
qed

text \<open>The pick came from the first tier that matched, after a prefix of tiers with no hits.\<close>
theorem explain_tier_precedence:
  assumes "decide (Explain k) ev = Answer c e"
  shows "\<exists>pre t suf. tiers ev = pre @ t # suf
    \<and> (\<forall>t'\<in>set pre. tier_hits t' (need_year k) (usable (admitted (pool_e ev))) = [])
    \<and> c \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))"
proof -
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h"
    using assms by (auto split: list.splits if_splits)
  from first_tier_split[OF ft] obtain pre t suf where
    sp: "tiers ev = pre @ t # suf"
    and pre: "\<forall>t'\<in>set pre. tier_hits t' (need_year k) (usable (admitted (pool_e ev))) = []"
    and th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    by blast
  have "c \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))" using th ce by simp
  with sp pre show ?thesis by blast
qed

theorem explain_needs_the_cue:
  assumes "decide (Explain k) ev = Answer c e"
  shows "\<exists>t. tier c = Some t" and "need_year k \<Longrightarrow> has_year c"
  and "need_year k \<Longrightarrow> e = None \<or> has_year (the e)"
proof -
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h" "e = (if r = [] then None else Some (hd r))"
    using assms by (auto split: list.splits if_splits)
  obtain pre t suf where
    th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    using first_tier_split[OF ft] by blast
  have hu: "h \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))" using th by simp
  have hr: "r = [] \<or> hd r \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))"
    using th by (cases r) auto
  show "\<exists>t. tier c = Some t" using tier_hits_member[OF hu] ce by blast
  show "need_year k \<Longrightarrow> has_year c" using tier_hits_member[OF hu] ce by auto
  show "need_year k \<Longrightarrow> e = None \<or> has_year (the e)"
    using tier_hits_member hr ce by (cases r) auto
qed

text \<open>Fragments never lead while a whole sentence is available (aa's FRAGMENT skip).\<close>
theorem explain_not_fragment_when_whole_exists:
  assumes "decide (Explain k) ev = Answer c e"
    and "\<exists>d\<in>set (admitted (pool_e ev)). \<not> fragment d"
  shows "\<not> fragment c" and "e = None \<or> \<not> fragment (the e)"
proof -
  have sub: "set (usable (admitted (pool_e ev))) \<subseteq> {d. \<not> fragment d}"
    using assms(2) by (auto simp: usable_def Let_def filter_empty_conv split: if_splits)
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h" "e = (if r = [] then None else Some (hd r))"
    using assms(1) by (auto split: list.splits if_splits)
  obtain pre t suf where
    th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    using first_tier_split[OF ft] by blast
  have hu: "h \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of h t "need_year k" "usable (admitted (pool_e ev))"] th by simp
  have ru: "r = [] \<or> hd r \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of "hd r" t "need_year k" "usable (admitted (pool_e ev))"] th
    by (cases r) auto
  show "\<not> fragment c" using hu sub by (auto simp: ce)
  show "e = None \<or> \<not> fragment (the e)" using ru sub ce by (cases r) auto
qed

text \<open>The explain declines are exactly their conditions.\<close>
theorem explain_no_anchor_iff:
  "decide (Explain k) ev = Declined NoAnchor \<longleftrightarrow> \<not> anchor_present (pool_e ev)"
  by (auto split: if_splits list.splits)

theorem explain_no_statement_iff:
  "decide (Explain k) ev = Declined NoAdmittedStatement \<longleftrightarrow>
    anchor_present (pool_e ev) \<and> first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = []"
  by (auto simp: first_tier_nil_iff[symmetric] split: if_splits list.splits)

section \<open>The weak-route law (verified_retrieval: shown is not asserted)\<close>

theorem weak_unverified_iff:
  "decide (Weak r) ev = UnverifiedPassage r' s \<longleftrightarrow>
     (\<exists>c. candidate ev = Some c \<and> \<not> checked ev \<and> \<not> definitional_release ev
       \<and> r' = r \<and> s = sentence c)"
  by (auto split: option.splits if_splits)

theorem weak_answer_needs_check_or_definition:
  assumes "decide (Weak r) ev = Answer c e"
  shows "e = None \<and> candidate ev = Some c
    \<and> (checked ev \<or> definitional_release ev)"
  using assms by (auto split: option.splits if_splits)

theorem weak_declined_iff:
  "decide (Weak r) ev = Declined NoAdmittedStatement \<longleftrightarrow>
     candidate ev = None \<and> withholds_empty r"
  by (auto split: option.splits if_splits)

theorem weak_pass_through_iff:
  "decide (Weak r) ev = Clarify \<longleftrightarrow>
     candidate ev = None \<and> \<not> withholds_empty r"
  by (auto split: option.splits if_splits)

text \<open>The unverified reply: withheld, the weak route's path prefixed, the passage quoted
verbatim and nothing asserted over it.\<close>
theorem unverified_reply_shape:
  assumes "decide (Weak r) ev = UnverifiedPassage r s"
  shows "status_of (decide (Weak r) ev) = STR ''withheld''"
    and "path_of (Weak r) (decide (Weak r) ev) = STR ''unverified:'' + route_name r"
    and "response_of (Weak r) ev (decide (Weak r) ev) = unverified_text s"
    and "s = sentence (the (candidate ev)) \<and> \<not> checked ev \<and> \<not> definitional_release ev"
    and "cited_claims (decide (Weak r) ev) = []"
  using assms weak_unverified_iff by auto

section \<open>The statement move (organ_converse: only the subject's own definition)\<close>

theorem statement_answer_iff:
  "decide Statement ev = Answer c None \<longleftrightarrow>
     candidate ev = Some c \<and> anchor_present (pool_e ev)
       \<and> definitional_release ev \<and> \<not> disambiguates ev"
  by (cases "candidate ev") (auto split: if_splits)

theorem statement_clarify_iff:
  "decide Statement ev = Clarify \<longleftrightarrow> \<not> (\<exists>c. candidate ev = Some c \<and> anchor_present (pool_e ev)
       \<and> definitional_release ev \<and> \<not> disambiguates ev)"
  by (cases "candidate ev") (auto split: if_splits)

section \<open>The clarify terminal asserts nothing\<close>

theorem clarify_shape:
  "decide Fallback ev = Clarify"
  and "status_of Clarify = STR ''clarification''"
  and "path_of t Clarify = STR ''act:clarify''"
  and "response_of t ev Clarify = clarify_text"
  and "cited_claims Clarify = []"
  by auto

lemma cited_ne_nil_iff:
  "cited_claims x \<noteq> [] \<longleftrightarrow> (\<exists>c e. x = Answer c e)"
proof (cases x)
  case C: (Answer c e)
  show ?thesis
  proof (cases e)
    case N: None
    show ?thesis by (simp add: C N)
  next
    case S: (Some a)
    show ?thesis by (simp add: C S)
  qed
next
  case C: (UnverifiedPassage r s)
  show ?thesis by (simp add: C)
next
  case C: (Declined d)
  show ?thesis by (simp add: C)
next
  case C: Clarify
  show ?thesis by (simp add: C)
qed

theorem cited_iff_answer:
  "cited_claims (decide t ev) \<noteq> [] \<longleftrightarrow> (\<exists>c e. decide t ev = Answer c e)"
  by (rule cited_ne_nil_iff)

lemma cited_answer_shape:
  "cited_claims (Answer c e) = (case e of None \<Rightarrow> [c] | Some d \<Rightarrow> [c, d])"
proof (cases e)
  case N: None
  show ?thesis by (simp add: N)
next
  case S: (Some a)
  show ?thesis by (simp add: S)
qed

text \<open>Every answer's reply names its witnesses in brackets: the render and the citation
list agree, so the reply carries its citation by construction.\<close>
theorem answer_reply_carries_citation:
  assumes ans: "decide t ev = Answer c e"
  shows "response_of t ev (decide t ev) =
      (if t = Statement then statement_text ev c
       else if (\<exists>r. t = Weak r) then render_lead c
       else render_answer c e)"
    and "cited_claims (decide t ev) = (case e of None \<Rightarrow> [c] | Some d \<Rightarrow> [c, d])"
    and "STR ''['' + claim_id c + STR '']'' = cite c"
proof -
  show "cited_claims (decide t ev) = (case e of None \<Rightarrow> [c] | Some d \<Rightarrow> [c, d])"
    by (simp add: ans cited_answer_shape)
  show "STR ''['' + claim_id c + STR '']'' = cite c" by (simp add: cite_def)
  show "response_of t ev (decide t ev) =
      (if t = Statement then statement_text ev c
       else if (\<exists>r. t = Weak r) then render_lead c
       else render_answer c e)"
    using ans by (cases t; cases e; cases "candidate ev")
      (auto split: if_splits list.splits option.splits simp: cite_def)
qed

section \<open>Determinism\<close>

text \<open>@{const decide} is a total HOL function of the turn and the fetched evidence, so the
decision is deterministic by construction; no separate lemma is stated (as in lane F).\<close>

end
