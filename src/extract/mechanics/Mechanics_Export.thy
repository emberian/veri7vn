theory Mechanics_Export
  imports Mechanics
begin

text \<open>Constructor the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel FsModelLimit = Decline (Underspecified N_fluid_conditions) \<and>
     kernel (PhKE (Some 5) (Some 2)) = Exact K_ke 10 \<and>
     kernel (PhKE (Some (mass_kg 500 MU_g)) (Some 4)) = Exact K_ke 4 \<and>
     kernel (SpObp 0 1 0 0 0) = Exact K_obp 1 \<and>
     kernel (FvCost 0 DU_mi (E_mpg False 30) (Some (389 / 100, True))) = Exact K_trip_cost 0 \<and>
     kernel (BdWeight (G_stated 0) (Some 4)) = Exact K_weight 0 \<and>
     kernel (PhFinalV (Some (3 / 2)) (Some 5) None True) = Exact K_final_velocity (15 / 2) \<and>
     kernel (PhFinalV (Some 2) (Some 3) None False) = Decline (Underspecified N_start_speed) \<and>
     kernel (PhPower 1 0) = Decline (Impossible R_zero_time) \<and>
     kernel (PhKE (Some 5) None) = Decline (Underspecified N_mass_speed) \<and>
     kernel (BdWeight (G_body MB_mars) (Some 400)) = Exact K_weight 1484 \<and>
     kernel (McInclineMA 1 3) = Decline (Impossible R_ramp) \<and>
     kernel (McLeverEffort (3 / 2) (3 / 10) None) = Decline (Underspecified N_load) \<and>
     kernel (McGearRatio 30 12) = Exact K_gear_ratio (2 / 5) \<and>
     kernel (FsSubmerged MS_lead MF_water) = Sinks \<and>
     kernel (FsSubmerged MS_ice MF_water) = Exact K_submerged_fraction (917 / 1000) \<and>
     kernel (SpGamesBehind 50 30 45 36) = Exact K_games_behind (11 / 2) \<and>
     kernel (SpEra 2 5 1) = Decline (Impossible R_bad_innings) \<and>
     kernel (SpEra 0 0 1) = Decline (Impossible R_zero_innings) \<and>
     kernel (FvBraking None (Some (3 / 5))) = Decline (Underspecified N_speed_friction) \<and>
     kernel (FvCost 250 DU_mi (E_mpg False 50) None) = Decline (Underspecified N_price) \<and>
     stated (reply_of (PhImpact 45)) = Some (STR ''29.71'') \<and>
     stated (reply_of (PhFall 45)) = Some (STR ''3.029'') \<and>
     stated (reply_of (PhRange (Some 40) (Some 45))) = Some (STR ''163.2'') \<and>
     stated (reply_of (McShaftPower 1500 20)) = Some (STR ''3142'') \<and>
     stated (reply_of (McTorqueAngle 50 (1 / 2) LU_m 30)) = Some (STR ''12.5'') \<and>
     stated (reply_of (BdPendulum (G_body MB_neptune) (Some 3))) = Some (STR ''3.259'') \<and>
     stated (reply_of (SpAvg 201 612)) = Some (STR ''0.328'') \<and>
     stated (reply_of (SpPasser 15 40 150 0 3)) = Some (STR ''17.7'') \<and>
     stated (reply_of (SpGamesBehind 50 30 45 36)) = Some (STR ''5.5'') \<and>
     stated (reply_of (SpGamesBehind 88 62 95 55)) = Some (STR ''7'') \<and>
     stated (reply_of (FvCost 250 DU_mi (E_mpg False 50) (Some (319 / 100, True)))) = Some (STR ''15.95'') \<and>
     stated (reply_of (FvToLpk False 50)) = Some (STR ''4.704'') \<and>
     render_dec 4 (1000, 1) = STR ''1e+04'' \<and>
     render_fixed 3 (5, -3) = STR ''0.005'' \<and>
     render_trim 2 (350, -2) = STR ''3.5'' \<and>
     response (reply_of (PhKE (Some 5) (Some 2))) =
       STR ''The kinetic energy is 10 J (KE = 1/2 m v^2 = 1/2 x 5 x 2^2).''"

export_code reply_of answered reply_kind response stated mk_rat length_m mass_kg
  integer_of_int nat_of_integer int_of_integer
  fluid_order solid_order body_order
  SU_kmh SU_mph SU_ms LU_m LU_cm LU_mm LU_ft LU_in LU_yd LU_mi MU_kg MU_g MU_tonne MU_lb VU_m3 VU_l VU_cm3 DU_mi DU_km LD_n LD_kg
  E_mpg E_lpk G_body G_stated
  PhRange PhImpact PhFall PhKE PhPE PhMomentum PhWeight PhForce PhWork PhPower PhFinalV
  PhDistance BdWeight BdFall BdImpact BdPendulum BdUnreadable FsModelLimit
  McGearRatio McGearSpeed McGearTorque McBeltSpeed McPulleyMA McPulleyEffort McLeverMA
  McLeverEffort McInclineMA McShaftPower McTorque McTorqueAngle McNeed
  SpPasser SpTrueShooting SpEra SpWhip SpAvg SpObp SpSlg SpGamesBehind SpWinPct
  FvBraking FvStopping FvToLpk FvToMpg FvCO2 FvCost FvLitres FvGallons
  FsGauge FsAbs FsBuoyant FsSubmerged
  in SML module_name Mechanics file_prefix mechanics

ML \<open>
  val theorems = [@{thm kernel_exact_sound}, @{thm kernel_approx_sound},
    @{thm kernel_underspecified}, @{thm kernel_impossible}, @{thm kernel_imprecise},
    @{thm reason_of_exact}, @{thm round_sig_sound}, @{thm to_dec_sound}, @{thm stated_dec_sound},
    @{thm round_tie_up},
    @{thm kinetic_energy}, @{thm potential_energy}, @{thm momentum_def}, @{thm weight_on_earth},
    @{thm newton_force}, @{thm work_def}, @{thm power_def}, @{thm final_velocity_def},
    @{thm distance_def}, @{thm impact_model}, @{thm fall_model}, @{thm range_model},
    @{thm body_weight}, @{thm body_weight_units}, @{thm fluid_model_limit_refuses}, @{thm kinetic_energy_units}, @{thm body_fall_model}, @{thm body_impact_model}, @{thm pendulum_model},
    @{thm gear_ratio_def}, @{thm gear_speed_def}, @{thm gear_torque_def}, @{thm belt_speed_def},
    @{thm pulley_ma_def}, @{thm pulley_effort_def}, @{thm lever_ma_def}, @{thm lever_effort_def},
    @{thm incline_ma_def}, @{thm torque_def}, @{thm shaft_power_model}, @{thm torque_angle_bound},
    @{thm passer_rating_def}, @{thm true_shooting_def}, @{thm era_def}, @{thm whip_def},
    @{thm batting_average_def}, @{thm on_base_def}, @{thm slugging_def}, @{thm games_behind_def},
    @{thm win_pct_def},
    @{thm braking_def}, @{thm stopping_def}, @{thm to_lpk_def}, @{thm to_mpg_def},
    @{thm trip_co2_def}, @{thm trip_cost_def}, @{thm trip_litres_def}, @{thm trip_gallons_def},
    @{thm gauge_pressure}, @{thm absolute_pressure}, @{thm buoyant_force},
    @{thm submerged_fraction}, @{thm submerged_sinks},
    @{thm kinetic_energy_momentum}, @{thm drop_energy_conserved}, @{thm stopping_is_reaction_plus_braking},
    @{thm answered_physical_domain}, @{thm lever_units}, @{thm lever_effort_units},
    @{thm reply_answered_iff}, @{thm reply_states_exact}, @{thm reply_states_approx},
    @{thm reply_withheld_names_decline}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("mechanics theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "mechanics self test failed";
  val _ = writeln ("VERI7VN_MECHANICS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
