theory Solutions
  imports "../Chemistry"
begin

text \<open>Directed stock and target roles are retained. Amounts use moles,
volumes use litres and concentrations use mol/L internally. Output prefixes
scale only the requested result, never the domain or the conservation law.\<close>
datatype solution_prefix = SolBase | SolMilli | SolMicro
fun solution_scale :: "solution_prefix \<Rightarrow> rat" where
  "solution_scale SolBase = 1"
| "solution_scale SolMilli = 1 / 1000"
| "solution_scale SolMicro = 1 / 1000000"
lemma solution_scale_positive: "0 < solution_scale u"
  by (cases u) simp_all

datatype solution_request =
    StockVolume rat rat rat
  | AddSolvent rat rat rat
  | SoluteAmount rat rat
  | SolutionMolarity rat rat
  | DilutedMolarity rat rat rat

fun solution_value :: "solution_request \<Rightarrow> rat option" where
  "solution_value (StockVolume stock target final) =
    (if 0 < stock \<and> 0 \<le> target \<and> target \<le> stock \<and> 0 \<le> final
     then Some (target * final / stock) else None)"
| "solution_value (AddSolvent c stock final) =
    (if 0 \<le> c \<and> 0 \<le> stock \<and> stock \<le> final then Some (final - stock) else None)"
| "solution_value (SoluteAmount c v) =
    (if 0 \<le> c \<and> 0 \<le> v then Some (c * v) else None)"
| "solution_value (SolutionMolarity n v) =
    (if 0 \<le> n \<and> 0 < v then Some (n / v) else None)"
| "solution_value (DilutedMolarity c stock final) =
    (if 0 \<le> c \<and> 0 \<le> stock \<and> stock \<le> final \<and> 0 < final
     then Some (c * stock / final) else None)"

fun solution_kind :: "solution_request \<Rightarrow> String.literal" where
  "solution_kind (StockVolume _ _ _) = ckind_name CK_dilution"
| "solution_kind (AddSolvent _ _ _) = ckind_name CK_water_add"
| "solution_kind (SoluteAmount _ _) = ckind_name CK_moles_sol"
| "solution_kind (SolutionMolarity _ _) = ckind_name CK_molarity_mol"
| "solution_kind (DilutedMolarity _ _ _) = ckind_name CK_diluted_conc"

fun solution_dimension :: "solution_request \<Rightarrow> nat" where
  "solution_dimension (StockVolume _ _ _) = 0"
| "solution_dimension (AddSolvent _ _ _) = 0"
| "solution_dimension (SoluteAmount _ _) = 1"
| "solution_dimension _ = 2"

fun solution_unit :: "nat \<Rightarrow> solution_prefix \<Rightarrow> String.literal" where
  "solution_unit d SolBase = (if d = 0 then STR ''L'' else if d = 1 then STR ''mol'' else STR ''M'')"
| "solution_unit d SolMilli = (if d = 0 then STR ''mL'' else if d = 1 then STR ''mmol'' else STR ''mM'')"
| "solution_unit d SolMicro = (if d = 0 then STR ''microlitres'' else if d = 1 then STR ''micromoles'' else STR ''micromolar'')"

fun solution_label :: "solution_request \<Rightarrow> String.literal" where
  "solution_label (StockVolume _ _ _) = STR ''Required stock volume is ''"
| "solution_label (AddSolvent _ _ _) = STR ''Water to add is ''"
| "solution_label (SoluteAmount _ _) = STR ''Amount of solute is ''"
| "solution_label (SolutionMolarity _ _) = STR ''Concentration is ''"
| "solution_label (DilutedMolarity _ _ _) = STR ''Final concentration is ''"

fun solution_refusal :: "solution_request \<Rightarrow> reply" where
  "solution_refusal (StockVolume stock target final) =
    (if stock = 0 \<and> target = 0 \<and> 0 \<le> final then
       Reply False (STR ''underspecified'') (STR ''Zero-concentration stock and target do not determine a unique stock volume.'') None
     else Reply False (STR ''impossible'')
       (STR ''Dilution needs positive stock concentration, a nonnegative target no greater than the stock, and nonnegative final volume.'') None)"
| "solution_refusal _ = Reply False (STR ''impossible'')
    (STR ''Amounts and concentrations must be nonnegative. Dilution cannot reduce volume, and concentration requires a positive final volume.'') None"

definition solution_reply :: "solution_request \<Rightarrow> solution_prefix \<Rightarrow> reply" where
  "solution_reply r u = (case solution_value r of None \<Rightarrow> solution_refusal r
    | Some v \<Rightarrow> Reply True (solution_kind r)
       (solution_label r + g4 (v / solution_scale u) + STR '' '' + solution_unit (solution_dimension r) u + STR ''.'')
       (Some (g4 (v / solution_scale u))))"

lemma solution_refusal_not_answered: "\<not> answered (solution_refusal r)"
  by (cases r) (auto split: if_splits)

theorem solution_reply_value:
  "answered (solution_reply r u) \<Longrightarrow>
    \<exists>v. solution_value r = Some v \<and>
      stated (solution_reply r u) = Some (g4 (v / solution_scale u)) \<and>
      (v / solution_scale u) * solution_scale u = v"
  using solution_scale_positive[of u] solution_refusal_not_answered[of r]
  by (auto simp: solution_reply_def split: option.splits)

theorem directed_stock_conserves_solute:
  assumes "solution_value (StockVolume stock target final) = Some v"
  shows "0 < stock \<and> 0 \<le> target \<and> target \<le> stock \<and> 0 \<le> final \<and>
    0 \<le> v \<and> v \<le> final \<and> stock * v = target * final"
proof -
  have h: "0 < stock" "0 \<le> target" "target \<le> stock" "0 \<le> final"
    and v: "v = target * final / stock" using assms by (auto split: if_splits)
  have p: "0 \<le> v" using h v by (auto intro: divide_nonneg_nonneg mult_nonneg_nonneg)
  have m: "target * final \<le> stock * final" using h by (intro mult_right_mono) auto
  have b: "v \<le> final" using h m v by (simp add: divide_le_eq mult.commute)
  have e: "stock * v = target * final" using h v by (simp add: field_simps)
  show ?thesis using h p b e by blast
qed

theorem directed_stock_unique:
  "solution_value (StockVolume stock target final) = Some v \<Longrightarrow>
    stock * other = target * final \<Longrightarrow> other = v"
proof -
  assume a: "solution_value (StockVolume stock target final) = Some v"
     and b: "stock * other = target * final"
  have h: "0 < stock" "stock * v = target * final"
    using directed_stock_conserves_solute[OF a] by blast+
  have "stock * other = stock * v" using b h by simp
  moreover have "stock \<noteq> 0" using h(1) by linarith
  ultimately show "other = v" by simp
qed

theorem solvent_volume_conservation:
  "solution_value (AddSolvent c stock final) = Some water \<Longrightarrow>
    0 \<le> c \<and> 0 \<le> stock \<and> 0 \<le> water \<and> stock + water = final"
  by (auto split: if_splits)

theorem solution_amount_conservation:
  "solution_value (SoluteAmount c v) = Some n \<Longrightarrow>
    0 \<le> c \<and> 0 \<le> v \<and> n = c * v"
  by (auto split: if_splits)

theorem solution_molarity_conservation:
  "solution_value (SolutionMolarity n v) = Some c \<Longrightarrow>
    0 \<le> n \<and> 0 < v \<and> c * v = n"
  by (auto split: if_splits)

theorem solution_dilution_conservation:
  "solution_value (DilutedMolarity c stock final) = Some result \<Longrightarrow>
    0 \<le> c \<and> 0 \<le> stock \<and> stock \<le> final \<and> 0 < final \<and>
    result * final = c * stock"
  by (auto split: if_splits)

end
