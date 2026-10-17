# Lane S04: electrical, electronics, wiring, optics (handoff, 2026-10-17)

Nine Oracle7 specialists are now one verified HOL kernel exported to SML and compiled into
one 760 KB binary, `var/emoptics/bin/emoptics` (not in git). Files:
`src/extract/emoptics/` ([README](../../src/extract/emoptics/README.md)).

## Result on the shipped panels

Scored with `tools/parity/harness.py --answerer "var/emoptics/bin/emoptics --specialist {id}"`
(right / wrong / valid item withheld / false yes). The lane's `score.py` gives the same counts
and also compares every reply with the shipped organ: 0 disagreements in `--specialist` mode
on all nine.

| Specialist | dev | held-out | Shipped held-out | p50 in binary (budget 50 ms) |
|---|---|---|---|---|
| electrical | 24 / 0 / 0 / 0 | **22 / 0 / 2 / 0** (n=24) | 22 / 0 wrong / 0 fy | 5.2 ms |
| electronics | 111 / 0 / 0 / 0 | **111 / 0 / 0 / 0** | 111 / 0 fy | 0.08 ms |
| electronics-r2 | 111 / 0 / 0 / 0 | **111 / 0 / 0 / 0** | 111 / 0 fy | 0.07 ms |
| wiring | 42 / 0 / 0 / 0 | **45 / 0 / 0 / 0** | 45 / 0 fy | 11.5 ms (24.6 ms round trip) |
| optics | 70 / 0 / 0 / 0 | **55 / 6 / 0 / 0** (n=61) | 55 / 61, 0 fy | 0.15 ms |
| optics-v2 | 68 / 0 / 0 / 0 | **59 / 7 / 0 / 0** (n=66) | 59 / 66, 0 fy | 0.16 ms |
| optics-v3 | 64 / 0 / 0 / 0 | **53 / 0 / 14 / 0** (n=67) | 53 / 67, 0 fy | 0.15 ms |
| optics-v5 | 74 / 0 / 0 / 0 | **51 / 0 / 14 / 0** (n=65) | 51 / 65, 0 wrong, 0 fy | 0.14 ms |
| optics-v5-r2 | 74 / 0 / 0 / 0 | **51 / 0 / 14 / 0** (n=65) | none shipped (verdict file absent) | 0.10 ms |

Each held-out count equals the shipped one. The named misses are the organs' own:
- electrical (withheld): "Transformer with 2000 primary turns and 100 secondary turns carries 1.5 A on the primary. Secondary current?" and the 200/100/12 A variant (the organ needs "primary current").
- optics (6 wrong, "light enters diamond/water from air ... Snell's law", e.g. at 55 degrees reported as total internal reflection) and optics-v2 (7 wrong, "Inside a material of index 1.5 ... going from index 1.5 to index 1.33" reported as a refraction angle): the old organs' known confident-wrong direction defects, reproduced faithfully because each version is scored on its own panel. optics-v2's 7 are fixed by v3 (0 wrong), and optics' 6 by v2.
- optics-v3/v5/v5-r2 (withheld): v3 misses "object 60 cm away, lens focal length 5 cm"; v5 and v5-r2 miss "Critical angle from a refractive index of 1.6 to 1.0?", "At what speed does light travel inside glass of refractive index 1.52?" and "Power in diopters of a 50 cm focal-length lens?" (the organs decline these too).

Family mode (no `--specialist`, order electrical, optics-v5-r2, wiring, electronics-r2): 0 wrong
on every panel; some electronics voltage-drop questions go to wiring first (12 of 111 held-out
withheld), so use `--specialist` for scoring. Binary 760 KB, cold start about 65 ms, wiring is
the slowest specialist (the AWG power law, enclosed at 32 bits).

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Emoptics --session-root src/extract/emoptics --expect 'VERI7VN_EMOPTICS PASS' --timeout 900`
status `passed`, receipt `var/native-scaffold/sessions/d74237667b60e9d2/receipt.json`.
Marker `VERI7VN_EMOPTICS PASS theorems=54 oracles=0`; the self test (17 kernel and reply
checks) must hold. `tables_check.py`: PASS, 28 checks. The sessions are `Veri7vn_Emoptics_Base`
(Approximation only) and `Veri7vn_Emoptics`.

## Theorem statements (verbatim from `src/extract/emoptics/Emoptics.thy`, converted to ASCII operators)

`pre r` is the decline predicate (missing value, impossible input, judgement), `qval` the exact
rational value, `phys` the real-number model (sqrt, pi, powr, sin, arcsin), `kernel` the
executable function.

```
kernel_underspecified: "kernel r = Decline (Underspecified n) <-> missing r = Some n"
kernel_impossible: "kernel r = Decline (Impossible why) <-> reason_of r = Some why"
kernel_judgement: "kernel r = Decline Judgement <-> r = W_Judgement"
kernel_imprecise: assumes "kernel r = Decline Imprecise" shows "pre r = None | pre r = Some Imprecise"
kernel_exact_sound: assumes "kernel r = Exact k q" shows "pre r = None & k = kind_of r & q = qval r & rl q = phys r"
kernel_approx_sound: assumes "kernel r = Approx k d" shows "pre r = None & k = kind_of r & |dec_val d - phys r| <= |phys r| / 1000 + 1 / 1000000000"
kernel_reflect_sound: assumes "kernel r = Reflect d" shows "EXt x y. r = O_Snell (Some t) (Some x) (Some y) & 1 <= x & 1 <= y & 0 <= t & t < 90 & rl x * sin (pi * rl t / 180) > rl y & |dec_val d - rl (x / y) * sin (pi * rl t / 180)| <= |rl (x / y) * sin (pi * rl t / 180)| / 1000 + 1 / 1000000000"
stated_dec_sound: assumes "stated_dec q = Some d" shows "|dec_val d - rl q| <= |rl q| / (2 * 10 ^ (4 - 1))"
reply_withheld_names_decline: "kernel r = Decline w ==> \<not> answered (reply_of r) & reply_kind (reply_of r) = decline_name w"
reply_answered_iff: "answered (reply_of r) <-> (EXk q d. kernel r = Exact k q & stated_dec q = Some d) | (EXk d t. kernel r = Approx k d & approx_text r (value_lit k d) = Some t) | (EXk. kernel r = Verdict k) | (EXd. kernel r = Reflect d)"
reply_states_exact: "kernel r = Exact k q ==> stated_dec q = Some d ==> stated (reply_of r) = Some (value_lit k d)"
hp_kw_value: "kernel (E_HpKw x) = Exact K_hp_kw (x * 7457 / 10000)"
hp_kw_roundtrip: "kernel (E_KwHp (x * 7457 / 10000)) = Exact K_kw_hp x"
transformer_power: assumes "kernel (E_XfmrV np ns vp) = Exact k1 vs" "kernel (E_XfmrI np ns ip) = Exact k2 ys" shows "vs * np = vp * ns & vs * ys = vp * ip"
power_factor_value: assumes "kernel (E_Tri pf (T_Pf p s)) = Exact k f" shows "f * amt vau_scale s = amt pu_scale p"
power_triangle: assumes "0 <= amt pu_scale p" "amt pu_scale p <= amt vau_scale s" shows "phys (E_Tri pf (T_React p s)) ^ 2 + rl (amt pu_scale p) ^ 2 = rl (amt vau_scale s) ^ 2"
wye_line_voltage: "phys (E_Tri pf (T_Wye v)) ^ 2 = 3 * rl v ^ 2"
delta_line_current: "phys (E_Tri pf (T_Delta i)) ^ 2 = 3 * rl i ^ 2"
three_phase_apparent: "phys (E_Tri pf (T_Kva v i)) ^ 2 = 3 * rl (amt vu_scale v * amt au_scale i / 1000) ^ 2"
three_phase_real_is_apparent_times_pf: "phys (E_Tri (Some x) (T_Kw v i)) = phys (E_Tri (Some x) (T_Kva v i)) * rl x"
three_phase_current_inverse: assumes "amt vu_scale v ~= 0" "x ~= 0" shows "phys (E_Tri (Some x) (T_Cur v p)) * sqrt 3 * rl (amt vu_scale v) * rl x = rl (amt pu_scale p * 1000)"
pf_correction_tan: assumes "0 < p1" "p1 <= 1" "0 < p2" "p2 <= 1" shows "phys (E_PfCorr p p1 p2) = rl (amt pu_scale p) * (tan (arccos (rl p1)) - tan (arccos (rl p2)))"
pf_correction_balance: assumes "0 < p1" "p1 <= 1" "0 < p2" "p2 <= 1" shows "rl (amt pu_scale p) * tan (arccos (rl p2)) + phys (E_PfCorr p p1 p2) = rl (amt pu_scale p) * tan (arccos (rl p1))"
pf_over_one: "kernel (E_Tri (Some x) b) = Decline (Impossible R_pf_over) <-> 1 < x"
power_factor_never_assumed: "kernel (E_Tri None (T_Kw v i)) = Decline (Underspecified N_pf_power)" "kernel (E_Tri None (T_Cur v p)) = Decline (Underspecified N_pf_current)"
ohm_law: assumes "kernel (C_Circ res rall (CB_Cur (Some v) (Some r) w)) = Exact k i" "cv r ~= 0" shows "i * cv r = cv v"
power_is_vi: assumes "kernel (C_Circ res rall (CB_Pow (Some v) (Some a) r)) = Exact k y" shows "y = cv v * cv a"
parallel_reciprocal: assumes "kernel (C_Circ res rall (CB_Parallel rs)) = Exact k t" shows "1 / t = sum_list (map (\<lambda>r. 1 / cv r) rs)"
series_sum: assumes "kernel (C_Circ res rall (CB_Series rs)) = Exact k t" shows "t = sum_list (map cv rs)"
divider_ratio: assumes "kernel (C_Circ res rall (CB_Divider vin r1 r2)) = Exact k y" shows "y * (cv r1 + cv r2) = cv vin * cv r2"
rc_time_constant: assumes "kernel (C_Circ res rall (CB_Rc r c)) = Exact k y" shows "y = cv r * cv c"
led_resistor: assumes "kernel (C_Circ res rall (CB_Led vs i)) = Exact k y" shows "y * cv i = lmax (map cv vs) - lmin (map cv vs) & 0 < y"
zero_resistor_declined: assumes "list_ex (\<lambda>r. cv r <= 0) rall" shows "kernel (C_Circ True rall b) = Decline (Impossible R_resistor)"
awg_36: "awg_d 36 = rl (127 / 1000)"
awg_step: "awg_d (n + 39) * 92 = awg_d n"
wire_resistance_area: "phys (W_Res m n None) * phys (W_Area n) = rl (rho m) * 1000 * 1000000"
voltage_drop_is_current_times_loop: "phys (W_Vdrop m (Some n) (Some i) (Some (x, u)) v) = rl i * phys (W_Res m n (Some (2 * (x * lu_scale u), L_m)))"
continuous_eighty_percent: assumes "kernel (W_Continuous b) = Exact k l" shows "5 * l = 4 * b"
single_phase_current: assumes "kernel (W_Cur p v) = Exact k i" shows "i * v = amt pu_scale p * 1000"
vdrop_underspecified: "kernel (W_Vdrop m n i l v) = Decline (Underspecified N_w_vdrop) <-> n = None | i = None | l = None"
photon_energy_wavelength: assumes "kernel (O_EnergyL l) = Exact k e" shows "e * echarge * amt lu_scale l = planck * light_c"
frequency_wavelength: assumes "kernel (O_Frequency l) = Exact k f" shows "f * amt lu_scale l = light_c"
wavelength_frequency: assumes "kernel (O_Wavelength f) = Exact k l" shows "l * amt fu_scale f = light_c"
medium_speed: assumes "kernel (O_Speed (Some n)) = Exact k v" shows "v * n = light_c & 1 <= n"
lens_power: assumes "kernel (O_LensPower (Some l)) = Exact k p" shows "p * amt lu_scale l = 1"
thin_lens_equation: assumes "kernel (O_Image (Some f) (Some d)) = Exact k di" shows "1 / di = 1 / f - 1 / d"
magnification_ratio: assumes "kernel (O_Mag (Some f) (Some d)) = Exact k m" "kernel (O_Image (Some f) (Some d)) = Exact k' di" shows "m * d = - di"
object_at_focus: "kernel (O_Image (Some f) (Some f)) = Verdict K_at_focus"
no_critical_angle: assumes "1 <= x" "1 <= y" shows "kernel (O_Crit (Some x) (Some y)) = Verdict K_no_critical <-> x <= y"
snell_law: assumes "kernel (O_Snell (Some t) (Some x) (Some y)) = Approx k d" shows "rl x * sin (pi * rl t / 180) = rl y * sin (pi * phys (O_Snell (Some t) (Some x) (Some y)) / 180)"
critical_angle_law: assumes "kernel (O_Crit (Some x) (Some y)) = Approx k d" shows "rl x * sin (pi * phys (O_Crit (Some x) (Some y)) / 180) = rl y"
```

## Untrusted parts and limits

- `recognizer.sml` ports each organ's regexes by hand; it decides which request a question
  becomes. `main.sml` frames JSON and writes the ohm and micro signs.
- Not proved: that the recognizer reads the question the way the organ does (checked on the
  panels and by `score.py`'s organ comparison, 0 disagreements per specialist), and the text
  layout of numbers (`render_dec`, checked by the self test and the panels).
- Differences from the organs, all declines in place of a crash: a zero turn count, zero object
  distance or zero focal length is declined as impossible.
- `electronics-r2` and `electronics` share one organ (byte-identical files); optics versions 1,
  2, 3, 5, 5-r2 are separate recognizer modes (v4 is not a shipped manifest).
- Reply wording is ASCII (`sqrt3`, `deg`, `x`) where the organs print Unicode, except the ohm and
  micro signs the electronics scorer reads; every scorer passes.
- Remaining: family-mode ordering (electronics voltage-drop questions), and a cleaner handling of
  rounding ties (decimals round half up on the exact value; the organs round a binary float).

## Reproduction

See the README commands. Scratch and logs: `var/emoptics/`.
