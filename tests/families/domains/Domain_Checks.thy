theory Domain_Checks
  imports Quantity_Specialists
begin
lemma exact_source_examples:
  "linear_convert Millimetre Inch 94 = Some (470/127)"
  "linear_convert Week Minute 435 = Some 4384800"
  "linear_convert GallonUS Litre 1 = Some (473176473/125000000)"
  "linear_convert Psi Pascal 1 = Some ((45359237/100000000)*(196133/20000)/(127/5000)^2)"
  "linear_convert Metre Kilogram 1 = None"
  by eval+
lemma affine_point_delta_cases:
  "temperature_convert Celsius Fahrenheit 0 = Some 32"
  "temperature_delta_convert Celsius Fahrenheit 10 = 18"
  "temperature_convert Celsius Kelvin (-5463/20) = Some 0"
  "temperature_convert Kelvin Celsius (-1) = None"
  "domain_dispatch (ConvertPoint Celsius Fahrenheit) [DeltaValue Celsius 10] = None"
  by eval+
lemma spring_cases:
  "spring_kernel SpringForce 200 (1/10) = Some 20"
  "spring_kernel SpringExtension 200 20 = Some (1/10)"
  "spring_kernel SpringStiffness 20 (1/10) = Some 200"
  "spring_kernel SpringEnergy 200 (1/10) = Some 1"
  "spring_kernel SpringExtension 0 20 = None"
  "spring_kernel SpringStiffness 20 0 = None"
  "spring_kernel SpringForce (-1) 2 = None"
  by eval+
end
