theory Computing_Export
  imports Networking Numerics System Pyref Sql
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
  val theorems = [@{thm net_props}, @{thm net_unique}, @{thm bcast_props}, @{thm mask_wildcard_complement},
    @{thm usable_hosts}, @{thm mask_prefix_iff}, @{thm pfh_smallest}, @{thm pfh_complete},
    @{thm net_private_iff}, @{thm net_mask_value}, @{thm net_network_value}, @{thm net_broadcast_value},
    @{thm net_subnets_value}, @{thm net_forhosts_value}, @{thm net_reply_answered_iff},
    @{thm round_he_close}, @{thm round_he_tie_even}, @{thm to_fixed_sound}, @{thm enclose_fixed_sound},
    @{thm emb_ctc_value}, @{thm emb_ctc_gives}, @{thm emb_ubrr_value}, @{thm emb_timer_identities},
    @{thm emb_uart_identities}, @{thm cyb_base64_len}, @{thm cyb_brute_value}, @{thm cyb_entropy_sound},
    @{thm rob_diff_identities}, @{thm rob_wheel_sound}, @{thm rob_enc_sound}, @{thm rob_fk_sound},
    @{thm sym_mode_sym}, @{thm mode_sym_mode}, @{thm item_vals_mem}, @{thm field_count_bound}, @{thm sig_table_bijective},
    @{thm umask_file_bits}, @{thm umask_dir_bits}, @{thm lin_reply_answered_iff}, @{thm git_warns_exactly_destructive},
    @{thm git_commands_distinct}, @{thm git_reply_states_command},
    @{thm py_names_distinct}, @{thm py_found_in_table}, @{thm py_missing_sound}, @{thm py_signature_states_row},
    @{thm py_withheld_iff}, @{thm py_table_size},
    @{thm isort_perm}, @{thm isort_sorted}, @{thm where_keeps_exactly_true}, @{thm agg_count_skips_null},
    @{thm agg_sum_empty}, @{thm agg_sum_ints}, @{thm agg_avg_value}, @{thm exec_unknown_column},
    @{thm sql_reply_answered_iff}, @{thm validity_unbalanced_is_no}, @{thm sql_answer_unparsed_withheld}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("computing theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code net_self_test} andalso @{code emb_self_test} andalso @{code cyb_self_test} andalso @{code rob_self_test} andalso
          @{code lin_self_test} andalso @{code git_self_test} andalso @{code py_self_test} andalso @{code sql_self_test} andalso @{code sql_parse_test}
          then () else error "computing self test failed";
  val _ = writeln ("VERI7VN_COMPUTING PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
