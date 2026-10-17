theory Math_Export
  imports Math
begin

text \<open>Constructors the untrusted SML recognizer uses to build requests from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

export_code reply_of answered response value_lit path_lit self_test mk_rat
  integer_of_int nat_of_integer int_of_integer
  PercentOf Convert Sqrt GcdLcm SolveLin EvalExpr
  C V Add Sub Mul Div Neg Pow
  T_second T_minute T_hour T_day T_week T_year
  M_milligram M_gram M_kilogram M_ounce M_pound
  Ask WordConv OpConv GuardP7 GuardG6 GuardG5
  in SML module_name Mathkernel file_prefix mathkernel

ML \<open>
  val theorems = [@{thm eval_closed_ignores_reading}, @{thm mfactor_positive},
    @{thm strip_factor_dvd}, @{thm strip_factor_max}, @{thm dec_expansion_sound},
    @{thm isqrt_interval}, @{thm isqrt_unique}, @{thm isqrt_square},
    @{thm newton_step_bounds}, @{thm newton_last_sound}, @{thm newton_last_isqrt},
    @{thm euc_res_gcd},
    @{thm percent_value}, @{thm percent_of_hundred},
    @{thm convert_exact}, @{thm convert_mismatch}, @{thm convert_composes},
    @{thm sqrt_negative_decline}, @{thm sqrt_of_square}, @{thm sqrt_value_is_interval},
    @{thm gcd_value_divides}, @{thm lcm_value_identity},
    @{thm solve_linear_sound}, @{thm solve_linear_complete}, @{thm solve_echo_iff},
    @{thm solve_what_the_echo_withholds}, @{thm solve_zero_slope},
    @{thm eval_value_independent}, @{thm eval_symbolic_decline},
    @{thm eval_undefined_decline},
    @{thm guard_P7_rule}, @{thm P7_no_witness},
    @{thm P7_area_of_negative_side_ambiguous},
    @{thm guard_G6_rule}, @{thm G6_value_not_determined},
    @{thm guard_G5_rule},
    @{thm reply_answered_iff}, @{thm reply_states_value}, @{thm reply_sqrt_perfect},
    @{thm reply_withheld_names_decline}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("mathorgan theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "mathorgan self test failed";
  val _ = writeln ("VERI7VN_MATHORGAN PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
