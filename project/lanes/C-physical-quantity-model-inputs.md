# Quantity: explicit physical model inputs

The quantity/variants producer packet is implemented, proved and tested, and the final composed boundary passes **18/18 independent checks**. Source and bound natives are frozen, ready for root integration and capture. The physical deputy checked Quantity `d0dbf2a0…`, Variants `d2c6b125…`, Mechanics `5810f082…` and Energy `a720c691…` together; receipt `var/c-physical-integration/quantity-model-final2-composed.json`. Both final compiler graphs and their proof closures were checked against shared measurement reader `11f703…`.

The integration probes found and repaired three real classes of error: pressure noun-phrase interpretation, sibling readers silently ignoring supplied physical conditions, and legacy fuel branches silently ignoring a supplied calorific value. The final complete-input contract refuses both a named calorific value and an unassigned 19 MJ/kg input for 3 kg wood; ordinary 3 kg wood still yields 46.8 MJ. Custom calorific inputs remain valid withheld, not capability-right. Earlier passing and failing receipts remain available, including `quantity-model-final-own-consumer.json` and `fuel-ownership-extra-consumer.json`. Final fresh-value producer checks pass 136/136.
## What changed

Hydrostatic pressure now carries a density source, depth, gravity magnitude and absolute surface pressure. Missing conditions use the existing reference defaults; supplied conditions must bind to complete numeric and unit spans. Supplied density is a positive mass/volume ratio. Gravity supports m/s², ft/s² and standard-gravity multiples; depth is a length and surface pressure is a pressure quantity. Depth, gravity and absolute surface pressure may be zero, but not negative. Existing `PressureGauge` and `PressureAbs` constructors remain unchanged for captured Fusion consumers.

Useful fuel heat is a separate operation and result kind, `useful_energy`. Its supplied heat-delivery fraction is between zero and one. The inverse `useful_mass_needed` requires a positive fraction and returns the mass of fuel required to deliver the requested heat. Efficiency does not silently become a burned-fuel fraction or an emissions multiplier. Reference fuel values remain the IPCC default net calorific values already present in the kernel.

The new `unsupported_model` decline consumes conditions that this finite model cannot apply: reference density at a specified temperature/pressure, moisture or calorific-basis changes, unread or ambiguous input units, and supplied conditions on other fluid operations. The reader uses `MeasuredInput` original number/unit spans and exact `ExactNumeric` values. Requested output units have a separate binding; they never provide a missing source unit. Numeric role conversion and physical bounds stay in HOL. Pressure mode binds to the requested noun phrase, including `total (absolute) pressure`, separately from an absolute surface-pressure input. Legacy fuel heat, emissions and inverse-mass branches now also bind complete measured inputs and separate requested output units. An extra calorific value, energy content or compound unit cannot silently disappear into the default fuel table; unsupported computable inputs count as valid withheld.

## Actual theorem statements

The successful export scans 59 theorem roots with zero oracles. Six new laws state:

- If absolute and gauge requests answer for identical density, depth, gravity and supplied surface pressure, their difference is exactly that surface pressure in Pa.
- If the new hydrostatic request answers, its pressure is nonnegative.
- If two answering hydrostatic requests have the same density, SI depth, SI gravity and SI surface pressure, their values agree.
- If useful and released energy requests answer for the same fuel, mass and output unit, `useful = efficiency × released` and `0 ≤ useful ≤ released`.
- If useful-fuel-mass inversion answers, `mass × efficiency × NCV × 1000000 = requested joules`, and the mass is nonnegative.
- `kernel (UnsupportedCondition c) = Decline (UnsupportedModel c)`.

The exact statements and proof bodies are in [Quantity.thy](../../src/extract/quantity/Quantity.thy), named `hydrostatic_absolute_gauge`, `hydrostatic_nonnegative`, `hydrostatic_equivalent_inputs`, `useful_heat_fraction`, `useful_heat_inverse` and `unsupported_condition_declines`. No axioms or admitted proofs were added.

First attempt `20261018T082849Z-946f59538731` failed because `values` was used as an Isar fact label despite being a reserved command. Second attempt `20261018T083646Z-c7d7689656ab` exposed two nonnegativity tactic residuals. The useful-heat proof was refactored into explicit numerator/denominator bounds and a separate inverse balance equality; its statements were not weakened.

The successful hbox attempt is `var/quantity/remote-attempts/20261018T084205Z-089f71726b21`: actual `Finished Veri7vn_Quantity`, 124 seconds, build exit 0, not cancelled, 59 roots/0 oracles. Its generated export SHA256 is `a45ce82683e3d7773f683fe81856e9afa7b46c2997f280d5ff1c55d046091375`.

## Panel numbers

Each affected specialist remains perfect on its own shipped scorer, both shipped dev+heldout and freshly generated dev+heldout values (seeds 2026102309/10). Baseline and final totals are identical:

| Specialist | Shipped right | Fresh right | Wrong | False yes | Valid withheld |
|---|---:|---:|---:|---:|---:|
| densities | 102/102 | 102/102 | 0 | 0 | 0 |
| densities-r2 | 102/102 | 102/102 | 0 | 0 | 0 |
| fluids | 68/68 | 68/68 | 0 | 0 | 0 |
| fuels | 84/84 | 84/84 | 0 | 0 | 0 |

All 18 existing probes for those four specialists also pass. Receipts: `model-inputs-panels-before/report.json`, `model-inputs-panels-final/report.json`, the corrected fluids-only `model-inputs-panels-mode/report.json`, the legacy fuel repair `model-inputs-panels-fuel-final/report.json`, and final shared-unit refresh `model-inputs-panels-operator-final/report.json`, all under `var/c-physical-quantity-sound/`. The first final-panel run caught eight genuine fluid errors on `total (absolute)` noun phrases. That receipt is retained; the corrected mode reader restores all 68 shipped and 68 fresh fluid scores.

The final independent numeric challenge uses unused seed 2026102329. It passes all 136 authored checks. Capability counts are separate: safe refusal of a computable unsupported form remains valid withheld, and any refusal of an invalid input counts as capability-right even if an earlier reader used a less specific decline kind.

| Specialist | Before right/wrong/FY/withheld | Final right/wrong/FY/withheld | Final authored checks |
|---|---|---|---:|
| densities | 0/3/0/1 | 0/0/0/4 | 4/4 |
| densities-r2 | 0/3/0/1 | 0/0/0/4 | 4/4 |
| fluids | 8/30/3/23 | 58/0/0/6 | 64/64 |
| fuels | 3/53/8/0 | 53/0/0/11 | 64/64 |

Thus the challenge changes from **11 right / 89 wrong / 11 false yes / 25 valid withheld** to **111 / 0 / 0 / 25**, while all 136 intended answer/refusal assertions pass. Baseline binaries were saved before replacement. Receipts: `model-inputs-fuel-untouched-before.json` and `model-inputs-fuel-untouched.json`. The earlier 131-case evaluation remains in `model-inputs-untouched-before.json` and `model-inputs-untouched.json`. Earlier tuning receipts and the original 121-case baseline remain available. Saved replies were reclassified to separate capability from decline-kind assertions; no binary rerun was used for that reporting correction.

Temperature point/difference regression remains 236/236 authored checks, with its known eight valid withheld multi-input forms: `model-inputs-conditions-regression.json`. That check preceded the pressure noun-phrase and legacy fuel repairs, which do not touch the conversion reader.

## Concrete controls and their sources

The authored harness [model_inputs_check.py](../../src/extract/quantity/model_inputs_check.py) computes expectations with Python `Fraction`, independently of exported arithmetic. These 20 controls are tied to the equations and exact factors in the named laws above and the existing `scale`, `g0`, `density` and `ncv` tables; they are not an independent experimental validation of the physical reference values.

| Control | Expected result or boundary |
|---|---|
| 2 m water, gravity 1.62 m/s² | 3240 Pa gauge |
| Same input with `g = 1.62 m/s2` | Same pressure |
| 2 m water, surface 200 kPa | 219613.3 Pa absolute before rounding |
| Gauge request with absolute surface 200 kPa | 19613.3 Pa gauge before rounding |
| Zero gravity and zero surface pressure | Zero absolute pressure |
| Supplied density 1 g/cm³, 2 m, gravity 10 m/s² | 20000 Pa |
| Supplied density 1 kg/L, otherwise identical | 20000 Pa |
| 1 lb/ft³, depth 1 ft, gravity 1 ft/s² | Exact pound/foot factor in Pa |
| Zero depth, surface 2 atm | 202650 Pa before rounding |
| Negative depth | Impossible physical input |
| Negative gravity magnitude | Impossible physical input |
| Negative absolute surface pressure | Impossible physical input |
| Zero supplied density | Impossible physical input |
| Gravity in furlong/s² | Valid withheld, unsupported unit |
| Reference water at 100 C | Valid withheld, no thermal model |
| 100 kg wood, 50% delivery | 780 MJ useful heat |
| Same heat requested in kWh | 650/3 kWh |
| Efficiency `1/2` versus `0.5` | Same exact fraction |
| 780 MJ useful heat, wood, 50% | 100 kg fuel |
| Moisture versus delivery efficiency | Moisture is unsupported, never substituted for efficiency |

Other controls cover percent bounds, zero forward efficiency, impossible zero inverse efficiency, negative fuel mass/required heat, malformed compound units, mJ/mWh versus MJ/MWh, explicit output dimensions and unrelated percentages. Seven final shared-unit controls also pass, covering `kg.min`, `kg × min`, acceleration compounds, custom calorific input and ordinary sentence-ending periods (`model-inputs-operator-controls.json`).

## Bound native artifacts and timing

| Family | Native attempt | Binary SHA256 | Bytes | Cold median | Warm p50 |
|---|---|---|---:|---:|---:|
| quantity | `20261018T085841Z-a58442a99bcd` | `d0dbf2a0f293b939374c88879edaa79b2b91e0e59905c070608e2b149dbe4e31` | 707704 | 7.892 ms | 0.503 ms |
| variants | `20261018T085848Z-e843e0ddea5a` | `d2c6b125747ab560bc9eb8d3c3b264449d90e7a1329651dc716ab4a8898f76d9` | 708216 | 8.061 ms | 0.532 ms |

Manifests are `var/<family>/native-attempts/<attempt>/compile-inputs.json`, produced by the immutable native helper from actual consumed inputs. Both consume `numeric.sml` SHA `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d` and `measured_input.sml` SHA `11f703525511191a6e075930191903841d65d158544075845c0142bfc32e2cb7`. Variants records its derived `recognizer_base.sml` as a real distinct compiler input. Cold values are five-process medians; warm values are 50 round trips after one warmup, on the explicit three-condition hydrostatic question. Cold latency remains above the 5 ms aspiration. Receipt: `model-inputs-fuel-timing.json`; prior timings remain in `model-inputs-timing.json`.

## Remaining limits

Pressure output remains Pa; an explicitly requested alternative pressure unit is withheld. Inverse useful-fuel mass returns kg. Bare `in` is treated as a preposition in material clauses, so inches must be spelled out in these new model inputs. Reference densities have no thermal expansion or compressibility model. Buoyancy/submerged-fraction operations with explicit gravity/density, emissions with delivery efficiency, custom calorific values, moisture/basis changes and unsupported inputs remain model refusals. These are capability limits, not completion claims.

Runtime found a separate valid-withheld conversion gap: Wh is absent from the typed unit vocabulary, while MJ/GJ/MWh exist but are absent from the general conversion alias table. The useful-heat reader binds those existing fuel units without doing conversion arithmetic. Exact Wh plus coherent general energy aliases are the next producer packet after capture; no dialogue arithmetic workaround is proposed.
