theory Sql
  imports Computing_Num
begin

text \<open>Lane S15-computing, specialist @{text sql}
(upstream/root/specialists/sql/organ_sql_v1.py). The organ answers by running
the user's statements in SQLite. This kernel is a small SQL engine in HOL for the
subset the panel exercises: CREATE TABLE and INSERT VALUES for setup, and
SELECT [DISTINCT] items FROM t [WHERE] [GROUP BY] [ORDER BY] [LIMIT] with
COUNT, SUM, AVG, MAX, MIN. SQLite's semantics are written out: NULL in
comparisons, SUM of no rows is NULL, COUNT(col) skips NULL, AVG is real, a
stable sort with NULLs first, groups in key order. REAL values are exact
rationals (SQLite uses binary doubles; the two print the same at ten
significant digits except at a rounding boundary). Anything outside the subset
is @{text SUnsupported} and the answer is withheld, never guessed.
Tokens come from the untrusted lexer in the recognizer.\<close>

section \<open>Values and tokens\<close>

datatype tok = TW String.literal String.literal | TI int | TR rat | TS String.literal | TP String.literal
datatype sval = SNull | SInt int | SReal rat | SText String.literal

fun sv_rank :: "sval \<Rightarrow> nat" where
  "sv_rank SNull = 0" | "sv_rank (SInt i) = 1" | "sv_rank (SReal r) = 1" | "sv_rank (SText s) = 2"

fun sv_num :: "sval \<Rightarrow> rat" where
  "sv_num (SInt i) = of_int i" | "sv_num (SReal r) = r" | "sv_num x = 0"

text \<open>SQLite's total order on stored values: NULL, then numbers, then text.\<close>
definition sv_ord :: "sval \<Rightarrow> sval \<Rightarrow> int" where
  "sv_ord a b = (if sv_rank a < sv_rank b then -1 else if sv_rank b < sv_rank a then 1
     else case (a, b) of
        (SText x, SText y) \<Rightarrow> (if x < y then -1 else if x = y then 0 else 1)
      | (SNull, SNull) \<Rightarrow> 0
      | _ \<Rightarrow> (if sv_num a < sv_num b then -1 else if sv_num a = sv_num b then 0 else 1))"

lemma sv_ord_refl: "sv_ord a a = 0"
  by (cases a) (auto simp: sv_ord_def)

lemma sv_ord_antisym: "sv_ord a b = - sv_ord b a"
  by (cases a; cases b) (auto simp: sv_ord_def not_less)

lemma sv_ord_total: "sv_ord a b \<le> 0 \<or> sv_ord b a \<le> 0"
  using sv_ord_antisym[of a b] by (cases "sv_ord a b \<le> 0") auto

lemma sv_ord_trans: "sv_ord a b \<le> 0 \<Longrightarrow> sv_ord b c \<le> 0 \<Longrightarrow> sv_ord a c \<le> 0"
  by (cases a; cases b; cases c) (auto simp: sv_ord_def split: if_splits)

section \<open>Stable sorting\<close>

fun ins :: "('a \<Rightarrow> 'a \<Rightarrow> bool) \<Rightarrow> 'a \<Rightarrow> 'a list \<Rightarrow> 'a list" where
  "ins le x [] = [x]"
| "ins le x (y # ys) = (if le x y then x # y # ys else y # ins le x ys)"

fun isort :: "('a \<Rightarrow> 'a \<Rightarrow> bool) \<Rightarrow> 'a list \<Rightarrow> 'a list" where
  "isort le [] = []"
| "isort le (x # xs) = ins le x (isort le xs)"

lemma set_ins: "set (ins le x ys) = insert x (set ys)"
  by (induction ys) auto

lemma length_ins: "length (ins le x ys) = Suc (length ys)"
  by (induction ys) auto

theorem isort_perm: "set (isort le xs) = set xs \<and> length (isort le xs) = length xs"
  by (induction xs) (auto simp: set_ins length_ins)

lemma ins_sorted:
  assumes tot: "\<forall>a b. le a b \<or> le b a" and tr: "\<forall>a b c. le a b \<longrightarrow> le b c \<longrightarrow> le a c"
    and s: "sorted_wrt le ys"
  shows "sorted_wrt le (ins le x ys)"
  using s
proof (induction ys)
  case Nil then show ?case by simp
next
  case (Cons y ys)
  then have sy: "\<forall>z \<in> set ys. le y z" and sys: "sorted_wrt le ys" by simp_all
  show ?case
  proof (cases "le x y")
    case True
    have "\<forall>z \<in> set (y # ys). le x z" using True sy tr by auto
    then show ?thesis using True Cons.prems by simp
  next
    case False
    then have yx: "le y x" using tot by blast
    have "\<forall>z \<in> set (ins le x ys). le y z" using yx sy by (auto simp: set_ins)
    then show ?thesis using False Cons.IH sys by simp
  qed
qed

theorem isort_sorted:
  assumes "\<forall>a b. le a b \<or> le b a" "\<forall>a b c. le a b \<longrightarrow> le b c \<longrightarrow> le a c"
  shows "sorted_wrt le (isort le xs)"
  using assms by (induction xs) (auto intro: ins_sorted)

theorem ins_stable_before_equal:
  "le x y \<Longrightarrow> ins le x (y # ys) = x # y # ys"
  by simp

section \<open>Tables\<close>

datatype aff = A_int | A_real | A_text | A_num | A_none
type_synonym cref = "String.literal \<times> String.literal"

datatype stable = STable String.literal String.literal "(String.literal \<times> aff \<times> bool) list" "sval list list"

datatype cop = C_eq | C_ne | C_lt | C_le | C_gt | C_ge

fun op_holds :: "cop \<Rightarrow> int \<Rightarrow> bool" where
  "op_holds C_eq o' = (o' = 0)" | "op_holds C_ne o' = (o' \<noteq> 0)" | "op_holds C_lt o' = (o' < 0)"
| "op_holds C_le o' = (o' \<le> 0)" | "op_holds C_gt o' = (0 < o')" | "op_holds C_ge o' = (0 \<le> o')"

datatype scond = SC_cmp cref cop sval | SC_isnull cref bool | SC_and scond scond | SC_or scond scond

datatype aggfn = AF_count | AF_sum | AF_avg | AF_max | AF_min

datatype sitem = SI_star | SI_col cref | SI_agg aggfn bool "cref option"

datatype sq = SQ bool "sitem list" cref "scond option" "cref option" "(cref \<times> bool) list" "nat option"

datatype sres = SRows "sval list list" | SErr String.literal | SNeedData | SSetupErr String.literal | SUnsupported

fun col_index :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> String.literal \<Rightarrow> nat option" where
  "col_index [] n = None"
| "col_index (c # cs) n = (if fst c = n then Some 0 else map_option Suc (col_index cs n))"

lemma col_index_sound: "col_index cs n = Some i \<Longrightarrow> i < length cs \<and> fst (cs ! i) = n"
  by (induction cs arbitrary: i) (auto split: if_splits)

definition cell :: "sval list \<Rightarrow> nat \<Rightarrow> sval" where "cell row i = (if i < length row then row ! i else SNull)"

section \<open>Conditions\<close>

fun and3 :: "bool option \<Rightarrow> bool option \<Rightarrow> bool option" where
  "and3 (Some False) b = Some False" | "and3 a (Some False) = Some False"
| "and3 (Some True) (Some True) = Some True" | "and3 a b = None"

fun or3 :: "bool option \<Rightarrow> bool option \<Rightarrow> bool option" where
  "or3 (Some True) b = Some True" | "or3 a (Some True) = Some True"
| "or3 (Some False) (Some False) = Some False" | "or3 a b = None"

fun cond_cols :: "scond \<Rightarrow> cref list" where
  "cond_cols (SC_cmp c o' v) = [c]" | "cond_cols (SC_isnull c n) = [c]"
| "cond_cols (SC_and a b) = cond_cols a @ cond_cols b" | "cond_cols (SC_or a b) = cond_cols a @ cond_cols b"

fun eval_cond :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sval list \<Rightarrow> scond \<Rightarrow> bool option" where
  "eval_cond cols row (SC_cmp c o' v) =
     (let x = (case col_index cols (fst c) of Some i \<Rightarrow> cell row i | None \<Rightarrow> SNull) in
      if x = SNull \<or> v = SNull then None else Some (op_holds o' (sv_ord x v)))"
| "eval_cond cols row (SC_isnull c n) =
     (let x = (case col_index cols (fst c) of Some i \<Rightarrow> cell row i | None \<Rightarrow> SNull) in Some ((x = SNull) \<noteq> n))"
| "eval_cond cols row (SC_and a b) = and3 (eval_cond cols row a) (eval_cond cols row b)"
| "eval_cond cols row (SC_or a b) = or3 (eval_cond cols row a) (eval_cond cols row b)"

definition where_rows :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> scond option \<Rightarrow> sval list list \<Rightarrow> sval list list" where
  "where_rows cols c rows = (case c of None \<Rightarrow> rows | Some cd \<Rightarrow> filter (\<lambda>r. eval_cond cols r cd = Some True) rows)"

theorem where_keeps_exactly_true:
  "r \<in> set (where_rows cols (Some c) rows) \<longleftrightarrow> r \<in> set rows \<and> eval_cond cols r c = Some True"
  by (simp add: where_rows_def)

theorem where_null_never_kept:
  "eval_cond cols r (SC_cmp c o' SNull) = None"
  by (simp add: Let_def)

section \<open>Aggregates\<close>

definition nonnull :: "sval list \<Rightarrow> sval list" where "nonnull vs = filter (\<lambda>v. v \<noteq> SNull) vs"

function (sequential) uniq_by_ord :: "sval list \<Rightarrow> sval list" where
  "uniq_by_ord [] = []"
| "uniq_by_ord (v # vs) = v # uniq_by_ord (filter (\<lambda>w. sv_ord v w \<noteq> 0) vs)"
  by pat_completeness auto
termination by (relation "measure length") (auto simp: less_Suc_eq_le length_filter_le)

definition is_text :: "sval \<Rightarrow> bool" where "is_text v = (case v of SText _ \<Rightarrow> True | _ \<Rightarrow> False)"
definition is_int_v :: "sval \<Rightarrow> bool" where "is_int_v v = (case v of SInt _ \<Rightarrow> True | _ \<Rightarrow> False)"

definition int_of :: "sval \<Rightarrow> int" where "int_of v = (case v of SInt i \<Rightarrow> i | _ \<Rightarrow> 0)"
lemma int_of_SInt [simp]: "int_of (SInt i) = i" by (simp add: int_of_def)

definition sum_vals :: "sval list \<Rightarrow> sval" where
  "sum_vals vs = (if vs = [] then SNull
     else if list_all is_int_v vs then SInt (sum_list (map int_of vs))
     else SReal (sum_list (map sv_num vs)))"

fun best :: "bool \<Rightarrow> sval list \<Rightarrow> sval" where
  "best mx [] = SNull"
| "best mx [v] = v"
| "best mx (v # w # vs) = best mx ((if (if mx then 0 < sv_ord w v else sv_ord w v < 0) then w else v) # vs)"

text \<open>@{text None} when the aggregate would read text as a number (SQLite converts it; not modelled).\<close>
definition agg_eval :: "aggfn \<Rightarrow> bool \<Rightarrow> sval list \<Rightarrow> sval option" where
  "agg_eval f dst vs = (let nn = nonnull vs; u = (if dst then uniq_by_ord nn else nn) in
     case f of
       AF_count \<Rightarrow> Some (SInt (int (length u)))
     | AF_sum \<Rightarrow> if list_ex is_text u then None else Some (sum_vals u)
     | AF_avg \<Rightarrow> if list_ex is_text u then None else
         Some (if u = [] then SNull else SReal (sum_list (map sv_num u) / of_nat (length u)))
     | AF_max \<Rightarrow> Some (best True u)
     | AF_min \<Rightarrow> Some (best False u))"

theorem agg_count_star_len: "agg_eval AF_count False (map (\<lambda>r. SInt 1) rs) = Some (SInt (int (length rs)))"
  by (simp add: agg_eval_def nonnull_def Let_def)

theorem agg_count_skips_null:
  "agg_eval AF_count False vs = Some (SInt (int (length (filter (\<lambda>v. v \<noteq> SNull) vs))))"
  by (simp add: agg_eval_def nonnull_def Let_def)

theorem agg_sum_empty: "agg_eval AF_sum d [] = Some SNull \<and> agg_eval AF_count d [] = Some (SInt 0) \<and> agg_eval AF_avg d [] = Some SNull"
  by (simp add: agg_eval_def nonnull_def Let_def sum_vals_def)

theorem agg_sum_ints:
  "agg_eval AF_sum False (map SInt xs) = Some (if xs = [] then SNull else SInt (sum_list xs))"
proof -
  have a: "list_all is_int_v (map SInt xs)" by (induction xs) (simp_all add: is_int_v_def)
  have b: "\<not> list_ex is_text (map SInt xs)" by (induction xs) (simp_all add: is_text_def)
  have c: "nonnull (map SInt xs) = map SInt xs" by (induction xs) (simp_all add: nonnull_def)
  have d: "map (int_of \<circ> SInt) xs = xs" by (induction xs) simp_all
  show ?thesis by (simp add: agg_eval_def Let_def c a b d sum_vals_def)
qed

theorem agg_avg_value:
  assumes "vs \<noteq> []" "\<forall>v \<in> set vs. v \<noteq> SNull \<and> \<not> is_text v"
  shows "agg_eval AF_avg False vs = Some (SReal (sum_list (map sv_num vs) / of_nat (length vs)))"
proof -
  have c: "nonnull vs = vs" using assms(2) by (induction vs) (auto simp: nonnull_def)
  have t: "\<not> list_ex is_text vs" using assms(2) by (induction vs) auto
  show ?thesis using assms(1) by (simp add: agg_eval_def Let_def c t)
qed

theorem agg_max_is_member:
  "best mx vs \<noteq> SNull \<Longrightarrow> best mx vs \<in> set vs"
  by (induction mx vs rule: best.induct) (auto split: if_splits)

section \<open>Execution\<close>

definition keys_cmp :: "(nat \<times> bool) list \<Rightarrow> sval list \<Rightarrow> sval list \<Rightarrow> int" where
  "keys_cmp ks x y = foldr (\<lambda>k acc. let c = sv_ord (cell x (fst k)) (cell y (fst k)) in
        if c \<noteq> 0 then (if snd k then - c else c) else acc) ks 0"

function (sequential) dedup_rows :: "sval list list \<Rightarrow> sval list list" where
  "dedup_rows [] = []"
| "dedup_rows (r # rs) = r # dedup_rows (filter (\<lambda>q. \<not> (list_all2 (\<lambda>a b. sv_ord a b = 0) r q)) rs)"
  by pat_completeness auto
termination by (relation "measure length") (auto simp: less_Suc_eq_le length_filter_le)

definition item_cols :: "sitem list \<Rightarrow> cref list" where
  "item_cols its = concat (map (\<lambda>i. case i of SI_col c \<Rightarrow> [c] | SI_agg f d (Some c) \<Rightarrow> [c] | _ \<Rightarrow> []) its)"

definition has_agg :: "sitem list \<Rightarrow> bool" where
  "has_agg its = list_ex (\<lambda>i. case i of SI_agg _ _ _ \<Rightarrow> True | _ \<Rightarrow> False) its"

definition agg_col_vals :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sval list list \<Rightarrow> cref option \<Rightarrow> sval list" where
  "agg_col_vals cols rows c = (case c of
      None \<Rightarrow> map (\<lambda>r. SInt 1) rows
    | Some cr \<Rightarrow> (case col_index cols (fst cr) of Some i \<Rightarrow> map (\<lambda>r. cell r i) rows | None \<Rightarrow> []))"

definition agg_row :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sitem list \<Rightarrow> sval list list \<Rightarrow> sval option \<Rightarrow> sval list option" where
  "agg_row cols its rows key = (let rs = map (\<lambda>i. case i of
        SI_agg f d c \<Rightarrow> agg_eval f d (agg_col_vals cols rows c)
      | SI_col c \<Rightarrow> key
      | SI_star \<Rightarrow> None) its in
     if None \<in> set rs then None else Some (map the rs))"

definition exec_sq :: "stable \<Rightarrow> sq \<Rightarrow> sres" where
  "exec_sq t q = (case t of STable tn to cols rows \<Rightarrow> (case q of SQ dst its tb cnd grp ordl lmt \<Rightarrow>
     (let used = item_cols its @ (case cnd of None \<Rightarrow> [] | Some c \<Rightarrow> cond_cols c) @ (case grp of None \<Rightarrow> [] | Some g \<Rightarrow> [g])
                 @ map fst ordl;
          bad = find (\<lambda>c. col_index cols (fst c) = None) used
      in case bad of Some c \<Rightarrow> SErr (STR ''no such column: '' + snd c) | None \<Rightarrow>
      (let rows' = where_rows cols cnd rows;
           limit = (\<lambda>rs. case lmt of None \<Rightarrow> rs | Some n \<Rightarrow> take n rs)
       in
       (case grp of
          None \<Rightarrow>
            (if has_agg its then
               (case agg_row cols its rows' None of None \<Rightarrow> SUnsupported
                | Some r \<Rightarrow> SRows (limit [r]))
             else if list_ex (\<lambda>i. i = SI_star) its \<and> length its \<noteq> 1 then SUnsupported
             else
               (let ks = map (\<lambda>o2. (the (col_index cols (fst (fst o2))), snd o2)) ordl;
                    sorted_rows = isort (\<lambda>x y. keys_cmp ks x y \<le> 0) rows';
                    proj = (\<lambda>r. concat (map (\<lambda>i. case i of SI_star \<Rightarrow> r
                              | SI_col c \<Rightarrow> [cell r (the (col_index cols (fst c)))] | SI_agg _ _ _ \<Rightarrow> []) its));
                    out = map proj sorted_rows
                in SRows (limit (if dst then dedup_rows out else out))))
        | Some g \<Rightarrow>
            (if \<not> list_all (\<lambda>i. case i of SI_star \<Rightarrow> False | SI_col c \<Rightarrow> fst c = fst g | SI_agg _ _ _ \<Rightarrow> True) its
                \<or> \<not> list_all (\<lambda>o2. fst (fst o2) = fst g) ordl \<or> length ordl > 1 then SUnsupported
             else
               (let gi = the (col_index cols (fst g));
                    keys = isort (\<lambda>a b. sv_ord a b \<le> 0) (uniq_by_ord (map (\<lambda>r. cell r gi) rows'));
                    keys' = (case ordl of [] \<Rightarrow> keys | (o1 # _) \<Rightarrow> (if snd o1 then rev keys else keys));
                    outs = map (\<lambda>k. agg_row cols its (filter (\<lambda>r. sv_ord (cell r gi) k = 0) rows') (Some k)) keys'
                in if None \<in> set outs then SUnsupported
                   else (let out = map the outs in SRows (limit (if dst then dedup_rows out else out))))))))))"

theorem exec_unknown_column:
  "find (\<lambda>c. col_index cols (fst c) = None)
     (item_cols its @ (case cnd of None \<Rightarrow> [] | Some c \<Rightarrow> cond_cols c) @ (case grp of None \<Rightarrow> [] | Some g \<Rightarrow> [g]) @ map fst ordl)
     = Some c \<Longrightarrow> exec_sq (STable tn to cols rows) (SQ dst its tb cnd grp ordl lmt) = SErr (STR ''no such column: '' + snd c)"
  by (simp add: exec_sq_def Let_def)

lemma uniq_subset: "set (uniq_by_ord vs) \<subseteq> set vs"
  by (induction vs rule: uniq_by_ord.induct) auto

lemma uniq_cover: "\<forall>x \<in> set vs. \<exists>u \<in> set (uniq_by_ord vs). sv_ord x u = 0"
proof (induction vs rule: uniq_by_ord.induct)
  case 1 then show ?case by simp
next
  case (2 v vs)
  show ?case
  proof
    fix x assume x: "x \<in> set (v # vs)"
    show "\<exists>u \<in> set (uniq_by_ord (v # vs)). sv_ord x u = 0"
    proof (cases "sv_ord v x = 0")
      case True
      then have "sv_ord x v = 0" using sv_ord_antisym[of x v] by simp
      then show ?thesis by auto
    next
      case False
      then have "x \<in> set (filter (\<lambda>w. sv_ord v w \<noteq> 0) vs)" using x sv_ord_refl[of v] by auto
      then obtain u where "u \<in> set (uniq_by_ord (filter (\<lambda>w. sv_ord v w \<noteq> 0) vs))" "sv_ord x u = 0"
        using 2 by blast
      then show ?thesis by auto
    qed
  qed
qed

lemma uniq_sep:
  "x \<in> set (uniq_by_ord vs) \<Longrightarrow> y \<in> set (uniq_by_ord vs) \<Longrightarrow> x \<noteq> y \<Longrightarrow> sv_ord x y \<noteq> 0"
proof (induction vs arbitrary: x y rule: uniq_by_ord.induct)
  case 1 then show ?case by simp
next
  case (2 v vs)
  let ?t = "uniq_by_ord (filter (\<lambda>w. sv_ord v w \<noteq> 0) vs)"
  have sub: "set ?t \<subseteq> set (filter (\<lambda>w. sv_ord v w \<noteq> 0) vs)" by (rule uniq_subset)
  show ?case
  proof (cases "x = v")
    case True
    then have "y \<in> set ?t" using 2(3,4) by auto
    then show ?thesis using sub True by auto
  next
    case xv: False
    then have xt: "x \<in> set ?t" using 2(2) by auto
    show ?thesis
    proof (cases "y = v")
      case True
      then have "sv_ord v x \<noteq> 0" using xt sub by auto
      then show ?thesis using True sv_ord_antisym[of x y] by simp
    next
      case False
      then have "y \<in> set ?t" using 2(3) by auto
      then show ?thesis using 2(1) xt 2(4) by blast
    qed
  qed
qed

lemma uniq_distinct: "distinct (uniq_by_ord vs)"
proof (induction vs rule: uniq_by_ord.induct)
  case 1 then show ?case by simp
next
  case (2 v vs)
  have "v \<notin> set (uniq_by_ord (filter (\<lambda>w. sv_ord v w \<noteq> 0) vs))"
    using uniq_subset[of "filter (\<lambda>w. sv_ord v w \<noteq> 0) vs"] sv_ord_refl[of v] by auto
  then show ?case using 2 by simp
qed

lemma strict_sorted:
  assumes "sorted_wrt (\<lambda>a b. sv_ord a b \<le> 0) l" "distinct l"
    "\<forall>x \<in> set l. \<forall>y \<in> set l. x \<noteq> y \<longrightarrow> sv_ord x y \<noteq> 0"
  shows "sorted_wrt (\<lambda>a b. sv_ord a b < 0) l"
  using assms
proof (induction l)
  case Nil then show ?case by simp
next
  case (Cons x xs)
  have "\<forall>y \<in> set xs. sv_ord x y < 0"
  proof
    fix y assume y: "y \<in> set xs"
    then have "x \<noteq> y" using Cons.prems(2) by auto
    moreover have "sv_ord x y \<le> 0" using y Cons.prems(1) by simp
    ultimately show "sv_ord x y < 0" using Cons.prems(3) y by fastforce
  qed
  then show ?case using Cons by simp
qed

lemma group_keys_out:
  assumes "exec_sq (STable tn to cols rows) (SQ False [SI_col g] tb cnd (Some g) [] None) = SRows out"
  obtains gi where "col_index cols (fst g) = Some gi"
    "out = map (\<lambda>k. [k]) (isort (\<lambda>a b. sv_ord a b \<le> 0)
              (uniq_by_ord (map (\<lambda>r. cell r gi) (where_rows cols cnd rows))))"
proof (cases "find (\<lambda>c. col_index cols (fst c) = None)
       (item_cols [SI_col g] @ (case cnd of None \<Rightarrow> [] | Some c \<Rightarrow> cond_cols c) @ [g] @ map fst [])")
  case (Some c)
  then show ?thesis using assms by (simp add: exec_sq_def Let_def)
next
  case None
  then have "col_index cols (fst g) \<noteq> None" by (auto simp: find_None_iff item_cols_def)
  then obtain gi where gi: "col_index cols (fst g) = Some gi" by auto
  have "out = map (\<lambda>k. [k]) (isort (\<lambda>a b. sv_ord a b \<le> 0)
              (uniq_by_ord (map (\<lambda>r. cell r gi) (where_rows cols cnd rows))))"
    using assms None gi
    by (simp add: exec_sq_def Let_def has_agg_def agg_row_def item_cols_def comp_def)
  then show ?thesis using gi that by blast
qed

text \<open>A grouped select of the grouping column alone returns each group key once, in strictly
ascending order, and the keys are exactly those of the rows the WHERE keeps.\<close>
theorem exec_group_keys_strictly_ordered:
  assumes "exec_sq (STable tn to cols rows) (SQ False [SI_col g] tb cnd (Some g) [] None) = SRows out"
  shows "\<exists>gi. col_index cols (fst g) = Some gi \<and>
     sorted_wrt (\<lambda>r s. sv_ord (hd r) (hd s) < 0) out \<and> (\<forall>r \<in> set out. \<exists>k. r = [k]) \<and>
     (\<forall>row \<in> set (where_rows cols cnd rows). \<exists>r \<in> set out. sv_ord (cell row gi) (hd r) = 0) \<and>
     (\<forall>r \<in> set out. \<exists>row \<in> set (where_rows cols cnd rows). sv_ord (cell row gi) (hd r) = 0)"
proof -
  from group_keys_out[OF assms] obtain gi where gi: "col_index cols (fst g) = Some gi"
    and out: "out = map (\<lambda>k. [k]) (isort (\<lambda>a b. sv_ord a b \<le> 0)
              (uniq_by_ord (map (\<lambda>r. cell r gi) (where_rows cols cnd rows))))" by blast
  define u where "u = uniq_by_ord (map (\<lambda>r. cell r gi) (where_rows cols cnd rows))"
  define keys where "keys = isort (\<lambda>a b. sv_ord a b \<le> 0) u"
  have out': "out = map (\<lambda>k. [k]) keys" using out by (simp add: u_def keys_def)
  have tot: "\<forall>a b. sv_ord a b \<le> 0 \<or> sv_ord b a \<le> 0" using sv_ord_total by blast
  have tr: "\<forall>a b c. sv_ord a b \<le> 0 \<longrightarrow> sv_ord b c \<le> 0 \<longrightarrow> sv_ord a c \<le> 0" using sv_ord_trans by blast
  have srt: "sorted_wrt (\<lambda>a b. sv_ord a b \<le> 0) keys" unfolding keys_def by (rule isort_sorted[OF tot tr])
  have perm: "set keys = set u" "length keys = length u"
    using isort_perm[of "\<lambda>a b. sv_ord a b \<le> 0" u] by (simp_all add: keys_def)
  have du: "distinct u" unfolding u_def by (rule uniq_distinct)
  have "card (set keys) = length keys" using perm distinct_card[OF du] by simp
  then have dk: "distinct keys" by (rule card_distinct)
  have sep0: "\<forall>x \<in> set u. \<forall>y \<in> set u. x \<noteq> y \<longrightarrow> sv_ord x y \<noteq> 0"
    unfolding u_def using uniq_sep by blast
  have sep: "\<forall>x \<in> set keys. \<forall>y \<in> set keys. x \<noteq> y \<longrightarrow> sv_ord x y \<noteq> 0" using sep0 perm(1) by simp
  have strict: "sorted_wrt (\<lambda>a b. sv_ord a b < 0) keys" by (rule strict_sorted[OF srt dk sep])
  have cov: "\<forall>row \<in> set (where_rows cols cnd rows). \<exists>k \<in> set keys. sv_ord (cell row gi) k = 0"
    using uniq_cover[of "map (\<lambda>r. cell r gi) (where_rows cols cnd rows)"] perm(1) by (auto simp: u_def)
  have sub: "\<forall>k \<in> set keys. \<exists>row \<in> set (where_rows cols cnd rows). sv_ord (cell row gi) k = 0"
  proof
    fix k assume "k \<in> set keys"
    then have "k \<in> set (map (\<lambda>r. cell r gi) (where_rows cols cnd rows))"
      using perm(1) uniq_subset[of "map (\<lambda>r. cell r gi) (where_rows cols cnd rows)"] u_def by auto
    then obtain row where "row \<in> set (where_rows cols cnd rows)" "k = cell row gi" by auto
    then show "\<exists>row \<in> set (where_rows cols cnd rows). sv_ord (cell row gi) k = 0"
      using sv_ord_refl by auto
  qed
  show ?thesis using gi strict cov sub by (auto simp: out' sorted_wrt_map)
qed

section \<open>Setup statements\<close>

fun split_top :: "nat \<Rightarrow> tok list \<Rightarrow> tok list \<Rightarrow> tok list list" where
  "split_top d acc [] = [rev acc]"
| "split_top d acc (t # ts) =
     (if t = TP (STR '','') \<and> d = 0 then rev acc # split_top 0 [] ts
      else split_top (if t = TP (STR ''('') then d + 1 else if t = TP (STR '')'') then d - 1 else d) (t # acc) ts)"

definition aff_of :: "String.literal \<Rightarrow> aff option" where
  "aff_of u = (if u \<in> set [STR ''INTEGER'', STR ''INT'', STR ''BIGINT'', STR ''SMALLINT'', STR ''TINYINT''] then Some A_int
     else if u \<in> set [STR ''REAL'', STR ''DOUBLE'', STR ''FLOAT''] then Some A_real
     else if u \<in> set [STR ''TEXT'', STR ''VARCHAR'', STR ''CHAR'', STR ''STRING''] then Some A_text
     else if u \<in> set [STR ''NUMERIC'', STR ''DECIMAL'', STR ''BOOLEAN'', STR ''DATE''] then Some A_num
     else if u = STR ''BLOB'' then Some A_none else None)"

fun has_pk :: "tok list \<Rightarrow> bool" where
  "has_pk (TW a x # TW b y # r) = ((a = STR ''PRIMARY'' \<and> b = STR ''KEY'') \<or> has_pk (TW b y # r))"
| "has_pk (t # r) = has_pk r"
| "has_pk [] = False"

definition col_def :: "tok list \<Rightarrow> (String.literal \<times> aff \<times> bool) option" where
  "col_def ts = (case ts of
      TW u o' # rest \<Rightarrow>
        (if u \<in> set [STR ''PRIMARY'', STR ''UNIQUE'', STR ''FOREIGN'', STR ''CHECK'', STR ''CONSTRAINT''] then None
         else case rest of
           [] \<Rightarrow> Some (u, A_none, False)
         | TW tu _ # _ \<Rightarrow> (case aff_of tu of Some a \<Rightarrow> Some (u, a, has_pk rest) | None \<Rightarrow> None)
         | _ \<Rightarrow> None)
    | _ \<Rightarrow> None)"

definition strip_semi :: "tok list \<Rightarrow> tok list" where
  "strip_semi ts = (if ts \<noteq> [] \<and> last ts = TP (STR '';'') then butlast ts else ts)"

datatype setup_stmt = SS_create String.literal String.literal "(String.literal \<times> aff \<times> bool) list"
  | SS_insert String.literal String.literal "sval list list"

definition parse_value :: "tok list \<Rightarrow> sval option" where
  "parse_value ts = (case ts of
      [TW u _] \<Rightarrow> if u = STR ''NULL'' then Some SNull else None
    | [TI i] \<Rightarrow> Some (SInt i) | [TR r] \<Rightarrow> Some (SReal r) | [TS s] \<Rightarrow> Some (SText s)
    | [TP m, TI i] \<Rightarrow> if m = STR ''-'' then Some (SInt (- i)) else if m = STR ''+'' then Some (SInt i) else None
    | [TP m, TR r] \<Rightarrow> if m = STR ''-'' then Some (SReal (- r)) else if m = STR ''+'' then Some (SReal r) else None
    | _ \<Rightarrow> None)"

definition parse_setup :: "tok list \<Rightarrow> setup_stmt option" where
  "parse_setup ts0 = (let ts = strip_semi ts0 in case ts of
      TW a _ # TW b _ # TW u o' # TP p # rest \<Rightarrow>
        (if a = STR ''CREATE'' \<and> b = STR ''TABLE'' \<and> p = STR ''('' \<and> rest \<noteq> [] \<and> last rest = TP (STR '')'') then
           (let defs = map col_def (split_top 0 [] (butlast rest)) in
            if None \<in> set defs then None else Some (SS_create u o' (map the defs)))
         else None)
    | TW a _ # TW b _ # TW u o' # TW v _ # rest \<Rightarrow>
        (if a = STR ''INSERT'' \<and> b = STR ''INTO'' \<and> v = STR ''VALUES'' then
           (let groups = split_top 0 [] rest;
                tuples = map (\<lambda>g. case g of TP l # inner \<Rightarrow>
                    (if l = STR ''('' \<and> inner \<noteq> [] \<and> last inner = TP (STR '')'')
                     then (let vs = map parse_value (split_top 0 [] (butlast inner)) in
                           if None \<in> set vs then None else Some (map the vs)) else None)
                  | _ \<Rightarrow> None) groups
            in if None \<in> set tuples \<or> groups = [] then None else Some (SS_insert u o' (map the tuples)))
         else None)
    | _ \<Rightarrow> None)"

definition apply_aff :: "aff \<Rightarrow> sval \<Rightarrow> sval option" where
  "apply_aff a v = (case (a, v) of
      (_, SNull) \<Rightarrow> Some SNull
    | (A_none, _) \<Rightarrow> Some v
    | (A_int, SInt i) \<Rightarrow> Some v | (A_num, SInt i) \<Rightarrow> Some v
    | (A_int, SReal r) \<Rightarrow> Some (if snd (quotient_of r) = 1 then SInt (fst (quotient_of r)) else v)
    | (A_num, SReal r) \<Rightarrow> Some (if snd (quotient_of r) = 1 then SInt (fst (quotient_of r)) else v)
    | (A_real, SInt i) \<Rightarrow> Some (SReal (of_int i)) | (A_real, SReal r) \<Rightarrow> Some v
    | (A_text, SText s) \<Rightarrow> Some v
    | _ \<Rightarrow> None)"

datatype dbres = DB "stable list" | DBErr String.literal | DBUnsupported

definition add_row :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sval list \<Rightarrow> sval list option" where
  "add_row cols vs = (let cs = map2 (\<lambda>c v. if snd (snd c) \<and> v = SNull then None else apply_aff (fst (snd c)) v) cols vs in
     if None \<in> set cs then None else Some (map the cs))"

fun run_setup :: "stable list \<Rightarrow> setup_stmt list \<Rightarrow> dbres" where
  "run_setup db [] = DB db"
| "run_setup db (SS_create u o' cols # rest) =
     (if list_ex (\<lambda>t. case t of STable tu _ _ _ \<Rightarrow> tu = u) db then DBErr (STR ''table '' + o' + STR '' already exists'')
      else run_setup (db @ [STable u o' cols []]) rest)"
| "run_setup db (SS_insert u o' tuples # rest) =
     (case find (\<lambda>t. case t of STable tu _ _ _ \<Rightarrow> tu = u) db of
        None \<Rightarrow> DBErr (STR ''no such table: '' + o')
      | Some (STable tu to cols rows) \<Rightarrow>
          (if \<exists>tp \<in> set tuples. length tp \<noteq> length cols then
             DBErr (STR ''table '' + o' + STR '' has '' + show_int (int (length cols)) + STR '' columns but '' +
               show_int (int (length (hd (filter (\<lambda>tp. length tp \<noteq> length cols) tuples)))) + STR '' values were supplied'')
           else
             (let news = map (add_row cols) tuples in
              if None \<in> set news then DBUnsupported
              else run_setup (map (\<lambda>t. case t of STable tx ox cx rx \<Rightarrow>
                      if tx = u then STable tx ox cx (rx @ map the news) else t) db) rest)))"

definition run_query :: "stable list \<Rightarrow> bool \<Rightarrow> sq \<Rightarrow> sres" where
  "run_query db had_setup q = (case q of SQ dst its tb cnd grp ordl lmt \<Rightarrow>
     (case find (\<lambda>t. case t of STable tu _ _ _ \<Rightarrow> tu = fst tb) db of
        Some t \<Rightarrow> exec_sq t q
      | None \<Rightarrow> if \<not> had_setup then SNeedData else SErr (STR ''no such table: '' + snd tb)))"

definition sql_run :: "tok list list \<Rightarrow> sq \<Rightarrow> sres" where
  "sql_run setup q = (let ps = map parse_setup setup in
     if None \<in> set ps then SUnsupported
     else case run_setup [] (map the ps) of
        DBErr m \<Rightarrow> SSetupErr m
      | DBUnsupported \<Rightarrow> SUnsupported
      | DB db \<Rightarrow> run_query db (setup \<noteq> []) q)"

section \<open>Reply text\<close>

definition fmt_val :: "sval \<Rightarrow> String.literal" where
  "fmt_val v = (case v of SNull \<Rightarrow> STR ''NULL'' | SInt i \<Rightarrow> show_int i
     | SReal r \<Rightarrow> (case round_sig 10 (rl r) of Some d \<Rightarrow> render_dec 10 d | None \<Rightarrow> STR ''?'')
     | SText s \<Rightarrow> apos + s + apos)"

definition join_sep :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_sep sep xs = (case xs of [] \<Rightarrow> STR '''' | x # r \<Rightarrow> foldl (\<lambda>a b. a + sep + b) x r)"

definition fmt_row :: "sval list \<Rightarrow> String.literal" where
  "fmt_row r = (case r of [v] \<Rightarrow> fmt_val v | _ \<Rightarrow> STR ''('' + join_sep (STR '', '') (map fmt_val r) + STR '')'')"

definition ran_on :: String.literal where "ran_on = STR '' (run in SQLite on the tables you gave).''"

definition sql_reply :: "sres \<Rightarrow> reply" where
  "sql_reply r = (case r of
      SRows [] \<Rightarrow> Reply True (STR ''rows'') (STR ''It returns no rows (run in SQLite on the tables you gave).'') None
    | SRows [[v]] \<Rightarrow> Reply True (STR ''scalar'') (STR ''It returns '' + fmt_val v + ran_on) (Some (fmt_val v))
    | SRows rows \<Rightarrow> (let more = 20 < length rows; shown = take 20 rows in
        Reply True (STR ''rows'')
          (STR ''It returns '' + (if more then STR ''at least '' else STR '''') + show_int (int (length shown))
            + (if length shown = 1 then STR '' row: '' else STR '' rows: '') + join_sep (STR ''; '') (map fmt_row shown)
            + (if more then STR '' ...'' else STR '''') + ran_on) None)
    | SErr m \<Rightarrow> Reply True (STR ''error'') (STR ''That query fails in SQLite: '' + m + STR ''.'') None
    | SNeedData \<Rightarrow> Reply False (STR ''needs_data'')
        (STR ''I can'' + apos + STR ''t know what that returns without the table'' + apos + STR ''s definition and rows; give me the CREATE TABLE and INSERT statements and I'' + apos + STR ''ll run it.'') None
    | SSetupErr m \<Rightarrow> Reply False (STR ''setup_error'')
        (STR ''Your setup statements fail in SQLite before the query runs: '' + m + STR ''.'') None
    | SUnsupported \<Rightarrow> Reply False (STR ''unsupported'') (STR '''') None)"

theorem sql_reply_answered_iff:
  "answered (sql_reply r) \<longleftrightarrow> (case r of SNeedData \<Rightarrow> False | SSetupErr _ \<Rightarrow> False | SUnsupported \<Rightarrow> False | _ \<Rightarrow> True)"
  by (cases r) (auto simp: sql_reply_def Let_def split: list.splits)

section \<open>Validity: does the statement parse\<close>

datatype vres = V_yes "String.literal option" | V_no | V_unknown

definition stmt_words :: "String.literal list" where
  "stmt_words = [STR ''SELECT'', STR ''WITH'', STR ''INSERT'', STR ''UPDATE'', STR ''DELETE'', STR ''CREATE'', STR ''DROP'',
    STR ''ALTER'', STR ''PRAGMA'', STR ''BEGIN'', STR ''COMMIT'', STR ''ROLLBACK'', STR ''EXPLAIN'', STR ''VACUUM'',
    STR ''REPLACE'', STR ''ANALYZE'', STR ''ATTACH'', STR ''DETACH'', STR ''REINDEX'', STR ''SAVEPOINT'', STR ''RELEASE'',
    STR ''VALUES'', STR ''END'']"

definition clause_words :: "String.literal list" where
  "clause_words = [STR ''SELECT'', STR ''FROM'', STR ''WHERE'', STR ''GROUP'', STR ''HAVING'', STR ''ORDER'', STR ''LIMIT'', STR ''OFFSET'']"

definition op_words :: "String.literal list" where
  "op_words = [STR ''AND'', STR ''OR'', STR ''LIKE'', STR ''GLOB'', STR ''IS'', STR ''NOT'', STR ''IN'', STR ''BETWEEN'', STR ''ESCAPE'']"

definition op_puncts :: "String.literal list" where
  "op_puncts = [STR ''='', STR ''=='', STR ''<'', STR ''>'', STR ''<='', STR ''>='', STR ''<>'', STR ''!='', STR ''+'', STR ''-'',
    STR ''*'', STR ''/'', STR ''%'', STR ''||'', STR ''<<'', STR ''>>'', STR ''&'', STR ''|'', STR ''.'']"

datatype scan = Sc_ok | Sc_cert | Sc_fail

text \<open>States: 0 expect an operand, 1 after an operand, 2 expect an alias word, 3 after
the alias, 4 right after a call parenthesis. A certificate is a syntax error that
SQLite reports whatever surrounds it: a missing operand, an unclosed or unmatched
parenthesis, a second bare word after an alias.\<close>
fun scan_expr :: "nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> tok list \<Rightarrow> scan" where
  "scan_expr st d ordl [] = (if d > 0 then Sc_cert else if st = 0 then Sc_cert else if st = 2 then Sc_cert
                            else if st = 4 then Sc_cert else Sc_ok)"
| "scan_expr st d ordl (t # ts) =
    (case t of
       TI _ \<Rightarrow> if st = 0 \<or> st = 4 then scan_expr 1 d ordl ts else if st = 1 then Sc_fail else Sc_cert
     | TR _ \<Rightarrow> if st = 0 \<or> st = 4 then scan_expr 1 d ordl ts else if st = 1 then Sc_fail else Sc_cert
     | TS _ \<Rightarrow> if st = 0 \<or> st = 4 then scan_expr 1 d ordl ts else if st = 1 then Sc_fail else Sc_cert
     | TW u _ \<Rightarrow>
         (if st = 0 \<or> st = 4 then
            (if u \<in> set clause_words then Sc_fail
             else if u = STR ''NOT'' then scan_expr 0 d ordl ts
             else scan_expr 1 d ordl ts)
          else if st = 1 then
            (if u \<in> set op_words then scan_expr 0 d ordl ts
             else if d > 0 then Sc_fail
             else if u = STR ''AS'' then scan_expr 2 d ordl ts
             else if ordl \<and> (u = STR ''ASC'' \<or> u = STR ''DESC'') then scan_expr 3 d ordl ts
             else if u \<in> set clause_words then Sc_fail
             else scan_expr 3 d ordl ts)
          else if st = 2 then scan_expr 3 d ordl ts
          else Sc_cert)
     | TP p \<Rightarrow>
         (if p = STR ''('' then
            (if st = 0 \<or> st = 4 then scan_expr 0 (d + 1) ordl ts
             else if st = 1 then scan_expr 4 (d + 1) ordl ts else Sc_cert)
          else if p = STR '')'' then
            (if d = 0 then Sc_cert
             else if st = 1 \<or> st = 4 then scan_expr 1 (d - 1) ordl ts else Sc_cert)
          else if p = STR '','' then
            (if d > 0 \<and> st = 1 then scan_expr 0 d ordl ts else Sc_cert)
          else if p = STR ''*'' \<and> st = 4 then scan_expr 1 d ordl ts
          else if st = 1 \<and> p \<in> set op_puncts then scan_expr 0 d ordl ts
          else if st = 0 \<and> (p = STR ''-'' \<or> p = STR ''+'' \<or> p = STR ''~'') then scan_expr 0 d ordl ts
          else if st = 1 then Sc_fail else Sc_cert))"

definition scan_part :: "bool \<Rightarrow> tok list \<Rightarrow> scan" where
  "scan_part ordl ts = (if ts = [TP (STR ''*'')] then Sc_ok else
     (case ts of [TW _ _, TP dot, TP star] \<Rightarrow> if dot = STR ''.'' \<and> star = STR ''*'' then Sc_ok else scan_expr 0 0 ordl ts
      | _ \<Rightarrow> scan_expr 0 0 ordl ts))"

fun combine :: "scan list \<Rightarrow> scan" where
  "combine [] = Sc_ok"
| "combine (s # r) = (case s of Sc_cert \<Rightarrow> Sc_cert | Sc_fail \<Rightarrow> (case combine r of Sc_cert \<Rightarrow> Sc_cert | _ \<Rightarrow> Sc_fail)
                      | Sc_ok \<Rightarrow> combine r)"

fun segs :: "nat \<Rightarrow> String.literal \<Rightarrow> tok list \<Rightarrow> tok list \<Rightarrow> (String.literal \<times> tok list) list" where
  "segs d kw acc [] = [(kw, rev acc)]"
| "segs d kw acc (t # ts) =
     (case t of
        TW u _ \<Rightarrow>
          (if d = 0 \<and> u \<in> set clause_words \<and> u \<noteq> STR ''SELECT'' then
             (if (u = STR ''GROUP'' \<or> u = STR ''ORDER'') then
                (case ts of TW b _ # ts2 \<Rightarrow> (if b = STR ''BY'' then (kw, rev acc) # segs 0 u [] ts2 else [(STR ''?'', [])])
                          | _ \<Rightarrow> [(STR ''?'', [])])
              else (kw, rev acc) # segs 0 u [] ts)
           else segs d kw (t # acc) ts)
      | TP p \<Rightarrow> segs (if p = STR ''('' then d + 1 else if p = STR '')'' then d - 1 else d) kw (t # acc) ts
      | _ \<Rightarrow> segs d kw (t # acc) ts)"

definition paren_balance :: "tok list \<Rightarrow> bool" where
  "paren_balance ts = (length (filter (\<lambda>t. t = TP (STR ''('')) ts) = length (filter (\<lambda>t. t = TP (STR '')'')) ts))"

definition seg_scan :: "String.literal \<times> tok list \<Rightarrow> scan" where
  "seg_scan s = (let kw = fst s; body = snd s in
     if kw = STR ''?'' then Sc_fail
     else if body = [] then Sc_cert
     else if kw = STR ''SELECT'' then
       (let b = (case body of TW u _ # r \<Rightarrow> if u = STR ''DISTINCT'' \<or> u = STR ''ALL'' then r else body | _ \<Rightarrow> body) in
        combine (map (scan_part False) (split_top 0 [] b)))
     else if kw = STR ''FROM'' then
       (case body of
          [TW _ _] \<Rightarrow> Sc_ok | [TW _ _, TW _ _] \<Rightarrow> Sc_ok | [TW _ _, TW a _, TW _ _] \<Rightarrow> if a = STR ''AS'' then Sc_ok else Sc_fail
        | _ \<Rightarrow> Sc_fail)
     else if kw = STR ''ORDER'' then combine (map (scan_part True) (split_top 0 [] body))
     else if kw = STR ''GROUP'' then combine (map (scan_part False) (split_top 0 [] body))
     else combine [scan_expr 0 0 False body])"

definition stmt_words_ok :: "tok list \<Rightarrow> bool option" where
  "stmt_words_ok ts = (case ts of
      TW u _ # _ \<Rightarrow> Some (u \<in> set stmt_words)
    | TP _ # _ \<Rightarrow> None
    | [] \<Rightarrow> Some False
    | _ \<Rightarrow> Some False)"

definition from_table :: "tok list \<Rightarrow> String.literal option" where
  "from_table ts = (case dropWhile (\<lambda>t. case t of TW u _ \<Rightarrow> u \<noteq> STR ''FROM'' | _ \<Rightarrow> True) ts of
      TW _ _ # TW _ o' # _ \<Rightarrow> Some o' | _ \<Rightarrow> None)"

definition sql_validity :: "tok list \<Rightarrow> vres" where
  "sql_validity ts0 = (let ts = strip_semi ts0 in
     case stmt_words_ok ts of
       None \<Rightarrow> V_unknown
     | Some False \<Rightarrow> V_no
     | Some True \<Rightarrow>
         (case ts of
            TW u _ # _ \<Rightarrow>
              (if u \<noteq> STR ''SELECT'' then V_unknown
               else if \<not> paren_balance ts then V_no
               else if TP (STR '';'') \<in> set ts then V_unknown
               else case combine (map seg_scan (segs 0 (STR ''SELECT'') [] (tl ts))) of
                      Sc_cert \<Rightarrow> V_no
                    | Sc_fail \<Rightarrow> V_unknown
                    | Sc_ok \<Rightarrow> V_yes (from_table ts))
          | _ \<Rightarrow> V_unknown))"

definition validity_reply :: "vres \<Rightarrow> reply" where
  "validity_reply v = (case v of
      V_yes None \<Rightarrow> Reply True (STR ''valid'') (STR ''Yes, SQLite parses it as valid SQL.'') None
    | V_yes (Some t) \<Rightarrow> Reply True (STR ''valid'')
        (STR ''Yes, the syntax is valid SQLite; running it needs the table it names (no such table: '' + t + STR '').'') None
    | V_no \<Rightarrow> Reply True (STR ''invalid'') (STR ''No, SQLite rejects it: syntax error.'') None
    | V_unknown \<Rightarrow> Reply False (STR ''unknown'') (STR '''') None)"

theorem validity_unbalanced_is_no:
  "\<not> paren_balance ts \<Longrightarrow> strip_semi ts = ts \<Longrightarrow> ts = TW (STR ''SELECT'') o' # r \<Longrightarrow> sql_validity ts = V_no"
  by (simp add: sql_validity_def stmt_words_ok_def Let_def stmt_words_def)

theorem validity_bad_leading_word:
  "u \<notin> set stmt_words \<Longrightarrow> strip_semi ts = TW u o' # r \<Longrightarrow> sql_validity ts = V_no"
  by (simp add: sql_validity_def stmt_words_ok_def Let_def)

theorem validity_yes_reply_answered: "answered (validity_reply (V_yes t))"
  by (cases t) (simp_all add: validity_reply_def)

theorem validity_unknown_withheld: "\<not> answered (validity_reply V_unknown)"
  by (simp add: validity_reply_def)

definition sql_self_test :: bool where
  "sql_self_test \<longleftrightarrow>
     (let w = (\<lambda>s. TW s s); p = (\<lambda>s. TP s); n = TI;
          cr = (\<lambda>s. (s, s));
          setup = [[TW (STR ''CREATE'') (STR ''create''), TW (STR ''TABLE'') (STR ''table''), TW (STR ''STOCK'') (STR ''stock''), TP (STR ''(''),
                    TW (STR ''ID'') (STR ''id''), TW (STR ''INTEGER'') (STR ''integer''), TW (STR ''PRIMARY'') (STR ''primary''), TW (STR ''KEY'') (STR ''key''),
                    TP (STR '',''), TW (STR ''CAT'') (STR ''cat''), TW (STR ''TEXT'') (STR ''text''), TP (STR '',''),
                    TW (STR ''QTY'') (STR ''qty''), TW (STR ''INTEGER'') (STR ''integer''), TP (STR '')''), TP (STR '';'')],
                   [TW (STR ''INSERT'') (STR ''insert''), TW (STR ''INTO'') (STR ''into''), TW (STR ''STOCK'') (STR ''stock''),
                    TW (STR ''VALUES'') (STR ''values''), TP (STR ''(''), TI 1, TP (STR '',''), TS (STR ''a''), TP (STR '',''), TI 2, TP (STR '')''),
                    TP (STR '',''), TP (STR ''(''), TI 2, TP (STR '',''), TS (STR ''b''), TP (STR '',''), TW (STR ''NULL'') (STR ''null''), TP (STR '')''),
                    TP (STR '',''), TP (STR ''(''), TI 3, TP (STR '',''), TS (STR ''b''), TP (STR '',''), TI 5, TP (STR '')''), TP (STR '';'')]];
          q1 = SQ False [SI_agg AF_count False None] (STR ''STOCK'', STR ''stock'') None None [] None;
          q2 = SQ False [SI_agg AF_sum False (Some (cr (STR ''QTY'')))] (STR ''STOCK'', STR ''stock'') None None [] None;
          q3 = SQ False [SI_col (cr (STR ''CAT'')), SI_agg AF_count False None] (STR ''STOCK'', STR ''stock'') None
                 (Some (cr (STR ''CAT''))) [(cr (STR ''CAT''), False)] None;
          q4 = SQ False [SI_agg AF_avg False (Some (cr (STR ''QTY'')))] (STR ''STOCK'', STR ''stock'') None None [] None
      in sql_run setup q1 = SRows [[SInt 3]] \<and> sql_run setup q2 = SRows [[SInt 7]] \<and>
         sql_run setup q3 = SRows [[SText (STR ''a''), SInt 1], [SText (STR ''b''), SInt 2]] \<and>
         sql_run setup q4 = SRows [[SReal (7 / 2)]] \<and>
         sql_run [] q1 = SNeedData \<and>
         response (sql_reply (SRows [[SReal (7 / 2)]])) = STR ''It returns 3.5 (run in SQLite on the tables you gave).'' \<and>
         response (sql_reply (SRows [[SInt 5, SText (STR ''x'')], [SNull, SText (STR ''y'')]])) =
           STR ''It returns 2 rows: (5, '' + apos + STR ''x'' + apos + STR ''); (NULL, '' + apos + STR ''y'' + apos + STR '') (run in SQLite on the tables you gave).'' \<and>
         sql_validity [w (STR ''SELEC''), w (STR ''NAME''), w (STR ''FROM''), w (STR ''STOCK'')] = V_no \<and>
         sql_validity [w (STR ''SELECT''), w (STR ''NAME''), w (STR ''FROM''), w (STR ''STOCK''), w (STR ''WHERE''), p (STR ''(''), w (STR ''QTY''), p (STR ''>''), n 3] = V_no \<and>
         sql_validity [w (STR ''SELECT''), p (STR '',''), w (STR ''NAME''), w (STR ''FROM''), w (STR ''STOCK'')] = V_no \<and>
         sql_validity [w (STR ''SELECT''), w (STR ''NAME''), w (STR ''FORM''), w (STR ''ITEMS'')] = V_no \<and>
         sql_validity [w (STR ''SELECT''), w (STR ''NAME''), w (STR ''FROM''), w (STR ''ITEMS''), w (STR ''WHERE''), w (STR ''QTY''), p (STR ''>'')] = V_no \<and>
         sql_validity [w (STR ''SELECT''), w (STR ''NAME''), w (STR ''FROM''), w (STR ''ITEMS''), w (STR ''ORDER''), w (STR ''BY'')] = V_no \<and>
         sql_validity [w (STR ''SELECT''), w (STR ''NAME''), p (STR '',''), w (STR ''PRICE''), p (STR ''*''), n 2, w (STR ''AS''), w (STR ''DOUBLE_PRICE''),
                       w (STR ''FROM''), w (STR ''ITEMS''), w (STR ''WHERE''), w (STR ''PRICE''), p (STR ''<''), n 5] = V_yes (Some (STR ''ITEMS'')))"


section \<open>Reading a SELECT into a query\<close>

definition plit :: "tok list \<Rightarrow> (sval \<times> tok list) option" where
  "plit ts = (case ts of
      TW u _ # r \<Rightarrow> if u = STR ''NULL'' then Some (SNull, r) else None
    | TI i # r \<Rightarrow> Some (SInt i, r) | TR x # r \<Rightarrow> Some (SReal x, r) | TS s # r \<Rightarrow> Some (SText s, r)
    | TP m # TI i # r \<Rightarrow> if m = STR ''-'' then Some (SInt (- i), r) else None
    | TP m # TR x # r \<Rightarrow> if m = STR ''-'' then Some (SReal (- x), r) else None
    | _ \<Rightarrow> None)"

definition cop_of :: "String.literal \<Rightarrow> cop option" where
  "cop_of p = (if p = STR ''='' \<or> p = STR ''=='' then Some C_eq else if p = STR ''!='' \<or> p = STR ''<>'' then Some C_ne
     else if p = STR ''<'' then Some C_lt else if p = STR ''<='' then Some C_le
     else if p = STR ''>'' then Some C_gt else if p = STR ''>='' then Some C_ge else None)"

fun pc :: "nat \<Rightarrow> nat \<Rightarrow> tok list \<Rightarrow> (scond \<times> tok list) option" where
  "pc 0 l ts = None"
| "pc (Suc f) l ts =
    (if l = 0 then
       Option.bind (pc f 1 ts) (\<lambda>cr. case snd cr of
           TW u _ # r2 \<Rightarrow> (if u = STR ''OR'' then Option.bind (pc f 0 r2) (\<lambda>cr2. Some (SC_or (fst cr) (fst cr2), snd cr2))
                          else Some cr)
         | _ \<Rightarrow> Some cr)
     else if l = 1 then
       Option.bind (pc f 2 ts) (\<lambda>cr. case snd cr of
           TW u _ # r2 \<Rightarrow> (if u = STR ''AND'' then Option.bind (pc f 1 r2) (\<lambda>cr2. Some (SC_and (fst cr) (fst cr2), snd cr2))
                          else Some cr)
         | _ \<Rightarrow> Some cr)
     else
       (case ts of
          TP p # r \<Rightarrow>
            (if p = STR ''('' then
               Option.bind (pc f 0 r) (\<lambda>cr. case snd cr of
                   TP q # r3 \<Rightarrow> (if q = STR '')'' then Some (fst cr, r3) else None) | _ \<Rightarrow> None)
             else None)
        | TW c o' # TW i _ # TW n _ # TW nl _ # r \<Rightarrow>
            (if i = STR ''IS'' \<and> n = STR ''NOT'' \<and> nl = STR ''NULL'' then Some (SC_isnull (c, o') True, r) else None)
        | TW c o' # TW i _ # TW nl _ # r \<Rightarrow>
            (if i = STR ''IS'' \<and> nl = STR ''NULL'' then Some (SC_isnull (c, o') False, r) else None)
        | TW c o' # TP p # r \<Rightarrow>
            (case cop_of p of None \<Rightarrow> None
             | Some co \<Rightarrow> (case plit r of None \<Rightarrow> None | Some (v, r2) \<Rightarrow> Some (SC_cmp (c, o') co v, r2)))
        | _ \<Rightarrow> None))"

definition stops :: "String.literal list \<Rightarrow> tok \<Rightarrow> bool" where
  "stops ws t = (case t of TW u _ \<Rightarrow> u \<in> set ws | _ \<Rightarrow> False)"

definition parse_item :: "tok list \<Rightarrow> sitem option" where
  "parse_item ts = (case ts of
      [TP s] \<Rightarrow> if s = STR ''*'' then Some SI_star else None
    | [TW u o'] \<Rightarrow> if u \<in> set clause_words then None else Some (SI_col (u, o'))
    | TW f _ # TP l # rest \<Rightarrow>
        (if l = STR ''('' \<and> rest \<noteq> [] \<and> last rest = TP (STR '')'') then
           (let inner = butlast rest; fn = (if f = STR ''COUNT'' then Some AF_count else if f = STR ''SUM'' then Some AF_sum
                      else if f = STR ''AVG'' then Some AF_avg else if f = STR ''MAX'' then Some AF_max
                      else if f = STR ''MIN'' then Some AF_min else None) in
            case fn of None \<Rightarrow> None | Some af \<Rightarrow>
              (case inner of
                 [TP s] \<Rightarrow> if s = STR ''*'' \<and> af = AF_count then Some (SI_agg af False None) else None
               | [TW c o'] \<Rightarrow> Some (SI_agg af False (Some (c, o')))
               | [TW d _, TW c o'] \<Rightarrow> if d = STR ''DISTINCT'' then Some (SI_agg af True (Some (c, o'))) else None
               | _ \<Rightarrow> None))
         else None)
    | _ \<Rightarrow> None)"

definition parse_order :: "tok list \<Rightarrow> (cref \<times> bool) option" where
  "parse_order ts = (case ts of
      [TW c o'] \<Rightarrow> Some ((c, o'), False)
    | [TW c o', TW d _] \<Rightarrow> if d = STR ''ASC'' then Some ((c, o'), False) else if d = STR ''DESC'' then Some ((c, o'), True) else None
    | _ \<Rightarrow> None)"

definition all_some :: "'a option list \<Rightarrow> 'a list option" where
  "all_some xs = (if None \<in> set xs then None else Some (map the xs))"

definition parse_query :: "tok list \<Rightarrow> sq option" where
  "parse_query ts0 = (case strip_semi ts0 of
      TW s _ # rest0 \<Rightarrow>
        (if s \<noteq> STR ''SELECT'' then None else
         let (dst, rest) = (case rest0 of TW d _ # r \<Rightarrow> if d = STR ''DISTINCT'' then (True, r) else (False, rest0) | _ \<Rightarrow> (False, rest0));
             its_toks = takeWhile (\<lambda>t. \<not> stops [STR ''FROM''] t) rest;
             after = dropWhile (\<lambda>t. \<not> stops [STR ''FROM''] t) rest
         in case after of
              TW _ _ # TW tu to # r0 \<Rightarrow>
                (let (wh, r1) = (case r0 of TW w _ # r \<Rightarrow> if w = STR ''WHERE'' then
                                   (Some (takeWhile (\<lambda>t. \<not> stops [STR ''GROUP'', STR ''ORDER'', STR ''LIMIT''] t) r),
                                    dropWhile (\<lambda>t. \<not> stops [STR ''GROUP'', STR ''ORDER'', STR ''LIMIT''] t) r)
                                   else (None, r0) | _ \<Rightarrow> (None, r0));
                     (gb, r2) = (case r1 of TW g _ # TW b _ # r \<Rightarrow> if g = STR ''GROUP'' \<and> b = STR ''BY'' then
                                   (Some (takeWhile (\<lambda>t. \<not> stops [STR ''ORDER'', STR ''LIMIT''] t) r),
                                    dropWhile (\<lambda>t. \<not> stops [STR ''ORDER'', STR ''LIMIT''] t) r)
                                   else (None, r1) | _ \<Rightarrow> (None, r1));
                     (ob, r3) = (case r2 of TW o2 _ # TW b _ # r \<Rightarrow> if o2 = STR ''ORDER'' \<and> b = STR ''BY'' then
                                   (Some (takeWhile (\<lambda>t. \<not> stops [STR ''LIMIT''] t) r),
                                    dropWhile (\<lambda>t. \<not> stops [STR ''LIMIT''] t) r)
                                   else (None, r2) | _ \<Rightarrow> (None, r2));
                     lmt = (case r3 of [] \<Rightarrow> Some None
                            | [TW l _, TI n] \<Rightarrow> if l = STR ''LIMIT'' \<and> 0 \<le> n then Some (Some (nat n)) else None
                            | _ \<Rightarrow> None);
                     items = all_some (map parse_item (split_top 0 [] its_toks));
                     cnd = (case wh of None \<Rightarrow> Some None
                            | Some w \<Rightarrow> (case pc 60 0 w of Some (c, []) \<Rightarrow> Some (Some c) | _ \<Rightarrow> None));
                     grp = (case gb of None \<Rightarrow> Some None
                            | Some [TW c o'] \<Rightarrow> Some (Some (c, o')) | Some _ \<Rightarrow> None);
                     ords = (case ob of None \<Rightarrow> Some [] | Some o3 \<Rightarrow> all_some (map parse_order (split_top 0 [] o3)))
                 in case (items, cnd, grp, ords, lmt) of
                      (Some its, Some c, Some g, Some os, Some l) \<Rightarrow> Some (SQ dst its (tu, to) c g os l)
                    | _ \<Rightarrow> None)
            | _ \<Rightarrow> None)
    | _ \<Rightarrow> None)"

definition sql_answer :: "tok list list \<Rightarrow> tok list \<Rightarrow> reply" where
  "sql_answer setup q = (case parse_query q of None \<Rightarrow> sql_reply SUnsupported | Some sq \<Rightarrow> sql_reply (sql_run setup sq))"

theorem sql_answer_unparsed_withheld: "parse_query q = None \<Longrightarrow> \<not> answered (sql_answer setup q)"
  by (simp add: sql_answer_def sql_reply_def)

definition sql_parse_test :: bool where
  "sql_parse_test \<longleftrightarrow>
     parse_query [TW (STR ''SELECT'') (STR ''select''), TW (STR ''SUM'') (STR ''sum''), TP (STR ''(''), TW (STR ''QTY'') (STR ''qty''), TP (STR '')''),
                  TW (STR ''FROM'') (STR ''from''), TW (STR ''STOCK'') (STR ''stock''), TW (STR ''WHERE'') (STR ''where''),
                  TW (STR ''CAT'') (STR ''cat''), TP (STR ''=''), TS (STR ''food'')] =
       Some (SQ False [SI_agg AF_sum False (Some (STR ''QTY'', STR ''qty''))] (STR ''STOCK'', STR ''stock'')
              (Some (SC_cmp (STR ''CAT'', STR ''cat'') C_eq (SText (STR ''food'')))) None [] None)"

end
