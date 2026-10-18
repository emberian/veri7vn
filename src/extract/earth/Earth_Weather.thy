theory Earth_Weather
  imports Earth_Num
begin

text \<open>
  Oracle7 Meteorology & Weather (upstream/root/specialists/meteorology/organ_weather_v1.py):
  NWS heat index (Rothfusz regression with the NWS adjustments), NWS 2001 wind chill,
  dew point, air temperature and relative humidity (Magnus, b = 17.62, c = 243.12 C),
  Saffir-Simpson category, Beaufort force, and the ISA troposphere. Never a forecast.
  Coefficients and thresholds are HOL constants checked against the organ by
  tables_check.py.
\<close>

datatype tscale = TsF | TsC
datatype wunit = WMph | WKmh | WMs | WKn
datatype altunit = AltKm | AltM | AltFt
datatype rhwhy = RhBoth | RhWhich

datatype weather_req =
    WHeat "rat option" tscale "rat option"
  | WChill "rat option" tscale "rat option" wunit
  | WDew "rat option" tscale "rat option"
  | WAirT "rat option" tscale "rat option"
  | WRH "rat option" "rat option" rhwhy
  | WSaffir "rat option" wunit
  | WBeaufort "rat option" wunit
  | WIsa "rat option" altunit bool

definition mag_b :: rat where "mag_b = 1762 / 100"
definition mag_c :: rat where "mag_c = 24312 / 100"

definition to_f :: "rat \<Rightarrow> tscale \<Rightarrow> rat" where
  "to_f v u = (if u = TsF then v else v * 9 / 5 + 32)"
definition to_c :: "rat \<Rightarrow> tscale \<Rightarrow> rat" where
  "to_c v u = (if u = TsC then v else (v - 32) * 5 / 9)"

fun mph_of :: "wunit \<Rightarrow> rat \<Rightarrow> rat" where
  "mph_of WMph v = v"
| "mph_of WKmh v = v / (1609344 / 1000000)"
| "mph_of WMs v = v * (22369363 / 10000000)"
| "mph_of WKn v = v * (1150779 / 1000000)"

fun knots_of :: "wunit \<Rightarrow> rat \<Rightarrow> rat" where
  "knots_of WKn v = v"
| "knots_of WMph v = v / (1150779 / 1000000)"
| "knots_of WMs v = v * (1943844 / 1000000)"
| "knots_of WKmh v = v / (1852 / 1000)"

fun metres_of :: "altunit \<Rightarrow> rat \<Rightarrow> rat" where
  "metres_of AltKm v = v * 1000"
| "metres_of AltM v = v"
| "metres_of AltFt v = v * (3048 / 10000)"

text \<open>Python's @{text round} on a number: the nearest integer, ties to even.\<close>
definition rnd_even :: "rat \<Rightarrow> int" where
  "rnd_even q = (let f = \<lfloor>q\<rfloor>; d = q - of_int f in
     if d < 1 / 2 then f else if 1 / 2 < d then f + 1 else if even f then f else f + 1)"

lemma rnd_aux:
  fixes q :: rat and n :: int
  assumes "of_int n \<le> q + 1 / 2" "q - 1 / 2 \<le> of_int n"
  shows "\<bar>of_int n - q\<bar> \<le> 1 / 2"
proof (rule abs_leI)
  show "of_int n - q \<le> 1 / 2" using assms(1) by linarith
  show "- (of_int n - q) \<le> 1 / 2" using assms(2) by linarith
qed

theorem rnd_even_nearest: "\<bar>of_int (rnd_even q) - q\<bar> \<le> 1 / 2"
proof -
  define f where "f = \<lfloor>q\<rfloor>"
  have fc: "of_int f \<le> q \<and> q < of_int f + 1" unfolding f_def using floor_correct[of q] by simp
  have lo: "of_int f \<le> q" and hi: "q < of_int f + 1" using fc by auto
  have f1: "(of_int (f + 1) :: rat) = of_int f + 1" by simp
  have unf: "rnd_even q = (if q - of_int f < 1 / 2 then f else if 1 / 2 < q - of_int f then f + 1
                           else if even f then f else f + 1)"
    by (simp add: rnd_even_def Let_def f_def)
  show ?thesis
  proof (cases "q - of_int f < 1 / 2")
    case True
    have "rnd_even q = f" using unf True by simp
    moreover have "\<bar>of_int f - q\<bar> \<le> 1 / 2" by (rule rnd_aux) (use True lo in linarith)+
    ultimately show ?thesis by simp
  next
    assume nl: "\<not> q - of_int f < 1 / 2"
    show ?thesis
    proof (cases "1 / 2 < q - of_int f")
      case True
      have "rnd_even q = f + 1" using unf nl True by simp
      moreover have "\<bar>of_int (f + 1) - q\<bar> \<le> 1 / 2"
        by (rule rnd_aux) (use True hi f1 in linarith)+
      ultimately show ?thesis by simp
    next
      assume ng: "\<not> 1 / 2 < q - of_int f"
      have tie: "q - of_int f = 1 / 2" using nl ng by linarith
      show ?thesis
      proof (cases "even f")
        case True
        have "rnd_even q = f" using unf nl ng True by simp
        moreover have "\<bar>of_int f - q\<bar> \<le> 1 / 2" by (rule rnd_aux) (use tie in linarith)+
        ultimately show ?thesis by simp
      next
        case False
        have "rnd_even q = f + 1" using unf nl ng False by simp
        moreover have "\<bar>of_int (f + 1) - q\<bar> \<le> 1 / 2"
          by (rule rnd_aux) (use tie f1 in linarith)+
        ultimately show ?thesis by simp
      qed
    qed
  qed
qed

definition ss_cat :: "int \<Rightarrow> nat" where
  "ss_cat n = (if 157 \<le> n then 5 else if 130 \<le> n then 4 else if 111 \<le> n then 3
               else if 96 \<le> n then 2 else if 74 \<le> n then 1 else 0)"

definition bft_force :: "int \<Rightarrow> nat" where
  "bft_force n = (if 64 \<le> n then 12 else if 56 \<le> n then 11 else if 48 \<le> n then 10 else if 41 \<le> n then 9
     else if 34 \<le> n then 8 else if 28 \<le> n then 7 else if 22 \<le> n then 6 else if 17 \<le> n then 5
     else if 11 \<le> n then 4 else if 7 \<le> n then 3 else if 4 \<le> n then 2 else if 1 \<le> n then 1 else 0)"

section \<open>Heat index\<close>

definition heat_simple :: "rat \<Rightarrow> rat \<Rightarrow> rat" where
  "heat_simple t r = (1 / 2) * (t + 61 + (t - 68) * (6 / 5) + r * (94 / 1000))"

definition heat_poly :: "rat \<Rightarrow> rat \<Rightarrow> rat" where
  "heat_poly t r = - 42379 / 1000 + (204901523 / 100000000) * t + (1014333127 / 100000000) * r
     - (22475541 / 100000000) * t * r - (683783 / 100000000) * t * t - (5481717 / 100000000) * r * r
     + (122874 / 100000000) * t * t * r + (85282 / 100000000) * t * r * r
     - (199 / 100000000) * t * t * r * r"

definition heat_adj_dry :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "heat_adj_dry t r \<longleftrightarrow> r < 13 \<and> 80 \<le> t \<and> t \<le> 112"
definition heat_adj_wet :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "heat_adj_wet t r \<longleftrightarrow> 85 < r \<and> 80 \<le> t \<and> t \<le> 87"

definition heat_simple_branch :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "heat_simple_branch t r \<longleftrightarrow> (heat_simple t r + t) / 2 < 80"

definition heat_x :: "rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "heat_x t r =
     (if heat_simple_branch t r then XRat (heat_simple t r)
      else if heat_adj_dry t r then
        XFa dprec (fsub (Q (heat_poly t r))
          (floatarith.Mult (Q ((13 - r) / 4)) (floatarith.Sqrt (Q ((17 - \<bar>t - 95\<bar>) / 17)))))
      else if heat_adj_wet t r then XRat (heat_poly t r + ((r - 85) / 10) * ((87 - t) / 5))
      else XRat (heat_poly t r))"

definition heat_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "heat_spec t r =
     (if heat_simple_branch t r then rl (heat_simple t r)
      else if heat_adj_dry t r then
        rl (heat_poly t r) - rl ((13 - r) / 4) * sqrt (rl ((17 - \<bar>t - 95\<bar>) / 17))
      else if heat_adj_wet t r then rl (heat_poly t r) + rl ((r - 85) / 10) * rl ((87 - t) / 5)
      else rl (heat_poly t r))"

lemma heat_x_sem: "xsem (heat_x t r) = heat_spec t r"
  by (auto simp: heat_x_def heat_spec_def of_rat_diff of_rat_add of_rat_mult of_rat_divide split: if_splits)

section \<open>Wind chill\<close>

definition wc_defined :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "wc_defined t mph \<longleftrightarrow> t \<le> 50 \<and> 3 \<le> mph"

definition wc_x :: "rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "wc_x t v =
     (let p = floatarith.Powr (Q v) (Q (16 / 100)) in
      XFa 140 (floatarith.Add
        (floatarith.Add (Q (3574 / 100)) (floatarith.Mult (Q (6215 / 10000)) (Q t)))
        (floatarith.Add (floatarith.Minus (floatarith.Mult (Q (3575 / 100)) p))
                        (floatarith.Mult (floatarith.Mult (Q (4275 / 10000)) (Q t)) p))))"

definition wc_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "wc_spec t v = 35.74 + 0.6215 * rl t - 35.75 * (rl v powr 0.16) + 0.4275 * rl t * (rl v powr 0.16)"

lemma wc_x_sem: "xsem (wc_x t v) = wc_spec t v"
  by (simp add: wc_x_def wc_spec_def of_rat_divide Let_def)

section \<open>Magnus: dew point, air temperature, relative humidity\<close>

definition magnus_t :: "rat \<Rightarrow> rat" where "magnus_t t = mag_b * t / (mag_c + t)"

definition magnus_out :: "floatarith \<Rightarrow> xexpr" where
  "magnus_out g = XFa dprec (fdiv (floatarith.Mult (Q mag_c) g) (fsub (Q mag_b) g))"

definition dew_x :: "rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "dew_x t r = magnus_out (floatarith.Add (floatarith.Ln (Q (r / 100))) (Q (magnus_t t)))"

definition air_x :: "rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "air_x td r = magnus_out (fsub (Q (magnus_t td)) (floatarith.Ln (Q (r / 100))))"

definition rh_x :: "rat \<Rightarrow> rat \<Rightarrow> xexpr" where
  "rh_x t td = XFa dprec (floatarith.Mult (Q 100) (floatarith.Exp (Q (magnus_t td - magnus_t t))))"

definition dew_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "dew_spec t r = (let g = ln (rl r / 100) + rl (magnus_t t) in rl mag_c * g / (rl mag_b - g))"
definition air_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "air_spec td r = (let y = rl (magnus_t td) - ln (rl r / 100) in rl mag_c * y / (rl mag_b - y))"
definition rh_spec :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "rh_spec t td = 100 * exp (rl (magnus_t td) - rl (magnus_t t))"

lemma dew_x_sem: "xsem (dew_x t r) = dew_spec t r"
  by (simp add: dew_x_def magnus_out_def dew_spec_def of_rat_divide Let_def)
lemma air_x_sem: "xsem (air_x t r) = air_spec t r"
  by (simp add: air_x_def magnus_out_def air_spec_def of_rat_divide Let_def)
lemma rh_x_sem: "xsem (rh_x t td) = rh_spec t td"
  by (simp add: rh_x_def rh_spec_def of_rat_diff)

section \<open>ISA troposphere\<close>

definition isa_p_x :: "rat \<Rightarrow> xexpr" where
  "isa_p_x h = XFa dprec (floatarith.Mult (Q (101325 / 100))
      (floatarith.Powr (Q (1 - (225577 / 10000000000) * h)) (Q (525588 / 100000))))"
definition isa_p_spec :: "rat \<Rightarrow> real" where
  "isa_p_spec h = rl (101325 / 100) * (rl (1 - (225577 / 10000000000) * h) powr rl (525588 / 100000))"
lemma isa_p_x_sem: "xsem (isa_p_x h) = isa_p_spec h"
  by (simp add: isa_p_x_def isa_p_spec_def)

section \<open>Declines\<close>

definition w_temp_rh :: String.literal where "w_temp_rh = STR ''the air temperature and the relative humidity''"
definition w_temp_wind :: String.literal where "w_temp_wind = STR ''the air temperature and the wind speed''"

fun w_missing :: "weather_req \<Rightarrow> String.literal option" where
  "w_missing (WHeat t u r) = (if t = None \<or> r = None then Some w_temp_rh else None)"
| "w_missing (WChill t u v wu) = (if t = None \<or> v = None then Some w_temp_wind else None)"
| "w_missing (WDew t u r) = (if t = None \<or> r = None then Some w_temp_rh else None)"
| "w_missing (WAirT t u r) = (if t = None \<or> r = None then Some w_temp_rh else None)"
| "w_missing (WRH t td why) =
     (if t = None \<or> td = None then
        Some (case why of RhBoth \<Rightarrow> STR ''both the air temperature and the dew point''
                        | RhWhich \<Rightarrow> STR ''which temperature is the dew point'')
      else None)"
| "w_missing (WSaffir v wu) = (if v = None then Some (STR ''the maximum sustained wind speed'') else None)"
| "w_missing (WBeaufort v wu) = (if v = None then Some (STR ''a wind speed with its unit'') else None)"
| "w_missing (WIsa h au p) = (if h = None then Some (STR ''an altitude with its unit'') else None)"

definition w_range_h :: "rat \<Rightarrow> bool" where "w_range_h h \<longleftrightarrow> 0 \<le> h \<and> h \<le> 11000"

fun w_impossible :: "weather_req \<Rightarrow> String.literal option" where
  "w_impossible (WHeat (Some t) u (Some r)) =
     (if 0 \<le> r \<and> r \<le> 100 then None else Some (STR ''Relative humidity must be between 0 and 100%.''))"
| "w_impossible (WDew (Some t) u (Some r)) =
     (if 0 < r \<and> r \<le> 100 then (if mag_c + to_c t u = 0 then Some (STR ''That temperature is at the Magnus pole.'') else None)
      else Some (STR ''Relative humidity must be above 0 and at most 100%.''))"
| "w_impossible (WAirT (Some t) u (Some r)) =
     (if 0 < r \<and> r \<le> 100 then (if mag_c + to_c t u = 0 then Some (STR ''That temperature is at the Magnus pole.'') else None)
      else Some (STR ''Relative humidity must be above 0 and at most 100%.''))"
| "w_impossible (WRH (Some t) (Some td) why) =
     (if t < td then Some (STR ''The dew point can'' + apos + STR ''t be above the air temperature.'')
      else if mag_c + t = 0 \<or> mag_c + td = 0 then Some (STR ''That temperature is at the Magnus pole.'') else None)"
| "w_impossible _ = None"

fun w_range :: "weather_req \<Rightarrow> String.literal option" where
  "w_range (WIsa (Some h) au p) =
     (if w_range_h (metres_of au h) then None
      else Some (STR ''I only compute the ISA troposphere (0 to 11 km); '' + showx (GFix L4) (XRat (metres_of au h))
                 + STR '' m is outside it.''))"
| "w_range _ = None"

definition wc_undefined :: "weather_req \<Rightarrow> bool" where
  "wc_undefined r = (case r of WChill (Some t) u (Some v) wu \<Rightarrow> \<not> wc_defined (to_f t u) (mph_of wu v) | _ \<Rightarrow> False)"

section \<open>Values\<close>

definition out_unit :: "tscale \<Rightarrow> xexpr \<Rightarrow> xexpr" where
  "out_unit u x = (if u = TsC then affine_x (5 / 9) (- 160 / 9) x else x)"

definition out_unit_f :: "tscale \<Rightarrow> xexpr \<Rightarrow> xexpr" where
  "out_unit_f u x = (if u = TsF then affine_x (9 / 5) 32 x else x)"

fun w_xval :: "weather_req \<Rightarrow> xexpr" where
  "w_xval (WHeat (Some t) u (Some r)) = out_unit u (heat_x (to_f t u) r)"
| "w_xval (WChill (Some t) u (Some v) wu) = out_unit u (wc_x (to_f t u) (mph_of wu v))"
| "w_xval (WDew (Some t) u (Some r)) = out_unit_f u (dew_x (to_c t u) r)"
| "w_xval (WAirT (Some t) u (Some r)) = out_unit_f u (air_x (to_c t u) r)"
| "w_xval (WRH (Some t) (Some td) why) = rh_x t td"
| "w_xval (WSaffir (Some v) wu) = XRat (of_nat (ss_cat (rnd_even (mph_of wu v))))"
| "w_xval (WBeaufort (Some v) wu) = XRat (of_nat (bft_force (rnd_even (knots_of wu v))))"
| "w_xval (WIsa (Some h) au True) = isa_p_x (metres_of au h)"
| "w_xval (WIsa (Some h) au False) = XRat (15 - (13 / 2) * metres_of au h / 1000)"
| "w_xval _ = XRat 0"

definition out_spec :: "tscale \<Rightarrow> real \<Rightarrow> real" where
  "out_spec u x = (if u = TsC then (x - 32) * 5 / 9 else x)"
definition out_spec_f :: "tscale \<Rightarrow> real \<Rightarrow> real" where
  "out_spec_f u x = (if u = TsF then x * 9 / 5 + 32 else x)"

fun w_phys :: "weather_req \<Rightarrow> real" where
  "w_phys (WHeat (Some t) u (Some r)) = out_spec u (heat_spec (to_f t u) r)"
| "w_phys (WChill (Some t) u (Some v) wu) = out_spec u (wc_spec (to_f t u) (mph_of wu v))"
| "w_phys (WDew (Some t) u (Some r)) = out_spec_f u (dew_spec (to_c t u) r)"
| "w_phys (WAirT (Some t) u (Some r)) = out_spec_f u (air_spec (to_c t u) r)"
| "w_phys (WRH (Some t) (Some td) why) = rh_spec t td"
| "w_phys (WSaffir (Some v) wu) = real (ss_cat (rnd_even (mph_of wu v)))"
| "w_phys (WBeaufort (Some v) wu) = real (bft_force (rnd_even (knots_of wu v)))"
| "w_phys (WIsa (Some h) au True) = isa_p_spec (metres_of au h)"
| "w_phys (WIsa (Some h) au False) = 15 - 6.5 * rl (metres_of au h) / 1000"
| "w_phys _ = 0"

definition w_kernel :: "weather_req \<Rightarrow> outcome" where
  "w_kernel r = (case w_missing r of Some w \<Rightarrow> Decline (Under w)
     | None \<Rightarrow> (case w_impossible r of Some w \<Rightarrow> Decline (Imposs w)
        | None \<Rightarrow> (case w_range r of Some w \<Rightarrow> Decline (Range w)
           | None \<Rightarrow> (if wc_undefined r then Note else Value (w_xval r)))))"

theorem w_underspecified: "w_kernel r = Decline (Under w) \<longleftrightarrow> w_missing r = Some w"
  by (auto simp: w_kernel_def split: option.splits if_splits)

theorem w_impossible_iff:
  "w_kernel r = Decline (Imposs w) \<longleftrightarrow> w_missing r = None \<and> w_impossible r = Some w"
  by (auto simp: w_kernel_def split: option.splits if_splits)

theorem w_range_iff:
  "w_kernel r = Decline (Range w) \<longleftrightarrow> w_missing r = None \<and> w_impossible r = None \<and> w_range r = Some w"
  by (auto simp: w_kernel_def split: option.splits if_splits)

theorem w_wind_chill_undefined:
  "w_missing r = None \<Longrightarrow> w_impossible r = None \<Longrightarrow> w_range r = None \<Longrightarrow> wc_undefined r \<Longrightarrow> w_kernel r = Note"
  by (simp add: w_kernel_def)

lemma w_value_cases:
  "w_kernel r = Value x \<Longrightarrow> w_missing r = None \<and> w_impossible r = None \<and> w_range r = None \<and>
     \<not> wc_undefined r \<and> x = w_xval r"
  by (auto simp: w_kernel_def split: option.splits if_splits)

lemma w_not_word: "w_kernel r \<noteq> Word t"
  by (auto simp: w_kernel_def split: option.splits if_splits)

lemma out_unit_sem: "xsem (out_unit u x) = out_spec u (xsem x)"
proof (cases "u = TsC")
  case True
  have "xsem (out_unit u x) = rl (5 / 9) * xsem x + rl (- 160 / 9)" using True by (simp add: out_unit_def)
  also have "\<dots> = (xsem x - 32) * 5 / 9" by (simp add: of_rat_divide of_rat_minus; linarith)
  finally show ?thesis using True by (simp add: out_spec_def)
next
  case False
  then show ?thesis by (simp add: out_unit_def out_spec_def)
qed

lemma out_unit_f_sem: "xsem (out_unit_f u x) = out_spec_f u (xsem x)"
proof (cases "u = TsF")
  case True
  have "xsem (out_unit_f u x) = rl (9 / 5) * xsem x + rl 32" using True by (simp add: out_unit_f_def)
  also have "\<dots> = xsem x * 9 / 5 + 32" by (simp add: of_rat_divide; linarith)
  finally show ?thesis using True by (simp add: out_spec_f_def)
next
  case False
  then show ?thesis by (simp add: out_unit_f_def out_spec_f_def)
qed

theorem w_value_sound:
  assumes "w_kernel r = Value x"
  shows "xsem x = w_phys r"
proof -
  have c: "x = w_xval r" using w_value_cases[OF assms] by auto
  have "xsem (w_xval r) = w_phys r"
  proof (cases r)
    case (WHeat t u rr)
    then show ?thesis by (cases t; cases rr) (simp_all add: out_unit_sem heat_x_sem)
  next
    case (WChill t u v wu)
    then show ?thesis by (cases t; cases v) (simp_all add: out_unit_sem wc_x_sem)
  next
    case (WDew t u rr)
    then show ?thesis by (cases t; cases rr) (simp_all add: out_unit_f_sem dew_x_sem)
  next
    case (WAirT t u rr)
    then show ?thesis by (cases t; cases rr) (simp_all add: out_unit_f_sem air_x_sem)
  next
    case (WRH t td why)
    then show ?thesis by (cases t; cases td) (simp_all add: rh_x_sem)
  next
    case (WSaffir v wu)
    then show ?thesis by (cases v) simp_all
  next
    case (WBeaufort v wu)
    then show ?thesis by (cases v) simp_all
  next
    case (WIsa h au p)
    then show ?thesis
      by (cases h; cases p) (simp_all add: isa_p_x_sem of_rat_divide of_rat_diff of_rat_mult)
  qed
  then show ?thesis using c by simp
qed

section \<open>What each kind means\<close>

theorem rnd_even_class_saffir: "ss_cat n \<le> 5"
  by (simp add: ss_cat_def)

theorem ss_cat_monotone: "n \<le> m \<Longrightarrow> ss_cat n \<le> ss_cat m"
  by (auto simp: ss_cat_def)

theorem bft_force_monotone: "n \<le> m \<Longrightarrow> bft_force n \<le> bft_force m"
  by (auto simp: bft_force_def)

theorem ss_cat_hurricane_threshold: "ss_cat n \<ge> 1 \<longleftrightarrow> 74 \<le> n"
  by (auto simp: ss_cat_def)

lemma magnus_g_lt:
  fixes b c T L :: real
  assumes "0 < b" "0 < c" "- c < T" "L \<le> 0"
  shows "L + b * T / (c + T) < b"
proof -
  have ct: "0 < c + T" using assms(3) by linarith
  have "b * T < b * (c + T)" using assms(1,2) by (simp add: algebra_simps)
  then have "b * T / (c + T) < b" using ct by (simp add: divide_less_eq)
  then show ?thesis using assms(4) by linarith
qed

lemma dew_spec_real:
  "dew_spec t r = (let g = ln (rl r / 100) + rl mag_b * rl t / (rl mag_c + rl t) in rl mag_c * g / (rl mag_b - g))"
  by (simp add: dew_spec_def magnus_t_def of_rat_divide of_rat_mult of_rat_add)

lemma ln_nonpos:
  fixes x :: real
  assumes "0 < x" "x \<le> 1"
  shows "ln x \<le> 0"
proof -
  have "exp (ln x) \<le> exp 0" using assms(2) by (simp add: exp_ln[OF assms(1)])
  then show ?thesis by (rule iffD1[OF exp_le_cancel_iff])
qed

text \<open>The dew point never exceeds the air temperature (relative humidity at most 100%).\<close>
theorem dew_point_below_air:
  assumes "0 < r" "r \<le> 100" "- rl mag_c < rl t"
  shows "dew_spec t r \<le> rl t"
proof -
  define b where "b = rl mag_b"
  define c where "c = rl mag_c"
  have bpos: "0 < b" by (simp add: b_def mag_b_def)
  have cpos: "0 < c" by (simp add: c_def mag_c_def)
  have ct: "0 < c + rl t" using assms(3) c_def by linarith
  have rp: "(0::real) < rl r" using assms(1) by (simp add: zero_less_of_rat_iff)
  have rle: "(rl r :: real) \<le> rl 100" by (rule iffD2[OF of_rat_less_eq]) (use assms(2) in simp)
  have r100: "(rl r :: real) \<le> 100" using rle by simp
  have r0: "0 < rl r / 100" using rp by simp
  have r1: "rl r / 100 \<le> 1" using r100 by simp
  have lnr: "ln (rl r / 100) \<le> 0" by (rule ln_nonpos[OF r0 r1])
  define g where "g = ln (rl r / 100) + b * rl t / (c + rl t)"
  have gdef: "dew_spec t r = c * g / (b - g)"
    using dew_spec_real[of t r] by (simp add: g_def b_def c_def Let_def)
  have ctn: "- c < rl t" using assms(3) c_def by simp
  have gb: "g < b" unfolding g_def by (rule magnus_g_lt[OF bpos cpos ctn lnr])
  have bg: "0 < b - g" using gb by simp
  have gk: "g \<le> b * rl t / (c + rl t)" using lnr g_def by linarith
  have h1: "g * (c + rl t) \<le> b * rl t" by (rule iffD1[OF pos_le_divide_eq[OF ct] gk])
  have h2: "c * g \<le> rl t * (b - g)" using h1 by (simp add: algebra_simps)
  show ?thesis unfolding gdef by (rule iffD2[OF pos_divide_le_eq[OF bg]]) (rule h2)
qed

text \<open>Relative humidity recovered from the air temperature and the dew point computed
from a relative humidity (real arithmetic) is that relative humidity.\<close>
theorem dew_point_humidity_roundtrip:
  fixes b c T r :: real
  assumes "0 < b" "0 < c" "- c < T" "0 < r" "r \<le> 100"
  defines "g \<equiv> ln (r / 100) + b * T / (c + T)"
  defines "td \<equiv> c * g / (b - g)"
  shows "100 * exp (b * td / (c + td) - b * T / (c + T)) = r"
proof -
  have r0: "0 < r / 100" using assms(4) by simp
  have r1: "r / 100 \<le> 1" using assms(5) by simp
  have lnr: "ln (r / 100) \<le> 0" by (rule ln_nonpos[OF r0 r1])
  have gb: "g < b" unfolding g_def by (rule magnus_g_lt[OF assms(1,2,3) lnr])
  have bg: "b - g \<noteq> 0" using gb by simp
  have bne: "b \<noteq> 0" using assms(1) by simp
  have cne: "c \<noteq> 0" using assms(2) by simp
  have e1: "c + td = c * b / (b - g)"
  proof -
    have "c * b / (b - g) = (c * (b - g) + c * g) / (b - g)" by (simp add: algebra_simps)
    also have "\<dots> = c + c * g / (b - g)" using bg by (simp add: add_divide_distrib)
    finally show ?thesis unfolding td_def by simp
  qed
  have e2: "b * td / (c + td) = g"
  proof -
    have nz: "c + td \<noteq> 0" using e1 bg bne cne by simp
    have "b * td = g * (c + td)"
    proof -
      have "g * (c + td) = g * (c * b / (b - g))" using e1 by simp
      also have "\<dots> = b * (c * g / (b - g))" by (simp add: field_simps)
      finally show ?thesis unfolding td_def by simp
    qed
    then show ?thesis using nz by (simp add: eq_divide_imp divide_eq_eq)
  qed
  have e3: "g - b * T / (c + T) = ln (r / 100)" by (simp add: g_def)
  have "exp (b * td / (c + td) - b * T / (c + T)) = r / 100"
    using e2 e3 r0 by simp
  then show ?thesis by simp
qed

section \<open>Text\<close>

fun w_kind :: "weather_req \<Rightarrow> String.literal" where
  "w_kind (WHeat _ _ _) = STR ''heat_index''"
| "w_kind (WChill t u v wu) = (if wc_undefined (WChill t u v wu) then STR ''wc_undefined'' else STR ''wind_chill'')"
| "w_kind (WDew _ _ _) = STR ''dew_point''"
| "w_kind (WAirT _ _ _) = STR ''air_temperature''"
| "w_kind (WRH _ _ _) = STR ''relative_humidity''"
| "w_kind (WSaffir _ _) = STR ''saffir_simpson''"
| "w_kind (WBeaufort _ _) = STR ''beaufort''"
| "w_kind (WIsa _ _ p) = (if p then STR ''isa_pressure'' else STR ''isa_temperature'')"

definition wn :: "rat option \<Rightarrow> String.literal" where
  "wn q = (case q of Some v \<Rightarrow> showx (GFix L4) (XRat v) | None \<Rightarrow> STR ''?'')"

definition sx :: "xexpr \<Rightarrow> String.literal" where "sx x = showx (GFix L4) x"

definition unit_c :: "tscale \<Rightarrow> String.literal" where
  "unit_c u = (if u = TsC then STR '' C'' else STR '' F'')"

fun w_text :: "weather_req \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "w_text (WHeat (Some t) u (Some r)) V =
     (let tf = to_f t u; how = (if heat_simple_branch tf r then STR ''NWS simple formula (below 80 F)''
                                else STR ''NWS Rothfusz regression''); hx = heat_x tf r in
      if u = TsC then STR ''The heat index is '' + V + STR '' C ('' + sx hx + STR '' F; '' + how + STR '' at '' + sx (XRat tf)
        + STR '' F and '' + sx (XRat r) + STR ''% RH).''
      else STR ''The heat index is '' + V + STR '' F ('' + how + STR '' at '' + sx (XRat tf) + STR '' F and ''
        + sx (XRat r) + STR ''% RH).'')"
| "w_text (WChill (Some t) u (Some v) wu) V =
     (let tf = to_f t u; mph = mph_of wu v in
      if u = TsC then STR ''The wind chill is '' + V + STR '' C ('' + sx (wc_x tf mph) + STR '' F; NWS 2001 formula at ''
        + sx (XRat tf) + STR '' F, '' + sx (XRat mph) + STR '' mph).''
      else STR ''The wind chill is '' + V + STR '' F (NWS 2001 formula at '' + sx (XRat tf) + STR '' F, ''
        + sx (XRat mph) + STR '' mph).'')"
| "w_text (WDew (Some t) u (Some r)) V =
     (if u = TsF then STR ''The dew point is '' + V + STR '' F ('' + sx (dew_x (to_c t u) r)
        + STR '' C; Magnus formula, b = 17.62, c = 243.12 C).''
      else STR ''The dew point is '' + V + STR '' C (Magnus formula, b = 17.62, c = 243.12 C).'')"
| "w_text (WAirT (Some t) u (Some r)) V =
     (if u = TsF then STR ''The air temperature is '' + V + STR '' F ('' + sx (air_x (to_c t u) r)
        + STR '' C; Magnus formula solved for T from the dew point and '' + sx (XRat r) + STR ''% RH).''
      else STR ''The air temperature is '' + V + STR '' C (Magnus formula solved for T from the dew point and ''
        + sx (XRat r) + STR ''% RH).'')"
| "w_text (WRH (Some t) (Some td) why) V =
     STR ''The relative humidity is '' + V + STR ''% (Magnus formula, from '' + sx (XRat t) + STR '' C air and ''
     + sx (XRat td) + STR '' C dew point).''"
| "w_text (WSaffir (Some v) wu) V =
     (let mph = mph_of wu v; n = rnd_even mph in
      if 1 \<le> ss_cat n then STR ''That is a Category '' + V + STR '' hurricane (NHC Saffir-Simpson scale: ''
        + sx (XRat mph) + STR '' mph sustained).''
      else STR ''That is '' + (if 39 \<le> n then STR ''a tropical storm'' else STR ''a tropical depression'')
        + STR '', below hurricane strength (hurricanes start at 74 mph sustained; '' + sx (XRat mph) + STR '' mph given).'')"
| "w_text (WBeaufort (Some v) wu) V =
     STR ''That is Beaufort force '' + V + STR '' (WMO scale; '' + sx (XRat (knots_of wu v)) + STR '' knots).''"
| "w_text (WIsa (Some h) au True) V =
     STR ''The standard-atmosphere pressure is '' + V + STR '' hPa at '' + sx (XRat (metres_of au h))
     + STR '' m (ISA: p = 1013.25 (1 - 2.25577e-5 h)^5.25588).''"
| "w_text (WIsa (Some h) au False) V =
     STR ''The standard-atmosphere temperature is '' + V + STR '' C at '' + sx (XRat (metres_of au h))
     + STR '' m (ISA: 15 C - 6.5 C per km).''"
| "w_text r V = V"

definition wc_undef_text :: "weather_req \<Rightarrow> String.literal" where
  "wc_undef_text r = (case r of WChill (Some t) u (Some v) wu \<Rightarrow>
     STR ''Wind chill isn'' + apos + STR ''t defined there: the NWS formula applies only at or below 50 F with wind of at least 3 mph (you gave ''
     + sx (XRat (to_f t u)) + STR '' F, '' + sx (XRat (mph_of wu v)) + STR '' mph).''
   | _ \<Rightarrow> STR '''')"

definition w_reply :: "weather_req \<Rightarrow> reply" where
  "w_reply r = (case w_kernel r of
      Value x \<Rightarrow> reply_val (GFix L4) (w_kind r) (w_text r) x
    | Note \<Rightarrow> Reply True (w_kind r) (wc_undef_text r) None
    | Decline w \<Rightarrow> decline_reply (w_kind r) w
    | Word t \<Rightarrow> decline_reply (w_kind r) Imprecise)"

theorem w_answered_iff:
  "answered (w_reply r) \<longleftrightarrow>
     w_kernel r = Note \<or> (\<exists>x s. w_kernel r = Value x \<and> render_x (GFix L4) x = Some s)"
  using w_not_word[of r] by (cases "w_kernel r")
    (auto simp: w_reply_def reply_val_def decline_reply_def split: option.splits decl.splits)

end
