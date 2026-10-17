theory Space_Export
  imports Space
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (SExhaust 220) = Exact (STR ''exhaust_velocity'') (2157463 / 1000) \<and>
     kernel (PEscape (Pb_earth 1 1)) = Approx (STR ''escape'') (111857, -4) \<and>
     kernel (OSpeed (Some O_earth) (Some 200)) = Approx (STR ''orbit_speed'') (7784, -3) \<and>
     kernel (OPeriod (Some O_earth) (Some 200)) = Approx (STR ''period'') (8849, -2) \<and>
     kernel (OHohDv (Some O_earth) (Some (1000, 35786))) = Approx (STR ''hohmann_dv'') (3636, -3) \<and>
     kernel (OHohTime (Some O_earth) (Some (1000, 35786))) = Approx (STR ''hohmann_time'') (5389, -3) \<and>
     kernel (OSync (Some O_earth)) = Approx (STR ''sync_alt'') (35786, 0) \<and>
     kernel (SDeltaV (Ve_isp 450) 10000 Mu_kg 4000 Mu_kg) = Approx (STR ''delta_v'') (40435841, -4) \<and>
     kernel (OSpeed None (Some 400)) = Decline (Underspecified N_body) \<and>
     kernel (OSpeed (Some O_mars) None) = Decline (Underspecified N_alt) \<and>
     kernel (OSync (Some O_venus)) = Decline NoSync \<and>
     kernel (SDeltaV (Ve_isp 320) 2000 Mu_kg 2500 Mu_kg) = Decline (Impossible R_final_exceeds_initial) \<and>
     kernel (AProp A_jupiter P_pressure) = Decline NoValue \<and>
     kernel (AProp A_earth P_gravity) = Fact (STR ''gravity'') (Cnum (STR ''9.8'') (49 / 5) False) \<and>
     stated (reply_of (CXfer 2 Dp_m True 2 Ru_kbps)) = Some (STR ''8000'') \<and>
     stated (reply_of (STwr 100 Fu_kn 5000 Mu_kg)) = Some (STR ''2.03943'') \<and>
     response (reply_of (STwr 100 Fu_kn 5000 Mu_kg)) =
       STR ''The thrust-to-weight ratio is 2.0394 (100,000 N / (5000 kg x 9.80665)).'' \<and>
     answered (reply_of (OSync (Some O_earth))) \<and>
     \<not> answered (reply_of (OSync (Some O_venus)))"

export_code reply_of answered reply_kind response stated kernel mk_rat self_test
  integer_of_int nat_of_integer int_of_integer
  abody_order abody_name obody_order obody_name sheet cell_num
  PGravity PEscape POrbV PDensity PWeightE Pb_si Pb_earth Lu_m Lu_km
  OSync OSpeed OPeriod OEscape OHohDv OHohTime
  SExhaust STwr SMassFlow SBurn SDeltaV SProp0 SPropF
  Mu_kg Mu_t Fu_n Fu_kn Fu_mn Su_mps Su_kmps Ve_isp Ve_speed
  CLight CFspl CXfer CBits Dist Ds_one Ds_million Ds_billion Db_km Db_mile Db_au
  Fq_hz Fq_khz Fq_mhz Fq_ghz Dp_one Dp_k Dp_m Dp_g Dp_t Ru_bps Ru_kbps Ru_mbps Ru_gbps
  AProp AFake ALight AWeight ARatio AYears AMoonKm AMoonKkm Wu_kg Wu_lb Rs_v1 Rs_v2
  O_earth O_moon O_mars O_sun O_jupiter O_venus
  A_mercury A_venus A_earth A_moon A_mars A_jupiter A_saturn A_uranus A_neptune A_pluto
  P_mass P_diameter P_density P_gravity P_escape P_rotation P_day P_distance P_perihelion
  P_aphelion P_period P_velocity P_inclination P_eccentricity P_tilt P_temperature
  P_pressure P_moons P_rings P_magnetic
  Cnum Cword Cunk
  in SML module_name Space file_prefix space

ML \<open>
  val theorems = [@{thm kernel_exact_sound}, @{thm kernel_approx_sound}, @{thm kernel_fact_sound},
    @{thm kernel_underspecified}, @{thm kernel_nosync}, @{thm kernel_impossible},
    @{thm kernel_unknown}, @{thm kernel_novalue}, @{thm kernel_imprecise},
    @{thm stated_dec_sound}, @{thm to_dec_sound}, @{thm enclose_sound}, @{thm round_tie_up},
    @{thm gravity_model}, @{thm weight_model}, @{thm escape_model}, @{thm orbital_velocity_model},
    @{thm escape_vs_orbital}, @{thm density_model},
    @{thm orbit_speed_model}, @{thm orbit_period_model}, @{thm hohmann_time_model},
    @{thm hohmann_vis_viva}, @{thm hohmann_dv_nonneg}, @{thm sync_model},
    @{thm exhaust_model}, @{thm twr_model}, @{thm mass_flow_model}, @{thm burn_time_model},
    @{thm tsiolkovsky_model}, @{thm propellant_initial_model}, @{thm propellant_final_model},
    @{thm light_time_model}, @{thm transfer_model}, @{thm bits_in_flight_model}, @{thm fspl_model},
    @{thm property_model}, @{thm weight_elsewhere_model}, @{thm sunlight_model},
    @{thm ratio_model}, @{thm years_model},
    @{thm reply_answered_iff}, @{thm reply_states_approx}, @{thm reply_states_exact},
    @{thm reply_states_fact}, @{thm reply_withheld_names_decline}] @ @{thms orbit_escape_model};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("space theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "space self test failed";
  val _ = writeln ("VERI7VN_SPACE PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
