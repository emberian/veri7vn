theory Acoustics_Export
  imports Acoustics
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition mk_nat :: "integer \<Rightarrow> nat" where
  "mk_nat k = nat_of_integer k"

text \<open>Diagnostics only: the raw float enclosure of a request's model value,
as (mantissa, exponent) pairs, at a given precision.\<close>
definition debug_enclosure :: "nat \<Rightarrow> request \<Rightarrow> ((int \<times> int) \<times> (int \<times> int)) option" where
  "debug_enclosure p r = map_option (\<lambda>X. ((mantissa (lower X), exponent (lower X)),
     (mantissa (upper X), exponent (upper X)))) (approx p (expr_of r) [])"

definition debug_approx :: "nat \<Rightarrow> floatarith \<Rightarrow> ((int \<times> int) \<times> (int \<times> int)) option" where
  "debug_approx p e = map_option (\<lambda>X. ((mantissa (lower X), exponent (lower X)),
     (mantissa (upper X), exponent (upper X)))) (approx p e [])"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (SpeedAir (AirAt 0)) = Value K_speed (3313, -1) \<and>
     render_dec 4 (3313, -1) = STR ''331.3'' \<and>
     render_dec 4 (4673, -1) = STR ''467.3'' \<and>
     render_dec 4 (7800, -4) = STR ''0.78'' \<and>
     render_dec 4 (1000, 1) = STR ''1e+04'' \<and>
     render_dec 4 (2000, -3) = STR ''2'' \<and>
     kernel (Doppler (Some 500) (Some 400) Source Toward AirDefault) = Decline (Impossible Shock_Wave) \<and>
     kernel (PipeClosed 2 (Some (1, Metre)) AirDefault) = Decline (Impossible (Even_Closed_Harmonic 2)) \<and>
     kernel (OutsideModel Moving_Medium) = Decline (UnsupportedModel Moving_Medium) \<and>
     kernel (DopplerBoth 500 30 Toward 10 Toward (Stated 330)) = Value K_doppler (5667, -1) \<and>
     kernel (DopplerBoth 500 0 Toward 330 Away (Stated 330)) = Value K_doppler (0, 0) \<and>
     kernel (Beat (Some 440) None) = Decline (Underspecified Both_Frequencies) \<and>
     kernel (Beat (Some 440) (Some 442)) = Value K_beat (2000, -3)"

export_code reply_of answered reply_kind response stated mk_rat mk_nat debug_enclosure debug_approx integer_of_int nat_of_integer int_of_integer Float floatarith.Num floatarith.Mult floatarith.Add floatarith.Inverse floatarith.Ln floatarith.Sqrt floatarith.Powr floatarith.Exp expr_of
  Beat Doppler DopplerBoth OutsideModel Moving_Medium Motion_Domain Unbound_Motion DbSum DbTwoEqual DbDistance DbRatio IntensityRatio StringHarmonic
  PipeClosed PipeOpen Wavelength Frequency SpeedAir SpeedWater
  Toward Away Unclear Source Listener Metre Centimetre Hz KHz Stated AirAt AirDefault
  in SML module_name Acoustics file_prefix acoustics

ML \<open>
  val theorems = [@{thm kernel_value_sound}, @{thm kernel_underspecified},
    @{thm kernel_impossible}, @{thm kernel_imprecise}, @{thm reason_of_exact},
    @{thm expr_of_meaning}, @{thm to_dec_sound}, @{thm reach_iff},
    @{thm doppler_source_toward}, @{thm doppler_source_away},
    @{thm doppler_listener_toward}, @{thm doppler_listener_away},
    @{thm doppler_supersonic_source_declined}, @{thm db_sum_intensities},
    @{thm db_two_equal_intensities}, @{thm db_distance_inverse_square},
    @{thm db_ratio_intensity}, @{thm intensity_ratio_levels}, @{thm string_harmonic},
    @{thm pipe_closed_harmonic}, @{thm pipe_open_harmonic}, @{thm pipe_closed_answers_odd},
    @{thm wavelength_relation}, @{thm frequency_relation}, @{thm speed_air_square},
    @{thm speed_air_freezing}, @{thm reply_answered_iff}, @{thm reply_states_kernel_value},
    @{thm answered_reply_model_bound}, @{thm pipe_open_closed_consistent},
    @{thm db_sum_not_quieter}, @{thm enclose_retry_sound},
    @{thm at_sound_iff}, @{thm speed_squared_correct}, @{thm outside_model_declined},
    @{thm doppler_both_returned}, @{thm doppler_both_source_returned},
    @{thm doppler_both_listener_returned}, @{thm doppler_both_stationary_returned},
    @{thm doppler_both_denominator}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("acoustics theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "acoustics self test failed";
  val _ = writeln ("VERI7VN_ACOUSTICS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
