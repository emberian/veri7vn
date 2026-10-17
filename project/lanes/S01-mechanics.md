# Lane S01: the mechanics family (handoff, 2026-10-17)

Nine shipped Oracle7 specialists (`physics`, `physics-r2`, `physics-r3`, `mechanisms`, `mechanisms-v2`,
`bodies-v2`, `sports`, `fleet`, `fluids-r2`) are now one verified HOL kernel, exported to Standard ML and
compiled with the MLton inside Isabelle into one 654 KB binary that speaks the answerer contract.
Files: `src/extract/mechanics/` ([README](../../src/extract/mechanics/README.md)).

## Result on the shipped panels

Right / wrong / valid item withheld / false yes, from lane A's harness and the lane's `score.py` (same counts).
`--specialist ID` mode; the family mode (no argument) gives the same counts except where noted.

| Specialist | dev | held-out | Shipped held-out | p50 in binary vs budget |
|---|---|---|---|---|
| physics | 123 / 0 / 0 / 0 | **123 / 0 / 0 / 0** | 123 right, 0 fy | 0.21 ms vs 50 ms |
| physics-r2 | 123 / 0 / 0 / 0 | **123 / 0 / 0 / 0** | 123 right, 0 fy | 0.21 ms vs 50 ms |
| physics-r3 | 123 / 0 / 0 / 0 | **123 / 0 / 0 / 0** | no verdict file shipped | 0.25 ms vs 50 ms |
| mechanisms | 54 / 0 / 0 / 0 | **57 / 0 / 7 / 0** of 64 | 57 right, 0 fy | 0.09 ms vs 50 ms |
| mechanisms-v2 | 63 / 0 / 0 / 0 | **55 / 0 / 0 / 0** | 55 right, 0 wrong, 0 fy | 0.19 ms vs 50 ms |
| bodies-v2 | 38 / 0 / 0 / 0 | **38 / 0 / 0 / 0** | 38 right, 0 wrong, 0 fy | 3.2 ms vs 600 ms |
| sports | 19 / 0 / 0 / 0 | **19 / 0 / 0 / 0** | 19 right, 0 wrong, 0 fy | 0.15 ms vs 50 ms |
| fleet | 54 / 0 / 0 / 0 | **54 / 0 / 0 / 0** | 54 right, 0 fy | 0.11 ms vs 50 ms |
| fluids-r2 | 34 / 0 / 0 / 0 | **34 / 0 / 0 / 0** | 34 right, 0 wrong, 0 fy (inherited) | 0.12 ms vs 50 ms |

Named misses: `mechanisms` held-out, seven items of the form "Find the torque when a force of N N is applied to a
X m lever." (120/0.25, 50/0.25, 80/0.5, 200/0.5, 200/0.2, 200/0.3, 80/0.2). The shipped v1 organ misses the same seven
(it reads "lever" as the lever branch and declines for want of arms); `mechanisms-v2` fixes them and answers all 55 of its
own panel. The miss is faithful, not a fault of the lift.

Organ comparison (`score.py`): on every panel question in `--specialist` mode every reply agrees with the shipped organ
(same status, kind, value within the scorer's tolerance): 0 disagreements for all nine. In family mode the `mechanisms`
(v1) panel shows 11 disagreements, all items where the family's `mechanisms-v2` answers what v1 declines.

Harness verdicts: `var/mechanics/parity/` (per manifest) and `var/mechanics/parity-family/`. Decision is `INCOMPLETE`
only because no head answerer was run (rules 1 and 2). Stays in lane: 0 of 924 core questions taken for every
specialist, in both modes (cap 9). Self: no identity question taken. Budget holds.
Binary `var/mechanics/bin/mechanics` 654,328 bytes (arm64 macOS), not committed; cold start 26 to 33 ms over 5 runs
(the family tables are built at start).

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Mechanics --session-root src/extract/mechanics --expect 'VERI7VN_MECHANICS PASS' --timeout 600`
status `passed`. Receipt `var/native-scaffold/sessions/478536f37e66eb3e/receipt.json`, attempt
`.../attempts/ad98f38022f74499b2ffb24e542ddc62/receipt.json`. Session build 1 min 55 s with the base session cached.
The ML block in `Mechanics_Export.thy` prints the marker only after `Thm_Deps.all_oracles` is empty for the 64 theorems
below and the compiled `self_test` holds. Sessions: `Veri7vn_Mechanics_Base` (`base/`, loads Approximation) and
`Veri7vn_Mechanics`.
Table transcription: `python3 src/extract/mechanics/tables_check.py` PASS, 44 checks (fluid and solid tables and recognizer
orders, body gravities and order, fleet constants, unit scales, and each formula literal the organs only write inline).

## Theorem statements (from `src/extract/mechanics/Mechanics.thy` and `Mech_Num.thy`, ASCII-fied operators)

The model: `qval` is the exact rational value of a request; `phys` is the real model (`sqrt`, `pi`, `sin`) for the six
real-valued kinds (`is_real`) and `rl (qval r)` otherwise; `missing` is the underspecified predicate, `impossible` the
impossible predicate; `kernel` is the executable function; `dec_val (m, e) = m * 10^e`.

```
kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None & ~ impossible r & k = kind_of r & q = qval r & ~ is_real r &
  ~ sinks r & rl q = phys r"
kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None & ~ impossible r & is_real r & k = kind_of r &
  |dec_val d - phys r| <= |phys r| / 1000 + 1 / 1000000000"
kernel_underspecified:
  "kernel r = Decline (Underspecified w) <-> missing r = Some w"
kernel_impossible:
  "(EXwhy. kernel r = Decline (Impossible why)) <-> missing r = None & impossible r"
kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None & ~ impossible r & is_real r"
reason_of_exact:
  "reason_of r ~= None <-> impossible r"
round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "|dec_val d - x| <= |x| / (2 * 10 ^ (p - 1))"
to_dec_sound:
  assumes x: "x in\<^sub>r X" and d: "to_dec X = Some d"
  shows "|dec_val d - x| <= |x| / 1000 + 1 / 1000000000"
stated_dec_sound:
  assumes "stated_dec k q = Some d"
  shows "|dec_val d - rl q| <= fmt_err (fmt_of k) (rl q)"
round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"
kinetic_energy:
  assumes "kernel (PhKE (Some m) (Some v)) = Exact c y"
  shows "c = K_ke & y = m * v ^ 2 / 2"
potential_energy:
  assumes "kernel (PhPE (Some m) (Some h)) = Exact c y"
  shows "c = K_pe & y = m * g0 * h"
momentum_def:
  assumes "kernel (PhMomentum (Some m) (Some v)) = Exact c y"
  shows "c = K_momentum & y = m * v"
weight_on_earth:
  assumes "kernel (PhWeight m) = Exact c y"
  shows "c = K_weight & y = m * g0"
newton_force:
  assumes "kernel (PhForce (Some m) (Some a)) = Exact c y"
  shows "c = K_force & y = m * a"
work_def:
  assumes "kernel (PhWork f d) = Exact c y"
  shows "c = K_work & y = f * d"
power_def:
  assumes "kernel (PhPower e t) = Exact c y"
  shows "c = K_power & t ~= 0 & y * t = e"
final_velocity_def:
  assumes "kernel (PhFinalV (Some a) (Some t) u rest) = Exact c y"
  shows "c = K_final_velocity & (u = None --> rest) & y = or0 u + a * t"
distance_def:
  assumes "kernel (PhDistance a t u rest) = Exact c y"
  shows "c = K_distance & (u = None --> rest) & y = or0 u * t + a * t ^ 2 / 2"
impact_model:
  assumes "0 <= h"
  shows "0 <= phys (PhImpact h) & phys (PhImpact h) ^ 2 = rl (2 * g0 * h)"
fall_model:
  assumes "0 <= h"
  shows "0 <= phys (PhFall h) & phys (PhFall h) ^ 2 * rl g0 = rl (2 * h)"
range_model:
  "phys (PhRange (Some v) (Some t)) * rl g0 = rl (v ^ 2) * sin (rl (2 * t / 180) * pi)"
body_weight:
  assumes "kernel (BdWeight g (Some m)) = Exact c y"
  shows "c = K_weight & 0 < g_of g & y = m * g_of g"
body_fall_model:
  assumes "0 < g_of g" "0 <= h"
  shows "0 <= phys (BdFall g (Some h)) & phys (BdFall g (Some h)) ^ 2 * rl (g_of g) = rl (2 * h)"
body_impact_model:
  assumes "0 < g_of g" "0 <= h"
  shows "0 <= phys (BdImpact g (Some h)) & phys (BdImpact g (Some h)) ^ 2 = rl (2 * g_of g * h)"
pendulum_model:
  assumes "0 < g_of g" "0 <= l"
  shows "0 <= phys (BdPendulum g (Some l)) &
  phys (BdPendulum g (Some l)) ^ 2 * rl (g_of g) = 4 * pi ^ 2 * rl l"
gear_ratio_def:
  assumes "kernel (McGearRatio a b) = Exact c y"
  shows "c = K_gear_ratio & a ~= 0 & y * a = b"
gear_speed_def:
  assumes "kernel (McGearSpeed n a b) = Exact c y"
  shows "c = K_gear_speed & a ~= 0 & b ~= 0 & y * b = n * a"
gear_torque_def:
  assumes "kernel (McGearTorque t a b) = Exact c y"
  shows "c = K_gear_torque & a ~= 0 & y * a = t * b"
belt_speed_def:
  assumes "kernel (McBeltSpeed n d1 d2) = Exact c y"
  shows "c = K_belt_speed & d2 ~= 0 & y * d2 = n * d1"
pulley_ma_def:
  assumes "kernel (McPulleyMA n) = Exact c y"
  shows "c = K_pulley_ma & y = n"
pulley_effort_def:
  assumes "kernel (McPulleyEffort n ld) = Exact c y"
  shows "c = K_pulley_effort & n ~= 0 & y * n = load_n ld"
lever_ma_def:
  assumes "kernel (McLeverMA e l) = Exact c y"
  shows "c = K_lever_ma & l ~= 0 & y * l = e"
lever_effort_def:
  assumes "kernel (McLeverEffort e l (Some ld)) = Exact c y"
  shows "c = K_lever_effort & e ~= 0 & y * e = load_n ld * l"
incline_ma_def:
  assumes "kernel (McInclineMA l h) = Exact c y"
  shows "c = K_incline_ma & 0 < h & h <= l & y * h = l"
torque_def:
  assumes "kernel (McTorque f r u) = Exact c y"
  shows "c = K_torque & y = f * r * len_scale u"
shaft_power_model:
  "phys (McShaftPower n t) * 60 = 2 * pi * rl (n * t)"
torque_angle_bound:
  "|phys (McTorqueAngle f r u a)| <= |rl (f * r * len_scale u)|"
passer_rating_def:
  assumes "kernel (SpPasser c a y t i) = Exact k res"
  shows "k = K_passer_rating & 0 < a & 0 <= res & res <= 475 / 3 &
  res = (cl_rating ((c / a - 3 / 10) * 5) + cl_rating ((y / a - 3) / 4) + cl_rating (t / a * 20)
  + cl_rating (19 / 8 - i / a * 25)) / 6 * 100"
true_shooting_def:
  assumes "kernel (SpTrueShooting p fga fta) = Exact c y"
  shows "c = K_ts_pct & 0 < 2 * (fga + 11 / 25 * fta) & y = p / (2 * (fga + 11 / 25 * fta)) * 100"
era_def:
  assumes "kernel (SpEra w f er) = Exact c y"
  shows "c = K_era & f < 3 & 0 < w + f / 3 & y * (w + f / 3) = 9 * er"
whip_def:
  assumes "kernel (SpWhip w f bb h) = Exact c y"
  shows "c = K_whip & f < 3 & 0 < w + f / 3 & y * (w + f / 3) = bb + h"
batting_average_def:
  assumes "kernel (SpAvg h ab) = Exact c y"
  shows "c = K_avg & 0 < ab & y * ab = h"
on_base_def:
  assumes "kernel (SpObp h bb hbp sf ab) = Exact c y"
  shows "c = K_obp & 0 < ab & y = (h + bb + hbp) / (ab + bb + hbp + sf)"
slugging_def:
  assumes "kernel (SpSlg s1 h s2 s3 hr ab) = Exact c y"
  shows "c = K_slg & 0 < ab & y * ab = singles_of s1 h s2 s3 hr + 2 * s2 + 3 * s3 + 4 * hr"
games_behind_def:
  assumes "kernel (SpGamesBehind wa la wb lb) = Exact c y"
  shows "c = K_games_behind & 0 <= y & y * 2 = |(wa - wb) + (lb - la)|"
win_pct_def:
  assumes "kernel (SpWinPct w l t) = Exact c y"
  shows "c = K_win_pct & 0 < w + l + t & y * (w + l + t) = w + t / 2"
braking_def:
  assumes "kernel (FvBraking (Some v) (Some mu)) = Exact c y"
  shows "c = K_braking & 0 < mu & y * (2 * mu * g0) = spd v ^ 2"
stopping_def:
  assumes "kernel (FvStopping (Some v) (Some mu) (Some rt)) = Exact c y"
  shows "c = K_stopping & 0 < mu & y = spd v * rt + spd v ^ 2 / (2 * mu * g0)"
to_lpk_def:
  assumes "kernel (FvToLpk uk x) = Exact c y"
  shows "c = K_to_lpk & x ~= 0 & y * x = (if uk then lpk_uk else lpk_us)"
to_mpg_def:
  assumes "kernel (FvToMpg uk x) = Exact c y"
  shows "c = K_to_mpg & x ~= 0 & y * x = (if uk then lpk_uk else lpk_us)"
trip_co2_def:
  assumes "kernel (FvCO2 d du ec dsl) = Exact c y"
  shows "c = K_co2 & ~ econ_zero ec &
  y = gallons_of d du ec * (if dsl then co2_diesel else co2_gasoline) / 1000"
trip_cost_def:
  assumes "kernel (FvCost d du ec (Some pr)) = Exact c y"
  shows "c = K_trip_cost & ~ econ_zero ec & d ~= 0 & y = price_cost (gallons_of d du ec) pr"
trip_litres_def:
  assumes "kernel (FvLitres d du ec) = Exact c y"
  shows "c = K_trip_litres & ~ econ_zero ec & y = gallons_of d du ec * l_per_gal"
trip_gallons_def:
  assumes "kernel (FvGallons d du ec) = Exact c y"
  shows "c = K_trip_gallons & ~ econ_zero ec & y = gallons_of d du ec"
gauge_pressure:
  assumes "kernel (FsGauge f (Some h)) = Exact c y"
  shows "c = K_pressure_gauge & y = fluid_density f * g0 * h"
absolute_pressure:
  assumes "kernel (FsAbs f (Some h)) = Exact c y"
  shows "c = K_pressure_abs & y = p0 + fluid_density f * g0 * h"
buoyant_force:
  assumes "kernel (FsBuoyant f (Some v)) = Exact c y"
  shows "c = K_buoyant_force & y = fluid_density f * g0 * vol_m3 v"
submerged_fraction:
  assumes "kernel (FsSubmerged s f) = Exact c y"
  shows "c = K_submerged_fraction & y * fluid_density f = solid_density s & 0 < y & y < 1"
submerged_sinks:
  "kernel (FsSubmerged s f) = Sinks <-> fluid_density f <= solid_density s"
reply_answered_iff:
  "answered (reply_of r) <->
  (EXk q d. kernel r = Exact k q & stated_dec k q = Some d) | (EXk d. kernel r = Approx k d) |
  kernel r = Sinks"
reply_states_exact:
  "kernel r = Exact k q ==> stated_dec k q = Some d ==> stated (reply_of r) = Some (value_lit k d)"
reply_states_approx:
  "kernel r = Approx k d ==> stated (reply_of r) = Some (render_dec 4 d)"
reply_withheld_names_decline:
  "kernel r = Decline w ==> ~ answered (reply_of r) & reply_kind (reply_of r) = decline_name w"
```

What they say together:
- **Exact values.** Every exact value is the request's own value, stated only for a fully specified, possible request.
- **Declines.** Underspecified exactly when the `missing` predicate holds; impossible exactly when `impossible` holds
  (division by zero, root of a negative, or the organ's own refusals); `imprecise` only on a possible request needing a
  root, pi or a sine, when the interval is too wide.
- **Equations.** Each kind satisfies its defining equation (division kinds as `y * denominator = numerator`, with the
  denominator proved nonzero; the clamp of each passer-rating component and the 0 to 158.33 range; the pendulum
  `T^2 g = 4 pi^2 L`; fall time `t^2 g = 2h`; impact speed `v^2 = 2gh`; shaft power `P * 60 = 2 pi n T`; angled torque
  bounded by `F r`).
- **Stated numbers.** Four significant digits for most kinds (`%.4g`), fixed decimals for the sports rates, money in cents.
  `render_dec`, `render_fixed`, `render_trim` (text layout) are checked by the self test and the panels, not proved.

## Untrusted parts

`regex.sml` (lane G's matcher, with lane S17's case-folding fix: the matcher lower-cases literals, so patterns the organs
apply case-sensitively are matched on lower-cased text and the original letter is checked afterwards: capital N and J units,
capitalised body names, the mid-sentence capital rule of `names_narrowing_v1`), `recognizer.sml` (hand port of the nine
organs, `narrow_v1`, `numbers_rule_v1`, `names_narrowing_v1`), `main.sml` (JSON framing). Everything the reply says comes
from `Mechanics.reply_of`.

Deliberate differences from the organs (none occur on the panels): inputs the organs divide by zero or take the root of a
negative on are withheld as impossible, where the organs raise; reply text is ASCII (`sqrt`, `pi`, `m3`, `deg`) for the scorers'
number extraction; "physics" numbers like "5 n" in lower case are not accepted as newtons (the organ is case-sensitive).

## Remaining

1. Decimal ties round up in the kernel; the organs round a binary float (lane G's open item 1, same scope, no panel item hits it).
2. Gate rules 1 and 2 need a head run (as lane G).
3. `render_dec`/`render_fixed`/`render_trim` text layout is not proved.
4. `fluids-r2` copies the `fluids` densities (`FLUIDS`, `SOLIDS`) locally rather than importing lane G's `Quantity.thy`;
   `tables_check.py` ties them to the organ file. A shared export would remove the duplicate.
5. Cold start is 26 to 33 ms (against lane G's 7 ms) because the family tables and regexes are built at start-up.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Mechanics --session-root src/extract/mechanics \
  --expect 'VERI7VN_MECHANICS PASS' --timeout 600
python3 src/extract/mechanics/tables_check.py
sh src/extract/mechanics/build.sh
export PYTHONDONTWRITEBYTECODE=1
python3 src/extract/mechanics/score.py
B=var/mechanics/bin/mechanics
S=physics,physics-r2,physics-r3,mechanisms,mechanisms-v2,bodies-v2,sports,fleet,fluids-r2
python3 tools/parity/harness.py --answerer "$B --specialist {id}" --lane-answerer "$B --specialist {id}" --specialist $S --split both --out var/mechanics/parity
python3 tools/parity/harness.py --answerer "$B" --lane-answerer "$B" --specialist $S --split both --out var/mechanics/parity-family
```
