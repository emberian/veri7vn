# Quantity: temperature differences and explicit conditions

The temperature-difference packet is ready for commit and immutable capture. It follows numeral commit `7073a48`. Quantity and its variants now distinguish a temperature point from a signed difference, reject unread unit suffixes, and preserve the intended operation through conversion fallbacks. Other explicit-condition gaps listed below remain next work; they are not claimed fixed by this packet.

## What changed

`ConvertDelta` is a separate typed request from point `Convert`. It requires temperature scales on both sides, scales differences without an affine offset and permits negative differences without imposing an absolute-zero point guard. The new reply kind is `temperature_difference`; both family capability files declare it for all four unit specialists. Existing mismatch refusals cover temperature/linear dimension mismatches.

The reader binds interval meaning to the numeric role: “temperature change of 10 C”, “10 C difference”, delta-T = 10 C, and “convert 10 C to F as a temperature difference”. “Please change 10 C to F” and unrelated trailing discussion remain point conversions. Rise/drop wording converts the stated magnitude; it never invents a sign. Signed numeric changes preserve their signs. Multiple endpoints and explicit uncertainty remain unclaimed until every role can be bound; the reader does not guess from the last scalar.

A complete-unit boundary now prevents `F/s`, `F per minute` and `cm^2` from being shortened to `F` or `cm`. Direct and quantity-first conversion paths share it. Registered compound units still match as complete units. Celsius/Fahrenheit degree-letter aliases now agree with the existing full scale names.

## Checked statements and fresh export

The genuine hbox attempt is `var/quantity/remote-attempts/20261018T080019Z-5b61eabada88/`: actual target completion, 53 checked roots, zero oracles and published export SHA256 `e524a556888530711cf81bff30962aae541a0303008f25526b0bd066a8768c0b`. The three new checked statements are:

```isabelle
kernel (ConvertDelta x (Tmp a) (Tmp b)) =
  Exact K_temperature_difference (tdelta a b x)

kernel (ConvertDelta (tdelta a b x) (Tmp b) (Tmp a)) =
  Exact K_temperature_difference x

kernel (Convert x (Tmp a) (Tmp b)) = Exact k u ⟹
kernel (Convert y (Tmp a) (Tmp b)) = Exact k' v ⟹
kernel (ConvertDelta (x - y) (Tmp a) (Tmp b)) =
  Exact K_temperature_difference (u - v)
```

Here `tdelta a b x = x * tscale a / tscale b`. The endpoint law connects the new consumer to the existing affine point model. The first attempt `20261018T075024Z-a21daa6033de` failed with a distributive field identity remaining in that proof. Adding `diff_divide_distrib` closed the unchanged statement; no failed export was installed. No axioms or admitted proofs were added.

Existing `Convert`, pressure and fuel constructor signatures remain unchanged for Fusion and other consumers. Future live Fusion proof builds must bind their Quantity dependency; runtime already captured the previous Fusion proof closure independently.

## Consumer evidence

`conditions_check.py` is explicitly untrusted authored evidence. It checks exact Fraction scale ratios, signed intervals, point controls, role wording, mismatches and unsupported multi-input/unit suffix cases. Baseline binaries are the immutable numeral captures under `var/C-runtime-package/bound-prepared/20261018T073902Z-6cfbea65b624/quantity/` and `20261018T073932Z-8da36b3b3ad1/variants/`. A wrong count includes the wrong point/difference meaning or reply kind even when one scale pair happens to produce the same number.

| Specialist | Baseline right / wrong / false yes / valid withheld | Final right / total | Final wrong / false yes / valid withheld |
|---|---:|---:|---:|
| units | 8 / 35 / 6 / 10 | 59 / 59 | 0 / 0 / 0 |
| units-v3 | 8 / 36 / 6 / 9 | 59 / 59 | 0 / 0 / 0 |
| units-v2 | 8 / 36 / 6 / 9 | 59 / 59 | 0 / 0 / 0 |
| units-v3-r2 | 8 / 36 / 6 / 9 | 59 / 59 | 0 / 0 / 0 |

Tuning used seed 2026102201; the final reserved numerical values use 2026102209. Final total is 236/236, with zero wrong answers, false yeses and valid withheld answers. No tuning followed the final evaluation. All 319 earlier numeral cases remain correct; acoustics in that regression is the unchanged captured binary. All 44 earlier quantity probes remain correct.

Final shipped and fresh panel totals below include dev plus held-out. Fresh generators use seeds 2026102209/10 and retain the inherited template/table lineage disclosed in the earlier reports.

| Specialist | Shipped right / total | Fresh right / total | Wrong / false yes / valid withheld |
|---|---:|---:|---:|
| densities | 102 / 102 | 102 / 102 | 0 / 0 / 0 |
| units | 152 / 152 | 152 / 152 | 0 / 0 / 0 |
| units-v3 | 151 / 151 | 152 / 152 | 0 / 0 / 0 |
| springs | 84 / 84 | 84 / 84 | 0 / 0 / 0 |
| fluids | 68 / 68 | 68 / 68 | 0 / 0 / 0 |
| fuels | 84 / 84 | 84 / 84 | 0 / 0 / 0 |
| densities-r2 | 102 / 102 | 102 / 102 | 0 / 0 / 0 |
| units-v2 | 149 / 149 | 152 / 152 | 0 / 0 / 0 |
| units-v3-r2 | 151 / 151 | 152 / 152 | 0 / 0 / 0 |

Independent composed checks also pass: parent 12/12 (`var/c-physical-integration/quantity-conditions-consumer.json`) and dispatch owner 24/24 across all four unit IDs with routes and guards enabled (`var/dispatch/quantity-delta-composed.json`). They verify signed −400 C intervals, F-to-K differences, ordinary “change” wording, point absolute-zero refusal, dimension mismatches and compound-unit/multiple-endpoint refusals. No fallback restored the old point answer.

## Actual native inputs and timing

Both native builds consumed immutable copied SML inputs and the checked export above. Their manifests bind the final shared numeric parser SHA256 `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`. Variants captures its transformed recognizer as a distinct actual input, with the same package transformation check used for the numeral packet.

| Binary | Bytes | SHA256 | Input manifest |
|---|---:|---|---|
| quantity | 614008 | `c4fea57b40b217a73ab0f6e6a5f892b441d42e387512451ad1bc6ee8c8648e89` | `var/quantity/native-attempts/20261018T080856Z-5155a9e20570/compile-inputs.json` |
| variants | 631192 | `6440b9534af842474ca4c85cdce81a0ffe0e073e80068e13c852ccc9429f3247` | `var/variants/native-attempts/20261018T080922Z-ccffe80bcad2/compile-inputs.json` |

For the new explicit difference request, five-process cold medians are 7.858 ms (quantity) and 7.571 ms (variants); 50 warm-request p50s are 0.048 ms and 0.137 ms. Cold starts remain above the 5 ms aspiration. Timing is local and scoped, not a broad speed guarantee. Full shipped per-specialist timings are in `conditions-panels/report.json`.

All scoped reports are under `var/c-physical-quantity-sound/`: `conditions-before.json`, `conditions-tuning.json`, `conditions-final.json`, `conditions-panels/report.json`, `conditions-numeric-regression.json` and `conditions-delta-timing.json`. Reproduce with `python3 -B src/extract/quantity/conditions_check.py --out var/c-physical-quantity-sound/replay-conditions.json --seed 2026102209`; optional binary arguments select the captured baseline.

## Explicit conditions still requiring a model

The original scout is `var/c-physical-quantity-sound/next-explicit-conditions-scout.json`. These observed defaults remain outstanding:

| Request | Observed current/default answer | Required next behavior |
|---|---|---|
| Liquid-water density at 100 C | 1000 kg/m3, typical near 20 C | Apply a temperature-dependent model or consume a specific unsupported-condition refusal. |
| Air density at 10 atm | 1.204 kg/m3 | Apply pressure/temperature state or refuse the unsupported lookup. |
| Mass of 2 litres of zinc at 500 C | 14.27 kg from typical-state row | Apply an appropriate phase/state model or refuse. |
| Useful heat from 100 kg wood at 50% boiler efficiency | 1560 MJ | 780 MJ under the same NCV model with one-way useful efficiency. |
| Wood energy at 50% moisture by mass | 1560 MJ | Refuse unless calorific basis and moisture treatment are supported; dry-fraction multiplication alone is not justified. |
| Absolute pressure 2 m below water, surface pressure 200000 Pa | About 120900 Pa using standard atmosphere | About 219600 Pa under the same density/gravity model with supplied surface pressure. |
| Gauge pressure 2 m below water, gravity 1.62 m/s2 | About 19610 Pa | 3240 Pa with supplied gravity. |
| Sound speed at 20 C and 80% relative humidity | 343.2 m/s dry-air result | Apply a humid-air model or refuse the unsupported condition. |

Hydrostatics should take explicit surface pressure and gravity, sharing the same density/gravity/depth inputs across absolute and gauge calculations. Useful fuel heat should take bounded one-way efficiency, with `useful = efficiency * released` and a checked physical domain. Moisture and calorific basis are separate model conditions. Fixed material rows and dry-air sound need explicit policy for supplied states. These should consume actual operation/condition roles; arbitrary keyword bans or silently ignored parameters are not substitutes.
