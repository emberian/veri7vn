theory Stores_Export
  imports Stores
begin

text \<open>Constructors the untrusted SML driver uses to build requests and rows
from decimal numerals it read off the text or the store.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition mk_int :: "integer \<Rightarrow> int" where
  "mk_int a = int_of_integer a"

definition mk_nat :: "integer \<Rightarrow> nat" where
  "mk_nat a = nat_of_integer a"

text \<open>Whether the site organ took the turn (it returns None otherwise).\<close>
definition site_taken :: "soutcome \<Rightarrow> bool" where
  "site_taken o' \<longleftrightarrow> taken o'"

definition site_reply :: "sstate \<Rightarrow> intent \<Rightarrow> sev \<Rightarrow> reply \<times> sstate \<times> soutcome" where
  "site_reply s i ev = (case sstep s i ev of (o', s') \<Rightarrow> (sreply o', s', o'))"

definition ordered_of :: "soutcome \<Rightarrow> (nat \<times> item) option" where
  "ordered_of o' = (case o' of SO_ordered n it \<Rightarrow> Some (n, it) | _ \<Rightarrow> None)"

definition unknown_what :: "soutcome \<Rightarrow> String.literal option" where
  "unknown_what o' = (case o' of SO_unknown_item w b \<Rightarrow> Some w | _ \<Rightarrow> None)"

definition q1 :: nquery where
  "q1 = NQ N_protein (A_mass 2 (STR ''oz'') MU_oz) (STR ''raw chayote'') (Some (170402, STR ''Chayote, fruit, raw''))
     [(170402, STR ''Chayote, fruit, raw'')] [(170402, 82 / 100, STR ''g'')] [] [] True"

definition q2 :: nquery where
  "q2 = NQ N_sodium (A_measure 1 (STR ''a'') (STR ''cup'') M_cup) (STR ''x'') (Some (1, STR ''X''))
     [(1, STR ''X''), (2, STR ''Y'')] [(1, 100, STR ''mg''), (2, 50, STR ''mg'')] [] [] True"

definition q3 :: nquery where
  "q3 = NQ N_sodium (A_measure 1 (STR ''a'') (STR ''cup'') M_cup) (STR ''x'') (Some (1, STR ''X''))
     [(1, STR ''X''), (2, STR ''Y'')] [(1, 100, STR ''mg''), (2, 90, STR ''mg'')]
     [(STR ''1 cup, chopped'', 150), (STR ''1 Cup'', 140), (STR ''1 tbsp'', 9)] [] True"

definition q4 :: nquery where
  "q4 = NQ N_calories (A_count 2 (STR ''2'') (STR ''bananas'')) (STR ''banana'') (Some (1, STR ''Bananas, raw''))
     [(1, STR ''Bananas, raw'')] [(1, 89, STR ''kcal'')]
     [(STR ''1 cup, mashed'', 225), (STR ''1 extra small'', 81), (STR ''1 medium (7 to 7-7/8 long)'', 118)] [] True"

definition ev0 :: sev where
  "ev0 = SEv 1000000 30 [(0, 10), (900000, -7)] 5 (Some (STR ''A1-01'', STR ''Aisle 1'')) None
     (Some ((STR ''C'', 15, 26), [(999000, 305 / 10), (100, 20)])) [] [(STR ''b'', 5, [3]), (STR ''a'', 4, [4])]
     (400, 10, 49, []) [] True"

definition it0 :: item where "it0 = (STR ''SKU1'', STR ''M4 valve'')"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     nkernel q1 = NAnswer (2 * 283495 / 10000) (82 / 100) (82 / 100 * (2 * 283495 / 10000) / 100) None \<and>
     stated (nreply q1) = Some (STR ''0.46'') \<and>
     response (nreply q1) = STR ''2 oz of raw chayote has 0.46 g of protein (USDA SR Legacy #170402: Chayote, fruit, raw; 0.82 g per 100 g).'' \<and>
     nkernel q2 = NDecline ND_clarify \<and>
     nkernel q3 = NDecline ND_serving_ambiguous \<and>
     reply_status (nreply q3) = STR ''clarify'' \<and>
     nkernel q4 = NAnswer 236 89 (89 * 236 / 100) (Some (STR ''1 medium (7 to 7-7/8 long)'')) \<and>
     reply_status (nreply q2) = STR ''clarify'' \<and>
     show_g (566990 / 10000) = STR ''56.699'' \<and> show_g 100 = STR ''100'' \<and> show_g (1 / 3) = STR ''0.333333'' \<and>
     show_g 1234567 = STR ''1.23457e+06'' \<and> render_fixed 1 30 = STR ''3.0'' \<and> render_fixed 2 5 = STR ''0.05'' \<and>
     fst (sstep s0 (I_confirm True R_off_site) ev0) = SO_off_site \<and>
     fst (sstep s0 (I_read (R_reorder 5 (Some it0) (STR ''M4 valve''))) ev0) = SO_confirm 5 it0 3 \<and>
     fst (sstep (snd (sstep s0 (I_read (R_reorder 5 (Some it0) (STR ''M4 valve''))) ev0)) (I_confirm True R_off_site) ev0)
       = SO_ordered 5 it0 \<and>
     fst (sstep s0 (I_read (R_runout it0)) ev0) = SO_runout (STR ''M4 valve'') 3 1 3 \<and>
     fst (sstep s0 (I_read (R_sensor (1, STR ''Aisle 1'') SK_temperature False)) ev0)
       = SO_sensor (STR ''Aisle 1'') SK_temperature (STR ''C'') (305 / 10) 15 26 (50 / 3) False \<and>
     response (sreply (fst (sstep s0 (I_read (R_sensor (1, STR ''Aisle 1'') SK_temperature False)) ev0))) =
       STR ''Aisle 1 temperature is 30.5 C, above its normal 15-26 C, read 17 minutes ago.'' \<and>
     fst (sstep s0 (I_read (R_sensor (1, STR ''Aisle 1'') SK_temperature False)) (SEv 1000000 10 [] 0 None None
        (Some ((STR ''C'', 15, 26), [(999000, 20)])) [] [] (0, 0, 0, []) [] True))
       = SO_stale (STR ''Aisle 1'') SK_temperature (50 / 3) \<and>
     response (sreply (SO_low (low_rows (ev_items ev0)))) =
       STR ''2 items are at or below reorder level: a (4, reorder at 4)''
       + STR ''; b (3, reorder at 5).''"

export_code nreply nkernel answered reply_status reply_kind response stated
  site_reply site_taken ordered_of unknown_what s0 SState s_pending s_item s_zone s_kind s_last
  mk_rat mk_int mk_nat self_test integer_of_int int_of_integer nat_of_integer integer_of_nat
  nutrient_order nutrient_key nutrient_unit mass_names measure_names measure_key skind_order skind_key
  NQ A_default A_mass A_measure A_count
  SEv I_read I_confirm R_self R_neighbour R_reorder R_low R_where R_runout R_stock R_zone_status R_sensor
  R_unknown_item R_kind_only R_off_site R_none SL_none SL_item SL_sensor SL_zone_status
  in SML module_name Stores file_prefix stores

ML \<open>
  val theorems = [@{thm first_min_Some}, @{thm first_min_tie_first}, @{thm round_dp_sound},
    @{thm nutrient_serving_alternatives}, @{thm nutrient_answer_covered}, @{thm nutrient_portion_real}, @{thm grams_pos}, @{thm stale_mono},
    @{thm nutrient_answer_sound}, @{thm nutrient_requires_complete}, @{thm nutrient_value},
    @{thm nutrient_default_grams}, @{thm nutrient_mass_grams}, @{thm nutrient_measure_portion},
    @{thm nutrient_count_portion}, @{thm nutrient_readings_agree}, @{thm nutrient_unknown_food},
    @{thm nutrient_no_value}, @{thm nutrient_clarify}, @{thm nutrient_no_portion}, @{thm amount_grams_none},
    @{thm nutrient_incomplete}, @{thm stated_within_tolerance}, @{thm nreply_answered_iff}, @{thm nreply_states},
    @{thm confirm_requires_proposal}, @{thm confirm_without_proposal_refused}, @{thm confirm_consumes},
    @{thm no_double_order}, @{thm propose_sets_pending}, @{thm propose_idempotent},
    @{thm reading_keeps_proposal}, @{thm incomplete_fetch_declines}, @{thm latest_Some},
    @{thm sensor_fresh}, @{thm stale_declines}, @{thm zone_parts_fresh}, @{thm stock_value},
    @{thm runout_days}, @{thm low_exact}, @{thm low_sorted}, @{thm stale_not_answered},
    @{thm sensor_reply_states_value}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("stores theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "stores self test failed";
  val marker = "VERI7VN_STORES PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0";
  val _ = writeln marker;
  (* explicit assertion export: RC1 may omit a successful session's messages from its build log *)
  val _ = Export.export @{theory} (Path.binding0 (Path.make ["veri7vn", "assertions", "stores"])) [XML.Text marker];
\<close>

end
