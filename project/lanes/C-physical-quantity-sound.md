# Quantity, variants and sound: Codex physical packet

Quantity and variants are ready for integration. Their fresh checked exports compile to the canonical binaries, all nine shipped panels and reserved fresh panels pass, and all 44 additional probes pass. The final acoustic proof/export is valid (32 roots, zero oracles), but independent composed checks found two plain explicit-speed sentences falling back to default air. Its recognizer repair and final consumer checks are in progress; acoustics is not ready yet.

## Behavior

The variants layer now admits the same explicit two-sentence conversions as units-v3. This recovers all 31 missed units-v2 held-out answers. The shared quantity recognizer also accepts “What does 37 K come to in C?”. Spring force questions no longer get mistaken for requests for the spring constant merely because they state a spring constant.

Explicit ordinary-state material descriptions reach the existing density table: liquid mercury, solid copper and metallic gold work. Incompatible phases, including liquid copper and solid mercury, fall through. The table models typical conditions, not thermal expansion or melting. Negative physical magnitudes no longer silently lose their sign; these unsupported sentences fall through. Signed unit conversions remain supported. These grammar guards return `taken:false`, so downstream fallback remains possible; they are not new HOL impossibility claims.

Acoustics distinguishes input wavelength from a request to compute wavelength, and stated sound speed from a moving-source speed or pipe length. Celsius air temperature reaches inverse frequency, wavelength, Doppler and pipe requests. Unsupported speed/temperature units, mixed feet/metres distances and unsupported water conditions fall through. No new answer kinds were added. The final acoustic candidate also distinguishes listener motion from source motion. Its verified enclosure guard remains unchanged in strength: the implementation tries 32-bit precision and retries at 64 bits when needed. The export theory runs the self-test before PASS; the program no longer evaluates the self-test on startup.

## Quantity and variants: final consumer evidence

Counts below use each specialist's shipped scorer. Every final row has zero wrong answers, zero false yes and zero valid withheld items. Fresh columns are the previously unused seeds 2026101891 and 2026101892; no tuning followed that evaluation.

| Specialist | Shipped dev | Shipped held-out before → final | Fresh dev | Fresh held-out before → final | Probes final |
|---|---:|---:|---:|---:|---:|
| densities | 51/51 | 51/51 → 51/51 | 51/51 | 51/51 → 51/51 | 7/7 |
| units | 76/76 | 76/76 → 76/76 | 75/75 | 76/76 → 76/76 | 5/5 |
| units-v3 | 76/76 | 75/75 → 75/75 | 75/75 | 76/76 → 76/76 | 5/5 |
| springs | 42/42 | 42/42 → 42/42 | 42/42 | 42/42 → 42/42 | 3/3 |
| fluids | 34/34 | 34/34 → 34/34 | 34/34 | 34/34 → 34/34 | 3/3 |
| fuels | 42/42 | 42/42 → 42/42 | 42/42 | 42/42 → 42/42 | 1/1 |
| densities-r2 | 51/51 | 51/51 → 51/51 | 51/51 | 51/51 → 51/51 | 7/7 |
| units-v2 | 75/75 | 43/74 → 74/74 | 75/75 | 49/76 → 76/76 | 8/8 |
| units-v3-r2 | 76/76 | 75/75 → 75/75 | 75/75 | 76/76 → 76/76 | 5/5 |

The baseline probe total was 16 right, 0 wrong, 6 false yes and 22 valid withheld; final is 44 right and zero in each failure category. Boundary probes prescribe refusing unsupported interpretations. They are recognizer-author checks with cited expectations, not independent shipped-panel invalid cases. The original organs retain the baseline coverage gaps.

Fresh generation changes only the author's dev/held-out random seeds, keeping templates and tables. The units-v2/v3 generators come from units-v3-r2; densities-r2 reuses the densities generator. This is fresh-value evidence with shared-generator blind spots. Earlier tuning seeds were 2026101801/02. Acoustics has no upstream generator in this snapshot.

| Specialist | Cold median ms | Shipped p50 ms | Bytes |
|---|---:|---:|---:|
| densities | 7.232 | 0.184 | 563632 |
| units | 7.478 | 0.048 | 563632 |
| units-v3 | 7.434 | 0.081 | 563632 |
| springs | 7.592 | 0.128 | 563632 |
| fluids | 7.528 | 0.118 | 563632 |
| fuels | 7.454 | 0.139 | 563632 |
| densities-r2 | 7.675 | 0.315 | 562400 |
| units-v2 | 8.723 | 0.079 | 562400 |
| units-v3-r2 | 7.859 | 0.098 | 562400 |

Cold measurements are five fresh processes; warm times use persistent line-oriented native consumers. The parent independently tested seven composed cases with reader/document/math routes disabled: appropriate answers/refusals for material phases, negative volume/stiffness, affine temperature, absolute-zero and dimension boundaries. The negative spring refusal has a generic downstream reason; it does not make a wrong assertion. Receipt: `var/c-physical-integration/quantity-final-consumer.json`.

## Binding laws

Quantity's three new laws are checked in the final 50-root, zero-oracle export. The three acoustic laws below and the additional retry law are checked in the final 32-root, zero-oracle export.

```isabelle
theorem temperature_round_trip:
  assumes "kernel (Convert x (Tmp a) (Tmp b)) = Exact k y"
  shows "kernel (Convert y (Tmp b) (Tmp a)) = Exact K_temperature x"

theorem spring_energy_force:
  assumes "kernel (SpringEnergy (Some k) (Some x)) = Exact c e"
    "kernel (SpringForce (Some k) (Some x)) = Exact c' F"
  shows "2 * e = F * siq x"

theorem pressure_absolute_gauge:
  assumes "kernel (PressureAbs f (Some h)) = Exact c a"
    "kernel (PressureGauge f (Some h)) = Exact c' g"
  shows "a = g + p0"

theorem pipe_open_closed_consistent:
  "phys (PipeOpen n (Some L) s) = 2 * phys (PipeClosed n (Some L) s)"

theorem db_sum_not_quieter:
  assumes "l \<in> set ls"
  shows "rl l \<le> phys (DbSum ls)"

theorem answered_reply_model_bound:
  assumes "answered (reply_of r)"
  shows "\<exists>k d. kernel r = Value k d \<and>
    stated (reply_of r) = Some (render_dec 4 d) \<and>
    \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"

lemma enclose_retry_sound:
  assumes "enclose_retry p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le>
    \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
```

These connect distinct physical answers or the printed decimal to the physical model. They do not prove English interpretation. Static theorem names in JSON are not per-answer proof certificates.

## Receipts and reproduction

Quantity: `var/quantity/remote-attempts/20261018T065346Z-de8d1c578c73/receipt.json`. The build log actually finishes Veri7vn_Quantity and the session log contains `VERI7VN_QUANTITY PASS theorems=50 oracles=0`. Proof sources match the recorded snapshot. Its `results/export/Veri7vn_Quantity/Veri7vn_Quantity.Quantity_Export/code/quantity.ML` has SHA256 `5868f0e58a7f8e180a0b921fb6370151bf92413b578d167fc89246d8251a64c6`.

Canonical native hashes:
- `var/quantity/bin/quantity`: `1f5a43ca0cf6d443088a2f78ae86260101f9ffbaac4022aebdad51663cdf88cc`.
- `var/variants/bin/variants`: `b61a8085c63044e29aa0bcbabb43733790c9b35ff34447b43ac389e55e302c01`.

Final reports: `var/c-physical-quantity-sound/quantity-final/report.json` and `quantity-final-before/report.json`. Reproduce with `python3 -B src/extract/quantity/beyond_check.py --out var/c-physical-quantity-sound/replay --only densities,units,units-v3,springs,fluids,fuels,densities-r2,units-v2,units-v3-r2 --seed 2026101891`. Baseline binaries are preserved in that scratch directory's `build/` folder.

Quantity proof history: a reserved Isar label caused the first parser failure; the next attempt exposed an incorrect simplifier proof strategy for temperature reversal. The final proof explicitly substitutes the conserved Kelvin value. An intermediate queued snapshot was cancelled before running. No claim was weakened.

Acoustics final: `var/acoustics/remote-attempts/20261018T064703Z-c2598a2f7c41/receipt.json`. The target actually finished, build-exit is zero, cancellation is false, and the session log contains `VERI7VN_ACOUSTICS PASS theorems=32 oracles=0`. Current theorem, export theory, ROOT and base source hashes match the snapshot. The export `results/export/Veri7vn_Acoustics/Veri7vn_Acoustics.Acoustics_Export/code/acoustics.ML` has SHA256 `c195d3a414ca1e048cf781936bd7b11f8190f127c1abb74d7698464c13ced11f`. The canonical native binary has SHA256 `1d58f696a68c353168d80ec354a26d35c889d2fc60857306f3c1545846fc4637`.

Final acoustics reports under `var/c-physical-quantity-sound/`:
- `acoustics-final-retry/report.json`: dev 70/70 and held-out 69/69, zero wrong/false yes/valid withheld.
- `probes43-final.json`: 43 right, zero failures. Baseline kernel: 22 right, 7 wrong, 9 false yes, 5 valid withheld; original organ: 21 right, 7 wrong, 10 false yes, 5 valid withheld. These are authored grammar/model-boundary probes, not independent upstream panels.
- `numeric-retry-regression.json`: seed 2026101893, 180 right, zero wrong or withheld. The earlier 32-bit-only binary had one safe precision refusal, on the combined levels −0.1456 dB and −21.3421 dB. This discovery motivated the generic verified retry; seed 1893 is now regression evidence.
- `numeric-retry-untouched.json`: reserved seed 2026101894, 180 right, zero wrong or withheld. No tuning followed this evaluation. The Python numerical oracle is independent of the kernel, but the grammar is authored alongside the recognizer; this is not a missing upstream generator replaced by independent coverage.

The numerical challenge contains 60 random level sums, 60 ratios around four-digit rounding boundaries and 60 distance-level changes. Expected values use Python math and the upstream manifest's OpenStax equations. Reproduce with `python3 -B src/extract/acoustics/untouched_check.py --binary var/acoustics/bin/acoustics --out var/c-physical-quantity-sound/numeric-replay.json --seed 2026101894`. The committed probe file supplies each probe's expected value, calculation and source.

Acoustic binary size changes from 429,016 to 428,448 bytes. Median cold start changes from 11.477 to 6.145 ms; shipped p50 changes from 10.306 to 2.258 ms. The reserved numerical challenge has p50 8.339 ms and maximum 22.864 ms. The regression seed has p50 8.982 ms and maximum 89.021 ms: a difficult retry exceeds the 50 ms aspiration. Cold start remains above the 5 ms aspiration. The earlier 31-root receipt `20261018T064045Z-6298204b9c87` is valid interim evidence, superseded by the final retry build.

A superseded cancelled acoustics attempt (`20261018T063118Z-1314b03bca10`) exposed a build-driver defect: a cancelled launcher returned zero and cached exports were marked successful despite the target not completing. The stale export was never installed. The build owner rejected that receipt, preserved the export in quarantine and added cancellation and build-exit checks. It is not proof evidence.

All three native build scripts accept `GENERATED_SML=/absolute/path/to/a/successful/receipt/export`. Without it they export into a new directory under the local build lock. They preserve earlier exports and replace binaries atomically. No upstream files or caches are modified. Root owns commits and the shared scoreboard.
