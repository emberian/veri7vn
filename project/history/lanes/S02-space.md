# Lane S02-space: orbits, planetary, spacecraft, spacecomms, astronomy x4 (handoff, 2026-10-17)

Eight Oracle7 specialists are one verified HOL kernel (`src/extract/space/`, [README](../../src/extract/space/README.md)), exported to SML and compiled to one 719 KB binary `var/space/bin/space` (not committed). Session `Veri7vn_Space` (base `Veri7vn_Space_Base`), marker `VERI7VN_SPACE PASS`, check-native status `passed`, receipt `var/native-scaffold/sessions/17dc596567f0c27b/receipt.json`.

## Numbers (own scorer per specialist, `tools/parity/harness.py --answerer "var/space/bin/space --specialist {id}" --split both`)

right / wrong / valid item withheld / false yes. The shipped number is Oracle7's own held-out verdict. `score.py` also compares every reply with the organ itself: 0 disagreements on all eight panels.

| Specialist | dev | heldout | shipped heldout | p50 in binary (budget 50 ms) |
|---|---|---|---|---|
| orbits | 35/0/0/0 | **35/0/0/0** | 35 | 20 ms (loaded box; 9 ms earlier) |
| planetary | 18/0/0/0 | **18/0/0/0** | 16, 2 false yes | 0.20 ms |
| spacecraft | 21/0/0/0 | **14/0/7/0** | 14 | 0.20 ms |
| spacecomms | 32/0/0/0 | **36/0/0/0** | 36 | 0.11 ms |
| astronomy | 60/0/0/0 | **68/13/0/0** | 68 | 0.06 ms |
| astronomy-v2 | 138/0/0/0 | **130/8/0/0** | 130 | 0.09 ms |
| astronomy-v3 | 138/0/0/0 | **137/0/1/0** | 137 | 0.09 ms |
| astronomy-v3-r2 | 138/0/0/0 | **137/0/1/0** | none shipped (manifest has no verdict) | 0.11 ms |

Named misses are the organs' own, reproduced: spacecraft held-out, 7 questions the organ returns None for (three "Starting from N kg total mass, what propellant mass does a V m/s maneuver need at Isp S s?", two "Convert a specific impulse of S s to effective exhaust velocity.", two "Burn time for N kg of propellant in an engine of F kN at Isp S s?"). astronomy v1 and v2 wrong answers are the defects v2 and v3 were written to fix (Earth used as a unit; ratio direction); they are kept so the number matches. astronomy-v3 held-out withheld 1 (same item as the organ). Planetary's two shipped false yes (Pluto/Mars-from-Sun) are not reproduced: the binary withholds them with `--specialist planetary`.

Binary 719,208 bytes, cold start about 65 ms on a quiet box (162 ms measured under load), `harness` decision `INCOMPLETE` (no head answerer run).

## For fusion: `planetary`

Typed requests (module `Space`, constructors exported): `PWeightE M R k` (weight in N of a k kg object on a body of M Earth masses and R Earth radii: k * 9.81 * M / R^2, kind `weight`), `PGravity b`, `PEscape b`, `POrbV b`, `PDensity b` with `b = Pb_earth M R` or `Pb_si M_kg R lenu`. Fusion's "planet weight" operation is `PWeightE`; call `Space.reply_of`, read `Space.stated`. Declines when M or R is not positive (`Impossible R_nonpositive`).

## Main theorem statements (verbatim, `Space.thy`)

```
kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None ∧ ¬ nosync r ∧ reason_of r = None ∧ k = kind_of r ∧ q = qval r ∧
         rl q = phys r ∧ ¬ is_approx r ∧ ¬ is_fact r"
kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None ∧ ¬ nosync r ∧ reason_of r = None ∧ k = kind_of r ∧ is_approx r ∧
         |dec_val d - phys r| ≤ pow10 (snd d) / 2 + |phys r| / 1000000 + 1 / 1000000000"
kernel_fact_sound:
  assumes "kernel r = Fact k c"
  shows "∃b p. r = AProp b p ∧ k = prop_kind p ∧ c = sheet b p ∧ ¬ is_unknown c"
kernel_underspecified: "kernel r = Decline (Underspecified w) ⟷ missing r = Some w"
kernel_nosync: "kernel r = Decline NoSync ⟷ missing r = None ∧ nosync r"
kernel_impossible: "kernel r = Decline (Impossible w) ⟷ missing r = None ∧ ¬ nosync r ∧ reason_of r = Some w"
kernel_unknown / kernel_novalue / kernel_imprecise (numeric decline only on enclosed kinds)
gravity_model:  pgrav b * pr_i b ^ 2 = pconst b * pm_i b
escape_model:   (1000 * phys (PEscape b)) ^ 2 * rl (prad b) = rl (2 * grav_G * pmass b)
density_model:  phys (PDensity b) * (4/3 * pi * rl (prad b) ^ 3) * 1000 = rl (pmass b)
orbit_period_model: (60 * phys (OPeriod ob oa)) ^ 2 * rl (mu (obd ob)) = 4 * pi ^ 2 * rl (rad1 ob oa ^ 3)
hohmann_time_model: (3600 * phys (OHohTime ob p)) ^ 2 * rl (mu (obd ob)) = pi ^ 2 * rl (((hr1 ob p + hr2 ob p) / 2) ^ 3)
hohmann_vis_viva:   (sqrt (rl (m / r1)) * sqrt (rl (2 * r2 / (r1 + r2)))) ^ 2 = rl (m * (2 / r1 - 1 / ((r1 + r2) / 2)))
sync_model:     (phys (OSync (Some b)) + rl (brad b)) ^ 3 * (4 * pi ^ 2) = rl (mu b * t ^ 2)   (sidereal b = Some t)
tsiolkovsky_model: exp (phys (SDeltaV v M0 u0 MF uf) / rl (ve_of v)) * rl (MF * massf uf) = rl (M0 * massf u0)
fspl_model:     10 powr ((phys (CFspl d f) - rl fspl_const) / 20) = rl (dd d) * rl (ff f)
light_time_model, transfer_model, bits_in_flight_model, twr_model, mass_flow_model, burn_time_model,
propellant_initial_model, propellant_final_model, weight_elsewhere_model, sunlight_model,
ratio_model, years_model, property_model: see Space.thy
```
`Space_Export.thy` prints `VERI7VN_SPACE PASS theorems=N oracles=0` only if `Thm_Deps.all_oracles` of the listed theorems is empty and the compiled `self_test` holds.

## Untrusted, limits
Recognizer and framing (hand-ported regexes; disclosed differences in the header of `recognizer.sml`). Orbits and the path loss use interval arithmetic at 80 bits; precision 53 left every 32 GHz path-loss item imprecise (fixed by one Ln of the product and 80 bits; cause of the 53-bit failure not isolated). The Moon's astronomy "distance" text uses an ASCII form. Numbers are printed in ASCII (no unicode superscripts), which the shipped scorers accept. Family mode (no argument) is not scored; order planetary, spacecraft, orbits, spacecomms, astronomy-v3-r2 lets orbits take "escape velocity of <planet>" before astronomy, so use `--specialist` for parity. Fusion should call the HOL `reply_of` directly rather than the family order.

## Reproduce
```
python3 tools/dev/check-native --session Veri7vn_Space --session-root src/extract/space --expect 'VERI7VN_SPACE PASS' --timeout 1800
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/space/tables_check.py   # PASS, 23 checks
sh src/extract/space/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/space/score.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/space/bin/space --specialist {id}" --specialist orbits,planetary,spacecraft,spacecomms,astronomy,astronomy-v2,astronomy-v3,astronomy-v3-r2 --split both --out var/space/parity
```
