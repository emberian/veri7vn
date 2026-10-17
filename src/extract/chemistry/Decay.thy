theory Decay
  imports "Veri7vn_Chemistry_Base.Chem_Util"
begin

text \<open>
  Radioactive decay (Oracle7 specialist decay): how much of a sample remains
  after a time, how long until a fraction remains, how many half-lives have
  passed, for a half-life the question states or a named isotope (NNDC
  half-lives). The decay law is N = N0 * (1/2)^(t/T). The factor (1/2)^n is
  an exact rational when n is a whole number, and otherwise a real number
  exp(-(ln 2 * n)) stated through a verified interval enclosure
  (HOL-Decision_Procs.Approximation), as lane D and lane G state square
  roots.
\<close>

section \<open>Units, isotopes and half-lives\<close>

datatype tu = TU_year | TU_day | TU_hour | TU_minute | TU_second

text \<open>Seconds per unit; a year is 365.25 days, as in the organ.\<close>
fun tu_sec :: "tu \<Rightarrow> rat" where
  "tu_sec TU_year = 31557600"
| "tu_sec TU_day = 86400"
| "tu_sec TU_hour = 3600"
| "tu_sec TU_minute = 60"
| "tu_sec TU_second = 1"

fun tu_label :: "tu \<Rightarrow> String.literal" where
  "tu_label TU_year = STR ''years''"
| "tu_label TU_day = STR ''days''"
| "tu_label TU_hour = STR ''hours''"
| "tu_label TU_minute = STR ''minutes''"
| "tu_label TU_second = STR ''seconds''"

definition tu_order :: "tu list" where
  "tu_order = [TU_year, TU_day, TU_hour, TU_minute, TU_second]"

lemma tu_sec_pos [simp]: "0 < tu_sec u"
  by (cases u) simp_all

datatype iso = I_c14 | I_u238 | I_u235 | I_i131 | I_co60 | I_cs137 | I_sr90 | I_ra226
  | I_pu239 | I_h3 | I_rn222 | I_k40 | I_p32 | I_tc99m | I_f18 | I_am241

text \<open>Half-lives in seconds (organ_decay_v1.ISOTOPES, in the organ's order).\<close>
fun iso_T :: "iso \<Rightarrow> rat" where
  "iso_T I_c14 = 5730 * 31557600"
| "iso_T I_u238 = 4468000000 * 31557600"
| "iso_T I_u235 = 704000000 * 31557600"
| "iso_T I_i131 = 80252 / 10000 * 86400"
| "iso_T I_co60 = 52714 / 10000 * 31557600"
| "iso_T I_cs137 = 3008 / 100 * 31557600"
| "iso_T I_sr90 = 2879 / 100 * 31557600"
| "iso_T I_ra226 = 1600 * 31557600"
| "iso_T I_pu239 = 24110 * 31557600"
| "iso_T I_h3 = 1232 / 100 * 31557600"
| "iso_T I_rn222 = 38235 / 10000 * 86400"
| "iso_T I_k40 = 1248000000 * 31557600"
| "iso_T I_p32 = 14268 / 1000 * 86400"
| "iso_T I_tc99m = 60067 / 10000 * 3600"
| "iso_T I_f18 = 10977 / 100 * 60"
| "iso_T I_am241 = 4326 / 10 * 31557600"

fun iso_name :: "iso \<Rightarrow> String.literal" where
  "iso_name I_c14 = STR ''carbon-14''" | "iso_name I_u238 = STR ''uranium-238''"
| "iso_name I_u235 = STR ''uranium-235''" | "iso_name I_i131 = STR ''iodine-131''"
| "iso_name I_co60 = STR ''cobalt-60''" | "iso_name I_cs137 = STR ''caesium-137''"
| "iso_name I_sr90 = STR ''strontium-90''" | "iso_name I_ra226 = STR ''radium-226''"
| "iso_name I_pu239 = STR ''plutonium-239''" | "iso_name I_h3 = STR ''tritium''"
| "iso_name I_rn222 = STR ''radon-222''" | "iso_name I_k40 = STR ''potassium-40''"
| "iso_name I_p32 = STR ''phosphorus-32''" | "iso_name I_tc99m = STR ''technetium-99m''"
| "iso_name I_f18 = STR ''fluorine-18''" | "iso_name I_am241 = STR ''americium-241''"

definition iso_order :: "iso list" where
  "iso_order = [I_c14, I_u238, I_u235, I_i131, I_co60, I_cs137, I_sr90, I_ra226, I_pu239,
    I_h3, I_rn222, I_k40, I_p32, I_tc99m, I_f18, I_am241]"

lemma iso_T_pos [simp]: "0 < iso_T i"
  by (cases i) simp_all

datatype hl = HL_stated rat tu | HL_iso iso

fun hl_T :: "hl \<Rightarrow> rat" where
  "hl_T (HL_stated v u) = v * tu_sec u"
| "hl_T (HL_iso i) = iso_T i"

section \<open>The decay factor\<close>

definition decay_real :: "real \<Rightarrow> real" where
  "decay_real x = exp (- (ln 2 * x))"

definition time_real :: "real \<Rightarrow> real" where
  "time_real y = - ln y / ln 2"

lemma exp_ln2 [simp]: "exp (ln (2::real)) = 2"
  by (rule exp_ln) simp

lemma ln2_pos [simp]: "0 < ln (2::real)"
  by (simp add: ln_gt_zero)

theorem decay_real_zero: "decay_real 0 = 1"
  by (simp add: decay_real_def)

text \<open>Each half-life halves the sample.\<close>
theorem decay_halves: "decay_real (x + 1) = decay_real x / 2"
proof -
  have h: "exp (- ln (2::real)) = 1 / 2" by (simp add: exp_minus inverse_eq_divide)
  have "decay_real (x + 1) = exp (- (ln 2 * x) + - ln (2::real))" by (simp add: decay_real_def algebra_simps)
  also have "\<dots> = exp (- (ln 2 * x)) * exp (- ln (2::real))" by (rule exp_add)
  finally show ?thesis by (simp add: decay_real_def h)
qed

theorem decay_real_nat: "decay_real (real k) = (1 / 2) ^ k"
proof -
  have h: "exp (- ln (2::real)) = 1 / 2" by (simp add: exp_minus inverse_eq_divide)
  have e: "- (ln 2 * real k) = real k * (- ln (2::real))" by (simp add: algebra_simps)
  have "decay_real (real k) = exp (real k * (- ln (2::real)))" unfolding decay_real_def e by simp
  also have "\<dots> = exp (- ln (2::real)) ^ k" by (rule exp_of_nat_mult)
  finally show ?thesis by (simp add: h)
qed

text \<open>The time to a fraction inverts the decay law.\<close>
theorem time_real_inverse: "0 < y \<Longrightarrow> decay_real (time_real y) = y"
  by (simp add: decay_real_def time_real_def)

theorem time_real_half: "time_real (1 / 2) = 1"
  by (simp add: time_real_def ln_div)

section \<open>Numeric values\<close>

definition nscale :: "rat \<Rightarrow> nval \<Rightarrow> nval" where
  "nscale r v = (case v of NR q \<Rightarrow> NR (r * q) | NA e \<Rightarrow> NA (floatarith.Mult (Q r) e))"

lemma nreal_nscale: "nreal (nscale r v) = rl r * nreal v"
  by (cases v) (simp_all add: nscale_def of_rat_mult)

definition factor_nv :: "rat \<Rightarrow> nval" where
  "factor_nv n = (let k = nat \<lfloor>n\<rfloor> in
     if rat_of_nat k = n \<and> k \<le> 2000 then NR ((1 / 2) ^ k)
     else NA (floatarith.Exp (floatarith.Minus (floatarith.Mult (floatarith.Ln (I 2)) (Q n)))))"

theorem factor_nv_sound: "nreal (factor_nv n) = decay_real (rl n)"
proof (cases "rat_of_nat (nat \<lfloor>n\<rfloor>) = n \<and> nat \<lfloor>n\<rfloor> \<le> 2000")
  case True
  then have n: "rl n = real (nat \<lfloor>n\<rfloor>)" by (metis of_rat_of_nat_eq)
  have "nreal (factor_nv n) = (1 / 2) ^ nat \<lfloor>n\<rfloor>" using True by (simp add: factor_nv_def Let_def of_rat_power of_rat_divide)
  then show ?thesis using n decay_real_nat by simp
next
  case False
  show ?thesis unfolding factor_nv_def Let_def if_not_P[OF False] by (simp add: decay_real_def)
qed

fun pow2_log :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat option" where
  "pow2_log 0 d k = (if d = 1 then Some k else None)"
| "pow2_log (Suc n) d k = (if d = 1 then Some k else if d mod 2 = 0 then pow2_log n (d div 2) (Suc k) else None)"

definition log2_exact :: "rat \<Rightarrow> nat option" where
  "log2_exact f = (case pow2_log 4000 (nat (snd (quotient_of f))) 0 of
     Some k \<Rightarrow> if (1 / 2) ^ k = f then Some k else None | None \<Rightarrow> None)"

definition halv_nv :: "rat \<Rightarrow> nval" where
  "halv_nv f = (case log2_exact f of
     Some k \<Rightarrow> NR (of_nat k)
   | None \<Rightarrow> NA (floatarith.Mult (floatarith.Minus (floatarith.Ln (Q f))) (floatarith.Inverse (floatarith.Ln (I 2)))))"

theorem halv_nv_sound: "0 < f \<Longrightarrow> nreal (halv_nv f) = time_real (rl f)"
proof (cases "log2_exact f")
  case (Some k)
  then have f: "(1 / 2) ^ k = f" by (auto simp: log2_exact_def split: option.splits if_splits)
  have "rl f = (1 / 2) ^ k" using f[symmetric] by (simp add: of_rat_power of_rat_divide)
  moreover have "ln ((1 / 2) ^ k :: real) = - (real k * ln 2)" by (simp add: ln_realpow ln_div)
  ultimately show ?thesis using Some by (simp add: halv_nv_def time_real_def)
next
  case None
  then show ?thesis by (simp add: halv_nv_def time_real_def divide_inverse)
qed

definition time_nv :: "rat \<Rightarrow> rat \<Rightarrow> nval" where
  "time_nv T f = nscale T (halv_nv f)"

section \<open>Requests, outcomes, the kernel\<close>

datatype dreq =
    TimeToFraction hl "rat option" "tu option"
  | HalfLives hl "(rat \<times> tu) option"
  | Remaining hl "(rat \<times> tu) option" "(rat \<times> String.literal) option"
  | RemFraction hl "(rat \<times> tu) option" bool

datatype dkind = D_remaining_amount | D_remaining_fraction | D_time_to_fraction | D_half_lives
datatype dneed = DN_fraction | DN_elapsed | DN_amount | DN_halflife
datatype dout = DVal dkind nval | DDecline dneed

definition elapsed_s :: "rat \<times> tu \<Rightarrow> rat" where "elapsed_s p = fst p * tu_sec (snd p)"

fun dkernel :: "dreq \<Rightarrow> dout" where
  "dkernel (TimeToFraction h fo u) =
     (if hl_T h \<le> 0 then DDecline DN_halflife else
      case fo of None \<Rightarrow> DDecline DN_fraction
       | Some f \<Rightarrow> if 0 < f \<and> f < 1 then DVal D_time_to_fraction (time_nv (hl_T h) f)
                   else DDecline DN_fraction)"
| "dkernel (HalfLives h el) =
     (if hl_T h \<le> 0 then DDecline DN_halflife else
      case el of None \<Rightarrow> DDecline DN_elapsed
       | Some p \<Rightarrow> DVal D_half_lives (NR (elapsed_s p / hl_T h)))"
| "dkernel (Remaining h el am) =
     (if hl_T h \<le> 0 then DDecline DN_halflife else
      case el of None \<Rightarrow> DDecline DN_elapsed
       | Some p \<Rightarrow> (case am of None \<Rightarrow> DDecline DN_amount
            | Some (a, _) \<Rightarrow> DVal D_remaining_amount (nscale a (factor_nv (elapsed_s p / hl_T h)))))"
| "dkernel (RemFraction h el pct) =
     (if hl_T h \<le> 0 then DDecline DN_halflife else
      case el of None \<Rightarrow> DDecline DN_elapsed
       | Some p \<Rightarrow> DVal D_remaining_fraction
            (if pct then nscale 100 (factor_nv (elapsed_s p / hl_T h)) else factor_nv (elapsed_s p / hl_T h)))"

section \<open>What each kind means\<close>

theorem half_lives_value:
  assumes "dkernel (HalfLives h (Some p)) = DVal k v"
  shows "k = D_half_lives \<and> 0 < hl_T h \<and> nreal v * rl (hl_T h) = rl (elapsed_s p)"
proof -
  have T: "0 < hl_T h" using assms by (auto split: if_splits)
  have v: "v = NR (elapsed_s p / hl_T h)" and k: "k = D_half_lives" using assms T by (auto split: if_splits)
  have "rl (elapsed_s p / hl_T h) * rl (hl_T h) = rl (elapsed_s p)"
    using T by (simp add: of_rat_divide[symmetric] of_rat_mult[symmetric])
  then show ?thesis using v k T by simp
qed

text \<open>The sample remaining after elapsed time t is the initial amount times
the decay law at t / T.\<close>
theorem remaining_amount_value:
  assumes "dkernel (Remaining h (Some p) (Some (a, u))) = DVal k v"
  shows "k = D_remaining_amount \<and> 0 < hl_T h \<and> nreal v = rl a * decay_real (rl (elapsed_s p / hl_T h))"
proof -
  have T: "0 < hl_T h" using assms by (auto split: if_splits)
  have "v = nscale a (factor_nv (elapsed_s p / hl_T h))" and k: "k = D_remaining_amount"
    using assms T by (auto split: if_splits)
  then show ?thesis using T nreal_nscale factor_nv_sound by simp
qed

theorem remaining_fraction_value:
  assumes "dkernel (RemFraction h (Some p) pct) = DVal k v"
  shows "k = D_remaining_fraction \<and> 0 < hl_T h \<and>
    nreal v = (if pct then 100 else 1) * decay_real (rl (elapsed_s p / hl_T h))"
proof -
  have T: "0 < hl_T h" using assms by (auto split: if_splits)
  show ?thesis using assms T nreal_nscale factor_nv_sound by (cases pct) (auto split: if_splits)
qed

text \<open>After whole half-lives the factor is exactly one half to that power.\<close>
theorem remaining_whole_half_lives:
  assumes "dkernel (RemFraction h (Some p) False) = DVal k (NR q)" "elapsed_s p / hl_T h = rat_of_nat m"
    "m \<le> 2000"
  shows "q = (1 / 2) ^ m"
  using assms by (auto simp: factor_nv_def Let_def split: if_splits)

theorem time_to_fraction_value:
  assumes "dkernel (TimeToFraction h (Some f) u) = DVal k v"
  shows "k = D_time_to_fraction \<and> 0 < hl_T h \<and> 0 < f \<and> f < 1 \<and>
    nreal v = rl (hl_T h) * time_real (rl f) \<and>
    decay_real (nreal v / rl (hl_T h)) = rl f"
proof -
  have T: "0 < hl_T h" and f: "0 < f" "f < 1" using assms by (auto split: if_splits)
  have v: "v = time_nv (hl_T h) f" and k: "k = D_time_to_fraction" using assms T f by (auto split: if_splits)
  have n: "nreal v = rl (hl_T h) * time_real (rl f)"
    using v by (simp add: time_nv_def nreal_nscale halv_nv_sound f)
  have Tr: "rl (hl_T h) \<noteq> 0" using T by simp
  have rf: "0 < rl f" using f by (simp add: of_rat_less_0_iff)
  have "decay_real (nreal v / rl (hl_T h)) = decay_real (time_real (rl f))" using n Tr by simp
  then show ?thesis using k T f n time_real_inverse[OF rf] by simp
qed

theorem time_to_fraction_half:
  "dkernel (TimeToFraction h (Some (1 / 2)) u) = DVal k v \<Longrightarrow> nreal v = rl (hl_T h)"
  using time_to_fraction_value[of h "1 / 2" u k v] by (simp add: time_real_half of_rat_divide)

text \<open>The declines are exactly the organ's underspecified cases.\<close>
theorem decay_declines:
  "0 < hl_T h \<Longrightarrow> dkernel (Remaining h el am) = DDecline n \<longleftrightarrow>
     (el = None \<and> n = DN_elapsed) \<or> (\<exists>p. el = Some p \<and> am = None \<and> n = DN_amount)"
  by (cases el; cases am) (auto split: prod.splits)

theorem decay_declines_fraction:
  "0 < hl_T h \<Longrightarrow> dkernel (TimeToFraction h fo u) = DDecline n \<longleftrightarrow>
     n = DN_fraction \<and> (fo = None \<or> (\<exists>f. fo = Some f \<and> \<not> (0 < f \<and> f < 1)))"
  by (cases fo) auto

section \<open>Response text (ASCII)\<close>

definition g4 :: "rat \<Rightarrow> String.literal" where "g4 = gfmt 4"

definition unit_for :: "rat \<Rightarrow> tu" where
  "unit_for sec = (case List.find (\<lambda>u. tu_sec u \<le> sec) tu_order of Some u \<Rightarrow> u | None \<Rightarrow> TU_second)"

definition fmt_t :: "rat \<Rightarrow> String.literal" where
  "fmt_t sec = g4 (sec / tu_sec (unit_for sec)) + STR '' '' + tu_label (unit_for sec)"

definition hl_what :: "hl \<Rightarrow> String.literal" where
  "hl_what h = (case h of
     HL_stated v u \<Rightarrow> STR ''a half-life of '' + g4 v + STR '' '' + tu_label u
   | HL_iso i \<Rightarrow> iso_name i + STR '' (half-life '' + fmt_t (iso_T i) + STR '')'')"

definition ge_dec :: "nval \<Rightarrow> rat \<Rightarrow> bool option" where
  "ge_dec v f = (case v of
     NR q \<Rightarrow> Some (f \<le> q)
   | NA e \<Rightarrow> (case approx 53 e [] of
        None \<Rightarrow> None
      | Some X \<Rightarrow> if rl f \<le> real_of_float (lower X) then Some True
                  else if real_of_float (upper X) < rl f then Some False else None))"

lemma ge_dec_enclosure:
  assumes "approx 53 e [] = Some X"
  shows "real_of_float (lower X) \<le> interpret_floatarith e [] \<and> interpret_floatarith e [] \<le> real_of_float (upper X)"
proof -
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this assms] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis by (auto simp: set_of_eq)
qed

theorem ge_dec_true:
  assumes "ge_dec v f = Some True"
  shows "rl f \<le> nreal v"
proof (cases v)
  case (NR q) then show ?thesis using assms by (simp add: ge_dec_def of_rat_less_eq)
next
  case (NA e)
  obtain X where X: "approx 53 e [] = Some X" and c: "rl f \<le> real_of_float (lower X)"
    using assms NA by (auto simp: ge_dec_def split: option.splits if_splits)
  show ?thesis using ge_dec_enclosure[OF X] c NA by simp
qed

theorem ge_dec_false:
  assumes "ge_dec v f = Some False"
  shows "nreal v < rl f"
proof (cases v)
  case (NR q) then show ?thesis using assms by (simp add: ge_dec_def of_rat_less)
next
  case (NA e)
  obtain X where X: "approx 53 e [] = Some X" and c: "real_of_float (upper X) < rl f"
    using assms NA by (auto simp: ge_dec_def split: option.splits if_splits)
  show ?thesis using ge_dec_enclosure[OF X] c NA by simp
qed

text \<open>The unit the organ's fmt_t picks for a time: the first of
years, days, hours, minutes whose length does not exceed it; seconds
otherwise. None when the enclosure cannot tell.\<close>
fun pick_unit :: "tu list \<Rightarrow> nval \<Rightarrow> tu option" where
  "pick_unit [] v = Some TU_second"
| "pick_unit (u # us) v = (case ge_dec v (tu_sec u) of
     Some True \<Rightarrow> Some u | Some False \<Rightarrow> pick_unit us v | None \<Rightarrow> None)"

definition ttf_shown :: "rat \<Rightarrow> tu option \<Rightarrow> nval \<Rightarrow> String.literal option" where
  "ttf_shown f ou tt = (case (case ou of Some u \<Rightarrow> Some u | None \<Rightarrow> pick_unit tu_order tt) of
     None \<Rightarrow> None
   | Some u \<Rightarrow> (case ndec (nscale (1 / tu_sec u) tt) of
        None \<Rightarrow> None
      | Some d \<Rightarrow> Some (render_dec 4 d)))"

fun need_text :: "dneed \<Rightarrow> String.literal" where
  "need_text DN_fraction = STR ''I need the fraction or amount that should remain to compute that; I won'' + apos + STR ''t assume it.''"
| "need_text DN_elapsed = STR ''I need the elapsed time to compute that; I won'' + apos + STR ''t assume it.''"
| "need_text DN_amount = STR ''I need the starting amount to compute that; I won'' + apos + STR ''t assume it.''"
| "need_text DN_halflife = STR ''I need a positive half-life to compute that; I won'' + apos + STR ''t assume it.''"

fun dkind_name :: "dkind \<Rightarrow> String.literal" where
  "dkind_name D_remaining_amount = STR ''remaining_amount''"
| "dkind_name D_remaining_fraction = STR ''remaining_fraction''"
| "dkind_name D_time_to_fraction = STR ''time_to_fraction''"
| "dkind_name D_half_lives = STR ''half_lives''"

text \<open>The response text and the stated number of an answered request, or None
when a four-digit enclosure is unavailable.\<close>
fun answer_text :: "dreq \<Rightarrow> nval \<Rightarrow> (String.literal \<times> String.literal) option" where
  "answer_text (HalfLives h (Some p)) v = (case ndec v of None \<Rightarrow> None
     | Some d \<Rightarrow> Some (STR ''That is about '' + render_dec 4 d + STR '' half-lives (t/T for '' + hl_what h + STR '').'',
                     render_dec 4 d))"
| "answer_text (Remaining h (Some p) (Some (a, ul))) v = (case ndec v of None \<Rightarrow> None
     | Some d \<Rightarrow> Some (STR ''About '' + render_dec 4 d + STR '' '' + ul + STR '' remains after '' + g4 (fst p)
         + STR '' '' + tu_label (snd p) + STR '' (N = N0*(1/2)^(t/T) = '' + g4 a + STR '' x ''
         + nshow (factor_nv (elapsed_s p / hl_T h)) + STR '', '' + hl_what h + STR '').'',
         render_dec 4 d))"
| "answer_text (RemFraction h (Some p) pct) v = (case ndec v of None \<Rightarrow> None
     | Some d \<Rightarrow> Some (STR ''The remaining fraction is about '' + nshow (factor_nv (elapsed_s p / hl_T h))
         + STR '' ('' + nshow (nscale 100 (factor_nv (elapsed_s p / hl_T h))) + STR ''%) after '' + g4 (fst p)
         + STR '' '' + tu_label (snd p) + STR '' ((1/2)^(t/T), '' + hl_what h + STR '').'',
         render_dec 4 d))"
| "answer_text (TimeToFraction h (Some f) ou) v = (case ttf_shown f ou v of None \<Rightarrow> None
     | Some s \<Rightarrow> Some (STR ''It takes about '' + s + STR '' '' + (case ou of Some u \<Rightarrow> tu_label u
           | None \<Rightarrow> (case pick_unit tu_order v of Some u \<Rightarrow> tu_label u | None \<Rightarrow> STR ''''))
         + STR '' for '' + g4 f + STR '' of the sample to remain (t = T*log2(1/f) = '' + nshow (halv_nv f)
         + STR '' halvings of '' + hl_what h + STR '').'', s))"
| "answer_text _ _ = None"

definition reply_d :: "dreq \<Rightarrow> reply" where
  "reply_d r = (case dkernel r of
     DDecline n \<Rightarrow> Reply False (STR ''underspecified'') (need_text n) None
   | DVal k v \<Rightarrow> (case answer_text r v of
         Some (txt, num) \<Rightarrow> Reply True (dkind_name k) txt (Some num)
       | None \<Rightarrow> Reply False (STR ''imprecise'')
            (STR ''The interval arithmetic could not pin four digits; I won'' + apos + STR ''t guess.'') None))"

theorem reply_d_withheld:
  "dkernel r = DDecline n \<Longrightarrow> \<not> answered (reply_d r) \<and> reply_kind (reply_d r) = STR ''underspecified''"
  by (simp add: reply_d_def)

theorem reply_d_answered:
  "answered (reply_d r) \<Longrightarrow> \<exists>k v t s. dkernel r = DVal k v \<and> answer_text r v = Some (t, s)"
  by (cases "dkernel r") (auto simp: reply_d_def split: option.splits prod.splits)

end
