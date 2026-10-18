# The energy family, end to end

This folder carries six shipped Oracle7 specialists as one program: `thermo`, `energy-v2`,
`energy-v3`, `hvac`, `renewables` and `iot` (`upstream/root/specialists/<id>/organ_*.py`).
Each reads numbers off a short English question and applies one formula: heat to change a
temperature or melt ice, the ideal gas law, Carnot efficiency, Stefan-Boltzmann radiation
(thermo); energy used by a device, its cost at a stated tariff, battery runtime, solar yield,
payback, swapping a bulb (energy); air changes, airflow heat, tons of cooling, conduction
(hvac); wind, hydro, photovoltaic output, capacity factor (renewables); ADC codes, duty-cycled
battery life, Nyquist, data rate (iot).

- The formulas and the decisions to decline are written in Isabelle/HOL, with proofs.
- The program that answers is a HOL function. Isabelle turns it into Standard ML, and the
  MLton compiler that ships inside Isabelle turns that into one standalone binary
  (`var/energy/bin/energy`, not in git). No Isabelle process runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md). With
  `--specialist ID` it reads questions the way that one manifest's organ does. Without it, it
  asks the family in a fixed order (thermo, hvac, renewables, iot, energy-v3), each behind its
  manifest's context regex.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Rounding, number layouts, generic four-stage kernel, reply record | `Energy_Core.thy` | HOL, proved; the interval and rounding lemmas are lane G's, copied |
| thermo kernel (tables, requests, declines, values, text) | `Thermo.thy` | HOL, proved |
| energy-v2 / energy-v3 kernel | `Home.thy` | HOL, proved |
| hvac kernel | `Hvac.thy` | HOL, proved |
| renewables kernel (rotor area is pi times a rational) | `Renewables.thy` | HOL, proved; digits from `HOL-Decision_Procs.Approximation` |
| iot kernel | `Iot.thy` | HOL, proved |
| Family request type and dispatcher | `Energy_Family.thy` | HOL |
| Export, self test, oracle check | `Energy_Export.thy` | the build fails if any listed theorem depends on an oracle or the self test fails |
| Table transcription check | `tables_check.py` | a Python check of the HOL text against the organ files; not a proof |
| Reading numbers and words out of English | `../commons/commons.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions |
| JSON framing | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

Every value is computed **exactly** in rational arithmetic. The one exception is a wind
turbine given by rotor diameter or blade length: its swept area is pi times a rational, so
the kernel returns that rational (`PiMul`) and the digits are enclosed by Isabelle's verified
interval arithmetic (`pi_bounds_sound`); a result whose enclosure straddles a unit boundary
(W against kW) is refused, never guessed.

Each kernel is the generic `mk_kernel` of `Energy_Core.thy` with four stages in the order the
organ tests: an up-front impossibility, a missing quantity, a late impossibility or refusal,
an answer with no number; otherwise the value. `mk_exact`, `mk_pi`, `mk_fixed` and
`mk_decline` say what each outcome means; each family states its defining equations on top
(`carnot_law`, `gas_*_law`, `radiated_power_law`, `payback_law`, `runtime_law`, `ach_law`,
`conduction_law`, `capacity_factor_law`, `wind_power_*_law`, `adc_code_law`, `battery_life_law`,
and so on). Statements: [the handoff](../../../project/lanes/S06-energy.md).

Stated values are rounded with a proved bound (`num_dec_r_sound`): `%.4g` for thermo, `%.4g`
below a million and whole above for home energy, and so on per organ (the `nfmt` layouts).
An exact decimal tie rounds up (lane G's `round_tie_up`); Python's `round` and `%f` round a
binary tie to even, so a tie like 4.4145 MW can differ in the last printed digit. How the
digits are laid out as text (`layout`) is checked by the self test and by the panels; it is
not proved.

## Typed requests (what fusion calls)

`Energy.family_request` is `FThermo request | FHome home_req | FHvac hvac_req | FRen ren_req |
FIot iot_req`. thermo takes `Thermo ts q`: `ts` is every temperature the question names, in
order (`Temp value unit`), and `q` says what is asked (`TCarnot`, `TGas`, `TRad`, `TFusion`,
`TVapor`, `TSens`). `Energy.reply_of` returns answered/withheld, the kind, the response text
and (where plain) the stated number.

## Differences from the organs

All in the kernel's favour, none on the panels: a zero divisor (room volume, current,
reference voltage, rated power, gas volume or pressure) is refused as impossible where the
organ raises; the ADC code is the exact floor (the organ adds 1e-9 against float error); the
reply text is plain ASCII (m^3, 1/2, x, /) where the organs print Unicode symbols.

## Build and run

```sh
# 1. prove and generate (the only Isabelle build; takes the shared lock)
python3 tools/dev/check-native --session Veri7vn_Energy \
  --session-root src/extract/energy --expect 'VERI7VN_ENERGY PASS' --timeout 1500
# 2. compile the binary (reads the session database, runs MLton; no Isabelle build)
sh src/extract/energy/build.sh
# 3. check the tables against the organs
python3 src/extract/energy/tables_check.py
# 4. score on the shipped panels (lane A's harness)
python3 tools/parity/harness.py --answerer "var/energy/bin/energy" \
  --specialist thermo,energy-v2,energy-v3,hvac,renewables,iot --split both --out var/energy/parity
# own cross-check against the organs, per specialist and for the whole family
python3 src/extract/energy/score.py
```

## Beyond the shipped versions (Codex, 18 October)

The home-energy readers now share the complete passive-swap grammar, so the
older energy-v2 name no longer answers a saving question with total usage.
Hydropower also reads a stated falling height. A new `runtime_adjusted` request
uses nominal battery energy times inverter efficiency times usable depth,
divided by a constant load. Unmentioned factors are one; a mentioned factor
without a numeric value takes the dedicated missing-factor request and is declined
as underspecified. A round-trip efficiency cannot supply the one-way factor. Each factor lies in [0,1]. Zero efficiency or usable depth gives zero runtime; a zero load is still refused. This is a constant-load energy budget, not a discharge-curve model;
voltage sag, idle consumption, ageing and Peukert effects are outside it.

The two runtime laws connect the adjusted result to delivered energy and to
the existing ideal runtime. The capability sidecar declares this new kind to
the shared runtime. `probes.json` supplies numeric and invalid-input checks;
these were authored alongside the recognizer and are not independent evidence.

The build-time self-test still runs and the final oracle scan remains mandatory.
The self-test is no longer exported as an eager startup value. To compile a
checked remote export, pass its SML path as the first argument to `build.sh`.


## Physical domains and numeric recognition

Physical magnitudes retain their signs until the typed request is checked.
Mass, area, generated power inputs, currents and capacities cannot become
positive by dropping a minus sign or multiplying two invalid constituents.
Temperatures in Celsius/Fahrenheit and temperature differences can be negative;
valid cooling can still produce a signed heat transfer. Zero production and
conversion factors have their ordinary zero-output meaning. Duty-cycle current
stays between the active and sleep currents.

Every captured scalar, including alternation groups and integer counts, must
cover an entire token issued by the shared exact numeric lexer. Values come
from that token. Explicit `R13`/`R-13` insulation labels are normalized as labels;
`R-value -13` remains a negative scalar. Physical scalar readers and adjusted
runtime accept decimals, scientific notation, fractions and Unicode minus.
Older home billing and integer-role grammars remain narrower and may decline
otherwise valid spellings. Unsupported `1×10^3` notation cannot donate its
trailing exponent to another quantity role. The adapter and role recognition
remain untrusted. `domain_probes.json` records examples and counterexamples;
it is a same-author set, not an independent benchmark.
