theory Chemistry_Export
  imports Chemistry Decay
begin

datatype request = RC creq | RD dreq

fun reply_of :: "request \<Rightarrow> reply" where
  "reply_of (RC r) = reply_c r"
| "reply_of (RD r) = reply_d r"

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
    (\<not> answers (RC (MolesInSol 0 1)))]"

definition self_test :: "unit \<Rightarrow> bool" where
  "self_test u = list_all id (self_checks u)"

export_code reply_of answered reply_kind response stated answers mk_rat chars_of self_test
  self_checks fclass elem_names is_symbol iso_order
  integer_of_int nat_of_integer int_of_integer
  RC RD MolarMass GramsToMoles MolesToGrams Percent Property NoSuchElement WvMass Dilution
  Molarity MassNeeded NeedFormula PercentComp DilutedConc WaterToAdd MolesInSol MolarityMoles
  P_atomic_mass P_atomic_number P_electronegativity P_melting_point P_boiling_point P_density
  P_electron_configuration P_ionization_energy P_standard_state P_group_block
  P_year_discovered P_symbol
  TimeToFraction HalfLives Remaining RemFraction HL_stated HL_iso
  TU_year TU_day TU_hour TU_minute TU_second
  in SML module_name Chemistry file_prefix chemistry

ML \<open>
  val theorems = [@{thm round_sig_sound}, @{thm round_tie_up}, @{thm to_dec_sound}, @{thm enclose_sound},
    @{thm ndec_sound}, @{thm fixed_val_error},
    @{thm mass_total_add_count}, @{thm mass_merge}, @{thm molar_mass_value}, @{thm grams_to_moles_value},
    @{thm moles_to_grams_value}, @{thm grams_moles_roundtrip}, @{thm grams_to_moles_declines},
    @{thm percent_value}, @{thm percent_entries_sum}, @{thm property_value}, @{thm property_declines},
    @{thm fahrenheit_celsius}, @{thm absolute_zero_fahrenheit}, @{thm wv_value}, @{thm dilution_value},
    @{thm molarity_value}, @{thm mass_needed_value}, @{thm mass_molarity_inverse}, @{thm lab_bad_formula},
    @{thm percent_comp_value}, @{thm percent_comp_entry}, @{thm diluted_conc_value}, @{thm diluted_conc_declines},
    @{thm water_add_value}, @{thm water_add_declines}, @{thm dilution_solute_conserved}, @{thm moles_sol_value},
    @{thm molarity_moles_value}, @{thm molarity_moles_inverse}, @{thm moles_sol_declines}, @{thm molarity_moles_declines},
    @{thm reply_c_answered}, @{thm reply_c_exact_stated}, @{thm reply_c_withheld},
    @{thm decay_real_zero}, @{thm decay_halves}, @{thm decay_real_nat}, @{thm time_real_inverse},
    @{thm time_real_half}, @{thm factor_nv_sound}, @{thm halv_nv_sound}, @{thm half_lives_value},
    @{thm remaining_amount_value}, @{thm remaining_fraction_value}, @{thm remaining_whole_half_lives},
    @{thm time_to_fraction_value}, @{thm time_to_fraction_half}, @{thm decay_declines},
    @{thm decay_declines_fraction}, @{thm wf_add}, @{thm wf_merge}, @{thm dilution_stock_le_final}, @{thm remaining_halflives_agree}, @{thm reply_d_withheld}, @{thm reply_d_answered}]
    @ [@{thm ge_dec_true}, @{thm ge_dec_false}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("chemistry theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} () then () else
    error ("chemistry self test failed at " ^ String.concatWith "," (List.mapPartial I
      (map_index (fn (i, b) => if b then NONE else SOME (string_of_int i)) (@{code self_checks} ()))));
  val _ = writeln ("VERI7VN_CHEMISTRY PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
