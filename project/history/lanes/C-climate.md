# C-climate — complete the shipped request language

The six specialists are carboncapture, airquality, climate, carbonmat, coldchain
and coldchain-v2. All shipped and measured fresh items are now answered correctly
or correctly declined: zero wrong and zero false yes. The binary starts in
3.6 ms, down from about 50–60 ms, and its slowest specialist median is 2.9 ms.

The air-quality reader accepts `CO measured at ...` and `Nitrogen dioxide
reads ...`. Both cold-chain wrappers use the complete existing reader, including
plural foods and free word order. A decimal duration between two temperatures
no longer gets mistaken for the end of a sentence. No numerical constants,
models or answer kinds were added.

## Shipped panels

Each cell is right / wrong / false yes / valid withheld. Right includes correct
refusals. Old-kernel numbers were measured before editing; the shipped organs
have the same counts. The table uses pinned specialist mode; the family-mode
parity harness also scores every item correctly.

| Specialist | Dev, old → new | Held-out, old → new | New p50 |
|---|---|---|---|
| carboncapture | 14/0/0/0 → same | 14/0/0/0 → same | 0.15 ms |
| airquality | 38/0/0/0 → same | 30/0/0/8 → 38/0/0/0 | 0.17 ms |
| climate | 24/0/0/0 → same | 24/0/0/0 → same | 2.90 ms |
| carbonmat | 17/0/0/0 → same | 17/0/0/0 → same | 0.14 ms |
| coldchain | 30/0/0/0 → same | 18/0/0/12 → 30/0/0/0 | 0.10 ms |
| coldchain-v2 | 30/0/0/0 → same | 29/0/0/1 → 30/0/0/0 | 0.11 ms |

Combined shipped: **306/306**, versus 285/306 and 21 valid withheld before.
The six admission criteria have not all been measured: the standalone harness
marks results INCOMPLETE because head comparison, core-lane and self behavior
were not run here. The zero-false-yes count is on the specialists' negative items.

## Fresh numeric samples and probes

The generator's original seeds receive offsets 701 and 1701 during development;
9701 was untouched until source work finished. The old kernel's archived binary
was retained to make the comparison. The generators retain the author's fixed
wording and assumptions, so these are fresh numeric samples, not independent
natural-language evaluations.

| Seed offset, both splits | Old kernel / shipped organ | New kernel | Wrong / false yes |
|---|---|---|---|
| 701 | 287/309, 22 valid withheld | 309/309 | 0 / 0 |
| 1701 | 289/308, 19 valid withheld | 308/308 | 0 / 0 |
| 9701, untouched | 289/309, 20 valid withheld | 309/309 | 0 / 0 |

The 20 committed author probes improve from 9/20 to 20/20, including invalid
AQI units, requests for personalized advice, non-food temperatures, unsupported
cooling stages, missing climate sensitivity and excessive capture rate. These
probes share an author with the recognizer; they are not independent evidence.

## Checked proof and execution changes

The existing HOL kernels still decide AQI thresholds and cooling-stage verdicts.
Their wave-6 monotonicity and exact decline proofs remain in place. A new code
equation proves:

```
not_taken r =
  (case r of Req_aq a => aq_kernel a = Decline Not_taken
           | Req_cd c => cd_kernel c = Decline Not_taken
           | _ => False)
```

This avoids calculating interval answers for climate/carbon-material requests
just to decide whether they can fall through. It changes executable cost, not
the mathematical function. Short direct questions also skip a duplicate answer
calculation in the untrusted reader. Build self-tests still execute, but their
eager constant is no longer exported into every executable startup.

Proof receipt: `var/climate/remote-attempts/20261018T063824Z-885e7e57dff6/receipt.json`,
`VERI7VN_CLIMATE PASS theorems=81 oracles=0`, exit 0. The checked SML export has
SHA256 `b935ec9a723770e87ce2e70484f1163382023dbc5753b1336fcd871051274941`;
the final 618,648-byte macOS binary has SHA256
`d3aa029c805763d9b39fe4f99d8b0b7dac816e5ee4ac04f0344c87720518c0ac`.
Cold medians use five start-to-unrecognized-reply runs, excluding a substantive
question's calculation. All specialist medians meet the 5 ms target.

Changed files: Climate_Export.thy, recognizer.sml, build.sh, README.md,
beyond.py and beyond-probes.json within `src/extract/climate/`, and this report.
The build script consumes the checked remote export and does not erase another
session's local export. English recognition and JSON framing remain untrusted;
text-layout checking is not a theorem about arbitrary English.

## Consumer and reproduction

Consumer: `var/climate/bin/climate --specialist ID` and the family-mode binary.
Existing answer kinds remain unchanged, so these repairs need no new manifest
acceptance entries. Composed runtime and Linux package validation belong to the
runtime/integration owner; this lane does not claim them.

```
sh src/extract/climate/build.sh
python3 -B src/extract/climate/beyond.py --seeds 701,1701,9701 --out var/climate/c-final
python3 -B tools/parity/harness.py --answerer 'var/climate/bin/climate' --specialist carboncapture,airquality,climate,carbonmat,coldchain,coldchain-v2 --split both --out var/climate/c-parity
```

Raw final measurements: `var/climate/c-final/report.json` and
`var/climate/c-parity/`. Warm-baseline receipts and archived binaries are under
`var/c-natural/earth-climate/`; they are not committed.
