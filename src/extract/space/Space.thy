theory Space
  imports Space_Tables
begin

text \<open>
  Eight shipped Oracle7 specialists (orbits, planetary, spacecraft, spacecomms,
  astronomy, astronomy-v2, astronomy-v3, astronomy-v3-r2) as one verified HOL
  kernel. A typed request (what the question asks, its numbers already read off
  by the untrusted recognizer) goes to an outcome: an exact rational value, a
  decimal enclosure (square roots, pi, exp, ln, a cube root), a table cell, or a
  decline. The tables are in Space_Tables.thy.
\<close>

section \<open>Rounding to a stated decimal\<close>

text \<open>The decimal rounding (round_at, its error bound, round_tie_up, sig_exp) and the
digit layout come from Veri7vn_Commons (src/extract/commons/Commons_Num.thy,
lifted from lane G). This family's @{text to_dec}, @{text enclose} and
@{text render_fixed} take a style or other arguments and are different
functions from the commons ones of the same names, so the commons names are
hidden. The exponent search never carries soundness (see @{text style_exp}).\<close>

hide_const (open) Commons_Num.to_dec Commons_Num.enclose Commons_Num.render_fixed
hide_fact (open) Commons_Num.to_dec_def Commons_Num.to_dec_sound Commons_Num.enclose_def
  Commons_Num.enclose_sound Commons_Num.render_fixed_def

text \<open>How the organs print a number: a style fixes the exponent the value is rounded
at. @{text "St_sig p"} is p significant digits; @{text St_orb} is Python's
@{text "%.4g"} below 10000 and a whole number above (orbits, space links);
@{text St_sc} is four decimals below 100000 and a whole number above
(spacecraft); @{text St_pl} is four decimals, or @{text "%.4g"} outside
[0.001, 10^6) (planetary); @{text St_r3} is three significant digits, whole
numbers from 100 (astronomy ratios); @{text "St_f n"} is n decimals.\<close>
datatype style = St_sig nat | St_orb | St_sc | St_pl | St_r3 | St_f nat

fun cand_exp :: "style \<Rightarrow> real \<Rightarrow> int" where
  "cand_exp (St_sig p) x = sig_exp p x"
| "cand_exp St_orb x = (if \<bar>x\<bar> < 10000 then sig_exp 4 x else 0)"
| "cand_exp St_sc x = (if \<bar>x\<bar> < 100000 then - 4 else 0)"
| "cand_exp St_pl x = (if x \<noteq> 0 \<and> (1000000 \<le> \<bar>x\<bar> \<or> \<bar>x\<bar> < 1 / 1000) then sig_exp 4 x else - 4)"
| "cand_exp St_r3 x = (if 100 \<le> \<bar>x\<bar> then 0 else sig_exp 3 x)"
| "cand_exp (St_f n) x = - int n"

text \<open>The exponent actually used: the candidate, if the resulting step is at most
one hundredth of the value or a tenth (so at least two digits are right), else none.
The check is what the soundness proofs read; the candidate only decides fidelity.\<close>
definition style_exp :: "style \<Rightarrow> real \<Rightarrow> int option" where
  "style_exp st x = (let e = cand_exp st x in
     if pow10 e \<le> max (\<bar>x\<bar> / 100) (1 / 10) then Some e else None)"

definition stated_dec :: "style \<Rightarrow> rat \<Rightarrow> (int \<times> int) option" where
  "stated_dec st q = (case style_exp st (rl q) of None \<Rightarrow> None | Some e \<Rightarrow> Some (round_at (rl q) e))"

theorem stated_dec_sound:
  assumes "stated_dec st q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> pow10 (snd d) / 2"
proof -
  obtain e where d: "d = round_at (rl q) e"
    using assms by (auto simp: stated_dec_def split: option.splits)
  have s: "snd d = e" by (simp add: d round_at_def)
  have "\<bar>dec_val d - rl q\<bar> \<le> pow10 e / 2" unfolding d by (rule round_at_error)
  then show ?thesis by (simp add: s)
qed

text \<open>A decimal from a float interval enclosing a value, or a refusal when the
interval is too wide (lane D's and lane G's @{text to_dec}, with a style).\<close>
definition to_dec :: "style \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec st X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000 then Some (0, 0)
     else case style_exp st mid of None \<Rightarrow> None
       | Some e \<Rightarrow> if hi - lo \<le> \<bar>mid\<bar> / 1000000 then Some (round_at mid e) else None)"

theorem to_dec_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec st X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> pow10 (snd d) / 2 + \<bar>x\<bar> / 1000000 + 1 / 1000000000"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  show ?thesis
  proof (cases "lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000")
    case True
    then have dz: "d = (0, 0)" using d by (simp add: to_dec_def Let_def lo_def hi_def)
    have hx: "\<bar>x\<bar> \<le> 1 / 1000000000" using True xin by arith
    have a: "dec_val d = 0" using dz by (simp add: dec_val_def)
    have b: "pow10 (snd d) = 1" using dz by (simp add: pow10_def)
    have e: "\<bar>dec_val d - x\<bar> = \<bar>x\<bar>" using a by simp
    have c: "0 \<le> \<bar>x\<bar> / 1000000" by simp
    show ?thesis using e b hx c by linarith
  next
    case False
    have ex: "\<exists>e. hi - lo \<le> \<bar>mid\<bar> / 1000000 \<and> d = round_at mid e"
      using d False
      by (auto simp: to_dec_def Let_def lo_def hi_def mid_def split: option.splits if_splits)
    then obtain e where chk: "hi - lo \<le> \<bar>mid\<bar> / 1000000" and dd: "d = round_at mid e" by blast
    have s: "snd d = e" by (simp add: dd round_at_def)
    have r: "\<bar>dec_val d - mid\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
    have "\<bar>mid - x\<bar> \<le> (hi - lo) / 2"
      unfolding mid_def using xin by (rule midpoint_close)
    moreover have "(hi - lo) / 2 \<le> (\<bar>mid\<bar> / 1000000) / 2"
      using chk by (rule divide_right_mono) simp
    ultimately have m: "\<bar>mid - x\<bar> \<le> \<bar>mid\<bar> / 2000000" by linarith
    have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
    have M: "\<bar>mid\<bar> \<le> \<bar>x\<bar> + \<bar>mid - x\<bar>" by arith
    have a0: "0 \<le> \<bar>mid - x\<bar>" "0 \<le> \<bar>x\<bar>" by simp_all
    have r': "\<bar>dec_val d - mid\<bar> \<le> pow10 (snd d) / 2" using r s by simp
    show ?thesis using r' m tri M a0 by linarith
  qed
qed

definition prec :: nat where "prec = 80"

definition enclose :: "style \<Rightarrow> nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose st p e = (case approx p e [] of None \<Rightarrow> None | Some X \<Rightarrow> to_dec st X)"

lemma enclose_sound:
  assumes "enclose st p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le>
     pow10 (snd d) / 2 + \<bar>interpret_floatarith e []\<bar> / 1000000 + 1 / 1000000000"
proof -
  obtain X where X: "approx p e [] = Some X" and d: "to_dec st X = Some d"
    using assms by (auto simp: enclose_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using to_dec_sound d by blast
qed

section \<open>Response text: digits\<close>

text \<open>Thousands commas, by fuel on the number of digits.\<close>
fun commas_n :: "nat \<Rightarrow> nat list \<Rightarrow> String.literal" where
  "commas_n 0 ds = lit ds"
| "commas_n (Suc n) ds = (if length ds \<le> 3 then lit ds
     else commas_n n (take (length ds - 3) ds) + STR '','' + lit (drop (length ds - 3) ds))"

definition commas :: "nat list \<Rightarrow> String.literal" where
  "commas ds = commas_n (length ds) ds"

text \<open>Python's @{text "%.pg"} layout for a decimal @{text "m * 10^e"} (lane G's).\<close>
text \<open>Fixed notation: @{text "%.nf"}, optionally with trailing zeros stripped (the
spacecraft and planetary @{text g}) and thousands commas.\<close>
definition render_fixed :: "bool \<Rightarrow> bool \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_fixed strip comma d = (case d of (m, e) \<Rightarrow>
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>);
         p = nat (- e);
         ip = (if 0 \<le> e then ds @ replicate (nat e) 0
               else if p < length ds then take (length ds - p) ds else [0]);
         fr0 = (if 0 \<le> e then []
                else if p < length ds then drop (length ds - p) ds
                else replicate (p - length ds) 0 @ ds);
         fr = (if strip then strip_zeros fr0 else fr0)
     in sg + (if comma then commas ip else lit ip) + (if fr = [] then STR '''' else STR ''.'' + lit fr))"

definition render_st :: "style \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_st st d = (case st of
       St_sig p \<Rightarrow> render_dec p d
     | St_orb \<Rightarrow> (if 0 \<le> snd d \<and> 10000 \<le> \<bar>fst d\<bar> * 10 ^ nat (snd d)
                  then render_fixed False True d else render_dec 4 d)
     | St_sc \<Rightarrow> (if snd d = 0 then render_fixed False True d else render_fixed True False d)
     | St_pl \<Rightarrow> (if snd d = - 4 then render_fixed True False d else render_dec 4 d)
     | St_r3 \<Rightarrow> render_fixed False False d
     | St_f n \<Rightarrow> render_fixed False False d)"

text \<open>A plain JSON number for the reply's value field.\<close>
definition render_plain :: "int \<times> int \<Rightarrow> String.literal" where
  "render_plain d = (if fst d = 0 then STR ''0'' else render_fixed True False d)"

text \<open>A number in a reply, in a style (a question mark if the style cannot pin it).\<close>
definition fmt :: "style \<Rightarrow> rat \<Rightarrow> String.literal" where
  "fmt st q = (case stated_dec st q of None \<Rightarrow> STR ''?'' | Some d \<Rightarrow> render_st st d)"

section \<open>Units the organs read\<close>

datatype lenu = Lu_m | Lu_km
fun lenf :: "lenu \<Rightarrow> rat" where "lenf Lu_m = 1" | "lenf Lu_km = 1000"

datatype massu = Mu_kg | Mu_t
fun massf :: "massu \<Rightarrow> rat" where "massf Mu_kg = 1" | "massf Mu_t = 1000"

datatype forceu = Fu_n | Fu_kn | Fu_mn
fun forcef :: "forceu \<Rightarrow> rat" where "forcef Fu_n = 1" | "forcef Fu_kn = 1000" | "forcef Fu_mn = 1000000"

datatype speedu = Su_mps | Su_kmps
fun speedf :: "speedu \<Rightarrow> rat" where "speedf Su_mps = 1" | "speedf Su_kmps = 1000"

text \<open>An exhaust velocity is given as a specific impulse (times g0) or as a speed.\<close>
datatype vesrc = Ve_isp rat | Ve_speed rat speedu
fun ve_of :: "vesrc \<Rightarrow> rat" where
  "ve_of (Ve_isp i) = i * std_g0"
| "ve_of (Ve_speed v u) = v * speedf u"

datatype dscale = Ds_one | Ds_million | Ds_billion
fun dscale_f :: "dscale \<Rightarrow> rat" where
  "dscale_f Ds_one = 1" | "dscale_f Ds_million = 1000000" | "dscale_f Ds_billion = 1000000000"

datatype dbase = Db_km | Db_mile | Db_au
fun dbase_f :: "dbase \<Rightarrow> rat" where
  "dbase_f Db_km = 1" | "dbase_f Db_mile = mile_km" | "dbase_f Db_au = au_km"

datatype dist = Dist rat dscale dbase
fun dkm :: "dist \<Rightarrow> rat" where "dkm (Dist a s b) = a * dscale_f s * dbase_f b"

datatype frequ = Fq_hz | Fq_khz | Fq_mhz | Fq_ghz
fun freq_mhz :: "frequ \<Rightarrow> rat" where
  "freq_mhz Fq_hz = 1 / 1000000" | "freq_mhz Fq_khz = 1 / 1000" | "freq_mhz Fq_mhz = 1"
| "freq_mhz Fq_ghz = 1000"

datatype dpre = Dp_one | Dp_k | Dp_m | Dp_g | Dp_t
fun dpre_f :: "dpre \<Rightarrow> rat" where
  "dpre_f Dp_one = 1" | "dpre_f Dp_k = 1000" | "dpre_f Dp_m = 1000000"
| "dpre_f Dp_g = 1000000000" | "dpre_f Dp_t = 1000000000000"

datatype rateu = Ru_bps | Ru_kbps | Ru_mbps | Ru_gbps
fun rate_f :: "rateu \<Rightarrow> rat" where
  "rate_f Ru_bps = 1" | "rate_f Ru_kbps = 1000" | "rate_f Ru_mbps = 1000000" | "rate_f Ru_gbps = 1000000000"

datatype wunit = Wu_kg | Wu_lb
datatype rstyle = Rs_v1 | Rs_v2

lemma lenf_pos [simp]: "0 < lenf u" by (cases u) simp_all
lemma massf_pos [simp]: "0 < massf u" by (cases u) simp_all
lemma forcef_pos [simp]: "0 < forcef u" by (cases u) simp_all
lemma speedf_pos [simp]: "0 < speedf u" by (cases u) simp_all
lemma dscale_f_pos [simp]: "0 < dscale_f u" by (cases u) simp_all
lemma dbase_f_pos [simp]: "0 < dbase_f u" by (cases u) (simp_all add: mile_km_def au_km_def)
lemma freq_mhz_pos [simp]: "0 < freq_mhz u" by (cases u) simp_all
lemma dpre_f_pos [simp]: "0 < dpre_f u" by (cases u) simp_all
lemma rate_f_pos [simp]: "0 < rate_f u" by (cases u) simp_all

section \<open>Requests and outcomes\<close>

text \<open>A planetary body as the question gives it: a mass in kg and a radius in a
length unit (SI), or multiples of Earth's mass and radius.\<close>
datatype pbody = Pb_si rat rat lenu | Pb_earth rat rat

datatype request =
    PGravity pbody | PEscape pbody | POrbV pbody | PDensity pbody
  | PWeightE rat rat rat
  | OSync "obody option" | OSpeed "obody option" "rat option" | OPeriod "obody option" "rat option"
  | OEscape "obody option" "rat option"
  | OHohDv "obody option" "(rat \<times> rat) option" | OHohTime "obody option" "(rat \<times> rat) option"
  | SExhaust rat | STwr rat forceu rat massu | SMassFlow rat forceu vesrc
  | SBurn rat forceu vesrc rat massu | SDeltaV vesrc rat massu rat massu
  | SProp0 vesrc rat speedu rat massu | SPropF vesrc rat speedu rat massu
  | CLight "dist option" bool | CFspl "dist option" "(rat \<times> frequ) option"
  | CXfer rat dpre bool rat rateu | CBits "dist option" "(rat \<times> rateu) option"
  | AProp abody aprop | AFake String.literal | ALight abody | AWeight rat wunit abody
  | ARatio rstyle abody abody aprop | AYears abody | AMoonKm | AMoonKkm

text \<open>In @{text SProp0} the mass is the initial mass; in @{text SPropF} the final
(dry) mass. @{text "SDeltaV ve m0 mf"}: initial then final mass. @{text CLight} is
the one-way light time, or the round trip when the flag is set. CXfer (n, p, bytes, r, u): n units with prefix p (bytes when the flag is set) at rate r u.\<close>

datatype need = N_body | N_alt | N_alts | N_dist_freq | N_dist_rate | N_dist
datatype reason = R_nonpositive | R_final_exceeds_initial
datatype decline = Underspecified need | NoSync | Impossible reason | Unknown | NoValue | Imprecise

datatype outcome = Exact String.literal rat | Approx String.literal "int \<times> int"
  | Fact String.literal cell | Decline decline

subsection \<open>Planetary bodies\<close>

fun pm_i :: "pbody \<Rightarrow> rat" where "pm_i (Pb_si M R u) = M" | "pm_i (Pb_earth M R) = M"
fun pr_i :: "pbody \<Rightarrow> rat" where "pr_i (Pb_si M R u) = R * lenf u" | "pr_i (Pb_earth M R) = R"
fun pmu :: "pbody \<Rightarrow> rat" where "pmu (Pb_si M R u) = 1" | "pmu (Pb_earth M R) = mass_E"
fun pru :: "pbody \<Rightarrow> rat" where "pru (Pb_si M R u) = 1" | "pru (Pb_earth M R) = radius_E"
fun pconst :: "pbody \<Rightarrow> rat" where "pconst (Pb_si M R u) = grav_G" | "pconst (Pb_earth M R) = grav_E"

definition pmass :: "pbody \<Rightarrow> rat" where "pmass b = pm_i b * pmu b"
definition prad :: "pbody \<Rightarrow> rat" where "prad b = pr_i b * pru b"
definition pgrav :: "pbody \<Rightarrow> rat" where "pgrav b = pconst b * pm_i b / pr_i b ^ 2"
definition ppos :: "pbody \<Rightarrow> bool" where "ppos b \<longleftrightarrow> 0 < pm_i b \<and> 0 < pr_i b"

lemma pmu_pos [simp]: "0 < pmu b" by (cases b) (simp_all add: mass_E_def)
lemma pru_pos [simp]: "0 < pru b" by (cases b) (simp_all add: radius_E_def)
lemma pconst_pos [simp]: "0 < pconst b" by (cases b) (simp_all add: grav_E_def)

lemma ppos_pm:
  assumes "ppos b"
  shows "0 < pm_i b"
  using assms unfolding ppos_def by (rule conjunct1)

lemma ppos_pr:
  assumes "ppos b"
  shows "0 < pr_i b"
  using assms unfolding ppos_def by (rule conjunct2)

lemma ppos_mass:
  assumes "ppos b"
  shows "0 < pmass b"
  unfolding pmass_def by (rule mult_pos_pos[OF ppos_pm[OF assms] pmu_pos])

lemma ppos_rad:
  assumes "ppos b"
  shows "0 < prad b"
  unfolding prad_def by (rule mult_pos_pos[OF ppos_pr[OF assms] pru_pos])

subsection \<open>Defaults for fields the question may lack\<close>

definition obd :: "obody option \<Rightarrow> obody" where "obd ob = (case ob of Some b \<Rightarrow> b | None \<Rightarrow> O_earth)"
definition opd :: "rat option \<Rightarrow> rat" where "opd oa = (case oa of Some a \<Rightarrow> a | None \<Rightarrow> 0)"
definition prd :: "(rat \<times> rat) option \<Rightarrow> rat \<times> rat" where
  "prd p = (case p of Some x \<Rightarrow> x | None \<Rightarrow> (0, 0))"
definition sidv :: "obody \<Rightarrow> rat" where "sidv b = (case sidereal b of Some t \<Rightarrow> t | None \<Rightarrow> 1)"
definition dd :: "dist option \<Rightarrow> rat" where "dd d = (case d of Some x \<Rightarrow> dkm x | None \<Rightarrow> 1)"
definition ff :: "(rat \<times> frequ) option \<Rightarrow> rat" where
  "ff f = (case f of Some (x, u) \<Rightarrow> x * freq_mhz u | None \<Rightarrow> 1)"
definition rr :: "(rat \<times> rateu) option \<Rightarrow> rat" where
  "rr f = (case f of Some (x, u) \<Rightarrow> x * rate_f u | None \<Rightarrow> 1)"

definition rad1 :: "obody option \<Rightarrow> rat option \<Rightarrow> rat" where
  "rad1 ob oa = brad (obd ob) + opd oa"
definition hr1 :: "obody option \<Rightarrow> (rat \<times> rat) option \<Rightarrow> rat" where
  "hr1 ob p = brad (obd ob) + fst (prd p)"
definition hr2 :: "obody option \<Rightarrow> (rat \<times> rat) option \<Rightarrow> rat" where
  "hr2 ob p = brad (obd ob) + snd (prd p)"

definition dur_scale :: "rat \<Rightarrow> rat" where
  "dur_scale s = (if s < 120 then 1 else if s < 7200 then 60 else if s < 172800 then 3600 else 86400)"

definition dur_unit :: "rat \<Rightarrow> String.literal" where
  "dur_unit s = (if s < 120 then STR '' seconds'' else if s < 7200 then STR '' minutes''
     else if s < 172800 then STR '' hours'' else STR '' days'')"

lemma dur_scale_pos [simp]: "0 < dur_scale s" by (simp add: dur_scale_def)

section \<open>Declines\<close>

text \<open>Underspecified: a body, altitude, distance, frequency or rate the formula
needs is absent (the organs' need).\<close>
fun missing :: "request \<Rightarrow> need option" where
  "missing (OSync None) = Some N_body"
| "missing (OSpeed None a) = Some N_body"
| "missing (OSpeed (Some b) None) = Some N_alt"
| "missing (OPeriod None a) = Some N_body"
| "missing (OPeriod (Some b) None) = Some N_alt"
| "missing (OEscape None a) = Some N_body"
| "missing (OHohDv None p) = Some N_body"
| "missing (OHohDv (Some b) None) = Some N_alts"
| "missing (OHohTime None p) = Some N_body"
| "missing (OHohTime (Some b) None) = Some N_alts"
| "missing (CLight None rt) = Some N_dist"
| "missing (CFspl d f) = (if d = None \<or> f = None then Some N_dist_freq else None)"
| "missing (CBits d r) = (if d = None \<or> r = None then Some N_dist_rate else None)"
| "missing r = None"

text \<open>No synchronous orbit: the body has no fixed sidereal rotation in the organ's table.\<close>
fun nosync :: "request \<Rightarrow> bool" where
  "nosync (OSync (Some b)) = (sidereal b = None)"
| "nosync r = False"

text \<open>Impossible: a quantity that is a divisor, a radius, a logarithm's argument or a
final mass above the initial mass.\<close>
fun reason_of :: "request \<Rightarrow> reason option" where
  "reason_of (PGravity b) = (if ppos b then None else Some R_nonpositive)"
| "reason_of (PEscape b) = (if ppos b then None else Some R_nonpositive)"
| "reason_of (POrbV b) = (if ppos b then None else Some R_nonpositive)"
| "reason_of (PDensity b) = (if ppos b then None else Some R_nonpositive)"
| "reason_of (PWeightE M R k) = (if 0 < M \<and> 0 < R then None else Some R_nonpositive)"
| "reason_of (OSpeed ob oa) = (if 0 < rad1 ob oa then None else Some R_nonpositive)"
| "reason_of (OPeriod ob oa) = (if 0 < rad1 ob oa then None else Some R_nonpositive)"
| "reason_of (OEscape ob oa) = (if 0 < rad1 ob oa then None else Some R_nonpositive)"
| "reason_of (OHohDv ob p) = (if 0 < hr1 ob p \<and> 0 < hr2 ob p then None else Some R_nonpositive)"
| "reason_of (OHohTime ob p) = (if 0 < hr1 ob p \<and> 0 < hr2 ob p then None else Some R_nonpositive)"
| "reason_of (STwr F fu M mw) = (if 0 < M * massf mw then None else Some R_nonpositive)"
| "reason_of (SMassFlow F fu v) = (if 0 < ve_of v then None else Some R_nonpositive)"
| "reason_of (SBurn F fu v P pu) =
     (if 0 < ve_of v \<and> 0 < F * forcef fu then None else Some R_nonpositive)"
| "reason_of (SDeltaV v M0 u0 MF uf) =
     (if M0 * massf u0 < MF * massf uf then Some R_final_exceeds_initial
      else if 0 < ve_of v \<and> 0 < M0 * massf u0 \<and> 0 < MF * massf uf then None else Some R_nonpositive)"
| "reason_of (SProp0 v dv du M0 u0) = (if 0 < ve_of v then None else Some R_nonpositive)"
| "reason_of (SPropF v dv du MF uf) = (if 0 < ve_of v then None else Some R_nonpositive)"
| "reason_of (CFspl d f) = (if 0 < dd d \<and> 0 < ff f then None else Some R_nonpositive)"
| "reason_of (CXfer n p bytes r u) = (if 0 < r * rate_f u then None else Some R_nonpositive)"
| "reason_of (ARatio rs b1 b2 p) = (if cell_num (sheet b2 p) \<noteq> 0 then None else Some R_nonpositive)"
| "reason_of r = None"

fun fake :: "request \<Rightarrow> bool" where "fake (AFake n) = True" | "fake r = False"

text \<open>NASA marks the value Unknown.\<close>
fun novalue :: "request \<Rightarrow> bool" where
  "novalue (AProp b p) = is_unknown (sheet b p)" | "novalue r = False"

definition decline_of :: "request \<Rightarrow> decline option" where
  "decline_of r = (case missing r of Some w \<Rightarrow> Some (Underspecified w)
     | None \<Rightarrow> if nosync r then Some NoSync
       else (case reason_of r of Some w \<Rightarrow> Some (Impossible w)
         | None \<Rightarrow> if fake r then Some Unknown else if novalue r then Some NoValue else None))"

lemma decl_under: "decline_of r = Some (Underspecified w) \<longleftrightarrow> missing r = Some w"
  by (auto simp: decline_of_def split: option.splits if_splits)

lemma decl_nosync: "decline_of r = Some NoSync \<longleftrightarrow> missing r = None \<and> nosync r"
  by (auto simp: decline_of_def split: option.splits if_splits)

lemma decl_imp: "decline_of r = Some (Impossible w) \<longleftrightarrow>
    missing r = None \<and> \<not> nosync r \<and> reason_of r = Some w"
  by (auto simp: decline_of_def split: option.splits if_splits)

lemma decl_unknown: "decline_of r = Some Unknown \<longleftrightarrow>
    missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> fake r"
  by (auto simp: decline_of_def split: option.splits if_splits)

lemma decl_novalue: "decline_of r = Some NoValue \<longleftrightarrow>
    missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> \<not> fake r \<and> novalue r"
  by (auto simp: decline_of_def split: option.splits if_splits)

lemma decl_not_imprecise: "decline_of r \<noteq> Some Imprecise"
  by (auto simp: decline_of_def split: option.splits if_splits)

lemma decl_none: "decline_of r = None \<Longrightarrow>
    missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> \<not> fake r \<and> \<not> novalue r"
  by (auto simp: decline_of_def split: option.splits if_splits)

section \<open>Values\<close>

subsection \<open>Which kinds are enclosed and which are exact\<close>

fun is_approx :: "request \<Rightarrow> bool" where
  "is_approx (PEscape b) = True" | "is_approx (POrbV b) = True" | "is_approx (PDensity b) = True"
| "is_approx (OSync b) = True" | "is_approx (OSpeed b a) = True" | "is_approx (OPeriod b a) = True"
| "is_approx (OEscape b a) = True" | "is_approx (OHohDv b p) = True" | "is_approx (OHohTime b p) = True"
| "is_approx (SDeltaV v a b c d) = True" | "is_approx (SProp0 v a b c d) = True"
| "is_approx (SPropF v a b c d) = True" | "is_approx (CFspl d f) = True"
| "is_approx r = False"

fun is_fact :: "request \<Rightarrow> bool" where "is_fact (AProp b p) = True" | "is_fact r = False"

subsection \<open>Exact values\<close>

fun qval :: "request \<Rightarrow> rat" where
  "qval (PGravity b) = pgrav b"
| "qval (PWeightE M R k) = k * (grav_E * M / R ^ 2)"
| "qval (SExhaust i) = i * std_g0"
| "qval (STwr F fu M mw) = F * forcef fu / (M * massf mw * std_g0)"
| "qval (SMassFlow F fu v) = F * forcef fu / ve_of v"
| "qval (SBurn F fu v P pu) = P * massf pu / (F * forcef fu / ve_of v)"
| "qval (CLight d rt) = (if rt then 2 else 1) * dd d / light_c"
| "qval (CXfer n p bytes r u) = n * dpre_f p * (if bytes then 8 else 1) / (r * rate_f u)"
| "qval (CBits d r) = rr r * dd d / light_c"
| "qval (ALight b) = dist_of b * 1000000 / light_c / 60"
| "qval (AWeight w u b) = w * grav_of b / grav_of A_earth"
| "qval (ARatio rs b1 b2 p) = cell_num (sheet b1 p) / cell_num (sheet b2 p)"
| "qval (AYears b) = period_of b / (36525 / 100)"
| "qval AMoonKm = dist_of A_moon * 1000000"
| "qval AMoonKkm = dist_of A_moon * 1000"
| "qval r = 0"

subsection \<open>Enclosed values: the expression the interval arithmetic evaluates\<close>

abbreviation fM :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where "fM a b \<equiv> floatarith.Mult a b"
abbreviation fA :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where "fA a b \<equiv> floatarith.Add a b"
abbreviation fN :: "floatarith \<Rightarrow> floatarith" where "fN a \<equiv> floatarith.Minus a"
abbreviation fV :: "floatarith \<Rightarrow> floatarith" where "fV a \<equiv> floatarith.Inverse a"
abbreviation fS :: "floatarith \<Rightarrow> floatarith" where "fS a \<equiv> floatarith.Sqrt a"
abbreviation fL :: "floatarith \<Rightarrow> floatarith" where "fL a \<equiv> floatarith.Ln a"
abbreviation fE :: "floatarith \<Rightarrow> floatarith" where "fE a \<equiv> floatarith.Exp a"
abbreviation fAbs :: "floatarith \<Rightarrow> floatarith" where "fAbs a \<equiv> floatarith.Abs a"
abbreviation fPi :: floatarith where "fPi \<equiv> floatarith.Pi"

fun fa :: "request \<Rightarrow> floatarith" where
  "fa (PEscape b) = fM (fS (Q (2 * grav_G * pmass b / prad b))) (Q (1 / 1000))"
| "fa (POrbV b) = fM (fS (Q (grav_G * pmass b / prad b))) (Q (1 / 1000))"
| "fa (PDensity b) = fM (Q (3 * pmass b / (4000 * prad b ^ 3))) (fV fPi)"
| "fa (OSync ob) = fA (fE (fM (fL (fM (Q (mu (obd ob) * sidv (obd ob) ^ 2))
       (fV (fM (I 4) (floatarith.Power fPi 2))))) (Q (1 / 3)))) (fN (Q (brad (obd ob))))"
| "fa (OSpeed ob oa) = fS (Q (mu (obd ob) / rad1 ob oa))"
| "fa (OPeriod ob oa) = fM (fM (fM (I 2) fPi) (fS (Q (rad1 ob oa ^ 3 / mu (obd ob))))) (Q (1 / 60))"
| "fa (OEscape ob oa) = fS (Q (2 * mu (obd ob) / rad1 ob oa))"
| "fa (OHohDv ob p) =
     fA (fAbs (fM (fS (Q (mu (obd ob) / hr1 ob p)))
                  (fA (fS (Q (2 * hr2 ob p / (hr1 ob p + hr2 ob p)))) (fN (I 1)))))
        (fAbs (fM (fS (Q (mu (obd ob) / hr2 ob p)))
                  (fA (I 1) (fN (fS (Q (2 * hr1 ob p / (hr1 ob p + hr2 ob p))))))))"
| "fa (OHohTime ob p) =
     fM (fM fPi (fS (Q (((hr1 ob p + hr2 ob p) / 2) ^ 3 / mu (obd ob))))) (Q (1 / 3600))"
| "fa (SDeltaV v M0 u0 MF uf) = fM (Q (ve_of v)) (fL (Q (M0 * massf u0 / (MF * massf uf))))"
| "fa (SProp0 v dv du M0 u0) =
     fM (Q (M0 * massf u0)) (fA (I 1) (fN (fE (fN (Q (dv * speedf du / ve_of v))))))"
| "fa (SPropF v dv du MF uf) =
     fM (Q (MF * massf uf)) (fA (fE (Q (dv * speedf du / ve_of v))) (fN (I 1)))"
| "fa (CFspl d f) =
     fA (fM (I 20) (fM (fL (Q (dd d * ff f))) (fV (fL (I 10))))) (Q fspl_const)"
| "fa r = I 0"

definition phys :: "request \<Rightarrow> real" where
  "phys r = (if is_approx r then interpret_floatarith (fa r) [] else rl (qval r))"

section \<open>Names, styles and the kernel\<close>

fun prop_name :: "aprop \<Rightarrow> String.literal" where
  "prop_name P_mass = STR ''mass''" | "prop_name P_diameter = STR ''diameter''"
| "prop_name P_density = STR ''density''" | "prop_name P_gravity = STR ''gravity''"
| "prop_name P_escape = STR ''escape velocity''" | "prop_name P_rotation = STR ''rotation period''"
| "prop_name P_day = STR ''length of day''" | "prop_name P_distance = STR ''distance from the sun''"
| "prop_name P_perihelion = STR ''perihelion''" | "prop_name P_aphelion = STR ''aphelion''"
| "prop_name P_period = STR ''orbital period''" | "prop_name P_velocity = STR ''orbital velocity''"
| "prop_name P_inclination = STR ''orbital inclination''"
| "prop_name P_eccentricity = STR ''orbital eccentricity''" | "prop_name P_tilt = STR ''axial tilt''"
| "prop_name P_temperature = STR ''mean temperature''" | "prop_name P_pressure = STR ''surface pressure''"
| "prop_name P_moons = STR ''number of moons''" | "prop_name P_rings = STR ''ring system''"
| "prop_name P_magnetic = STR ''magnetic field''"

fun prop_kind :: "aprop \<Rightarrow> String.literal" where
  "prop_kind P_mass = STR ''mass''" | "prop_kind P_diameter = STR ''diameter''"
| "prop_kind P_density = STR ''density''" | "prop_kind P_gravity = STR ''gravity''"
| "prop_kind P_escape = STR ''escape_velocity''" | "prop_kind P_rotation = STR ''rotation_period''"
| "prop_kind P_day = STR ''length_of_day''" | "prop_kind P_distance = STR ''distance_from_the_sun''"
| "prop_kind P_perihelion = STR ''perihelion''" | "prop_kind P_aphelion = STR ''aphelion''"
| "prop_kind P_period = STR ''orbital_period''" | "prop_kind P_velocity = STR ''orbital_velocity''"
| "prop_kind P_inclination = STR ''orbital_inclination''"
| "prop_kind P_eccentricity = STR ''orbital_eccentricity''" | "prop_kind P_tilt = STR ''axial_tilt''"
| "prop_kind P_temperature = STR ''mean_temperature''" | "prop_kind P_pressure = STR ''surface_pressure''"
| "prop_kind P_moons = STR ''number_of_moons''" | "prop_kind P_rings = STR ''ring_system''"
| "prop_kind P_magnetic = STR ''magnetic_field''"

text \<open>The unit after a sheet value (the organ's PROPS table, ASCII).\<close>
fun prop_unit :: "aprop \<Rightarrow> String.literal" where
  "prop_unit P_mass = STR '' x10^24 kg''" | "prop_unit P_diameter = STR '' km''"
| "prop_unit P_density = STR '' kg/m3''" | "prop_unit P_gravity = STR '' m/s2''"
| "prop_unit P_escape = STR '' km/s''" | "prop_unit P_rotation = STR '' hours''"
| "prop_unit P_day = STR '' hours''" | "prop_unit P_distance = STR '' million km''"
| "prop_unit P_period = STR '' Earth days''" | "prop_unit P_velocity = STR '' km/s''"
| "prop_unit P_tilt = STR '' degrees''" | "prop_unit P_temperature = STR '' C''"
| "prop_unit P_pressure = STR '' bar''" | "prop_unit p = STR ''''"

fun kind_of :: "request \<Rightarrow> String.literal" where
  "kind_of (PGravity b) = STR ''gravity''" | "kind_of (PEscape b) = STR ''escape''"
| "kind_of (POrbV b) = STR ''orbital_v''" | "kind_of (PDensity b) = STR ''density''"
| "kind_of (PWeightE M R k) = STR ''weight''"
| "kind_of (OSync b) = STR ''sync_alt''" | "kind_of (OSpeed b a) = STR ''orbit_speed''"
| "kind_of (OPeriod b a) = STR ''period''" | "kind_of (OEscape b a) = STR ''escape''"
| "kind_of (OHohDv b p) = STR ''hohmann_dv''" | "kind_of (OHohTime b p) = STR ''hohmann_time''"
| "kind_of (SExhaust i) = STR ''exhaust_velocity''" | "kind_of (STwr F fu M mw) = STR ''twr''"
| "kind_of (SMassFlow F fu v) = STR ''mass_flow''" | "kind_of (SBurn F fu v P pu) = STR ''burn_time''"
| "kind_of (SDeltaV v a b c d) = STR ''delta_v''" | "kind_of (SProp0 v a b c d) = STR ''propellant''"
| "kind_of (SPropF v a b c d) = STR ''propellant''"
| "kind_of (CLight d rt) = (if rt then STR ''round_trip'' else STR ''light_time'')"
| "kind_of (CFspl d f) = STR ''fspl''" | "kind_of (CXfer n p bytes r u) = STR ''transfer_time''"
| "kind_of (CBits d r) = STR ''bits_in_flight''"
| "kind_of (AProp b p) = prop_kind p" | "kind_of (AFake n) = STR ''unknown''"
| "kind_of (ALight b) = STR ''light_time''" | "kind_of (AWeight w u b) = STR ''weight''"
| "kind_of (ARatio rs a b p) = STR ''ratio''" | "kind_of (AYears b) = STR ''year_years''"
| "kind_of AMoonKm = STR ''distance_from_earth''"
| "kind_of AMoonKkm = STR ''distance from earth''"

text \<open>The style each kind is stated in (the organs' own number layout).\<close>
fun style_of :: "request \<Rightarrow> style" where
  "style_of (PGravity b) = St_pl" | "style_of (PEscape b) = St_pl" | "style_of (POrbV b) = St_pl"
| "style_of (PDensity b) = St_pl" | "style_of (PWeightE M R k) = St_pl"
| "style_of (SExhaust i) = St_sc" | "style_of (STwr F fu M mw) = St_sc"
| "style_of (SMassFlow F fu v) = St_sc" | "style_of (SBurn F fu v P pu) = St_sc"
| "style_of (SDeltaV v a b c d) = St_sc" | "style_of (SProp0 v a b c d) = St_sc"
| "style_of (SPropF v a b c d) = St_sc"
| "style_of (CFspl d f) = St_f 2"
| "style_of (ALight b) = St_f 1" | "style_of (AWeight w u b) = St_f 1"
| "style_of (ARatio rs a b p) = (case rs of Rs_v1 \<Rightarrow> St_f 2 | Rs_v2 \<Rightarrow> St_r3)"
| "style_of (AYears b) = St_f 2" | "style_of AMoonKkm = St_f 0"
| "style_of r = St_orb"

text \<open>A duration is shown in seconds, minutes, hours or days.\<close>
fun is_dur :: "request \<Rightarrow> bool" where
  "is_dur (CLight d rt) = True" | "is_dur (CXfer n p bytes r u) = True" | "is_dur r = False"

definition qshown :: "request \<Rightarrow> rat \<Rightarrow> rat" where
  "qshown r q = (if is_dur r then q / dur_scale q else q)"

definition answer_gen :: "request \<Rightarrow> outcome" where
  "answer_gen r = (if is_approx r then
     (case enclose (style_of r) prec (fa r) of None \<Rightarrow> Decline Imprecise
      | Some d \<Rightarrow> Approx (kind_of r) d)
     else Exact (kind_of r) (qval r))"

definition answer_of :: "request \<Rightarrow> outcome" where
  "answer_of r = (case r of AProp b p \<Rightarrow> Fact (prop_kind p) (sheet b p) | _ \<Rightarrow> answer_gen r)"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

lemma answer_nonfact: "\<not> is_fact r \<Longrightarrow> answer_of r = answer_gen r"
  by (cases r) (simp_all add: answer_of_def)

lemma fact_shape: "is_fact r \<Longrightarrow> \<exists>b p. r = AProp b p"
  by (cases r) simp_all

lemma answer_decline:
  assumes "answer_of r = Decline w"
  shows "w = Imprecise"
proof (cases "is_fact r")
  case True
  then show ?thesis using fact_shape[OF True] assms by (auto simp: answer_of_def)
next
  case False
  then show ?thesis using answer_nonfact[OF False] assms
    by (auto simp: answer_gen_def split: if_splits option.splits)
qed

lemma answer_exact:
  assumes "answer_of r = Exact k q"
  shows "k = kind_of r \<and> q = qval r \<and> \<not> is_approx r \<and> \<not> is_fact r"
proof (cases "is_fact r")
  case True
  then show ?thesis using fact_shape[OF True] assms by (auto simp: answer_of_def)
next
  case False
  then show ?thesis using answer_nonfact[OF False] assms
    by (auto simp: answer_gen_def split: if_splits option.splits)
qed

lemma answer_approx:
  assumes "answer_of r = Approx k d"
  shows "k = kind_of r \<and> is_approx r \<and>
     \<bar>dec_val d - phys r\<bar> \<le> pow10 (snd d) / 2 + \<bar>phys r\<bar> / 1000000 + 1 / 1000000000"
proof (cases "is_fact r")
  case True
  then show ?thesis using fact_shape[OF True] assms by (auto simp: answer_of_def)
next
  case False
  have e: "is_approx r" and en: "enclose (style_of r) prec (fa r) = Some d" and k: "k = kind_of r"
    using answer_nonfact[OF False] assms by (auto simp: answer_gen_def split: if_splits option.splits)
  have "phys r = interpret_floatarith (fa r) []" using e by (simp add: phys_def)
  then show ?thesis using enclose_sound[OF en] e k by simp
qed

lemma answer_fact:
  assumes "answer_of r = Fact k c"
  shows "\<exists>b p. r = AProp b p \<and> k = kind_of r \<and> c = sheet b p"
proof (cases "is_fact r")
  case True
  then show ?thesis using fact_shape[OF True] assms by (auto simp: answer_of_def)
next
  case False
  then show ?thesis using answer_nonfact[OF False] assms
    by (auto simp: answer_gen_def split: if_splits option.splits)
qed

lemma decl_none_iff: "decline_of r = None \<longleftrightarrow>
    missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> \<not> fake r \<and> \<not> novalue r"
  by (auto simp: decline_of_def split: option.splits if_splits)

text \<open>Every exact value the kernel states is the request's value, and only for
requests that are fully specified and possible.\<close>
theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> k = kind_of r \<and> q = qval r \<and>
         rl q = phys r \<and> \<not> is_approx r \<and> \<not> is_fact r"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Exact k q"
    using assms by (auto simp: kernel_def split: option.splits)
  have x: "k = kind_of r \<and> q = qval r \<and> \<not> is_approx r \<and> \<not> is_fact r" by (rule answer_exact[OF a])
  then have p: "phys r = rl (qval r)" by (simp add: phys_def)
  show ?thesis using decl_none[OF nd] x p by simp
qed

text \<open>Every decimal the kernel states for an enclosed kind is within half a unit of
its last digit, plus one part in a million and 10^-9, of the real model
(the interpretation of the expression the interval arithmetic evaluated).\<close>
theorem kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> k = kind_of r \<and> is_approx r \<and>
         \<bar>dec_val d - phys r\<bar> \<le> pow10 (snd d) / 2 + \<bar>phys r\<bar> / 1000000 + 1 / 1000000000"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Approx k d"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using decl_none[OF nd] answer_approx[OF a] by simp
qed

text \<open>A sheet value is stated only when NASA gives one.\<close>
theorem kernel_fact_sound:
  assumes "kernel r = Fact k c"
  shows "\<exists>b p. r = AProp b p \<and> k = prop_kind p \<and> c = sheet b p \<and> \<not> is_unknown c"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Fact k c"
    using assms by (auto simp: kernel_def split: option.splits)
  obtain b p where r: "r = AProp b p" and k: "k = kind_of r" and c: "c = sheet b p"
    using answer_fact[OF a] by blast
  have "\<not> novalue r" using decl_none[OF nd] by simp
  then show ?thesis using r k c by simp
qed

lemma kernel_decl: "w \<noteq> Imprecise \<Longrightarrow> (kernel r = Decline w \<longleftrightarrow> decline_of r = Some w)"
  by (cases "decline_of r") (auto simp: kernel_def dest: answer_decline)

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified w) \<longleftrightarrow> missing r = Some w"
  using kernel_decl[of "Underspecified w" r] decl_under by simp

theorem kernel_nosync:
  "kernel r = Decline NoSync \<longleftrightarrow> missing r = None \<and> nosync r"
  using kernel_decl[of NoSync r] decl_nosync by simp

theorem kernel_impossible:
  "kernel r = Decline (Impossible w) \<longleftrightarrow> missing r = None \<and> \<not> nosync r \<and> reason_of r = Some w"
  using kernel_decl[of "Impossible w" r] decl_imp by simp

theorem kernel_unknown:
  "kernel r = Decline Unknown \<longleftrightarrow>
     missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> fake r"
  using kernel_decl[of Unknown r] decl_unknown by simp

theorem kernel_novalue:
  "kernel r = Decline NoValue \<longleftrightarrow>
     missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> \<not> fake r \<and> novalue r"
  using kernel_decl[of NoValue r] decl_novalue by simp

text \<open>The one numerical decline: the enclosure was too wide to pin the digits. It
happens only to enclosed kinds that are fully specified and possible.\<close>
theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None \<and> \<not> nosync r \<and> reason_of r = None \<and> is_approx r"
proof -
  have nd: "decline_of r = None"
    using assms decl_not_imprecise by (auto simp: kernel_def split: option.splits)
  have a: "answer_of r = Decline Imprecise" using assms nd by (simp add: kernel_def)
  have nf: "\<not> is_fact r"
    using a by (cases r) (simp_all add: answer_of_def)
  have "is_approx r"
    using a answer_nonfact[OF nf] by (auto simp: answer_gen_def split: if_splits option.splits)
  then show ?thesis using decl_none[OF nd] by simp
qed

lemma kernel_exact_of:
  assumes "decline_of r = None" "\<not> is_approx r" "\<not> is_fact r"
  shows "kernel r = Exact (kind_of r) (qval r)"
  using assms answer_nonfact[of r] by (simp add: kernel_def answer_gen_def)

theorem kernel_deterministic: "kernel r = o1 \<Longrightarrow> kernel r = o2 \<Longrightarrow> o1 = o2"
  by simp

section \<open>What each kind means\<close>

lemma pos_ne0:
  fixes x :: "'a::linordered_field"
  assumes "0 < x"
  shows "x \<noteq> 0"
proof
  assume "x = 0"
  then show False using assms by simp
qed

lemma sqrt_model:
  fixes x y :: rat
  assumes "0 \<le> x" "0 < y"
  shows "(sqrt (rl (x / y)))\<^sup>2 * rl y = rl x"
proof -
  have a: "0 \<le> x / y" by (rule divide_nonneg_pos[OF assms(1) assms(2)])
  have a': "0 \<le> rl (x / y)" using a by simp
  have e1: "(sqrt (rl (x / y)))\<^sup>2 = rl (x / y)" using a' by simp
  have ne: "y \<noteq> 0" by (rule pos_ne0[OF assms(2)])
  have h: "x / y * y = x" using ne by (simp add: field_simps)
  have e2: "rl (x / y) * rl y = rl x" by (metis h of_rat_mult)
  show ?thesis using e1 e2 by simp
qed

lemma cbrt_cube:
  fixes x :: real
  assumes "0 < x"
  shows "exp (ln x * (1 / 3)) ^ 3 = x"
proof -
  have "exp (ln x * (1 / 3)) ^ 3 = exp ((of_nat (3::nat) :: real) * (ln x * (1 / 3)))"
    by (rule exp_of_nat_mult[symmetric])
  also have "(of_nat (3::nat) :: real) * (ln x * (1 / 3)) = ln x" by (simp add: field_simps)
  also have "exp (ln x) = x" using assms by simp
  finally show ?thesis .
qed

lemma unscale:
  fixes k S :: real
  assumes "k \<noteq> 0"
  shows "k * (S * (1 / k)) = S"
  using assms by (simp add: field_simps)

text \<open>If a * R = 2 c and b * R = c with R nonzero then a = 2 b (used to compare an
escape speed with a circular speed from their defining equations).\<close>
lemma cancel_two:
  fixes a b R c :: real
  assumes "R \<noteq> 0" "a * R = 2 * c" "b * R = c"
  shows "a = 2 * b"
proof -
  have "a * R = (2 * b) * R" using assms(2) assms(3) by (simp add: mult.assoc)
  then show ?thesis using assms(1) by simp
qed

subsection \<open>Planetary\<close>

text \<open>Surface gravity: g R^2 = G M (G for SI inputs, 9.81 for Earth multiples).\<close>
theorem gravity_model:
  assumes "ppos b"
  shows "kernel (PGravity b) = Exact (STR ''gravity'') (pgrav b) \<and>
         pgrav b * pr_i b ^ 2 = pconst b * pm_i b"
proof -
  have p: "0 < pr_i b" by (rule ppos_pr[OF assms])
  have nz: "pr_i b ^ 2 \<noteq> 0" by (rule power_not_zero[OF pos_ne0[OF p]])
  have nd: "decline_of (PGravity b) = None" using assms by (simp add: decl_none_iff)
  show ?thesis using kernel_exact_of[OF nd] nz by (simp add: pgrav_def)
qed

text \<open>Weight on an Earth-multiple body: weight = the object's mass times g, with
g R^2 = 9.81 M.\<close>
theorem weight_model:
  assumes "0 < M" "0 < R"
  shows "kernel (PWeightE M R k) = Exact (STR ''weight'') (k * pgrav (Pb_earth M R)) \<and>
         k * pgrav (Pb_earth M R) * R ^ 2 = k * (grav_E * M)"
proof -
  have nz: "R ^ 2 \<noteq> 0" by (rule power_not_zero[OF pos_ne0[OF assms(2)]])
  have nd: "decline_of (PWeightE M R k) = None" using assms by (simp add: decl_none_iff)
  show ?thesis using kernel_exact_of[OF nd] nz by (simp add: pgrav_def)
qed

text \<open>Escape velocity: (1000 v)^2 R = 2 G M, with v in km/s and M, R in SI.\<close>
theorem escape_model:
  assumes "ppos b"
  shows "(1000 * phys (PEscape b)) ^ 2 * rl (prad b) = rl (2 * grav_G * pmass b)"
proof -
  have x1: "0 < 2 * grav_G * pmass b" using ppos_mass[OF assms] by simp
  have x0: "0 \<le> 2 * grav_G * pmass b" by (rule less_imp_le[OF x1])
  have y0: "0 < prad b" by (rule ppos_rad[OF assms])
  define S where "S = sqrt (rl (2 * grav_G * pmass b / prad b))"
  have ph: "phys (PEscape b) = S * (1 / 1000)" by (simp add: phys_def S_def of_rat_divide)
  have e: "1000 * phys (PEscape b) = S" unfolding ph by (rule unscale) simp
  have sm: "S ^ 2 * rl (prad b) = rl (2 * grav_G * pmass b)"
    using sqrt_model[OF x0 y0] unfolding S_def by simp
  show ?thesis unfolding e by (rule sm)
qed

text \<open>Circular orbital velocity at the surface: (1000 v)^2 R = G M.\<close>
theorem orbital_velocity_model:
  assumes "ppos b"
  shows "(1000 * phys (POrbV b)) ^ 2 * rl (prad b) = rl (grav_G * pmass b)"
proof -
  have x1: "0 < grav_G * pmass b" using ppos_mass[OF assms] by simp
  have x0: "0 \<le> grav_G * pmass b" by (rule less_imp_le[OF x1])
  have y0: "0 < prad b" by (rule ppos_rad[OF assms])
  define S where "S = sqrt (rl (grav_G * pmass b / prad b))"
  have ph: "phys (POrbV b) = S * (1 / 1000)" by (simp add: phys_def S_def of_rat_divide)
  have e: "1000 * phys (POrbV b) = S" unfolding ph by (rule unscale) simp
  have sm: "S ^ 2 * rl (prad b) = rl (grav_G * pmass b)"
    using sqrt_model[OF x0 y0] unfolding S_def by simp
  show ?thesis unfolding e by (rule sm)
qed

text \<open>The escape speed is the circular speed times the square root of two.\<close>
theorem escape_vs_orbital:
  assumes "ppos b"
  shows "(phys (PEscape b)) ^ 2 = 2 * (phys (POrbV b)) ^ 2"
proof -
  have Rp: "0 < rl (prad b)" using ppos_rad[OF assms] by simp
  have R0: "rl (prad b) \<noteq> 0" by (rule pos_ne0[OF Rp])
  have h1: "(1000 * phys (PEscape b)) ^ 2 * rl (prad b) = 2 * rl (grav_G * pmass b)"
    using escape_model[OF assms] by (simp add: mult.assoc of_rat_mult)
  have h2: "(1000 * phys (POrbV b)) ^ 2 * rl (prad b) = rl (grav_G * pmass b)"
    by (rule orbital_velocity_model[OF assms])
  have "(1000 * phys (PEscape b)) ^ 2 = 2 * (1000 * phys (POrbV b)) ^ 2"
    by (rule cancel_two[OF R0 h1 h2])
  then show ?thesis by (simp add: power_mult_distrib)
qed

text \<open>Mean density: rho (4/3 pi R^3) = M, rho in g/cm3 (a factor 1000 from kg/m3).\<close>
theorem density_model:
  assumes "ppos b"
  shows "phys (PDensity b) * (4 / 3 * pi * rl (prad b) ^ 3) * 1000 = rl (pmass b)"
proof -
  have y0: "prad b \<noteq> 0" by (rule pos_ne0[OF ppos_rad[OF assms]])
  define cc where "cc = 3 * pmass b / (4000 * prad b ^ 3)"
  have ratid: "cc * (4000 * prad b ^ 3) = 3 * pmass b" unfolding cc_def using y0 by (simp add: field_simps)
  have h1: "rl cc * (4000 * rl (prad b) ^ 3) = 3 * rl (pmass b)"
  proof -
    have "rl (cc * (4000 * prad b ^ 3)) = rl (3 * pmass b)" by (simp only: ratid)
    then show ?thesis by (simp add: of_rat_mult of_rat_power)
  qed
  have ph: "phys (PDensity b) = rl cc * inverse pi" by (simp add: phys_def cc_def)
  have ne: "pi \<noteq> 0" by simp
  have "phys (PDensity b) * (4 / 3 * pi * rl (prad b) ^ 3) * 1000 =
        (rl cc * (4000 * rl (prad b) ^ 3)) / 3"
    unfolding ph using ne by (simp add: field_simps)
  also have "\<dots> = rl (pmass b)" using h1 by simp
  finally show ?thesis .
qed

subsection \<open>Orbits\<close>

text \<open>Circular orbit: v^2 r = mu (v in km/s, r the body's radius plus the altitude).\<close>
theorem orbit_speed_model:
  assumes "0 < rad1 ob oa"
  shows "(phys (OSpeed ob oa)) ^ 2 * rl (rad1 ob oa) = rl (mu (obd ob))"
proof -
  have ph: "phys (OSpeed ob oa) = sqrt (rl (mu (obd ob) / rad1 ob oa))" by (simp add: phys_def)
  have x0: "0 \<le> mu (obd ob)" by (rule less_imp_le[OF mu_pos])
  show ?thesis using sqrt_model[OF x0 assms] unfolding ph by simp
qed

text \<open>Escape velocity: v^2 r = 2 mu; it is the circular speed times the square root of two.\<close>
theorem orbit_escape_model:
  assumes "0 < rad1 ob oa"
  shows "(phys (OEscape ob oa)) ^ 2 * rl (rad1 ob oa) = rl (2 * mu (obd ob))" and
        "(phys (OEscape ob oa)) ^ 2 = 2 * (phys (OSpeed ob oa)) ^ 2"
proof -
  have x1: "0 < 2 * mu (obd ob)" by simp
  have x0: "0 \<le> 2 * mu (obd ob)" by (rule less_imp_le[OF x1])
  have ph: "phys (OEscape ob oa) = sqrt (rl (2 * mu (obd ob) / rad1 ob oa))" by (simp add: phys_def)
  have h1: "(phys (OEscape ob oa)) ^ 2 * rl (rad1 ob oa) = rl (2 * mu (obd ob))"
    using sqrt_model[OF x0 assms] unfolding ph by simp
  show "(phys (OEscape ob oa)) ^ 2 * rl (rad1 ob oa) = rl (2 * mu (obd ob))" by (rule h1)
  have Rp: "0 < rl (rad1 ob oa)" using assms by simp
  have R0: "rl (rad1 ob oa) \<noteq> 0" by (rule pos_ne0[OF Rp])
  have h1': "(phys (OEscape ob oa)) ^ 2 * rl (rad1 ob oa) = 2 * rl (mu (obd ob))"
    using h1 by (simp add: of_rat_mult)
  have h2: "(phys (OSpeed ob oa)) ^ 2 * rl (rad1 ob oa) = rl (mu (obd ob))"
    by (rule orbit_speed_model[OF assms])
  show "(phys (OEscape ob oa)) ^ 2 = 2 * (phys (OSpeed ob oa)) ^ 2"
    by (rule cancel_two[OF R0 h1' h2])
qed

text \<open>Kepler's third law: (T in seconds)^2 mu = 4 pi^2 r^3.\<close>
theorem orbit_period_model:
  assumes "0 < rad1 ob oa"
  shows "(60 * phys (OPeriod ob oa)) ^ 2 * rl (mu (obd ob)) = 4 * pi ^ 2 * rl (rad1 ob oa ^ 3)"
proof -
  have x0: "0 \<le> rad1 ob oa ^ 3" by (rule zero_le_power[OF less_imp_le[OF assms]])
  have y0: "0 < mu (obd ob)" by simp
  define S where "S = sqrt (rl (rad1 ob oa ^ 3 / mu (obd ob)))"
  have ph: "phys (OPeriod ob oa) = 2 * pi * S * (1 / 60)" by (simp add: phys_def S_def of_rat_divide)
  have e: "60 * phys (OPeriod ob oa) = 2 * pi * S" unfolding ph by (rule unscale) simp
  have sm: "S ^ 2 * rl (mu (obd ob)) = rl (rad1 ob oa ^ 3)"
    using sqrt_model[OF x0 y0] unfolding S_def by simp
  have "(2 * pi * S) ^ 2 * rl (mu (obd ob)) = 4 * pi ^ 2 * (S ^ 2 * rl (mu (obd ob)))"
    by (simp add: power_mult_distrib ac_simps)
  then show ?thesis unfolding e using sm by simp
qed

text \<open>Hohmann transfer time: half the period of the transfer ellipse,
(t in seconds)^2 mu = pi^2 a^3 with a = (r1 + r2) / 2.\<close>
theorem hohmann_time_model:
  assumes "0 < hr1 ob p" "0 < hr2 ob p"
  shows "(3600 * phys (OHohTime ob p)) ^ 2 * rl (mu (obd ob)) =
         pi ^ 2 * rl (((hr1 ob p + hr2 ob p) / 2) ^ 3)"
proof -
  have a0: "0 < (hr1 ob p + hr2 ob p) / 2" 
  proof -
    have s: "0 < hr1 ob p + hr2 ob p" by (rule add_pos_pos[OF assms(1) assms(2)])
    show ?thesis using s by simp
  qed
  have x0: "0 \<le> ((hr1 ob p + hr2 ob p) / 2) ^ 3" by (rule zero_le_power[OF less_imp_le[OF a0]])
  have y0: "0 < mu (obd ob)" by simp
  define S where "S = sqrt (rl (((hr1 ob p + hr2 ob p) / 2) ^ 3 / mu (obd ob)))"
  have ph: "phys (OHohTime ob p) = pi * S * (1 / 3600)" by (simp add: phys_def S_def of_rat_divide)
  have e: "3600 * phys (OHohTime ob p) = pi * S" unfolding ph by (rule unscale) simp
  have sm: "S ^ 2 * rl (mu (obd ob)) = rl (((hr1 ob p + hr2 ob p) / 2) ^ 3)"
    using sqrt_model[OF x0 y0] unfolding S_def by simp
  have "(pi * S) ^ 2 * rl (mu (obd ob)) = pi ^ 2 * (S ^ 2 * rl (mu (obd ob)))"
    by (simp add: power_mult_distrib ac_simps)
  then show ?thesis unfolding e using sm by simp
qed

text \<open>Vis-viva at the start of the transfer: the speed on the transfer ellipse at r1
satisfies v^2 = mu (2/r1 - 1/a) with a = (r1 + r2)/2. The first burn the kernel
evaluates is this speed (sqrt (mu/r1) times sqrt (2 r2/(r1 + r2))) less the
circular speed sqrt (mu/r1).\<close>
theorem hohmann_vis_viva:
  fixes m r1 r2 :: rat
  assumes "0 \<le> m" "0 < r1" "0 < r2"
  shows "(sqrt (rl (m / r1)) * sqrt (rl (2 * r2 / (r1 + r2)))) ^ 2 =
         rl (m * (2 / r1 - 1 / ((r1 + r2) / 2)))"
proof -
  have a1: "0 \<le> m / r1" by (rule divide_nonneg_pos[OF assms(1) assms(2)])
  have a0: "0 \<le> rl (m / r1)" using a1 by simp
  have b2: "0 \<le> 2 * r2" using assms by linarith
  have b3: "0 < r1 + r2" using assms by linarith
  have b1: "0 \<le> 2 * r2 / (r1 + r2)" by (rule divide_nonneg_pos[OF b2 b3])
  have b0: "0 \<le> rl (2 * r2 / (r1 + r2))" using b1 by simp
  have s: "(sqrt (rl (m / r1)) * sqrt (rl (2 * r2 / (r1 + r2)))) ^ 2 =
           rl (m / r1) * rl (2 * r2 / (r1 + r2))"
    using a0 b0 by (simp add: power_mult_distrib)
  have n1: "r1 \<noteq> 0" "r1 + r2 \<noteq> 0" using pos_ne0[OF assms(2)] pos_ne0[OF b3] by simp_all
  have q: "m / r1 * (2 * r2 / (r1 + r2)) = m * (2 / r1 - 1 / ((r1 + r2) / 2))"
    using n1 by (simp add: field_simps)
  have "rl (m / r1) * rl (2 * r2 / (r1 + r2)) = rl (m / r1 * (2 * r2 / (r1 + r2)))"
    by (rule of_rat_mult[symmetric])
  then show ?thesis using s q by simp
qed

text \<open>The total delta-v of a Hohmann transfer is never negative.\<close>
theorem hohmann_dv_nonneg: "0 \<le> phys (OHohDv ob p)"
  by (simp add: phys_def)

text \<open>The synchronous orbit: its radius r = altitude + R satisfies
r^3 4 pi^2 = mu T^2 (Kepler), T the sidereal rotation period.\<close>
theorem sync_model:
  assumes "sidereal b = Some t"
  shows "(phys (OSync (Some b)) + rl (brad b)) ^ 3 * (4 * pi ^ 2) = rl (mu b * t ^ 2)"
proof -
  have tpos: "0 < t" using sidereal_pos[OF assms] .
  define Y where "Y = rl (mu b * t ^ 2) * inverse (4 * pi ^ 2)"
  have c: "0 < mu b * t ^ 2" by (rule mult_pos_pos[OF mu_pos zero_less_power[OF tpos]])
  have c': "0 < (rl (mu b * t ^ 2) :: real)" using c by simp
  have pp: "0 < (4 * pi ^ 2 :: real)" by (rule mult_pos_pos[OF _ zero_less_power[OF pi_gt_zero]]) simp
  have ipp: "0 < inverse (4 * pi ^ 2 :: real)" using pp by simp
  have Ypos: "0 < Y" unfolding Y_def by (rule mult_pos_pos[OF c' ipp])
  have ph0: "phys (OSync (Some b)) = exp (ln Y * (1 / 3)) - rl (brad b)"
    by (simp add: phys_def sidv_def assms obd_def Y_def of_rat_divide)
  have ph: "phys (OSync (Some b)) + rl (brad b) = exp (ln Y * (1 / 3))" using ph0 by simp
  have pn: "(4 * pi ^ 2 :: real) \<noteq> 0" by (rule pos_ne0[OF pp])
  have "Y * (4 * pi ^ 2) = rl (mu b * t ^ 2)" unfolding Y_def using pn by (simp add: field_simps)
  then show ?thesis unfolding ph using cbrt_cube[OF Ypos] by simp
qed

subsection \<open>Spacecraft\<close>

theorem exhaust_model:
  "kernel (SExhaust i) = Exact (STR ''exhaust_velocity'') (qval (SExhaust i)) \<and>
   qval (SExhaust i) = i * std_g0"
proof -
  have nd: "decline_of (SExhaust i) = None" by (simp add: decl_none_iff)
  show ?thesis using kernel_exact_of[OF nd] by simp
qed

text \<open>Thrust to weight: twr (m g0) = F.\<close>
theorem twr_model:
  assumes "0 < M * massf mw"
  shows "kernel (STwr F fu M mw) = Exact (STR ''twr'') (qval (STwr F fu M mw)) \<and>
         qval (STwr F fu M mw) * (M * massf mw * std_g0) = F * forcef fu"
proof -
  have nd: "decline_of (STwr F fu M mw) = None" using assms by (simp add: decl_none_iff)
  have g: "std_g0 \<noteq> 0" by (simp add: std_g0_def)
  have Mp: "0 < M" by (rule zero_less_mult_pos2[OF assms massf_pos])
  have Mn: "M \<noteq> 0" by (rule pos_ne0[OF Mp])
  have m: "massf mw \<noteq> 0" by (rule pos_ne0[OF massf_pos])
  show ?thesis using kernel_exact_of[OF nd] g m Mn by (simp add: field_simps)
qed

text \<open>Mass flow: mdot ve = F; burn time: t mdot = the propellant mass.\<close>
theorem mass_flow_model:
  assumes "0 < ve_of v"
  shows "kernel (SMassFlow F fu v) = Exact (STR ''mass_flow'') (qval (SMassFlow F fu v)) \<and>
         qval (SMassFlow F fu v) * ve_of v = F * forcef fu"
proof -
  have nd: "decline_of (SMassFlow F fu v) = None" using assms by (simp add: decl_none_iff)
  have m: "ve_of v \<noteq> 0" by (rule pos_ne0[OF assms])
  show ?thesis using kernel_exact_of[OF nd] m by simp
qed

theorem burn_time_model:
  assumes "0 < ve_of v" "0 < F * forcef fu"
  shows "kernel (SBurn F fu v P pu) = Exact (STR ''burn_time'') (qval (SBurn F fu v P pu)) \<and>
         qval (SBurn F fu v P pu) * qval (SMassFlow F fu v) = P * massf pu"
proof -
  have nd: "decline_of (SBurn F fu v P pu) = None" using assms by (simp add: decl_none_iff)
  have m: "ve_of v \<noteq> 0" by (rule pos_ne0[OF assms(1)])
  have Fp: "0 < F" by (rule zero_less_mult_pos2[OF assms(2) forcef_pos])
  have Fn: "F \<noteq> 0" by (rule pos_ne0[OF Fp])
  have fn: "forcef fu \<noteq> 0" by (rule pos_ne0[OF forcef_pos])
  have d: "F * forcef fu / ve_of v \<noteq> 0" using m Fn fn by simp
  show ?thesis using kernel_exact_of[OF nd] d by simp
qed

text \<open>Tsiolkovsky: e^(dv/ve) mf = m0.\<close>
theorem tsiolkovsky_model:
  assumes "0 < ve_of v" "0 < M0 * massf u0" "0 < MF * massf uf"
  shows "exp (phys (SDeltaV v M0 u0 MF uf) / rl (ve_of v)) * rl (MF * massf uf) = rl (M0 * massf u0)"
proof -
  have pos0: "0 < M0 * massf u0 / (MF * massf uf)" by (rule divide_pos_pos[OF assms(2) assms(3)])
  have pos: "0 < rl (M0 * massf u0 / (MF * massf uf))" using pos0 by simp
  have ve0: "rl (ve_of v) \<noteq> 0"
  proof -
    have "0 < rl (ve_of v)" using assms(1) by simp
    then show ?thesis by (rule pos_ne0)
  qed
  have ph: "phys (SDeltaV v M0 u0 MF uf) / rl (ve_of v) = ln (rl (M0 * massf u0 / (MF * massf uf)))"
    using ve0 by (simp add: phys_def)
  have mf0: "MF * massf uf \<noteq> 0" by (rule pos_ne0[OF assms(3)])
  have "M0 * massf u0 / (MF * massf uf) * (MF * massf uf) = M0 * massf u0" using mf0 by simp
  then have "rl (M0 * massf u0 / (MF * massf uf)) * rl (MF * massf uf) = rl (M0 * massf u0)"
    by (metis of_rat_mult)
  then show ?thesis unfolding ph using pos by simp
qed

text \<open>The propellant for a delta-v from the initial mass inverts Tsiolkovsky: the rocket
equation on the masses before and after the burn gives back the delta-v.\<close>
theorem propellant_initial_model:
  assumes "0 < ve_of v" "0 < M0 * massf u0"
  shows "rl (ve_of v) * ln (rl (M0 * massf u0) / (rl (M0 * massf u0) - phys (SProp0 v dv du M0 u0))) =
         rl (dv * speedf du)"
proof -
  define m where "m = (rl (M0 * massf u0) :: real)"
  define x where "x = (rl (dv * speedf du / ve_of v) :: real)"
  have mpos: "0 < m" unfolding m_def using assms(2) by simp
  have ve0: "rl (ve_of v) \<noteq> 0"
  proof -
    have "0 < rl (ve_of v)" using assms(1) by simp
    then show ?thesis by (rule pos_ne0)
  qed
  have ph: "phys (SProp0 v dv du M0 u0) = m * (1 - exp (- x))"
    by (simp add: phys_def m_def x_def)
  have d: "m - phys (SProp0 v dv du M0 u0) = m * inverse (exp x)"
    by (simp add: ph exp_minus algebra_simps)
  have q: "m / (m * inverse (exp x)) = exp x" using mpos by (simp add: field_simps)
  have q2: "m / (m - phys (SProp0 v dv du M0 u0)) = exp x" by (subst d) (rule q)
  have lx: "ln (m / (m - phys (SProp0 v dv du M0 u0))) = x" by (simp add: q2)
  have vx: "rl (ve_of v) * x = rl (dv * speedf du)"
    using ve0 by (simp add: x_def of_rat_divide)
  have "rl (ve_of v) * ln (m / (m - phys (SProp0 v dv du M0 u0))) = rl (dv * speedf du)"
    using lx vx by simp
  then show ?thesis unfolding m_def .
qed

theorem propellant_final_model:
  assumes "0 < ve_of v" "0 < MF * massf uf"
  shows "rl (ve_of v) * ln ((rl (MF * massf uf) + phys (SPropF v dv du MF uf)) / rl (MF * massf uf)) =
         rl (dv * speedf du)"
proof -
  define m where "m = (rl (MF * massf uf) :: real)"
  define x where "x = (rl (dv * speedf du / ve_of v) :: real)"
  have mpos: "0 < m" unfolding m_def using assms(2) by simp
  have ve0: "rl (ve_of v) \<noteq> 0"
  proof -
    have "0 < rl (ve_of v)" using assms(1) by simp
    then show ?thesis by (rule pos_ne0)
  qed
  have ph: "phys (SPropF v dv du MF uf) = m * (exp x - 1)"
    by (simp add: phys_def m_def x_def)
  have d: "m + phys (SPropF v dv du MF uf) = m * exp x" by (simp add: ph algebra_simps)
  have q: "m * exp x / m = exp x" using mpos by simp
  have q2: "(m + phys (SPropF v dv du MF uf)) / m = exp x" by (subst d) (rule q)
  have lx: "ln ((m + phys (SPropF v dv du MF uf)) / m) = x" by (simp add: q2)
  have vx: "rl (ve_of v) * x = rl (dv * speedf du)"
    using ve0 by (simp add: x_def of_rat_divide)
  have "rl (ve_of v) * ln ((m + phys (SPropF v dv du MF uf)) / m) = rl (dv * speedf du)"
    using lx vx by simp
  then show ?thesis unfolding m_def .
qed

subsection \<open>Space communications\<close>

text \<open>Light time: t c = distance; the round trip is twice the one-way time.\<close>
theorem light_time_model:
  "kernel (CLight (Some d) False) = Exact (STR ''light_time'') (qval (CLight (Some d) False)) \<and>
   qval (CLight (Some d) False) * light_c = dkm d \<and>
   qval (CLight (Some d) True) = 2 * qval (CLight (Some d) False)"
proof -
  have nd: "decline_of (CLight (Some d) False) = None" by (simp add: decl_none_iff)
  have c: "light_c \<noteq> 0" by (simp add: light_c_def)
  show ?thesis using kernel_exact_of[OF nd] c by (simp add: dd_def)
qed

text \<open>File transfer: t times the rate = the bits sent; a byte is eight bits.\<close>
theorem transfer_model:
  assumes "0 < r * rate_f u"
  shows "kernel (CXfer n p bytes r u) = Exact (STR ''transfer_time'') (qval (CXfer n p bytes r u)) \<and>
         qval (CXfer n p bytes r u) * (r * rate_f u) = n * dpre_f p * (if bytes then 8 else 1) \<and>
         qval (CXfer n p True r u) = 8 * qval (CXfer n p False r u)"
proof -
  have nd: "decline_of (CXfer n p bytes r u) = None" using assms by (simp add: decl_none_iff)
  have m: "r * rate_f u \<noteq> 0" by (rule pos_ne0[OF assms])
  show ?thesis using kernel_exact_of[OF nd] m by (simp add: field_simps)
qed

text \<open>Bits in flight: the rate times the one-way light time.\<close>
theorem bits_in_flight_model:
  "kernel (CBits (Some d) (Some x)) = Exact (STR ''bits_in_flight'') (qval (CBits (Some d) (Some x))) \<and>
   qval (CBits (Some d) (Some x)) = rr (Some x) * qval (CLight (Some d) False)"
proof -
  have nd: "decline_of (CBits (Some d) (Some x)) = None" by (simp add: decl_none_iff)
  show ?thesis using kernel_exact_of[OF nd] by (simp add: dd_def)
qed

text \<open>Free-space path loss: the loss L in dB satisfies 10^((L - 32.4478)/20) = d f,
d in km and f in MHz.\<close>
lemma pw10: "(10::real) powr y = exp (y * ln 10)"
  by (simp add: powr_def mult.commute)

theorem fspl_model:
  assumes "0 < dd d" "0 < ff f"
  shows "(10::real) powr ((phys (CFspl d f) - rl fspl_const) / 20) = rl (dd d) * rl (ff f)"
proof -
  have l10: "0 < ln (10::real)" by (simp add: ln_gt_zero)
  have D: "0 < (rl (dd d) :: real)" using assms(1) by simp
  have F: "0 < (rl (ff f) :: real)" using assms(2) by simp
  have l10n: "ln (10::real) \<noteq> 0" by (rule pos_ne0[OF l10])
  have DF: "0 < rl (dd d) * rl (ff f)" by (rule mult_pos_pos[OF D F])
  have p: "phys (CFspl d f) = 20 * (ln (rl (dd d) * rl (ff f)) / ln 10) + rl fspl_const"
    by (simp add: phys_def divide_inverse of_rat_mult)
  have ph: "(phys (CFspl d f) - rl fspl_const) / 20 * ln 10 = ln (rl (dd d) * rl (ff f))"
  proof -
    have e: "phys (CFspl d f) - rl fspl_const = 20 * (ln (rl (dd d) * rl (ff f)) / ln 10)"
      using p by simp
    show ?thesis by (subst e) (use l10n in \<open>simp add: field_simps\<close>)
  qed
  have "(10::real) powr ((phys (CFspl d f) - rl fspl_const) / 20) =
        exp ((phys (CFspl d f) - rl fspl_const) / 20 * ln 10)" by (rule pw10)
  also have "\<dots> = exp (ln (rl (dd d) * rl (ff f)))" by (rule arg_cong[OF ph])
  also have "\<dots> = rl (dd d) * rl (ff f)" using DF by simp
  finally show ?thesis .
qed

subsection \<open>Astronomy\<close>

theorem property_model:
  assumes "\<not> is_unknown (sheet b p)"
  shows "kernel (AProp b p) = Fact (prop_kind p) (sheet b p)"
proof -
  have nd: "decline_of (AProp b p) = None" using assms by (simp add: decl_none_iff)
  show ?thesis using nd by (simp add: kernel_def answer_of_def)
qed

text \<open>Your weight elsewhere scales with surface gravity.\<close>
theorem weight_elsewhere_model:
  "kernel (AWeight w u b) = Exact (STR ''weight'') (qval (AWeight w u b)) \<and>
   qval (AWeight w u b) * grav_of A_earth = w * grav_of b"
proof -
  have nd: "decline_of (AWeight w u b) = None" by (simp add: decl_none_iff)
  have g: "grav_of A_earth \<noteq> 0" by (rule pos_ne0[OF grav_earth_pos])
  show ?thesis using kernel_exact_of[OF nd] g by simp
qed

text \<open>Sunlight: minutes * 60 * c = the mean distance from the Sun in km.\<close>
theorem sunlight_model:
  "kernel (ALight b) = Exact (STR ''light_time'') (qval (ALight b)) \<and>
   qval (ALight b) * 60 * light_c = dist_of b * 1000000"
proof -
  have nd: "decline_of (ALight b) = None" by (simp add: decl_none_iff)
  have c: "light_c \<noteq> 0" by (simp add: light_c_def)
  show ?thesis using kernel_exact_of[OF nd] c by simp
qed

text \<open>A ratio times the reference value is the subject's value.\<close>
theorem ratio_model:
  assumes "cell_num (sheet b2 p) \<noteq> 0"
  shows "kernel (ARatio rs b1 b2 p) = Exact (STR ''ratio'') (qval (ARatio rs b1 b2 p)) \<and>
         qval (ARatio rs b1 b2 p) * cell_num (sheet b2 p) = cell_num (sheet b1 p)"
proof -
  have nd: "decline_of (ARatio rs b1 b2 p) = None" using assms by (simp add: decl_none_iff)
  show ?thesis using kernel_exact_of[OF nd] assms by simp
qed

text \<open>A year in Earth years: years * 365.25 = the orbital period in days.\<close>
theorem years_model:
  "kernel (AYears b) = Exact (STR ''year_years'') (qval (AYears b)) \<and>
   qval (AYears b) * (36525 / 100) = period_of b"
proof -
  have nd: "decline_of (AYears b) = None" by (simp add: decl_none_iff)
  show ?thesis using kernel_exact_of[OF nd] by simp
qed

section \<open>Response text (ASCII)\<close>

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

text \<open>The sheet value as printed, star included.\<close>
definition cell_disp :: "cell \<Rightarrow> String.literal" where
  "cell_disp c = (case c of Cnum s _ star \<Rightarrow> (if star then s + STR ''*'' else s) | Cword s \<Rightarrow> s | Cunk s \<Rightarrow> s)"

definition cell_plain :: "cell \<Rightarrow> String.literal" where
  "cell_plain c = (case c of Cnum s _ _ \<Rightarrow> s | Cword s \<Rightarrow> s | Cunk s \<Rightarrow> s)"

definition fact_json :: "cell \<Rightarrow> String.literal" where
  "fact_json c = dq + cell_plain c + dq"

definition wu_name :: "wunit \<Rightarrow> String.literal" where
  "wu_name u = (case u of Wu_kg \<Rightarrow> STR ''kg'' | Wu_lb \<Rightarrow> STR ''lb'')"

fun gdesc :: "pbody \<Rightarrow> String.literal" where
  "gdesc (Pb_si M R u) = STR ''G M / R^2 = 6.674e-11 x '' + fmt St_pl M + STR '' / ('' + fmt St_pl (R * lenf u)
     + STR '' m)^2''"
| "gdesc (Pb_earth M R) = STR ''9.81 x '' + fmt St_pl M + STR '' / '' + fmt St_pl R + STR ''^2''"

definition earth_note :: "pbody \<Rightarrow> String.literal" where
  "earth_note b = (case b of Pb_earth _ _ \<Rightarrow> STR ''; Earth M = 5.972e24 kg, R = 6371 km'' | Pb_si _ _ _ \<Rightarrow> STR '''')"

definition dtext :: "dist option \<Rightarrow> String.literal" where
  "dtext d = (case d of Some x \<Rightarrow> fmt St_orb (dkm x) + STR '' km'' | None \<Rightarrow> STR '''')"

definition ve_text :: "vesrc \<Rightarrow> String.literal" where
  "ve_text v = fmt St_sc (ve_of v)"

definition bname :: "obody option \<Rightarrow> String.literal" where
  "bname ob = obody_name (obd ob)"

definition mu_text :: "obody option \<Rightarrow> String.literal" where
  "mu_text ob = fmt St_orb (mu (obd ob))"

fun exact_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text (PGravity b) q V = STR ''The surface gravity is '' + V + STR '' m/s2 ('' + gdesc b + STR '').''"
| "exact_text (PWeightE M R k) q V = STR ''The weight is '' + V + STR '' N ('' + fmt St_pl k + STR '' kg x ''
     + fmt St_pl (grav_E * M / R ^ 2) + STR '' m/s2; g = 9.81 x '' + fmt St_pl M + STR '' / '' + fmt St_pl R
     + STR ''^2).''"
| "exact_text (SExhaust i) q V = STR ''The effective exhaust velocity is '' + V + STR '' m/s (Isp x g0 = ''
     + fmt St_sc i + STR '' s x 9.80665).''"
| "exact_text (STwr F fu M mw) q V = STR ''The thrust-to-weight ratio is '' + V + STR '' (''
     + fmt St_sc (F * forcef fu) + STR '' N / ('' + fmt St_sc (M * massf mw) + STR '' kg x 9.80665)).''"
| "exact_text (SMassFlow F fu v) q V = STR ''The mass flow rate is '' + V + STR '' kg/s (F / (Isp g0) = ''
     + fmt St_sc (F * forcef fu) + STR '' N / '' + ve_text v + STR '' m/s).''"
| "exact_text (SBurn F fu v P pu) q V = STR ''The burn time is '' + V + STR '' s ('' + fmt St_sc (P * massf pu)
     + STR '' kg / '' + fmt St_sc (F * forcef fu / ve_of v) + STR '' kg/s; mdot = F / (Isp g0)).''"
| "exact_text (CLight d rt) q V = (if rt then STR ''The round trip is '' + V + dur_unit q
       + STR '' (2 x '' + dtext d + STR '' / 299,792.458 km/s).''
     else STR ''The one-way delay is '' + V + dur_unit q + STR '' ('' + dtext d + STR '' / 299,792.458 km/s).'')"
| "exact_text (CXfer n p bytes r u) q V = STR ''The transfer time is '' + V + dur_unit q + STR '' (''
     + fmt St_orb (n * dpre_f p * (if bytes then 8 else 1)) + STR '' bits / '' + fmt St_orb (r * rate_f u)
     + STR '' bit/s; decimal prefixes, 8 bits per byte, no protocol overhead).''"
| "exact_text (CBits d r) q V = STR ''The bits in flight number '' + V + STR '' (rate '' + fmt St_orb (rr r)
     + STR '' bit/s x one-way delay '' + fmt St_orb (dd d / light_c) + STR '' s).''"
| "exact_text (ALight b) q V = STR ''Sunlight takes about '' + V + STR '' minutes to reach '' + abody_name b
     + STR '' (mean distance '' + cell_disp (sheet b P_distance) + STR '' million km, NASA).''"
| "exact_text (AWeight w u b) q V = STR ''Something that weighs '' + fmt (St_sig 6) w + STR '' '' + wu_name u
     + STR '' on Earth would weigh about '' + V + STR '' '' + wu_name u + STR '' on '' + abody_name b
     + STR '' (surface gravity '' + cell_disp (sheet b P_gravity) + STR '' vs ''
     + cell_disp (sheet A_earth P_gravity) + STR '' m/s2, NASA).''"
| "exact_text (ARatio rs b1 b2 p) q V = abody_name b1 + apos + STR ''s '' + prop_name p + STR '' is '' + V
     + STR '' times '' + abody_name b2 + apos + STR ''s (''
     + (case rs of Rs_v1 \<Rightarrow> cell_disp (sheet b1 p) | Rs_v2 \<Rightarrow> cell_plain (sheet b1 p))
     + STR '' vs ''
     + (case rs of Rs_v1 \<Rightarrow> cell_disp (sheet b2 p) | Rs_v2 \<Rightarrow> cell_plain (sheet b2 p)) + STR '', NASA).''"
| "exact_text (AYears b) q V = STR ''A year on '' + abody_name b + STR '' lasts about '' + V
     + STR '' Earth years ('' + cell_disp (sheet b P_period) + STR '' Earth days, NASA).''"
| "exact_text AMoonKm q V = STR ''The Moon is on average about '' + V
     + STR '' km from Earth (NASA lists the Moon'' + apos + STR ''s orbit relative to Earth).''"
| "exact_text AMoonKkm q V = STR ''The Moon is on average '' + V
     + STR '' thousand km from Earth (NASA lists the Moon'' + apos + STR ''s orbit relative to Earth).''"
| "exact_text r q V = V"

fun approx_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "approx_text (PEscape b) V = STR ''The escape velocity is '' + V + STR '' km/s (sqrt(2 G M / R)''
     + earth_note b + STR '').''"
| "approx_text (POrbV b) V = STR ''The circular orbital velocity at the surface is '' + V
     + STR '' km/s (sqrt(G M / R)).''"
| "approx_text (PDensity b) V = STR ''The mean density is '' + V + STR '' g/cm3 (M / (4/3 pi R^3)).''"
| "approx_text (OSync ob) V = STR ''The synchronous orbit altitude is '' + V + STR '' km above '' + bname ob
     + STR '' (altitude = (mu T^2 / 4 pi^2)^(1/3) - R, R = '' + fmt St_orb (brad (obd ob))
     + STR '' km, T = '' + fmt St_orb (sidv (obd ob)) + STR '' s sidereal, mu = '' + mu_text ob
     + STR '' km3/s2).''"
| "approx_text (OSpeed ob oa) V = STR ''The orbital speed is '' + V + STR '' km/s (sqrt(mu/r), r = ''
     + fmt St_orb (rad1 ob oa) + STR '' km, mu = '' + mu_text ob + STR ''; circular orbit).''"
| "approx_text (OPeriod ob oa) V = STR ''The orbital period is '' + V + STR '' minutes (2 pi sqrt(r^3/mu), r = ''
     + fmt St_orb (rad1 ob oa) + STR '' km, mu = '' + mu_text ob + STR ''; circular orbit).''"
| "approx_text (OEscape ob oa) V = STR ''The escape velocity is '' + V + STR '' km/s at ''
     + (if opd oa = 0 then STR ''the surface'' else fmt St_orb (opd oa) + STR '' km altitude'')
     + STR '' of '' + bname ob + STR '' (sqrt(2 mu/r), r = '' + fmt St_orb (rad1 ob oa) + STR '' km, mu = ''
     + mu_text ob + STR '' km3/s2).''"
| "approx_text (OHohDv ob p) V = STR ''The total delta-v is '' + V
     + STR '' km/s (Hohmann transfer between circular orbits of radius '' + fmt St_orb (hr1 ob p)
     + STR '' and '' + fmt St_orb (hr2 ob p) + STR '' km around '' + bname ob + STR '', mu = '' + mu_text ob + STR '').''"
| "approx_text (OHohTime ob p) V = STR ''The transfer time is '' + V
     + STR '' hours (half the transfer ellipse: pi sqrt(a^3/mu), a = '' + fmt St_orb ((hr1 ob p + hr2 ob p) / 2)
     + STR '' km).''"
| "approx_text (SDeltaV v M0 u0 MF uf) V = STR ''The delta-v is '' + V + STR '' m/s (ve ln(m0/mf) = ''
     + ve_text v + STR '' x ln('' + fmt St_sc (M0 * massf u0) + STR ''/'' + fmt St_sc (MF * massf uf)
     + STR ''); Tsiolkovsky).''"
| "approx_text (SProp0 v dv du M0 u0) V = STR ''The propellant needed is '' + V
     + STR '' kg (m0 (1 - e^(-dv/ve)) = '' + fmt St_sc (M0 * massf u0) + STR '' x (1 - e^(-''
     + fmt St_sc (dv * speedf du) + STR ''/'' + ve_text v + STR '')))).''"
| "approx_text (SPropF v dv du MF uf) V = STR ''The propellant needed is '' + V
     + STR '' kg (mf (e^(dv/ve) - 1) = '' + fmt St_sc (MF * massf uf) + STR '' x (e^(''
     + fmt St_sc (dv * speedf du) + STR ''/'' + ve_text v + STR '') - 1)).''"
| "approx_text (CFspl d f) V = STR ''The free-space path loss is '' + V + STR '' dB (20log10('' + dtext d
     + STR '') + 20log10('' + fmt St_orb (ff f) + STR '' MHz) + 32.45).''"
| "approx_text r V = V"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text w = STR ''I need '' + (case w of
       N_body \<Rightarrow> STR ''which body is being orbited''
     | N_alt \<Rightarrow> STR ''the orbit'' + apos + STR ''s altitude''
     | N_alts \<Rightarrow> STR ''the starting and final orbit altitudes''
     | N_dist_freq \<Rightarrow> STR ''the distance and the carrier frequency''
     | N_dist_rate \<Rightarrow> STR ''the distance and the link rate''
     | N_dist \<Rightarrow> STR ''the distance (it changes as the planets move, so I won'' + apos + STR ''t assume one)'')
     + STR '' to work that out; I won'' + apos + STR ''t assume it.''"

fun impossible_text :: "request \<Rightarrow> reason \<Rightarrow> String.literal" where
  "impossible_text (SDeltaV v M0 u0 MF uf) R_final_exceeds_initial = STR ''The final mass (''
     + fmt St_sc (MF * massf uf) + STR '' kg) cannot exceed the initial mass ('' + fmt St_sc (M0 * massf u0)
     + STR '' kg).''"
| "impossible_text r R_final_exceeds_initial = STR ''The final mass cannot exceed the initial mass.''"
| "impossible_text r R_nonpositive = STR ''A mass, radius, rate, frequency or distance used as a divisor or in a logarithm must be positive.''"

fun decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r (Underspecified n) = need_text n"
| "decline_text (OSync ob) NoSync = bname ob
     + STR '' has no synchronous orbit I can compute here (no fixed sidereal rotation in my table).''"
| "decline_text r NoSync = STR ''No synchronous orbit I can compute here.''"
| "decline_text r (Impossible why) = impossible_text r why"
| "decline_text (AFake n) Unknown = n + STR '' isn'' + apos + STR ''t in NASA'' + apos
     + STR ''s Planetary Fact Sheet, so I have no figures for it.''"
| "decline_text r Unknown = STR ''That body is not in NASA'' + apos + STR ''s Planetary Fact Sheet.''"
| "decline_text (AProp b p) NoValue = STR ''NASA lists '' + abody_name b + apos + STR ''s '' + prop_name p
     + STR '' as unknown, so I won'' + apos + STR ''t give a number.''"
| "decline_text r NoValue = STR ''NASA lists that value as unknown, so I won'' + apos + STR ''t give a number.''"
| "decline_text r Imprecise = STR ''The interval arithmetic could not pin the digits; I won'' + apos + STR ''t guess.''"

definition what_text :: "aprop \<Rightarrow> bool \<Rightarrow> String.literal" where
  "what_text p yes = (case p of
       P_rings \<Rightarrow> (if yes then STR ''a ring system'' else STR ''ring system'')
     | P_magnetic \<Rightarrow> (if yes then STR ''a global magnetic field'' else STR ''global magnetic field'')
     | _ \<Rightarrow> prop_name p)"

text \<open>The sentence for a sheet value (the organ's property branch).\<close>
fun fact_text :: "request \<Rightarrow> cell \<Rightarrow> String.literal" where
  "fact_text (AProp b p) (Cnum s _ star) = abody_name b + apos + STR ''s '' + prop_name p + STR '' is '' + s
     + prop_unit p + (if star then STR '' (relative to Earth)'' else STR '''')
     + STR '', per NASA'' + apos + STR ''s Planetary Fact Sheet.''"
| "fact_text (AProp b p) (Cword s) = s + STR '', '' + abody_name b
     + (if s = STR ''Yes'' then STR '' has '' else STR '' has no '') + what_text p (s = STR ''Yes'')
     + STR '', per NASA'' + apos + STR ''s Planetary Fact Sheet.''"
| "fact_text r c = STR ''''"

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | NoSync \<Rightarrow> STR ''no_sync''
     | Impossible _ \<Rightarrow> STR ''impossible'' | Unknown \<Rightarrow> STR ''unknown'' | NoValue \<Rightarrow> STR ''no_value''
     | Imprecise \<Rightarrow> STR ''imprecise'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and the
stated value (a JSON number, or a JSON string for a sheet cell). A withheld reply
carries the decline text, as the organs do.\<close>
definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow>
       (case stated_dec (style_of r) (qshown r q) of
          None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text r Imprecise) None
        | Some d \<Rightarrow>
          (case stated_dec (St_sig 6) q of
             None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text r Imprecise) None
           | Some dv \<Rightarrow> Reply True k (exact_text r q (render_st (style_of r) d)) (Some (render_plain dv))))
   | Approx k d \<Rightarrow> Reply True k (approx_text r (render_st (style_of r) d)) (Some (render_plain d))
   | Fact k c \<Rightarrow> Reply True k (fact_text r c) (Some (fact_json c))
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text r w) None)"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d dv. kernel r = Exact k q \<and> stated_dec (style_of r) (qshown r q) = Some d \<and>
        stated_dec (St_sig 6) q = Some dv) \<or>
     (\<exists>k d. kernel r = Approx k d) \<or> (\<exists>k c. kernel r = Fact k c)"
  by (auto simp: reply_of_def split: outcome.splits option.splits)

theorem reply_states_approx:
  "kernel r = Approx k d \<Longrightarrow> stated (reply_of r) = Some (render_plain d)"
  by (simp add: reply_of_def)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated_dec (St_sig 6) q = Some dv \<Longrightarrow>
   stated_dec (style_of r) (qshown r q) = Some d \<Longrightarrow> stated (reply_of r) = Some (render_plain dv)"
  by (simp add: reply_of_def)

theorem reply_states_fact:
  "kernel r = Fact k c \<Longrightarrow> stated (reply_of r) = Some (fact_json c)"
  by (simp add: reply_of_def)

text \<open>A withheld reply names the kernel's decline.\<close>
theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

end
