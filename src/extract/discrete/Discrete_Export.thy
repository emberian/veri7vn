theory Discrete_Export
  imports Discrete
begin

definition st0 :: bool where
  "st0 \<longleftrightarrow>
     response (reply_of (RGames (G_dice 2 6 7))) =
       [PS (STR ''The probability is 1/6 (16.6667%; 6 of the 36 equally likely outcomes of 2 d6 total 7).'')]"

definition st1 :: bool where
  "st1 \<longleftrightarrow>
     response (reply_of (RGames (G_dice 2 6 13))) =
       [PS (STR ''13 is not a possible total with 2 6-sided dice (range 2-12).'')]"

definition st2 :: bool where
  "st2 \<longleftrightarrow>
     \<not> answered (reply_of (RGames (G_dice 2 6 13)))"

definition st3 :: bool where
  "st3 \<longleftrightarrow>
     response (reply_of (RGames (G_poker False H_royal))) =
       [PS (STR ''The probability is 1/649740 (0.0002%; 4 of 2,598,960 five-card hands are a royal flush).'')]"

definition st4 :: bool where
  "st4 \<longleftrightarrow>
     response (reply_of (RGames (G_poker True H_flush))) =
       [PS (STR ''There are 5,108 flush hands (of 2,598,960 five-card hands).'')]"

definition st5 :: bool where
  "st5 \<longleftrightarrow>
     response (reply_of (RGames (G_anagram [77, 73, 83, 83, 73, 83, 83, 73, 80, 80, 73]))) =
       [PS (STR ''The number of distinct arrangements is 34,650 (11! / (4! x 4! x 2!) for ''),
        PB [77, 73, 83, 83, 73, 83, 83, 73, 80, 80, 73], PS (STR '').'')]"

definition st6 :: bool where
  "st6 \<longleftrightarrow>
     response (reply_of (RGames (G_card_k C_king 3 False))) =
       [PS (STR ''The probability is 1/5525 (0.0181%; 4/52 x 3/51 x 2/50, without replacement).'')]"

definition st7 :: bool where
  "st7 \<longleftrightarrow>
     response (reply_of (RGames (G_atleast 6 2 6))) =
       [PS (STR ''The probability is 11/36 (30.5556%; 11 of 36 equally likely roll sequences contain 6).'')]"

definition st8 :: bool where
  "st8 \<longleftrightarrow>
     response (reply_of (RLogic (L_formula (FEquiv (FImpl (FVar 15) (FVar 16)) (FImpl (FNeg (FVar 16)) (FNeg (FVar 15))))))) =
       [PS (STR ''It is a tautology (4 of 4 truth-table rows true).'')]"

definition st9 :: bool where
  "st9 \<longleftrightarrow>
     response (reply_of (RLogic (L_formula (FImpl (FDisj (FVar 15) (FVar 16)) (FVar 15))))) =
       [PS (STR ''It is contingent (3 of 4 truth-table rows true).'')]"

definition st10 :: bool where
  "st10 \<longleftrightarrow>
     response (reply_of (RLogic (L_argument [FImpl (FVar 15) (FVar 16), FVar 16] (FVar 15)))) =
       [PS (STR ''Invalid - the argument is invalid (counterexample: p=F, q=T makes every premise true and the conclusion false).'')]"

definition st11 :: bool where
  "st11 \<longleftrightarrow>
     response (reply_of (RLogic (L_argument [FImpl (FVar 15) (FVar 16), FVar 15] (FVar 16)))) =
       [PS (STR ''Valid - the argument is valid (no row of the 4-row truth table makes the premises true and the conclusion false).'')]"

definition st12 :: bool where
  "st12 \<longleftrightarrow>
     response (reply_of (RLogic (L_form F_da))) =
       [PS (STR ''This is denying the antecedent - an invalid argument, a formal fallacy (a counterexample row makes the premises true and the conclusion false).'')]"

definition st13 :: bool where
  "st13 \<longleftrightarrow>
     response (reply_of (RAlgos (A_sort [3, -1, 2, 2] False))) = [PS (STR ''Sorted ascending: -1, 2, 2, 3.'')]"

definition st14 :: bool where
  "st14 \<longleftrightarrow>
     response (reply_of (RAlgos (A_sort [3, -1, 2] True))) = [PS (STR ''Sorted descending: 3, 2, -1.'')]"

definition st15 :: bool where
  "st15 \<longleftrightarrow>
     response (reply_of (RAlgos (A_bsearch [1, 3, 5, 7] 5))) =
       [PS (STR ''The index is 2 (0-based), found in 2 probes.'')]"

definition st16 :: bool where
  "st16 \<longleftrightarrow>
     response (reply_of (RAlgos (A_bsearch [1, 3, 5, 7] 4))) =
       [PS (STR ''4 is not in the list (binary search ended after 2 probes).'')]"

definition st17 :: bool where
  "st17 \<longleftrightarrow>
     \<not> answered (reply_of (RAlgos (A_bsearch [5, 1, 8] 8)))"

definition st18 :: bool where
  "st18 \<longleftrightarrow>
     response (reply_of (RAlgos (A_sp [(STR ''A'', STR ''B'', 4), (STR ''B'', STR ''A'', 4), (STR ''B'', STR ''C'', 1),
         (STR ''C'', STR ''B'', 1), (STR ''A'', STR ''C'', 7), (STR ''C'', STR ''A'', 7)] 3 (STR ''A'') (STR ''C'')))) =
       [PS (STR ''The shortest path length is 5, via A -> B -> C (Dijkstra on the 3 edges you gave).'')]"

definition st19 :: bool where
  "st19 \<longleftrightarrow>
     response (reply_of (RAlgos (A_mst [(STR ''A'', STR ''B'', 4), (STR ''B'', STR ''C'', 1), (STR ''A'', STR ''C'', 7)]))) =
       [PS (STR ''The minimum spanning tree weight is 5 (2 edges, Kruskal on the edges you gave). The tree is B-C 1, A-B 4.'')]"

definition st20 :: bool where
  "st20 \<longleftrightarrow>
     response (reply_of (RCalc (C_deriv [(2, 3), (1, 2), (0, 1)] (STR ''x'') 1))) =
       [PS (STR ''The derivative is 6x + 2.'')]"

definition st21 :: bool where
  "st21 \<longleftrightarrow>
     response (reply_of (RCalc (C_deriv_at [(2, 3), (1, 2), (0, 1)] (STR ''x'') 1 2 False))) =
       [PS (STR ''The derivative at x = 2 is 14 (from 6x + 2).'')]"

definition st22 :: bool where
  "st22 \<longleftrightarrow>
     response (reply_of (RCalc (C_anti [(2, 3), (1, 2)] (STR ''x'')))) =
       [PS (STR ''The antiderivative is x^3 + x^2 + C.'')]"

definition st23 :: bool where
  "st23 \<longleftrightarrow>
     response (reply_of (RCalc (C_def [(2, 3)] (STR ''x'') 0 2))) =
       [PS (STR ''The integral from 0 to 2 is 8 (F(2) - F(0) with F = x^3).'')]"

definition st24 :: bool where
  "st24 \<longleftrightarrow>
     response (reply_of (RCalc (C_def [(1, 1)] (STR ''x'') 0 1))) =
       [PS (STR ''The integral from 0 to 1 is 1/2 ~ 0.5 (F(1) - F(0) with F = (1/2)x^2).'')]"

definition st25 :: bool where
  "st25 \<longleftrightarrow>
     response (reply_of (RFormats (F_base [102, 102] 16 2 [102, 102]))) =
       [PB [102, 102], PS (STR '' (base 16) is ''), PB [49, 49, 49, 49, 49, 49, 49, 49], PS (STR '' in base 2.'')]"

definition st26 :: bool where
  "st26 \<longleftrightarrow>
     \<not> answered (reply_of (RFormats (F_base [49, 50, 56, 57] 8 10 [49, 50, 56, 57])))"

definition st27 :: bool where
  "st27 \<longleftrightarrow>
     response (reply_of (RFormats (F_b64enc [77, 97, 110]))) =
       [PS ((STR '''' + Disc_Formats.dq + STR '''')), PB [77, 97, 110], PS ((STR '''' + Disc_Formats.dq + STR '' in base64 is '' + Disc_Formats.dq + STR '''')), PB [84, 87, 70, 117], PS ((STR '''' + Disc_Formats.dq + STR ''.''))]"

definition st28 :: bool where
  "st28 \<longleftrightarrow>
     \<not> answered (reply_of (RFormats (F_b64dec [110, 111, 116, 42])))"

definition st29 :: bool where
  "st29 \<longleftrightarrow>
     response (reply_of (RFormats (F_day [49, 57, 55, 48, 45, 48, 49, 45, 48, 49] 1970 1 1))) =
       [PB [49, 57, 55, 48, 45, 48, 49, 45, 48, 49], PS (STR '' is a Thursday.'')]"

definition st30 :: bool where
  "st30 \<longleftrightarrow>
     \<not> answered (reply_of (RFormats (F_day [50, 48, 50, 51, 45, 48, 50, 45, 51, 48] 2023 2 30)))"

definition st31 :: bool where
  "st31 \<longleftrightarrow>
     response (reply_of (RFormats (F_day [50, 48, 50, 52, 45, 48, 50, 45, 50, 57] 2024 2 29))) =
       [PB [50, 48, 50, 52, 45, 48, 50, 45, 50, 57], PS (STR '' is a Thursday.'')]"

definition st32 :: bool where
  "st32 \<longleftrightarrow>
     response (reply_of (RFormats (F_json [123, 34, 97, 34, 58, 32, 49, 125]))) =
       [PS (STR ''Yes, that is valid JSON (an object with 1 keys).'')]"

definition st33 :: bool where
  "st33 \<longleftrightarrow>
     answered (reply_of (RFormats (F_json [123, 34, 97, 34, 32, 49, 125])))"

definition st34 :: bool where
  "st34 \<longleftrightarrow>
     response (reply_of (RFormats (F_json [123, 34, 97, 34, 58, 32, 49]))) =
       [PS (STR ''No, that is not valid JSON: Expecting ',' delimiter at line 1, column 8.'')]"

export_code reply_of answered reply_kind response stated answers mk_rat
  integer_of_nat nat_of_integer int_of_integer
  st0 st1 st2 st3 st4 st5 st6 st7 st8 st9 st10 st11 st12 st13 st14 st15 st16 st17 st18 st19 st20 st21 st22 st23 st24 st25 st26 st27 st28 st29 st30 st31 st32 st33 st34
  piece_lit piece_raw hand_list card_list form_list complexity_names
  PS PB JNone JRaw JStr
  RGames RLogic RAlgos RCalc RFormats
  G_poker G_dice G_atleast G_atleast_unknown G_need G_card_one G_card_k G_anagram G_anagram_none
  FVar FNeg FConj FDisj FImpl FEquiv L_formula L_argument L_form L_bad_formula L_bad_argument L_need
  A_sp A_sp_need A_mst A_mst_need A_bsearch A_bsearch_need A_need A_sort A_complexity
  C_deriv C_deriv_at C_anti C_def C_partial C_partial_at C_need
  F_json F_b64dec F_b64enc F_hash F_urldec F_urlenc F_base F_signed_base F_need F_day
  H_sha256 H_sha1 H_md5
  in SML module_name Discrete file_prefix discrete

ML \<open>
  val theorems = [@{thm anagram_equation}, @{thm sum_dist}, @{thm dist_ways}, @{thm hand_values},
    @{thm hand_partition}, @{thm seq_prob_ordered}, @{thm dice_value}, @{thm dice_impossible},
    @{thm roll_sequences_count}, @{thm roll_sequences_nonempty}, @{thm containing_lists_count}, @{thm roll_sequences_containing},
    @{thm atleast_value}, @{thm atleast_range}, @{thm atleast_empty}, @{thm atleast_impossible_face},
    @{thm seq_prob_too_many}, @{thm card_k_too_many}, @{thm card_one_value}, @{thm card_k_ordered},
    @{thm card_k_repl_value}, @{thm poker_value}, @{thm anagram_value}, @{thm g_reply_answered},
    @{thm pct_num_sound},
    @{thm classify_taut}, @{thm classify_contr}, @{thm classify_conting}, @{thm argument_valid},
    @{thm argument_witness}, @{thm form_table}, @{thm form_semantics}, @{thm l_formula_sound},
    @{thm l_argument_valid_sound}, @{thm l_argument_invalid_sound}, @{thm l_reply_answered}, @{thm l_formula_table_bound}, @{thm l_argument_table_bound},
    @{thm sp_found_sound}, @{thm sp_unreach_sound}, @{thm a_shortest_sound}, @{thm a_unreach_sound},
    @{thm a_nonode}, @{thm a_mst_sound}, @{thm mst_edges}, @{thm bsearch_found}, @{thm bsearch_none},
    @{thm a_bsearch_found}, @{thm a_bsearch_none}, @{thm a_bsearch_unsorted}, @{thm isort_correct},
    @{thm a_sorted_sound}, @{thm a_reply_answered},
    @{thm norm_peval}, @{thm norm_pev}, @{thm pder_raw_derivative}, @{thm pint_raw_derivative},
    @{thm pder_n_derivative}, @{thm pint_derivative}, @{thm c_deriv_sound}, @{thm c_deriv_at_sound},
    @{thm coordinate_partial_derivative}, @{thm c_partial_sound}, @{thm c_partial_at_sound}, @{thm c_anti_sound}, @{thm c_def_sound}, @{thm c_reply_answered},
    @{thm from_to_digits}, @{thm to_digits_below}, @{thm base_convert_value}, @{thm b64_roundtrip},
    @{thm pct_roundtrip}, @{thm sha_pad_blocks}, @{thm days_next_day_in_month},
    @{thm weekday_next_day}, @{thm epoch_is_thursday}, @{thm f_base_sound}, @{thm f_signed_base_sound}, @{thm f_base_declines},
    @{thm f_b64dec_ok}, @{thm f_b64enc_decodes}, @{thm f_url_roundtrip}, @{thm f_day_valid},
    @{thm f_day_invalid}, @{thm f_base_decline_exact}, @{thm sha_pad_shape},
    @{thm mst_cert_minimal}, @{thm mst_cert_spans}, @{thm a_mst_minimal}, @{thm a_mst_disconnected},
    @{thm reply_of_games}, @{thm reply_of_logic}, @{thm reply_of_algos}, @{thm reply_of_calc},
    @{thm reply_of_formats}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("discrete theorems use oracles: " ^ string_of_int (length oracles));


  val _ = writeln "st0"; val _ = if @{code st0} then () else error "self test 0 failed";
  val _ = writeln "st1"; val _ = if @{code st1} then () else error "self test 1 failed";
  val _ = writeln "st2"; val _ = if @{code st2} then () else error "self test 2 failed";
  val _ = writeln "st3"; val _ = if @{code st3} then () else error "self test 3 failed";
  val _ = writeln "st4"; val _ = if @{code st4} then () else error "self test 4 failed";
  val _ = writeln "st5"; val _ = if @{code st5} then () else error "self test 5 failed";
  val _ = writeln "st6"; val _ = if @{code st6} then () else error "self test 6 failed";
  val _ = writeln "st7"; val _ = if @{code st7} then () else error "self test 7 failed";
  val _ = writeln "st8"; val _ = if @{code st8} then () else error "self test 8 failed";
  val _ = writeln "st9"; val _ = if @{code st9} then () else error "self test 9 failed";
  val _ = writeln "st10"; val _ = if @{code st10} then () else error "self test 10 failed";
  val _ = writeln "st11"; val _ = if @{code st11} then () else error "self test 11 failed";
  val _ = writeln "st12"; val _ = if @{code st12} then () else error "self test 12 failed";
  val _ = writeln "st13"; val _ = if @{code st13} then () else error "self test 13 failed";
  val _ = writeln "st14"; val _ = if @{code st14} then () else error "self test 14 failed";
  val _ = writeln "st15"; val _ = if @{code st15} then () else error "self test 15 failed";
  val _ = writeln "st16"; val _ = if @{code st16} then () else error "self test 16 failed";
  val _ = writeln "st17"; val _ = if @{code st17} then () else error "self test 17 failed";
  val _ = writeln "st18"; val _ = if @{code st18} then () else error "self test 18 failed";
  val _ = writeln "st19"; val _ = if @{code st19} then () else error "self test 19 failed";
  val _ = writeln "st20"; val _ = if @{code st20} then () else error "self test 20 failed";
  val _ = writeln "st21"; val _ = if @{code st21} then () else error "self test 21 failed";
  val _ = writeln "st22"; val _ = if @{code st22} then () else error "self test 22 failed";
  val _ = writeln "st23"; val _ = if @{code st23} then () else error "self test 23 failed";
  val _ = writeln "st24"; val _ = if @{code st24} then () else error "self test 24 failed";
  val _ = writeln "st25"; val _ = if @{code st25} then () else error "self test 25 failed";
  val _ = writeln "st26"; val _ = if @{code st26} then () else error "self test 26 failed";
  val _ = writeln "st27"; val _ = if @{code st27} then () else error "self test 27 failed";
  val _ = writeln "st28"; val _ = if @{code st28} then () else error "self test 28 failed";
  val _ = writeln "st29"; val _ = if @{code st29} then () else error "self test 29 failed";
  val _ = writeln "st30"; val _ = if @{code st30} then () else error "self test 30 failed";
  val _ = writeln "st31"; val _ = if @{code st31} then () else error "self test 31 failed";
  val _ = writeln "st32"; val _ = if @{code st32} then () else error "self test 32 failed";
  val _ = writeln "st33"; val _ = if @{code st33} then () else error "self test 33 failed";
  val _ = writeln "st34"; val _ = if @{code st34} then () else error "self test 34 failed";

  (* byte-level known-answer checks (digests, base64) through the exported code *)
  fun nat i = @{code nat_of_integer} (IntInf.fromInt i);
  fun bytes s = map (fn c => nat (Char.ord c)) (String.explode s);
  fun piece_text p = case @{code piece_lit} p of
      SOME s => s
    | NONE => String.implode (map (fn n => Char.chr (IntInf.toInt (@{code integer_of_nat} n))) (@{code piece_raw} p));
  fun resp r = String.concat (map piece_text (@{code response} r));
  fun hash alg s = resp (@{code reply_of} (@{code RFormats} (@{code F_hash} (alg, bytes s))));
  val _ = if hash @{code H_sha256} "abc" = "The SHA256 of \"abc\" (UTF-8) is ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad."
          then () else error "sha256 vector";
  val _ = if hash @{code H_md5} "abc" = "The MD5 of \"abc\" (UTF-8) is 900150983cd24fb0d6963f7d28e17f72."
          then () else error "md5 vector";
  val _ = if hash @{code H_sha1} "abc" = "The SHA1 of \"abc\" (UTF-8) is a9993e364706816aba3e25717850c26c9cd0d89d."
          then () else error "sha1 vector";
  val _ = if hash @{code H_sha256} "" = "The SHA256 of \"\" (UTF-8) is e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855."
          then () else error "sha256 empty vector";
  val _ = if hash @{code H_sha256} "The quick brown fox jumps over the lazy dog the quick brown fox jumps over" =
            "The SHA256 of \"The quick brown fox jumps over the lazy dog the quick brown fox jumps over\" (UTF-8) is de7921b91555fdc4f466e9574071d03295ee43fb41044e21814ca32ce71015b7."
          then () else error "sha256 two-block vector";
  val _ = writeln ("VERI7VN_DISCRETE PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
