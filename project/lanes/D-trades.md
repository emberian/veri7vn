# Exact trade counts, 18 October 2026

Status: proof passed on persvati as `20261018T072624Z-cf9d4c182966`,
with `VERI7VN_TRADES PASS theorems=40 oracles=0`; build, log and export exited
zero. The final native compiled from that export and the frozen shared numeral
reader passes 357/357 shipped and 35/35 authored probes in both modes. The
shared native compiler captured and hashed its actual inputs. C source was
captured first; its original frozen report remains preserved in scratch.

The original ceiling/floor functions shift exact rational inputs by 1e-9,
copying an old floating-point workaround. That can undercount required layers,
occupants, sheets or risers, and overcount blocks that fit. For example, a part
1.0000000001 mm tall with 1 mm layers needs two layers but receives one. The
repair uses exact ceiling and floor and gives those counts an independent
integer covering/fitting specification. It also corrects the explanation that
called a 32-square-foot sheet 4x4 instead of 4x8.

Checked statements:

- Covering count n has integer value and satisfies x <= n < x + 1. With a
  positive unit size, n units cover the amount and n-1 do not.
- Fitting count n has integer value and satisfies n <= x < n + 1. With a
  positive unit size, n units fit within the amount and n+1 do not.
- Exact layer, occupant and drywall answers satisfy the corresponding capacity
  inequalities in their supplied physical units.
- An exact quilt answer is the product of across/down counts whose blocks fit
  in each dimension, while one more block in that dimension would not.

The row-gauge reader also now uses shared `ExactNumeric.scan` values and spans.
The new fraction probe exposed C's `1/2 rows per inch` being interpreted as two
rows per inch; the shared lexer represents one-half exactly. The row kernel
and nearest-even convention are unchanged from C.

## Evidence

All 24 C probes pass in a scratch reader prototype using the captured C
arithmetic export. This checks shared-lexer migration, not the new count laws.
There are 11 new D probes. Together, the captured C binary scores 25 right,
9 wrong and 1 valid withheld on 35 probes, with no false yes. One exact-integer
control was already correct; the failures expose the model/count/text issues.
Receipts: `var/D-materials-trades/trades-prototype-c-probes.json` and
`trades-probes-before.json`.

The final report will state any disagreement between true exact counts and
old benchmark expectations. It must not reproduce an incorrect epsilon result
merely to obtain the old scorer's approval. Existing unsigned number readers
outside the row-gauge change remain a separate semantic boundary to audit.

## Per-specialist semantic ledger

These are actual observed behaviors and inspected model boundaries, not panel
completeness claims. Inputs/replies: `var/D-materials-trades/gap-probes.json`.

| Specialist | Observed behavior | Current repair or remaining limit |
|---|---|---|
| architecture | Business area 150.00000001 sq ft gives one occupant, although exact division by 150 requires ceiling two | Exact covering count and consumer capacity law implemented; physical code conventions remain explicitly assumed |
| printing | Height 1.0000000001 mm with 1 mm layers gives one layer | Exact ceiling implemented; C printed-cue repair preserved |
| printing-v2 | Same integer-boundary undercount as printing | Shares the repaired count primitive |
| safety | Noise exposure 2 h at 90 dBA plus 2 h at 95 dBA gives 75%; accepted FM=2 with other multipliers one gives RWL 46 kg | The official frequency table never exceeds one; FM=2 is outside it. A separate multiplier-domain guard remains to implement |
| woodworking | Area 32.000000001 sq ft gives one 4x8 sheet; explanation calls a 32 sq ft sheet 4x4 | Exact covering and dimension text repaired; stairs use the same exact count |
| crafts | Width .9999999999 in with 1 in blocks incorrectly fits one; three-primary RGB light is withheld despite original promise | Exact fitting and shared row lexer implemented; n-ary RGB mixing remains unfinished |

Final D native: 357/357 shipped, 35/35 authored probes in both modes,
versus C's 25/35 authored probes. Fresh seed 20270118 gives 354/354; untouched
seed 20270219 gives 351/351, also matched by C. Both include the 89 retained,
not-fresh safety cases. No panel scorer disagreement with the exact arithmetic
appeared in these samples; the authored boundary probes deliberately expose
where the old epsilon rule is wrong.

Receipts: `var/D-materials-trades/trades-shipped.json`, `trades-fresh.json`,
`trades-untouched.json` and corresponding `*-before.json`. Final binary
size 864,616 bytes; first measured launch 76.17 ms, subsequent four 3.75–4.26 ms.
Specialist in-binary median reply times are 0.083–0.785 ms. Final shipped/probe
receipt: `var/D-materials-trades/trades-final.json`. Fresh and untouched panels
were sampled on the earlier diagnostic compile; the final compile then
rechecked shipped cases and all probes after the shared slash-unit repair.
The scoped official parity harness confirms 357/357, zero wrong and false yes;
its overall verdict is INCOMPLETE because no full-head domain/lane/self
comparison was run (`var/D-materials-trades/trades-parity`).
Table/source checks pass, with the old organ epsilon explicitly documented as
a deliberate model difference. Six actual composed dispatcher cases pass; receipt
`var/C-runtime-consumers/trades-D-final.json`. Immutable actual-input capture
is at `var/C-runtime-package/bound-prepared/20261018T073832Z-a963817c152d/trades`.
Linux/package checks and root integration are pending. Source remains frozen
until integration as well as capture.
Root owns commits and integration.

Native SHA256: `c96fff97e1e89826e27c46fa7b1f4f0875e3954dfca29845df4d42534ea3684f`.
Export SHA256: `e8145a238ed96c8b654da9c84262cf955249d66a8a1cb285e071bbe37a0a1dbb`.
Compile receipt: `var/trades/native-attempts/20261018T073832Z-a963817c152d/compile-inputs.json`.
All final source hashes: `var/D-materials-trades/trades-final-hashes.json`.
The shared lexer hash is `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The safety follow-on is now source-confirmed: the original NIOSH manual's
frequency table has values from zero through one, and its coupling table uses
0.90, 0.95 or 1.00. The accepted FM=2 request is outside that table; a guard
must not claim it validated which table row applies to an actual task.
Source: [NIOSH applications manual, tables 5 and 7](https://stacks.cdc.gov/view/cdc/5434/cdc_5434_DS1.pdf).

Additional observed safety boundary (`var/D-materials-trades/safety-next-probes.json`):
a lifting-index question with all multipliers but no load silently answers
weight limit 23 kg instead of asking for load. FM=1/2 is read as 1, returning
23 rather than 11.5 kg. The next correction needs both exact shared numeric
roles and an explicit distinction between the requested weight-limit and
lifting-index targets; inferring the target from whether a load was parsed
loses the user's request. These are not repaired by the current D count packet.
