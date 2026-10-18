theory Emoptics_Export
  imports Emoptics
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition mk_nat :: "integer \<Rightarrow> nat" where "mk_nat a = nat_of_integer a"

text \<open>The recognizer reads each lens length with its explicit unit.
All lens-distance requests use centimetres, including mixed-unit inputs.\<close>
definition lens_cm :: "rat \<times> lu \<Rightarrow> rat" where
  "lens_cm l = 100 * amt lu_scale l"
lemma lens_cm_metres: "lens_cm l / 100 = amt lu_scale l"
  by (simp add: lens_cm_def)

definition optical_frequency_input :: "rat \<times> fu \<Rightarrow> optical_input" where
  "optical_frequency_input f = OpticalFrequency (amt fu_scale f)"
definition optical_source_frequency_input :: "rat \<Rightarrow> rat \<times> fu \<Rightarrow> optical_input" where
  "optical_source_frequency_input ns f = OpticalFrequencyIn ns (amt fu_scale f)"
definition optical_wavelength_input :: "rat \<Rightarrow> rat \<times> lu \<Rightarrow> optical_input" where
  "optical_wavelength_input ns l = OpticalWavelength ns (amt lu_scale l)"
definition optical_redundant_input :: "rat \<Rightarrow> rat \<times> lu \<Rightarrow> rat \<times> fu \<Rightarrow> optical_input" where
  "optical_redundant_input ns l f = OpticalWavelengthFrequency ns (amt lu_scale l) (amt fu_scale f)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (E_HpKw 5) = Exact K_hp_kw (37285 / 10000) \<and>
     kernel (E_Tri (Some (13 / 10)) (T_Kw (400, VU_V) (50, AU_A))) = Decline (Impossible R_pf_over) \<and>
     kernel (E_Tri None (T_Kw (400, VU_V) (50, AU_A))) = Decline (Underspecified N_pf_power) \<and>
     kernel W_Judgement = Decline Judgement \<and>
     kernel (C_Circ (CB_Cur (Some (9, P_1)) (Some (150, P_1)) None)) = Exact K_current (6 / 100) \<and>
     response (reply_of (C_Circ (CB_Cur (Some (9, P_1)) (Some (150, P_1)) None))) =
       STR ''The current is 60 mA (I = V/R = 9 V / 150 @OHM@).'' \<and>
     kernel (C_Circ (CB_Cur (Some (9, P_1)) (Some (0, P_1)) None)) = Decline (Impossible R_resistor) \<and>
     stated (reply_of (E_Tri (Some (85 / 100)) (T_Kw (480, VU_V) (100, AU_A)))) = Some (STR ''70.67'') \<and>
     stated (reply_of (W_Diam 12)) = Some (STR ''2.053'') \<and>
     stated (reply_of (O_LensPower (Some (-50, L_cm)))) = Some (STR ''-2'') \<and>
     stated (reply_of (O_Snell (Some 40) (Some (1000293 / 1000000)) (Some (1333 / 1000)))) = Some (STR ''28.84'') \<and>
     (case kernel (O_Snell (Some 80) (Some (16 / 10)) (Some 1)) of Reflect _ \<Rightarrow> True | _ \<Rightarrow> False) \<and>
     kernel (O_Crit (Some (133 / 100)) (Some (15 / 10))) = Verdict K_no_critical \<and>
     stated (reply_of (O_Crit (Some (16 / 10)) (Some 1))) = Some (STR ''38.68'') \<and>
     stated (reply_of (O_Image (Some 10) (Some 40))) = Some (STR ''13.33'') \<and>
     kernel (O_Image (Some 10) (Some 10)) = Verdict K_at_focus \<and>
     stated (reply_of (O_EnergyL (400, L_nm))) = Some (STR ''3.1'')"

export_code optical_source_frequency_input optical_frequency_input optical_wavelength_input optical_redundant_input optical_snell
  OpticalFrequencyTarget OpticalWavelengthTarget OpticalEnergyTarget O_Wave O_UnknownOptical
  AngleToNormal AngleToSurface F_mHz
  reply_of answered reply_kind response stated mk_rat mk_nat lens_cm
  integer_of_int nat_of_integer int_of_integer lookup
  names_v names_a names_w names_va names_len names_wlen names_freq names_pfx names_cq names_medium
  medium_n
  VU_V VU_kV AU_A AU_kA PU_W PU_kW PU_MW VAU_VA VAU_kVA VAU_MVA
  L_nm L_um L_mm L_cm L_m L_km L_ft F_Hz F_kHz F_MHz F_GHz F_THz
  P_p P_n P_u P_m P_1 P_k P_M CQ_V CQ_A CQ_R CQ_W CQ_C
  Vacuum Air Water Diamond Copper Aluminium
  T_Wye T_Delta T_Kva T_Kw T_Cur T_Pf T_React
  Series Parallel EquivalentResistance SourceCurrent TotalPower CB_Network CB_Divider CB_Rc CB_Led CB_Cur CB_Volt CB_Res CB_Pow
  E_HpKw E_KwHp E_XfmrV E_XfmrI E_PfCorr E_Tri C_Circ W_Judgement W_Continuous W_Vdrop W_Res
  W_Area W_Diam W_Cur W_Cur3 O_EnergyL O_EnergyF O_Frequency O_Wavelength O_LensPower O_Image
  O_Object O_Focal O_Mag O_Crit O_Speed O_Index O_Snell
  in SML module_name Emoptics file_prefix emoptics

(* marker block *)
ML \<open>
  val theorems = [@{thm optical_kernel_model}, @{thm optical_kernel_wavelength}, @{thm optical_kernel_energy},
    @{thm optical_kernel_redundant_decline}, @{thm surface_snell_consumer_law},
    @{thm optical_source_frequency_preserved}, @{thm optical_wave_equations}, @{thm optical_wave_positive}, @{thm optical_stationary_frequency_energy},
    @{thm optical_redundant_inputs_consistent}, @{thm optical_inconsistent_measurements_declined},
    @{thm optical_surface_sine}, @{thm lens_cm_metres}, @{thm kernel_exact_sound}, @{thm kernel_approx_sound}, @{thm kernel_reflect_sound},
    @{thm kernel_underspecified}, @{thm kernel_impossible}, @{thm kernel_judgement}, @{thm kernel_imprecise},
    @{thm round_sig_sound}, @{thm to_dec_sound}, @{thm stated_dec_sound},
    @{thm hp_kw_value}, @{thm hp_kw_roundtrip}, @{thm transformer_power}, @{thm power_factor_value},
    @{thm power_triangle}, @{thm wye_line_voltage}, @{thm delta_line_current}, @{thm three_phase_apparent},
    @{thm three_phase_real_is_apparent_times_pf}, @{thm three_phase_current_inverse},
    @{thm pf_correction_tan}, @{thm pf_correction_balance}, @{thm pf_over_one}, 
    @{thm ohm_law}, @{thm power_is_vi}, @{thm parallel_reciprocal}, @{thm series_sum}, @{thm divider_ratio},
    @{thm rc_time_constant}, @{thm led_resistor}, @{thm zero_resistor_declined}, @{thm resistor_decline_exact},
    @{thm circuit_resistor_domain}, @{thm network_answer_domain}, @{thm network_current_conservation},
    @{thm network_power_conservation}, @{thm divider_passive_bounds}, @{thm parallel_below_smallest}, @{thm reply_states_approximation}, @{thm inverse_lens_equation},
    @{thm focal_lens_equation}, @{thm lens_roundtrip},
    @{thm awg_36}, @{thm awg_step}, @{thm wire_resistance_area}, @{thm voltage_drop_is_current_times_loop},
    @{thm continuous_eighty_percent}, @{thm single_phase_current}, @{thm vdrop_underspecified},
    @{thm photon_energy_wavelength}, @{thm frequency_wavelength}, @{thm wavelength_frequency}, @{thm medium_speed},
    @{thm lens_power}, @{thm thin_lens_equation}, @{thm magnification_ratio}, @{thm object_at_focus},
    @{thm no_critical_angle}, @{thm snell_law}, @{thm critical_angle_law},
    @{thm reply_answered_iff}, @{thm reply_states_exact}, @{thm reply_withheld_names_decline}] @ @{thms power_factor_never_assumed};
  val family_facts = Global_Theory.all_thms_of @{theory} true
    |> filter (fn ((name, _), _) => exists (fn prefix => String.isPrefix prefix name)
         ["Emoptics.", "Emoptics_Num.", "Emoptics_Optical_Model.", "Emoptics_Export."]);
  val family_theorems = map #2 family_facts;
  val oracles = Thm_Deps.all_oracles (theorems @ family_theorems);
  (* The aggregate checks every fact. On failure, locate one witness by
     partitioning, without repeatedly traversing every clean proof root. *)
  fun oracle_witness [] = NONE
    | oracle_witness [x] = SOME x
    | oracle_witness xs =
        let val (left, right) = chop (length xs div 2) xs
        in if null (Thm_Deps.all_oracles (map (fn (_, th) => th) left))
           then oracle_witness right else oracle_witness left end;
  val _ = if null oracles then ()
    else if null (Thm_Deps.all_oracles family_theorems)
      then Pretty.writeln (Thm_Deps.pretty_thm_oracles @{context} theorems)
    else (case oracle_witness family_facts of NONE => ()
      | SOME ((name, _), th) => (writeln ("EMOPTICS_ORACLE_FACT " ^ name);
          Pretty.writeln (Thm_Deps.pretty_thm_oracles @{context} [th])));
  val _ = if null oracles then () else error ("emoptics theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "emoptics self test failed";
  val marker = "VERI7VN_EMOPTICS PASS theorems=" ^ string_of_int (length theorems) ^ " scanned=" ^ string_of_int (length family_theorems) ^ " oracles=0";
  val _ = writeln marker;
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/emoptics")) [XML.Text marker];
\<close>

end
