theory Earth_Geo
  imports Earth_Num
begin

text \<open>
  Oracle7 World Geography (upstream/root/specialists/geography/organ_geography_v1.py):
  capitals (with split capitals stated as split), great-circle distance by the
  haversine formula on the 6,371 km sphere, the antipode, solar time difference
  from longitude, and north-south distance. The capital tables are HOL constants
  transcribed from the organ and checked by tables_check.py.
\<close>

section \<open>Tables\<close>

definition cap_table :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "cap_table = [
    (STR ''afghanistan'', STR ''Afghanistan'', STR ''Kabul''),
    (STR ''argentina'', STR ''Argentina'', STR ''Buenos Aires''),
    (STR ''australia'', STR ''Australia'', STR ''Canberra''),
    (STR ''austria'', STR ''Austria'', STR ''Vienna''),
    (STR ''bangladesh'', STR ''Bangladesh'', STR ''Dhaka''),
    (STR ''belgium'', STR ''Belgium'', STR ''Brussels''),
    (STR ''brazil'', STR ''Brazil'', STR ''Brasilia''),
    (STR ''canada'', STR ''Canada'', STR ''Ottawa''),
    (STR ''chile'', STR ''Chile'', STR ''Santiago''),
    (STR ''china'', STR ''China'', STR ''Beijing''),
    (STR ''colombia'', STR ''Colombia'', STR ''Bogota''),
    (STR ''cuba'', STR ''Cuba'', STR ''Havana''),
    (STR ''czech republic'', STR ''Czech Republic'', STR ''Prague''),
    (STR ''czechia'', STR ''Czechia'', STR ''Prague''),
    (STR ''denmark'', STR ''Denmark'', STR ''Copenhagen''),
    (STR ''egypt'', STR ''Egypt'', STR ''Cairo''),
    (STR ''ethiopia'', STR ''Ethiopia'', STR ''Addis Ababa''),
    (STR ''finland'', STR ''Finland'', STR ''Helsinki''),
    (STR ''france'', STR ''France'', STR ''Paris''),
    (STR ''germany'', STR ''Germany'', STR ''Berlin''),
    (STR ''ghana'', STR ''Ghana'', STR ''Accra''),
    (STR ''greece'', STR ''Greece'', STR ''Athens''),
    (STR ''hungary'', STR ''Hungary'', STR ''Budapest''),
    (STR ''iceland'', STR ''Iceland'', STR ''Reykjavik''),
    (STR ''india'', STR ''India'', STR ''New Delhi''),
    (STR ''iran'', STR ''Iran'', STR ''Tehran''),
    (STR ''iraq'', STR ''Iraq'', STR ''Baghdad''),
    (STR ''ireland'', STR ''Ireland'', STR ''Dublin''),
    (STR ''italy'', STR ''Italy'', STR ''Rome''),
    (STR ''japan'', STR ''Japan'', STR ''Tokyo''),
    (STR ''kenya'', STR ''Kenya'', STR ''Nairobi''),
    (STR ''mexico'', STR ''Mexico'', STR ''Mexico City''),
    (STR ''morocco'', STR ''Morocco'', STR ''Rabat''),
    (STR ''nepal'', STR ''Nepal'', STR ''Kathmandu''),
    (STR ''new zealand'', STR ''New Zealand'', STR ''Wellington''),
    (STR ''nigeria'', STR ''Nigeria'', STR ''Abuja''),
    (STR ''north korea'', STR ''North Korea'', STR ''Pyongyang''),
    (STR ''norway'', STR ''Norway'', STR ''Oslo''),
    (STR ''pakistan'', STR ''Pakistan'', STR ''Islamabad''),
    (STR ''peru'', STR ''Peru'', STR ''Lima''),
    (STR ''philippines'', STR ''Philippines'', STR ''Manila''),
    (STR ''poland'', STR ''Poland'', STR ''Warsaw''),
    (STR ''portugal'', STR ''Portugal'', STR ''Lisbon''),
    (STR ''russia'', STR ''Russia'', STR ''Moscow''),
    (STR ''saudi arabia'', STR ''Saudi Arabia'', STR ''Riyadh''),
    (STR ''south korea'', STR ''South Korea'', STR ''Seoul''),
    (STR ''spain'', STR ''Spain'', STR ''Madrid''),
    (STR ''sweden'', STR ''Sweden'', STR ''Stockholm''),
    (STR ''switzerland'', STR ''Switzerland'', STR ''Bern''),
    (STR ''thailand'', STR ''Thailand'', STR ''Bangkok''),
    (STR ''turkey'', STR ''Turkey'', STR ''Ankara''),
    (STR ''ukraine'', STR ''Ukraine'', STR ''Kyiv''),
    (STR ''united kingdom'', STR ''United Kingdom'', STR ''London''),
    (STR ''uk'', STR ''UK'', STR ''London''),
    (STR ''united states'', STR ''United States'', STR ''Washington, D.C.''),
    (STR ''usa'', STR ''USA'', STR ''Washington, D.C.''),
    (STR ''venezuela'', STR ''Venezuela'', STR ''Caracas''),
    (STR ''vietnam'', STR ''Vietnam'', STR ''Hanoi''),
    (STR ''myanmar'', STR ''Myanmar'', STR ''Naypyidaw''),
    (STR ''kazakhstan'', STR ''Kazakhstan'', STR ''Astana''),
    (STR ''tanzania'', STR ''Tanzania'', STR ''Dodoma'')]"

definition split_table :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "split_table = [
    (STR ''south africa'', STR ''South Africa'', STR ''three capitals: Pretoria (executive), Cape Town (legislative) and Bloemfontein (judicial)''),
    (STR ''netherlands'', STR ''Netherlands'', STR ''Amsterdam (the constitutional capital); the government sits in The Hague''),
    (STR ''bolivia'', STR ''Bolivia'', STR ''Sucre (the constitutional capital); the seat of government is La Paz''),
    (STR ''sri lanka'', STR ''Sri Lanka'', STR ''Sri Jayawardenepura Kotte (the legislative capital); Colombo is the executive and commercial capital''),
    (STR ''cote d'' + apos + STR ''ivoire'', STR ''Cote D'' + apos + STR ''Ivoire'', STR ''Yamoussoukro (the official capital); Abidjan is the economic centre''),
    (STR ''ivory coast'', STR ''Ivory Coast'', STR ''Yamoussoukro (the official capital); Abidjan is the economic centre''),
    (STR ''indonesia'', STR ''Indonesia'', STR ''Jakarta, with a move to Nusantara in progress (check the current status)'')]"

fun tbl_find :: "String.literal \<Rightarrow> (String.literal \<times> String.literal \<times> String.literal) list \<Rightarrow>
    (String.literal \<times> String.literal) option" where
  "tbl_find c [] = None"
| "tbl_find c ((k, d, v) # rest) = (if c = k then Some (d, v) else tbl_find c rest)"

definition cap_text :: "String.literal \<Rightarrow> (String.literal \<times> String.literal) option" where
  "cap_text c = (case tbl_find c split_table of
      Some (d, v) \<Rightarrow> Some (STR ''capital_split'', d + STR '' has '' + v + STR ''.'')
    | None \<Rightarrow> (case tbl_find c cap_table of
        Some (d, v) \<Rightarrow> Some (STR ''capital'', STR ''The capital of '' + d + STR '' is '' + v + STR ''.'')
      | None \<Rightarrow> None))"

definition capital_known :: "String.literal \<Rightarrow> bool" where
  "capital_known c = (cap_text c \<noteq> None)"

section \<open>Requests\<close>

text \<open>Coordinates are in degrees, latitude first. @{text GGc} carries whether the
answer is asked in miles.\<close>
datatype geo_req =
    GCapital String.literal
  | GGc bool rat rat rat rat
  | GAntipode rat rat
  | GSolar rat rat
  | GLat rat rat

definition lat_ok :: "rat \<Rightarrow> bool" where
  "lat_ok p \<longleftrightarrow> - 90 \<le> p \<and> p \<le> 90"

definition earth_radius :: rat where "earth_radius = 6371"
definition km_per_mile :: rat where "km_per_mile = 1609344 / 1000000"
definition km_per_deg_lat :: rat where "km_per_deg_lat = 1112 / 10"

section \<open>The haversine distance\<close>

definition rad :: "rat \<Rightarrow> real" where "rad d = rl d * pi / 180"

text \<open>The haversine of the central angle between two points (radians).\<close>
definition hav :: "real \<Rightarrow> real \<Rightarrow> real \<Rightarrow> real \<Rightarrow> real" where
  "hav p1 l1 p2 l2 = (sin ((p2 - p1) / 2)) ^ 2 + cos p1 * cos p2 * (sin ((l2 - l1) / 2)) ^ 2"

lemma sin_half_sq: "(sin (y / 2)) ^ 2 = (1 - cos (y::real)) / 2"
proof -
  have "cos (2 * (y / 2)) = 1 - 2 * (sin (y / 2)) ^ 2" by (rule cos_double_sin)
  then show ?thesis by simp
qed

lemma hav_nonneg:
  assumes "- (pi / 2) \<le> p1" "p1 \<le> pi / 2" "- (pi / 2) \<le> p2" "p2 \<le> pi / 2"
  shows "0 \<le> hav p1 l1 p2 l2"
proof -
  have c1: "0 \<le> cos p1" using assms(1,2) by (rule cos_ge_zero)
  have c2: "0 \<le> cos p2" using assms(3,4) by (rule cos_ge_zero)
  have "0 \<le> cos p1 * cos p2 * (sin ((l2 - l1) / 2)) ^ 2" using c1 c2 by simp
  then show ?thesis by (simp add: hav_def)
qed

lemma hav_le_one:
  assumes "- (pi / 2) \<le> p1" "p1 \<le> pi / 2" "- (pi / 2) \<le> p2" "p2 \<le> pi / 2"
  shows "hav p1 l1 p2 l2 \<le> 1"
proof -
  define u where "u = (p2 - p1) / 2"
  have c1: "0 \<le> cos p1" using assms(1,2) by (rule cos_ge_zero)
  have c2: "0 \<le> cos p2" using assms(3,4) by (rule cos_ge_zero)
  have e1: "cos (p1 - p2) = cos p1 * cos p2 + sin p1 * sin p2" by (rule cos_diff)
  have e2: "cos (p1 + p2) = cos p1 * cos p2 - sin p1 * sin p2" by (rule cos_add)
  have e3: "cos (p1 - p2) = 2 * (cos u) ^ 2 - 1"
  proof -
    have "p1 - p2 = - (2 * u)" by (simp add: u_def field_simps)
    then have "cos (p1 - p2) = cos (2 * u)" by simp
    then show ?thesis by (simp add: cos_double_cos)
  qed
  have e4: "cos (p1 + p2) \<le> 1" by (rule cos_le_one)
  have prod: "cos p1 * cos p2 \<le> (cos u) ^ 2" using e1 e2 e3 e4 by linarith
  have sv: "(sin ((l2 - l1) / 2)) ^ 2 \<le> 1"
    using sin_cos_squared_add[of "(l2 - l1) / 2"] zero_le_power2[of "cos ((l2 - l1) / 2)"] by linarith
  have cc: "0 \<le> cos p1 * cos p2" using c1 c2 by simp
  have "cos p1 * cos p2 * (sin ((l2 - l1) / 2)) ^ 2 \<le> cos p1 * cos p2 * 1"
    by (rule mult_left_mono[OF sv cc])
  then have k: "cos p1 * cos p2 * (sin ((l2 - l1) / 2)) ^ 2 \<le> (cos u) ^ 2" using prod by simp
  have su: "(sin u) ^ 2 + (cos u) ^ 2 = 1" by (rule sin_cos_squared_add)
  have hv: "hav p1 l1 p2 l2 = (sin u) ^ 2 + cos p1 * cos p2 * (sin ((l2 - l1) / 2)) ^ 2"
    by (simp add: hav_def u_def)
  show ?thesis using hv k su by linarith
qed

text \<open>For @{text "0 \<le> a \<le> 1"} the number @{text "4 arctan (sqrt a / (1 + sqrt (1 - a)))"} is
the central angle @{text c}, with @{text "0 \<le> c \<le> pi"} and haversine @{text "sin(c/2)^2 = a"}.\<close>
lemma central_angle:
  assumes a0: "0 \<le> a" and a1: "a \<le> 1"
  defines "c \<equiv> 4 * arctan (sqrt a / (1 + sqrt (1 - a)))"
  shows "0 \<le> c \<and> c \<le> pi \<and> (sin (c / 2)) ^ 2 = a"
proof -
  define s where "s = sqrt a"
  define u where "u = sqrt (1 - a)"
  define t where "t = s / (1 + u)"
  have s0: "0 \<le> s" unfolding s_def by (rule real_sqrt_ge_zero[OF a0])
  have u0: "0 \<le> u" unfolding u_def by (rule real_sqrt_ge_zero) (use a1 in linarith)
  have s2: "s ^ 2 = a" using a0 by (simp add: s_def)
  have u2: "u ^ 2 = 1 - a" using a1 by (simp add: u_def)
  have su: "s ^ 2 + u ^ 2 = 1" using s2 u2 by simp
  have u2n: "0 \<le> u ^ 2" by simp
  have s1: "s \<le> 1"
  proof (rule ccontr)
    assume "\<not> s \<le> 1"
    then have "1 < s" by simp
    then have "1 < s ^ 2" by (rule one_less_power) simp_all
    then show False using su u2n by linarith
  qed
  have u1: "0 < 1 + u" using u0 by simp
  have ne: "1 + u \<noteq> 0" using u1 by simp
  have t0: "0 \<le> t" using s0 u1 by (simp add: t_def)
  have t1: "t \<le> 1"
  proof -
    have "s \<le> 1 + u" using s1 u0 by linarith
    then show ?thesis by (simp add: t_def divide_le_eq_1_pos[OF u1])
  qed
  have ceq: "c = 4 * arctan t" by (simp add: c_def t_def s_def u_def)
  have at0: "0 \<le> arctan t" using arctan_monotone'[OF t0] by simp
  have at1: "arctan t \<le> pi / 4" using arctan_monotone'[OF t1] by (simp add: arctan_one)
  have rng: "0 \<le> c \<and> c \<le> pi" using ceq at0 at1 by linarith
  have half: "c / 2 = 2 * arctan t" using ceq by simp
  have pos0: "0 < 1 + t ^ 2" using zero_le_power2[of t] by linarith
  have rne: "sqrt (1 + t ^ 2) \<noteq> 0" using pos0 by simp
  have sq: "(sqrt (1 + t ^ 2)) ^ 2 = 1 + t ^ 2" by (rule real_sqrt_pow2) simp
  have sn: "sin (c / 2) = 2 * t / (1 + t ^ 2)"
  proof -
    have "sin (c / 2) = 2 * sin (arctan t) * cos (arctan t)" using half by (simp add: sin_double)
    also have "\<dots> = 2 * (t / sqrt (1 + t ^ 2)) * (1 / sqrt (1 + t ^ 2))"
      by (simp add: sin_arctan cos_arctan)
    also have "\<dots> = 2 * t / (sqrt (1 + t ^ 2)) ^ 2" using rne by (simp add: power2_eq_square field_simps)
    also have "\<dots> = 2 * t / (1 + t ^ 2)" using sq by simp
    finally show ?thesis .
  qed
  have ht: "t * (1 + u) = s" using ne by (simp add: t_def)
  have st: "s * t = 1 - u"
  proof -
    have "(s * t) * (1 + u) = s * (t * (1 + u))" by (simp add: algebra_simps)
    also have "\<dots> = s ^ 2" using ht by (simp add: power2_eq_square)
    also have "\<dots> = (1 - u) * (1 + u)" using su by (simp add: power2_eq_square algebra_simps)
    finally show ?thesis using ne by simp
  qed
  have two: "(1 + u) * (1 + t ^ 2) = 2"
  proof -
    have "(1 + u) * (1 + t ^ 2) = (1 + u) + t * (t * (1 + u))" by (simp add: power2_eq_square algebra_simps)
    also have "\<dots> = (1 + u) + t * s" using ht by simp
    also have "\<dots> = 2" using st by (simp add: mult.commute)
    finally show ?thesis .
  qed
  have key: "s * (1 + t ^ 2) = 2 * t"
  proof -
    have "s * (1 + t ^ 2) = (t * (1 + u)) * (1 + t ^ 2)" using ht by simp
    also have "\<dots> = t * ((1 + u) * (1 + t ^ 2))" by (simp add: algebra_simps)
    also have "\<dots> = 2 * t" using two by simp
    finally show ?thesis .
  qed
  have pos: "1 + t ^ 2 \<noteq> 0" using pos0 by (rule less_imp_neq[THEN not_sym])
  have "2 * t / (1 + t ^ 2) = s" using key pos by (simp add: divide_eq_eq)
  then have "sin (c / 2) = s" using sn by simp
  then have "(sin (c / 2)) ^ 2 = a" using s2 by simp
  then show ?thesis using rng by blast
qed

definition rad_fa :: "rat \<Rightarrow> floatarith" where
  "rad_fa d = floatarith.Mult (floatarith.Mult (Q d) floatarith.Pi) (floatarith.Inverse (I 180))"

lemma interp_rad_fa [simp]: "interpret_floatarith (rad_fa d) xs = rad d"
proof -
  have "interpret_floatarith (rad_fa d) xs = rl d * pi * inverse 180" by (simp add: rad_fa_def)
  then show ?thesis by (simp add: rad_def inverse_eq_divide)
qed

definition hav_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "hav_fa p1 l1 p2 l2 =
     floatarith.Add
       (floatarith.Mult (Q (1 / 2)) (fsub (I 1) (floatarith.Cos (fsub (rad_fa p2) (rad_fa p1)))))
       (floatarith.Mult (floatarith.Mult (floatarith.Cos (rad_fa p1)) (floatarith.Cos (rad_fa p2)))
          (floatarith.Mult (Q (1 / 2)) (fsub (I 1) (floatarith.Cos (fsub (rad_fa l2) (rad_fa l1))))))"

lemma interp_hav_fa [simp]:
  "interpret_floatarith (hav_fa p1 l1 p2 l2) [] = hav (rad p1) (rad l1) (rad p2) (rad l2)"
proof -
  have a: "(sin ((rad p2 - rad p1) / 2)) ^ 2 = (1 - cos (rad p2 - rad p1)) / 2" by (rule sin_half_sq)
  have b: "(sin ((rad l2 - rad l1) / 2)) ^ 2 = (1 - cos (rad l2 - rad l1)) / 2" by (rule sin_half_sq)
  have hf: "rl (1 / 2) = (1 / 2 :: real)" by (simp add: of_rat_divide)
  show ?thesis by (simp add: hav_fa_def hav_def a b hf field_simps)
qed

definition central_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "central_fa p1 l1 p2 l2 =
     (let h = hav_fa p1 l1 p2 l2 in
      floatarith.Mult (I 4)
        (floatarith.Arctan
           (fdiv (floatarith.Sqrt (floatarith.Max (I 0) h))
                 (floatarith.Add (I 1) (floatarith.Sqrt (floatarith.Max (I 0) (fsub (I 1) h)))))))"

lemma lat_rad_range:
  assumes "lat_ok p"
  shows "- (pi / 2) \<le> rad p \<and> rad p \<le> pi / 2"
proof -
  have a1: "(of_rat (- 90) :: real) \<le> of_rat p"
    by (rule iffD2[OF of_rat_less_eq]) (use assms in \<open>simp add: lat_ok_def\<close>)
  have a2: "(of_rat p :: real) \<le> of_rat 90"
    by (rule iffD2[OF of_rat_less_eq]) (use assms in \<open>simp add: lat_ok_def\<close>)
  have b1: "- 90 \<le> rl p" using a1 by simp
  have b2: "rl p \<le> 90" using a2 by simp
  have pp: "0 < pi" by (rule pi_gt_zero)
  have m1: "rl p * pi \<le> 90 * pi" using b2 pp by (intro mult_right_mono) simp_all
  have m2: "- 90 * pi \<le> rl p * pi" using b1 pp by (intro mult_right_mono) simp_all
  show ?thesis using m1 m2 by (simp add: rad_def)
qed

lemma interp_central_fa:
  assumes "lat_ok p1" "lat_ok p2"
  shows "interpret_floatarith (central_fa p1 l1 p2 l2) [] =
         4 * arctan (sqrt (hav (rad p1) (rad l1) (rad p2) (rad l2)) /
                     (1 + sqrt (1 - hav (rad p1) (rad l1) (rad p2) (rad l2))))"
proof -
  have r1: "- (pi / 2) \<le> rad p1" "rad p1 \<le> pi / 2" using lat_rad_range[OF assms(1)] by auto
  have r2: "- (pi / 2) \<le> rad p2" "rad p2 \<le> pi / 2" using lat_rad_range[OF assms(2)] by auto
  have h0: "0 \<le> hav (rad p1) (rad l1) (rad p2) (rad l2)" by (rule hav_nonneg[OF r1(1) r1(2) r2(1) r2(2)])
  have h1: "hav (rad p1) (rad l1) (rad p2) (rad l2) \<le> 1" by (rule hav_le_one[OF r1(1) r1(2) r2(1) r2(2)])
  have m1: "max 0 (hav (rad p1) (rad l1) (rad p2) (rad l2)) = hav (rad p1) (rad l1) (rad p2) (rad l2)"
    by (rule max.absorb2[OF h0])
  have m2: "max 0 (1 - hav (rad p1) (rad l1) (rad p2) (rad l2)) = 1 - hav (rad p1) (rad l1) (rad p2) (rad l2)"
    by (rule max.absorb2) (use h1 in linarith)
  show ?thesis by (simp add: central_fa_def Let_def m1 m2)
qed

section \<open>The kernel\<close>

definition gc_x :: "bool \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "gc_x mi p1 l1 p2 l2 =
     XFa dprec (floatarith.Mult (Q (if mi then earth_radius / km_per_mile else earth_radius))
                  (central_fa p1 l1 p2 l2))"

definition antipode_of :: "rat \<Rightarrow> rat \<Rightarrow> rat \<times> rat" where
  "antipode_of la lo = (- la, if 0 < lo then lo - 180 else lo + 180)"

definition hemi :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "hemi v pos neg = (if 0 \<le> v then pos else neg)"

definition antipode_text :: "rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "antipode_text la lo = (case antipode_of la lo of (a, b) \<Rightarrow>
     STR ''The antipode is '' + showx (GFix (LP 2)) (XRat (abs a)) + STR '' deg '' + hemi a (STR ''N'') (STR ''S'')
     + STR '', '' + showx (GFix (LP 2)) (XRat (abs b)) + STR '' deg '' + hemi b (STR ''E'') (STR ''W'')
     + STR '' (latitude negated, longitude shifted by 180 deg).'')"

fun geo_kernel :: "geo_req \<Rightarrow> outcome" where
  "geo_kernel (GCapital c) = (case cap_text c of
      Some (_, t) \<Rightarrow> Word t
    | None \<Rightarrow> Decline (Imposs (STR ''I do not know that country.'')))"
| "geo_kernel (GGc mi p1 l1 p2 l2) =
     (if lat_ok p1 \<and> lat_ok p2 then Value (gc_x mi p1 l1 p2 l2)
      else Decline (Imposs (STR ''A latitude must be between -90 and 90 degrees.'')))"
| "geo_kernel (GAntipode la lo) =
     (if lat_ok la then Word (antipode_text la lo)
      else Decline (Imposs (STR ''A latitude must be between -90 and 90 degrees.'')))"
| "geo_kernel (GSolar a b) = Value (XRat (abs (a - b) / 15))"
| "geo_kernel (GLat a b) = Value (XRat (abs (a - b) * km_per_deg_lat))"

fun geo_kind :: "geo_req \<Rightarrow> String.literal" where
  "geo_kind (GCapital c) = (case cap_text c of Some (k, _) \<Rightarrow> k | None \<Rightarrow> STR ''capital'')"
| "geo_kind (GGc mi _ _ _ _) = (if mi then STR ''gc_miles'' else STR ''gc_km'')"
| "geo_kind (GAntipode _ _) = STR ''antipode''"
| "geo_kind (GSolar _ _) = STR ''solar_time''"
| "geo_kind (GLat _ _) = STR ''lat_km''"

fun geo_text :: "geo_req \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "geo_text (GGc mi p1 l1 p2 l2) V =
     (if mi then STR ''The great-circle distance is '' + V + STR '' miles ('' + showx (GFix (LP 2)) (gc_x False p1 l1 p2 l2)
        + STR '' km; haversine, mean Earth radius 6,371 km).''
      else STR ''The great-circle distance is '' + V + STR '' km (haversine, mean Earth radius 6,371 km).'')"
| "geo_text (GSolar a b) V = STR ''The solar time difference is '' + V + STR '' hours ('' + showx (GFix (LP 2)) (XRat (abs (a - b)))
     + STR '' deg of longitude / 15 deg per hour; civil time zones differ).''"
| "geo_text (GLat a b) V = STR ''The north-south distance is '' + V + STR '' km ('' + showx (GFix (LP 2)) (XRat (abs (a - b)))
     + STR '' deg x 111.2 km per degree of latitude).''"
| "geo_text r V = V"

definition geo_reply :: "geo_req \<Rightarrow> reply" where
  "geo_reply r = (case geo_kernel r of
      Value x \<Rightarrow> reply_val (GFix (LP 2)) (geo_kind r) (geo_text r) x
    | Word t \<Rightarrow> Reply True (geo_kind r) t None
    | Note \<Rightarrow> Reply True (geo_kind r) (STR '''') None
    | Decline w \<Rightarrow> decline_reply (geo_kind r) w)"

section \<open>What each kind means\<close>

text \<open>The great-circle distance in kilometres is the sphere's radius times a central angle
@{text c} between 0 and pi whose haversine @{text "sin(c/2)^2"} is the haversine formula's
value for the two points; in miles it is that distance over 1.609344.\<close>
theorem gc_sound:
  assumes "geo_kernel (GGc mi p1 l1 p2 l2) = Value x"
  shows "lat_ok p1 \<and> lat_ok p2 \<and>
    (\<exists>c. 0 \<le> c \<and> c \<le> pi \<and> (sin (c / 2)) ^ 2 = hav (rad p1) (rad l1) (rad p2) (rad l2) \<and>
         xsem x * (if mi then rl km_per_mile else 1) = rl earth_radius * c)"
proof -
  have ok: "lat_ok p1" "lat_ok p2" using assms by (auto split: if_splits)
  have x: "x = gc_x mi p1 l1 p2 l2" using assms ok by simp
  define h where "h = hav (rad p1) (rad l1) (rad p2) (rad l2)"
  have r1: "- (pi / 2) \<le> rad p1" "rad p1 \<le> pi / 2" using lat_rad_range[OF ok(1)] by auto
  have r2: "- (pi / 2) \<le> rad p2" "rad p2 \<le> pi / 2" using lat_rad_range[OF ok(2)] by auto
  have h0: "0 \<le> h" unfolding h_def by (rule hav_nonneg[OF r1(1) r1(2) r2(1) r2(2)])
  have h1: "h \<le> 1" unfolding h_def by (rule hav_le_one[OF r1(1) r1(2) r2(1) r2(2)])
  define c where "c = 4 * arctan (sqrt h / (1 + sqrt (1 - h)))"
  have cc: "0 \<le> c \<and> c \<le> pi \<and> (sin (c / 2)) ^ 2 = h" unfolding c_def by (rule central_angle[OF h0 h1])
  have e: "interpret_floatarith (central_fa p1 l1 p2 l2) [] = c"
    using interp_central_fa[OF ok] by (simp add: c_def h_def)
  have kz: "rl km_per_mile \<noteq> 0" by (simp add: km_per_mile_def)
  have xs: "xsem x = rl (if mi then earth_radius / km_per_mile else earth_radius) * c"
    using x e by (simp add: gc_x_def)
  have fin: "xsem x * (if mi then rl km_per_mile else 1) = rl earth_radius * c"
    using xs kz by (cases mi) (simp_all add: of_rat_divide field_simps)
  show ?thesis
    by (intro conjI exI[of _ c]) (use ok cc fin in \<open>simp_all add: h_def\<close>)
qed

theorem antipode_sound:
  assumes "- 180 \<le> lo" "lo \<le> 180" "antipode_of la lo = (la', lo')"
  shows "la' = - la \<and> - 180 \<le> lo' \<and> lo' \<le> 180 \<and> \<bar>lo' - lo\<bar> = 180"
proof (cases "0 < lo")
  case True
  have e1: "la' = - la" and e2: "lo' = lo - 180" using assms(3) True by (auto simp: antipode_of_def)
  have d: "lo' - lo = - 180" using e2 by linarith
  show ?thesis
  proof (intro conjI)
    show "la' = - la" by (rule e1)
    show "- 180 \<le> lo'" using e2 True by linarith
    show "lo' \<le> 180" using e2 assms(2) by linarith
    show "\<bar>lo' - lo\<bar> = 180" using d by simp
  qed
next
  case False
  have lo0: "lo \<le> 0" using False by simp
  have e1: "la' = - la" and e2: "lo' = lo + 180" using assms(3) False by (auto simp: antipode_of_def)
  have d: "lo' - lo = 180" using e2 by linarith
  show ?thesis
  proof (intro conjI)
    show "la' = - la" by (rule e1)
    show "- 180 \<le> lo'" using e2 assms(1) by linarith
    show "lo' \<le> 180" using e2 lo0 by linarith
    show "\<bar>lo' - lo\<bar> = 180" using d by simp
  qed
qed

theorem antipode_involution:
  assumes "- 180 < lo" "lo < 180" "antipode_of la lo = (la', lo')"
  shows "antipode_of la' lo' = (la, lo)"
proof (cases "0 < lo")
  case True
  have e1: "la' = - la" and e2: "lo' = lo - 180" using assms(3) True by (auto simp: antipode_of_def)
  have "\<not> 0 < lo'" using e2 assms(2) by linarith
  then show ?thesis using e1 e2 by (simp add: antipode_of_def)
next
  case False
  have e1: "la' = - la" and e2: "lo' = lo + 180" using assms(3) False by (auto simp: antipode_of_def)
  have "0 < lo'" using e2 assms(1) by linarith
  then show ?thesis using e1 e2 by (simp add: antipode_of_def)
qed

theorem solar_time_sound:
  "geo_kernel (GSolar a b) = Value (XRat h) \<Longrightarrow> h * 15 = abs (a - b) \<and> 0 \<le> h"
  by auto

theorem lat_distance_sound:
  assumes "geo_kernel (GLat a b) = Value (XRat d)"
  shows "d = abs (a - b) * (1112 / 10) \<and> 0 \<le> d"
proof -
  have d: "d = abs (a - b) * (1112 / 10)" using assms by (simp add: km_per_deg_lat_def)
  have "0 \<le> abs (a - b) * (1112 / 10)" by (rule mult_nonneg_nonneg) simp_all
  show ?thesis
  proof (intro conjI)
    show "d = abs (a - b) * (1112 / 10)" by (rule d)
    show "0 \<le> d" using d \<open>0 \<le> abs (a - b) * (1112 / 10)\<close> by linarith
  qed
qed

theorem capital_split_stated:
  "cap_text c = Some (STR ''capital_split'', t) \<Longrightarrow> \<exists>d v. tbl_find c split_table = Some (d, v)"
  by (auto simp: cap_text_def split: option.splits)

lemma geo_kernel_not_note: "geo_kernel r \<noteq> Note"
  by (cases r) (auto split: option.splits prod.splits)

theorem geo_answered_iff:
  "answered (geo_reply r) \<longleftrightarrow>
     (\<exists>t. geo_kernel r = Word t) \<or> (\<exists>x s. geo_kernel r = Value x \<and> render_x (GFix (LP 2)) x = Some s)"
proof -
  have nn: "geo_kernel r \<noteq> Note" by (rule geo_kernel_not_note)
  show ?thesis using nn
    by (cases "geo_kernel r") (auto simp: geo_reply_def reply_val_def decline_reply_def split: option.splits decl.splits)
qed

theorem geo_declines_impossible:
  "(\<exists>w. geo_kernel r = Decline w) \<longleftrightarrow>
     (case r of GCapital c \<Rightarrow> \<not> capital_known c
              | GGc _ p1 _ p2 _ \<Rightarrow> \<not> (lat_ok p1 \<and> lat_ok p2)
              | GAntipode la _ \<Rightarrow> \<not> lat_ok la
              | _ \<Rightarrow> False)"
  by (cases r) (auto simp: capital_known_def split: option.splits prod.splits)

end
