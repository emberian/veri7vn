# The mechanics family, end to end

This folder carries nine shipped Oracle7 specialists as one program: `physics`, `physics-r2`,
`physics-r3`, `mechanisms`, `mechanisms-v2`, `bodies-v2`, `sports`, `fleet` and `fluids-r2`
(`upstream/root/specialists/<id>/organ_*.py`). Each reads numbers and words out of a short
question (a mass and a speed, the teeth of two gears, a planet's name and a height, a batting line,
miles per gallon, a depth in water) and applies a short formula. Versions of one stem
(`physics`, `-r2`, `-r3`; `mechanisms`, `-v2`) differ only in which questions they take.

- The formulas, the tables and the decisions to decline are written in Isabelle/HOL, with proofs.
- The program that answers is a HOL function. Isabelle turns it into Standard ML, and the MLton
  compiler that ships inside Isabelle turns that into one standalone binary. No Isabelle process
  runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md). With
  `--specialist ID` it reads questions the way that one manifest's organ does. Without it, it asks
  the family in a fixed order (fluids-r2, bodies-v2, fleet, sports, mechanisms-v2, physics-r3).

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Rounding, number layout, interval enclosure | `Mech_Num.thy` | HOL, copied from lane G and lane D, proved there and here |
| Constants, fluid and solid densities, body gravities, unit scales | `Mechanics.thy` | HOL constants, copied from the organs and checked by `tables_check.py` |
| Requests, declines, kernel, per-kind equations, reply text | `Mechanics.thy` | HOL, proved; exported to SML |
| Export, self test, oracle check | `Mechanics_Export.thy` | HOL; the build fails if any listed theorem uses an oracle or the self test fails |
| Square roots, pi, sine (free-fall times and speeds, pendulum, range, shaft power, angled torque) | Isabelle's `HOL-Decision_Procs.Approximation` | Isabelle library, proved there |
| Table transcription check | `tables_check.py` | a Python check of the HOL text against the organ files; not a proof |
| Reading numbers and words out of English | `../commons/commons.sml`, `../commons/numeric.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions |
| JSON framing | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

Everything except the six real-valued kinds is computed exactly in rational arithmetic. The six
real-valued kinds (free-fall time and impact speed, pendulum period, projectile range, shaft power,
torque at an angle) are computed by enclosing the real value in a verified interval and rounding
to four digits; `kernel_approx_sound` bounds the error at one part in a thousand. The kernel declines
as underspecified when a required amount is missing. It declines impossible
inputs such as zero denominators, a ramp rising more than its length, and
invalid baseball outs. The current domain work also checks nonnegative mass,
geometry and elapsed time, integer event counts, and count relationships.
Directed velocity, force and torque retain their signs. Statements:
[lane S01 handoff](../../../project/lanes/S01-mechanics.md).

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Mechanics --session-root src/extract/mechanics \
  --expect 'VERI7VN_MECHANICS PASS' --timeout 600
python3 src/extract/mechanics/tables_check.py
sh src/extract/mechanics/build.sh        # checked export, immutable MLton inputs, native binary
echo '{"id": "1", "q": "On Mars, how much does a 400 kg crate weigh in newtons?"}' | var/mechanics/bin/mechanics --specialist bodies-v2
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/mechanics/score.py
```

## Current result

The continuation also fixes torque-on-a-lever questions in `mechanisms` v1:
a simple torque request reaches the existing torque kernel instead of asking
for two lever-arm lengths. Questions explicitly asking about effort and load
arms still use the lever model. The held-out panel rises from 57/64 to 64/64;
all nine specialist panels are now completely right in both splits, with zero
wrong and zero false yes. No new formula or answer kind was needed.

Build-time self tests still run but are no longer exported as an eager runtime
constant. The build script accepts a checked remote export or an explicit
`GENERATED_SML` path and preserves existing export directories. See the
[continuation report](../../../project/lanes/C-physical-mechanics-space.md) for
fresh seeds, 20 authored probes, timing and remaining scope limits.

## Dimensions and input domains

The next Mechanics packet normalizes lever arms, belt diameters, incline
geometry and fluid depth with exact metre, centimetre, millimetre, foot and
inch scales. Shared `ExactNumeric` tokens preserve signs and whole numeric
literals; baseball innings and win-loss records keep their distinct syntax.
Every ordinary arithmetic field resolves to an issued numeric token.

The typed `physical_domain` predicate is part of the kernel acceptance check.
An accepted reply implies this predicate; existing output equations still
bind the answer to its input. The lever-unit statements additionally bind the
answer to the original magnitudes and exact unit scales. These statements
assume that the untrusted English recognizer assigned the right quantities
to the right fields. They do not prove an arbitrary English interpretation.

The model also permits zero-distance fuel cost, zero-gravity weight, and
on-base percentage with zero at-bats when the full denominator is positive.
See the [domain and dimensions report](../../../project/lanes/C-physical-mechanics-space-next.md)
for the passed proof receipt, measurements, and limits. `build.sh` captures
the actual MLton inputs in `var/mechanics/build/compile-inputs.json`; source
hashes gathered after compilation are not used as evidence of those inputs.
