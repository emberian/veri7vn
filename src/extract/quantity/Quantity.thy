theory Quantity
  imports "Veri7vn_Quantity_Base.Quantity_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>
  Six shipped Oracle7 specialists (densities, units, units-v3, springs, fluids,
  fuels: upstream/root/specialists/*/organ_*.py) as one verified HOL kernel
  over a shared typed quantity: an amount is a rational number with a unit,
  every unit has a dimension and an exact SI factor, and every formula reads
  its amounts in SI. A typed request (what the question asks, its numbers
  already read off by the untrusted recognizer) goes to an outcome: an exact
  rational value, a decimal enclosure (only the spring period and frequency,
  which need a square root and pi), a yes/no verdict, or a decline.

  The tables (unit factors, unit names, densities, fuel values) are HOL
  constants transcribed from the organs; tables_check.py parses the organ
  files and this file and fails on any difference.

  The numeric core (rounding, enclosures, number layout) is not in this
  file: it is imported once from the shared session Veri7vn_Commons
  (src/extract/commons/Commons_Num.thy), which this lane's own copies
  originally seeded. Only the family policy constant prec = 53 stays here.
\<close>

section \<open>Units and dimensions\<close>

datatype dim = D_length | D_mass | D_volume | D_area | D_speed | D_time | D_pressure
  | D_energy | D_power | D_data

datatype qunit =
    U_metre | U_kilometre | U_centimetre | U_millimetre | U_inch | U_foot
  | U_yard | U_mile | U_nautical_mile | U_kilogram | U_gram | U_milligram
  | U_pound | U_ounce | U_tonne | U_stone | U_litre | U_millilitre
  | U_gallon_us | U_quart_us | U_pint_us | U_cup_us | U_fluid_ounce_us | U_cubic_metre
  | U_square_metre | U_square_foot | U_acre | U_hectare | U_square_kilometre | U_square_mile
  | U_metre_per_second | U_kilometre_per_hour | U_mile_per_hour | U_knot | U_second | U_minute
  | U_hour | U_day | U_week | U_pascal | U_kilopascal | U_bar
  | U_atmosphere | U_psi | U_mmhg | U_joule | U_kilojoule | U_calorie
  | U_kilocalorie | U_kilowatt_hour | U_btu | U_watt | U_kilowatt | U_horsepower
  | U_byte | U_kilobyte | U_megabyte | U_gigabyte | U_terabyte | U_kibibyte
  | U_mebibyte | U_gibibyte | U_cubic_centimetre | U_cubic_foot | U_megajoule | U_gigajoule
  | U_megawatt_hour | U_watt_hour | U_millijoule | U_milliwatt_hour

fun dim_of :: "qunit \<Rightarrow> dim" where
    "dim_of U_metre = D_length"
| "dim_of U_kilometre = D_length"
| "dim_of U_centimetre = D_length"
| "dim_of U_millimetre = D_length"
| "dim_of U_inch = D_length"
| "dim_of U_foot = D_length"
| "dim_of U_yard = D_length"
| "dim_of U_mile = D_length"
| "dim_of U_nautical_mile = D_length"
| "dim_of U_kilogram = D_mass"
| "dim_of U_gram = D_mass"
| "dim_of U_milligram = D_mass"
| "dim_of U_pound = D_mass"
| "dim_of U_ounce = D_mass"
| "dim_of U_tonne = D_mass"
| "dim_of U_stone = D_mass"
| "dim_of U_litre = D_volume"
| "dim_of U_millilitre = D_volume"
| "dim_of U_gallon_us = D_volume"
| "dim_of U_quart_us = D_volume"
| "dim_of U_pint_us = D_volume"
| "dim_of U_cup_us = D_volume"
| "dim_of U_fluid_ounce_us = D_volume"
| "dim_of U_cubic_metre = D_volume"
| "dim_of U_square_metre = D_area"
| "dim_of U_square_foot = D_area"
| "dim_of U_acre = D_area"
| "dim_of U_hectare = D_area"
| "dim_of U_square_kilometre = D_area"
| "dim_of U_square_mile = D_area"
| "dim_of U_metre_per_second = D_speed"
| "dim_of U_kilometre_per_hour = D_speed"
| "dim_of U_mile_per_hour = D_speed"
| "dim_of U_knot = D_speed"
| "dim_of U_second = D_time"
| "dim_of U_minute = D_time"
| "dim_of U_hour = D_time"
| "dim_of U_day = D_time"
| "dim_of U_week = D_time"
| "dim_of U_pascal = D_pressure"
| "dim_of U_kilopascal = D_pressure"
| "dim_of U_bar = D_pressure"
| "dim_of U_atmosphere = D_pressure"
| "dim_of U_psi = D_pressure"
| "dim_of U_mmhg = D_pressure"
| "dim_of U_joule = D_energy"
| "dim_of U_kilojoule = D_energy"
| "dim_of U_calorie = D_energy"
| "dim_of U_kilocalorie = D_energy"
| "dim_of U_kilowatt_hour = D_energy"
| "dim_of U_btu = D_energy"
| "dim_of U_watt = D_power"
| "dim_of U_kilowatt = D_power"
| "dim_of U_horsepower = D_power"
| "dim_of U_byte = D_data"
| "dim_of U_kilobyte = D_data"
| "dim_of U_megabyte = D_data"
| "dim_of U_gigabyte = D_data"
| "dim_of U_terabyte = D_data"
| "dim_of U_kibibyte = D_data"
| "dim_of U_mebibyte = D_data"
| "dim_of U_gibibyte = D_data"
| "dim_of U_cubic_centimetre = D_volume"
| "dim_of U_cubic_foot = D_volume"
| "dim_of U_megajoule = D_energy"
| "dim_of U_gigajoule = D_energy"
| "dim_of U_megawatt_hour = D_energy"

| "dim_of U_watt_hour = D_energy"

| "dim_of U_millijoule = D_energy"

| "dim_of U_milliwatt_hour = D_energy"

text \<open>Exact SI factor of each unit (the organ's exact rationals).\<close>
fun scale :: "qunit \<Rightarrow> rat" where
    "scale U_metre = 1"
| "scale U_kilometre = 1000"
| "scale U_centimetre = 1 / 100"
| "scale U_millimetre = 1 / 1000"
| "scale U_inch = 127 / 5000"
| "scale U_foot = 381 / 1250"
| "scale U_yard = 1143 / 1250"
| "scale U_mile = 201168 / 125"
| "scale U_nautical_mile = 1852"
| "scale U_kilogram = 1"
| "scale U_gram = 1 / 1000"
| "scale U_milligram = 1 / 1000000"
| "scale U_pound = 45359237 / 100000000"
| "scale U_ounce = 45359237 / 1600000000"
| "scale U_tonne = 1000"
| "scale U_stone = 317514659 / 50000000"
| "scale U_litre = 1 / 1000"
| "scale U_millilitre = 1 / 1000000"
| "scale U_gallon_us = 473176473 / 125000000000"
| "scale U_quart_us = 473176473 / 500000000000"
| "scale U_pint_us = 473176473 / 1000000000000"
| "scale U_cup_us = 473176473 / 2000000000000"
| "scale U_fluid_ounce_us = 473176473 / 16000000000000"
| "scale U_cubic_metre = 1"
| "scale U_square_metre = 1"
| "scale U_square_foot = 145161 / 1562500"
| "scale U_acre = 316160658 / 78125"
| "scale U_hectare = 10000"
| "scale U_square_kilometre = 1000000"
| "scale U_square_mile = 40468564224 / 15625"
| "scale U_metre_per_second = 1"
| "scale U_kilometre_per_hour = 5 / 18"
| "scale U_mile_per_hour = 1397 / 3125"
| "scale U_knot = 463 / 900"
| "scale U_second = 1"
| "scale U_minute = 60"
| "scale U_hour = 3600"
| "scale U_day = 86400"
| "scale U_week = 604800"
| "scale U_pascal = 1"
| "scale U_kilopascal = 1000"
| "scale U_bar = 100000"
| "scale U_atmosphere = 101325"
| "scale U_psi = 8896443230521 / 1290320000"
| "scale U_mmhg = 26664477483 / 200000000"
| "scale U_joule = 1"
| "scale U_kilojoule = 1000"
| "scale U_calorie = 523 / 125"
| "scale U_kilocalorie = 4184"
| "scale U_kilowatt_hour = 3600000"
| "scale U_btu = 52752792631 / 50000000"
| "scale U_watt = 1"
| "scale U_kilowatt = 1000"
| "scale U_horsepower = 37284993579113511 / 50000000000000"
| "scale U_byte = 1"
| "scale U_kilobyte = 1000"
| "scale U_megabyte = 1000000"
| "scale U_gigabyte = 1000000000"
| "scale U_terabyte = 1000000000000"
| "scale U_kibibyte = 1024"
| "scale U_mebibyte = 1048576"
| "scale U_gibibyte = 1073741824"
| "scale U_cubic_centimetre = 1 / 1000000"
| "scale U_cubic_foot = 55306341 / 1953125000"
| "scale U_megajoule = 1000000"
| "scale U_gigajoule = 1000000000"
| "scale U_megawatt_hour = 3600000000"

| "scale U_watt_hour = 3600"

| "scale U_millijoule = 1 / 1000"

| "scale U_milliwatt_hour = 18 / 5"

fun unit_label :: "qunit \<Rightarrow> String.literal" where
    "unit_label U_metre = STR ''m''"
| "unit_label U_kilometre = STR ''km''"
| "unit_label U_centimetre = STR ''cm''"
| "unit_label U_millimetre = STR ''mm''"
| "unit_label U_inch = STR ''in''"
| "unit_label U_foot = STR ''ft''"
| "unit_label U_yard = STR ''yd''"
| "unit_label U_mile = STR ''mi''"
| "unit_label U_nautical_mile = STR ''nmi''"
| "unit_label U_kilogram = STR ''kg''"
| "unit_label U_gram = STR ''g''"
| "unit_label U_milligram = STR ''mg''"
| "unit_label U_pound = STR ''lb''"
| "unit_label U_ounce = STR ''oz''"
| "unit_label U_tonne = STR ''tonnes''"
| "unit_label U_stone = STR ''st''"
| "unit_label U_litre = STR ''L''"
| "unit_label U_millilitre = STR ''mL''"
| "unit_label U_gallon_us = STR ''US gallons''"
| "unit_label U_quart_us = STR ''qt''"
| "unit_label U_pint_us = STR ''pt''"
| "unit_label U_cup_us = STR ''cups''"
| "unit_label U_fluid_ounce_us = STR ''fl oz''"
| "unit_label U_cubic_metre = STR ''m3''"
| "unit_label U_square_metre = STR ''m2''"
| "unit_label U_square_foot = STR ''ft2''"
| "unit_label U_acre = STR ''acres''"
| "unit_label U_hectare = STR ''ha''"
| "unit_label U_square_kilometre = STR ''km2''"
| "unit_label U_square_mile = STR ''mi2''"
| "unit_label U_metre_per_second = STR ''m/s''"
| "unit_label U_kilometre_per_hour = STR ''km/h''"
| "unit_label U_mile_per_hour = STR ''mph''"
| "unit_label U_knot = STR ''knots''"
| "unit_label U_second = STR ''s''"
| "unit_label U_minute = STR ''min''"
| "unit_label U_hour = STR ''h''"
| "unit_label U_day = STR ''days''"
| "unit_label U_week = STR ''weeks''"
| "unit_label U_pascal = STR ''Pa''"
| "unit_label U_kilopascal = STR ''kPa''"
| "unit_label U_bar = STR ''bar''"
| "unit_label U_atmosphere = STR ''atm''"
| "unit_label U_psi = STR ''psi''"
| "unit_label U_mmhg = STR ''mmHg''"
| "unit_label U_joule = STR ''J''"
| "unit_label U_kilojoule = STR ''kJ''"
| "unit_label U_calorie = STR ''cal''"
| "unit_label U_kilocalorie = STR ''kcal''"
| "unit_label U_kilowatt_hour = STR ''kWh''"
| "unit_label U_btu = STR ''BTU''"
| "unit_label U_watt = STR ''W''"
| "unit_label U_kilowatt = STR ''kW''"
| "unit_label U_horsepower = STR ''hp''"
| "unit_label U_byte = STR ''bytes''"
| "unit_label U_kilobyte = STR ''kB''"
| "unit_label U_megabyte = STR ''MB''"
| "unit_label U_gigabyte = STR ''GB''"
| "unit_label U_terabyte = STR ''TB''"
| "unit_label U_kibibyte = STR ''KiB''"
| "unit_label U_mebibyte = STR ''MiB''"
| "unit_label U_gibibyte = STR ''GiB''"
| "unit_label U_cubic_centimetre = STR ''cm3''"
| "unit_label U_cubic_foot = STR ''ft3''"
| "unit_label U_megajoule = STR ''MJ''"
| "unit_label U_gigajoule = STR ''GJ''"
| "unit_label U_megawatt_hour = STR ''MWh''"

| "unit_label U_watt_hour = STR ''Wh''"

| "unit_label U_millijoule = STR ''mJ''"

| "unit_label U_milliwatt_hour = STR ''mWh''"

lemma scale_pos [simp]: "0 < scale u"
  by (cases u) simp_all

lemma scale_nz [simp]: "scale u \<noteq> 0"
  using scale_pos[of u] by linarith

fun dim_name :: "dim \<Rightarrow> String.literal" where
  "dim_name D_length = STR ''length''" | "dim_name D_mass = STR ''mass''"
| "dim_name D_volume = STR ''volume''" | "dim_name D_area = STR ''area''"
| "dim_name D_speed = STR ''speed''" | "dim_name D_time = STR ''time''"
| "dim_name D_pressure = STR ''pressure''" | "dim_name D_energy = STR ''energy''"
| "dim_name D_power = STR ''power''" | "dim_name D_data = STR ''data''"

text \<open>Temperature scales are affine: a point on a scale is
@{text "x * tscale u + toffset u"} kelvin. A temperature difference scales
without the offset (@{text tdelta}).\<close>
datatype tunit = T_C | T_F | T_K

fun tscale :: "tunit \<Rightarrow> rat" where
  "tscale T_C = 1" | "tscale T_F = 5 / 9" | "tscale T_K = 1"

fun toffset :: "tunit \<Rightarrow> rat" where
  "toffset T_C = 27315 / 100" | "toffset T_F = 45967 / 180" | "toffset T_K = 0"

lemma tscale_pos [simp]: "0 < tscale u"
  by (cases u) simp_all

lemma tscale_nz [simp]: "tscale u \<noteq> 0"
  using tscale_pos[of u] by linarith

definition kelvin :: "tunit \<Rightarrow> rat \<Rightarrow> rat" where
  "kelvin u x = x * tscale u + toffset u"

definition tdelta :: "tunit \<Rightarrow> tunit \<Rightarrow> rat \<Rightarrow> rat" where
  "tdelta a b x = x * tscale a / tscale b"

fun tlabel :: "tunit \<Rightarrow> String.literal" where
  "tlabel T_C = STR ''degrees C''" | "tlabel T_F = STR ''degrees F''" | "tlabel T_K = STR ''K''"

text \<open>What a unit word in a conversion question denotes: a linear unit or a
temperature scale.\<close>
datatype uref = Lin qunit | Tmp tunit

text \<open>The organ's unit names (organ_units_v1.U and TEMP, ASCII entries) and what they denote.\<close>
definition unit_names :: "(String.literal \<times> uref) list" where
  "unit_names = [
    (STR ''m'', Lin U_metre),
    (STR ''meter'', Lin U_metre),
    (STR ''meters'', Lin U_metre),
    (STR ''metre'', Lin U_metre),
    (STR ''metres'', Lin U_metre),
    (STR ''km'', Lin U_kilometre),
    (STR ''kilometer'', Lin U_kilometre),
    (STR ''kilometers'', Lin U_kilometre),
    (STR ''kilometre'', Lin U_kilometre),
    (STR ''kilometres'', Lin U_kilometre),
    (STR ''cm'', Lin U_centimetre),
    (STR ''centimeter'', Lin U_centimetre),
    (STR ''centimeters'', Lin U_centimetre),
    (STR ''centimetre'', Lin U_centimetre),
    (STR ''centimetres'', Lin U_centimetre),
    (STR ''mm'', Lin U_millimetre),
    (STR ''millimeter'', Lin U_millimetre),
    (STR ''millimeters'', Lin U_millimetre),
    (STR ''millimetre'', Lin U_millimetre),
    (STR ''millimetres'', Lin U_millimetre),
    (STR ''in'', Lin U_inch),
    (STR ''inch'', Lin U_inch),
    (STR ''inches'', Lin U_inch),
    (STR ''ft'', Lin U_foot),
    (STR ''foot'', Lin U_foot),
    (STR ''feet'', Lin U_foot),
    (STR ''yd'', Lin U_yard),
    (STR ''yard'', Lin U_yard),
    (STR ''yards'', Lin U_yard),
    (STR ''mi'', Lin U_mile),
    (STR ''mile'', Lin U_mile),
    (STR ''miles'', Lin U_mile),
    (STR ''nmi'', Lin U_nautical_mile),
    (STR ''nautical mile'', Lin U_nautical_mile),
    (STR ''nautical miles'', Lin U_nautical_mile),
    (STR ''kg'', Lin U_kilogram),
    (STR ''kilogram'', Lin U_kilogram),
    (STR ''kilograms'', Lin U_kilogram),
    (STR ''g'', Lin U_gram),
    (STR ''gram'', Lin U_gram),
    (STR ''grams'', Lin U_gram),
    (STR ''mg'', Lin U_milligram),
    (STR ''milligram'', Lin U_milligram),
    (STR ''milligrams'', Lin U_milligram),
    (STR ''lb'', Lin U_pound),
    (STR ''lbs'', Lin U_pound),
    (STR ''pound'', Lin U_pound),
    (STR ''pounds'', Lin U_pound),
    (STR ''oz'', Lin U_ounce),
    (STR ''ounce'', Lin U_ounce),
    (STR ''ounces'', Lin U_ounce),
    (STR ''t'', Lin U_tonne),
    (STR ''tonne'', Lin U_tonne),
    (STR ''tonnes'', Lin U_tonne),
    (STR ''metric ton'', Lin U_tonne),
    (STR ''metric tons'', Lin U_tonne),
    (STR ''st'', Lin U_stone),
    (STR ''stone'', Lin U_stone),
    (STR ''stones'', Lin U_stone),
    (STR ''l'', Lin U_litre),
    (STR ''liter'', Lin U_litre),
    (STR ''liters'', Lin U_litre),
    (STR ''litre'', Lin U_litre),
    (STR ''litres'', Lin U_litre),
    (STR ''ml'', Lin U_millilitre),
    (STR ''milliliter'', Lin U_millilitre),
    (STR ''milliliters'', Lin U_millilitre),
    (STR ''millilitre'', Lin U_millilitre),
    (STR ''millilitres'', Lin U_millilitre),
    (STR ''gal'', Lin U_gallon_us),
    (STR ''gallon'', Lin U_gallon_us),
    (STR ''gallons'', Lin U_gallon_us),
    (STR ''us gallon'', Lin U_gallon_us),
    (STR ''us gallons'', Lin U_gallon_us),
    (STR ''qt'', Lin U_quart_us),
    (STR ''quart'', Lin U_quart_us),
    (STR ''quarts'', Lin U_quart_us),
    (STR ''pt'', Lin U_pint_us),
    (STR ''pint'', Lin U_pint_us),
    (STR ''pints'', Lin U_pint_us),
    (STR ''cup'', Lin U_cup_us),
    (STR ''cups'', Lin U_cup_us),
    (STR ''fl oz'', Lin U_fluid_ounce_us),
    (STR ''fluid ounce'', Lin U_fluid_ounce_us),
    (STR ''fluid ounces'', Lin U_fluid_ounce_us),
    (STR ''m3'', Lin U_cubic_metre),
    (STR ''cubic meter'', Lin U_cubic_metre),
    (STR ''cubic meters'', Lin U_cubic_metre),
    (STR ''cubic metre'', Lin U_cubic_metre),
    (STR ''cubic metres'', Lin U_cubic_metre),
    (STR ''m2'', Lin U_square_metre),
    (STR ''square meter'', Lin U_square_metre),
    (STR ''square meters'', Lin U_square_metre),
    (STR ''square metre'', Lin U_square_metre),
    (STR ''square metres'', Lin U_square_metre),
    (STR ''ft2'', Lin U_square_foot),
    (STR ''square foot'', Lin U_square_foot),
    (STR ''square feet'', Lin U_square_foot),
    (STR ''acre'', Lin U_acre),
    (STR ''acres'', Lin U_acre),
    (STR ''hectare'', Lin U_hectare),
    (STR ''hectares'', Lin U_hectare),
    (STR ''ha'', Lin U_hectare),
    (STR ''km2'', Lin U_square_kilometre),
    (STR ''square kilometer'', Lin U_square_kilometre),
    (STR ''square kilometers'', Lin U_square_kilometre),
    (STR ''square kilometre'', Lin U_square_kilometre),
    (STR ''square kilometres'', Lin U_square_kilometre),
    (STR ''mi2'', Lin U_square_mile),
    (STR ''square mile'', Lin U_square_mile),
    (STR ''square miles'', Lin U_square_mile),
    (STR ''m/s'', Lin U_metre_per_second),
    (STR ''meters per second'', Lin U_metre_per_second),
    (STR ''metres per second'', Lin U_metre_per_second),
    (STR ''km/h'', Lin U_kilometre_per_hour),
    (STR ''kph'', Lin U_kilometre_per_hour),
    (STR ''kilometers per hour'', Lin U_kilometre_per_hour),
    (STR ''kilometres per hour'', Lin U_kilometre_per_hour),
    (STR ''mph'', Lin U_mile_per_hour),
    (STR ''miles per hour'', Lin U_mile_per_hour),
    (STR ''knot'', Lin U_knot),
    (STR ''knots'', Lin U_knot),
    (STR ''kn'', Lin U_knot),
    (STR ''s'', Lin U_second),
    (STR ''sec'', Lin U_second),
    (STR ''second'', Lin U_second),
    (STR ''seconds'', Lin U_second),
    (STR ''min'', Lin U_minute),
    (STR ''minute'', Lin U_minute),
    (STR ''minutes'', Lin U_minute),
    (STR ''h'', Lin U_hour),
    (STR ''hr'', Lin U_hour),
    (STR ''hour'', Lin U_hour),
    (STR ''hours'', Lin U_hour),
    (STR ''day'', Lin U_day),
    (STR ''days'', Lin U_day),
    (STR ''week'', Lin U_week),
    (STR ''weeks'', Lin U_week),
    (STR ''pa'', Lin U_pascal),
    (STR ''pascal'', Lin U_pascal),
    (STR ''pascals'', Lin U_pascal),
    (STR ''kpa'', Lin U_kilopascal),
    (STR ''kilopascal'', Lin U_kilopascal),
    (STR ''kilopascals'', Lin U_kilopascal),
    (STR ''bar'', Lin U_bar),
    (STR ''bars'', Lin U_bar),
    (STR ''atm'', Lin U_atmosphere),
    (STR ''atmosphere'', Lin U_atmosphere),
    (STR ''atmospheres'', Lin U_atmosphere),
    (STR ''psi'', Lin U_psi),
    (STR ''mmhg'', Lin U_mmhg),
    (STR ''j'', Lin U_joule),
    (STR ''joule'', Lin U_joule),
    (STR ''joules'', Lin U_joule),
    (STR ''kj'', Lin U_kilojoule),
    (STR ''kilojoule'', Lin U_kilojoule),
    (STR ''kilojoules'', Lin U_kilojoule),
    (STR ''cal'', Lin U_calorie),
    (STR ''calorie'', Lin U_calorie),
    (STR ''calories'', Lin U_calorie),
    (STR ''kcal'', Lin U_kilocalorie),
    (STR ''kilocalorie'', Lin U_kilocalorie),
    (STR ''kilocalories'', Lin U_kilocalorie),
    (STR ''kwh'', Lin U_kilowatt_hour),
    (STR ''kilowatt hour'', Lin U_kilowatt_hour),
    (STR ''kilowatt hours'', Lin U_kilowatt_hour),
    (STR ''kilowatt-hour'', Lin U_kilowatt_hour),
    (STR ''kilowatt-hours'', Lin U_kilowatt_hour),
    (STR ''Wh'', Lin U_watt_hour),
    (STR ''watt hour'', Lin U_watt_hour),
    (STR ''watt hours'', Lin U_watt_hour),
    (STR ''watt-hour'', Lin U_watt_hour),
    (STR ''watt-hours'', Lin U_watt_hour),
    (STR ''mJ'', Lin U_millijoule),
    (STR ''millijoule'', Lin U_millijoule),
    (STR ''millijoules'', Lin U_millijoule),
    (STR ''mWh'', Lin U_milliwatt_hour),
    (STR ''milliwatt hour'', Lin U_milliwatt_hour),
    (STR ''milliwatt hours'', Lin U_milliwatt_hour),
    (STR ''milliwatt-hour'', Lin U_milliwatt_hour),
    (STR ''milliwatt-hours'', Lin U_milliwatt_hour),
    (STR ''MJ'', Lin U_megajoule),
    (STR ''megajoule'', Lin U_megajoule),
    (STR ''megajoules'', Lin U_megajoule),
    (STR ''GJ'', Lin U_gigajoule),
    (STR ''gigajoule'', Lin U_gigajoule),
    (STR ''gigajoules'', Lin U_gigajoule),
    (STR ''MWh'', Lin U_megawatt_hour),
    (STR ''megawatt hour'', Lin U_megawatt_hour),
    (STR ''megawatt hours'', Lin U_megawatt_hour),
    (STR ''megawatt-hour'', Lin U_megawatt_hour),
    (STR ''megawatt-hours'', Lin U_megawatt_hour),
    (STR ''btu'', Lin U_btu),
    (STR ''w'', Lin U_watt),
    (STR ''watt'', Lin U_watt),
    (STR ''watts'', Lin U_watt),
    (STR ''kw'', Lin U_kilowatt),
    (STR ''kilowatt'', Lin U_kilowatt),
    (STR ''kilowatts'', Lin U_kilowatt),
    (STR ''hp'', Lin U_horsepower),
    (STR ''horsepower'', Lin U_horsepower),
    (STR ''byte'', Lin U_byte),
    (STR ''bytes'', Lin U_byte),
    (STR ''kb'', Lin U_kilobyte),
    (STR ''kilobyte'', Lin U_kilobyte),
    (STR ''kilobytes'', Lin U_kilobyte),
    (STR ''mb'', Lin U_megabyte),
    (STR ''megabyte'', Lin U_megabyte),
    (STR ''megabytes'', Lin U_megabyte),
    (STR ''gb'', Lin U_gigabyte),
    (STR ''gigabyte'', Lin U_gigabyte),
    (STR ''gigabytes'', Lin U_gigabyte),
    (STR ''tb'', Lin U_terabyte),
    (STR ''terabyte'', Lin U_terabyte),
    (STR ''terabytes'', Lin U_terabyte),
    (STR ''kib'', Lin U_kibibyte),
    (STR ''kibibyte'', Lin U_kibibyte),
    (STR ''kibibytes'', Lin U_kibibyte),
    (STR ''mib'', Lin U_mebibyte),
    (STR ''mebibyte'', Lin U_mebibyte),
    (STR ''mebibytes'', Lin U_mebibyte),
    (STR ''gib'', Lin U_gibibyte),
    (STR ''gibibyte'', Lin U_gibibyte),
    (STR ''gibibytes'', Lin U_gibibyte),
    (STR ''c'', Tmp T_C),
    (STR ''celsius'', Tmp T_C),
    (STR ''degrees celsius'', Tmp T_C),
    (STR ''f'', Tmp T_F),
    (STR ''fahrenheit'', Tmp T_F),
    (STR ''degrees fahrenheit'', Tmp T_F),
    (STR ''k'', Tmp T_K),
    (STR ''kelvin'', Tmp T_K),
    (STR ''kelvins'', Tmp T_K)]"

definition lookup_unit :: "String.literal \<Rightarrow> uref option" where
  "lookup_unit s = map_option snd (find (\<lambda>p. fst p = s) unit_names)"

definition uref_label :: "uref \<Rightarrow> String.literal" where
  "uref_label r = (case r of Lin u \<Rightarrow> unit_label u | Tmp t \<Rightarrow> tlabel t)"

text \<open>The units each organ reads amounts in, in the order of the organ's own
unit lists (densities VOL_UNITS and MASS_UNITS, springs DISP and MASS/GRAMS,
fluids VOLUME, fuels MASS and ENERGY). The recognizer reads the i-th unit
pattern of an organ list as the i-th unit here; tables_check.py checks that
each organ factor is this unit's SI factor.\<close>
definition dens_vol_units :: "qunit list" where
  "dens_vol_units = [U_cubic_metre, U_litre, U_millilitre, U_cubic_centimetre, U_gallon_us, U_cubic_foot]"
definition dens_mass_units :: "qunit list" where
  "dens_mass_units = [U_kilogram, U_gram, U_tonne, U_pound]"
definition spring_disp_units :: "qunit list" where
  "spring_disp_units = [U_metre, U_centimetre, U_millimetre]"
definition spring_mass_units :: "qunit list" where
  "spring_mass_units = [U_kilogram, U_gram]"
definition fluid_vol_units :: "qunit list" where
  "fluid_vol_units = [U_cubic_metre, U_litre, U_cubic_centimetre]"
definition fuel_mass_units :: "qunit list" where
  "fuel_mass_units = [U_tonne, U_kilogram, U_gram]"
definition fuel_energy_units :: "qunit list" where
  "fuel_energy_units = [U_kilowatt_hour, U_megawatt_hour, U_megajoule, U_gigajoule]"

type_synonym qty = "rat \<times> qunit"

text \<open>An amount in SI units.\<close>
definition siq :: "qty \<Rightarrow> rat" where
  "siq q = fst q * scale (snd q)"


section \<open>Materials, densities and fuels\<close>

datatype material = M_water | M_seawater | M_ice | M_aluminium | M_steel | M_iron | M_copper
  | M_gold | M_silver | M_lead | M_concrete | M_glass | M_petrol | M_diesel | M_ethanol
  | M_mercury | M_air | M_granite | M_brass | M_titanium | M_platinum | M_zinc | M_nickel
  | M_milk | M_honey | M_uranium | M_tungsten | M_magnesium | M_olive_oil

text \<open>Typical densities near 20 C in kg/m3 (organ_densities_v1.MATERIALS; the
fluids organ uses the same values, checked by tables_check.py).\<close>
fun density :: "material \<Rightarrow> rat" where
  "density M_water = 1000" | "density M_seawater = 1025" | "density M_ice = 917"
| "density M_aluminium = 2700" | "density M_steel = 7850" | "density M_iron = 7874"
| "density M_copper = 8933" | "density M_gold = 19282" | "density M_silver = 10501"
| "density M_lead = 11342" | "density M_concrete = 2400" | "density M_glass = 2500"
| "density M_petrol = 745" | "density M_diesel = 832" | "density M_ethanol = 789"
| "density M_mercury = 135336 / 10" | "density M_air = 1204 / 1000" | "density M_granite = 2700"
| "density M_brass = 8500" | "density M_titanium = 4500" | "density M_platinum = 21460"
| "density M_zinc = 7134" | "density M_nickel = 8912" | "density M_milk = 1030"
| "density M_honey = 1420" | "density M_uranium = 18950" | "density M_tungsten = 19300"
| "density M_magnesium = 1740" | "density M_olive_oil = 911"

lemma density_pos [simp]: "0 < density m"
  by (cases m) simp_all

lemma density_nz [simp]: "density m \<noteq> 0"
  using density_pos[of m] by linarith

fun mat_name :: "material \<Rightarrow> String.literal" where
  "mat_name M_water = STR ''water''" | "mat_name M_seawater = STR ''seawater''"
| "mat_name M_ice = STR ''ice''" | "mat_name M_aluminium = STR ''aluminium''"
| "mat_name M_steel = STR ''steel''" | "mat_name M_iron = STR ''iron''"
| "mat_name M_copper = STR ''copper''" | "mat_name M_gold = STR ''gold''"
| "mat_name M_silver = STR ''silver''" | "mat_name M_lead = STR ''lead''"
| "mat_name M_concrete = STR ''concrete''" | "mat_name M_glass = STR ''glass''"
| "mat_name M_petrol = STR ''petrol''" | "mat_name M_diesel = STR ''diesel''"
| "mat_name M_ethanol = STR ''ethanol''" | "mat_name M_mercury = STR ''mercury''"
| "mat_name M_air = STR ''air''" | "mat_name M_granite = STR ''granite''"
| "mat_name M_brass = STR ''brass''" | "mat_name M_titanium = STR ''titanium''"
| "mat_name M_platinum = STR ''platinum''" | "mat_name M_zinc = STR ''zinc''"
| "mat_name M_nickel = STR ''nickel''" | "mat_name M_milk = STR ''milk''"
| "mat_name M_honey = STR ''honey''" | "mat_name M_uranium = STR ''uranium''"
| "mat_name M_tungsten = STR ''tungsten''" | "mat_name M_magnesium = STR ''magnesium''"
| "mat_name M_olive_oil = STR ''olive oil''"

text \<open>The organ's material order (dictionary order of MATERIALS), which the
recognizer's material patterns follow.\<close>
definition material_order :: "material list" where
  "material_order = [M_water, M_seawater, M_ice, M_aluminium, M_steel, M_iron, M_copper,
     M_gold, M_silver, M_lead, M_concrete, M_glass, M_petrol, M_diesel, M_ethanol,
     M_mercury, M_air, M_granite, M_brass, M_titanium, M_platinum, M_zinc, M_nickel,
     M_milk, M_honey, M_uranium, M_tungsten, M_magnesium, M_olive_oil]"

text \<open>Pure elements: their bare density belongs to the chemistry specialist
(organ_densities_v1.ELEMENTS), so the densities organ does not take it.\<close>
definition elements :: "material list" where
  "elements = [M_aluminium, M_iron, M_copper, M_gold, M_silver, M_lead, M_mercury, M_titanium,
     M_platinum, M_zinc, M_nickel, M_uranium, M_tungsten, M_magnesium]"

text \<open>The fluids organ's fluids and solids (organ_fluids_v1.FLUIDS and SOLIDS,
in order) as materials of the shared table.\<close>
definition fluid_order :: "material list" where
  "fluid_order = [M_water, M_seawater, M_mercury, M_petrol, M_diesel, M_ethanol, M_olive_oil,
     M_honey, M_milk]"
definition solid_order :: "material list" where
  "solid_order = [M_ice, M_aluminium, M_steel, M_concrete, M_glass, M_granite, M_iron, M_copper,
     M_gold, M_lead, M_brass]"

fun fluid_name :: "material \<Rightarrow> String.literal" where
  "fluid_name M_water = STR ''fresh water''"
| "fluid_name M_seawater = STR ''sea water''"
| "fluid_name m = mat_name m"

datatype fuel = F_petrol | F_diesel | F_jet_fuel | F_lpg | F_natural_gas | F_coal | F_lignite
  | F_anthracite | F_wood | F_charcoal

text \<open>IPCC 2006 default net calorific values in MJ/kg and CO2 emission factors
in kg CO2 per TJ (organ_fuels_v1.FUELS).\<close>
fun ncv :: "fuel \<Rightarrow> rat" where
  "ncv F_petrol = 443 / 10" | "ncv F_diesel = 43" | "ncv F_jet_fuel = 441 / 10"
| "ncv F_lpg = 473 / 10" | "ncv F_natural_gas = 48" | "ncv F_coal = 258 / 10"
| "ncv F_lignite = 119 / 10" | "ncv F_anthracite = 267 / 10" | "ncv F_wood = 156 / 10"
| "ncv F_charcoal = 295 / 10"

fun co2_factor :: "fuel \<Rightarrow> rat" where
  "co2_factor F_petrol = 69300" | "co2_factor F_diesel = 74100" | "co2_factor F_jet_fuel = 71500"
| "co2_factor F_lpg = 63100" | "co2_factor F_natural_gas = 56100" | "co2_factor F_coal = 94600"
| "co2_factor F_lignite = 101000" | "co2_factor F_anthracite = 98300" | "co2_factor F_wood = 112000"
| "co2_factor F_charcoal = 112000"

fun biogenic :: "fuel \<Rightarrow> bool" where
  "biogenic F_wood = True" | "biogenic F_charcoal = True" | "biogenic _ = False"

fun fuel_name :: "fuel \<Rightarrow> String.literal" where
  "fuel_name F_petrol = STR ''petrol''" | "fuel_name F_diesel = STR ''diesel''"
| "fuel_name F_jet_fuel = STR ''jet fuel''" | "fuel_name F_lpg = STR ''LPG''"
| "fuel_name F_natural_gas = STR ''natural gas''" | "fuel_name F_coal = STR ''coal''"
| "fuel_name F_lignite = STR ''lignite''" | "fuel_name F_anthracite = STR ''anthracite''"
| "fuel_name F_wood = STR ''wood''" | "fuel_name F_charcoal = STR ''charcoal''"

definition fuel_order :: "fuel list" where
  "fuel_order = [F_petrol, F_diesel, F_jet_fuel, F_lpg, F_natural_gas, F_coal, F_lignite,
     F_anthracite, F_wood, F_charcoal]"

lemma ncv_pos [simp]: "0 < ncv f"
  by (cases f) simp_all

lemma ncv_nz [simp]: "ncv f \<noteq> 0"
  using ncv_pos[of f] by linarith

text \<open>Standard gravity (m/s2) and standard atmosphere (Pa), exact.\<close>
definition g0 :: rat where "g0 = 980665 / 100000"
definition p0 :: rat where "p0 = 101325"


section \<open>Requests and outcomes\<close>

text \<open>Explicit conditions are inputs to an incompressible hydrostatic model.
Density units remain a mass/volume pair, so their dimensions and conversion are
checked here. Gravity is a magnitude; surface pressure is absolute.\<close>
datatype density_input = ReferenceDensity material | SuppliedDensity rat qunit qunit
datatype gravity_unit = G_mps2 | G_fps2 | G_standard
datatype efficiency_unit = E_fraction | E_percent
datatype model_condition = C_reference_state | C_moisture | C_unread_input | C_other_operation

fun input_density :: "density_input \<Rightarrow> rat" where
  "input_density (ReferenceDensity m) = density m"
| "input_density (SuppliedDensity x m v) = x * scale m / scale v"

fun density_dims :: "density_input \<Rightarrow> bool" where
  "density_dims (ReferenceDensity m) = True"
| "density_dims (SuppliedDensity x m v) = (dim_of m = D_mass \<and> dim_of v = D_volume)"

fun gravity_scale :: "gravity_unit \<Rightarrow> rat" where
  "gravity_scale G_mps2 = 1"
| "gravity_scale G_fps2 = scale U_foot"
| "gravity_scale G_standard = g0"

definition gravity_si :: "rat \<times> gravity_unit \<Rightarrow> rat" where
  "gravity_si g = fst g * gravity_scale (snd g)"

fun efficiency :: "rat \<times> efficiency_unit \<Rightarrow> rat" where
  "efficiency (x, E_fraction) = x"
| "efficiency (x, E_percent) = x / 100"

datatype request =
    Density material
  | MassOf material "qty option" qunit
  | VolumeOf material "qty option" qunit
  | Floats material material
  | Convert rat uref uref
  | ConvertDelta rat uref uref
  | SpringForce "rat option" "qty option"
  | SpringExtension "rat option" "rat option"
  | SpringConstant "rat option" "qty option"
  | SpringEnergy "rat option" "qty option"
  | SpringPeriod "rat option" "qty option"
  | SpringFrequency "rat option" "qty option"
  | PressureGauge material "qty option"
  | PressureAbs material "qty option"
  | Buoyant material "qty option"
  | Submerged material material
  | FuelEnergy fuel "qty option" qunit
  | FuelCO2 fuel "qty option"
  | FuelMassNeeded fuel qty
  | FuelNCV fuel
  | Hydrostatic density_input "qty option" "rat \<times> gravity_unit" qty bool
  | FuelUsefulEnergy fuel "qty option" qunit "(rat \<times> efficiency_unit) option"
  | FuelUsefulMass fuel qty "(rat \<times> efficiency_unit) option"
  | UnsupportedCondition model_condition

text \<open>In @{text MassOf} the amount is a volume and the unit the answer unit;
in @{text VolumeOf} the amount is a mass. Springs: stiffness in N/m and force
in N as plain numbers, stretch a length, the hung mass a mass. Fluids: a depth
(length) or a displaced volume. Fuels: a burnt mass (with the answer unit for
energy), or an energy to release.\<close>

datatype need = N_amount | N_k_stretch | N_k_stretch_or_compression | N_force_stretch | N_k_force
  | N_mass_k | N_depth | N_volume | N_fuel_mass | N_efficiency

datatype reason = R_below_absolute_zero | R_nonpositive_stiffness | R_nonpositive_stretch
  | R_nonpositive_mass | R_hydrostatic_inputs | R_fuel_inputs | R_efficiency | R_inverse_efficiency

datatype decline = Underspecified need | Mismatch | Impossible reason | Undecided | Imprecise | UnsupportedModel model_condition

datatype kind = K_density | K_mass | K_volume | K_floats | K_convert | K_temperature | K_temperature_difference | K_force
  | K_extension | K_spring_constant | K_elastic_energy | K_period | K_frequency
  | K_pressure_gauge | K_pressure_abs | K_buoyant_force | K_submerged_fraction | K_sinks
  | K_energy | K_co2 | K_mass_needed | K_ncv | K_useful_energy | K_useful_mass_needed | K_model_condition

text \<open>An exact rational value, a decimal @{text "(m, e)"} meaning
@{text "m * 10^e"} enclosing a real value, a yes/no verdict, or a decline.\<close>
datatype outcome = Exact kind rat | Approx kind "int \<times> int" | Verdict kind bool | Decline decline

fun kind_of :: "request \<Rightarrow> kind" where
  "kind_of (Density _) = K_density"
| "kind_of (MassOf _ _ _) = K_mass"
| "kind_of (VolumeOf _ _ _) = K_volume"
| "kind_of (Floats _ _) = K_floats"
| "kind_of (Convert _ (Tmp _) (Tmp _)) = K_temperature"
| "kind_of (Convert _ _ _) = K_convert"
| "kind_of (ConvertDelta _ _ _) = K_temperature_difference"
| "kind_of (SpringForce _ _) = K_force"
| "kind_of (SpringExtension _ _) = K_extension"
| "kind_of (SpringConstant _ _) = K_spring_constant"
| "kind_of (SpringEnergy _ _) = K_elastic_energy"
| "kind_of (SpringPeriod _ _) = K_period"
| "kind_of (SpringFrequency _ _) = K_frequency"
| "kind_of (PressureGauge _ _) = K_pressure_gauge"
| "kind_of (PressureAbs _ _) = K_pressure_abs"
| "kind_of (Buoyant _ _) = K_buoyant_force"
| "kind_of (Submerged _ _) = K_submerged_fraction"
| "kind_of (FuelEnergy _ _ _) = K_energy"
| "kind_of (FuelCO2 _ _) = K_co2"
| "kind_of (FuelMassNeeded _ _) = K_mass_needed"
| "kind_of (FuelNCV _) = K_ncv"
| "kind_of (Hydrostatic _ _ _ _ absolute) = (if absolute then K_pressure_abs else K_pressure_gauge)"
| "kind_of (FuelUsefulEnergy _ _ _ _) = K_useful_energy"
| "kind_of (FuelUsefulMass _ _ _) = K_useful_mass_needed"
| "kind_of (UnsupportedCondition _) = K_model_condition"


section \<open>Declines\<close>

text \<open>Underspecified: an amount the formula needs is absent (the organs'
need branches and the densities organ's no-amount decline).\<close>
fun missing :: "request \<Rightarrow> need option" where
  "missing (MassOf m V u) = (if V = None then Some N_amount else None)"
| "missing (VolumeOf m M u) = (if M = None then Some N_amount else None)"
| "missing (SpringForce k x) = (if k = None \<or> x = None then Some N_k_stretch else None)"
| "missing (SpringExtension k f) = (if k = None \<or> f = None then Some N_k_force else None)"
| "missing (SpringConstant f x) = (if f = None \<or> x = None then Some N_force_stretch else None)"
| "missing (SpringEnergy k x) = (if k = None \<or> x = None then Some N_k_stretch_or_compression else None)"
| "missing (SpringPeriod k m) = (if k = None \<or> m = None then Some N_mass_k else None)"
| "missing (SpringFrequency k m) = (if k = None \<or> m = None then Some N_mass_k else None)"
| "missing (PressureGauge f h) = (if h = None then Some N_depth else None)"
| "missing (PressureAbs f h) = (if h = None then Some N_depth else None)"
| "missing (Buoyant f v) = (if v = None then Some N_volume else None)"
| "missing (FuelEnergy f m u) = (if m = None then Some N_fuel_mass else None)"
| "missing (FuelCO2 f m) = (if m = None then Some N_fuel_mass else None)"
| "missing (Hydrostatic d h g p a) = (if h = None then Some N_depth else None)"
| "missing (FuelUsefulEnergy f m u e) = (if m = None then Some N_fuel_mass else if e = None then Some N_efficiency else None)"
| "missing (FuelUsefulMass f q e) = (if e = None then Some N_efficiency else None)"
| "missing _ = None"

fun opt_dim :: "qty option \<Rightarrow> dim \<Rightarrow> bool" where
  "opt_dim None d = True"
| "opt_dim (Some (x, u)) d = (dim_of u = d)"

text \<open>Mismatch: the units do not have the dimensions the formula needs. For a
conversion this is the units organ's mismatch decline (metres to kilograms,
or a temperature scale against a linear unit).\<close>
fun dims_ok :: "request \<Rightarrow> bool" where
  "dims_ok (MassOf m V u) \<longleftrightarrow> opt_dim V D_volume \<and> dim_of u = D_mass"
| "dims_ok (VolumeOf m M u) \<longleftrightarrow> opt_dim M D_mass \<and> dim_of u = D_volume"
| "dims_ok (Convert x (Lin a) (Lin b)) \<longleftrightarrow> dim_of a = dim_of b"
| "dims_ok (Convert x (Tmp a) (Tmp b)) \<longleftrightarrow> True"
| "dims_ok (Convert x _ _) \<longleftrightarrow> False"
| "dims_ok (ConvertDelta x (Tmp a) (Tmp b)) \<longleftrightarrow> True"
| "dims_ok (ConvertDelta x _ _) \<longleftrightarrow> False"
| "dims_ok (SpringForce k x) \<longleftrightarrow> opt_dim x D_length"
| "dims_ok (SpringConstant f x) \<longleftrightarrow> opt_dim x D_length"
| "dims_ok (SpringEnergy k x) \<longleftrightarrow> opt_dim x D_length"
| "dims_ok (SpringPeriod k m) \<longleftrightarrow> opt_dim m D_mass"
| "dims_ok (SpringFrequency k m) \<longleftrightarrow> opt_dim m D_mass"
| "dims_ok (PressureGauge f h) \<longleftrightarrow> opt_dim h D_length"
| "dims_ok (PressureAbs f h) \<longleftrightarrow> opt_dim h D_length"
| "dims_ok (Buoyant f v) \<longleftrightarrow> opt_dim v D_volume"
| "dims_ok (FuelEnergy f m u) \<longleftrightarrow> opt_dim m D_mass \<and> dim_of u = D_energy"
| "dims_ok (FuelCO2 f m) \<longleftrightarrow> opt_dim m D_mass"
| "dims_ok (FuelMassNeeded f e) \<longleftrightarrow> dim_of (snd e) = D_energy"
| "dims_ok (Hydrostatic d h g p a) \<longleftrightarrow> density_dims d \<and> opt_dim h D_length \<and> dim_of (snd p) = D_pressure"
| "dims_ok (FuelUsefulEnergy f m u e) \<longleftrightarrow> opt_dim m D_mass \<and> dim_of u = D_energy"
| "dims_ok (FuelUsefulMass f q e) \<longleftrightarrow> dim_of (snd q) = D_energy"
| "dims_ok _ \<longleftrightarrow> True"

text \<open>Impossible: a temperature below absolute zero (the units organ's
decline), and the inputs for which a spring formula divides by zero or takes
the root of a negative number (the organ would raise an exception there).\<close>
fun impossible :: "request \<Rightarrow> bool" where
  "impossible (Convert x (Tmp a) (Tmp b)) \<longleftrightarrow> x * tscale a + toffset a < 0"
| "impossible (SpringExtension (Some k) (Some f)) \<longleftrightarrow> k \<le> 0"
| "impossible (SpringConstant (Some f) (Some x)) \<longleftrightarrow> fst x * scale (snd x) \<le> 0"
| "impossible (SpringPeriod (Some k) (Some m)) \<longleftrightarrow> k \<le> 0 \<or> fst m * scale (snd m) \<le> 0"
| "impossible (SpringFrequency (Some k) (Some m)) \<longleftrightarrow> k \<le> 0 \<or> fst m * scale (snd m) \<le> 0"
| "impossible (Hydrostatic d (Some h) g p a) \<longleftrightarrow>
     input_density d \<le> 0 \<or> siq h < 0 \<or> gravity_si g < 0 \<or> siq p < 0"
| "impossible (FuelUsefulEnergy f (Some m) u (Some e)) \<longleftrightarrow>
     siq m < 0 \<or> efficiency e < 0 \<or> 1 < efficiency e"
| "impossible (FuelUsefulMass f q (Some e)) \<longleftrightarrow>
     siq q < 0 \<or> efficiency e \<le> 0 \<or> 1 < efficiency e"
| "impossible _ \<longleftrightarrow> False"

text \<open>The executable check, with the reason it reports.\<close>
fun reason_of :: "request \<Rightarrow> reason option" where
  "reason_of (Convert x (Tmp a) (Tmp b)) =
     (if kelvin a x < 0 then Some R_below_absolute_zero else None)"
| "reason_of (SpringExtension (Some k) (Some f)) =
     (if k \<le> 0 then Some R_nonpositive_stiffness else None)"
| "reason_of (SpringConstant (Some f) (Some x)) =
     (if siq x \<le> 0 then Some R_nonpositive_stretch else None)"
| "reason_of (SpringPeriod (Some k) (Some m)) =
     (if k \<le> 0 then Some R_nonpositive_stiffness else if siq m \<le> 0 then Some R_nonpositive_mass else None)"
| "reason_of (SpringFrequency (Some k) (Some m)) =
     (if k \<le> 0 then Some R_nonpositive_stiffness else if siq m \<le> 0 then Some R_nonpositive_mass else None)"
| "reason_of (Hydrostatic d (Some h) g p a) =
     (if input_density d \<le> 0 \<or> siq h < 0 \<or> gravity_si g < 0 \<or> siq p < 0 then Some R_hydrostatic_inputs else None)"
| "reason_of (FuelUsefulEnergy f (Some m) u (Some e)) =
     (if siq m < 0 then Some R_fuel_inputs else if efficiency e < 0 \<or> 1 < efficiency e then Some R_efficiency else None)"
| "reason_of (FuelUsefulMass f q (Some e)) =
     (if siq q < 0 then Some R_fuel_inputs else if efficiency e \<le> 0 \<or> 1 < efficiency e then Some R_inverse_efficiency else None)"
| "reason_of _ = None"

theorem reason_of_exact: "reason_of r \<noteq> None \<longleftrightarrow> impossible r"
  by (cases r rule: reason_of.cases) (auto simp: kelvin_def siq_def)

text \<open>Undecided: the densities organ does not call float or sink when the two
densities are within 2 percent of each other.\<close>
fun undecided :: "request \<Rightarrow> bool" where
  "undecided (Floats s f) \<longleftrightarrow> \<bar>density s - density f\<bar> * 50 < density f"
| "undecided _ \<longleftrightarrow> False"

fun unsupported_of :: "request \<Rightarrow> model_condition option" where
  "unsupported_of (UnsupportedCondition c) = Some c"
| "unsupported_of _ = None"

definition decline_of :: "request \<Rightarrow> decline option" where
  "decline_of r = (case missing r of
     Some w \<Rightarrow> Some (Underspecified w)
   | None \<Rightarrow> if \<not> dims_ok r then Some Mismatch else
       (case reason_of r of
          Some why \<Rightarrow> Some (Impossible why)
        | None \<Rightarrow> if undecided r then Some Undecided else
            (case unsupported_of r of Some c \<Rightarrow> Some (UnsupportedModel c) | None \<Rightarrow> None)))"


section \<open>Values\<close>

text \<open>The exact rational value of each rational kind, from SI amounts.\<close>
fun qval :: "request \<Rightarrow> rat" where
  "qval (Density m) = density m"
| "qval (MassOf m (Some V) u) = density m * siq V / scale u"
| "qval (VolumeOf m (Some M) u) = siq M / density m / scale u"
| "qval (Convert x (Lin a) (Lin b)) = x * scale a / scale b"
| "qval (Convert x (Tmp a) (Tmp b)) = (kelvin a x - toffset b) / tscale b"
| "qval (ConvertDelta x (Tmp a) (Tmp b)) = tdelta a b x"
| "qval (SpringForce (Some k) (Some x)) = k * siq x"
| "qval (SpringExtension (Some k) (Some f)) = f / k"
| "qval (SpringConstant (Some f) (Some x)) = f / siq x"
| "qval (SpringEnergy (Some k) (Some x)) = k * siq x ^ 2 / 2"
| "qval (PressureGauge f (Some h)) = density f * g0 * siq h"
| "qval (PressureAbs f (Some h)) = p0 + density f * g0 * siq h"
| "qval (Buoyant f (Some v)) = density f * g0 * siq v"
| "qval (Submerged s f) = density s / density f"
| "qval (FuelEnergy f (Some m) u) = siq m * ncv f * 1000000 / scale u"
| "qval (FuelCO2 f (Some m)) = siq m * ncv f * co2_factor f / 1000000"
| "qval (FuelMassNeeded f e) = siq e / 1000000 / ncv f"
| "qval (FuelNCV f) = ncv f"
| "qval (Hydrostatic d (Some h) g p a) =
     input_density d * gravity_si g * siq h + (if a then siq p else 0)"
| "qval (FuelUsefulEnergy f (Some m) u (Some e)) =
     efficiency e * siq m * ncv f * 1000000 / scale u"
| "qval (FuelUsefulMass f q (Some e)) = siq q / (efficiency e * ncv f * 1000000)"
| "qval _ = 0"


text \<open>The real-number model: the spring period and frequency with a real
square root and pi; every other kind is its exact rational value.\<close>
fun phys :: "request \<Rightarrow> real" where
  "phys (SpringPeriod (Some k) (Some m)) = 2 * pi * sqrt (rl (siq m) / rl k)"
| "phys (SpringFrequency (Some k) (Some m)) = inverse (2 * pi * sqrt (rl (siq m) / rl k))"
| "phys r = rl (qval r)"


section \<open>Executable enclosure of the period (as in lane D)\<close>

definition period_fa :: "rat \<Rightarrow> qty \<Rightarrow> floatarith" where
  "period_fa k m = floatarith.Mult (floatarith.Mult (I 2) floatarith.Pi)
     (floatarith.Sqrt (floatarith.Mult (Q (siq m)) (floatarith.Inverse (Q k))))"

lemma interp_period [simp]:
  "interpret_floatarith (period_fa k m) xs = 2 * pi * sqrt (rl (siq m) / rl k)"
  by (simp add: period_fa_def divide_inverse)

definition prec :: nat where "prec = 53"

definition approx_out :: "kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out k e = (case enclose prec e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out c e = Approx k d"
  shows "k = c \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
  using assms enclose_sound by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_exact [simp]: "approx_out c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_verdict [simp]: "approx_out c e \<noteq> Verdict k b"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decline: "approx_out c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)


section \<open>The kernel\<close>

fun answer_of :: "request \<Rightarrow> outcome" where
  "answer_of (Floats s f) = Verdict K_floats (density s < density f)"
| "answer_of (Submerged s f) =
     (if density s < density f then Exact K_submerged_fraction (density s / density f)
      else Verdict K_sinks False)"
| "answer_of (SpringPeriod (Some k) (Some m)) = approx_out K_period (period_fa k m)"
| "answer_of (SpringFrequency (Some k) (Some m)) =
     approx_out K_frequency (floatarith.Inverse (period_fa k m))"
| "answer_of r = Exact (kind_of r) (qval r)"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

lemma answer_decline: "answer_of r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r rule: answer_of.cases) (auto split: if_splits dest: approx_out_decline)

lemma answer_exact: "answer_of r = Exact k q \<Longrightarrow> k = kind_of r \<and> q = qval r"
  by (cases r rule: answer_of.cases) (auto split: if_splits)

lemma answer_approx:
  "answer_of r = Approx k d \<Longrightarrow> k = kind_of r \<and> \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
  by (cases r rule: answer_of.cases) (auto split: if_splits dest!: approx_out_sound)

lemma decline_none:
  "decline_of r = None \<Longrightarrow> missing r = None \<and> dims_ok r \<and> \<not> impossible r \<and> \<not> undecided r"
  using reason_of_exact[of r] by (auto simp: decline_of_def split: option.splits if_splits)

text \<open>Every exact value the kernel states is the request's value, and only
for requests that are fully specified, dimensionally right and possible.\<close>
theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None \<and> dims_ok r \<and> \<not> impossible r \<and> k = kind_of r \<and> q = qval r \<and> rl q = phys r"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Exact k q"
    using assms by (auto simp: kernel_def split: option.splits)
  have kq: "k = kind_of r \<and> q = qval r" by (rule answer_exact[OF a])
  have "phys r = rl (qval r)"
    using a by (cases r rule: answer_of.cases) (auto split: if_splits)
  then show ?thesis using decline_none[OF nd] kq by simp
qed

text \<open>Every decimal the kernel states for the spring period or frequency is
within one part in a thousand (plus @{text "10\<^sup>-\<^sup>9"}) of the real model.\<close>
theorem kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None \<and> dims_ok r \<and> \<not> impossible r \<and> k = kind_of r \<and>
         \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Approx k d"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using decline_none[OF nd] answer_approx[OF a] by simp
qed

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified w) \<longleftrightarrow> missing r = Some w"
  by (auto simp: kernel_def decline_of_def dest: answer_decline split: option.splits if_splits)

theorem kernel_mismatch:
  "kernel r = Decline Mismatch \<longleftrightarrow> missing r = None \<and> \<not> dims_ok r"
  by (auto simp: kernel_def decline_of_def dest: answer_decline split: option.splits if_splits)

theorem kernel_impossible:
  "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> dims_ok r \<and> impossible r"
proof -
  have "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> dims_ok r \<and> reason_of r \<noteq> None"
    by (auto simp: kernel_def decline_of_def dest: answer_decline split: option.splits if_splits)
  then show ?thesis using reason_of_exact by blast
qed

theorem kernel_undecided:
  "kernel r = Decline Undecided \<longleftrightarrow> missing r = None \<and> dims_ok r \<and> \<not> impossible r \<and> undecided r"
proof -
  have "kernel r = Decline Undecided \<longleftrightarrow> missing r = None \<and> dims_ok r \<and> reason_of r = None \<and> undecided r"
    by (auto simp: kernel_def decline_of_def dest: answer_decline split: option.splits if_splits)
  then show ?thesis using reason_of_exact by blast
qed

text \<open>A numerical decline (the period enclosure too wide)
only happens on requests that are fully specified and possible.\<close>
theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None \<and> dims_ok r \<and> \<not> impossible r \<and> \<not> undecided r"
proof -
  have "decline_of r = None"
    using assms by (auto simp: kernel_def decline_of_def split: option.splits if_splits)
  then show ?thesis by (rule decline_none)
qed


section \<open>What each kind means\<close>

subsection \<open>Units\<close>

theorem convert_exact:
  assumes "kernel (Convert x (Lin a) (Lin b)) = Exact k y"
  shows "k = K_convert \<and> dim_of a = dim_of b \<and> y * scale b = x * scale a"
  using kernel_exact_sound[OF assms] by (simp add: field_simps)

theorem convert_mismatch:
  "kernel (Convert x (Lin a) (Lin b)) = Decline Mismatch \<longleftrightarrow> dim_of a \<noteq> dim_of b"
  by (simp add: kernel_mismatch)

theorem convert_composes:
  assumes "kernel (Convert x (Lin a) (Lin b)) = Exact k y"
    and "kernel (Convert y (Lin b) (Lin c)) = Exact k' z"
  shows "kernel (Convert x (Lin a) (Lin c)) = Exact K_convert z"
proof -
  from convert_exact[OF assms(1)] have ab: "dim_of a = dim_of b" "y * scale b = x * scale a" by auto
  from convert_exact[OF assms(2)] have bc: "dim_of b = dim_of c" "z * scale c = y * scale b" by auto
  have "z * scale c = x * scale a" using ab(2) bc(2) by simp
  then have z: "z = x * scale a / scale c" by (simp add: eq_divide_eq)
  show ?thesis using ab(1) bc(1) z by (simp add: kernel_def decline_of_def)
qed

text \<open>A watt-hour amount records constant power in watts times elapsed
hours. Converting that amount preserves the same power-times-time energy in
SI units, for every requested energy unit. Prefix case changes the unit, not
merely its rendering.\<close>
theorem watt_hour_power_time:
  assumes "dim_of u = D_energy"
  shows "kernel (Convert (p * t) (Lin U_watt_hour) (Lin u)) =
    Exact K_convert ((p * scale U_watt) * (t * scale U_hour) / scale u)"
  using assms by (simp add: kernel_def decline_of_def algebra_simps)

theorem energy_prefix_separation:
  "kernel (Convert x (Lin U_megajoule) (Lin U_millijoule)) = Exact K_convert (x * 1000000000)"
  "kernel (Convert x (Lin U_megawatt_hour) (Lin U_milliwatt_hour)) = Exact K_convert (x * 1000000000)"
  by (simp_all add: kernel_def decline_of_def field_simps)

text \<open>A temperature is a point on an affine scale: the converted value names
the same absolute temperature, and the kernel refuses points below absolute
zero.\<close>
theorem temperature_point:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y"
  shows "k = K_temperature \<and> 0 \<le> kelvin a x \<and> kelvin b y = kelvin a x"
proof -
  have s: "\<not> x * tscale a + toffset a < 0" "k = K_temperature" "y = (kelvin a x - toffset b) / tscale b"
    using kernel_exact_sound[OF assms] by simp_all
  have kb: "kelvin b y = kelvin a x"
    unfolding s(3) kelvin_def[of b] by (simp add: field_simps)
  have k0: "0 \<le> kelvin a x" using s(1) by (simp add: kelvin_def)
  show ?thesis using s(2) k0 kb by simp
qed

theorem temperature_impossible:
  "(\<exists>why. kernel (Convert x (Tmp a) (Tmp b)) = Decline (Impossible why)) \<longleftrightarrow> kelvin a x < 0"
  by (simp add: kernel_impossible kelvin_def)

theorem temperature_round_trip:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y"
  shows "kernel (Convert y (Tmp b) (Tmp a)) = Exact K_temperature x"
proof -
  have nonneg: "0 \<le> kelvin a x" and same: "kelvin b y = kelvin a x"
    using temperature_point[OF assms] by auto
  have reverse_value: "(kelvin b y - toffset a) / tscale a = x"
    by (subst same) (simp add: kelvin_def)
  have valid_b: "\<not> kelvin b y < 0"
    using nonneg same by simp
  show ?thesis using valid_b reverse_value
    by (simp add: kernel_def decline_of_def)
qed

text \<open>A temperature point is not a temperature difference: the point
conversion differs from the difference conversion by the offset between the
scales' zeros, so it differs whenever the zeros differ (C to F: by 32).\<close>
theorem temperature_point_vs_difference:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y"
  shows "y = tdelta a b x + (toffset a - toffset b) / tscale b"
proof -
  have "y = (kelvin a x - toffset b) / tscale b"
    using kernel_exact_sound[OF assms] by simp
  then show ?thesis by (simp add: kelvin_def tdelta_def field_simps)
qed

corollary temperature_point_not_difference:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y" "toffset a \<noteq> toffset b"
  shows "y \<noteq> tdelta a b x"
proof -
  have "(toffset a - toffset b) / tscale b \<noteq> 0" using assms(2) by simp
  then show ?thesis using temperature_point_vs_difference[OF assms(1)] by simp
qed

theorem temperature_difference_scales: "tdelta a b x * tscale b = x * tscale a"
  by (simp add: tdelta_def)

text \<open>Interval conversion is total on signed temperature changes. It does not
add affine offsets or impose an absolute-zero guard on a difference.\<close>
theorem temperature_delta_exact:
  "kernel (ConvertDelta x (Tmp a) (Tmp b)) = Exact K_temperature_difference (tdelta a b x)"
  by (simp add: kernel_def decline_of_def)

theorem temperature_delta_round_trip:
  "kernel (ConvertDelta (tdelta a b x) (Tmp b) (Tmp a)) = Exact K_temperature_difference x"
  by (simp add: temperature_delta_exact tdelta_def)

theorem temperature_delta_endpoints:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k u"
      and "kernel (Convert y (Tmp a) (Tmp b)) = Exact k' v"
  shows "kernel (ConvertDelta (x - y) (Tmp a) (Tmp b)) = Exact K_temperature_difference (u - v)"
proof -
  have u: "u = tdelta a b x + (toffset a - toffset b) / tscale b"
    using temperature_point_vs_difference[OF assms(1)] .
  have v: "v = tdelta a b y + (toffset a - toffset b) / tscale b"
    using temperature_point_vs_difference[OF assms(2)] .
  show ?thesis by (simp add: temperature_delta_exact u v tdelta_def algebra_simps diff_divide_distrib)
qed

theorem temperature_linear_mismatch:
  "kernel (Convert x (Lin u) (Tmp t)) = Decline Mismatch"
  "kernel (Convert x (Tmp t) (Lin u)) = Decline Mismatch"
  by (simp_all add: kernel_def decline_of_def)

subsection \<open>Densities\<close>

theorem density_value: "kernel (Density m) = Exact K_density (density m)"
  by (simp add: kernel_def decline_of_def)

theorem mass_from_volume:
  assumes "kernel (MassOf m (Some V) u) = Exact k y"
  shows "k = K_mass \<and> dim_of (snd V) = D_volume \<and> dim_of u = D_mass \<and> y * scale u = density m * siq V"
  using kernel_exact_sound[OF assms] by (cases V) (auto simp: field_simps)

theorem volume_from_mass:
  assumes "kernel (VolumeOf m (Some M) u) = Exact k y"
  shows "k = K_volume \<and> dim_of (snd M) = D_mass \<and> dim_of u = D_volume \<and> y * scale u * density m = siq M"
  using kernel_exact_sound[OF assms] by (cases M) (auto simp: field_simps)

theorem floats_verdict:
  "kernel (Floats s f) = Verdict k b \<longleftrightarrow>
     k = K_floats \<and> b = (density s < density f) \<and> \<not> \<bar>density s - density f\<bar> * 50 < density f"
  by (auto simp: kernel_def decline_of_def)

theorem floats_undecided:
  "kernel (Floats s f) = Decline Undecided \<longleftrightarrow> \<bar>density s - density f\<bar> * 50 < density f"
  by (auto simp: kernel_def decline_of_def)

subsection \<open>Springs\<close>

theorem hooke_force:
  assumes "kernel (SpringForce (Some k) (Some x)) = Exact c y"
  shows "c = K_force \<and> dim_of (snd x) = D_length \<and> y = k * siq x"
  using kernel_exact_sound[OF assms] by (cases x) auto

theorem hooke_extension:
  assumes "kernel (SpringExtension (Some k) (Some f)) = Exact c y"
  shows "c = K_extension \<and> 0 < k \<and> y * k = f"
proof -
  have s: "\<not> k \<le> 0" "c = K_extension" "y = f / k" using kernel_exact_sound[OF assms] by simp_all
  then have "k \<noteq> 0" by simp
  then show ?thesis using s by simp
qed

theorem hooke_constant:
  assumes "kernel (SpringConstant (Some f) (Some x)) = Exact c y"
  shows "c = K_spring_constant \<and> dim_of (snd x) = D_length \<and> 0 < siq x \<and> y * siq x = f"
proof -
  have s: "\<not> fst x * scale (snd x) \<le> 0" "c = K_spring_constant" "y = f / siq x"
    using kernel_exact_sound[OF assms] by simp_all
  have d: "dim_of (snd x) = D_length"
    using kernel_exact_sound[OF assms] by (cases x) simp
  have p: "0 < siq x" using s(1) by (simp add: siq_def)
  then have "siq x \<noteq> 0" by simp
  then show ?thesis using s p d by simp
qed

theorem elastic_energy:
  assumes "kernel (SpringEnergy (Some k) (Some x)) = Exact c y"
  shows "c = K_elastic_energy \<and> dim_of (snd x) = D_length \<and> y = k * siq x ^ 2 / 2"
  using kernel_exact_sound[OF assms] by (cases x) auto

theorem spring_energy_force:
  assumes "kernel (SpringEnergy (Some k) (Some x)) = Exact c e"
    "kernel (SpringForce (Some k) (Some x)) = Exact c' F"
  shows "2 * e = F * siq x"
  using elastic_energy[OF assms(1)] hooke_force[OF assms(2)]
  by (auto simp: power2_eq_square)

text \<open>The defining relation of a mass on an ideal spring,
@{text "T\<^sup>2 k = 4 pi\<^sup>2 m"}, and @{text "f T = 1"}.\<close>
theorem spring_period_model:
  assumes "0 < k" "0 \<le> siq m"
  shows "0 \<le> phys (SpringPeriod (Some k) (Some m)) \<and>
         phys (SpringPeriod (Some k) (Some m)) ^ 2 * rl k = 4 * pi ^ 2 * rl (siq m)"
proof -
  have K: "0 < rl k" using assms(1) by (simp add: zero_less_of_rat_iff)
  have M: "0 \<le> rl (siq m)" using assms(2) by (simp add: zero_le_of_rat_iff)
  have q: "0 \<le> rl (siq m) / rl k" using K M by simp
  have sq: "sqrt (rl (siq m) / rl k) ^ 2 = rl (siq m) / rl k" using q by simp
  have "(2 * pi * sqrt (rl (siq m) / rl k)) ^ 2 * rl k = 4 * pi ^ 2 * (rl (siq m) / rl k) * rl k"
    by (simp add: power_mult_distrib sq)
  also have "\<dots> = 4 * pi ^ 2 * rl (siq m)"
  proof -
    have "rl k \<noteq> 0" using K by linarith
    then show ?thesis by (simp add: field_simps)
  qed
  finally have e: "(2 * pi * sqrt (rl (siq m) / rl k)) ^ 2 * rl k = 4 * pi ^ 2 * rl (siq m)" .
  have "0 \<le> 2 * pi * sqrt (rl (siq m) / rl k)"
    by (intro mult_nonneg_nonneg) (simp_all add: pi_ge_zero q)
  then show ?thesis using e by simp
qed

text \<open>The frequency is the reciprocal of the period, and for a positive
stiffness and mass @{text "f * T = 1"}.\<close>
theorem spring_frequency_inverse:
  "phys (SpringFrequency (Some k) (Some m)) = inverse (phys (SpringPeriod (Some k) (Some m)))"
  by simp

theorem spring_frequency_model:
  assumes "0 < k" "0 < siq m"
  shows "phys (SpringFrequency (Some k) (Some m)) * phys (SpringPeriod (Some k) (Some m)) = 1"
proof -
  have K: "0 < rl k" using assms(1) by (simp add: zero_less_of_rat_iff)
  have M: "0 < rl (siq m)" using assms(2) by (simp add: zero_less_of_rat_iff)
  have "0 < rl (siq m) / rl k" by (rule divide_pos_pos[OF M K])
  then have "0 < sqrt (rl (siq m) / rl k)" by (rule real_sqrt_gt_zero)
  then have T: "0 < 2 * pi * sqrt (rl (siq m) / rl k)" using pi_gt_zero by simp
  show ?thesis unfolding phys.simps
    by (rule left_inverse) (use T in linarith)
qed

subsection \<open>Fluids\<close>

theorem gauge_pressure:
  assumes "kernel (PressureGauge f (Some h)) = Exact c y"
  shows "c = K_pressure_gauge \<and> dim_of (snd h) = D_length \<and> y = density f * g0 * siq h"
  using kernel_exact_sound[OF assms] by (cases h) auto

theorem absolute_pressure:
  assumes "kernel (PressureAbs f (Some h)) = Exact c y"
  shows "c = K_pressure_abs \<and> dim_of (snd h) = D_length \<and> y = p0 + density f * g0 * siq h"
  using kernel_exact_sound[OF assms] by (cases h) auto

theorem pressure_absolute_gauge:
  assumes "kernel (PressureAbs f (Some h)) = Exact c a"
    "kernel (PressureGauge f (Some h)) = Exact c' g"
  shows "a = g + p0"
  using absolute_pressure[OF assms(1)] gauge_pressure[OF assms(2)] by auto

theorem buoyant_force:
  assumes "kernel (Buoyant f (Some v)) = Exact c y"
  shows "c = K_buoyant_force \<and> dim_of (snd v) = D_volume \<and> y = density f * g0 * siq v"
  using kernel_exact_sound[OF assms] by (cases v) auto

theorem submerged_fraction:
  assumes "kernel (Submerged s f) = Exact c y"
  shows "c = K_submerged_fraction \<and> y * density f = density s \<and> 0 < y \<and> y < 1"
proof -
  have a: "answer_of (Submerged s f) = Exact c y"
    using assms by (simp add: kernel_def decline_of_def)
  then have lt: "density s < density f" and y: "y = density s / density f" and c: "c = K_submerged_fraction"
    by (auto split: if_splits)
  have "y < 1" using lt y by simp
  moreover have "0 < y" using y by simp
  ultimately show ?thesis using y c by simp
qed

theorem submerged_sinks:
  "kernel (Submerged s f) = Verdict K_sinks False \<longleftrightarrow> density f \<le> density s"
  by (auto simp: kernel_def decline_of_def)

subsection \<open>Fuels\<close>

theorem fuel_energy:
  assumes "kernel (FuelEnergy f (Some m) u) = Exact c y"
  shows "c = K_energy \<and> dim_of (snd m) = D_mass \<and> dim_of u = D_energy \<and>
         y * scale u = siq m * ncv f * 1000000"
  using kernel_exact_sound[OF assms] by (cases m) (auto simp: field_simps)

text \<open>CO2 is the energy released (MJ) times the emission factor (kg per TJ),
over 10^6 MJ per TJ.\<close>
theorem fuel_co2:
  assumes "kernel (FuelCO2 f (Some m)) = Exact c y"
  shows "c = K_co2 \<and> dim_of (snd m) = D_mass \<and> y = (siq m * ncv f) * co2_factor f / 1000000"
  using kernel_exact_sound[OF assms] by (cases m) auto

theorem fuel_mass_needed:
  assumes "kernel (FuelMassNeeded f e) = Exact c y"
  shows "c = K_mass_needed \<and> dim_of (snd e) = D_energy \<and> y * ncv f * 1000000 = siq e"
  using kernel_exact_sound[OF assms] by (auto simp: field_simps)

theorem fuel_ncv: "kernel (FuelNCV f) = Exact K_ncv (ncv f)"
  by (simp add: kernel_def decline_of_def)


subsection \<open>Explicit model conditions\<close>

theorem hydrostatic_absolute_gauge:
  assumes "kernel (Hydrostatic d (Some h) g p True) = Exact ca a"
      and "kernel (Hydrostatic d (Some h) g p False) = Exact cg b"
  shows "a - b = siq p"
  using kernel_exact_sound[OF assms(1)] kernel_exact_sound[OF assms(2)] by simp

theorem hydrostatic_nonnegative:
  assumes "kernel (Hydrostatic d (Some h) g p a) = Exact k y"
  shows "0 \<le> y"
proof -
  have "0 \<le> input_density d" "0 \<le> gravity_si g" "0 \<le> siq h" "0 \<le> siq p"
    and y: "y = input_density d * gravity_si g * siq h + (if a then siq p else 0)"
    using kernel_exact_sound[OF assms] by auto
  then show ?thesis by (auto intro: add_nonneg_nonneg mult_nonneg_nonneg)
qed

theorem hydrostatic_equivalent_inputs:
  assumes "input_density d = input_density d'" "siq h = siq h'"
      "gravity_si g = gravity_si g'" "siq p = siq p'"
      "kernel (Hydrostatic d (Some h) g p a) = Exact k y"
      "kernel (Hydrostatic d' (Some h') g' p' a) = Exact k' y'"
  shows "y = y'"
  using assms kernel_exact_sound[OF assms(5)] kernel_exact_sound[OF assms(6)] by simp

theorem useful_heat_fraction:
  assumes "kernel (FuelUsefulEnergy f (Some m) u (Some e)) = Exact ku useful"
      "kernel (FuelEnergy f (Some m) u) = Exact kr released"
  shows "useful = efficiency e * released \<and> 0 \<le> useful \<and> useful \<le> released"
proof -
  have bounds: "0 \<le> siq m" "0 \<le> efficiency e" "efficiency e \<le> 1"
    and vals: "useful = efficiency e * (siq m * ncv f * 1000000 / scale u)"
      "released = siq m * ncv f * 1000000 / scale u"
    using kernel_exact_sound[OF assms(1)] kernel_exact_sound[OF assms(2)]
    by (auto simp: algebra_simps)
  have ncv_nonneg: "0 \<le> ncv f" using ncv_pos[of f] by linarith
  have product_nonneg: "0 \<le> siq m * ncv f * 1000000"
    by (intro mult_nonneg_nonneg; simp add: bounds(1) ncv_nonneg)
  have quotient_nonneg: "0 \<le> siq m * ncv f * 1000000 / scale u"
    by (rule divide_nonneg_pos[OF product_nonneg scale_pos])
  have r: "0 \<le> released" using quotient_nonneg vals(2) by simp
  have eq: "useful = efficiency e * released" using vals by simp
  have upper: "efficiency e * released \<le> 1 * released"
    by (rule mult_right_mono[OF bounds(3) r])
  have lower: "0 \<le> efficiency e * released"
    by (rule mult_nonneg_nonneg[OF bounds(2) r])
  show ?thesis using eq upper lower by simp
qed

theorem useful_heat_inverse:
  assumes "kernel (FuelUsefulMass f q (Some e)) = Exact k m"
  shows "m * efficiency e * ncv f * 1000000 = siq q \<and> 0 \<le> m"
proof -
  have pos: "0 < efficiency e" and nonneg: "0 \<le> siq q"
    and m: "m = siq q / (efficiency e * ncv f * 1000000)"
    using kernel_exact_sound[OF assms] by auto
  have m_nonneg: "0 \<le> m" using pos nonneg m by (auto intro: divide_nonneg_pos mult_pos_pos)
  have balance: "m * efficiency e * ncv f * 1000000 = siq q"
    using pos m by (auto simp: field_simps)
  show ?thesis using balance m_nonneg by blast
qed

theorem unsupported_condition_declines:
  "kernel (UnsupportedCondition c) = Decline (UnsupportedModel c)"
  by (simp add: kernel_def decline_of_def)

section \<open>Response text (ASCII)\<close>

definition sig_digits :: "kind \<Rightarrow> nat" where
  "sig_digits k = (if k = K_convert \<or> k = K_temperature \<or> k = K_temperature_difference then 10 else 4)"

definition is_int :: "rat \<Rightarrow> bool" where
  "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

text \<open>The decimal stated for an exact value: a whole conversion result
exactly, otherwise rounded to the kind's significant digits.\<close>
definition stated_dec :: "kind \<Rightarrow> rat \<Rightarrow> (int \<times> int) option" where
  "stated_dec k q = (if sig_digits k = 10 \<and> is_int q then Some (fst (quotient_of q), 0)
     else round_sig (sig_digits k) (rl q))"

theorem stated_dec_sound:
  assumes "stated_dec k q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (sig_digits k - 1))"
proof (cases "sig_digits k = 10 \<and> is_int q")
  case True
  obtain a b where ab: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have b: "b = 1" using True by (simp add: is_int_def)
  have "q = of_int a / of_int b" using ab by (rule quotient_of_div)
  then have qa: "q = of_int a" using b by simp
  have "d = (a, 0)" using assms True ab by (simp add: stated_dec_def)
  then have "dec_val d = rl q" using qa by (simp add: dec_val_def pow10_def)
  then show ?thesis by simp
next
  case False
  have "stated_dec k q = round_sig (sig_digits k) (rl q)" using False by (auto simp: stated_dec_def)
  then have "round_sig (sig_digits k) (rl q) = Some d" using assms by simp
  then show ?thesis by (rule round_sig_sound)
qed

definition value_lit :: "kind \<Rightarrow> rat \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "value_lit k q d = (if sig_digits k = 10 \<and> is_int q then show_int (fst (quotient_of q))
     else render_dec (sig_digits k) d)"

text \<open>The exact fraction behind a fractional conversion result, as the units
organ v2 prints it.\<close>
definition frac_note :: "rat \<Rightarrow> String.literal" where
  "frac_note q = (case quotient_of q of (a, b) \<Rightarrow>
     if b = 1 \<or> 1000000000000000 < b then STR '''' else
     STR '' (exactly '' + show_int a + STR ''/'' + show_int b + STR '')'')"

fun exact_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text (Density m) q V = STR ''The density of '' + mat_name m + STR '' is about '' + V
     + STR '' kg/m3 ('' + show4 (density m / 1000) + STR '' g/cm3), a typical value near 20 degrees C.''"
| "exact_text (MassOf m (Some A) u) q V = STR ''The mass is about '' + V + STR '' '' + unit_label u
     + STR '' (m = rho V = '' + show4 (density m) + STR '' kg/m3 x '' + show4 (siq A) + STR '' m3 for ''
     + mat_name m + STR ''; rho is a typical value near 20 degrees C).''"
| "exact_text (VolumeOf m (Some A) u) q V = STR ''The volume is about '' + V + STR '' '' + unit_label u
     + STR '' (V = m/rho = '' + show4 (siq A) + STR '' kg / '' + show4 (density m) + STR '' kg/m3 for ''
     + mat_name m + STR ''; rho is a typical value near 20 degrees C).''"
| "exact_text (Convert x a b) q V = show_input x + STR '' '' + uref_label a + STR '' is '' + V + frac_note q
     + STR '' '' + uref_label b + (case a of Lin _ \<Rightarrow> STR '' (NIST exact factors).'' | Tmp _ \<Rightarrow> STR ''.'')"
| "exact_text (ConvertDelta x a b) q V = STR ''A temperature difference of '' + show_input x + STR '' '' + uref_label a
     + STR '' is a difference of '' + V + frac_note q + STR '' '' + uref_label b + STR ''.''"
| "exact_text (SpringForce (Some k) (Some x)) q V = STR ''The force is about '' + V
     + STR '' N (F = k x = '' + show4 k + STR '' x '' + show4 (siq x) + STR '').''"
| "exact_text (SpringExtension (Some k) (Some f)) q V = STR ''The extension is about '' + V
     + STR '' m ('' + show4 (100 * q) + STR '' cm) (x = F/k = '' + show4 f + STR ''/'' + show4 k + STR '').''"
| "exact_text (SpringConstant (Some f) (Some x)) q V = STR ''The spring constant is about '' + V
     + STR '' N/m (k = F/x = '' + show4 f + STR ''/'' + show4 (siq x) + STR '').''"
| "exact_text (SpringEnergy (Some k) (Some x)) q V = STR ''The stored energy is about '' + V
     + STR '' J (E = 1/2 k x^2 = 1/2 x '' + show4 k + STR '' x '' + show4 (siq x) + STR ''^2).''"
| "exact_text (PressureGauge f (Some h)) q V = STR ''The gauge pressure is about '' + V + STR '' Pa (''
     + show4 (q / 1000) + STR '' kPa) at '' + show4 (siq h) + STR '' m in '' + fluid_name f
     + STR '' (P = rho g h = '' + show4 (density f) + STR '' x 9.80665 x '' + show4 (siq h)
     + STR ''; add 101325 Pa for absolute).''"
| "exact_text (PressureAbs f (Some h)) q V = STR ''The absolute pressure is about '' + V + STR '' Pa (''
     + show4 (q / 1000) + STR '' kPa) at '' + show4 (siq h) + STR '' m in '' + fluid_name f
     + STR '' (P = P0 + rho g h = 101325 + '' + show4 (density f) + STR '' x 9.80665 x '' + show4 (siq h) + STR '').''"
| "exact_text (Buoyant f (Some v)) q V = STR ''The buoyant force is about '' + V
     + STR '' N (F = rho g V = '' + show4 (density f) + STR '' x 9.80665 x '' + show4 (siq v) + STR '' m3 of ''
     + fluid_name f + STR '' displaced).''"
| "exact_text (Submerged s f) q V = STR ''The submerged fraction is about '' + V + STR '' (''
     + show4 (100 * q) + STR ''%) of a floating piece of '' + mat_name s + STR '' in '' + fluid_name f
     + STR '' (fraction = rho_solid/rho_fluid = '' + show4 (density s) + STR ''/'' + show4 (density f) + STR '').''"
| "exact_text (FuelEnergy f (Some m) u) q V = STR ''Burning '' + show4 (siq m) + STR '' kg of '' + fuel_name f
     + STR '' releases about '' + V + STR '' '' + unit_label u + STR '' (E = m x NCV = '' + show4 (siq m)
     + STR '' kg x '' + show4 (ncv f) + STR '' MJ/kg = '' + show4 (siq m * ncv f)
     + STR '' MJ, IPCC 2006 default).''"
| "exact_text (FuelCO2 f (Some m)) q V = STR ''Burning '' + show4 (siq m) + STR '' kg of '' + fuel_name f
     + STR '' emits about '' + V + STR '' kg of CO2'' + (if biogenic f then STR '' (biogenic carbon)'' else STR '''')
     + STR '' (mass x NCV x EF = '' + show4 (siq m) + STR '' kg x '' + show4 (ncv f) + STR '' MJ/kg x ''
     + show4 (co2_factor f) + STR '' kg CO2/TJ; IPCC 2006 defaults).''"
| "exact_text (FuelMassNeeded f e) q V = STR ''It takes about '' + V + STR '' kg of '' + fuel_name f
     + STR '' to release '' + show4 (siq e / 1000000) + STR '' MJ (m = E / NCV = '' + show4 (siq e / 1000000)
     + STR '' MJ / '' + show4 (ncv f) + STR '' MJ/kg; IPCC 2006 default).''"
| "exact_text (FuelNCV f) q V = STR ''The net calorific value of '' + fuel_name f + STR '' is about '' + V
     + STR '' MJ/kg ('' + show4 (ncv f * 10 / 36) + STR '' kWh/kg; IPCC 2006 default).''"
| "exact_text (Hydrostatic d (Some h) g p a) q V =
     (if a then STR ''The absolute pressure is about '' else STR ''The gauge pressure is about '')
     + V + STR '' Pa (constant density '' + show4 (input_density d) + STR '' kg/m3, gravity ''
     + show4 (gravity_si g) + STR '' m/s2, depth '' + show4 (siq h) + STR '' m, absolute surface pressure ''
     + show4 (siq p) + STR '' Pa).''"
| "exact_text (FuelUsefulEnergy f (Some m) u (Some e)) q V = STR ''The useful heat is about ''
     + V + STR '' '' + unit_label u + STR '' from '' + show4 (siq m) + STR '' kg of '' + fuel_name f
     + STR '' at '' + show4 (100 * efficiency e) + STR ''% heat-delivery efficiency (IPCC default net calorific value).''"
| "exact_text (FuelUsefulMass f q (Some e)) v V = STR ''About '' + V + STR '' kg of '' + fuel_name f
     + STR '' is needed to deliver '' + show4 (siq q / 1000000) + STR '' MJ of useful heat at ''
     + show4 (100 * efficiency e) + STR ''% heat-delivery efficiency (IPCC default net calorific value).''"
| "exact_text r q V = V"

fun approx_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "approx_text (SpringPeriod (Some k) (Some m)) V = STR ''The period is about '' + V
     + STR '' s (T = 2 pi sqrt(m/k) = 2 pi sqrt('' + show4 (siq m) + STR ''/'' + show4 k + STR '')).''"
| "approx_text (SpringFrequency (Some k) (Some m)) V = STR ''The frequency is about '' + V
     + STR '' Hz (f = 1/(2 pi) sqrt(k/m) = 1/(2 pi) sqrt('' + show4 k + STR ''/'' + show4 (siq m) + STR '')).''"
| "approx_text r V = V"

fun verdict_text :: "request \<Rightarrow> bool \<Rightarrow> String.literal" where
  "verdict_text (Floats s f) b = (if b then STR ''Yes'' else STR ''No'') + STR '' - solid '' + mat_name s
     + STR '' (about '' + show4 (density s) + STR '' kg/m3) is '' + (if b then STR ''less'' else STR ''more'')
     + STR '' dense than '' + mat_name f + STR '' (about '' + show4 (density f) + STR '' kg/m3), so it ''
     + (if b then STR ''floats.'' else STR ''sinks.'')"
| "verdict_text (Submerged s f) b = STR ''It does not float: '' + mat_name s + STR '' (about ''
     + show4 (density s) + STR '' kg/m3) is denser than '' + fluid_name f + STR '' (about ''
     + show4 (density f) + STR '' kg/m3), so all of it sinks.''"
| "verdict_text r b = STR ''''"

fun req_material :: "request \<Rightarrow> String.literal" where
  "req_material (MassOf m _ _) = mat_name m"
| "req_material (VolumeOf m _ _) = mat_name m"
| "req_material (FuelEnergy f _ _) = fuel_name f"
| "req_material (FuelCO2 f _) = fuel_name f"
| "req_material (FuelUsefulEnergy f _ _ _) = fuel_name f"
| "req_material r = STR ''''"

definition need_text :: "request \<Rightarrow> need \<Rightarrow> String.literal" where
  "need_text r w = (case w of
     N_amount \<Rightarrow> STR ''I need an amount of '' + req_material r
       + STR '' (a volume for its mass, or a mass for its volume); I won'' + apos + STR ''t assume one.''
   | N_k_stretch \<Rightarrow> STR ''I need a spring constant and a stretch to compute that; I won'' + apos + STR ''t assume it.''
   | N_k_stretch_or_compression \<Rightarrow> STR ''I need a spring constant and a stretch or compression to compute that; I won''
       + apos + STR ''t assume it.''
   | N_force_stretch \<Rightarrow> STR ''I need a force and the stretch it causes to compute that; I won'' + apos + STR ''t assume it.''
   | N_k_force \<Rightarrow> STR ''I need a spring constant and a force to compute that; I won'' + apos + STR ''t assume it.''
   | N_mass_k \<Rightarrow> STR ''I need a mass and a spring constant to compute that; I won'' + apos + STR ''t assume it.''
   | N_depth \<Rightarrow> STR ''I need a depth to compute that; I won'' + apos + STR ''t assume it.''
   | N_volume \<Rightarrow> STR ''I need the submerged volume to compute that; I won'' + apos + STR ''t assume it.''
   | N_fuel_mass \<Rightarrow> STR ''I need a mass of '' + req_material r + STR '' to compute that; I won'' + apos + STR ''t assume it.''
   | N_efficiency \<Rightarrow> STR ''I need the fraction or percentage of released heat delivered as useful heat.'')"

fun mismatch_text :: "request \<Rightarrow> String.literal" where
  "mismatch_text (Convert x (Lin a) (Lin b)) = unit_label a + STR '' measures '' + dim_name (dim_of a)
     + STR '' and '' + unit_label b + STR '' measures '' + dim_name (dim_of b) + STR '', so there'' + apos
     + STR ''s no conversion between them.''"
| "mismatch_text (ConvertDelta x a b) = STR ''A temperature difference needs temperature scales on both sides.''"
| "mismatch_text (Convert x a b) = uref_label a + STR '' and '' + uref_label b
     + STR '' measure different things, so there'' + apos + STR ''s no conversion between them.''"
| "mismatch_text r = STR ''The amounts given do not have the units this formula needs.''"

fun reason_text :: "request \<Rightarrow> reason \<Rightarrow> String.literal" where
  "reason_text (Convert x (Tmp a) b) R_below_absolute_zero = show_input x + STR '' '' + tlabel a
     + STR '' is below absolute zero, so it isn'' + apos + STR ''t a real temperature.''"
| "reason_text r R_below_absolute_zero = STR ''That is below absolute zero.''"
| "reason_text r R_nonpositive_stiffness = STR ''A spring constant must be positive.''"
| "reason_text r R_nonpositive_stretch = STR ''A stretch must be positive to give a spring constant.''"
| "reason_text r R_nonpositive_mass = STR ''The mass on the spring must be positive.''"
| "reason_text r R_hydrostatic_inputs = STR ''Density must be positive; depth, gravity magnitude and absolute surface pressure must be nonnegative.''"
| "reason_text r R_fuel_inputs = STR ''Fuel mass and required useful heat must be nonnegative.''"
| "reason_text r R_efficiency = STR ''Heat-delivery efficiency must be between zero and one (0% to 100%).''"
| "reason_text r R_inverse_efficiency = STR ''Delivering a specified useful heat requires efficiency greater than zero and at most one.''"

fun model_condition_text :: "model_condition \<Rightarrow> String.literal" where
  "model_condition_text C_reference_state = STR ''The reference density table does not model the stated temperature, pressure or state condition.''"
| "model_condition_text C_moisture = STR ''The default fuel value does not model the stated moisture or calorific-value basis.''"
| "model_condition_text C_unread_input = STR ''The stated model input or its units could not be bound unambiguously.''"
| "model_condition_text C_other_operation = STR ''The requested operation with these explicit conditions is outside this model.''"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | Mismatch \<Rightarrow> STR ''mismatch''
     | Impossible _ \<Rightarrow> STR ''impossible'' | Undecided \<Rightarrow> STR ''undecided'' | Imprecise \<Rightarrow> STR ''imprecise'' | UnsupportedModel _ \<Rightarrow> STR ''unsupported_model'')"

definition decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r w = (case w of
     Underspecified n \<Rightarrow> need_text r n
   | Mismatch \<Rightarrow> mismatch_text r
   | Impossible why \<Rightarrow> reason_text r why
   | Undecided \<Rightarrow> STR ''The two densities are within 2 percent of each other; I won'' + apos
       + STR ''t call whether it floats.''
   | Imprecise \<Rightarrow> STR ''The interval arithmetic could not pin four digits; I won'' + apos + STR ''t guess.''
   | UnsupportedModel c \<Rightarrow> model_condition_text c)"

definition kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name k = (case k of K_density \<Rightarrow> STR ''density'' | K_mass \<Rightarrow> STR ''mass''
     | K_volume \<Rightarrow> STR ''volume'' | K_floats \<Rightarrow> STR ''floats'' | K_convert \<Rightarrow> STR ''convert''
     | K_temperature \<Rightarrow> STR ''temperature'' | K_temperature_difference \<Rightarrow> STR ''temperature_difference'' | K_force \<Rightarrow> STR ''force'' | K_extension \<Rightarrow> STR ''extension''
     | K_spring_constant \<Rightarrow> STR ''spring_constant'' | K_elastic_energy \<Rightarrow> STR ''elastic_energy''
     | K_period \<Rightarrow> STR ''period'' | K_frequency \<Rightarrow> STR ''frequency''
     | K_pressure_gauge \<Rightarrow> STR ''pressure_gauge'' | K_pressure_abs \<Rightarrow> STR ''pressure_abs''
     | K_buoyant_force \<Rightarrow> STR ''buoyant_force'' | K_submerged_fraction \<Rightarrow> STR ''submerged_fraction''
     | K_sinks \<Rightarrow> STR ''sinks'' | K_energy \<Rightarrow> STR ''energy'' | K_co2 \<Rightarrow> STR ''co2''
     | K_mass_needed \<Rightarrow> STR ''mass_needed'' | K_ncv \<Rightarrow> STR ''ncv''
     | K_useful_energy \<Rightarrow> STR ''useful_energy'' | K_useful_mass_needed \<Rightarrow> STR ''useful_mass_needed''
     | K_model_condition \<Rightarrow> STR ''model_condition'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and
the stated value. Withheld replies carry the decline text, as the organs do.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow> (case stated_dec k q of
         None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text r Imprecise) None
       | Some d \<Rightarrow> Reply True (kind_name k) (exact_text r q (value_lit k q d)) (Some (value_lit k q d)))
   | Approx k d \<Rightarrow> Reply True (kind_name k) (approx_text r (render_dec 4 d)) (Some (render_dec 4 d))
   | Verdict k b \<Rightarrow> Reply True (kind_name k) (verdict_text r b) None
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text r w) None)"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d. kernel r = Exact k q \<and> stated_dec k q = Some d) \<or> (\<exists>k d. kernel r = Approx k d) \<or>
     (\<exists>k b. kernel r = Verdict k b)"
  by (auto simp: reply_of_def split: outcome.splits option.splits)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated_dec k q = Some d \<Longrightarrow> stated (reply_of r) = Some (value_lit k q d)"
  by (simp add: reply_of_def)

theorem reply_states_approx:
  "kernel r = Approx k d \<Longrightarrow> stated (reply_of r) = Some (render_dec 4 d)"
  by (simp add: reply_of_def)

text \<open>A withheld reply names the kernel's decline.\<close>
theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

end
