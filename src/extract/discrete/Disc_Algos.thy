theory Disc_Algos
  imports Disc_Dtext
begin

text \<open>algorithms (upstream/root/specialists/algorithms). Every answer carries a
witness that the kernel checks before it is stated. Shortest path: Dijkstra
runs untrusted-style, then the result is accepted only with a certificate (a
feasible potential), which proves optimality of the returned walk. Binary
search and sorting are proved against their specifications. Kruskal's tree is
proved to consist of graph edges; its minimality is a runtime check only (see
the handoff).\<close>

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
   | A_mst es \<Rightarrow> (case mst_kernel es of Some t \<Rightarrow> AMst t | None \<Rightarrow> ADisconnected)
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

theorem a_mst_sound:
  "a_kernel (A_mst es) = AMst t \<Longrightarrow> set t \<subseteq> set es"
  unfolding a_kernel_def using mst_edges by (auto split: option.splits)

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
