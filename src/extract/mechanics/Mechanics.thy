theory Mechanics
  imports Mech_Num
begin

text \<open>
  Nine shipped Oracle7 specialists (physics, physics-r2, physics-r3,
  mechanisms, mechanisms-v2, bodies-v2, sports, fleet, fluids-r2:
  upstream/root/specialists/<id>/organ_*.py) as one verified HOL kernel.
  The untrusted recognizer reads numbers and words off the question and builds
  a typed request; this theory decides what the request means: an exact
  rational value, a decimal enclosure (for square roots, pi and sine, via
  Isabelle's verified interval arithmetic), or a decline. Tables and constants
  are HOL constants transcribed from the organs; tables_check.py compares
  them with the organ files.
\<close>

section \<open>Constants, units and tables\<close>

definition g0 :: rat where "g0 = 980665 / 100000"
definition p0 :: rat where "p0 = 101325"
definition l_per_gal :: rat where "l_per_gal = 3785411784 / 1000000000"
definition km_per_mi :: rat where "km_per_mi = 1609344 / 1000000"
definition uk_gal_litres :: rat where "uk_gal_litres = 454609 / 100000"
definition lpk_us :: rat where "lpk_us = 2352146 / 10000"
definition lpk_uk :: rat where "lpk_uk = 2824809 / 10000"
definition co2_gasoline :: rat where "co2_gasoline = 8887"
definition co2_diesel :: rat where "co2_diesel = 10180"

lemma g0_pos [simp]: "0 < g0" by (simp add: g0_def)
lemma g0_nz [simp]: "g0 \<noteq> 0" by (simp add: g0_def)

datatype speedu = SU_kmh | SU_mph | SU_ms
fun speed_scale :: "speedu \<Rightarrow> rat" where
  "speed_scale SU_kmh = 5 / 18"
| "speed_scale SU_mph = 44704 / 100000"
| "speed_scale SU_ms = 1"

datatype lenu = LU_m | LU_cm | LU_mm | LU_ft | LU_in | LU_yd | LU_mi
fun len_scale :: "lenu \<Rightarrow> rat" where
  "len_scale LU_m = 1" | "len_scale LU_cm = 1 / 100" | "len_scale LU_mm = 1 / 1000"
| "len_scale LU_ft = 381 / 1250" | "len_scale LU_in = 127 / 5000"
| "len_scale LU_yd = 1143 / 1250" | "len_scale LU_mi = 201168 / 125"

definition length_m :: "rat \<Rightarrow> lenu \<Rightarrow> rat" where
  "length_m x u = x * len_scale u"

lemma len_scale_pos [simp]: "0 < len_scale u"
  by (cases u) simp_all

lemma length_m_pos [simp]: "0 < length_m x u \<longleftrightarrow> 0 < x"
  using len_scale_pos[of u]
  by (auto simp: length_m_def zero_less_mult_iff; linarith)

text \<open>Mass magnitudes retain their declared exact unit through conversion to kg.
The pound is the international avoirdupois pound; tonne means 1000 kg.\<close>
datatype massu = MU_kg | MU_g | MU_tonne | MU_lb
fun mass_scale :: "massu \<Rightarrow> rat" where
  "mass_scale MU_kg = 1" | "mass_scale MU_g = 1 / 1000"
| "mass_scale MU_tonne = 1000" | "mass_scale MU_lb = 45359237 / 100000000"
definition mass_kg :: "rat \<Rightarrow> massu \<Rightarrow> rat" where
  "mass_kg m u = m * mass_scale u"
lemma mass_scale_pos [simp]: "0 < mass_scale u"
  by (cases u) simp_all
lemma mass_kg_nonnegative [simp]: "0 \<le> mass_kg m u \<longleftrightarrow> 0 \<le> m"
  using mass_scale_pos[of u]
  by (auto simp: mass_kg_def zero_le_mult_iff; linarith)

datatype volu = VU_m3 | VU_l | VU_cm3
fun vol_scale :: "volu \<Rightarrow> rat" where
  "vol_scale VU_m3 = 1" | "vol_scale VU_l = 1 / 1000" | "vol_scale VU_cm3 = 1 / 1000000"

datatype distu = DU_mi | DU_km
datatype loadu = LD_n | LD_kg

definition spd :: "rat \<times> speedu \<Rightarrow> rat" where "spd a = fst a * speed_scale (snd a)"
definition vol_m3 :: "rat \<times> volu \<Rightarrow> rat" where "vol_m3 a = fst a * vol_scale (snd a)"
definition load_n :: "rat \<times> loadu \<Rightarrow> rat" where
  "load_n a = (case snd a of LD_n \<Rightarrow> fst a | LD_kg \<Rightarrow> fst a * g0)"

datatype mfluid = MF_water | MF_seawater | MF_mercury | MF_petrol | MF_diesel | MF_ethanol
  | MF_olive_oil | MF_honey | MF_milk

fun fluid_density :: "mfluid \<Rightarrow> rat" where
  "fluid_density MF_water = 1000" | "fluid_density MF_seawater = 1025"
| "fluid_density MF_mercury = 135336 / 10" | "fluid_density MF_petrol = 745"
| "fluid_density MF_diesel = 832" | "fluid_density MF_ethanol = 789"
| "fluid_density MF_olive_oil = 911" | "fluid_density MF_honey = 1420"
| "fluid_density MF_milk = 1030"

fun fluid_name :: "mfluid \<Rightarrow> String.literal" where
  "fluid_name MF_water = STR ''fresh water''" | "fluid_name MF_seawater = STR ''sea water''"
| "fluid_name MF_mercury = STR ''mercury''" | "fluid_name MF_petrol = STR ''petrol''"
| "fluid_name MF_diesel = STR ''diesel''" | "fluid_name MF_ethanol = STR ''ethanol''"
| "fluid_name MF_olive_oil = STR ''olive oil''" | "fluid_name MF_honey = STR ''honey''"
| "fluid_name MF_milk = STR ''milk''"

definition fluid_order :: "mfluid list" where
  "fluid_order = [MF_water, MF_seawater, MF_mercury, MF_petrol, MF_diesel, MF_ethanol,
                  MF_olive_oil, MF_honey, MF_milk]"

lemma fluid_density_pos [simp]: "0 < fluid_density f"
  by (cases f) simp_all

datatype msolid = MS_ice | MS_aluminium | MS_steel | MS_concrete | MS_glass | MS_granite
  | MS_iron | MS_copper | MS_gold | MS_lead | MS_brass

fun solid_density :: "msolid \<Rightarrow> rat" where
  "solid_density MS_ice = 917" | "solid_density MS_aluminium = 2700"
| "solid_density MS_steel = 7850" | "solid_density MS_concrete = 2400"
| "solid_density MS_glass = 2500" | "solid_density MS_granite = 2700"
| "solid_density MS_iron = 7874" | "solid_density MS_copper = 8933"
| "solid_density MS_gold = 19282" | "solid_density MS_lead = 11342"
| "solid_density MS_brass = 8500"

fun solid_name :: "msolid \<Rightarrow> String.literal" where
  "solid_name MS_ice = STR ''ice''" | "solid_name MS_aluminium = STR ''aluminium''"
| "solid_name MS_steel = STR ''steel''" | "solid_name MS_concrete = STR ''concrete''"
| "solid_name MS_glass = STR ''glass''" | "solid_name MS_granite = STR ''granite''"
| "solid_name MS_iron = STR ''iron''" | "solid_name MS_copper = STR ''copper''"
| "solid_name MS_gold = STR ''gold''" | "solid_name MS_lead = STR ''lead''"
| "solid_name MS_brass = STR ''brass''"

definition solid_order :: "msolid list" where
  "solid_order = [MS_ice, MS_aluminium, MS_steel, MS_concrete, MS_glass, MS_granite,
                  MS_iron, MS_copper, MS_gold, MS_lead, MS_brass]"

lemma solid_density_pos [simp]: "0 < solid_density s"
  by (cases s) simp_all

datatype mbody = MB_mercury | MB_venus | MB_earth | MB_moon | MB_mars | MB_jupiter | MB_saturn
  | MB_uranus | MB_neptune | MB_pluto | MB_sun | MB_ceres | MB_io | MB_europa | MB_ganymede
  | MB_callisto | MB_titan | MB_triton | MB_enceladus

fun body_gravity :: "mbody \<Rightarrow> rat" where
  "body_gravity MB_mercury = 37 / 10" | "body_gravity MB_venus = 887 / 100"
| "body_gravity MB_earth = 980665 / 100000" | "body_gravity MB_moon = 162 / 100"
| "body_gravity MB_mars = 371 / 100" | "body_gravity MB_jupiter = 2479 / 100"
| "body_gravity MB_saturn = 1044 / 100" | "body_gravity MB_uranus = 887 / 100"
| "body_gravity MB_neptune = 1115 / 100" | "body_gravity MB_pluto = 62 / 100"
| "body_gravity MB_sun = 274" | "body_gravity MB_ceres = 28 / 100"
| "body_gravity MB_io = 1796 / 1000" | "body_gravity MB_europa = 1314 / 1000"
| "body_gravity MB_ganymede = 1428 / 1000" | "body_gravity MB_callisto = 1235 / 1000"
| "body_gravity MB_titan = 1352 / 1000" | "body_gravity MB_triton = 779 / 1000"
| "body_gravity MB_enceladus = 113 / 1000"

fun body_name :: "mbody \<Rightarrow> String.literal" where
  "body_name MB_mercury = STR ''Mercury''" | "body_name MB_venus = STR ''Venus''"
| "body_name MB_earth = STR ''Earth''" | "body_name MB_moon = STR ''the Moon''"
| "body_name MB_mars = STR ''Mars''" | "body_name MB_jupiter = STR ''Jupiter''"
| "body_name MB_saturn = STR ''Saturn''" | "body_name MB_uranus = STR ''Uranus''"
| "body_name MB_neptune = STR ''Neptune''" | "body_name MB_pluto = STR ''Pluto''"
| "body_name MB_sun = STR ''the Sun''" | "body_name MB_ceres = STR ''Ceres''"
| "body_name MB_io = STR ''Io''" | "body_name MB_europa = STR ''Europa''"
| "body_name MB_ganymede = STR ''Ganymede''" | "body_name MB_callisto = STR ''Callisto''"
| "body_name MB_titan = STR ''Titan''" | "body_name MB_triton = STR ''Triton''"
| "body_name MB_enceladus = STR ''Enceladus''"

definition body_order :: "mbody list" where
  "body_order = [MB_mercury, MB_venus, MB_earth, MB_moon, MB_mars, MB_jupiter, MB_saturn,
    MB_uranus, MB_neptune, MB_pluto, MB_sun, MB_ceres, MB_io, MB_europa, MB_ganymede,
    MB_callisto, MB_titan, MB_triton, MB_enceladus]"

text \<open>The gravity a bodies question works under: a named body's surface
gravity, or a value the question states (m/s^2).\<close>
datatype mgrav = G_body mbody | G_stated rat

fun g_of :: "mgrav \<Rightarrow> rat" where
  "g_of (G_body b) = body_gravity b"
| "g_of (G_stated x) = x"

datatype gravity_unit = GU_ms2 | GU_fts2 | GU_standard
fun gravity_scale :: "gravity_unit \<Rightarrow> rat" where
  "gravity_scale GU_ms2 = 1"
| "gravity_scale GU_fts2 = 381 / 1250"
| "gravity_scale GU_standard = g0"
definition gravity_si :: "rat \<Rightarrow> gravity_unit \<Rightarrow> rat" where
  "gravity_si x u = x * gravity_scale u"
lemma gravity_scale_positive [simp]: "0 < gravity_scale u"
  by (cases u) simp_all
lemma gravity_si_nonnegative [simp]: "0 \<le> gravity_si x u \<longleftrightarrow> 0 \<le> x"
  using gravity_scale_positive[of u]
  by (auto simp: gravity_si_def zero_le_mult_iff; linarith)

fun grav_where :: "mgrav \<Rightarrow> String.literal" where
  "grav_where (G_body b) = STR ''on '' + body_name b"
| "grav_where (G_stated x) = STR ''at g = '' + show4 x + STR '' m/s^2''"

text \<open>Fuel economy: US or UK miles per gallon, or litres per 100 km.\<close>
datatype econ = E_mpg bool rat | E_lpk rat

text \<open>The economy's gallon, requested volume and price denominator are
independent source roles. Output and price use these exact volume scales.\<close>
datatype fuel_unit = FU_us_gallon | FU_imperial_gallon | FU_litre
fun fuel_scale :: "fuel_unit \<Rightarrow> rat" where
  "fuel_scale FU_us_gallon = l_per_gal"
| "fuel_scale FU_imperial_gallon = uk_gal_litres"
| "fuel_scale FU_litre = 1"
fun fuel_name :: "fuel_unit \<Rightarrow> String.literal" where
  "fuel_name FU_us_gallon = STR ''US gallons''"
| "fuel_name FU_imperial_gallon = STR ''Imperial gallons''"
| "fuel_name FU_litre = STR ''L''"
lemma fuel_scale_pos [simp]: "0 < fuel_scale u"
  by (cases u) (simp_all add: l_per_gal_def uk_gal_litres_def)
lemma fuel_scale_nz [simp]: "fuel_scale u \<noteq> 0"
  by (cases u) (simp_all add: l_per_gal_def uk_gal_litres_def)
lemma l_per_gal_nz [simp]: "l_per_gal \<noteq> 0"
  by (simp add: l_per_gal_def)

section \<open>Requests, outcomes, declines\<close>

text \<open>Efficiency is useful output work divided by input work. Geometry gives
input travel divided by output travel; it does not change with energy losses.
The load retains its source unit until the checked work model converts it.\<close>
datatype work_request = W_pulley_ma rat | W_lever_ma rat rat
  | W_pulley_effort rat "rat \<times> loadu"
  | W_lever_effort rat rat "rat \<times> loadu"
  | W_gear_torque rat rat rat | W_incline_ma rat rat
  | W_gear_ratio rat rat | W_gear_speed rat rat rat | W_belt_speed rat rat rat | W_pulley_ideal rat | W_lever_ideal rat rat | W_incline_ideal rat rat

datatype request =
    PhRange "rat option" "rat option"
  | PhImpact rat
  | PhFall rat
  | PhKE "rat option" "rat option"
  | PhPE "rat option" "rat option"
  | PhPEAt mgrav "rat option" "rat option" | PhModelLimit
  | PhMomentum "rat option" "rat option"
  | PhWeight rat
  | PhForce "rat option" "rat option"
  | PhWork rat rat
  | PhPower rat rat
  | PhFinalV "rat option" "rat option" "rat option" bool
  | PhDistance rat rat "rat option" bool
  | BdWeight mgrav "rat option"
  | BdFall mgrav "rat option"
  | BdImpact mgrav "rat option"
  | BdPendulum mgrav "rat option"
  | BdUnreadable mgrav | FsModelLimit
  | McGearRatio rat rat
  | McGearSpeed rat rat rat
  | McGearTorque rat rat rat
  | McBeltSpeed rat rat rat
  | McPulleyMA rat
  | McPulleyEffort rat "rat \<times> loadu"
  | McLeverMA rat rat
  | McLeverEffort rat rat "(rat \<times> loadu) option"
  | McInclineMA rat rat
  | McShaftPower rat rat
  | McTorque rat rat lenu
  | McTorqueAngle rat rat lenu rat
  | McWork work_request rat
  | McNeed nat
  | SpPasser rat rat rat rat rat
  | SpTrueShooting rat rat rat
  | SpEra rat rat rat
  | SpWhip rat rat rat rat
  | SpAvg rat rat
  | SpObp rat rat rat rat rat
  | SpSlg "rat option" rat rat rat rat rat
  | SpGamesBehind rat rat rat rat
  | SpWinPct rat rat rat
  | FvBraking "(rat \<times> speedu) option" "rat option"
  | FvStopping "(rat \<times> speedu) option" "rat option" "rat option"
  | FvToLpk bool rat
  | FvToMpg bool rat
  | FvCO2 rat distu econ bool
  | FvCost rat distu econ "(rat \<times> fuel_unit) option"
  | FvVolume rat distu econ fuel_unit
  | FvNeed
  | FsGauge mfluid "rat option"
  | FsAbs mfluid "rat option"
  | FsBuoyant mfluid "(rat \<times> volu) option"
  | FsSubmerged msolid mfluid

text \<open>The mechanisms organ's own underspecified declines (which gear drives
which, the arm lengths, ...) are the requests @{text "McNeed n"}; the number
selects the sentence (see @{text need_text}).\<close>

datatype need = N_speed_angle | N_mass_speed | N_mass_height | N_mass_velocity | N_mass_accel
  | N_accel_time | N_start_speed | N_mass_kg | N_fall_height | N_pendulum_length
  | N_fuel | N_mc_need nat | N_load | N_speed_friction | N_reaction | N_price | N_depth | N_volume
  | N_unreadable | N_fluid_conditions | N_physics_conditions

datatype reason = R_nonpositive_gravity | R_negative_gravity | R_negative_amount | R_zero_time | R_zero_teeth
  | R_zero_diameter | R_zero_strands | R_zero_arm | R_ramp | R_zero_attempts | R_zero_shooting
  | R_bad_innings | R_zero_innings | R_zero_at_bats | R_zero_games | R_friction
  | R_zero_economy | R_zero_obp_chances | R_physical_domain

datatype decline = Underspecified need | Impossible reason | Imprecise

datatype kind = K_range | K_impact_speed | K_fall_time | K_ke | K_pe | K_momentum | K_weight
  | K_force | K_work | K_power | K_final_velocity | K_distance | K_pendulum_period
  | K_gear_ratio | K_gear_speed | K_gear_torque | K_belt_speed | K_pulley_ma | K_pulley_effort
  | K_lever_effort | K_lever_ma | K_incline_ma | K_shaft_power | K_torque
  | K_passer_rating | K_ts_pct | K_era | K_whip | K_slg | K_obp | K_avg | K_win_pct
  | K_games_behind | K_braking | K_stopping | K_to_lpk | K_to_mpg | K_co2 | K_trip_cost
  | K_trip_litres | K_trip_gallons | K_pressure_gauge | K_pressure_abs | K_buoyant_force
  | K_submerged_fraction | K_sinks | K_declined

text \<open>An exact rational value; a decimal @{text "(m, e)"} meaning
@{text "m * 10^e"} enclosing a real value; the answer that a solid sinks; or a
decline.\<close>
datatype outcome = Exact kind rat | Approx kind "int \<times> int" | Sinks | Decline decline

fun work_kind :: "work_request \<Rightarrow> kind" where
  "work_kind (W_pulley_ma n) = K_pulley_ma"
| "work_kind (W_lever_ma e l) = K_lever_ma"
| "work_kind (W_pulley_effort n ld) = K_pulley_effort"
| "work_kind (W_lever_effort e l ld) = K_lever_effort"
| "work_kind (W_gear_torque t a b) = K_gear_torque"
| "work_kind (W_incline_ma l h) = K_incline_ma"
| "work_kind (W_gear_ratio a b) = K_gear_ratio"
| "work_kind (W_gear_speed n a b) = K_gear_speed"
| "work_kind (W_belt_speed n a b) = K_belt_speed"
| "work_kind (W_pulley_ideal n) = K_pulley_ma"
| "work_kind (W_lever_ideal e l) = K_lever_ma"
| "work_kind (W_incline_ideal l h) = K_incline_ma"

primrec kind_of :: "request \<Rightarrow> kind" where
  "kind_of (PhRange _ _) = K_range"
| "kind_of (PhImpact _) = K_impact_speed"
| "kind_of (PhFall _) = K_fall_time"
| "kind_of (PhKE _ _) = K_ke"
| "kind_of (PhPE _ _) = K_pe"
| "kind_of (PhPEAt _ _ _) = K_pe"
| "kind_of PhModelLimit = K_declined"
| "kind_of (PhMomentum _ _) = K_momentum"
| "kind_of (PhWeight _) = K_weight"
| "kind_of (PhForce _ _) = K_force"
| "kind_of (PhWork _ _) = K_work"
| "kind_of (PhPower _ _) = K_power"
| "kind_of (PhFinalV _ _ _ _) = K_final_velocity"
| "kind_of (PhDistance _ _ _ _) = K_distance"
| "kind_of (BdWeight _ _) = K_weight"
| "kind_of (BdFall _ _) = K_fall_time"
| "kind_of (BdImpact _ _) = K_impact_speed"
| "kind_of (BdPendulum _ _) = K_pendulum_period"
| "kind_of (BdUnreadable _) = K_declined"
| "kind_of FsModelLimit = K_declined"
| "kind_of (McGearRatio _ _) = K_gear_ratio"
| "kind_of (McGearSpeed _ _ _) = K_gear_speed"
| "kind_of (McGearTorque _ _ _) = K_gear_torque"
| "kind_of (McBeltSpeed _ _ _) = K_belt_speed"
| "kind_of (McPulleyMA _) = K_pulley_ma"
| "kind_of (McPulleyEffort _ _) = K_pulley_effort"
| "kind_of (McLeverMA _ _) = K_lever_ma"
| "kind_of (McLeverEffort _ _ _) = K_lever_effort"
| "kind_of (McInclineMA _ _) = K_incline_ma"
| "kind_of (McShaftPower _ _) = K_shaft_power"
| "kind_of (McTorque _ _ _) = K_torque"
| "kind_of (McTorqueAngle _ _ _ _) = K_torque"
| "kind_of (McWork w eta) = work_kind w"
| "kind_of (McNeed _) = K_declined"
| "kind_of (SpPasser _ _ _ _ _) = K_passer_rating"
| "kind_of (SpTrueShooting _ _ _) = K_ts_pct"
| "kind_of (SpEra _ _ _) = K_era"
| "kind_of (SpWhip _ _ _ _) = K_whip"
| "kind_of (SpAvg _ _) = K_avg"
| "kind_of (SpObp _ _ _ _ _) = K_obp"
| "kind_of (SpSlg _ _ _ _ _ _) = K_slg"
| "kind_of (SpGamesBehind _ _ _ _) = K_games_behind"
| "kind_of (SpWinPct _ _ _) = K_win_pct"
| "kind_of (FvBraking _ _) = K_braking"
| "kind_of (FvStopping _ _ _) = K_stopping"
| "kind_of (FvToLpk _ _) = K_to_lpk"
| "kind_of (FvToMpg _ _) = K_to_mpg"
| "kind_of (FvCO2 _ _ _ _) = K_co2"
| "kind_of (FvCost _ _ _ _) = K_trip_cost"
| "kind_of (FvVolume _ _ _ u) = (if u = FU_litre then K_trip_litres else K_trip_gallons)"
| "kind_of FvNeed = K_declined"
| "kind_of (FsGauge _ _) = K_pressure_gauge"
| "kind_of (FsAbs _ _) = K_pressure_abs"
| "kind_of (FsBuoyant _ _) = K_buoyant_force"
| "kind_of (FsSubmerged _ _) = K_submerged_fraction"

section \<open>Declines\<close>

text \<open>Underspecified: an amount the organ needs is absent (the organs' need
branches).\<close>
definition miss_if :: "bool \<Rightarrow> need \<Rightarrow> need option" where
  "miss_if b w = (if b then Some w else None)"

lemma miss_if_none [simp]: "miss_if b w = None \<longleftrightarrow> \<not> b"
  by (simp add: miss_if_def)

lemma miss_if_some [simp]: "miss_if b w = Some w' \<longleftrightarrow> b \<and> w = w'"
  by (simp add: miss_if_def)

primrec missing :: "request \<Rightarrow> need option" where
  "missing (PhRange v t) = miss_if (v = None \<or> t = None) N_speed_angle"
| "missing (PhKE m v) = miss_if (m = None \<or> v = None) N_mass_speed"
| "missing (PhPE m h) = miss_if (m = None \<or> h = None) N_mass_height"
| "missing (PhPEAt g m h) = miss_if (m = None \<or> h = None) N_mass_height"
| "missing PhModelLimit = Some N_physics_conditions"
| "missing (PhMomentum m v) = miss_if (m = None \<or> v = None) N_mass_velocity"
| "missing (PhForce m a) = miss_if (m = None \<or> a = None) N_mass_accel"
| "missing (PhFinalV a t u rest) =
     (if a = None \<or> t = None then Some N_accel_time
      else miss_if (u = None \<and> \<not> rest) N_start_speed)"
| "missing (PhDistance a t u rest) = miss_if (u = None \<and> \<not> rest) N_start_speed"
| "missing (BdWeight g m) = miss_if (m = None) N_mass_kg"
| "missing (BdFall g h) = miss_if (h = None) N_fall_height"
| "missing (BdImpact g h) = miss_if (h = None) N_fall_height"
| "missing (BdPendulum g l) = miss_if (l = None) N_pendulum_length"
| "missing (BdUnreadable g) = Some N_unreadable"
| "missing FsModelLimit = Some N_fluid_conditions"
| "missing (McLeverEffort e l ld) = miss_if (ld = None) N_load"
| "missing (McWork w eta) = None"
| "missing (McNeed n) = Some (N_mc_need n)"
| "missing (FvBraking v mu) = miss_if (v = None \<or> mu = None) N_speed_friction"
| "missing (FvStopping v mu rt) =
     (if v = None \<or> mu = None then Some N_speed_friction
      else miss_if (rt = None \<and> \<not> the mu \<le> 0) N_reaction)"
| "missing (FvCost d du ec pr) = miss_if (pr = None) N_price"
| "missing (FsGauge f h) = miss_if (h = None) N_depth"
| "missing (FsAbs f h) = miss_if (h = None) N_depth"
| "missing (FsBuoyant f v) = miss_if (v = None) N_volume"
| "missing (PhImpact x1) = None"
| "missing (PhFall x1) = None"
| "missing (PhWeight x1) = None"
| "missing (PhWork x1 x2) = None"
| "missing (PhPower x1 x2) = None"
| "missing (McGearRatio x1 x2) = None"
| "missing (McGearSpeed x1 x2 x3) = None"
| "missing (McGearTorque x1 x2 x3) = None"
| "missing (McBeltSpeed x1 x2 x3) = None"
| "missing (McPulleyMA x1) = None"
| "missing (McPulleyEffort x1 x2) = None"
| "missing (McLeverMA x1 x2) = None"
| "missing (McInclineMA x1 x2) = None"
| "missing (McShaftPower x1 x2) = None"
| "missing (McTorque x1 x2 x3) = None"
| "missing (McTorqueAngle x1 x2 x3 x4) = None"
| "missing (SpPasser x1 x2 x3 x4 x5) = None"
| "missing (SpTrueShooting x1 x2 x3) = None"
| "missing (SpEra x1 x2 x3) = None"
| "missing (SpWhip x1 x2 x3 x4) = None"
| "missing (SpAvg x1 x2) = None"
| "missing (SpObp x1 x2 x3 x4 x5) = None"
| "missing (SpSlg x1 x2 x3 x4 x5 x6) = None"
| "missing (SpGamesBehind x1 x2 x3 x4) = None"
| "missing (SpWinPct x1 x2 x3) = None"
| "missing (FvToLpk x1 x2) = None"
| "missing (FvToMpg x1 x2) = None"
| "missing (FvCO2 x1 x2 x3 x4) = None"
| "missing (FvVolume d du ec u) = None"
| "missing FvNeed = Some N_fuel"
| "missing (FsSubmerged x1 x2) = None"

definition econ_zero :: "econ \<Rightarrow> bool" where
  "econ_zero ec = (case ec of E_mpg uk e \<Rightarrow> e = 0 | E_lpk x \<Rightarrow> False)"

text \<open>Physical domains are separate from numerical failure. Signed velocity,
force, torque, work, potential height and passing yardage retain their one-dimensional
meaning. Mass, geometry, elapsed time and consumption are magnitudes; event counts
are nonnegative integers. The kernel consumes this predicate before answering.\<close>
definition physical_count :: "rat \<Rightarrow> bool" where
  "physical_count x \<longleftrightarrow> 0 \<le> x \<and> snd (quotient_of x) = 1"
fun nonnegative_option :: "rat option \<Rightarrow> bool" where
  "nonnegative_option None = True"
| "nonnegative_option (Some x) = (0 \<le> x)"
fun nonnegative_pair :: "(rat * 'a) option \<Rightarrow> bool" where
  "nonnegative_pair None = True"
| "nonnegative_pair (Some (x,u)) = (0 \<le> x)"
fun economy_domain :: "econ \<Rightarrow> bool" where
  "economy_domain (E_mpg uk x) = (0 < x)"
| "economy_domain (E_lpk x) = (0 \<le> x)"

fun work_domain :: "work_request \<Rightarrow> bool" where
  "work_domain (W_pulley_ma n) = (physical_count n \<and> 0 < n)"
| "work_domain (W_lever_ma e l) = (0 < e \<and> 0 < l)"
| "work_domain (W_pulley_effort n ld) = (physical_count n \<and> 0 < n \<and> 0 \<le> fst ld)"
| "work_domain (W_lever_effort e l ld) = (0 < e \<and> 0 < l \<and> 0 \<le> fst ld)"
| "work_domain (W_gear_torque t a b) = (physical_count a \<and> physical_count b \<and> 0 < a \<and> 0 < b)"
| "work_domain (W_incline_ma l h) = (0 < h \<and> h \<le> l)"
| "work_domain (W_gear_ratio a b) = (physical_count a \<and> physical_count b \<and> 0 < a \<and> 0 < b)"
| "work_domain (W_gear_speed n a b) = (physical_count a \<and> physical_count b \<and> 0 < a \<and> 0 < b)"
| "work_domain (W_belt_speed n a b) = (0 < a \<and> 0 < b)"
| "work_domain (W_pulley_ideal n) = (physical_count n \<and> 0 < n)"
| "work_domain (W_lever_ideal e l) = (0 < e \<and> 0 < l)"
| "work_domain (W_incline_ideal l h) = (0 < h \<and> h \<le> l)"

fun work_needs_positive :: "work_request \<Rightarrow> bool" where
  "work_needs_positive (W_pulley_effort n ld) = True"
| "work_needs_positive (W_lever_effort e l ld) = True"
| "work_needs_positive w = False"

fun physical_domain :: "request \<Rightarrow> bool" where
  "physical_domain (PhRange v a) = nonnegative_option v"
| "physical_domain (PhKE m v) = nonnegative_option m"
| "physical_domain (PhPE m h) = nonnegative_option m"
| "physical_domain (PhPEAt g m h) = nonnegative_option m"
| "physical_domain PhModelLimit = True"
| "physical_domain (PhMomentum m v) = nonnegative_option m"
| "physical_domain (PhWeight m) = (0 \<le> m)"
| "physical_domain (PhForce m a) = nonnegative_option m"
| "physical_domain (PhPower e t) = (0 < t)"
| "physical_domain (PhFinalV a t v rest) = nonnegative_option t"
| "physical_domain (PhDistance a t v rest) = (0 \<le> t)"
| "physical_domain (BdWeight g m) = nonnegative_option m"
| "physical_domain (McGearRatio a b) = (physical_count a \<and> physical_count b \<and> 0 < a \<and> 0 < b)"
| "physical_domain (McGearSpeed n a b) = (physical_count a \<and> physical_count b \<and> 0 < a \<and> 0 < b)"
| "physical_domain (McGearTorque t a b) = (physical_count a \<and> physical_count b \<and> 0 < a \<and> 0 < b)"
| "physical_domain (McBeltSpeed n a b) = (0 < a \<and> 0 < b)"
| "physical_domain (McPulleyMA n) = (physical_count n \<and> 0 < n)"
| "physical_domain (McPulleyEffort n ld) = (physical_count n \<and> 0 < n \<and> 0 \<le> fst ld)"
| "physical_domain (McLeverMA e l) = (0 < e \<and> 0 < l)"
| "physical_domain (McLeverEffort e l ld) = (0 < e \<and> 0 < l \<and> nonnegative_pair ld)"
| "physical_domain (McTorque f r u) = (0 \<le> r)"
| "physical_domain (McTorqueAngle f r u a) = (0 \<le> r)"
| "physical_domain (SpPasser c a y t i) = (physical_count c \<and> physical_count a \<and> physical_count t \<and> physical_count i \<and> c \<le> a \<and> t \<le> c \<and> i \<le> a-c)"
| "physical_domain (SpTrueShooting p fga fta) = (physical_count p \<and> physical_count fga \<and> physical_count fta)"
| "physical_domain (SpEra w f er) = (physical_count w \<and> physical_count f \<and> physical_count er)"
| "physical_domain (SpWhip w f bb h) = (physical_count w \<and> physical_count f \<and> physical_count bb \<and> physical_count h)"
| "physical_domain (SpAvg h ab) = (physical_count h \<and> physical_count ab \<and> h \<le> ab)"
| "physical_domain (SpObp h bb hbp sf ab) = (physical_count h \<and> physical_count bb \<and> physical_count hbp \<and> physical_count sf \<and> physical_count ab \<and> h \<le> ab)"
| "physical_domain (SpSlg s1 h s2 s3 hr ab) = (physical_count h \<and> physical_count s2 \<and> physical_count s3 \<and> physical_count hr \<and> physical_count ab \<and> (case s1 of None \<Rightarrow> s2+s3+hr \<le> h \<and> h \<le> ab | Some s \<Rightarrow> physical_count s \<and> s+s2+s3+hr \<le> ab))"
| "physical_domain (SpGamesBehind wa la wb lb) = (physical_count wa \<and> physical_count la \<and> physical_count wb \<and> physical_count lb)"
| "physical_domain (SpWinPct w l t) = (physical_count w \<and> physical_count l \<and> physical_count t)"
| "physical_domain (FvBraking v mu) = nonnegative_pair v"
| "physical_domain (FvStopping v mu rt) = (nonnegative_pair v \<and> nonnegative_option rt)"
| "physical_domain (FvToLpk uk x) = (0 < x)"
| "physical_domain (FvToMpg uk x) = (0 < x)"
| "physical_domain (FvCO2 d du ec diesel) = (0 \<le> d \<and> economy_domain ec)"
| "physical_domain (FvCost d du ec pr) = (0 \<le> d \<and> economy_domain ec \<and> nonnegative_pair pr)"
| "physical_domain (FvVolume d du ec u) = (0 \<le> d \<and> economy_domain ec)"
| "physical_domain (FsGauge f h) = nonnegative_option h"
| "physical_domain (FsAbs f h) = nonnegative_option h"
| "physical_domain (FsBuoyant f v) = nonnegative_pair v"
| "physical_domain (McWork w eta) = (work_domain w \<and> 0 \<le> eta \<and> eta \<le> 1 \<and> (work_needs_positive w \<longrightarrow> 0 < eta))"
| "physical_domain r = True"


text \<open>Impossible: the inputs for which the organ divides by zero, takes the
root of a negative number, or states its own refusal (a ramp that rises more
than its length, zero attempts, a non-inning figure).\<close>
primrec impossible_base :: "request \<Rightarrow> bool" where
  "impossible_base (PhImpact h) \<longleftrightarrow> h < 0"
| "impossible_base (PhFall h) \<longleftrightarrow> h < 0"
| "impossible_base (PhPower e t) \<longleftrightarrow> t = 0"
| "impossible_base (BdWeight g m) \<longleftrightarrow> g_of g < 0"
| "impossible_base (BdFall g h) \<longleftrightarrow> g_of g \<le> 0 \<or> the h < 0"
| "impossible_base (BdImpact g h) \<longleftrightarrow> g_of g \<le> 0 \<or> the h < 0"
| "impossible_base (BdPendulum g l) \<longleftrightarrow> g_of g \<le> 0 \<or> the l < 0"
| "impossible_base (McGearRatio a b) \<longleftrightarrow> a = 0"
| "impossible_base (McGearSpeed n a b) \<longleftrightarrow> a = 0 \<or> b = 0"
| "impossible_base (McGearTorque t a b) \<longleftrightarrow> a = 0"
| "impossible_base (McBeltSpeed n d1 d2) \<longleftrightarrow> d2 = 0"
| "impossible_base (McPulleyEffort n ld) \<longleftrightarrow> n = 0"
| "impossible_base (McLeverMA e l) \<longleftrightarrow> l = 0"
| "impossible_base (McLeverEffort e l ld) \<longleftrightarrow> e = 0"
| "impossible_base (McInclineMA l h) \<longleftrightarrow> h \<le> 0 \<or> l < h"
| "impossible_base (SpPasser c a y t i) \<longleftrightarrow> a \<le> 0"
| "impossible_base (SpTrueShooting p fga fta) \<longleftrightarrow> 2 * (fga + 11 / 25 * fta) \<le> 0"
| "impossible_base (SpEra w f er) \<longleftrightarrow> 3 \<le> f \<or> w + f / 3 \<le> 0"
| "impossible_base (SpWhip w f bb h) \<longleftrightarrow> 3 \<le> f \<or> w + f / 3 \<le> 0"
| "impossible_base (SpAvg h ab) \<longleftrightarrow> ab \<le> 0"
| "impossible_base (SpObp h bb hbp sf ab) \<longleftrightarrow> ab + bb + hbp + sf \<le> 0"
| "impossible_base (SpSlg s1 h s2 s3 hr ab) \<longleftrightarrow> ab \<le> 0"
| "impossible_base (SpWinPct w l t) \<longleftrightarrow> w + l + t \<le> 0"
| "impossible_base (FvBraking v mu) \<longleftrightarrow> the mu \<le> 0"
| "impossible_base (FvStopping v mu rt) \<longleftrightarrow> the mu \<le> 0"
| "impossible_base (FvToLpk uk x) \<longleftrightarrow> x = 0"
| "impossible_base (FvToMpg uk x) \<longleftrightarrow> x = 0"
| "impossible_base (FvCO2 d du ec dsl) \<longleftrightarrow> econ_zero ec"
| "impossible_base (FvCost d du ec pr) \<longleftrightarrow> econ_zero ec"
| "impossible_base (FvVolume d du ec u) \<longleftrightarrow> econ_zero ec"
| "impossible_base FvNeed \<longleftrightarrow> False"
| "impossible_base (PhRange x1 x2) \<longleftrightarrow> False"
| "impossible_base (PhKE x1 x2) \<longleftrightarrow> False"
| "impossible_base (PhPE x1 x2) \<longleftrightarrow> False"
| "impossible_base (PhPEAt g m h) \<longleftrightarrow> g_of g < 0"
| "impossible_base PhModelLimit \<longleftrightarrow> False"
| "impossible_base (PhMomentum x1 x2) \<longleftrightarrow> False"
| "impossible_base (PhWeight x1) \<longleftrightarrow> False"
| "impossible_base (PhForce x1 x2) \<longleftrightarrow> False"
| "impossible_base (PhWork x1 x2) \<longleftrightarrow> False"
| "impossible_base (PhFinalV x1 x2 x3 x4) \<longleftrightarrow> False"
| "impossible_base (PhDistance x1 x2 x3 x4) \<longleftrightarrow> False"
| "impossible_base (BdUnreadable x1) \<longleftrightarrow> False"
| "impossible_base FsModelLimit \<longleftrightarrow> False"
| "impossible_base (McPulleyMA x1) \<longleftrightarrow> False"
| "impossible_base (McShaftPower x1 x2) \<longleftrightarrow> False"
| "impossible_base (McTorque x1 x2 x3) \<longleftrightarrow> False"
| "impossible_base (McTorqueAngle x1 x2 x3 x4) \<longleftrightarrow> False"
| "impossible_base (McWork w eta) \<longleftrightarrow> False"
| "impossible_base (McNeed x1) \<longleftrightarrow> False"
| "impossible_base (SpGamesBehind x1 x2 x3 x4) \<longleftrightarrow> False"
| "impossible_base (FsGauge x1 x2) \<longleftrightarrow> False"
| "impossible_base (FsAbs x1 x2) \<longleftrightarrow> False"
| "impossible_base (FsBuoyant x1 x2) \<longleftrightarrow> False"
| "impossible_base (FsSubmerged x1 x2) \<longleftrightarrow> False"

text \<open>The executable check, with the reason it reports (in the order the
organ checks).\<close>
primrec reason_base :: "request \<Rightarrow> reason option" where
  "reason_base (PhImpact h) = (if h < 0 then Some R_negative_amount else None)"
| "reason_base (PhFall h) = (if h < 0 then Some R_negative_amount else None)"
| "reason_base (PhPower e t) = (if t = 0 then Some R_zero_time else None)"
| "reason_base (BdWeight g m) = (if g_of g < 0 then Some R_negative_gravity else None)"
| "reason_base (BdFall g h) =
     (if g_of g \<le> 0 then Some R_nonpositive_gravity
      else if the h < 0 then Some R_negative_amount else None)"
| "reason_base (BdImpact g h) =
     (if g_of g \<le> 0 then Some R_nonpositive_gravity
      else if the h < 0 then Some R_negative_amount else None)"
| "reason_base (BdPendulum g l) =
     (if g_of g \<le> 0 then Some R_nonpositive_gravity
      else if the l < 0 then Some R_negative_amount else None)"
| "reason_base (McGearRatio a b) = (if a = 0 then Some R_zero_teeth else None)"
| "reason_base (McGearSpeed n a b) = (if a = 0 \<or> b = 0 then Some R_zero_teeth else None)"
| "reason_base (McGearTorque t a b) = (if a = 0 then Some R_zero_teeth else None)"
| "reason_base (McBeltSpeed n d1 d2) = (if d2 = 0 then Some R_zero_diameter else None)"
| "reason_base (McPulleyEffort n ld) = (if n = 0 then Some R_zero_strands else None)"
| "reason_base (McLeverMA e l) = (if l = 0 then Some R_zero_arm else None)"
| "reason_base (McLeverEffort e l ld) = (if e = 0 then Some R_zero_arm else None)"
| "reason_base (McInclineMA l h) = (if h \<le> 0 \<or> l < h then Some R_ramp else None)"
| "reason_base (SpPasser c a y t i) = (if a \<le> 0 then Some R_zero_attempts else None)"
| "reason_base (SpTrueShooting p fga fta) =
     (if 2 * (fga + 11 / 25 * fta) \<le> 0 then Some R_zero_shooting else None)"
| "reason_base (SpEra w f er) =
     (if 3 \<le> f then Some R_bad_innings
      else if w + f / 3 \<le> 0 then Some R_zero_innings else None)"
| "reason_base (SpWhip w f bb h) =
     (if 3 \<le> f then Some R_bad_innings
      else if w + f / 3 \<le> 0 then Some R_zero_innings else None)"
| "reason_base (SpAvg h ab) = (if ab \<le> 0 then Some R_zero_at_bats else None)"
| "reason_base (SpObp h bb hbp sf ab) = (if ab + bb + hbp + sf \<le> 0 then Some R_zero_obp_chances else None)"
| "reason_base (SpSlg s1 h s2 s3 hr ab) = (if ab \<le> 0 then Some R_zero_at_bats else None)"
| "reason_base (SpWinPct w l t) = (if w + l + t \<le> 0 then Some R_zero_games else None)"
| "reason_base (FvBraking v mu) = (if the mu \<le> 0 then Some R_friction else None)"
| "reason_base (FvStopping v mu rt) = (if the mu \<le> 0 then Some R_friction else None)"
| "reason_base (FvToLpk uk x) = (if x = 0 then Some R_zero_economy else None)"
| "reason_base (FvToMpg uk x) = (if x = 0 then Some R_zero_economy else None)"
| "reason_base (FvCO2 d du ec dsl) = (if econ_zero ec then Some R_zero_economy else None)"
| "reason_base (FvCost d du ec pr) = (if econ_zero ec then Some R_zero_economy else None)"
| "reason_base (FvVolume d du ec u) = (if econ_zero ec then Some R_zero_economy else None)"
| "reason_base FvNeed = None"
| "reason_base (PhRange x1 x2) = None"
| "reason_base (PhKE x1 x2) = None"
| "reason_base (PhPE x1 x2) = None"
| "reason_base (PhPEAt g m h) = (if g_of g < 0 then Some R_negative_gravity else None)"
| "reason_base PhModelLimit = None"
| "reason_base (PhMomentum x1 x2) = None"
| "reason_base (PhWeight x1) = None"
| "reason_base (PhForce x1 x2) = None"
| "reason_base (PhWork x1 x2) = None"
| "reason_base (PhFinalV x1 x2 x3 x4) = None"
| "reason_base (PhDistance x1 x2 x3 x4) = None"
| "reason_base (BdUnreadable x1) = None"
| "reason_base FsModelLimit = None"
| "reason_base (McPulleyMA x1) = None"
| "reason_base (McShaftPower x1 x2) = None"
| "reason_base (McTorque x1 x2 x3) = None"
| "reason_base (McTorqueAngle x1 x2 x3 x4) = None"
| "reason_base (McWork w eta) = None"
| "reason_base (McNeed x1) = None"
| "reason_base (SpGamesBehind x1 x2 x3 x4) = None"
| "reason_base (FsGauge x1 x2) = None"
| "reason_base (FsAbs x1 x2) = None"
| "reason_base (FsBuoyant x1 x2) = None"
| "reason_base (FsSubmerged x1 x2) = None"

theorem reason_base_exact: "reason_base r \<noteq> None \<longleftrightarrow> impossible_base r"
  by (cases r) (auto split: if_splits)

definition impossible :: "request \<Rightarrow> bool" where
  "impossible r \<longleftrightarrow> impossible_base r \<or> \<not> physical_domain r"
declare impossible_def [simp]

definition reason_of :: "request \<Rightarrow> reason option" where
  "reason_of r = (case reason_base r of Some why \<Rightarrow> Some why
     | None \<Rightarrow> (if physical_domain r then None else Some R_physical_domain))"

theorem reason_of_exact: "reason_of r \<noteq> None \<longleftrightarrow> impossible r"
  using reason_base_exact[of r]
  by (auto simp: reason_of_def split: option.splits)

definition decline_of :: "request \<Rightarrow> decline option" where
  "decline_of r = (case missing r of
     Some w \<Rightarrow> Some (Underspecified w)
   | None \<Rightarrow> (case reason_of r of Some why \<Rightarrow> Some (Impossible why) | None \<Rightarrow> None))"

lemma decline_none:
  "decline_of r = None \<Longrightarrow> missing r = None \<and> \<not> impossible r"
  using reason_of_exact[of r] by (auto simp: decline_of_def split: option.splits)


section \<open>Values\<close>

definition or0 :: "rat option \<Rightarrow> rat" where
  "or0 x = (case x of None \<Rightarrow> 0 | Some y \<Rightarrow> y)"

definition miles_of :: "rat \<Rightarrow> distu \<Rightarrow> rat" where
  "miles_of d du = (case du of DU_mi \<Rightarrow> d | DU_km \<Rightarrow> d / km_per_mi)"

text \<open>US gallons burnt on a trip: miles over miles-per-gallon (UK gallons
converted), or kilometres times litres per 100 km.\<close>
definition gallons_of :: "rat \<Rightarrow> distu \<Rightarrow> econ \<Rightarrow> rat" where
  "gallons_of d du ec = (case ec of
     E_mpg uk e \<Rightarrow> if uk then miles_of d du / e * uk_gal_litres / l_per_gal else miles_of d du / e
   | E_lpk x \<Rightarrow> (miles_of d du * km_per_mi) * x / 100 / l_per_gal)"

definition fuel_amount :: "rat \<Rightarrow> fuel_unit \<Rightarrow> rat" where
  "fuel_amount gal u = gal * l_per_gal / fuel_scale u"
definition price_cost :: "rat \<Rightarrow> rat \<times> fuel_unit \<Rightarrow> rat" where
  "price_cost gal pr = fuel_amount gal (snd pr) * fst pr"

definition fuel_balance :: "rat \<Rightarrow> distu \<Rightarrow> econ \<Rightarrow> rat \<Rightarrow> bool" where
  "fuel_balance d du ec litres = (case ec of
    E_mpg uk e \<Rightarrow> litres * e = miles_of d du * (if uk then uk_gal_litres else l_per_gal)
  | E_lpk x \<Rightarrow> litres * 100 = miles_of d du * km_per_mi * x)"
lemma fuel_amount_units:
  "fuel_amount gal u * fuel_scale u = gal * l_per_gal"
  by (simp add: fuel_amount_def)
lemma gallons_source_balance:
  "economy_domain ec \<Longrightarrow> fuel_balance d du ec (gallons_of d du ec * l_per_gal)"
  by (cases ec) (auto simp: fuel_balance_def gallons_of_def field_simps)


text \<open>Each of the four passer-rating components is clamped to [0, 2.375].\<close>
text \<open>Singles are given, or are the hits that are not doubles, triples or
home runs.\<close>
definition singles_of :: "rat option \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "singles_of s1 h s2 s3 hr = (case s1 of Some x \<Rightarrow> x | None \<Rightarrow> h - s2 - s3 - hr)"

definition cl_rating :: "rat \<Rightarrow> rat" where
  "cl_rating x = max 0 (min (19 / 8) x)"

lemma passer_bounds:
  fixes A B C D :: rat
  assumes "0 \<le> A" "0 \<le> B" "0 \<le> C" "0 \<le> D" "A \<le> 19 / 8" "B \<le> 19 / 8" "C \<le> 19 / 8" "D \<le> 19 / 8"
  shows "0 \<le> (A + B + C + D) / 6 * 100 \<and> (A + B + C + D) / 6 * 100 \<le> 475 / 3"
proof -
  have s: "0 \<le> A + B + C + D" "A + B + C + D \<le> 19 / 8 * 4" using assms by linarith+
  have "0 \<le> (A + B + C + D) / 6 * 100" using s(1) by simp
  moreover have "(A + B + C + D) / 6 * 100 \<le> 475 / 3" using s(2) by simp
  ultimately show ?thesis by blast
qed

lemma cl_rating_bounds: "0 \<le> cl_rating x \<and> cl_rating x \<le> 19 / 8"
  by (simp add: cl_rating_def)

definition efficiency_percent :: "rat \<Rightarrow> rat" where
  "efficiency_percent p = p / 100"

fun work_value :: "work_request \<Rightarrow> rat \<Rightarrow> rat" where
  "work_value (W_pulley_ma n) eta = eta * n"
| "work_value (W_lever_ma e l) eta = eta * e / l"
| "work_value (W_pulley_effort n ld) eta = load_n ld / (eta * n)"
| "work_value (W_lever_effort e l ld) eta = load_n ld * l / (eta * e)"
| "work_value (W_gear_torque t a b) eta = eta * t * b / a"
| "work_value (W_incline_ma l h) eta = eta * l / h"
| "work_value (W_gear_ratio a b) eta = b / a"
| "work_value (W_gear_speed n a b) eta = n * a / b"
| "work_value (W_belt_speed n a b) eta = n * a / b"
| "work_value (W_pulley_ideal n) eta = n"
| "work_value (W_lever_ideal e l) eta = e / l"
| "work_value (W_incline_ideal l h) eta = l / h"

fun work_text :: "work_request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "work_text (W_pulley_ma n) V = STR ''The actual mechanical advantage is '' + V"
| "work_text (W_lever_ma e l) V = STR ''The actual mechanical advantage is '' + V"
| "work_text (W_pulley_effort n ld) V = STR ''The effort is '' + V + STR '' N''"
| "work_text (W_lever_effort e l ld) V = STR ''The effort needed is '' + V + STR '' N''"
| "work_text (W_gear_torque t a b) V = STR ''The output torque is '' + V + STR '' N m''"
| "work_text (W_incline_ma l h) V = STR ''The actual mechanical advantage is '' + V"
| "work_text (W_gear_ratio a b) V = STR ''The gear ratio is '' + V + STR '':1''"
| "work_text (W_gear_speed n a b) V = STR ''The output speed is '' + V + STR '' rpm''"
| "work_text (W_belt_speed n a b) V = STR ''The driven pulley turns at '' + V + STR '' rpm''"
| "work_text (W_pulley_ideal n) V = STR ''The ideal mechanical advantage is '' + V"
| "work_text (W_lever_ideal e l) V = STR ''The ideal mechanical advantage is '' + V"
| "work_text (W_incline_ideal l h) V = STR ''The ideal mechanical advantage is '' + V"

primrec qval :: "request \<Rightarrow> rat" where
  "qval (PhKE m v) = the m * the v ^ 2 / 2"
| "qval (PhPE m h) = the m * g0 * the h"
| "qval (PhPEAt g m h) = the m * g_of g * the h"
| "qval PhModelLimit = 0"
| "qval (PhMomentum m v) = the m * the v"
| "qval (PhWeight m) = m * g0"
| "qval (PhForce m a) = the m * the a"
| "qval (PhWork f d) = f * d"
| "qval (PhPower e t) = e / t"
| "qval (PhFinalV a t u rest) = or0 u + the a * the t"
| "qval (PhDistance a t u rest) = or0 u * t + a * t ^ 2 / 2"
| "qval (BdWeight g m) = the m * g_of g"
| "qval (McGearRatio a b) = b / a"
| "qval (McGearSpeed n a b) = n * a / b"
| "qval (McGearTorque t a b) = t * b / a"
| "qval (McBeltSpeed n d1 d2) = n * d1 / d2"
| "qval (McPulleyMA n) = n"
| "qval (McPulleyEffort n ld) = load_n ld / n"
| "qval (McLeverMA e l) = e / l"
| "qval (McLeverEffort e l ld) = load_n (the ld) * l / e"
| "qval (McInclineMA l h) = l / h"
| "qval (McTorque f r u) = f * r * len_scale u"
| "qval (SpPasser c a y t i) =
     (cl_rating ((c / a - 3 / 10) * 5) + cl_rating ((y / a - 3) / 4) + cl_rating (t / a * 20)
      + cl_rating (19 / 8 - i / a * 25)) / 6 * 100"
| "qval (SpTrueShooting p fga fta) = p / (2 * (fga + 11 / 25 * fta)) * 100"
| "qval (SpEra w f er) = 9 * er / (w + f / 3)"
| "qval (SpWhip w f bb h) = (bb + h) / (w + f / 3)"
| "qval (SpAvg h ab) = h / ab"
| "qval (SpObp h bb hbp sf ab) = (h + bb + hbp) / (ab + bb + hbp + sf)"
| "qval (SpSlg s1 h s2 s3 hr ab) = (singles_of s1 h s2 s3 hr + 2 * s2 + 3 * s3 + 4 * hr) / ab"
| "qval (SpGamesBehind wa la wb lb) = \<bar>(wa - wb) + (lb - la)\<bar> / 2"
| "qval (SpWinPct w l t) = (w + t / 2) / (w + l + t)"
| "qval (FvBraking v mu) = spd (the v) ^ 2 / (2 * the mu * g0)"
| "qval (FvStopping v mu rt) = spd (the v) * the rt + spd (the v) ^ 2 / (2 * the mu * g0)"
| "qval (FvToLpk uk x) = (if uk then lpk_uk else lpk_us) / x"
| "qval (FvToMpg uk x) = (if uk then lpk_uk else lpk_us) / x"
| "qval (FvCO2 d du ec dsl) = gallons_of d du ec * (if dsl then co2_diesel else co2_gasoline) / 1000"
| "qval (FvCost d du ec pr) = price_cost (gallons_of d du ec) (the pr)"
| "qval (FvVolume d du ec u) = fuel_amount (gallons_of d du ec) u"
| "qval FvNeed = 0"
| "qval (FsGauge f h) = fluid_density f * g0 * the h"
| "qval (FsAbs f h) = p0 + fluid_density f * g0 * the h"
| "qval (FsBuoyant f v) = fluid_density f * g0 * vol_m3 (the v)"
| "qval (FsSubmerged s f) = solid_density s / fluid_density f"
| "qval (PhRange x1 x2) = 0"
| "qval (PhImpact x1) = 0"
| "qval (PhFall x1) = 0"
| "qval (BdFall x1 x2) = 0"
| "qval (BdImpact x1 x2) = 0"
| "qval (BdPendulum x1 x2) = 0"
| "qval (BdUnreadable x1) = 0"
| "qval FsModelLimit = 0"
| "qval (McShaftPower x1 x2) = 0"
| "qval (McTorqueAngle x1 x2 x3 x4) = 0"
| "qval (McWork w eta) = work_value w eta"
| "qval (McNeed x1) = 0"

primrec is_real :: "request \<Rightarrow> bool" where
  "is_real (PhRange _ _) = True"
| "is_real (PhImpact _) = True"
| "is_real (PhFall _) = True"
| "is_real (BdFall _ _) = True"
| "is_real (BdImpact _ _) = True"
| "is_real (BdPendulum _ _) = True"
| "is_real (McShaftPower _ _) = True"
| "is_real (McTorqueAngle _ _ _ _) = True"
| "is_real (PhKE x1 x2) = False"
| "is_real (PhPE x1 x2) = False"
| "is_real (PhPEAt g m h) = False"
| "is_real PhModelLimit = False"
| "is_real (PhMomentum x1 x2) = False"
| "is_real (PhWeight x1) = False"
| "is_real (PhForce x1 x2) = False"
| "is_real (PhWork x1 x2) = False"
| "is_real (PhPower x1 x2) = False"
| "is_real (PhFinalV x1 x2 x3 x4) = False"
| "is_real (PhDistance x1 x2 x3 x4) = False"
| "is_real (BdWeight x1 x2) = False"
| "is_real (BdUnreadable x1) = False"
| "is_real FsModelLimit = False"
| "is_real (McGearRatio x1 x2) = False"
| "is_real (McGearSpeed x1 x2 x3) = False"
| "is_real (McGearTorque x1 x2 x3) = False"
| "is_real (McBeltSpeed x1 x2 x3) = False"
| "is_real (McPulleyMA x1) = False"
| "is_real (McPulleyEffort x1 x2) = False"
| "is_real (McLeverMA x1 x2) = False"
| "is_real (McLeverEffort x1 x2 x3) = False"
| "is_real (McInclineMA x1 x2) = False"
| "is_real (McTorque x1 x2 x3) = False"
| "is_real (McWork w eta) = False"
| "is_real (McNeed x1) = False"
| "is_real (SpPasser x1 x2 x3 x4 x5) = False"
| "is_real (SpTrueShooting x1 x2 x3) = False"
| "is_real (SpEra x1 x2 x3) = False"
| "is_real (SpWhip x1 x2 x3 x4) = False"
| "is_real (SpAvg x1 x2) = False"
| "is_real (SpObp x1 x2 x3 x4 x5) = False"
| "is_real (SpSlg x1 x2 x3 x4 x5 x6) = False"
| "is_real (SpGamesBehind x1 x2 x3 x4) = False"
| "is_real (SpWinPct x1 x2 x3) = False"
| "is_real (FvBraking x1 x2) = False"
| "is_real (FvStopping x1 x2 x3) = False"
| "is_real (FvToLpk x1 x2) = False"
| "is_real (FvToMpg x1 x2) = False"
| "is_real (FvCO2 x1 x2 x3 x4) = False"
| "is_real (FvCost x1 x2 x3 x4) = False"
| "is_real (FvVolume d du ec u) = False"
| "is_real FvNeed = False"
| "is_real (FsGauge x1 x2) = False"
| "is_real (FsAbs x1 x2) = False"
| "is_real (FsBuoyant x1 x2) = False"
| "is_real (FsSubmerged x1 x2) = False"

primrec sinks :: "request \<Rightarrow> bool" where
  "sinks (FsSubmerged s f) \<longleftrightarrow> fluid_density f \<le> solid_density s"
| "sinks (PhRange x1 x2) \<longleftrightarrow> False"
| "sinks (PhImpact x1) \<longleftrightarrow> False"
| "sinks (PhFall x1) \<longleftrightarrow> False"
| "sinks (PhKE x1 x2) \<longleftrightarrow> False"
| "sinks (PhPE x1 x2) \<longleftrightarrow> False"
| "sinks (PhPEAt g m h) \<longleftrightarrow> False"
| "sinks PhModelLimit \<longleftrightarrow> False"
| "sinks (PhMomentum x1 x2) \<longleftrightarrow> False"
| "sinks (PhWeight x1) \<longleftrightarrow> False"
| "sinks (PhForce x1 x2) \<longleftrightarrow> False"
| "sinks (PhWork x1 x2) \<longleftrightarrow> False"
| "sinks (PhPower x1 x2) \<longleftrightarrow> False"
| "sinks (PhFinalV x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (PhDistance x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (BdWeight x1 x2) \<longleftrightarrow> False"
| "sinks (BdFall x1 x2) \<longleftrightarrow> False"
| "sinks (BdImpact x1 x2) \<longleftrightarrow> False"
| "sinks (BdPendulum x1 x2) \<longleftrightarrow> False"
| "sinks (BdUnreadable x1) \<longleftrightarrow> False"
| "sinks FsModelLimit \<longleftrightarrow> False"
| "sinks (McGearRatio x1 x2) \<longleftrightarrow> False"
| "sinks (McGearSpeed x1 x2 x3) \<longleftrightarrow> False"
| "sinks (McGearTorque x1 x2 x3) \<longleftrightarrow> False"
| "sinks (McBeltSpeed x1 x2 x3) \<longleftrightarrow> False"
| "sinks (McPulleyMA x1) \<longleftrightarrow> False"
| "sinks (McPulleyEffort x1 x2) \<longleftrightarrow> False"
| "sinks (McLeverMA x1 x2) \<longleftrightarrow> False"
| "sinks (McLeverEffort x1 x2 x3) \<longleftrightarrow> False"
| "sinks (McInclineMA x1 x2) \<longleftrightarrow> False"
| "sinks (McShaftPower x1 x2) \<longleftrightarrow> False"
| "sinks (McTorque x1 x2 x3) \<longleftrightarrow> False"
| "sinks (McTorqueAngle x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (McWork w eta) \<longleftrightarrow> False"
| "sinks (McNeed x1) \<longleftrightarrow> False"
| "sinks (SpPasser x1 x2 x3 x4 x5) \<longleftrightarrow> False"
| "sinks (SpTrueShooting x1 x2 x3) \<longleftrightarrow> False"
| "sinks (SpEra x1 x2 x3) \<longleftrightarrow> False"
| "sinks (SpWhip x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (SpAvg x1 x2) \<longleftrightarrow> False"
| "sinks (SpObp x1 x2 x3 x4 x5) \<longleftrightarrow> False"
| "sinks (SpSlg x1 x2 x3 x4 x5 x6) \<longleftrightarrow> False"
| "sinks (SpGamesBehind x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (SpWinPct x1 x2 x3) \<longleftrightarrow> False"
| "sinks (FvBraking x1 x2) \<longleftrightarrow> False"
| "sinks (FvStopping x1 x2 x3) \<longleftrightarrow> False"
| "sinks (FvToLpk x1 x2) \<longleftrightarrow> False"
| "sinks (FvToMpg x1 x2) \<longleftrightarrow> False"
| "sinks (FvCO2 x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (FvCost x1 x2 x3 x4) \<longleftrightarrow> False"
| "sinks (FvVolume d du ec u) \<longleftrightarrow> False"
| "sinks FvNeed \<longleftrightarrow> False"
| "sinks (FsGauge x1 x2) \<longleftrightarrow> False"
| "sinks (FsAbs x1 x2) \<longleftrightarrow> False"
| "sinks (FsBuoyant x1 x2) \<longleftrightarrow> False"

text \<open>The real-number model of the kinds that need a square root, pi or a
sine; every other kind is its exact rational value.\<close>
primrec phys :: "request \<Rightarrow> real" where
  "phys (PhRange v t) = rl (the v ^ 2 / g0) * sin (rl (2 * the t / 180) * pi)"
| "phys (PhImpact h) = sqrt (rl (2 * g0 * h))"
| "phys (PhFall h) = sqrt (rl (2 * h / g0))"
| "phys (BdFall g h) = sqrt (rl (2 * the h / g_of g))"
| "phys (BdImpact g h) = sqrt (rl (2 * g_of g * the h))"
| "phys (BdPendulum g l) = 2 * pi * sqrt (rl (the l) / rl (g_of g))"
| "phys (McShaftPower n t) = 2 * pi * rl (n * t / 60)"
| "phys (McTorqueAngle f r u a) = rl (f * r * len_scale u) * sin (rl (a / 180) * pi)"
| "phys (PhKE x1 x2) = rl (qval (PhKE x1 x2))"
| "phys (PhPE x1 x2) = rl (qval (PhPE x1 x2))"
| "phys (PhPEAt g m h) = rl (qval (PhPEAt g m h))"
| "phys PhModelLimit = 0"
| "phys (PhMomentum x1 x2) = rl (qval (PhMomentum x1 x2))"
| "phys (PhWeight x1) = rl (qval (PhWeight x1))"
| "phys (PhForce x1 x2) = rl (qval (PhForce x1 x2))"
| "phys (PhWork x1 x2) = rl (qval (PhWork x1 x2))"
| "phys (PhPower x1 x2) = rl (qval (PhPower x1 x2))"
| "phys (PhFinalV x1 x2 x3 x4) = rl (qval (PhFinalV x1 x2 x3 x4))"
| "phys (PhDistance x1 x2 x3 x4) = rl (qval (PhDistance x1 x2 x3 x4))"
| "phys (BdWeight x1 x2) = rl (qval (BdWeight x1 x2))"
| "phys (BdUnreadable x1) = rl (qval (BdUnreadable x1))"
| "phys FsModelLimit = rl (qval FsModelLimit)"
| "phys (McGearRatio x1 x2) = rl (qval (McGearRatio x1 x2))"
| "phys (McGearSpeed x1 x2 x3) = rl (qval (McGearSpeed x1 x2 x3))"
| "phys (McGearTorque x1 x2 x3) = rl (qval (McGearTorque x1 x2 x3))"
| "phys (McBeltSpeed x1 x2 x3) = rl (qval (McBeltSpeed x1 x2 x3))"
| "phys (McPulleyMA x1) = rl (qval (McPulleyMA x1))"
| "phys (McPulleyEffort x1 x2) = rl (qval (McPulleyEffort x1 x2))"
| "phys (McLeverMA x1 x2) = rl (qval (McLeverMA x1 x2))"
| "phys (McLeverEffort x1 x2 x3) = rl (qval (McLeverEffort x1 x2 x3))"
| "phys (McInclineMA x1 x2) = rl (qval (McInclineMA x1 x2))"
| "phys (McTorque x1 x2 x3) = rl (qval (McTorque x1 x2 x3))"
| "phys (McWork w eta) = rl (work_value w eta)"
| "phys (McNeed x1) = rl (qval (McNeed x1))"
| "phys (SpPasser x1 x2 x3 x4 x5) = rl (qval (SpPasser x1 x2 x3 x4 x5))"
| "phys (SpTrueShooting x1 x2 x3) = rl (qval (SpTrueShooting x1 x2 x3))"
| "phys (SpEra x1 x2 x3) = rl (qval (SpEra x1 x2 x3))"
| "phys (SpWhip x1 x2 x3 x4) = rl (qval (SpWhip x1 x2 x3 x4))"
| "phys (SpAvg x1 x2) = rl (qval (SpAvg x1 x2))"
| "phys (SpObp x1 x2 x3 x4 x5) = rl (qval (SpObp x1 x2 x3 x4 x5))"
| "phys (SpSlg x1 x2 x3 x4 x5 x6) = rl (qval (SpSlg x1 x2 x3 x4 x5 x6))"
| "phys (SpGamesBehind x1 x2 x3 x4) = rl (qval (SpGamesBehind x1 x2 x3 x4))"
| "phys (SpWinPct x1 x2 x3) = rl (qval (SpWinPct x1 x2 x3))"
| "phys (FvBraking x1 x2) = rl (qval (FvBraking x1 x2))"
| "phys (FvStopping x1 x2 x3) = rl (qval (FvStopping x1 x2 x3))"
| "phys (FvToLpk x1 x2) = rl (qval (FvToLpk x1 x2))"
| "phys (FvToMpg x1 x2) = rl (qval (FvToMpg x1 x2))"
| "phys (FvCO2 x1 x2 x3 x4) = rl (qval (FvCO2 x1 x2 x3 x4))"
| "phys (FvCost x1 x2 x3 x4) = rl (qval (FvCost x1 x2 x3 x4))"
| "phys (FvVolume d du ec u) = rl (qval (FvVolume d du ec u))"
| "phys FvNeed = 0"
| "phys (FsGauge x1 x2) = rl (qval (FsGauge x1 x2))"
| "phys (FsAbs x1 x2) = rl (qval (FsAbs x1 x2))"
| "phys (FsBuoyant x1 x2) = rl (qval (FsBuoyant x1 x2))"
| "phys (FsSubmerged x1 x2) = rl (qval (FsSubmerged x1 x2))"

lemma phys_exact: "\<not> is_real r \<Longrightarrow> phys r = rl (qval r)"
  by (cases r) simp_all


section \<open>Executable enclosure of the real kinds\<close>

definition sinfa :: "floatarith \<Rightarrow> floatarith" where
  "sinfa a = floatarith.Cos (floatarith.Add (floatarith.Mult floatarith.Pi (floatarith.Inverse (I 2)))
                                            (floatarith.Minus a))"

lemma interp_sinfa [simp]:
  "interpret_floatarith (sinfa a) xs = sin (interpret_floatarith a xs)"
proof -
  define v where "v = interpret_floatarith a xs"
  have e: "pi * inverse 2 + - v = pi / 2 - v" by (simp add: field_simps)
  show ?thesis by (simp add: sinfa_def v_def[symmetric] e cos_diff)
qed

primrec fa_of :: "request \<Rightarrow> floatarith" where
  "fa_of (PhRange v t) = floatarith.Mult (Q (the v ^ 2 / g0))
       (sinfa (floatarith.Mult (Q (2 * the t / 180)) floatarith.Pi))"
| "fa_of (PhImpact h) = floatarith.Sqrt (Q (2 * g0 * h))"
| "fa_of (PhFall h) = floatarith.Sqrt (Q (2 * h / g0))"
| "fa_of (BdFall g h) = floatarith.Sqrt (Q (2 * the h / g_of g))"
| "fa_of (BdImpact g h) = floatarith.Sqrt (Q (2 * g_of g * the h))"
| "fa_of (BdPendulum g l) = floatarith.Mult (floatarith.Mult (I 2) floatarith.Pi)
       (floatarith.Sqrt (floatarith.Mult (Q (the l)) (floatarith.Inverse (Q (g_of g)))))"
| "fa_of (McShaftPower n t) = floatarith.Mult (floatarith.Mult (I 2) floatarith.Pi) (Q (n * t / 60))"
| "fa_of (McTorqueAngle f r u a) = floatarith.Mult (Q (f * r * len_scale u))
       (sinfa (floatarith.Mult (Q (a / 180)) floatarith.Pi))"
| "fa_of (PhKE x1 x2) = I 0"
| "fa_of (PhPE x1 x2) = I 0"
| "fa_of (PhPEAt g m h) = I 0"
| "fa_of PhModelLimit = I 0"
| "fa_of (PhMomentum x1 x2) = I 0"
| "fa_of (PhWeight x1) = I 0"
| "fa_of (PhForce x1 x2) = I 0"
| "fa_of (PhWork x1 x2) = I 0"
| "fa_of (PhPower x1 x2) = I 0"
| "fa_of (PhFinalV x1 x2 x3 x4) = I 0"
| "fa_of (PhDistance x1 x2 x3 x4) = I 0"
| "fa_of (BdWeight x1 x2) = I 0"
| "fa_of (BdUnreadable x1) = I 0"
| "fa_of FsModelLimit = I 0"
| "fa_of (McGearRatio x1 x2) = I 0"
| "fa_of (McGearSpeed x1 x2 x3) = I 0"
| "fa_of (McGearTorque x1 x2 x3) = I 0"
| "fa_of (McBeltSpeed x1 x2 x3) = I 0"
| "fa_of (McPulleyMA x1) = I 0"
| "fa_of (McPulleyEffort x1 x2) = I 0"
| "fa_of (McLeverMA x1 x2) = I 0"
| "fa_of (McLeverEffort x1 x2 x3) = I 0"
| "fa_of (McInclineMA x1 x2) = I 0"
| "fa_of (McTorque x1 x2 x3) = I 0"
| "fa_of (McWork w eta) = I 0"
| "fa_of (McNeed x1) = I 0"
| "fa_of (SpPasser x1 x2 x3 x4 x5) = I 0"
| "fa_of (SpTrueShooting x1 x2 x3) = I 0"
| "fa_of (SpEra x1 x2 x3) = I 0"
| "fa_of (SpWhip x1 x2 x3 x4) = I 0"
| "fa_of (SpAvg x1 x2) = I 0"
| "fa_of (SpObp x1 x2 x3 x4 x5) = I 0"
| "fa_of (SpSlg x1 x2 x3 x4 x5 x6) = I 0"
| "fa_of (SpGamesBehind x1 x2 x3 x4) = I 0"
| "fa_of (SpWinPct x1 x2 x3) = I 0"
| "fa_of (FvBraking x1 x2) = I 0"
| "fa_of (FvStopping x1 x2 x3) = I 0"
| "fa_of (FvToLpk x1 x2) = I 0"
| "fa_of (FvToMpg x1 x2) = I 0"
| "fa_of (FvCO2 x1 x2 x3 x4) = I 0"
| "fa_of (FvCost x1 x2 x3 x4) = I 0"
| "fa_of (FvVolume d du ec u) = I 0"
| "fa_of FvNeed = I 0"
| "fa_of (FsGauge x1 x2) = I 0"
| "fa_of (FsAbs x1 x2) = I 0"
| "fa_of (FsBuoyant x1 x2) = I 0"
| "fa_of (FsSubmerged x1 x2) = I 0"

lemma fa_phys:
  "is_real r \<Longrightarrow> interpret_floatarith (fa_of r) [] = phys r"
proof (cases r)
  case (BdPendulum g l)
  then show ?thesis by (simp add: divide_inverse)
qed simp_all

definition approx_out :: "kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out k e = (case enclose prec e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out c e = Approx k d"
  shows "k = c \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
  using assms enclose_sound by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_exact [simp]: "approx_out c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_sinks [simp]: "approx_out c e \<noteq> Sinks"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decline: "approx_out c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)


section \<open>The kernel\<close>

definition answer_of :: "request \<Rightarrow> outcome" where
  "answer_of r = (if is_real r then approx_out (kind_of r) (fa_of r)
                  else if sinks r then Sinks else Exact (kind_of r) (qval r))"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

lemma answer_decline: "answer_of r = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: answer_of_def dest: approx_out_decline split: if_splits)

lemma answer_exact:
  "answer_of r = Exact k q \<Longrightarrow> k = kind_of r \<and> q = qval r \<and> \<not> is_real r \<and> \<not> sinks r"
  by (auto simp: answer_of_def split: if_splits)

lemma answer_approx:
  assumes "answer_of r = Approx k d"
  shows "is_real r \<and> k = kind_of r \<and> \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have R: "is_real r" using assms by (auto simp: answer_of_def split: if_splits)
  have a: "approx_out (kind_of r) (fa_of r) = Approx k d" using assms R by (simp add: answer_of_def)
  show ?thesis using R approx_out_sound[OF a] fa_phys[OF R] by simp
qed

text \<open>Every exact value the kernel states is the request's value, and only for
requests that are fully specified and possible.\<close>
theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and> q = qval r \<and> \<not> is_real r \<and>
         \<not> sinks r \<and> rl q = phys r"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Exact k q"
    using assms by (auto simp: kernel_def split: option.splits)
  have kq: "k = kind_of r \<and> q = qval r \<and> \<not> is_real r \<and> \<not> sinks r" by (rule answer_exact[OF a])
  have "phys r = rl (qval r)" using kq by (simp add: phys_exact)
  then show ?thesis using decline_none[OF nd] kq by simp
qed

text \<open>Every decimal the kernel states for a root, pi or sine kind is within
one part in a thousand (plus 10^-9) of the real model.\<close>
theorem kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None \<and> \<not> impossible r \<and> is_real r \<and> k = kind_of r \<and>
         \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Approx k d"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using decline_none[OF nd] answer_approx[OF a] by simp
qed

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified w) \<longleftrightarrow> missing r = Some w"
  by (auto simp: kernel_def decline_of_def dest: answer_decline split: option.splits if_splits)

theorem kernel_impossible:
  "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> impossible r"
proof -
  have "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> reason_of r \<noteq> None"
    by (auto simp: kernel_def decline_of_def dest: answer_decline split: option.splits if_splits)
  then show ?thesis using reason_of_exact by blast
qed

text \<open>The only other decline is numerical (the enclosure too wide); it
happens only on fully specified, possible requests that need a root, pi or a
sine.\<close>
theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None \<and> \<not> impossible r \<and> is_real r"
proof -
  have nd: "decline_of r = None"
    using assms by (auto simp: kernel_def decline_of_def split: option.splits if_splits)
  then have a: "answer_of r = Decline Imprecise" using assms by (simp add: kernel_def)
  have "is_real r" using a by (auto simp: answer_of_def split: if_splits)
  then show ?thesis using decline_none[OF nd] by simp
qed

lemma exact_facts:
  assumes "kernel r = Exact k q"
  shows "k = kind_of r \<and> q = qval r \<and> missing r = None \<and> \<not> impossible r \<and> \<not> sinks r"
  using kernel_exact_sound[OF assms] by simp


section \<open>Stated numbers and response text (ASCII)\<close>

datatype fmt = Sig nat | Fixed nat | Trim nat | Money

text \<open>How each organ prints its number: Python's @{text "%.4g"} for most
kinds; fixed decimals for the sports rates and money.\<close>
definition fmt_of :: "kind \<Rightarrow> fmt" where
  "fmt_of k = (case k of
       K_passer_rating \<Rightarrow> Fixed 1
     | K_ts_pct \<Rightarrow> Trim 2 | K_games_behind \<Rightarrow> Trim 2
     | K_era \<Rightarrow> Fixed 2 | K_whip \<Rightarrow> Fixed 2
     | K_slg \<Rightarrow> Fixed 3 | K_obp \<Rightarrow> Fixed 3 | K_avg \<Rightarrow> Fixed 3 | K_win_pct \<Rightarrow> Fixed 3
     | K_trip_cost \<Rightarrow> Money
     | _ \<Rightarrow> Sig 4)"

definition stated_dec :: "kind \<Rightarrow> rat \<Rightarrow> (int \<times> int) option" where
  "stated_dec k q = (case fmt_of k of
       Sig p \<Rightarrow> round_sig p (rl q)
     | Fixed n \<Rightarrow> Some (round_at (rl q) (- int n))
     | Trim n \<Rightarrow> Some (round_at (rl q) (- int n))
     | Money \<Rightarrow> Some (round_at (rl q) (- 2)))"

fun fmt_err :: "fmt \<Rightarrow> real \<Rightarrow> real" where
  "fmt_err (Sig p) x = \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
| "fmt_err (Fixed n) x = pow10 (- int n) / 2"
| "fmt_err (Trim n) x = pow10 (- int n) / 2"
| "fmt_err Money x = pow10 (- 2) / 2"

theorem stated_dec_sound:
  assumes "stated_dec k q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> fmt_err (fmt_of k) (rl q)"
proof (cases "fmt_of k")
  case (Sig p)
  then have h: "round_sig p (rl q) = Some d" using assms by (simp add: stated_dec_def)
  have "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (p - 1))" by (rule round_sig_sound[OF h])
  then show ?thesis using Sig by simp
next
  case (Fixed n)
  then have h: "d = round_at (rl q) (- int n)" using assms by (simp add: stated_dec_def)
  have "\<bar>dec_val d - rl q\<bar> \<le> pow10 (- int n) / 2" unfolding h by (rule round_at_error)
  then show ?thesis using Fixed by simp
next
  case (Trim n)
  then have h: "d = round_at (rl q) (- int n)" using assms by (simp add: stated_dec_def)
  have "\<bar>dec_val d - rl q\<bar> \<le> pow10 (- int n) / 2" unfolding h by (rule round_at_error)
  then show ?thesis using Trim by simp
next
  case Money
  then have h: "d = round_at (rl q) (- 2)" using assms by (simp add: stated_dec_def)
  have "\<bar>dec_val d - rl q\<bar> \<le> pow10 (- 2) / 2" unfolding h by (rule round_at_error)
  then show ?thesis using Money by simp
qed

definition value_lit :: "kind \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "value_lit k d = (case fmt_of k of
       Sig p \<Rightarrow> render_dec p d
     | Fixed n \<Rightarrow> render_fixed n d
     | Trim n \<Rightarrow> render_trim n d
     | Money \<Rightarrow> render_fixed 2 d)"

definition gen_text :: "String.literal" where "gen_text = STR ''''"

primrec ok_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "ok_text (PhRange v t) V = STR ''The range is '' + V + STR '' m on level ground (R = v^2 sin(2 theta)/g = ''
     + show4 (the v) + STR ''^2 sin('' + show4 (2 * the t) + STR '' deg)/9.80665; no air resistance).''"
| "ok_text (PhImpact h) V = STR ''It hits the ground at about '' + V + STR '' m/s (v = sqrt(2gh) = sqrt(2 x 9.80665 x ''
     + show4 h + STR ''); no air resistance).''"
| "ok_text (PhFall h) V = STR ''It takes about '' + V + STR '' s to fall '' + show4 h
     + STR '' m (t = sqrt(2h/g); no air resistance).''"
| "ok_text (PhKE m v) V = STR ''The kinetic energy is '' + V + STR '' J (KE = 1/2 m v^2 = 1/2 x '' + show4 (the m)
     + STR '' x '' + show4 (the v) + STR ''^2).''"
| "ok_text (PhPE m h) V = STR ''The gravitational potential energy is '' + V + STR '' J (PE = m g h = ''
     + show4 (the m) + STR '' x 9.80665 x '' + show4 (the h) + STR '').''"
| "ok_text (PhMomentum m v) V = STR ''The momentum is '' + V + STR '' kg m/s (p = m v = '' + show4 (the m)
     + STR '' x '' + show4 (the v) + STR '').''"
| "ok_text (PhWeight m) V = STR ''The weight is '' + V + STR '' N on Earth (W = m g = '' + show4 m
     + STR '' x 9.80665).''"
| "ok_text (PhForce m a) V = STR ''The net force is '' + V + STR '' N (F = m a = '' + show4 (the m)
     + STR '' x '' + show4 (the a) + STR '').''"
| "ok_text (PhWork f d) V = STR ''The work done is '' + V + STR '' J (W = F d = '' + show4 f + STR '' x ''
     + show4 d + STR '', force along the motion).''"
| "ok_text (PhPower e t) V = STR ''The power is '' + V + STR '' W (P = E/t = '' + show4 e + STR ''/'' + show4 t + STR '').''"
| "ok_text (PhFinalV a t u rest) V = STR ''The final velocity is '' + V + STR '' m/s (v = u + a t = '' + show4 (or0 u)
     + STR '' + '' + show4 (the a) + STR '' x '' + show4 (the t) + STR '').''"
| "ok_text (PhDistance a t u rest) V = STR ''It travels '' + V + STR '' m (s = u t + 1/2 a t^2 = '' + show4 (or0 u)
     + STR '' x '' + show4 t + STR '' + 1/2 x '' + show4 a + STR '' x '' + show4 t + STR ''^2).''"
| "ok_text (BdWeight g m) V = STR ''The weight is about '' + V + STR '' N '' + grav_where g + STR '' (W = m g = ''
     + show4 (the m) + STR '' kg x '' + show4 (g_of g) + STR '' m/s^2; the same as '' + show4 (the m * g_of g / g0)
     + STR '' kg would weigh on Earth).''"
| "ok_text (BdFall g h) V = STR ''It takes about '' + V + STR '' s to fall '' + show4 (the h) + STR '' m '' + grav_where g
     + STR '' (t = sqrt(2h/g) = sqrt(2 x '' + show4 (the h) + STR ''/'' + show4 (g_of g) + STR ''); no air resistance).''"
| "ok_text (BdImpact g h) V = STR ''It lands at about '' + V + STR '' m/s '' + grav_where g
     + STR '' (v = sqrt(2gh) = sqrt(2 x '' + show4 (g_of g) + STR '' x '' + show4 (the h) + STR ''); no air resistance).''"
| "ok_text (BdPendulum g l) V = STR ''The period is about '' + V + STR '' s '' + grav_where g
     + STR '' (T = 2 pi sqrt(L/g) = 2 pi sqrt('' + show4 (the l) + STR ''/'' + show4 (g_of g) + STR ''); small swings).''"
| "ok_text (McGearRatio a b) V = STR ''The gear ratio is '' + V + STR '':1 (driven '' + show4 b
     + STR '' teeth / driver '' + show4 a + STR '' teeth).''"
| "ok_text (McGearSpeed n a b) V = STR ''The output speed is '' + V + STR '' rpm ('' + show4 n + STR '' rpm x ''
     + show4 a + STR ''/'' + show4 b + STR '' teeth; ideal gears).''"
| "ok_text (McGearTorque t a b) V = STR ''The output torque is '' + V + STR '' N m ('' + show4 t + STR '' N m x ''
     + show4 b + STR ''/'' + show4 a + STR '' teeth; ideal, no friction losses).''"
| "ok_text (McBeltSpeed n d1 d2) V = STR ''The driven pulley turns at '' + V + STR '' rpm ('' + show4 n + STR '' rpm x ''
     + show4 d1 + STR ''/'' + show4 d2 + STR ''; belt without slip).''"
| "ok_text (McPulleyMA n) V = STR ''The ideal mechanical advantage is '' + V + STR '' (the number of supporting strands).''"
| "ok_text (McPulleyEffort n ld) V = STR ''The effort is '' + V + STR '' N (load '' + show4 (load_n ld)
     + STR '' N / '' + show4 n + STR '' supporting strands; ideal, frictionless).''"
| "ok_text (McLeverMA e l) V = STR ''The mechanical advantage is '' + V + STR '' (effort arm '' + show4 e
     + STR '' / load arm '' + show4 l + STR '').''"
| "ok_text (McLeverEffort e l ld) V = STR ''The effort needed is '' + V + STR '' N (load '' + show4 (load_n (the ld))
     + STR '' N x load arm '' + show4 l + STR '' / effort arm '' + show4 e + STR ''; ideal lever).''"
| "ok_text (McInclineMA l h) V = STR ''The ideal mechanical advantage is '' + V + STR '' (length '' + show4 l
     + STR '' / height '' + show4 h + STR '').''"
| "ok_text (McShaftPower n t) V = STR ''The shaft power is '' + V + STR '' W (P = 2 pi n T/60 = 2 pi x '' + show4 n
     + STR '' rpm x '' + show4 t + STR '' N m / 60).''"
| "ok_text (McTorque f r u) V = STR ''The torque is '' + V + STR '' N m (tau = F r = '' + show4 f + STR '' N x ''
     + show4 (r * len_scale u) + STR '' m).''"
| "ok_text (McTorqueAngle f r u a) V = STR ''The torque is '' + V + STR '' N m (tau = F r sin(theta) = '' + show4 f
     + STR '' N x '' + show4 (r * len_scale u) + STR '' m x sin '' + show4 a + STR '' deg).''"
| "ok_text (SpPasser c a y t i) V = STR ''The passer rating is '' + V + STR '' (NFL formula: (a + b + c + d) / 6 x 100, ''
     + STR ''each part clamped 0-2.375; '' + show4 c + STR ''/'' + show4 a + STR '' completions, '' + show4 y
     + STR '' yards, '' + show4 t + STR '' TD, '' + show4 i + STR '' INT).''"
| "ok_text (SpTrueShooting p fga fta) V = STR ''The true shooting percentage is '' + V
     + STR ''% (PTS / (2 x (FGA + 0.44 FTA)) = '' + show4 p + STR '' / (2 x ('' + show4 fga + STR '' + 0.44 x ''
     + show4 fta + STR ''))).''"
| "ok_text (SpEra w f er) V = STR ''The ERA is '' + V + STR '' (9 x '' + show4 er + STR '' earned runs / ''
     + show4 (w + f / 3) + STR '' innings).''"
| "ok_text (SpWhip w f bb h) V = STR ''The WHIP is '' + V + STR '' ((BB + H) / IP = ('' + show4 bb + STR '' + ''
     + show4 h + STR '') / '' + show4 (w + f / 3) + STR '').''"
| "ok_text (SpAvg h ab) V = STR ''The batting average is '' + V + STR '' ('' + show4 h + STR '' hits / ''
     + show4 ab + STR '' at-bats).''"
| "ok_text (SpObp h bb hbp sf ab) V = STR ''The on-base percentage is '' + V
     + STR '' ((H + BB + HBP) / (AB + BB + HBP + SF) = '' + show4 (h + bb + hbp) + STR '' / ''
     + show4 (ab + bb + hbp + sf) + STR '').''"
| "ok_text (SpSlg s1 h s2 s3 hr ab) V = STR ''The slugging percentage is '' + V + STR '' (TB / AB = ''
     + show4 (singles_of s1 h s2 s3 hr + 2 * s2 + 3 * s3 + 4 * hr) + STR '' / '' + show4 ab
     + STR ''; TB = 1B + 2x2B + 3x3B + 4xHR).''"
| "ok_text (SpGamesBehind wa la wb lb) V = STR ''The gap is '' + V + STR '' games (|(W_A - W_B) + (L_B - L_A)| / 2 = |(''
     + show4 wa + STR '' - '' + show4 wb + STR '') + ('' + show4 lb + STR '' - '' + show4 la + STR '')| / 2).''"
| "ok_text (SpWinPct w l t) V = STR ''The winning percentage is '' + V + STR '' ((W + 1/2 T) / G = ('' + show4 w
     + STR '' + 1/2 x '' + show4 t + STR '') / '' + show4 (w + l + t) + STR '').''"
| "ok_text (FvBraking v mu) V = STR ''The braking distance is '' + V + STR '' m (v^2/(2 mu g) with v = ''
     + show4 (spd (the v)) + STR '' m/s, mu = '' + show4 (the mu) + STR '').''"
| "ok_text (FvStopping v mu rt) V = STR ''The stopping distance is '' + V + STR '' m ('' + show4 (spd (the v) * the rt)
     + STR '' m reacting + '' + show4 (spd (the v) ^ 2 / (2 * the mu * g0)) + STR '' m braking; v = ''
     + show4 (spd (the v)) + STR '' m/s, mu = '' + show4 (the mu) + STR '', g = 9.80665).''"
| "ok_text (FvToLpk uk x) V = STR ''That is '' + V + STR '' L/100 km ('' + show4 (if uk then lpk_uk else lpk_us)
     + STR '' / '' + show4 x + (if uk then STR '' UK'' else STR '' US'') + STR '' mpg).''"
| "ok_text (FvToMpg uk x) V = STR ''That is '' + V + (if uk then STR '' UK'' else STR '' US'') + STR '' mpg (''
     + show4 (if uk then lpk_uk else lpk_us) + STR '' / '' + show4 x + STR '' L/100 km).''"
| "ok_text (FvCO2 d du ec dsl) V = STR ''The trip emits about '' + V + STR '' kg of CO2 ('' + show4 (gallons_of d du ec)
     + STR '' US gallons of '' + (if dsl then STR ''diesel'' else STR ''gasoline'') + STR '' x ''
     + show4 (if dsl then co2_diesel else co2_gasoline) + STR '' g/gal, EPA).''"
| "ok_text (FvCost d du ec pr) V = STR ''The fuel costs about $'' + V + STR '' (''
     + show4 (fuel_amount (gallons_of d du ec) (snd (the pr))) + STR '' '' + fuel_name (snd (the pr))
     + STR '' at $'' + show4 (fst (the pr)) + STR '' per unit).''"
| "ok_text (FvVolume d du ec u) V = STR ''The trip needs '' + V + STR '' '' + fuel_name u + STR '' of fuel.''"
| "ok_text FvNeed V = STR ''''"
| "ok_text (FsGauge f h) V = STR ''The gauge pressure is about '' + V + STR '' Pa ('' + show4 (qval (FsGauge f h) / 1000)
     + STR '' kPa) at '' + show4 (the h) + STR '' m in '' + fluid_name f + STR '' (P = rho g h = ''
     + show4 (fluid_density f) + STR '' x 9.80665 x '' + show4 (the h) + STR ''; add 101325 Pa for absolute).''"
| "ok_text (FsAbs f h) V = STR ''The absolute pressure is about '' + V + STR '' Pa ('' + show4 (qval (FsAbs f h) / 1000)
     + STR '' kPa) at '' + show4 (the h) + STR '' m in '' + fluid_name f + STR '' (P = P0 + rho g h = 101325 + ''
     + show4 (fluid_density f) + STR '' x 9.80665 x '' + show4 (the h) + STR '').''"
| "ok_text (FsBuoyant f v) V = STR ''The buoyant force is about '' + V + STR '' N (F = rho g V = ''
     + show4 (fluid_density f) + STR '' x 9.80665 x '' + show4 (vol_m3 (the v)) + STR '' m3 of ''
     + fluid_name f + STR '' displaced).''"
| "ok_text (FsSubmerged s f) V = STR ''The submerged fraction is about '' + V + STR '' ('' + show4 (100 * qval (FsSubmerged s f))
     + STR ''%) of a floating piece of '' + solid_name s + STR '' in '' + fluid_name f
     + STR '' (fraction = rho_solid/rho_fluid = '' + show4 (solid_density s) + STR ''/'' + show4 (fluid_density f) + STR '').''"
| "ok_text (BdUnreadable x1) V = V"
| "ok_text FsModelLimit V = V"
| "ok_text PhModelLimit V = V"
| "ok_text (PhPEAt g m h) V = STR ''The gravitational potential energy change is '' + V + STR '' J '' + grav_where g + STR '' (constant gravity; mass '' + show4 (the m) + STR '' kg, signed height change '' + show4 (the h) + STR '' m).''"
| "ok_text (McWork w eta) V = work_text w V + STR '' (useful output work / input work = '' + show4 eta + STR ''; fixed geometry).''"
| "ok_text (McNeed x1) V = V"

primrec sinks_text :: "request \<Rightarrow> String.literal" where
  "sinks_text (FsSubmerged s f) = STR ''It does not float: '' + solid_name s + STR '' (about ''
     + show4 (solid_density s) + STR '' kg/m3) is denser than '' + fluid_name f + STR '' (about ''
     + show4 (fluid_density f) + STR '' kg/m3), so all of it sinks.''"
| "sinks_text (PhRange x1 x2) = STR ''''"
| "sinks_text (PhImpact x1) = STR ''''"
| "sinks_text (PhFall x1) = STR ''''"
| "sinks_text (PhKE x1 x2) = STR ''''"
| "sinks_text (PhPE x1 x2) = STR ''''"
| "sinks_text (PhPEAt g m h) = STR ''''"
| "sinks_text PhModelLimit = STR ''''"
| "sinks_text (PhMomentum x1 x2) = STR ''''"
| "sinks_text (PhWeight x1) = STR ''''"
| "sinks_text (PhForce x1 x2) = STR ''''"
| "sinks_text (PhWork x1 x2) = STR ''''"
| "sinks_text (PhPower x1 x2) = STR ''''"
| "sinks_text (PhFinalV x1 x2 x3 x4) = STR ''''"
| "sinks_text (PhDistance x1 x2 x3 x4) = STR ''''"
| "sinks_text (BdWeight x1 x2) = STR ''''"
| "sinks_text (BdFall x1 x2) = STR ''''"
| "sinks_text (BdImpact x1 x2) = STR ''''"
| "sinks_text (BdPendulum x1 x2) = STR ''''"
| "sinks_text (BdUnreadable x1) = STR ''''"
| "sinks_text FsModelLimit = STR ''''"
| "sinks_text (McGearRatio x1 x2) = STR ''''"
| "sinks_text (McGearSpeed x1 x2 x3) = STR ''''"
| "sinks_text (McGearTorque x1 x2 x3) = STR ''''"
| "sinks_text (McBeltSpeed x1 x2 x3) = STR ''''"
| "sinks_text (McPulleyMA x1) = STR ''''"
| "sinks_text (McPulleyEffort x1 x2) = STR ''''"
| "sinks_text (McLeverMA x1 x2) = STR ''''"
| "sinks_text (McLeverEffort x1 x2 x3) = STR ''''"
| "sinks_text (McInclineMA x1 x2) = STR ''''"
| "sinks_text (McShaftPower x1 x2) = STR ''''"
| "sinks_text (McTorque x1 x2 x3) = STR ''''"
| "sinks_text (McTorqueAngle x1 x2 x3 x4) = STR ''''"
| "sinks_text (McWork w eta) = STR ''''"
| "sinks_text (McNeed x1) = STR ''''"
| "sinks_text (SpPasser x1 x2 x3 x4 x5) = STR ''''"
| "sinks_text (SpTrueShooting x1 x2 x3) = STR ''''"
| "sinks_text (SpEra x1 x2 x3) = STR ''''"
| "sinks_text (SpWhip x1 x2 x3 x4) = STR ''''"
| "sinks_text (SpAvg x1 x2) = STR ''''"
| "sinks_text (SpObp x1 x2 x3 x4 x5) = STR ''''"
| "sinks_text (SpSlg x1 x2 x3 x4 x5 x6) = STR ''''"
| "sinks_text (SpGamesBehind x1 x2 x3 x4) = STR ''''"
| "sinks_text (SpWinPct x1 x2 x3) = STR ''''"
| "sinks_text (FvBraking x1 x2) = STR ''''"
| "sinks_text (FvStopping x1 x2 x3) = STR ''''"
| "sinks_text (FvToLpk x1 x2) = STR ''''"
| "sinks_text (FvToMpg x1 x2) = STR ''''"
| "sinks_text (FvCO2 x1 x2 x3 x4) = STR ''''"
| "sinks_text (FvCost x1 x2 x3 x4) = STR ''''"
| "sinks_text (FvVolume d du ec u) = STR ''''"
| "sinks_text FvNeed = STR ''''"
| "sinks_text (FsGauge x1 x2) = STR ''''"
| "sinks_text (FsAbs x1 x2) = STR ''''"
| "sinks_text (FsBuoyant x1 x2) = STR ''''"

definition need_text :: "request \<Rightarrow> need \<Rightarrow> String.literal" where
  "need_text r w = (let wont = STR ''; I won'' + apos + STR ''t assume it.'' in case w of
     N_fuel \<Rightarrow> STR ''I need one trip distance, one fuel economy and unambiguous requested or price units, with every supplied number accounted for.''
   | N_speed_angle \<Rightarrow> STR ''I need a launch speed and an angle to compute that'' + wont
   | N_mass_speed \<Rightarrow> STR ''I need a mass and a speed to compute that'' + wont
   | N_mass_height \<Rightarrow> STR ''I need a mass and a height to compute that'' + wont
   | N_mass_velocity \<Rightarrow> STR ''I need a mass and a velocity to compute that'' + wont
   | N_mass_accel \<Rightarrow> STR ''I need a mass and an acceleration to compute that'' + wont
   | N_accel_time \<Rightarrow> STR ''I need an acceleration and a time (and a starting speed, or it starts from rest) to compute that'' + wont
   | N_start_speed \<Rightarrow> STR ''I need a starting speed (or say it starts from rest) to compute that'' + wont
   | N_mass_kg \<Rightarrow> STR ''I need a mass with a supported unit to compute that'' + wont
   | N_fall_height \<Rightarrow> STR ''I need the height it falls to compute that'' + wont
   | N_pendulum_length \<Rightarrow> STR ''I need the pendulum length to compute that'' + wont
   | N_mc_need n \<Rightarrow> (if n = 0 then STR ''I need to know which gear drives which (e.g. a 12-tooth gear drives a 36-tooth gear) to work that out'' + wont
        else if n = 1 then STR ''I need to know which pulley drives which, with both diameters, to work that out'' + wont
        else if n = 2 then STR ''I need the effort-arm and load-arm lengths to work that out'' + wont
        else if n = 3 then STR ''I need the ramp length and height to work that out'' + wont
        else if n = 5 then STR ''I need one unambiguous efficiency, all required quantities and their roles, with no conflicting or unused numbers'' + wont
        else STR ''I need the force and the lever arm to work that out'' + wont)
   | N_load \<Rightarrow> STR ''I need the load to work that out'' + wont
   | N_speed_friction \<Rightarrow> STR ''I need the speed and the tyre-road friction coefficient to work that out'' + wont
   | N_reaction \<Rightarrow> STR ''I need the driver reaction time (stopping distance includes it) to work that out'' + wont
   | N_price \<Rightarrow> (case r of FvCost d du ec pr \<Rightarrow> STR ''It needs '' + show4 (gallons_of d du ec)
        + STR '' US gallons ('' + show4 (gallons_of d du ec * l_per_gal) + STR '' L); give me the fuel price and I will cost it.''
        | _ \<Rightarrow> STR ''I need the fuel price.'')
   | N_depth \<Rightarrow> STR ''I need a depth to compute that'' + wont
   | N_volume \<Rightarrow> STR ''I need the submerged volume to compute that'' + wont
   | N_physics_conditions \<Rightarrow> STR ''The supplied conditions need a different physical model or an unambiguous gravity value and unit; I will not replace them with Earth or classical defaults.''
   | N_fluid_conditions \<Rightarrow> STR ''The supplied fluid conditions are outside this reader'' + apos + STR ''s fixed-property, standard-gravity and atmospheric-pressure model; I will not replace them with defaults.''
   | N_unreadable \<Rightarrow> (case r of BdUnreadable g \<Rightarrow> STR ''I recognise a gravity question ''
        + grav_where g + STR '', but I could not read every amount it needs, so I won'' + apos
        + STR ''t assume one (or Earth'' + apos + STR ''s gravity).''
        | _ \<Rightarrow> STR ''I could not read every amount.''))"

fun reason_text :: "reason \<Rightarrow> String.literal" where
  "reason_text R_nonpositive_gravity = STR ''The gravity must be positive.''"
| "reason_text R_negative_amount = STR ''That amount cannot be negative here.''"
| "reason_text R_zero_time = STR ''A power needs a time above zero.''"
| "reason_text R_zero_teeth = STR ''A gear needs teeth.''"
| "reason_text R_zero_diameter = STR ''A pulley needs a diameter above zero.''"
| "reason_text R_zero_strands = STR ''A pulley system needs supporting strands.''"
| "reason_text R_zero_arm = STR ''A lever arm must be above zero.''"
| "reason_text R_physical_domain = STR ''The stated magnitudes or event counts are outside the physical domain of this calculation.''"
| "reason_text R_ramp = STR ''A ramp can'' + apos + STR ''t rise more than its own length.''"
| "reason_text R_zero_attempts = STR ''A passer rating needs at least one attempt.''"
| "reason_text R_zero_shooting = STR ''True shooting needs at least one shot attempt.''"
| "reason_text R_bad_innings = STR ''That is not a valid innings figure: after the point, .1 and .2 mean one and two outs (thirds of an inning).''"
| "reason_text R_zero_innings = STR ''ERA and WHIP need innings pitched greater than zero.''"
| "reason_text R_zero_at_bats = STR ''A batting statistic needs at least one at-bat.''"
| "reason_text R_zero_games = STR ''A winning percentage needs at least one game.''"
| "reason_text R_friction = STR ''A friction coefficient must be above zero.''"
| "reason_text R_zero_economy = STR ''A fuel economy must be above zero.''"
| "reason_text R_zero_obp_chances = STR ''On-base percentage needs at least one at-bat, walk, hit-by-pitch, or sacrifice fly.''"
| "reason_text R_negative_gravity = STR ''A gravity magnitude cannot be negative.''"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of
       Underspecified N_price \<Rightarrow> STR ''need_price''
     | Underspecified N_fluid_conditions \<Rightarrow> STR ''unsupported_model''
     | Underspecified N_physics_conditions \<Rightarrow> STR ''unsupported_model''
     | Underspecified N_unreadable \<Rightarrow> STR ''unreadable''
     | Underspecified _ \<Rightarrow> STR ''underspecified''
     | Impossible _ \<Rightarrow> STR ''impossible''
     | Imprecise \<Rightarrow> STR ''imprecise'')"

definition decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r w = (case w of
       Underspecified n \<Rightarrow> need_text r n
     | Impossible why \<Rightarrow> reason_text why
     | Imprecise \<Rightarrow> STR ''The interval arithmetic could not pin four digits; I won'' + apos + STR ''t guess.'')"

definition kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name k = (case k of
       K_range \<Rightarrow> STR ''range'' | K_impact_speed \<Rightarrow> STR ''impact_speed'' | K_fall_time \<Rightarrow> STR ''fall_time''
     | K_ke \<Rightarrow> STR ''ke'' | K_pe \<Rightarrow> STR ''pe'' | K_momentum \<Rightarrow> STR ''momentum'' | K_weight \<Rightarrow> STR ''weight''
     | K_force \<Rightarrow> STR ''force'' | K_work \<Rightarrow> STR ''work'' | K_power \<Rightarrow> STR ''power''
     | K_final_velocity \<Rightarrow> STR ''final_velocity'' | K_distance \<Rightarrow> STR ''distance''
     | K_pendulum_period \<Rightarrow> STR ''pendulum_period'' | K_gear_ratio \<Rightarrow> STR ''gear_ratio''
     | K_gear_speed \<Rightarrow> STR ''gear_speed'' | K_gear_torque \<Rightarrow> STR ''gear_torque''
     | K_belt_speed \<Rightarrow> STR ''belt_speed'' | K_pulley_ma \<Rightarrow> STR ''pulley_ma''
     | K_pulley_effort \<Rightarrow> STR ''pulley_effort'' | K_lever_effort \<Rightarrow> STR ''lever_effort''
     | K_lever_ma \<Rightarrow> STR ''lever_ma'' | K_incline_ma \<Rightarrow> STR ''incline_ma''
     | K_shaft_power \<Rightarrow> STR ''shaft_power'' | K_torque \<Rightarrow> STR ''torque''
     | K_passer_rating \<Rightarrow> STR ''passer_rating'' | K_ts_pct \<Rightarrow> STR ''ts_pct'' | K_era \<Rightarrow> STR ''era''
     | K_whip \<Rightarrow> STR ''whip'' | K_slg \<Rightarrow> STR ''slg'' | K_obp \<Rightarrow> STR ''obp'' | K_avg \<Rightarrow> STR ''avg''
     | K_win_pct \<Rightarrow> STR ''win_pct'' | K_games_behind \<Rightarrow> STR ''games_behind''
     | K_braking \<Rightarrow> STR ''braking'' | K_stopping \<Rightarrow> STR ''stopping'' | K_to_lpk \<Rightarrow> STR ''to_lpk''
     | K_to_mpg \<Rightarrow> STR ''to_mpg'' | K_co2 \<Rightarrow> STR ''co2'' | K_trip_cost \<Rightarrow> STR ''trip_cost''
     | K_trip_litres \<Rightarrow> STR ''trip_litres'' | K_trip_gallons \<Rightarrow> STR ''trip_gallons''
     | K_pressure_gauge \<Rightarrow> STR ''pressure_gauge'' | K_pressure_abs \<Rightarrow> STR ''pressure_abs''
     | K_buoyant_force \<Rightarrow> STR ''buoyant_force'' | K_submerged_fraction \<Rightarrow> STR ''submerged_fraction''
     | K_sinks \<Rightarrow> STR ''sinks'' | K_declined \<Rightarrow> STR ''declined'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and
the stated value.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow> (case stated_dec k q of
         None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text r Imprecise) None
       | Some d \<Rightarrow> Reply True (kind_name k) (ok_text r (value_lit k d)) (Some (value_lit k d)))
   | Approx k d \<Rightarrow> Reply True (kind_name k) (ok_text r (render_dec 4 d)) (Some (render_dec 4 d))
   | Sinks \<Rightarrow> Reply True (kind_name K_sinks) (sinks_text r) None
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text r w) None)"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d. kernel r = Exact k q \<and> stated_dec k q = Some d) \<or> (\<exists>k d. kernel r = Approx k d) \<or>
     kernel r = Sinks"
  by (auto simp: reply_of_def split: outcome.splits option.splits)

theorem fluid_model_limit_refuses:
  "kernel FsModelLimit = Decline (Underspecified N_fluid_conditions) \<and>
   \<not> answered (reply_of FsModelLimit) \<and>
   reply_kind (reply_of FsModelLimit) = STR ''unsupported_model''"
  by (simp add: kernel_def decline_of_def reply_of_def decline_name_def)

theorem physics_model_limit_refuses:
  "kernel PhModelLimit = Decline (Underspecified N_physics_conditions) \<and>
   \<not> answered (reply_of PhModelLimit) \<and>
   reply_kind (reply_of PhModelLimit) = STR ''unsupported_model''"
  by (simp add: kernel_def decline_of_def reply_of_def decline_name_def)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated_dec k q = Some d \<Longrightarrow> stated (reply_of r) = Some (value_lit k d)"
  by (simp add: reply_of_def)

theorem reply_states_approx:
  "kernel r = Approx k d \<Longrightarrow> stated (reply_of r) = Some (render_dec 4 d)"
  by (simp add: reply_of_def)

theorem answered_physical_domain:
  assumes "answered (reply_of r)"
  shows "physical_domain r"
proof -
  have "decline_of r = None"
    using assms by (auto simp: reply_of_def kernel_def split: option.splits outcome.splits)
  then show ?thesis using decline_none by auto
qed

text \<open>A withheld reply names the kernel's decline.\<close>
theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)


section \<open>What each kind means\<close>

lemma div_mul:
  fixes e t y :: rat
  assumes "t \<noteq> 0" "y = e / t"
  shows "y * t = e"
  using assms by (simp add: field_simps)

lemma sqrt_model:
  assumes "0 \<le> (x::rat)"
  shows "0 \<le> sqrt (rl x) \<and> sqrt (rl x) ^ 2 = rl x"
proof -
  have q: "0 \<le> (rl x::real)" using assms by simp
  show ?thesis using q by (simp add: real_sqrt_ge_zero)
qed

lemma sqrt_div_model:
  assumes "0 \<le> (a::rat)" "0 < b"
  shows "0 \<le> sqrt (rl (a / b)) \<and> sqrt (rl (a / b)) ^ 2 * rl b = rl a"
proof -
  have p: "0 \<le> a / b" using assms by (rule divide_nonneg_pos)
  have bn: "b \<noteq> 0" using assms(2) by auto
  have e: "a / b * b = a" using bn by (simp add: field_simps)
  from sqrt_model[OF p] have s0: "0 \<le> sqrt (rl (a / b))" and s2: "sqrt (rl (a / b)) ^ 2 = rl (a / b)"
    by simp_all
  have "rl (a / b) * rl b = (rl (a / b * b) :: real)" by (rule of_rat_mult[symmetric])
  also have "\<dots> = rl a" by (simp only: e)
  finally show ?thesis using s0 s2 by simp
qed

lemma sqrt_div_model2:
  assumes "0 \<le> (a::rat)" "0 < b"
  shows "0 \<le> sqrt (rl a / rl b) \<and> sqrt (rl a / rl b) ^ 2 * rl b = rl a"
proof -
  have e: "(rl (a / b) :: real) = rl a / rl b" by (rule of_rat_divide)
  show ?thesis using sqrt_div_model[OF assms] unfolding e by blast
qed

subsection \<open>Physics\<close>

theorem kinetic_energy:
  assumes "kernel (PhKE (Some m) (Some v)) = Exact c y"
  shows "c = K_ke \<and> y = m * v ^ 2 / 2"
  using exact_facts[OF assms] by simp

theorem potential_energy:
  assumes "kernel (PhPE (Some m) (Some h)) = Exact c y"
  shows "c = K_pe \<and> y = m * g0 * h"
  using exact_facts[OF assms] by simp

theorem supplied_potential_energy:
  assumes "kernel (PhPEAt g (Some m) (Some h)) = Exact c y"
  shows "c = K_pe \<and> 0 \<le> m \<and> 0 \<le> g_of g \<and> y = m * g_of g * h"
  using exact_facts[OF assms] by simp

theorem supplied_potential_units:
  assumes "kernel (PhPEAt (G_stated (gravity_si a gu))
    (Some (mass_kg m mu)) (Some (length_m h lu))) = Exact c y"
  shows "c = K_pe \<and> 0 \<le> m \<and> 0 \<le> a \<and>
    y = (m * mass_scale mu) * (a * gravity_scale gu) * (h * len_scale lu)"
proof -
  have facts: "c=K_pe \<and> 0 \<le> mass_kg m mu \<and> 0 \<le> gravity_si a gu \<and>
    y=mass_kg m mu * gravity_si a gu * length_m h lu"
    using supplied_potential_energy[OF assms] by simp
  have signs: "0 \<le> m \<and> 0 \<le> a" using facts by simp
  show ?thesis using facts signs
    by (simp add: mass_kg_def gravity_si_def length_m_def)
qed

theorem supplied_potential_additive:
  assumes "kernel (PhPEAt g (Some m) (Some h)) = Exact c x"
    "kernel (PhPEAt g (Some m) (Some k)) = Exact d y"
    "kernel (PhPEAt g (Some m) (Some (h+k))) = Exact e z"
  shows "z=x+y"
  using supplied_potential_energy[OF assms(1)] supplied_potential_energy[OF assms(2)]
    supplied_potential_energy[OF assms(3)] by (simp add: algebra_simps)

theorem momentum_def:
  assumes "kernel (PhMomentum (Some m) (Some v)) = Exact c y"
  shows "c = K_momentum \<and> y = m * v"
  using exact_facts[OF assms] by simp

text \<open>Kinetic energy and momentum of one body agree: 2 E m = p^2.\<close>
theorem kinetic_energy_momentum:
  assumes "kernel (PhKE (Some m) (Some v)) = Exact c e"
    and "kernel (PhMomentum (Some m) (Some v)) = Exact c' p"
  shows "2 * e * m = p ^ 2"
proof -
  have e: "e = m * v ^ 2 / 2" using kinetic_energy[OF assms(1)] by simp
  have p: "p = m * v" using momentum_def[OF assms(2)] by simp
  show ?thesis using e p by (simp add: power2_eq_square field_simps)
qed

theorem weight_on_earth:
  assumes "kernel (PhWeight m) = Exact c y"
  shows "c = K_weight \<and> y = m * g0"
  using exact_facts[OF assms] by simp

theorem newton_force:
  assumes "kernel (PhForce (Some m) (Some a)) = Exact c y"
  shows "c = K_force \<and> y = m * a"
  using exact_facts[OF assms] by simp

theorem work_def:
  assumes "kernel (PhWork f d) = Exact c y"
  shows "c = K_work \<and> y = f * d"
  using exact_facts[OF assms] by simp

theorem power_def:
  assumes "kernel (PhPower e t) = Exact c y"
  shows "c = K_power \<and> t \<noteq> 0 \<and> y * t = e"
proof -
  have f: "c = K_power" "t \<noteq> 0" "y = e / t" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem final_velocity_def:
  assumes "kernel (PhFinalV (Some a) (Some t) u rest) = Exact c y"
  shows "c = K_final_velocity \<and> (u = None \<longrightarrow> rest) \<and> y = or0 u + a * t"
  using exact_facts[OF assms] by auto

theorem distance_def:
  assumes "kernel (PhDistance a t u rest) = Exact c y"
  shows "c = K_distance \<and> (u = None \<longrightarrow> rest) \<and> y = or0 u * t + a * t ^ 2 / 2"
  using exact_facts[OF assms] by auto

theorem impact_model:
  assumes "0 \<le> h"
  shows "0 \<le> phys (PhImpact h) \<and> phys (PhImpact h) ^ 2 = rl (2 * g0 * h)"
proof -
  have p: "0 \<le> 2 * g0 * h"
  proof (rule mult_nonneg_nonneg)
    show "0 \<le> 2 * g0" using g0_pos by linarith
    show "0 \<le> h" by (rule assms)
  qed
  show ?thesis using sqrt_model[OF p] by simp
qed

text \<open>Energy is conserved in a drop: the kinetic energy at the impact speed
the kernel models equals the potential energy the kernel states.\<close>
theorem drop_energy_conserved:
  assumes "0 \<le> h" and "kernel (PhPE (Some m) (Some h)) = Exact c e"
  shows "rl m * phys (PhImpact h) ^ 2 / 2 = (rl e :: real)"
proof -
  have e: "e = m * g0 * h" using potential_energy[OF assms(2)] by simp
  have s: "phys (PhImpact h) ^ 2 = rl (2 * g0 * h)" using impact_model[OF assms(1)] by simp
  show ?thesis using s e by (simp add: of_rat_mult of_rat_divide)
qed

theorem fall_model:
  assumes "0 \<le> h"
  shows "0 \<le> phys (PhFall h) \<and> phys (PhFall h) ^ 2 * rl g0 = rl (2 * h)"
proof -
  have p: "0 \<le> 2 * h" using assms by simp
  show ?thesis unfolding phys.simps using sqrt_div_model[OF p g0_pos] by blast
qed

theorem range_model:
  "phys (PhRange (Some v) (Some t)) * rl g0 = rl (v ^ 2) * sin (rl (2 * t / 180) * pi)"
proof -
  have "(rl g0 :: real) \<noteq> 0" by simp
  then show ?thesis by (simp add: of_rat_divide of_rat_power field_simps)
qed

subsection \<open>Bodies\<close>

theorem body_weight:
  assumes "kernel (BdWeight g (Some m)) = Exact c y"
  shows "c = K_weight \<and> 0 \<le> g_of g \<and> 0 \<le> m \<and> y = m * g_of g"
  using exact_facts[OF assms] by simp

theorem body_weight_units:
  assumes "kernel (BdWeight g (Some (mass_kg m u))) = Exact c y"
  shows "c = K_weight \<and> 0 \<le> g_of g \<and> 0 \<le> m \<and>
         y = (m * mass_scale u) * g_of g"
proof -
  have domain: "0 \<le> m" using body_weight[OF assms] by simp
  show ?thesis using domain body_weight[OF assms] by (simp add: mass_kg_def)
qed

theorem kinetic_energy_units:
  assumes "kernel (PhKE (Some (mass_kg m u)) (Some v)) = Exact c y"
  shows "c = K_ke \<and> 0 \<le> m \<and> y = (m * mass_scale u) * v ^ 2 / 2"
proof -
  have domain: "0 \<le> m" using exact_facts[OF assms] by simp
  show ?thesis using domain kinetic_energy[OF assms] by (simp add: mass_kg_def)
qed

theorem body_fall_model:
  assumes "0 < g_of g" "0 \<le> h"
  shows "0 \<le> phys (BdFall g (Some h)) \<and> phys (BdFall g (Some h)) ^ 2 * rl (g_of g) = rl (2 * h)"
proof -
  have p: "0 \<le> 2 * h" using assms by simp
  show ?thesis unfolding phys.simps option.sel using sqrt_div_model[OF p assms(1)] by blast
qed

theorem body_impact_model:
  assumes "0 < g_of g" "0 \<le> h"
  shows "0 \<le> phys (BdImpact g (Some h)) \<and> phys (BdImpact g (Some h)) ^ 2 = rl (2 * g_of g * h)"
proof -
  have p: "0 \<le> 2 * g_of g * h"
  proof (rule mult_nonneg_nonneg)
    show "0 \<le> 2 * g_of g" using assms(1) by linarith
    show "0 \<le> h" by (rule assms(2))
  qed
  show ?thesis using sqrt_model[OF p] by simp
qed

text \<open>The exact potential-energy change accepted at supplied gravity
matches the independently modelled impact kinetic energy for a drop from rest.\<close>
theorem supplied_drop_energy_conserved:
  assumes g: "0 < g_of g" and h: "0 \<le> h"
    and pe: "kernel (PhPEAt g (Some m) (Some h)) = Exact c e"
  shows "rl m / 2 * phys (BdImpact g (Some h)) ^ 2 = rl e"
proof -
  have en: "e=m*g_of g*h" using supplied_potential_energy[OF pe] by simp
  have sq: "phys (BdImpact g (Some h)) ^ 2 = rl (2*g_of g*h)"
    using body_impact_model[OF g h] by simp
  have step: "rl m / 2 * phys (BdImpact g (Some h)) ^ 2 =
      rl m / 2 * rl (2*g_of g*h)" by (subst sq, rule refl)
  have finish: "rl m / 2 * rl (2*g_of g*h) = rl e"
    by (simp add: en of_rat_mult of_rat_divide algebra_simps)
  show ?thesis by (rule trans[OF step finish])
qed

theorem pendulum_model:
  assumes "0 < g_of g" "0 \<le> l"
  shows "0 \<le> phys (BdPendulum g (Some l)) \<and>
         phys (BdPendulum g (Some l)) ^ 2 * rl (g_of g) = 4 * pi ^ 2 * rl l"
proof -
  have sm: "0 \<le> sqrt (rl l / rl (g_of g)) \<and> sqrt (rl l / rl (g_of g)) ^ 2 * rl (g_of g) = rl l"
    by (rule sqrt_div_model2[OF assms(2) assms(1)])
  from sm have s0: "0 \<le> sqrt (rl l / rl (g_of g))" and s2: "sqrt (rl l / rl (g_of g)) ^ 2 * rl (g_of g) = rl l"
    by blast+
  have ph: "phys (BdPendulum g (Some l)) = 2 * pi * sqrt (rl l / rl (g_of g))" by simp
  have nn: "0 \<le> 2 * pi * sqrt (rl l / rl (g_of g))"
    using s0 by (intro mult_nonneg_nonneg) (simp_all add: pi_ge_zero)
  have "(2 * pi * sqrt (rl l / rl (g_of g))) ^ 2 * rl (g_of g)
        = 4 * pi ^ 2 * (sqrt (rl l / rl (g_of g)) ^ 2 * rl (g_of g))"
    by (simp add: power_mult_distrib algebra_simps)
  also have "\<dots> = 4 * pi ^ 2 * rl l" by (simp only: s2)
  finally have sq: "(2 * pi * sqrt (rl l / rl (g_of g))) ^ 2 * rl (g_of g) = 4 * pi ^ 2 * rl l" .
  show ?thesis using nn sq unfolding ph by blast
qed

subsection \<open>Mechanisms\<close>

text \<open>The independent balance uses force times travel (or torque times
angle): useful output work equals efficiency times supplied input work.\<close>
definition transmission_balance :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> bool" where
  "transmission_balance input output din dout eta \<longleftrightarrow>
    output * dout = eta * (input * din)"

lemma efficiency_percent_bounds:
  "0 < efficiency_percent p \<and> efficiency_percent p \<le> 1 \<longleftrightarrow> 0 < p \<and> p \<le> 100"
  by (simp add: efficiency_percent_def)

theorem accepted_efficiency_domain:
  "kernel (McWork w eta) = Exact c y \<Longrightarrow> work_domain w \<and> 0 \<le> eta \<and> eta \<le> 1 \<and> (work_needs_positive w \<longrightarrow> 0 < eta)"
  by (auto dest: exact_facts)

theorem actual_pulley_effort_balance:
  assumes "kernel (McWork (W_pulley_effort n ld) eta) = Exact c y"
  shows "c = K_pulley_effort \<and> physical_count n \<and> 0 < n \<and> 0 \<le> fst ld \<and>
    0 < eta \<and> eta \<le> 1 \<and> transmission_balance y (load_n ld) (n * h) h eta"
proof -
  have f: "c = K_pulley_effort" "physical_count n" "0 < n" "0 \<le> fst ld"
    "0 < eta" "eta \<le> 1" "y = load_n ld / (eta * n)"
    using exact_facts[OF assms] by simp_all
  have nz: "eta \<noteq> 0" "n \<noteq> 0" using f by auto
  show ?thesis using f nz by (auto simp: transmission_balance_def field_simps)
qed

theorem actual_lever_effort_balance:
  assumes "kernel (McWork (W_lever_effort e l ld) eta) = Exact c y"
  shows "c = K_lever_effort \<and> 0 < e \<and> 0 < l \<and> 0 \<le> fst ld \<and>
    0 < eta \<and> eta \<le> 1 \<and> transmission_balance y (load_n ld) (e * theta) (l * theta) eta"
proof -
  have f: "c = K_lever_effort" "0 < e" "0 < l" "0 \<le> fst ld"
    "0 < eta" "eta \<le> 1" "y = load_n ld * l / (eta * e)"
    using exact_facts[OF assms] by simp_all
  have nz: "eta \<noteq> 0" "e \<noteq> 0" using f by auto
  show ?thesis using f nz by (auto simp: transmission_balance_def field_simps)
qed

theorem actual_gear_power_balance:
  assumes "kernel (McWork (W_gear_torque t a b) eta) = Exact c y"
  shows "c = K_gear_torque \<and> physical_count a \<and> physical_count b \<and>
    0 < a \<and> 0 < b \<and> 0 \<le> eta \<and> eta \<le> 1 \<and>
    transmission_balance t y (b * omega) (a * omega) eta"
proof -
  have f: "c = K_gear_torque" "physical_count a" "physical_count b" "0 < a" "0 < b"
    "0 \<le> eta" "eta \<le> 1" "y = eta * t * b / a"
    using exact_facts[OF assms] by simp_all
  have nz: "a \<noteq> 0" using f by auto
  show ?thesis using f nz by (auto simp: transmission_balance_def field_simps)
qed

theorem actual_advantage_balance:
  "kernel (McWork (W_pulley_ma n) eta) = Exact c y \<Longrightarrow>
     c = K_pulley_ma \<and> y = eta * n \<and> transmission_balance 1 y n 1 eta"
  "kernel (McWork (W_lever_ma e l) eta) = Exact c y \<Longrightarrow>
     c = K_lever_ma \<and> transmission_balance 1 y e l eta"
  "kernel (McWork (W_incline_ma l h) eta) = Exact c y \<Longrightarrow>
     c = K_incline_ma \<and> transmission_balance 1 y l h eta"
  by (auto dest: exact_facts simp: transmission_balance_def field_simps)

theorem efficient_lever_source_units:
  assumes "kernel (McWork (W_lever_effort (length_m e eu) (length_m l lu) (m,unit))
    (efficiency_percent p)) = Exact c y"
  shows "0 < e \<and> 0 < l \<and> 0 \<le> m \<and> 0 < p \<and> p \<le> 100 \<and>
    y * (e * len_scale eu) * (p / 100) =
      (if unit = LD_kg then m * g0 else m) * (l * len_scale lu)"
proof -
  note f = actual_lever_effort_balance[OF assms, where theta=1]
  have domain: "0 < e \<and> 0 < l \<and> 0 \<le> m \<and> 0 < p \<and> p \<le> 100"
    using f by (simp add: efficiency_percent_def)
  have balance: "y * length_m e eu * efficiency_percent p = load_n (m,unit) * length_m l lu"
    using f by (auto simp: transmission_balance_def algebra_simps)
  show ?thesis using domain balance
    by (cases unit) (auto simp: length_m_def load_n_def efficiency_percent_def)
qed

theorem efficiency_one_ideal_compatibility:
  "work_value (W_pulley_ma n) 1 = qval (McPulleyMA n)"
  "work_value (W_pulley_effort n ld) 1 = qval (McPulleyEffort n ld)"
  "work_value (W_lever_ma e l) 1 = qval (McLeverMA e l)"
  "work_value (W_lever_effort e l ld) 1 = qval (McLeverEffort e l (Some ld))"
  "work_value (W_gear_torque t a b) 1 = qval (McGearTorque t a b)"
  "work_value (W_incline_ma l h) 1 = qval (McInclineMA l h)"
  by simp_all

theorem efficiency_invariant_quantities:
  "work_value (W_pulley_ideal n) eta = n"
  "work_value (W_lever_ideal e l) eta = e / l"
  "work_value (W_incline_ideal l h) eta = l / h"
  "b \<noteq> 0 \<Longrightarrow> work_value (W_gear_speed n a b) eta * b = n * a"
  "b \<noteq> 0 \<Longrightarrow> work_value (W_belt_speed n a b) eta * b = n * a"
  by (simp_all add: field_simps)

theorem gear_ratio_def:
  assumes "kernel (McGearRatio a b) = Exact c y"
  shows "c = K_gear_ratio \<and> a \<noteq> 0 \<and> y * a = b"
proof -
  have f: "c = K_gear_ratio" "a \<noteq> 0" "y = b / a" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem gear_speed_def:
  assumes "kernel (McGearSpeed n a b) = Exact c y"
  shows "c = K_gear_speed \<and> a \<noteq> 0 \<and> b \<noteq> 0 \<and> y * b = n * a"
proof -
  have f: "c = K_gear_speed" "a \<noteq> 0" "b \<noteq> 0" "y = n * a / b" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(3) f(4)]
  show ?thesis using f d by blast
qed

theorem gear_torque_def:
  assumes "kernel (McGearTorque t a b) = Exact c y"
  shows "c = K_gear_torque \<and> a \<noteq> 0 \<and> y * a = t * b"
proof -
  have f: "c = K_gear_torque" "a \<noteq> 0" "y = t * b / a" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem belt_speed_def:
  assumes "kernel (McBeltSpeed n d1 d2) = Exact c y"
  shows "c = K_belt_speed \<and> d2 \<noteq> 0 \<and> y * d2 = n * d1"
proof -
  have f: "c = K_belt_speed" "d2 \<noteq> 0" "y = n * d1 / d2" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem pulley_ma_def:
  assumes "kernel (McPulleyMA n) = Exact c y"
  shows "c = K_pulley_ma \<and> y = n"
  using exact_facts[OF assms] by simp

theorem pulley_effort_def:
  assumes "kernel (McPulleyEffort n ld) = Exact c y"
  shows "c = K_pulley_effort \<and> n \<noteq> 0 \<and> y * n = load_n ld"
proof -
  have f: "c = K_pulley_effort" "n \<noteq> 0" "y = load_n ld / n" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem lever_ma_def:
  assumes "kernel (McLeverMA e l) = Exact c y"
  shows "c = K_lever_ma \<and> l \<noteq> 0 \<and> y * l = e"
proof -
  have f: "c = K_lever_ma" "l \<noteq> 0" "y = e / l" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem lever_effort_def:
  assumes "kernel (McLeverEffort e l (Some ld)) = Exact c y"
  shows "c = K_lever_effort \<and> e \<noteq> 0 \<and> y * e = load_n ld * l"
proof -
  have f: "c = K_lever_effort" "e \<noteq> 0" "y = load_n ld * l / e" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

text \<open>These are the exact length conversions consumed by the recognizer;
the response is bound to both original magnitudes and their declared units.\<close>
theorem lever_units:
  assumes "kernel (McLeverMA (length_m e eu) (length_m l lu)) = Exact c y"
  shows "c = K_lever_ma \<and> 0 < e \<and> 0 < l \<and>
    y * (l * len_scale lu) = e * len_scale eu"
proof -
  have domain: "0 < e" "0 < l" using exact_facts[OF assms] by auto
  show ?thesis using domain lever_ma_def[OF assms] by (simp add: length_m_def)
qed

theorem lever_effort_units:
  assumes "kernel (McLeverEffort (length_m e eu) (length_m l lu) (Some ld)) = Exact c y"
  shows "c = K_lever_effort \<and> 0 < e \<and> 0 < l \<and> 0 \<le> fst ld \<and>
    y * (e * len_scale eu) = load_n ld * (l * len_scale lu)"
proof -
  have good: "physical_domain (McLeverEffort (length_m e eu) (length_m l lu) (Some ld))"
    using exact_facts[OF assms] by auto
  have domain: "0 < e \<and> 0 < l \<and> 0 \<le> fst ld"
    using good by (cases ld) auto
  show ?thesis using domain lever_effort_def[OF assms] by (simp add: length_m_def)
qed

theorem incline_ma_def:
  assumes "kernel (McInclineMA l h) = Exact c y"
  shows "c = K_incline_ma \<and> 0 < h \<and> h \<le> l \<and> y * h = l"
proof -
  have f: "c = K_incline_ma" "0 < h" "h \<le> l" "y = l / h" using exact_facts[OF assms] by simp_all
  have hn: "h \<noteq> 0" using f(2) by auto
  note d = div_mul[OF hn f(4)]
  show ?thesis using f d by blast
qed

theorem torque_def:
  assumes "kernel (McTorque f r u) = Exact c y"
  shows "c = K_torque \<and> y = f * r * len_scale u"
  using exact_facts[OF assms] by simp

theorem shaft_power_model:
  "phys (McShaftPower n t) * 60 = 2 * pi * rl (n * t)"
proof -
  have e: "n * t / 60 * 60 = n * t" by (simp add: field_simps)
  have m: "rl (n * t / 60 * 60) = rl (n * t / 60) * (rl 60 :: real)" by (rule of_rat_mult)
  have s: "(rl 60 :: real) = 60" by simp
  have k: "rl (n * t / 60) * 60 = (rl (n * t) :: real)" using m s e by metis
  have "phys (McShaftPower n t) * 60 = 2 * pi * (rl (n * t / 60) * 60)" by (simp add: mult.assoc)
  also have "\<dots> = 2 * pi * rl (n * t)" by (simp only: k)
  finally show ?thesis .
qed

theorem torque_angle_bound:
  "\<bar>phys (McTorqueAngle f r u a)\<bar> \<le> \<bar>rl (f * r * len_scale u)\<bar>"
proof -
  have "\<bar>sin (rl (a / 180) * pi)\<bar> \<le> 1" by (rule abs_sin_le_one)
  then have "\<bar>rl (f * r * len_scale u)\<bar> * \<bar>sin (rl (a / 180) * pi)\<bar> \<le> \<bar>rl (f * r * len_scale u)\<bar> * 1"
    by (rule mult_left_mono) simp
  then show ?thesis by (simp add: abs_mult)
qed

subsection \<open>Sports\<close>

theorem passer_rating_def:
  assumes "kernel (SpPasser c a y t i) = Exact k res"
  shows "k = K_passer_rating \<and> 0 < a \<and> 0 \<le> res \<and> res \<le> 475 / 3 \<and>
         res = (cl_rating ((c / a - 3 / 10) * 5) + cl_rating ((y / a - 3) / 4) + cl_rating (t / a * 20)
                + cl_rating (19 / 8 - i / a * 25)) / 6 * 100"
proof -
  have f: "k = K_passer_rating" "0 < a"
    "res = (cl_rating ((c / a - 3 / 10) * 5) + cl_rating ((y / a - 3) / 4) + cl_rating (t / a * 20)
            + cl_rating (19 / 8 - i / a * 25)) / 6 * 100"
    using exact_facts[OF assms] by simp_all
  have b1: "0 \<le> cl_rating ((c / a - 3 / 10) * 5) \<and> cl_rating ((c / a - 3 / 10) * 5) \<le> 19 / 8"
    by (rule cl_rating_bounds)
  have b2: "0 \<le> cl_rating ((y / a - 3) / 4) \<and> cl_rating ((y / a - 3) / 4) \<le> 19 / 8"
    by (rule cl_rating_bounds)
  have b3: "0 \<le> cl_rating (t / a * 20) \<and> cl_rating (t / a * 20) \<le> 19 / 8"
    by (rule cl_rating_bounds)
  have b4: "0 \<le> cl_rating (19 / 8 - i / a * 25) \<and> cl_rating (19 / 8 - i / a * 25) \<le> 19 / 8"
    by (rule cl_rating_bounds)
  from b1 b2 b3 b4 have l: "0 \<le> cl_rating ((c / a - 3 / 10) * 5)" "0 \<le> cl_rating ((y / a - 3) / 4)"
    "0 \<le> cl_rating (t / a * 20)" "0 \<le> cl_rating (19 / 8 - i / a * 25)"
    and u: "cl_rating ((c / a - 3 / 10) * 5) \<le> 19 / 8" "cl_rating ((y / a - 3) / 4) \<le> 19 / 8"
    "cl_rating (t / a * 20) \<le> 19 / 8" "cl_rating (19 / 8 - i / a * 25) \<le> 19 / 8" by blast+
  have pb: "0 \<le> res \<and> res \<le> 475 / 3" unfolding f(3)
    by (rule passer_bounds[OF l(1) l(2) l(3) l(4) u(1) u(2) u(3) u(4)])
  have lo: "0 \<le> res" and hi: "res \<le> 475 / 3" using pb by blast+
  show ?thesis using f lo hi by simp
qed

theorem true_shooting_def:
  assumes "kernel (SpTrueShooting p fga fta) = Exact c y"
  shows "c = K_ts_pct \<and> 0 < 2 * (fga + 11 / 25 * fta) \<and> y = p / (2 * (fga + 11 / 25 * fta)) * 100"
  using exact_facts[OF assms] by simp

theorem era_def:
  assumes "kernel (SpEra w f er) = Exact c y"
  shows "c = K_era \<and> f < 3 \<and> 0 < w + f / 3 \<and> y * (w + f / 3) = 9 * er"
proof -
  have f: "c = K_era" "f < 3" "0 < w + f / 3" "y = 9 * er / (w + f / 3)"
    using exact_facts[OF assms] by simp_all
  have n: "w + f / 3 \<noteq> 0" using f(3) by auto
  note d = div_mul[OF n f(4)]
  show ?thesis using f d by blast
qed

theorem whip_def:
  assumes "kernel (SpWhip w f bb h) = Exact c y"
  shows "c = K_whip \<and> f < 3 \<and> 0 < w + f / 3 \<and> y * (w + f / 3) = bb + h"
proof -
  have f: "c = K_whip" "f < 3" "0 < w + f / 3" "y = (bb + h) / (w + f / 3)"
    using exact_facts[OF assms] by simp_all
  have n: "w + f / 3 \<noteq> 0" using f(3) by auto
  note d = div_mul[OF n f(4)]
  show ?thesis using f d by blast
qed

theorem batting_average_def:
  assumes "kernel (SpAvg h ab) = Exact c y"
  shows "c = K_avg \<and> 0 < ab \<and> y * ab = h"
proof -
  have f: "c = K_avg" "0 < ab" "y = h / ab" using exact_facts[OF assms] by simp_all
  have n: "ab \<noteq> 0" using f(2) by auto
  note d = div_mul[OF n f(3)]
  show ?thesis using f d by blast
qed

theorem on_base_def:
  assumes "kernel (SpObp h bb hbp sf ab) = Exact c y"
  shows "c = K_obp \<and> 0 < ab + bb + hbp + sf \<and>
    y * (ab + bb + hbp + sf) = h + bb + hbp"
proof -
  have f: "c = K_obp" "0 < ab + bb + hbp + sf"
    "y = (h + bb + hbp) / (ab + bb + hbp + sf)"
    using exact_facts[OF assms] by simp_all
  have nz: "ab + bb + hbp + sf \<noteq> 0" using f(2) by auto
  show ?thesis using f div_mul[OF nz f(3)] by blast
qed

theorem slugging_def:
  assumes "kernel (SpSlg s1 h s2 s3 hr ab) = Exact c y"
  shows "c = K_slg \<and> 0 < ab \<and> y * ab = singles_of s1 h s2 s3 hr + 2 * s2 + 3 * s3 + 4 * hr"
proof -
  have f: "c = K_slg" "0 < ab" "y = (singles_of s1 h s2 s3 hr + 2 * s2 + 3 * s3 + 4 * hr) / ab"
    using exact_facts[OF assms] by simp_all
  have n: "ab \<noteq> 0" using f(2) by auto
  note d = div_mul[OF n f(3)]
  show ?thesis using f d by blast
qed

theorem games_behind_def:
  assumes "kernel (SpGamesBehind wa la wb lb) = Exact c y"
  shows "c = K_games_behind \<and> 0 \<le> y \<and> y * 2 = \<bar>(wa - wb) + (lb - la)\<bar>"
proof -
  have f: "c = K_games_behind" "y = \<bar>(wa - wb) + (lb - la)\<bar> / 2" using exact_facts[OF assms] by simp_all
  show ?thesis using f by (auto simp: field_simps)
qed

theorem win_pct_def:
  assumes "kernel (SpWinPct w l t) = Exact c y"
  shows "c = K_win_pct \<and> 0 < w + l + t \<and> y * (w + l + t) = w + t / 2"
proof -
  have f: "c = K_win_pct" "0 < w + l + t" "y = (w + t / 2) / (w + l + t)"
    using exact_facts[OF assms] by simp_all
  have n: "w + l + t \<noteq> 0" using f(2) by auto
  note d = div_mul[OF n f(3)]
  show ?thesis using f d by blast
qed

subsection \<open>Fleet\<close>

theorem braking_def:
  assumes "kernel (FvBraking (Some v) (Some mu)) = Exact c y"
  shows "c = K_braking \<and> 0 < mu \<and> y * (2 * mu * g0) = spd v ^ 2"
proof -
  have f: "c = K_braking" "0 < mu" "y = spd v ^ 2 / (2 * mu * g0)" using exact_facts[OF assms] by simp_all
  have mn: "mu \<noteq> 0" using f(2) by auto
  have n: "2 * mu * g0 \<noteq> 0" using mn by simp
  note d = div_mul[OF n f(3)]
  show ?thesis using f d by blast
qed

theorem stopping_def:
  assumes "kernel (FvStopping (Some v) (Some mu) (Some rt)) = Exact c y"
  shows "c = K_stopping \<and> 0 < mu \<and> y = spd v * rt + spd v ^ 2 / (2 * mu * g0)"
  using exact_facts[OF assms] by simp

text \<open>Stopping distance is the reaction distance plus the braking distance.\<close>
theorem stopping_is_reaction_plus_braking:
  assumes "kernel (FvStopping (Some v) (Some mu) (Some rt)) = Exact c s"
    and "kernel (FvBraking (Some v) (Some mu)) = Exact c' b"
  shows "s = spd v * rt + b"
proof -
  have s: "s = spd v * rt + spd v ^ 2 / (2 * mu * g0)" using stopping_def[OF assms(1)] by simp
  have "b * (2 * mu * g0) = spd v ^ 2" and mu: "0 < mu" using braking_def[OF assms(2)] by simp_all
  hence b: "b = spd v ^ 2 / (2 * mu * g0)" using mu by (simp add: eq_divide_eq)
  show ?thesis using s b by simp
qed

theorem to_lpk_def:
  assumes "kernel (FvToLpk uk x) = Exact c y"
  shows "c = K_to_lpk \<and> x \<noteq> 0 \<and> y * x = (if uk then lpk_uk else lpk_us)"
proof -
  have f: "c = K_to_lpk" "x \<noteq> 0" "y = (if uk then lpk_uk else lpk_us) / x" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem to_mpg_def:
  assumes "kernel (FvToMpg uk x) = Exact c y"
  shows "c = K_to_mpg \<and> x \<noteq> 0 \<and> y * x = (if uk then lpk_uk else lpk_us)"
proof -
  have f: "c = K_to_mpg" "x \<noteq> 0" "y = (if uk then lpk_uk else lpk_us) / x" using exact_facts[OF assms] by simp_all
  note d = div_mul[OF f(2) f(3)]
  show ?thesis using f d by blast
qed

theorem trip_co2_def:
  assumes "kernel (FvCO2 d du ec dsl) = Exact c y"
  shows "c = K_co2 \<and> \<not> econ_zero ec \<and>
         y = gallons_of d du ec * (if dsl then co2_diesel else co2_gasoline) / 1000"
  using exact_facts[OF assms] by simp

theorem trip_cost_def:
  assumes "kernel (FvCost d du ec (Some pr)) = Exact c y"
  shows "c = K_trip_cost \<and> \<not> econ_zero ec \<and> 0 \<le> d \<and> y = price_cost (gallons_of d du ec) pr"
  using exact_facts[OF assms] by simp

theorem trip_volume_source_units:
  assumes "kernel (FvVolume d du ec u) = Exact c y"
  shows "c = (if u = FU_litre then K_trip_litres else K_trip_gallons) \<and>
    0 \<le> d \<and> economy_domain ec \<and> fuel_balance d du ec (y * fuel_scale u)"
proof -
  have f: "c = (if u = FU_litre then K_trip_litres else K_trip_gallons)"
    "0 \<le> d" "economy_domain ec" "y = fuel_amount (gallons_of d du ec) u"
    using exact_facts[OF assms] by simp_all
  show ?thesis using f gallons_source_balance[OF f(3), of d du]
    by (simp add: fuel_amount_units)
qed

theorem trip_price_source_units:
  assumes "kernel (FvCost d du ec (Some (p,u))) = Exact c y"
  shows "c = K_trip_cost \<and> 0 \<le> d \<and> 0 \<le> p \<and> economy_domain ec \<and>
    (\<exists>litres. fuel_balance d du ec litres \<and> y * fuel_scale u = litres * p)"
proof -
  have f: "c = K_trip_cost" "0 \<le> d" "0 \<le> p" "economy_domain ec"
    "y = price_cost (gallons_of d du ec) (p,u)"
    using exact_facts[OF assms] by simp_all
  have balance: "fuel_balance d du ec (gallons_of d du ec * l_per_gal)"
    using gallons_source_balance[OF f(4)] .
  have units: "y * fuel_scale u = (gallons_of d du ec * l_per_gal) * p"
    using f(5) by (simp add: price_cost_def fuel_amount_def field_simps)
  show ?thesis using f balance units by blast
qed

subsection \<open>Fluid statics\<close>

theorem gauge_pressure:
  assumes "kernel (FsGauge f (Some h)) = Exact c y"
  shows "c = K_pressure_gauge \<and> y = fluid_density f * g0 * h"
  using exact_facts[OF assms] by simp

theorem absolute_pressure:
  assumes "kernel (FsAbs f (Some h)) = Exact c y"
  shows "c = K_pressure_abs \<and> y = p0 + fluid_density f * g0 * h"
  using exact_facts[OF assms] by simp

theorem buoyant_force:
  assumes "kernel (FsBuoyant f (Some v)) = Exact c y"
  shows "c = K_buoyant_force \<and> y = fluid_density f * g0 * vol_m3 v"
  using exact_facts[OF assms] by simp

theorem submerged_fraction:
  assumes "kernel (FsSubmerged s f) = Exact c y"
  shows "c = K_submerged_fraction \<and> y * fluid_density f = solid_density s \<and> 0 < y \<and> y < 1"
proof -
  have f: "c = K_submerged_fraction" "\<not> fluid_density f \<le> solid_density s"
    "y = solid_density s / fluid_density f"
    using exact_facts[OF assms] by simp_all
  have n: "fluid_density f \<noteq> 0" by (metis fluid_density_pos less_irrefl)
  have lt: "solid_density s < fluid_density f" using f(2) by simp
  have "y < 1" using f(3) lt by (simp add: divide_less_eq_1_pos)
  moreover have "0 < y" using f(3) by simp
  ultimately show ?thesis using f div_mul[OF n f(3)] by blast
qed

theorem submerged_sinks:
  "kernel (FsSubmerged s f) = Sinks \<longleftrightarrow> fluid_density f \<le> solid_density s"
  by (simp add: kernel_def decline_of_def reason_of_def answer_of_def split: if_splits)

end
