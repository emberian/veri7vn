# Lane G: the quantity family end to end (handoff, 2026-10-16)

Six shipped Oracle7 specialists (`densities`, `units`, `units-v3`, `springs`, `fluids`,
`fuels`) are now one verified HOL kernel over a shared typed quantity. The kernel is
exported to Standard ML and compiled with the MLton inside Isabelle into one 545 KB
standalone binary that speaks the answerer contract. No Isabelle process runs when it
answers. Files: `src/extract/quantity/` ([README](../../src/extract/quantity/README.md)).

## Result on the shipped panels

The binary was scored on every item of each panel with that specialist's own scorer.
Lane A's harness (`tools/parity/harness.py`) and the lane's `score.py` give the same
counts. Each count is right / wrong / valid item withheld / false yes.

| Specialist | Split | n | `--specialist ID` | family (no argument) | Shipped organ, held-out | p50 per question (in binary) vs budget |
|---|---|---|---|---|---|---|
| densities | dev | 51 | 51 / 0 / 0 / 0 | 51 / 0 / 0 / 0 | | |
| densities | heldout | 51 | **51 / 0 / 0 / 0** | 51 / 0 / 0 / 0 | 51 / 0 wrong / 0 fy | 0.12 ms (family 0.19) vs 50 ms |
| units | dev | 76 | 76 / 0 / 0 / 0 | 76 / 0 / 0 / 0 | | |
| units | heldout | 76 | **76 / 0 / 0 / 0** | 76 / 0 / 0 / 0 | 76 / 0 fy | 0.03 ms (family 0.13) vs 50 ms |
| units-v3 | dev | 76 | 76 / 0 / 0 / 0 | 76 / 0 / 0 / 0 | | |
| units-v3 | heldout | 75 | **75 / 0 / 0 / 0** | 75 / 0 / 0 / 0 | 75 / 0 fy | 0.06 ms (family 0.16) vs 50 ms |
| springs | dev | 42 | 42 / 0 / 0 / 0 | 42 / 0 / 0 / 0 | | |
| springs | heldout | 42 | **42 / 0 / 0 / 0** | 42 / 0 / 0 / 0 | 42 / 0 wrong / 0 fy | 0.09 ms (family 0.14) vs 50 ms |
| fluids | dev | 34 | 34 / 0 / 0 / 0 | 34 / 0 / 0 / 0 | | |
| fluids | heldout | 34 | **34 / 0 / 0 / 0** | 34 / 0 / 0 / 0 | 34 / 0 wrong / 0 fy | 0.07 ms (family 0.13) vs 50 ms |
| fuels | dev | 42 | 42 / 0 / 0 / 0 | 42 / 0 / 0 / 0 | | |
| fuels | heldout | 42 | **42 / 0 / 0 / 0** | 42 / 0 / 0 / 0 | 42 / 0 wrong / 0 fy | 0.10 ms (family 0.10) vs 50 ms |

Organ comparison (`score.py`). On all 640 panel questions, in both modes, every reply
agrees with the shipped organ: same answered or withheld status, same kind, and the
same value within the scorer's tolerance. There are 0 disagreements.

Harness verdicts are in `var/quantity/parity/` (per manifest) and
`var/quantity/parity-family/` (family). The decision is `INCOMPLETE` only because no
head answerer was run, so rules 1 and 2 (gain over the core, false yes against the core)
were not measured. Rules 3 to 6 hold:
- **Wrong:** 0.
- **Stays in lane:** units and units-v3 take 6 of the 924 core questions (cap 9). The
  other four take 0. The family also takes 6. All six are "What is N pounds in
  kilograms?", the same 6 of 924 the shipped units organ takes in lane A's control.
- **Self:** no identity question is taken.
- **Budget:** p50 is at most 0.17 ms against 50 ms.

The worst single question takes 4.4 ms in the binary. That is a units-v3 rewrite: one
re-reading in the canonical order plus the kernel call.

Binary: `var/quantity/bin/quantity`, 544,808 bytes (arm64 macOS, MLton from the
Isabelle2026-RC1 bundle), not committed. Cold start (process start to first reply):
6.7 to 7.2 ms over 5 runs.

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Quantity --session-root src/extract/quantity --expect 'VERI7VN_QUANTITY PASS' --timeout 900`
status `passed`, inputs stable. Session build 2 min 04 s with the base session cached;
the first base build (Approximation from source) took about 2 min. Receipt
`var/native-scaffold/sessions/487dde4ecace2b6f/receipt.json`, immutable attempt
`var/native-scaffold/sessions/487dde4ecace2b6f/attempts/50e9b3ffdb164529a0f9b5cdbc643dd4/receipt.json`
(follow-up build at 22:40; the first acceptance was attempt `f82c8203...`; at load ~250 the follow-up
session took 8 min 54 s).
Marker: `VERI7VN_QUANTITY PASS theorems=47 oracles=0`. The ML block in
`Quantity_Export.thy` prints it only after two checks pass: `Thm_Deps.all_oracles` is
empty for the 47 theorems below, and the compiled `self_test` holds. The self test
covers kernel outcomes for every family, the C/F point-versus-difference example, and
reply text and number layout. Sessions: `Veri7vn_Quantity_Base` (`base/`, loads
`HOL-Decision_Procs.Approximation`, no HOL-Analysis) and `Veri7vn_Quantity`.

Table transcription: `python3 src/extract/quantity/tables_check.py` reports PASS, 27
checks. It compares the HOL text with the organ files on these points:
- unit names, each unit's dimension, and each SI factor (units v2's own exact
  rationals);
- temperature points against the organ's `to_k`/`from_k`;
- densities, the element list and the material order;
- the fluids organ's fluids and solids against the shared density table;
- the unit lists each organ reads;
- g and P0;
- fuel NCV, CO2 factor and biogenic flag.

Negative check: a copy of the theory with honey at 1421, psi at 6895 and kph mapped to
mph fails three checks, as it should.

## Theorem statements (verbatim from `src/extract/quantity/Quantity.thy`)

The model:
- `qval` is the exact rational value of a request, computed from SI amounts
  (`siq (x, u) = x * scale u`).
- `phys` is the real-number model. It is `2 * pi * sqrt (siq m / k)` for the period and
  its inverse for the frequency, and `rl (qval r)` for everything else.
- The decline predicates: `missing` means underspecified, `dims_ok` false means
  mismatch, `impossible` means impossible, and `undecided` covers float/sink within 2%.
- `kernel` is the executable function.
- `dec_val (m, e) = m * 10^e` is a decimal.
- The tables are `scale`, `dim_of`, `tscale`, `toffset`, `density`, `ncv`, `co2_factor`,
  `g0 = 980665/100000` and `p0 = 101325`.

```
kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None ∧ dims_ok r ∧ ¬ impossible r ∧ k = kind_of r ∧ q = qval r ∧ rl q = phys r"
kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None ∧ dims_ok r ∧ ¬ impossible r ∧ k = kind_of r ∧
  |dec_val d - phys r| ≤ |phys r| / 1000 + 1 / 1000000000"
kernel_underspecified:
  "kernel r = Decline (Underspecified w) ⟷ missing r = Some w"
kernel_mismatch:
  "kernel r = Decline Mismatch ⟷ missing r = None ∧ ¬ dims_ok r"
kernel_impossible:
  "(∃why. kernel r = Decline (Impossible why)) ⟷ missing r = None ∧ dims_ok r ∧ impossible r"
kernel_undecided:
  "kernel r = Decline Undecided ⟷ missing r = None ∧ dims_ok r ∧ ¬ impossible r ∧ undecided r"
kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None ∧ dims_ok r ∧ ¬ impossible r ∧ ¬ undecided r"
reason_of_exact:
  "reason_of r ≠ None ⟷ impossible r"
round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "|dec_val d - x| ≤ |x| / (2 * 10 ^ (p - 1))"
to_dec_sound:
  assumes x: "x ∈ᵣ X" and d: "to_dec X = Some d"
  shows "|dec_val d - x| ≤ |x| / 1000 + 1 / 1000000000"
stated_dec_sound:
  assumes "stated_dec k q = Some d"
  shows "|dec_val d - rl q| ≤ |rl q| / (2 * 10 ^ (sig_digits k - 1))"
convert_exact:
  assumes "kernel (Convert x (Lin a) (Lin b)) = Exact k y"
  shows "k = K_convert ∧ dim_of a = dim_of b ∧ y * scale b = x * scale a"
convert_mismatch:
  "kernel (Convert x (Lin a) (Lin b)) = Decline Mismatch ⟷ dim_of a ≠ dim_of b"
convert_composes:
  assumes "kernel (Convert x (Lin a) (Lin b)) = Exact k y"
  and "kernel (Convert y (Lin b) (Lin c)) = Exact k' z"
  shows "kernel (Convert x (Lin a) (Lin c)) = Exact K_convert z"
temperature_point:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y"
  shows "k = K_temperature ∧ 0 ≤ kelvin a x ∧ kelvin b y = kelvin a x"
temperature_impossible:
  "(∃why. kernel (Convert x (Tmp a) (Tmp b)) = Decline (Impossible why)) ⟷ kelvin a x < 0"
temperature_point_vs_difference:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y"
  shows "y = tdelta a b x + (toffset a - toffset b) / tscale b"
temperature_point_not_difference:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y" "toffset a ≠ toffset b"
  shows "y ≠ tdelta a b x"
temperature_difference_scales:
  "tdelta a b x * tscale b = x * tscale a"
density_value:
  "kernel (Density m) = Exact K_density (density m)"
mass_from_volume:
  assumes "kernel (MassOf m (Some V) u) = Exact k y"
  shows "k = K_mass ∧ dim_of (snd V) = D_volume ∧ dim_of u = D_mass ∧ y * scale u = density m * siq V"
volume_from_mass:
  assumes "kernel (VolumeOf m (Some M) u) = Exact k y"
  shows "k = K_volume ∧ dim_of (snd M) = D_mass ∧ dim_of u = D_volume ∧ y * scale u * density m = siq M"
floats_verdict:
  "kernel (Floats s f) = Verdict k b ⟷
  k = K_floats ∧ b = (density s < density f) ∧ ¬ |density s - density f| * 50 < density f"
floats_undecided:
  "kernel (Floats s f) = Decline Undecided ⟷ |density s - density f| * 50 < density f"
hooke_force:
  assumes "kernel (SpringForce (Some k) (Some x)) = Exact c y"
  shows "c = K_force ∧ dim_of (snd x) = D_length ∧ y = k * siq x"
hooke_extension:
  assumes "kernel (SpringExtension (Some k) (Some f)) = Exact c y"
  shows "c = K_extension ∧ 0 < k ∧ y * k = f"
hooke_constant:
  assumes "kernel (SpringConstant (Some f) (Some x)) = Exact c y"
  shows "c = K_spring_constant ∧ dim_of (snd x) = D_length ∧ 0 < siq x ∧ y * siq x = f"
elastic_energy:
  assumes "kernel (SpringEnergy (Some k) (Some x)) = Exact c y"
  shows "c = K_elastic_energy ∧ dim_of (snd x) = D_length ∧ y = k * siq x ^ 2 / 2"
spring_period_model:
  assumes "0 < k" "0 ≤ siq m"
  shows "0 ≤ phys (SpringPeriod (Some k) (Some m)) ∧
  phys (SpringPeriod (Some k) (Some m)) ^ 2 * rl k = 4 * pi ^ 2 * rl (siq m)"
spring_frequency_inverse:
  "phys (SpringFrequency (Some k) (Some m)) = inverse (phys (SpringPeriod (Some k) (Some m)))"
spring_frequency_model:
  assumes "0 < k" "0 < siq m"
  shows "phys (SpringFrequency (Some k) (Some m)) * phys (SpringPeriod (Some k) (Some m)) = 1"
round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"
gauge_pressure:
  assumes "kernel (PressureGauge f (Some h)) = Exact c y"
  shows "c = K_pressure_gauge ∧ dim_of (snd h) = D_length ∧ y = density f * g0 * siq h"
absolute_pressure:
  assumes "kernel (PressureAbs f (Some h)) = Exact c y"
  shows "c = K_pressure_abs ∧ dim_of (snd h) = D_length ∧ y = p0 + density f * g0 * siq h"
buoyant_force:
  assumes "kernel (Buoyant f (Some v)) = Exact c y"
  shows "c = K_buoyant_force ∧ dim_of (snd v) = D_volume ∧ y = density f * g0 * siq v"
submerged_fraction:
  assumes "kernel (Submerged s f) = Exact c y"
  shows "c = K_submerged_fraction ∧ y * density f = density s ∧ 0 < y ∧ y < 1"
submerged_sinks:
  "kernel (Submerged s f) = Verdict K_sinks False ⟷ density f ≤ density s"
fuel_energy:
  assumes "kernel (FuelEnergy f (Some m) u) = Exact c y"
  shows "c = K_energy ∧ dim_of (snd m) = D_mass ∧ dim_of u = D_energy ∧
  y * scale u = siq m * ncv f * 1000000"
fuel_co2:
  assumes "kernel (FuelCO2 f (Some m)) = Exact c y"
  shows "c = K_co2 ∧ dim_of (snd m) = D_mass ∧ y = (siq m * ncv f) * co2_factor f / 1000000"
fuel_mass_needed:
  assumes "kernel (FuelMassNeeded f e) = Exact c y"
  shows "c = K_mass_needed ∧ dim_of (snd e) = D_energy ∧ y * ncv f * 1000000 = siq e"
fuel_ncv:
  "kernel (FuelNCV f) = Exact K_ncv (ncv f)"
reply_answered_iff:
  "answered (reply_of r) ⟷
  (∃k q d. kernel r = Exact k q ∧ stated_dec k q = Some d) ∨ (∃k d. kernel r = Approx k d) ∨
  (∃k b. kernel r = Verdict k b)"
reply_states_exact:
  "kernel r = Exact k q ⟹ stated_dec k q = Some d ⟹ stated (reply_of r) = Some (value_lit k q d)"
reply_states_approx:
  "kernel r = Approx k d ⟹ stated (reply_of r) = Some (render_dec 4 d)"
reply_withheld_names_decline:
  "kernel r = Decline w ⟹ ¬ answered (reply_of r) ∧ reply_kind (reply_of r) = decline_name w"
temperature_linear_mismatch:
  "kernel (Convert x (Lin u) (Tmp t)) = Decline Mismatch"
  "kernel (Convert x (Tmp t) (Lin u)) = Decline Mismatch"
```

What they say together:
- **Exact values.** Every exact value is the request's own value. It is given only for
  a request that is fully specified, has the right dimensions and is possible.
- **Declines.** The kernel declines as underspecified exactly when an amount is missing.
  It declines as a mismatch exactly when the dimensions are wrong; for a conversion,
  that means the two units measure different things, or a temperature scale is paired
  with a linear unit. It declines as impossible exactly when the input is impossible.
  `imprecise` happens only on specified, possible requests, and only the period and
  frequency can reach it.
- **Equations.** Each kind satisfies its defining equation in SI units.
- **Conversions.** Conversions compose.
- **Temperature.** A converted temperature names the same absolute temperature. It is
  not a temperature difference: it differs from one by `(toffset a - toffset b) / tscale b`,
  so 100 C is 212 F as a point but 180 F as a difference (self test).
- **Period.** The period satisfies `T^2 k = 4 pi^2 m`, and the stated decimal is within
  1/1000 of it.
- **Stated numbers.** The stated decimal is within half a unit in the last significant
  digit of the exact value: ten digits for conversions and four for the other kinds.
  Whole conversion results are stated exactly.
- **Determinism.** No theorem is needed: the kernel is a HOL function.
- **Text layout.** `render_dec` (how the digits are laid out) is checked by the self
  test and the panels. It is not proved.

## What is trusted and untrusted

- **Proved (HOL):** the model, declines, kernel, exact arithmetic, the period enclosure
  (via Isabelle's `approx` and its correctness theorem), rounding, and the reply text and
  kind names (`reply_of`). Text is ASCII (`kg/m3`, `degrees C`, `rho`, `sqrt`), because
  Isabelle string literals are 7-bit.
- **Checked, not proved:** the HOL tables match the organ files (`tables_check.py`).
- **Untrusted:**
  - `regex.sml`: lane D's matcher, extended with `^`, `$`, `{m,n}` and lookbehind.
  - `recognizer.sml`: a hand port of the six organs' patterns, the branch order and
    `narrow_v1`. It pairs each organ's i-th unit or material pattern with the i-th entry
    of the HOL list for that organ, and takes unit names from the HOL `unit_names`. The
    units organ's narrowing (v2, v3) asks the kernel whether a re-read question is
    answered, as the organ asks v1.
  - `main.sml`: JSON framing, with lane D's reader.
- **Trusted toolchain:** the Isabelle code generator and MLton.

Deliberate differences from the organs; none occur on the panels:
1. A zero spring constant, stretch or mass is declined as impossible. The organ raises
   ZeroDivisionError.
2. Reply text names units canonically ("2.5 g is ... lb"). The units organ echoes the
   user's spelling.
3. Units v1 replies use v2's exact form (ten digits plus the exact fraction). v1 printed
   `%.6g`. The scorer reads both.
4. Float or sink within 2% of the fluid's density is a withheld `undecided` reply. The
   organ returns no reply at all.

Non-ASCII spellings: the organ's temperature names `°c` and `°f` cannot be HOL
literals, so `recognizer.sml` maps them to `c` and `f`. `tables_check.py` checks that
those are the organ's only non-ASCII names. Python's Unicode `\w` and `\d` are ASCII in
the SML matcher. All 640 panel questions are ASCII.

Reuse: codex's `src/families/domains/Domain_Quantities.thy` was read and not imported.
Its statements fit (its unit factors are the same numbers). But its session sits on
`Veri7vn_Codegen` and `Veri7vn_Plans`, and its unit type lacks names, cm3, ft3, MJ, GJ
and MWh, and any link to the organ tables. The definitions here are local, and
`tables_check.py` ties them to the organs.

## Remaining

`spring_frequency_model` (`f * T = 1` for positive k and m) is now proved; it took one more attempt in the follow-up, with an explicit `left_inverse` step. The earlier weakened form remains as `spring_frequency_inverse`.

1. **Rounding on exact decimal ties is stated, not matched (follow-up from lane H).**
   Example: 0.015 m3 of petrol at 745 kg/m3 is exactly 11.175 kg. The kernel rounds
   the exact tie up to 11.18 (`round_tie_up`; the self test pins
   `stated_dec K_mass (11175/1000) = Some (1118, -2)`). The densities organ computes the
   float `0.015*745 = 11.174999999999999` and prints 11.17. This explains 8 of lane H's
   266 fourth-digit differences (`var/fusion/measure.json`, differential rows,
   petrol/gasoline at 15 and 250 litres, carried through to fuel energy).
   - **Why (b), not (a).** Option (a) (round half to even) does not reproduce the
     organ: on the exact value 11.175 it also gives 11.18, because 1117 is odd. The
     organ's 11.17 is an artefact of binary floating point, not a tie rule.
   - **Matching it** would mean modelling IEEE double arithmetic in the kernel, which
     the exact-rational design deliberately avoids.
   - **Scope of the difference.** The kernel and the organs differ only where the exact
     decimal value is a tie, or within float error of one, at the fourth (or tenth)
     significant digit. None of the 640 panel items is such a case.
2. **Rules 1 and 2 of the gate need a head run.** Run
   `tools/parity/answerers/oracle7.py --compose front` with the binary as the specialist
   (needs a small adapter), or run the head alone and combine. Lane A's full board run
   is using the head, so this lane did not run it.
3. **Composition for `network_v3`.** The six organs already share one typed quantity
   pool (`qty = rat × qunit`, dimension-checked). The fusion planner's compositions are
   not encoded. An example is mass from density and volume, then fuel energy from that
   mass. The shape is a request that takes the SI result of another request; `qval` and
   `dims_ok` compose directly.
4. **Not exported as diagnostics.** No debug functions are exported (unlike lane D).
5. **Unproved text layout.** The number-to-text layout `render_dec` is not proved
   (lane D's same open item).

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Quantity --session-root src/extract/quantity \
  --expect 'VERI7VN_QUANTITY PASS' --timeout 900
python3 src/extract/quantity/tables_check.py
sh src/extract/quantity/build.sh                 # export -n under the build lock, MLton, var/quantity/bin/quantity
python3 src/extract/quantity/score.py            # six panels x {--specialist ID, family}, organ comparison, cold start, p50
B=var/quantity/bin/quantity
python3 tools/parity/harness.py --answerer "$B --specialist {id}" --lane-answerer "$B --specialist {id}" \
  --specialist densities,units,units-v3,springs,fluids,fuels --split both --out var/quantity/parity
python3 tools/parity/harness.py --answerer "$B" --lane-answerer "$B" \
  --specialist densities,units,units-v3,springs,fluids,fuels --split both --out var/quantity/parity-family
```
