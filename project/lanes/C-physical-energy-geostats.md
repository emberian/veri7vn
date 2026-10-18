# Physical families: energy and geometry/statistics

Owner: Codex physical/energy_geostats. Energy packet verified through shared consumers; geometry/statistics proof revision pending.

## Scope

Finish existing readers across variant identities, expose adjusted battery runtime and weighted mean, preserve decline conditions, and remove exported eager self-tests. Shared runtime integration uses family capabilities.json sidecars.

## Baseline from current binaries

Measured 18 October with each specialist’s own shipped scorer; columns are right / wrong / false yes / withheld-on-valid. Correct refusals count as right.

| Specialist | Dev | Held-out |
|---|---|---|
| thermo | 44 / 0 / 0 / 0 | 50 / 0 / 0 / 0 |
| energy-v2 | 68 / 0 / 0 / 0 | 67 / 7 / 0 / 0 |
| energy-v3 | 74 / 0 / 0 / 0 | 70 / 0 / 0 / 0 |
| hvac | 41 / 0 / 0 / 0 | 42 / 0 / 0 / 0 |
| renewables | 26 / 0 / 0 / 0 | 23 / 0 / 0 / 3 |
| iot | 27 / 0 / 0 / 0 | 27 / 0 / 0 / 0 |
| geometry | 106 / 0 / 0 / 0 | 89 / 0 / 0 / 8 |
| geometry-v3 | 100 / 0 / 0 / 0 | 93 / 0 / 0 / 7 |
| geometry-v4 | 100 / 0 / 0 / 0 | 93 / 0 / 0 / 0 |
| statistics | 142 / 0 / 0 / 0 | 128 / 0 / 0 / 14 |
| statistics-v2 | 144 / 0 / 0 / 0 | 130 / 0 / 0 / 14 |
| statistics-v3 | 144 / 0 / 0 / 0 | 144 / 0 / 0 / 0 |

Energy-v2 has seven wrong passive bulb-swap replies. Geometry misses eight Heron questions; geometry-v3 misses seven imperative hypotenuse questions; statistics misses fourteen binomial phrasings; statistics-v2 misses fourteen dataset phrasings. Renewables misses three falling-height hydropower questions.

Only statistics-v1, renewables and iot panel generators exist in this upstream snapshot. The statistics-v1 generator can exercise all three statistics versions, but does not reproduce the added v2/v3 templates. Seeds 17118 and 28118 offset each generator’s original seeds. Seed 17118 was inspected during tuning; energy seed 28118 was evaluated only after the final reader freeze. Geometry/statistics seed 28118 remains untouched until its final build. No fresh-generator claim is made for the other seven specialist IDs.

Baseline probe counts (right/wrong/false yes/withheld): energy 3/10/9/0 (22 cases); geostats 6/8/5/1. These probes reveal ignored efficiency/depth and weight arguments. They are not independent of the recognizer author.

## Evidence and assumptions

Adjusted runtime: q * watts = capacity_Wh * efficiency * usable_depth, with Wh/kWh and Ah nonnegative, voltage and watts positive, and both factors in (0,1]. Mentioned but unread factors take a dedicated missing-input request; numeric zero takes the invalid-domain request. Also q = ideal_runtime * efficiency * usable_depth when both kernels answer. English recognition and unit extraction remain untrusted.

Weighted mean: accepted q times sum(weights) equals the sum of corresponding value-weight products; invalid lists return None exactly; unit weights equal the existing arithmetic mean. A further consequence bounds the exact mean by every interval containing the observations, using an independent weighted-sum induction. Lists must have equal length and nonnegative weights with positive sum; zero weights are allowed.

## Energy packet ready

Fresh Isabelle receipt: `var/energy/remote-attempts/20261018T071045Z-ecb42f269ea2/receipt.json`, passed, marker found, source stable, exports published. The actual Energy session finished; 102 theorem roots scanned with zero oracles. Generated SML SHA-256 `ac951cdf6896f07d65e2be482966d43a467eab7a94c5ef0b9059c0dd611f3cd6`. Final native binary SHA-256 `e7db4b4a22d23766c19390d6bb1ba9c9841180855d27f659d1f747b4e810276f`. Native context and sidecar additions include supported W quantities and running-cost operations; missing tariff remains a decisive refusal in family mode.

All six shipped panels are now perfect in both pinned and family mode. Dev/held-out right totals: thermo 44/50, energy-v2 68/74, energy-v3 74/70, hvac 41/42, renewables 26/26, iot 27/27. Every row has zero wrong, false yes and withheld-valid. This recovers seven wrong energy-v2 replies and three withheld renewables replies. Receipt: `var/c-physical-energy-geostats/energy-after.json`.

Both fresh seeds 17118 and 28118, each evaluated against the original organ and preserved pre-change binary: renewables dev/held-out 26/26 versus 26/23 with three withheld before; iot 27/27 throughout. All final fresh results have zero wrong/false yes/withheld-valid. Receipts: `var/c-physical-energy-geostats/energy-fresh-{17118,28118}-{before,after}/receipt.json`. Other four Energy identities have no available generators; no fresh-panel claim is made for them.

New capability probes: 22/22 right, zero wrong, false yes or withheld-valid, versus baseline 3/10/9/0. Covers factors, kW load, Ah/voltage capacities, invalid/missing factors, double-negative constituent inputs and zero voltage. Receipt: `var/c-physical-energy-geostats/energy-probes-after.json`. The primary source describes inverter efficiency; the finite constant-load algebra and stated factors are the model, not a detailed battery simulation. These are same-author probes, not an independent benchmark.

Binary size 776,712 bytes versus 760,920. Final cold runs 95.6, 3.5, 3.7, 3.1, 3.4 ms (first OS/cache load separately visible); baseline 107.9,12.2,10.3,8.1,10.5 ms. Pinned p50 per specialist 0.12–0.19 ms. Removing eager exported self-tests preserves build-time checks while avoiding work at startup. Timings are local observations, not a cross-machine claim.

Energy files: `Home.thy`, `Energy_Export.thy`, `recognizer.sml`, `main.sml`, `build.sh`, `README.md`, `capabilities.json`, `probes.json` under `src/extract/energy/`. Shared lane evaluation tools `src/extract/geostats/check_probes.py` and `check_fresh.py` are needed to reproduce the receipts. No upstream writes, no new axioms or admitted proofs. Existing wave-6 results are not counted as new work.

Representative consumer questions: “How long will a 1000 Wh battery run a 100 W load at 80% efficiency?” → runtime_adjusted 8 h; unknown efficiency → underspecified; −2 Ah at −12 V → impossible; running-cost request without tariff → need_tariff. Independent shared-runtime consumer capture passed 6/6 on the final binary: adjusted Wh and Ah/V runtime, missing factor, invalid constituent capacity, invalid factor, and missing tariff. All four declines were taken and decisive on energy-v3. Receipt: `var/c-physical-integration/energy-final-consumer.json`. Known unrelated semantic counterexamples and next work are recorded in `C-physical-energy-geostats-next.md`.

## Geometry/statistics validation pending

Fresh Isabelle proof revision, MLton compilation, shipped and frozen fresh comparisons, probe checks, performance and runtime consumer verification remain pending. No completion claim yet.

