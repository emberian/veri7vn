theory Home
  imports Energy_Core
begin

text \<open>
  The Oracle7 home-energy specialists energy-v2 and energy-v3
  (upstream/root/specialists/energy-{v2,v3}/organ_energy_v{1,2,3}.py): the
  energy a device uses, what it costs at a stated tariff, how long a battery
  runs a load, a solar array's yield, a payback period and the saving from
  swapping one device for another. v2 and v3 differ only in how the question is
  read (the untrusted recognizer); the arithmetic is one kernel. Everything is
  exact rational arithmetic.
\<close>

section \<open>Requests\<close>

text \<open>How long a device runs, as the question states it. The total in hours
is what the formulas use; 365 and 30 days are the organ's year and month.\<close>
datatype hspec = H_pdd rat rat | H_pdy rat | H_pdm rat | H_day rat | H_tot rat | H_min rat

fun htot :: "hspec \<Rightarrow> rat" where
  "htot (H_pdd h d) = h * d" | "htot (H_pdy h) = h * 365" | "htot (H_pdm h) = h * 30"
| "htot (H_day h) = h" | "htot (H_tot h) = h" | "htot (H_min m) = m / 60"

datatype cap = Cap_wh rat | Cap_kwh rat | Cap_ahv rat rat
fun capwh :: "cap \<Rightarrow> rat" where
  "capwh (Cap_wh x) = x" | "capwh (Cap_kwh x) = x * 1000" | "capwh (Cap_ahv ah v) = ah * v"

datatype derate = Dr_none | Dr_loss rat | Dr_eff rat
datatype per = Per_day | Per_year | Per_month

fun perfac :: "per \<Rightarrow> rat" where "perfac Per_day = 1" | "perfac Per_year = 365" | "perfac Per_month = 30"
fun dfac :: "derate \<Rightarrow> rat" where "dfac Dr_none = 1" | "dfac (Dr_loss p) = 1 - p / 100" | "dfac (Dr_eff f) = f"

text \<open>HPayback: cost in dollars, saving and whether it is per month. HRuntime:
battery, load in watts. HSolar: array (size, True when given in kW), number of
panels, peak sun hours, derate, period. HSwap: the two wattages, hours, tariff.
HEnergy: watts, hours, tariff, and whether a cost was asked.\<close>
datatype home_req =
    HPayback "rat option" "(rat \<times> bool) option"
  | HRuntime "cap option" "rat option"
  | HSolar "(rat \<times> bool) option" "rat option" "rat option" derate per
  | HSwap rat rat "hspec option" "rat option"
  | HEnergy "rat option" "hspec option" "rat option" bool

fun syear :: "rat \<Rightarrow> bool \<Rightarrow> rat" where "syear s m = (if m then s * 12 else s)"

fun solar_kw :: "(rat \<times> bool) option \<Rightarrow> rat option \<Rightarrow> rat" where
  "solar_kw None _ = 0"
| "solar_kw (Some (n, True)) _ = n"
| "solar_kw (Some (n, False)) p = n / 1000 * (case p of None \<Rightarrow> 1 | Some x \<Rightarrow> x)"

section \<open>Declines\<close>

fun miss_h :: "home_req \<Rightarrow> String.literal option" where
  "miss_h (HPayback c s) = (case (c, s) of (Some _, Some _) \<Rightarrow> None
     | _ \<Rightarrow> Some (STR ''the up-front cost and the saving per year (or month)''))"
| "miss_h (HRuntime c w) = (case c of None \<Rightarrow> Some (STR ''the capacity of the battery (Wh, or volts and amp-hours)'')
     | Some _ \<Rightarrow> (case w of None \<Rightarrow> Some (STR ''the load in watts'') | Some _ \<Rightarrow> None))"
| "miss_h (HSolar a p s d pe) = (case (a, s) of (Some _, Some _) \<Rightarrow> None
     | _ \<Rightarrow> Some (STR ''the array size (kW) and the peak sun hours''))"
| "miss_h (HSwap a b h r) = (case h of None \<Rightarrow> Some (STR ''how many hours it runs'') | Some _ \<Rightarrow> None)"
| "miss_h (HEnergy w h r c) = (case (w, h) of (Some _, Some _) \<Rightarrow> None
     | _ \<Rightarrow> Some (STR ''the wattage of the device and how long it runs''))"

abbreviation gw :: "rat \<Rightarrow> String.literal" where "gw \<equiv> gf G4W"
definition money :: "rat \<Rightarrow> String.literal" where "money x = STR ''$'' + gf M2 x"

fun hnote :: "hspec \<Rightarrow> String.literal" where
  "hnote (H_pdd h d) = gw h + STR '' h/day x '' + gw d + STR '' days''"
| "hnote (H_pdy h) = gw h + STR '' h/day x 365 days''"
| "hnote (H_pdm h) = gw h + STR '' h/day x 30 days''"
| "hnote (H_day h) = gw h + STR '' h (one day)''"
| "hnote (H_tot h) = gw h + STR '' h''"
| "hnote (H_min m) = gw m + STR '' min''"

fun post_h :: "home_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "post_h (HRuntime c (Some w)) =
     (if w \<le> 0 then Some (D_imposs, STR ''A load must draw more than 0 W.'') else None)"
| "post_h (HEnergy (Some w) (Some h) None True) =
     Some (D_tariff, STR ''It uses '' + gw (w * htot h / 1000) + STR '' kWh ('' + gw w + STR '' W x ''
       + hnote h + STR ''); give me your price per kWh and I will price it.'')"
| "post_h _ = None"

fun fx_h :: "home_req \<Rightarrow> String.literal option" where
  "fx_h (HPayback (Some c) (Some (s, m))) = (if syear s m \<le> 0 then Some (STR ''never'') else None)"
| "fx_h _ = None"

section \<open>Values\<close>

fun vl_h :: "home_req \<Rightarrow> rat" where
  "vl_h (HPayback (Some c) (Some (s, m))) = c / syear s m"
| "vl_h (HRuntime (Some c) (Some w)) = capwh c / w"
| "vl_h (HSolar a p (Some s) d pe) = solar_kw a p * s * dfac d * perfac pe"
| "vl_h (HSwap a b (Some h) r) = (a - b) * htot h / 1000"
| "vl_h (HEnergy (Some w) (Some h) r cost) =
     (if cost then w * htot h / 1000 * (case r of None \<Rightarrow> 0 | Some x \<Rightarrow> x) else w * htot h / 1000)"
| "vl_h _ = 0"

fun kd_h :: "home_req \<Rightarrow> String.literal" where
  "kd_h (HPayback _ _) = STR ''payback''"
| "kd_h (HRuntime _ _) = STR ''runtime''"
| "kd_h (HSolar _ _ _ _ _) = STR ''solar_yield''"
| "kd_h (HSwap _ _ _ _) = STR ''swap_saving''"
| "kd_h (HEnergy _ _ _ cost) = (if cost then STR ''cost'' else STR ''energy'')"

definition kernel_h :: "home_req \<Rightarrow> outcome" where
  "kernel_h = mk_kernel (\<lambda>_. None) miss_h post_h fx_h kd_h vl_h (\<lambda>_. False)"

section \<open>Soundness\<close>

theorem home_exact_sound:
  assumes "kernel_h r = Exact k q"
  shows "miss_h r = None \<and> post_h r = None \<and> fx_h r = None \<and> k = kd_h r \<and> q = vl_h r"
  using assms by (auto simp: kernel_h_def mk_exact)

lemmas exact_parts_h =
  home_exact_sound[THEN conjunct1]
  home_exact_sound[THEN conjunct2, THEN conjunct1]
  home_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct1]
  home_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct1]
  home_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2]

lemma post_h_not_under: "post_h r \<noteq> Some (D_under, w)"
  by (cases r rule: post_h.cases) auto

theorem home_underspecified:
  "kernel_h r = Decline D_under w \<longleftrightarrow> miss_h r = Some w"
  by (auto simp: kernel_h_def mk_decline post_h_not_under)

theorem home_declines:
  "kernel_h r = Decline d w \<longleftrightarrow>
     (miss_h r = Some w \<and> d = D_under) \<or> (miss_h r = None \<and> post_h r = Some (d, w))"
  by (auto simp: kernel_h_def mk_decline)

text \<open>Payback: the years times the yearly saving give the cost, the saving is
positive, and a saving of nothing (or less) is answered "never" with no number.\<close>
theorem payback_law:
  assumes "kernel_h (HPayback (Some c) (Some (s, m))) = Exact k q"
  shows "k = STR ''payback'' \<and> 0 < syear s m \<and> q * syear s m = c"
proof -
  note p = exact_parts_h[OF assms]
  have pos: "0 < syear s m" using p(3) by (auto split: if_splits)
  have nz: "syear s m \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = c / syear s m" using p(5) by simp
  then show ?thesis using p(4) pos nz by (simp add: field_simps)
qed

theorem payback_never:
  "kernel_h (HPayback (Some c) (Some (s, m))) = Fixed k \<longleftrightarrow> syear s m \<le> 0 \<and> k = STR ''never''"
  by (auto simp: kernel_h_def mk_fixed)

theorem runtime_law:
  assumes "kernel_h (HRuntime (Some c) (Some w)) = Exact k q"
  shows "k = STR ''runtime'' \<and> 0 < w \<and> q * w = capwh c"
proof -
  note p = exact_parts_h[OF assms]
  have pos: "0 < w" using p(2) by (auto split: if_splits)
  have nz: "w \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = capwh c / w" using p(5) by simp
  then show ?thesis using p(4) pos nz by (simp add: field_simps)
qed

theorem solar_law:
  assumes "kernel_h (HSolar a p (Some s) d pe) = Exact k q"
  shows "k = STR ''solar_yield'' \<and> q = solar_kw a p * s * dfac d * perfac pe"
  using exact_parts_h(4,5)[OF assms] by simp

theorem swap_law:
  assumes "kernel_h (HSwap a b (Some h) r) = Exact k q"
  shows "k = STR ''swap_saving'' \<and> q * 1000 = (a - b) * htot h"
  using exact_parts_h(4,5)[OF assms] by (simp add: field_simps)

theorem energy_law:
  assumes "kernel_h (HEnergy (Some w) (Some h) r False) = Exact k q"
  shows "k = STR ''energy'' \<and> q * 1000 = w * htot h"
  using exact_parts_h(4,5)[OF assms] by (simp add: field_simps)

theorem cost_law:
  assumes "kernel_h (HEnergy (Some w) (Some h) (Some rate) True) = Exact k q"
  shows "k = STR ''cost'' \<and> q = (w * htot h / 1000) * rate"
  using exact_parts_h(4,5)[OF assms] by simp

text \<open>A cost asked with no tariff is refused as needing the tariff, never
answered with a guessed price.\<close>
theorem cost_needs_tariff:
  "\<exists>w'. kernel_h (HEnergy (Some w) (Some h) None True) = Decline D_tariff w'"
  by (simp add: kernel_h_def mk_kernel_def)

section \<open>Reply text\<close>

fun capnote :: "cap \<Rightarrow> String.literal" where
  "capnote (Cap_wh x) = gw x + STR '' Wh''"
| "capnote (Cap_kwh x) = gw (x * 1000) + STR '' Wh''"
| "capnote (Cap_ahv ah v) = gw v + STR '' V x '' + gw ah + STR '' Ah = '' + gw (ah * v) + STR '' Wh''"

fun pertext :: "per \<Rightarrow> String.literal" where
  "pertext Per_day = STR '' a day''" | "pertext Per_year = STR '' a year (365 days)''"
| "pertext Per_month = STR '' a month (30 days)''"

fun dernote :: "derate \<Rightarrow> String.literal" where
  "dernote Dr_none = STR ''before losses''"
| "dernote (Dr_loss p) = STR ''after '' + gw p + STR ''% losses''"
| "dernote (Dr_eff f) = STR ''at a '' + gw f + STR '' derate''"

fun fmt_h :: "home_req \<Rightarrow> nfmt" where
  "fmt_h (HEnergy _ _ _ cost) = (if cost then M2 else G4W)"
| "fmt_h _ = G4W"

fun exact_text_h :: "home_req \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text_h (HPayback (Some c) (Some (s, m))) q V = STR ''The payback period is '' + V
     + STR '' years ('' + money c + STR '' / '' + money (syear s m)
     + STR '' saved per year), ignoring price changes and financing.''"
| "exact_text_h (HRuntime (Some c) (Some w)) q V = STR ''The runtime is about '' + V + STR '' hours (''
     + capnote c + STR '' / '' + gw w + STR '' W), before inverter and depth-of-discharge losses.''"
| "exact_text_h (HSolar a p (Some s) d pe) q V = STR ''The array makes about '' + V + STR '' kWh''
     + pertext pe + STR '' ('' + gw (solar_kw a p) + STR '' kW x '' + gw s + STR '' peak sun hours, ''
     + dernote d + STR '').''"
| "exact_text_h (HSwap a b (Some h) r) q V = (case r of
       None \<Rightarrow> STR ''That saves '' + V + STR '' kWh ('' + gw (a - b) + STR '' W less x '' + hnote h + STR '').''
     | Some rate \<Rightarrow> STR ''That saves '' + V + STR '' kWh, about '' + money (q * rate) + STR '' at $''
         + gf G6 rate + STR ''/kWh ('' + gw (a - b) + STR '' W less x '' + hnote h + STR '').'')"
| "exact_text_h (HEnergy (Some w) (Some h) r cost) q V = (if cost then
       STR ''It costs about $'' + V + STR '' ('' + gw (w * htot h / 1000) + STR '' kWh = '' + gw w + STR '' W x ''
         + hnote h + STR '', at $'' + gf G6 (case r of None \<Rightarrow> 0 | Some x \<Rightarrow> x) + STR ''/kWh).''
     else STR ''It uses '' + V + STR '' kWh ('' + gw w + STR '' W x '' + hnote h + STR '' = ''
         + gw (w * htot h) + STR '' Wh).'')"
| "exact_text_h _ q V = V"

fun fixed_text_h :: "home_req \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "fixed_text_h _ k = STR ''With no saving, it never pays back.''"

definition reply_h :: "home_req \<Rightarrow> reply" where
  "reply_h = mk_reply kernel_h (\<lambda>r q. show_fmt (fmt_h r) (rl q)) (\<lambda>r. fmt_h r = G4W) exact_text_h
     (\<lambda>_ _. None) fixed_text_h"

theorem reply_h_answered_iff:
  "answered (reply_h r) \<longleftrightarrow>
     (\<exists>k q V. kernel_h r = Exact k q \<and> show_fmt (fmt_h r) (rl q) = Some V) \<or> (\<exists>k. kernel_h r = Fixed k)"
  by (simp add: reply_h_def kernel_h_def mk_reply_answered_iff mk_pi)

theorem reply_h_states_digits:
  assumes "kernel_h r = Exact k q" "show_fmt (fmt_h r) (rl q) = Some V"
  shows "\<exists>d. num_dec_r (fmt_h r) (rl q) = Some d \<and> V = layout (fmt_h r) (rl q) d \<and>
             \<bar>dec_val d - rl q\<bar> \<le> fmt_err_r (fmt_h r) (rl q)"
  using show_fmt_sound[OF assms(2)] by blast

theorem reply_h_withheld:
  assumes "kernel_h r = Decline d w"
  shows "\<not> answered (reply_h r) \<and> response (reply_h r) = decline_text d w"
  using assms by (simp add: reply_h_def mk_reply_def)

end
