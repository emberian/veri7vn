# Trades continuation, 18 October 2026

Status: implemented, freshly proved, compiled and checked through the shared
runtime. Source and binary are frozen for delivery capture. Root owns commits.

Printing now recognizes printed parts in its layer-count requests. Woodworking
recognizes board footage with inch marks and retains invalid dimensional-lumber
refusals through dispatch. Crafts now computes rows from row gauge and target
length, with exact inch/cm conversion and nearest-whole rounding, ties to even.
The kernel receives gauge count and span separately and refuses a nonpositive
span or negative count/length. This assumes uniform gauge throughout the work.

## Shipped results

Counts are right / wrong / false yes / valid withheld. Original organs and the
saved pre-change binary agree on the baseline specialist counts.

| Specialist | Before dev | Before heldout | After dev | After heldout |
|---|---|---|---|---|
| architecture | 10/0/0/0 | 10/0/0/0 | 10/0/0/0 | 10/0/0/0 |
| printing | 39/0/0/0 | 30/0/0/6 | 39/0/0/0 | 36/0/0/0 |
| printing-v2 | 36/0/0/0 | 37/0/0/0 | 36/0/0/0 | 37/0/0/0 |
| safety | 44/0/0/0 | 45/0/0/0 | 44/0/0/0 | 45/0/0/0 |
| woodworking | 36/0/0/0 | 33/0/0/3 | 36/0/0/0 | 36/0/0/0 |
| crafts | 14/0/0/0 | 14/0/0/0 | 14/0/0/0 | 14/0/0/0 |

Total specialist results improve from 388/397 to 397/397. Family mode also
scores 397/397; it already used printing-v2 for the printing questions, so its
new shipped gain is the three woodworking answers. The scoped parity harness
confirms 397/397, zero wrong and false yes. Its overall verdict remains
**INCOMPLETE** because no whole-head domain-gain/lane/self comparison was run.

## Fresh and extension checks

Seed offset 20261018 yields complete results in both modes: architecture 10/10,
printing 39/37, printing-v2 38/38, woodworking 36/36, crafts 14/14 (dev/heldout).
Safety retains its shipped 44/45 because no generator ships for it; those 89
items are explicitly not fresh. Including safety, the saved binary and organs
score 393/401, versus 401/401 after: five printing and three woodworking misses
resolved, with zero wrong and false yes.

The untouched second seed offset 20261231, generated after the final reader,
yields architecture 10/10, printing 35/35, printing-v2 36/38, woodworking 36/36,
crafts 14/14, plus retained safety 44/45. Final result is 393/393 in both modes,
versus 384/393 for original organs and saved binary. No new tuning followed
this seed. Fresh sampling varies existing pools/templates, not independent
question design.

All 24 authored probes pass in specialist and family mode, versus 7/24 for the
saved binary: 17 newly usable answers and seven correct refusals. The extension
covers row gauge arithmetic, conversions, ties, zero target length, leading-dot
numerals and invalid dimensions/numeric tokens, plus printing and board-foot
requests. These checks share the author's assumptions and are not independent
panels.

Actual shared acceptance and arbitration checks pass: rows 84, zero-span
terminal impossible, printed layers 900, board footage 10, and invalid nominal
5x7 terminal impossible. Receipt: `var/C-runtime-consumers/trades-final.json`.

## What is proved

Two new statements are included in the final oracle scan:

- If `kernel (Rows count span unit len len_unit) = Exact kind value`, then
  count and length are nonnegative, span is positive, kind is rows, and value
  is an integer within one-half of `count/span * converted_length`; exact
  half ties choose an even integer. Conversion is performed in HOL.
- For an inch-based gauge, replacing an inch target length by that length times
  127/50 in centimeters
  leaves the entire row kernel outcome unchanged, including refusals.

The independent nearest-integer specification is bound to the kernel, not just
asserted of a duplicated formula. The statements do not prove the English
reader or that real knitting maintains its measured gauge. Request metadata
links the applicable checked statement; it is not a per-answer proof object.

Successful immutable receipt:
`var/trades/remote-attempts/20261018T071108Z-9df0f3d44b01/receipt.json`.
Full session marker: `VERI7VN_TRADES PASS theorems=34 oracles=0`; build, log and
export exit zero. An earlier hbox attempt failed on an imported-name collision;
no export from that failed attempt was used. `tables_check.py` passes all 77
constant/table checks.

## Delivery and limits

Changed files: `Trades.thy`, `Trades_Export.thy`, `recognizer.sml`, `main.sml`,
`build.sh`, `score.py`, `README.md`, new `capabilities.json` and `probes.json`,
all under `src/extract/trades/`, plus this report. The capability declaration
adds rows and its refusal to crafts, and general board-footage and dimensional
lumber contexts to woodworking. Build scripts require an explicit successful
export. The scorer supports fresh seeds, selected panels and authored probes.

Binary size is 811,656 bytes, versus 812,104 before. Five final process starts
were 4.18–7.90 ms, median 6.37 ms. Specialist in-binary medians were
0.076–0.547 ms, below the 50 ms budgets. No interval precision was reduced.

Export SHA256: `26968da628393689ec84e32309cedb80d2f49c0928ebfddd22b1392de1ba6a34`.
Binary SHA256: `57712b68033669f95c5d39188bdf5a2a1aef3292e28e119b32c1ac70f9785b9d`.
Theory SHA256: `b68971f1a83fd5632dd2333e8b5b39b531585f3a38aab976663ad3e595148b7b`.
Export theory SHA256: `b4476d83c98c5687be75090827cbe44a8fe6b9bc8a33fb960732b7d4227dc624`.
Reader SHA256: `866fb8276846b77ba15ea19ab9b31ed4110db014d2b86a3c3f16e0801afbcc02`.
Full source hashes: `var/trades/codex/final-source-sha256.json`.

Detailed receipts: `var/trades/codex/{after,fresh-after,untouched-after,
untouched-before,organ-untouched,probes-final-before}.json` and `parity-final/`.

A fresh Linux/package receipt is still the delivery owner's work. The original
crafts docstring's three-primary RGB white mixture remains unsupported. A
separate D audit also found inherited epsilon ceiling/floor behavior wrong at
integer boundaries; its exact-count correction is staged separately until
this C packet is captured. Full shipped parity is not a claim that every input
or every original model convention is correct.
