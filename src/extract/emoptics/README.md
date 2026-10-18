# Electrical, electronics, wiring and optics, end to end (lane S04)

Nine shipped Oracle7 specialists are one program here: `electrical`, `electronics`,
`electronics-r2`, `wiring`, `optics`, `optics-v2`, `optics-v3`, `optics-v5` and
`optics-v5-r2` (`upstream/root/specialists/<id>/`). The arithmetic and the decisions to
decline are written in Isabelle/HOL with proofs. Isabelle turns them into Standard ML, and
the MLton compiler inside Isabelle makes one standalone binary (760 KB) that speaks the
[answerer contract](../../../docs/contracts/answerer.md). `--specialist ID` reads questions
the way that one manifest's organ does; without it the family is asked in a fixed order.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Unit factors, unit words, media, resistivities, h, c, e | `Emoptics.thy` | HOL constants, compared with the organ files by `tables_check.py` (28 checks) |
| Requests, declines, kernel, rounding, reply text | `Emoptics.thy` | HOL, proved, exported to SML |
| Enclosures for square roots, the AWG power law, sine, arc sine | `Emoptics_Num.thy` over Isabelle's `Approximation` | proved there; this lane adds sine in degrees, arc sine and the sign test |
| Export, self test, oracle check | `Emoptics_Export.thy` | the build fails if a listed theorem uses an oracle or the self test fails |
| Reading English | `../commons/commons.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions and branch order |
| JSON framing, ohm and micro signs | `main.sml` | **untrusted** |
| Table transcription check | `tables_check.py` | a Python check, not a proof |

Rational kinds (Ohm's law, series and parallel, dividers, RC, LED, transformers, power
factor, horsepower, lenses, photon energy, frequency, wavelength, speed in a medium) are
exact. Square-root, AWG and angle kinds are decimals inside a verified interval, to four
digits within one part in a thousand. Total internal reflection is stated only when the
interval shows `n1 sin t1 > n2`; a refraction exactly at the boundary is declined as
imprecise. A decline happens exactly when the kernel's `pre` says so (missing value, power
factor above 1, real power above apparent power, a zero or negative resistor, an index below
1, an angle outside 0..90, a judgement about code compliance).

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Emoptics --session-root src/extract/emoptics --expect 'VERI7VN_EMOPTICS PASS' --timeout 900
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/emoptics/tables_check.py
sh src/extract/emoptics/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/emoptics/bin/emoptics --specialist {id}" \
  --specialist electrical,electronics,electronics-r2,wiring,optics,optics-v2,optics-v3,optics-v5,optics-v5-r2 \
  --split both --out var/emoptics/parity
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/emoptics/score.py     # also compares every reply with the organ
```

## Result

Every specialist matches its shipped held-out count and every reply agrees with the
shipped organ (same status, kind and value). See the [handoff](../../../project/lanes/S04-em-optics.md).
