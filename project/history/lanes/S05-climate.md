# Lane S05-climate: carboncapture, airquality, climate, carbonmat, coldchain, coldchain-v2 (handoff, 2026-10-17)

One verified HOL kernel (`src/extract/climate/`, [README](../../src/extract/climate/README.md)),
session `Veri7vn_Climate` on `Veri7vn_Climate_Base`. Marker `VERI7VN_CLIMATE PASS theorems=79 oracles=0`
(check-native status `passed`, receipt `var/native-scaffold/sessions/a189cc5b3e795fb9/receipt.json`).
Binary `var/climate/bin/climate`, 619,816 bytes, cold start about 42 ms, MLton from Isabelle2026-RC1.

## For fusion (lane H): carboncapture

The kinds `c_to_co2`, `co2_to_c`, `fuel_co2`, `co2_per_mile`, `captured`, `capture_energy` are the typed
requests `Req_cc (Cc_c_to_co2 m unit | Cc_co2_to_c m unit | Cc_fuel_co2 fuel fuel_word gallons |
Cc_co2_per_mile fuel fuel_word mpg | Cc_captured m unit rate_percent | Cc_capture_energy m unit rate_percent
intensity eunit)`. Fusion's gasoline step is `Cc_fuel_co2 F_gasoline (STR 'gasoline') gallons`; its value is
`gallons * 8887 / 1000` kg, exact (theorem `fuel_co2_model`), stated to 4 significant digits as the organ does.
Lane G's `FuelCO2` is a different, NCV-based fuel table; the EPA tailpipe factors live here.
`Climate.reply_of`/`kernel` are exported (`Climate_Export.thy`); the string fields only echo the question's words.

## Result (answered right / wrong / withheld on valid / false yes)

| Specialist | Split | n | `--specialist ID` | Shipped held-out | p50 (budget 50 ms) |
|---|---|---|---|---|---|
| carboncapture | dev / heldout | 14 / 14 | 14/0/0/0 / 14/0/0/0 | 14, 0 fy | 0.25 ms |
| airquality | dev / heldout | 38 / 38 | 38/0/0/0 / 30/0/8/0 | 30, 0 fy | 0.13 ms |
| climate | dev / heldout | 24 / 24 | 24/0/0/0 / 24/0/0/0 | 24, 0 fy | 9 ms |
| carbonmat | dev / heldout | 17 / 17 | 17/0/0/0 / 17/0/0/0 | 17, 0 fy | 0.08 ms |
| coldchain | dev / heldout | 30 / 30 | 30/0/0/0 / 18/0/12/0 | 18, 0 fy | 0.08 ms |
| coldchain-v2 | dev / heldout | 30 / 30 | 30/0/0/0 / 29/0/1/0 | 29, 0 fy | 0.08 ms |

Named misses are the shipped organs' own misses (organ disagreements: 0 in specialist mode on every panel):
- airquality held-out, 8: the four "CO measured at X ppm over 8 hours" and four "Nitrogen dioxide reads X ppb" items (the organ's reading regex does not take them).
- coldchain held-out, 12: free word order cooling ("Rice went from 135 F down to 70 F over 3 hours"), "sandwiches sitting out", "hamburgers".
- coldchain-v2 held-out, 1: "After reaching 70 F, the rice took 3.5 hours to cool to 41 F." (the organ withholds it too).
In family mode (no argument, and what `tools/parity/harness.py` runs) coldchain-v2 comes first, so the
coldchain panel scores 30/30 there (the harness lines show coldchain heldout ok=30).
climate p50 is 9 ms because logarithm/root enclosures run in the binary; 0.2 ms for the rest.

## Theorem statements (verbatim, `src/extract/climate/Climate.thy`)

```
theorem cc_kernel_sound:
  assumes "cc_kernel r = Exact k q"
  shows "cc_impossible r = None \<and> k = cc_kind r \<and> q = cc_val r"

theorem captured_model:
  assumes "cc_kernel (Cc_captured m u c) = Exact k q"
  shows "k = K_captured \<and> q * 100 = m * c \<and> c \<le> 100 \<and> (0 \<le> m \<and> 0 \<le> c \<longrightarrow> 0 \<le> q \<and> q \<le> m)"

theorem co2_per_mile_model:
  assumes "cc_kernel (Cc_co2_per_mile f n mpg) = Exact k q"
  shows "k = K_co2_per_mile \<and> mpg \<noteq> 0 \<and> q * mpg = ef f"

theorem aq_single_sound:
  assumes "aq_kernel (Aq_index h [Reading p c u]) = Index k a q"
  shows "k = K_aqi \<and> q = p \<and> \<not> (h \<and> is_pm p) \<and> \<not> (is_pm p \<and> (u = Au_ppm \<or> u = Au_ppb)) \<and>
         sub_index p (trunc_q (aq_conc p u c) (tdig p)) = Some a"

theorem aq_overall_sound:
  assumes "aq_kernel (Aq_index h rs) = Index K_overall a q"
  shows "\<exists>ss. aq_subs h rs = Inr ss \<and> 2 \<le> length ss \<and>
           (\<exists>s \<in> set ss. sub_pol s = q \<and> sub_aqi s = a) \<and> (\<forall>s \<in> set ss. sub_aqi s \<le> a)"

theorem aq_category_sound:
  assumes "aq_kernel (Aq_category a n) = Category c"
  shows "0 \<le> a \<and> a \<le> 500 \<and> c = cat_of a"

theorem sub_index_interpolation:
  assumes "sub_index p c = Some a"
  shows "\<exists>r \<in> set (rows p). in_row c r \<and> of_int a \<le> interp r c + 1 / 2 \<and> interp r c + 1 / 2 < of_int a + 1"

theorem cl_exact_sound:
  assumes "cl_kernel r = Exact k q"
  shows "cl_missing r = None \<and> cl_impossible r = None \<and> k = sp_kind (cl_spec r) \<and>
         sp_exact (cl_spec r) = Some q \<and> sp_phys (cl_spec r) = rl q"

theorem cl_approx_sound:
  assumes "cl_kernel r = Approx k d"
  shows "cl_missing r = None \<and> cl_impossible r = None \<and> k = sp_kind (cl_spec r) \<and>
         sp_exact (cl_spec r) = None \<and> (snd d = -3 \<or> snd d = 0) \<and>
         \<bar>dec_val d - sp_phys (cl_spec r)\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"

theorem forcing_model:
  assumes "0 < c0" "0 < c"
  shows "exp (sp_phys (Sp_forcing c0 c) / rl forcing_coeff) = rl c / rl c0"

theorem warming_ecs_model:
  assumes "0 < c0" "0 < c" "e \<noteq> 0"
  shows "exp (sp_phys (Sp_warming_ecs e c0 c) * ln 2 / rl e) = rl c / rl c0"

theorem effective_temperature_model:
  assumes "0 \<le> s" "0 \<le> a" "a \<le> 1"
  shows "sp_phys (Sp_teff s a) ^ 4 * (4 * rl sigma) = rl s * (1 - rl a)"

theorem cm_exact_sound:
  assumes "cm_kernel r = Exact k q"
  shows "cm_impossible r = None \<and> k = cm_kind r \<and> cm_exact r = Some q \<and> cm_phys r = rl q"

theorem cm_approx_sound:
  assumes "cm_kernel r = Approx k d"
  shows "cm_impossible r = None \<and> k = cm_kind r \<and> cm_exact r = None \<and> (snd d = -4 \<or> snd d = 0) \<and>
         \<bar>dec_val d - cm_phys r\<bar> \<le> pow10 (snd d) / 2 + 1 / 1000000000"

theorem cnt_circumference:
  "pi * cm_phys (Cm_diameter n m) = rl lat_a * sqrt (of_int (circ2 n m))"

theorem cnt_type_metallic:
  assumes "cm_kernel (Cm_type n m) = Verdict k v"
  shows "chiral_ok n m \<and> (v \<longleftrightarrow> (\<exists>j. n - m = 3 * j))"

theorem cnt_kind_classes:
  assumes "cm_kernel (Cm_kind n m) = Tube_kind t"
  shows "chiral_ok n m \<and> (t = T_armchair \<longleftrightarrow> n = m) \<and> (t = T_zigzag \<longleftrightarrow> m = 0 \<and> n \<noteq> m)"

theorem graphene_layers_model:
  assumes "cm_kernel (Cm_layers t ang) = Exact k q"
  shows "k = K_graphene_layers \<and> q * layer_sp = thickness t ang"

theorem graphene_areal_mass:
  "(rl areal_k / sqrt 3) * (sqrt 3 / 2 * rl lat_a ^ 2 / 10 ^ 18) =
   rl (2 * (12011 / 1000) * 1000 / (602214076 * 10 ^ 15))"

theorem cooling_verdict:
  assumes "cd_kernel (Cd_cool a b d) = Verdict k ok"
  shows "k = K_cooling_check \<and> (\<exists>lm. cool_limit (f_of a) (f_of b) = Some lm \<and> (ok \<longleftrightarrow> hours d \<le> lm))"

theorem cool_stage1:
  assumes "269 / 2 \<le> a" "\<bar>b - 70\<bar> \<le> 1 / 2"
  shows "cool_limit a b = Some 2"

theorem cooling_not_a_stage:
  "cd_kernel (Cd_cool a b d) = Decline w \<longleftrightarrow> cool_limit (f_of a) (f_of b) = None \<and> w = Not_taken"

theorem date_marking:
  "wd_idx (last_day d) = (wd_idx d + 6) mod 7"

theorem tphc_limit:
  "cd_kernel (Cd_tphc (Some h)) = Verdict K_tphc (h \<le> 4)"
  "cd_kernel (Cd_tphc None) = Exact K_tphc_rule 4"

theorem reply_answered_iff: "answered (reply_of r) \<longleftrightarrow> (\<forall>w. kernel r \<noteq> Decline w)"

theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
```

Declines are exactly the organ predicates: capture rate over 100 (`capture_rate_over_100`), missing GWP /
sensitivity (`co2e_needs_gwp`, `warming_needs_sensitivity`), albedo outside 0-1, `n < m` chirality
(`cnt_chirality_declined`), AQI out of 0-500, hourly PM, 8-hour ozone above 0.200 ppm, 1-hour SO2 above
304 ppb. Determinism: `kernel_deterministic` (a function; stated, near-trivial).

## Untrusted and limits

- `regex.sml` (lane G's fixed copy), `recognizer.sml`, `main.sml`; `tables_check.py` is a check, not a proof
  (68 checks; AQI breakpoints, constants and Food Code limits against the organs).
- Decimal layout of reply text (`g_text`, `fixed_lit`) is checked by the self test and panels, not proved; the
  rounded values carry a proved half-unit bound (`g_dec_sound`, `to_fixed_sound`).
- Cooling-stage tolerance of half a degree and the Food Code limits are the organ's rules, not independent facts.
- Not modelled: the organs' float artefacts on exact decimal ties (as lane G `round_tie_up`); a non-ASCII `\b`
  (micro sign, degree) is dropped in the port.
- `coldchain` (v1) is only distinguished from v2 by `--specialist coldchain` (v1 word order, no hamburgers plural, no numbers rule).

## Reproduce

See the README. Check-native: one build, about 1 to 2 minutes with the base session cached.
