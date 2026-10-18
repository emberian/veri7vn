theory Conceptnet
  imports Main "HOL-Library.Code_Target_Numeral" "HOL-Library.Code_Target_Int"
    "HOL-Library.Product_Lexorder" "HOL-Library.List_Lexorder"
begin

text \<open>Oracle7's ConceptNet adapter (upstream/root/wander-train/oracle_release_conceptnet.py)
as a HOL decision over fetched typed edges, plus the derived two-hop route the
release's own standing gaps declare missing (\<^verbatim>\<open>route:conceptnet_isa_derived\<close>,
\<^verbatim>\<open>route:conceptnet_partof_derived\<close>, carried by 82 shipped folds).

The fetch is untrusted (tools/conceptnet/answerer.py): it supplies typed edge
rows from the sealed build m13e5_conceptnet_build_a_v1 and the routed request.
Everything between those rows and the reply lines - filtering to the routed
relation and direction, ranking, selection, deduplication, rendering and
provenance - is decided here.

Text is a code-point list (\<^typ>\<open>int list\<close>), not a literal: HOL \<^typ>\<open>char\<close>
is 8-bit and the code generator's \<^const>\<open>String.explode\<close> fails on
non-ASCII literals, while ConceptNet surface texts carry accented letters.
Code-point order equals UTF-8 byte order, which is SQLite's BINARY collation,
so ranking on \<^typ>\<open>int list\<close> matches the adapter's ORDER BY.\<close>

subsection \<open>Code points and constant strings\<close>

definition cp :: "char list \<Rightarrow> int list" where
  "cp cs = map (\<lambda>c. of_char c) cs"

lemma cp_simps [simp]:
  "cp [] = []"
  "cp (c # cs) = of_char c # cp cs"
  by (simp_all add: cp_def)

definition c_dot :: int where [simp]: "c_dot = 46"
definition c_star :: int where [simp]: "c_star = 42"
definition c_open :: int where [simp]: "c_open = 91"
definition c_close :: int where [simp]: "c_close = 93"

definition is_ws :: "int \<Rightarrow> bool" where [simp]:
  "is_ws c \<longleftrightarrow> c = 32 \<or> c = 9 \<or> c = 10 \<or> c = 13 \<or> c = 11 \<or> c = 12"

subsection \<open>Relations, directions, edges, requests\<close>

datatype relation =
  IsA | PartOf | HasA | UsedFor | CapableOf | AtLocation | Causes |
  HasSubevent | HasPrerequisite | MotivatedByGoal | Desires | MadeOf |
  ReceivesAction | HasProperty | Synonym | Antonym | DistinctFrom |
  SimilarTo | RelatedTo

definition rel_name :: "relation \<Rightarrow> int list" where
  "rel_name r = (case r of
     IsA \<Rightarrow> cp ''IsA'' | PartOf \<Rightarrow> cp ''PartOf'' | HasA \<Rightarrow> cp ''HasA''
   | UsedFor \<Rightarrow> cp ''UsedFor'' | CapableOf \<Rightarrow> cp ''CapableOf''
   | AtLocation \<Rightarrow> cp ''AtLocation'' | Causes \<Rightarrow> cp ''Causes''
   | HasSubevent \<Rightarrow> cp ''HasSubevent'' | HasPrerequisite \<Rightarrow> cp ''HasPrerequisite''
   | MotivatedByGoal \<Rightarrow> cp ''MotivatedByGoal'' | Desires \<Rightarrow> cp ''Desires''
   | MadeOf \<Rightarrow> cp ''MadeOf'' | ReceivesAction \<Rightarrow> cp ''ReceivesAction''
   | HasProperty \<Rightarrow> cp ''HasProperty'' | Synonym \<Rightarrow> cp ''Synonym''
   | Antonym \<Rightarrow> cp ''Antonym'' | DistinctFrom \<Rightarrow> cp ''DistinctFrom''
   | SimilarTo \<Rightarrow> cp ''SimilarTo'' | RelatedTo \<Rightarrow> cp ''RelatedTo'')"

definition parse_relation :: "int list \<Rightarrow> relation option" where
  "parse_relation s =
     (if s = cp ''IsA'' then Some IsA else if s = cp ''PartOf'' then Some PartOf else
      if s = cp ''HasA'' then Some HasA else if s = cp ''UsedFor'' then Some UsedFor else
      if s = cp ''CapableOf'' then Some CapableOf else if s = cp ''AtLocation'' then Some AtLocation else
      if s = cp ''Causes'' then Some Causes else if s = cp ''HasSubevent'' then Some HasSubevent else
      if s = cp ''HasPrerequisite'' then Some HasPrerequisite else
      if s = cp ''MotivatedByGoal'' then Some MotivatedByGoal else
      if s = cp ''Desires'' then Some Desires else if s = cp ''MadeOf'' then Some MadeOf else
      if s = cp ''ReceivesAction'' then Some ReceivesAction else
      if s = cp ''HasProperty'' then Some HasProperty else if s = cp ''Synonym'' then Some Synonym else
      if s = cp ''Antonym'' then Some Antonym else if s = cp ''DistinctFrom'' then Some DistinctFrom else
      if s = cp ''SimilarTo'' then Some SimilarTo else if s = cp ''RelatedTo'' then Some RelatedTo
      else None)"

lemma parse_rel_name [simp]: "parse_relation s = Some r \<Longrightarrow> rel_name r = s"
  by (cases r) (auto split: if_splits simp: parse_relation_def rel_name_def)

datatype direction = Fwd | Rev

record cedge =
  c_rel :: relation
  c_start :: "int list"
  c_end :: "int list"
  c_weight :: int          \<comment> \<open>the store's REAL weight scaled by 10^6; ranking only\<close>
  c_surface :: "int list"
  c_dataset :: "int list"

record crequest =
  c_concept :: "int list"  \<comment> \<open>already trimmed and lowercased by the untrusted router, as the adapter's SQL parameter is\<close>
  c_specs :: "(relation \<times> direction) list"

subsection \<open>Ranking: weight descending, then start, then end (the adapter's ORDER BY)\<close>

definition rank_key :: "cedge \<Rightarrow> int \<times> int list \<times> int list" where
  "rank_key e = (- c_weight e, c_start e, c_end e)"

definition outranks :: "cedge \<Rightarrow> cedge \<Rightarrow> bool" where
  "outranks e f \<longleftrightarrow> rank_key e < rank_key f"

definition same_rank :: "cedge \<Rightarrow> cedge \<Rightarrow> bool" where
  "same_rank e f \<longleftrightarrow> rank_key e = rank_key f"

lemma outranks_cases: "outranks a b \<or> same_rank a b \<or> outranks b a"
  unfolding outranks_def same_rank_def by (rule less_linear)

lemma outranks_trans: "outranks a b \<Longrightarrow> outranks b c \<Longrightarrow> outranks a c"
  unfolding outranks_def by (rule less_trans)

lemma same_rank_outranks_left [simp]:
  "same_rank a b \<Longrightarrow> outranks b c \<Longrightarrow> outranks a c"
  unfolding outranks_def same_rank_def by simp

lemma same_rank_outranks_right [simp]:
  "same_rank b c \<Longrightarrow> outranks a b \<Longrightarrow> outranks a c"
  unfolding outranks_def same_rank_def by simp

fun rank_sorted :: "cedge list \<Rightarrow> bool" where
  "rank_sorted (e # f # es) \<longleftrightarrow> (outranks e f \<or> same_rank e f) \<and> rank_sorted (f # es)"
| "rank_sorted _ \<longleftrightarrow> True"

fun ins :: "cedge list \<Rightarrow> cedge \<Rightarrow> cedge list" where
  "ins [] e = [e]"
| "ins (x # xs) e = (if outranks e x then e # x # xs else x # ins xs e)"

fun isort :: "cedge list \<Rightarrow> cedge list" where
  "isort [] = []"
| "isort (e # es) = ins (isort es) e"

lemma ins_set [simp]: "set (ins xs e) = insert e (set xs)"
  by (induction xs) auto

lemma isort_set [simp]: "set (isort es) = set es"
  by (induction es) auto

lemma rank_sorted_ConsD: "rank_sorted (x # xs) \<Longrightarrow> rank_sorted xs"
  by (cases xs) simp_all

lemma ins_sorted: "rank_sorted xs \<Longrightarrow> rank_sorted (ins xs e)"
proof (induction xs arbitrary: e)
  case Nil show ?case by simp
next
  case (Cons x xs)
  note prems = Cons.prems
  note IH = Cons.IH
  have rs_xs: "rank_sorted xs" using prems rank_sorted_ConsD by blast
  have ih: "rank_sorted (ins xs e)" using IH rs_xs by simp
  show ?case
  proof (cases "outranks e x")
    case True
    then show ?thesis using prems by simp
  next
    case False
    then have f1: "outranks x e \<or> same_rank x e" using outranks_cases[of x e] by blast
    show ?thesis
    proof (cases xs)
      case Nil
      then show ?thesis using f1 by simp
    next
      case (Cons y ys)
      then show ?thesis
      proof (cases "outranks e y")
        case True
        then show ?thesis using f1 prems \<open>xs = y # ys\<close> by simp
      next
        case False
        then show ?thesis using prems ih \<open>xs = y # ys\<close> by simp
      qed
    qed
  qed
qed

lemma isort_sorted: "rank_sorted (isort es)"
  by (induction es) (simp_all add: ins_sorted)

text \<open>A ranked list stays ranked over any prefix: a take is a prefix
(\<open>take n l @ drop n l = l\<close>), and the head condition of a concatenation
already relates each element to its successor inside the left part.\<close>

lemma rank_sorted_appendL: "rank_sorted (l @ m) \<Longrightarrow> rank_sorted l"
proof (induction l arbitrary: m)
  case Nil show ?case by simp
next
  case (Cons x xs)
  show ?case
  proof (cases "xs @ m")
    case Nil
    then show ?thesis by simp
  next
    case (Cons y ys)
    with Cons.prems have
      h: "outranks x y \<or> same_rank x y" and t: "rank_sorted (xs @ m)" by simp_all
    from Cons.IH[OF t] have rs: "rank_sorted xs" .
    show ?thesis
    proof (cases xs)
      case Nil then show ?thesis by simp
    next
      case (Cons z zs)
      with Cons \<open>xs @ m = y # ys\<close> have yz: "y = z" by simp
      with h Cons rs show ?thesis by simp
    qed
  qed
qed

lemma rank_sorted_take: "rank_sorted l \<Longrightarrow> rank_sorted (take n l)"
proof -
  assume rl: "rank_sorted l"
  have eq: "take n l @ drop n l = l" by (rule append_take_drop_id)
  with rl have "rank_sorted (take n l @ drop n l)" by simp
  then show "rank_sorted (take n l)" by (rule rank_sorted_appendL)
qed

subsection \<open>Selection: the adapter's LIMIT 6 per routed spec\<close>

definition edge_matches :: "direction \<Rightarrow> int list \<Rightarrow> relation \<Rightarrow> cedge \<Rightarrow> bool" where
  "edge_matches d c r e \<longleftrightarrow>
     c_rel e = r \<and> (case d of Fwd \<Rightarrow> c_start e = c | Rev \<Rightarrow> c_end e = c)"

definition sel_spec :: "cedge list \<Rightarrow> relation \<times> direction \<Rightarrow> int list \<Rightarrow> cedge list" where
  "sel_spec es rd c = take 6 (isort [e \<leftarrow> es. edge_matches (snd rd) c (fst rd) e])"

lemma set_take_mem: "x \<in> set (take n l) \<Longrightarrow> x \<in> set l"
proof (induction l arbitrary: n)
  case Nil thus ?case by simp
next
  case (Cons y ys)
  show ?case
  proof (cases n)
    case 0
    with Cons show ?thesis by simp
  next
    case (Suc m)
    with Cons have p: "x = y \<or> x \<in> set (take m ys)" by simp
    then show ?thesis
    proof
      assume xy: "x = y" then show "x \<in> set (y # ys)" by simp
    next
      assume t: "x \<in> set (take m ys)"
      from Cons.IH[OF t] show "x \<in> set (y # ys)" by simp
    qed
  qed
qed

lemma sel_spec_subset:
  "set (sel_spec es rd c) \<subseteq> {e \<in> set es. edge_matches (snd rd) c (fst rd) e}"
proof (unfold sel_spec_def, rule subsetI)
  fix x
  assume "x \<in> set (take 6 (isort [e \<leftarrow> es. edge_matches (snd rd) c (fst rd) e]))"
  then have "x \<in> set (isort [e \<leftarrow> es. edge_matches (snd rd) c (fst rd) e])"
    by (rule set_take_mem)
  then have "x \<in> set [e \<leftarrow> es. edge_matches (snd rd) c (fst rd) e]" by simp
  then show "x \<in> {e \<in> set es. edge_matches (snd rd) c (fst rd) e}" by auto
qed

lemma sel_spec_len: "length (sel_spec es rd c) \<le> 6" by (simp add: sel_spec_def)

lemma sel_spec_nil [simp]: "sel_spec [] rd c = []" by (simp add: sel_spec_def)

lemma sel_spec_sorted: "rank_sorted (sel_spec es rd c)"
  unfolding sel_spec_def using isort_sorted rank_sorted_take by simp

lemma concat_map_nil [simp]: "concat (map (\<lambda>x. []) l) = []"
  by (induction l) simp_all

subsection \<open>Rendering: the adapter's exact surface-text and template rules\<close>

fun drop_last_dots :: "int list \<Rightarrow> int list" where
  "drop_last_dots [] = []"
| "drop_last_dots [c] = (if c = c_dot then [] else [c])"
| "drop_last_dots (c1 # c2 # cs) = c1 # drop_last_dots (c2 # cs)"

definition strip_ws :: "int list \<Rightarrow> int list" where
  "strip_ws cs = (let l = dropWhile is_ws cs in rev (dropWhile is_ws (rev l)))"

fun strip_doubled :: "int \<Rightarrow> int list \<Rightarrow> int list" where
  "strip_doubled b (c # d # cs) =
     (if c = b \<and> d = b then strip_doubled b cs else c # strip_doubled b (d # cs))"
| "strip_doubled b cs = cs"

definition clean_surface :: "int list \<Rightarrow> int list" where
  "clean_surface cs =
     strip_ws (dropWhile (\<lambda>c. c = c_star)
       (strip_doubled c_open (strip_doubled c_close (strip_ws cs))))"

definition upper :: "int \<Rightarrow> int" where
  "upper c = (if 97 \<le> c \<and> c \<le> 122 then c - 32 else c)"

fun cap_chars :: "int list \<Rightarrow> int list" where
  "cap_chars [] = []"
| "cap_chars (c # cs) = upper c # cs"

lemma cap_chars_Nil [simp]: "cap_chars xs = [] \<longleftrightarrow> xs = []"
  by (cases xs) simp_all

fun template_chars :: "relation \<Rightarrow> int list \<Rightarrow> int list \<Rightarrow> int list" where
  "template_chars IsA s t = s @ cp '' is a kind of '' @ t"
| "template_chars PartOf s t = s @ cp '' is part of '' @ t"
| "template_chars HasA s t = s @ cp '' has '' @ t"
| "template_chars UsedFor s t = s @ cp '' is used for '' @ t"
| "template_chars CapableOf s t = s @ cp '' can '' @ t"
| "template_chars AtLocation s t = s @ cp '' is typically found at '' @ t"
| "template_chars Causes s t = s @ cp '' causes '' @ t"
| "template_chars HasSubevent s t = s @ cp '' involves '' @ t"
| "template_chars HasPrerequisite s t = s @ cp '' requires '' @ t"
| "template_chars MotivatedByGoal s t = s @ cp '' is motivated by '' @ t"
| "template_chars Desires s t = s @ cp '' desires '' @ t"
| "template_chars MadeOf s t = s @ cp '' is made of '' @ t"
| "template_chars ReceivesAction s t = s @ cp '' can be '' @ t"
| "template_chars HasProperty s t = s @ cp '' is '' @ t"
| "template_chars Synonym s t = s @ cp '' is a synonym of '' @ t"
| "template_chars Antonym s t = s @ cp '' is an antonym of '' @ t"
| "template_chars DistinctFrom s t = s @ cp '' is distinct from '' @ t"
| "template_chars SimilarTo s t = s @ cp '' is similar to '' @ t"
| "template_chars RelatedTo s t = s @ cp '' is related to '' @ t"

lemma template_chars_neq_Nil [simp]: "template_chars r s t \<noteq> []"
  by (cases r) simp_all

definition render_chars :: "cedge \<Rightarrow> int list" where
  "render_chars e =
     (let t = clean_surface (c_surface e) in
      if t \<noteq> [] then upper (hd t) # drop_last_dots (tl t) @ [c_dot]
      else cap_chars (template_chars (c_rel e) (c_start e) (c_end e)) @ [c_dot])"

definition render_edge :: "cedge \<Rightarrow> int list" where
  "render_edge e = render_chars e"

lemma append_dot_last: "xs \<noteq> [] \<Longrightarrow> last (xs @ [c_dot]) = c_dot"
  by (induction xs) auto

lemma render_edge_sentence:
  "render_edge e \<noteq> [] \<and> last (render_edge e) = c_dot"
  unfolding render_edge_def render_chars_def
  by (auto simp: Let_def append_dot_last)

subsection \<open>Claims (provenance)\<close>

type_synonym claim = "int list \<times> int \<times> int list"

definition claim_of :: "cedge \<Rightarrow> claim" where
  "claim_of e = (cp ''conceptnet57:'' @ rel_name (c_rel e) @ cp '':'' @ c_start e @ cp ''->'' @ c_end e,
                 c_weight e, c_dataset e)"

lemma claim_of_shape:
  "claim_of e = (cp ''conceptnet57:'' @ rel_name (c_rel e) @ cp '':'' @ c_start e @ cp ''->'' @ c_end e,
                 c_weight e, c_dataset e)"
  by (rule claim_of_def)

subsection \<open>The direct decision (the adapter's answer path)\<close>

definition declared_witness :: "crequest \<Rightarrow> cedge \<Rightarrow> bool" where
  "declared_witness req e \<longleftrightarrow>
     (\<exists>r d. (r, d) \<in> set (c_specs req) \<and> c_rel e = r \<and>
       (d = Fwd \<and> c_start e = c_concept req \<or> d = Rev \<and> c_end e = c_concept req))"

definition collect_edges :: "crequest \<Rightarrow> cedge list \<Rightarrow> cedge list" where
  "collect_edges req es = concat (map (\<lambda>rd. sel_spec es rd (c_concept req)) (c_specs req))"

lemma collect_edges_empty [simp]: "collect_edges req [] = []"
  unfolding collect_edges_def by (induction "c_specs req") auto

fun add_line :: "(int list \<times> claim) list \<Rightarrow> cedge \<Rightarrow> (int list \<times> claim) list" where
  "add_line acc e =
     (if length acc < 5 then
        let l = render_edge e in
        if l \<in> fst ` set acc then acc else acc @ [(l, claim_of e)]
      else acc)"

definition decide_direct :: "crequest \<Rightarrow> cedge list \<Rightarrow> (int list \<times> claim) list" where
  "decide_direct req es = foldl add_line [] (collect_edges req es)"

lemma collect_edges_witnessed:
  "e \<in> set (collect_edges req es) \<Longrightarrow> e \<in> set es \<and> declared_witness req e"
proof -
  assume "e \<in> set (collect_edges req es)"
  then obtain rd where rd: "rd \<in> set (c_specs req)"
    "e \<in> set (sel_spec es rd (c_concept req))"
    unfolding collect_edges_def by auto
  from rd(2) sel_spec_subset have
    ee: "e \<in> set es" and m: "edge_matches (snd rd) (c_concept req) (fst rd) e" by blast+
  obtain r d where rdp: "rd = (r, d)" by (cases rd)
  with rd(1) have pe: "(fst rd, snd rd) \<in> set (c_specs req)" by simp
  from pe m ee show "e \<in> set es \<and> declared_witness req e"
    unfolding declared_witness_def edge_matches_def
    by (cases "snd rd") auto
qed

lemma add_line_skip:
  "\<not> (length acc < 5 \<and> render_edge a \<notin> fst ` set acc) \<Longrightarrow> add_line acc a = acc"
  by (cases "length acc < 5") (auto simp: Let_def)

lemma add_line_add:
  "length acc < 5 \<Longrightarrow> render_edge a \<notin> fst ` set acc \<Longrightarrow>
     add_line acc a = acc @ [(render_edge a, claim_of a)]"
  by (auto simp: Let_def)

lemma ex_line_witness:
  "x = (render_edge e, claim_of e) \<Longrightarrow> e \<in> set l \<Longrightarrow>
     \<exists>e' \<in> set (a # l). x = (render_edge e', claim_of e')"
proof -
  assume xeq: "x = (render_edge e, claim_of e)" and e: "e \<in> set l"
  from e have ec: "e \<in> set (a # l)" by simp
  from ec xeq show ?thesis by blast
qed

text \<open>Every line the fold emits is either older than the batch or exactly the
rendering of a batch edge. Proved elementarily: an \<open>auto\<close> induction loses
the dedup branch's set image.\<close>

lemma fold_add_line_new:
  "\<forall>x \<in> set (foldl add_line acc l). x \<in> set acc \<or> (\<exists>e \<in> set l. x = (render_edge e, claim_of e))"
proof (induction l arbitrary: acc)
  case Nil thus ?case by simp
next
  case (Cons a l)
  note IH = Cons.IH
  show ?case
  proof (cases "length acc < 5 \<and> render_edge a \<notin> fst ` set acc")
    case True
    then have p1: "length acc < 5" and p2: "render_edge a \<notin> fst ` set acc" by simp_all
    from p1 p2 have al: "add_line acc a = acc @ [(render_edge a, claim_of a)]"
      by (rule add_line_add)
    show ?thesis
    proof (rule ballI)
      fix x
      assume x: "x \<in> set (foldl add_line acc (a # l))"
      then have xr: "x \<in> set (foldl add_line (add_line acc a) l)"
        by (simp only: foldl.simps(2))
      from IH[of "add_line acc a"] xr have
        d: "x \<in> set (add_line acc a) \<or> (\<exists>e \<in> set l. x = (render_edge e, claim_of e))" by blast
      from d show "x \<in> set acc \<or> (\<exists>e \<in> set (a # l). x = (render_edge e, claim_of e))"
      proof
        assume xa: "x \<in> set (add_line acc a)"
        with al have ap: "x \<in> set (acc @ [(render_edge a, claim_of a)])" by simp
        then have s: "x = (render_edge a, claim_of a) \<or> x \<in> set acc" by simp
        then show ?thesis
        proof
          assume xeq: "x = (render_edge a, claim_of a)"
          have aw: "a \<in> set (a # l)" by simp
          from aw xeq have b: "\<exists>e' \<in> set (a # l). x = (render_edge e', claim_of e')"
            by blast
          show ?thesis by (rule disjI2[OF b])
        next
          assume s1: "x \<in> set acc" then show ?thesis by (rule disjI1)
        qed
      next
        assume ex: "\<exists>e \<in> set l. x = (render_edge e, claim_of e)"
        then show ?thesis
        proof
          fix e
          assume xeq: "x = (render_edge e, claim_of e)" and e: "e \<in> set l"
          from xeq e have b: "\<exists>e' \<in> set (a # l). x = (render_edge e', claim_of e')"
            by (rule ex_line_witness)
          show ?thesis by (rule disjI2[OF b])
        qed
      qed
    qed
  next
    case False
    then have al: "add_line acc a = acc" by (rule add_line_skip)
    show ?thesis
    proof (rule ballI)
      fix x
      assume x: "x \<in> set (foldl add_line acc (a # l))"
      then have xr: "x \<in> set (foldl add_line (add_line acc a) l)"
        by (simp only: foldl.simps(2))
      from IH[of "add_line acc a"] xr have
        d: "x \<in> set (add_line acc a) \<or> (\<exists>e \<in> set l. x = (render_edge e, claim_of e))" by blast
      from d show "x \<in> set acc \<or> (\<exists>e \<in> set (a # l). x = (render_edge e, claim_of e))"
      proof
        assume xa: "x \<in> set (add_line acc a)"
        with al show ?thesis by simp
      next
        assume ex: "\<exists>e \<in> set l. x = (render_edge e, claim_of e)"
        then show ?thesis
        proof
          fix e
          assume xeq: "x = (render_edge e, claim_of e)" and e: "e \<in> set l"
          from xeq e have b: "\<exists>e' \<in> set (a # l). x = (render_edge e', claim_of e')"
            by (rule ex_line_witness)
          show ?thesis by (rule disjI2[OF b])
        qed
      qed
    qed
  qed
qed

lemma fold_add_line_new0:
  "x \<in> set (foldl add_line [] l) \<Longrightarrow> \<exists>e \<in> set l. x = (render_edge e, claim_of e)"
proof -
  assume "x \<in> set (foldl add_line [] l)"
  from fold_add_line_new[of "[]" l] this have
    "x \<in> set [] \<or> (\<exists>e \<in> set l. x = (render_edge e, claim_of e))" by blast
  then show ?thesis by simp
qed

lemma add_line_len:
  "length (add_line acc e) = length acc \<or> length (add_line acc e) = length acc + 1"
  by (cases "length acc < 5") (auto simp: Let_def)

lemma fold_add_line_bound: "length acc \<le> 5 \<Longrightarrow> length (foldl add_line acc l) \<le> 5"
proof (induction l arbitrary: acc)
  case Nil thus ?case by simp
next
  case (Cons a l)
  have step: "foldl add_line acc (a # l) = foldl add_line (add_line acc a) l"
    by (rule foldl.simps(2))
  from add_line_len[of acc a] show ?case
  proof (elim disjE)
    assume e1: "length (add_line acc a) = length acc"
    then have lt: "length (add_line acc a) \<le> 5" using Cons.prems by simp
    from Cons.IH[OF lt] step show ?case by simp
  next
    assume e2: "length (add_line acc a) = length acc + 1"
    have lt: "length (add_line acc a) \<le> 5"
    proof (cases "length acc < 5")
      case True
      then have "length acc + 1 \<le> 5" by arith
      with e2 show ?thesis by simp
    next
      case False
      then have n5: "\<not> (length acc < 5 \<and> render_edge a \<notin> fst ` set acc)" by simp
      from n5 have sk: "add_line acc a = acc" by (rule add_line_skip)
      with e2 show ?thesis by simp
    qed
    from Cons.IH[OF lt] step show ?case by simp
  qed
qed

text \<open>Stated over \<^const>\<open>fst\<close>/\<^const>\<open>snd\<close> rather than a pair pattern: a
\<^theory_text>\<open>cases\<close> split of a reply line gives its four components (the claim is
itself a triple), and repacking them into two is exactly where automation
stalls; projections need no split at all.\<close>

theorem decide_direct_witnessed:
  "\<forall>ln \<in> set (decide_direct req es).
     \<exists>e \<in> set es. declared_witness req e \<and> render_edge e = fst ln \<and> claim_of e = snd ln"
proof (unfold decide_direct_def, rule ballI)
  fix x
  assume x: "x \<in> set (foldl add_line [] (collect_edges req es))"
  from fold_add_line_new0[where l="collect_edges req es"] x
  obtain e where
    e: "e \<in> set (collect_edges req es)" and
    parts: "x = (render_edge e, claim_of e)"
    by blast
  from parts have px: "fst x = render_edge e" "snd x = claim_of e" by simp_all
  from e collect_edges_witnessed have
    ee: "e \<in> set es" and dw: "declared_witness req e" by blast+
  from ee dw px have w: "e \<in> set es \<and> declared_witness req e \<and>
    render_edge e = fst x \<and> claim_of e = snd x" by simp
  from w show "\<exists>e \<in> set es. declared_witness req e \<and> render_edge e = fst x \<and> claim_of e = snd x"
    by blast
qed

theorem decide_direct_bounded: "length (decide_direct req es) \<le> 5"
  unfolding decide_direct_def by (rule fold_add_line_bound) simp

subsection \<open>The derived decision (two hops through a declared mediator)\<close>

text \<open>The adapter has only one-hop routes. The release's standing gaps name
\<^verbatim>\<open>conceptnet_isa_derived\<close> and \<^verbatim>\<open>conceptnet_partof_derived\<close> as missing
complements; this is that route: concept - mediator -\<guillemotright> parent - relation -\<guillemotright> answer.
Every rendered line names the parent it was derived through, and the reply
carries the provenance of both hops.\<close>

record dline =
  d_via :: "int list"       \<comment> \<open>the parent concept the line was derived through\<close>
  d_line :: "int list"
  d_hop1 :: claim           \<comment> \<open>the mediator edge (concept - mediator -\<guillemotright> parent)\<close>
  d_hop2 :: claim           \<comment> \<open>the answered edge (parent - relation -\<guillemotright> answer)\<close>

definition parent_edges :: "relation \<Rightarrow> int list \<Rightarrow> cedge list \<Rightarrow> cedge list" where
  "parent_edges med c es = take 3 (isort [e \<leftarrow> es. c_rel e = med \<and> c_start e = c])"

lemma parent_edges_witnessed:
  "e \<in> set (parent_edges med c es) \<Longrightarrow> e \<in> set es \<and> c_rel e = med \<and> c_start e = c"
proof -
  assume x: "e \<in> set (parent_edges med c es)"
  then have t: "e \<in> set (take 3 (isort [z \<leftarrow> es. c_rel z = med \<and> c_start z = c]))"
    by (simp add: parent_edges_def)
  from set_take_mem[OF t]
  have i: "e \<in> set (isort [z \<leftarrow> es. c_rel z = med \<and> c_start z = c])" .
  from i have f: "e \<in> set [z \<leftarrow> es. c_rel z = med \<and> c_start z = c]" by simp
  then have ee: "e \<in> set es" and mm: "c_rel e = med" and ss: "c_start e = c" by auto
  from ee mm ss show ?thesis by simp
qed

lemma parent_edges_nil [simp]: "parent_edges med c [] = []"
  by (simp add: parent_edges_def)

definition fwd_specs :: "crequest \<Rightarrow> relation list" where
  "fwd_specs req = map fst [rd \<leftarrow> c_specs req. snd rd = Fwd]"

definition derived_pairs :: "relation \<Rightarrow> crequest \<Rightarrow> cedge list \<Rightarrow> (int list \<times> cedge \<times> cedge) list" where
  "derived_pairs med req es =
     concat (map
       (\<lambda>e1. concat (map
          (\<lambda>r. map (\<lambda>e2. (c_end e1, e1, e2))
                       (take 3 (isort [e \<leftarrow> es. c_rel e = r \<and> c_start e = c_end e1])))
          (fwd_specs req)))
       (parent_edges med (c_concept req) es))"

lemma derived_pairs_nil [simp]: "derived_pairs med req [] = []"
  by (simp add: derived_pairs_def)

lemma derived_pairs_witnessed:
  assumes "(p, e1, e2) \<in> set (derived_pairs med req es)"
  shows "e1 \<in> set es" "c_rel e1 = med" "c_start e1 = c_concept req" "c_end e1 = p"
    and "e2 \<in> set es" "c_start e2 = p" "c_rel e2 \<in> set (fwd_specs req)"
proof -
  from assms obtain e1' r e2' where
    p1: "e1' \<in> set (parent_edges med (c_concept req) es)" and
    p2: "r \<in> set (fwd_specs req)" and
    p3: "e2' \<in> set (take 3 (isort [x \<leftarrow> es. c_rel x = r \<and> c_start x = c_end e1']))" and
    pe: "p = c_end e1'" "e1 = e1'" "e2 = e2'"
    unfolding derived_pairs_def by auto
  from p1 parent_edges_witnessed have
    w1: "e1' \<in> set es" "c_rel e1' = med" "c_start e1' = c_concept req" by blast+
  from set_take_mem[OF p3]
  have i3: "e2' \<in> set (isort [x \<leftarrow> es. c_rel x = r \<and> c_start x = c_end e1'])" .
  from i3 have f3: "e2' \<in> set [x \<leftarrow> es. c_rel x = r \<and> c_start x = c_end e1']" by simp
  from f3 have w2: "e2' \<in> set es" "c_rel e2' = r" "c_start e2' = c_end e1'" by auto
  from pe w1 w2 p2 show
    "e1 \<in> set es" "c_rel e1 = med" "c_start e1 = c_concept req" "c_end e1 = p"
    "e2 \<in> set es" "c_start e2 = p" "c_rel e2 \<in> set (fwd_specs req)"
    by auto
qed

fun add_dline :: "dline list \<Rightarrow> int list \<times> cedge \<times> cedge \<Rightarrow> dline list" where
  "add_dline acc (p, e1, e2) =
     (if length acc < 4 then
        let l = cp ''(via '' @ p @ cp '') '' @ render_edge e2 in
        if l \<in> d_line ` set acc then acc
        else acc @ [\<lparr>d_via = p, d_line = l, d_hop1 = claim_of e1, d_hop2 = claim_of e2\<rparr>]
      else acc)"

definition decide_derived :: "relation \<Rightarrow> crequest \<Rightarrow> cedge list \<Rightarrow> dline list" where
  "decide_derived med req es = foldl add_dline [] (derived_pairs med req es)"

definition dline_of :: "int list \<times> cedge \<times> cedge \<Rightarrow> dline" where
  "dline_of x = \<lparr>d_via = fst x, d_line = cp ''(via '' @ fst x @ cp '') '' @ render_edge (snd (snd x)),
     d_hop1 = claim_of (fst (snd x)), d_hop2 = claim_of (snd (snd x))\<rparr>"

lemma dline_of_simps [simp]:
  "d_via (dline_of x) = fst x"
  "d_line (dline_of x) = cp ''(via '' @ fst x @ cp '') '' @ render_edge (snd (snd x))"
  "d_hop1 (dline_of x) = claim_of (fst (snd x))"
  "d_hop2 (dline_of x) = claim_of (snd (snd x))"
  by (simp_all add: dline_of_def)

lemma add_dline_skip:
  "\<not> (length acc < 4 \<and> cp ''(via '' @ fst x @ cp '') '' @ render_edge (snd (snd x)) \<notin> d_line ` set acc) \<Longrightarrow>
     add_dline acc x = acc"
  by (cases x) (auto simp: Let_def)

lemma add_dline_add:
  "length acc < 4 \<Longrightarrow> cp ''(via '' @ fst x @ cp '') '' @ render_edge (snd (snd x)) \<notin> d_line ` set acc \<Longrightarrow>
     add_dline acc x = acc @ [dline_of x]"
  by (cases x) (auto simp: Let_def dline_of_def)

definition dline_new :: "dline \<Rightarrow> (int list \<times> cedge \<times> cedge) list \<Rightarrow> bool" where
  "dline_new dl l \<longleftrightarrow>
     (\<exists>x \<in> set l. d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge (snd (snd x))
                \<and> d_hop2 dl = claim_of (snd (snd x)) \<and> d_hop1 dl = claim_of (fst (snd x))
                \<and> d_via dl = fst x)"

lemma dline_new_mono: "dline_new dl l \<Longrightarrow> dline_new dl (a # l)"
proof -
  assume h: "dline_new dl l"
  then obtain x where x: "x \<in> set l"
    and P: "d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge (snd (snd x))
                \<and> d_hop2 dl = claim_of (snd (snd x)) \<and> d_hop1 dl = claim_of (fst (snd x))
                \<and> d_via dl = fst x"
    unfolding dline_new_def by blast
  from x have xa: "x \<in> set (a # l)" by simp
  from xa P show ?thesis unfolding dline_new_def by blast
qed

lemma fold_add_dline_new:
  "\<forall>dl \<in> set (foldl add_dline acc l). dl \<in> set acc \<or> dline_new dl l"
proof (induction l arbitrary: acc)
  case Nil thus ?case by simp
next
  case (Cons a l)
  note IH = Cons.IH
  show ?case
  proof (cases "length acc < 4 \<and> cp ''(via '' @ fst a @ cp '') '' @ render_edge (snd (snd a)) \<notin> d_line ` set acc")
    case True
    then have p1: "length acc < 4"
      and p2: "cp ''(via '' @ fst a @ cp '') '' @ render_edge (snd (snd a)) \<notin> d_line ` set acc" by simp_all
    from p1 p2 have al: "add_dline acc a = acc @ [dline_of a]" by (rule add_dline_add)
    show ?thesis
    proof (rule ballI)
      fix dl
      assume x: "dl \<in> set (foldl add_dline acc (a # l))"
      then have xr: "dl \<in> set (foldl add_dline (add_dline acc a) l)"
        by (simp only: foldl.simps(2))
      from IH[of "add_dline acc a"] xr have
        d: "dl \<in> set (add_dline acc a) \<or> dline_new dl l" by blast
      from d show "dl \<in> set acc \<or> dline_new dl (a # l)"
      proof
        assume xa: "dl \<in> set (add_dline acc a)"
        with al have ap: "dl \<in> set (acc @ [dline_of a])" by simp
        then have s: "dl = dline_of a \<or> dl \<in> set acc" by simp
        then show ?thesis
        proof
          assume dre: "dl = dline_of a"
          have am: "a \<in> set (a # l)" by simp
          from am dre have nn: "dline_new dl (a # l)"
            unfolding dline_new_def by simp
          from nn show ?thesis by (rule disjI2)
        next
          assume s1: "dl \<in> set acc" then show ?thesis by (rule disjI1)
        qed
      next
        assume dnew: "dline_new dl l"
        from dline_new_mono[OF dnew] show ?thesis by (rule disjI2)
      qed
    qed
  next
    case False
    then have al: "add_dline acc a = acc" by (rule add_dline_skip)
    show ?thesis
    proof (rule ballI)
      fix dl
      assume x: "dl \<in> set (foldl add_dline acc (a # l))"
      then have xr: "dl \<in> set (foldl add_dline (add_dline acc a) l)"
        by (simp only: foldl.simps(2))
      from IH[of "add_dline acc a"] xr have
        d: "dl \<in> set (add_dline acc a) \<or> dline_new dl l" by blast
      from d show "dl \<in> set acc \<or> dline_new dl (a # l)"
      proof
        assume xa: "dl \<in> set (add_dline acc a)"
        with al show ?thesis by simp
      next
        assume dnew: "dline_new dl l"
        from dline_new_mono[OF dnew] show ?thesis by (rule disjI2)
      qed
    qed
  qed
qed

lemma fold_add_dline_new0:
  "dl \<in> set (foldl add_dline [] l) \<Longrightarrow> dline_new dl l"
proof -
  assume "dl \<in> set (foldl add_dline [] l)"
  from fold_add_dline_new[of "[]" l] this have
    "dl \<in> set [] \<or> dline_new dl l" by blast
  then show ?thesis by simp
qed

lemma add_dline_len:
  "length (add_dline acc x) = length acc \<or> length (add_dline acc x) = length acc + 1"
  by (cases x) (cases "length acc < 4"; auto simp: Let_def)

lemma fold_add_dline_bound: "length acc \<le> 4 \<Longrightarrow> length (foldl add_dline acc l) \<le> 4"
proof (induction l arbitrary: acc)
  case Nil thus ?case by simp
next
  case (Cons a l)
  have step: "foldl add_dline acc (a # l) = foldl add_dline (add_dline acc a) l"
    by (rule foldl.simps(2))
  from add_dline_len[of acc a] show ?case
  proof (elim disjE)
    assume e1: "length (add_dline acc a) = length acc"
    then have lt: "length (add_dline acc a) \<le> 4" using Cons.prems by simp
    from Cons.IH[OF lt] step show ?case by simp
  next
    assume e2: "length (add_dline acc a) = length acc + 1"
    have lt: "length (add_dline acc a) \<le> 4"
    proof (cases "length acc < 4")
      case True
      then have "length acc + 1 \<le> 4" by arith
      with e2 show ?thesis by simp
    next
      case False
      then have n4: "\<not> (length acc < 4 \<and>
        cp ''(via '' @ fst a @ cp '') '' @ render_edge (snd (snd a)) \<notin> d_line ` set acc)" by simp
      from n4 have sk: "add_dline acc a = acc" by (rule add_dline_skip)
      with e2 show ?thesis by simp
    qed
    from Cons.IH[OF lt] step show ?case by simp
  qed
qed

theorem decide_derived_witnessed:
  "\<forall>dl \<in> set (decide_derived med req es).
     \<exists>e1 e2. e1 \<in> set es \<and> e2 \<in> set es \<and>
       c_rel e1 = med \<and> c_start e1 = c_concept req \<and> c_end e1 = d_via dl \<and>
       c_rel e2 \<in> set (fwd_specs req) \<and> c_start e2 = d_via dl \<and>
       d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge e2 \<and>
       d_hop1 dl = claim_of e1 \<and> d_hop2 dl = claim_of e2"
proof (unfold decide_derived_def, rule ballI)
  fix dl assume dl: "dl \<in> set (foldl add_dline [] (derived_pairs med req es))"
  from dl have fldl: "dl \<in> set (foldl add_dline [] (derived_pairs med req es))"
    by (simp add: decide_derived_def)
  note dn = fold_add_dline_new0[where l="derived_pairs med req es", OF fldl]
  then obtain x where
    x: "x \<in> set (derived_pairs med req es)" and
    dl_line: "d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge (snd (snd x))" and
    dl_hop2: "d_hop2 dl = claim_of (snd (snd x))" and
    dl_hop1: "d_hop1 dl = claim_of (fst (snd x))" and
    dl_via: "d_via dl = fst x"
    unfolding dline_new_def by blast
  obtain p e1 e2 where pe: "x = (p, e1, e2)" by (cases x) auto
  from x pe have w: "(p, e1, e2) \<in> set (derived_pairs med req es)" by simp
  note ws = derived_pairs_witnessed[OF w]
  from pe have sel: "fst x = p" "fst (snd x) = e1" "snd (snd x) = e2" by simp_all
  from dl_via sel have dv: "d_via dl = p" by simp
  from dl_hop1 sel have h1: "d_hop1 dl = claim_of e1" by simp
  from dl_hop2 sel have h2: "d_hop2 dl = claim_of e2" by simp
  from dl_line sel have ll: "d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge e2" by simp
  show "\<exists>e1 e2. e1 \<in> set es \<and> e2 \<in> set es \<and>
    c_rel e1 = med \<and> c_start e1 = c_concept req \<and> c_end e1 = d_via dl \<and>
    c_rel e2 \<in> set (fwd_specs req) \<and> c_start e2 = d_via dl \<and>
    d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge e2 \<and>
    d_hop1 dl = claim_of e1 \<and> d_hop2 dl = claim_of e2"
  proof (rule exI[where x=e1], rule exI[where x=e2])
    show "e1 \<in> set es \<and> e2 \<in> set es \<and>
      c_rel e1 = med \<and> c_start e1 = c_concept req \<and> c_end e1 = d_via dl \<and>
      c_rel e2 \<in> set (fwd_specs req) \<and> c_start e2 = d_via dl \<and>
      d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge e2 \<and>
      d_hop1 dl = claim_of e1 \<and> d_hop2 dl = claim_of e2"
      using ws(1) ws(2) ws(3) ws(4) ws(5) ws(6) ws(7) dv h1 h2 ll by simp
  qed
qed

theorem decide_derived_bounded: "length (decide_derived med req es) \<le> 4"
  unfolding decide_derived_def by (rule fold_add_dline_bound) simp

subsection \<open>The decision\<close>

datatype creply =
  C_answer "(int list \<times> claim) list"
| C_derived "dline list"
| C_abstain

fun first_derived :: "relation list \<Rightarrow> crequest \<Rightarrow> cedge list \<Rightarrow> dline list" where
  "first_derived [] _ _ = []"
| "first_derived (m # ms) req es =
     (let ds = decide_derived m req es in if ds \<noteq> [] then ds else first_derived ms req es)"

definition decide :: "relation list \<Rightarrow> crequest \<Rightarrow> cedge list \<Rightarrow> creply" where
  "decide meds req es =
     (let out = decide_direct req es in
      if out \<noteq> [] then C_answer out
      else (case first_derived meds req es of [] \<Rightarrow> C_abstain | ds \<Rightarrow> C_derived ds))"

theorem decide_empty_is_abstain: "decide meds req [] = C_abstain"
  by (induction meds) (simp_all add: decide_def decide_direct_def decide_derived_def)

theorem decide_no_meds_iff:
  "decide [] req es = C_abstain \<longleftrightarrow> decide_direct req es = []"
proof
  assume h: "decide [] req es = C_abstain"
  then show "decide_direct req es = []"
  proof (cases "decide_direct req es = []")
    case True then show ?thesis .
  next
    case False
    then have ca: "decide [] req es = C_answer (decide_direct req es)"
      by (simp add: decide_def)
    with h have "C_answer (decide_direct req es) = C_abstain" by simp
    then have False by simp
    then show ?thesis by simp
  qed
next
  assume h: "decide_direct req es = []"
  then show "decide [] req es = C_abstain" by (simp add: decide_def)
qed

lemma first_derived_nil_iff:
  "first_derived meds req es = [] \<longleftrightarrow> (\<forall>m \<in> set meds. decide_derived m req es = [])"
proof (induction meds)
  case Nil show ?case by simp
next
  case (Cons m ms)
  show "first_derived (m # ms) req es = [] \<longleftrightarrow>
      (\<forall>mm \<in> set (m # ms). decide_derived mm req es = [])"
  proof (cases "decide_derived m req es = []")
    case True
    then show "first_derived (m # ms) req es = [] \<longleftrightarrow>
        (\<forall>mm \<in> set (m # ms). decide_derived mm req es = [])"
      using Cons.IH by simp
  next
    case False
    then show "first_derived (m # ms) req es = [] \<longleftrightarrow>
        (\<forall>mm \<in> set (m # ms). decide_derived mm req es = [])" by simp
  qed
qed

theorem decide_abstain_iff:
  "decide meds req es = C_abstain \<longleftrightarrow>
     decide_direct req es = [] \<and> (\<forall>m \<in> set meds. decide_derived m req es = [])"
proof
  assume h: "decide meds req es = C_abstain"
  then show "decide_direct req es = [] \<and> (\<forall>m \<in> set meds. decide_derived m req es = [])"
  proof (cases "decide_direct req es = []")
    case True
    then have dd: "decide meds req es =
        (case first_derived meds req es of [] \<Rightarrow> C_abstain | ds \<Rightarrow> C_derived ds)"
      by (simp add: decide_def)
    with h have ce: "(case first_derived meds req es of
        [] \<Rightarrow> C_abstain | ds \<Rightarrow> C_derived ds) = C_abstain" by simp
    have fde: "first_derived meds req es = []"
    proof (cases "first_derived meds req es")
      case Nil then show ?thesis .
    next
      case (Cons d dsx)
      with ce have "C_derived (d # dsx) = C_abstain" by simp
      then have False by simp
      then show ?thesis by simp
    qed
    with first_derived_nil_iff[of meds req es] True show ?thesis by simp
  next
    case False
    then have ca: "decide meds req es = C_answer (decide_direct req es)"
      by (simp add: decide_def)
    with h have "C_answer (decide_direct req es) = C_abstain" by simp
    then have False by simp
    then show ?thesis by simp
  qed
next
  assume h: "decide_direct req es = [] \<and> (\<forall>m \<in> set meds. decide_derived m req es = [])"
  then have hd: "decide_direct req es = []"
    and ha: "\<forall>m \<in> set meds. decide_derived m req es = []" by simp_all
  from ha first_derived_nil_iff[of meds req es] have fe: "first_derived meds req es = []" by simp
  from hd have dd: "decide meds req es =
      (case first_derived meds req es of [] \<Rightarrow> C_abstain | ds \<Rightarrow> C_derived ds)"
    by (simp add: decide_def)
  with fe show "decide meds req es = C_abstain" by simp
qed
theorem answer_nonempty_bounded:
  "decide meds req es = C_answer out \<Longrightarrow> out \<noteq> [] \<and> length out \<le> 5"
proof (unfold decide_def)
  assume eq: "(let o0 = decide_direct req es in
      if o0 \<noteq> [] then C_answer o0
      else case first_derived meds req es of [] \<Rightarrow> C_abstain | ds \<Rightarrow> C_derived ds) = C_answer out"
  show "out \<noteq> [] \<and> length out \<le> 5"
  proof (cases "decide_direct req es \<noteq> []")
    case True
    with eq have cc: "C_answer (decide_direct req es) = C_answer out" by simp
    then have oq: "out = decide_direct req es" by simp
    from True oq have nz: "out \<noteq> []" by simp
    from oq decide_direct_bounded[of req es] have lb: "length out \<le> 5" by simp
    from nz lb show ?thesis ..
  next
    case False
    with eq have fc: "(case first_derived meds req es of
        [] \<Rightarrow> C_abstain | ds \<Rightarrow> C_derived ds) = C_answer out" by simp
    then show ?thesis
    proof (cases "first_derived meds req es")
      case Nil
      with fc have "C_abstain = C_answer out" by simp
      then have False by simp
      then show ?thesis by simp
    next
      case (Cons d dsx)
      with fc have "C_derived (d # dsx) = C_answer out" by simp
      then have False by simp
      then show ?thesis by simp
    qed
  qed
qed

lemma first_derived_bounded: "length (first_derived meds req es) \<le> 4"
proof (induction meds)
  case Nil show ?case by simp
next
  case (Cons m ms)
  show ?case
  proof (cases "decide_derived m req es \<noteq> []")
    case True
    then show "length (first_derived (m # ms) req es) \<le> 4"
      using decide_derived_bounded[of m req es] by simp
  next
    case False
    then show "length (first_derived (m # ms) req es) \<le> 4" using Cons.IH by simp
  qed
qed

theorem derived_nonempty_bounded:
  "decide meds req es = C_derived ds \<Longrightarrow> ds \<noteq> [] \<and> length ds \<le> 4"
proof (unfold decide_def)
  assume eq: "(let o0 = decide_direct req es in
      if o0 \<noteq> [] then C_answer o0
      else case first_derived meds req es of [] \<Rightarrow> C_abstain | dsl \<Rightarrow> C_derived dsl) = C_derived ds"
  show "ds \<noteq> [] \<and> length ds \<le> 4"
  proof (cases "decide_direct req es \<noteq> []")
    case True
    with eq have "C_answer (decide_direct req es) = C_derived ds" by simp
    then have False by simp
    then show ?thesis by simp
  next
    case False
    with eq have fc: "(case first_derived meds req es of
        [] \<Rightarrow> C_abstain | dsl \<Rightarrow> C_derived dsl) = C_derived ds" by simp
    then show ?thesis
    proof (cases "first_derived meds req es")
      case Nil
      with fc have "C_abstain = C_derived ds" by simp
      then have False by simp
      then show ?thesis by simp
    next
      case (Cons d dsx)
      with fc have cde: "C_derived (d # dsx) = C_derived ds" by simp
      then have dsq: "ds = d # dsx" by simp
      then have nz: "ds \<noteq> []" by simp
      from dsq have len: "length ds = Suc (length dsx)" by simp
      from first_derived_bounded[of meds req es] \<open>first_derived meds req es = d # dsx\<close>
      have fb: "Suc (length dsx) \<le> 4" by simp
      from len fb have lb: "length ds \<le> 4" by simp
      from nz lb show ?thesis ..
    qed
  qed
qed


text \<open>The explicit abstention rule, plainly: if the fetch brought no edge the
request declares (no direct witness, and no mediator-parent pair whose second
hop is a declared forward relation), the decision abstains - it never invents a
line.\<close>

text \<open>Obtains-forms of the two witnessed theorems, stated as standalone lemmas
so their small final blast steps run in a clean context (a blast in the context
of the no_matching_edges_abstains premises below diverges).\<close>

lemma decide_direct_nonemptyE:
  assumes ne: "decide_direct req es \<noteq> []"
  obtains e where "e \<in> set es" "declared_witness req e"
proof -
  from ne obtain x where x: "x \<in> set (decide_direct req es)"
    by (cases "decide_direct req es") auto
  note w = decide_direct_witnessed[of req es, THEN bspec, OF x]
  from w obtain e where
    w1: "e \<in> set es" and w2: "declared_witness req e" by blast
  show ?thesis by (rule that[OF w1 w2])
qed

lemma decide_derived_nonemptyE:
  assumes ne: "decide_derived med req es \<noteq> []"
  obtains e1 e2 where
    "e1 \<in> set es" "e2 \<in> set es" "c_rel e1 = med" "c_start e1 = c_concept req"
    "c_rel e2 \<in> set (fwd_specs req)" "c_start e2 = c_end e1"
proof -
  from ne obtain dl where dl: "dl \<in> set (decide_derived med req es)"
    by (cases "decide_derived med req es") auto
  from dl have fldl: "dl \<in> set (foldl add_dline [] (derived_pairs med req es))"
    by (simp add: decide_derived_def)
  note dn = fold_add_dline_new0[where l="derived_pairs med req es", OF fldl]
  then obtain x where
    x: "x \<in> set (derived_pairs med req es)" and
    dl_line: "d_line dl = cp ''(via '' @ d_via dl @ cp '') '' @ render_edge (snd (snd x))" and
    dl_hop2: "d_hop2 dl = claim_of (snd (snd x))" and
    dl_hop1: "d_hop1 dl = claim_of (fst (snd x))" and
    dl_via: "d_via dl = fst x"
    unfolding dline_new_def by blast
  obtain p e1 e2 where pe: "x = (p, e1, e2)" by (cases x) auto
  from x pe have w: "(p, e1, e2) \<in> set (derived_pairs med req es)" by simp
  note ws = derived_pairs_witnessed[OF w]
  from ws(4) ws(6) have s2: "c_start e2 = c_end e1" by simp
  show ?thesis by (rule that[OF ws(1) ws(5) ws(2) ws(3) ws(7) s2])
qed

corollary no_matching_edges_abstains:
  assumes dir: "\<forall>e \<in> set es. \<not> declared_witness req e"
    and der: "\<And>m e1 e2. m \<in> set meds \<Longrightarrow> e1 \<in> set es \<Longrightarrow> e2 \<in> set es \<Longrightarrow>
      c_rel e1 = m \<Longrightarrow> c_start e1 = c_concept req \<Longrightarrow>
      c_rel e2 \<in> set (fwd_specs req) \<Longrightarrow> c_start e2 = c_end e1 \<Longrightarrow> False"
  shows "decide meds req es = C_abstain"
proof -
  have d1: "decide_direct req es = []"
  proof (rule ccontr)
    assume ne: "decide_direct req es \<noteq> []"
    from decide_direct_nonemptyE[OF ne] obtain e where
      e: "e \<in> set es" and w: "declared_witness req e" by blast
    from dir[THEN bspec, OF e] have n: "\<not> declared_witness req e" .
    from n w show False by (rule notE)
  qed
  have d2: "\<forall>m \<in> set meds. decide_derived m req es = []"
  proof (rule ballI)
    fix m assume m: "m \<in> set meds"
    show "decide_derived m req es = []"
    proof (rule ccontr)
      assume ne: "decide_derived m req es \<noteq> []"
      from decide_derived_nonemptyE[OF ne] obtain e1 e2 where
        e1: "e1 \<in> set es" and e2: "e2 \<in> set es" and
        r1: "c_rel e1 = m" and s1: "c_start e1 = c_concept req" and
        r2: "c_rel e2 \<in> set (fwd_specs req)" and s2: "c_start e2 = c_end e1" by blast
      from der[OF m e1 e2 r1 s1 r2 s2] show False .
    qed
  qed
  from iffD2[OF decide_abstain_iff conjI[OF d1 d2]] show "decide meds req es = C_abstain" .
qed

end
