theory Trades_Export
  imports Trades
begin

(* W6-24: the oracle scan below covers the colour and lumber laws. *)

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (Far 36000 12000) = Exact K_far 3 \<and>
     kernel (Occupant 4500 (Table O_business)) = Exact K_occupant 30 \<and>
     kernel (Occupant 900 (Table O_classroom)) = Exact K_occupant 45 \<and>
     kernel (Occupant 5000 (Given 150)) = Exact K_occupant 34 \<and>
     kernel (Egress 4500 (Table O_business) True) = Exact K_egress 9 \<and>
     kernel (Ramp 30 False) = Exact K_ramp 30 \<and>
     kernel (Layers (Some 180) (Some (1 / 5))) = Exact K_layers 900 \<and>
     kernel (Shrink (Some 5)) = Exact K_shrink (20 / 19) \<and>
     kernel (Shrink None) = Decline (Underspecified N_shrink) \<and>
     kernel (Shrink (Some 100)) = Decline (Impossible R_shrink_range) \<and>
     kernel (Ladder (Some 8) L_ft) = Exact K_ladder 2 \<and>
     kernel (Miter 4) = Exact K_miter 45 \<and>
     kernel (Miter 2) = Decline (Impossible R_few_sides) \<and>
     kernel (ActualSize 2 4) = Duo K_actual_size (3 / 2) (7 / 2) \<and>
     kernel (ActualSize 2 5) = Decline (Impossible R_nominal_size) \<and>
     kernel (Moisture 150 100) = Exact K_wood_mc 50 \<and>
     kernel (MixRyb C_red C_yellow) = Hue K_mix_ryb C_orange \<and>
     kernel (Rows 28 4 True 12 True) = Exact K_rows 84 \<and>
     kernel (Rows 28 0 True 12 True) = Decline (Impossible R_gauge_dimensions) \<and>
     kernel (Rows 5 2 True 1 True) = Exact K_rows 2 \<and>
     kernel (CastOn (9 / 2) True 3 True) = Exact K_cast_on 14 \<and>
     kernel (CastOn (5 / 2) True 1 True) = Exact K_cast_on 2 \<and>
     kernel (Drywall 100 0 S32) = Exact K_drywall 4 \<and>
     kernel (Stairs 108 False False) = Exact K_risers 14 \<and>
     kernel Judge = Decline Judgement \<and>
     kernel (Niosh (Some 25) (Some 75) (Some 25) (Some 0) (Some 1) (Some 1) None) = Exact K_rwl 23 \<and>
     stated (reply_of (Far 36000 12000)) = Some (STR ''3'') \<and>
     stated (reply_of (MaxFloor (7 / 2) 8000)) = Some (STR ''28000'') \<and>
     stated (reply_of (Cost 100 (Per_kg 20))) = Some (STR ''2.00'') \<and>
     stated (reply_of (Flow (Some (1 / 5)) (Some (2 / 5)) (Some 50))) = Some (STR ''4'') \<and>
     show_commas 1234567 = STR ''1,234,567'' \<and>
     stated (reply_of (NoiseTime 85)) = Some (STR ''16'') \<and>
     stated (reply_of (NoiseDose [92, 100] [5, 3])) = Some (STR ''232.5'') \<and>
     stated (reply_of (Twa [92, 100] [5, 3])) = Some (STR ''96.09'') \<and>
     stated (reply_of (Pitch 4)) = Some (STR ''18.435'') \<and>
     stated (reply_of (Rafter 6 10 True)) = Some (STR ''11.18'') \<and>
     stated (reply_of (FilMass 10 (Some (175 / 100)) (D_typical F_pla))) = Some (STR ''29.83'') \<and>
     stated (reply_of (FilLength 100 (Some (175 / 100)) (D_typical F_pla))) = Some (STR ''33.53'')"

export_code reply_of answered reply_kind response stated mk_rat
  integer_of_int nat_of_integer int_of_integer
  use_order fil_order input_colours
  Far MaxFloor Coverage Occupant Egress Ramp Shrink Layers Flow Cost FilLength FilMass NoiseTime
  NoiseDose Twa Ladder Niosh Judge ActualSize BoardFeet Concrete Drywall Stairs Rafter Pitch Miter
  Moisture MixRyb MixRgb Complement Rows CastOn Quilt CutSize Yards Mat Clay
  C_red C_yellow C_blue C_green C_orange C_purple C_violet
  Given Table D_given D_typical D_none Per_kg Per_spool L_ft L_m S32 S40 S48 CU_in CU_quote CU_cm CU_mm
  in SML module_name Trades file_prefix trades

ML \<open>
  val theorems = [@{thm kernel_exact_sound}, @{thm kernel_duo_sound}, @{thm kernel_hue_sound},
    @{thm kernel_approx_sound}, @{thm kernel_underspecified}, @{thm kernel_impossible},
    @{thm kernel_judgement}, @{thm kernel_imprecise}, @{thm reason_of_exact},
    @{thm expr_of_meaning}, @{thm round_he_spec}, @{thm ceil_eps_cover}, @{thm floor_eps_fit},
    @{thm round_at_error}, @{thm round_sig_sound}, @{thm to_dec_sound}, @{thm to_fixed_sound},
    @{thm enclose_m_sound}, @{thm stated_dec_sound}, @{thm round_tie_up},
    @{thm mix_symmetric}, @{thm complement_involution}, @{thm complement_violet_exception},
    @{thm actual_below_nominal}, @{thm rows_unit_invariant}, @{thm rows_nearest},
    @{thm rafter_pythagoras}, @{thm pitch_tan}, @{thm noise_halving}, @{thm egress_widths},
    @{thm reply_answered_iff}, @{thm reply_states_exact}, @{thm reply_states_approx},
    @{thm reply_withheld_names_decline}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("trades theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "trades self test failed";
  val _ = writeln ("VERI7VN_TRADES PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
