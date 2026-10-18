theory Wordprob_Export
  imports Wordprob
begin

text \<open>Constructor the untrusted SML recognizer uses to build exact rationals
from decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

text \<open>Self test, one named case per schema reply (against the organ's own
output for that shape) plus the abstention and ambiguity rules, so the ML
below can name exactly what failed.\<close>
definition c_percent_of :: bool where
  "c_percent_of \<longleftrightarrow> response (reply_of (None, [PercentOf False 17 2400])) =
       STR ''[ev:derived] 408. Read as percent of: 17% of 2400. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_convert :: bool where
  "c_convert \<longleftrightarrow> response (reply_of (None, [Convert (7 / 2) U_hour U_second])) =
       STR ''[ev:derived] 12600 seconds. Read as convert: 3.5 hour = 3.5 x 1 / 0.000277778 second. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_simple_interest :: bool where
  "c_simple_interest \<longleftrightarrow> response (reply_of (None, [SimpleInterest 800 5 3])) =
       STR ''[ev:derived] $120. Read as simple interest: I = P x r x t = 800 x 5% x 3 years. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_percent_of_total :: bool where
  "c_percent_of_total \<longleftrightarrow> response (reply_of (None, [PercentOfTotal 20 80])) =
       STR ''[ev:derived] 25%. Read as percent of total: percent = part / whole x 100 = 20 / 80 x 100. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_motion_dist :: bool where
  "c_motion_dist \<longleftrightarrow> response (reply_of (None, [MotionDist 12 45 U_minute (STR ''miles'')])) =
       STR ''[ev:derived] 9 miles. Read as motion: d = r x t = 12 x 0.75 h. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_motion_speed :: bool where
  "c_motion_speed \<longleftrightarrow> response (reply_of (None, [MotionSpeed 150 U_mile (5 / 2) U_hour])) =
       STR ''[ev:derived] 60 miles/h. Read as motion: r = d / t = 150 / 2.5 h. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_rect_area :: bool where
  "c_rect_area \<longleftrightarrow> response (reply_of (None, [RectArea 8 5])) =
       STR ''[ev:derived] 40 square units. Read as geometry: A = L x W = 8 x 5. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_total_cost :: bool where
  "c_total_cost \<longleftrightarrow> response (reply_of (None, [TotalCost 1200 7])) =
       STR ''[ev:derived] $8,400. Read as total cost: total = count x price each = 1200 x 7. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_percent_of_money :: bool where
  "c_percent_of_money \<longleftrightarrow> response (reply_of (None, [PercentOf True 9 (mk_rat 105 100)])) =
       STR ''[ev:derived] $0.09. Read as percent of: 9% of 1.05. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_circle_area :: bool where
  "c_circle_area \<longleftrightarrow> response (reply_of (None, [CircleArea 3 Pi314])) =
       STR ''[ev:derived] 28.26 square units. Read as geometry: A = pi r^2, r = 3. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_sphere_vol :: bool where
  "c_sphere_vol \<longleftrightarrow> response (reply_of (None, [SphereVol 6 Pi314])) =
       STR ''[ev:derived] 904.32 cubic units. Read as geometry: V = (4/3) pi r^3, r = 6. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_percent_of_g :: bool where
  "c_percent_of_g \<longleftrightarrow> response (reply_of (None, [PercentOf False 33 1234567])) =
       STR ''[ev:derived] 407407. Read as percent of: 33% of 1.23457e+06. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"
definition c_empty :: bool where
  "c_empty \<longleftrightarrow> \<not> answered (reply_of (None, []))"
definition c_ambiguous :: bool where
  "c_ambiguous \<longleftrightarrow> \<not> answered (reply_of (None, [PercentOf False 20 50, PercentOfTotal 20 50]))
     \<and> schema (reply_of (None, [PercentOf False 20 50, PercentOfTotal 20 50])) = STR ''ambiguous''"
definition c_tables :: bool where
  "c_tables \<longleftrightarrow> scale U_year = 8766 \<and> scale U_feet = scale U_foot
     \<and> unit_table \<noteq> []"

text \<open>The names of the failing cases, for the build error message.\<close>
definition self_failures :: "String.literal" where
  "self_failures =
     (if c_percent_of then STR '''' else STR ''percent_of '') +
     (if c_convert then STR '''' else STR ''convert '') +
     (if c_simple_interest then STR '''' else STR ''simple_interest '') +
     (if c_percent_of_total then STR '''' else STR ''percent_of_total '') +
     (if c_motion_dist then STR '''' else STR ''motion_dist '') +
     (if c_motion_speed then STR '''' else STR ''motion_speed '') +
     (if c_rect_area then STR '''' else STR ''rect_area '') +
     (if c_total_cost then STR '''' else STR ''total_cost '') +
     (if c_percent_of_money then STR '''' else STR ''percent_of_money '') +
     (if c_circle_area then STR '''' else STR ''circle_area '') +
     (if c_sphere_vol then STR '''' else STR ''sphere_vol '') +
     (if c_percent_of_g then STR '''' else STR ''percent_of_g '') +
     (if c_empty then STR '''' else STR ''empty '') +
     (if c_ambiguous then STR '''' else STR ''ambiguous '') +
     (if c_tables then STR '''' else STR ''tables '')"

definition self_test :: bool where
  "self_test \<longleftrightarrow> self_failures = STR ''''"

text \<open>The driver's entry point: the untrusted SML recognizer holds the
rounding digit count as a target @{type integer}, so it reaches @{const
reply_of} through this wrapper instead of building a @{type nat} itself.\<close>
definition reply_of' :: "integer option \<times> wp list \<Rightarrow> wreply" where
  "reply_of' x = reply_of (map_option nat_of_integer (fst x), snd x)"

export_code reply_of' answered schema response stated mk_rat g6r uname self_test self_failures
  integer_of_int int_of_integer
  unit_table plural_units
  PercentOf Convert SimpleInterest UnitPrice TotalCost SaleOff SalePct
  PercentOfTotal MotionDist MotionSpeed RectArea RectPerim CircleArea
  CircleCirc ConeVol CylVol SphereVol
  Pi314 Pidouble
  Mlength Mmass Mvolume Mtime
  U_second U_sec U_minute U_min U_hour U_hr U_h U_day U_week U_year
  in SML module_name Wordprob file_prefix wordprob

ML \<open>
  val theorems = [@{thm reply_answered_iff}, @{thm response_template},
    @{thm printed_rounds_value}, @{thm printed_rounds_value_percent},
    @{thm stated6_sound}, @{thm stated4_sound}, @{thm round_dec_error},
    @{thm rl_round_dec_bound},
    @{thm round_tie_up}, @{thm round_sig_sound}, @{thm round_at_error},
    @{thm percent_of_value}, @{thm convert_value}, @{thm simple_interest_value},
    @{thm unit_price_value}, @{thm total_cost_value}, @{thm sale_off_value},
    @{thm sale_pct_value}, @{thm percent_of_total_value}, @{thm motion_dist_value},
    @{thm motion_speed_value}, @{thm rect_area_value}, @{thm rect_perim_value},
    @{thm circle_area_value}, @{thm circle_circ_value}, @{thm cone_vol_value},
    @{thm cyl_vol_value}, @{thm sphere_vol_value}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("wordprob theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error ("wordprob self test failed: " ^ @{code self_failures});
  val _ = writeln ("VERI7VN_WORDPROB PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
