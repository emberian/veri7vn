theory Earth_Export
  imports Earth
begin

definition self_tests :: "bool list" where
  "self_tests = [
    response (reply_of (RGeo (GCapital (STR ''brazil'')))) = STR ''The capital of Brazil is Brasilia.'',
    reply_kind (reply_of (RGeo (GCapital (STR ''netherlands'')))) = STR ''capital_split'',
    stated (reply_of (RGeo (GGc False (356762 / 10000) (13965 / 100) (- 338688 / 10000) (151209 / 1000)))) = Some (STR ''7826''),
    stated (reply_of (RGeo (GSolar 60 (- 90)))) = Some (STR ''10''),
    stated (reply_of (RGeol (GlLeft (HlIso C14) 11460))) = Some (STR ''0.25''),
    stated (reply_of (RGeol (GlAge (HlIso C14) (MFrac (1 / 4))))) = Some (STR ''1.146e+04''),
    \<not> answers (RGeol (GlAge HlNone (MFrac (1 / 4)))),
    \<not> answers (RGeol (GlAge (HlIso C14) (MFrac (13 / 10)))),
    stated (reply_of (RSeis (SeEnergy 6 4))) = Some (STR ''1000''),
    stated (reply_of (RSeis (SeMw (11 / 10 * 10 ^ 21)))) = Some (STR ''7.961''),
    stated (reply_of (RSeis (SeSP (Some 8) (Some (29 / 5)) (Some (17 / 5))))) = Some (STR ''65.73''),
    stated (reply_of (RSeis (SeGR (Some 6) (Some 1) (Some 5)))) = Some (STR ''10''),
    \<not> answers (RSeis (SeAsk 7 5)),
    \<not> answers (RSeis (SeSP (Some 30) None None)),
    stated (reply_of (RHydro (HyRational (Some (1 / 2)) (Some 2) (Some 10) IIn AAcre))) = Some (STR ''10''),
    stated (reply_of (ROcean (OTsunamiSpeed 1000))) = Some (STR ''99.05''),
    stated (reply_of (RWeather (WDew (Some 25) TsC (Some 60)))) = Some (STR ''16.69''),
    stated (reply_of (RWeather (WHeat (Some 90) TsF (Some 70)))) = Some (STR ''105.9''),
    stated (reply_of (RWeather (WChill (Some 20) TsF (Some 15) WMph))) = Some (STR ''6.219''),
    stated (reply_of (RWeather (WRH (Some 30) (Some 20) RhBoth))) = Some (STR ''55.1''),
    stated (reply_of (RWeather (WSaffir (Some 100) WMph))) = Some (STR ''2''),
    stated (reply_of (RWeather (WIsa (Some 3000) AltM True))) = Some (STR ''701.1''),
    reply_kind (reply_of (RWeather (WChill (Some 60) TsF (Some 20) WMph))) = STR ''wc_undefined'',
    answers (RWeather (WChill (Some 60) TsF (Some 20) WMph)),
    stated (reply_of (RGreen (GhVpd (Some 25) GC None GC (Some 60) True))) = Some (STR ''1.267''),
    stated (reply_of (RGreen (GhDli (Some 400) (Some 16)))) = Some (STR ''23.04''),
    render_dec 4 (1000, 1) = STR ''1e+04'',
    render_fixed 2 (782582, -2) = STR ''7825.82'',
    render_fixed 4 (114600000, -4) = STR ''11460'',
    render_comma (1000, 0) = STR ''1,000'',
    render_comma (1234567, 0) = STR ''1,234,567'',
    render_sci3 (5623, 19) = STR ''5.623e+22'']"

definition self_test :: bool where
  "self_test \<longleftrightarrow> list_all id self_tests"

export_code reply_of answered reply_kind response stated answers mk_rat self_test self_tests capital_known
  integer_of_int nat_of_integer int_of_integer
  RGeo RGeol RSeis RHydro ROcean RWeather RGreen
  GCapital GGc GAntipode GSolar GLat
  GlPlateDist GlPlateRate GlDepthTemp GlAge GlLeft HlNone HlGiven HlIso C14 K40 U238 U235 MRatio MFrac
  SeEnergy SeAmp SeAsk SeMw SeM0 SeSP SeGR
  HyRational HyHarvest HyManning HyFill HyCont IIn IMm AAcre AHa AKm2 HUS HSI HMix VGal VL VM3 TMin THour TSec
  OSonar OPressure OTsunamiSpeed OTsunamiTime ODeepSpeed ODeepWL
  WHeat WChill WDew WAirT WRH WSaffir WBeaufort WIsa TsF TsC WMph WKmh WMs WKn AltKm AltM AltFt RhBoth RhWhich
  GhVpd GhDli GhPpfd GhGdd GhPlants GC GF LCm LM LIn LFt GaM2 GaFt2
  in SML module_name Earth file_prefix earth

ML \<open>
  val theorems = [
    @{thm round_tie_up}, @{thm round_sig_sound}, @{thm to_dec_sound}, @{thm to_places_sound},
    @{thm round_layout_sound}, @{thm render_x_sound}, @{thm reply_val_states}, @{thm reply_with_states},
    @{thm decline_reply_withheld}, @{thm reply_withheld_has_no_value},
    @{thm central_angle}, @{thm hav_le_one}, @{thm gc_sound}, @{thm antipode_sound},
    @{thm antipode_involution}, @{thm solar_time_sound}, @{thm lat_distance_sound},
    @{thm capital_split_stated}, @{thm geo_answered_iff}, @{thm geo_declines_impossible},
    @{thm gl_underspecified}, @{thm gl_impossible_iff}, @{thm gl_value_sound}, @{thm gl_age_ratio_law},
    @{thm gl_age_fraction_law}, @{thm left_after_one_half_life}, @{thm left_composes},
    @{thm half_powr_log2}, @{thm ystr_opt_sound}, @{thm gl_answered_iff},
    @{thm seis_underspecified}, @{thm seis_impossible_iff}, @{thm seis_asks_back}, @{thm seis_value_sound},
    @{thm energy_is_amplitude_power}, @{thm amp_ratio_adds}, @{thm energy_ratio_adds},
    @{thm amp_ratio_two_units}, @{thm energy_ratio_two_units}, @{thm mw_of_m0_of}, @{thm m0_of_mw_of},
    @{thm sp_travel_times}, @{thm gr_log_count}, @{thm gr_decreases_with_magnitude}, @{thm seis_answered_iff},
    @{thm hy_underspecified}, @{thm hy_impossible_iff}, @{thm hy_value_sound}, @{thm manning_velocity},
    @{thm manning_cubed}, @{thm fill_time_times_flow}, @{thm rational_method_si}, @{thm hy_answered_iff},
    @{thm oc_impossible_iff}, @{thm oc_value_sound}, @{thm shallow_speed_squared},
    @{thm tsunami_time_times_speed}, @{thm deep_wavelength_is_speed_times_period},
    @{thm deep_speed_relation}, @{thm sonar_round_trip}, @{thm absolute_pressure_adds_atmosphere},
    @{thm oc_answered_iff},
    @{thm w_underspecified}, @{thm w_impossible_iff}, @{thm w_range_iff}, @{thm w_wind_chill_undefined},
    @{thm w_value_sound}, @{thm rnd_even_nearest}, @{thm ss_cat_monotone}, @{thm bft_force_monotone},
    @{thm ss_cat_hurricane_threshold}, @{thm dew_point_below_air}, @{thm dew_point_humidity_roundtrip},
    @{thm w_answered_iff},
    @{thm gh_underspecified}, @{thm gh_impossible_iff}, @{thm gh_value_sound},
    @{thm vpd_air_complements_vapour_pressure}, @{thm vpd_leaf_difference}, @{thm saturation_pressure_positive},
    @{thm vpd_nonneg_at_leaf_equals_air}, @{thm dli_definition}, @{thm ppfd_needed_reaches_target},
    @{thm ppfd_inverts_dli}, @{thm gdd_nonneg}, @{thm plant_count_bounds}, @{thm gh_answered_iff}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("earth theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else
    error ("earth self test failed at items " ^ String.concatWith "," (map_filter I
      (map_index (fn (i, b) => if b then NONE else SOME (string_of_int i)) (@{code self_tests}))));
  val marker = "VERI7VN_EARTH PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0";
  val _ = writeln marker;
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/earth")) [XML.Text marker];
\<close>

end
