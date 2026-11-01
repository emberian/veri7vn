# Quantity: exact energy units and case-sensitive prefixes

The producer packet is proved and passes its scoped panels and consumer challenges. The physical deputy independently passed eight fresh-value questions through all four unit wrappers (32/32), including milli/mega role swaps, exact fractional conversions and compound/ambiguous refusals. Receipt: `var/c-physical-integration/quantity-energy-units-independent.json`. Both actual compiler manifests and current proof closures passed its offline verification. Final Quantity/Variants sources and bound natives are frozen, ready for root integration and capture. No new reply kind is required. Acoustic motion work is separate and is not part of this ready packet.

## What now works

Runtime's dialogue chain exposed two distinct valid-withheld gaps: `Convert 6 kWh to Wh.` had no typed Wh unit, while `Convert 6 kWh to MJ.` had typed units but no general MJ alias. Both now answer: 6000 Wh and 21.6 MJ.

The kernel adds exact Wh, mJ and mWh units with energy dimension and SI factors 3600, 1/1000 and 18/5. The general name table also exposes existing MJ/GJ/MWh units. The useful-fuel reader now consumes this shared typed table, replacing its duplicate energy aliases. All arithmetic remains in HOL.

Each source and target role preserves its original symbol spelling. `mJ` and `MJ` differ by a billion; so do `mWh` and `MWh`. Spelled names are case-insensitive. Ambiguous lowercase `mj`/`mwh` and noncanonical `WH` are deliberately withheld. The shared measured-unit adapter checks complete captured roles, so rate/product suffixes such as `MJ/s`, `MJ.min` or `MJ × min` cannot be discarded. The word `in` is treated as an inch abbreviation only when bound as that unit role, rather than extending another measured unit through the English preposition.

The table checker still requires every shipped alias, dimension and exact factor unchanged. It separately checks the exact finite extension set, its energy dimensions/factors and name uniqueness. No arbitrary extra alias is permitted.

## What is proved

The existing `convert_exact` and `convert_composes` laws apply to the new units. The new `watt_hour_power_time` theorem states: for any energy unit u, converting p×t Wh to u returns exactly `(p × scale watt) × (t × scale hour) / scale u`. Thus constant power in watts and duration in hours retain the same power-times-time energy in SI units.

The two `energy_prefix_separation` conclusions state that converting x MJ to mJ, or x MWh to mWh, returns exactly x×1000000000. These are kernel-result statements, not parser or printed-label claims.

One hbox proof attempt passed: `var/quantity/remote-attempts/20261018T100329Z-8f533c054a86`, actual `Finished Veri7vn_Quantity` in 137 seconds, 62 theorem roots/0 oracles. Generated export SHA256: `5e8464fd246f437e24253809a44c21f5f6d955c3c2a5c1354d513b5c3f235478`. No axioms or admitted proofs were added.

## Shipped and fresh panels

Each specialist is run through its actual pinned consumer and scored by its own shipped scorer. Before and after scores are identical and perfect:

| Specialist | Shipped right | Fresh right | Wrong | False yes | Valid withheld |
|---|---:|---:|---:|---:|---:|
| units | 152/152 | 151/151 | 0 | 0 | 0 |
| units-v2 | 149/149 | 152/152 | 0 | 0 | 0 |
| units-v3 | 151/151 | 152/152 | 0 | 0 | 0 |
| units-v3-r2 | 151/151 | 152/152 | 0 | 0 | 0 |
| fuels | 84/84 | 84/84 | 0 | 0 | 0 |

Fresh generator seeds are 2026102409/10. The units-v3 generator is the corresponding version retained under units-v3-r2, as disclosed in the earlier continuation. All 24 existing probes pass. Receipts: `var/c-physical-quantity-sound/energy-panels-before/report.json` and `energy-panels-tuning/report.json`.

The unused numerical seed 2026102421 passes all 431 authored checks. These include every ordered pair of nine energy symbols, exact signed fractions/scientific values, source/target roles, the variant quantity-first and two-sentence grammars, malformed inputs and compound suffixes. These are capability counts, separately from authored refusal assertions:

| Specialist | Before right/wrong/FY/withheld | Final right/wrong/FY/withheld | Checks |
|---|---|---|---:|
| units | 20/0/0/83 | 100/0/0/3 | 103/103 |
| units-v2 | 20/0/0/88 | 105/0/0/3 | 108/108 |
| units-v3 | 20/0/0/88 | 105/0/0/3 | 108/108 |
| units-v3-r2 | 20/0/0/88 | 105/0/0/3 | 108/108 |
| fuels | 0/0/0/4 | 4/0/0/0 | 4/4 |

Total: **80 right / 0 wrong / 0 false yes / 351 valid withheld** before, **419 / 0 / 0 / 12** after. The twelve withheld cases are the three ambiguous/noncanonical symbol forms through four unit readers. They are not counted as capability successes merely because the safety assertions expect refusal. Receipts: `energy-untouched-before.json`, `energy-untouched.json`; tuning seed 2026102401 remains separate.

Regression receipts cover 236/236 temperature point/difference checks (228 right, eight known valid withheld) and 136/136 explicit physical-model checks (113 right, 23 valid withheld). `densities-r2` is explicitly exercised through its variant consumer on four stated-temperature/pressure inputs, all consumed as unsupported reference-state models; these four are valid withheld, not completion claims for a thermal density model. Files: `energy-delta-regression.json`, `energy-model-regression.json`. The latter updates two former valid-withheld milli-energy output cases to correct useful-heat answers.

## Concrete controls

The independent untrusted [energy_units_check.py](../../src/extract/quantity/energy_units_check.py) uses Python Fraction and a separate exact-factor table. The following controls cite that harness, the `scale`/`unit_names` tables and the kernel conversion laws above; they do not claim independent experimental measurements.

| Input | Expected result/boundary |
|---|---|
| 6 kWh → Wh | 6000 |
| 6 kWh → MJ | 21.6 |
| 1 Wh → J | 3600 |
| 1 mJ → J | 0.001 |
| 1 MJ → mJ | 1000000000 |
| 1 mWh → J | 3.6 |
| 1 MWh → mWh | 1000000000 |
| .5 MWh → mWh | 500000000 |
| 1e-3 MJ → J | 1000 |
| Unicode minus 2 mJ → J | -0.002 |
| 1/ 2 Wh → J | 1800 |
| 3 MEGAJOULES → watt-hours | 2500/3 |
| 4 milliwatt hours → J | 14.4 |
| I have 2 MWh; convert that to mWh | 2000000000 through variants |
| I have 2 mWh; what is that in MWh | 1/500000000 through variants |
| 2 mWh: how many joules | 7.2 through quantity-first variants |
| 1 in → cm; 1 m in cm | 2.54; 100, preserving inch/preposition roles |
| MJ/s, MJ.min, MJ × min as source | No scalar energy answer |
| J/s or J × min as target | No scalar energy answer |
| 100 kg wood, 50% useful heat in mJ | 780000000000 |
| Same useful heat in mWh | 650000000/3 |
| 3 kg wood released heat in Wh | 13000 |

## Actual compiler inputs and performance

| Family | Native attempt | Binary SHA256 | Bytes | Cold median | Warm p50 |
|---|---|---|---:|---:|---:|
| quantity | `20261018T101353Z-f577ea9df27b` | `75ec0797c33bd0d1f1b3b8c494d49adb533c2b2432a1e76337344ccdedf63c45` | 707512 | 7.705 ms | 0.081 ms |
| variants | `20261018T101400Z-436f1965c268` | `68c9d6ea6d8e2fa402efdc74bbb77230fbbd079f6ac56c3ac8a4ed5bb799325b` | 724424 | 7.425 ms | 0.095 ms |

Each actual-input manifest is `var/<family>/native-attempts/<attempt>/compile-inputs.json`. Both bind shared ExactNumeric `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d` and MeasuredInput `11f703525511191a6e075930191903841d65d158544075845c0142bfc32e2cb7`. Variants' transformed recognizer remains a distinct recorded compiler input. Timing uses five fresh-process medians and 50 round trips after one warmup on `Convert 6 kWh to Wh.`; receipt `energy-timing.json`. Cold start remains above the 5 ms aspiration.

## Integration scope and limits

Named files: quantity `Quantity.thy`, `Quantity_Export.thy`, `recognizer.sml`, `tables_check.py`, `energy_units_check.py`, `model_inputs_check.py`, `README.md`; variants `README.md`; this report. The earlier `conditions_check.py` and temperature-conditions report correction remain separate reporting-only auxiliary files. Acoustic edits and its report are excluded.

This is a finite energy vocabulary, not arbitrary dimensional algebra. Energy rates/products are refused. The units-v1 specialist still lacks the variant two-sentence grammar. Reference-density thermal models, custom fuel calorific values and unsupported physical conditions remain the earlier documented limits. Next work is the additive both-moving acoustic Doppler model, independently bound and rounded once.
