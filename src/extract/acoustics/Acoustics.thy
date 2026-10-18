theory Acoustics
  imports "Veri7vn_Acoustics_Base.Acoustics_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>
  The Oracle7 acoustics specialist (upstream organ_acoustics_v1.py) as a
  verified HOL kernel. A typed request (what the question asks, with its
  numbers already read off) goes to an outcome: a value of a named kind, or a
  decline. This file holds

  \<^item> the physical model over the real numbers (@{text phys}), with the
    defining equations proved for every kind,
  \<^item> the decline predicates @{text missing} (underspecified) and
    @{text impossible}, the latter stated with real square roots,
  \<^item> the executable kernel, which encloses the model value in a float
    interval with Isabelle's verified interval arithmetic and rounds it to four
    significant decimal digits, and its soundness theorems,
  \<^item> the response text, rendered by HOL functions (ASCII only).

  The English recognizer that produces requests is not here; it is
  hand-ported SML and untrusted.
\<close>

section \<open>Requests and outcomes\<close>

datatype direction = Toward | Away | Unclear
datatype mover = Source | Listener
datatype lunit = Metre | Centimetre
datatype funit = Hz | KHz

text \<open>Where the speed of sound comes from: a stated speed, dry air at a stated
temperature in degrees C, or air at 20 C when the question gives neither.\<close>
datatype medium = Stated rat | AirAt rat | AirDefault

datatype request =
    Beat "rat option" "rat option"
  | Doppler "rat option" "rat option" mover direction medium
  | DbSum "rat list"
  | DbTwoEqual rat
  | DbDistance rat rat rat
  | DbRatio rat
  | IntensityRatio rat rat
  | StringHarmonic nat "(rat \<times> lunit) option" "rat option"
  | PipeClosed nat "(rat \<times> lunit) option" medium
  | PipeOpen nat "(rat \<times> lunit) option" medium
  | Wavelength "(rat \<times> funit) option" medium
  | Frequency "rat \<times> lunit" medium
  | SpeedAir medium
  | SpeedWater

datatype need = Both_Frequencies | Doppler_Inputs | Doppler_Direction | Two_Levels
  | Length | Wave_Speed | A_Frequency

datatype reason = Below_Absolute_Zero | Nonpositive_Speed | Nonpositive_Frequency
  | Negative_Speed | Shock_Wave | Outruns_Sound | Nonpositive_Distance | Nonpositive_Ratio
  | Nonpositive_Length | Zero_Harmonic | Even_Closed_Harmonic nat | Nonpositive_Wavelength

datatype decline = Underspecified need | Impossible reason | Imprecise

datatype kind = K_beat | K_doppler | K_db_sum | K_db_distance | K_db_ratio
  | K_intensity_ratio | K_string | K_pipe_closed | K_pipe_open | K_wavelength
  | K_frequency | K_speed

text \<open>A value is a decimal @{text "(m, e)"} meaning @{text "m * 10^e"}.\<close>
datatype outcome = Value kind "int \<times> int" | Decline decline

fun kind_of :: "request \<Rightarrow> kind" where
  "kind_of (Beat _ _) = K_beat"
| "kind_of (Doppler _ _ _ _ _) = K_doppler"
| "kind_of (DbSum _) = K_db_sum"
| "kind_of (DbTwoEqual _) = K_db_sum"
| "kind_of (DbDistance _ _ _) = K_db_distance"
| "kind_of (DbRatio _) = K_db_ratio"
| "kind_of (IntensityRatio _ _) = K_intensity_ratio"
| "kind_of (StringHarmonic _ _ _) = K_string"
| "kind_of (PipeClosed _ _ _) = K_pipe_closed"
| "kind_of (PipeOpen _ _ _) = K_pipe_open"
| "kind_of (Wavelength _ _) = K_wavelength"
| "kind_of (Frequency _ _) = K_frequency"
| "kind_of (SpeedAir _) = K_speed"
| "kind_of SpeedWater = K_speed"


section \<open>The physical model over the reals\<close>

definition len :: "rat \<times> lunit \<Rightarrow> rat" where
  "len p = (case p of (x, Metre) \<Rightarrow> x | (x, Centimetre) \<Rightarrow> x / 100)"

definition hz :: "rat \<times> funit \<Rightarrow> rat" where
  "hz p = (case p of (x, Hz) \<Rightarrow> x | (x, KHz) \<Rightarrow> 1000 * x)"

text \<open>Speed of sound in dry air at temperature T (degrees C).\<close>
definition air_speed :: "real \<Rightarrow> real" where
  "air_speed T = 331.3 * sqrt (1 + T / 273.15)"

fun speed :: "medium \<Rightarrow> real" where
  "speed (Stated v) = rl v"
| "speed (AirAt T) = air_speed (rl T)"
| "speed AirDefault = air_speed 20"

fun medium_ok :: "medium \<Rightarrow> bool" where
  "medium_ok (Stated v) \<longleftrightarrow> 0 < v"
| "medium_ok (AirAt T) \<longleftrightarrow> - 27315 / 100 < T"
| "medium_ok AirDefault \<longleftrightarrow> True"

lemma rl_temp: "- 27315 / 100 < T \<longleftrightarrow> - 273.15 < rl T"
proof -
  have "rl (- 27315 / 100) = - 273.15" by (simp add: of_rat_divide of_rat_minus)
  then show ?thesis using of_rat_less[of "- 27315 / 100" T, where 'a = real] by simp
qed

lemma speed_pos: "medium_ok s \<Longrightarrow> 0 < speed s"
proof (cases s)
  case (AirAt T)
  assume "medium_ok s"
  then have "- 273.15 < rl T" using AirAt rl_temp by simp
  then have "0 < 1 + rl T / 273.15" by (simp add: field_simps)
  then show ?thesis using AirAt by (simp add: air_speed_def real_sqrt_gt_zero)
qed (auto simp: air_speed_def real_sqrt_gt_zero zero_less_of_rat_iff)

text \<open>The model value of each request. Patterns are the same as in the
executable expression below, so the two agree everywhere.\<close>
fun phys :: "request \<Rightarrow> real" where
  "phys (Beat (Some a) (Some b)) = \<bar>rl a - rl b\<bar>"
| "phys (Doppler (Some f) (Some u) Source Toward s) = rl f * speed s / (speed s - rl u)"
| "phys (Doppler (Some f) (Some u) Source Away s) = rl f * speed s / (speed s + rl u)"
| "phys (Doppler (Some f) (Some u) Listener Toward s) = rl f * (speed s + rl u) / speed s"
| "phys (Doppler (Some f) (Some u) Listener Away s) = rl f * (speed s - rl u) / speed s"
| "phys (DbSum ls) = 10 * log 10 (\<Sum>l\<leftarrow>ls. 10 powr (rl l / 10))"
| "phys (DbTwoEqual l) = rl l + 10 * log 10 2"
| "phys (DbDistance l r1 r2) = rl l - 20 * log 10 (rl r2 / rl r1)"
| "phys (DbRatio k) = 10 * log 10 (rl k)"
| "phys (IntensityRatio l1 l2) = 10 powr ((rl l1 - rl l2) / 10)"
| "phys (StringHarmonic n (Some L) (Some v)) = real n * rl v / (2 * rl (len L))"
| "phys (PipeClosed n (Some L) s) = real n * speed s / (4 * rl (len L))"
| "phys (PipeOpen n (Some L) s) = real n * speed s / (2 * rl (len L))"
| "phys (Wavelength (Some f) s) = speed s / rl (hz f)"
| "phys (Frequency L s) = speed s / rl (len L)"
| "phys (SpeedAir s) = speed s"
| "phys SpeedWater = 1481"
| "phys _ = 0"


section \<open>Declines\<close>

text \<open>Underspecified: a value the formula needs is absent.\<close>
fun missing :: "request \<Rightarrow> need option" where
  "missing (Beat a b) = (if a = None \<or> b = None then Some Both_Frequencies else None)"
| "missing (Doppler f u m d s) =
     (if f = None \<or> u = None then Some Doppler_Inputs
      else if d = Unclear then Some Doppler_Direction else None)"
| "missing (DbSum ls) = (if length ls < 2 then Some Two_Levels else None)"
| "missing (StringHarmonic n L v) =
     (if L = None then Some Length else if v = None then Some Wave_Speed else None)"
| "missing (PipeClosed n L s) = (if L = None then Some Length else None)"
| "missing (PipeOpen n L s) = (if L = None then Some Length else None)"
| "missing (Wavelength f s) = (if f = None then Some A_Frequency else None)"
| "missing _ = None"

text \<open>Impossible: the inputs describe no physical situation the formula
covers. The Doppler clause compares with the real speed of sound, a square
root; the kernel decides it exactly (lemma @{text reach_iff}).\<close>
fun impossible :: "request \<Rightarrow> bool" where
  "impossible (Beat (Some a) (Some b)) \<longleftrightarrow> a \<le> 0 \<or> b \<le> 0"
| "impossible (Doppler (Some f) (Some u) m d s) \<longleftrightarrow>
     \<not> medium_ok s \<or> f \<le> 0 \<or> u < 0 \<or> (speed s \<le> rl u \<and> (m = Source \<or> d = Away))"
| "impossible (DbDistance l r1 r2) \<longleftrightarrow> r1 \<le> 0 \<or> r2 \<le> 0"
| "impossible (DbRatio k) \<longleftrightarrow> k \<le> 0"
| "impossible (StringHarmonic n (Some L) (Some v)) \<longleftrightarrow> n = 0 \<or> len L \<le> 0 \<or> v \<le> 0"
| "impossible (PipeClosed n (Some L) s) \<longleftrightarrow> n = 0 \<or> len L \<le> 0 \<or> \<not> medium_ok s \<or> even n"
| "impossible (PipeOpen n (Some L) s) \<longleftrightarrow> n = 0 \<or> len L \<le> 0 \<or> \<not> medium_ok s"
| "impossible (Wavelength (Some f) s) \<longleftrightarrow> hz f \<le> 0 \<or> \<not> medium_ok s"
| "impossible (Frequency L s) \<longleftrightarrow> len L \<le> 0 \<or> \<not> medium_ok s"
| "impossible (SpeedAir s) \<longleftrightarrow> \<not> medium_ok s"
| "impossible _ \<longleftrightarrow> False"

text \<open>Exact rational decision of @{text "speed s \<le> u"}: for air,
@{text "331.3 sqrt(1 + T/273.15) \<le> u"} iff @{text "0 \<le> u"} and
@{text "331.3\<^sup>2 (1 + T/273.15) \<le> u\<^sup>2"}.\<close>
definition reach :: "rat \<Rightarrow> medium \<Rightarrow> bool" where
  "reach u s = (case s of
     Stated v \<Rightarrow> v \<le> u
   | AirAt T \<Rightarrow> 0 \<le> u \<and> (3313 / 10) ^ 2 * (1 + T / (27315 / 100)) \<le> u ^ 2
   | AirDefault \<Rightarrow> 0 \<le> u \<and> (3313 / 10) ^ 2 * (1 + 20 / (27315 / 100)) \<le> u ^ 2)"

lemma air_reach:
  fixes t x :: real
  assumes "0 \<le> 1 + t / 273.15"
  shows "air_speed t \<le> x \<longleftrightarrow> 0 \<le> x \<and> 331.3 ^ 2 * (1 + t / 273.15) \<le> x ^ 2"
proof -
  have eq: "air_speed t = sqrt (331.3 ^ 2 * (1 + t / 273.15))"
    by (simp add: air_speed_def real_sqrt_mult)
  have nn: "0 \<le> 331.3 ^ 2 * (1 + t / 273.15 :: real)" using assms by simp
  show ?thesis
  proof (cases "0 \<le> x")
    case True
    have "sqrt (331.3 ^ 2 * (1 + t / 273.15)) \<le> sqrt (x ^ 2) \<longleftrightarrow> 331.3 ^ 2 * (1 + t / 273.15) \<le> x ^ 2"
      by (rule real_sqrt_le_iff)
    moreover have "sqrt (x ^ 2) = x" using True by simp
    ultimately have "sqrt (331.3 ^ 2 * (1 + t / 273.15)) \<le> x \<longleftrightarrow> 331.3 ^ 2 * (1 + t / 273.15) \<le> x ^ 2"
      by simp
    then show ?thesis using eq True by simp
  next
    case False
    have "0 \<le> air_speed t" using eq real_sqrt_ge_zero[OF nn] by simp
    then have "\<not> air_speed t \<le> x" using False by linarith
    then show ?thesis using False by simp
  qed
qed

lemma reach_iff: "medium_ok s \<Longrightarrow> reach u s \<longleftrightarrow> speed s \<le> rl u"
proof (cases s)
  case (Stated v)
  then show ?thesis by (simp add: reach_def of_rat_less_eq)
next
  case (AirAt T)
  assume ok: "medium_ok s"
  then have "- 273.15 < rl T" using AirAt rl_temp by simp
  then have pos: "0 \<le> 1 + rl T / 273.15" by (simp add: field_simps)
  have conv: "rl ((3313 / 10) ^ 2 * (1 + T / (27315 / 100))) = 331.3 ^ 2 * (1 + rl T / 273.15)"
    by (simp add: of_rat_mult of_rat_add of_rat_divide of_rat_power)
  have "(3313 / 10) ^ 2 * (1 + T / (27315 / 100)) \<le> u ^ 2 \<longleftrightarrow>
        331.3 ^ 2 * (1 + rl T / 273.15) \<le> rl u ^ 2"
    using of_rat_less_eq[of "(3313 / 10) ^ 2 * (1 + T / (27315 / 100))" "u ^ 2", where 'a = real]
    by (simp only: conv of_rat_power)
  moreover have "0 \<le> u \<longleftrightarrow> 0 \<le> rl u" by (simp add: zero_le_of_rat_iff)
  ultimately show ?thesis using AirAt air_reach[OF pos, of "rl u"] by (simp add: reach_def)
next
  case AirDefault
  have conv: "rl ((3313 / 10) ^ 2 * (1 + 20 / (27315 / 100))) = 331.3 ^ 2 * (1 + 20 / 273.15)"
    by (simp add: of_rat_mult of_rat_add of_rat_divide of_rat_power)
  have "(3313 / 10) ^ 2 * (1 + 20 / (27315 / 100)) \<le> u ^ 2 \<longleftrightarrow>
        331.3 ^ 2 * (1 + 20 / 273.15) \<le> rl u ^ 2"
    using of_rat_less_eq[of "(3313 / 10) ^ 2 * (1 + 20 / (27315 / 100))" "u ^ 2", where 'a = real]
    by (simp only: conv of_rat_power)
  moreover have "0 \<le> u \<longleftrightarrow> 0 \<le> rl u" by (simp add: zero_le_of_rat_iff)
  ultimately show ?thesis using AirDefault air_reach[of 20 "rl u"] by (simp add: reach_def)
qed

fun medium_reason :: "medium \<Rightarrow> reason" where
  "medium_reason (Stated _) = Nonpositive_Speed"
| "medium_reason _ = Below_Absolute_Zero"

text \<open>The executable impossibility check, with the reason it reports.\<close>
fun reason_of :: "request \<Rightarrow> reason option" where
  "reason_of (Beat (Some a) (Some b)) =
     (if a \<le> 0 \<or> b \<le> 0 then Some Nonpositive_Frequency else None)"
| "reason_of (Doppler (Some f) (Some u) m d s) =
     (if \<not> medium_ok s then Some (medium_reason s)
      else if f \<le> 0 then Some Nonpositive_Frequency
      else if u < 0 then Some Negative_Speed
      else if reach u s \<and> m = Source then Some Shock_Wave
      else if reach u s \<and> d = Away then Some Outruns_Sound
      else None)"
| "reason_of (DbDistance l r1 r2) = (if r1 \<le> 0 \<or> r2 \<le> 0 then Some Nonpositive_Distance else None)"
| "reason_of (DbRatio k) = (if k \<le> 0 then Some Nonpositive_Ratio else None)"
| "reason_of (StringHarmonic n (Some L) (Some v)) =
     (if n = 0 then Some Zero_Harmonic else if len L \<le> 0 then Some Nonpositive_Length
      else if v \<le> 0 then Some Nonpositive_Speed else None)"
| "reason_of (PipeClosed n (Some L) s) =
     (if n = 0 then Some Zero_Harmonic else if len L \<le> 0 then Some Nonpositive_Length
      else if \<not> medium_ok s then Some (medium_reason s)
      else if even n then Some (Even_Closed_Harmonic n) else None)"
| "reason_of (PipeOpen n (Some L) s) =
     (if n = 0 then Some Zero_Harmonic else if len L \<le> 0 then Some Nonpositive_Length
      else if \<not> medium_ok s then Some (medium_reason s) else None)"
| "reason_of (Wavelength (Some f) s) =
     (if hz f \<le> 0 then Some Nonpositive_Frequency
      else if \<not> medium_ok s then Some (medium_reason s) else None)"
| "reason_of (Frequency L s) =
     (if len L \<le> 0 then Some Nonpositive_Wavelength
      else if \<not> medium_ok s then Some (medium_reason s) else None)"
| "reason_of (SpeedAir s) = (if \<not> medium_ok s then Some (medium_reason s) else None)"
| "reason_of _ = None"

theorem reason_of_exact:
  assumes "missing r = None"
  shows "reason_of r \<noteq> None \<longleftrightarrow> impossible r"
  using assms by (induction r rule: reason_of.induct) (auto simp: reach_iff split: if_splits)

definition decline_of :: "request \<Rightarrow> decline option" where
  "decline_of r = (case missing r of
     Some w \<Rightarrow> Some (Underspecified w)
   | None \<Rightarrow> map_option Impossible (reason_of r))"


section \<open>Executable enclosure of the model\<close>

text \<open>Base-10 logarithm. The library's bounds for @{text ln} converge slowly when
the binary mantissa of the argument is near 2 (about four digits at any
precision), so the argument is first brought near 1 by eight square roots:
@{text "ln y = 256 ln (sqrt\<^sup>8 y)"} for @{text "y \<ge> 0"}.\<close>
definition sq8 :: "floatarith \<Rightarrow> floatarith" where
  "sq8 a = floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt
     (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt (floatarith.Sqrt a)))))))"

definition r8 :: "real \<Rightarrow> real" where
  "r8 y = sqrt (sqrt (sqrt (sqrt (sqrt (sqrt (sqrt (sqrt y)))))))"

definition Lg :: "floatarith \<Rightarrow> floatarith" where
  "Lg a = floatarith.Mult (floatarith.Mult (I 256) (floatarith.Ln (sq8 a)))
     (floatarith.Inverse (floatarith.Ln (I 10)))"
definition P10 :: "floatarith \<Rightarrow> floatarith" where "P10 a = floatarith.Powr (I 10) a"

lemma interp_sq8: "interpret_floatarith (sq8 a) xs = r8 (interpret_floatarith a xs)"
  by (simp add: sq8_def r8_def)

lemma ln_sqrt_half: "0 \<le> z \<Longrightarrow> ln (sqrt z) = ln z / 2"
  by (rule ln_sqrt)

lemma ln_r8: "0 \<le> y \<Longrightarrow> ln (r8 y) = ln y / 256"
proof -
  assume y: "0 \<le> y"
  let ?s = sqrt
  have n1: "0 \<le> ?s y" and n2: "0 \<le> ?s (?s y)" and n3: "0 \<le> ?s (?s (?s y))"
    and n4: "0 \<le> ?s (?s (?s (?s y)))" and n5: "0 \<le> ?s (?s (?s (?s (?s y))))"
    and n6: "0 \<le> ?s (?s (?s (?s (?s (?s y)))))" and n7: "0 \<le> ?s (?s (?s (?s (?s (?s (?s y))))))"
    using y by (simp_all only: real_sqrt_ge_zero)
  show ?thesis unfolding r8_def
    by (simp only: ln_sqrt_half[OF n7] ln_sqrt_half[OF n6] ln_sqrt_half[OF n5] ln_sqrt_half[OF n4]
        ln_sqrt_half[OF n3] ln_sqrt_half[OF n2] ln_sqrt_half[OF n1] ln_sqrt_half[OF y])
qed

lemma interp_Lg [simp]:
  "0 \<le> interpret_floatarith a xs \<Longrightarrow> interpret_floatarith (Lg a) xs = log 10 (interpret_floatarith a xs)"
proof -
  assume y: "0 \<le> interpret_floatarith a xs"
  have "interpret_floatarith (Lg a) xs = of_int 256 * ln (r8 (interpret_floatarith a xs)) * inverse (ln (of_int 10))"
    by (simp only: Lg_def interpret_floatarith.simps interp_sq8 interp_I)
  also have "\<dots> = of_int 256 * (ln (interpret_floatarith a xs) / 256) * inverse (ln (of_int 10))"
    by (simp only: ln_r8[OF y])
  also have "\<dots> = ln (interpret_floatarith a xs) * inverse (ln 10)"
    by simp
  also have "\<dots> = log 10 (interpret_floatarith a xs)"
    by (simp only: log_def divide_inverse)
  finally show ?thesis .
qed
lemma interp_P10 [simp]: "interpret_floatarith (P10 a) xs = 10 powr interpret_floatarith a xs"
  by (simp add: P10_def)

fun speed_fa :: "medium \<Rightarrow> floatarith" where
  "speed_fa (Stated v) = Q v"
| "speed_fa (AirAt T) = floatarith.Mult (Q (3313 / 10)) (floatarith.Sqrt (floatarith.Add (I 1) (Dv (Q T) (Q (27315 / 100)))))"
| "speed_fa AirDefault = floatarith.Mult (Q (3313 / 10)) (floatarith.Sqrt (floatarith.Add (I 1) (Dv (I 20) (Q (27315 / 100)))))"

lemma interp_speed [simp]: "interpret_floatarith (speed_fa s) xs = speed s"
  by (cases s) (simp_all add: air_speed_def of_rat_divide)

definition sum_fa :: "rat list \<Rightarrow> floatarith" where
  "sum_fa ls = foldr (\<lambda>l acc. floatarith.Add (P10 (Dv (Q l) (I 10))) acc) ls (I 0)"

lemma interp_sum [simp]: "interpret_floatarith (sum_fa ls) xs = (\<Sum>l\<leftarrow>ls. 10 powr (rl l / 10))"
  by (induction ls) (simp_all add: sum_fa_def)

fun expr_of :: "request \<Rightarrow> floatarith" where
  "expr_of (Beat (Some a) (Some b)) = floatarith.Abs (Sb (Q a) (Q b))"
| "expr_of (Doppler (Some f) (Some u) Source Toward s) = Dv (floatarith.Mult (Q f) (speed_fa s)) (Sb (speed_fa s) (Q u))"
| "expr_of (Doppler (Some f) (Some u) Source Away s) = Dv (floatarith.Mult (Q f) (speed_fa s)) (floatarith.Add (speed_fa s) (Q u))"
| "expr_of (Doppler (Some f) (Some u) Listener Toward s) = Dv (floatarith.Mult (Q f) (floatarith.Add (speed_fa s) (Q u))) (speed_fa s)"
| "expr_of (Doppler (Some f) (Some u) Listener Away s) = Dv (floatarith.Mult (Q f) (Sb (speed_fa s) (Q u))) (speed_fa s)"
| "expr_of (DbSum ls) = floatarith.Mult (I 10) (Lg (sum_fa ls))"
| "expr_of (DbTwoEqual l) = floatarith.Add (Q l) (floatarith.Mult (I 10) (Lg (I 2)))"
| "expr_of (DbDistance l r1 r2) = Sb (Q l) (floatarith.Mult (I 20) (Lg (Dv (Q r2) (Q r1))))"
| "expr_of (DbRatio k) = floatarith.Mult (I 10) (Lg (Q k))"
| "expr_of (IntensityRatio l1 l2) = P10 (Dv (Sb (Q l1) (Q l2)) (I 10))"
| "expr_of (StringHarmonic n (Some L) (Some v)) = Dv (floatarith.Mult (I (int n)) (Q v)) (floatarith.Mult (I 2) (Q (len L)))"
| "expr_of (PipeClosed n (Some L) s) = Dv (floatarith.Mult (I (int n)) (speed_fa s)) (floatarith.Mult (I 4) (Q (len L)))"
| "expr_of (PipeOpen n (Some L) s) = Dv (floatarith.Mult (I (int n)) (speed_fa s)) (floatarith.Mult (I 2) (Q (len L)))"
| "expr_of (Wavelength (Some f) s) = Dv (speed_fa s) (Q (hz f))"
| "expr_of (Frequency L s) = Dv (speed_fa s) (Q (len L))"
| "expr_of (SpeedAir s) = speed_fa s"
| "expr_of SpeedWater = I 1481"
| "expr_of _ = I 0"

lemma intensity_sum_nonneg: "0 \<le> (\<Sum>l\<leftarrow>ls. 10 powr (rl l / 10) :: real)"
  by (induction ls) (auto intro: add_nonneg_nonneg)

theorem expr_of_meaning:
  assumes "missing r = None" "\<not> impossible r"
  shows "interpret_floatarith (expr_of r) [] = phys r"
  using assms
  by (induction r rule: expr_of.induct) (simp_all add: intensity_sum_nonneg zero_le_divide_iff)


section \<open>Decimal rounding with a proved error bound\<close>

text \<open>An exponent @{text e} with @{text "1000 * 10^e \<le> |x| < 10000 * 10^e"}
when one is found within 400 steps; soundness below does not rely on it, the
kernel checks the condition it needs.\<close>
text \<open>Turn a float interval enclosing a value into a four-significant-digit
decimal, or refuse when the interval is too wide to say four digits.\<close>
section \<open>The kernel\<close>

definition prec :: nat where "prec = 32"

text \<open>Precision in bits per kind: the decibel kinds use logarithms and powers.
The enclosure width test, not this precision choice, guarantees the error bound.
32 bits avoids spending time computing digits the four-digit reply cannot show.\<close>
fun prec_of :: "request \<Rightarrow> nat" where
  "prec_of (DbSum _) = 32"
| "prec_of (DbTwoEqual _) = 32"
| "prec_of (DbDistance _ _ _) = 32"
| "prec_of (DbRatio _) = 32"
| "prec_of (IntensityRatio _ _) = 32"
| "prec_of _ = prec"

text \<open>Close cancellation, especially a sum of sound levels near zero,
can need more bits than ordinary inputs. Retry only when the first verified
enclosure cannot support the printed digits. Both paths obey the same bound.\<close>
definition enclose_retry :: "nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose_retry p e = (case enclose p e of None \<Rightarrow> enclose (2 * p) e | Some d \<Rightarrow> Some d)"

lemma enclose_retry_sound:
  assumes "enclose_retry p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le>
    \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
  using assms by (auto simp: enclose_retry_def split: option.splits dest: enclose_sound)

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of
     Some w \<Rightarrow> Decline w
   | None \<Rightarrow> (case enclose_retry (prec_of r) (expr_of r) of
       None \<Rightarrow> Decline Imprecise
     | Some d \<Rightarrow> Value (kind_of r) d))"

text \<open>Every value the kernel states is within one part in a thousand (plus
@{text "10\<^sup>-\<^sup>9"} absolute, for values at zero) of the physical model,
and only for requests that are neither underspecified nor impossible.\<close>
theorem kernel_value_sound:
  assumes "kernel r = Value k d"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and>
         \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "decline_of r = None" and en: "enclose_retry (prec_of r) (expr_of r) = Some d" and k: "k = kind_of r"
    using assms by (auto simp: kernel_def split: option.splits)
  have mi: "missing r = None" and ro: "reason_of r = None"
    using nd by (auto simp: decline_of_def split: option.splits)
  have "\<not> impossible r" using reason_of_exact[OF mi] ro by simp
  moreover have "\<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
    using enclose_retry_sound[OF en] by (simp add: expr_of_meaning[OF mi \<open>\<not> impossible r\<close>])
  ultimately show ?thesis using mi k by simp
qed

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified w) \<longleftrightarrow> missing r = Some w"
  by (auto simp: kernel_def decline_of_def split: option.splits)

theorem kernel_impossible:
  "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> impossible r"
proof -
  have "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> reason_of r \<noteq> None"
    by (auto simp: kernel_def decline_of_def split: option.splits)
  then show ?thesis using reason_of_exact by blast
qed

text \<open>The only other decline is numerical, and it only happens on requests
that are fully specified and possible.\<close>
theorem kernel_imprecise:
  "kernel r = Decline Imprecise \<Longrightarrow> missing r = None \<and> \<not> impossible r"
  using reason_of_exact[of r]
  by (auto simp: kernel_def decline_of_def split: option.splits)


section \<open>The defining physical equations\<close>

theorem doppler_source_toward:
  assumes "rl u < speed s"
  shows "phys (Doppler (Some f) (Some u) Source Toward s) * (speed s - rl u) = rl f * speed s"
proof -
  have nz: "speed s - rl u \<noteq> 0" using assms by linarith
  then show ?thesis by simp
qed

theorem doppler_source_away:
  assumes "medium_ok s" "0 \<le> u"
  shows "phys (Doppler (Some f) (Some u) Source Away s) * (speed s + rl u) = rl f * speed s"
proof -
  have "0 \<le> rl u" using assms(2) by (simp add: zero_le_of_rat_iff)
  then have "speed s + rl u \<noteq> 0" using speed_pos[OF assms(1)] by linarith
  then show ?thesis by simp
qed

theorem doppler_listener_toward:
  assumes "medium_ok s"
  shows "phys (Doppler (Some f) (Some u) Listener Toward s) * speed s = rl f * (speed s + rl u)"
proof -
  have "speed s \<noteq> 0" using speed_pos[OF assms] by linarith
  then show ?thesis by simp
qed

theorem doppler_listener_away:
  assumes "medium_ok s"
  shows "phys (Doppler (Some f) (Some u) Listener Away s) * speed s = rl f * (speed s - rl u)"
proof -
  have "speed s \<noteq> 0" using speed_pos[OF assms] by linarith
  then show ?thesis by simp
qed

text \<open>A source at or above the speed of sound is declined, never answered.\<close>
theorem doppler_supersonic_source_declined:
  assumes "d \<noteq> Unclear" "speed s \<le> rl u"
  shows "\<exists>why. kernel (Doppler (Some f) (Some u) Source d s) = Decline (Impossible why)"
  using assms by (simp add: kernel_impossible)

theorem db_sum_intensities:
  assumes "ls \<noteq> []"
  shows "10 powr (phys (DbSum ls) / 10) = (\<Sum>l\<leftarrow>ls. 10 powr (rl l / 10))"
proof -
  obtain a t where ls: "ls = a # t" using assms by (cases ls) auto
  have pos: "0 < (\<Sum>l\<leftarrow>ls. 10 powr (rl l / 10) :: real)"
    unfolding ls using intensity_sum_nonneg[of t] by (simp add: add_pos_nonneg)
  have "phys (DbSum ls) / 10 = log 10 (\<Sum>l\<leftarrow>ls. 10 powr (rl l / 10))" by simp
  then show ?thesis using pos by simp
qed

theorem db_two_equal_intensities:
  "10 powr (phys (DbTwoEqual l) / 10) = 2 * 10 powr (rl l / 10)"
proof -
  have "10 powr (phys (DbTwoEqual l) / 10) = 10 powr (rl l / 10 + log 10 2)"
    by (simp add: add_divide_distrib)
  also have "\<dots> = 2 * 10 powr (rl l / 10)" by (simp add: powr_add mult.commute)
  finally show ?thesis .
qed

text \<open>Inverse-square law: intensity times squared distance is the same at
both distances.\<close>
theorem db_distance_inverse_square:
  assumes "0 < r1" "0 < r2"
  shows "10 powr (phys (DbDistance l r1 r2) / 10) * rl r2 ^ 2 = 10 powr (rl l / 10) * rl r1 ^ 2"
proof -
  have p1: "0 < rl r1" and p2: "0 < rl r2" using assms by (simp_all add: zero_less_of_rat_iff)
  then have q: "0 < rl r2 / rl r1" by simp
  have e1: "phys (DbDistance l r1 r2) / 10 = rl l / 10 - 2 * log 10 (rl r2 / rl r1)"
    by (simp add: diff_divide_distrib)
  have "10 powr (phys (DbDistance l r1 r2) / 10) = 10 powr (rl l / 10 - 2 * log 10 (rl r2 / rl r1))"
    by (simp only: e1)
  also have "\<dots> = 10 powr (rl l / 10) / 10 powr (2 * log 10 (rl r2 / rl r1))"
    by (rule powr_diff)
  also have "10 powr (2 * log 10 (rl r2 / rl r1)) = (rl r2 / rl r1) ^ 2"
  proof -
    have "10 powr (2 * log 10 (rl r2 / rl r1)) = (10 powr log 10 (rl r2 / rl r1)) powr 2"
      by (simp add: powr_powr mult.commute)
    also have "\<dots> = (rl r2 / rl r1) powr 2" using q by simp
    also have "\<dots> = (rl r2 / rl r1) ^ 2" using q powr_realpow[of "rl r2 / rl r1" 2] by simp
    finally show ?thesis .
  qed
  finally show ?thesis using p1 p2 by (simp add: field_simps power2_eq_square)
qed

theorem db_ratio_intensity:
  assumes "0 < k"
  shows "10 powr (phys (DbRatio k) / 10) = rl k"
  using assms by (simp add: zero_less_of_rat_iff)

theorem intensity_ratio_levels:
  "phys (IntensityRatio l1 l2) * 10 powr (rl l2 / 10) = 10 powr (rl l1 / 10)"
  by (simp add: powr_add[symmetric] diff_divide_distrib)

theorem string_harmonic:
  assumes "0 < len L"
  shows "phys (StringHarmonic n (Some L) (Some v)) * (2 * rl (len L)) = real n * rl v"
proof -
  have "rl (len L) \<noteq> 0" using assms by simp
  then show ?thesis by simp
qed

theorem pipe_closed_harmonic:
  assumes "0 < len L"
  shows "phys (PipeClosed n (Some L) s) * (4 * rl (len L)) = real n * speed s"
proof -
  have "rl (len L) \<noteq> 0" using assms by simp
  then show ?thesis by simp
qed

theorem pipe_open_harmonic:
  assumes "0 < len L"
  shows "phys (PipeOpen n (Some L) s) * (2 * rl (len L)) = real n * speed s"
proof -
  have "rl (len L) \<noteq> 0" using assms by simp
  then show ?thesis by simp
qed

theorem pipe_open_closed_consistent:
  "phys (PipeOpen n (Some L) s) = 2 * phys (PipeClosed n (Some L) s)"
  by (simp add: field_simps)

lemma intensity_member_le_sum:
  "l \<in> set ls \<Longrightarrow> 10 powr (rl l / 10) \<le> (\<Sum>x\<leftarrow>ls. 10 powr (rl x / 10) :: real)"
proof (induction ls)
  case Nil
  then show ?case by simp
next
  case (Cons a ls)
  have tail: "0 \<le> (\<Sum>x\<leftarrow>ls. 10 powr (rl x / 10) :: real)"
    by (rule intensity_sum_nonneg)
  have head: "0 \<le> (10 powr (rl a / 10) :: real)" by simp
  show ?case
  proof (cases "l = a")
    case True
    then show ?thesis using tail by simp
  next
    case False
    then have "l \<in> set ls" using Cons.prems by simp
    have "10 powr (rl l / 10) \<le> 10 powr (rl a / 10) + (\<Sum>x\<leftarrow>ls. 10 powr (rl x / 10) :: real)"
      using Cons.IH[OF \<open>l \<in> set ls\<close>] head by linarith
    then show ?thesis by simp
  qed
qed

theorem db_sum_not_quieter:
  assumes "l \<in> set ls"
  shows "rl l \<le> phys (DbSum ls)"
proof -
  have nonempty: "ls \<noteq> []" using assms by auto
  have "10 powr (rl l / 10) \<le> 10 powr (phys (DbSum ls) / 10)"
    using intensity_member_le_sum[OF assms] db_sum_intensities[OF nonempty] by simp
  then show ?thesis by simp
qed

text \<open>A pipe closed at one end is only ever answered for odd harmonics.\<close>
theorem pipe_closed_answers_odd:
  assumes "kernel (PipeClosed n L s) = Value k d"
  shows "odd n"
  using kernel_value_sound[OF assms] by (cases L) auto

theorem wavelength_relation:
  assumes "0 < hz f"
  shows "phys (Wavelength (Some f) s) * rl (hz f) = speed s"
proof -
  have "rl (hz f) \<noteq> 0" using assms by simp
  then show ?thesis by simp
qed

theorem frequency_relation:
  assumes "0 < len L"
  shows "phys (Frequency L s) * rl (len L) = speed s"
proof -
  have "rl (len L) \<noteq> 0" using assms by simp
  then show ?thesis by simp
qed

theorem speed_air_square:
  assumes "medium_ok (AirAt T)"
  shows "0 < phys (SpeedAir (AirAt T)) \<and> phys (SpeedAir (AirAt T)) ^ 2 = 331.3 ^ 2 * (1 + rl T / 273.15)"
proof -
  have "- 273.15 < rl T" using assms rl_temp by simp
  then have pos: "0 < 1 + rl T / 273.15" by (simp add: field_simps)
  then have nn: "0 \<le> 1 + rl T / 273.15" by simp
  show ?thesis unfolding phys.simps speed.simps air_speed_def
    using pos nn by (simp add: power_mult_distrib power_divide)
qed

theorem speed_air_freezing: "phys (SpeedAir (AirAt 0)) = 331.3"
  by (simp add: air_speed_def)


section \<open>Response text (ASCII)\<close>

text \<open>Python's @{text "%.4g"} layout for a decimal @{text "m * 10^e"}.\<close>
definition show_real :: "real \<Rightarrow> String.literal" where
  "show_real x = (if x = 0 then STR ''0'' else render_dec 4 (round_at x (sig_exp 4 x)))"

definition show_rat :: "rat \<Rightarrow> String.literal" where
  "show_rat q = show_real (rl q)"

definition speed_text :: "medium \<Rightarrow> String.literal" where
  "speed_text s = (case enclose_retry prec (speed_fa s) of Some d \<Rightarrow> render_dec 4 d | None \<Rightarrow> STR ''?'')"

fun medium_note :: "medium \<Rightarrow> String.literal" where
  "medium_note (Stated v) = STR ''v = '' + show_rat v + STR '' m/s''"
| "medium_note (AirAt T) = STR ''air at '' + show_rat T + STR '' degrees C''"
| "medium_note AirDefault = STR ''air at 20 degrees C''"

fun medium_of :: "request \<Rightarrow> medium" where
  "medium_of (Doppler _ _ _ _ s) = s"
| "medium_of (PipeClosed _ _ s) = s"
| "medium_of (PipeOpen _ _ s) = s"
| "medium_of (Wavelength _ s) = s"
| "medium_of (Frequency _ s) = s"
| "medium_of (SpeedAir s) = s"
| "medium_of _ = AirDefault"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text w = (case w of
     Both_Frequencies \<Rightarrow> STR ''both frequencies''
   | Doppler_Inputs \<Rightarrow> STR ''the emitted frequency and the speed of the moving source or listener''
   | Doppler_Direction \<Rightarrow> STR ''whether it is moving toward or away''
   | Two_Levels \<Rightarrow> STR ''two sound levels''
   | Length \<Rightarrow> STR ''the length''
   | Wave_Speed \<Rightarrow> STR ''the wave speed on the string''
   | A_Frequency \<Rightarrow> STR ''a frequency'')"

definition reason_text :: "request \<Rightarrow> reason \<Rightarrow> String.literal" where
  "reason_text r why = (let s = medium_of r in case why of
     Below_Absolute_Zero \<Rightarrow> STR ''A temperature at or below absolute zero (-273.15 degrees C) has no speed of sound.''
   | Nonpositive_Speed \<Rightarrow> STR ''A wave speed must be positive.''
   | Nonpositive_Frequency \<Rightarrow> STR ''A frequency must be positive.''
   | Negative_Speed \<Rightarrow> STR ''A speed of motion here is a magnitude; it cannot be negative.''
   | Shock_Wave \<Rightarrow> STR ''A source at or above the speed of sound ('' + speed_text s + STR '' m/s, ''
       + medium_note s + STR '') makes a shock wave; the Doppler formula doesn'' + apos + STR ''t apply.''
   | Outruns_Sound \<Rightarrow> STR ''A listener moving away at or above the speed of sound ('' + speed_text s
       + STR '' m/s, '' + medium_note s + STR '') never hears the source.''
   | Nonpositive_Distance \<Rightarrow> STR ''Distances must be positive.''
   | Nonpositive_Ratio \<Rightarrow> STR ''An intensity ratio must be positive.''
   | Nonpositive_Length \<Rightarrow> STR ''A length must be positive.''
   | Zero_Harmonic \<Rightarrow> STR ''Harmonics are numbered from 1.''
   | Even_Closed_Harmonic n \<Rightarrow> STR ''A pipe closed at one end has only odd harmonics, so there is no harmonic ''
       + show_nat n + STR ''.''
   | Nonpositive_Wavelength \<Rightarrow> STR ''A wavelength must be positive.'')"

fun value_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "value_text (Beat (Some a) (Some b)) V = STR ''The beat frequency is '' + V + STR '' Hz (|f1 - f2| = |''
     + show_rat a + STR '' - '' + show_rat b + STR ''|).''"
| "value_text (Doppler (Some f) (Some u) Listener d s) V = STR ''The heard frequency is '' + V
     + STR '' Hz (f'' + apos + STR '' = f (v '' + (if d = Toward then STR ''+'' else STR ''-'')
     + STR '' v_o)/v with '' + medium_note s + STR '', v_o = '' + show_rat u + STR '' m/s).''"
| "value_text (Doppler (Some f) (Some u) Source d s) V = STR ''The heard frequency is '' + V
     + STR '' Hz (f'' + apos + STR '' = f v/(v '' + (if d = Toward then STR ''-'' else STR ''+'')
     + STR '' v_s) with '' + medium_note s + STR '', v_s = '' + show_rat u + STR '' m/s).''"
| "value_text (DbSum ls) V = STR ''The combined level is '' + V
     + STR '' dB (10 log10 of the summed intensities, not '' + show_rat (sum_list ls) + STR '' dB).''"
| "value_text (DbTwoEqual l) V = STR ''The combined level is '' + V
     + STR '' dB (two equal sources add 10 log10 2 = 3.01 dB).''"
| "value_text (DbDistance l r1 r2) V = STR ''The level is '' + V + STR '' dB at '' + show_rat r2
     + STR '' (L2 = L1 - 20 log10(r2/r1) = '' + show_rat l + STR '' - 20 log10('' + show_rat r2
     + STR ''/'' + show_rat r1 + STR '')).''"
| "value_text (DbRatio k) V = STR ''The level change is '' + V + STR '' dB (10 log10 '' + show_rat k + STR '').''"
| "value_text (IntensityRatio l1 l2) V = STR ''The intensity ratio is '' + V + STR '' (10^(('' + show_rat l1
     + STR '' - '' + show_rat l2 + STR '')/10)).''"
| "value_text (StringHarmonic n (Some L) (Some v)) V = STR ''The frequency is '' + V
     + STR '' Hz (f_n = n v/(2L) with n = '' + show_nat n + STR '', v = '' + show_rat v
     + STR '' m/s, L = '' + show_rat (len L) + STR '' m).''"
| "value_text (PipeClosed n (Some L) s) V = STR ''The frequency is '' + V
     + STR '' Hz (closed pipe: f_n = n v/(4L), n odd; n = '' + show_nat n + STR '', '' + medium_note s
     + STR '', L = '' + show_rat (len L) + STR '' m).''"
| "value_text (PipeOpen n (Some L) s) V = STR ''The frequency is '' + V
     + STR '' Hz (open pipe: f_n = n v/(2L); n = '' + show_nat n + STR '', '' + medium_note s
     + STR '', L = '' + show_rat (len L) + STR '' m).''"
| "value_text (Wavelength (Some f) s) V = STR ''The wavelength is '' + V + STR '' m (lambda = v/f with ''
     + medium_note s + STR '': '' + speed_text s + STR '' m/s / '' + show_rat (hz f) + STR '' Hz).''"
| "value_text (Frequency L s) V = STR ''The frequency is '' + V + STR '' Hz (f = v/lambda with ''
     + medium_note s + STR '').''"
| "value_text (SpeedAir s) V = STR ''The speed of sound is '' + V + STR '' m/s ('' + medium_note s
     + STR '': v = 331.3 sqrt(1 + T/273.15)).''"
| "value_text SpeedWater V = STR ''Sound travels at about '' + V + STR '' m/s in fresh water at 20 degrees C.''"
| "value_text _ V = V"

definition kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name k = (case k of K_beat \<Rightarrow> STR ''beat'' | K_doppler \<Rightarrow> STR ''doppler''
     | K_db_sum \<Rightarrow> STR ''db_sum'' | K_db_distance \<Rightarrow> STR ''db_distance'' | K_db_ratio \<Rightarrow> STR ''db_ratio''
     | K_intensity_ratio \<Rightarrow> STR ''intensity_ratio'' | K_string \<Rightarrow> STR ''string''
     | K_pipe_closed \<Rightarrow> STR ''pipe_closed'' | K_pipe_open \<Rightarrow> STR ''pipe_open''
     | K_wavelength \<Rightarrow> STR ''wavelength'' | K_frequency \<Rightarrow> STR ''frequency'' | K_speed \<Rightarrow> STR ''speed'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and
the stated value. Withheld replies carry the decline text, as the organ does.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Value k d \<Rightarrow> Reply True (kind_name k) (value_text r (render_dec 4 d)) (Some (render_dec 4 d))
   | Decline (Underspecified w) \<Rightarrow> Reply False (STR ''underspecified'')
       (STR ''I need '' + need_text w + STR '' to compute that; I won'' + apos + STR ''t assume it.'') None
   | Decline (Impossible why) \<Rightarrow> Reply False (STR ''impossible'') (reason_text r why) None
   | Decline Imprecise \<Rightarrow> Reply False (STR ''imprecise'')
       (STR ''The interval arithmetic could not pin four digits; I won'' + apos + STR ''t guess.'') None)"

theorem reply_answered_iff: "answered (reply_of r) \<longleftrightarrow> (\<exists>k d. kernel r = Value k d)"
  by (auto simp: reply_of_def split: outcome.splits decline.splits)

theorem reply_states_kernel_value:
  "kernel r = Value k d \<Longrightarrow> stated (reply_of r) = Some (render_dec 4 d)"
  by (simp add: reply_of_def)

theorem answered_reply_model_bound:
  assumes "answered (reply_of r)"
  shows "\<exists>k d. kernel r = Value k d \<and>
    stated (reply_of r) = Some (render_dec 4 d) \<and>
    \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
  using assms reply_answered_iff reply_states_kernel_value kernel_value_sound by blast

end
