theory Novel_Reader
  imports Main
begin

text \<open>Oracle7's relation specialist @{emph \<open>rel-novels\<close>} (upstream/root/specialists/rel-novels,
class RelationOrganV2) as a decision over fetched evidence. The specialist reads five hand-written
readers (author P50, publication date P577, narrative location P840, followed by P156, based on P144,
all forward) over the Wikidata relation store, answers only when the linked in-domain candidates agree
on one stored value, and otherwise declines in domain (recognise-then-decline) or stays silent. This
is the shipped organ's primary path, @{text relation_spec_v2.answer}; its fallback reader
(relation_spec_v1.answer over patterns.json) never fires on this specialist's panel (measured
2026-10-17: with the fallback disabled the panel numbers are identical), so the decision here is the
organ's whole behaviour on that evidence.

Everything the shipped code reads with a regex or a store query arrives here as fetched data: the
phrasing match, the slot, the candidate entities with their popularity, each entity's subclass-of
ancestor closure and its stored rows. The decision proves what an answer means about that evidence,
and only that. The fetch's flags are premises, never established here: @{term complete} claims the
rows hold every stored fact of that entity for the five properties, @{term dom_complete} claims the
ancestor rows are the result of the shipped closure walk over the store.\<close>

datatype rel_value = Entity natural | Literal String.literal | Blank
text \<open>Blank is any value the shipped value reading would skip: a blank node
(a literal naming @{text ".well-known/genid"}) and an entity with neither label nor English title.
The shipped reading also resolves an entity to its display label before comparing values, so two
entities that share a label are one value there; the fetch does that resolution and sends the result
as a @{const Literal}, which keeps this decision's comparisons identical to the shipped ones.\<close>

record candidate =
  qid :: natural
  links :: natural
  dom_complete :: bool
  ancestors :: "natural list list"
  rows :: "(natural \<times> rel_value) list"
  complete :: bool

record attempt =
  key :: natural
  idx :: natural
  slot_ok :: bool
  candidates :: "candidate list"

datatype outcome =
  Answer "natural \<times> natural \<times> rel_value"
  | Decline "natural \<times> natural"
  | Incomplete
  | Silent

record question_features =
  kind_conflict :: bool
  past :: bool
  question_words :: "String.literal list"
  value_words :: "(rel_value \<times> String.literal list) list"

section \<open>The reader table (relation_readers_v1: five properties, forward phrasings, one dropped)\<close>

text \<open>@{term readers} holds, per reader key, the number of forward phrasings and the indices the
natural measuring dropped. For these five keys the key IS the Wikidata property. Phrasings live in the
untrusted recognizer, which uses the shipped module's own compiled regexes; the table is what the
decision checks attempts against.\<close>

definition readers :: "(natural \<times> natural \<times> natural list) list" where
  "readers = [(50, 6, [2]), (577, 3, []), (840, 2, []), (156, 2, []), (144, 2, [])]"

definition in_table :: "natural \<Rightarrow> natural \<Rightarrow> bool" where
  "in_table k i = (\<exists>(k', n, dr) \<in> set readers. k = k' \<and> i < n)"

definition dropped :: "natural \<Rightarrow> natural \<Rightarrow> bool" where
  "dropped k i = (\<exists>(k', n, dr) \<in> set readers. k = k' \<and> i \<in> set dr)"

definition prop_of :: "natural \<Rightarrow> natural" where
  "prop_of k = k"

lemma readers_entries:
  "(k, n, dr) \<in> set readers \<longleftrightarrow>
    (k = 50 \<and> n = 6 \<and> dr = [2]) \<or> (k = 577 \<and> n = 3 \<and> dr = []) \<or>
    (k = 840 \<and> n = 2 \<and> dr = []) \<or> (k = 156 \<and> n = 2 \<and> dr = []) \<or> (k = 144 \<and> n = 2 \<and> dr = [])"
  by (simp add: readers_def)

lemma in_table_iff:
  "in_table k i \<longleftrightarrow>
    (k = 50 \<and> i < 6) \<or> (k = 577 \<and> i < 3) \<or> (k = 840 \<and> i < 2) \<or> (k = 156 \<and> i < 2) \<or> (k = 144 \<and> i < 2)"
  by (auto simp: in_table_def readers_entries readers_def)

lemma dropped_iff: "dropped k i \<longleftrightarrow> k = 50 \<and> i = 2"
  by (auto simp: dropped_def readers_def)

lemma table_props: "in_table k i \<Longrightarrow> prop_of k = k \<and> k \<in> {50, 577, 840, 156, 144}"
  by (auto simp: in_table_iff prop_of_def)

section \<open>The domain (relation_domains_v2: novels, roots only; the domain has no occupations)\<close>

definition novel_roots :: "natural list" where
  "novel_roots = [7725634, 47461344, 1667921, 13593966, 8261]"

definition domain_member :: "candidate \<Rightarrow> bool" where
  "domain_member c = (dom_complete c \<and>
     (\<exists>anc \<in> set (ancestors c). \<exists>x \<in> set anc. x \<in> set novel_roots))"

lemma domain_member_roots:
  assumes "domain_member c"
  shows "dom_complete c \<and> (\<exists>anc x. anc \<in> set (ancestors c) \<and> x \<in> set anc \<and> x \<in> set novel_roots)"
  using assms by (auto simp: domain_member_def)

section \<open>Stored values and the question\<close>

definition vals :: "natural \<Rightarrow> candidate \<Rightarrow> rel_value list" where
  "vals p c = remdups (filter (\<lambda>v. v \<noteq> Blank) (map snd (filter (\<lambda>(p', _). p' = p) (rows c))))"

lemma set_vals: "set (vals p c) = {v. v \<noteq> Blank \<and> (p, v) \<in> set (rows c)}"
  by (force simp: vals_def)

definition time_variant :: "natural list" where
  "time_variant = [36, 35, 6, 54, 159, 27, 17, 131, 286, 488, 1037, 108, 39, 463, 102, 26]"

lemma table_props_not_time_variant:
  "k \<in> {50, 577, 840, 156, 144} \<Longrightarrow> k \<notin> set time_variant"
  by (auto simp: time_variant_def)

definition restates :: "question_features \<Rightarrow> rel_value \<Rightarrow> bool" where
  "restates f v = (case map_of (value_words f) v of
      Some ws \<Rightarrow> ws \<noteq> [] \<and> set ws \<subseteq> set (question_words f) | None \<Rightarrow> False)"

section \<open>Candidate selection: at most three, or one when it dominates (the shipped rule)\<close>

text \<open>The shipped code applies the dominance rule to the linker's whole candidate list before
taking three (relation_spec_v2.answer): a first sense linked ten times more than every other sense
refers to itself.\<close>

definition dominated :: "candidate list \<Rightarrow> bool" where
  "dominated cs = (case cs of c # rest \<Rightarrow> rest \<noteq> [] \<and>
      10 * max 1 (fold max (map links rest) 0) \<le> links c | [] \<Rightarrow> False)"

definition select :: "candidate list \<Rightarrow> candidate list" where
  "select cs = (if dominated cs then take 1 cs else take 3 cs)"

abbreviation (input) selof :: "attempt \<Rightarrow> candidate list" where
  "selof a \<equiv> select (candidates a)"

abbreviation (input) mineof :: "attempt \<Rightarrow> candidate list" where
  "mineof a \<equiv> filter domain_member (take 3 (select (candidates a)))"

abbreviation (input) vsof :: "attempt \<Rightarrow> rel_value list list" where
  "vsof a \<equiv> map (vals (prop_of (key a))) (filter domain_member (take 3 (select (candidates a))))"

lemma select_cases:
  "select cs = take 3 cs \<or> (select cs = take 1 cs \<and> dominated cs)"
  by (cases "dominated cs") (simp_all add: select_def)

lemma select_subset: "set (select cs) \<subseteq> set cs"
  by (auto simp: select_def dest: in_set_takeD)

lemma select_nonempty: "cs \<noteq> [] \<Longrightarrow> select cs \<noteq> []"
  by (cases cs) (auto simp: select_def split: if_splits)

lemma select_head: "cs \<noteq> [] \<Longrightarrow> hd (select cs) = hd cs"
  by (cases cs) (auto simp: select_def split: if_splits)

section \<open>The walk over the question's matched phrasings, in order\<close>

text \<open>One attempt is one matched phrasing of the recognizer: which reader, which phrasing, whether
the slot is a whole name, and the candidates linked for that slot. The walk processes attempts in the
order the shipped code does (reader keys 50, 577, 840, 156, 144, phrasings in index order). An attempt
that is not a table phrasing is ignored (the recognizer uses the shipped regexes, so this cannot fire;
it bounds what a broken recognizer could do). A dropped phrasing only marks a decline, and only when
its first candidate is in domain. An answered phrasing needs every in-domain candidate of the selected
candidates to agree on one stored value; an attempt that cannot name one value declines when it had an
in-domain candidate at all. An answer that restates the question silences the whole turn, discarding
any decline marked so far, exactly as the shipped code returns None.\<close>


definition live :: "attempt \<Rightarrow> bool" where
  "live a \<longleftrightarrow> in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> []"

definition allc :: "attempt \<Rightarrow> bool" where
  "allc a \<longleftrightarrow> (\<forall>c \<in> set (selof a). complete c)"

text \<open>@{text agreed}: the in-domain candidates among the selected ones exist, each has at least one
stored value, they all hold the same set of values, and that set has exactly one member.\<close>

definition agreed :: "attempt \<Rightarrow> bool" where
  "agreed a \<longleftrightarrow> mineof a \<noteq> [] \<and> (\<forall>v \<in> set (vsof a). v \<noteq> []) \<and>
     (\<forall>v \<in> set (vsof a). set v = set (hd (vsof a))) \<and> length (hd (vsof a)) = 1"

datatype step = Cont "(natural \<times> natural) option" | Halt outcome

text \<open>What the walk does at one attempt: carry on, possibly marking a decline (kept only if nothing
was marked before), or end the turn.\<close>

definition step :: "question_features \<Rightarrow> attempt \<Rightarrow> step" where
  "step f a =
    (if \<not> live a then Cont None
     else if dropped (key a) (idx a) then
       Cont (if domain_member (hd (selof a)) then Some (prop_of (key a), qid (hd (selof a))) else None)
     else if \<not> allc a then Halt Incomplete
     else if \<not> agreed a then
       Cont (if mineof a = [] then None else Some (prop_of (key a), qid (hd (mineof a))))
     else if restates f (hd (hd (vsof a))) then Halt Silent
     else if prop_of (key a) \<in> set time_variant \<and> past f then Halt Silent
     else Halt (Answer (qid (hd (mineof a)), prop_of (key a), hd (hd (vsof a)))))"

fun walk :: "question_features \<Rightarrow> attempt list \<Rightarrow> (natural \<times> natural) option \<Rightarrow> outcome" where
  "walk f [] acc = (case acc of None \<Rightarrow> Silent | Some d \<Rightarrow> Decline d)"
| "walk f (a # rest) acc =
    (case step f a of
       Halt r \<Rightarrow> r
     | Cont m \<Rightarrow> walk f rest (case acc of None \<Rightarrow> m | Some d \<Rightarrow> Some d))"

definition decide_spec :: "question_features \<Rightarrow> attempt list \<Rightarrow> outcome" where
  "decide_spec f attempts = (if kind_conflict f then Silent else walk f attempts None)"

section \<open>What one attempt would answer, and what it marks as a decline\<close>

text \<open>@{text attempt_values} is one attempt's answer: it is @{term Some} exactly when the walk,
reaching this attempt, answers from it, and the value is then the receipt's subject, property and
stored value. @{text attempt_decline} holds for the pair an attempt marks as the decline: a dropped
phrasing whose first selected candidate is in domain, or an answering-shaped attempt whose in-domain
candidates cannot name one agreed stored value. An attempt is @{text transparent} when the walk
crosses it without marking anything and without ending.\<close>

definition attempt_values :: "question_features \<Rightarrow> attempt \<Rightarrow> (natural \<times> natural \<times> rel_value) option" where
  "attempt_values f a = (case step f a of Halt (Answer x) \<Rightarrow> Some x | _ \<Rightarrow> None)"

definition attempt_decline :: "question_features \<Rightarrow> attempt \<Rightarrow> (natural \<times> natural) \<Rightarrow> bool" where
  "attempt_decline f a d \<longleftrightarrow> step f a = Cont (Some d)"

definition transparent :: "question_features \<Rightarrow> attempt \<Rightarrow> bool" where
  "transparent f a \<longleftrightarrow> step f a = Cont None"

lemma attempt_values_iff: "attempt_values f a = Some x \<longleftrightarrow> step f a = Halt (Answer x)"
proof (cases "step f a")
  case (Cont m)
  then show ?thesis by (simp add: attempt_values_def)
next
  case (Halt r)
  then show ?thesis by (cases r) (simp_all add: attempt_values_def)
qed

lemma attempt_values_None: "step f a = Cont m \<Longrightarrow> attempt_values f a = None"
  by (simp add: attempt_values_def)

lemma step_not_decline: "step f a \<noteq> Halt (Decline d)"
  by (simp add: step_def split: if_splits)

section \<open>What the walk's end result means\<close>

lemma walk_answer_exists:
  "\<forall>acc. walk f attempts acc = Answer x \<longrightarrow> (\<exists>a \<in> set attempts. attempt_values f a = Some x)"
proof (induct attempts)
  case Nil
  show ?case by (auto split: option.splits)
next
  case (Cons a attempts)
  show ?case
  proof (intro allI impI)
    fix acc
    assume ans: "walk f (a # attempts) acc = Answer x"
    show "\<exists>b \<in> set (a # attempts). attempt_values f b = Some x"
    proof (cases "step f a")
      case (Halt r)
      with ans have "r = Answer x" by simp
      with Halt have "attempt_values f a = Some x" by (simp add: attempt_values_iff)
      then show ?thesis by auto
    next
      case (Cont m)
      with ans have "walk f attempts (case acc of None \<Rightarrow> m | Some d \<Rightarrow> Some d) = Answer x" by simp
      with Cons obtain b where "b \<in> set attempts" "attempt_values f b = Some x" by blast
      then show ?thesis by auto
    qed
  qed
qed

lemma no_answer_when_none:
  assumes none: "\<forall>a \<in> set attempts. attempt_values f a = None"
  shows "walk f attempts acc \<noteq> Answer x"
proof
  assume eq: "walk f attempts acc = Answer x"
  then have "\<exists>a \<in> set attempts. attempt_values f a = Some x"
    using walk_answer_exists[rule_format] by meson
  with none show False by auto
qed

text \<open>The invariant behind a decline: no attempt along the way could answer, and the declined pair
either came in with the accumulator (the decision itself never starts one) or was marked by a real
attempt of the question.\<close>

lemma walk_decline_inv:
  assumes dw: "walk f attempts acc = Decline d"
  shows "\<forall>b \<in> set attempts. attempt_values f b = None"
    and "(acc = Some d) \<or> (\<exists>b \<in> set attempts. attempt_decline f b d)"
proof -
  have both: "(\<forall>b \<in> set attempts. attempt_values f b = None) \<and>
      ((acc = Some d) \<or> (\<exists>b \<in> set attempts. attempt_decline f b d))"
    using dw
  proof (induct attempts arbitrary: acc)
    case Nil
    then show ?case by (cases acc) auto
  next
    case (Cons a rest)
    show ?case
    proof (cases "step f a")
      case (Halt r)
      with Cons.prems have "r = Decline d" by simp
      with Halt step_not_decline show ?thesis by metis
    next
      case (Cont m)
      with Cons.prems have w: "walk f rest (case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Decline d" by simp
      from Cons.hyps[OF w] have ih1: "\<forall>b \<in> set rest. attempt_values f b = None"
        and ih2: "(case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Some d \<or>
                  (\<exists>b \<in> set rest. attempt_decline f b d)" by auto
      have va: "attempt_values f a = None" by (rule attempt_values_None[OF Cont])
      show ?thesis
      proof (cases acc)
        case None
        with ih2 have "m = Some d \<or> (\<exists>b \<in> set rest. attempt_decline f b d)" by simp
        then show ?thesis using ih1 va Cont by (auto simp: attempt_decline_def)
      next
        case (Some e)
        with ih2 have "e = d \<or> (\<exists>b \<in> set rest. attempt_decline f b d)" by simp
        then show ?thesis using ih1 va Some by auto
      qed
    qed
  qed
  from both show "\<forall>b \<in> set attempts. attempt_values f b = None"
    and "(acc = Some d) \<or> (\<exists>b \<in> set attempts. attempt_decline f b d)" by blast+
qed

lemma decline_meaning:
  assumes "decide_spec f attempts = Decline d"
  shows "(\<forall>a \<in> set attempts. attempt_values f a = None)" and "(\<exists>a \<in> set attempts. attempt_decline f a d)"
proof -
  from assms have w: "walk f attempts None = Decline d"
    by (cases "kind_conflict f") (simp_all add: decide_spec_def)
  from walk_decline_inv(1)[OF w] show "(\<forall>a \<in> set attempts. attempt_values f a = None)" .
  from walk_decline_inv(2)[OF w] show "(\<exists>a \<in> set attempts. attempt_decline f a d)" by simp
qed

lemma step_incomplete:
  assumes "step f a = Halt Incomplete"
  shows "in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
    \<not> dropped (key a) (idx a) \<and> (\<exists>c \<in> set (selof a). \<not> complete c)"
  using assms by (auto simp: step_def live_def allc_def split: if_splits)

lemma walk_incomplete_inv:
  assumes iw: "walk f attempts acc = Incomplete"
  shows "\<exists>a \<in> set attempts. step f a = Halt Incomplete"
  using iw
proof (induct attempts arbitrary: acc)
  case Nil
  then show ?case by (cases acc) simp_all
next
  case (Cons a rest)
  show ?case
  proof (cases "step f a")
    case (Halt r)
    with Cons.prems have "r = Incomplete" by simp
    with Halt show ?thesis by auto
  next
    case (Cont m)
    with Cons.prems have "walk f rest (case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Incomplete" by simp
    from Cons.hyps[OF this] show ?thesis by auto
  qed
qed

lemma incomplete_meaning:
  assumes "decide_spec f attempts = Incomplete"
  shows "\<exists>a \<in> set attempts. in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
    \<not> dropped (key a) (idx a) \<and> (\<exists>c \<in> set (selof a). \<not> complete c)"
proof -
  from assms have "walk f attempts None = Incomplete"
    by (cases "kind_conflict f") (simp_all add: decide_spec_def)
  from walk_incomplete_inv[OF this] show ?thesis using step_incomplete by blast
qed

lemma agreed_ne: "agreed a \<Longrightarrow> mineof a \<noteq> []"
  by (simp add: agreed_def)

lemma step_silent:
  assumes "step f a = Halt Silent"
  shows "in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
       \<not> dropped (key a) (idx a) \<and> (\<forall>c \<in> set (selof a). complete c) \<and>
       mineof a \<noteq> [] \<and>
       (restates f (hd (hd (vsof a))) \<or> prop_of (key a) \<in> set time_variant \<and> past f)"
proof -
  have g: "live a \<and> \<not> dropped (key a) (idx a) \<and> allc a \<and> agreed a \<and>
      (restates f (hd (hd (vsof a))) \<or> prop_of (key a) \<in> set time_variant \<and> past f)"
    using assms by (simp add: step_def split: if_splits)
  then show ?thesis using agreed_ne by (auto simp: live_def allc_def)
qed

lemma walk_silent_inv:
  assumes sw: "walk f attempts acc = Silent"
  shows "(acc = None \<and> (\<forall>a \<in> set attempts. transparent f a)) \<or>
    (\<exists>a \<in> set attempts. step f a = Halt Silent)"
  using sw
proof (induct attempts arbitrary: acc)
  case Nil
  then show ?case by (cases acc) auto
next
  case (Cons a rest)
  show ?case
  proof (cases "step f a")
    case (Halt r)
    with Cons.prems have "r = Silent" by simp
    with Halt show ?thesis by auto
  next
    case (Cont m)
    with Cons.prems have w: "walk f rest (case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Silent" by simp
    from Cons.hyps[OF w] show ?thesis
    proof
      assume h: "(case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = None \<and>
                 (\<forall>b \<in> set rest. transparent f b)"
      then have "acc = None" and "m = None" by (cases acc, auto)+
      with h Cont show ?thesis by (auto simp: transparent_def)
    next
      assume "\<exists>b \<in> set rest. step f b = Halt Silent"
      then show ?thesis by auto
    qed
  qed
qed

lemma silent_meaning:
  assumes "decide_spec f attempts = Silent"
  shows "kind_conflict f \<or> attempts = [] \<or>
    (\<exists>a \<in> set attempts. in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
       \<not> dropped (key a) (idx a) \<and> (\<forall>c \<in> set (selof a). complete c) \<and>
       mineof a \<noteq> [] \<and>
       (restates f (hd (hd (vsof a))) \<or>
        prop_of (key a) \<in> set time_variant \<and> past f)) \<or>
    (\<forall>a \<in> set attempts. transparent f a)"
proof (cases "kind_conflict f")
  case True
  then show ?thesis by simp
next
  case False
  then have "walk f attempts None = Silent" using assms by (simp add: decide_spec_def)
  from walk_silent_inv[OF this] show ?thesis using step_silent by blast
qed

lemma agreed_unfold:
  assumes ag: "agreed a"
  shows "mineof a \<noteq> []"
    and "\<forall>c \<in> set (mineof a). set (vals (prop_of (key a)) c) = set (vals (prop_of (key a)) (hd (mineof a)))"
    and "length (vals (prop_of (key a)) (hd (mineof a))) = 1"
    and "hd (vsof a) = vals (prop_of (key a)) (hd (mineof a))"
proof -
  note g = ag[unfolded agreed_def]
  have ne: "mineof a \<noteq> []" using g by blast
  then show "mineof a \<noteq> []" .
  have hd: "hd (vsof a) = vals (prop_of (key a)) (hd (mineof a))" by (rule hd_map[OF ne])
  then show "hd (vsof a) = vals (prop_of (key a)) (hd (mineof a))" .
  show "length (vals (prop_of (key a)) (hd (mineof a))) = 1" using g hd by metis
  show "\<forall>c \<in> set (mineof a). set (vals (prop_of (key a)) c) = set (vals (prop_of (key a)) (hd (mineof a)))"
  proof
    fix c assume c: "c \<in> set (mineof a)"
    have "vals (prop_of (key a)) c \<in> set (vsof a)" unfolding set_map by (rule imageI[OF c])
    with g hd show "set (vals (prop_of (key a)) c) = set (vals (prop_of (key a)) (hd (mineof a)))" by metis
  qed
qed

lemma attempt_values_sound:
  assumes av: "attempt_values f a = Some (s, p, v)"
  shows "in_table (key a) (idx a)" "slot_ok a" "candidates a \<noteq> []" "\<not> dropped (key a) (idx a)"
    "p = prop_of (key a)"
    "mineof a \<noteq> []"
    "s = qid (hd (mineof a))"
    "domain_member (hd (mineof a))"
    "(\<forall>c \<in> set (selof a). complete c)"
    "(\<forall>c \<in> set (mineof a). set (vals p c) = {v})"
    "(p, v) \<in> set (rows (hd (mineof a)))"
    "v \<noteq> Blank"
    "\<not> restates f v"
    "p \<notin> set time_variant \<or> \<not> past f"
proof -
  from av have st: "step f a = Halt (Answer (s, p, v))" by (simp add: attempt_values_iff)
  have g: "live a \<and> \<not> dropped (key a) (idx a) \<and> allc a \<and> agreed a \<and> \<not> restates f (hd (hd (vsof a))) \<and>
      \<not> (prop_of (key a) \<in> set time_variant \<and> past f) \<and>
      s = qid (hd (mineof a)) \<and> p = prop_of (key a) \<and> v = hd (hd (vsof a))"
    using st by (simp add: step_def split: if_splits) metis
  then have live: "live a" and nd: "\<not> dropped (key a) (idx a)" and ac: "allc a" and ag: "agreed a"
    and nr: "\<not> restates f (hd (hd (vsof a)))" and ntv: "\<not> (prop_of (key a) \<in> set time_variant \<and> past f)"
    and sv: "s = qid (hd (mineof a))" and pv: "p = prop_of (key a)" and vv: "v = hd (hd (vsof a))"
    by blast+
  from live show "in_table (key a) (idx a)" "slot_ok a" "candidates a \<noteq> []" by (simp_all add: live_def)
  from nd show "\<not> dropped (key a) (idx a)" .
  from pv show "p = prop_of (key a)" .
  have mine: "mineof a \<noteq> []" by (rule agreed_unfold(1)[OF ag])
  then show "mineof a \<noteq> []" .
  from sv show "s = qid (hd (mineof a))" .
  have hin: "hd (mineof a) \<in> set (mineof a)" by (rule hd_in_set[OF mine])
  then show dom: "domain_member (hd (mineof a))" by (simp add: set_filter)
  from ac show "(\<forall>c \<in> set (selof a). complete c)" by (simp add: allc_def)
  note same = agreed_unfold(2)[OF ag] and len = agreed_unfold(3)[OF ag] and hdv = agreed_unfold(4)[OF ag]
  from len obtain w where w: "vals (prop_of (key a)) (hd (mineof a)) = [w]" by (cases "vals (prop_of (key a)) (hd (mineof a))") auto
  from vv hdv w have vw: "v = w" by simp
  show "\<forall>c \<in> set (mineof a). set (vals p c) = {v}" using same w vw pv by simp
  then have "set (vals p (hd (mineof a))) = {v}" using hin by blast
  then have in_rows: "v \<in> set (vals p (hd (mineof a)))" by simp
  from in_rows show "(p, v) \<in> set (rows (hd (mineof a)))" by (simp add: set_vals)
  from in_rows show "v \<noteq> Blank" by (simp add: set_vals)
  from nr vv hdv w show "\<not> restates f v" by simp
  from ntv pv show "p \<notin> set time_variant \<or> \<not> past f" by blast
qed

section \<open>The receipts\<close>

text \<open>An answer names one of the five properties, a candidate the linker proposed and the fetch
vouched for, whose stored rows hold that very value; every in-domain candidate of the selection agrees
on exactly that value, and the value does not restate the question. This is the specialist's whole
truth claim: what an answer says about the fetched evidence.\<close>

theorem answer_stored:
  assumes ans: "decide_spec f attempts = Answer (s, p, v)"
  shows "p \<in> {50, 577, 840, 156, 144}"
    and "\<exists>a c. a \<in> set attempts \<and> attempt_values f a = Some (s, p, v) \<and>
          c \<in> set (mineof a) \<and> qid c = s \<and> dom_complete c \<and>
          (\<forall>c' \<in> set (selof a). complete c') \<and>
          (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and> \<not> restates f v \<and>
          (\<forall>c' \<in> set (mineof a). set (vals p c') = {v})"
proof -
  from ans have "walk f attempts None = Answer (s, p, v)"
    by (cases "kind_conflict f") (simp_all add: decide_spec_def)
  then obtain a where a: "a \<in> set attempts" and av: "attempt_values f a = Some (s, p, v)"
    using walk_answer_exists[rule_format] by meson
  from table_props[OF attempt_values_sound(1)[OF av]] attempt_values_sound(5)[OF av]
  show "p \<in> {50, 577, 840, 156, 144}" by simp
  let ?c = "hd (mineof a)"
  have mine_ne: "mineof a \<noteq> []" by (rule attempt_values_sound(6)[OF av])
  have cin: "?c \<in> set (mineof a)" using mine_ne by (cases "mineof a") auto
  have cdom: "domain_member ?c" using cin by (auto simp: set_filter)
  note receipts = attempt_values_sound(7,8,9,10,11,12,13)[OF av]
  from a av cin receipts cdom show "\<exists>a c. a \<in> set attempts \<and> attempt_values f a = Some (s, p, v) \<and>
          c \<in> set (mineof a) \<and> qid c = s \<and> dom_complete c \<and>
          (\<forall>c' \<in> set (selof a). complete c') \<and>
          (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and> \<not> restates f v \<and>
          (\<forall>c' \<in> set (mineof a). set (vals p c') = {v})"
    by (intro exI[where x = a] exI[where x = ?c]) (auto simp: domain_member_roots)
qed

text \<open>A decline names one of the five properties and a linked candidate that is in the domain:
recognise-then-decline, never a refusal about something the specialist did not read.\<close>

theorem decline_stored:
  assumes dec: "decide_spec f attempts = Decline (p, s)"
  shows "p \<in> {50, 577, 840, 156, 144}"
    and "\<exists>a c. a \<in> set attempts \<and> in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
          c \<in> set (selof a) \<and> qid c = s \<and> domain_member c"
proof -
  from decline_meaning(2)[OF dec] obtain a where a: "a \<in> set attempts" and ad: "attempt_decline f a (p, s)"
    by blast
  have g: "live a \<and>
      (dropped (key a) (idx a) \<longrightarrow> p = prop_of (key a) \<and> s = qid (hd (selof a)) \<and> domain_member (hd (selof a))) \<and>
      (\<not> dropped (key a) (idx a) \<longrightarrow> mineof a \<noteq> [] \<and> p = prop_of (key a) \<and> s = qid (hd (mineof a)))"
    using ad by (auto simp: attempt_decline_def step_def split: if_splits)
  then have guards: "in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> []"
    by (simp add: live_def)
  have pk: "p = prop_of (key a)" using g by (cases "dropped (key a) (idx a)") auto
  from guards have tp: "prop_of (key a) = key a \<and> key a \<in> {50, 577, 840, 156, 144}"
    using table_props by blast
  with pk show "p \<in> {50, 577, 840, 156, 144}" by simp
  show "\<exists>a c. a \<in> set attempts \<and> in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
          c \<in> set (selof a) \<and> qid c = s \<and> domain_member c"
  proof (cases "dropped (key a) (idx a)")
    case True
    with g have dm: "domain_member (hd (selof a))" and qs: "qid (hd (selof a)) = s" by auto
    have hin: "hd (selof a) \<in> set (selof a)"
      by (rule hd_in_set[OF select_nonempty]) (use guards in simp)
    show ?thesis
      by (intro exI[where x = a] exI[where x = "hd (selof a)"]) (use a guards hin dm qs in auto)
  next
    case False
    with g have mine_ne: "mineof a \<noteq> []" and qs: "qid (hd (mineof a)) = s" by auto
    have hm: "hd (mineof a) \<in> set (mineof a)" by (rule hd_in_set[OF mine_ne])
    then have dm: "domain_member (hd (mineof a))" by (simp add: set_filter)
    from hm have hin: "hd (mineof a) \<in> set (selof a)" by (auto simp: set_filter dest: in_set_takeD)
    show ?thesis
      by (intro exI[where x = a] exI[where x = "hd (mineof a)"]) (use a guards hin dm qs in auto)
  qed
qed

end
