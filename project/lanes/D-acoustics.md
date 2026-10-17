# Lane D: acoustics end to end (handoff, 2026-10-16)

The shipped Oracle7 specialist `acoustics` is now a verified HOL kernel, exported to
Standard ML, compiled with the MLton inside Isabelle into a 427 KB standalone binary
that speaks the answerer contract. No Isabelle process runs when it answers.

## Result on the shipped panel (binary scored directly on every item)

| Split | n | right | wrong | declined (valid item withheld) | false yes |
|---|---|---|---|---|---|
| dev | 70 | 67 | 0 | 3 | 0 |
| heldout | 69 | **66** | 0 | 3 | 0 |

Shipped organ: heldout 69/69, false yes 0. Same numbers from lane A's harness
(`tools/parity/harness.py`, verdicts in `var/acoustics/parity/`) and from the lane's own
`score.py`. Harness lane checks with the binary as lane answerer: 0 of 924 core-panel
questions taken (cap 9), self questions not taken.

The six misses (3 dev, 3 heldout) are all the same cause: the kernel withholds with
kind `imprecise` rather than state a number it cannot pin to four digits.

| Split | Kind | Question |
|---|---|---|
| dev | dbsum | Two sources of 60 dB and 60 dB play together. What is the combined sound level in decibels? |
| dev | dbdist | A sound is 60 dB at 5 m. What is the level in dB at 20 m? |
| dev | dbratio | How many decibels louder is a sound with 1000 times the intensity? |
| heldout | dbsum | What is the total level in dB when a 60 dB source and a 60 dB source are combined? |
| heldout | dbsum | What is the total level in dB when a 60 dB source and a 65 dB source are combined? |
| heldout | dbdist | At 5 m a speaker measures 60 dB. What will the decibel level be at 20 m? |

Why: Isabelle's interval bounds for `ln` (`lb_ln`/`ub_ln` in
`HOL-Decision_Procs.Approximation_Bounds`) run a series on the argument's binary
mantissa minus 1; when the mantissa is near 2 (1000 = 1.95*2^9, 10^6 = 1.91*2^19,
4.16*10^6 = 1.98*2^21) the series converges slowly and the enclosure stays about
1e-4 wide whatever the precision (measured with the exported `debug_enclosure` at
precision 20, 30, 40, 53 and 64). The kernel requires width at most |value|/10^6, so it
withholds. No wrong number is stated.

All other answered values agree with the organ within the scorer's tolerance (the
`organ_disagreements` list in `var/acoustics/score.json` has exactly these six).

## Binary, start-up and latency (budget p50 50 ms)

- Binary: `var/acoustics/bin/acoustics`, 427,176 bytes (arm64 macOS, MLton 20241230 from
  the Isabelle2026-RC1 bundle). Not committed.
- Cold start (process start to first reply, a Doppler item): 14 to 19 ms over 5 runs.
- p50 in-binary time per panel item: 12.3 ms (139 items); round trip 12.8 ms.
- By kind (p50 / max ms): beat 0.17/0.33, string 0.39/0.91, speed 6.7/8.9, pipes 6.7/9.1,
  doppler 13.3/17.9, wavelength 13.2/17.8, db_distance 23/27, db_ratio 22/27,
  **db_sum 78/86** (over the 50 ms budget for that kind), imprecise 49/101.
  The cost is interval arithmetic at 64 bits for `ln` and `powr`; precision 30 to 40
  gives the same certainty margin at a third of the time (measured with
  `debug_approx`), not yet applied.

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Acoustics --session-root src/extract/acoustics --expect 'VERI7VN_ACOUSTICS PASS' --timeout 900`
status `passed`, inputs stable, 67 s (base session cached). Receipt
`var/native-scaffold/sessions/1913aa72eafed902/receipt.json`, immutable attempt
`var/native-scaffold/sessions/1913aa72eafed902/attempts/90690a68c2a0498992c230c6afbbfb49/receipt.json`.
The marker is printed only after the ML block in `Acoustics_Export.thy` checks that
`Thm_Deps.all_oracles` is empty for the 28 theorems below and that the compiled
`self_test` holds. Sessions: `Veri7vn_Acoustics_Base` (in `base/`, loads
`HOL-Decision_Procs.Approximation` from source, about 2 min once; no HOL-Analysis) and
`Veri7vn_Acoustics`.

## Theorem statements (verbatim from `src/extract/acoustics/Acoustics.thy`)

`phys` is the real-number model (speed of sound `331.3 * sqrt (1 + T / 273.15)` in air,
`1481` in fresh water, decibel, Doppler, harmonic formulas). `missing` is the
underspecified predicate, `impossible` the impossible one. `kernel` is the executable
function. `dec_val (m, e) = m * 10^e` is the decimal it states.

```
reason_of_exact:
  assumes "missing r = None"
  shows "reason_of r ≠ None ⟷ impossible r"
expr_of_meaning:
  "interpret_floatarith (expr_of r) [] = phys r"
to_dec_sound:
  assumes x: "x ∈r X" and d: "to_dec X = Some d"
  shows "|dec_val d - x| ≤ |x| / 1000 + 1 / 1000000000"
reach_iff:
  "medium_ok s ⟹ reach u s ⟷ speed s ≤ rl u"
kernel_value_sound:
  assumes "kernel r = Value k d"
  shows "missing r = None ∧ ¬ impossible r ∧ k = kind_of r ∧
         |dec_val d - phys r| ≤ |phys r| / 1000 + 1 / 1000000000"
kernel_underspecified:
  "kernel r = Decline (Underspecified w) ⟷ missing r = Some w"
kernel_impossible:
  "(∃why. kernel r = Decline (Impossible why)) ⟷ missing r = None ∧ impossible r"
kernel_imprecise:
  "kernel r = Decline Imprecise ⟹ missing r = None ∧ ¬ impossible r"
doppler_source_toward:
  assumes "rl u < speed s"
  shows "phys (Doppler (Some f) (Some u) Source Toward s) * (speed s - rl u) = rl f * speed s"
doppler_source_away:
  assumes "medium_ok s" "0 ≤ u"
  shows "phys (Doppler (Some f) (Some u) Source Away s) * (speed s + rl u) = rl f * speed s"
doppler_listener_toward:
  assumes "medium_ok s"
  shows "phys (Doppler (Some f) (Some u) Listener Toward s) * speed s = rl f * (speed s + rl u)"
doppler_listener_away:
  assumes "medium_ok s"
  shows "phys (Doppler (Some f) (Some u) Listener Away s) * speed s = rl f * (speed s - rl u)"
doppler_supersonic_source_declined:
  assumes "d ≠ Unclear" "speed s ≤ rl u"
  shows "∃why. kernel (Doppler (Some f) (Some u) Source d s) = Decline (Impossible why)"
db_sum_intensities:
  assumes "ls ≠ []"
  shows "10 powr (phys (DbSum ls) / 10) = (∑l←ls. 10 powr (rl l / 10))"
db_two_equal_intensities:
  "10 powr (phys (DbTwoEqual l) / 10) = 2 * 10 powr (rl l / 10)"
db_distance_inverse_square:
  assumes "0 < r1" "0 < r2"
  shows "10 powr (phys (DbDistance l r1 r2) / 10) * rl r2 ^ 2 = 10 powr (rl l / 10) * rl r1 ^ 2"
db_ratio_intensity:
  assumes "0 < k"
  shows "10 powr (phys (DbRatio k) / 10) = rl k"
intensity_ratio_levels:
  "phys (IntensityRatio l1 l2) * 10 powr (rl l2 / 10) = 10 powr (rl l1 / 10)"
string_harmonic:
  assumes "0 < len L"
  shows "phys (StringHarmonic n (Some L) (Some v)) * (2 * rl (len L)) = real n * rl v"
pipe_closed_harmonic:
  assumes "0 < len L"
  shows "phys (PipeClosed n (Some L) s) * (4 * rl (len L)) = real n * speed s"
pipe_open_harmonic:
  assumes "0 < len L"
  shows "phys (PipeOpen n (Some L) s) * (2 * rl (len L)) = real n * speed s"
pipe_closed_answers_odd:
  assumes "kernel (PipeClosed n L s) = Value k d"
  shows "odd n"
wavelength_relation:
  assumes "0 < hz f"
  shows "phys (Wavelength (Some f) s) * rl (hz f) = speed s"
frequency_relation:
  assumes "0 < len L"
  shows "phys (Frequency L s) * rl (len L) = speed s"
speed_air_square:
  assumes "medium_ok (AirAt T)"
  shows "0 < phys (SpeedAir (AirAt T)) ∧ phys (SpeedAir (AirAt T)) ^ 2 = 331.3 ^ 2 * (1 + rl T / 273.15)"
speed_air_freezing:
  "phys (SpeedAir (AirAt 0)) = 331.3"
reply_answered_iff:
  "answered (reply_of r) ⟷ (∃k d. kernel r = Value k d)"
reply_states_kernel_value:
  "kernel r = Value k d ⟹ stated (reply_of r) = Some (render_dec d)"
```

What they say together: every stated value is within 1/1000 relative (plus 1e-9
absolute) of the real model, which is inside the scorer's 0.2% + 0.05. The kernel
withholds as underspecified exactly when a value is missing, and as impossible
exactly when the inputs are impossible. In the Doppler case that test involves a square
root and is decided exactly in rational arithmetic (`reach_iff`). `imprecise` happens
only on specified, possible requests. Each kind's defining equation holds for the model.
Determinism needs no theorem: the kernel is a HOL function. Rounding to four digits
is covered by `to_dec_sound`; how the digits are laid out as text (`render_dec`) is a
HOL function checked by `self_test` and the panel, not proved.

## What is trusted and untrusted

- Proved (HOL): model, declines, enclosure via Isabelle's `approx` (its own
  correctness theorem `approx`), rounding, kernel, reply text and kind names
  (`reply_of`). Text is ASCII (`degrees C`, `sqrt`, `log10`, `lambda`) because
  Isabelle string literals are 7-bit.
- **Untrusted**: `regex.sml` (a small backtracking matcher for the Python regex subset
  the organ uses), `recognizer.sml` (hand port of the organ's patterns and branch
  order into a typed `request`; it computes nothing), `main.sml` (JSON lines framing,
  hand-rolled reader). Trusted toolchain: Isabelle code generator, MLton.
- The recognizer produces the same request as the organ's reading on all 139 panel
  questions (stub run before integration; organ comparison in `score.py`).

Deliberate differences from the organ: (1) temperatures at or below -273.15 C are
declined as impossible (the organ silently used 20 C); (2) negative input speeds,
non-positive beat frequencies, harmonic 0 and a listener receding at or above the
speed of sound are declined as impossible (the organ computed a number); (3) a string
with a non-positive length and no wave speed is declined as underspecified (the kernel
checks missing values first), where the organ said impossible. None of these occur on
the panel.

Reply shape: `path` is `specialist:acoustics>KIND`, `kind`, `value` (the stated decimal
as a JSON number), `provenance` with `taken`, `specialist_ms`, kernel and theorem names.
Questions it does not take get `status: withheld`, empty `path`, `provenance.taken:
false`.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Acoustics --session-root src/extract/acoustics \
  --expect 'VERI7VN_ACOUSTICS PASS' --timeout 900
sh src/extract/acoustics/build.sh          # export -n under the build lock, MLton, var/acoustics/bin/acoustics
.venv/bin/python src/extract/acoustics/score.py      # per-split counts, misses, organ comparison, cold start, p50
python3 tools/parity/harness.py --answerer var/acoustics/bin/acoustics \
  --lane-answerer var/acoustics/bin/acoustics --specialist acoustics --split both --out var/acoustics/parity
```

## Remaining

1. **The six `imprecise` items.** Intended fix, tried and not landed: compute
   `ln y` as `256 * ln (sqrt^8 y)` so `ln`'s argument is near 1. Intended lemma:
   `0 ≤ y ⟹ ln (r8 y) = ln y / 256` with `r8` eight nested `sqrt`, giving
   `0 ≤ interpret_floatarith a xs ⟹ interpret_floatarith (Lg a) xs = log 10 (interpret_floatarith a xs)`.
   `expr_of_meaning` then becomes conditional on `missing r = None ∧ ¬ impossible r`
   (positivity of the log arguments follows from those). Two builds hung (>400 s) in
   a final one-line `simp` closing `256 * ln (r8 y) * inverse (ln 10) = log 10 y`, most likely
   a `log`/`ln` rewrite loop. Do this step with explicit rewriting (`subst`, `field_simps`
   without `log_def` in the simp set) instead of `simp add: log_def`.
2. Lower `prec` from 64 to about 36 to bring db_sum under 50 ms; check with
   `debug_approx` that the width test still passes on the panel.
3. Head count (how many panel items the Oracle7 head answers itself): not measured
   here. Use lane A's `tools/parity/answerers/oracle7.py` (it redirects the head's
   writes under `upstream/`).
4. `debug_enclosure`/`debug_approx` are exported only as diagnostics; drop them
   once the precision work is done.
