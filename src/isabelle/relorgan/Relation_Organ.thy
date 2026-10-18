theory Relation_Organ
  imports "HOL-Library.Code_Target_Numeral"
begin

text \<open>The shared decision of Oracle7's 161 relation specialists (RelationOrganV2 and its pronoun-guard
subclass RelationOrganV2G), ported statement-for-statement from @{text relation_spec_v2.answer} (the
hand-written readers) and @{text relation_spec_v1.answer} (the mined-pattern fallback). One decision
theory; every specialist is a table: its reader keys, dropped phrasings, domain flags, mined patterns.

What stays outside HOL, by the same cut as the exact router (src/isabelle/reader/Relation_Reader.thy):
the question regexes (which phrasing matched the whole question, the slot text it captured, the mined
pattern features), the entity linker (the candidates a slot names, their link counts), the store fetch
(the rows and the inverse holders), domain membership (a P31/P279 closure over fetched classes), and
rendering. Their results arrive as data. The decision - which candidates count, when they must agree,
when the organ declines in domain instead of staying silent, when a restating or time-variant answer is
silenced - is the function below, and the theorems say what an answer means about that data.

Two deliberate differences from the shipped organ, both safety-positive and both marked:
an incomplete fetch (a candidate whose rows are not everything the store holds for it) never answers
(the shipped code has no completeness notion - a store problem is an exception, and silence);
and the pronoun guard is a per-turn flag rather than a second class.\<close>

datatype direction = Fwd | Inv

datatype organ_result =
  Answered natural String.literal natural String.literal    \<comment> \<open>property, value display, subject, pattern\<close>
| Withheld natural natural String.literal                   \<comment> \<open>property, subject, pattern\<close>
| Silence

record cand =
  qid :: natural
  links :: natural
  indomain :: bool          \<comment> \<open>the domain oracle's claim for the stage that reads this candidate\<close>
  complete :: bool          \<comment> \<open>the fetch's claim: rows hold every stored fact of this entity\<close>
  rows :: "(natural \<times> String.literal) list"   \<comment> \<open>(property, display string); no blank or empty displays\<close>

record attempt =
  key :: String.literal     \<comment> \<open>the readers.json key, verbatim\<close>
  idx :: natural
  dir :: direction
  patk :: String.literal    \<comment> \<open>key|direction|idx, for receipts\<close>
  slot_len :: natural       \<comment> \<open>length in characters of the captured slot text\<close>
  cands :: "cand list"      \<comment> \<open>linker candidates for the slot, link-count order\<close>
  inv_subs :: "(natural \<times> bool \<times> String.literal) list"  \<comment> \<open>holders of (property, top candidate): qid, in-domain, label\<close>
  inv_capped :: bool        \<comment> \<open>the holders query hit its LIMIT 8\<close>

record turn =
  attempts :: "attempt list"        \<comment> \<open>the phrasing matches, in the organ's iteration order\<close>
  kind_conflict :: bool
  past :: bool
  qwords :: "String.literal list"           \<comment> \<open>normalized words of the question\<close>
  value_words :: "(String.literal \<times> String.literal list) list"  \<comment> \<open>per value: its non-stop words\<close>
  dropped :: "(String.literal \<times> direction \<times> natural) list"
  props :: "(String.literal \<times> natural) list"              \<comment> \<open>reader key -> property\<close>
  time_variant :: "natural list"
  feats :: "(String.literal \<times> String.literal) list"       \<comment> \<open>the mined-pattern features of the question\<close>
  patterns :: "((direction \<times> String.literal \<times> String.literal) \<times> natural) list"
  pat_cands :: "cand list"                  \<comment> \<open>analyse(): the linked span's candidates\<close>
  pat_inv :: "((direction \<times> natural) \<times> ((natural \<times> bool \<times> String.literal) list \<times> bool)) list"
    \<comment> \<open>holders of (property, top pattern candidate): subs and the LIMIT-8 cap\<close>
  pats :: "((direction \<times> natural) \<times> String.literal) list"
    \<comment> \<open>the pattern id of (direction, property): the first sorted key that names it\<close>
  pronoun_guard :: bool
  pron_subj :: "(natural \<times> String.literal \<times> bool \<times> bool) list"
    \<comment> \<open>per possible subject: qid, lowercase label, label appears lowercased in the question,
        title-cased label appears in the question\<close>

section \<open>The reader stage (relation_spec_v2.answer)\<close>

definition prop_of_key :: "turn \<Rightarrow> String.literal \<Rightarrow> natural" where
  "prop_of_key t k = (case map_of (props t) k of None \<Rightarrow> 0 | Some p \<Rightarrow> p)"

definition vals :: "natural \<Rightarrow> cand \<Rightarrow> String.literal list" where
  "vals P c = remdups (map snd (filter (\<lambda>(p, _). p = P) (rows c)))"

definition restates :: "turn \<Rightarrow> String.literal \<Rightarrow> bool" where
  "restates t v = (case map_of (value_words t) v of
      Some ws \<Rightarrow> ws \<noteq> [] \<and> set ws \<subseteq> set (qwords t) | None \<Rightarrow> False)"

text \<open>The linker's popularity rule (DOMINANCE = 10 in entity_linker_v2): a top sense linked ten
times more than every other collapses the candidate list to itself.\<close>
definition dominated :: "cand list \<Rightarrow> bool" where
  "dominated cs = (case cs of c # rest \<Rightarrow> rest \<noteq> [] \<and>
      10 * max 1 (fold max (map links rest) 0) \<le> links c | [] \<Rightarrow> False)"

definition select_dom :: "cand list \<Rightarrow> cand list" where
  "select_dom cs = (if dominated cs then [hd cs] else cs)"

text \<open>Forward: the first three candidates that are in the domain (the shipped code filters in
domain AFTER cutting to three - it never reaches past the third sense).\<close>
definition mine3 :: "cand list \<Rightarrow> cand list" where
  "mine3 cs = filter indomain (take 3 cs)"

text \<open>The agreement rule: all in-domain candidates must name exactly one shared stored value.
The last line (no answer from an incomplete fetch) is the veri7vn addition. Written without
@{const Let}: a let-bound if-chain defeats every splitter (auto, simp, force alike).\<close>
definition agree :: "natural \<Rightarrow> cand list \<Rightarrow> (String.literal \<times> natural) option" where
  "agree P cs =
     (if mine3 cs = [] then None
      else if \<exists>x \<in> set (map (vals P) (mine3 cs)). x = [] then None
      else if length (remdups (map (vals P) (mine3 cs))) \<noteq> 1 then None
      else if length (hd (map (vals P) (mine3 cs))) \<noteq> 1 then None
      else if \<exists>c \<in> set (mine3 cs). \<not> complete c then None
      else Some (hd (hd (map (vals P) (mine3 cs))), qid (hd (mine3 cs))))"

text \<open>Inverse: the slot names the value; exactly one in-domain entity holds (property, it), within
the first eight holders, and that entity has a label.\<close>
definition inv_read :: "(natural \<times> bool \<times> String.literal) list \<Rightarrow> bool \<Rightarrow> (String.literal \<times> natural) option" where
  "inv_read subs capped =
     (if capped \<or> subs = [] then None
      else if length (filter (\<lambda>(_, d, _). d) subs) \<noteq> 1 then None
      else case hd (filter (\<lambda>(_, d, _). d) subs) of (s, _, lab) \<Rightarrow>
       if lab = STR '''' then None else Some (lab, s))"

definition finish :: "turn \<Rightarrow> natural \<Rightarrow> String.literal \<Rightarrow> natural \<Rightarrow> String.literal \<Rightarrow> organ_result" where
  "finish t P v s pat =
     (if restates t v then Silence
      else if P \<in> set (time_variant t) \<and> past t then Silence
      else Answered P v s pat)"

text \<open>The walk over phrasing matches, carrying the first in-domain decline (recognise-then-decline:
a forward relation question about an in-domain entity that this organ cannot read reliably is declined
in domain rather than left to a weaker route). A restating or past time-variant answer aborts the whole
stage to silence - the decline is discarded, exactly as shipped.\<close>
fun walk :: "turn \<Rightarrow> attempt list \<Rightarrow> (natural \<times> natural \<times> String.literal) option \<Rightarrow> organ_result" where
  "walk t [] dn = (case dn of Some (P, s, pat) \<Rightarrow> Withheld P s pat | None \<Rightarrow> Silence)"
| "walk t (a # as) dn =
     (if 2 \<le> slot_len a then
        (if cands a = [] then walk t as dn
         else if (key a, dir a, idx a) \<in> set (dropped t) then
           (if dir a = Fwd \<and> dn = None \<and> indomain (hd (select_dom (cands a)))
            then walk t as (Some (prop_of_key t (key a), qid (hd (select_dom (cands a))), patk a))
            else walk t as dn)
         else case dir a of
           Fwd \<Rightarrow> (case agree (prop_of_key t (key a)) (select_dom (cands a)) of
                     Some (v, s) \<Rightarrow> finish t (prop_of_key t (key a)) v s (patk a)
                   | None \<Rightarrow> if mine3 (select_dom (cands a)) \<noteq> [] \<and> dn = None
                              then walk t as (Some (prop_of_key t (key a),
                                              qid (hd (mine3 (select_dom (cands a)))), patk a))
                              else walk t as dn)
           | Inv \<Rightarrow> (case inv_read (inv_subs a) (inv_capped a) of
                       Some (v, s) \<Rightarrow> finish t (prop_of_key t (key a)) v s (patk a)
                     | None \<Rightarrow> walk t as dn))
      else walk t as dn)"

section \<open>The pattern stage (relation_spec_v1.answer)\<close>

text \<open>The mined patterns that fire on the question's feature pairs, per direction; a direction is
readable only when they name exactly one property.\<close>
definition fired :: "turn \<Rightarrow> direction \<Rightarrow> natural list" where
  "fired t d = remdups [p. (f1, f2) \<leftarrow> feats t, ((d', g1, g2), p) \<leftarrow> patterns t, d' = d, g1 = f1, g2 = f2]"

definition pat_inv_read :: "turn \<Rightarrow> natural \<Rightarrow> (String.literal \<times> natural) option" where
  "pat_inv_read t P = (case map_of (pat_inv t) (Inv, P) of
      None \<Rightarrow> None    \<comment> \<open>no holders fetched for this property: silence, never a guess\<close>
    | Some (subs, capped) \<Rightarrow> inv_read subs capped)"

datatype stage_res = Continue | Stop organ_result

definition pat_id :: "turn \<Rightarrow> direction \<Rightarrow> natural \<Rightarrow> String.literal" where
  "pat_id t d P = (case map_of (pats t) (d, P) of None \<Rightarrow> STR '''' | Some i \<Rightarrow> i)"

definition try_stage :: "turn \<Rightarrow> direction \<Rightarrow> stage_res" where
  "try_stage t d =
     (case fired t d of
        [P] \<Rightarrow> if P \<in> set (time_variant t) \<and> past t then Stop Silence
                else (case d of
                        Fwd \<Rightarrow> (case agree P (pat_cands t) of
                                  Some (v, s) \<Rightarrow> Stop (finish t P v s (pat_id t d P))
                                | None \<Rightarrow> Continue)
                      | Inv \<Rightarrow> (case pat_inv_read t P of
                                  Some (v, s) \<Rightarrow> Stop (finish t P v s (pat_id t d P))
                                | None \<Rightarrow> Continue))
      | _ \<Rightarrow> Continue)"

definition pattern_decide :: "turn \<Rightarrow> organ_result" where
  "pattern_decide t =
     (case try_stage t Fwd of
        Continue \<Rightarrow> (case try_stage t Inv of Continue \<Rightarrow> Silence | Stop r \<Rightarrow> r)
      | Stop r \<Rightarrow> r)"

section \<open>The organ: readers first, patterns as fallback, then the pronoun guard\<close>

definition pronouns :: "String.literal list" where
  "pronouns = [STR ''you'', STR ''me'', STR ''it'', STR ''this'', STR ''that'', STR ''them'',
               STR ''him'', STR ''her'', STR ''us'', STR ''they'', STR ''we'', STR ''i'',
               STR ''he'', STR ''she'', STR ''these'', STR ''those'', STR ''one'']"

definition guard_drops :: "turn \<Rightarrow> natural \<Rightarrow> bool" where
  "guard_drops t s = (case map_of (pron_subj t) s of
      Some (lab, low_in, title_in) \<Rightarrow> lab \<in> set pronouns \<and> low_in \<and> \<not> title_in
    | None \<Rightarrow> False)"

definition guard :: "turn \<Rightarrow> organ_result \<Rightarrow> organ_result" where
  "guard t r =
     (if \<not> pronoun_guard t then r
      else case r of
        Answered P v s pat \<Rightarrow> if guard_drops t s then Silence else r
      | Withheld P s pat \<Rightarrow> if guard_drops t s then Silence else r
      | Silence \<Rightarrow> Silence)"

lemma guard_Silence [simp]: "guard t Silence = Silence"
  by (cases "pronoun_guard t") (simp_all add: guard_def)

definition organ_decide :: "turn \<Rightarrow> organ_result" where
  "organ_decide t =
     (if kind_conflict t then Silence
      else guard t (case walk t (attempts t) None of
                      Silence \<Rightarrow> if patterns t = [] then Silence else pattern_decide t
                    | r \<Rightarrow> r))"

section \<open>What an answer means\<close>

lemma set_vals: "set (vals P c) = {v. (P, v) \<in> set (rows c)}"
  by (force simp: vals_def)

lemma select_dom_cons: "cs \<noteq> [] \<Longrightarrow> select_dom cs = cs \<or> select_dom cs = [hd cs]"
  by (cases cs; simp add: select_dom_def split: if_splits)

lemma hd_select_dom: assumes "cs \<noteq> []" shows "hd (select_dom cs) = hd cs"
  using select_dom_cons [OF assms] by auto

lemma set_select_dom: "set (select_dom cs) \<subseteq> set cs"
  by (cases cs; auto simp: select_dom_def dominated_def split: if_splits)

lemma mine3_props: "set (mine3 cs) \<subseteq> set cs" "length (mine3 cs) \<le> 3"
  "\<And>c. c \<in> set (mine3 cs) \<Longrightarrow> indomain c"
proof -
  show "set (mine3 cs) \<subseteq> set cs"
    unfolding mine3_def by (auto dest: set_take_subset [THEN subsetD])
  have "length (filter indomain (take 3 cs)) \<le> length (take 3 cs)" by (rule length_filter_le)
  moreover have "length (take 3 cs) \<le> 3" by (simp add: min_def)
  ultimately show "length (mine3 cs) \<le> 3" unfolding mine3_def by linarith
  show "\<And>c. c \<in> set (mine3 cs) \<Longrightarrow> indomain c" unfolding mine3_def by auto
qed

lemma remdups_len1:
  assumes "length (remdups xs) = 1"
  shows "\<forall>y \<in> set xs. y = hd xs"
proof -
  obtain z where rz: "remdups xs = [z]" using assms by (cases "remdups xs") auto
  then have z1: "set (remdups xs) = {z}" by simp
  then have sx: "set xs = {z}" by (simp add: set_remdups)
  then have "xs \<noteq> []" by auto
  then have "hd xs \<in> set xs" by (cases xs) simp_all
  with sx have "hd xs = z" by auto
  with sx show ?thesis by auto
qed

lemma agree_Some:
  assumes "agree P cs = Some (v, s)"
  shows "mine3 cs \<noteq> []"
    and "s = qid (hd (mine3 cs))"
    and "\<And>c. c \<in> set (mine3 cs) \<Longrightarrow> vals P c = [v]"
    and "\<And>c. c \<in> set (mine3 cs) \<Longrightarrow> complete c"
proof -
  let ?sets = "map (vals P) (mine3 cs)"
  have m: "mine3 cs \<noteq> []"
    using assms by (cases "mine3 cs = []") (simp_all add: agree_def)
  from assms m have step1:
    "(if \<exists>x \<in> set ?sets. x = [] then None
      else if length (remdups ?sets) \<noteq> 1 then None
      else if length (hd ?sets) \<noteq> 1 then None
      else if \<exists>c \<in> set (mine3 cs). \<not> complete c then None
      else Some (hd (hd ?sets), qid (hd (mine3 cs)))) = Some (v, s)"
    by (simp add: agree_def)
  from step1 have nz: "\<not> (\<exists>x \<in> set ?sets. x = [])"
    by (cases "\<exists>x \<in> set ?sets. x = []") simp_all
  from step1 nz have len1: "length (remdups ?sets) = 1"
    by (cases "length (remdups ?sets) = 1") simp_all
  from step1 nz len1 have hd1: "length (hd ?sets) = 1"
    by (cases "length (hd ?sets) = 1") simp_all
  from step1 nz len1 hd1 have ncomp: "\<not> (\<exists>c \<in> set (mine3 cs). \<not> complete c)"
    by (cases "\<exists>c \<in> set (mine3 cs). \<not> complete c") simp_all
  from step1 nz len1 hd1 ncomp have pair: "v = hd (hd ?sets)"
    and s: "s = qid (hd (mine3 cs))"
    by simp_all
  from len1 have all_eq: "\<forall>y \<in> set ?sets. y = hd ?sets"
    by (rule remdups_len1)
  have hdv: "vals P (hd (mine3 cs)) = hd ?sets"
  proof -
    have "hd (mine3 cs) \<in> set (mine3 cs)" using m by (cases "mine3 cs") simp_all
    then have "vals P (hd (mine3 cs)) \<in> set ?sets" by force
    then show ?thesis using all_eq by blast
  qed
  have hds: "vals P (hd (mine3 cs)) = [v]"
    using hd1 pair hdv by (cases "hd ?sets") simp_all
  show "mine3 cs \<noteq> []" by (fact m)
  show "s = qid (hd (mine3 cs))" by (fact s)
  show "\<And>c. c \<in> set (mine3 cs) \<Longrightarrow> vals P c = [v]"
  proof -
    fix c assume c: "c \<in> set (mine3 cs)"
    then have "vals P c \<in> set ?sets" by auto
    with all_eq have "vals P c = hd ?sets" by blast
    with hdv hds show "vals P c = [v]" by metis
  qed
  show "\<And>c. c \<in> set (mine3 cs) \<Longrightarrow> complete c"
    using ncomp by blast
qed

lemma in_filter_imp: "x \<in> set (filter P xs) \<Longrightarrow> P x"
  by simp

lemma inv_read_Some:
  assumes "inv_read subs capped = Some (v, s)"
  shows "\<not> capped" "subs \<noteq> []" "v \<noteq> STR ''''"
    and "length (filter (\<lambda>(_, d, _). d) subs) = 1"
    and "hd (filter (\<lambda>(_, d, _). d) subs) = (s, True, v)"
proof -
  let ?ins = "filter (\<lambda>(_, d, _). d) subs"
  from assms have nc: "\<not> capped" and ne: "subs \<noteq> []"
    by (auto simp: inv_read_def split: if_splits)
  from assms nc ne have step1:
    "(if length ?ins \<noteq> 1 then None
      else case hd ?ins of (s', _, lab) \<Rightarrow>
        if lab = STR '''' then None else Some (lab, s')) = Some (v, s)"
    by (simp add: inv_read_def)
  from step1 have len: "length ?ins = 1"
    by (cases "length ?ins = 1") simp_all
  from step1 len have step2:
    "(case hd ?ins of (s', _, lab) \<Rightarrow>
        if lab = STR '''' then None else Some (lab, s')) = Some (v, s)"
    by simp
  from len have ne2: "?ins \<noteq> []" by (cases ?ins) simp_all
  then have hin: "hd ?ins \<in> set ?ins" by (cases ?ins) simp_all
  obtain p q where pq: "hd ?ins = (p, q)" by (metis surj_pair)
  obtain r u where ru: "q = (r, u)" by (metis surj_pair)
  from in_filter_imp [OF hin] pq ru have r: "r" by simp
  from step2 pq ru have vu:
    "(if u = STR '''' then None else Some (u, p)) = Some (v, s)" by simp
  show "hd ?ins = (s, True, v)"
  proof (cases "u = STR ''''")
    case True
    with vu show ?thesis by simp
  next
    case False
    with vu have "u = v" "p = s" by simp_all
    with pq ru r show ?thesis by simp
  qed
  show "v \<noteq> STR ''''"
  proof (cases "v = STR ''''")
    case True
    with vu show ?thesis by (cases "u = STR ''''") simp_all
  next
    case False
    then show ?thesis by simp
  qed
  show "\<not> capped" by (fact nc)
  show "subs \<noteq> []" by (fact ne)
  show "length ?ins = 1" by (fact len)
qed

lemma finish_Answered:
  assumes "finish t P v s pat = Answered P' v' s' pat'"
  shows "P = P' \<and> v = v' \<and> s = s' \<and> pat = pat' \<and> \<not> restates t v
    \<and> \<not> (P \<in> set (time_variant t) \<and> past t)"
proof (cases "restates t v")
  case True
  with assms show ?thesis by (simp add: finish_def)
next
  case False
  show ?thesis
  proof (cases "P \<in> set (time_variant t) \<and> past t")
    case True
    with False assms show ?thesis by (simp add: finish_def)
  next
    case False
    with \<open>\<not> restates t v\<close> assms show ?thesis by (simp add: finish_def)
  qed
qed

text \<open>The reader stage answers only through an attempt that was not dropped and whose selected
candidates agree (or whose inverse holders reduce to one), with a value that neither restates the
question nor carries a past qualifier on a time-variant property.\<close>
lemma walk_Answered_inv:
  assumes "walk t as dn = Answered P v s pat"
  shows "\<exists>a \<in> set as.
    2 \<le> slot_len a \<and> cands a \<noteq> [] \<and> (key a, dir a, idx a) \<notin> set (dropped t)
    \<and> prop_of_key t (key a) = P \<and> patk a = pat
    \<and> ((dir a = Fwd \<and> agree P (select_dom (cands a)) = Some (v, s))
      \<or> (dir a = Inv \<and> inv_read (inv_subs a) (inv_capped a) = Some (v, s)))
    \<and> \<not> restates t v \<and> \<not> (P \<in> set (time_variant t) \<and> past t)"
  using assms
proof (induct as arbitrary: dn)
  case Nil
  then show ?case by (cases dn; simp_all split: prod.splits)
next
  case (Cons a as)
  then show ?case
    by (simp add: finish_def split: if_splits option.splits direction.splits prod.splits; force)
qed
text \<open>A withhold comes only from a forward attempt about an in-domain entity whose read failed:
a phrasing the natural check dropped, or candidates that could not agree on one value.\<close>
lemma walk_Withheld_inv:
  assumes "walk t as dn = Withheld P s pat"
  shows "dn = Some (P, s, pat)
    \<or> (\<exists>a \<in> set as. 2 \<le> slot_len a \<and> cands a \<noteq> [] \<and> dir a = Fwd
        \<and> prop_of_key t (key a) = P
        \<and> (((key a, Fwd, idx a) \<in> set (dropped t) \<and> indomain (hd (select_dom (cands a)))
              \<and> s = qid (hd (select_dom (cands a))))
          \<or> ((key a, Fwd, idx a) \<notin> set (dropped t)
              \<and> mine3 (select_dom (cands a)) \<noteq> []
              \<and> agree P (select_dom (cands a)) = None
              \<and> s = qid (hd (mine3 (select_dom (cands a)))))))"
  using assms
proof (induct as arbitrary: dn)
  case Nil
  then show ?case by (cases dn; simp_all split: prod.splits)
next
  case (Cons a as)
  then show ?case
    apply (simp add: finish_def split: if_splits option.splits direction.splits prod.splits)
    using Cons(1) by force+
qed


text \<open>A carried decline (dn = Some) is never overwritten (the walk records one only when
dn = None); the walk ends in that withhold, an answer, or a silencing restated or past
time-variant answer.\<close>
lemma walk_Some_open:
  "walk t as (Some (P, s, pat)) = Withheld P s pat
    \<or> (\<exists>P' v' s' pat'. walk t as (Some (P, s, pat)) = Answered P' v' s' pat')
    \<or> walk t as (Some (P, s, pat)) = Silence"
  by (induct as arbitrary: P s pat)
     (auto simp: finish_def split: if_splits option.splits direction.splits prod.splits)

text \<open>Appending attempts never rewrites an answer the walk already gave.\<close>
lemma walk_append_Answered:
  assumes "walk t as dn = Answered P v s pat"
  shows "walk t (as @ as') dn = Answered P v s pat"
  using assms
proof (induct as arbitrary: dn)
  case Nil
  then show ?case by (cases dn; simp_all split: prod.splits)
next
  case (Cons a as)
  then show ?case
    apply (simp add: finish_def split: if_splits option.splits direction.splits prod.splits)
    using Cons(1) by force+
qed

text \<open>A withhold stays a withhold or becomes an answer when later attempts carry one, unless a
restating or past time-variant answer silences the walk.\<close>
lemma walk_append_Withheld:
  assumes "walk t as dn = Withheld P s pat"
  shows "walk t (as @ as') dn = Withheld P s pat
    \<or> (\<exists>P' v' s' pat'. walk t (as @ as') dn = Answered P' v' s' pat')
    \<or> walk t (as @ as') dn = Silence"
  using assms
proof (induct as arbitrary: dn)
  case Nil
  then show ?case
  proof (cases dn)
    case None
    with Nil show ?thesis by simp
  next
    case (Some a)
    from Nil(1) Some have eq: "(case a of (P0, s0, pat0) \<Rightarrow> Withheld P0 s0 pat0) = Withheld P s pat"
      by simp
    from eq have aeq: "a = (P, s, pat)" by (auto split: prod.splits)
    from aeq Some have dns: "dn = Some (P, s, pat)" by simp
    from dns show ?thesis using walk_Some_open [of t as' P s pat] by simp
  qed
next
  case (Cons a as)
  then show ?case
    apply (simp add: finish_def split: if_splits option.splits direction.splits prod.splits)
    using Cons(1) by blast+
qed

lemma try_stage_Stop_Answered_inv:
  assumes "try_stage t d = Stop (Answered P v s pid)"
  shows "fired t d = [P] \<and> pat_id t d P = pid \<and> \<not> restates t v
    \<and> \<not> (P \<in> set (time_variant t) \<and> past t)
    \<and> ((d = Fwd \<and> agree P (pat_cands t) = Some (v, s))
      \<or> (d = Inv \<and> pat_inv_read t P = Some (v, s)))"
proof (cases "fired t d")
  case Nil
  with assms show ?thesis by (simp add: try_stage_def)
next
  case (Cons x xs)
  show ?thesis
  proof (cases xs)
    case Nil
    with Cons have f1: "fired t d = [x]" by simp
    show ?thesis
    proof (cases "x \<in> set (time_variant t) \<and> past t")
      case True
      with assms f1 show ?thesis by (simp add: try_stage_def)
    next
      case False
      note notv = False
      have cfalse: "(x \<in> set (time_variant t) \<and> past t) = False"
        using notv by (cases "x \<in> set (time_variant t)"; cases "past t") simp_all
      show ?thesis
      proof (cases d)
        case Fwd
        show ?thesis
        proof (cases "agree x (pat_cands t)")
          case None
          with assms f1 cfalse Fwd show ?thesis
            by (auto simp: try_stage_def split: list.splits option.splits if_splits)
        next
          case (Some r)
          then obtain v' s' where r: "r = (v', s')" by (cases r)
          from assms f1 cfalse Fwd Some r have
            fin: "finish t x v' s' (pat_id t Fwd x) = Answered P v s pid"
            by (auto simp: try_stage_def split: list.splits option.splits if_splits)
          from finish_Answered[OF fin] have
            inj: "x = P \<and> v' = v \<and> s' = s \<and> pat_id t Fwd x = pid
              \<and> \<not> restates t v' \<and> \<not> (x \<in> set (time_variant t) \<and> past t)"
            by auto
          with f1 Fwd Some r show ?thesis by (simp; metis)
        qed
      next
        case Inv
        show ?thesis
        proof (cases "pat_inv_read t x")
          case None
          with assms f1 cfalse Inv show ?thesis
            by (auto simp: try_stage_def split: list.splits option.splits if_splits)
        next
          case (Some r)
          then obtain v' s' where r: "r = (v', s')" by (cases r)
          from assms f1 cfalse Inv Some r have
            fin: "finish t x v' s' (pat_id t Inv x) = Answered P v s pid"
            by (auto simp: try_stage_def split: list.splits option.splits if_splits)
          from finish_Answered[OF fin] have
            inj: "x = P \<and> v' = v \<and> s' = s \<and> pat_id t Inv x = pid
              \<and> \<not> restates t v' \<and> \<not> (x \<in> set (time_variant t) \<and> past t)"
            by auto
          with f1 Inv Some r show ?thesis by (simp; metis)
        qed
      qed
    qed
  next
    case (Cons y ys)
    with assms \<open>fired t d = x # xs\<close> show ?thesis by (simp add: try_stage_def)
  qed
qed

lemma pattern_decide_Answered_inv:
  assumes "pattern_decide t = Answered P v s pid"
  shows "\<exists>d. try_stage t d = Stop (Answered P v s pid) \<and> (d = Fwd \<or> try_stage t Fwd = Continue)"
  using assms
  by (force simp: pattern_decide_def split: stage_res.splits organ_result.splits)

text \<open>The witness lemma every corollary reads: an answer comes from the reader stage (one
phrasing attempt, not dropped, agreeing, not restating, not past time-variant) or from the pattern
stage on a uniquely-named property.\<close>
lemma organ_decide_Answered_witness:
  assumes "organ_decide t = Answered P v s pat"
  shows "\<not> kind_conflict t
    \<and> (pronoun_guard t \<longrightarrow> \<not> guard_drops t s)
    \<and> ((\<exists>a \<in> set (attempts t).
          (key a, dir a, idx a) \<notin> set (dropped t) \<and> prop_of_key t (key a) = P
          \<and> ((dir a = Fwd \<and> agree P (select_dom (cands a)) = Some (v, s))
            \<or> (dir a = Inv \<and> inv_read (inv_subs a) (inv_capped a) = Some (v, s)))
          \<and> \<not> restates t v \<and> \<not> (P \<in> set (time_variant t) \<and> past t))
       \<or> (patterns t \<noteq> [] \<and> (\<exists>d. try_stage t d = Stop (Answered P v s pat)
            \<and> (d = Fwd \<or> try_stage t Fwd = Continue))))"
proof -
  from assms have kg: "\<not> kind_conflict t"
    by (auto simp: organ_decide_def split: if_splits organ_result.splits)
  let ?r = "(case walk t (attempts t) None of
              Silence \<Rightarrow> if patterns t = [] then Silence else pattern_decide t
            | r \<Rightarrow> r)"
  from assms kg have g: "guard t ?r = Answered P v s pat" by (auto simp: organ_decide_def)
  from g have r: "?r = Answered P v s pat"
  proof (cases "?r")
    case Silence
    with g show ?thesis by simp
  next
    case (Answered P0 v0 s0 pat0)
    with g show ?thesis
    proof (cases "guard_drops t s0")
      case True
      with g \<open>?r = Answered P0 v0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    next
      case False
      with g \<open>?r = Answered P0 v0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    qed
  next
    case (Withheld P0 s0 pat0)
    with g show ?thesis
    proof (cases "guard_drops t s0")
      case True
      with g \<open>?r = Withheld P0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    next
      case False
      with g \<open>?r = Withheld P0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    qed
  qed
  from g r have gd: "pronoun_guard t \<longrightarrow> \<not> guard_drops t s"
    by (cases "pronoun_guard t"; cases "guard_drops t s"; simp add: guard_def)
  from r have disj: "walk t (attempts t) None = Answered P v s pat
    \<or> (walk t (attempts t) None = Silence \<and> patterns t \<noteq> []
        \<and> pattern_decide t = Answered P v s pat)"
    by (cases "walk t (attempts t) None") (auto split: if_splits)
  then consider (reader) "walk t (attempts t) None = Answered P v s pat"
    | (pat) "walk t (attempts t) None = Silence" "patterns t \<noteq> []"
        "pattern_decide t = Answered P v s pat"
    by blast
  then show ?thesis
  proof cases
    case reader
    from walk_Answered_inv[OF this] show ?thesis using kg gd by blast
  next
    case pat
    from pattern_decide_Answered_inv[OF pat(3)] show ?thesis using kg gd pat(2) by blast
  qed
qed

theorem organ_answer_means:
  assumes "organ_decide t = Answered P v s pat"
  shows "\<not> restates t v"
    and "\<not> (P \<in> set (time_variant t) \<and> past t)"
    and "(\<exists>cs. cs \<noteq> [] \<and> length cs \<le> 3 \<and> s = qid (hd cs)
          \<and> (\<forall>c \<in> set cs. indomain c \<and> complete c \<and> vals P c = [v] \<and> (P, v) \<in> set (rows c)))
     \<or> (\<exists>subs capped. inv_read subs capped = Some (v, s) \<and> \<not> capped)"
proof -
  from organ_decide_Answered_witness[OF assms] have
    kg: "\<not> kind_conflict t" and gd: "pronoun_guard t \<longrightarrow> \<not> guard_drops t s" and
    wit: "(\<exists>a \<in> set (attempts t).
          (key a, dir a, idx a) \<notin> set (dropped t) \<and> prop_of_key t (key a) = P
          \<and> ((dir a = Fwd \<and> agree P (select_dom (cands a)) = Some (v, s))
            \<or> (dir a = Inv \<and> inv_read (inv_subs a) (inv_capped a) = Some (v, s)))
          \<and> \<not> restates t v \<and> \<not> (P \<in> set (time_variant t) \<and> past t))
       \<or> (patterns t \<noteq> [] \<and> (\<exists>d. try_stage t d = Stop (Answered P v s pat)
            \<and> (d = Fwd \<or> try_stage t Fwd = Continue)))" by blast+
  show "\<not> restates t v"
    using wit try_stage_Stop_Answered_inv by blast
  show "\<not> (P \<in> set (time_variant t) \<and> past t)"
    using wit try_stage_Stop_Answered_inv by blast
  show "(\<exists>cs. cs \<noteq> [] \<and> length cs \<le> 3 \<and> s = qid (hd cs)
          \<and> (\<forall>c \<in> set cs. indomain c \<and> complete c \<and> vals P c = [v] \<and> (P, v) \<in> set (rows c)))
     \<or> (\<exists>subs capped. inv_read subs capped = Some (v, s) \<and> \<not> capped)"
    using wit
  proof
    assume reader: "\<exists>a \<in> set (attempts t).
          (key a, dir a, idx a) \<notin> set (dropped t) \<and> prop_of_key t (key a) = P
          \<and> ((dir a = Fwd \<and> agree P (select_dom (cands a)) = Some (v, s))
            \<or> (dir a = Inv \<and> inv_read (inv_subs a) (inv_capped a) = Some (v, s)))
          \<and> \<not> restates t v \<and> \<not> (P \<in> set (time_variant t) \<and> past t)"
    then obtain a where a: "a \<in> set (attempts t)"
      "((dir a = Fwd \<and> agree P (select_dom (cands a)) = Some (v, s))
        \<or> (dir a = Inv \<and> inv_read (inv_subs a) (inv_capped a) = Some (v, s)))" by blast
    from a(2) show ?thesis
    proof
      assume "dir a = Fwd \<and> agree P (select_dom (cands a)) = Some (v, s)"
      then have ag: "agree P (select_dom (cands a)) = Some (v, s)" by blast
      let ?cs = "mine3 (select_dom (cands a))"
      from agree_Some(1)[OF ag] agree_Some(2)[OF ag] agree_Some(3)[OF ag] agree_Some(4)[OF ag]
      have m: "?cs \<noteq> []" "s = qid (hd ?cs)"
        "\<And>c. c \<in> set ?cs \<Longrightarrow> vals P c = [v]" "\<And>c. c \<in> set ?cs \<Longrightarrow> complete c" by metis+
      have "\<forall>c \<in> set ?cs. indomain c" by (simp add: mine3_props)
      moreover have "length ?cs \<le> 3" by (simp add: mine3_props)
      moreover have "\<forall>c \<in> set ?cs. (P, v) \<in> set (rows c)"
        using m(3) set_vals by fastforce
      ultimately show ?thesis using m by blast
    next
      assume "dir a = Inv \<and> inv_read (inv_subs a) (inv_capped a) = Some (v, s)"
      then show ?thesis
        using inv_read_Some(1)[of "inv_subs a" "inv_capped a" v s] by blast
    qed
  next
    assume pat: "patterns t \<noteq> [] \<and> (\<exists>d. try_stage t d = Stop (Answered P v s pat)
            \<and> (d = Fwd \<or> try_stage t Fwd = Continue))"
    then obtain d where d: "try_stage t d = Stop (Answered P v s pat)" by blast
    from try_stage_Stop_Answered_inv [OF d] have
      "(d = Fwd \<and> agree P (pat_cands t) = Some (v, s))
        \<or> (d = Inv \<and> pat_inv_read t P = Some (v, s))" by blast
    then show ?thesis
    proof
      assume "d = Fwd \<and> agree P (pat_cands t) = Some (v, s)"
      then have ag: "agree P (pat_cands t) = Some (v, s)" by blast
      let ?cs = "mine3 (pat_cands t)"
      from agree_Some(1)[OF ag] agree_Some(2)[OF ag] agree_Some(3)[OF ag] agree_Some(4)[OF ag]
      have m: "?cs \<noteq> []" "s = qid (hd ?cs)"
        "\<And>c. c \<in> set ?cs \<Longrightarrow> vals P c = [v]" "\<And>c. c \<in> set ?cs \<Longrightarrow> complete c" by metis+
      have "\<forall>c \<in> set ?cs. indomain c" by (simp add: mine3_props)
      moreover have "length ?cs \<le> 3" by (simp add: mine3_props)
      moreover have "\<forall>c \<in> set ?cs. (P, v) \<in> set (rows c)"
        using m(3) set_vals by fastforce
      ultimately show ?thesis using m by blast
    next
      assume "d = Inv \<and> pat_inv_read t P = Some (v, s)"
      then obtain subs capped where rc: "inv_read subs capped = Some (v, s)"
        by (auto simp: pat_inv_read_def split: option.splits)
      from inv_read_Some(1)[OF rc] show ?thesis using rc by blast
    qed
  qed
qed

theorem organ_withheld_means:
  assumes "organ_decide t = Withheld P s pat"
  shows "\<not> kind_conflict t
    \<and> (pronoun_guard t \<longrightarrow> \<not> guard_drops t s)
    \<and> (\<exists>a \<in> set (attempts t). cands a \<noteq> [] \<and> dir a = Fwd
        \<and> prop_of_key t (key a) = P
        \<and> (((key a, Fwd, idx a) \<in> set (dropped t) \<and> indomain (hd (select_dom (cands a)))
              \<and> s = qid (hd (select_dom (cands a))))
          \<or> ((key a, Fwd, idx a) \<notin> set (dropped t)
              \<and> mine3 (select_dom (cands a)) \<noteq> []
              \<and> agree P (select_dom (cands a)) = None
              \<and> s = qid (hd (mine3 (select_dom (cands a)))))))"
proof -
  from assms have kg: "\<not> kind_conflict t"
    by (auto simp: organ_decide_def split: if_splits organ_result.splits)
  let ?r = "(case walk t (attempts t) None of
              Silence \<Rightarrow> if patterns t = [] then Silence else pattern_decide t
            | r \<Rightarrow> r)"
  from assms kg have g: "guard t ?r = Withheld P s pat" by (auto simp: organ_decide_def)
  from g have r: "?r = Withheld P s pat"
  proof (cases "?r")
    case Silence
    with g show ?thesis by simp
  next
    case (Answered P0 v0 s0 pat0)
    with g show ?thesis
    proof (cases "guard_drops t s0")
      case True
      with g \<open>?r = Answered P0 v0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    next
      case False
      with g \<open>?r = Answered P0 v0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    qed
  next
    case (Withheld P0 s0 pat0)
    with g show ?thesis
    proof (cases "guard_drops t s0")
      case True
      with g \<open>?r = Withheld P0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    next
      case False
      with g \<open>?r = Withheld P0 s0 pat0\<close> show ?thesis
        by (simp add: guard_def split: if_splits)
    qed
  qed
  from g r have gd: "pronoun_guard t \<longrightarrow> \<not> guard_drops t s"
    by (cases "pronoun_guard t"; cases "guard_drops t s"; simp add: guard_def)
  then have w: "walk t (attempts t) None = Withheld P s pat"
  proof (cases "walk t (attempts t) None")
    case Silence
    with r have eq: "(if patterns t = [] then Silence else pattern_decide t) = Withheld P s pat"
      by simp
    show ?thesis
    proof (cases "patterns t = []")
      case True
      with eq show ?thesis by simp
    next
      case False
      with eq show ?thesis
        by (auto simp: pattern_decide_def try_stage_def finish_def pat_inv_read_def
              split: if_splits stage_res.splits organ_result.splits option.splits
                     direction.splits list.splits)
    qed
  next
    case (Answered P0 v0 s0 pat0)
    with r show ?thesis by simp
  next
    case (Withheld P0 s0 pat0)
    with r show ?thesis by simp
  qed
  from walk_Withheld_inv[OF w] show ?thesis using kg gd by force
qed

text \<open>The pattern stage answers only on a property the fired patterns name uniquely.\<close>
theorem pattern_answer_single_property:
  assumes "pattern_decide t = Answered P v s pid"
  shows "\<exists>d. fired t d = [P]"
  using pattern_decide_Answered_inv[OF assms] try_stage_Stop_Answered_inv by blast

lemma guard_drops_silences:
  assumes "pronoun_guard t" "guard_drops t s"
  shows "organ_decide t \<noteq> Answered P v s pat" "organ_decide t \<noteq> Withheld P' s pat'"
  using assms by (auto simp: organ_decide_def guard_def split: organ_result.splits)

text \<open>Determinism is by construction: @{const organ_decide} is a total function. Plainly: an
@{const Answered} is always witnessed by stored rows the fetch declared complete, was agreed by every
in-domain candidate the selection kept (at most three senses, or the one that dominates tenfold),
does not restate the question, and is not a past-tense read of a time-variant property. A
@{const Withheld} always names the phrasing and the in-domain entity whose read failed. Nothing here
says the store is right, that the linker found the intended entity, or that the phrasing that fired
is the one the asker meant.\<close>

end
