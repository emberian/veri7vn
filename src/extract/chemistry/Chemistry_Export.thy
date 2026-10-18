theory Chemistry_Export
  imports "stoich/NetStoichiometry" "stoich/Mass_Units" "stoich/Solutions" "stoich/Reaction_Units"
begin

datatype request = RC creq | RD dreq | RM measured_request | RL solution_request solution_prefix
  | RS "(string \<times> nat) list" "(string \<times> nat) list" "rat list" stoich_query
  | RNS "(string \<times> nat) list" "(string \<times> nat) list" "(string \<times> rat) list" net_query
  | RNU "(string \<times> nat) list" "(string \<times> nat) list" "reaction_amount list" measured_net_query

text \<open>The arithmetic functions are total algebraic maps. The public typed
answer interface additionally checks the physical input domain. In particular a
negative amount or elapsed time must not become an affirmative physical answer,
even if an untrusted reader supplies that request directly.\<close>
fun physical_creq :: "creq \<Rightarrow> bool" where
  "physical_creq (GramsToMoles q f) = (0 \<le> q)"
| "physical_creq (MolesToGrams q f) = (0 \<le> q)"
| "physical_creq (WvMass c v) = (0 \<le> c \<and> 0 \<le> v)"
| "physical_creq (Dilution a b v) = (0 \<le> a \<and> 0 \<le> b \<and> 0 \<le> v)"
| "physical_creq (Molarity f q v) = (0 \<le> q \<and> 0 \<le> v)"
| "physical_creq (MassNeeded f c v) = (0 \<le> c \<and> 0 \<le> v)"
| "physical_creq (DilutedConc c a b) = (0 \<le> c \<and> 0 \<le> a \<and> 0 \<le> b)"
| "physical_creq (WaterToAdd a b) = (0 \<le> a \<and> 0 \<le> b)"
| "physical_creq (MolesInSol c v) = (0 \<le> c \<and> 0 \<le> v)"
| "physical_creq (MolarityMoles n v) = (0 \<le> n \<and> 0 \<le> v)"
| "physical_creq (MolarMass f) = (case parse_formula f of FOk cs \<Rightarrow> 0 < mass_total cs | _ \<Rightarrow> True)"
| "physical_creq _ = True"

fun physical_elapsed :: "(rat \<times> tu) option \<Rightarrow> bool" where
  "physical_elapsed None = True"
| "physical_elapsed (Some (t, u)) = (0 \<le> t)"

fun physical_dreq :: "dreq \<Rightarrow> bool" where
  "physical_dreq (HalfLives h el) = physical_elapsed el"
| "physical_dreq (Remaining h el am) =
     (physical_elapsed el \<and> (case am of None \<Rightarrow> True | Some (a, u) \<Rightarrow> 0 \<le> a))"
| "physical_dreq (RemFraction h el pct) = physical_elapsed el"
| "physical_dreq (TimeToFraction h f u) = True"

fun physical_request :: "request \<Rightarrow> bool" where
  "physical_request (RC r) = physical_creq r"
| "physical_request (RD r) = physical_dreq r"
| "physical_request (RS lhs rhs amounts query) = True"
| "physical_request (RNS lhs rhs amounts query) = True"
| "physical_request (RNU lhs rhs amounts query) = True"
| "physical_request (RM r) = True"
| "physical_request (RL r u) = True"

fun raw_reply :: "request \<Rightarrow> reply" where
  "raw_reply (RC r) = reply_c r"
| "raw_reply (RD r) = reply_d r"
| "raw_reply (RS lhs rhs amounts query) = reply_s lhs rhs amounts query"
| "raw_reply (RNS lhs rhs amounts query) = reply_net lhs rhs amounts query"
| "raw_reply (RNU lhs rhs amounts query) = measured_net_reply lhs rhs amounts query"
| "raw_reply (RM r) = measured_reply r"
| "raw_reply (RL r u) = solution_reply r u"

fun invalid_request_text :: "request \<Rightarrow> String.literal" where
  "invalid_request_text (RC (MolarMass f)) = STR ''A molecular formula must have positive mass; zero atoms do not define a molecule.''"
| "invalid_request_text _ = STR ''Amounts, concentrations, volumes and elapsed times must be nonnegative.''"

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (if physical_request r then raw_reply r
     else Reply False (STR ''impossible'') (invalid_request_text r) None)"

theorem reply_of_measured_net_value:
  "answered (reply_of (RNU lhs rhs amounts query)) \<Longrightarrow>
    \<exists>ns result n scale. normalize_inventory amounts = Some ns \<and>
      checked_net_reaction lhs rhs ns = Some result \<and>
      net_value result (base_net_query query) = Some n \<and>
      unit_scale (net_query_name (base_net_query query)) (measured_query_unit query) = Some scale \<and>
      0 < scale \<and>
      stated (reply_of (RNU lhs rhs amounts query)) = Some (nshow (NR (n * scale)))"
  using measured_net_answered_value[of lhs rhs amounts query] by (auto simp: reply_of_def)

theorem reply_of_solution_value:
  "answered (reply_of (RL r u)) \<Longrightarrow>
    \<exists>v. solution_value r = Some v \<and>
      stated (reply_of (RL r u)) = Some (Chemistry.g4 (v / solution_scale u)) \<and>
      (v / solution_scale u) * solution_scale u = v"
  using solution_reply_value[of r u] by (simp add: reply_of_def)

theorem reply_of_physical:
  "answered (reply_of r) \<Longrightarrow> physical_request r"
  by (auto simp: reply_of_def split: if_splits)

theorem reply_of_valid_agrees:
  "physical_request r \<Longrightarrow> reply_of r = raw_reply r"
  by (simp add: reply_of_def)

theorem reply_of_invalid_declines:
  "\<not> physical_request r \<Longrightarrow>
   \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = STR ''impossible''"
  by (simp add: reply_of_def)

theorem reply_of_grams_nonnegative:
  "answered (reply_of (RC (GramsToMoles q f))) \<Longrightarrow> 0 \<le> q"
  using reply_of_physical[of "RC (GramsToMoles q f)"] by simp

theorem reply_of_lab_nonnegative:
  "answered (reply_of (RC (MassNeeded f c v))) \<Longrightarrow> 0 \<le> c \<and> 0 \<le> v"
  using reply_of_physical[of "RC (MassNeeded f c v)"] by simp

theorem reply_of_remaining_nonnegative:
  "answered (reply_of (RD (Remaining h (Some (t, u)) (Some (a, au))))) \<Longrightarrow>
   0 \<le> t \<and> 0 \<le> a"
  using reply_of_physical[of "RD (Remaining h (Some (t, u)) (Some (a, au)))"] by simp

theorem reply_of_molar_mass_positive:
  assumes "answered (reply_of (RC (MolarMass f)))"
  shows "\<exists>cs. parse_formula f = FOk cs \<and> 0 < mass_total cs"
  using assms reply_of_physical[OF assms]
  by (cases "parse_formula f") (auto simp: reply_of_def reply_c_def with_mass_def)

theorem reply_of_reaction_certificate:
  "answered (reply_of (RS lhs rhs amounts query)) \<Longrightarrow>
     \<exists>ls rs fs x q. checked_reaction lhs rhs amounts = Some (ReactionResult ls rs fs x) \<and>
       stoich_value (ReactionResult ls rs fs x) query = Some q \<and>
       (\<forall>e. side_atoms e ls = side_atoms e rs) \<and>
       feasible_extent fs x \<and> (\<forall>y. feasible_extent fs y \<longrightarrow> y \<le> x) \<and>
       0 \<in> set (reaction_leftovers fs)"
  using reply_s_answered_certificate[of lhs rhs amounts query]
  by (simp add: reply_of_def)

theorem reply_of_net_reaction_certificate:
  "answered (reply_of (RNS lhs rhs amounts query)) \<Longrightarrow>
    \<exists>ls rs ss x q. checked_net_reaction lhs rhs amounts = Some (NetResult ls rs ss x) \<and>
      net_value (NetResult ls rs ss x) query = Some q \<and>
      (\<forall>e. side_atoms e ls = side_atoms e rs \<and>
        side_atoms e (net_left_side ss) = side_atoms e (net_right_side ss) \<and>
        inventory_atoms e ss x = initial_inventory_atoms e ss) \<and>
      feasible_extent (net_feed ss) x \<and>
      (\<forall>y. feasible_extent (net_feed ss) y \<longrightarrow> y \<le> x) \<and>
      0 \<in> set (reaction_leftovers (net_feed ss)) \<and>
      (\<forall>s \<in> set ss. 0 \<le> final_amount s x)"
  using reply_net_answered_certificate[of lhs rhs amounts query]
  by (simp add: reply_of_def)

theorem reply_of_measured_mass:
  "answered (reply_of (RM (MeasuredMass n f u))) \<Longrightarrow>
    \<exists>cs. parse_formula f = FOk cs \<and> 0 \<le> n \<and> 0 < mass_total cs \<and>
      stated (reply_of (RM (MeasuredMass n f u))) = Some (g4 (n * mass_total cs / grams_per_unit u))"
  using measured_mass_value[of n f u] by (simp add: reply_of_def)

text \<open>Constructors the untrusted SML recognizer uses to build requests from
numerals and text it read off the question.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition chars_of :: "integer list \<Rightarrow> string" where
  "chars_of = map char_of_integer"

text \<open>Whether the kernel answers a request; the organs' fall-through
(a percent whose element is not in the formula) and the narrowing consult it.\<close>
definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

text \<open>0: a readable formula; 1: a symbol that is no element; 2: unreadable.\<close>
definition fclass :: "string \<Rightarrow> integer" where
  "fclass f = (case parse_formula f of FOk _ \<Rightarrow> 0 | FUnknown _ \<Rightarrow> 1 | FBad \<Rightarrow> 2)"

definition elem_names :: "(String.literal \<times> String.literal) list" where
  "elem_names = map (\<lambda>e. (plow e, sl (psym e))) ptable"

definition is_symbol :: "String.literal \<Rightarrow> bool" where
  "is_symbol s = (\<exists>e \<in> set ptable. sl (psym e) = s)"

text \<open>B-chemistry step 4: the self test is a function of unit. As a plain constant the code
generator makes it a top-level SML value, so the binary ran every check (decay enclosures
included) before it read its first request: 58 ms of cold start for nothing.\<close>
definition self_checks :: "unit \<Rightarrow> bool list" where
  "self_checks _ = [
    (stated (reply_of (RM (MeasuredMoles (18015/1000000) MassKilogram ''H2O''))) = Some (STR ''1'')),
    (stated (reply_of (RM (MeasuredMass 2 ''H2O'' MassKilogram))) = Some (STR ''0.03603'')),
    (stated (reply_of (RM (MeasuredRemaining (HL_stated 10 TU_day) (Some (10,TU_day)) 1 MassKilogram MassGram))) = Some (STR ''500'')),
    (stated (reply_of (RM (MeasuredMolarMass ''H2O'' MassKilogram))) = Some (STR ''0.018015'')),
    (stated (reply_of (RM (MeasuredSolutionMass ''NaCl'' 1 (1/2) MassKilogram))) = Some (STR ''0.02922'')),
    (stated (reply_of (RM (MeasuredMolarity ''NaCl'' (2922/100000) MassKilogram (1/2)))) = Some (STR ''1'')),
    (mass_fraction 1000 MassMilligram 500 MassMicrogram = Some (1/2000)),
    (stated (reply_of (RM (MeasuredDecayTime (HL_stated 10 TU_day) 1000 MassMilligram 500 MassMicrogram (Some TU_day)))) = Some (STR ''109.7'')),
    (\<not> answers (RM (MeasuredMass 2 ''H0'' MassGram))),
    (\<not> answers (RM (MeasuredRemaining (HL_stated 10 TU_day) (Some (-1,TU_day)) 1 MassGram MassGram))),

    (ckernel (MolarMass ''H2O'') = CExact CK_molar_mass (18015 / 1000)),
    (ckernel (MolarMass ''Ca(OH)2'') = CExact CK_molar_mass (74094 / 1000)),
    ((case parse_formula ''CuSO4.5H2O'' of FOk _ \<Rightarrow> True | _ \<Rightarrow> False)),
    (parse_formula ''XyO2'' = FUnknown ''Xy''),
    (parse_formula ''Ca(OH'' = FBad),
    (parse_formula ''NaXq'' = FUnknown ''Xq''),
    (fclass ''NaCl'' = 0 \<and> fclass ''XyO2'' = 1 \<and> fclass ''water'' = 2),
    (response (reply_of (RC (MolarMass ''H2O''))) = STR ''The molar mass of H2O is 18.015 g/mol (2 x H + 1 x O, PubChem atomic masses).''),
    (stated (reply_of (RC (GramsToMoles 50 ''H2O''))) = Some (STR ''2.775'')),
    (stated (reply_of (RC (MolesToGrams 3 ''H2O''))) = Some (STR ''54.05'')),
    (response (reply_of (RC (Percent ''O'' ''H2O''))) = STR ''Oxygen is 88.81% of H2O by mass (1 x 15.999 in 18.015 g/mol).''),
    (response (reply_of (RC (Property P_melting_point ''H'' False))) = STR ''The melting point of Hydrogen (H) is 13.81 K (-259.34 C), per PubChem.''),
    (response (reply_of (RC (Property P_melting_point ''H'' True))) = STR ''The melting point of Hydrogen (H) is -434.81 F (13.81 K, -259.34 C), per PubChem.''),
    (\<not> answers (RC (Property P_electronegativity ''He'' False))),
    (ckernel (MassNeeded ''KCl'' 1 (50 / 1000)) = CExact CK_mass_needed (3727415 / 1000000)),
    (ckernel (Dilution 10 (1 / 2) (50 / 1000)) = CExact CK_dilution (5 / 2)),
    (stated (reply_of (RC (WvMass 2 50))) = Some (STR ''1'')),
    (dkernel (Remaining (HL_iso I_c14) (Some (5730, TU_year)) (Some (800, STR ''g''))) = DVal D_remaining_amount (NR 400)),
    (response (reply_of (RD (Remaining (HL_stated 12 TU_day) (Some (24, TU_day)) (Some (40, STR ''mg''))))) = STR ''About 10 mg remains after 24 days (N = N0*(1/2)^(t/T) = 40 x 0.25, a half-life of 12 days).''),
    (stated (reply_of (RD (RemFraction (HL_stated 12 TU_day) (Some (10, TU_day)) False))) = Some (STR ''0.5612'')),
    (stated (reply_of (RD (HalfLives (HL_iso I_rn222) (Some (17.21, TU_day))))) = Some (STR ''4.501'')),
    (stated (reply_of (RD (TimeToFraction (HL_iso I_h3) (Some (1 / 2)) (Some TU_year)))) = Some (STR ''12.32'')),
    (stated (reply_of (RD (TimeToFraction (HL_iso I_ra226) (Some (5 / 100)) (Some TU_year)))) = Some (STR ''6915'')),
    (\<not> answers (RD (Remaining (HL_iso I_c14) (Some (1000, TU_year)) None))),
    (response (reply_of (RC (PercentComp ''H2O''))) = STR ''Percent composition of H2O by mass: H 11.19%, O 88.81% (total 18.015 g/mol, PubChem atomic masses).''),
    (stated (reply_of (RC (PercentComp ''H2O''))) = Some (dq + STR ''H 11.19%, O 88.81%'' + dq)),
    (\<not> answers (RC (PercentComp ''XyO2''))),
    (stated (reply_of (RC (DilutedConc 2 (10 / 1000) (100 / 1000)))) = Some (STR ''0.2'')),
    (stated (reply_of (RC (WaterToAdd (10 / 1000) (100 / 1000)))) = Some (STR ''90'')),
    (\<not> answers (RC (WaterToAdd (100 / 1000) (10 / 1000)))),
    (stated (reply_of (RC (MolesInSol (1 / 2) (250 / 1000)))) = Some (STR ''0.125'')),
    (stated (reply_of (RC (MolarityMoles (1 / 5) (500 / 1000)))) = Some (STR ''0.4'')),
    (stated (reply_of (RC (MolesInSol 0 1))) = Some (STR ''0'')),
    (stated (reply_of (RC (MolesInSol 2 0))) = Some (STR ''0'')),
    (stated (reply_of (RC (MolarityMoles 0 1))) = Some (STR ''0'')),
    (stated (reply_of (RC (DilutedConc 2 0 1))) = Some (STR ''0'')),
    (stated (reply_of (RC (WaterToAdd 0 1))) = Some (STR ''1000'')),
    (\<not> answers (RC (MolarityMoles 0 0))),
    (\<not> answers (RC (DilutedConc 2 0 0))),
    (stated (reply_of (RNU [(''H2'',2),(''O2'',1)] [(''H2O'',2)]
      [ReactionAmount ''H2'' 4.032 (ReactionMass MassGram), ReactionAmount ''O2'' 31.998 (ReactionMass MassGram)]
      (MeasuredNetYield ''H2O'' (ReactionMass MassKilogram)))) = Some (STR ''0.03603'')),
    (\<not> answers (RNU [(''H2'',2),(''O2'',1)] [(''H2O'',2)]
      [ReactionAmount ''H2'' (-1) (ReactionMass MassGram), ReactionAmount ''O2'' 1 ReactionMol]
      (MeasuredNetYield ''H2O'' ReactionMol))),
    (stated (reply_of (RL (MassSolutionMolarity ''H2O'' 18.015 MassMilligram 1) SolMilli)) = Some (STR ''1'')),
    (stated (reply_of (RL (StockVolume 0 0 0) SolMilli)) = Some (STR ''0'')),
    (\<not> answers (RL (MassSolutionMolarity ''H2O'' 1 MassGram 0) SolMilli)),
    (reply_kind (reply_of (RL (SoluteAmount 1 1) SolBase)) = STR ''moles_in_solution''),
    (reply_kind (reply_of (RL (AddSolvent 1 0 1) SolMilli)) = STR ''water_to_add''),
    (reply_kind (reply_of (RL (SolutionMolarity 1 1) SolBase)) = STR ''molarity_from_moles''),
    (stated (reply_of (RL (StockVolume 2 1 (1/10)) SolMilli)) = Some (STR ''50'')),
    (\<not> answers (RL (StockVolume 1 2 (1/10)) SolMilli)),
    (\<not> answers (RL (StockVolume 0 0 (1/10)) SolMilli)),
    (stated (reply_of (RL (AddSolvent 1 (1/20) (1/10)) SolBase)) = Some (STR ''0.05'')),
    (\<not> answers (RL (AddSolvent (-1) (1/20) (1/10)) SolBase)),
    (stated (reply_of (RL (SoluteAmount 1 (1/2)) SolMilli)) = Some (STR ''500'')),
    (stated (reply_of (RL (SolutionMolarity 1 (1/2)) SolMilli)) = Some (STR ''2000'')),
    (stated (reply_of (RL (DilutedMolarity 1 (1/20) (1/10)) SolMilli)) = Some (STR ''500'')),
    (\<not> answers (RC (GramsToMoles (-1) ''H2O''))),
    (\<not> answers (RC (MassNeeded ''NaCl'' (-1) 1))),
    (\<not> answers (RC (MolarMass ''H0''))),
    (\<not> answers (RD (Remaining (HL_iso I_c14) (Some (-1, TU_year)) (Some (1, STR ''g''))))),
    (\<not> answers (RD (Remaining (HL_iso I_c14) (Some (1, TU_year)) (Some (-1, STR ''g''))))),
    (stated (reply_of (RS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [4, 1] (YieldMoles 0))) = Some (STR ''2'')),
    (stated (reply_of (RS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [4, 1] (YieldGrams 0))) = Some (STR ''36.03'')),
    (stated (reply_of (RS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [4, 1] (LeftMoles 0))) = Some (STR ''2'')),
    (stated (reply_of (RS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [0, 1] (YieldMoles 0))) = Some (STR ''0'')),
    (\<not> answers (RS [(''H2'', 1), (''O2'', 1)] [(''H2O'', 1)] [4, 1] (YieldMoles 0))),
    (\<not> answers (RS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [4] (YieldMoles 0))),
    (\<not> answers (RS [(''H2'', 2), (''O2'', 1), (''Pt'', 1)] [(''H2O'', 2), (''Pt'', 1)] [4, 1, 1/10] (YieldMoles 0))),
    (\<not> answers (RS [(''H2O'', 2)] [(''OH2'', 2)] [4] (YieldMoles 0))),
    (stated (reply_of (RNS [(''H2'', 2), (''O2'', 1), (''Pt'', 1)] [(''H2O'', 2), (''Pt'', 1)] [(''H2'', 4), (''O2'', 1), (''Pt'', 1/10)] (NetYieldMoles ''H2O''))) = Some (STR ''2'')),
    (stated (reply_of (RNS [(''H2'', 2), (''O2'', 1), (''Pt'', 1)] [(''H2O'', 2), (''Pt'', 1)] [(''H2'', 4), (''O2'', 1), (''Pt'', 1/10)] (NetFinalMoles ''Pt''))) = Some (STR ''0.1'')),
    (stated (reply_of (RNS [(''H2'', 1), (''H2'', 1), (''O2'', 1)] [(''H2O'', 2)] [(''H2'', 4), (''O2'', 1)] (NetYieldMoles ''H2O''))) = Some (STR ''2'')),
    (stated (reply_of (RNS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [(''H2'', 4), (''O2'', 1), (''H2O'', 2)] (NetFinalMoles ''H2O''))) = Some (STR ''4'')),
    (\<not> answers (RNS [(''CH3CH2OH'', 1)] [(''CH3OCH3'', 1)] [(''CH3CH2OH'', 1)] (NetYieldMoles ''CH3OCH3''))),
    (\<not> answers (RNS [(''H2'', 2), (''O2'', 1)] [(''H2O'', 2)] [(''H2'', 4), (''H2'', 1), (''O2'', 1)] (NetYieldMoles ''H2O'')))]"

definition self_test :: "unit \<Rightarrow> bool" where
  "self_test u = list_all id (self_checks u)"

export_code reply_of answered reply_kind response stated answers mk_rat chars_of self_test
  self_checks fclass elem_names is_symbol iso_order
  integer_of_int nat_of_integer int_of_integer
  RNU ReactionAmount ReactionMol ReactionMillimol ReactionMicromol ReactionMass MeasuredNetYield MeasuredNetFinal
  RL StockVolume AddSolvent SoluteAmount SolutionMolarity DilutedMolarity MassSolutionMolarity SolBase SolMilli SolMicro
  RM MeasuredMoles MeasuredMass MeasuredRemaining MeasuredDecayTime
  MeasuredMolarMass MeasuredSolutionMass MeasuredMolarity
  MassGram MassMilligram MassKilogram MassMicrogram
  RC RD MolarMass GramsToMoles MolesToGrams Percent Property NoSuchElement WvMass Dilution
  RS YieldMoles YieldGrams LeftMoles LeftGrams
  RNS NetYieldMoles NetYieldGrams NetFinalMoles NetFinalGrams
  Molarity MassNeeded NeedFormula PercentComp DilutedConc WaterToAdd MolesInSol MolarityMoles
  P_atomic_mass P_atomic_number P_electronegativity P_melting_point P_boiling_point P_density
  P_electron_configuration P_ionization_energy P_standard_state P_group_block
  P_year_discovered P_symbol
  TimeToFraction HalfLives Remaining RemFraction HL_stated HL_iso
  TU_year TU_day TU_hour TU_minute TU_second
  in SML module_name Chemistry file_prefix chemistry

ML \<open>
  val theorems = [@{thm reply_of_measured_net_value}, @{thm units_per_mole_positive}, @{thm unit_scale_value}, @{thm amount_conversion_conserves_quantity}, @{thm mass_inventory_conserves_grams}, @{thm normalized_inventory_names}, @{thm normalized_inventory_quantities}, @{thm measured_net_answered_value}, @{thm measured_net_conservation_certificate}, @{thm mass_solution_conservation}, @{thm zero_stock_zero_final}, @{thm reply_of_solution_value}, @{thm solution_reply_value}, @{thm directed_stock_conserves_solute}, @{thm directed_stock_unique}, @{thm solvent_volume_conservation}, @{thm solution_amount_conservation}, @{thm solution_molarity_conservation}, @{thm solution_dilution_conservation}, @{thm measured_molar_mass_value}, @{thm measured_solution_mass_value}, @{thm measured_molarity_value}, @{thm measured_moles_value}, @{thm grams_per_unit_positive}, @{thm convert_mass_conserves_grams}, @{thm convert_mass_composes}, @{thm convert_mass_nonnegative}, @{thm mass_fraction_value}, @{thm measured_mass_value}, @{thm measured_remaining_kernel_value}, @{thm measured_remaining_answered}, @{thm measured_decay_time_answered}, @{thm reply_of_measured_mass}, @{thm net_inventory_atom_conservation}, @{thm checked_net_inventory_conservation}, @{thm species_coefficient_append}, @{thm species_coefficient_other}, @{thm species_coefficient_same}, @{thm prepared_species_bindings}, @{thm prepared_species_names}, @{thm spectator_zero_net}, @{thm spectator_excluded_from_consumers}, @{thm spectator_does_not_limit}, @{thm spectator_inventory_unchanged}, @{thm net_inventory_nonnegative}, @{thm checked_net_certificate}, @{thm checked_net_conservation}, @{thm checked_net_limiting_extent}, @{thm reply_net_answered_certificate}, @{thm reply_of_net_reaction_certificate},
    @{thm balanced_reaction_conserves_every_element}, @{thm parsed_reaction_side_known},
    @{thm reaction_extent_feasible}, @{thm reaction_extent_greatest}, @{thm reaction_extent_exhausts_a_feed},
    @{thm reaction_leftovers_nonnegative}, @{thm reaction_leftovers_contains_zero},
    @{thm checked_reaction_certificate}, @{thm checked_reaction_conservation}, @{thm checked_reaction_bottleneck},
    @{thm reply_s_answered_certificate}, @{thm reaction_yield_value}, @{thm reply_of_reaction_certificate},
    @{thm reply_of_physical}, @{thm reply_of_valid_agrees}, @{thm reply_of_invalid_declines},
    @{thm reply_of_grams_nonnegative}, @{thm reply_of_lab_nonnegative}, @{thm reply_of_remaining_nonnegative},
    @{thm reply_of_molar_mass_positive}, @{thm round_sig_sound}, @{thm round_tie_up}, @{thm to_dec_sound}, @{thm enclose_sound},
    @{thm ndec_sound}, @{thm fixed_val_error},
    @{thm mass_total_add_count}, @{thm mass_merge}, @{thm molar_mass_value}, @{thm grams_to_moles_value},
    @{thm moles_to_grams_value}, @{thm grams_moles_roundtrip}, @{thm grams_to_moles_declines},
    @{thm percent_value}, @{thm percent_entries_sum}, @{thm property_value}, @{thm property_declines},
    @{thm fahrenheit_celsius}, @{thm absolute_zero_fahrenheit}, @{thm wv_value}, @{thm dilution_value},
    @{thm molarity_value}, @{thm mass_needed_value}, @{thm mass_molarity_inverse}, @{thm lab_bad_formula},
    @{thm percent_comp_value}, @{thm percent_comp_entry}, @{thm diluted_conc_value}, @{thm diluted_conc_declines},
    @{thm water_add_value}, @{thm water_add_declines}, @{thm dilution_solute_conserved}, @{thm moles_sol_value},
    @{thm molarity_moles_value}, @{thm molarity_moles_inverse}, @{thm moles_sol_declines}, @{thm molarity_moles_declines},
    @{thm zero_volume_has_zero_moles}, @{thm zero_amount_has_zero_molarity}, @{thm zero_stock_dilutes_to_zero},
    @{thm reply_c_answered}, @{thm reply_c_exact_stated}, @{thm reply_c_withheld},
    @{thm decay_real_zero}, @{thm decay_halves}, @{thm decay_real_nat}, @{thm time_real_inverse},
    @{thm time_real_half}, @{thm factor_nv_sound}, @{thm halv_nv_sound}, @{thm half_lives_value},
    @{thm remaining_amount_value}, @{thm remaining_fraction_value}, @{thm remaining_whole_half_lives},
    @{thm time_to_fraction_value}, @{thm time_to_fraction_half}, @{thm decay_declines},
    @{thm decay_declines_fraction}, @{thm wf_add}, @{thm wf_merge}, @{thm scan_wf}, @{thm parse_parts_wf}, @{thm parse_formula_wf},
    @{thm parse_formula_known_distinct}, @{thm molar_mass_known_distinct}, @{thm percent_comp_known_distinct}, @{thm dilution_stock_le_final}, @{thm remaining_halflives_agree}, @{thm reply_d_withheld}, @{thm reply_d_answered}]
    @ [@{thm ge_dec_true}, @{thm ge_dec_false}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("chemistry theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} () then () else
    error ("chemistry self test failed at " ^ String.concatWith "," (List.mapPartial I
      (map_index (fn (i, b) => if b then NONE else SOME (string_of_int i)) (@{code self_checks} ()))));
  val _ = writeln ("VERI7VN_CHEMISTRY PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
