# The trades family, end to end

This folder carries six shipped Oracle7 specialists as one program: `architecture`,
`printing`, `printing-v2`, `safety`, `woodworking` and `crafts`
(`upstream/root/specialists/<id>/organ_*.py`). They are everyday trade arithmetic:
floor area ratio and occupant loads, filament length and cost, noise dose and the
NIOSH lifting limit, board feet and rafters, knitting gauge and colour mixing.

- The formulas, the rounding rules (round up, round down, nearest) and the decisions to
  decline are written in Isabelle/HOL, with proofs. Occupant loads, layers, sheets,
  risers and blocks are exact rational arithmetic, including the organs' 1e-9 slack.
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
| English recognizer | `../commons/commons.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs |
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
