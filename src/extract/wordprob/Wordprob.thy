theory Wordprob
  imports "Veri7vn_Wordprob_Base.Wordprob_Base"
begin

text \<open>
  The Oracle7 head's word-problem organ (upstream/root/wander-train/
  word_problems_v1.py, admitted through fold w488) as one verified HOL kernel
  over exact rationals. The organ stores nine schemas (simple interest, unit
  price, total cost, sale price, percent of a total, percent of, motion,
  conversion, geometry); a schema fires only when every typed quantity it
  needs was read off the text, and two schemas firing is an abstention.

  Division of labour: the UNTRUSTED SML recognizer (recognizer.sml) reads
  numbers, units and trigger words off the question and builds a typed
  request list, one per schema that fired, in the organ's order; it computes
  nothing. The kernel (this theory) holds the organ's unit tables, computes
  every value as an exact rational, refuses division by zero, enforces the
  exactly-one-schema rule, and renders the reply in the shape the head prints
  (fold w488's template, fold w490's pluralisation of the value's unit).

  The tables (unit factors, unit names, the pluralised units) are transcribed
  from the organ and from fold w490; tables_check.py parses both sources and
  fails on any difference.
\<close>

section \<open>The organ's unit tables\<close>

datatype mkind = Mlength | Mmass | Mvolume | Mtime

text \<open>One constructor per key of the organ's four tables (aliases kept
apart, because the organ prints the key it matched: a question asking in
"feet" is answered in "feet").\<close>
datatype wunit =
    U_mm | U_millimeter | U_cm | U_centimeter | U_m | U_meter | U_km
  | U_kilometer | U_in | U_inch | U_ft | U_foot | U_feet | U_yd | U_yard
  | U_mi | U_mile
  | U_mg | U_milligram | U_g | U_gram | U_kg | U_kilogram | U_oz | U_ounce
  | U_lb | U_pound | U_ton
  | U_ml | U_milliliter | U_l | U_liter | U_litre | U_cup | U_pint
  | U_quart | U_gallon | U_tsp | U_tbsp
  | U_second | U_sec | U_minute | U_min | U_hour | U_hr | U_h | U_day
  | U_week | U_year

fun ukind :: "wunit \<Rightarrow> mkind" where
    "ukind U_mm = Mlength" | "ukind U_millimeter = Mlength"
  | "ukind U_cm = Mlength" | "ukind U_centimeter = Mlength"
  | "ukind U_m = Mlength" | "ukind U_meter = Mlength"
  | "ukind U_km = Mlength" | "ukind U_kilometer = Mlength"
  | "ukind U_in = Mlength" | "ukind U_inch = Mlength"
  | "ukind U_ft = Mlength" | "ukind U_foot = Mlength" | "ukind U_feet = Mlength"
  | "ukind U_yd = Mlength" | "ukind U_yard = Mlength"
  | "ukind U_mi = Mlength" | "ukind U_mile = Mlength"
  | "ukind U_mg = Mmass" | "ukind U_milligram = Mmass"
  | "ukind U_g = Mmass" | "ukind U_gram = Mmass"
  | "ukind U_kg = Mmass" | "ukind U_kilogram = Mmass"
  | "ukind U_oz = Mmass" | "ukind U_ounce = Mmass"
  | "ukind U_lb = Mmass" | "ukind U_pound = Mmass" | "ukind U_ton = Mmass"
  | "ukind U_ml = Mvolume" | "ukind U_milliliter = Mvolume"
  | "ukind U_l = Mvolume" | "ukind U_liter = Mvolume" | "ukind U_litre = Mvolume"
  | "ukind U_cup = Mvolume" | "ukind U_pint = Mvolume"
  | "ukind U_quart = Mvolume" | "ukind U_gallon = Mvolume"
  | "ukind U_tsp = Mvolume" | "ukind U_tbsp = Mvolume"
  | "ukind _ = Mtime"

text \<open>The organ's factors, in the organ's own base units: length in metres,
mass in grams, volume in litres, time in HOURS (the organ's @{text TIME}
table is hour-based: a second is 1/3600 hour, a year is 8766 hours).\<close>
fun scale :: "wunit \<Rightarrow> rat" where
    "scale U_mm = 1 / 1000" | "scale U_millimeter = 1 / 1000"
  | "scale U_cm = 1 / 100" | "scale U_centimeter = 1 / 100"
  | "scale U_m = 1" | "scale U_meter = 1"
  | "scale U_km = 1000" | "scale U_kilometer = 1000"
  | "scale U_in = 254 / 10000" | "scale U_inch = 254 / 10000"
  | "scale U_ft = 3048 / 10000" | "scale U_foot = 3048 / 10000"
  | "scale U_feet = 3048 / 10000"
  | "scale U_yd = 9144 / 10000" | "scale U_yard = 9144 / 10000"
  | "scale U_mi = 1609344 / 1000" | "scale U_mile = 1609344 / 1000"
  | "scale U_mg = 1 / 1000" | "scale U_milligram = 1 / 1000"
  | "scale U_g = 1" | "scale U_gram = 1"
  | "scale U_kg = 1000" | "scale U_kilogram = 1000"
  | "scale U_oz = 28349523125 / 1000000000" | "scale U_ounce = 28349523125 / 1000000000"
  | "scale U_lb = 45359237 / 100000" | "scale U_pound = 45359237 / 100000"
  | "scale U_ton = 90718474 / 100"
  | "scale U_ml = 1 / 1000" | "scale U_milliliter = 1 / 1000"
  | "scale U_l = 1" | "scale U_liter = 1" | "scale U_litre = 1"
  | "scale U_cup = 2365882365 / 10000000000"
  | "scale U_pint = 473176473 / 1000000000"
  | "scale U_quart = 946352946 / 1000000000"
  | "scale U_gallon = 3785411784 / 1000000000"
  | "scale U_tsp = 492892 / 100000000" | "scale U_tbsp = 147868 / 10000000"
  | "scale U_second = 1 / 3600" | "scale U_sec = 1 / 3600"
  | "scale U_minute = 1 / 60" | "scale U_min = 1 / 60"
  | "scale U_hour = 1" | "scale U_hr = 1" | "scale U_h = 1"
  | "scale U_day = 24" | "scale U_week = 168" | "scale U_year = 8766"

fun uname :: "wunit \<Rightarrow> String.literal" where
    "uname U_mm = STR ''mm''" | "uname U_millimeter = STR ''millimeter''"
  | "uname U_cm = STR ''cm''" | "uname U_centimeter = STR ''centimeter''"
  | "uname U_m = STR ''m''" | "uname U_meter = STR ''meter''"
  | "uname U_km = STR ''km''" | "uname U_kilometer = STR ''kilometer''"
  | "uname U_in = STR ''in''" | "uname U_inch = STR ''inch''"
  | "uname U_ft = STR ''ft''" | "uname U_foot = STR ''foot''"
  | "uname U_feet = STR ''feet''"
  | "uname U_yd = STR ''yd''" | "uname U_yard = STR ''yard''"
  | "uname U_mi = STR ''mi''" | "uname U_mile = STR ''mile''"
  | "uname U_mg = STR ''mg''" | "uname U_milligram = STR ''milligram''"
  | "uname U_g = STR ''g''" | "uname U_gram = STR ''gram''"
  | "uname U_kg = STR ''kg''" | "uname U_kilogram = STR ''kilogram''"
  | "uname U_oz = STR ''oz''" | "uname U_ounce = STR ''ounce''"
  | "uname U_lb = STR ''lb''" | "uname U_pound = STR ''pound''"
  | "uname U_ton = STR ''ton''"
  | "uname U_ml = STR ''ml''" | "uname U_milliliter = STR ''milliliter''"
  | "uname U_l = STR ''l''" | "uname U_liter = STR ''liter''"
  | "uname U_litre = STR ''litre''"
  | "uname U_cup = STR ''cup''" | "uname U_pint = STR ''pint''"
  | "uname U_quart = STR ''quart''" | "uname U_gallon = STR ''gallon''"
  | "uname U_tsp = STR ''tsp''" | "uname U_tbsp = STR ''tbsp''"
  | "uname U_second = STR ''second''" | "uname U_sec = STR ''sec''"
  | "uname U_minute = STR ''minute''" | "uname U_min = STR ''min''"
  | "uname U_hour = STR ''hour''" | "uname U_hr = STR ''hr''"
  | "uname U_h = STR ''h''"
  | "uname U_day = STR ''day''" | "uname U_week = STR ''week''"
  | "uname U_year = STR ''year''"

text \<open>The unit table in the organ's own order (length, mass, volume, time;
dict order within each), for the untrusted recognizer's name lookup and for
tables_check.py.\<close>
definition unit_table :: "(String.literal \<times> mkind \<times> wunit) list" where
  "unit_table = [
    (STR ''mm'', Mlength, U_mm), (STR ''millimeter'', Mlength, U_millimeter),
    (STR ''cm'', Mlength, U_cm), (STR ''centimeter'', Mlength, U_centimeter),
    (STR ''m'', Mlength, U_m), (STR ''meter'', Mlength, U_meter),
    (STR ''km'', Mlength, U_km), (STR ''kilometer'', Mlength, U_kilometer),
    (STR ''in'', Mlength, U_in), (STR ''inch'', Mlength, U_inch),
    (STR ''ft'', Mlength, U_ft), (STR ''foot'', Mlength, U_foot),
    (STR ''feet'', Mlength, U_feet),
    (STR ''yd'', Mlength, U_yd), (STR ''yard'', Mlength, U_yard),
    (STR ''mi'', Mlength, U_mi), (STR ''mile'', Mlength, U_mile),
    (STR ''mg'', Mmass, U_mg), (STR ''milligram'', Mmass, U_milligram),
    (STR ''g'', Mmass, U_g), (STR ''gram'', Mmass, U_gram),
    (STR ''kg'', Mmass, U_kg), (STR ''kilogram'', Mmass, U_kilogram),
    (STR ''oz'', Mmass, U_oz), (STR ''ounce'', Mmass, U_ounce),
    (STR ''lb'', Mmass, U_lb), (STR ''pound'', Mmass, U_pound),
    (STR ''ton'', Mmass, U_ton),
    (STR ''ml'', Mvolume, U_ml), (STR ''milliliter'', Mvolume, U_milliliter),
    (STR ''l'', Mvolume, U_l), (STR ''liter'', Mvolume, U_liter),
    (STR ''litre'', Mvolume, U_litre),
    (STR ''cup'', Mvolume, U_cup), (STR ''pint'', Mvolume, U_pint),
    (STR ''quart'', Mvolume, U_quart), (STR ''gallon'', Mvolume, U_gallon),
    (STR ''tsp'', Mvolume, U_tsp), (STR ''tbsp'', Mvolume, U_tbsp),
    (STR ''second'', Mtime, U_second), (STR ''sec'', Mtime, U_sec),
    (STR ''minute'', Mtime, U_minute), (STR ''min'', Mtime, U_min),
    (STR ''hour'', Mtime, U_hour), (STR ''hr'', Mtime, U_hr),
    (STR ''h'', Mtime, U_h), (STR ''day'', Mtime, U_day),
    (STR ''week'', Mtime, U_week), (STR ''year'', Mtime, U_year)]"

text \<open>Geometry's pi: the organ uses 3.14 when the text says so, and the
double @{text math.pi} otherwise. @{text Pidouble} IS that double, exactly:
@{term "884279719003555 / 281474976710656"} is the value of the IEEE double
nearest to pi, so the kernel models the organ's pi exactly (the organ's
float ARITHMETIC around it is not modelled; after rounding to six decimals
the two agree on every panel shape).\<close>
datatype pival = Pi314 | Pidouble

definition pi_of :: "pival \<Rightarrow> rat" where
  "pi_of p = (if p = Pi314 then 157 / 50 else 884279719003555 / 281474976710656)"


section \<open>Requests\<close>

text \<open>One constructor per organ schema branch. @{term "PercentOf m r w"}:
@{text m} is the money flag (the organ answers in dollars exactly when the
text contains a dollar sign). Motion: the organ converts the TIME to hours
with its table and never converts the rate; the rate's own label (say
"miles" of "miles/hour") is read off the text, so it travels as a literal.\<close>
datatype wp =
    PercentOf bool rat rat
  | Convert rat wunit wunit
  | SimpleInterest rat rat rat
  | UnitPrice rat rat
  | TotalCost rat rat
  | SaleOff rat rat
  | SalePct rat rat
  | PercentOfTotal rat rat
  | MotionDist rat rat wunit String.literal
  | MotionSpeed rat wunit rat wunit
  | RectArea rat rat
  | RectPerim rat rat
  | CircleArea rat pival
  | CircleCirc rat pival
  | ConeVol rat rat pival
  | CylVol rat rat pival
  | SphereVol rat pival

datatype skind = Ssimple_interest | Sunit_price | Stotal_cost | Ssale_price
  | Spercent_of_total | Spercent_of | Smotion | Sconvert | Sgeometry

fun skind_of :: "wp \<Rightarrow> skind" where
    "skind_of (PercentOf _ _ _) = Spercent_of"
  | "skind_of (Convert _ _ _) = Sconvert"
  | "skind_of (SimpleInterest _ _ _) = Ssimple_interest"
  | "skind_of (UnitPrice _ _) = Sunit_price"
  | "skind_of (TotalCost _ _) = Stotal_cost"
  | "skind_of (SaleOff _ _) = Ssale_price"
  | "skind_of (SalePct _ _) = Ssale_price"
  | "skind_of (PercentOfTotal _ _) = Spercent_of_total"
  | "skind_of (MotionDist _ _ _ _) = Smotion"
  | "skind_of (MotionSpeed _ _ _ _) = Smotion"
  | "skind_of _ = Sgeometry"

fun sname :: "skind \<Rightarrow> String.literal" where
    "sname Ssimple_interest = STR ''simple_interest''"
  | "sname Sunit_price = STR ''unit_price''"
  | "sname Stotal_cost = STR ''total_cost''"
  | "sname Ssale_price = STR ''sale_price''"
  | "sname Spercent_of_total = STR ''percent_of_total''"
  | "sname Spercent_of = STR ''percent_of''"
  | "sname Smotion = STR ''motion''"
  | "sname Sconvert = STR ''convert''"
  | "sname Sgeometry = STR ''geometry''"

text \<open>The organ's @{text "schema.replace(chr(95), chr(32))"} for "Read as".\<close>
fun read_name :: "skind \<Rightarrow> String.literal" where
    "read_name Ssimple_interest = STR ''simple interest''"
  | "read_name Sunit_price = STR ''unit price''"
  | "read_name Stotal_cost = STR ''total cost''"
  | "read_name Ssale_price = STR ''sale price''"
  | "read_name Spercent_of_total = STR ''percent of total''"
  | "read_name Spercent_of = STR ''percent of''"
  | "read_name Smotion = STR ''motion''"
  | "read_name Sconvert = STR ''convert''"
  | "read_name Sgeometry = STR ''geometry''"


section \<open>Values and declines\<close>

fun wvalue :: "wp \<Rightarrow> rat" where
    "wvalue (PercentOf _ r w) = r / 100 * w"
  | "wvalue (Convert x a b) = x * scale a / scale b"
  | "wvalue (SimpleInterest P r n) = P * r / 100 * n"
  | "wvalue (UnitPrice p n) = p / n"
  | "wvalue (TotalCost n p) = n * p"
  | "wvalue (SaleOff a b) = a - b"
  | "wvalue (SalePct a r) = a * (1 - r / 100)"
  | "wvalue (PercentOfTotal a b) = min a b / max a b * 100"
  | "wvalue (MotionDist r t u _) = r * (t * scale u)"
  | "wvalue (MotionSpeed x u t u') = x * scale u / (t * scale u')"
  | "wvalue (RectArea l w) = l * w"
  | "wvalue (RectPerim l w) = 2 * (l + w)"
  | "wvalue (CircleArea r p) = pi_of p * r * r"
  | "wvalue (CircleCirc r p) = 2 * pi_of p * r"
  | "wvalue (ConeVol r h p) = pi_of p * r * r * h / 3"
  | "wvalue (CylVol r h p) = pi_of p * r * r * h"
  | "wvalue (SphereVol r p) = 4 / 3 * pi_of p * r ^ 3"

fun wlab :: "wp \<Rightarrow> String.literal" where
    "wlab (PercentOf m _ _) = (if m then STR ''$'' else STR '''')"
  | "wlab (Convert _ _ b) = uname b"
  | "wlab (SimpleInterest _ _ _) = STR ''$''"
  | "wlab (UnitPrice _ _) = STR ''$''"
  | "wlab (TotalCost _ _) = STR ''$''"
  | "wlab (SaleOff _ _) = STR ''$''"
  | "wlab (SalePct _ _) = STR ''$''"
  | "wlab (PercentOfTotal _ _) = STR ''%''"
  | "wlab (MotionDist _ _ _ l) = l"
  | "wlab (MotionSpeed _ u _ _) = uname u + STR ''/h''"
  | "wlab (RectArea _ _) = STR ''sq''"
  | "wlab (RectPerim _ _) = STR ''''"
  | "wlab (CircleArea _ _) = STR ''sq''"
  | "wlab (CircleCirc _ _) = STR ''''"
  | "wlab (ConeVol _ _ _) = STR ''cu''"
  | "wlab (CylVol _ _ _) = STR ''cu''"
  | "wlab (SphereVol _ _) = STR ''cu''"

text \<open>Division by zero: the organ would raise (the schema is skipped and
the turn abstains); the kernel declines. The recogniser already enforces the
organ's own guards (a unit-price count above one), so these fire only on
shapes the organ never reaches.\<close>
fun wdecline :: "wp \<Rightarrow> bool" where
    "wdecline (UnitPrice _ n) \<longleftrightarrow> n = 0"
  | "wdecline (PercentOfTotal a b) \<longleftrightarrow> max a b = 0"
  | "wdecline (MotionSpeed _ _ t u) \<longleftrightarrow> t * scale u = 0"
  | "wdecline _ \<longleftrightarrow> False"


section \<open>Rounding and the %g layout\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

text \<open>The decimal machinery (pow10, round_at, round_sig, render_dec and
their proofs) is lane G's (src/extract/quantity/Quantity.thy), restated here
for this session.\<close>

definition pow10 :: "int \<Rightarrow> real" where
  "pow10 k = (if 0 \<le> k then 10 ^ nat k else inverse (10 ^ nat (- k)))"

lemma pow10_pos: "0 < pow10 k"
  by (simp add: pow10_def)

definition dec_val :: "int \<times> int \<Rightarrow> real" where
  "dec_val d = (case d of (m, e) \<Rightarrow> of_int m * pow10 e)"

definition round_at :: "real \<Rightarrow> int \<Rightarrow> int \<times> int" where
  "round_at x e = (\<lfloor>x / pow10 e + 1 / 2\<rfloor>, e)"

lemma round_at_error: "\<bar>dec_val (round_at x e) - x\<bar> \<le> pow10 e / 2"
proof -
  define p where "p = pow10 e"
  have p: "0 < p" by (simp add: p_def pow10_pos)
  define y where "y = x / p"
  have x: "x = y * p" using p by (simp add: y_def)
  have lo: "of_int \<lfloor>y + 1 / 2\<rfloor> \<le> y + 1 / 2" by (rule of_int_floor_le)
  have hi: "y + 1 / 2 < of_int \<lfloor>y + 1 / 2\<rfloor> + 1" by (rule real_of_int_floor_add_one_gt)
  have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> \<le> 1 / 2" using lo hi by linarith
  then have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> * p \<le> 1 / 2 * p" using p by (intro mult_right_mono) auto
  then have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> * p - y * p\<bar> \<le> p / 2"
    using p by (simp add: abs_mult left_diff_distrib[symmetric])
  then show ?thesis by (simp add: dec_val_def round_at_def p_def[symmetric] y_def[symmetric] x[symmetric])
qed

text \<open>Tie behaviour, stated: an exact decimal tie rounds up (towards plus
infinity). The organ rounds a binary float with Python's @{text round}
(banker's on the double), so an exact tie can print the other neighbour
(@{text "0.125"} dollars prints @{text "$0.12"}); that is a float artefact
and is not modelled.\<close>
theorem round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"
proof -
  have "x / pow10 e + 1 / 2 = of_int (n + 1)" using assms by simp
  then show ?thesis by (simp add: round_at_def)
qed

fun exp_up :: "real \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> int \<Rightarrow> int" where
  "exp_up B x 0 e = e"
| "exp_up B x (Suc n) e = (if B * pow10 e \<le> x then exp_up B x n (e + 1) else e)"

fun exp_down :: "real \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> int \<Rightarrow> int" where
  "exp_down L x 0 e = e"
| "exp_down L x (Suc n) e = (if x < L * pow10 e then exp_down L x n (e - 1) else e)"

definition sig_exp :: "nat \<Rightarrow> real \<Rightarrow> int" where
  "sig_exp p x = exp_down (10 ^ (p - 1)) \<bar>x\<bar> 400 (exp_up (10 ^ p) \<bar>x\<bar> 400 0)"

definition round_sig :: "nat \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "round_sig p x = (if x = 0 then Some (0, 0) else
     let e = sig_exp p x in if 10 ^ (p - 1) * pow10 e \<le> \<bar>x\<bar> then Some (round_at x e) else None)"

theorem round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
proof (cases "x = 0")
  case True
  then have "d = (0, 0)" using assms by (simp add: round_sig_def)
  then show ?thesis using True by (simp add: dec_val_def)
next
  case False
  define e where "e = sig_exp p x"
  have chk: "10 ^ (p - 1) * pow10 e \<le> \<bar>x\<bar>" and dd: "d = round_at x e"
    using assms False by (simp_all add: round_sig_def Let_def e_def split: if_splits)
  have r: "\<bar>dec_val d - x\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have "(10 ^ (p - 1) * pow10 e) / (2 * 10 ^ (p - 1)) \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
    using chk by (intro divide_right_mono) auto
  moreover have "(10 ^ (p - 1) * pow10 e) / (2 * 10 ^ (p - 1)) = pow10 e / 2" by simp
  ultimately show ?thesis using r by linarith
qed

text \<open>The organ's @{text "round(v, nd)"}: round to @{text nd} decimal
places, ties up (towards plus infinity), as an exact rational.\<close>
definition round_dec :: "nat \<Rightarrow> rat \<Rightarrow> rat" where
  "round_dec n v = (let d = of_nat (10 ^ n) in of_int \<lfloor>v * d + 1 / 2\<rfloor> / d)"

lemma round_dec_error: "\<bar>round_dec n v - v\<bar> \<le> 1 / (2 * 10 ^ n)"
proof -
  define d :: rat where "d = of_nat (10 ^ n)"
  have dpos: "0 < d" by (simp add: d_def)
  have lo: "of_int \<lfloor>v * d + 1 / 2\<rfloor> \<le> v * d + 1 / 2" by (rule of_int_floor_le)
  have hi: "v * d + 1 / 2 < of_int (\<lfloor>v * d + 1 / 2\<rfloor> + 1)"
    using floor_less_iff[of "v * d + 1 / 2" "\<lfloor>v * d + 1 / 2\<rfloor> + 1"] by simp
  have abs: "\<bar>of_int \<lfloor>v * d + 1 / 2\<rfloor> - v * d\<bar> \<le> 1 / 2" using lo hi by linarith
  have dd: "d \<noteq> 0" using dpos by linarith
  have "\<bar>of_int \<lfloor>v * d + 1 / 2\<rfloor> / d - v\<bar> = \<bar>of_int \<lfloor>v * d + 1 / 2\<rfloor> - v * d\<bar> / d"
  proof -
    have "of_int \<lfloor>v * d + 1 / 2\<rfloor> / d - v = (of_int \<lfloor>v * d + 1 / 2\<rfloor> - v * d) / d"
      by (simp add: diff_divide_distrib nonzero_mult_div_cancel_right dd)
    then show ?thesis by (simp add: abs_divide dpos)
  qed
  also have "\<dots> \<le> (1 / 2) / d" using abs dpos by (rule divide_right_mono)
  finally have "\<bar>round_dec n v - v\<bar> \<le> (1 / 2) / d"
    by (simp add: round_dec_def Let_def d_def)
  moreover have "(1 / 2) / d = 1 / (2 * 10 ^ n)" by (simp add: d_def field_simps)
  ultimately show ?thesis by simp
qed

text \<open>The organ's printed value: "%g" % round(v, 6) for plain
numbers and "%g" % round(v, 4) for percents -- first rounded to that
many DECIMAL places, then to six SIGNIFICANT digits.\<close>
definition stated6 :: "rat \<Rightarrow> (int \<times> int) option" where
  "stated6 v = round_sig 6 (rl (round_dec 6 v))"

definition stated4 :: "rat \<Rightarrow> (int \<times> int) option" where
  "stated4 v = round_sig 6 (rl (round_dec 4 v))"

lemma rl_round_dec_bound: "\<bar>rl (round_dec n v) - rl v\<bar> \<le> 1 / (2 * 10 ^ n)"
proof -
  define k :: nat where "k = 10 ^ n"
  define d :: real where "d = of_nat k"
  have dpos: "(0::real) < d" by (simp add: d_def)
  have kd: "of_nat k = d" by (simp add: d_def)
  have conv: "of_rat (v * of_nat k + 1 / 2) = rl v * d + 1 / 2"
    by (simp add: of_rat_add of_rat_mult of_rat_divide kd)
  have fr: "\<lfloor>v * of_nat k + 1 / 2\<rfloor> = \<lfloor>rl v * d + 1 / 2\<rfloor>"
    unfolding conv[symmetric] by simp
  have "rl (round_dec n v) = of_rat (of_int \<lfloor>v * of_nat k + 1 / 2\<rfloor> / of_nat k)"
    by (simp add: round_dec_def Let_def k_def)
  also have "\<dots> = of_int \<lfloor>rl v * d + 1 / 2\<rfloor> / d"
    by (simp add: of_rat_divide of_rat_of_int_eq fr kd)
  finally have eq: "rl (round_dec n v) = of_int \<lfloor>rl v * d + 1 / 2\<rfloor> / d" .
  have lo: "of_int \<lfloor>rl v * d + 1 / 2\<rfloor> \<le> rl v * d + 1 / 2" by (rule of_int_floor_le)
  have hi: "rl v * d + 1 / 2 < of_int (\<lfloor>rl v * d + 1 / 2\<rfloor> + 1)"
    using floor_less_iff[of "rl v * d + 1 / 2" "\<lfloor>rl v * d + 1 / 2\<rfloor> + 1"] by simp
  have abs: "\<bar>of_int \<lfloor>rl v * d + 1 / 2\<rfloor> - rl v * d\<bar> \<le> 1 / 2" using lo hi by linarith
  have dd: "d \<noteq> 0" using dpos by linarith
  have "\<bar>of_int \<lfloor>rl v * d + 1 / 2\<rfloor> / d - rl v\<bar> = \<bar>of_int \<lfloor>rl v * d + 1 / 2\<rfloor> - rl v * d\<bar> / d"
  proof -
    have "of_int \<lfloor>rl v * d + 1 / 2\<rfloor> / d - rl v = (of_int \<lfloor>rl v * d + 1 / 2\<rfloor> - rl v * d) / d"
      by (simp add: diff_divide_distrib nonzero_mult_div_cancel_right dd)
    then show ?thesis by (simp add: abs_divide dpos)
  qed
  also have "\<dots> \<le> (1 / 2) / d" using abs dpos by (rule divide_right_mono)
  finally have "\<bar>rl (round_dec n v) - rl v\<bar> \<le> (1 / 2) / d" unfolding eq .
  moreover have "(1 / 2) / d = 1 / (2 * 10 ^ n)" by (simp add: d_def k_def field_simps)
  ultimately show ?thesis by simp
qed

theorem stated6_sound:
  assumes "stated6 v = Some d"
  shows "\<bar>dec_val d - rl v\<bar> \<le> \<bar>rl v\<bar> / 200000 + 1 / 1000000"
proof -
  have n5: "(2::real) * 10 ^ 5 = 200000" and n6: "(2::real) * 10 ^ 6 = 2000000"
    by (simp_all add: eval_nat_numeral)
  have b: "\<bar>dec_val d - rl (round_dec 6 v)\<bar> \<le> \<bar>rl (round_dec 6 v)\<bar> / 200000"
    using round_sig_sound[of 6 "rl (round_dec 6 v)" d] assms
    by (simp add: stated6_def n5[unfolded eval_nat_numeral] eval_nat_numeral)
  have e: "\<bar>rl (round_dec 6 v) - rl v\<bar> \<le> 1 / 2000000"
    using rl_round_dec_bound[of 6 v] by (simp add: n6[unfolded eval_nat_numeral] eval_nat_numeral)
  have "\<bar>rl (round_dec 6 v)\<bar> \<le> \<bar>rl v\<bar> + 1 / 2000000" using e by linarith
  then have "\<bar>rl (round_dec 6 v)\<bar> / 200000 \<le> (\<bar>rl v\<bar> + 1 / 2000000) / 200000"
    by (intro divide_right_mono) auto
  moreover have "\<bar>dec_val d - rl v\<bar> \<le> \<bar>dec_val d - rl (round_dec 6 v)\<bar> + \<bar>rl (round_dec 6 v) - rl v\<bar>"
    by arith
  ultimately show ?thesis using b e by linarith
qed

theorem stated4_sound:
  assumes "stated4 v = Some d"
  shows "\<bar>dec_val d - rl v\<bar> \<le> \<bar>rl v\<bar> / 200000 + 1 / 10000"
proof -
  have n5: "(2::real) * 10 ^ 5 = 200000" and n4: "(2::real) * 10 ^ 4 = 20000"
    by (simp_all add: eval_nat_numeral)
  have b: "\<bar>dec_val d - rl (round_dec 4 v)\<bar> \<le> \<bar>rl (round_dec 4 v)\<bar> / 200000"
    using round_sig_sound[of 6 "rl (round_dec 4 v)" d] assms
    by (simp add: stated4_def n5[unfolded eval_nat_numeral] eval_nat_numeral)
  have e: "\<bar>rl (round_dec 4 v) - rl v\<bar> \<le> 1 / 20000"
    using rl_round_dec_bound[of 4 v] by (simp add: n4[unfolded eval_nat_numeral] eval_nat_numeral)
  have "\<bar>rl (round_dec 4 v)\<bar> \<le> \<bar>rl v\<bar> + 1 / 20000" using e by linarith
  then have "\<bar>rl (round_dec 4 v)\<bar> / 200000 \<le> (\<bar>rl v\<bar> + 1 / 20000) / 200000"
    by (intro divide_right_mono) auto
  moreover have "\<bar>dec_val d - rl v\<bar> \<le> \<bar>dec_val d - rl (round_dec 4 v)\<bar> + \<bar>rl (round_dec 4 v) - rl v\<bar>"
    by arith
  ultimately show ?thesis using b e by linarith
qed


section \<open>Rendering (ASCII)\<close>

fun digits :: "nat \<Rightarrow> nat list" where
  "digits n = (if n < 10 then [n] else digits (n div 10) @ [n mod 10])"

definition digit_lit :: "nat \<Rightarrow> String.literal" where
  "digit_lit d = (if d = 0 then STR ''0'' else if d = 1 then STR ''1'' else if d = 2 then STR ''2''
    else if d = 3 then STR ''3'' else if d = 4 then STR ''4'' else if d = 5 then STR ''5''
    else if d = 6 then STR ''6'' else if d = 7 then STR ''7'' else if d = 8 then STR ''8''
    else STR ''9'')"

definition lit :: "nat list \<Rightarrow> String.literal" where
  "lit ds = foldr (\<lambda>d s. digit_lit d + s) ds (STR '''')"

definition strip_zeros :: "nat list \<Rightarrow> nat list" where
  "strip_zeros ds = rev (dropWhile (\<lambda>d. d = 0) (rev ds))"

definition pad2 :: "nat list \<Rightarrow> nat list" where
  "pad2 ds = (if length ds < 2 then 0 # ds else ds)"

text \<open>Python's @{text "%.pg"} layout for a decimal @{text "m * 10^e"}.\<close>
definition render_dec :: "nat \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_dec p d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>); k = int (length ds); x = e + k - 1 in
     if x < -4 \<or> int p \<le> x then
       (let fr = strip_zeros (tl ds) in
        sg + lit [hd ds] + (if fr = [] then STR '''' else STR ''.'' + lit fr) + STR ''e''
          + (if x < 0 then STR ''-'' else STR ''+'') + lit (pad2 (digits (nat \<bar>x\<bar>))))
     else if 0 \<le> e then sg + lit (ds @ replicate (nat e) 0)
     else
       (let p = nat (- e);
            ip = (if p < length ds then take (length ds - p) ds else [0]);
            fr = strip_zeros (if p < length ds then drop (length ds - p) ds
                              else replicate (p - length ds) 0 @ ds)
        in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr)))"

definition show_int :: "int \<Rightarrow> String.literal" where
  "show_int i = (if i < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>i\<bar>))"

definition is_int :: "rat \<Rightarrow> bool" where
  "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

text \<open>%g of an exact rational, as the organ prints inputs in its
steps (no decimal-places rounding first).\<close>
definition g6r :: "rat \<Rightarrow> String.literal" where
  "g6r v = (case round_sig 6 (rl v) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"

text \<open>Comma-grouped integers, as Python's @{text "{:,}"} layout.\<close>
definition pad3 :: "nat \<Rightarrow> nat list" where
  "pad3 n = replicate (3 - length (digits n)) 0 @ digits n"

fun commas :: "nat \<Rightarrow> String.literal" where
  "commas n = (if n < 1000 then lit (digits n)
     else commas (n div 1000) + STR '','' + lit (pad3 (n mod 1000)))"

definition pad2d :: "nat \<Rightarrow> String.literal" where
  "pad2d n = lit (pad2 (digits n))"

text \<open>The organ's money layout: whole dollars without decimals, otherwise
two decimals (@{text "{:,.2f}"}), on the already-rounded value.\<close>
definition money_str :: "rat \<Rightarrow> String.literal" where
  "money_str v = (let c = \<lfloor>v * 100 + 1 / 2\<rfloor> in
     (if v < 0 then STR ''-'' else STR '''') +
     (if is_int v then commas (nat \<bar>fst (quotient_of v)\<bar>)
      else commas (nat (\<bar>c\<bar> div 100)) + STR ''.'' + pad2d (nat (\<bar>c\<bar> mod 100))))"


section \<open>Fold w490's pluralisation of the value's unit\<close>

text \<open>The head pluralises the first "number unit" of a word-problem reply
(fold w490): "12600 second" becomes "12600 seconds", unless the number is
exactly one; "inch" and "foot" are irregular. The units it pluralises are its
own list. The kernel applies the rule at the value, which IS the first
"number unit" pair of the reply whenever the value's unit is one of those
27 spelled-out units (every core-panel and probe shape: the printed value
comes first). The residual gap: when the value's unit is an abbreviation
("min", "sec", "kg", ...) the head skips the value and pluralises the first
number-unit pair in the STEPS instead ("5 hours" inside "5 hour = 5 x ..."),
which this kernel does not reproduce; the values are unaffected.\<close>

definition plural_units :: "String.literal list" where
  "plural_units = [
    STR ''millimeter'', STR ''centimeter'', STR ''meter'', STR ''kilometer'',
    STR ''inch'', STR ''foot'', STR ''yard'', STR ''mile'',
    STR ''milligram'', STR ''gram'', STR ''kilogram'', STR ''ounce'',
    STR ''pound'', STR ''ton'', STR ''milliliter'', STR ''liter'', STR ''litre'',
    STR ''cup'', STR ''pint'', STR ''quart'', STR ''gallon'',
    STR ''second'', STR ''minute'', STR ''hour'', STR ''day'', STR ''week'', STR ''year'']"

definition plural_of :: "String.literal \<Rightarrow> String.literal" where
  "plural_of u = (if u = STR ''inch'' then STR ''inches'' else if u = STR ''foot'' then STR ''feet''
     else u + STR ''s'')"

definition plural_label :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "plural_label v l = (let cs = String.explode l;
       i = length (takeWhile (\<lambda>c. c \<noteq> CHR ''/'') cs)
   in if String.implode (take i cs) \<in> set plural_units
      then (if v = 1 then l else plural_of (String.implode (take i cs))) + String.implode (drop i cs)
      else l)"

definition unit_suffix :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "unit_suffix v l = (if l = STR ''sq'' then STR '' square units''
     else if l = STR ''cu'' then STR '' cubic units''
     else if l = STR '''' then STR ''''
     else STR '' '' + plural_label v l)"


section \<open>The reply\<close>

text \<open>The organ's rounding: an explicit "round to the nearest ..." wins,
otherwise money is rounded to two decimals.\<close>
definition rounded :: "nat option \<Rightarrow> wp \<Rightarrow> rat" where
  "rounded rnd r = (case rnd of
     Some n \<Rightarrow> round_dec n (wvalue r)
   | None \<Rightarrow> if wlab r = STR ''$'' then round_dec 2 (wvalue r) else wvalue r)"

definition num_str :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "num_str v l = (if l = STR ''$'' then money_str v
     else if l = STR ''%'' then (case stated4 v of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')
     else (case stated6 v of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?''))"

definition fmt_value :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "fmt_value v l = (if l = STR ''$'' then STR ''$'' + money_str v
     else if l = STR ''%'' then num_str v l + STR ''%''
     else num_str v l + unit_suffix v l)"

text \<open>The organ's steps, one string per schema (its %g of the
values it read).\<close>
fun steps_text :: "wp \<Rightarrow> String.literal" where
    "steps_text (PercentOf _ r w) = g6r r + STR ''% of '' + g6r w"
  | "steps_text (Convert x a b) = g6r x + STR '' '' + uname a + STR '' = '' + g6r x
     + STR '' x '' + g6r (scale a) + STR '' / '' + g6r (scale b) + STR '' '' + uname b"
  | "steps_text (SimpleInterest P r n) = STR ''I = P x r x t = '' + g6r P + STR '' x '' + g6r r
     + STR ''% x '' + g6r n + STR '' years''"
  | "steps_text (UnitPrice p n) = STR ''each = total / count = '' + g6r p + STR '' / '' + g6r n"
  | "steps_text (TotalCost n p) = STR ''total = count x price each = '' + g6r n + STR '' x '' + g6r p"
  | "steps_text (SaleOff c d) = STR ''sale = original - discount = '' + g6r c + STR '' - '' + g6r d"
  | "steps_text (SalePct c r) = STR ''sale = original x (1 - rate) = '' + g6r c + STR '' x (1 - ''
     + g6r r + STR ''%)''"
  | "steps_text (PercentOfTotal a b) = STR ''percent = part / whole x 100 = '' + g6r (min a b)
     + STR '' / '' + g6r (max a b) + STR '' x 100''"
  | "steps_text (MotionDist r t u _) = STR ''d = r x t = '' + g6r r + STR '' x ''
     + g6r (t * scale u) + STR '' h''"
  | "steps_text (MotionSpeed x u t u') = STR ''r = d / t = '' + g6r x + STR '' / ''
     + g6r (t * scale u') + STR '' h''"
  | "steps_text (RectArea l w) = STR ''A = L x W = '' + g6r l + STR '' x '' + g6r w"
  | "steps_text (RectPerim l w) = STR ''P = 2(L + W) = 2('' + g6r l + STR '' + '' + g6r w + STR '')''"
  | "steps_text (CircleArea r _) = STR ''A = pi r^2, r = '' + g6r r"
  | "steps_text (CircleCirc r _) = STR ''C = 2 pi r, r = '' + g6r r"
  | "steps_text (ConeVol r h _) = STR ''V = (1/3) pi r^2 h, r = '' + g6r r + STR '', h = '' + g6r h"
  | "steps_text (CylVol r h _) = STR ''V = pi r^2 h, r = '' + g6r r + STR '', h = '' + g6r h"
  | "steps_text (SphereVol r _) = STR ''V = (4/3) pi r^3, r = '' + g6r r"

text \<open>Fold w488's reply body.\<close>
definition body_text :: "nat option \<Rightarrow> wp \<Rightarrow> String.literal" where
  "body_text rnd r = STR ''[ev:derived] '' + fmt_value (rounded rnd r) (wlab r) + STR ''. Read as ''
     + read_name (skind_of r) + STR '': '' + steps_text r
     + STR ''. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"

text \<open>The whole reply. An empty request list is the organ abstaining with
no schema reading the problem; two or more is two schemas reading it
differently, which the organ also abstains on.\<close>
datatype wreply = WReply (answered :: bool) (schema :: String.literal)
  (response :: String.literal) (stated :: "String.literal option")

definition reply_one :: "nat option \<Rightarrow> wp \<Rightarrow> wreply" where
  "reply_one rnd r = (if wdecline r then WReply False (STR ''impossible'') (STR '''') None
     else WReply True (sname (skind_of r)) (body_text rnd r)
       (Some (num_str (rounded rnd r) (wlab r))))"

fun reply_of :: "nat option \<times> wp list \<Rightarrow> wreply" where
    "reply_of (rnd, []) = WReply False (STR '''') (STR '''') None"
  | "reply_of (rnd, [r]) = reply_one rnd r"
  | "reply_of (rnd, r1 # r2 # _) = WReply False (STR ''ambiguous'') (STR '''') None"


section \<open>What the kernel proves\<close>

text \<open>The exactly-one-schema rule: the kernel answers a problem exactly
when one schema read it and its formula does not divide by zero.\<close>
theorem reply_answered_iff:
  "answered (reply_of (rnd, rs)) \<longleftrightarrow> (\<exists>r. rs = [r] \<and> \<not> wdecline r)"
  by (cases rs) (auto simp: reply_one_def split: if_splits)

text \<open>Every value satisfies its schema's equation.\<close>
theorem percent_of_value: "wvalue (PercentOf m r w) = r / 100 * w" by simp

theorem convert_value: "wvalue (Convert x a b) * scale b = x * scale a" by simp

theorem simple_interest_value: "wvalue (SimpleInterest P r n) = P * r / 100 * n" by simp

theorem unit_price_value: "n \<noteq> 0 \<Longrightarrow> wvalue (UnitPrice p n) * n = p" by simp

theorem total_cost_value: "wvalue (TotalCost n p) = n * p" by simp

theorem sale_off_value: "wvalue (SaleOff a b) = a - b" by simp

theorem sale_pct_value: "wvalue (SalePct a r) = a * (1 - r / 100)" by simp

theorem percent_of_total_value:
  "max a b \<noteq> 0 \<Longrightarrow> wvalue (PercentOfTotal a b) * max a b = min a b * 100" by simp

theorem motion_dist_value: "wvalue (MotionDist r t u l) = r * (t * scale u)" by simp

theorem motion_speed_value:
  "t * scale u' \<noteq> 0 \<Longrightarrow> wvalue (MotionSpeed x u t u') * (t * scale u') = x * scale u" by simp

theorem rect_area_value: "wvalue (RectArea l w) = l * w" by simp

theorem rect_perim_value: "wvalue (RectPerim l w) = 2 * (l + w)" by simp

theorem circle_area_value: "wvalue (CircleArea r p) = pi_of p * r * r" by simp

theorem circle_circ_value: "wvalue (CircleCirc r p) = 2 * pi_of p * r" by simp

theorem cone_vol_value: "wvalue (ConeVol r h p) * 3 = pi_of p * r * r * h" by simp

theorem cyl_vol_value: "wvalue (CylVol r h p) = pi_of p * r * r * h" by simp

theorem sphere_vol_value: "wvalue (SphereVol r p) * 3 = 4 * pi_of p * r ^ 3" by simp

text \<open>The printed number is a rounding of the schema's exact value: the
reply prints @{term "stated6 (rounded rnd r)"} (or @{term "stated4"} for
percents), which @{thm stated6_sound} and @{thm stated4_sound} bound against
the value printed. Two things tie the printed number to the formula: the
rounding never moves the value by more than half a unit in the last printed
place, and an exact tie rounds up (@{thm round_tie_up}).\<close>
theorem printed_rounds_value:
  assumes "wlab r \<noteq> STR ''$''" and "wlab r \<noteq> STR ''%''"
  shows "num_str (rounded rnd r) (wlab r) =
     (case stated6 (rounded rnd r) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"
  by (simp add: num_str_def assms)

theorem printed_rounds_value_percent:
  assumes "wlab r = STR ''%''"
  shows "num_str (rounded rnd r) (wlab r) =
     (case stated4 (rounded rnd r) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"
  by (simp add: num_str_def assms)

text \<open>The response is fold w488's body over that printed value and the
schema's steps, with fold w490's pluralisation.\<close>
theorem response_template:
  assumes "\<not> wdecline r"
  shows "response (reply_of (rnd, [r])) = body_text rnd r"
  using assms by (simp add: reply_one_def split: if_splits)

end
