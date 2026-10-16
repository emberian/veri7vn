theory Domain_Quantities
  imports "Veri7vn_Codegen.Veri7vn_Codegen" "HOL.Rat"
begin

text \<open>Canonical exact definitions from shipped units V1/V2. Day and week
are fixed durations. US volume conventions, thermochemical calories and listed
conventional pressure factors remain explicit. No calendar or logarithmic law
is inferred. Force and stiffness extend the table for the shipped springs model.\<close>
datatype quantity_dimension = Length | Mass | Volume | Area | Speed | Duration | Pressure | Energy | Power | DataSize | ForceDimension | StiffnessDimension
datatype linear_unit = Metre | Kilometre | Centimetre | Millimetre | Inch | Foot | Yard | Mile | NauticalMile | Kilogram | Gram | Milligram | Pound | Ounce | Tonne | Stone | Litre | Millilitre | GallonUS | QuartUS | PintUS | CupUS | FluidOunceUS | CubicMetre | SquareMetre | SquareFoot | Acre | Hectare | SquareKilometre | SquareMile | MetrePerSecond | KilometrePerHour | MilePerHour | Knot | Second | Minute | Hour | Day | Week | Pascal | Kilopascal | Bar | Atmosphere | Psi | MmHg | Joule | Kilojoule | Calorie | Kilocalorie | KilowattHour | Btu | Watt | Kilowatt | Horsepower | Byte | Kilobyte | Megabyte | Gigabyte | Terabyte | Kibibyte | Mebibyte | Gibibyte | Newton | NewtonPerMetre

fun unit_dimension :: "linear_unit \<Rightarrow> quantity_dimension" where
  "unit_dimension Metre = Length"
|   "unit_dimension Kilometre = Length"
|   "unit_dimension Centimetre = Length"
|   "unit_dimension Millimetre = Length"
|   "unit_dimension Inch = Length"
|   "unit_dimension Foot = Length"
|   "unit_dimension Yard = Length"
|   "unit_dimension Mile = Length"
|   "unit_dimension NauticalMile = Length"
|   "unit_dimension Kilogram = Mass"
|   "unit_dimension Gram = Mass"
|   "unit_dimension Milligram = Mass"
|   "unit_dimension Pound = Mass"
|   "unit_dimension Ounce = Mass"
|   "unit_dimension Tonne = Mass"
|   "unit_dimension Stone = Mass"
|   "unit_dimension Litre = Volume"
|   "unit_dimension Millilitre = Volume"
|   "unit_dimension GallonUS = Volume"
|   "unit_dimension QuartUS = Volume"
|   "unit_dimension PintUS = Volume"
|   "unit_dimension CupUS = Volume"
|   "unit_dimension FluidOunceUS = Volume"
|   "unit_dimension CubicMetre = Volume"
|   "unit_dimension SquareMetre = Area"
|   "unit_dimension SquareFoot = Area"
|   "unit_dimension Acre = Area"
|   "unit_dimension Hectare = Area"
|   "unit_dimension SquareKilometre = Area"
|   "unit_dimension SquareMile = Area"
|   "unit_dimension MetrePerSecond = Speed"
|   "unit_dimension KilometrePerHour = Speed"
|   "unit_dimension MilePerHour = Speed"
|   "unit_dimension Knot = Speed"
|   "unit_dimension Second = Duration"
|   "unit_dimension Minute = Duration"
|   "unit_dimension Hour = Duration"
|   "unit_dimension Day = Duration"
|   "unit_dimension Week = Duration"
|   "unit_dimension Pascal = Pressure"
|   "unit_dimension Kilopascal = Pressure"
|   "unit_dimension Bar = Pressure"
|   "unit_dimension Atmosphere = Pressure"
|   "unit_dimension Psi = Pressure"
|   "unit_dimension MmHg = Pressure"
|   "unit_dimension Joule = Energy"
|   "unit_dimension Kilojoule = Energy"
|   "unit_dimension Calorie = Energy"
|   "unit_dimension Kilocalorie = Energy"
|   "unit_dimension KilowattHour = Energy"
|   "unit_dimension Btu = Energy"
|   "unit_dimension Watt = Power"
|   "unit_dimension Kilowatt = Power"
|   "unit_dimension Horsepower = Power"
|   "unit_dimension Byte = DataSize"
|   "unit_dimension Kilobyte = DataSize"
|   "unit_dimension Megabyte = DataSize"
|   "unit_dimension Gigabyte = DataSize"
|   "unit_dimension Terabyte = DataSize"
|   "unit_dimension Kibibyte = DataSize"
|   "unit_dimension Mebibyte = DataSize"
|   "unit_dimension Gibibyte = DataSize"
|   "unit_dimension Newton = ForceDimension"
|   "unit_dimension NewtonPerMetre = StiffnessDimension"

fun unit_scale :: "linear_unit \<Rightarrow> rat" where
  "unit_scale Metre = 1"
|   "unit_scale Kilometre = 1000"
|   "unit_scale Centimetre = 1/100"
|   "unit_scale Millimetre = 1/1000"
|   "unit_scale Inch = 127/5000"
|   "unit_scale Foot = 381/1250"
|   "unit_scale Yard = 1143/1250"
|   "unit_scale Mile = 201168/125"
|   "unit_scale NauticalMile = 1852"
|   "unit_scale Kilogram = 1"
|   "unit_scale Gram = 1/1000"
|   "unit_scale Milligram = 1/1000000"
|   "unit_scale Pound = 45359237/100000000"
|   "unit_scale Ounce = 45359237/1600000000"
|   "unit_scale Tonne = 1000"
|   "unit_scale Stone = 317514659/50000000"
|   "unit_scale Litre = 1/1000"
|   "unit_scale Millilitre = 1/1000000"
|   "unit_scale GallonUS = 473176473/125000000000"
|   "unit_scale QuartUS = 473176473/500000000000"
|   "unit_scale PintUS = 473176473/1000000000000"
|   "unit_scale CupUS = 473176473/2000000000000"
|   "unit_scale FluidOunceUS = 473176473/16000000000000"
|   "unit_scale CubicMetre = 1"
|   "unit_scale SquareMetre = 1"
|   "unit_scale SquareFoot = 145161/1562500"
|   "unit_scale Acre = 316160658/78125"
|   "unit_scale Hectare = 10000"
|   "unit_scale SquareKilometre = 1000000"
|   "unit_scale SquareMile = 40468564224/15625"
|   "unit_scale MetrePerSecond = 1"
|   "unit_scale KilometrePerHour = 5/18"
|   "unit_scale MilePerHour = 1397/3125"
|   "unit_scale Knot = 463/900"
|   "unit_scale Second = 1"
|   "unit_scale Minute = 60"
|   "unit_scale Hour = 3600"
|   "unit_scale Day = 86400"
|   "unit_scale Week = 604800"
|   "unit_scale Pascal = 1"
|   "unit_scale Kilopascal = 1000"
|   "unit_scale Bar = 100000"
|   "unit_scale Atmosphere = 101325"
|   "unit_scale Psi = (45359237/100000000)*(196133/20000)/(127/5000)^2"
|   "unit_scale MmHg = 26664477483/200000000"
|   "unit_scale Joule = 1"
|   "unit_scale Kilojoule = 1000"
|   "unit_scale Calorie = 523/125"
|   "unit_scale Kilocalorie = 4184"
|   "unit_scale KilowattHour = 3600000"
|   "unit_scale Btu = 52752792631/50000000"
|   "unit_scale Watt = 1"
|   "unit_scale Kilowatt = 1000"
|   "unit_scale Horsepower = 550*(381/1250)*(45359237/100000000)*(196133/20000)"
|   "unit_scale Byte = 1"
|   "unit_scale Kilobyte = 1000"
|   "unit_scale Megabyte = 1000000"
|   "unit_scale Gigabyte = 1000000000"
|   "unit_scale Terabyte = 1000000000000"
|   "unit_scale Kibibyte = 1024"
|   "unit_scale Mebibyte = 1048576"
|   "unit_scale Gibibyte = 1073741824"
|   "unit_scale Newton = 1"
|   "unit_scale NewtonPerMetre = 1"

lemma unit_scale_positive: "0 < unit_scale u"
  by (cases u) simp_all

definition linear_convert :: "linear_unit \<Rightarrow> linear_unit \<Rightarrow> rat \<Rightarrow> rat option" where
  "linear_convert a b x = (if unit_dimension a = unit_dimension b
    then Some (x * unit_scale a / unit_scale b) else None)"

definition linear_meaning where
  "linear_meaning a b x y \<longleftrightarrow> unit_dimension a = unit_dimension b \<and>
    y * unit_scale b = x * unit_scale a"

lemma linear_conversion_refinement:
  "linear_convert a b x = Some y \<longleftrightarrow> linear_meaning a b x y"
  using unit_scale_positive[of b]
  by (auto simp: linear_convert_def linear_meaning_def field_simps split: if_splits)

lemma linear_conversion_composes:
  assumes "linear_convert a b x = Some y" "linear_convert b c y = Some z"
  shows "linear_convert a c x = Some z"
  using assms unit_scale_positive[of b] unit_scale_positive[of c]
  by (auto simp: linear_conversion_refinement linear_meaning_def field_simps)

datatype temperature_unit = Kelvin | Celsius | Fahrenheit
fun temperature_scale :: "temperature_unit \<Rightarrow> rat" where
  "temperature_scale Kelvin = 1" | "temperature_scale Celsius = 1"
| "temperature_scale Fahrenheit = 5/9"
fun temperature_offset :: "temperature_unit \<Rightarrow> rat" where
  "temperature_offset Kelvin = 0" | "temperature_offset Celsius = 5463/20"
| "temperature_offset Fahrenheit = 45967/180"
definition kelvin_point where "kelvin_point u x = x * temperature_scale u + temperature_offset u"
definition temperature_convert where
  "temperature_convert a b x = (let k = kelvin_point a x in
    if k < 0 then None else Some ((k - temperature_offset b) / temperature_scale b))"
definition temperature_delta_convert where
  "temperature_delta_convert a b x = x * temperature_scale a / temperature_scale b"
lemma temperature_scale_positive: "0 < temperature_scale u"
  by (cases u) simp_all
lemma temperature_conversion_refinement:
  "temperature_convert a b x = Some y \<longleftrightarrow>
    0 \<le> kelvin_point a x \<and> kelvin_point b y = kelvin_point a x"
  using temperature_scale_positive[of b]
  by (auto simp: temperature_convert_def kelvin_point_def Let_def field_simps split: if_splits)
lemma temperature_conversion_composes:
  assumes "temperature_convert a b x = Some y" "temperature_convert b c y = Some z"
  shows "temperature_convert a c x = Some z"
  using assms by (simp add: temperature_conversion_refinement)
lemma temperature_delta_refinement:
  "temperature_delta_convert a b x * temperature_scale b = x * temperature_scale a"
  using temperature_scale_positive[of b]
  by (simp add: temperature_delta_convert_def)

lemma temperature_delta_characterization:
  "temperature_delta_convert a b x = y \<longleftrightarrow>
    y * temperature_scale b = x * temperature_scale a"
  using temperature_scale_positive[of b]
  by (auto simp: temperature_delta_convert_def field_simps)

end
