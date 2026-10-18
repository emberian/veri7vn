theory Quantity_Export
  imports Quantity
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

text \<open>Whether the kernel answers a request; the units organ's narrowing (v2,
v3) consults it.\<close>
definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (Convert 100 (Tmp T_C) (Tmp T_F)) = Exact K_temperature 212 \<and>
     kernel (ConvertDelta 100 (Tmp T_C) (Tmp T_F)) = Exact K_temperature_difference 180 \<and>
     kernel (Convert 1 (Lin U_mile) (Lin U_kilometre)) = Exact K_convert (25146 / 15625) \<and>
     kernel (Convert 5 (Lin U_metre) (Lin U_kilogram)) = Decline Mismatch \<and>
     kernel (Convert 5 (Lin U_metre) (Tmp T_C)) = Decline Mismatch \<and>
     kernel (Convert (-300) (Tmp T_C) (Tmp T_K)) = Decline (Impossible R_below_absolute_zero) \<and>
     kernel (MassOf M_zinc (Some (2, U_litre)) U_kilogram) = Exact K_mass (14268 / 1000) \<and>
     kernel (MassOf M_gold None U_kilogram) = Decline (Underspecified N_amount) \<and>
     kernel (SpringPeriod (Some 2000) (Some (1, U_kilogram))) = Approx K_period (1405, -4) \<and>
     kernel (Floats M_lead M_diesel) = Verdict K_floats False \<and>
     kernel (Submerged M_ice M_water) = Exact K_submerged_fraction (917 / 1000) \<and>
     kernel (FuelCO2 F_lpg (Some (30, U_kilogram))) = Exact K_co2 (895389 / 10000) \<and>
     render_dec 4 (1405, -4) = STR ''0.1405'' \<and>
     kernel (MassOf M_petrol (Some (15, U_litre)) U_kilogram) = Exact K_mass (11175 / 1000) \<and>
     stated_dec K_mass (11175 / 1000) = Some (1118, -2) \<and>
     render_dec 10 (3700787402, -9) = STR ''3.700787402'' \<and>
     render_dec 4 (1000, 1) = STR ''1e+04'' \<and>
     stated (reply_of (Convert 94 (Lin U_millimetre) (Lin U_inch))) = Some (STR ''3.700787402'') \<and>
     response (reply_of (Convert 435 (Lin U_week) (Lin U_minute))) =
       STR ''435 weeks is 4384800 min (NIST exact factors).''"

export_code reply_of answered reply_kind response stated answers mk_rat self_test
  integer_of_int nat_of_integer int_of_integer
  lookup_unit unit_names material_order elements fluid_order solid_order fuel_order
  dens_vol_units dens_mass_units spring_disp_units spring_mass_units fluid_vol_units
  fuel_mass_units fuel_energy_units
  Lin Tmp U_kilogram U_cubic_metre U_metre U_kilowatt_hour U_megajoule
  Density MassOf VolumeOf Floats Convert ConvertDelta SpringForce SpringExtension SpringConstant
  SpringEnergy SpringPeriod SpringFrequency PressureGauge PressureAbs Buoyant Submerged
  FuelEnergy FuelCO2 FuelMassNeeded FuelNCV
  in SML module_name Quantity file_prefix quantity

ML \<open>
  val theorems = [@{thm kernel_exact_sound}, @{thm kernel_approx_sound},
    @{thm kernel_underspecified}, @{thm kernel_mismatch}, @{thm kernel_impossible},
    @{thm kernel_undecided}, @{thm kernel_imprecise}, @{thm reason_of_exact},
    @{thm round_sig_sound}, @{thm to_dec_sound}, @{thm stated_dec_sound},
    @{thm convert_exact}, @{thm convert_mismatch}, @{thm convert_composes},
    @{thm temperature_point}, @{thm temperature_impossible},
    @{thm temperature_point_vs_difference}, @{thm temperature_point_not_difference},
    @{thm temperature_difference_scales}, @{thm temperature_round_trip},
    @{thm temperature_delta_exact}, @{thm temperature_delta_round_trip}, @{thm temperature_delta_endpoints},
    @{thm spring_energy_force}, @{thm pressure_absolute_gauge},
    @{thm density_value}, @{thm mass_from_volume}, @{thm volume_from_mass},
    @{thm floats_verdict}, @{thm floats_undecided},
    @{thm hooke_force}, @{thm hooke_extension}, @{thm hooke_constant}, @{thm elastic_energy},
    @{thm spring_period_model}, @{thm spring_frequency_inverse}, @{thm spring_frequency_model},
    @{thm round_tie_up},
    @{thm gauge_pressure}, @{thm absolute_pressure}, @{thm buoyant_force},
    @{thm submerged_fraction}, @{thm submerged_sinks},
    @{thm fuel_energy}, @{thm fuel_co2}, @{thm fuel_mass_needed}, @{thm fuel_ncv},
    @{thm reply_answered_iff}, @{thm reply_states_exact}, @{thm reply_states_approx},
    @{thm reply_withheld_names_decline}] @ @{thms temperature_linear_mismatch};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("quantity theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "quantity self test failed";
  val _ = writeln ("VERI7VN_QUANTITY PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
