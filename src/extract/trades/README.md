# The trades family, end to end

This folder carries six shipped Oracle7 specialists as one program: `architecture`,
`printing`, `printing-v2`, `safety`, `woodworking` and `crafts`
(`upstream/root/specialists/<id>/organ_*.py`). They are everyday trade arithmetic:
floor area ratio and occupant loads, filament length and cost, noise dose and the
NIOSH lifting limit, board feet and rafters, knitting gauge and colour mixing.

- The formulas, the rounding rules (round up, round down, nearest) and the decisions to
  decline are written in Isabelle/HOL, with proofs. Occupant loads, layers, sheets,
  risers and blocks use exact rational ceilings and floors: enough units cover the
  requested amount, or the largest whole count fits within it.
- Quantities that need pi, a square root, an arctangent, a power of 2 or a logarithm
  (filament length and mass, rafter length, roof angle, noise time, dose and TWA) are
  enclosed in a verified interval and rounded to the organs' digits.
- The program that answers is a HOL function exported to Standard ML and compiled with
  the MLton inside Isabelle into one standalone binary, `var/trades/bin/trades`. It speaks
  the [answerer contract](../../../docs/contracts/answerer.md). `--specialist ID` reads
  questions the way that one manifest's organ does; with no argument it asks the family in
  a fixed order (safety, architecture, printing-v2, woodworking, crafts).

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Interval arithmetic, rounding with a proved bound, digit layout | `Trades_Num.thy` | HOL, proved (copied from lanes D and G, extended with fixed-decimal enclosure) |
| Tables: occupancy factors, filament densities, lumber sizes, sheets, colour wheels, NIOSH constants | `Trades.thy` | HOL constants, checked against the organs by `tables_check.py` |
| Requests, declines, kernel, reply text | `Trades.thy` | HOL, proved; exported to SML |
| Export, self test, oracle check | `Trades_Export.thy` | the build fails if a listed theorem uses an oracle or the self test fails |
| English recognizer | `../commons/commons.sml`, `../commons/numeric.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs |
| JSON framing | `main.sml` | **untrusted** |

Statements and numbers: [lane S14 handoff](../../../project/lanes/S14-trades.md).

## Build and run

```sh
tools/dev/remote-build persvati src/extract/trades Veri7vn_Trades \
  -d src/extract/commons --expect 'VERI7VN_TRADES PASS'
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/trades/tables_check.py
VERI7VN_GENERATED=/path/from/successful/receipt/trades.ML sh src/extract/trades/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/trades/score.py
```

## Completing the intended calculations

The printing specialist recognizes printed parts, and woodworking recognizes
board footage with inch marks on the thickness and width. Crafts now computes
rows from a stated row gauge and target length, including inch/cm conversion.
Its kernel receives gauge row count and gauge span separately, refuses a
nonpositive span or negative count or length, and rounds to the nearest whole
row with ties to even. This assumes a uniform gauge throughout the work.

`capabilities.json` adds the `rows` kind and its in-domain refusal to dispatch
and packaging. Row replies name the selected binding theorem. The English
reader remains untrusted.

`score.py --fresh-seed 20261018 --out var/trades/fresh-score.json --probes`
runs fresh samples and authored extension probes. Fresh seeds select from the
same shipped pools and phrasings; they are not independent question design.
The safety folder ships no generator, so its original panel is retained and
explicitly marked as not fresh in `generation.json`.

The shared numeral reader preserves exact signed decimals, scientific notation
and fractions in row gauges. Count replies carry the selected model law; the
English role binding remains untrusted. Boundary probes include amounts just
above or below an integer, where floating-point epsilon rules gave wrong counts.

NIOSH questions preserve whether weight limit or lifting index was requested.
A lifting index needs a load; missing load does not turn the request into a
weight-limit calculation. Numeric inputs use the shared exact reader. Necessary
model guards require nonnegative geometry and load, FM between zero and one,
and CM equal to 0.90, 0.95 or 1.00. The conditional weight bound is 0–23 kg.
These checks do not establish the correct table row or whether the equation
applies to an actual lifting task.

RGB colour composition accepts lists of named full digital channels and combines
them by saturation. All three primaries give white; black contributes no channel.
Every output channel comes from an input and every input channel is preserved.
This does not compute brightness ratios, spectra, weighted continuous colour
or paint mixtures. RYB paint retains its separate named wheel.


G staged board-foot correction: dimension products and named thickness/width/
length fields use the shared exact numeric lexer and shared unit adapter. Unit
parsing is applied to the complete isolated grammatical unit field, whose byte
spans are local to that field. The grammar consumes the source field before
assigning a role; requested output units cannot supply a source dimension.
Typed inch, foot, centimetre and millimetre tags reach HOL, which performs every
unit conversion and rectangular-volume calculation. Bare thickness/width in
conventional products mean inches; the length needs an explicit unit. The
kernel requires nonnegative dimensions and an integral nonnegative complete-
piece count. Partial-board quantities are valid requests outside this model.
No nominal-to-dressed correction, irregular shape or waste allowance is inferred.
The two independent laws bind the result to cubic inches/144 and prove its
nonnegativity. English extraction and native compilation remain untrusted.

Explicit piece counts are never treated as missing: numerals retain exact value,
word counts from zero through ninety-nine use a finite grammar, and unsupported
quantifiers or multiple groups are withheld. A plural source without a count
does not silently become one piece.


Printing layer counts preserve the separate length units of the part and each
uniform layer. The result is the least whole number of layers covering the part:
a 2 cm part with 0.2 mm layers needs 100 layers. Part height may be zero but
cannot be negative; layer height must be positive. Adaptive layers, separate
first-layer heights and rates such as mm/s need a different model.

Fabric conversion treats length as continuous: half an inch is 1/72 yard, not
five inches or a rounded-up purchase quantity. Inches, feet, yards, millimetres,
centimetres and metres are supported, including exact fractions and small
positive lengths. Negative lengths are refused. Width, area, waste allowances
and strip layouts are not represented by this length-only calculation.

The isolated Crafts reader refuses negative fabric lengths. The full default
system currently can select a generic signed unit conversion instead; this
composition gap is tracked by `check_composition.py`, which presently passes
three of four checks and exits with failure. Signed conversion alone remains
valid; the missing distinction is the physical fabric constraint.
