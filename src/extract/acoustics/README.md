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
| Reading numbers out of English | `../commons/commons.sml` (Regex), `recognizer.sml` | **untrusted**, hand-ported from the organ's regular expressions |
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
rounding. The kernel first tries 32-bit intervals, then retries at 64 bits
when that guard refuses; both paths have the same proved error bound. The one comparison that involves a square root, "is the source at or
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

For a remote build, compile its recorded export with
`GENERATED_SML=/absolute/path/to/the/checked/export sh src/extract/acoustics/build.sh`.
The script preserves earlier exports. The self-test runs during the proof export,
and is no longer exported as a startup computation.

The Codex continuation fixes inverse frequency questions and keeps stated sound
speed separate from mover speed and pipe length. Explicit Celsius temperature
reaches each dry-air calculation. Unsupported speed or temperature units, mixed
feet/metres distance queries, and water conditions outside the fixed 20 C speed
model fall through instead of silently substituting air at 20 C. This does not
make the recognizer verified. Additional laws connect the printed decimal to
the model, relate open and closed pipe frequencies, and show that adding a sound
source cannot make the combined level lower. Continuation receipts and probes:
`project/lanes/C-physical-quantity-sound.md`.

## Current result

Held-out panel: 69 of 69 right, 0 wrong, 0 false yes (the shipped organ: 69 of 69);
practice panel 70 of 70. The final continuation binary is 428,720 bytes, with
a measured 4.25 ms median cold start and 1.99 ms shipped-panel median per question.
All 45 additional probes and a reserved 180-case numerical challenge pass.
The numerical challenge has an 8.18 ms median and 76.95 ms maximum; the earlier
regression seed includes an 89.02 ms retry, exceeding the 50 ms aspiration.
The folder `oracle7-organ/` wraps the
binary as an Oracle7 specialist (`acoustics-veri7vn`). Details, theorem
statements and remaining work: [continuation report](../../../project/lanes/C-physical-quantity-sound.md).

## Exact numeral interpretation

The continuation uses the shared untrusted `../commons/numeric.sml` lexer.
It reads complete signed decimal, scientific and slash-fraction tokens exactly,
including leading-dot decimals and Unicode minus. Malformed or over-limit
numeric runs fall through; their suffixes are never treated as a different
number. The role recognizer binds the resulting exact fractions to the physical
request. This improves interpretation but does not make English parsing a proof.
See [semantic continuation](../../../project/lanes/C-physical-quantity-sound-next.md)
for domain-specific sign rules, panel results and remaining limitations.
