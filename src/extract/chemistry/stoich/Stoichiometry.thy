theory Stoichiometry
  imports "../Chemistry"
begin

text \<open>Explicit reaction certificates. The caller supplies the coefficients;
the kernel checks them against complete parsed formulas. This is an atom-count
model of a stated reaction, not a claim that the reaction occurs.\<close>

type_synonym reaction_side = "(counts \<times> nat) list"

fun parse_reaction_side :: "(string \<times> nat) list \<Rightarrow> reaction_side option" where
  "parse_reaction_side [] = Some []"
| "parse_reaction_side ((f, k) # xs) =
    (if k = 0 then None else
     case (parse_formula f, parse_reaction_side xs) of
       (FOk cs, Some ys) \<Rightarrow>
         if cs \<noteq> [] \<and> list_all (\<lambda>p. 0 < snd p) cs
         then Some ((cs, k) # ys) else None
     | _ \<Rightarrow> None)"

fun side_atoms :: "string \<Rightarrow> reaction_side \<Rightarrow> nat" where
  "side_atoms e [] = 0"
| "side_atoms e ((cs, k) # xs) = k * count_of e cs + side_atoms e xs"

fun side_symbols :: "reaction_side \<Rightarrow> string list" where
  "side_symbols [] = []"
| "side_symbols ((cs, k) # xs) = map fst cs @ side_symbols xs"

definition balanced_reaction :: "reaction_side \<Rightarrow> reaction_side \<Rightarrow> bool" where
  "balanced_reaction lhs rhs \<longleftrightarrow>
     lhs \<noteq> [] \<and> rhs \<noteq> [] \<and>
     list_all (\<lambda>p. 0 < snd p) (lhs @ rhs) \<and>
     list_all (\<lambda>e. side_atoms e lhs = side_atoms e rhs)
       (remdups (side_symbols lhs @ side_symbols rhs))"

lemma count_of_absent:
  assumes "e \<notin> set (map fst cs)"
  shows "count_of e cs = 0"
proof -
  have "filter (\<lambda>p. fst p = e) cs = []"
    using assms by (auto simp: filter_empty_conv)
  then show ?thesis by (simp add: count_of_def)
qed

lemma side_atoms_absent:
  "e \<notin> set (side_symbols xs) \<Longrightarrow> side_atoms e xs = 0"
proof (induction xs)
  case Nil then show ?case by simp
next
  case (Cons p xs)
  obtain cs k where p: "p = (cs, k)" by (cases p)
  show ?case using Cons by (simp add: p count_of_absent)
qed

theorem balanced_reaction_conserves_every_element:
  assumes "balanced_reaction lhs rhs"
  shows "side_atoms e lhs = side_atoms e rhs"
proof (cases "e \<in> set (side_symbols lhs @ side_symbols rhs)")
  case True
  with assms show ?thesis
    by (auto simp: balanced_reaction_def list_all_iff)
next
  case False
  then show ?thesis by (simp add: side_atoms_absent)
qed

theorem parsed_reaction_side_known:
  assumes "parse_reaction_side fs = Some xs"
  shows "\<forall>p \<in> set xs. 0 < snd p \<and> wf_counts (fst p) \<and>
      fst p \<noteq> [] \<and> (\<forall>q \<in> set (fst p). 0 < snd q)"
  using assms
proof (induction fs arbitrary: xs)
  case Nil then show ?case by simp
next
  case (Cons p fs)
  obtain f k where p: "p = (f, k)" by (cases p)
  obtain cs ys where parsed: "parse_formula f = FOk cs"
    and tail: "parse_reaction_side fs = Some ys" and positive: "0 < k"
    and counts: "cs \<noteq> [] \<and> list_all (\<lambda>q. 0 < snd q) cs"
    and shape: "xs = (cs, k) # ys"
    using Cons.prems p
    by (cases "parse_formula f"; cases "parse_reaction_side fs") (auto split: if_splits)
  have known: "wf_counts cs" by (rule parse_formula_wf[OF parsed])
  show ?case using Cons.IH[OF tail] known positive counts shape
    by (auto simp: list_all_iff)
qed

text \<open>A feed row is its positive stoichiometric coefficient and supplied
nonnegative amount in moles. The smallest amount/coefficient is the greatest
reaction extent that can consume every feed without a negative remainder.\<close>

type_synonym reaction_feed = "(nat \<times> rat) list"

definition valid_feed :: "reaction_feed \<Rightarrow> bool" where
  "valid_feed fs \<longleftrightarrow> fs \<noteq> [] \<and>
    (\<forall>p \<in> set fs. 0 < fst p \<and> 0 \<le> snd p)"

definition capacity :: "nat \<times> rat \<Rightarrow> rat" where
  "capacity p = snd p / of_nat (fst p)"

definition reaction_extent :: "reaction_feed \<Rightarrow> rat" where
  "reaction_extent fs = (if fs = [] then 0 else min_list (map capacity fs))"

definition feasible_extent :: "reaction_feed \<Rightarrow> rat \<Rightarrow> bool" where
  "feasible_extent fs x \<longleftrightarrow> 0 \<le> x \<and>
    (\<forall>p \<in> set fs. x * of_nat (fst p) \<le> snd p)"

definition reaction_leftovers :: "reaction_feed \<Rightarrow> rat list" where
  "reaction_leftovers fs = map (\<lambda>(k, a). a - reaction_extent fs * of_nat k) fs"

lemma extent_Min:
  "fs \<noteq> [] \<Longrightarrow> reaction_extent fs = Min (capacity ` set fs)"
  by (simp add: reaction_extent_def min_list_Min)

lemma feed_capacity_nonnegative:
  "valid_feed fs \<Longrightarrow> p \<in> set fs \<Longrightarrow> 0 \<le> capacity p"
  by (auto simp: valid_feed_def capacity_def intro: divide_nonneg_nonneg)

theorem reaction_extent_feasible:
  assumes "valid_feed fs"
  shows "feasible_extent fs (reaction_extent fs)"
proof -
  have ne: "fs \<noteq> []" using assms by (simp add: valid_feed_def)
  have nonnegative: "0 \<le> reaction_extent fs"
    using feed_capacity_nonnegative[OF assms]
    by (simp add: extent_Min[OF ne] ne)
  have bound: "reaction_extent fs * of_nat k \<le> a"
    if member: "(k, a) \<in> set fs" for k a
  proof -
    have pos: "0 < (of_nat k :: rat)"
      using assms member by (auto simp: valid_feed_def)
    have mem: "capacity (k, a) \<in> capacity ` set fs" using member by blast
    have "Min (capacity ` set fs) \<le> capacity (k, a)"
      by (rule Min_le) (simp_all add: mem)
    then have "reaction_extent fs \<le> a / of_nat k"
      by (simp add: extent_Min[OF ne] capacity_def)
    then show ?thesis using pos by (simp add: le_divide_eq)
  qed
  show ?thesis using nonnegative bound by (auto simp: feasible_extent_def)
qed

theorem reaction_extent_greatest:
  assumes "valid_feed fs" "feasible_extent fs x"
  shows "x \<le> reaction_extent fs"
proof -
  have ne: "fs \<noteq> []" using assms by (simp add: valid_feed_def)
  have bound: "x \<le> capacity p" if "p \<in> set fs" for p
    using assms that
    by (cases p) (auto simp: valid_feed_def feasible_extent_def capacity_def le_divide_eq)
  show ?thesis using bound by (simp add: extent_Min[OF ne] ne)
qed

theorem reaction_extent_exhausts_a_feed:
  assumes "valid_feed fs"
  shows "\<exists>k a. (k, a) \<in> set fs \<and> a - reaction_extent fs * of_nat k = 0"
proof -
  have ne: "fs \<noteq> []" using assms by (simp add: valid_feed_def)
  have "reaction_extent fs \<in> capacity ` set fs"
    by (simp add: extent_Min[OF ne] ne)
  then obtain k a where member: "(k, a) \<in> set fs"
    and ratio: "reaction_extent fs = a / of_nat k"
    by (auto simp: capacity_def)
  have "0 < k" using assms member by (auto simp: valid_feed_def)
  then have "a - reaction_extent fs * of_nat k = 0" by (simp add: ratio)
  with member show ?thesis by blast
qed

theorem reaction_leftovers_nonnegative:
  "valid_feed fs \<Longrightarrow> \<forall>a \<in> set (reaction_leftovers fs). 0 \<le> a"
  using reaction_extent_feasible[of fs]
  by (auto simp: reaction_leftovers_def feasible_extent_def)

theorem reaction_leftovers_contains_zero:
  assumes "valid_feed fs"
  shows "0 \<in> set (reaction_leftovers fs)"
proof -
  obtain k a where member: "(k, a) \<in> set fs"
    and zero: "a - reaction_extent fs * of_nat k = 0"
    using reaction_extent_exhausts_a_feed[OF assms] by blast
  have "a - reaction_extent fs * of_nat k \<in> set (reaction_leftovers fs)"
    using member unfolding reaction_leftovers_def by (force simp: image_iff)
  then show ?thesis by (simp add: zero)
qed

datatype reaction_result = ReactionResult reaction_side reaction_side reaction_feed rat

text \<open>This first model consumes each species once. Formula compositions
must be distinct across both sides, so catalysts, spectators and duplicate
formula aliases cannot become spurious independent feed constraints.\<close>

definition distinct_reaction_species :: "reaction_side \<Rightarrow> reaction_side \<Rightarrow> bool" where
  "distinct_reaction_species ls rs \<longleftrightarrow>
    distinct (map (\<lambda>p. map (\<lambda>e. count_of (psym e) (fst p)) ptable) (ls @ rs))"

definition checked_reaction ::
  "(string \<times> nat) list \<Rightarrow> (string \<times> nat) list \<Rightarrow> rat list
   \<Rightarrow> reaction_result option" where
  "checked_reaction lhs rhs amounts =
    (case (parse_reaction_side lhs, parse_reaction_side rhs) of
       (Some ls, Some rs) \<Rightarrow>
         (let fs = zip (map snd ls) amounts in
          if balanced_reaction ls rs \<and> distinct_reaction_species ls rs \<and> length amounts = length ls \<and> valid_feed fs
          then Some (ReactionResult ls rs fs (reaction_extent fs)) else None)
     | _ \<Rightarrow> None)"

theorem checked_reaction_certificate:
  "checked_reaction lhs rhs amounts = Some (ReactionResult ls rs fs x) \<Longrightarrow>
     parse_reaction_side lhs = Some ls \<and> parse_reaction_side rhs = Some rs \<and>
     balanced_reaction ls rs \<and> distinct_reaction_species ls rs \<and> length amounts = length ls \<and>
     fs = zip (map snd ls) amounts \<and> valid_feed fs \<and> x = reaction_extent fs"
  by (auto simp: checked_reaction_def Let_def split: option.splits if_splits)

theorem checked_reaction_conservation:
  "checked_reaction lhs rhs amounts = Some (ReactionResult ls rs fs x) \<Longrightarrow>
     side_atoms e ls = side_atoms e rs"
  using checked_reaction_certificate balanced_reaction_conserves_every_element by blast

theorem checked_reaction_bottleneck:
  "checked_reaction lhs rhs amounts = Some (ReactionResult ls rs fs x) \<Longrightarrow>
     feasible_extent fs x \<and> (\<forall>y. feasible_extent fs y \<longrightarrow> y \<le> x) \<and>
     (\<forall>a \<in> set (reaction_leftovers fs). 0 \<le> a) \<and>
     0 \<in> set (reaction_leftovers fs)"
  using checked_reaction_certificate reaction_extent_feasible reaction_extent_greatest
    reaction_leftovers_nonnegative reaction_leftovers_contains_zero by blast

datatype stoich_query = YieldMoles nat | YieldGrams nat | LeftMoles nat | LeftGrams nat

fun stoich_value :: "reaction_result \<Rightarrow> stoich_query \<Rightarrow> rat option" where
  "stoich_value (ReactionResult ls rs fs x) (YieldMoles i) =
    (if i < length rs then Some (x * of_nat (snd (rs ! i))) else None)"
| "stoich_value (ReactionResult ls rs fs x) (YieldGrams i) =
    (if i < length rs then Some (x * of_nat (snd (rs ! i)) * mass_total (fst (rs ! i))) else None)"
| "stoich_value (ReactionResult ls rs fs x) (LeftMoles i) =
    (if i < length fs then Some (snd (fs ! i) - x * of_nat (fst (fs ! i))) else None)"
| "stoich_value (ReactionResult ls rs fs x) (LeftGrams i) =
    (if i < length fs \<and> i < length ls
     then Some ((snd (fs ! i) - x * of_nat (fst (fs ! i))) * mass_total (fst (ls ! i))) else None)"

fun stoich_kind :: "stoich_query \<Rightarrow> String.literal" where
  "stoich_kind (YieldMoles _) = STR ''reaction_yield_moles''"
| "stoich_kind (YieldGrams _) = STR ''reaction_yield_grams''"
| "stoich_kind (LeftMoles _) = STR ''reaction_leftover_moles''"
| "stoich_kind (LeftGrams _) = STR ''reaction_leftover_grams''"

fun stoich_text :: "stoich_query \<Rightarrow> String.literal" where
  "stoich_text (YieldMoles _) = STR ''The theoretical yield is ''"
| "stoich_text (YieldGrams _) = STR ''The theoretical yield is ''"
| "stoich_text (LeftMoles _) = STR ''The amount remaining is ''"
| "stoich_text (LeftGrams _) = STR ''The amount remaining is ''"

fun stoich_unit :: "stoich_query \<Rightarrow> String.literal" where
  "stoich_unit (YieldMoles _) = STR '' mol''"
| "stoich_unit (YieldGrams _) = STR '' g''"
| "stoich_unit (LeftMoles _) = STR '' mol''"
| "stoich_unit (LeftGrams _) = STR '' g''"

definition reply_s ::
  "(string \<times> nat) list \<Rightarrow> (string \<times> nat) list \<Rightarrow> rat list
   \<Rightarrow> stoich_query \<Rightarrow> reply" where
  "reply_s lhs rhs amounts query =
    (case checked_reaction lhs rhs amounts of
       None \<Rightarrow> Reply False (STR ''impossible'')
         (STR ''A reaction calculation needs positive balanced coefficients, complete formulas, and one nonnegative mole amount for every reactant.'') None
     | Some result \<Rightarrow> (case stoich_value result query of
         None \<Rightarrow> Reply False (STR ''underspecified'') (STR ''The requested species is not on that side of the reaction.'') None
       | Some q \<Rightarrow> Reply True (stoich_kind query)
           (stoich_text query + nshow (NR q) + stoich_unit query +
            STR '' for the supplied balanced reaction, consuming the limiting reactant completely.'')
           (Some (nshow (NR q)))))"

theorem reply_s_answered_certificate:
  "answered (reply_s lhs rhs amounts query) \<Longrightarrow>
     \<exists>ls rs fs x q. checked_reaction lhs rhs amounts = Some (ReactionResult ls rs fs x) \<and>
       stoich_value (ReactionResult ls rs fs x) query = Some q \<and>
       (\<forall>e. side_atoms e ls = side_atoms e rs) \<and>
       feasible_extent fs x \<and> (\<forall>y. feasible_extent fs y \<longrightarrow> y \<le> x) \<and>
       0 \<in> set (reaction_leftovers fs)"
proof -
  assume answered: "answered (reply_s lhs rhs amounts query)"
  then obtain result q where result: "checked_reaction lhs rhs amounts = Some result"
    and chosen: "stoich_value result query = Some q"
    by (auto simp: reply_s_def split: option.splits)
  obtain ls rs fs x where shape: "result = ReactionResult ls rs fs x" by (cases result) auto
  show ?thesis using result chosen checked_reaction_conservation checked_reaction_bottleneck
    by (auto simp: shape)
qed

theorem reaction_yield_value:
  "checked_reaction lhs rhs amounts = Some (ReactionResult ls rs fs x) \<Longrightarrow>
   i < length rs \<Longrightarrow>
   stated (reply_s lhs rhs amounts (YieldMoles i)) = Some (nshow (NR (x * of_nat (snd (rs ! i)))))"
  by (simp add: reply_s_def)

end
