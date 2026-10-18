# The quantity family, end to end

This folder carries six shipped Oracle7 specialists as one program: `densities`,
`units`, `units-v3`, `springs`, `fluids` and `fuels`
(`upstream/root/specialists/<id>/organ_*.py`). They are one family. Each one reads an
amount with a unit (2 litres, 0.25 m, 30 kg), uses exact unit factors, a density
table or a fuel table, and applies a short physical formula. Here they share one typed
quantity: every amount is an exact fraction with a unit, every unit has a dimension
(length, mass, volume, ...) and an exact factor to SI units, and every formula reads
its amounts in SI units.

- The formulas and the decisions to decline are written in Isabelle/HOL, with proofs.
- The program that answers is a HOL function. Isabelle turns it into Standard ML, and
  the MLton compiler that ships inside Isabelle turns that into one standalone binary.
  No Isabelle process runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md). With
  `--specialist ID` it reads questions the way that one manifest's organ does. Without
  it, it asks the whole family in a fixed order (fuels, springs, fluids, densities, units).

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Units, dimensions, exact SI factors, temperature scales, densities, fuel values | `Quantity.thy` | HOL constants, copied from the organs and checked by `tables_check.py` |
| Requests, declines, kernel, rounding, reply text | `Quantity.thy` | HOL, proved; exported to SML |
| Export, self test, oracle check | `Quantity_Export.thy` | HOL; the build fails if any listed theorem depends on an oracle or the self test fails |
| Interval arithmetic (spring period and frequency only: a square root and pi) | Isabelle's `HOL-Decision_Procs.Approximation` | Isabelle library, proved there |
| Table transcription check | `tables_check.py` | a Python check of the HOL text against the organ files; it is not a proof |
| Reading numbers and words out of English | `../commons/commons.sml` (Regex), `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions |
| JSON framing | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

Every kind except the spring period and frequency is computed **exactly** in rational
arithmetic. The kernel's main theorem, `kernel_exact_sound`, says that an exact value
is stated only for a request that is fully specified, has the right dimensions and is
possible, and that the value is the request's value. A theorem for each kind gives its
defining equation. For example, mass times the unit factor equals density times volume.
A conversion times the target factor equals the amount times the source factor, and
conversions compose. A temperature names the same absolute temperature on both scales,
and the theorems show it is not a temperature difference: the two differ by the gap
between the scales' zero points. CO2 equals the energy released times the emission
factor. The fraction of a floating solid below the surface times the fluid density
equals the solid density. The period is computed by enclosing the real value
`2 pi sqrt(m/k)` in a verified interval and rounding to four digits. `kernel_approx_sound`
bounds the error at one part in a thousand, `spring_period_model` proves
`T^2 k = 4 pi^2 m`, and `spring_frequency_model` proves `f T = 1`. The kernel declines as underspecified exactly when an amount is
missing, as a mismatch exactly when the dimensions are wrong (metres to kilograms), and
as impossible exactly when the input is impossible (below absolute zero, or a zero
spring constant or stretch). Statements: [lane G handoff](../../../project/lanes/G-quantity.md).

Stated values are rounded with a proved bound (`stated_dec_sound`). Conversions use ten
significant digits, or the exact whole number with the exact fraction alongside, as
units v2 prints them. The other organs use four digits, as `%.4g` gives. An exact
decimal tie rounds up (`round_tie_up`). The organs round a binary float, so on a tie
like 0.015 x 745 = 11.175 they can print the lower neighbour (11.17 against 11.18 here). How the digits
are laid out as text (`render_dec`) is checked by the self test and by the panels. It
is not proved.

Codex's `src/families/domains/Domain_Quantities.thy` already proves exact linear units
and the difference between temperature points and differences. Its unit factors are the
same numbers as the ones here. This folder does not import it, for two reasons. That
session sits on `Veri7vn_Codegen` and `Veri7vn_Plans`, which this binary does not need.
Its unit type also has no unit names, no cm3, ft3, MJ, GJ or MWh, and no link to the
organs' tables. The definitions here are local, and `tables_check.py` ties them to the
organ files.

## Build and run

```sh
# 1. prove and generate (the only Isabelle build; takes the shared lock)
python3 tools/dev/check-native --session Veri7vn_Quantity \
  --session-root src/extract/quantity --expect 'VERI7VN_QUANTITY PASS' --timeout 900
# 2. the tables have not drifted from the organs
python3 src/extract/quantity/tables_check.py
# 3. export the generated SML and compile var/quantity/bin/quantity
sh src/extract/quantity/build.sh
# 4. ask it something
echo '{"id": "1", "q": "What is the mass of 2 litres of zinc in kg?", "session": "s"}' | var/quantity/bin/quantity
# 5. score on the six shipped panels, each manifest alone and as a family, and compare with the organs
python3 src/extract/quantity/score.py
```

The binary is not committed; it lives under `var/quantity/bin/`.

## Current result

On every one of the six shipped panels, both splits, every item is right: 0 wrong and
0 false yes. That holds per manifest (`--specialist ID`) and as one family. The shipped
held-out numbers are densities 51/51, units 76/76, units-v3 75/75, springs 42/42,
fluids 34/34 and fuels 42/42; the binary matches each. Every reply also agrees with the
shipped organ on the same question: same answered or withheld status, same kind, and
the same value within the scorer's tolerance. The binary is 545 KB and starts in about
7 ms. The median time per question is under 0.25 ms, against a budget of 50 ms. Details:
[lane G handoff](../../../project/lanes/G-quantity.md).
