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
| Reading numbers and words out of English | `regex.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions |
| JSON framing | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

Everything except the six real-valued kinds is computed exactly in rational arithmetic. The six
real-valued kinds (free-fall time and impact speed, pendulum period, projectile range, shaft power,
torque at an angle) are computed by enclosing the real value in a verified interval and rounding
to four digits; `kernel_approx_sound` bounds the error at one part in a thousand. The kernel declines
as underspecified exactly when an amount the organ needs is missing, and as impossible exactly when
the input would divide by zero, take the root of a negative number, or is one the organ itself
refuses (a ramp that rises more than its length, zero attempts, ".5" outs in an innings). Statements:
[lane S01 handoff](../../../project/lanes/S01-mechanics.md).

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Mechanics --session-root src/extract/mechanics \
  --expect 'VERI7VN_MECHANICS PASS' --timeout 600
python3 src/extract/mechanics/tables_check.py
sh src/extract/mechanics/build.sh        # export, then MLton: var/mechanics/bin/mechanics
echo '{"id": "1", "q": "On Mars, how much does a 400 kg crate weigh in newtons?"}' | var/mechanics/bin/mechanics --specialist bodies-v2
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/mechanics/score.py
```

## Current result

Every item of every shipped panel, both splits, is right with 0 wrong and 0 false yes, except
the `mechanisms` (v1) held-out panel at 57 of 64, exactly the shipped 57: its seven misses are the
torque-on-a-lever questions that `mechanisms-v2` was written to fix, and `mechanisms-v2` gets all
of them. Details and numbers per specialist: [lane S01 handoff](../../../project/lanes/S01-mechanics.md).
