theory AnatomyAgri_Export
  imports AnatomyAgri
begin

text \<open>Constructor for the untrusted recognizer: a decimal numeral it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     response (reply_of (Count C_bones)) = STR ''There are 206 bones in the adult human skeleton.'' \<and>
     stated (reply_of (Count C_bones)) = Some (STR ''206'') \<and>
     response (reply_of (Superlative S_bone_smallest)) = STR ''It is the stapes (in the middle ear).'' \<and>
     stated (reply_of (Produces P_melatonin)) = Some (dq + STR ''pineal gland'' + dq) \<and>
     response (reply_of (FertProduct Nit 46 0 0 60)) =
       STR ''Apply 130.435 lb of product per acre (60 lb N / 46% N in 46-0-0).'' \<and>
     kernel (FertProduct Pho 0 46 0 100) = Value (10000 / 46) \<and>
     kernel (FertProduct Nit 0 46 0 100) = Decline (Impossible R_no_nutrient) \<and>
     kernel (SeedsNeeded 120 30000) = Decline (Impossible R_germination) \<and>
     response (reply_of (SeedsPerAcre 15 2)) =
       STR ''That is 209,088 seeds per acre (6,272,640 sq in / (15 in rows x 2 in spacing)).'' \<and>
     g3 (104544) = STR ''104,544'' \<and> g3 (1234567) = STR ''1,234,567'' \<and> g3 (1 / 3) = STR ''0.333'' \<and>
     g3 0 = STR ''0'' \<and> g3 (1 / 1000) = STR ''0.001'' \<and> g2 (2 / 5) = STR ''0.4'' \<and>
     stated (reply_of (GardenGrid 6 3 9)) = Some (STR ''32'') \<and>
     stated (reply_of (GardenBags (Dims 4 4) (Inches 8) 1)) = Some (STR ''11'') \<and>
     stated (reply_of (GardenFeet (Dims 4 4) (Inches 8))) = Some (STR ''10.667'') \<and>
     stated (reply_of (BmiMetric 85 (Mcm 175) True)) = Some (dq + STR ''overweight'' + dq) \<and>
     stated (reply_of (BmiImperial 200 (Ftin 6 0) False)) = Some (STR ''27.12'') \<and>
     stated (reply_of (Kcal 25 0 15 0)) = Some (STR ''235'') \<and>
     stated (reply_of (PctDV AddSug 14 U_g)) = Some (STR ''28'') \<and>
     stated (reply_of (PctDV Iron 260 U_mg)) = Some (STR ''1444.44'') \<and>
     stated (reply_of (PctFatCal 3 150)) = Some (STR ''18'') \<and>
     \<not> answered (reply_of (PctDV VitD 5 U_g))"

export_code reply_of answered reply_kind response stated answers mk_rat self_test
  nat_of_integer integer_of_nat count_order super_order made_order crop_order dv_order
  Count CountAt AdultStage DevelopingStage NewbornStage Superlative Produces FertProduct NutrientLb SeedsPerAcre SeedsNeeded Yield AcreInch
  AgriUnderspecified GardenWater GardenFert GardenGrid GardenRectGrid GardenNeedOrientation GardenBags GardenYards GardenFeet
  BmiMetric BmiImperial Kcal PctFatCal PctDV NutUnderspecified
  Nit Pho Pot KgHa THa Dims Area Inches Feet Mm Mcm Iin Ftin U_mg U_g U_mcg
  in SML module_name AnatomyAgri file_prefix anatomyagri

ML \<open>
  val theorems = [@{thm lval_digits}, @{thm rnd_sound}, @{thm rnd_nat},
    @{thm anatomy_counts_consistent}, @{thm agri_constants_grounded}, @{thm water_constant_grounded},
    @{thm unit_factor_inverse}, @{thm bmi_category_exact}, @{thm bmi_const_grounded},
    @{thm kernel_underspecified}, @{thm kernel_impossible}, @{thm kernel_total}, @{thm kernel_decline_iff},
    @{thm count_value}, @{thm count_stage_narrows}, @{thm count_stage_declines_iff},
    @{thm newborn_bones_declines}, @{thm adult_bones_preserved}, @{thm superlative_label}, @{thm produces_label},
    @{thm fert_product}, @{thm nutrient_lb}, @{thm fert_roundtrip}, @{thm fert_no_nutrient},
    @{thm seeds_per_acre}, @{thm seeds_needed}, @{thm seeds_needed_germination},
    @{thm yield_kgha}, @{thm yield_tha}, @{thm acre_inch(1)}, @{thm acre_inch(2)},
    @{thm garden_water}, @{thm garden_fert}, @{thm fit_floor}, @{thm garden_grid}, @{thm garden_grid_fits}, @{thm garden_rect_grid_fits},
    @{thm seeds_needed_declines_iff}, @{thm acre_inch_derived_error},
    @{thm bags_cover}, @{thm garden_bags}, @{thm garden_yards}, @{thm garden_feet},
    @{thm bmi_metric}, @{thm bmi_imperial}, @{thm bmi_category_agrees}, @{thm bmi_category_agrees_imperial},
    @{thm kcal_value}, @{thm kcal_atwater_unit}, @{thm kcal_underspecified},
    @{thm pct_fat_cal}, @{thm pct_dv}, @{thm pct_dv_units},
    @{thm reply_answered_iff}, @{thm reply_states_value}, @{thm reply_states_label},
    @{thm count_stated_exact}, @{thm reply_withheld_names_decline}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("anatomyagri theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "anatomyagri self test failed";
  val _ = writeln ("VERI7VN_ANATOMYAGRI PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
