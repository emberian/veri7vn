# The life-science family, end to end

This folder carries six shipped Oracle7 specialists as one program: `genetics-v2`,
`biology`, `ecology`, `forestry`, `wildlife` and `microbiology-v2`
(`upstream/root/specialists/<id>/organ_*.py`). They share no unit system, so each has its own
small HOL kernel, but they share one numeric layer, one reply type and one binary.

- The decisions to answer or decline, and every value, are written in Isabelle/HOL with proofs.
- Isabelle turns the kernels into Standard ML; the MLton compiler inside Isabelle turns that and
  the hand-written recognizer into one standalone binary, `var/life/bin/life`. No Isabelle process
  runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md). With
  `--specialist ID` it reads questions the way that one manifest's organ does; without it, it asks
  all six in a fixed order.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Rounding to four significant digits, interval enclosure, decimal layout | `base/Life_Num.thy` | copied from lane G, proved |
| Outcomes, declines, reply text type | `Life_Core.thy` | HOL, proved |
| Punnett squares, Hardy-Weinberg | `Genetics.thy` | HOL, proved; exact except the square roots |
| Genetic code, complement, transcription, translation, GC content | `Biology.thy` | HOL, proved; code table checked by `tables_check.py` |
| Diversity indices, growth | `Ecology.thy` | Simpson and logistic rate exact; Shannon, evenness, exponentials enclosed |
| Basal area, Doyle, Smalian, trees per acre, clinometer height | `Forestry.thy` | exact except pi and tan (enclosed) |
| Mark-recapture, density, survival | `Wildlife.thy` | exact rationals |
| Growth, generations, plate counts, dilutions | `Micro.thy` | exact; a real power of two or logarithm is enclosed |
| Export, self test, oracle check | `Life_Export.thy` | the build fails if any listed theorem uses an oracle or the self test fails |
| Table transcription check | `tables_check.py` | a Python check of HOL text against the organ files, not a proof |
| Reading English | `regex.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions |
| JSON framing | `main.sml` | **untrusted** |

Enclosed values are rounded to four significant digits from a verified interval (precision 72
bits); each theorem bounds the error at one part in a thousand plus 1e-9. Genetics answers are
exact fractions (1/4, 3/4) with the percent alongside, as the organ prints them.

## Regenerating the recognizer

`recognizer.sml` is generated: `sh src/extract/life/gen/rebuild.sh` rebuilds it from
`gen/part{1,2,3}.sml` with `gen/conv.py` (which turns the bracketed regex text into SML string
literals). Edit the parts, not the generated file; `git diff` on it must be empty after a no-op regenerate.

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Life --session-root src/extract/life \
  --expect 'VERI7VN_LIFE PASS' --timeout 900
python3 src/extract/life/tables_check.py
sh src/extract/life/build.sh                 # exports the SML, compiles var/life/bin/life
echo '{"id": "1", "q": "Reverse complement of ATGCGT?", "session": "s"}' | var/life/bin/life
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/life/score.py     # organ cross-check, all six panels
```

## Current result

See [the lane handoff](../../../project/lanes/S09-life.md) for the per-specialist table.
