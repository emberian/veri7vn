theory Relation_Reader
  imports Main
begin

text \<open>Oracle7's 161 relation specialists (upstream/root/specialists/rel-*, class RelationOrganV2 and
its pronoun-guard subclass RelationOrganV2G, engine wander-train/relation_spec_v2.py) as ONE decision
over fetched evidence. A specialist is data (a spec record): its reader table (which reader keys, which
Wikidata property each reads, how many forward and inverse phrasings, which phrasings the natural
measuring dropped), its domain (root classes, occupation roots for people, excluded properties) and
whether the pronoun guard applies. The decision itself is one function, @{term decide_spec}.

This generalises lane W5-01's novels kernel (src/extract/rel-novels/Novel_Reader.thy) with one change
of rule, stated in @{text pool_agrees}: a forward answer needs every LINKED in-domain sense that holds a
stored value of the property to hold exactly the answered value, not only the (at most three) senses
the shipped popularity rule selects. The shipped rule answered eleven panel questions with the
popular homonym's value (an album called Infinite by Eminem for the one by Stratovarius); under this
rule each of them is declined (@{text disagreeing_senses_never_answer}).

Everything a regex or a store query produces arrives as fetched data: which phrasing matched, the
slot, the linked senses in rank order with their popularity, each sense's classes and their
subclass-of closures, the excluded properties it holds, its label and its stored rows of the asked
property. The fetch flags @{term complete} (the rows are every stored fact of the property) and
@{term dom_complete} (classes, closures and held properties are the shipped walk over the store) are
premises supplied by untrusted glue, never established here.

The mined-pattern fallback (relation_spec_v1.answer over patterns.json, 23 specialists) is not
modelled: where the shipped organ would fall back, this decision is silent. Measured: the fallback
answers none of the 18,976 panel items over the shipped store.\<close>

datatype rel_value = Entity natural | Literal String.literal | Blank
datatype direction = Fwd | Inv

record reader =
  rkey :: String.literal
  rprop :: natural
  nfwd :: natural
  ninv :: natural
  dfwd :: "natural list"
  dinv :: "natural list"

record spec =
  sid :: String.literal
  readers :: "reader list"
  roots :: "natural list"
  occs :: "natural list"
  excl :: "natural list"
  guard :: bool

record candidate =
  qid :: natural
  links :: natural
  dom_complete :: bool
  cls :: "natural list"
  canc :: "natural list list"
  oanc :: "natural list list"
  held :: "natural list"
  label :: rel_value
  rows :: "(natural \<times> rel_value) list"
  complete :: bool
  pron :: bool

record attempt =
  key :: String.literal
  dir :: direction
  idx :: natural
  slot_ok :: bool
  candidates :: "candidate list"
  subjects :: "candidate list"
  capped :: bool

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

section \<open>The reader table of one specialist\<close>

definition reader_of :: "spec \<Rightarrow> String.literal \<Rightarrow> reader option" where
  "reader_of sp k = find (\<lambda>r. rkey r = k) (readers sp)"

definition in_table :: "spec \<Rightarrow> String.literal \<Rightarrow> direction \<Rightarrow> natural \<Rightarrow> bool" where
  "in_table sp k d i = (case reader_of sp k of None \<Rightarrow> False
     | Some r \<Rightarrow> i < (case d of Fwd \<Rightarrow> nfwd r | Inv \<Rightarrow> ninv r))"

definition dropped :: "spec \<Rightarrow> String.literal \<Rightarrow> direction \<Rightarrow> natural \<Rightarrow> bool" where
  "dropped sp k d i = (case reader_of sp k of None \<Rightarrow> False
     | Some r \<Rightarrow> i \<in> set (case d of Fwd \<Rightarrow> dfwd r | Inv \<Rightarrow> dinv r))"

definition prop_of :: "spec \<Rightarrow> String.literal \<Rightarrow> natural" where
  "prop_of sp k = (case reader_of sp k of None \<Rightarrow> 0 | Some r \<Rightarrow> rprop r)"

lemma find_Some_mem: "find P xs = Some x \<Longrightarrow> x \<in> set xs \<and> P x"
  by (induct xs) (auto split: if_splits)

lemma in_table_reader:
  assumes "in_table sp k d i"
  shows "\<exists>r \<in> set (readers sp). rkey r = k \<and> prop_of sp k = rprop r \<and>
           i < (case d of Fwd \<Rightarrow> nfwd r | Inv \<Rightarrow> ninv r)"
proof (cases "reader_of sp k")
  case None
  with assms show ?thesis by (simp add: in_table_def)
next
  case (Some r)
  then have "r \<in> set (readers sp) \<and> rkey r = k" using find_Some_mem by (fastforce simp: reader_of_def)
  with Some assms show ?thesis by (auto simp: in_table_def prop_of_def)
qed

section \<open>The domain\<close>

definition hits :: "natural list list \<Rightarrow> natural list \<Rightarrow> bool" where
  "hits ancs xs = (\<exists>anc \<in> set ancs. \<exists>x \<in> set anc. x \<in> set xs)"

text \<open>relation_spec_v2.in_domain: a member holds none of the domain's excluded properties, and
either one of its classes' closures meets the domain roots, or it is human (class 5) and one of its
occupations' closures meets the occupation roots.\<close>

definition domain_member :: "spec \<Rightarrow> candidate \<Rightarrow> bool" where
  "domain_member sp c = (dom_complete c \<and> (\<forall>x \<in> set (excl sp). x \<notin> set (held c)) \<and>
     (hits (canc c) (roots sp) \<or> (5 \<in> set (cls c) \<and> hits (oanc c) (occs sp))))"

section \<open>Stored values and the question\<close>

definition vals :: "natural \<Rightarrow> candidate \<Rightarrow> rel_value list" where
  "vals p c = remdups (filter (\<lambda>v. v \<noteq> Blank) (map snd (filter (\<lambda>(p', _). p' = p) (rows c))))"

lemma set_vals: "set (vals p c) = {v. v \<noteq> Blank \<and> (p, v) \<in> set (rows c)}"
  by (force simp: vals_def)

definition time_variant :: "natural list" where
  "time_variant = [36, 35, 6, 54, 159, 27, 17, 131, 286, 488, 1037, 108, 39, 463, 102, 26]"

definition restates :: "question_features \<Rightarrow> rel_value \<Rightarrow> bool" where
  "restates f v = (case map_of (value_words f) v of
      Some ws \<Rightarrow> ws \<noteq> [] \<and> set ws \<subseteq> set (question_words f) | None \<Rightarrow> False)"

section \<open>Candidate selection: at most three, or one when it dominates (the shipped rule)\<close>

definition dominated :: "candidate list \<Rightarrow> bool" where
  "dominated cs = (case cs of c # rest \<Rightarrow> rest \<noteq> [] \<and>
      10 * max 1 (fold max (map links rest) 0) \<le> links c | [] \<Rightarrow> False)"

definition select :: "candidate list \<Rightarrow> candidate list" where
  "select cs = (if dominated cs then take 1 cs else take 3 cs)"

abbreviation (input) selof :: "attempt \<Rightarrow> candidate list" where
  "selof a \<equiv> select (candidates a)"

abbreviation (input) mineof :: "spec \<Rightarrow> attempt \<Rightarrow> candidate list" where
  "mineof sp a \<equiv> filter (domain_member sp) (take 3 (select (candidates a)))"

abbreviation (input) poolof :: "spec \<Rightarrow> attempt \<Rightarrow> candidate list" where
  "poolof sp a \<equiv> filter (domain_member sp) (candidates a)"

abbreviation (input) vsof :: "spec \<Rightarrow> attempt \<Rightarrow> rel_value list list" where
  "vsof sp a \<equiv> map (vals (prop_of sp (key a))) (filter (domain_member sp) (take 3 (select (candidates a))))"

abbreviation (input) insubs :: "spec \<Rightarrow> attempt \<Rightarrow> candidate list" where
  "insubs sp a \<equiv> filter (domain_member sp) (subjects a)"

lemma select_subset: "set (select cs) \<subseteq> set cs"
  by (auto simp: select_def dest: in_set_takeD)

lemma select_nonempty: "cs \<noteq> [] \<Longrightarrow> select cs \<noteq> []"
  by (cases cs) (auto simp: select_def split: if_splits)

lemma select_head: "cs \<noteq> [] \<Longrightarrow> hd (select cs) = hd cs"
  by (cases cs) (auto simp: select_def split: if_splits)

lemma mine_in_candidates: "c \<in> set (mineof sp a) \<Longrightarrow> c \<in> set (candidates a) \<and> domain_member sp c"
  using select_subset by (auto dest: in_set_takeD)

section \<open>One attempt\<close>

definition live :: "spec \<Rightarrow> attempt \<Rightarrow> bool" where
  "live sp a \<longleftrightarrow> in_table sp (key a) (dir a) (idx a) \<and> slot_ok a \<and> candidates a \<noteq> []"

definition allc :: "attempt \<Rightarrow> bool" where
  "allc a \<longleftrightarrow> (\<forall>c \<in> set (candidates a). complete c)"

text \<open>@{text agreed} is the shipped rule: the in-domain senses among the selected ones exist, each
holds at least one stored value, they all hold the same set of values, and that set has one member.\<close>

definition agreed :: "spec \<Rightarrow> attempt \<Rightarrow> bool" where
  "agreed sp a \<longleftrightarrow> mineof sp a \<noteq> [] \<and> (\<forall>v \<in> set (vsof sp a). v \<noteq> []) \<and>
     (\<forall>v \<in> set (vsof sp a). set v = set (hd (vsof sp a))) \<and> length (hd (vsof sp a)) = 1"

text \<open>@{text pool_agrees} is this kernel's added rule: every linked in-domain sense, selected or not,
that holds a stored value of the property holds the same set of values as the answering sense.\<close>

definition pool_agrees :: "spec \<Rightarrow> attempt \<Rightarrow> bool" where
  "pool_agrees sp a \<longleftrightarrow> (\<forall>c \<in> set (poolof sp a). vals (prop_of sp (key a)) c \<noteq> [] \<longrightarrow>
     set (vals (prop_of sp (key a)) c) = set (hd (vsof sp a)))"

text \<open>The shipped inverse reading: the value is the top linked sense; the fetch sends the first (up
to) eight subjects that hold it; when there are none, or eight (the shipped LIMIT 8 is reached), the
phrasing is passed over; exactly one in-domain subject must remain, with a label. The decision also
checks, from the subjects' own rows, that each in-domain subject holds the top sense's label as a value
of the property, which the shipped query guarantees by construction.\<close>

definition inv_ok :: "spec \<Rightarrow> attempt \<Rightarrow> bool" where
  "inv_ok sp a \<longleftrightarrow> subjects a \<noteq> [] \<and> \<not> capped a \<and> insubs sp a \<noteq> [] \<and>
     (\<forall>c \<in> set (insubs sp a). qid c = qid (hd (insubs sp a))) \<and>
     label (hd (insubs sp a)) \<noteq> Blank \<and> label (hd (candidates a)) \<noteq> Blank \<and>
     (\<forall>c \<in> set (insubs sp a). (prop_of sp (key a), label (hd (candidates a))) \<in> set (rows c))"

datatype step = Cont "(natural \<times> natural \<times> bool) option" | Halt outcome

text \<open>The end of an answering attempt: a value that restates the question, a time-variant property
asked in the past, or (pronoun guard) a subject whose title is a pronoun the question writes in lower
case silence the whole turn, exactly as the shipped code returns None.\<close>

definition finish :: "spec \<Rightarrow> question_features \<Rightarrow> attempt \<Rightarrow> candidate \<Rightarrow> rel_value \<Rightarrow> step" where
  "finish sp f a c v =
    (if restates f v then Halt Silent
     else if prop_of sp (key a) \<in> set time_variant \<and> past f then Halt Silent
     else if guard sp \<and> pron c then Halt Silent
     else Halt (Answer (qid c, prop_of sp (key a), v)))"

definition step :: "spec \<Rightarrow> question_features \<Rightarrow> attempt \<Rightarrow> step" where
  "step sp f a =
    (if \<not> live sp a then Cont None
     else if dropped sp (key a) (dir a) (idx a) then
       Cont (if dir a = Fwd \<and> domain_member sp (hd (selof a))
             then Some (prop_of sp (key a), qid (hd (selof a)), pron (hd (selof a))) else None)
     else if dir a = Inv then
       (if inv_ok sp a then finish sp f a (hd (insubs sp a)) (label (hd (insubs sp a))) else Cont None)
     else if \<not> allc a then Halt Incomplete
     else if \<not> (agreed sp a \<and> pool_agrees sp a) then
       Cont (if mineof sp a = [] then None
             else Some (prop_of sp (key a), qid (hd (mineof sp a)), pron (hd (mineof sp a))))
     else finish sp f a (hd (mineof sp a)) (hd (hd (vsof sp a))))"

fun walk :: "spec \<Rightarrow> question_features \<Rightarrow> attempt list \<Rightarrow> (natural \<times> natural \<times> bool) option \<Rightarrow> outcome" where
  "walk sp f [] acc = (case acc of None \<Rightarrow> Silent
     | Some d \<Rightarrow> (if guard sp \<and> snd (snd d) then Silent else Decline (fst d, fst (snd d))))"
| "walk sp f (a # rest) acc =
    (case step sp f a of
       Halt r \<Rightarrow> r
     | Cont m \<Rightarrow> walk sp f rest (case acc of None \<Rightarrow> m | Some d \<Rightarrow> Some d))"

definition decide_spec :: "spec \<Rightarrow> question_features \<Rightarrow> attempt list \<Rightarrow> outcome" where
  "decide_spec sp f attempts = (if kind_conflict f then Silent else walk sp f attempts None)"

section \<open>What one attempt answers, marks, or passes\<close>

definition attempt_values :: "spec \<Rightarrow> question_features \<Rightarrow> attempt \<Rightarrow> (natural \<times> natural \<times> rel_value) option" where
  "attempt_values sp f a = (case step sp f a of Halt (Answer x) \<Rightarrow> Some x | _ \<Rightarrow> None)"

definition attempt_decline :: "spec \<Rightarrow> question_features \<Rightarrow> attempt \<Rightarrow> (natural \<times> natural \<times> bool) \<Rightarrow> bool" where
  "attempt_decline sp f a d \<longleftrightarrow> step sp f a = Cont (Some d)"

definition transparent :: "spec \<Rightarrow> question_features \<Rightarrow> attempt \<Rightarrow> bool" where
  "transparent sp f a \<longleftrightarrow> step sp f a = Cont None"

lemma attempt_values_iff: "attempt_values sp f a = Some x \<longleftrightarrow> step sp f a = Halt (Answer x)"
proof (cases "step sp f a")
  case (Cont m)
  then show ?thesis by (simp add: attempt_values_def)
next
  case (Halt r)
  then show ?thesis by (cases r) (simp_all add: attempt_values_def)
qed

lemma attempt_values_None: "step sp f a = Cont m \<Longrightarrow> attempt_values sp f a = None"
  by (simp add: attempt_values_def)

lemma finish_not_decline: "finish sp f a c v \<noteq> Halt (Decline d)"
  by (simp add: finish_def)

lemma finish_not_incomplete: "finish sp f a c v \<noteq> Halt Incomplete"
  by (simp add: finish_def)

lemma finish_not_cont: "finish sp f a c v \<noteq> Cont m"
  by (simp add: finish_def)

lemma finish_answer:
  assumes "finish sp f a c v = Halt (Answer (s, p, w))"
  shows "s = qid c \<and> p = prop_of sp (key a) \<and> w = v \<and> \<not> restates f v \<and>
         \<not> (p \<in> set time_variant \<and> past f) \<and> \<not> (guard sp \<and> pron c)"
  using assms by (simp add: finish_def split: if_splits)

lemma step_not_decline: "step sp f a \<noteq> Halt (Decline d)"
  by (simp add: step_def finish_not_decline split: if_splits)

section \<open>What the walk's end result means\<close>

lemma walk_answer_exists:
  "\<forall>acc. walk sp f attempts acc = Answer x \<longrightarrow> (\<exists>a \<in> set attempts. attempt_values sp f a = Some x)"
proof (induct attempts)
  case Nil
  show ?case by (auto split: option.splits if_splits)
next
  case (Cons a attempts)
  show ?case
  proof (intro allI impI)
    fix acc
    assume ans: "walk sp f (a # attempts) acc = Answer x"
    show "\<exists>b \<in> set (a # attempts). attempt_values sp f b = Some x"
    proof (cases "step sp f a")
      case (Halt r)
      with ans have "r = Answer x" by simp
      with Halt have "attempt_values sp f a = Some x" by (simp add: attempt_values_iff)
      then show ?thesis by auto
    next
      case (Cont m)
      with ans have "walk sp f attempts (case acc of None \<Rightarrow> m | Some d \<Rightarrow> Some d) = Answer x" by simp
      with Cons obtain b where "b \<in> set attempts" "attempt_values sp f b = Some x" by blast
      then show ?thesis by auto
    qed
  qed
qed

lemma no_answer_when_none:
  assumes none: "\<forall>a \<in> set attempts. attempt_values sp f a = None"
  shows "walk sp f attempts acc \<noteq> Answer x"
proof
  assume eq: "walk sp f attempts acc = Answer x"
  then have "\<exists>a \<in> set attempts. attempt_values sp f a = Some x"
    using walk_answer_exists[rule_format] by meson
  with none show False by auto
qed

lemma walk_end_decline:
  "walk sp f [] acc = Decline (p, s) \<Longrightarrow> \<exists>pr. acc = Some (p, s, pr) \<and> \<not> (guard sp \<and> pr)"
  by (cases acc) (auto split: if_splits)

lemma walk_decline_inv:
  assumes dw: "walk sp f attempts acc = Decline (p, s)"
  shows "(\<forall>b \<in> set attempts. attempt_values sp f b = None) \<and>
    (\<exists>pr. \<not> (guard sp \<and> pr) \<and> ((acc = Some (p, s, pr)) \<or> (\<exists>b \<in> set attempts. attempt_decline sp f b (p, s, pr))))"
  using dw
proof (induct attempts arbitrary: acc)
  case Nil
  then obtain pr where e1: "acc = Some (p, s, pr)" and e2: "\<not> (guard sp \<and> pr)"
    by (meson walk_end_decline)
  show ?case using e1 e2 by auto
next
  case (Cons a rest)
  show ?case
  proof (cases "step sp f a")
    case (Halt r)
    with Cons.prems have "r = Decline (p, s)" by simp
    with Halt step_not_decline show ?thesis by metis
  next
    case (Cont m)
    with Cons.prems have w: "walk sp f rest (case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Decline (p, s)" by simp
    from Cons.hyps[OF w] obtain pr where ih1: "\<forall>b \<in> set rest. attempt_values sp f b = None"
      and ng: "\<not> (guard sp \<and> pr)"
      and ih2: "(case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Some (p, s, pr) \<or>
                (\<exists>b \<in> set rest. attempt_decline sp f b (p, s, pr))" by blast
    have va: "attempt_values sp f a = None" by (rule attempt_values_None[OF Cont])
    show ?thesis
    proof (cases acc)
      case None
      with ih2 have "m = Some (p, s, pr) \<or> (\<exists>b \<in> set rest. attempt_decline sp f b (p, s, pr))" by simp
      then show ?thesis using ih1 va Cont ng by (auto simp: attempt_decline_def)
    next
      case (Some e)
      with ih2 have "e = (p, s, pr) \<or> (\<exists>b \<in> set rest. attempt_decline sp f b (p, s, pr))" by simp
      then show ?thesis using ih1 va Some ng by auto
    qed
  qed
qed

lemma decline_meaning:
  assumes "decide_spec sp f attempts = Decline (p, s)"
  shows "\<forall>a \<in> set attempts. attempt_values sp f a = None"
    and "\<exists>a \<in> set attempts. \<exists>pr. attempt_decline sp f a (p, s, pr) \<and> \<not> (guard sp \<and> pr)"
proof -
  from assms have w: "walk sp f attempts None = Decline (p, s)"
    by (cases "kind_conflict f") (simp_all add: decide_spec_def)
  from walk_decline_inv[OF w] show "\<forall>a \<in> set attempts. attempt_values sp f a = None" by blast
  from walk_decline_inv[OF w] show "\<exists>a \<in> set attempts. \<exists>pr. attempt_decline sp f a (p, s, pr) \<and> \<not> (guard sp \<and> pr)"
    by blast
qed

lemma step_incomplete:
  assumes "step sp f a = Halt Incomplete"
  shows "live sp a \<and> \<not> dropped sp (key a) (dir a) (idx a) \<and> dir a = Fwd \<and>
    (\<exists>c \<in> set (candidates a). \<not> complete c)"
  using assms finish_not_incomplete
  by (cases "dir a") (auto simp: step_def allc_def split: if_splits)

lemma walk_incomplete_inv:
  assumes iw: "walk sp f attempts acc = Incomplete"
  shows "\<exists>a \<in> set attempts. step sp f a = Halt Incomplete"
  using iw
proof (induct attempts arbitrary: acc)
  case Nil
  then show ?case by (cases acc) (simp_all split: if_splits)
next
  case (Cons a rest)
  show ?case
  proof (cases "step sp f a")
    case (Halt r)
    with Cons.prems have "r = Incomplete" by simp
    with Halt show ?thesis by auto
  next
    case (Cont m)
    with Cons.prems have "walk sp f rest (case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Incomplete" by simp
    from Cons.hyps[OF this] show ?thesis by auto
  qed
qed

lemma incomplete_meaning:
  assumes "decide_spec sp f attempts = Incomplete"
  shows "\<exists>a \<in> set attempts. live sp a \<and> \<not> dropped sp (key a) (dir a) (idx a) \<and> dir a = Fwd \<and>
    (\<exists>c \<in> set (candidates a). \<not> complete c)"
proof -
  from assms have "walk sp f attempts None = Incomplete"
    by (cases "kind_conflict f") (simp_all add: decide_spec_def)
  from walk_incomplete_inv[OF this] show ?thesis using step_incomplete by blast
qed

lemma walk_silent_inv:
  assumes sw: "walk sp f attempts acc = Silent"
  shows "(\<exists>a \<in> set attempts. step sp f a = Halt Silent) \<or>
    (acc = None \<and> (\<forall>a \<in> set attempts. transparent sp f a)) \<or>
    (guard sp \<and> ((\<exists>d. acc = Some d \<and> snd (snd d)) \<or>
                   (\<exists>a \<in> set attempts. \<exists>d. attempt_decline sp f a d \<and> snd (snd d))))"
  using sw
proof (induct attempts arbitrary: acc)
  case Nil
  then show ?case by (cases acc) (auto split: if_splits)
next
  case (Cons a rest)
  show ?case
  proof (cases "step sp f a")
    case (Halt r)
    with Cons.prems have "r = Silent" by simp
    with Halt show ?thesis by auto
  next
    case (Cont m)
    with Cons.prems have w: "walk sp f rest (case acc of None \<Rightarrow> m | Some e \<Rightarrow> Some e) = Silent" by simp
    note ih = Cons.hyps[OF w]
    show ?thesis
    proof (cases acc)
      case None
      with ih have "(\<exists>b \<in> set rest. step sp f b = Halt Silent) \<or> (m = None \<and> (\<forall>b \<in> set rest. transparent sp f b)) \<or>
          (guard sp \<and> ((\<exists>d. m = Some d \<and> snd (snd d)) \<or> (\<exists>b \<in> set rest. \<exists>d. attempt_decline sp f b d \<and> snd (snd d))))"
        by simp
      then show ?thesis using None Cont by (auto simp: transparent_def attempt_decline_def)
    next
      case (Some e)
      with ih have "(\<exists>b \<in> set rest. step sp f b = Halt Silent) \<or>
          (guard sp \<and> ((snd (snd e)) \<or> (\<exists>b \<in> set rest. \<exists>d. attempt_decline sp f b d \<and> snd (snd d))))"
        by auto
      then consider (h) "\<exists>b \<in> set rest. step sp f b = Halt Silent"
        | (g) "guard sp" "snd (snd e)"
        | (gd) "guard sp" "\<exists>b \<in> set rest. \<exists>d. attempt_decline sp f b d \<and> snd (snd d)"
        by blast
      then show ?thesis
      proof cases
        case h
        then have "\<exists>b \<in> set (a # rest). step sp f b = Halt Silent" by auto
        then show ?thesis by blast
      next
        case g
        have "\<exists>d. acc = Some d \<and> snd (snd d)" using Some g(2) by blast
        with g(1) show ?thesis by blast
      next
        case gd
        from gd(2) obtain b d where b: "b \<in> set rest" "attempt_decline sp f b d" "snd (snd d)" by blast
        have bm: "b \<in> set (a # rest)" using b(1) by simp
        have cj: "attempt_decline sp f b d \<and> snd (snd d)" using b(2) b(3) by (rule conjI)
        then have ex: "\<exists>d. attempt_decline sp f b d \<and> snd (snd d)" by (rule exI)
        have "\<exists>b \<in> set (a # rest). \<exists>d. attempt_decline sp f b d \<and> snd (snd d)"
          using ex bm by (rule bexI)
        with gd(1) show ?thesis by blast
      qed
    qed
  qed
qed

lemma silent_meaning:
  assumes "decide_spec sp f attempts = Silent"
  shows "kind_conflict f \<or> (\<exists>a \<in> set attempts. step sp f a = Halt Silent) \<or>
    (\<forall>a \<in> set attempts. transparent sp f a) \<or>
    (guard sp \<and> (\<exists>a \<in> set attempts. \<exists>d. attempt_decline sp f a d \<and> snd (snd d)))"
proof (cases "kind_conflict f")
  case True
  then show ?thesis by simp
next
  case False
  then have "walk sp f attempts None = Silent" using assms by (simp add: decide_spec_def)
  from walk_silent_inv[OF this] show ?thesis by auto
qed

text \<open>A turn is silenced at an attempt only after the attempt would have answered: the restate,
past-tense and pronoun checks of @{const finish}.\<close>

lemma finish_silent:
  assumes "finish sp f a c v = Halt Silent"
  shows "restates f v \<or> prop_of sp (key a) \<in> set time_variant \<and> past f \<or> guard sp \<and> pron c"
  using assms by (simp add: finish_def split: if_splits)

lemma step_silent:
  assumes st: "step sp f a = Halt Silent"
  shows "live sp a \<and> \<not> dropped sp (key a) (dir a) (idx a) \<and>
    (\<exists>c v. finish sp f a c v = Halt Silent \<and>
       (restates f v \<or> prop_of sp (key a) \<in> set time_variant \<and> past f \<or> guard sp \<and> pron c))"
proof -
  have lv: "live sp a" using st by (auto simp: step_def split: if_splits)
  have nd: "\<not> dropped sp (key a) (dir a) (idx a)" using st lv by (auto simp: step_def split: if_splits)
  have two: "step sp f a = finish sp f a (hd (insubs sp a)) (label (hd (insubs sp a))) \<or>
             step sp f a = finish sp f a (hd (mineof sp a)) (hd (hd (vsof sp a)))"
    using st lv nd by (auto simp: step_def split: if_splits)
  then show ?thesis
  proof
    assume e: "step sp f a = finish sp f a (hd (insubs sp a)) (label (hd (insubs sp a)))"
    with st have fs: "finish sp f a (hd (insubs sp a)) (label (hd (insubs sp a))) = Halt Silent" by simp
    show ?thesis using lv nd fs finish_silent[OF fs] by blast
  next
    assume e: "step sp f a = finish sp f a (hd (mineof sp a)) (hd (hd (vsof sp a)))"
    with st have fs: "finish sp f a (hd (mineof sp a)) (hd (hd (vsof sp a))) = Halt Silent" by simp
    show ?thesis using lv nd fs finish_silent[OF fs] by blast
  qed
qed

section \<open>Meaning of a forward answer\<close>

lemma agreed_unfold:
  assumes ag: "agreed sp a"
  shows "mineof sp a \<noteq> []"
    and "\<forall>c \<in> set (mineof sp a). set (vals (prop_of sp (key a)) c) = set (vals (prop_of sp (key a)) (hd (mineof sp a)))"
    and "length (vals (prop_of sp (key a)) (hd (mineof sp a))) = 1"
    and "hd (vsof sp a) = vals (prop_of sp (key a)) (hd (mineof sp a))"
proof -
  note g = ag[unfolded agreed_def]
  have ne: "mineof sp a \<noteq> []" using g by blast
  then show "mineof sp a \<noteq> []" .
  have hd: "hd (vsof sp a) = vals (prop_of sp (key a)) (hd (mineof sp a))" by (rule hd_map[OF ne])
  then show "hd (vsof sp a) = vals (prop_of sp (key a)) (hd (mineof sp a))" .
  show "length (vals (prop_of sp (key a)) (hd (mineof sp a))) = 1" using g hd by metis
  show "\<forall>c \<in> set (mineof sp a). set (vals (prop_of sp (key a)) c) = set (vals (prop_of sp (key a)) (hd (mineof sp a)))"
  proof
    fix c assume c: "c \<in> set (mineof sp a)"
    have "vals (prop_of sp (key a)) c \<in> set (vsof sp a)" unfolding set_map by (rule imageI[OF c])
    with g hd show "set (vals (prop_of sp (key a)) c) = set (vals (prop_of sp (key a)) (hd (mineof sp a)))" by metis
  qed
qed

lemma step_fwd_answer:
  assumes st: "step sp f a = Halt (Answer (s, p, v))" and fw: "dir a = Fwd"
  shows "live sp a \<and> \<not> dropped sp (key a) (dir a) (idx a) \<and> allc a \<and> agreed sp a \<and> pool_agrees sp a \<and>
         finish sp f a (hd (mineof sp a)) (hd (hd (vsof sp a))) = Halt (Answer (s, p, v))"
  using st fw finish_not_cont by (auto simp: step_def split: if_splits)

lemma attempt_values_sound:
  assumes av: "attempt_values sp f a = Some (s, p, v)" and fw: "dir a = Fwd"
  shows "live sp a" "\<not> dropped sp (key a) (dir a) (idx a)"
    "p = prop_of sp (key a)"
    "mineof sp a \<noteq> []"
    "s = qid (hd (mineof sp a))"
    "domain_member sp (hd (mineof sp a))"
    "\<forall>c \<in> set (candidates a). complete c"
    "\<forall>c \<in> set (mineof sp a). set (vals p c) = {v}"
    "\<forall>c \<in> set (candidates a). domain_member sp c \<and> vals p c \<noteq> [] \<longrightarrow> set (vals p c) = {v}"
    "(p, v) \<in> set (rows (hd (mineof sp a)))"
    "v \<noteq> Blank"
    "\<not> restates f v"
    "p \<notin> set time_variant \<or> \<not> past f"
    "\<not> (guard sp \<and> pron (hd (mineof sp a)))"
proof -
  from av have st: "step sp f a = Halt (Answer (s, p, v))" by (simp add: attempt_values_iff)
  note g = step_fwd_answer[OF st fw]
  then have live: "live sp a" and nd: "\<not> dropped sp (key a) (dir a) (idx a)" and ac: "allc a"
    and ag: "agreed sp a" and pa: "pool_agrees sp a"
    and fin: "finish sp f a (hd (mineof sp a)) (hd (hd (vsof sp a))) = Halt (Answer (s, p, v))" by blast+
  note fa = finish_answer[OF fin]
  from live show "live sp a" .
  from nd show "\<not> dropped sp (key a) (dir a) (idx a)" .
  from fa show pv: "p = prop_of sp (key a)" by blast
  have mine: "mineof sp a \<noteq> []" by (rule agreed_unfold(1)[OF ag])
  then show "mineof sp a \<noteq> []" .
  from fa show "s = qid (hd (mineof sp a))" by blast
  have hin: "hd (mineof sp a) \<in> set (mineof sp a)" by (rule hd_in_set[OF mine])
  then show "domain_member sp (hd (mineof sp a))" by (simp add: set_filter)
  from ac show "\<forall>c \<in> set (candidates a). complete c" by (simp add: allc_def)
  note same = agreed_unfold(2)[OF ag] and len = agreed_unfold(3)[OF ag] and hdv = agreed_unfold(4)[OF ag]
  from len obtain w where w: "vals (prop_of sp (key a)) (hd (mineof sp a)) = [w]"
    by (cases "vals (prop_of sp (key a)) (hd (mineof sp a))") auto
  from fa have vv: "v = hd (hd (vsof sp a))" by blast
  from vv hdv w have vw: "v = w" by simp
  show "\<forall>c \<in> set (mineof sp a). set (vals p c) = {v}" using same w vw pv by simp
  show "\<forall>c \<in> set (candidates a). domain_member sp c \<and> vals p c \<noteq> [] \<longrightarrow> set (vals p c) = {v}"
  proof (intro ballI impI)
    fix c assume c: "c \<in> set (candidates a)" and h: "domain_member sp c \<and> vals p c \<noteq> []"
    then have "c \<in> set (poolof sp a)" by simp
    with pa h pv have "set (vals p c) = set (hd (vsof sp a))" by (simp add: pool_agrees_def)
    with hdv w vw show "set (vals p c) = {v}" by simp
  qed
  have "set (vals p (hd (mineof sp a))) = {v}" using same w vw pv hin by simp
  then have in_rows: "v \<in> set (vals p (hd (mineof sp a)))" by simp
  from in_rows show "(p, v) \<in> set (rows (hd (mineof sp a)))" by (simp add: set_vals)
  from in_rows show "v \<noteq> Blank" by (simp add: set_vals)
  from fa vv show "\<not> restates f v" by blast
  from fa show "p \<notin> set time_variant \<or> \<not> past f" by blast
  from fa show "\<not> (guard sp \<and> pron (hd (mineof sp a)))" by blast
qed

section \<open>Meaning of an inverse answer\<close>

lemma attempt_values_sound_inv:
  assumes av: "attempt_values sp f a = Some (s, p, v)" and iv: "dir a = Inv"
  shows "live sp a" "\<not> dropped sp (key a) (dir a) (idx a)" "p = prop_of sp (key a)" "\<not> capped a"
    "\<exists>c \<in> set (subjects a). domain_member sp c \<and> qid c = s \<and> label c = v \<and> v \<noteq> Blank \<and>
        (p, label (hd (candidates a))) \<in> set (rows c) \<and> label (hd (candidates a)) \<noteq> Blank \<and>
        \<not> (guard sp \<and> pron c)"
    "\<forall>c \<in> set (subjects a). domain_member sp c \<longrightarrow> qid c = s"
    "\<not> restates f v" "p \<notin> set time_variant \<or> \<not> past f"
proof -
  from av have st: "step sp f a = Halt (Answer (s, p, v))" by (simp add: attempt_values_iff)
  have g: "live sp a \<and> \<not> dropped sp (key a) (dir a) (idx a) \<and> inv_ok sp a \<and>
      finish sp f a (hd (insubs sp a)) (label (hd (insubs sp a))) = Halt (Answer (s, p, v))"
    using st iv finish_not_cont by (auto simp: step_def split: if_splits)
  then have live: "live sp a" and nd: "\<not> dropped sp (key a) (dir a) (idx a)" and ok: "inv_ok sp a"
    and fin: "finish sp f a (hd (insubs sp a)) (label (hd (insubs sp a))) = Halt (Answer (s, p, v))" by blast+
  note fa = finish_answer[OF fin]
  note ok' = ok[unfolded inv_ok_def]
  from live show "live sp a" .
  from nd show "\<not> dropped sp (key a) (dir a) (idx a)" .
  from fa show pv: "p = prop_of sp (key a)" by blast
  from ok' show "\<not> capped a" by blast
  have ne: "insubs sp a \<noteq> []" using ok' by blast
  have hin: "hd (insubs sp a) \<in> set (insubs sp a)" by (rule hd_in_set[OF ne])
  have sq: "s = qid (hd (insubs sp a))" and vq: "v = label (hd (insubs sp a))" using fa by blast+
  let ?c = "hd (insubs sp a)"
  have c1: "?c \<in> set (subjects a)" and c2: "domain_member sp ?c" using hin by simp_all
  have l1: "label ?c \<noteq> Blank" and l2: "label (hd (candidates a)) \<noteq> Blank" using ok' by blast+
  have allr: "\<forall>c \<in> set (insubs sp a). (prop_of sp (key a), label (hd (candidates a))) \<in> set (rows c)"
    using ok' by blast
  have r1: "(p, label (hd (candidates a))) \<in> set (rows ?c)" using allr hin pv by blast
  have g1: "\<not> (guard sp \<and> pron ?c)" using fa by blast
  have q1: "qid ?c = s" using sq by simp
  have v1: "label ?c = v" and v2: "v \<noteq> Blank" using vq l1 by simp_all
  show "\<exists>c \<in> set (subjects a). domain_member sp c \<and> qid c = s \<and> label c = v \<and> v \<noteq> Blank \<and>
        (p, label (hd (candidates a))) \<in> set (rows c) \<and> label (hd (candidates a)) \<noteq> Blank \<and>
        \<not> (guard sp \<and> pron c)"
    using c1 c2 q1 v1 v2 r1 l2 g1 by blast
  have allq: "\<forall>c \<in> set (insubs sp a). qid c = qid ?c" using ok' by blast
  show "\<forall>c \<in> set (subjects a). domain_member sp c \<longrightarrow> qid c = s"
  proof (intro ballI impI)
    fix c assume "c \<in> set (subjects a)" and "domain_member sp c"
    then have "c \<in> set (insubs sp a)" by simp
    with allq q1 show "qid c = s" by simp
  qed
  from fa vq show "\<not> restates f v" by blast
  from fa show "p \<notin> set time_variant \<or> \<not> past f" by blast
qed

section \<open>The receipts\<close>

text \<open>An answer comes from one matched phrasing of a reader in this specialist's table, and names
that reader's property. A forward answer names a linked in-domain sense whose stored rows hold that
very value; every in-domain sense the shipped rule selects holds exactly that value, and so does every
LINKED in-domain sense that holds any value of the property at all. An inverse answer names the one
in-domain subject the fetch found holding the top sense as a value.\<close>

theorem answer_stored:
  assumes ans: "decide_spec sp f attempts = Answer (s, p, v)"
  shows "\<exists>a r. a \<in> set attempts \<and> attempt_values sp f a = Some (s, p, v) \<and>
          r \<in> set (readers sp) \<and> rkey r = key a \<and> p = rprop r \<and> slot_ok a \<and> \<not> restates f v \<and>
          (dir a = Fwd \<longrightarrow>
             (\<exists>c. c \<in> set (mineof sp a) \<and> qid c = s \<and> dom_complete c \<and>
                (\<forall>c' \<in> set (candidates a). complete c') \<and>
                (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and>
                (\<forall>c' \<in> set (mineof sp a). set (vals p c') = {v}) \<and>
                (\<forall>c' \<in> set (candidates a). domain_member sp c' \<and> vals p c' \<noteq> [] \<longrightarrow> set (vals p c') = {v}))) \<and>
          (dir a = Inv \<longrightarrow>
             (\<exists>c \<in> set (subjects a). domain_member sp c \<and> qid c = s \<and> label c = v \<and> v \<noteq> Blank \<and>
                (p, label (hd (candidates a))) \<in> set (rows c) \<and>
                (\<forall>c' \<in> set (subjects a). domain_member sp c' \<longrightarrow> qid c' = s)))"
proof -
  from ans have "walk sp f attempts None = Answer (s, p, v)"
    by (cases "kind_conflict f") (simp_all add: decide_spec_def)
  then obtain a where a: "a \<in> set attempts" and av: "attempt_values sp f a = Some (s, p, v)"
    using walk_answer_exists[rule_format] by meson
  show ?thesis
  proof (cases "dir a")
    case Fwd
    note S = attempt_values_sound[OF av Fwd]
    have live: "live sp a" by (rule S(1))
    have it: "in_table sp (key a) (dir a) (idx a)" using live by (simp add: live_def)
    from in_table_reader[OF it] obtain r where r: "r \<in> set (readers sp)" "rkey r = key a" "prop_of sp (key a) = rprop r"
      by blast
    have pv: "p = rprop r" using S(3) r(3) by simp
    have hin: "hd (mineof sp a) \<in> set (mineof sp a)" by (rule hd_in_set[OF S(4)])
    have dc: "dom_complete (hd (mineof sp a))" using S(6) by (simp add: domain_member_def)
    let ?c = "hd (mineof sp a)"
    have q: "qid ?c = s" using S(5) by simp
    have F: "\<exists>c. c \<in> set (mineof sp a) \<and> qid c = s \<and> dom_complete c \<and>
                (\<forall>c' \<in> set (candidates a). complete c') \<and>
                (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and>
                (\<forall>c' \<in> set (mineof sp a). set (vals p c') = {v}) \<and>
                (\<forall>c' \<in> set (candidates a). domain_member sp c' \<and> vals p c' \<noteq> [] \<longrightarrow> set (vals p c') = {v})"
      using hin q dc S(7) S(10) S(11) S(8) S(9) by blast
    have so: "slot_ok a" using live by (simp add: live_def)
    have I: "dir a = Inv \<longrightarrow>
             (\<exists>c \<in> set (subjects a). domain_member sp c \<and> qid c = s \<and> label c = v \<and> v \<noteq> Blank \<and>
                (p, label (hd (candidates a))) \<in> set (rows c) \<and>
                (\<forall>c' \<in> set (subjects a). domain_member sp c' \<longrightarrow> qid c' = s))" using Fwd by simp
    have Fi: "dir a = Fwd \<longrightarrow>
             (\<exists>c. c \<in> set (mineof sp a) \<and> qid c = s \<and> dom_complete c \<and>
                (\<forall>c' \<in> set (candidates a). complete c') \<and>
                (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and>
                (\<forall>c' \<in> set (mineof sp a). set (vals p c') = {v}) \<and>
                (\<forall>c' \<in> set (candidates a). domain_member sp c' \<and> vals p c' \<noteq> [] \<longrightarrow> set (vals p c') = {v}))"
      using F by blast
    have rk: "rkey r = key a" using r(2) .
    show ?thesis using a av r(1) rk pv so S(12) Fi I by blast
  next
    case Inv
    note S = attempt_values_sound_inv[OF av Inv]
    have live: "live sp a" by (rule S(1))
    have it: "in_table sp (key a) (dir a) (idx a)" using live by (simp add: live_def)
    from in_table_reader[OF it] obtain r where r: "r \<in> set (readers sp)" "rkey r = key a" "prop_of sp (key a) = rprop r"
      by blast
    have pv: "p = rprop r" using S(3) r(3) by simp
    from S(5) obtain c where c: "c \<in> set (subjects a)" "domain_member sp c" "qid c = s" "label c = v"
      "v \<noteq> Blank" "(p, label (hd (candidates a))) \<in> set (rows c)" by blast
    have so: "slot_ok a" using live by (simp add: live_def)
    have I: "dir a = Inv \<longrightarrow>
             (\<exists>c \<in> set (subjects a). domain_member sp c \<and> qid c = s \<and> label c = v \<and> v \<noteq> Blank \<and>
                (p, label (hd (candidates a))) \<in> set (rows c) \<and>
                (\<forall>c' \<in> set (subjects a). domain_member sp c' \<longrightarrow> qid c' = s))"
      using c S(6) by blast
    have Fi: "dir a = Fwd \<longrightarrow>
             (\<exists>c. c \<in> set (mineof sp a) \<and> qid c = s \<and> dom_complete c \<and>
                (\<forall>c' \<in> set (candidates a). complete c') \<and>
                (p, v) \<in> set (rows c) \<and> v \<noteq> Blank \<and>
                (\<forall>c' \<in> set (mineof sp a). set (vals p c') = {v}) \<and>
                (\<forall>c' \<in> set (candidates a). domain_member sp c' \<and> vals p c' \<noteq> [] \<longrightarrow> set (vals p c') = {v}))"
      using Inv by simp
    have rk: "rkey r = key a" using r(2) .
    show ?thesis using a av r(1) rk pv so S(7) Fi I by blast
  qed
qed

text \<open>A decline names a reader of this specialist's table, its property, and a linked in-domain
sense of a matched forward phrasing: recognise-then-decline, never a refusal about something the
specialist did not read.\<close>

theorem decline_stored:
  assumes dec: "decide_spec sp f attempts = Decline (p, s)"
  shows "\<exists>a c r. a \<in> set attempts \<and> dir a = Fwd \<and> in_table sp (key a) Fwd (idx a) \<and> slot_ok a \<and>
          r \<in> set (readers sp) \<and> rkey r = key a \<and> p = rprop r \<and>
          c \<in> set (candidates a) \<and> qid c = s \<and> domain_member sp c \<and> \<not> (guard sp \<and> pron c)"
proof -
  from decline_meaning(2)[OF dec] obtain a pr where a: "a \<in> set attempts"
    and ad: "attempt_decline sp f a (p, s, pr)" and ng: "\<not> (guard sp \<and> pr)" by blast
  have st: "step sp f a = Cont (Some (p, s, pr))" using ad by (simp add: attempt_decline_def)
  have g: "live sp a \<and> dir a = Fwd \<and>
      (\<exists>c \<in> set (candidates a). p = prop_of sp (key a) \<and> s = qid c \<and> pr = pron c \<and> domain_member sp c)"
  proof -
    have lv: "live sp a" using st by (auto simp: step_def split: if_splits)
    then have ne: "candidates a \<noteq> []" by (simp add: live_def)
    have hs: "hd (selof a) \<in> set (candidates a)"
      using hd_in_set[OF select_nonempty[OF ne]] select_subset by blast
    show ?thesis
    proof (cases "dropped sp (key a) (dir a) (idx a)")
      case True
      with st lv have "dir a = Fwd \<and> domain_member sp (hd (selof a)) \<and>
          p = prop_of sp (key a) \<and> s = qid (hd (selof a)) \<and> pr = pron (hd (selof a))"
        by (auto simp: step_def split: if_splits)
      with lv hs show ?thesis by blast
    next
      case False
      have fw: "dir a = Fwd"
        using st lv False finish_not_cont by (cases "dir a") (auto simp: step_def split: if_splits)
      with st lv False have m: "mineof sp a \<noteq> [] \<and> p = prop_of sp (key a) \<and>
          s = qid (hd (mineof sp a)) \<and> pr = pron (hd (mineof sp a))"
        using finish_not_cont by (auto simp: step_def split: if_splits)
      then have hm: "hd (mineof sp a) \<in> set (mineof sp a)" using hd_in_set by blast
      then have "hd (mineof sp a) \<in> set (candidates a) \<and> domain_member sp (hd (mineof sp a))"
        by (rule mine_in_candidates)
      with lv fw m show ?thesis by blast
    qed
  qed
  then obtain c where c: "c \<in> set (candidates a)" "p = prop_of sp (key a)" "s = qid c" "pr = pron c"
    "domain_member sp c" and lv: "live sp a" and fw: "dir a = Fwd" by blast
  from lv fw have it: "in_table sp (key a) Fwd (idx a)" and so: "slot_ok a" by (auto simp: live_def)
  from in_table_reader[OF it] obtain r where r: "r \<in> set (readers sp)" "rkey r = key a"
    "prop_of sp (key a) = rprop r" by blast
  show ?thesis
    using a fw it so r c ng by (intro exI[where x = a] exI[where x = c] exI[where x = r]) auto
qed

text \<open>The new rule, stated on its own: when two linked in-domain senses of a forward phrasing both
hold stored values of the asked property and the values differ, that phrasing never answers; when the
shipped selection kept an in-domain sense, the phrasing marks a decline about it (and the turn declines
unless a later phrasing answers, or the pronoun guard applies).\<close>

theorem disagreeing_senses_never_answer:
  assumes fw: "dir a = Fwd"
    and c1: "c1 \<in> set (candidates a)" and c2: "c2 \<in> set (candidates a)"
    and d1: "domain_member sp c1" and d2: "domain_member sp c2"
    and n1: "vals (prop_of sp (key a)) c1 \<noteq> []" and n2: "vals (prop_of sp (key a)) c2 \<noteq> []"
    and differ: "set (vals (prop_of sp (key a)) c1) \<noteq> set (vals (prop_of sp (key a)) c2)"
  shows "attempt_values sp f a = None"
    and "live sp a \<Longrightarrow> \<not> dropped sp (key a) (dir a) (idx a) \<Longrightarrow> allc a \<Longrightarrow> mineof sp a \<noteq> [] \<Longrightarrow>
         attempt_decline sp f a (prop_of sp (key a), qid (hd (mineof sp a)), pron (hd (mineof sp a)))"
proof -
  have npa: "\<not> pool_agrees sp a"
  proof
    assume pa: "pool_agrees sp a"
    from c1 d1 have "c1 \<in> set (poolof sp a)" by simp
    with pa n1 have e1: "set (vals (prop_of sp (key a)) c1) = set (hd (vsof sp a))" by (simp add: pool_agrees_def)
    from c2 d2 have "c2 \<in> set (poolof sp a)" by simp
    with pa n2 have e2: "set (vals (prop_of sp (key a)) c2) = set (hd (vsof sp a))" by (simp add: pool_agrees_def)
    from e1 e2 differ show False by simp
  qed
  show "attempt_values sp f a = None"
  proof (rule ccontr)
    assume "attempt_values sp f a \<noteq> None"
    then obtain s p v where "attempt_values sp f a = Some (s, p, v)" by (cases "attempt_values sp f a") auto
    then have "step sp f a = Halt (Answer (s, p, v))" by (simp add: attempt_values_iff)
    from step_fwd_answer[OF this fw] npa show False by blast
  qed
  show "live sp a \<Longrightarrow> \<not> dropped sp (key a) (dir a) (idx a) \<Longrightarrow> allc a \<Longrightarrow> mineof sp a \<noteq> [] \<Longrightarrow>
         attempt_decline sp f a (prop_of sp (key a), qid (hd (mineof sp a)), pron (hd (mineof sp a)))"
    using fw npa by (simp add: attempt_decline_def step_def)
qed

text \<open>And at the level of the whole turn: an answer never comes from a phrasing whose linked
in-domain senses disagree.\<close>

corollary answer_senses_agree:
  assumes "decide_spec sp f attempts = Answer (s, p, v)"
  shows "\<exists>a \<in> set attempts. attempt_values sp f a = Some (s, p, v) \<and>
    (dir a = Fwd \<longrightarrow> (\<forall>c1 \<in> set (candidates a). \<forall>c2 \<in> set (candidates a).
       domain_member sp c1 \<and> domain_member sp c2 \<and> vals p c1 \<noteq> [] \<and> vals p c2 \<noteq> [] \<longrightarrow>
       set (vals p c1) = set (vals p c2)))"
proof -
  from answer_stored[OF assms] obtain a r where a: "a \<in> set attempts" and av: "attempt_values sp f a = Some (s, p, v)"
    and fw: "dir a = Fwd \<longrightarrow> (\<forall>c' \<in> set (candidates a). domain_member sp c' \<and> vals p c' \<noteq> [] \<longrightarrow> set (vals p c') = {v})"
    by blast
  show ?thesis using a av fw by (intro bexI[where x = a]) auto
qed

text \<open>The decision is a function of its evidence (a HOL function), and the turn's answer, if any, is
the answer of the first attempt that halts.\<close>

lemma walk_first_halt:
  "step sp f a = Halt r \<Longrightarrow> walk sp f (a # rest) acc = r"
  by simp

end
