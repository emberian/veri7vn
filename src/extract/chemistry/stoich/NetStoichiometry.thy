theory NetStoichiometry
  imports Stoichiometry
begin

text \<open>Species identity is the supplied formula spelling, after the reader's
explicit syntactic normalization. Element counts are used only for balance;
they do not identify different formula spellings or structural isomers.\<close>

definition species_coefficient :: "string \<Rightarrow> (string \<times> nat) list \<Rightarrow> nat" where
  "species_coefficient f side = sum_list (map snd (filter (\<lambda>p. fst p = f) side))"

lemma species_coefficient_append:
  "species_coefficient f (xs @ ys) = species_coefficient f xs + species_coefficient f ys"
  by (simp add: species_coefficient_def)

lemma species_coefficient_other:
  "f \<noteq> g \<Longrightarrow> species_coefficient f ((g, k) # xs) = species_coefficient f xs"
  by (simp add: species_coefficient_def)

lemma species_coefficient_same:
  "species_coefficient f ((f, k) # xs) = k + species_coefficient f xs"
  by (simp add: species_coefficient_def)

definition initial_amount :: "string \<Rightarrow> (string \<times> rat) list \<Rightarrow> rat" where
  "initial_amount f amounts = sum_list (map snd (filter (\<lambda>p. fst p = f) amounts))"

datatype net_species = NetSpecies string counts nat nat rat

fun species_name where "species_name (NetSpecies f cs l r a) = f"
fun species_counts where "species_counts (NetSpecies f cs l r a) = cs"
fun species_left where "species_left (NetSpecies f cs l r a) = l"
fun species_right where "species_right (NetSpecies f cs l r a) = r"
fun species_initial where "species_initial (NetSpecies f cs l r a) = a"

fun prepare_species :: "string list \<Rightarrow> (string \<times> nat) list \<Rightarrow>
    (string \<times> nat) list \<Rightarrow> (string \<times> rat) list \<Rightarrow> net_species list option" where
  "prepare_species [] lhs rhs amounts = Some []"
| "prepare_species (f # names) lhs rhs amounts =
    (case (parse_formula f, prepare_species names lhs rhs amounts) of
      (FOk cs, Some rest) \<Rightarrow>
        (if cs \<noteq> [] \<and> list_all (\<lambda>p. 0 < snd p) cs then
          Some (NetSpecies f cs (species_coefficient f lhs)
            (species_coefficient f rhs) (initial_amount f amounts) # rest)
         else None)
    | _ \<Rightarrow> None)"

theorem prepared_species_bindings:
  assumes "prepare_species names lhs rhs amounts = Some ss"
  shows "\<forall>s \<in> set ss.
    parse_formula (species_name s) = FOk (species_counts s) \<and>
    species_left s = species_coefficient (species_name s) lhs \<and>
    species_right s = species_coefficient (species_name s) rhs \<and>
    species_initial s = initial_amount (species_name s) amounts"
  using assms
proof (induction names arbitrary: ss)
  case Nil then show ?case by simp
next
  case (Cons f names)
  obtain cs rest where parsed: "parse_formula f = FOk cs"
    and tail: "prepare_species names lhs rhs amounts = Some rest"
    and shape: "ss = NetSpecies f cs (species_coefficient f lhs)
      (species_coefficient f rhs) (initial_amount f amounts) # rest"
    using Cons.prems
    by (cases "parse_formula f"; cases "prepare_species names lhs rhs amounts")
       (auto split: if_splits)
  show ?case using Cons.IH[OF tail] parsed shape by auto
qed

theorem prepared_species_names:
  "prepare_species names lhs rhs amounts = Some ss \<Longrightarrow> map species_name ss = names"
  by (induction names arbitrary: ss)
    (auto split: fparse.splits option.splits if_splits)

definition net_consumed :: "net_species \<Rightarrow> nat" where
  "net_consumed s = species_left s - species_right s"

definition net_produced :: "net_species \<Rightarrow> nat" where
  "net_produced s = species_right s - species_left s"

definition net_feed :: "net_species list \<Rightarrow> reaction_feed" where
  "net_feed ss = map (\<lambda>s. (net_consumed s, species_initial s))
    (filter (\<lambda>s. 0 < net_consumed s) ss)"

definition net_left_side :: "net_species list \<Rightarrow> reaction_side" where
  "net_left_side ss = map (\<lambda>s. (species_counts s, net_consumed s))
    (filter (\<lambda>s. 0 < net_consumed s) ss)"

definition net_right_side :: "net_species list \<Rightarrow> reaction_side" where
  "net_right_side ss = map (\<lambda>s. (species_counts s, net_produced s))
    (filter (\<lambda>s. 0 < net_produced s) ss)"

definition final_amount :: "net_species \<Rightarrow> rat \<Rightarrow> rat" where
  "final_amount s x = species_initial s +
     x * (of_nat (species_right s) - of_nat (species_left s))"

lemma spectator_zero_net:
  "species_left s = species_right s \<Longrightarrow> net_consumed s = 0 \<and> net_produced s = 0"
  by (simp add: net_consumed_def net_produced_def)

lemma spectator_excluded_from_consumers:
  "species_left s = species_right s \<Longrightarrow>
    s \<notin> set (filter (\<lambda>r. 0 < net_consumed r) ss)"
  by (auto simp: net_consumed_def)

theorem spectator_does_not_limit:
  "reaction_extent (net_feed (NetSpecies f cs k k a # ss)) = reaction_extent (net_feed ss)"
  by (simp add: net_feed_def net_consumed_def)

lemma spectator_inventory_unchanged:
  "species_left s = species_right s \<Longrightarrow> final_amount s x = species_initial s"
  by (simp add: final_amount_def)

lemma final_amount_consumer:
  "species_right s < species_left s \<Longrightarrow>
   final_amount s x = species_initial s - x * of_nat (net_consumed s)"
  by (simp add: final_amount_def net_consumed_def of_nat_diff algebra_simps)

theorem net_inventory_nonnegative:
  assumes "feasible_extent (net_feed ss) x"
    and initial: "\<forall>s \<in> set ss. 0 \<le> species_initial s"
    and member: "s \<in> set ss"
  shows "0 \<le> final_amount s x"
proof (cases "species_right s < species_left s")
  case True
  then have positive: "0 < net_consumed s" by (simp add: net_consumed_def)
  have "(net_consumed s, species_initial s) \<in> set (net_feed ss)"
    using member positive by (auto simp: net_feed_def)
  then have "x * of_nat (net_consumed s) \<le> species_initial s"
    using assms(1) by (auto simp: feasible_extent_def)
  then show ?thesis using True by (simp add: final_amount_consumer)
next
  case False
  have nonnegative: "0 \<le> x" using assms(1) by (simp add: feasible_extent_def)
  have delta: "0 \<le> (of_nat (species_right s) - of_nat (species_left s) :: rat)"
    using False by simp
  have "0 \<le> x * (of_nat (species_right s) - of_nat (species_left s))"
    by (rule mult_nonneg_nonneg[OF nonnegative delta])
  then show ?thesis using initial member by (auto simp: final_amount_def)
qed

text \<open>The final inventory is connected to element conservation, not only
to the checked equation. These rational totals count moles of each element.\<close>

definition inventory_atoms :: "string \<Rightarrow> net_species list \<Rightarrow> rat \<Rightarrow> rat" where
  "inventory_atoms e ss x = sum_list (map
    (\<lambda>s. final_amount s x * of_nat (count_of e (species_counts s))) ss)"

definition initial_inventory_atoms :: "string \<Rightarrow> net_species list \<Rightarrow> rat" where
  "initial_inventory_atoms e ss = sum_list (map
    (\<lambda>s. species_initial s * of_nat (count_of e (species_counts s))) ss)"

definition signed_atom_delta :: "string \<Rightarrow> net_species list \<Rightarrow> rat" where
  "signed_atom_delta e ss = sum_list (map
    (\<lambda>s. (of_nat (species_right s) - of_nat (species_left s)) *
      of_nat (count_of e (species_counts s))) ss)"

lemma net_coefficient_difference:
  "(of_nat (species_right s) - of_nat (species_left s) :: rat) =
    of_nat (net_produced s) - of_nat (net_consumed s)"
  by (cases "species_left s \<le> species_right s")
    (simp_all add: net_produced_def net_consumed_def of_nat_diff)

lemma net_left_atoms_Cons:
  "side_atoms e (net_left_side (s # ss)) =
    net_consumed s * count_of e (species_counts s) + side_atoms e (net_left_side ss)"
  by (cases "net_consumed s = 0") (simp_all add: net_left_side_def)

lemma net_right_atoms_Cons:
  "side_atoms e (net_right_side (s # ss)) =
    net_produced s * count_of e (species_counts s) + side_atoms e (net_right_side ss)"
  by (cases "net_produced s = 0") (simp_all add: net_right_side_def)

lemma signed_atom_delta_sides:
  "signed_atom_delta e ss =
    of_nat (side_atoms e (net_right_side ss)) - of_nat (side_atoms e (net_left_side ss))"
proof (induction ss)
  case Nil then show ?case
    by (simp add: signed_atom_delta_def net_left_side_def net_right_side_def)
next
  case (Cons s ss)
  have step: "signed_atom_delta e (s # ss) =
    (of_nat (species_right s) - of_nat (species_left s)) *
      of_nat (count_of e (species_counts s)) + signed_atom_delta e ss"
    by (simp add: signed_atom_delta_def)
  show ?case
    by (simp only: step net_left_atoms_Cons net_right_atoms_Cons of_nat_add of_nat_mult Cons.IH)
       (simp add: net_coefficient_difference algebra_simps)
qed

lemma inventory_atoms_affine:
  "inventory_atoms e ss x = initial_inventory_atoms e ss + x * signed_atom_delta e ss"
  by (induction ss)
    (simp_all add: inventory_atoms_def initial_inventory_atoms_def signed_atom_delta_def
      final_amount_def algebra_simps)

theorem net_inventory_atom_conservation:
  assumes "balanced_reaction (net_left_side ss) (net_right_side ss)"
  shows "inventory_atoms e ss x = initial_inventory_atoms e ss"
proof -
  have "side_atoms e (net_left_side ss) = side_atoms e (net_right_side ss)"
    by (rule balanced_reaction_conserves_every_element[OF assms])
  then have "signed_atom_delta e ss = 0" by (simp add: signed_atom_delta_sides)
  then show ?thesis by (simp add: inventory_atoms_affine)
qed

definition valid_inventory :: "string list \<Rightarrow> string list \<Rightarrow>
    (string \<times> rat) list \<Rightarrow> bool" where
  "valid_inventory reactants names amounts \<longleftrightarrow>
    distinct (map fst amounts) \<and> set reactants \<subseteq> set (map fst amounts) \<and>
    set (map fst amounts) \<subseteq> set names \<and> list_all (\<lambda>p. 0 \<le> snd p) amounts"

datatype net_result = NetResult reaction_side reaction_side "net_species list" rat

text \<open>The formula-only interface cannot resolve whether distinct spellings
with equal atom counts are aliases or different isomers. It conservatively
withholds that ambiguity, while repeated identical names aggregate normally.\<close>

definition distinct_net_compositions :: "net_species list \<Rightarrow> bool" where
  "distinct_net_compositions ss \<longleftrightarrow>
    distinct (map (\<lambda>s. map (\<lambda>e. count_of (psym e) (species_counts s)) ptable) ss)"

definition checked_net_reaction :: "(string \<times> nat) list \<Rightarrow>
    (string \<times> nat) list \<Rightarrow> (string \<times> rat) list \<Rightarrow> net_result option" where
  "checked_net_reaction lhs rhs amounts =
    (let names = remdups (map fst lhs @ map fst rhs) in
     case (parse_reaction_side lhs, parse_reaction_side rhs,
           prepare_species names lhs rhs amounts) of
       (Some ls, Some rs, Some ss) \<Rightarrow>
         if distinct_net_compositions ss \<and> balanced_reaction ls rs \<and> balanced_reaction (net_left_side ss) (net_right_side ss) \<and>
            valid_inventory (map fst lhs) names amounts \<and>
            list_all (\<lambda>s. 0 \<le> species_initial s) ss \<and> valid_feed (net_feed ss)
         then Some (NetResult ls rs ss (reaction_extent (net_feed ss))) else None
     | _ \<Rightarrow> None)"

theorem checked_net_certificate:
  "checked_net_reaction lhs rhs amounts = Some (NetResult ls rs ss x) \<Longrightarrow>
    parse_reaction_side lhs = Some ls \<and> parse_reaction_side rhs = Some rs \<and>
    prepare_species (remdups (map fst lhs @ map fst rhs)) lhs rhs amounts = Some ss \<and>
    distinct_net_compositions ss \<and> balanced_reaction ls rs \<and> balanced_reaction (net_left_side ss) (net_right_side ss) \<and>
    valid_inventory (map fst lhs) (remdups (map fst lhs @ map fst rhs)) amounts \<and>
    (\<forall>s \<in> set ss. 0 \<le> species_initial s) \<and> valid_feed (net_feed ss) \<and>
    x = reaction_extent (net_feed ss)"
  by (auto simp: checked_net_reaction_def Let_def list_all_iff split: option.splits if_splits)

theorem checked_net_conservation:
  "checked_net_reaction lhs rhs amounts = Some (NetResult ls rs ss x) \<Longrightarrow>
    side_atoms e ls = side_atoms e rs \<and>
    side_atoms e (net_left_side ss) = side_atoms e (net_right_side ss)"
  using checked_net_certificate balanced_reaction_conserves_every_element by blast

theorem checked_net_inventory_conservation:
  "checked_net_reaction lhs rhs amounts = Some (NetResult ls rs ss x) \<Longrightarrow>
    inventory_atoms e ss x = initial_inventory_atoms e ss"
  using checked_net_certificate net_inventory_atom_conservation by blast

theorem checked_net_limiting_extent:
  assumes checked: "checked_net_reaction lhs rhs amounts = Some (NetResult ls rs ss x)"
  shows "feasible_extent (net_feed ss) x \<and>
    (\<forall>y. feasible_extent (net_feed ss) y \<longrightarrow> y \<le> x) \<and>
    0 \<in> set (reaction_leftovers (net_feed ss)) \<and>
    (\<forall>s \<in> set ss. 0 \<le> final_amount s x)"
proof -
  have valid: "valid_feed (net_feed ss)" and extent: "x = reaction_extent (net_feed ss)"
    and initial: "\<forall>s \<in> set ss. 0 \<le> species_initial s"
    using checked_net_certificate[OF checked] by blast+
  have feasible: "feasible_extent (net_feed ss) x"
    using reaction_extent_feasible[OF valid] by (simp add: extent)
  have greatest: "\<forall>y. feasible_extent (net_feed ss) y \<longrightarrow> y \<le> x"
    using reaction_extent_greatest[OF valid] extent by blast
  have exhausted: "0 \<in> set (reaction_leftovers (net_feed ss))"
    by (rule reaction_leftovers_contains_zero[OF valid])
  have final: "\<forall>s \<in> set ss. 0 \<le> final_amount s x"
    using net_inventory_nonnegative[OF feasible initial] by blast
  show ?thesis using feasible greatest exhausted final by blast
qed


datatype net_query = NetYieldMoles string | NetYieldGrams string |
  NetFinalMoles string | NetFinalGrams string

fun net_query_name where
  "net_query_name (NetYieldMoles f) = f"
| "net_query_name (NetYieldGrams f) = f"
| "net_query_name (NetFinalMoles f) = f"
| "net_query_name (NetFinalGrams f) = f"

fun net_species_value :: "net_species \<Rightarrow> rat \<Rightarrow> net_query \<Rightarrow> rat" where
  "net_species_value s x (NetYieldMoles _) = x * of_nat (net_produced s)"
| "net_species_value s x (NetYieldGrams _) = x * of_nat (net_produced s) * mass_total (species_counts s)"
| "net_species_value s x (NetFinalMoles _) = final_amount s x"
| "net_species_value s x (NetFinalGrams _) = final_amount s x * mass_total (species_counts s)"

fun net_value :: "net_result \<Rightarrow> net_query \<Rightarrow> rat option" where
  "net_value (NetResult ls rs ss x) query =
    (case List.find (\<lambda>s. species_name s = net_query_name query) ss of
      None \<Rightarrow> None | Some s \<Rightarrow> Some (net_species_value s x query))"

fun net_query_kind where
  "net_query_kind (NetYieldMoles _) = STR ''reaction_yield_moles''"
| "net_query_kind (NetYieldGrams _) = STR ''reaction_yield_grams''"
| "net_query_kind (NetFinalMoles _) = STR ''reaction_leftover_moles''"
| "net_query_kind (NetFinalGrams _) = STR ''reaction_leftover_grams''"

fun net_query_text where
  "net_query_text (NetYieldMoles _) = STR ''The net theoretical yield is ''"
| "net_query_text (NetYieldGrams _) = STR ''The net theoretical yield is ''"
| "net_query_text (NetFinalMoles _) = STR ''The final amount is ''"
| "net_query_text (NetFinalGrams _) = STR ''The final amount is ''"

fun net_query_unit where
  "net_query_unit (NetYieldMoles _) = STR '' mol''"
| "net_query_unit (NetYieldGrams _) = STR '' g''"
| "net_query_unit (NetFinalMoles _) = STR '' mol''"
| "net_query_unit (NetFinalGrams _) = STR '' g''"

definition reply_net :: "(string \<times> nat) list \<Rightarrow> (string \<times> nat) list \<Rightarrow>
    (string \<times> rat) list \<Rightarrow> net_query \<Rightarrow> reply" where
  "reply_net lhs rhs amounts query =
    (case checked_net_reaction lhs rhs amounts of
      None \<Rightarrow> Reply False (STR ''impossible'')
        (STR ''This calculation needs balanced positive coefficients, unambiguous species formulas, distinct nonnegative initial amounts for all reactants, and a nonzero net reaction.'') None
    | Some result \<Rightarrow> (case net_value result query of
        None \<Rightarrow> Reply False (STR ''underspecified'')
          (STR ''The requested species does not occur in the supplied reaction.'') None
      | Some q \<Rightarrow> Reply True (net_query_kind query)
          (net_query_text query + nshow (NR q) + net_query_unit query +
           STR '' under complete conversion of the net limiting reactant.'')
          (Some (nshow (NR q)))))"

theorem reply_net_answered_certificate:
  "answered (reply_net lhs rhs amounts query) \<Longrightarrow>
    \<exists>ls rs ss x q. checked_net_reaction lhs rhs amounts = Some (NetResult ls rs ss x) \<and>
      net_value (NetResult ls rs ss x) query = Some q \<and>
      (\<forall>e. side_atoms e ls = side_atoms e rs \<and>
        side_atoms e (net_left_side ss) = side_atoms e (net_right_side ss) \<and>
        inventory_atoms e ss x = initial_inventory_atoms e ss) \<and>
      feasible_extent (net_feed ss) x \<and>
      (\<forall>y. feasible_extent (net_feed ss) y \<longrightarrow> y \<le> x) \<and>
      0 \<in> set (reaction_leftovers (net_feed ss)) \<and>
      (\<forall>s \<in> set ss. 0 \<le> final_amount s x)"
proof -
  assume answered: "answered (reply_net lhs rhs amounts query)"
  then obtain result q where checked: "checked_net_reaction lhs rhs amounts = Some result"
    and chosen: "net_value result query = Some q"
    by (auto simp: reply_net_def split: option.splits)
  obtain ls rs ss x where shape: "result = NetResult ls rs ss x" by (cases result) auto
  show ?thesis using checked chosen checked_net_conservation checked_net_inventory_conservation checked_net_limiting_extent
    by (auto simp: shape)
qed

end
