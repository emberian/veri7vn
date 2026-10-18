theory Life_Export
  imports Life_Core Genetics Biology Ecology Forestry Wildlife Micro
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition st0 :: bool where
  "st0 \<longleftrightarrow>
     g_kernel (G_Geno [(Locus (STR ''B'') (STR ''b'') Het, Locus (STR ''B'') (STR ''b'') Het, Hom_dom)])
        = Exact (STR ''genotype_prob'') (1 / 4)"

definition st1 :: bool where
  "st1 \<longleftrightarrow>
     g_kernel (G_Geno [(Locus (STR ''A'') (STR ''a'') Het, Locus (STR ''A'') (STR ''a'') Het, Het),
                       (Locus (STR ''B'') (STR ''b'') Het, Locus (STR ''B'') (STR ''b'') Het, Het)])
        = Exact (STR ''genotype_prob'') (1 / 4)"

definition st2 :: bool where
  "st2 \<longleftrightarrow>
     g_kernel (G_Pheno True (Locus (STR ''A'') (STR ''a'') Het) (Locus (STR ''A'') (STR ''a'') Het))
        = Exact (STR ''phenotype_prob'') (3 / 4)"

definition st3 :: bool where
  "st3 \<longleftrightarrow>
     g_kernel (G_PRatio [(Locus (STR ''A'') (STR ''a'') Het, Locus (STR ''A'') (STR ''a'') Het)])
        = Ratio (STR ''pheno_ratio'') [3, 1]"

definition st4 :: bool where
  "st4 \<longleftrightarrow>
     g_kernel (G_PRatio [(Locus (STR ''A'') (STR ''a'') Het, Locus (STR ''a'') (STR ''a'') Hom_rec),
                         (Locus (STR ''B'') (STR ''b'') Het, Locus (STR ''b'') (STR ''b'') Hom_rec)])
        = Ratio (STR ''pheno_ratio'') [1, 1, 1, 1]"

definition st5 :: bool where
  "st5 \<longleftrightarrow>
     g_kernel (G_GRatio (Locus (STR ''A'') (STR ''a'') Het) (Locus (STR ''A'') (STR ''a'') Het))
        = Ratio (STR ''geno_ratio'') [1, 2, 1]"

definition st6 :: bool where
  "st6 \<longleftrightarrow>
     g_kernel (G_HW HK_q (HWqs (3 / 10))) = Exact (STR ''hw_q'') (3 / 10)"

definition st7 :: bool where
  "st7 \<longleftrightarrow>
     g_kernel (G_HW HK_q (HWq2 (6 / 5))) = Decline (Impossible R_freq)"

definition st8 :: bool where
  "st8 \<longleftrightarrow>
     stated (g_reply (G_HW HK_q (HWq2 (4 / 100)))) = Some (STR ''0.2'')"

definition st9 :: bool where
  "st9 \<longleftrightarrow>
     stated (g_reply (G_HW HK_carrier (HWone 400))) = Some (STR ''0.095'')"

definition st10 :: bool where
  "st10 \<longleftrightarrow>
     b_kernel (Bio Op_codon [NC, NC, NG]) = Amino (STR ''codon'') (CHR ''P'')"

definition st11 :: bool where
  "st11 \<longleftrightarrow>
     b_kernel (Bio Op_revcomp [NA, NT, NG, NC, NG, NT]) = Bases (STR ''revcomp'') [NA, NC, NG, NC, NA, NT]"

definition st12 :: bool where
  "st12 \<longleftrightarrow>
     b_kernel (Bio Op_translate [NA, NU, NG, NG, NG, NC, NU, NU, NU, NU, NG, NA])
        = Prot (STR ''translate'') (''MGF'')"

definition st13 :: bool where
  "st13 \<longleftrightarrow>
     b_kernel (Bio Op_translate [NA, NT, NG, NG, NC, NC, NT, NT]) = Decline (Impossible R_frame)"

definition st14 :: bool where
  "st14 \<longleftrightarrow>
     b_kernel (Bio Op_complement [NA, NT, NU]) = Decline (Impossible R_both)"

definition st15 :: bool where
  "st15 \<longleftrightarrow>
     stated (b_reply (Bio Op_gc [NT, NT, NT, NA, NC, NC, NG, NG])) = Some (STR ''50'')"

definition st16 :: bool where
  "st16 \<longleftrightarrow>
     e_kernel (E_SimpDiv [80, 10, 5, 5]) = Exact (STR ''simpson_div'') (23 / 66)"

definition st17 :: bool where
  "st17 \<longleftrightarrow>
     e_kernel (E_LogRate (1 / 10) 250 500) = Exact (STR ''logistic_rate'') (25 / 2)"

definition st18 :: bool where
  "st18 \<longleftrightarrow>
     e_kernel (E_Evenness [7]) = Decline (Impossible R_one_species)"

definition st19 :: bool where
  "st19 \<longleftrightarrow>
     stated (e_reply (E_Shannon [12, 8, 6, 3, 1])) = Some (STR ''1.385'')"

definition st20 :: bool where
  "st20 \<longleftrightarrow>
     stated (e_reply (E_ExpN (1 / 10) 100 5)) = Some (STR ''164.9'')"

definition st21 :: bool where
  "st21 \<longleftrightarrow>
     f_kernel (F_Doyle 14 8) = Exact (STR ''doyle'') 50"

definition st22 :: bool where
  "st22 \<longleftrightarrow>
     f_kernel (F_Doyle 4 12) = Decline (Impossible R_doyle)"

definition st23 :: bool where
  "st23 \<longleftrightarrow>
     stated (f_reply (F_Height 100 30 None True)) = Some (STR ''57.74'')"

definition st24 :: bool where
  "st24 \<longleftrightarrow>
     stated (f_reply (F_BAm 60)) = Some (STR ''0.2827'')"

definition st25 :: bool where
  "st25 \<longleftrightarrow>
     w_kernel (W_Lincoln (Some 30) (Some 25) (Some 5) False) = Exact (STR ''lincoln'') 150"

definition st26 :: bool where
  "st26 \<longleftrightarrow>
     w_kernel (W_Lincoln (Some 50) (Some 40) (Some 0) False) = Decline (Impossible R_no_recapture)"

definition st27 :: bool where
  "st27 \<longleftrightarrow>
     w_kernel (W_Surv 150 200 True) = Exact (STR ''mortality'') 25"

definition st28 :: bool where
  "st28 \<longleftrightarrow>
     m_kernel (M_Serial 10 6) = Exact (STR ''serial'') 1000000"

definition st29 :: bool where
  "st29 \<longleftrightarrow>
     m_kernel (M_GrowthN 500 30 180) = Exact (STR ''growth_n'') 32000"

definition st30 :: bool where
  "st30 \<longleftrightarrow>
     m_kernel (M_GenTime 100 6400 180) = Exact (STR ''gen_time'') 30"

definition st31 :: bool where
  "st31 \<longleftrightarrow>
     m_kernel (M_GenTime 5000 1000 120) = Decline (Impossible R_final_below)"

definition st32 :: bool where
  "st32 \<longleftrightarrow>
     stated (m_reply (M_CFU 87 (1 / 10000000) (1 / 10))) = Some (STR ''8700000000'')"

definition self_test :: bool where
  "self_test \<longleftrightarrow> st0 \<and> st1 \<and> st2 \<and> st3 \<and> st4 \<and> st5 \<and> st6 \<and> st7 \<and> st8 \<and> st9 \<and> st10 \<and> st11 \<and> st12 \<and> st13 \<and> st14 \<and> st15 \<and> st16 \<and> st17 \<and> st18 \<and> st19 \<and> st20 \<and> st21 \<and> st22 \<and> st23 \<and> st24 \<and> st25 \<and> st26 \<and> st27 \<and> st28 \<and> st29 \<and> st30 \<and> st31 \<and> st32"


export_code bio_input bio_model_reply g_reply b_reply e_reply f_reply w_reply m_reply
  answered reply_kind response stated mk_rat
  integer_of_int nat_of_integer int_of_integer
  Hom_dom Het Hom_rec Locus G_Geno G_Pheno G_PRatio G_GRatio G_HW G_Need G_Model
  HK_carrier HK_p2 HK_p HK_q HWq2 HWone HWqs HWps
  NA NC NG NT NU Op_codon Op_gc Op_revcomp Op_complement Op_transcribe Op_translate Op_protlen Bio
  E_Shannon E_Evenness E_SimpD E_SimpDiv E_SimpInv E_Richness E_LogRate E_LogN E_ExpN E_Doubling E_Geom
  F_Doyle F_Smalian F_Tpa F_Height F_BA F_BAPA F_BAm
  W_Lincoln W_Density W_Surv
  M_CFU M_Serial M_GrowthN M_Gens M_GenTime M_Unread
  in SML module_name Life file_prefix life

ML \<open>
  val theorems = [@{thm round_sig_sound}, @{thm to_dec_sound}, @{thm num_dec_sound}, @{thm fixed_dec_sound},
    @{thm enclose_sound},
    @{thm reply_withheld_names_decline}, @{thm reply_answered_not_decline}, @{thm reply_states_exact},
    @{thm reply_states_approx},
    @{thm punnett_closed}, @{thm punnett_total}, @{thm gprob_total_one_locus}, @{thm pclasses_sum},
    @{thm ratio_proportional}, @{thm hw_sum_one}, @{thm geno_prob_value}, @{thm genotype_independent_composition}, @{thm pheno_prob_complement},
    @{thm pheno_ratio_value}, @{thm geno_ratio_value}, @{thm hw_exact}, @{thm hw_approx},
    @{thm hw_impossible}, @{thm hw_imprecise}, @{thm need_declines}, @{thm unsupported_model_declines},
    @{thm revcomp_involutive}, @{thm transcription_inverse}, @{thm protein_length_bound},
    @{thm protein_has_no_stop}, @{thm gc_val_bounds}, @{thm gc_val_defining}, @{thm bio_mixed_declines},
    @{thm bio_codon}, @{thm bio_complement}, @{thm bio_revcomp}, @{thm bio_transcribe},
    @{thm bio_model_declines}, @{thm bio_input_template_backwards}, @{thm bio_input_coding_backwards},
    @{thm bio_input_preserves_length}, @{thm bio_input_orientation_invariance},
    @{thm bio_translate}, @{thm bio_translate_frame}, @{thm bio_gc},
    @{thm e_impossible}, @{thm e_imprecise}, @{thm simpson_d_value}, @{thm simpson_div_value},
    @{thm simpson_inv_value}, @{thm richness_value}, @{thm logistic_rate_value},
    @{thm logistic_rate_at_capacity}, @{thm geometric_exact}, @{thm ecology_approx},
    @{thm doubling_declines_iff}, @{thm logistic_n_declines_iff}, @{thm shannon_declines_iff},
    @{thm evenness_zero_declines_iff}, @{thm doubling_phys}, @{thm logistic_phys_start},
    @{thm logistic_phys_capacity}, @{thm exp_phys_start}, @{thm shannon_gibbs}, @{thm evenness_range},
    @{thm shannon_kernel_range}, @{thm doubling_kernel_bound},
    @{thm doyle_declines_iff}, @{thm tpa_declines_iff}, @{thm height_declines_iff},
    @{thm cfu_declines_iff}, @{thm gens_declines_iff}, @{thm gentime_final_below_iff}, @{thm gentime_zero_iff},
    @{thm hw_q2_declines_iff}, @{thm hw_qs_declines_iff}, @{thm hw_ps_declines_iff}, @{thm hw_one_declines_iff},
    @{thm gc_count_le},
    @{thm f_impossible}, @{thm f_imprecise}, @{thm doyle_value}, @{thm doyle_declines_small},
    @{thm smalian_value}, @{thm smalian_cylinder}, @{thm tpa_value}, @{thm basal_area_value},
    @{thm ba_per_acre_value}, @{thm forestry_approx}, @{thm height_angle_range},
    @{thm lincoln_underspecified}, @{thm lincoln_estimate}, @{thm chapman_estimate},
    @{thm lincoln_impossible}, @{thm density_value}, @{thm survival_value}, @{thm survival_mortality_sum},
    @{thm m_imprecise}, @{thm unread_declines}, @{thm cfu_value}, @{thm serial_value},
    @{thm serial_composes}, @{thm generations_value}, @{thm growth_exact}, @{thm growth_approx},
    @{thm gentime_exact}, @{thm gentime_approx}, @{thm gentime_declines_shrinking}]
    @ @{thms pheno_prob_value};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("life theorems use oracles: " ^ string_of_int (length oracles));
  val st = [(0, @{code st0}), (1, @{code st1}), (2, @{code st2}), (3, @{code st3}), (4, @{code st4}), (5, @{code st5}), (6, @{code st6}), (7, @{code st7}), (8, @{code st8}), (9, @{code st9}), (10, @{code st10}), (11, @{code st11}), (12, @{code st12}), (13, @{code st13}), (14, @{code st14}), (15, @{code st15}), (16, @{code st16}), (17, @{code st17}), (18, @{code st18}), (19, @{code st19}), (20, @{code st20}), (21, @{code st21}), (22, @{code st22}), (23, @{code st23}), (24, @{code st24}), (25, @{code st25}), (26, @{code st26}), (27, @{code st27}), (28, @{code st28}), (29, @{code st29}), (30, @{code st30}), (31, @{code st31}), (32, @{code st32})];
  val bad = map fst (filter (not o snd) st);
  val _ = if null bad then () else error ("life self test failed at " ^ String.concatWith "," (map string_of_int bad));
  val _ = writeln ("VERI7VN_LIFE PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
