theory Novel_Reader
  imports Main
begin

text \<open>Oracle7's relation specialist @{emph \<open>rel-novels\<close>} (upstream/root/specialists/rel-novels,
class RelationOrganV2) as a decision over fetched evidence. The specialist reads five hand-written
readers (author P50, publication date P577, narrative location P840, followed by P156, based on P144,
all forward) over the Wikidata relation store, answers only when the linked in-domain candidates agree
on one stored value, and otherwise declines in domain (recognise-then-decline) or stays silent. This
is the shipped organ's primary path, @{term relation_spec_v2.answer}; its fallback reader
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
  by (auto simp: in_table_def readers_entries)

lemma dropped_iff: "dropped k i \<longleftrightarrow> k = 50 \<and> i = 2"
  by (auto simp: dropped_def readers_entries)

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
  by (simp add: time_variant_def)

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

lemma select_cases:
  "select cs = take 3 cs \<or> (select cs = take 1 cs \<and> dominated cs)"
  by (simp add: select_def)

lemma select_subset: "set (select cs) \<subseteq> set cs"
  by (auto simp: select_def dest: in_set_takeD)

lemma select_nonempty: "cs \<noteq> [] \<Longrightarrow> select cs \<noteq> []"
  by (cases cs) (simp add: select_def)

lemma select_head: "cs \<noteq> [] \<Longrightarrow> hd (select cs) = hd cs"
  by (cases cs) (simp add: select_def)

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

fun walk :: "question_features \<Rightarrow> attempt list \<Rightarrow> (natural \<times> natural) option \<Rightarrow> outcome" where
  "walk f [] acc = (case acc of None \<Rightarrow> Silent | Some d \<Rightarrow> Decline d)"
| "walk f (a # rest) acc =
    (if \<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = [] then walk f rest acc
     else
       let cs = select (candidates a); p = prop_of (key a) in
       if dropped (key a) (idx a) then
         (case acc of
            None \<Rightarrow> if domain_member (hd cs) then walk f rest (Some (p, qid (hd cs))) else walk f rest None
          | Some d \<Rightarrow> walk f rest (Some d))
       else if \<not> (\<forall>c \<in> set cs. complete c) then Incomplete
       else
         let mine = filter domain_member (take 3 cs); vs = map (vals p) mine in
         if mine = [] \<or> (\<exists>v \<in> set vs. v = []) \<or> (\<exists>v \<in> set vs. set v \<noteq> set (hd vs)) \<or> length (hd vs) \<noteq> 1
         then (case acc of
                 None \<Rightarrow> if mine = [] then walk f rest None else walk f rest (Some (p, qid (hd mine)))
               | Some d \<Rightarrow> walk f rest (Some d))
         else if restates f (hd (hd vs)) then Silent
         else if p \<in> set time_variant \<and> past f then Silent
         else Answer (qid (hd mine), p, hd (hd vs)))"

definition decide_spec :: "question_features \<Rightarrow> attempt list \<Rightarrow> outcome" where
  "decide_spec f attempts = (if kind_conflict f then Silent else walk f attempts None)"

section \<open>What one attempt would answer, and what it marks as a decline\<close>

text \<open>@{text attempt_values} is one attempt's answer computed without the walk: it is @{term Some}
exactly when the walk, reaching this attempt, answers from it — and the value is then the receipt's
subject, property and stored value. @{text attempt_decline} holds for the pair an attempt marks as
the decline: a dropped phrasing whose first selected candidate is in domain, or an answering-shaped
attempt whose in-domain candidates cannot name one agreed stored value. An attempt is @{text
transparent} when the walk crosses it without marking anything and without ending: an unmatched
phrasing, a dropped phrasing out of domain, or an answering-shaped attempt with no in-domain
candidate at all.\<close>

definition attempt_values :: "question_features \<Rightarrow> attempt \<Rightarrow> (natural \<times> natural \<times> rel_value) option" where
  "attempt_values f a =
    (if \<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = [] then None
     else let cs = select (candidates a); p = prop_of (key a) in
       if dropped (key a) (idx a) then None
       else if \<not> (\<forall>c \<in> set cs. complete c) then None
       else let mine = filter domain_member (take 3 cs); vs = map (vals p) mine in
         if mine = [] \<or> (\<exists>v \<in> set vs. v = []) \<or> (\<exists>v \<in> set vs. set v \<noteq> set (hd vs)) \<or> length (hd vs) \<noteq> 1
         then None
         else if restates f (hd (hd vs)) then None
         else if p \<in> set time_variant \<and> past f then None
         else Some (qid (hd mine), p, hd (hd vs)))"

definition attempt_decline :: "question_features \<Rightarrow> attempt \<Rightarrow> (natural \<times> natural) \<Rightarrow> bool" where
  "attempt_decline f a d \<longleftrightarrow>
     in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
     (if dropped (key a) (idx a) then
        d = (prop_of (key a), qid (hd (select (candidates a)))) \<and>
        domain_member (hd (select (candidates a)))
      else filter domain_member (take 3 (select (candidates a))) \<noteq> [] \<and>
        (\<forall>c \<in> set (select (candidates a)). complete c) \<and>
        d = (prop_of (key a), qid (hd (filter domain_member (take 3 (select (candidates a)))))))"

definition transparent :: "question_features \<Rightarrow> attempt \<Rightarrow> bool" where
  "transparent f a \<longleftrightarrow>
     (\<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = []) \<or>
     (in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and> dropped (key a) (idx a) \<and>
        \<not> domain_member (hd (select (candidates a)))) \<or>
     (in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and> \<not> dropped (key a) (idx a) \<and>
        (\<forall>c \<in> set (select (candidates a)). complete c) \<and>
        filter domain_member (take 3 (select (candidates a))) = [])"

text \<open>The walk's step on one attempt, seen through @{text attempt_values}: an attempt whose answer
exists ends the walk with that answer; otherwise the walk does to the accumulator exactly what the
tree below says.\<close>

lemma walk_cons_eq:
  "walk f (a # rest) acc =
    (case attempt_values f a of
       Some x \<Rightarrow> Answer x
     | None \<Rightarrow>
         (if \<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = [] then walk f rest acc
          else let cs = select (candidates a); p = prop_of (key a) in
               if dropped (key a) (idx a) then
                 (case acc of
                    None \<Rightarrow> if domain_member (hd cs) then walk f rest (Some (p, qid (hd cs))) else walk f rest None
                  | Some d \<Rightarrow> walk f rest (Some d))
               else if \<not> (\<forall>c \<in> set cs. complete c) then Incomplete
               else let mine = filter domain_member (take 3 cs); vs = map (vals p) mine in
                    if mine = [] \<or> (\<exists>v \<in> set vs. v = []) \<or> (\<exists>v \<in> set vs. set v \<noteq> set (hd vs)) \<or> length (hd vs) \<noteq> 1
                    then (case acc of
                            None \<Rightarrow> if mine = [] then walk f rest None else walk f rest (Some (p, qid (hd mine)))
                          | Some d \<Rightarrow> walk f rest (Some d))
                    else if restates f (hd (hd vs)) then Silent
                    else if p \<in> set time_variant \<and> past f then Silent
                    else Answer (qid (hd mine), p, hd (hd vs))))"
  by (simp add: attempt_values_def split: if_splits)

lemma walk_answer_exists:
  "\<forall>acc. walk f attempts acc = Answer x \<longrightarrow> (\<exists>a \<in> set attempts. attempt_values f a = Some x)"
proof (induct attempts)
  case Nil
  show ?case by simp
next
  case (Cons a attempts)
  show ?case
  proof (intro allI impI)
    fix acc
    assume ans: "walk f (a # attempts) acc = Answer x"
    have "attempt_values f a = Some x \<or> (\<exists>acc'. walk f attempts acc' = Answer x)"
      using ans by (subst walk_cons_eq) (auto split: option.splits if_splits simp: attempt_values_def)
    then show "\<exists>b \<in> set (a # attempts). attempt_values f b = Some x"
      by (meson Cons in_set_consI)
  qed
qed

lemma no_answer_when_none:
  assumes none: "\<forall>a \<in> set attempts. attempt_values f a = None"
  shows "walk f attempts acc \<noteq> Answer x"
proof
  assume eq: "walk f attempts acc = Answer x"
  then obtain a where "a \<in> set attempts" and "attempt_values f a = Some x"
    using walk_answer_exists[rule_format, of attempts f x acc] by auto
  with none show False by auto
qed

lemma walk_acc_decline:
  assumes "walk f attempts (Some d) = Decline d'"
  shows "d' = d"
  using assms by (induct attempts arbitrary: d) (auto split: option.splits if_splits)

text \<open>The invariant behind a decline: no attempt along the way could answer, and the declined pair
either came in with the accumulator (the decision itself never starts one) or was marked by a real
attempt of the question.\<close>

lemma walk_decline_inv:
  assumes dw: "walk f attempts acc = Decline d"
  shows "\<forall>b \<in> set attempts. attempt_values f b = None"
    and "(acc = Some d) \<or> (\<exists>b \<in> set attempts. attempt_decline f b d)"
using dw
proof (induct attempts arbitrary: acc d)
  case Nil
  show "\<forall>b \<in> set []. attempt_values f b = None" by simp
  show "(acc = Some d) \<or> (\<exists>b \<in> set []. attempt_decline f b d)"
    using Nil by (auto split: option.splits)
next
  case (Cons a rest)
  have av: "attempt_values f a = None"
  proof (rule ccontr)
    assume "attempt_values f a \<noteq> None"
    then obtain x where "attempt_values f a = Some x" by blast
    then have "walk f (a # rest) acc = Answer x" by (simp add: walk_cons_eq)
    with Cons(2) show False by simp
  qed
  from Cons(2) have tree:
    "(if \<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = [] then walk f rest acc
      else let cs = select (candidates a); p = prop_of (key a) in
      if dropped (key a) (idx a) then
        (case acc of
           None \<Rightarrow> if domain_member (hd cs) then walk f rest (Some (p, qid (hd cs))) else walk f rest None
         | Some d \<Rightarrow> walk f rest (Some d))
      else if \<not> (\<forall>c \<in> set cs. complete c) then Incomplete
      else let mine = filter domain_member (take 3 cs); vs = map (vals p) mine in
        if mine = [] \<or> (\<exists>v \<in> set vs. v = []) \<or> (\<exists>v \<in> set vs. set v \<noteq> set (hd vs)) \<or> length (hd vs) \<noteq> 1
        then (case acc of
                None \<Rightarrow> if mine = [] then walk f rest None else walk f rest (Some (p, qid (hd mine)))
              | Some d \<Rightarrow> walk f rest (Some d))
        else if restates f (hd (hd vs)) then Silent
        else if p \<in> set time_variant \<and> past f then Silent
        else Answer (qid (hd mine), p, hd (hd vs))) = Decline d"
    by (simp add: walk_cons_eq av)
  show "\<forall>b \<in> set (a # rest). attempt_values f b = None"
    using tree by (auto split: if_splits option.splits simp: attempt_values_def
                         dest: Cons(1)[THEN conjunct1, rule_format])
  show "(acc = Some d) \<or> (\<exists>b \<in> set (a # rest). attempt_decline f b d)"
    using tree
    by (auto split: if_splits option.splits simp: attempt_values_def attempt_decline_def
             dest: walk_acc_decline Cons(1)[THEN conjunct2, rule_format])
qed

lemma decline_meaning:
  assumes "decide_spec f attempts = Decline d"
  shows "(\<forall>a \<in> set attempts. attempt_values f a = None)" and "(\<exists>a \<in> set attempts. attempt_decline f a d)"
proof -
  from assms have "walk f attempts None = Decline d" by (simp add: decide_spec_def)
  from walk_decline_inv[OF this] show "(\<forall>a \<in> set attempts. attempt_values f a = None)" ..
  from walk_decline_inv[OF this] show "(\<exists>a \<in> set attempts. attempt_decline f a d)" by auto
qed

lemma walk_incomplete_inv:
  assumes iw: "walk f attempts acc = Incomplete"
  shows "\<exists>a \<in> set attempts. in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
    \<not> dropped (key a) (idx a) \<and> (\<exists>c \<in> set (select (candidates a)). \<not> complete c)"
using iw
proof (induct attempts arbitrary: acc)
  case Nil
  then show ?case by simp
next
  case (Cons a rest)
  have av: "attempt_values f a = None"
  proof (rule ccontr)
    assume "attempt_values f a \<noteq> None"
    then obtain x where "attempt_values f a = Some x" by blast
    then have "walk f (a # rest) acc = Answer x" by (simp add: walk_cons_eq)
    with Cons(2) show False by simp
  qed
  from Cons(2) have tree:
    "(if \<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = [] then walk f rest acc
      else let cs = select (candidates a); p = prop_of (key a) in
      if dropped (key a) (idx a) then
        (case acc of
           None \<Rightarrow> if domain_member (hd cs) then walk f rest (Some (p, qid (hd cs))) else walk f rest None
         | Some d \<Rightarrow> walk f rest (Some d))
      else if \<not> (\<forall>c \<in> set cs. complete c) then Incomplete
      else let mine = filter domain_member (take 3 cs); vs = map (vals p) mine in
        if mine = [] \<or> (\<exists>v \<in> set vs. v = []) \<or> (\<exists>v \<in> set vs. set v \<noteq> set (hd vs)) \<or> length (hd vs) \<noteq> 1
        then (case acc of
                None \<Rightarrow> if mine = [] then walk f rest None else walk f rest (Some (p, qid (hd mine)))
              | Some d \<Rightarrow> walk f rest (Some d))
        else if restates f (hd (hd vs)) then Silent
        else if p \<in> set time_variant \<and> past f then Silent
        else Answer (qid (hd mine), p, hd (hd vs))) = Incomplete"
    by (simp add: walk_cons_eq av)
  show ?case
    using tree by (auto split: if_splits option.splits simp: attempt_values_def
                        dest: Cons(1))
qed

lemma incomplete_meaning:
  assumes "decide_spec f attempts = Incomplete"
  shows "\<exists>a \<in> set attempts. in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
    \<not> dropped (key a) (idx a) \<and> (\<exists>c \<in> set (select (candidates a)). \<not> complete c)"
proof -
  from assms have "\<not> kind_conflict f" and "walk f attempts None = Incomplete"
    by (auto simp: decide_spec_def)
  from walk_incomplete_inv[OF this(2)] show ?thesis .
qed

lemma walk_silent_inv:
  assumes sw: "walk f attempts acc = Silent"
  shows "(acc = None \<and> (\<forall>a \<in> set attempts. transparent f a)) \<or>
    (\<exists>a \<in> set attempts. in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
       \<not> dropped (key a) (idx a) \<and> (\<forall>c \<in> set (select (candidates a)). complete c) \<and>
       filter domain_member (take 3 (select (candidates a))) \<noteq> [] \<and>
       (restates f (hd (hd (map (vals (prop_of (key a))) (filter domain_member (take 3 (select (candidates a))))))) \<or>
        prop_of (key a) \<in> set time_variant \<and> past f))"
using sw
proof (induct attempts arbitrary: acc)
  case Nil
  then show ?case by (auto split: option.splits)
next
  case (Cons a rest)
  have av: "attempt_values f a = None"
  proof (rule ccontr)
    assume "attempt_values f a \<noteq> None"
    then obtain x where "attempt_values f a = Some x" by blast
    then have "walk f (a # rest) acc = Answer x" by (simp add: walk_cons_eq)
    with Cons(2) show False by simp
  qed
  from Cons(2) have tree:
    "(if \<not> in_table (key a) (idx a) \<or> \<not> slot_ok a \<or> candidates a = [] then walk f rest acc
      else let cs = select (candidates a); p = prop_of (key a) in
      if dropped (key a) (idx a) then
        (case acc of
           None \<Rightarrow> if domain_member (hd cs) then walk f rest (Some (p, qid (hd cs))) else walk f rest None
         | Some d \<Rightarrow> walk f rest (Some d))
      else if \<not> (\<forall>c \<in> set cs. complete c) then Incomplete
      else let mine = filter domain_member (take 3 cs) in
        if mine = [] \<or> \<exists>v \<in> set (map (vals p) mine). v = [] \<or>
           (\<exists>v \<in> set (map (vals p) mine). set v \<noteq> set (hd (map (vals p) mine))) \<or> length (hd (map (vals p) mine)) \<noteq> 1
        then (case acc of
                None \<Rightarrow> if mine = [] then walk f rest None else walk f rest (Some (p, qid (hd mine)))
              | Some d \<Rightarrow> walk f rest (Some d))
        else if restates f (hd (hd (map (vals p) mine)) ) then Silent
        else if p \<in> set time_variant \<and> past f then Silent
        else Answer (qid (hd mine), p, hd (hd (map (vals p) mine)))) = Silent"
    by (simp add: walk_cons_eq av)
  show ?case
    using tree by (auto split: if_splits option.splits simp: attempt_values_def transparent_def
                        dest: Cons(1))
qed

lemma silent_meaning:
  assumes "decide_spec f attempts = Silent"
  shows "kind_conflict f \<or> attempts = [] \<or>
    (\<exists>a \<in> set attempts. in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
       \<not> dropped (key a) (idx a) \<and> (\<forall>c \<in> set (select (candidates a)). complete c) \<and>
       filter domain_member (take 3 (select (candidates a))) \<noteq> [] \<and>
       (restates f (hd (hd (map (vals (prop_of (key a))) (filter domain_member (take 3 (select (candidates a))))))) \<or>
        prop_of (key a) \<in> set time_variant \<and> past f)) \<or>
    (\<forall>a \<in> set attempts. transparent f a)"
proof (cases "kind_conflict f")
  case True
  then show ?thesis by simp
next
  case False
  then have "walk f attempts None = Silent" using assms by (simp add: decide_spec_def)
  from walk_silent_inv[OF this] show ?thesis by auto
qed

lemma attempt_values_sound:
  assumes "attempt_values f a = Some (s, p, v)"
  shows "in_table (key a) (idx a)" "slot_ok a" "candidates a \<noteq> []" "\<not> dropped (key a) (idx a)"
    "p = prop_of (key a)"
    "filter domain_member (take 3 (select (candidates a))) \<noteq> []"
    "s = qid (hd (filter domain_member (take 3 (select (candidates a)))))"
    "domain_member (hd (filter domain_member (take 3 (select (candidates a)))))"
    "(\<forall>c \<in> set (select (candidates a)). complete c)"
    "(\<forall>c \<in> set (filter domain_member (take 3 (select (candidates a)))). set (vals p c) = {v})"
    "(p, v) \<in> set (rows (hd (filter domain_member (take 3 (select (candidates a))))))"
    "v \<noteq> Blank"
    "\<not> restates f v"
    "p \<notin> set time_variant \<or> \<not> past f"
proof -
  let ?mine = "filter domain_member (take 3 (select (candidates a)))"
  note unf = assms[unfolded attempt_values_def, simplified]
  from unf show "in_table (key a) (idx a)" "slot_ok a" "candidates a \<noteq> []" "\<not> dropped (key a) (idx a)"
    by (auto split: if_splits)
  from unf show "p = prop_of (key a)" by (auto split: if_splits)
  from unf have mine: "?mine \<noteq> []"
    by (auto split: if_splits)
  then show mine': "?mine \<noteq> []" by (rule mine)
  then show dom: "domain_member (hd ?mine)" by (induct ?mine) auto
  from unf mine show s: "s = qid (hd ?mine)" by (auto split: if_splits)
  from unf show "(\<forall>c \<in> set (select (candidates a)). complete c)" by (auto split: if_splits)
  from unf mine have agree: "\<not> ((\<exists>w \<in> set (map (vals p) ?mine). w = []) \<or>
      (\<exists>w \<in> set (map (vals p) ?mine). set w \<noteq> set (hd (map (vals p) ?mine))) \<or>
      length (hd (map (vals p) ?mine)) \<noteq> 1)"
    and no_restates: "\<not> restates f v" and no_past: "p \<notin> set time_variant \<or> \<not> past f"
    and val: "v = hd (hd (map (vals p) ?mine))"
    by (auto split: if_splits)
  have hdmap: "hd (map (vals p) ?mine) = vals p (hd ?mine)" using mine by simp
  from agree have "\<forall>w \<in> set (map (vals p) ?mine). set w = set (vals p (hd ?mine))"
    using hdmap by auto
  then have sets: "\<forall>c \<in> set ?mine. set (vals p c) = set (vals p (hd ?mine))"
    by (induct ?mine) (auto simp: dom)
  from agree hdmap have len: "length (vals p (hd ?mine)) = 1" by auto
  then have "set (vals p (hd ?mine)) = {v}" using val hdmap
    by (cases "vals p (hd ?mine)") (auto simp: dom)
  with sets show "(\<forall>c \<in> set ?mine. set (vals p c) = {v})" by auto
  then have in_rows: "v \<in> set (vals p (hd ?mine))" using dom by auto
  from in_rows show "(p, v) \<in> set (rows (hd ?mine))" by (auto simp: set_vals)
  from in_rows show "v \<noteq> Blank" by (auto simp: set_vals)
  show "\<not> restates f v" by (rule no_restates)
  show "p \<notin> set time_variant \<or> \<not> past f" by (rule no_past)
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
          c \<in> set (filter domain_member (take 3 (select (candidates a)))) \<and>
          qid c = s \<and> dom_complete c \<and> (\<forall>c' \<in> set (select (candidates a)). complete c') \<and>
          (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and> \<not> restates f v \<and>
          (\<forall>c' \<in> set (filter domain_member (take 3 (select (candidates a)))). set (vals p c') = {v})"
proof -
  from ans have "walk f attempts None = Answer (s, p, v)" by (simp add: decide_spec_def)
  then obtain a where a: "a \<in> set attempts" and av: "attempt_values f a = Some (s, p, v)"
    using walk_answer_exists[rule_format] by meson
  from attempt_values_sound(1)[OF av] table_props
  show "p \<in> {50, 577, 840, 156, 144}" by fastforce
  let ?mine = "filter domain_member (take 3 (select (candidates a)))"
  let ?c = "hd ?mine"
  have mine_ne: "?mine \<noteq> []" by (rule attempt_values_sound(6)[OF av])
  have cin: "?c \<in> set ?mine" using mine_ne by (cases "?mine") auto
  have cdom: "domain_member ?c" using cin by (auto simp: set_filter)
  note receipts = attempt_values_sound(7,8,9,10,11,12,13)[OF av]
  from a av cin receipts cdom show "\<exists>a c. a \<in> set attempts \<and> attempt_values f a = Some (s, p, v) \<and>
          c \<in> set (filter domain_member (take 3 (select (candidates a)))) \<and>
          qid c = s \<and> dom_complete c \<and> (\<forall>c' \<in> set (select (candidates a)). complete c') \<and>
          (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and> \<not> restates f v \<and>
          (\<forall>c' \<in> set (filter domain_member (take 3 (select (candidates a)))). set (vals p c') = {v})"
    by (intro exI[where x = a] exI[where x = ?c]) (auto simp: domain_member_roots)
qed

text \<open>A decline names one of the five properties and a linked candidate that is in the domain:
recognise-then-decline, never a refusal about something the specialist did not read.\<close>

theorem decline_stored:
  assumes dec: "decide_spec f attempts = Decline (p, s)"
  shows "p \<in> {50, 577, 840, 156, 144}"
    and "\<exists>a c. a \<in> set attempts \<and> in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
          c \<in> set (select (candidates a)) \<and> qid c = s \<and> domain_member c"
proof -
  from decline_meaning[OF dec] obtain a where a: "a \<in> set attempts" and ad: "attempt_decline f a (p, s)"
    by auto
  have guards: "in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> []"
    using ad by (auto simp: attempt_decline_def)
  have pk: "p = prop_of (key a)"
    using ad by (auto simp: attempt_decline_def split: if_splits)
  from table_props guards pk show "p \<in> {50, 577, 840, 156, 144}" by fastforce
  let ?cs = "select (candidates a)"
  show "\<exists>a c. a \<in> set attempts \<and> in_table (key a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> [] \<and>
          c \<in> set (select (candidates a)) \<and> qid c = s \<and> domain_member c"
  proof (cases "dropped (key a) (idx a)")
    case True
    with ad have "domain_member (hd ?cs) \<and> (p, s) = (prop_of (key a), qid (hd ?cs))"
      by (auto simp: attempt_decline_def)
    with guards have dm: "domain_member (hd ?cs)" and qs: "qid (hd ?cs) = s"
      by (auto simp: prop_of_def)
    have hin: "hd ?cs \<in> set ?cs" using guards by (cases "candidates a") (auto simp: select_def)
    show ?thesis
      by (intro exI[where x = a] exI[where x = "hd ?cs"])
         (auto simp: guards hin dm qs)
  next
    case False
    let ?mine = "filter domain_member (take 3 ?cs)"
    from False ad have mine_ne: "?mine \<noteq> []" and qs: "qid (hd ?mine) = s"
      by (auto simp: attempt_decline_def prop_of_def)
    have dm: "domain_member (hd ?mine)" using mine_ne by (cases "?mine") (auto simp: set_filter)
    have hin: "hd ?mine \<in> set ?cs" using mine_ne
      by (cases "?mine") (auto dest: in_set_takeD simp: select_subset)
    show ?thesis
      by (intro exI[where x = a] exI[where x = "hd ?mine"])
         (auto simp: guards hin dm qs)
  qed
qed

end
