theory Finance_Export
  imports Finance
begin

text \<open>Constructor the untrusted SML recognizer uses to build rationals from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

text \<open>Whether the kernel answers a request.\<close>
definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (R_TurnoverPeriod 700 100 1 IT_Week 1 IT_Year365) = Exact K_turnover 365 \<and>
     kernel (R_TurnoverPeriod 3000 1000 30 IT_Day 30 IT_Day) = Exact K_turnover 3 \<and>
     kernel (R_TurnoverPeriod 0 100 1 IT_Week 1 IT_Year365) = Exact K_turnover 0 \<and>
     kernel (R_DaysPeriod 700 100 1 IT_Week) = Exact K_days_inventory 1 \<and>
     kernel (R_ROPPeriod 70 1 IT_Week 5 IT_Day 20) = Exact K_rop 70 \<and>
     kernel (R_ROPPeriod 10 1 IT_Day 2 IT_Week 20) = Exact K_rop 160 \<and>
     kernel (R_DaysPeriod 700 100 0 IT_Week) = Decline (Impossible R_positive) \<and>
     kernel (F_Savings (Some 1200) (Some 1) None) = Exact K_savings_goal 100 \<and>
     kernel (F_CompoundInterest (Some 1000) (Some (5 / 100)) (Some 2) (Some Fq_annual)) = Cents K_compound_interest 10250 \<and>
     kernel (F_SimpleTotal (Some 1000) (Some (5 / 100)) (Some 2)) = Exact K_simple_total 1100 \<and>
     kernel (E_Fisher 10 5) = Exact K_real_rate (100 / 21) \<and>
     kernel (F_LoanPayment (Some 1200) (Some (12 / 100)) (Some (1 / 10))) = Decline (Impossible R_term) \<and>
     kernel (F_Simple (Some 5000) (Some (8 / 100)) (Some 10)) = Exact K_simple_interest 4000 \<and>
     kernel (F_LoanPayment (Some 1200) (Some 0) (Some 1)) = Exact K_loan_payment 100 \<and>
     kernel (F_Compound (Some 1000) (Some (1 / 10)) (Some 2) (Some Fq_annual)) = Cents K_compound 121000 \<and>
     kernel (F_Compound (Some 1000) (Some (1 / 20)) (Some 1) (Some Fq_continuous)) = Approx K_compound (105127, -2) \<and>
     kernel (F_Compound (Some 1000) (Some (1 / 10)) (Some (1 / 2)) (Some Fq_annual)) = Approx K_compound (104881, -2) \<and>
     kernel (F_Apy (Some (1 / 20)) (Some Fq_continuous)) = Approx K_apy (51271, -4) \<and>
     kernel (F_Doubling (Some (8 / 100))) = Approx K_doubling (901, -2) \<and>
     kernel (F_Doubling None) = Decline (Underspecified N_pos_rate) \<and>
     kernel (E_Multiplier (3 / 5)) = Exact K_multiplier (5 / 2) \<and>
     kernel (E_Multiplier (6 / 5)) = Decline (Impossible R_mpc) \<and>
     kernel (R_Margin 8 10) = Exact K_margin 20 \<and>
     kernel (R_BreakEven (Some 30000) (Some 24) (Some 4)) = Exact K_break_even 1500 \<and>
     kernel (R_BreakEven (Some 1) (Some 4) (Some 4)) = NoValue K_never_even \<and>
     kernel (R_EOQ (Some 1200) (Some 40) (Some 2)) = Approx K_eoq (2191, -1) \<and>
     kernel F_Advice = Decline Advice \<and>
     kernel (F_Annuity (Some 100) (Some 0) (Some 1)) = Exact K_annuity 1200 \<and>
     stated (reply_of (F_Annuity (Some 100) (Some (12 / 100)) (Some 1))) = Some (STR ''1268.25'') \<and>
     kernel (F_Annuity (Some 100) None (Some 1)) = Decline (Underspecified N_annuity) \<and>
     kernel (F_TwoPhase (Some 1000) (Some (1 / 10)) (Some 1) (Some Fq_annual) (Some (1 / 5)) (Some 1) (Some Fq_annual))
       = Cents K_two_phase 132000 \<and>
     kernel (F_TwoPhase (Some 1000) (Some (1 / 10)) (Some 1) (Some Fq_continuous) (Some (1 / 5)) (Some 1) (Some Fq_annual))
       = Decline (Impossible R_phase) \<and>
     kernel (E_RealGdp (Some 24) (Some 120) (STR '''')) = Exact K_real_gdp 20 \<and>
     kernel (E_RealGdp (Some 24) (Some 0) (STR '''')) = Decline (Impossible R_positive) \<and>
     kernel (R_DiscountTax 100 [20] (1 / 10)) = Exact K_discount_tax 88 \<and>
     response (reply_of (F_Simple (Some 5000) (Some (8 / 100)) (Some 10))) =
       STR ''The simple interest is $4,000.00 (I = P*r*t = $5,000.00 x 8% x 10 years); total $9,000.00.'' \<and>
     stated (reply_of (F_Simple (Some 5000) (Some (8 / 100)) (Some 10))) = Some (STR ''4000.00'') \<and>
     response (reply_of (F_Compound (Some 1000) (Some (1 / 10)) (Some 2) (Some Fq_annual))) =
       STR ''It grows to $1,210.00 ($1,000.00 at 10% compounded annually for 2 years; interest earned $210.00).'' \<and>
     response (reply_of (R_Margin 8 10)) = STR ''The gross margin is 20% (($10.00 - $8.00) / price $10.00).'' \<and>
     response (reply_of (R_EOQ (Some 1200) (Some 40) (Some 2))) =
       STR ''The EOQ is 219.1 units (sqrt(2 x 1200 x $40.00 / $2.00)).'' \<and>
     response (reply_of (E_Multiplier (3 / 5))) = STR ''The spending multiplier is 2.5 (1 / (1 - MPC) = 1 / 0.4).'' \<and>
     response (reply_of (E_Elasticity (Some (20, 22)) (Some (1000, 980)))) =
       STR ''The price elasticity of demand is -0.212 (midpoint method: %dQ -2.02% / %dP 9.524%) - inelastic (|E| < 1).''"

definition rat_parts :: "rat \<Rightarrow> integer \<times> integer" where
  "rat_parts r = (integer_of_int (fst (quotient_of r)), integer_of_int (snd (quotient_of r)))"

export_code rat_parts check_discount_tax discount_tax_value reply_of answered reply_kind response stated answers mk_rat
  F_Cashflow CF_Balance CF_Interest At_Start At_End
  R_TurnoverPeriod
  R_DaysPeriod R_ROPPeriod R_InventoryModel IT_Hour IT_Day IT_Week IT_Year365
  Fq_annual Fq_semi Fq_quarterly Fq_monthly Fq_weekly Fq_daily Fq_continuous
  F_Apy F_Doubling F_LoanPayment F_LoanInterest F_Savings F_Simple F_SimpleTotal F_Compound F_CompoundInterest F_Advice F_UnknownTarget F_MultiPhase
  E_Elasticity E_ElasticityPct E_Inflation E_RealValue E_RealRate E_Fisher E_Growth E_Multiplier
  E_TaxMultiplier E_Unemployment E_Participation E_Deflator E_Rule70
  R_BreakEven R_EOQ R_ROP R_Turnover R_Days R_Markup R_Margin R_PriceMarkup R_PriceMargin
  R_Discount R_WithTax R_TaxModel R_TaxQuery RT_Final RT_Tax RT_Saving F_Annuity F_TwoPhase E_RealGdp R_DiscountTax
  in SML module_name Finance file_prefix finance

ML \<open>
  val theorems = [@{thm turnover_period_balance}, @{thm turnover_period_nonnegative}, @{thm turnover_observed_period}, @{thm inventory_period_balance}, @{thm inventory_period_unit_equivalence}, @{thm reorder_period_balance}, @{thm reorder_period_nonnegative}, @{thm inventory_annual_compatibility}, @{thm reorder_daily_compatibility}, @{thm cashflow_recurrence}, @{thm cashflow_due_contribution}, @{thm cashflow_balance_binding}, @{thm cashflow_interest_binding}, @{thm reorder_point_nonnegative}, @{thm price_from_markup_nonnegative}, @{thm inventory_turnover_nonnegative}, @{thm kernel_exact_sound}, @{thm kernel_cents_sound}, @{thm kernel_approx_sound},
    @{thm kernel_underspecified}, @{thm kernel_impossible}, @{thm kernel_imprecise},
    @{thm reason_of_exact}, @{thm never_even_iff},
    @{thm round_sig_sound}, @{thm to_dec_sound}, @{thm to_dec_at_sound}, @{thm to_dec_g4_sound},
    @{thm enclose_fmt_sound}, @{thm quant_sound}, @{thm round_tie_up}, @{thm round_frac_eq},
    @{thm compound_frac_props}, @{thm compound_interest_frac_props}, @{thm compound_interest_out_cents}, @{thm compound_interest_out_approx}, @{thm rpow_eq},
    @{thm loan_amortizes}, @{thm savings_reaches_goal}, @{thm loan_interest_is_total_minus_principal},
    @{thm simple_interest_additive}, @{thm apy_compounding}, @{thm apy_at_least_nominal},
    @{thm doubling_model}, @{thm compound_matches_exponential}, @{thm eoq_model},
    @{thm break_even_equation}, @{thm margin_markup_relation}, @{thm price_from_margin_correct},
    @{thm price_from_markup_correct}, @{thm discounts_compose}, @{thm multiplier_equation},
    @{thm tax_multiplier_relation}, @{thm real_rate_is_fisher_approximation}, @{thm exact_real_rate_factors}, @{thm loan_interest_agrees_with_payment}, @{thm price_markup_roundtrip}, @{thm unemployment_in_range}, @{thm participation_in_range}, @{thm real_gdp_nonnegative}, @{thm inflation_positive_indices},
    @{thm reply_answered_iff}, @{thm reply_states_exact}, @{thm reply_states_cents},
    @{thm reply_states_approx}, @{thm reply_withheld_names_decline},
    @{thm exact_stated_within_tolerance},
    @{thm annuity_accumulates}, @{thm annuity_inverts_savings}, @{thm two_phase_chains},
    @{thm real_gdp_equation}, @{thm real_gdp_deflator_roundtrip}, @{thm discount_tax_chains}, @{thm disc_val_bounds}, @{thm discount_bounds}, @{thm discount_tax_bounds}, @{thm disc_val_product}, @{thm check_discount_tax_iff}, @{thm discount_tax_value_checked}, @{thm retail_tax_components(1)}, @{thm retail_tax_components(2)},
    @{thm retail_final_binding}, @{thm retail_tax_binding}, @{thm retail_savings_binding}] @ @{thms kernel_refusal};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("finance theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "finance self test failed";
  val marker = "VERI7VN_FINANCE PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0";
  val _ = writeln marker;
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/finance")) [XML.Text marker];
\<close>

end
