theory Effects_Indexed
  imports Veri7vn_Effects_Closure.Effects_Closure_Totality Veri7vn_Effects_RBT.RBT
begin

type_synonym effect_index = "(nat, nat list) rbt"
type_synonym effect_seen = "(nat, unit) rbt"

definition effect_successors :: "effect_index \<Rightarrow> nat \<Rightarrow> nat list" where
  "effect_successors index key = (case RBT.lookup index key of None \<Rightarrow> [] | Some xs \<Rightarrow> xs)"

definition index_dependency :: "nat \<Rightarrow> nat \<Rightarrow> effect_index \<Rightarrow> effect_index" where
  "index_dependency target dependency index =
    RBT.insert dependency (target # effect_successors index dependency) index"

definition index_record :: "retained_value \<Rightarrow> effect_index \<Rightarrow> effect_index" where
  "index_record value index = fold (index_dependency (retained_id value))
    (retained_dependencies value) index"

definition reverse_index :: "retained_value list \<Rightarrow> effect_index" where
  "reverse_index values = fold index_record values RBT.empty"

fun indexed_walk :: "nat \<Rightarrow> effect_index \<Rightarrow> nat list \<Rightarrow> effect_seen \<Rightarrow> effect_seen option" where
  "indexed_walk 0 index pending seen = (if pending=[] then Some seen else None)" |
  "indexed_walk (Suc fuel) index [] seen = Some seen" |
  "indexed_walk (Suc fuel) index (key#pending) seen =
    (if RBT.lookup seen key = None then indexed_walk fuel index
      (effect_successors index key @ pending) (RBT.insert key () seen)
     else indexed_walk fuel index pending seen)"

declare [[code drop: indexed_walk]]
lemma indexed_walk_code [code]:
  "indexed_walk fuel index pending seen = (if fuel=0 then
    (if pending=[] then Some seen else None) else
    (case pending of [] \<Rightarrow> Some seen | key#rest \<Rightarrow>
      if RBT.lookup seen key=None then indexed_walk (fuel-1) index
        (effect_successors index key @ rest) (RBT.insert key () seen)
      else indexed_walk (fuel-1) index rest seen))"
  by (cases fuel; cases pending) simp_all

definition closure_work :: "retained_value list \<Rightarrow> nat list \<Rightarrow> nat" where
  "closure_work values seeds = length seeds + sum_list (map (length \<circ> retained_dependencies) values)"

fun indexed_last_unique :: "nat list \<Rightarrow> effect_seen \<Rightarrow> nat list \<times> effect_seen" where
  "indexed_last_unique [] seen = ([],seen)" |
  "indexed_last_unique (key#keys) seen =
    (let (tail,used)=indexed_last_unique keys seen in
      if RBT.lookup used key = None then (key#tail,RBT.insert key () used) else (tail,used))"

definition indexed_reconstruction :: "retained_value list \<Rightarrow> nat list \<Rightarrow> effect_seen \<Rightarrow> nat list" where
  "indexed_reconstruction values seeds reached =
    fst (indexed_last_unique
      (seeds @ map retained_id (filter (\<lambda>value.
        list_ex (\<lambda>dependency. RBT.lookup reached dependency \<noteq> None)
          (retained_dependencies value)) values)) RBT.empty)"

definition indexed_forget_closure :: "retained_value list \<Rightarrow> nat list \<Rightarrow> nat list option" where
  "indexed_forget_closure values seeds = (if values=[] then Some seeds else
    map_option (indexed_reconstruction values seeds)
      (indexed_walk (closure_work values seeds) (reverse_index values) seeds RBT.empty))"

definition index_ancestor_record :: "retained_value \<Rightarrow> effect_index \<Rightarrow> effect_index" where
  "index_ancestor_record value index = RBT.insert (retained_id value)
    (retained_dependencies value @ effect_successors index (retained_id value)) index"

definition dependency_index :: "retained_value list \<Rightarrow> effect_index" where
  "dependency_index values = fold index_ancestor_record values RBT.empty"

definition protected_ancestor_summary :: "retained_value list \<Rightarrow> nat list \<Rightarrow> effect_seen option" where
  "protected_ancestor_summary values protected =
    indexed_walk (closure_work values protected) (dependency_index values) protected RBT.empty"

definition protected_ancestors_hit :: "effect_seen \<Rightarrow> nat list \<Rightarrow> bool" where
  "protected_ancestors_hit seen seeds = list_ex (\<lambda>key. RBT.lookup seen key \<noteq> None) seeds"

lemma ancestor_record_lookup:
  "set (effect_successors (index_ancestor_record value index) key) =
    set (effect_successors index key) \<union>
      (if key=retained_id value then set (retained_dependencies value) else {})"
  by (auto simp: effect_successors_def index_ancestor_record_def split: option.splits)

lemma dependency_index_edges:
  "set (effect_successors (dependency_index values) key) =
    {dependency. \<exists>value\<in>set values. retained_id value=key \<and>
      dependency\<in>set (retained_dependencies value)}"
proof -
  have general: "\<And>index. set (effect_successors (fold index_ancestor_record values index) key) =
      set (effect_successors index key) \<union>
      {dependency. \<exists>value\<in>set values. retained_id value=key \<and>
        dependency\<in>set (retained_dependencies value)}"
    by (induction "values") (auto simp: ancestor_record_lookup)
  show ?thesis by (simp only: dependency_index_def general; simp add: effect_successors_def)
qed

inductive dependency_path :: "retained_value list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" for records where
  refl: "dependency_path records key key" |
  step: "value\<in>set records \<Longrightarrow> dependency\<in>set (retained_dependencies value) \<Longrightarrow>
    dependency_path records dependency ancestor \<Longrightarrow>
    dependency_path records (retained_id value) ancestor"

definition ancestor_set :: "retained_value list \<Rightarrow> nat set \<Rightarrow> nat set" where
  "ancestor_set values protected = {ancestor. \<exists>key\<in>protected. dependency_path values key ancestor}"

definition dependent_set :: "retained_value list \<Rightarrow> nat set \<Rightarrow> nat set" where
  "dependent_set values seeds = {key. \<exists>seed\<in>seeds. dependency_path values key seed}"

lemma ancestor_dependent_intersection:
  "seeds \<inter> ancestor_set values protected = {} \<longleftrightarrow>
    dependent_set values seeds \<inter> protected = {}"
  by (auto simp: ancestor_set_def dependent_set_def)

lemma dependent_set_closed:
  "managed_closed values (dependent_set values seeds)"
  unfolding managed_closed_def dependent_set_def
  by (auto intro: dependency_path.step)

lemma dependent_set_includes:
  "seeds \<subseteq> dependent_set values seeds"
  by (auto simp: dependent_set_def intro: dependency_path.refl)

lemma path_closed:
  assumes "dependency_path values key seed" "managed_closed values reached" "seed\<in>reached"
  shows "key\<in>reached"
  using assms by (induction rule: dependency_path.induct) (auto simp: managed_closed_def)

lemma reference_reachable_set:
  "set (dependency_closure (length values) values seeds) = dependent_set values (set seeds)"
proof -
  let ?result = "set (dependency_closure (length values) values seeds)"
  have minimal: "?result \<subseteq> dependent_set values (set seeds)"
    by (rule dependency_closure_minimal)
      (rule dependent_set_includes, rule dependent_set_closed)
  have bound: "card (set (map retained_id values) - set seeds) \<le> length values"
    using card_mono[of "set (map retained_id values)" "set (map retained_id values) - set seeds"]
      card_length[of "map retained_id values"] by auto
  have closed: "managed_closed values ?result" by (rule closure_bound[OF bound])
  have seeds: "set seeds \<subseteq> ?result" by (rule dependency_closure_includes)
  have "dependent_set values (set seeds) \<subseteq> ?result"
    using path_closed[OF _ closed] seeds by (auto simp: dependent_set_def)
  with minimal show ?thesis by blast
qed

lemma reference_ancestor_guard:
  "set seeds \<inter> ancestor_set values (set protected) = {} \<longleftrightarrow>
    set (dependency_closure (length values) values seeds) \<inter> set protected = {}"
  using ancestor_dependent_intersection[of "set seeds" "values" "set protected"]
    reference_reachable_set[of "values" seeds] by simp

lemma indexed_last_unique_correct:
  "fst (indexed_last_unique xs seen) =
      filter (\<lambda>x. RBT.lookup seen x = None) (remdups xs) \<and>
    dom (RBT.lookup (snd (indexed_last_unique xs seen))) = set xs \<union> dom (RBT.lookup seen)"
proof (induction xs arbitrary: seen)
  case Nil then show ?case by simp
next
  case (Cons key keys)
  obtain tail used where pair: "indexed_last_unique keys seen = (tail,used)"
    by (cases "indexed_last_unique keys seen") auto
  have tail: "tail = filter (\<lambda>x. RBT.lookup seen x=None) (remdups keys)"
    and used: "dom (RBT.lookup used) = set keys \<union> dom (RBT.lookup seen)"
    using Cons.IH[of seen] pair by auto
  have absent: "RBT.lookup used key=None \<longleftrightarrow>
      key\<notin>set keys \<and> RBT.lookup seen key=None"
    using used by (metis Un_iff domIff)
  have insert_dom: "dom (RBT.lookup (RBT.insert key () used)) = insert key (dom (RBT.lookup used))"
    by (auto simp: dom_def)
  show ?case
    using tail used absent pair insert_dom
    by (auto simp: Let_def split: if_splits)
qed

lemma indexed_last_unique_empty:
  "fst (indexed_last_unique xs RBT.empty) = remdups xs"
  using indexed_last_unique_correct[of xs RBT.empty] by simp

definition indexed_new_ids :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "indexed_new_ids previous next = fst (indexed_last_unique next
    (fold (\<lambda>key. RBT.insert key ()) previous RBT.empty))"

lemma fold_seen_lookup:
  "RBT.lookup (fold (\<lambda>key. RBT.insert key ()) xs seen) key =
    (if key \<in> set xs then Some () else RBT.lookup seen key)"
  by (induction xs arbitrary: seen) auto

lemma indexed_new_ids_exact:
  "indexed_new_ids previous next = filter (\<lambda>key. key \<notin> set previous) (remdups next)"
  using indexed_last_unique_correct[of "next" "fold (\<lambda>key. RBT.insert key ()) previous RBT.empty"]
  by (simp add: indexed_new_ids_def fold_seen_lookup)

lemma successor_insert_edge:
  "set (effect_successors (index_dependency target dependency index) key) =
    set (effect_successors index key) \<union> (if key=dependency then {target} else {})"
  by (auto simp: effect_successors_def index_dependency_def split: option.splits)

lemma successor_fold_edges:
  "set (effect_successors (fold (index_dependency target) dependencies index) key) =
    set (effect_successors index key) \<union> (if key \<in> set dependencies then {target} else {})"
  by (induction dependencies arbitrary: index)
    (auto simp: successor_insert_edge)

lemma successor_record:
  "set (effect_successors (index_record value index) key) =
    set (effect_successors index key) \<union>
      (if key \<in> set (retained_dependencies value) then {retained_id value} else {})"
  by (simp add: index_record_def successor_fold_edges)

lemma reverse_index_edges:
  "set (effect_successors (reverse_index values) key) =
    {retained_id value |value. value \<in> set values \<and> key \<in> set (retained_dependencies value)}"
proof -
  have general: "\<And>index. set (effect_successors (fold index_record values index) key) =
      set (effect_successors index key) \<union>
      {retained_id value |value. value \<in> set values \<and> key \<in> set (retained_dependencies value)}"
    by (induction "values") (auto simp: successor_record)
  show ?thesis by (simp only: reverse_index_def general; simp add: effect_successors_def)
qed

lemma reverse_index_absent:
  assumes "key \<notin> set (concat (map retained_dependencies values))"
  shows "effect_successors (reverse_index values) key = []"
proof -
  have "set (effect_successors (reverse_index values) key) = {}"
    using assms by (auto simp: reverse_index_edges)
  then show ?thesis by simp
qed

text \<open>The termination potential is pending-list length plus the sum of
adjacency lengths at as-yet-unvisited keys. Every first pop removes that key's
entire adjacency contribution before pushing exactly that adjacency; later pops
push nothing. Duplicate edges count separately in both sums. The proofs below
connect the initial potential to closure_work and characterize reached sets.\<close>


lemma dependency_index_lengths:
  "length (effect_successors (dependency_index values) key) =
    sum_list (map (\<lambda>value. if retained_id value=key
      then length (retained_dependencies value) else 0) values)"
proof -
  have general: "\<And>index. length (effect_successors (fold index_ancestor_record values index) key) =
    length (effect_successors index key) +
      sum_list (map (\<lambda>value. if retained_id value=key
        then length (retained_dependencies value) else 0) values)"
    by (induction "values") (auto simp: effect_successors_def index_ancestor_record_def
      algebra_simps split: option.splits)
  show ?thesis by (simp only: dependency_index_def general; simp add: effect_successors_def)
qed

definition ancestor_work :: "retained_value list \<Rightarrow> effect_seen \<Rightarrow> nat" where
  "ancestor_work values seen = sum_list (map (\<lambda>value.
    if RBT.lookup seen (retained_id value) = None
    then length (retained_dependencies value) else 0) values)"

lemma ancestor_work_insert:
  assumes "RBT.lookup seen key=None"
  shows "ancestor_work values seen =
    length (effect_successors (dependency_index values) key) +
      ancestor_work values (RBT.insert key () seen)"
  unfolding ancestor_work_def dependency_index_lengths
  using assms by (induction "values") (auto simp: algebra_simps)

lemma indexed_walk_total:
  assumes work: "\<And>seen key. RBT.lookup seen key=None \<Longrightarrow>
      work seen = length (effect_successors index key) + work (RBT.insert key () seen)"
    and bound: "length pending + work seen \<le> fuel"
  shows "\<exists>result. indexed_walk fuel index pending seen = Some result"
  using bound
proof (induction fuel arbitrary: pending seen)
  case 0 then show ?case by auto
next
  case (Suc fuel)
  show ?case
  proof (cases pending)
    case Nil then show ?thesis by simp
  next
    case (Cons key rest)
    show ?thesis
    proof (cases "RBT.lookup seen key=None")
      case True
      have bound: "length (effect_successors index key @ rest) + work (RBT.insert key () seen) \<le> fuel"
        using Suc.prems work[OF True] Cons by simp
      from Suc.IH[OF bound] True Cons show ?thesis by simp
    next
      case False
      have bound: "length rest + work seen \<le> fuel" using Suc.prems Cons by simp
      from Suc.IH[OF bound] False Cons show ?thesis by simp
    qed
  qed
qed

lemma ancestor_walk_total:
  assumes "length pending + ancestor_work values seen \<le> fuel"
  shows "\<exists>result. indexed_walk fuel (dependency_index values) pending seen = Some result"
  by (rule indexed_walk_total[where work="ancestor_work values", OF _ assms])
    (meson ancestor_work_insert)

lemma protected_ancestor_summary_total:
  "\<exists>summary. protected_ancestor_summary values protected = Some summary"
  unfolding protected_ancestor_summary_def
  by (rule ancestor_walk_total)
    (simp add: closure_work_def ancestor_work_def comp_def)

definition index_closed :: "effect_index \<Rightarrow> nat set \<Rightarrow> bool" where
  "index_closed index reached \<longleftrightarrow>
    (\<forall>key\<in>reached. set (effect_successors index key) \<subseteq> reached)"

lemma indexed_walk_invariant:
  assumes run: "indexed_walk fuel index pending seen = Some result"
    and seeds: "seeds \<subseteq> dom (RBT.lookup seen) \<union> set pending"
    and closed: "\<And>key. key\<in>dom (RBT.lookup seen) \<Longrightarrow>
      set (effect_successors index key) \<subseteq> dom (RBT.lookup seen) \<union> set pending"
    and sound: "dom (RBT.lookup seen) \<union> set pending \<subseteq> allowed"
    and allowed: "index_closed index allowed"
  shows "seeds \<subseteq> dom (RBT.lookup result) \<and>
    index_closed index (dom (RBT.lookup result)) \<and> dom (RBT.lookup result) \<subseteq> allowed"
  using run seeds closed sound
proof (induction fuel arbitrary: pending seen)
  case 0
  then show ?case by (auto simp: index_closed_def split: if_splits)
next
  case (Suc fuel)
  show ?case
  proof (cases pending)
    case Nil
    with Suc.prems show ?thesis by (auto simp: index_closed_def)
  next
    case (Cons key rest)
    show ?thesis
    proof (cases "RBT.lookup seen key=None")
      case True
      have key: "key\<in>allowed" using Suc.prems Cons by auto
      have successors_allowed: "set (effect_successors index key) \<subseteq> allowed"
        using allowed key by (simp add: index_closed_def)
      have run: "indexed_walk fuel index (effect_successors index key @ rest)
          (RBT.insert key () seen) = Some result"
        using Suc.prems(1) Cons True by simp
      have domain: "dom (RBT.lookup (RBT.insert key () seen)) = insert key (dom (RBT.lookup seen))"
        by (auto simp: domIff)
      have next_seeds: "seeds \<subseteq> dom (RBT.lookup (RBT.insert key () seen)) \<union>
          set (effect_successors index key @ rest)"
        using Suc.prems(2) Cons by (simp only: domain set_append; auto)
      have next_closed: "\<And>visited. visited\<in>dom (RBT.lookup (RBT.insert key () seen)) \<Longrightarrow>
        set (effect_successors index visited) \<subseteq>
          dom (RBT.lookup (RBT.insert key () seen)) \<union> set (effect_successors index key @ rest)"
        using Suc.prems(3) Cons by (simp only: domain set_append; auto)
      have next_sound: "dom (RBT.lookup (RBT.insert key () seen)) \<union>
          set (effect_successors index key @ rest) \<subseteq> allowed"
        using Suc.prems(4) Cons key successors_allowed by (simp only: domain set_append; auto)
      show ?thesis by (rule Suc.IH[OF run next_seeds next_closed next_sound])
    next
      case False
      have key: "key\<in>dom (RBT.lookup seen)" using False by auto
      have run: "indexed_walk fuel index rest seen = Some result"
        using Suc.prems(1) Cons False by simp
      show ?thesis
        by (rule Suc.IH[OF run]) (use Suc.prems Cons key in auto)
    qed
  qed
qed


lemma successor_fold_lengths:
  "length (effect_successors (fold (index_dependency target) dependencies index) key) =
    length (effect_successors index key) + count_list dependencies key"
  by (induction dependencies arbitrary: index)
    (auto simp: effect_successors_def index_dependency_def algebra_simps split: option.splits)

lemma reverse_index_lengths:
  "length (effect_successors (reverse_index values) key) =
    count_list (concat (map retained_dependencies values)) key"
proof -
  have general: "\<And>index. length (effect_successors (fold index_record values index) key) =
      length (effect_successors index key) + count_list (concat (map retained_dependencies values)) key"
    by (induction "values") (auto simp: index_record_def successor_fold_lengths algebra_simps)
  show ?thesis by (simp only: reverse_index_def general; simp add: effect_successors_def)
qed

definition reverse_work :: "retained_value list \<Rightarrow> effect_seen \<Rightarrow> nat" where
  "reverse_work values seen = length (filter (\<lambda>key. RBT.lookup seen key=None)
    (concat (map retained_dependencies values)))"

lemma unseen_count_insert:
  assumes "RBT.lookup seen key=None"
  shows "length (filter (\<lambda>x. RBT.lookup seen x=None) xs) = count_list xs key +
    length (filter (\<lambda>x. RBT.lookup (RBT.insert key () seen) x=None) xs)"
  using assms by (induction xs) (auto simp: algebra_simps)

lemma reverse_walk_total:
  "\<exists>result. indexed_walk (closure_work values seeds) (reverse_index values) seeds RBT.empty = Some result"
proof (rule indexed_walk_total[where work="reverse_work values"])
  show "\<And>seen key. RBT.lookup seen key=None \<Longrightarrow>
    reverse_work values seen = length (effect_successors (reverse_index values) key) +
      reverse_work values (RBT.insert key () seen)"
    by (simp add: reverse_work_def reverse_index_lengths unseen_count_insert)
  show "length seeds + reverse_work values RBT.empty \<le> closure_work values seeds"
    by (simp add: reverse_work_def closure_work_def length_concat comp_def)
qed

lemma dependent_set_index_closed:
  "index_closed (reverse_index values) (dependent_set values seeds)"
  by (auto simp: index_closed_def dependent_set_def reverse_index_edges
    intro: dependency_path.step)

lemma dependent_path_closed:
  assumes "dependency_path values key seed" "index_closed (reverse_index values) reached" "seed\<in>reached"
  shows "key\<in>reached"
  using assms by (induction rule: dependency_path.induct)
    (auto simp: index_closed_def reverse_index_edges)

lemma reverse_walk_exact:
  assumes "indexed_walk fuel (reverse_index values) seeds RBT.empty = Some reached"
  shows "dom (RBT.lookup reached) = dependent_set values (set seeds)"
proof -
  have invariant: "set seeds \<subseteq> dom (RBT.lookup reached) \<and>
      index_closed (reverse_index values) (dom (RBT.lookup reached)) \<and>
      dom (RBT.lookup reached) \<subseteq> dependent_set values (set seeds)"
    by (rule indexed_walk_invariant[OF assms])
      (use dependent_set_includes[of "set seeds" "values"] in
        \<open>auto intro: dependent_set_index_closed\<close>)
  have closed: "index_closed (reverse_index values) (dom (RBT.lookup reached))"
    using invariant by blast
  have "dependent_set values (set seeds) \<subseteq> dom (RBT.lookup reached)"
  proof
    fix candidate
    assume "candidate\<in>dependent_set values (set seeds)"
    then obtain seed where seed: "seed\<in>set seeds" and path: "dependency_path values candidate seed"
      by (auto simp: dependent_set_def)
    have seed_seen: "seed\<in>dom (RBT.lookup reached)" using invariant seed by blast
    show "candidate\<in>dom (RBT.lookup reached)"
      by (rule dependent_path_closed[OF path closed seed_seen])
  qed
  with invariant show ?thesis by blast
qed

lemma dependency_path_trans:
  "dependency_path values a b \<Longrightarrow> dependency_path values b c \<Longrightarrow>
    dependency_path values a c"
  by (induction rule: dependency_path.induct) (auto intro: dependency_path.intros)

lemma ancestor_set_index_closed:
  "index_closed (dependency_index values) (ancestor_set values protected)"
  unfolding index_closed_def
proof
  fix key
  assume key: "key\<in>ancestor_set values protected"
  show "set (effect_successors (dependency_index values) key) \<subseteq> ancestor_set values protected"
  proof
    fix dependency
    assume dependency: "dependency\<in>set (effect_successors (dependency_index values) key)"
    obtain root where root: "root\<in>protected" and path: "dependency_path values root key"
      using key by (auto simp: ancestor_set_def)
    obtain record_value where record_member: "record_value\<in>set values"
        and id: "retained_id record_value=key"
        and edge: "dependency\<in>set (retained_dependencies record_value)"
      using dependency by (auto simp: dependency_index_edges)
    have one_step: "dependency_path values (retained_id record_value) dependency"
      by (rule dependency_path.step[OF record_member edge]) (rule dependency_path.refl)
    have key_step: "dependency_path values key dependency" using one_step id by simp
    have composed: "dependency_path values root dependency"
      by (rule dependency_path_trans[OF path key_step])
    show "dependency\<in>ancestor_set values protected"
      using root composed by (auto simp: ancestor_set_def)
  qed
qed

lemma ancestor_path_closed:
  assumes "dependency_path values key ancestor"
    "index_closed (dependency_index values) reached" "key\<in>reached"
  shows "ancestor\<in>reached"
  using assms
  by (induction rule: dependency_path.induct)
    (auto simp: index_closed_def dependency_index_edges)

lemma protected_ancestor_summary_exact:
  assumes "protected_ancestor_summary values protected = Some summary"
  shows "dom (RBT.lookup summary) = ancestor_set values (set protected)"
proof -
  have included: "set protected \<subseteq> ancestor_set values (set protected)"
    by (auto simp: ancestor_set_def intro: dependency_path.refl)
  have invariant: "set protected \<subseteq> dom (RBT.lookup summary) \<and>
      index_closed (dependency_index values) (dom (RBT.lookup summary)) \<and>
      dom (RBT.lookup summary) \<subseteq> ancestor_set values (set protected)"
    by (rule indexed_walk_invariant[OF assms[unfolded protected_ancestor_summary_def]])
      (use included in \<open>auto intro: ancestor_set_index_closed\<close>)
  have closed: "index_closed (dependency_index values) (dom (RBT.lookup summary))"
    using invariant by blast
  have "ancestor_set values (set protected) \<subseteq> dom (RBT.lookup summary)"
  proof
    fix candidate
    assume "candidate\<in>ancestor_set values (set protected)"
    then obtain root where root: "root\<in>set protected" and path: "dependency_path values root candidate"
      by (auto simp: ancestor_set_def)
    have root_seen: "root\<in>dom (RBT.lookup summary)" using invariant root by blast
    show "candidate\<in>dom (RBT.lookup summary)"
      by (rule ancestor_path_closed[OF path closed root_seen])
  qed
  with invariant show ?thesis by blast
qed

lemma protected_ancestors_hit_exact:
  assumes "protected_ancestor_summary values protected = Some summary"
  shows "protected_ancestors_hit summary seeds \<longleftrightarrow>
    set (dependency_closure (length values) values seeds) \<inter> set protected \<noteq> {}"
  using protected_ancestor_summary_exact[OF assms]
    reference_ancestor_guard[of seeds "values" protected]
  by (auto simp: protected_ancestors_hit_def list_ex_iff dom_def)

lemma protected_ancestors_groups_safe:
  assumes summary: "protected_ancestor_summary values protected = Some summary"
  shows "set (dependency_closure (length values) values
      (concat (filter (\<lambda>roots. \<not> protected_ancestors_hit summary roots) groups)))
    \<inter> set protected = {}"
proof -
  have safe: "\<not> protected_ancestors_hit summary
      (concat (filter (\<lambda>roots. \<not> protected_ancestors_hit summary roots) groups))"
    by (auto simp: protected_ancestors_hit_def list_ex_iff)
  from protected_ancestors_hit_exact[OF summary] safe show ?thesis by blast
qed

lemma indexed_empty_exact:
  "indexed_forget_closure [] seeds = forget_closure [] seeds"
  by (simp add: indexed_forget_closure_def forget_closure_def managed_closed_def list_all_iff Let_def)

text \<open>This implementation is isolated and is not selected as a code equation.
The candidate proofs establish edge multiplicity, the actual-edge work bound and
reachable-set equality. The optional complete child connects exact reference list
reconstruction. Native qualification and generated consumer measurement are still
required. Fuel is derived from the graph, not a caller-selected rejection cap.\<close>

export_code indexed_forget_closure protected_ancestor_summary protected_ancestors_hit indexed_new_ids in SML module_name IndexedEffects
end
