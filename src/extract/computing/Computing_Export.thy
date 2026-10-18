theory Computing_Export
  imports Networking Numerics System Permission_Query Pyref Sql "HOL-Library.Code_Target_Numeral"
begin

definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

export_code permission_scope_reply permission_effective_reply permission_reply net_reply emb_reply cyb_reply rob_reply lin_reply git_reply py_reply sql_answer validity_reply sql_validity
  mk_rat mask_prefix sig_num sig_name
  integer_of_int nat_of_integer int_of_integer integer_of_nat
  IP NReq BMask BPrefix BWildcard BCount BAddr BNeedPrefix BSame BPrivate BSubnets BForHosts
  W_hosts W_network W_broadcast W_first W_last W_range
  E_char E_byte EAddr EUbrr EUartTp EUartTime ECtc EOvf ETick
  CS_printable CS_alnum CS_mixed CS_lower CS_digits CS_custom
  CDigest CBirthday CBase64 CKeyspace CEntropy CDistribution CBrute
  RW_radius RW_angular RW_linear RPwm RFk REnc RWheel RDiff
  Mode P_owner P_group P_other
  LSymFromOct LOctFromSym LUmask LCron LCronNoPeriod LSigNum LSigName LExit
  Sym Perm X_no X_x X_sp X_SP UM_file UM_dir UM_both CStar CRange CSingle CI CBad
  G_reset_soft G_reset_hard G_amend G_switch_c G_switch G_unstage G_restore G_add_all G_rename G_del_remote
  G_del_local G_remotes G_stash_pop G_stash_apply G_stash_list G_stash G_diff_staged G_log G_clone G_init G_config_name G_status
  G_fetch G_pull_rebase G_cherry_pick G_tag_a G_blame G_revert
  PyCand PQ_module PQ_signature PQ_doc
  TW TI TR TS TP
  answered reply_kind response stated
  in SML module_name Computing file_prefix computing

ML \<open>
  val theorems = flat [@{thms missing_actions_exact}, @{thms permission_rows_exact},
    @{thms permission_reply_lists_exact_unset}, @{thms permission_reply_guard}, @{thms net_props}, @{thms net_unique}, @{thms bcast_props}, @{thms mask_wildcard_complement},
    @{thms usable_hosts}, @{thms mask_prefix_iff}, @{thms pfh_smallest}, @{thms pfh_complete},
    @{thms net_private_iff}, @{thms net_mask_value}, @{thms net_network_value}, @{thms net_broadcast_value},
    @{thms net_subnets_value}, @{thms net_forhosts_value}, @{thms net_reply_answered_iff},
    @{thms round_he_close}, @{thms round_he_tie_even}, @{thms to_fixed_sound}, @{thms enclose_fixed_sound},
    @{thms emb_ctc_value}, @{thms emb_ctc_freq_bound}, @{thms emb_ubrr_value}, @{thms emb_timer_identities},
    @{thms emb_uart_identities}, @{thms cyb_base64_len}, @{thms cyb_brute_value}, @{thms cyb_entropy_sound},
    @{thms rob_diff_identities}, @{thms rob_wheel_sound}, @{thms rob_enc_sound}, @{thms rob_fk_sound},
    @{thms sym_mode_sym}, @{thms mode_sym_mode}, @{thms item_vals_mem}, @{thms field_count_bound}, @{thms sig_table_bijective},
    @{thms umask_file_bits}, @{thms umask_dir_bits}, @{thms lin_reply_answered_iff}, @{thms git_warns_exactly_destructive},
    @{thms git_commands_distinct}, @{thms git_reply_states_command},
    @{thms py_found_in_table}, @{thms py_missing_sound}, @{thms py_missing_is_reference_absence}, @{thms py_signature_states_row},
    @{thms py_withheld_iff}, @{thms py_lookup_sound}, @{thms py_lookup_complete},
    @{thms isort_perm}, @{thms isort_sorted}, @{thms where_keeps_exactly_true}, @{thms agg_count_skips_null},
    @{thms agg_sum_empty}, @{thms agg_sum_ints}, @{thms agg_avg_value}, @{thms exec_unknown_column},
    @{thms sql_reply_answered_iff}, @{thms validity_unbalanced_is_no}, @{thms sql_answer_unparsed_withheld},
    @{thms fixed_str_sound}, @{thms net_of_eq_iff}, @{thms usable_p2p}, @{thms priv_block_range},
    @{thms priv_block_complete}, @{thms net_kernel_value}, @{thms net_decline_ip}, @{thms net_decline_prefix},
    @{thms net_decline_mask}, @{thms net_prefix_value}, @{thms net_wildcard_value}, @{thms net_usable_value},
    @{thms net_same_value}, @{thms net_forhosts_declines_iff}, @{thms net_reply_withheld_names_decline},
    @{thms emb_address_value}, @{thms emb_address_bytes_exact}, @{thms emb_address_locations}, @{thms emb_uart_byte_mapping}, @{thms emb_reply_answered_iff},
    @{thms cyb_digest_hex}, @{thms cyb_birthday_value}, @{thms cyb_keyspace_value},
    @{thms cyb_brute_avg_half}, @{thms cyb_underspecified}, @{thms dur_unit_years},
    @{thms cyb_reply_answered}, @{thms cyb_distribution_withheld}, @{thms rob_diff_straight}, @{thms rob_pwm_bound},
    @{thms rob_reply_withheld_iff_decline}, @{thms py_module_states_row}, @{thms py_doc_states_row},
    @{thms ins_stable_before_equal}, @{thms where_null_never_kept}, @{thms agg_count_star_len},
    @{thms agg_max_is_member}, @{thms validity_bad_leading_word}, @{thms validity_yes_reply_answered},
    @{thms validity_unknown_withheld}, @{thms sig_name_some}, @{thms umask_values},
    @{thms lin_chmod_declines_iff}, @{thms lin_umask_declines_iff}, @{thms lin_exit_value},
    @{thms git_all_intents_complete}, @{thms exec_group_keys_strictly_ordered},
    @{thms where_cond_is_relational}, @{thms where_rows_relational}, @{thms keys_cmp_relational},
    @{thms select_correct_unordered}, @{thms select_correct_ordered}, @{thms select_distinct_relational}, @{thms select_group_count_relational}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("computing theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code permission_self_test} andalso @{code net_self_test} andalso @{code emb_self_test} andalso @{code cyb_self_test} andalso @{code rob_self_test} andalso
          @{code lin_self_test} andalso @{code git_self_test} andalso @{code py_self_test} andalso @{code sql_self_test} andalso @{code sql_parse_test}
          then () else error "computing self test failed";
  val _ = writeln ("VERI7VN_COMPUTING PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
