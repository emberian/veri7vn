# Word problems with explicit quantities and units

This program answers a finite set of single-step questions: percentages,
prices, simple interest, unit conversion, motion, and common geometric
measures. It reads one JSON question per line and returns an answer or a
refusal through the [answerer contract](../../../docs/contracts/answerer.md).
English recognition is untrusted. Isabelle/HOL defines the arithmetic,
conditions for answering, and rendered response; its exported Standard ML
runs as a standalone native executable.

The unit-aware kernel passed its fresh proof build with 49 theorem checks and
zero oracles. Its immutable native build passes 34 input boundary cases and
four actual guard-composition cases. The previous executable and measurements
remain recorded in `project/lanes/C-runtime-routes.md`; the current receipts
and limits are in `project/lanes/D-runtime-routes.md`.

## Measured questions

`Wordprob_Units.thy` retains the unit of each length, duration, and rate,
including the rate denominator and requested output unit. For example:

- A rectangle with sides 2 m and 30 cm has area 0.6 square metres.
- A speed of 60 km/s sustained for 2 hours gives 432000 km.
- A distance of 60 km in 2 hours gives about 8.33333 metres per second.

The supported length and time units come from the existing 49-entry unit
table. Geometry scales every length to metres, computes the shape measure,
and divides by the requested length scale to the appropriate power. Motion
also scales both time units. Missing or ambiguous roles and unsupported
units are refused. The kernel independently checks dimension kinds,
nonnegative physical inputs, and positive duration for speed.

The geometry model uses either 157/50 when the question selects pi = 3.14,
or the exact rational value of the original IEEE-double pi constant,
884279719003555/281474976710656. Its scale and conservation laws concern
that rational model. They do not give an error bound against true pi or
establish that a physical object is an ideal geometric shape.

Measured answers render six significant digits directly. In particular,
small areas are not first rounded to six decimal places and lost as zero.
With no explicit decimal-place request, `measured_precision` bounds display
error relative to the rational model value by 1/200000 of its magnitude.
Explicit decimal-place rounding uses the existing `round_dec` operation,
which rounds ties upward, before significant-digit rendering.

The new connected statements are:

- `geometry_unit_conservation`: multiplying the result by the output unit
  scale raised to the shape degree recovers the formula on metre-scaled
  inputs.
- `geometry_scale_law`: scaling both input lengths by k scales the measure
  by k to that same degree.
- `distance_unit_conservation` and `speed_unit_conservation`: converting a
  result back to base units preserves distance = speed × time, with nonzero
  duration where division requires it.
- `speed_distance_inverse`: computing speed and using it for the original
  duration recovers the original distance, even across different units.
- `measured_answered_iff` and `measured_reply_states_value`: the exported
  reply answers only with valid dimensions/domain and available rendered
  digits, and states those digits.

These statements assume the typed request. They do not prove that the
English reader chose the right roles. The new `measured.sml` adapter uses
`../commons/numeric.sml` for exact numeric tokens, including signed decimals,
fractions, scientific notation, and grouped digits. It binds units and roles
using numeric masks resolved through the scanner's table. Invalid or
unsupported readings produce explicit recognizer refusals carrying no
kernel claim. The older price/percentage schemas retain narrower decimal
syntax and now reject shared tokens that their patterns would truncate.

## Existing arithmetic and composition

`Wordprob.thy` retains the original finite formulas, money rounding,
exactly-one-schema rule, and decimal rendering proofs. Money ties round up:
12.5% of $1 is stated as $0.13. Its older reply rendering applies preliminary
decimal-place rounding; the measured entry point above avoids that step
unless explicitly requested.

Replies do not claim that their English interpretation was checked, or that
an independent second calculation ran. The theorem names in provenance are
a static inventory, not a per-answer proof certificate. JSON framing,
recognition, and routing remain untrusted; Isabelle's code generator and
MLton are part of the trusted toolchain.

No recognized schema means `taken=false` and allows another route to try.
A recognized impossibility, invalid dimension, ambiguity, or unsupported
measured input returns `taken=true` and stops routing. The precision guards
subsequently inspect actual answered replies. Their G6 unit-letter check is
restricted to the symbolic evaluator: printing the unit of a typed
quantity is not evidence of treating that unit as a variable.

## Build and checks

Use the project's managed build driver and a successful immutable export:

    python3 tools/dev/remote-build persvati src/extract/wordprob Veri7vn_Wordprob -d src/extract/commons --expect 'VERI7VN_WORDPROB PASS'
    VERI7VN_EXPORT_DIR=<successful-attempt>/results/export/Veri7vn_Wordprob sh src/extract/wordprob/build.sh
    python3 -B src/extract/wordprob/test_units.py

`test_units.py` checks independent unit and numeric boundaries plus actual
guard composition. `score_core.py` retains the original recorded core
references and reports intentional behavior/text differences; it does not
silently rewrite them. These checks are distinct from shipped specialist
panels and their six-criterion scorers. The 924-question core comparison now answers 46 questions (five newly
answered rectangle perimeters are independently correct), preserves all 24
core word-item status/path results and all 12 negative-given refusals, and
changes 12 other geometry/motion schema paths deliberately. No shipped
specialist-panel completion is claimed for this route. Receipts are tracked in
`project/lanes/D-runtime-routes.md`.
