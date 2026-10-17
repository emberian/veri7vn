# Lane S06-energy handoff

Specialists lifted as one family kernel: thermo, energy-v3, energy-v2, hvac, renewables, iot.
Files: `src/extract/energy/` (ROOT, base/Energy_Base.thy, Energy_Core.thy, Thermo.thy, Home.thy, Hvac.thy,
Renewables.thy, Iot.thy, Energy_Family.thy, Energy_Export.thy, tables_check.py, regex.sml, recognizer.sml,
main.sml, build.sh, score.py, README.md). Binary `var/energy/bin/energy` (760,552 bytes, not in git),
cold start about 5 ms, p50 0.07 to 0.18 ms against a 50 ms budget.

Build: `VERI7VN_ENERGY PASS theorems=92 oracles=0` (check-native, session `Veri7vn_Energy`, no sorry, self test holds).
regex.sml is the d85f26c fixed copy; recognizer calls `Regex.compile p`.

## For fusion (lane H): calling thermo
Request type `Energy.family_request`; thermo is `FThermo (Thermo ts q)`.
`ts : temp list` is every temperature the question names in order (`Temp value TU_C|TU_F|TU_K`, value an exact rat via `mk_rat`).
`q` is one of `TCarnot hot_first_bool` | `TGas n_opt (value,punit)_opt (value,vunit)_opt` (exactly three of n, P, V, T given; T is the first of ts)
| `TRad area_opt emissivity` | `TFusion (mass,munit)_opt` | `TVapor (mass,munit)_opt` | `TSens (mass,munit)_opt csrc dtq`
(`csrc` = `C_given c | C_mat material | C_none`; `dtq` = `DT_by d | DT_temps`) | `TAny` (a temperature below absolute zero).
`Energy.reply_of` returns answered/withheld, kind (carnot, gas_pressure, gas_volume, gas_moles, gas_temperature,
radiated_power, latent_fusion, latent_vapor, sensible_heat; declines underspecified / impossible), response text and stated number.
Material names: `Energy.mat_table`. The easiest route is to call the binary with `--specialist thermo`.

## Scores (shipped panels, binary, harness-compatible; score.py also compares each reply with the organ)
| specialist | split | right/n | wrong | withheld-valid | false yes | shipped heldout |
|---|---|---|---|---|---|---|
| thermo | dev / heldout | 44/44, 50/50 | 0 | 0 | 0 | 50/50 |
| energy-v2 | dev / heldout | 68/68, 74/74 (family order, v3 reading); 67/74 with `--specialist energy-v2` | 0 / 7 | 0 | 0 | 66/74, 1 false yes |
| energy-v3 | dev / heldout | 74/74, 70/70 | 0 | 0 | 0 | 69/70 |
| hvac | dev / heldout | 41/41, 42/42 | 0 | 0 | 0 | 42/42 |
| renewables | dev / heldout | 26/26, 23/26 | 0 | 3 | 0 | 23/26 |
| iot | dev / heldout | 27/27, 27/27 | 0 | 0 | 0 | 27/27 |

Named misses (all faithful to the organ, 0 organ disagreements in specialist mode):
- energy-v2 alone, 7 wrong: passive swap questions ("A 75 W bulb is replaced by a 11 W LED, lit 6 hours a day. How much energy is saved in a year?" answered "It uses 164.3 kWh"). This is the v2 defect that v3 fixes; the harness (family mode, v3 reading) scores 74/74.
- renewables, 3 withheld: "A dam turbine sees 200 cubic meters per second falling 100 m at 85% efficiency..." and two siblings; the organ also withholds ("falling" is no head cue).
Harness output: `var/energy/parity`; own cross-check `python3 src/extract/energy/score.py`.

## Untrusted parts
regex.sml, recognizer.sml (hand port of the six organs plus narrow_v1; the family order thermo, hvac, renewables, iot, energy-v3 behind each manifest context regex), main.sml, tables_check.py (a text check, not a proof), the layout of digits (`layout`, checked by self test and panels), the ASCII reply text.

## Deviations
Zero divisors are refused as impossible (organs raise); ADC code is the exact floor (organ adds 1e-9); reply text is ASCII; an exact decimal tie rounds up (Python rounds a binary float).
The wind power for a rotor diameter or blade length is PiMul: a rational times pi, digits from HOL-Decision_Procs.Approximation; an enclosure straddling a W/kW/MW boundary is refused.

## Remaining
The lane-stays-in-its-lane check on the 924 core questions (lane C's gate) was not run for the family binary. Family mode answers energy-v2 questions with the v3 reading (2 to 9 organ disagreements, all v3 fixes).

## Reproduce
```
python3 tools/dev/check-native --session Veri7vn_Energy --session-root src/extract/energy --expect 'VERI7VN_ENERGY PASS' --timeout 1500
sh src/extract/energy/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/energy/tables_check.py   # PASS
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/energy/score.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/energy/bin/energy" --specialist thermo,energy-v2,energy-v3,hvac,renewables,iot --split both --out var/energy/parity
```

## Theorem statements (verbatim, extracted from the theories)
```
Energy_Core.thy: round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"

Energy_Core.thy: round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"

Energy_Core.thy: to_dec_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000"

Energy_Core.thy: num_dec_r_sound:
  assumes "num_dec_r f x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> fmt_err_r f x"

Energy_Core.thy: show_fmt_sound:
  assumes "show_fmt f x = Some s"
  shows "\<exists>d. num_dec_r f x = Some d \<and> s = layout f x d \<and> \<bar>dec_val d - x\<bar> \<le> fmt_err_r f x"

Energy_Core.thy: pi_bounds_sound:
  assumes "pi_bounds c = Some (lo, hi)"
  shows "lo \<le> rl c * pi \<and> rl c * pi \<le> hi"

Energy_Core.thy: pw_scale_sound:
  assumes "pw_scale lo hi = Some (s, i)"
  shows "0 < s \<and> (s = 1 \<or> s \<le> lo) \<and> (hi < 1000 * s \<or> i = 3)"

Energy_Core.thy: pw_show_sound:
  assumes "pw_show en lo hi = Some t"
  shows "\<exists>s i d. pw_scale lo hi = Some (s, i) \<and> num_dec_r F3C ((lo + hi) / 2 / s) = Some d \<and>
         \<bar>dec_val d - (lo + hi) / 2 / s\<bar> \<le> fmt_err_r F3C ((lo + hi) / 2 / s)"

Energy_Core.thy: mk_exact:
  "mk_kernel pre miss post fx kd vl pf r = Exact k q \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = None \<and> \<not> pf r \<and> k = kd r \<and> q = vl r"

Energy_Core.thy: mk_pi:
  "mk_kernel pre miss post fx kd vl pf r = PiMul k q \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = None \<and> pf r \<and> k = kd r \<and> q = vl r"

Energy_Core.thy: mk_fixed:
  "mk_kernel pre miss post fx kd vl pf r = Fixed k \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = Some k"

Energy_Core.thy: mk_decline:
  "mk_kernel pre miss post fx kd vl pf r = Decline d w \<longleftrightarrow>
     pre r = Some (d, w) \<or> (pre r = None \<and> miss r = Some w \<and> d = D_under) \<or>
     (pre r = None \<and> miss r = None \<and> post r = Some (d, w))"

Energy_Core.thy: mk_reply_answered_iff:
  "answered (mk_reply kn shw plain ext pit fxt r) \<longleftrightarrow>
     (\<exists>k q V. kn r = Exact k q \<and> shw r q = Some V) \<or> (\<exists>k c s. kn r = PiMul k c \<and> pit r c = Some s) \<or>
     (\<exists>k. kn r = Fixed k)"

Energy_Core.thy: mk_reply_exact:
  "kn r = Exact k q \<Longrightarrow> shw r q = Some V \<Longrightarrow>
     response (mk_reply kn shw plain ext pit fxt r) = ext r q V \<and>
     reply_kind (mk_reply kn shw plain ext pit fxt r) = k"

Energy_Core.thy: mk_reply_withheld:
  "kn r = Decline d w \<Longrightarrow>
     \<not> answered (mk_reply kn shw plain ext pit fxt r) \<and>
     response (mk_reply kn shw plain ext pit fxt r) = decline_text d w \<and>
     reply_kind (mk_reply kn shw plain ext pit fxt r) = dcl_name d"

Thermo.thy: thermo_exact_sound:
  assumes "kernel_t r = Exact k q"
  shows "pre_t r = None \<and> miss_t r = None \<and> post_t r = None \<and> k = kd_t r \<and> q = vl_t r"

Thermo.thy: thermo_underspecified:
  "kernel_t r = Decline D_under w \<longleftrightarrow> pre_t r = None \<and> miss_t r = Some w"

Thermo.thy: thermo_impossible_temperature:
  assumes "\<exists>t \<in> set ts. kel t < 0"
  shows "\<exists>w. kernel_t (Thermo ts q) = Decline D_imposs w"

Thermo.thy: thermo_impossible_only_if:
  assumes "kernel_t r = Decline D_imposs w"
  shows "pre_t r = Some (D_imposs, w) \<or> (pre_t r = None \<and> miss_t r = None \<and> post_t r = Some (D_imposs, w))"

Thermo.thy: thermo_no_other_declines:
  assumes "kernel_t r = Decline d w"
  shows "d = D_under \<or> d = D_imposs"

Thermo.thy: kelvin_scales: "kelvin TU_F v = kelvin TU_C ((v - 32) * 5 / 9)"

Thermo.thy: carnot_law:
  assumes "kernel_t (Thermo (t0 # t1 # rest) (TCarnot hf)) = Exact k q"
  shows "k = STR ''carnot'' \<and> 0 \<le> cold hf (kel t0) (kel t1) \<and>
         cold hf (kel t0) (kel t1) < hot hf (kel t0) (kel t1) \<and>
         q * hot hf (kel t0) (kel t1) = 100 * (hot hf (kel t0) (kel t1) - cold hf (kel t0) (kel t1))"

Thermo.thy: gas_pressure_law:
  assumes "kernel_t (Thermo (t # rest) (TGas (Some n) None (Some (v, vu)))) = Exact k q"
  shows "k = STR ''gas_pressure'' \<and> v * vfac vu \<noteq> 0 \<and> q * (v * vfac vu) = n * R_gas * kel t"

Thermo.thy: gas_volume_law:
  assumes "kernel_t (Thermo (t # rest) (TGas (Some n) (Some (p, pu)) None)) = Exact k q"
  shows "k = STR ''gas_volume'' \<and> p * pfac pu \<noteq> 0 \<and> q * (p * pfac pu) = n * R_gas * kel t"

Thermo.thy: gas_moles_law:
  assumes "kernel_t (Thermo (t # rest) (TGas None (Some (p, pu)) (Some (v, vu)))) = Exact k q"
  shows "k = STR ''gas_moles'' \<and> R_gas * kel t \<noteq> 0 \<and>
         q * (R_gas * kel t) = (p * pfac pu) * (v * vfac vu)"

Thermo.thy: gas_temperature_law:
  assumes "kernel_t (Thermo [] (TGas (Some n) (Some (p, pu)) (Some (v, vu)))) = Exact k q"
  shows "k = STR ''gas_temperature'' \<and> n \<noteq> 0 \<and> q * (n * R_gas) = (p * pfac pu) * (v * vfac vu)"

Thermo.thy: gas_three_given:
  assumes "kernel_t (Thermo ts (TGas n p v)) = Exact k q"
  shows "nunk n p v ts = 1"

Thermo.thy: radiated_power_law:
  assumes "kernel_t (Thermo (t # rest) (TRad (Some a) e)) = Exact k q"
  shows "k = STR ''radiated_power'' \<and> 0 < e \<and> e \<le> 1 \<and> q = e * sigma_sb * a * (kel t) ^ 4"

Thermo.thy: latent_fusion_law:
  assumes "kernel_t (Thermo ts (TFusion (Some (x, u)))) = Exact k q"
  shows "k = STR ''latent_fusion'' \<and> q = (x * mfac u) * 334000"

Thermo.thy: latent_vapor_law:
  assumes "kernel_t (Thermo ts (TVapor (Some (x, u)))) = Exact k q"
  shows "k = STR ''latent_vapor'' \<and> q = (x * mfac u) * 2257000"

Thermo.thy: sensible_heat_by:
  assumes "kernel_t (Thermo ts (TSens (Some (x, u)) cs (DT_by d))) = Exact k q"
  shows "k = STR ''sensible_heat'' \<and> q = (x * mfac u) * csv cs * d"

Thermo.thy: sensible_heat_temps:
  assumes "kernel_t (Thermo (t0 # t1 # rest) (TSens (Some (x, u)) cs DT_temps)) = Exact k q"
  shows "k = STR ''sensible_heat'' \<and> q = (x * mfac u) * csv cs * (kel t1 - kel t0)"

Thermo.thy: sensible_heat_table:
  assumes "kernel_t (Thermo ts (TSens (Some (x, u)) (C_mat m) (DT_by d))) = Exact k q"
  shows "q = (x * mfac u) * spec_heat m * d"

Thermo.thy: reply_t_answered_iff:
  "answered (reply_t r) \<longleftrightarrow> (\<exists>k q V. kernel_t r = Exact k q \<and> show_fmt G4 (rl q) = Some V)"

Thermo.thy: reply_t_states_four_digits:
  assumes "kernel_t r = Exact k q" "show_fmt G4 (rl q) = Some V"
  shows "stated (reply_t r) = Some V \<and>
         (\<exists>d. num_dec_r G4 (rl q) = Some d \<and> \<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1)) \<and>
              V = layout G4 (rl q) d)"

Thermo.thy: reply_t_withheld:
  assumes "kernel_t r = Decline d w"
  shows "\<not> answered (reply_t r) \<and> response (reply_t r) = decline_text d w"

Home.thy: home_exact_sound:
  assumes "kernel_h r = Exact k q"
  shows "miss_h r = None \<and> post_h r = None \<and> fx_h r = None \<and> k = kd_h r \<and> q = vl_h r"

Home.thy: home_underspecified:
  "kernel_h r = Decline D_under w \<longleftrightarrow> miss_h r = Some w"

Home.thy: home_declines:
  "kernel_h r = Decline d w \<longleftrightarrow>
     (miss_h r = Some w \<and> d = D_under) \<or> (miss_h r = None \<and> post_h r = Some (d, w))"

Home.thy: payback_law:
  assumes "kernel_h (HPayback (Some c) (Some (s, m))) = Exact k q"
  shows "k = STR ''payback'' \<and> 0 < syear s m \<and> q * syear s m = c"

Home.thy: payback_never:
  "kernel_h (HPayback (Some c) (Some (s, m))) = Fixed k \<longleftrightarrow> syear s m \<le> 0 \<and> k = STR ''never''"

Home.thy: runtime_law:
  assumes "kernel_h (HRuntime (Some c) (Some w)) = Exact k q"
  shows "k = STR ''runtime'' \<and> 0 < w \<and> q * w = capwh c"

Home.thy: solar_law:
  assumes "kernel_h (HSolar a p (Some s) d pe) = Exact k q"
  shows "k = STR ''solar_yield'' \<and> q = solar_kw a p * s * dfac d * perfac pe"

Home.thy: swap_law:
  assumes "kernel_h (HSwap a b (Some h) r) = Exact k q"
  shows "k = STR ''swap_saving'' \<and> q * 1000 = (a - b) * htot h"

Home.thy: energy_law:
  assumes "kernel_h (HEnergy (Some w) (Some h) r False) = Exact k q"
  shows "k = STR ''energy'' \<and> q * 1000 = w * htot h"

Home.thy: cost_law:
  assumes "kernel_h (HEnergy (Some w) (Some h) (Some rate) True) = Exact k q"
  shows "k = STR ''cost'' \<and> q = (w * htot h / 1000) * rate"

Home.thy: cost_needs_tariff:
  "\<exists>w'. kernel_h (HEnergy (Some w) (Some h) None True) = Decline D_tariff w'"

Home.thy: reply_h_answered_iff:
  "answered (reply_h r) \<longleftrightarrow>
     (\<exists>k q V. kernel_h r = Exact k q \<and> show_fmt (fmt_h r) (rl q) = Some V) \<or> (\<exists>k. kernel_h r = Fixed k)"

Home.thy: reply_h_states_digits:
  assumes "kernel_h r = Exact k q" "show_fmt (fmt_h r) (rl q) = Some V"
  shows "\<exists>d. num_dec_r (fmt_h r) (rl q) = Some d \<and> V = layout (fmt_h r) (rl q) d \<and>
             \<bar>dec_val d - rl q\<bar> \<le> fmt_err_r (fmt_h r) (rl q)"

Home.thy: reply_h_withheld:
  assumes "kernel_h r = Decline d w"
  shows "\<not> answered (reply_h r) \<and> response (reply_h r) = decline_text d w"

Hvac.thy: hvac_exact_sound:
  assumes "kernel_v r = Exact k q"
  shows "pre_v r = None \<and> miss_v r = None \<and> post_v r = None \<and> k = kd_v r \<and> q = vl_v r"

Hvac.thy: hvac_underspecified:
  "kernel_v r = Decline D_under w \<longleftrightarrow> pre_v r = None \<and> miss_v r = Some w"

Hvac.thy: hvac_sizing:
  "kernel_v VSizing = Decline D_sizing w \<longleftrightarrow> pre_v VSizing = Some (D_sizing, w)"

Hvac.thy: hvac_sizing_always_declined:
  "\<exists>w. kernel_v VSizing = Decline D_sizing w"

Hvac.thy: tons_law:
  assumes "kernel_v (VTons b) = Exact k q"
  shows "k = STR ''tons'' \<and> q * 12000 = b"

Hvac.thy: btuh_law:
  assumes "kernel_v (VBtuh t) = Exact k q"
  shows "k = STR ''btuh'' \<and> q = t * 12000"

Hvac.thy: ach_law:
  assumes "kernel_v (VAch (Some c) (Some v)) = Exact k q"
  shows "k = STR ''ach'' \<and> 0 < v \<and> q * v = 60 * c"

Hvac.thy: cfm_law:
  assumes "kernel_v (VCfm (Some a) (Some v)) = Exact k q"
  shows "k = STR ''cfm_needed'' \<and> 0 < v \<and> q * 60 = a * v"

Hvac.thy: sensible_law:
  assumes "kernel_v (VSens c (Some d)) = Exact k q"
  shows "k = STR ''sensible'' \<and> q * 100 = 108 * c * d"

Hvac.thy: conduction_law:
  assumes "kernel_v (VCond (Some a) r (Some d)) = Exact k q"
  shows "k = STR ''conduction'' \<and> 0 < r \<and> q * r = a * dsv d"

Hvac.thy: seasonal_law:
  assumes "kernel_v (VSeasonal (Some a) r h) = Exact k q"
  shows "k = STR ''seasonal'' \<and> 0 < r \<and> q * r = a * h * 24"

Hvac.thy: pair_difference_nonneg: "0 \<le> dsv (DS_pair a b)"

Hvac.thy: reply_v_answered_iff:
  "answered (reply_v r) \<longleftrightarrow> (\<exists>k q V. kernel_v r = Exact k q \<and> show_fmt G4C (rl q) = Some V)"

Hvac.thy: reply_v_states_digits:
  assumes "kernel_v r = Exact k q" "show_fmt G4C (rl q) = Some V"
  shows "\<exists>d. num_dec_r G4C (rl q) = Some d \<and> V = layout G4C (rl q) d \<and>
             \<bar>dec_val d - rl q\<bar> \<le> fmt_err_r G4C (rl q)"

Hvac.thy: reply_v_withheld:
  assumes "kernel_v r = Decline d w"
  shows "\<not> answered (reply_v r) \<and> response (reply_v r) = decline_text d w"

Renewables.thy: ren_exact_sound:
  assumes "kernel_r r = Exact k q"
  shows "pre_r r = None \<and> miss_r r = None \<and> post_r r = None \<and> \<not> pf_r r \<and> k = kd_r r \<and> q = vl_r r"

Renewables.thy: ren_pi_sound:
  assumes "kernel_r r = PiMul k q"
  shows "pre_r r = None \<and> miss_r r = None \<and> post_r r = None \<and> pf_r r \<and> k = kd_r r \<and> q = vl_r r"

Renewables.thy: ren_underspecified:
  "kernel_r r = Decline D_under w \<longleftrightarrow> pre_r r = None \<and> miss_r r = Some w"

Renewables.thy: hydro_law:
  assumes "kernel_r (RHydro q h e) = Exact k p"
  shows "k = STR ''hydro'' \<and> e \<le> 1 \<and> p = 1000 * (981 / 100) * q * h * e"

Renewables.thy: pv_law:
  assumes "kernel_r (RPV a i e) = Exact k p"
  shows "k = STR ''pv_power'' \<and> e \<le> 1 \<and> p = a * irr_val i * e \<and> i \<noteq> Irr_none"

Renewables.thy: capacity_factor_law:
  assumes "kernel_r (RCapF r e h) = Exact k p"
  shows "k = STR ''capacity_factor'' \<and> 0 < r * h \<and> p \<le> 100 \<and> p * (r * h) = 100 * e"

Renewables.thy: annual_energy_law:
  assumes "kernel_r (RAnnual r h c) = Exact k p"
  shows "k = STR ''annual_energy'' \<and> c \<le> 1 \<and> p = r * h * c"

Renewables.thy: wind_ratio_law:
  assumes "kernel_r (RRatio v1 v2) = Exact k p"
  shows "k = STR ''wind_ratio'' \<and> 0 < v1 \<and> p * v1 ^ 3 = v2 ^ 3"

Renewables.thy: wind_power_swept_law:
  assumes "kernel_r (RWind (G_swept a) v rho cp) = Exact k p"
  shows "k = STR ''wind_power'' \<and> (\<forall>c. cp = Some c \<longrightarrow> c \<le> betz) \<and>
         p = rho * v ^ 3 * cpf cp / 2 * a"

Renewables.thy: wind_power_diameter_law:
  assumes "kernel_r (RWind (G_diam d) v rho cp) = PiMul k c"
  shows "k = STR ''wind_power'' \<and> (\<forall>x. cp = Some x \<longrightarrow> x \<le> betz) \<and>
         rl c * pi = 1 / 2 * rl rho * (pi * (rl d / 2) ^ 2) * rl v ^ 3 * rl (cpf cp)"

Renewables.thy: wind_power_radius_law:
  assumes "kernel_r (RWind (G_rad r) v rho cp) = PiMul k c"
  shows "k = STR ''wind_power'' \<and> rl c * pi = 1 / 2 * rl rho * (pi * rl r ^ 2) * rl v ^ 3 * rl (cpf cp)"

Renewables.thy: reply_r_withheld:
  assumes "kernel_r r = Decline d w"
  shows "\<not> answered (reply_r r) \<and> response (reply_r r) = decline_text d w"

Renewables.thy: reply_r_answered_iff:
  "answered (reply_r r) \<longleftrightarrow>
     (\<exists>k q V. kernel_r r = Exact k q \<and> shw_r r q = Some V) \<or> (\<exists>k c s. kernel_r r = PiMul k c \<and> pit_r r c = Some s)"

Renewables.thy: reply_r_power_units:
  assumes "pw_show en x x = Some t"
  shows "\<exists>s i d. pw_scale x x = Some (s, i) \<and> 0 < s \<and> (s = 1 \<or> s \<le> x) \<and> (x < 1000 * s \<or> i = 3) \<and>
         num_dec_r F3C (x / s) = Some d \<and> \<bar>dec_val d - x / s\<bar> \<le> fmt_err_r F3C (x / s)"

Renewables.thy: reply_r_pi_enclosed:
  assumes "pi_bounds c = Some (lo, hi)"
  shows "lo \<le> rl c * pi \<and> rl c * pi \<le> hi"

Iot.thy: iot_exact_sound:
  assumes "kernel_i r = Exact k q"
  shows "pre_i r = None \<and> miss_i r = None \<and> post_i r = None \<and> k = kd_i r \<and> q = vl_i r"

Iot.thy: iot_underspecified:
  "kernel_i r = Decline D_under w \<longleftrightarrow> pre_i r = None \<and> miss_i r = Some w"

Iot.thy: adc_voltage_law:
  assumes "kernel_i (IAdcVolt n (Some v) c) = Exact k q"
  shows "k = STR ''adc_voltage'' \<and> int c < adc_full n \<and> q * of_int (adc_full n) = of_nat c * v"

Iot.thy: adc_lsb_law:
  assumes "kernel_i (IAdcLsb n (Some v)) = Exact k q"
  shows "k = STR ''adc_lsb'' \<and> q * of_int (adc_full n) = v * 1000"

Iot.thy: adc_code_law:
  assumes "kernel_i (IAdcCode n (Some v) x) = Exact k q"
  shows "k = STR ''adc_code'' \<and> 0 < v \<and> x \<le> v \<and> q \<le> x / v * of_int (adc_full n) \<and>
         (x / v * of_int (adc_full n) < q + 1 \<or> q = of_int (adc_full n) - 1)"

Iot.thy: nyquist_law:
  assumes "kernel_i (INyquist f) = Exact k q"
  shows "k = STR ''nyquist'' \<and> q = 2 * f"

Iot.thy: avg_current_law:
  assumes "kernel_i (IAvgCur ia slp d) = Exact k q"
  shows "k = STR ''avg_current'' \<and> d \<le> 1 \<and> q = ia * d + slp * (1 - d)"

Iot.thy: battery_life_law:
  assumes "kernel_i (IBat c ia slp d y) = Exact k q"
  shows "k = STR ''battery_life'' \<and> d \<le> 1 \<and> 0 < avg_cur ia slp d \<and> q * avg_cur ia slp d = c"

Iot.thy: battery_life_const_law:
  assumes "kernel_i (IBatConst c i y) = Exact k q"
  shows "k = STR ''battery_life'' \<and> 0 < i \<and> q * i = c"

Iot.thy: data_rate_law:
  assumes "kernel_i (IDataRate s b ch) = Exact k q"
  shows "k = STR ''data_rate'' \<and> q = s * of_nat b * of_nat ch"

Iot.thy: storage_law:
  assumes "kernel_i (IStorage s b ch) = Exact k q"
  shows "k = STR ''storage_day'' \<and> q * 8 * 1000000 = s * of_nat b * of_nat ch * 86400"

Iot.thy: reply_i_answered_iff:
  "answered (reply_i r) \<longleftrightarrow> (\<exists>k q V. kernel_i r = Exact k q \<and> shw_i r q = Some V)"

Iot.thy: reply_i_states_digits:
  assumes "kernel_i r = Exact k q" "shw_i r q = Some V"
  shows "\<exists>d. num_dec_r (fmt_i r) (rl (if days_i r then q / 24 else q)) = Some d \<and>
             \<bar>dec_val d - rl (if days_i r then q / 24 else q)\<bar> \<le> fmt_err_r (fmt_i r) (rl (if days_i r then q / 24 else q))"

Iot.thy: reply_i_withheld:
  assumes "kernel_i r = Decline d w"
  shows "\<not> answered (reply_i r) \<and> response (reply_i r) = decline_text d w"

Energy_Family.thy: family_declines_withheld:
  assumes "kernel_of r = Decline d w"
  shows "\<not> answered (reply_of r) \<and> response (reply_of r) = decline_text d w"```
