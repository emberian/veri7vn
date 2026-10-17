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
| English recognizer | `regex.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs |
| JSON framing | `main.sml` | **untrusted** |

Statements and numbers: [lane S14 handoff](../../../project/lanes/S14-trades.md).

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Trades --session-root src/extract/trades \
  --expect 'VERI7VN_TRADES PASS' --timeout 1800
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/trades/tables_check.py
sh src/extract/trades/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/trades/score.py
```
