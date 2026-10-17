# Acoustics, end to end

This folder carries one shipped Oracle7 specialist, `acoustics`
(`upstream/root/specialists/acoustics/organ_acoustics_v1.py`), all the way from
proved formulas to a small program that answers questions.

- The formulas (speed of sound, wavelengths, decibels, Doppler shift, string and
  pipe harmonics, beats) are written down in Isabelle/HOL over the real numbers,
  with proofs that each answer satisfies its physical equation.
- The program that computes the answers is a HOL function. Isabelle turns it
  into Standard ML, and the MLton compiler that ships inside Isabelle turns that
  into a standalone binary. No Isabelle process runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md):
  one JSON question per line in, one JSON reply per line out.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Physical model, declines, kernel, rounding, reply text | `Acoustics.thy` | HOL, proved; exported to SML |
| Export, self test, oracle check | `Acoustics_Export.thy` | HOL; the build fails if any listed theorem depends on an oracle |
| Interval arithmetic (square root, logarithm, powers) | Isabelle's `HOL-Decision_Procs.Approximation` | Isabelle library, proved there |
| Reading numbers out of English | `regex.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organ's regular expressions |
| JSON framing | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

The kernel's main theorem, `kernel_value_sound`, says: whenever the kernel
states a value, the request was neither underspecified nor impossible, and the
stated decimal is within one part in a thousand of the real-number model (plus
10^-9 absolute, which only matters at zero). The scorer allows two parts in a
thousand plus 0.05. The other theorems pin down exactly when the kernel declines,
and give each kind's defining equation; see `project/lanes/D-acoustics.md` for
the statements.

How square roots and logarithms are handled: the kernel writes each formula as
an expression for Isabelle's verified interval arithmetic, which returns a small
interval of binary floats guaranteed to contain the true real value. The kernel
rounds the middle of that interval to four significant digits and refuses
(`imprecise`) if the interval is too wide for that; the theorem covers the
rounding. The one comparison that involves a square root, "is the source at or
above the speed of sound", is decided exactly with rational arithmetic
(`reach_iff`).

The reply text, including the stated formula and assumption ("air at 20 degrees
C" when no temperature is given), is produced by HOL functions. It is ASCII:
Isabelle string literals cannot hold the organ's Unicode symbols, so the text
says `degrees C`, `sqrt`, `log10`, `lambda`, `v_s`.

## Build and run

```sh
# 1. prove and generate (the only Isabelle build; takes the shared lock)
python3 tools/dev/check-native --session Veri7vn_Acoustics \
  --session-root src/extract/acoustics --expect 'VERI7VN_ACOUSTICS PASS' --timeout 900
# 2. export the generated SML and compile the binary to var/acoustics/bin/acoustics
sh src/extract/acoustics/build.sh
# 3. ask it something
echo '{"id": "1", "q": "What is the speed of sound in air at 0 degrees C?", "session": "s"}' \
  | var/acoustics/bin/acoustics
# 4. score on the shipped panel and compare with the organ
.venv/bin/python src/extract/acoustics/score.py
```

The binary is not committed; it lives under `var/acoustics/bin/`.

## Current result

Held-out panel: 66 of 69 right, 0 wrong, 0 false yes (the shipped organ: 69 of 69).
The three misses are decibel questions where the interval for a logarithm is too
wide to give four digits, so the kernel withholds instead of guessing. Binary
427 KB, cold start about 15 ms, median 12 ms per question. Details, theorem
statements and remaining work: [lane D handoff](../../../project/lanes/D-acoustics.md).
