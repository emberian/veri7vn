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
  val theorems = @{thms eval_closed_ignores_reading mfactor_positive
    dec_search_sound dec_expansion_sound
    isqrt_interval isqrt_unique isqrt_square
    newton_step_bounds newton_last_sound newton_last_isqrt
    euc_res_gcd
    percent_value percent_of_hundred
    convert_exact convert_mismatch convert_composes
    sqrt_negative_decline sqrt_of_square sqrt_value_is_interval
    gcd_value_divides lcm_value_identity
    solve_linear_sound solve_linear_complete solve_echo_iff
    solve_what_the_echo_withholds solve_zero_slope
    eval_value_independent eval_symbolic_decline
    eval_undefined_decline
    guard_P7_rule P7_no_witness
    P7_area_of_negative_side_ambiguous
    guard_G6_rule G6_value_not_determined
    guard_G5_rule
    reply_answered_iff reply_states_value reply_sqrt_perfect
    reply_withheld_names_decline};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("mathorgan theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "mathorgan self test failed";
  val _ = writeln ("VERI7VN_MATHORGAN PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
