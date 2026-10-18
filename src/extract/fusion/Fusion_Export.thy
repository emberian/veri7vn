theory Fusion_Export
  imports Fusion_Nodes "HOL-Library.Code_Target_Numeral"
begin

text \<open>Constructors and readers the untrusted SML driver uses to build typed
givens, goals and contexts from JSON, and to print outcomes. Quantity's fuel
type is written in full: Climate (imported by Fusion_Nodes) has its own.\<close>

definition fz_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "fz_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition fz_num :: "rat \<Rightarrow> integer \<times> integer" where
  "fz_num q = (case quotient_of q of (a, b) \<Rightarrow> (integer_of_int a, integer_of_int b))"

definition fz_dim :: "integer \<Rightarrow> integer \<Rightarrow> integer \<Rightarrow> integer \<Rightarrow> integer \<Rightarrow> integer \<Rightarrow> dimv" where
  "fz_dim a b c d e f = Dim (int_of_integer a) (int_of_integer b) (int_of_integer c)
     (int_of_integer d) (int_of_integer e) (int_of_integer f)"

definition fz_q :: "rat \<Rightarrow> dimv \<Rightarrow> role option \<Rightarrow> integer \<Rightarrow> mark list \<Rightarrow> quantity" where
  "fz_q v d r i ms = \<lparr>amount = v, qdim = d, role = r, origin = Given (nat_of_integer i), marks = ms\<rparr>"

definition fz_ctx :: "material option \<Rightarrow> material option \<Rightarrow> material option \<Rightarrow> Quantity.fuel option \<Rightarrow>
    bool \<Rightarrow> bool \<Rightarrow> bool \<Rightarrow> bool \<Rightarrow> String.literal option \<Rightarrow> bool \<Rightarrow> bool \<Rightarrow> ctx" where
  "fz_ctx ob su fl fu bu co sp fo hm me ga = \<lparr>c_object = ob, c_substance = su, c_fluid = fl, c_fuel = fu,
     c_burn = bu, c_asks_co2 = co, c_spring = sp, c_full_of = fo, c_heat_mat = hm, c_melt = me, c_gasoline = ga\<rparr>"

text \<open>The names network_v3 puts into its phrasings (SUBSTANCES, FLUIDS and
FUELS values) and the lane G table entry the organ reads for each.\<close>
definition v3_materials :: "(String.literal \<times> material) list" where
  "v3_materials = [(STR ''water'', M_water), (STR ''fresh water'', M_water),
     (STR ''sea water'', M_seawater), (STR ''ice'', M_ice), (STR ''aluminium'', M_aluminium),
     (STR ''steel'', M_steel), (STR ''iron'', M_iron), (STR ''copper'', M_copper),
     (STR ''gold'', M_gold), (STR ''silver'', M_silver), (STR ''lead'', M_lead),
     (STR ''concrete'', M_concrete), (STR ''glass'', M_glass), (STR ''petrol'', M_petrol),
     (STR ''diesel'', M_diesel), (STR ''ethanol'', M_ethanol), (STR ''mercury'', M_mercury),
     (STR ''granite'', M_granite), (STR ''brass'', M_brass), (STR ''olive oil'', M_olive_oil),
     (STR ''honey'', M_honey), (STR ''milk'', M_milk)]"

definition v3_fuels :: "(String.literal \<times> Quantity.fuel) list" where
  "v3_fuels = [(STR ''coal'', F_coal), (STR ''lignite'', F_lignite), (STR ''anthracite'', F_anthracite),
     (STR ''charcoal'', F_charcoal), (STR ''wood'', F_wood), (STR ''LPG'', F_lpg),
     (STR ''natural gas'', F_natural_gas), (STR ''diesel'', Quantity.fuel.F_diesel), (STR ''petrol'', F_petrol),
     (STR ''jet fuel'', F_jet_fuel)]"

definition v3_material :: "String.literal \<Rightarrow> material option" where
  "v3_material s = map_option snd (find (\<lambda>x. fst x = s) v3_materials)"

definition v3_fuel :: "String.literal \<Rightarrow> Quantity.fuel option" where
  "v3_fuel s = map_option snd (find (\<lambda>x. fst x = s) v3_fuels)"

fun fop_name :: "fop \<Rightarrow> String.literal" where
  "fop_name Mass_of_volume = STR ''mass_of_volume''" | "fop_name Volume_of_mass = STR ''volume_of_mass''"
| "fop_name Gauge_pressure = STR ''gauge_pressure''" | "fop_name Buoyant_force = STR ''buoyant_force''"
| "fop_name Spring_force = STR ''spring_force''" | "fop_name Spring_energy = STR ''spring_energy''"
| "fop_name Fuel_energy = STR ''fuel_energy''" | "fop_name Fuel_co2_mass = STR ''fuel_co2_mass''"
| "fop_name Surface_gravity = STR ''surface_gravity''" | "fop_name Sensible_heat = STR ''sensible_heat''"
| "fop_name Melt_ice = STR ''melt_ice''" | "fop_name Gasoline_co2 = STR ''fuel_co2''"
| "fop_name Planet_weight = STR ''planet_weight''"

fun snode_name :: "snode \<Rightarrow> String.literal" where
  "snode_name Nd_densities = STR ''densities''" | "snode_name Nd_fluids = STR ''fluids''"
| "snode_name Nd_springs = STR ''springs''" | "snode_name Nd_fuels = STR ''fuels''"
| "snode_name Nd_thermo = STR ''thermo''" | "snode_name Nd_carboncapture = STR ''carboncapture''"
| "snode_name Nd_planetary = STR ''planetary''"

definition fz_node :: "fop \<Rightarrow> String.literal" where
  "fz_node f = snode_name (node_of f)"

text \<open>The pool after running a plan (givens, then each step's value).\<close>
definition fz_trace :: "ctx \<Rightarrow> quantity list \<Rightarrow> step list \<Rightarrow> rat list" where
  "fz_trace c p pl = (case run_plan fnode ops_all c p (start_st p) pl of
     Some s \<Rightarrow> map amount (pool s) | None \<Rightarrow> [])"

definition no_ctx :: ctx where
  "no_ctx = fz_ctx None None None None False False False False None False False"

definition fz_self_test :: bool where
  "fz_self_test \<longleftrightarrow>
     \<comment> \<open>40 litres of diesel burnt, energy in MJ: densities then fuels then core math\<close>
     fdecide Pairwise (GDim d_energy 1000000 False)
       (fz_ctx (Some M_diesel) (Some M_diesel) None (Some Quantity.fuel.F_diesel) True False False False None False False)
       [\<lparr>amount = 1 / 25, qdim = d_vol, role = None, origin = Given 0, marks = [Of_material, Of_fuel]\<rparr>]
       = Answer (FVal 1431) [Step Mass_of_volume [Pool 0], Step Fuel_energy [Pool 1]] \<and>
     \<comment> \<open>a 20 kg block of copper fully submerged in water: buoyant force (an op goal)\<close>
     fdecide Pairwise (GDim d_force 1 True)
       (fz_ctx (Some M_copper) None (Some M_water) None False False False False None False False)
       [\<lparr>amount = 20, qdim = d_mass, role = None, origin = Given 0, marks = [Of_material]\<rparr>]
       = Answer (FVal (2196 / 100)) [Step Volume_of_mass [Pool 0], Step Buoyant_force [Pool 1]] \<and>
     \<comment> \<open>2 kW, 6 hours a day, 30 days, 0.15 dollars per kWh: core math alone, 54 dollars\<close>
     fdecide Pairwise (GDim d_money 1 False) no_ctx
       [\<lparr>amount = 15 / 100 / 3600000, qdim = Dim (-2) (-1) 2 0 0 1, role = Some (Ro_tag STR ''price''), origin = Given 0, marks = []\<rparr>,
        \<lparr>amount = 1 / 4, qdim = d_one, role = Some Ro_duty, origin = Given 1, marks = []\<rparr>,
        \<lparr>amount = 2000, qdim = d_power, role = None, origin = Given 2, marks = []\<rparr>,
        \<lparr>amount = 2592000, qdim = d_time, role = None, origin = Given 3, marks = []\<rparr>]
       = Answer (FVal 54) [] \<and>
     \<comment> \<open>one given converted to another unit: the core's own operator\<close>
     fdecide Pairwise (GDim d_mass 1 False) no_ctx
       [\<lparr>amount = 5, qdim = d_mass, role = None, origin = Given 0, marks = []\<rparr>] = SingleConversion \<and>
     \<comment> \<open>26 hours a day is more than the whole day\<close>
     fdecide Pairwise (GDim d_energy 3600000 False) no_ctx
       [\<lparr>amount = 26 / 24, qdim = d_one, role = Some Ro_duty, origin = Given 0, marks = []\<rparr>,
        \<lparr>amount = 2000, qdim = d_power, role = None, origin = Given 1, marks = []\<rparr>] = Invalid 0 1 \<and>
     \<comment> \<open>heating water with no material for the thermo phrasing: no plan\<close>
     fdecide Pairwise (GDim d_energy 3600000 False)
       (fz_ctx None (Some M_water) (Some M_water) None False False False False None False False)
       [\<lparr>amount = 4, qdim = d_mass, role = None, origin = Given 0, marks = [Of_material]\<rparr>,
        \<lparr>amount = 28815 / 100, qdim = d_temp, role = Some Ro_temp, origin = Given 1, marks = []\<rparr>,
        \<lparr>amount = 34815 / 100, qdim = d_temp, role = Some Ro_temp, origin = Given 2, marks = []\<rparr>] = NoPlan \<and>
     \<comment> \<open>heat 4 kg of water from 15 C to 75 C, in kWh: thermo states 1.005e6 J\<close>
     fdecide Pairwise (GDim d_energy 3600000 False) (fz_ctx None None None None False False False False (Some STR ''water'') False False)
       [\<lparr>amount = 4, qdim = d_mass, role = None, origin = Given 0, marks = [Of_material]\<rparr>,
        \<lparr>amount = 28815 / 100, qdim = d_temp, role = Some Ro_temp, origin = Given 1, marks = []\<rparr>,
        \<lparr>amount = 34815 / 100, qdim = d_temp, role = Some Ro_temp, origin = Given 2, marks = []\<rparr>]
       = Answer (FVal (1005000 / 3600000)) [Step Sensible_heat [Pool 0, Pool 1, Pool 2]] \<and>
     \<comment> \<open>the same temperatures named the other way round: cooling, no plan\<close>
     fdecide Pairwise (GDim d_energy 3600000 False) (fz_ctx None None None None False False False False (Some STR ''water'') False False)
       [\<lparr>amount = 4, qdim = d_mass, role = None, origin = Given 0, marks = [Of_material]\<rparr>,
        \<lparr>amount = 34815 / 100, qdim = d_temp, role = Some Ro_temp, origin = Given 1, marks = []\<rparr>,
        \<lparr>amount = 28815 / 100, qdim = d_temp, role = Some Ro_temp, origin = Given 2, marks = []\<rparr>] = NoPlan \<and>
     \<comment> \<open>melt 8 kg of ice, in kWh: 2.672e6 J\<close>
     fdecide Pairwise (GDim d_energy 3600000 False) (fz_ctx None None None None False False False False None True False)
       [\<lparr>amount = 8, qdim = d_mass, role = None, origin = Given 0, marks = []\<rparr>]
       = Answer (FVal (2672000 / 3600000)) [Step Melt_ice [Pool 0]] \<and>
     \<comment> \<open>25 mpg over 350 miles, kg of CO2: core math gives 14 gallons, carboncapture 124.418 kg\<close>
     fdecide Pairwise (GDim d_mass 1 False) (fz_ctx None None None None False True False False None False True)
       [\<lparr>amount = 25 * (1609344 / 1000) / (3785411784 / 1000000000000), qdim = Dim (-2) 0 0 0 0 0, role = None, origin = Given 0, marks = []\<rparr>,
        \<lparr>amount = 350 * (1609344 / 1000), qdim = d_len, role = None, origin = Given 1, marks = []\<rparr>]
       = Answer (FVal (124418 / 1000)) [Step Gasoline_co2 [Derive 0 1]] \<and>
     \<comment> \<open>75 kg on 2 Earth masses and 1.3 Earth radii: surface gravity 11.6095 times 75 kg (870.7125 N) and
        planet weight 870.7101 N agree; the first plan in catalogue order is stated\<close>
     fdecide Pairwise (GDim d_force 1 False) no_ctx
       [\<lparr>amount = 75, qdim = d_mass, role = None, origin = Given 0, marks = []\<rparr>,
        \<lparr>amount = 2, qdim = d_one, role = Some Ro_earth_mass, origin = Given 1, marks = []\<rparr>,
        \<lparr>amount = 13 / 10, qdim = d_one, role = Some Ro_earth_radius, origin = Given 2, marks = []\<rparr>]
       = Answer (FVal (8707125 / 10000)) [Step Surface_gravity [Pool 1, Pool 2]] \<and>
     fz_trace no_ctx
       [\<lparr>amount = 75, qdim = d_mass, role = None, origin = Given 0, marks = []\<rparr>,
        \<lparr>amount = 2, qdim = d_one, role = Some Ro_earth_mass, origin = Given 1, marks = []\<rparr>,
        \<lparr>amount = 13 / 10, qdim = d_one, role = Some Ro_earth_radius, origin = Given 2, marks = []\<rparr>]
       [Step Planet_weight [Pool 0, Pool 1, Pool 2]] = [75, 2, 13 / 10, 8707101 / 10000] \<and>
     agree Anchor [FVal (502 / 5), FVal 100, FVal (504 / 5)] \<and>
     \<not> agree Pairwise [FVal (502 / 5), FVal 100, FVal (504 / 5)] \<and>
     v3_material STR ''fresh water'' = Some M_water \<and> v3_fuel STR ''LPG'' = Some F_lpg"

export_code fdecide fz_trace fz_rat fz_num fz_dim fz_q fz_ctx v3_material v3_fuel fop_name fz_node
  fz_self_test integer_of_nat nat_of_integer
  Anchor Pairwise GDim GBool GCount
  Ro_delta Ro_duty Ro_derived Ro_co2 Ro_temp Ro_per_unit Ro_earth_mass Ro_earth_radius Ro_out Ro_tag
  Of_material Of_fuel Depth_of
  Answer Disagree NoPlan BudgetExceeded SingleConversion Invalid
  FVal FBool Pool Derive Step
  in SML module_name Fusion file_prefix fusion

ML \<open>
  val theorems = [@{thm zero_magnitude_admitted}, @{thm zero_body_rejected},
    @{thm duty_outside_closed_interval}, @{thm nonnegative_duty_admitted},
    @{thm zero_power_product}, @{thm zero_time_denominator},
    @{thm nonpositive_goal_factor_no_finish}, @{thm core_eval_sound}, @{thm every_given_used_once},
    @{thm answer_has_complete_plan}, @{thm depth_bound}, @{thm search_complete},
    @{thm answer_all_shallowest_agree}, @{thm disagreement_never_picked}, @{thm decide_on_search},
    @{thm pairwise_order_independent}, 
    @{thm single_conversion_not_answer}, @{thm echo_not_answer}, @{thm op_goal_needs_operation},
    @{thm answer_uses_givens_once}, @{thm phrase_sound}, @{thm qnode_sound},
    @{thm fnode_lane_g}, @{thm sensible_heat_node}, @{thm melt_ice_node}, @{thm gasoline_co2_node},
    @{thm surface_gravity_node}, @{thm planet_weight_node}]
    @ @{thms anchor_three_plans} @ @{thms memory_never_decides} @ @{thms agree_not_transitive_counterexample};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("fusion theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code fz_self_test} then () else error "fusion self test failed";
  val marker = "VERI7VN_FUSION PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0";
  val _ = writeln marker;
  (* The session log of this build can come back empty (Isabelle2026-RC1); check-native also reads
     explicit veri7vn/assertions exports, written only after the checks above. *)
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/fusion")) [XML.Text marker];
\<close>

end
