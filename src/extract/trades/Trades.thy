theory Trades
  imports Trades_Num
begin

text \<open>
  Six shipped Oracle7 specialists (architecture, printing, printing-v2, safety,
  woodworking, crafts: upstream/root/specialists/<id>/organ_*.py) as one
  verified HOL kernel. A typed request (what the question asks, its numbers
  already read off by the untrusted recognizer) goes to an outcome: an exact
  rational value, a pair of values, a colour, a decimal enclosure (the
  quantities that need pi, a square root, an arctangent, a power of 2 or a
  logarithm), or a decline. Rounding up and down (occupant loads, layers,
  sheets, risers, blocks) is exact on rationals; the organs' 1e-9 tolerance
  is part of the definition.

  The tables (occupancy factors, filament densities, lumber sizes, colour
  wheels) are HOL constants transcribed from the organs; tables_check.py parses
  the organ files and this file and fails on any difference.
\<close>

section \<open>Tables\<close>

datatype occ_use = O_business | O_mercantile | O_residential | O_classroom | O_standing
  | O_concentrated | O_unconcentrated | O_exercise | O_reading | O_stacks | O_kitchen | O_warehouse

fun use_factor :: "occ_use \<Rightarrow> rat" where
  "use_factor O_business = 150"
| "use_factor O_mercantile = 60"
| "use_factor O_residential = 200"
| "use_factor O_classroom = 20"
| "use_factor O_standing = 5"
| "use_factor O_concentrated = 7"
| "use_factor O_unconcentrated = 15"
| "use_factor O_exercise = 50"
| "use_factor O_reading = 50"
| "use_factor O_stacks = 100"
| "use_factor O_kitchen = 200"
| "use_factor O_warehouse = 500"

fun use_label :: "occ_use \<Rightarrow> String.literal" where
  "use_label O_business = STR ''business, 150 gross''"
| "use_label O_mercantile = STR ''mercantile, 60 gross''"
| "use_label O_residential = STR ''residential, 200 gross''"
| "use_label O_classroom = STR ''classroom, 20 net''"
| "use_label O_standing = STR ''assembly standing space, 5 net''"
| "use_label O_concentrated = STR ''assembly concentrated (chairs only), 7 net''"
| "use_label O_unconcentrated = STR ''assembly unconcentrated (tables and chairs), 15 net''"
| "use_label O_exercise = STR ''exercise rooms, 50 gross''"
| "use_label O_reading = STR ''library reading rooms, 50 net''"
| "use_label O_stacks = STR ''library stack areas, 100 gross''"
| "use_label O_kitchen = STR ''commercial kitchens, 200 gross''"
| "use_label O_warehouse = STR ''warehouses / storage, 500 gross''"

text \<open>The organ's LOAD list order (the first pattern that matches wins).\<close>
definition use_order :: "occ_use list" where
  "use_order = [O_business, O_mercantile, O_residential, O_classroom, O_standing, O_concentrated,
     O_unconcentrated, O_exercise, O_reading, O_stacks, O_kitchen, O_warehouse]"

lemma use_factor_pos [simp]: "0 < use_factor u"
  by (cases u) simp_all

datatype load_src = Given rat | Table occ_use

fun load_factor :: "load_src \<Rightarrow> rat" where
  "load_factor (Given f) = f"
| "load_factor (Table u) = use_factor u"

datatype filament = F_pla | F_petg | F_abs | F_asa | F_tpu | F_nylon

fun fil_rho :: "filament \<Rightarrow> rat" where
  "fil_rho F_pla = 124 / 100"
| "fil_rho F_petg = 127 / 100"
| "fil_rho F_abs = 104 / 100"
| "fil_rho F_asa = 107 / 100"
| "fil_rho F_tpu = 121 / 100"
| "fil_rho F_nylon = 114 / 100"

fun fil_name :: "filament \<Rightarrow> String.literal" where
  "fil_name F_pla = STR ''PLA''"
| "fil_name F_petg = STR ''PETG''"
| "fil_name F_abs = STR ''ABS''"
| "fil_name F_asa = STR ''ASA''"
| "fil_name F_tpu = STR ''TPU''"
| "fil_name F_nylon = STR ''nylon''"

definition fil_order :: "filament list" where
  "fil_order = [F_pla, F_petg, F_abs, F_asa, F_tpu, F_nylon]"

lemma fil_rho_pos [simp]: "0 < fil_rho f"
  by (cases f) simp_all

datatype dens_src = D_given rat | D_typical filament | D_none

fun dens :: "dens_src \<Rightarrow> rat" where
  "dens (D_given r) = r"
| "dens (D_typical f) = fil_rho f"
| "dens D_none = 0"

text \<open>Nominal dimensional-lumber sizes to actual dressed dry sizes in inches (PS 20).\<close>
definition actual_tab :: "(nat \<times> rat) list" where
  "actual_tab = [(1, 3 / 4), (2, 3 / 2), (3, 5 / 2), (4, 7 / 2), (6, 11 / 2), (8, 29 / 4), (10, 37 / 4), (12, 45 / 4)]"

definition actual :: "nat \<Rightarrow> rat option" where "actual n = map_of actual_tab n"

datatype sheet = S32 | S40 | S48

fun sheet_area :: "sheet \<Rightarrow> rat" where
  "sheet_area S32 = 32"
| "sheet_area S40 = 40"
| "sheet_area S48 = 48"

lemma sheet_area_pos [simp]: "0 < sheet_area s"
  by (cases s) simp_all

datatype colour = C_red | C_yellow | C_blue | C_green | C_orange | C_purple | C_violet | C_cyan | C_magenta | C_white | C_black

fun cname :: "colour \<Rightarrow> String.literal" where
  "cname C_red = STR ''red''"
| "cname C_yellow = STR ''yellow''"
| "cname C_blue = STR ''blue''"
| "cname C_green = STR ''green''"
| "cname C_orange = STR ''orange''"
| "cname C_purple = STR ''purple''"
| "cname C_violet = STR ''violet''"
| "cname C_cyan = STR ''cyan''"
| "cname C_magenta = STR ''magenta''"
| "cname C_white = STR ''white''" | "cname C_black = STR ''black''"

text \<open>Alphabetical rank of the colour names (the organ prints the pair sorted).\<close>
fun crank :: "colour \<Rightarrow> nat" where
  "crank C_black = 0" | "crank C_blue = 1" | "crank C_cyan = 2" | "crank C_green = 3"
| "crank C_magenta = 4" | "crank C_orange = 5" | "crank C_purple = 6" | "crank C_red = 7"
| "crank C_violet = 8" | "crank C_white = 9" | "crank C_yellow = 10"

definition input_colours :: "colour list" where
  "input_colours = [C_red, C_yellow, C_blue, C_green, C_orange, C_purple, C_violet]"

text \<open>Traditional RYB painter's wheel: red + yellow = orange and so on.\<close>
definition mix_ryb :: "colour \<Rightarrow> colour \<Rightarrow> colour option" where
  "mix_ryb a b = (if (a = C_red \<and> b = C_yellow) \<or> (a = C_yellow \<and> b = C_red) then Some C_orange
     else if (a = C_yellow \<and> b = C_blue) \<or> (a = C_blue \<and> b = C_yellow) then Some C_green
     else if (a = C_red \<and> b = C_blue) \<or> (a = C_blue \<and> b = C_red) then Some C_purple else None)"

text \<open>Additive RGB light: red + green = yellow, green + blue = cyan, red + blue = magenta.\<close>
definition mix_rgb :: "colour \<Rightarrow> colour \<Rightarrow> colour option" where
  "mix_rgb a b = (if (a = C_red \<and> b = C_green) \<or> (a = C_green \<and> b = C_red) then Some C_yellow
     else if (a = C_green \<and> b = C_blue) \<or> (a = C_blue \<and> b = C_green) then Some C_cyan
     else if (a = C_red \<and> b = C_blue) \<or> (a = C_blue \<and> b = C_red) then Some C_magenta else None)"

text \<open>Full digital RGB channels combine by saturation. This discrete
model does not determine brightness ratios or spectra of physical lights.\<close>

type_synonym rgb_bits = "bool \<times> bool \<times> bool"
datatype rgb_channel = RedChannel | GreenChannel | BlueChannel

fun rgb_mask :: "colour \<Rightarrow> rgb_bits" where
  "rgb_mask C_red = (True,False,False)"
| "rgb_mask C_green = (False,True,False)"
| "rgb_mask C_blue = (False,False,True)"
| "rgb_mask C_yellow = (True,True,False)"
| "rgb_mask C_cyan = (False,True,True)"
| "rgb_mask C_magenta = (True,False,True)"
| "rgb_mask C_white = (True,True,True)"
| "rgb_mask _ = (False,False,False)"

definition rgb_supported :: "colour \<Rightarrow> bool" where
  "rgb_supported c \<longleftrightarrow> c \<in> {C_red,C_green,C_blue,C_yellow,C_cyan,C_magenta,C_white,C_black}"

fun union_rgb :: "rgb_bits \<Rightarrow> rgb_bits \<Rightarrow> rgb_bits" where
  "union_rgb (r,g,b) (r',g',b') = (r \<or> r',g \<or> g',b \<or> b')"

fun fold_rgb :: "colour list \<Rightarrow> rgb_bits" where
  "fold_rgb [] = (False,False,False)"
| "fold_rgb (c#cs) = union_rgb (rgb_mask c) (fold_rgb cs)"

fun rgb_colour :: "rgb_bits \<Rightarrow> colour" where
  "rgb_colour (True,True,True) = C_white"
| "rgb_colour (True,True,False) = C_yellow"
| "rgb_colour (True,False,True) = C_magenta"
| "rgb_colour (False,True,True) = C_cyan"
| "rgb_colour (True,False,False) = C_red"
| "rgb_colour (False,True,False) = C_green"
| "rgb_colour (False,False,True) = C_blue"
| "rgb_colour (False,False,False) = C_black"

fun bit_channels :: "rgb_bits \<Rightarrow> rgb_channel set" where
  "bit_channels (r,g,b) = (if r then {RedChannel} else {}) \<union>
      (if g then {GreenChannel} else {}) \<union> (if b then {BlueChannel} else {})"

definition rgb_channels :: "colour \<Rightarrow> rgb_channel set" where
  "rgb_channels c = bit_channels (rgb_mask c)"

definition mix_rgb_many :: "colour list \<Rightarrow> colour option" where
  "mix_rgb_many cs = (if cs \<noteq> [] \<and> list_all rgb_supported cs
     then Some (rgb_colour (fold_rgb cs)) else None)"

lemma union_rgb_channels:
  "bit_channels (union_rgb x y) = bit_channels x \<union> bit_channels y"
proof -
  obtain r g b where x: "x = (r,g,b)" by (cases x) auto
  obtain r' g' b' where y: "y = (r',g',b')" by (cases y) auto
  show ?thesis unfolding x y by auto
qed

lemma rgb_colour_channels:
  "rgb_channels (rgb_colour x) = bit_channels x"
proof -
  obtain r g b where x: "x = (r,g,b)" by (cases x) auto
  show ?thesis unfolding x by (cases r; cases g; cases b) (simp_all add: rgb_channels_def)
qed

lemma fold_rgb_channels:
  "bit_channels (fold_rgb cs) = \<Union> (rgb_channels ` set cs)"
  by (induction cs) (auto simp: union_rgb_channels rgb_channels_def)

lemma mix_rgb_many_channels:
  assumes "mix_rgb_many cs = Some c"
  shows "cs \<noteq> [] \<and> list_all rgb_supported cs \<and>
         rgb_channels c = \<Union> (rgb_channels ` set cs)"
  using assms by (auto simp: mix_rgb_many_def rgb_colour_channels fold_rgb_channels split: if_splits)

lemma rgb_pair_preserved:
  assumes "mix_rgb a b = Some c"
  shows "mix_rgb_many [a,b] = Some c"
  using assms by (cases a; cases b) (simp_all add: mix_rgb_def mix_rgb_many_def rgb_supported_def)

fun comp_of :: "colour \<Rightarrow> colour" where
  "comp_of C_red = C_green"
| "comp_of C_green = C_red"
| "comp_of C_blue = C_orange"
| "comp_of C_orange = C_blue"
| "comp_of C_yellow = C_purple"
| "comp_of C_purple = C_yellow"
| "comp_of C_violet = C_yellow"
| "comp_of c = c"

section \<open>Laws of the colour and lumber tables\<close>

text \<open>Mixing two paints does not depend on which was named first, in both
the painter's (RYB) and the light (RGB) models.\<close>
theorem mix_symmetric: "mix_ryb a b = mix_ryb b a \<and> mix_rgb a b = mix_rgb b a"
  by (cases a; cases b) (simp_all add: mix_ryb_def mix_rgb_def)

text \<open>The complement table is an involution on every colour except violet.
Violet is the organ's own asymmetry: its complement is yellow, but yellow's is
purple, so two steps land on purple, not back on violet. The kernel keeps the
organ's table; the two statements say exactly where the law holds and where it
does not.\<close>
theorem complement_involution:
  "x \<noteq> C_violet \<Longrightarrow> comp_of (comp_of x) = x"
  by (cases x) simp_all

theorem complement_violet_exception:
  "comp_of (comp_of C_violet) = C_purple \<and> C_purple \<noteq> C_violet"
  by simp

text \<open>A dressed board is smaller than its nominal size and has a positive
size: the table never claims a board larger than its name.\<close>
theorem actual_below_nominal:
  "actual n = Some x \<Longrightarrow> 0 < x \<and> x < of_nat n"
  by (auto simp: actual_def actual_tab_def split: if_splits)


datatype cunit = CU_in | CU_quote | CU_cm | CU_mm

fun cunit_label :: "cunit \<Rightarrow> String.literal" where
  "cunit_label CU_in = STR ''in''"
| "cunit_label CU_quote = String.implode [CHR 0x22]"
| "cunit_label CU_cm = STR ''cm''"
| "cunit_label CU_mm = STR ''mm''"

datatype price = Per_kg rat | Per_spool rat "(rat \<times> bool) option"
datatype ladder_unit = L_ft | L_m

text \<open>Exact constants of the organs: the IBC egress widths per occupant
(stairways 0.3 in, other components 0.2 in), the 1e-9 slack on every
round-up and round-down, the IRC maximum riser (7 3/4 in), 2.54 cm per inch.\<close>
definition egress_per :: "bool \<Rightarrow> rat" where
  "egress_per stair = (if stair then 3 / 10 else 1 / 5)"

definition max_riser :: rat where "max_riser = 31 / 4"
definition cm_per_inch :: rat where "cm_per_inch = 127 / 50"

section \<open>Requests, outcomes and declines\<close>

datatype length_unit = BU_in | BU_ft | BU_cm | BU_mm | BU_m | BU_yd

fun length_inches :: "length_unit \<Rightarrow> rat \<Rightarrow> rat" where
  "length_inches BU_in x = x"
| "length_inches BU_ft x = 12*x"
| "length_inches BU_cm x = 50*x/127"
| "length_inches BU_mm x = 5*x/127"
| "length_inches BU_m x = 5000*x/127"
| "length_inches BU_yd x = 36*x"

definition board_domain :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> bool" where
  "board_domain t w l k \<longleftrightarrow> 0 \<le> t \<and> 0 \<le> w \<and> 0 \<le> l \<and>
    0 \<le> k \<and> snd (quotient_of k) = 1"

lemma length_inches_nonnegative:
  "0 \<le> x \<Longrightarrow> 0 \<le> length_inches u x"
  by (cases u) auto

datatype request =
    Far rat rat                       (* floor area, lot area (sq ft) *)
  | MaxFloor rat rat                  (* FAR, lot area *)
  | Coverage rat rat                  (* footprint, lot area *)
  | Occupant rat load_src             (* area, load factor *)
  | Egress rat load_src bool          (* area, load factor, stairway? *)
  | Ramp rat bool                     (* rise, given in feet? *)
  | Shrink "rat option"               (* shrinkage in percent *)
  | Layers "(rat * length_unit) option" "(rat * length_unit) option"  (* part height, layer height *)
  | Flow "rat option" "rat option" "rat option"  (* layer height, line width, speed *)
  | Cost rat price                    (* grams *)
  | FilLength rat "rat option" dens_src   (* grams, filament diameter mm *)
  | FilMass rat "rat option" dens_src     (* metres, filament diameter mm *)
  | NoiseTime rat                     (* dBA *)
  | NoiseDose "rat list" "rat list"   (* levels, hours *)
  | Twa "rat list" "rat list"
  | Ladder "rat option" ladder_unit
  | Niosh "rat option" "rat option" "rat option" "rat option" "rat option" "rat option" bool "rat option"
      (* H V D A FM CM and the load (kg) when a lifting index is asked *)
  | Judge
  | ActualSize nat nat
  | BoardFeet rat length_unit rat length_unit rat length_unit rat (* thickness/unit, width/unit, length/unit, integral piece count *)
  | BoardUnread
  | Concrete rat rat rat bool         (* length ft, width ft, depth, depth in inches? *)
  | Drywall rat rat sheet             (* area, openings *)
  | Stairs rat bool bool              (* rise, in feet?, asks the riser height *)
  | Rafter rat rat bool               (* pitch X in 12, run, run in feet? *)
  | Pitch rat
  | Miter nat
  | Moisture rat rat                  (* wet, oven-dry *)
  | MixRyb colour colour
  | MixRgb "colour list"
  | Complement colour
  | Rows rat rat bool rat bool        (* gauge rows, gauge span, inches?, target length, inches? *)
  | CastOn rat bool rat bool          (* stitches per unit, per inch?, width, in inches? *)
  | Quilt rat rat rat                 (* width, length, block size *)
  | CutSize rat
  | Yards rat length_unit
  | YardsUnread
  | Mat rat rat rat                   (* artwork w, h, border *)
  | Clay rat rat cunit                (* shrinkage percent, wet size, unit *)

datatype need = N_shrink | N_height_layer | N_flow_inputs | N_spool_weight | N_filament_diameter
  | N_fabric_length | N_board_inputs | N_rgb_model | N_material | N_noise_times | N_ladder_length | N_niosh_geometry | N_niosh_multipliers | N_niosh_load

datatype reason = R_lot_nonpositive | R_factor_nonpositive | R_shrink_range | R_layer_nonpositive
  | R_negative_length | R_board_domain | R_gauge_dimensions | R_spool_nonpositive | R_diameter_nonpositive | R_density_nonpositive | R_negative_duration
  | R_zero_dose | R_niosh_domain | R_zero_rwl | R_nominal_size | R_openings_exceed | R_rise_nonpositive
  | R_few_sides | R_dry_exceeds_wet | R_no_mix | R_block_nonpositive

datatype decline = Underspecified need | Judgement | Impossible reason | Imprecise

datatype kind = K_far | K_max_floor | K_coverage | K_occupant | K_egress | K_ramp
  | K_shrink | K_layers | K_flow | K_cost | K_length | K_mass
  | K_noise_time | K_noise_dose | K_twa | K_ladder | K_rwl | K_li
  | K_actual_size | K_board_feet | K_concrete | K_drywall | K_risers | K_riser_height
  | K_rafter | K_pitch | K_miter | K_wood_mc
  | K_mix_ryb | K_mix_rgb | K_complement | K_rows | K_cast_on | K_quilt | K_cut_size | K_yards
  | K_mat_outer | K_clay_fired

text \<open>An exact rational value, a pair of them, a colour, a decimal
@{text "(m, e)"} meaning @{text "m * 10^e"} enclosing a real value, or a
decline.\<close>
datatype outcome = Exact kind rat | Duo kind rat rat | Hue kind colour | Approx kind "int \<times> int"
  | Decline decline

fun kind_of :: "request \<Rightarrow> kind" where
  "kind_of (Far _ _) = K_far"
| "kind_of (MaxFloor _ _) = K_max_floor"
| "kind_of (Coverage _ _) = K_coverage"
| "kind_of (Occupant _ _) = K_occupant"
| "kind_of (Egress _ _ _) = K_egress"
| "kind_of (Ramp _ _) = K_ramp"
| "kind_of (Shrink _) = K_shrink"
| "kind_of (Layers _ _) = K_layers"
| "kind_of (Flow _ _ _) = K_flow"
| "kind_of (Cost _ _) = K_cost"
| "kind_of (FilLength _ _ _) = K_length"
| "kind_of (FilMass _ _ _) = K_mass"
| "kind_of (NoiseTime _) = K_noise_time"
| "kind_of (NoiseDose _ _) = K_noise_dose"
| "kind_of (Twa _ _) = K_twa"
| "kind_of (Ladder _ _) = K_ladder"
| "kind_of (Niosh _ _ _ _ _ _ want_li _) = (if want_li then K_li else K_rwl)"
| "kind_of Judge = K_rwl"
| "kind_of (ActualSize _ _) = K_actual_size"
| "kind_of BoardUnread = K_board_feet"
| "kind_of (BoardFeet _ _ _ _ _ _ _) = K_board_feet"
| "kind_of (Concrete _ _ _ _) = K_concrete"
| "kind_of (Drywall _ _ _) = K_drywall"
| "kind_of (Stairs _ _ h) = (if h then K_riser_height else K_risers)"
| "kind_of (Rafter _ _ _) = K_rafter"
| "kind_of (Pitch _) = K_pitch"
| "kind_of (Miter _) = K_miter"
| "kind_of (Moisture _ _) = K_wood_mc"
| "kind_of (MixRyb _ _) = K_mix_ryb"
| "kind_of (MixRgb _) = K_mix_rgb"
| "kind_of (Complement _) = K_complement"
| "kind_of (Rows _ _ _ _ _) = K_rows"
| "kind_of (CastOn _ _ _ _) = K_cast_on"
| "kind_of (Quilt _ _ _) = K_quilt"
| "kind_of (CutSize _) = K_cut_size"
| "kind_of (Yards _ _) = K_yards"
| "kind_of YardsUnread = K_yards"
| "kind_of (Mat _ _ _) = K_mat_outer"
| "kind_of (Clay _ _ _) = K_clay_fired"

section \<open>Values the organs compute\<close>

text \<open>Exact rational covering and fitting counts. No floating-point slack
is needed because all input decimals are interpreted as exact fractions.\<close>
definition ceil_rat :: "rat \<Rightarrow> rat" where "ceil_rat x = of_int \<lceil>x\<rceil>"
definition floor_rat :: "rat \<Rightarrow> rat" where "floor_rat x = of_int \<lfloor>x\<rfloor>"

text \<open>@{text "least_cover x n"}: @{text n} is the smallest whole number not
below @{text "x"}. @{text "most_fit x n"}: the largest not above
@{text "x"}.\<close>
definition least_cover :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "least_cover x n \<longleftrightarrow> (\<exists>z::int. n = of_int z) \<and> x \<le> n \<and> n < x + 1"

definition most_fit :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "most_fit x n \<longleftrightarrow> (\<exists>z::int. n = of_int z) \<and> n \<le> x \<and> x < n + 1"

lemma ceil_rat_cover: "least_cover x (ceil_rat x)"
proof -
  have c: "of_int \<lceil>x\<rceil> - 1 < x \<and> x \<le> (of_int \<lceil>x\<rceil> :: rat)"
    by (rule ceiling_correct)
  show ?thesis unfolding least_cover_def ceil_rat_def
  proof (intro conjI)
    show "\<exists>z::int. (of_int \<lceil>x\<rceil> :: rat) = of_int z" by blast
    show "x \<le> (of_int \<lceil>x\<rceil> :: rat)" using c by linarith
    show "(of_int \<lceil>x\<rceil> :: rat) < x + 1" using c by linarith
  qed
qed

lemma floor_rat_fit: "most_fit x (floor_rat x)"
proof -
  have c: "(of_int \<lfloor>x\<rfloor> :: rat) \<le> x \<and> x < of_int \<lfloor>x\<rfloor> + 1"
    using floor_correct[of "x"] by simp
  show ?thesis unfolding most_fit_def floor_rat_def
  proof (intro conjI)
    show "\<exists>z::int. (of_int \<lfloor>x\<rfloor> :: rat) = of_int z" by blast
    show "(of_int \<lfloor>x\<rfloor> :: rat) \<le> x" using c by linarith
    show "x < (of_int \<lfloor>x\<rfloor> :: rat) + 1" using c by linarith
  qed
qed

text \<open>Python's @{text "round()"} of an exact value: to the nearest whole
number, an exact tie to the even one.\<close>
definition round_he :: "rat \<Rightarrow> rat" where
  "round_he x = of_int (if x - of_int \<lfloor>x\<rfloor> < 1 / 2 then \<lfloor>x\<rfloor>
     else if 1 / 2 < x - of_int \<lfloor>x\<rfloor> then \<lfloor>x\<rfloor> + 1
     else if even \<lfloor>x\<rfloor> then \<lfloor>x\<rfloor> else \<lfloor>x\<rfloor> + 1)"

definition spec_he :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "spec_he x n \<longleftrightarrow> (\<exists>z::int. n = of_int z \<and> \<bar>x - n\<bar> \<le> 1 / 2 \<and> (\<bar>x - n\<bar> = 1 / 2 \<longrightarrow> even z))"

theorem round_he_spec: "spec_he x (round_he x)"
proof -
  obtain f where f: "f = \<lfloor>x\<rfloor>" by blast
  have b1: "(of_int f :: rat) \<le> x" and b2: "x < of_int f + 1"
    using floor_correct[of x] f by simp_all
  have r: "round_he x = of_int (if x - of_int f < 1 / 2 then f
     else if 1 / 2 < x - of_int f then f + 1 else if even f then f else f + 1)"
    by (simp add: round_he_def f)
  show ?thesis
  proof (cases "x - of_int f < 1 / 2")
    case True
    have a: "\<bar>x - of_int f\<bar> = x - of_int f" by (rule abs_of_nonneg) (use b1 in linarith)
    show ?thesis unfolding spec_he_def r
      using True a by (intro exI[of _ f]) auto
  next
    case F1: False
    show ?thesis
    proof (cases "1 / 2 < x - of_int f")
      case True
      have a: "\<bar>x - of_int (f + 1)\<bar> = of_int f + 1 - x"
        by (simp add: abs_of_nonpos) (use b2 in linarith)
      show ?thesis unfolding spec_he_def r
        using F1 True a b2 by (intro exI[of _ "f + 1"]) auto
    next
      case F2: False
      have t: "x - of_int f = 1 / 2" using F1 F2 by linarith
      show ?thesis
      proof (cases "even f")
        case True
        have a: "\<bar>x - of_int f\<bar> = 1 / 2" using t by simp
        show ?thesis unfolding spec_he_def r
          using F1 F2 True a by (intro exI[of _ f]) auto
      next
        case False
        have a: "\<bar>x - of_int (f + 1)\<bar> = 1 / 2" using t by (simp add: abs_if)
        have ev: "even (f + 1)" using False by simp
        show ?thesis unfolding spec_he_def r
          using F1 F2 False a ev by (intro exI[of _ "f + 1"]) auto
      qed
    qed
  qed
qed

definition ramp_rise_in :: "rat \<Rightarrow> bool \<Rightarrow> rat" where
  "ramp_rise_in r ft = r * (if ft then 12 else 1)"

fun per_kg :: "price \<Rightarrow> rat" where
  "per_kg (Per_kg p) = p"
| "per_kg (Per_spool p w) = (case w of None \<Rightarrow> 0 | Some (x, kg) \<Rightarrow> p / (x / (if kg then 1 else 1000)))"

definition cast_width :: "bool \<Rightarrow> rat \<Rightarrow> bool \<Rightarrow> rat" where
  "cast_width u_in w w_in = (if u_in = w_in then w else if u_in then w / cm_per_inch else w * cm_per_inch)"

text \<open>NIOSH 1994 (metric) multipliers: horizontal, vertical, distance, asymmetry; below 25 cm
the horizontal and distance reads as 25.\<close>
definition hm :: "rat \<Rightarrow> rat" where "hm h = min 1 (25 / max h 25)"
definition vm :: "rat \<Rightarrow> rat" where "vm v = max 0 (1 - 3 / 1000 * \<bar>v - 75\<bar>)"
definition dm :: "rat \<Rightarrow> rat" where "dm d = min 1 (82 / 100 + 45 / 10 / max d 25)"
definition am :: "rat \<Rightarrow> rat" where "am a = max 0 (1 - 32 / 10000 * a)"
definition rwl_of :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "rwl_of h v d a fm cm = 23 * hm h * vm v * dm d * am a * fm * cm"

definition niosh_domain :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> bool \<Rightarrow> rat option \<Rightarrow> bool" where
  "niosh_domain h v d a fm cm want_li ld =
    (0 \<le> h \<and> 0 \<le> v \<and> 0 \<le> d \<and> 0 \<le> a \<and> 0 \<le> fm \<and> fm \<le> 1
      \<and> cm \<in> {9/10, 19/20, 1} \<and> (want_li \<longrightarrow> 0 \<le> the ld))"

definition rise_in :: "rat \<Rightarrow> bool \<Rightarrow> rat" where
  "rise_in r ft = r * (if ft then 12 else 1)"

section \<open>Declines\<close>

text \<open>Underspecified: an input the formula needs is absent (the organs' need branches).\<close>
fun missing :: "request \<Rightarrow> need option" where
  "missing (Shrink p) = (if p = None then Some N_shrink else None)"
| "missing (Layers h l) = (if h = None \<or> l = None then Some N_height_layer else None)"
| "missing (Flow a b c) = (if a = None \<or> b = None \<or> c = None then Some N_flow_inputs else None)"
| "missing (Cost g p) = (case p of Per_spool _ None \<Rightarrow> Some N_spool_weight | _ \<Rightarrow> None)"
| "missing (FilLength m d s) = (if d = None then Some N_filament_diameter
     else if s = D_none then Some N_material else None)"
| "missing (FilMass m d s) = (if d = None then Some N_filament_diameter
     else if s = D_none then Some N_material else None)"
| "missing (NoiseDose ls cs) = (if length ls \<noteq> length cs then Some N_noise_times else None)"
| "missing (Twa ls cs) = (if length ls \<noteq> length cs then Some N_noise_times else None)"
| "missing (Ladder l u) = (if l = None then Some N_ladder_length else None)"
| "missing (Niosh h v d a fm cm want_li ld) =
     (if h = None \<or> v = None \<or> d = None \<or> a = None then Some N_niosh_geometry
      else if fm = None \<or> cm = None then Some N_niosh_multipliers
      else if want_li \<and> ld = None then Some N_niosh_load else None)"
| "missing (MixRgb cs) = (if mix_rgb_many cs = None then Some N_rgb_model else None)"
| "missing YardsUnread = Some N_fabric_length"
| "missing BoardUnread = Some N_board_inputs"
| "missing _ = None"

text \<open>Impossible: the inputs are all there and cannot be computed with (a division by
zero, a shrinkage of 100 percent or more, a frame with fewer than 3 sides, a dry mass above the
wet mass, a nominal size outside the lumber table, a colour pair the wheel does not mix).
The options are read with @{const the}: this is only asked of fully specified requests.\<close>
fun impossible :: "request \<Rightarrow> bool" where
  "impossible (Far _ lot) = (lot \<le> 0)"
| "impossible (Coverage _ lot) = (lot \<le> 0)"
| "impossible (Occupant _ s) = (load_factor s \<le> 0)"
| "impossible (Egress _ s _) = (load_factor s \<le> 0)"
| "impossible (Shrink p) = (the p < 0 \<or> 100 \<le> the p)"
| "impossible (Layers h l) = (length_inches (snd (the l)) (fst (the l)) \<le> 0 \<or> length_inches (snd (the h)) (fst (the h)) < 0)"
| "impossible (Yards x _) = (x < 0)"
| "impossible (Cost _ p) = (case p of Per_spool _ (Some (x, _)) \<Rightarrow> x \<le> 0 | _ \<Rightarrow> False)"
| "impossible (FilLength _ d s) = (the d \<le> 0 \<or> dens s \<le> 0)"
| "impossible (FilMass _ d _) = (the d \<le> 0)"
| "impossible (NoiseDose _ cs) = (\<exists>c\<in>set cs. c < 0)"
| "impossible (Twa _ cs) = ((\<exists>c\<in>set cs. c < 0) \<or> (\<forall>c\<in>set cs. c = 0))"
| "impossible (Niosh h v d a fm cm want_li ld) =
     (\<not> niosh_domain (the h) (the v) (the d) (the a) (the fm) (the cm) want_li ld
      \<or> (want_li \<and> rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm) \<le> 0))"
| "impossible (BoardFeet t tu w wu l lu k) = (\<not> board_domain t w l k)"
| "impossible (ActualSize a b) = (actual a = None \<or> actual b = None)"
| "impossible (Drywall a ov _) = (a \<le> ov)"
| "impossible (Stairs r ft _) = (rise_in r ft / max_riser \<le> 0)"
| "impossible (Miter n) = (n < 3)"
| "impossible (Moisture w d) = (d \<le> 0 \<or> w < d)"
| "impossible (MixRyb a b) = (mix_ryb a b = None)"
| "impossible (MixRgb cs) = False"
| "impossible (Rows row_count gauge_span _ target_len _) = (row_count < 0 \<or> gauge_span \<le> 0 \<or> target_len < 0)"
| "impossible (Quilt _ _ s) = (s \<le> 0)"
| "impossible _ = False"

fun reason_of :: "request \<Rightarrow> reason option" where
  "reason_of (Far _ lot) = (if lot \<le> 0 then Some R_lot_nonpositive else None)"
| "reason_of (Coverage _ lot) = (if lot \<le> 0 then Some R_lot_nonpositive else None)"
| "reason_of (Occupant _ s) = (if load_factor s \<le> 0 then Some R_factor_nonpositive else None)"
| "reason_of (Egress _ s _) = (if load_factor s \<le> 0 then Some R_factor_nonpositive else None)"
| "reason_of (Shrink p) = (if the p < 0 \<or> 100 \<le> the p then Some R_shrink_range else None)"
| "reason_of (Layers h l) = (if length_inches (snd (the l)) (fst (the l)) \<le> 0 \<or> length_inches (snd (the h)) (fst (the h)) < 0 then Some R_layer_nonpositive else None)"
| "reason_of (Yards x _) = (if x < 0 then Some R_negative_length else None)"
| "reason_of (Cost _ p) = (case p of Per_spool _ (Some (x, _)) \<Rightarrow>
     (if x \<le> 0 then Some R_spool_nonpositive else None) | _ \<Rightarrow> None)"
| "reason_of (FilLength _ d s) = (if the d \<le> 0 then Some R_diameter_nonpositive
     else if dens s \<le> 0 then Some R_density_nonpositive else None)"
| "reason_of (FilMass _ d _) = (if the d \<le> 0 then Some R_diameter_nonpositive else None)"
| "reason_of (NoiseDose _ cs) = (if list_ex (\<lambda>c. c < 0) cs then Some R_negative_duration else None)"
| "reason_of (Twa _ cs) = (if list_ex (\<lambda>c. c < 0) cs then Some R_negative_duration
     else if list_all (\<lambda>c. c = 0) cs then Some R_zero_dose else None)"
| "reason_of (Niosh h v d a fm cm want_li ld) =
     (if \<not> niosh_domain (the h) (the v) (the d) (the a) (the fm) (the cm) want_li ld
      then Some R_niosh_domain
      else if want_li \<and> rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm) \<le> 0
      then Some R_zero_rwl else None)"
| "reason_of (BoardFeet t tu w wu l lu k) = (if board_domain t w l k then None else Some R_board_domain)"
| "reason_of (ActualSize a b) = (if actual a = None \<or> actual b = None then Some R_nominal_size else None)"
| "reason_of (Drywall a ov _) = (if a \<le> ov then Some R_openings_exceed else None)"
| "reason_of (Stairs r ft _) = (if rise_in r ft / max_riser \<le> 0 then Some R_rise_nonpositive else None)"
| "reason_of (Miter n) = (if n < 3 then Some R_few_sides else None)"
| "reason_of (Moisture w d) = (if d \<le> 0 \<or> w < d then Some R_dry_exceeds_wet else None)"
| "reason_of (MixRyb a b) = (if mix_ryb a b = None then Some R_no_mix else None)"
| "reason_of (MixRgb cs) = None"
| "reason_of (Rows row_count gauge_span _ target_len _) = (if row_count < 0 \<or> gauge_span \<le> 0 \<or> target_len < 0 then Some R_gauge_dimensions else None)"
| "reason_of (Quilt _ _ s) = (if s \<le> 0 then Some R_block_nonpositive else None)"
| "reason_of _ = None"

theorem reason_of_exact: "reason_of r \<noteq> None \<longleftrightarrow> impossible r"
  by (cases r) (auto simp: list_all_iff list_ex_iff split: if_splits option.splits price.splits prod.splits)

fun is_judge :: "request \<Rightarrow> bool" where
  "is_judge Judge = True"
| "is_judge _ = False"

definition decline_of :: "request \<Rightarrow> decline option" where
  "decline_of r = (case missing r of Some n \<Rightarrow> Some (Underspecified n) | None \<Rightarrow>
     (case reason_of r of Some y \<Rightarrow> Some (Impossible y)
      | None \<Rightarrow> if is_judge r then Some Judgement else None))"

section \<open>The enclosed quantities\<close>

fun dose_real :: "rat list \<Rightarrow> rat list \<Rightarrow> real" where
  "dose_real (l # ls) (c # cs) = rl c / (8 / (2 powr ((rl l - 90) / 5))) + dose_real ls cs"
| "dose_real _ _ = 0"

fun dose_fa :: "rat list \<Rightarrow> rat list \<Rightarrow> floatarith" where
  "dose_fa (l # ls) (c # cs) = floatarith.Add
     (Dv (Q c) (Dv (I 8) (floatarith.Powr (I 2) (Dv (Sb (Q l) (I 90)) (I 5))))) (dose_fa ls cs)"
| "dose_fa _ _ = I 0"

lemma interp_dose [simp]: "interpret_floatarith (dose_fa ls cs) xs = dose_real ls cs"
proof (induction ls arbitrary: cs)
  case Nil
  then show ?case by (cases cs) simp_all
next
  case (Cons l ls)
  show ?case
  proof (cases "cs = []")
    case True
    then show ?thesis by simp
  next
    case False
    then obtain c cs' where cs: "cs = c # cs'" by (cases cs) auto
    have "interpret_floatarith (dose_fa ls cs') xs = dose_real ls cs'" by (rule Cons.IH)
    have e: "interpret_floatarith (dose_fa (l # ls) (c # cs')) xs
        = rl c / (8 / (2 powr ((rl l - 90) / 5))) + interpret_floatarith (dose_fa ls cs') xs"
      by (simp only: dose_fa.simps interpret_floatarith.simps interp_Dv interp_Q interp_Sb interp_I of_int_numeral)
    show ?thesis using cs e \<open>interpret_floatarith (dose_fa ls cs') xs = dose_real ls cs'\<close>
      by (simp only: dose_real.simps)
  qed
qed

lemma dose_real_nonneg: "list_all (\<lambda>c. 0 \<le> c) cs \<Longrightarrow> 0 \<le> dose_real ls cs"
proof (induction ls arbitrary: cs)
  case Nil
  then show ?case by (cases cs) simp_all
next
  case (Cons l ls)
  show ?case
  proof (cases "cs = []")
    case True
    then show ?thesis by simp
  next
    case False
    then obtain c cs' where cs: "cs = c # cs'" by (cases cs) auto
    have all: "0 \<le> c" "list_all (\<lambda>c. 0 \<le> c) cs'" using Cons.prems cs by simp_all
    have rest: "0 \<le> dose_real ls cs'" by (rule Cons.IH[OF all(2)])
    have c0: "0 \<le> rl c" using all(1) by simp
    have p: "0 < (8::real) / (2 powr ((rl l - 90) / 5))" by simp
    have "0 \<le> rl c / (8 / (2 powr ((rl l - 90) / 5)))" using c0 p by (simp add: zero_le_divide_iff)
    then show ?thesis using rest cs by simp
  qed
qed

text \<open>The real-number model of each enclosed quantity.\<close>
fun phys :: "request \<Rightarrow> real" where
  "phys (FilLength m d s) = rl m / (rl (dens s) * (pi * (rl (the d) / 20) ^ 2)) / 100"
| "phys (FilMass l d s) = rl (dens s) * (pi * (rl (the d) / 20) ^ 2) * (rl l * 100)"
| "phys (NoiseTime l) = 8 / (2 powr ((rl l - 90) / 5))"
| "phys (NoiseDose ls cs) = 100 * dose_real ls cs"
| "phys (Twa ls cs) = rl (1661 / 100) * log 10 ((100 * dose_real ls cs) / 100) + 90"
| "phys (Rafter x rv _) = rl rv * sqrt (1 + (rl x / 12) ^ 2)"
| "phys (Pitch x) = 180 / pi * arctan (rl x / 12)"
| "phys _ = 0"

fun expr_of :: "request \<Rightarrow> floatarith" where
  "expr_of (FilLength m d s) = Dv (Dv (Q m) (floatarith.Mult (Q (dens s))
     (floatarith.Mult floatarith.Pi (floatarith.Power (Dv (Q (the d)) (I 20)) 2)))) (I 100)"
| "expr_of (FilMass l d s) = floatarith.Mult (floatarith.Mult (Q (dens s))
     (floatarith.Mult floatarith.Pi (floatarith.Power (Dv (Q (the d)) (I 20)) 2)))
     (floatarith.Mult (Q l) (I 100))"
| "expr_of (NoiseTime l) = Dv (I 8) (floatarith.Powr (I 2) (Dv (Sb (Q l) (I 90)) (I 5)))"
| "expr_of (NoiseDose ls cs) = floatarith.Mult (I 100) (dose_fa ls cs)"
| "expr_of (Twa ls cs) = floatarith.Add (floatarith.Mult (Q (1661 / 100))
     (Lg (Dv (floatarith.Mult (I 100) (dose_fa ls cs)) (I 100)))) (I 90)"
| "expr_of (Rafter x rv _) = floatarith.Mult (Q rv)
     (floatarith.Sqrt (floatarith.Add (I 1) (floatarith.Power (Dv (Q x) (I 12)) 2)))"
| "expr_of (Pitch x) = floatarith.Mult (Dv (I 180) floatarith.Pi) (floatarith.Arctan (Dv (Q x) (I 12)))"
| "expr_of _ = I 0"

lemma meaning_non_twa:
  "(\<forall>ls cs. r \<noteq> Twa ls cs) \<Longrightarrow> interpret_floatarith (expr_of r) [] = phys r"
  by (cases r) simp_all

lemma meaning_twa:
  assumes "list_all (\<lambda>c. 0 \<le> c) cs"
  shows "interpret_floatarith (expr_of (Twa ls cs)) [] = phys (Twa ls cs)"
proof -
  have n: "0 \<le> dose_real ls cs" using assms by (rule dose_real_nonneg)
  have "0 \<le> (100 * dose_real ls cs) / 100" using n by simp
  then show ?thesis by (simp add: n)
qed

text \<open>No durations below zero: a stated duration is read from digits.\<close>
lemma nonneg_from_not_impossible:
  assumes "\<not> impossible (Twa ls cs)"
  shows "list_all (\<lambda>c. 0 \<le> c) cs"
  using assms by (auto simp: list_all_iff not_less)

theorem expr_of_meaning:
  assumes "\<not> impossible r"
  shows "interpret_floatarith (expr_of r) [] = phys r"
proof (cases "\<exists>ls cs. r = Twa ls cs")
  case True
  then obtain ls cs where r: "r = Twa ls cs" by blast
  have "\<not> impossible (Twa ls cs)" using assms r by simp
  then show ?thesis using meaning_twa nonneg_from_not_impossible r by blast
next
  case False
  then have "\<forall>ls cs. r \<noteq> Twa ls cs" by blast
  then show ?thesis by (rule meaning_non_twa)
qed

fun mode_of :: "kind \<Rightarrow> amode" where
  "mode_of K_length = Sig4C"
| "mode_of K_mass = Sig4C"
| "mode_of K_rafter = Fix3"
| "mode_of K_pitch = Fix3"
| "mode_of _ = Sig4"

definition approx_out :: "kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out k e = (case enclose_m (mode_of k) prec e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out c e = Approx k d"
  shows "k = c \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000"
  using assms enclose_m_sound by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decline: "approx_out c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_exact [simp]: "approx_out c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_duo [simp]: "approx_out c e \<noteq> Duo k p q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_hue [simp]: "approx_out c e \<noteq> Hue k h"
  by (auto simp: approx_out_def split: option.splits)

section \<open>The kernel\<close>

fun answer_of :: "request \<Rightarrow> outcome" where
  "answer_of (Far fa lot) = Exact K_far (fa / lot)"
| "answer_of (MaxFloor f lot) = Exact K_max_floor (f * lot)"
| "answer_of (Coverage fp lot) = Exact K_coverage (fp / lot * 100)"
| "answer_of (Occupant a s) = Exact K_occupant (ceil_rat (a / load_factor s))"
| "answer_of (Egress a s st) = Exact K_egress (ceil_rat (a / load_factor s) * egress_per st)"
| "answer_of (Ramp r ft) = Exact K_ramp (ramp_rise_in r ft * 12 / 12)"
| "answer_of (Shrink p) = Exact K_shrink (1 / (1 - the p / 100))"
| "answer_of (Layers h l) = Exact K_layers (ceil_rat (length_inches (snd (the h)) (fst (the h)) / length_inches (snd (the l)) (fst (the l))))"
| "answer_of (Flow a b c) = Exact K_flow (the a * the b * the c)"
| "answer_of (Cost g p) = Exact K_cost (g * per_kg p / 1000)"
| "answer_of (FilLength m d s) = approx_out K_length (expr_of (FilLength m d s))"
| "answer_of (FilMass l d s) = approx_out K_mass (expr_of (FilMass l d s))"
| "answer_of (NoiseTime l) = approx_out K_noise_time (expr_of (NoiseTime l))"
| "answer_of (NoiseDose ls cs) = approx_out K_noise_dose (expr_of (NoiseDose ls cs))"
| "answer_of (Twa ls cs) = approx_out K_twa (expr_of (Twa ls cs))"
| "answer_of (Ladder l u) = Exact K_ladder (the l / 4)"
| "answer_of (Niosh h v d a fm cm want_li ld) =
     (if want_li then Exact K_li (the ld / rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm))
      else Exact K_rwl (rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm)))"
| "answer_of (ActualSize a b) = (case (actual a, actual b) of
     (Some x, Some y) \<Rightarrow> Duo K_actual_size x y | _ \<Rightarrow> Decline Imprecise)"
| "answer_of (BoardFeet th tu w wu l lu k) =
     Exact K_board_feet (length_inches tu th * length_inches wu w * length_inches lu l * k / 144)"
| "answer_of (Concrete l w d inch) = Exact K_concrete (l * w * (if inch then d / 12 else d) / 27)"
| "answer_of (Drywall a ov s) = Exact K_drywall (ceil_rat ((a - ov) / sheet_area s))"
| "answer_of (Stairs r ft h) =
     (if h then Exact K_riser_height (rise_in r ft / ceil_rat (rise_in r ft / max_riser))
      else Exact K_risers (ceil_rat (rise_in r ft / max_riser)))"
| "answer_of (Rafter x rv ft) = approx_out K_rafter (expr_of (Rafter x rv ft))"
| "answer_of (Pitch x) = approx_out K_pitch (expr_of (Pitch x))"
| "answer_of (Miter n) = Exact K_miter (180 / of_nat n)"
| "answer_of (Moisture w d) = Exact K_wood_mc ((w - d) / d * 100)"
| "answer_of (MixRyb a b) = (case mix_ryb a b of Some c \<Rightarrow> Hue K_mix_ryb c | None \<Rightarrow> Decline Imprecise)"
| "answer_of (MixRgb cs) = (case mix_rgb_many cs of Some c \<Rightarrow> Hue K_mix_rgb c | None \<Rightarrow> Decline Imprecise)"
| "answer_of (Complement c) = Hue K_complement (comp_of c)"
| "answer_of (Rows row_count gauge_span u l li) = Exact K_rows (round_he (row_count / gauge_span * cast_width u l li))"
| "answer_of (CastOn spu u w wi) = Exact K_cast_on (round_he (spu * cast_width u w wi))"
| "answer_of (Quilt w l s) = Exact K_quilt (floor_rat (w / s) * floor_rat (l / s))"
| "answer_of (CutSize s) = Exact K_cut_size (s + 1 / 2)"
| "answer_of (Yards i u) = Exact K_yards (length_inches u i / 36)"
| "answer_of (Mat w h b) = Duo K_mat_outer (w + 2 * b) (h + 2 * b)"
| "answer_of (Clay p s u) = Exact K_clay_fired (s * (1 - p / 100))"
| "answer_of YardsUnread = Decline Imprecise"
| "answer_of BoardUnread = Decline Imprecise"
| "answer_of Judge = Decline Imprecise"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

lemma kernel_eq: "kernel r = (case missing r of Some n \<Rightarrow> Decline (Underspecified n)
    | None \<Rightarrow> (case reason_of r of Some y \<Rightarrow> Decline (Impossible y)
       | None \<Rightarrow> if is_judge r then Decline Judgement else answer_of r))"
  by (simp add: kernel_def decline_of_def split: option.splits if_splits)

lemma answer_decline: "answer_of r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r) (auto dest: approx_out_decline split: option.splits prod.splits if_splits)

lemma decline_none:
  assumes "kernel r = Exact k q \<or> kernel r = Duo k q q2 \<or> kernel r = Approx k d \<or> kernel r = Hue k c"
  shows "missing r = None \<and> reason_of r = None \<and> \<not> is_judge r \<and> answer_of r = kernel r"
  using assms by (auto simp: kernel_eq split: option.splits if_splits)

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified w) \<longleftrightarrow> missing r = Some w"
  by (auto dest: answer_decline simp: kernel_eq split: option.splits if_splits)

theorem kernel_impossible:
  "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> impossible r"
proof -
  have "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> reason_of r \<noteq> None"
    by (auto dest: answer_decline simp: kernel_eq split: option.splits if_splits)
  then show ?thesis using reason_of_exact[of r] by simp
qed

theorem kernel_judgement:
  "kernel r = Decline Judgement \<longleftrightarrow> missing r = None \<and> \<not> impossible r \<and> is_judge r"
proof -
  have "kernel r = Decline Judgement \<longleftrightarrow> missing r = None \<and> reason_of r = None \<and> is_judge r"
    by (auto dest: answer_decline simp: kernel_eq split: option.splits if_splits)
  then show ?thesis using reason_of_exact[of r] by auto
qed

theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None \<and> \<not> impossible r \<and> \<not> is_judge r"
proof -
  have "missing r = None \<and> reason_of r = None \<and> \<not> is_judge r"
    using assms by (auto simp: kernel_eq split: option.splits if_splits)
  then show ?thesis using reason_of_exact[of r] by auto
qed

section \<open>What each exact answer means\<close>

text \<open>The defining equation of each exact kind. The request's optional
fields are read with @{const the}; the kernel theorems below only apply to
requests with @{text "missing r = None"}, where every option is @{text Some}.\<close>
fun spec_exact :: "request \<Rightarrow> rat \<Rightarrow> bool" where
  "spec_exact (Far fa lot) q = (0 < lot \<and> q * lot = fa)"
| "spec_exact (MaxFloor f lot) q = (q = f * lot)"
| "spec_exact (Coverage fp lot) q = (0 < lot \<and> q * lot = 100 * fp)"
| "spec_exact (Occupant a s) q = (0 < load_factor s \<and> least_cover (a / load_factor s) q)"
| "spec_exact (Egress a s st) q =
     (0 < load_factor s \<and> least_cover (a / load_factor s) (q / egress_per st))"
| "spec_exact (Ramp r ft) q = (q * 12 = ramp_rise_in r ft * 12)"
| "spec_exact (Shrink p) q = (0 \<le> the p \<and> the p < 100 \<and> (1 - the p / 100) * q = 1)"
| "spec_exact (Layers h l) q = (0 < length_inches (snd (the l)) (fst (the l)) \<and> 0 \<le> length_inches (snd (the h)) (fst (the h)) \<and> least_cover (length_inches (snd (the h)) (fst (the h)) / length_inches (snd (the l)) (fst (the l))) q)"
| "spec_exact (Flow a b c) q = (q = the a * the b * the c)"
| "spec_exact (Cost g p) q = (q * 1000 = g * per_kg p)"
| "spec_exact (Ladder l u) q = (q * 4 = the l)"
| "spec_exact (Niosh h v d a fm cm want_li ld) q =
     (if want_li then 0 < rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm)
          \<and> q * rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm) = the ld
      else q = rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm))"
| "spec_exact (BoardFeet th tu w wu l lu k) q = (q * 144 = length_inches tu th * length_inches wu w * length_inches lu l * k)"
| "spec_exact (Concrete l w d inch) q = (q * 27 = l * w * (if inch then d / 12 else d))"
| "spec_exact (Drywall a ov s) q = least_cover ((a - ov) / sheet_area s) q"
| "spec_exact (Stairs r ft h) q =
     (if h then (\<exists>n. least_cover (rise_in r ft / max_riser) n \<and> n \<noteq> 0 \<and> q * n = rise_in r ft)
      else least_cover (rise_in r ft / max_riser) q)"
| "spec_exact (Miter n) q = (3 \<le> n \<and> q * of_nat n = 180)"
| "spec_exact (Moisture w d) q = (0 < d \<and> d \<le> w \<and> q * d = (w - d) * 100)"
| "spec_exact (Rows row_count gauge_span u l li) q = (0 \<le> row_count \<and> 0 < gauge_span \<and> 0 \<le> l \<and> spec_he (row_count / gauge_span * cast_width u l li) q)"
| "spec_exact (CastOn spu u w wi) q = spec_he (spu * cast_width u w wi) q"
| "spec_exact (Quilt w l s) q =
     (0 < s \<and> (\<exists>nw nl. most_fit (w / s) nw \<and> most_fit (l / s) nl \<and> q = nw * nl))"
| "spec_exact (CutSize s) q = (q - 1 / 2 = s)"
| "spec_exact (Yards i u) q = (0 \<le> i \<and> q * 36 = length_inches u i)"
| "spec_exact (Clay p s u) q = (q = s * (1 - p / 100))"
| "spec_exact _ q = False"

lemma egress_per_nz [simp]: "egress_per st \<noteq> 0"
  by (simp add: egress_per_def)

lemma max_riser_pos [simp]: "0 < max_riser"
  by (simp add: max_riser_def)

lemma answer_exact_spec:
  assumes A: "answer_of r = Exact k q" and B: "reason_of r = None"
  shows "k = kind_of r \<and> spec_exact r q"
proof (cases r)
  case (Far fa lot)
    have lp: "0 < lot" using B Far by (simp split: if_splits)
    then have ne: "lot \<noteq> 0" by simp
    show ?thesis using A Far lp by (auto simp: ne field_simps algebra_simps)
next
  case (MaxFloor x0 x1)
    show ?thesis using A MaxFloor by simp
next
  case (Coverage fp lot)
    have lp: "0 < lot" using B Coverage by (simp split: if_splits)
    then have ne: "lot \<noteq> 0" by simp
    show ?thesis using A Coverage lp by (auto simp: ne field_simps algebra_simps)
next
  case (Occupant x0 x1)
    have lp: "0 < load_factor x1" using B Occupant by (simp split: if_splits)
    show ?thesis using A lp Occupant ceil_rat_cover by auto
next
  case (Egress a s st)
    have lp: "0 < load_factor s" using B Egress by (simp split: if_splits)
    show ?thesis using A Egress lp ceil_rat_cover by auto
next
  case (Ramp x0 x1)
    show ?thesis using A Ramp by (simp add: field_simps algebra_simps)
next
  case (Shrink p)
    have lt: "0 \<le> the p" "the p < 100" using B Shrink by (auto split: if_splits)
    have pos: "0 < 1 - the p / 100" using lt by linarith
    have eq: "(1 - the p / 100) * (1 / (1 - the p / 100)) = 1" using pos by (simp add: field_simps)
    have kq: "k = K_shrink \<and> q = 1 / (1 - the p / 100)" using A Shrink by simp
    have K: "k = kind_of (Shrink p)" using kq by (simp only: kind_of.simps)
    have S: "spec_exact (Shrink p) q"
      unfolding spec_exact.simps
      by (rule conjI[OF lt(1) conjI[OF lt(2)]]) (simp only: kq[THEN conjunct2] eq)
    show ?thesis unfolding Shrink by (rule conjI[OF K S])
next
  case (Layers x0 x1)
    have lp: "0 < length_inches (snd (the x1)) (fst (the x1))" "0 \<le> length_inches (snd (the x0)) (fst (the x0))" using B Layers by (auto split: if_splits)
    show ?thesis using A lp Layers ceil_rat_cover by auto
next
  case (Flow x0 x1 x2)
    show ?thesis using A Flow by simp
next
  case (Cost x0 x1)
    show ?thesis using A Cost by (simp add: field_simps algebra_simps)
next
  case FilLength
    show ?thesis using A FilLength by simp
next
  case FilMass
    show ?thesis using A FilMass by simp
next
  case NoiseTime
    show ?thesis using A NoiseTime by simp
next
  case NoiseDose
    show ?thesis using A NoiseDose by simp
next
  case Twa
    show ?thesis using A Twa by simp
next
  case (Ladder x0 x1)
    show ?thesis using A Ladder by simp
next
  case (Niosh h v d a fm cm want_li ld)
    show ?thesis
    proof (cases want_li)
      case False
      then show ?thesis using A Niosh by simp
    next
      case True
      have rp: "0 < rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm)"
        using B Niosh True by (auto split: if_splits)
      show ?thesis using A Niosh True rp by (auto simp: field_simps algebra_simps)
    qed
next
  case Judge
    show ?thesis using A Judge by simp
next
  case ActualSize
    show ?thesis using A ActualSize by (simp split: option.splits)
next
  case BoardUnread
    show ?thesis using A BoardUnread by simp
next
  case (BoardFeet x0 x1 x2 x3 x4 x5 x6)
    show ?thesis using A BoardFeet by (simp add: field_simps algebra_simps)
next
  case (Concrete x0 x1 x2 x3)
    show ?thesis using A Concrete by (simp add: field_simps algebra_simps)
next
  case (Drywall x0 x1 x2)
    show ?thesis using A Drywall ceil_rat_cover by auto
next
  case (Stairs r ft h)
    define x where "x = rise_in r ft / max_riser"
    have gt: "0 < x" using B Stairs by (auto simp: x_def split: if_splits)
    have lc: "least_cover x (ceil_rat x)" by (rule ceil_rat_cover)
    have pos: "0 < ceil_rat x" using lc gt unfolding least_cover_def by linarith
    show ?thesis
    proof (cases h)
      case True
      have nz: "ceil_rat x \<noteq> 0" using pos by simp
      have kq: "k = K_riser_height \<and> q = rise_in r ft / ceil_rat x"
        using A Stairs True by (simp add: x_def)
      have "q * ceil_rat x = rise_in r ft" using kq nz by (simp add: field_simps algebra_simps)
      then have ex: "\<exists>n. least_cover x n \<and> n \<noteq> 0 \<and> q * n = rise_in r ft" using lc nz by blast
      show ?thesis using kq ex Stairs True by (simp add: x_def)
    next
      case False
      then show ?thesis using A Stairs lc by (auto simp: x_def[symmetric])
    qed
next
  case Rafter
    show ?thesis using A Rafter by simp
next
  case Pitch
    show ?thesis using A Pitch by simp
next
  case (Miter n)
    have n3: "3 \<le> n" using B Miter by (auto split: if_splits)
    then have nz: "(of_nat n :: rat) \<noteq> 0" by simp
    show ?thesis using A Miter n3 by (auto simp: nz field_simps algebra_simps)
next
  case (Moisture w d)
    have dp: "0 < d" "d \<le> w" using B Moisture by (auto split: if_splits)
    show ?thesis using A Moisture dp by (auto simp: field_simps algebra_simps)
next
  case MixRyb
    show ?thesis using A MixRyb by (simp split: option.splits)
next
  case MixRgb
    show ?thesis using A MixRgb by (simp split: option.splits)
next
  case Complement
    show ?thesis using A Complement by simp
next
  case (Rows row_count gauge_span u l li)
    show ?thesis using A B Rows round_he_spec by (auto split: if_splits)
next
  case (CastOn x0 x1 x2 x3)
    show ?thesis using A CastOn round_he_spec by auto
next
  case (Quilt w l s)
    have sp: "0 < s" using B Quilt by (simp split: if_splits)
    show ?thesis using A Quilt sp floor_rat_fit by auto
next
  case (CutSize x0)
    show ?thesis using A CutSize by simp
next
  case (Yards x0 x1)
    show ?thesis using A B Yards by (auto split: if_splits)
next
  case YardsUnread
    show ?thesis using A YardsUnread by simp
next
  case Mat
    show ?thesis using A Mat by simp
next
  case (Clay x0 x1 x2)
    show ?thesis using A Clay by simp
qed

theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and> spec_exact r q"
proof -
  have d: "missing r = None \<and> reason_of r = None \<and> \<not> is_judge r \<and> answer_of r = kernel r"
    by (rule decline_none) (use assms in blast)
  then have a: "answer_of r = Exact k q" using assms by simp
  show ?thesis using d answer_exact_spec[OF a] reason_of_exact[of r] by auto
qed

text \<open>These bounds validate the supplied arithmetic inputs. They do not
select a frequency/coupling table row or establish that a real lifting task
satisfies the applicability conditions of the NIOSH equation.\<close>
lemma unit_product:
  fixes x y :: rat
  assumes "0 \<le> x" "x \<le> 1" "0 \<le> y" "y \<le> 1"
  shows "0 \<le> x * y \<and> x * y \<le> 1"
  using assms mult_nonneg_nonneg mult_le_one by blast

lemma niosh_factors_bounded:
  assumes "0 \<le> angle"
  shows "0 \<le> hm h \<and> hm h \<le> 1 \<and> 0 \<le> vm v \<and> vm v \<le> 1
    \<and> 0 \<le> dm d \<and> dm d \<le> 1 \<and> 0 \<le> am angle \<and> am angle \<le> 1"
proof -
  have hpos: "0 < max h 25" and dpos: "0 < max d 25" by auto
  have hn: "0 \<le> 25 / max h 25" using hpos by simp
  have dn: "0 \<le> (45/10) / max d 25" using dpos by simp
  have vn: "0 \<le> \<bar>v - 75\<bar>" by simp
  show ?thesis using assms hn dn vn
    by (auto simp: hm_def vm_def dm_def am_def max_def min_def; linarith)
qed

lemma niosh_weight_bound:
  assumes "niosh_domain h v d angle frequency coupling want_li load_value"
  shows "0 \<le> rwl_of h v d angle frequency coupling \<and> rwl_of h v d angle frequency coupling \<le> 23"
proof -
  have a: "0 \<le> angle" and f: "0 \<le> frequency" "frequency \<le> 1"
    and c: "0 \<le> coupling" "coupling \<le> 1"
    using assms by (auto simp: niosh_domain_def)
  note factors = niosh_factors_bounded[OF a, of h v d]
  have p1: "0 \<le> hm h * vm v \<and> hm h * vm v \<le> 1"
    using factors unit_product[of "hm h" "vm v"] by blast
  have p2: "0 \<le> hm h * vm v * dm d \<and> hm h * vm v * dm d \<le> 1"
    using factors p1 unit_product[of "hm h * vm v" "dm d"] by blast
  have p3: "0 \<le> hm h * vm v * dm d * am angle \<and> hm h * vm v * dm d * am angle \<le> 1"
    using factors p2 unit_product[of "hm h * vm v * dm d" "am angle"] by blast
  have p4: "0 \<le> hm h * vm v * dm d * am angle * frequency \<and> hm h * vm v * dm d * am angle * frequency \<le> 1"
    using f p3 unit_product[of "hm h * vm v * dm d * am angle" frequency] by blast
  have p5: "0 \<le> hm h * vm v * dm d * am angle * frequency * coupling \<and> hm h * vm v * dm d * am angle * frequency * coupling \<le> 1"
    using c p4 unit_product[of "hm h * vm v * dm d * am angle * frequency" coupling] by blast
  have scaled: "0 \<le> 23 * (hm h * vm v * dm d * am angle * frequency * coupling)
    \<and> 23 * (hm h * vm v * dm d * am angle * frequency * coupling) \<le> 23"
    using p5 by linarith
  show ?thesis using scaled by (simp add: rwl_of_def algebra_simps)
qed

theorem niosh_rwl_bound:
  assumes "kernel (Niosh (Some h) (Some v) (Some d) (Some angle) (Some frequency) (Some coupling) False None) = Exact k q"
  shows "k = K_rwl \<and> 0 \<le> q \<and> q \<le> 23"
  using kernel_exact_sound[OF assms] niosh_weight_bound[of h v d angle frequency coupling False None]
  by auto

theorem niosh_index_balance:
  assumes "kernel (Niosh (Some h) (Some v) (Some d) (Some angle) (Some frequency) (Some coupling) True (Some load_value)) = Exact k q"
  shows "k = K_li \<and> 0 \<le> load_value \<and> 0 < rwl_of h v d angle frequency coupling
    \<and> 0 \<le> q \<and> q * rwl_of h v d angle frequency coupling = load_value"
proof -
  have data: "k = K_li \<and> 0 \<le> load_value \<and> 0 < rwl_of h v d angle frequency coupling
    \<and> q * rwl_of h v d angle frequency coupling = load_value"
    using kernel_exact_sound[OF assms] by (auto simp: niosh_domain_def)
  have computed: "q = load_value / rwl_of h v d angle frequency coupling"
    using data by (auto simp: field_simps)
  have nonnegative: "0 \<le> q" using data computed by (auto intro: divide_nonneg_nonneg)
  show ?thesis using data nonnegative by blast
qed

lemma rows_unit_invariant:
  "kernel (Rows row_count gauge_span True inches True) = kernel (Rows row_count gauge_span True (inches * cm_per_inch) False)"
  by (simp add: kernel_def decline_of_def cast_width_def cm_per_inch_def)

lemma rows_nearest:
  assumes "kernel (Rows row_count gauge_span u target_len li) = Exact k q"
  shows "0 \<le> row_count \<and> 0 < gauge_span \<and> 0 \<le> target_len \<and> k = K_rows \<and> spec_he (row_count / gauge_span * cast_width u target_len li) q"
  using kernel_exact_sound[OF assms] by simp

text \<open>Covering and fitting have their physical-unit meanings, with no
slack around an integer boundary. These statements connect the independent
integer specifications to dimensions supplied to the consumer.\<close>
lemma least_cover_capacity:
  assumes "0 < unit_size" "least_cover (amount / unit_size) n"
  shows "amount \<le> n * unit_size \<and> (n - 1) * unit_size < amount"
proof -
  have lo: "amount / unit_size \<le> n" and hi: "n < amount / unit_size + 1"
    using assms by (auto simp: least_cover_def)
  have cover: "amount \<le> n * unit_size" using lo assms(1) by (simp add: divide_le_eq)
  have "n - 1 < amount / unit_size" using hi by linarith
  then have "(n - 1) * unit_size < amount" using assms(1) by (simp add: less_divide_eq)
  with cover show ?thesis by simp
qed

lemma most_fit_capacity:
  assumes "0 < unit_size" "most_fit (amount / unit_size) n"
  shows "n * unit_size \<le> amount \<and> amount < (n + 1) * unit_size"
proof -
  have lo: "n \<le> amount / unit_size" and hi: "amount / unit_size < n + 1"
    using assms by (auto simp: most_fit_def)
  show ?thesis using lo hi assms(1) by (simp add: le_divide_eq divide_less_eq)
qed

theorem layers_cover_height:
  assumes "kernel (Layers (Some (height_value, hu)) (Some (layer_height, lu))) = Exact k n"
  shows "k = K_layers \<and> 0 < length_inches lu layer_height \<and> 0 \<le> length_inches hu height_value \<and>
    length_inches hu height_value \<le> n * length_inches lu layer_height \<and>
    (n - 1) * length_inches lu layer_height < length_inches hu height_value"
  using kernel_exact_sound[OF assms]
    least_cover_capacity[of "length_inches lu layer_height" "length_inches hu height_value" n] by auto

theorem layers_count_nonnegative:
  assumes "kernel (Layers (Some (height_value, hu)) (Some (layer_height, lu))) = Exact k n"
  shows "0 \<le> n"
proof -
  have b: "0 < length_inches lu layer_height" "0 \<le> length_inches hu height_value"
      "length_inches hu height_value \<le> n * length_inches lu layer_height"
    using layers_cover_height[OF assms] by auto
  have "0 \<le> n * length_inches lu layer_height" using b(2,3) by linarith
  then show ?thesis using b(1) by (auto simp: zero_le_mult_iff)
qed

theorem occupants_cover_area:
  assumes "kernel (Occupant area_value load_source) = Exact k n"
  shows "k = K_occupant \<and> 0 < load_factor load_source \<and>
    area_value \<le> n * load_factor load_source \<and> (n - 1) * load_factor load_source < area_value"
  using kernel_exact_sound[OF assms] least_cover_capacity[of "load_factor load_source" area_value n] by auto

theorem drywall_covers_area:
  assumes "kernel (Drywall area_value openings sheet_kind) = Exact k n"
  shows "k = K_drywall \<and> area_value - openings \<le> n * sheet_area sheet_kind \<and>
    (n - 1) * sheet_area sheet_kind < area_value - openings"
  using kernel_exact_sound[OF assms] least_cover_capacity[of "sheet_area sheet_kind" "area_value - openings" n] by auto

theorem quilt_blocks_fit:
  assumes "kernel (Quilt width_value height_value block_size) = Exact k n"
  shows "k = K_quilt \<and> 0 < block_size \<and>
    (\<exists>nw nh. n = nw * nh \<and> nw * block_size \<le> width_value \<and> width_value < (nw + 1) * block_size
      \<and> nh * block_size \<le> height_value \<and> height_value < (nh + 1) * block_size)"
proof -
  have kind: "k = K_quilt" and positive: "0 < block_size"
    and fits: "\<exists>nw nh. most_fit (width_value / block_size) nw \<and>
      most_fit (height_value / block_size) nh \<and> n = nw * nh"
    using kernel_exact_sound[OF assms] by auto
  obtain nw nh where w: "most_fit (width_value / block_size) nw"
    and h: "most_fit (height_value / block_size) nh" and count: "n = nw * nh"
    using fits by blast
  have wb: "nw * block_size \<le> width_value \<and> width_value < (nw + 1) * block_size"
    by (rule most_fit_capacity[OF positive w])
  have hb: "nh * block_size \<le> height_value \<and> height_value < (nh + 1) * block_size"
    by (rule most_fit_capacity[OF positive h])
  show ?thesis using kind positive count wb hb by blast
qed

lemma answer_duo:
  "answer_of r = Duo k x y \<Longrightarrow>
     (\<exists>a b. r = ActualSize a b \<and> actual a = Some x \<and> actual b = Some y \<and> k = K_actual_size)
   \<or> (\<exists>w h b. r = Mat w h b \<and> x = w + 2 * b \<and> y = h + 2 * b \<and> k = K_mat_outer)"
  by (cases r) (auto split: option.splits prod.splits if_splits)

theorem kernel_duo_sound:
  assumes "kernel r = Duo k x y"
  shows "missing r = None \<and> \<not> impossible r \<and>
     ((\<exists>a b. r = ActualSize a b \<and> actual a = Some x \<and> actual b = Some y \<and> k = K_actual_size)
    \<or> (\<exists>w h b. r = Mat w h b \<and> x = w + 2 * b \<and> y = h + 2 * b \<and> k = K_mat_outer))"
proof -
  have d: "missing r = None \<and> reason_of r = None \<and> \<not> is_judge r \<and> answer_of r = kernel r"
    by (rule decline_none) (use assms in blast)
  then show ?thesis using assms answer_duo reason_of_exact[of r] by auto
qed

lemma answer_hue:
  "answer_of r = Hue k c \<Longrightarrow>
     (\<exists>a b. r = MixRyb a b \<and> mix_ryb a b = Some c \<and> k = K_mix_ryb)
   \<or> (\<exists>cs. r = MixRgb cs \<and> mix_rgb_many cs = Some c \<and> k = K_mix_rgb)
   \<or> (\<exists>x. r = Complement x \<and> c = comp_of x \<and> k = K_complement)"
  by (cases r) (auto split: option.splits if_splits)

theorem kernel_hue_sound:
  assumes "kernel r = Hue k c"
  shows "missing r = None \<and> \<not> impossible r \<and>
     ((\<exists>a b. r = MixRyb a b \<and> mix_ryb a b = Some c \<and> k = K_mix_ryb)
    \<or> (\<exists>cs. r = MixRgb cs \<and> mix_rgb_many cs = Some c \<and> k = K_mix_rgb)
    \<or> (\<exists>x. r = Complement x \<and> c = comp_of x \<and> k = K_complement))"
proof -
  have d: "missing r = None \<and> reason_of r = None \<and> \<not> is_judge r \<and> answer_of r = kernel r"
    by (rule decline_none) (use assms in blast)
  then show ?thesis using assms answer_hue reason_of_exact[of r] by auto
qed

theorem kernel_rgb_channel_union:
  assumes "kernel (MixRgb cs) = Hue k c"
  shows "k = K_mix_rgb \<and> cs \<noteq> [] \<and> list_all rgb_supported cs \<and>
         rgb_channels c = \<Union> (rgb_channels ` set cs)"
  using kernel_hue_sound[OF assms] mix_rgb_many_channels
  by auto

lemma answer_approx:
  "answer_of r = Approx k d \<Longrightarrow> k = kind_of r \<and>
     \<bar>dec_val d - interpret_floatarith (expr_of r) []\<bar> \<le> \<bar>interpret_floatarith (expr_of r) []\<bar> / 1000 + 1 / 1000"
  by (cases r) (auto dest: approx_out_sound split: option.splits prod.splits if_splits)

text \<open>An enclosed value is within a thousandth (relative, plus a thousandth absolute: the
organs print three decimals or four significant digits) of the real-number model.\<close>
theorem kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and>
     \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000"
proof -
  have d1: "missing r = None \<and> reason_of r = None \<and> \<not> is_judge r \<and> answer_of r = kernel r"
    by (rule decline_none) (use assms in blast)
  then have a: "answer_of r = Approx k d" using assms by simp
  have ni: "\<not> impossible r" using d1 reason_of_exact[of r] by auto
  have m: "interpret_floatarith (expr_of r) [] = phys r" using ni by (rule expr_of_meaning)
  show ?thesis using d1 ni answer_approx[OF a] m by auto
qed

section \<open>Model facts\<close>

theorem rafter_pythagoras:
  "phys (Rafter x rv u) ^ 2 = rl rv ^ 2 + (rl rv * (rl x / 12)) ^ 2"
proof -
  have p: "0 \<le> 1 + (rl x / 12) ^ 2" by simp
  show ?thesis by (simp add: power_mult_distrib real_sqrt_pow2[OF p] power_divide algebra_simps)
qed

theorem pitch_tan: "tan (pi / 180 * phys (Pitch x)) = rl x / 12"
proof -
  have e: "pi / 180 * (180 / pi * arctan (rl x / 12)) = arctan (rl x / 12)" by (simp add: field_simps)
  show ?thesis by (simp only: phys.simps e tan_arctan)
qed

theorem noise_halving: "phys (NoiseTime (l + 5)) * 2 = phys (NoiseTime l)"
proof -
  have a: "rl (l + 5) = rl l + 5" by (simp add: of_rat_add)
  have h1: "phys (NoiseTime (l + 5)) = 8 / (2 powr ((rl (l + 5) - 90) / 5))" by simp
  have h3: "phys (NoiseTime l) = 8 / (2 powr ((rl l - 90) / 5))" by simp
  have h2: "(rl (l + 5) - 90) / 5 = (rl l - 90) / 5 + 1" using a by (simp add: field_simps)
  have p: "(2::real) powr ((rl l - 90) / 5 + 1) = 2 powr ((rl l - 90) / 5) * 2" by (simp add: powr_add)
  have pos: "0 < (2::real) powr ((rl l - 90) / 5)" by simp
  have nz: "(2::real) powr ((rl l - 90) / 5) \<noteq> 0" using pos by simp
  show ?thesis unfolding h1 h3 h2 p using nz by (simp add: field_simps)
qed

theorem egress_widths: "egress_per True = 3 / 10 \<and> egress_per False = 1 / 5"
  by (simp add: egress_per_def)

text \<open>One board foot is 144 cubic inches. The result binds the exact
unit-converted rectangular volume and a nonnegative integral piece count.\<close>
theorem board_feet_volume:
  assumes "kernel (BoardFeet t tu w wu l lu n) = Exact k q"
  shows "k = K_board_feet \<and> 0 \<le> t \<and> 0 \<le> w \<and> 0 \<le> l \<and>
    0 \<le> n \<and> snd (quotient_of n) = 1 \<and>
    q * 144 = length_inches tu t * length_inches wu w * length_inches lu l * n"
  using kernel_exact_sound[OF assms] by (simp add: board_domain_def)

theorem board_feet_nonnegative:
  assumes "kernel (BoardFeet t tu w wu l lu n) = Exact k q"
  shows "0 \<le> q"
proof -
  have b: "0 \<le> t" "0 \<le> w" "0 \<le> l" "0 \<le> n"
    using board_feet_volume[OF assms] by auto
  have p: "0 \<le> length_inches tu t * length_inches wu w * length_inches lu l * n"
    using b length_inches_nonnegative by (intro mult_nonneg_nonneg) auto
  show ?thesis using p board_feet_volume[OF assms] by linarith
qed

theorem fabric_yards_balance:
  assumes "kernel (Yards x u) = Exact k q"
  shows "k = K_yards \<and> 0 \<le> x \<and> 0 \<le> q \<and> 36*q = length_inches u x"
proof -
  have b: "k = K_yards" "0 \<le> x" "q*36 = length_inches u x"
    using kernel_exact_sound[OF assms] by auto
  have "0 \<le> length_inches u x" using length_inches_nonnegative[OF b(2)] .
  then show ?thesis using b by linarith
qed

section \<open>Stated values\<close>

datatype vrule = V_int | V_f3 | V_f3c | V_g4 | V_g4c | V_cents

text \<open>How each exact kind is printed: a whole number, three decimals with trailing zeros
dropped (@{text "%.3f"}), the same with comma grouping from a million (architecture's
@{text g}), four significant digits, the same with comma grouping from ten thousand
(printing's @{text g}), or cents.\<close>
fun value_rule :: "kind \<Rightarrow> vrule" where
  "value_rule K_far = V_f3c" | "value_rule K_max_floor = V_f3c" | "value_rule K_coverage = V_f3c"
| "value_rule K_egress = V_f3c" | "value_rule K_ramp = V_f3c"
| "value_rule K_occupant = V_int" | "value_rule K_layers = V_int" | "value_rule K_drywall = V_int"
| "value_rule K_rows = V_int"
| "value_rule K_risers = V_int" | "value_rule K_cast_on = V_int" | "value_rule K_quilt = V_int"
| "value_rule K_shrink = V_g4c" | "value_rule K_flow = V_g4c"
| "value_rule K_cost = V_cents"
| "value_rule K_yards = V_g4"
| "value_rule K_ladder = V_g4" | "value_rule K_rwl = V_g4" | "value_rule K_li = V_g4"
| "value_rule _ = V_f3"

definition is_int :: "rat \<Rightarrow> bool" where "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

definition stated_dec :: "kind \<Rightarrow> rat \<Rightarrow> (int \<times> int) option" where
  "stated_dec k q = (case value_rule k of
       V_int \<Rightarrow> if is_int q then Some (fst (quotient_of q), 0) else None
     | V_f3 \<Rightarrow> Some (round_at (rl q) (- 3))
     | V_f3c \<Rightarrow> if 1000000 \<le> \<bar>rl q\<bar> then Some (round_at (rl q) 0) else Some (round_at (rl q) (- 3))
     | V_g4 \<Rightarrow> round_sig 4 (rl q)
     | V_g4c \<Rightarrow> if 10000 \<le> \<bar>rl q\<bar> then Some (round_at (rl q) 0) else round_sig 4 (rl q)
     | V_cents \<Rightarrow> Some (round_at (rl q) (- 2)))"

theorem stated_dec_sound:
  assumes "stated_dec k q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / 2000 + 1 / 200"
proof -
  have ab0: "0 \<le> \<bar>rl q\<bar>" by simp
  have p3: "pow10 (- 3) = 1 / 1000" by (simp add: pow10_def inverse_eq_divide)
  have p2: "pow10 (- 2) = 1 / 100" by (simp add: pow10_def inverse_eq_divide)
  have p0: "pow10 0 = 1" by (simp add: pow10_def)
  show ?thesis
  proof (cases "value_rule k")
    case V_int
    obtain a b where ab: "quotient_of q = (a, b)" by (cases "quotient_of q")
    have hd: "is_int q" and dd: "d = (fst (quotient_of q), 0)"
      using assms V_int by (auto simp: stated_dec_def split: if_splits)
    have b: "b = 1" using hd ab by (simp add: is_int_def)
    have "q = of_int a / of_int b" using ab by (rule quotient_of_div)
    then have qa: "q = of_int a" using b by simp
    have "dec_val d = rl q" using dd ab qa by (simp add: dec_val_def pow10_def)
    then show ?thesis using ab0 by simp
  next
    case V_f3
    then have "d = round_at (rl q) (- 3)" using assms by (simp add: stated_dec_def)
    then have "\<bar>dec_val d - rl q\<bar> \<le> pow10 (- 3) / 2" using round_at_error by simp
    then show ?thesis using p3 ab0 by linarith
  next
    case V_f3c
    show ?thesis
    proof (cases "1000000 \<le> \<bar>rl q\<bar>")
      case True
      then have "d = round_at (rl q) 0" using assms V_f3c by (simp add: stated_dec_def)
      then have "\<bar>dec_val d - rl q\<bar> \<le> pow10 0 / 2" using round_at_error by simp
      then show ?thesis using p0 True by linarith
    next
      case False
      then have "d = round_at (rl q) (- 3)" using assms V_f3c by (simp add: stated_dec_def)
      then have "\<bar>dec_val d - rl q\<bar> \<le> pow10 (- 3) / 2" using round_at_error by simp
      then show ?thesis using p3 ab0 by linarith
    qed
  next
    case V_g4
    then have "round_sig 4 (rl q) = Some d" using assms by (simp add: stated_dec_def)
    then have "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" by (rule round_sig_sound)
    then show ?thesis by simp
  next
    case V_g4c
    show ?thesis
    proof (cases "10000 \<le> \<bar>rl q\<bar>")
      case True
      then have "d = round_at (rl q) 0" using assms V_g4c by (simp add: stated_dec_def)
      then have "\<bar>dec_val d - rl q\<bar> \<le> pow10 0 / 2" using round_at_error by simp
      then show ?thesis using p0 True by linarith
    next
      case False
      then have "round_sig 4 (rl q) = Some d" using assms V_g4c by (simp add: stated_dec_def)
      then have "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" by (rule round_sig_sound)
      then show ?thesis by simp
    qed
  next
    case V_cents
    then have "d = round_at (rl q) (- 2)" using assms by (simp add: stated_dec_def)
    then have "\<bar>dec_val d - rl q\<bar> \<le> pow10 (- 2) / 2" using round_at_error by simp
    then show ?thesis using p2 ab0 by linarith
  qed
qed

definition dec_int :: "int \<times> int \<Rightarrow> int" where "dec_int d = fst d * 10 ^ nat (snd d)"

definition big_int :: "int \<Rightarrow> int \<times> int \<Rightarrow> bool" where
  "big_int thr d \<longleftrightarrow> 0 \<le> snd d \<and> thr \<le> \<bar>fst d\<bar> * 10 ^ nat (snd d)"

definition render_big :: "bool \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_big cm d = (if cm then show_commas (dec_int d) else show_int (dec_int d))"

text \<open>The stated number: with comma grouping in the reply text (@{text cm}), without it in
the JSON @{text value}.\<close>
definition value_lit :: "bool \<Rightarrow> kind \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "value_lit cm k d = (case value_rule k of
       V_int \<Rightarrow> show_int (fst d)
     | V_f3 \<Rightarrow> render_dec 100 d
     | V_f3c \<Rightarrow> if big_int 1000000 d then render_big cm d else render_dec 100 d
     | V_g4 \<Rightarrow> render_dec 4 d
     | V_g4c \<Rightarrow> if big_int 10000 d then render_big cm d else render_dec 4 d
     | V_cents \<Rightarrow> render_cents d)"

definition approx_lit :: "bool \<Rightarrow> kind \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "approx_lit cm k d = (case mode_of k of
       Sig4 \<Rightarrow> render_dec 4 d
     | Sig4C \<Rightarrow> if big_int 10000 d then render_big cm d else render_dec 4 d
     | Fix3 \<Rightarrow> render_dec 100 d)"

definition dec_rat :: "int \<times> int \<Rightarrow> rat" where
  "dec_rat d = (case d of (m, e) \<Rightarrow> if 0 \<le> e then of_int m * 10 ^ nat e else of_int m / 10 ^ nat (- e))"

section \<open>Response text (ASCII)\<close>

definition show3 :: "rat \<Rightarrow> String.literal" where
  "show3 q = render_dec 100 (round_at (rl q) (- 3))"

definition show3c :: "rat \<Rightarrow> String.literal" where
  "show3c q = (if 1000000 \<le> \<bar>rl q\<bar> then show_commas (fst (round_at (rl q) 0)) else show3 q)"

definition show4c :: "rat \<Rightarrow> String.literal" where
  "show4c q = (if 10000 \<le> \<bar>rl q\<bar> then show_commas (fst (round_at (rl q) 0)) else show4 q)"

definition show_whole :: "rat \<Rightarrow> String.literal" where
  "show_whole q = show_int (fst (quotient_of q))"

definition show_mixed :: "rat \<Rightarrow> String.literal" where
  "show_mixed q = (case quotient_of q of (a, b) \<Rightarrow>
     if a mod b = 0 then show_int (a div b)
     else if a div b = 0 then show_int (a mod b) + STR ''/'' + show_int b
     else show_int (a div b) + STR '' '' + show_int (a mod b) + STR ''/'' + show_int b)"

fun load_note :: "load_src \<Rightarrow> String.literal" where
  "load_note (Given f) = STR ''load factor '' + show3c f + STR '' sq ft per occupant (given)''"
| "load_note (Table u) = STR ''IBC Table 1004.5: '' + use_label u + STR '' sq ft per occupant''"

fun rho_note :: "dens_src \<Rightarrow> String.literal" where
  "rho_note (D_given r) = STR ''given density '' + show4c r + STR '' g/cm3''"
| "rho_note (D_typical f) = STR ''typical '' + fil_name f + STR '' density '' + show4c (fil_rho f) + STR '' g/cm3''"
| "rho_note D_none = STR ''''"

definition per_str :: "bool \<Rightarrow> String.literal" where
  "per_str st = (if st then STR ''0.3'' else STR ''0.2'')"

fun exact_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text (Far fa lot) q V = STR ''The FAR is '' + V + STR '' ('' + show3c fa
     + STR '' sq ft floor area / '' + show3c lot + STR '' sq ft lot).''"
| "exact_text (MaxFloor f lot) q V = STR ''The maximum floor area is '' + V + STR '' sq ft (FAR ''
     + show3 f + STR '' x '' + show3c lot + STR '' sq ft lot).''"
| "exact_text (Coverage fp lot) q V = STR ''The lot coverage is '' + V + STR ''% ('' + show3c fp
     + STR '' sq ft footprint / '' + show3c lot + STR '' sq ft lot).''"
| "exact_text (Occupant a s) q V = STR ''The occupant load is '' + V + STR '' ('' + show3c a
     + STR '' sq ft / '' + show3c (load_factor s) + STR '', rounded up; '' + load_note s + STR '').''"
| "exact_text (Egress a s st) q V = STR ''The required egress width is '' + V
     + STR '' in by capacity ('' + show_whole (ceil_rat (a / load_factor s)) + STR '' occupants x ''
     + per_str st + STR '' in; IBC 1005.3, ''
     + (if st then STR ''stairways'' else STR ''other egress components'') + STR ''; '' + load_note s
     + STR '') - minimum component widths still apply (e.g. stairways 44 in, or 36 in for an occupant load under 50; IBC 1011.2).''"
| "exact_text (Ramp r ft) q V = STR ''The minimum ramp run is '' + V + STR '' ft ('' + show3c (ramp_rise_in r ft)
     + STR '' in rise x 12 = '' + show3c (ramp_rise_in r ft * 12) + STR '' in; ADA maximum slope 1:12).''"
| "exact_text (Shrink p) q V = STR ''The scale factor is '' + V + STR '' ('' + show4c (the p)
     + STR ''%: 1 / (1 - '' + show4c (the p / 100) + STR '')), i.e. model it ''
     + show4c (100 * (q - 1)) + STR ''% larger.''"
| "exact_text (Layers h l) q V = STR ''That is '' + V + STR '' layers ('' + show4c (length_inches (snd (the h)) (fst (the h))) + STR '' in / ''
     + show4c (length_inches (snd (the l)) (fst (the l))) + STR '' in, rounded up; uniform layer height).''"
| "exact_text (Flow a b c) q V = STR ''The volumetric flow is '' + V
     + STR '' mm3/s (layer height x line width x speed).''"
| "exact_text (Cost g p) q V = STR ''The material cost is $'' + V + STR '' ('' + show4c g + STR '' g at $''
     + show4c (per_kg p) + STR ''/kg).''"
| "exact_text (Ladder l u) q V = STR ''The base should be '' + V + STR '' ''
     + (case u of L_ft \<Rightarrow> STR ''ft'' | L_m \<Rightarrow> STR ''m'') + STR '' out (one quarter of the '' + show4 (the l)
     + STR '' '' + (case u of L_ft \<Rightarrow> STR ''ft'' | L_m \<Rightarrow> STR ''m'')
     + STR '' working length; the 4-to-1 rule, OSHA 1926.1053(b)(5)(i)).''"
| "exact_text (Niosh h v d a fm cm want_li ld) q V = (if \<not> want_li then STR ''The recommended weight limit is '' + V + STR '' kg (23 x HM '' + show4 (hm (the h))
         + STR '' x VM '' + show4 (vm (the v)) + STR '' x DM '' + show4 (dm (the d))
         + STR '' x AM '' + show4 (am (the a)) + STR '' x FM '' + show4 (the fm)
         + STR '' x CM '' + show4 (the cm) + STR ''; NIOSH 1994).''
     else STR ''The lifting index is '' + V + STR '' ('' + show4 (the ld) + STR '' kg / RWL ''
         + show4 (rwl_of (the h) (the v) (the d) (the a) (the fm) (the cm))
         + STR '' kg; NIOSH lifting equation)''
         + (if 1 < q then STR '' - above 1, the lift is a risk for some workers'' else STR '''') + STR ''.'')"
| "exact_text (BoardFeet th tu w wu l lu k) q V = STR ''That is '' + V + STR '' board feet ('' + show3 (length_inches tu th)
     + STR '' in x '' + show3 (length_inches wu w) + STR '' in x '' + show3 (length_inches lu l)
     + STR '' in x '' + show3 k + STR '' pieces / 144 cubic inches per board foot; rectangular pieces, no waste allowance).''"
| "exact_text (Concrete l w d inch) q V = STR ''The volume is '' + V + STR '' cubic yards ('' + show3 l
     + STR '' ft x '' + show3 w + STR '' ft x '' + show3 (if inch then d / 12 else d)
     + STR '' ft / 27; no waste allowance).''"
| "exact_text (Drywall a ov s) q V = STR ''You need '' + V + STR '' sheets ('' + show3 (a - ov) + STR '' sq ft''
     + (if ov \<noteq> 0 then STR '' after '' + show3 ov + STR '' sq ft of openings'' else STR '''')
     + STR '' / '' + show_whole (sheet_area s) + STR '' sq ft per 4x'' + show_whole (sheet_area s / 4)
     + STR '' sheet, rounded up; no waste allowance).''"
| "exact_text (Stairs r ft h) q V = (if h
     then STR ''Each riser is '' + V + STR '' in ('' + show3 (rise_in r ft) + STR '' in / ''
       + show_whole (ceil_rat (rise_in r ft / max_riser)) + STR '' risers; IRC maximum 7 3/4 in).''
     else STR ''You need '' + V + STR '' risers of '' + show3 (rise_in r ft / q) + STR '' in each (''
       + show3 (rise_in r ft) + STR '' in / 7.75 in, rounded up; IRC R311.7.5.1 maximum riser 7 3/4 in).'')"
| "exact_text (Miter n) q V = STR ''The miter angle is '' + V + STR '' degrees per cut (180 / '' + show_nat n
     + STR '' sides).''"
| "exact_text (Moisture w d) q V = STR ''The moisture content is '' + V + STR ''% (('' + show3 w + STR '' - ''
     + show3 d + STR '') / '' + show3 d + STR '', oven-dry basis; USDA Wood Handbook).''"
| "exact_text (Rows row_count gauge_span u l li) q V = STR ''Work '' + V + STR '' rows ('' + show3 (row_count / gauge_span)
     + STR '' rows per '' + (if u then STR ''inch'' else STR ''cm'') + STR '' x ''
     + show3 (cast_width u l li) + STR '' '' + (if u then STR ''in'' else STR ''cm'') + STR ''; nearest whole row, ties to even).''"
| "exact_text (CastOn spu u w wi) q V = STR ''Cast on '' + V + STR '' stitches ('' + show3 spu
     + STR '' stitches per '' + (if u then STR ''inch'' else STR ''cm'') + STR '' x ''
     + show3 (cast_width u w wi) + STR '' '' + (if u then STR ''in'' else STR ''cm'') + STR '', rounded).''"
| "exact_text (Quilt w l s) q V = STR ''You need '' + V + STR '' blocks ('' + show_whole (floor_rat (w / s))
     + STR '' across x '' + show_whole (floor_rat (l / s)) + STR '' down of '' + show3 s
     + STR '' in finished blocks).''"
| "exact_text (CutSize s) q V = STR ''Cut the squares at '' + V + STR '' in ('' + show3 s
     + STR '' in finished + 1/2 in for a 1/4 in seam allowance on each side).''"
| "exact_text (Yards i u) q V = STR ''That is '' + V + STR '' yards ('' + show3 (length_inches u i) + STR '' in / 36; continuous fabric length, no whole-yard rounding).''"
| "exact_text (Clay p s u) q V = STR ''The fired size is '' + V + STR '' '' + cunit_label u + STR '' (''
     + show3 s + STR '' x (1 - '' + show3 p + STR ''%)).''"
| "exact_text r q V = V"

fun approx_text :: "request \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "approx_text (FilLength m d s) D = STR ''That is about '' + approx_lit True K_length D
     + STR '' m of filament ('' + show4c m + STR '' g / ('' + show4c (dens s) + STR '' x pi(''
     + show4c (the d) + STR '' mm/2)^2); '' + rho_note s + STR '').''"
| "approx_text (FilMass l d s) D = STR ''That is about '' + approx_lit True K_mass D
     + STR '' g of filament ('' + show4c l + STR '' m x pi('' + show4c (the d) + STR '' mm/2)^2 x ''
     + show4c (dens s) + STR ''; '' + rho_note s + STR '').''"
| "approx_text (NoiseTime l) D = STR ''The permissible exposure is '' + approx_lit True K_noise_time D
     + STR '' hours at '' + show4 l + STR '' dBA (T = 8 / 2^((L - 90)/5), OSHA 1910.95 Table G-16).''"
| "approx_text (NoiseDose ls cs) D = STR ''The noise dose is '' + approx_lit True K_noise_dose D
     + STR ''% (D = 100 x sum C/T with T = 8 / 2^((L - 90)/5); OSHA 1910.95)''
     + (if 100 < dec_rat D then STR '' - above the 100% permissible dose'' else STR '''') + STR ''.''"
| "approx_text (Twa ls cs) D = STR ''The 8-hour TWA is '' + approx_lit True K_twa D
     + STR '' dBA (16.61 log10(D/100) + 90 with dose D = ''
     + (case enclose_m Sig4 prec (expr_of (NoiseDose ls cs)) of Some e \<Rightarrow> render_dec 4 e | None \<Rightarrow> STR ''?'')
     + STR ''%; OSHA 1910.95 App. A).''"
| "approx_text (Rafter x rv ft) D = STR ''The rafter length is '' + approx_lit True K_rafter D + STR '' ''
     + (if ft then STR ''ft'' else STR ''in'') + STR '' (run '' + show3 rv + STR '' x sqrt(1 + ('' + show3 x
     + STR ''/12)^2); no overhang or ridge deduction).''"
| "approx_text (Pitch x) D = STR ''The roof angle is '' + approx_lit True K_pitch D
     + STR '' degrees (atan('' + show3 x + STR ''/12)).''"
| "approx_text r D = approx_lit True (kind_of r) D"

fun duo_text :: "request \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "duo_text (ActualSize a b) x y = STR ''The actual size is '' + show_mixed x + STR '' x '' + show_mixed y
     + STR '' in (a nominal '' + show_nat a + STR ''x'' + show_nat b + STR '', dressed dry, PS 20).''"
| "duo_text (Mat w h b) x y = STR ''The outer size is '' + show3 x + STR '' x '' + show3 y
     + STR '' (artwork + 2 x '' + show3 b + STR '' border on each dimension).''"
| "duo_text r x y = show3 x + STR '' x '' + show3 y"

fun sort_pair :: "colour \<Rightarrow> colour \<Rightarrow> colour \<times> colour" where
  "sort_pair a b = (if crank a \<le> crank b then (a, b) else (b, a))"

fun hue_text :: "request \<Rightarrow> colour \<Rightarrow> String.literal" where
  "hue_text (MixRyb a b) c = STR ''The colour is '' + cname c + STR '' (traditional RYB painter'' + apos
     + STR ''s colour wheel: '' + cname (fst (sort_pair a b)) + STR '' + '' + cname (snd (sort_pair a b)) + STR '').''"
| "hue_text (MixRgb cs) c = STR ''The colour is '' + cname c
     + STR '' (saturated digital RGB channels; no brightness or spectral prediction).''"
| "hue_text (Complement x) c = STR ''The complementary colour is '' + cname c
     + STR '' (traditional RYB colour wheel, opposite '' + cname x + STR '').''"
| "hue_text r c = cname c"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text n = (case n of
       N_fabric_length \<Rightarrow> STR ''I need one unambiguous fabric length with a supported source unit to convert to yards; widths, areas and waste allowances need a different model.''
     | N_board_inputs \<Rightarrow> STR ''I need three unambiguous rectangular dimensions with length units and a whole number of pieces; thickness and width without units use the board-foot inch convention.''
     | N_rgb_model \<Rightarrow> STR ''I can combine named full digital RGB channels; I need the supported colour names and cannot infer brightness or a weighted physical light mixture.''
     | N_shrink \<Rightarrow> STR ''I need the shrinkage percentage to work that out; I won'' + apos + STR ''t assume it.''
     | N_height_layer \<Rightarrow> STR ''I need the part height and the layer height to work that out; I won'' + apos + STR ''t assume it.''
     | N_flow_inputs \<Rightarrow> STR ''I need the layer height, the line width and the print speed to work that out; I won'' + apos + STR ''t assume it.''
     | N_spool_weight \<Rightarrow> STR ''I need the spool'' + apos + STR ''s weight to work that out; I won'' + apos + STR ''t assume it.''
     | N_filament_diameter \<Rightarrow> STR ''I need the filament diameter to work that out; I won'' + apos + STR ''t assume it.''
     | N_material \<Rightarrow> STR ''I need the material (or its density) to work that out; I won'' + apos + STR ''t assume it.''
     | N_noise_times \<Rightarrow> STR ''I need an exposure time for each noise level to calculate that; I won'' + apos + STR ''t assume it.''
     | N_ladder_length \<Rightarrow> STR ''I need the ladder'' + apos + STR ''s working length (to the top support) to calculate that; I won'' + apos + STR ''t assume it.''
     | N_niosh_geometry \<Rightarrow> STR ''I need the horizontal distance, vertical height, travel distance (cm) and asymmetry angle to calculate that; I won'' + apos + STR ''t assume it.''
     | N_niosh_load \<Rightarrow> STR ''I need the load in kilograms to calculate the lifting index.''
     | N_niosh_multipliers \<Rightarrow> STR ''I need the frequency and coupling multipliers (they come from the NIOSH tables for your lift rate and grip) to calculate that; I won'' + apos + STR ''t assume it.'')"

definition reason_text :: "request \<Rightarrow> reason \<Rightarrow> String.literal" where
  "reason_text r y = (case y of
       R_negative_length \<Rightarrow> STR ''A physical fabric length cannot be negative.''
     | R_board_domain \<Rightarrow> STR ''Board dimensions and piece count must be nonnegative, and the number of complete pieces must be an integer.''
     | R_niosh_domain \<Rightarrow> STR ''NIOSH inputs need nonnegative distances, angle and load; frequency multiplier from 0 to 1; and coupling multiplier 0.90, 0.95 or 1.00.''
     | R_gauge_dimensions \<Rightarrow> STR ''The gauge span must be positive and row count and target length nonnegative.''
     | R_nominal_size \<Rightarrow> (case r of ActualSize a b \<Rightarrow> show_nat a + STR ''x'' + show_nat b
           + STR '' is outside the standard dimensional-lumber table (PS 20).'' | _ \<Rightarrow> STR ''Not in the lumber table.'')
     | R_few_sides \<Rightarrow> STR ''A closed frame needs at least 3 sides.''
     | R_dry_exceeds_wet \<Rightarrow> STR ''The oven-dry mass cannot exceed the wet mass.''
     | R_shrink_range \<Rightarrow> STR ''Shrinkage must be between 0 and 100%.''
     | R_layer_nonpositive \<Rightarrow> STR ''The part height must be nonnegative and the uniform layer height positive.''
     | R_no_mix \<Rightarrow> STR ''That colour pair has no mix on this colour wheel.''
     | _ \<Rightarrow> STR ''That cannot be worked out from those numbers.'')"

definition decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r w = (case w of
       Underspecified n \<Rightarrow> need_text n
     | Judgement \<Rightarrow> STR ''Whether a specific situation is safe needs a qualified person looking at it on site; I can only do the regulation arithmetic (noise dose, ladder angle, lifting limits) for numbers you give me.''
     | Impossible y \<Rightarrow> reason_text r y
     | Imprecise \<Rightarrow> STR ''I could not state that value to the digits the organ prints.'')"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | Judgement \<Rightarrow> STR ''judgement''
     | Impossible _ \<Rightarrow> STR ''impossible'' | Imprecise \<Rightarrow> STR ''imprecise'')"

fun kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name K_far = STR ''far''" | "kind_name K_max_floor = STR ''max_floor''"
| "kind_name K_coverage = STR ''coverage''" | "kind_name K_occupant = STR ''occupant_load''"
| "kind_name K_egress = STR ''egress_width''" | "kind_name K_ramp = STR ''ramp_run''"
| "kind_name K_shrink = STR ''shrink_scale''" | "kind_name K_layers = STR ''layers''"
| "kind_name K_flow = STR ''flow''" | "kind_name K_cost = STR ''cost''"
| "kind_name K_length = STR ''length''" | "kind_name K_mass = STR ''mass''"
| "kind_name K_noise_time = STR ''noise_time''" | "kind_name K_noise_dose = STR ''noise_dose''"
| "kind_name K_twa = STR ''twa''" | "kind_name K_ladder = STR ''ladder''"
| "kind_name K_rwl = STR ''rwl''" | "kind_name K_li = STR ''lifting_index''"
| "kind_name K_actual_size = STR ''actual_size''" | "kind_name K_board_feet = STR ''board_feet''"
| "kind_name K_concrete = STR ''concrete''" | "kind_name K_drywall = STR ''drywall''"
| "kind_name K_risers = STR ''risers''" | "kind_name K_riser_height = STR ''riser_height''"
| "kind_name K_rafter = STR ''rafter''" | "kind_name K_pitch = STR ''pitch_angle''"
| "kind_name K_miter = STR ''miter''" | "kind_name K_wood_mc = STR ''wood_mc''"
| "kind_name K_mix_ryb = STR ''mix_ryb''" | "kind_name K_mix_rgb = STR ''mix_rgb''"
| "kind_name K_rows = STR ''rows''"
| "kind_name K_complement = STR ''complement''" | "kind_name K_cast_on = STR ''cast_on''"
| "kind_name K_quilt = STR ''quilt_blocks''" | "kind_name K_cut_size = STR ''cut_size''"
| "kind_name K_yards = STR ''yards''" | "kind_name K_mat_outer = STR ''mat_outer''"
| "kind_name K_clay_fired = STR ''clay_fired''"

text \<open>The whole reply: answered or withheld, the kind, the response text and the stated value.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow> (case stated_dec k q of
         None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text r Imprecise) None
       | Some d \<Rightarrow> Reply True (kind_name k) (exact_text r q (value_lit True k d)) (Some (value_lit False k d)))
   | Duo k x y \<Rightarrow> Reply True (kind_name k) (duo_text r x y) None
   | Hue k c \<Rightarrow> Reply True (kind_name k) (hue_text r c) None
   | Approx k d \<Rightarrow> Reply True (kind_name k) (approx_text r d) (Some (approx_lit False k d))
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text r w) None)"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d. kernel r = Exact k q \<and> stated_dec k q = Some d) \<or> (\<exists>k x y. kernel r = Duo k x y)
     \<or> (\<exists>k c. kernel r = Hue k c) \<or> (\<exists>k d. kernel r = Approx k d)"
  by (auto simp: reply_of_def split: outcome.splits option.splits)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated_dec k q = Some d \<Longrightarrow> stated (reply_of r) = Some (value_lit False k d)"
  by (simp add: reply_of_def)

theorem reply_states_approx:
  "kernel r = Approx k d \<Longrightarrow> stated (reply_of r) = Some (approx_lit False k d)"
  by (simp add: reply_of_def)

text \<open>A withheld reply names the kernel's decline.\<close>
theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

end
