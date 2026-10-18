theory GeoStats_Export
  imports GeoStats_Geometry GeoStats_Stats
begin

(* W6-15: marker and oracle scan are the last commands; every headline theorem is listed. *)

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition mk_nat :: "integer \<Rightarrow> nat" where
  "mk_nat k = nat_of_integer k"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     g_kernel (G_rect_area (Some 12) (Some 11)) = GExact GK_rect_area 132 \<and>
     g_kernel (G_leg 3 (Some 3)) = GDecline (GImpossible GR_leg_ge_hyp) \<and>
     g_kernel (G_circle_area None) = GDecline (GUnderspecified GN_radius) \<and>
     g_kernel (G_angle_sum 9) = GCount GK_angle_sum 1260 \<and>
     g_kernel (G_angle_sum 2) = GDecline (GImpossible GR_few_sides) \<and>
     g_kernel (G_heron 2 3 8) = GDecline (GImpossible GR_triangle_inequality) \<and>
     g_kernel (G_box_volume (Some 2) (Some 3) None) = GDecline (GUnderspecified GN_height) \<and>
     render_dec 6 (314159, -5) = STR ''3.14159'' \<and>
     render_dec 6 (1000000, 0) = STR ''1e+06'' \<and>
     stated (g_reply (G_hypotenuse 5 12)) = Some (STR ''13'') \<and>
     stated (g_reply (G_circle_area (Some 2))) = Some (STR ''12.5664'') \<and>
     stated (g_reply (G_heron 3 4 5)) = Some (STR ''6'') \<and>
     stated (g_reply (G_rect_area (Some 8) (Some 2))) = Some (STR ''16'') \<and>
     stated (g_reply (G_angle_sum 5)) = Some (STR ''540'') \<and>
     response (g_reply (G_angle_sum 5)) =
       STR ''The interior angles of a 5-sided polygon add up to 540 degrees ((n - 2) x 180).'' \<and>
     s_kernel (S_mean [1, 2, 3, 4] True) = SRat SK_mean (5 / 2) \<and>
     response (s_reply (S_mean [1, 2, 3, 4] True)) =
       STR ''The mean of 1, 2, 3, 4 is 2.5 (sum 10 / 4) (exactly 5/2).'' \<and>
     s_kernel (S_median [1, 3, 2] False) = SRat SK_median 2 \<and>
     s_kernel (S_median [4, 1, 3, 2] False) = SRat SK_median (5 / 2) \<and>
     s_kernel (S_range [4, 1, 3, 2]) = SRat SK_range 3 \<and>
     s_kernel (S_mode [1, 2, 2, 3]) = SModes [2] \<and>
     s_kernel (S_mode [1, 2, 3]) = SNoMode \<and>
     s_kernel (S_variance False [5]) = SDecline STooFew \<and>
     stated (s_reply (S_stdev False [2, 4, 4, 4, 5, 5, 7, 9])) = Some (STR ''2.1381'') \<and>
     stated (s_reply (S_stdev True [2, 4, 4, 4, 5, 5, 7, 9])) = Some (STR ''2'') \<and>
     s_kernel (S_choose 5 12 True) = SDecline (SImpossible SR_choose_k_gt_n) \<and>
     s_kernel (S_choose 9 2 True) = SCount SK_combinations 36 \<and>
     s_kernel (S_arrange 8 (Some 5) True) = SCount SK_permutations 6720 \<and>
     s_kernel (S_arrange 5 None False) = SCount SK_permutations 120 \<and>
     stated (s_reply (S_binom 7 7 (1 / 2) True)) = Some (STR ''0.0078125'') \<and>
     stated (s_reply (S_z 44 61 12)) = Some (STR ''-1.4167'') \<and>
     s_kernel (S_z 44 61 0) = SDecline (SImpossible SR_nonpositive_sd)"

export_code g_reply s_reply answered reply_kind response stated mk_rat mk_nat self_test
  integer_of_int nat_of_integer int_of_integer
  G_circle_area G_circumference G_sphere_volume G_sphere_surface G_cylinder_volume G_cylinder_surface
  G_cone_volume G_cube_volume G_cube_surface G_box_volume G_rect_area G_rect_perimeter G_square_area
  G_square_perimeter G_tri_area G_heron G_hypotenuse G_leg G_angle_sum
  S_mean S_median S_mode S_range S_variance S_stdev S_choose S_arrange S_binom S_z
  in SML module_name GeoStats file_prefix geostats

ML \<open>
  val theorems = [@{thm g_exact_sound}, @{thm g_approx_value}, @{thm g_count_value},
    @{thm g_underspecified}, @{thm g_impossible}, @{thm g_imprecise},
    @{thm cube_volume_value}, @{thm cube_surface_value}, @{thm box_volume_value},
    @{thm rect_area_value}, @{thm rect_perimeter_value}, @{thm square_area_value},
    @{thm square_perimeter_value}, @{thm tri_area_value}, @{thm angle_sum_value},
    @{thm angle_sum_impossible}, @{thm circle_area_value}, @{thm circumference_value},
    @{thm sphere_volume_value}, @{thm sphere_surface_value}, @{thm cylinder_volume_value},
    @{thm cylinder_surface_value}, @{thm cone_volume_value}, @{thm hypotenuse_value},
    @{thm leg_value}, @{thm heron_value}, @{thm leg_decline_iff}, @{thm heron_decline_iff},
    @{thm g_dec_sound}, @{thm g_reply_answered_iff}, @{thm g_reply_states_exact},
    @{thm g_reply_states_approx}, @{thm g_reply_withheld_names_decline},
    @{thm s_rat_sound}, @{thm s_count_sound}, @{thm s_approx_sound}, @{thm s_no_data},
    @{thm s_too_few}, @{thm s_impossible}, @{thm s_imprecise}, @{thm too_few_iff},
    @{thm choose_impossible_iff}, @{thm binomial_impossible_iff}, @{thm z_impossible_iff},
    @{thm mean_value}, @{thm variance_population}, @{thm variance_sample}, @{thm stdev_value},
    @{thm median_halves(1)}, @{thm median_halves(2)}, @{thm median_order_free},
    @{thm median_between_extremes}, @{thm median_value}, @{thm range_value},
    @{thm modes_value}, @{thm mode_value}, @{thm choose_value}, @{thm arrange_value},
    @{thm arrange_all_value}, @{thm binomial_value}, @{thm z_value},
    @{thm s_reply_answered_iff}, @{thm s_reply_withheld_names_decline},
    @{thm s_reply_states_approx}, @{thm s_reply_states_rat},
    @{thm to_dec6_sound}, @{thm enc6_sound}, @{thm fix4_sound}, @{thm fix4_dec_sound},
    @{thm enc4_sound}, @{thm round_sig_sound},
    @{thm leg_missing}, @{thm circle_missing}, @{thm g_lengths_positive},
    @{thm cube_volume_nonpositive_iff}, @{thm cube_surface_nonpositive_iff},
    @{thm square_area_nonpositive_iff}, @{thm square_perimeter_nonpositive_iff},
    @{thm circle_area_nonpositive_iff}, @{thm rect_area_nonpositive_iff},
    @{thm box_volume_nonpositive_iff}, @{thm hypotenuse_nonpositive_iff}, @{thm leg_nonpositive_iff},
    @{thm box_volume_is_area_times_height}, @{thm cube_volume_is_area_times_edge},
    @{thm cube_surface_is_six_faces}, @{thm rect_area_is_two_triangles},
    @{thm square_perimeter_is_rect_perimeter}, @{thm angle_sum_step}, @{thm modes_complete}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("geostats theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "geostats self test failed";
  val _ = writeln ("VERI7VN_GEOSTATS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
