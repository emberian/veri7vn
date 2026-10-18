theory Climate_Export
  imports Climate
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition mk_int :: "integer \<Rightarrow> int" where "mk_int a = int_of_integer a"

text \<open>Whether the kernel answers a request; the organs fall through to the next
branch when a cooling reading is not a stage, and decline only short questions.\<close>
definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

definition not_taken :: "request \<Rightarrow> bool" where
  "not_taken r = (kernel r = Decline Not_taken)"

text \<open>Only the AQI and cooling routes can fall through. Testing whether a
climate or carbon-material request is in lane must not compute its interval
answer and then throw that computation away.\<close>
lemma not_taken_code [code]:
  "not_taken r = (case r of
     Req_aq a \<Rightarrow> aq_kernel a = Decline Not_taken
   | Req_cd c \<Rightarrow> cd_kernel c = Decline Not_taken
   | _ \<Rightarrow> False)"
  by (cases r)
     (auto simp: not_taken_def cc_kernel_def cl_kernel_def cm_kernel_def Let_def
       split: option.splits cmreq.splits dest: spec_out_decline)

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     stated (reply_of (Req_cc (Cc_fuel_co2 F_gasoline (STR ''gasoline'') 10))) = Some (STR ''88.87'') \<and>
     stated (reply_of (Req_cc (Cc_co2_per_mile F_gasoline (STR ''gasoline'') 40))) = Some (STR ''222.175'') \<and>
     response (reply_of (Req_cc (Cc_captured 10000 (STR ''tonnes'') 95))) =
       STR ''The CO2 captured is 9500 tonnes (10000 x 95% capture rate).'' \<and>
     kernel (Req_cc (Cc_captured 1 (STR ''t'') 101)) = Decline (Impossible R_rate_over_100) \<and>
     kernel (Req_aq (Aq_index False [Reading P_pm25 (121 / 2) Au_ug])) = Index K_aqi 155 P_pm25 \<and>
     kernel (Req_aq (Aq_index False [Reading P_o3 150 Au_ppb])) = Index K_aqi 247 P_o3 \<and>
     kernel (Req_aq (Aq_index False [Reading P_o3 (1 / 4) Au_ppm])) = Decline (Impossible R_o3_above_8h) \<and>
     kernel (Req_aq (Aq_index False [Reading P_pm25 (4017 / 100) Au_ug, Reading P_o3 (31 / 1000) Au_ppm])) =
       Index K_overall 112 P_pm25 \<and>
     kernel (Req_aq (Aq_category 101 (STR ''101''))) = Category Cat_usg \<and>
     kernel (Req_aq (Aq_category 650 (STR ''650''))) = Decline (Impossible R_aqi_out_of_scale) \<and>
     stated (reply_of (Req_cl (Cl_forcing (Some (280, 420))))) = Some (STR ''2.169'') \<and>
     stated (reply_of (Req_cl (Cl_warming (Some (280, 560)) (Sens_ecs 3)))) = Some (STR ''3'') \<and>
     stated (reply_of (Req_cl (Cl_eff_temp (Some 1361) (Some (3 / 10))))) = Some (STR ''254.578'') \<and>
     stated (reply_of (Req_cl (Cl_ppm_to_gtc 140))) = Some (STR ''297.36'') \<and>
     kernel (Req_cl (Cl_warming (Some (280, 420)) Sens_none)) = Decline (Underspecified N_sens) \<and>
     stated (reply_of (Req_cm (Cm_diameter 10 0))) = Some (STR ''0.783'') \<and>
     stated (reply_of (Req_cm (Cm_angle 6 5))) = Some (STR ''26.9955'') \<and>
     kernel (Req_cm (Cm_type 10 10)) = Verdict K_cnt_type True \<and>
     kernel (Req_cm (Cm_kind 9 3)) = Tube_kind T_chiral \<and>
     kernel (Req_cm (Cm_diameter 3 8)) = Decline (Impossible R_bad_chirality) \<and>
     stated (reply_of (Req_cm (Cm_mass 100 False))) = Some (STR ''76.1128'') \<and>
     kernel (Req_cd (Cd_cool (Temp 135 False) (Temp 70 False) (Dur 3 False))) = Verdict K_cooling_check False \<and>
     kernel (Req_cd (Cd_cool (Temp 70 False) (Temp 41 False) (Dur 4 False))) = Verdict K_cooling_check True \<and>
     kernel (Req_cd (Cd_cool (Temp 80 False) (Temp 60 False) (Dur 1 False))) = Decline Not_taken \<and>
     kernel (Req_cd (Cd_date (Some Thursday))) = Weekday Wednesday \<and>
     kernel (Req_cd (Cd_cook Cook_ground)) = Exact K_cook_temp 155"

export_code reply_of answered reply_kind response stated answers not_taken
  mk_rat mk_int integer_of_int nat_of_integer int_of_integer
  Req_cc Req_aq Req_cl Req_cm Req_cd
  F_gasoline F_diesel E_kwh E_mwh E_gj
  Cc_c_to_co2 Cc_co2_to_c Cc_fuel_co2 Cc_co2_per_mile Cc_captured Cc_capture_energy
  P_pm25 P_pm10 P_o3 P_co P_so2 P_no2 Au_none Au_ug Au_ppm Au_ppb Reading Aq_index Aq_category
  Sens_lambda Sens_ecs Sens_none
  Cl_forcing Cl_warming Cl_ppm_to_gtc Cl_ppm_to_gtco2 Cl_mass_to_ppm Cl_eff_temp Cl_co2e
  Cm_diameter Cm_angle Cm_type Cm_kind Cm_layers Cm_mass
  Temp Dur Cook_poultry Cook_ground Cook_whole
  Cd_cool Cd_schedule Cd_schedule_unknown Cd_partial Whole_schedule Checkpoint_only Cd_cold Cd_hot Cd_cook Cd_reheat Cd_tphc Cd_date Cd_danger
  Monday Tuesday Wednesday Thursday Friday Saturday Sunday
  in SML module_name Climate file_prefix climate

ML \<open>
  val theorems = [
    @{thm not_taken_code}, @{thm approx_out_sound}, @{thm spec_out_exact}, @{thm spec_out_approx},
    @{thm to_fixed_sound}, @{thm enclose_fixed_sound}, @{thm g_dec_sound}, @{thm round_sig_sound},
    @{thm cc_kernel_sound}, @{thm cc_kernel_declines}, @{thm c_to_co2_model}, @{thm co2_to_c_model},
    @{thm carbon_co2_roundtrip}, @{thm fuel_co2_model}, @{thm co2_per_mile_model}, @{thm captured_model},
    @{thm capture_energy_model}, @{thm capture_rate_over_100}, @{thm capture_energy_rate_over_100},
    @{thm zero_mpg_declined},
    @{thm best_max}, @{thm sub_index_interpolation}, @{thm sub_index_none}, @{thm aq_single_sound},
    @{thm aq_overall_sound}, @{thm aq_category_sound}, @{thm aq_category_out_of_scale}, @{thm cat_of_bands},
    @{thm cl_exact_sound}, @{thm cl_approx_sound}, @{thm cl_underspecified}, @{thm cl_impossible_iff},
    @{thm forcing_model}, @{thm forcing_doubling}, @{thm warming_ecs_model}, @{thm warming_ecs_per_doubling},
    @{thm warming_lambda_model}, @{thm effective_temperature_model}, @{thm ppm_gtc_model},
    @{thm gtco2_gtc_model}, @{thm co2e_model}, @{thm co2e_needs_gwp},
    @{thm warming_needs_sensitivity}, @{thm albedo_out_of_range},
    @{thm cm_exact_sound}, @{thm cm_approx_sound}, @{thm cm_impossible_iff}, @{thm cnt_circumference},
    @{thm cnt_chiral_angle_tangent}, @{thm cnt_type_metallic}, @{thm cnt_kind_classes},
    @{thm graphene_layers_model}, @{thm graphene_areal_mass}, @{thm graphene_mass_is_area_times_areal},
    @{thm compatible_cooling_exists}, @{thm compatible_cooling_pass}, @{thm compatible_cooling_fail},
    @{thm partial_clock_true}, @{thm partial_clock_false}, @{thm partial_clock_unknown},
    @{thm partial_clock_negative}, @{thm partial_checkpoint_scope(1)}, @{thm partial_checkpoint_scope(2)},
    @{thm partial_cooling_whole_binding}, @{thm partial_cooling_true}, @{thm partial_cooling_false}, @{thm partial_cooling_unknown}, @{thm partial_cooling_negative},
    @{thm cooling_verdict}, @{thm cooling_not_a_stage}, @{thm cooling_negative_time},
    @{thm cooling_pass_elapsed_bound}, @{thm tphc_negative_time}, @{thm tphc_pass_elapsed_bound},
    @{thm cooling_schedule_clock_law}, @{thm cooling_schedule_negative_time},
    @{thm cooling_schedule_shorter}, @{thm cooling_schedule_missing},
    @{thm cooling_schedule_temperature_bounds}, @{thm cooling_schedule_above_limit},
    @{thm cooling_schedule_nominal_units(1)}, @{thm cooling_schedule_nominal_units(2)},
    @{thm cool_stage1}, @{thm cool_stage2},
    @{thm cool_stage3}, @{thm cold_hold_verdict(1)}, @{thm cold_hold_verdict(2)}, @{thm cooking_minimums(1)}, @{thm cooking_minimums(2)}, @{thm cooking_minimums(3)}, @{thm tphc_limit(1)}, @{thm tphc_limit(2)},
    @{thm date_marking}, @{thm date_marking_kernel}, @{thm celsius_to_fahrenheit},
    @{thm reply_answered_iff}, @{thm reply_withheld_names_decline}, @{thm reply_states_exact},
    @{thm reply_states_approx}, @{thm exact_stated_sound}, @{thm carbon_kernel_roundtrip}, @{thm sub_index_monotone}, @{thm albedo_decline_iff}]
    @ @{thms cnt_chirality_declined};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("climate theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "climate self test failed";
  val _ = writeln ("VERI7VN_CLIMATE PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
