theory Computing_Export
  imports Networking Numerics System Pyref Sql "HOL-Library.Code_Target_Numeral"
begin

definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

export_code net_reply emb_reply cyb_reply rob_reply lin_reply git_reply py_reply sql_answer validity_reply sql_validity
  mk_rat mask_prefix sig_num sig_name
  net_self_test emb_self_test cyb_self_test rob_self_test lin_self_test git_self_test py_self_test sql_self_test sql_parse_test
  integer_of_int nat_of_integer int_of_integer integer_of_nat
  IP NReq BMask BPrefix BWildcard BCount BAddr BNeedPrefix BSame BPrivate BSubnets BForHosts
  W_hosts W_network W_broadcast W_first W_last W_range
  EAddr EUbrr EUartTp EUartTime ECtc EOvf ETick
  CS_printable CS_alnum CS_mixed CS_lower CS_digits CS_custom
  CDigest CBirthday CBase64 CKeyspace CEntropy CBrute
  RW_radius RW_angular RW_linear RPwm RFk REnc RWheel RDiff
  LSymFromOct LOctFromSym LUmask LCron LCronNoPeriod LSigNum LSigName LExit
  Sym Perm X_no X_x X_sp X_SP UM_file UM_dir UM_both CStar CRange CSingle CI CBad
  G_reset_soft G_reset_hard G_amend G_switch_c G_switch G_unstage G_restore G_add_all G_rename G_del_remote
  G_del_local G_remotes G_stash_pop G_stash G_diff_staged G_log G_clone G_init G_config_name G_status
  G_fetch G_pull_rebase G_cherry_pick G_tag_a G_blame G_revert
  PyCand PQ_module PQ_signature PQ_doc
  TW TI TR TS TP
  answered reply_kind response stated
  in SML module_name Computing file_prefix computing

ML \<open>
  val theorems = flat [@{thms net_props}, @{thms net_unique}, @{thms bcast_props}, @{thms mask_wildcard_complement},
    @{thms usable_hosts}, @{thms mask_prefix_iff}, @{thms pfh_smallest}, @{thms pfh_complete},
    @{thms net_private_iff}, @{thms net_mask_value}, @{thms net_network_value}, @{thms net_broadcast_value},
    @{thms net_subnets_value}, @{thms net_forhosts_value}, @{thms net_reply_answered_iff},
    @{thms round_he_close}, @{thms round_he_tie_even}, @{thms to_fixed_sound}, @{thms enclose_fixed_sound},
    @{thms emb_ctc_value}, @{thms emb_ctc_gives}, @{thms emb_ubrr_value}, @{thms emb_timer_identities},
    @{thms emb_uart_identities}, @{thms cyb_base64_len}, @{thms cyb_brute_value}, @{thms cyb_entropy_sound},
    @{thms rob_diff_identities}, @{thms rob_wheel_sound}, @{thms rob_enc_sound}, @{thms rob_fk_sound},
    @{thms sym_mode_sym}, @{thms mode_sym_mode}, @{thms item_vals_mem}, @{thms field_count_bound}, @{thms sig_table_bijective},
    @{thms umask_file_bits}, @{thms umask_dir_bits}, @{thms lin_reply_answered_iff}, @{thms git_warns_exactly_destructive},
    @{thms git_commands_distinct}, @{thms git_reply_states_command},
    @{thms py_found_in_table}, @{thms py_missing_sound}, @{thms py_signature_states_row},
    @{thms py_withheld_iff}, @{thms py_lookup_sound}, @{thms py_lookup_complete},
    @{thms isort_perm}, @{thms isort_sorted}, @{thms where_keeps_exactly_true}, @{thms agg_count_skips_null},
    @{thms agg_sum_empty}, @{thms agg_sum_ints}, @{thms agg_avg_value}, @{thms exec_unknown_column},
    @{thms sql_reply_answered_iff}, @{thms validity_unbalanced_is_no}, @{thms sql_answer_unparsed_withheld}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("computing theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code net_self_test} andalso @{code emb_self_test} andalso @{code cyb_self_test} andalso @{code rob_self_test} andalso
          @{code lin_self_test} andalso @{code git_self_test} andalso @{code py_self_test} andalso @{code sql_self_test} andalso @{code sql_parse_test}
          then () else error "computing self test failed";
  val _ = writeln ("VERI7VN_COMPUTING PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
