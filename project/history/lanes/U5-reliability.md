# U5 reliability: geometry answers retain their dimensions

The supported geometry fallback now returns **12 m²**, **14 m**, and **12.5 m²**
for the original room-area, perimeter and rounded-area requests. Same-unit
centimeter, foot and other supported calculations keep their own unit instead
of being relabeled as meters. Circle and volume formulas carry the appropriate
first, second or third power of the unit. The actual word module and w488
consumer pass **51 focused tests**; no full Engine, build or specialist panel was
run in U5. No theorem or Mini admission claim is made.

## Evidence and the bounded repair

The actual U4-v2 full-Engine receipts in
`var/u4-service/u4-v2-real/calls.jsonl` contained seven correct numeric geometry
answers whose units were incomplete: six said “square units,” including the
rounded 12.5 result, and the perimeter reply was bare 14. The service report at
`project/lanes/U4-service.md` explicitly distinguished these from completed
answers. Those original receipts remain unchanged.

The existing dimension reader already requires a common length scale across
all supplied dimensions. The repair maps that checked scale to its canonical
unit (`mm`, `cm`, `m`, `km`, `in`, `ft`, `yd`, `mi`) and carries the formula's
power: 1 for perimeter/circumference, 2 for area, 3 for volume. A small shared
result constructor serves all seven existing geometry formulas. Raw numerical
values and formulas are unchanged. Equal-scale aliases such as `feet`/`ft`
are compatible; mixed scales remain refused rather than multiplied as raw
numbers or silently converted.

The recognizer's machine-facing `unit` is `m`, `m^2`, `cm^3`, and so on. The
w488 consumer renders powers as superscripts and carries the unit alongside
the numeric value in provenance. Existing rounding changes only the scalar,
so a rounded area remains squared and a rounded volume remains cubed. This is
an explicitly untrusted Python calculation and formatting contract, not a
proof of the English parse or of the answer's admission.

A new independent ambiguity test caught an existing parse error before delivery:
`length 3 in the diagram` was interpreted as three inches. The geometry reader
now accepts `in` as the inch abbreviation only at a measurement boundary
(end/punctuation, conjunction, or a long/wide/tall/high suffix). It declines the
prepositional example, while `length 3 in and width 4 inches` gives 12 in².
This is a bounded ambiguity guard, not a general natural-language unit resolver.
Other unknown units and non-length units stay outside the geometry reader.

## Actual consumer checks

The independent numerical/dimensional expectations include:

- Rectangle: area 3 × 4 = 12 units²; perimeter 2 × (3 + 4) = 14 units.
- Circle, radius 3 cm or diameter 6 cm: area 9π cm², circumference 6π cm.
- Cone, radius 2 cm and height 3 cm: volume 4π cm³.
- Cylinder, radius 2 in and height 3 in: volume 12π in³.
- Sphere, radius 2 ft: volume (32π/3) ft³.
- Rounding: 3.12 × 4 = 12.48 m² rounds to 12.5 m²; cylinder radius 1.2 cm,
  height 3.4 cm rounds to 15.4 cm³; radius 1 m circumference rounds to 6.3 m.

All supported length spellings/scales are checked for area and perimeter.
The seven original U4 question strings are retained unchanged in
`var/usage-20261026/reliability/u5/consumer-comparison.json`. That file separates
the recorded U4 Engine reply from before/after **controlled component** calls.
It shows six dimensioned area results and one dimensioned perimeter result;
it is not a new appliance or Engine receipt.

The tests use the existing harness's actual word module and w488 class with
unchanged AST-selected w480 timing/answered helpers and a substituted expensive
parent. No stores or full head are launched. Assertions check numerical values,
the module unit, the consumer's provenance unit, and its rendered answer unit.
They deliberately preserve U4's scalar/clarification semantics. Contradictory
radius/diameter and duplicate lengths remain clarified; multiple shapes,
multiple requested measures and explicit target-unit requests remain bounded
refusals. Apartment identifiers are not treated as dimensions. Mixed and
malformed units receive no new numeric answer. Zero area retains a unit.

## Changes and reproducible checks

Authorized mutable source files:

- `var/ap1-upstream-slim/root/wander-train/word_problems_v1.py`
- `var/ap1-upstream-slim/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w488.py`

Public U5-owned additions:

- `tests/usage/reliability/test_geometry_units.py`
- `project/lanes/U5-reliability.md`

No existing tracked test was edited; all 38 U4 tests retained their assertions.
Root owns the source checkpoint, portable patch export and next candidate.
No Git/staging command, immutable candidate edit, or subagent was used.

Exact final check:

```
.venv/bin/python -B -m unittest discover -s tests/usage/reliability -v
```

Result: **51 tests passed** (38 existing plus 13 new), 0.034 seconds in the
retained run. Full output:
`var/usage-20261026/reliability/u5/tests.txt`.

Pre-edit and final SHA256 maps:
`var/usage-20261026/reliability/u5/{base-hashes,patched-hashes}.json`.
Final source hashes:

- Word module: `6a22393a62de0b677977499c658fa1d9033a8d22d4414d47c5bab24e574c9532`.
- w488 consumer: `c9e3ea08175080f779ff7ae5e93cf5743ca32f693ccb6503e148fc195b9305a4`.

This repair stops at dimensional completion for already supported formulas.
Mixed-unit conversion, requested output-unit conversion, aggregation across
shapes, multiple-measure answers, broader unit grammar and the earlier speed
or spelled-negative-temperature refusals remain outside scope. The numeric
formatter's existing precision and the previous formula-selection behavior
are unchanged. A future root-coordinated full-Engine replay must confirm that
later serving folds preserve these dimensioned replies.

## Root checkpoint

Root reviewed both complete source diffs and reran the 32 geometry-named
consumer tests successfully. Private-source checkpoint: `05fa1a2`.
The portable patch is `tools/usage/reliability/u5-geometry-units.patch`, applied
after the U4 geometry patch. A fresh U5 candidate will check the full Engine.
