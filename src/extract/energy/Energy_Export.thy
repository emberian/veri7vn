theory Energy_Export
  imports Energy_Family
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel_t (Thermo [Temp 500 TU_K, Temp 350 TU_K] (TCarnot True)) = Exact (STR ''carnot'') 30 \<and>
     response (reply_t (Thermo [Temp 500 TU_K, Temp 350 TU_K] (TCarnot True))) =
       STR ''The Carnot efficiency is 30% (1 - T_c/T_h = 1 - 350 K / 500 K).'' \<and>
     stated (reply_t (Thermo [Temp 0 TU_C] (TGas (Some 2) None (Some (50, VU_L))))) = Some (STR ''9.084e+04'') \<and>
     stated (reply_t (Thermo [] (TFusion (Some (2, MU_kg))))) = Some (STR ''6.68e+05'') \<and>
     stated (reply_t (Thermo [Temp 20 TU_C, Temp 80 TU_C] (TSens (Some (2, MU_kg)) (C_mat Mat_lead) DT_temps))) =
       Some (STR ''1.548e+04'') \<and>
     stated (reply_t (Thermo [Temp 300 TU_K] (TRad (Some 1) 1))) = Some (STR ''459.3'') \<and>
     \<not> answered (reply_t (Thermo [Temp 300 TU_K, Temp 600 TU_K] (TCarnot True))) \<and>
     \<not> answered (reply_t (Thermo [Temp (-300) TU_C] TAny)) \<and>
     \<not> answered (reply_t (Thermo [] (TGas (Some 1) None (Some (1, VU_m3))))) \<and>
     \<not> answered (reply_t (Thermo [] (TFusion None))) \<and>
     \<not> answered (reply_t (Thermo [] (TSens (Some (3, MU_kg)) C_none (DT_by 30)))) \<and>
     response (reply_h (HEnergy (Some 100) (Some (H_tot 5)) None False)) =
       STR ''It uses 0.5 kWh (100 W x 5 h = 500 Wh).'' \<and>
     response (reply_h (HEnergy (Some 1000) (Some (H_tot 2)) (Some (15 / 100)) True)) =
       STR ''It costs about $0.30 (2 kWh = 1000 W x 2 h, at $0.15/kWh).'' \<and>
     response (reply_h (HPayback (Some 10000) (Some (1000, False)))) =
       STR ''The payback period is 10 years ($10,000 / $1,000 saved per year), ignoring price changes and financing.'' \<and>
     response (reply_h (HPayback (Some 100) (Some (0, False)))) = STR ''With no saving, it never pays back.'' \<and>
     answered (reply_h (HPayback (Some 100) (Some (0, False)))) \<and>
     \<not> answered (reply_h (HEnergy (Some 100) (Some (H_tot 1)) None True)) \<and>
     response (reply_h (HSolar (Some (5, True)) None (Some 4) Dr_none Per_day)) =
       STR ''The array makes about 20 kWh a day (5 kW x 4 peak sun hours, before losses).'' \<and>
     response (reply_h (HRuntime (Some (Cap_wh 1000)) (Some 100))) =
       STR ''The runtime is about 10 hours (1000 Wh / 100 W), before inverter and depth-of-discharge losses.'' \<and>
     response (reply_h (HSwap 60 10 (Some (H_tot 10)) None)) = STR ''That saves 0.5 kWh (50 W less x 10 h).'' \<and>
     response (reply_v (VTons 24000)) = STR ''That is 2 tons of cooling (24,000 BTU/h / 12,000).'' \<and>
     response (reply_v (VSens 100 (Some 20))) =
       STR ''The sensible heat is 2160 BTU/h (1.08 x 100 CFM x 20 F; standard air).'' \<and>
     response (reply_v (VAch (Some 100) (Some 600))) = STR ''That is 10 air changes per hour (100 CFM x 60 / 600 ft3).'' \<and>
     response (reply_v (VCond (Some 100) 10 (Some (DS_pair 70 20)))) =
       STR ''The heat loss is 500 BTU/h (A x dT / R = 100 ft2 x 50 F / R-10).'' \<and>
     \<not> answered (reply_v VSizing) \<and>
     response (reply_r (RHydro 2 30 (4 / 5))) =
       STR ''The power is 470.88 kW (P = rho g Q h eta = 1000 x 9.81 x 2 m3/s x 30 m x 0.8).'' \<and>
     response (reply_r (RRatio 4 6)) =
       STR ''The power changes by a factor of 3.375 ((6 / 4)^3 - power goes as wind speed cubed).'' \<and>
     response (reply_r (RCapF 5000000 13140000000 8760)) =
       STR ''The capacity factor is 30% (13.14 GWh / (5 MW x 8760 h)).'' \<and>
     response (reply_r (RWind (G_diam 80) 10 (1225 / 1000) None)) =
       STR ''The power in the wind is 3.079 MW (1/2 rho A v^3 = 1/2 x 1.225 x A x 10^3; A = pi(D/2)^2 = 5026.548 m2).'' \<and>
     \<not> answered (reply_r (RWind (G_diam 100) 10 (1225 / 1000) (Some (7 / 10)))) \<and>
     \<not> answered (reply_r (RPV 10 Irr_none (1 / 5))) \<and>
     response (reply_i (IAdcLsb 12 (Some (33 / 10)))) =
       STR ''The resolution is 0.8057 mV per step (Vref 3.3 V / 2^12 = 4,096 steps).'' \<and>
     response (reply_i (IAdcCode 10 (Some (33 / 10)) (165 / 100))) =
       STR ''The code is 512 (floor(1.65 V / 3.3 V x 2^10)).'' \<and>
     response (reply_i (IBatConst 2000 100 True)) =
       STR ''The battery lasts 0.8333 days (2000 mAh / 100 mA = 20 h; ideal, no self-discharge).'' \<and>
     response (reply_i (INyquist 1000)) = STR ''The minimum sampling rate is 2000 Hz (Nyquist: 2 x 1000 Hz).'' \<and>
     response (reply_i (IStorage 100 16 1)) =
       STR ''That is 17.28 MB per day (1600 bit/s x 86,400 s / 8 / 10^6).'' \<and>
     \<not> answered (reply_i (IAdcVolt 8 (Some 5) 256))"

export_code reply_of answered reply_kind response stated mk_rat
  integer_of_int nat_of_integer int_of_integer
  mat_table air_density
  Temp TU_C TU_F TU_K PU_Pa PU_kPa PU_atm PU_bar VU_m3 VU_L VU_mL MU_kg MU_g
  C_given C_mat C_none DT_by DT_temps
  TCarnot TGas TRad TFusion TVapor TSens TAny Thermo
  H_pdd H_pdy H_pdm H_day H_tot H_min Cap_wh Cap_kwh Cap_ahv Dr_none Dr_loss Dr_eff
  Per_day Per_year Per_month HPayback HRuntime HRuntimeAdjusted HRuntimeMissingFactors HSolar HSwap HEnergy
  DS_direct DS_pair VTons VBtuh VAch VCfm VSens VCond VSeasonal VSizing
  G_swept G_diam G_rad Irr_given Irr_stc Irr_none RHydro RPV RCapF RAnnual RRatio RWind
  IAdcLsb IAdcVolt IAdcCode INyquist IAvgCur IBat IBatConst IDataRate IStorage
  FThermo FHome FHvac FRen FIot
  in SML module_name Energy file_prefix energy

ML \<open>
  val theorems = [@{thm cap_valid_nonnegative}, @{thm runtime_missing_factors}, @{thm adjusted_runtime_law}, @{thm adjusted_runtime_agrees}, @{thm mk_exact}, @{thm mk_pi}, @{thm mk_fixed}, @{thm mk_decline},
    @{thm num_dec_r_sound}, @{thm show_fmt_sound}, @{thm round_sig_sound}, @{thm to_dec_sound},
    @{thm round_tie_up}, @{thm pi_bounds_sound}, @{thm pw_scale_sound}, @{thm pw_show_sound},
    @{thm mk_reply_answered_iff}, @{thm mk_reply_exact}, @{thm mk_reply_withheld},
    @{thm family_declines_withheld},
    (* across kinds *)
    @{thm sensible_heat_swap}, @{thm tons_btuh_roundtrip}, @{thm btuh_tons_roundtrip},
    @{thm cost_is_energy_times_tariff}, @{thm swap_is_energy_difference},
    (* thermo *)
    @{thm thermo_exact_sound}, @{thm thermo_underspecified}, @{thm thermo_impossible_temperature},
    @{thm thermo_impossible_only_if}, @{thm thermo_no_other_declines}, @{thm kelvin_scales},
    @{thm carnot_law}, @{thm gas_pressure_law}, @{thm gas_volume_law}, @{thm gas_moles_law},
    @{thm gas_temperature_law}, @{thm gas_three_given}, @{thm radiated_power_law},
    @{thm latent_fusion_law}, @{thm latent_vapor_law}, @{thm sensible_heat_by},
    @{thm sensible_heat_temps}, @{thm sensible_heat_table},
    @{thm reply_t_answered_iff}, @{thm reply_t_states_four_digits}, @{thm reply_t_withheld},
    (* home *)
    @{thm home_exact_sound}, @{thm home_underspecified}, @{thm home_declines}, @{thm payback_law},
    @{thm payback_never}, @{thm runtime_law}, @{thm solar_law}, @{thm swap_law}, @{thm energy_law},
    @{thm cost_law}, @{thm cost_needs_tariff}, @{thm reply_h_answered_iff},
    @{thm reply_h_states_digits}, @{thm reply_h_withheld},
    (* hvac *)
    @{thm hvac_exact_sound}, @{thm hvac_underspecified}, @{thm hvac_sizing_always_declined},
    @{thm pair_difference_nonneg},
    @{thm tons_law}, @{thm btuh_law}, @{thm ach_law}, @{thm cfm_law}, @{thm sensible_law},
    @{thm conduction_law}, @{thm seasonal_law}, @{thm reply_v_answered_iff},
    @{thm reply_v_states_digits}, @{thm reply_v_withheld},
    (* renewables *)
    @{thm ren_exact_sound}, @{thm ren_pi_sound}, @{thm ren_underspecified}, @{thm hydro_law},
    @{thm pv_law}, @{thm capacity_factor_law}, @{thm annual_energy_law}, @{thm wind_ratio_law},
    @{thm wind_power_swept_law}, @{thm wind_power_diameter_law}, @{thm wind_power_radius_law},
    @{thm reply_r_answered_iff}, @{thm reply_r_power_units}, @{thm reply_r_withheld},
    (* iot *)
    @{thm iot_exact_sound}, @{thm iot_underspecified}, @{thm adc_voltage_law}, @{thm adc_lsb_law},
    @{thm adc_code_law}, @{thm nyquist_law}, @{thm avg_current_law}, @{thm battery_life_law},
    @{thm battery_life_const_law}, @{thm data_rate_law}, @{thm storage_law},
    @{thm reply_i_answered_iff}, @{thm reply_i_states_digits}, @{thm reply_i_withheld}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("energy theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "energy self test failed";
  val _ = writeln ("VERI7VN_ENERGY PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
