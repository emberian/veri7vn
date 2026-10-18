theory Disc_Algos
  imports Disc_Dtext
begin

text \<open>algorithms (upstream/root/specialists/algorithms). Every answer carries a
witness that the kernel checks before it is stated. Shortest path: Dijkstra
runs untrusted-style, then the result is accepted only with a certificate (a
feasible potential), which proves optimality of the returned walk. Binary
search and sorting are proved against their specifications. Kruskal's tree is
checked by a certificate before it is stated, and the check passing proves
the tree is a spanning tree of minimum weight (theorem @{text a_mst_minimal}).
That Kruskal's tree always passes the check is not proved; a failure would
withhold.\<close>

type_synonym node = String.literal
type_synonym edge = "node \<times> node \<times> rat"

fun wt :: "edge list \<Rightarrow> rat" where
  "wt [] = 0"
| "wt ((u, v, w) # r) = w + wt r"

fun walk :: "edge list \<Rightarrow> node \<Rightarrow> node \<Rightarrow> edge list \<Rightarrow> bool" where
  "walk es s e [] = (s = e)"
| "walk es s e ((u, v, w) # r) = (u = s \<and> (u, v, w) \<in> set es \<and> walk es v e r)"

definition node_list :: "edge list \<Rightarrow> node list" where
  "node_list es = map fst es @ map (\<lambda>x. fst (snd x)) es"

section \<open>Shortest path by certificate\<close>

definition feasible :: "edge list \<Rightarrow> (node \<times> rat) list \<Rightarrow> bool" where
  "feasible es d = (\<forall>x \<in> set es. case x of (u, v, w) \<Rightarrow>
     (case map_of d u of None \<Rightarrow> True
      | Some du \<Rightarrow> (case map_of d v of None \<Rightarrow> False | Some dv \<Rightarrow> dv \<le> du + w)))"

lemma walk_bound:
  assumes feas: "feasible es d"
  shows "walk es s e r \<Longrightarrow> map_of d s = Some ds \<Longrightarrow>
         \<exists>de. map_of d e = Some de \<and> de \<le> ds + wt r"
proof (induction r arbitrary: s ds)
  case Nil
  then show ?case by simp
next
  case (Cons x r)
  obtain u v w where x: "x = (u, v, w)" by (cases x) auto
  have c0: "walk es s e ((u, v, w) # r)" using Cons.prems(1) unfolding x .
  have c: "u = s \<and> (u, v, w) \<in> set es \<and> walk es v e r" using c0[unfolded walk.simps(2)] .
  have u: "u = s" and mem: "(u, v, w) \<in> set es" and wk: "walk es v e r" using c by blast+
  have f: "case map_of d u of None \<Rightarrow> True
      | Some du \<Rightarrow> (case map_of d v of None \<Rightarrow> False | Some dv \<Rightarrow> dv \<le> du + w)"
    using feas mem unfolding feasible_def by force
  from f u Cons.prems(2) obtain dv where dv: "map_of d v = Some dv" "dv \<le> ds + w"
    by (auto split: option.splits)
  from Cons.IH[OF wk dv(1)] obtain de where de: "map_of d e = Some de" "de \<le> dv + wt r" by blast
  have "wt (x # r) = w + wt r" by (simp add: x)
  then show ?case using de dv(2) by (intro exI[of _ de]) (auto)
qed

definition fin_d :: "(node \<times> rat) list \<Rightarrow> (node \<times> rat) list" where
  "fin_d dst = map (\<lambda>n. (n, the (map_of dst n))) (remdups (map fst dst))"

fun bktrack :: "nat \<Rightarrow> (node \<times> edge) list \<Rightarrow> node \<Rightarrow> node \<Rightarrow> edge list \<Rightarrow> edge list option" where
  "bktrack 0 pv s x acc = None"
| "bktrack (Suc f) pv s x acc =
     (if x = s then Some acc
      else case map_of pv x of None \<Rightarrow> None
           | Some (u, v, w) \<Rightarrow> bktrack f pv s u ((u, v, w) # acc))"

datatype spres = SP_found "edge list" rat | SP_unreach | SP_imprecise

definition sp_check :: "edge list \<Rightarrow> node \<Rightarrow> node \<Rightarrow> (node \<times> rat) list \<Rightarrow> (node \<times> edge) list \<Rightarrow> spres" where
  "sp_check es s e dst prev =
     (let d = fin_d dst in
      if \<not> feasible es d \<or> map_of d s \<noteq> Some 0 then SP_imprecise
      else case map_of d e of
             None \<Rightarrow> SP_unreach
           | Some de \<Rightarrow>
               (case bktrack (length es + 1) prev s e [] of
                  None \<Rightarrow> SP_imprecise
                | Some r \<Rightarrow> if walk es s e r \<and> wt r = de then SP_found r de else SP_imprecise))"

text \<open>Whatever the untrusted search produced: a found walk is a walk in the
graph and no walk is lighter.\<close>
theorem sp_found_sound:
  assumes "sp_check es s e dst prev = SP_found r de"
  shows "walk es s e r \<and> wt r = de \<and> (\<forall>r'. walk es s e r' \<longrightarrow> de \<le> wt r')"
proof -
  have key: "feasible es (fin_d dst) \<and> map_of (fin_d dst) s = Some 0 \<and>
             map_of (fin_d dst) e = Some de \<and> walk es s e r \<and> wt r = de"
    using assms by (auto simp: sp_check_def Let_def split: if_splits option.splits)
  have lower: "\<forall>r'. walk es s e r' \<longrightarrow> de \<le> wt r'"
  proof (intro allI impI)
    fix r' assume w: "walk es s e r'"
    from walk_bound[OF _ w, of "fin_d dst" 0] key obtain de' where
      "map_of (fin_d dst) e = Some de'" "de' \<le> 0 + wt r'" by blast
    with key show "de \<le> wt r'" by auto
  qed
  show ?thesis using key lower by blast
qed

theorem sp_unreach_sound:
  assumes "sp_check es s e dst prev = SP_unreach"
  shows "\<not> walk es s e r"
proof
  assume w: "walk es s e r"
  have key: "feasible es (fin_d dst) \<and> map_of (fin_d dst) s = Some 0 \<and> map_of (fin_d dst) e = None"
    using assms by (auto simp: sp_check_def Let_def split: if_splits option.splits)
  from walk_bound[OF _ w, of "fin_d dst" 0] key obtain de where "map_of (fin_d dst) e = Some de" by blast
  with key show False by simp
qed

type_synonym st = "(node \<times> rat) list \<times> (node \<times> edge) list"

definition relax1 :: "rat \<Rightarrow> st \<Rightarrow> edge \<Rightarrow> st" where
  "relax1 du st x = (case x of (a, b, w) \<Rightarrow> (case st of (dst, prev) \<Rightarrow>
     (let nd = du + w in
      (case map_of dst b of
         None \<Rightarrow> ((b, nd) # dst, (b, x) # prev)
       | Some old \<Rightarrow> if nd < old then ((b, nd) # dst, (b, x) # prev) else (dst, prev)))))"

definition relax :: "node \<Rightarrow> rat \<Rightarrow> edge list \<Rightarrow> st \<Rightarrow> st" where
  "relax u du es st = foldl (relax1 du) st (filter (\<lambda>x. fst x = u) es)"

definition pick :: "(node \<times> rat) list \<Rightarrow> node list \<Rightarrow> (node \<times> rat) option" where
  "pick dst dn = foldl (\<lambda>acc c. case acc of None \<Rightarrow> Some c
        | Some m \<Rightarrow> if snd c < snd m then Some c else acc)
      None (filter (\<lambda>c. fst c \<notin> set dn) (fin_d dst))"

fun dijk :: "nat \<Rightarrow> edge list \<Rightarrow> (node \<times> rat) list \<Rightarrow> (node \<times> edge) list \<Rightarrow> node list \<Rightarrow> st" where
  "dijk 0 es dst prev dn = (dst, prev)"
| "dijk (Suc f) es dst prev dn =
     (case pick dst dn of
        None \<Rightarrow> (dst, prev)
      | Some (u, du) \<Rightarrow>
          (case relax u du es (dst, prev) of (dst', prev') \<Rightarrow> dijk f es dst' prev' (u # dn)))"

section \<open>Minimum spanning tree (Kruskal)\<close>

definition lab_merge :: "node \<Rightarrow> node \<Rightarrow> (node \<times> node) list \<Rightarrow> (node \<times> node) list" where
  "lab_merge la lb lab = map (\<lambda>p. (fst p, if snd p = lb then la else snd p)) lab"

fun kr :: "edge list \<Rightarrow> (node \<times> node) list \<Rightarrow> edge list \<Rightarrow> edge list" where
  "kr [] lab acc = rev acc"
| "kr ((a, b, w) # r) lab acc =
     (if the (map_of lab a) = the (map_of lab b) then kr r lab acc
      else kr r (lab_merge (the (map_of lab a)) (the (map_of lab b)) lab) ((a, b, w) # acc))"

lemma kr_subset: "set (kr es lab acc) \<subseteq> set es \<union> set acc"
proof (induction es arbitrary: lab acc)
  case Nil
  show ?case by simp
next
  case (Cons x r)
  obtain a b w where x: "x = (a, b, w)" by (cases x) auto
  show ?case
  proof (cases "the (map_of lab a) = the (map_of lab b)")
    case True
    have "set (kr r lab acc) \<subseteq> set r \<union> set acc" by (rule Cons.IH)
    then show ?thesis using True x by auto
  next
    case False
    have "set (kr r (lab_merge (the (map_of lab a)) (the (map_of lab b)) lab) ((a, b, w) # acc))
          \<subseteq> set r \<union> set ((a, b, w) # acc)" by (rule Cons.IH)
    then show ?thesis using False x by auto
  qed
qed

definition mst_kernel :: "edge list \<Rightarrow> edge list option" where
  "mst_kernel es =
     (let ns = remdups (node_list es);
          t = kr (sort_key (\<lambda>x. snd (snd x)) es) (map (\<lambda>n. (n, n)) ns) []
      in if ns \<noteq> [] \<and> length t = length ns - 1 then Some t else None)"

theorem mst_edges:
  "mst_kernel es = Some t \<Longrightarrow> set t \<subseteq> set es \<and> length t + 1 = length (remdups (node_list es))
     \<and> (0 < length (remdups (node_list es)))"
proof -
  assume h: "mst_kernel es = Some t"
  have sub: "set t \<subseteq> set es"
    using h kr_subset[of "sort_key (\<lambda>x. snd (snd x)) es" "map (\<lambda>n. (n, n)) (remdups (node_list es))" "[]"]
    by (auto simp: mst_kernel_def Let_def split: if_splits)
  have ne: "remdups (node_list es) \<noteq> []" and len: "length t = length (remdups (node_list es)) - 1"
    using h by (auto simp: mst_kernel_def Let_def split: if_splits)
  have pos: "0 < length (remdups (node_list es))" using ne by simp
  show ?thesis using sub len pos by auto
qed

section \<open>Minimum spanning tree: an independent minimality certificate\<close>

text \<open>The specification, stated without reference to Kruskal. An edge joins
its two ends in either direction; a list of edges connects a node list when
every two of its nodes are joined by a path of those edges; a spanning tree of
the graph is a list of graph edges, one fewer than the graph's nodes, that
connects all of the graph's nodes. Weight is @{const wt}, the sum of the edge
weights.\<close>

definition adj :: "edge list \<Rightarrow> node \<Rightarrow> node \<Rightarrow> bool" where
  "adj F u v = (\<exists>w. (u, v, w) \<in> set F \<or> (v, u, w) \<in> set F)"

definition connects :: "edge list \<Rightarrow> node list \<Rightarrow> bool" where
  "connects F V = (\<forall>x \<in> set V. \<forall>y \<in> set V. (adj F)\<^sup>*\<^sup>* x y)"

definition spans :: "edge list \<Rightarrow> edge list \<Rightarrow> bool" where
  "spans t es = (set t \<subseteq> set es \<and> length t + 1 = length (remdups (node_list es))
      \<and> connects t (node_list es))"

text \<open>The checker. Labels: every node starts as its own label; joining an
edge sends every node labelled like its second end to the label of its first
end (the closure is built with the two end labels evaluated once). For each
edge weight c of the graph, the number of classes left after joining every
graph edge of weight at most c is @{text "ncomp c es"}. A tree passes when it
is made of graph edges, has one edge fewer than the graph's nodes, joins every
node into one class, and for every weight c has exactly @{text "ncomp c es - 1"}
edges heavier than c. Any spanning tree has at least that many (each heavier
edge merges at most two classes), and summing over the weights gives the
minimality theorem below. Nothing here refers to Kruskal.\<close>

definition lmerge :: "(node \<Rightarrow> node) \<Rightarrow> node \<Rightarrow> node \<Rightarrow> node \<Rightarrow> node" where
  "lmerge f a b = (let la = f a; lb = f b in (\<lambda>x. let lx = f x in if lx = lb then la else lx))"

fun mergeall :: "(node \<Rightarrow> node) \<Rightarrow> edge list \<Rightarrow> node \<Rightarrow> node" where
  "mergeall f [] = f"
| "mergeall f ((a, b, w) # r) = mergeall (lmerge f a b) r"

definition const_on :: "(node \<Rightarrow> node) \<Rightarrow> node list \<Rightarrow> bool" where
  "const_on f V = (\<forall>y \<in> set V. f y = f (hd V))"

definition low_edges :: "rat \<Rightarrow> edge list \<Rightarrow> edge list" where
  "low_edges c es = filter (\<lambda>e. snd (snd e) \<le> c) es"

definition ncomp :: "rat \<Rightarrow> edge list \<Rightarrow> nat" where
  "ncomp c es = length (remdups (map (mergeall id (low_edges c es)) (remdups (node_list es))))"

definition cnt_gt :: "rat \<Rightarrow> edge list \<Rightarrow> nat" where
  "cnt_gt c F = length (filter (\<lambda>e. c < snd (snd e)) F)"

definition wts :: "edge list \<Rightarrow> rat list" where
  "wts es = sort (remdups (map (\<lambda>e. snd (snd e)) es))"

definition mst_cert :: "edge list \<Rightarrow> edge list \<Rightarrow> bool" where
  "mst_cert es t = (set t \<subseteq> set es \<and> length t + 1 = length (remdups (node_list es))
      \<and> const_on (mergeall id t) (remdups (node_list es))
      \<and> (\<forall>c \<in> set (wts es). cnt_gt c t + 1 = ncomp c es))"

lemma lmerge_apply: "lmerge f a b x = (if f x = f b then f a else f x)"
  by (simp add: lmerge_def Let_def)

lemma lmerge_same: "f a = f b \<Longrightarrow> lmerge f a b = f"
  by (rule ext) (simp add: lmerge_apply)

lemma mergeall_mono: "f x = f y \<Longrightarrow> mergeall f F x = mergeall f F y"
proof (induction F arbitrary: f)
  case Nil
  then show ?case by simp
next
  case (Cons e r)
  obtain a b w where e: "e = (a, b, w)" by (cases e) auto
  have "lmerge f a b x = lmerge f a b y" using Cons.prems by (simp add: lmerge_apply)
  then have "mergeall (lmerge f a b) r x = mergeall (lmerge f a b) r y" by (rule Cons.IH)
  then show ?case using e by simp
qed

lemma mergeall_joins: "(a, b, w) \<in> set F \<Longrightarrow> mergeall f F a = mergeall f F b"
proof (induction F arbitrary: f)
  case Nil
  then show ?case by simp
next
  case (Cons e r)
  obtain a' b' w' where e: "e = (a', b', w')" by (cases e) auto
  show ?case
  proof (cases "e = (a, b, w)")
    case True
    have "lmerge f a b a = lmerge f a b b" by (simp add: lmerge_apply)
    then have "mergeall (lmerge f a b) r a = mergeall (lmerge f a b) r b" by (rule mergeall_mono)
    then show ?thesis using True by simp
  next
    case False
    then have "(a, b, w) \<in> set r" using Cons.prems by auto
    then have "mergeall (lmerge f a' b') r a = mergeall (lmerge f a' b') r b" by (rule Cons.IH)
    then show ?thesis using e by simp
  qed
qed

lemma mergeall_connects:
  assumes "set F \<subseteq> set G" "(adj F)\<^sup>*\<^sup>* x y"
  shows "mergeall f G x = mergeall f G y"
  using assms(2)
proof (induction rule: rtranclp_induct)
  case base
  then show ?case by simp
next
  case (step u v)
  obtain w where "(u, v, w) \<in> set F \<or> (v, u, w) \<in> set F" using step.hyps(2) by (auto simp: adj_def)
  then have uv: "(u, v, w) \<in> set G \<or> (v, u, w) \<in> set G" using assms(1) by auto
  have "mergeall f G u = mergeall f G v"
  proof (cases "(u, v, w) \<in> set G")
    case True
    then show ?thesis by (rule mergeall_joins)
  next
    case False
    then have "(v, u, w) \<in> set G" using uv by simp
    then have "mergeall f G v = mergeall f G u" by (rule mergeall_joins)
    then show ?thesis by simp
  qed
  then show ?case using step.IH by simp
qed

lemma mergeall_reach:
  assumes "\<forall>x y. f x = f y \<longrightarrow> (adj G)\<^sup>*\<^sup>* x y" "set F \<subseteq> set G"
  shows "\<forall>x y. mergeall f F x = mergeall f F y \<longrightarrow> (adj G)\<^sup>*\<^sup>* x y"
  using assms
proof (induction F arbitrary: f)
  case Nil
  then show ?case by simp
next
  case (Cons e r)
  obtain a b w where e: "e = (a, b, w)" by (cases e) auto
  have abG: "(a, b, w) \<in> set G" using Cons.prems(2) e by simp
  have ab: "adj G a b" using abG by (auto simp: adj_def)
  have ba: "adj G b a" using abG by (auto simp: adj_def)
  have R: "\<And>x y. f x = f y \<Longrightarrow> (adj G)\<^sup>*\<^sup>* x y" using Cons.prems(1) by blast
  have inv: "\<forall>x y. lmerge f a b x = lmerge f a b y \<longrightarrow> (adj G)\<^sup>*\<^sup>* x y"
  proof (intro allI impI)
    fix x y assume h: "lmerge f a b x = lmerge f a b y"
    consider "f x = f b" "f y = f b" | "f x = f b" "f y \<noteq> f b" | "f x \<noteq> f b" "f y = f b"
      | "f x \<noteq> f b" "f y \<noteq> f b" by blast
    then show "(adj G)\<^sup>*\<^sup>* x y"
    proof cases
      case 1
      then have "f x = f y" by simp
      then show ?thesis by (rule R)
    next
      case 2
      have fa: "f a = f y" using h 2 by (simp add: lmerge_apply)
      have xb: "(adj G)\<^sup>*\<^sup>* x b" by (rule R) (rule 2(1))
      have bA: "(adj G)\<^sup>*\<^sup>* b a" by (rule r_into_rtranclp[of "adj G", OF ba])
      have ay: "(adj G)\<^sup>*\<^sup>* a y" by (rule R) (rule fa)
      show ?thesis by (rule rtranclp_trans[OF rtranclp_trans[OF xb bA] ay])
    next
      case 3
      have fa: "f x = f a" using h 3 by (simp add: lmerge_apply)
      have xa: "(adj G)\<^sup>*\<^sup>* x a" by (rule R) (rule fa)
      have aB: "(adj G)\<^sup>*\<^sup>* a b" by (rule r_into_rtranclp[of "adj G", OF ab])
      have byy: "(adj G)\<^sup>*\<^sup>* b y" by (rule R) (rule 3(2)[symmetric])
      show ?thesis by (rule rtranclp_trans[OF rtranclp_trans[OF xa aB] byy])
    next
      case 4
      then have "f x = f y" using h by (simp add: lmerge_apply)
      then show ?thesis by (rule R)
    qed
  qed
  have sub: "set r \<subseteq> set G" using Cons.prems(2) by simp
  have "\<forall>x y. mergeall (lmerge f a b) r x = mergeall (lmerge f a b) r y \<longrightarrow> (adj G)\<^sup>*\<^sup>* x y"
    by (rule Cons.IH[OF inv sub])
  then show ?case using e by simp
qed

lemma connects_iff_const: "connects F V \<longleftrightarrow> const_on (mergeall id F) V"
proof
  assume c: "connects F V"
  show "const_on (mergeall id F) V" unfolding const_on_def
  proof
    fix y assume y: "y \<in> set V"
    then have "V \<noteq> []" by auto
    then have "hd V \<in> set V" by (rule hd_in_set)
    then have "(adj F)\<^sup>*\<^sup>* y (hd V)" using c y by (auto simp: connects_def)
    then show "mergeall id F y = mergeall id F (hd V)" by (rule mergeall_connects[OF subset_refl])
  qed
next
  assume k: "const_on (mergeall id F) V"
  have inv: "\<forall>x y. id x = id y \<longrightarrow> (adj F)\<^sup>*\<^sup>* x y" by simp
  have r: "\<forall>x y. mergeall id F x = mergeall id F y \<longrightarrow> (adj F)\<^sup>*\<^sup>* x y"
    by (rule mergeall_reach[OF inv subset_refl])
  show "connects F V" unfolding connects_def
  proof (intro ballI)
    fix x y assume "x \<in> set V" "y \<in> set V"
    then have "mergeall id F x = mergeall id F y" using k by (auto simp: const_on_def)
    then show "(adj F)\<^sup>*\<^sup>* x y" using r by blast
  qed
qed

lemma connected_iff: "const_on (mergeall id es) (remdups (node_list es)) \<longleftrightarrow> connects es (node_list es)"
  by (simp add: connects_iff_const[symmetric] connects_def)

lemma card_lmerge:
  assumes "finite S"
  shows "card (f ` S) \<le> card (lmerge f a b ` S) + 1"
proof -
  define g where "g = (\<lambda>y. if y = f b then f a else y)"
  have "lmerge f a b = g \<circ> f" by (rule ext) (simp add: lmerge_apply g_def)
  then have img: "lmerge f a b ` S = g ` (f ` S)" by (simp add: image_comp)
  have fin: "finite (f ` S)" using assms by simp
  have inj: "inj_on g (f ` S - {f b})" by (auto simp: inj_on_def g_def)
  have "card (f ` S) \<le> card (insert (f b) (f ` S - {f b}))" using fin by (intro card_mono) auto
  also have "\<dots> \<le> card (f ` S - {f b}) + 1" using fin by (subst card_insert_disjoint) auto
  also have "\<dots> = card (g ` (f ` S - {f b})) + 1" using inj by (simp add: card_image)
  also have "\<dots> \<le> card (g ` (f ` S)) + 1" using fin by (intro add_right_mono card_mono) auto
  finally have "card (f ` S) \<le> card (g ` (f ` S)) + 1" .
  then show ?thesis using img by simp
qed

lemma mergeall_count:
  assumes "finite S" "set F \<subseteq> set es"
      "\<forall>e \<in> set es. snd (snd e) \<le> c \<longrightarrow> f (fst e) = f (fst (snd e))"
  shows "card (f ` S) \<le> card (mergeall f F ` S) + cnt_gt c F"
  using assms(2,3)
proof (induction F arbitrary: f)
  case Nil
  then show ?case by (simp add: cnt_gt_def)
next
  case (Cons e r)
  obtain a b w where e: "e = (a, b, w)" by (cases e) auto
  have sub: "set r \<subseteq> set es" using Cons.prems(1) by simp
  have inv: "\<forall>e \<in> set es. snd (snd e) \<le> c \<longrightarrow> lmerge f a b (fst e) = lmerge f a b (fst (snd e))"
    using Cons.prems(2) by (auto simp: lmerge_apply)
  have ih: "card (lmerge f a b ` S) \<le> card (mergeall (lmerge f a b) r ` S) + cnt_gt c r"
    by (rule Cons.IH[OF sub inv])
  have m: "mergeall f (e # r) = mergeall (lmerge f a b) r" using e by simp
  show ?case
  proof (cases "w \<le> c")
    case True
    have "(a, b, w) \<in> set es" using Cons.prems(1) e by simp
    then have "f a = f b" using Cons.prems(2) True by fastforce
    then have lm: "lmerge f a b = f" by (rule lmerge_same)
    have nc: "\<not> c < w" using True by (simp add: not_less)
    have cn: "cnt_gt c (e # r) = cnt_gt c r" using e nc by (simp add: cnt_gt_def)
    show ?thesis using ih unfolding m cn lm by simp
  next
    case False
    have lt: "c < w" using False by (simp add: not_le)
    have cn: "cnt_gt c (e # r) = cnt_gt c r + 1" using e lt by (simp add: cnt_gt_def)
    have cl: "card (f ` S) \<le> card (lmerge f a b ` S) + 1" by (rule card_lmerge[OF assms(1)])
    show ?thesis unfolding m cn using cl ih by linarith
  qed
qed

lemma low_joined:
  assumes "e \<in> set es" "snd (snd e) \<le> c"
  shows "mergeall id (low_edges c es) (fst e) = mergeall id (low_edges c es) (fst (snd e))"
proof -
  obtain a b w where e: "e = (a, b, w)" by (cases e) auto
  have "(a, b, w) \<in> set (low_edges c es)" using assms e by (simp add: low_edges_def)
  then have "mergeall id (low_edges c es) a = mergeall id (low_edges c es) b" by (rule mergeall_joins)
  then show ?thesis using e by simp
qed

lemma spans_lower:
  assumes "spans t' es"
  shows "ncomp c es \<le> cnt_gt c t' + 1"
proof -
  let ?S = "set (node_list es)"
  let ?f = "mergeall id (low_edges c es)"
  have sub: "set t' \<subseteq> set es" and con: "connects t' (node_list es)"
    and len: "length t' + 1 = length (remdups (node_list es))"
    using assms by (auto simp: spans_def)
  have inv: "\<forall>e \<in> set es. snd (snd e) \<le> c \<longrightarrow> ?f (fst e) = ?f (fst (snd e))"
    using low_joined by blast
  have cnt: "card (?f ` ?S) \<le> card (mergeall ?f t' ` ?S) + cnt_gt c t'"
    by (rule mergeall_count[OF finite_set sub inv])
  have ne: "node_list es \<noteq> []" using len by auto
  have h: "hd (node_list es) \<in> ?S" using ne by (rule hd_in_set)
  have "\<forall>y \<in> ?S. mergeall ?f t' y = mergeall ?f t' (hd (node_list es))"
  proof
    fix y assume y: "y \<in> ?S"
    have "(adj t')\<^sup>*\<^sup>* y (hd (node_list es))" using con y h by (auto simp: connects_def)
    then show "mergeall ?f t' y = mergeall ?f t' (hd (node_list es))"
      by (rule mergeall_connects[OF subset_refl])
  qed
  then have "mergeall ?f t' ` ?S \<subseteq> {mergeall ?f t' (hd (node_list es))}" by auto
  then have "card (mergeall ?f t' ` ?S) \<le> card {mergeall ?f t' (hd (node_list es))}"
    by (intro card_mono) auto
  then have one: "card (mergeall ?f t' ` ?S) \<le> 1" by simp
  have "ncomp c es = card (?f ` ?S)" by (simp add: ncomp_def length_remdups_card_conv)
  then show ?thesis using cnt one by linarith
qed

fun tele :: "rat list \<Rightarrow> rat \<Rightarrow> rat" where
  "tele (c # d # r) w = (if c < w then d - c else 0) + tele (d # r) w"
| "tele _ w = 0"

fun tsum :: "rat list \<Rightarrow> edge list \<Rightarrow> rat" where
  "tsum (c # d # r) F = (d - c) * of_nat (cnt_gt c F) + tsum (d # r) F"
| "tsum _ F = 0"

lemma tele_low: "sorted_wrt (<) (c # r) \<Longrightarrow> w \<le> c \<Longrightarrow> tele (c # r) w = 0"
proof (induction r arbitrary: c)
  case Nil
  then show ?case by simp
next
  case (Cons d r)
  have cd: "c < d" using Cons.prems(1) by simp
  have wd: "w \<le> d" using cd Cons.prems(2) by linarith
  have sd: "sorted_wrt (<) (d # r)" using Cons.prems(1) by simp
  have t: "tele (d # r) w = 0" by (rule Cons.IH[OF sd wd])
  have nc: "\<not> c < w" using Cons.prems(2) by (simp add: not_less)
  show ?case using t nc by simp
qed

lemma tele_val: "sorted_wrt (<) (c # r) \<Longrightarrow> w \<in> set (c # r) \<Longrightarrow> c + tele (c # r) w = w"
proof (induction r arbitrary: c)
  case Nil
  then show ?case by simp
next
  case (Cons d r)
  have cd: "c < d" and sd: "sorted_wrt (<) (d # r)" using Cons.prems(1) by auto
  show ?case
  proof (cases "w = c")
    case True
    have wd: "w \<le> d" using cd True by linarith
    have "tele (d # r) w = 0" by (rule tele_low[OF sd wd])
    then show ?thesis using True by simp
  next
    case False
    then have wr: "w \<in> set (d # r)" using Cons.prems(2) by simp
    have cw: "c < w" using Cons.prems(1) wr by auto
    have ih: "d + tele (d # r) w = w" by (rule Cons.IH[OF sd wr])
    have "tele (c # d # r) w = (d - c) + tele (d # r) w" using cw by simp
    then show ?thesis using ih by linarith
  qed
qed

lemma tsum_nil: "tsum (c # r) [] = 0"
  by (induction r arbitrary: c) (simp_all add: cnt_gt_def)

lemma tsum_cons: "tsum (c # r) (e # F) = tele (c # r) (snd (snd e)) + tsum (c # r) F"
proof (induction r arbitrary: c)
  case Nil
  then show ?case by simp
next
  case (Cons d r)
  show ?case by (cases "c < snd (snd e)") (simp_all add: Cons.IH cnt_gt_def algebra_simps)
qed

lemma wt_layer:
  assumes "sorted_wrt (<) (c # r)" "\<forall>e \<in> set F. snd (snd e) \<in> set (c # r)"
  shows "wt F = c * of_nat (length F) + tsum (c # r) F"
  using assms(2)
proof (induction F)
  case Nil
  then show ?case by (simp add: tsum_nil)
next
  case (Cons e F)
  obtain a b w where e: "e = (a, b, w)" by (cases e) auto
  have w: "w \<in> set (c # r)" using Cons.prems e by simp
  have ih: "wt F = c * of_nat (length F) + tsum (c # r) F" using Cons.prems by (intro Cons.IH) simp
  have tv: "c + tele (c # r) w = w" by (rule tele_val[OF assms(1) w])
  have A: "wt (e # F) = w + wt F" using e by simp
  have B: "tsum (c # r) (e # F) = tele (c # r) w + tsum (c # r) F" using e tsum_cons[of c r e F] by simp
  have C: "c * of_nat (length (e # F)) = c + c * of_nat (length F)" by (simp add: algebra_simps)
  show ?case unfolding A B C ih using tv by linarith
qed

lemma tsum_mono:
  "sorted_wrt (<) (c # r) \<Longrightarrow> (\<forall>x \<in> set (c # r). cnt_gt x t \<le> cnt_gt x t') \<Longrightarrow>
     tsum (c # r) t \<le> tsum (c # r) t'"
proof (induction r arbitrary: c)
  case Nil
  then show ?case by simp
next
  case (Cons d r)
  have cd: "c < d" and sd: "sorted_wrt (<) (d # r)" using Cons.prems(1) by auto
  have le: "cnt_gt c t \<le> cnt_gt c t'" using Cons.prems(2) by simp
  have all: "\<forall>x \<in> set (d # r). cnt_gt x t \<le> cnt_gt x t'" using Cons.prems(2) by simp
  have ih: "tsum (d # r) t \<le> tsum (d # r) t'" by (rule Cons.IH[OF sd all])
  have dc: "0 \<le> d - c" using cd by linarith
  have m: "(d - c) * of_nat (cnt_gt c t) \<le> (d - c) * of_nat (cnt_gt c t')"
    using le dc by (intro mult_left_mono) simp_all
  show ?case using add_mono[OF m ih] by simp
qed

lemma wts_sorted: "sorted_wrt (<) (wts es)"
  by (simp add: wts_def strict_sorted_iff)

lemma wts_set: "set (wts es) = (\<lambda>e. snd (snd e)) ` set es"
  by (simp add: wts_def)

theorem mst_cert_minimal:
  assumes c: "mst_cert es t" and s: "spans t' es"
  shows "wt t \<le> wt t'"
proof -
  have sub: "set t \<subseteq> set es" and len: "length t + 1 = length (remdups (node_list es))"
    and cn: "\<forall>x \<in> set (wts es). cnt_gt x t + 1 = ncomp x es"
    using c by (auto simp: mst_cert_def)
  have sub': "set t' \<subseteq> set es" and len': "length t' + 1 = length (remdups (node_list es))"
    using s by (auto simp: spans_def)
  have "es \<noteq> []" using len by (auto simp: node_list_def)
  then have "wts es \<noteq> []" using wts_set[of es] by auto
  then obtain c0 r where cs: "wts es = c0 # r" by (cases "wts es") auto
  have srt: "sorted_wrt (<) (c0 # r)" using wts_sorted[of es] cs by simp
  have ws: "set (c0 # r) = (\<lambda>e. snd (snd e)) ` set es" using wts_set[of es] cs by simp
  have inT: "\<forall>e \<in> set t. snd (snd e) \<in> set (c0 # r)" unfolding ws using sub by auto
  have inT': "\<forall>e \<in> set t'. snd (snd e) \<in> set (c0 # r)" unfolding ws using sub' by auto
  have mono: "\<forall>x \<in> set (c0 # r). cnt_gt x t \<le> cnt_gt x t'"
  proof
    fix x assume "x \<in> set (c0 # r)"
    then have "x \<in> set (wts es)" using cs by simp
    then have "cnt_gt x t + 1 = ncomp x es" using cn by blast
    moreover have "ncomp x es \<le> cnt_gt x t' + 1" by (rule spans_lower[OF s])
    ultimately show "cnt_gt x t \<le> cnt_gt x t'" by linarith
  qed
  have "wt t = c0 * of_nat (length t) + tsum (c0 # r) t" by (rule wt_layer[OF srt inT])
  moreover have "wt t' = c0 * of_nat (length t') + tsum (c0 # r) t'" by (rule wt_layer[OF srt inT'])
  moreover have "length t = length t'" using len len' by simp
  moreover have "tsum (c0 # r) t \<le> tsum (c0 # r) t'" by (rule tsum_mono[OF srt mono])
  ultimately show ?thesis by simp
qed

theorem mst_cert_spans: "mst_cert es t \<Longrightarrow> spans t es"
proof -
  assume c: "mst_cert es t"
  have "const_on (mergeall id t) (remdups (node_list es))" using c by (simp add: mst_cert_def)
  then have "connects t (remdups (node_list es))" by (simp add: connects_iff_const)
  then have "connects t (node_list es)" by (simp add: connects_def)
  then show "spans t es" using c by (simp add: mst_cert_def spans_def)
qed

section \<open>Binary search\<close>

datatype bsres = BS_found nat nat | BS_none nat | BS_fuel

fun bs :: "nat \<Rightarrow> rat list \<Rightarrow> rat \<Rightarrow> int \<Rightarrow> int \<Rightarrow> nat \<Rightarrow> bsres" where
  "bs 0 xs x lo hi pr = BS_fuel"
| "bs (Suc f) xs x lo hi pr =
     (if lo \<le> hi then
        (let mid = (lo + hi) div 2 in
         if xs ! nat mid = x then BS_found (nat mid) (pr + 1)
         else if xs ! nat mid < x then bs f xs x (mid + 1) hi (pr + 1)
         else bs f xs x lo (mid - 1) (pr + 1))
      else BS_none pr)"

lemma bs_sound:
  assumes srt: "sorted xs"
  shows "0 \<le> lo \<Longrightarrow> hi < int (length xs) \<Longrightarrow>
         (\<forall>i < length xs. (int i < lo \<or> hi < int i) \<longrightarrow> xs ! i \<noteq> x) \<Longrightarrow>
         (bs f xs x lo hi pr = BS_found i p \<longrightarrow> i < length xs \<and> xs ! i = x) \<and>
         (bs f xs x lo hi pr = BS_none p \<longrightarrow> x \<notin> set xs)"
proof (induction f arbitrary: lo hi pr)
  case 0
  show ?case by simp
next
  case (Suc f)
  note lo0 = Suc.prems(1) and hi0 = Suc.prems(2) and inv = Suc.prems(3)
  show ?case
  proof (cases "lo \<le> hi")
    case False
    have "x \<notin> set xs"
    proof
      assume "x \<in> set xs"
      then obtain i where i: "i < length xs" "xs ! i = x" by (auto simp: in_set_conv_nth)
      have "int i < lo \<or> hi < int i" using False by arith
      then show False using inv i by blast
    qed
    then show ?thesis using False by simp
  next
    case True
    define mid where "mid = (lo + hi) div 2"
    have m1: "lo \<le> mid" and m2: "mid \<le> hi" unfolding mid_def using True by arith+
    have m3: "0 \<le> mid" using m1 lo0 by arith
    define m where "m = nat mid"
    have mi: "int m = mid" unfolding m_def using m3 by simp
    have ml: "m < length xs" using mi m2 hi0 by arith
    show ?thesis
    proof (cases "xs ! m = x")
      assume eq: "xs ! m = x"
      then show ?thesis using True ml eq mid_def m_def by (auto simp: Let_def)
    next
      assume ne: "xs ! m \<noteq> x"
      show ?thesis
      proof (cases "xs ! m < x")
        assume lt: "xs ! m < x"
        have inv': "\<forall>i < length xs. (int i < mid + 1 \<or> hi < int i) \<longrightarrow> xs ! i \<noteq> x"
        proof (intro allI impI)
          fix i assume il: "i < length xs" and d: "int i < mid + 1 \<or> hi < int i"
          show "xs ! i \<noteq> x"
          proof (cases "int i \<le> mid")
            case True
            then have "i \<le> m" using mi by arith
            then have "xs ! i \<le> xs ! m" using sorted_nth_mono[OF srt _ ml] by blast
            then show ?thesis using lt by auto
          next
            case False
            then show ?thesis using d inv il by auto
          qed
        qed
        have r: "(bs f xs x (mid + 1) hi (pr + 1) = BS_found i p \<longrightarrow> i < length xs \<and> xs ! i = x) \<and>
                 (bs f xs x (mid + 1) hi (pr + 1) = BS_none p \<longrightarrow> x \<notin> set xs)"
          using Suc.IH[of "mid + 1" hi "pr + 1"] m3 hi0 inv' by auto
        show ?thesis using True ne lt r mid_def m_def by (simp add: Let_def)
      next
        assume nlt: "\<not> xs ! m < x"
        have gt: "x < xs ! m" using ne nlt by auto
        have inv': "\<forall>i < length xs. (int i < lo \<or> mid - 1 < int i) \<longrightarrow> xs ! i \<noteq> x"
        proof (intro allI impI)
          fix i assume il: "i < length xs" and d: "int i < lo \<or> mid - 1 < int i"
          show "xs ! i \<noteq> x"
          proof (cases "mid \<le> int i")
            case True
            then have "m \<le> i" using mi by arith
            then have "xs ! m \<le> xs ! i" using sorted_nth_mono[OF srt _ il] by blast
            then show ?thesis using gt by auto
          next
            case False
            then show ?thesis using d inv il by auto
          qed
        qed
        have r: "(bs f xs x lo (mid - 1) (pr + 1) = BS_found i p \<longrightarrow> i < length xs \<and> xs ! i = x) \<and>
                 (bs f xs x lo (mid - 1) (pr + 1) = BS_none p \<longrightarrow> x \<notin> set xs)"
          using Suc.IH[of lo "mid - 1" "pr + 1"] lo0 m2 hi0 inv' by auto
        show ?thesis using True ne nlt r mid_def m_def by (simp add: Let_def)
      qed
    qed
  qed
qed

definition bsearch :: "rat list \<Rightarrow> rat \<Rightarrow> bsres" where
  "bsearch xs x = bs (length xs + 2) xs x 0 (int (length xs) - 1) 0"

theorem bsearch_found:
  "sorted xs \<Longrightarrow> bsearch xs x = BS_found i p \<Longrightarrow> i < length xs \<and> xs ! i = x"
  unfolding bsearch_def using bs_sound[of xs 0 "int (length xs) - 1" x "length xs + 2" 0 i p] by auto

theorem bsearch_none:
  "sorted xs \<Longrightarrow> bsearch xs x = BS_none p \<Longrightarrow> x \<notin> set xs"
  unfolding bsearch_def using bs_sound[of xs 0 "int (length xs) - 1" x "length xs + 2" 0 _ p] by auto

section \<open>Sorting\<close>

fun ins :: "rat \<Rightarrow> rat list \<Rightarrow> rat list" where
  "ins x [] = [x]"
| "ins x (y # ys) = (if x \<le> y then x # y # ys else y # ins x ys)"

fun isort :: "rat list \<Rightarrow> rat list" where
  "isort [] = []"
| "isort (x # xs) = ins x (isort xs)"

lemma set_ins: "set (ins x ys) = insert x (set ys)"
  by (induction ys) auto

lemma sorted_ins: "sorted ys \<Longrightarrow> sorted (ins x ys)"
  by (induction ys) (auto simp: set_ins sorted_simps)

lemma count_ins: "count_list (ins x ys) a = count_list ys a + (if x = a then 1 else 0)"
  by (induction ys) auto

theorem isort_correct: "sorted (isort xs) \<and> (\<forall>a. count_list (isort xs) a = count_list xs a)"
  by (induction xs) (auto simp: sorted_ins count_ins)

section \<open>Complexity table\<close>

definition complexity_table :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "complexity_table =
    [(STR ''binary search'', STR ''O(log n)'', STR ''O(log n)''),
     (STR ''linear search'', STR ''O(n)'', STR ''O(n)''),
     (STR ''bubble sort'', STR ''O(n^2)'', STR ''O(n^2)''),
     (STR ''insertion sort'', STR ''O(n^2)'', STR ''O(n^2)''),
     (STR ''selection sort'', STR ''O(n^2)'', STR ''O(n^2)''),
     (STR ''merge sort'', STR ''O(n log n)'', STR ''O(n log n)''),
     (STR ''heap sort'', STR ''O(n log n)'', STR ''O(n log n)''),
     (STR ''heapsort'', STR ''O(n log n)'', STR ''O(n log n)''),
     (STR ''quicksort'', STR ''O(n^2)'', STR ''O(n log n)''),
     (STR ''quick sort'', STR ''O(n^2)'', STR ''O(n log n)''),
     (STR ''breadth-first search'', STR ''O(V + E)'', STR ''O(V + E)''),
     (STR ''bfs'', STR ''O(V + E)'', STR ''O(V + E)''),
     (STR ''depth-first search'', STR ''O(V + E)'', STR ''O(V + E)''),
     (STR ''dfs'', STR ''O(V + E)'', STR ''O(V + E)''),
     (STR ''dijkstra'', STR ''O((V + E) log V) with a binary heap'',
        STR ''O((V + E) log V) with a binary heap'')]"

definition complexity_names :: "String.literal list" where
  "complexity_names = map fst complexity_table"

section \<open>Requests, kernel, reply\<close>

datatype areq =
    A_sp "edge list" nat node node
  | A_sp_need
  | A_mst "edge list"
  | A_mst_need
  | A_bsearch "rat list" rat
  | A_bsearch_need
  | A_sort "rat list" bool
  | A_complexity nat bool

datatype aout =
    AShortest "edge list" rat nat node
  | AUnreach node node
  | ANoNode node
  | AMst "edge list"
  | ADisconnected
  | ABs nat nat
  | ANotFound rat nat
  | AUnsorted
  | ASorted "rat list" bool
  | AComplexity nat bool
  | ANeed nat
  | AImprecise

definition a_kernel :: "areq \<Rightarrow> aout" where
  "a_kernel r = (case r of
     A_sp es n s e \<Rightarrow>
       (if s \<notin> set (node_list es) then ANoNode s
        else if e \<notin> set (node_list es) then ANoNode e
        else (case dijk (length (node_list es) + 1) es [(s, 0)] [] [] of
                (dst, prev) \<Rightarrow>
                  (case sp_check es s e dst prev of
                     SP_found p d \<Rightarrow> AShortest p d n s
                   | SP_unreach \<Rightarrow> AUnreach s e
                   | SP_imprecise \<Rightarrow> AImprecise)))
   | A_sp_need \<Rightarrow> ANeed 0
   | A_mst es \<Rightarrow>
       (if es = [] \<or> \<not> const_on (mergeall id es) (remdups (node_list es)) then ADisconnected
        else (case mst_kernel es of
                Some t \<Rightarrow> if mst_cert es t then AMst t else AImprecise
              | None \<Rightarrow> AImprecise))
   | A_mst_need \<Rightarrow> ANeed 1
   | A_bsearch xs x \<Rightarrow>
       (if \<not> sorted xs then AUnsorted
        else case bsearch xs x of BS_found i p \<Rightarrow> ABs i p | BS_none p \<Rightarrow> ANotFound x p
             | BS_fuel \<Rightarrow> AImprecise)
   | A_bsearch_need \<Rightarrow> ANeed 2
   | A_sort xs desc \<Rightarrow> ASorted (if desc then rev (isort xs) else isort xs) desc
   | A_complexity i avg \<Rightarrow> AComplexity i avg)"

theorem a_shortest_sound:
  "a_kernel (A_sp es n s e) = AShortest p d n' s' \<Longrightarrow>
     walk es s e p \<and> wt p = d \<and> (\<forall>r'. walk es s e r' \<longrightarrow> d \<le> wt r')"
  unfolding a_kernel_def
  by (auto simp: sp_found_sound split: if_splits prod.splits spres.splits)

theorem a_unreach_sound:
  "a_kernel (A_sp es n s e) = AUnreach s' e' \<Longrightarrow> \<not> walk es s e r"
  unfolding a_kernel_def
  by (auto simp: sp_unreach_sound split: if_splits prod.splits spres.splits)

theorem a_nonode:
  "a_kernel (A_sp es n s e) = ANoNode x \<Longrightarrow> x \<notin> set (node_list es)"
  unfolding a_kernel_def by (auto split: if_splits prod.splits spres.splits)

theorem a_mst_minimal:
  assumes "a_kernel (A_mst es) = AMst t"
  shows "spans t es \<and> (\<forall>t'. spans t' es \<longrightarrow> wt t \<le> wt t')"
proof -
  have "mst_cert es t" using assms unfolding a_kernel_def by (auto split: if_splits option.splits)
  then show ?thesis using mst_cert_spans mst_cert_minimal by blast
qed

theorem a_mst_disconnected:
  "a_kernel (A_mst es) = ADisconnected \<longleftrightarrow> es = [] \<or> \<not> connects es (node_list es)"
  unfolding a_kernel_def connected_iff by (auto split: if_splits option.splits)

theorem a_mst_sound:
  "a_kernel (A_mst es) = AMst t \<Longrightarrow> set t \<subseteq> set es"
  using a_mst_minimal[of es t] by (simp add: spans_def)

theorem a_bsearch_found:
  "a_kernel (A_bsearch xs x) = ABs i p \<Longrightarrow> sorted xs \<and> i < length xs \<and> xs ! i = x"
  unfolding a_kernel_def using bsearch_found by (auto split: if_splits bsres.splits)

theorem a_bsearch_none:
  "a_kernel (A_bsearch xs x) = ANotFound y p \<Longrightarrow> sorted xs \<and> y = x \<and> x \<notin> set xs"
  unfolding a_kernel_def using bsearch_none by (auto split: if_splits bsres.splits)

theorem a_bsearch_unsorted:
  "a_kernel (A_bsearch xs x) = AUnsorted \<longleftrightarrow> \<not> sorted xs"
  unfolding a_kernel_def by (auto split: if_splits bsres.splits)

theorem a_sorted_sound:
  "a_kernel (A_sort xs desc) = ASorted ys d \<Longrightarrow>
     d = desc \<and> (\<forall>a. count_list ys a = count_list xs a) \<and>
     (if desc then sorted (rev ys) else sorted ys)"
  unfolding a_kernel_def using isort_correct[of xs] by auto

section \<open>Reply text (ASCII)\<close>

definition join_with :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_with sep xs = (case xs of [] \<Rightarrow> STR '''' | x # r \<Rightarrow> foldl (\<lambda>a b. a + sep + b) x r)"

definition edge_text :: "edge \<Rightarrow> String.literal" where
  "edge_text x = (case x of (a, b, w) \<Rightarrow> a + STR ''-'' + b + STR '' '' + fmt_num w)"

definition need_text :: "nat \<Rightarrow> String.literal" where
  "need_text n = (if n = 0 then STR ''the weighted edges (e.g. A-B 4, B-C 1) and the start and end nodes''
     else if n = 1 then STR ''the weighted edges'' else STR ''the value to search for'')"

definition a_reply :: "areq \<Rightarrow> reply" where
  "a_reply r = (case a_kernel r of
     AShortest p d n s \<Rightarrow>
       Reply True (STR ''shortest_path'')
         [PS (STR ''The shortest path length is '' + fmt_num d + STR '', via ''
             + join_with (STR '' -> '') (s # map (\<lambda>x. fst (snd x)) p)
             + STR '' (Dijkstra on the '' + show_nat n + STR '' edges you gave).'')] (JRaw (fmt_num d))
   | AUnreach s e \<Rightarrow>
       Reply True (STR ''unreachable'')
         [PS (STR ''There is no path from '' + s + STR '' to '' + e + STR '' in the graph you gave.'')] JNone
   | ANoNode x \<Rightarrow>
       Reply False (STR ''no_node'')
         [PS (x + STR '' is not a node in the edges you gave.'')] JNone
   | AMst t \<Rightarrow>
       Reply True (STR ''mst'')
         [PS (STR ''The minimum spanning tree weight is '' + fmt_num (wt t) + STR '' (''
             + show_nat (length t) + STR '' edges, Kruskal on the edges you gave). The tree is ''
             + join_with (STR '', '') (map edge_text t) + STR ''.'')] (JRaw (fmt_num (wt t)))
   | ADisconnected \<Rightarrow>
       Reply True (STR ''disconnected'')
         [PS (STR ''The graph you gave is not connected, so it has no spanning tree (only a spanning forest).'')] JNone
   | ABs i p \<Rightarrow>
       Reply True (STR ''bsearch'')
         [PS (STR ''The index is '' + show_nat i + STR '' (0-based), found in '' + show_nat p + STR '' probes.'')]
         (JRaw (show_nat i))
   | ANotFound x p \<Rightarrow>
       Reply True (STR ''not_found'')
         [PS (fmt_num x + STR '' is not in the list (binary search ended after '' + show_nat p + STR '' probes).'')] JNone
   | AUnsorted \<Rightarrow>
       Reply False (STR ''unsorted'')
         [PS (STR ''That list is not sorted, so binary search would give a wrong answer; sort it first.'')] JNone
   | ASorted ys d \<Rightarrow>
       Reply True (STR ''sorted'')
         [PS (STR ''Sorted '' + (if d then STR ''descending'' else STR ''ascending'') + STR '': ''
             + join_with (STR '', '') (map fmt_num ys) + STR ''.'')]
         (JRaw (STR ''['' + join_with (STR '', '') (map fmt_num ys) + STR '']''))
   | AComplexity i avg \<Rightarrow>
       (case complexity_table ! i of (nm, worst, av) \<Rightarrow>
          Reply True (STR ''complexity'')
            [PS (if avg then STR ''The average-case time complexity of '' + nm + STR '' is '' + av + STR ''.''
                else if worst \<noteq> av then STR ''The worst-case time complexity of '' + nm + STR '' is '' + worst
                       + STR '' (average '' + av + STR '').''
                else STR ''The time complexity of '' + nm + STR '' is '' + worst + STR ''.'')]
            JNone)
   | ANeed n \<Rightarrow>
       Reply False (STR ''underspecified'')
         [PS (STR ''I need '' + need_text n + STR '' to run that; I will not assume it.'')] JNone
   | AImprecise \<Rightarrow>
       Reply False (STR ''imprecise'')
         [PS (STR ''I could not certify a result for that input, so I will not state one.'')] JNone)"

theorem a_reply_answered:
  "answered (a_reply r) \<longleftrightarrow>
     (case a_kernel r of ANoNode _ \<Rightarrow> False | AUnsorted \<Rightarrow> False | ANeed _ \<Rightarrow> False
        | AImprecise \<Rightarrow> False | _ \<Rightarrow> True)"
  by (auto simp: a_reply_def split: aout.splits prod.splits)

end
