theory Space_Tables
  imports "Veri7vn_Space_Base.Space_Base"
begin

text \<open>
  Constants and tables of the space family, transcribed from the shipped Oracle7
  organs (upstream/root/specialists/{orbits,planetary,spacecraft,spacecomms,
  astronomy}/organ_*.py and astronomy/nasa_planetary_factsheet.html).
  tables_check.py parses this file and the organ files and fails on any
  difference, so the tables cannot drift. Nothing here is computed: these are
  data.
\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

section \<open>Orbits: gravitational parameters, radii, sidereal periods\<close>

datatype obody = O_earth | O_moon | O_mars | O_sun | O_jupiter | O_venus

text \<open>The organ's BODY dictionary order (the body named first in the question
wins, ties broken by this order never arise because positions differ).\<close>
definition obody_order :: "obody list" where
  "obody_order = [O_earth, O_moon, O_mars, O_sun, O_jupiter, O_venus]"

text \<open>mu in km^3/s^2 (JPL / IAU).\<close>
fun mu :: "obody \<Rightarrow> rat" where
  "mu O_earth = 3986004418 / 10000"
| "mu O_moon = 4902800066 / 1000000"
| "mu O_mars = 4282837 / 100"
| "mu O_sun = 132712440018"
| "mu O_jupiter = 126686534"
| "mu O_venus = 32485859 / 100"

text \<open>Mean or equatorial radius in km.\<close>
fun brad :: "obody \<Rightarrow> rat" where
  "brad O_earth = 6378137 / 1000"
| "brad O_moon = 17374 / 10"
| "brad O_mars = 339619 / 100"
| "brad O_sun = 6957 * 100"
| "brad O_jupiter = 71492"
| "brad O_venus = 60518 / 10"

text \<open>Sidereal rotation period in seconds, where the organ has one.\<close>
fun sidereal :: "obody \<Rightarrow> rat option" where
  "sidereal O_earth = Some (861640905 / 10000)"
| "sidereal O_moon = Some (23605915 / 10)"
| "sidereal O_mars = Some (8864266 / 100)"
| "sidereal O_sun = None"
| "sidereal O_jupiter = Some 35730"
| "sidereal O_venus = None"

fun obody_name :: "obody \<Rightarrow> String.literal" where
  "obody_name O_earth = STR ''Earth''"
| "obody_name O_moon = STR ''Moon''"
| "obody_name O_mars = STR ''Mars''"
| "obody_name O_sun = STR ''Sun''"
| "obody_name O_jupiter = STR ''Jupiter''"
| "obody_name O_venus = STR ''Venus''"

lemma mu_pos [simp]: "0 < mu b"
  by (cases b) simp_all

lemma brad_pos [simp]: "0 < brad b"
  by (cases b) simp_all

lemma sidereal_pos: "sidereal b = Some t \<Longrightarrow> 0 < t"
  by (cases b) auto


section \<open>Planetary: constants\<close>

text \<open>G = 6.674e-11 N m2/kg2, g = 9.81 m/s2, Earth mass 5.972e24 kg and radius
6371 km (organ_planetary_v1).\<close>
definition grav_G :: rat where "grav_G = 6674 / 100000000000000"
definition grav_E :: rat where "grav_E = 981 / 100"
definition mass_E :: rat where "mass_E = 5972 * 1000000000000000000000"
definition radius_E :: rat where "radius_E = 6371000"

lemma grav_G_pos [simp]: "0 < grav_G" by (simp add: grav_G_def)


section \<open>Spacecraft and space communications: constants\<close>

text \<open>Standard gravity g0 = 9.80665 m/s2 (organ_spacecraft_v1).\<close>
definition std_g0 :: rat where "std_g0 = 980665 / 100000"

text \<open>c = 299,792.458 km/s and 1 AU = 149,597,870.7 km (organ_spacecomms_v1), a mile
is 1.609344 km, and the constant of the free-space path loss in dB.\<close>
definition light_c :: rat where "light_c = 299792458 / 1000"
definition au_km :: rat where "au_km = 1495978707 / 10"
definition mile_km :: rat where "mile_km = 1609344 / 1000000"
definition fspl_const :: rat where "fspl_const = 324478 / 10000"

lemma light_c_pos [simp]: "0 < light_c" by (simp add: light_c_def)


section \<open>Astronomy: NASA's Planetary Fact Sheet\<close>

datatype abody = A_mercury | A_venus | A_earth | A_moon | A_mars | A_jupiter | A_saturn
  | A_uranus | A_neptune | A_pluto

text \<open>The sheet's column order (the order the organ searches bodies in is by
position in the question).\<close>
definition abody_order :: "abody list" where
  "abody_order = [A_mercury, A_venus, A_earth, A_moon, A_mars, A_jupiter, A_saturn, A_uranus, A_neptune, A_pluto]"

fun abody_name :: "abody \<Rightarrow> String.literal" where
  "abody_name A_mercury = STR ''Mercury''"
| "abody_name A_venus = STR ''Venus''"
| "abody_name A_earth = STR ''Earth''"
| "abody_name A_moon = STR ''Moon''"
| "abody_name A_mars = STR ''Mars''"
| "abody_name A_jupiter = STR ''Jupiter''"
| "abody_name A_saturn = STR ''Saturn''"
| "abody_name A_uranus = STR ''Uranus''"
| "abody_name A_neptune = STR ''Neptune''"
| "abody_name A_pluto = STR ''Pluto''"

text \<open>The sheet's rows in order: Mass (1024kg), Diameter (km), Density (kg/m3),
Gravity (m/s2), Escape Velocity (km/s), Rotation Period (hours), Length of Day
(hours), Distance from Sun (106 km), Perihelion, Aphelion, Orbital Period (days),
Orbital Velocity (km/s), Orbital Inclination, Orbital Eccentricity, Obliquity to
Orbit, Mean Temperature (C), Surface Pressure (bars), Number of Moons, Ring
System?, Global Magnetic Field?.\<close>
datatype aprop = P_mass | P_diameter | P_density | P_gravity | P_escape | P_rotation | P_day
  | P_distance | P_perihelion | P_aphelion | P_period | P_velocity | P_inclination
  | P_eccentricity | P_tilt | P_temperature | P_pressure | P_moons | P_rings | P_magnetic

fun prop_index :: "aprop \<Rightarrow> nat" where
  "prop_index P_mass = 0" | "prop_index P_diameter = 1" | "prop_index P_density = 2"
| "prop_index P_gravity = 3" | "prop_index P_escape = 4" | "prop_index P_rotation = 5"
| "prop_index P_day = 6" | "prop_index P_distance = 7" | "prop_index P_perihelion = 8"
| "prop_index P_aphelion = 9" | "prop_index P_period = 10" | "prop_index P_velocity = 11"
| "prop_index P_inclination = 12" | "prop_index P_eccentricity = 13" | "prop_index P_tilt = 14"
| "prop_index P_temperature = 15" | "prop_index P_pressure = 16" | "prop_index P_moons = 17"
| "prop_index P_rings = 18" | "prop_index P_magnetic = 19"

text \<open>A sheet cell: the number as printed (with its thousands commas or the star
that marks a value relative to Earth, kept apart as the flag) and its value, a yes or no, or a value
NASA marks Unknown.\<close>
datatype cell = Cnum String.literal rat bool | Cword String.literal | Cunk String.literal

fun row :: "abody \<Rightarrow> cell list" where
  "row A_mercury = [
     Cnum (STR ''0.330'') (33 / 100) False,
     Cnum (STR ''4879'') (4879 / 1) False,
     Cnum (STR ''5429'') (5429 / 1) False,
     Cnum (STR ''3.7'') (37 / 10) False,
     Cnum (STR ''4.3'') (43 / 10) False,
     Cnum (STR ''1407.6'') (7038 / 5) False,
     Cnum (STR ''4222.6'') (21113 / 5) False,
     Cnum (STR ''57.9'') (579 / 10) False,
     Cnum (STR ''46.0'') (46 / 1) False,
     Cnum (STR ''69.8'') (349 / 5) False,
     Cnum (STR ''88.0'') (88 / 1) False,
     Cnum (STR ''47.4'') (237 / 5) False,
     Cnum (STR ''7.0'') (7 / 1) False,
     Cnum (STR ''0.206'') (103 / 500) False,
     Cnum (STR ''0.034'') (17 / 500) False,
     Cnum (STR ''167'') (167 / 1) False,
     Cnum (STR ''0'') (0 / 1) False,
     Cnum (STR ''0'') (0 / 1) False,
     Cword (STR ''No''),
     Cword (STR ''Yes'')]"
| "row A_venus = [
     Cnum (STR ''4.87'') (487 / 100) False,
     Cnum (STR ''12,104'') (12104 / 1) False,
     Cnum (STR ''5243'') (5243 / 1) False,
     Cnum (STR ''8.9'') (89 / 10) False,
     Cnum (STR ''10.4'') (52 / 5) False,
     Cnum (STR ''-5832.5'') ((-11665) / 2) False,
     Cnum (STR ''2802.0'') (2802 / 1) False,
     Cnum (STR ''108.2'') (541 / 5) False,
     Cnum (STR ''107.5'') (215 / 2) False,
     Cnum (STR ''108.9'') (1089 / 10) False,
     Cnum (STR ''224.7'') (2247 / 10) False,
     Cnum (STR ''35.0'') (35 / 1) False,
     Cnum (STR ''3.4'') (17 / 5) False,
     Cnum (STR ''0.007'') (7 / 1000) False,
     Cnum (STR ''177.4'') (887 / 5) False,
     Cnum (STR ''464'') (464 / 1) False,
     Cnum (STR ''92'') (92 / 1) False,
     Cnum (STR ''0'') (0 / 1) False,
     Cword (STR ''No''),
     Cword (STR ''No'')]"
| "row A_earth = [
     Cnum (STR ''5.97'') (597 / 100) False,
     Cnum (STR ''12,756'') (12756 / 1) False,
     Cnum (STR ''5514'') (5514 / 1) False,
     Cnum (STR ''9.8'') (49 / 5) False,
     Cnum (STR ''11.2'') (56 / 5) False,
     Cnum (STR ''23.9'') (239 / 10) False,
     Cnum (STR ''24.0'') (24 / 1) False,
     Cnum (STR ''149.6'') (748 / 5) False,
     Cnum (STR ''147.1'') (1471 / 10) False,
     Cnum (STR ''152.1'') (1521 / 10) False,
     Cnum (STR ''365.2'') (1826 / 5) False,
     Cnum (STR ''29.8'') (149 / 5) False,
     Cnum (STR ''0.0'') (0 / 1) False,
     Cnum (STR ''0.017'') (17 / 1000) False,
     Cnum (STR ''23.4'') (117 / 5) False,
     Cnum (STR ''15'') (15 / 1) False,
     Cnum (STR ''1'') (1 / 1) False,
     Cnum (STR ''1'') (1 / 1) False,
     Cword (STR ''No''),
     Cword (STR ''Yes'')]"
| "row A_moon = [
     Cnum (STR ''0.073'') (73 / 1000) False,
     Cnum (STR ''3475'') (3475 / 1) False,
     Cnum (STR ''3340'') (3340 / 1) False,
     Cnum (STR ''1.6'') (8 / 5) False,
     Cnum (STR ''2.4'') (12 / 5) False,
     Cnum (STR ''655.7'') (6557 / 10) False,
     Cnum (STR ''708.7'') (7087 / 10) False,
     Cnum (STR ''0.384'') (48 / 125) True,
     Cnum (STR ''0.363'') (363 / 1000) True,
     Cnum (STR ''0.406'') (203 / 500) True,
     Cnum (STR ''27.3'') (273 / 10) True,
     Cnum (STR ''1.0'') (1 / 1) True,
     Cnum (STR ''5.1'') (51 / 10) False,
     Cnum (STR ''0.055'') (11 / 200) False,
     Cnum (STR ''6.7'') (67 / 10) False,
     Cnum (STR ''-20'') ((-20) / 1) False,
     Cnum (STR ''0'') (0 / 1) False,
     Cnum (STR ''0'') (0 / 1) False,
     Cword (STR ''No''),
     Cword (STR ''No'')]"
| "row A_mars = [
     Cnum (STR ''0.642'') (321 / 500) False,
     Cnum (STR ''6792'') (6792 / 1) False,
     Cnum (STR ''3934'') (3934 / 1) False,
     Cnum (STR ''3.7'') (37 / 10) False,
     Cnum (STR ''5.0'') (5 / 1) False,
     Cnum (STR ''24.6'') (123 / 5) False,
     Cnum (STR ''24.7'') (247 / 10) False,
     Cnum (STR ''228.0'') (228 / 1) False,
     Cnum (STR ''206.7'') (2067 / 10) False,
     Cnum (STR ''249.3'') (2493 / 10) False,
     Cnum (STR ''687.0'') (687 / 1) False,
     Cnum (STR ''24.1'') (241 / 10) False,
     Cnum (STR ''1.8'') (9 / 5) False,
     Cnum (STR ''0.094'') (47 / 500) False,
     Cnum (STR ''25.2'') (126 / 5) False,
     Cnum (STR ''-65'') ((-65) / 1) False,
     Cnum (STR ''0.01'') (1 / 100) False,
     Cnum (STR ''2'') (2 / 1) False,
     Cword (STR ''No''),
     Cword (STR ''No'')]"
| "row A_jupiter = [
     Cnum (STR ''1898'') (1898 / 1) False,
     Cnum (STR ''142,984'') (142984 / 1) False,
     Cnum (STR ''1326'') (1326 / 1) False,
     Cnum (STR ''23.1'') (231 / 10) False,
     Cnum (STR ''59.5'') (119 / 2) False,
     Cnum (STR ''9.9'') (99 / 10) False,
     Cnum (STR ''9.9'') (99 / 10) False,
     Cnum (STR ''778.5'') (1557 / 2) False,
     Cnum (STR ''740.6'') (3703 / 5) False,
     Cnum (STR ''816.4'') (4082 / 5) False,
     Cnum (STR ''4331'') (4331 / 1) False,
     Cnum (STR ''13.1'') (131 / 10) False,
     Cnum (STR ''1.3'') (13 / 10) False,
     Cnum (STR ''0.049'') (49 / 1000) False,
     Cnum (STR ''3.1'') (31 / 10) False,
     Cnum (STR ''-110'') ((-110) / 1) False,
     Cunk (STR ''Unknown*''),
     Cnum (STR ''95'') (95 / 1) False,
     Cword (STR ''Yes''),
     Cword (STR ''Yes'')]"
| "row A_saturn = [
     Cnum (STR ''568'') (568 / 1) False,
     Cnum (STR ''120,536'') (120536 / 1) False,
     Cnum (STR ''687'') (687 / 1) False,
     Cnum (STR ''9.0'') (9 / 1) False,
     Cnum (STR ''35.5'') (71 / 2) False,
     Cnum (STR ''10.7'') (107 / 10) False,
     Cnum (STR ''10.7'') (107 / 10) False,
     Cnum (STR ''1432.0'') (1432 / 1) False,
     Cnum (STR ''1357.6'') (6788 / 5) False,
     Cnum (STR ''1506.5'') (3013 / 2) False,
     Cnum (STR ''10,747'') (10747 / 1) False,
     Cnum (STR ''9.7'') (97 / 10) False,
     Cnum (STR ''2.5'') (5 / 2) False,
     Cnum (STR ''0.052'') (13 / 250) False,
     Cnum (STR ''26.7'') (267 / 10) False,
     Cnum (STR ''-140'') ((-140) / 1) False,
     Cunk (STR ''Unknown*''),
     Cnum (STR ''274'') (274 / 1) False,
     Cword (STR ''Yes''),
     Cword (STR ''Yes'')]"
| "row A_uranus = [
     Cnum (STR ''86.8'') (434 / 5) False,
     Cnum (STR ''51,118'') (51118 / 1) False,
     Cnum (STR ''1270'') (1270 / 1) False,
     Cnum (STR ''8.7'') (87 / 10) False,
     Cnum (STR ''21.3'') (213 / 10) False,
     Cnum (STR ''-17.2'') ((-86) / 5) False,
     Cnum (STR ''17.2'') (86 / 5) False,
     Cnum (STR ''2867.0'') (2867 / 1) False,
     Cnum (STR ''2732.7'') (27327 / 10) False,
     Cnum (STR ''3001.4'') (15007 / 5) False,
     Cnum (STR ''30,589'') (30589 / 1) False,
     Cnum (STR ''6.8'') (34 / 5) False,
     Cnum (STR ''0.8'') (4 / 5) False,
     Cnum (STR ''0.047'') (47 / 1000) False,
     Cnum (STR ''97.8'') (489 / 5) False,
     Cnum (STR ''-195'') ((-195) / 1) False,
     Cunk (STR ''Unknown*''),
     Cnum (STR ''28'') (28 / 1) False,
     Cword (STR ''Yes''),
     Cword (STR ''Yes'')]"
| "row A_neptune = [
     Cnum (STR ''102'') (102 / 1) False,
     Cnum (STR ''49,528'') (49528 / 1) False,
     Cnum (STR ''1638'') (1638 / 1) False,
     Cnum (STR ''11.0'') (11 / 1) False,
     Cnum (STR ''23.5'') (47 / 2) False,
     Cnum (STR ''16.1'') (161 / 10) False,
     Cnum (STR ''16.1'') (161 / 10) False,
     Cnum (STR ''4515.0'') (4515 / 1) False,
     Cnum (STR ''4471.1'') (44711 / 10) False,
     Cnum (STR ''4558.9'') (45589 / 10) False,
     Cnum (STR ''59,800'') (59800 / 1) False,
     Cnum (STR ''5.4'') (27 / 5) False,
     Cnum (STR ''1.8'') (9 / 5) False,
     Cnum (STR ''0.010'') (1 / 100) False,
     Cnum (STR ''28.3'') (283 / 10) False,
     Cnum (STR ''-200'') ((-200) / 1) False,
     Cunk (STR ''Unknown*''),
     Cnum (STR ''16'') (16 / 1) False,
     Cword (STR ''Yes''),
     Cword (STR ''Yes'')]"
| "row A_pluto = [
     Cnum (STR ''0.0130'') (13 / 1000) False,
     Cnum (STR ''2376'') (2376 / 1) False,
     Cnum (STR ''1850'') (1850 / 1) False,
     Cnum (STR ''0.7'') (7 / 10) False,
     Cnum (STR ''1.3'') (13 / 10) False,
     Cnum (STR ''-153.3'') ((-1533) / 10) False,
     Cnum (STR ''153.3'') (1533 / 10) False,
     Cnum (STR ''5906.4'') (29532 / 5) False,
     Cnum (STR ''4436.8'') (22184 / 5) False,
     Cnum (STR ''7375.9'') (73759 / 10) False,
     Cnum (STR ''90,560'') (90560 / 1) False,
     Cnum (STR ''4.7'') (47 / 10) False,
     Cnum (STR ''17.2'') (86 / 5) False,
     Cnum (STR ''0.244'') (61 / 250) False,
     Cnum (STR ''119.5'') (239 / 2) False,
     Cnum (STR ''-225'') ((-225) / 1) False,
     Cnum (STR ''0.00001'') (1 / 100000) False,
     Cnum (STR ''5'') (5 / 1) False,
     Cword (STR ''No''),
     Cunk (STR ''Unknown'')]"

definition sheet :: "abody \<Rightarrow> aprop \<Rightarrow> cell" where
  "sheet b p = row b ! prop_index p"

definition is_unknown :: "cell \<Rightarrow> bool" where
  "is_unknown c = (case c of Cunk _ \<Rightarrow> True | _ \<Rightarrow> False)"

text \<open>The numeric value of a cell, where it has one (the organ's NUM: commas and the
star removed).\<close>
definition cell_num :: "cell \<Rightarrow> rat" where
  "cell_num c = (case c of Cnum _ v _ \<Rightarrow> v | _ \<Rightarrow> 0)"

definition grav_of :: "abody \<Rightarrow> rat" where "grav_of b = cell_num (sheet b P_gravity)"
definition dist_of :: "abody \<Rightarrow> rat" where "dist_of b = cell_num (sheet b P_distance)"
definition period_of :: "abody \<Rightarrow> rat" where "period_of b = cell_num (sheet b P_period)"

lemma row_length [simp]: "length (row b) = 20"
  by (cases b) simp_all

lemma grav_earth_pos: "0 < grav_of A_earth"
  by (simp add: grav_of_def sheet_def cell_num_def)

end
