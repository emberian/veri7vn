theory Reaction_Units
  imports NetStoichiometry Mass_Units
begin

text \<open>Every supplied inventory and requested result retains its unit. The
reader binds species and unit names; this kernel converts to moles before the
net-species checker and converts only its exact result to the requested unit.\<close>

datatype reaction_unit = ReactionMol | ReactionMillimol | ReactionMicromol |
  ReactionMass mass_unit

fun units_per_mole :: "counts \<Rightarrow> reaction_unit \<Rightarrow> rat" where
  "units_per_mole cs ReactionMol = 1"
| "units_per_mole cs ReactionMillimol = 1000"
| "units_per_mole cs ReactionMicromol = 1000000"
| "units_per_mole cs (ReactionMass u) = mass_total cs / grams_per_unit u"

lemma units_per_mole_positive:
  "0 < mass_total cs \<Longrightarrow> 0 < units_per_mole cs u"
  using grams_per_unit_positive by (cases u) (auto intro: divide_pos_pos)

fun reaction_unit_text where
  "reaction_unit_text ReactionMol = STR ''mol''"
| "reaction_unit_text ReactionMillimol = STR ''mmol''"
| "reaction_unit_text ReactionMicromol = STR ''micromoles''"
| "reaction_unit_text (ReactionMass u) = mass_unit_text u"

datatype reaction_amount = ReactionAmount string rat reaction_unit
fun amount_name where "amount_name (ReactionAmount f q u) = f"

definition unit_scale :: "string \<Rightarrow> reaction_unit \<Rightarrow> rat option" where
  "unit_scale f u = (case parse_formula f of FOk cs \<Rightarrow>
     if 0 < mass_total cs then Some (units_per_mole cs u) else None
   | _ \<Rightarrow> None)"

theorem unit_scale_value:
  "unit_scale f u = Some scale \<Longrightarrow>
    0 < scale \<and> (\<exists>cs. parse_formula f = FOk cs \<and>
      0 < mass_total cs \<and> scale = units_per_mole cs u)"
  using units_per_mole_positive
  by (auto simp: unit_scale_def split: fparse.splits if_splits)

fun amount_to_moles :: "reaction_amount \<Rightarrow> rat option" where
  "amount_to_moles (ReactionAmount f q u) =
    (if 0 \<le> q then (case unit_scale f u of Some scale \<Rightarrow> Some (q / scale) | None \<Rightarrow> None)
     else None)"

theorem amount_conversion_conserves_quantity:
  "amount_to_moles (ReactionAmount f q u) = Some n \<Longrightarrow>
    0 \<le> q \<and> 0 \<le> n \<and> (\<exists>cs. parse_formula f = FOk cs \<and>
      0 < mass_total cs \<and> n * units_per_mole cs u = q)"
proof -
  assume a: "amount_to_moles (ReactionAmount f q u) = Some n"
  then obtain scale where s: "unit_scale f u = Some scale" and h: "0 \<le> q" "n = q / scale"
    by (auto split: if_splits option.splits)
  obtain cs where cs: "parse_formula f = FOk cs" "0 < mass_total cs"
    "scale = units_per_mole cs u" and positive: "0 < scale"
    using unit_scale_value[OF s] by blast
  have "0 \<le> n" using h positive by (auto intro: divide_nonneg_nonneg)
  moreover have "n * units_per_mole cs u = q" using h positive cs by simp
  ultimately show ?thesis using h cs by blast
qed

corollary mass_inventory_conserves_grams:
  "amount_to_moles (ReactionAmount f q (ReactionMass u)) = Some n \<Longrightarrow>
    \<exists>cs. parse_formula f = FOk cs \<and> 0 \<le> q \<and> 0 \<le> n \<and>
      0 < mass_total cs \<and> n * mass_total cs = q * grams_per_unit u"
proof -
  assume a: "amount_to_moles (ReactionAmount f q (ReactionMass u)) = Some n"
  obtain cs where cs: "parse_formula f = FOk cs" "0 < mass_total cs"
    and h: "0 \<le> q" "0 \<le> n" "n * (mass_total cs / grams_per_unit u) = q"
    using amount_conversion_conserves_quantity[OF a] by auto
  have "n * mass_total cs = q * grams_per_unit u"
    using h(3) grams_per_unit_positive[of u] by (simp add: field_simps)
  then show ?thesis using cs h by blast
qed

fun normalize_inventory :: "reaction_amount list \<Rightarrow> (string \<times> rat) list option" where
  "normalize_inventory [] = Some []"
| "normalize_inventory (a # rest) = (case (amount_to_moles a, normalize_inventory rest) of
     (Some n, Some ns) \<Rightarrow> Some ((amount_name a,n) # ns) | _ \<Rightarrow> None)"

theorem normalized_inventory_names:
  "normalize_inventory amounts = Some ns \<Longrightarrow> map fst ns = map amount_name amounts"
  by (induction amounts arbitrary: ns) (auto split: option.splits)

theorem normalized_inventory_quantities:
  "normalize_inventory amounts = Some ns \<Longrightarrow> a \<in> set amounts \<Longrightarrow>
    \<exists>n. (amount_name a,n) \<in> set ns \<and> amount_to_moles a = Some n"
  by (induction amounts arbitrary: ns) (auto split: option.splits)

datatype measured_net_query = MeasuredNetYield string reaction_unit |
  MeasuredNetFinal string reaction_unit
fun base_net_query where
  "base_net_query (MeasuredNetYield f u) = NetYieldMoles f"
| "base_net_query (MeasuredNetFinal f u) = NetFinalMoles f"
fun measured_query_unit where
  "measured_query_unit (MeasuredNetYield f u) = u"
| "measured_query_unit (MeasuredNetFinal f u) = u"
fun measured_net_kind where
  "measured_net_kind (MeasuredNetYield f (ReactionMass u)) = net_query_kind (NetYieldGrams f)"
| "measured_net_kind (MeasuredNetFinal f (ReactionMass u)) = net_query_kind (NetFinalGrams f)"
| "measured_net_kind query = net_query_kind (base_net_query query)"

definition measured_net_reply :: "(string \<times> nat) list \<Rightarrow> (string \<times> nat) list \<Rightarrow>
    reaction_amount list \<Rightarrow> measured_net_query \<Rightarrow> reply" where
  "measured_net_reply lhs rhs amounts query =
   (let refusal = Reply False (STR ''impossible'')
      (STR ''The reaction needs balanced positive coefficients, unambiguous species, nonnegative inventories, and compatible amount units.'') None
    in case normalize_inventory amounts of None \<Rightarrow> refusal | Some ns \<Rightarrow>
      (case checked_net_reaction lhs rhs ns of None \<Rightarrow> refusal | Some result \<Rightarrow>
        (case (net_value result (base_net_query query),
           unit_scale (net_query_name (base_net_query query)) (measured_query_unit query)) of
         (Some n,Some scale) \<Rightarrow> Reply True (measured_net_kind query)
           (net_query_text (base_net_query query) + nshow (NR (n * scale)) + STR '' '' +
            reaction_unit_text (measured_query_unit query) +
            STR '' under complete conversion of the net limiting reactant.'')
           (Some (nshow (NR (n * scale))))
         | _ \<Rightarrow> refusal)))"

theorem measured_net_answered_value:
  "answered (measured_net_reply lhs rhs amounts query) \<Longrightarrow>
    \<exists>ns result n scale. normalize_inventory amounts = Some ns \<and>
      checked_net_reaction lhs rhs ns = Some result \<and>
      net_value result (base_net_query query) = Some n \<and>
      unit_scale (net_query_name (base_net_query query)) (measured_query_unit query) = Some scale \<and>
      0 < scale \<and>
      stated (measured_net_reply lhs rhs amounts query) = Some (nshow (NR (n * scale))) \<and>
      (n * scale) / scale = n"
proof -
  assume ans: "answered (measured_net_reply lhs rhs amounts query)"
  obtain ns result n scale where ns: "normalize_inventory amounts = Some ns"
    and result: "checked_net_reaction lhs rhs ns = Some result"
    and n: "net_value result (base_net_query query) = Some n"
    and scale: "unit_scale (net_query_name (base_net_query query)) (measured_query_unit query) = Some scale"
    using ans by (auto simp: measured_net_reply_def Let_def split: option.splits)
  have positive: "0 < scale" using unit_scale_value[OF scale] by blast
  have stated: "stated (measured_net_reply lhs rhs amounts query) = Some (nshow (NR (n * scale)))"
    using ns result n scale by (simp add: measured_net_reply_def Let_def)
  have inverse: "(n * scale) / scale = n" using positive by simp
  show ?thesis using ns result n scale positive stated inverse by blast
qed

theorem measured_net_conservation_certificate:
  "answered (measured_net_reply lhs rhs amounts query) \<Longrightarrow>
    \<exists>ns ls rs ss x. normalize_inventory amounts = Some ns \<and>
      checked_net_reaction lhs rhs ns = Some (NetResult ls rs ss x) \<and>
      (\<forall>e. side_atoms e ls = side_atoms e rs \<and>
        inventory_atoms e ss x = initial_inventory_atoms e ss) \<and>
      feasible_extent (net_feed ss) x \<and>
      (\<forall>y. feasible_extent (net_feed ss) y \<longrightarrow> y \<le> x) \<and>
      0 \<in> set (reaction_leftovers (net_feed ss)) \<and>
      (\<forall>s \<in> set ss. 0 \<le> final_amount s x)"
proof -
  assume ans: "answered (measured_net_reply lhs rhs amounts query)"
  obtain ns result where n: "normalize_inventory amounts = Some ns"
    and c: "checked_net_reaction lhs rhs ns = Some result"
    using measured_net_answered_value[OF ans] by blast
  obtain ls rs ss x where shape: "result = NetResult ls rs ss x" by (cases result) auto
  show ?thesis using n c checked_net_conservation checked_net_inventory_conservation checked_net_limiting_extent
    by (auto simp: shape)
qed

end
